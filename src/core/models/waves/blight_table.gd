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

## Where the authored table stops naming levels. Blight itself does not stop here:
## Provocation is unlimited, so a run that keeps daring the garden keeps raising it,
## and every multiplier below carries on climbing at the same rate.
##
## It used to be a ceiling, and the ceiling was doing two jobs badly. It capped the
## difficulty a player could choose, which is the opposite of what Provocation is for;
## and because the Growth debt was appended inside the same check, a capped run paid the
## surge, skipped the wave and was owed *nothing*, so the presses past it were pure cost.
const NAMED_LEVELS := 5

## Linear, deliberately, and unbounded.
##
## An accelerating curve would create a natural stopping point, which is the right shape
## for a resource and the wrong one for a dial: what a player is deciding here is *how
## fast*, not *when to stop*, and that decision needs to be arithmetic they can do in
## advance. Eleven presses is +88% budget, and it should be possible to know that before
## pressing anything.
##
## Nothing here is what stops a reckless run -- the surge is, and it is proportional to
## the seconds skipped rather than to the press count, so it arrives immediately and in
## front of the player rather than as a number in a table.
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
## player has to be able to say out loud what they are at. Level 0 is the one the
## numerals have no glyph for, so it is authored; everything above is built.
const ZERO_NAME := "0"
## Value and glyph, descending, including the four subtractive pairs. A Blight is
## unbounded now, so the numeral has to be composed rather than looked up: a run that
## keeps daring the garden can pass any table somebody thought to write out.
const NUMERALS := [
	[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"],
	[100, "C"], [90, "XC"], [50, "L"], [40, "XL"],
	[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"],
]


static func clamp_level(level: int) -> int:
	## Only the floor. There is no ceiling on Blight any more, and every multiplier
	## below reads through here, so this is the one place that would silently reinstate
	## one.
	return maxi(level, 0)


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
	## The numeral for any level, composed rather than looked up.
	var remaining := clamp_level(level)
	if remaining <= 0:
		return ZERO_NAME
	var name := ""
	for pair in NUMERALS:
		var value: int = pair[0]
		while remaining >= value:
			name += String(pair[1])
			remaining -= value
	return name
