class_name PhaseBEnemyProfile
extends Node

enum Role {
	HUNTER,
	GRAZER,
	ELITE,
	BOSS,
	SABOTEUR,
	CORRUPTOR,
	COLONIZER,
	WARDEN,
	COLONY_CORE,
}

enum MovementBehavior {
	CHASE_PLAYER,
	HUNT_CATALYSTS,
	KEEP_DISTANCE,
	ANCHORED,
}

enum TerritoryBehavior {
	NONE,
	GRAZE_GREEN,
	ERUPTION,
	SABOTAGE_CATALYST,
	CORRUPT_GREEN,
	ESTABLISH_COLONY,
	SPREAD_HOSTILE,
	SUPPRESS_MATURITY,
}

@export_group("Identity")
## Required archetype identity for this profile slot; keep it matched to the node name.
@export var role := Role.HUNTER

@export_group("Combat Stats")
## Base health assigned when this enemy spawns, before run-pressure scaling.
@export_range(1.0, 10000.0, 1.0) var maximum_health := 28.0
## Pursuit speed in arena pixels per second.
@export_range(1.0, 500.0, 1.0) var movement_speed := 68.0
## Player damage dealt by each successful contact attack, before run scaling.
@export_range(0.0, 200.0, 0.5) var contact_damage := 5.5
## Minimum seconds between repeated contact attacks against the player.
@export_range(0.05, 5.0, 0.05) var contact_interval_seconds := 0.80
## Base XP carried by the dropped pickup, before per-wave reward scaling.
@export_range(1, 5000, 1) var xp_reward := 2
## Visual and contact radius in pixels; navigation collision derives from this value.
@export_range(2.0, 64.0, 0.5) var body_radius_pixels := 9.0

@export_group("Targeting and Navigation")
## Thornshot target-score multiplier; values below 1 make this enemy more attractive.
@export_range(0.05, 2.0, 0.05) var target_priority_multiplier := 1.0
## Uses CombatDirector's wider boss navigation clearance instead of the small clearance.
@export var use_boss_navigation := false
## Movement objective used by this archetype: chase, hunt catalysts, keep distance, or remain anchored.
@export var movement_behavior := MovementBehavior.CHASE_PLAYER
## Desired player separation used only by Keep Distance movement; the enemy retreats inside this range.
@export_range(0.0, 500.0, 5.0) var preferred_distance_pixels := 0.0

@export_group("Territory Behavior")
## Specialized action performed on cadence, including erosion, corruption, colonies, and suppression.
@export var territory_behavior := TerritoryBehavior.NONE
## Seconds after spawning before this enemy may perform its first territory action.
@export_range(0.0, 20.0, 0.05) var first_territory_action_delay_seconds := 0.0
## Seconds between this enemy's repeated territory actions.
@export_range(0.01, 20.0, 0.01) var territory_action_interval_seconds := 1.0
## Base magnitude of this role's action before per-wave territory-pressure scaling.
@export_range(0.0, 8.0, 0.01) var territory_action_strength := 0.0
## Radius multiplier for erosion, hostile growth, catalyst attacks, or maturity suppression.
@export_range(0.1, 8.0, 0.05) var territory_action_radius_multiplier := 1.0
## Territory actions performed back to back before this archetype must recover; zero disables.
@export_range(0, 60, 1) var territory_actions_before_recovery := 0
## Seconds this archetype pauses after a burst, opening a window for the frontier to regrow.
@export_range(0.0, 30.0, 0.1) var territory_recovery_seconds := 0.0
## When enabled, territory actions occur only while standing on player-owned Green.
@export var require_player_territory := false
## Emits the boss-eruption event after each action for its pulse and status feedback.
@export var emit_eruption_signal := false

@export_group("Specialized Behavior")
## Furthest distance at which Hunt Catalysts movement notices a Seed or Bloom; zero means unlimited.
@export_range(0.0, 1200.0, 10.0) var catalyst_search_range_pixels := 0.0
## Highest territory maturity a Saboteur treats as vulnerable Fresh fallback terrain.
@export_range(0.0, 1.0, 0.01) var fresh_maturity_threshold := 0.35
## Maximum Colony Cores maintained by one Colonizer profile across the active arena.
@export_range(0, 20, 1) var maximum_active_summons := 0
## Minimum center-to-center distance required before a Colonizer establishes another Core.
@export_range(0.0, 500.0, 5.0) var summon_spacing_pixels := 0.0
