class_name PickupState
extends RefCounted

## One dropped XP mote waiting to be walked over.
##
## A pooled struct with no behaviour, one of the flat arrays `CombatDirector` sweeps.
## Entities in this game are deliberately never nodes: a horde spawns them by the
## hundred, and `docs/performance_optimization_implementation_guide.md` exists to
## protect the layout that makes that affordable.

var active := false
var position := Vector2.ZERO
var xp_value := 1
var age := 0.0
