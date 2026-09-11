class_name EliteModifiers
extends RefCounted

## Which rule change a spawn carries, if any.
##
## A modifier is a change to how an enemy has to be fought rather than a bigger
## number on it, so the whole point is that the player can read one on sight. Two on
## one body cannot be read, which is why nothing here ever returns more than one.
##
## It decides an integer from the run's own state and never touches the enemy it is
## deciding for: `CombatDirector` asks on spawn and writes the answer onto the
## pooled struct itself. The wave scaling it consults arrives per call rather than
## being held, because the Campaign replaces it wave by wave.
##
## The authored chances and the late-role list are copied in once through
## `configure`, since they are Inspector design surface on the director and are not
## written to during a run.

## Wave 18 is the modifier showcase: its first eligible spawns are steered to
## demonstrate three different rule changes before the roll goes back to chance.
## Tutorial shaping for one wave, deliberately not a permanent bias.
const SHOWCASE_WAVE := 18
const SHOWCASE_SPAWNS := 6
const SHOWCASE_TYPES := 3

var _base_chance := 0.0
var _final_chance := 0.0
## Roles that may carry a rule change outside the Campaign, where there is no
## authored per-wave eligibility to ask.
var _eligible_late_roles := PackedInt32Array()

## Chance an eligible spawn carries a rule change, driven by the wave director.
var _chance := 0.0
## A modifier pinned for the next eligible spawn, for tests and debug keys.
var _forced := EnemyKinds.EliteModifier.NONE
## Which rule changes this wave may hand out. Empty means the Quick behaviour of
## drawing from every authored modifier.
var _pool := PackedInt32Array()
## The Campaign wave modifier eligibility is judged against; zero outside Campaign.
var _wave_number := 0
var _showcase := PackedInt32Array()
var _showcase_eligible_spawns := 0


## Copies the authored tuning. The director calls this from its own `_ready`, after
## the scene has set its exports and before anything spawns.
func configure(
	base_chance: float,
	final_chance: float,
	eligible_late_roles: PackedInt32Array
) -> void:
	_base_chance = base_chance
	_final_chance = final_chance
	_eligible_late_roles = eligible_late_roles.duplicate()
	_chance = base_chance


func reset() -> void:
	_chance = _base_chance
	_forced = EnemyKinds.EliteModifier.NONE
	_pool = PackedInt32Array()
	_wave_number = 0
	_showcase = PackedInt32Array()
	_showcase_eligible_spawns = 0


func set_pressure(progress: float) -> void:
	# The wave director owns the run's escalation curve, so it says how far along the
	# run is and this turns that into the chance an eligible spawn changes the rules.
	_chance = lerpf(_base_chance, _final_chance, clampf(progress, 0.0, 1.0))


func get_chance() -> float:
	return _chance


func force_next(modifier: int) -> void:
	# Pins the next eligible spawn's rule change, because a one-in-six roll behind a
	# probability gate is not something a check can wait for.
	_forced = modifier


func set_stage(
	chance: float,
	available_modifiers: PackedInt32Array,
	wave_number: int
) -> void:
	## What this wave's rule changes can be, and how often they land.
	##
	## A stage adds to the one before it rather than replacing it, so a modifier the
	## player has learned to read never quietly disappears from the Campaign.
	_chance = clampf(chance, 0.0, 1.0)
	_pool = available_modifiers.duplicate()
	if wave_number != _wave_number:
		_wave_number = wave_number
		if wave_number == SHOWCASE_WAVE:
			_showcase = PackedInt32Array()
			_showcase_eligible_spawns = 0


func get_showcase_type_count() -> int:
	## How many different rule changes the showcase wave has demonstrated so far.
	return _showcase.size()


func roll(role: int, scaling: WaveScaling) -> int:
	if _forced != EnemyKinds.EliteModifier.NONE:
		var forced := _forced
		_forced = EnemyKinds.EliteModifier.NONE
		return forced
	if not is_eligible(role, scaling):
		return EnemyKinds.EliteModifier.NONE
	if scaling.is_campaign_active():
		return _roll_campaign()
	if _chance <= 0.0:
		return EnemyKinds.EliteModifier.NONE
	if randf() > _chance:
		return EnemyKinds.EliteModifier.NONE
	# One modifier, never two. Two rule changes on one body is a fight the player
	# cannot read, and the point of these is that they are legible.
	return randi_range(EnemyKinds.EliteModifier.UNSTOPPABLE, EnemyKinds.EliteModifier.VOLATILE)


func is_eligible(role: int, scaling: WaveScaling) -> bool:
	# The Elite is always eligible - it is what the modifiers are named for. The
	# Boss is excluded: it already changes the rules by itself, and a Colony Core
	# cannot use any of them, nor may it inherit its Colonizer's.
	if role == EnemyKinds.Role.ELITE:
		return true
	if role == EnemyKinds.Role.BOSS or role == EnemyKinds.Role.COLONY_CORE:
		return false
	if not scaling.is_campaign_active():
		return _eligible_late_roles.has(role)
	return scaling.is_role_modifier_eligible(role, _wave_number)


func _roll_campaign() -> int:
	if _pool.is_empty():
		return EnemyKinds.EliteModifier.NONE
	if _wave_number == SHOWCASE_WAVE:
		var showcased := _draw_showcase()
		if showcased != EnemyKinds.EliteModifier.NONE:
			return showcased
	if _chance <= 0.0 or randf() > _chance:
		return EnemyKinds.EliteModifier.NONE
	return _pool[randi() % _pool.size()]


func _draw_showcase() -> int:
	## The modifier showcase. Wave 18's first eligible spawns are steered so the
	## player meets three different rule changes rather than three copies of
	## whichever one the dice picked first. Shaping for one wave only: once the
	## quota is met the wave goes back to its authored chance.
	_showcase_eligible_spawns += 1
	if (
		_showcase_eligible_spawns > SHOWCASE_SPAWNS
		or _showcase.size() >= SHOWCASE_TYPES
	):
		return EnemyKinds.EliteModifier.NONE
	for offset in range(_pool.size()):
		var candidate := _pool[
			(_showcase_eligible_spawns + offset) % _pool.size()
		]
		if not _showcase.has(candidate):
			_showcase.append(candidate)
			return candidate
	return EnemyKinds.EliteModifier.NONE
