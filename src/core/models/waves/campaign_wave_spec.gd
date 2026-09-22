class_name CampaignWaveSpec
extends Resource

## One authored wave of the 20-minute Campaign.
##
## The wave is the Campaign's unit of configuration. Every number an enemy spawned
## during a wave is built from lives here, so tuning a wave is editing one object
## rather than hunting for the wave number in a director's branches. The director
## reads a spec and never asks "which wave is this" a second time.

@export_group("Identity")
## One-based Campaign wave this spec configures.
@export_range(1, 20, 1) var wave_index := 1
## Which of the four Campaign acts this wave belongs to. Gates which encounter
## recipes the Threat Director may buy and how far the Canker ladder has opened.
@export_range(1, 4, 1) var act := 1
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

@export_group("Threat")
## Total threat this wave may spend on encounters, before Blight and Surge.
##
## The Campaign's one density dial. It is a budget rather than a spawn rate because
## the same number has to buy a different kind of wave at each end of the run: three
## hundred spent on Probes is a crowd, three hundred spent on a Siege Push is a
## problem, and the recipe list below decides which of those a wave is made of.
@export_range(0.0, 20000.0, 10.0) var threat_budget := 620.0
## Encounter recipe ids (see `EncounterRecipes`) this wave may buy.
@export var recipe_ids: Array = []
## Topology profile used when a recipe does not name one of its own.
@export var spawn_topology: StringName = &"EVEN_RING"
## Whether this wave skips the recovery tail in its pressure rhythm. Only the finale
## does: every other wave owes the player the quiet that Provocation is spent on.
@export var sustains_final_pressure := false
## Which modifier unlock stage this wave draws from; see CampaignWaves.
@export_range(0, 4, 1) var modifier_pool_stage := 0

@export_group("Milestones")
## Second within the wave at which the Elite Rootbreaker enters; negative disables.
@export_range(-1.0, 60.0, 0.5) var elite_spawn_second := -1.0
## Second within the wave at which the Burrower Boss enters; negative disables.
@export_range(-1.0, 60.0, 0.5) var boss_spawn_second := -1.0
## Second within the wave at which the Hive Queen enters; negative disables.
@export_range(-1.0, 60.0, 0.5) var hive_queen_spawn_second := -1.0
## Completing this wave opens one of the Campaign's eleven relic opportunities.
@export var grants_wave_relic := false
## Beginning this wave offers every Evolution the run currently qualifies for.
@export var grants_evolution_reward := false
## Whether that reward is a second chance for a run still short of the target rather
## than another grant. See `CampaignWaves.CATCH_UP_EVOLUTION_WAVES`.
@export var evolution_reward_is_catch_up := false
## Beginning this wave hands the player a draft of Adaptations they do not own.
@export var grants_path_draft := false
## Beginning this wave sets a Trial: one rule, held for this wave, for a relic.
@export var grants_trial := false
