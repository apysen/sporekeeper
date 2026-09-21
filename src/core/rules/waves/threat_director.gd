class_name ThreatDirector
extends RefCounted

## How a Campaign wave spends itself.
##
## A wave is a threat budget and a list of recipes it may buy. This releases that
## budget over the wave on an authored rhythm, decides which recipe is next, and
## hands the purchase back when the released credit covers its price. Nothing here
## touches the arena: what a purchase becomes is the director's problem, and keeping
## the spending rules free of the scene is what lets a probe replay a whole wave's
## composition without a field under it.
##
## Recipe first, then price. The alternative -- buy whatever the credit currently
## affords -- sounds equivalent and is not: the cheap recipes are always affordable,
## so credit never accumulates and the wave buys nothing but Probes however large its
## budget grows. Choosing the pack and then saving for it is what makes a big budget
## read as bigger encounters rather than as more of the same one.

## The internal shape of a wave: establish, build, peak, recover.
##
## Each row is the fraction of the wave the phase ends at and the relative rate it
## releases credit at. The cumulative curve below is normalised, so a wave always
## releases exactly its budget however these are edited -- moving a phase changes
## *when* the pressure lands, never how much of it there is.
##
## The recovery tail at the end is the resource Provocation spends. A wave with no
## quiet is a wave with nothing to give up by calling the next one early.
const PHASES := [
	[0.17, 0.55],
	[0.58, 1.05],
	[0.83, 1.85],
	[1.00, 0.25],
]

## The finale's rhythm. One wave in the Campaign is allowed to have no recovery in
## it, and it is the one the run ends on: a last wave that went quiet for its final
## ten seconds would hand the player the victory rather than make them take it.
## How hard Blight tilts the recipe draw toward the expensive end, per level.
##
## Zero at Blight 0, so an unprovoked run draws exactly as it always did. At Blight V
## the exponent reaches 1.1, which makes a recipe's chance of being drawn slightly
## more than proportional to its price -- an Elite Spearhead at 75 against a Probe at
## 10 goes from equally likely to roughly nine times as likely.
##
## The budget still rises with Blight, so a Blighted wave is both larger and heavier.
## What this stops is it being *only* larger.
const BLIGHT_QUALITY_BIAS_PER_LEVEL := 0.22

const FINALE_PHASES := [
	[0.15, 0.80],
	[0.60, 1.15],
	[1.00, 1.35],
]

var _wave_number := 0
var _act := 1
var _budget := 0.0
var _recipe_ids: Array = []
var _duration := 60.0
var _opening_break := 0.0
var _blight_level := 0
## Whether this wave uses the finale's rhythm instead of the ordinary one.
var _sustained := false
## Credit released and not yet spent, and how much of the budget has been released
## at all. The second is what tells the run whether this wave's threat has mostly
## already arrived, which is half of whether Provocation is available.
var _credit := 0.0
var _released := 0.0
var _spent := 0.0
var _elapsed := 0.0
## The pack the Director is currently saving for, and the one before it, so a wave
## does not send the same recipe four times running because the draw allowed it.
var _pending_recipe: StringName = &""
var _previous_recipe: StringName = &""
var _random := RandomNumberGenerator.new()


func begin_wave(
	wave_number: int,
	act: int,
	budget: float,
	recipe_ids: Array,
	duration: float,
	opening_break: float,
	blight_level: int,
	sustained: bool,
	run_seed: int
) -> void:
	## Everything a wave needs to spend itself, applied at its boundary.
	##
	## Carried credit is deliberately dropped rather than banked: a wave the player
	## survived without the Director managing to place its last few packs must not
	## hand that pressure to the next wave as a wall.
	_wave_number = wave_number
	_act = act
	_budget = maxf(0.0, budget)
	_recipe_ids = recipe_ids.duplicate()
	_duration = maxf(1.0, duration)
	_opening_break = clampf(opening_break, 0.0, _duration - 1.0)
	_blight_level = BlightTable.clamp_level(blight_level)
	_sustained = sustained
	_credit = 0.0
	_released = 0.0
	_spent = 0.0
	_elapsed = 0.0
	_pending_recipe = &""
	_previous_recipe = &""
	_random.seed = run_seed + wave_number * 15485863


func add_surge_credit(amount: float) -> void:
	## A Provocation's immediate consequence. Injected as credit rather than as extra
	## budget, so it arrives at the front of the wave and is gone -- the permanent
	## half of calling a wave early is Blight, and mixing the two would make one
	## early call worth two.
	if amount <= 0.0:
		return
	_credit += amount
	_released += amount


func advance(delta: float) -> void:
	## Releases the wave's next slice of credit. Nothing is spent here; the caller
	## drains purchases separately, because how many packs one frame may place is a
	## property of the scene rather than of the budget.
	if delta <= 0.0 or _budget <= 0.0:
		return
	var previous := _spend_fraction_at(_elapsed)
	_elapsed = minf(_duration, _elapsed + delta)
	var released := _budget * (_spend_fraction_at(_elapsed) - previous)
	if released <= 0.0:
		return
	_credit += released
	_released += released


func next_purchase(canker_available: bool) -> StringName:
	## The next pack to place, or an empty name when the Director is still saving.
	##
	## `canker_available` gates the interior recipes. A wave that names Canker
	## Reinforcement while the run holds no Knot simply buys something else from its
	## list -- the Director never creates the Canker it would enter through, which is
	## the line that keeps territory failure the only thing that makes one.
	if _recipe_ids.is_empty():
		return &""
	if _pending_recipe == &"":
		_pending_recipe = _select_recipe(canker_available)
		if _pending_recipe == &"":
			return &""
	var price := get_price(_pending_recipe)
	if _credit < price:
		return &""
	_credit -= price
	_spent += price
	_previous_recipe = _pending_recipe
	var bought := _pending_recipe
	_pending_recipe = &""
	return bought


func get_price(recipe_id: StringName) -> float:
	## What this run pays for a recipe now. The authored cost, less the Blight
	## discount on anything that is not a plain pressure pack -- which is how a
	## Blight V run ends up meeting the expensive compositions more often out of the
	## same wave list rather than out of a second table.
	var cost := float(EncounterRecipes.get_cost(recipe_id))
	if EncounterRecipes.get_minimum_act(recipe_id) <= 1:
		return cost
	return cost * BlightTable.get_specialist_price_multiplier(_blight_level)


func get_budget() -> float:
	return _budget


func get_spent() -> float:
	return _spent


func get_released_fraction() -> float:
	## How much of the wave's pressure has been let out. One of the two conditions
	## that make a wave provokable: a player who has cleared a wave that has already
	## committed most of itself has genuinely finished it early.
	if _budget <= 0.0:
		return 1.0
	return clampf(_released / _budget, 0.0, 1.0)


func get_pending_recipe() -> StringName:
	return _pending_recipe


func _select_recipe(canker_available: bool) -> StringName:
	var eligible: Array = []
	for recipe_id in _recipe_ids:
		if not EncounterRecipes.has_recipe(recipe_id):
			continue
		if EncounterRecipes.get_minimum_act(recipe_id) > _act:
			continue
		if EncounterRecipes.is_interior(recipe_id) and not canker_available:
			continue
		eligible.append(recipe_id)
	if eligible.is_empty():
		return &""
	# Uniform at Blight 0, except that the pack just sent is half as likely to come
	# again: the wave's identity is its recipe list, and weighting inside that list
	# would otherwise be a second, invisible composition table on top of the authored
	# one.
	#
	# Blight is what tilts it, and this is the whole of Blight's composition lever.
	#
	# It has to live here rather than in the price. Discounting an expensive recipe
	# only lets the Director *afford* it sooner, and the Director then buys more packs
	# with the change -- so a price-only Blight is a second budget knob, and budget is
	# density. Measured, Blight V put 66% more bodies on the board and cost a mature
	# build five to ten points of ground at the very end: exactly the escalation this
	# whole rework exists to stop using. Tilting the *draw* is what makes high Blight
	# arrive as Siege Pushes and Elite Spearheads rather than as more Probes.
	var cheapest := float(EncounterRecipes.get_cheapest_cost(eligible))
	var bias := BLIGHT_QUALITY_BIAS_PER_LEVEL * float(_blight_level)
	var weights := PackedFloat32Array()
	var total := 0.0
	for recipe_id in eligible:
		var weight := 0.5 if recipe_id == _previous_recipe else 1.0
		if bias > 0.0:
			weight *= pow(
				maxf(1.0, float(EncounterRecipes.get_cost(recipe_id)) / cheapest),
				bias
			)
		weights.append(weight)
		total += weight
	var roll := _random.randf() * total
	for index in range(eligible.size()):
		roll -= weights[index]
		if roll <= 0.0:
			return eligible[index]
	return eligible[eligible.size() - 1]


func _spend_fraction_at(seconds: float) -> float:
	## Share of the budget released by this second of the wave.
	##
	## Piecewise-linear and normalised to end at exactly one, so the phases above
	## describe the wave's shape and never its size. The opening break is subtracted
	## first: an authored pause is time the wave is not spending in, not time it has
	## to make up afterwards.
	var spending_span := maxf(1.0, _duration - _opening_break)
	var progress := clampf((seconds - _opening_break) / spending_span, 0.0, 1.0)
	var total := 0.0
	var accumulated := 0.0
	var previous_end := 0.0
	for phase in (FINALE_PHASES if _sustained else PHASES):
		var end: float = phase[0]
		var rate: float = phase[1]
		var span := end - previous_end
		if progress > previous_end:
			accumulated += rate * minf(span, progress - previous_end)
		total += rate * span
		previous_end = end
	if total <= 0.0:
		return progress
	return clampf(accumulated / total, 0.0, 1.0)
