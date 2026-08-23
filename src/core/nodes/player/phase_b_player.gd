class_name PhaseBPlayer
extends Node2D

signal health_changed(current: float, maximum: float)
## Published after a hit actually lands, so relics can answer being hurt without
## intercepting the damage rule itself.
signal damage_taken(amount: float)
signal died

@export_group("Collaborators")
## Authoritative field used for movement collision, spawn position, and Green healing checks.
@export var territory_field: TerritoryField

@export_group("Health")
## Health restored on reset and the upper limit for all healing.
@export_range(10.0, 500.0, 1.0) var maximum_health := 100.0
## Seconds of damage immunity granted after a successful enemy hit.
@export_range(0.0, 2.0, 0.05) var damage_invulnerability_seconds := 0.50

@export_group("Movement")
## Movement speed in arena pixels per second at full directional input.
@export_range(50.0, 500.0, 1.0) var speed_pixels_per_second := 230.0
## Player collision and contact radius in arena pixels.
@export_range(1.0, 40.0, 0.5) var body_radius_pixels := 12.0

@export_group("Photosynthesis")
## Health restored per second while standing on sufficiently mature Green territory.
@export_range(0.0, 10.0, 0.05) var green_healing_per_second := 1.0
## Minimum 0-to-1 local maturity required for Green territory to heal the player.
@export_range(0.0, 1.0, 0.01) var green_healing_maturity_threshold := 0.25

var input_enabled := true
var simulation_paused := false

var _health := 0.0
var _speed_multiplier := 1.0
var _damage_absorption := 0.0
var _damage_absorption_cooldown := 0.0
var _damage_absorption_remaining := 0.0
var _invulnerability_remaining := 0.0
var _facing := Vector2.RIGHT
var _damage_flash_remaining := 0.0


func _ready() -> void:
	assert(territory_field != null, "PhaseBPlayer requires TerritoryField")
	reset_player()


func _physics_process(delta: float) -> void:
	if simulation_paused:
		return
	_invulnerability_remaining = maxf(0.0, _invulnerability_remaining - delta)
	_damage_flash_remaining = maxf(0.0, _damage_flash_remaining - delta)
	_damage_absorption_remaining = maxf(0.0, _damage_absorption_remaining - delta)

	if input_enabled:
		var movement := _read_movement_input()
		move_with_intent(movement, delta)

	var local_position := territory_field.to_local(global_position)
	if (
		territory_field.get_control_at_local(local_position)
		> territory_field.tuning.ownership_threshold
		and territory_field.get_maturity_at_local(local_position)
		>= green_healing_maturity_threshold
	):
		heal(green_healing_per_second * delta)
	queue_redraw()


func _draw() -> void:
	var flash := _damage_flash_remaining > 0.0
	var body_color := Color("fff0df") if flash else Color("d8ffe5")
	draw_circle(Vector2.ZERO, body_radius_pixels + 3.0, Color(0.01, 0.03, 0.025, 0.92))
	draw_circle(Vector2.ZERO, body_radius_pixels, body_color)
	var leaf := PackedVector2Array([
		_facing * 14.0,
		_facing.rotated(2.25) * 9.0,
		_facing.rotated(PI) * 5.0,
		_facing.rotated(-2.25) * 9.0,
	])
	draw_colored_polygon(leaf, Color("48d778"))
	draw_polyline(leaf, Color("9dffc1"), 1.5, true)
	draw_circle(_facing * 3.0, 2.2, Color("163526"))


func reset_player() -> void:
	_health = maximum_health
	_invulnerability_remaining = 0.0
	_damage_flash_remaining = 0.0
	_speed_multiplier = 1.0
	_damage_absorption_remaining = 0.0
	_facing = Vector2.RIGHT
	global_position = territory_field.to_global(
		Vector2(
			territory_field.tuning.arena_size.x * 0.25,
			territory_field.tuning.arena_size.y * 0.53
		)
	)
	health_changed.emit(_health, maximum_health)
	queue_redraw()


func move_with_intent(intent: Vector2, delta: float) -> void:
	if intent.length_squared() > 1.0:
		intent = intent.normalized()
	if intent.length_squared() <= 0.0001:
		return
	_facing = intent.normalized()
	var movement := intent * speed_pixels_per_second * _speed_multiplier * delta
	var current_local := territory_field.to_local(global_position)
	var target_local := current_local + movement
	if _can_occupy(target_local):
		global_position = territory_field.to_global(target_local)
		return
	var horizontal_target := current_local + Vector2(movement.x, 0.0)
	if absf(movement.x) > 0.001 and _can_occupy(horizontal_target):
		global_position = territory_field.to_global(horizontal_target)
		current_local = horizontal_target
	var vertical_target := current_local + Vector2(0.0, movement.y)
	if absf(movement.y) > 0.001 and _can_occupy(vertical_target):
		global_position = territory_field.to_global(vertical_target)


func apply_damage(amount: float) -> bool:
	if amount <= 0.0 or _health <= 0.0 or _invulnerability_remaining > 0.0:
		return false
	# Canopy: standing on old ground means part of the hit lands in the canopy
	# instead of in you. The condition is ground maturity, which the player
	# already reads for its own healing rule, so no relic knowledge lives here.
	if (
		_damage_absorption > 0.0
		and _damage_absorption_remaining <= 0.0
		and territory_field.is_mature_player_territory_at_local(
			territory_field.to_local(global_position)
		)
	):
		amount *= 1.0 - _damage_absorption
		_damage_absorption_remaining = _damage_absorption_cooldown
	_health = maxf(0.0, _health - amount)
	_invulnerability_remaining = damage_invulnerability_seconds
	_damage_flash_remaining = 0.16
	health_changed.emit(_health, maximum_health)
	damage_taken.emit(amount)
	if _health <= 0.0:
		died.emit()
	return true


func set_speed_multiplier(multiplier: float) -> void:
	_speed_multiplier = maxf(0.05, multiplier)


func get_speed_multiplier() -> float:
	return _speed_multiplier


func set_damage_absorption(fraction: float, cooldown_seconds: float) -> void:
	_damage_absorption = clampf(fraction, 0.0, 0.95)
	_damage_absorption_cooldown = maxf(0.0, cooldown_seconds)
	if _damage_absorption <= 0.0:
		_damage_absorption_remaining = 0.0


func get_damage_absorption_remaining() -> float:
	return _damage_absorption_remaining


func heal(amount: float) -> void:
	if amount <= 0.0 or _health <= 0.0 or _health >= maximum_health:
		return
	_health = minf(maximum_health, _health + amount)
	health_changed.emit(_health, maximum_health)


func get_health() -> float:
	return _health


func get_max_health() -> float:
	return maximum_health


func get_arena_position() -> Vector2:
	return territory_field.to_local(global_position)


func set_simulation_paused(paused: bool) -> void:
	simulation_paused = paused


func _read_movement_input() -> Vector2:
	var movement := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		movement.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		movement.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		movement.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		movement.y += 1.0
	return movement.normalized() if movement.length_squared() > 1.0 else movement


func _can_occupy(local_position: Vector2) -> bool:
	if not territory_field.contains_local_point(local_position):
		return false
	var radius := body_radius_pixels * 0.58
	return (
		territory_field.is_claimable_at_local(local_position)
		and territory_field.is_claimable_at_local(local_position + Vector2(radius, 0.0))
		and territory_field.is_claimable_at_local(local_position + Vector2(-radius, 0.0))
		and territory_field.is_claimable_at_local(local_position + Vector2(0.0, radius))
		and territory_field.is_claimable_at_local(local_position + Vector2(0.0, -radius))
	)
