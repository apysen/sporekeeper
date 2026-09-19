extends SceneTree

## Drives a whole run on a fixed clock and records what the player would have, minute by
## minute: which wave, what level, how many upgrade picks spent, how much ground held,
## and how hard the enemies currently hit.
##
## The balance bench asks what a finished build does. This asks the other half of the
## same question - *when does a build become that build*, and what is the wave doing
## while it waits. A pair that is unbeatable at rank 3 is not a problem if rank 3 lands
## at minute eleven of twelve; a pair that is merely good is a problem if it is complete
## by minute four. Neither fact is visible in a table of upgrade values.
##
## Upgrades are taken by a policy rather than by a player: Core pair lines first, then
## the Evolution when it is offered, then anything. That is the greedy build-completing
## line, so the picks column is the *fastest* a build can come together rather than the
## average one.
##
## Grandma stands still and is kept alive, exactly as in the bench, and for the same
## reason: this measures the run's schedule, not a player's hands.
##
## Run: godot --headless --path . --script tools/pacing_probe.gd -- --pair 5-6
##      godot --headless --path . --script tools/pacing_probe.gd -- --pair 0-3 --campaign

const STEP := 1.0 / 60.0
const SAMPLE_SECONDS := 60.0

var _first := Progression.PathId.THISTLE
var _second := Progression.PathId.VINE
var _campaign := false
var _kills := 0
var _picks := 0
var _pick_log: Array[String] = []
var _damage_taken := 0.0


func _initialize() -> void:
	_read_arguments()
	call_deferred("_run")


func _read_arguments() -> void:
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size()):
		match arguments[index]:
			"--pair":
				if index + 1 < arguments.size():
					var halves := String(arguments[index + 1]).split("-")
					if halves.size() == 2:
						_first = int(halves[0])
						_second = int(halves[1])
			"--campaign":
				_campaign = true


func _run() -> void:
	if change_scene_to_file("res://scenes/run/run.tscn") != OK:
		push_error("PACING: the run scene did not load")
		quit(1)
		return
	await process_frame
	await process_frame
	var run := current_scene as RunRoot
	if run == null:
		push_error("PACING: the run scene did not become a RunRoot")
		quit(1)
		return
	run.set_process(false)
	run.combat.set_process(false)
	run.territory_field.set_process(false)
	run.overlay.set_process(false)
	run.player.input_enabled = false
	run.combat.debug_damage_accounting = true
	run.combat.enemy_killed.connect(
		func(_p: Vector2, _xp: int, _r: int, _s: int, _c: int) -> void: _kills += 1
	)

	run.wave_director.configure_mode(
		RunMode.Id.CAMPAIGN if _campaign else RunMode.Id.QUICK
	)
	run.reset_run()
	run.set_process(false)
	run.combat.set_process(false)
	run.territory_field.set_process(false)
	run.overlay.set_process(false)
	run.player.input_enabled = false
	run.progression.debug_select_paths(_first, _second)

	print(
		"PACING: %s mode, %s+%s, %.0fs run"
		% [
			"Campaign" if _campaign else "Quick",
			Progression.get_path_name(_first),
			Progression.get_path_name(_second),
			run.wave_director.run_duration_seconds,
		]
	)
	print(
		"PACING_HEAD	minute	wave	level	picks	core_ranks	evo	kills	alive"
		+ "	green%	hunter_hp	damage	taken"
	)

	var field := run.territory_field
	var field_step := 1.0 / maxf(1.0, field.tuning.simulation_hz)
	var field_accumulator := 0.0
	var elapsed := 0.0
	var next_sample := SAMPLE_SECONDS
	var duration := run.wave_director.run_duration_seconds
	while elapsed < duration:
		_answer_any_choice(run)
		run.advance_run(STEP)
		_aim(run)
		run.combat.simulate_step(STEP)
		run.overlay._process(STEP)
		# Her invulnerability frames, her damage-absorption window and her healing on
		# Mature Green all tick in `_physics_process`, which no frame ever calls here.
		# Left out, the first contact hit made her permanently invulnerable and the
		# damage-taken column read the same 6 points for every build on the board -
		# a number produced entirely by the instrument.
		run.player._physics_process(STEP)
		run.adaptation_director.advance(STEP)
		field_accumulator += STEP
		while field_accumulator >= field_step:
			field.step_simulation()
			field_accumulator -= field_step
		_damage_taken += run.player.get_max_health() - run.player.get_health()
		run.player.heal(1000.0)
		elapsed += STEP
		if elapsed >= next_sample:
			next_sample += SAMPLE_SECONDS
			field.recalculate_metrics_now()
			_sample(run, elapsed)
	print("PACING: picks in order -> %s" % ", ".join(_pick_log))


func _sample(run: RunRoot, elapsed: float) -> void:
	print(
		"PACING_ROW	%d	%d	%d	%d	%d/24	%d	%d	%d	%.1f	%.0f	%.0f	%.0f"
		% [
			int(round(elapsed / 60.0)),
			run.wave_director.get_current_wave_number(),
			run.progression.current_level,
			_picks,
			_core_ranks(run),
			run.progression.get_evolution_upgrade_level(),
			_kills,
			# How far behind the build is: population only climbs when the schedule is
			# spawning faster than the build can clear, so this is the difficulty curve
			# as the player actually feels it.
			run.combat.get_active_enemy_count(),
			run.territory_field.get_player_percent(),
			_sample_hunter_health(run),
			run.combat.debug_damage_applied_total,
			_damage_taken,
		]
	)


func _core_ranks(run: RunRoot) -> int:
	## Ranks bought across the eight Core-pair lines, out of the 24 that complete them.
	var ranks := 0
	for path_id in [_first, _second]:
		for upgrade_id in run.progression.get_adaptation_line_ids(path_id):
			ranks += run.progression.get_owned_upgrade_level(upgrade_id)
	return ranks


func _sample_hunter_health(run: RunRoot) -> float:
	## What a plain Hunter is worth right now, which is the wave curve expressed in the
	## only unit a build cares about: how much damage one body costs to remove.
	for enemy_id in run.combat.get_active_enemy_ids():
		if run.combat.get_enemy_role(enemy_id) == EnemyKinds.Role.HUNTER:
			return run.combat.get_enemy_maximum_health(enemy_id)
	return 0.0


func _answer_any_choice(run: RunRoot) -> void:
	## Takes the offered upgrade the way a player building toward their pair would:
	## the Evolution whenever it appears, then a Core line, then whatever is left.
	if run._choice_kind == RunRoot.ChoiceKind.NONE:
		return
	var options := run.progression.get_pending_upgrade_options()
	if options.is_empty():
		run._choose_displayed_option(0)
		return
	var chosen := 0
	var chosen_is_core := false
	var evolution_line := run.evolutions.get_evolution_upgrade_id(
		run.evolutions.active_evolution
	)
	for index in range(options.size()):
		# Claiming the pairing, then ranking it, outranks any ordinary line. A player
		# who has seen what their Evolution does buys it on sight, and an instrument
		# that quietly preferred ordinary lines would report the Evolution arriving
		# later than it ever needs to - which is the number this probe exists to get
		# right.
		if options[index] == Progression.EVOLUTION_DRAFT_OPTION:
			chosen = index
			break
		if evolution_line >= 0 and options[index] == evolution_line:
			chosen = index
			break
		if not _is_core_line(run, options[index]):
			continue
		# Among Core lines, the one nearest its ceiling. The Evolution unlocks on *two
		# mastered lines in each Core*, so finishing a line is worth more than starting
		# one - and a policy that spread its picks evenly took 21 of them to claim the
		# pairing where a player aiming at it needs 12. That gap was the instrument's,
		# not the game's, and it is the number the whole Evolution question turns on.
		if (
			chosen_is_core
			and run.progression.get_owned_upgrade_level(options[index])
			<= run.progression.get_owned_upgrade_level(options[chosen])
		):
			continue
		chosen = index
		chosen_is_core = true
	_picks += 1
	_pick_log.append(_describe_option(run, options[chosen]))
	run._choose_displayed_option(chosen)


func _is_core_line(run: RunRoot, upgrade_id: int) -> bool:
	for path_id in [_first, _second]:
		if run.progression.get_adaptation_line_ids(path_id).has(upgrade_id):
			return true
	return false


func _describe_option(run: RunRoot, upgrade_id: int) -> String:
	if upgrade_id == Progression.EVOLUTION_DRAFT_OPTION:
		return "EVOLUTION"
	return run.progression.get_upgrade_name(upgrade_id)


func _aim(run: RunRoot) -> void:
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
