class_name PhaseBCloverJackpots
extends Node

## How long each Path stays lit after the Clover machine pays it out.
##
## A jackpot lends the run a Path at its ceiling: every one of that Path's four lines
## behaves as though it were maxed, whether or not the run owns the Path at all. The
## loan is written into Progression, which is where every director already reads its
## levels from, so a jackpot fires the real mechanic rather than a casino-only imitation
## of it. Nothing is added to the build and ownership is never granted.
##
## Repeat jackpots stack by duration and never by strength. Level 5 is the top of the
## Path and a second win cannot go above it, so a second Root jackpot buys another
## fifteen seconds of maxed Root rather than a Root nobody has numbers for.

## A Path lit up, for this long in total. Fired on every win, including one that only
## extended a timer already running.
signal jackpot_started(path_id: int, total_seconds: float)
## A Path's loan expired and its levels dropped back to what the run actually owns.
signal jackpot_ended(path_id: int)

@export_group("Collaborators")
## Where the borrowed levels are written. Directors read them back from here without
## knowing the casino exists.
@export var progression: PhaseBProgression

@export_group("Durations")
## Seconds of maxed Root per win. The longest of the three because Root is the slowest
## to show its effect on the ground.
@export_range(1.0, 60.0, 0.5) var root_seconds := 15.0
## Seconds of maxed Bramble per win.
@export_range(1.0, 60.0, 0.5) var bramble_seconds := 10.0
## Seconds of maxed Pruning per win.
@export_range(1.0, 60.0, 0.5) var pruning_seconds := 10.0
## Thistle, Vine, and Fruit are active battlefield systems rather than one-shot
## board events. Ten seconds gives each enough time to express at least one full
## cadence while their four standard lines are held at rank 5.
@export_range(1.0, 60.0, 0.5) var adaptation_seconds := 10.0
## How long Spore and Bloom stay lit. Both resolve as one discrete board-wide event
## rather than as a duration, but the material they throw is still in the air a moment
## later and has to land at the strength it was launched with.
@export_range(0.5, 20.0, 0.5) var discrete_seconds := 3.0

var _remaining := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])


func reset_jackpots() -> void:
	for path_id in range(_remaining.size()):
		_remaining[path_id] = 0.0
	if progression != null:
		progression.clear_casino_paths()


func get_path_seconds(path_id: int) -> float:
	match path_id:
		PhaseBProgression.PathId.ROOT:
			return root_seconds
		PhaseBProgression.PathId.BRAMBLE:
			return bramble_seconds
		PhaseBProgression.PathId.PRUNING:
			return pruning_seconds
		PhaseBProgression.PathId.THISTLE, PhaseBProgression.PathId.VINE, PhaseBProgression.PathId.FRUIT:
			return adaptation_seconds
		_:
			return discrete_seconds


func light(path_id: int) -> float:
	## Adds this Path's duration to whatever is already running and returns the new
	## total. There is no cap: a player who keeps hitting Root jackpots has earned the
	## minutes, and capping it would quietly delete a reward the reels already promised.
	if path_id < 0 or path_id >= _remaining.size():
		return 0.0
	var was_active := _remaining[path_id] > 0.0
	_remaining[path_id] += get_path_seconds(path_id)
	if not was_active and progression != null:
		progression.set_casino_path_active(path_id, true)
	jackpot_started.emit(path_id, _remaining[path_id])
	return _remaining[path_id]


func is_active(path_id: int) -> bool:
	if path_id < 0 or path_id >= _remaining.size():
		return false
	return _remaining[path_id] > 0.0


func get_remaining_seconds(path_id: int) -> float:
	if path_id < 0 or path_id >= _remaining.size():
		return 0.0
	return _remaining[path_id]


func get_active_count() -> int:
	var count := 0
	for seconds in _remaining:
		if seconds > 0.0:
			count += 1
	return count


func advance(delta: float) -> void:
	for path_id in range(_remaining.size()):
		if _remaining[path_id] <= 0.0:
			continue
		_remaining[path_id] -= delta
		if _remaining[path_id] > 0.0:
			continue
		_remaining[path_id] = 0.0
		if progression != null:
			progression.set_casino_path_active(path_id, false)
		jackpot_ended.emit(path_id)
