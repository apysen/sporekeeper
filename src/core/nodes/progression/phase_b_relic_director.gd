class_name PhaseBRelicDirector
extends Node2D

## Runtime for every triggered relic in the run.
##
## Relics are permanent rule changes, not levelled stats, so this component owns
## the counters, cooldowns, per-wave flags, and persistent world objects that
## make those rules fire. It subscribes to explicit domain events - kills, wave
## starts, germinations, Bloom detonations, Bites, territory metrics - and never
## polls the scene tree looking for something to act on.
##
## Relics that are pure parameter changes are not simulated here at all. Those
## are pushed once into the system that owns them when the relic set changes, so
## the Core Weapon's own rules stay inside combat and the field's rules stay
## inside the field.
##
## Every trigger here is a fixed counter, a per-object limit, local enemy
## density, or an absolute amount of territory. Nothing keys off a percentage of
## the whole arena, which is the standing rule after the Kudzu and timed-Pruning
## failures.

signal status_requested(message: String)
signal relic_triggered(relic_id: int)

const INVALID_POSITION := Vector2(-1.0, -1.0)

class WorldObject:
	## A persistent relic object standing in the arena: a World Seed's site, a
	## Taproot, or a World Tree. It holds only plain values, and it dies with the
	## Green under it.
	var active := false
	var position := Vector2.ZERO
	var timer := 0.0
	var charge := 0.0
	var stage := 0

class RingRegion:
	## One Annual Rings region: where it is, how long it has survived, and how
	## many Rings it has earned.
	var position := Vector2.ZERO
	var survived := 0.0
	var rings := 0

class SweepState:
	## The Hedge's Briar Sweep, travelling across owned Green.
	var active := false
	var origin := Vector2.ZERO
	var radius := 0.0
	var maximum_radius := 0.0

@export_group("Collaborators")
## Progression component that owns which relics the run holds.
@export var progression: PhaseBProgression
## Authoritative field every territorial relic effect goes through.
@export var territory_field: TerritoryField
## Overlay owning Seeds, Blooms, and the markers relic objects draw through.
@export var overlay: TerritoryPrototypeOverlay
## Combat component supplying kills, enemies, and Core Weapon rules.
@export var combat: PhaseBCombatDirector
## Player component whose HP and movement two relics modify.
@export var player: PhaseBPlayer
## Wave component supplying the per-wave boundary relics reset on.
@export var wave_director: PhaseBWaveDirector
## Bloom component asked to open the Blooms two relics schedule.
@export var bloom_director: PhaseBBloomDirector
## Root component that reads back the Root Potency two relics deepen.
@export var root_director: PhaseBRootDirector

@export_group("Plant")
## Green Thumb: how close a pass has to be, and how far it advances the Seed.
@export_range(10.0, 200.0, 2.0) var green_thumb_radius_pixels := 46.0
@export_range(0.05, 1.0, 0.01) var green_thumb_progress := 0.35

@export_group("Spore")
## Hard Husk: interruptions each Seed shrugs off.
@export_range(1, 5, 1) var hard_husk_charges := 1
## Cross-Pollination: progress granted, its radius, and the per-Seed receiving
## cooldown that is the pool's primary anti-chain-rate limiter.
@export_range(0.05, 1.0, 0.01) var cross_pollination_progress := 0.25
@export_range(20.0, 600.0, 5.0) var cross_pollination_radius_pixels := 165.0
@export_range(0.0, 10.0, 0.05) var germination_grant_cooldown_seconds := 0.85

@export_group("Plant Relics")
## Garden Hose: how far Grandma has to travel across her own Green before the
## spray fires, and what the fan looks like when it does.
@export_range(20.0, 1200.0, 10.0) var garden_hose_travel_pixels := 240.0
@export_range(10.0, 400.0, 5.0) var garden_hose_range_pixels := 145.0
@export_range(1, 12, 1) var garden_hose_projectiles := 5
@export_range(10.0, 180.0, 1.0) var garden_hose_arc_degrees := 90.0
@export_range(0.0, 2.0, 0.01) var garden_hose_mass_per_projectile := 0.11
## Mulch: the share of what an enemy eats that it carries, the ceiling on that
## store, and how little is too little to bother erupting.
##
## Both are below the master document's initial targets of 0.65 and 1.25, which
## played as a Rare rather than a Common: a single well-fed corpse returned more
## than a whole Seed's worth of ground. The document asks for those numbers to be
## balanced from playtests, and this is that.
@export_range(0.0, 1.0, 0.01) var mulch_stored_share := 0.40
@export_range(0.1, 8.0, 0.05) var mulch_maximum_store := 0.60
@export_range(0.0, 2.0, 0.01) var mulch_minimum_store := 0.15
@export_range(10.0, 400.0, 5.0) var mulch_radius_pixels := 95.0
## Mimosa: the Green underfoot snaps shut when Grandma is hurt standing on it.
@export_range(10.0, 400.0, 5.0) var mimosa_radius_pixels := 120.0
@export_range(0.0, 400.0, 5.0) var mimosa_knockback_pixels := 90.0
@export_range(0.1, 30.0, 0.1) var mimosa_cooldown_seconds := 5.0
@export_range(0.0, 1.0, 0.01) var mimosa_elite_share := 0.60
@export_range(0.0, 1.0, 0.01) var mimosa_boss_share := 0.25
## Compost Heap: what a corpse is worth to a pile, what sets one off, and what it
## leaves behind when it does.
@export_range(10.0, 400.0, 5.0) var compost_merge_pixels := 110.0
@export_range(1, 40, 1) var compost_threshold := 6
@export_range(1.0, 120.0, 0.5) var compost_lifetime_seconds := 18.0
@export_range(0.0, 3.0, 0.05) var compost_eruption_delay := 0.45
@export_range(0.0, 400.0, 1.0) var compost_damage := 36.0
@export_range(10.0, 400.0, 5.0) var compost_damage_radius := 105.0
@export_range(0.0, 4.0, 0.05) var compost_mass := 0.75
@export_range(1, 20, 1) var compost_maximum_heaps := 8
## Grafting Tape: how often one primary Adaptation makes the other answer, and how
## hard the answer lands.
@export_range(1.0, 120.0, 0.5) var grafting_tape_cooldown_seconds := 18.0
@export_range(0.0, 3.0, 0.05) var grafting_tape_delay_seconds := 0.25
@export_range(0.05, 1.0, 0.01) var grafting_tape_strength := 0.75
## Miracle-Gro: new Green banked before the next Adaptation event repeats.
@export_range(0.1, 20.0, 0.1) var miracle_gro_required_mass := 2.5
@export_range(0.0, 3.0, 0.05) var miracle_gro_delay_seconds := 0.35
@export_range(0.05, 1.0, 0.01) var miracle_gro_strength := 0.60
## Hybrid Vigor: the chance a triggered relic effect happens twice, and the rolling
## ceiling that stops a dense chain from doubling everything at once.
@export_range(0.0, 1.0, 0.01) var hybrid_vigor_chance := 0.20
@export_range(0.0, 3.0, 0.05) var hybrid_vigor_delay_seconds := 0.20
@export_range(0.05, 1.0, 0.01) var hybrid_vigor_strength := 0.60
@export_range(1, 20, 1) var hybrid_vigor_window_maximum := 4

@export_group("Generated Events")
## The global safety net. Individual relic caps stay authoritative; this only stops
## a pathological frame from resolving an unbounded number of secondary events.
@export_range(1, 64, 1) var generated_events_per_frame := 12
@export_range(1, 256, 1) var generated_event_queue_maximum := 48
@export_range(0.01, 0.5, 0.01) var generated_event_stagger_seconds := 0.05

@export_group("Bloom")
## Wind-up multiplier applied to every Bloom under Late Bloomer.
@export_range(1.0, 4.0, 0.05) var late_bloomer_windup_multiplier := 1.70
## Largest Force and Conversion bonus a fully charged Late Bloomer reaches.
@export_range(0.0, 3.0, 0.05) var late_bloomer_maximum_bonus := 0.65
## Pixels within which two Blooms count as substantially overlapping.
@export_range(20.0, 600.0, 5.0) var superbloom_overlap_pixels := 150.0
## Seconds a recent Bloom stays eligible to overlap with the next one.
@export_range(0.1, 10.0, 0.05) var superbloom_memory_seconds := 1.20
## Force multiplier of the secondary shockwave.
@export_range(0.05, 2.0, 0.05) var superbloom_force := 0.55
## Global cooldown in seconds between secondary shockwaves.
@export_range(0.5, 30.0, 0.5) var superbloom_cooldown_seconds := 5.0
## Times a Perennial Flower re-blooms during its wave.
@export_range(1, 6, 1) var perennial_reblooms := 2
## Seconds between a Perennial's re-blooms.
@export_range(1.0, 60.0, 0.5) var perennial_interval_seconds := 7.0
## Force multiplier of a Perennial re-bloom.
@export_range(0.05, 2.0, 0.05) var perennial_force := 0.60

@export_group("Bramble")
## Enemies that receive spread Entanglement when Grasping Roots bites.
@export_range(1, 8, 1) var snare_vine_targets := 2
## Radius in pixels Snare Vine spreads across.
@export_range(20.0, 400.0, 5.0) var snare_vine_radius_pixels := 96.0
## Entanglement spread to each of those enemies.
@export_range(0.01, 1.0, 0.01) var snare_vine_entanglement := 0.20
## Enemies standing on one patch of Green that raise it to Rampart.
@export_range(2, 30, 1) var living_rampart_enemies := 6
## Radius in pixels a Rampart covers.
@export_range(40.0, 500.0, 5.0) var living_rampart_radius_pixels := 150.0
## Ensnare-rate bonus applied inside a Rampart.
@export_range(0.0, 4.0, 0.05) var living_rampart_ensnare_bonus := 1.20
## Repulsion-interval multiplier inside a Rampart; lower repels more often.
@export_range(0.05, 1.0, 0.01) var living_rampart_repulsion_multiplier := 0.55
## Seconds a Rampart persists after the crowd that raised it thins out.
@export_range(0.1, 10.0, 0.1) var living_rampart_linger_seconds := 1.5
## Seconds between Rampart scans. The scan compares every enemy against every
## other, so it runs on a cadence rather than every frame.
@export_range(0.05, 2.0, 0.05) var living_rampart_scan_seconds := 0.25
## Heavily Entangled enemies on Green that set off a Briar Sweep.
@export_range(2, 30, 1) var hedge_enemies := 6
## Entanglement at which an enemy counts toward that total.
@export_range(0.1, 1.0, 0.01) var hedge_entanglement_threshold := 0.70
## Entanglement floor the Sweep raises normal enemies to.
@export_range(0.1, 1.0, 0.01) var hedge_minimum_entanglement := 0.75
## Fraction of that floor applied to elites and bosses instead.
@export_range(0.0, 1.0, 0.01) var hedge_elite_share := 0.35
## Pixels per second the Sweep front travels. The master document suggests 520,
## which is slow enough for the ridge of thorns to read as travelling through the
## Green rather than arriving everywhere at once.
@export_range(50.0, 2000.0, 10.0) var hedge_sweep_speed := 520.0
## Global cooldown in seconds between Briar Sweeps.
@export_range(1.0, 60.0, 0.5) var hedge_cooldown_seconds := 10.0

@export_group("Root")
## The Shared Ancient Territory placement rule: how far from Grandma a relic object
## looks for old ground, how far it will stretch if nothing nearby qualifies, and
## what counts as a region worth establishing on at all.
@export_range(40.0, 1200.0, 10.0) var ancient_search_pixels := 320.0
@export_range(40.0, 2000.0, 10.0) var ancient_expanded_search_pixels := 480.0
@export_range(0.1, 1.0, 0.01) var ancient_minimum_maturity := 0.90
@export_range(1, 200, 1) var ancient_minimum_cells := 16
## Seconds between topology samples. Component analysis walks the whole field, and
## the shape of an organism does not change between two frames, so every relic that
## asks a question about it shares one cached answer on this clock.
@export_range(0.05, 5.0, 0.05) var topology_interval_seconds := 0.50
## Rootbound: time on deeply Mature Green to charge a pulse, how long the charge
## is carried, and what discharging it into younger Green does.
@export_range(0.1, 30.0, 0.1) var rootbound_charge_seconds := 2.5
@export_range(0.1, 1.0, 0.01) var rootbound_charge_maturity := 0.90
@export_range(0.5, 30.0, 0.5) var rootbound_carry_seconds := 4.0
@export_range(0.0, 1.0, 0.01) var rootbound_discharge_maturity := 0.60
@export_range(10.0, 400.0, 5.0) var rootbound_radius_pixels := 95.0
@export_range(0.0, 1.0, 0.01) var rootbound_maturity_granted := 0.18
@export_range(0.1, 30.0, 0.1) var rootbound_cooldown_seconds := 4.0
## Suckers: how much Mature Green enemies have to tear away, and what the
## surviving roots throw back into the wound.
@export_range(1, 200, 1) var suckers_lost_cells := 24
@export_range(0.1, 10.0, 0.1) var suckers_window_seconds := 1.0
@export_range(1, 12, 1) var suckers_count := 2
@export_range(0.0, 3.0, 0.05) var suckers_delay_seconds := 0.45
@export_range(10.0, 400.0, 5.0) var suckers_radius_pixels := 110.0
@export_range(0.0, 2.0, 0.01) var suckers_mass := 0.18
@export_range(0.1, 30.0, 0.1) var suckers_cooldown_seconds := 4.0
## Feeder Roots: amplified natural events before the network feeds its frontier.
@export_range(1, 20, 1) var feeder_roots_events := 4
@export_range(0.1, 1.0, 0.01) var feeder_roots_source_maturity := 0.90
@export_range(20.0, 800.0, 10.0) var feeder_roots_range_pixels := 240.0
@export_range(10.0, 400.0, 5.0) var feeder_roots_radius_pixels := 80.0
@export_range(0.0, 1.0, 0.01) var feeder_roots_maturity_granted := 0.12
@export_range(0.0, 1.0, 0.01) var feeder_roots_control := 0.08
@export_range(0.1, 30.0, 0.1) var feeder_roots_cooldown_seconds := 2.0
## Graft Union: two established networks reconnecting mature both sides and arm
## one echo across the new join.
@export_range(1, 200, 1) var graft_union_minimum_cells := 16
@export_range(0.1, 30.0, 0.1) var graft_union_separation_seconds := 3.0
@export_range(10.0, 400.0, 5.0) var graft_union_radius_pixels := 90.0
@export_range(0.0, 1.0, 0.01) var graft_union_maturity_granted := 0.15
@export_range(0.5, 30.0, 0.5) var graft_union_armed_seconds := 5.0
@export_range(0.05, 1.0, 0.01) var graft_union_strength := 0.50
@export_range(0.1, 60.0, 0.5) var graft_union_cooldown_seconds := 8.0
## Rhizome: an isolated colony that survives long enough grows a runner home.
@export_range(1, 200, 1) var rhizome_minimum_cells := 24
@export_range(0.1, 1.0, 0.01) var rhizome_minimum_maturity := 0.70
@export_range(0.5, 60.0, 0.5) var rhizome_survival_seconds := 10.0
@export_range(20.0, 1200.0, 10.0) var rhizome_maximum_distance := 320.0
@export_range(0.1, 10.0, 0.05) var rhizome_growth_seconds := 1.20
@export_range(0.0, 1.0, 0.01) var rhizome_corridor_maturity := 0.50
@export_range(10.0, 400.0, 5.0) var rhizome_pulse_pixels := 100.0
@export_range(0.0, 1.0, 0.01) var rhizome_pulse_maturity := 0.10
@export_range(0.5, 60.0, 0.5) var rhizome_cooldown_seconds := 12.0
## Seconds between one Taproot repair pulse.
@export_range(0.5, 30.0, 0.5) var taproot_interval_seconds := 4.0
## Mass multiplier of one Taproot repair pulse.
@export_range(0.05, 4.0, 0.05) var taproot_mass := 0.55
## Radius multiplier of that pulse.
@export_range(0.1, 4.0, 0.05) var taproot_radius := 1.30
## Seconds a Mature region must survive to earn one Annual Ring.
@export_range(2.0, 120.0, 1.0) var annual_rings_interval_seconds := 22.0
## Rings one region may accumulate.
@export_range(1, 8, 1) var annual_rings_maximum := 3
## Root Potency added per Ring for mechanics acting inside that region.
@export_range(0.01, 1.0, 0.01) var annual_rings_potency := 0.14
## Radius in pixels a tracked Ring region covers.
@export_range(20.0, 400.0, 5.0) var annual_rings_radius_pixels := 110.0
## Regions Annual Rings tracks at once.
@export_range(1, 12, 1) var annual_rings_regions := 4
## Seconds between World Tree echo charges.
@export_range(1.0, 60.0, 0.5) var world_tree_interval_seconds := 6.0
## Strength multiplier of a World Tree echo.
@export_range(0.05, 1.0, 0.01) var world_tree_echo_strength := 0.45
## Seconds before a destroyed World Tree may reform.
@export_range(1.0, 120.0, 1.0) var world_tree_reform_seconds := 20.0

var _wave_number := 0
var _green_thumb_used := {}

## Distance Grandma has covered on her own Green since the last spray. Paused off
## Green rather than reset, so crossing a gap does not cost the progress.
var _garden_hose_travel := 0.0
var _garden_hose_last_position := INVALID_POSITION
## What each enemy has eaten and is carrying, by id.
var _mulch_stores := {}
var _mimosa_cooldown := 0.0
## Compost piles, each [position, compost, lifetime, fuse].
var _compost_heaps: Array = []
var _grafting_tape_cooldown := 0.0
var _miracle_gro_banked := 0.0
var _miracle_gro_charged := false
## Hybrid Vigor repeats resolved inside the current rolling second.
var _hybrid_vigor_window: Array = []
## True while a repeat is being resolved, so a repeat can never roll another.
var _repeating := false
## The global generated-event queue: [relic_id, position, strength, remaining].
var _generated_events: Array = []
var _generated_this_frame := 0
## Telemetry for the stress fixtures: how deep the queue has ever been, how many
## events had to wait for a later frame, and how many were dropped outright. A
## dropped event is the only one that costs the player something, so it is counted
## separately from one that merely arrived late.
var _generated_peak_depth := 0
var _generated_staggered := 0
var _generated_dropped := 0

## Rootbound: seconds stood on deeply Mature Green, and the pulse being carried.
var _rootbound_standing := 0.0
var _rootbound_carrying := 0.0
var _rootbound_cooldown := 0.0
## Suckers: Mature cells the enemy has torn off inside the rolling window.
var _suckers_lost := 0
var _suckers_window := 0.0
var _suckers_cooldown := 0.0
## Shoots waiting to emerge, each [position, remaining].
var _pending_suckers: Array = []
## Feeder Roots: amplified natural events so far, and its own cooldown.
var _feeder_events := 0
var _feeder_cooldown := 0.0
## Graft Union: how long the network has been split, and the armed echo.
var _graft_components := 0
var _graft_split_seconds := 0.0
var _graft_armed := 0.0
var _graft_cooldown := 0.0
var _graft_position := INVALID_POSITION
## Rhizome: how long the current isolated colony has held out.
var _rhizome_survived := 0.0
var _rhizome_growing := 0.0
var _rhizome_cooldown := 0.0
var _rhizome_route := PackedVector2Array()

## Cached topology, refreshed on the shared cadence rather than per relic per frame.
var _topology_remaining := 0.0
var _cached_component_count := 1
var _cached_isolated_colony := INVALID_POSITION
## Every qualifying ancient region, refreshed on the topology clock. All three
## relics that establish on old ground choose from this one list.
var _cached_ancient_regions: Array = []

var _recent_blooms: Array = []
var _superbloom_cooldown := 0.0
var _perennial := WorldObject.new()
var _perennial_armed := false

var _rampart_remaining := 0.0
var _rampart_scan_remaining := 0.0
var _rampart_position := INVALID_POSITION
var _hedge_cooldown := 0.0
var _sweep := SweepState.new()

var _taproot := WorldObject.new()
var _ring_regions: Array[RingRegion] = []
var _world_tree := WorldObject.new()

var _relic_random := RandomNumberGenerator.new()


func _ready() -> void:
	assert(progression != null, "PhaseBRelicDirector requires PhaseBProgression")
	assert(territory_field != null, "PhaseBRelicDirector requires TerritoryField")
	assert(overlay != null, "PhaseBRelicDirector requires TerritoryPrototypeOverlay")
	assert(combat != null, "PhaseBRelicDirector requires PhaseBCombatDirector")
	assert(player != null, "PhaseBRelicDirector requires PhaseBPlayer")
	assert(wave_director != null, "PhaseBRelicDirector requires PhaseBWaveDirector")
	combat.enemy_killed.connect(_on_enemy_killed)
	combat.enemy_rooted.connect(_on_enemy_rooted)
	overlay.seed_germinated_with_context.connect(_on_seed_germinated)
	overlay.bloom_detonated.connect(_on_bloom_detonated)
	player.damage_taken.connect(_on_player_damage_taken)
	combat.enemy_ate_green.connect(notify_green_eaten)
	reset_director()


func reset_director() -> void:
	_wave_number = 0
	_green_thumb_used.clear()
	_garden_hose_travel = 0.0
	_garden_hose_last_position = INVALID_POSITION
	_mulch_stores.clear()
	_mimosa_cooldown = 0.0
	_compost_heaps.clear()
	_grafting_tape_cooldown = 0.0
	_miracle_gro_banked = 0.0
	_miracle_gro_charged = false
	_hybrid_vigor_window.clear()
	_repeating = false
	_generated_events.clear()
	_generated_this_frame = 0
	_generated_peak_depth = 0
	_generated_staggered = 0
	_generated_dropped = 0
	_rootbound_standing = 0.0
	_rootbound_carrying = 0.0
	_rootbound_cooldown = 0.0
	_suckers_lost = 0
	_suckers_window = 0.0
	_suckers_cooldown = 0.0
	_pending_suckers.clear()
	_feeder_events = 0
	_feeder_cooldown = 0.0
	_graft_components = 0
	_graft_split_seconds = 0.0
	_graft_armed = 0.0
	_graft_cooldown = 0.0
	_graft_position = INVALID_POSITION
	_rhizome_survived = 0.0
	_rhizome_growing = 0.0
	_rhizome_cooldown = 0.0
	_rhizome_route = PackedVector2Array()
	# Deliberately not zero: the first sample would otherwise land on the same frame
	# as every other system's first tick, and the warm-up frame is already the
	# heaviest one in the run.
	_topology_remaining = topology_interval_seconds
	_cached_component_count = 1
	_cached_isolated_colony = INVALID_POSITION
	_cached_ancient_regions.clear()
	_recent_blooms.clear()
	_superbloom_cooldown = 0.0
	_perennial = WorldObject.new()
	_perennial_armed = false
	_rampart_remaining = 0.0
	_rampart_scan_remaining = 0.0
	_rampart_position = INVALID_POSITION
	_hedge_cooldown = 0.0
	_sweep = SweepState.new()
	_taproot = WorldObject.new()
	_ring_regions.clear()
	_world_tree = WorldObject.new()
	_relic_random.seed = 0x0FF1CE5
	player.set_speed_multiplier(1.0)
	apply_relics()
	queue_redraw()


func apply_relics() -> void:
	# Relics that are pure rule parameters are pushed once, when the relic set
	# changes, into whichever system owns that rule. Nothing about them needs a
	# per-frame tick, so nothing about them lives in this component's update.
	overlay.set_default_seed_shield_charges(
		hard_husk_charges if has(PhaseBRelicCatalog.Id.HARD_HUSK) else 0
	)
	if bloom_director != null:
		bloom_director.set_relic_rules(
			late_bloomer_windup_multiplier if has(PhaseBRelicCatalog.Id.LATE_BLOOMER) else 1.0,
			late_bloomer_maximum_bonus
		)


func has(relic_id: int) -> bool:
	return progression.has_relic(relic_id)


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	_generated_this_frame = 0
	_advance_wave_boundary()
	_advance_timers(delta)
	_advance_generated_events(delta)
	_advance_garden_hose()
	_advance_compost(delta)
	_advance_topology(delta)
	_advance_rootbound(delta)
	_advance_suckers(delta)
	_advance_graft_union(delta)
	_advance_rhizome(delta)
	_advance_green_thumb()
	_advance_rampart(delta)
	_try_trigger_hedge()
	_advance_sweep(delta)
	_advance_taproot(delta)
	_advance_annual_rings(delta)
	_advance_world_tree(delta)
	_advance_perennial(delta)
	queue_redraw()


func _advance_wave_boundary() -> void:
	# Per-wave relics reset on the wave the wave director publishes, so nothing
	# here has to guess where a wave began.
	var current := wave_director.get_current_wave_number()
	if current == _wave_number:
		return
	_wave_number = current
	_perennial_armed = has(PhaseBRelicCatalog.Id.PERENNIAL)
	_perennial.active = false


func _advance_timers(delta: float) -> void:
	_superbloom_cooldown = maxf(0.0, _superbloom_cooldown - delta)
	_mimosa_cooldown = maxf(0.0, _mimosa_cooldown - delta)
	_grafting_tape_cooldown = maxf(0.0, _grafting_tape_cooldown - delta)
	for index in range(_hybrid_vigor_window.size() - 1, -1, -1):
		_hybrid_vigor_window[index] = float(_hybrid_vigor_window[index]) - delta
		if float(_hybrid_vigor_window[index]) <= 0.0:
			_hybrid_vigor_window.remove_at(index)
	_hedge_cooldown = maxf(0.0, _hedge_cooldown - delta)
	for index in range(_recent_blooms.size() - 1, -1, -1):
		var entry: Array = _recent_blooms[index]
		entry[1] = float(entry[1]) - delta
		if float(entry[1]) <= 0.0:
			_recent_blooms.remove_at(index)


func _advance_green_thumb() -> void:
	# One touch per Seed, ever. The dictionary is keyed by the Seed's own id, so a
	# Seed cannot be milked by walking back and forth across it.
	if not has(PhaseBRelicCatalog.Id.GREEN_THUMB):
		return
	var origin := player.get_arena_position()
	for seed_id in overlay.get_seed_ids():
		if _green_thumb_used.has(seed_id):
			continue
		if overlay.get_seed_position(seed_id).distance_to(origin) > green_thumb_radius_pixels:
			continue
		_green_thumb_used[seed_id] = true
		overlay.advance_seed(seed_id, green_thumb_progress, 0.0)
		_notify_triggered(PhaseBRelicCatalog.Id.GREEN_THUMB)


func _advance_rampart(delta: float) -> void:
	# Local enemy density, not a territory percentage: a Rampart is a patch of
	# your own Green that too many enemies are standing on right now.
	if not has(PhaseBRelicCatalog.Id.LIVING_RAMPART):
		if _rampart_remaining > 0.0:
			_rampart_remaining = 0.0
			combat.clear_rampart()
		return
	_rampart_remaining = maxf(0.0, _rampart_remaining - delta)
	_rampart_scan_remaining -= delta
	if _rampart_scan_remaining > 0.0:
		return
	_rampart_scan_remaining = living_rampart_scan_seconds
	var best_position := INVALID_POSITION
	var best_count := living_rampart_enemies - 1
	var positions := combat.get_active_enemy_positions()
	for candidate in positions:
		if territory_field.get_control_at_local(candidate) <= territory_field.tuning.ownership_threshold:
			continue
		var count := 0
		for other in positions:
			if candidate.distance_to(other) <= living_rampart_radius_pixels:
				count += 1
		if count > best_count:
			best_count = count
			best_position = candidate
	if best_position.x >= 0.0:
		var was_active := _rampart_remaining > 0.0
		_rampart_position = best_position
		_rampart_remaining = living_rampart_linger_seconds
		combat.set_rampart(
			best_position,
			living_rampart_radius_pixels,
			living_rampart_ensnare_bonus,
			living_rampart_repulsion_multiplier
		)
		if not was_active:
			status_requested.emit("LIVING RAMPART — crowded Green turns on the crowd.")
			_notify_triggered(PhaseBRelicCatalog.Id.LIVING_RAMPART)
	elif _rampart_remaining <= 0.0 and _rampart_position.x >= 0.0:
		_rampart_position = INVALID_POSITION
		combat.clear_rampart()


func _try_trigger_hedge() -> void:
	if not has(PhaseBRelicCatalog.Id.THE_HEDGE) or _hedge_cooldown > 0.0 or _sweep.active:
		return
	var heavily_entangled := 0
	for enemy_id in combat.get_active_enemy_ids():
		if combat.get_enemy_entanglement(enemy_id) < hedge_entanglement_threshold:
			continue
		heavily_entangled += 1
	if heavily_entangled < hedge_enemies:
		return
	_hedge_cooldown = hedge_cooldown_seconds
	_sweep.active = true
	_sweep.origin = player.get_arena_position()
	_sweep.radius = 0.0
	_sweep.maximum_radius = territory_field.tuning.arena_size.length()
	status_requested.emit("THE HEDGE — a Briar Sweep runs the length of your Green.")
	_notify_triggered(PhaseBRelicCatalog.Id.THE_HEDGE)


func _advance_sweep(delta: float) -> void:
	if not _sweep.active:
		return
	var previous := _sweep.radius
	_sweep.radius += hedge_sweep_speed * delta
	if _sweep.radius >= _sweep.maximum_radius:
		_sweep.active = false
	for enemy_id in combat.get_active_enemy_ids():
		var enemy_position := combat.get_enemy_position(enemy_id)
		var distance := enemy_position.distance_to(_sweep.origin)
		if distance < previous or distance > _sweep.radius:
			continue
		if territory_field.get_control_at_local(enemy_position) <= territory_field.tuning.ownership_threshold:
			continue
		# Elites and bosses feel it, but far less: a Sweep controls the horde.
		var floor_value := hedge_minimum_entanglement
		if combat.is_enemy_resistant(enemy_id):
			floor_value *= hedge_elite_share
		combat.raise_entanglement_floor(enemy_id, floor_value)
		combat.interrupt_enemy(enemy_id)


func _advance_topology(delta: float) -> void:
	## One flood fill on a clock, shared by every relic that asks about the shape of
	## the organism. Sampled only while a relic that reads it is actually held.
	var wants_components := has(PhaseBRelicCatalog.Id.GRAFT_UNION)
	var wants_colony := has(PhaseBRelicCatalog.Id.RHIZOME)
	var wants_ancient := (
		has(PhaseBRelicCatalog.Id.TAPROOT)
		or has(PhaseBRelicCatalog.Id.ANNUAL_RINGS)
		or has(PhaseBRelicCatalog.Id.WORLD_TREE)
	)
	if not wants_components and not wants_colony and not wants_ancient:
		return
	_topology_remaining -= delta
	if _topology_remaining > 0.0:
		return
	_topology_remaining = topology_interval_seconds
	if wants_components:
		_cached_component_count = territory_field.get_owned_component_count(
			graft_union_minimum_cells
		)
	if wants_colony:
		_cached_isolated_colony = territory_field.find_isolated_colony(
			rhizome_minimum_cells,
			rhizome_minimum_maturity
		)
	if wants_ancient:
		_cached_ancient_regions = territory_field.get_ancient_regions(
			ancient_minimum_maturity,
			ancient_minimum_cells
		)


func _advance_rootbound(delta: float) -> void:
	## Charged by standing on old ground, spent by walking into young ground. The
	## player carries the pulse rather than the ground broadcasting it, which is
	## what makes the relic about where Grandma goes next.
	_rootbound_cooldown = maxf(0.0, _rootbound_cooldown - delta)
	if not has(PhaseBRelicCatalog.Id.ROOTBOUND):
		_rootbound_standing = 0.0
		_rootbound_carrying = 0.0
		return
	var origin := player.get_arena_position()
	var owned := (
		territory_field.get_control_at_local(origin)
		> territory_field.tuning.ownership_threshold
	)
	var maturity := territory_field.get_maturity_at_local(origin)
	if _rootbound_carrying > 0.0:
		# Leaving owned Green entirely does not discharge it; only younger owned
		# Green does. The charge simply ages out otherwise.
		_rootbound_carrying = maxf(0.0, _rootbound_carrying - delta)
		if owned and maturity < rootbound_discharge_maturity:
			_rootbound_carrying = 0.0
			_rootbound_cooldown = rootbound_cooldown_seconds
			territory_field.queue_maturity_support(
				origin,
				rootbound_maturity_granted,
				rootbound_radius_pixels / 48.0
			)
			overlay.spawn_bloom(origin)
			status_requested.emit("ROOTBOUND — the carried pulse threads into young Green.")
			_notify_triggered(PhaseBRelicCatalog.Id.ROOTBOUND)
		return
	if _rootbound_cooldown > 0.0:
		return
	if owned and maturity >= rootbound_charge_maturity:
		_rootbound_standing += delta
		if _rootbound_standing >= rootbound_charge_seconds:
			_rootbound_standing = 0.0
			_rootbound_carrying = rootbound_carry_seconds
			status_requested.emit("ROOTBOUND — you are carrying a root pulse.")
		return
	# The charge wants continuous time on deep ground, so stepping off resets it.
	_rootbound_standing = 0.0


func notify_mature_green_lost(cells: int) -> void:
	## Reported when enemies tear Mature Green off. Player-authored losses -- a
	## Pruning harvest, a Clover wager -- must never reach this: Suckers answers an
	## attack, not a sacrifice.
	if not has(PhaseBRelicCatalog.Id.SUCKERS) or cells <= 0:
		return
	if _suckers_cooldown > 0.0:
		return
	_suckers_lost += cells
	_suckers_window = suckers_window_seconds


func _advance_suckers(delta: float) -> void:
	_suckers_cooldown = maxf(0.0, _suckers_cooldown - delta)
	if _suckers_window > 0.0:
		_suckers_window = maxf(0.0, _suckers_window - delta)
		if _suckers_window <= 0.0:
			_suckers_lost = 0
	if _suckers_lost >= suckers_lost_cells and _suckers_cooldown <= 0.0:
		var wound := player.get_arena_position()
		_suckers_lost = 0
		_suckers_window = 0.0
		_suckers_cooldown = suckers_cooldown_seconds
		for index in range(suckers_count):
			_pending_suckers.append([
				wound + Vector2.from_angle(float(index) * 2.39996) * suckers_radius_pixels * 0.5,
				suckers_delay_seconds,
			])
		status_requested.emit("SUCKERS — surviving roots throw shoots back into the wound.")
		_notify_triggered(PhaseBRelicCatalog.Id.SUCKERS)
	for index in range(_pending_suckers.size() - 1, -1, -1):
		var shoot: Array = _pending_suckers[index]
		shoot[1] = float(shoot[1]) - delta
		if float(shoot[1]) > 0.0:
			continue
		_pending_suckers.remove_at(index)
		var site: Vector2 = shoot[0]
		if not territory_field.is_claimable_at_local(site):
			continue
		territory_field.queue_seed_growth(
			site,
			suckers_mass,
			0.25,
			progression.get_conversion_multiplier(),
			1.0
		)


func notify_amplified_event(local_position: Vector2, amplification: float) -> void:
	## A natural Adaptation event that actually drew on Mature Green. Relic-generated
	## echoes may still be amplified, but they never advance this: the relic pays out
	## on what the player's own play is doing.
	if not has(PhaseBRelicCatalog.Id.FEEDER_ROOTS) or _repeating:
		return
	if amplification <= 1.0:
		return
	if territory_field.get_maturity_at_local(local_position) < feeder_roots_source_maturity:
		return
	if _feeder_cooldown > 0.0:
		return
	_feeder_events += 1
	if _feeder_events < feeder_roots_events:
		return
	_feeder_events = 0
	_feeder_cooldown = feeder_roots_cooldown_seconds
	# Aim at the least established owned ground in range: the network feeds its own
	# frontier rather than thickening what is already deep.
	var target := territory_field.find_player_frontier_near(local_position)
	if target.x < 0.0 or target.distance_to(local_position) > feeder_roots_range_pixels:
		return
	territory_field.queue_maturity_support(
		target,
		feeder_roots_maturity_granted,
		feeder_roots_radius_pixels / 48.0
	)
	territory_field.queue_seed_growth(
		target,
		feeder_roots_control,
		feeder_roots_control,
		progression.get_conversion_multiplier(),
		1.0
	)
	overlay.spawn_relic_cue(
		TerritoryPrototypeOverlay.RelicCue.TRAVELLING,
		local_position,
		local_position.distance_to(target),
		Color("6fd7a0"),
		local_position.direction_to(target),
		false,
		1.0,
		TerritoryPrototypeOverlay.RelicMotif.PARTICLE
	)
	status_requested.emit("FEEDER ROOTS — the network feeds its own frontier.")
	_notify_triggered(PhaseBRelicCatalog.Id.FEEDER_ROOTS)


func _advance_graft_union(delta: float) -> void:
	_graft_cooldown = maxf(0.0, _graft_cooldown - delta)
	if _graft_armed > 0.0:
		_graft_armed = maxf(0.0, _graft_armed - delta)
	if not has(PhaseBRelicCatalog.Id.GRAFT_UNION):
		_graft_components = 0
		_graft_split_seconds = 0.0
		return
	var components := _cached_component_count
	if components > 1:
		_graft_split_seconds += delta
		_graft_components = components
		return
	if _graft_components > 1 and _graft_split_seconds >= graft_union_separation_seconds:
		# Two established networks that were apart long enough have just rejoined.
		var join := player.get_arena_position()
		if _graft_cooldown <= 0.0:
			_graft_cooldown = graft_union_cooldown_seconds
			_graft_armed = graft_union_armed_seconds
			_graft_position = join
			territory_field.queue_maturity_support(
				join,
				graft_union_maturity_granted,
				graft_union_radius_pixels / 48.0
			)
			overlay.spawn_reconnection_pulse(join)
			status_requested.emit("GRAFT UNION — the two networks knit back together.")
			_notify_triggered(PhaseBRelicCatalog.Id.GRAFT_UNION)
	_graft_components = components
	_graft_split_seconds = 0.0


func is_graft_union_armed() -> bool:
	return _graft_armed > 0.0


func consume_graft_union() -> float:
	## Spent by the first eligible natural Adaptation event near either endpoint.
	if _graft_armed <= 0.0:
		return 0.0
	_graft_armed = 0.0
	return graft_union_strength


func _advance_rhizome(delta: float) -> void:
	_rhizome_cooldown = maxf(0.0, _rhizome_cooldown - delta)
	if not has(PhaseBRelicCatalog.Id.RHIZOME):
		_rhizome_survived = 0.0
		_rhizome_growing = 0.0
		return
	if _rhizome_growing > 0.0:
		# The runner grows along its route over real time rather than snapping into
		# place, so the player can see the organism reaching back for itself.
		_rhizome_growing = maxf(0.0, _rhizome_growing - delta)
		var progress := 1.0 - _rhizome_growing / maxf(0.01, rhizome_growth_seconds)
		if _rhizome_route.size() == 2:
			var along := _rhizome_route[0].lerp(_rhizome_route[1], progress)
			if territory_field.is_claimable_at_local(along):
				territory_field.queue_seed_growth(
					along,
					0.05,
					rhizome_corridor_maturity,
					progression.get_conversion_multiplier(),
					0.6
				)
		if _rhizome_growing <= 0.0 and _rhizome_route.size() == 2:
			for endpoint in _rhizome_route:
				territory_field.queue_maturity_support(
					endpoint,
					rhizome_pulse_maturity,
					rhizome_pulse_pixels / 48.0
				)
				overlay.spawn_reconnection_pulse(endpoint)
			# A Rhizome connection is a reconnection, so it qualifies for Graft Union.
			if has(PhaseBRelicCatalog.Id.GRAFT_UNION) and _graft_cooldown <= 0.0:
				_graft_cooldown = graft_union_cooldown_seconds
				_graft_armed = graft_union_armed_seconds
				_graft_position = _rhizome_route[1]
			_rhizome_route = PackedVector2Array()
			status_requested.emit("RHIZOME — the colony is back on the network.")
			_notify_triggered(PhaseBRelicCatalog.Id.RHIZOME)
		return
	if _rhizome_cooldown > 0.0:
		return
	var colony := _cached_isolated_colony
	if colony.x < 0.0:
		_rhizome_survived = 0.0
		return
	_rhizome_survived += delta
	if _rhizome_survived < rhizome_survival_seconds:
		return
	var home := territory_field.find_player_frontier_near(colony)
	if home.x < 0.0 or home.distance_to(colony) > rhizome_maximum_distance:
		# No route home worth growing. Retried rather than charged for.
		_rhizome_survived = maxf(0.0, _rhizome_survived - 3.0)
		return
	_rhizome_survived = 0.0
	_rhizome_cooldown = rhizome_cooldown_seconds
	_rhizome_growing = rhizome_growth_seconds
	_rhizome_route = PackedVector2Array([colony, home])


func _find_ancient_site(
	excluded: PackedVector2Array = PackedVector2Array(),
	exclusion_radius_pixels: float = 110.0
) -> Vector2:
	## The Shared Ancient Territory placement rule, asked from one place so Taproot,
	## Annual Rings and the World Tree cannot drift apart on where they establish.
	# Near Grandma first, then the wider ring, then anywhere. Within each band the
	# oldest region wins, and placement is that region's own central cell. Reading
	# from the cached list, so choosing costs nothing on the frames between samples.
	var anchor := player.get_arena_position()
	var near := _pick_ancient_region(
		anchor, ancient_search_pixels, excluded, exclusion_radius_pixels, false
	)
	if near.x >= 0.0:
		return near
	var expanded := _pick_ancient_region(
		anchor, ancient_expanded_search_pixels, excluded, exclusion_radius_pixels, false
	)
	if expanded.x >= 0.0:
		return expanded
	# Last resort takes the nearest qualifying region rather than the oldest: at
	# this range, being reachable matters more than being ancient.
	return _pick_ancient_region(anchor, INF, excluded, exclusion_radius_pixels, true)


func _pick_ancient_region(
	anchor: Vector2,
	radius_pixels: float,
	excluded: PackedVector2Array,
	exclusion_radius_pixels: float,
	prefer_nearest: bool
) -> Vector2:
	var radius_squared := radius_pixels * radius_pixels
	var exclusion_squared := exclusion_radius_pixels * exclusion_radius_pixels
	var best := INVALID_POSITION
	var best_score := -INF
	for region in _cached_ancient_regions:
		var centre: Vector2 = region[0]
		var distance_squared := centre.distance_squared_to(anchor)
		if distance_squared > radius_squared:
			continue
		var already_tracked := false
		for taken in excluded:
			if taken.distance_squared_to(centre) <= exclusion_squared:
				already_tracked = true
				break
		if already_tracked:
			continue
		var score := -distance_squared if prefer_nearest else float(region[1])
		if score > best_score:
			best_score = score
			best = centre
	return best


func _advance_taproot(delta: float) -> void:
	if not has(PhaseBRelicCatalog.Id.TAPROOT):
		_taproot.active = false
		return
	if _taproot.active:
		# The Taproot dies with the ground holding it up, and another can form.
		if not territory_field.is_mature_player_territory_at_local(_taproot.position):
			_taproot.active = false
		else:
			_taproot.timer -= delta
			if _taproot.timer <= 0.0:
				_taproot.timer = taproot_interval_seconds
				territory_field.queue_seed_growth(
					_taproot.position,
					taproot_mass,
					0.15,
					progression.get_conversion_multiplier(),
					taproot_radius
				)
				_notify_triggered(PhaseBRelicCatalog.Id.TAPROOT)
			return
	# Anchored on Grandma rather than on the map: a Taproot the player never sees
	# is a Taproot they never defend.
	var site := _find_ancient_site()
	if site.x < 0.0:
		return
	_taproot.active = true
	_taproot.position = site
	_taproot.timer = taproot_interval_seconds
	status_requested.emit("TAPROOT — the oldest ground puts down a repair root.")


func _advance_annual_rings(delta: float) -> void:
	if not has(PhaseBRelicCatalog.Id.ANNUAL_RINGS):
		if not _ring_regions.is_empty():
			_ring_regions.clear()
		return
	for index in range(_ring_regions.size() - 1, -1, -1):
		var region := _ring_regions[index]
		if not territory_field.is_mature_player_territory_at_local(region.position):
			# A region that stops being Mature loses everything it had banked.
			_ring_regions.remove_at(index)
			continue
		region.survived += delta
		if (
			region.rings < annual_rings_maximum
			and region.survived >= annual_rings_interval_seconds * float(region.rings + 1)
		):
			region.rings += 1
			status_requested.emit(
				"ANNUAL RINGS — a Mature region reaches %d ring(s)." % region.rings
			)
			_notify_triggered(PhaseBRelicCatalog.Id.ANNUAL_RINGS)
	if _ring_regions.size() >= annual_rings_regions:
		return
	var tracked := PackedVector2Array()
	for region in _ring_regions:
		tracked.append(region.position)
	var site := _find_ancient_site(tracked, annual_rings_radius_pixels)
	if site.x < 0.0:
		return
	var fresh := RingRegion.new()
	fresh.position = site
	_ring_regions.append(fresh)


func get_root_potency_bonus_at(local_position: Vector2) -> float:
	# Published for the Root path to fold into its own amplification, so a
	# mechanic acting inside a ringed region is stronger there without every
	# consumer having to know the relic exists.
	var bonus := 0.0
	for region in _ring_regions:
		if region.position.distance_to(local_position) <= annual_rings_radius_pixels:
			bonus += annual_rings_potency * float(region.rings)
	return bonus


func _advance_world_tree(delta: float) -> void:
	if not has(PhaseBRelicCatalog.Id.WORLD_TREE):
		_world_tree.active = false
		return
	if _world_tree.active:
		if not territory_field.is_mature_player_territory_at_local(_world_tree.position):
			_world_tree.active = false
			_world_tree.timer = world_tree_reform_seconds
			status_requested.emit("WORLD TREE — its Green was taken; the Tree dies.")
			return
		_world_tree.charge = minf(
			world_tree_interval_seconds,
			_world_tree.charge + delta
		)
		return
	_world_tree.timer = maxf(0.0, _world_tree.timer - delta)
	if _world_tree.timer > 0.0:
		return
	var site := _find_ancient_site()
	if site.x < 0.0:
		return
	_world_tree.active = true
	_world_tree.position = site
	_world_tree.charge = 0.0
	status_requested.emit("WORLD TREE — the oldest ground raises a World Tree.")


func _try_world_tree_echo(local_position: Vector2, is_bloom: bool) -> void:
	# One charge, spent on the next eligible Plant event that starts on Mature
	# ground. The echo is reduced and cannot itself be echoed.
	if not _world_tree.active or _world_tree.charge < world_tree_interval_seconds:
		return
	if not territory_field.is_mature_player_territory_at_local(local_position):
		return
	_world_tree.charge = 0.0
	if is_bloom:
		territory_field.queue_bloom(
			local_position,
			0.0,
			world_tree_echo_strength,
			progression.get_conversion_multiplier(),
			world_tree_echo_strength
		)
	else:
		territory_field.queue_seed_growth(
			local_position,
			world_tree_echo_strength,
			world_tree_echo_strength * 0.4,
			progression.get_conversion_multiplier(),
			world_tree_echo_strength
		)
	overlay.spawn_bloom(local_position)
	_notify_triggered(PhaseBRelicCatalog.Id.WORLD_TREE)


func _advance_perennial(delta: float) -> void:
	if not _perennial.active:
		return
	if not has(PhaseBRelicCatalog.Id.PERENNIAL):
		_perennial.active = false
		return
	_perennial.timer -= delta
	if _perennial.timer > 0.0:
		return
	_perennial.stage += 1
	_perennial.timer = perennial_interval_seconds
	if _perennial.stage > perennial_reblooms:
		_perennial.active = false
		return
	if not territory_field.is_claimable_at_local(_perennial.position):
		_perennial.active = false
		return
	# A re-bloom is Force only. It must never become a second source of Mass.
	territory_field.queue_bloom(
		_perennial.position,
		0.0,
		perennial_force,
		progression.get_conversion_multiplier(),
		1.0
	)
	overlay.spawn_bloom(_perennial.position)
	status_requested.emit("PERENNIAL — the flower opens again.")
	_notify_triggered(PhaseBRelicCatalog.Id.PERENNIAL)


func _advance_generated_events(delta: float) -> void:
	## The global scheduler. Events past the per-frame budget are staggered into
	## later frames rather than dropped, because a relic effect the player earned
	## has to happen. Only a full queue drops anything, and then the rarest survive.
	for index in range(_generated_events.size() - 1, -1, -1):
		var event: Array = _generated_events[index]
		event[3] = float(event[3]) - delta
		if float(event[3]) > 0.0:
			continue
		if _generated_this_frame >= generated_events_per_frame:
			event[3] = generated_event_stagger_seconds
			_generated_staggered += 1
			continue
		_generated_events.remove_at(index)
		_generated_this_frame += 1
		_repeating = true
		# A repeat is drawn as a ghost of the effect it copies: recognisably the same
		# thing, unmistakably the weaker one.
		overlay.spawn_relic_cue(
			TerritoryPrototypeOverlay.RelicCue.GHOST,
			event[1],
			48.0,
			Color("cfe8a0"),
			Vector2.ZERO,
			true,
			float(event[2]),
			TerritoryPrototypeOverlay.RelicMotif.RING
		)
		_resolve_generated_event(int(event[0]), event[1], float(event[2]))
		_repeating = false


func get_generated_queue_depth() -> int:
	return _generated_events.size()


func get_generated_peak_depth() -> int:
	return _generated_peak_depth


func get_generated_staggered_count() -> int:
	return _generated_staggered


func get_generated_dropped_count() -> int:
	return _generated_dropped


func _queue_generated_event(
	relic_id: int,
	position: Vector2,
	strength: float,
	delay: float
) -> bool:
	if _generated_events.size() >= generated_event_queue_maximum:
		# Full. Displace the least rare queued event rather than refusing the new
		# one outright, so a Legendary is never lost to a backlog of Commons.
		var weakest := -1
		var weakest_rarity := PhaseBRelicCatalog.get_rarity(relic_id)
		for index in range(_generated_events.size()):
			var queued_rarity := PhaseBRelicCatalog.get_rarity(int(_generated_events[index][0]))
			if queued_rarity < weakest_rarity:
				weakest_rarity = queued_rarity
				weakest = index
		if weakest < 0:
			_generated_dropped += 1
			return false
		_generated_events.remove_at(weakest)
		_generated_dropped += 1
	_generated_events.append([relic_id, position, strength, maxf(0.0, delay)])
	_generated_peak_depth = maxi(_generated_peak_depth, _generated_events.size())
	return true


func _resolve_generated_event(relic_id: int, position: Vector2, strength: float) -> void:
	# A repeat of an effect that is a discrete burst. Relics that stand a permanent
	# object up are deliberately absent: a repeat must never duplicate one.
	match relic_id:
		PhaseBRelicCatalog.Id.GARDEN_HOSE:
			_spray_garden_hose(position, strength)
		PhaseBRelicCatalog.Id.MIMOSA:
			_snap_mimosa(position, strength)
		PhaseBRelicCatalog.Id.COMPOST_HEAP:
			_erupt_compost(position, strength)
		PhaseBRelicCatalog.Id.SNARE_VINE:
			combat.apply_entanglement_in_radius(
				position,
				snare_vine_radius_pixels,
				snare_vine_entanglement * strength
			)
		PhaseBRelicCatalog.Id.CROSS_POLLINATION:
			overlay.advance_seeds_in_radius(
				position,
				cross_pollination_radius_pixels,
				cross_pollination_progress * strength,
				0,
				germination_grant_cooldown_seconds
			)
		_:
			return
	status_requested.emit(
		"HYBRID VIGOR — %s fires again, weaker."
			% PhaseBRelicCatalog.get_relic_name(relic_id)
	)


func _advance_garden_hose() -> void:
	# Distance across owned Green only. The counter pauses off Green and resumes on
	# it, and a teleport or a correction must never bank a spray, so an
	# implausibly large step is treated as a jump and skipped rather than counted.
	if not has(PhaseBRelicCatalog.Id.GARDEN_HOSE):
		_garden_hose_last_position = INVALID_POSITION
		return
	var origin := player.get_arena_position()
	if _garden_hose_last_position.x < 0.0:
		_garden_hose_last_position = origin
		return
	var step := origin.distance_to(_garden_hose_last_position)
	var previous := _garden_hose_last_position
	_garden_hose_last_position = origin
	if step > 80.0:
		return
	if territory_field.get_control_at_local(previous) <= territory_field.tuning.ownership_threshold:
		return
	_garden_hose_travel += step
	if _garden_hose_travel < garden_hose_travel_pixels:
		return
	# Reset only when the spray actually fires, so a blocked spray does not cost
	# the player the distance they walked for it.
	_garden_hose_travel = 0.0
	_spray_garden_hose(origin, 1.0)
	_notify_triggered(PhaseBRelicCatalog.Id.GARDEN_HOSE)


func _spray_garden_hose(origin: Vector2, strength: float) -> void:
	var facing := player.get_facing_direction()
	if facing.length_squared() <= 0.0001:
		facing = Vector2.RIGHT
	var sprayed := 0
	for index in range(garden_hose_projectiles):
		var progress := (
			0.5
			if garden_hose_projectiles <= 1
			else float(index) / float(garden_hose_projectiles - 1)
		)
		var angle := deg_to_rad(lerpf(
			-garden_hose_arc_degrees * 0.5,
			garden_hose_arc_degrees * 0.5,
			progress
		))
		var site := origin + facing.rotated(angle) * garden_hose_range_pixels
		if not territory_field.is_claimable_at_local(site):
			continue
		if not territory_field.is_growth_path_clear(origin, site):
			continue
		# Fresh Green only. The spray creates territory; it never grants maturity.
		territory_field.queue_seed_growth(
			site,
			garden_hose_mass_per_projectile * strength,
			0.0,
			progression.get_conversion_multiplier(),
			1.0
		)
		sprayed += 1
	if sprayed > 0:
		# Five separated streams rather than a fog cone, kept low to the ground so it
		# does not sit on top of the enemies the player is reading.
		overlay.spawn_relic_cue(
			TerritoryPrototypeOverlay.RelicCue.SPRAY,
			origin,
			garden_hose_range_pixels,
			Color("9cff63"),
			facing,
			not is_equal_approx(strength, 1.0),
			strength,
			TerritoryPrototypeOverlay.RelicMotif.PARTICLE
		)
		status_requested.emit("GARDEN HOSE — a fan of fresh Green sprays ahead.")


func notify_green_eaten(enemy_id: int, mass: float, _seconds: float = 0.0) -> void:
	## Reported by whatever erases Green on an enemy's behalf. Only what the enemy
	## itself destroys is stored: Green given up to Pruning or wagered on Clover is
	## the player's own doing and must never come back as fertiliser.
	if not has(PhaseBRelicCatalog.Id.MULCH) or mass <= 0.0:
		return
	var stored := float(_mulch_stores.get(enemy_id, 0.0))
	_mulch_stores[enemy_id] = minf(
		stored + mass * mulch_stored_share, mulch_maximum_store
	)


func _release_mulch(enemy_id: int, local_position: Vector2) -> void:
	if not _mulch_stores.has(enemy_id):
		return
	var stored := float(_mulch_stores[enemy_id])
	# One release per enemy, whatever else happens to the corpse.
	_mulch_stores.erase(enemy_id)
	if stored < mulch_minimum_store:
		return
	var site := local_position
	if not territory_field.is_claimable_at_local(site):
		site = territory_field.find_player_frontier_near(local_position)
		if site.x < 0.0:
			return
	territory_field.queue_seed_growth(
		site,
		stored,
		0.0,
		progression.get_conversion_multiplier(),
		mulch_radius_pixels / 48.0
	)
	overlay.spawn_bloom(site)
	status_requested.emit("MULCH — the stolen growth bursts back out of the corpse.")
	_notify_triggered(PhaseBRelicCatalog.Id.MULCH)


func _snap_mimosa(origin: Vector2, strength: float) -> void:
	# Crowd control, not mitigation: Mimosa deals no damage and converts nothing.
	var pushed := 0
	for enemy_id in combat.get_active_enemy_ids():
		var enemy_position := combat.get_enemy_position(enemy_id)
		if enemy_position.distance_to(origin) > mimosa_radius_pixels:
			continue
		var share := 1.0
		match combat.get_enemy_role(enemy_id):
			PhaseBCombatDirector.EnemyRole.BOSS:
				share = mimosa_boss_share
			PhaseBCombatDirector.EnemyRole.ELITE:
				share = mimosa_elite_share
		combat.knockback_enemy_from(
			enemy_id, origin, mimosa_knockback_pixels * share * strength
		)
		pushed += 1
	if pushed > 0:
		overlay.spawn_relic_cue(
			TerritoryPrototypeOverlay.RelicCue.BITE,
			origin,
			mimosa_radius_pixels,
			Color("8fe86a"),
			Vector2.ZERO,
			not is_equal_approx(strength, 1.0),
			strength
		)
		status_requested.emit("MIMOSA — the Green snaps shut and throws them off.")


func _advance_compost(delta: float) -> void:
	for index in range(_compost_heaps.size() - 1, -1, -1):
		var heap: Array = _compost_heaps[index]
		if float(heap[3]) > 0.0:
			# Already at threshold and swelling. The fuse runs whatever else happens.
			heap[3] = float(heap[3]) - delta
			if float(heap[3]) <= 0.0:
				var heap_position: Vector2 = heap[0]
				_compost_heaps.remove_at(index)
				_erupt_compost(heap_position, 1.0)
				_notify_triggered(PhaseBRelicCatalog.Id.COMPOST_HEAP)
			continue
		heap[2] = float(heap[2]) - delta
		if float(heap[2]) <= 0.0:
			_compost_heaps.remove_at(index)


func _add_compost(local_position: Vector2, amount: int) -> void:
	if not has(PhaseBRelicCatalog.Id.COMPOST_HEAP) or amount <= 0:
		return
	if not territory_field.is_mature_player_territory_at_local(local_position):
		if territory_field.get_control_at_local(local_position) <= territory_field.tuning.ownership_threshold:
			return
	for heap in _compost_heaps:
		if float(heap[3]) > 0.0:
			# A heap at threshold stops accepting until after it goes off.
			continue
		var heap_position: Vector2 = heap[0]
		if heap_position.distance_to(local_position) > compost_merge_pixels:
			continue
		heap[1] = int(heap[1]) + amount
		heap[2] = compost_lifetime_seconds
		if int(heap[1]) >= compost_threshold:
			heap[3] = maxf(0.0001, compost_eruption_delay)
		return
	if _compost_heaps.size() >= compost_maximum_heaps:
		return
	_compost_heaps.append([
		local_position,
		amount,
		compost_lifetime_seconds,
		compost_eruption_delay if amount >= compost_threshold else 0.0,
	])
	# The pile is visible as it grows, so the eruption can be anticipated rather
	# than only recognised after it has happened.
	overlay.spawn_relic_cue(
		TerritoryPrototypeOverlay.RelicCue.HEAP,
		local_position,
		compost_merge_pixels * 0.35,
		Color("8a6b3a"),
		Vector2.ZERO,
		false,
		1.0,
		TerritoryPrototypeOverlay.RelicMotif.GLOW
	)


func _erupt_compost(origin: Vector2, strength: float) -> void:
	combat.damage_enemies_in_radius(
		origin,
		compost_damage_radius * strength,
		compost_damage * strength,
		PhaseBCombatDirector.DeathSource.RELIC
	)
	if territory_field.is_claimable_at_local(origin):
		territory_field.queue_seed_growth(
			origin,
			compost_mass * strength,
			1.0,
			progression.get_conversion_multiplier(),
			1.4
		)
		territory_field.queue_maturity_support(origin, compost_mass * strength, 1.2)
	overlay.spawn_bloom(origin)
	status_requested.emit("COMPOST HEAP — the pile erupts into deep new Green.")


func get_compost_heap_count() -> int:
	return _compost_heaps.size()


func get_mulch_store(enemy_id: int) -> float:
	return float(_mulch_stores.get(enemy_id, 0.0))


func notify_green_created(mass: float) -> void:
	## Miracle-Gro banks new owned Green until it can make one Adaptation event
	## happen twice. Control recovered on Green the run already owned does not
	## count: the relic is paid for by expansion, not by holding ground.
	if not has(PhaseBRelicCatalog.Id.MIRACLE_GRO) or mass <= 0.0:
		return
	if _miracle_gro_charged or _repeating:
		return
	_miracle_gro_banked += mass
	if _miracle_gro_banked < miracle_gro_required_mass:
		return
	_miracle_gro_banked = 0.0
	_miracle_gro_charged = true
	status_requested.emit("MIRACLE-GRO — the next Adaptation event is primed to repeat.")


func is_miracle_gro_charged() -> bool:
	return _miracle_gro_charged


func consume_miracle_gro() -> float:
	## Spent by the first eligible natural or Evolution Adaptation event. Returns the
	## strength of the repeat, or zero when nothing is stored.
	if not _miracle_gro_charged:
		return 0.0
	_miracle_gro_charged = false
	return miracle_gro_strength


func is_grafting_tape_ready() -> bool:
	return has(PhaseBRelicCatalog.Id.GRAFTING_TAPE) and _grafting_tape_cooldown <= 0.0


func consume_grafting_tape() -> float:
	## The paired Adaptation answers with its own core event. The cooldown begins
	## when the echo fires rather than when the source event did.
	if not is_grafting_tape_ready():
		return 0.0
	_grafting_tape_cooldown = grafting_tape_cooldown_seconds
	status_requested.emit("GRAFTING TAPE — the other Adaptation answers.")
	return grafting_tape_strength


func _notify_triggered(relic_id: int) -> void:
	relic_triggered.emit(relic_id)
	_try_hybrid_vigor(relic_id)


func _try_hybrid_vigor(relic_id: int) -> void:
	# A repeat can never roll another repeat, and Hybrid Vigor never repeats itself.
	if _repeating or not has(PhaseBRelicCatalog.Id.HYBRID_VIGOR):
		return
	if relic_id == PhaseBRelicCatalog.Id.HYBRID_VIGOR:
		return
	if _hybrid_vigor_window.size() >= hybrid_vigor_window_maximum:
		return
	if _relic_random.randf() >= hybrid_vigor_chance:
		return
	if not _queue_generated_event(
		relic_id,
		player.get_arena_position(),
		hybrid_vigor_strength,
		hybrid_vigor_delay_seconds
	):
		return
	_hybrid_vigor_window.append(1.0)


func _on_player_damage_taken(_amount: float) -> void:
	if not has(PhaseBRelicCatalog.Id.MIMOSA) or _mimosa_cooldown > 0.0:
		return
	var origin := player.get_arena_position()
	# The check is on where Grandma is standing at the moment the damage resolves.
	if territory_field.get_control_at_local(origin) <= territory_field.tuning.ownership_threshold:
		return
	_mimosa_cooldown = mimosa_cooldown_seconds
	_snap_mimosa(origin, 1.0)
	_notify_triggered(PhaseBRelicCatalog.Id.MIMOSA)


func _on_enemy_killed(
	local_position: Vector2,
	_xp_value: int,
	role: int,
	_death_source: int,
	_chain_depth: int
) -> void:
	_release_mulch(combat.get_last_killed_enemy_id(), local_position)
	var compost := 1
	if role == PhaseBCombatDirector.EnemyRole.BOSS:
		compost = 5
	elif role == PhaseBCombatDirector.EnemyRole.ELITE:
		compost = 2
	_add_compost(local_position, compost)
	_try_trigger_hedge()


func _on_enemy_rooted(local_position: Vector2) -> void:
	if not has(PhaseBRelicCatalog.Id.SNARE_VINE):
		return
	var spread := combat.spread_entanglement_from(
		local_position,
		snare_vine_radius_pixels,
		snare_vine_entanglement,
		snare_vine_targets
	)
	if spread > 0:
		_notify_triggered(PhaseBRelicCatalog.Id.SNARE_VINE)


func _on_seed_germinated(local_position: Vector2, _chain_depth: int) -> void:
	if has(PhaseBRelicCatalog.Id.CROSS_POLLINATION):
		var advanced := overlay.advance_seeds_in_radius(
			local_position,
			cross_pollination_radius_pixels,
			cross_pollination_progress,
			0,
			germination_grant_cooldown_seconds
		)
		if advanced > 0:
			_notify_triggered(PhaseBRelicCatalog.Id.CROSS_POLLINATION)
	_try_world_tree_echo(local_position, false)


func _on_bloom_detonated(
	local_position: Vector2,
	_chain_depth: int,
	_source_tag: int = 0,
	_strength: float = 1.0
) -> void:
	_try_superbloom(local_position)
	_try_arm_perennial(local_position)
	_try_world_tree_echo(local_position, true)


func _try_superbloom(local_position: Vector2) -> void:
	if not has(PhaseBRelicCatalog.Id.SUPERBLOOM):
		return
	if _superbloom_cooldown <= 0.0:
		for entry in _recent_blooms:
			var other: Vector2 = entry[0]
			if other.distance_to(local_position) > superbloom_overlap_pixels:
				continue
			_superbloom_cooldown = superbloom_cooldown_seconds
			var midpoint := other.lerp(local_position, 0.5)
			# Force only. The secondary wave creates no Plant Mass of its own.
			territory_field.queue_bloom(
				midpoint,
				0.0,
				superbloom_force,
				progression.get_conversion_multiplier(),
				1.0
			)
			overlay.spawn_bloom(midpoint)
			status_requested.emit("SUPERBLOOM — two waves collide into a third.")
			_notify_triggered(PhaseBRelicCatalog.Id.SUPERBLOOM)
			break
	_recent_blooms.append([local_position, superbloom_memory_seconds])


func _try_arm_perennial(local_position: Vector2) -> void:
	if not _perennial_armed:
		return
	_perennial_armed = false
	_perennial.active = true
	_perennial.position = local_position
	_perennial.timer = perennial_interval_seconds
	_perennial.stage = 0
	status_requested.emit("PERENNIAL — this wave's first Bloom takes root.")




func get_relic_counter_text(relic_id: int) -> String:
	# A triggered relic needs to show its counter somewhere, so the slot row can
	# read out how close the next activation is.
	match relic_id:
		PhaseBRelicCatalog.Id.ANNUAL_RINGS:
			var rings := 0
			for region in _ring_regions:
				rings = maxi(rings, region.rings)
			return "%d / %d" % [rings, annual_rings_maximum]
		PhaseBRelicCatalog.Id.THE_HEDGE:
			if _hedge_cooldown > 0.0:
				return "%.0fs" % _hedge_cooldown
			return "READY"
		PhaseBRelicCatalog.Id.SUPERBLOOM:
			if _superbloom_cooldown > 0.0:
				return "%.0fs" % _superbloom_cooldown
			return "READY"
		PhaseBRelicCatalog.Id.WORLD_TREE:
			if not _world_tree.active:
				return "GONE"
			if _world_tree.charge >= world_tree_interval_seconds:
				return "READY"
			return "%.0fs" % (world_tree_interval_seconds - _world_tree.charge)
	return ""


func is_taproot_active() -> bool:
	return _taproot.active


func is_world_tree_active() -> bool:
	return _world_tree.active


func get_ring_region_count() -> int:
	return _ring_regions.size()


func is_sweep_active() -> bool:
	return _sweep.active


func is_rampart_active() -> bool:
	return _rampart_remaining > 0.0


func get_perennial_reblooms_left() -> int:
	if not _perennial.active:
		return 0
	return maxi(0, perennial_reblooms - _perennial.stage)


func _draw() -> void:
	# Persistent relic objects need a world marker, so the player can see what the
	# relic actually put on the battlefield and defend it.
	if _taproot.active:
		_draw_marker(_taproot.position, Color("8fe86a"), 9.0, 5)
	if _world_tree.active:
		var ready := _world_tree.charge >= world_tree_interval_seconds
		_draw_marker(
			_world_tree.position,
			Color("ffd24a") if ready else Color("b58a3a"),
			14.0,
			6
		)
	for region in _ring_regions:
		for ring in range(region.rings):
			draw_arc(
				region.position,
				annual_rings_radius_pixels * (0.45 + 0.22 * float(ring)),
				0.0,
				TAU,
				40,
				Color(0.66, 0.86, 0.45, 0.30),
				1.5,
				true
			)
	if _rampart_remaining > 0.0 and _rampart_position.x >= 0.0:
		draw_arc(
			_rampart_position,
			living_rampart_radius_pixels,
			0.0,
			TAU,
			44,
			Color(0.85, 0.45, 0.95, 0.34),
			2.0,
			true
		)
	if _sweep.active:
		draw_arc(
			_sweep.origin,
			_sweep.radius,
			0.0,
			TAU,
			64,
			Color(0.62, 1.0, 0.48, 0.55),
			3.0,
			true
		)


func _draw_marker(position: Vector2, color: Color, radius: float, points: int) -> void:
	draw_circle(position, radius + 4.0, Color(color, 0.18), true, -1.0, true)
	var outline := PackedVector2Array()
	for index in range(points):
		var angle := -PI * 0.5 + TAU * float(index) / float(points)
		outline.append(position + Vector2.from_angle(angle) * radius)
	outline.append(outline[0])
	draw_polyline(outline, color, 2.0, true)
