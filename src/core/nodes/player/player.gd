class_name Player
extends Node2D

signal health_changed(current: float, maximum: float)
## Published after a hit actually lands, so relics can answer being hurt without
## intercepting the damage rule itself.
signal damage_taken(amount: float)
signal died

@export_group("Collaborators")
## Authoritative field used for movement collision, spawn position, and Green healing checks.
@export var territory_field: TerritoryField
## Presentation options, for the highlight ring. Optional: without it the Gardener
## is drawn exactly as it was before the setting existed.
@export var display_settings: DisplaySettings

@export_group("Health")
## Health restored on reset and the upper limit for all healing.
@export_range(10.0, 500.0, 1.0) var maximum_health := 100.0
## Seconds of damage immunity granted after a successful enemy hit.
@export_range(0.0, 2.0, 0.05) var damage_invulnerability_seconds := 0.50
## Seconds the whole body is drawn pure white after a hit.
##
## The point is location, not decoration. By the late waves the Gardener is a small
## shape inside a hundred bodies, splatter, thorns and a whip, and the moment they
## are hit is exactly the moment they need to know where they are standing. Pure
## white because every other thing on the field is green, gold or red.
@export_range(0.0, 1.0, 0.01) var damage_flash_seconds := 0.15
## How much of its colour the body keeps at the dimmest point of the i-frame blink
## that follows the flash. Above zero so the Gardener never disappears.
@export_range(0.0, 1.0, 0.05) var invulnerability_blink_floor := 0.45
## Blinks per second while the remaining invincibility frames run.
@export_range(0.0, 30.0, 0.5) var invulnerability_blink_hz := 9.0

@export_group("Movement")
## Movement speed in arena pixels per second at full directional input.
@export_range(50.0, 500.0, 1.0) var speed_pixels_per_second := 230.0
## Player collision and contact radius in arena pixels.
@export_range(1.0, 40.0, 0.5) var body_radius_pixels := 12.0

@export_group("Territory Movement")
## Peak movement bonus supplied by fully mature owned Green. Established ground is
## a home-field advantage rather than a tax on losing it: Rot, Neutral and Fresh
## Green all move at the plain base speed, so ground the run loses takes an
## advantage away without ever making recovery slower than normal.
@export_range(0.0, 1.0, 0.01) var mature_green_speed_bonus := 0.10
## Radius of the local territory sample, as a fraction of the body radius. Movement
## reads a small patch rather than the single cell underfoot, because one raw sample
## flickers along a noisy border and the bonus would strobe with it. The radius is
## floored at one territory cell whatever this is set to: a sample tighter than the
## lattice lands every offset back in the middle cell and silently becomes the
## single-cell read this exists to avoid.
@export_range(0.1, 3.0, 0.05) var territory_sample_radius_fraction := 1.00
## Local control average at which an active bonus is released. Deliberately below
## the ownership threshold that grants it: entering and leaving on the same number
## would toggle every time the frontier breathes.
@export_range(0.0, 0.49, 0.01) var territory_bonus_release_control := 0.10

@export_group("Photosynthesis")
## Health restored per second while standing on sufficiently mature Green territory.
@export_range(0.0, 10.0, 0.05) var green_healing_per_second := 1.0
## Minimum 0-to-1 local maturity required for Green territory to heal the player.
@export_range(0.0, 1.0, 0.01) var green_healing_maturity_threshold := 0.25

## Where the movement sample looks, beyond the cell underfoot. Four neighbours is
## enough to average out a noisy border without making movement pay for a survey.
const TERRITORY_SAMPLE_OFFSETS: Array[Vector2] = [
	Vector2.RIGHT,
	Vector2.LEFT,
	Vector2.UP,
	Vector2.DOWN,
]

var input_enabled := true
var simulation_paused := false

var _health := 0.0
## Movement speed is composed rather than held in one slot: relics and territory
## both want a say, and a single shared multiplier meant whichever wrote last
## erased the other. Each owner writes its own factor and movement reads the
## product.
var _relic_speed_multiplier := 1.0
var _territory_speed_multiplier := 1.0
## Whether the territory bonus is currently granted. Held as state because the
## thresholds that enter and leave it differ; one Grandma means one boolean, which
## is why the hysteresis lives here rather than on every field cell.
var _territory_bonus_active := false
var _damage_absorption := 0.0
var _damage_absorption_cooldown := 0.0
var _damage_absorption_remaining := 0.0
var _invulnerability_remaining := 0.0
var _facing := Vector2.RIGHT
var _damage_flash_remaining := 0.0
## Seconds since the current invincibility window opened, which is what the blink
## is a function of. Kept separate from the countdown so the blink phase does not
## depend on how long the window happens to be.
var _invulnerability_elapsed := 0.0


func _ready() -> void:
	assert(territory_field != null, "Player requires TerritoryField")
	reset_player()


func _physics_process(delta: float) -> void:
	if simulation_paused:
		return
	_invulnerability_remaining = maxf(0.0, _invulnerability_remaining - delta)
	_invulnerability_elapsed += delta
	_damage_flash_remaining = maxf(0.0, _damage_flash_remaining - delta)
	_damage_absorption_remaining = maxf(0.0, _damage_absorption_remaining - delta)

	_update_territory_speed()
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
	# Two stages, because they answer two questions. The white flash says "you were
	# hit, and this is where you are"; the blink that follows says "you still cannot
	# be hit again", which is a different and quieter piece of information.
	var flash := _damage_flash_remaining > 0.0
	var body_color := Color.WHITE if flash else Color("d8ffe5")
	var body_alpha := 1.0
	if not flash and _invulnerability_remaining > 0.0:
		var blink := 0.5 + 0.5 * sin(_invulnerability_elapsed * TAU * invulnerability_blink_hz)
		body_alpha = lerpf(invulnerability_blink_floor, 1.0, blink)
	# Drawn first, underneath the body, so the highlight reads as the Gardener being
	# picked out of the battlefield rather than as another effect sitting on top of
	# them. Off by default is deliberately not the default choice: by the time the
	# arena carries splatter, vines and an orbiting ring, an outline is the difference
	# between playing and hunting for yourself.
	if display_settings != null:
		var highlight_width := display_settings.get_player_highlight_width()
		var highlight_alpha := display_settings.get_player_highlight_alpha()
		if highlight_width > 0.0 and highlight_alpha > 0.0:
			draw_arc(
				Vector2.ZERO,
				body_radius_pixels + 6.0,
				0.0,
				TAU,
				28,
				Color(0.05, 0.02, 0.03, highlight_alpha * 0.7),
				highlight_width + 2.0,
				true
			)
			draw_arc(
				Vector2.ZERO,
				body_radius_pixels + 6.0,
				0.0,
				TAU,
				28,
				Color(1.0, 0.98, 0.72, highlight_alpha),
				highlight_width,
				true
			)
	draw_circle(Vector2.ZERO, body_radius_pixels + 3.0, Color(0.01, 0.03, 0.025, 0.92 * body_alpha))
	draw_circle(Vector2.ZERO, body_radius_pixels, Color(body_color, body_alpha))
	var leaf := PackedVector2Array([
		_facing * 14.0,
		_facing.rotated(2.25) * 9.0,
		_facing.rotated(PI) * 5.0,
		_facing.rotated(-2.25) * 9.0,
	])
	# The leaf and the eye flash with the body rather than staying green on top of
	# it. A silhouette that is only half white reads as a lighting change; one that
	# is entirely white reads as a hit.
	draw_colored_polygon(leaf, Color(Color.WHITE if flash else Color("48d778"), body_alpha))
	draw_polyline(leaf, Color(Color.WHITE if flash else Color("9dffc1"), body_alpha), 1.5, true)
	if not flash:
		draw_circle(_facing * 3.0, 2.2, Color(Color("163526"), body_alpha))


func reset_player() -> void:
	_health = maximum_health
	_invulnerability_remaining = 0.0
	_invulnerability_elapsed = 0.0
	_damage_flash_remaining = 0.0
	_relic_speed_multiplier = 1.0
	_territory_speed_multiplier = 1.0
	_territory_bonus_active = false
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
	var movement := intent * speed_pixels_per_second * get_speed_multiplier() * delta
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
	_invulnerability_elapsed = 0.0
	_damage_flash_remaining = damage_flash_seconds
	health_changed.emit(_health, maximum_health)
	damage_taken.emit(amount)
	if _health <= 0.0:
		died.emit()
	return true


func _update_territory_speed() -> void:
	## The territory factor is derived rather than pushed: the player already holds
	## the field reference and is the only thing that needs the answer, so nothing
	## outside writes this slot and the two owners the composition exists to keep
	## apart stay apart.
	var local_position := territory_field.to_local(global_position)
	var ownership_threshold := territory_field.tuning.ownership_threshold
	var cell_width := (
		territory_field.tuning.arena_size.x
		/ float(territory_field.tuning.field_size.x)
	)
	var sample_radius := maxf(
		body_radius_pixels * territory_sample_radius_fraction,
		cell_width
	)
	var control_sum := territory_field.get_control_at_local(local_position)
	var maturity_sum := 0.0
	var owned_samples := 0
	if control_sum > ownership_threshold:
		maturity_sum = territory_field.get_maturity_at_local(local_position)
		owned_samples = 1
	for offset in TERRITORY_SAMPLE_OFFSETS:
		var point := local_position + offset * sample_radius
		var control := territory_field.get_control_at_local(point)
		control_sum += control
		if control > ownership_threshold:
			maturity_sum += territory_field.get_maturity_at_local(point)
			owned_samples += 1
	var control_average := control_sum / float(TERRITORY_SAMPLE_OFFSETS.size() + 1)
	if _territory_bonus_active:
		_territory_bonus_active = control_average > territory_bonus_release_control
	else:
		_territory_bonus_active = control_average >= ownership_threshold
	if not _territory_bonus_active or owned_samples == 0:
		_territory_speed_multiplier = 1.0
		return
	# Fresh Green is worth nothing here on purpose. What the bonus pays for is age,
	# so the routes worth defending are the ones the run has held longest.
	_territory_speed_multiplier = 1.0 + mature_green_speed_bonus * (
		maturity_sum / float(owned_samples)
	)


func set_relic_speed_multiplier(multiplier: float) -> void:
	_relic_speed_multiplier = maxf(0.05, multiplier)


## The effective multiplier movement actually travels on.
func get_speed_multiplier() -> float:
	return _relic_speed_multiplier * _territory_speed_multiplier


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


func get_facing_direction() -> Vector2:
	## Snapshot-safe facing for directional automatic attacks. The Cane asks once at
	## sweep start, so turning during its presentation cannot bend the authored arc.
	return _facing


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


## Where the player is and how hurt they are.
##
## Position is stored in the field's own space rather than as a global, because a
## global is only meaningful against the scene's transform and a save outlives the
## scene it was taken in.
##
## The timers are not kept - invulnerability, the damage flash, the absorption window.
## Each is a fraction of a second of reaction to something that happened; restoring
## one would hand the resumed run a shield it earned in a fight that is over.
func capture_state() -> Dictionary:
	return {
		"health": _health,
		"local_position": territory_field.to_local(global_position),
		"facing": _facing,
	}


func apply_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_health = clampf(float(state.get("health", maximum_health)), 0.0, maximum_health)
	var local_position: Variant = state.get("local_position", Vector2.ZERO)
	if local_position is Vector2:
		global_position = territory_field.to_global(local_position)
	var facing: Variant = state.get("facing", Vector2.RIGHT)
	if facing is Vector2 and (facing as Vector2).length_squared() > 0.0:
		_facing = (facing as Vector2).normalized()
	health_changed.emit(_health, maximum_health)
	queue_redraw()
