class_name PhaseBSporeDirector
extends Node

## Spore: kills condensed into Seeds, what a germination does to the ground it
## lands on, and the Seed-side evolutions. Bloom owns everything about Blooms, so
## when a germination arms a chain this asks the Bloom director for it rather than
## keeping a second copy of the Bloom's numbers.

signal status_requested(message: String)

@export_group("Collaborators")
## Evolutions component that owns the tuning for every Evolution this path takes
## part in. The behaviour stays here; the numbers live in one place.
@export var evolutions: PhaseBEvolutions

## Authoritative field that receives Seed territory commands.
@export var territory_field: TerritoryField
## Overlay that owns visible Seed charges and germination pulses.
@export var overlay: TerritoryPrototypeOverlay
## Combat component supplying kill events, radial damage, and explosion audio.
@export var combat: PhaseBCombatDirector
## Progression component that supplies upgrade, relic, and evolution modifiers.
@export var progression: PhaseBProgression
## Bloom component asked to arm a chained Bloom when a Super Bloom germination fires.
@export var bloom_director: PhaseBBloomDirector
## Root component supplying the Root Network amplification this path reads.
@export var root_director: PhaseBRootDirector

@export_group("Seed Lines")
## Enemy kills required to create a Seed before Seed Production ranks reduce it.
@export_range(1, 10, 1) var baseline_seed_kill_threshold := 5
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

func _ready() -> void:
	assert(territory_field != null, "PhaseBSporeDirector requires TerritoryField")
	assert(overlay != null, "PhaseBSporeDirector requires TerritoryPrototypeOverlay")
	assert(combat != null, "PhaseBSporeDirector requires PhaseBCombatDirector")
	assert(progression != null, "PhaseBSporeDirector requires PhaseBProgression")
	assert(bloom_director != null, "PhaseBSporeDirector requires PhaseBBloomDirector")
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

func advance(delta: float) -> void:
	_advance_seed_bank(delta)

func _advance_seed_bank(delta: float) -> void:
	# Seed Bank: Mature ground banks dormant Seeds, and on a fixed clock the whole
	# reserve opens at once on top of whatever the mob is standing on. The payoff is
	# a burst, not a territorial drip - that is the entire point of the rework.
	if not progression.has_active_evolution(PhaseBProgression.EvolutionId.SEED_BANK):
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
	var rank := progression.get_evolution_upgrade_level()
	var storage_rate := evolutions.seed_bank_storage_per_mature_percent
	if rank >= 2:
		storage_rate *= 1.0 + evolutions.seed_reserve_rate_bonus
	var capacity := evolutions.seed_bank_capacity
	if rank >= 1:
		capacity *= 1.0 + evolutions.seed_reserve_capacity_per_rank
	_seed_bank_storage = minf(
		capacity,
		_seed_bank_storage + territory_field.get_mature_player_percent() * storage_rate * delta
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
			progression.get_evolution_upgrade_level() >= 4
			and evolutions.fungal_reserve_seeds > 0
		):
			_fungal_reserve_progress += 1
			if _fungal_reserve_progress >= evolutions.fungal_reserve_seeds:
				_fungal_reserve_progress -= evolutions.fungal_reserve_seeds
				combat.spawn_fruiting_body(origin, true)
	return planted


func on_seed_germinated(local_position: Vector2, chain_depth: int) -> void:
	combat.play_plant_explosion_sfx()
	var expansion := progression.get_expansion_multiplier()
	var ground_maturity := territory_field.get_maturity_at_local(local_position)
	# Root Network: a Seed germinating out of Mature ground draws on it and carries
	# more mass than one starting from ground the run only just claimed.
	var inherited_mass := root_director.get_network_multiplier_at(
		local_position,
		ground_maturity
	)
	if progression.has_active_evolution(PhaseBProgression.EvolutionId.SEED_BANK):
		inherited_mass += evolutions.seed_bank_maturity_mass_bonus * ground_maturity
	if (
		progression.has_active_evolution(PhaseBProgression.EvolutionId.PIONEER)
		and progression.get_evolution_upgrade_level() >= 3
		and territory_field.get_pruned_ground_at_local(local_position) > 0.0
	):
		# Fertile Cut: ground Pruning has just opened is the best thing a Seed can land
		# in. Read from the field's own pruned-ground timer rather than from a list the
		# Pruning director would have to keep, so it works for any Seed that happens to
		# germinate there and not only for the ones Pioneer buried.
		inherited_mass += evolutions.second_flush_pruned_mass_bonus
	territory_field.queue_seed_growth(
		local_position,
		get_seed_mass_multiplier() * inherited_mass,
		1.0,
		progression.get_conversion_multiplier(),
		sqrt(expansion)
	)
	if progression.has_relic(PhaseBRelicCatalog.Id.SPORE_BURST):
		# Spore Burst: germination is violent. The damage rides the same mass the growth
		# just pushed into the field rather than being a flat number beside it, so the
		# relic scales with everything that already makes a Seed better - Growth Mass,
		# the Root Network, Seed Bank's maturity bonus - instead of needing its own
		# ladder. Sourced as RELIC so a kill it causes cannot feed a relic trigger and
		# start a chain the player cannot see the end of.
		var burst_mass := get_seed_mass_multiplier() * inherited_mass
		var burst_radius := spore_burst_radius_pixels * sqrt(expansion)
		var caught := combat.damage_enemies_in_radius(
			local_position,
			burst_radius,
			spore_burst_damage * burst_mass,
			PhaseBCombatDirector.DeathSource.RELIC
		)
		overlay.spawn_hostile_pulse(local_position, burst_radius)
		if caught > 0:
			status_requested.emit("SPORE BURST — germination tore through %d enemies." % caught)
	if progression.has_active_evolution(PhaseBProgression.EvolutionId.SUPER_BLOOM):
		# The Bloom director owns chain depth and the Bloom's own telegraph, so the
		# Seed asks it to arm the chain rather than keeping a second copy.
		if bloom_director.plant_chained_bloom(local_position, chain_depth + 1):
			status_requested.emit("SUPER BLOOM — germination has armed a chain detonation.")
	elif progression.has_active_evolution(PhaseBProgression.EvolutionId.BRIAR_PODS):
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
	var rank := progression.get_evolution_upgrade_level()
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
		overlay.spawn_seed(site, get_germination_seconds_at(site), 0, seed_durability)
	status_requested.emit("A Fruiting Body ruptured and scattered its Seeds.")


func get_fruiting_body_chance() -> float:
	return clampf(
		fruiting_body_chance_per_level * float(
			progression.get_upgrade_level(PhaseBProgression.UpgradeId.FRUITING_BODIES)
		),
		0.0,
		1.0
	)


func get_sporulation_rate_multiplier() -> float:
	return 1.0 + sporulation_rate_per_level * float(
		progression.get_upgrade_level(PhaseBProgression.UpgradeId.SPORULATION)
	)


func get_fungal_reserve_progress() -> int:
	return _fungal_reserve_progress


func _apply_tangleburst(local_position: Vector2, radius: float) -> void:
	# Tangleburst turns germination itself into crowd control, rank by rank.
	var rank := progression.get_evolution_upgrade_level()
	if rank <= 0:
		return
	_briar_pod_germinations += 1
	combat.apply_entanglement_in_radius(
		local_position,
		radius,
		evolutions.tangleburst_entanglement
	)
	if rank >= 2:
		combat.root_entangled_enemies_in_radius(
			local_position,
			radius,
			evolutions.tangleburst_root_threshold,
			evolutions.tangleburst_root_seconds
		)
	if rank >= 3:
		combat.pull_enemies_toward(
			local_position,
			radius,
			evolutions.tangleburst_pull_pixels
		)
	if rank >= 4:
		combat.add_ensnare_zone(
			local_position,
			radius,
			evolutions.tangleburst_ensnare_bonus,
			evolutions.tangleburst_ensnare_seconds
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
	if death_source == PhaseBCombatDirector.DeathSource.SUPER_BLOOM:
		if chain_depth >= bloom_director.get_maximum_chain_depth():
			return
		_super_bloom_kills_toward_seed += 1
		if _super_bloom_kills_toward_seed >= evolutions.secondary_kills_per_seed:
			_super_bloom_kills_toward_seed = 0
			overlay.spawn_seed(
				local_position,
				get_germination_seconds_at(local_position),
				chain_depth,
				seed_durability
			)
			status_requested.emit("Super Bloom propagated a secondary Seed.")
		return
	# An Overgrown enemy has already paid for its infection and death burst. It does
	# not also advance the ordinary kill-to-Seed counter.
	if death_source == PhaseBCombatDirector.DeathSource.SPORE:
		return

	credit_seed_kills(local_position, 1)


func credit_seed_kills(local_position: Vector2, count: int = 1) -> void:
	## Public, bounded credit used by Mycelial Vine's Vector Harvest. The actual Seed
	## threshold and spawn behavior stay owned here rather than being duplicated by
	## the Evolution runtime.
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
			seed_durability
		)
		status_requested.emit("%d kills condensed into a Seed at the death site." % threshold)

func _on_catalyst_destroyed(catalyst_kind: int, _local_position: Vector2) -> void:
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
		baseline_seed_kill_threshold - progression.get_upgrade_level(PhaseBProgression.UpgradeId.SEED_PRODUCTION)
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
	return 1.0 + seed_mass_per_level * float(progression.get_upgrade_level(PhaseBProgression.UpgradeId.GROWTH_MASS))
