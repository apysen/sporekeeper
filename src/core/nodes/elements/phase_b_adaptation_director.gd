class_name PhaseBAdaptationDirector
extends Node2D

## Runtime owner for the three Adaptations introduced together: Thistle, Vine,
## and Fruit. Cane remains universal and resolves its fixed sector in Combat; this
## component turns on Vine's dense-sector auto-aim, pushes its four modifiers into
## that same attack, and answers bounded sweep signals with pair-Evolution effects.

signal status_requested(message: String)

const FRUIT_TEXTURES: Array[Texture2D] = [
	preload("res://assets/art/fruit/watermelon.png"),
	preload("res://assets/art/fruit/red-apple.png"),
	preload("res://assets/art/fruit/peach.png"),
	preload("res://assets/art/fruit/orange.png"),
	preload("res://assets/art/fruit/lemon.png"),
	preload("res://assets/art/fruit/strawberry.png"),
]
const FRUITSEED_TEXTURE: Texture2D = preload("res://assets/art/seed/fruitseed.png")
const INVALID_POSITION := Vector2(-99999.0, -99999.0)
## What a lone Thistle keeps when it has to answer its own network event.
const SOLO_NETWORK_SHARE := 0.65

enum PendingKind {
	THISTLE_VOLLEY,
	CANE_SWEEP,
	THORNWHIP_SECOND_HALF,
	WISTERIA_SEQUENCE,
	WISTERIA_BLOSSOM,
	ESPALIER_CUTTINGS,
}


class RootedGlowState:
	## One point's reading of the Root Network under it: whether it is standing on
	## Mature player ground, how deep the Network is there, and how much of the
	## transition flare is left. Kept per point rather than recomputed in _draw so a
	## paused run holds its light still instead of breathing on a stopped clock.
	var lit := false
	var network := 1.0
	var flare := 0.0
	var _was_lit := false

	func advance(
		delta: float,
		now_lit: bool,
		now_network: float,
		flare_seconds: float
	) -> void:
		# Both edges flare. Stepping on is when the whole unit is won and stepping
		# off is when it is lost, and the second is the one a player misses.
		if now_lit != _was_lit:
			flare = 1.0
		elif flare > 0.0:
			flare = maxf(0.0, flare - delta / maxf(0.01, flare_seconds))
		_was_lit = now_lit
		lit = now_lit
		network = now_network

	func clear() -> void:
		lit = false
		network = 1.0
		flare = 0.0
		_was_lit = false


class ThistleState:
	var active := false
	var permanent := true
	var position := Vector2.ZERO
	var attack_remaining := 0.0
	var temporary_remaining := 0.0
	var unsupported_remaining := -1.0
	var collapse_volley_fired := false
	var firing_cycles := 0
	var heavy_thorns := 0
	var bloom_charge_remaining := 0.0
	var sequence := 0
	var burdock_temporary := false
	## A real thistle catches on whatever walks through it. While carried the turret
	## rides Grandma, keeps firing from her position, and answers to no supporting
	## Green: it is on her coat, not in the ground.
	var carried := false
	var carry_remaining := 0.0
	## Time before this turret is willing to catch on Grandma again. Without it she
	## would simply stand on the thing and never put it down.
	var stick_cooldown_remaining := 0.0
	## The Root Network under this turret, which is where Clustering and Burr are
	## measured. A carried turret takes no light of its own: it is standing exactly
	## where Grandma is and her own light already says so.
	var rooted_glow := RootedGlowState.new()


## What fired a thorn. Only NATURAL advances a network counter; every relic-made
## thorn is tagged so it can hit, kill and ricochet normally without ever feeding
## the counters that produced it.
enum ThornSource {
	NATURAL,
	ROSETTE,
	RELAY,
	PINCUSHION,
	SEEDHEAD,
	ANSWERING,
	PHYLLOTAXIS,
	FORKING,
	CROWN,
}


class ThornState:
	var active := false
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var remaining := 0.0
	var damage := 0.0
	var ricochets_remaining := 0
	var pierce_remaining := 0
	## ROOTSTOCK's Heavy Thorn may pass through ordinary enemies, but elites and
	## bosses stop the punch-through and hand the packet off to Burr ricochets.
	var pierces_normal_only := false
	var critical_chance_bonus := 0.0
	var heavy := false
	var bloomshot := false
	var bloomshot_force := 0.0
	var ricochet_depth := 0
	var inherit_needlepoint := true
	var source_thistle_sequence := -1
	var source_tag := 0
	var hit_ids := PackedInt32Array()


class FruitState:
	var active := false
	var dropped_seed := false
	var fragment := false
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var speed := 0.0
	var base_speed := 0.0
	var deceleration := 0.0
	## Seconds this Fruit may keep rolling before it bursts wherever it is. A Fruit
	## is a roll and then a burst; nothing legitimately outlives its own roll, so
	## this is the backstop that makes permanent scenery impossible.
	var roll_deadline_remaining := 0.0
	var last_direction := Vector2.RIGHT
	var remaining_distance := 0.0
	var maximum_distance := 1.0
	var normal_roll_distance := 1.0
	var damage := 0.0
	var terminal_damage := 0.0
	var knockback := 0.0
	## Trail and terminal area are separate because GRAFT's Prize Fruit enlarges
	## only the terminal foothold, while Germination/Fertile Union affect both.
	var germination_multiplier := 1.0
	var terminal_germination_multiplier := 1.0
	var visual_scale := 1.0
	var visual_index := 0
	var rotation := 0.0
	var trail_debt := 0.0
	var hit_cooldowns := {}
	var first_enemy_collision := true
	var thick_rind_available := false
	var first_obstacle_bounce := true
	var bank_shot_armed := false
	var first_collision_damage_multiplier := 1.0
	var carried_thistle_remaining := 0.0
	var burdock_reset_remaining := 0.0
	var graft_cuttings := 0
	var prize := false
	var can_raise_sapling := true
	## Which release threw this Fruit, and which Fruit of that release it is. Fruit
	## Salad needs both: two hits from the same Fruit are not two Fruit.
	var release_id := 0
	var fruit_id := 0
	## Stem Steering and Windfall each redirect the same Fruit, so each keeps its own
	## budget rather than sharing one and quietly stealing from the other.
	var steering_uses := 0
	var windfall_uses := 0
	var windfall_cooldown := 0.0
	## Bruised Fruit is measured in travel rather than time, so a Fruit that has
	## nearly stopped does not keep painting wide.
	var juicy_remaining := 0.0
	## Newton's Apple chain starters this Fruit has spent, and the clock between them.
	var newton_starters := 0
	var newton_cooldown := 0.0


class FruitseedState:
	var active := false
	var position := Vector2.ZERO
	var remaining := 0.0
	var duration := 1.0
	var area_multiplier := 1.0
	var dropped_seed := false
	var fragment := false
	var rotation := 0.0
	var direction := Vector2.RIGHT
	var visual_index := 0
	var visual_scale := 1.0
	var damage := 0.0
	var terminal_damage := 0.0
	var knockback := 0.0
	var normal_roll_distance := 1.0
	var can_raise_sapling := true


class SaplingState:
	var active := false
	var position := Vector2.ZERO
	## Negative while rooted, positive while waiting for Green to return.
	var dormant_remaining := -1.0
	## Lets the queued terminal foothold resolve before support is evaluated.
	var support_grace_remaining := 0.0
	var release_toggle := false
	var support_remaining := 0.0


class PendingEvent:
	var active := false
	var kind := PendingKind.THISTLE_VOLLEY
	var remaining := 0.0
	var origin := Vector2.ZERO
	var facing := Vector2.RIGHT
	var left_to_right := true
	var damage_scale := 1.0
	var count := 0
	var extra_pierce := 0
	var reach := 0.0


@export_group("Collaborators")
@export var progression: PhaseBProgression
@export var evolutions: PhaseBEvolutions
@export var player: PhaseBPlayer
@export var territory_field: TerritoryField
@export var overlay: TerritoryPrototypeOverlay
@export var combat: PhaseBCombatDirector
@export var spore_director: PhaseBSporeDirector
@export var bloom_director: PhaseBBloomDirector
@export var bramble_director: PhaseBBrambleDirector
@export var root_director: PhaseBRootDirector
@export var pruning_director: PhaseBPruningDirector

@export_group("Thistle Base")
## Direct damage of every ordinary thorn before a critical hit or Evolution.
@export_range(1.0, 300.0, 1.0) var thistle_damage := 12.0
## Seconds between attacks for an unupgraded supported Thistle.
@export_range(0.1, 10.0, 0.05) var thistle_attack_interval := 1.10
@export_range(20.0, 800.0, 5.0) var thistle_range_pixels := 240.0
@export_range(40.0, 1200.0, 10.0) var thorn_speed_pixels_per_second := 460.0
@export_range(0.1, 5.0, 0.05) var thorn_lifetime_seconds := 1.15
@export_range(1.0, 40.0, 1.0) var thorn_hit_radius_pixels := 6.0
@export_range(0.0, 1.0, 0.01) var thistle_base_critical_chance := 0.0
@export_range(1.0, 5.0, 0.05) var thistle_critical_multiplier := 2.0
@export_range(10.0, 200.0, 2.0) var thistle_planting_radius := 62.0
## Center-to-center room reserved by every active Thistle. The flower head and its
## longest spikes occupy a 24 px diameter, so 28 px leaves a small readable gap.
@export_range(20.0, 80.0, 1.0) var thistle_minimum_spacing_pixels := 28.0
## How long the ground stays bare after a turret collapses before a replacement
## grows -- whether Grandma worked it loose over bare dirt or an enemy took the
## Green out from under it. This is what makes losing the Thistle a real loss
## rather than a half-second stutter.
@export_range(0.1, 30.0, 0.1) var thistle_replant_seconds := 5.0

@export_group("Thistle Carry")
## How close Grandma has to pass for the Thistle to catch on her.
@export_range(2.0, 80.0, 1.0) var thistle_stick_radius_pixels := 15.0
## Base time a caught Thistle rides Grandma before it works loose and drops.
@export_range(0.5, 15.0, 0.05) var thistle_carry_seconds := 3.0
## Base wait before a dropped Thistle will catch on her again. Together with the
## carry time this sets the share of the fight the turret spends mobile.
@export_range(0.5, 60.0, 0.1) var thistle_stick_cooldown_seconds := 7.0
## The four Thistle lines used to buy turret slots. With the network capped at one
## turret they buy carry instead: every started line lengthens the ride and
## shortens the wait between rides.
@export_range(0.0, 3.0, 0.05) var thistle_carry_seconds_per_line := 0.25
@export_range(0.0, 3.0, 0.05) var thistle_stick_cooldown_per_line := 0.55

@export_group("Root Network Feedback")
## Whether to light points that the Root Network is paying out under. Root Potency's
## whole-unit step is the one part of the Network that is on or off rather than
## proportional, so it is the one part that has to be visible: without it a player
## holding three Potency ranks reads a four-Fruit release as a bug rather than as
## ground they walked off.
@export var draw_rooted_ground_glow := true
## Light radius under Grandma, which is where Fruit Set is measured.
@export_range(4.0, 80.0, 1.0) var rooted_glow_player_radius := 27.0
## Light radius under a planted Thistle, which is where Clustering and Burr are.
@export_range(4.0, 80.0, 1.0) var rooted_glow_thistle_radius := 19.0
## Breaths per second of the sustained light. Deliberately under 1 Hz: this state
## lasts most of a Root run, and anything faster stops reading as calm.
@export_range(0.1, 4.0, 0.05) var rooted_glow_pulse_hz := 0.85
## Seconds the brighter flare lasts when a point crosses onto or off Mature ground.
@export_range(0.05, 2.0, 0.05) var rooted_glow_flare_seconds := 0.40

@export_group("Fruit Base")
## Direct damage on each enemy collision.
@export_range(1.0, 500.0, 1.0) var fruit_collision_damage := 36.0
## Maximum direct damage at the center of the terminal burst. Radius damage uses
## Combat's standard falloff, reaching 48% of this value at the outer edge.
@export_range(0.0, 200.0, 1.0) var fruit_terminal_explosion_damage := 10.0
## Cooldown between releases, started the moment the Fruit launch. Rolling and the
## planted fuse run on their own time inside it. Waiting for the previous batch to
## burst made Momentum a cadence tax -- a longer roll pushed the next release further
## out, so the line that bought reach was paying for it in releases per minute.
@export_range(0.2, 30.0, 0.1) var fruit_release_interval := 3.0
@export_range(20.0, 1000.0, 5.0) var fruit_roll_distance_pixels := 320.0
@export_range(20.0, 1000.0, 5.0) var fruit_speed_pixels_per_second := 300.0
## Speed under which a Fruit counts as stopped and bursts. This is a threshold and
## not an exact zero on purpose: of the three things that reduce a Fruit's speed, two
## are multiplications -- an obstacle bounce keeps 55% and an enemy collision keeps as
## little as 15% -- and a multiplication never arrives at zero. Testing for exactly
## zero meant a Fruit could be parked microscopically above it forever: motionless,
## never bursting, never freeing its pool slot, and still dealing contact damage to
## anything that walked into it.
@export_range(0.001, 20.0, 0.001) var fruit_minimum_roll_speed := 1.0
## Floor under a Fruit's deceleration. Constant deceleration is the only thing that
## actually brings a Fruit to rest, so it is never allowed to reach zero.
@export_range(0.01, 100.0, 0.01) var fruit_minimum_deceleration := 1.0
## Multiple of its own unobstructed roll time after which a Fruit bursts wherever it
## is. Bounces and the re-acceleration relics legitimately stretch a roll, so this is
## slack rather than a schedule -- it should never fire in a healthy run.
@export_range(1.0, 20.0, 0.5) var fruit_roll_deadline_safety := 4.0
## Floor under that deadline, for Fruit whose authored roll is very short.
@export_range(1.0, 120.0, 0.5) var fruit_minimum_roll_deadline_seconds := 8.0
@export_range(10.0, 180.0, 1.0) var fruit_targeting_sector_degrees := 90.0
@export_range(2.0, 80.0, 1.0) var fruit_radius_pixels := 18.0
@export_range(0.0, 200.0, 1.0) var fruit_knockback_pixels := 38.0
## Share of current momentum lost on an ordinary enemy collision.
@export_range(0.0, 1.0, 0.01) var fruit_enemy_momentum_loss := 0.32
@export_range(2.0, 100.0, 1.0) var fruit_trail_spacing_pixels := 20.0
@export_range(0.0, 4.0, 0.01) var fruit_trail_mass := 0.18
@export_range(0.0, 8.0, 0.05) var fruit_trail_pressure_cells := 0.60
@export_range(0.5, 8.0, 0.05) var fruit_trail_radius_cells := 1.30
## Time the stopped Fruit remains planted before bursting into territory.
@export_range(0.1, 10.0, 0.1) var fruitseed_germination_seconds := 0.5
@export_range(8.0, 96.0, 1.0) var fruit_art_diameter_pixels := 36.0
@export_range(8.0, 96.0, 1.0) var fruitseed_art_diameter_pixels := 24.0

@export_group("Fruit Territory")
## These are deliberately separate from Seed/Bloom tuning: Fruit paints a narrow,
## immature corridor and then pays out one conventional Seed-shaped foothold.
@export_range(0.1, 20.0, 0.1) var fruit_terminal_mass_multiplier := 0.85
@export_range(0.1, 20.0, 0.1) var fruit_terminal_pressure_multiplier := 0.70
@export_range(0.1, 20.0, 0.1) var fruit_terminal_conversion_multiplier := 0.85
@export_range(8.0, 200.0, 1.0) var fruit_terminal_effect_radius_pixels := 72.0
@export_range(0.1, 1.0, 0.01) var fruit_obstacle_momentum_preserved := 0.55

@export_group("Orchard")
@export_range(0.1, 2.0, 0.05) var sapling_support_interval := 0.50
@export_range(0.0, 2.0, 0.01) var sapling_maturation_rate_bonus := 0.30
@export_range(0.0, 2.0, 0.01) var sapling_control_support := 0.04
@export_range(0.1, 4.0, 0.05) var sapling_support_radius_multiplier := 0.85
@export_range(0.1, 2.0, 0.05) var sapling_spawn_support_grace_seconds := 0.50

@export_group("Pools")
@export_range(5, 30, 1) var thistle_pool_size := 12
@export_range(32, 600, 1) var thorn_pool_size := 256
@export_range(8, 120, 1) var fruit_pool_size := 48
@export_range(4, 120, 1) var fruitseed_pool_size := 32
@export_range(3, 12, 1) var sapling_pool_size := 3
@export_range(8, 120, 1) var pending_event_pool_size := 48

@export_group("Relic Rules")
@export_range(1, 20, 1) var phyllotaxis_cycle_interval := 5
@export_range(1, 20, 1) var phyllotaxis_bonus_thorns := 5
@export_range(0.0, 1.0, 0.01) var phyllotaxis_damage_share := 0.55
@export_range(0.0, 120.0, 1.0) var phyllotaxis_spread_degrees := 48.0
@export_range(1, 40, 1) var crown_cycle_interval := 12
@export_range(0.0, 1.0, 0.01) var crown_damage_share := 0.55
@export_range(0.1, 30.0, 0.1) var crown_cooldown_seconds := 7.0
## Crown pays the whole network at once, so a network of one would be a single
## ordinary volley. Alone, the Thistle fires this many staggered volleys instead.
@export_range(1, 8, 1) var crown_solo_volleys := 3
@export_range(0.02, 1.0, 0.01) var crown_solo_interval := 0.14
## Rosette: how long after a permanent Thistle finishes growing it fires its
## opening volley, and what that volley is worth.
@export_range(0.0, 3.0, 0.01) var rosette_delay_seconds := 0.25
@export_range(0.0, 2.0, 0.01) var rosette_damage_share := 0.60
## Thorn Relay: natural impacts between bonus thorns, what one is worth, and the
## ceiling on how often the network may answer.
@export_range(1, 40, 1) var thorn_relay_impacts := 8
@export_range(0.0, 2.0, 0.01) var thorn_relay_damage_share := 0.65
@export_range(0.1, 20.0, 0.1) var thorn_relay_per_second := 2.0
## Pincushion: thorns an enemy has to absorb, how long the stack survives without
## a new one, and what bursts out of the corpse.
@export_range(1, 20, 1) var pincushion_threshold := 5
@export_range(0.1, 20.0, 0.1) var pincushion_stack_seconds := 3.0
@export_range(1, 12, 1) var pincushion_thorns := 3
@export_range(0.0, 2.0, 0.01) var pincushion_damage_share := 0.45
@export_range(20.0, 600.0, 5.0) var pincushion_range_pixels := 190.0
## Answering Thorn: what a killing natural volley makes another turret do.
@export_range(0.0, 2.0, 0.01) var answering_thorn_damage_share := 0.50
@export_range(0.1, 20.0, 0.1) var answering_thorn_cooldown_seconds := 2.25
## Forking Pattern: natural impacts between splits, how many branches, and the
## caps that stop a dense fight turning into a wall of thorns.
@export_range(1, 60, 1) var forking_pattern_impacts := 12
@export_range(1, 12, 1) var forking_pattern_branches := 3
@export_range(1, 12, 1) var forking_pattern_critical_branches := 4
@export_range(0.0, 2.0, 0.01) var forking_pattern_damage_share := 0.55
@export_range(20.0, 600.0, 5.0) var forking_pattern_range_pixels := 210.0
@export_range(0.05, 10.0, 0.05) var forking_pattern_cooldown_seconds := 0.75
@export_range(1, 40, 1) var forking_pattern_active_maximum := 8
## Stem Steering: how often one Fruit may curve, how far it looks, and how sharply
## it is allowed to turn while keeping every bit of its speed.
@export_range(1, 8, 1) var stem_steering_uses := 2
@export_range(20.0, 600.0, 5.0) var stem_steering_range_pixels := 180.0
@export_range(1.0, 90.0, 1.0) var stem_steering_degrees := 28.0
@export_range(0.0, 400.0, 5.0) var stem_steering_minimum_speed := 90.0
## Bruised Fruit: how far the Juicy state lasts and how much wider it paints.
@export_range(10.0, 400.0, 2.0) var bruised_fruit_distance_pixels := 72.0
@export_range(1.0, 4.0, 0.05) var bruised_fruit_area_multiplier := 1.75
## Fruit Salad: how long the first Fruit's mark stands, and what the second does.
@export_range(0.1, 10.0, 0.05) var fruit_salad_mark_seconds := 1.25
@export_range(10.0, 300.0, 5.0) var fruit_salad_burst_radius := 65.0
@export_range(0.0, 2.0, 0.01) var fruit_salad_damage_share := 0.45
@export_range(0.0, 200.0, 1.0) var fruit_salad_knockback := 20.0
## Windfall: what a collision kill gives back, and how often.
@export_range(0.0, 1.0, 0.01) var windfall_speed_share := 0.22
@export_range(1.0, 2.0, 0.01) var windfall_maximum_speed_share := 1.10
@export_range(20.0, 600.0, 5.0) var windfall_range_pixels := 220.0
@export_range(1.0, 90.0, 1.0) var windfall_degrees := 35.0
@export_range(1, 8, 1) var windfall_uses := 3
@export_range(0.0, 2.0, 0.01) var windfall_cooldown_seconds := 0.12
## Newton's Apple: how many chains one Fruit may start, what a launched body does
## on impact, and the global budget that keeps a dense fight bounded.
@export_range(1, 8, 1) var newton_starters_per_fruit := 3
@export_range(0.0, 5.0, 0.05) var newton_starter_cooldown := 0.25
@export_range(0.05, 3.0, 0.05) var newton_active_seconds := 0.45
@export_range(0.0, 2.0, 0.01) var newton_first_damage_share := 0.55
@export_range(0.0, 2.0, 0.01) var newton_first_knockback_share := 0.65
@export_range(0.0, 2.0, 0.01) var newton_second_damage_share := 0.30
@export_range(0.0, 2.0, 0.01) var newton_second_knockback_share := 0.40
@export_range(1, 20, 1) var newton_active_maximum := 6
@export_range(1, 40, 1) var newton_impacts_per_second := 8
@export_range(1, 8, 1) var newton_impacts_per_frame := 2
@export_range(1, 64, 1) var newton_trajectory_candidates := 16
## Elite and boss shares for a Falling Body, which can strike them but never
## become one: turning a boss into a projectile is not a thing this may do.
@export_range(0.0, 1.0, 0.01) var newton_elite_damage_share := 0.50
@export_range(0.0, 1.0, 0.01) var newton_elite_knockback_share := 0.35
@export_range(0.0, 1.0, 0.01) var newton_boss_damage_share := 0.25
## Whiplash: an Apical hit snaps the tip past its endpoint at reduced damage,
## reaching only enemies the parent stroke did not.
@export_range(0.0, 3.0, 0.05) var whiplash_delay_seconds := 0.10
@export_range(10.0, 400.0, 5.0) var whiplash_reach_pixels := 70.0
@export_range(4.0, 120.0, 1.0) var whiplash_width_pixels := 30.0
@export_range(0.0, 2.0, 0.01) var whiplash_damage_share := 0.40
## Runner: the first enemy a natural sweep kills sprouts one lash at a neighbour.
@export_range(0.0, 3.0, 0.05) var runner_delay_seconds := 0.30
@export_range(10.0, 400.0, 5.0) var runner_range_pixels := 135.0
@export_range(0.0, 2.0, 0.01) var runner_damage_share := 0.45
@export_range(1, 12, 1) var runner_active_maximum := 3
## Climber: a wrapped Vine cinches the section past its first bend.
@export_range(0.0, 3.0, 0.05) var climber_delay_seconds := 0.12
@export_range(0.0, 2.0, 0.01) var climber_damage_share := 0.40
## Girdling: consecutive Apical hits on one enemy crush it on the next contact.
@export_range(1, 8, 1) var girdling_required_hits := 2
@export_range(0.1, 20.0, 0.1) var girdling_window_seconds := 2.5
@export_range(0.1, 30.0, 0.1) var girdling_duration_seconds := 3.0
@export_range(0.0, 4.0, 0.01) var girdling_damage_share := 0.75
@export_range(0.0, 30.0, 0.1) var girdling_target_cooldown := 4.0
@export_range(1, 20, 1) var girdling_maximum_marks := 4
## Liana: three consecutive successful Apical sweeps unleash a rapid cascade.
@export_range(1, 8, 1) var liana_required_sweeps := 3
@export_range(1, 12, 1) var liana_bonus_sweeps := 4
@export_range(0.0, 3.0, 0.05) var liana_first_delay := 0.12
@export_range(0.02, 2.0, 0.01) var liana_interval_seconds := 0.16
@export_range(0.0, 2.0, 0.01) var liana_damage_share := 0.60
@export_range(0.1, 60.0, 0.5) var liana_cooldown_seconds := 5.0
@export_range(1, 20, 1) var twining_sweep_interval := 4
@export_range(0.0, 1.0, 0.01) var twining_damage_share := 0.55
@export_range(0.05, 2.0, 0.05) var twining_delay_seconds := 0.30

var simulation_paused := false
var _thistles: Array[ThistleState] = []
var _thorns: Array[ThornState] = []
var _fruits: Array[FruitState] = []
var _fruitseeds: Array[FruitseedState] = []
var _saplings: Array[SaplingState] = []
var _pending_events: Array[PendingEvent] = []
var _fruit_release_remaining := 0.0
## The light under Grandma, and the free-running clock its breath rides on.
var _player_rooted_glow := RootedGlowState.new()
var _rooted_glow_phase := 0.0
var _fruit_release_count := 0
var _fruit_terminal_count := 0
var _rot_terminal_count := 0
var _orchard_terminal_count := 0
var _thistle_sequence := 0
## Bare ground left behind by a collapsed turret, so a replacement cannot appear
## in the same breath as the loss.
var _thistle_replant_remaining := 0.0
var _fruit_sequence := 0
var _network_cycle_count := 0
var _rootstock_heavy_count := 0
var _crown_cooldown := 0.0
## Network-wide natural thorn impacts, counted separately per relic because the two
## thresholds are different and neither may consume the other's progress.
var _relay_impacts := 0
var _forking_impacts := 0
var _relay_cooldown := 0.0
var _forking_cooldown := 0.0
var _answering_cooldown := 0.0
## Opening volleys owed to newly grown turrets: [thistle_sequence, remaining].
var _rosette_queue: Array = []
## Embedded thorns per enemy: {enemy_id: [stacks, remaining]}.
var _pincushion_stacks := {}
## Fruit Salad marks: {enemy_id: [release_id, fruit_id, remaining]}.
var _fruit_salad_marks := {}
## Falling Bodies in flight, each [enemy_id, target_id, remaining, generation,
## damage, knockback]. The target is chosen once, when the body is launched.
var _falling_bodies: Array = []
var _newton_impacts_this_second := 0
var _newton_second_remaining := 1.0
var _newton_impacts_this_frame := 0
## Runners waiting to lash, each [position, remaining, damage].
var _runners: Array = []
## Girdling progress and marks: {enemy_id: [consecutive_hits, last_sweep, mark_remaining]}.
var _girdling: Dictionary = {}
var _girdling_cooldowns := {}
## Consecutive natural sweeps that landed an Apical hit.
var _liana_progress := 0
var _liana_cooldown := 0.0
var _liana_remaining := 0
var _liana_step := 0.0
var _liana_facing := Vector2.RIGHT
var _liana_left_to_right := true
## Whether the stroke being resolved actually bent around terrain, and whether it
## hit anything past that bend. Climber requires both.
var _sweep_bend_index := -1
var _sweep_hit_past_bend := false
## Natural sweeps so far, so consecutive-sweep relics can tell one from the next.
var _natural_sweep_index := 0
## Runner is one sprout per natural sweep, taken by the first kill it scores.
var _runner_spawned_this_sweep := false
var _hedge_battery_cooldown := 0.0
var _rootstock_network_cooldown := 0.0
var _inoculator_pulsed := {}
var _cane_sweep_hits := PackedInt32Array()
var _briar_cane_full_hit := false
var _wisteria_armed := false
var _gourdvine_pending_count := 0
var _gourdvine_attached := false
var _gourdvine_directions := PackedFloat32Array()
var _graft_cuttings := 0
var _graft_all_fruit := false
var _graft_prize := false
var _orchard_release_toggle := false
var _trellis_stacks := 0
var _recurve_armed := false
var _twining_progress := 0
var _current_sweep_apical_hit := false
var _current_sweep_wisteria := false
var _current_sweep_facing := Vector2.RIGHT
var _current_sweep_left_to_right := true
var _current_sweep_reach := 0.0
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	assert(progression != null, "PhaseBAdaptationDirector requires PhaseBProgression")
	assert(evolutions != null, "PhaseBAdaptationDirector requires PhaseBEvolutions")
	assert(player != null, "PhaseBAdaptationDirector requires PhaseBPlayer")
	assert(territory_field != null, "PhaseBAdaptationDirector requires TerritoryField")
	assert(overlay != null, "PhaseBAdaptationDirector requires TerritoryPrototypeOverlay")
	assert(combat != null, "PhaseBAdaptationDirector requires PhaseBCombatDirector")
	_configure_pools()
	combat.cane_sweep_started.connect(_on_cane_sweep_started)
	combat.cane_enemy_hit.connect(_on_cane_enemy_hit)
	combat.cane_sweep_finished.connect(_on_cane_sweep_finished)
	overlay.bloom_detonated.connect(_on_bloom_detonated)
	if pruning_director != null and pruning_director.has_signal("ring_released"):
		pruning_director.ring_released.connect(_on_pruning_ring_released)
	reset_adaptations()


func _process(delta: float) -> void:
	if simulation_paused:
		return
	advance(delta)


func advance(delta: float) -> void:
	_refresh_vine_modifiers()
	_crown_cooldown = maxf(0.0, _crown_cooldown - delta)
	_hedge_battery_cooldown = maxf(0.0, _hedge_battery_cooldown - delta)
	_rootstock_network_cooldown = maxf(0.0, _rootstock_network_cooldown - delta)
	_update_pending_events(delta)
	# The two current p99 offenders are split out by name here rather than measured
	# as one "adaptation director" bar, because Thistle spikes on a volley cadence
	# and Fruit spikes on territory writes, and one number cannot show both.
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_THISTLE_TOTAL)
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_THISTLE_RELIC_LOGIC)
	_advance_thistle_relics(delta)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_THISTLE_RELIC_LOGIC)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_THISTLE_TOTAL)
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_FRUIT_TOTAL)
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_FRUIT_RELICS)
	_advance_fruit_relics(delta)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_FRUIT_RELICS)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_FRUIT_TOTAL)
	_advance_vine_relics(delta)
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_THISTLE_TOTAL)
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_THISTLE_TARGETING)
	_update_thistles(delta)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_THISTLE_TARGETING)
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_THISTLE_PROJECTILE_UPDATE)
	_update_thorns(delta)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_THISTLE_PROJECTILE_UPDATE)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_THISTLE_TOTAL)
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_FRUIT_TOTAL)
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_FRUIT_ADVANCE)
	_update_fruits(delta)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_FRUIT_ADVANCE)
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_FRUIT_SEEDS)
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_FRUITSEEDS)
	_update_fruitseeds(delta)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_FRUITSEEDS)
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_SAPLINGS)
	_update_saplings(delta)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_SAPLINGS)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_FRUIT_SEEDS)
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_FRUIT_RELEASE)
	_update_fruit_release_cadence(delta)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_FRUIT_RELEASE)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_FRUIT_TOTAL)
	_update_rooted_glow(delta)
	queue_redraw()


func set_simulation_paused(paused: bool) -> void:
	simulation_paused = paused


func reset_adaptations() -> void:
	for thistle in _thistles:
		thistle.active = false
	for thorn in _thorns:
		thorn.active = false
	for fruit in _fruits:
		fruit.active = false
	for fruitseed in _fruitseeds:
		fruitseed.active = false
	for sapling in _saplings:
		sapling.active = false
	for pending in _pending_events:
		pending.active = false
	_fruit_release_remaining = fruit_release_interval
	_player_rooted_glow.clear()
	for thistle in _thistles:
		thistle.rooted_glow.clear()
	_rooted_glow_phase = 0.0
	_fruit_release_count = 0
	_fruit_terminal_count = 0
	_rot_terminal_count = 0
	_orchard_terminal_count = 0
	_thistle_sequence = 0
	_thistle_replant_remaining = 0.0
	_fruit_sequence = 0
	_network_cycle_count = 0
	_rootstock_heavy_count = 0
	_crown_cooldown = 0.0
	_relay_impacts = 0
	_forking_impacts = 0
	_relay_cooldown = 0.0
	_forking_cooldown = 0.0
	_answering_cooldown = 0.0
	_rosette_queue.clear()
	_pincushion_stacks.clear()
	_fruit_salad_marks.clear()
	_falling_bodies.clear()
	_runners.clear()
	_girdling.clear()
	_girdling_cooldowns.clear()
	_liana_progress = 0
	_liana_cooldown = 0.0
	_liana_remaining = 0
	_liana_step = 0.0
	_sweep_bend_index = -1
	_sweep_hit_past_bend = false
	_natural_sweep_index = 0
	_runner_spawned_this_sweep = false
	_newton_impacts_this_second = 0
	_newton_second_remaining = 1.0
	_newton_impacts_this_frame = 0
	_hedge_battery_cooldown = 0.0
	_rootstock_network_cooldown = 0.0
	_inoculator_pulsed.clear()
	_cane_sweep_hits.clear()
	_briar_cane_full_hit = false
	_wisteria_armed = false
	_gourdvine_pending_count = 0
	_gourdvine_attached = false
	_gourdvine_directions.clear()
	_graft_cuttings = 0
	_graft_all_fruit = false
	_graft_prize = false
	_orchard_release_toggle = false
	_trellis_stacks = 0
	_recurve_armed = false
	_twining_progress = 0
	_current_sweep_apical_hit = false
	_current_sweep_wisteria = false
	_current_sweep_facing = Vector2.RIGHT
	_current_sweep_left_to_right = true
	_current_sweep_reach = 0.0
	_random.seed = progression.run_seed ^ 0xF817A11
	apply_modifiers()
	queue_redraw()


func apply_modifiers() -> void:
	_refresh_vine_modifiers()
	var vine_active := progression.has_path_active(PhaseBProgression.PathId.VINE)
	combat.set_cane_auto_targeting(vine_active)
	combat.set_heartwood_rank(_evolution_rank(PhaseBProgression.EvolutionId.HEARTWOOD))


func _refresh_vine_modifiers() -> void:
	var vine_active := progression.has_path_active(PhaseBProgression.PathId.VINE)
	var damage_multiplier := 1.0
	var cooldown_multiplier := 1.0
	var reach_multiplier := 1.0
	var apical_bonus := 0.0
	if vine_active:
		var origin := player.get_arena_position()
		# Each Vine line takes Root Potency on its own bonus, so the Network
		# lengthens the reach, quickens the stroke, and hardens the tip rather than
		# only inflating one damage figure. This refresh runs every frame and all
		# four lines resolve at the same point, so they share one Network sample.
		var network := _root_network_at(origin)
		damage_multiplier += _root_scaled_bonus_with(
			PhaseBProgression.UpgradeId.VINE_LIGNIFICATION, 0.25, network
		)
		cooldown_multiplier /= 1.0 + _root_scaled_bonus_with(
			PhaseBProgression.UpgradeId.VINE_TURGOR, 0.15, network
		)
		reach_multiplier += _root_scaled_bonus_with(
			PhaseBProgression.UpgradeId.VINE_ELONGATION, 0.20, network
		)
		apical_bonus = _root_scaled_bonus_with(
			PhaseBProgression.UpgradeId.VINE_APICAL_DOMINANCE, 0.25, network
		)
	combat.set_cane_modifiers(
		damage_multiplier,
		cooldown_multiplier,
		reach_multiplier,
		apical_bonus
	)
	# The rope is the Vine. Holding the Adaptation is what makes the Cane resolve
	# through a simulated body instead of through its authored sector.
	combat.set_vine_enabled(vine_active)


## Root Potency reaches Thistle, Vine, and Fruit one line at a time, in the shape
## that line is about. A line is only amplified where the effect actually happens,
## and only when the build has started the line itself: Root deepens what is being
## built and never invents an unowned line out of Root alone or out of a temporary
## casino loan.
func _root_amplifies_line(upgrade_id: int) -> bool:
	return (
		progression.get_owned_upgrade_level(upgrade_id) > 0
		and root_director != null
		and root_director.has_path()
	)


## Counts get whole units, because half a thorn and half a Fruit are not things.
## Clustering, Burr, and Fruit Set each gain exactly one, and only out of ground
## that is actually Mature -- there is no partial unit to scale.
func _root_count_step(upgrade_id: int, origin: Vector2) -> int:
	if not _root_amplifies_line(upgrade_id):
		return 0
	return 1 if territory_field.is_mature_player_territory_at_local(origin) else 0


## Everything that is a rate, a reach, or a damage figure gets its own per-rank
## bonus multiplied instead. This is the Root Network multiplier read where the
## effect happens, so it rises and falls continuously with the maturity of the
## ground under it rather than snapping on at the Mature threshold. It scales the
## line's bonus and not the authored base, so amplification is proportional to what
## the run actually invested in that line.
func _root_bonus_scale(upgrade_id: int, origin: Vector2) -> float:
	if not _root_amplifies_line(upgrade_id):
		return 1.0
	return maxf(1.0, root_director.get_network_multiplier_here(origin))


## One line's per-rank bonus after Root Potency: rank x per-rank value x the
## Network where it resolves. Every rate/reach/damage line reads its bonus through
## this, which is what keeps the amplified number in the ROOTED row honest.
func _root_scaled_bonus(upgrade_id: int, per_rank: float, origin: Vector2) -> float:
	return per_rank * float(_upgrade(upgrade_id)) * _root_bonus_scale(upgrade_id, origin)


## The Network at a point, sampled once for callers whose lines all resolve there.
## The projection query behind it walks nearby ground, so a per-frame refresh or a
## multi-line spawn takes one sample instead of one per line.
func _root_network_at(origin: Vector2) -> float:
	if root_director == null or not root_director.has_path():
		return 1.0
	return maxf(1.0, root_director.get_network_multiplier_here(origin))


## Same rule as _root_scaled_bonus, for a caller that already holds that sample.
func _root_scaled_bonus_with(upgrade_id: int, per_rank: float, network: float) -> float:
	var scale := network if _root_amplifies_line(upgrade_id) else 1.0
	return per_rank * float(_upgrade(upgrade_id)) * scale


func _configure_pools() -> void:
	_thistles.clear()
	_thorns.clear()
	_fruits.clear()
	_fruitseeds.clear()
	_saplings.clear()
	_pending_events.clear()
	for _index in range(thistle_pool_size):
		_thistles.append(ThistleState.new())
	for _index in range(thorn_pool_size):
		_thorns.append(ThornState.new())
	for _index in range(fruit_pool_size):
		_fruits.append(FruitState.new())
	for _index in range(fruitseed_pool_size):
		_fruitseeds.append(FruitseedState.new())
	for _index in range(sapling_pool_size):
		_saplings.append(SaplingState.new())
	for _index in range(pending_event_pool_size):
		_pending_events.append(PendingEvent.new())


func _upgrade(upgrade_id: int) -> int:
	return progression.get_upgrade_level(upgrade_id)


func _evolution_rank(evolution_id: int) -> int:
	if not progression.has_active_evolution(evolution_id):
		return 0
	return evolutions.get_active_evolution_rank()


func _has_relic(relic_id: int) -> bool:
	return progression.has_relic(relic_id)


func get_active_thistle_count() -> int:
	var count := 0
	for thistle in _thistles:
		if thistle.active:
			count += 1
	return count


func get_active_thorn_count() -> int:
	var count := 0
	for thorn in _thorns:
		if thorn.active:
			count += 1
	return count


func get_active_fruit_count() -> int:
	var count := 0
	for fruit in _fruits:
		if fruit.active:
			count += 1
	return count


func get_active_fruitseed_count() -> int:
	var count := 0
	for fruitseed in _fruitseeds:
		if fruitseed.active:
			count += 1
	return count


func get_active_sapling_count() -> int:
	var count := 0
	for sapling in _saplings:
		if sapling.active:
			count += 1
	return count


func _update_thistles(delta: float) -> void:
	if not progression.has_path_active(PhaseBProgression.PathId.THISTLE):
		for thistle in _thistles:
			thistle.active = false
		for thorn in _thorns:
			thorn.active = false
		return
	var rootstock_rank := _evolution_rank(PhaseBProgression.EvolutionId.ROOTSTOCK)
	var player_position := player.get_arena_position()
	var stick_radius_squared := thistle_stick_radius_pixels * thistle_stick_radius_pixels
	_thistle_replant_remaining = maxf(0.0, _thistle_replant_remaining - delta)
	for thistle in _thistles:
		if not thistle.active:
			continue
		if not thistle.permanent:
			thistle.temporary_remaining -= delta
			if thistle.temporary_remaining <= 0.0:
				thistle.active = false
				continue
		thistle.stick_cooldown_remaining = maxf(
			0.0, thistle.stick_cooldown_remaining - delta
		)
		if thistle.carried:
			# Riding Grandma. Support is deliberately not evaluated: the turret is on
			# her coat, not in the ground, so it fires happily over bare dirt.
			thistle.position = player_position
			thistle.unsupported_remaining = -1.0
			thistle.carry_remaining -= delta
			if thistle.carry_remaining <= 0.0:
				_drop_thistle(thistle)
				continue
		elif (
			thistle.permanent
			and thistle.stick_cooldown_remaining <= 0.0
			and player_position.distance_squared_to(thistle.position) <= stick_radius_squared
		):
			_stick_thistle_to_player(thistle, player_position)
		elif not _resolve_thistle_support(thistle, delta, rootstock_rank):
			continue
		thistle.bloom_charge_remaining = maxf(0.0, thistle.bloom_charge_remaining - delta)
		thistle.attack_remaining -= delta
		if thistle.attack_remaining > 0.0:
			continue
		_fire_thistle(thistle)
		thistle.attack_remaining = _get_thistle_attack_interval(thistle.position)
	_ensure_permanent_thistles()


## Whether a planted turret still has the Green under it. Collapses it and answers
## false when it does not.
func _resolve_thistle_support(
	thistle: ThistleState,
	delta: float,
	rootstock_rank: int
) -> bool:
	if territory_field.is_owned_at_local(thistle.position):
		thistle.unsupported_remaining = -1.0
		return true
	if rootstock_rank >= 1:
		if thistle.unsupported_remaining < 0.0:
			thistle.unsupported_remaining = 3.0
		else:
			thistle.unsupported_remaining -= delta
		if thistle.unsupported_remaining > 0.0:
			return true
	_collapse_thistle(thistle, true)
	return false


func _stick_thistle_to_player(thistle: ThistleState, player_position: Vector2) -> void:
	thistle.carried = true
	thistle.carry_remaining = get_thistle_carry_seconds()
	thistle.position = player_position
	thistle.unsupported_remaining = -1.0
	# A band tightening around a body is exactly what a burr on a coat is.
	overlay.spawn_relic_cue(
		TerritoryPrototypeOverlay.RelicCue.BAND,
		player_position,
		18.0,
		Color("b98fd4"),
		Vector2.UP
	)


func _drop_thistle(thistle: ThistleState) -> void:
	thistle.carried = false
	thistle.carry_remaining = 0.0
	thistle.stick_cooldown_remaining = get_thistle_stick_cooldown_seconds()
	var site := player.get_arena_position()
	# Carrying the turret somewhere useful is the decision the Adaptation is built
	# on, so working it loose over bare dirt has to actually cost the turret.
	var cell := (
		_find_unoccupied_thistle_cell(site, thistle.sequence)
		if territory_field.is_owned_at_local(site)
		else -1
	)
	if cell < 0:
		status_requested.emit("THISTLE — worked loose off the Green, and withered.")
		_collapse_thistle(thistle, true)
		return
	thistle.position = territory_field.get_cell_local_position(cell)
	thistle.unsupported_remaining = -1.0
	thistle.collapse_volley_fired = false
	thistle.attack_remaining = minf(thistle.attack_remaining, 0.12)
	if thistle.permanent and _has_relic(PhaseBRelicCatalog.Id.ROSETTE):
		# A turret that has just taken root is a newly grown one however it got
		# there, so Rosette now pays out on every drop rather than once a run.
		_rosette_queue.append([thistle.sequence, rosette_delay_seconds])


func _ensure_permanent_thistles() -> void:
	if _thistle_replant_remaining > 0.0:
		return
	var wanted := _get_thistle_capacity()
	var active_permanent := 0
	for thistle in _thistles:
		if thistle.active and thistle.permanent:
			active_permanent += 1
	while active_permanent < wanted:
		if not _plant_thistle(true, 0.0):
			break
		active_permanent += 1


func _get_thistle_capacity() -> int:
	# One turret, always. Thistle is no longer a field of free stationary damage you
	# grow and forget; it is a single thing you have to walk over and carry.
	return 1


func _count_started_thistle_lines() -> int:
	# Owned ranks only. A Clover jackpot lends every Thistle line its ceiling for a
	# few seconds, and carry earned on the strength of that loan would outlast it.
	var started := 0
	for upgrade_id in [
		PhaseBProgression.UpgradeId.THISTLE_CLUSTERING,
		PhaseBProgression.UpgradeId.THISTLE_DEHISCENCE,
		PhaseBProgression.UpgradeId.THISTLE_BURR,
		PhaseBProgression.UpgradeId.THISTLE_NEEDLEPOINT,
	]:
		if progression.get_owned_upgrade_level(upgrade_id) > 0:
			started += 1
	return started


func get_thistle_carry_seconds() -> float:
	return thistle_carry_seconds + thistle_carry_seconds_per_line * float(
		_count_started_thistle_lines()
	)


func get_thistle_stick_cooldown_seconds() -> float:
	return maxf(
		0.5,
		thistle_stick_cooldown_seconds
		- thistle_stick_cooldown_per_line * float(_count_started_thistle_lines())
	)


func _plant_thistle(
	permanent: bool,
	temporary_seconds: float,
	wanted := INVALID_POSITION,
	burdock_temporary: bool = false
) -> bool:
	var thistle: ThistleState
	for candidate in _thistles:
		if not candidate.active:
			thistle = candidate
			break
	if thistle == null:
		return false
	var site := wanted
	if site.x <= -90000.0:
		var angle := float(_thistle_sequence) * 2.399963
		var radius := thistle_planting_radius * (0.65 + 0.35 * float(_thistle_sequence % 3) / 2.0)
		site = player.get_arena_position() + Vector2.from_angle(angle) * radius
	var owned_cell := _find_unoccupied_thistle_cell(site)
	if owned_cell < 0:
		return false
	site = territory_field.get_cell_local_position(owned_cell)
	_thistle_sequence += 1
	thistle.active = true
	thistle.permanent = permanent
	thistle.position = site
	thistle.attack_remaining = 0.12 + 0.08 * float(thistle.sequence % 4)
	thistle.temporary_remaining = maxf(0.0, temporary_seconds)
	thistle.unsupported_remaining = -1.0
	thistle.collapse_volley_fired = false
	thistle.firing_cycles = 0
	thistle.heavy_thorns = 0
	thistle.bloom_charge_remaining = 0.0
	thistle.sequence = _thistle_sequence
	thistle.burdock_temporary = burdock_temporary
	thistle.carried = false
	thistle.carry_remaining = 0.0
	thistle.stick_cooldown_remaining = get_thistle_stick_cooldown_seconds()
	if permanent and _has_relic(PhaseBRelicCatalog.Id.ROSETTE):
		# Temporary Evolution turrets are explicitly excluded; a permanent
		# replacement grown after a collapse is not.
		_rosette_queue.append([thistle.sequence, rosette_delay_seconds])
	return true


func _find_unoccupied_thistle_cell(wanted: Vector2, exclude_sequence: int = -1) -> int:
	var best_cell := -1
	var best_distance_squared := INF
	var minimum_spacing_squared := (
		thistle_minimum_spacing_pixels * thistle_minimum_spacing_pixels
	)
	var cell_count := territory_field.get_grid_width() * territory_field.get_grid_height()
	for cell in range(cell_count):
		if not territory_field.is_owned_cell(cell):
			continue
		var position := territory_field.get_cell_local_position(cell)
		var occupied := false
		for planted in _thistles:
			if (
				planted.active
				and planted.sequence != exclude_sequence
				and planted.position.distance_squared_to(position) < minimum_spacing_squared
			):
				occupied = true
				break
		if occupied:
			continue
		var distance_squared := wanted.distance_squared_to(position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_cell = cell
	return best_cell


func _collapse_thistle(thistle: ThistleState, support_loss: bool) -> void:
	if (
		support_loss
		and _has_relic(PhaseBRelicCatalog.Id.SEEDHEAD)
		and not thistle.collapse_volley_fired
	):
		thistle.collapse_volley_fired = true
		_fire_thistle(thistle, 1.5, 0, false)
	thistle.active = false
	thistle.carried = false
	thistle.carry_remaining = 0.0
	if thistle.permanent:
		_thistle_replant_remaining = maxf(_thistle_replant_remaining, thistle_replant_seconds)


func _get_thistle_attack_interval(origin: Vector2) -> float:
	var rate := 1.0 + _root_scaled_bonus(
		PhaseBProgression.UpgradeId.THISTLE_DEHISCENCE, 0.15, origin
	)
	return thistle_attack_interval / maxf(0.05, rate)


func _fire_thistle(
	thistle: ThistleState,
	damage_scale: float = 1.0,
	extra_pierce: int = 0,
	counts_as_normal_cycle: bool = true,
	forced_target_id: int = -1
) -> int:
	if not thistle.active:
		return 0
	var projectile_count := (
		1
		+ _upgrade(PhaseBProgression.UpgradeId.THISTLE_CLUSTERING)
		+ _root_count_step(
			PhaseBProgression.UpgradeId.THISTLE_CLUSTERING, thistle.position
		)
	)
	var targets := PackedInt32Array()
	if forced_target_id >= 0 and combat.is_enemy_active(forced_target_id):
		var forced_position := combat.get_enemy_position(forced_target_id)
		if (
			thistle.position.distance_to(forced_position) <= thistle_range_pixels
			and territory_field.is_growth_path_clear(thistle.position, forced_position)
		):
			targets.append(forced_target_id)
	else:
		targets = _collect_enemy_targets(thistle.position, thistle_range_pixels)
	if targets.is_empty():
		return 0
	# Volley cadence, so a frame's Thistle cost can be read against how many
	# Thistles actually fired into it rather than against wall time alone.
	PhaseBPerfCounters.count(PhaseBPerfCounters.COUNT_THISTLES_FIRED)
	var rootstock_rank := _evolution_rank(PhaseBProgression.EvolutionId.ROOTSTOCK)
	var heavy_primary := false
	if counts_as_normal_cycle:
		thistle.firing_cycles += 1
		var heavy_interval := 5
		if (
			rootstock_rank >= 4
			and territory_field.is_mature_player_territory_at_local(thistle.position)
		):
			heavy_interval = 4
		if rootstock_rank >= 2 and thistle.firing_cycles % heavy_interval == 0:
			heavy_primary = true
			thistle.heavy_thorns += 1
	var bloomshot_primary := thistle.bloom_charge_remaining > 0.0
	var burstbloom_rank := _evolution_rank(PhaseBProgression.EvolutionId.BURSTBLOOM)
	var bloomshot_force := 0.50 if burstbloom_rank >= 4 else 0.35
	var fired := 0
	for index in range(projectile_count):
		var target_id := targets[index % targets.size()]
		if _spawn_thorn(
			thistle.position,
			target_id,
			damage_scale,
			extra_pierce + (2 if heavy_primary and index == 0 and rootstock_rank >= 3 else 0),
			heavy_primary and index == 0,
			bloomshot_primary and index == 0,
			bloomshot_force,
			0.0,
			-1,
			true,
			0,
			thistle.sequence,
			heavy_primary and index == 0 and rootstock_rank >= 3
		):
			fired += 1
	if not counts_as_normal_cycle:
		return fired
	# Phyllotaxis is a secondary packet, never a firing cycle of its own. It inherits
	# Needlepoint, but Clustering and more than one Burr hop are explicitly excluded.
	if (
		_has_relic(PhaseBRelicCatalog.Id.PHYLLOTAXIS)
		and phyllotaxis_cycle_interval > 0
		and thistle.firing_cycles % phyllotaxis_cycle_interval == 0
	):
		# The spiral packet has to be unmistakable against an ordinary clustered
		# volley, so the cue turns as it plays rather than sitting still.
		overlay.spawn_relic_cue(
			TerritoryPrototypeOverlay.RelicCue.GHOST,
			thistle.position,
			thistle_range_pixels * 0.35,
			Color("d7e86a"),
			Vector2.ZERO,
			false,
			1.0,
			TerritoryPrototypeOverlay.RelicMotif.SWIRL,
			1.6
		)
		for bonus_index in range(phyllotaxis_bonus_thorns):
			var spread_progress := (
				0.5
				if phyllotaxis_bonus_thorns <= 1
				else float(bonus_index) / float(phyllotaxis_bonus_thorns - 1)
			)
			var launch_angle_offset := deg_to_rad(lerpf(
				-phyllotaxis_spread_degrees * 0.5,
				phyllotaxis_spread_degrees * 0.5,
				spread_progress
			))
			_spawn_thorn(
				thistle.position,
				targets[0],
				phyllotaxis_damage_share,
				0,
				false,
				false,
				0.0,
				0.0,
				1,
				true,
				0,
				thistle.sequence,
				false,
				launch_angle_offset,
				ThornSource.PHYLLOTAXIS
			)
	if thistle.permanent:
		_network_cycle_count += 1
	if (
		_has_relic(PhaseBRelicCatalog.Id.CROWN_OF_THORNS)
		and thistle.permanent
		and crown_cycle_interval > 0
		and _network_cycle_count % crown_cycle_interval == 0
		and _crown_cooldown <= 0.0
	):
		_crown_cooldown = crown_cooldown_seconds
		_fire_all_thistles(crown_damage_share, 0, false)
		if get_active_thistle_count() <= 1:
			for volley in range(1, crown_solo_volleys):
				_queue_pending_event(
					PendingKind.THISTLE_VOLLEY,
					crown_solo_interval * float(volley),
					thistle.position,
					Vector2.RIGHT,
					true,
					crown_damage_share,
					0,
					0
				)
	if heavy_primary and fired > 0:
		_rootstock_heavy_count += 1
		if (
			rootstock_rank >= 5
			and _rootstock_heavy_count % 3 == 0
			and _rootstock_network_cooldown <= 0.0
		):
			_rootstock_network_cooldown = 8.0
			_fire_rootstock_network_salvo()
	return fired


func _advance_vine_relics(delta: float) -> void:
	_liana_cooldown = maxf(0.0, _liana_cooldown - delta)
	for enemy_id in _girdling_cooldowns.keys():
		var remaining := float(_girdling_cooldowns[enemy_id]) - delta
		if remaining <= 0.0:
			_girdling_cooldowns.erase(enemy_id)
		else:
			_girdling_cooldowns[enemy_id] = remaining
	for enemy_id in _girdling.keys():
		var mark: Array = _girdling[enemy_id]
		mark[2] = float(mark[2]) - delta
		if float(mark[2]) <= 0.0 or not combat.is_enemy_active(enemy_id):
			_girdling.erase(enemy_id)
	for index in range(_runners.size() - 1, -1, -1):
		var runner: Array = _runners[index]
		runner[1] = float(runner[1]) - delta
		if float(runner[1]) > 0.0:
			continue
		_runners.remove_at(index)
		_lash_runner(runner[0], float(runner[2]))
	if _liana_remaining <= 0:
		return
	_liana_step -= delta
	if _liana_step > 0.0:
		return
	_liana_step = liana_interval_seconds
	_liana_remaining -= 1
	# Alternating, from Grandma's current position, on the same continuous rope.
	_liana_left_to_right = not _liana_left_to_right
	combat.perform_bonus_cane_sweep(
		_liana_facing,
		_liana_left_to_right,
		liana_damage_share
	)


func _lash_runner(origin: Vector2, damage: float) -> void:
	# A direct lash from the corpse to one neighbour. It has no sweep arc of its own
	# and never receives Apical Dominance: it is a runner, not a second Vine.
	var target := -1
	var nearest := runner_range_pixels
	for enemy_id in combat.get_active_enemy_ids():
		var distance := combat.get_enemy_position(enemy_id).distance_to(origin)
		if distance > nearest:
			continue
		if not territory_field.is_growth_path_clear(
			origin, combat.get_enemy_position(enemy_id)
		):
			continue
		nearest = distance
		target = enemy_id
	if target < 0:
		return
	combat.damage_enemy_by_id(target, damage, PhaseBCombatDirector.DeathSource.RELIC)


func _note_vine_apical_hit(enemy_id: int, damage: float) -> void:
	## Girdling builds only on natural Apical hits, and only while the same enemy
	## keeps taking them on consecutive sweeps.
	if not _has_relic(PhaseBRelicCatalog.Id.GIRDLING):
		return
	if _girdling_cooldowns.has(enemy_id):
		return
	var mark: Array = _girdling.get(enemy_id, [0, -1, 0.0])
	if int(mark[1]) == _natural_sweep_index:
		return
	# A gap of more than one sweep breaks the streak, which is what makes Girdling
	# about sustained accuracy rather than about hitting the same body eventually.
	if int(mark[1]) >= 0 and _natural_sweep_index - int(mark[1]) > 1:
		mark[0] = 0
	mark[0] = int(mark[0]) + 1
	mark[1] = _natural_sweep_index
	if int(mark[0]) >= girdling_required_hits:
		mark[2] = girdling_duration_seconds
		# A visible tightening band, so a Girdled target can be picked out of a crowd
		# before the constriction lands.
		overlay.spawn_relic_cue(
			TerritoryPrototypeOverlay.RelicCue.BAND,
			combat.get_enemy_position(enemy_id),
			26.0,
			Color("6fe8c8"),
			Vector2.ZERO,
			false,
			1.0,
			TerritoryPrototypeOverlay.RelicMotif.RING
		)
	if _girdling.size() >= girdling_maximum_marks and not _girdling.has(enemy_id):
		return
	_girdling[enemy_id] = mark


func _try_consume_girdling(enemy_id: int, damage: float) -> void:
	## Any Vine contact spends the mark, relic-generated strokes included. Only
	## building it is restricted to natural Apical hits.
	if not _girdling.has(enemy_id):
		return
	var mark: Array = _girdling[enemy_id]
	if float(mark[2]) <= 0.0:
		return
	_girdling.erase(enemy_id)
	_girdling_cooldowns[enemy_id] = girdling_target_cooldown
	combat.damage_enemy_by_id(
		enemy_id,
		damage * girdling_damage_share,
		PhaseBCombatDirector.DeathSource.RELIC
	)


func _try_whiplash(origin: Vector2, facing: Vector2, damage: float) -> void:
	if not _has_relic(PhaseBRelicCatalog.Id.WHIPLASH):
		return
	# Past the tip, and only onto bodies the parent stroke did not already reach.
	var tip := origin + facing * _current_sweep_reach
	for enemy_id in combat.get_active_enemy_ids():
		if _cane_sweep_hits.has(enemy_id):
			continue
		var enemy_position := combat.get_enemy_position(enemy_id)
		if Geometry2D.get_closest_point_to_segment(
			enemy_position, tip, tip + facing * whiplash_reach_pixels
		).distance_to(enemy_position) > whiplash_width_pixels:
			continue
		if not territory_field.is_growth_path_clear(tip, enemy_position):
			continue
		combat.damage_enemy_by_id(
			enemy_id,
			damage * whiplash_damage_share,
			PhaseBCombatDirector.DeathSource.RELIC
		)
		_try_consume_girdling(enemy_id, damage)


func _try_climber(damage: float) -> void:
	## Requires a real bend in the simulated rope and a hit past it. The cinch
	## replays the actual post-bend path rather than an independently drawn line, so
	## it can never reach through an obstacle the Vine did not itself go around.
	if not _has_relic(PhaseBRelicCatalog.Id.CLIMBER):
		return
	if _sweep_bend_index < 0 or not _sweep_hit_past_bend:
		return
	var whip: PhaseBVineWhip = combat.vine_whip
	if whip == null or not whip.is_built():
		return
	var body := whip.points
	for enemy_id in combat.get_active_enemy_ids():
		var enemy_position := combat.get_enemy_position(enemy_id)
		var reached := false
		for index in range(_sweep_bend_index, body.size() - 1):
			if Geometry2D.get_closest_point_to_segment(
				enemy_position, body[index], body[index + 1]
			).distance_to(enemy_position) <= combat.get_enemy_radius(enemy_id):
				reached = true
				break
		if not reached:
			continue
		combat.damage_enemy_by_id(
			enemy_id,
			damage * climber_damage_share,
			PhaseBCombatDirector.DeathSource.RELIC
		)
		_try_consume_girdling(enemy_id, damage)


func _advance_thistle_relics(delta: float) -> void:
	_relay_cooldown = maxf(0.0, _relay_cooldown - delta)
	_forking_cooldown = maxf(0.0, _forking_cooldown - delta)
	_answering_cooldown = maxf(0.0, _answering_cooldown - delta)
	for index in range(_rosette_queue.size() - 1, -1, -1):
		var owed: Array = _rosette_queue[index]
		owed[1] = float(owed[1]) - delta
		if float(owed[1]) > 0.0:
			continue
		_rosette_queue.remove_at(index)
		var thistle := _find_thistle_by_sequence(int(owed[0]))
		if thistle == null or not thistle.active:
			continue
		# If the new turret still has nobody in range the event is consumed rather
		# than stored, so an opening volley cannot be banked for a later fight.
		_fire_thistle(thistle, rosette_damage_share, 0, false)
	for enemy_id in _pincushion_stacks.keys():
		var stack: Array = _pincushion_stacks[enemy_id]
		stack[1] = float(stack[1]) - delta
		if float(stack[1]) <= 0.0 or not combat.is_enemy_active(enemy_id):
			_pincushion_stacks.erase(enemy_id)


func _find_thistle_by_sequence(sequence: int) -> ThistleState:
	for thistle in _thistles:
		if thistle.sequence == sequence:
			return thistle
	return null


func _count_active_forked_thorns() -> int:
	var count := 0
	for thorn in _thorns:
		if thorn.active and thorn.source_tag == ThornSource.FORKING:
			count += 1
	return count


func _find_other_thistle(exclude_sequence: int, near: Vector2) -> ThistleState:
	# The nearest turret that is not the one responsible for the event. Callers go
	# through _find_network_responder, which falls back to the source turret when
	# the network really is one Thistle.
	var best: ThistleState = null
	var best_distance := INF
	for thistle in _thistles:
		if not thistle.active or thistle.sequence == exclude_sequence:
			continue
		var distance := thistle.position.distance_squared_to(near)
		if distance < best_distance:
			best_distance = distance
			best = thistle
	return best


## With the network capped at one turret, "another Thistle" usually has nobody to
## call on, and three relics in this pool would read as dead text. The sole Thistle
## answers itself instead, at a reduced share: a real network — Burdock's temporary
## heads, a Deadheading pair — still answers harder, it is just no longer required.
func _find_network_responder(exclude_sequence: int, near: Vector2) -> ThistleState:
	var other := _find_other_thistle(exclude_sequence, near)
	if other != null:
		return other
	var alone := _find_thistle_by_sequence(exclude_sequence)
	if alone != null and alone.active:
		return alone
	return null


func _note_natural_thorn_impact(
	thorn: ThornState,
	enemy_id: int,
	hit_position: Vector2,
	critical: bool
) -> void:
	## Every network counter advances from here, and only from here, so a bonus
	## thorn can never advance the counter that produced it.
	if thorn.source_tag != ThornSource.NATURAL:
		return
	if _has_relic(PhaseBRelicCatalog.Id.THORN_RELAY):
		_relay_impacts += 1
		if _relay_impacts >= thorn_relay_impacts:
			_relay_impacts = 0
			_fire_thorn_relay(thorn, hit_position)
	if _has_relic(PhaseBRelicCatalog.Id.FORKING_PATTERN):
		_forking_impacts += 1
		if _forking_impacts >= forking_pattern_impacts:
			_forking_impacts = 0
			_fork_thorn(thorn, enemy_id, hit_position, critical)


func _fire_thorn_relay(thorn: ThornState, hit_position: Vector2) -> void:
	if _relay_cooldown > 0.0 or thorn_relay_per_second <= 0.0:
		return
	var responder := _find_network_responder(thorn.source_thistle_sequence, hit_position)
	if responder == null:
		return
	var relay_share := thorn_relay_damage_share
	if responder.sequence == thorn.source_thistle_sequence:
		relay_share *= SOLO_NETWORK_SHARE
	_relay_cooldown = 1.0 / thorn_relay_per_second
	# A very fast network ping between the impact and the turret that answers it.
	overlay.spawn_relic_cue(
		TerritoryPrototypeOverlay.RelicCue.STREAK,
		hit_position,
		hit_position.distance_to(responder.position),
		Color("d7e86a"),
		hit_position.direction_to(responder.position)
	)
	# One bonus thorn, not a volley: Clustering is explicitly not inherited.
	var targets := _collect_enemy_targets(responder.position, thistle_range_pixels)
	if targets.is_empty():
		return
	_spawn_thorn(
		responder.position,
		targets[0],
		relay_share,
		0,
		false,
		false,
		0.0,
		0.0,
		1,
		true,
		0,
		responder.sequence,
		false,
		0.0,
		ThornSource.RELAY
	)


func _fork_thorn(
	thorn: ThornState,
	enemy_id: int,
	hit_position: Vector2,
	critical: bool
) -> void:
	if _forking_cooldown > 0.0:
		return
	var room := forking_pattern_active_maximum - _count_active_forked_thorns()
	if room <= 0:
		return
	_forking_cooldown = forking_pattern_cooldown_seconds
	var wanted := (
		forking_pattern_critical_branches if critical else forking_pattern_branches
	)
	var excluded := PackedInt32Array([enemy_id])
	# Only as many branches as there is room for. Missing ones are not queued: a
	# split that could not happen simply did not happen.
	for _branch in range(mini(wanted, room)):
		var target := _find_ricochet_target(hit_position, excluded)
		if target < 0:
			return
		excluded.append(target)
		_spawn_thorn(
			hit_position,
			target,
			forking_pattern_damage_share,
			0,
			false,
			false,
			0.0,
			0.0,
			1,
			true,
			0,
			thorn.source_thistle_sequence,
			false,
			0.0,
			ThornSource.FORKING
		)


func _add_pincushion_stack(enemy_id: int, thorn: ThornState) -> void:
	if not _has_relic(PhaseBRelicCatalog.Id.PINCUSHION):
		return
	# Only the thorns the relic names may embed. A Pincushion burst embedding more
	# stacks would let one corpse pay out forever.
	match thorn.source_tag:
		ThornSource.NATURAL, ThornSource.ROSETTE, ThornSource.SEEDHEAD, \
		ThornSource.ANSWERING, ThornSource.CROWN:
			pass
		_:
			return
	var stack: Array = _pincushion_stacks.get(
		enemy_id, [0, pincushion_stack_seconds]
	)
	stack[0] = mini(int(stack[0]) + 1, pincushion_threshold)
	stack[1] = pincushion_stack_seconds
	_pincushion_stacks[enemy_id] = stack


func _burst_pincushion(enemy_id: int, hit_position: Vector2) -> void:
	if not _pincushion_stacks.has(enemy_id):
		return
	var stack: Array = _pincushion_stacks[enemy_id]
	_pincushion_stacks.erase(enemy_id)
	if int(stack[0]) < pincushion_threshold:
		return
	var excluded := PackedInt32Array([enemy_id])
	for _thorn_index in range(pincushion_thorns):
		var target := _find_ricochet_target(hit_position, excluded)
		if target < 0:
			return
		excluded.append(target)
		_spawn_thorn(
			hit_position,
			target,
			pincushion_damage_share,
			0,
			false,
			false,
			0.0,
			0.0,
			0,
			true,
			0,
			-1,
			false,
			0.0,
			ThornSource.PINCUSHION
		)


func _answer_thorn(thorn: ThornState, hit_position: Vector2) -> void:
	## A natural volley that kills makes a turret answer. Only natural volleys start
	## it, and it prefers a different turret — see _find_network_responder for what
	## happens when the sole Thistle is the only one there is.
	if not _has_relic(PhaseBRelicCatalog.Id.ANSWERING_THORN):
		return
	if thorn.source_tag != ThornSource.NATURAL or _answering_cooldown > 0.0:
		return
	var responder := _find_network_responder(thorn.source_thistle_sequence, hit_position)
	if responder == null:
		# No turret left standing at all: the trigger is consumed on a shorter
		# cooldown rather than being held open until one grows back.
		_answering_cooldown = answering_thorn_cooldown_seconds * 0.44
		return
	var answering_share := answering_thorn_damage_share
	if responder.sequence == thorn.source_thistle_sequence:
		answering_share *= SOLO_NETWORK_SHARE
	_answering_cooldown = answering_thorn_cooldown_seconds
	_fire_thistle(responder, answering_share, 0, false)


func _fire_all_thistles(
	damage_scale: float,
	extra_pierce: int = 0,
	counts_as_normal_cycle: bool = false
) -> int:
	var fired := 0
	for thistle in _thistles:
		if thistle.active:
			fired += _fire_thistle(
				thistle,
				damage_scale,
				extra_pierce,
				counts_as_normal_cycle
			)
	return fired


func _fire_rootstock_network_salvo() -> void:
	for thistle in _thistles:
		if not thistle.active:
			continue
		var targets := _collect_enemy_targets(thistle.position, thistle_range_pixels)
		if targets.is_empty():
			continue
		_spawn_thorn(
			thistle.position,
			targets[0],
			1.0,
			2,
			true,
			false,
			0.0,
			0.0,
			-1,
			true,
			0,
			thistle.sequence,
			true
		)
	status_requested.emit("ROOTSTOCK — the network answers with a Heavy salvo.")


func _collect_enemy_targets(origin: Vector2, maximum_distance: float) -> PackedInt32Array:
	var candidates: Array[Dictionary] = []
	# Read the roster once. Asking combat for a position by id is a scan of the
	# enemy pool, so doing it per enemy made this quadratic in the crowd -- and this
	# runs on every Thistle fire and on every mounted head of every Cane sweep, which
	# is why it showed up in two unrelated bars at once. The candidate list, its
	# comparator and its ordering are deliberately left exactly as they were.
	var enemy_ids := combat.get_active_enemy_ids()
	var enemy_positions := combat.get_active_enemy_positions()
	for index in range(enemy_ids.size()):
		var enemy_id := enemy_ids[index]
		var position := enemy_positions[index]
		var distance_squared := origin.distance_squared_to(position)
		if distance_squared > maximum_distance * maximum_distance:
			continue
		if not territory_field.is_growth_path_clear(origin, position):
			continue
		candidates.append({"id": enemy_id, "distance": distance_squared})
	candidates.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return float(first["distance"]) < float(second["distance"])
	)
	var targets := PackedInt32Array()
	for candidate in candidates:
		targets.append(int(candidate["id"]))
	return targets


func _spawn_thorn(
	origin: Vector2,
	target_id: int,
	damage_scale: float,
	extra_pierce: int,
	heavy: bool,
	bloomshot: bool,
	bloomshot_force: float,
	critical_chance_bonus: float = 0.0,
	ricochet_cap_override: int = -1,
	inherit_needlepoint: bool = true,
	extra_ricochets: int = 0,
	source_thistle_sequence: int = -1,
	pierces_normal_only: bool = false,
	launch_angle_offset: float = 0.0,
	source_tag: int = ThornSource.NATURAL
) -> bool:
	var thorn: ThornState
	for candidate in _thorns:
		if not candidate.active:
			thorn = candidate
			break
	if thorn == null or not combat.is_enemy_active(target_id):
		return false
	var target := combat.get_enemy_position(target_id)
	var direction := origin.direction_to(target)
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	direction = direction.rotated(launch_angle_offset)
	thorn.active = true
	thorn.position = origin
	thorn.velocity = direction * thorn_speed_pixels_per_second
	thorn.remaining = thorn_lifetime_seconds
	thorn.damage = (
		thistle_damage
		* maxf(0.0, damage_scale)
		* (1.5 if heavy else 1.0)
	)
	var effective_burr := _upgrade(
		PhaseBProgression.UpgradeId.THISTLE_BURR
	) + _root_count_step(PhaseBProgression.UpgradeId.THISTLE_BURR, origin)
	thorn.ricochets_remaining = (
		effective_burr + maxi(0, extra_ricochets)
		if ricochet_cap_override < 0
		else mini(
			effective_burr,
			ricochet_cap_override
		) + maxi(0, extra_ricochets)
	)
	thorn.pierce_remaining = maxi(0, extra_pierce)
	thorn.pierces_normal_only = pierces_normal_only
	thorn.critical_chance_bonus = maxf(0.0, critical_chance_bonus) + (
		_root_scaled_bonus(
			PhaseBProgression.UpgradeId.THISTLE_NEEDLEPOINT, 0.10, origin
		)
		if inherit_needlepoint
		else 0.0
	)
	thorn.heavy = heavy
	thorn.bloomshot = bloomshot
	thorn.bloomshot_force = maxf(0.0, bloomshot_force)
	thorn.ricochet_depth = 0
	thorn.inherit_needlepoint = inherit_needlepoint
	thorn.source_thistle_sequence = source_thistle_sequence
	thorn.source_tag = source_tag
	thorn.hit_ids.clear()
	return true


func _update_thorns(delta: float) -> void:
	# The roster is read once for the whole pass. Asking combat for a position or a
	# radius by id is a scan of the enemy pool, and doing that per enemy per thorn
	# was costing more than everything else in this component put together.
	var enemy_ids := combat.get_active_enemy_ids()
	var enemy_positions := combat.get_active_enemy_positions()
	var enemy_radii := combat.get_active_enemy_radii()
	for thorn in _thorns:
		if not thorn.active:
			continue
		thorn.remaining -= delta
		if thorn.remaining <= 0.0:
			thorn.active = false
			continue
		var previous := thorn.position
		var next := previous + thorn.velocity * delta
		if not territory_field.contains_local_point(next):
			thorn.active = false
			continue
		if not territory_field.is_growth_path_clear(previous, next):
			thorn.active = false
			continue
		var struck_id := _find_thorn_segment_hit(
			thorn, previous, next, enemy_ids, enemy_positions, enemy_radii
		)
		thorn.position = next
		if struck_id < 0:
			continue
		var resolve_began := Time.get_ticks_usec() if PhaseBPerfCounters.enabled else 0
		_resolve_thorn_hit(thorn, struck_id)
		PhaseBPerfCounters.timer_add_since(
			PhaseBPerfCounters.TIMER_THISTLE_HIT_RESOLUTION, resolve_began
		)


func _find_thorn_segment_hit(
	thorn: ThornState,
	segment_start: Vector2,
	segment_end: Vector2,
	enemy_ids: PackedInt32Array,
	enemy_positions: PackedVector2Array,
	enemy_radii: PackedFloat32Array
) -> int:
	var began_usec := Time.get_ticks_usec() if PhaseBPerfCounters.enabled else 0
	var struck := -1
	var nearest_progress := INF
	var segment := segment_end - segment_start
	var segment_length_squared := maxf(segment.length_squared(), 0.0001)
	for index in range(enemy_ids.size()):
		var enemy_id := enemy_ids[index]
		if thorn.hit_ids.has(enemy_id):
			continue
		var enemy_position := enemy_positions[index]
		var hit_radius := thorn_hit_radius_pixels + enemy_radii[index]
		var progress := clampf(
			(enemy_position - segment_start).dot(segment) / segment_length_squared,
			0.0,
			1.0
		)
		var nearest := segment_start + segment * progress
		if enemy_position.distance_squared_to(nearest) > hit_radius * hit_radius:
			continue
		if progress < nearest_progress:
			nearest_progress = progress
			struck = enemy_id
	# Counted once for the whole scan rather than once per enemy: this is the
	# O(thorns x enemies) loop the shared spatial grid is meant to replace, and it
	# is the last place that should pay for its own instrumentation.
	PhaseBPerfCounters.count(
		PhaseBPerfCounters.COUNT_THORN_CANDIDATE_CHECKS, enemy_ids.size()
	)
	PhaseBPerfCounters.count(PhaseBPerfCounters.COUNT_THORN_SEGMENTS_RESOLVED)
	PhaseBPerfCounters.timer_add_since(
		PhaseBPerfCounters.TIMER_THISTLE_COLLISION, began_usec
	)
	return struck


func _resolve_thorn_hit(thorn: ThornState, enemy_id: int) -> void:
	var lookup_began := Time.get_ticks_usec() if PhaseBPerfCounters.enabled else 0
	if not combat.is_enemy_active(enemy_id):
		return
	var hit_position := combat.get_enemy_position(enemy_id)
	var hit_was_resistant := combat.is_enemy_resistant(enemy_id)
	var hedge_rank := _evolution_rank(PhaseBProgression.EvolutionId.HEDGE_BATTERY)
	var was_fully_entangled := combat.get_enemy_entanglement(enemy_id) >= 1.0
	PhaseBPerfCounters.timer_add_since(
		PhaseBPerfCounters.TIMER_THISTLE_HIT_LOOKUP, lookup_began
	)
	var critical_chance := clampf(
		thistle_base_critical_chance
		+ thorn.critical_chance_bonus,
		0.0,
		1.0
	)
	var critical := _random.randf() < critical_chance
	var damage := thorn.damage * (thistle_critical_multiplier if critical else 1.0)
	if hedge_rank >= 2 and was_fully_entangled:
		damage *= 1.20
	var cascade_began := Time.get_ticks_usec() if PhaseBPerfCounters.enabled else 0
	_apply_inoculator_hit(thorn, enemy_id, critical, hit_position)
	_apply_hedge_battery_hit(enemy_id, critical, was_fully_entangled, hit_position)
	_add_pincushion_stack(enemy_id, thorn)
	PhaseBPerfCounters.timer_add_since(
		PhaseBPerfCounters.TIMER_THISTLE_HIT_CASCADE, cascade_began
	)
	var damage_began := Time.get_ticks_usec() if PhaseBPerfCounters.enabled else 0
	combat.damage_enemy_by_id(
		enemy_id, damage, PhaseBCombatDirector.DeathSource.THISTLE, critical
	)
	PhaseBPerfCounters.timer_add_since(
		PhaseBPerfCounters.TIMER_THISTLE_HIT_DAMAGE, damage_began
	)
	cascade_began = Time.get_ticks_usec() if PhaseBPerfCounters.enabled else 0
	thorn.hit_ids.append(enemy_id)
	_note_natural_thorn_impact(thorn, enemy_id, hit_position, critical)
	PhaseBPerfCounters.timer_add_since(
		PhaseBPerfCounters.TIMER_THISTLE_HIT_CASCADE, cascade_began
	)
	if not combat.is_enemy_active(enemy_id):
		# Read on the kill, while the corpse still has its embedded thorns.
		_burst_pincushion(enemy_id, hit_position)
		_answer_thorn(thorn, hit_position)
	if thorn.heavy:
		combat.knockback_enemy_from(enemy_id, thorn.position - thorn.velocity.normalized() * 8.0, 34.0)
	if thorn.bloomshot:
		_detonate_bloomshot(hit_position, thorn.bloomshot_force, critical)
		thorn.bloomshot = false
	if (
		was_fully_entangled
		and hedge_rank >= 5
		and _hedge_battery_cooldown <= 0.0
	):
		_hedge_battery_cooldown = 1.0
		_fire_nearest_other_thistle(enemy_id, thorn.source_thistle_sequence)
	if (
		thorn.pierce_remaining > 0
		and (not thorn.pierces_normal_only or not hit_was_resistant)
	):
		thorn.pierce_remaining -= 1
		thorn.position += thorn.velocity.normalized() * (thorn_hit_radius_pixels + 2.0)
		return
	if thorn.ricochets_remaining > 0:
		var next_target := _find_ricochet_target(hit_position, thorn.hit_ids)
		if next_target >= 0:
			thorn.ricochets_remaining -= 1
			thorn.ricochet_depth += 1
			thorn.position = hit_position
			thorn.velocity = (
				hit_position.direction_to(combat.get_enemy_position(next_target))
				* thorn_speed_pixels_per_second
			)
			thorn.remaining = maxf(thorn.remaining, 0.45)
			return
	thorn.active = false


func _find_ricochet_target(origin: Vector2, excluded: PackedInt32Array) -> int:
	var began_usec := Time.get_ticks_usec() if PhaseBPerfCounters.enabled else 0
	var nearest_id := -1
	var nearest_distance := thistle_range_pixels * thistle_range_pixels
	var enemy_ids := combat.get_active_enemy_ids()
	var enemy_positions := combat.get_active_enemy_positions()
	for index in range(enemy_ids.size()):
		var enemy_id := enemy_ids[index]
		if excluded.has(enemy_id):
			continue
		var position := enemy_positions[index]
		var distance := origin.distance_squared_to(position)
		if distance > nearest_distance:
			continue
		if not territory_field.is_growth_path_clear(origin, position):
			continue
		nearest_distance = distance
		nearest_id = enemy_id
	PhaseBPerfCounters.timer_add_since(
		PhaseBPerfCounters.TIMER_THISTLE_RICOCHET, began_usec
	)
	return nearest_id


func _apply_inoculator_hit(
	thorn: ThornState,
	enemy_id: int,
	critical: bool,
	hit_position: Vector2
) -> void:
	var rank := _evolution_rank(PhaseBProgression.EvolutionId.INOCULATOR)
	if rank <= 0 or not combat.is_enemy_active(enemy_id):
		return
	var spore := 0.06 if rank >= 4 else 0.04
	if rank >= 2 and thorn.ricochet_depth > 0:
		spore = 0.06
	if rank >= 3 and critical:
		spore += 0.08
	var result := combat.add_spore_to_enemy(enemy_id, spore)
	if rank < 5 or result < 1.0 or _inoculator_pulsed.has(enemy_id):
		return
	_inoculator_pulsed[enemy_id] = true
	combat.apply_spore_in_radius(hit_position, 60.0, 0.60)


func _apply_hedge_battery_hit(
	enemy_id: int,
	critical: bool,
	_was_fully_entangled: bool,
	hit_position: Vector2
) -> void:
	var rank := _evolution_rank(PhaseBProgression.EvolutionId.HEDGE_BATTERY)
	if rank <= 0 or not combat.is_enemy_active(enemy_id):
		return
	var on_green := territory_field.is_owned_at_local(hit_position)
	var gain := 0.05
	if rank >= 4:
		gain = 0.08
	if on_green:
		gain *= 2.0
	if rank >= 3 and critical:
		gain += 0.08
	combat.add_entanglement_to_enemy(enemy_id, gain)


func _detonate_bloomshot(position: Vector2, force_share: float, critical: bool) -> void:
	if bloom_director == null or force_share <= 0.0:
		return
	var rank := _evolution_rank(PhaseBProgression.EvolutionId.BURSTBLOOM)
	var amplification := (
		root_director.get_network_multiplier_here(position)
		if root_director != null
		else 1.0
	)
	var pixels_per_cell := (
		territory_field.tuning.arena_size.x
		/ float(territory_field.tuning.field_size.x)
	)
	var radius_scale := sqrt(force_share)
	if rank >= 3 and critical:
		radius_scale *= 1.40
	var radius := territory_field.tuning.bloom_radius_cells * pixels_per_cell * radius_scale
	var damage := (
		bloom_director.bloom_damage
		* bloom_director.get_bloom_force_multiplier()
		* force_share
		* amplification
	)
	combat.damage_enemies_in_radius(
		position,
		radius,
		damage,
		PhaseBCombatDirector.DeathSource.BLOOM
	)
	territory_field.queue_bloom(
		position,
		force_share * amplification,
		force_share * amplification,
		force_share * amplification,
		radius_scale
	)
	overlay.spawn_bloom(position)
	combat.play_plant_explosion_sfx()


func _fire_nearest_other_thistle(enemy_id: int, source_sequence: int) -> void:
	if not combat.is_enemy_active(enemy_id):
		return
	var target_position := combat.get_enemy_position(enemy_id)
	var nearest: ThistleState
	var nearest_distance := INF
	var nearest_is_source := false
	for thistle in _thistles:
		if not thistle.active:
			continue
		var distance := thistle.position.distance_squared_to(target_position)
		if distance > thistle_range_pixels * thistle_range_pixels:
			continue
		if not territory_field.is_growth_path_clear(thistle.position, target_position):
			continue
		var is_source := thistle.sequence == source_sequence
		# A second turret always wins the tie: the source only answers when it is
		# the whole network, and then at the reduced solo share.
		if nearest != null and not nearest_is_source and is_source:
			continue
		if nearest != null and nearest_is_source == is_source and distance >= nearest_distance:
			continue
		nearest_distance = distance
		nearest_is_source = is_source
		nearest = thistle
	if nearest != null:
		_fire_thistle(
			nearest,
			SOLO_NETWORK_SHARE if nearest_is_source else 1.0,
			0,
			false,
			enemy_id
		)


func _on_cane_sweep_started(
	origin: Vector2,
	facing: Vector2,
	left_to_right: bool,
	reach: float,
	_damage: float,
	is_bonus: bool
) -> void:
	if is_bonus:
		return
	_cane_sweep_hits.clear()
	_briar_cane_full_hit = false
	_current_sweep_apical_hit = false
	_natural_sweep_index += 1
	# Read from the rope itself: Climber requires the Vine to have genuinely bent
	# around something, not merely to have been routed past it.
	_sweep_bend_index = -1
	_sweep_hit_past_bend = false
	_runner_spawned_this_sweep = false
	var sweep_whip: PhaseBVineWhip = combat.vine_whip
	if sweep_whip != null and sweep_whip.is_built():
		# A wrap, not a bend: a rope whipping through open ground curves sharply on
		# its own, and that must never read as having gone around something.
		_sweep_bend_index = sweep_whip.get_wrap_index()
	_current_sweep_facing = facing
	_current_sweep_left_to_right = left_to_right
	_current_sweep_reach = reach
	_current_sweep_wisteria = (
		_wisteria_armed
		and _evolution_rank(PhaseBProgression.EvolutionId.WISTERIA) > 0
	)
	if _current_sweep_wisteria:
		_wisteria_armed = false
	_fire_thornwhip(origin, facing, left_to_right, reach)
	if _gourdvine_pending_count > 0:
		_gourdvine_attached = true
	# Twining counts automatic sweeps only. Its repeated stroke is marked bonus and
	# cannot advance this counter or retrigger any Evolution secondary.
	if _has_relic(PhaseBRelicCatalog.Id.TWINING):
		_twining_progress += 1
		if twining_sweep_interval > 0 and _twining_progress >= twining_sweep_interval:
			_twining_progress = 0
			_queue_pending_event(
				PendingKind.CANE_SWEEP,
				twining_delay_seconds,
				origin,
				facing,
				left_to_right,
				twining_damage_share
			)


func _on_cane_enemy_hit(
	enemy_id: int,
	local_position: Vector2,
	_distance_fraction: float,
	apical: bool,
	damage: float,
	killed: bool,
	is_bonus: bool
) -> void:
	if not _cane_sweep_hits.has(enemy_id):
		_cane_sweep_hits.append(enemy_id)
	if apical and not is_bonus:
		_current_sweep_apical_hit = true
		if _has_relic(PhaseBRelicCatalog.Id.RECURVE) and not _recurve_armed:
			_recurve_armed = true
			combat.multiply_next_cane_cooldown(0.80)
		_note_vine_apical_hit(enemy_id, damage)
	# Any Vine contact spends a Girdle, including a relic-generated stroke.
	_try_consume_girdling(enemy_id, damage)
	if _sweep_bend_index >= 0 and _distance_fraction > 0.0:
		# The hit landed on the far side of the wrap, which is what Climber answers.
		_sweep_hit_past_bend = true
	if (
		killed
		and not is_bonus
		and _has_relic(PhaseBRelicCatalog.Id.RUNNER)
		and _runners.size() < runner_active_maximum
		and not _runner_spawned_this_sweep
	):
		_runner_spawned_this_sweep = true
		_runners.append([local_position, runner_delay_seconds, damage * runner_damage_share])
	_apply_mycelial_vine_hit(enemy_id, local_position, apical, damage)
	if (
		killed
		and not is_bonus
		and _evolution_rank(PhaseBProgression.EvolutionId.MYCELIAL_VINE) >= 3
		and spore_director != null
	):
		# Combat's ordinary kill signal already supplies the first credit. Vector
		# Harvest contributes exactly one more, making the Vine kill worth two.
		spore_director.credit_seed_kills(local_position, 1)
	_apply_briar_cane_hit(enemy_id, local_position, apical, damage)
	if _gourdvine_attached and apical:
		_apply_attached_gourdvine_hit(enemy_id, damage)


func _on_cane_sweep_finished(
	origin: Vector2,
	facing: Vector2,
	left_to_right: bool,
	reach: float,
	_hit_count: int,
	is_bonus: bool
) -> void:
	if is_bonus:
		return
	var briar_rank := _evolution_rank(PhaseBProgression.EvolutionId.BRIAR_CANE)
	if briar_rank >= 5 and _briar_cane_full_hit:
		for enemy_id in _cane_sweep_hits:
			if not combat.is_enemy_active(enemy_id):
				continue
			var full := combat.get_enemy_entanglement(enemy_id) >= 1.0
			var distance := bramble_director.get_repulsion_pixels() if bramble_director != null else 26.0
			distance *= 1.0 if full else 0.50
			if territory_field.is_owned_at_local(combat.get_enemy_position(enemy_id)):
				distance *= 1.25
			combat.knockback_enemy_from(enemy_id, origin, distance)
	if _current_sweep_wisteria:
		_fire_wisteria_sequence(origin, facing, left_to_right, reach, 1.0)
	var sweep_damage := combat.cane_damage * combat.get_cane_damage_multiplier()
	if _current_sweep_apical_hit:
		_try_whiplash(origin, facing, sweep_damage)
	_try_climber(sweep_damage)
	if _has_relic(PhaseBRelicCatalog.Id.LIANA):
		if not _current_sweep_apical_hit:
			# A sweep that lands no Apical hit breaks the streak outright.
			_liana_progress = 0
		elif _liana_cooldown <= 0.0 and _liana_remaining <= 0:
			_liana_progress += 1
			if _liana_progress >= liana_required_sweeps:
				_liana_progress = 0
				_liana_cooldown = liana_cooldown_seconds
				_liana_remaining = liana_bonus_sweeps
				_liana_step = liana_first_delay
				_liana_facing = facing
				_liana_left_to_right = left_to_right
		if _evolution_rank(PhaseBProgression.EvolutionId.WISTERIA) >= 5:
			_queue_pending_event(
				PendingKind.WISTERIA_SEQUENCE,
				0.75,
				origin,
				facing,
				left_to_right,
				0.50,
				0,
				0,
				reach
			)
	if _gourdvine_attached:
		_detach_gourdvine_fruit(origin, facing, left_to_right, reach)
	# Trellis widens only after a completed sweep. A miss resets all stacks; a hit
	# adds one to the next stroke, to the authored maximum of three.
	if _has_relic(PhaseBRelicCatalog.Id.TRELLIS):
		if _current_sweep_apical_hit:
			_trellis_stacks = mini(3, _trellis_stacks + 1)
		else:
			_trellis_stacks = 0
		combat.set_cane_apical_fraction_bonus(0.05 * float(_trellis_stacks))
	else:
		_trellis_stacks = 0
		combat.set_cane_apical_fraction_bonus(0.0)
	_recurve_armed = false


func _apply_mycelial_vine_hit(
	enemy_id: int,
	local_position: Vector2,
	apical: bool,
	damage: float
) -> void:
	var rank := _evolution_rank(PhaseBProgression.EvolutionId.MYCELIAL_VINE)
	if rank <= 0 or not combat.is_enemy_active(enemy_id):
		return
	var previous_spore := combat.get_enemy_spore(enemy_id)
	var was_overgrown := combat.is_enemy_overgrown(enemy_id)
	if rank >= 4 and previous_spore >= 0.50:
		combat.damage_enemy_by_id(
			enemy_id,
			damage * 0.20,
			PhaseBCombatDirector.DeathSource.CANE
		)
	if not combat.is_enemy_active(enemy_id):
		return
	var spore := 0.15
	if rank >= 2 and apical:
		spore += 0.15
	combat.add_spore_to_enemy(enemy_id, spore)
	if rank >= 5 and apical and was_overgrown:
		combat.collapse_overgrown_enemy(
			enemy_id,
			0.25,
			0.08,
			PhaseBCombatDirector.DeathSource.CANE
		)
		status_requested.emit("MYCELIAL VINE — the Apical tip collapses an infection.")


func _apply_briar_cane_hit(
	enemy_id: int,
	local_position: Vector2,
	apical: bool,
	damage: float
) -> void:
	var rank := _evolution_rank(PhaseBProgression.EvolutionId.BRIAR_CANE)
	if rank <= 0 or not combat.is_enemy_active(enemy_id):
		return
	var fully_entangled := combat.get_enemy_entanglement(enemy_id) >= 1.0
	if rank >= 2 and fully_entangled:
		combat.damage_enemy_by_id(
			enemy_id,
			damage * 0.20,
			PhaseBCombatDirector.DeathSource.CANE
		)
	if not combat.is_enemy_active(enemy_id):
		return
	var on_green := territory_field.is_owned_at_local(local_position)
	var gain := 0.15 if not on_green else 0.25
	if rank >= 4 and apical:
		gain = 0.30 if not on_green else 0.50
	combat.add_entanglement_to_enemy(enemy_id, gain)
	if rank >= 3 and fully_entangled:
		_briar_cane_full_hit = true
		var distance := bramble_director.get_repulsion_pixels() if bramble_director != null else 26.0
		distance *= 1.0 if on_green else 0.50
		combat.knockback_enemy_from(enemy_id, player.get_arena_position(), distance)


func _fire_thornwhip(
	origin: Vector2,
	facing: Vector2,
	left_to_right: bool,
	reach: float,
	second_half: bool = false
) -> void:
	var rank := _evolution_rank(PhaseBProgression.EvolutionId.THORNWHIP)
	if rank <= 0:
		return
	var head_count := 2
	if rank >= 2:
		head_count += 1
	if rank >= 4:
		head_count += 1
	var sector_facing := facing
	var sector_degrees := combat.cane_arc_degrees
	if rank >= 5:
		# Raking Fire is two readable packets, one in each half of the animated
		# sweep. Reverse sweeps visit those halves in reverse order.
		var first_half_sign := -1.0 if left_to_right else 1.0
		var half_sign := -first_half_sign if second_half else first_half_sign
		sector_facing = facing.rotated(
			deg_to_rad(combat.cane_arc_degrees * 0.25 * half_sign)
		)
		sector_degrees = combat.cane_arc_degrees * 0.50
	for head_index in range(head_count):
		var fraction := float(head_index + 1) / float(head_count + 1)
		var head_position := origin + facing * reach * fraction
		var scale := 1.0
		if rank >= 3 and head_index == head_count - 1:
			scale += _root_scaled_bonus(
				PhaseBProgression.UpgradeId.VINE_APICAL_DOMINANCE, 0.25, origin
			)
		_fire_mounted_head(
			head_position,
			origin,
			sector_facing,
			sector_degrees,
			scale
		)
	if rank >= 5 and not second_half:
		var queued := _queue_pending_event(
			PendingKind.THORNWHIP_SECOND_HALF,
			combat.cane_sweep_seconds * 0.50,
			origin,
			facing,
			left_to_right,
			1.0,
			0,
			0,
			reach
		)
		if not queued:
			# Pool pressure may collapse timing, never authored damage.
			_fire_thornwhip(origin, facing, left_to_right, reach, true)


func _fire_mounted_head(
	head_position: Vector2,
	sweep_origin: Vector2,
	sector_facing: Vector2,
	sector_degrees: float,
	damage_scale: float
) -> void:
	var targets := PackedInt32Array()
	var half_angle := deg_to_rad(sector_degrees * 0.5)
	# Same reason as in _collect_enemy_targets: one roster read instead of a pool
	# scan per surviving candidate. Keyed by id rather than walked, because the
	# candidate list comes back sorted by distance and no longer lines up with
	# roster order.
	var head_enemy_ids := combat.get_active_enemy_ids()
	var head_enemy_positions := combat.get_active_enemy_positions()
	var head_positions_by_id := {}
	for roster_index in range(head_enemy_ids.size()):
		head_positions_by_id[head_enemy_ids[roster_index]] = (
			head_enemy_positions[roster_index]
		)
	for enemy_id in _collect_enemy_targets(head_position, thistle_range_pixels):
		if not head_positions_by_id.has(enemy_id):
			continue
		var offset: Vector2 = head_positions_by_id[enemy_id] - sweep_origin
		if (
			offset.length_squared() > 0.001
			and absf(sector_facing.angle_to(offset.normalized())) <= half_angle
		):
			targets.append(enemy_id)
	if targets.is_empty():
		return
	var projectile_count := (
		1
		+ _upgrade(PhaseBProgression.UpgradeId.THISTLE_CLUSTERING)
		+ _root_count_step(
			PhaseBProgression.UpgradeId.THISTLE_CLUSTERING, head_position
		)
	)
	for index in range(projectile_count):
		_spawn_thorn(
			head_position,
			targets[index % targets.size()],
			damage_scale,
			0,
			false,
			false,
			0.0,
			0.0,
			-1
		)


func _on_bloom_detonated(
	local_position: Vector2,
	chain_depth: int,
	_source_tag: int = 0,
	_strength: float = 1.0
) -> void:
	# Only a normal Bloom arms these pairings. Chained and secondary Blooms keep
	# their own behavior and cannot recursively charge the same trigger.
	if chain_depth != 0:
		return
	if _evolution_rank(PhaseBProgression.EvolutionId.WISTERIA) > 0:
		_wisteria_armed = true
	var burst_rank := _evolution_rank(PhaseBProgression.EvolutionId.BURSTBLOOM)
	if burst_rank <= 0:
		return
	var pixels_per_cell := (
		territory_field.tuning.arena_size.x
		/ float(territory_field.tuning.field_size.x)
	)
	var radius := territory_field.tuning.bloom_radius_cells * pixels_per_cell
	var duration := 6.0 if burst_rank >= 2 else 4.0
	var charged: Array[ThistleState] = []
	for thistle in _thistles:
		if not thistle.active:
			continue
		if thistle.position.distance_to(local_position) > radius:
			continue
		if not territory_field.is_owned_at_local(thistle.position):
			continue
		thistle.bloom_charge_remaining = maxf(thistle.bloom_charge_remaining, duration)
		charged.append(thistle)
	if burst_rank >= 5:
		for thistle in charged:
			_fire_thistle(thistle, 1.0, 0, false)


func _fire_wisteria_sequence(
	origin: Vector2,
	facing: Vector2,
	left_to_right: bool,
	reach: float,
	sequence_scale: float
) -> void:
	var rank := _evolution_rank(PhaseBProgression.EvolutionId.WISTERIA)
	if rank <= 0 or bloom_director == null:
		return
	var blossom_count := 4 if rank >= 2 else 3
	var half_angle := deg_to_rad(combat.cane_arc_degrees * 0.5)
	for index in range(blossom_count):
		var progress := float(index + 1) / float(blossom_count)
		var directional_progress := progress if left_to_right else 1.0 - progress
		var angle := lerpf(-half_angle, half_angle, directional_progress)
		var distance := reach * lerpf(0.42, 0.92, progress)
		var position := origin + facing.rotated(angle) * distance
		if not territory_field.contains_local_point(position):
			continue
		var tip := index == blossom_count - 1
		var force := 0.35 * sequence_scale
		if rank >= 3 and tip:
			force = 0.70 * sequence_scale
		var radius_scale := sqrt(maxf(force, 0.05)) * (1.35 if rank >= 3 and tip else 1.0)
		if not _queue_pending_event(
			PendingKind.WISTERIA_BLOSSOM,
			0.10 * float(index),
			position,
			Vector2.RIGHT,
			true,
			force,
			0,
			0,
			radius_scale
		):
			_detonate_wisteria_blossom(position, force, radius_scale)


func _detonate_wisteria_blossom(
	position: Vector2,
	force: float,
	radius_scale: float
) -> void:
	if bloom_director == null or force <= 0.0:
		return
	var pixels_per_cell := (
		territory_field.tuning.arena_size.x
		/ float(territory_field.tuning.field_size.x)
	)
	var base_radius := territory_field.tuning.bloom_radius_cells * pixels_per_cell
	var amplification := (
		root_director.get_network_multiplier_here(position)
		if root_director != null
		else 1.0
	)
	territory_field.queue_bloom(
		position,
		force * amplification,
		force * amplification,
		force * amplification,
		radius_scale
	)
	combat.damage_enemies_in_radius(
		position,
		base_radius * radius_scale,
		bloom_director.bloom_damage
			* bloom_director.get_bloom_force_multiplier()
			* force
			* amplification,
		PhaseBCombatDirector.DeathSource.BLOOM
	)
	if _evolution_rank(PhaseBProgression.EvolutionId.WISTERIA) >= 4:
		var aftergrowth := bloom_director.get_aftergrowth_shield() * 0.50
		if aftergrowth > 0.0:
			territory_field.queue_aftergrowth(
				position,
				territory_field.tuning.bloom_radius_cells * radius_scale,
				aftergrowth,
				bloom_director.bloom_tempo_window_seconds
			)
		var suppression := bloom_director.get_suppression_share() * 0.50
		if suppression > 0.0:
			combat.apply_suppression_in_radius(
				position,
				base_radius * radius_scale,
				suppression,
				bloom_director.bloom_tempo_window_seconds
			)
	overlay.spawn_bloom(position)
	combat.play_plant_explosion_sfx()


func _queue_pending_event(
	kind: int,
	delay: float,
	origin: Vector2,
	facing: Vector2,
	left_to_right: bool,
	damage_scale: float,
	count: int = 0,
	extra_pierce: int = 0,
	reach: float = 0.0
) -> bool:
	for pending in _pending_events:
		if pending.active:
			continue
		pending.active = true
		pending.kind = kind
		pending.remaining = maxf(0.0, delay)
		pending.origin = origin
		pending.facing = facing
		pending.left_to_right = left_to_right
		pending.damage_scale = maxf(0.0, damage_scale)
		pending.count = count
		pending.extra_pierce = extra_pierce
		pending.reach = reach
		return true
	return false


func _update_pending_events(delta: float) -> void:
	for pending in _pending_events:
		if not pending.active:
			continue
		pending.remaining -= delta
		if pending.remaining > 0.0:
			continue
		pending.active = false
		match pending.kind:
			PendingKind.THISTLE_VOLLEY:
				_fire_all_thistles(
					pending.damage_scale,
					pending.extra_pierce,
					false
				)
			PendingKind.CANE_SWEEP:
				combat.perform_bonus_cane_sweep(
					pending.facing,
					pending.left_to_right,
					pending.damage_scale,
					1.0
				)
			PendingKind.THORNWHIP_SECOND_HALF:
				_fire_thornwhip(
					pending.origin,
					pending.facing,
					pending.left_to_right,
					pending.reach,
					true
				)
			PendingKind.WISTERIA_SEQUENCE:
				_fire_wisteria_sequence(
					pending.origin,
					pending.facing,
					pending.left_to_right,
					pending.reach,
					pending.damage_scale
				)
			PendingKind.WISTERIA_BLOSSOM:
				_detonate_wisteria_blossom(
					pending.origin,
					pending.damage_scale,
					pending.reach
				)
			PendingKind.ESPALIER_CUTTINGS:
				if pruning_director != null:
					pruning_director.fire_espalier_fan(
						pending.count,
						pending.facing,
						pending.damage_scale
					)


func _update_fruits(delta: float) -> void:
	if not progression.has_path_active(PhaseBProgression.PathId.FRUIT):
		for fruit in _fruits:
			if fruit.active:
				_advance_fruit(fruit, delta)
		_gourdvine_pending_count = 0
		_gourdvine_attached = false
		return
	for fruit in _fruits:
		if fruit.active:
			_advance_fruit(fruit, delta)


func _update_fruit_release_cadence(delta: float) -> void:
	if not progression.has_path_active(PhaseBProgression.PathId.FRUIT):
		# A temporary Fruit loan can expire while its last roll is still resolving.
		# The clock is left where it stands rather than cleared, so reactivating the
		# path cannot hand back a release the loan already paid for.
		_fruit_release_remaining = minf(_fruit_release_remaining, fruit_release_interval)
		return
	if _gourdvine_pending_count > 0 or _gourdvine_attached:
		# Weighted Harvest is the one release that is a stored object rather than a
		# batch already in the air: it sits on the Vine tip until a sweep spends it,
		# and arming a second would overwrite the first. So this case, and only this
		# case, still waits for the previous release to clear.
		return
	_fruit_release_remaining -= delta
	if _fruit_release_remaining <= 0.0:
		_begin_normal_fruit_release()


func _has_live_normal_fruit_release() -> bool:
	## Whether a normal release is still resolving somewhere on the field. The
	## cadence no longer waits on this -- releases overlap freely now -- but Orchard
	## and the probes still ask, and Dropped Seed is deliberately excluded.
	if _gourdvine_pending_count > 0 or _gourdvine_attached:
		return true
	for fruit in _fruits:
		if fruit.active and not fruit.dropped_seed:
			return true
	for fruitseed in _fruitseeds:
		if fruitseed.active and not fruitseed.dropped_seed:
			return true
	return false


func _begin_normal_fruit_release() -> void:
	# The clock restarts here, at the launch, not when the batch finishes bursting.
	_fruit_release_remaining = fruit_release_interval
	var release_origin := player.get_arena_position()
	var fruit_count := (
		1
		+ _upgrade(PhaseBProgression.UpgradeId.FRUIT_SET)
		+ _root_count_step(PhaseBProgression.UpgradeId.FRUIT_SET, release_origin)
	)
	_fruit_release_count += 1
	var gourdvine_rank := _evolution_rank(PhaseBProgression.EvolutionId.GOURDVINE)
	if gourdvine_rank > 0:
		# The cadence has paid for these Fruit, but Weighted Harvest holds them for
		# the next automatic sweep rather than creating another release.
		_gourdvine_pending_count = fruit_count
		_gourdvine_directions.clear()
		for index in range(fruit_count):
			_gourdvine_directions.append(_fruit_fan_offset(index, fruit_count, 0.42))
		status_requested.emit("GOURDVINE — a weighted harvest is armed on the Vine tip.")
		return
	var origins := _get_normal_fruit_origins(fruit_count)
	# Every Fruit in a release launches from one of a handful of origins, and the
	# aim query is not cheap: it walks the whole enemy roster with a path test per
	# enemy, then sweeps every candidate sector against every target. Asking it once
	# per Fruit asked the identical question up to sixteen times about the same
	# point, on the one frame that could least afford it. The answer depends only on
	# the origin and on state the loop does not change, so one per origin is the
	# same answer.
	var origin_aims := PackedVector2Array()
	for origin_index in range(origins.size()):
		origin_aims.append(_get_fruit_aim_direction(origins[origin_index]))
	for index in range(fruit_count):
		var origin_index := index % origins.size()
		var origin := origins[origin_index]
		var aim_direction := origin_aims[origin_index]
		var grafted := _graft_cuttings >= 4 and (_graft_all_fruit or index == 0)
		var prize := _graft_prize and index == 0
		_spawn_fruit(
			origin,
			aim_direction.rotated(_fruit_fan_offset(index, fruit_count, 0.72)),
			1.0,
			1.0,
			1.0,
			1.0,
			false,
			false,
			true,
			_graft_cuttings if grafted else 0,
			prize
		)
	_spawn_orchard_bonus_fruit()
	# Graft stock is one release, not a persistent buff. Consume it even if the Fruit
	# pool was full so an overloaded scene cannot preserve a prize indefinitely.
	_graft_cuttings = 0
	_graft_all_fruit = false
	_graft_prize = false


func _get_normal_fruit_origins(fruit_count: int) -> PackedVector2Array:
	var origins := PackedVector2Array([player.get_arena_position()])
	if _evolution_rank(PhaseBProgression.EvolutionId.ORCHARD) < 3:
		return origins
	for sapling in _saplings:
		if (
			sapling.active
			and sapling.dormant_remaining < 0.0
			and territory_field.is_owned_at_local(sapling.position)
		):
			origins.append(sapling.position)
	if origins.size() > fruit_count:
		origins.resize(fruit_count)
	return origins


func _spawn_orchard_bonus_fruit() -> void:
	if (
		_evolution_rank(PhaseBProgression.EvolutionId.ORCHARD) < 5
		or _fruit_release_count % 2 != 0
	):
		return
	var bonus_index := 0
	for sapling in _saplings:
		if bonus_index >= 3:
			break
		if (
			not sapling.active
			or sapling.dormant_remaining >= 0.0
			or not territory_field.is_owned_at_local(sapling.position)
		):
			continue
		_spawn_fruit(
			sapling.position,
			_get_fruit_aim_direction(sapling.position),
			1.0,
			1.0,
			1.0,
			1.0,
			false,
			false,
			false
		)
		bonus_index += 1


func _get_fruit_aim_direction(origin: Vector2, distance_scale: float = 1.0) -> Vector2:
	var fallback := player.get_facing_direction()
	if fallback.length_squared() <= 0.0001:
		fallback = Vector2.RIGHT
	var momentum_multiplier := 1.0 + _root_scaled_bonus(
		PhaseBProgression.UpgradeId.FRUIT_MOMENTUM, 0.20, origin
	)
	return combat.get_densest_target_direction(
		origin,
		fruit_roll_distance_pixels * momentum_multiplier * maxf(0.05, distance_scale),
		fruit_targeting_sector_degrees,
		fallback
	)


func _fruit_fan_offset(index: int, count: int, total_spread: float) -> float:
	if count <= 1:
		return 0.0
	return lerpf(-total_spread * 0.5, total_spread * 0.5, float(index) / float(count - 1))


func _spawn_fruit(
	origin: Vector2,
	direction: Vector2,
	distance_scale: float = 1.0,
	damage_scale: float = 1.0,
	area_scale: float = 1.0,
	speed_scale: float = 1.0,
	dropped_seed: bool = false,
	fragment: bool = false,
	can_raise_sapling: bool = true,
	graft_cuttings: int = 0,
	prize: bool = false,
	trail_area_override: float = -1.0,
	terminal_area_override: float = -1.0
) -> FruitState:
	var fruit: FruitState
	for candidate in _fruits:
		if not candidate.active:
			fruit = candidate
			break
	if fruit == null:
		return null
	var roll_direction := direction.normalized()
	if roll_direction.length_squared() <= 0.0001:
		roll_direction = Vector2.RIGHT
	# Every Fruit line takes Root Potency on its own bonus at the launch origin, so
	# Mature ground makes the Fruit hit harder, roll further, and paint more Green
	# instead of only raising the damage figure. One Network sample serves all three:
	# a multi-Fruit release spawns up to sixteen of these on one frame.
	var fruit_network := _root_network_at(origin)
	var ripening_multiplier := 1.0 + _root_scaled_bonus_with(
		PhaseBProgression.UpgradeId.FRUIT_RIPENING, 0.25, fruit_network
	)
	var momentum_multiplier := 1.0 + _root_scaled_bonus_with(
		PhaseBProgression.UpgradeId.FRUIT_MOMENTUM, 0.20, fruit_network
	)
	var germination_multiplier := 1.0 + _root_scaled_bonus_with(
		PhaseBProgression.UpgradeId.FRUIT_GERMINATION, 0.20, fruit_network
	)
	var graft_damage := 1.0 + 0.03 * float(clampi(graft_cuttings, 0, 12))
	var graft_area := 1.0
	if _evolution_rank(PhaseBProgression.EvolutionId.GRAFT) >= 2:
		graft_area += 0.02 * float(clampi(graft_cuttings, 0, 12))
	var prize_damage := 1.50 if prize else 1.0
	fruit.active = true
	fruit.dropped_seed = dropped_seed
	fruit.fragment = fragment
	fruit.position = origin
	fruit.base_speed = fruit_speed_pixels_per_second * maxf(0.05, speed_scale)
	fruit.speed = fruit.base_speed
	fruit.last_direction = roll_direction
	fruit.velocity = roll_direction * fruit.speed
	fruit.normal_roll_distance = fruit_roll_distance_pixels * momentum_multiplier
	fruit.maximum_distance = (
		fruit.normal_roll_distance * maxf(0.05, distance_scale)
	)
	fruit.remaining_distance = fruit.maximum_distance
	_recompute_fruit_deceleration(fruit)
	fruit.damage = (
		fruit_collision_damage
		* ripening_multiplier
		* maxf(0.0, damage_scale)
		* graft_damage
		* prize_damage
	)
	fruit.terminal_damage = (
		fruit_terminal_explosion_damage
		* ripening_multiplier
		* maxf(0.0, damage_scale)
	)
	fruit.knockback = fruit_knockback_pixels * (1.50 if prize else 1.0)
	var shared_area_multiplier := (
		germination_multiplier
		* maxf(0.05, area_scale)
		* graft_area
	)
	fruit.germination_multiplier = (
		maxf(0.05, trail_area_override)
		if trail_area_override >= 0.0
		else shared_area_multiplier
	)
	fruit.terminal_germination_multiplier = (
		maxf(0.05, terminal_area_override)
		if terminal_area_override >= 0.0
		else shared_area_multiplier * (1.50 if prize else 1.0)
	)
	fruit.visual_scale = (
		(0.68 if fragment else 1.0)
		* (1.50 if prize else 1.0)
		# Ripening shows on the Fruit. It reads the amplified multiplier rather than
		# the raw rank, so a Fruit launched out of Mature ground looks as heavy as
		# it hits.
		* (1.0 + 0.22 * (ripening_multiplier - 1.0))
	)
	fruit.visual_index = _random.randi_range(0, FRUIT_TEXTURES.size() - 1)
	_fruit_sequence += 1
	fruit.rotation = _random.randf_range(-PI, PI)
	fruit.trail_debt = 0.0
	fruit.hit_cooldowns.clear()
	fruit.first_enemy_collision = true
	fruit.thick_rind_available = (
		not dropped_seed and _has_relic(PhaseBRelicCatalog.Id.THICK_RIND)
	)
	fruit.first_obstacle_bounce = true
	fruit.bank_shot_armed = false
	fruit.first_collision_damage_multiplier = 1.0
	fruit.carried_thistle_remaining = 0.12
	fruit.burdock_reset_remaining = 0.0
	fruit.graft_cuttings = graft_cuttings
	fruit.prize = prize
	fruit.can_raise_sapling = can_raise_sapling
	fruit.release_id = _fruit_release_count
	fruit.fruit_id = _fruit_sequence
	fruit.steering_uses = 0
	fruit.windfall_uses = 0
	fruit.windfall_cooldown = 0.0
	fruit.juicy_remaining = 0.0
	fruit.newton_starters = 0
	fruit.newton_cooldown = 0.0
	_stamp_fruit_trail(fruit, origin)
	return fruit


func _recompute_fruit_deceleration(fruit: FruitState) -> void:
	## Constant deceleration makes maximum_distance the unobstructed stopping
	## distance. Collisions and bounces reduce velocity directly, so they make a
	## Fruit stop earlier without inventing a distance-based despawn condition.
	##
	## The floor matters more than it looks. Every Fruit that reaches its burst does
	## so because this subtraction walked its speed down to the stop threshold, and a
	## Fruit that ever reached zero deceleration would never stop at all: the only
	## other things touching its speed are multiplications, which converge on zero
	## without arriving. So the one term the whole lifecycle depends on is not
	## allowed to vanish.
	fruit.deceleration = maxf(
		fruit_minimum_deceleration,
		fruit.base_speed * fruit.base_speed
		/ (2.0 * maxf(1.0, fruit.maximum_distance))
	)
	# Derived rather than authored, so retuning Momentum or the base roll cannot
	# leave a fixed deadline cutting a legitimate roll short.
	fruit.roll_deadline_remaining = maxf(
		fruit_minimum_roll_deadline_seconds,
		fruit.base_speed / fruit.deceleration * fruit_roll_deadline_safety
	)


func _fruit_has_stopped(fruit: FruitState) -> bool:
	return fruit.speed <= fruit_minimum_roll_speed


func _advance_fruit(fruit: FruitState, delta: float) -> void:
	_update_fruit_hit_cooldowns(fruit, delta)
	fruit.windfall_cooldown = maxf(0.0, fruit.windfall_cooldown - delta)
	fruit.newton_cooldown = maxf(0.0, fruit.newton_cooldown - delta)
	fruit.burdock_reset_remaining = maxf(0.0, fruit.burdock_reset_remaining - delta)
	PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_FRUIT_BURDOCK)
	_update_burdock_head(fruit, delta)
	PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_FRUIT_BURDOCK)
	fruit.roll_deadline_remaining -= delta
	if _fruit_has_stopped(fruit) or fruit.roll_deadline_remaining <= 0.0:
		# Either it has come to rest or it has outlived any roll it could have had.
		# Both end the same way: it bursts where it is. Deleting it instead would
		# quietly rob the player of the territory and the terminal damage the Fruit
		# had already been paid for.
		fruit.speed = 0.0
		fruit.velocity = Vector2.ZERO
		PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_FRUIT_FINISH)
		_finish_fruit(fruit)
		PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_FRUIT_FINISH)
		return
	var direction := fruit.velocity.normalized()
	if direction.length_squared() <= 0.0001:
		direction = fruit.last_direction
	var previous_speed := fruit.speed
	# Integrate only until velocity reaches zero. A long frame must not make a
	# stopped Fruit coast beyond its authored physical stopping distance.
	var travel_time := delta
	if fruit.deceleration > 0.0001:
		travel_time = minf(delta, previous_speed / fruit.deceleration)
	fruit.speed = maxf(0.0, previous_speed - fruit.deceleration * travel_time)
	var step_distance := (previous_speed + fruit.speed) * 0.5 * travel_time
	fruit.last_direction = direction
	fruit.velocity = direction * fruit.speed
	var previous := fruit.position
	var next := previous + direction * step_distance
	var terrain_began := Time.get_ticks_usec() if PhaseBPerfCounters.enabled else 0
	var blocked := (
		not territory_field.contains_local_point(next)
		or not territory_field.is_claimable_at_local(next)
		or not territory_field.is_growth_path_clear(previous, next)
	)
	PhaseBPerfCounters.timer_add_since(
		PhaseBPerfCounters.TIMER_FRUIT_TERRAIN, terrain_began
	)
	if blocked:
		terrain_began = Time.get_ticks_usec() if PhaseBPerfCounters.enabled else 0
		_resolve_fruit_obstacle_bounce(fruit, previous, next)
		PhaseBPerfCounters.timer_add_since(
			PhaseBPerfCounters.TIMER_FRUIT_TERRAIN, terrain_began
		)
		if _fruit_has_stopped(fruit):
			fruit.speed = 0.0
			fruit.velocity = Vector2.ZERO
			PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_FRUIT_FINISH)
			_finish_fruit(fruit)
			PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_FRUIT_FINISH)
		var bounce_distance := previous.distance_to(fruit.position)
		fruit.rotation += bounce_distance / maxf(
			4.0,
			fruit_radius_pixels * fruit.visual_scale
		)
		_stamp_fruit_trail_segment(fruit, previous, fruit.position)
		# The bounce resolver has already placed the Fruit just off the obstacle.
		# Do not overwrite that reflected position with the blocked destination.
		return
	fruit.position = next
	fruit.remaining_distance = maxf(0.0, fruit.remaining_distance - step_distance)
	fruit.juicy_remaining = maxf(0.0, fruit.juicy_remaining - step_distance)
	fruit.rotation += step_distance / maxf(4.0, fruit_radius_pixels * fruit.visual_scale)
	_stamp_fruit_trail_segment(fruit, previous, fruit.position)
	var enemy_id := _find_fruit_segment_hit(fruit, previous, next)
	if enemy_id >= 0:
		PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_FRUIT_HIT_RESOLUTION)
		_resolve_fruit_enemy_hit(fruit, enemy_id)
		PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_FRUIT_HIT_RESOLUTION)
	if _fruit_has_stopped(fruit):
		fruit.speed = 0.0
		fruit.velocity = Vector2.ZERO
		PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_FRUIT_FINISH)
		_finish_fruit(fruit)
		PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_FRUIT_FINISH)


func _update_fruit_hit_cooldowns(fruit: FruitState, delta: float) -> void:
	var expired := PackedInt32Array()
	for key in fruit.hit_cooldowns.keys():
		var enemy_id := int(key)
		var remaining := float(fruit.hit_cooldowns[key]) - delta
		if remaining <= 0.0:
			expired.append(enemy_id)
		else:
			fruit.hit_cooldowns[key] = remaining
	for enemy_id in expired:
		fruit.hit_cooldowns.erase(enemy_id)


func _find_fruit_segment_hit(
	fruit: FruitState,
	segment_start: Vector2,
	segment_end: Vector2
) -> int:
	var began_usec := Time.get_ticks_usec() if PhaseBPerfCounters.enabled else 0
	var struck := -1
	var nearest_progress := INF
	var segment := segment_end - segment_start
	var segment_length_squared := maxf(0.0001, segment.length_squared())
	# Every by-id accessor on combat is a scan of the enemy pool, so asking for a
	# position and a radius per enemy made this loop quadratic in the crowd: a
	# 16-Fruit release at the cap was walking the pool a quarter of a million times
	# a frame to find at most sixteen hits. The thorn loop already reads the roster
	# once for the same reason. These are the same three arrays read at the same
	# moment as before, paired by index, so the enemy chosen does not change.
	var enemy_ids := combat.get_active_enemy_ids()
	var enemy_positions := combat.get_active_enemy_positions()
	var enemy_radii := combat.get_active_enemy_radii()
	for index in range(enemy_ids.size()):
		var enemy_id := enemy_ids[index]
		if fruit.hit_cooldowns.has(enemy_id):
			continue
		var enemy_position := enemy_positions[index]
		var hit_radius := fruit_radius_pixels * fruit.visual_scale + enemy_radii[index]
		var progress := clampf(
			(enemy_position - segment_start).dot(segment) / segment_length_squared,
			0.0,
			1.0
		)
		var nearest := segment_start + segment * progress
		if enemy_position.distance_squared_to(nearest) > hit_radius * hit_radius:
			continue
		if progress < nearest_progress:
			nearest_progress = progress
			struck = enemy_id
	PhaseBPerfCounters.timer_add_since(
		PhaseBPerfCounters.TIMER_FRUIT_COLLISION, began_usec
	)
	return struck


func _resolve_fruit_enemy_hit(fruit: FruitState, enemy_id: int) -> void:
	if not combat.is_enemy_active(enemy_id):
		return
	fruit.hit_cooldowns[enemy_id] = 0.35
	var prior_spore := combat.get_enemy_spore(enemy_id)
	var prior_entanglement := combat.get_enemy_entanglement(enemy_id)
	var damage_multiplier := fruit.first_collision_damage_multiplier
	var knockback_multiplier := 1.0
	if fruit.bank_shot_armed:
		damage_multiplier *= 1.40
		knockback_multiplier *= 1.40
		fruit.bank_shot_armed = false
	var durian_rank := _evolution_rank(PhaseBProgression.EvolutionId.DURIAN)
	if not fruit.dropped_seed and durian_rank >= 3 and prior_entanglement >= 1.0:
		damage_multiplier *= 1.25
	combat.knockback_enemy_from(
		enemy_id,
		fruit.position - fruit.velocity.normalized() * fruit_radius_pixels,
		fruit.knockback * knockback_multiplier
	)
	combat.damage_enemy_by_id(
		enemy_id,
		fruit.damage * damage_multiplier,
		PhaseBCombatDirector.DeathSource.FRUIT
	)
	fruit.first_collision_damage_multiplier = 1.0
	var rot_rank := _evolution_rank(PhaseBProgression.EvolutionId.ROT)
	if not fruit.dropped_seed and rot_rank >= 1 and combat.is_enemy_active(enemy_id):
		combat.add_spore_to_enemy(enemy_id, 0.20)
	if not fruit.dropped_seed and durian_rank >= 1 and combat.is_enemy_active(enemy_id):
		combat.add_entanglement_to_enemy(enemy_id, 0.30)
	var overripe_rank := _evolution_rank(PhaseBProgression.EvolutionId.OVERRIPE)
	if (
		not fruit.dropped_seed
		and not fruit.fragment
		and fruit.first_enemy_collision
		and overripe_rank >= 2
	):
		_create_fruit_bloom(fruit.position, 0.25, false, fruit.velocity.normalized())
	if (
		not fruit.dropped_seed
		and _evolution_rank(PhaseBProgression.EvolutionId.BURDOCK) >= 3
		and fruit.burdock_reset_remaining <= 0.0
	):
		fruit.carried_thistle_remaining = 0.0
		fruit.burdock_reset_remaining = 0.50
	fruit.first_enemy_collision = false
	var survived := combat.is_enemy_active(enemy_id)
	if not fruit.dropped_seed and not fruit.fragment:
		# Bruised Fruit is refreshed by any qualifying collision, and the wider trail
		# starts from the very next stamp rather than the next frame.
		if _has_relic(PhaseBRelicCatalog.Id.BRUISED_FRUIT):
			fruit.juicy_remaining = bruised_fruit_distance_pixels
		PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_FRUIT_SALAD)
		_try_fruit_salad(fruit, enemy_id)
		PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_FRUIT_SALAD)
		PhaseBPerfCounters.timer_begin(PhaseBPerfCounters.TIMER_FRUIT_NEWTON)
		_try_newtons_apple(fruit, enemy_id)
		PhaseBPerfCounters.timer_end(PhaseBPerfCounters.TIMER_FRUIT_NEWTON)
		if survived:
			_try_stem_steering(fruit, enemy_id)
		else:
			# Windfall answers a kill; Stem Steering answers a hit. A collision that
			# kills is not also a hit for steering purposes, so the two never both
			# redirect the same Fruit off one body.
			_try_windfall(fruit, enemy_id)
	var momentum_loss := fruit_enemy_momentum_loss * _get_enemy_momentum_weight(enemy_id)
	if not fruit.dropped_seed and rot_rank >= 3 and prior_spore >= 0.50:
		momentum_loss *= 0.50
	if not fruit.dropped_seed and durian_rank >= 2 and prior_entanglement > 0.0:
		momentum_loss *= 0.60
	if (
		not fruit.dropped_seed
		and _evolution_rank(PhaseBProgression.EvolutionId.GRAFT) >= 3
		and fruit.graft_cuttings >= 8
	):
		momentum_loss *= 0.60
	if fruit.thick_rind_available:
		fruit.thick_rind_available = false
	else:
		fruit.speed *= 1.0 - clampf(momentum_loss, 0.0, 0.85)
		fruit.velocity = fruit.last_direction * fruit.speed


func _advance_fruit_relics(delta: float) -> void:
	## Fruit Salad marks age out, and Falling Bodies resolve the one collision each
	## was launched at. Both are global rather than per-Fruit, so both live here.
	_newton_impacts_this_frame = 0
	_newton_second_remaining -= delta
	if _newton_second_remaining <= 0.0:
		_newton_second_remaining = 1.0
		_newton_impacts_this_second = 0
	for enemy_id in _fruit_salad_marks.keys():
		var mark: Array = _fruit_salad_marks[enemy_id]
		mark[2] = float(mark[2]) - delta
		if float(mark[2]) <= 0.0 or not combat.is_enemy_active(enemy_id):
			_fruit_salad_marks.erase(enemy_id)
	for index in range(_falling_bodies.size() - 1, -1, -1):
		var body: Array = _falling_bodies[index]
		body[2] = float(body[2]) - delta
		if float(body[2]) > 0.0:
			continue
		_falling_bodies.remove_at(index)
		_resolve_falling_body(body)


func _resolve_falling_body(body: Array) -> void:
	# The collision was predicted once, when the body was launched. Nothing is
	# searched for while it is in the air, which is what keeps the cost flat.
	var target_id := int(body[1])
	if target_id < 0 or not combat.is_enemy_active(target_id):
		return
	if _newton_impacts_this_second >= newton_impacts_per_second:
		return
	if _newton_impacts_this_frame >= newton_impacts_per_frame:
		return
	_newton_impacts_this_second += 1
	_newton_impacts_this_frame += 1
	var generation := int(body[3])
	var damage := float(body[4])
	var knockback := float(body[5])
	var target_position := combat.get_enemy_position(target_id)
	match combat.get_enemy_role(target_id):
		PhaseBCombatDirector.EnemyRole.BOSS:
			damage *= newton_boss_damage_share
			knockback = 0.0
		PhaseBCombatDirector.EnemyRole.ELITE:
			damage *= newton_elite_damage_share
			knockback *= newton_elite_knockback_share
	# Falling Body damage is relic damage: it may kill and it may activate generic
	# kill relics, but it is never a Fruit collision, so it cannot feed this pool.
	combat.damage_enemy_by_id(
		target_id, damage, PhaseBCombatDirector.DeathSource.RELIC
	)
	if knockback > 0.0:
		combat.knockback_enemy_from(
			target_id, target_position - Vector2(knockback, 0.0), knockback
		)
	if generation >= 2:
		return
	# The struck body may become the final generation, if it is an ordinary enemy
	# and the global budget still has room.
	if not combat.is_enemy_active(target_id):
		return
	if combat.get_enemy_role(target_id) != PhaseBCombatDirector.EnemyRole.HUNTER:
		return
	_launch_falling_body(
		target_id,
		target_position,
		2,
		float(body[4]) * (newton_second_damage_share / maxf(0.01, newton_first_damage_share)),
		float(body[5]) * (newton_second_knockback_share / maxf(0.01, newton_first_knockback_share))
	)


func _launch_falling_body(
	enemy_id: int,
	from_position: Vector2,
	generation: int,
	damage: float,
	knockback: float
) -> bool:
	if _falling_bodies.size() >= newton_active_maximum:
		return false
	var target := _predict_falling_body_target(enemy_id, from_position)
	if target < 0:
		return false
	_falling_bodies.append([
		enemy_id,
		target,
		newton_active_seconds,
		generation,
		damage,
		knockback,
	])
	return true


func _predict_falling_body_target(enemy_id: int, from_position: Vector2) -> int:
	# One bounded query at launch, capped at the authored candidate count, rather
	# than a search every frame while the body flies.
	var nearest := -1
	var nearest_distance := INF
	var inspected := 0
	for candidate_id in combat.get_active_enemy_ids():
		if candidate_id == enemy_id:
			continue
		inspected += 1
		if inspected > newton_trajectory_candidates:
			break
		var distance := combat.get_enemy_position(candidate_id).distance_squared_to(
			from_position
		)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate_id
	return nearest


func _try_stem_steering(fruit: FruitState, enemy_id: int) -> void:
	if not _has_relic(PhaseBRelicCatalog.Id.STEM_STEERING):
		return
	if fruit.dropped_seed or fruit.fragment:
		return
	if fruit.steering_uses >= stem_steering_uses:
		return
	if fruit.speed < stem_steering_minimum_speed:
		return
	var target := _find_fruit_redirect_target(
		fruit, enemy_id, stem_steering_range_pixels
	)
	if target.x < 0.0:
		return
	fruit.steering_uses += 1
	# Heading only. The relic preserves speed exactly and adds nothing, so it can
	# never make a Fruit roll further than its Momentum paid for.
	_curve_fruit_toward(fruit, target, stem_steering_degrees)


func _try_windfall(fruit: FruitState, enemy_id: int) -> void:
	if not _has_relic(PhaseBRelicCatalog.Id.WINDFALL):
		return
	if fruit.dropped_seed or fruit.fragment:
		return
	if fruit.windfall_uses >= windfall_uses or fruit.windfall_cooldown > 0.0:
		return
	fruit.windfall_uses += 1
	fruit.windfall_cooldown = windfall_cooldown_seconds
	fruit.speed = minf(
		fruit.speed + fruit.base_speed * windfall_speed_share,
		fruit.base_speed * windfall_maximum_speed_share
	)
	fruit.velocity = fruit.last_direction * fruit.speed
	var target := _find_fruit_redirect_target(fruit, enemy_id, windfall_range_pixels)
	if target.x < 0.0:
		return
	_curve_fruit_toward(fruit, target, windfall_degrees)


func _find_fruit_redirect_target(
	fruit: FruitState,
	exclude_id: int,
	range_pixels: float
) -> Vector2:
	# Prefer somebody this Fruit has not already been through, so a redirect opens
	# new ground instead of grinding the same body.
	var began_usec := Time.get_ticks_usec() if PhaseBPerfCounters.enabled else 0
	var best := Vector2(-1.0, -1.0)
	var best_distance := INF
	# Left as a by-id read on purpose. Hoisting the paired roster here was tried and
	# was a pessimisation: the lookup is O(1) since the id-to-slot map landed, so the
	# hoist bought nothing and cost a second array allocation on a search that runs
	# on every qualifying collision.
	for candidate_id in combat.get_active_enemy_ids():
		if candidate_id == exclude_id or fruit.hit_cooldowns.has(candidate_id):
			continue
		var candidate := combat.get_enemy_position(candidate_id)
		var distance := candidate.distance_to(fruit.position)
		if distance > range_pixels or distance >= best_distance:
			continue
		best_distance = distance
		best = candidate
	PhaseBPerfCounters.timer_add_since(
		PhaseBPerfCounters.TIMER_FRUIT_REDIRECT, began_usec
	)
	return best


func _curve_fruit_toward(fruit: FruitState, target: Vector2, maximum_degrees: float) -> void:
	var wanted := fruit.position.direction_to(target)
	if wanted.length_squared() <= 0.0001:
		return
	var limit := deg_to_rad(maximum_degrees)
	var turn := clampf(fruit.last_direction.angle_to(wanted), -limit, limit)
	fruit.last_direction = fruit.last_direction.rotated(turn).normalized()
	fruit.velocity = fruit.last_direction * fruit.speed


func _try_fruit_salad(fruit: FruitState, enemy_id: int) -> void:
	if not _has_relic(PhaseBRelicCatalog.Id.FRUIT_SALAD):
		return
	if fruit.dropped_seed or fruit.fragment:
		return
	var mark: Array = _fruit_salad_marks.get(enemy_id, [])
	if (
		mark.size() == 3
		and int(mark[0]) == fruit.release_id
		and int(mark[1]) != fruit.fruit_id
	):
		# Two different Fruit of the same release. The burst is not a Fruit
		# collision, so it can never mark, chain, or feed anything in this pool.
		_fruit_salad_marks.erase(enemy_id)
		var burst_position := combat.get_enemy_position(enemy_id)
		combat.damage_enemies_in_radius(
			burst_position,
			fruit_salad_burst_radius,
			fruit.damage * fruit_salad_damage_share,
			PhaseBCombatDirector.DeathSource.RELIC
		)
		territory_field.queue_splat(
			burst_position,
			fruit_trail_mass * 0.6,
			fruit_trail_pressure_cells,
			progression.get_conversion_multiplier(),
			1.0
		)
		overlay.spawn_hostile_pulse(burst_position, fruit_salad_burst_radius)
		return
	_fruit_salad_marks[enemy_id] = [
		fruit.release_id,
		fruit.fruit_id,
		fruit_salad_mark_seconds,
	]


func _try_newtons_apple(fruit: FruitState, enemy_id: int) -> void:
	if not _has_relic(PhaseBRelicCatalog.Id.NEWTONS_APPLE):
		return
	if fruit.dropped_seed or fruit.fragment:
		return
	if fruit.newton_starters >= newton_starters_per_fruit or fruit.newton_cooldown > 0.0:
		return
	if not combat.is_enemy_active(enemy_id):
		return
	# Only an ordinary enemy becomes a projectile. An elite or a boss can be struck
	# by one and is never launched.
	if combat.get_enemy_role(enemy_id) != PhaseBCombatDirector.EnemyRole.HUNTER:
		return
	if _launch_falling_body(
		enemy_id,
		combat.get_enemy_position(enemy_id),
		1,
		fruit.damage * newton_first_damage_share,
		fruit.knockback * newton_first_knockback_share
	):
		fruit.newton_starters += 1
		fruit.newton_cooldown = newton_starter_cooldown


func _get_enemy_momentum_weight(enemy_id: int) -> float:
	match combat.get_enemy_role(enemy_id):
		PhaseBCombatDirector.EnemyRole.HUNTER, PhaseBCombatDirector.EnemyRole.RUSHER:
			return 0.35
		PhaseBCombatDirector.EnemyRole.GRAZER, PhaseBCombatDirector.EnemyRole.SABOTEUR:
			return 0.65
		PhaseBCombatDirector.EnemyRole.CORRUPTOR, PhaseBCombatDirector.EnemyRole.COLONIZER:
			return 0.72
		PhaseBCombatDirector.EnemyRole.BOSS:
			return 1.35
		PhaseBCombatDirector.EnemyRole.HEAVY_GRAZER, PhaseBCombatDirector.EnemyRole.SIEGE_CORRUPTOR:
			return 1.10
		_:
			return 1.0


func _resolve_fruit_obstacle_bounce(
	fruit: FruitState,
	previous: Vector2,
	blocked_position: Vector2
) -> void:
	var normal := territory_field.get_obstacle_normal_at_local(blocked_position)
	if normal.length_squared() <= 0.0001:
		var arena_center := territory_field.tuning.arena_size * 0.5
		normal = blocked_position.direction_to(arena_center)
	if normal.length_squared() <= 0.0001:
		normal = -fruit.velocity.normalized()
	var preserved := fruit_obstacle_momentum_preserved
	if (
		not fruit.dropped_seed
		and fruit.first_obstacle_bounce
		and _has_relic(PhaseBRelicCatalog.Id.BANK_SHOT)
	):
		preserved = 0.90
		fruit.bank_shot_armed = true
	fruit.first_obstacle_bounce = false
	fruit.speed *= preserved
	var reflected := fruit.velocity.normalized().bounce(normal).normalized()
	if reflected.length_squared() <= 0.0001:
		reflected = normal
	fruit.last_direction = reflected
	fruit.velocity = reflected * fruit.speed
	fruit.position = previous + reflected * 2.0


func _stamp_fruit_trail(fruit: FruitState, position: Vector2) -> void:
	if not territory_field.contains_local_point(position):
		return
	# One point splat per trail step. The count is what says how much a swept
	# capsule would save: every segment here overlaps its neighbours.
	PhaseBPerfCounters.count(PhaseBPerfCounters.COUNT_FRUIT_TRAIL_SEGMENTS)
	var area := maxf(0.05, fruit.germination_multiplier)
	if fruit.juicy_remaining > 0.0:
		# A bruised Fruit leaks. The terminal foothold is deliberately untouched:
		# this widens the trail, not the landing.
		area *= bruised_fruit_area_multiplier
	var radius_scale := sqrt(area)
	territory_field.queue_splat(
		position,
		fruit_trail_mass * area,
		fruit_trail_pressure_cells * radius_scale,
		fruit_trail_radius_cells * radius_scale,
		0.70,
		fruit.velocity.normalized(),
		1.65
	)
	if fruit.dropped_seed:
		return
	var pixels_per_cell := (
		territory_field.tuning.arena_size.x
		/ float(territory_field.tuning.field_size.x)
	)
	var zone_radius := fruit_trail_radius_cells * pixels_per_cell * radius_scale
	if _evolution_rank(PhaseBProgression.EvolutionId.ROT) >= 2:
		combat.add_spore_rate_zone(position, zone_radius, 0.50, 4.0)
	if _evolution_rank(PhaseBProgression.EvolutionId.DURIAN) >= 4:
		combat.add_entanglement_rate_zone(position, zone_radius, 0.50, 4.0)


func _stamp_fruit_trail_segment(
	fruit: FruitState,
	segment_start: Vector2,
	segment_end: Vector2
) -> void:
	## Every Fruit owns its own spacing accumulator. Sampling exact points along the
	## travelled segment prevents a multi-Fruit release from collapsing its territory
	## into whichever Fruit happened to cross a frame boundary first.
	var began_usec := Time.get_ticks_usec() if PhaseBPerfCounters.enabled else 0
	var segment := segment_end - segment_start
	var segment_length := segment.length()
	if segment_length <= 0.001:
		return
	var spacing := maxf(1.0, fruit_trail_spacing_pixels)
	var direction := segment / segment_length
	var cursor := maxf(0.0, spacing - fruit.trail_debt)
	var last_stamp_distance := -1.0
	while cursor <= segment_length + 0.001:
		_stamp_fruit_trail(fruit, segment_start + direction * cursor)
		last_stamp_distance = cursor
		cursor += spacing
	if last_stamp_distance >= 0.0:
		fruit.trail_debt = fmod(
			maxf(0.0, segment_length - last_stamp_distance),
			spacing
		)
	else:
		fruit.trail_debt = minf(spacing, fruit.trail_debt + segment_length)
	PhaseBPerfCounters.timer_add_since(
		PhaseBPerfCounters.TIMER_FRUIT_TRAIL_ENQUEUE, began_usec
	)


func _update_burdock_head(fruit: FruitState, delta: float) -> void:
	if (
		fruit.dropped_seed
		or _evolution_rank(PhaseBProgression.EvolutionId.BURDOCK) <= 0
	):
		return
	fruit.carried_thistle_remaining -= delta
	if fruit.carried_thistle_remaining > 0.0:
		return
	_fire_burdock_volley(fruit, false)
	# A mobile head's timer is its own. At rank 2 it inherits projectile upgrades,
	# not Dehiscence, because rolling cadence is part of Burdock's authored rule.
	fruit.carried_thistle_remaining = thistle_attack_interval


func _fire_burdock_volley(fruit: FruitState, empowered_final: bool) -> int:
	var rank := _evolution_rank(PhaseBProgression.EvolutionId.BURDOCK)
	if rank <= 0:
		return 0
	var targets := _collect_enemy_targets(fruit.position, thistle_range_pixels)
	if targets.is_empty():
		return 0
	var inherit_upgrades := rank >= 2
	var projectile_count := (
		1
		+ _upgrade(PhaseBProgression.UpgradeId.THISTLE_CLUSTERING)
		+ _root_count_step(
			PhaseBProgression.UpgradeId.THISTLE_CLUSTERING, fruit.position
		)
		if inherit_upgrades
		else 1
	)
	var fired := 0
	for index in range(projectile_count):
		if _spawn_thorn(
			fruit.position,
			targets[index % targets.size()],
			1.0,
			0,
			false,
			false,
			0.0,
			0.50 if empowered_final else 0.0,
			-1 if inherit_upgrades else 0,
			inherit_upgrades,
			2 if empowered_final else 0
		):
			fired += 1
	return fired


func _count_burdock_temporary_thistles() -> int:
	var count := 0
	for thistle in _thistles:
		if thistle.active and thistle.burdock_temporary:
			count += 1
	return count


func _finish_fruit(fruit: FruitState) -> void:
	if not fruit.active:
		return
	var direction := fruit.last_direction.normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	var burdock_rank := _evolution_rank(PhaseBProgression.EvolutionId.BURDOCK)
	if not fruit.dropped_seed and burdock_rank >= 5:
		_fire_burdock_volley(fruit, true)
	if (
		not fruit.dropped_seed
		and burdock_rank >= 4
		and _count_burdock_temporary_thistles() < 2
	):
		_plant_thistle(false, 5.0, fruit.position, true)
	_spawn_terminal_fruitseed(fruit, direction)
	if not fruit.dropped_seed and _has_relic(PhaseBRelicCatalog.Id.DROPPED_SEED):
		_fruit_terminal_count += 1
		if _fruit_terminal_count % 3 == 0:
			var dropped_area := fruit.germination_multiplier * 0.50
			var seed_roll := _spawn_fruit(
				fruit.position,
				direction,
				0.60,
				1.0,
				1.0,
				1.0,
				true,
				false,
				false,
				0,
				false,
				dropped_area,
				dropped_area
			)
			if seed_roll != null:
				seed_roll.damage = fruit.damage * 0.65
				seed_roll.terminal_damage = fruit.terminal_damage * 0.65
				seed_roll.normal_roll_distance = fruit.normal_roll_distance
				seed_roll.maximum_distance = fruit.normal_roll_distance * 0.60
				seed_roll.remaining_distance = seed_roll.maximum_distance
				_recompute_fruit_deceleration(seed_roll)
	fruit.active = false


func _spawn_terminal_fruitseed(fruit: FruitState, direction: Vector2) -> bool:
	var fruitseed: FruitseedState
	for candidate in _fruitseeds:
		if not candidate.active:
			fruitseed = candidate
			break
	if fruitseed == null:
		# Pool exhaustion must not erase gameplay; germinate synchronously and omit
		# only the charging presentation.
		var fallback := FruitseedState.new()
		_copy_fruit_to_fruitseed(fruit, fallback, direction)
		_germinate_fruitseed(fallback)
		return false
	_copy_fruit_to_fruitseed(fruit, fruitseed, direction)
	fruitseed.active = true
	return true


func _copy_fruit_to_fruitseed(
	fruit: FruitState,
	fruitseed: FruitseedState,
	direction: Vector2
) -> void:
	fruitseed.position = fruit.position
	fruitseed.duration = fruitseed_germination_seconds
	fruitseed.remaining = fruitseed.duration
	fruitseed.area_multiplier = fruit.terminal_germination_multiplier
	fruitseed.dropped_seed = fruit.dropped_seed
	fruitseed.fragment = fruit.fragment
	fruitseed.rotation = fruit.rotation
	fruitseed.direction = direction
	fruitseed.visual_index = fruit.visual_index
	fruitseed.visual_scale = fruit.visual_scale
	fruitseed.damage = fruit.damage
	fruitseed.terminal_damage = fruit.terminal_damage
	fruitseed.knockback = fruit.knockback
	fruitseed.normal_roll_distance = fruit.normal_roll_distance
	fruitseed.can_raise_sapling = fruit.can_raise_sapling


func _update_fruitseeds(delta: float) -> void:
	for fruitseed in _fruitseeds:
		if not fruitseed.active:
			continue
		fruitseed.remaining -= delta
		fruitseed.rotation += delta * 1.25
		if fruitseed.remaining > 0.0:
			continue
		fruitseed.active = false
		_germinate_fruitseed(fruitseed)


func _germinate_fruitseed(fruitseed: FruitseedState) -> void:
	var area := maxf(0.05, fruitseed.area_multiplier)
	var radius := fruit_terminal_effect_radius_pixels * sqrt(area)
	combat.damage_enemies_in_radius(
		fruitseed.position,
		radius,
		fruitseed.terminal_damage,
		PhaseBCombatDirector.DeathSource.FRUIT
	)
	# Evolution terminal events and the base burst happen before the territory
	# command, matching the explicit "explodes, then plants" order.
	if not fruitseed.dropped_seed:
		if _evolution_rank(PhaseBProgression.EvolutionId.ROT) >= 2:
			combat.add_spore_rate_zone(fruitseed.position, radius, 0.50, 4.0)
		if _evolution_rank(PhaseBProgression.EvolutionId.DURIAN) >= 4:
			combat.add_entanglement_rate_zone(fruitseed.position, radius, 0.50, 4.0)
		_apply_fruit_terminal_evolution(fruitseed)
	territory_field.queue_seed_growth(
		fruitseed.position,
		fruit_terminal_mass_multiplier * area,
		fruit_terminal_pressure_multiplier * area,
		fruit_terminal_conversion_multiplier * area,
		sqrt(area)
	)
	overlay.spawn_bloom(fruitseed.position)
	combat.play_plant_explosion_sfx()


func _apply_fruit_terminal_evolution(fruitseed: FruitseedState) -> void:
	var rot_rank := _evolution_rank(PhaseBProgression.EvolutionId.ROT)
	if rot_rank >= 4:
		combat.apply_spore_in_radius(fruitseed.position, 80.0, 0.40)
	if rot_rank >= 5:
		_rot_terminal_count += 1
		if _rot_terminal_count % 3 == 0 and spore_director != null:
			combat.spawn_fruiting_body(fruitseed.position, true)
	var overripe_rank := _evolution_rank(PhaseBProgression.EvolutionId.OVERRIPE)
	if overripe_rank >= 1:
		var force := 0.80 if overripe_rank >= 4 else 0.65
		_create_fruit_bloom(
			fruitseed.position,
			force,
			overripe_rank >= 3,
			fruitseed.direction,
			false
		)
		if overripe_rank >= 5 and not fruitseed.fragment:
			for sign_value in [-1.0, 1.0]:
				var fragment := _spawn_fruit(
					fruitseed.position,
					fruitseed.direction.rotated(0.34 * sign_value),
					0.40,
					1.0,
					1.0,
					1.05,
					false,
					true,
					false
				)
				if fragment != null:
					fragment.normal_roll_distance = fruitseed.normal_roll_distance
					fragment.maximum_distance = fruitseed.normal_roll_distance * 0.40
					fragment.remaining_distance = fragment.maximum_distance
					fragment.damage = fruitseed.damage
					fragment.terminal_damage = fruitseed.terminal_damage
					fragment.germination_multiplier = fruitseed.area_multiplier
					fragment.terminal_germination_multiplier = fruitseed.area_multiplier
					_recompute_fruit_deceleration(fragment)
	var durian_rank := _evolution_rank(PhaseBProgression.EvolutionId.DURIAN)
	if durian_rank >= 5:
		var radius := fruit_terminal_effect_radius_pixels * sqrt(maxf(0.05, fruitseed.area_multiplier))
		combat.apply_entanglement_in_radius(fruitseed.position, radius, 0.60)
		var repulsion := (
			bramble_director.get_repulsion_pixels()
			if bramble_director != null
			else 26.0
		)
		for enemy_id in combat.get_active_enemy_ids():
			if combat.get_enemy_position(enemy_id).distance_to(fruitseed.position) <= (
				radius + combat.get_enemy_radius(enemy_id)
			):
				combat.knockback_enemy_from(enemy_id, fruitseed.position, repulsion)
	var orchard_rank := _evolution_rank(PhaseBProgression.EvolutionId.ORCHARD)
	if orchard_rank >= 1 and fruitseed.can_raise_sapling:
		_orchard_terminal_count += 1
		if _orchard_terminal_count % 4 == 0:
			_spawn_orchard_sapling(fruitseed.position)


func _create_fruit_bloom(
	position: Vector2,
	force_share: float,
	launch_droplets: bool,
	direction: Vector2,
	play_primary_feedback: bool = true
) -> void:
	if bloom_director == null or force_share <= 0.0:
		return
	var bloom_began := Time.get_ticks_usec() if PhaseBPerfCounters.enabled else 0
	var amplification := (
		root_director.get_network_multiplier_here(position)
		if root_director != null
		else 1.0
	)
	var pixels_per_cell := (
		territory_field.tuning.arena_size.x
		/ float(territory_field.tuning.field_size.x)
	)
	var radius := territory_field.tuning.bloom_radius_cells * pixels_per_cell * sqrt(force_share)
	territory_field.queue_bloom(
		position,
		force_share * amplification,
		force_share * amplification,
		force_share * amplification,
		sqrt(force_share)
	)
	combat.damage_enemies_in_radius(
		position,
		radius,
		bloom_director.bloom_damage
			* bloom_director.get_bloom_force_multiplier()
			* force_share
			* amplification,
		PhaseBCombatDirector.DeathSource.BLOOM
	)
	if play_primary_feedback:
		overlay.spawn_bloom(position)
	if launch_droplets:
		var aim := direction.normalized()
		if aim.length_squared() <= 0.0001:
			aim = Vector2.RIGHT
		var globs := PackedVector2Array()
		for offset in [-0.48, 0.0, 0.48]:
			var landing := position + aim.rotated(float(offset)) * radius * 1.35
			if not territory_field.contains_local_point(landing):
				continue
			globs.append(landing)
			territory_field.queue_splat(
				landing,
				territory_field.tuning.bloom_mass * 0.18 * amplification,
				territory_field.tuning.bloom_pressure_cells * 0.22 * amplification,
				territory_field.tuning.bloom_radius_cells * 0.42,
				territory_field.tuning.bloom_hostile_conversion_factor,
				aim.rotated(float(offset)),
				1.25
			)
			combat.damage_enemies_in_radius(
				landing,
				radius * 0.42,
				bloom_director.bloom_damage
					* bloom_director.get_bloom_force_multiplier()
					* 0.18
					* amplification,
				PhaseBCombatDirector.DeathSource.BLOOM
			)
		if not globs.is_empty():
			overlay.spawn_splatter(position, radius, 0.55, 0.75, globs, 0.70)
	if play_primary_feedback:
		combat.play_plant_explosion_sfx()
	PhaseBPerfCounters.timer_add_since(
		PhaseBPerfCounters.TIMER_FRUIT_BLOOM, bloom_began
	)


func _spawn_orchard_sapling(position: Vector2) -> bool:
	for sapling in _saplings:
		if sapling.active:
			continue
		sapling.active = true
		sapling.position = position
		sapling.dormant_remaining = -1.0
		sapling.support_grace_remaining = sapling_spawn_support_grace_seconds
		sapling.release_toggle = false
		sapling.support_remaining = 0.0
		status_requested.emit("ORCHARD — a terminal foothold rooted into a Sapling.")
		return true
	return false


func _update_saplings(delta: float) -> void:
	var orchard_rank := _evolution_rank(PhaseBProgression.EvolutionId.ORCHARD)
	if orchard_rank <= 0:
		for sapling in _saplings:
			sapling.active = false
		return
	for sapling in _saplings:
		if not sapling.active:
			continue
		var supported := territory_field.is_owned_at_local(sapling.position)
		if supported:
			sapling.dormant_remaining = -1.0
			sapling.support_grace_remaining = 0.0
			if orchard_rank >= 2:
				sapling.support_remaining -= delta
				if sapling.support_remaining <= 0.0:
					sapling.support_remaining = sapling_support_interval
					territory_field.queue_maturity_support(
						sapling.position,
						territory_field.tuning.maturation_per_second
							* sapling_maturation_rate_bonus
							* sapling_support_interval,
						sapling_support_radius_multiplier
					)
					territory_field.queue_seed_growth(
						sapling.position,
						sapling_control_support * sapling_support_interval,
						0.0,
						0.20,
						sapling_support_radius_multiplier
					)
			continue
		if sapling.support_grace_remaining > 0.0:
			sapling.support_grace_remaining = maxf(
				0.0,
				sapling.support_grace_remaining - delta
			)
			continue
		if orchard_rank < 4:
			sapling.active = false
			continue
		if sapling.dormant_remaining < 0.0:
			sapling.dormant_remaining = 5.0
		else:
			sapling.dormant_remaining -= delta
			if sapling.dormant_remaining <= 0.0:
				sapling.active = false


func _apply_attached_gourdvine_hit(enemy_id: int, cane_damage: float) -> void:
	var rank := _evolution_rank(PhaseBProgression.EvolutionId.GOURDVINE)
	if rank <= 0 or not combat.is_enemy_active(enemy_id):
		return
	if rank >= 2:
		var weighted_damage := (
			fruit_collision_damage
			* (1.0 + _root_scaled_bonus(
				PhaseBProgression.UpgradeId.FRUIT_RIPENING,
				0.25,
				player.get_arena_position()
			))
			* 0.50
		)
		combat.damage_enemy_by_id(
			enemy_id,
			weighted_damage,
			PhaseBCombatDirector.DeathSource.FRUIT
		)
	if rank >= 4 and combat.is_enemy_active(enemy_id):
		var ripening_bonus := _root_scaled_bonus(
			PhaseBProgression.UpgradeId.FRUIT_RIPENING,
			0.25,
			player.get_arena_position()
		)
		combat.damage_enemy_by_id(
			enemy_id,
			cane_damage * ripening_bonus * 0.25,
			PhaseBCombatDirector.DeathSource.CANE
		)


func _detach_gourdvine_fruit(
	origin: Vector2,
	facing: Vector2,
	left_to_right: bool,
	reach: float
) -> void:
	var rank := _evolution_rank(PhaseBProgression.EvolutionId.GOURDVINE)
	if rank <= 0 or _gourdvine_pending_count <= 0:
		_gourdvine_attached = false
		return
	var half_angle := deg_to_rad(combat.cane_arc_degrees * 0.5)
	var terminal_angle := half_angle if left_to_right else -half_angle
	var tip_direction := facing.rotated(terminal_angle)
	var tip := origin + tip_direction * reach
	var distance_scale := 1.0
	if rank >= 3:
		distance_scale += 0.10 * float(
			_upgrade(PhaseBProgression.UpgradeId.VINE_ELONGATION)
		) * _root_bonus_scale(PhaseBProgression.UpgradeId.VINE_ELONGATION, origin)
	var speed_scale := 1.50 if rank >= 5 else 1.0
	var fruit_aim := _get_fruit_aim_direction(tip, distance_scale)
	for index in range(_gourdvine_pending_count):
		var offset := (
			float(_gourdvine_directions[index])
			if index < _gourdvine_directions.size()
			else _fruit_fan_offset(index, _gourdvine_pending_count, 0.42)
		)
		var fruit := _spawn_fruit(
			tip,
			fruit_aim.rotated(offset),
			distance_scale,
			1.0,
			1.0,
			speed_scale
		)
		if fruit != null and rank >= 5:
			fruit.first_collision_damage_multiplier = 1.50
	_gourdvine_pending_count = 0
	_gourdvine_attached = false
	_gourdvine_directions.clear()


func fire_slot_jackpot(path_id: int, jackpot_scale: float) -> void:
	## Immediate spectacle for the three new reel faces. The casino loan has already
	## maxed the Path's four lines before this is called; these events simply make the
	## win visible now instead of asking the player to wait for the next cadence tick.
	match path_id:
		PhaseBProgression.PathId.THISTLE:
			_ensure_permanent_thistles()
			_fire_all_thistles(maxf(1.0, jackpot_scale), 0, false)
		PhaseBProgression.PathId.VINE:
			var fallback := player.get_facing_direction()
			var facing := combat.get_densest_target_direction(
				player.get_arena_position(),
				combat.get_cane_reach(),
				combat.cane_arc_degrees,
				fallback
			)
			combat.perform_bonus_cane_sweep(
				facing,
				true,
				maxf(1.0, jackpot_scale),
				1.0
			)
		PhaseBProgression.PathId.FRUIT:
			_begin_normal_fruit_release()


func _draw() -> void:
	# First, under everything else: this is ground the effects stand on, not another
	# effect stacked on top of them.
	if draw_rooted_ground_glow:
		_draw_rooted_glow(
			_player_rooted_glow,
			player.get_arena_position(),
			rooted_glow_player_radius
		)
		for thistle in _thistles:
			if thistle.active and not thistle.carried:
				_draw_rooted_glow(
					thistle.rooted_glow,
					thistle.position,
					rooted_glow_thistle_radius
				)
	for sapling in _saplings:
		if sapling.active:
			_draw_sapling(sapling)
	for thistle in _thistles:
		if thistle.active:
			_draw_thistle(thistle)
	for thorn in _thorns:
		if thorn.active:
			_draw_thorn(thorn)
	for fruitseed in _fruitseeds:
		if fruitseed.active:
			_draw_fruitseed(fruitseed)
	for fruit in _fruits:
		if fruit.active:
			_draw_fruit(fruit)
	if _gourdvine_pending_count > 0:
		var facing := player.get_facing_direction()
		if progression.has_path_active(PhaseBProgression.PathId.VINE):
			facing = combat.get_densest_target_direction(
				player.get_arena_position(),
				combat.get_cane_reach(),
				combat.cane_arc_degrees,
				facing
			)
		var anchor := player.get_arena_position() + facing * combat.cane_reach_pixels * 0.72
		for index in range(_gourdvine_pending_count):
			var offset := Vector2.from_angle(float(index) * TAU / float(maxi(1, _gourdvine_pending_count))) * 7.0
			_draw_centered_texture(
				_get_fruit_texture(index),
				anchor + offset,
				fruit_art_diameter_pixels * 0.58,
				float(index) * 0.9,
				Color(1.0, 1.0, 1.0, 0.88)
			)


## Sample the Network at every point that takes a whole unit from it. Same two
## conditions the count step reads, so the light is true by construction rather than
## by a second copy of the rule: Root in the run, and Mature player ground here.
func _update_rooted_glow(delta: float) -> void:
	if not draw_rooted_ground_glow:
		return
	_rooted_glow_phase += delta
	var rooted := root_director != null and root_director.has_path()
	_advance_rooted_glow(_player_rooted_glow, player.get_arena_position(), rooted, delta)
	for thistle in _thistles:
		if thistle.active and not thistle.carried:
			_advance_rooted_glow(thistle.rooted_glow, thistle.position, rooted, delta)
		else:
			thistle.rooted_glow.clear()


func _advance_rooted_glow(
	glow: RootedGlowState,
	center: Vector2,
	rooted: bool,
	delta: float
) -> void:
	var lit := rooted and territory_field.is_mature_player_territory_at_local(center)
	# The depth read is only worth paying for where the light is actually on.
	var network := (
		root_director.get_network_multiplier_here(center)
		if lit
		else 1.0
	)
	glow.advance(delta, lit, network, rooted_glow_flare_seconds)


## A slow breathing light, brighter for a deeper Network, flaring on both edges.
##
## Sustained brightness follows the local Network rather than being a flat on/off
## mark, because the proportional lines are reading that same number at the same
## point -- a faint light is ground that just turned Mature, a strong one is a deep
## colony or an Annual Rings region, and the difference is worth seeing while moving.
## The breath is under 1 Hz on purpose: this state lasts most of a Root run, so it has
## to survive being looked at for minutes without becoming noise. The flares are what
## carry the actual event, and stepping *off* flares too -- an afterglow with nothing
## under it is the frame where the extra Fruit was lost.
func _draw_rooted_glow(glow: RootedGlowState, center: Vector2, radius: float) -> void:
	if not glow.lit and glow.flare <= 0.0:
		return
	var breath := 0.5 + 0.5 * sin(_rooted_glow_phase * TAU * rooted_glow_pulse_hz)
	var alpha := 0.0
	if glow.lit:
		var depth := clampf((glow.network - 1.0) / 1.6, 0.0, 1.0)
		alpha = lerpf(0.16, 0.38, depth) * lerpf(0.58, 1.0, breath)
	alpha += 0.30 * glow.flare * glow.flare
	if alpha <= 0.004:
		return
	var scale := 1.0 + 0.07 * breath + 0.24 * glow.flare
	# There is no gradient texture in this project, so the falloff is four stacked
	# discs drawn widest and dimmest first. Cheap enough at two points, and it reads
	# as light spilling out of the ground rather than as an outline drawn on it.
	for step in range(4):
		var t := 1.0 - float(step) / 3.0
		draw_circle(
			center,
			radius * scale * lerpf(0.42, 1.0, t),
			Color(1.0, 0.87, 0.48, alpha * lerpf(1.0, 0.26, t))
		)


func _draw_thistle(thistle: ThistleState) -> void:
	var alpha := 0.72 if not thistle.permanent else 0.92
	if thistle.unsupported_remaining >= 0.0:
		alpha *= clampf(thistle.unsupported_remaining / 3.0, 0.25, 1.0)
	var stalk_color := Color(0.24, 0.62, 0.31, alpha)
	var head_color := Color(0.58, 0.32, 0.72, alpha)
	if thistle.carried:
		# Snagged on the coat: no stalk in the ground, and the head sits high on
		# Grandma's shoulder so it reads as carried rather than as stood on.
		_draw_carried_thistle(thistle, head_color)
		return
	draw_line(thistle.position + Vector2(0.0, 11.0), thistle.position, stalk_color, 3.2, true)
	draw_circle(thistle.position, 7.5, head_color)
	for spike in range(10):
		var direction := Vector2.from_angle(TAU * float(spike) / 10.0)
		draw_line(
			thistle.position + direction * 5.0,
			thistle.position + direction * 12.0,
			head_color,
			2.0,
			true
		)


func _draw_carried_thistle(thistle: ThistleState, head_color: Color) -> void:
	var anchor := thistle.position + Vector2(0.0, -13.0)
	# The last stretch of the ride shakes as the burr works itself loose.
	var loosening := clampf(1.0 - thistle.carry_remaining / 0.6, 0.0, 1.0)
	if loosening > 0.0:
		anchor.x += sin(float(Time.get_ticks_msec()) * 0.045) * 2.0 * loosening
	draw_circle(anchor, 6.0, head_color)
	for spike in range(10):
		var direction := Vector2.from_angle(TAU * float(spike) / 10.0)
		draw_line(anchor + direction * 4.0, anchor + direction * 9.5, head_color, 1.7, true)


func _draw_thorn(thorn: ThornState) -> void:
	var direction := thorn.velocity.normalized()
	var length := 15.0 if thorn.heavy else 9.0
	var color := Color(1.0, 0.84, 0.38, 1.0) if thorn.heavy else Color(0.72, 0.92, 0.50, 0.95)
	draw_line(thorn.position - direction * length, thorn.position, color, 3.0 if thorn.heavy else 1.8, true)


func _draw_fruit(fruit: FruitState) -> void:
	var texture := FRUITSEED_TEXTURE if fruit.dropped_seed else _get_fruit_texture(fruit.visual_index)
	var diameter := (
		fruitseed_art_diameter_pixels * 0.78
		if fruit.dropped_seed
		else fruit_art_diameter_pixels * fruit.visual_scale
	)
	_draw_centered_texture(texture, fruit.position, diameter, fruit.rotation, Color.WHITE)
	if fruit.bank_shot_armed:
		draw_arc(fruit.position, diameter * 0.62, 0.0, TAU, 18, Color(1.0, 0.83, 0.34, 0.9), 2.2, true)


func _draw_fruitseed(fruitseed: FruitseedState) -> void:
	var progress := 1.0 - clampf(
		fruitseed.remaining / maxf(0.05, fruitseed.duration),
		0.0,
		1.0
	)
	var texture := (
		FRUITSEED_TEXTURE
		if fruitseed.dropped_seed
		else _get_fruit_texture(fruitseed.visual_index)
	)
	var base_diameter := (
		fruitseed_art_diameter_pixels
		if fruitseed.dropped_seed
		else fruit_art_diameter_pixels * fruitseed.visual_scale
	)
	var diameter := base_diameter * lerpf(0.94, 1.16, progress)
	_draw_centered_texture(
		texture,
		fruitseed.position,
		diameter,
		fruitseed.rotation,
		Color(1.0, 1.0, 1.0, 0.72 + 0.28 * progress)
	)
	draw_arc(
		fruitseed.position,
		diameter * 0.68,
		-PI * 0.5,
		-PI * 0.5 + TAU * progress,
		24,
		Color(0.96, 0.82, 0.34, 0.82) if fruitseed.dropped_seed else Color(0.50, 0.92, 0.43, 0.76),
		1.8,
		true
	)


func _draw_sapling(sapling: SaplingState) -> void:
	var dormant := sapling.dormant_remaining >= 0.0
	var color := Color(0.48, 0.44, 0.31, 0.48) if dormant else Color(0.36, 0.78, 0.38, 0.92)
	draw_line(sapling.position + Vector2(0.0, 13.0), sapling.position - Vector2(0.0, 10.0), color, 3.2, true)
	draw_circle(sapling.position + Vector2(-5.0, -8.0), 5.0, color)
	draw_circle(sapling.position + Vector2(5.0, -11.0), 5.5, color)


func _get_fruit_texture(index: int) -> Texture2D:
	return FRUIT_TEXTURES[posmod(index, FRUIT_TEXTURES.size())]


func _draw_centered_texture(
	texture: Texture2D,
	position: Vector2,
	diameter: float,
	rotation: float,
	tint: Color
) -> void:
	if texture == null or diameter <= 0.0:
		return
	var texture_size := Vector2(texture.get_width(), texture.get_height())
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var scale := diameter / maxf(texture_size.x, texture_size.y)
	var rect := Rect2(-texture_size * scale * 0.5, texture_size * scale)
	draw_set_transform(position, rotation, Vector2.ONE)
	draw_texture_rect(texture, rect, false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_pruning_ring_released(
	cuttings: int,
	charge: float,
	facing: Vector2,
	intentional: bool
) -> void:
	if not intentional:
		return
	var deadheading_rank := _evolution_rank(PhaseBProgression.EvolutionId.DEADHEADING)
	if deadheading_rank > 0 and cuttings >= 4:
		var charge_bonus := (
			pruning_director.get_launch_charge_damage_bonus() * charge
			if pruning_director != null
			else 0.0
		)
		var damage_scale := 1.0
		if deadheading_rank >= 2:
			damage_scale += charge_bonus * 0.35
		var extra_pierce := 1 if deadheading_rank >= 3 else 0
		_fire_all_thistles(damage_scale, extra_pierce, false)
		if deadheading_rank >= 4 and charge >= 0.999:
			_queue_pending_event(
				PendingKind.THISTLE_VOLLEY,
				0.40,
				player.get_arena_position(),
				facing,
				true,
				damage_scale * 0.60,
				0,
				extra_pierce
			)
		if deadheading_rank >= 5 and charge >= 0.999:
			_plant_thistle(false, 5.0)
			_plant_thistle(false, 5.0)
	var espalier_rank := _evolution_rank(PhaseBProgression.EvolutionId.ESPALIER)
	if espalier_rank >= 3 and charge >= 0.999:
		var cane_scale := 1.0
		if espalier_rank >= 4 and pruning_director != null:
			cane_scale += pruning_director.get_launch_charge_damage_bonus() * charge * 0.50
		combat.perform_bonus_cane_sweep(facing, true, cane_scale, 1.0)
	if espalier_rank >= 5 and charge >= 0.999:
		var release_scale := 1.0
		if pruning_director != null:
			release_scale += pruning_director.get_launch_charge_damage_bonus() * charge
		_queue_pending_event(
			PendingKind.ESPALIER_CUTTINGS,
			0.50,
			player.get_arena_position(),
			facing,
			true,
			release_scale * 0.60,
			cuttings
		)
	var graft_rank := _evolution_rank(PhaseBProgression.EvolutionId.GRAFT)
	if graft_rank > 0 and cuttings >= 4:
		_graft_cuttings = mini(12, cuttings)
		_graft_all_fruit = graft_rank >= 4 and cuttings >= 12
		_graft_prize = graft_rank >= 5 and cuttings >= 16
