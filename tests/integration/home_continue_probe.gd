extends SceneTree

## The menu half of continuing a run: whether the button is there at all, and whether
## it says which run it would continue.
##
## A continue button that is always present and sometimes does nothing is worse than
## no button, so the check is both ways round - hidden on a machine with no save,
## shown and named on one with a save.
##
## Holds the machine's own save and puts it back, like the other two probes that write
## to `user://save.dat`.
##
## Run: godot --headless --path . --script tests/integration/home_continue_probe.gd

const HOME_SCENE := "res://scenes/app/home_screen.tscn"

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
		print("HOME_CONTINUE: PASS")
		quit(0)
	else:
		push_error("HOME_CONTINUE: %d failure(s)" % _failures)
		quit(1)


func _drive() -> void:
	SaveStore.erase()
	var cold := await _load_home()
	if cold == null:
		return
	_check(
		cold.continue_button != null,
		"the home screen authors a continue button rather than building one at runtime"
	)
	if cold.continue_button == null:
		return
	_check(
		not cold.continue_button.visible,
		"a machine with no save is offered nothing to continue"
	)
	_check(
		cold.record_label != null and not cold.record_label.visible,
		"and is shown no record of runs it has not finished"
	)

	# A save the menu has never seen, written the way a run writes one.
	var snapshot := RunSnapshot.new()
	snapshot.mode = RunMode.Id.CAMPAIGN
	snapshot.wave_number = 17
	snapshot.run_seed = 0x0FFE0001
	SaveStore.write_run(snapshot.to_dictionary())

	var warm := await _load_home()
	if warm == null:
		return
	_check(warm.continue_button.visible, "a machine with a save is offered it")
	_check(
		warm.continue_button.text.contains("CAMPAIGN") and warm.continue_button.text.contains("17"),
		"and is told which run it is: \"%s\"" % warm.continue_button.text
	)

	# Pressing continue asks for the saved run's own mode, not whichever was last picked
	# here - and never warns, because continuing is the answer that keeps the run.
	RunMode.set_selected(RunMode.Id.QUICK)
	warm._on_continue_pressed()
	_check(
		not warm.overwrite_page.visible,
		"continuing a run is never asked to confirm anything"
	)
	_check(
		RunMode.get_selected() == RunMode.Id.CAMPAIGN,
		"continuing a Campaign run selects Campaign rather than the last mode chosen"
	)
	_check(
		RunLaunch.consume_resume(),
		"and asks the run scene to resume rather than to start something new"
	)

	# Starting a new run would destroy the saved one, and there is one save slot, so it
	# asks first. Both answers are checked: the one that keeps the run has to actually
	# keep it, and the one that starts a new run has to actually start the mode asked
	# for rather than whichever button was pressed last.
	var asked := await _load_home()
	if asked == null:
		return
	_check(
		asked.overwrite_page != null and not asked.overwrite_page.visible,
		"the overwrite warning starts hidden"
	)
	asked._on_campaign_pressed()
	_check(
		asked.overwrite_page.visible and not asked.menu_page.visible,
		"pressing a mode button with a run saved warns instead of starting one"
	)
	_check(
		asked.overwrite_label.text.contains("CAMPAIGN")
		and asked.overwrite_label.text.contains("17"),
		"and names the run that would be lost and the wave it reached"
	)
	asked._on_overwrite_cancelled()
	_check(
		not asked.overwrite_page.visible
		and asked.menu_page.visible
		and SaveStore.has_run(),
		"keeping the run puts the menu back and leaves the save alone"
	)
	_check(
		asked.continue_button.visible,
		"and the run is still there to continue"
	)

	# The same question, answered the other way. Quick this time, so what starts is the
	# mode the second question asked about rather than the first.
	asked._on_quick_pressed()
	_check(asked.overwrite_page.visible, "pressing the other mode button warns as well")
	asked._on_overwrite_confirmed()
	_check(
		not SaveStore.has_run(),
		"starting a new run drops the saved one rather than leaving it to be resumed"
	)
	_check(
		RunMode.get_selected() == RunMode.Id.QUICK and not RunLaunch.consume_resume(),
		"and starts the mode that was asked for, as a new run rather than a resume"
	)
	RunLaunch.consume_launched_from_menu()

	SaveStore.clear_run()

	# A record of finished runs, written the way a finished run writes one. Quick has
	# been played and Campaign has not, which is the case the line has to get right:
	# a mode with no runs in it is left out rather than shown as a zero.
	var record := MetaRecord.new()
	record.record_run(RunMode.Id.QUICK, true, 21, 900.0)
	record.record_run(RunMode.Id.QUICK, false, 8, 120.0)
	SaveStore.write_meta(record.to_dictionary())

	var recorded := await _load_home()
	if recorded == null:
		return
	_check(recorded.record_label.visible, "a machine with finished runs is shown its record")
	_check(
		recorded.record_label.text.contains("QUICK")
		and recorded.record_label.text.contains("21")
		and recorded.record_label.text.contains("2 RUNS, 1 HELD"),
		"which says the best wave and what the runs came to: \"%s\""
			% recorded.record_label.text
	)
	_check(
		not recorded.record_label.text.contains("CAMPAIGN"),
		"and leaves out a mode no run has finished in"
	)


func _load_home() -> HomeScreen:
	if change_scene_to_file(HOME_SCENE) != OK:
		_check(false, "the home screen scene loads")
		return null
	await process_frame
	await process_frame
	var screen := current_scene as HomeScreen
	if screen == null:
		_check(false, "the home screen scene becomes a HomeScreen")
		return null
	return screen


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
		push_error("HOME_CONTINUE: could not put the machine's own save back")
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
