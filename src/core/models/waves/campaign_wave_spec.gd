class_name CampaignWaveSpec
extends Resource

## One authored wave of the 25-minute Campaign.
##
## The wave is the Campaign's unit of configuration. Every number an enemy spawned
## during a wave is built from lives here, so tuning a wave is editing one object
## rather than hunting for the wave number in a director's branches. The director
## reads a spec and never asks "which wave is this" a second time.

@export_group("Identity")
## One-based Campaign wave this spec configures.
@export_range(1, 25, 1) var wave_index := 1
## Wave card title shown to the player; says what the wave is rather than its numbers.
@export var display_name: StringName = &"Garden Under Attack"
## Length of this wave in seconds. Every Campaign wave is a fixed minute.
@export_range(10.0, 180.0, 1.0) var duration_seconds := 60.0
## Authored reinforcement-free seconds at the wave's start. Never ended early.
@export_range(0.0, 10.0, 0.25) var opening_break_seconds := 0.0

@export_group("Global Scaling")
## Multiplier on every spawned enemy's authored maximum health.
@export_range(0.5, 8.0, 0.01) var hp_multiplier := 1.10
## Multiplier on every spawned enemy's authored contact damage.
@export_range(0.5, 8.0, 0.01) var contact_damage_multiplier := 1.05
## Movement multiplier before each role's own movement scaling factor is applied.
@export_range(0.5, 3.0, 0.001) var movement_speed_multiplier := 1.0
## Multiplier on the strength of every territory action an enemy performs.
@export_range(0.5, 8.0, 0.01) var territory_strength_multiplier := 1.10
## Territory-action rate multiplier before each role's own action scaling factor.
@export_range(0.5, 3.0, 0.001) var territory_action_speed_multiplier := 1.0
## Share of authored root duration, shove distance, and slow intensity removed.
## Never an immunity: buildup toward full Entanglement is deliberately untouched.
@export_range(0.0, 1.0, 0.01) var cc_resistance := 0.0
## Chance an eligible spawn carries one rule-changing modifier.
@export_range(0.0, 1.0, 0.01) var modifier_chance := 0.0

@export_group("Cadence")
## Seconds between scheduled reinforcement packs.
@export_range(0.05, 5.0, 0.01) var pack_interval_seconds := 0.80
## Pack-size sequence consumed one entry per pack, reset at the wave boundary.
@export var pack_pattern: StringName = &"ONE"
## Role id (PhaseBCombatDirector.EnemyRole) to leader-deck percentage.
@export var role_weights: Dictionary = {}
## Topology profile governing where this wave's packs enter the arena.
@export var spawn_topology: StringName = &"EVEN_RING"
## Which modifier unlock stage this wave draws from; see PhaseBCampaignWaves.
@export_range(0, 4, 1) var modifier_pool_stage := 0

@export_group("Milestones")
## Second within the wave at which the Elite Rootbreaker enters; negative disables.
@export_range(-1.0, 60.0, 0.5) var elite_spawn_second := -1.0
## Second within the wave at which the Burrower Boss enters; negative disables.
@export_range(-1.0, 60.0, 0.5) var boss_spawn_second := -1.0
## Completing this wave opens one of the Campaign's ten relic opportunities.
@export var grants_wave_relic := false
