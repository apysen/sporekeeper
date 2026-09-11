class_name ThornState
extends RefCounted

## One thorn in flight, and what fired it.
##
## `Source` sits on the thorn rather than beside it because `source_tag` is the only
## thing that reads it: a thorn has to carry its own provenance so a relic-made one
## can hit, kill and ricochet normally without feeding the counter that produced it.

## What fired a thorn. Only NATURAL advances a network counter; every relic-made
## thorn is tagged so it can hit, kill and ricochet normally without ever feeding
## the counters that produced it.
enum Source {
	NATURAL,
	ROSETTE,
	RELAY,
	PINCUSHION,
	SEEDHEAD,
	ANSWERING,
	PHYLLOTAXIS,
	FORKING,
	CROWN,
}

var active := false
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var remaining := 0.0
var damage := 0.0
var ricochets_remaining := 0
var pierce_remaining := 0
## ROOTSTOCK's Heavy Thorn may pass through ordinary enemies, but elites and
## bosses stop the punch-through and hand the packet off to Burr ricochets.
var pierces_normal_only := false
var critical_chance_bonus := 0.0
## Added to the critical multiplier, not to the odds of reaching it. Needlepoint
## is the whole of this; the chance above belongs to the effects that hand a
## single packet better odds.
var critical_damage_bonus := 0.0
var heavy := false
var bloomshot := false
var bloomshot_force := 0.0
var ricochet_depth := 0
var inherit_needlepoint := true
var source_thistle_sequence := -1
var source_tag := 0
var hit_ids := PackedInt32Array()
