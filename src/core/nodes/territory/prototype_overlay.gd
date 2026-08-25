class_name TerritoryPrototypeOverlay
extends Node2D

signal seed_germinated(local_position: Vector2)
signal seed_germinated_with_context(local_position: Vector2, chain_depth: int)
signal bloom_detonated(local_position: Vector2, chain_depth: int)
signal catalyst_destroyed(catalyst_kind: int, local_position: Vector2)
## A Seed entered the world. Carries its stable id, so a relic can claim a
## particular Seed and follow it until it opens.
signal seed_spawned(seed_id: int, local_position: Vector2)

const INVALID_CATALYST_POSITION := Vector2(-100000.0, -100000.0)

enum CatalystKind {
	SEED,
	BLOOM,
}

enum SeedMarker {
	NONE,
	## The first Seed of a wave, claimed by Patient Zero.
	PATIENT_ZERO,
	## The one enormous Seed a World Seed milestone plants.
	WORLD_SEED,
}

class SeedVisual:
	var position := Vector2.ZERO
	var remaining := 0.0
	var duration := 0.0
	var chain_depth := 0
	var health := 1.0
	var maximum_health := 1.0
	var hit_flash_remaining := 0.0
	## Stable identity, so a relic can hold onto one Seed rather than a position.
	var id := 0
	## Interruptions this Seed shrugs off before a hit can hurt it at all.
	var shield_charges := 0
	## Seconds before this Seed may receive relic germination progress again,
	## which is what stops a chain of Seeds accelerating each other without end.
	var grant_cooldown := 0.0
	var marker := SeedMarker.NONE


class BloomVisual:
	var position := Vector2.ZERO
	var remaining := 0.0
	var duration := 0.0
	var chain_depth := 0
	var health := 1.0
	var maximum_health := 1.0
	var hit_flash_remaining := 0.0

class PulseVisual:
	var position := Vector2.ZERO
	var age := 0.0
	var duration := 0.0
	var maximum_radius := 0.0
	var color := Color.WHITE
	## Whether this pulse is telling the player about danger rather than about
	## something they did. The two are drawn by the same code and must not be turned
	## down by the same setting: quietening your own spectacle to see the fight more
	## clearly cannot be allowed to quieten the fight.
	var hostile := false


class InjectionVisual:
	## One release of Biomass into the border, drawn along the border it was poured
	## into. The three axes are drawn as three different actions rather than three
	## tints of the same flash, because they are three different things: Mass is
	## material arriving, Pressure is a shove, and Cohesion is the ecosystem knitting
	## itself back together.
	var positions := PackedVector2Array()
	var directions := PackedVector2Array()
	var mass := 0.0
	var pressure := 0.0
	var cohesion := 0.0
	var age := 0.0
	var duration := 0.0


class SplatterVisual:
	## Cosmetic layer for one Bloom eruption. Every droplet here is presentation:
	## the gameplay splats were already submitted to the field as commands, and
	## nothing drawn in this class is ever read back to decide a result.
	var position := Vector2.ZERO
	var age := 0.0
	var duration := 0.0
	var central_radius := 0.0
	var mass := 1.0
	var force := 1.0
	## Where the meaningful globs actually landed, so the visible spray agrees with
	## the territory that is about to appear.
	var globs := PackedVector2Array()
	## Cosmetic microdroplets: direction, distance, and size per droplet.
	var droplets := PackedVector3Array()


class TetherVisual:
	## One Bramble tether. The restraint itself is resolved deterministically in
	## combat; this only draws how tight it has become.
	var anchor := Vector2.ZERO
	var enemy := Vector2.ZERO
	var strength := 0.0
	var strands := 1
	var snapping := 0.0

## Shared territory resource used to size the arena and Seed/Bloom presentation.
@export var tuning: TerritoryPrototypeTuning
## Authoritative field queried so pulses and telegraphs stop at basalt walls.
@export var territory_field: TerritoryField

var effects_paused := false
var show_annotations := true
var _seeds: Array[SeedVisual] = []
var _blooms: Array[BloomVisual] = []
var _pulses: Array[PulseVisual] = []
var _splatters: Array[SplatterVisual] = []
var _tethers: Array[TetherVisual] = []
## Where the root network currently has colonies cut off from the main organism.
## Held rather than spawned so the marker persists for as long as the colony does:
## a one-off flash would say a colony was lost, not that one is still out there.
var _isolated_colonies := PackedVector2Array()
## What each of those colonies is holding, so the marker can say why it matters.
var _isolated_colony_reserves := PackedFloat32Array()
## The root network as drawn: one entry per component, each a heart and the vessels
## running out of it. Rebuilt on the topology cadence rather than per frame, because
## the shape of an organism does not change between two frames.
var _root_vessels: Array = []
## Anchor points of the fine root mat, in pairs: a position, then that cell's
## maturity in the x of the following entry. Empty unless the run holds the Root
## path, which is the only build that grows a mat worth drawing.
var _root_mat := PackedVector2Array()
## How developed the mat is, 0 to 1. Root's own ranks drive it, so a run that has
## only just taken the path shows fine hairs and a maxed one shows a dense felt.
var _root_mat_strength := 0.0
## Advances only while something is flowing, and is what the pulses ride on.
var _root_flow_phase := 0.0
## Where the player is, so flow can favour the ground they are standing on.
var _root_demand_position := Vector2.INF
## Seconds left of a discharge running hot through the vessels after a release.
var _root_surge_remaining := 0.0
var _root_surge_origin := Vector2.INF
## Whether the deeper root read-out is up, which brightens the layer and labels it.
var _root_inspect := false
## Per-component reserves, drawn at the component while the inspect layer is held.
var _root_reserves: Array = []

## The release being aimed, drawn only while the player is choosing where to put it.
var _overgrow_aim_active := false
var _overgrow_aim_position := Vector2.ZERO
var _overgrow_aim_radius := 0.0

@export_group("Presentation")
## Presentation options. Optional: without it everything is drawn at full strength,
## which is what this did before the settings existed.
@export var display_settings: PhaseBDisplaySettings

@export_group("Root Network")
## How fast a pulse travels its vessel, in vessels per second. Normal flow is slow on
## purpose: the doc wants the eye to react to changes in motion, not to constant
## motion, so this is the baseline everything else is read against.
@export_range(0.05, 3.0, 0.05) var root_flow_speed := 0.28
## How near the player a vessel has to end before flow starts favouring it.
@export_range(20.0, 900.0, 10.0) var root_demand_radius := 220.0

@export_group("Root Mat")
## Colour of the root hairs drawn under Green while the run holds the Root path.
## Darker than the Green above it on purpose: this is the underside of the
## organism showing through, not another layer of foliage.
@export var root_mat_color := Color(0.30, 0.20, 0.10, 1.0)
## Alpha of the mat at full development. Everything above it has to stay readable,
## so the mat is texture rather than a surface: it says the ground is rooted, it
## does not say anything the player has to read.
@export_range(0.0, 1.0, 0.01) var root_mat_alpha := 0.34
## Hairs radiating from one anchor.
@export_range(2, 12, 1) var root_mat_hairs := 5
## Length of one hair at full maturity, in arena pixels.
@export_range(2.0, 60.0, 0.5) var root_mat_hair_length := 13.0
## Width of a hair's first segment; each following segment tapers toward nothing,
## which is what makes a line read as a root rather than as a scratch.
@export_range(0.5, 6.0, 0.1) var root_mat_hair_width := 1.6
## Segments per hair. More than this buys no visible crookedness and costs draw
## calls on every anchor.
@export_range(2, 8, 1) var root_mat_segments := 3

@export_group("Splatter Flight")
## Body colour of a glob in flight. Opaque on purpose: a translucent glob against
## bright Green or deep red is nearly invisible, and this is what the eye is meant
## to track between the eruption and the landing.
@export var glob_flight_color := Color(0.36, 0.94, 0.42, 1.0)
## Brighter core drawn at the leading edge.
@export var glob_flight_core_color := Color(0.78, 1.0, 0.72, 1.0)
## Tail length as a multiple of the glob's radius.
@export_range(0.0, 8.0, 0.1) var glob_tail_length_scale := 2.6


@export_group("Ecosystem Injections")
## Material arriving at the border: a bead that swells and settles.
@export var injection_mass_color := Color(0.62, 1.0, 0.55, 1.0)
@export_range(1.0, 40.0, 0.5) var injection_mass_radius := 7.5
## A shove: a chevron that leaves the border and travels outward.
@export var injection_pressure_color := Color(1.0, 0.85, 0.38, 1.0)
@export_range(2.0, 120.0, 1.0) var injection_pressure_reach := 34.0
@export_range(1.0, 20.0, 0.5) var injection_pressure_width := 5.0
## Knitting: stitches laid along the border, closing as they brighten.
@export var injection_cohesion_color := Color(0.55, 0.86, 1.0, 1.0)
@export_range(2.0, 60.0, 0.5) var injection_cohesion_length := 15.0
@export_range(0.5, 8.0, 0.1) var injection_cohesion_thickness := 2.4

var _injections: Array[InjectionVisual] = []
var _splatter_random := RandomNumberGenerator.new()

## Globs currently in the air, refreshed by the Bloom director each frame. These
## are the real simulated droplets rather than a cosmetic re-run of the throw, so
## what the player watches is what the field is about to be handed.
var _flight_positions := PackedVector2Array()
var _flight_directions := PackedVector2Array()
var _flight_radii := PackedFloat32Array()

var _next_seed_id := 1
var _default_seed_shield_charges := 0
var _last_germinated_seed_id := -1


func _process(delta: float) -> void:
	if not effects_paused:
		_advance_root_flow(delta)
	if not effects_paused:
		for index in range(_seeds.size() - 1, -1, -1):
			var seed := _seeds[index]
			seed.remaining -= delta
			seed.hit_flash_remaining = maxf(0.0, seed.hit_flash_remaining - delta)
			seed.grant_cooldown = maxf(0.0, seed.grant_cooldown - delta)
			if seed.remaining <= 0.0:
				_last_germinated_seed_id = seed.id
				seed_germinated.emit(seed.position)
				seed_germinated_with_context.emit(seed.position, seed.chain_depth)
				_spawn_pulse(seed.position, 0.72, 76.0, Color("9cff63"))
				_seeds.remove_at(index)

		for index in range(_blooms.size() - 1, -1, -1):
			var bloom := _blooms[index]
			bloom.remaining -= delta
			bloom.hit_flash_remaining = maxf(0.0, bloom.hit_flash_remaining - delta)
			if bloom.remaining <= 0.0:
				bloom_detonated.emit(bloom.position, bloom.chain_depth)
				var pixels_per_cell := tuning.arena_size.x / float(tuning.field_size.x)
				_spawn_pulse(
					bloom.position,
					0.48,
					tuning.bloom_radius_cells * pixels_per_cell,
					Color("65ffd0")
				)
				_blooms.remove_at(index)

		for index in range(_injections.size() - 1, -1, -1):
			var injection := _injections[index]
			injection.age += delta
			if injection.age >= injection.duration:
				_injections.remove_at(index)

		for index in range(_pulses.size() - 1, -1, -1):
			var pulse := _pulses[index]
			pulse.age += delta
			if pulse.age >= pulse.duration:
				_pulses.remove_at(index)

		for index in range(_splatters.size() - 1, -1, -1):
			var splatter := _splatters[index]
			splatter.age += delta
			if splatter.age >= splatter.duration:
				_splatters.remove_at(index)

		for index in range(_tethers.size() - 1, -1, -1):
			var tether := _tethers[index]
			tether.snapping = maxf(0.0, tether.snapping - delta)
			if tether.strength <= 0.0 and tether.snapping <= 0.0:
				_tethers.remove_at(index)

	queue_redraw()


func _draw() -> void:
	_draw_flight_globs()
	draw_rect(
		Rect2(Vector2.ZERO, tuning.arena_size),
		Color("6d7f8f"),
		false,
		2.0,
		true
	)
	if show_annotations:
		_draw_annotation(Vector2(58.0, 58.0), "OPEN GROUND", Color("79d59b"))
		_draw_annotation(Vector2(427.0, 272.0), "CHOKE", Color("8bd5ff"))
		_draw_annotation(Vector2(696.0, 91.0), "ENCLOSED POCKET", Color("b9ff73"))
		_draw_annotation(Vector2(309.0, 111.0), "BASALT", Color("b8b9b8"))
		_draw_annotation(Vector2(573.0, 440.0), "BASALT", Color("b8b9b8"))
		var weak_hostile_center := Vector2(662.0, 413.0)
		draw_circle(weak_hostile_center, 7.0, Color("ffb071"), false, 1.5, true)
		draw_line(
			weak_hostile_center + Vector2(6.0, -5.0),
			Vector2(704.0, 391.0),
			Color("ffb071"),
			1.0,
			true
		)
		_draw_annotation(Vector2(704.0, 380.0), "WEAK HOSTILE TERRITORY", Color("ffb071"))

	# Under everything else: the root layer is the ground's own state, and it must not
	# compete with enemies, projectiles, or the frontier for attention. The mat goes
	# down first of all, because it is literally underneath: the vessels run through it.
	_draw_root_mat()
	_draw_root_network()
	_draw_isolated_colonies()
	if _root_inspect:
		_draw_root_reserves()
	_draw_overgrow_aim()

	for tether in _tethers:
		_draw_tether(tether)

	for splatter in _splatters:
		_draw_splatter(splatter)

	_draw_injections()

	for pulse in _pulses:
		var progress := clampf(pulse.age / pulse.duration, 0.0, 1.0)
		var radius := lerpf(8.0, pulse.maximum_radius, progress)
		var alpha := (1.0 - progress) * 0.90
		# The two settings meet here and nowhere else: a hostile pulse reads the
		# telegraph setting and a friendly one reads the friendly setting, so the same
		# drawing code serves both without either being able to turn the other down.
		if pulse.hostile:
			alpha = minf(1.0, alpha * _telegraph_alpha_scale())
		else:
			alpha *= _friendly_scale()
		if alpha <= 0.004:
			continue
		var pulse_color := Color(pulse.color, alpha)
		_draw_occluded_arc(
			pulse.position,
			radius,
			pulse_color,
			_telegraph_width_bonus() if pulse.hostile else 0.0
		)
		draw_circle(pulse.position, maxf(2.0, radius * 0.08), pulse_color, true, -1.0, true)

	for bloom in _blooms:
		var progress := 1.0 - clampf(bloom.remaining / bloom.duration, 0.0, 1.0)
		var radius := 8.0 + progress * 11.0
		var glow_alpha := 0.36 + progress * 0.46
		draw_circle(bloom.position, radius + 7.0, Color(0.26, 1.0, 0.70, glow_alpha * 0.22))
		draw_circle(bloom.position, radius, Color(0.08, 0.25, 0.15, 0.96))
		draw_circle(bloom.position, radius, Color("70ffd0"), false, 2.5, true)
		draw_arc(
			bloom.position,
			radius + 5.0,
			-PI * 0.5,
			-PI * 0.5 + TAU * progress,
			32,
			Color("c8ffe4"),
			3.0,
			true
		)
		draw_line(
			bloom.position + Vector2(-5.0, 2.0),
			bloom.position + Vector2(0.0, -8.0),
			Color("a9ffca"),
			2.0,
			true
		)
		draw_line(
			bloom.position + Vector2(0.0, -8.0),
			bloom.position + Vector2(7.0, 2.0),
			Color("a9ffca"),
			2.0,
			true
		)
		_draw_catalyst_durability(
			bloom.position,
			radius,
			bloom.health,
			bloom.maximum_health,
			bloom.hit_flash_remaining
		)

	for seed in _seeds:
		var progress := 1.0 - clampf(seed.remaining / seed.duration, 0.0, 1.0)
		var breathe := sin(progress * TAU * 3.0) * 1.5
		var radius := 9.0 + progress * 5.0 + breathe
		draw_circle(seed.position, radius, Color(0.13, 0.20, 0.10, 0.92), true, -1.0, true)
		draw_circle(seed.position, radius, Color("b5ff69"), false, 2.0, true)
		draw_arc(
			seed.position,
			radius + 5.0,
			-PI * 0.5,
			-PI * 0.5 + TAU * progress,
			32,
			Color("eaffb8"),
			3.0,
			true
		)
		draw_line(seed.position + Vector2(0.0, -4.0), seed.position + Vector2(5.0, -10.0), Color("d9ff9c"), 2.0, true)
		if seed.marker != SeedMarker.NONE:
			# A relic that claims one particular Seed has to say which one, or the
			# player cannot defend it.
			var marker_color := (
				Color("ffd24a")
				if seed.marker == SeedMarker.WORLD_SEED
				else Color("9cd8ff")
			)
			draw_arc(seed.position, radius + 9.0, 0.0, TAU, 28, marker_color, 2.0, true)
			draw_arc(seed.position, radius + 13.0, 0.0, TAU, 28, Color(marker_color, 0.35), 1.0, true)
		if seed.shield_charges > 0:
			for shield_index in range(seed.shield_charges):
				var shield_angle := -PI * 0.5 + float(shield_index) * 0.55
				draw_circle(
					seed.position + Vector2.from_angle(shield_angle) * (radius + 6.0),
					2.0,
					Color("d9ff9c"),
					true,
					-1.0,
					true
				)
		_draw_catalyst_durability(
			seed.position,
			radius,
			seed.health,
			seed.maximum_health,
			seed.hit_flash_remaining
		)


func spawn_seed(
	local_position: Vector2,
	charge_seconds: float = -1.0,
	chain_depth: int = 0,
	durability: float = 1.0
) -> int:
	var seed := SeedVisual.new()
	seed.position = local_position
	seed.duration = tuning.seed_charge_seconds if charge_seconds <= 0.0 else charge_seconds
	seed.remaining = seed.duration
	seed.chain_depth = chain_depth
	seed.maximum_health = maxf(0.01, durability)
	seed.health = seed.maximum_health
	seed.id = _next_seed_id
	seed.shield_charges = _default_seed_shield_charges
	_next_seed_id += 1
	_seeds.append(seed)
	queue_redraw()
	seed_spawned.emit(seed.id, local_position)
	return seed.id


func set_default_seed_shield_charges(charges: int) -> void:
	# Hard Husk applies to every Seed the run makes from here on, so the default
	# is stored rather than being pushed onto each Seed by its creator.
	_default_seed_shield_charges = maxi(0, charges)


func add_seed_shield_charges(seed_id: int, charges: int) -> bool:
	var seed := _find_seed(seed_id)
	if seed == null:
		return false
	seed.shield_charges += maxi(0, charges)
	return true


func mark_seed(seed_id: int, marker: int) -> bool:
	var seed := _find_seed(seed_id)
	if seed == null:
		return false
	seed.marker = marker
	queue_redraw()
	return true


func has_seed(seed_id: int) -> bool:
	return _find_seed(seed_id) != null


func get_seed_ids() -> PackedInt32Array:
	var ids := PackedInt32Array()
	for seed in _seeds:
		ids.append(seed.id)
	return ids


func get_seed_position(seed_id: int) -> Vector2:
	var seed := _find_seed(seed_id)
	if seed == null:
		return INVALID_CATALYST_POSITION
	return seed.position


func get_seed_progress(seed_id: int) -> float:
	var seed := _find_seed(seed_id)
	if seed == null or seed.duration <= 0.0:
		return 0.0
	return clampf(1.0 - seed.remaining / seed.duration, 0.0, 1.0)


func get_last_germinated_seed_id() -> int:
	return _last_germinated_seed_id


func advance_seed(seed_id: int, progress: float, cooldown_seconds: float) -> bool:
	# Germination progress as a fraction of the Seed's own charge, so a long
	# World Seed and an ordinary Seed both advance by the same share of themselves.
	var seed := _find_seed(seed_id)
	if seed == null or progress <= 0.0 or seed.grant_cooldown > 0.0:
		return false
	seed.remaining = maxf(0.0, seed.remaining - seed.duration * progress)
	seed.grant_cooldown = maxf(0.0, cooldown_seconds)
	queue_redraw()
	return true


func advance_seeds_in_radius(
	local_position: Vector2,
	radius: float,
	progress: float,
	maximum_seeds: int,
	cooldown_seconds: float
) -> int:
	# Nearest first, capped, and never the Seed that is standing exactly where the
	# effect came from, so a germination cannot advance itself.
	if progress <= 0.0:
		return 0
	var candidates: Array[SeedVisual] = []
	for seed in _seeds:
		if seed.grant_cooldown > 0.0:
			continue
		if seed.position.distance_to(local_position) > radius:
			continue
		candidates.append(seed)
	if candidates.is_empty():
		return 0
	candidates.sort_custom(
		func(first: SeedVisual, second: SeedVisual) -> bool:
			return (
				first.position.distance_squared_to(local_position)
				< second.position.distance_squared_to(local_position)
			)
	)
	var limit := candidates.size() if maximum_seeds <= 0 else mini(maximum_seeds, candidates.size())
	var advanced := 0
	for index in range(limit):
		var seed := candidates[index]
		seed.remaining = maxf(0.0, seed.remaining - seed.duration * progress)
		seed.grant_cooldown = maxf(0.0, cooldown_seconds)
		advanced += 1
	if advanced > 0:
		queue_redraw()
	return advanced


func _find_seed(seed_id: int) -> SeedVisual:
	for seed in _seeds:
		if seed.id == seed_id:
			return seed
	return null


func spawn_bloom(local_position: Vector2) -> void:
	var pixels_per_cell := tuning.arena_size.x / float(tuning.field_size.x)
	_spawn_pulse(local_position, 0.48, tuning.bloom_radius_cells * pixels_per_cell, Color("65ffd0"))


func plant_bloom(
	local_position: Vector2,
	windup_seconds: float,
	chain_depth: int = 0,
	durability: float = 1.0
) -> void:
	var bloom := BloomVisual.new()
	bloom.position = local_position
	bloom.duration = maxf(0.05, windup_seconds)
	bloom.remaining = bloom.duration
	bloom.chain_depth = chain_depth
	bloom.maximum_health = maxf(0.01, durability)
	bloom.health = bloom.maximum_health
	_blooms.append(bloom)
	queue_redraw()


func germinate_nearest_seed(
	local_position: Vector2,
	radius: float,
	inherited_chain_depth: int = -1
) -> bool:
	# Forced Germination: bring the closest charging Seed forward instead of
	# spawning a new one, so the effect accelerates the ecosystem rather than
	# inflating it.
	var nearest_index := -1
	var nearest_distance := radius * radius
	for index in range(_seeds.size()):
		var distance := _seeds[index].position.distance_squared_to(local_position)
		if distance > nearest_distance:
			continue
		nearest_distance = distance
		nearest_index = index
	if nearest_index < 0:
		return false
	if inherited_chain_depth >= 0:
		# A Seed cracked open by something that was itself part of a chain belongs to
		# that chain. Without this the germination reports the depth it was planted
		# at, every generation looks like the first, and nothing ever terminates.
		_seeds[nearest_index].chain_depth = maxi(
			_seeds[nearest_index].chain_depth, inherited_chain_depth
		)
	_seeds[nearest_index].remaining = 0.0
	return true


func spawn_splatter(
	local_position: Vector2,
	central_radius_pixels: float,
	mass: float,
	force: float,
	globs: PackedVector2Array,
	scale: float = 1.0
) -> void:
	# The visible half of a Bloom. The field already has the splats that matter;
	# this adds the microdroplets and streaks that make the eruption read as thrown
	# paint rather than as an expanding ring. Hundreds of physics bodies are exactly
	# what this avoids: the droplets are drawn, never simulated.
	var splatter := SplatterVisual.new()
	splatter.position = local_position
	splatter.duration = 0.62 + clampf(mass, 0.0, 3.0) * 0.10
	splatter.age = 0.0
	splatter.central_radius = central_radius_pixels * scale
	splatter.mass = maxf(0.05, mass)
	splatter.force = maxf(0.05, force)
	splatter.globs = globs
	# One owned source, reseeded from the eruption itself, so replaying a run
	# produces the same spray rather than a different one every time.
	_splatter_random.seed = (
		int(local_position.x) * 73856093
		^ int(local_position.y) * 19349663
		^ int(central_radius_pixels * 16.0)
	)
	var count := tuning.bloom_microdroplet_count
	for _index in range(count):
		var angle := _splatter_random.randf() * TAU
		var reach := (
			splatter.central_radius
			* splatter.force
			* (0.35 + _splatter_random.randf() * tuning.bloom_satellite_throw_multiplier)
		)
		var size := 1.0 + _splatter_random.randf() * 2.6 * sqrt(splatter.mass)
		splatter.droplets.append(Vector3(angle, reach, size))
	_splatters.append(splatter)
	queue_redraw()


func set_tethers(tethers: Array) -> void:
	# Bramble hands over what it is currently restraining, as plain values. The
	# overlay never asks combat or the field anything: it draws what it was told.
	_tethers.clear()
	for entry in tethers:
		_tethers.append(entry)
	queue_redraw()


func make_tether(
	anchor: Vector2,
	enemy: Vector2,
	strength: float,
	strands: int
) -> TetherVisual:
	var tether := TetherVisual.new()
	tether.anchor = anchor
	tether.enemy = enemy
	tether.strength = clampf(strength, 0.0, 1.0)
	tether.strands = maxi(1, strands)
	return tether


func spawn_tether_snap(anchor: Vector2, enemy: Vector2) -> void:
	var tether := make_tether(anchor, enemy, 0.0, 1)
	tether.snapping = 0.22
	_tethers.append(tether)
	queue_redraw()


func get_active_splatter_count() -> int:
	return _splatters.size()


func get_active_tether_count() -> int:
	return _tethers.size()



func set_flight_globs(
	positions: PackedVector2Array,
	directions: PackedVector2Array,
	radii: PackedFloat32Array
) -> void:
	_flight_positions = positions
	_flight_directions = directions
	_flight_radii = radii
	queue_redraw()


func get_flight_glob_count() -> int:
	return _flight_positions.size()


func _draw_flight_globs() -> void:
	# A thrown glob is not a circle. It is fat at the leading edge where the
	# material piles up and drawn out behind into a tail, so the shape itself says
	# which way it is going and how fast. Drawn opaque: this is the thing the player
	# is meant to be following.
	for index in range(_flight_positions.size()):
		var position: Vector2 = _flight_positions[index]
		var direction: Vector2 = _flight_directions[index]
		var radius: float = _flight_radii[index]
		if direction.length_squared() < 0.0001:
			draw_circle(position, radius, glob_flight_color, true, -1.0, true)
			continue
		var forward := direction.normalized()
		var tail := forward * radius * glob_tail_length_scale
		var polygon := PackedVector2Array()
		# The leading half is a full round face.
		var steps := 10
		for step in range(steps + 1):
			var angle := -PI * 0.5 + PI * float(step) / float(steps)
			var offset := forward.rotated(angle) * radius
			polygon.append(position + offset)
		# Then it tapers to a point behind, against the direction of travel.
		polygon.append(position - tail)
		draw_colored_polygon(polygon, glob_flight_color)
		# A brighter core so the head reads against bright Green as well as red.
		draw_circle(
			position + forward * radius * 0.18,
			radius * 0.55,
			glob_flight_core_color,
			true,
			-1.0,
			true
		)

func _draw_splatter(splatter: SplatterVisual) -> void:
	var progress := clampf(splatter.age / maxf(0.01, splatter.duration), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	var alpha := (1.0 - progress) * 0.92
	var wet := Color(0.42, 1.0, 0.52, alpha)
	var deep := Color(0.10, 0.52, 0.20, alpha * 0.85)

	# The central splat lands first and thickest.
	draw_circle(
		splatter.position,
		splatter.central_radius * (0.35 + 0.65 * eased) * sqrt(splatter.mass),
		deep,
		true,
		-1.0,
		true
	)

	# The globs themselves are drawn in flight from the simulation, so this layer
	# only marks where they came down once they have landed.
	for glob in splatter.globs:
		if eased < 0.999:
			continue
		draw_circle(glob, 4.0 * sqrt(splatter.mass) + 1.5, wet, true, -1.0, true)

	for droplet in splatter.droplets:
		var direction := Vector2.from_angle(droplet.x)
		var travel := direction * droplet.y * eased
		var point := splatter.position + travel
		if territory_field != null and not territory_field.is_growth_path_clear(
			splatter.position,
			point
		):
			continue
		draw_line(
			point - direction * droplet.z * splatter.force,
			point,
			Color(wet, alpha * 0.7),
			maxf(1.0, droplet.z * 0.5),
			true
		)


func _draw_tether(tether: TetherVisual) -> void:
	if tether.snapping > 0.0:
		# A broken restraint snaps back visibly rather than simply disappearing.
		var recoil := clampf(tether.snapping / 0.22, 0.0, 1.0)
		var midpoint := tether.anchor.lerp(tether.enemy, 0.45)
		draw_line(
			tether.anchor,
			midpoint,
			Color(0.85, 1.0, 0.55, recoil * 0.8),
			2.0,
			true
		)
		return
	var offset := tether.enemy - tether.anchor
	var length := offset.length()
	if length <= 0.5:
		return
	var normal := offset.orthogonal() / length
	# More Entanglement means more strands and a tighter line: a moving enemy
	# visibly stretches them, and a fully Entangled one is drawn taut.
	var slack := (1.0 - tether.strength) * minf(18.0, length * 0.28)
	for strand in range(tether.strands):
		var side := (float(strand) - float(tether.strands - 1) * 0.5) * 4.0
		var bow := normal * (side + slack * (1.0 if strand % 2 == 0 else -1.0))
		var control := tether.anchor.lerp(tether.enemy, 0.5) + bow
		var previous := tether.anchor
		for segment in range(1, 7):
			var time := float(segment) / 6.0
			var point := (
				tether.anchor.lerp(control, time).lerp(control.lerp(tether.enemy, time), time)
			)
			draw_line(
				previous,
				point,
				Color(0.52, 0.92, 0.42, 0.28 + tether.strength * 0.52),
				1.0 + tether.strength * 1.6,
				true
			)
			previous = point


func spawn_hostile_pulse(local_position: Vector2, maximum_radius: float) -> void:
	_spawn_pulse(local_position, 0.52, maximum_radius, Color("ff5369"), true)


func set_root_mat(anchors: PackedVector2Array, strength: float) -> void:
	_root_mat = anchors
	_root_mat_strength = clampf(strength, 0.0, 1.0)
	queue_redraw()


func get_root_mat_anchor_count() -> int:
	# Anchors arrive in pairs of position and maturity, so what a caller means by
	# "how many" is half of what the array holds.
	return _root_mat.size() / 2


func _draw_root_mat() -> void:
	# Root's own signature on the battlefield: held ground visibly grows roots into
	# itself. It is drawn as tapering hairs radiating from sampled mature cells rather
	# than as a texture over the Green, so what the player sees follows the actual
	# shape of the organism and thins out wherever the ground is young.
	var detail := _territory_detail_scale()
	if _root_mat_strength <= 0.0 or _root_mat.size() < 2 or detail <= 0.0:
		return
	var anchor_count := _root_mat.size() / 2
	for anchor_index in range(anchor_count):
		var origin := _root_mat[anchor_index * 2]
		var maturity := clampf(_root_mat[anchor_index * 2 + 1].x, 0.0, 1.0)
		# Older ground carries more of the mat, which is what makes the layer describe
		# the organism's age rather than only its outline.
		var presence := _root_mat_strength * maturity * detail
		if presence <= 0.02:
			continue
		var colour := Color(
			root_mat_color.r,
			root_mat_color.g,
			root_mat_color.b,
			root_mat_alpha * presence
		)
		# Seeded off the anchor's own position so a hair is in the same place every
		# frame. A mat that reshuffles itself between frames reads as static, not roots.
		var seed := int(origin.x) * 73856093 ^ int(origin.y) * 19349663
		var hair_count := maxi(2, int(round(float(root_mat_hairs) * presence)) + 1)
		for hair_index in range(hair_count):
			var wobble := float((seed + hair_index * 2654435761) % 1000) / 1000.0
			var angle := (
				TAU * float(hair_index) / float(hair_count)
				+ wobble * TAU / float(hair_count)
			)
			var length := root_mat_hair_length * (0.45 + 0.55 * maturity) * (0.6 + wobble * 0.7)
			var previous := origin
			var heading := Vector2.from_angle(angle)
			for segment in range(root_mat_segments):
				# Each segment bends a little further off the last, so a hair crooks the
				# way a root does instead of being a spoke on a wheel.
				var bend := (wobble - 0.5) * 1.1 * float(segment + 1)
				var step := heading.rotated(bend) * (length / float(root_mat_segments))
				var point := previous + step
				var taper := 1.0 - float(segment) / float(root_mat_segments)
				draw_line(
					previous,
					point,
					Color(colour.r, colour.g, colour.b, colour.a * taper),
					maxf(0.6, root_mat_hair_width * taper),
					true
				)
				previous = point


func set_root_vessels(vessels: Array) -> void:
	_root_vessels = vessels
	queue_redraw()


func set_root_demand(local_position: Vector2) -> void:
	_root_demand_position = local_position


func set_root_reserves(reserves: Array) -> void:
	_root_reserves = reserves
	queue_redraw()


func _draw_root_reserves() -> void:
	for entry in _root_reserves:
		var position: Vector2 = entry["position"]
		var reserve: float = entry["reserve"]
		var capacity: float = entry["capacity"]
		var is_primary: bool = entry["primary"]
		# A storage organ drawn where the reserve actually is, filling as it fills.
		var fill := clampf(reserve / maxf(1.0, capacity), 0.0, 1.0)
		var radius := 15.0
		draw_circle(position, radius, Color(0.04, 0.09, 0.06, 0.72))
		draw_arc(
			position,
			radius,
			-PI * 0.5,
			-PI * 0.5 + TAU * fill,
			48,
			Color(0.78, 1.0, 0.52, 0.95) if is_primary else Color(0.44, 0.84, 0.75, 0.95),
			3.0,
			true
		)
		var font := ThemeDB.fallback_font
		var label := "%d" % roundi(reserve)
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11)
		draw_string(
			font,
			position + Vector2(-text_size.x * 0.5, radius + 14.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			11,
			Color(0.86, 1.0, 0.78, 0.95)
		)


func set_root_inspect(enabled: bool) -> void:
	if enabled == _root_inspect:
		return
	_root_inspect = enabled
	queue_redraw()


func is_root_inspect() -> bool:
	return _root_inspect


func spawn_root_surge(origin: Vector2, seconds: float) -> void:
	## A release travelling out through the roots before it reaches the border. The
	## doc asks for the network to visibly carry what was spent rather than for the
	## frontier to simply change.
	_root_surge_origin = origin
	_root_surge_remaining = maxf(_root_surge_remaining, seconds)


func get_root_vessel_count() -> int:
	var total := 0
	for vessel in _root_vessels:
		total += (vessel["endpoints"] as PackedVector2Array).size()
	return total


func _advance_root_flow(delta: float) -> void:
	var flowing := false
	for vessel in _root_vessels:
		if vessel["flowing"]:
			flowing = true
			break
	if flowing:
		_root_flow_phase = fmod(_root_flow_phase + delta * root_flow_speed, 1.0)
	_root_surge_remaining = maxf(0.0, _root_surge_remaining - delta)
	if flowing or _root_surge_remaining > 0.0:
		queue_redraw()


func _vessel_bend(heart: Vector2, endpoint: Vector2) -> Vector2:
	# Roots do not run in straight lines to a hub. A deterministic sideways kick at the
	# midpoint is enough to read as growth rather than as a diagram, and being derived
	# from the endpoint means a vessel keeps its shape between rebuilds.
	var span := endpoint - heart
	var sideways := Vector2(-span.y, span.x).normalized()
	var wobble := sin(endpoint.x * 0.061 + endpoint.y * 0.043) * span.length() * 0.24
	return heart + span * 0.5 + sideways * wobble


func _vessel_point(heart: Vector2, bend: Vector2, endpoint: Vector2, t: float) -> Vector2:
	var inverse := 1.0 - t
	return (
		heart * inverse * inverse
		+ bend * 2.0 * inverse * t
		+ endpoint * t * t
	)


func _draw_root_network() -> void:
	if _root_vessels.is_empty():
		return
	var surging := _root_surge_remaining > 0.0
	for vessel in _root_vessels:
		var heart: Vector2 = vessel["heart"]
		var endpoints: PackedVector2Array = vessel["endpoints"]
		var flowing: bool = vessel["flowing"]
		# A component cut off from the organism keeps its roots and loses its flow.
		# The doc is explicit that a severed region must not instantly look dead: it
		# stops receiving pulses, and that absence is what carries the information.
		# Subtle is not the same as invisible. At the alpha this started on, the root
		# layer could not be seen at all during normal play, which made the question
		# "what are the roots doing" unanswerable before it was a question about flow.
		var vessel_alpha := (0.46 if _root_inspect else 0.30) * (1.0 if flowing else 0.55)
		var vessel_colour := Color(0.50, 0.92, 0.56, vessel_alpha)
		var vessel_width := 2.2 if _root_inspect else 1.7
		for endpoint_index in range(endpoints.size()):
			var endpoint := endpoints[endpoint_index]
			var bend := _vessel_bend(heart, endpoint)
			var previous := heart
			for step in range(1, 7):
				var point := _vessel_point(heart, bend, endpoint, float(step) / 6.0)
				draw_line(previous, point, vessel_colour, vessel_width, true)
				previous = point
			if not flowing:
				continue
			# Which way a pulse travels is the whole of what the roots are saying.
			# Inward is the organism gathering what its ground produced into the
			# reserve; outward is the organism spending, pushing support to the front
			# the player is standing at. One picture, two opposite meanings.
			var demand := 0.0
			if _root_demand_position.is_finite():
				demand = clampf(
					1.0 - endpoint.distance_to(_root_demand_position)
					/ maxf(1.0, root_demand_radius),
					0.0,
					1.0
				)
			var outward := demand > 0.35 or surging
			var offset := float(endpoint_index) * 0.137
			var travel := fmod(_root_flow_phase + offset, 1.0)
			var along := travel if outward else 1.0 - travel
			var brightness := (0.60 if _root_inspect else 0.48) + demand * 0.50
			draw_circle(
				_vessel_point(heart, bend, endpoint, along),
				(1.7 if not _root_inspect else 2.3) * (1.0 + demand * 0.6),
				Color(
					0.76 + demand * 0.18,
					1.0,
					0.52,
					clampf(brightness * sin(along * PI), 0.0, 1.0)
				)
			)
			if not surging:
				continue
			# The discharge runs the same vessels outward, faster and brighter, so what
			# the player spent is seen leaving the organism on its way to the border.
			draw_circle(
				_vessel_point(
					heart,
					bend,
					endpoint,
					fmod(travel + _root_surge_remaining * 2.4, 1.0)
				),
				3.0,
				Color(0.90, 1.0, 0.58, clampf(_root_surge_remaining * 1.4, 0.0, 0.9))
			)


func set_overgrow_aim(local_position: Vector2, radius: float) -> void:
	_overgrow_aim_active = true
	_overgrow_aim_position = local_position
	_overgrow_aim_radius = radius
	queue_redraw()


func clear_overgrow_aim() -> void:
	if not _overgrow_aim_active:
		return
	_overgrow_aim_active = false
	queue_redraw()


func is_aiming_overgrow() -> bool:
	return _overgrow_aim_active


func get_overgrow_aim_position() -> Vector2:
	return _overgrow_aim_position


func _draw_overgrow_aim() -> void:
	if not _overgrow_aim_active:
		return
	# The ring is the reach the release will actually favour, so the player is aiming
	# at an area rather than a point. It exists only while aiming: the doc rules out a
	# permanent influence circle sitting on the battlefield.
	var aim_colour := Color(0.72, 1.0, 0.42, 0.90)
	draw_arc(
		_overgrow_aim_position,
		_overgrow_aim_radius,
		0.0,
		TAU,
		96,
		Color(aim_colour, 0.34),
		2.0,
		true
	)
	# Four ticks and a gap at the centre rather than crossed lines, so the crosshair
	# never hides the ground being aimed at.
	var inner := 7.0
	var outer := 17.0
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(
			_overgrow_aim_position + direction * inner,
			_overgrow_aim_position + direction * outer,
			aim_colour,
			2.0,
			true
		)
	draw_arc(_overgrow_aim_position, inner * 0.5, 0.0, TAU, 24, aim_colour, 1.5, true)


func spawn_discharge_pulse(local_position: Vector2) -> void:
	## A release leaving the player and travelling out through the roots. It is drawn
	## at the player rather than at the border because that is where the demand the
	## network answered actually came from.
	_spawn_pulse(local_position, 0.62, 148.0, Color("b6ff6a"))


func spawn_sever_pulse(local_position: Vector2) -> void:
	## A connection has been cut. It reads inward and cold, against the reconnection
	## pulse below, which reads outward and bright.
	_spawn_pulse(local_position, 0.75, 46.0, Color("6fd6c0"))


func spawn_reconnection_pulse(local_position: Vector2) -> void:
	## The doc asks for this to become a recognisable event of its own, so it is
	## brighter and reaches further than anything else the root layer draws.
	_spawn_pulse(local_position, 0.95, 104.0, Color("d8ff8a"))


func set_isolated_colonies(
	positions: PackedVector2Array,
	reserves: PackedFloat32Array = PackedFloat32Array()
) -> void:
	if positions == _isolated_colonies and reserves == _isolated_colony_reserves:
		return
	_isolated_colonies = positions
	_isolated_colony_reserves = reserves
	queue_redraw()


func get_isolated_colony_count() -> int:
	return _isolated_colonies.size()


func _draw_isolated_colonies() -> void:
	# A broken ring rather than a coloured one. The doc is explicit that a state this
	# important must not be carried by colour alone, and a ring with gaps torn in it
	# says "cut off" at a glance in a way a tinted circle does not.
	var font := ThemeDB.fallback_font
	for colony_index in range(_isolated_colonies.size()):
		var colony_position := _isolated_colonies[colony_index]
		var segments := 16
		for segment in range(segments):
			if segment % 2 == 1:
				continue
			var from_angle := TAU * float(segment) / float(segments)
			var to_angle := TAU * float(segment + 1) / float(segments)
			draw_arc(
				colony_position,
				19.0,
				from_angle,
				to_angle,
				5,
				Color(0.44, 0.84, 0.75, 0.85),
				2.0,
				true
			)
		# The ring says something is wrong with this ground; it cannot say what. A
		# marker nobody can read is decoration, so it names itself and carries the
		# number that makes it matter - Biomass the run is producing and cannot spend.
		var caption := "CUT OFF"
		if colony_index < _isolated_colony_reserves.size():
			caption = "CUT OFF  %d" % roundi(_isolated_colony_reserves[colony_index])
		# Sized to be read at a glance over bright territory rather than squinted at.
		# The accessibility guidance the doc cites treats small text as a defect, and
		# this sits on top of the most saturated colour on the screen.
		var caption_font_size := 17
		var caption_size := font.get_string_size(
			caption,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			caption_font_size
		)
		var caption_origin := colony_position + Vector2(-caption_size.x * 0.5, 40.0)
		draw_rect(
			Rect2(
				caption_origin - Vector2(7.0, caption_size.y * 0.80),
				caption_size + Vector2(14.0, 8.0)
			),
			Color(0.01, 0.04, 0.04, 0.88),
			true
		)
		draw_rect(
			Rect2(
				caption_origin - Vector2(7.0, caption_size.y * 0.80),
				caption_size + Vector2(14.0, 8.0)
			),
			Color(0.44, 0.84, 0.75, 0.55),
			false,
			1.0,
			true
		)
		draw_string(
			font,
			caption_origin,
			caption,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			caption_font_size,
			Color(0.78, 1.0, 0.93, 1.0)
		)


func get_active_seed_count() -> int:
	return _seeds.size()


func get_active_bloom_count() -> int:
	return _blooms.size()


func get_first_bloom_position() -> Vector2:
	if _blooms.is_empty():
		return INVALID_CATALYST_POSITION
	return _blooms[0].position


func get_nearest_catalyst_position(
	local_origin: Vector2,
	maximum_distance_pixels: float = 0.0,
	require_clear_path: bool = true
) -> Vector2:
	var nearest_position := INVALID_CATALYST_POSITION
	var nearest_distance_squared := (
		INF
		if maximum_distance_pixels <= 0.0
		else maximum_distance_pixels * maximum_distance_pixels
	)
	for seed in _seeds:
		var distance_squared := local_origin.distance_squared_to(seed.position)
		if distance_squared >= nearest_distance_squared:
			continue
		if require_clear_path and territory_field != null and not territory_field.is_growth_path_clear(
			local_origin,
			seed.position
		):
			continue
		nearest_distance_squared = distance_squared
		nearest_position = seed.position
	for bloom in _blooms:
		var distance_squared := local_origin.distance_squared_to(bloom.position)
		if distance_squared >= nearest_distance_squared:
			continue
		if require_clear_path and territory_field != null and not territory_field.is_growth_path_clear(
			local_origin,
			bloom.position
		):
			continue
		nearest_distance_squared = distance_squared
		nearest_position = bloom.position
	return nearest_position


func damage_nearest_catalyst(
	local_origin: Vector2,
	radius_pixels: float,
	damage: float
) -> bool:
	if damage <= 0.0:
		return false
	var nearest_kind := -1
	var nearest_index := -1
	var nearest_distance_squared := radius_pixels * radius_pixels
	for index in range(_seeds.size()):
		var seed := _seeds[index]
		var distance_squared := local_origin.distance_squared_to(seed.position)
		if distance_squared > nearest_distance_squared:
			continue
		if territory_field != null and not territory_field.is_growth_path_clear(
			local_origin,
			seed.position
		):
			continue
		nearest_kind = CatalystKind.SEED
		nearest_index = index
		nearest_distance_squared = distance_squared
	for index in range(_blooms.size()):
		var bloom := _blooms[index]
		var distance_squared := local_origin.distance_squared_to(bloom.position)
		if distance_squared > nearest_distance_squared:
			continue
		if territory_field != null and not territory_field.is_growth_path_clear(
			local_origin,
			bloom.position
		):
			continue
		nearest_kind = CatalystKind.BLOOM
		nearest_index = index
		nearest_distance_squared = distance_squared
	if nearest_index < 0:
		return false

	if nearest_kind == CatalystKind.SEED:
		var seed := _seeds[nearest_index]
		if seed.shield_charges > 0:
			# Hard Husk and Patient Zero: the hit is shrugged off entirely rather
			# than softened, so one Saboteur cannot chip a Seed down through it.
			seed.shield_charges -= 1
			seed.hit_flash_remaining = 0.16
			queue_redraw()
			return true
		seed.health -= damage
		seed.hit_flash_remaining = 0.16
		if seed.health <= 0.0:
			var destroyed_position := seed.position
			_seeds.remove_at(nearest_index)
			catalyst_destroyed.emit(CatalystKind.SEED, destroyed_position)
	else:
		var bloom := _blooms[nearest_index]
		bloom.health -= damage
		bloom.hit_flash_remaining = 0.16
		if bloom.health <= 0.0:
			var destroyed_position := bloom.position
			_blooms.remove_at(nearest_index)
			catalyst_destroyed.emit(CatalystKind.BLOOM, destroyed_position)
	queue_redraw()
	return true


func clear_effects() -> void:
	_injections.clear()
	_last_germinated_seed_id = -1
	_seeds.clear()
	_blooms.clear()
	_pulses.clear()
	_splatters.clear()
	_tethers.clear()
	_isolated_colonies.clear()
	_isolated_colony_reserves.clear()
	_root_vessels.clear()
	_root_reserves.clear()
	_root_mat = PackedVector2Array()
	_root_mat_strength = 0.0
	_root_surge_remaining = 0.0
	_overgrow_aim_active = false
	queue_redraw()


func toggle_annotations() -> bool:
	show_annotations = not show_annotations
	queue_redraw()
	return show_annotations



func spawn_injection(
	positions: PackedVector2Array,
	directions: PackedVector2Array,
	mass: float,
	pressure: float,
	cohesion: float,
	duration: float
) -> void:
	if positions.is_empty():
		return
	var injection := InjectionVisual.new()
	injection.positions = positions
	injection.directions = directions
	injection.mass = maxf(0.0, mass)
	injection.pressure = maxf(0.0, pressure)
	injection.cohesion = maxf(0.0, cohesion)
	injection.duration = maxf(0.05, duration)
	_injections.append(injection)
	queue_redraw()


func get_injection_visual_count() -> int:
	return _injections.size()


func _draw_injections() -> void:
	for injection in _injections:
		var progress := clampf(injection.age / injection.duration, 0.0, 1.0)
		var fade := 1.0 - progress * progress
		var total := injection.mass + injection.pressure + injection.cohesion
		if total <= 0.0:
			continue
		for index in range(injection.positions.size()):
			var origin: Vector2 = injection.positions[index]
			var outward: Vector2 = (
				injection.directions[index]
				if index < injection.directions.size()
				else Vector2.ZERO
			)
			if injection.mass > 0.0:
				# Material arriving: a bead that swells at the border and settles.
				var swell := injection_mass_radius * (injection.mass / total)
				var eased := sin(progress * PI)
				draw_circle(
					origin + outward * swell * progress * 0.5,
					maxf(0.6, swell * eased),
					Color(injection_mass_color, fade * 0.85),
					true,
					-1.0,
					true
				)
			if injection.pressure > 0.0 and outward != Vector2.ZERO:
				# A shove: a chevron that leaves the border and travels outward, so
				# the axis reads as motion rather than as a colour.
				var reach := injection_pressure_reach * (injection.pressure / total)
				var tip := origin + outward * reach * progress
				var across := outward.orthogonal() * injection_pressure_width
				var trail := outward * injection_pressure_width * 1.6
				var chevron := PackedVector2Array([
					tip,
					tip - trail + across,
					tip - trail * 0.45,
					tip - trail - across,
				])
				draw_colored_polygon(
					chevron, Color(injection_pressure_color, fade * 0.95)
				)
			if injection.cohesion > 0.0 and outward != Vector2.ZERO:
				# Knitting: short stitches laid *along* the border rather than across
				# it, brightening as they close. Tangential on purpose — nothing else
				# in the game draws along the frontier, so the axis owns the read.
				var along := outward.orthogonal()
				var stitch := injection_cohesion_length * (injection.cohesion / total)
				var closing := 1.0 - absf(1.0 - progress * 2.0)
				var half := along * stitch * (0.35 + 0.65 * closing)
				draw_line(
					origin - half,
					origin + half,
					Color(injection_cohesion_color, fade * 0.95),
					injection_cohesion_thickness,
					true
				)
				draw_circle(
					origin,
					injection_cohesion_thickness * 0.9,
					Color(injection_cohesion_color, fade * 0.7),
					true,
					-1.0,
					true
				)


func _spawn_pulse(
	local_position: Vector2,
	duration: float,
	maximum_radius: float,
	color: Color,
	hostile: bool = false
) -> void:
	var pulse := PulseVisual.new()
	pulse.position = local_position
	pulse.duration = duration
	pulse.maximum_radius = maximum_radius
	pulse.color = color
	pulse.hostile = hostile
	_pulses.append(pulse)


func _friendly_scale() -> float:
	# One guarded read, so every consumer stays a legible line and none of them has
	# to know whether the settings node is present.
	return 1.0 if display_settings == null else display_settings.get_friendly_effect_scale()


func _telegraph_alpha_scale() -> float:
	return 1.0 if display_settings == null else display_settings.get_telegraph_alpha_scale()


func _telegraph_width_bonus() -> float:
	return 0.0 if display_settings == null else display_settings.get_telegraph_width_bonus()


func _territory_detail_scale() -> float:
	return 1.0 if display_settings == null else display_settings.get_territory_detail_scale()


func _draw_occluded_arc(
	center: Vector2,
	radius: float,
	color: Color,
	width_bonus: float = 0.0
) -> void:
	var width := 3.0 + maxf(0.0, width_bonus)
	if territory_field == null:
		draw_arc(center, radius, 0.0, TAU, 64, color, width, true)
		return

	var segment_count := 64
	var previous_point := center + Vector2(radius, 0.0)
	var previous_visible := territory_field.is_growth_path_clear(center, previous_point)
	for segment in range(1, segment_count + 1):
		var angle := TAU * float(segment) / float(segment_count)
		var point := center + Vector2.from_angle(angle) * radius
		var visible := territory_field.is_growth_path_clear(center, point)
		if previous_visible and visible:
			draw_line(previous_point, point, color, width, true)
		previous_point = point
		previous_visible = visible


func _draw_annotation(local_position: Vector2, label: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 11
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var background_rect := Rect2(local_position, text_size + Vector2(14.0, 9.0))
	draw_rect(background_rect, Color(0.025, 0.035, 0.050, 0.82), true)
	draw_rect(background_rect, Color(color, 0.52), false, 1.0, true)
	draw_string(
		font,
		local_position + Vector2(7.0, text_size.y + 1.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		color
	)


func _draw_catalyst_durability(
	local_position: Vector2,
	radius: float,
	health: float,
	maximum_health: float,
	hit_flash_remaining: float
) -> void:
	if hit_flash_remaining > 0.0:
		draw_arc(
			local_position,
			radius + 8.0,
			0.0,
			TAU,
			24,
			Color(1.0, 0.35, 0.48, clampf(hit_flash_remaining / 0.16, 0.0, 1.0)),
			3.0,
			true
		)
	if health >= maximum_health:
		return
	var bar_width := radius * 1.8
	var bar_position := local_position + Vector2(-bar_width * 0.5, radius + 7.0)
	draw_rect(Rect2(bar_position, Vector2(bar_width, 3.0)), Color(0.03, 0.03, 0.04, 0.9), true)
	draw_rect(
		Rect2(
			bar_position,
			Vector2(bar_width * clampf(health / maximum_health, 0.0, 1.0), 3.0)
		),
		Color("b5ff69"),
		true
	)
