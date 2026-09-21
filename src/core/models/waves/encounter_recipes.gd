class_name EncounterRecipes
extends RefCounted

## What a Campaign wave is allowed to buy, and what each purchase costs.
##
## The Campaign's late difficulty used to be a shorter pack interval and a larger
## pack: the same enemies, more of them. That is the one escalation Sporekeeper
## cannot use, because density is an *input* to a mature build -- more bodies make a
## Vine sweep, a Burr ricochet and a Pruning ring more efficient, not less. A wave
## that wants to threaten a finished organism has to spend its pressure on enemies
## that are individually harder to answer.
##
## So a wave is a budget rather than a cadence. Every role has a Threat Cost, every
## legal encounter is a named recipe with a fixed membership, and a wave names the
## recipes it may buy. Raising a late wave's budget buys Siege Corruptors and elite
## spearheads because the cheap recipes are no longer in its list -- the composition
## shift is a property of the table rather than of a tuning constant somebody has to
## remember to move alongside the density.
##
## The recipes are also what keeps the Director authored. A budget spent freely on
## whatever fits would produce eleven Wardens the moment Wardens became affordable;
## a recipe is a pack somebody designed, and the budget only decides how many of
## them and which.

const ROLE_HUNTER := EnemyKinds.Role.HUNTER
const ROLE_GRAZER := EnemyKinds.Role.GRAZER
const ROLE_ELITE := EnemyKinds.Role.ELITE
const ROLE_SABOTEUR := EnemyKinds.Role.SABOTEUR
const ROLE_CORRUPTOR := EnemyKinds.Role.CORRUPTOR
const ROLE_COLONIZER := EnemyKinds.Role.COLONIZER
const ROLE_WARDEN := EnemyKinds.Role.WARDEN
const ROLE_HEAVY_GRAZER := EnemyKinds.Role.HEAVY_GRAZER
const ROLE_RUSHER := EnemyKinds.Role.RUSHER
const ROLE_SIEGE_CORRUPTOR := EnemyKinds.Role.SIEGE_CORRUPTOR

## What one body of each role costs the Director.
##
## Ordered by how much of the player's attention the role demands rather than by its
## health. A Rusher is cheap to kill and expensive to ignore; a Heavy Grazer is the
## reverse. Both are priced on the problem they set, because the budget is a measure
## of pressure and not of hit points.
const THREAT_COSTS := {
	ROLE_HUNTER: 10,
	ROLE_RUSHER: 15,
	ROLE_GRAZER: 18,
	ROLE_SABOTEUR: 20,
	ROLE_CORRUPTOR: 26,
	ROLE_COLONIZER: 30,
	ROLE_WARDEN: 30,
	ROLE_HEAVY_GRAZER: 35,
	ROLE_SIEGE_CORRUPTOR: 45,
	ROLE_ELITE: 55,
}

## Milestone actors are not bought. The Elite Rootbreaker, the Burrower and the Hive
## Queen arrive because the Campaign says so, and charging a wave's budget for one
## would make an authored fight quietly cancel the wave around it.
const MILESTONE_COST := 0

## Recipe identifiers, so a wave row names a pack rather than describing one.
const PROBE := &"PROBE"
const PAIR_PUSH := &"PAIR_PUSH"
const GRAZE_LINE := &"GRAZE_LINE"
const RUSH_ASSAULT := &"RUSH_ASSAULT"
const SABOTAGE_RUN := &"SABOTAGE_RUN"
const CORRUPTION_CELL := &"CORRUPTION_CELL"
const HEAVY_FRONT := &"HEAVY_FRONT"
const COLONY_PUSH := &"COLONY_PUSH"
const SPLIT_PRESSURE := &"SPLIT_PRESSURE"
const WARDEN_GUARD := &"WARDEN_GUARD"
const SIEGE_PUSH := &"SIEGE_PUSH"
const ELITE_SPEARHEAD := &"ELITE_SPEARHEAD"
const CANKER_REINFORCEMENT := &"CANKER_REINFORCEMENT"

## Every recipe, as the membership the Director actually spawns.
##
## `members` is spawned in order from one perimeter sector, so the first entry is the
## pack's leader in everything but name -- it chooses the sector and the rest follow
## it in. `split` sends the tail of the pack to the opposite sector instead, which is
## the whole content of a recipe that exists to punish a build that only defends one
## side. `interior` asks the Canker director for an entrance instead of the perimeter
## and is refused, harmlessly, when the run holds no Knot.
##
## `act` is the earliest Campaign act the recipe may be bought in. This is the enemy
## pool gate: a wave cannot buy a Siege Push in Act I however large its budget grows,
## so an early wave that is going badly still produces early-wave problems.
const RECIPES := {
	PROBE: {
		"members": [ROLE_HUNTER],
		"topology": &"EVEN_RING", "act": 1,
	},
	PAIR_PUSH: {
		"members": [ROLE_HUNTER, ROLE_HUNTER],
		"topology": &"EVEN_RING", "act": 1,
	},
	GRAZE_LINE: {
		"members": [ROLE_GRAZER, ROLE_GRAZER],
		"topology": &"CLUSTERED_FRONT", "act": 1,
	},
	RUSH_ASSAULT: {
		"members": [ROLE_RUSHER, ROLE_HUNTER, ROLE_HUNTER],
		"topology": &"WEAK_SIDE_RUSH", "act": 2,
	},
	SABOTAGE_RUN: {
		"members": [ROLE_SABOTEUR, ROLE_HUNTER],
		"topology": &"SPECIALIST_OPPOSITE_PACK", "act": 1,
	},
	CORRUPTION_CELL: {
		"members": [ROLE_CORRUPTOR, ROLE_GRAZER],
		"topology": &"SPECIALIST_OPPOSITE_PACK", "act": 2,
	},
	HEAVY_FRONT: {
		"members": [ROLE_HEAVY_GRAZER, ROLE_GRAZER, ROLE_HUNTER],
		"topology": &"CLUSTERED_FRONT", "act": 2,
	},
	COLONY_PUSH: {
		"members": [ROLE_COLONIZER, ROLE_HUNTER, ROLE_GRAZER],
		"topology": &"COLONIZER_DISTRACTION", "act": 2,
	},
	SPLIT_PRESSURE: {
		"members": [ROLE_RUSHER, ROLE_HUNTER, ROLE_GRAZER, ROLE_HUNTER],
		"topology": &"TWO_SIDE_PINCER", "act": 3, "split": true,
	},
	WARDEN_GUARD: {
		"members": [ROLE_WARDEN, ROLE_HEAVY_GRAZER],
		"topology": &"SPECIALIST_OPPOSITE_PACK", "act": 3,
	},
	SIEGE_PUSH: {
		"members": [ROLE_SIEGE_CORRUPTOR, ROLE_HEAVY_GRAZER, ROLE_HUNTER],
		"topology": &"TWO_SIDE_PINCER", "act": 3,
	},
	ELITE_SPEARHEAD: {
		"members": [ROLE_ELITE, ROLE_HUNTER, ROLE_HUNTER],
		"topology": &"THREE_FRONT_PRESSURE", "act": 4,
	},
	CANKER_REINFORCEMENT: {
		"members": [ROLE_CORRUPTOR, ROLE_HUNTER, ROLE_HUNTER],
		"topology": &"EVEN_RING", "act": 2, "interior": true,
	},
}


static func get_role_cost(role: int) -> int:
	return int(THREAT_COSTS.get(role, MILESTONE_COST))


static func has_recipe(recipe_id: StringName) -> bool:
	return RECIPES.has(recipe_id)


static func get_members(recipe_id: StringName) -> PackedInt32Array:
	var members := PackedInt32Array()
	if not RECIPES.has(recipe_id):
		return members
	for role in RECIPES[recipe_id]["members"]:
		members.append(int(role))
	return members


static func get_cost(recipe_id: StringName) -> int:
	## Summed rather than authored, so a recipe cannot be given a fifth member and
	## keep a four-member price.
	var cost := 0
	for role in get_members(recipe_id):
		cost += get_role_cost(role)
	return cost


static func get_topology(recipe_id: StringName) -> StringName:
	if not RECIPES.has(recipe_id):
		return &"EVEN_RING"
	return RECIPES[recipe_id].get("topology", &"EVEN_RING")


static func get_minimum_act(recipe_id: StringName) -> int:
	if not RECIPES.has(recipe_id):
		return 1
	return int(RECIPES[recipe_id].get("act", 1))


static func is_split(recipe_id: StringName) -> bool:
	## Whether the pack's second half enters from the opposite side of the arena.
	if not RECIPES.has(recipe_id):
		return false
	return bool(RECIPES[recipe_id].get("split", false))


static func is_interior(recipe_id: StringName) -> bool:
	## Whether this recipe wants to come out of a Canker rather than the perimeter.
	if not RECIPES.has(recipe_id):
		return false
	return bool(RECIPES[recipe_id].get("interior", false))


static func get_cheapest_cost(recipe_ids: Array) -> int:
	## What the Director must be able to afford before a wave can buy anything at
	## all. Read by the scheduler to decide whether accumulated credit is spendable
	## or whether it should keep growing.
	var cheapest := -1
	for recipe_id in recipe_ids:
		var cost := get_cost(recipe_id)
		if cheapest < 0 or cost < cheapest:
			cheapest = cost
	return maxi(1, cheapest)
