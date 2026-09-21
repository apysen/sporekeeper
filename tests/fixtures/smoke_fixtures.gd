## Fixtures for `tests/integration/run_smoke.gd`.
##
## These build the situation a check needs - a grown territory, a place to stand,
## an Adaptation already drafted - and then get out of the way. Not one of them
## asserts anything: a fixture that could fail a check would make a failure
## ambiguous between the setup and the thing being measured.
##
## They are static because none of them holds state. Each takes the run it is
## acting on, reaches into `TerritoryField`'s arrays or `Progression`'s draft the
## way the run itself would, and returns a position, a handle or nothing.
class_name SmokeFixtures
extends RefCounted


static func find_open_ground_position(prototype: RunRoot) -> Vector2:
	var field := prototype.territory_field
	var width := field.tuning.field_size.x
	for y in range(3, field.tuning.field_size.y - 3):
		for x in range(3, width - 3):
			var index := y * width + x
			if field._claimable_mask[index] == 0:
				continue
			if field._control[index] > field.tuning.ownership_threshold:
				continue
			# Checked the way the run checks it, not the way the array stores it.
			# `get_control_at_local` samples between cells, so an unowned cell with
			# owned neighbours still reads as standing on Green -- and every fixture
			# that steps off the Green to drop a ring was handed one of those.
			var candidate := field.cell_to_local(Vector2(x, y))
			if field.get_control_at_local(candidate) <= field.tuning.ownership_threshold:
				return candidate
	return Vector2(-1.0, -1.0)


## The nearest unowned ground to a given point, rather than the first one the scan
## happens to reach. Stepping off your own Green is a step: a fixture that teleports
## the player across the arena leaves whatever was orbiting them stranded behind,
## which is not the situation any of this is designed for.
static func find_open_ground_near(prototype: RunRoot, origin: Vector2) -> Vector2:
	var field := prototype.territory_field
	var width := field.tuning.field_size.x
	var best := Vector2(-1.0, -1.0)
	var best_distance := INF
	for y in range(3, field.tuning.field_size.y - 3):
		for x in range(3, width - 3):
			var index := y * width + x
			if field._claimable_mask[index] == 0:
				continue
			if field._control[index] > field.tuning.ownership_threshold:
				continue
			var candidate := field.cell_to_local(Vector2(x, y))
			var distance := origin.distance_squared_to(candidate)
			if distance < best_distance:
				best_distance = distance
				best = candidate
	return best


static func thorn_all_owned_ground(prototype: RunRoot) -> void:
	# Thorns on every owned cell, not only the frontier, so a cycle that eats the
	# interior still tears some out and Deadfall has something to convert.
	var field := prototype.territory_field
	for index in range(field._bramble_development.size()):
		if field._control[index] > field.tuning.ownership_threshold:
			field._bramble_development[index] = 1.0


static func grow_test_ecosystem(prototype: RunRoot) -> void:
	# A territory big enough to prune, since the starting foothold sits under the
	# safety floor by design.
	var arena := prototype.territory_field.tuning.arena_size
	for grow_index in range(14):
		var grow_spot := Vector2(
			arena.x * (0.18 + 0.06 * float(grow_index % 7)),
			arena.y * (0.30 + 0.30 * float(grow_index / 7))
		)
		prototype.territory_field.queue_seed_growth(grow_spot, 4.0, 0.0, 1.0, 3.0)
	prototype.territory_field._apply_pending_commands()
	step_field(prototype.territory_field, 40)


static func graze_owned_ground(
	prototype: RunRoot,
	home: Vector2,
	angle: float
) -> void:
	# Pruning's harvest eats the ground under the player, so a fixture that stands
	# still burns its own footing out. Grazing is what a run actually does to keep a
	# ring turning, and it is what the fixture has to do too.
	#
	# The circle has to be wider than the harvest itself or it is not grazing: a sweep
	# inside `upkeep_radius_pixels` re-treads ground the last lap already cut, which
	# starves the ring exactly as standing still does. Widest-first, because the test
	# ecosystem is not always big enough for the wide lap and a graze onto ground the
	# run does not own is no graze at all.
	# The circle has to be wider than the harvest itself or it is not grazing: a sweep
	# inside `upkeep_radius_pixels` re-treads ground the last lap already cut, which
	# starves the ring exactly as standing still does.
	#
	# Widest-first, and the angle is a heading rather than a promise. `home` is often
	# the first owned cell found scanning from the corner, so half of a wide circle
	# around it is off the field or off the Green; swinging the heading until the step
	# lands on owned ground keeps her inside the garden and still moving.
	var field := prototype.territory_field
	var harvest_radius: float = prototype.pruning_director.upkeep_radius_pixels
	for radius in [harvest_radius * 1.6, harvest_radius * 1.2]:
		for swing in [0.0, 0.7, -0.7, 1.4, -1.4, 2.1, -2.1, 2.8, -2.8, PI]:
			var graze: Vector2 = home + Vector2.from_angle(angle + swing) * radius
			if field.get_control_at_local(graze) > field.tuning.ownership_threshold:
				prototype.player.global_position = field.to_global(graze)
				return


static func stand_on_owned_ground(prototype: RunRoot) -> Vector2:
	# The harvest happens under the player, so a Pruning check has to put the player
	# on their own ground first. In a run that is the whole input to the path.
	var spot := find_owned_cell_position(prototype)
	prototype.player.global_position = prototype.territory_field.to_global(spot)
	return spot


## Owned ground with room around it for a ring to orbit in. `find_owned_cell_position`
## scans from the corner and returns the first owned cell it meets, which puts the
## player about 30px from the field edge - inside the 44-70px orbit radius, so a third
## of the ring sits outside the arena and is culled the moment it launches. Anything
## measuring the whole ring has to stand where the whole ring fits.
static func find_owned_cell_with_clearance(prototype: RunRoot, clearance: float) -> Vector2:
	var field := prototype.territory_field
	var width := field.tuning.field_size.x
	var extent := field.cell_to_local(Vector2(width, field.tuning.field_size.y))
	for y in range(3, field.tuning.field_size.y - 3):
		for x in range(3, width - 3):
			if field._control[y * width + x] <= 0.5:
				continue
			var candidate := field.cell_to_local(Vector2(x, y))
			if (
				candidate.x >= clearance
				and candidate.y >= clearance
				and candidate.x <= extent.x - clearance
				and candidate.y <= extent.y - clearance
			):
				return candidate
	return Vector2(-1.0, -1.0)


static func find_owned_cell_position(prototype: RunRoot) -> Vector2:
	var field := prototype.territory_field
	var width := field.tuning.field_size.x
	for y in range(3, field.tuning.field_size.y - 3):
		for x in range(3, width - 3):
			if field._control[y * width + x] > 0.5:
				return field.cell_to_local(Vector2(x, y))
	return Vector2(-1.0, -1.0)


static func restore_green_in_radius(
	field: TerritoryField,
	local_position: Vector2,
	radius_pixels: float
) -> void:
	# Write the ground back rather than waiting on the field to reclaim it, so a
	# check about territory does not also depend on how fast Green happens to
	# spread that day.
	var cell := field.local_to_cell(local_position)
	var width := int(field.tuning.field_size.x)
	var height := int(field.tuning.field_size.y)
	var radius_cells := radius_pixels / (field.tuning.arena_size.x / float(width))
	for y in range(height):
		for x in range(width):
			if Vector2(float(x), float(y)).distance_to(cell) > radius_cells:
				continue
			var index := y * width + x
			if field._claimable_mask[index] == 0:
				continue
			field._control[index] = 1.0
	field.recalculate_metrics_now()


static func step_field(field: TerritoryField, count: int) -> void:
	for _index in range(count):
		field.step_simulation()
	field.recalculate_metrics_now()


static func paint_lane(field: TerritoryField, origin: Vector2, control: float) -> void:
	# A wide corridor of one owner, so a thrown glob crosses nothing else.
	var width := int(field.tuning.field_size.x)
	var height := int(field.tuning.field_size.y)
	var cell := field.local_to_cell(origin)
	for y in range(height):
		for x in range(width):
			if absf(float(y) - cell.y) > 6.0:
				continue
			if float(x) < cell.x - 2.0 or float(x) > cell.x + 40.0:
				continue
			var index := y * width + x
			if field._claimable_mask[index] == 0:
				continue
			field._control[index] = control


static func throw_one_glob(bloom: BloomDirector, origin: Vector2) -> float:
	# One glob, thrown along the lane, flown until it lands. The answer is how far
	# it actually got.
	for glob in bloom._globs:
		glob.active = false
	bloom._launch_glob(origin, Vector2.RIGHT, bloom.glob_launch_speed, 4.0, 2.0, 1.0, 0)
	var travelled := 0.0
	for _step in range(240):
		bloom.advance(1.0 / 60.0)
		if bloom.get_active_glob_count() == 0:
			break
	for glob in bloom._globs:
		travelled = maxf(travelled, glob.travelled)
	return travelled


static func find_player_frontier(field: TerritoryField) -> Vector2:
	# Return the centre of a real frontier cell so callers that convert the
	# position back into a cell index land on the cell they were shown.
	var cells := find_player_frontier_cells(field, 1)
	if cells[0].x < 0:
		return Vector2(-1.0, -1.0)
	return field.cell_to_local(Vector2(cells[0]))


static func acquire_adaptation(prototype: RunRoot, path_id: int) -> void:
	## Enters one Adaptation the way a run does: by drafting one of its lines. The
	## fixture forces the offer onto the line it wants rather than waiting for the
	## seed to deal it, but the commitment itself goes through choose_upgrade.
	if prototype.progression.owns_adaptation(path_id):
		return
	var lines := prototype.progression.get_adaptation_line_ids(path_id)
	if lines.is_empty():
		return
	prototype.progression._pending_upgrade_options = PackedInt32Array([lines[0]])
	prototype.progression.choose_upgrade(lines[0])


static func seed_run_adaptations(
	prototype: RunRoot,
	first_core: int,
	second_core: int
) -> void:
	## A Core pair committed, so a fixture that is about to draft has an owned build
	## to draft into.
	prototype.progression.debug_select_paths(first_core, second_core)


static func take_offered_upgrade(prototype: RunRoot, upgrade_id: int) -> void:
	## Spends a level on one named line. The draft is weighted rather than walked
	## from a cursor, so a fixture that needs a specific line puts it on the screen
	## instead of re-rolling seeds until it appears; the commitment itself still goes
	## through the run's own selection path.
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	if not prototype.progression.get_pending_upgrade_options().has(upgrade_id):
		prototype.progression._pending_upgrade_options = PackedInt32Array([upgrade_id])
		prototype._choice_ids = PackedInt32Array([upgrade_id])
	prototype._choose_displayed_option(
		maxi(0, prototype._choice_ids.find(upgrade_id))
	)


static func spawn_bramble_contact_enemy(
	prototype: RunRoot,
	role: int,
	local_position: Vector2
) -> EnemyState:
	var enemy_id := prototype.combat.spawn_enemy(role, local_position)
	for enemy in prototype.combat._enemies:
		if enemy.id == enemy_id:
			enemy.position = local_position
			return enemy
	return null


static func maximum_frontier_development(field: TerritoryField) -> float:
	var maximum := 0.0
	for index in range(field._bramble_development.size()):
		if field._player_frontier_mask[index] == 0:
			continue
		maximum = maxf(maximum, field._bramble_development[index])
	return maximum


static func find_distant_frontier_index(
	field: TerritoryField,
	local_position: Vector2,
	minimum_distance: float
) -> int:
	var width := field.tuning.field_size.x
	for y in range(2, field.tuning.field_size.y - 2):
		for x in range(2, width - 2):
			var index := y * width + x
			if field._player_frontier_mask[index] == 0:
				continue
			if field._bramble_development[index] <= 0.0:
				continue
			if field.cell_to_local(Vector2(x, y)).distance_to(local_position) < minimum_distance:
				continue
			return index
	return -1


static func find_deep_owned_position(field: TerritoryField) -> Vector2:
	var index := find_deep_owned_cell(field, 12.0)
	if index < 0:
		return Vector2(-1.0, -1.0)
	var width := field.tuning.field_size.x
	return field.cell_to_local(Vector2(index % width, index / width))


static func find_deep_owned_cell(field: TerritoryField, band_pixels: float) -> int:
	# Owned ground far enough from any border that the frontier hedge cannot reach
	# it, so an interior-only effect can be measured on its own.
	var width := field.tuning.field_size.x
	for y in range(3, field.tuning.field_size.y - 3):
		for x in range(3, width - 3):
			var index := y * width + x
			if (
				field._player_frontier_mask[index] != 0
				or field._control[index] <= field.tuning.ownership_threshold
			):
				continue
			if field.is_player_frontier_at_local(
				field.cell_to_local(Vector2(x, y)),
				band_pixels
			):
				continue
			return index
	return -1


static func find_owned_cell_behind_frontier(field: TerritoryField) -> int:
	var width := field.tuning.field_size.x
	for y in range(2, field.tuning.field_size.y - 2):
		for x in range(2, width - 2):
			var index := y * width + x
			if (
				field._player_frontier_mask[index] != 0
				or field._control[index] <= field.tuning.ownership_threshold
			):
				continue
			var touches_frontier := (
				field._player_frontier_mask[index - 1] != 0
				or field._player_frontier_mask[index + 1] != 0
				or field._player_frontier_mask[index - width] != 0
				or field._player_frontier_mask[index + width] != 0
			)
			if touches_frontier:
				return index
	return -1


static func find_player_frontier_cells(field: TerritoryField, wanted: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var width := field.tuning.field_size.x
	for y in range(2, field.tuning.field_size.y - 2):
		for x in range(2, width - 2):
			if field._player_frontier_mask[y * width + x] == 0:
				continue
			found.append(Vector2i(x, y))
			if found.size() >= wanted:
				return found
	while found.size() < wanted:
		found.append(Vector2i(-1, -1))
	return found


static func minimum_frontier_development(field: TerritoryField) -> float:
	var minimum := 1.0
	for index in range(field._bramble_development.size()):
		if field._player_frontier_mask[index] == 0:
			continue
		minimum = minf(minimum, field._bramble_development[index])
	return minimum


static func find_green_unclaimable_cell(field: TerritoryField) -> Vector2i:
	var width := field.tuning.field_size.x
	var height := field.tuning.field_size.y
	for y in range(2, height - 2):
		for x in range(2, width - 2):
			var index := y * width + x
			if (
				field._claimable_mask[index] == 0
				or field._control[index] <= field.tuning.ownership_threshold
			):
				continue
			var touches_rock := (
				field._claimable_mask[index - 1] == 0
				or field._claimable_mask[index + 1] == 0
				or field._claimable_mask[index - width] == 0
				or field._claimable_mask[index + width] == 0
			)
			if touches_rock and not field._is_player_frontier_cell(x, y):
				return Vector2i(x, y)
	return Vector2i(-1, -1)
