class_name AllInGrace
extends Node

## The three seconds after an All In whiff.
##
## Losing everything is not the same as losing the run. The organism is gone, the
## ordinary zero-territory defeat check is held off, and the player has exactly three
## seconds to put something back on the board. Everything else keeps running - enemies,
## Blooms in flight, jackpot timers from earlier spins - which is what makes an
## improbable rescue possible rather than scripted.

## The organism was wiped and the clock has started. The countdown belongs on screen
## from this moment, not from the next frame the HUD happens to poll.
signal grace_started(duration: float)
## Enough ground was reclaimed in time. The run continues, with nothing granted.
signal grace_recovered(seconds_remaining: float)
## The clock ran out below the threshold. The run is over.
signal grace_failed()

@export_group("Collaborators")
@export var territory_field: TerritoryField

@export_group("Timing")
## Seconds to reclaim the board. Short enough to be an emergency, long enough that a
## player who reacts immediately has a real chance.
@export_range(0.5, 10.0, 0.1) var grace_duration := 3.0
## Share of the claimable board that has to be Green again before the clock reaches
## zero. Raw Green, deliberately: demanding Established maturity inside three seconds
## would make the grace period decorative.
@export_range(0.0, 0.5, 0.01) var recovery_threshold := 0.05

var _active := false
var _remaining := 0.0


func reset_grace() -> void:
	_active = false
	_remaining = 0.0


func begin() -> void:
	_active = true
	_remaining = grace_duration
	grace_started.emit(grace_duration)


func is_active() -> bool:
	return _active


func is_suppressing_defeat() -> bool:
	## While this is true the run's ordinary zero-territory countdown must not run. The
	## two clocks would otherwise race, and the visible one would not be the one that
	## decided the outcome.
	return _active


func get_remaining_seconds() -> float:
	return _remaining


func get_recovered_fraction() -> float:
	if territory_field == null:
		return 0.0
	var claimable := territory_field.get_claimable_cell_count()
	if claimable <= 0:
		return 0.0
	return float(territory_field.get_player_cell_count()) / float(claimable)


func advance(delta: float) -> void:
	if not _active:
		return
	# Recovery is checked before the clock is spent, so reaching the threshold on the
	# same frame the timer expires is a rescue rather than a loss. The visible number
	# and the deadline behind it have to agree, and when they disagree by a frame the
	# player should get the frame.
	if get_recovered_fraction() >= recovery_threshold:
		_active = false
		grace_recovered.emit(_remaining)
		return
	_remaining -= delta
	if _remaining > 0.0:
		return
	_remaining = 0.0
	_active = false
	grace_failed.emit()
