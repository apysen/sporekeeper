class_name Evolutions
extends Node

## Every Evolution in one place: which pairing produces which Evolution, whether
## this run has earned it, the optional upgrade line it unlocks, and the tuning for
## all of them.
##
## It used to be spread across three owners. Progression held the pairing table,
## the status and sixty-odd lines of overclock tuning on top of XP, drafting,
## paths, relics and the Biomass currency; each path director carried the export
## groups for the Evolutions its path takes part in, so Super Bloom's numbers lived
## on Spore and on Bloom at once and Deadfall's sat in the middle of Pruning's own
## tuning. Reading what an Evolution actually does meant opening three Inspectors.
##
## The behaviour still belongs to the paths: Deadfall adds Cuttings inside the
## harvest because the harvest is Pruning's, and Coppice buries Seeds where the
## ring cut because the ring is Pruning's. A director asks this node whether the
## run holds an Evolution and what its numbers are, and then does its own work.
## Nothing here reaches into a director to act on its behalf.

## The text every one of these Evolutions prints. Held rather than static because
## the rank lines are written in this node's own tuning.
var _descriptions := EvolutionDescriptions.new()

signal evolution_changed(status: int)

@export_group("Collaborators")
## Progression component that owns the paths a pairing is read from and the
## upgrade levels an Evolution's optional line is counted in.
@export var progression: Progression

@export_group("Evolution Upgrades")
## Extra Bloom Force a chained Super Bloom keeps per Cascade Force rank, at levels
## one and four. Deliberately Force only: Seeds stay the best source of new Green.
@export_range(0.0, 1.0, 0.01) var floral_cascade_force_per_rank := 0.15
## Super Blooms between each Forced Germination at Floral Cascade level three.
@export_range(1, 12, 1) var floral_cascade_germination_cadence := 4
## Super Blooms between each Grand Bloom at Floral Cascade level five.
@export_range(1, 12, 1) var floral_cascade_grand_cadence := 6
## Area and pressure multiplier applied to a Grand Bloom.
@export_range(1.0, 4.0, 0.05) var floral_cascade_grand_scale := 1.80
## Entanglement a germinating Seed applies at Tangleburst level one.
@export_range(0.0, 1.0, 0.01) var tangleburst_entanglement := 0.15
## Entanglement above which germination Ensnares an enemy at Tangleburst level two.
@export_range(0.0, 1.0, 0.01) var tangleburst_ensnare_threshold := 0.70
## Ensnare duration germination applies at Tangleburst level two.
@export_range(0.0, 3.0, 0.05) var tangleburst_ensnare_hold_seconds := 0.35
## Pixels a germinating Seed pulls nearby enemies inward at Tangleburst level three.
@export_range(0.0, 200.0, 1.0) var tangleburst_pull_pixels := 26.0
## Germinating Seeds between each mass Briar pulse at Tangleburst level five.
@export_range(1, 12, 1) var tangleburst_pulse_cadence := 5
## Share of a mass Briar pulse's Entanglement applied to elites.
@export_range(0.0, 1.0, 0.01) var tangleburst_elite_share := 0.50
## Share of a mass Briar pulse's Entanglement applied to bosses.
@export_range(0.0, 1.0, 0.01) var tangleburst_boss_share := 0.20
## Spore the Mass Entanglement pulse applies to everything it pins. The pin is what
## makes the pack stand still; this is what makes standing still fatal.
@export_range(0.0, 1.0, 0.01) var tangleburst_pulse_spore := 0.35
## Extra Seed-Bank storage granted by Expanded Reserve at Seed Reserve level one.
@export_range(0.0, 2.0, 0.01) var seed_reserve_capacity_per_rank := 0.50
## Faster dormant-Seed accumulation at Seed Reserve level two.
@export_range(0.0, 2.0, 0.01) var seed_reserve_rate_bonus := 0.50
## Seeds a Season has to release before Fungal Reserve raises one guaranteed
## Fruiting Body. Counted at release rather than at germination, so a Season's
## infrastructure is decided the moment it is sown; the remainder carries forward.
@export_range(1, 20, 1) var fungal_reserve_seeds := 3
## Extra Briar Traps harvested per Packed Thorns rank at Briar Payload level one.
@export_range(0.0, 1.0, 0.01) var briar_payload_trap_yield := 0.20
## Trigger-radius increase at Briar Payload level two.
@export_range(0.0, 1.0, 0.01) var briar_payload_trigger_bonus := 0.20
## Entanglement a trap blast applies at Briar Payload level three.
@export_range(0.0, 1.0, 0.01) var briar_payload_entanglement := 0.35
## Trap-to-trap chain range increase at Briar Payload level four.
@export_range(0.0, 1.0, 0.01) var briar_payload_chain_bonus := 0.20
## Traps between each Briar Heart at Briar Payload level five.
@export_range(1, 12, 1) var briar_payload_heart_cadence := 5
## Extra Bloom Force per Spring Pressure rank, at levels one and four.
@export_range(0.0, 1.0, 0.01) var seasonal_surge_force_per_rank := 0.15
## Extra hostile-conversion pressure at Seasonal Surge level two.
@export_range(0.0, 1.0, 0.01) var seasonal_surge_conversion_bonus := 0.20
## Echo Blooms released after a Flowering Season at Seasonal Surge level five.
@export_range(0, 8, 1) var seasonal_surge_echo_count := 4
## Share of normal Force an Echo Bloom carries. Echo Blooms add no Plant Mass.
@export_range(0.0, 1.0, 0.01) var seasonal_surge_echo_force := 0.35
## Root-eruption radius increase at Ancient Fury level one.
@export_range(0.0, 1.0, 0.01) var ancient_fury_radius_bonus := 0.15
## Entanglement a root eruption applies to survivors at Ancient Fury level two.
@export_range(0.0, 1.0, 0.01) var ancient_fury_entanglement := 0.30
## Damage retained by an eruption chained from a kill at Ancient Fury level three.
@export_range(0.0, 1.0, 0.01) var ancient_fury_chain_damage_share := 0.70
## Entanglement required to wake the Root Network at Ancient Fury level four.
@export_range(0.0, 1.0, 0.01) var ancient_fury_trigger_threshold := 0.85
## Heavily Entangled enemies on Mature ground that wake the forest at level five.
@export_range(1, 20, 1) var ancient_fury_awakening_enemies := 6
## Simultaneous eruptions a Forest Awakening fires.
@export_range(1, 20, 1) var ancient_fury_awakening_eruptions := 6
## Seconds between Forest Awakenings.
@export_range(1.0, 60.0, 0.5) var ancient_fury_awakening_cooldown := 10.0

@export_group("Super Bloom")
# Read by Spore.
## Super Bloom kills required to plant one secondary Seed.
@export_range(1, 12, 1) var secondary_kills_per_seed := 3
# Read by Bloom.
## Maximum number of Seed-to-Bloom propagation generations in one chain.
@export_range(0, 6, 1) var maximum_chain_depth := 2
## Territory force and enemy-damage multiplier applied to chained Blooms.
@export_range(1.0, 3.0, 0.01) var chained_bloom_multiplier := 1.22
## Telegraph duration in seconds before a Super Bloom chain detonation.
@export_range(0.0, 2.0, 0.01) var chained_bloom_windup_seconds := 0.34
## Radius in arena pixels Forced Germination searches for a Seed to crack open.
@export_range(20.0, 400.0, 5.0) var forced_germination_radius := 150.0
## Seeds one Bloom's thrown material may crack open where it lands. A Bloom throws
## the ecosystem itself, propagules and all, so a glob coming down on a Seed that is
## already breaking ground doubles what is trying to establish there. How many
## propagules reach a site is the strongest predictor of whether it takes — a site
## receiving a fresh load of living material establishes at once. Capped per Bloom
## so a wide splatter opens the Seeds it actually lands on rather than the field.
@export_range(0, 8, 1) var inoculation_seeds_per_bloom := 2
## How far past the splat's own footprint a landing counts as having reached a Seed.
@export_range(0.5, 4.0, 0.05) var inoculation_radius_scale := 1.15

@export_group("Briar Pods")
## Radius in arena pixels of the temporary thorn perimeter left by an evolved Seed.
@export_range(20.0, 240.0, 1.0) var briar_pod_radius_pixels := 62.0
## Seconds an evolved Seed's temporary Briar Pod perimeter remains active.
@export_range(1.0, 30.0, 0.5) var briar_pod_duration_seconds := 8.0
## Damage and slow multiplier applied by temporary Briar Pod perimeters.
@export_range(1.0, 4.0, 0.05) var briar_pod_contact_multiplier := 1.50

@export_group("Tangleburst")
## Entanglement-rate bonus Aggressive Growth leaves on freshly claimed Seed ground.
@export_range(0.0, 4.0, 0.05) var tangleburst_entanglement_bonus := 0.50
## Seconds that bonus lingers on the new ground.
@export_range(0.1, 20.0, 0.1) var tangleburst_entanglement_seconds := 3.0
## Radius multiple of the mass Briar pulse at Tangleburst level five.
@export_range(1.0, 6.0, 0.05) var tangleburst_pulse_radius_scale := 2.20

@export_group("Rootburst")
## Damage one Germination Season Seed deals as it opens, as a share of what a
## standard enemy is worth at the current wave. A share rather than a flat number so
## it keeps meaning "a third of a normal mob" however far the run has scaled.
@export_range(0.0, 4.0, 0.01) var rootburst_damage_share := 0.35
## Spore that same burst applies.
@export_range(0.0, 2.0, 0.01) var rootburst_spore := 0.50
## Reach of the burst.
@export_range(8.0, 400.0, 2.0) var rootburst_radius_pixels := 70.0
## What Rank 3 adds to each.
@export_range(0.0, 2.0, 0.05) var rootburst_damage_bonus := 0.40
@export_range(0.0, 2.0, 0.05) var rootburst_radius_bonus := 0.20

@export_group("Seed Bank")
## Dormant Seeds banked per second for each percentage point of Mature Green.
@export_range(0.0, 1.0, 0.001) var seed_bank_storage_per_mature_percent := 0.006
## Dormant Seeds the ecosystem can hold before banking stops.
@export_range(1.0, 60.0, 0.5) var seed_bank_capacity := 9.0
## Dormant Seeds required before a Germination Season fires.
## Seconds between Germination Seasons. A clock, not a storage threshold: the burst
## has to be something a player can hold ground for and time a fight around.
@export_range(1.0, 60.0, 0.5) var germination_season_interval := 8.0
## Seeds the free Season that comes with claiming the Evolution releases, regardless
## of what the Bank has actually stored.
@export_range(0, 40, 1) var germination_season_claim_seeds := 6
@export_range(1.0, 40.0, 0.5) var germination_season_threshold := 5.0
## Highest number of Seeds one Germination Season may release at once.
@export_range(1, 40, 1) var germination_season_maximum_seeds := 12
## Arena pixels between the anchors a Germination Season spreads its Seeds across.
@export_range(20.0, 400.0, 5.0) var germination_season_spread_pixels := 150.0
## Seconds between a Mast Year's first and second germination wave.
@export_range(0.1, 6.0, 0.05) var germination_season_mast_delay := 1.50
## Extra Seed growth mass supplied by fully mature ground under a Seed Bank Seed.
@export_range(0.0, 3.0, 0.05) var seed_bank_maturity_mass_bonus := 0.60

@export_group("Flowering Season")
## Mature Green percentage-seconds required to build one Flowering Season event.
@export_range(1.0, 600.0, 1.0) var flowering_season_charge_required := 140.0
## Blooms planted across Mature borders by a single Flowering Season.
@export_range(1, 8, 1) var flowering_season_bloom_count := 3
## Maturity spent at each Flowering Season site, which Root then regrows.
@export_range(0.0, 1.0, 0.01) var flowering_season_maturity_cost := 0.35
## Anchor spacing used once Distributed Flowering spreads the sites out.
@export_range(40.0, 600.0, 5.0) var flowering_season_distributed_spread_pixels := 240.0
## Seconds after a Flowering Season before its Echo Blooms arrive.
@export_range(0.1, 6.0, 0.05) var flowering_season_echo_delay_seconds := 1.10

@export_group("Thornburst")
## Harvested Bramble power required for each Briar Trap a Bloom leaves behind.
@export_range(1.0, 200.0, 0.5) var briar_trap_power_per_trap := 26.0
## Highest number of Briar Traps one Bloom may leave in the ground it just claimed.
@export_range(1, 24, 1) var briar_trap_maximum := 8
## Radius in arena pixels of each Briar Trap blast.
@export_range(8.0, 160.0, 1.0) var briar_trap_radius_pixels := 46.0
## Seconds a Briar Trap persists in newly claimed territory before rotting away.
@export_range(1.0, 60.0, 0.5) var briar_trap_duration_seconds := 12.0
## Base Briar Trap damage before harvested maturity is applied.
@export_range(1.0, 400.0, 1.0) var briar_trap_damage := 46.0
## Extra trap damage supplied when the harvested Bramble stood on fully Mature Green.
@export_range(0.0, 3.0, 0.05) var briar_trap_maturity_bonus := 0.80
## Entanglement applied to everything caught in a Briar Trap blast.
@export_range(0.0, 1.0, 0.01) var briar_trap_entanglement := 0.30
## Territory pressure a detonating trap adds to the ground the Bloom just claimed.
@export_range(0.0, 2.0, 0.01) var briar_trap_pressure := 0.35

@export_group("Coppice")
## Cells of harvest between the Seeds this pairing buries in the cut ground.
@export_range(1, 200, 1) var pioneer_cells_per_seed := 6
## Most Seeds one eruption may carry, so a long hold erupts repeatedly rather than
## saving up one enormous batch.
@export_range(1, 30, 1) var pioneer_seeds := 6
## Seconds buried Seeds wait before they erupt.
@export_range(0.1, 10.0, 0.05) var pioneer_delay_seconds := 1.80
## Damage one of those Seeds can absorb before a Saboteur destroys it.
@export_range(0.1, 20.0, 0.1) var pioneer_seed_durability := 2.0

@export_group("Rebound")
## Radius in arena pixels a detonating Bloom pulls Green in from.
@export_range(10.0, 400.0, 5.0) var rebound_radius_pixels := 96.0
## Bloom Force added per cell of Green the Bloom absorbed.
@export_range(0.0, 0.2, 0.001) var rebound_force_per_cell := 0.014
## Highest Force multiplier Rebound may add, so the collapse cannot compound.
@export_range(0.0, 4.0, 0.05) var rebound_maximum_force := 1.30
## How thin Rebound leaves the Green it draws on, as control. Above the ownership
## threshold on purpose: the collapse thins the ground and never takes it.
@export_range(0.19, 1.0, 0.01) var rebound_compression_floor := 0.40

@export_group("Deadfall")
## Extra Cuttings per point of thorn development the harvest tore out with the Green.
@export_range(0.0, 8.0, 0.05) var deadfall_cuttings_per_development := 1.10

@export_group("Coppicing")
## Extra Cuttings per Mature cell the harvest took.
@export_range(0.0, 4.0, 0.01) var coppicing_cuttings_per_mature_cell := 0.10
## Multiplier on how fast Pruned Ground regrows once the Root Network runs it.
@export_range(1.0, 6.0, 0.05) var coppicing_regrowth_multiplier := 1.90

@export_group("Second Flush")
## Extra buried Seeds per rank of Dense Reseeding, as a share of the base count.
@export_range(0.0, 2.0, 0.05) var second_flush_seed_bonus := 0.20
## How much sooner a buried Seed germinates once Rapid Germination is bought.
@export_range(0.0, 0.9, 0.01) var second_flush_germination_cut := 0.15
## Extra Growth Mass a Seed carries when it germinates on ground Pruning cut open.
@export_range(0.0, 2.0, 0.05) var second_flush_pruned_mass_bonus := 0.20
## Blood and Soil: Seeds a cycle's Cutting kills can bury, and the cap per cycle.
@export_range(0.0, 4.0, 0.05) var second_flush_seeds_per_kill := 0.34
@export_range(0, 20, 1) var second_flush_kill_seed_cap := 6
## Second Flush: every Nth eruption is followed by a second wave of this share.
@export_range(1, 10, 1) var second_flush_wave_cadence := 3
@export_range(0.0, 1.0, 0.05) var second_flush_wave_share := 0.50

@export_group("Compression")
## Extra Force per cell per rank of Efficient Compression, as a share of the base.
@export_range(0.0, 2.0, 0.05) var compression_force_bonus := 0.15
## How much longer Rebound's crater keeps its accelerated reclaim.
@export_range(1.0, 4.0, 0.05) var compression_regrowth_window := 1.20
## Inward Collapse: how far the compression drags enemies toward the Bloom.
@export_range(0.0, 200.0, 1.0) var compression_pull_pixels := 46.0
## Elastic Rebound: the delay before the second wave, and its share of the Force.
@export_range(0.1, 5.0, 0.05) var compression_second_wave_delay := 1.25
@export_range(0.0, 1.0, 0.05) var compression_second_wave_share := 0.45
@export_range(10.0, 400.0, 5.0) var compression_second_wave_radius := 132.0
@export_range(0.0, 400.0, 1.0) var compression_second_wave_damage := 34.0

@export_group("Splinterstorm")
## Extra thorn Cuttings per rank of Thorn Harvest, as a share of the base yield.
@export_range(0.0, 2.0, 0.05) var splinterstorm_yield_bonus := 0.20
## Piercing Splinters: extra pierce, and what a pierced hit keeps of its damage.
@export_range(0, 6, 1) var splinterstorm_extra_pierce := 1
@export_range(0.1, 1.0, 0.05) var splinterstorm_pierce_falloff := 0.60
## Shatter: how much of its damage each half keeps when a Cutting splits on a fully
## Entangled enemy, and how far the splinters seek.
@export_range(0.0, 1.0, 0.05) var splinterstorm_shatter_share := 0.45
## How much Entanglement an enemy must be carrying before a Cutting breaks on it.
@export_range(0.0, 1.0, 0.01) var splinterstorm_shatter_threshold := 0.90
@export_range(10.0, 400.0, 5.0) var splinterstorm_shatter_seek_pixels := 150.0
## Deadfall Volley: spikes launched by every cycle, and how hard they hit.
## Seconds between Deadfall Volleys.
##
## The volley used to fire on *every harvest cycle*, which is several times a second
## while she walks fresh Green -- eight heavy spikes at 1.6x with four pierce, costing
## neither ring nor ground, at a rate an upgrade line buys more of. Measured, rank 5 was
## +138% over its own unevolved pair and took zero damage across a whole bench: the
## strongest thing on the board by a distance, and strong in the specific way that stops
## a run being played.
##
## A cadence of its own is the fix rather than a smaller volley, because the volley is
## the evolution's whole identity and the problem was never its size. Deadfall's contract
## is the *ring* firing continuously; the volley is a second weapon on top of that, and a
## second weapon does not also get to inherit the harvest's rate.
@export_range(0.1, 10.0, 0.1) var splinterstorm_volley_interval_seconds := 2.0
@export_range(0, 24, 1) var splinterstorm_volley_spikes := 8
@export_range(0.5, 6.0, 0.05) var splinterstorm_volley_damage_scale := 1.60
@export_range(0, 12, 1) var splinterstorm_volley_pierce := 4

@export_group("Stool Regrowth")
## Extra Cuttings per rank of Mature Harvest, as a share of the Mature yield.
@export_range(0.0, 2.0, 0.05) var stool_regrowth_yield_bonus := 0.15
## Vigorous Regrowth: how much faster Coppicing drives the cut ground back.
@export_range(1.0, 4.0, 0.05) var stool_regrowth_reclaim_bonus := 1.20
## Root Memory: how much of its former maturity ground regrowing over a Mature cut
## keeps, and how long the memory lasts.
@export_range(0.0, 1.0, 0.05) var stool_regrowth_memory_share := 0.25
@export_range(0.5, 20.0, 0.5) var stool_regrowth_memory_seconds := 6.0
## Second Harvest: the share of a cycle's Mature harvest that must have regrown
## before the second volley fires, and how large that volley is.
@export_range(0.0, 1.0, 0.05) var stool_regrowth_second_threshold := 0.50
@export_range(0.0, 1.0, 0.05) var stool_regrowth_second_share := 0.40

## How many Evolutions a run is built to develop.
##
## Not a cap -- nothing refuses a third -- but the number the panel shows sockets for,
## because a run that can grow two relationships and is shown one socket has no way to
## know the second is coming.
const TARGET_ACTIVE_EVOLUTIONS := 2

## Every Evolution this run holds, in the order it claimed them.
##
## Plural, because an Evolution is no longer a property of one locked pair. A run
## owning three Adaptations has three relationships, any of which may mature, and a
## Path that has already evolved once stays eligible for its other relationship --
## taking Root + Vine does not spend Vine. Two per run is the target; nothing here
## enforces it, because what limits it is how many relationships a twenty-minute run
## can actually develop and how many reward moments the Campaign opens.
var active_evolutions: Array[int] = []

## Whether at least one relationship currently qualifies. Stored rather than derived
## so a bench can force it, and so recomputing it is one call from Progression rather
## than a pair sweep every time something asks.
var _pair_ready := false

## The first Evolution claimed, for everything that still speaks of "the" Evolution:
## the HUD line, the Adaptation tree's header, and a handful of probes. Assigning it
## replaces the whole set, which is what a test restoring a forced state means.
var active_evolution: int:
	get:
		return (
			active_evolutions[0]
			if not active_evolutions.is_empty()
			else Progression.EvolutionId.NONE
		)
	set(value):
		active_evolutions.clear()
		if value != Progression.EvolutionId.NONE:
			active_evolutions.append(value)
		evolution_changed.emit(evolution_status)

## Derived from the set rather than tracked beside it, because a stored status and a
## set of claimed Evolutions are two records of the same fact and only one of them
## can be right after a claim nobody remembered to announce.
var evolution_status: int:
	get:
		if not active_evolutions.is_empty():
			return Progression.EvolutionStatus.EVOLVED
		return (
			Progression.EvolutionStatus.READY
			if _pair_ready
			else Progression.EvolutionStatus.NOT_READY
		)
	set(value):
		# EVOLVED is the set's to say; forcing the other two is how a bench asks for a
		# claim without buying ten ranks to get there first.
		if value != Progression.EvolutionStatus.EVOLVED:
			_pair_ready = value == Progression.EvolutionStatus.READY


func _ready() -> void:
	_descriptions.configure(self)
	assert(progression != null, "Evolutions requires Progression")
	reset_evolutions()


func reset_evolutions() -> void:
	active_evolutions.clear()
	_pair_ready = false
	evolution_changed.emit(evolution_status)


func update_readiness(pair_ready: bool) -> void:
	# Progression owns what counts as investment in a Path, so it reports whether any
	# relationship qualifies and this node decides what the run's state becomes.
	var was := evolution_status
	_pair_ready = pair_ready
	if evolution_status != was:
		evolution_changed.emit(evolution_status)


func clear_active_evolution() -> void:
	# A roster that changed under the run invalidates what it had claimed. Readiness
	# is recomputed from the new roster immediately after.
	active_evolutions.clear()


func is_evolution_path(path_id: int) -> bool:
	# Every owned Adaptation is half of a relationship now. Cores and Branches differ
	# in when the run is allowed to take them, not in what they can become.
	return progression.owns_adaptation(path_id)


static func get_evolution_upgrade_id(evolution_id: int) -> int:
	return EvolutionDescriptions.upgrade_id_for(evolution_id)


func get_evolution_rank(evolution_id: int) -> int:
	## What rank the run has bought of one named Evolution, or zero if it does not
	## hold that Evolution at all.
	##
	## The question every director actually has. While a run could only ever hold one
	## Evolution, "the Evolution's rank" and "Deadfall's rank" were the same number
	## and every caller asked for the first; with two claimed at once they are not,
	## and a Pruning effect reading a Spore Evolution's rank would be silently wrong
	## rather than visibly broken.
	if evolution_id == Progression.EvolutionId.NONE:
		return 0
	if not active_evolutions.has(evolution_id):
		return 0
	var upgrade_id := get_evolution_upgrade_id(evolution_id)
	if upgrade_id < 0:
		return 0
	return progression.get_upgrade_level(upgrade_id)


func get_evolution_upgrade_level() -> int:
	# The deepest rank the run holds in any of its Evolutions. Presentation only --
	# the HUD line and the Adaptation tree header -- because a run with two
	# Evolutions has no single "the Evolution rank", and anything that mechanically
	# needs one is asking the wrong question and should name its Evolution.
	var deepest := 0
	for evolution_id in active_evolutions:
		deepest = maxi(deepest, get_evolution_rank(evolution_id))
	return deepest


func get_active_evolution_rank() -> int:
	## Claiming an Evolution grants its line at rank 1; later drafts deepen that
	## same stored line to rank 5.
	return get_evolution_rank(active_evolution)


## The Evolution matrix, as one symmetric table.
##
## Twenty-eight unordered pairs of eight Adaptations. Held as data rather than as a
## chain of conditionals so the pairing can be asked about before it is owned --
## the second Core's chooser needs to name the Evolution it would produce -- and so
## the symmetry is a property of the lookup instead of something twenty-eight
## hand-written lines have to remember.
const PAIR_EVOLUTIONS := {
	0 * 8 + 1: Progression.EvolutionId.SUPER_BLOOM,
	0 * 8 + 2: Progression.EvolutionId.BRIAR_PODS,
	0 * 8 + 3: Progression.EvolutionId.SEED_BANK,
	0 * 8 + 4: Progression.EvolutionId.PIONEER,
	0 * 8 + 5: Progression.EvolutionId.INOCULATOR,
	0 * 8 + 6: Progression.EvolutionId.MYCELIAL_VINE,
	0 * 8 + 7: Progression.EvolutionId.ROT,
	1 * 8 + 2: Progression.EvolutionId.THORNBURST,
	1 * 8 + 3: Progression.EvolutionId.FLOWERING_SEASON,
	1 * 8 + 4: Progression.EvolutionId.REBOUND,
	1 * 8 + 5: Progression.EvolutionId.BURSTBLOOM,
	1 * 8 + 6: Progression.EvolutionId.WISTERIA,
	1 * 8 + 7: Progression.EvolutionId.OVERRIPE,
	2 * 8 + 3: Progression.EvolutionId.OLD_GROWTH,
	2 * 8 + 4: Progression.EvolutionId.DEADFALL,
	2 * 8 + 5: Progression.EvolutionId.HEDGE_BATTERY,
	2 * 8 + 6: Progression.EvolutionId.BRIAR_CANE,
	2 * 8 + 7: Progression.EvolutionId.DURIAN,
	3 * 8 + 4: Progression.EvolutionId.COPPICING,
	3 * 8 + 5: Progression.EvolutionId.ROOTSTOCK,
	3 * 8 + 6: Progression.EvolutionId.HEARTWOOD,
	3 * 8 + 7: Progression.EvolutionId.ORCHARD,
	4 * 8 + 5: Progression.EvolutionId.DEADHEADING,
	4 * 8 + 6: Progression.EvolutionId.ESPALIER,
	4 * 8 + 7: Progression.EvolutionId.GRAFT,
	5 * 8 + 6: Progression.EvolutionId.THORNWHIP,
	5 * 8 + 7: Progression.EvolutionId.BURDOCK,
	6 * 8 + 7: Progression.EvolutionId.GOURDVINE,
}


static func get_pair_evolution_for(first_path: int, second_path: int) -> int:
	## What an unordered Core pair becomes. Order never matters: Spore then Root and
	## Root then Spore are the same run and the same Seed Bank.
	if first_path == second_path:
		return Progression.EvolutionId.NONE
	# Keyed on the sorted pair, packed into one integer, so both orders of the same
	# two Adaptations resolve to the same entry by construction.
	var key := mini(first_path, second_path) * 8 + maxi(first_path, second_path)
	return PAIR_EVOLUTIONS.get(key, Progression.EvolutionId.NONE)


func get_pair_evolution_id() -> int:
	## What the Core pair specifically becomes. Still meaningful -- the Cores are the
	## first two Adaptations a run commits to and the relationship it is most likely
	## to develop -- but no longer the run's only possible Evolution.
	if not progression.has_primary_path() or not progression.has_secondary_path():
		return Progression.EvolutionId.NONE
	return get_pair_evolution_for(progression.primary_path, progression.secondary_path)


func get_eligible_evolutions() -> PackedInt32Array:
	## Every Evolution the run could claim right now.
	##
	## One entry per owned pair whose two Adaptations are both developed past the
	## investment gate and whose Evolution is not already held. Order is the roster's,
	## so the same build offers the same list twice -- the *sample* shown to the
	## player is drawn from it, and drawing from a set that reshuffled itself would
	## make a reroll look like it had changed what the run qualifies for.
	var eligible := PackedInt32Array()
	if progression == null:
		return eligible
	var owned := progression.get_owned_adaptations()
	for first_index in range(owned.size()):
		for second_index in range(first_index + 1, owned.size()):
			var first: int = owned[first_index]
			var second: int = owned[second_index]
			if not progression.is_pair_invested(first, second):
				continue
			var evolution_id := get_pair_evolution_for(first, second)
			if evolution_id == Progression.EvolutionId.NONE:
				continue
			if active_evolutions.has(evolution_id):
				continue
			if eligible.has(evolution_id):
				continue
			eligible.append(evolution_id)
	return eligible


func has_active_evolution(evolution_id: int) -> bool:
	return active_evolutions.has(evolution_id)


func get_evolution_upgrade_rank_description(upgrade_id: int, rank: int) -> String:
	## Every rank of an Evolution line does something different, so the draft names
	## the rank it is about to buy rather than a per-level average. The text itself
	## is `EvolutionDescriptions`, which reads this node for the numbers in it.
	return _descriptions.get_rank_description(upgrade_id, rank)


func is_pair_evolution_draftable() -> bool:
	return not get_eligible_evolutions().is_empty()


func grant_evolution(evolution_id: int) -> bool:
	## Claims one named Evolution. Nothing is consumed: both Paths stay eligible for
	## whatever else they are half of, which is what lets a three-Adaptation run reach
	## a second Evolution without abandoning the first.
	if evolution_id == Progression.EvolutionId.NONE:
		return false
	if active_evolutions.has(evolution_id):
		return false
	active_evolutions.append(evolution_id)
	evolution_changed.emit(evolution_status)
	return true


func grant_evolution_if_ready() -> bool:
	## The first Evolution the run qualifies for, claimed.
	##
	## The bench path and the shorthand every probe uses. A forced READY with nothing
	## actually eligible falls back to the Core pair, so an instrument can hand a
	## build its Evolution without buying ten ranks to get there first.
	var eligible := get_eligible_evolutions()
	if not eligible.is_empty():
		return grant_evolution(eligible[0])
	if not _pair_ready:
		return false
	return grant_evolution(get_pair_evolution_id())


static func get_evolution_name(evolution_id: int) -> String:
	return EvolutionDescriptions.evolution_name(evolution_id)


static func get_evolution_description(evolution_id: int) -> String:
	return EvolutionDescriptions.evolution_description(evolution_id)


static func get_upgrade_evolution(upgrade_id: int) -> int:
	return EvolutionDescriptions.evolution_for_upgrade(upgrade_id)

## What the run has claimed, rather than the authored tuning that surrounds it.
## Everything else on this node describes what an Evolution *does*, which belongs to
## the build and not to the save.
func capture_state() -> Dictionary:
	return {
		"pair_ready": _pair_ready,
		"active_evolutions": PackedInt32Array(active_evolutions),
	}


func apply_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_pair_ready = bool(state.get("pair_ready", false))
	active_evolutions.clear()
	var stored: Variant = state.get("active_evolutions")
	if stored is PackedInt32Array:
		for evolution_id in stored as PackedInt32Array:
			active_evolutions.append(int(evolution_id))
	elif state.has("active_evolution"):
		# A save written before Evolutions became plural.
		var single := int(state.get("active_evolution", Progression.EvolutionId.NONE))
		if single != Progression.EvolutionId.NONE:
			active_evolutions.append(single)
	evolution_changed.emit(evolution_status)
