class_name RateZones
extends RefCounted

## Timed circular patches that raise one rate wherever they cover the ground.
##
## Two of these run in a fight - Aggressive Growth's Entanglement patches and
## Contaminated Ground's Spore patches - and they were the same eighty lines written
## twice inside `CombatDirector`. They are one class instantiated twice because the
## rule is the same rule: a patch has a centre, a reach, a bonus and a clock, and
## where patches overlap the strongest wins rather than the sum.
##
## Overlap chooses rather than stacks deliberately. A Fruit trail stamps a patch
## every few pixels, and a rule that added them together would make a doubled-back
## trail worth several times a straight one for no reason a player could see.

## A patch is [centre, radius, bonus, seconds remaining]. Kept as a plain Array
## because that is the layout the zones were merged and aged in before they moved,
## and this is a move rather than a rewrite.
var _zones: Array = []

## How many patches may exist at once. A Fruit trail can outrun any expiry, so the
## oldest is dropped rather than letting the list grow without bound.
const MAXIMUM_ZONES := 64
## How close two equal patches must be before the newer one refreshes the older
## instead of joining it. Proportional to the reach, with a floor for small ones.
const MERGE_DISTANCE_FRACTION := 0.55
const MERGE_DISTANCE_MINIMUM := 8.0


func add(center: Vector2, radius: float, rate_bonus: float, duration: float) -> void:
	if rate_bonus <= 0.0 or duration <= 0.0:
		return
	# Stamps can arrive every few pixels. Merging nearby equal patches keeps a long
	# trail one bounded gameplay region rather than hundreds of entries.
	for zone in _zones:
		if (
			Vector2(zone[0]).distance_to(center)
				<= maxf(MERGE_DISTANCE_MINIMUM, radius * MERGE_DISTANCE_FRACTION)
			and is_equal_approx(float(zone[2]), rate_bonus)
		):
			zone[0] = center
			zone[1] = maxf(float(zone[1]), radius)
			zone[3] = maxf(float(zone[3]), duration)
			return
	_zones.append([center, radius, rate_bonus, duration])
	if _zones.size() > MAXIMUM_ZONES:
		_zones.pop_front()


func advance(delta: float) -> void:
	for index in range(_zones.size() - 1, -1, -1):
		var zone: Array = _zones[index]
		zone[3] = float(zone[3]) - delta
		if zone[3] <= 0.0:
			_zones.remove_at(index)


## The strongest bonus covering this point, or zero where nothing does.
func get_bonus_at(local_position: Vector2) -> float:
	var bonus := 0.0
	for zone in _zones:
		if local_position.distance_to(Vector2(zone[0])) <= float(zone[1]):
			bonus = maxf(bonus, float(zone[2]))
	return bonus


func get_active_count() -> int:
	return _zones.size()


func clear() -> void:
	_zones.clear()
