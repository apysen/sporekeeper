class_name BriarTrapState
extends RefCounted

## One armed trap: what it does when something walks into it, and how long it waits.
##
## A pooled struct with no behaviour, one of the flat arrays `CombatDirector` sweeps.
## Entities in this game are deliberately never nodes: a horde spawns them by the
## hundred, and `docs/performance_optimization_implementation_guide.md` exists to
## protect the layout that makes that affordable.

var active := false
## A Briar Heart detonates repeatedly instead of once, at a larger reach.
var detonations_remaining := 1
var is_briar_heart := false
var position := Vector2.ZERO
var radius := 0.0
var trigger_radius := 0.0
var chain_radius := 0.0
var remaining := 0.0
var duration := 1.0
var damage := 0.0
var entanglement_gain := 0.0
## Seconds left on a lit fuse; zero while the trap is simply waiting for prey.
var fuse_remaining := 0.0
var chain_depth := 0
var seed := 0
