extends SceneTree

## The whole path, through the file: a run launched the way the menu launches one,
## saved by crossing a wave boundary, loaded back into a second run scene, and then
## finished so the save is dropped and the record kept.
##
## `run_smoke`'s persistence module proves that a captured run restores correctly; it
## does it in memory, on one scene, because a suite must not write the player's save.
## What it cannot prove is the wiring around that: that a launched run turns saving on
## and a probe-loaded one does not, that a wave boundary is what writes, that the
## resume request is honored on the next scene, and that finishing clears the file.
## That needs two real scene loads and the real path, so it is its own probe - and it
## holds the machine's own save and puts it back, the way `save_store_probe` does.
##
## Run: godot --headless --path . --script tests/integration/save_resume_probe.gd

const RUN_SCENE := "res://scenes/run/run.tscn"

var _failures := 0
var _held_bytes := PackedByteArray()
var _held_file := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_hold_existing_save()
	await _drive()
	_restore_existing_save()
	if _failures == 0:
		print("SAVE_RESUME: PASS")
		quit(0)
	else:
		push_error("SAVE_RESUME: %d failure(s)" % _failures)
		quit(1)


func _drive() -> void:
	SaveStore.erase()

	# A run loaded the way a probe loads one saves nothing, however far it is driven.
	# This is the check that keeps the other forty-one scripts that load this scene
	# from writing over the player's run.
	var unlaunched := await _load_run()
	if unlaunched == null:
		return
	_check(not unlaunched.save_enabled, "a run the menu did not launch has saving off")
	# What a run holds before anything is grown on it, so the ground check below is
	# against a fresh field rather than against a number a fresh run would also pass.
	var opening_ground := unlaunched.territory_field.get_player_cell_count()
	unlaunched.wave_director.debug_advance_time(120.0)
	unlaunched.save_run()
	_check(
		not SaveStore.has_run(),
		"and writes nothing even when driven across a wave boundary and asked to save"
	)

	# Now the menu's own path.
	RunMode.set_selected(RunMode.Id.QUICK)
	RunLaunch.mark_launched_from_menu()
	var played := await _load_run()
	if played == null:
		return
	_check(played.save_enabled, "a run launched from the menu has saving on")

	played.set_process(false)
	played.player.input_enabled = false
	played._set_simulation_paused(true)
	SmokeFixtures.grow_test_ecosystem(played)
	SmokeFixtures.acquire_adaptation(played, Progression.PathId.ROOT)
	played.progression.add_biomass(77.0)
	played.player.reset_player()
	played.player.apply_damage(9.0)
	# The clock crosses a wave boundary, which is the only thing that writes a save.
	played.wave_director.debug_advance_time(150.0)
	_check(SaveStore.has_run(), "crossing a wave boundary writes the run to disk")

	var expected_wave := played.wave_director.get_current_wave_number()
	var expected_seed := played.progression.run_seed
	var expected_health := played.player.get_health()
	var expected_ground := played.territory_field.get_player_cell_count()
	var snapshot := RunSnapshot.from_dictionary(SaveStore.read_run())
	_check(
		snapshot.wave_number == expected_wave and snapshot.mode == RunMode.Id.QUICK,
		"the saved run names the wave and the mode a menu would show (%s wave %d)"
			% [RunMode.mode_name(snapshot.mode), snapshot.wave_number]
	)

	# The player quits to the menu and presses continue.
	RunLaunch.request_resume()
	RunLaunch.mark_launched_from_menu()
	var resumed := await _load_run()
	if resumed == null:
		return
	resumed.set_process(false)
	resumed.player.input_enabled = false
	resumed._set_simulation_paused(true)
	# Near rather than exact, and deliberately so: a resumed run is a run, and it has
	# been running for the frames between its scene readying and this probe pausing
	# it. Biomass has come in and Green has healed. Demanding the saved number back to
	# the decimal would be demanding that continuing a run not continue it.
	_check(
		resumed.progression.run_seed == expected_seed
		and resumed.progression.owns_adaptation(Progression.PathId.ROOT)
		and absf(resumed.progression.biomass - 77.0) <= 1.0,
		"the continued run is the same run: same seed, same build, same biomass"
	)
	_check(
		resumed.wave_director.get_current_wave_number() == expected_wave
		and absf(resumed.player.get_health() - expected_health) <= 1.0,
		"and stands where it stood: wave %d, %.1f health" % [expected_wave, expected_health]
	)
	# The ground is the bulk of the file and the part a player would notice missing.
	# Checked against the opening foothold as well as against the saved count, because
	# a restore that silently did nothing would leave a field that still has ground on
	# it - just not the ground that was won.
	var resumed_ground := resumed.territory_field.get_player_cell_count()
	_check(
		absi(resumed_ground - expected_ground) <= 1 and expected_ground > opening_ground + 100,
		"and holds the ground it won (%d cells, against %d on a fresh field)"
			% [expected_ground, opening_ground]
	)

	# Closing the window is the exit a player takes without thinking of it as one, and
	# it happens mid-wave: the clock is moved somewhere no boundary is near, the save is
	# dropped, and the exit itself is what writes one.
	resumed.wave_director.debug_advance_time(41.0)
	var mid_wave_seconds := resumed.wave_director.elapsed_seconds
	SaveStore.clear_run()
	resumed.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(SaveStore.has_run(), "closing the window mid-wave saves the run")
	_check(
		is_equal_approx(
			RunSnapshot.from_dictionary(SaveStore.read_run()).elapsed_seconds,
			mid_wave_seconds
		),
		"at the minute it was left rather than at the last wave boundary (%.1fs)"
			% mid_wave_seconds
	)

	# Finishing is what ends the save. A continue offered after a defeat would put the
	# player back into a run they have already lost.
	resumed._finish_run(false, "probe")
	_check(not SaveStore.has_run(), "finishing a run clears the save")
	var record := MetaRecord.from_dictionary(SaveStore.read_meta())
	_check(
		record.runs_finished == 1
		and record.victories == 0
		and record.best_wave_by_mode[RunMode.Id.QUICK] >= expected_wave,
		"and records it: one finished run, no victory, wave %d"
			% record.best_wave_by_mode[RunMode.Id.QUICK]
	)
	# The result panel says what the run was worth against every run before it. This
	# one is the first, so every wave it reached is a new best.
	_check(
		resumed.result_detail.text.contains("A NEW BEST"),
		"and the result panel says so: \"%s\"" % resumed.result_detail.text.split("
")[-1]
	)

	# A second, shorter run, measured against the first rather than announced as a best
	# of its own - the check that a record nobody compares against is just a label.
	# Reset in place rather than loaded again: what is being measured is the record
	# across two finished runs, not the scene.
	var best_wave := MetaRecord.from_dictionary(SaveStore.read_meta()).best_wave_by_mode[
		RunMode.Id.QUICK
	]
	resumed.reset_run()
	resumed._set_simulation_paused(true)
	resumed._finish_run(false, "probe")
	_check(
		resumed.result_detail.text.contains("YOUR BEST")
		and not resumed.result_detail.text.contains("A NEW BEST"),
		"a shorter run is told what the best still is: \"%s\""
			% resumed.result_detail.text.split("
")[-1]
	)
	_check(
		MetaRecord.from_dictionary(SaveStore.read_meta()).runs_finished == 2
		and MetaRecord.from_dictionary(SaveStore.read_meta()).best_wave_by_mode[
			RunMode.Id.QUICK
		] == best_wave,
		"and is counted alongside it without moving the best it did not beat"
	)

	# Quitting to the menu saves as well, and is checked last because it hands the
	# scene tree a deferred load of the home screen on its way out.
	resumed.reset_run()
	resumed._set_simulation_paused(true)
	resumed.wave_director.debug_advance_time(95.0)
	SaveStore.clear_run()
	resumed._return_to_main_menu()
	_check(SaveStore.has_run(), "quitting to the main menu saves the run")


## One run scene, readied. Returns null and reports the failure if it will not load,
## rather than letting every check after it fail for the same reason.
func _load_run() -> RunRoot:
	if change_scene_to_file(RUN_SCENE) != OK:
		_check(false, "the run scene loads")
		return null
	await process_frame
	await process_frame
	var prototype := current_scene as RunRoot
	if prototype == null:
		_check(false, "the run scene becomes a RunRoot")
		return null
	return prototype


func _hold_existing_save() -> void:
	_held_file = FileAccess.file_exists(SaveStore.PATH)
	if not _held_file:
		return
	var file := FileAccess.open(SaveStore.PATH, FileAccess.READ)
	if file == null:
		_held_file = false
		return
	_held_bytes = file.get_buffer(file.get_length())
	file.close()


func _restore_existing_save() -> void:
	if not _held_file:
		SaveStore.erase()
		return
	var file := FileAccess.open(SaveStore.PATH, FileAccess.WRITE)
	if file == null:
		push_error("SAVE_RESUME: could not put the machine's own save back")
		_failures += 1
		return
	file.store_buffer(_held_bytes)
	file.close()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		push_error("FAIL: %s" % description)
