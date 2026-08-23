class_name DebugGrazer
extends Node2D

enum State {
	IDLE,
	CROSSING,
}

## Phase A field that receives erosion stamps while this debug Grazer crosses the arena.
@export var territory_field: TerritoryField
## Shared territory resource supplying the debug Grazer's speed, cadence, and arena bounds.
@export var tuning: TerritoryPrototypeTuning

var state := State.IDLE
var _stamp_accumulator := 0.0
var _externally_paused := false


func _ready() -> void:
	visible = false
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if state != State.CROSSING or _externally_paused:
		return

	global_position += Vector2(tuning.grazer_speed_pixels_per_second * delta, 0.0)
	_stamp_accumulator += delta
	while _stamp_accumulator >= tuning.grazer_stamp_interval:
		_stamp_accumulator -= tuning.grazer_stamp_interval
		territory_field.queue_erosion(territory_field.to_local(global_position))

	var local_position := territory_field.to_local(global_position)
	if local_position.x > tuning.arena_size.x + 24.0:
		stop()


func _draw() -> void:
	var shell := PackedVector2Array([
		Vector2(14.0, 0.0),
		Vector2(2.0, -9.0),
		Vector2(-11.0, -7.0),
		Vector2(-15.0, 0.0),
		Vector2(-11.0, 7.0),
		Vector2(2.0, 9.0),
	])
	draw_colored_polygon(shell, Color("ff9d45"))
	draw_polyline(shell, Color("ffe0a3"), 2.0, true)
	draw_circle(Vector2(6.0, -3.2), 1.8, Color("1b1821"))
	draw_circle(Vector2(6.0, 3.2), 1.8, Color("1b1821"))
	draw_line(Vector2(-7.0, -7.0), Vector2(-12.0, -13.0), Color("ffcc76"), 2.0, true)
	draw_line(Vector2(-7.0, 7.0), Vector2(-12.0, 13.0), Color("ffcc76"), 2.0, true)


func launch(local_y: float) -> void:
	var clamped_y := clampf(local_y, 18.0, tuning.arena_size.y - 18.0)
	global_position = territory_field.to_global(Vector2(-18.0, clamped_y))
	_stamp_accumulator = tuning.grazer_stamp_interval
	state = State.CROSSING
	visible = true
	set_physics_process(true)


func stop() -> void:
	state = State.IDLE
	visible = false
	set_physics_process(false)


func set_simulation_paused(paused: bool) -> void:
	_externally_paused = paused


func is_crossing() -> bool:
	return state == State.CROSSING
