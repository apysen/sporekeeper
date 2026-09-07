class_name TerritoryPrototype
extends Node2D

## Shared resource containing the Phase A territory-lab dimensions and tuning.
@export var tuning: TerritoryPrototypeTuning
## Authoritative territory simulation controlled by this Phase A lab scene.
@export var territory_field: TerritoryField
## Presentation adapter for field annotations and Seed/Bloom telegraphs.
@export var overlay: TerritoryPrototypeOverlay
## Debug actor launched across the field to demonstrate territory fragmentation.
@export var grazer: DebugGrazer
## Label that displays ownership, maturity, and connected-region metrics.
@export var metrics_label: Label
## Label that displays FPS plus measured simulation and texture-upload timings.
@export var performance_label: Label
## Label used to explain the most recent Phase A lab action.
@export var status_label: Label
## Label that displays the active territory debug-view name.
@export var view_label: Label
## Button that pauses or resumes the field, overlay effects, and debug Grazer.
@export var pause_button: Button
## Button that restores the Phase A comparison fixture to its initial state.
@export var reset_button: Button
## Button that launches the debug Grazer across the cursor's vertical position.
@export var grazer_button: Button
## Button that cycles between territory, maturity, and raw-control views.
@export var debug_view_button: Button
## Button that shows or hides authored arena annotation labels.
@export var annotations_button: Button

@export_group("Interface Text")
## Wording for the states a control does not sit in at rest. The resting wording
## is the text on the node itself; these are what it swaps to.
@export var pause_resume_text := "RESUME  [SPACE]"
@export var annotations_show_text := "SHOW LABELS  [H]"

var _hud_accumulator := 0.0
## Every dynamic line in the lab, as the scene authored it, captured before
## anything writes to a control. The lab is arranged in the editor like anything
## else, so the editor owns its wording too.
var _authored := AuthoredText.new()


func _ready() -> void:
	assert(tuning != null)
	assert(territory_field != null)
	assert(overlay != null)
	assert(grazer != null)

	_authored.capture([
		metrics_label,
		performance_label,
		status_label,
		view_label,
		pause_button,
		reset_button,
		grazer_button,
		debug_view_button,
		annotations_button,
	])

	territory_field.metrics_changed.connect(_on_metrics_changed)
	overlay.seed_germinated.connect(_on_seed_germinated)
	pause_button.pressed.connect(_toggle_pause)
	reset_button.pressed.connect(_reset_prototype)
	grazer_button.pressed.connect(_launch_grazer_at_cursor)
	debug_view_button.pressed.connect(_cycle_debug_view)
	annotations_button.pressed.connect(_toggle_annotations)

	_on_metrics_changed(
		territory_field.get_player_percent(),
		territory_field.get_hostile_percent(),
		territory_field.get_neutral_percent(),
		territory_field.get_mature_fraction_of_green(),
		territory_field.get_fragment_count()
	)
	_update_view_label()
	_set_status("Ready. Try a Bloom at the central choke or weak hostile basin.")


func _process(delta: float) -> void:
	_hud_accumulator += delta
	if _hud_accumulator < 0.20:
		return
	_hud_accumulator = 0.0
	_authored.write(performance_label, {
		"fps": Engine.get_frames_per_second(),
		"field_avg": "%.2f" % territory_field.get_average_step_ms(),
		"field_peak": "%.2f" % territory_field.get_peak_step_ms(),
		"render_avg": "%.2f" % territory_field.get_average_render_ms(),
		"render_peak": "%.2f" % territory_field.get_peak_render_ms(),
	})


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var local_position := territory_field.to_local(event.position)
		if not territory_field.contains_local_point(local_position):
			return
		if not territory_field.is_claimable_at_local(local_position):
			_set_status("Basalt blocks territory effects. Choose claimable ground.")
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			territory_field.queue_bloom(local_position)
			overlay.spawn_bloom(local_position)
			_set_status("Bloom released: high pressure, broad territorial displacement.")
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			overlay.spawn_seed(local_position)
			_set_status("Seed planted: protect it until the germination ring completes.")
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_G:
				_launch_grazer_at_cursor()
			KEY_R:
				_reset_prototype()
			KEY_SPACE:
				_toggle_pause()
			KEY_M:
				_cycle_debug_view()
			KEY_H:
				_toggle_annotations()


func _on_seed_germinated(local_position: Vector2) -> void:
	territory_field.queue_seed_growth(local_position)
	_set_status("Seed germinated: dense growth with lower impulse than Bloom.")


func _on_metrics_changed(
	player_percent: float,
	hostile_percent: float,
	neutral_percent: float,
	mature_player_percent: float,
	fragment_count: int
) -> void:
	_authored.write(metrics_label, {
		"green": "%5.1f" % player_percent,
		"hostile": "%5.1f" % hostile_percent,
		"neutral": "%5.1f" % neutral_percent,
		"mature": "%4.1f" % mature_player_percent,
		"regions": fragment_count,
	})


func _toggle_pause() -> void:
	territory_field.simulation_paused = not territory_field.simulation_paused
	overlay.effects_paused = territory_field.simulation_paused
	grazer.set_simulation_paused(territory_field.simulation_paused)
	if territory_field.simulation_paused:
		pause_button.text = pause_resume_text
	else:
		_authored.write(pause_button)
	_set_status("Simulation paused." if territory_field.simulation_paused else "Simulation resumed.")


func _reset_prototype() -> void:
	territory_field.simulation_paused = false
	overlay.effects_paused = false
	grazer.set_simulation_paused(false)
	grazer.stop()
	overlay.clear_effects()
	territory_field.reset_field()
	_authored.write(pause_button)
	_set_status("Arena reset to the Phase A comparison fixture.")


func _launch_grazer_at_cursor() -> void:
	var local_mouse := territory_field.to_local(get_viewport().get_mouse_position())
	var launch_y := local_mouse.y
	if not territory_field.contains_local_point(local_mouse):
		launch_y = tuning.arena_size.y * 0.535
	grazer.launch(launch_y)
	_set_status("Grazer crossing launched. Its neutral channel can split Green territory.")


func _cycle_debug_view() -> void:
	territory_field.cycle_debug_view()
	_update_view_label()
	_set_status("Debug field changed to %s." % territory_field.get_debug_view_name())


func _toggle_annotations() -> void:
	var annotations_visible := overlay.toggle_annotations()
	if annotations_visible:
		_authored.write(annotations_button)
	else:
		annotations_button.text = annotations_show_text


func _update_view_label() -> void:
	_authored.write(view_label, {"view": territory_field.get_debug_view_name()})
	_authored.write(debug_view_button)


func _set_status(message: String) -> void:
	_authored.write(status_label, {"event": message}, "{event}")
