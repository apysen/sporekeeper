class_name PhaseBCombatDirector
extends Node2D

const NAVIGATION_DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]
const STEERING_ANGLES: Array[float] = [0.0, 0.48, -0.48, 0.92, -0.92, 1.45, -1.45]
const XP_COLLECT_AUDIO_VOICE_COUNT := 12
const PLANT_EXPLOSION_MAX_POLYPHONY := 8
const OLD_GROWTH_MAX_POLYPHONY := 4
const DEBUG_PROJECTILE_SPEED := 720.0
const DEBUG_PROJECTILE_RANGE := 285.0
const DEBUG_PROJECTILE_LIFETIME := 1.4

signal enemy_killed(
	local_position: Vector2,
	xp_value: int,
	role: int,
	death_source: int,
	chain_depth: int
)
signal xp_collected(amount: int)
signal elite_defeated
signal boss_defeated
signal boss_erupted(local_position: Vector2)
signal briar_trap_detonated(local_position: Vector2)
## An Overgrown enemy shedding a Fruiting Body's Seeds is Spore's business, not
## combat's: this reports the rupture and the Spore path decides what Seeds it makes.
signal fruiting_body_ruptured(local_position: Vector2)
## Grasping Roots pinned an enemy. Published so a relic can answer a root without
## reaching into the combat loop for it.
signal enemy_rooted(local_position: Vector2)
## Bramble Repulsion shoved an enemy. Carries where it started and where it is being
## sent, because the relics that answer a shove care about what it collides with.
signal enemy_repelled(enemy_id: int, from_position: Vector2, direction: Vector2)
## An enemy carried Entanglement off the Green it picked it up on.
signal enemy_left_green(enemy_id: int, local_position: Vector2, entanglement: float)
## An enemy died with Entanglement still on it, which is what the corpse-reading
## Bramble relics are counting.
signal enemy_died_entangled(local_position: Vector2, entanglement: float, role: int)
## How much Green an enemy personally erased. Only what the enemy itself destroys is
## reported: territory the player gives up to Pruning or wagers on Clover is their
## own doing and must never be readable as something an enemy ate.
signal enemy_ate_green(enemy_id: int, mass: float, seconds: float)
signal active_enemy_count_changed(count: int)
## An elite spawned carrying a rule change. The player has to be able to see which
## one before it matters, so this is what the battlefield reads to mark it.
signal elite_modifier_assigned(enemy_id: int, modifier: int)
## A Volatile elite detonated where it died.
signal elite_detonated(local_position: Vector2, radius: float)
## The universal Cane publishes one bounded event per sweep so Vine and its pair
## Evolutions can answer the attack without replacing its cadence or targeting rules.
signal cane_sweep_started(
	origin: Vector2,
	facing: Vector2,
	left_to_right: bool,
	reach: float,
	damage: float,
	is_bonus: bool
)
signal cane_enemy_hit(
	enemy_id: int,
	local_position: Vector2,
	distance_fraction: float,
	apical: bool,
	damage: float,
	killed: bool,
	is_bonus: bool
)
signal cane_sweep_finished(
	origin: Vector2,
	facing: Vector2,
	left_to_right: bool,
	reach: float,
	hit_count: int,
	is_bonus: bool
)

enum EnemyRole {
	HUNTER,
	GRAZER,
	ELITE,
	BOSS,
	SABOTEUR,
	CORRUPTOR,
	COLONIZER,
	WARDEN,
	COLONY_CORE,
	HEAVY_GRAZER,
	RUSHER,
	SIEGE_CORRUPTOR,
}

## Rule changes an elite can carry. The design note is explicit that a late elite
## should increasingly change the rules rather than only its stat line, so each of
## these makes the fight different rather than longer. One per elite, never stacked:
## two rule changes on one body is a fight the player cannot read.
enum EliteModifier {
	NONE,
	## Cannot be rooted or shoved. Still fully vulnerable to being slowed, which is
	## what keeps it a rule change rather than an immunity to Bramble.
	UNSTOPPABLE,
	## Leaves Hostile territory in its wake, so its path through the organism has to
	## be fought back through afterwards.
	BLIGHTED,
	## Its territory work accelerates for as long as it is left alone.
	RAVENOUS,
	## Heals unless the player has damaged it recently. Anything else the run does -
	## thorns, Blooms, the ring - is deliberately not enough on its own.
	REGENERATIVE,
	## Suppresses the maturity of the Green around it, weakening everything the run's
	## territory effects are read from while it is standing there.
	DISRUPTIVE,
	## Detonates on death, damaging nearby enemies and the Green it dies on.
	VOLATILE,
}

enum EnemyStateKind {
	INACTIVE,
	ADVANCING,
	CONTACT,
}

enum DeathSource {
	CANE,
	BLOOM,
	SUPER_BLOOM,
	DEBUG,
	BRAMBLE,
	THORNBURST,
	ROOT_ERUPTION,
	CUTTING,
	MAN_EATER,
	## Damage dealt by a relic. Relic kills never feed a relic's own trigger, so
	## the source is what stops a primed explosion from chaining into itself.
	RELIC,
	## An Overgrown enemy rotting from the inside. Named apart from the rest because
	## Spore has already been paid for this enemy: an Overgrown kill must not also
	## feed the kill-to-Seed counter.
	SPORE,
	THISTLE,
	FRUIT,
}

class EnemyState:
	var active := false
	## Damage waiting to be shown as one number. Ordinary hits accumulate here and
	## flush together; a critical never waits, so it is never part of this.
	var pending_number_damage := 0.0
	var pending_number_remaining := 0.0
	var pending_number_color := Color.WHITE
	var state := EnemyStateKind.INACTIVE
	var id := 0
	var role := EnemyRole.HUNTER
	var position := Vector2.ZERO
	var health := 0.0
	var maximum_health := 0.0
	var speed := 0.0
	var contact_damage := 0.0
	var contact_interval := 0.8
	var contact_remaining := 0.0
	var movement_behavior := PhaseBEnemyProfile.MovementBehavior.CHASE_PLAYER
	var preferred_distance_pixels := 0.0
	var territory_behavior := PhaseBEnemyProfile.TerritoryBehavior.NONE
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
	## Seconds left of a Grasping Roots hold, during which the enemy cannot move.
	var bramble_root_remaining := 0.0
	## Full length of the current hold, so the indicator can show what is left of it.
	var bramble_root_duration := 0.0
	## Seconds left before this enemy may be rooted again.
	var bramble_root_immunity_remaining := 0.0
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
	var elite_modifier := EliteModifier.NONE
	## Seconds left of the window in which Regenerative refuses to heal.
	var regeneration_block_remaining := 0.0
	## Where Blighted last soured the ground, so it leaves a trail rather than a
	## smear: the wake is stamped at intervals along the path, not every frame.
	var blight_last_position := Vector2.ZERO

class ProjectileState:
	var active := false
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var damage := 0.0
	var remaining := 0.0
	var remaining_distance := 0.0
	var pierce_remaining := 1
	var last_hit_enemy_id := -1

class PickupState:
	var active := false
	var position := Vector2.ZERO
	var xp_value := 1
	var age := 0.0

class DamageNumberState:
	var active := false
	var impact_position := Vector2.ZERO
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var text := ""
	var color := Color.WHITE
	var age := 0.0
	var impact_radius := 8.0
	## Size the text renders at, and the measurement of it. Neither changes once the
	## number is spawned, so both are worked out there rather than every frame.
	var font_size := 16
	var text_size := Vector2.ZERO

class RootEruptionState:
	var active := false
	var position := Vector2.ZERO
	var remaining := 0.0
	var duration := 1.0
	var seed := 0

class BrambleZoneState:
	var active := false
	var position := Vector2.ZERO
	var radius := 0.0
	var remaining := 0.0
	var duration := 1.0
	var contact_multiplier := 1.0

class BriarTrapState:
	var active := false
	## A Briar Heart detonates repeatedly instead of once, at a larger reach.
	var detonations_remaining := 1
	var is_briar_heart := false
	var position := Vector2.ZERO
	var radius := 0.0
	var trigger_radius := 0.0
	var chain_radius := 0.0
	var remaining := 0.0
	var duration := 1.0
	var damage := 0.0
	var entanglement_gain := 0.0
	## Seconds left on a lit fuse; zero while the trap is simply waiting for prey.
	var fuse_remaining := 0.0
	var chain_depth := 0
	var seed := 0

class FruitingBodyState:
	## One fungal colony raised by a germination inside owned Green. Every Fruiting
	## Body behaves identically whatever rank raised it: the upgrade line buys how
	## often one appears, never what it does once it is standing.
	var active := false
	var position := Vector2.ZERO
	## Seconds until the next Spore cloud.
	var cloud_remaining := 0.0
	## Clouds left before this colony ruptures.
	var clouds_remaining := 0
	var seed := 0


class PendingEruptionState:
	var active := false
	var position := Vector2.ZERO
	var delay_remaining := 0.0
	var chain_depth := 0

@export_group("Collaborators")
## Player component used as the enemy target, Cane origin, and contact-damage receiver.
@export var player: PhaseBPlayer
## Authoritative field used for wall visibility, navigation, ownership, and erosion commands.
@export var territory_field: TerritoryField
## Seed and Bloom owner queried by Saboteurs for visible catalyst targets and damage.
@export var overlay: TerritoryPrototypeOverlay
## Audio bus names and global output caps used by dynamically created combat players.
@export var audio_settings: PhaseBAudioSettings
## Presentation options. Optional: without it every number is drawn, which is the
## behaviour this had before the setting existed.
@export var display_settings: PhaseBDisplaySettings
## Root component supplying the Root Network amplification at a given position,
## which is how the relics that deepen the Network locally reach the Bramble rules.
## Optional: without it the path falls back to the run-wide bonus Bramble pushes in.
@export var root_director: PhaseBRootDirector
## The persistent Vine body. Optional: without it the Cane resolves through its
## authored sector exactly as it always has, for every build that lacks Vine.
@export var vine_whip: PhaseBVineWhip

@export_group("Sporulation")
## Spore an enemy standing on owned Green gains per second before the Sporulation
## line adds to it. Every Spore radius below is authored in pixels: the design doc
## states them in metres at 1 m = 20 px, which is the scale the Briar Pod perimeter
## and the Seed burst already work at.
@export_range(0.0, 1.0, 0.005) var sporulation_per_second := 0.05
## Share of its own maximum health an Overgrown enemy loses per second, which kills
## it in five. Applied to every role alike - there is no boss cap and no elite
## resistance, because the gate on this path is reaching 100% Spore and not the
## damage that follows it. Set to compete with how fast Bloom and Pruning clear a
## mob: a completed infection has to be worth the time it took to land.
@export_range(0.0, 1.0, 0.005) var overgrown_max_health_damage_per_second := 0.25
## Seconds between ticks of that damage. Chip damage on a clock rather than a
## per-frame drain, so a damage number is readable when it appears.
@export_range(0.05, 3.0, 0.05) var overgrown_damage_interval_seconds := 0.5
## Spore an Overgrown enemy pushes into everything around it every second while it
## is dying. Over its four-second lethal phase this is 40% to anything that stays in
## range, which the death burst then finishes. Deliberately NOT amplified by Root
## Potency: the aura and the burst are the self-propagating half of the outbreak, and
## multiplying the loop's own feedback term makes it impossible to tune.
@export_range(0.0, 1.0, 0.01) var overgrown_contagion_spore_per_second := 0.10
## Reach of that aura.
@export_range(8.0, 320.0, 2.0) var overgrown_contagion_radius_pixels := 60.0
## Spore the death of an Overgrown enemy applies to everything near the corpse. Flat
## for the same reason the aura is.
@export_range(0.0, 1.0, 0.01) var overgrown_burst_spore := 0.60
## Reach of that burst. 3 m in the design doc.
@export_range(8.0, 320.0, 2.0) var overgrown_burst_radius_pixels := 80.0

## Share of its own maximum health an elite loses to a Fungal Collapse instead of
## dying outright, and the same for a boss. Collapse cashes an infection in at once
## against ordinary mobs; against the things a run is supposed to fight for a while
## it pays out as a large hit and an Overgrown status rather than a delete.
@export_range(0.0, 1.0, 0.01) var fungal_collapse_elite_health_share := 0.50
@export_range(0.0, 1.0, 0.01) var fungal_collapse_boss_health_share := 0.15
## How far apart two enemies can stand and still count as the same cluster when a
## Germination Season looks for somewhere worth opening.
@export_range(8.0, 400.0, 2.0) var infection_cluster_radius_pixels := 70.0

@export_group("Fruiting Bodies")
## Fruiting Bodies alive at once. The design doc's cap of 20 is the pool itself, so
## no counter can drift away from the number of colonies that actually exist.
@export_range(1, 120, 1) var fruiting_body_pool_size := 20
## Seconds between one colony's Spore clouds.
@export_range(0.5, 30.0, 0.5) var fruiting_body_cloud_interval_seconds := 3.0
## Clouds a colony releases before it ruptures.
@export_range(1, 12, 1) var fruiting_body_clouds := 3
## Spore one cloud applies to everything inside it.
@export_range(0.0, 1.0, 0.01) var fruiting_body_cloud_spore := 0.30
## Reach of a cloud. 2.5 m in the design doc.
@export_range(8.0, 320.0, 2.0) var fruiting_body_cloud_radius_pixels := 60.0
## Spore the rupture applies.
@export_range(0.0, 1.0, 0.01) var fruiting_body_rupture_spore := 0.75
## Reach of the rupture. 3.5 m in the design doc.
@export_range(8.0, 320.0, 2.0) var fruiting_body_rupture_radius_pixels := 80.0

@export_group("Damage Numbers")
## Damage at or above which a hit counts as important, and survives the Important
## Only setting. Priced as an ability landing rather than a tick: the point of the
## setting is to drop the stream of small numbers and keep the ones that mean
## something happened.
@export_range(0.0, 500.0, 1.0) var important_damage_number_threshold := 25.0

@export_group("Elite Modifiers")
## Chance an eligible spawn carries a rule change, before run pressure raises it.
## Zero until the run is far enough in that the player has a build to change the
## rules of: a modifier met before that is only an unexplained stat line.
@export_range(0.0, 1.0, 0.01) var elite_modifier_base_chance := 0.0
## Chance at full run pressure. The wave director raises the live value between the
## two as the run escalates, which is the doc's "begin introducing more dangerous
## elites" expressed as a dial rather than a second schedule.
@export_range(0.0, 1.0, 0.01) var elite_modifier_final_chance := 0.85
## Roles other than the Elite that may carry a modifier once the run is escalating.
## Late specialists qualify; the early body of a pack deliberately never does.
@export var modifier_eligible_late_roles := PackedInt32Array([9, 10, 11])
## Health per second a Regenerative elite recovers while the player has left it be.
@export_range(0.0, 200.0, 0.5) var regenerative_health_per_second := 9.0
## Seconds a Regenerative elite is stopped from healing by one hit from the player.
@export_range(0.05, 10.0, 0.05) var regenerative_block_seconds := 2.2
## Arena pixels a Blighted elite travels between the stamps that sour its wake.
@export_range(2.0, 200.0, 1.0) var blighted_trail_spacing_pixels := 18.0
## Strength of one of those stamps, on the same scale a Corruptor's action uses.
@export_range(0.0, 4.0, 0.05) var blighted_trail_strength := 0.55
## Radius multiplier of a Disruptive elite's maturity suppression.
@export_range(0.1, 8.0, 0.05) var disruptive_radius_multiplier := 2.4
## Maturity suppression per second applied by a Disruptive elite standing on Green.
@export_range(0.0, 4.0, 0.05) var disruptive_suppression_per_second := 0.9
## Damage a Volatile elite deals to everything near where it died.
@export_range(0.0, 400.0, 1.0) var volatile_detonation_damage := 46.0
## Radius of that detonation in arena pixels.
@export_range(4.0, 400.0, 1.0) var volatile_detonation_radius := 74.0
## Erosion the detonation inflicts on the Green it dies on, so a Volatile death
## costs the player ground as well as answering their kill with damage.
@export_range(0.0, 4.0, 0.05) var volatile_territory_damage := 1.3
## What each uninterrupted action multiplies the next one by for a Ravenous elite.
@export_range(1.0, 2.0, 0.01) var ravenous_escalation := 1.16
## Ceiling on that, as a multiple of the elite's base territory strength.
@export_range(1.0, 20.0, 0.5) var ravenous_escalation_cap := 5.0

@export_group("Enemy Profiles")
## Profile copied into each newly spawned Hunter.
@export var hunter_profile: PhaseBEnemyProfile
## Profile copied into each newly spawned Grazer.
@export var grazer_profile: PhaseBEnemyProfile
## Profile copied into each newly spawned elite Rootbreaker.
@export var elite_profile: PhaseBEnemyProfile
## Profile copied into each newly spawned Burrower boss.
@export var boss_profile: PhaseBEnemyProfile
## Profile copied into each newly spawned catalyst-hunting Saboteur.
@export var saboteur_profile: PhaseBEnemyProfile
## Profile copied into each newly spawned territory-converting Corruptor.
@export var corruptor_profile: PhaseBEnemyProfile
## Profile copied into each newly spawned hostile-Core-building Colonizer.
@export var colonizer_profile: PhaseBEnemyProfile
## Profile copied into each newly spawned maturity-suppressing Warden.
@export var warden_profile: PhaseBEnemyProfile
## Profile copied into each stationary hostile Colony Core created by Colonizers.
@export var colony_core_profile: PhaseBEnemyProfile
## Late specialist: large, slow, eats a lot of Green, and cannot be shoved.
@export var heavy_grazer_profile: PhaseBEnemyProfile
## Late specialist: a fast Hunter that crosses Bramble before it can take hold.
@export var rusher_profile: PhaseBEnemyProfile
## Late specialist: a Corruptor whose conversion accelerates while it is ignored.
@export var siege_corruptor_profile: PhaseBEnemyProfile
## How far a colony core may be nudged to find ground it can actually be fought on. A
## core inside a wall cannot be damaged from any direction, so beyond this the placement
## is refused outright rather than allowed to strand the run.
@export_range(0.0, 240.0, 4.0) var colony_core_relocation_pixels := 96.0

@export_group("Cane")
## Universal starting-weapon damage. Cane has no upgrade line of its own; Vine
## evolves these same sweeps through reach, damage, cadence, and the apical tip.
@export_range(1.0, 200.0, 1.0) var cane_damage := 24.0
## Seconds between automatic sweeps before Vine, relic, or temporary rate rules.
@export_range(0.05, 3.0, 0.01) var cane_cooldown_seconds := 0.72
## Radius of the base melee sweep measured from the player.
@export_range(20.0, 480.0, 2.0) var cane_reach_pixels := 92.0
## Fixed sector width. Base Cane centers on facing; Vine centers on the densest
## targetable sector at sweep start.
@export_range(10.0, 180.0, 1.0) var cane_arc_degrees := 90.0
## Presentation time for the visible left-to-right or right-to-left stroke.
@export_range(0.05, 0.8, 0.01) var cane_sweep_seconds := 0.20
## Outermost share of reach that counts as the Vine apical zone.
@export_range(0.05, 0.75, 0.01) var cane_apical_fraction := 0.25

@export_group("Combat Audio")
## Audio stream played once at the start of every Cane sweep.
@export var cane_swing_sfx: AudioStream
## Per-player Cane gain in decibels before the SFX bus output cap.
@export_range(-40.0, 6.0, 0.5) var cane_sfx_volume_db := -6.0
## Audio stream played for each collected XP circle.
@export var xp_collect_sfx: AudioStream
## Per-voice XP collection gain in decibels before the SFX bus output cap.
@export_range(-40.0, 6.0, 0.5) var xp_collect_sfx_volume_db := -6.0206
## Audio stream played when a Seed germinates or a Bloom detonates.
@export var plant_explosion_sfx: AudioStream
## Per-player plant-explosion gain in decibels before the SFX bus output cap.
@export_range(-40.0, 6.0, 0.5) var plant_explosion_sfx_volume_db := -6.0206
## Semitones added for each consecutive XP circle collected within the reset window.
@export_range(0.0, 4.0, 0.25) var xp_collect_pitch_step_semitones := 1.0
## Highest pitch-scale multiplier allowed for a rapid XP collection chain.
@export_range(1.0, 4.0, 0.05) var xp_collect_max_pitch_scale := 2.0
## Lowest and highest pitch one plant explosion may play at. The same sample fired
## at the same pitch several times a second is what makes a good effect grating, so
## every detonation is detuned a little. Kept narrow on purpose: wide enough that
## repeats stop sounding machine-stamped, narrow enough that no single blast reads
## as a different weapon.
@export_range(0.5, 1.0, 0.01) var explosion_minimum_pitch_scale := 0.90
@export_range(1.0, 2.0, 0.01) var explosion_maximum_pitch_scale := 1.12
## Seconds without an XP pickup before the ascending collection pitch resets.
@export_range(0.1, 3.0, 0.05) var xp_collect_pitch_reset_seconds := 1.0

@export_group("Combat Feedback")
## Seconds an enemy remains brightly flashed after taking damage.
@export_range(0.02, 0.5, 0.01) var enemy_hit_flash_seconds := 0.12
## Seconds a floating damage number remains visible.
@export_range(0.1, 2.0, 0.05) var damage_number_lifetime_seconds := 0.70
## Upward movement speed of floating damage numbers in pixels per second.
@export_range(0.0, 160.0, 1.0) var damage_number_rise_speed_pixels_per_second := 42.0
## Point size a damage number renders at. Each number remembers the size it was
## spawned with, so varying this per hit -- a larger one for a critical, say -- costs
## nothing beyond one extra glyph cache the first time that size is drawn.
@export_range(8, 48, 1) var damage_number_font_size := 14
## Point size a critical hit's number renders at. Both sizes come out of the same
## baked strip, so a second size is free rather than a second glyph cache.
@export_range(8, 64, 1) var damage_number_critical_font_size := 26
## Colour a critical's number is drawn in, replacing the damage source's own.
##
## Every source colour in _get_damage_feedback_color sits in the same yellow-green
## to warm-orange band -- Bloom is already a soft gold and Fruit a soft orange -- so
## the usual gold critical would read as another source rather than as a critical.
## This is deliberately hotter and far more saturated than any of them, which is
## what carries the distinction alongside the larger size. The enemy's hit flash
## keeps the source colour: only the number changes.
@export var damage_number_critical_color := Color("ffc21f")
## How long ordinary damage on one enemy accumulates before it is shown as a single
## number. Zero shows every hit separately, as before.
##
## A Fruit release lands several overlapping areas on the same crowd, so one enemy
## can take five or more hits in a frame and each was spawning its own number: a
## thousand of them a frame competing for a hundred and sixty slots, most overwritten
## before they were ever drawn. Merging them is both cheaper and, by the usual
## reading, better feedback -- five small numbers read as chip damage where one total
## reads as a hit.
##
## Criticals are excluded from this deliberately. They are the hit worth reading on
## its own, they are the only source in the game that can crit, and they are rare
## enough per frame to cost nothing.
@export_range(0.0, 0.5, 0.01) var damage_number_merge_seconds := 0.10

## Exact running totals of damage applied and damage shown, for the probe that
## proves merging never loses any. Off in play: merging is arithmetic, and
## arithmetic can drop things in ways no frame-time measurement would catch, so the
## accounting exists rather than the assurance.
var debug_damage_accounting := false
var debug_damage_applied_total := 0.0
var debug_damage_number_total := 0.0

## Where the baked digit strip lives, and the point size it was baked at. The two
## must agree with tools/bake_damage_digit_atlas.gd or the numbers come out the
## wrong size.
const DAMAGE_DIGIT_ATLAS_PATH := "res://assets/ui/damage_digits.png"
const DAMAGE_DIGIT_METRICS_PATH := "res://assets/ui/damage_digits.json"

@export_group("Bramble Territory")
## Base thorn damage per tick against an enemy that has only just stepped onto Green.
## Thorn damage is deliberately a fixed, modest chip effect with no upgrade line
## behind it: Bramble controls enemies, and its Evolutions turn that control into
## damage.
@export_range(0.0, 100.0, 0.5) var bramble_contact_damage := 0.18
## Seconds between repeated thorn-damage ticks while an enemy stands on Green.
@export_range(0.05, 3.0, 0.05) var bramble_damage_interval_seconds := 0.45
## Fraction of an enemy's maximum health added to each thorn tick, so chip damage
## still registers against late-game health pools. No upgrade line raises it.
@export_range(0.0, 0.2, 0.001) var bramble_max_health_damage_fraction := 0.0005
## Thorn-damage multiplier reached once an enemy is fully Entangled. Chip damage
## still rises with Entanglement, but a crossing enemy must never be killed by it.
@export_range(1.0, 12.0, 0.05) var bramble_entangled_damage_multiplier := 3.00
## Entanglement gained per second of contact before the Ensnare Rate line applies.
@export_range(0.01, 2.0, 0.01) var bramble_entanglement_per_second := 0.20
## Entanglement shed per second once an enemy leaves Bramble-covered ground.
@export_range(0.0, 4.0, 0.01) var bramble_entanglement_decay_per_second := 0.30
## Extra thorn damage supplied by standing in a fully developed frontier hedge.
@export_range(0.0, 4.0, 0.05) var bramble_frontier_damage_bonus := 0.60
## Extra Entanglement rate supplied by a fully developed frontier hedge.
@export_range(0.0, 4.0, 0.05) var bramble_frontier_ensnare_bonus := 0.75
## One-off thorn damage dealt the moment an enemy crosses an established hedge.
@export_range(0.0, 100.0, 0.5) var bramble_frontier_crossing_damage := 1.0
## Seconds before the same enemy can be hit by crossing a hedge again.
@export_range(0.0, 10.0, 0.05) var bramble_frontier_crossing_cooldown_seconds := 2.00
## Seconds an individual enemy must wait before Bramble may repel it again.
@export_range(0.0, 10.0, 0.05) var bramble_repulsion_cooldown_seconds := 1.50
## Pixels each repulsion step advances while testing that the shove stays in bounds.
@export_range(1.0, 32.0, 1.0) var bramble_repulsion_step_pixels := 4.0
## Seconds a repulsion shove takes to travel its distance. The enemy slides out
## over this window and eases to a stop, so the pulse reads as a shove rather than
## a teleport.
@export_range(0.05, 2.0, 0.01) var bramble_repulsion_seconds := 0.28
## Radius in arena pixels within which co-attackers reinforce one Bramble section.
@export_range(0.0, 240.0, 4.0) var bramble_horde_radius_pixels := 48.0
## Extra thorn damage per nearby enemy also standing in the same Bramble section.
@export_range(0.0, 1.0, 0.01) var bramble_horde_damage_per_attacker := 0.08
## Highest total horde bonus one Bramble section may reach regardless of crowd size.
@export_range(0.0, 4.0, 0.05) var bramble_horde_damage_maximum_bonus := 0.60
## Seconds between recounts of how many enemies crowd each Bramble section.
@export_range(0.05, 2.0, 0.05) var bramble_horde_refresh_seconds := 0.25

@export_group("Old Growth")
## Entanglement an enemy must reach on Mature ground before the Root Network erupts.
@export_range(0.0, 1.0, 0.01) var old_growth_eruption_entanglement := 0.70
## Base damage of one root eruption before Age scaling. Evolutions are where
## Bramble's control turns into damage, so this is authored, not upgraded.
@export_range(1.0, 400.0, 1.0) var old_growth_eruption_damage := 34.0
## Arena-pixel radius struck by one root eruption.
@export_range(8.0, 300.0, 1.0) var old_growth_eruption_radius_pixels := 74.0
## Extra eruption damage supplied by ground aged to the field's Age reference.
@export_range(0.0, 4.0, 0.05) var old_growth_eruption_age_bonus := 1.00
## Entanglement applied to everything caught in a root eruption.
@export_range(0.0, 1.0, 0.01) var old_growth_eruption_entanglement_gain := 0.25
## Seconds before the same enemy can trigger another eruption.
@export_range(0.05, 10.0, 0.05) var old_growth_eruption_cooldown_seconds := 1.30
## Eruptions a single kill cascade may travel through the Root Network.
@export_range(0, 8, 1) var old_growth_eruption_maximum_chain := 3
## Seconds between one eruption killing an enemy and the next erupting under it.
@export_range(0.0, 2.0, 0.01) var old_growth_eruption_chain_delay_seconds := 0.10
## Seconds a root eruption stays visible beneath an enemy the old ground has bitten.
@export_range(0.05, 3.0, 0.05) var old_growth_eruption_seconds := 0.45
## Root-eruption visuals preallocated for Old Growth cascades.
@export_range(4, 200, 1) var old_growth_eruption_pool_size := 48
## Audio stream played when the Root Network erupts under an Entangled enemy.
@export var old_growth_sfx: AudioStream
## Per-eruption Old Growth gain in decibels before the SFX bus output cap.
@export_range(-40.0, 6.0, 0.5) var old_growth_sfx_volume_db := -7.0
## Shortest gap between Old Growth cues, so a cascade of eruptions in one frame
## reads as a single swell instead of stacking one voice per eruption.
@export_range(0.0, 1.0, 0.01) var old_growth_sfx_retrigger_seconds := 0.09
## Half-width in arena pixels used to detect contact with a Green or Briar Pod boundary.
@export_range(2.0, 40.0, 1.0) var bramble_frontier_band_pixels := 12.0
## Number of temporary Briar Pod boundaries preallocated for the Spore/Bramble evolution.
@export_range(1, 40, 1) var briar_pod_pool_size := 12

@export_group("Briar Traps")
## Briar Traps preallocated for the Bloom/Bramble evolution's minefields.
@export_range(1, 120, 1) var briar_trap_pool_size := 32
## Fraction of a trap's blast radius within which an enemy sets it off.
@export_range(0.05, 1.0, 0.05) var briar_trap_trigger_fraction := 0.55
## Multiple of a trap's blast radius within which it sets off neighbouring traps.
@export_range(0.5, 4.0, 0.05) var briar_trap_chain_fraction := 1.60
## Seconds between a trap detonating and the traps it lit going off, which paces the cascade.
@export_range(0.0, 1.0, 0.01) var briar_trap_chain_delay_seconds := 0.09
## Traps one cascade may travel through before it stops chaining.
@export_range(0, 20, 1) var briar_trap_maximum_chain_depth := 6
## Blast and trigger scale of a Briar Heart from the Briar Payload line.
@export_range(1.0, 4.0, 0.05) var briar_heart_scale := 1.55
## Times a Briar Heart detonates before it is spent.
@export_range(1, 8, 1) var briar_heart_detonations := 3
## Seconds a Briar Heart waits between its own detonations.
@export_range(0.05, 3.0, 0.05) var briar_heart_recharge_seconds := 0.55

@export_group("Object Pools")
## Enemy-state objects preallocated when this node enters the scene tree.
@export_range(20, 400, 1) var enemy_pool_size := 160
## Generic projectile-state objects retained for stress probes and secondary effects;
## the Cane never allocates or fires one.
@export_range(10, 240, 1) var projectile_pool_size := 96
## XP pickup-state objects preallocated when this node enters the scene tree.
@export_range(20, 400, 1) var pickup_pool_size := 180
## Spawn limit for simultaneously active enemies; keep at or below the enemy pool size.
@export_range(10, 300, 1) var maximum_active_enemies := 130

@export_group("Rendering Performance")
## Above this population, cosmetic battlefield detail is reduced while role colours,
## hit feedback, status effects, and major-enemy telegraphs remain.
## Active enemies at which ornamental detail is dropped from pickups and
## projectiles. It no longer touches enemy bodies: those are drawn from baked art,
## so density never costs the player the ability to tell what is coming at them.
@export_range(20, 300, 1) var crowd_visual_lod_enemy_threshold := 80
## Padding around a baked role's art, in pixels. The art reaches past the body
## radius -- a Grazer's spines, a Rusher's nose and speed streaks -- so the canvas
## has to be wider than the enemy it draws.
@export_range(8.0, 128.0, 1.0) var enemy_art_bake_padding := 26.0
## Per-enemy art variants baked per role. The Heavy Grazer rotates its plating by
## its own id, so baking a handful keeps that variation instead of making every
## one of them identical.
@export_range(1, 16, 1) var enemy_art_variants := 6

@export_group("Enemy Navigation")
## Seconds between navigation-field rebuild checks and direct-path visibility refreshes.
@export_range(0.05, 1.0, 0.01) var navigation_refresh_seconds := 0.18
## Territory cells combined per navigation cell; higher values are cheaper but less precise.
@export_range(1, 4, 1) var navigation_grid_divisor := 2
## Fraction of visual body radius used by each enemy's diamond collision proxy.
@export_range(0.3, 1.0, 0.01) var enemy_collision_radius_multiplier := 0.50
## Pixel clearance used to mark navigation cells walkable for ordinary enemies.
@export_range(1.0, 30.0, 0.5) var navigation_small_clearance_pixels := 10.0
## Pixel clearance used by profiles with Use Boss Navigation enabled.
@export_range(1.0, 40.0, 0.5) var navigation_boss_clearance_pixels := 16.0

var simulation_paused := false

var _enemies: Array[EnemyState] = []
var _projectiles: Array[ProjectileState] = []
var _pickups: Array[PickupState] = []
var _damage_numbers: Array[DamageNumberState] = []
var _bramble_zones: Array[BrambleZoneState] = []
var _active_enemy_count := 0
var _next_enemy_id := 1
## Enemy id to its slot in `_enemies`. A cache in front of the linear search in
## `_find_enemy`, never the authority for what is where -- see that function.
var _enemy_slot_by_id := {}
## Slot `_get_inactive_enemy` last handed out, so `spawn_enemy` can register the
## new id without searching the pool for the object it was just given.
var _last_inactive_enemy_slot := -1
var _spawn_sequence := 0
var _cane_remaining := 0.0
var _cane_damage_multiplier := 1.0
var _cane_cooldown_multiplier := 1.0
var _cane_reach_multiplier := 1.0
var _cane_apical_damage_bonus := 0.0
var _cane_auto_targets := false
var _cane_next_left_to_right := true
var _cane_visual_remaining := 0.0
var _cane_visual_origin := Vector2.ZERO
var _cane_visual_facing := Vector2.RIGHT
var _cane_visual_left_to_right := true
var _cane_visual_reach := 0.0
var _cane_visual_path := PackedVector2Array()
var _cane_route_cache: Dictionary = {}
## The sweep the rope is currently resolving: damage, apical bonus, and whether it
## was a bonus stroke, held because the hits arrive over several frames.
var _vine_sweep_active := false
var _vine_sweep_damage := 0.0
var _vine_sweep_is_bonus := false
var _vine_sweep_facing := Vector2.RIGHT
var _vine_sweep_left_to_right := true
var _vine_sweep_reach := 0.0
var _vine_sweep_origin := Vector2.ZERO
var _vine_sweep_hits := 0
var _cane_sweep_count := 0
var _heartwood_rank := 0
var _heartwood_progress := 0
var _heartwood_echo_remaining := 0.0
var _heartwood_echo_facing := Vector2.RIGHT
var _heartwood_echo_left_to_right := true
var _next_cane_cooldown_multiplier := 1.0
var _cane_apical_fraction_bonus := 0.0
var _temporary_attack_multiplier := 1.0
var _temporary_attack_remaining := 0.0
## The enemy that died most recently, readable for the duration of the kill signal
## so a relic can tell whose corpse it is looking at.
var _last_killed_enemy_id := -1
## Baked role art, keyed by role * enemy_art_variants + variant. Empty until the
## bake completes, and left empty on a driver that cannot render to a viewport.
var _enemy_art := {}
## Body radius each role was baked at, so the quad can be scaled to the enemy's
## actual radius rather than assuming they match.
var _enemy_art_radius := {}
var _enemy_art_ready := false
var _enemy_art_baking := false
var _rampart_center := Vector2(-1.0, -1.0)
var _rampart_radius := 0.0
var _rampart_ensnare_bonus := 0.0
var _rampart_repulsion_multiplier := 1.0
var _sporulation_enabled := false
var _sporulation_rate_multiplier := 1.0
var _fruiting_bodies: Array[FruitingBodyState] = []
var _fruiting_body_sequence := 0
var _bramble_enabled := false
var _bramble_slow_fraction := 0.0
var _bramble_repulsion_pixels := 0.0
var _bramble_root_seconds := 0.0
var _bramble_root_immunity_seconds := 0.0
var _bramble_ensnare_multiplier := 1.0
var _root_network_bonus := 0.0
var _old_growth_enabled := false
var _bramble_horde_refresh_remaining := 0.0
var _bramble_attackers: Array[EnemyState] = []
var _root_eruptions: Array[RootEruptionState] = []
var _root_eruption_sequence := 0
var _briar_traps: Array[BriarTrapState] = []
var _briar_trap_sequence := 0
var _briar_payload_trigger_bonus := 0.0
var _briar_payload_chain_bonus := 0.0
var _briar_payload_entanglement := 0.0
var _briar_payload_heart_cadence := 0
var _ancient_fury_radius_bonus := 0.0
var _ancient_fury_entanglement := 0.0
var _ancient_fury_chain_damage_share := 0.0
var _ancient_fury_chains_enabled := false
var _ancient_fury_trigger_threshold := 1.0
var _ancient_fury_awakening_enemies := 0
var _ancient_fury_awakening_eruptions := 0
var _ancient_fury_awakening_cooldown := 10.0
var _ancient_fury_awakening_remaining := 0.0
var _pending_eruptions: Array[PendingEruptionState] = []
var _briar_heart_recharges: Array = []
var _ensnare_zones: Array = []
## Short-lived local multipliers created by contaminated Fruit trails. Like Ensnare
## zones, overlapping patches refresh/choose the strongest value instead of stacking.
var _spore_rate_zones: Array = []
var _mass_entanglement_elite_share := 0.5
var _mass_entanglement_boss_share := 0.2
var _enemy_health_scale := 1.0
var _enemy_damage_scale := 1.0
var _enemy_territory_erosion_scale := 1.0
var _enemy_spawn_wave_number := 1
var _enemy_xp_growth_per_wave := 0.10
var _enemy_xp_minimum_bonus_per_wave := 1
var _navigation_width := 0
var _navigation_height := 0
var _navigation_cell_count := 0
var _navigation_small_target_index := -1
## Chance an eligible spawn carries a rule change, driven by the wave director.
var _elite_modifier_chance := 0.0
## A modifier pinned for the next eligible spawn, for tests and debug keys.
var _forced_elite_modifier := EliteModifier.NONE
var _navigation_boss_target_index := -1
var _navigation_catalyst_target_index := -1
var _navigation_catalyst_target_position := Vector2(-99999.0, -99999.0)
var _navigation_refresh_remaining := 0.0
var _navigation_small_walkable := PackedByteArray()
var _navigation_boss_walkable := PackedByteArray()
var _navigation_small_distances := PackedInt32Array()
var _navigation_boss_distances := PackedInt32Array()
var _navigation_catalyst_distances := PackedInt32Array()
var _navigation_queue := PackedInt32Array()
var _cane_audio: AudioStreamPlayer
var _plant_explosion_audio: AudioStreamPlayer
var _old_growth_audio: AudioStreamPlayer
var _old_growth_sfx_play_count := 0
var _old_growth_sfx_retrigger_remaining := 0.0
var _xp_collect_audio_voices: Array[AudioStreamPlayer] = []
var _cane_sfx_play_count := 0
var _plant_explosion_sfx_play_count := 0
var _xp_collect_sfx_play_count := 0
var _xp_collect_voice_cursor := 0
var _xp_collect_chain_count := 0
var _xp_collect_pitch_reset_remaining := 0.0
var _last_xp_collect_pitch_scale := 1.0
var _last_explosion_pitch_scale := 1.0
## Presentation only, and deliberately its own generator: pitch must never pull
## from a stream any gameplay draw depends on, or a replayed run would diverge
## because a sound played.
var _sfx_random := RandomNumberGenerator.new()
var _damage_number_sequence := 0
## Lowest slot in `_damage_numbers` that might be free. Everything below it is
## active, so the search for a free slot can start here instead of at zero. It is
## lowered whenever a slot expires, which keeps the invariant true.
var _damage_number_free_cursor := 0
var _damage_number_font: Font
## The ten digits of Beholden Regular on one strip, baked by
## tools/bake_damage_digit_atlas.gd. Damage numbers are drawn as quads out of this
## rather than as text, because draw_string re-shapes its string on every call and a
## screenful of numbers was the largest single cost in the rendered frame. Null if
## the asset is missing, in which case the text path below still works.
var _damage_digit_atlas: Texture2D
## One digit's cell in that strip, the point size it was baked at, and how far the
## pen moves after each digit. Read from the metrics written beside the texture, so
## a re-bake at a different size needs no code change.
var _damage_digit_cell := Vector2.ZERO
var _damage_digit_bake_size := 64.0
var _damage_digit_advances := PackedFloat32Array()


func _ready() -> void:
	assert(player != null, "PhaseBCombatDirector requires PhaseBPlayer")
	assert(territory_field != null, "PhaseBCombatDirector requires TerritoryField")
	assert(overlay != null, "PhaseBCombatDirector requires TerritoryPrototypeOverlay")
	assert(audio_settings != null, "PhaseBCombatDirector requires PhaseBAudioSettings")
	assert(hunter_profile != null, "PhaseBCombatDirector requires a Hunter profile")
	assert(grazer_profile != null, "PhaseBCombatDirector requires a Grazer profile")
	assert(elite_profile != null, "PhaseBCombatDirector requires an Elite profile")
	assert(boss_profile != null, "PhaseBCombatDirector requires a Boss profile")
	assert(saboteur_profile != null, "PhaseBCombatDirector requires a Saboteur profile")
	_sfx_random.randomize()
	# Started rather than awaited: the run must not wait on a render pass to begin,
	# and until it finishes the art draws directly exactly as it always did.
	_start_enemy_art_bake()
	assert(corruptor_profile != null, "PhaseBCombatDirector requires a Corruptor profile")
	assert(colonizer_profile != null, "PhaseBCombatDirector requires a Colonizer profile")
	assert(warden_profile != null, "PhaseBCombatDirector requires a Warden profile")
	assert(colony_core_profile != null, "PhaseBCombatDirector requires a Colony Core profile")
	assert(
		hunter_profile.role == PhaseBEnemyProfile.Role.HUNTER,
		"The Hunter profile must identify itself as HUNTER"
	)
	assert(
		grazer_profile.role == PhaseBEnemyProfile.Role.GRAZER,
		"The Grazer profile must identify itself as GRAZER"
	)
	assert(
		elite_profile.role == PhaseBEnemyProfile.Role.ELITE,
		"The Elite profile must identify itself as ELITE"
	)
	assert(
		boss_profile.role == PhaseBEnemyProfile.Role.BOSS,
		"The Boss profile must identify itself as BOSS"
	)
	assert(
		saboteur_profile.role == PhaseBEnemyProfile.Role.SABOTEUR,
		"The Saboteur profile must identify itself as SABOTEUR"
	)
	assert(
		corruptor_profile.role == PhaseBEnemyProfile.Role.CORRUPTOR,
		"The Corruptor profile must identify itself as CORRUPTOR"
	)
	assert(
		colonizer_profile.role == PhaseBEnemyProfile.Role.COLONIZER,
		"The Colonizer profile must identify itself as COLONIZER"
	)
	assert(
		warden_profile.role == PhaseBEnemyProfile.Role.WARDEN,
		"The Warden profile must identify itself as WARDEN"
	)
	assert(
		colony_core_profile.role == PhaseBEnemyProfile.Role.COLONY_CORE,
		"The Colony Core profile must identify itself as COLONY_CORE"
	)
	_configure_pools()
	_configure_audio()
	_configure_navigation()
	_damage_number_font = ThemeDB.fallback_font
	_load_damage_digit_atlas()
	reset_combat()


func _process(delta: float) -> void:
	if simulation_paused:
		return
	simulate_step(delta)


func simulate_step(delta: float) -> void:
	_update_bramble_horde_pressure(delta)
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_CANE_TOTAL)
	_update_cane(delta)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_CANE_TOTAL)
	_old_growth_sfx_retrigger_remaining = maxf(
		0.0,
		_old_growth_sfx_retrigger_remaining - delta
	)
	_update_briar_pods(delta)
	_update_briar_traps(delta)
	_update_fruiting_bodies(delta)
	_update_forest_awakening(delta)
	_update_ensnare_zones(delta)
	_update_spore_rate_zones(delta)
	_update_pending_eruptions(delta)
	_update_root_eruptions(delta)
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_ENEMY_MANAGER_TOTAL)
	_update_enemies(delta)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_ENEMY_MANAGER_TOTAL)
	_update_pending_damage_numbers(delta)
	_update_damage_numbers(delta)
	_update_projectiles(delta)
	_update_xp_collect_pitch(delta)
	_update_pickups(delta)
	queue_redraw()


func _draw() -> void:
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_COMBAT_DRAW)
	var use_crowd_lod := _active_enemy_count >= crowd_visual_lod_enemy_threshold
	_draw_cane_sweep()
	for zone in _bramble_zones:
		if zone.active:
			_draw_briar_pod(zone)

	for trap in _briar_traps:
		if trap.active:
			_draw_briar_trap(trap)

	for body in _fruiting_bodies:
		if body.active:
			_draw_fruiting_body(body)

	for eruption in _root_eruptions:
		if eruption.active:
			_draw_root_eruption(eruption)

	for pickup in _pickups:
		if not pickup.active:
			continue
		var pulse := 1.0 + sin(pickup.age * 7.0) * 0.12
		if not use_crowd_lod:
			draw_circle(pickup.position, 5.0 * pulse, Color(0.42, 0.86, 1.0, 0.22))
		draw_circle(pickup.position, 2.8 * pulse, Color("7be8ff"))
		if not use_crowd_lod:
			draw_line(
				pickup.position + Vector2(-4.0, 0.0),
				pickup.position + Vector2(4.0, 0.0),
				Color("d5faff"),
				1.0,
				true
			)

	for projectile in _projectiles:
		if not projectile.active:
			continue
		var direction := projectile.velocity.normalized()
		draw_line(
			projectile.position - direction * 11.0,
			projectile.position + direction * 3.0,
			Color("d9ff9c"),
			2.4,
			true
		)
		if not use_crowd_lod:
			draw_circle(projectile.position + direction * 3.0, 2.2, Color("efffc9"))

	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_ENEMY_DRAW)
	for enemy in _enemies:
		if not enemy.active:
			continue
		if enemy.bramble_root_remaining > 0.0:
			if use_crowd_lod:
				_draw_enemy_root_hold_lod(enemy)
			else:
				_draw_enemy_root_hold(enemy)
		# The baked quad is the art, so there is no longer a density at which the
		# enemy stops looking like itself. The direct path stays as the fallback for
		# a driver that could not bake, and for the few enemies whose art is not a
		# static shape at all.
		if not _enemy_art_ready or _enemy_requires_full_detail(enemy):
			_draw_enemy(self, enemy)
		elif not _draw_enemy_baked(enemy):
			_draw_enemy(self, enemy)

	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_ENEMY_DRAW)

	for damage_number in _damage_numbers:
		if damage_number.active:
			_draw_damage_number(damage_number)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_COMBAT_DRAW)


func set_temporary_attack_rate_multiplier(multiplier: float, seconds: float) -> void:
	# An emergency buff, not a permanent stat: it expires on its own timer.
	_temporary_attack_multiplier = clampf(multiplier, 0.05, 4.0)
	_temporary_attack_remaining = maxf(0.0, seconds)


func set_rampart(
	center: Vector2,
	radius: float,
	ensnare_bonus: float,
	repulsion_multiplier: float
) -> void:
	_rampart_center = center
	_rampart_radius = maxf(0.0, radius)
	_rampart_ensnare_bonus = maxf(0.0, ensnare_bonus)
	_rampart_repulsion_multiplier = clampf(repulsion_multiplier, 0.05, 1.0)


func clear_rampart() -> void:
	_rampart_center = Vector2(-1.0, -1.0)
	_rampart_radius = 0.0
	_rampart_ensnare_bonus = 0.0
	_rampart_repulsion_multiplier = 1.0


func is_in_rampart(local_position: Vector2) -> bool:
	return (
		_rampart_radius > 0.0
		and _rampart_center.x >= 0.0
		and local_position.distance_to(_rampart_center) <= _rampart_radius
	)


func spread_entanglement_from(
	center: Vector2,
	radius: float,
	amount: float,
	maximum_targets: int
) -> int:
	# Snare Vine: the nearest few enemies pick up part of the hold, capped, so a
	# dense crowd cannot be entangled wholesale by one root.
	if amount <= 0.0 or maximum_targets <= 0:
		return 0
	var nearby: Array[EnemyState] = []
	for enemy in _enemies:
		if not enemy.active:
			continue
		var distance := enemy.position.distance_to(center)
		if distance > radius or distance <= 0.5:
			continue
		nearby.append(enemy)
	if nearby.is_empty():
		return 0
	nearby.sort_custom(
		func(first: EnemyState, second: EnemyState) -> bool:
			return (
				first.position.distance_squared_to(center)
				< second.position.distance_squared_to(center)
			)
	)
	var spread := 0
	for index in range(mini(maximum_targets, nearby.size())):
		nearby[index].entanglement = clampf(
			nearby[index].entanglement + amount,
			0.0,
			1.0
		)
		spread += 1
	return spread


func raise_entanglement_floor(enemy_id: int, floor_value: float) -> bool:
	var enemy := _find_enemy(enemy_id)
	if enemy == null:
		return false
	if enemy.entanglement >= floor_value:
		return false
	enemy.entanglement = clampf(floor_value, 0.0, 1.0)
	return true


func interrupt_enemy(enemy_id: int) -> bool:
	# An interrupt stops whatever the enemy was doing this moment: its contact
	# swing and its territory action both go back on the clock.
	var enemy := _find_enemy(enemy_id)
	if enemy == null:
		return false
	enemy.contact_remaining = maxf(enemy.contact_remaining, enemy.contact_interval)
	enemy.territory_action_remaining = maxf(
		enemy.territory_action_remaining,
		enemy.territory_action_interval
	)
	enemy.hit_flash_remaining = maxf(enemy.hit_flash_remaining, 0.12)
	return true


func is_enemy_resistant(enemy_id: int) -> bool:
	# Elites and bosses resist crowd control that is meant for the horde.
	var enemy := _find_enemy(enemy_id)
	if enemy == null:
		return false
	return enemy.role == EnemyRole.ELITE or enemy.role == EnemyRole.BOSS


func get_enemy_maximum_health(enemy_id: int) -> float:
	var enemy := _find_enemy(enemy_id)
	if enemy == null:
		return 0.0
	return enemy.maximum_health


func _find_enemy(enemy_id: int) -> EnemyState:
	## Every by-id accessor on this class funnels through here, and there are
	## sixteen of them. As a linear scan that made a single hit resolution -- which
	## asks about the same enemy eight or ten times -- cost as much as a pass over
	## the whole crowd, and the Fruit and Thistle hit cascades were both dominated
	## by it.
	##
	## The map is a shortcut, never the authority. A slot is only accepted if it
	## still holds an active enemy with the id asked for, and anything else falls
	## through to the scan that was here before, so a stale or missing entry can
	## make this slower but cannot make it wrong.
	var slot: int = _enemy_slot_by_id.get(enemy_id, -1)
	if slot >= 0 and slot < _enemies.size():
		var mapped := _enemies[slot]
		if mapped.active and mapped.id == enemy_id:
			return mapped
	for enemy in _enemies:
		if enemy.active and enemy.id == enemy_id:
			PhaseBPerfCounters.count(PhaseBPerfCounters.COUNT_ENEMY_LOOKUP_FALLBACKS)
			return enemy
	return null


func reset_combat() -> void:
	_elite_modifier_chance = elite_modifier_base_chance
	_forced_elite_modifier = EliteModifier.NONE
	for enemy in _enemies:
		enemy.active = false
		enemy.state = EnemyStateKind.INACTIVE
		enemy.elite_modifier = EliteModifier.NONE
		enemy.territory_escalation = 1.0
		enemy.pending_number_damage = 0.0
		enemy.pending_number_remaining = 0.0
	for projectile in _projectiles:
		projectile.active = false
	for pickup in _pickups:
		pickup.active = false
	for damage_number in _damage_numbers:
		damage_number.active = false
	for zone in _bramble_zones:
		zone.active = false
	for eruption in _root_eruptions:
		eruption.active = false
	for trap in _briar_traps:
		trap.active = false
	for body in _fruiting_bodies:
		body.active = false
	for pending in _pending_eruptions:
		pending.active = false
	_briar_heart_recharges.clear()
	_ensnare_zones.clear()
	_spore_rate_zones.clear()
	_ancient_fury_awakening_remaining = 0.0
	_root_eruption_sequence = 0
	_briar_trap_sequence = 0
	_fruiting_body_sequence = 0
	_active_enemy_count = 0
	_enemy_slot_by_id.clear()
	_last_inactive_enemy_slot = -1
	_next_enemy_id = 1
	_spawn_sequence = 0
	_cane_remaining = 0.16
	_cane_next_left_to_right = true
	_cane_visual_remaining = 0.0
	_cane_visual_origin = Vector2.ZERO
	_cane_visual_facing = Vector2.RIGHT
	_cane_visual_left_to_right = true
	_cane_visual_reach = cane_reach_pixels
	_cane_sweep_count = 0
	_heartwood_progress = 0
	_heartwood_echo_remaining = 0.0
	_heartwood_echo_facing = Vector2.RIGHT
	_heartwood_echo_left_to_right = true
	_next_cane_cooldown_multiplier = 1.0
	_cane_apical_fraction_bonus = 0.0
	_bramble_horde_refresh_remaining = 0.0
	_bramble_attackers.clear()
	_cane_sfx_play_count = 0
	_plant_explosion_sfx_play_count = 0
	_old_growth_sfx_play_count = 0
	_old_growth_sfx_retrigger_remaining = 0.0
	_xp_collect_sfx_play_count = 0
	_xp_collect_voice_cursor = 0
	_xp_collect_chain_count = 0
	_xp_collect_pitch_reset_remaining = 0.0
	_last_xp_collect_pitch_scale = 1.0
	_damage_number_sequence = 0
	_damage_number_free_cursor = 0
	if _cane_audio != null:
		_cane_audio.stop()
	if _plant_explosion_audio != null:
		_plant_explosion_audio.stop()
	if _old_growth_audio != null:
		_old_growth_audio.stop()
	for xp_audio_voice in _xp_collect_audio_voices:
		xp_audio_voice.stop()
	_navigation_small_target_index = -1
	_navigation_boss_target_index = -1
	_navigation_catalyst_target_index = -1
	_navigation_catalyst_target_position = Vector2(-99999.0, -99999.0)
	_navigation_refresh_remaining = 0.0
	_navigation_small_distances.fill(-1)
	_navigation_boss_distances.fill(-1)
	_navigation_catalyst_distances.fill(-1)
	active_enemy_count_changed.emit(_active_enemy_count)
	queue_redraw()


func spawn_enemy(role: int, local_position: Vector2 = Vector2(-99999.0, -99999.0)) -> int:
	if _active_enemy_count >= maximum_active_enemies:
		return -1
	var enemy := _get_inactive_enemy()
	if enemy == null:
		return -1
	enemy.role = role
	_configure_enemy_stats(enemy)
	if local_position.x < -90000.0:
		local_position = _choose_spawn_position(enemy.collision_radius)
	if not _can_occupy_diamond(local_position, enemy.collision_radius):
		local_position = _choose_spawn_position(enemy.collision_radius)

	enemy.active = true
	enemy.state = EnemyStateKind.ADVANCING
	# The slot is about to carry a different enemy, so whatever id used to point at
	# it must stop doing so. Retiring the old key here is what keeps the map bounded
	# by the pool rather than by everything ever spawned.
	_enemy_slot_by_id.erase(enemy.id)
	enemy.id = _next_enemy_id
	_next_enemy_id += 1
	if _last_inactive_enemy_slot >= 0:
		_enemy_slot_by_id[enemy.id] = _last_inactive_enemy_slot
	enemy.position = local_position
	enemy.direct_path_clear = false
	enemy.path_check_remaining = (
		navigation_refresh_seconds * float(enemy.id % 11) / 11.0
	)
	enemy.contact_remaining = 0.0
	enemy.territory_action_remaining = _profile_for_role(role).first_territory_action_delay_seconds
	enemy.territory_actions_taken = 0
	enemy.hit_flash_remaining = 0.0
	enemy.hit_flash_color = Color.WHITE
	enemy.bramble_damage_remaining = 0.0
	enemy.bramble_repulsion_remaining = 0.0
	enemy.bramble_crossing_remaining = 0.0
	enemy.bramble_eruption_remaining = 0.0
	enemy.bramble_root_remaining = 0.0
	enemy.bramble_root_duration = 0.0
	enemy.bramble_root_immunity_remaining = 0.0
	enemy.knockback_direction = Vector2.ZERO
	enemy.knockback_remaining = 0.0
	enemy.knockback_speed = 0.0
	enemy.entanglement = 0.0
	enemy.suppression_remaining = 0.0
	enemy.suppression_share = 0.0
	enemy.spore = 0.0
	enemy.overgrown = false
	enemy.spore_damage_remaining = 0.0
	enemy.bramble_frontier_strength = 0.0
	enemy.bramble_ground_maturity = 0.0
	enemy.bramble_horde_count = 0
	enemy.was_on_bramble = false
	enemy.movement_speed_multiplier = 1.0
	enemy.territory_escalation = 1.0
	enemy.regeneration_block_remaining = 0.0
	enemy.blight_last_position = local_position
	enemy.elite_modifier = _roll_elite_modifier(role)
	if enemy.elite_modifier != EliteModifier.NONE:
		elite_modifier_assigned.emit(enemy.id, enemy.elite_modifier)
	if enemy.use_boss_navigation:
		_navigation_boss_target_index = -1
		_navigation_refresh_remaining = 0.0
	_active_enemy_count += 1
	active_enemy_count_changed.emit(_active_enemy_count)
	return enemy.id


func spawn_pack(role: int, count: int) -> int:
	var spawned := 0
	for _index in range(count):
		if spawn_enemy(role) == -1:
			break
		spawned += 1
	return spawned


class BlastReport:
	## What one radial attack actually did. Relics that key off a blast need more
	## than a hit count -- how many died, where, and how much damage was spent past
	## the health that was there -- and computing it inside the blast is the only
	## place those facts are still available.
	var hits := 0
	var kills := 0
	var kill_positions := PackedVector2Array()
	## Damage dealt beyond what the victims had left, already capped per victim by
	## role, which is what stops one boss hit filling an Overkill meter by itself.
	var overkill := 0.0


func damage_enemies_in_radius(
	center: Vector2,
	radius: float,
	damage: float,
	death_source: int,
	chain_depth: int = 0
) -> int:
	return blast_enemies_in_radius(center, radius, damage, death_source, chain_depth).hits


func blast_enemies_in_radius(
	center: Vector2,
	radius: float,
	damage: float,
	death_source: int,
	chain_depth: int = 0,
	normal_overkill_cap: float = 0.0,
	elite_overkill_cap: float = 0.0,
	boss_overkill_cap: float = 0.0
) -> BlastReport:
	var report := BlastReport.new()
	if PhaseBPerfCounters.enabled:
		PhaseBPerfCounters.count(PhaseBPerfCounters.COUNT_BLAST_CALLS)
		PhaseBPerfCounters.count(
			PhaseBPerfCounters.COUNT_BLAST_ENEMIES_WALKED, _enemies.size()
		)
	# Read once for the whole blast rather than per enemy. This loop runs for every
	# AoE in the game against the whole roster, and even an early-returning counter
	# call is not free at that rate -- taking the timestamps unconditionally here was
	# enough on its own to push a pairing over budget.
	var measuring := PhaseBPerfCounters.enabled
	for enemy in _enemies:
		if not enemy.active:
			continue
		var distance := enemy.position.distance_to(center)
		if distance > radius + enemy.radius:
			continue
		var sight_began := Time.get_ticks_usec() if measuring else 0
		var reachable := territory_field.is_growth_path_clear(center, enemy.position)
		if measuring:
			PhaseBPerfCounters.timer_add_since(
				PhaseBPerfCounters.TIMER_BLAST_LINE_OF_SIGHT, sight_began
			)
		if not reachable:
			continue
		var falloff := clampf(1.0 - distance / maxf(radius, 1.0), 0.0, 1.0)
		var applied := damage * lerpf(0.48, 1.0, falloff)
		var health_before := enemy.health
		var position_before := enemy.position
		var role := enemy.role
		var damage_began := Time.get_ticks_usec() if measuring else 0
		_damage_enemy(enemy, applied, death_source, chain_depth)
		if measuring:
			PhaseBPerfCounters.timer_add_since(
				PhaseBPerfCounters.TIMER_BLAST_DAMAGE, damage_began
			)
		report.hits += 1
		if enemy.active:
			continue
		report.kills += 1
		report.kill_positions.append(position_before)
		var excess := maxf(0.0, applied - health_before)
		var cap := normal_overkill_cap
		if role == EnemyRole.BOSS:
			cap = boss_overkill_cap
		elif role == EnemyRole.ELITE:
			cap = elite_overkill_cap
		if cap > 0.0:
			report.overkill += minf(excess, cap)
	return report


func get_target_position() -> Vector2:
	var player_position := player.get_arena_position()
	var best_position := Vector2(
		territory_field.tuning.arena_size.x * 0.69,
		territory_field.tuning.arena_size.y * 0.765
	)
	var best_score := INF
	for enemy in _enemies:
		if not enemy.active:
			continue
		var score := (
			enemy.position.distance_squared_to(player_position)
			* enemy.target_priority_multiplier
		)
		if score < best_score:
			best_score = score
			best_position = enemy.position
	return best_position


func get_active_enemy_count() -> int:
	return _active_enemy_count


func get_active_enemy_count_by_role(role: int) -> int:
	var count := 0
	for enemy in _enemies:
		if enemy.active and enemy.role == role:
			count += 1
	return count


func is_enemy_active(enemy_id: int) -> bool:
	return _find_enemy(enemy_id) != null


func get_enemy_position(enemy_id: int) -> Vector2:
	var enemy := _find_enemy(enemy_id)
	return enemy.position if enemy != null else Vector2(-99999.0, -99999.0)


func get_enemy_role(enemy_id: int) -> int:
	var enemy := _find_enemy(enemy_id)
	return enemy.role if enemy != null else -1


func get_enemy_health(enemy_id: int) -> float:
	var enemy := _find_enemy(enemy_id)
	return enemy.health if enemy != null else 0.0


func get_enemy_xp_value(enemy_id: int) -> int:
	var enemy := _find_enemy(enemy_id)
	return enemy.xp_value if enemy != null else 0


func get_last_killed_enemy_id() -> int:
	return _last_killed_enemy_id


func get_enemy_territory_erosion_scale(enemy_id: int) -> float:
	var enemy := _find_enemy(enemy_id)
	return enemy.territory_erosion_scale if enemy != null else 0.0


func get_enemy_territory_behavior(enemy_id: int) -> int:
	var enemy := _find_enemy(enemy_id)
	return enemy.territory_behavior if enemy != null else PhaseBEnemyProfile.TerritoryBehavior.NONE


func get_active_projectile_count() -> int:
	var count := 0
	for projectile in _projectiles:
		if projectile.active:
			count += 1
	return count


func get_active_pickup_count() -> int:
	var count := 0
	for pickup in _pickups:
		if pickup.active:
			count += 1
	return count


func get_active_damage_number_count() -> int:
	var count := 0
	for damage_number in _damage_numbers:
		if damage_number.active:
			count += 1
	return count


func get_enemy_hit_flash_remaining(enemy_id: int) -> float:
	var enemy := _find_enemy(enemy_id)
	return enemy.hit_flash_remaining if enemy != null else 0.0


func get_cane_sfx_play_count() -> int:
	return _cane_sfx_play_count


func get_cane_sweep_count() -> int:
	return _cane_sweep_count


func get_cane_reach() -> float:
	return cane_reach_pixels * _cane_reach_multiplier


func get_plant_explosion_sfx_play_count() -> int:
	return _plant_explosion_sfx_play_count


func get_old_growth_sfx_play_count() -> int:
	return _old_growth_sfx_play_count


func play_old_growth_sfx() -> void:
	# A cascade can fire several eruptions in one frame; the retrigger guard keeps
	# that a single swell rather than a stack of identical voices.
	if _old_growth_audio == null or _old_growth_audio.stream == null:
		return
	if _old_growth_sfx_retrigger_remaining > 0.0:
		return
	_old_growth_sfx_retrigger_remaining = old_growth_sfx_retrigger_seconds
	_old_growth_audio.play()
	_old_growth_sfx_play_count += 1


func get_xp_collect_sfx_play_count() -> int:
	return _xp_collect_sfx_play_count


func get_xp_collect_chain_count() -> int:
	return _xp_collect_chain_count


func get_last_xp_collect_pitch_scale() -> float:
	return _last_xp_collect_pitch_scale


func get_last_explosion_pitch_scale() -> float:
	return _last_explosion_pitch_scale


func has_active_boss() -> bool:
	for enemy in _enemies:
		if enemy.active and enemy.role == EnemyRole.BOSS:
			return true
	return false


func set_cane_modifiers(
	damage_multiplier: float,
	cooldown_multiplier: float,
	reach_multiplier: float = 1.0,
	apical_damage_bonus: float = 0.0
) -> void:
	_cane_damage_multiplier = maxf(0.05, damage_multiplier)
	_cane_cooldown_multiplier = maxf(0.05, cooldown_multiplier)
	_cane_reach_multiplier = maxf(0.05, reach_multiplier)
	_cane_apical_damage_bonus = maxf(0.0, apical_damage_bonus)


func set_cane_auto_targeting(enabled: bool) -> void:
	## Base Cane follows the player's facing. Vine replaces that input with the
	## densest targetable sector while preserving every other Cane rule.
	_cane_auto_targets = enabled


## How far below the sector's cosine a dot product must sit before the cheap test
## is allowed to reject a target outright.
##
## `angle > threshold` and `dot < cos(threshold)` are the same condition for unit
## vectors, because cosine decreases monotonically over [0, PI]. Only floating
## point separates them, so backing the cut off by a margin far larger than the
## error in a normalized dot product leaves a band around the boundary that is
## still decided by `angle_to` exactly as before. Nothing inside the sector, or
## near enough to be arguable, is ever rejected by arithmetic.
const CANE_SECTOR_DOT_MARGIN := 1.0e-5

## How the densest-target search evaluates each candidate sector.
##
## All three produce the same answer for any layout where the tie-breaker is not
## being asked to separate two candidates that are equal to within its own
## thresholds. They differ in cost and in how exactly they reproduce the original
## arithmetic, which is why the slow one stays available to probes forever.
enum DensestTargetMode {
	## Every candidate/target pair decided by `angle_to`, as originally written.
	REFERENCE,
	## As REFERENCE, but a dot product may reject pairs that are plainly outside the
	## sector. Bit-identical to REFERENCE: it only skips work whose outcome was
	## already settled.
	DOT_PRUNE,
	## Angles sorted once, then each candidate's contained set found by binary
	## search and summarised from prefix sums. Mathematically identical to
	## REFERENCE, but NOT bit-identical: it forms the angular error as a difference
	## of two `atan2` results rather than one `atan2` of a cross and a dot, and
	## sums in sorted order rather than pool order. Both are exact to roughly 1e-7,
	## against a tie-breaker with 1e-4 thresholds.
	SORTED,
}

## Which mode ships. Kept as a constant rather than inlined so a regression can be
## bisected by changing one line.
const CANE_DENSEST_TARGET_MODE := DensestTargetMode.SORTED


func get_densest_target_direction(
	origin: Vector2,
	maximum_range: float,
	sector_degrees: float,
	fallback_direction: Vector2 = Vector2.RIGHT
) -> Vector2:
	## Finds the direction whose fixed-width sector contains the most live,
	## unobstructed enemies. Testing each target on both sector edges guarantees a
	## maximal angular window without depending on pool order for the result.
	return _densest_target_direction(
		origin,
		maximum_range,
		sector_degrees,
		fallback_direction,
		CANE_DENSEST_TARGET_MODE
	)


func debug_densest_target_direction_reference(
	origin: Vector2,
	maximum_range: float,
	sector_degrees: float,
	fallback_direction: Vector2 = Vector2.RIGHT
) -> Vector2:
	## The original search, every pair decided by `angle_to`. Kept in the shipping
	## class rather than in the probe so the paths cannot drift apart: they are one
	## body and one tie-breaker, differing only in how each candidate is evaluated.
	return _densest_target_direction(
		origin,
		maximum_range,
		sector_degrees,
		fallback_direction,
		DensestTargetMode.REFERENCE
	)


func debug_densest_target_direction_mode(
	origin: Vector2,
	maximum_range: float,
	sector_degrees: float,
	fallback_direction: Vector2,
	mode: DensestTargetMode
) -> Vector2:
	## For probes that need to compare one specific mode against the reference.
	return _densest_target_direction(
		origin, maximum_range, sector_degrees, fallback_direction, mode
	)


func _densest_target_direction(
	origin: Vector2,
	maximum_range: float,
	sector_degrees: float,
	fallback_direction: Vector2,
	mode: DensestTargetMode
) -> Vector2:
	var fallback := fallback_direction.normalized()
	if fallback.length_squared() <= 0.0001:
		fallback = Vector2.RIGHT
	var gather_began := Time.get_ticks_usec() if PhaseBPerfCounters.enabled else 0
	var target_directions := PackedVector2Array()
	var target_distances := PackedFloat32Array()
	if _cane_auto_targets:
		_cane_route_cache.clear()
	for enemy in _enemies:
		if not enemy.active:
			continue
		var to_enemy := enemy.position - origin
		var distance := to_enemy.length()
		if distance > maxf(0.0, maximum_range) + enemy.radius:
			continue
		if _cane_auto_targets:
			var route := territory_field.get_growth_path(origin, enemy.position)
			if route.is_empty():
				continue
			distance = territory_field.get_growth_path_length(route)
			if distance > maxf(0.0, maximum_range) + enemy.radius:
				continue
			_cane_route_cache[enemy.id] = route
		elif not territory_field.is_growth_path_clear(origin, enemy.position):
			continue
		target_directions.append(to_enemy / distance if distance > 0.001 else fallback)
		target_distances.append(distance)
	PhaseBPerfCounters.timer_add_since(
		PhaseBPerfCounters.TIMER_CANE_TARGET_GATHER, gather_began
	)
	if target_directions.is_empty():
		return fallback
	var sweep_began := Time.get_ticks_usec() if PhaseBPerfCounters.enabled else 0
	PhaseBPerfCounters.count(
		PhaseBPerfCounters.COUNT_CANE_TARGETS, target_directions.size()
	)
	var half_angle := deg_to_rad(clampf(sector_degrees, 1.0, 359.0) * 0.5)
	# The angular threshold the loop below tests against, and the dot product that
	# corresponds to it. A sector wide enough that no angle can fall outside pushes
	# this under -1, at which point nothing is ever rejected early -- which is the
	# correct behaviour, not a special case.
	var angle_threshold := half_angle + 0.0001
	var rejection_dot := cos(angle_threshold) - CANE_SECTOR_DOT_MARGIN
	var candidate_directions := PackedVector2Array()
	# Unit copies, built once, used only by the cheap rejection.
	#
	# These entries are not unit vectors. Gathering divides the straight-line offset
	# by `distance`, and with auto-targeting on `distance` has by then been replaced
	# with the routed path length, which is longer -- so the "direction" comes out
	# shorter than one. `angle_to` never noticed, because atan2 of cross over dot is
	# scale invariant. A raw dot product is not: it returns |a||b|cos(angle), so
	# against short vectors it reads as a wider angle than the real one and rejects
	# targets that are actually inside the sector. Normalizing here costs one pass
	# and keeps the arrays the tie-breaker reads untouched.
	var target_units := PackedVector2Array()
	var candidate_units := PackedVector2Array()
	for direction in target_directions:
		candidate_directions.append(direction)
		candidate_directions.append(direction.rotated(-half_angle))
		candidate_directions.append(direction.rotated(half_angle))
		var unit := direction.normalized()
		target_units.append(unit)
		candidate_units.append(unit)
		candidate_units.append(unit.rotated(-half_angle))
		candidate_units.append(unit.rotated(half_angle))
	# Sorted mode's one-off preparation. Angles are laid out three times -- shifted
	# down a turn, as measured, and shifted up a turn -- so that a candidate's window
	# is one contiguous run whatever it straddles, with no wrap-around case to get
	# wrong. A window is narrower than a full turn (the widest legal sector is just
	# under 360 degrees), so no target can appear in one twice.
	var sorted_angles := PackedFloat64Array()
	var prefix_distance := PackedFloat64Array()
	var prefix_angle := PackedFloat64Array()
	if mode == DensestTargetMode.SORTED:
		var order: Array[int] = []
		var raw_angles := PackedFloat64Array()
		for index in range(target_directions.size()):
			var target_vector := target_directions[index]
			raw_angles.append(atan2(target_vector.y, target_vector.x))
			order.append(index)
		order.sort_custom(
			func(first: int, second: int) -> bool:
				return raw_angles[first] < raw_angles[second]
		)
		var turn := TAU
		for copy in range(3):
			var shift := float(copy - 1) * turn
			for index in order:
				sorted_angles.append(raw_angles[index] + shift)
		prefix_distance.resize(sorted_angles.size() + 1)
		prefix_angle.resize(sorted_angles.size() + 1)
		prefix_distance[0] = 0.0
		prefix_angle[0] = 0.0
		for index in range(sorted_angles.size()):
			var source_index: int = order[index % order.size()]
			prefix_distance[index + 1] = (
				prefix_distance[index] + float(target_distances[source_index])
			)
			prefix_angle[index + 1] = prefix_angle[index] + sorted_angles[index]

	var best_direction := fallback
	var best_count := -1
	var best_distance_sum := INF
	var best_alignment_error := INF
	var best_facing_difference := INF
	for candidate_index in range(candidate_directions.size()):
		var candidate := candidate_directions[candidate_index]
		var candidate_unit := candidate_units[candidate_index]
		var contained := 0
		var distance_sum := 0.0
		var alignment_error := 0.0
		if mode == DensestTargetMode.SORTED:
			# The contained set is exactly the targets whose angle lies within the
			# threshold of this candidate's, which after sorting is one run. Splitting
			# that run at the candidate's own angle turns the sum of |candidate -
			# target| into two prefix-sum differences, so a candidate costs three
			# binary searches instead of a pass over every target.
			var candidate_angle := atan2(candidate.y, candidate.x)
			var low := _lower_bound_float(sorted_angles, candidate_angle - angle_threshold)
			var high := _upper_bound_float(sorted_angles, candidate_angle + angle_threshold)
			var split := _upper_bound_float(sorted_angles, candidate_angle)
			split = clampi(split, low, high)
			contained = high - low
			distance_sum = prefix_distance[high] - prefix_distance[low]
			var below := (
				candidate_angle * float(split - low)
				- (prefix_angle[split] - prefix_angle[low])
			)
			var above := (
				(prefix_angle[high] - prefix_angle[split])
				- candidate_angle * float(high - split)
			)
			alignment_error = below + above
		else:
			for index in range(target_directions.size()):
				var target := target_directions[index]
				# Most targets in a crowd are nowhere near any given candidate's
				# sector, and rejecting those costs a multiply instead of an atan2.
				# Anything that survives -- inside the sector, or close enough to the
				# edge to be arguable -- still goes through `angle_to` and the
				# identical test, and a contained target needs its true angular error
				# anyway.
				if (
					mode == DensestTargetMode.DOT_PRUNE
					and candidate_unit.dot(target_units[index]) < rejection_dot
				):
					continue
				var angular_error := absf(candidate.angle_to(target))
				if angular_error > angle_threshold:
					continue
				contained += 1
				distance_sum += target_distances[index]
				alignment_error += angular_error
		var facing_difference := absf(fallback.angle_to(candidate))
		if (
			contained > best_count
			or (
				contained == best_count
				and distance_sum < best_distance_sum - 0.001
			)
			or (
				contained == best_count
				and absf(distance_sum - best_distance_sum) <= 0.001
				and alignment_error < best_alignment_error - 0.0001
			)
			or (
				contained == best_count
				and absf(distance_sum - best_distance_sum) <= 0.001
				and absf(alignment_error - best_alignment_error) <= 0.0001
				and facing_difference < best_facing_difference - 0.0001
			)
		):
			best_direction = candidate
			best_count = contained
			best_distance_sum = distance_sum
			best_alignment_error = alignment_error
			best_facing_difference = facing_difference
	PhaseBPerfCounters.timer_add_since(
		PhaseBPerfCounters.TIMER_CANE_TARGET_SWEEP, sweep_began
	)
	return best_direction.normalized()


func _lower_bound_float(values: PackedFloat64Array, wanted: float) -> int:
	## First index whose value is >= wanted.
	var low := 0
	var high := values.size()
	while low < high:
		var middle := (low + high) / 2
		if values[middle] < wanted:
			low = middle + 1
		else:
			high = middle
	return low


func _upper_bound_float(values: PackedFloat64Array, wanted: float) -> int:
	## First index whose value is > wanted.
	var low := 0
	var high := values.size()
	while low < high:
		var middle := (low + high) / 2
		if values[middle] <= wanted:
			low = middle + 1
		else:
			high = middle
	return low


func set_heartwood_rank(rank: int) -> void:
	_heartwood_rank = clampi(rank, 0, 5)
	if _heartwood_rank <= 0:
		_heartwood_progress = 0
		_heartwood_echo_remaining = 0.0


func multiply_next_cane_cooldown(multiplier: float) -> void:
	## Recurve and similar one-shot timing rules use the lowest multiplier offered;
	## repeated hits in one sweep cannot stack the same cooldown cut.
	_next_cane_cooldown_multiplier = minf(
		_next_cane_cooldown_multiplier,
		clampf(multiplier, 0.05, 1.0)
	)


func set_cane_apical_fraction_bonus(extra_fraction: float) -> void:
	_cane_apical_fraction_bonus = clampf(extra_fraction, 0.0, 0.70)


func set_sporulation_modifiers(enabled: bool, rate_multiplier: float = 1.0) -> void:
	# Spore is a path rule like Bramble's: pushed in when the run's lines change
	# rather than read out of Progression every frame by every enemy.
	_sporulation_enabled = enabled
	_sporulation_rate_multiplier = maxf(0.0, rate_multiplier)
	if enabled:
		return
	for enemy in _enemies:
		enemy.spore = 0.0
		enemy.overgrown = false
		enemy.spore_damage_remaining = 0.0
	for body in _fruiting_bodies:
		body.active = false


func set_bramble_modifiers(
	enabled: bool,
	slow_fraction: float,
	ensnare_multiplier: float = 1.0,
	root_seconds: float = 0.0,
	root_immunity_seconds: float = 4.0,
	repulsion_pixels: float = 0.0,
	old_growth_enabled: bool = false,
	root_network_bonus: float = 0.0
) -> void:
	_bramble_enabled = enabled
	_bramble_slow_fraction = clampf(slow_fraction, 0.0, 0.85)
	_bramble_ensnare_multiplier = maxf(0.05, ensnare_multiplier)
	_bramble_root_seconds = maxf(0.0, root_seconds)
	_bramble_root_immunity_seconds = maxf(0.0, root_immunity_seconds)
	_bramble_repulsion_pixels = maxf(0.0, repulsion_pixels)
	_old_growth_enabled = old_growth_enabled
	_root_network_bonus = maxf(0.0, root_network_bonus)
	if not enabled:
		for enemy in _enemies:
			enemy.was_on_bramble = false
			enemy.entanglement = 0.0
			enemy.bramble_root_remaining = 0.0
			enemy.movement_speed_multiplier = 1.0


func spawn_briar_pod(
	local_position: Vector2,
	radius: float,
	duration: float,
	contact_multiplier: float = 1.5
) -> bool:
	if not _bramble_enabled or not territory_field.is_claimable_at_local(local_position):
		return false
	var selected: BrambleZoneState
	for zone in _bramble_zones:
		if not zone.active:
			selected = zone
			break
		if selected == null or zone.remaining < selected.remaining:
			selected = zone
	if selected == null:
		return false
	selected.active = true
	selected.position = local_position
	selected.radius = maxf(bramble_frontier_band_pixels * 2.0, radius)
	selected.remaining = maxf(0.1, duration)
	selected.duration = selected.remaining
	selected.contact_multiplier = maxf(0.1, contact_multiplier)
	queue_redraw()
	return true


func get_active_briar_pod_count() -> int:
	var count := 0
	for zone in _bramble_zones:
		if zone.active:
			count += 1
	return count


func spawn_briar_trap(
	local_position: Vector2,
	radius: float,
	duration: float,
	damage: float,
	entanglement_gain: float
) -> bool:
	# Briar Traps are armed ground rather than a perimeter: they wait for prey, blow
	# once, and light their neighbours, which is what turns a Bloom's harvest into a
	# visible cascade instead of a stack of overlapping rings.
	if not _bramble_enabled or not territory_field.is_claimable_at_local(local_position):
		return false
	var selected: BriarTrapState
	for trap in _briar_traps:
		if not trap.active:
			selected = trap
			break
		if selected == null or trap.remaining < selected.remaining:
			selected = trap
	if selected == null:
		return false
	selected.active = true
	selected.position = local_position
	selected.radius = maxf(4.0, radius)
	selected.trigger_radius = (
		selected.radius
		* briar_trap_trigger_fraction
		* (1.0 + _briar_payload_trigger_bonus)
	)
	selected.chain_radius = (
		selected.radius * briar_trap_chain_fraction * (1.0 + _briar_payload_chain_bonus)
	)
	selected.remaining = maxf(0.1, duration)
	selected.duration = selected.remaining
	selected.damage = maxf(0.0, damage)
	selected.entanglement_gain = clampf(entanglement_gain, 0.0, 1.0)
	selected.fuse_remaining = 0.0
	selected.chain_depth = 0
	_briar_trap_sequence += 1
	selected.seed = _briar_trap_sequence
	selected.is_briar_heart = (
		_briar_payload_heart_cadence > 0
		and _briar_trap_sequence % _briar_payload_heart_cadence == 0
	)
	selected.detonations_remaining = briar_heart_detonations if selected.is_briar_heart else 1
	if selected.is_briar_heart:
		selected.radius *= briar_heart_scale
		selected.trigger_radius *= briar_heart_scale
	queue_redraw()
	return true


func get_active_briar_trap_count() -> int:
	var count := 0
	for trap in _briar_traps:
		if trap.active:
			count += 1
	return count


func _update_briar_traps(delta: float) -> void:
	for recharge_index in range(_briar_heart_recharges.size() - 1, -1, -1):
		var recharge: Array = _briar_heart_recharges[recharge_index]
		recharge[1] = float(recharge[1]) - delta
		if recharge[1] > 0.0:
			continue
		var recharged_trap: BriarTrapState = recharge[0]
		if recharged_trap.active:
			recharged_trap.trigger_radius = float(recharge[2])
		_briar_heart_recharges.remove_at(recharge_index)
	for trap in _briar_traps:
		if not trap.active:
			continue
		trap.remaining -= delta
		if trap.remaining <= 0.0:
			# Traps rot rather than accumulating, so the arena never fills with mines.
			trap.active = false
			continue
		if trap.fuse_remaining > 0.0:
			trap.fuse_remaining -= delta
			if trap.fuse_remaining <= 0.0:
				_detonate_briar_trap(trap)
			continue
		if _has_enemy_within(trap.position, trap.trigger_radius):
			_detonate_briar_trap(trap)


func _recharge_briar_heart(trap: BriarTrapState) -> void:
	# Restore the trigger only after the recharge window, so one enemy standing on
	# a Heart cannot chain-detonate it every frame.
	trap.fuse_remaining = 0.0
	trap.remaining = maxf(trap.remaining, briar_heart_recharge_seconds)
	trap.trigger_radius = 0.0
	_briar_heart_recharges.append(
		[trap, briar_heart_recharge_seconds, trap.radius * briar_trap_trigger_fraction
			* (1.0 + _briar_payload_trigger_bonus)]
	)


func _has_enemy_within(center: Vector2, radius: float) -> bool:
	for enemy in _enemies:
		if not enemy.active:
			continue
		if enemy.position.distance_to(center) <= radius + enemy.radius:
			return true
	return false


func _detonate_briar_trap(trap: BriarTrapState) -> void:
	trap.detonations_remaining -= 1
	if trap.detonations_remaining > 0:
		# A Briar Heart reloads instead of dying, so it keeps punishing the ground
		# it was sown on for as long as enemies keep walking into it.
		trap.fuse_remaining = 0.0
		trap.remaining = maxf(trap.remaining, briar_heart_recharge_seconds)
		trap.trigger_radius = 0.0
		_recharge_briar_heart(trap)
	else:
		trap.active = false
	_spawn_root_eruption(trap.position)
	damage_enemies_in_radius(
		trap.position,
		trap.radius,
		trap.damage,
		DeathSource.THORNBURST,
		trap.chain_depth
	)
	_apply_entanglement_in_radius(
		trap.position,
		trap.radius,
		maxf(trap.entanglement_gain, _briar_payload_entanglement)
	)
	briar_trap_detonated.emit(trap.position)
	if trap.chain_depth >= briar_trap_maximum_chain_depth:
		return
	for other in _briar_traps:
		if not other.active or other.fuse_remaining > 0.0:
			continue
		if other.position.distance_to(trap.position) > trap.chain_radius:
			continue
		if not territory_field.is_growth_path_clear(trap.position, other.position):
			continue
		other.fuse_remaining = maxf(0.01, briar_trap_chain_delay_seconds)
		other.chain_depth = trap.chain_depth + 1


func _draw_briar_trap(trap: BriarTrapState) -> void:
	var lit := trap.fuse_remaining > 0.0
	var pulse := 0.55 + 0.45 * sin(float(trap.seed) * 0.7 + trap.remaining * 6.0)
	var body_color := Color(0.20, 0.42, 0.14, 0.55)
	var thorn_color := Color(0.78, 1.0, 0.42, 0.55 + 0.40 * pulse)
	if lit:
		body_color = Color(0.52, 0.28, 0.10, 0.75)
		thorn_color = Color(1.0, 0.92, 0.45, 0.95)
	draw_circle(trap.position, trap.trigger_radius * 0.35, body_color)
	for thorn_index in range(6):
		var direction := Vector2.from_angle(
			TAU * float(thorn_index) / 6.0 + float(trap.seed % 5) * 0.24
		)
		var base_point := trap.position + direction * (trap.trigger_radius * 0.30)
		var tip := trap.position + direction * (trap.trigger_radius * 0.72)
		draw_line(base_point, tip, thorn_color, 1.8)


func get_enemy_movement_speed_multiplier(enemy_id: int) -> float:
	var enemy := _find_enemy(enemy_id)
	return enemy.movement_speed_multiplier if enemy != null else 0.0


func set_enemy_scaling(
	health_scale: float,
	damage_scale: float,
	territory_erosion_scale: float = 1.0,
	spawn_wave_number: int = 1,
	xp_growth_per_wave: float = 0.10,
	xp_minimum_bonus_per_wave: int = 1
) -> void:
	_enemy_health_scale = maxf(0.1, health_scale)
	_enemy_damage_scale = maxf(0.1, damage_scale)
	_enemy_territory_erosion_scale = maxf(0.1, territory_erosion_scale)
	_enemy_spawn_wave_number = maxi(1, spawn_wave_number)
	_enemy_xp_growth_per_wave = maxf(0.0, xp_growth_per_wave)
	_enemy_xp_minimum_bonus_per_wave = maxi(0, xp_minimum_bonus_per_wave)


func set_simulation_paused(paused: bool) -> void:
	simulation_paused = paused


func play_plant_explosion_sfx() -> void:
	if _plant_explosion_audio.stream == null:
		return
	_last_explosion_pitch_scale = _sfx_random.randf_range(
		minf(explosion_minimum_pitch_scale, explosion_maximum_pitch_scale),
		maxf(explosion_minimum_pitch_scale, explosion_maximum_pitch_scale)
	)
	_plant_explosion_audio.pitch_scale = _last_explosion_pitch_scale
	_plant_explosion_audio.play()
	_plant_explosion_sfx_play_count += 1


func debug_kill_all(death_source: int = DeathSource.DEBUG) -> int:
	var killed := 0
	for enemy in _enemies:
		if not enemy.active:
			continue
		_damage_enemy(enemy, enemy.health + 1.0, death_source, 0)
		killed += 1
	return killed


func debug_reset_damage_accounting() -> void:
	debug_damage_applied_total = 0.0
	debug_damage_number_total = 0.0


func debug_pending_damage_number_total() -> float:
	## Damage accumulated but not yet flushed. Owed, not lost, so a probe comparing
	## applied against shown has to count it.
	var total := 0.0
	for enemy in _enemies:
		if enemy.active:
			total += enemy.pending_number_damage
	return total


func debug_damage_enemy(enemy_id: int, damage: float) -> bool:
	var enemy := _find_enemy(enemy_id)
	if enemy == null:
		return false
	_damage_enemy(enemy, damage, DeathSource.DEBUG, 0)
	return true


func debug_fill_stress(enemy_count: int, projectile_count: int, pickup_count: int) -> void:
	var stress_roles := PackedInt32Array([
		EnemyRole.HUNTER,
		EnemyRole.GRAZER,
		EnemyRole.SABOTEUR,
		EnemyRole.CORRUPTOR,
		EnemyRole.COLONIZER,
		EnemyRole.WARDEN,
	])
	for index in range(enemy_count):
		var role := stress_roles[index % stress_roles.size()]
		spawn_enemy(role)
	for index in range(mini(projectile_count, _projectiles.size())):
		var projectile := _projectiles[index]
		projectile.active = true
		projectile.position = Vector2(
			80.0 + float((index * 47) % 800),
			60.0 + float((index * 83) % 420)
		)
		projectile.velocity = Vector2.from_angle(float(index) * 0.73) * DEBUG_PROJECTILE_SPEED
		projectile.damage = cane_damage
		projectile.remaining = DEBUG_PROJECTILE_LIFETIME
		projectile.remaining_distance = DEBUG_PROJECTILE_RANGE
		projectile.pierce_remaining = 1
		projectile.last_hit_enemy_id = -1
	for index in range(mini(pickup_count, _pickups.size())):
		var pickup := _pickups[index]
		pickup.active = true
		pickup.position = Vector2(
			70.0 + float((index * 67) % 820),
			55.0 + float((index * 31) % 430)
		)
		pickup.xp_value = 1
		pickup.age = 0.0


func _configure_pools() -> void:
	_enemies.clear()
	_projectiles.clear()
	_pickups.clear()
	_damage_numbers.clear()
	_bramble_zones.clear()
	for _index in range(enemy_pool_size):
		_enemies.append(EnemyState.new())
		_damage_numbers.append(DamageNumberState.new())
	for _index in range(projectile_pool_size):
		_projectiles.append(ProjectileState.new())
	for _index in range(pickup_pool_size):
		_pickups.append(PickupState.new())
	for _index in range(briar_pod_pool_size):
		_bramble_zones.append(BrambleZoneState.new())
	_root_eruptions.clear()
	for _eruption_index in range(old_growth_eruption_pool_size):
		_root_eruptions.append(RootEruptionState.new())
	_briar_traps.clear()
	for _trap_index in range(briar_trap_pool_size):
		_briar_traps.append(BriarTrapState.new())
	_fruiting_bodies.clear()
	for _body_index in range(fruiting_body_pool_size):
		_fruiting_bodies.append(FruitingBodyState.new())
	_pending_eruptions.clear()
	for _pending_index in range(old_growth_eruption_pool_size):
		_pending_eruptions.append(PendingEruptionState.new())


func _configure_audio() -> void:
	_cane_audio = AudioStreamPlayer.new()
	_cane_audio.name = "CaneSfx"
	_cane_audio.stream = cane_swing_sfx
	_cane_audio.volume_db = cane_sfx_volume_db
	_cane_audio.max_polyphony = 4
	_cane_audio.bus = audio_settings.sfx_bus_name
	add_child(_cane_audio)
	_plant_explosion_audio = AudioStreamPlayer.new()
	_plant_explosion_audio.name = "PlantExplosionSfx"
	_plant_explosion_audio.stream = plant_explosion_sfx
	_plant_explosion_audio.volume_db = plant_explosion_sfx_volume_db
	_plant_explosion_audio.max_polyphony = PLANT_EXPLOSION_MAX_POLYPHONY
	_plant_explosion_audio.bus = audio_settings.sfx_bus_name
	add_child(_plant_explosion_audio)
	_old_growth_audio = AudioStreamPlayer.new()
	_old_growth_audio.name = "OldGrowthSfx"
	_old_growth_audio.stream = old_growth_sfx
	_old_growth_audio.volume_db = old_growth_sfx_volume_db
	_old_growth_audio.max_polyphony = OLD_GROWTH_MAX_POLYPHONY
	_old_growth_audio.bus = audio_settings.sfx_bus_name
	add_child(_old_growth_audio)
	_xp_collect_audio_voices.clear()
	for voice_index in range(XP_COLLECT_AUDIO_VOICE_COUNT):
		var xp_audio_voice := AudioStreamPlayer.new()
		xp_audio_voice.name = "XpCollectSfx%d" % (voice_index + 1)
		xp_audio_voice.stream = xp_collect_sfx
		xp_audio_voice.volume_db = xp_collect_sfx_volume_db
		xp_audio_voice.bus = audio_settings.sfx_bus_name
		add_child(xp_audio_voice)
		_xp_collect_audio_voices.append(xp_audio_voice)


func _configure_navigation() -> void:
	_navigation_width = maxi(
		8,
		int(ceil(
			float(territory_field.tuning.field_size.x) / float(navigation_grid_divisor)
		))
	)
	_navigation_height = maxi(
		8,
		int(ceil(
			float(territory_field.tuning.field_size.y) / float(navigation_grid_divisor)
		))
	)
	_navigation_cell_count = _navigation_width * _navigation_height
	_navigation_small_walkable.resize(_navigation_cell_count)
	_navigation_boss_walkable.resize(_navigation_cell_count)
	_navigation_small_distances.resize(_navigation_cell_count)
	_navigation_boss_distances.resize(_navigation_cell_count)
	_navigation_catalyst_distances.resize(_navigation_cell_count)
	_navigation_queue.resize(_navigation_cell_count)
	for y in range(_navigation_height):
		for x in range(_navigation_width):
			var index := y * _navigation_width + x
			var local_position := _navigation_cell_to_local(Vector2i(x, y))
			_navigation_small_walkable[index] = int(_can_occupy_diamond(
				local_position,
				navigation_small_clearance_pixels
			))
			_navigation_boss_walkable[index] = int(_can_occupy_diamond(
				local_position,
				navigation_boss_clearance_pixels
			))


## Whether the run currently has Vine running the Cane. Pushed in by the Adaptation
## director, which is what owns the question of which Paths are active.
var _vine_enabled := false


func set_vine_enabled(enabled: bool) -> void:
	_vine_enabled = enabled


func is_vine_driven() -> bool:
	## Whether the Vine Adaptation is running the Cane, in which case the rope and
	## not the authored sector is what resolves a stroke.
	return _vine_enabled and vine_whip != null and vine_whip.is_built()


func _update_vine_whip(delta: float) -> void:
	if vine_whip == null:
		return
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_VINE_TOTAL)
	var origin := player.get_arena_position()
	if not vine_whip.is_built():
		vine_whip.build(origin, cane_reach_pixels * _cane_reach_multiplier)
	vine_whip.set_reach(cane_reach_pixels * _cane_reach_multiplier)
	vine_whip.set_apical_share(
		clampf(cane_apical_fraction + _cane_apical_fraction_bonus, 0.05, 0.95)
	)
	# Simulated continuously. The rope exists between attacks, which is the whole
	# point of it being an appendage rather than an attack effect.
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_VINE_ADVANCE)
	vine_whip.advance(origin, player.get_facing_direction(), delta)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_VINE_ADVANCE)
	if not _vine_sweep_active:
		PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_VINE_TOTAL)
		return
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_VINE_HITS)
	_resolve_vine_hits()
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_VINE_HITS)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_VINE_TOTAL)
	if not vine_whip.is_sweeping():
		_vine_sweep_active = false
		cane_sweep_finished.emit(
			_vine_sweep_origin,
			_vine_sweep_facing,
			_vine_sweep_left_to_right,
			_vine_sweep_reach,
			_vine_sweep_hits,
			_vine_sweep_is_bonus
		)


func _resolve_vine_hits() -> void:
	var ids := PackedInt32Array()
	var positions := PackedVector2Array()
	var radii := PackedFloat32Array()
	for enemy in _enemies:
		if not enemy.active:
			continue
		ids.append(enemy.id)
		positions.append(enemy.position)
		radii.append(enemy.radius)
	if ids.is_empty():
		return
	for hit in vine_whip.collect_hits(ids, positions, radii):
		var enemy_id := int(hit[0])
		var apical: bool = hit[1]
		var chain_position := float(hit[2])
		var enemy := _find_enemy(enemy_id)
		if enemy == null or not enemy.active:
			continue
		var damage := _vine_sweep_damage
		if apical:
			damage *= 1.0 + _cane_apical_damage_bonus
		var hit_position := enemy.position
		_damage_enemy(enemy, damage, DeathSource.CANE, 0)
		_vine_sweep_hits += 1
		cane_enemy_hit.emit(
			enemy_id,
			hit_position,
			chain_position,
			apical,
			damage,
			not enemy.active,
			_vine_sweep_is_bonus
		)


func _update_cane(delta: float) -> void:
	_update_vine_whip(delta)
	if _temporary_attack_remaining > 0.0:
		_temporary_attack_remaining -= delta
		if _temporary_attack_remaining <= 0.0:
			_temporary_attack_multiplier = 1.0
	_cane_visual_remaining = maxf(0.0, _cane_visual_remaining - delta)
	if _heartwood_echo_remaining > 0.0:
		_heartwood_echo_remaining -= delta
		if _heartwood_echo_remaining <= 0.0:
			_perform_cane_sweep(
				_heartwood_echo_facing,
				_heartwood_echo_left_to_right,
				0.60,
				1.15,
				true,
				0.40 if _heartwood_rank >= 2 else -1.0
			)
	_cane_remaining -= delta
	if _cane_remaining > 0.0:
		return
	var reach_multiplier := 1.0
	var heartwood_sweep := false
	if _heartwood_rank > 0:
		var progress_step := 1
		if (
			_heartwood_rank >= 3
			and territory_field.is_mature_player_territory_at_local(
				player.get_arena_position()
			)
		):
			progress_step = 2
		_heartwood_progress += progress_step
		if _heartwood_progress >= 5:
			_heartwood_progress -= 5
			heartwood_sweep = true
			reach_multiplier *= 1.15
	var facing := player.get_facing_direction()
	if _cane_auto_targets:
		PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_CANE_TARGETING)
		facing = get_densest_target_direction(
			player.get_arena_position(),
			cane_reach_pixels * _cane_reach_multiplier * reach_multiplier,
			cane_arc_degrees,
			facing
		)
		PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_CANE_TARGETING)
	_perform_cane_sweep(
		facing,
		_cane_next_left_to_right,
		1.50 if heartwood_sweep else 1.0,
		reach_multiplier,
		false,
		0.40 if heartwood_sweep and _heartwood_rank >= 2 else -1.0
	)
	if heartwood_sweep and _heartwood_rank >= 5:
		_heartwood_echo_remaining = 0.30
		_heartwood_echo_facing = facing
		_heartwood_echo_left_to_right = _cane_next_left_to_right
	_cane_next_left_to_right = not _cane_next_left_to_right
	_cane_sweep_count += 1
	var cooldown := cane_cooldown_seconds * _cane_cooldown_multiplier
	cooldown *= _temporary_attack_multiplier
	if heartwood_sweep and _heartwood_rank >= 4:
		cooldown *= 0.60
	cooldown *= _next_cane_cooldown_multiplier
	_next_cane_cooldown_multiplier = 1.0
	_cane_remaining = maxf(0.03, cooldown)


func perform_bonus_cane_sweep(
	facing: Vector2,
	left_to_right: bool,
	damage_multiplier: float = 1.0,
	reach_multiplier: float = 1.0,
	apical_fraction_override: float = -1.0
) -> int:
	## Evolution-triggered stroke. It uses the same sector and hit-once resolver but
	## does not consume the automatic alternation or the attack timer.
	return _perform_cane_sweep(
		facing,
		left_to_right,
		maxf(0.0, damage_multiplier),
		maxf(0.05, reach_multiplier),
		true,
		apical_fraction_override
	)


func _perform_cane_sweep(
	facing: Vector2,
	left_to_right: bool,
	bonus_damage_multiplier: float,
	bonus_reach_multiplier: float,
	is_bonus: bool,
	apical_fraction_override: float = -1.0
) -> int:
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_CANE_PERFORM)
	if facing.length_squared() <= 0.0001:
		facing = Vector2.RIGHT
	facing = facing.normalized()
	var origin := player.get_arena_position()
	var reach := cane_reach_pixels * _cane_reach_multiplier * bonus_reach_multiplier
	var base_damage := cane_damage * _cane_damage_multiplier * bonus_damage_multiplier
	_cane_visual_remaining = cane_sweep_seconds
	_cane_visual_origin = origin
	_cane_visual_facing = facing
	_cane_visual_left_to_right = left_to_right
	_cane_visual_reach = reach
	_cane_visual_path = PackedVector2Array()
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_CANE_SWEEP_SIGNAL)
	cane_sweep_started.emit(
		origin,
		facing,
		left_to_right,
		reach,
		base_damage,
		is_bonus
	)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_CANE_SWEEP_SIGNAL)
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_CANE_SFX)
	_play_cane_sfx()
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_CANE_SFX)
	if is_vine_driven():
		# The rope resolves this sweep. Hits arrive over the driving window rather
		# than all at once, so cane_sweep_finished is emitted when the stroke ends.
		if _vine_sweep_active:
			# A stroke arriving on top of one still running closes the old one first,
			# so every started sweep is matched by exactly one finished.
			cane_sweep_finished.emit(
				_vine_sweep_origin,
				_vine_sweep_facing,
				_vine_sweep_left_to_right,
				_vine_sweep_reach,
				_vine_sweep_hits,
				_vine_sweep_is_bonus
			)
		vine_whip.begin_sweep(facing, left_to_right, cane_cooldown_seconds)
		_vine_sweep_active = true
		_vine_sweep_damage = base_damage
		_vine_sweep_is_bonus = is_bonus
		_vine_sweep_facing = facing
		_vine_sweep_left_to_right = left_to_right
		_vine_sweep_reach = reach
		_vine_sweep_origin = origin
		_vine_sweep_hits = 0
		_cane_route_cache.clear()
		PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_CANE_PERFORM)
		return 0
	var half_angle := deg_to_rad(cane_arc_degrees * 0.5)
	var apical_fraction := clampf(
		(
			apical_fraction_override
			if apical_fraction_override >= 0.0
			else cane_apical_fraction + _cane_apical_fraction_bonus
		),
		0.05,
		0.95
	)
	var hit_count := 0
	var strongest_visual_detour := 0.01
	for enemy in _enemies:
		if not enemy.active:
			continue
		var to_enemy := enemy.position - origin
		var direct_distance := to_enemy.length()
		if direct_distance > reach + enemy.radius:
			continue
		if direct_distance > 0.001:
			var edge_allowance := asin(clampf(enemy.radius / direct_distance, 0.0, 1.0))
			if absf(facing.angle_to(to_enemy / direct_distance)) > half_angle + edge_allowance:
				continue
		var distance := direct_distance
		var vine_route := PackedVector2Array()
		if _cane_auto_targets:
			vine_route = _cane_route_cache.get(enemy.id, PackedVector2Array())
			if vine_route.is_empty():
				PhaseBPerfCounters.count(
					PhaseBPerfCounters.COUNT_CANE_ROUTE_CACHE_MISSES
				)
				var route_began := Time.get_ticks_usec() if PhaseBPerfCounters.enabled else 0
				vine_route = territory_field.get_growth_path(origin, enemy.position)
				PhaseBPerfCounters.timer_add_since(
					PhaseBPerfCounters.TIMER_CANE_PERFORM_ROUTES, route_began
				)
			else:
				PhaseBPerfCounters.count(
					PhaseBPerfCounters.COUNT_CANE_ROUTE_CACHE_HITS
				)
			if vine_route.is_empty():
				continue
			distance = territory_field.get_growth_path_length(vine_route)
			if distance > reach + enemy.radius:
				continue
			var detour := distance - direct_distance
			if detour > strongest_visual_detour:
				strongest_visual_detour = detour
				_cane_visual_path = _trim_path_to_length(vine_route, reach)
		elif not territory_field.is_growth_path_clear(origin, enemy.position):
			continue
		var distance_fraction := clampf(distance / maxf(reach, 0.001), 0.0, 1.0)
		var apical := distance_fraction >= 1.0 - apical_fraction
		var damage := base_damage
		if apical:
			damage *= 1.0 + _cane_apical_damage_bonus
		var enemy_id := enemy.id
		var hit_position := enemy.position
		_damage_enemy(enemy, damage, DeathSource.CANE, 0)
		var killed := not enemy.active
		hit_count += 1
		cane_enemy_hit.emit(
			enemy_id,
			hit_position,
			distance_fraction,
			apical,
			damage,
			killed,
			is_bonus
		)
	cane_sweep_finished.emit(origin, facing, left_to_right, reach, hit_count, is_bonus)
	_cane_route_cache.clear()
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_CANE_PERFORM)
	return hit_count


func _trim_path_to_length(path: PackedVector2Array, maximum_length: float) -> PackedVector2Array:
	var trimmed := PackedVector2Array()
	if path.is_empty() or maximum_length <= 0.0:
		return trimmed
	trimmed.append(path[0])
	var remaining := maximum_length
	for index in range(1, path.size()):
		var segment_length := path[index - 1].distance_to(path[index])
		if segment_length <= remaining:
			trimmed.append(path[index])
			remaining -= segment_length
			continue
		if segment_length > 0.001:
			trimmed.append(path[index - 1].move_toward(path[index], remaining))
		break
	return trimmed


func _play_cane_sfx() -> void:
	if _cane_audio == null or _cane_audio.stream == null:
		return
	_cane_audio.play()
	_cane_sfx_play_count += 1


func _draw_cane_sweep() -> void:
	if is_vine_driven():
		# One body: the drawn Vine is the simulated Vine, so what the player sees is
		# exactly what resolved the hit.
		_draw_vine_whip()
		return
	if _cane_visual_remaining <= 0.0 or cane_sweep_seconds <= 0.0:
		return
	var progress := clampf(
		1.0 - _cane_visual_remaining / cane_sweep_seconds,
		0.0,
		1.0
	)
	var half_angle := deg_to_rad(cane_arc_degrees * 0.5)
	var start_angle := -half_angle if _cane_visual_left_to_right else half_angle
	var end_angle := half_angle if _cane_visual_left_to_right else -half_angle
	var current_offset := lerpf(start_angle, end_angle, progress)
	var direction := _cane_visual_facing.rotated(current_offset)
	var fade := clampf(_cane_visual_remaining / maxf(cane_sweep_seconds * 0.35, 0.001), 0.0, 1.0)
	var arc_start := _cane_visual_facing.angle() - half_angle
	var arc_end := _cane_visual_facing.angle() + half_angle
	var arc_color := (
		Color(0.33, 0.92, 0.38, 0.22 * fade)
		if _cane_auto_targets
		else Color(0.78, 0.95, 0.45, 0.18 * fade)
	)
	var shaft_shadow := (
		Color(0.055, 0.20, 0.075, 0.96 * fade)
		if _cane_auto_targets
		else Color(0.20, 0.10, 0.045, 0.96 * fade)
	)
	var shaft_color := (
		Color(0.24, 0.72, 0.25, 0.96 * fade)
		if _cane_auto_targets
		else Color(0.72, 0.46, 0.20, 0.96 * fade)
	)
	var tip_color := (
		Color(0.63, 1.0, 0.45, 0.95 * fade)
		if _cane_auto_targets
		else Color(0.90, 0.72, 0.34, 0.95 * fade)
	)
	draw_arc(
		_cane_visual_origin,
		_cane_visual_reach,
		arc_start,
		arc_end,
		24,
		arc_color,
		2.0,
		true
	)
	var shaft_start := _cane_visual_origin + direction * (player.body_radius_pixels + 3.0)
	var shaft_end := _cane_visual_origin + direction * _cane_visual_reach
	var shaft_path := PackedVector2Array([shaft_start, shaft_end])
	if _cane_auto_targets and _cane_visual_path.size() >= 2:
		shaft_path = _cane_visual_path.duplicate()
		shaft_path[0] = shaft_path[0].move_toward(
			shaft_path[1],
			player.body_radius_pixels + 3.0
		)
		shaft_end = shaft_path[shaft_path.size() - 1]
	draw_polyline(shaft_path, shaft_shadow, 7.0, true)
	draw_polyline(shaft_path, shaft_color, 3.5, true)
	for bend_index in range(1, shaft_path.size() - 1):
		draw_circle(shaft_path[bend_index], 1.75, shaft_color)
	draw_circle(shaft_end, 4.0, tip_color)


func _draw_vine_whip() -> void:
	if vine_whip == null or not vine_whip.is_built():
		return
	var body := vine_whip.points
	if body.size() < 2:
		return
	var attacking := vine_whip.is_sweeping()
	var shadow := Color(0.055, 0.20, 0.075, 0.96 if attacking else 0.55)
	var shaft := Color(0.24, 0.72, 0.25, 0.96 if attacking else 0.55)
	var tip_color := Color(0.63, 1.0, 0.45, 0.95 if attacking else 0.45)
	draw_polyline(body, shadow, 7.0 if attacking else 5.0, true)
	draw_polyline(body, shaft, 3.5 if attacking else 2.5, true)
	draw_circle(body[body.size() - 1], 4.0 if attacking else 3.0, tip_color)


func _update_enemies(delta: float) -> void:
	var player_position := player.get_arena_position()
	_update_navigation(player_position, delta)
	for enemy in _enemies:
		if not enemy.active:
			continue
		enemy.contact_remaining = maxf(0.0, enemy.contact_remaining - delta)
		_advance_elite_modifier(enemy, delta)
		enemy.territory_action_remaining -= delta
		enemy.hit_flash_remaining = maxf(0.0, enemy.hit_flash_remaining - delta)
		enemy.suppression_remaining = maxf(0.0, enemy.suppression_remaining - delta)
		if enemy.suppression_remaining <= 0.0:
			enemy.suppression_share = 0.0
		_update_enemy_bramble_contact(enemy, delta)
		if not enemy.active:
			continue
		# Kept apart from the Bramble tick on purpose: that one returns early for a
		# run without Bramble, and Sporulation has to work for a Root and Spore build
		# that never took a thorn.
		_update_enemy_spore(enemy, delta)
		if not enemy.active:
			continue

		if enemy.knockback_remaining > 0.0:
			# A repelled enemy is staggered: it slides out and does not chase, act on
			# territory, or land contact damage until the shove finishes.
			enemy.state = EnemyStateKind.ADVANCING
			_advance_knockback(enemy, delta)
			continue

		var contact_distance := enemy.radius + player.body_radius_pixels
		if enemy.position.distance_squared_to(player_position) <= contact_distance * contact_distance:
			enemy.state = EnemyStateKind.CONTACT
			if enemy.contact_remaining <= 0.0:
				player.apply_damage(enemy.contact_damage)
				enemy.contact_remaining = enemy.contact_interval
			if enemy.movement_behavior == PhaseBEnemyProfile.MovementBehavior.KEEP_DISTANCE:
				_move_enemy_keep_distance(enemy, player_position, delta)
		else:
			enemy.state = EnemyStateKind.ADVANCING
			_advance_enemy_for_behavior(enemy, player_position, delta)

		if (
			enemy.territory_behavior != PhaseBEnemyProfile.TerritoryBehavior.NONE
			and enemy.territory_action_remaining <= 0.0
			and (
				not enemy.require_player_territory
				or territory_field.get_control_at_local(enemy.position)
				> territory_field.tuning.ownership_threshold
			)
		):
			_perform_enemy_territory_action(enemy)
			enemy.territory_action_remaining = enemy.territory_action_interval
			# A grazing burst is followed by a recovery window, so sustained erosion
			# comes in bites the frontier can grow back between.
			if enemy.territory_actions_before_recovery > 0:
				enemy.territory_actions_taken += 1
				if enemy.territory_actions_taken >= enemy.territory_actions_before_recovery:
					enemy.territory_actions_taken = 0
					enemy.territory_action_remaining = enemy.territory_recovery_seconds


func _advance_enemy_for_behavior(
	enemy: EnemyState,
	player_position: Vector2,
	delta: float
) -> void:
	match enemy.movement_behavior:
		PhaseBEnemyProfile.MovementBehavior.ANCHORED:
			return
		PhaseBEnemyProfile.MovementBehavior.HUNT_CATALYSTS:
			if _navigation_catalyst_target_index >= 0:
				_move_enemy(
					enemy,
					_navigation_catalyst_target_position,
					delta,
					true
				)
				return
		PhaseBEnemyProfile.MovementBehavior.KEEP_DISTANCE:
			_move_enemy_keep_distance(enemy, player_position, delta)
			return
	_move_enemy(enemy, player_position, delta)


func _move_enemy_keep_distance(
	enemy: EnemyState,
	player_position: Vector2,
	delta: float
) -> void:
	var preferred_distance := maxf(1.0, enemy.preferred_distance_pixels)
	var current_distance := enemy.position.distance_to(player_position)
	if current_distance > preferred_distance * 1.15:
		_move_enemy(enemy, player_position, delta)
		return
	if current_distance >= preferred_distance * 0.85:
		return
	var retreat_direction := player_position.direction_to(enemy.position)
	if retreat_direction.length_squared() <= 0.001:
		retreat_direction = Vector2.from_angle(float(enemy.id) * 1.618)
	var retreat_distance := enemy.speed * enemy.movement_speed_multiplier * delta
	var side := -1.0 if enemy.id % 2 == 0 else 1.0
	for angle in STEERING_ANGLES:
		if _try_move_enemy(
			enemy,
			retreat_direction.rotated(angle * side),
			retreat_distance
		):
			return


func _update_enemy_bramble_contact(enemy: EnemyState, delta: float) -> void:
	if not _bramble_enabled:
		enemy.was_on_bramble = false
		enemy.entanglement = 0.0
		enemy.bramble_frontier_strength = 0.0
		enemy.bramble_ground_maturity = 0.0
		enemy.bramble_horde_count = 0
		enemy.movement_speed_multiplier = 1.0
		return
	enemy.bramble_damage_remaining = maxf(0.0, enemy.bramble_damage_remaining - delta)
	# The cooldowns keep running off Bramble so an enemy chewing a border cannot
	# re-trigger a crossing hit or a repulsion every time contact flickers.
	enemy.bramble_repulsion_remaining = maxf(
		0.0,
		enemy.bramble_repulsion_remaining - delta
	)
	enemy.bramble_crossing_remaining = maxf(0.0, enemy.bramble_crossing_remaining - delta)
	enemy.bramble_eruption_remaining = maxf(0.0, enemy.bramble_eruption_remaining - delta)
	enemy.bramble_root_immunity_remaining = maxf(
		0.0,
		enemy.bramble_root_immunity_remaining - delta
	)
	# A root outlives the ground that caused it, so an enemy shoved or grown off
	# the Green mid-hold still finishes serving it.
	enemy.bramble_root_remaining = maxf(0.0, enemy.bramble_root_remaining - delta)

	# All owned Green is hazardous ground. The frontier hedge and a Briar Pod ring
	# are bonuses layered on top of that coverage, never its foundation, so holes,
	# moving borders, and buried thorns leave the hazard itself untouched.
	var coverage := territory_field.get_bramble_coverage_at_local(enemy.position)
	var frontier_strength := territory_field.get_bramble_strength_at_local(
		enemy.position,
		bramble_frontier_band_pixels
	)
	var zone_strength := _get_briar_pod_strength(enemy.position)
	var contact_strength := maxf(coverage, zone_strength)
	if contact_strength <= 0.0:
		if enemy.was_on_bramble:
			# The Green-to-open-ground crossing, reported before the decay tick, so
			# what is announced is the Entanglement the enemy actually walked out with.
			enemy_left_green.emit(enemy.id, enemy.position, enemy.entanglement)
		_decay_entanglement(enemy, delta)
		enemy.was_on_bramble = false
		enemy.bramble_frontier_strength = 0.0
		enemy.bramble_ground_maturity = 0.0
		enemy.bramble_damage_remaining = 0.0
		enemy.movement_speed_multiplier = 0.0 if enemy.bramble_root_remaining > 0.0 else 1.0
		return

	enemy.bramble_frontier_strength = frontier_strength
	enemy.bramble_ground_maturity = territory_field.get_maturity_at_local(enemy.position)
	# Entanglement ramps rather than applying at once, so a fast enemy crosses Green
	# almost untouched while a Grazer settled in it is eventually overwhelmed.
	enemy.entanglement = minf(
		1.0,
		enemy.entanglement + _get_entanglement_rate(enemy, contact_strength) * delta
	)
	enemy.movement_speed_multiplier = 1.0 - clampf(
		_bramble_slow_fraction * enemy.entanglement * contact_strength,
		0.0,
		0.85
	)
	_try_root_entangled_enemy(enemy)
	if enemy.bramble_root_remaining > 0.0:
		# Grasping Roots holds the enemy outright; the slow it was already under is
		# irrelevant while it cannot move at all.
		enemy.movement_speed_multiplier = 0.0
	if (
		not enemy.was_on_bramble
		and bramble_frontier_crossing_damage > 0.0
		and enemy.bramble_crossing_remaining <= 0.0
		and frontier_strength >= territory_field.get_established_bramble_strength()
	):
		# Crossing a thick hedge stings once. It is a bonus on entry, not the path.
		enemy.bramble_crossing_remaining = bramble_frontier_crossing_cooldown_seconds
		_damage_enemy(
			enemy,
			bramble_frontier_crossing_damage * frontier_strength,
			DeathSource.BRAMBLE,
			0
		)
		if not enemy.active:
			return
	if enemy.bramble_damage_remaining <= 0.0:
		_damage_enemy(
			enemy,
			get_bramble_tick_damage(enemy, contact_strength),
			DeathSource.BRAMBLE,
			0
		)
		enemy.bramble_damage_remaining = bramble_damage_interval_seconds
		if not enemy.active:
			return
	enemy.was_on_bramble = true
	_try_erupt_root_network(enemy)


func _get_entanglement_rate(enemy: EnemyState, contact_strength: float) -> float:
	var frontier_bonus := (
		1.0 + bramble_frontier_ensnare_bonus * enemy.bramble_frontier_strength
	)
	return (
		bramble_entanglement_per_second
		* _bramble_ensnare_multiplier
		* contact_strength
		* frontier_bonus
		* (1.0 + _get_ensnare_zone_bonus(enemy.position))
		* _get_root_network_multiplier(enemy.position, enemy.bramble_ground_maturity)
	)


func _update_enemy_spore(enemy: EnemyState, delta: float) -> void:
	# Owned Green is infectious ground. Bramble decides whether that ground also has
	# thorns in it; Spore only asks whether the player holds it, so an enemy standing
	# on plain Green is being infected the whole time it is there.
	if not _sporulation_enabled:
		return
	if enemy.spore < 1.0 and territory_field.is_owned_at_local(enemy.position):
		# Root Potency is the one system that amplifies a path on Mature ground, so
		# Sporulation carries no Mature bonus of its own and reads the Network here
		# instead. Relic regions that deepen the Network locally come with it.
		var rate := (
			sporulation_per_second
			* _sporulation_rate_multiplier
			* (1.0 + _get_spore_rate_zone_bonus(enemy.position))
			* _get_root_network_multiplier(
				enemy.position,
				territory_field.get_maturity_at_local(enemy.position)
			)
		)
		_add_enemy_spore(enemy, rate * delta)
	if not enemy.overgrown:
		return
	enemy.spore_damage_remaining -= delta
	if enemy.spore_damage_remaining > 0.0:
		return
	enemy.spore_damage_remaining = overgrown_damage_interval_seconds
	# Contagion first, so an enemy killed by this very tick still pushes out one last
	# pulse before its death burst lands on the same neighbours. Riding the damage
	# clock rather than the frame keeps this to two scans a second per Overgrown
	# enemy, which is what makes a pack full of them affordable. The source itself is
	# already at full Spore, so it is skipped without needing to be excluded.
	apply_spore_in_radius(
		enemy.position,
		overgrown_contagion_radius_pixels,
		overgrown_contagion_spore_per_second * overgrown_damage_interval_seconds
	)
	# A share of the enemy's own maximum health, so the rot is as lethal to a boss as
	# it is to a Hunter. Sourced as SPORE so the kill cannot also be condensed into a
	# Seed by the kill counter, which this enemy has already been paying into.
	_damage_enemy(
		enemy,
		enemy.maximum_health
		* overgrown_max_health_damage_per_second
		* overgrown_damage_interval_seconds,
		DeathSource.SPORE,
		0
	)


func _add_enemy_spore(enemy: EnemyState, amount: float) -> void:
	# One door into Overgrown. Promotion has to live here rather than in the tick
	# because a cloud or a death burst can push an enemy over the line while it is
	# standing somewhere the ground will never infect it.
	if amount <= 0.0 or enemy.spore >= 1.0:
		return
	enemy.spore = minf(1.0, enemy.spore + amount)
	if enemy.spore < 1.0 or enemy.overgrown:
		return
	enemy.overgrown = true
	enemy.spore_damage_remaining = overgrown_damage_interval_seconds


func apply_suppression_in_radius(
	center: Vector2,
	radius: float,
	share: float,
	seconds: float
) -> int:
	# Refreshes rather than stacks: a second Bloom over the same pack restores the
	# window instead of deepening it, so the reduction can never exceed the rank.
	if share <= 0.0 or seconds <= 0.0:
		return 0
	var caught := 0
	for enemy in _enemies:
		if not enemy.active:
			continue
		if enemy.position.distance_to(center) > radius + enemy.radius:
			continue
		enemy.suppression_share = maxf(enemy.suppression_share, clampf(share, 0.0, 1.0))
		enemy.suppression_remaining = maxf(enemy.suppression_remaining, seconds)
		caught += 1
	return caught


func get_enemy_suppression(enemy_id: int) -> float:
	var enemy := _find_enemy(enemy_id)
	if enemy == null:
		return 0.0
	return enemy.suppression_share if enemy.suppression_remaining > 0.0 else 0.0


func apply_spore_in_radius(center: Vector2, radius: float, spore_gain: float) -> int:
	# Every airborne application of Spore - a cloud, a rupture, a death burst, the
	# Mass Entanglement pulse - lands through here, so promotion to Overgrown has a
	# single definition whatever put the Spore on the enemy.
	if spore_gain <= 0.0:
		return 0
	var caught := 0
	for enemy in _enemies:
		if not enemy.active or enemy.spore >= 1.0:
			continue
		if enemy.position.distance_to(center) > radius + enemy.radius:
			continue
		_add_enemy_spore(enemy, spore_gain)
		caught += 1
	return caught


func get_standard_enemy_health() -> float:
	# What "a standard enemy" is worth right now. The Hunter is the yardstick and the
	# wave scaling comes with it, so a Rootburst written as a share of a normal mob
	# keeps its meaning as the waves harden instead of decaying into a scratch.
	if hunter_profile == null:
		return 1.0
	return maxf(1.0, hunter_profile.maximum_health * _enemy_health_scale)


func find_infection_targets(wanted: int) -> PackedVector2Array:
	# Where a Germination Season is worth opening: on top of enemies that are already
	# standing in the run's own Green, densest cluster first. Seeds spent on empty
	# ground are the whole reason the old Season read as territory rather than as an
	# answer to a mob.
	var targets := PackedVector2Array()
	if wanted <= 0:
		return targets
	var standing: Array[EnemyState] = []
	for enemy in _enemies:
		if not enemy.active or enemy.spore >= 1.0:
			continue
		if not territory_field.is_owned_at_local(enemy.position):
			continue
		standing.append(enemy)
	if standing.is_empty():
		return targets
	# Score every candidate by how many others share its patch, then take them in
	# order, skipping anyone already covered by a burst this Season will place.
	var cluster_squared := infection_cluster_radius_pixels * infection_cluster_radius_pixels
	var scored: Array = []
	for enemy in standing:
		var neighbours := 0
		for other in standing:
			if other.position.distance_squared_to(enemy.position) <= cluster_squared:
				neighbours += 1
		scored.append([neighbours, enemy.position])
	scored.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	for entry in scored:
		if targets.size() >= wanted:
			break
		var candidate: Vector2 = entry[1]
		var covered := false
		for placed in targets:
			if placed.distance_squared_to(candidate) <= cluster_squared * 0.25:
				covered = true
				break
		if not covered:
			targets.append(candidate)
	# A Season with more Seeds than clusters still spends them: the leftovers double
	# up on the densest ground rather than being thrown away.
	var index := 0
	while targets.size() < wanted and not scored.is_empty():
		targets.append(scored[index % scored.size()][1])
		index += 1
	return targets


func apply_rootburst(
	center: Vector2,
	radius: float,
	damage: float,
	spore_gain: float
) -> int:
	# A Germination Season Seed opening underneath a mob. Damage first, so anything
	# the burst can kill outright dies as a Seed kill; the survivors then take the
	# Spore, and whatever that pushes to full infection collapses on the spot.
	var caught := 0
	for enemy in _enemies:
		if not enemy.active:
			continue
		if enemy.position.distance_to(center) > radius + enemy.radius:
			continue
		caught += 1
		if damage > 0.0:
			_damage_enemy(enemy, damage, DeathSource.SPORE, 0)
			if not enemy.active:
				continue
		if spore_gain <= 0.0 or enemy.spore >= 1.0:
			continue
		_add_enemy_spore(enemy, spore_gain)
		if enemy.overgrown:
			_fungal_collapse(enemy)
	return caught


func _fungal_collapse(enemy: EnemyState) -> void:
	# Infection cashed in at once. An ordinary mob simply dies, and because it is
	# Overgrown when it does, the death burst it owes still fires and carries the
	# outbreak into whatever was standing beside it. Elites and bosses are the fights
	# the run is meant to have, so they take a large hit and keep rotting instead.
	match enemy.role:
		EnemyRole.ELITE:
			_damage_enemy(
				enemy,
				enemy.maximum_health * fungal_collapse_elite_health_share,
				DeathSource.SPORE,
				0
			)
		EnemyRole.BOSS:
			_damage_enemy(
				enemy,
				enemy.maximum_health * fungal_collapse_boss_health_share,
				DeathSource.SPORE,
				0
			)
		_:
			_damage_enemy(enemy, enemy.health, DeathSource.SPORE, 0)


func spawn_fruiting_body(local_position: Vector2, immediate_cloud: bool = false) -> bool:
	# The pool is the cap. A colony that cannot find a free slot is simply not
	# raised, which is the same way a Briar Trap behaves under chain pressure.
	for body in _fruiting_bodies:
		if body.active:
			continue
		body.active = true
		body.position = local_position
		body.cloud_remaining = fruiting_body_cloud_interval_seconds
		body.clouds_remaining = fruiting_body_clouds
		if immediate_cloud:
			# Fungal Reserve's colonies arrive already breathing. The cloud it owes is
			# spent now and its lifecycle carries on one cloud shorter, so a guaranteed
			# body is a faster colony rather than a longer-lived one.
			body.clouds_remaining -= 1
			apply_spore_in_radius(
				local_position,
				fruiting_body_cloud_radius_pixels,
				_get_fruiting_body_spore(body, fruiting_body_cloud_spore)
			)
		_fruiting_body_sequence += 1
		body.seed = _fruiting_body_sequence
		queue_redraw()
		return true
	return false


func get_active_fruiting_body_count() -> int:
	var count := 0
	for body in _fruiting_bodies:
		if body.active:
			count += 1
	return count


func _update_fruiting_bodies(delta: float) -> void:
	for body in _fruiting_bodies:
		if not body.active:
			continue
		body.cloud_remaining -= delta
		if body.cloud_remaining > 0.0:
			continue
		body.cloud_remaining = fruiting_body_cloud_interval_seconds
		if body.clouds_remaining > 0:
			body.clouds_remaining -= 1
			apply_spore_in_radius(
				body.position,
				fruiting_body_cloud_radius_pixels,
				_get_fruiting_body_spore(body, fruiting_body_cloud_spore)
			)
			continue
		# Every cloud the colony had is spent, so this tick is the rupture. It comes
		# one full interval after the last cloud rather than landing on top of it,
		# which keeps the two applications legible as separate events.
		# Root Potency amplifies what a colony puts into the air and nothing else
		# about it: not the radius, not how long it lives, not the Seeds it scatters.
		apply_spore_in_radius(
			body.position,
			fruiting_body_rupture_radius_pixels,
			_get_fruiting_body_spore(body, fruiting_body_rupture_spore)
		)
		body.active = false
		fruiting_body_ruptured.emit(body.position)


func _get_fruiting_body_spore(body: FruitingBodyState, base_spore: float) -> float:
	return base_spore * _get_root_network_multiplier(
		body.position,
		territory_field.get_maturity_at_local(body.position)
	)


func _draw_fruiting_body(body: FruitingBodyState) -> void:
	# A swelling cap that fills as its next cloud comes due, so the player can read
	# how close a colony is to bursting without a bar over it.
	var swell := 1.0 - clampf(
		body.cloud_remaining / maxf(0.01, fruiting_body_cloud_interval_seconds),
		0.0,
		1.0
	)
	var pulse := 0.55 + 0.45 * sin(float(body.seed) * 0.7 + body.cloud_remaining * 3.0)
	# Pale and fungal rather than green, so a colony reads as something growing out
	# of the Green instead of as another piece of it. The last cloud before rupture
	# runs hot, which is the only warning the player gets.
	var cap_color := Color(0.82, 0.76, 0.55, 0.55 + 0.30 * swell)
	var halo_color := Color(0.68, 0.82, 0.44, 0.30 + 0.35 * pulse)
	if body.clouds_remaining <= 1:
		cap_color = Color(0.94, 0.72, 0.38, 0.85)
		halo_color = Color(1.0, 0.82, 0.42, 0.45 + 0.40 * pulse)
	var radius := 7.0 * (0.7 + 0.3 * swell)
	draw_circle(body.position, radius, cap_color)
	draw_line(
		body.position,
		body.position + Vector2(0.0, radius * 1.1),
		cap_color,
		2.0
	)
	# The halo is the reach the next cloud will actually cover.
	draw_arc(
		body.position,
		fruiting_body_cloud_radius_pixels * (0.35 + 0.65 * swell),
		0.0,
		TAU,
		24,
		halo_color,
		1.2,
		true
	)


func _get_root_network_multiplier(local_position: Vector2, ground_maturity: float) -> float:
	# Root Potency: mechanics operating from Mature ground run through the Root
	# Network, so old Green sharpens thorns and ensnares faster than fresh Green.
	# Asked of the Root path where the effect is happening, so a thorn inside an
	# Annual Rings region or a Seedbed patch reads the deeper Network there. The
	# pushed bonus stays as the fallback for a run wired without the path.
	if root_director != null:
		return root_director.get_network_multiplier_at(local_position, ground_maturity)
	return 1.0 + _root_network_bonus * clampf(ground_maturity, 0.0, 1.0)


func add_ensnare_zone(
	center: Vector2,
	radius: float,
	rate_bonus: float,
	duration: float
) -> void:
	# Aggressive Growth: freshly claimed ground ensnares faster for a few seconds.
	if rate_bonus <= 0.0 or duration <= 0.0:
		return
	# Fruit stamps can arrive every few pixels. Merge nearby equal zones so a long
	# trail remains one bounded gameplay region rather than hundreds of arrays.
	for zone in _ensnare_zones:
		if (
			Vector2(zone[0]).distance_to(center) <= maxf(8.0, radius * 0.55)
			and is_equal_approx(float(zone[2]), rate_bonus)
		):
			zone[0] = center
			zone[1] = maxf(float(zone[1]), radius)
			zone[3] = maxf(float(zone[3]), duration)
			return
	_ensnare_zones.append([center, radius, rate_bonus, duration])
	if _ensnare_zones.size() > 64:
		_ensnare_zones.pop_front()


func get_active_ensnare_zone_count() -> int:
	return _ensnare_zones.size()


func _update_ensnare_zones(delta: float) -> void:
	for index in range(_ensnare_zones.size() - 1, -1, -1):
		var zone: Array = _ensnare_zones[index]
		zone[3] = float(zone[3]) - delta
		if zone[3] <= 0.0:
			_ensnare_zones.remove_at(index)


func _get_ensnare_zone_bonus(local_position: Vector2) -> float:
	var bonus := 0.0
	for zone in _ensnare_zones:
		if local_position.distance_to(zone[0]) <= float(zone[1]):
			bonus = maxf(bonus, float(zone[2]))
	if is_in_rampart(local_position):
		# Living Rampart is a standing zone rather than a timed one, so it is read
		# here beside the timed zones instead of being re-added every frame.
		bonus = maxf(bonus, _rampart_ensnare_bonus)
	return bonus


func add_spore_rate_zone(
	center: Vector2,
	radius: float,
	rate_bonus: float,
	duration: float
) -> void:
	## Contaminated Ground: only owned-Green accumulation is accelerated. Direct
	## Spore applications remain unchanged because this multiplier is read solely by
	## `_update_enemy_spore`.
	if rate_bonus <= 0.0 or duration <= 0.0:
		return
	for zone in _spore_rate_zones:
		if (
			Vector2(zone[0]).distance_to(center) <= maxf(8.0, radius * 0.55)
			and is_equal_approx(float(zone[2]), rate_bonus)
		):
			zone[0] = center
			zone[1] = maxf(float(zone[1]), radius)
			zone[3] = maxf(float(zone[3]), duration)
			return
	_spore_rate_zones.append([center, radius, rate_bonus, duration])
	if _spore_rate_zones.size() > 64:
		_spore_rate_zones.pop_front()


func get_active_spore_rate_zone_count() -> int:
	return _spore_rate_zones.size()


func _update_spore_rate_zones(delta: float) -> void:
	for index in range(_spore_rate_zones.size() - 1, -1, -1):
		var zone: Array = _spore_rate_zones[index]
		zone[3] = float(zone[3]) - delta
		if zone[3] <= 0.0:
			_spore_rate_zones.remove_at(index)


func _get_spore_rate_zone_bonus(local_position: Vector2) -> float:
	var bonus := 0.0
	for zone in _spore_rate_zones:
		if local_position.distance_to(Vector2(zone[0])) <= float(zone[1]):
			bonus = maxf(bonus, float(zone[2]))
	return bonus


func damage_first_enemy_in_radius(
	center: Vector2,
	radius: float,
	damage: float,
	death_source: int,
	ignored_enemy_id: int = -1
) -> int:
	# One enemy, not a blast: a piercing projectile outside combat needs to know
	# which enemy it struck so it can decline to strike the same one twice.
	for enemy in _enemies:
		if not enemy.active or enemy.id == ignored_enemy_id:
			continue
		if enemy.position.distance_to(center) > radius + enemy.radius:
			continue
		var struck := enemy.id
		_damage_enemy(enemy, damage, death_source, 0)
		return struck
	return -1


func get_active_enemy_ids() -> PackedInt32Array:
	# Paired with get_active_enemy_positions by index, so a component outside combat
	# can keep its own per-enemy state without reaching into enemy objects.
	var ids := PackedInt32Array()
	for enemy in _enemies:
		if enemy.active:
			ids.append(enemy.id)
	return ids


func get_active_enemy_radii() -> PackedFloat32Array:
	## Paired by index with get_active_enemy_ids and get_active_enemy_positions, so a
	## hot loop can read the whole roster once instead of asking for one enemy at a
	## time -- every by-id accessor here is a scan of the pool, and a projectile
	## asking per enemy per frame turns that into millions of iterations.
	var radii := PackedFloat32Array()
	for enemy in _enemies:
		if enemy.active:
			radii.append(enemy.radius)
	return radii


func damage_enemy_by_id(
	enemy_id: int,
	damage: float,
	death_source: int,
	critical: bool = false
) -> bool:
	var enemy := _find_enemy(enemy_id)
	if enemy == null:
		return false
	_damage_enemy(enemy, damage, death_source, 0, critical)
	return true


func get_active_enemy_positions() -> PackedVector2Array:
	# Positions only, so a component outside combat can measure pressure on a place
	# without reaching into enemy state.
	var positions := PackedVector2Array()
	for enemy in _enemies:
		if enemy.active:
			positions.append(enemy.position)
	return positions


func get_enemy_positions_by_role(role: int) -> PackedVector2Array:
	# Positions of one role only, so a path can answer a specific threat without
	# reaching into enemy state or filtering the whole roster itself.
	var positions := PackedVector2Array()
	for enemy in _enemies:
		if enemy.active and enemy.role == role:
			positions.append(enemy.position)
	return positions


func get_nearest_enemy_position(origin: Vector2, maximum_distance: float) -> Vector2:
	# Nearest live enemy to a point, or a negative vector when nothing is in reach.
	var nearest := Vector2(-1.0, -1.0)
	var nearest_distance := maximum_distance * maximum_distance
	for enemy in _enemies:
		if not enemy.active:
			continue
		var distance := enemy.position.distance_squared_to(origin)
		if distance > nearest_distance:
			continue
		nearest_distance = distance
		nearest = enemy.position
	return nearest


func spawn_root_eruption(local_position: Vector2) -> void:
	# Public entry point for mechanics outside combat that erupt the ground, such
	# as a Root eruption fired from an evolution rather than from thorn contact.
	_spawn_root_eruption(local_position)


func apply_entanglement_in_radius(
	center: Vector2,
	radius: float,
	entanglement_gain: float
) -> void:
	_apply_entanglement_in_radius(center, radius, entanglement_gain)


func root_entangled_enemies_in_radius(
	center: Vector2,
	radius: float,
	threshold: float,
	root_seconds: float
) -> int:
	# Tangleburst: germination pins whatever was already tangled enough to catch.
	var rooted := 0
	for enemy in _enemies:
		if not enemy.active or enemy.entanglement < threshold:
			continue
		if enemy.position.distance_to(center) > radius + enemy.radius:
			continue
		if not territory_field.is_growth_path_clear(center, enemy.position):
			continue
		enemy.bramble_root_remaining = maxf(enemy.bramble_root_remaining, root_seconds)
		enemy.bramble_root_duration = maxf(
			enemy.bramble_root_duration,
			enemy.bramble_root_remaining
		)
		rooted += 1
	return rooted


func pull_enemies_toward(center: Vector2, radius: float, pull_pixels: float) -> void:
	# Constricting Growth: drag nearby enemies inward as the Green expands. Reuses
	# the stepped shove so nothing is dragged through basalt.
	if pull_pixels <= 0.0:
		return
	for enemy in _enemies:
		if not enemy.active:
			continue
		var offset := center - enemy.position
		var distance := offset.length()
		if distance > radius + enemy.radius or distance <= 1.0:
			continue
		if not territory_field.is_growth_path_clear(center, enemy.position):
			continue
		_begin_knockback(enemy, offset / distance, minf(pull_pixels, distance - 1.0))


func apply_mass_entanglement(center: Vector2, radius: float) -> int:
	# Mass Entanglement: normal enemies caught are pinned outright, elites and
	# bosses take a reduced share so the pulse cannot trivialise them.
	var caught := 0
	for enemy in _enemies:
		if not enemy.active:
			continue
		if enemy.position.distance_to(center) > radius + enemy.radius:
			continue
		if not territory_field.is_growth_path_clear(center, enemy.position):
			continue
		var share := 1.0
		if enemy.role == EnemyRole.BOSS:
			share = _mass_entanglement_boss_share
		elif enemy.role == EnemyRole.ELITE:
			share = _mass_entanglement_elite_share
		enemy.entanglement = minf(1.0, enemy.entanglement + share)
		caught += 1
	return caught


func set_mass_entanglement_shares(elite_share: float, boss_share: float) -> void:
	_mass_entanglement_elite_share = clampf(elite_share, 0.0, 1.0)
	_mass_entanglement_boss_share = clampf(boss_share, 0.0, 1.0)


func get_enemy_entanglement(enemy_id: int) -> float:
	var enemy := _find_enemy(enemy_id)
	return enemy.entanglement if enemy != null else 0.0


func get_cane_damage_multiplier() -> float:
	## What the run's Vine investment has made one stroke worth. Published so the
	## relics that deal a share of a Vine hit read the same number the stroke did.
	return _cane_damage_multiplier


func get_enemy_radius(enemy_id: int) -> float:
	var enemy := _find_enemy(enemy_id)
	return enemy.radius if enemy != null else 0.0


func get_enemy_spore(enemy_id: int) -> float:
	var enemy := _find_enemy(enemy_id)
	return enemy.spore if enemy != null else 0.0


func is_enemy_overgrown(enemy_id: int) -> bool:
	var enemy := _find_enemy(enemy_id)
	return enemy != null and enemy.overgrown


func add_spore_to_enemy(enemy_id: int, amount: float) -> float:
	var enemy := _find_enemy(enemy_id)
	if enemy == null or amount <= 0.0:
		return 0.0
	_add_enemy_spore(enemy, amount)
	return enemy.spore


func add_entanglement_to_enemy(enemy_id: int, amount: float) -> float:
	var enemy := _find_enemy(enemy_id)
	if enemy == null or amount <= 0.0:
		return 0.0
	enemy.entanglement = clampf(enemy.entanglement + amount, 0.0, 1.0)
	return enemy.entanglement


func knockback_enemy_from(enemy_id: int, origin: Vector2, distance: float) -> bool:
	var enemy := _find_enemy(enemy_id)
	if enemy == null or distance <= 0.0:
		return false
	var direction := origin.direction_to(enemy.position)
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	_begin_knockback(enemy, direction, distance)
	return true


func collapse_overgrown_enemy(
	enemy_id: int,
	elite_max_health_share: float,
	boss_max_health_share: float,
	death_source: int
) -> bool:
	## A bounded public collapse for Mycelial Vine and Inoculator. Normal enemies
	## die; elites and bosses cash the completed infection out as authored max-health
	## damage while remaining Overgrown.
	var enemy := _find_enemy(enemy_id)
	if enemy == null or not enemy.overgrown:
		return false
	var damage := enemy.health + 1.0
	if enemy.role == EnemyRole.ELITE:
		damage = enemy.maximum_health * clampf(elite_max_health_share, 0.0, 1.0)
	elif enemy.role == EnemyRole.BOSS:
		damage = enemy.maximum_health * clampf(boss_max_health_share, 0.0, 1.0)
	_damage_enemy(enemy, damage, death_source, 0)
	return true


func get_bramble_tick_damage(enemy: EnemyState, contact_strength: float) -> float:
	# Every enemy resolves its own full calculation from its own Entanglement.
	# Thorn damage is never divided between the enemies sharing a stretch of Green.
	# Chip damage only. There is no Thorn Damage line: the flat and max-health parts
	# are fixed, and everything that grows comes from control and the Evolutions.
	var base_damage := (
		bramble_contact_damage
		+ enemy.maximum_health * bramble_max_health_damage_fraction
	)
	var entanglement_multiplier := lerpf(
		1.0,
		bramble_entangled_damage_multiplier,
		clampf(enemy.entanglement, 0.0, 1.0)
	)
	var frontier_multiplier := (
		1.0 + bramble_frontier_damage_bonus * enemy.bramble_frontier_strength
	)
	var horde_multiplier := 1.0 + minf(
		float(enemy.bramble_horde_count) * bramble_horde_damage_per_attacker,
		bramble_horde_damage_maximum_bonus
	)
	return (
		base_damage
		* contact_strength
		* entanglement_multiplier
		* frontier_multiplier
		* horde_multiplier
		* _get_root_network_multiplier(enemy.position, enemy.bramble_ground_maturity)
	)


func repel_territory_attacker(enemy: EnemyState) -> void:
	# Repulsion answers enemies that actively damage Green, which is what makes it
	# the Grazer's problem: a Grazer is shoved off the ground it is eating instead
	# of being handed free damage. The per-enemy cooldown keeps a fast grazing
	# cadence from firing dozens of shoves a second.
	if (
		not _bramble_enabled
		or _bramble_repulsion_pixels <= 0.0
		or enemy.bramble_repulsion_remaining > 0.0
	):
		return
	if territory_field.get_bramble_coverage_at_local(enemy.position) <= 0.0:
		return
	# Inside a Living Rampart the ground answers far more often, which is the
	# whole of what a Rampart is: the same rule, on a shorter clock.
	enemy.bramble_repulsion_remaining = bramble_repulsion_cooldown_seconds
	if is_in_rampart(enemy.position):
		enemy.bramble_repulsion_remaining *= _rampart_repulsion_multiplier
	var distance := _bramble_repulsion_pixels * _get_root_network_multiplier(
		enemy.position,
		enemy.bramble_ground_maturity
	)
	var escape := _get_territory_escape_direction(enemy.position)
	var shove_origin := enemy.position
	_begin_knockback(enemy, escape, distance)
	enemy.hit_flash_remaining = enemy_hit_flash_seconds
	enemy.hit_flash_color = _get_damage_feedback_color(DeathSource.BRAMBLE)
	enemy_repelled.emit(enemy.id, shove_origin, escape)


func _get_territory_escape_direction(local_position: Vector2) -> Vector2:
	# Shove down the territory gradient, so an enemy is pushed toward the nearest
	# way out of the Green rather than blindly away from the player.
	var pixels_per_cell := (
		territory_field.tuning.arena_size.x / float(territory_field.tuning.field_size.x)
	)
	var step := maxf(1.0, pixels_per_cell)
	var gradient := Vector2(
		territory_field.get_control_at_local(local_position + Vector2(step, 0.0))
		- territory_field.get_control_at_local(local_position - Vector2(step, 0.0)),
		territory_field.get_control_at_local(local_position + Vector2(0.0, step))
		- territory_field.get_control_at_local(local_position - Vector2(0.0, step))
	)
	if gradient.length_squared() > 0.000001:
		return -gradient.normalized()
	# Uniform Green in every direction: fall back to shoving straight away from the
	# player, which is the direction the territory is being defended from.
	var away := local_position - player.get_arena_position()
	if away.length_squared() > 0.000001:
		return away.normalized()
	return Vector2.RIGHT


func _begin_knockback(enemy: EnemyState, direction: Vector2, distance: float) -> void:
	# The shove travels over time instead of teleporting: a repelled enemy visibly
	# slides back out of the territory, which is the whole point of the effect
	# reading as crowd control.
	if direction.length_squared() <= 0.000001 or distance <= 0.0:
		return
	# What an immovable archetype actually is. Heavy Grazer and Unstoppable both come
	# through here rather than each refusing the shove somewhere of their own, so
	# there is one place that decides whether a body moves.
	distance *= 1.0 - clampf(enemy.knockback_resistance, 0.0, 1.0)
	if distance <= 0.0:
		return
	var duration := maxf(0.01, bramble_repulsion_seconds)
	enemy.knockback_direction = direction.normalized()
	enemy.knockback_remaining = duration
	# Speed eases linearly to zero across the window, so the travelled distance is
	# the area under that ramp: an opening speed of twice the average delivers it.
	enemy.knockback_speed = 2.0 * distance / duration


func _advance_knockback(enemy: EnemyState, delta: float) -> void:
	if enemy.knockback_remaining <= 0.0:
		return
	var duration := maxf(0.01, bramble_repulsion_seconds)
	var eased_speed := enemy.knockback_speed * clampf(
		enemy.knockback_remaining / duration,
		0.0,
		1.0
	)
	var travel := eased_speed * minf(delta, enemy.knockback_remaining)
	enemy.knockback_remaining = maxf(0.0, enemy.knockback_remaining - delta)
	if travel <= 0.0:
		return
	# Stepped rather than jumped, so a shove never pushes an enemy through basalt
	# or off the field; hitting anything solid simply ends the slide there.
	var step := maxf(1.0, bramble_repulsion_step_pixels)
	var travelled := 0.0
	while travelled < travel:
		var advance := minf(step, travel - travelled)
		if not _try_set_enemy_position(
			enemy,
			enemy.position + enemy.knockback_direction * advance
		):
			enemy.knockback_remaining = 0.0
			return
		travelled += advance


func _try_root_entangled_enemy(enemy: EnemyState) -> void:
	# Grasping Roots: maximum Entanglement pins the enemy outright. The immunity
	# window means a camper is held repeatedly rather than held forever.
	if (
		_bramble_root_seconds <= 0.0
		or enemy.entanglement < 1.0
		or enemy.bramble_root_remaining > 0.0
		or enemy.bramble_root_immunity_remaining > 0.0
	):
		return
	enemy.bramble_root_remaining = _bramble_root_seconds
	enemy.bramble_root_duration = _bramble_root_seconds
	enemy.bramble_root_immunity_remaining = (
		_bramble_root_seconds + _bramble_root_immunity_seconds
	)
	_spawn_root_eruption(enemy.position)
	enemy_rooted.emit(enemy.position)


func get_enemy_root_remaining(enemy_id: int) -> float:
	var enemy := _find_enemy(enemy_id)
	return enemy.bramble_root_remaining if enemy != null else 0.0


func _try_erupt_root_network(enemy: EnemyState) -> void:
	# Old Growth: an enemy that stays long enough on ancient ground to become
	# heavily Entangled is seized by the Root Network itself.
	if (
		not _old_growth_enabled
		or enemy.bramble_eruption_remaining > 0.0
		or enemy.entanglement < minf(
			old_growth_eruption_entanglement,
			_ancient_fury_trigger_threshold
		)
		or not territory_field.is_mature_player_territory_at_local(enemy.position)
	):
		return
	enemy.bramble_eruption_remaining = old_growth_eruption_cooldown_seconds
	_erupt_root_network(enemy.position, 0)


func _erupt_root_network(local_position: Vector2, chain_depth: int) -> void:
	_spawn_root_eruption(local_position)
	play_old_growth_sfx()
	var age_fraction := territory_field.get_age_fraction_at_local(local_position)
	var damage := (
		old_growth_eruption_damage
		* (1.0 + old_growth_eruption_age_bonus * age_fraction)
	)
	if chain_depth > 0 and _ancient_fury_chain_damage_share > 0.0:
		# A chained eruption hits softer than the one that spawned it, which is what
		# keeps a cascade from compounding without bound.
		damage *= pow(_ancient_fury_chain_damage_share, float(chain_depth))
	var radius := old_growth_eruption_radius_pixels * (1.0 + _ancient_fury_radius_bonus)
	damage_enemies_in_radius(
		local_position,
		radius,
		damage,
		DeathSource.ROOT_ERUPTION,
		chain_depth
	)
	_apply_entanglement_in_radius(
		local_position,
		radius,
		maxf(old_growth_eruption_entanglement_gain, _ancient_fury_entanglement)
	)


func _apply_entanglement_in_radius(
	center: Vector2,
	radius: float,
	entanglement_gain: float
) -> void:
	if entanglement_gain <= 0.0:
		return
	for enemy in _enemies:
		if not enemy.active:
			continue
		if enemy.position.distance_to(center) > radius + enemy.radius:
			continue
		if not territory_field.is_growth_path_clear(center, enemy.position):
			continue
		enemy.entanglement = minf(1.0, enemy.entanglement + entanglement_gain)


func _queue_chained_eruption(local_position: Vector2, chain_depth: int) -> void:
	# Kills inside the Root Network wake the ground under the next enemy, so a large
	# mob standing on ancient territory cascades instead of dying one at a time.
	if chain_depth > old_growth_eruption_maximum_chain:
		return
	for pending in _pending_eruptions:
		if pending.active:
			continue
		pending.active = true
		pending.position = local_position
		pending.delay_remaining = old_growth_eruption_chain_delay_seconds
		pending.chain_depth = chain_depth
		return


func _update_pending_eruptions(delta: float) -> void:
	for pending in _pending_eruptions:
		if not pending.active:
			continue
		pending.delay_remaining -= delta
		if pending.delay_remaining > 0.0:
			continue
		pending.active = false
		_erupt_root_network(pending.position, pending.chain_depth)


func _update_forest_awakening(delta: float) -> void:
	# Level five: enough heavily Entangled enemies standing on ancient ground at
	# once and the whole forest answers, on a global cooldown.
	_ancient_fury_awakening_remaining = maxf(
		0.0,
		_ancient_fury_awakening_remaining - delta
	)
	if (
		not _old_growth_enabled
		or _ancient_fury_awakening_eruptions <= 0
		or _ancient_fury_awakening_enemies <= 0
		or _ancient_fury_awakening_remaining > 0.0
	):
		return
	var qualifying: Array[EnemyState] = []
	for enemy in _enemies:
		if not enemy.active or enemy.entanglement < _ancient_fury_trigger_threshold:
			continue
		if not territory_field.is_mature_player_territory_at_local(enemy.position):
			continue
		qualifying.append(enemy)
	if qualifying.size() < _ancient_fury_awakening_enemies:
		return
	_ancient_fury_awakening_remaining = _ancient_fury_awakening_cooldown
	for index in range(mini(_ancient_fury_awakening_eruptions, qualifying.size())):
		_erupt_root_network(qualifying[index].position, 0)


func get_forest_awakening_remaining() -> float:
	return _ancient_fury_awakening_remaining


func set_evolution_upgrade_modifiers(
	briar_payload_trigger_bonus: float,
	briar_payload_chain_bonus: float,
	briar_payload_entanglement: float,
	briar_payload_heart_cadence: int,
	ancient_fury_radius_bonus: float,
	ancient_fury_entanglement: float,
	ancient_fury_chain_damage_share: float,
	ancient_fury_chains_enabled: bool,
	ancient_fury_trigger_threshold: float,
	ancient_fury_awakening_enemies: int,
	ancient_fury_awakening_eruptions: int,
	ancient_fury_awakening_cooldown: float
) -> void:
	_briar_payload_trigger_bonus = maxf(0.0, briar_payload_trigger_bonus)
	_briar_payload_chain_bonus = maxf(0.0, briar_payload_chain_bonus)
	_briar_payload_entanglement = clampf(briar_payload_entanglement, 0.0, 1.0)
	_briar_payload_heart_cadence = maxi(0, briar_payload_heart_cadence)
	_ancient_fury_radius_bonus = maxf(0.0, ancient_fury_radius_bonus)
	_ancient_fury_entanglement = clampf(ancient_fury_entanglement, 0.0, 1.0)
	_ancient_fury_chain_damage_share = clampf(ancient_fury_chain_damage_share, 0.0, 1.0)
	_ancient_fury_chains_enabled = ancient_fury_chains_enabled
	_ancient_fury_trigger_threshold = clampf(ancient_fury_trigger_threshold, 0.05, 1.0)
	_ancient_fury_awakening_enemies = maxi(0, ancient_fury_awakening_enemies)
	_ancient_fury_awakening_eruptions = maxi(0, ancient_fury_awakening_eruptions)
	_ancient_fury_awakening_cooldown = maxf(0.5, ancient_fury_awakening_cooldown)


func _update_bramble_horde_pressure(delta: float) -> void:
	if not _bramble_enabled:
		return
	_bramble_horde_refresh_remaining -= delta
	if _bramble_horde_refresh_remaining > 0.0:
		return
	_bramble_horde_refresh_remaining = bramble_horde_refresh_seconds
	_refresh_bramble_horde_counts()


func _decay_entanglement(enemy: EnemyState, delta: float) -> void:
	# Entanglement fades rather than resetting, so briefly stepping off Green does
	# not shake off thorns an enemy has already worked itself into.
	var decay := bramble_entanglement_decay_per_second
	enemy.entanglement = maxf(0.0, enemy.entanglement - decay * delta)


func _refresh_bramble_horde_counts() -> void:
	# Recounted on a cadence rather than every frame: the pairwise scan only ever
	# covers enemies already touching a boundary, and one stale frame is invisible.
	_bramble_attackers.clear()
	for enemy in _enemies:
		if not enemy.active:
			continue
		enemy.bramble_horde_count = 0
		if enemy.was_on_bramble:
			_bramble_attackers.append(enemy)
	var radius_squared := bramble_horde_radius_pixels * bramble_horde_radius_pixels
	for index in range(_bramble_attackers.size()):
		var attacker := _bramble_attackers[index]
		for other_index in range(index + 1, _bramble_attackers.size()):
			var other := _bramble_attackers[other_index]
			if attacker.position.distance_squared_to(other.position) <= radius_squared:
				attacker.bramble_horde_count += 1
				other.bramble_horde_count += 1


func _get_briar_pod_strength(local_position: Vector2) -> float:
	# One strength per enemy per tick. Every ring the enemy touches competes for the
	# maximum instead of contributing its own damage, so overlapping Briar Pods
	# cannot multiply thorn damage.
	var strength := 0.0
	for zone in _bramble_zones:
		if not zone.active:
			continue
		var ring_distance := absf(local_position.distance_to(zone.position) - zone.radius)
		if (
			ring_distance <= bramble_frontier_band_pixels
			and territory_field.is_growth_path_clear(zone.position, local_position)
		):
			strength = maxf(strength, zone.contact_multiplier)
	return strength


func _spawn_root_eruption(local_position: Vector2) -> void:
	var selected: RootEruptionState
	for eruption in _root_eruptions:
		if not eruption.active:
			selected = eruption
			break
		if selected == null or eruption.remaining < selected.remaining:
			selected = eruption
	if selected == null:
		return
	selected.active = true
	selected.position = local_position
	selected.remaining = old_growth_eruption_seconds
	selected.duration = selected.remaining
	_root_eruption_sequence += 1
	selected.seed = _root_eruption_sequence


func _update_root_eruptions(delta: float) -> void:
	for eruption in _root_eruptions:
		if not eruption.active:
			continue
		eruption.remaining -= delta
		if eruption.remaining <= 0.0:
			eruption.active = false


func get_active_root_eruption_count() -> int:
	var count := 0
	for eruption in _root_eruptions:
		if eruption.active:
			count += 1
	return count


func _draw_root_eruption(eruption: RootEruptionState) -> void:
	var progress := 1.0 - clampf(eruption.remaining / eruption.duration, 0.0, 1.0)
	var rise := sin(progress * PI)
	var root_color := Color(0.30, 0.20, 0.10, 0.85 * rise)
	var thorn_color := Color(0.62, 0.92, 0.38, 0.95 * rise)
	for spike_index in range(5):
		var angle := (
			float(spike_index) * TAU / 5.0
			+ float(eruption.seed % 7) * 0.31
		)
		var direction := Vector2.from_angle(angle)
		var base_point := eruption.position + direction * 3.0
		var tip := eruption.position + direction * (5.0 + 9.0 * rise)
		draw_line(base_point, tip, root_color, 2.4)
		draw_line(tip - direction * 3.0, tip, thorn_color, 1.4)


func _update_briar_pods(delta: float) -> void:
	for zone in _bramble_zones:
		if not zone.active:
			continue
		zone.remaining -= delta
		if zone.remaining <= 0.0:
			zone.active = false


func _perform_enemy_territory_action(enemy: EnemyState) -> void:
	# Suppression is taken here, at the single point every territory behaviour reads
	# its strength from, so grazing, hostile conversion, spread and a Saboteur's
	# cutting are all weakened by one rule rather than four.
	var scaled_strength := (
		enemy.territory_action_strength
		* enemy.territory_erosion_scale
		* enemy.territory_escalation
		* (1.0 - clampf(enemy.suppression_share, 0.0, 1.0))
	)
	# Uninterrupted work compounds. The Siege Corruptor carries this on its profile and
	# Ravenous grants it to any elite, so "if ignored" is one mechanic with two owners
	# rather than two mechanics that happen to look alike.
	var escalation := enemy.territory_action_escalation
	if enemy.elite_modifier == EliteModifier.RAVENOUS:
		escalation = maxf(escalation, ravenous_escalation)
	if escalation > 1.0:
		enemy.territory_escalation = minf(
			enemy.territory_escalation * escalation,
			maxf(1.0, enemy.territory_action_escalation_cap)
		)
	# Repulsion answers anything that weakens Green, not erosion alone: grazing,
	# hostile conversion and spread, maturity suppression, a colony planted in the
	# territory, and a Saboteur cutting down a catalyst standing on it all count.
	var weakened_territory := false
	match enemy.territory_behavior:
		PhaseBEnemyProfile.TerritoryBehavior.GRAZE_GREEN, PhaseBEnemyProfile.TerritoryBehavior.ERUPTION:
			territory_field.queue_erosion(
				enemy.position,
				scaled_strength,
				enemy.territory_action_radius_multiplier
			)
			# The seconds this bite represents, so a relic can count grazing time
			# without watching every enemy every frame.
			enemy_ate_green.emit(
				enemy.id, scaled_strength, maxf(0.0, enemy.territory_action_interval)
			)
			weakened_territory = true
			if enemy.emit_eruption_signal:
				boss_erupted.emit(enemy.position)
		PhaseBEnemyProfile.TerritoryBehavior.SABOTAGE_CATALYST:
			var pixels_per_cell := (
				territory_field.tuning.arena_size.x
				/ float(territory_field.tuning.field_size.x)
			)
			var action_radius := (
				territory_field.tuning.grazer_radius_cells
				* pixels_per_cell
				* enemy.territory_action_radius_multiplier
			)
			var damaged_catalyst := overlay.damage_nearest_catalyst(
				enemy.position,
				action_radius,
				scaled_strength
			)
			weakened_territory = damaged_catalyst
			if (
				not damaged_catalyst
				and territory_field.get_control_at_local(enemy.position)
				> territory_field.tuning.ownership_threshold
				and territory_field.get_maturity_at_local(enemy.position)
				<= enemy.fresh_maturity_threshold
			):
				territory_field.queue_erosion(
					enemy.position,
					scaled_strength,
					enemy.territory_action_radius_multiplier
				)
				weakened_territory = true
		PhaseBEnemyProfile.TerritoryBehavior.CORRUPT_GREEN, PhaseBEnemyProfile.TerritoryBehavior.SPREAD_HOSTILE:
			territory_field.queue_hostile_growth(
				enemy.position,
				scaled_strength,
				enemy.territory_action_radius_multiplier
			)
			weakened_territory = true
		PhaseBEnemyProfile.TerritoryBehavior.ESTABLISH_COLONY:
			weakened_territory = _try_establish_colony_core(enemy)
		PhaseBEnemyProfile.TerritoryBehavior.SUPPRESS_MATURITY:
			territory_field.queue_maturity_suppression(
				enemy.position,
				scaled_strength,
				enemy.territory_action_radius_multiplier
			)
			weakened_territory = true
	if weakened_territory:
		# The shove itself still requires the attacker to be standing on Green, so
		# an enemy working on ground the player does not hold is left alone.
		repel_territory_attacker(enemy)


func _try_establish_colony_core(colonizer: EnemyState) -> bool:
	if colonizer.maximum_active_summons <= 0:
		return false
	if get_active_enemy_count_by_role(EnemyRole.COLONY_CORE) >= colonizer.maximum_active_summons:
		return false
	var minimum_spacing_squared := colonizer.summon_spacing_pixels * colonizer.summon_spacing_pixels
	for enemy in _enemies:
		if not enemy.active or enemy.role != EnemyRole.COLONY_CORE:
			continue
		if enemy.position.distance_squared_to(colonizer.position) < minimum_spacing_squared:
			return false
	# A Colonizer holding position against a wall can be overlapping it, and a core
	# planted there is unkillable rather than merely awkward: every radial source checks
	# is_growth_path_clear from its centre to the target, and there is no direction from
	# which a line reaches into solid rock. The run then cannot be won, because clearing
	# the field is a victory condition.
	var site := _find_colony_core_site(colonizer.position)
	if site == Vector2.INF:
		return false
	return spawn_enemy(EnemyRole.COLONY_CORE, site) != -1


func _find_colony_core_site(wanted: Vector2) -> Vector2:
	## The nearest place a colony core can stand and still be fought, or Vector2.INF if
	## there is none nearby. Refusing the placement is deliberate: a Colonizer that finds
	## nowhere legal should waste its action rather than plant something invincible.
	var radius := colony_core_profile.body_radius_pixels
	if territory_field.is_diamond_claimable_at_local(wanted, radius):
		return wanted
	# Outward in rings, nearest first, so a core pressed against a wall steps just clear
	# of it instead of teleporting somewhere the Colonizer never went.
	var step := maxf(4.0, radius * 0.5)
	var rings := int(ceil(colony_core_relocation_pixels / step))
	for ring in range(1, rings + 1):
		var distance := float(ring) * step
		var samples := 8 * ring
		for sample in range(samples):
			var angle := TAU * float(sample) / float(samples)
			var candidate := wanted + Vector2.from_angle(angle) * distance
			if territory_field.is_diamond_claimable_at_local(candidate, radius):
				return candidate
	return Vector2.INF


func _update_damage_numbers(delta: float) -> void:
	for index in range(_damage_numbers.size()):
		var damage_number := _damage_numbers[index]
		if not damage_number.active:
			continue
		damage_number.age += delta
		if damage_number.age >= damage_number_lifetime_seconds:
			damage_number.active = false
			# Freeing a slot can only lower where the next free-slot search starts.
			_damage_number_free_cursor = mini(_damage_number_free_cursor, index)
			continue
		damage_number.position += damage_number.velocity * delta


func _update_projectiles(delta: float) -> void:
	for projectile in _projectiles:
		if not projectile.active:
			continue
		projectile.remaining -= delta
		if projectile.remaining <= 0.0:
			projectile.active = false
			continue
		var previous_position := projectile.position
		var requested_distance := projectile.velocity.length() * delta
		var travel_distance := minf(requested_distance, projectile.remaining_distance)
		var next_position := previous_position + projectile.velocity.normalized() * travel_distance
		projectile.remaining_distance -= travel_distance
		var segment_min_x := minf(previous_position.x, next_position.x)
		var segment_max_x := maxf(previous_position.x, next_position.x)
		var segment_min_y := minf(previous_position.y, next_position.y)
		var segment_max_y := maxf(previous_position.y, next_position.y)
		for enemy in _enemies:
			if not enemy.active or enemy.id == projectile.last_hit_enemy_id:
				continue
			var hit_radius := enemy.radius + 3.0
			if (
				enemy.position.x < segment_min_x - hit_radius
				or enemy.position.x > segment_max_x + hit_radius
				or enemy.position.y < segment_min_y - hit_radius
				or enemy.position.y > segment_max_y + hit_radius
			):
				continue
			if (
				_distance_squared_to_segment(enemy.position, previous_position, next_position)
				> hit_radius * hit_radius
			):
				continue
			if not territory_field.is_growth_path_clear(previous_position, enemy.position):
				continue
			projectile.last_hit_enemy_id = enemy.id
			_damage_enemy(enemy, projectile.damage, DeathSource.DEBUG, 0)
			projectile.pierce_remaining -= 1
			if projectile.pierce_remaining <= 0:
				projectile.active = false
				break
		if not projectile.active:
			continue
		if not territory_field.is_growth_path_clear(previous_position, next_position):
			projectile.active = false
			continue
		projectile.position = next_position
		if projectile.remaining_distance <= 0.001:
			projectile.active = false


func _update_pickups(delta: float) -> void:
	var player_position := player.get_arena_position()
	var attraction_radius_squared := 165.0 * 165.0
	var collect_radius := player.body_radius_pixels + 7.0
	var collect_radius_squared := collect_radius * collect_radius
	for pickup in _pickups:
		if not pickup.active:
			continue
		pickup.age += delta
		var distance_squared := pickup.position.distance_squared_to(player_position)
		if distance_squared < attraction_radius_squared or pickup.age > 7.0:
			var distance := sqrt(distance_squared)
			var speed := 120.0 + maxf(0.0, 170.0 - distance) * 1.7
			pickup.position = pickup.position.move_toward(player_position, speed * delta)
			distance_squared = pickup.position.distance_squared_to(player_position)
		if distance_squared <= collect_radius_squared:
			pickup.active = false
			_play_xp_collect_sfx()
			xp_collected.emit(pickup.xp_value)


func _update_xp_collect_pitch(delta: float) -> void:
	if _xp_collect_pitch_reset_remaining <= 0.0:
		return
	_xp_collect_pitch_reset_remaining = maxf(
		0.0,
		_xp_collect_pitch_reset_remaining - delta
	)
	if _xp_collect_pitch_reset_remaining <= 0.0:
		_xp_collect_chain_count = 0
		_last_xp_collect_pitch_scale = 1.0


func _play_xp_collect_sfx() -> void:
	if _xp_collect_audio_voices.is_empty() or xp_collect_sfx == null:
		return
	var semitone_offset := (
		float(_xp_collect_chain_count) * xp_collect_pitch_step_semitones
	)
	var pitch_scale := minf(
		xp_collect_max_pitch_scale,
		pow(2.0, semitone_offset / 12.0)
	)
	var audio_voice := _xp_collect_audio_voices[_xp_collect_voice_cursor]
	audio_voice.stop()
	audio_voice.pitch_scale = pitch_scale
	audio_voice.play()
	_xp_collect_voice_cursor = (
		(_xp_collect_voice_cursor + 1) % _xp_collect_audio_voices.size()
	)
	_xp_collect_chain_count += 1
	_xp_collect_pitch_reset_remaining = xp_collect_pitch_reset_seconds
	_last_xp_collect_pitch_scale = pitch_scale
	_xp_collect_sfx_play_count += 1


func _move_enemy(
	enemy: EnemyState,
	target_position: Vector2,
	delta: float,
	use_catalyst_navigation: bool = false
) -> void:
	var direct_direction := enemy.position.direction_to(target_position)
	if direct_direction.length_squared() <= 0.001:
		return
	var distance := enemy.speed * enemy.movement_speed_multiplier * delta
	enemy.path_check_remaining -= delta
	if enemy.path_check_remaining <= 0.0:
		enemy.direct_path_clear = territory_field.is_growth_path_clear(
			enemy.position,
			target_position
		)
		enemy.path_check_remaining = navigation_refresh_seconds
	if enemy.direct_path_clear:
		# Only accept the direct chase when the whole collision proxy can advance.
		# Axis sliding here can keep reselecting the same blocked wall corner and
		# prevent the flow field from guiding the enemy around it.
		if _try_set_enemy_position(enemy, enemy.position + direct_direction * distance):
			return
	var navigation_waypoint := _get_navigation_waypoint(enemy, use_catalyst_navigation)
	var navigation_direction := enemy.position.direction_to(navigation_waypoint)
	if navigation_direction.length_squared() <= 0.001:
		navigation_direction = direct_direction
	var navigation_distance := minf(distance, enemy.position.distance_to(navigation_waypoint))
	if navigation_distance <= 0.001:
		navigation_distance = distance
	var side := -1.0 if enemy.id % 2 == 0 else 1.0
	for angle in STEERING_ANGLES:
		if _try_move_enemy(
			enemy,
			navigation_direction.rotated(angle * side),
			navigation_distance
		):
			return


func _try_move_enemy(enemy: EnemyState, direction: Vector2, distance: float) -> bool:
	var motion := direction * distance
	if _try_set_enemy_position(enemy, enemy.position + motion):
		return true
	var horizontal_motion := Vector2(motion.x, 0.0)
	var vertical_motion := Vector2(0.0, motion.y)
	if absf(motion.x) >= absf(motion.y):
		if absf(horizontal_motion.x) > 0.001 and _try_set_enemy_position(
			enemy,
			enemy.position + horizontal_motion
		):
			return true
		if absf(vertical_motion.y) > 0.001 and _try_set_enemy_position(
			enemy,
			enemy.position + vertical_motion
		):
			return true
	else:
		if absf(vertical_motion.y) > 0.001 and _try_set_enemy_position(
			enemy,
			enemy.position + vertical_motion
		):
			return true
		if absf(horizontal_motion.x) > 0.001 and _try_set_enemy_position(
			enemy,
			enemy.position + horizontal_motion
		):
			return true
	return false


func _try_set_enemy_position(enemy: EnemyState, candidate: Vector2) -> bool:
	if not _can_occupy_diamond(candidate, enemy.collision_radius):
		return false
	enemy.position = candidate
	return true


func _update_navigation(player_position: Vector2, delta: float) -> void:
	_navigation_refresh_remaining -= delta
	if _navigation_refresh_remaining > 0.0:
		return
	_navigation_refresh_remaining = navigation_refresh_seconds
	var target_cell := _local_to_navigation_cell(player_position)
	var target_x := target_cell.x
	var target_y := target_cell.y
	var target_index := target_y * _navigation_width + target_x
	if target_index != _navigation_small_target_index:
		_navigation_small_target_index = target_index
		_rebuild_navigation_distances(
			_navigation_small_distances,
			_navigation_small_walkable,
			target_index
		)
	if has_active_boss() and target_index != _navigation_boss_target_index:
		_navigation_boss_target_index = target_index
		_rebuild_navigation_distances(
			_navigation_boss_distances,
			_navigation_boss_walkable,
			target_index
		)
	var catalyst_position := Vector2(-99999.0, -99999.0)
	var catalyst_distance_squared := INF
	for enemy in _enemies:
		if not enemy.active or enemy.role != EnemyRole.SABOTEUR:
			continue
		var candidate := overlay.get_nearest_catalyst_position(
			enemy.position,
			enemy.catalyst_search_range_pixels,
			false
		)
		if candidate.x <= -90000.0:
			continue
		var candidate_distance_squared := enemy.position.distance_squared_to(candidate)
		if candidate_distance_squared < catalyst_distance_squared:
			catalyst_distance_squared = candidate_distance_squared
			catalyst_position = candidate
	var catalyst_target_index := -1
	if catalyst_position.x > -90000.0:
		var catalyst_cell := _local_to_navigation_cell(catalyst_position)
		catalyst_target_index = catalyst_cell.y * _navigation_width + catalyst_cell.x
	_navigation_catalyst_target_position = catalyst_position
	if catalyst_target_index != _navigation_catalyst_target_index:
		_navigation_catalyst_target_index = catalyst_target_index
		if catalyst_target_index >= 0:
			_rebuild_navigation_distances(
				_navigation_catalyst_distances,
				_navigation_small_walkable,
				catalyst_target_index
			)
		else:
			_navigation_catalyst_distances.fill(-1)


func _rebuild_navigation_distances(
	distances: PackedInt32Array,
	walkable: PackedByteArray,
	target_index: int
) -> void:
	distances.fill(-1)
	var start_index := _find_nearest_walkable_index(target_index, walkable)
	if start_index == -1:
		return
	var head := 0
	var tail := 1
	_navigation_queue[0] = start_index
	distances[start_index] = 0
	while head < tail:
		var current_index := _navigation_queue[head]
		head += 1
		var current_x := current_index % _navigation_width
		var current_y := current_index / _navigation_width
		var next_distance := distances[current_index] + 1
		for direction in NAVIGATION_DIRECTIONS:
			var next_x := current_x + direction.x
			var next_y := current_y + direction.y
			if (
				next_x < 0
				or next_y < 0
				or next_x >= _navigation_width
				or next_y >= _navigation_height
			):
				continue
			var next_index := next_y * _navigation_width + next_x
			if walkable[next_index] == 0 or distances[next_index] != -1:
				continue
			distances[next_index] = next_distance
			_navigation_queue[tail] = next_index
			tail += 1


func _find_nearest_walkable_index(target_index: int, walkable: PackedByteArray) -> int:
	if walkable[target_index] != 0:
		return target_index
	var target_x := target_index % _navigation_width
	var target_y := target_index / _navigation_width
	for radius in range(1, 13):
		for offset_y in range(-radius, radius + 1):
			for offset_x in range(-radius, radius + 1):
				if absi(offset_x) != radius and absi(offset_y) != radius:
					continue
				var x := target_x + offset_x
				var y := target_y + offset_y
				if x < 0 or y < 0 or x >= _navigation_width or y >= _navigation_height:
					continue
				var index := y * _navigation_width + x
				if walkable[index] != 0:
					return index
	return -1


func _local_to_navigation_cell(local_position: Vector2) -> Vector2i:
	var arena_size := territory_field.tuning.arena_size
	return Vector2i(
		clampi(
			int(floor(local_position.x / arena_size.x * float(_navigation_width))),
			0,
			_navigation_width - 1
		),
		clampi(
			int(floor(local_position.y / arena_size.y * float(_navigation_height))),
			0,
			_navigation_height - 1
		)
	)


func _navigation_cell_to_local(cell: Vector2i) -> Vector2:
	var arena_size := territory_field.tuning.arena_size
	return Vector2(
		(float(cell.x) + 0.5) / float(_navigation_width) * arena_size.x,
		(float(cell.y) + 0.5) / float(_navigation_height) * arena_size.y
	)


func _get_navigation_waypoint(
	enemy: EnemyState,
	use_catalyst_navigation: bool = false
) -> Vector2:
	var distances := (
		_navigation_catalyst_distances
		if use_catalyst_navigation
		else (
			_navigation_boss_distances
			if enemy.use_boss_navigation
			else _navigation_small_distances
		)
	)
	var cell := _local_to_navigation_cell(enemy.position)
	var cell_x := cell.x
	var cell_y := cell.y
	var current_index := cell_y * _navigation_width + cell_x
	var current_distance := distances[current_index]
	if current_distance < 0:
		var reachable_index := _find_nearest_reachable_index(enemy, current_index, distances)
		if reachable_index == -1:
			return enemy.position
		var reachable_x := reachable_index % _navigation_width
		var reachable_y := reachable_index / _navigation_width
		return _navigation_cell_to_local(Vector2i(reachable_x, reachable_y))
	var best_index := current_index
	var best_distance := current_distance
	for direction in NAVIGATION_DIRECTIONS:
		var next_x := cell_x + direction.x
		var next_y := cell_y + direction.y
		if (
			next_x < 0
			or next_y < 0
			or next_x >= _navigation_width
			or next_y >= _navigation_height
		):
			continue
		var next_index := next_y * _navigation_width + next_x
		var next_distance := distances[next_index]
		if next_distance >= 0 and next_distance < best_distance:
			best_distance = next_distance
			best_index = next_index
	if best_index == current_index:
		return enemy.position
	var best_x := best_index % _navigation_width
	var best_y := best_index / _navigation_width
	return _navigation_cell_to_local(Vector2i(best_x, best_y))


func _find_nearest_reachable_index(
	enemy: EnemyState,
	origin_index: int,
	distances: PackedInt32Array
) -> int:
	var origin_x := origin_index % _navigation_width
	var origin_y := origin_index / _navigation_width
	for radius in range(1, 9):
		var best_index := -1
		var best_flow_distance := 2147483647
		var best_distance_squared := INF
		for offset_y in range(-radius, radius + 1):
			for offset_x in range(-radius, radius + 1):
				if absi(offset_x) != radius and absi(offset_y) != radius:
					continue
				var x := origin_x + offset_x
				var y := origin_y + offset_y
				if x < 0 or y < 0 or x >= _navigation_width or y >= _navigation_height:
					continue
				var index := y * _navigation_width + x
				if distances[index] < 0:
					continue
				var waypoint := _navigation_cell_to_local(Vector2i(x, y))
				if not territory_field.is_growth_path_clear(enemy.position, waypoint):
					continue
				var distance_squared := enemy.position.distance_squared_to(waypoint)
				var flow_distance := distances[index]
				if (
					flow_distance < best_flow_distance
					or (
						flow_distance == best_flow_distance
						and distance_squared < best_distance_squared
					)
				):
					best_flow_distance = flow_distance
					best_distance_squared = distance_squared
					best_index = index
		if best_index != -1:
			return best_index
	return -1


func _damage_enemy(
	enemy: EnemyState,
	damage: float,
	death_source: int,
	chain_depth: int,
	critical: bool = false
) -> void:
	if not enemy.active or damage <= 0.0:
		return
	# One static read per call, and the timestamp only when it is on. Taking it
	# unconditionally here is what pushed a pairing over budget earlier in this pass:
	# this runs once per enemy per blast, many blasts a frame.
	var measuring := PhaseBPerfCounters.enabled
	var damage_began := Time.get_ticks_usec() if measuring else 0
	if measuring:
		PhaseBPerfCounters.count(PhaseBPerfCounters.COUNT_DAMAGE_CALLS)
	var applied_damage := minf(damage, enemy.health)
	if debug_damage_accounting:
		debug_damage_applied_total += applied_damage
	# Being hit is what "interrupted" means. An escalating enemy loses everything it
	# had built up, which is what makes answering one worth doing at all rather than
	# only worth doing eventually.
	enemy.territory_escalation = 1.0
	if _is_player_damage_source(death_source):
		# Regenerative is explicit that it must be the protagonist. Thorns, Blooms and
		# the ring keep working; they just do not stop it healing, which is what makes
		# it a rule change to a build rather than a larger health pool.
		enemy.regeneration_block_remaining = regenerative_block_seconds
	if death_source != DeathSource.DEBUG:
		enemy.hit_flash_remaining = enemy_hit_flash_seconds
		enemy.hit_flash_color = _get_damage_feedback_color(death_source)
		# What "important" means, decided where the facts are. A hit on an elite or a
		# boss carries information about a fight the player is actually having; so does
		# a hit large enough to be an ability landing rather than a tick of damage.
		# A critical carries information whether it landed for twenty-four or two
		# hundred, which is what the Important Only setting says it keeps. Without
		# this a Thistle crit was filtered out: a thorn hits for 12 and doubles to
		# exactly 24, one point under the threshold, so the whole Adaptation showed
		# no numbers at all on ordinary enemies.
		if critical or damage_number_merge_seconds <= 0.0:
			# Straight through. A critical is the number worth reading on its own, and
			# merging it would be the one case where the aggregate's styling became
			# ambiguous.
			if _should_show_damage_number(enemy, applied_damage, critical):
				_spawn_damage_number(
					enemy.position,
					enemy.radius,
					applied_damage,
					damage_number_critical_color if critical else enemy.hit_flash_color,
					critical
				)
		else:
			if enemy.pending_number_damage <= 0.0:
				enemy.pending_number_remaining = damage_number_merge_seconds
			enemy.pending_number_damage += applied_damage
			enemy.pending_number_color = enemy.hit_flash_color
	enemy.health -= damage
	if enemy.health > 0.0:
		if measuring:
			PhaseBPerfCounters.timer_add_since(
				PhaseBPerfCounters.TIMER_DAMAGE_TOTAL, damage_began
			)
		return
	var death_began := Time.get_ticks_usec() if measuring else 0
	if measuring:
		PhaseBPerfCounters.count(PhaseBPerfCounters.COUNT_DAMAGE_KILLS)
	# Whatever was still accumulating dies with the enemy unless it is shown now, and
	# the killing blow is the one a player most wants to read.
	_flush_pending_damage_number(enemy)
	var role := enemy.role
	var death_position := enemy.position
	var xp_value := enemy.xp_value
	var was_overgrown := enemy.overgrown
	var death_entanglement := enemy.entanglement
	_last_killed_enemy_id = enemy.id
	enemy.active = false
	enemy.state = EnemyStateKind.INACTIVE
	_active_enemy_count = maxi(0, _active_enemy_count - 1)
	_spawn_xp_pickup(death_position, xp_value)
	if was_overgrown:
		# The outbreak spreads from the corpse however the corpse was made: an
		# Overgrown enemy shot dead still bursts. The burst deals no damage, so it
		# cannot kill anything and cannot recurse - it only infects.
		apply_spore_in_radius(
			death_position,
			overgrown_burst_radius_pixels,
			overgrown_burst_spore
		)
	if death_source == DeathSource.ROOT_ERUPTION and _ancient_fury_chains_enabled:
		_queue_chained_eruption(death_position, chain_depth + 1)
	if enemy.elite_modifier == EliteModifier.VOLATILE:
		_detonate_volatile(death_position)
	if death_entanglement > 0.0:
		enemy_died_entangled.emit(death_position, death_entanglement, role)
	enemy_killed.emit(death_position, xp_value, role, death_source, chain_depth)
	if role == EnemyRole.ELITE:
		elite_defeated.emit()
	elif role == EnemyRole.BOSS:
		boss_defeated.emit()
	active_enemy_count_changed.emit(_active_enemy_count)
	if measuring:
		PhaseBPerfCounters.timer_add_since(
			PhaseBPerfCounters.TIMER_DAMAGE_DEATH, death_began
		)
		PhaseBPerfCounters.timer_add_since(
			PhaseBPerfCounters.TIMER_DAMAGE_TOTAL, damage_began
		)


func _spawn_xp_pickup(local_position: Vector2, xp_value: int) -> void:
	var measuring := PhaseBPerfCounters.enabled
	var began := Time.get_ticks_usec() if measuring else 0
	var walked := 0
	for pickup in _pickups:
		walked += 1
		if pickup.active:
			continue
		pickup.active = true
		pickup.position = local_position
		pickup.xp_value = xp_value
		pickup.age = 0.0
		if measuring:
			PhaseBPerfCounters.count(
				PhaseBPerfCounters.COUNT_XP_PICKUP_SLOTS_WALKED, walked
			)
			PhaseBPerfCounters.timer_add_since(
				PhaseBPerfCounters.TIMER_XP_PICKUP_SPAWN, began
			)
		return
	# A saturated pickup pool resolves XP immediately rather than losing progression.
	xp_collected.emit(xp_value)
	if measuring:
		PhaseBPerfCounters.count(
			PhaseBPerfCounters.COUNT_XP_PICKUP_SLOTS_WALKED, walked
		)
		PhaseBPerfCounters.timer_add_since(
			PhaseBPerfCounters.TIMER_XP_PICKUP_SPAWN, began
		)


func _should_show_damage_number(
	enemy: EnemyState,
	shown_damage: float,
	critical: bool
) -> bool:
	## What "important" means, decided where the facts are. A hit on an elite or a
	## boss carries information about a fight the player is actually having; so does
	## one large enough to be an ability landing rather than a tick.
	##
	## A critical carries information whether it landed for twenty-four or two
	## hundred, which is what the Important Only setting says it keeps. Without that a
	## Thistle crit was filtered out entirely: a thorn hits for 12 and doubles to
	## exactly 24, one point under the threshold.
	##
	## Merged damage is judged on its total rather than on the hits that made it,
	## which is what gives Important Only its meaning back: a crowd being chipped now
	## reports once it has been chipped meaningfully, instead of either never or on
	## every tick.
	if display_settings == null:
		return true
	var is_important := (
		critical
		or enemy.role == EnemyRole.ELITE
		or enemy.role == EnemyRole.BOSS
		or enemy.elite_modifier != EliteModifier.NONE
		or shown_damage >= important_damage_number_threshold
	)
	return display_settings.should_show_damage_number(is_important)


func _flush_pending_damage_number(enemy: EnemyState) -> void:
	if enemy.pending_number_damage <= 0.0:
		return
	var total := enemy.pending_number_damage
	enemy.pending_number_damage = 0.0
	enemy.pending_number_remaining = 0.0
	if _should_show_damage_number(enemy, total, false):
		_spawn_damage_number(
			enemy.position, enemy.radius, total, enemy.pending_number_color, false
		)


func _update_pending_damage_numbers(delta: float) -> void:
	for enemy in _enemies:
		if not enemy.active or enemy.pending_number_damage <= 0.0:
			continue
		enemy.pending_number_remaining -= delta
		if enemy.pending_number_remaining <= 0.0:
			_flush_pending_damage_number(enemy)


func _spawn_damage_number(
	local_position: Vector2,
	enemy_radius: float,
	damage: float,
	color: Color,
	critical: bool = false
) -> void:
	if debug_damage_accounting:
		debug_damage_number_total += damage
	var spawn_began := Time.get_ticks_usec() if PhaseBPerfCounters.enabled else 0
	# This used to scan the whole pool for a free slot, and then scan it again for
	# the oldest when the pool was full. A blast landing on a hundred enemies did
	# that a hundred times, which made floating damage numbers -- a cosmetic -- the
	# single largest cost in the worst fixture.
	#
	# The free-slot half is maintained rather than searched for: everything below the
	# cursor is active, so the first inactive slot at or above it is the lowest one in
	# the pool, which is the slot the old scan returned. The full-pool half is still
	# the scan -- see the note where it happens for why the fast version was reverted.
	var selected: DamageNumberState
	var slot := _damage_number_free_cursor
	while slot < _damage_numbers.size():
		if not _damage_numbers[slot].active:
			break
		slot += 1
	if slot < _damage_numbers.size():
		selected = _damage_numbers[slot]
		_damage_number_free_cursor = slot + 1
	else:
		# Pool full. Recycle the oldest, by the original scan.
		#
		# A queue of slots in activation order was tried here, on the reasoning that
		# every number ages at the same rate so activation order is age order. It is
		# not, under sustained saturation, and damage_number_pool_probe caught it
		# recycling a different slot than the scan would. Which number survives a
		# saturated frame is visible, so this stays exact until there is a fast
		# version that provably agrees.
		_damage_number_free_cursor = _damage_numbers.size()
		var oldest_age := -1.0
		for damage_number in _damage_numbers:
			if damage_number.age > oldest_age:
				oldest_age = damage_number.age
				selected = damage_number
	if selected == null:
		if spawn_began > 0:
			PhaseBPerfCounters.timer_add_since(
				PhaseBPerfCounters.TIMER_DAMAGE_NUMBER_SPAWN, spawn_began
			)
		return
	var side := -1.0 if _damage_number_sequence % 2 == 0 else 1.0
	var lateral_speed := 7.0 + float(_damage_number_sequence % 3) * 2.0
	_damage_number_sequence += 1
	selected.active = true
	selected.impact_position = local_position
	selected.position = local_position + Vector2(0.0, -enemy_radius - 18.0)
	selected.velocity = Vector2(
		side * lateral_speed,
		-damage_number_rise_speed_pixels_per_second
	)
	selected.text = str(maxi(1, int(round(damage))))
	selected.color = color
	selected.font_size = (
		damage_number_critical_font_size if critical else damage_number_font_size
	)
	# Measured once here. Doing it in _draw re-shaped every number's text on every
	# frame, which was a third of the whole damage-number draw cost for a string that
	# cannot change after this point.
	if _damage_digit_atlas != null:
		var digit_scale := float(selected.font_size) / _damage_digit_bake_size
		selected.text_size = Vector2(
			_damage_digit_text_width(selected.text), _damage_digit_cell.y
		) * digit_scale
	else:
		selected.text_size = _damage_number_font.get_string_size(
			selected.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			selected.font_size
		)
	selected.age = 0.0
	selected.impact_radius = enemy_radius
	if spawn_began > 0:
		PhaseBPerfCounters.timer_add_since(
			PhaseBPerfCounters.TIMER_DAMAGE_NUMBER_SPAWN, spawn_began
		)
	queue_redraw()


func _get_damage_feedback_color(death_source: int) -> Color:
	match death_source:
		DeathSource.CANE:
			return Color("e5ff9b")
		DeathSource.BLOOM:
			return Color("ffd978")
		DeathSource.SUPER_BLOOM:
			return Color("b8fff2")
		DeathSource.BRAMBLE:
			return Color("b9ff70")
		DeathSource.THORNBURST:
			return Color("e8ff8a")
		DeathSource.ROOT_ERUPTION:
			return Color("d9a86a")
		DeathSource.CUTTING:
			return Color("c9e59a")
		DeathSource.THISTLE:
			return Color("d8ff62")
		DeathSource.FRUIT:
			return Color("ff9f67")
	return Color.WHITE


func set_elite_modifier_pressure(progress: float) -> void:
	# The wave director owns the run's escalation curve, so it says how far along the
	# run is and this turns that into the chance an eligible spawn changes the rules.
	_elite_modifier_chance = lerpf(
		elite_modifier_base_chance,
		elite_modifier_final_chance,
		clampf(progress, 0.0, 1.0)
	)


func get_elite_modifier_chance() -> float:
	return _elite_modifier_chance


func get_enemy_elite_modifier(enemy_id: int) -> int:
	var enemy := _find_enemy(enemy_id)
	return enemy.elite_modifier if enemy != null else EliteModifier.NONE


func debug_force_elite_modifier(modifier: int) -> void:
	# Pins the next eligible spawn's rule change, because a one-in-six roll behind a
	# probability gate is not something a check can wait for.
	_forced_elite_modifier = modifier


func _roll_elite_modifier(role: int) -> int:
	if _forced_elite_modifier != EliteModifier.NONE:
		var forced := _forced_elite_modifier
		_forced_elite_modifier = EliteModifier.NONE
		return forced
	if not _is_modifier_eligible(role):
		return EliteModifier.NONE
	if _elite_modifier_chance <= 0.0:
		return EliteModifier.NONE
	if randf() > _elite_modifier_chance:
		return EliteModifier.NONE
	# One modifier, never two. Two rule changes on one body is a fight the player
	# cannot read, and the point of these is that they are legible.
	return randi_range(EliteModifier.UNSTOPPABLE, EliteModifier.VOLATILE)


func _is_modifier_eligible(role: int) -> bool:
	# The Elite is always eligible - it is what the modifiers are named for. The late
	# specialists become eligible too, because the doc's final escalation stage asks
	# for more specialised behaviour and not merely more elites. The Boss is excluded:
	# it already changes the rules by itself, and a Colony Core cannot use any of them.
	if role == EnemyRole.ELITE:
		return true
	return modifier_eligible_late_roles.has(role)


func _is_player_damage_source(death_source: int) -> bool:
	# What the protagonist did, as opposed to what the ecosystem did on their behalf.
	# Regenerative is the only thing that asks, and it asks precisely this.
	return (
		death_source == DeathSource.CANE
		or death_source == DeathSource.CUTTING
		or death_source == DeathSource.DEBUG
	)


func _advance_elite_modifier(enemy: EnemyState, delta: float) -> void:
	# Everything a modifier does per frame, in one place, so a body carrying none pays
	# a single comparison for the whole system.
	if enemy.elite_modifier == EliteModifier.NONE:
		return
	enemy.regeneration_block_remaining = maxf(
		0.0,
		enemy.regeneration_block_remaining - delta
	)
	match enemy.elite_modifier:
		EliteModifier.UNSTOPPABLE:
			# Rooted is the one state it refuses. Slowed is deliberately left alone:
			# the note says it can still be slowed, and an Unstoppable that ignored
			# Bramble entirely would read as immunity rather than as a rule change.
			enemy.bramble_root_remaining = 0.0
			enemy.bramble_root_duration = 0.0
			enemy.knockback_remaining = 0.0
		EliteModifier.REGENERATIVE:
			if (
				enemy.regeneration_block_remaining <= 0.0
				and enemy.health < enemy.maximum_health
			):
				enemy.health = minf(
					enemy.maximum_health,
					enemy.health + regenerative_health_per_second * delta
				)
		EliteModifier.BLIGHTED:
			# Stamped along the path rather than every frame, so the wake is a trail
			# with gaps in it instead of a solid smear whose width is the frame rate.
			if (
				enemy.position.distance_to(enemy.blight_last_position)
				>= blighted_trail_spacing_pixels
			):
				enemy.blight_last_position = enemy.position
				territory_field.queue_hostile_growth(
					enemy.position,
					blighted_trail_strength * enemy.territory_erosion_scale,
					1.0
				)
		EliteModifier.DISRUPTIVE:
			# Everything the run reads off its territory is read off maturity, so
			# suppressing it nearby weakens Green-territory effects without this
			# needing to know what any of those effects are.
			territory_field.queue_maturity_suppression(
				enemy.position,
				disruptive_suppression_per_second * delta,
				disruptive_radius_multiplier
			)


func _detonate_volatile(local_position: Vector2) -> void:
	# Sourced as RELIC so a kill it causes cannot feed a relic trigger and start a
	# chain the player cannot see the end of - the same safeguard Spore Burst uses.
	damage_enemies_in_radius(
		local_position,
		volatile_detonation_radius,
		volatile_detonation_damage,
		DeathSource.RELIC,
		0
	)
	if volatile_territory_damage > 0.0:
		territory_field.queue_erosion(local_position, volatile_territory_damage, 1.6)
	elite_detonated.emit(local_position, volatile_detonation_radius)


func _configure_enemy_stats(enemy: EnemyState) -> void:
	var profile := _profile_for_role(enemy.role)
	assert(profile != null, "Every Phase B enemy role requires an authored profile")
	enemy.spawn_wave_number = _enemy_spawn_wave_number
	enemy.territory_erosion_scale = _enemy_territory_erosion_scale
	enemy.maximum_health = profile.maximum_health * _enemy_health_scale
	enemy.speed = profile.movement_speed
	enemy.contact_damage = profile.contact_damage * _enemy_damage_scale
	enemy.contact_interval = profile.contact_interval_seconds
	enemy.radius = profile.body_radius_pixels
	enemy.xp_value = profile.xp_reward
	enemy.target_priority_multiplier = profile.target_priority_multiplier
	enemy.use_boss_navigation = profile.use_boss_navigation
	enemy.knockback_resistance = profile.knockback_resistance
	enemy.territory_action_escalation = profile.territory_action_escalation
	enemy.territory_action_escalation_cap = profile.territory_action_escalation_cap
	enemy.movement_behavior = profile.movement_behavior
	enemy.preferred_distance_pixels = profile.preferred_distance_pixels
	enemy.territory_behavior = profile.territory_behavior
	enemy.territory_action_interval = profile.territory_action_interval_seconds
	enemy.territory_action_strength = profile.territory_action_strength
	enemy.territory_action_radius_multiplier = profile.territory_action_radius_multiplier
	enemy.require_player_territory = profile.require_player_territory
	enemy.territory_actions_before_recovery = profile.territory_actions_before_recovery
	enemy.territory_recovery_seconds = profile.territory_recovery_seconds
	enemy.territory_actions_taken = 0
	enemy.emit_eruption_signal = profile.emit_eruption_signal
	enemy.catalyst_search_range_pixels = profile.catalyst_search_range_pixels
	enemy.fresh_maturity_threshold = profile.fresh_maturity_threshold
	enemy.maximum_active_summons = profile.maximum_active_summons
	enemy.summon_spacing_pixels = profile.summon_spacing_pixels
	enemy.xp_value = _get_scaled_xp_reward(enemy.xp_value, enemy.spawn_wave_number)
	enemy.collision_radius = enemy.radius * enemy_collision_radius_multiplier
	enemy.health = enemy.maximum_health


func _get_scaled_xp_reward(base_xp: int, spawn_wave_number: int) -> int:
	var wave_index := maxi(0, spawn_wave_number - 1)
	var proportional_reward := ceili(
		snappedf(
			float(base_xp) * (
				1.0 + float(wave_index) * _enemy_xp_growth_per_wave
			),
			0.0001
		)
	)
	var minimum_reward := base_xp + wave_index * _enemy_xp_minimum_bonus_per_wave
	return maxi(base_xp, maxi(proportional_reward, minimum_reward))


func _profile_for_role(role: int) -> PhaseBEnemyProfile:
	match role:
		EnemyRole.HUNTER:
			return hunter_profile
		EnemyRole.GRAZER:
			return grazer_profile
		EnemyRole.ELITE:
			return elite_profile
		EnemyRole.BOSS:
			return boss_profile
		EnemyRole.SABOTEUR:
			return saboteur_profile
		EnemyRole.CORRUPTOR:
			return corruptor_profile
		EnemyRole.COLONIZER:
			return colonizer_profile
		EnemyRole.WARDEN:
			return warden_profile
		EnemyRole.COLONY_CORE:
			return colony_core_profile
		EnemyRole.HEAVY_GRAZER:
			return heavy_grazer_profile
		EnemyRole.RUSHER:
			return rusher_profile
		EnemyRole.SIEGE_CORRUPTOR:
			return siege_corruptor_profile
	return null


func _choose_spawn_position(collision_radius: float) -> Vector2:
	var arena_size := territory_field.tuning.arena_size
	for attempt in range(32):
		var sequence := _spawn_sequence + attempt
		var edge := sequence % 4
		var fraction := float((sequence * 37 + 17) % 101) / 100.0
		var cell_size := Vector2(
			arena_size.x / float(territory_field.tuning.field_size.x),
			arena_size.y / float(territory_field.tuning.field_size.y)
		)
		var margin := maxf(28.0, collision_radius + maxf(cell_size.x, cell_size.y) * 2.5)
		var candidate := Vector2.ZERO
		match edge:
			0:
				candidate = Vector2(margin, lerpf(margin, arena_size.y - margin, fraction))
			1:
				candidate = Vector2(arena_size.x - margin, lerpf(margin, arena_size.y - margin, fraction))
			2:
				candidate = Vector2(lerpf(margin, arena_size.x - margin, fraction), margin)
			_:
				candidate = Vector2(lerpf(margin, arena_size.x - margin, fraction), arena_size.y - margin)
		if _can_occupy_diamond(candidate, collision_radius):
			_spawn_sequence = sequence + 1
			return candidate
	_spawn_sequence += 1
	return Vector2(arena_size.x * 0.80, arena_size.y * 0.50)


func _can_occupy_diamond(local_position: Vector2, radius: float) -> bool:
	return territory_field.is_diamond_claimable_at_local(local_position, radius)


func _get_inactive_enemy() -> EnemyState:
	for index in range(_enemies.size()):
		if not _enemies[index].active:
			# Remembered so the caller can register the slot without searching for it
			# again. Valid only until the next call.
			_last_inactive_enemy_slot = index
			return _enemies[index]
	_last_inactive_enemy_slot = -1
	return null


func _get_inactive_projectile() -> ProjectileState:
	for projectile in _projectiles:
		if not projectile.active:
			return projectile
	return null


func _distance_squared_to_segment(
	point: Vector2,
	segment_start: Vector2,
	segment_end: Vector2
) -> float:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_squared_to(segment_start)
	var projection := clampf((point - segment_start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_squared_to(segment_start + segment * projection)


func _draw_briar_pod(zone: BrambleZoneState) -> void:
	var life_fraction := clampf(zone.remaining / maxf(zone.duration, 0.001), 0.0, 1.0)
	var pulse := 1.0 + sin(zone.remaining * 7.0) * 0.025
	var radius := zone.radius * pulse
	_draw_occluded_briar_arc(
		zone.position,
		radius,
		Color(0.32, 0.88, 0.24, 0.78 * life_fraction)
	)
	for thorn_index in range(18):
		var direction := Vector2.from_angle(TAU * float(thorn_index) / 18.0)
		var base := zone.position + direction * (radius - 2.0)
		var tip := zone.position + direction * (radius + 8.0)
		if territory_field.is_growth_path_clear(zone.position, tip):
			draw_line(
				base,
				tip,
				Color(0.72, 1.0, 0.35, 0.88 * life_fraction),
				2.0,
				true
			)


func _draw_occluded_briar_arc(center: Vector2, radius: float, color: Color) -> void:
	var segment_count := 48
	var previous_point := center + Vector2(radius, 0.0)
	var previous_visible := territory_field.is_growth_path_clear(center, previous_point)
	for segment in range(1, segment_count + 1):
		var angle := TAU * float(segment) / float(segment_count)
		var point := center + Vector2.from_angle(angle) * radius
		var visible := territory_field.is_growth_path_clear(center, point)
		if previous_visible and visible:
			draw_line(previous_point, point, color, 3.0, true)
		previous_point = point
		previous_visible = visible


func _draw_enemy_root_hold(enemy: EnemyState) -> void:
	# Drawn beneath the enemy so the body stays readable: roots clamped around its
	# feet, plus a ring that unwinds as the hold runs out.
	var remaining_fraction := clampf(
		enemy.bramble_root_remaining / maxf(0.01, enemy.bramble_root_duration),
		0.0,
		1.0
	)
	var grip := enemy.radius + 5.0
	var root_color := Color(0.34, 0.22, 0.11, 0.55 + 0.35 * remaining_fraction)
	var thorn_color := Color(0.58, 0.88, 0.36, 0.55 + 0.40 * remaining_fraction)
	draw_circle(enemy.position, grip, Color(0.16, 0.10, 0.05, 0.30 * remaining_fraction))
	for tendril_index in range(7):
		var angle := (
			TAU * float(tendril_index) / 7.0
			+ float(enemy.id % 9) * 0.21
		)
		var direction := Vector2.from_angle(angle)
		var anchor := enemy.position + direction * (grip + 3.0)
		var claw := enemy.position + direction * (enemy.radius * 0.45)
		var curl := direction.orthogonal() * (2.6 * remaining_fraction)
		draw_line(anchor, anchor.lerp(claw, 0.55) + curl, root_color, 2.6, true)
		draw_line(anchor.lerp(claw, 0.55) + curl, claw, thorn_color, 1.8, true)
	# The unwinding ring reads as a timer: a full circle at the moment of the hold,
	# closing to nothing as the enemy works itself free.
	if remaining_fraction > 0.0:
		draw_arc(
			enemy.position,
			grip + 2.0,
			-PI * 0.5,
			-PI * 0.5 + TAU * remaining_fraction,
			24,
			thorn_color,
			2.0,
			true
		)


func _draw_enemy_root_hold_lod(enemy: EnemyState) -> void:
	var remaining_fraction := clampf(
		enemy.bramble_root_remaining / maxf(0.01, enemy.bramble_root_duration),
		0.0,
		1.0
	)
	draw_arc(
		enemy.position,
		enemy.radius + 7.0,
		-PI * 0.5,
		-PI * 0.5 + TAU * remaining_fraction,
		16,
		Color(0.58, 0.88, 0.36, 0.55 + 0.40 * remaining_fraction),
		2.0,
		true
	)


func _enemy_requires_full_detail(enemy: EnemyState) -> bool:
	# These bodies carry radial or escalation telegraphs that affect decisions. Crowd
	# LOD only removes ornamental detail from ordinary enemies.
	match enemy.role:
		EnemyRole.ELITE, EnemyRole.BOSS, EnemyRole.WARDEN, EnemyRole.COLONY_CORE, EnemyRole.SIEGE_CORRUPTOR:
			return true
	return false


func _start_enemy_art_bake() -> void:
	# Fire and forget. The await inside belongs to the bake, not to _ready: the run
	# must not wait on a render pass to start, and until the bake lands the art
	# draws directly exactly as it always did.
	bake_enemy_art()


func bake_enemy_art() -> void:
	## Render each role once into a texture, so the live frame draws a quad instead
	## of replaying the vector art per enemy per frame.
	##
	## Awaits a rendering pass, so it cannot run on a driver that has none. A failed
	## bake leaves _enemy_art_ready false and the game keeps drawing the art
	## directly -- slower, but correct. That fallback is what makes this safe to
	## attempt at startup rather than ship as a build step.
	if _enemy_art_ready or _enemy_art_baking:
		return
	_enemy_art_baking = true
	var roles := [
		EnemyRole.HUNTER,
		EnemyRole.RUSHER,
		EnemyRole.GRAZER,
		EnemyRole.HEAVY_GRAZER,
		EnemyRole.SABOTEUR,
		EnemyRole.CORRUPTOR,
		EnemyRole.COLONIZER,
	]
	for role in roles:
		var radius := _get_role_bake_radius(role)
		var extent := radius + enemy_art_bake_padding
		var side := int(ceil(extent * 2.0))
		for variant in range(enemy_art_variants):
			var viewport := SubViewport.new()
			viewport.size = Vector2i(side, side)
			viewport.transparent_bg = true
			viewport.disable_3d = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			var painter := PhaseBEnemyArtPainter.new()
			painter.director = self
			painter.role = role
			painter.variant = variant
			painter.body_radius = radius
			painter.centre = Vector2(extent, extent)
			viewport.add_child(painter)
			add_child(viewport)
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			viewport.queue_free()
			if image == null or image.is_empty():
				# No rendering driver, or the target never resolved. Abandon the whole
				# bake rather than shipping half a roster of blanks.
				_enemy_art.clear()
				_enemy_art_radius.clear()
				_enemy_art_baking = false
				return
			_enemy_art[role * enemy_art_variants + variant] = (
				ImageTexture.create_from_image(image)
			)
		_enemy_art_radius[role] = radius
	_enemy_art_baking = false
	_enemy_art_ready = not _enemy_art.is_empty()


func _get_role_bake_radius(role: int) -> float:
	var profile := _profile_for_role(role)
	if profile != null and profile.body_radius_pixels > 0.0:
		return profile.body_radius_pixels
	return 10.0


func is_enemy_art_baked() -> bool:
	return _enemy_art_ready


func get_baked_enemy_art_count() -> int:
	return _enemy_art.size()


func _draw_enemy_baked(enemy: EnemyState) -> bool:
	## One textured quad in place of the role's vector art. Returns false when the
	## role has no baked art, so the caller can fall back to drawing it directly.
	var key := enemy.role * enemy_art_variants + (enemy.id % enemy_art_variants)
	if not _enemy_art.has(key):
		return false
	var texture: Texture2D = _enemy_art[key]
	var baked_radius: float = _enemy_art_radius.get(enemy.role, 10.0)
	var art_scale := enemy.radius / maxf(1.0, baked_radius)
	var extent := Vector2(texture.get_width(), texture.get_height()) * art_scale
	# Directional roles were baked facing +X, so the quad is turned rather than the
	# art being redrawn at a new angle.
	var art_rotation := 0.0
	if enemy.role == EnemyRole.RUSHER and player != null:
		var heading := enemy.position.direction_to(player.get_arena_position())
		if heading.length_squared() > 0.01:
			art_rotation = heading.angle()
	draw_set_transform(enemy.position, art_rotation, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-extent * 0.5, extent), false, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The aura and the flash belong to this enemy in this moment, so they are drawn
	# over the baked body rather than baked into it.
	_draw_enemy_state_overlay(self, enemy)
	return true


func _draw_enemy(
	canvas: CanvasItem,
	enemy: EnemyState,
	heading_override: Vector2 = Vector2.ZERO
) -> void:
	match enemy.role:
		EnemyRole.HUNTER:
			canvas.draw_circle(enemy.position, enemy.radius + 2.0, Color(0.08, 0.02, 0.03, 0.92))
			canvas.draw_circle(enemy.position, enemy.radius, Color("ff625b"))
		EnemyRole.RUSHER:
			# A Hunter that arrives before Bramble can take hold, so it is drawn as one
			# that is already moving: the same red, swept into a wedge that points where
			# it is going, with the streaks of its own speed trailing behind it. A player
			# has to be able to tell at a glance which red body is the one that will not
			# be slowed on the way in.
			var heading := Vector2.RIGHT
			if heading_override.length_squared() > 0.01:
				heading = heading_override.normalized()
			elif player != null:
				var toward_player := enemy.position.direction_to(player.get_arena_position())
				if toward_player.length_squared() > 0.01:
					heading = toward_player
			var flank := heading.orthogonal()
			var nose := enemy.position + heading * (enemy.radius + 5.0)
			var tail := enemy.position - heading * (enemy.radius * 0.7)
			for streak_index in range(2):
				var side := flank * (enemy.radius * (0.45 + 0.35 * float(streak_index)))
				canvas.draw_line(
					tail + side,
					tail - heading * (7.0 + 5.0 * float(streak_index)) + side,
					Color(1.0, 0.42, 0.32, 0.42 - 0.16 * float(streak_index)),
					2.0,
					true
				)
				canvas.draw_line(
					tail - side,
					tail - heading * (7.0 + 5.0 * float(streak_index)) - side,
					Color(1.0, 0.42, 0.32, 0.42 - 0.16 * float(streak_index)),
					2.0,
					true
				)
			canvas.draw_colored_polygon(
				PackedVector2Array([
					nose,
					tail + flank * enemy.radius,
					tail - flank * enemy.radius,
				]),
				Color(0.09, 0.02, 0.03, 0.92)
			)
			canvas.draw_colored_polygon(
				PackedVector2Array([
					nose - heading * 2.5,
					tail + flank * (enemy.radius - 2.5),
					tail - flank * (enemy.radius - 2.5),
				]),
				Color("ff7a4a")
			)
			canvas.draw_line(
				enemy.position + heading * (enemy.radius * 0.2),
				nose - heading * 3.0,
				Color("ffe1b8"),
				2.0,
				true
			)
		EnemyRole.GRAZER:
			canvas.draw_circle(enemy.position, enemy.radius + 3.0, Color(0.08, 0.04, 0.01, 0.95))
			canvas.draw_circle(enemy.position, enemy.radius, Color("ff9d45"))
			for axis in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
				canvas.draw_line(
					enemy.position + axis * (enemy.radius - 2.0),
					enemy.position + axis * (enemy.radius + 5.0),
					Color("ffe0a3"),
					2.0,
					true
				)
		EnemyRole.HEAVY_GRAZER:
			# The Grazer's orange, plated. It eats the same ground and cannot be shoved off
			# it, so what it says about itself is weight: a hide too thick to move, blunt
			# tusks rather than the ordinary Grazer's fine ones, and a body that fills its
			# own outline instead of sitting inside it.
			canvas.draw_circle(enemy.position, enemy.radius + 5.0, Color(0.10, 0.05, 0.01, 0.95))
			canvas.draw_circle(enemy.position, enemy.radius + 2.0, Color("6b3312"))
			canvas.draw_circle(enemy.position, enemy.radius - 1.0, Color("e07a2a"))
			for plate_index in range(6):
				var plate_angle := TAU * float(plate_index) / 6.0 + float(enemy.id % 6) * 0.18
				var plate_direction := Vector2.from_angle(plate_angle)
				canvas.draw_line(
					enemy.position + plate_direction * (enemy.radius - 4.0),
					enemy.position + plate_direction * (enemy.radius + 2.0),
					Color("8f4a18"),
					3.0,
					true
				)
			for tusk in [Vector2.RIGHT, Vector2.LEFT]:
				canvas.draw_line(
					enemy.position + tusk * (enemy.radius - 2.0),
					enemy.position + tusk * (enemy.radius + 8.0),
					Color("ffd9a0"),
					4.5,
					true
				)
			canvas.draw_circle(enemy.position, 4.5, Color("40190a"))
		EnemyRole.SABOTEUR:
			var top := enemy.position + Vector2(0.0, -enemy.radius)
			var right := enemy.position + Vector2(enemy.radius, 0.0)
			var bottom := enemy.position + Vector2(0.0, enemy.radius)
			var left := enemy.position + Vector2(-enemy.radius, 0.0)
			canvas.draw_circle(enemy.position, enemy.radius + 4.0, Color(0.28, 0.02, 0.12, 0.42))
			canvas.draw_line(top, right, Color("ff477e"), 4.0, true)
			canvas.draw_line(right, bottom, Color("ff477e"), 4.0, true)
			canvas.draw_line(bottom, left, Color("ff477e"), 4.0, true)
			canvas.draw_line(left, top, Color("ff477e"), 4.0, true)
			canvas.draw_line(
				enemy.position + Vector2(-5.0, -5.0),
				enemy.position + Vector2(6.0, 6.0),
				Color("fff0a6"),
				2.0,
				true
			)
			canvas.draw_line(
				enemy.position + Vector2(5.0, -5.0),
				enemy.position + Vector2(-6.0, 6.0),
				Color("fff0a6"),
				2.0,
				true
			)
		EnemyRole.CORRUPTOR:
			canvas.draw_circle(enemy.position, enemy.radius + 4.0, Color(0.30, 0.02, 0.38, 0.48))
			canvas.draw_circle(enemy.position, enemy.radius, Color("a338c7"))
			canvas.draw_circle(enemy.position, enemy.radius - 5.0, Color("42114f"))
			canvas.draw_arc(
				enemy.position,
				enemy.radius - 2.0,
				-PI * 0.25,
				PI * 1.25,
				18,
				Color("ff86e8"),
				2.5,
				true
			)
		EnemyRole.SIEGE_CORRUPTOR:
			# A Corruptor that gets worse the longer it is left alone, so the one thing it
			# has to show is how far along it already is. The ring closes as its conversion
			# compounds toward the cap and springs open again the moment it is hit, which
			# makes 'deal with it now' a thing the player can see rather than infer.
			var escalation_fraction := 0.0
			if enemy.territory_action_escalation_cap > 1.0:
				escalation_fraction = clampf(
					(enemy.territory_escalation - 1.0)
					/ (enemy.territory_action_escalation_cap - 1.0),
					0.0,
					1.0
				)
			canvas.draw_circle(
				enemy.position,
				enemy.radius + 6.0,
				Color(0.34, 0.02, 0.30, 0.30 + 0.30 * escalation_fraction)
			)
			for siege_spike in range(8):
				var spike_direction := Vector2.from_angle(TAU * float(siege_spike) / 8.0)
				canvas.draw_line(
					enemy.position + spike_direction * (enemy.radius - 2.0),
					enemy.position + spike_direction * (
						enemy.radius + 4.0 + 5.0 * escalation_fraction
					),
					Color(0.85, 0.30, 1.0, 0.55 + 0.40 * escalation_fraction),
					2.5,
					true
				)
			canvas.draw_circle(enemy.position, enemy.radius, Color("7a1f9c"))
			canvas.draw_circle(enemy.position, enemy.radius - 6.0, Color("2b0838"))
			canvas.draw_circle(
				enemy.position,
				maxf(2.0, (enemy.radius - 6.0) * escalation_fraction),
				Color(1.0, 0.52, 0.95, 0.85)
			)
			if escalation_fraction > 0.0:
				canvas.draw_arc(
					enemy.position,
					enemy.radius + 3.0,
					-PI * 0.5,
					-PI * 0.5 + TAU * escalation_fraction,
					28,
					Color("ff86e8"),
					2.5,
					true
				)
		EnemyRole.COLONIZER:
			canvas.draw_circle(enemy.position, enemy.radius + 4.0, Color(0.02, 0.26, 0.30, 0.46))
			for pod_index in range(3):
				var direction := Vector2.from_angle(TAU * float(pod_index) / 3.0)
				canvas.draw_circle(
					enemy.position + direction * (enemy.radius - 1.0),
					5.0,
					Color("59d7c6")
				)
			canvas.draw_circle(enemy.position, enemy.radius - 3.0, Color("155b67"))
			canvas.draw_circle(enemy.position, 4.0, Color("b8fff2"))
		EnemyRole.WARDEN:
			var pixels_per_cell := (
				territory_field.tuning.arena_size.x
				/ float(territory_field.tuning.field_size.x)
			)
			var suppression_radius := (
				territory_field.tuning.grazer_radius_cells
				* pixels_per_cell
				* enemy.territory_action_radius_multiplier
			)
			var pulse_progress := clampf(
				1.0 - enemy.territory_action_remaining / maxf(enemy.territory_action_interval, 0.01),
				0.0,
				1.0
			)
			canvas.draw_circle(
				enemy.position,
				suppression_radius,
				Color(0.25, 0.38, 1.0, 0.055 + pulse_progress * 0.035)
			)
			canvas.draw_arc(
				enemy.position,
				suppression_radius,
				0.0,
				TAU,
				48,
				Color(0.48, 0.62, 1.0, 0.42),
				2.0,
				true
			)
			canvas.draw_rect(
				Rect2(enemy.position - Vector2.ONE * enemy.radius, Vector2.ONE * enemy.radius * 2.0),
				Color("5267d8"),
				true
			)
			canvas.draw_rect(
				Rect2(enemy.position - Vector2.ONE * (enemy.radius - 5.0), Vector2.ONE * (enemy.radius - 5.0) * 2.0),
				Color("172758"),
				true
			)
			canvas.draw_circle(enemy.position, 4.0, Color("c8d5ff"))
		EnemyRole.COLONY_CORE:
			canvas.draw_circle(enemy.position, enemy.radius + 7.0, Color(0.38, 0.02, 0.14, 0.30))
			for spine_index in range(6):
				var direction := Vector2.from_angle(TAU * float(spine_index) / 6.0)
				canvas.draw_line(
					enemy.position + direction * (enemy.radius - 3.0),
					enemy.position + direction * (enemy.radius + 7.0),
					Color("ff5d78"),
					3.0,
					true
				)
			canvas.draw_circle(enemy.position, enemy.radius, Color("781b3e"))
			canvas.draw_circle(enemy.position, enemy.radius - 6.0, Color("2d1029"))
			canvas.draw_circle(enemy.position, 4.0, Color("ff9bb0"))
		EnemyRole.ELITE:
			canvas.draw_circle(enemy.position, enemy.radius + 5.0, Color(0.35, 0.09, 0.42, 0.55))
			canvas.draw_circle(enemy.position, enemy.radius, Color("d85cff"))
			canvas.draw_circle(enemy.position, enemy.radius - 6.0, Color("4a153e"))
			canvas.draw_arc(enemy.position, enemy.radius + 4.0, 0.0, TAU, 24, Color("f5c4ff"), 2.0, true)
		EnemyRole.BOSS:
			canvas.draw_circle(enemy.position, enemy.radius + 8.0, Color(0.45, 0.02, 0.12, 0.38))
			for petal_index in range(6):
				var direction := Vector2.from_angle(TAU * float(petal_index) / 6.0)
				canvas.draw_circle(enemy.position + direction * 20.0, 10.0, Color("c72d58"))
			canvas.draw_circle(enemy.position, enemy.radius, Color("8f173d"))
			canvas.draw_circle(enemy.position, 10.0, Color("ff8096"))
			canvas.draw_arc(enemy.position, enemy.radius + 5.0, 0.0, TAU, 36, Color("ffc1cc"), 3.0, true)

	# Everything that depends on what this particular enemy is doing right now is
	# drawn separately, because the body art above it is baked into a texture and a
	# texture cannot carry a pulse or a flash.
	_draw_enemy_state_overlay(canvas, enemy)


func _draw_enemy_state_overlay(canvas: CanvasItem, enemy: EnemyState) -> void:
	## Per-enemy state drawn over the body: the Overgrown aura and the hit flash.
	## Shared by both draw paths so a baked enemy and a directly drawn one report
	## the same state in the same way.
	if enemy.overgrown:
		# Overgrown reads as the enemy itself breathing out. The pulse is driven by the
		# contagion clock rather than by wall time, so what the player sees flashing is
		# the aura actually going off: brightest the instant it fires, faded by the time
		# the next one is due. Kept under the hit flash and low in alpha - this runs for
		# four seconds on every infected body in a pack, and a bright one would drown
		# out the hits that are also landing on it.
		var spore_pulse := clampf(
			enemy.spore_damage_remaining / maxf(overgrown_damage_interval_seconds, 0.001),
			0.0,
			1.0
		)
		canvas.draw_circle(
			enemy.position,
			enemy.radius + 1.0,
			Color(0.55, 0.95, 0.42, 0.10 + 0.22 * spore_pulse)
		)
		canvas.draw_arc(
			enemy.position,
			enemy.radius + 3.5,
			0.0,
			TAU,
			20,
			Color(0.72, 1.0, 0.55, 0.18 + 0.30 * spore_pulse),
			1.5,
			true
		)

	if enemy.hit_flash_remaining > 0.0:
		var flash_strength := clampf(
			enemy.hit_flash_remaining / maxf(enemy_hit_flash_seconds, 0.001),
			0.0,
			1.0
		)
		var flash_color := enemy.hit_flash_color
		flash_color.a = 0.68 * flash_strength
		canvas.draw_circle(enemy.position, enemy.radius + 1.5, flash_color)
		var flash_edge := Color(1.0, 1.0, 1.0, 0.85 * flash_strength)
		canvas.draw_arc(
			enemy.position,
			enemy.radius + 3.0,
			0.0,
			TAU,
			20,
			flash_edge,
			2.0,
			true
		)

	if (
		enemy.role == EnemyRole.ELITE
		or enemy.role == EnemyRole.BOSS
		or enemy.role == EnemyRole.COLONY_CORE
		or enemy.health < enemy.maximum_health
	):
		var bar_width := enemy.radius * 2.2
		var bar_position := enemy.position + Vector2(-bar_width * 0.5, -enemy.radius - 10.0)
		canvas.draw_rect(Rect2(bar_position, Vector2(bar_width, 4.0)), Color(0.03, 0.03, 0.04, 0.9), true)
		canvas.draw_rect(
			Rect2(
				bar_position,
				Vector2(bar_width * clampf(enemy.health / enemy.maximum_health, 0.0, 1.0), 4.0)
			),
			Color("ff6a82"),
			true
		)


func _load_damage_digit_atlas() -> void:
	## Both halves or neither: without the metrics the strip cannot be laid out, and
	## drawing it wrong is worse than falling back to text.
	var texture := load(DAMAGE_DIGIT_ATLAS_PATH) as Texture2D
	if texture == null:
		return
	if not FileAccess.file_exists(DAMAGE_DIGIT_METRICS_PATH):
		return
	var file := FileAccess.open(DAMAGE_DIGIT_METRICS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var metrics: Dictionary = parsed
	var advances: Array = metrics.get("advances", [])
	if advances.size() != 10:
		return
	_damage_digit_advances = PackedFloat32Array()
	for advance in advances:
		_damage_digit_advances.append(float(advance))
	_damage_digit_bake_size = maxf(1.0, float(metrics.get("bake_font_size", 64.0)))
	_damage_digit_cell = Vector2(
		float(metrics.get("cell_width", texture.get_width() / 10.0)),
		float(metrics.get("cell_height", texture.get_height()))
	)
	_damage_digit_atlas = texture


func _damage_digit_text_width(text: String) -> float:
	var width := 0.0
	for character_index in range(text.length()):
		var digit := text.unicode_at(character_index) - 48
		if digit >= 0 and digit <= 9:
			width += _damage_digit_advances[digit]
	return width


func _draw_damage_number(damage_number: DamageNumberState) -> void:
	var draw_began := Time.get_ticks_usec() if PhaseBPerfCounters.enabled else 0
	var lifetime := maxf(damage_number_lifetime_seconds, 0.001)
	var lifetime_progress := clampf(damage_number.age / lifetime, 0.0, 1.0)
	var text_alpha := 1.0 - clampf((lifetime_progress - 0.48) / 0.52, 0.0, 1.0)
	var impact_progress := clampf(
		damage_number.age / maxf(enemy_hit_flash_seconds, 0.001),
		0.0,
		1.0
	)
	if impact_progress < 1.0:
		var impact_color := damage_number.color
		impact_color.a = (1.0 - impact_progress) * 0.90
		var impact_radius := lerpf(
			damage_number.impact_radius * 0.45,
			damage_number.impact_radius + 7.0,
			impact_progress
		)
		draw_arc(
			damage_number.impact_position,
			impact_radius,
			0.0,
			TAU,
			16,
			impact_color,
			2.0,
			true
		)

	var font_size := damage_number.font_size
	var text_size := damage_number.text_size
	var shadow_color := Color(0.01, 0.018, 0.02, 0.92 * text_alpha)
	var text_color := damage_number.color
	text_color.a = text_alpha
	if _damage_digit_atlas != null:
		var digit_scale := float(font_size) / _damage_digit_bake_size
		var cell := _damage_digit_cell * digit_scale
		var origin := damage_number.position - Vector2(text_size.x * 0.5, text_size.y * 0.5)
		# Shadow and glyphs are the same quads out of the same texture, so the whole
		# layer stays on one texture and batches rather than switching per glyph.
		for pass_index in range(2):
			var offset := Vector2(1.5, 1.5) if pass_index == 0 else Vector2.ZERO
			var tint := shadow_color if pass_index == 0 else text_color
			var pen := 0.0
			for character_index in range(damage_number.text.length()):
				var digit := damage_number.text.unicode_at(character_index) - 48
				if digit < 0 or digit > 9:
					continue
				var advance := _damage_digit_advances[digit] * digit_scale
				# The glyph sits centred in its cell, so the cell is centred over the
				# advance slot rather than aligned to its left edge.
				draw_texture_rect_region(
					_damage_digit_atlas,
					Rect2(
						origin
						+ offset
						+ Vector2(pen + (advance - cell.x) * 0.5, 0.0),
						cell
					),
					Rect2(
						Vector2(_damage_digit_cell.x * float(digit), 0.0),
						_damage_digit_cell
					),
					tint
				)
				pen += advance
	else:
		var baseline := (
			damage_number.position + Vector2(-text_size.x * 0.5, text_size.y * 0.35)
		)
		draw_string(
			_damage_number_font,
			baseline + Vector2(1.5, 1.5),
			damage_number.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			shadow_color
		)
		draw_string(
			_damage_number_font,
			baseline,
			damage_number.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			text_color
		)
	if draw_began > 0:
		PhaseBPerfCounters.timer_add_since(
			PhaseBPerfCounters.TIMER_DAMAGE_NUMBER_DRAW, draw_began
		)
