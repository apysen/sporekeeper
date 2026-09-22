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
## An Evolution reward is open, carrying the eligible Evolutions it is offering.
signal evolution_choice_requested(options: PackedInt32Array)
## A Growth reward is open, carrying the universal stats it is offering.
signal growth_choice_requested(options: PackedInt32Array)
## A Growth rank was taken, so everything reading the universal stats must refresh.
signal growth_changed

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
## Adaptations a Campaign run may own. Three, not four.
##
## Three Adaptations is three pair relationships rather than six, which is enough
## Evolution variety for a twenty-minute run without diluting four Paths' worth of
## upgrade lines across it -- and it leaves each Path a larger share of the run's
## identity. Quick keeps four; a fourth Path in Campaign is reserved for whatever
## eventually breaks the rules on purpose.
const CAMPAIGN_OWNED_ADAPTATIONS := 3

## Ordinary lines every owned Adaptation exposes, all of them from the moment it is
## acquired. Nothing is ever permanently rejected: a lower-priority utility line is
## delayed by choice rather than locked out of the run.
const LINES_PER_ADAPTATION := 4

## Owned ordinary ranks each half of a pair needs before their Evolution becomes
## eligible.
##
## Five of a possible twelve, in each of the two Adaptations: ten deliberate
## purchases for a relationship, which is meaningful investment without being
## mastery. Requiring both Paths maxed was the old rule and it cannot survive a
## twenty-minute run with a two-Evolution target -- there is not time to max four
## lines twice, twice. No Branch distinction, no temporary Clover rank and no relic
## bonus counts: this reads owned ordinary ranks and nothing else.
const EVOLUTION_RANKS_PER_PATH := 5

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
##
## Raised from 7. The Campaign rework rebuilt a wave into a threat budget and never
## revisited this curve, so it was being fed by a spawn supply it was not calibrated
## against. Measured end to end by `tools/pacing_probe.gd`: level 9 and eight upgrade
## picks inside the first minute, level 12 by wave 3, and twenty of a roster's
## thirty-six ranks bought by minute five of twenty -- half the picks in a run landing
## in its first quarter. The probe's own note names that as the failure it exists to
## catch: a build that is merely good is a problem if it is complete by minute four.
##
## This rather than `xp_requirement_growth`, because the shape is wrong only at the
## start: after minute six the run already settles to about one pick a minute, which is
## fine, and steepening the exponent would punish the part that works. Scaling this
## multiplies every threshold equally, and since early income is small while late income
## is enormous, the same factor costs minutes early and seconds late -- the asymmetry the
## problem actually has.
@export_range(1, 200, 1) var first_level_xp := 34
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

@export_group("Reward Offers")
## Evolutions shown at an Evolution reward, sampled from everything eligible.
##
## Three of however many relationships qualify, so a run with all three pairs
## developed still has to choose rather than being handed the whole set, and a run
## with one qualifying pair simply sees that one.
@export_range(1, 4, 1) var evolution_offer_count := 3
## Universal stats shown at a Growth reward.
@export_range(1, 4, 1) var growth_offer_count := 3

@export_group("Adaptation Slots")
## Branch positions this run may ever open. Two in Quick, one in Campaign, which is
## what makes the Campaign roster three Adaptations rather than four.
@export_range(0, 2, 1) var branch_slot_limit := MAXIMUM_BRANCH_ADAPTATIONS
## Whether new Adaptations may only be entered through an authored Adaptation draft.
##
## Campaign turns this on. The measured pacing showed early upgrade ordering deciding
## whether a build functioned at all -- a run whose first three screens happened to
## offer three lines of one Path had no build, through no decision anybody made.
## Randomness is supposed to shape how a build develops, not whether the player is
## allowed to have one, so Campaign hands out its three Adaptation choices on the
## wave table and keeps ordinary level-ups to the lines of Paths already owned.
@export var authored_path_drafts := false

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
## The Evolution reward currently on the table, and the Growth reward behind it.
## Kept apart from the upgrade draft because they are different rewards arriving
## from different places: an Evolution comes from a Campaign milestone or a boss, a
## Growth from having survived a wave the player called in early, and neither is
## something an ordinary level-up may roll.
var _pending_evolution_options := PackedInt32Array()
var _pending_growth_options := PackedInt32Array()
## Ranks bought in each universal Growth stat, indexed by GrowthCatalog.StatId.
var _growth_ranks := PackedInt32Array()
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
	_pending_evolution_options.clear()
	_pending_growth_options.clear()
	_growth_ranks.resize(GrowthCatalog.get_count())
	_growth_ranks.fill(0)
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

func get_branch_slot_limit() -> int:
	return clampi(branch_slot_limit, 0, MAXIMUM_BRANCH_ADAPTATIONS)


func get_maximum_owned_adaptations() -> int:
	return MAXIMUM_CORE_ADAPTATIONS + get_branch_slot_limit()


func has_branch_slot_open() -> bool:
	## A Branch slot exists only once the milestone that earns it has been beaten.
	## Breadth is the Elite's and the Boss's reward, so before those fights the run
	## simply has nowhere to put a third or fourth Adaptation and its drafts stay
	## narrowed to what it already owns.
	return branch_adaptations.size() < unlocked_branch_slots

func unlock_branch_slot() -> bool:
	## Opens one Branch position. The Adaptation that fills it is still drafted, not
	## handed over: the milestone earns the room, the player chooses what goes in it.
	if unlocked_branch_slots >= get_branch_slot_limit():
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

func request_adaptation_draft() -> bool:
	## A draft of real upgrade lines drawn only from Adaptations the run has not
	## entered.
	##
	## An Adaptation is entered exactly the way it always was -- by taking one of its
	## lines -- so this is an upgrade offer, never a screen of bare Adaptations to
	## pick between. What changed is who opens it: in Quick it is the milestone that
	## earned the room for a Branch, and in Campaign it is the wave table, which hands
	## out all three of the run's Adaptation choices at authored moments rather than
	## leaving them to whatever the level-up pool happened to roll.
	if not (has_core_slot_open() or has_branch_slot_open()):
		return false
	if _has_any_pending_choice():
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

func is_pending_adaptation_draft() -> bool:
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


func get_invested_rank_count(path_id: int) -> int:
	## Owned ordinary ranks in one Adaptation. The currency the Evolution gate is
	## priced in: not lines mastered, because three ranks of one line and one rank of
	## three are the same amount of commitment and only one of them used to count.
	if not owns_adaptation(path_id):
		return 0
	var invested := 0
	for upgrade_id in get_adaptation_line_ids(path_id):
		invested += get_owned_upgrade_level(upgrade_id)
	return invested


func is_pair_invested(first_path: int, second_path: int) -> bool:
	## Whether both halves of a relationship are developed enough to evolve.
	return (
		first_path != second_path
		and get_invested_rank_count(first_path) >= EVOLUTION_RANKS_PER_PATH
		and get_invested_rank_count(second_path) >= EVOLUTION_RANKS_PER_PATH
	)


func get_eligible_evolutions() -> PackedInt32Array:
	return (
		evolutions.get_eligible_evolutions()
		if evolutions != null
		else PackedInt32Array()
	)


func get_evolution_rank(evolution_id: int) -> int:
	## The rank of one named Evolution, or zero when the run does not hold it. Every
	## director asks this rather than "the Evolution rank": a run can hold two.
	return evolutions.get_evolution_rank(evolution_id) if evolutions != null else 0


func get_active_evolutions() -> PackedInt32Array:
	var active := PackedInt32Array()
	if evolutions == null:
		return active
	for evolution_id in evolutions.active_evolutions:
		active.append(int(evolution_id))
	return active

func get_pair_evolution_id() -> int:
	return evolutions.get_pair_evolution_id() if evolutions != null else EvolutionId.NONE

func get_evolution_upgrade_level() -> int:
	return evolutions.get_evolution_upgrade_level() if evolutions != null else 0

func is_pair_evolution_draftable() -> bool:
	return evolutions != null and evolutions.is_pair_evolution_draftable()

func grant_evolution_if_ready() -> bool:
	if evolutions == null:
		return false
	var before := get_active_evolutions().size()
	if not evolutions.grant_evolution_if_ready():
		return false
	_open_granted_evolution_lines()
	return get_active_evolutions().size() > before


func grant_evolution(evolution_id: int) -> bool:
	## Claims one named Evolution and opens its five-rank line at rank 1.
	if evolutions == null or not evolutions.grant_evolution(evolution_id):
		return false
	_open_granted_evolution_lines()
	return true


func _open_granted_evolution_lines() -> void:
	# Every claimed Evolution owns a line, and claiming it is what buys that line's
	# first rank. Walked over the whole set rather than over the one just added, so a
	# state restored out of a save opens the lines it was already holding.
	for evolution_id in get_active_evolutions():
		var upgrade_id: int = evolutions.get_evolution_upgrade_id(evolution_id)
		if upgrade_id >= 0 and get_owned_upgrade_level(upgrade_id) == 0:
			_upgrade_levels[upgrade_id] = 1
	_update_evolution_readiness()
	upgrades_changed.emit()


## An Evolution reward: every relationship the run currently qualifies for, sampled
## down to a few and put on the table.
##
## The whole point of the rework is here. An Evolution used to be decided by which
## two Adaptations the run happened to take first, minutes before the player knew
## what the run was going to be; now any owned pair that has been developed is a
## candidate, a Path may take part in more than one, and the reward is a choice
## between the relationships the build has actually earned.
func request_evolution_choice() -> bool:
	if _has_any_pending_choice():
		return false
	var eligible := get_eligible_evolutions()
	if eligible.is_empty():
		return false
	var offered := PackedInt32Array()
	var remaining: Array[int] = []
	for evolution_id in eligible:
		remaining.append(evolution_id)
	while offered.size() < evolution_offer_count and not remaining.is_empty():
		var index := _draft_random.randi_range(0, remaining.size() - 1)
		offered.append(remaining[index])
		remaining.remove_at(index)
	_pending_evolution_options = offered
	evolution_choice_requested.emit(_pending_evolution_options.duplicate())
	return true


func choose_evolution(evolution_id: int) -> bool:
	if _pending_evolution_options.find(evolution_id) == -1:
		return false
	if not grant_evolution(evolution_id):
		return false
	_pending_evolution_options.clear()
	relic_pools_changed.emit(get_eligible_relic_pool_ids())
	return true


func get_pending_evolution_options() -> PackedInt32Array:
	return _pending_evolution_options.duplicate()


func has_pending_evolution_choice() -> bool:
	return not _pending_evolution_options.is_empty()


## A Growth reward: three of the universal stats that still have a rank left.
##
## Offered rather than granted, and capped per stat, so the set a run collects is a
## small spread rather than four ranks of whichever one is best. Returns false when
## every stat is full, which is the run having collected all the Growth there is.
func request_growth_choice() -> bool:
	if _has_any_pending_choice():
		return false
	var remaining: Array[int] = []
	for stat_id in range(GrowthCatalog.get_count()):
		if get_growth_rank(stat_id) < GrowthCatalog.get_rank_cap(stat_id):
			remaining.append(stat_id)
	if remaining.is_empty():
		return false
	var offered := PackedInt32Array()
	while offered.size() < growth_offer_count and not remaining.is_empty():
		var index := _draft_random.randi_range(0, remaining.size() - 1)
		offered.append(remaining[index])
		remaining.remove_at(index)
	_pending_growth_options = offered
	growth_choice_requested.emit(_pending_growth_options.duplicate())
	return true


func choose_growth(stat_id: int) -> bool:
	if _pending_growth_options.find(stat_id) == -1:
		return false
	if get_growth_rank(stat_id) >= GrowthCatalog.get_rank_cap(stat_id):
		return false
	_growth_ranks[stat_id] += 1
	_pending_growth_options.clear()
	growth_changed.emit()
	upgrades_changed.emit()
	return true


func get_pending_growth_options() -> PackedInt32Array:
	return _pending_growth_options.duplicate()


func has_pending_growth_choice() -> bool:
	return not _pending_growth_options.is_empty()


func get_growth_rank(stat_id: int) -> int:
	if stat_id < 0 or stat_id >= _growth_ranks.size():
		return 0
	return _growth_ranks[stat_id]


func get_growth_total_ranks() -> int:
	var total := 0
	for rank in _growth_ranks:
		total += rank
	return total


func get_growth_bonus(stat_id: int) -> float:
	## Additive, always. Growth is the one reward in the run that must not compound
	## with itself, because it is the one the player can farm by repeatedly choosing
	## to make the Campaign harder.
	return float(get_growth_rank(stat_id)) * GrowthCatalog.get_per_rank(stat_id)


func get_growth_damage_multiplier() -> float:
	return 1.0 + get_growth_bonus(GrowthCatalog.StatId.DAMAGE)


func get_growth_attack_speed_multiplier() -> float:
	return 1.0 + get_growth_bonus(GrowthCatalog.StatId.ATTACK_SPEED)


func get_growth_movement_multiplier() -> float:
	return 1.0 + get_growth_bonus(GrowthCatalog.StatId.MOVEMENT_SPEED)


func get_growth_area_multiplier() -> float:
	return 1.0 + get_growth_bonus(GrowthCatalog.StatId.AREA)


func get_growth_bonus_health() -> float:
	return get_growth_bonus(GrowthCatalog.StatId.MAX_HEALTH)


func get_growth_damage_reduction() -> float:
	return get_growth_bonus(GrowthCatalog.StatId.ARMOR)


func get_growth_regeneration() -> float:
	return get_growth_bonus(GrowthCatalog.StatId.RECOVERY)

func is_evolution_path(path_id: int) -> bool:
	# Every owned Adaptation is half of a relationship. A Branch used to be excluded
	# by construction -- the pairing was the Core pair and nothing else -- and that
	# is the rule the Evolution rework removed: a run that took Thistle third and
	# built it is entitled to what Thistle pairs with.
	return owns_adaptation(path_id)

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
	# Campaign is three Adaptations handed out on its wave table, in twenty minutes
	# rather than twenty-five. The level curve is flatter than Quick's because the
	# build has to be *finished* by the last quarter rather than still assembling
	# through it, and flatter again than the twenty-five-minute Campaign's because
	# the Threat Director puts fewer bodies on the board to earn XP from.
	if mode == RUN_MODE.Id.CAMPAIGN:
		xp_requirement_growth = 1.18
		branch_slot_limit = CAMPAIGN_OWNED_ADAPTATIONS - MAXIMUM_CORE_ADAPTATIONS
		authored_path_drafts = true
	else:
		xp_requirement_growth = 1.34
		branch_slot_limit = MAXIMUM_BRANCH_ADAPTATIONS
		authored_path_drafts = false

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
	# With authored drafts on, the only screen that may commit a new Adaptation is
	# the Adaptation draft itself. An ordinary level-up cannot quietly decide what
	# the run is going to be.
	if authored_path_drafts and not _pending_upgrade_is_branch_choice:
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
	if owned >= get_maximum_owned_adaptations():
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
	# Enough owned ranks in each Core to clear the investment gate, bought a line at
	# a time exactly as a player would have to buy them.
	for core_id in core_adaptations:
		var invested := get_invested_rank_count(core_id)
		for upgrade_id in get_adaptation_line_ids(core_id):
			while (
				invested < EVOLUTION_RANKS_PER_PATH
				and get_owned_upgrade_level(upgrade_id) < get_upgrade_maximum_level(upgrade_id)
			):
				_upgrade_levels[upgrade_id] += 1
				invested += 1
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
	return UpgradeDescriptions.get_upgrade_name(upgrade_id)

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
			return "+%d%% harvest rate, and the ring holds that much longer unfed" % roundi(
				pruning_director.pruning_harvest_rate_per_level * 100.0 if pruning_director != null else 0.0
			)
		UpgradeId.PRUNING_CUTTING_YIELD:
			return "+%d%% Cuttings from the same harvested ground" % roundi(
				pruning_director.pruning_cutting_yield_per_level * 100.0 if pruning_director != null else 0.0
			)
		UpgradeId.PRUNING_CUTTING_DAMAGE:
			return "+%d%% launched Cutting damage" % roundi(
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
	return UpgradeDescriptions.get_path_name(path_id)

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
	if authored_path_drafts:
		# The Adaptation draft builds its own candidate list, so an unowned Path is
		# simply not in the ordinary pool at all.
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

func _get_evolution_rank_candidates() -> PackedInt32Array:
	# Every claimed Evolution's own line, offered as an ordinary unrestricted
	# candidate at exactly the next rank it can buy. Claiming an Evolution is a
	# reward of its own now; deepening one is an ordinary upgrade like any other,
	# and a run holding two has two such lines competing for the same screens.
	var candidates := PackedInt32Array()
	if evolutions == null:
		return candidates
	for evolution_id in get_active_evolutions():
		var upgrade_id: int = evolutions.get_evolution_upgrade_id(evolution_id)
		if upgrade_id < 0:
			continue
		if get_owned_upgrade_level(upgrade_id) >= get_upgrade_maximum_level(upgrade_id):
			continue
		candidates.append(upgrade_id)
	return candidates

func _roll_upgrade_options() -> bool:
	## Three cards drawn from everything the run could still buy.
	##
	## Sixteen ordinary lines plus the Evolution is a large pool, so the draw is
	## weighted rather than uniform: the drought guards below are what keep a line
	## the player wants from simply not appearing for minutes at a time.
	var candidates := get_ordinary_candidate_lines()
	for evolution_rank_candidate in _get_evolution_rank_candidates():
		candidates.append(evolution_rank_candidate)
	if candidates.is_empty():
		return false
	var offer := PackedInt32Array()
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
	## Whether any owned relationship has been developed far enough to evolve.
	##
	## Any pair, not the Core pair: a Branch is half of a relationship too, and a run
	## that took Thistle third and built it is entitled to what Thistle pairs with.
	## Clover's temporary ranks and relic bonuses are excluded by construction,
	## because the gate reads owned ordinary ranks and nothing else.
	if evolutions == null:
		return
	evolutions.update_readiness(not evolutions.get_eligible_evolutions().is_empty())

func _has_any_pending_choice() -> bool:
	return (
		not _pending_upgrade_options.is_empty()
		or not _pending_relic_options.is_empty()
		or not _pending_evolution_options.is_empty()
		or not _pending_growth_options.is_empty()
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


## Everything about the run's progress that a save has to carry.
##
## Written out field by field rather than by walking the script's properties, because
## half of what is on this node is authored tuning and scene wiring that belongs to
## the scene rather than to the run: a save that carried `offer_spore_path` or the
## exported director references would restore a run into the previous build's
## authoring. What is here is what the player did.
func capture_state() -> Dictionary:
	return {
		"run_seed": run_seed,
		"core_adaptations": PackedInt32Array(core_adaptations),
		"branch_adaptations": PackedInt32Array(branch_adaptations),
		"unlocked_branch_slots": unlocked_branch_slots,
		"current_level": current_level,
		"current_xp": current_xp,
		"rerolls_remaining": rerolls_remaining,
		"biomass": biomass,
		"biomass_per_second": biomass_per_second,
		"biomass_earned_total": biomass_earned_total,
		"upgrade_levels": _upgrade_levels,
		"owned_relics": _owned_relics,
		"casino_paths": _casino_paths.keys(),
		"mastered_adaptations": _mastered_adaptations.keys(),
		"screens_since_offered": _screens_since_offered.duplicate(),
		"previous_offer": _previous_offer,
		"pending_upgrade_options": _pending_upgrade_options,
		"pending_upgrade_is_branch_choice": _pending_upgrade_is_branch_choice,
		"pending_relic_options": _pending_relic_options,
		"pending_evolution_options": _pending_evolution_options,
		"pending_growth_options": _pending_growth_options,
		"growth_ranks": _growth_ranks,
		"upgrade_slot_order": _upgrade_slot_order,
		"upgrade_offer_cursor": _upgrade_offer_cursor,
		"garden_complete_announced": _garden_complete_announced,
		"relic_rerolls_remaining": _relic_rerolls_remaining,
		"relic_reroll_used": _relic_reroll_used,
		"last_rerolled_relic_rarity": _last_rerolled_relic_rarity,
		# The seed alone is not enough to resume drafting: it says where the run's
		# draws started, and the run is somewhere further along that stream. The
		# generator's own position is what makes the next draft the one the run was
		# going to be offered rather than the one it opened with.
		"draft_random_state": _draft_random.state,
		"relic_random_state": _relic_random.state,
	}


## Puts a captured run back.
##
## `set_run_seed` is called before the generator positions are restored and not after:
## it reseeds both streams *and* moves the offer cursor, so restoring the positions
## first would have them immediately overwritten by the opening draw.
func apply_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	set_run_seed(int(state.get("run_seed", run_seed)))
	_assign_slots(core_adaptations, state.get("core_adaptations"))
	_assign_slots(branch_adaptations, state.get("branch_adaptations"))
	unlocked_branch_slots = int(state.get("unlocked_branch_slots", 0))
	current_level = maxi(1, int(state.get("current_level", 1)))
	current_xp = int(state.get("current_xp", 0))
	rerolls_remaining = int(state.get("rerolls_remaining", rerolls_per_run))
	biomass = float(state.get("biomass", 0.0))
	biomass_per_second = float(state.get("biomass_per_second", 0.0))
	biomass_earned_total = float(state.get("biomass_earned_total", 0.0))
	# Sized here rather than trusted from the file: a build that added an Upgrade or a
	# Relic since the save was written must not end up with an array too short for the
	# ids it is about to be asked about.
	_upgrade_levels = _fit_int_array(state.get("upgrade_levels"), UpgradeId.size())
	_owned_relics = _fit_byte_array(state.get("owned_relics"), RelicCatalog.get_count())
	_casino_paths = _set_from(state.get("casino_paths"))
	_mastered_adaptations = _set_from(state.get("mastered_adaptations"))
	_screens_since_offered = _dictionary_from(state.get("screens_since_offered"))
	_previous_offer = _int_array_from(state.get("previous_offer"))
	_pending_upgrade_options = _int_array_from(state.get("pending_upgrade_options"))
	_pending_upgrade_is_branch_choice = bool(state.get("pending_upgrade_is_branch_choice", false))
	_pending_relic_options = _int_array_from(state.get("pending_relic_options"))
	_pending_evolution_options = _int_array_from(state.get("pending_evolution_options"))
	_pending_growth_options = _int_array_from(state.get("pending_growth_options"))
	_growth_ranks = _fit_int_array(state.get("growth_ranks"), GrowthCatalog.get_count())
	_upgrade_slot_order = _int_array_from(state.get("upgrade_slot_order"))
	_upgrade_offer_cursor = int(state.get("upgrade_offer_cursor", _upgrade_offer_cursor))
	_garden_complete_announced = bool(state.get("garden_complete_announced", false))
	_relic_rerolls_remaining = int(state.get("relic_rerolls_remaining", relic_rerolls_per_run))
	_relic_reroll_used = bool(state.get("relic_reroll_used", false))
	_last_rerolled_relic_rarity = int(state.get("last_rerolled_relic_rarity", -1))
	_draft_random.state = int(state.get("draft_random_state", _draft_random.state))
	_relic_random.state = int(state.get("relic_random_state", _relic_random.state))
	_emit_all_state()


## The slot arrays are `Array[int]` rather than Packed so a helper handed one edits
## the run's roster instead of a copy - which means they are filled in place here
## rather than replaced, and a Packed value out of a file cannot simply be assigned.
func _assign_slots(slots: Array[int], stored: Variant) -> void:
	slots.clear()
	if not (stored is PackedInt32Array):
		return
	for path_id in stored as PackedInt32Array:
		slots.append(int(path_id))


func _int_array_from(stored: Variant) -> PackedInt32Array:
	return stored if stored is PackedInt32Array else PackedInt32Array()


func _fit_int_array(stored: Variant, size: int) -> PackedInt32Array:
	var values := _int_array_from(stored)
	values.resize(size)
	return values


func _fit_byte_array(stored: Variant, size: int) -> PackedByteArray:
	var values: PackedByteArray = stored if stored is PackedByteArray else PackedByteArray()
	values.resize(size)
	return values


## A set stored as its keys. The three dictionaries this node keeps as sets hold no
## values worth writing, and a list survives the round trip through a file without
## depending on how a Dictionary's `true` is encoded.
func _set_from(stored: Variant) -> Dictionary:
	var set_values := {}
	if not (stored is Array):
		return set_values
	for key in stored as Array:
		set_values[int(key)] = true
	return set_values


func _dictionary_from(stored: Variant) -> Dictionary:
	return (stored as Dictionary).duplicate() if stored is Dictionary else {}
