class_name PendingEruptionState
extends RefCounted

## An eruption that has been decided but not yet arrived.
##
## A pooled struct with no behaviour, one of the flat arrays `CombatDirector` sweeps.
## Entities in this game are deliberately never nodes: a horde spawns them by the
## hundred, and `docs/performance_optimization_implementation_guide.md` exists to
## protect the layout that makes that affordable.

var active := false
var position := Vector2.ZERO
var delay_remaining := 0.0
var chain_depth := 0
