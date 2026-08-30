class_name PhaseBProgression
extends Node

const RUN_MODE := preload("res://src/core/models/run/phase_b_run_mode.gd")

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
	THISTLE,
	VINE,
	FRUIT,
}

const UNSELECTED_PATH := -1

enum PathSlot {
	PRIMARY,
	SECONDARY,
}
## Draft option identifying the pair evolution rather than an upgrade line.
const EVOLUTION_DRAFT_OPTION := -2

enum UpgradeId {
	SEED_PRODUCTION,
	GROWTH_MASS,
	SPORULATION,
	FRUITING_BODIES,
	BLOOM_FORCE,
	BLOOM_FREQUENCY,
	AFTERGROWTH,
	SUPPRESSION,
	BRAMBLE_ENTANGLEMENT,
	BRAMBLE_ENSNARE_RATE,
	BRAMBLE_GRASPING_ROOTS,
	BRAMBLE_REPULSION,
	ROOT_MATURATION,
	ROOT_LATERAL_ROOTS,
	ROOT_MATURE_STRENGTH,
	ROOT_POTENCY,
	PRUNING_HARVEST_RATE,
	PRUNING_CUTTING_YIELD,
	PRUNING_CUTTING_DAMAGE,
	PRUNING_CHARGE,
	THISTLE_CLUSTERING,
	THISTLE_DEHISCENCE,
	THISTLE_BURR,
	THISTLE_NEEDLEPOINT,
	VINE_ELONGATION,
	VINE_LIGNIFICATION,
	VINE_TURGOR,
	VINE_APICAL_DOMINANCE,
	FRUIT_SET,
	FRUIT_RIPENING,
	FRUIT_MOMENTUM,
	FRUIT_GERMINATION,
	EVOLUTION_FLORAL_CASCADE,
	EVOLUTION_TANGLEBURST,
	EVOLUTION_SEED_RESERVE,
	EVOLUTION_BRIAR_PAYLOAD,
	EVOLUTION_SEASONAL_SURGE,
	EVOLUTION_ANCIENT_FURY,
	EVOLUTION_SECOND_FLUSH,
	EVOLUTION_COMPRESSION,
	EVOLUTION_SPLINTERSTORM,
	EVOLUTION_STOOL_REGROWTH,
	EVOLUTION_INOCULATOR,
	EVOLUTION_BURSTBLOOM,
	EVOLUTION_HEDGE_BATTERY,
	EVOLUTION_ROOTSTOCK,
	EVOLUTION_DEADHEADING,
	EVOLUTION_THORNWHIP,
	EVOLUTION_BURDOCK,
	EVOLUTION_MYCELIAL_VINE,
	EVOLUTION_WISTERIA,
	EVOLUTION_BRIAR_CANE,
	EVOLUTION_HEARTWOOD,
	EVOLUTION_ESPALIER,
	EVOLUTION_GOURDVINE,
	EVOLUTION_ROT,
	EVOLUTION_OVERRIPE,
	EVOLUTION_DURIAN,
	EVOLUTION_ORCHARD,
	EVOLUTION_GRAFT,
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
	PIONEER,
	REBOUND,
	DEADFALL,
	COPPICING,
	INOCULATOR,
	BURSTBLOOM,
	HEDGE_BATTERY,
	ROOTSTOCK,
	DEADHEADING,
	THORNWHIP,
	BURDOCK,
	MYCELIAL_VINE,
	WISTERIA,
	BRIAR_CANE,
	HEARTWOOD,
	ESPALIER,
	GOURDVINE,
	ROT,
	OVERRIPE,
	DURIAN,
	ORCHARD,
	GRAFT,
}

@export_group("XP and Drafting")
## XP required to advance from the starting level to the first upgrade draft.
@export_range(1, 100, 1) var first_level_xp := 7
## Exponential multiplier applied to the XP requirement for each new level.
@export_range(1.0, 3.0, 0.01) var xp_requirement_growth := 1.34
## Highest rank obtainable by any individual upgrade line.
@export_range(1, 10, 1) var maximum_upgrade_level := 5
## Rank every line of a Path is run at while a Clover jackpot has that Path lit. The
## jackpot's whole promise is a fully maxed Path, so this tracks the ceiling above
## rather than being a second number that can drift away from it.
@export_range(1, 10, 1) var casino_upgrade_level := 5
## Maximum number of different upgrade lines that may be started before evolving.
@export_range(1, 16, 1) var upgrade_slot_count := 8
## Extra upgrade-line slots granted by completing the pair Evolution, so the third
## path and the Evolution line can be developed without deleting the build already
## assembled. Eight paired-path lines plus these five positions fill the 13-slot HUD.
@export_range(0, 8, 1) var evolution_bonus_upgrade_slots := 5
## Fraction of a spent level's XP converted to Biomass when no draft option remains.
@export_range(0.0, 2.0, 0.05) var exhausted_draft_biomass_ratio := 0.75
## Upgrade-draft rerolls granted for an entire run.
@export_range(0, 20, 1) var rerolls_per_run := 3
## Seed for every draw the run makes. Zero rolls a fresh one per run, which is what
## a played run wants; anything else pins the drafting so a run can be replayed or a
## report reproduced.
@export var authored_run_seed := 0

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
## Thistle, Vine, Fruit, and the universal Cane. Kept as Node here because the
## adaptation component also reads Progression and would otherwise form a typed
## parse-time cycle.
@export var adaptation_director: Node
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

@export_group("Relic Effects")
## Multiple of the base Biomass cost granted when the relic pool is exhausted.
@export_range(0.0, 10.0, 0.5) var relic_overflow_biomass_multiplier := 3.0

@export_group("Development Path Offers")
## Development switch for narrowing a playtest to the paths under test. Turning a
## path off keeps it out of both path milestones and keeps its four upgrade lines
## out of every level-up draft. A path a run already holds keeps working.
@export var offer_spore_path := true
## Development switch; see Offer Spore Path.
@export var offer_bloom_path := true
## Development switch; see Offer Spore Path.
@export var offer_bramble_path := true
## Development switch; see Offer Spore Path.
@export var offer_root_path := true
## Development switch; see Offer Spore Path.
@export var offer_pruning_path := true
## Development switch; see Offer Spore Path.
@export var offer_thistle_path := true
## Development switch; see Offer Spore Path.
@export var offer_vine_path := true
## Development switch; see Offer Spore Path.
@export var offer_fruit_path := true

var primary_path := UNSELECTED_PATH
var secondary_path := UNSELECTED_PATH
## Support path chosen after the Evolution consolidates the first two into one slot.
var tertiary_path := UNSELECTED_PATH
var current_level := 1
var current_xp := 0
var rerolls_remaining := 0
var biomass := 0.0
var biomass_per_second := 0.0
## Every unit of Biomass the run has ever earned, which is what Metabolism grows on.
## Kept apart from the balance on purpose: what is spent or wagered away still counted
## toward the organism's physical development, so a bad spin costs a stake rather than
## undoing the run's growth.
var biomass_earned_total := 0.0
## Kept readable here because most of the run asks Progression for the state of
## the run. Both are owned by the Evolutions node and read straight back off it.
var evolution_status: int:
	get:
		return evolutions.evolution_status if evolutions != null else EvolutionStatus.NOT_READY
var active_evolution: int:
	get:
		return evolutions.active_evolution if evolutions != null else EvolutionId.NONE

var _upgrade_levels := PackedInt32Array()
## Paths currently being run at the casino ceiling, as a set of PathId. Empty for the
## whole of a run in which nobody pulls the lever.
var _casino_paths := {}
var _owned_relics := PackedByteArray()
var _pending_upgrade_options := PackedInt32Array()
var _pending_upgrade_is_support_choice := false
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
var _draft_random := RandomNumberGenerator.new()
## The seed every draw in the run comes out of. Rolled fresh each run so two runs
## are not handed the same three lines, and kept so one can be replayed: set it
## before the first draft and the whole run's drafting repeats exactly.
var run_seed := 0

func set_run_seed(seed_value: int) -> void:
	# Every draw in the run hangs off this. The cursor starts somewhere the seed
	# chose rather than at the top of the enum, because a fixed starting point is
	# what made the opening draft the same three lines in every run.
	run_seed = seed_value
	_draft_random.seed = seed_value ^ 0x9E3779B9
	_relic_random.seed = seed_value ^ 0x85EBCA6B
	_upgrade_offer_cursor = _draft_random.randi() % UpgradeId.size()


func _roll_run_seed() -> int:
	# Godot seeds the global generator differently on every launch, so this is a
	# different run every time the game is started as well as every time it is reset.
	return randi() | 1


func _ready() -> void:
	assert(evolutions != null, "PhaseBProgression requires PhaseBEvolutions")
	# Relayed rather than re-owned: the run listens to Progression for the shape of
	# its own progress, and the Evolutions node is where the change actually happens.
	evolutions.evolution_changed.connect(evolution_changed.emit)
	reset_progression()

func reset_progression() -> void:
	_casino_paths.clear()
	primary_path = UNSELECTED_PATH
	secondary_path = UNSELECTED_PATH
	tertiary_path = UNSELECTED_PATH
	current_level = 1
	current_xp = 0
	biomass = 0.0
	biomass_per_second = 0.0
	biomass_earned_total = 0.0
	if evolutions != null:
		evolutions.reset_evolutions()
	rerolls_remaining = rerolls_per_run
	_relic_rerolls_remaining = relic_rerolls_per_run
	_relic_reroll_used = false
	_last_rerolled_relic_rarity = -1
	# A run's draws come out of one seed, rolled fresh unless the scene pins one. The
	# streams are separated by mixing constants rather than by being separate seeds,
	# so a seed still describes the whole run and a relic draw cannot shift which
	# upgrades a level offers.
	set_run_seed(authored_run_seed if authored_run_seed != 0 else _roll_run_seed())
	_pending_upgrade_options.clear()
	_pending_upgrade_is_support_choice = false
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
		PathId.THISTLE:
			return offer_thistle_path
		PathId.VINE:
			return offer_vine_path
		PathId.FRUIT:
			return offer_fruit_path
	return true

func request_tertiary_upgrade_choice() -> bool:
	# Support is chosen through a real upgrade, just like an opening Path commitment:
	# the selected rank-1 line determines which unused Path fills the tertiary slot.
	if (
		evolution_status != EvolutionStatus.EVOLVED
		or tertiary_path != UNSELECTED_PATH
		or _has_any_pending_choice()
	):
		return false
	var candidates := PackedInt32Array()
	for offset in range(UpgradeId.size()):
		var upgrade_id := (_upgrade_offer_cursor + offset) % UpgradeId.size()
		if evolutions.get_upgrade_evolution(upgrade_id) != EvolutionId.NONE:
			continue
		var path_id := _get_upgrade_path(upgrade_id)
		if path_id == UNSELECTED_PATH or has_path(path_id) or not is_path_offered(path_id):
			continue
		candidates.append(upgrade_id)
	var drawn := _draw_upgrade_candidates(candidates, mini(3, candidates.size()))
	if drawn.is_empty():
		return false
	_pending_upgrade_options = drawn
	_pending_upgrade_is_support_choice = true
	_upgrade_offer_cursor = (_upgrade_offer_cursor + 1) % UpgradeId.size()
	upgrade_choice_requested.emit(_pending_upgrade_options.duplicate())
	return true

func is_pending_support_upgrade_choice() -> bool:
	return _pending_upgrade_is_support_choice and not _pending_upgrade_options.is_empty()

func has_tertiary_path() -> bool:
	return tertiary_path != UNSELECTED_PATH

func is_tertiary_path_available() -> bool:
	return evolution_status == EvolutionStatus.EVOLVED and not has_tertiary_path()

func get_upgrade_slot_count() -> int:
	# Evolving does not delete the eight paired-path lines already slotted; it adds
	# one Evolution-line position and four support-path positions beside them.
	if evolution_status == EvolutionStatus.EVOLVED:
		return upgrade_slot_count + evolution_bonus_upgrade_slots
	return upgrade_slot_count

func choose_path(path_id: int) -> bool:
	if _pending_path_options.find(path_id) == -1:
		return false
	if _pending_path_is_primary:
		primary_path = path_id
	else:
		secondary_path = path_id
	_pending_path_options.clear()
	if evolutions != null:
		# Changing either pairing Path invalidates whatever it would have evolved into.
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

func get_path_rank_fraction(path_id: int) -> float:
	## How far into a Path the run actually is, from 0 at not owning it to 1 with every
	## one of its lines maxed. Presentation asks this: a Path the run has just taken and
	## a Path it has spent the whole run on should not look identical on the battlefield.
	##
	## Read from owned ranks rather than borrowed ones, because it describes the build.
	## A Clover jackpot lends behaviour for ten seconds and must not repaint the ground
	## as though the run had bought the Path.
	if not has_path(path_id):
		return 0.0
	var owned := 0
	var possible := 0
	for upgrade_id in range(UpgradeId.size()):
		if _get_upgrade_path(upgrade_id) != path_id:
			continue
		owned += get_owned_upgrade_level(upgrade_id)
		possible += maximum_upgrade_level
	if possible <= 0:
		return 1.0
	# Never zero for a Path the run owns: taking the Path is itself the first thing
	# worth showing, and a fraction that starts at nothing would hide it until the
	# first draft landed.
	return clampf(0.25 + 0.75 * float(owned) / float(possible), 0.0, 1.0)

func has_active_evolution(evolution_id: int) -> bool:
	return evolutions != null and evolutions.has_active_evolution(evolution_id)

func get_pair_evolution_id() -> int:
	return evolutions.get_pair_evolution_id() if evolutions != null else EvolutionId.NONE

func get_evolution_upgrade_level() -> int:
	return evolutions.get_evolution_upgrade_level() if evolutions != null else 0

func is_pair_evolution_draftable() -> bool:
	return evolutions != null and evolutions.is_pair_evolution_draftable()

func grant_evolution_if_ready() -> bool:
	if evolutions == null or not evolutions.grant_evolution_if_ready():
		return false
	var upgrade_id: int = evolutions.get_evolution_upgrade_id(active_evolution)
	if upgrade_id >= 0 and get_owned_upgrade_level(upgrade_id) == 0:
		_upgrade_levels[upgrade_id] = 1
	upgrades_changed.emit()
	return true

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


func configure_mode(mode: int) -> void:
	# Campaign has more time and more authored adaptation positions to fill, so its
	# level curve uses the measured 30-minute pacing while Quick keeps its balance.
	if mode == RUN_MODE.Id.CAMPAIGN:
		xp_requirement_growth = 1.20

func choose_upgrade(upgrade_id: int) -> bool:
	if _pending_upgrade_options.find(upgrade_id) == -1:
		return false
	if get_owned_upgrade_level(upgrade_id) >= get_upgrade_maximum_level(upgrade_id):
		return false
	_upgrade_levels[upgrade_id] += 1
	_pending_upgrade_options.clear()
	_pending_upgrade_is_support_choice = false
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

func get_owned_upgrade_level(upgrade_id: int) -> int:
	## What the run has actually bought. Drafting, slot occupancy, upgrade text and
	## evolution readiness all read this rather than the effective level: a Clover
	## jackpot lends a Path its ceiling for a few seconds and must not be able to
	## unlock an Evolution or fill a growth-line slot on the way past.
	if upgrade_id < 0 or upgrade_id >= _upgrade_levels.size():
		return 0
	return _upgrade_levels[upgrade_id]

func get_upgrade_level(upgrade_id: int) -> int:
	## What the mechanics should behave as: the owned level, plus the whole of the
	## casino ceiling while a Clover jackpot is running that Path.
	##
	## Added rather than raised to a floor. A player who has already maxed a line has
	## bought that ceiling, and a jackpot that merely handed it back what it already
	## owned would be no reward at all - it would read as the machine paying out nothing
	## for the Path the run is actually built around. Level 5 becomes 10, level 4 becomes
	## 9, and an unowned Path still arrives at a full 5.
	var owned := get_owned_upgrade_level(upgrade_id)
	if _casino_paths.is_empty():
		return owned
	var path := _get_upgrade_path(upgrade_id)
	if path == UNSELECTED_PATH or not _casino_paths.has(path):
		return owned
	return owned + casino_upgrade_level


func get_upgrade_maximum_level(_upgrade_id: int) -> int:
	return maximum_upgrade_level


func has_path_active(path_id: int) -> bool:
	## Whether a Path's mechanics should be running at all - which a Clover jackpot turns
	## on for a Path the run does not own, because a jackpot that raised the numbers on a
	## mechanic nobody had switched on would produce nothing at all.
	##
	## Deliberately not the same question as has_path. That one is ownership, and stays
	## ownership: it decides drafting, which lines may be offered, and which relics are
	## eligible. A jackpot lends a Path's behaviour and never its membership in the build.
	return has_path(path_id) or _casino_paths.has(path_id)

func set_casino_path_active(path_id: int, active: bool) -> void:
	## A Clover jackpot runs a Path as though all four of its lines were maxed, whether
	## or not the run owns the Path at all. It is a loan, not a purchase: nothing is
	## added to the build, and ownership itself is deliberately not granted, so a relic
	## that requires the player to have selected the Path keeps requiring it.
	if active:
		_casino_paths[path_id] = true
	else:
		_casino_paths.erase(path_id)

func is_casino_path_active(path_id: int) -> bool:
	return _casino_paths.has(path_id)

func clear_casino_paths() -> void:
	_casino_paths.clear()

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
	var earned := biomass_per_second * delta
	biomass += earned
	biomass_earned_total += earned
	biomass_changed.emit(biomass, biomass_per_second)

func get_selected_paths() -> PackedInt32Array:
	# Whichever Paths the run is actually built out of, in one place, so anything that
	# leans on the build does not have to know how many slots there are.
	var selected := PackedInt32Array()
	if primary_path != UNSELECTED_PATH:
		selected.append(primary_path)
	if secondary_path != UNSELECTED_PATH:
		selected.append(secondary_path)
	return selected


func add_biomass(amount: float) -> void:
	if amount > 0.0:
		biomass_earned_total += amount
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

func is_relic_eligible(relic_id: int) -> bool:
	## An offer may contain Plant relics and relics of Adaptations the run
	## permanently owns, and nothing else.
	##
	## Ownership is has_path on purpose rather than has_path_active: a Clover
	## jackpot lends an Adaptation's behaviour for ten seconds and must not open
	## that Adaptation's relic pool along with it.
	if has_relic(relic_id):
		return false
	if PhaseBRelicCatalog.get_pool(relic_id) == PhaseBRelicCatalog.Pool.PLANT:
		return true
	return has_path(PhaseBRelicCatalog.get_owning_path(relic_id))

func get_eligible_relics() -> PackedInt32Array:
	var eligible := PackedInt32Array()
	for relic_id in range(PhaseBRelicCatalog.get_count()):
		if is_relic_eligible(relic_id):
			eligible.append(relic_id)
	return eligible

func get_relic_run_state() -> int:
	## Which rarity table this run rolls against. Deliberately reads the shape of
	## the build rather than elapsed time, so a run that took its support
	## Adaptation early gets the deeper table early.
	if has_tertiary_path():
		return PhaseBRelicCatalog.RunState.SUPPORT_LATE
	if evolution_status == EvolutionStatus.EVOLVED:
		return PhaseBRelicCatalog.RunState.POST_EVOLUTION
	if has_primary_path() and has_secondary_path():
		return PhaseBRelicCatalog.RunState.TWO_PRE_EVOLUTION
	return PhaseBRelicCatalog.RunState.SINGLE_ADAPTATION

func get_relic_rarity_odds() -> PackedFloat32Array:
	return PhaseBRelicCatalog.get_rarity_odds(get_relic_run_state())

func _roll_relic_rarity(odds: PackedFloat32Array) -> int:
	var roll := _relic_random.randf()
	for rarity in range(odds.size()):
		roll -= odds[rarity]
		if roll <= 0.0:
			return rarity
	return PhaseBRelicCatalog.Rarity.COMMON

func _roll_relic_options() -> PackedInt32Array:
	## One rarity roll per offered slot rather than one roll for the whole screen,
	## then an unowned eligible relic of that rarity.
	##
	## An exhausted rarity falls downward -- Legendary to Rare to Uncommon to
	## Common -- and never upward, so running out of Rares can never manufacture a
	## Legendary the odds did not actually produce.
	var candidates := get_eligible_relics()
	var offers := PackedInt32Array()
	if candidates.is_empty():
		return offers
	var odds := get_relic_rarity_odds()
	while offers.size() < relic_offer_count and not candidates.is_empty():
		var drawn := _draw_relic_of_rarity(candidates, _roll_relic_rarity(odds))
		if drawn == -1:
			break
		offers.append(drawn)
		var remaining := PackedInt32Array()
		for relic_id in candidates:
			if relic_id != drawn:
				remaining.append(relic_id)
		candidates = remaining
	return offers

func _draw_relic_of_rarity(candidates: PackedInt32Array, rarity: int) -> int:
	# Falls downward through the rarities until one has a candidate left. Returns
	# -1 only when the whole eligible pool is spent.
	var wanted := rarity
	while wanted >= PhaseBRelicCatalog.Rarity.COMMON:
		var matching := PackedInt32Array()
		for relic_id in candidates:
			if PhaseBRelicCatalog.get_rarity(relic_id) == wanted:
				matching.append(relic_id)
		if not matching.is_empty():
			return matching[_relic_random.randi_range(0, matching.size() - 1)]
		wanted -= 1
	return -1

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
	var offers := _roll_relic_options()
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
		if get_owned_upgrade_level(upgrade_id) > 0:
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
				get_upgrade_maximum_level(upgrade_id),
			])
	if lines.is_empty():
		return "No upgrade lines slotted"
	return "\n".join(lines)

static func get_upgrade_name(upgrade_id: int) -> String:
	match upgrade_id:
		UpgradeId.SEED_PRODUCTION:
			return "Seed Production"
		UpgradeId.GROWTH_MASS:
			return "Growth Mass"
		UpgradeId.SPORULATION:
			return "Sporulation"
		UpgradeId.FRUITING_BODIES:
			return "Fruiting Bodies"
		UpgradeId.BLOOM_FORCE:
			return "Bloom Force"
		UpgradeId.BLOOM_FREQUENCY:
			return "Bloom Frequency"
		UpgradeId.AFTERGROWTH:
			return "Aftergrowth"
		UpgradeId.SUPPRESSION:
			return "Suppression"
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
		UpgradeId.ROOT_LATERAL_ROOTS:
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
		UpgradeId.THISTLE_CLUSTERING:
			return "Clustering"
		UpgradeId.THISTLE_DEHISCENCE:
			return "Dehiscence"
		UpgradeId.THISTLE_BURR:
			return "Burr"
		UpgradeId.THISTLE_NEEDLEPOINT:
			return "Needlepoint"
		UpgradeId.VINE_ELONGATION:
			return "Elongation"
		UpgradeId.VINE_LIGNIFICATION:
			return "Lignification"
		UpgradeId.VINE_TURGOR:
			return "Turgor"
		UpgradeId.VINE_APICAL_DOMINANCE:
			return "Apical Dominance"
		UpgradeId.FRUIT_SET:
			return "Fruit Set"
		UpgradeId.FRUIT_RIPENING:
			return "Ripening"
		UpgradeId.FRUIT_MOMENTUM:
			return "Momentum"
		UpgradeId.FRUIT_GERMINATION:
			return "Germination"
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
		UpgradeId.EVOLUTION_SECOND_FLUSH:
			return "Second Flush"
		UpgradeId.EVOLUTION_COMPRESSION:
			return "Compression"
		UpgradeId.EVOLUTION_SPLINTERSTORM:
			return "Splinterstorm"
		UpgradeId.EVOLUTION_STOOL_REGROWTH:
			return "Stool Regrowth"
		UpgradeId.EVOLUTION_INOCULATOR:
			return "Inoculator"
		UpgradeId.EVOLUTION_BURSTBLOOM:
			return "Burstbloom"
		UpgradeId.EVOLUTION_HEDGE_BATTERY:
			return "Hedge Battery"
		UpgradeId.EVOLUTION_ROOTSTOCK:
			return "Rootstock"
		UpgradeId.EVOLUTION_DEADHEADING:
			return "Deadheading"
		UpgradeId.EVOLUTION_THORNWHIP:
			return "Thornwhip"
		UpgradeId.EVOLUTION_BURDOCK:
			return "Burdock"
		UpgradeId.EVOLUTION_MYCELIAL_VINE:
			return "Mycelial Vine"
		UpgradeId.EVOLUTION_WISTERIA:
			return "Wisteria"
		UpgradeId.EVOLUTION_BRIAR_CANE:
			return "Briar Cane"
		UpgradeId.EVOLUTION_HEARTWOOD:
			return "Heartwood"
		UpgradeId.EVOLUTION_ESPALIER:
			return "Espalier"
		UpgradeId.EVOLUTION_GOURDVINE:
			return "Gourdvine"
		UpgradeId.EVOLUTION_ROT:
			return "Rot"
		UpgradeId.EVOLUTION_OVERRIPE:
			return "Overripe"
		UpgradeId.EVOLUTION_DURIAN:
			return "Durian"
		UpgradeId.EVOLUTION_ORCHARD:
			return "Orchard"
		UpgradeId.EVOLUTION_GRAFT:
			return "Graft"
	return "Unknown Upgrade"

func get_upgrade_description(upgrade_id: int) -> String:
	if evolutions.get_upgrade_evolution(upgrade_id) != EvolutionId.NONE:
		var next_rank := get_owned_upgrade_level(upgrade_id) + 1
		return evolutions.get_evolution_upgrade_rank_description(
			upgrade_id,
			next_rank
		)
	match upgrade_id:
		UpgradeId.SEED_PRODUCTION:
			return "One fewer kill required per Seed"
		UpgradeId.GROWTH_MASS:
			return "+%d%% Seed growth mass" % roundi(spore_director.seed_mass_per_level * 100.0 if spore_director != null else 0.0)
		UpgradeId.SPORULATION:
			return "+%d%% Spore accumulation on enemies standing in your Green" % roundi(
				spore_director.sporulation_rate_per_level * 100.0
				if spore_director != null
				else 0.0
			)
		UpgradeId.FRUITING_BODIES:
			return "+%d%% chance a Seed germinating inside your Green raises a colony" % roundi(
				spore_director.fruiting_body_chance_per_level * 100.0
				if spore_director != null
				else 0.0
			)
		UpgradeId.BLOOM_FORCE:
			return "+%d%% Bloom pressure and damage" % roundi(bloom_director.bloom_force_per_level * 100.0 if bloom_director != null else 0.0)
		UpgradeId.BLOOM_FREQUENCY:
			return "%d%% shorter Bloom interval" % roundi(
				(1.0 - (bloom_director.bloom_interval_multiplier_per_level if bloom_director != null else 0.0)) * 100.0
			)
		UpgradeId.AFTERGROWTH:
			return "+%d temporary control shielding Green a Bloom touches" % roundi(
				bloom_director.aftergrowth_per_level if bloom_director != null else 0.0
			)
		UpgradeId.SUPPRESSION:
			return "Bloom-struck enemies do %d%% less Territory damage" % roundi(
				bloom_director.suppression_per_level * 100.0 if bloom_director != null else 0.0
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
		UpgradeId.ROOT_LATERAL_ROOTS:
			return "+%d px Root Network reach projected from Mature Green" % roundi(
				root_director.lateral_reach_per_level if root_director != null else 0.0
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
		UpgradeId.THISTLE_CLUSTERING:
			return "+1 thorn per turret firing event"
		UpgradeId.THISTLE_DEHISCENCE:
			return "+15% Thistle attack speed"
		UpgradeId.THISTLE_BURR:
			return "+1 full-damage ricochet target per thorn"
		UpgradeId.THISTLE_NEEDLEPOINT:
			return "+10 percentage points Thistle critical chance (2x damage)"
		UpgradeId.VINE_ELONGATION:
			return "+20% Cane sweep reach"
		UpgradeId.VINE_LIGNIFICATION:
			return "+25% Cane sweep damage"
		UpgradeId.VINE_TURGOR:
			return "+15% Cane attack speed"
		UpgradeId.VINE_APICAL_DOMINANCE:
			return "+25% damage in the outermost 25% of the Cane sweep"
		UpgradeId.FRUIT_SET:
			return "+1 Fruit per release"
		UpgradeId.FRUIT_RIPENING:
			return "+25% Fruit collision and terminal damage"
		UpgradeId.FRUIT_MOMENTUM:
			return "+20% maximum Fruit roll distance"
		UpgradeId.FRUIT_GERMINATION:
			return "+20% Green area created by Fruit"
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
		PathId.THISTLE:
			return "Thistle"
		PathId.VINE:
			return "Vine"
		PathId.FRUIT:
			return "Fruit"
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
		PathId.THISTLE:
			return "Plant two stationary Thistles on your Green; they fire thorns and replant when their support is lost."
		PathId.VINE:
			return "Grow Cane into a green lash that auto-targets the densest valid sector."
		PathId.FRUIT:
			return "Roll painted Fruit toward enemy crowds, trail Green, then burst into a terminal foothold."
	return ""

static func get_relic_name(relic_id: int) -> String:
	return PhaseBRelicCatalog.get_relic_name(relic_id)

static func get_relic_rarity(relic_id: int) -> int:
	return PhaseBRelicCatalog.get_rarity(relic_id)

func get_relic_description(relic_id: int) -> String:
	return PhaseBRelicCatalog.get_relic_description(relic_id)

func get_relic_requirement_text(relic_id: int) -> String:
	# What a relic needs before it can be offered, so a locked entry in the
	# collection row explains itself rather than only being empty. Plant is always
	# available; every other pool names the Adaptation that unlocks it.
	return PhaseBRelicCatalog.get_pool_name(PhaseBRelicCatalog.get_pool(relic_id))

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
	var rerolling_support := _pending_upgrade_is_support_choice
	# A redraw can legitimately come back with the same three lines, and a reroll that
	# appears to do nothing is a reroll the player believes is broken. Keep drawing -
	# from a new cursor each time, so even a pool too small to shuffle eventually
	# moves - and give up rather than spending a reroll on a pool that cannot produce
	# a different offer at all.
	for _attempt in range(UpgradeId.size()):
		_upgrade_offer_cursor = (_upgrade_offer_cursor + 1) % UpgradeId.size()
		_pending_upgrade_options.clear()
		_pending_upgrade_is_support_choice = false
		var rolled := (
			request_tertiary_upgrade_choice()
			if rerolling_support
			else _roll_upgrade_options()
		)
		if not rolled:
			continue
		if not _is_same_offer(_pending_upgrade_options, previous_offer):
			rerolls_remaining -= 1
			rerolls_changed.emit(rerolls_remaining)
			upgrade_choice_requested.emit(_pending_upgrade_options.duplicate())
			return true
	# Nothing else was available: restore the draft the player was looking at
	# rather than leaving them with an empty panel, and charge them nothing.
	_pending_upgrade_options = previous_offer
	_pending_upgrade_is_support_choice = rerolling_support
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
	_pending_upgrade_is_support_choice = false
	_try_request_level_up()
	xp_changed.emit(current_level, current_xp, get_required_xp())
	return true

func _roll_upgrade_options() -> bool:
	_pending_upgrade_is_support_choice = false
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
		var level := get_owned_upgrade_level(upgrade_id)
		if level >= get_upgrade_maximum_level(upgrade_id):
			continue
		if occupied_slots >= get_upgrade_slot_count() and level == 0:
			continue
		candidates.append(upgrade_id)
	if candidates.is_empty() and evolution_slots == 0:
		return false
	if evolution_slots > 0:
		_pending_upgrade_options.append(EVOLUTION_DRAFT_OPTION)
	var offer_count := mini(3 - evolution_slots, candidates.size())
	# The line the cursor is standing on is always offered, so the sequence still
	# walks the whole pool over a run rather than leaving lines undrawn. The rest are
	# drawn at random, preferring paths the offer does not already carry: a wide
	# pre-commitment draft has to represent the board rather than three lines of one
	# path, and that was the only thing the old even spread was really buying.
	var drawn := _draw_upgrade_candidates(candidates, offer_count)
	for upgrade_id in drawn:
		_pending_upgrade_options.append(upgrade_id)
	_upgrade_offer_cursor = (_upgrade_offer_cursor + 1) % UpgradeId.size()
	return true

func _draw_upgrade_candidates(candidates: PackedInt32Array, offer_count: int) -> PackedInt32Array:
	var drawn := PackedInt32Array()
	if offer_count <= 0 or candidates.is_empty():
		return drawn
	drawn.append(candidates[0])
	var remaining: Array[int] = []
	for index in range(1, candidates.size()):
		remaining.append(candidates[index])
	_shuffle_upgrades(remaining)
	while drawn.size() < offer_count and not remaining.is_empty():
		var taken := -1
		for index in range(remaining.size()):
			if not _offer_carries_path(drawn, _get_upgrade_path(remaining[index])):
				taken = index
				break
		if taken < 0:
			taken = 0
		drawn.append(remaining[taken])
		remaining.remove_at(taken)
	return drawn

func _shuffle_upgrades(upgrades: Array[int]) -> void:
	# Fisher-Yates off the run's own generator rather than Array.shuffle, which draws
	# from the global one: two runs with the same seed have to draft identically.
	for index in range(upgrades.size() - 1, 0, -1):
		var swap := _draft_random.randi() % (index + 1)
		var held := upgrades[index]
		upgrades[index] = upgrades[swap]
		upgrades[swap] = held


func _offer_carries_path(offer: PackedInt32Array, path_id: int) -> bool:
	for upgrade_id in offer:
		if _get_upgrade_path(upgrade_id) == path_id:
			return true
	return false


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
		UpgradeId.SEED_PRODUCTION, UpgradeId.GROWTH_MASS, \
		UpgradeId.SPORULATION, UpgradeId.FRUITING_BODIES:
			return PathId.SPORE
		UpgradeId.BLOOM_FORCE, UpgradeId.BLOOM_FREQUENCY, \
		UpgradeId.AFTERGROWTH, UpgradeId.SUPPRESSION:
			return PathId.BLOOM
		UpgradeId.BRAMBLE_ENTANGLEMENT, UpgradeId.BRAMBLE_ENSNARE_RATE, \
		UpgradeId.BRAMBLE_GRASPING_ROOTS, UpgradeId.BRAMBLE_REPULSION:
			return PathId.BRAMBLE
		UpgradeId.ROOT_MATURATION, UpgradeId.ROOT_LATERAL_ROOTS, \
		UpgradeId.ROOT_MATURE_STRENGTH, UpgradeId.ROOT_POTENCY:
			return PathId.ROOT
		UpgradeId.PRUNING_HARVEST_RATE, UpgradeId.PRUNING_CUTTING_YIELD, \
		UpgradeId.PRUNING_CUTTING_DAMAGE, UpgradeId.PRUNING_CHARGE:
			return PathId.PRUNING
		UpgradeId.THISTLE_CLUSTERING, UpgradeId.THISTLE_DEHISCENCE, \
		UpgradeId.THISTLE_BURR, UpgradeId.THISTLE_NEEDLEPOINT:
			return PathId.THISTLE
		UpgradeId.VINE_ELONGATION, UpgradeId.VINE_LIGNIFICATION, \
		UpgradeId.VINE_TURGOR, UpgradeId.VINE_APICAL_DOMINANCE:
			return PathId.VINE
		UpgradeId.FRUIT_SET, UpgradeId.FRUIT_RIPENING, \
		UpgradeId.FRUIT_MOMENTUM, UpgradeId.FRUIT_GERMINATION:
			return PathId.FRUIT
	return UNSELECTED_PATH

func _has_maxed_path_line(path_id: int) -> bool:
	for upgrade_id in range(UpgradeId.size()):
		if (
			_get_upgrade_path(upgrade_id) == path_id
			and get_owned_upgrade_level(upgrade_id) >= maximum_upgrade_level
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
		PathId.THISTLE:
			return UpgradeId.THISTLE_CLUSTERING
		PathId.VINE:
			return UpgradeId.VINE_LIGNIFICATION
		PathId.FRUIT:
			return UpgradeId.FRUIT_RIPENING
	return UpgradeId.GROWTH_MASS

func _emit_all_state() -> void:
	paths_changed.emit()
	xp_changed.emit(current_level, current_xp, get_required_xp())
	upgrades_changed.emit()
	biomass_changed.emit(biomass, biomass_per_second)
	metabolism_changed.emit()
	relics_changed.emit()
	evolution_changed.emit(evolution_status)
	rerolls_changed.emit(rerolls_remaining)
