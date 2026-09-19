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
	## The Campaign's second boss. She does not fight for ground herself: she plants
	## Colony Cores and lets them do it, which is the Colonizer contract at boss scale.
	##
	## Appended rather than slotted next to BOSS on purpose. These values are stored -
	## in `enemy_profiles.tscn`, in authored wave tables, in a run's save - so the
	## order is a file format, and inserting into the middle of it would silently
	## rename every role after the insertion point.
	HIVE_QUEEN,
}


## Whether this role is one of the run's boss actors.
##
## Asked in about a dozen places - overkill caps, the shares that stop a pulse
## trivialising a boss, whether a spawn may be redirected, whether a damage number is
## worth showing - and every one of them means "a boss", not "the Burrower". Before
## the Hive Queen there was only one boss, so those sites compared against `BOSS`
## directly and were right by accident. A predicate is what keeps the second boss from
## having to be remembered in twelve separate places.
static func is_boss(role: int) -> bool:
	return role == Role.BOSS or role == Role.HIVE_QUEEN

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
