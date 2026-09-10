class_name EnemyState
extends RefCounted

## One enemy body, as a pooled struct.
##
## Enemies are not nodes and deliberately never become them: a horde game spawns
## them by the hundred, and `docs/performance_optimization_implementation_guide.md`
## exists to protect the pooled-array layout that makes that affordable. What lives
## here is the whole of one body's state - every field a system reads or writes -
## so the arrays `CombatDirector` sweeps are flat and contiguous.
##
## It holds no behaviour. Every rule that acts on these fields lives in the director
## that owns the pool or in `src/core/rules/`.

var active := false
## Damage waiting to be shown as one number. Ordinary hits accumulate here and
## flush together; a critical never waits, so it is never part of this.
var pending_number_damage := 0.0
var pending_number_remaining := 0.0
var pending_number_color := Color.WHITE
var state := EnemyKinds.StateKind.INACTIVE
var id := 0
var role := EnemyKinds.Role.HUNTER
var position := Vector2.ZERO
var health := 0.0
var maximum_health := 0.0
var speed := 0.0
var contact_damage := 0.0
var contact_interval := 0.8
var contact_remaining := 0.0
var movement_behavior := EnemyProfile.MovementBehavior.CHASE_PLAYER
var preferred_distance_pixels := 0.0
var territory_behavior := EnemyProfile.TerritoryBehavior.NONE
var territory_action_remaining := 0.0
var territory_action_interval := 1.0
var territory_action_strength := 0.0
var territory_action_radius_multiplier := 1.0
var require_player_territory := false
var territory_actions_before_recovery := 0
var territory_recovery_seconds := 0.0
var territory_actions_taken := 0
var emit_eruption_signal := false
var catalyst_search_range_pixels := 0.0
var fresh_maturity_threshold := 0.35
var maximum_active_summons := 0
var summon_spacing_pixels := 0.0
var radius := 10.0
var collision_radius := 6.0
var xp_value := 1
var spawn_wave_number := 1
var territory_erosion_scale := 1.0
## Share of an incoming Ensnare duration, shove distance or slow this body ignores,
## resolved once at spawn from the wave's curve and this role's own resistance.
## Stored on the body rather than read live so an enemy fights at the wave it
## entered in, which is the same rule its health and damage already follow.
var cc_resistance := 0.0
var target_priority_multiplier := 1.0
var use_boss_navigation := false
var direct_path_clear := false
var path_check_remaining := 0.0
var hit_flash_remaining := 0.0
var hit_flash_color := Color.WHITE
var bramble_damage_remaining := 0.0
var bramble_repulsion_remaining := 0.0
var bramble_crossing_remaining := 0.0
var bramble_eruption_remaining := 0.0
## Seconds left of a Grasping Thorns Ensnare, during which the enemy cannot move.
var bramble_ensnare_remaining := 0.0
## Full length of the current hold, so the indicator can show what is left of it.
var bramble_ensnare_duration := 0.0
## Seconds left before this enemy may be Ensnared again.
var bramble_ensnare_immunity_remaining := 0.0
## Direction of a repulsion shove currently playing out.
var knockback_direction := Vector2.ZERO
## Seconds left of that shove, which travels over time rather than teleporting.
var knockback_remaining := 0.0
## Opening speed of the shove; it eases to zero across the duration.
var knockback_speed := 0.0
## Suppressed: seconds left of the window in which this enemy is worse at eating
## Green, and the share of its territory damage the window takes away. It touches
## the territory layer and nothing else - not what it does to the player, not how
## fast it moves, not what it can take.
var suppression_remaining := 0.0
var suppression_share := 0.0
## 0-to-1 Spore accumulated by standing on owned Green. Unlike Entanglement it
## never decays: an infection the enemy walks away from is still an infection.
var spore := 0.0
## Set the moment Spore reaches 1.0, and never cleared while the enemy lives.
var overgrown := false
## Seconds until the next tick of Overgrown max-health damage.
var spore_damage_remaining := 0.0
## 0-to-1 Entanglement accumulated by standing on Bramble-covered Green.
var entanglement := 0.0
## Frontier hedge strength sampled where the enemy stands, as a damage bonus.
var bramble_frontier_strength := 0.0
## Maturity of the ground under the enemy, which the Root Network amplifies.
var bramble_ground_maturity := 0.0
var bramble_horde_count := 0
var was_on_bramble := false
var movement_speed_multiplier := 1.0
## Share of an incoming shove this enemy ignores.
var knockback_resistance := 0.0
## What each uninterrupted territory action multiplies the next one by, and the
## ceiling on the running total.
var territory_action_escalation := 1.0
var territory_action_escalation_cap := 1.0
## The running multiplier itself. It is reset by being hit, which is what makes
## "if ignored" the actual condition rather than a timer.
var territory_escalation := 1.0
## The rule this elite changes, or NONE for everything that changes none.
var elite_modifier := EnemyKinds.EliteModifier.NONE
## Seconds left of the window in which Regenerative refuses to heal.
var regeneration_block_remaining := 0.0
## Where Blighted last soured the ground, so it leaves a trail rather than a
## smear: the wake is stamped at intervals along the path, not every frame.
var blight_last_position := Vector2.ZERO
