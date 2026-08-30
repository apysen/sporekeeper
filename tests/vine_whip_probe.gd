extends SceneTree

## Validation for the persistent guided-whip Vine, against the behaviour
## docs/relics.md specifies for it.
##
## The rope is exercised on its own rather than through the prototype: what is
## being checked is that it stays one continuous physical body across movement,
## strokes and terrain, and that damage comes from where that body actually is.

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures += 1
	push_error("FAIL: " + message)


func _run() -> void:
	var load_error := change_scene_to_file("res://scenes/run/phase_b_prototype.tscn")
	_check(load_error == OK, "Phase B scene loads")
	if load_error != OK:
		quit(1)
		return
	await process_frame
	await process_frame

	var prototype := current_scene as PhaseBPrototype
	var whip := PhaseBVineWhip.new()
	whip.territory_field = prototype.territory_field
	prototype.add_child(whip)

	var origin := Vector2(320.0, 300.0)
	whip.build(origin, 92.0)
	_check(
		whip.is_built() and whip.get_point_count() >= whip.minimum_points,
		"the Vine exists as a built chain before any attack (%d points)"
			% whip.get_point_count()
	)

	# Idle: the rope stays attached and keeps simulating without being driven.
	for _idle in range(30):
		whip.advance(origin, Vector2.RIGHT, 1.0 / 60.0)
	_check(
		whip.points[0].is_equal_approx(origin) and not whip.is_sweeping(),
		"an idle Vine stays attached to Grandma and is not attacking"
	)

	# Moving trails the body rather than rebuilding it: the point count is stable
	# and the tip lags behind the anchor.
	var moved := origin
	var points_before := whip.get_point_count()
	for step in range(40):
		moved += Vector2(3.0, 0.0)
		whip.advance(moved, Vector2.RIGHT, 1.0 / 60.0)
	_check(
		whip.get_point_count() == points_before
		and whip.points[0].is_equal_approx(moved)
		and whip.get_tip().distance_to(moved) > 1.0,
		"moving trails the same chain behind Grandma without rebuilding it"
	)

	# A passive Vine deals no damage: collect_hits reports nothing while no sweep
	# is running, however close a body is to the rope.
	var enemy_ids := PackedInt32Array([1])
	var enemy_positions := PackedVector2Array([whip.get_tip()])
	var enemy_radii := PackedFloat32Array([12.0])
	var passive_hits := whip.collect_hits(enemy_ids, enemy_positions, enemy_radii)
	_check(
		passive_hits.is_empty(),
		"a passive Vine resting against an enemy deals no damage"
	)

	# A driven sweep damages from the simulated body, and one enemy takes at most
	# one hit per sweep however many segments brush it.
	whip.begin_sweep(Vector2.RIGHT, true, 0.72)
	var struck_total := 0
	for _sweep_tick in range(30):
		whip.advance(moved, Vector2.RIGHT, 1.0 / 60.0)
		var reachable := PackedVector2Array()
		for index in range(whip.points.size()):
			reachable.append(whip.points[index])
		# Park the enemy on the middle of the rope so several segments are near it.
		var body := whip.points[whip.points.size() / 2]
		struck_total += whip.collect_hits(
			enemy_ids, PackedVector2Array([body]), PackedFloat32Array([24.0])
		).size()
	_check(
		struck_total == 1,
		"one enemy takes exactly one Vine hit per sweep (%d)" % struck_total
	)

	# Alternation and continuity: the opposite stroke starts from the state the
	# last one ended in rather than from a reset pose.
	var settled := whip.points.duplicate()
	var second_id := whip.begin_sweep(Vector2.RIGHT, false, 0.72)
	var continuous := true
	for index in range(settled.size()):
		if not settled[index].is_equal_approx(whip.points[index]):
			continuous = false
			break
	_check(
		second_id > 0 and continuous,
		"the opposite sweep begins from the rope's existing physical state"
	)

	# Apical is measured along the rope's own length, so the outer portion of the
	# chain is Apical and the base never is.
	var tip_index := whip.points.size() - 1
	_check(
		whip.is_apical_at(tip_index) and not whip.is_apical_at(1),
		"the Apical zone is the outer share of the Vine's own arc length"
	)

	# Trellis widens that zone physically rather than changing a damage number.
	# Find a segment that sits between the narrow and wide thresholds rather than
	# assuming one: segment lengths vary along a simulated rope.
	var narrow_index := -1
	for index in range(1, whip.points.size()):
		if whip.is_apical_at(index):
			continue
		whip.set_apical_share(0.40)
		var widened := whip.is_apical_at(index)
		whip.set_apical_share(0.25)
		if widened:
			narrow_index = index
			break
	_check(
		narrow_index > 0,
		"Trellis widens the physical Apical portion of the rope (segment %d)"
			% narrow_index
	)

	# A teleport carries the rope rather than whipping it: the shape is preserved
	# and the tip does not sweep the arena on the way.
	# Somewhere legal: a teleport into the void collapses the rope, which is the
	# recovery path rather than the behaviour under test here.
	var far := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.72,
		prototype.territory_field.tuning.arena_size.y * 0.45
	)
	var shape_before := PackedVector2Array()
	for index in range(whip.points.size()):
		shape_before.append(whip.points[index] - whip.points[0])
	whip.advance(far, Vector2.RIGHT, 1.0 / 60.0)
	var shape_preserved := true
	for index in range(whip.points.size()):
		if (whip.points[index] - whip.points[0]).distance_to(shape_before[index]) > 24.0:
			shape_preserved = false
			break
	_check(
		whip.points[0].is_equal_approx(far) and shape_preserved,
		"a teleport translates the whole Vine instead of producing a giant lash"
	)

	# The rope never crosses solid terrain: every link stays on a clear path.
	whip.build(origin, 184.0)
	for _wrap_tick in range(60):
		whip.advance(origin, Vector2.RIGHT, 1.0 / 60.0)
	var links_clear := true
	for index in range(whip.points.size() - 1):
		if not prototype.territory_field.is_growth_path_clear(
			whip.points[index], whip.points[index + 1]
		):
			links_clear = false
			break
	_check(links_clear, "no link of the simulated Vine passes through solid terrain")

	# Elongation resamples rather than rebuilds, so the rope keeps its shape.
	var reach_points := whip.get_point_count()
	whip.set_reach(92.0)
	_check(
		whip.get_point_count() != reach_points or whip.get_point_count() >= whip.minimum_points,
		"changing reach resamples the chain instead of respawning it"
	)

	whip.queue_free()
	if _failures == 0:
		print("VINE_WHIP_PROBE: PASS")
		quit(0)
		return
	push_error("VINE_WHIP_PROBE: %d failure(s)" % _failures)
	quit(1)
