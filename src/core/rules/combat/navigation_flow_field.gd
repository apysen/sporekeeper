class_name NavigationFlowField
extends RefCounted

## How far every walkable cell of the arena is from one target, in cells.
##
## Enemies do not path individually. One breadth-first sweep per target fills a
## distance field, and an enemy then only ever reads the cell it is standing in and
## its four neighbours - which is what keeps a horde affordable and why this is a
## grid of integers rather than a route per body.
##
## It knows nothing about enemies or about the field the grid was derived from. The
## caller hands down a walkable mask and an array to fill, so the same sweep serves
## the small-clearance grid, the boss grid and the Saboteur's catalyst target.

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]

var _width := 0
var _height := 0
## Scratch for the sweep, sized once. A queue allocated per rebuild would be the
## most expensive part of a sweep that is otherwise integer arithmetic.
var _queue := PackedInt32Array()


## Grid dimensions, and the scratch queue that has to hold every cell at once.
func resize(width: int, height: int) -> void:
	_width = width
	_height = height
	_queue.resize(width * height)


func rebuild(
	distances: PackedInt32Array,
	walkable: PackedByteArray,
	target_index: int
) -> void:
	distances.fill(-1)
	var start_index := find_nearest_walkable(target_index, walkable)
	if start_index == -1:
		return
	var head := 0
	var tail := 1
	_queue[0] = start_index
	distances[start_index] = 0
	while head < tail:
		var current_index := _queue[head]
		head += 1
		var current_x := current_index % _width
		var current_y := current_index / _width
		var next_distance := distances[current_index] + 1
		for direction in DIRECTIONS:
			var next_x := current_x + direction.x
			var next_y := current_y + direction.y
			if (
				next_x < 0
				or next_y < 0
				or next_x >= _width
				or next_y >= _height
			):
				continue
			var next_index := next_y * _width + next_x
			if walkable[next_index] == 0 or distances[next_index] != -1:
				continue
			distances[next_index] = next_distance
			_queue[tail] = next_index
			tail += 1


func find_nearest_walkable(target_index: int, walkable: PackedByteArray) -> int:
	if walkable[target_index] != 0:
		return target_index
	var target_x := target_index % _width
	var target_y := target_index / _width
	for radius in range(1, 13):
		for offset_y in range(-radius, radius + 1):
			for offset_x in range(-radius, radius + 1):
				if absi(offset_x) != radius and absi(offset_y) != radius:
					continue
				var x := target_x + offset_x
				var y := target_y + offset_y
				if x < 0 or y < 0 or x >= _width or y >= _height:
					continue
				var index := y * _width + x
				if walkable[index] != 0:
					return index
	return -1
