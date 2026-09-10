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

@export_group("Collaborators")
## Presentation options this screen edits. Its own instance, saved to disk on change.
@export var display_settings: DisplaySettings
## Bus names, so the volume sliders here move the same buses the run does.
@export var audio_settings: AudioSettings

@export_group("Pages")
## The title and the three menu buttons.
@export var menu_page: Control
## The settings page, shown in place of the menu rather than on top of it.
@export var settings_page: Control

@export_group("Menu")
@export var play_button: Button
@export var campaign_button: Button
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

var _sfx_bus := -1
var _music_bus := -1
var _run_load_started := false
var _run_scene: PackedScene
var _authored := AuthoredText.new()
var _launch_requested := false
var _loading_overlay: ColorRect
var _loading_label: Label


func _ready() -> void:
	if skip_home_screen and OS.is_debug_build():
		# Deferred: changing scene from inside _ready tears down the node that is
		# still being readied.
		get_tree().change_scene_to_file.call_deferred(RUN_SCENE)
		return
	NinePatchButtonBorder.install_under(self)
	NinePatchPanelBorder.install_under(self)
	assert(display_settings != null, "HomeScreen requires DisplaySettings")
	assert(audio_settings != null, "HomeScreen requires AudioSettings")
	if play_button != null:
		play_button.pressed.connect(_on_quick_pressed)
	if campaign_button != null:
		campaign_button.pressed.connect(_on_campaign_pressed)
	if settings_button != null:
		settings_button.pressed.connect(_show_settings.bind(true))
	if settings_back_button != null:
		settings_back_button.pressed.connect(_show_settings.bind(false))
	if quit_button != null:
		quit_button.pressed.connect(_on_quit_pressed)
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
	if settings_page != null and settings_page.visible:
		_show_settings(false)
		get_viewport().set_input_as_handled()


func _on_quick_pressed() -> void:
	RUN_MODE.set_selected(RUN_MODE.Id.QUICK)
	_request_launch()


func _on_campaign_pressed() -> void:
	RUN_MODE.set_selected(RUN_MODE.Id.CAMPAIGN)
	_request_launch()


func _request_launch() -> void:
	if _launch_requested:
		return
	_launch_requested = true
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
			DisplaySettings.load_volume("sfx", 1.0) * 100.0
		)
	if music_slider != null:
		music_slider.value_changed.connect(_on_music_changed)
		music_slider.editable = _music_bus >= 0
		music_slider.set_value_no_signal(
			DisplaySettings.load_volume("music", 1.0) * 100.0
		)
	# Applied on ready as well as on change, so the volumes a player set last session
	# are in force before they press Play rather than only after they touch a slider.
	if sfx_slider != null:
		_apply_volume(_sfx_bus, sfx_slider.value, audio_settings.sfx_max_linear_volume)
	if music_slider != null:
		_apply_volume(_music_bus, music_slider.value, audio_settings.music_max_linear_volume)


func _on_sfx_changed(value: float) -> void:
	_apply_volume(_sfx_bus, value, audio_settings.sfx_max_linear_volume)
	DisplaySettings.save_volume("sfx", clampf(value / 100.0, 0.0, 1.0))
	_refresh()


func _on_music_changed(value: float) -> void:
	_apply_volume(_music_bus, value, audio_settings.music_max_linear_volume)
	DisplaySettings.save_volume("music", clampf(value / 100.0, 0.0, 1.0))
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
