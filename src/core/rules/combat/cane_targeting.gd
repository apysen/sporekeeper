class_name CaneTargeting
extends RefCounted

## Which way the Cane swings: the direction whose fixed-width sector holds the most
## of the targets it was handed.
##
## It never sees an enemy. `CombatDirector` walks its pool, drops anything out of
## range or behind a wall, and passes down two parallel arrays - a direction and a
## distance per surviving target - because deciding an angle needs neither the bodies
## nor the field, and a rule that reached for either could not live here.
##
## Testing every target on both edges of the sector as well as on its own bearing is
## what makes the answer independent of pool order: one of those candidates is always
## a maximal window, whatever order the targets arrived in.


## How far below the sector's cosine a dot product must sit before the cheap test
## is allowed to reject a target outright.
##
## `angle > threshold` and `dot < cos(threshold)` are the same condition for unit
## vectors, because cosine decreases monotonically over [0, PI]. Only floating
## point separates them, so backing the cut off by a margin far larger than the
## error in a normalized dot product leaves a band around the boundary that is
## still decided by `angle_to` exactly as before. Nothing inside the sector, or
## near enough to be arguable, is ever rejected by arithmetic.
const SECTOR_DOT_MARGIN := 1.0e-5

## How the densest-target search evaluates each candidate sector.
##
## All three produce the same answer for any layout where the tie-breaker is not
## being asked to separate two candidates that are equal to within its own
## thresholds. They differ in cost and in how exactly they reproduce the original
## arithmetic, which is why the slow one stays available to probes forever.
enum Mode {
	## Every candidate/target pair decided by `angle_to`, as originally written.
	REFERENCE,
	## As REFERENCE, but a dot product may reject pairs that are plainly outside the
	## sector. Bit-identical to REFERENCE: it only skips work whose outcome was
	## already settled.
	DOT_PRUNE,
	## Angles sorted once, then each candidate's contained set found by binary
	## search and summarised from prefix sums. Mathematically identical to
	## REFERENCE, but NOT bit-identical: it forms the angular error as a difference
	## of two `atan2` results rather than one `atan2` of a cross and a dot, and
	## sums in sorted order rather than pool order. Both are exact to roughly 1e-7,
	## against a tie-breaker with 1e-4 thresholds.
	SORTED,
}

## Which mode ships. Kept as a constant rather than inlined so a regression can be
## bisected by changing one line.
const SHIPPING_MODE := Mode.SORTED


## The best direction for `target_directions`, or `fallback` when nothing was handed
## down. Entries pair up by index: `target_distances[i]` belongs to
## `target_directions[i]`, and neither array is read after this returns.
static func densest_direction(
	target_directions: PackedVector2Array,
	target_distances: PackedFloat32Array,
	fallback: Vector2,
	sector_degrees: float,
	mode: Mode
) -> Vector2:
	if target_directions.is_empty():
		return fallback
	var half_angle := deg_to_rad(clampf(sector_degrees, 1.0, 359.0) * 0.5)
	# The angular threshold the loop below tests against, and the dot product that
	# corresponds to it. A sector wide enough that no angle can fall outside pushes
	# this under -1, at which point nothing is ever rejected early -- which is the
	# correct behaviour, not a special case.
	var angle_threshold := half_angle + 0.0001
	var rejection_dot := cos(angle_threshold) - SECTOR_DOT_MARGIN
	var candidate_directions := PackedVector2Array()
	# Unit copies, built once, used only by the cheap rejection.
	#
	# These entries are not unit vectors. Gathering divides the straight-line offset
	# by `distance`, and with auto-targeting on `distance` has by then been replaced
	# with the routed path length, which is longer -- so the "direction" comes out
	# shorter than one. `angle_to` never noticed, because atan2 of cross over dot is
	# scale invariant. A raw dot product is not: it returns |a||b|cos(angle), so
	# against short vectors it reads as a wider angle than the real one and rejects
	# targets that are actually inside the sector. Normalizing here costs one pass
	# and keeps the arrays the tie-breaker reads untouched.
	var target_units := PackedVector2Array()
	var candidate_units := PackedVector2Array()
	for direction in target_directions:
		candidate_directions.append(direction)
		candidate_directions.append(direction.rotated(-half_angle))
		candidate_directions.append(direction.rotated(half_angle))
		var unit := direction.normalized()
		target_units.append(unit)
		candidate_units.append(unit)
		candidate_units.append(unit.rotated(-half_angle))
		candidate_units.append(unit.rotated(half_angle))
	# Sorted mode's one-off preparation. Angles are laid out three times -- shifted
	# down a turn, as measured, and shifted up a turn -- so that a candidate's window
	# is one contiguous run whatever it straddles, with no wrap-around case to get
	# wrong. A window is narrower than a full turn (the widest legal sector is just
	# under 360 degrees), so no target can appear in one twice.
	var sorted_angles := PackedFloat64Array()
	var prefix_distance := PackedFloat64Array()
	var prefix_angle := PackedFloat64Array()
	if mode == Mode.SORTED:
		var order: Array[int] = []
		var raw_angles := PackedFloat64Array()
		for index in range(target_directions.size()):
			var target_vector := target_directions[index]
			raw_angles.append(atan2(target_vector.y, target_vector.x))
			order.append(index)
		order.sort_custom(
			func(first: int, second: int) -> bool:
				return raw_angles[first] < raw_angles[second]
		)
		var turn := TAU
		for copy in range(3):
			var shift := float(copy - 1) * turn
			for index in order:
				sorted_angles.append(raw_angles[index] + shift)
		prefix_distance.resize(sorted_angles.size() + 1)
		prefix_angle.resize(sorted_angles.size() + 1)
		prefix_distance[0] = 0.0
		prefix_angle[0] = 0.0
		for index in range(sorted_angles.size()):
			var source_index: int = order[index % order.size()]
			prefix_distance[index + 1] = (
				prefix_distance[index] + float(target_distances[source_index])
			)
			prefix_angle[index + 1] = prefix_angle[index] + sorted_angles[index]

	var best_direction := fallback
	var best_count := -1
	var best_distance_sum := INF
	var best_alignment_error := INF
	var best_facing_difference := INF
	for candidate_index in range(candidate_directions.size()):
		var candidate := candidate_directions[candidate_index]
		var candidate_unit := candidate_units[candidate_index]
		var contained := 0
		var distance_sum := 0.0
		var alignment_error := 0.0
		if mode == Mode.SORTED:
			# The contained set is exactly the targets whose angle lies within the
			# threshold of this candidate's, which after sorting is one run. Splitting
			# that run at the candidate's own angle turns the sum of |candidate -
			# target| into two prefix-sum differences, so a candidate costs three
			# binary searches instead of a pass over every target.
			var candidate_angle := atan2(candidate.y, candidate.x)
			var low := _lower_bound_float(sorted_angles, candidate_angle - angle_threshold)
			var high := _upper_bound_float(sorted_angles, candidate_angle + angle_threshold)
			var split := _upper_bound_float(sorted_angles, candidate_angle)
			split = clampi(split, low, high)
			contained = high - low
			distance_sum = prefix_distance[high] - prefix_distance[low]
			var below := (
				candidate_angle * float(split - low)
				- (prefix_angle[split] - prefix_angle[low])
			)
			var above := (
				(prefix_angle[high] - prefix_angle[split])
				- candidate_angle * float(high - split)
			)
			alignment_error = below + above
		else:
			for index in range(target_directions.size()):
				var target := target_directions[index]
				# Most targets in a crowd are nowhere near any given candidate's
				# sector, and rejecting those costs a multiply instead of an atan2.
				# Anything that survives -- inside the sector, or close enough to the
				# edge to be arguable -- still goes through `angle_to` and the
				# identical test, and a contained target needs its true angular error
				# anyway.
				if (
					mode == Mode.DOT_PRUNE
					and candidate_unit.dot(target_units[index]) < rejection_dot
				):
					continue
				var angular_error := absf(candidate.angle_to(target))
				if angular_error > angle_threshold:
					continue
				contained += 1
				distance_sum += target_distances[index]
				alignment_error += angular_error
		var facing_difference := absf(fallback.angle_to(candidate))
		if (
			contained > best_count
			or (
				contained == best_count
				and distance_sum < best_distance_sum - 0.001
			)
			or (
				contained == best_count
				and absf(distance_sum - best_distance_sum) <= 0.001
				and alignment_error < best_alignment_error - 0.0001
			)
			or (
				contained == best_count
				and absf(distance_sum - best_distance_sum) <= 0.001
				and absf(alignment_error - best_alignment_error) <= 0.0001
				and facing_difference < best_facing_difference - 0.0001
			)
		):
			best_direction = candidate
			best_count = contained
			best_distance_sum = distance_sum
			best_alignment_error = alignment_error
			best_facing_difference = facing_difference
	return best_direction.normalized()


static func _lower_bound_float(values: PackedFloat64Array, wanted: float) -> int:
	## First index whose value is >= wanted.
	var low := 0
	var high := values.size()
	while low < high:
		var middle := (low + high) / 2
		if values[middle] < wanted:
			low = middle + 1
		else:
			high = middle
	return low


static func _upper_bound_float(values: PackedFloat64Array, wanted: float) -> int:
	## First index whose value is > wanted.
	var low := 0
	var high := values.size()
	while low < high:
		var middle := (low + high) / 2
		if values[middle] <= wanted:
			low = middle + 1
		else:
			high = middle
	return low
