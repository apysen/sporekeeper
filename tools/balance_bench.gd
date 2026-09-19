extends SceneTree

## Measures what each Core pair actually does, on the same board, against the same
## pressure, with the same ranks bought.
##
## Not a test: nothing here passes or fails. It is an instrument, and it exists because
## every balance question in this project has so far been answered by reading exported
## numbers and multiplying them in one's head - which cannot see what a build does with
## *reach*, with *targets available*, or with the ground it is standing on. Thistle's
## thorn damage and Vine's sweep damage are not comparable quantities until something
## fires both of them at the same enemies for the same minute.
##
## What it does per build:
##
## 1. Puts the same Green island on the same field, with Grandma in the middle of it.
## 2. Commits the Core pair and buys every one of its eight lines to the same rank.
## 3. Holds a fixed population of Hunters on the board, respawning each one that dies,
##    so every build is measured against the *same* target supply rather than against
##    whatever its own clear rate leaves standing.
## 4. Steps combat, the path directors and the field by hand at a fixed delta, so a
##    minute of game time is a minute of game time on any machine.
## 5. Reports damage actually applied, kills, and the ground held at the end.
##
## Grandma stands still and cannot die. That is the honest limit of this instrument and
## it is stated rather than hidden: it measures a build's *output and ground*, not a
## player's movement, and it under-reads anything that pays for repositioning - Thistle
## carry, Fruit rolls, Pruning charges - while reading turrets and sweeps at full value.
## Numbers below are a floor for mobile kits and a fair reading for stationary ones.
##
## Run: godot --headless --path . --script tools/balance_bench.gd
##      godot --headless --path . --script tools/balance_bench.gd -- --ranks 1
##      godot --headless --path . --script tools/balance_bench.gd -- --evolved

const BENCH_SECONDS := 40.0
const STEP := 1.0 / 60.0
## Held population. High enough that a wide sweep finds more targets than a single-target
## kit, which is the difference being measured, and low enough to stay well under the
## crowd LOD and the spawn cap.
const TARGET_POPULATION := 22
const SPAWN_RING_PIXELS := 230.0
## `--siege`: a board the build cannot clear, entering close enough to reach her.
##
## The ordinary bench answers "how much can this build kill". It cannot answer "how
## much does this build stop", because at 22 targets entering from 230px almost nothing
## survives the walk: every pair took 6 points of damage in forty seconds, the same 6,
## which is one hit landing before the first sweep. Bramble and Root are paid entirely
## in that column, so the column has to be given something to measure.
const SIEGE_POPULATION := 60
const SIEGE_RING_PIXELS := 130.0
const GREEN_ESTABLISH_STEPS := 420

var _kills := 0
var _rows: Array[Dictionary] = []
var _ranks := 3
var _evolved := false
var _pairs_only := ""
var _siege := false
var _evolution_rank := 5


func _initialize() -> void:
	_read_arguments()
	call_deferred("_run")


func _read_arguments() -> void:
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size()):
		match arguments[index]:
			"--ranks":
				if index + 1 < arguments.size():
					_ranks = clampi(int(arguments[index + 1]), 0, 3)
			"--evolved":
				_evolved = true
			"--evo-rank":
				# Which rank to buy the Evolution to, for reading the ladder one step at
				# a time. Rank 5 is what `--evolved` alone means, and is not what a run
				# reaches: Campaign gets to 3 and Quick to 1.
				if index + 1 < arguments.size():
					_evolved = true
					_evolution_rank = clampi(int(arguments[index + 1]), 1, 5)
			"--siege":
				_siege = true
			"--pair":
				if index + 1 < arguments.size():
					_pairs_only = arguments[index + 1]


func _run() -> void:
	if change_scene_to_file("res://scenes/run/run.tscn") != OK:
		push_error("BALANCE_BENCH: the run scene did not load")
		quit(1)
		return
	await process_frame
	await process_frame
	var run := current_scene as RunRoot
	if run == null:
		push_error("BALANCE_BENCH: the run scene did not become a RunRoot")
		quit(1)
		return
	# Everything is stepped by hand below, so nothing may also step itself.
	run.set_process(false)
	run.combat.set_process(false)
	run.territory_field.set_process(false)
	run.overlay.set_process(false)
	run.player.input_enabled = false
	run.combat.debug_damage_accounting = true
	run.combat.enemy_killed.connect(
		func(_p: Vector2, _xp: int, _r: int, _s: int, _c: int) -> void: _kills += 1
	)

	print(
		"BALANCE_BENCH: %.0fs per build, %d held targets, ranks=%d, evolution=%s"
		% [
			BENCH_SECONDS,
			SIEGE_POPULATION if _siege else TARGET_POPULATION,
			_ranks,
			("rank %d" % _evolution_rank) if _evolved else "none",
		]
	)
	for first in range(Progression.PathId.size()):
		for second in range(first + 1, Progression.PathId.size()):
			if not _pairs_only.is_empty():
				var label := "%d-%d" % [first, second]
				if label != _pairs_only:
					continue
			_rows.append(await _bench_pair(run, first, second))
	_report()
	quit(0)


func _bench_pair(run: RunRoot, first: int, second: int) -> Dictionary:
	_prepare_board(run)
	_commit_build(run, first, second)
	var field := run.territory_field
	var green_before := field.get_player_percent()
	run.combat.debug_damage_applied_total = 0.0
	run.combat.debug_damage_number_total = 0.0
	_kills = 0

	var field_accumulator := 0.0
	var field_step := 1.0 / maxf(1.0, field.tuning.simulation_hz)
	var elapsed := 0.0
	var spawn_cursor := 0
	var damage_taken := 0.0
	while elapsed < BENCH_SECONDS:
		spawn_cursor = _hold_population(run, spawn_cursor)
		# The build's own systems, minus the wave director: the population here is held
		# rather than scheduled, because a build that clears faster would otherwise be
		# measured against an emptier board than a build that clears slower - which is
		# the one comparison this must not make.
		run.progression.tick_biomass(
			STEP, field.get_player_percent(), field.get_mature_percent_of_arena(), 1.0
		)
		run.metabolism.advance(STEP)
		run.relic_director.advance(STEP)
		run.spore_director.advance(STEP)
		run.bloom_director.advance(STEP)
		run.bramble_director.advance(STEP)
		run.bramble_director.advance_relics(STEP)
		run.man_eater.advance(STEP)
		run.pruning_director.advance(STEP)
		run.adaptation_director.advance(STEP)
		# Seeds, Blooms, Fruit and every other catalyst live on the overlay and are
		# advanced by its `_process`, which never runs here: this loop is synchronous and
		# no frame passes inside it. Calling it by hand is what makes Spore and Bloom
		# measurable at all - without it their rows came back as the Cane-only baseline,
		# identical to a build that had bought nothing, which is a bench reporting its own
		# omission as a balance finding.
		run.overlay._process(STEP)
		# Her invulnerability frames, her damage-absorption window and her healing on
		# Mature Green all tick in `_physics_process`, which no frame ever calls here.
		# Left out, the first contact hit made her permanently invulnerable and the
		# damage-taken column read the same 6 points for every build on the board -
		# a number produced entirely by the instrument.
		run.player._physics_process(STEP)
		_aim(run)
		run.combat.simulate_step(STEP)
		field_accumulator += STEP
		while field_accumulator >= field_step:
			field.step_simulation()
			field_accumulator -= field_step
		# What the build failed to stop, read before she is topped back up. Bramble and
		# Root are paid in damage that never lands, and a bench that only counted damage
		# dealt would report the two defensive Adaptations as contributing nothing at
		# all - which says something about the instrument, not about them.
		damage_taken += run.player.get_max_health() - run.player.get_health()
		# She is the bench, not the subject. Kept alive so a build is never credited
		# with the peace of having lost.
		run.player.heal(1000.0)
		elapsed += STEP
	field.recalculate_metrics_now()

	return {
		"first": first,
		"second": second,
		"name": "%s+%s" % [
			Progression.get_path_name(first), Progression.get_path_name(second)
		],
		"damage": run.combat.debug_damage_applied_total,
		"kills": _kills,
		"green_before": green_before,
		"green_after": field.get_player_percent(),
		"mature": field.get_mature_percent_of_arena(),
		"biomass": run.progression.biomass_earned_total,
		"taken": damage_taken,
	}


func _prepare_board(run: RunRoot) -> void:
	## The same starting board for every build: one Green island, grown from one Bloom
	## at the centre, with Grandma standing in the middle of it. A build is measured on
	## ground it did not choose, so what varies between rows is the build.
	run.reset_run()
	run.set_process(false)
	run.combat.set_process(false)
	run.territory_field.set_process(false)
	run.overlay.set_process(false)
	run.player.input_enabled = false
	run.combat.reset_combat()
	var field := run.territory_field
	field.reset_field()
	var centre := field.tuning.arena_size * 0.5
	field.queue_bloom(centre, 9.0, 1.6, 9.0, 3.0)
	for _step in range(GREEN_ESTABLISH_STEPS):
		field.step_simulation()
	field.recalculate_metrics_now()
	run.player.reset_player()
	run.player.global_position = field.to_global(centre)


func _commit_build(run: RunRoot, first: int, second: int) -> void:
	var progression := run.progression
	progression.debug_select_paths(first, second)
	for path_id in [first, second]:
		for upgrade_id in progression.get_adaptation_line_ids(path_id):
			progression._upgrade_levels[upgrade_id] = _ranks
	if _evolved:
		run.evolutions.evolution_status = Progression.EvolutionStatus.READY
		if progression.grant_evolution_if_ready():
			var upgrade_id: int = run.evolutions.get_evolution_upgrade_id(
				run.evolutions.active_evolution
			)
			if upgrade_id >= 0:
				progression._upgrade_levels[upgrade_id] = mini(
					_evolution_rank, progression.evolution_maximum_upgrade_level
				)
	progression.upgrades_changed.emit()
	run._apply_progression_modifiers()


func _aim(run: RunRoot) -> void:
	## Turns Grandma toward the nearest enemy without moving her.
	##
	## Base Cane sweeps the sector she faces; Vine replaces that with auto-aim at the
	## densest sector. A bench where she never turns would therefore be measuring Vine
	## against a player who refuses to look at the enemy, and every number in the table
	## would be an argument for auto-aim rather than for the kit. Facing the nearest
	## body is a competent player's floor, so what the rows below compare is damage,
	## reach and cadence - with Vine's aim counted as the convenience it is rather than
	## as three quarters of everyone else's output.
	var origin := run.player.get_arena_position()
	var nearest := Vector2.ZERO
	var nearest_distance := INF
	for enemy_id in run.combat.get_active_enemy_ids():
		var offset := run.combat.get_enemy_position(enemy_id) - origin
		var distance := offset.length_squared()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = offset
	if nearest.length_squared() > 0.001:
		run.player.move_with_intent(nearest.normalized(), 0.0)


func _hold_population(run: RunRoot, spawn_cursor: int) -> int:
	## Tops the board back up to the held population, entering from a ring around
	## Grandma at evenly walked angles so no build is handed a lucky cluster.
	var combat := run.combat
	var cursor := spawn_cursor
	var guard := 0
	var population := SIEGE_POPULATION if _siege else TARGET_POPULATION
	var ring := SIEGE_RING_PIXELS if _siege else SPAWN_RING_PIXELS
	while combat.get_active_enemy_count() < population and guard < population:
		guard += 1
		var angle := float(cursor) * 2.39996
		cursor += 1
		var position := (
			run.player.get_arena_position()
			+ Vector2.from_angle(angle) * ring
		)
		if not run.territory_field.contains_local_point(position):
			continue
		combat.spawn_enemy(EnemyKinds.Role.HUNTER, position)
	return cursor


func _report() -> void:
	var by_damage := _rows.duplicate()
	by_damage.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a["damage"] > b["damage"]
	)
	print("")
	print("BALANCE_BENCH: pair | damage | kills | green | mature | biomass | damage taken")
	for row in by_damage:
		print(
			"BENCH_ROW	%s	%.0f	%d	%.2f	%.2f	%.1f	%.0f"
			% [
				row["name"],
				row["damage"],
				row["kills"],
				row["green_after"],
				row["mature"],
				row["biomass"],
				row["taken"],
			]
		)
	var total := 0.0
	for row in _rows:
		total += row["damage"]
	var average := total / maxf(1.0, float(_rows.size()))
	print("BALANCE_BENCH: %d pairs, mean damage %.0f" % [_rows.size(), average])
	for row in by_damage:
		print(
			"BENCH_INDEX\t%s\t%.2f"
			% [row["name"], row["damage"] / maxf(1.0, average)]
		)
