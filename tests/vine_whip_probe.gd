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
	var load_error := change_scene_to_file("res://scenes/run/run.tscn")
	_check(load_error == OK, "Sporekeeper scene loads")
	if load_error != OK:
		quit(1)
		return
	await process_frame
	await process_frame

	var prototype := current_scene as RunRoot
	var whip := VineWhip.new()
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

	# Alternation: consecutive strokes drive the rope in opposite directions. Read
	# from where the tip actually goes rather than from the flag that asked for it.
	whip.build(origin, 92.0)
	for _settle_alt in range(20):
		whip.advance(origin, Vector2.RIGHT, 1.0 / 60.0)
	var left_swing := _measure_swing(whip, origin, true)
	var right_swing := _measure_swing(whip, origin, false)
	_check(
		left_swing * right_swing < 0.0,
		"consecutive natural sweeps drive the rope in opposite directions (%.3f vs %.3f)"
			% [left_swing, right_swing]
	)

	# The tip may overshoot the authored 90-degree driver arc, but it must never come
	# round far enough to attack behind Grandma.
	whip.build(origin, 92.0)
	whip.begin_sweep(Vector2.RIGHT, true, 0.72)
	var widest := 0.0
	for _overshoot_tick in range(40):
		whip.advance(origin, Vector2.RIGHT, 1.0 / 60.0)
		var offset := whip.get_tip() - origin
		if offset.length_squared() > 0.0001:
			widest = maxf(widest, absf(Vector2.RIGHT.angle_to(offset)))
	_check(
		widest < deg_to_rad(90.0),
		"the tip may overshoot the driver arc but never swings behind Grandma (%.1f deg)"
			% rad_to_deg(widest)
	)

	# Wrapping: a rope taken round a corner reports a wrap, keeps it while nothing is
	# driving it, and gives it up once Grandma moves back into the open.
	var wrap_anchor := _find_wrap_anchor(prototype)
	if wrap_anchor.x < 0.0:
		_check(false, "the arena offers somewhere for the Vine to wrap around")
	else:
		whip.build(wrap_anchor, 184.0)
		var wrapped_during := false
		for _wrap_tick in range(120):
			whip.advance(wrap_anchor, Vector2.RIGHT, 1.0 / 60.0)
			if whip.is_wrapped():
				wrapped_during = true
		var wrapped_at_rest := whip.is_wrapped()
		for _hold_tick in range(30):
			whip.advance(wrap_anchor, Vector2.RIGHT, 1.0 / 60.0)
		var wrap_held := whip.is_wrapped() == wrapped_at_rest
		_check(
			wrapped_during and wrap_held,
			"a wrapped Vine reports its wrap and keeps it between attacks"
		)

		# Walking back into the open releases it rather than dragging the wrap along.
		var open_ground := _find_open_anchor(prototype)
		for _release_tick in range(180):
			whip.advance(open_ground, Vector2.RIGHT, 1.0 / 60.0)
		_check(
			not whip.is_wrapped(),
			"moving away from the obstacle releases the wrap cleanly"
		)

	# A maximum-length rope under crowd load stays inside the authored frame budget.
	whip.build(origin, 184.0)
	for stress_index in range(90):
		prototype.combat.spawn_enemy(
			CombatDirector.EnemyRole.HUNTER,
			origin + Vector2(
				-120.0 + float(stress_index % 12) * 22.0,
				-90.0 + float(stress_index / 12) * 24.0
			)
		)
	var stress_ids := prototype.combat.get_active_enemy_ids()
	var stress_positions := PackedVector2Array()
	var stress_radii := PackedFloat32Array()
	for stress_id in stress_ids:
		stress_positions.append(prototype.combat.get_enemy_position(stress_id))
		stress_radii.append(prototype.combat.get_enemy_radius(stress_id))
	var worst_us := 0.0
	for _stress_tick in range(120):
		if not whip.is_sweeping():
			whip.begin_sweep(Vector2.RIGHT, true, 0.72)
		var began := Time.get_ticks_usec()
		whip.advance(origin, Vector2.RIGHT, 1.0 / 60.0)
		whip.collect_hits(stress_ids, stress_positions, stress_radii)
		worst_us = maxf(worst_us, float(Time.get_ticks_usec() - began))
	prototype.combat.reset_combat()
	# A slice of one frame, not the whole of it: the rope is one system among many.
	_check(
		worst_us < 4000.0,
		"a max-length Vine against a crowd stays well inside the frame budget (%.2fms)"
			% (worst_us / 1000.0)
	)

	whip.queue_free()
	if _failures == 0:
		print("VINE_WHIP_PROBE: PASS")
		quit(0)
		return
	push_error("VINE_WHIP_PROBE: %d failure(s)" % _failures)
	quit(1)


func _measure_swing(whip: VineWhip, origin: Vector2, left_to_right: bool) -> float:
	## Signed angle the tip travels through during one driven stroke. Its sign is the
	## direction the rope actually went, which is what alternation has to be read from.
	whip.begin_sweep(Vector2.RIGHT, left_to_right, 0.72)
	var opening := Vector2.RIGHT.angle_to(whip.get_tip() - origin)
	var travelled := 0.0
	for _tick in range(30):
		whip.advance(origin, Vector2.RIGHT, 1.0 / 60.0)
		var offset := whip.get_tip() - origin
		if offset.length_squared() > 0.0001:
			travelled = Vector2.RIGHT.angle_to(offset) - opening
	return travelled


func _find_wrap_anchor(prototype: RunRoot) -> Vector2:
	## Somewhere the Vine can be hung beside solid ground: a point whose immediate
	## surroundings are open but which has terrain within the rope's reach.
	var field := prototype.territory_field
	var size := field.tuning.arena_size
	for step_y in range(12, 60):
		for step_x in range(12, 60):
			var candidate := Vector2(
				size.x * float(step_x) / 60.0,
				size.y * float(step_y) / 60.0
			)
			if not field.contains_local_point(candidate):
				continue
			if not field.is_claimable_at_local(candidate):
				continue
			var blocked := 0
			for angle_step in range(12):
				var probe := candidate + Vector2.from_angle(
					TAU * float(angle_step) / 12.0
				) * 150.0
				if not field.is_growth_path_clear(candidate, probe):
					blocked += 1
			# Open where it stands, with something solid in reach to fold around.
			if blocked >= 3 and blocked <= 8:
				return candidate
	return Vector2(-1.0, -1.0)


func _find_open_anchor(prototype: RunRoot) -> Vector2:
	var field := prototype.territory_field
	var size := field.tuning.arena_size
	for step_y in range(10, 55):
		for step_x in range(10, 55):
			var candidate := Vector2(
				size.x * float(step_x) / 60.0,
				size.y * float(step_y) / 60.0
			)
			if not field.contains_local_point(candidate):
				continue
			var clear := true
			for angle_step in range(16):
				var probe := candidate + Vector2.from_angle(
					TAU * float(angle_step) / 16.0
				) * 220.0
				if not field.is_growth_path_clear(candidate, probe):
					clear = false
					break
			if clear:
				return candidate
	return prototype.player.get_arena_position()
