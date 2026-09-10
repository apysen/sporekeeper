class_name PauseMenu
extends Control

## The run's pause overlay: the menu panel, the settings page, the volume and
## fullscreen controls, and the dev-control card.
##
## It owns every node beneath it and every rule about how they present. What it
## does not own is what pausing *means* to the run: it reports that the player
## opened it, closed it, asked for the glossary, or asked to leave, and the run
## root decides what those cost. That split is why the simulation-pause rule and
## the tooltip system stay on the run root while all of this moved here.
##
## Two collaborators cannot be authored as Inspector references because they live
## in the parent scene: `DisplaySettings` and `AudioSettings` arrive through
## `setup()`, which the run root calls from its own `_ready`. Everything the menu
## can resolve on its own is an ordinary exported child reference.

## The player closed the menu, by the resume button or by Escape.
signal closed
## The player opened the menu.
signal opened
## The glossary button was pressed. The run root owns `MechanicsHelp`, because the
## same tooltip stack serves HUD and reward hovers that have nothing to do with
## pausing, so the menu asks rather than opens.
signal glossary_requested
## The player chose to abandon the run and return to the home screen.
signal main_menu_requested
## The player chose to quit the game.
signal quit_requested
## The settings page was shown or hidden. The glossary is owned by the run root and
## must not stay up behind a page change, so the change is reported rather than
## reaching across to close it.
signal settings_toggled(settings_open: bool)

const SFX_VOLUME_KEY := "sfx"
const MUSIC_VOLUME_KEY := "music"

@export_group("Panels")
## The menu panel itself, hidden while the settings page is up.
@export var panel: Control
## The settings page, hidden while the menu panel is up.
@export var settings_panel: Control

@export_group("Menu Buttons")
@export var resume_button: Button
@export var fullscreen_button: Button
@export var settings_button: Button
@export var glossary_button: Button
@export var main_menu_button: Button
@export var quit_button: Button
@export var settings_back_button: Button

@export_group("Volume")
@export var volume_slider: HSlider
@export var volume_value: Label
@export var music_volume_slider: HSlider
@export var music_volume_value: Label

@export_group("Settings Rows")
## One button per DisplaySettings option, in option order. The order here is the
## order the rows appear in, and the index is the option id.
@export var setting_button_friendly_effects: Button
@export var setting_button_enemy_telegraphs: Button
@export var setting_button_territory_detail: Button
@export var setting_button_damage_numbers: Button
@export var setting_button_player_highlight: Button

@export_group("Dev Controls")
## The dev-control key card, shown only while the run's dev controls are on.
@export var debug_help_label: Label

@export_group("Text")
## Replaces the authored fullscreen wording while the window is already fullscreen.
@export var fullscreen_exit_text := "EXIT FULLSCREEN"
## Shown in place of a percentage when the audio bus this slider drives is missing.
@export var volume_unavailable_text := "UNAVAILABLE"

@export_group("Input")
## How far a stick must travel before it counts as the player reaching for a pad.
@export_range(0.05, 1.0, 0.01) var controller_stick_deadzone := 0.35

## Resolved in option order in `_ready`; the index into this array is the option id.
var setting_buttons: Array[Button] = []

var _authored := AuthoredText.new()
var _display_settings: DisplaySettings
var _audio_settings: AudioSettings
var _open := false
var _settings_open := false
var _controller_active := false
var _sfx_bus_index := -1
var _music_bus_index := -1


func _ready() -> void:
	visible = false
	setting_buttons = [
		setting_button_friendly_effects,
		setting_button_enemy_telegraphs,
		setting_button_territory_detail,
		setting_button_damage_numbers,
		setting_button_player_highlight,
	]
	var authored_controls: Array[Control] = [
		resume_button,
		volume_slider,
		volume_value,
		music_volume_slider,
		music_volume_value,
		fullscreen_button,
		glossary_button,
		main_menu_button,
		quit_button,
	]
	# Before a single frame runs: from here on the scene owns the wording and this
	# script only fills in numbers.
	_authored.capture(authored_controls)
	_authored.capture(authored_controls, "tooltip_text")
	_authored.capture(setting_buttons)
	_authored.capture(setting_buttons, "tooltip_text")
	for authored_control in authored_controls:
		assert(
			authored_control != null,
			"PauseMenu has an unwired control reference at index %d of %d"
			% [
				authored_controls.find(authored_control),
				authored_controls.size(),
			]
		)

	# The dimmer is visual only. Leaving it out of hit testing keeps the visible
	# Adaptation and relic slots inspectable while simulation is paused.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := get_node_or_null("Dim") as Control
	if dim != null:
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for option_id in range(setting_buttons.size()):
		if setting_buttons[option_id] == null:
			continue
		setting_buttons[option_id].pressed.connect(_cycle_setting.bind(option_id))
	resume_button.pressed.connect(close)
	volume_slider.value_changed.connect(_on_sfx_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	if settings_button != null:
		settings_button.pressed.connect(show_settings.bind(true))
	if settings_back_button != null:
		settings_back_button.pressed.connect(show_settings.bind(false))
	# Named handlers rather than lambdas, so what a button leads to is something a
	# reader - and a test - can name and follow out of this node.
	glossary_button.pressed.connect(_request_glossary)
	main_menu_button.pressed.connect(_request_main_menu)
	quit_button.pressed.connect(_request_quit)


## Hands over the two run components the menu cannot reach on its own. The run
## root calls this from its `_ready`, which is after this node's own.
func setup(display_settings: DisplaySettings, audio_settings: AudioSettings) -> void:
	_display_settings = display_settings
	_audio_settings = audio_settings
	_configure_volume_control()
	_update_fullscreen_button()
	refresh_setting_buttons()


func is_open() -> bool:
	return _open


func is_settings_open() -> bool:
	return _settings_open


func is_controller_active() -> bool:
	return _controller_active


func open() -> void:
	if _open:
		return
	_open = true
	visible = true
	# Always opens on the menu itself. A player who left settings open last time is
	# pausing now because something is happening, not to read options again.
	show_settings(false)
	_update_fullscreen_button()
	# Focus is only taken for a controller. A mouse player gets no ring to explain.
	_refresh_focus_ring()
	opened.emit()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func show_settings(open_settings: bool) -> void:
	_settings_open = open_settings
	if panel != null:
		panel.visible = not open_settings
	if settings_panel != null:
		settings_panel.visible = open_settings
	if open_settings:
		refresh_setting_buttons()
	settings_toggled.emit(open_settings)
	_refresh_focus_ring()


## Clears both panels so the glossary the run root opens has the screen to itself.
func hide_panels() -> void:
	if panel != null:
		panel.visible = false
	if settings_panel != null:
		settings_panel.visible = false


## Restores the menu panel after the glossary closes over it.
func show_panel() -> void:
	if panel != null:
		panel.visible = true


func set_dev_controls_enabled(enabled: bool) -> void:
	if debug_help_label != null:
		debug_help_label.visible = enabled


## The device that produced the last event decides whether the focus ring is
## shown. A pad shows it; touching the mouse or the keyboard takes it away again.
func note_input_device(event: InputEvent) -> void:
	var controller := false
	if event is InputEventJoypadButton and event.pressed:
		controller = true
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		controller = absf(motion.axis_value) >= controller_stick_deadzone
	elif (
		event is InputEventMouseMotion
		or event is InputEventMouseButton
		or event is InputEventKey
	):
		controller = false
	else:
		return
	if controller == _controller_active:
		return
	_controller_active = controller
	_refresh_focus_ring()


func refresh_setting_buttons() -> void:
	if _display_settings == null:
		return
	for option_id in range(setting_buttons.size()):
		var button := setting_buttons[option_id]
		if button == null:
			continue
		# The name and the current value on one line, because a settings row that only
		# says its value makes the player remember which row is which.
		# What that line is made of is shared with the home screen, which draws the
		# same rows from the same options.
		var option_values := DisplaySettings.get_row_values(
			option_id, _display_settings.get_choice(option_id)
		)
		# Each row names itself on its own node, so a row can be renamed, reordered
		# or reworded without this loop knowing anything about it.
		_authored.write(button, option_values, DisplaySettings.ROW_TEXT_FALLBACK)
		_authored.write(
			button, option_values, DisplaySettings.ROW_TOOLTIP_FALLBACK, "tooltip_text"
		)


func _request_glossary() -> void:
	glossary_requested.emit()


func _request_main_menu() -> void:
	main_menu_requested.emit()


func _request_quit() -> void:
	quit_requested.emit()


func _refresh_focus_ring() -> void:
	if _controller_active:
		if _open and resume_button != null:
			resume_button.grab_focus()
		return
	# Nothing focused means nothing draws a focus ring, which is the whole fix: the
	# box was Godot telling a mouse player where the controller cursor is.
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()


func _cycle_setting(option_id: int) -> void:
	if _display_settings == null:
		return
	_display_settings.cycle_choice(option_id)


func _configure_volume_control() -> void:
	_sfx_bus_index = AudioServer.get_bus_index(_audio_settings.sfx_bus_name)
	if _sfx_bus_index < 0:
		volume_slider.set_value_no_signal(0.0)
		volume_value.text = volume_unavailable_text
	else:
		var sfx_linear_volume := 0.0
		if not AudioServer.is_bus_mute(_sfx_bus_index):
			sfx_linear_volume = db_to_linear(AudioServer.get_bus_volume_db(_sfx_bus_index))
		# The saved choice wins over whatever the bus happens to sit at, so a volume
		# set on the home screen is still in force once the run loads.
		var saved_sfx := DisplaySettings.load_volume(SFX_VOLUME_KEY, -1.0)
		if saved_sfx >= 0.0:
			sfx_linear_volume = saved_sfx * _audio_settings.sfx_max_linear_volume
			_apply_bus_volume(_sfx_bus_index, sfx_linear_volume)
		volume_slider.set_value_no_signal(
			clampf(
				sfx_linear_volume / maxf(_audio_settings.sfx_max_linear_volume, 0.0001),
				0.0,
				1.0
			) * 100.0
		)
		_update_volume_label()

	_music_bus_index = AudioServer.get_bus_index(_audio_settings.music_bus_name)
	if _music_bus_index < 0:
		music_volume_slider.set_value_no_signal(0.0)
		music_volume_value.text = volume_unavailable_text
	else:
		var music_linear_volume := 0.0
		if not AudioServer.is_bus_mute(_music_bus_index):
			music_linear_volume = db_to_linear(AudioServer.get_bus_volume_db(_music_bus_index))
		var saved_music := DisplaySettings.load_volume(MUSIC_VOLUME_KEY, -1.0)
		if saved_music >= 0.0:
			music_linear_volume = saved_music * _audio_settings.music_max_linear_volume
			_apply_bus_volume(_music_bus_index, music_linear_volume)
		music_volume_slider.set_value_no_signal(
			clampf(
				music_linear_volume / maxf(
					_audio_settings.music_max_linear_volume,
					0.0001
				),
				0.0,
				1.0
			) * 100.0
		)
		_update_music_volume_label()


func _on_sfx_volume_changed(value: float) -> void:
	if _sfx_bus_index < 0:
		return
	var linear_volume := (
		clampf(value / 100.0, 0.0, 1.0)
		* _audio_settings.sfx_max_linear_volume
	)
	_apply_bus_volume(_sfx_bus_index, linear_volume)
	_update_volume_label()
	DisplaySettings.save_volume(SFX_VOLUME_KEY, clampf(value / 100.0, 0.0, 1.0))


func _on_music_volume_changed(value: float) -> void:
	if _music_bus_index < 0:
		return
	var linear_volume := (
		clampf(value / 100.0, 0.0, 1.0)
		* _audio_settings.music_max_linear_volume
	)
	_apply_bus_volume(_music_bus_index, linear_volume)
	_update_music_volume_label()
	DisplaySettings.save_volume(MUSIC_VOLUME_KEY, clampf(value / 100.0, 0.0, 1.0))


func _apply_bus_volume(bus_index: int, linear_volume: float) -> void:
	if bus_index < 0:
		return
	var muted := linear_volume <= 0.0001
	AudioServer.set_bus_mute(bus_index, muted)
	if not muted:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_volume))


func _update_volume_label() -> void:
	_authored.write(
		volume_value,
		{"percent": roundi(volume_slider.value)},
	)


func _update_music_volume_label() -> void:
	_authored.write(
		music_volume_value,
		{"percent": roundi(music_volume_slider.value)},
	)


func _toggle_fullscreen() -> void:
	var enter_fullscreen := not _is_fullscreen()
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if enter_fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if enter_fullscreen:
		fullscreen_button.text = fullscreen_exit_text
	else:
		_authored.write(fullscreen_button)
	call_deferred("_update_fullscreen_button")


func _update_fullscreen_button() -> void:
	if _is_fullscreen():
		fullscreen_button.text = fullscreen_exit_text
	else:
		_authored.write(fullscreen_button)


func _is_fullscreen() -> bool:
	var window_mode := DisplayServer.window_get_mode()
	return (
		window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
