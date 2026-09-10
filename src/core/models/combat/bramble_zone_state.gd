class_name BrambleZoneState
extends RefCounted

## A patch of ground where thorn contact is worth more than usual, for a while.
##
## A pooled struct with no behaviour, one of the flat arrays `CombatDirector` sweeps.
## Entities in this game are deliberately never nodes: a horde spawns them by the
## hundred, and `docs/performance_optimization_implementation_guide.md` exists to
## protect the layout that makes that affordable.

var active := false
var position := Vector2.ZERO
var radius := 0.0
var remaining := 0.0
var duration := 1.0
var contact_multiplier := 1.0
