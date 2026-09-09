class_name Progression
extends Node

const RUN_MODE := preload("res://src/core/models/run/run_mode.gd")

signal xp_changed(level: int, current_xp: int, required_xp: int)
signal upgrade_choice_requested(options: PackedInt32Array)
signal rerolls_changed(remaining: int)
signal upgrades_changed
signal paths_changed
signal biomass_changed(current: float, per_second: float)
signal metabolism_changed
signal relic_choice_requested(options: PackedInt32Array)
signal relics_changed
signal evolution_changed(status: int)
## An Adaptation entered the run through a Core or Branch slot.
signal adaptation_acquired(path_id: int, slot_kind: int, slot_index: int)
## A milestone opened a Branch position for an Adaptation still to be drafted.
signal branch_slot_unlocked(unlocked_count: int)
## The two Cores are locked, and with them the run's only Evolution.
signal core_pair_locked(core_a: int, core_b: int, evolution_id: int)
## Every ordinary line of one Adaptation reached rank 3.
signal adaptation_mastered(path_id: int)
## Every relic pool the run may now be offered from changed.
signal relic_pools_changed(eligible_pool_ids: PackedInt32Array)
## Every eligible relic is already held, so the reward pays out as a Compost Cache.
signal compost_cache_granted
## No ordinary or Evolution rank remains to buy. Announced once per run.
signal garden_completed

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

## Draft option identifying the pair evolution rather than an upgrade line.
const EVOLUTION_DRAFT_OPTION := -2

## Which kind of slot an Adaptation occupies. Core and Branch are both permanent
## and both complete: the only differences are that the unordered Core pair names
## the run's Evolution, and that only Core lines satisfy the Evolution gate.
enum SlotKind {
	CORE,
	BRANCH,
}

## Adaptations the run may ever own, split into the two Core positions that decide
## the Evolution and the two Branch positions that never can. Four of eight is 70
## rosters before the Core pair, investment order, Evolution rank and relics are
## considered, and it still stops a run from switching on the entire arsenal.
const MAXIMUM_CORE_ADAPTATIONS := 2
const MAXIMUM_BRANCH_ADAPTATIONS := 2
const MAXIMUM_OWNED_ADAPTATIONS := MAXIMUM_CORE_ADAPTATIONS + MAXIMUM_BRANCH_ADAPTATIONS

## Ordinary lines every owned Adaptation exposes, all of them from the moment it is
## acquired. Nothing is ever permanently rejected: a lower-priority utility line is
## delayed by choice rather than locked out of the run.
const LINES_PER_ADAPTATION := 4

## Mastered lines each Core needs before the pairing may be claimed. Twelve
## ordinary purchases, six in each Core, and no Branch line, temporary Clover rank
## or relic bonus counts toward it.
const MASTERED_LINES_FOR_EVOLUTION := 2

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
	BRAMBLE_ENTANGLEMENT_RATE,
	BRAMBLE_GRASPING_THORNS,
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
## Highest rank obtainable by an ordinary Adaptation line.
##
## Three, not five. Every owned Adaptation exposes all four of its lines, so a run
## that could take each of them to five would rebuild the old multiplicative
## ceilings four times over. Per-rank values are deliberately unchanged: rank 3 is
## sixty per cent of the former rank-5 total, not the same total in fewer steps.
@export_range(1, 10, 1) var maximum_upgrade_level := 3
## Highest rank obtainable by the run's Evolution line. Preserved at the authored
## five because those ranks are distinct mechanics rather than repeated stat
## increments, and compressing them would mean redesigning all 28 Evolutions.
@export_range(1, 10, 1) var evolution_maximum_upgrade_level := 5
## Rank every line of a Path is run at while a Clover jackpot has that Path lit. The
## jackpot's whole promise is a fully maxed Path, so this tracks the ceiling above
## rather than being a second number that can drift away from it.
@export_range(1, 10, 1) var casino_upgrade_level := 3
## Upgrade screens a line may sit out before it is forced into the next unrestricted
## slot, so a sixteen-line pool cannot bury one line for the whole run.
@export_range(1, 12, 1) var line_drought_forced_screens := 4
## Upgrade screens after which a line's draw weight is raised.
@export_range(1, 12, 1) var line_drought_boost_screens := 2
## Weight multiplier for a line that has not been offered recently.
@export_range(1.0, 4.0, 0.05) var line_drought_boost_weight := 1.5
## Weight multiplier for a line that was on the previous screen, so a redraw is
## much more likely to move than to hand back what the player just declined.
@export_range(0.05, 1.0, 0.05) var line_repeat_weight := 0.65
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
@export var bramble_director: BrambleDirector
## Root component that owns that path's tuning and derived values.
@export var root_director: RootDirector
## Spore component that owns that path's tuning and derived values.
@export var spore_director: SporeDirector
## Bloom component that owns that path's tuning and derived values.
@export var bloom_director: BloomDirector
## Pruning component that owns that path's tuning and derived values.
@export var pruning_director: PruningDirector
## Thistle, Vine, Fruit, and the universal Cane. Kept as Node here because the
## adaptation component also reads Progression and would otherwise form a typed
## parse-time cycle.
@export var adaptation_director: Node
## Ecosystem Metabolism component. Progression still owns the Biomass currency;
## what allocating that currency does to the simulation belongs to Metabolism, so
## the physical multipliers are read back from it rather than kept here.
@export var metabolism: Metabolism

@export_group("Relic Effects")
## Biomass generated each second per percentage point of the arena held as Green.
@export_range(0.0, 2.0, 0.001) var biomass_per_green_percent := 0.018
## Extra Biomass generated each second per percentage point of the arena held as
## Mature Green. Both coefficients now multiply the same kind of quantity - a share
## of the whole arena - which is the invariant that was silently broken while this
## one was being fed a share of held Green instead.
##
## 0.022 is a compatibility value, not a balance target. It was chosen to land the
## opening economy back on the ~0.16 Biomass/s the run produced before the metric was
## corrected, so the territory rework can be tested without also moving the economy
## under it. No single coefficient can preserve the old curve everywhere: the old
## formula fed the same number for a run holding 10% Green and one holding 60%, and
## the corrected one does not, which is the entire point of fixing it. Retune across
## early, mid, strong, damaged and recovery states once the territory loop settles.
@export_range(0.0, 4.0, 0.001) var biomass_per_mature_percent := 0.022
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

## The run's permanently owned Adaptations, in acquisition order.
##
## One authoritative pair of arrays rather than three named slots. Everything that
## asks whether the run owns an Adaptation asks owns_adaptation, and nothing infers
## ownership from a nonzero rank, a Clover jackpot, an Evolution-generated event or
## a live entity on the field.
##
## Ordinary Arrays rather than Packed ones on purpose: a Packed array is a value
## type in GDScript, so a helper handed one would quietly edit a copy of the run's
## roster instead of the roster.
var core_adaptations: Array[int] = []
var branch_adaptations: Array[int] = []
## Branch positions the run has earned. Zero until the Elite falls, one until the
## Boss does. Kept apart from what fills them, because earning the room and
## choosing what grows in it are two different moments.
var unlocked_branch_slots := 0

## Compatibility aliases. The Evolutions node and the HUD still speak of a primary
## and a secondary; those are Core 1 and Core 2, and the old support slot is
## Branch 1. New logic reads the arrays directly.
var primary_path: int:
	get:
		return core_adaptations[0] if core_adaptations.size() > 0 else UNSELECTED_PATH
	set(value):
		_set_core_slot(0, value)
var secondary_path: int:
	get:
		return core_adaptations[1] if core_adaptations.size() > 1 else UNSELECTED_PATH
	set(value):
		_set_core_slot(1, value)
var tertiary_path: int:
	get:
		return branch_adaptations[0] if branch_adaptations.size() > 0 else UNSELECTED_PATH
	set(value):
		_set_branch_slot(0, value)

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
## Whether the open draft is the milestone offer of unowned Adaptation lines, so
## the panel can name what it is rather than looking like an ordinary level-up.
var _pending_upgrade_is_branch_choice := false
var _pending_relic_options := PackedInt32Array()
var _upgrade_slot_order := PackedInt32Array()
var _upgrade_offer_cursor := 0
## Adaptations already announced as mastered, so the flourish plays once.
var _mastered_adaptations := {}
## Upgrade screens since each ordinary line was last offered, so a line the pool
## keeps passing over is eventually forced onto the table.
var _screens_since_offered := {}
## The previous screen's options, which a redraw weights against repeating.
var _previous_offer := PackedInt32Array()
var _garden_complete_announced := false
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
	assert(evolutions != null, "Progression requires Evolutions")
	# Relayed rather than re-owned: the run listens to Progression for the shape of
	# its own progress, and the Evolutions node is where the change actually happens.
	evolutions.evolution_changed.connect(evolution_changed.emit)
	reset_progression()

func reset_progression() -> void:
	_casino_paths.clear()
	core_adaptations.clear()
	branch_adaptations.clear()
	unlocked_branch_slots = 0
	_mastered_adaptations.clear()
	_screens_since_offered.clear()
	_previous_offer = PackedInt32Array()
	_garden_complete_announced = false
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
	_pending_upgrade_is_branch_choice = false
	_pending_relic_options.clear()
	_upgrade_slot_order.clear()
	_upgrade_levels.resize(UpgradeId.size())
	_upgrade_levels.fill(0)
	_owned_relics.resize(RelicCatalog.get_count())
	_owned_relics.fill(0)
	_emit_all_state()

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

func has_primary_path() -> bool:
	return core_adaptations.size() > 0

func has_secondary_path() -> bool:
	return core_adaptations.size() > 1

func has_tertiary_path() -> bool:
	return branch_adaptations.size() > 0

func has_path(path_id: int) -> bool:
	return owns_adaptation(path_id)

func owns_adaptation(path_id: int) -> bool:
	## Permanent ownership, and the only question any combat, relic or draft system
	## should ask. A Clover jackpot lends an Adaptation's behaviour, an Evolution can
	## generate its events and a relic can borrow its numbers; none of those is
	## ownership, and none of them opens a relic pool or an upgrade line.
	return (
		core_adaptations.has(path_id)
		or branch_adaptations.has(path_id)
	)

func is_core_adaptation(path_id: int) -> bool:
	return core_adaptations.has(path_id)

func is_branch_adaptation(path_id: int) -> bool:
	return branch_adaptations.has(path_id)

func get_owned_adaptations() -> PackedInt32Array:
	var owned := PackedInt32Array()
	for path_id in core_adaptations:
		owned.append(path_id)
	for path_id in branch_adaptations:
		owned.append(path_id)
	return owned

func get_owned_adaptation_count() -> int:
	return core_adaptations.size() + branch_adaptations.size()

func has_core_slot_open() -> bool:
	return core_adaptations.size() < MAXIMUM_CORE_ADAPTATIONS

func has_branch_slot_open() -> bool:
	## A Branch slot exists only once the milestone that earns it has been beaten.
	## Breadth is the Elite's and the Boss's reward, so before those fights the run
	## simply has nowhere to put a third or fourth Adaptation and its drafts stay
	## narrowed to what it already owns.
	return branch_adaptations.size() < unlocked_branch_slots

func unlock_branch_slot() -> bool:
	## Opens one Branch position. The Adaptation that fills it is still drafted, not
	## handed over: the milestone earns the room, the player chooses what goes in it.
	if unlocked_branch_slots >= MAXIMUM_BRANCH_ADAPTATIONS:
		return false
	unlocked_branch_slots += 1
	branch_slot_unlocked.emit(unlocked_branch_slots)
	upgrades_changed.emit()
	return true

func get_next_slot_kind() -> int:
	## Cores fill first and Branches after, because the pairing has to be locked
	## early enough for the run to be built toward its Evolution.
	return SlotKind.CORE if has_core_slot_open() else SlotKind.BRANCH

func get_acquirable_adaptations() -> PackedInt32Array:
	## Every Adaptation the run could still enter. Read by the development switches
	## and by tests; a run enters one by drafting a line, so nothing offers this list
	## as a choice in itself.
	var available := PackedInt32Array()
	for path_id in range(PathId.size()):
		if owns_adaptation(path_id) or not is_path_offered(path_id):
			continue
		available.append(path_id)
	return available

func acquire_adaptation(path_id: int) -> bool:
	## Take an Adaptation permanently. Its base mechanic starts immediately, all four
	## of its ordinary lines become draftable at rank 0, and its relic pool opens the
	## same moment.
	##
	## Normally reached through choose_upgrade: a run enters an Adaptation by taking
	## one of its lines, so the rank that comes with it is the one the player just
	## chose rather than a free one this hands out.
	if path_id < 0 or path_id >= PathId.size() or owns_adaptation(path_id):
		return false
	if not (has_core_slot_open() or has_branch_slot_open()):
		return false
	var slot_kind := get_next_slot_kind()
	var slot_index := 0
	if slot_kind == SlotKind.CORE:
		slot_index = core_adaptations.size()
		core_adaptations.append(path_id)
	else:
		if not has_branch_slot_open():
			return false
		slot_index = branch_adaptations.size()
		branch_adaptations.append(path_id)
	adaptation_acquired.emit(path_id, slot_kind, slot_index)
	if slot_kind == SlotKind.CORE and core_adaptations.size() == MAXIMUM_CORE_ADAPTATIONS:
		# The pairing is frozen the instant the second Core lands. Nothing later --
		# no Branch, no relic, no Evolution event -- may reroll which Evolution the
		# run is playing toward.
		core_pair_locked.emit(
			core_adaptations[0],
			core_adaptations[1],
			get_pair_evolution_id()
		)
	paths_changed.emit()
	relic_pools_changed.emit(get_eligible_relic_pool_ids())
	_update_evolution_readiness()
	upgrades_changed.emit()
	return true

func request_branch_upgrade_choice() -> bool:
	## The milestone reward: a draft of real upgrade lines drawn only from
	## Adaptations the run has not entered.
	##
	## A Branch is entered exactly the way a Core was -- by taking one of its lines
	## -- so the reward for beating the Elite is an upgrade offer, never a screen of
	## bare Adaptations to pick between. What the milestone changed is that there is
	## now somewhere for a new Adaptation to go.
	if not has_branch_slot_open() or _has_any_pending_choice():
		return false
	var candidates: Array[int] = []
	for upgrade_id in range(UpgradeId.size()):
		if evolutions.get_upgrade_evolution(upgrade_id) != EvolutionId.NONE:
			continue
		var path_id := _get_upgrade_path(upgrade_id)
		if path_id == UNSELECTED_PATH or owns_adaptation(path_id):
			continue
		if not is_path_offered(path_id):
			continue
		candidates.append(upgrade_id)
	if candidates.is_empty():
		return false
	var offer := PackedInt32Array()
	while offer.size() < 3 and not candidates.is_empty():
		var taken := _weighted_take(candidates, offer)
		offer.append(candidates[taken])
		candidates.remove_at(taken)
	_pending_upgrade_options = offer
	_pending_upgrade_is_branch_choice = true
	_record_offer(offer)
	upgrade_choice_requested.emit(_pending_upgrade_options.duplicate())
	return true

func is_pending_branch_upgrade_choice() -> bool:
	return _pending_upgrade_is_branch_choice and not _pending_upgrade_options.is_empty()

func is_line_mastered(upgrade_id: int) -> bool:
	return (
		get_owned_upgrade_level(upgrade_id)
		>= get_upgrade_maximum_level(upgrade_id)
	)

func get_mastered_line_count(path_id: int) -> int:
	var mastered := 0
	for upgrade_id in get_adaptation_line_ids(path_id):
		if is_line_mastered(upgrade_id):
			mastered += 1
	return mastered

func is_adaptation_mastered(path_id: int) -> bool:
	## Every one of its four ordinary lines at rank 3. Presentation and completion
	## state only: mastery grants no hidden multiplier, so a build cannot be forced
	## through it by anything except wanting the ranks themselves.
	return (
		owns_adaptation(path_id)
		and get_mastered_line_count(path_id) >= LINES_PER_ADAPTATION
	)

func get_adaptation_line_ids(path_id: int) -> PackedInt32Array:
	var lines := PackedInt32Array()
	if path_id == UNSELECTED_PATH:
		return lines
	for upgrade_id in range(UpgradeId.size()):
		if _get_upgrade_path(upgrade_id) == path_id:
			lines.append(upgrade_id)
	return lines

func _set_core_slot(slot_index: int, path_id: int) -> void:
	# Only the compatibility aliases and debug helpers write a slot directly. Real
	# acquisition goes through acquire_adaptation, which also opens the relic pool
	# and locks the pairing.
	_set_slot(core_adaptations, slot_index, path_id)

func _set_branch_slot(slot_index: int, path_id: int) -> void:
	_set_slot(branch_adaptations, slot_index, path_id)

func _set_slot(slots: Array[int], slot_index: int, path_id: int) -> void:
	if path_id == UNSELECTED_PATH:
		if slot_index < slots.size():
			slots.remove_at(slot_index)
		return
	while slots.size() <= slot_index:
		slots.append(path_id)
	slots[slot_index] = path_id

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
		possible += get_upgrade_maximum_level(upgrade_id)
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
	# Only the Core pair makes the pairing. A Branch never joins it, so no second
	# Evolution and no three-way pairing can ever form no matter how deeply the
	# Branch is developed.
	return is_core_adaptation(path_id)

func debug_select_tertiary_path(path_id: int) -> bool:
	## Debug shorthand for filling the next Branch slot.
	if path_id < 0 or path_id >= PathId.size() or owns_adaptation(path_id):
		return false
	if not has_branch_slot_open():
		branch_adaptations.remove_at(branch_adaptations.size() - 1)
	branch_adaptations.append(path_id)
	paths_changed.emit()
	relic_pools_changed.emit(get_eligible_relic_pool_ids())
	return true

func debug_select_branch_paths(first_branch: int, second_branch: int) -> bool:
	branch_adaptations.clear()
	var accepted := debug_select_tertiary_path(first_branch)
	accepted = debug_select_tertiary_path(second_branch) or accepted
	return accepted

func debug_select_paths(first_path: int, second_path: int) -> bool:
	## Debug shorthand for the Core pair. Branches are cleared with it, because a
	## roster whose Cores changed is a different run.
	if (
		first_path < 0
		or first_path >= PathId.size()
		or second_path < 0
		or second_path >= PathId.size()
		or first_path == second_path
	):
		return false
	core_adaptations.clear()
	branch_adaptations.clear()
	core_adaptations.append(first_path)
	core_adaptations.append(second_path)
	if evolutions != null:
		evolutions.reset_evolutions()
	paths_changed.emit()
	relic_pools_changed.emit(get_eligible_relic_pool_ids())
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
	# Taking a line of an Adaptation the run has not entered is how it enters:
	# the Adaptation is the mechanic, and committing to it is choosing to develop
	# one of its lines. A slot has to be open for that -- both Cores at the start,
	# a Branch once its milestone has been beaten -- and if none is, only lines of
	# owned Adaptations were ever on the table.
	var committed_path := get_upgrade_committed_path(upgrade_id)
	if committed_path != UNSELECTED_PATH:
		acquire_adaptation(committed_path)
	_upgrade_levels[upgrade_id] += 1
	_pending_upgrade_options.clear()
	_pending_upgrade_is_branch_choice = false
	_announce_mastery(_get_upgrade_path(upgrade_id))
	_update_evolution_readiness()
	upgrades_changed.emit()
	_try_request_level_up()
	xp_changed.emit(current_level, current_xp, get_required_xp())
	return true

func get_upgrade_committed_path(upgrade_id: int) -> int:
	## The Adaptation this upgrade would bring into the run if it were taken now, or
	## UNSELECTED_PATH when it belongs to one the run already holds.
	var upgrade_path := _get_upgrade_path(upgrade_id)
	if upgrade_path == UNSELECTED_PATH or owns_adaptation(upgrade_path):
		return UNSELECTED_PATH
	if not is_path_offered(upgrade_path):
		return UNSELECTED_PATH
	if has_core_slot_open() or has_branch_slot_open():
		return upgrade_path
	return UNSELECTED_PATH

func _announce_mastery(path_id: int) -> void:
	if path_id == UNSELECTED_PATH or _mastered_adaptations.has(path_id):
		return
	if not is_adaptation_mastered(path_id):
		return
	_mastered_adaptations[path_id] = true
	adaptation_mastered.emit(path_id)

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


func get_upgrade_maximum_level(upgrade_id: int) -> int:
	## Ordinary lines stop at three; the Evolution line keeps its authored five.
	## Two different ceilings because they are two different kinds of thing: an
	## ordinary rank is one more of the same increment, and an Evolution rank is a
	## mechanic that did not exist before it.
	if (
		evolutions != null
		and evolutions.get_upgrade_evolution(upgrade_id) != EvolutionId.NONE
	):
		return evolution_maximum_upgrade_level
	return maximum_upgrade_level

func is_evolution_upgrade(upgrade_id: int) -> bool:
	return (
		evolutions != null
		and evolutions.get_upgrade_evolution(upgrade_id) != EvolutionId.NONE
	)


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
	green_percent_of_arena: float,
	mature_percent_of_arena: float,
	root_yield_multiplier: float = 1.0
) -> void:
	# Both arguments are shares of the whole arena. The names say so because they used
	# not to be: this took "what share of my Green is Mature" and multiplied it by a
	# per-arena-percentage coefficient, so a small fully established foothold paid as
	# though it had established most of the board.
	#
	# Root's yield arrives as an argument: the economy is progression's, but what
	# Mature Green is worth belongs to the Root path.
	biomass_per_second = (
		green_percent_of_arena * biomass_per_green_percent
		+ mature_percent_of_arena
		* biomass_per_mature_percent
		* maxf(0.0, root_yield_multiplier)
	) * get_biomass_production_multiplier()
	var earned := biomass_per_second * delta
	biomass += earned
	biomass_earned_total += earned
	biomass_changed.emit(biomass, biomass_per_second)

func get_selected_paths() -> PackedInt32Array:
	# The Core pair, in one place, so anything that leans on the run's build
	# identity does not have to know how the slots are stored. Branches are
	# deliberately absent: this answers "what is this run", not "what does it own".
	var selected := PackedInt32Array()
	for path_id in core_adaptations:
		selected.append(path_id)
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
	if RelicCatalog.get_pool(relic_id) == RelicCatalog.Pool.PLANT:
		return true
	return has_path(RelicCatalog.get_owning_path(relic_id))

func get_eligible_relics() -> PackedInt32Array:
	var eligible := PackedInt32Array()
	for relic_id in range(RelicCatalog.get_count()):
		if is_relic_eligible(relic_id):
			eligible.append(relic_id)
	return eligible

func get_eligible_relic_pool_ids() -> PackedInt32Array:
	## Plant, plus one pool per permanently owned Adaptation. Five pools of eight is
	## a forty-relic catalogue at a full roster, which is already a large enough
	## interaction surface without opening the whole seventy-two.
	var pool_ids := PackedInt32Array([RelicCatalog.Pool.PLANT])
	for path_id in get_owned_adaptations():
		pool_ids.append(RelicCatalog.get_pool_for_path(path_id))
	return pool_ids

func get_relic_run_state() -> int:
	## Which rarity table this run rolls against. Deliberately reads the shape of
	## the build rather than elapsed time, so a roster that filled early gets the
	## deeper table early. Where several rows apply, the furthest one wins.
	var owned := get_owned_adaptation_count()
	if owned >= MAXIMUM_OWNED_ADAPTATIONS:
		return RelicCatalog.RunState.FULL_ROSTER
	if owned >= 3 or evolution_status == EvolutionStatus.EVOLVED:
		return RelicCatalog.RunState.POST_EVOLUTION
	if owned >= 2:
		return RelicCatalog.RunState.TWO_PRE_EVOLUTION
	return RelicCatalog.RunState.SINGLE_ADAPTATION

func get_relic_rarity_odds() -> PackedFloat32Array:
	return RelicCatalog.get_rarity_odds(get_relic_run_state())

func _roll_relic_rarity(odds: PackedFloat32Array) -> int:
	var roll := _relic_random.randf()
	for rarity in range(odds.size()):
		roll -= odds[rarity]
		if roll <= 0.0:
			return rarity
	return RelicCatalog.Rarity.COMMON

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
	while wanted >= RelicCatalog.Rarity.COMMON:
		var matching := PackedInt32Array()
		for relic_id in candidates:
			if RelicCatalog.get_rarity(relic_id) == wanted:
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
		# Nothing left the run can hold. The reward pays out as a Compost Cache --
		# health and a patch of Fresh Green -- rather than as a currency the player
		# has no remaining use for.
		compost_cache_granted.emit()
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
	var replaced_rarity := RelicCatalog.Rarity.COMMON
	for relic_id in _pending_relic_options:
		replaced_rarity = maxi(
			replaced_rarity,
			RelicCatalog.get_rarity(relic_id)
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
	# Two mastered lines in each Core, which is what the gate actually asks for.
	for core_id in core_adaptations:
		var lines := get_adaptation_line_ids(core_id)
		for index in range(mini(MASTERED_LINES_FOR_EVOLUTION, lines.size())):
			_upgrade_levels[lines[index]] = get_upgrade_maximum_level(lines[index])
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
		UpgradeId.BRAMBLE_ENTANGLEMENT_RATE:
			return "Entanglement Rate"
		UpgradeId.BRAMBLE_GRASPING_THORNS:
			return "Grasping Thorns"
		UpgradeId.BRAMBLE_REPULSION:
			return "Repulsion"
		UpgradeId.ROOT_MATURATION:
			return "Maturation Speed"
		UpgradeId.ROOT_LATERAL_ROOTS:
			return "Lateral Roots"
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
		UpgradeId.BRAMBLE_ENTANGLEMENT_RATE:
			return "+%d%% faster Entanglement build-up on your Green" % roundi(
				bramble_director.entanglement_rate_per_level * 100.0 if bramble_director != null else 0.0
			)
		UpgradeId.BRAMBLE_GRASPING_THORNS:
			return "+%.2fs Ensnare on enemies that reach full Entanglement" % (
				bramble_director.ensnare_seconds_per_level if bramble_director != null else 0.0
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
			return "+1x Thistle critical damage (10% critical chance)"
		UpgradeId.VINE_ELONGATION:
			return "+20% Vine sweep reach"
		UpgradeId.VINE_LIGNIFICATION:
			return "+25% Vine sweep damage"
		UpgradeId.VINE_TURGOR:
			return "+15% Vine attack speed"
		UpgradeId.VINE_APICAL_DOMINANCE:
			return "+25% damage in the outermost 25% of the Vine sweep"
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

static func get_relic_name(relic_id: int) -> String:
	return RelicCatalog.get_relic_name(relic_id)

static func get_relic_rarity(relic_id: int) -> int:
	return RelicCatalog.get_rarity(relic_id)

func get_relic_description(relic_id: int) -> String:
	return RelicCatalog.get_relic_description(relic_id)

func get_relic_requirement_text(relic_id: int) -> String:
	# What a relic needs before it can be offered, so a locked entry in the
	# collection row explains itself rather than only being empty. Plant is always
	# available; every other pool names the Adaptation that unlocks it.
	return RelicCatalog.get_pool_name(RelicCatalog.get_pool(relic_id))

func _try_request_level_up() -> void:
	if not _pending_upgrade_options.is_empty():
		return
	var required := get_required_xp()
	if current_xp < required:
		return
	current_xp -= required
	current_level += 1
	if not _roll_upgrade_options():
		# Nothing left to buy. The run keeps levelling for telemetry, but it does
		# not open a panel it cannot fill and it does not fall back to an endless
		# generic stat purchase, which would undo the point of a finite build.
		if not _garden_complete_announced:
			_garden_complete_announced = true
			garden_completed.emit()
		return
	upgrade_choice_requested.emit(_pending_upgrade_options.duplicate())

func reroll_upgrade_choice() -> bool:
	if _pending_upgrade_options.is_empty() or rerolls_remaining <= 0:
		return false
	var previous_offer := _pending_upgrade_options.duplicate()
	# A redraw can legitimately come back with the same three lines, and a reroll that
	# appears to do nothing is a reroll the player believes is broken. Keep drawing -
	# from a new cursor each time, so even a pool too small to shuffle eventually
	# moves - and give up rather than spending a reroll on a pool that cannot produce
	# a different offer at all.
	#
	# The rebuild reads the same ranks: a reroll changes what is offered, never what
	# the run is able to invest in.
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
	_pending_upgrade_is_branch_choice = false
	relic_pools_changed.emit(get_eligible_relic_pool_ids())
	_try_request_level_up()
	xp_changed.emit(current_level, current_xp, get_required_xp())
	return true

func _is_upgrade_draftable(upgrade_id: int) -> bool:
	## Whether this line may appear in an offer at all, ignoring its current rank.
	##
	## An Evolution line belongs to the run that claimed that Evolution. An ordinary
	## line belongs to an Adaptation the run owns -- or to one it could still enter,
	## because entering an Adaptation is drafting one of its lines. Drafts narrow to
	## what the run holds whenever no slot is open: after the Core pair is committed,
	## and again after each Branch the milestones opened is filled.
	var upgrade_evolution: int = evolutions.get_upgrade_evolution(upgrade_id)
	if upgrade_evolution != EvolutionId.NONE:
		return has_active_evolution(upgrade_evolution)
	var upgrade_path := _get_upgrade_path(upgrade_id)
	if upgrade_path == UNSELECTED_PATH:
		return false
	if owns_adaptation(upgrade_path):
		return true
	if not is_path_offered(upgrade_path):
		return false
	return has_core_slot_open() or has_branch_slot_open()

func get_ordinary_candidate_lines() -> PackedInt32Array:
	## Every ordinary line the run could still buy. Maxed lines are excluded, and so
	## is Clover's temporary overlay: a jackpot is not a purchase, and its expiry
	## must not un-max anything.
	var candidates := PackedInt32Array()
	for upgrade_id in range(UpgradeId.size()):
		if evolutions.get_upgrade_evolution(upgrade_id) != EvolutionId.NONE:
			continue
		if not _is_upgrade_draftable(upgrade_id):
			continue
		if get_owned_upgrade_level(upgrade_id) < get_upgrade_maximum_level(upgrade_id):
			candidates.append(upgrade_id)
	return candidates

func _get_evolution_rank_candidate() -> int:
	# The claimed Evolution's own line, offered as an ordinary unrestricted
	# candidate at exactly the next rank it can buy.
	if evolutions == null or evolution_status != EvolutionStatus.EVOLVED:
		return -1
	var upgrade_id: int = evolutions.get_evolution_upgrade_id(active_evolution)
	if upgrade_id < 0:
		return -1
	if get_owned_upgrade_level(upgrade_id) >= get_upgrade_maximum_level(upgrade_id):
		return -1
	return upgrade_id

func _roll_upgrade_options() -> bool:
	## Three cards drawn from everything the run could still buy.
	##
	## Sixteen ordinary lines plus the Evolution is a large pool, so the draw is
	## weighted rather than uniform: the drought guards below are what keep a line
	## the player wants from simply not appearing for minutes at a time.
	var candidates := get_ordinary_candidate_lines()
	var evolution_rank_candidate := _get_evolution_rank_candidate()
	if evolution_rank_candidate >= 0:
		candidates.append(evolution_rank_candidate)
	# A completed pairing holds one of the three slots until it is taken, so the
	# claim can never be missed by an unlucky draw.
	var claim_ready := is_pair_evolution_draftable()
	if candidates.is_empty() and not claim_ready:
		return false
	var offer := PackedInt32Array()
	if claim_ready:
		offer.append(EVOLUTION_DRAFT_OPTION)
	var remaining: Array[int] = []
	for upgrade_id in candidates:
		if offer.find(upgrade_id) == -1:
			remaining.append(upgrade_id)
	# The forced line first: something the pool has passed over four screens running
	# takes an unrestricted slot outright rather than waiting for the weights.
	var forced := _take_drought_forced_line(remaining)
	if forced >= 0 and offer.size() < 3:
		offer.append(forced)
	while offer.size() < 3 and not remaining.is_empty():
		var taken := _weighted_take(remaining, offer)
		offer.append(remaining[taken])
		remaining.remove_at(taken)
	_pending_upgrade_options = offer
	_pending_upgrade_is_branch_choice = false
	_record_offer(offer)
	_upgrade_offer_cursor = (_upgrade_offer_cursor + 1) % UpgradeId.size()
	return not offer.is_empty()

func _take_drought_forced_line(remaining: Array[int]) -> int:
	for index in range(remaining.size()):
		if _get_screens_since_offered(remaining[index]) >= line_drought_forced_screens:
			var upgrade_id := remaining[index]
			remaining.remove_at(index)
			return upgrade_id
	return -1

func _weighted_take(remaining: Array[int], offer: PackedInt32Array) -> int:
	## Index into remaining, drawn against the drought weights.
	##
	## Weighted rather than uniform because a uniform draw over sixteen lines lets a
	## line the player wants simply not appear for several minutes while the screen
	## keeps showing what they already declined.
	if remaining.size() <= 1:
		return 0
	var weights := PackedFloat32Array()
	var total := 0.0
	for upgrade_id in remaining:
		var weight := 1.0
		var waited := _get_screens_since_offered(upgrade_id)
		if waited >= line_drought_boost_screens:
			weight *= line_drought_boost_weight
		if _previous_offer.has(upgrade_id):
			weight *= line_repeat_weight
		# Two Adaptations on a screen where possible: three lines of one Adaptation
		# is a screen that only decides how fast, never what.
		if _offer_carries_path(offer, _get_upgrade_path(upgrade_id)):
			weight *= 0.5
		weights.append(weight)
		total += weight
	var roll := _draft_random.randf() * total
	for index in range(weights.size()):
		roll -= weights[index]
		if roll <= 0.0:
			return index
	return weights.size() - 1

func _get_screens_since_offered(upgrade_id: int) -> int:
	return _screens_since_offered.get(upgrade_id, 0)

func _record_offer(offer: PackedInt32Array) -> void:
	# Every eligible line ages by one screen; the ones actually shown reset.
	for upgrade_id in get_ordinary_candidate_lines():
		_screens_since_offered[upgrade_id] = _get_screens_since_offered(upgrade_id) + 1
	for upgrade_id in offer:
		if upgrade_id >= 0:
			_screens_since_offered[upgrade_id] = 0
	_previous_offer = offer.duplicate()

func _offer_carries_path(offer: PackedInt32Array, path_id: int) -> bool:
	for upgrade_id in offer:
		if _get_upgrade_path(upgrade_id) == path_id:
			return true
	return false


func _update_evolution_readiness() -> void:
	## Two mastered lines in each Core, and nothing else counts.
	##
	## Not one line each, and not any two mastered lines: twelve deliberate ordinary
	## purchases split across both Cores is what the Evolution is the reward for.
	## Branch lines, Clover's temporary ranks, relic bonuses and Evolution-generated
	## events carrying a Core's tag are all excluded by construction here, because
	## this reads owned ordinary ranks of the two Core Adaptations and nothing else.
	if evolutions == null:
		return
	evolutions.update_readiness(
		has_primary_path()
		and has_secondary_path()
		and get_mastered_line_count(core_adaptations[0]) >= MASTERED_LINES_FOR_EVOLUTION
		and get_mastered_line_count(core_adaptations[1]) >= MASTERED_LINES_FOR_EVOLUTION
	)

func _has_any_pending_choice() -> bool:
	return (
		not _pending_upgrade_options.is_empty()
		or not _pending_relic_options.is_empty()
	)

func _get_upgrade_path(upgrade_id: int) -> int:
	match upgrade_id:
		UpgradeId.SEED_PRODUCTION, UpgradeId.GROWTH_MASS, \
		UpgradeId.SPORULATION, UpgradeId.FRUITING_BODIES:
			return PathId.SPORE
		UpgradeId.BLOOM_FORCE, UpgradeId.BLOOM_FREQUENCY, \
		UpgradeId.AFTERGROWTH, UpgradeId.SUPPRESSION:
			return PathId.BLOOM
		UpgradeId.BRAMBLE_ENTANGLEMENT, UpgradeId.BRAMBLE_ENTANGLEMENT_RATE, \
		UpgradeId.BRAMBLE_GRASPING_THORNS, UpgradeId.BRAMBLE_REPULSION:
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

func _emit_all_state() -> void:
	paths_changed.emit()
	relic_pools_changed.emit(get_eligible_relic_pool_ids())
	xp_changed.emit(current_level, current_xp, get_required_xp())
	upgrades_changed.emit()
	biomass_changed.emit(biomass, biomass_per_second)
	metabolism_changed.emit()
	relics_changed.emit()
	evolution_changed.emit(evolution_status)
	rerolls_changed.emit(rerolls_remaining)
