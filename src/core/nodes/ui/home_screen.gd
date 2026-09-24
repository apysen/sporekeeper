class_name HomeScreen
extends Control

const RUN_MODE := preload("res://src/core/models/run/run_mode.gd")

## The title screen: the game's name, and the three things you can do from a cold start.
##
## It owns its own DisplaySettings rather than reaching into the run's, because
## the run does not exist yet. The two agree because both read and write the same
## user://settings.cfg: a choice made here is on disk before the run is loaded, and the
## run's own settings node picks it up when it readies. Without that the settings button
## on this screen would be a menu that changes nothing.

const RUN_SCENE := "res://scenes/run/run.tscn"

@export_group("Development")
## Skips straight into the run on startup, so iterating on the game does not mean
## clicking through the menu every launch. Left in the Inspector rather than behind a
## build flag because that is where it is wanted, and it is checked with OS.is_debug_build
## so an exported release can never ship past its own title screen.
@export var skip_home_screen := false
## Offers the QUICK button. Off while playtesting concentrates on the Campaign; the
## mode itself is untouched, and a saved Quick run can still be continued.
@export var quick_mode_enabled := false

@export_group("Collaborators")
## Presentation options this screen edits. Its own instance, saved to disk on change.
@export var display_settings: DisplaySettings
## Bus names, so the volume sliders here move the same buses the run does.
@export var audio_settings: AudioSettings

@export_group("Pages")
## The confirmation shown when starting a new run would overwrite a saved one. Its own
## page rather than a popup, so it is shown the same way the settings page is.
@export var overwrite_page: Control
@export var overwrite_label: Label
@export var overwrite_confirm_button: Button
@export var overwrite_cancel_button: Button
## The title and the three menu buttons.
@export var menu_page: Control
## The settings page, shown in place of the menu rather than on top of it.
@export var settings_page: Control

@export_group("Menu")
## What the player's finished runs add up to. Hidden until there is a first one,
## because a row of zeroes is a worse greeting than no row at all.
@export var record_label: Label
## Shown only when there is a saved run to go back to, and hidden the moment there is
## not. A button that is always there and sometimes does nothing teaches the player to
## distrust it.
@export var continue_button: Button
@export var play_button: Button
@export var campaign_button: Button
## Opens the history of finished runs, each with the table its result screen showed.
@export var past_runs_button: Button
@export var settings_button: Button
@export var quit_button: Button

@export_group("Settings")
@export var settings_back_button: Button
@export var fullscreen_button: Button
@export var sfx_slider: Slider
@export var sfx_value: Label
@export var music_slider: Slider
@export var music_value: Label
## One button per presentation option, in OptionId order.
@export var setting_buttons: Array[Button] = []

@export_group("Text")
@export var fullscreen_enter_text := "FULLSCREEN"
@export var fullscreen_exit_text := "EXIT FULLSCREEN"
@export var volume_unavailable_text := "UNAVAILABLE"
## Shown when starting a new run would overwrite a saved one. Names the run that would
## be lost and the one that would replace it.
@export_multiline var overwrite_message_template := "Your {saved} run reached wave {wave} and has not ended.

Starting a new {new} run will overwrite it. There is one save, and it cannot be brought back."

var _sfx_bus := -1
var _music_bus := -1
var _run_load_started := false
var _run_scene: PackedScene
var _authored := AuthoredText.new()
var _launch_requested := false
## The mode the confirmation is asking about, so confirming starts the run that was
## asked for rather than whichever button was pressed last.
var _pending_new_run_mode := RUN_MODE.Id.QUICK
var _loading_overlay: ColorRect
var _past_runs_page: PastRunsPage
var _loading_label: Label


func _ready() -> void:
	if skip_home_screen and OS.is_debug_build():
		# Deferred: changing scene from inside _ready tears down the node that is
		# still being readied.
		RunLaunch.mark_launched_from_menu()
		if not quick_mode_enabled:
			RUN_MODE.set_selected(RUN_MODE.Id.CAMPAIGN)
		get_tree().change_scene_to_file.call_deferred(RUN_SCENE)
		return
	NinePatchButtonBorder.install_under(self)
	NinePatchPanelBorder.install_under(self)
	assert(display_settings != null, "HomeScreen requires DisplaySettings")
	assert(audio_settings != null, "HomeScreen requires AudioSettings")
	if continue_button != null:
		continue_button.pressed.connect(_on_continue_pressed)
	if play_button != null:
		play_button.pressed.connect(_on_quick_pressed)
		if not quick_mode_enabled:
			_hide_quick_button()
	if campaign_button != null:
		campaign_button.pressed.connect(_on_campaign_pressed)
	if past_runs_button != null:
		past_runs_button.pressed.connect(_show_past_runs.bind(true))
		_build_past_runs_page()
	if settings_button != null:
		settings_button.pressed.connect(_show_settings.bind(true))
	if settings_back_button != null:
		settings_back_button.pressed.connect(_show_settings.bind(false))
	if quit_button != null:
		quit_button.pressed.connect(_on_quit_pressed)
	if overwrite_confirm_button != null:
		overwrite_confirm_button.pressed.connect(_on_overwrite_confirmed)
	if overwrite_cancel_button != null:
		overwrite_cancel_button.pressed.connect(_on_overwrite_cancelled)
	if fullscreen_button != null:
		fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	# Captured before the first refresh, so from here on the scene owns the wording
	# of a settings row and this script only fills in the values - the same rule the
	# pause menu follows for the same rows.
	_authored.capture(setting_buttons)
	_authored.capture(setting_buttons, "tooltip_text")
	for option_id in range(setting_buttons.size()):
		var button := setting_buttons[option_id]
		if button != null:
			button.pressed.connect(_on_setting_pressed.bind(option_id))
	_configure_audio()
	_show_overwrite_confirmation(-1)
	_refresh_continue_button()
	_refresh_record_label()
	_show_settings(false)
	_refresh()
	_begin_run_scene_load()


func _process(_delta: float) -> void:
	if not _run_load_started:
		return
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(RUN_SCENE, progress)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_run_scene = ResourceLoader.load_threaded_get(RUN_SCENE) as PackedScene
		set_process(false)
		if _launch_requested:
			_finish_launch()
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		# Keep the fallback explicit: a threaded load failure should not strand the player.
		set_process(false)
		if _launch_requested:
			_run_scene = load(RUN_SCENE) as PackedScene
			_finish_launch()


func _begin_run_scene_load() -> void:
	if _run_load_started:
		return
	_run_load_started = true
	ResourceLoader.load_threaded_request(RUN_SCENE, "PackedScene", true)
	set_process(true)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	# Escape backs out of settings before it does anything else, so the key never
	# closes the screen out from under a player who opened a page with it.
	if overwrite_page != null and overwrite_page.visible:
		# Escape is the cautious answer: it keeps the run.
		_on_overwrite_cancelled()
		get_viewport().set_input_as_handled()
		return
	if settings_page != null and settings_page.visible:
		_show_settings(false)
		get_viewport().set_input_as_handled()


## Continues the saved run in the mode it was saved in, rather than in whichever mode
## was last picked from this screen: a Campaign resumed as Quick would be a different
## game holding the same progress.
func _on_continue_pressed() -> void:
	var stored := SaveStore.read_run()
	if stored.is_empty():
		_refresh_continue_button()
		return
	RUN_MODE.set_selected(RunSnapshot.from_dictionary(stored).mode)
	RunLaunch.request_resume()
	_request_launch()


## Hides QUICK and closes the gap it leaves, by lifting every menu button that sat
## below it one row.
func _hide_quick_button() -> void:
	play_button.visible = false
	var row := play_button.position.y - campaign_button.position.y
	for button in [past_runs_button, settings_button, quit_button]:
		if button != null and button.position.y > play_button.position.y:
			button.position.y -= row


func _build_past_runs_page() -> void:
	_past_runs_page = PastRunsPage.new()
	_past_runs_page.visible = false
	add_child(_past_runs_page)
	_past_runs_page.build()
	_past_runs_page.closed.connect(_show_past_runs.bind(false))


## Swaps the menu for the Past Runs page, or back. The page reads the record fresh on
## every opening, so a run finished since the menu loaded is on it.
func _show_past_runs(showing: bool) -> void:
	if _past_runs_page == null:
		return
	if showing:
		_past_runs_page.open(MetaRecord.from_dictionary(SaveStore.read_meta()))
	else:
		_past_runs_page.visible = false
	if menu_page != null:
		menu_page.visible = not showing


func _on_quick_pressed() -> void:
	_start_new_run(RUN_MODE.Id.QUICK)


func _on_campaign_pressed() -> void:
	_start_new_run(RUN_MODE.Id.CAMPAIGN)


## Starts a new run, asking first if there is one it would destroy.
##
## There is exactly one save slot, so starting a new run is the one irreversible thing
## on this screen: a player who wanted to continue and pressed QUICK by habit has lost
## a run they could still have been playing. The mode is remembered rather than acted
## on, so confirming starts the run that was actually asked for.
func _start_new_run(mode: int) -> void:
	if _launch_requested:
		return
	if not SaveStore.has_run():
		_launch_new_run(mode)
		return
	_pending_new_run_mode = mode
	_show_overwrite_confirmation(mode)


func _launch_new_run(mode: int) -> void:
	RunLaunch.request_new_run()
	RUN_MODE.set_selected(mode)
	_request_launch()


func _on_overwrite_confirmed() -> void:
	# The save is dropped here rather than left for the new run to write over, so a
	# player who quits the new run in its first seconds is not offered the old one.
	SaveStore.clear_run()
	_show_overwrite_confirmation(-1)
	_launch_new_run(_pending_new_run_mode)


func _on_overwrite_cancelled() -> void:
	_show_overwrite_confirmation(-1)
	_refresh_continue_button()


## Shows the confirmation for the given mode, or hides it when the mode is -1.
##
## The wording names both runs: the one that would be lost, with the wave it reached,
## and the one that would replace it. "Are you sure" on its own asks the player to
## remember what they have.
func _show_overwrite_confirmation(mode: int) -> void:
	if overwrite_page == null:
		return
	var showing := mode >= 0
	overwrite_page.visible = showing
	if menu_page != null:
		menu_page.visible = not showing
	if not showing:
		return
	var snapshot := RunSnapshot.from_dictionary(SaveStore.read_run())
	if overwrite_label != null:
		overwrite_label.text = AuthoredText.render(overwrite_message_template, {
			"saved": RUN_MODE.mode_name(snapshot.mode),
			"wave": snapshot.wave_number,
			"new": RUN_MODE.mode_name(mode),
		})


func _request_launch() -> void:
	if _launch_requested:
		return
	_launch_requested = true
	RunLaunch.mark_launched_from_menu()
	if menu_page != null:
		menu_page.visible = false
	if settings_page != null:
		settings_page.visible = false
	_show_loading_overlay()
	if _run_scene != null:
		_finish_launch()


func _finish_launch() -> void:
	if _run_scene == null:
		return
	get_tree().change_scene_to_packed(_run_scene)


func _show_loading_overlay() -> void:
	if _loading_overlay != null:
		return
	_loading_overlay = ColorRect.new()
	_loading_overlay.color = Color("#120f16")
	_loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading_overlay.z_index = 100
	add_child(_loading_overlay)
	_loading_label = Label.new()
	_loading_label.text = "LOADING..."
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_loading_label.position -= Vector2(100.0, 18.0)
	_loading_label.size = Vector2(200.0, 36.0)
	_loading_label.add_theme_font_size_override("font_size", 16)
	_loading_overlay.add_child(_loading_label)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _show_settings(open: bool) -> void:
	if menu_page != null:
		menu_page.visible = not open
	if settings_page != null:
		settings_page.visible = open
	if open:
		_refresh()


func _on_setting_pressed(option_id: int) -> void:
	# Pressing a row advances it and wraps, which is where the choice is written to
	# disk; this only has to redraw what the row now says.
	display_settings.cycle_choice(option_id)
	_refresh()


func _on_fullscreen_pressed() -> void:
	var windowed := DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if windowed else DisplayServer.WINDOW_MODE_WINDOWED
	)
	_refresh()


func _configure_audio() -> void:
	_sfx_bus = AudioServer.get_bus_index(audio_settings.sfx_bus_name)
	_music_bus = AudioServer.get_bus_index(audio_settings.music_bus_name)
	if sfx_slider != null:
		sfx_slider.value_changed.connect(_on_sfx_changed)
		sfx_slider.editable = _sfx_bus >= 0
		sfx_slider.set_value_no_signal(
			SettingsStore.read_volume("sfx", 1.0) * 100.0
		)
	if music_slider != null:
		music_slider.value_changed.connect(_on_music_changed)
		music_slider.editable = _music_bus >= 0
		music_slider.set_value_no_signal(
			SettingsStore.read_volume("music", 1.0) * 100.0
		)
	# Applied on ready as well as on change, so the volumes a player set last session
	# are in force before they press Play rather than only after they touch a slider.
	if sfx_slider != null:
		_apply_volume(_sfx_bus, sfx_slider.value, audio_settings.sfx_max_linear_volume)
	if music_slider != null:
		_apply_volume(_music_bus, music_slider.value, audio_settings.music_max_linear_volume)


func _on_sfx_changed(value: float) -> void:
	_apply_volume(_sfx_bus, value, audio_settings.sfx_max_linear_volume)
	SettingsStore.write_volume("sfx", clampf(value / 100.0, 0.0, 1.0))
	_refresh()


func _on_music_changed(value: float) -> void:
	_apply_volume(_music_bus, value, audio_settings.music_max_linear_volume)
	SettingsStore.write_volume("music", clampf(value / 100.0, 0.0, 1.0))
	_refresh()


func _apply_volume(bus_index: int, percent: float, maximum_linear: float) -> void:
	if bus_index < 0:
		return
	var linear := clampf(percent / 100.0, 0.0, 1.0) * maximum_linear
	var muted := linear <= 0.0001
	AudioServer.set_bus_mute(bus_index, muted)
	if not muted:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear))


func _refresh() -> void:
	for option_id in range(setting_buttons.size()):
		var button := setting_buttons[option_id]
		if button == null:
			continue
		var option_values := DisplaySettings.get_row_values(
			option_id, display_settings.get_choice(option_id)
		)
		_authored.write(button, option_values, DisplaySettings.ROW_TEXT_FALLBACK)
		_authored.write(
			button, option_values, DisplaySettings.ROW_TOOLTIP_FALLBACK, "tooltip_text"
		)
	if fullscreen_button != null:
		fullscreen_button.text = (
			fullscreen_exit_text
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			else fullscreen_enter_text
		)
	if sfx_value != null:
		sfx_value.text = (
			volume_unavailable_text if _sfx_bus < 0
			else "%d%%" % roundi(sfx_slider.value if sfx_slider != null else 0.0)
		)
	if music_value != null:
		music_value.text = (
			volume_unavailable_text if _music_bus < 0
			else "%d%%" % roundi(music_slider.value if music_slider != null else 0.0)
		)


## Offers the saved run, and says which one it is.
##
## The wave and the mode come off the snapshot's own identity fields rather than out
## of the systems it carries, which is what those fields are for: the screen can
## describe the save without loading a run to ask.
func _refresh_continue_button() -> void:
	if continue_button == null:
		return
	var stored := SaveStore.read_run()
	continue_button.visible = not stored.is_empty()
	if stored.is_empty():
		return
	var snapshot := RunSnapshot.from_dictionary(stored)
	continue_button.text = "CONTINUE  %s  WAVE %d" % [
		RUN_MODE.mode_name(snapshot.mode), snapshot.wave_number
	]


## The record of finished runs, as one line.
##
## Read here and nowhere else: `MetaRecord` grants nothing and unlocks nothing, so the
## only thing it owes anyone is a legible sentence about what they have done. A mode
## nobody has finished a run in is left out rather than shown as a zero - the line is
## about what happened, not about what has not.
func _refresh_record_label() -> void:
	if record_label == null:
		return
	var record := MetaRecord.from_dictionary(SaveStore.read_meta())
	record_label.visible = record.runs_finished > 0
	if record.runs_finished == 0:
		return
	var parts := PackedStringArray()
	for mode in [RUN_MODE.Id.QUICK, RUN_MODE.Id.CAMPAIGN]:
		if record.runs_by_mode[mode] <= 0:
			continue
		parts.append("%s BEST WAVE %d" % [
			RUN_MODE.mode_name(mode), record.best_wave_by_mode[mode]
		])
	parts.append("%d RUN%s, %d HELD" % [
		record.runs_finished,
		"" if record.runs_finished == 1 else "S",
		record.victories,
	])
	record_label.text = "   ".join(parts)
