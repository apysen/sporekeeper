class_name RankCosts
extends RefCounted

## The geometric ladder every Metabolism axis climbs: 20, 35, 61, 107, 188, 328, 574.
##
## The shop that charged those prices is gone and the climb is automatic now, but the
## curve is the same one, so a run lands where buying in the best order would have put
## it. Four questions are asked of it - what a rank costs, what standing at one has
## cost in total, what rank a pile of earnings has paid for, and how far along the
## current one is - and all four are arithmetic over two authored numbers.
##
## Inverting the sum is what makes this a rule rather than a loop: the rank an amount
## has paid for is solved directly rather than by walking the ladder until the total
## exceeds it, which is the kind of loop that quietly becomes a per-frame cost once
## something draws a meter from it.


## What this rank cost on its own. Rank one is where everything starts and is free.
static func rank_cost(base: float, growth: float, level: int) -> float:
	if level <= 1:
		return 0.0
	return base * pow(growth, float(level - 2))


## Everything that had to be earned to stand at this rank.
static func cumulative_cost(base: float, growth: float, level: int) -> float:
	if level <= 1:
		return 0.0
	return base * (pow(growth, float(level - 1)) - 1.0) / (growth - 1.0)


## The highest rank an amount of lifetime earnings has paid for, clamped to the
## ladder's top. The closed form of "how many terms of this geometric series fit".
static func level_for(base: float, growth: float, earned: float, maximum_level: int) -> int:
	if earned <= 0.0 or base <= 0.0 or growth <= 1.0:
		return 1
	var ranks: float = floor(log(1.0 + earned * (growth - 1.0) / base) / log(growth))
	return clampi(1 + int(ranks), 1, maximum_level)


## How far this axis has come toward its next rank, 0 to 1. One at the top of the
## ladder, because a meter that never fills reads as a system that is still waiting.
static func progress_toward_next(
	base: float, growth: float, earned: float, level: int, maximum_level: int
) -> float:
	if level >= maximum_level:
		return 1.0
	var floor_cost := cumulative_cost(base, growth, level)
	var next_cost := cumulative_cost(base, growth, level + 1)
	if next_cost <= floor_cost:
		return 0.0
	return clampf((earned - floor_cost) / (next_cost - floor_cost), 0.0, 1.0)
