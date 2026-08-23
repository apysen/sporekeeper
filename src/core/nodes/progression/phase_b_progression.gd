class_name PhaseBProgression
extends Node

signal xp_changed(level: int, current_xp: int, required_xp: int)
signal upgrade_choice_requested(options: PackedInt32Array)
signal rerolls_changed(remaining: int)
signal upgrades_changed
signal path_choice_requested(options: PackedInt32Array, selecting_primary: bool)
signal paths_changed
signal biomass_changed(current: float, per_second: float)
signal metabolism_changed
signal relic_choice_requested(options: PackedInt32Array)
signal relics_changed
signal evolution_changed(status: int)

enum PathId {
	SPORE,
	BLOOM,
	BRAMBLE,
	ROOT,
	PRUNING,
}

const UNSELECTED_PATH := -1

enum PathSlot {
	PRIMARY,
	SECONDARY,
	TERTIARY,
}
## Draft option identifying the pair evolution rather than an upgrade line.
const EVOLUTION_DRAFT_OPTION := -2

enum UpgradeId {
	THORNSHOT_POWER,
	THORNSHOT_TEMPO,
	THORNSHOT_VOLLEY,
	SEED_PRODUCTION,
	GROWTH_MASS,
	BLOOM_FORCE,
	BLOOM_FREQUENCY,
	BRAMBLE_ENTANGLEMENT,
	BRAMBLE_ENSNARE_RATE,
	BRAMBLE_GRASPING_ROOTS,
	BRAMBLE_REPULSION,
	ROOT_MATURATION,
	ROOT_BIOMASS_YIELD,
	ROOT_MATURE_STRENGTH,
	ROOT_POTENCY,
	PRUNING_HARVEST_RATE,
	PRUNING_CUTTING_YIELD,
	PRUNING_CUTTING_DAMAGE,
	PRUNING_CHARGE,
	EVOLUTION_FLORAL_CASCADE,
	EVOLUTION_TANGLEBURST,
	EVOLUTION_SEED_RESERVE,
	EVOLUTION_BRIAR_PAYLOAD,
	EVOLUTION_SEASONAL_SURGE,
	EVOLUTION_ANCIENT_FURY,
}

enum EvolutionStatus {
	NOT_READY,
	READY,
	EVOLVED,
}

enum EvolutionId {
	NONE,
	SUPER_BLOOM,
	BRIAR_PODS,
	THORNBURST,
	SEED_BANK,
	FLOWERING_SEASON,
	OLD_GROWTH,
	COPPICE,
	REBOUND,
	DEADFALL,
	COPPICING,
}

@export_group("XP and Drafting")
## XP required to advance from the starting level to the first upgrade draft.
@export_range(1, 100, 1) var first_level_xp := 7
## Exponential multiplier applied to the XP requirement for each new level.
@export_range(1.0, 3.0, 0.01) var xp_requirement_growth := 1.34
## Highest rank obtainable by any individual upgrade line.
@export_range(1, 10, 1) var maximum_upgrade_level := 5
## Maximum number of different upgrade lines that may be started before evolving.
@export_range(1, 12, 1) var upgrade_slot_count := 6
## Extra upgrade-line slots granted by completing the pair Evolution, so the third
## path can actually be developed without deleting the build already assembled.
@export_range(0, 8, 1) var evolution_bonus_upgrade_slots := 2
## Fraction of a spent level's XP converted to Biomass when no draft option remains.
@export_range(0.0, 2.0, 0.05) var exhausted_draft_biomass_ratio := 0.75
## Upgrade-draft rerolls granted for an entire run.
@export_range(0, 20, 1) var rerolls_per_run := 3

@export_group("Upgrade Effects")
## Additive Thornshot damage multiplier granted by each Thornshot Power rank.
@export_range(0.0, 2.0, 0.01) var thornshot_damage_per_level := 0.28
## Compounding cooldown multiplier applied by each Thornshot Tempo rank; lower is faster.
@export_range(0.1, 1.0, 0.01) var thornshot_cooldown_multiplier_per_level := 0.88
## Additional enemies targeted at once per Thornshot Volley rank. Extra shots take
## different targets, so the line buys horde coverage rather than boss damage.
@export_range(0, 3, 1) var thornshot_targets_per_level := 1
@export_group("Path Components")
## Evolutions component. Progression still owns the paths a pairing is read from
## and the upgrade levels its optional line is counted in; what an Evolution is,
## whether the run holds it, and every number it carries belong over there.
##
## Typed as Node on purpose: Evolutions names Progression's enums, so declaring the
## concrete type here would make the two scripts reference each other at parse time
## and neither would resolve. The reference is one-directional in code even though
## the two nodes talk both ways at runtime.
@export var evolutions: Node
## Bramble component that owns that path's tuning and derived values.
@export var bramble_director: PhaseBBrambleDirector
## Root component that owns that path's tuning and derived values.
@export var root_director: PhaseBRootDirector
## Spore component that owns that path's tuning and derived values.
@export var spore_director: PhaseBSporeDirector
## Bloom component that owns that path's tuning and derived values.
@export var bloom_director: PhaseBBloomDirector
## Pruning component that owns that path's tuning and derived values.
@export var pruning_director: PhaseBPruningDirector
## Ecosystem Metabolism component. Progression still owns the Biomass currency;
## what allocating that currency does to the simulation belongs to Metabolism, so
## the physical multipliers are read back from it rather than kept here.
@export var metabolism: PhaseBMetabolism

@export_group("Relic Effects")
## Biomass generated each second per percentage point of player-owned Green territory.
@export_range(0.0, 2.0, 0.001) var biomass_per_green_percent := 0.018
## Extra Biomass generated each second per percentage point of Mature Green territory.
@export_range(0.0, 4.0, 0.001) var biomass_per_mature_percent := 0.055
## Reference Biomass amount used for one-off payouts such as an exhausted relic
## pool. Repeatable percentage purchases are gone; Metabolism spends the Reserve.
@export_range(1.0, 100.0, 0.5) var biomass_base_cost := 8.0

@export_group("Relic Drafting")
## Relic options presented at one reward. Relics are choose-one-of-three; the
## pool is far larger than the run will ever see, so the offer is a sample.
@export_range(2, 4, 1) var relic_offer_count := 3
## Relic rerolls the run may spend. Separate from upgrade rerolls, because a
## relic reward now shows three of a large pool rather than everything left.
@export_range(0, 20, 1) var relic_rerolls_per_run := 2
## Draft weight of a Common relic.
@export_range(0.0, 100.0, 0.5) var relic_common_weight := 44.0
## Draft weight of an Uncommon relic.
@export_range(0.0, 100.0, 0.5) var relic_uncommon_weight := 31.0
## Draft weight of a Rare relic.
@export_range(0.0, 100.0, 0.5) var relic_rare_weight := 18.0
## Draft weight of a Legendary relic.
@export_range(0.0, 100.0, 0.5) var relic_legendary_weight := 7.0

@export_group("Relic Effects")
## Multiple of the base Biomass cost granted when the relic pool is exhausted.
@export_range(0.0, 10.0, 0.5) var relic_overflow_biomass_multiplier := 3.0

@export_group("Development Path Offers")
## Development switch for narrowing a playtest to the paths under test. Turning a
## path off keeps it out of both path milestones and keeps its four upgrade lines
## out of every level-up draft. A path a run already holds keeps working, and the
## universal Thornshot lines are always drafted, so a run with every path off still
## levels up normally.
@export var offer_spore_path := true
## Development switch; see Offer Spore Path.
@export var offer_bloom_path := true
## Development switch; see Offer Spore Path.
@export var offer_bramble_path := true
## Development switch; see Offer Spore Path.
@export var offer_root_path := true
## Development switch; see Offer Spore Path.
@export var offer_pruning_path := true

var primary_path := UNSELECTED_PATH
var secondary_path := UNSELECTED_PATH
## Support path chosen after the Evolution consolidates the first two into one slot.
var tertiary_path := UNSELECTED_PATH
var current_level := 1
var current_xp := 0
var rerolls_remaining := 0
var biomass := 0.0
var biomass_per_second := 0.0
## Kept readable here because most of the run asks Progression for the state of
## the run. Both are owned by the Evolutions node and read straight back off it.
var evolution_status: int:
	get:
		return evolutions.evolution_status if evolutions != null else EvolutionStatus.NOT_READY
var active_evolution: int:
	get:
		return evolutions.active_evolution if evolutions != null else EvolutionId.NONE

var _upgrade_levels := PackedInt32Array()
var _owned_relics := PackedByteArray()
var _pending_upgrade_options := PackedInt32Array()
var _pending_relic_options := PackedInt32Array()
var _pending_path_options := PackedInt32Array()
var _pending_path_is_primary := true
var _pending_path_slot := PathSlot.PRIMARY
var _upgrade_slot_order := PackedInt32Array()
var _upgrade_offer_cursor := 0
var _relic_rerolls_remaining := 0
var _relic_reroll_used := false
var _last_rerolled_relic_rarity := -1
var _relic_random := RandomNumberGenerator.new()

func _ready() -> void:
	assert(evolutions != null, "PhaseBProgression requires PhaseBEvolutions")
	# Relayed rather than re-owned: the run listens to Progression for the shape of
	# its own progress, and the Evolutions node is where the change actually happens.
	evolutions.evolution_changed.connect(evolution_changed.emit)
	reset_progression()

func reset_progression() -> void:
	primary_path = UNSELECTED_PATH
	secondary_path = UNSELECTED_PATH
	tertiary_path = UNSELECTED_PATH
	current_level = 1
	current_xp = 0
	biomass = 0.0
	biomass_per_second = 0.0
	if evolutions != null:
		evolutions.reset_evolutions()
	rerolls_remaining = rerolls_per_run
	_upgrade_offer_cursor = 0
	_relic_rerolls_remaining = relic_rerolls_per_run
	_relic_reroll_used = false
	_last_rerolled_relic_rarity = -1
	# One owned source, fixed per run, so a replayed seed offers the same relics.
	_relic_random.seed = 0x9E3779B9
	_pending_upgrade_options.clear()
	_pending_relic_options.clear()
	_pending_path_options.clear()
	_pending_path_is_primary = true
	_pending_path_slot = PathSlot.PRIMARY
	_upgrade_slot_order.clear()
	_upgrade_levels.resize(UpgradeId.size())
	_upgrade_levels.fill(0)
	_owned_relics.resize(PhaseBRelicCatalog.get_count())
	_owned_relics.fill(0)
	_emit_all_state()

func request_primary_path_choice() -> bool:
	if primary_path != UNSELECTED_PATH or _has_any_pending_choice():
		return false
	_pending_path_is_primary = true
	_pending_path_slot = PathSlot.PRIMARY
	_pending_path_options.clear()
	for path_id in range(PathId.size()):
		if not is_path_offered(path_id):
			continue
		_pending_path_options.append(path_id)
	if _pending_path_options.is_empty():
		# Every path is switched off for development, so the milestone simply never
		# fires rather than presenting an empty choice.
		return false
	path_choice_requested.emit(_pending_path_options.duplicate(), true)
	return true

func request_secondary_path_choice() -> bool:
	if (
		primary_path == UNSELECTED_PATH
		or secondary_path != UNSELECTED_PATH
		or _has_any_pending_choice()
	):
		return false
	_pending_path_is_primary = false
	_pending_path_slot = PathSlot.SECONDARY
	_pending_path_options.clear()
	for path_id in range(PathId.size()):
		if path_id == primary_path or not is_path_offered(path_id):
			continue
		_pending_path_options.append(path_id)
	if _pending_path_options.is_empty():
		return false
	path_choice_requested.emit(_pending_path_options.duplicate(), false)
	return true

func is_path_offered(path_id: int) -> bool:
	match path_id:
		PathId.SPORE:
			return offer_spore_path
		PathId.BLOOM:
			return offer_bloom_path
		PathId.BRAMBLE:
			return offer_bramble_path
		PathId.ROOT:
			return offer_root_path
		PathId.PRUNING:
			return offer_pruning_path
	return true

func request_tertiary_path_choice() -> bool:
	# The Evolution consolidates the first two paths into one slot, which frees a
	# third. It is offered only once the pairing is actually claimed, so a run that
	# evolves late is offered its support path immediately rather than losing it.
	if (
		evolution_status != EvolutionStatus.EVOLVED
		or tertiary_path != UNSELECTED_PATH
		or _has_any_pending_choice()
	):
		return false
	_pending_path_is_primary = false
	_pending_path_slot = PathSlot.TERTIARY
	_pending_path_options.clear()
	for path_id in range(PathId.size()):
		# The paths the Evolution consumed cannot be taken again.
		if has_path(path_id) or not is_path_offered(path_id):
			continue
		_pending_path_options.append(path_id)
	if _pending_path_options.is_empty():
		return false
	path_choice_requested.emit(_pending_path_options.duplicate(), false)
	return true

func has_tertiary_path() -> bool:
	return tertiary_path != UNSELECTED_PATH

func is_tertiary_path_available() -> bool:
	return evolution_status == EvolutionStatus.EVOLVED and not has_tertiary_path()

func get_upgrade_slot_count() -> int:
	# Evolving does not delete the six lines already slotted; it adds room beside
	# them so the support path can be developed.
	if evolution_status == EvolutionStatus.EVOLVED:
		return upgrade_slot_count + evolution_bonus_upgrade_slots
	return upgrade_slot_count

func choose_path(path_id: int) -> bool:
	if _pending_path_options.find(path_id) == -1:
		return false
	var fills_pairing := _pending_path_slot != PathSlot.TERTIARY
	if _pending_path_slot == PathSlot.TERTIARY:
		tertiary_path = path_id
	elif _pending_path_is_primary:
		primary_path = path_id
	else:
		secondary_path = path_id
	_pending_path_options.clear()
	if fills_pairing and evolutions != null:
		# Changing the pairing invalidates whatever it would have evolved into. The
		# support path is chosen after the fact and must never clear a claimed one.
		evolutions.clear_active_evolution()
	_update_evolution_readiness()
	paths_changed.emit()
	_try_request_level_up()
	return true

func get_pending_path_options() -> PackedInt32Array:
	return _pending_path_options.duplicate()

func has_pending_path_choice() -> bool:
	return not _pending_path_options.is_empty()

func is_pending_primary_path_choice() -> bool:
	return _pending_path_is_primary

func has_primary_path() -> bool:
	return primary_path != UNSELECTED_PATH

func has_secondary_path() -> bool:
	return secondary_path != UNSELECTED_PATH

func has_path(path_id: int) -> bool:
	return (
		path_id == primary_path
		or path_id == secondary_path
		or path_id == tertiary_path
	)

func has_active_evolution(evolution_id: int) -> bool:
	return evolutions != null and evolutions.has_active_evolution(evolution_id)

func get_pair_evolution_id() -> int:
	return evolutions.get_pair_evolution_id() if evolutions != null else EvolutionId.NONE

func get_evolution_upgrade_level() -> int:
	return evolutions.get_evolution_upgrade_level() if evolutions != null else 0

func is_pair_evolution_draftable() -> bool:
	return evolutions != null and evolutions.is_pair_evolution_draftable()

func grant_evolution_if_ready() -> bool:
	return evolutions != null and evolutions.grant_evolution_if_ready()

func is_evolution_path(path_id: int) -> bool:
	# Only the first two paths make the pairing. The support path never joins it,
	# so no second Evolution and no three-way pairing can ever form.
	return path_id == primary_path or path_id == secondary_path

func debug_select_tertiary_path(path_id: int) -> bool:
	if path_id < 0 or path_id >= PathId.size() or is_evolution_path(path_id):
		return false
	tertiary_path = path_id
	_pending_path_options.clear()
	paths_changed.emit()
	return true

func debug_select_paths(first_path: int, second_path: int) -> bool:
	if (
		first_path < 0
		or first_path >= PathId.size()
		or second_path < 0
		or second_path >= PathId.size()
		or first_path == second_path
	):
		return false
	primary_path = first_path
	secondary_path = second_path
	tertiary_path = UNSELECTED_PATH
	_pending_path_options.clear()
	if evolutions != null:
		evolutions.reset_evolutions()
	paths_changed.emit()
	_update_evolution_readiness()
	return true

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	current_xp += amount
	_try_request_level_up()
	xp_changed.emit(current_level, current_xp, get_required_xp())

func choose_upgrade(upgrade_id: int) -> bool:
	if _pending_upgrade_options.find(upgrade_id) == -1:
		return false
	if get_upgrade_level(upgrade_id) >= maximum_upgrade_level:
		return false
	_upgrade_levels[upgrade_id] += 1
	_pending_upgrade_options.clear()
	# Taking a line from an uncommitted path is the commitment itself, filling the
	# next open path slot. The run never asks again for a choice the player has
	# already made, and the path is set before the next draft rolls so later
	# offers filter correctly.
	var committed_path := get_upgrade_committed_path(upgrade_id)
	if committed_path != UNSELECTED_PATH:
		if not has_primary_path():
			primary_path = committed_path
		elif not has_secondary_path():
			secondary_path = committed_path
		else:
			tertiary_path = committed_path
	_update_evolution_readiness()
	upgrades_changed.emit()
	if committed_path != UNSELECTED_PATH:
		paths_changed.emit()
	_try_request_level_up()
	xp_changed.emit(current_level, current_xp, get_required_xp())
	return true

func get_upgrade_committed_path(upgrade_id: int) -> int:
	# The path this upgrade would commit the run to if it were taken right now.
	var upgrade_path := _get_upgrade_path(upgrade_id)
	if upgrade_path == UNSELECTED_PATH or has_path(upgrade_path):
		return UNSELECTED_PATH
	if not has_primary_path() or not has_secondary_path():
		return upgrade_path
	# Both pairing slots are filled. Only an evolved run has anywhere to put it.
	if is_tertiary_path_available():
		return upgrade_path
	return UNSELECTED_PATH

func get_pending_upgrade_options() -> PackedInt32Array:
	return _pending_upgrade_options.duplicate()

func has_pending_upgrade_choice() -> bool:
	return not _pending_upgrade_options.is_empty()

func get_upgrade_level(upgrade_id: int) -> int:
	if upgrade_id < 0 or upgrade_id >= _upgrade_levels.size():
		return 0
	return _upgrade_levels[upgrade_id]

func get_required_xp() -> int:
	return maxi(
		1,
		int(round(
			float(first_level_xp)
			* pow(xp_requirement_growth, float(current_level - 1))
		))
	)

func tick_biomass(
	delta: float,
	green_percent: float,
	mature_green_percent: float,
	root_yield_multiplier: float = 1.0
) -> void:
	# Root's yield arrives as an argument: the economy is progression's, but what
	# Mature Green is worth belongs to the Root path.
	biomass_per_second = (
		green_percent * biomass_per_green_percent
		+ mature_green_percent
		* biomass_per_mature_percent
		* maxf(0.0, root_yield_multiplier)
	) * get_biomass_production_multiplier()
	biomass += biomass_per_second * delta
	biomass_changed.emit(biomass, biomass_per_second)

func add_biomass(amount: float) -> void:
	biomass = maxf(0.0, biomass + amount)
	biomass_changed.emit(biomass, biomass_per_second)

func spend_biomass(amount: float) -> float:
	# The Reserve is spent, never bought against a shop price. Metabolism draws its
	# investment through here and Overgrow spends a share of what is left, so one
	# owner still holds the currency and every debit is visible in one place.
	if amount <= 0.0:
		return 0.0
	var spent := minf(amount, biomass)
	if spent <= 0.0:
		return 0.0
	biomass -= spent
	biomass_changed.emit(biomass, biomass_per_second)
	return spent

func notify_metabolism_changed() -> void:
	metabolism_changed.emit()

func get_provided_mechanics() -> PackedInt32Array:
	# What this run can actually do right now. Seeds and maturity are baseline
	# Plant behaviour; everything else arrives with a path. Synergy relics are
	# gated on mechanics rather than on path pairs, so a support path taken after
	# the Evolution opens exactly the same relics the initial pair would have.
	var mechanics := PhaseBRelicCatalog.get_baseline_mechanics()
	for path_id in [primary_path, secondary_path, tertiary_path]:
		if path_id == UNSELECTED_PATH:
			continue
		for mechanic in PhaseBRelicCatalog.get_path_mechanics(path_id):
			if mechanics.find(mechanic) == -1:
				mechanics.append(mechanic)
	return mechanics

func is_relic_eligible(relic_id: int) -> bool:
	if has_relic(relic_id):
		return false
	match PhaseBRelicCatalog.get_pool(relic_id):
		PhaseBRelicCatalog.Pool.UNIVERSAL, PhaseBRelicCatalog.Pool.ELEMENT:
			pass
		PhaseBRelicCatalog.Pool.PATH:
			# A path relic needs its path, from any of the three slots.
			if not has_path(PhaseBRelicCatalog.get_owning_path(relic_id)):
				return false
		PhaseBRelicCatalog.Pool.SYNERGY:
			pass
	var provided := get_provided_mechanics()
	for required in PhaseBRelicCatalog.get_mechanic_requirements(relic_id):
		if provided.find(required) == -1:
			return false
	return true

func get_eligible_relics() -> PackedInt32Array:
	var eligible := PackedInt32Array()
	for relic_id in range(PhaseBRelicCatalog.get_count()):
		if is_relic_eligible(relic_id):
			eligible.append(relic_id)
	return eligible

func get_relic_rarity_weight(rarity: int) -> float:
	match rarity:
		PhaseBRelicCatalog.Rarity.COMMON:
			return relic_common_weight
		PhaseBRelicCatalog.Rarity.UNCOMMON:
			return relic_uncommon_weight
		PhaseBRelicCatalog.Rarity.RARE:
			return relic_rare_weight
		PhaseBRelicCatalog.Rarity.LEGENDARY:
			return relic_legendary_weight
	return 0.0

func _roll_relic_options(minimum_rarity: int = -1) -> PackedInt32Array:
	# Weighted sampling without replacement, from an owned random source so a
	# replayed seed offers the same three relics.
	var candidates := get_eligible_relics()
	var offers := PackedInt32Array()
	if candidates.is_empty():
		return offers
	if minimum_rarity >= 0:
		# Recycling Bin: one option is guaranteed to be at least as rare as the
		# relic it replaced. It never guarantees a higher rarity.
		var floor_candidates := PackedInt32Array()
		for relic_id in candidates:
			if PhaseBRelicCatalog.get_rarity(relic_id) >= minimum_rarity:
				floor_candidates.append(relic_id)
		if not floor_candidates.is_empty():
			var guaranteed := _draw_weighted_relic(floor_candidates)
			offers.append(guaranteed)
			var trimmed := PackedInt32Array()
			for relic_id in candidates:
				if relic_id != guaranteed:
					trimmed.append(relic_id)
			candidates = trimmed
	while offers.size() < relic_offer_count and not candidates.is_empty():
		var drawn := _draw_weighted_relic(candidates)
		offers.append(drawn)
		var remaining := PackedInt32Array()
		for relic_id in candidates:
			if relic_id != drawn:
				remaining.append(relic_id)
		candidates = remaining
	return offers

func _draw_weighted_relic(candidates: PackedInt32Array) -> int:
	var total := 0.0
	for relic_id in candidates:
		total += get_relic_rarity_weight(PhaseBRelicCatalog.get_rarity(relic_id))
	if total <= 0.0:
		return candidates[0]
	var roll := _relic_random.randf() * total
	for relic_id in candidates:
		roll -= get_relic_rarity_weight(PhaseBRelicCatalog.get_rarity(relic_id))
		if roll <= 0.0:
			return relic_id
	return candidates[candidates.size() - 1]

func request_relic_choice() -> bool:
	if not _pending_relic_options.is_empty():
		return false
	var offers := _roll_relic_options()
	if offers.is_empty():
		# Nothing left the run can hold, so the reward pays out as Biomass rather
		# than presenting an empty panel.
		add_biomass(biomass_base_cost * relic_overflow_biomass_multiplier)
		return false
	_pending_relic_options = offers
	_relic_reroll_used = false
	relic_choice_requested.emit(_pending_relic_options.duplicate())
	return true

func reroll_relic_choice() -> bool:
	# Relic offers are a sample of a large pool now, so redrawing one can change
	# what is on the table. That is also what makes Recycling Bin mean anything.
	if _pending_relic_options.is_empty() or _relic_rerolls_remaining <= 0:
		return false
	var replaced_rarity := PhaseBRelicCatalog.Rarity.COMMON
	for relic_id in _pending_relic_options:
		replaced_rarity = maxi(
			replaced_rarity,
			PhaseBRelicCatalog.get_rarity(relic_id)
		)
	var minimum_rarity := -1
	if has_relic(PhaseBRelicCatalog.Id.RECYCLING_BIN) and not _relic_reroll_used:
		minimum_rarity = replaced_rarity
	var offers := _roll_relic_options(minimum_rarity)
	if offers.is_empty():
		return false
	_relic_rerolls_remaining -= 1
	_relic_reroll_used = true
	_last_rerolled_relic_rarity = replaced_rarity
	_pending_relic_options = offers
	rerolls_changed.emit(rerolls_remaining)
	relic_choice_requested.emit(_pending_relic_options.duplicate())
	return true

func get_relic_rerolls_remaining() -> int:
	return _relic_rerolls_remaining

func choose_relic(relic_id: int) -> bool:
	if _pending_relic_options.find(relic_id) == -1 or has_relic(relic_id):
		return false
	_owned_relics[relic_id] = 1
	_pending_relic_options.clear()
	relics_changed.emit()
	return true

func get_pending_relic_options() -> PackedInt32Array:
	return _pending_relic_options.duplicate()

func has_pending_relic_choice() -> bool:
	return not _pending_relic_options.is_empty()

func has_relic(relic_id: int) -> bool:
	return (
		relic_id >= 0
		and relic_id < _owned_relics.size()
		and _owned_relics[relic_id] != 0
	)

func debug_complete_evolution_requirements() -> void:
	if not has_primary_path() or not has_secondary_path():
		debug_select_paths(PathId.SPORE, PathId.BLOOM)
	_upgrade_levels[_get_representative_upgrade(primary_path)] = maximum_upgrade_level
	_upgrade_levels[_get_representative_upgrade(secondary_path)] = maximum_upgrade_level
	_update_evolution_readiness()
	upgrades_changed.emit()

func get_thornshot_damage_multiplier() -> float:
	return 1.0 + thornshot_damage_per_level * float(get_upgrade_level(UpgradeId.THORNSHOT_POWER))

func get_thornshot_cooldown_multiplier() -> float:
	return pow(
		thornshot_cooldown_multiplier_per_level,
		float(get_upgrade_level(UpgradeId.THORNSHOT_TEMPO))
	)

func get_thornshot_target_count() -> int:
	return 1 + thornshot_targets_per_level * get_upgrade_level(UpgradeId.THORNSHOT_VOLLEY)

func get_expansion_multiplier() -> float:
	# Meristem is Pressure, and passive frontier spread is the cheapest thing
	# Pressure buys, so an unwired Metabolism simply leaves the baseline alone.
	if metabolism == null:
		return 1.0
	return metabolism.get_spread_multiplier()

func get_maturation_multiplier() -> float:
	var multiplier := 1.0
	if metabolism != null:
		multiplier = metabolism.get_maturation_multiplier()
	return multiplier

func get_resistance_multiplier() -> float:
	if metabolism == null:
		return 1.0
	return metabolism.get_resistance_multiplier()

func get_biomass_production_multiplier() -> float:
	if metabolism == null:
		return 1.0
	return metabolism.get_production_multiplier()

func get_conversion_multiplier() -> float:
	if metabolism == null:
		return 1.0
	return metabolism.get_conversion_multiplier()

func get_mass_multiplier() -> float:
	# Photosynthesis is Mass: how much raw Plant material every growth effect in
	# the run is made of.
	if metabolism == null:
		return 1.0
	return metabolism.get_mass_multiplier()

func get_pressure_multiplier() -> float:
	if metabolism == null:
		return 1.0
	return metabolism.get_pressure_multiplier()

func get_owned_relic_names() -> PackedStringArray:
	var names := PackedStringArray()
	for relic_id in range(_owned_relics.size()):
		if _owned_relics[relic_id] != 0:
			names.append(get_relic_name(relic_id))
	return names

func get_slotted_upgrades() -> PackedInt32Array:
	# Growth lines in the order the run first took them, so a line keeps the same
	# slot for the whole run. Rebuilt from the levels themselves rather than
	# recorded on selection, so debug and test mutation land in slots too.
	for upgrade_id in range(_upgrade_levels.size()):
		if _upgrade_levels[upgrade_id] <= 0:
			continue
		if _upgrade_slot_order.has(upgrade_id):
			continue
		_upgrade_slot_order.append(upgrade_id)
	var slotted := PackedInt32Array()
	for upgrade_id in _upgrade_slot_order:
		if get_upgrade_level(upgrade_id) > 0:
			slotted.append(upgrade_id)
	return slotted

func get_upgrade_summary() -> String:
	var lines := PackedStringArray()
	for upgrade_id in range(_upgrade_levels.size()):
		var level := _upgrade_levels[upgrade_id]
		if level > 0:
			lines.append("%s  %d/%d" % [
				get_upgrade_name(upgrade_id),
				level,
				maximum_upgrade_level,
			])
	if lines.is_empty():
		return "No upgrade lines slotted"
	return "\n".join(lines)

static func get_upgrade_name(upgrade_id: int) -> String:
	match upgrade_id:
		UpgradeId.THORNSHOT_POWER:
			return "Thornshot Power"
		UpgradeId.THORNSHOT_TEMPO:
			return "Thornshot Tempo"
		UpgradeId.THORNSHOT_VOLLEY:
			return "Thornshot Volley"
		UpgradeId.SEED_PRODUCTION:
			return "Seed Production"
		UpgradeId.GROWTH_MASS:
			return "Growth Mass"
		UpgradeId.BLOOM_FORCE:
			return "Bloom Force"
		UpgradeId.BLOOM_FREQUENCY:
			return "Bloom Frequency"
		UpgradeId.BRAMBLE_ENTANGLEMENT:
			return "Entanglement"
		UpgradeId.BRAMBLE_ENSNARE_RATE:
			return "Ensnare Rate"
		UpgradeId.BRAMBLE_GRASPING_ROOTS:
			return "Grasping Roots"
		UpgradeId.BRAMBLE_REPULSION:
			return "Repulsion"
		UpgradeId.ROOT_MATURATION:
			return "Maturation Speed"
		UpgradeId.ROOT_BIOMASS_YIELD:
			return "Biomass Yield"
		UpgradeId.ROOT_MATURE_STRENGTH:
			return "Mature Strength"
		UpgradeId.ROOT_POTENCY:
			return "Root Potency"
		UpgradeId.PRUNING_HARVEST_RATE:
			return "Harvest Rate"
		UpgradeId.PRUNING_CUTTING_YIELD:
			return "Cutting Yield"
		UpgradeId.PRUNING_CUTTING_DAMAGE:
			return "Cutting Edge"
		UpgradeId.PRUNING_CHARGE:
			return "Charge"
		UpgradeId.EVOLUTION_FLORAL_CASCADE:
			return "Floral Cascade"
		UpgradeId.EVOLUTION_TANGLEBURST:
			return "Tangleburst"
		UpgradeId.EVOLUTION_SEED_RESERVE:
			return "Seed Reserve"
		UpgradeId.EVOLUTION_BRIAR_PAYLOAD:
			return "Briar Payload"
		UpgradeId.EVOLUTION_SEASONAL_SURGE:
			return "Seasonal Surge"
		UpgradeId.EVOLUTION_ANCIENT_FURY:
			return "Ancient Fury"
	return "Unknown Upgrade"

func get_upgrade_description(upgrade_id: int) -> String:
	if evolutions.get_upgrade_evolution(upgrade_id) != EvolutionId.NONE:
		return evolutions.get_evolution_upgrade_rank_description(
			upgrade_id,
			get_upgrade_level(upgrade_id) + 1
		)
	match upgrade_id:
		UpgradeId.THORNSHOT_POWER:
			return "+%d%% Thornshot damage" % roundi(thornshot_damage_per_level * 100.0)
		UpgradeId.THORNSHOT_TEMPO:
			return "%d%% faster Thornshot attacks" % roundi(
				(1.0 - thornshot_cooldown_multiplier_per_level) * 100.0
			)
		UpgradeId.THORNSHOT_VOLLEY:
			return "Thornshot targets +%d more enemy at once" % thornshot_targets_per_level
		UpgradeId.SEED_PRODUCTION:
			return "One fewer kill required per Seed"
		UpgradeId.GROWTH_MASS:
			return "+%d%% Seed growth mass" % roundi(spore_director.seed_mass_per_level * 100.0 if spore_director != null else 0.0)
		UpgradeId.BLOOM_FORCE:
			return "+%d%% Bloom pressure and damage" % roundi(bloom_director.bloom_force_per_level * 100.0 if bloom_director != null else 0.0)
		UpgradeId.BLOOM_FREQUENCY:
			return "%d%% shorter Bloom interval" % roundi(
				(1.0 - (bloom_director.bloom_interval_multiplier_per_level if bloom_director != null else 0.0)) * 100.0
			)
		UpgradeId.BRAMBLE_ENTANGLEMENT:
			return "+%d%% slow on fully Entangled enemies" % roundi(
				bramble_director.slow_per_level * 100.0 if bramble_director != null else 0.0
			)
		UpgradeId.BRAMBLE_ENSNARE_RATE:
			return "+%d%% faster Entanglement build-up on your Green" % roundi(
				bramble_director.ensnare_per_level * 100.0 if bramble_director != null else 0.0
			)
		UpgradeId.BRAMBLE_GRASPING_ROOTS:
			return "+%.2fs root on enemies that reach full Entanglement" % (
				bramble_director.root_seconds_per_level if bramble_director != null else 0.0
			)
		UpgradeId.BRAMBLE_REPULSION:
			return "+%d px knockback when an enemy damages your territory" % roundi(
				bramble_director.repulsion_pixels_per_level if bramble_director != null else 0.0
			)
		UpgradeId.ROOT_MATURATION:
			return "+%d%% territory maturation rate" % roundi(
				root_director.maturation_per_level * 100.0 if root_director != null else 0.0
			)
		UpgradeId.ROOT_BIOMASS_YIELD:
			return "+%d%% Biomass from Mature Green" % roundi(
				root_director.biomass_yield_per_level * 100.0 if root_director != null else 0.0
			)
		UpgradeId.ROOT_MATURE_STRENGTH:
			return "+%d%% Mature resistance and +%.3f control per second regrowth" % [
				roundi(
					root_director.mature_resistance_per_level * 100.0
					if root_director != null
					else 0.0
				),
				root_director.regeneration_per_level if root_director != null else 0.0,
			]
		UpgradeId.ROOT_POTENCY:
			return "+%d%% Root Network amplification from Mature ground" % roundi(
				root_director.network_bonus_per_level * 100.0 if root_director != null else 0.0
			)
		UpgradeId.PRUNING_HARVEST_RATE:
			return "+%d%% ground harvested per second, and spent per second" % roundi(
				pruning_director.pruning_harvest_rate_per_level * 100.0 if pruning_director != null else 0.0
			)
		UpgradeId.PRUNING_CUTTING_YIELD:
			return "+%d%% Cuttings from the same harvested ground" % roundi(
				pruning_director.pruning_cutting_yield_per_level * 100.0 if pruning_director != null else 0.0
			)
		UpgradeId.PRUNING_CUTTING_DAMAGE:
			return "+%d%% ring and Cutting damage" % roundi(
				pruning_director.pruning_cutting_damage_per_level * 100.0 if pruning_director != null else 0.0
			)
		UpgradeId.PRUNING_CHARGE:
			return "+%d%% Charge rate and launch payout" % roundi(
				pruning_director.pruning_charge_per_level * 100.0 if pruning_director != null else 0.0
			)
	return ""

static func get_path_name(path_id: int) -> String:
	match path_id:
		PathId.SPORE:
			return "Spore"
		PathId.BLOOM:
			return "Bloom"
		PathId.BRAMBLE:
			return "Bramble"
		PathId.ROOT:
			return "Root"
		PathId.PRUNING:
			return "Pruning"
	return "Unchosen"

static func get_path_description(path_id: int) -> String:
	match path_id:
		PathId.SPORE:
			return "Seed catalysts turn kills into deliberate bursts of new Green."
		PathId.BLOOM:
			return "Periodic radial surges reclaim space and convert hostile territory."
		PathId.BRAMBLE:
			return "Your Green entangles, slows, roots, and repels whatever stands on it."
		PathId.ROOT:
			return "Age Green into a Root Network that amplifies everything else your build does."
		PathId.PRUNING:
			return "Burn the Green under your feet into an orbiting ring of blades."
	return ""

static func get_relic_name(relic_id: int) -> String:
	return PhaseBRelicCatalog.get_relic_name(relic_id)

static func get_relic_rarity(relic_id: int) -> int:
	return PhaseBRelicCatalog.get_rarity(relic_id)

func get_relic_description(relic_id: int) -> String:
	return PhaseBRelicCatalog.get_relic_description(relic_id)

func get_relic_requirement_text(relic_id: int) -> String:
	# What a relic needs before it can be offered, so a locked entry in the
	# collection row explains itself rather than only being empty.
	match PhaseBRelicCatalog.get_pool(relic_id):
		PhaseBRelicCatalog.Pool.UNIVERSAL:
			return "Universal"
		PhaseBRelicCatalog.Pool.ELEMENT:
			return "Plant"
		PhaseBRelicCatalog.Pool.PATH:
			return get_path_name(PhaseBRelicCatalog.get_owning_path(relic_id))
	var names := PackedStringArray()
	for mechanic in PhaseBRelicCatalog.get_mechanic_requirements(relic_id):
		names.append(PhaseBRelicCatalog.get_mechanic_name(mechanic))
	return " + ".join(names)

func _try_request_level_up() -> void:
	if not _pending_upgrade_options.is_empty() or not _pending_path_options.is_empty():
		return
	var required := get_required_xp()
	if current_xp < required:
		return
	current_xp -= required
	current_level += 1
	if not _roll_upgrade_options():
		add_biomass(float(required) * exhausted_draft_biomass_ratio)
		_try_request_level_up()
		return
	upgrade_choice_requested.emit(_pending_upgrade_options.duplicate())

func reroll_upgrade_choice() -> bool:
	if _pending_upgrade_options.is_empty() or rerolls_remaining <= 0:
		return false
	var previous_offer := _pending_upgrade_options.duplicate()
	# Advancing the cursor by one is not enough on its own. The offer is spread
	# across the eligible pool, so a single step can land on the same three lines
	# and the reroll looks like it did nothing. Keep stepping until the offer
	# actually changes, and give up rather than spending a reroll on a pool that
	# cannot produce a different one.
	for _attempt in range(UpgradeId.size()):
		_upgrade_offer_cursor = (_upgrade_offer_cursor + 1) % UpgradeId.size()
		_pending_upgrade_options.clear()
		if not _roll_upgrade_options():
			continue
		if not _is_same_offer(_pending_upgrade_options, previous_offer):
			rerolls_remaining -= 1
			rerolls_changed.emit(rerolls_remaining)
			upgrade_choice_requested.emit(_pending_upgrade_options.duplicate())
			return true
	# Nothing else was available: restore the draft the player was looking at
	# rather than leaving them with an empty panel, and charge them nothing.
	_pending_upgrade_options = previous_offer
	upgrade_choice_requested.emit(_pending_upgrade_options.duplicate())
	return false

func _is_same_offer(left: PackedInt32Array, right: PackedInt32Array) -> bool:
	if left.size() != right.size():
		return false
	for option_id in left:
		if right.find(option_id) == -1:
			return false
	return true

func choose_pair_evolution() -> bool:
	if _pending_upgrade_options.find(EVOLUTION_DRAFT_OPTION) == -1:
		return false
	if not grant_evolution_if_ready():
		return false
	_pending_upgrade_options.clear()
	upgrades_changed.emit()
	_try_request_level_up()
	xp_changed.emit(current_level, current_xp, get_required_xp())
	return true

func _roll_upgrade_options() -> bool:
	# A completed pairing is offered in the level-up draft itself and holds one of
	# the three slots until it is taken, so it can never be missed.
	var evolution_slots := 1 if is_pair_evolution_draftable() else 0
	var candidates := PackedInt32Array()
	var occupied_slots := 0
	for level in _upgrade_levels:
		if level > 0:
			occupied_slots += 1
	for offset in range(UpgradeId.size()):
		var upgrade_id := (_upgrade_offer_cursor + offset) % UpgradeId.size()
		if not _is_upgrade_draftable(upgrade_id):
			continue
		var level := get_upgrade_level(upgrade_id)
		if level >= maximum_upgrade_level:
			continue
		if occupied_slots >= get_upgrade_slot_count() and level == 0:
			continue
		candidates.append(upgrade_id)
	if candidates.is_empty() and evolution_slots == 0:
		return false
	if evolution_slots > 0:
		_pending_upgrade_options.append(EVOLUTION_DRAFT_OPTION)
	var offer_count := mini(3 - evolution_slots, candidates.size())
	# Spread the offers across the eligible pool instead of taking three adjacent
	# entries, so a wide pre-commitment draft represents every path rather than
	# the first few lines in enum order. The cursor still advances each level, so
	# the sequence stays deterministic and reproducible from a run seed.
	for index in range(offer_count):
		var spread_index := 0
		if offer_count > 1:
			spread_index = roundi(
				float(index) * float(candidates.size() - 1) / float(offer_count - 1)
			)
		_pending_upgrade_options.append(candidates[spread_index])
	_upgrade_offer_cursor = (_upgrade_offer_cursor + 1) % UpgradeId.size()
	return true

func _update_evolution_readiness() -> void:
	# What counts as a maxed path line is Progression's to know; what that means for
	# the run's Evolution is not.
	if evolutions == null:
		return
	evolutions.update_readiness(
		has_primary_path()
		and has_secondary_path()
		and _has_maxed_path_line(primary_path)
		and _has_maxed_path_line(secondary_path)
	)

func _has_any_pending_choice() -> bool:
	return (
		not _pending_path_options.is_empty()
		or not _pending_upgrade_options.is_empty()
		or not _pending_relic_options.is_empty()
	)

func _is_upgrade_draftable(upgrade_id: int) -> bool:
	var upgrade_evolution: int = evolutions.get_upgrade_evolution(upgrade_id)
	if upgrade_evolution != EvolutionId.NONE:
		# An Evolution's optional overclock, offered only to the run that claimed it.
		return has_active_evolution(upgrade_evolution)
	var upgrade_path := _get_upgrade_path(upgrade_id)
	if upgrade_path == UNSELECTED_PATH or has_path(upgrade_path):
		return true
	if not is_path_offered(upgrade_path):
		return false
	# While a path slot is still open, every line it could fill stays on the table
	# and taking one fills that slot. Drafts narrow to the selected paths whenever
	# no slot is open: after the pairing is locked, and again after the Evolution's
	# support path is chosen.
	if not (has_primary_path() and has_secondary_path()):
		return true
	return is_tertiary_path_available()

func _get_upgrade_path(upgrade_id: int) -> int:
	match upgrade_id:
		UpgradeId.SEED_PRODUCTION, UpgradeId.GROWTH_MASS:
			return PathId.SPORE
		UpgradeId.BLOOM_FORCE, UpgradeId.BLOOM_FREQUENCY:
			return PathId.BLOOM
		UpgradeId.BRAMBLE_ENTANGLEMENT, UpgradeId.BRAMBLE_ENSNARE_RATE, \
		UpgradeId.BRAMBLE_GRASPING_ROOTS, UpgradeId.BRAMBLE_REPULSION:
			return PathId.BRAMBLE
		UpgradeId.ROOT_MATURATION, UpgradeId.ROOT_BIOMASS_YIELD, \
		UpgradeId.ROOT_MATURE_STRENGTH, UpgradeId.ROOT_POTENCY:
			return PathId.ROOT
		UpgradeId.PRUNING_HARVEST_RATE, UpgradeId.PRUNING_CUTTING_YIELD, \
		UpgradeId.PRUNING_CUTTING_DAMAGE, UpgradeId.PRUNING_CHARGE:
			return PathId.PRUNING
	return UNSELECTED_PATH

func _has_maxed_path_line(path_id: int) -> bool:
	for upgrade_id in range(UpgradeId.size()):
		if (
			_get_upgrade_path(upgrade_id) == path_id
			and get_upgrade_level(upgrade_id) >= maximum_upgrade_level
		):
			return true
	return false

func _get_representative_upgrade(path_id: int) -> int:
	match path_id:
		PathId.SPORE:
			return UpgradeId.GROWTH_MASS
		PathId.BLOOM:
			return UpgradeId.BLOOM_FORCE
		PathId.BRAMBLE:
			return UpgradeId.BRAMBLE_ENTANGLEMENT
		PathId.ROOT:
			return UpgradeId.ROOT_MATURATION
		PathId.PRUNING:
			return UpgradeId.PRUNING_CUTTING_DAMAGE
	return UpgradeId.THORNSHOT_POWER

func _emit_all_state() -> void:
	paths_changed.emit()
	xp_changed.emit(current_level, current_xp, get_required_xp())
	upgrades_changed.emit()
	biomass_changed.emit(biomass, biomass_per_second)
	metabolism_changed.emit()
	relics_changed.emit()
	evolution_changed.emit(evolution_status)
	rerolls_changed.emit(rerolls_remaining)
