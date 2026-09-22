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
## What it measures, beyond damage:
##
## The pair sweep this was built for answered "how much does the build kill", and the
## Campaign rework's whole argument is that killing is not the only axis a build is
## allowed to win on. A Bramble opening that halves the speed of everything on the
## board is doing its job even while its damage column reads near zero, and a table
## that could not see that would keep recommending the same four damage Paths.
##
## So four control columns sit beside the damage: how slowed the board is, how
## tangled, how much of it is pinned outright, and what the build did to the ground.
## They are sampled from the live roster four times a second rather than counted at
## the end, because control is a state the board is held in and not an event.
##
## Run: godot --headless --path . --script tools/balance_bench.gd
##      godot --headless --path . --script tools/balance_bench.gd -- --ranks 1
##      godot --headless --path . --script tools/balance_bench.gd -- --evolved
##      godot --headless --path . --script tools/balance_bench.gd -- --archetypes
##      godot --headless --path . --script tools/balance_bench.gd -- --build 6-5-4
##      godot --headless --path . --script tools/balance_bench.gd -- --isolate 6
##      godot --headless --path . --script tools/balance_bench.gd -- --isolate 6 --with 4
##      godot --headless --path . --script tools/balance_bench.gd -- --boss
##      godot --headless --path . --script tools/balance_bench.gd -- --boss queen

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
## `--boss`: one tough target, replaced the instant it falls, instead of a crowd.
##
## Every number in the pair sweep so far comes from a sixty-Hunter siege, where every
## build is overkill-bound: the difference between damage dealt and damage applied is
## thrown away against bodies that were dying anyway, so a cut to a single-target value
## costs nothing the table can see. Two Pruning decisions are parked on exactly that --
## the 54% cut to `orbit_contact_damage`, chosen on a board that cannot read its cost,
## and `torn_ring_charge_share` 0.20, which measured as *exactly* zero change because
## the discharge landed entirely in overkill. Neither is a balance finding; both are the
## instrument declining to answer.
##
## The headline here is therefore not damage. Damage applied against a lone body is
## nearly quantised by that body's health, while damage *dealt* keeps counting, so the
## reading is how long the build holds the target under fire and how much of what it
## fired was wasted -- which is the eight-target ring cap stated as a number.
##
## Entering close, because the walk in is not the thing being measured. `--boss queen`
## is the Hive Queen, who is deliberately *not* a single-target measurement: she summons,
## so she reads as a boss with a brood around it. `--boss elite` is the Rootbreaker.
##
## Pair it with `--island`. On the default patch board all four Bramble lines measured
## *byte-identical* to the Cane alone against the Burrower -- same damage, same kill, the
## same 540 taken, control columns at exactly 0.000 -- and on the island the same rows
## read slow 0.03-0.07, tangle 0.17-0.33 and 540 taken falling to 444 under Repulsion. So
## the zero was the board, not the Adaptation: a boss that erupts stands in ground it has
## just unmade, and six per cent of Green has nothing around that hole to keep coverage
## under its feet. The patch board reads every territory Adaptation as absent against a
## boss, which is the same defect `--island` was added to the crowd bench to fix.
const BOSS_RING_PIXELS := 90.0
const GREEN_ESTABLISH_STEPS := 420
## Seconds between control samples. Four a second is far finer than any control
## effect in the game turns over, and far coarser than the step loop, so it costs
## nothing and still cannot miss a slow that came and went.
const CONTROL_SAMPLE_SECONDS := 0.25
## The seed every row is run on.
##
## Pinned so that `reset_run` cannot roll a fresh one per row, which is worth doing and
## is *not* what the comment here used to claim. It said the seed pinned each row's
## critical hits, Thistle placements and spawn jitter. It pins none of those, because
## none of them are random: `CombatDirector` holds no gameplay RNG at all -- its repeated
## choices run off deterministic counters (`_briar_trap_sequence`, `_root_eruption_sequence`,
## `_fruiting_body_sequence`) and its one `RandomNumberGenerator` is for audio. Of the
## directors that do own one, Spore hardcodes `0x5EED10` and RelicDirector hardcodes
## `0x0FF1CE5`, so the run seed never reaches either.
##
## What the seed does reach: Progression's draft and relic draws, which a bench that
## writes `_upgrade_levels` directly never performs; the wave director, which this loop
## does not run; the Canker director; and `AdaptationDirector._random`, whose rolls are
## Apical and Wisteria -- Evolution and relic features, inactive unless `--evolved`.
##
## The measured consequence: two seeds produce byte-identical rows. 11,887 damage, 423
## kills, 105 Seeds sown, every column to the digit, in two separate processes. So the
## default sweep is fully deterministic, and that cuts both ways. No row needs a second
## seed to be trusted -- but no row can be *checked* for seed-dependence either, and the
## "two seeds agreeing is a result, one is an anecdote" rule the sweep documents invoke
## cannot be exercised with this tool as it stands. `--seed` is not a variance control
## here; treat a reading as one sample of one configuration.
const DEFAULT_BENCH_SEED := 20260919
## `--island`: a board with real territory on it, instead of the single central patch.
##
## The default board is one Bloom grown for seven seconds, which settles at about six
## per cent of the arena. That is a fair board for a turret and an unfair one for
## everything that reads the ground: Bramble damages and tangles enemies *standing on
## Green*, Root amplifies from Mature Green, Spore germinates into it. With six per
## cent of the arena owned and the held population entering at a ring outside it, the
## territory Adaptations were being measured almost entirely off their own ground.
##
## That matters beyond this tool. The pair sweep that concluded several early Paths
## "provide almost no immediate combat value" was run on this board, so some of that
## finding may be the board rather than the Paths -- which is exactly the thing an
## instrument is supposed to rule out before a balance pass acts on it.
const ISLAND_ANCHORS := [
	Vector2(0.0, 0.0),
	Vector2(-0.22, -0.16),
	Vector2(0.22, -0.16),
	Vector2(-0.22, 0.16),
	Vector2(0.22, 0.16),
]
const ISLAND_ESTABLISH_STEPS := 900
## `--coverage N`: grow the board until N per cent of the arena is Green, rather than
## stepping a fixed number of times and accepting whatever that produces.
##
## The two existing boards are the extremes and neither is a run. The patch settles near
## six per cent, which starves every territory Adaptation -- all four Bramble lines
## measured byte-identical to the bare Cane against a boss on it. The island reaches
## ninety-one, which starves nothing: Pruning holds a ring 100% of a bench there, is off
## its own ground 0.6% of the time and tears none, so anything paid for in *losing* the
## ring reads as worth nothing there. Harvest Rate buys recovery and measured +0.2% on
## siege for exactly that reason.
##
## Defined by the coverage it reaches rather than by a step count, so it stays the same
## board whatever the field tuning does later, and two rows grown to the same coverage
## are comparable by construction.
##
## It sets the *opening* coverage and does not hold it. Natural spread is pinned off for the
## row -- see `_apply_spread_pin` -- and the board still reaches about 89% of the arena
## inside forty seconds, because what grows it is the mass of the Blooms planted to
## establish it rather than the spread rate. A Bloom with enough mass to reach 30% has
## enough to reach 90%, so holding a coverage would mean establishing from many small
## Blooms instead, which this does not do.
##
## That matters for anything whose output is linear in the ground it can reach. Pruning's
## leaves come only from ground it can cut, so measuring it here reports a ring roughly
## twice as full as a build sustains without a territory Adaptation beside it -- which is
## what a played run found and what these boards could not show. The default patch board,
## which settles near 6% and stays there, is the scarce case; this one and `--island` are
## both abundant.
const COVERAGE_STEP_CAP := 4000

## `--walk`: Grandma on a slow circuit instead of rooted to one spot.
##
## The bench's stationary player is its oldest and least examined assumption, and it
## is not neutral. Almost every kit follows her -- turrets, sweeps, auras, Fruit --
## so standing still costs them nothing. Pruning is the exception: its whole contract
## is that it eats the ground beneath her and dies if she steps off, so a bench where
## she never moves is a bench that never charges the one Adaptation with a positional
## cost. Section 12 of the rework says exactly this and it has never been tested.
##
## A slow circle rather than a chase or a flee: it is the least opinionated movement
## that still makes her cross her own ground, and it keeps every build measured
## against the same path rather than against its own idea of good play.
## The default circle is deliberately tight -- barely wider than Pruning's own harvest
## disc -- so that it measures a player who fidgets rather than one who relocates.
## `--walk-radius` widens it, and the gap between a tight circle and a wide one is the
## only reading the bench has on whether moving *well* is worth anything.
const WALK_RADIUS_PIXELS := 70.0
const WALK_RADIANS_PER_SECOND := 0.55

## The five rosters section 33.3 of the Campaign rework asks for, now that a Campaign
## build is three Adaptations rather than two.
##
## Named here rather than passed in because the point of the list is that it is the
## *same* five every time: a sweep whose rosters move between runs cannot be compared
## with the run before it, which is most of what a balance instrument is for.
const ARCHETYPES := [
	{
		"label": "damage-heavy",
		"paths": [Progression.PathId.VINE, Progression.PathId.THISTLE, Progression.PathId.PRUNING],
	},
	{
		"label": "territory-heavy",
		"paths": [Progression.PathId.SPORE, Progression.PathId.BLOOM, Progression.PathId.ROOT],
	},
	{
		"label": "defensive-control",
		"paths": [Progression.PathId.BRAMBLE, Progression.PathId.ROOT, Progression.PathId.SPORE],
	},
	{
		"label": "mixed",
		"paths": [Progression.PathId.THISTLE, Progression.PathId.SPORE, Progression.PathId.ROOT],
	},
	{
		# Thistle + Vine is Thornwhip, and Root amplifies both halves of it. The case
		# the rework most wants watched after the mounted-head correction.
		"label": "evolution-synergy",
		"paths": [Progression.PathId.THISTLE, Progression.PathId.VINE, Progression.PathId.ROOT],
	},
]

var _kills := 0
## Bosses put down during a row, counted by role off `enemy_killed`.
var _targets_felled := 0
## Seeds that actually broke ground during a row, and Blooms that actually went off.
##
## Territory Adaptations are paid in events the damage column cannot see, and a row
## that reads identical to no Adaptation at all needs to be able to say whether the
## mechanic fired and did nothing or never fired. Those are different bugs.
var _sown := 0
var _germinations := 0
var _detonations := 0
var _rows: Array[Dictionary] = []
var _ranks := 3
var _evolved := false
var _pairs_only := ""
var _siege := false
## `--boss`: hold one tough target rather than a crowd, and which one.
var _boss := false
var _boss_role := EnemyKinds.Role.BOSS
var _evolution_rank := 5
## `--with`: an Adaptation held at full ranks underneath an `--isolate` sweep.
##
## `--isolate` answers "which of this Adaptation's lines carries it". It cannot answer
## "which of its lines carries the *pair*", which is a different question and the one
## the table's top seven all turn on. Vine contributes nothing whatever against a single
## target alone -- owned with no lines bought it measures byte-identical to having no
## Vine at all -- and yet Pruning+Vine is the strongest single-target build benched and
## tears three times the rings Pruning does. That interaction sits in neither
## Adaptation's own column, so neither sweep could see it.
##
## With a partner named, every row carries all of the partner's lines and varies only
## the isolated Adaptation, so the difference between two rows is still one line.
var _with_path := -1
## An explicit roster of two or three Paths, as "6-5" or "6-5-4".
var _build_only := ""
## Sweep the five named archetypes instead of every pair.
var _archetypes := false
## Bench each line of one Adaptation on its own, which is how a single line's
## contribution is separated from the Adaptation it belongs to.
var _isolate_path := -1
var _seed := DEFAULT_BENCH_SEED
var _island := false
## Per cent of the arena to grow Green to before a row starts; <= 0 keeps the fixed
## establish step counts.
var _coverage_target := 0.0
## The field's authored spread rate, captured once so a pinned row can restore it.
var _authored_spread_rate := -1.0
var _walk := false
var _walk_radius := WALK_RADIUS_PIXELS
## `--ring`: report Pruning's hold rather than its damage. The held population sits at
## the arena centre, so every step away from it costs contact for every build alike and
## the damage columns cannot say whether moving *well* pays. These three can: how much
## of the bench the ring was up, how much of it she had no Green underfoot, and how
## many times the ring tore loose.
var _ring_report := false
var _reference_orbit_capacity := 16
var _walk_angle := 0.0


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
			"--boss":
				_boss = true
				# The role is optional and only known words are taken, so a flag
				# following `--boss` falls through to its own case unharmed.
				if index + 1 < arguments.size():
					match arguments[index + 1]:
						"burrower":
							_boss_role = EnemyKinds.Role.BOSS
						"queen":
							_boss_role = EnemyKinds.Role.HIVE_QUEEN
						"elite":
							_boss_role = EnemyKinds.Role.ELITE
			"--pair":
				if index + 1 < arguments.size():
					_pairs_only = arguments[index + 1]
			"--build":
				# Two or three Path ids, so a Campaign roster can be benched as the
				# three Adaptations it actually is rather than as a pair plus a guess.
				if index + 1 < arguments.size():
					_build_only = arguments[index + 1]
			"--with":
				if index + 1 < arguments.size():
					_with_path = clampi(
						int(arguments[index + 1]), 0, Progression.PathId.size() - 1
					)
			"--archetypes":
				_archetypes = true
			"--island":
				_island = true
			"--coverage":
				if index + 1 < arguments.size():
					_island = true
					_coverage_target = clampf(float(arguments[index + 1]), 1.0, 95.0)
			"--ring":
				_ring_report = true
			"--walk":
				_walk = true
			"--walk-radius":
				if index + 1 < arguments.size():
					_walk = true
					_walk_radius = maxf(0.0, float(arguments[index + 1]))
			"--seed":
				# A second seed is how a reading is checked for having been a property
				# of the first one. Two seeds agreeing is a result; one is an anecdote.
				if index + 1 < arguments.size():
					_seed = int(arguments[index + 1])
			"--isolate":
				# One Adaptation's four lines, each bought alone. This is the answer to
				# "which Vine line is carrying Vine", which a whole-Adaptation row
				# cannot give however many times it is run.
				if index + 1 < arguments.size():
					_isolate_path = clampi(
						int(arguments[index + 1]), 0, Progression.PathId.size() - 1
					)


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
	run.combat.enemy_killed.connect(_count_kill)
	# A boss dying in a run opens a relic, a Branch slot and an Evolution. In a bench
	# that replaces one every few seconds that is not a reward, it is the row editing
	# its own build halfway through being measured -- and `_on_boss_defeated` calls
	# `unlock_branch_slot` before anything checks whether a run is even in progress, so
	# a third Adaptation would arrive whether a panel could open or not. The bench is
	# not a run and takes no milestones.
	run.combat.elite_defeated.disconnect(run._on_elite_defeated)
	run.combat.boss_defeated.disconnect(run._on_boss_defeated)
	run.combat.hive_queen_defeated.disconnect(run._on_hive_queen_defeated)
	run.overlay.seed_spawned.connect(
		func(_id: int, _p: Vector2) -> void: _sown += 1
	)
	run.overlay.seed_germinated.connect(
		func(_p: Vector2) -> void: _germinations += 1
	)
	run.overlay.bloom_detonated.connect(
		func(_p: Vector2, _d: int, _t: int, _s: float) -> void: _detonations += 1
	)

	print(
		"BALANCE_BENCH: %.0fs per build, %s held, ranks=%d, evolution=%s, seed=%d, board=%s, player=%s"
		% [
			BENCH_SECONDS,
			("1 %s" % _target_label()) if _boss
				else ("%d Hunters" % (SIEGE_POPULATION if _siege else TARGET_POPULATION)),
			_ranks,
			("rank %d" % _evolution_rank) if _evolved else "none",
			_seed,
			("%.0f%% grown" % _coverage_target) if _coverage_target > 0.0
				else ("island" if _island else "patch"),
			("walking r=%d" % int(_walk_radius)) if _walk else "rooted",
		]
	)
	if _isolate_path >= 0:
		await _sweep_lines(run)
	elif not _build_only.is_empty():
		await _sweep_explicit_build(run)
	elif _archetypes:
		await _sweep_archetypes(run)
	else:
		await _sweep_pairs(run)
	_report()
	quit(0)


func _count_kill(_position: Vector2, _xp: int, role: int, _source: int, _chain: int) -> void:
	_kills += 1
	if role == _boss_role:
		_targets_felled += 1


func _target_label() -> String:
	match _boss_role:
		EnemyKinds.Role.HIVE_QUEEN:
			return "Hive Queen"
		EnemyKinds.Role.ELITE:
			return "Rootbreaker"
		_:
			return "Burrower"


func _sweep_pairs(run: RunRoot) -> void:
	# The Cane alone, so every pair below is readable as what the *build* added. On a
	# crowded board the universal weapon is a large share of every row, and a table
	# without this line invites the reader to treat that share as the pair's.
	_rows.append(await _bench_build(run, [], "cane only", PackedInt32Array()))
	for first in range(Progression.PathId.size()):
		for second in range(first + 1, Progression.PathId.size()):
			if not _pairs_only.is_empty():
				var label := "%d-%d" % [first, second]
				if label != _pairs_only:
					continue
			_rows.append(await _bench_build(run, [first, second], ""))


func _sweep_archetypes(run: RunRoot) -> void:
	for archetype in ARCHETYPES:
		var paths: Array = archetype["paths"]
		_rows.append(await _bench_build(run, paths, String(archetype["label"])))


func _sweep_explicit_build(run: RunRoot) -> void:
	var paths: Array[int] = []
	for part in _build_only.split("-"):
		var path_id := int(part)
		if path_id >= 0 and path_id < Progression.PathId.size():
			paths.append(path_id)
	if paths.size() < 2:
		push_error("BALANCE_BENCH: --build needs at least two Path ids, as 6-5 or 6-5-4")
		return
	_rows.append(await _bench_build(run, paths, ""))


func _sweep_lines(run: RunRoot) -> void:
	## Every line of one Adaptation, bought alone to the bench's rank.
	##
	## The Adaptation itself is owned in every row -- its base mechanic is not a line
	## and cannot be switched off -- so the first row here is the Adaptation with
	## nothing bought, and every row after it is that same baseline plus one line. The
	## difference between them is the line, which is the number the rework's Vine and
	## Thistle questions both turn on.
	# The Cane alone, first. Every row below it includes the same Cane, and on a
	# crowded board the Cane is most of the damage in all of them -- Thistle with no
	# lines bought and Bramble with no lines bought measured within one per cent of
	# each other, which is not a fact about Thistle or Bramble. Without this row a
	# line that doubles its Adaptation's output reads as a rounding error, because it
	# is being divided by a baseline that has nothing to do with it.
	_rows.append(await _bench_build(run, [], "cane only", PackedInt32Array()))
	var roster: Array[int] = [_isolate_path]
	# An Adaptation cannot partner itself, and asking for it would reach
	# `debug_select_paths(n, n)` with a roster holding the same Path twice.
	if _with_path >= 0 and _with_path != _isolate_path:
		roster.append(_with_path)
		# All of the partner and none of the isolated Adaptation. The sweep had no way
		# to state this row before, and a pairing reading has no baseline without it:
		# every other row here carries the partner, so whatever the partner is worth by
		# itself was being folded into what the isolated line appeared to add.
		_rows.append(await _bench_build(
			run,
			[_with_path],
			"%s alone" % Progression.get_path_name(_with_path)
		))
	_rows.append(await _bench_build(run, roster, "base", PackedInt32Array()))
	for upgrade_id in run.progression.get_adaptation_line_ids(_isolate_path):
		_rows.append(await _bench_build(
			run,
			roster,
			Progression.get_upgrade_name(upgrade_id),
			PackedInt32Array([upgrade_id])
		))
	# The whole Adaptation, every line bought. The sweep could produce the bare
	# mechanic and each line alone but never the four together, so "one Adaptation at
	# full ranks" was a row the bench could not state at all -- `--pair` and `--build`
	# both require two. It is the natural top of this table, and the baseline any pair
	# ought to be read against.
	_rows.append(await _bench_build(run, roster, "all lines"))


func _bench_build(
	run: RunRoot,
	paths: Array,
	label: String,
	only_lines: Variant = null
) -> Dictionary:
	_prepare_board(run)
	_commit_build(run, paths, only_lines)
	var field := run.territory_field
	var green_before := field.get_player_percent()
	var hostile_before := field.get_hostile_percent()
	run.combat.debug_damage_applied_total = 0.0
	run.combat.debug_damage_dealt_total = 0.0
	run.combat.debug_damage_number_total = 0.0
	_kills = 0
	_targets_felled = 0
	_sown = 0
	_germinations = 0
	_detonations = 0

	var field_accumulator := 0.0
	var field_step := 1.0 / maxf(1.0, field.tuning.simulation_hz)
	var elapsed := 0.0
	var spawn_cursor := 0
	var damage_taken := 0.0
	var control_remaining := 0.0
	var control_samples := 0
	var ring_held := 0.0
	var ring_starved := 0.0
	var ring_spikes := 0.0
	# Seconds a held boss spent alive having already been hit, totalled over the ones
	# that actually died. Time under fire rather than time alive, because the walk in
	# is paid by every row alike and is not what any row is being measured on; and
	# closed on death rather than summed over the row, because the boss still standing
	# when the bench ends has been under fire for seconds that bought no kill, and
	# charging them to the kills before it reads as a build being slower than it is.
	var felled_engaged := 0.0
	var current_engaged := 0.0
	var felled_closed := 0
	var ring_samples := 0
	var slow_total := 0.0
	var tangle_total := 0.0
	var pinned_total := 0.0
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
		# The overlay and the field are paused by `_refresh_simulation_pause` whenever
		# the run considers itself not-RUNNING, and a bench that never calls
		# `RunRoot._process` has no way to un-pause them again: the flag is cleared on
		# a real frame this loop does not have. Asserted every step rather than once at
		# the top, because anything the row does can set it.
		_apply_spread_pin(run)
		run.overlay.effects_paused = false
		run.territory_field.simulation_paused = false
		run.player.simulation_paused = false
		run.overlay._process(STEP)
		# Her invulnerability frames, her damage-absorption window and her healing on
		# Mature Green all tick in `_physics_process`, which no frame ever calls here.
		# Left out, the first contact hit made her permanently invulnerable and the
		# damage-taken column read the same 6 points for every build on the board -
		# a number produced entirely by the instrument.
		run.player._physics_process(STEP)
		# Walk first, then aim. `_aim` sets her facing with a zero-delta move, so
		# doing it second leaves her facing the fight rather than her own path --
		# which is what a competent player does and what every other row assumes.
		_walk_player(run, STEP)
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
		_reference_orbit_capacity = run.pruning_director.orbit_capacity
		if run.pruning_director.is_holding():
			ring_held += STEP
		if not run.pruning_director.is_player_on_green():
			ring_starved += STEP
		ring_spikes += float(run.pruning_director.get_orbit_count())
		ring_samples += 1
		if _boss:
			var engaged := false
			for enemy in run.combat._enemies:
				if not enemy.active or enemy.role != _boss_role:
					continue
				if enemy.health < enemy.maximum_health:
					engaged = true
			if engaged:
				current_engaged += STEP
			if _targets_felled > felled_closed:
				felled_closed = _targets_felled
				felled_engaged += current_engaged
				current_engaged = 0.0
		control_remaining -= STEP
		if control_remaining <= 0.0:
			control_remaining = CONTROL_SAMPLE_SECONDS
			var sample := _sample_control(run)
			slow_total += float(sample["slow"])
			tangle_total += float(sample["tangle"])
			pinned_total += float(sample["pinned"])
			control_samples += 1
		elapsed += STEP
	field.recalculate_metrics_now()
	var samples := maxf(1.0, float(control_samples))

	return {
		"name": label if not label.is_empty() else _build_label(paths),
		"damage": run.combat.debug_damage_applied_total,
		"dealt": run.combat.debug_damage_dealt_total,
		"kills": _kills,
		"sown": _sown,
		"seeds": _germinations,
		"blooms": _detonations,
		"green_before": green_before,
		"green_after": field.get_player_percent(),
		# Hostile share pushed back over the bench. Negative is the ordinary result
		# and is the interesting one: the held population is eating the island, and
		# how much less of it a build loses is most of what a defensive kit is for.
		"reclaimed": hostile_before - field.get_hostile_percent(),
		"mature": field.get_mature_percent_of_arena(),
		"biomass": run.progression.biomass_earned_total,
		"taken": damage_taken,
		"slow": slow_total / samples,
		"tangle": tangle_total / samples,
		"pinned": pinned_total / samples,
		"ring_held": 100.0 * ring_held / BENCH_SECONDS,
		"ring_starved": 100.0 * ring_starved / BENCH_SECONDS,
		"rings_torn": run.pruning_director.get_rings_released(),
		"ring_spikes": ring_spikes / float(maxi(1, ring_samples)),
		"felled": _targets_felled,
		"felled_engaged": felled_engaged,
	}


func _build_label(paths: Array) -> String:
	var names := PackedStringArray()
	for path_id in paths:
		names.append(Progression.get_path_name(int(path_id)))
	return "+".join(names)


func _sample_control(run: RunRoot) -> Dictionary:
	## How held the board is, right now.
	##
	## Read off the live roster rather than counted as effects are applied, because
	## what matters is the state an enemy is in and not how many times something was
	## done to it: two Adaptations that each apply a slow once a second are not
	## equivalent if one of them expires in a tenth of a second.
	var slow := 0.0
	var tangle := 0.0
	var pinned := 0.0
	var counted := 0
	for enemy in run.combat._enemies:
		if not enemy.active:
			continue
		# A boss is left out of the crowd's control average on purpose -- it carries its
		# own CC resistance and one body among twenty-two would read as the crowd being
		# less held than it is. In `--boss` the boss is the only body there is, so the
		# same exclusion would leave these three columns reading zero for every row, and
		# a Bramble or Root row against a single target is paid in nothing else.
		if EnemyKinds.is_boss(enemy.role) and not _boss:
			continue
		counted += 1
		slow += clampf(1.0 - enemy.movement_speed_multiplier, 0.0, 1.0)
		tangle += clampf(enemy.entanglement, 0.0, 1.0)
		if enemy.bramble_ensnare_remaining > 0.0:
			pinned += 1.0
	var bodies := maxf(1.0, float(counted))
	return {
		"slow": slow / bodies,
		"tangle": tangle / bodies,
		"pinned": pinned / bodies,
	}


func _prepare_board(run: RunRoot) -> void:
	## The same starting board for every build: one Green island, grown from one Bloom
	## at the centre, with Grandma standing in the middle of it. A build is measured on
	## ground it did not choose, so what varies between rows is the build.
	# Before the reset, because the reset is what consumes it.
	run.progression.authored_run_seed = _seed
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
	var arena := field.tuning.arena_size
	if _island:
		for anchor in ISLAND_ANCHORS:
			field.queue_bloom(
				centre + Vector2(anchor.x * arena.x, anchor.y * arena.y),
				9.0, 1.6, 9.0, 3.0
			)
	else:
		field.queue_bloom(centre, 9.0, 1.6, 9.0, 3.0)
	if _authored_spread_rate < 0.0:
		_authored_spread_rate = field.tuning.natural_spread_rate
	_apply_spread_pin(run)
	if _coverage_target > 0.0:
		# Grown to a coverage rather than for a duration. Capped so a tuning that
		# cannot reach the target fails as a slow row rather than as a hang.
		var grown := 0
		while grown < COVERAGE_STEP_CAP:
			field.step_simulation()
			grown += 1
			if grown % 30 == 0:
				field.recalculate_metrics_now()
				if field.get_player_percent() >= _coverage_target:
					break
	else:
		for _step in range(ISLAND_ESTABLISH_STEPS if _island else GREEN_ESTABLISH_STEPS):
			field.step_simulation()
	field.recalculate_metrics_now()
	run.player.reset_player()
	_walk_angle = 0.0
	run.player.global_position = field.to_global(
		centre + Vector2.RIGHT * _walk_radius if _walk else centre
	)


func _apply_spread_pin(run: RunRoot) -> void:
	## Holds the field's spread rate where `--coverage` wants it.
	##
	## Asserted every step rather than set once, because several things put it back:
	## `reset_run` restores it from `RunRoot`'s own copy, and
	## `_apply_progression_modifiers` rewrites it as `base * expansion multiplier` --
	## which `_commit_build` calls after the board is prepared, so a pin applied there is
	## undone before the first step ever runs. Set once, the board grew to 89% anyway and
	## the pin read as doing nothing at all.
	run.territory_field.tuning.natural_spread_rate = (
		0.0 if _coverage_target > 0.0 else _authored_spread_rate
	)

func _commit_build(run: RunRoot, paths: Array, only_lines: Variant = null) -> void:
	## Puts the roster on the run and buys it to the bench's rank.
	##
	## Two Cores and any number of Branches, because a Campaign roster is three
	## Adaptations now. The Branch room is unlocked here rather than earned, since the
	## milestone that normally opens it is a fight this bench deliberately does not
	## have; what is being measured is what the build does, not how it was assembled.
	##
	## `only_lines` is the isolation mode: when it is a list, exactly those lines are
	## bought and every other line of the Adaptation stays at zero.
	var progression := run.progression
	if paths.is_empty():
		# No Adaptation at all: the Cane baseline every other row is measured over.
		progression.core_adaptations.clear()
		progression.branch_adaptations.clear()
		progression.paths_changed.emit()
		progression.upgrades_changed.emit()
		run._apply_progression_modifiers()
		return
	var first: int = int(paths[0])
	var second: int = int(paths[1]) if paths.size() > 1 else -1
	if second >= 0:
		progression.debug_select_paths(first, second)
	else:
		# A single-Adaptation row still has to enter the Adaptation. Paired with
		# itself is not a thing, so the Core slot is filled directly.
		progression.debug_select_paths(first, (first + 1) % Progression.PathId.size())
		progression.core_adaptations.clear()
		progression.core_adaptations.append(first)
		progression.paths_changed.emit()
	for index in range(2, paths.size()):
		progression.unlock_branch_slot()
		progression.debug_select_tertiary_path(int(paths[index]))
	for path_id in paths:
		# Isolation applies to the isolated Adaptation and to nothing else. A partner
		# named with `--with` is held at full ranks in every row, which is what makes it
		# a constant rather than a second variable.
		var isolate_this := (
			only_lines is PackedInt32Array and int(path_id) == _isolate_path
		)
		for upgrade_id in progression.get_adaptation_line_ids(int(path_id)):
			if isolate_this:
				progression._upgrade_levels[upgrade_id] = (
					_ranks if (only_lines as PackedInt32Array).has(upgrade_id) else 0
				)
			else:
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


func _walk_player(run: RunRoot, delta: float) -> void:
	if not _walk:
		return
	_walk_angle += WALK_RADIANS_PER_SECOND * delta
	var centre := run.territory_field.tuning.arena_size * 0.5
	var target := centre + Vector2.from_angle(_walk_angle) * _walk_radius
	var offset := target - run.player.get_arena_position()
	if offset.length_squared() <= 1.0:
		return
	run.player.move_with_intent(offset.normalized(), delta)


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
	if _boss:
		# Replaced the instant it falls, so the board is never empty and never a crowd.
		# Guarded rather than looped to satisfaction: the pool and the active cap can
		# both refuse a spawn, and a bench that spun here would hang instead of report.
		var attempts := 0
		while combat.get_active_enemy_count_by_role(_boss_role) < 1 and attempts < 8:
			attempts += 1
			var boss_angle := float(cursor) * 2.39996
			cursor += 1
			var boss_position := (
				run.player.get_arena_position()
				+ Vector2.from_angle(boss_angle) * BOSS_RING_PIXELS
			)
			if not run.territory_field.contains_local_point(boss_position):
				continue
			combat.spawn_enemy(_boss_role, boss_position)
		return cursor
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
	if _ring_report:
		print(
			"BALANCE_BENCH: build | ring held %% | no Green underfoot %% | rings torn "
			+ "loose | mean spikes of %d" % _reference_orbit_capacity
		)
		for row in by_damage:
			print(
				"RING_ROW	%s	%.1f	%.1f	%d	%.2f"
				% [
					row["name"], row["ring_held"], row["ring_starved"],
					row["rings_torn"], row["ring_spikes"]
				]
			)
		print("")
	if _boss:
		print(
			"BALANCE_BENCH: build | %s felled | mean s under fire each | applied | "
			% _target_label()
			+ "dealt | wasted %% | mean spikes of %d" % _reference_orbit_capacity
		)
		print(
			"BALANCE_BENCH: (wasted = damage fired into health that was not there, which
"
			+ " is what an eight-target ring does to a lone body)"
		)
		for row in by_damage:
			var felled: int = int(row["felled"])
			var dealt := float(row["dealt"])
			var applied := float(row["damage"])
			print(
				"BOSS_ROW	%s	%d	%s	%.0f	%.0f	%.1f	%.2f"
				% [
					row["name"],
					felled,
					# A row that never put one down reports so rather than reporting a
					# time-to-kill it did not achieve; the applied column says how close.
					("%.2f" % (float(row["felled_engaged"]) / float(felled)))
						if felled > 0 else "never",
					applied,
					dealt,
					100.0 * (dealt - applied) / maxf(1.0, dealt),
					row["ring_spikes"],
				]
			)
		print("")
	print(
		"BALANCE_BENCH: build | damage | dealt | kills | seeds | blooms | green | "
		+ "mature | rot_pushed | biomass | taken | slow | tangle | pinned"
	)
	print(
		"BALANCE_BENCH: (sown = Seeds planted, seeds = Seeds that broke ground)"
	)
	for row in by_damage:
		print(
			"BENCH_ROW	%s	%.0f	%.0f	%d	%d	%d	%d	%.2f	%.2f	%.2f	%.1f	%.0f	%.3f	%.3f	%.3f"
			% [
				row["name"],
				row["damage"],
				row["dealt"],
				row["kills"],
				row["sown"],
				row["seeds"],
				row["blooms"],
				row["green_after"],
				row["mature"],
				row["reclaimed"],
				row["biomass"],
				row["taken"],
				row["slow"],
				row["tangle"],
				row["pinned"],
			]
		)
	var total := 0.0
	for row in _rows:
		total += row["damage"]
	var average := total / maxf(1.0, float(_rows.size()))
	print("BALANCE_BENCH: %d builds, mean damage %.0f" % [_rows.size(), average])
	# Damage against the sweep's own mean, and beside it the two columns a build can
	# be worth something on without appearing in the damage order at all. A row near
	# the bottom of the damage index with a high control index is not a weak build; a
	# row near the bottom of both is the thing the rank-1 sweep is looking for.
	for row in by_damage:
		print(
			"BENCH_INDEX\t%s\tdamage %.2f\tcontrol %.2f\tground %.2f"
			% [
				row["name"],
				row["damage"] / maxf(1.0, average),
				float(row["slow"]) + float(row["tangle"]),
				float(row["green_after"]) + float(row["mature"]),
			]
		)
