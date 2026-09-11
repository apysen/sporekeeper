class_name Rampart
extends RefCounted

## Living Rampart: one standing circle that makes the ground inside it answer harder.
##
## It is not a [RateZones] patch, even though its Entanglement bonus is read beside
## them. A patch is timed and expires; a Rampart stands until the relic takes it
## down, so re-adding it every frame to keep it alive would be a clock it does not
## have. It also carries a second effect a patch has no room for - a multiplier on
## how soon the Green may shove again - which is why it is its own small rule rather
## than a permanent entry in the other one.

var _center := Vector2(-1.0, -1.0)
var _radius := 0.0
var _entanglement_rate_bonus := 0.0
var _repulsion_multiplier := 1.0


func raise_region(
	center: Vector2,
	radius: float,
	entanglement_rate_bonus: float,
	repulsion_multiplier: float
) -> void:
	_center = center
	_radius = maxf(0.0, radius)
	_entanglement_rate_bonus = maxf(0.0, entanglement_rate_bonus)
	_repulsion_multiplier = clampf(repulsion_multiplier, 0.05, 1.0)


func clear() -> void:
	_center = Vector2(-1.0, -1.0)
	_radius = 0.0
	_entanglement_rate_bonus = 0.0
	_repulsion_multiplier = 1.0


func contains(local_position: Vector2) -> bool:
	return (
		_radius > 0.0
		and _center.x >= 0.0
		and local_position.distance_to(_center) <= _radius
	)


func get_entanglement_rate_bonus() -> float:
	return _entanglement_rate_bonus


func get_repulsion_multiplier() -> float:
	return _repulsion_multiplier
