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

@export_group("Universal")
## Core Weapon volleys between Predator's Eye's extra target.
@export_range(2, 40, 1) var predators_eye_interval := 10
## Seconds a Follow Through pierce bonus stays armed after a kill.
@export_range(0.1, 10.0, 0.1) var follow_through_seconds := 2.0
## Core Weapon attacks sped up by one Adrenal Response trigger.
@export_range(1, 10, 1) var adrenal_response_charges := 3
## Cooldown multiplier applied to those attacks; lower fires faster.
@export_range(0.1, 1.0, 0.01) var adrenal_response_multiplier := 0.55
## Internal cooldown before Adrenal Response can trigger again.
@export_range(0.0, 30.0, 0.5) var adrenal_response_cooldown := 6.0
## Player health restored by Clean Finish.
@export_range(0.0, 100.0, 1.0) var clean_finish_health := 8.0
## Kills that must land inside the window to prime Overpopulation.
@export_range(2, 20, 1) var overpopulation_kills := 6
## Window in seconds those kills must fall inside.
@export_range(0.2, 10.0, 0.1) var overpopulation_window_seconds := 2.0
## Radius in pixels of the primed explosion.
@export_range(10.0, 300.0, 5.0) var overpopulation_radius_pixels := 82.0
## Damage dealt at the centre of the primed explosion.
@export_range(1.0, 500.0, 1.0) var overpopulation_damage := 70.0
## Owned territory cells that must be lost inside the window for Last Bastion and
## Resurrection Fern to fire. An absolute cell count, never an arena percentage.
@export_range(1, 2000, 1) var territory_emergency_cells := 130
## Seconds the territory-loss window covers.
@export_range(0.2, 10.0, 0.1) var territory_emergency_window_seconds := 2.0
## Seconds Last Bastion's emergency buff lasts.
@export_range(0.5, 30.0, 0.5) var last_bastion_seconds := 6.0
## Movement-speed multiplier granted by Last Bastion.
@export_range(1.0, 3.0, 0.05) var last_bastion_speed_multiplier := 1.35
## Core Weapon cooldown multiplier granted by Last Bastion; lower fires faster.
@export_range(0.1, 1.0, 0.01) var last_bastion_attack_multiplier := 0.65
## Health fraction below which Blood in the Water prioritises an enemy.
@export_range(0.05, 0.9, 0.01) var blood_in_the_water_threshold := 0.20
## Biomass an elite kill drops under Salvage Rights.
@export_range(1.0, 400.0, 1.0) var salvage_rights_biomass := 26.0
## Enemies that must be near the player for Underdog's extra target.
@export_range(2, 40, 1) var underdog_enemy_count := 8
## Radius in pixels Underdog counts enemies inside.
@export_range(40.0, 600.0, 5.0) var underdog_radius_pixels := 190.0
## Non-Legendary relic triggers between Encore repeats.
@export_range(2, 12, 1) var encore_interval := 3
## Delay in seconds before an Encore repeat plays out.
@export_range(0.05, 5.0, 0.05) var encore_delay_seconds := 0.55
## Strength multiplier applied to an Encore repeat.
@export_range(0.05, 1.0, 0.01) var encore_strength := 0.50

@export_group("Plant Element")
## Radius in pixels at which walking past a Seed advances it under Green Thumb.
@export_range(10.0, 200.0, 2.0) var green_thumb_radius_pixels := 46.0
## Germination progress one Green Thumb touch grants.
@export_range(0.05, 1.0, 0.01) var green_thumb_progress := 0.35
## Seconds recently lost Green stays remembered under Regrowth.
@export_range(0.5, 60.0, 0.5) var regrowth_memory_seconds := 7.0
## Control per second remembered ground reclaims while uncontested.
@export_range(0.0, 2.0, 0.01) var regrowth_per_second := 0.34
## Kills on Mature Green between Compost payouts.
@export_range(1, 60, 1) var compost_kills := 12
## Biomass one Compost payout is worth.
@export_range(1.0, 200.0, 1.0) var compost_biomass := 14.0
## Fraction of an incoming hit Canopy absorbs on Mature Green.
@export_range(0.05, 0.95, 0.01) var canopy_absorption := 0.45
## Seconds before Canopy can absorb again.
@export_range(0.5, 30.0, 0.5) var canopy_cooldown_seconds := 8.0
## Recovery pulses Resurrection Fern releases from Mature ground.
@export_range(1, 12, 1) var resurrection_fern_pulses := 4
## Mass multiplier of one Resurrection Fern recovery pulse.
@export_range(0.1, 4.0, 0.05) var resurrection_fern_mass := 1.10
## Kills before the World Seed appears.
@export_range(10, 600, 5) var world_seed_kills := 120
## Seconds the World Seed spends germinating, during which it can be disrupted.
@export_range(1.0, 30.0, 0.5) var world_seed_charge_seconds := 7.0
## Damage the World Seed can absorb before a Saboteur destroys it.
@export_range(1.0, 200.0, 1.0) var world_seed_durability := 24.0
## Mass multiplier of the growth event a surviving World Seed creates.
@export_range(1.0, 20.0, 0.5) var world_seed_mass := 7.0
## Radius multiplier of that growth event.
@export_range(1.0, 12.0, 0.5) var world_seed_radius := 4.0

@export_group("Spore")
## Interruptions each Seed shrugs off under Hard Husk.
@export_range(1, 5, 1) var hard_husk_charges := 1
## Germination progress Cross-Pollination grants nearby Seeds.
@export_range(0.05, 1.0, 0.01) var cross_pollination_progress := 0.25
## Radius in pixels Cross-Pollination reaches.
@export_range(20.0, 600.0, 5.0) var cross_pollination_radius_pixels := 165.0
## Seconds a Seed cannot receive relic germination progress again.
@export_range(0.0, 10.0, 0.05) var germination_grant_cooldown_seconds := 0.85
## Extra interruptions Patient Zero shrugs off.
@export_range(1, 5, 1) var patient_zero_charges := 1
## Germination progress Patient Zero grants every other Seed when it opens.
@export_range(0.05, 1.0, 0.01) var patient_zero_progress := 0.35

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
## Pixels per second the Sweep front travels.
@export_range(50.0, 2000.0, 10.0) var hedge_sweep_speed := 620.0
## Global cooldown in seconds between Briar Sweeps.
@export_range(1.0, 60.0, 0.5) var hedge_cooldown_seconds := 10.0

@export_group("Root")
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

@export_group("Synergies")
## Seeds one Bloom advances under Pollinator.
@export_range(1, 8, 1) var pollinator_seeds := 3
## Germination progress Pollinator grants each of them.
@export_range(0.05, 1.0, 0.01) var pollinator_progress := 0.25
## Seconds a Seedbed Root Node extends Root Potency into new Green.
@export_range(1.0, 60.0, 0.5) var seedbed_seconds := 9.0
## Root Potency a Seedbed node supplies inside its patch.
@export_range(0.01, 2.0, 0.01) var seedbed_potency := 0.30
## Radius in pixels of a Seedbed node.
@export_range(20.0, 400.0, 5.0) var seedbed_radius_pixels := 96.0
## Seconds newly pushed Green ensnares faster under Tangled Wake.
@export_range(0.5, 20.0, 0.5) var tangled_wake_seconds := 3.0
## Ensnare-rate bonus inside a Tangled Wake.
@export_range(0.1, 6.0, 0.05) var tangled_wake_bonus := 2.20
## Entanglement-decay multiplier on Mature Green under Deep Snare.
@export_range(0.0, 1.0, 0.01) var deep_snare_decay_multiplier := 0.18

var _wave_number := 0
var _kill_times := PackedFloat64Array()
var _overpopulation_primed := false
var _adrenal_cooldown := 0.0
var _clean_finish_used_this_wave := false
var _last_bastion_used_this_wave := false
var _resurrection_fern_used_this_wave := false
var _last_bastion_remaining := 0.0
var _territory_history := PackedInt32Array()
var _territory_sample_remaining := 0.0
var _encore_counter := 0
var _encore_queue: Array = []
var _encore_repeating := false

var _compost_kills := 0
var _total_kills := 0
var _world_seed := WorldObject.new()
var _world_seed_id := -1
var _green_thumb_used := {}

var _patient_zero_id := -1
var _patient_zero_armed := false

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
var _seedbed_nodes: Array = []

var _relic_random := RandomNumberGenerator.new()


func _ready() -> void:
	assert(progression != null, "PhaseBRelicDirector requires PhaseBProgression")
	assert(territory_field != null, "PhaseBRelicDirector requires TerritoryField")
	assert(overlay != null, "PhaseBRelicDirector requires TerritoryPrototypeOverlay")
	assert(combat != null, "PhaseBRelicDirector requires PhaseBCombatDirector")
	assert(player != null, "PhaseBRelicDirector requires PhaseBPlayer")
	assert(wave_director != null, "PhaseBRelicDirector requires PhaseBWaveDirector")
	combat.enemy_killed.connect(_on_enemy_killed)
	combat.elite_defeated.connect(_on_elite_defeated)
	combat.enemy_rooted.connect(_on_enemy_rooted)
	overlay.seed_germinated_with_context.connect(_on_seed_germinated)
	overlay.seed_spawned.connect(_on_seed_spawned)
	overlay.catalyst_destroyed.connect(_on_catalyst_destroyed)
	overlay.bloom_detonated.connect(_on_bloom_detonated)
	player.damage_taken.connect(_on_player_damage_taken)
	reset_director()


func reset_director() -> void:
	_wave_number = 0
	_kill_times = PackedFloat64Array()
	_overpopulation_primed = false
	_adrenal_cooldown = 0.0
	_clean_finish_used_this_wave = false
	_last_bastion_used_this_wave = false
	_resurrection_fern_used_this_wave = false
	_last_bastion_remaining = 0.0
	_territory_history = PackedInt32Array()
	_territory_sample_remaining = 0.0
	_encore_counter = 0
	_encore_queue.clear()
	_encore_repeating = false
	_compost_kills = 0
	_total_kills = 0
	_world_seed = WorldObject.new()
	_world_seed_id = -1
	_green_thumb_used.clear()
	_patient_zero_id = -1
	_patient_zero_armed = false
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
	_seedbed_nodes.clear()
	_relic_random.seed = 0x0FF1CE5
	player.set_speed_multiplier(1.0)
	apply_relics()
	queue_redraw()


func apply_relics() -> void:
	# Relics that are pure rule parameters are pushed once, when the relic set
	# changes, into whichever system owns that rule. Nothing about them needs a
	# per-frame tick, so nothing about them lives in this component's update.
	combat.set_relic_rules(
		predators_eye_interval if has(PhaseBRelicCatalog.Id.PREDATORS_EYE) else 0,
		follow_through_seconds if has(PhaseBRelicCatalog.Id.FOLLOW_THROUGH) else 0.0,
		adrenal_response_multiplier,
		blood_in_the_water_threshold if has(PhaseBRelicCatalog.Id.BLOOD_IN_THE_WATER) else 0.0,
		underdog_enemy_count if has(PhaseBRelicCatalog.Id.UNDERDOG) else 0,
		underdog_radius_pixels,
		deep_snare_decay_multiplier if has(PhaseBRelicCatalog.Id.DEEP_SNARE) else 1.0
	)
	player.set_damage_absorption(
		canopy_absorption if has(PhaseBRelicCatalog.Id.CANOPY) else 0.0,
		canopy_cooldown_seconds
	)
	territory_field.set_regrowth_memory(
		regrowth_memory_seconds if has(PhaseBRelicCatalog.Id.REGROWTH) else 0.0,
		regrowth_per_second
	)
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
	_advance_wave_boundary()
	_advance_timers(delta)
	_advance_territory_watch(delta)
	_advance_green_thumb()
	_advance_world_seed(delta)
	_advance_rampart(delta)
	_try_trigger_hedge()
	_advance_sweep(delta)
	_advance_taproot(delta)
	_advance_annual_rings(delta)
	_advance_world_tree(delta)
	_advance_perennial(delta)
	_advance_seedbed(delta)
	_advance_encore(delta)
	queue_redraw()


func _advance_wave_boundary() -> void:
	# Per-wave relics reset on the wave the wave director publishes, so nothing
	# here has to guess where a wave began.
	var current := wave_director.get_current_wave_number()
	if current == _wave_number:
		return
	_wave_number = current
	_clean_finish_used_this_wave = false
	_last_bastion_used_this_wave = false
	_resurrection_fern_used_this_wave = false
	_patient_zero_id = -1
	_patient_zero_armed = has(PhaseBRelicCatalog.Id.PATIENT_ZERO)
	_perennial_armed = has(PhaseBRelicCatalog.Id.PERENNIAL)
	_perennial.active = false


func _advance_timers(delta: float) -> void:
	_adrenal_cooldown = maxf(0.0, _adrenal_cooldown - delta)
	_superbloom_cooldown = maxf(0.0, _superbloom_cooldown - delta)
	_hedge_cooldown = maxf(0.0, _hedge_cooldown - delta)
	if _last_bastion_remaining > 0.0:
		_last_bastion_remaining -= delta
		if _last_bastion_remaining <= 0.0:
			player.set_speed_multiplier(1.0)
	for index in range(_recent_blooms.size() - 1, -1, -1):
		var entry: Array = _recent_blooms[index]
		entry[1] = float(entry[1]) - delta
		if float(entry[1]) <= 0.0:
			_recent_blooms.remove_at(index)


func _advance_territory_watch(delta: float) -> void:
	# Both emergency relics key off an absolute number of owned cells lost inside
	# a short window. A percentage of the arena is exactly what this must not be.
	if not (
		has(PhaseBRelicCatalog.Id.LAST_BASTION)
		or has(PhaseBRelicCatalog.Id.RESURRECTION_FERN)
	):
		return
	_territory_sample_remaining -= delta
	if _territory_sample_remaining > 0.0:
		return
	var sample_interval := 0.20
	_territory_sample_remaining = sample_interval
	var samples := maxi(2, int(ceil(territory_emergency_window_seconds / sample_interval)))
	_territory_history.append(territory_field.get_player_cell_count())
	while _territory_history.size() > samples:
		_territory_history.remove_at(0)
	if _territory_history.size() < samples:
		return
	var lost := _territory_history[0] - _territory_history[_territory_history.size() - 1]
	if lost < territory_emergency_cells:
		return
	if has(PhaseBRelicCatalog.Id.LAST_BASTION) and not _last_bastion_used_this_wave:
		_last_bastion_used_this_wave = true
		_trigger_last_bastion(1.0)
	if has(PhaseBRelicCatalog.Id.RESURRECTION_FERN) and not _resurrection_fern_used_this_wave:
		_resurrection_fern_used_this_wave = true
		_trigger_resurrection_fern(1.0)


func _trigger_last_bastion(strength: float) -> void:
	_last_bastion_remaining = last_bastion_seconds * strength
	player.set_speed_multiplier(
		lerpf(1.0, last_bastion_speed_multiplier, clampf(strength, 0.0, 1.0))
	)
	combat.set_temporary_attack_rate_multiplier(
		lerpf(1.0, last_bastion_attack_multiplier, clampf(strength, 0.0, 1.0)),
		last_bastion_seconds * strength
	)
	status_requested.emit("LAST BASTION — the frontier buckles and you speed up.")
	_notify_triggered(PhaseBRelicCatalog.Id.LAST_BASTION)


func _trigger_resurrection_fern(strength: float) -> void:
	var pulses := maxi(1, int(round(float(resurrection_fern_pulses) * strength)))
	var released := 0
	var anchor := player.get_arena_position()
	for index in range(pulses):
		var site := territory_field.find_mature_player_frontier_near(
			anchor + Vector2.from_angle(float(index) * 2.39996) * 140.0
		)
		if site.x < 0.0:
			continue
		territory_field.queue_seed_growth(
			site,
			resurrection_fern_mass * strength,
			0.35,
			progression.get_conversion_multiplier(),
			1.20
		)
		overlay.spawn_bloom(site)
		released += 1
	if released > 0:
		status_requested.emit(
			"RESURRECTION FERN — %d recovery pulses out of old ground." % released
		)
		_notify_triggered(PhaseBRelicCatalog.Id.RESURRECTION_FERN)


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


func _advance_world_seed(delta: float) -> void:
	if not has(PhaseBRelicCatalog.Id.WORLD_SEED):
		return
	if _world_seed.active:
		_world_seed.timer += delta
		return
	if _total_kills < world_seed_kills:
		return
	# Only one at a time, and the counter has to be re-earned after each one.
	_total_kills = 0
	var site := territory_field.find_player_frontier_near(player.get_arena_position())
	if site.x < 0.0:
		site = player.get_arena_position()
	if not territory_field.is_claimable_at_local(site):
		return
	_world_seed_id = overlay.spawn_seed(
		site,
		world_seed_charge_seconds,
		0,
		world_seed_durability
	)
	overlay.mark_seed(_world_seed_id, TerritoryPrototypeOverlay.SeedMarker.WORLD_SEED)
	_world_seed.active = true
	_world_seed.position = site
	_world_seed.timer = 0.0
	status_requested.emit("WORLD SEED — something enormous is opening. Defend it.")


func _germinate_world_seed(local_position: Vector2) -> void:
	# A World Seed that survives is a major growth event, not a bigger ordinary
	# Seed: one large splat with several supporting ones around it.
	_world_seed.active = false
	_world_seed_id = -1
	territory_field.queue_seed_growth(
		local_position,
		world_seed_mass,
		1.20,
		progression.get_conversion_multiplier(),
		world_seed_radius
	)
	for index in range(6):
		var offset := Vector2.from_angle(float(index) * 1.047) * 74.0
		var site := local_position + offset
		if not territory_field.is_growth_path_clear(local_position, site):
			continue
		territory_field.queue_seed_growth(
			site,
			world_seed_mass * 0.35,
			0.6,
			progression.get_conversion_multiplier(),
			world_seed_radius * 0.45
		)
	overlay.spawn_bloom(local_position)
	combat.play_old_growth_sfx()
	status_requested.emit("WORLD SEED — the arena greens over in one breath.")


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
	var site := territory_field.find_oldest_mature_position()
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
	var site := territory_field.find_oldest_mature_position()
	if site.x < 0.0:
		return
	for region in _ring_regions:
		if region.position.distance_to(site) < annual_rings_radius_pixels:
			return
	var fresh := RingRegion.new()
	fresh.position = site
	_ring_regions.append(fresh)


func get_root_potency_bonus_at(local_position: Vector2) -> float:
	# Published for the Root path to fold into its own amplification, so a
	# mechanic acting inside a ringed region or a Seedbed node is stronger there
	# without every consumer having to know these relics exist.
	var bonus := 0.0
	for region in _ring_regions:
		if region.position.distance_to(local_position) <= annual_rings_radius_pixels:
			bonus += annual_rings_potency * float(region.rings)
	for node in _seedbed_nodes:
		var node_position: Vector2 = node[0]
		if node_position.distance_to(local_position) <= seedbed_radius_pixels:
			bonus += seedbed_potency
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
	var site := territory_field.find_oldest_mature_position()
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


func _advance_seedbed(delta: float) -> void:
	for index in range(_seedbed_nodes.size() - 1, -1, -1):
		var node: Array = _seedbed_nodes[index]
		node[1] = float(node[1]) - delta
		if float(node[1]) <= 0.0:
			_seedbed_nodes.remove_at(index)


func _advance_encore(delta: float) -> void:
	for index in range(_encore_queue.size() - 1, -1, -1):
		var entry: Array = _encore_queue[index]
		entry[1] = float(entry[1]) - delta
		if float(entry[1]) > 0.0:
			continue
		var relic_id := int(entry[0])
		var position: Vector2 = entry[2]
		_encore_queue.remove_at(index)
		_encore_repeating = true
		_repeat_relic(relic_id, position)
		_encore_repeating = false


func _notify_triggered(relic_id: int) -> void:
	relic_triggered.emit(relic_id)
	# Encore counts non-Legendary triggers only, and its own repeats never
	# advance it, which is what stops the engine from feeding itself.
	if _encore_repeating or not has(PhaseBRelicCatalog.Id.ENCORE):
		return
	if PhaseBRelicCatalog.is_legendary(relic_id):
		return
	_encore_counter += 1
	if _encore_counter < encore_interval:
		return
	_encore_counter = 0
	_encore_queue.append([relic_id, encore_delay_seconds, player.get_arena_position()])


func _repeat_relic(relic_id: int, position: Vector2) -> void:
	# A reduced second helping of whatever just fired. Relics that create a
	# permanent object are deliberately not repeated: an Encore must not be able
	# to double the run's standing world objects.
	match relic_id:
		PhaseBRelicCatalog.Id.OVERPOPULATION:
			_detonate_overpopulation(position, encore_strength)
		PhaseBRelicCatalog.Id.SALVAGE_RIGHTS:
			progression.add_biomass(salvage_rights_biomass * encore_strength)
		PhaseBRelicCatalog.Id.COMPOST:
			progression.add_biomass(compost_biomass * encore_strength)
		PhaseBRelicCatalog.Id.CLEAN_FINISH:
			player.heal(clean_finish_health * encore_strength)
		PhaseBRelicCatalog.Id.LAST_BASTION:
			_trigger_last_bastion(encore_strength)
		PhaseBRelicCatalog.Id.RESURRECTION_FERN:
			_trigger_resurrection_fern(encore_strength)
		PhaseBRelicCatalog.Id.SNARE_VINE:
			combat.apply_entanglement_in_radius(
				position,
				snare_vine_radius_pixels,
				snare_vine_entanglement * encore_strength
			)
		PhaseBRelicCatalog.Id.TAPROOT:
			if _taproot.active:
				territory_field.queue_seed_growth(
					_taproot.position,
					taproot_mass * encore_strength,
					0.1,
					progression.get_conversion_multiplier(),
					taproot_radius
				)
		PhaseBRelicCatalog.Id.CROSS_POLLINATION, PhaseBRelicCatalog.Id.POLLINATOR:
			overlay.advance_seeds_in_radius(
				position,
				cross_pollination_radius_pixels,
				cross_pollination_progress * encore_strength,
				pollinator_seeds,
				germination_grant_cooldown_seconds
			)
		PhaseBRelicCatalog.Id.TANGLED_WAKE:
			combat.add_ensnare_zone(
				position,
				140.0,
				tangled_wake_bonus * encore_strength,
				tangled_wake_seconds * encore_strength
			)
		_:
			return
	status_requested.emit(
		"ENCORE — %s fires again, weaker." % PhaseBRelicCatalog.get_relic_name(relic_id)
	)


func _on_enemy_killed(
	local_position: Vector2,
	_xp_value: int,
	_role: int,
	death_source: int,
	_chain_depth: int
) -> void:
	var from_relic := death_source == PhaseBCombatDirector.DeathSource.RELIC
	if not from_relic:
		_total_kills += 1
	_try_overpopulation(local_position, death_source)
	_try_compost(local_position)
	_try_clean_finish()
	_try_trigger_hedge()


func _try_overpopulation(local_position: Vector2, death_source: int) -> void:
	if not has(PhaseBRelicCatalog.Id.OVERPOPULATION):
		return
	# An Overpopulation explosion can neither consume the primed charge nor count
	# toward the next one, so a crowd cannot chain-detonate itself.
	if death_source == PhaseBCombatDirector.DeathSource.RELIC:
		return
	if _overpopulation_primed:
		_overpopulation_primed = false
		_detonate_overpopulation(local_position, 1.0)
		return
	var now := Time.get_ticks_msec() / 1000.0
	_kill_times.append(now)
	while (
		_kill_times.size() > 0
		and now - _kill_times[0] > overpopulation_window_seconds
	):
		_kill_times.remove_at(0)
	if _kill_times.size() < overpopulation_kills:
		return
	_kill_times = PackedFloat64Array()
	_overpopulation_primed = true
	status_requested.emit("OVERPOPULATION — the next kill is primed to burst.")


func _detonate_overpopulation(local_position: Vector2, strength: float) -> void:
	combat.damage_enemies_in_radius(
		local_position,
		overpopulation_radius_pixels * strength,
		overpopulation_damage * strength,
		PhaseBCombatDirector.DeathSource.RELIC,
		0
	)
	overlay.spawn_bloom(local_position)
	combat.play_plant_explosion_sfx()
	_notify_triggered(PhaseBRelicCatalog.Id.OVERPOPULATION)


func _try_compost(local_position: Vector2) -> void:
	if not has(PhaseBRelicCatalog.Id.COMPOST):
		return
	if not territory_field.is_mature_player_territory_at_local(local_position):
		return
	_compost_kills += 1
	if _compost_kills < compost_kills:
		return
	_compost_kills = 0
	progression.add_biomass(compost_biomass)
	status_requested.emit("COMPOST — old ground turns the dead into Biomass.")
	_notify_triggered(PhaseBRelicCatalog.Id.COMPOST)


func _try_clean_finish() -> void:
	# Clearing the field is the readable version of "the last enemy of a wave".
	# A wave that ends with hostiles still standing pays nothing.
	if not has(PhaseBRelicCatalog.Id.CLEAN_FINISH) or _clean_finish_used_this_wave:
		return
	if combat.get_active_enemy_count() > 0:
		return
	_clean_finish_used_this_wave = true
	player.heal(clean_finish_health)
	status_requested.emit("CLEAN FINISH — the field is clear; you catch your breath.")
	_notify_triggered(PhaseBRelicCatalog.Id.CLEAN_FINISH)


func _on_elite_defeated() -> void:
	if not has(PhaseBRelicCatalog.Id.SALVAGE_RIGHTS):
		return
	progression.add_biomass(salvage_rights_biomass)
	status_requested.emit("SALVAGE RIGHTS — the elite leaves a Biomass cache.")
	_notify_triggered(PhaseBRelicCatalog.Id.SALVAGE_RIGHTS)


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


func _on_player_damage_taken(_amount: float) -> void:
	if not has(PhaseBRelicCatalog.Id.ADRENAL_RESPONSE) or _adrenal_cooldown > 0.0:
		return
	_adrenal_cooldown = adrenal_response_cooldown
	combat.prime_adrenal_response(adrenal_response_charges)
	status_requested.emit("ADRENAL RESPONSE — the next volleys come faster.")
	_notify_triggered(PhaseBRelicCatalog.Id.ADRENAL_RESPONSE)


func _on_seed_spawned(seed_id: int, _local_position: Vector2) -> void:
	# Patient Zero claims the first Seed the wave produces naturally, and the
	# World Seed is never eligible to be it.
	if not _patient_zero_armed or seed_id == _world_seed_id:
		return
	_patient_zero_armed = false
	_patient_zero_id = seed_id
	overlay.add_seed_shield_charges(seed_id, patient_zero_charges)
	overlay.mark_seed(seed_id, TerritoryPrototypeOverlay.SeedMarker.PATIENT_ZERO)
	status_requested.emit("PATIENT ZERO — this wave's first Seed is marked.")


func _on_seed_germinated(local_position: Vector2, _chain_depth: int) -> void:
	var seed_id := overlay.get_last_germinated_seed_id()
	if _world_seed.active and seed_id == _world_seed_id:
		_germinate_world_seed(local_position)
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
	if _patient_zero_id >= 0 and seed_id == _patient_zero_id:
		_patient_zero_id = -1
		var woken := overlay.advance_seeds_in_radius(
			local_position,
			territory_field.tuning.arena_size.length(),
			patient_zero_progress,
			0,
			0.0
		)
		if woken > 0:
			status_requested.emit(
				"PATIENT ZERO — %d Seeds wake up at once." % woken
			)
	if (
		has(PhaseBRelicCatalog.Id.SEEDBED)
		and territory_field.is_mature_player_territory_at_local(local_position)
	):
		_seedbed_nodes.append([local_position, seedbed_seconds])
		_notify_triggered(PhaseBRelicCatalog.Id.SEEDBED)
	_try_world_tree_echo(local_position, false)


func _on_catalyst_destroyed(catalyst_kind: int, _local_position: Vector2) -> void:
	if catalyst_kind != TerritoryPrototypeOverlay.CatalystKind.SEED:
		return
	if _world_seed.active and not overlay.has_seed(_world_seed_id):
		_world_seed.active = false
		_world_seed_id = -1
		status_requested.emit("WORLD SEED — it was cracked open before it could grow.")


func _on_bloom_detonated(local_position: Vector2, _chain_depth: int) -> void:
	if has(PhaseBRelicCatalog.Id.POLLINATOR):
		var advanced := overlay.advance_seeds_in_radius(
			local_position,
			cross_pollination_radius_pixels,
			pollinator_progress,
			pollinator_seeds,
			germination_grant_cooldown_seconds
		)
		if advanced > 0:
			_notify_triggered(PhaseBRelicCatalog.Id.POLLINATOR)
	if has(PhaseBRelicCatalog.Id.TANGLED_WAKE):
		combat.add_ensnare_zone(
			local_position,
			cross_pollination_radius_pixels,
			tangled_wake_bonus,
			tangled_wake_seconds
		)
		_notify_triggered(PhaseBRelicCatalog.Id.TANGLED_WAKE)
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




func notify_objective_failed() -> bool:
	# Insurance Policy's hook. The prototype has no optional-objective layer yet,
	# so nothing calls this and the relic is never offered; when objectives land,
	# this is the single place they have to reach.
	return has(PhaseBRelicCatalog.Id.INSURANCE_POLICY)


func get_predators_eye_progress() -> String:
	if not has(PhaseBRelicCatalog.Id.PREDATORS_EYE):
		return ""
	return "%d / %d" % [combat.get_predators_eye_progress(), predators_eye_interval]


func get_relic_counter_text(relic_id: int) -> String:
	# A triggered relic needs to show its counter somewhere, so the slot row can
	# read out how close the next activation is.
	match relic_id:
		PhaseBRelicCatalog.Id.PREDATORS_EYE:
			return get_predators_eye_progress()
		PhaseBRelicCatalog.Id.COMPOST:
			return "%d / %d" % [_compost_kills, compost_kills]
		PhaseBRelicCatalog.Id.WORLD_SEED:
			if _world_seed.active:
				return "GROWING"
			return "%d / %d" % [_total_kills, world_seed_kills]
		PhaseBRelicCatalog.Id.OVERPOPULATION:
			if _overpopulation_primed:
				return "PRIMED"
			return "%d / %d" % [_kill_times.size(), overpopulation_kills]
		PhaseBRelicCatalog.Id.ENCORE:
			return "%d / %d" % [_encore_counter, encore_interval]
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


func is_world_seed_active() -> bool:
	return _world_seed.active


func is_taproot_active() -> bool:
	return _taproot.active


func is_world_tree_active() -> bool:
	return _world_tree.active


func get_ring_region_count() -> int:
	return _ring_regions.size()


func get_seedbed_node_count() -> int:
	return _seedbed_nodes.size()


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
	for node in _seedbed_nodes:
		var node_position: Vector2 = node[0]
		draw_arc(
			node_position,
			seedbed_radius_pixels,
			0.0,
			TAU,
			32,
			Color(0.55, 0.95, 0.60, 0.22),
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
