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
## Provocation is the other half of Campaign pacing, and it is a *policy* rather than
## a number: the same build finishes at very different times depending on how often
## the player dares the garden to escalate. `--provoke` picks one of three, so the
## same roster can be run four ways and the spread compared.
##
## Never and aggressive are the two ends. Moderate is the interesting one -- it calls
## the next wave only once the board is back under control, which is what a player
## who is ahead but not reckless actually does.
##
## Run: godot --headless --path . --script tools/pacing_probe.gd -- --pair 5-6
##      godot --headless --path . --script tools/pacing_probe.gd -- --pair 0-3 --campaign
##      godot --headless --path . --script tools/pacing_probe.gd -- --build 6-5-3 --campaign
##      godot --headless --path . --script tools/pacing_probe.gd -- --build 6-5-3 --campaign --provoke aggressive

const STEP := 1.0 / 60.0
const SAMPLE_SECONDS := 60.0
## Live enemies below which the moderate policy considers the board back in hand.
const MODERATE_CLEAR_ENEMIES := 8

enum ProvokePolicy {
	## Never call a wave early. The baseline runtime the Campaign is authored for.
	NEVER,
	## Call only once the board is back under control, which is what being genuinely
	## ahead of a wave looks like from the player's side.
	MODERATE,
	## Call at the first legal moment, every time.
	AGGRESSIVE,
}

var _first := Progression.PathId.THISTLE
var _second := Progression.PathId.VINE
## The third Adaptation, or -1 for the two-Path rosters the pair sweep uses.
var _third := -1
var _campaign := false
var _provoke := ProvokePolicy.NEVER
## Blight forced at the start of the run, so the same build can be driven at 0 and at
## V and the difference read off two tables instead of out of the Blight table's
## percentages. Negative leaves the run to earn its own.
var _forced_blight := -1
## The seed every draw in the run comes out of.
##
## Pinned, for the same reason the bench's is. `reset_run` rolls a fresh one unless
## the scene authors one, so two runs of the same roster were two different games:
## the same build, same flags and same policy came back at 73% ground held and at
## 37%, which is a spread wide enough to swallow whatever was being compared. A
## pacing table is a comparison between rows, and rows have to share a world.
var _seed := 20260920
var _kills := 0
var _picks := 0
var _provocations := 0
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
			"--build":
				# Two or three Path ids. A Campaign roster is three Adaptations now,
				# and a pacing report built from two of them is measuring a build the
				# player cannot actually have.
				if index + 1 < arguments.size():
					var parts := String(arguments[index + 1]).split("-")
					if parts.size() >= 2:
						_first = int(parts[0])
						_second = int(parts[1])
					if parts.size() >= 3:
						_third = int(parts[2])
			"--provoke":
				if index + 1 < arguments.size():
					match String(arguments[index + 1]):
						"moderate":
							_provoke = ProvokePolicy.MODERATE
						"aggressive":
							_provoke = ProvokePolicy.AGGRESSIVE
						_:
							_provoke = ProvokePolicy.NEVER
			"--seed":
				if index + 1 < arguments.size():
					_seed = int(arguments[index + 1])
			"--blight":
				if index + 1 < arguments.size():
					_forced_blight = int(arguments[index + 1])
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

	# Both, the way `RunRoot._ready` does it. Configuring only the wave director gave
	# a Campaign schedule running Quick's progression rules -- four Adaptations and
	# Paths drafted out of ordinary level-ups -- which is not a build the Campaign can
	# actually produce, and the rank ceiling in the table below said so.
	var mode := RunMode.Id.CAMPAIGN if _campaign else RunMode.Id.QUICK
	run.wave_director.configure_mode(mode)
	run.progression.configure_mode(mode)
	# Before `reset_run`, which is what consumes it.
	run.progression.authored_run_seed = _seed
	run.reset_run()
	run.set_process(false)
	run.combat.set_process(false)
	run.territory_field.set_process(false)
	run.overlay.set_process(false)
	run.player.input_enabled = false
	run.progression.debug_select_paths(_first, _second)
	if _third >= 0:
		run.progression.unlock_branch_slot()
		run.progression.debug_select_tertiary_path(_third)
	# Campaign opens by asking for its first Adaptation, and the chooser holds the
	# run still until it is answered. The roster is already committed above, so the
	# panel is dismissed rather than played.
	if run._choice_kind != RunRoot.ChoiceKind.NONE:
		run._choose_displayed_option(0)
	if _forced_blight >= 0:
		run.wave_director.debug_set_blight(_forced_blight)

	print(
		"PACING: %s mode, %s, provoke=%s, blight=%s, seed=%d, %.0fs run"
		% [
			"Campaign" if _campaign else "Quick",
			_roster_label(),
			_policy_name(),
			run.wave_director.get_blight_name(),
			_seed,
			run.wave_director.run_duration_seconds,
		]
	)
	print(
		"PACING_HEAD	minute	wave	level	picks	ranks	evo	kills	alive"
		+ "	green%	hunter_hp	damage	taken	blight	provoked	growth"
	)

	var field := run.territory_field
	var field_step := 1.0 / maxf(1.0, field.tuning.simulation_hz)
	var field_accumulator := 0.0
	var elapsed := 0.0
	var next_sample := SAMPLE_SECONDS
	var duration := run.wave_director.run_duration_seconds
	while elapsed < duration:
		_answer_any_choice(run)
		_maybe_provoke(run)
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
	print(
		"PACING_END	wave %d	played %.0fs	blight %s	provocations %d	growth %d"
		% [
			run.wave_director.get_current_wave_number(),
			run.wave_director.real_elapsed_seconds,
			run.wave_director.get_blight_name(),
			_provocations,
			run.progression.get_growth_total_ranks(),
		]
	)


func _roster_label() -> String:
	var names := PackedStringArray([
		Progression.get_path_name(_first),
		Progression.get_path_name(_second),
	])
	if _third >= 0:
		names.append(Progression.get_path_name(_third))
	return "+".join(names)


func _policy_name() -> String:
	match _provoke:
		ProvokePolicy.MODERATE:
			return "moderate"
		ProvokePolicy.AGGRESSIVE:
			return "aggressive"
	return "never"


func _maybe_provoke(run: RunRoot) -> void:
	## The policy, applied. Nothing here reads the build: it reads the board, exactly
	## as the availability rule does, so the probe cannot provoke on information a
	## player would not have.
	if _provoke == ProvokePolicy.NEVER:
		return
	if run._choice_kind != RunRoot.ChoiceKind.NONE:
		return
	if not run.wave_director.can_provoke():
		return
	if _provoke == ProvokePolicy.MODERATE:
		# Back under control: most of what the wave sent is gone. A player calling
		# the next wave while still swamped is the aggressive policy, not this one.
		if run.combat.get_active_enemy_count() > MODERATE_CLEAR_ENEMIES:
			return
	if run.wave_director.provoke() > 0.0:
		_provocations += 1


func _sample(run: RunRoot, elapsed: float) -> void:
	print(
		"PACING_ROW	%d	%d	%d	%d	%d/%d	%d	%d	%d	%.1f	%.0f	%.0f	%.0f	%s	%d	%d"
		% [
			int(round(elapsed / 60.0)),
			run.wave_director.get_current_wave_number(),
			run.progression.current_level,
			_picks,
			_core_ranks(run),
			_roster_rank_ceiling(run),
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
			run.wave_director.get_blight_name(),
			_provocations,
			run.progression.get_growth_total_ranks(),
		]
	)


func _roster_rank_ceiling(run: RunRoot) -> int:
	## Every ordinary rank the roster could hold, so the ranks column reads against the
	## build the run is actually allowed rather than against a fixed twenty-four.
	var ceiling := 0
	for path_id in run.progression.get_owned_adaptations():
		for upgrade_id in run.progression.get_adaptation_line_ids(path_id):
			ceiling += run.progression.get_upgrade_maximum_level(upgrade_id)
	return ceiling


func _core_ranks(run: RunRoot) -> int:
	## Ordinary ranks bought across the whole roster, against the ceiling beside it.
	##
	## The roster rather than the Core pair: a Campaign build is three Adaptations and
	## the third one is a real part of it, so counting only two would report a
	## completed build as two thirds finished for the whole back half of the run.
	var ranks := 0
	for path_id in run.progression.get_owned_adaptations():
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
	var evolution_lines := PackedInt32Array()
	for evolution_id in run.progression.get_active_evolutions():
		evolution_lines.append(run.evolutions.get_evolution_upgrade_id(evolution_id))
	for index in range(options.size()):
		# Ranking a claimed Evolution outranks any ordinary line. A player who has
		# seen what their Evolution does buys it on sight, and an instrument that
		# quietly preferred ordinary lines would report the Evolution arriving later
		# than it ever needs to - which is the number this probe exists to get right.
		#
		# Claiming one is no longer a card in this draft at all: an Evolution reward
		# is its own panel now, answered by the same greedy policy in `_choose`.
		if evolution_lines.has(options[index]):
			chosen = index
			break
		if not _is_core_line(run, options[index]):
			continue
		# Among Core lines, the one nearest its ceiling. An Evolution unlocks on five
		# owned ranks in each half of the pair, so finishing a line is worth more than
		# starting one - and a policy that spread its picks evenly took far longer to
		# qualify than a player aiming at it needs. That gap was the instrument's, not
		# the game's, and it is the number the whole Evolution question turns on.
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
