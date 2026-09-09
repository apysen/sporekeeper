extends SceneTree

## The cached Root Network projection has to agree with the flood fill it replaced.
##
## get_mature_projection_at used to run one breadth-first search per query, outward
## from the queried cell until it found Mature Green. It now runs one pass inward
## from every Mature cell and caches the whole field per revision. Distance through
## Green is symmetric, so the two should agree exactly -- but "should" is why this
## exists: the reference implementation below is the old algorithm, kept verbatim,
## and every owned cell is checked against it.
##
## It also checks the cache invalidates. A projection that is correct once and then
## never updates is worse than the flood fill was.

const NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]
const REACH_PIXELS := 120.0
const MINIMUM_MATURITY := 0.90

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_error := change_scene_to_file("res://scenes/run/run.tscn")
	if load_error != OK:
		push_error("Unable to load Sporekeeper run: %s" % error_string(load_error))
		quit(1)
		return
	await process_frame
	await process_frame
	var prototype := current_scene as RunRoot
	if prototype == null:
		push_error("Sporekeeper run scene did not become current")
		quit(1)
		return
	prototype.set_process(false)
	prototype.player.input_enabled = false
	var field := prototype.territory_field

	# A field with a real mixture: an established core that has had time to mature,
	# and fresh Green around it that has not.
	field.reset_field()
	for _step in range(12):
		field.step_simulation()
	var seeded := _seed_mature_core(field)
	_check(seeded > 0, "the fixture has Mature Green to project from")

	var compared := 0
	var mismatches := 0
	var worst_delta := 0.0
	for index in range(field._cell_count):
		if field._claimable_mask[index] == 0:
			continue
		if field._control[index] <= field.tuning.ownership_threshold:
			continue
		var position := field.cell_to_local(
			Vector2(float(index % field._width), float(index / field._width))
		)
		var cached := field.get_mature_projection_at(
			position, REACH_PIXELS, MINIMUM_MATURITY
		)
		var reference := _reference_projection(field, position)
		compared += 1
		var delta := absf(cached - reference)
		if delta > worst_delta:
			worst_delta = delta
		if delta > 0.0001:
			mismatches += 1
	print(
		"MATURE_PROJECTION: compared=%d mismatches=%d worst_delta=%.6f" % [
			compared, mismatches, worst_delta
		]
	)
	_check(compared > 200, "the sweep covers a meaningful amount of owned Green")
	_check(
		mismatches == 0,
		"the cached projection matches the per-query flood fill on every owned cell"
	)

	# Off the board, and on ground nobody owns, both still answer nothing.
	_check(
		is_equal_approx(
			field.get_mature_projection_at(Vector2(-500.0, -500.0), REACH_PIXELS), 0.0
		),
		"a point off the board projects nothing"
	)

	# Invalidation: maturing new ground has to change the answer next time it is
	# asked, rather than serving the field the cache was built from.
	var probe_position := _find_young_owned_position(field)
	_check(probe_position.x > -90000.0, "the fixture has young owned Green to test with")
	var before := field.get_mature_projection_at(
		probe_position, REACH_PIXELS, MINIMUM_MATURITY
	)
	var probe_index := field.local_to_cell_index(probe_position)
	field._maturity[probe_index] = 1.0
	field._mark_field_changed()
	var after := field.get_mature_projection_at(
		probe_position, REACH_PIXELS, MINIMUM_MATURITY
	)
	_check(
		before < 1.0 and is_equal_approx(after, 1.0),
		"maturing a cell invalidates the cached projection instead of serving a stale one"
	)

	prototype.queue_free()
	await process_frame
	if _failures == 0:
		print("MATURE_PROJECTION: PASS")
		quit(0)
		return
	push_error("MATURE_PROJECTION: %d failure(s)" % _failures)
	quit(1)


func _seed_mature_core(field: TerritoryField) -> int:
	# Written straight into the field: the probe is about the projection, not about
	# how long ground takes to age.
	var seeded := 0
	for index in range(field._cell_count):
		if field._claimable_mask[index] == 0:
			continue
		if field._control[index] <= field.tuning.ownership_threshold:
			continue
		# Roughly a third of the owned cells, in a fixed pattern rather than at
		# random, so a failure can be reproduced.
		if index % 3 == 0:
			field._maturity[index] = 1.0
			seeded += 1
		else:
			field._maturity[index] = 0.2
	field._mark_field_changed()
	return seeded


func _find_young_owned_position(field: TerritoryField) -> Vector2:
	for index in range(field._cell_count):
		if field._claimable_mask[index] == 0:
			continue
		if field._control[index] <= field.tuning.ownership_threshold:
			continue
		if field._maturity[index] >= MINIMUM_MATURITY:
			continue
		return field.cell_to_local(
			Vector2(float(index % field._width), float(index / field._width))
		)
	return Vector2(-99999.0, -99999.0)


func _reference_projection(field: TerritoryField, local_position: Vector2) -> float:
	## The original algorithm, unchanged: one breadth-first search per query,
	## outward from the queried cell, stopping at the first Mature cell it reaches.
	var start := field.local_to_cell_index(local_position)
	if start < 0 or field._claimable_mask[start] == 0:
		return 0.0
	if field._control[start] <= field.tuning.ownership_threshold:
		return 0.0
	if field._maturity[start] >= MINIMUM_MATURITY:
		return 1.0
	var cell_width := field.tuning.arena_size.x / float(field._width)
	var cell_height := field.tuning.arena_size.y / float(field._height)
	var step := minf(cell_width, cell_height)
	var maximum_steps := int(ceil(REACH_PIXELS / maxf(1.0, step)))
	var visited := {start: 0}
	var frontier := PackedInt32Array([start])
	var depth := 0
	while not frontier.is_empty() and depth < maximum_steps:
		depth += 1
		var next_frontier := PackedInt32Array()
		for index in frontier:
			var x := index % field._width
			var y := index / field._width
			for offset in NEIGHBOUR_OFFSETS:
				var next_x := x + offset.x
				var next_y := y + offset.y
				if (
					next_x < 0
					or next_x >= field._width
					or next_y < 0
					or next_y >= field._height
				):
					continue
				var next_index := next_y * field._width + next_x
				if visited.has(next_index):
					continue
				if field._claimable_mask[next_index] == 0:
					continue
				if field._control[next_index] <= field.tuning.ownership_threshold:
					continue
				visited[next_index] = depth
				if field._maturity[next_index] >= MINIMUM_MATURITY:
					return clampf(1.0 - (float(depth) * step) / REACH_PIXELS, 0.0, 1.0)
				next_frontier.append(next_index)
		frontier = next_frontier
	return 0.0


func _check(passed: bool, description: String) -> void:
	if passed:
		print("PASS: %s" % description)
		return
	_failures += 1
	push_error("FAIL: %s" % description)
