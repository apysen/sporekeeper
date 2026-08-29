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

var _wave_number := 0
var _green_thumb_used := {}

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
	reset_director()


func reset_director() -> void:
	_wave_number = 0
	_green_thumb_used.clear()
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
	_advance_wave_boundary()
	_advance_timers(delta)
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


func _notify_triggered(relic_id: int) -> void:
	relic_triggered.emit(relic_id)


func _on_enemy_killed(
	_local_position: Vector2,
	_xp_value: int,
	_role: int,
	_death_source: int,
	_chain_depth: int
) -> void:
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
