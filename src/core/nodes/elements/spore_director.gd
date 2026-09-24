class_name SporeDirector
extends Node

## Spore: kills condensed into Seeds, what a germination does to the ground it
## lands on, and the Seed-side evolutions. Bloom owns everything about Blooms, so
## when a germination arms a chain this asks the Bloom director for it rather than
## keeping a second copy of the Bloom's numbers.

signal status_requested(message: String)

@export_group("Collaborators")
## Evolutions component that owns the tuning for every Evolution this path takes
## part in. The behaviour stays here; the numbers live in one place.
@export var evolutions: Evolutions

## Authoritative field that receives Seed territory commands.
@export var territory_field: TerritoryField
## Overlay that owns visible Seed charges and germination pulses.
@export var overlay: TerritoryPrototypeOverlay
## Combat component supplying kill events, radial damage, and explosion audio.
@export var combat: CombatDirector
## Progression component that supplies upgrade, relic, and evolution modifiers.
@export var progression: Progression
## Bloom component asked to arm a chained Bloom when a Super Bloom germination fires.
@export var bloom_director: BloomDirector
## Root component supplying the Root Network amplification this path reads.
@export var root_director: RootDirector

@export_group("Seed Lines")
## Enemy kills required to create a Seed before Seed Production ranks reduce it.
##
## Four rather than five, from the early-Path pass. Spore's first rank was not weak
## so much as *late*: at five kills a Seed, an opening Spore run spent most of its
## first minute having produced nothing at all, and an Adaptation the player cannot
## see working in the first minute is one they cannot tell they have taken. Four
## brings the first Seed inside the opening wave without changing what a Seed is or
## how the line scales -- Seed Production still buys a kill off the threshold, and
## the floor below is unchanged, so the ceiling this line reaches has not moved.
@export_range(1, 10, 1) var baseline_seed_kill_threshold := 4
## Lowest Seed kill threshold allowed after all Seed Production reductions.
@export_range(1, 10, 1) var minimum_seed_kill_threshold := 2
## Additive Seed territory-mass multiplier granted by each Growth Mass rank.
@export_range(0.0, 2.0, 0.01) var seed_mass_per_level := 0.24

@export_group("Sporulation")
## Additive Spore-accumulation multiplier granted by each Sporulation rank. The base
## rate and everything Overgrown does live on the combat director, which is where the
## enemies are; this line only decides how fast the ground infects them.
@export_range(0.0, 2.0, 0.01) var sporulation_rate_per_level := 0.25

@export_group("Fruiting Bodies")
## Chance added per Fruiting Bodies rank that a Seed germinating on ground the run
## already owns raises a colony instead of only growing.
@export_range(0.0, 1.0, 0.01) var fruiting_body_chance_per_level := 0.10
## Seeds a ruptured colony scatters. They are ordinary Seeds: the rupture reports
## itself and this path decides what comes of it.
@export_range(0, 12, 1) var fruiting_body_rupture_seeds := 2
## How far those Seeds are thrown from the rupture.
@export_range(4.0, 200.0, 1.0) var fruiting_body_scatter_pixels := 34.0

@export_group("Spore Burst")
## Damage a germinating Seed deals at a Growth Mass of one, for runs holding the Spore
## Burst relic. Scaled by the same mass the germination pushes into the field, so a Seed
## that arrives out of Mature ground hits as hard as the Green it makes.
@export_range(0.0, 200.0, 1.0) var spore_burst_damage := 24.0
## How far that detonation reaches. Kept close to the growth it accompanies: the relic
## should read as the germination itself being violent, not as a second explosion
## arriving from somewhere else.
@export_range(8.0, 320.0, 2.0) var spore_burst_radius_pixels := 84.0

@export_group("Puffball")
## Seedlings a destroyed Seed bursts into.
@export_range(1, 8, 1) var puffball_seedlings := 3
## How far a Seedling scatters from the Seed that failed.
@export var puffball_scatter_pixels := Vector2(80.0, 130.0)
## How long a Seedling is airborne before it lands and starts charging.
@export var puffball_flight_seconds := Vector2(0.35, 0.55)
## Germination-time multiplier of a Seedling. Below one, so a Seedling opens sooner
## than the Seed it came from: the relic trades size for speed.
@export_range(0.1, 1.0, 0.005) var puffball_germination_multiplier := 0.625
## Growth Mass a Seedling carries, as a share of a normal Seed's.
@export_range(0.05, 1.0, 0.01) var puffball_mass_share := 0.45

@export_group("Windborne")
## Germinations between Windborne launches.
@export_range(1, 20, 1) var windborne_germination_interval := 5
## Seeds launched by one trigger.
@export_range(1, 8, 1) var windborne_seeds := 3
## How far from the triggering germination Windborne looks for open ground.
@export var windborne_target_distance_pixels := Vector2(260.0, 420.0)
## Minimum spacing between the Seeds of one launch.
@export_range(10.0, 300.0, 5.0) var windborne_separation_pixels := 70.0
## Seconds a Windborne Seed spends in the air.
@export_range(0.05, 3.0, 0.05) var windborne_flight_seconds := 0.70
## Live Windborne Seeds allowed at once. Windborne makes three Seeds per five
## germinations, so it is subcritical on its own; this bounds the pathological case.
@export_range(1, 40, 1) var windborne_active_maximum := 12

@export_group("Volunteer")
## Seconds Green stays "freshly germinated" and able to plant a Volunteer.
@export_range(0.5, 20.0, 0.5) var volunteer_recent_seconds := 4.0
## How close to that germination a death has to land.
@export_range(10.0, 300.0, 5.0) var volunteer_recent_radius_pixels := 70.0
## Chance a qualifying death plants a Seed.
@export_range(0.0, 1.0, 0.01) var volunteer_chance := 0.30
## Global cooldown between Volunteer procs.
@export_range(0.0, 5.0, 0.05) var volunteer_cooldown_seconds := 0.50
## Delay between the death and the Seed appearing on the corpse.
@export_range(0.0, 2.0, 0.05) var volunteer_spawn_delay_seconds := 0.20
## Live Volunteer Seeds allowed at once.
@export_range(1, 20, 1) var volunteer_active_maximum := 6

@export_group("Domino Germination")
## Natural germinations that set off a cascade.
@export_range(1, 40, 1) var domino_natural_germinations := 10
## Seeds one cascade forces open.
@export_range(1, 20, 1) var domino_cascade_seeds := 6
## Seconds between the forced germinations, so the cascade reads as a fuse running
## through the colony rather than six simultaneous pops.
@export_range(0.02, 1.0, 0.01) var domino_step_seconds := 0.16

@export_group("Catalyst Durability")
## Base damage charging Seeds can withstand before a Saboteur destroys them.
@export_range(0.1, 20.0, 0.1) var seed_durability := 2.0

var _kills_toward_seed := 0
var _super_bloom_kills_toward_seed := 0
var _seed_bank_storage := 0.0
var _germination_seasons := 0
var _mast_wave_remaining := 0.0
var _mast_wave_seeds := 0
var _briar_pod_germinations := 0
## Seeds released by a Germination Season, by id. Fungal Reserve counts only the
## banked ones, so the Seeds a Season opens have to be told apart from every other
## Seed the run makes.
var _banked_seed_ids := {}
## Qualifying banked germinations so far. Kept as a running count rather than reset
## on payout, so leftover progress carries into the next colony.
var _fungal_reserve_progress := 0
## Seconds until the next Germination Season. The Season runs on a clock now, not on
## a storage threshold, so the burst is something the player can time a fight around.
var _season_remaining := 0.0
## Whether the free Season that comes with claiming the Evolution has been spent.
var _seed_bank_claimed := false

## Seeds still in the air, each [position, remaining, charge_seconds, mass_share, origin].
## Puffball, Windborne and Volunteer all place a Seed a moment after the event that
## earned it, so they share one queue rather than each keeping a timer.
var _pending_seeds: Array = []
## Growth Mass share carried by particular Seeds, by id. Only Seeds that differ from
## a normal one appear here, so an ordinary Seed costs nothing to look up.
var _seed_mass_share := {}
## Seedlings, by id. A Seedling that is destroyed cannot Puffball again, which is the
## whole of the relic's generation cap.
var _puffball_seedling_ids := {}
var _windborne_seed_ids := {}
var _volunteer_seed_ids := {}
## Germinations since the last Windborne launch. Advanced by forced germinations too.
var _windborne_progress := 0
## Where Seeds have recently opened, each [position, remaining]. Volunteer reads it to
## decide whether a corpse is lying on Green a Seed has just made.
var _recent_seed_green: Array = []
var _volunteer_cooldown := 0.0
## Natural germinations since the last cascade. A forced germination never advances
## this, which is what stops a cascade from feeding the next one.
var _domino_progress := 0
## Seed ids still to be forced open by the running cascade, and the clock between them.
var _domino_cascade: PackedInt32Array = PackedInt32Array()
var _domino_step_remaining := 0.0
var _domino_queued := false
## True only while a cascade is opening a Seed, so the germination it causes can be
## told apart from one the player's own play produced.
var _forcing_germination := false
var _spore_random := RandomNumberGenerator.new()

func _ready() -> void:
	assert(territory_field != null, "SporeDirector requires TerritoryField")
	assert(overlay != null, "SporeDirector requires TerritoryPrototypeOverlay")
	assert(combat != null, "SporeDirector requires CombatDirector")
	assert(progression != null, "SporeDirector requires Progression")
	assert(bloom_director != null, "SporeDirector requires BloomDirector")
	combat.enemy_killed.connect(_on_enemy_killed)
	overlay.seed_germinated_with_context.connect(on_seed_germinated)
	overlay.catalyst_destroyed.connect(_on_catalyst_destroyed)
	combat.fruiting_body_ruptured.connect(_on_fruiting_body_ruptured)

func reset_director() -> void:
	_kills_toward_seed = 0
	_super_bloom_kills_toward_seed = 0
	_seed_bank_storage = 0.0
	_germination_seasons = 0
	_mast_wave_remaining = 0.0
	_mast_wave_seeds = 0
	_briar_pod_germinations = 0
	_banked_seed_ids.clear()
	_fungal_reserve_progress = 0
	_season_remaining = 0.0
	_seed_bank_claimed = false
	_pending_seeds.clear()
	_seed_mass_share.clear()
	_puffball_seedling_ids.clear()
	_windborne_seed_ids.clear()
	_volunteer_seed_ids.clear()
	_windborne_progress = 0
	_recent_seed_green.clear()
	_volunteer_cooldown = 0.0
	_domino_progress = 0
	_domino_cascade = PackedInt32Array()
	_domino_step_remaining = 0.0
	_domino_queued = false
	_forcing_germination = false
	_spore_random.seed = 0x5EED10

func advance(delta: float) -> void:
	_advance_seed_bank(delta)
	_advance_pending_seeds(delta)
	_advance_recent_seed_green(delta)
	_advance_domino(delta)

func _advance_seed_bank(delta: float) -> void:
	# Seed Bank: Mature ground banks dormant Seeds, and on a fixed clock the whole
	# reserve opens at once on top of whatever the mob is standing on. The payoff is
	# a burst, not a territorial drip - that is the entire point of the rework.
	if not progression.has_active_evolution(Progression.EvolutionId.SEED_BANK):
		_seed_bank_storage = 0.0
		_mast_wave_remaining = 0.0
		_season_remaining = 0.0
		_seed_bank_claimed = false
		return
	if not _seed_bank_claimed:
		# Claiming the Evolution is itself a Season, so the power spike lands the
		# moment the player takes it rather than up to eight seconds later.
		_seed_bank_claimed = true
		_season_remaining = evolutions.germination_season_interval
		var claim_planted := _release_germination_season(
			evolutions.germination_season_claim_seeds
		)
		if claim_planted > 0:
			status_requested.emit(
				"SEED BANK — the reserve breaks open across %d enemies at once."
				% claim_planted
			)
	if _mast_wave_remaining > 0.0:
		_mast_wave_remaining -= delta
		if _mast_wave_remaining <= 0.0 and _mast_wave_seeds > 0:
			var mast_planted := _release_germination_season(_mast_wave_seeds)
			_mast_wave_seeds = 0
			if mast_planted > 0:
				status_requested.emit(
					"MAST YEAR — a second full wave breaks over the same ground."
				)
	var rank := progression.get_evolution_rank(Progression.EvolutionId.SEED_BANK)
	var storage_rate := evolutions.seed_bank_storage_per_mature_percent
	if rank >= 2:
		storage_rate *= 1.0 + evolutions.seed_reserve_rate_bonus
	var capacity := evolutions.seed_bank_capacity
	if rank >= 1:
		capacity *= 1.0 + evolutions.seed_reserve_capacity_per_rank
	_seed_bank_storage = minf(
		capacity,
		_seed_bank_storage + territory_field.get_mature_fraction_of_green() * storage_rate * delta
	)
	# The Season is a clock now rather than a threshold: it fires on time with
	# whatever the Bank has managed to store, so the player can count on it.
	_season_remaining -= delta
	if _season_remaining > 0.0:
		return
	_season_remaining = evolutions.germination_season_interval
	var seeds := mini(
		int(floor(_seed_bank_storage)),
		evolutions.germination_season_maximum_seeds
	)
	if seeds <= 0:
		return
	_seed_bank_storage -= float(seeds)
	var planted := _release_germination_season(seeds)
	if planted <= 0:
		return
	_germination_seasons += 1
	status_requested.emit(
		"GERMINATION SEASON — %d Seeds open on the mob." % planted
	)
	if rank >= 5:
		# Mast Year: the second wave is the same wave again, at full strength.
		_mast_wave_seeds = planted
		_mast_wave_remaining = evolutions.germination_season_mast_delay


## Which relic put a Seed into the air, so the Seed it becomes can be booked against
## the right cap and kept out of its own trigger.
enum SeedOrigin {
	PUFFBALL,
	WINDBORNE,
	VOLUNTEER,
}


func _note_germination(local_position: Vector2) -> void:
	## Every germination, natural or forced, passes through here. Windborne counts
	## both; Domino counts only the natural ones, because a cascade that advanced its
	## own counter would never stop.
	if progression.has_relic(RelicCatalog.Id.VOLUNTEER):
		_recent_seed_green.append([local_position, volunteer_recent_seconds])
	if progression.has_relic(RelicCatalog.Id.WINDBORNE):
		_windborne_progress += 1
		if _windborne_progress >= windborne_germination_interval:
			_windborne_progress = 0
			_launch_windborne(local_position)
	if _forcing_germination:
		return
	if not progression.has_relic(RelicCatalog.Id.DOMINO_GERMINATION):
		return
	_domino_progress += 1
	if _domino_progress < domino_natural_germinations:
		return
	_domino_progress = 0
	if _domino_cascade.is_empty():
		_start_domino_cascade()
	else:
		# One cascade runs at a time and at most one waits behind it. Further
		# thresholds reached while both are spoken for are simply dropped.
		_domino_queued = true


func _advance_pending_seeds(delta: float) -> void:
	# A Seed thrown by a relic is airborne for a moment before it lands. The delay is
	# what makes the throw readable, so it is real time rather than a visual flourish
	# over an already-planted Seed.
	for index in range(_pending_seeds.size() - 1, -1, -1):
		var pending: Array = _pending_seeds[index]
		pending[1] = float(pending[1]) - delta
		if float(pending[1]) > 0.0:
			continue
		_pending_seeds.remove_at(index)
		var origin: Vector2 = pending[0]
		if not territory_field.is_claimable_at_local(origin):
			continue
		var seed_id := overlay.spawn_seed(
			origin,
			float(pending[2]),
			0,
			seed_durability,
			RunStats.Source.RELICS
		)
		var mass_share := float(pending[3])
		if not is_equal_approx(mass_share, 1.0):
			_seed_mass_share[seed_id] = mass_share
		match int(pending[4]):
			SeedOrigin.PUFFBALL:
				_puffball_seedling_ids[seed_id] = true
			SeedOrigin.WINDBORNE:
				_windborne_seed_ids[seed_id] = true
			SeedOrigin.VOLUNTEER:
				_volunteer_seed_ids[seed_id] = true


func _advance_recent_seed_green(delta: float) -> void:
	_volunteer_cooldown = maxf(0.0, _volunteer_cooldown - delta)
	for index in range(_recent_seed_green.size() - 1, -1, -1):
		var patch: Array = _recent_seed_green[index]
		patch[1] = float(patch[1]) - delta
		if float(patch[1]) <= 0.0:
			_recent_seed_green.remove_at(index)


func _advance_domino(delta: float) -> void:
	if _domino_cascade.is_empty():
		return
	_domino_step_remaining -= delta
	if _domino_step_remaining > 0.0:
		return
	_domino_step_remaining = domino_step_seconds
	var seed_id := _domino_cascade[0]
	_domino_cascade.remove_at(0)
	# The Seed may have germinated or been destroyed while the cascade was running.
	# A missing link simply does not fire; it does not stall the fuse.
	_forcing_germination = true
	overlay.force_germinate_seed(seed_id)
	_forcing_germination = false
	if _domino_cascade.is_empty() and _domino_queued:
		_domino_queued = false
		_start_domino_cascade()


func _forget_seed(seed_id: int) -> void:
	_seed_mass_share.erase(seed_id)
	_puffball_seedling_ids.erase(seed_id)
	_windborne_seed_ids.erase(seed_id)
	_volunteer_seed_ids.erase(seed_id)


func _count_live(ids: Dictionary) -> int:
	# Counts what is actually still standing rather than trusting the bookkeeping, so
	# a Seed removed by something this director never hears about cannot leak a slot.
	var live := 0
	for seed_id in ids:
		if overlay.has_seed(seed_id):
			live += 1
	return live


func _burst_puffball(local_position: Vector2) -> void:
	# A destroyed Seed is not wasted: it scatters. The Seedlings are smaller and
	# faster, and they can never Puffball themselves, which caps the relic at one
	# generation no matter how the field is being cleared.
	var base_angle := _spore_random.randf() * TAU
	var spawned := 0
	for index in range(puffball_seedlings):
		var spread := TAU * float(index) / float(maxi(1, puffball_seedlings))
		var site := Vector2(-1.0, -1.0)
		# A few tries around the intended bearing, because a Seedling thrown into
		# basalt should land beside it rather than be quietly dropped: the player was
		# promised three, and terrain is not supposed to eat one of them.
		for attempt in range(6):
			var angle := base_angle + spread + _spore_random.randf_range(-0.35, 0.35)
			var distance := _spore_random.randf_range(
				puffball_scatter_pixels.x,
				puffball_scatter_pixels.y
			)
			if attempt >= 3:
				# Later tries pull in closer, which is where valid ground usually is.
				distance = puffball_scatter_pixels.x * 0.5
			var candidate := local_position + Vector2.from_angle(angle) * distance
			if not territory_field.is_claimable_at_local(candidate):
				continue
			if not territory_field.is_growth_path_clear(local_position, candidate):
				continue
			site = candidate
			break
		if site.x < 0.0:
			continue
		_pending_seeds.append([
			site,
			_spore_random.randf_range(puffball_flight_seconds.x, puffball_flight_seconds.y),
			get_germination_seconds_at(site) * puffball_germination_multiplier,
			puffball_mass_share,
			SeedOrigin.PUFFBALL,
		])
		spawned += 1
	if spawned > 0:
		status_requested.emit(
			"PUFFBALL — the broken Seed scatters %d Seedlings." % spawned
		)


func _launch_windborne(local_position: Vector2) -> void:
	# Windborne is the relic that stops a colony sitting still: it throws Seeds at
	# ground the run does not hold yet, rather than thickening the Green it has.
	var room := windborne_active_maximum - _count_live(_windborne_seed_ids)
	if room <= 0:
		return
	var placed := PackedVector2Array()
	var base_angle := _spore_random.randf() * TAU
	for index in range(mini(windborne_seeds, room)):
		var site := Vector2(-1.0, -1.0)
		# A handful of tries rather than a search: the relic wants distant open
		# ground, and failing to find any is an acceptable outcome for one Seed.
		for _attempt in range(8):
			var angle := base_angle + TAU * float(index) / float(maxi(1, windborne_seeds))
			angle += _spore_random.randf_range(-0.45, 0.45)
			var distance := _spore_random.randf_range(
				windborne_target_distance_pixels.x,
				windborne_target_distance_pixels.y
			)
			var candidate := local_position + Vector2.from_angle(angle) * distance
			if not territory_field.is_claimable_at_local(candidate):
				continue
			# Preferred target is ground the run does not already own.
			if territory_field.get_control_at_local(candidate) > territory_field.tuning.ownership_threshold:
				continue
			var spaced := true
			for other in placed:
				if other.distance_to(candidate) < windborne_separation_pixels:
					spaced = false
					break
			if not spaced:
				continue
			site = candidate
			break
		if site.x < 0.0:
			continue
		placed.append(site)
		_pending_seeds.append([
			site,
			windborne_flight_seconds,
			get_germination_seconds_at(site),
			1.0,
			SeedOrigin.WINDBORNE,
		])
	if placed.size() > 0:
		status_requested.emit(
			"WINDBORNE — %d Seeds carried out onto open ground." % placed.size()
		)


func _try_volunteer(local_position: Vector2) -> void:
	if not progression.has_relic(RelicCatalog.Id.VOLUNTEER):
		return
	if _volunteer_cooldown > 0.0:
		return
	if _count_live(_volunteer_seed_ids) >= volunteer_active_maximum:
		return
	var on_fresh_green := false
	for patch in _recent_seed_green:
		var patch_position: Vector2 = patch[0]
		if patch_position.distance_to(local_position) <= volunteer_recent_radius_pixels:
			on_fresh_green = true
			break
	if not on_fresh_green:
		return
	if _spore_random.randf() >= volunteer_chance:
		return
	var site := local_position
	if not territory_field.is_claimable_at_local(site):
		site = territory_field.find_player_frontier_near(local_position)
		if site.x < 0.0:
			return
	_volunteer_cooldown = volunteer_cooldown_seconds
	_pending_seeds.append([
		site,
		volunteer_spawn_delay_seconds,
		get_germination_seconds_at(site),
		1.0,
		SeedOrigin.VOLUNTEER,
	])
	status_requested.emit("VOLUNTEER — the corpse falls on fresh Green and a Seed takes.")


func _start_domino_cascade() -> void:
	# Ripest first, oldest to break a tie. The player sees the colony open in the
	# order it was closest to opening anyway, which is what makes the cascade read
	# as a fuse rather than as a random cull.
	var ids := overlay.get_seed_ids()
	var ordered: Array = []
	for index in range(ids.size()):
		# The index is the Seed's age: get_seed_ids reports them in spawn order.
		ordered.append([ids[index], overlay.get_seed_progress(ids[index]), index])
	if ordered.is_empty():
		return
	ordered.sort_custom(
		func(first: Array, second: Array) -> bool:
			if is_equal_approx(float(first[1]), float(second[1])):
				return int(first[2]) < int(second[2])
			return float(first[1]) > float(second[1])
	)
	_domino_cascade = PackedInt32Array()
	for index in range(mini(domino_cascade_seeds, ordered.size())):
		_domino_cascade.append(int(ordered[index][0]))
	if _domino_cascade.is_empty():
		return
	# The first link opens on the next step rather than instantly, so the cascade has
	# a visible rhythm from its very first Seed.
	_domino_step_remaining = domino_step_seconds
	status_requested.emit(
		"DOMINO GERMINATION — %d Seeds go up in a cascade." % _domino_cascade.size()
	)


func _release_germination_season(seeds: int) -> int:
	# Seeds are placed on the enemies themselves rather than spread across the
	# frontier. A Season that opens on empty Green is the failure this rework exists
	# to fix, so the combat director picks the ground that is actually occupied and
	# only falls back to Mature frontier when nothing is standing in the Green.
	var wanted := maxi(0, seeds)
	if wanted <= 0:
		return 0
	var targets := combat.find_infection_targets(wanted)
	var planted := 0
	var anchor := combat.get_target_position()
	for index in range(wanted):
		var origin := Vector2(-1.0, -1.0)
		if index < targets.size():
			origin = targets[index]
		else:
			var spread := evolutions.germination_season_spread_pixels * sqrt(float(index + 1))
			origin = territory_field.find_mature_player_frontier_near(
				anchor + Vector2.from_angle(float(index) * 2.39996) * spread
			)
		if origin.x < 0.0:
			continue
		var banked_id := overlay.spawn_seed(
			origin,
			get_germination_seconds_at(origin),
			0,
			seed_durability
		)
		_banked_seed_ids[banked_id] = true
		planted += 1
		# Fungal Reserve counts Seeds released, not Seeds that survive to germinate,
		# so a Season's infrastructure is known the moment it is sown. The remainder
		# carries forward rather than being discarded between Seasons.
		if (
			progression.get_evolution_rank(Progression.EvolutionId.SEED_BANK) >= 4
			and evolutions.fungal_reserve_seeds > 0
		):
			_fungal_reserve_progress += 1
			if _fungal_reserve_progress >= evolutions.fungal_reserve_seeds:
				_fungal_reserve_progress -= evolutions.fungal_reserve_seeds
				combat.spawn_fruiting_body(origin, true)
	return planted


func on_seed_germinated(local_position: Vector2, chain_depth: int) -> void:
	combat.play_plant_explosion_sfx()
	var germinated_id := overlay.get_last_germinated_seed_id()
	# A Seedling carries less than a whole Seed's growth. Read and released here, so
	# no other system has to know that some Seeds are worth less than others.
	var mass_share := float(_seed_mass_share.get(germinated_id, 1.0))
	_forget_seed(germinated_id)
	_note_germination(local_position)
	var expansion := progression.get_expansion_multiplier()
	var ground_maturity := territory_field.get_maturity_at_local(local_position)
	# Root Network: a Seed germinating out of Mature ground draws on it and carries
	# more mass than one starting from ground the run only just claimed.
	var inherited_mass := root_director.get_network_multiplier_at(
		local_position,
		ground_maturity
	)
	if progression.has_active_evolution(Progression.EvolutionId.SEED_BANK):
		inherited_mass += evolutions.seed_bank_maturity_mass_bonus * ground_maturity
	if (
		progression.get_evolution_rank(Progression.EvolutionId.PIONEER) >= 3
		and territory_field.get_pruned_ground_at_local(local_position) > 0.0
	):
		# Fertile Cut: ground Pruning has just opened is the best thing a Seed can land
		# in. Read from the field's own pruned-ground timer rather than from a list the
		# Pruning director would have to keep, so it works for any Seed that happens to
		# germinate there and not only for the ones Pioneer buried.
		inherited_mass += evolutions.second_flush_pruned_mass_bonus
	# Every germinating Seed comes through here, owned Spore or not. Its Green goes to
	# whatever made the Seed -- the kill that condensed it, the relic that threw it --
	# and to the Seeds row when nothing did.
	var credit := overlay.get_last_germinated_seed_credit()
	territory_field.attribution = credit if credit >= 0 else RunStats.Source.SEEDS
	territory_field.queue_seed_growth(
		local_position,
		get_seed_mass_multiplier() * inherited_mass * mass_share,
		1.0,
		progression.get_conversion_multiplier(),
		sqrt(expansion) * mass_share
	)
	if progression.has_relic(RelicCatalog.Id.SPORE_BURST):
		# Spore Burst: germination is violent. The damage rides the same mass the growth
		# just pushed into the field rather than being a flat number beside it, so the
		# relic scales with everything that already makes a Seed better - Growth Mass,
		# the Root Network, Seed Bank's maturity bonus - instead of needing its own
		# ladder. Sourced as RELIC so a kill it causes cannot feed a relic trigger and
		# start a chain the player cannot see the end of.
		var burst_mass := get_seed_mass_multiplier() * inherited_mass * mass_share
		var burst_radius := spore_burst_radius_pixels * sqrt(expansion)
		var caught := combat.damage_enemies_in_radius(
			local_position,
			burst_radius,
			spore_burst_damage * burst_mass,
			CombatDirector.DeathSource.RELIC
		)
		overlay.spawn_hostile_pulse(local_position, burst_radius)
		if caught > 0:
			status_requested.emit("SPORE BURST — germination tore through %d enemies." % caught)
	if progression.has_active_evolution(Progression.EvolutionId.SUPER_BLOOM):
		# The Bloom director owns chain depth and the Bloom's own telegraph, so the
		# Seed asks it to arm the chain rather than keeping a second copy.
		if bloom_director.plant_chained_bloom(local_position, chain_depth + 1):
			status_requested.emit("SUPER BLOOM — germination has armed a chain detonation.")
	elif progression.has_active_evolution(Progression.EvolutionId.BRIAR_PODS):
		combat.spawn_briar_pod(
			local_position,
			evolutions.briar_pod_radius_pixels * sqrt(expansion),
			evolutions.briar_pod_duration_seconds,
			evolutions.briar_pod_contact_multiplier
		)
		_apply_tangleburst(local_position, evolutions.briar_pod_radius_pixels * sqrt(expansion))
		status_requested.emit("BRIAR PODS — germination raised a temporary thorn perimeter.")
	else:
		status_requested.emit("Seed germinated into dense Green growth.")
	# A Season Seed detonates as it opens. Ordered before the colony roll so a body
	# raised here is not standing in its own Rootburst.
	if _banked_seed_ids.erase(overlay.get_last_germinated_seed_id()):
		_fire_rootburst(local_position)
	# Last, so a colony raised this frame is never caught in its own germination's
	# Spore Burst and never displaces the growth the Seed was already going to make.
	_try_raise_fruiting_body(local_position)

func _fire_rootburst(local_position: Vector2) -> void:
	# Rootburst: what a banked Seed does that an ordinary Seed does not. Written as a
	# share of what a standard enemy is worth rather than as a flat number, so it
	# keeps killing normal mobs as the waves harden, and it lands as a fraction of a
	# boss rather than as a boss-killer. Root Potency amplifies both halves - this is
	# the one Spore effect the doc wants Mature ground to make lethal outright.
	var rank := progression.get_evolution_rank(Progression.EvolutionId.SEED_BANK)
	var damage_share := evolutions.rootburst_damage_share
	var radius := evolutions.rootburst_radius_pixels
	if rank >= 3:
		damage_share *= 1.0 + evolutions.rootburst_damage_bonus
		radius *= 1.0 + evolutions.rootburst_radius_bonus
	var amplification := root_director.get_network_multiplier_here(local_position)
	var caught := combat.apply_rootburst(
		local_position,
		radius,
		combat.get_standard_enemy_health() * damage_share * amplification,
		evolutions.rootburst_spore * amplification
	)
	overlay.spawn_hostile_pulse(local_position, radius)
	if caught > 0:
		status_requested.emit("ROOTBURST — the Seed opened under %d enemies." % caught)


func _try_raise_fruiting_body(local_position: Vector2) -> void:
	# A germination inside ground the run already holds is not claiming anything: the
	# Seed's growth still runs, and the colony is raised beside it rather than instead
	# of it. That is also the whole test for "not expanding territory" - no separate
	# rule is needed, because a Seed on unowned ground never gets here.
	if not territory_field.is_owned_at_local(local_position):
		return
	# Fungal Reserve is paid at release, not here, so this is only ever the ordinary
	# chance roll. A Season Seed rolls it like any other Seed does.
	var chance := get_fruiting_body_chance()
	if chance <= 0.0 or randf() >= chance:
		return
	if combat.spawn_fruiting_body(local_position):
		status_requested.emit("A Fruiting Body has swollen out of your own Green.")


func _on_fruiting_body_ruptured(local_position: Vector2) -> void:
	# The colony bursts and throws Seeds. They are ordinary Seeds from here on, which
	# is what lets them germinate, grow, and roll for a colony of their own.
	for _seed_index in range(fruiting_body_rupture_seeds):
		var offset := (
			Vector2.from_angle(randf() * TAU)
			* fruiting_body_scatter_pixels
			* sqrt(randf())
		)
		var site := local_position + offset
		if not territory_field.contains_local_point(site):
			site = local_position
		overlay.spawn_seed(
			site, get_germination_seconds_at(site), 0, seed_durability, RunStats.Source.SPORE
		)
	status_requested.emit("A Fruiting Body ruptured and scattered its Seeds.")


func get_fruiting_body_chance() -> float:
	return clampf(
		fruiting_body_chance_per_level * float(
			progression.get_upgrade_level(Progression.UpgradeId.FRUITING_BODIES)
		),
		0.0,
		1.0
	)


func get_sporulation_rate_multiplier() -> float:
	return 1.0 + sporulation_rate_per_level * float(
		progression.get_upgrade_level(Progression.UpgradeId.SPORULATION)
	)


func get_fungal_reserve_progress() -> int:
	return _fungal_reserve_progress


func _apply_tangleburst(local_position: Vector2, radius: float) -> void:
	# Tangleburst turns germination itself into crowd control, rank by rank.
	var rank := progression.get_evolution_rank(Progression.EvolutionId.BRIAR_PODS)
	if rank <= 0:
		return
	_briar_pod_germinations += 1
	combat.apply_entanglement_in_radius(
		local_position,
		radius,
		evolutions.tangleburst_entanglement
	)
	if rank >= 2:
		combat.ensnare_entangled_enemies_in_radius(
			local_position,
			radius,
			evolutions.tangleburst_ensnare_threshold,
			evolutions.tangleburst_ensnare_hold_seconds
		)
	if rank >= 3:
		combat.pull_enemies_toward(
			local_position,
			radius,
			evolutions.tangleburst_pull_pixels
		)
	if rank >= 4:
		combat.add_entanglement_rate_zone(
			local_position,
			radius,
			evolutions.tangleburst_entanglement_bonus,
			evolutions.tangleburst_entanglement_seconds
		)
	if (
		rank >= 5
		and evolutions.tangleburst_pulse_cadence > 0
		and _briar_pod_germinations % evolutions.tangleburst_pulse_cadence == 0
	):
		var pulse_radius := radius * evolutions.tangleburst_pulse_radius_scale
		var caught := combat.apply_mass_entanglement(local_position, pulse_radius)
		# The pin is only half of it: a mob held in place is a mob the infection can
		# finish, so the pulse seeds the whole cluster at the same moment.
		combat.apply_spore_in_radius(
			local_position,
			pulse_radius,
			evolutions.tangleburst_pulse_spore
		)
		if caught > 0:
			status_requested.emit(
				"MASS ENTANGLEMENT — %d enemies seized by the new growth." % caught
			)

func _on_enemy_killed(
	local_position: Vector2,
	_xp_value: int,
	_role: int,
	death_source: int,
	chain_depth: int
) -> void:
	if death_source == CombatDirector.DeathSource.SUPER_BLOOM:
		if chain_depth >= bloom_director.get_maximum_chain_depth():
			return
		_super_bloom_kills_toward_seed += 1
		if _super_bloom_kills_toward_seed >= evolutions.secondary_kills_per_seed:
			_super_bloom_kills_toward_seed = 0
			overlay.spawn_seed(
				local_position,
				get_germination_seconds_at(local_position),
				chain_depth,
				seed_durability,
				RunStats.Source.BLOOM
			)
			status_requested.emit("Super Bloom propagated a secondary Seed.")
		return
	# An Overgrown enemy has already paid for its infection and death burst. It does
	# not also advance the ordinary kill-to-Seed counter.
	if death_source == CombatDirector.DeathSource.SPORE:
		return

	_try_volunteer(local_position)
	credit_seed_kills(local_position, 1, combat.get_stats_source(death_source))


func credit_seed_kills(local_position: Vector2, count: int = 1, credit: int = -1) -> void:
	## Public, bounded credit used by Mycelial Vine's Vector Harvest. The actual Seed
	## threshold and spawn behavior stay owned here rather than being duplicated by
	## the Evolution runtime.
	##
	## `credit` is the result-screen row of the kill that tipped the count over: the
	## Seed it condenses is that kill's, and so is the Green it grows.
	if count <= 0:
		return
	_kills_toward_seed += count
	var threshold := get_seed_kill_threshold()
	while _kills_toward_seed >= threshold:
		_kills_toward_seed -= threshold
		overlay.spawn_seed(
			local_position,
			get_germination_seconds_at(local_position),
			0,
			seed_durability,
			credit
		)
		status_requested.emit("%d kills condensed into a Seed at the death site." % threshold)

func _on_catalyst_destroyed(
	catalyst_kind: int,
	local_position: Vector2,
	catalyst_id: int
) -> void:
	if catalyst_kind == TerritoryPrototypeOverlay.CatalystKind.SEED:
		var was_seedling := _puffball_seedling_ids.has(catalyst_id)
		_forget_seed(catalyst_id)
		if (
			progression.has_relic(RelicCatalog.Id.PUFFBALL)
			and not was_seedling
		):
			_burst_puffball(local_position)
	var catalyst_name := (
		"Seed"
		if catalyst_kind == TerritoryPrototypeOverlay.CatalystKind.SEED
		else "Bloom"
	)
	status_requested.emit("Saboteur destroyed a charging %s." % catalyst_name)

func get_seed_bank_storage() -> float:
	return _seed_bank_storage

func get_seed_bank_charge_remaining() -> float:
	# Seconds left before the next Germination Season. The Season stopped being a
	# storage threshold in the burst rework, so what is worth reporting is the clock.
	return maxf(0.0, _season_remaining)

func get_kills_toward_seed() -> int:
	return _kills_toward_seed

func get_seed_kill_threshold() -> int:
	return maxi(
		minimum_seed_kill_threshold,
		baseline_seed_kill_threshold - progression.get_upgrade_level(Progression.UpgradeId.SEED_PRODUCTION)
	)

func get_germination_seconds_at(local_position: Vector2) -> float:
	# Root Network: a Seed buried in old ground breaks open sooner than one left in
	# Green the run only just claimed. Root already decides what a Seed landing here
	# is worth; this is the same amplification spent on the wait instead of on the
	# mass, so Root shortens the gap between a kill and the growth it becomes.
	return territory_field.tuning.seed_charge_seconds / maxf(
		0.01,
		root_director.get_network_multiplier_here(local_position)
	)


func get_seed_mass_multiplier() -> float:
	return 1.0 + seed_mass_per_level * float(progression.get_upgrade_level(Progression.UpgradeId.GROWTH_MASS))
