class_name WaveScaling
extends RefCounted

## The curves one wave applies to everything that spawns while it is current.
##
## Two modes share one set of numbers. Quick drives health, contact damage and
## territory erosion from a difficulty ramp and leaves the rest neutral. The
## Campaign hands over one authored wave at a time, with six curves rather than
## two: health and contact damage alone produce a wave that is longer instead of
## harder, and what actually threatens a built organism is enemies that arrive
## sooner, work on the Green faster, take the territory apart harder, and shrug off
## part of the control that used to hold them.
##
## This owns the numbers, never the bodies they are written onto. `CombatDirector`
## keeps its enemies as pooled structs in a layout it tunes for the horde, so it
## asks what multiplier a role receives and does the assigning itself. That is also
## what keeps this module free of the node: `EnemyState` lives inside the director,
## and pure rules may not depend on it.

## Quick's ramp, and the Campaign's health/damage/erosion curves.
var _health_scale := 1.0
var _damage_scale := 1.0
var _territory_erosion_scale := 1.0
var _spawn_wave_number := 1
## Quick's XP growth, which the Campaign replaces with a flat multiplier.
var _xp_growth_per_wave := 0.10
var _xp_minimum_bonus_per_wave := 1
## Campaign scaling. Quick leaves all of this at its neutral value.
var _campaign_active := false
var _movement_scale := 1.0
var _action_speed_scale := 1.0
var _cc_resistance := 0.0
var _xp_multiplier := 1.0
## Role id to EnemyRoleScalingProfile, so a Rusher takes half the movement curve
## and a Grazer's bite cadence is never touched.
var _role_profiles := {}


## Quick's difficulty ramp: three curves and an XP growth, no role profiles.
func set_quick(
	health_scale: float,
	damage_scale: float,
	territory_erosion_scale: float = 1.0,
	spawn_wave_number: int = 1,
	xp_growth_per_wave: float = 0.10,
	xp_minimum_bonus_per_wave: int = 1
) -> void:
	_health_scale = maxf(0.1, health_scale)
	_damage_scale = maxf(0.1, damage_scale)
	_territory_erosion_scale = maxf(0.1, territory_erosion_scale)
	_spawn_wave_number = maxi(1, spawn_wave_number)
	_xp_growth_per_wave = maxf(0.0, xp_growth_per_wave)
	_xp_minimum_bonus_per_wave = maxi(0, xp_minimum_bonus_per_wave)
	_campaign_active = false


## The whole of one Campaign wave's pressure.
func set_campaign(
	wave_number: int,
	health_scale: float,
	damage_scale: float,
	movement_scale: float,
	territory_strength_scale: float,
	action_speed_scale: float,
	cc_resistance: float,
	xp_multiplier: float,
	role_profiles: Dictionary
) -> void:
	_campaign_active = true
	_health_scale = maxf(0.1, health_scale)
	_damage_scale = maxf(0.1, damage_scale)
	_territory_erosion_scale = maxf(0.1, territory_strength_scale)
	_movement_scale = maxf(0.1, movement_scale)
	_action_speed_scale = maxf(0.1, action_speed_scale)
	_cc_resistance = clampf(cc_resistance, 0.0, 1.0)
	_xp_multiplier = maxf(0.1, xp_multiplier)
	_spawn_wave_number = maxi(1, wave_number)
	_role_profiles = role_profiles


## Drops back to Quick's neutral values. The health, damage and erosion curves are
## deliberately left where they are: a reset run re-arms them from its own ramp
## before anything spawns, and zeroing them here would only hide a caller that
## forgot to.
func reset_campaign() -> void:
	_campaign_active = false
	_movement_scale = 1.0
	_action_speed_scale = 1.0
	_cc_resistance = 0.0
	_xp_multiplier = 1.0


func is_campaign_active() -> bool:
	return _campaign_active


func get_health_scale() -> float:
	return _health_scale


func get_damage_scale() -> float:
	return _damage_scale


func get_territory_erosion_scale() -> float:
	return _territory_erosion_scale


func get_spawn_wave_number() -> int:
	return _spawn_wave_number


func get_role_profile(role: int) -> EnemyRoleScalingProfile:
	return _role_profiles.get(role)


## The share of the wave's movement curve this role receives, as a multiplier to
## apply to its authored speed.
func get_movement_multiplier(role: int) -> float:
	var profile := get_role_profile(role)
	var factor := profile.movement_scaling_factor if profile != null else 1.0
	return 1.0 + (_movement_scale - 1.0) * factor


## The share of the wave's action-speed curve this role receives, as a divisor for
## whichever interval `scales_rest_interval_only` selects. Returns 1.0 - no change -
## for a role whose profile takes itself out of interval scaling entirely.
##
## Contact intervals are deliberately never part of this. Faster movement and higher
## contact damage already increase the pressure a body applies; shortening the
## interval as well would stack a third multiplier the player cannot read off the
## screen.
func get_action_speed_multiplier(role: int) -> float:
	var profile := get_role_profile(role)
	if profile != null and not profile.scales_action_interval:
		return 1.0
	var factor := profile.action_speed_scaling_factor if profile != null else 1.0
	var multiplier := 1.0 + (_action_speed_scale - 1.0) * factor
	return multiplier if multiplier > 0.0 else 1.0


## Whether this role's action curve shortens the recovery between bursts rather
## than the repeated action itself.
func scales_rest_interval_only(role: int) -> bool:
	var profile := get_role_profile(role)
	return profile != null and profile.scales_rest_interval_only


## Role resistance first, then the wave curve on what is left, so a Boss stays
## visibly affectable rather than compounding into immunity.
func get_cc_resistance(role: int) -> float:
	var profile := get_role_profile(role)
	var role_resistance := profile.role_cc_resistance if profile != null else 0.0
	var receives_global := profile == null or profile.receives_global_cc_resistance
	var remaining := 1.0 - clampf(role_resistance, 0.0, 0.9)
	if receives_global:
		remaining *= 1.0 - _cc_resistance
	return clampf(1.0 - remaining, 0.0, 0.95)


## Whether a role may be handed a random rule change yet. The Campaign gates each
## role on the wave its profile names, so the objective specialists join the system
## at the Boss rather than alongside the first Heavy Grazer.
func is_role_modifier_eligible(role: int, wave_number: int) -> bool:
	var profile := get_role_profile(role)
	if profile == null:
		return false
	return wave_number >= profile.modifier_eligible_from_wave


## The Campaign's XP curve is deliberately far flatter than its health curve. More
## durable enemies already reduce the kill rate, so an XP reward that grew at the
## same pace would make dense late waves fund themselves and hand a finished build
## the ranks the pacing targets say it should not have.
func get_scaled_xp_reward(base_xp: int, spawn_wave_number: int) -> int:
	if _campaign_active:
		return maxi(base_xp, roundi(float(base_xp) * _xp_multiplier))
	var wave_index := maxi(0, spawn_wave_number - 1)
	var proportional_reward := ceili(
		snappedf(
			float(base_xp) * (
				1.0 + float(wave_index) * _xp_growth_per_wave
			),
			0.0001
		)
	)
	var minimum_reward := base_xp + wave_index * _xp_minimum_bonus_per_wave
	return maxi(base_xp, maxi(proportional_reward, minimum_reward))
