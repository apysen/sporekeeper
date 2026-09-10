class_name DamageNumberState
extends RefCounted

## One floating number, from the moment it is spawned to the moment it fades.
##
## A pooled struct with no behaviour, one of the flat arrays `CombatDirector` sweeps.
## Entities in this game are deliberately never nodes: a horde spawns them by the
## hundred, and `docs/performance_optimization_implementation_guide.md` exists to
## protect the layout that makes that affordable.

var active := false
var impact_position := Vector2.ZERO
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var text := ""
var color := Color.WHITE
var age := 0.0
var impact_radius := 8.0
## Size the text renders at, and the measurement of it. Neither changes once the
## number is spawned, so both are worked out there rather than every frame.
var font_size := 16
var text_size := Vector2.ZERO
## Criticals are read differently at every stage of the draw, so the number
## remembers what it was rather than the draw inferring it.
var critical := false
## Per number, because a critical is given longer to be read than chip damage is.
var lifetime := 0.7
