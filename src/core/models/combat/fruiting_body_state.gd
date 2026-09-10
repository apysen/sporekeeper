class_name FruitingBodyState
extends RefCounted

## One fungal colony raised by a germination inside owned Green. Every Fruiting
## Body behaves identically whatever rank raised it: the upgrade line buys how
## often one appears, never what it does once it is standing.
##
## A pooled struct with no behaviour, one of the flat arrays `CombatDirector` sweeps.
## Entities in this game are deliberately never nodes: a horde spawns them by the
## hundred, and `docs/performance_optimization_implementation_guide.md` exists to
## protect the layout that makes that affordable.

var active := false
var position := Vector2.ZERO
## Seconds until the next Spore cloud.
var cloud_remaining := 0.0
## Clouds left before this colony ruptures.
var clouds_remaining := 0
var seed := 0
