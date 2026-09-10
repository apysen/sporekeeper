extends SceneTree

## Does the final wave get reinforcements, and does clearing the arena end the break?
##
## Two things this checks, both of which were true of Quick and not of Campaign.
##
## Campaign is 25 waves of one minute, and its reinforcements stop at 24:45, so its
## final wave is a wave: three quarters of it spawns and the last fifteen seconds
## are fought. Quick has never had that problem either: its cleanup is the last
## thirty seconds of the run.
##
## And a Quick wave opens with a grace period. Standing in a cleared arena waiting
## for it
## to elapse is the game withholding the next wave from a player who has already
## earned it, so an empty arena now ends the break early.
##
## Run: godot --headless --script tests/wave_cadence_probe.gd

const STEP := 1.0 / 60.0

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_error := change_scene_to_file("res://scenes/run/run.tscn")
	if load_error != OK:
		push_error("Unable to load Sporekeeper run: %s" % error_string(load_error))
		quit(1)
		return
	await process_frame
	await process_frame
	var prototype := current_scene as RunRoot
	if prototype == null:
		push_error("Sporekeeper run scene did not become current")
		quit(1)
		return
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.combat.set_process(false)
	prototype.adaptation_director.set_process(false)
	prototype.player.maximum_health = 1000000000.0
	prototype.player.reset_player()

	_check_final_wave_spawns(
		prototype,
		RunMode.Id.CAMPAIGN,
		CampaignWaves.WAVE_COUNT,
		CampaignWaves.CAMPAIGN_DURATION_SECONDS
	)
	# Deliberately after Campaign. The director outlives a run, so this is also the
	# case where Quick used to inherit Campaign's thirty-minute clock.
	_check_final_wave_spawns(prototype, RunMode.Id.QUICK, 12, 720.0)
	_check_mode_switch_restores(prototype)
	_check_grace_skipped_when_clear(prototype)
	_check_grace_holds_while_enemies_live(prototype)

	prototype.queue_free()
	await process_frame

	if _failures.is_empty():
		print("WAVE_CADENCE: PASS (%d checks)" % _checks)
		quit(0)
		return
	for line in _failures:
		print(line)
	push_error("WAVE_CADENCE: %d failure(s)" % _failures.size())
	quit(1)


func _check_final_wave_spawns(
	prototype: RunRoot, mode: int, final_wave: int, run_seconds: float
) -> void:
	## The last wave must contain at least one moment where the director would
	## spawn. Checked by asking the director, not by counting enemies, so a full
	## arena cannot disguise a cleanup that started too early.
	var director := prototype.wave_director
	director.configure_mode(mode)
	director.reset_director()

	var wave_duration: float = director.wave_duration_seconds
	var final_wave_start := float(final_wave - 1) * wave_duration
	if final_wave_start >= run_seconds:
		_failures.append(
			"WAVE_CADENCE %s: wave %d starts at %.0fs, past the %.0fs run"
			% [_mode_name(mode), final_wave, final_wave_start, run_seconds]
		)
		return

	_checks += 1
	var cleanup_at: float = director.cleanup_time_seconds
	if cleanup_at <= final_wave_start:
		_failures.append(
			(
				"WAVE_CADENCE %s: cleanup begins at %.0fs but the final wave (%d) "
				+ "starts at %.0fs, so no reinforcements arrive in it at all"
			) % [
				_mode_name(mode),
				cleanup_at,
				final_wave,
				final_wave_start,
			]
		)
		return
	print(
		"WAVE_CADENCE %-8s wave %d spans %.0f-%.0fs, cleanup at %.0fs -- %.0fs of it spawns"
		% [
			_mode_name(mode),
			final_wave,
			final_wave_start,
			run_seconds,
			cleanup_at,
			cleanup_at - final_wave_start,
		]
	)


func _check_mode_switch_restores(prototype: RunRoot) -> void:
	## Configuring a mode must say what that mode is, not what has changed since the
	## last one.
	var director := prototype.wave_director
	_checks += 1
	director.configure_mode(RunMode.Id.CAMPAIGN)
	var campaign_run: float = director.run_duration_seconds
	director.configure_mode(RunMode.Id.QUICK)
	var quick_run: float = director.run_duration_seconds
	var quick_cleanup: float = director.cleanup_time_seconds
	var quick_boss: float = director.boss_time_seconds
	if quick_run >= campaign_run or quick_cleanup > quick_run:
		_failures.append(
			(
				"WAVE_CADENCE: Quick kept Campaign's clock after a mode switch -- "
				+ "run %.0fs, cleanup %.0fs, boss %.0fs"
			) % [quick_run, quick_cleanup, quick_boss]
		)
		return
	print(
		"WAVE_CADENCE          switching Campaign -> Quick restores run %.0fs, cleanup %.0fs, boss %.0fs"
		% [quick_run, quick_cleanup, quick_boss]
	)


func _mode_name(mode: int) -> String:
	## Spelled out here rather than through RunMode.get_name, whose name
	## collides with a built-in and resolves to the wrong one.
	return "CAMPAIGN" if mode == RunMode.Id.CAMPAIGN else "QUICK"


func _check_grace_skipped_when_clear(prototype: RunRoot) -> void:
	## An empty arena during a wave's opening break should end the break.
	var director := prototype.wave_director
	director.configure_mode(RunMode.Id.QUICK)
	director.reset_director()
	prototype.combat.reset_combat()
	_checks += 1

	# Two seconds into wave 2, which is inside the five second break.
	director.debug_advance_time(director.wave_duration_seconds + 2.0)
	if director.get_current_wave_number() != 2:
		_failures.append("WAVE_CADENCE: expected wave 2, got %d" % director.get_current_wave_number())
		return
	if prototype.combat.get_active_enemy_count() != 0:
		_failures.append("WAVE_CADENCE: arena should be empty for this case")
		return
	if director.is_grace_period_active():
		_failures.append(
			"WAVE_CADENCE: the break is still running with the arena cleared -- "
			+ "the player is waiting on a timer they have already beaten"
		)
		return
	print("WAVE_CADENCE          cleared arena ends the wave break early")


func _check_grace_holds_while_enemies_live(prototype: RunRoot) -> void:
	## The break is a break. It should only be cut short by clearing the arena, not
	## by the arena happening to be quiet for other reasons.
	var director := prototype.wave_director
	director.configure_mode(RunMode.Id.QUICK)
	director.reset_director()
	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	_checks += 1

	prototype.combat.spawn_enemy(
		EnemyKinds.Role.GRAZER, Vector2(320.0, 300.0)
	)
	if prototype.combat.get_active_enemy_count() == 0:
		_failures.append("WAVE_CADENCE: could not spawn the enemy this case needs")
		return
	# Advanced in steps, because the skip is decided as time passes rather than in
	# one jump, and a single jump would not exercise it the way a run does.
	var target := director.wave_duration_seconds + 2.0
	while director.elapsed_seconds < target:
		director.advance(STEP)
	if not director.is_grace_period_active():
		_failures.append(
			"WAVE_CADENCE: the break ended with an enemy still alive, so it can be "
			+ "skipped without clearing the arena"
		)
		return
	print("WAVE_CADENCE          the break holds while an enemy is alive")
