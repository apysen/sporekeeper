class_name VineWhip
extends Node2D

## The Vine as a persistent physical appendage.
##
## The Vine is not spawned per attack. It exists from the moment the Adaptation is
## acquired, hangs off Grandma, trails as she moves, bends around basalt, and
## settles when she stops. An attack does not create a Vine: it drives the Vine
## that is already there through the next alternating stroke.
##
## The authored 90-degree sector is the *driving intent*, not a damage wedge. Only
## the base of the rope is steered; the rest follows through physics, so the tip
## lags, cracks, and overshoots. Damage comes from where the simulated body
## actually is, which is the whole reason the rope exists rather than a sector
## being drawn to look like one.
##
## Implemented as a Verlet chain over flat arrays rather than a body-and-joint
## chain: it is cheaper, deterministic, easier to constrain to the authored sweep,
## and it keeps rendering and hit resolution reading the same points.

signal sweep_started(sweep_id: int, left_to_right: bool)
signal enemy_struck(enemy_id: int, apical: bool, sweep_id: int)

@export_group("Collaborators")
## Authoritative field supplying the obstacle mask the rope collides against.
@export var territory_field: TerritoryField

@export_group("Shape")
## Rest length of one segment. Reach divided by this decides the point count.
@export_range(4.0, 48.0, 1.0) var segment_rest_length := 12.0
## Bounds on that count, so a short Vine still simulates and a long one stays cheap.
@export_range(3, 32, 1) var minimum_points := 9
@export_range(4, 64, 1) var maximum_points := 18

@export_group("Solver")
## Velocity retained per step while trailing, and while being driven. The driven
## value is higher because a stroke should carry rather than damp out mid-swing.
@export_range(0.5, 1.0, 0.005) var passive_damping := 0.92
@export_range(0.5, 1.0, 0.005) var active_damping := 0.96
## Distance-constraint passes per physics step.
@export_range(1, 16, 1) var constraint_iterations := 4
## Longest simulation step the solver will take at once, so a frame spike becomes
## several small steps instead of one explosive one.
@export_range(0.005, 0.1, 0.001) var maximum_substep := 1.0 / 30.0
@export_range(1, 8, 1) var maximum_substeps := 3
## Clearance kept from an obstacle when a point is pushed out of one.
@export_range(0.5, 8.0, 0.5) var collision_clearance := 2.0

@export_group("Sweep")
## The authored driver arc. The rope is allowed to distort this; it is not clamped.
@export_range(10.0, 180.0, 1.0) var sweep_arc_degrees := 90.0
## How far past the authored endpoints the free tip may visibly overshoot.
@export_range(0.0, 60.0, 1.0) var overshoot_allowance_degrees := 15.0
## Beyond this angle from the forward axis a strong restoring force is applied, so
## the Vine cannot end up attacking behind Grandma.
@export_range(20.0, 180.0, 1.0) var tip_restoring_degrees := 60.0
## Share of the attack interval spent driving the stroke, and its bounds. The rest
## of the interval is recovery, so the rope settles before the next stroke.
@export_range(0.05, 1.0, 0.01) var sweep_duration_share := 0.55
@export_range(0.02, 1.0, 0.01) var minimum_sweep_duration := 0.12
@export_range(0.02, 1.0, 0.01) var maximum_sweep_duration := 0.28
## Guide weights: the first free point is driven hard, the second less, and the
## rest only lightly biased so the body lags behind the base.
@export_range(0.0, 1.0, 0.01) var first_guide_weight := 1.00
@export_range(0.0, 1.0, 0.01) var second_guide_weight := 0.55
@export_range(0.0, 1.0, 0.01) var base_bias := 0.20
@export_range(0.0, 1.0, 0.01) var tip_bias := 0.05
## How fast a fully weighted point is pulled onto the driver line, per second. The
## guide is a position target rather than a force, so it is applied as a rate: at
## weight 1.0 the base of the rope closes half the remaining gap every two frames,
## while the tip's much lower weight leaves it free to lag and crack.
@export_range(1.0, 120.0, 1.0) var guide_rate := 30.0

@export_group("Apical")
## Outer share of the rope's arc length that counts as the Apical zone at Trellis
## rank zero. Trellis widens this, which is what makes the physical tip the sweet
## spot rather than a radius measured from Grandma.
@export_range(0.05, 0.75, 0.01) var apical_share := 0.25

@export_group("Recovery")
## A player displacement larger than this in one tick is a teleport, not movement:
## the whole rope is translated with her rather than being whipped across the arena.
@export_range(10.0, 400.0, 5.0) var teleport_pixels := 80.0
## How long a recovered rope blends back toward a legal pose.
@export_range(0.0, 2.0, 0.05) var recovery_seconds := 0.20

## The rope itself. Flat arrays owned here rather than a node per segment.
var points := PackedVector2Array()
var previous_points := PackedVector2Array()

var _anchor := Vector2.ZERO
var _facing := Vector2.RIGHT
var _reach := 0.0
var _sweep_active := false
var _sweep_id := 0
var _sweep_left_to_right := true
var _sweep_elapsed := 0.0
var _sweep_duration := 0.0
var _sweep_facing := Vector2.RIGHT
var _hit_enemy_ids := PackedInt32Array()
## Segment endpoints from the previous physics step, so a fast tip is tested
## against where it swept rather than only where it ended up.
var _previous_segments := PackedVector2Array()
var _apical_threshold := 0.75
var _recovery_remaining := 0.0
var _built := false


func is_built() -> bool:
	return _built and points.size() >= 2


func is_sweeping() -> bool:
	return _sweep_active


func get_sweep_id() -> int:
	return _sweep_id


func get_point_count() -> int:
	return points.size()


func get_tip() -> Vector2:
	if points.is_empty():
		return _anchor
	return points[points.size() - 1]


func set_apical_share(share: float) -> void:
	## Trellis moves the physical Apical threshold rather than changing damage, so
	## the widened sweet spot is a real part of the rope.
	_apical_threshold = clampf(1.0 - share, 0.0, 0.99)


func build(anchor: Vector2, reach: float) -> void:
	## Lay the rope out behind Grandma. Called on creation and on a true reset only;
	## ordinary play must never rebuild it, because rebuilding is what makes a Vine
	## look like it is being spawned per attack.
	_anchor = anchor
	_reach = maxf(1.0, reach)
	var count := clampi(
		int(ceil(_reach / maxf(1.0, segment_rest_length))) + 1,
		minimum_points,
		maximum_points
	)
	points = PackedVector2Array()
	previous_points = PackedVector2Array()
	var spacing := _reach / float(maxi(1, count - 1))
	for index in range(count):
		var position := anchor - _facing * spacing * float(index)
		points.append(position)
		previous_points.append(position)
	_previous_segments = points.duplicate()
	_built = true
	_recovery_remaining = 0.0


func set_reach(reach: float) -> void:
	## Elongation changed the Vine's length. The chain is resampled rather than
	## rebuilt, so the rope keeps its current shape and momentum through the change.
	var wanted := maxf(1.0, reach)
	if is_equal_approx(wanted, _reach):
		return
	_reach = wanted
	var count := clampi(
		int(ceil(_reach / maxf(1.0, segment_rest_length))) + 1,
		minimum_points,
		maximum_points
	)
	if count == points.size() or points.size() < 2:
		return
	var resampled := PackedVector2Array()
	var previous_resampled := PackedVector2Array()
	for index in range(count):
		var t := float(index) / float(maxi(1, count - 1)) * float(points.size() - 1)
		var low := clampi(int(floor(t)), 0, points.size() - 1)
		var high := clampi(low + 1, 0, points.size() - 1)
		var blend := t - float(low)
		resampled.append(points[low].lerp(points[high], blend))
		previous_resampled.append(previous_points[low].lerp(previous_points[high], blend))
	points = resampled
	previous_points = previous_resampled
	_previous_segments = points.duplicate()


func begin_sweep(facing: Vector2, left_to_right: bool, attack_interval: float) -> int:
	## Drive the existing rope through the next stroke. Nothing is created here and
	## no point is repositioned: the state the last stroke ended in is the state this
	## one starts from, which is what makes Recurve and Liana feel continuous.
	if not is_built():
		return -1
	_sweep_id += 1
	_sweep_active = true
	_sweep_left_to_right = left_to_right
	_sweep_elapsed = 0.0
	_sweep_duration = clampf(
		attack_interval * sweep_duration_share,
		minimum_sweep_duration,
		maximum_sweep_duration
	)
	_sweep_facing = facing.normalized() if facing.length_squared() > 0.0001 else Vector2.RIGHT
	_hit_enemy_ids = PackedInt32Array()
	sweep_started.emit(_sweep_id, left_to_right)
	return _sweep_id


func advance(anchor: Vector2, facing: Vector2, delta: float) -> void:
	if not is_built() or delta <= 0.0:
		return
	if facing.length_squared() > 0.0001:
		_facing = facing.normalized()
	var displacement := anchor - _anchor
	if displacement.length() > teleport_pixels:
		# A teleport or a scene correction. Carry the whole rope with her: solving
		# this as movement would fling the tip across the arena as a free attack.
		for index in range(points.size()):
			points[index] += displacement
			previous_points[index] += displacement
	_anchor = anchor
	_previous_segments = points.duplicate()
	var remaining := delta
	var substeps := 0
	while remaining > 0.0 and substeps < maximum_substeps:
		var step := minf(remaining, maximum_substep)
		_solve(step)
		remaining -= step
		substeps += 1
	if _sweep_active:
		_sweep_elapsed += delta
		if _sweep_elapsed >= _sweep_duration:
			# Damage stops, simulation does not. The rope carries its momentum into
			# the settle and then into the opposite stroke.
			_sweep_active = false
	_recovery_remaining = maxf(0.0, _recovery_remaining - delta)
	if not _is_finite():
		_recover()
	queue_redraw()


func _solve(delta: float) -> void:
	var damping := active_damping if _sweep_active else passive_damping
	var guide := _current_guide_direction()
	for index in range(points.size()):
		if index == 0:
			# Point zero is hard-attached to Grandma every tick.
			previous_points[0] = points[0]
			points[0] = _anchor
			continue
		var velocity := (points[index] - previous_points[index]) * damping
		previous_points[index] = points[index]
		points[index] += velocity
		if not _sweep_active:
			continue
		# The driver is a position target, so it is applied as a rate toward that
		# target rather than as an acceleration: treating a position error as an
		# acceleration and scaling it by delta squared makes it vanish entirely.
		var weight := _guide_weight(index)
		var wanted := _anchor + guide * segment_rest_length * float(index)
		points[index] = points[index].lerp(
			wanted,
			clampf(weight * guide_rate * delta, 0.0, 1.0)
		)
	for _iteration in range(constraint_iterations):
		_solve_distances()
		_solve_obstacles()
	_restrain_tip()


func _guide_weight(index: int) -> float:
	# Only the base is really driven. Everything past it is physics-dominant with a
	# light bias, which is what produces the lag and the crack at the tip.
	if index == 1:
		return first_guide_weight
	if index == 2:
		return second_guide_weight
	var span := maxi(1, points.size() - 3)
	var progress := float(index - 3) / float(span)
	return lerpf(base_bias, tip_bias, clampf(progress, 0.0, 1.0))


func _current_guide_direction() -> Vector2:
	var half := deg_to_rad(sweep_arc_degrees * 0.5)
	var start_angle := -half if _sweep_left_to_right else half
	var end_angle := half if _sweep_left_to_right else -half
	var progress := clampf(_sweep_elapsed / maxf(0.0001, _sweep_duration), 0.0, 1.0)
	# Eased rather than constant, so the tip reaches its highest speed late in the
	# stroke the way a driven whip does.
	var eased := progress * progress * (3.0 - 2.0 * progress)
	return _sweep_facing.rotated(lerpf(start_angle, end_angle, eased))


func _solve_distances() -> void:
	for index in range(points.size() - 1):
		var first := points[index]
		var second := points[index + 1]
		var delta_position := second - first
		var distance := delta_position.length()
		if distance <= 0.0001:
			continue
		var correction := (distance - segment_rest_length) / distance * 0.5
		var offset := delta_position * correction
		if index == 0:
			# The anchored end does not move, so its partner takes the whole
			# correction rather than dragging Grandma along the chain.
			points[index + 1] = second - offset * 2.0
			continue
		points[index] = first + offset
		points[index + 1] = second - offset


func _solve_obstacles() -> void:
	if territory_field == null:
		return
	for index in range(1, points.size()):
		var point := points[index]
		if territory_field.contains_local_point(point) and territory_field.is_growth_path_clear(
			points[index - 1],
			point
		):
			continue
		# Project back toward the previous point until the link is legal again. The
		# previous point is already legal, so this always terminates on it.
		var anchor_point := points[index - 1]
		var direction := anchor_point.direction_to(point)
		if direction.length_squared() <= 0.0001:
			points[index] = anchor_point
			continue
		var legal := anchor_point
		var span := anchor_point.distance_to(point)
		var travelled := 0.0
		while travelled < span:
			var candidate := anchor_point + direction * (travelled + collision_clearance)
			if not territory_field.contains_local_point(candidate):
				break
			if not territory_field.is_growth_path_clear(anchor_point, candidate):
				break
			legal = candidate
			travelled += collision_clearance
		points[index] = legal


func _restrain_tip() -> void:
	# The rope may overshoot the authored arc, but it may never come round behind
	# Grandma and attack from the wrong side.
	if points.size() < 2:
		return
	var limit := deg_to_rad(tip_restoring_degrees + overshoot_allowance_degrees)
	var forward := _sweep_facing if _sweep_active else _facing
	for index in range(1, points.size()):
		var offset := points[index] - _anchor
		if offset.length_squared() <= 0.0001:
			continue
		var angle := forward.angle_to(offset)
		if absf(angle) <= limit:
			continue
		var corrected := forward.rotated(limit * signf(angle)) * offset.length()
		points[index] = _anchor + corrected


func _is_finite() -> bool:
	for point in points:
		if not (is_finite(point.x) and is_finite(point.y)):
			return false
	return true


func _recover() -> void:
	# Only for genuinely invalid state. An awkward-looking rope is not a reason to
	# reset one: resetting is what makes the Vine look re-spawned.
	build(_anchor, _reach)
	_recovery_remaining = recovery_seconds


func get_wrap_index() -> int:
	## The first point past which Grandma can no longer see the rest of the rope in
	## a straight line -- that is, where the Vine has actually gone around
	## something. Returns -1 when the whole body is in the open.
	##
	## This is deliberately not "the rope is bent": a whipping rope curves sharply
	## all the time under its own momentum. A wrap is specifically terrain between
	## the anchor and the far end, with the rope itself still legal, which is the
	## only shape Climber is meant to answer.
	if territory_field == null or points.size() < 3:
		return -1
	for index in range(1, points.size()):
		if not territory_field.is_growth_path_clear(points[0], points[index]):
			return index
	return -1


func is_wrapped() -> bool:
	return get_wrap_index() >= 0


func get_bend_count(tolerance_degrees: float = 25.0) -> int:
	## How many real corners the rope is currently folded around. Climber requires
	## an actual bend rather than a routed line, so this counts the shape the
	## simulation is genuinely in.
	if points.size() < 3:
		return 0
	var limit := deg_to_rad(tolerance_degrees)
	var bends := 0
	for index in range(1, points.size() - 1):
		var incoming := points[index] - points[index - 1]
		var outgoing := points[index + 1] - points[index]
		if incoming.length_squared() <= 0.0001 or outgoing.length_squared() <= 0.0001:
			continue
		if absf(incoming.angle_to(outgoing)) > limit:
			bends += 1
	return bends


func get_first_bend_index(tolerance_degrees: float = 25.0) -> int:
	if points.size() < 3:
		return -1
	var limit := deg_to_rad(tolerance_degrees)
	for index in range(1, points.size() - 1):
		var incoming := points[index] - points[index - 1]
		var outgoing := points[index + 1] - points[index]
		if incoming.length_squared() <= 0.0001 or outgoing.length_squared() <= 0.0001:
			continue
		if absf(incoming.angle_to(outgoing)) > limit:
			return index
	return -1


func get_total_length() -> float:
	var total := 0.0
	for index in range(points.size() - 1):
		total += points[index].distance_to(points[index + 1])
	return total


func get_chain_position(index: int) -> float:
	## How far along the rope a segment sits, from 0 at Grandma to 1 at the tip.
	## Reported with every hit so damage falloff and Apical both read the same
	## measurement the rope actually has.
	if points.size() < 2:
		return 0.0
	var total := get_total_length()
	if total <= 0.0001:
		return 0.0
	var travelled := 0.0
	for step in range(mini(index, points.size() - 1)):
		travelled += points[step].distance_to(points[step + 1])
	return clampf(travelled / total, 0.0, 1.0)


func is_apical_at(index: int) -> bool:
	## Whether a segment sits in the outer share of the rope's own arc length. This
	## is measured along the Vine rather than as a distance from Grandma, so a
	## wrapped Vine's sweet spot follows the rope around the corner.
	return get_chain_position(index) >= _apical_threshold


func collect_hits(
	enemy_ids: PackedInt32Array,
	positions: PackedVector2Array,
	radii: PackedFloat32Array
) -> Array:
	## Swept-segment collision against the actual simulated body. Each enemy takes
	## at most one hit per sweep however many segments touch it; if any contact came
	## from the Apical portion the resolved hit is Apical.
	var hits: Array = []
	if not _sweep_active or points.size() < 2:
		return hits
	for enemy_index in range(enemy_ids.size()):
		var enemy_id := enemy_ids[enemy_index]
		if _hit_enemy_ids.has(enemy_id):
			continue
		var enemy_position := positions[enemy_index]
		var radius := radii[enemy_index] if enemy_index < radii.size() else 8.0
		var struck := false
		var apical := false
		var chain_position := 0.0
		for index in range(points.size() - 1):
			# Tested against where the segment was as well as where it is, so the
			# fast tip cannot step straight over a body between two frames.
			if not _segment_touches(index, enemy_position, radius):
				continue
			var position_along := get_chain_position(index)
			if not struck or position_along > chain_position:
				chain_position = position_along
			struck = true
			if position_along >= _apical_threshold:
				apical = true
				break
		if not struck:
			continue
		_hit_enemy_ids.append(enemy_id)
		hits.append([enemy_id, apical, chain_position])
	return hits


func _segment_touches(index: int, target: Vector2, radius: float) -> bool:
	var current_first := points[index]
	var current_second := points[index + 1]
	if Geometry2D.get_closest_point_to_segment(
		target, current_first, current_second
	).distance_to(target) <= radius:
		return true
	if _previous_segments.size() <= index + 1:
		return false
	var previous_first := _previous_segments[index]
	var previous_second := _previous_segments[index + 1]
	if Geometry2D.get_closest_point_to_segment(
		target, previous_first, previous_second
	).distance_to(target) <= radius:
		return true
	# The quad the segment swept between the two frames, approximated by its
	# diagonals, which is enough to catch a body the tip crossed over.
	return (
		Geometry2D.get_closest_point_to_segment(
			target, previous_first, current_second
		).distance_to(target) <= radius
		or Geometry2D.get_closest_point_to_segment(
			target, previous_second, current_first
		).distance_to(target) <= radius
	)
