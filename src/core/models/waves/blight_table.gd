class_name BlightTable
extends RefCounted

## What the garden becomes when Grandma keeps daring it to escalate.
##
## Blight is the permanent half of Provocation. Every rewarded Provocation raises it
## by one and it never comes back down, so a run that hurried is a run that is
## fighting a worse ecosystem for the rest of its length -- including in the finale,
## which inherits whatever the run built up on the way there.
##
## Nearly all of it is Director budget. Health and contact damage move too, but
## deliberately by a fraction of the budget's movement: the difficulty a player chose
## should arrive as harder encounters, not as the same encounter with a longer
## time-to-kill. At Blight V the Director is spending forty per cent more on packs it
## can now afford the expensive versions of, while an individual Hunter has twenty
## per cent more health than it did at Blight 0.
##
## The composition column is the specialist discount below. A Blight level does not
## unlock a recipe -- act gating owns that, and a player cannot Provoke their way
## into Act IV enemies during Act I -- it makes the expensive recipes cheaper
## relative to the budget, so the Director buys more of them out of the same list.

## Highest Blight a rewarded Provocation can reach. Beyond it Provocation still
## works and still overlaps waves; it simply stops making the run permanently worse.
const MAXIMUM_LEVEL := 5

const BUDGET_PER_LEVEL := 0.08
const HEALTH_PER_LEVEL := 0.04
const DAMAGE_PER_LEVEL := 0.02
## How much of a specialist or elite recipe's price each level forgives. Small: it is
## the thumb on the scale that shifts what a wave buys, not a second budget curve.
const SPECIALIST_DISCOUNT_PER_LEVEL := 0.04
## Floor on that discount, so Blight V cannot make an Elite Spearhead cost less than
## two thirds of what it is worth.
const MINIMUM_SPECIALIST_PRICE := 0.66

## Roman numerals, because the HUD prints the level rather than a percentage and a
## player has to be able to say out loud what they are at.
const LEVEL_NAMES := ["0", "I", "II", "III", "IV", "V"]


static func clamp_level(level: int) -> int:
	return clampi(level, 0, MAXIMUM_LEVEL)


static func get_budget_multiplier(level: int) -> float:
	return 1.0 + float(clamp_level(level)) * BUDGET_PER_LEVEL


static func get_health_multiplier(level: int) -> float:
	return 1.0 + float(clamp_level(level)) * HEALTH_PER_LEVEL


static func get_damage_multiplier(level: int) -> float:
	return 1.0 + float(clamp_level(level)) * DAMAGE_PER_LEVEL


static func get_specialist_price_multiplier(level: int) -> float:
	## Applied to a recipe's cost when the Director prices it, never to the recipe
	## table itself: two runs at different Blight read the same authored numbers and
	## only the purchase differs.
	return maxf(
		MINIMUM_SPECIALIST_PRICE,
		1.0 - float(clamp_level(level)) * SPECIALIST_DISCOUNT_PER_LEVEL
	)


static func get_level_name(level: int) -> String:
	return LEVEL_NAMES[clamp_level(level)]
