class_name TerritoryPrototypeOverlay
extends Node2D

signal seed_germinated(local_position: Vector2)
signal seed_germinated_with_context(local_position: Vector2, chain_depth: int)
signal bloom_detonated(
	local_position: Vector2,
	chain_depth: int,
	source_tag: int,
	strength: float
)
## A charging Bloom was destroyed by something hostile before it opened. Separate
## from catalyst_destroyed because the relic that answers it needs the dead Bloom's
## source tag, and only a Bloom has one.
signal bloom_interrupted(local_position: Vector2, source_tag: int, strength: float)
## A charging Seed or Bloom was destroyed before it opened. Carries the Seed's own
## id so a relic can tell a Seed it created apart from an ordinary one; Blooms have
## no stable identity and report -1.
signal catalyst_destroyed(catalyst_kind: int, local_position: Vector2, catalyst_id: int)
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
	## A Seed one relic has singled out, which the player has to be able to pick
	## out of a field of ordinary Seeds in order to defend it.
	CLAIMED,
	## A Seed that is materially larger or more valuable than a normal one.
	MAJOR,
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
	## Which way this Seed is lying, so a scattered field of them does not read as one
	## sprite stamped over and over. Taken from the id rather than rolled, so a Seed
	## faces the same way every frame and a replayed run looks identical.
	var facing := 0.0


class BloomVisual:
	var position := Vector2.ZERO
	var remaining := 0.0
	var duration := 0.0
	var chain_depth := 0
	var health := 1.0
	var maximum_health := 1.0
	var hit_flash_remaining := 0.0
	## What made this Bloom. Relic recursion is settled by comparing tags rather than
	## by guessing from position or timing, so every Bloom has to carry one.
	var source_tag := 0
	## Share of a full Bloom this one is worth. A relic that plants a weaker child
	## stamps it here, so the strength travels with the bud rather than being looked
	## up from a table the bud has no way to stay in step with.
	var strength := 1.0

## The shapes the relic pool draws with. Every one is a short deformation, a
## directional streak or a ground pulse, which is what the master document asks
## for in place of a particle emitter per trigger.
enum RelicCue {
	## A fan of separated streams, not a fog cone: Garden Hose.
	SPRAY,
	## Something on the ground that swells before it pays out: Compost Heap.
	HEAP,
	## A pulse that visibly crosses the ground rather than arriving everywhere at
	## once: Feeder Roots, The Hedge's sweep, Rhizome's runner.
	TRAVELLING,
	## A ghosted second image of an effect that just happened: Hybrid Vigor,
	## Miracle-Gro, Twining's repeat.
	GHOST,
	## A directional line thrown from one place to another: Thorn Relay's ping,
	## Petal Scatter, Runner, Whiplash.
	STREAK,
	## A band tightening around a body: Girdling, Cocklebur's burrs.
	BAND,
	## One strong closing motion: Man-Eater, Briar Knot's yank.
	BITE,
}


## The placeholder motifs in assets/placeholder_art, in the order the exported
## texture array holds them. A cue without a motif falls back to its drawn shape,
## so the layer works with no art wired at all.
enum RelicMotif {
	NONE,
	## A soft dab. One is a droplet; a line of them is a spray; a scatter is a
	## puff. Most of the pool is this sprite drawn more than once.
	PARTICLE,
	## The same idea spread wide and soft: a charge, a primed relic.
	GLOW,
	## An expanding wave, and the shape an echo borrows.
	RING,
	## A wave with a bright leading edge, for something travelling outward.
	SHOCKWAVE,
	## A soft taper pointing along the cue's heading.
	STREAK,
	## A small hot accent: a chip off basalt, the head of a fuse.
	SPARK,
	## Radial spokes: a detonation, an eruption, a synchronised volley.
	BURST,
	## A soft spiral, for the effects whose identity is rotation.
	SWIRL,
}


class RelicCueVisual:
	## One relic cue in flight. Held as plain values and drawn from the same pass as
	## every other overlay effect, so a dense chain costs one loop rather than a
	## node per activation.
	var kind := RelicCue.SPRAY
	var position := Vector2.ZERO
	var toward := Vector2.ZERO
	var radius := 0.0
	var age := 0.0
	var duration := 0.0
	## Delay before the accent actually starts, which is how same-frame cues are
	## spread out rather than landing on top of one another.
	var lead_in := 0.0
	## 1.0 for a natural event. A generated echo is clamped below it on the way in,
	## so nothing downstream has to remember to weaken it.
	var intensity := 1.0
	var color := Color.WHITE
	var motif := RelicMotif.NONE
	## Turns per second while the cue plays. Zero holds the sprite on its heading,
	## which is what a streak or a ring wants; a rolling or unwinding effect sets it
	## so the motion is in the drawing rather than in the art.
	var spin := 0.0


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
var _relic_cues: Array[RelicCueVisual] = []
## Cues already started this frame, so several resolving together are spread by the
## authored stagger instead of flashing at once.
var _cues_this_frame := 0
var _cue_frame_remaining := 0.0
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
## Anchor points of the fine root mat, in pairs: a position, then that cell's
## maturity in the x of the following entry. Empty unless the run holds the Root
## path, which is the only build that grows a mat worth drawing.
## Per-component reserves, drawn at the component while the inspect layer is held.

## The release being aimed, drawn only while the player is choosing where to put it.
var _overgrow_aim_active := false
var _overgrow_aim_position := Vector2.ZERO
var _overgrow_aim_radius := 0.0
## The ground a Trial has marked, for the one rule that is about a place. Unlike the
## aim ring this does sit on the battlefield for a whole wave, because the rule it
## belongs to cannot be played at all without knowing which ground it means.
var _trial_mark_active := false
var _trial_mark_position := Vector2.ZERO
var _trial_mark_radius := 0.0
var _trial_mark_held := true

@export_group("Catalyst Art")
## Painted Seed. Optional: without it the Seed falls back to the authored circle.
@export var seed_texture: Texture2D
## The Seed art's visible bounds inside its own image, in 0-1 texture coordinates.
## The painting is not centred in its canvas - its content sits low and right of the
## middle - so the drawing has to be told where the art actually is. Without this the
## sprite would hang below and right of the point the Seed really occupies, and every
## ring, bar and marker drawn at that point would sit off its face.
@export var seed_texture_content := Rect2(0.1775, 0.12125, 0.67625, 0.82125)
## Multiplier on how large the art is drawn against the Seed's own radius. One draws
## the art exactly as wide as the circle it replaces.
@export_range(0.25, 4.0, 0.05) var seed_art_scale := 1.0
## Painted Bloom, on the same terms.
@export var bloom_texture: Texture2D
## The Bloom art is centred in its canvas already, so this is very close to the full
## image. It is still measured rather than assumed, so a repaint that shifts cannot
## quietly pull the sprite off centre.
@export var bloom_texture_content := Rect2(0.0078125, 0.013672, 0.984375, 0.978516)
@export_range(0.25, 4.0, 0.05) var bloom_art_scale := 1.0

@export_group("Relic Cues")
## The band a generated echo's intensity is clamped into. A repeat is recognisably
## the same effect and unmistakably the weaker one.
@export_range(0.1, 1.0, 0.01) var echo_intensity_minimum := 0.70
@export_range(0.1, 1.0, 0.01) var echo_intensity_maximum := 0.85
## How far apart the strongest accents of same-frame cues are pushed.
@export_range(0.0, 0.5, 0.005) var cue_stagger_seconds := 0.05
## Accents past this many in one frame stop being staggered further; beyond it the
## chain is dense enough that spreading it more would just delay it.
@export_range(1, 24, 1) var cue_stagger_limit := 6
@export_range(0.05, 3.0, 0.05) var cue_duration_seconds := 0.42
## Motif art indexed by RelicMotif, skipping NONE. Optional: a cue with no texture
## behind it draws its authored shape instead, so the pool works unwired.
@export var relic_motif_textures: Array[Texture2D] = []

@export_group("Presentation")
## Presentation options. Optional: without it everything is drawn at full strength,
## which is what this did before the settings existed.
@export var display_settings: DisplaySettings

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
		for index in range(_seeds.size() - 1, -1, -1):
			var seed := _seeds[index]
			seed.remaining -= delta
			seed.hit_flash_remaining = maxf(0.0, seed.hit_flash_remaining - delta)
			seed.grant_cooldown = maxf(0.0, seed.grant_cooldown - delta)
			if seed.remaining <= 0.0:
				_open_seed(index)

		for index in range(_blooms.size() - 1, -1, -1):
			var bloom := _blooms[index]
			bloom.remaining -= delta
			bloom.hit_flash_remaining = maxf(0.0, bloom.hit_flash_remaining - delta)
			if bloom.remaining <= 0.0:
				bloom_detonated.emit(
					bloom.position,
					bloom.chain_depth,
					bloom.source_tag,
					bloom.strength
				)
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

		# The stagger window is a frame, not a wall clock: cues that arrive in the
		# same frame share it and the count resets once that frame has passed.
		_cue_frame_remaining -= delta
		if _cue_frame_remaining <= 0.0:
			_cues_this_frame = 0
		for index in range(_relic_cues.size() - 1, -1, -1):
			var cue := _relic_cues[index]
			cue.age += delta
			if cue.age >= cue.lead_in + cue.duration:
				_relic_cues.remove_at(index)

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

	_draw_overgrow_aim()
	_draw_trial_mark()

	for tether in _tethers:
		_draw_tether(tether)

	for splatter in _splatters:
		_draw_splatter(splatter)

	_draw_injections()

	_draw_relic_cues()
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
		if not _draw_catalyst_art(
			bloom_texture,
			bloom_texture_content,
			bloom.position,
			radius * 2.0 * bloom_art_scale,
			Color(1.0, 1.0, 1.0, 1.0)
		):
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
		if bloom_texture == null:
			# The chevron is the authored Bloom's petal shorthand. The painting has
			# petals of its own, so this would only sit on top of them.
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
		var seed_painted := _draw_catalyst_art(
			seed_texture,
			seed_texture_content,
			seed.position,
			radius * 2.0 * seed_art_scale,
			Color(1.0, 1.0, 1.0, 1.0),
			seed.facing
		)
		if not seed_painted:
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
		if not seed_painted:
			# The little sprout is shorthand for a Seed on the authored circle. The
			# painting has its own, so drawing this over it reads as a stray mark.
			draw_line(
				seed.position + Vector2(0.0, -4.0),
				seed.position + Vector2(5.0, -10.0),
				Color("d9ff9c"),
				2.0,
				true
			)
		if seed.marker != SeedMarker.NONE:
			# A relic that claims one particular Seed has to say which one, or the
			# player cannot defend it.
			var marker_color := (
				Color("ffd24a")
				if seed.marker == SeedMarker.MAJOR
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
	# The golden angle, so consecutive Seeds never land on similar facings.
	seed.facing = fmod(float(seed.id) * 2.39996, TAU)
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


func force_germinate_seed(seed_id: int) -> bool:
	## Open one named Seed now, as though its own timer had run out. Domino
	## Germination's cascade is the caller: a forced germination is a real
	## germination, so it goes through the same path and emits the same events
	## rather than being a separate kind of growth nothing else can see.
	for index in range(_seeds.size()):
		if _seeds[index].id == seed_id:
			_open_seed(index)
			queue_redraw()
			return true
	return false


func _open_seed(index: int) -> void:
	var seed := _seeds[index]
	_last_germinated_seed_id = seed.id
	seed_germinated.emit(seed.position)
	seed_germinated_with_context.emit(seed.position, seed.chain_depth)
	_spawn_pulse(seed.position, 0.72, 76.0, Color("9cff63"))
	_seeds.remove_at(index)


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
	durability: float = 1.0,
	source_tag: int = 0,
	strength: float = 1.0
) -> void:
	var bloom := BloomVisual.new()
	bloom.position = local_position
	bloom.duration = maxf(0.05, windup_seconds)
	bloom.remaining = bloom.duration
	bloom.chain_depth = chain_depth
	bloom.maximum_health = maxf(0.01, durability)
	bloom.health = bloom.maximum_health
	bloom.source_tag = source_tag
	bloom.strength = maxf(0.0, strength)
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


func set_trial_mark(local_position: Vector2, radius: float, held: bool) -> void:
	_trial_mark_active = true
	_trial_mark_position = local_position
	_trial_mark_radius = radius
	_trial_mark_held = held
	queue_redraw()


func clear_trial_mark() -> void:
	if not _trial_mark_active:
		return
	_trial_mark_active = false
	queue_redraw()


func _draw_trial_mark() -> void:
	## A dashed ring rather than a solid one, and a faint wash inside it, so a circle
	## the player has to look at for a whole wave never reads as a wall or as a thing
	## they can collide with. The colour is the Trial's own state: gold while the rule
	## is being held, the hostile red once it has been broken.
	if not _trial_mark_active:
		return
	var mark_colour := (
		Color(0.769, 0.604, 0.314, 1.0) if _trial_mark_held else Color(0.43, 0.215, 0.305, 1.0)
	)
	draw_circle(
		_trial_mark_position, _trial_mark_radius, Color(mark_colour, 0.05), true, -1.0, true
	)
	var dashes := 36
	var span := TAU / float(dashes)
	for index in range(dashes):
		var start := float(index) * span
		draw_arc(
			_trial_mark_position,
			_trial_mark_radius,
			start,
			start + span * 0.55,
			6,
			Color(mark_colour, 0.7),
			2.0,
			true
		)


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


func get_active_seed_count() -> int:
	return _seeds.size()


func get_bloom_source_tags() -> PackedInt32Array:
	## What made each Bloom currently charging. The relic bud cap is counted from
	## this rather than from a tally the Bloom director keeps, so a bud a Saboteur
	## destroys frees its slot without anything having to be told.
	var tags := PackedInt32Array()
	for bloom in _blooms:
		tags.append(bloom.source_tag)
	return tags


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
			catalyst_destroyed.emit(CatalystKind.SEED, destroyed_position, seed.id)
	else:
		var bloom := _blooms[nearest_index]
		bloom.health -= damage
		bloom.hit_flash_remaining = 0.16
		if bloom.health <= 0.0:
			var destroyed_position := bloom.position
			var destroyed_tag := bloom.source_tag
			var destroyed_strength := bloom.strength
			_blooms.remove_at(nearest_index)
			catalyst_destroyed.emit(CatalystKind.BLOOM, destroyed_position, -1)
			bloom_interrupted.emit(destroyed_position, destroyed_tag, destroyed_strength)
	queue_redraw()
	return true


func clear_effects() -> void:
	clear_relic_cues()
	_injections.clear()
	_last_germinated_seed_id = -1
	_seeds.clear()
	_blooms.clear()
	_pulses.clear()
	_splatters.clear()
	_tethers.clear()
	_isolated_colonies.clear()
	_isolated_colony_reserves.clear()
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


func spawn_relic_cue(
	kind: int,
	local_position: Vector2,
	radius: float,
	color: Color,
	toward: Vector2 = Vector2.ZERO,
	generated: bool = false,
	source_intensity: float = 1.0,
	motif: int = RelicMotif.NONE,
	spin: float = 0.0
) -> void:
	## Draw one relic cue.
	##
	## `generated` is what makes an echo look like an echo: its intensity is clamped
	## into the authored band and then held below whatever caused it, so a repeat can
	## never out-shout the natural event. Callers do not get to opt out of that,
	## which is the point -- the rule lives here rather than in forty call sites.
	var cue := RelicCueVisual.new()
	cue.kind = kind
	cue.position = local_position
	cue.toward = toward
	cue.radius = maxf(1.0, radius)
	cue.duration = cue_duration_seconds
	cue.color = color
	if generated:
		cue.intensity = minf(
			source_intensity,
			randf_range(echo_intensity_minimum, echo_intensity_maximum) * source_intensity
		)
	else:
		cue.intensity = clampf(source_intensity, 0.0, 1.0)
	cue.motif = motif
	cue.spin = spin
	cue.lead_in = cue_stagger_seconds * float(mini(_cues_this_frame, cue_stagger_limit))
	_cues_this_frame += 1
	_cue_frame_remaining = 0.0001
	_relic_cues.append(cue)


func get_relic_cue_count() -> int:
	return _relic_cues.size()


func get_last_relic_cue_intensity() -> float:
	if _relic_cues.is_empty():
		return 0.0
	return _relic_cues[_relic_cues.size() - 1].intensity


func get_last_relic_cue_lead_in() -> float:
	if _relic_cues.is_empty():
		return 0.0
	return _relic_cues[_relic_cues.size() - 1].lead_in


func clear_relic_cues() -> void:
	_relic_cues.clear()
	_cues_this_frame = 0


func _draw_relic_cues() -> void:
	for cue in _relic_cues:
		if cue.age < cue.lead_in:
			continue
		var progress := clampf((cue.age - cue.lead_in) / maxf(0.0001, cue.duration), 0.0, 1.0)
		var alpha := (1.0 - progress) * cue.intensity * _friendly_scale()
		if alpha <= 0.004:
			continue
		var tint := Color(cue.color, alpha)
		var heading := cue.toward
		if heading.length_squared() <= 0.0001:
			heading = Vector2.RIGHT
		heading = heading.normalized()
		var spun := heading.angle() + cue.spin * TAU * (cue.age - cue.lead_in)
		var motif_texture := _relic_motif_texture(cue.motif)
		if motif_texture != null:
			# The art is eight soft primitives; anything with structure is that art
			# drawn more than once along a path. A spray is one particle down five
			# streams, a travelling pulse is one along its route -- cheaper than a
			# bespoke sprite per relic, and it keeps the pool looking like one family.
			match cue.kind:
				RelicCue.SPRAY:
					for stream in range(5):
						var spread := heading.rotated(deg_to_rad(lerpf(-45.0, 45.0, float(stream) / 4.0)))
						for step in range(4):
							var reach := cue.radius * (0.25 + 0.25 * float(step)) * progress
							_draw_motif(
								motif_texture,
								cue.position + spread * reach,
								spread.angle(),
								cue.radius * 0.22,
								tint
							)
				RelicCue.TRAVELLING:
					for step in range(4):
						var trail := progress - float(step) * 0.10
						if trail <= 0.0:
							continue
						_draw_motif(
							motif_texture,
							cue.position + heading * cue.radius * trail,
							spun,
							cue.radius * 0.20 * (1.0 - float(step) * 0.18),
							Color(tint, tint.a * (1.0 - float(step) * 0.22))
						)
				_:
					_draw_motif(
						motif_texture,
						cue.position,
						spun,
						cue.radius * (0.55 + 0.45 * progress),
						tint
					)
			continue
		match cue.kind:
			RelicCue.SPRAY:
				# Separated streams rather than a cone, so the player can see where
				# each one landed.
				for stream in range(5):
					var angle := deg_to_rad(lerpf(-45.0, 45.0, float(stream) / 4.0))
					var tip := cue.position + heading.rotated(angle) * cue.radius * progress
					draw_line(cue.position, tip, tint, 2.0, true)
			RelicCue.HEAP:
				# Swells before it pays out, so the eruption can be anticipated.
				draw_circle(cue.position, cue.radius * (0.35 + 0.65 * progress), tint)
			RelicCue.TRAVELLING:
				# Crosses the ground rather than appearing along its whole length.
				draw_line(
					cue.position,
					cue.position.lerp(cue.position + heading * cue.radius, progress),
					tint,
					3.0,
					true
				)
			RelicCue.GHOST:
				# A second, weaker image of something that already happened.
				draw_arc(cue.position, cue.radius * (0.8 + 0.2 * progress), 0.0, TAU, 20, tint, 2.0, true)
			RelicCue.STREAK:
				var reach := cue.position + heading * cue.radius
				draw_line(cue.position.lerp(reach, progress * 0.6), reach, tint, 2.5, true)
			RelicCue.BAND:
				# Tightens rather than expands: the target is being constricted.
				draw_arc(cue.position, cue.radius * (1.0 - 0.45 * progress), 0.0, TAU, 18, tint, 2.5, true)
			RelicCue.BITE:
				# One closing motion, not a lingering cloud.
				var closing := cue.radius * (1.0 - progress)
				draw_arc(cue.position, closing, -0.6, 0.6, 10, tint, 3.0, true)
				draw_arc(cue.position, closing, PI - 0.6, PI + 0.6, 10, tint, 3.0, true)


func _draw_motif(
	texture: Texture2D,
	at: Vector2,
	rotation: float,
	extent: float,
	tint: Color
) -> void:
	draw_set_transform(at, rotation, Vector2.ONE)
	draw_texture_rect(
		texture,
		Rect2(Vector2(-extent, -extent) * 0.5, Vector2(extent, extent)),
		false,
		tint
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _relic_motif_texture(motif: int) -> Texture2D:
	if motif <= RelicMotif.NONE:
		return null
	var index := motif - 1
	if index >= relic_motif_textures.size():
		return null
	return relic_motif_textures[index]


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


func _draw_catalyst_art(
	texture: Texture2D,
	content: Rect2,
	centre: Vector2,
	diameter: float,
	tint: Color,
	facing: float = 0.0
) -> bool:
	# Draws a painting so that the middle of what is actually painted lands on the
	# point the catalyst occupies, whatever margin the artist left around it. Both
	# the position and the size are taken from the content box rather than from the
	# image, so the rings and bars drawn at the same point stay concentric with the
	# art and two paintings with different margins still come out the same size.
	if texture == null or diameter <= 0.0:
		return false
	var texture_size := Vector2(texture.get_width(), texture.get_height())
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return false
	var content_pixels := Vector2(
		maxf(1.0, content.size.x * texture_size.x),
		maxf(1.0, content.size.y * texture_size.y)
	)
	# The longer side of the content is what meets the diameter, so a tall painting
	# is not cropped and a wide one does not overhang.
	var art_scale := diameter / maxf(content_pixels.x, content_pixels.y)
	var content_centre := (content.position + content.size * 0.5) * texture_size
	var art_rect := Rect2(-content_centre * art_scale, texture_size * art_scale)
	if is_zero_approx(facing):
		draw_texture_rect(
			texture,
			Rect2(centre + art_rect.position, art_rect.size),
			false,
			tint
		)
		return true
	# Rotating about the content centre rather than the image centre, so a painting
	# with an off-centre subject spins on its own middle instead of orbiting a point
	# beside it. The transform is reset immediately: it applies to every later draw.
	draw_set_transform(centre, facing, Vector2.ONE)
	draw_texture_rect(texture, art_rect, false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


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
