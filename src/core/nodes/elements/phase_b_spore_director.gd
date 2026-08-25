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

func _ready() -> void:
	assert(territory_field != null, "PhaseBSporeDirector requires TerritoryField")
	assert(overlay != null, "PhaseBSporeDirector requires TerritoryPrototypeOverlay")
	assert(combat != null, "PhaseBSporeDirector requires PhaseBCombatDirector")
	assert(progression != null, "PhaseBSporeDirector requires PhaseBProgression")
	assert(bloom_director != null, "PhaseBSporeDirector requires PhaseBBloomDirector")
	combat.enemy_killed.connect(_on_enemy_killed)
	overlay.seed_germinated_with_context.connect(on_seed_germinated)
	overlay.catalyst_destroyed.connect(_on_catalyst_destroyed)

func reset_director() -> void:
	_kills_toward_seed = 0
	_super_bloom_kills_toward_seed = 0
	_seed_bank_storage = 0.0
	_germination_seasons = 0
	_mast_wave_remaining = 0.0
	_mast_wave_seeds = 0
	_briar_pod_germinations = 0

func advance(delta: float) -> void:
	_advance_seed_bank(delta)

func _advance_seed_bank(delta: float) -> void:
	# Seed Bank: Mature ground banks dormant Seeds over time, and periodically the
	# whole ecosystem germinates at once. The payoff is a territorial jump, not a
	# steady drip of single Seeds.
	if not progression.has_active_evolution(PhaseBProgression.EvolutionId.SEED_BANK):
		_seed_bank_storage = 0.0
		_mast_wave_remaining = 0.0
		return
	if _mast_wave_remaining > 0.0:
		_mast_wave_remaining -= delta
		if _mast_wave_remaining <= 0.0 and _mast_wave_seeds > 0:
			var mast_planted := _release_germination_season(_mast_wave_seeds)
			_mast_wave_seeds = 0
			if mast_planted > 0:
				status_requested.emit(
					"MAST YEAR — a second germination wave breaks across the ecosystem."
				)
	var rank := progression.get_evolution_upgrade_level()
	var storage_rate := evolutions.seed_bank_storage_per_mature_percent
	if rank >= 2:
		storage_rate *= 1.0 + evolutions.seed_reserve_rate_bonus
	var capacity := evolutions.seed_bank_capacity
	if rank >= 1:
		capacity *= 1.0 + evolutions.seed_reserve_capacity_per_rank
	if rank >= 4:
		capacity *= 1.0 + evolutions.seed_reserve_capacity_per_rank
	_seed_bank_storage = minf(
		capacity,
		_seed_bank_storage + territory_field.get_mature_player_percent() * storage_rate * delta
	)
	if _seed_bank_storage < evolutions.germination_season_threshold:
		return
	var seeds := mini(int(floor(_seed_bank_storage)), evolutions.germination_season_maximum_seeds)
	_seed_bank_storage = 0.0
	var planted := _release_germination_season(seeds)
	if planted <= 0:
		return
	_germination_seasons += 1
	status_requested.emit(
		"GERMINATION SEASON — %d banked Seeds break open across Mature ground." % planted
	)
	if (
		rank >= 5
		and evolutions.seed_reserve_mast_cadence > 0
		and _germination_seasons % evolutions.seed_reserve_mast_cadence == 0
	):
		_mast_wave_seeds = maxi(
			1,
			int(round(float(planted) * evolutions.seed_reserve_mast_share))
		)
		_mast_wave_remaining = evolutions.germination_season_mast_delay

func _release_germination_season(seeds: int) -> int:
	# Seeds are spread across Mature ground rather than stacked on one border, so a
	# Season reads as the whole ecosystem opening at once.
	var planted := 0
	var anchor := combat.get_target_position()
	for index in range(maxi(0, seeds)):
		var spread := evolutions.germination_season_spread_pixels * sqrt(float(index + 1))
		var origin := territory_field.find_mature_player_frontier_near(
			anchor + Vector2.from_angle(float(index) * 2.39996) * spread
		)
		if origin.x < 0.0:
			continue
		overlay.spawn_seed(origin, -1.0, 0, seed_durability)
		planted += 1
	return planted

func on_seed_germinated(local_position: Vector2, chain_depth: int) -> void:
	combat.play_plant_explosion_sfx()
	var expansion := progression.get_expansion_multiplier()
	var ground_maturity := territory_field.get_maturity_at_local(local_position)
	# Root Network: a Seed germinating out of Mature ground draws on it and carries
	# more mass than one starting from ground the run only just claimed.
	var inherited_mass := 1.0 + root_director.get_network_bonus() * ground_maturity
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
		var caught := combat.apply_mass_entanglement(
			local_position,
			radius * evolutions.tangleburst_pulse_radius_scale
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
				territory_field.tuning.seed_charge_seconds,
				chain_depth,
				seed_durability
			)
			status_requested.emit("Super Bloom propagated a secondary Seed.")
		return

	_kills_toward_seed += 1
	var threshold := get_seed_kill_threshold()
	if _kills_toward_seed >= threshold:
		_kills_toward_seed = 0
		overlay.spawn_seed(local_position, -1.0, 0, seed_durability)
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
	# What is left before the next Germination Season, in banked Seeds.
	return maxf(0.0, evolutions.germination_season_threshold - _seed_bank_storage)

func get_kills_toward_seed() -> int:
	return _kills_toward_seed

func get_seed_kill_threshold() -> int:
	return maxi(
		minimum_seed_kill_threshold,
		baseline_seed_kill_threshold - progression.get_upgrade_level(PhaseBProgression.UpgradeId.SEED_PRODUCTION)
	)

func get_seed_mass_multiplier() -> float:
	return 1.0 + seed_mass_per_level * float(progression.get_upgrade_level(PhaseBProgression.UpgradeId.GROWTH_MASS))
