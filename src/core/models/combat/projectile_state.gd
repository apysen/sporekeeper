class_name ProjectileState
extends RefCounted

## One shot in flight. Pooled like everything else the director sweeps.
##
## A pooled struct with no behaviour, one of the flat arrays `CombatDirector` sweeps.
## Entities in this game are deliberately never nodes: a horde spawns them by the
## hundred, and `docs/performance_optimization_implementation_guide.md` exists to
## protect the layout that makes that affordable.

var active := false
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var damage := 0.0
var remaining := 0.0
var remaining_distance := 0.0
var pierce_remaining := 1
var last_hit_enemy_id := -1
