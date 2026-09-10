class_name EnemyKinds
extends RefCounted

## The vocabulary every enemy is described in: what role it plays, what rule it
## changes if it is an elite, and what it is currently doing.
##
## This is authored-data vocabulary, not one node's private enum. A Campaign wave
## spec names roles, an `EnemyRoleScalingProfile` is keyed by one, and a relic reads
## them - none of which should have to reach into `CombatDirector` to say "Grazer".
## It lives here so `data/` and `src/core/models/` can name an enemy without
## depending on the node that happens to simulate it.

enum Role {
	HUNTER,
	GRAZER,
	ELITE,
	BOSS,
	SABOTEUR,
	CORRUPTOR,
	COLONIZER,
	WARDEN,
	COLONY_CORE,
	HEAVY_GRAZER,
	RUSHER,
	SIEGE_CORRUPTOR,
}

## Rule changes an elite can carry. The design note is explicit that a late elite
## should increasingly change the rules rather than only its stat line, so each of
## these makes the fight different rather than longer. One per elite, never stacked:
## two rule changes on one body is a fight the player cannot read.
enum EliteModifier {
	NONE,
	## Cannot be Ensnared or shoved. Still fully vulnerable to being slowed, which is
	## what keeps it a rule change rather than an immunity to Bramble.
	UNSTOPPABLE,
	## Leaves Hostile territory in its wake, so its path through the organism has to
	## be fought back through afterwards.
	BLIGHTED,
	## Its territory work accelerates for as long as it is left alone.
	RAVENOUS,
	## Heals unless the player has damaged it recently. Anything else the run does -
	## thorns, Blooms, the ring - is deliberately not enough on its own.
	REGENERATIVE,
	## Suppresses the maturity of the Green around it, weakening everything the run's
	## territory effects are read from while it is standing there.
	DISRUPTIVE,
	## Detonates on death, damaging nearby enemies and the Green it dies on.
	VOLATILE,
}

enum StateKind {
	INACTIVE,
	ADVANCING,
	CONTACT,
}
