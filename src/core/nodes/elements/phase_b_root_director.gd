class_name PhaseBRootDirector
extends Node

## Root: how fast territory ages, how well aged territory holds, what it yields,
## and how strongly it amplifies whatever else the run does. Like Bramble, Root
## owns no entities and has no cadence - its effects are field rules and a single
## published amplification - so this component owns the path's tuning and its
## derived values, and hands them to the systems that execute them.

@export_group("Collaborators")
## Authoritative field that applies maturation, regeneration, and Mature resistance.
@export var territory_field: TerritoryField
## Progression component that owns which lines the run has taken and at what level.
@export var progression: PhaseBProgression
## Relic component publishing the local Root Potency two relics add on top of the
## path's own amplification. Optional: without it the path behaves as authored.
@export var relic_director: PhaseBRelicDirector

@export_group("Maturation Speed")
## Additive maturation-rate multiplier granted by each Maturation Speed rank.
@export_range(0.0, 2.0, 0.01) var maturation_per_level := 0.22

@export_group("Biomass Yield")
## Additive multiplier on Biomass from Mature Green per Biomass Yield rank.
@export_range(0.0, 2.0, 0.01) var biomass_yield_per_level := 0.20

@export_group("Mature Strength")
## Resistance multiplier applied to Mature Plant territory whenever Root is selected.
@export_range(1.0, 4.0, 0.05) var base_mature_resistance := 1.20
## Additive Mature-territory resistance granted by each Mature Strength rank.
@export_range(0.0, 1.0, 0.01) var mature_resistance_per_level := 0.16
## Control per second recovered by damaged Plant territory whenever Root is selected.
@export_range(0.0, 0.5, 0.005) var base_regeneration := 0.006
## Additional recovered control per second granted by each Mature Strength rank.
## Regeneration is folded into Mature Strength rather than owning a line of its own.
@export_range(0.0, 0.5, 0.005) var regeneration_per_level := 0.008

@export_group("Material Properties")
## Small-fragment decay multiplier applied to Green while Root is selected. Rooted
## ground tears into isolated scraps far less readily than fresh Green does.
@export_range(0.05, 1.0, 0.01) var fragment_decay_multiplier := 0.65
## Extra pressure transmission supplied by fully Rooted territory. Old Green passes
## force along instead of absorbing it, which is why a Bloom out of Rooted ground
## behaves physically differently from one out of Fresh Green.
@export_range(0.0, 2.0, 0.01) var pressure_transmission_bonus := 0.35

@export_group("Root Potency")
## Root Network amplification supplied by fully Mature ground whenever Root is selected.
@export_range(0.0, 4.0, 0.01) var base_network_bonus := 0.30
## Additional Root Network amplification granted by each Root Potency rank.
@export_range(0.0, 2.0, 0.01) var network_bonus_per_level := 0.22

## Field maturation rate before this path multiplies it, captured once so repeated
## application never compounds.
var _base_maturation_per_second := 0.0
var _base_regeneration_per_second := 0.0


func _ready() -> void:
	assert(territory_field != null, "PhaseBRootDirector requires TerritoryField")
	assert(progression != null, "PhaseBRootDirector requires PhaseBProgression")
	_base_maturation_per_second = territory_field.tuning.maturation_per_second
	_base_regeneration_per_second = territory_field.tuning.regeneration_per_second


func reset_director() -> void:
	# The run controller resets the field's own tuning; Root re-applies its share
	# from the untouched baselines it captured on ready.
	territory_field.tuning.maturation_per_second = _base_maturation_per_second
	territory_field.tuning.regeneration_per_second = _base_regeneration_per_second
	territory_field.set_mature_resistance_multiplier(1.0)


func has_path() -> bool:
	# Active, not owned: a Root jackpot runs the path for a run that never took it.
	return progression.has_path_active(PhaseBProgression.PathId.ROOT)


func get_maturation_multiplier() -> float:
	if not has_path():
		return 1.0
	return 1.0 + maturation_per_level * float(
		progression.get_upgrade_level(PhaseBProgression.UpgradeId.ROOT_MATURATION)
	)


func get_biomass_yield_multiplier() -> float:
	if not has_path():
		return 1.0
	return 1.0 + biomass_yield_per_level * float(
		progression.get_upgrade_level(PhaseBProgression.UpgradeId.ROOT_BIOMASS_YIELD)
	)


func get_mature_resistance_multiplier() -> float:
	if not has_path():
		return 1.0
	return base_mature_resistance + mature_resistance_per_level * float(
		progression.get_upgrade_level(PhaseBProgression.UpgradeId.ROOT_MATURE_STRENGTH)
	)


func get_regeneration_per_second() -> float:
	if not has_path():
		return 0.0
	return base_regeneration + regeneration_per_level * float(
		progression.get_upgrade_level(PhaseBProgression.UpgradeId.ROOT_MATURE_STRENGTH)
	)


func get_network_bonus() -> float:
	# Root Potency: how strongly Mature ground amplifies whatever else the run runs
	# through it. Every consumer scales this by the maturity under the effect, so a
	# run without Root gets nothing and fresh Green gets nothing either.
	if not has_path():
		return 0.0
	return base_network_bonus + network_bonus_per_level * float(
		progression.get_upgrade_level(PhaseBProgression.UpgradeId.ROOT_POTENCY)
	)


func get_fragment_decay_multiplier() -> float:
	# Lower fragmentation is a material property, so it is reported as a multiplier
	# on the field's own decay rather than as a special case inside the field.
	if not has_path():
		return 1.0
	return fragment_decay_multiplier


func get_pressure_transmission_multiplier() -> float:
	if not has_path():
		return 1.0
	return 1.0 + pressure_transmission_bonus


func get_cohesion_multiplier() -> float:
	# Root is the path that changes what old Green is made of. Its Mature Strength
	# is the same number the field reads as cohesion, so one investment moves
	# resistance, recovery, and how the material holds together together.
	if not has_path():
		return 1.0
	return get_mature_resistance_multiplier()


func get_network_bonus_at(local_position: Vector2) -> float:
	# Root Potency where the effect is actually happening. Annual Rings and a
	# Seedbed node both deepen the ecosystem locally rather than globally, so the
	# mechanics that ride Root ask about the ground they are standing on.
	var bonus := get_network_bonus()
	if relic_director != null:
		bonus += relic_director.get_root_potency_bonus_at(local_position)
	return bonus


func apply_modifiers(field_maturation_multiplier: float) -> void:
	# Root's rules are field rules. The Biomass multiplier is read by whoever ticks
	# the economy rather than pushed anywhere.
	territory_field.tuning.maturation_per_second = (
		_base_maturation_per_second
		* field_maturation_multiplier
		* get_maturation_multiplier()
	)
	territory_field.tuning.regeneration_per_second = (
		_base_regeneration_per_second + get_regeneration_per_second()
	)
	territory_field.set_mature_resistance_multiplier(get_mature_resistance_multiplier())
