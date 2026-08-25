class_name PhaseBWagerSelector
extends Node

## Chooses which part of the organism goes on the table.
##
## A wager is not a percentage subtracted from a counter. It is a physical region of
## Green, grown outward from where the player is standing until it holds the right
## number of cells, and the player can see it before committing. That is the whole
## reason the machine is interesting: the cost of a spin is a shape, and the shape is
## the run's own body.
##
## The flood is a Dijkstra expansion rather than a radius, so a player standing in open
## Green gets something roughly circular while a player at the edge gets a region that
## deforms inward through the tissue instead of stamping a circle over ground nobody
## owns.
##
## It runs ten times a second while the player is deciding, so every question it asks
## about a cell is answered from one snapshot the field publishes at the start of the
## rebuild rather than by calling back into the field per cell. That single change is
## the difference between a preview that costs a frame and one that does not.

## Width of one cost bucket. Finer keeps the expansion order closer to an exact
## Dijkstra; coarser costs less. At this width two cells have to be within a twentieth
## of a step of each other before the queue stops telling them apart, which is far below
## anything the resulting shape shows.
const COST_QUANTUM := 0.05

@export_group("Collaborators")
## The field the wager is drawn from. The selector reads it and never writes to it;
## conversion is the field's own business.
@export var territory_field: TerritoryField

@export_group("Selection Cost")
## Extra traversal cost for fresh ground, at zero maturity. Immature Green is still
## real Green and can still be staked, but the flood should reach past a disposable
## sliver toward tissue that actually matters, so that losing a bet costs the organism
## something it will feel.
@export_range(0.0, 6.0, 0.05) var maturity_penalty := 1.50
## Extra traversal cost for ground on the boundary of the organism. Without it every
## wager would be a rim of edge cells, which is the cheapest possible shape and the
## least interesting one.
@export_range(0.0, 6.0, 0.05) var boundary_penalty := 1.00

## Dial's bucket queue. Step costs are bounded - one, plus the two penalties at most -
## so the frontier never spans more than a fixed window of cost, and the queue can be a
## ring of buckets with O(1) push and pop instead of a binary heap paying a dozen
## compare-and-swap levels on every one of several thousand pushes per rebuild.
var _bucket_head := PackedInt32Array()
var _bucket_count := 0
var _current_bucket := 0
var _queued := 0
## Entries rather than cells, so one cell may sit in the queue at several costs and the
## cheapest simply arrives first. The pool is reused across rebuilds.
var _entry_cell := PackedInt32Array()
var _entry_next := PackedInt32Array()
var _entry_cost := PackedFloat32Array()
var _entry_count := 0
var _visited := PackedInt32Array()
var _visit_generation := 0
var _selected := PackedInt32Array()
var _selected_mask := PackedInt32Array()
var _last_pop_cost := 0.0
## Maturity per owned cell and -1.0 elsewhere, republished by the field once per
## rebuild. Every ownership, maturity and exposure question in the flood is answered
## from here.
var _snapshot := PackedFloat32Array()
## Traversal cost per cell, and the best cost it has already been queued at. Both are
## filled the first time the flood touches a cell and stamped with the rebuild's
## generation, so the exposure count behind the cost is paid once per cell rather than
## once per neighbour that reaches it. Building them for the whole board up front was
## measurably worse: at the stakes below All In the flood never sees most of it.
var _step := PackedFloat32Array()
var _queued_cost := PackedFloat32Array()
var _touch_generation := PackedInt32Array()
var _width := 0
var _height := 0
var _cell_count := 0


func get_target_cell_count(stake: int, owned_cells: int) -> int:
	## How many cells this notch stakes right now, measured against what the run owns at
	## this instant rather than against anything banked earlier.
	if owned_cells <= 0:
		return 0
	if stake == CloverSlot.Stake.ALL_IN:
		return owned_cells
	return maxi(1, roundi(float(owned_cells) * CloverSlot.get_stake_fraction(stake)))


func select(stake: int, player_local_position: Vector2) -> PackedInt32Array:
	## The region this stake would take, seeded at the player. Deterministic: the same
	## board and the same position produce the same cells, so a preview held still does
	## not shimmer between equally good choices.
	if territory_field == null:
		return PackedInt32Array()
	_prepare()
	var owned_count := territory_field.refresh_ownership_snapshot()
	_snapshot = territory_field.get_ownership_snapshot()
	var target := get_target_cell_count(stake, owned_count)
	if target <= 0:
		return PackedInt32Array()
	if target >= owned_count:
		# All In, or a stake large enough to swallow the whole organism. Selection
		# completes immediately; any outward propagation is presentation, not a
		# different set of cells.
		return _collect_all_owned(owned_count)
	return _flood(target, player_local_position)


func _prepare() -> void:
	_width = territory_field.get_grid_width()
	_height = territory_field.get_grid_height()
	var cell_count := _width * _height
	if _visited.size() != cell_count:
		_visited.resize(cell_count)
		_visited.fill(0)
		_selected_mask.resize(cell_count)
		_selected_mask.fill(0)
		_touch_generation.resize(cell_count)
		_touch_generation.fill(0)
		_step.resize(cell_count)
		_queued_cost.resize(cell_count)
		_visit_generation = 0
	_cell_count = cell_count
	# A generation stamp rather than a cleared array, so a 10 Hz preview does not walk
	# the whole board twice per rebuild just to erase the last one.
	_visit_generation += 1
	# One bucket per quantum of cost, with room for the largest single step the current
	# penalties can produce. Anything narrower would let a newly pushed cell wrap past
	# the bucket being drained and come back out too early.
	var widest_step := 1.0 + maturity_penalty + boundary_penalty
	var wanted_buckets := int(ceil(widest_step / COST_QUANTUM)) + 2
	if _bucket_count != wanted_buckets:
		_bucket_count = wanted_buckets
		_bucket_head.resize(_bucket_count)
	_bucket_head.fill(-1)
	_current_bucket = 0
	_queued = 0
	_entry_count = 0
	_selected.resize(0)


func _collect_all_owned(owned_count: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	cells.resize(owned_count)
	var written := 0
	for index in range(_cell_count):
		if _snapshot[index] >= 0.0:
			cells[written] = index
			written += 1
	return cells


func _flood(target: int, player_local_position: Vector2) -> PackedInt32Array:
	var origin := _find_origin(player_local_position)
	if origin < 0:
		return PackedInt32Array()
	while _selected.size() < target:
		_push(origin, 0.0)
		_drain(target)
		if _selected.size() >= target:
			break
		# The player's own island did not hold enough. Rather than stopping short of
		# the stake the interface promised, the wager jumps to the nearest remaining
		# Green and keeps going, so a fragmented organism produces a wager in several
		# pieces. That is the honest picture of what a fragmented organism is.
		var next_origin := _find_nearest_unselected(origin)
		if next_origin < 0:
			break
		origin = next_origin
	return _selected.duplicate()


func _find_origin(player_local_position: Vector2) -> int:
	var index := territory_field.local_to_cell_index(player_local_position)
	if index >= 0 and index < _cell_count and _snapshot[index] >= 0.0:
		return index
	# Standing on neutral or hostile ground. The wager still has to come from somewhere
	# the run actually holds, so it starts at the closest Green instead of refusing.
	if index < 0:
		var cell := territory_field.local_to_cell(player_local_position)
		index = clampi(int(cell.y), 0, _height - 1) * _width + clampi(int(cell.x), 0, _width - 1)
	return _find_nearest_owned(index, false)


func _find_nearest_unselected(from_cell: int) -> int:
	return _find_nearest_owned(from_cell, true)


func _find_nearest_owned(from_cell: int, skip_selected: bool) -> int:
	# Measured in cells rather than pixels. Both are the same ordering and this one costs
	# no Vector2 per candidate, which matters because the fragmented case walks the whole
	# grid once per island the wager has to reach into.
	var from_x := from_cell % _width
	var from_y := from_cell / _width
	var best := -1
	var best_distance := 0x7FFFFFFF
	for index in range(_cell_count):
		if _snapshot[index] < 0.0:
			continue
		if skip_selected and _selected_mask[index] == _visit_generation:
			continue
		var offset_x := index % _width - from_x
		var offset_y := index / _width - from_y
		var distance := offset_x * offset_x + offset_y * offset_y
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


func _drain(target: int) -> void:
	# One flat loop over local arrays, with nothing in it calling out to another object.
	# That is the whole optimisation: the first version asked the field whether a cell was
	# owned and how mature it was, once per cell per neighbour, and spent twenty-six
	# milliseconds of a sixteen-millisecond frame doing it.
	#
	# Two caches keep the work down. A cell's traversal cost is computed the first time
	# the flood touches it rather than once per neighbour that reaches it, and a cell
	# already queued at a cheaper cost is not queued again, which removes most of the
	# duplicate entries the queue would otherwise carry and pop.
	var width := _width
	var last_column := width - 1
	var cell_count := _cell_count
	var generation := _visit_generation
	# Continues from whatever is already selected rather than from zero: a wager that has
	# run out of island comes back through here to keep filling from the next one, and
	# starting over would silently overwrite the piece it already chose.
	var selected_count := _selected.size()
	_selected.resize(target)
	while _queued > 0 and selected_count < target:
		var cell := _pop()
		if _visited[cell] == generation:
			continue
		_visited[cell] = generation
		if _snapshot[cell] < 0.0:
			continue
		_selected[selected_count] = cell
		selected_count += 1
		_selected_mask[cell] = generation
		var cost := _last_pop_cost
		var x := cell % width

		var neighbor := cell - 1
		if x > 0 and _visited[neighbor] != generation and _snapshot[neighbor] >= 0.0:
			if _touch_generation[neighbor] != generation:
				_touch_generation[neighbor] = generation
				_step[neighbor] = _compute_step(neighbor, x - 1)
				_queued_cost[neighbor] = INF
			var next := cost + _step[neighbor]
			if next < _queued_cost[neighbor]:
				_queued_cost[neighbor] = next
				_push(neighbor, next)

		neighbor = cell + 1
		if x < last_column and _visited[neighbor] != generation and _snapshot[neighbor] >= 0.0:
			if _touch_generation[neighbor] != generation:
				_touch_generation[neighbor] = generation
				_step[neighbor] = _compute_step(neighbor, x + 1)
				_queued_cost[neighbor] = INF
			var next := cost + _step[neighbor]
			if next < _queued_cost[neighbor]:
				_queued_cost[neighbor] = next
				_push(neighbor, next)

		neighbor = cell - width
		if neighbor >= 0 and _visited[neighbor] != generation and _snapshot[neighbor] >= 0.0:
			if _touch_generation[neighbor] != generation:
				_touch_generation[neighbor] = generation
				_step[neighbor] = _compute_step(neighbor, x)
				_queued_cost[neighbor] = INF
			var next := cost + _step[neighbor]
			if next < _queued_cost[neighbor]:
				_queued_cost[neighbor] = next
				_push(neighbor, next)

		neighbor = cell + width
		if neighbor < cell_count and _visited[neighbor] != generation and _snapshot[neighbor] >= 0.0:
			if _touch_generation[neighbor] != generation:
				_touch_generation[neighbor] = generation
				_step[neighbor] = _compute_step(neighbor, x)
				_queued_cost[neighbor] = INF
			var next := cost + _step[neighbor]
			if next < _queued_cost[neighbor]:
				_queued_cost[neighbor] = next
				_push(neighbor, next)
	_selected.resize(selected_count)


func _compute_step(cell: int, x: int) -> float:
	# Cheap through mature interior tissue, expensive across fresh growth and across the
	# rim of the organism. This is what decides the shape of the wager, and it changes
	# none of its size. The column is passed in because the caller already knows it.
	var exposed := 0
	if x <= 0 or _snapshot[cell - 1] < 0.0:
		exposed += 1
	if x >= _width - 1 or _snapshot[cell + 1] < 0.0:
		exposed += 1
	var above := cell - _width
	if above < 0 or _snapshot[above] < 0.0:
		exposed += 1
	var below := cell + _width
	if below >= _cell_count or _snapshot[below] < 0.0:
		exposed += 1
	var maturity := clampf(_snapshot[cell], 0.0, 1.0)
	return (
		1.0
		+ maturity_penalty * (1.0 - maturity)
		+ boundary_penalty * float(exposed) * 0.25
	)


func get_step_cost(cell: int) -> float:
	## What one cell costs the flood to take, for debug views and tests. Rebuilds the
	## cost field first, so it answers about the board as it is now rather than about
	## whatever the last preview happened to leave behind.
	_prepare()
	territory_field.refresh_ownership_snapshot()
	_snapshot = territory_field.get_ownership_snapshot()
	if cell < 0 or cell >= _cell_count or _snapshot[cell] < 0.0:
		return 0.0
	return _compute_step(cell, cell % _width)


func _push(cell: int, cost: float) -> void:
	var bucket := int(cost / COST_QUANTUM) % _bucket_count
	if _entry_count >= _entry_cell.size():
		_entry_cell.append(cell)
		_entry_cost.append(cost)
		_entry_next.append(_bucket_head[bucket])
	else:
		_entry_cell[_entry_count] = cell
		_entry_cost[_entry_count] = cost
		_entry_next[_entry_count] = _bucket_head[bucket]
	_bucket_head[bucket] = _entry_count
	_entry_count += 1
	_queued += 1


func _pop() -> int:
	# Buckets are only ever advanced, never rewound, which is what makes the ring safe:
	# every cell pushed from here lands at most one widest-step ahead of the bucket being
	# drained, and the ring is sized so that cannot reach round to the current one.
	while _bucket_head[_current_bucket] == -1:
		_current_bucket += 1
		if _current_bucket >= _bucket_count:
			_current_bucket = 0
	var entry := _bucket_head[_current_bucket]
	_bucket_head[_current_bucket] = _entry_next[entry]
	_queued -= 1
	_last_pop_cost = _entry_cost[entry]
	return _entry_cell[entry]
