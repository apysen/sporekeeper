class_name PhaseBBloomDirector
extends Node

## Bloom: the automatic Bloom cadence, what a detonation does to territory and
## enemies, and the Bloom-side evolutions. It also owns Super Bloom chain depth
## and the chained telegraph, because a chain is a Bloom even when a Seed armed it.

signal status_requested(message: String)

class Glob:
	## One thrown lump of Plant material in flight. It is the splatter's physics:
	## where it lands is decided by what it crosses, not by a ray measured before it
	## left. Basalt stops it dead, hostile ground drags on it and takes some of its
	## Mass to cross, neutral ground costs a little, and the run's own Green barely
	## slows it at all.
	var active := false
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var mass := 0.0
	## Droplet radius in pixels. Mass follows from it as a volume, and it is what
	## decides how the glob flies: drag acts on area and is resisted by mass, so the
	## ballistic coefficient is proportional to the radius. Fine mist is thrown
	## fastest and stops first; a heavy lump leaves slowly and carries.
	var radius_pixels := 0.0
	## Which generation of a chained Bloom threw this glob, so a Seed it cracks open
	## joins that chain instead of restarting it.
	var chain_depth := 0
	## Obstacle faces this glob has already run down. Bounded so a lump caught in a
	## corner settles instead of grinding along the geometry forever.
	var wall_contacts := 0
	## The face this glob is currently running down, and how long it stays wetted to
	## it. A liquid that has touched a surface clings to it: that is what holds paint
	## against a wall while the rest of its motion carries it along, and without it a
	## glob simply glances off and flies away.
	var wall_normal := Vector2.ZERO
	var wall_cling_remaining := 0.0
	var radius_cells := 0.0
	var conversion := 1.0
	var trail_remaining := 0.0
	var travelled := 0.0

@export_group("Collaborators")
## Evolutions component that owns the tuning for every Evolution this path takes
## part in. The behaviour stays here; the numbers live in one place.
@export var evolutions: PhaseBEvolutions

## Authoritative field that receives Bloom territory commands.
@export var territory_field: TerritoryField
## Overlay that owns visible Bloom telegraphs and burst pulses.
@export var overlay: TerritoryPrototypeOverlay
## Combat component used for targeting, radial damage, and explosion audio.
@export var combat: PhaseBCombatDirector
## Progression component that supplies upgrade, relic, and evolution modifiers.
@export var progression: PhaseBProgression
## Root component supplying the Root Network amplification this path reads.
@export var root_director: PhaseBRootDirector
## Bramble component supplying how deeply this path's effects Entangle.
@export var bramble_director: PhaseBBrambleDirector
## Pruning component asked to collapse Green into a Bloom under the Rebound pairing.
@export var pruning_director: PhaseBPruningDirector

@export_group("Bloom Lines")
## Additive Bloom territory-force and damage multiplier granted by each Bloom Force rank.
@export_range(0.0, 2.0, 0.01) var bloom_force_per_level := 0.25
## Compounding interval multiplier per Bloom Frequency rank; lower produces Blooms faster.
@export_range(0.1, 1.0, 0.01) var bloom_interval_multiplier_per_level := 0.86

@export_group("Automatic Bloom")
## Seconds after a run reset before the first automatic Bloom is planted.
@export_range(0.0, 30.0, 0.5) var first_bloom_delay_seconds := 4.0
## Base seconds between automatic Blooms before Bloom Frequency upgrades apply.
@export_range(1.0, 60.0, 0.5) var bloom_interval_seconds := 13.0
## Short telegraph in seconds between a Bloom charging on the frontier and its burst.
@export_range(0.1, 5.0, 0.05) var bloom_windup_seconds := 0.65
## Base enemy damage at the center of a normal Bloom before upgrades and falloff.
@export_range(1.0, 300.0, 1.0) var bloom_damage := 40.0
## Base damage charging Bloom buds can withstand before a Saboteur destroys them.
@export_range(0.1, 20.0, 0.1) var bloom_durability := 3.0

@export_group("Splatter Flight")
## Droplets one eruption breaks into. A burst of liquid does not throw a handful of
## equal lumps: it atomises into many small droplets and a few large ones.
@export_range(1, 64, 1) var droplet_count := 6
## Share of a Bloom's material left as a puddle at the detonation point instead of
## being thrown. This is the part of the charge that never got airborne, so it is
## the blast's footprint rather than its payload — the thrown droplets are what
## actually takes ground.
@export_range(0.0, 1.0, 0.01) var central_material_share := 0.28
## Radius of that central puddle as a multiple of the Bloom's nominal surge radius.
@export_range(0.05, 1.5, 0.01) var central_radius_scale := 0.34
## Whether more material makes more droplets rather than bigger ones. Droplet size
## in an atomising burst is set by the contest between the disruptive force tearing
## the fluid apart and the surface tension holding it together, not by how much
## fluid there is — so a bigger charge of the same stuff breaks into more pieces of
## much the same size. Turning this off returns to scaling each droplet's radius.
@export var material_scales_droplet_count := true
## Most droplets a single Bloom may break into, whatever its Mass.
@export_range(4, 64, 1) var maximum_droplet_count := 34
## Calibration on the authored droplet size spectrum. The spectrum itself is the
## physics — the range of sizes a burst of this material tears into — and this is
## the one number that maps it onto the arena's scale. This is the size a Bloom
## breaks into with no investment behind it; the run's Mass line grows it.
@export_range(0.05, 2.0, 0.01) var droplet_radius_scale := 0.12
## How strongly droplet size follows the material behind the blast. A burst breaks
## into finer pieces the more energy there is per unit of what it is tearing apart,
## so piling material behind the same detonation lowers the specific energy and the
## breakup coarsens: an invested Bloom throws fatter lumps.
##
## How many pieces it breaks into is then not a free choice — it follows from this
## and from conservation, since the material has to be exactly used up by the
## droplets it became. That makes the coverage a Bloom gains per point of Mass grow
## as the ratio to the power of one minus twice this, which is what keeps an
## invested Bloom from running away with the arena.
@export_range(0.0, 0.33, 0.01) var droplet_size_material_exponent := 0.25
## Largest droplet radius in pixels, before Mass scales the whole burst.
@export_range(1.0, 160.0, 0.5) var droplet_maximum_radius := 58.0
## Smallest droplet radius in pixels.
@export_range(0.5, 80.0, 0.5) var droplet_minimum_radius := 13.0
## Shapes the size distribution. Above one produces mostly fine mist with a few
## heavy globs, which is what a burst of paint actually looks like; at one the
## sizes are spread evenly.
@export_range(0.2, 6.0, 0.05) var droplet_size_bias := 2.10
## Energy the blast puts into every unit of Mass it throws. Specific energy, not
## total: an explosion accelerates the material it touches to a common speed
## (v = sqrt(2E)), and it is drag afterwards that sorts the droplets out. Giving
## each droplet the same total energy instead makes mist the fastest thing on the
## field and leaves the heavy globs sitting at the origin, which is backwards.
@export_range(100.0, 400000.0, 100.0) var blast_specific_energy := 190000.0
## How much faster the finest droplets leave than the heavy ones. Small droplets
## couple to the expanding gas a little better; this is a lean on that, not the
## mechanism that decides range.
@export_range(0.0, 1.0, 0.01) var droplet_speed_size_bias := 0.18
## Air drag coefficient. Deceleration scales with speed squared and inversely with
## droplet radius, because drag acts on cross-section while momentum scales with
## volume. This is the whole reason mist falls short and heavy globs carry.
@export_range(0.0, 4.0, 0.001) var air_drag_coefficient := 0.055
## Reference radius in pixels at which terrain drag is felt at full strength. A
## droplet smaller than this is stopped more easily by what it crosses; a heavier
## one plows through.
@export_range(0.5, 40.0, 0.5) var terrain_drag_reference_radius := 8.0
## Pixels per second a thrown glob leaves the eruption with, before Force scales it.
@export_range(50.0, 2000.0, 10.0) var glob_launch_speed := 620.0
## Seconds a glob may stay in the air before it lands wherever it is.
@export_range(0.05, 4.0, 0.05) var glob_flight_seconds := 0.55
## Drag per second applied while a glob crosses fully hostile ground. This is what
## makes a Bloom thrown into the invasion fall short of one thrown across open
## ground, without either case being written down.
@export_range(0.0, 40.0, 0.1) var hostile_drag_per_second := 7.5
## Drag per second over unclaimed ground.
@export_range(0.0, 40.0, 0.1) var neutral_drag_per_second := 2.6
## Drag per second over the run's own Green. Paint slides on wet paint.
@export_range(0.0, 40.0, 0.1) var green_drag_per_second := 0.7
## Share of its speed a glob keeps each time it runs down an obstacle. Only the
## motion along the face survives a hit at all; this is the rest of what the impact
## costs it. High because these faces are meant to be slippery — paint runs down
## basalt rather than gripping it.
@export_range(0.0, 1.0, 0.01) var wall_slide_retention := 0.88
## How much of the motion driving into a face comes back out of it. Paint is not
## bouncy, so this stays near zero; a little keeps globs from hugging the surface.
@export_range(0.0, 1.0, 0.01) var wall_restitution := 0.06
## How hard a wetted glob is held against the face it is running down, in pixels
## per second squared. This stands in for what gravity does to paint on a wall: it
## is what keeps the material on the surface while the rest of its motion carries it
## along, instead of letting it glance off into open ground.
@export_range(0.0, 4000.0, 10.0) var wall_cling_acceleration := 900.0
## How much closer together a glob lays its trail while it is running down a face.
## Material on a surface leaves a continuous streak rather than the spaced droplets
## of something in free flight, and that streak is most of what a wall hit paints.
@export_range(0.05, 1.0, 0.05) var wall_streak_spacing_scale := 0.55
## How long a glob stays wetted to a face after touching it.
@export_range(0.0, 4.0, 0.05) var wall_cling_seconds := 0.85
## How square-on a contact has to be before it marks the face at all. A glob that
## merely grazes a rock leaves its streak and carries on; stamping a splat for every
## glancing touch costs the frame far more than it shows.
@export_range(0.0, 1.0, 0.01) var minimum_face_splash_share := 0.22
## Obstacle faces one glob may run down before it settles. Without a bound a lump
## caught in a corner can grind along the geometry indefinitely.
@export_range(0, 12, 1) var maximum_wall_contacts := 4
## Cells a glob is held off a face after hitting it, so the next step begins in open
## ground instead of colliding with the same cell again.
@export_range(0.1, 3.0, 0.1) var wall_clearance_cells := 0.7
## Speed in pixels per second below which a glob has run out of throw and lands.
@export_range(1.0, 400.0, 1.0) var glob_landing_speed := 90.0
## How much a landing is stretched along its own travel per pixel per second of
## impact speed. Paint that arrives with speed runs on; paint that has stopped
## puddles where it is.
@export_range(0.0, 0.02, 0.0001) var landing_smear_per_speed := 0.0042
## Longest a landing may be stretched, so a fast glob smears rather than painting a
## line across the arena.
@export_range(1.0, 8.0, 0.1) var maximum_landing_smear := 3.4
## Outward Pressure a landing carries per pixel per second of impact speed. This is
## what makes a landed splat visibly shove the border it lands on.
@export_range(0.0, 0.2, 0.001) var landing_pressure_per_speed := 0.028
## Maturity a landing knocks out of the ground per unit of momentum it arrives
## with. Established territory resists conversion, so without this a glob thrown
## into an old hostile front is absorbed by it; with it the impact breaks the
## ground up first and the Green that follows has something to take.
@export_range(0.0, 4.0, 0.005) var impact_maturity_break := 0.220
## Multiplier on the Mass a glob actually delivers when it lands. The flight spends
## material on its trail, and the landing is meant to be the part you can see.
@export_range(0.1, 24.0, 0.1) var landing_mass_scale := 6.0
## Maturity thrown paint is allowed to have where it lands. Zero on purpose: a
## glob is wet material sitting on top of the ground, not territory that has grown
## there, so the Green it wins has no root behind it and the hostile front around
## it takes the ground back on its own unless the run follows the throw up.
@export_range(0.0, 1.0, 0.01) var landing_maturity_ceiling := 0.0
## Maturity a landing adds to ground the run already holds, before the run's own
## Maturation is counted. Thrown material that comes down on established growth
## settles into it and thickens it, so a Bloom fired over its own territory
## reinforces that ground instead of stripping it.
@export_range(0.0, 1.0, 0.005) var landing_maturity_reinforcement := 0.075
## How far a glob spreads when it hits the ground, as a multiple of the radius it
## had in the air. A droplet does not stay droplet-sized on impact: it flattens out
## across the surface into a splat several times its own diameter, which is why a
## thrown handful of paint marks a wall far wider than the handful was.
@export_range(1.0, 12.0, 0.1) var landing_spread_scale := 3.2
## Extra spread per root of impact speed. Splat width grows with the Weber number
## of the impact — the ratio of the droplet's momentum to the surface tension
## holding it together — so paint that arrives fast flattens further than paint
## that has already run out of throw.
@export_range(0.0, 1.0, 0.005) var landing_spread_per_root_speed := 0.055
## Pixels between the trail splats a glob leaves behind it in flight. The streak is
## the trail of a real object now rather than splats placed along a sampled ray.
@export_range(0.0, 400.0, 1.0) var glob_trail_spacing := 34.0
## Share of the glob's current Mass each trail splat spends.
@export_range(0.0, 1.0, 0.01) var glob_trail_mass_share := 0.16
## Globs in flight at once across every Bloom.
@export_range(4, 256, 1) var glob_pool_size := 160

@export_group("Splatter")
## Bloom Mass multiplier applied on top of the run's Photosynthesis. Mass decides
## how much material is thrown: central splat size, glob size, resulting territory
## thickness, and whether satellite patches survive at all.
@export_range(0.0, 4.0, 0.05) var bloom_mass_multiplier := 1.00
## Bloom Force multiplier applied on top of the run's Meristem. Force decides how
## far the splatter travels, how elongated it is, and how hard it shoves.
@export_range(0.0, 4.0, 0.05) var bloom_force_multiplier := 1.00

var _late_bloomer_windup := 1.0
var _late_bloomer_maximum_bonus := 0.0
var _bloom_remaining := 0.0
var _super_bloom_count := 0
var _flowering_charge := 0.0
var _echo_bloom_remaining := 0.0
var _echo_bloom_origin := Vector2(-1.0, -1.0)
var _globs: Array[Glob] = []
var _inoculation_remaining := 0
var _inoculation_openings := 0
var _globs_landed := 0
var _globs_launched := 0

func _ready() -> void:
	assert(territory_field != null, "PhaseBBloomDirector requires TerritoryField")
	assert(overlay != null, "PhaseBBloomDirector requires TerritoryPrototypeOverlay")
	assert(combat != null, "PhaseBBloomDirector requires PhaseBCombatDirector")
	assert(progression != null, "PhaseBBloomDirector requires PhaseBProgression")
	combat.briar_trap_detonated.connect(_on_briar_trap_detonated)
	overlay.bloom_detonated.connect(on_bloom_detonated)

func set_relic_rules(windup_multiplier: float, maximum_bonus: float) -> void:
	# Late Bloomer is a change to the Bloom's own timing rule, so it lives on the
	# Bloom component rather than being simulated from outside.
	_late_bloomer_windup = maxf(1.0, windup_multiplier)
	_late_bloomer_maximum_bonus = maxf(0.0, maximum_bonus)

func get_windup_seconds() -> float:
	return bloom_windup_seconds * _late_bloomer_windup

func get_late_bloomer_bonus() -> float:
	# The Bloom gathers Force and Conversion for exactly as long as the longer
	# wind-up made it wait, and no further: the bonus is capped by design.
	if _late_bloomer_windup <= 1.0:
		return 0.0
	var charged := (_late_bloomer_windup - 1.0) / maxf(0.001, _late_bloomer_windup)
	return _late_bloomer_maximum_bonus * clampf(charged, 0.0, 1.0)

func reset_director() -> void:
	_configure_globs()
	for glob in _globs:
		glob.active = false
	_globs_landed = 0
	_inoculation_remaining = 0
	_inoculation_openings = 0
	_globs_launched = 0
	_bloom_remaining = first_bloom_delay_seconds
	_super_bloom_count = 0
	_flowering_charge = 0.0
	_echo_bloom_remaining = 0.0
	_echo_bloom_origin = Vector2(-1.0, -1.0)

func advance(delta: float) -> void:
	_advance_globs(delta)
	_advance_echo_blooms(delta)
	_advance_flowering_season(delta)
	if not progression.has_path_active(PhaseBProgression.PathId.BLOOM):
		_bloom_remaining = first_bloom_delay_seconds
		return
	_bloom_remaining -= delta
	if _bloom_remaining > 0.0:
		return
	# A Bloom is the existing ecosystem erupting outward, so it roots on the
	# player's own border facing the nearest threat rather than at the threat
	# itself. Colonising ground the player does not hold is the Seed's job.
	var origin := territory_field.find_player_frontier_near(combat.get_target_position())
	if origin.x >= 0.0 and territory_field.is_claimable_at_local(origin):
		overlay.plant_bloom(origin, get_windup_seconds(), 0, bloom_durability)
		status_requested.emit("Bloom charging on the Green frontier facing the threat.")
	_bloom_remaining = bloom_interval_seconds * get_bloom_interval_multiplier()

func plant_chained_bloom(local_position: Vector2, chain_depth: int) -> bool:
	# Super Bloom's chain: a germination asks for the next generation, and the
	# Bloom director decides whether the chain still has room to grow.
	if chain_depth > get_maximum_chain_depth():
		return false
	overlay.plant_bloom(
		local_position,
		evolutions.chained_bloom_windup_seconds,
		chain_depth,
		bloom_durability
	)
	return true

func get_maximum_chain_depth() -> int:
	# Deep Cascade lets a Super Bloom chain propagate one generation further.
	if progression.get_evolution_upgrade_level() >= 2:
		return evolutions.maximum_chain_depth + 1
	return evolutions.maximum_chain_depth

func get_flowering_charge() -> float:
	return _flowering_charge

func _advance_flowering_season(delta: float) -> void:
	# Flowering Season: mature ground stores up to a mass flowering that spends the
	# very maturity that produced it, which Root then regrows.
	if not progression.has_active_evolution(
		PhaseBProgression.EvolutionId.FLOWERING_SEASON
	):
		_flowering_charge = 0.0
		return
	_flowering_charge += territory_field.get_mature_player_percent() * delta
	if _flowering_charge < evolutions.flowering_season_charge_required:
		return
	_flowering_charge = 0.0
	var rank := progression.get_evolution_upgrade_level()
	# Distributed Flowering spreads the sites across the frontier instead of
	# clustering them near one anchor.
	var spread_pixels := 180.0
	if rank >= 3:
		spread_pixels = evolutions.flowering_season_distributed_spread_pixels
	var planted := 0
	var anchor := combat.get_target_position()
	var last_origin := Vector2(-1.0, -1.0)
	for index in range(evolutions.flowering_season_bloom_count):
		var origin := territory_field.find_mature_player_frontier_near(
			anchor + Vector2.from_angle(float(index) * 2.39996) * spread_pixels
				* (1.0 + float(index) * 0.35 if rank >= 3 else 1.0)
		)
		if origin.x < 0.0:
			continue
		last_origin = origin
		overlay.plant_bloom(origin, bloom_windup_seconds, 0, bloom_durability)
		territory_field.queue_maturity_suppression(
			origin,
			evolutions.flowering_season_maturity_cost,
			1.0
		)
		planted += 1
	if planted > 0:
		status_requested.emit(
			"FLOWERING SEASON — %d Blooms opened across mature ground." % planted
		)
		if rank >= 5:
			_echo_bloom_remaining = evolutions.flowering_season_echo_delay_seconds
			_echo_bloom_origin = last_origin

func _advance_echo_blooms(delta: float) -> void:
	# Second Spring: Echo Blooms push and deform existing Green and inject no new
	# Plant Mass, so Seeds stay the only real source of new territory.
	if _echo_bloom_remaining <= 0.0:
		return
	_echo_bloom_remaining -= delta
	if _echo_bloom_remaining > 0.0:
		return
	var anchor := _echo_bloom_origin
	if anchor.x < 0.0:
		return
	var expansion := progression.get_expansion_multiplier()
	var force := (
		get_bloom_force_multiplier()
		* evolutions.seasonal_surge_echo_force
	)
	var echoed := 0
	for index in range(evolutions.seasonal_surge_echo_count):
		var origin := territory_field.find_mature_player_frontier_near(
			anchor + Vector2.from_angle(float(index) * 1.9) * 120.0
		)
		if origin.x < 0.0:
			continue
		territory_field.queue_bloom(
			origin,
			0.0,
			force,
			progression.get_conversion_multiplier(),
			sqrt(expansion)
		)
		overlay.spawn_bloom(origin)
		echoed += 1
	if echoed > 0:
		status_requested.emit(
			"SECOND SPRING — %d Echo Blooms shove the frontier outward." % echoed
		)

func _harvest_bramble_into_traps(local_position: Vector2, bloom_radius_pixels: float) -> void:
	# Thornburst: the Bloom converts the Bramble already covering the ground into a
	# minefield and scatters it through the territory it is claiming. Area is the
	# input, so the harvest no longer depends on a frontier standing in the blast.
	if not progression.has_active_evolution(PhaseBProgression.EvolutionId.THORNBURST):
		return
	var harvest := territory_field.harvest_bramble_in_radius(
		local_position,
		bloom_radius_pixels
	)
	if harvest.amount <= 0.0:
		return
	var payload_rank := progression.get_evolution_upgrade_level()
	var trap_yield := 1.0
	if payload_rank >= 1:
		trap_yield += evolutions.briar_payload_trap_yield
	var trap_count := clampi(
		int(floor(harvest.amount * trap_yield / maxf(0.01, evolutions.briar_trap_power_per_trap))),
		1,
		evolutions.briar_trap_maximum
	)
	var maturity := clampf(harvest.average_maturity, 0.0, 1.0)
	# Evolutions are where Bramble's control turns into damage, so trap damage is
	# authored here and amplified by the ground it was harvested from rather than by
	# a Thorn Damage line the path no longer has.
	var trap_damage := evolutions.briar_trap_damage * (1.0 + evolutions.briar_trap_maturity_bonus * maturity)
	var trap_entanglement := clampf(
		evolutions.briar_trap_entanglement * bramble_director.get_entanglement_multiplier(),
		0.0,
		1.0
	)
	var expansion := progression.get_expansion_multiplier()
	# Traps are scattered through the ground the Bloom is claiming, using a
	# deterministic spiral so a replayed run places them identically.
	var placed := 0
	for index in range(trap_count):
		var angle := float(index) * 2.39996
		var spread := sqrt(float(index + 1) / float(trap_count + 1))
		var trap_position := local_position + Vector2.from_angle(angle) * (
			bloom_radius_pixels * spread * 0.75
		)
		if not territory_field.is_growth_path_clear(local_position, trap_position):
			continue
		if combat.spawn_briar_trap(
			trap_position,
			evolutions.briar_trap_radius_pixels * sqrt(expansion),
			evolutions.briar_trap_duration_seconds,
			trap_damage,
			trap_entanglement
		):
			placed += 1
	if placed > 0:
		status_requested.emit(
			"THORNBURST — %d Bramble cells harvested into %d Briar Trap(s)."
			% [harvest.cell_count, placed]
		)

func on_bloom_detonated(local_position: Vector2, chain_depth: int) -> void:
	combat.play_plant_explosion_sfx()
	var is_super_bloom := chain_depth > 0
	# Root Network: a Bloom erupting out of Mature ground pushes harder than one
	# opening on ground the run only just claimed.
	var force := get_bloom_force_multiplier() * (
		1.0
		+ root_director.get_network_bonus()
		* territory_field.get_maturity_at_local(local_position)
	)
	var expansion := progression.get_expansion_multiplier()
	var super_multiplier := evolutions.chained_bloom_multiplier if is_super_bloom else 1.0
	var cascade_rank := 0
	if progression.has_active_evolution(PhaseBProgression.EvolutionId.SUPER_BLOOM):
		cascade_rank = progression.get_evolution_upgrade_level()
	var grand_scale := 1.0
	if is_super_bloom:
		# Cascade Force: a chained Bloom keeps more of the Force that spawned it,
		# and none of the Plant Mass, so chains stay spectacle rather than economy.
		if cascade_rank >= 1:
			super_multiplier += evolutions.floral_cascade_force_per_rank
		if cascade_rank >= 4:
			super_multiplier += evolutions.floral_cascade_force_per_rank
		_super_bloom_count += 1
		if (
			cascade_rank >= 3
			and evolutions.floral_cascade_germination_cadence > 0
			and _super_bloom_count % evolutions.floral_cascade_germination_cadence == 0
		):
			if overlay.germinate_nearest_seed(local_position, evolutions.forced_germination_radius):
				status_requested.emit("FORCED GERMINATION — a Seed cracks open early.")
		if (
			cascade_rank >= 5
			and evolutions.floral_cascade_grand_cadence > 0
			and _super_bloom_count % evolutions.floral_cascade_grand_cadence == 0
		):
			grand_scale = evolutions.floral_cascade_grand_scale
			status_requested.emit("GRAND BLOOM — the chain erupts far wider than usual.")
	var bloom_radius_pixels := (
		territory_field.tuning.bloom_radius_cells
		* (territory_field.tuning.arena_size.x / float(territory_field.tuning.field_size.x))
		* sqrt(expansion)
	)
	# Harvest before the Bloom lands, so the Traps are sown into the ground the
	# Bloom is about to claim rather than into the border it is about to move.
	_harvest_bramble_into_traps(local_position, bloom_radius_pixels)
	if pruning_director != null:
		# Rebound: the ecosystem collapses inward first, and the mass it gives up
		# comes back out as Force rather than as new Plant Mass.
		force += pruning_director.prune_for_rebound(local_position)
	# Mass and Force are kept physically distinct. Mass is how much material is
	# thrown; Force is how far and how hard it goes. A Grand Bloom widens area and
	# Force only: it must not become a better source of new Green than a Seed.
	var late_bonus := get_late_bloomer_bonus()
	var mass := get_bloom_mass_multiplier() * super_multiplier
	var throw := force * super_multiplier * (1.0 + late_bonus)
	_splatter(
		local_position,
		mass,
		throw,
		bloom_radius_pixels * grand_scale,
		grand_scale,
		chain_depth
	)
	var pixels_per_cell := (
		territory_field.tuning.arena_size.x / float(territory_field.tuning.field_size.x)
	)
	combat.damage_enemies_in_radius(
		local_position,
		territory_field.tuning.bloom_radius_cells * pixels_per_cell * sqrt(expansion),
		bloom_damage * force * super_multiplier,
		PhaseBCombatDirector.DeathSource.SUPER_BLOOM
			if is_super_bloom
			else PhaseBCombatDirector.DeathSource.BLOOM,
		chain_depth
	)
	status_requested.emit(
		"Super Bloom detonated; wall-shadowed ground remains untouched."
		if is_super_bloom
		else "Bloom splattered: central splat, globs, satellites, and streaks."
	)

func get_landing_maturity_reinforcement() -> float:
	# How much thrown material roots when it settles onto growth the run already
	# holds. This rides Maturation rather than Mass, because Maturation is the
	# ecosystem's own capacity to put down roots and this is that capacity acting on
	# material the Bloom delivered. Mass already buys the splatter its coverage, so
	# the two lines stay distinct: Mass decides how much ground a Bloom reaches,
	# Maturation decides how well what it lands on holds.
	return landing_maturity_reinforcement * progression.get_maturation_multiplier()


func get_bloom_mass_multiplier() -> float:
	# Bloom Mass rides Photosynthesis, because Mass is what the ecosystem is making.
	return bloom_mass_multiplier * progression.get_mass_multiplier()

func get_bloom_force_multiplier() -> float:
	# Bloom Force rides Meristem and the Bloom Force line, because Force is how
	# eagerly the material moves.
	return (
		bloom_force_multiplier
		* get_bloom_force_line_multiplier()
		* progression.get_pressure_multiplier()
	)

func _splatter(
	local_position: Vector2,
	mass: float,
	throw: float,
	central_radius_pixels: float,
	grand_scale: float,
	chain_depth: int
) -> void:
	# A Bloom is a violent paint splatter, not one expanding circle and not one
	# stamped decal. It resolves into a large central splat, several gameplay globs,
	# smaller satellites that may land as isolated Green, and directional streaks
	# along whichever rays the arena actually leaves open. Each of those injects
	# real Mass and Force; the final shape is whatever the simulation makes of them.
	var tuning := territory_field.tuning
	var pixels_per_cell := tuning.arena_size.x / float(tuning.field_size.x)
	var central_radius_cells := central_radius_pixels / maxf(0.001, pixels_per_cell)
	var conversion := progression.get_conversion_multiplier() * (
		1.0 + get_late_bloomer_bonus()
	)

	# A Bloom's material is finite, so it is divided rather than duplicated: what
	# stays behind as the puddle is material the throw does not get. The puddle is
	# the part of the charge that never became airborne — the blast's footprint,
	# not its payload. The thrown droplets are what actually takes ground, because
	# they are the only part of a Bloom that arrives with momentum, and momentum is
	# what lets it break established ground instead of negotiating with it.
	var central_share := clampf(central_material_share, 0.0, 1.0)
	var central_mass := mass * central_share
	var thrown_mass := mass * (1.0 - central_share)
	if central_mass > 0.0:
		territory_field.queue_bloom(
			local_position,
			central_mass,
			throw,
			conversion,
			(central_radius_cells * central_radius_scale)
			/ maxf(0.001, tuning.bloom_radius_cells)
		)

	# Everything past the central surge is atomised, not placed. A burst of liquid
	# does not come apart into a handful of equal lumps: it breaks into a spectrum,
	# mostly fine mist with a few heavy globs. Each droplet's Mass is its volume, so
	# the eruption's Mass is conserved however many pieces it breaks into, and the
	# speed each one leaves with comes out of the blast energy and that Mass.
	if thrown_mass <= 0.0:
		return
	# A Bloom throws the ecosystem, so its material carries propagules with it and
	# can establish a Seed it lands on. Budgeted per Bloom rather than per glob, so a
	# wide splatter is not simply a field-wide germination.
	_inoculation_remaining = (
		evolutions.inoculation_seeds_per_bloom
		if progression.has_active_evolution(PhaseBProgression.EvolutionId.SUPER_BLOOM)
		else 0
	)
	var radii := PackedFloat32Array()
	var volume_total := 0.0
	# How much material there is decides how many pieces it breaks into, not how big
	# each piece is. A droplet's size comes out of the contest between the force
	# tearing the fluid apart and the surface tension holding it together, which does
	# not care how much fluid is present; doubling the charge of the same material
	# under the same blast gives twice the droplets, not droplets twice the size.
	# So the run's Mass line buys coverage — more throws in more directions — and it
	# is the throw that decides how hard each one lands.
	# Measured against the run's own Mass line rather than the field's nominal Bloom
	# Mass: a baseline Bloom breaks into `droplet_count` pieces, and every point of
	# Photosynthesis past that buys more of them at the same size.
	var material_ratio := mass / maxf(0.001, bloom_mass_multiplier)
	var size_scale := droplet_radius_scale
	var effective_count := droplet_count
	if material_scales_droplet_count:
		# Size first, from the specific energy of the blast.
		var coarsening := pow(maxf(0.01, material_ratio), droplet_size_material_exponent)
		size_scale *= coarsening
		# Then the count that conserves the material at that size. A droplet's Mass
		# is its volume, so pieces this much fatter each take that cubed, and what
		# is left to divide is the material itself.
		effective_count = clampi(
			int(round(
				float(droplet_count) * material_ratio / pow(coarsening, 3.0)
			)),
			1,
			maximum_droplet_count
		)
	else:
		size_scale *= clampf(material_ratio, 0.35, 2.5)
	for index in range(effective_count):
		var spread := float(index) / float(maxi(1, effective_count - 1))
		# Biased toward the small end: many droplets, few lumps.
		var radius := lerpf(
			droplet_maximum_radius,
			droplet_minimum_radius,
			pow(spread, 1.0 / maxf(0.05, droplet_size_bias))
		) * size_scale
		radii.append(radius)
		volume_total += radius * radius * radius

	if volume_total <= 0.0:
		return
	for index in range(radii.size()):
		var radius: float = radii[index]
		# Mass is volume: the eruption's material is divided by how much of it each
		# droplet actually is, so the burst conserves what it was given.
		var droplet_mass := thrown_mass * (radius * radius * radius) / volume_total
		var angle := TAU * float(index) / float(maxi(1, radii.size()))
		_launch_glob(
			local_position,
			Vector2.from_angle(angle + _splatter_jitter(index)),
			radius,
			droplet_mass,
			conversion,
			throw,
			chain_depth
		)

	# The drawn burst rides the same throw: it is seeded with the material actually
	# in the air, so the spectacle and the simulation agree about where paint went.
	overlay.spawn_splatter(
		local_position,
		central_radius_pixels * central_radius_scale,
		mass,
		throw,
		get_glob_positions(),
		grand_scale
	)


func _splatter_jitter(seed_index: int) -> float:
	# Deterministic spread, so a replayed run throws its paint the same way.
	return (fmod(float(seed_index) * 2.39996, TAU) - PI) * 0.12




func _on_briar_trap_detonated(local_position: Vector2) -> void:
	# A trap going off also shoves the border outward a little, so a cascade through
	# a claimed field reads as the ecosystem advancing rather than only killing.
	combat.play_plant_explosion_sfx()
	overlay.spawn_bloom(local_position)
	if evolutions.briar_trap_pressure <= 0.0:
		return
	territory_field.queue_bloom(
		local_position,
		evolutions.briar_trap_pressure,
		evolutions.briar_trap_pressure,
		progression.get_conversion_multiplier(),
		0.5
	)

func get_bloom_force_line_multiplier() -> float:
	# The Bloom Force line's own contribution. get_bloom_force_multiplier folds this
	# together with the path's tuning and Meristem, and is what the run reads.
	return 1.0 + bloom_force_per_level * float(
		progression.get_upgrade_level(PhaseBProgression.UpgradeId.BLOOM_FORCE)
	)

func get_bloom_interval_multiplier() -> float:
	return pow(
		bloom_interval_multiplier_per_level,
		float(progression.get_upgrade_level(PhaseBProgression.UpgradeId.BLOOM_FREQUENCY))
	)


func _configure_globs() -> void:
	if _globs.size() == glob_pool_size:
		return
	_globs.clear()
	for _index in range(glob_pool_size):
		_globs.append(Glob.new())


func _launch_glob(
	origin: Vector2,
	direction: Vector2,
	radius_pixels: float,
	mass: float,
	conversion: float,
	force: float,
	chain_depth: int
) -> bool:
	# Speed is not authored per droplet: it falls out of the blast energy and the
	# droplet's own Mass. Equal energy per unit Mass means v = sqrt(2E/m), so the
	# mist leaves fastest and the heavy globs lumber out.
	_configure_globs()
	var pixels_per_cell := territory_field.tuning.arena_size.x / float(
		territory_field.tuning.field_size.x
	)
	# Force is the blast's energy, not its speed. The run's Bloom Force and its
	# Meristem Pressure both feed it, and speed comes out as the square root, so
	# doubling the Force behind an eruption does not simply double how far the paint
	# flies — it is a harder bang, and drag still decides what survives it.
	var energy := blast_specific_energy * maxf(0.0, force)
	var speed := sqrt(2.0 * energy) * pow(
		terrain_drag_reference_radius / maxf(0.5, radius_pixels),
		droplet_speed_size_bias
	)
	for glob in _globs:
		if glob.active:
			continue
		glob.active = true
		glob.position = origin
		glob.velocity = direction.normalized() * maxf(1.0, speed)
		glob.mass = maxf(0.0, mass)
		glob.radius_pixels = maxf(0.5, radius_pixels)
		glob.radius_cells = maxf(0.5, radius_pixels / maxf(0.001, pixels_per_cell))
		glob.conversion = conversion
		glob.chain_depth = chain_depth
		glob.wall_contacts = 0
		glob.wall_normal = Vector2.ZERO
		glob.wall_cling_remaining = 0.0
		glob.trail_remaining = glob_trail_spacing
		glob.travelled = 0.0
		_globs_launched += 1
		return true
	return false



func _publish_flight_globs() -> void:
	# The overlay draws what is actually in the air rather than replaying the throw
	# cosmetically, so the spectacle cannot disagree with the simulation.
	if overlay == null:
		return
	var positions := PackedVector2Array()
	var directions := PackedVector2Array()
	var radii := PackedFloat32Array()
	for glob in _globs:
		if not glob.active:
			continue
		positions.append(glob.position)
		directions.append(glob.velocity)
		radii.append(glob.radius_pixels)
	overlay.set_flight_globs(positions, directions, radii)

func _advance_globs(delta: float) -> void:
	if delta <= 0.0:
		return
	for glob in _globs:
		if not glob.active:
			continue
		_advance_glob(glob, delta)
	_publish_flight_globs()


func _advance_glob(glob: Glob, delta: float) -> void:
	var step := glob.velocity * delta
	var next_position := glob.position + step
	# Basalt and the arena edge are surfaces, not sinks. Paint thrown at a wall does
	# not stop dead and it does not vanish: it hits, loses everything it had driving
	# into the face, and what it had running along the face carries it down the wall
	# until it runs out and pools at the foot. A very slippery surface is exactly the
	# case where almost none of that along-the-face motion is taken away.
	if (
		not territory_field.contains_local_point(next_position)
		or not territory_field.is_claimable_at_local(next_position)
	):
		if not _run_down_obstacle(glob, next_position):
			_land_glob(glob)
		return
	glob.position = next_position
	glob.travelled += step.length()

	# While it is still wetted to a face, it is held against it. This is what makes
	# the paint run down the wall rather than glance off it: what carries it along
	# the surface is untouched, but it is not free to leave.
	if glob.wall_cling_remaining > 0.0:
		glob.wall_cling_remaining -= delta
		glob.velocity -= glob.wall_normal * wall_cling_acceleration * delta
		if glob.wall_cling_remaining <= 0.0:
			glob.wall_normal = Vector2.ZERO

	# Air drag first, and it is the reason a splatter looks the way it does: it acts
	# on the droplet's cross-section and is resisted by its Mass, so deceleration
	# goes as speed squared over radius. Fine mist is thrown hardest and stops
	# almost immediately; a heavy glob leaves slowly and keeps going.
	var speed := glob.velocity.length()
	if speed > 0.0:
		var air := air_drag_coefficient * speed * speed / maxf(0.5, glob.radius_pixels)
		glob.velocity -= glob.velocity.normalized() * minf(air * delta, speed)

	# Then what it is crossing. A droplet is stopped by ground a heavier lump plows
	# straight through, so terrain drag is scaled by the same ballistic coefficient.
	var control := territory_field.get_control_at_local(glob.position)
	var drag := neutral_drag_per_second
	if control > 0.0:
		drag = lerpf(neutral_drag_per_second, green_drag_per_second, clampf(control, 0.0, 1.0))
	elif control < 0.0:
		# Hostile ground slows a glob down, but it does not dissolve it. The glob is
		# the paint: whatever it was thrown with is still on it when it stops, and
		# crossing an invasion costs it distance rather than material.
		var hostility := clampf(-control, 0.0, 1.0)
		drag = lerpf(neutral_drag_per_second, hostile_drag_per_second, hostility)
	drag *= terrain_drag_reference_radius / maxf(0.5, glob.radius_pixels)
	glob.velocity = glob.velocity.lerp(Vector2.ZERO, clampf(drag * delta, 0.0, 1.0))

	# The streak is the trail of something moving, so it is laid down as the glob
	# travels rather than stamped along a ray decided in advance.
	glob.trail_remaining -= step.length()
	if glob.trail_remaining <= 0.0 and glob_trail_spacing > 0.0:
		# Material running down a face leaves a continuous streak on it, not the
		# spaced droplets of something in free flight. Without this a glob spent most
		# of what it carried on the slide and deposited almost nothing.
		var spacing_scale := 1.0
		if glob.wall_cling_remaining > 0.0:
			spacing_scale = wall_streak_spacing_scale
		glob.trail_remaining = glob_trail_spacing * spacing_scale
		# Spending a share of the remaining Mass per splat means the closer the
		# splats are laid the faster the glob bleeds out, so a streak with three
		# times the marks arrived carrying nothing. What the trail costs is charged
		# by the distance covered instead, which leaves the material a glob spends
		# per pixel the same whether it is streaking a face or crossing open ground.
		var trail_mass := glob.mass * glob_trail_mass_share * spacing_scale
		if trail_mass > 0.0:
			glob.mass = maxf(0.0, glob.mass - trail_mass)
			territory_field.queue_splat(
				glob.position,
				trail_mass,
				0.0,
				glob.radius_cells * 0.6,
				glob.conversion
			)

	if glob.velocity.length() <= glob_landing_speed or glob.mass <= 0.0:
		_land_glob(glob)


func _run_down_obstacle(glob: Glob, contact_position: Vector2) -> bool:
	# Returns false when the glob is spent and should deposit where it lies.
	if glob.wall_contacts >= maximum_wall_contacts:
		return false
	var normal := territory_field.get_obstacle_normal_at_local(contact_position)
	if normal == Vector2.ZERO:
		return false
	var into := glob.velocity.dot(normal)
	if into >= 0.0:
		# Already travelling away from the face and still blocked, which means the
		# normal is not describing what it is caught on. Let it settle.
		return false
	# A hit splits along the surface. What was driving into the face has nowhere to
	# go and is what actually splatters there; what was running along the face is
	# untouched, and that is the part that carries on down the wall. So a glob
	# thrown square at a rock still marks it hard, and one that catches it at an
	# angle mostly keeps going — which is the difference between throwing paint at
	# a wall and dragging a loaded brush across it.
	var speed := glob.velocity.length()
	var head_on := clampf(absf(into) / maxf(1.0, speed), 0.0, 1.0)
	var splash_mass := glob.mass * head_on
	if head_on > minimum_face_splash_share and splash_mass > 0.0:
		glob.mass = maxf(0.0, glob.mass - splash_mass)
		territory_field.queue_splat(
			glob.position,
			splash_mass * landing_mass_scale,
			absf(into) * landing_pressure_per_speed,
			glob.radius_cells * landing_spread_scale * head_on * (
				1.0 + landing_spread_per_root_speed * sqrt(absf(into))
			),
			glob.conversion,
			-normal,
			minf(1.0 + landing_smear_per_speed * absf(into), maximum_landing_smear),
			splash_mass * absf(into) * impact_maturity_break,
			landing_maturity_ceiling,
			get_landing_maturity_reinforcement()
		)
	glob.velocity -= normal * into * (1.0 + wall_restitution)
	glob.velocity *= wall_slide_retention
	glob.wall_contacts += 1
	glob.wall_normal = normal
	glob.wall_cling_remaining = wall_cling_seconds
	# Held a hair off the surface so the next step starts in open ground rather than
	# re-colliding with the same cell forever.
	var pixels_per_cell := (
		territory_field.tuning.arena_size.x / float(territory_field.tuning.field_size.x)
	)
	var clearance := glob.position + normal * pixels_per_cell * wall_clearance_cells
	if (
		territory_field.contains_local_point(clearance)
		and territory_field.is_claimable_at_local(clearance)
	):
		glob.position = clearance
	return glob.velocity.length() > glob_landing_speed


func _land_glob(glob: Glob) -> void:
	glob.active = false
	_globs_landed += 1
	if glob.mass <= 0.0:
		return
	# It lands the way it was thrown: stretched along its own travel, pushing the
	# ground it claims downrange, and carrying the speed it still had as Pressure.
	# A fast glancing hit smears; a spent one puddles where it stopped.
	var speed := glob.velocity.length()
	var travel := glob.velocity.normalized() if speed > 1.0 else Vector2.ZERO
	var smear := 1.0 + landing_smear_per_speed * speed
	# The glob does not stamp itself at the size it was flying at. It hits the
	# ground and flattens, and how far it flattens is set by how hard it arrived.
	var spread_radius := (
		glob.radius_cells
		* landing_spread_scale
		* (1.0 + landing_spread_per_root_speed * sqrt(maxf(0.0, speed)))
	)
	territory_field.queue_splat(
		glob.position,
		glob.mass * landing_mass_scale,
		speed * landing_pressure_per_speed,
		spread_radius,
		glob.conversion,
		travel,
		minf(smear, maximum_landing_smear),
		glob.mass * speed * impact_maturity_break,
		landing_maturity_ceiling,
		get_landing_maturity_reinforcement()
	)
	_inoculate_seed_at_landing(glob, spread_radius)


func _inoculate_seed_at_landing(glob: Glob, spread_radius_cells: float) -> void:
	# What a Bloom throws is the ecosystem itself, propagules and all, not inert
	# paint. Whether a site establishes is governed above all by how much living
	# material arrives at it, so a Seed already breaking ground that takes a direct
	# hit from a glob has its establishment settled then and there. Under Super Bloom
	# a germination is already what arms a chained detonation, so the throw carries
	# itself into the next Bloom rather than needing a second rule to say so.
	if _inoculation_remaining <= 0:
		return
	var pixels_per_cell := (
		territory_field.tuning.arena_size.x / float(territory_field.tuning.field_size.x)
	)
	var reach := (
		spread_radius_cells * pixels_per_cell * evolutions.inoculation_radius_scale
	)
	if not overlay.germinate_nearest_seed(glob.position, reach, glob.chain_depth + 1):
		return
	_inoculation_remaining -= 1
	_inoculation_openings += 1
	status_requested.emit("INOCULATION — thrown growth established a Seed where it landed.")


func get_inoculation_openings() -> int:
	return _inoculation_openings


func get_active_glob_count() -> int:
	var count := 0
	for glob in _globs:
		if glob.active:
			count += 1
	return count


func get_glob_positions() -> PackedVector2Array:
	var positions := PackedVector2Array()
	for glob in _globs:
		if glob.active:
			positions.append(glob.position)
	return positions


func get_globs_launched() -> int:
	return _globs_launched


func get_globs_landed() -> int:
	return _globs_landed
