extends SceneTree

## What a Campaign wave actually produces, wave by wave, for the four Trials that
## are a number rather than a rule.
##
## Patience allows 45 kills, Pressure allows 24 standing at once, Groundwork asks for
## 15 kills the Cane did not land and Stillness asks for 20 quiet seconds at the top
## of the wave. Every one of those was written as a guess. A guess is fine for a rule
## -- "do not step off your Green" is either interesting or it is not -- but a
## *threshold* that nobody has measured is the thing that makes an optional challenge
## either free or impossible, and the player cannot tell which until they have spent a
## wave on it.
##
## So this drives a Campaign run with the Cane defending itself and reports, per wave:
## kills, how many of those the Cane did not land, the peak concurrent board, and how
## long the wave took to produce its first kill. Read against the Trial waves -- 6, 11
## and 16 -- those four columns are the four numbers.
##
## Grandma stands still and is kept alive, exactly as in the pacing probe and for the
## same reason: this measures what the schedule produces, not what a player's hands do
## with it. A real player kills faster, so the kill columns are a floor.
##
## Run: godot --headless --path . --script tools/trial_numbers_probe.gd
##      godot --headless --path . --script tools/trial_numbers_probe.gd -- --waves 17

const STEP := 1.0 / 30.0

var _kills := 0
var _off_cane_kills := 0
var _first_kill_at := -1.0
var _peak_alive := 0
var _wave_elapsed := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var waves := _int_argument("--waves", 17)
	change_scene_to_file("res://scenes/run/run.tscn")
	await process_frame
	await process_frame
	var run := current_scene as RunRoot
	if run == null:
		push_error("TRIAL_NUMBERS: the run scene did not load")
		quit(1)
		return
	run.set_process(false)
	run.player.input_enabled = false
	run.combat.set_process(false)
	run.adaptation_director.set_process(false)
	run.overlay.set_process(false)
	run.wave_director.configure_mode(RunMode.Id.CAMPAIGN)
	run.reset_run()
	run.wave_director.configure_mode(RunMode.Id.CAMPAIGN)
	# A full roster, so the kill rate is a built run's rather than an empty one's.
	run.progression.debug_select_paths(
		Progression.PathId.SPORE, Progression.PathId.ROOT
	)
	run.progression.debug_select_branch_paths(
		Progression.PathId.BRAMBLE, Progression.PathId.THISTLE
	)
	if run._choice_kind != RunRoot.ChoiceKind.NONE:
		run._choose_displayed_option(0)
	run.player.maximum_health = 1000000.0
	run.player.heal(1000000.0)
	run.combat.enemy_killed.connect(_on_kill)

	print("TRIAL_NUMBERS\twave\tkills\toff_cane\tpeak_alive\tfirst_kill_s\tgreen")
	var wave := run.wave_director.get_current_wave_number()
	var elapsed := 0.0
	while wave <= waves:
		elapsed += STEP
		_wave_elapsed += STEP
		run.advance_run(STEP)
		run.combat.simulate_step(STEP)
		run.adaptation_director.advance(STEP)
		if int(elapsed * 30.0) % 4 == 0:
			run.territory_field.step_simulation()
		_peak_alive = maxi(_peak_alive, run.combat.get_active_enemy_count())
		# A level-up chooser pauses the directors, so it is answered and the wave
		# carries on. Which upgrade is taken does not matter here; that the run keeps
		# moving does.
		if run._choice_kind != RunRoot.ChoiceKind.NONE:
			run._choose_displayed_option(0)
		var current := run.wave_director.get_current_wave_number()
		if current == wave:
			continue
		_report(wave, run)
		wave = current

	quit(0)


func _report(wave: int, run: RunRoot) -> void:
	print(
		"TRIAL_ROW\t%d\t%d\t%d\t%d\t%s\t%.0f"
		% [
			wave,
			_kills,
			_off_cane_kills,
			_peak_alive,
			"%.1f" % _first_kill_at if _first_kill_at >= 0.0 else "none",
			run.territory_field.get_player_percent(),
		]
	)
	_kills = 0
	_off_cane_kills = 0
	_peak_alive = 0
	_first_kill_at = -1.0
	_wave_elapsed = 0.0


func _on_kill(
	_position: Vector2,
	_xp_value: int,
	_role: int,
	death_source: int,
	_chain_depth: int
) -> void:
	_kills += 1
	if death_source != CombatDirector.DeathSource.CANE:
		_off_cane_kills += 1
	if _first_kill_at < 0.0:
		_first_kill_at = _wave_elapsed


func _int_argument(flag: String, fallback: int) -> int:
	var arguments := OS.get_cmdline_user_args()
	var index := arguments.find(flag)
	if index < 0 or index + 1 >= arguments.size():
		return fallback
	return int(arguments[index + 1])
