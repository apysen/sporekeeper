class_name GrowthCatalog
extends RefCounted

## The small universal stats a survived Provocation pays out in.
##
## Growth is deliberately the least interesting reward in the run. It has no
## mechanics in it, it stacks additively, every rank is capped, and the whole set a
## run can collect is worth less than one Adaptation. That is the design: the player
## is being paid for taking a risk, and a payment large enough to matter would make
## Provocation the only correct way to play, which is exactly the feedback loop the
## Campaign rework exists to avoid.
##
## Earlier Provocations do not pay more. What an early call buys is Surge -- more
## danger, sooner -- and the Growth is the same either way, so "call it as early as
## possible" stays a question about the player's nerve rather than about arithmetic.

enum StatId {
	DAMAGE,
	ATTACK_SPEED,
	MOVEMENT_SPEED,
	AREA,
	MAX_HEALTH,
	ARMOR,
	RECOVERY,
}

## What one rank of each stat is worth. Fractions are proportional; Max Health is
## flat hit points and Recovery is hit points per second.
const PER_RANK := [0.04, 0.04, 0.05, 0.04, 8.0, 0.03, 0.40]

## Ranks each stat may reach. Area and Recovery are the short ones: reach multiplies
## into every sweep, ring and blast the run owns, and passive regeneration is the
## stat most able to quietly cancel the damage a harder Campaign is meant to deal.
const RANK_CAP := [3, 3, 3, 2, 4, 3, 2]

const NAMES := [
	"Vigour",
	"Quickening",
	"Fleetness",
	"Spread",
	"Hardiness",
	"Bark",
	"Convalescence",
]

const DESCRIPTIONS := [
	"+%d%% damage from everything the garden does",
	"+%d%% attack speed",
	"+%d%% movement speed",
	"+%d%% reach and area",
	"+%d maximum health",
	"+%d%% of incoming damage turned aside",
	"+%.1f health regained per second",
]


static func get_count() -> int:
	return StatId.size()


static func get_stat_name(stat_id: int) -> String:
	return NAMES[clampi(stat_id, 0, NAMES.size() - 1)]


static func get_per_rank(stat_id: int) -> float:
	return float(PER_RANK[clampi(stat_id, 0, PER_RANK.size() - 1)])


static func get_rank_cap(stat_id: int) -> int:
	return int(RANK_CAP[clampi(stat_id, 0, RANK_CAP.size() - 1)])


static func get_description(stat_id: int) -> String:
	## One rank's worth, written the way the choice panel prints it.
	var stat := clampi(stat_id, 0, DESCRIPTIONS.size() - 1)
	var template: String = DESCRIPTIONS[stat]
	var amount := get_per_rank(stat)
	if stat == StatId.MAX_HEALTH:
		return template % roundi(amount)
	if stat == StatId.RECOVERY:
		return template % amount
	return template % roundi(amount * 100.0)
