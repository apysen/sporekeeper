class_name PhaseBEvolutions
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

signal evolution_changed(status: int)

@export_group("Collaborators")
## Progression component that owns the paths a pairing is read from and the
## upgrade levels an Evolution's optional line is counted in.
@export var progression: PhaseBProgression

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

var evolution_status := PhaseBProgression.EvolutionStatus.NOT_READY
var active_evolution := PhaseBProgression.EvolutionId.NONE


func _ready() -> void:
	assert(progression != null, "PhaseBEvolutions requires PhaseBProgression")
	reset_evolutions()


func reset_evolutions() -> void:
	evolution_status = PhaseBProgression.EvolutionStatus.NOT_READY
	active_evolution = PhaseBProgression.EvolutionId.NONE
	evolution_changed.emit(evolution_status)


func update_readiness(pair_ready: bool) -> void:
	# Progression owns what "maxed" means for a path line, so it reports readiness
	# and this node decides what the run's Evolution state becomes.
	if evolution_status == PhaseBProgression.EvolutionStatus.EVOLVED:
		return
	var next_status := (
		PhaseBProgression.EvolutionStatus.READY
		if pair_ready
		else PhaseBProgression.EvolutionStatus.NOT_READY
	)
	if next_status == evolution_status:
		return
	evolution_status = next_status
	evolution_changed.emit(evolution_status)


func clear_active_evolution() -> void:
	# A pairing that changes invalidates what it would have become. The status is
	# left alone: readiness is recomputed from the new pair immediately after.
	active_evolution = PhaseBProgression.EvolutionId.NONE


func is_evolution_path(path_id: int) -> bool:
	# Only the Core pair makes the pairing. A Branch never joins it, so no second
	# Evolution and no three-way pairing can ever form.
	return progression.is_core_adaptation(path_id)


static func get_evolution_upgrade_id(evolution_id: int) -> int:
	match evolution_id:
		PhaseBProgression.EvolutionId.SUPER_BLOOM:
			return PhaseBProgression.UpgradeId.EVOLUTION_FLORAL_CASCADE
		PhaseBProgression.EvolutionId.BRIAR_PODS:
			return PhaseBProgression.UpgradeId.EVOLUTION_TANGLEBURST
		PhaseBProgression.EvolutionId.SEED_BANK:
			return PhaseBProgression.UpgradeId.EVOLUTION_SEED_RESERVE
		PhaseBProgression.EvolutionId.THORNBURST:
			return PhaseBProgression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD
		PhaseBProgression.EvolutionId.FLOWERING_SEASON:
			return PhaseBProgression.UpgradeId.EVOLUTION_SEASONAL_SURGE
		PhaseBProgression.EvolutionId.OLD_GROWTH:
			return PhaseBProgression.UpgradeId.EVOLUTION_ANCIENT_FURY
		PhaseBProgression.EvolutionId.PIONEER:
			return PhaseBProgression.UpgradeId.EVOLUTION_SECOND_FLUSH
		PhaseBProgression.EvolutionId.REBOUND:
			return PhaseBProgression.UpgradeId.EVOLUTION_COMPRESSION
		PhaseBProgression.EvolutionId.DEADFALL:
			return PhaseBProgression.UpgradeId.EVOLUTION_SPLINTERSTORM
		PhaseBProgression.EvolutionId.COPPICING:
			return PhaseBProgression.UpgradeId.EVOLUTION_STOOL_REGROWTH
		PhaseBProgression.EvolutionId.INOCULATOR:
			return PhaseBProgression.UpgradeId.EVOLUTION_INOCULATOR
		PhaseBProgression.EvolutionId.BURSTBLOOM:
			return PhaseBProgression.UpgradeId.EVOLUTION_BURSTBLOOM
		PhaseBProgression.EvolutionId.HEDGE_BATTERY:
			return PhaseBProgression.UpgradeId.EVOLUTION_HEDGE_BATTERY
		PhaseBProgression.EvolutionId.ROOTSTOCK:
			return PhaseBProgression.UpgradeId.EVOLUTION_ROOTSTOCK
		PhaseBProgression.EvolutionId.DEADHEADING:
			return PhaseBProgression.UpgradeId.EVOLUTION_DEADHEADING
		PhaseBProgression.EvolutionId.THORNWHIP:
			return PhaseBProgression.UpgradeId.EVOLUTION_THORNWHIP
		PhaseBProgression.EvolutionId.BURDOCK:
			return PhaseBProgression.UpgradeId.EVOLUTION_BURDOCK
		PhaseBProgression.EvolutionId.MYCELIAL_VINE:
			return PhaseBProgression.UpgradeId.EVOLUTION_MYCELIAL_VINE
		PhaseBProgression.EvolutionId.WISTERIA:
			return PhaseBProgression.UpgradeId.EVOLUTION_WISTERIA
		PhaseBProgression.EvolutionId.BRIAR_CANE:
			return PhaseBProgression.UpgradeId.EVOLUTION_BRIAR_CANE
		PhaseBProgression.EvolutionId.HEARTWOOD:
			return PhaseBProgression.UpgradeId.EVOLUTION_HEARTWOOD
		PhaseBProgression.EvolutionId.ESPALIER:
			return PhaseBProgression.UpgradeId.EVOLUTION_ESPALIER
		PhaseBProgression.EvolutionId.GOURDVINE:
			return PhaseBProgression.UpgradeId.EVOLUTION_GOURDVINE
		PhaseBProgression.EvolutionId.ROT:
			return PhaseBProgression.UpgradeId.EVOLUTION_ROT
		PhaseBProgression.EvolutionId.OVERRIPE:
			return PhaseBProgression.UpgradeId.EVOLUTION_OVERRIPE
		PhaseBProgression.EvolutionId.DURIAN:
			return PhaseBProgression.UpgradeId.EVOLUTION_DURIAN
		PhaseBProgression.EvolutionId.ORCHARD:
			return PhaseBProgression.UpgradeId.EVOLUTION_ORCHARD
		PhaseBProgression.EvolutionId.GRAFT:
			return PhaseBProgression.UpgradeId.EVOLUTION_GRAFT
	return -1


func get_evolution_upgrade_level() -> int:
	# Level of the line belonging to the Evolution this run actually holds. Zero
	# for a run that has not evolved, so every consumer can read it unguarded.
	if evolution_status != PhaseBProgression.EvolutionStatus.EVOLVED:
		return 0
	var upgrade_id := get_evolution_upgrade_id(active_evolution)
	if upgrade_id < 0:
		return 0
	return progression.get_upgrade_level(upgrade_id)


func get_active_evolution_rank() -> int:
	## Claiming an Evolution grants its line at rank 1; later drafts deepen that
	## same stored line to rank 5.
	if evolution_status != PhaseBProgression.EvolutionStatus.EVOLVED:
		return 0
	var upgrade_id := get_evolution_upgrade_id(active_evolution)
	if upgrade_id < 0:
		return 0
	return progression.get_upgrade_level(upgrade_id)


## The Evolution matrix, as one symmetric table.
##
## Twenty-eight unordered pairs of eight Adaptations. Held as data rather than as a
## chain of conditionals so the pairing can be asked about before it is owned --
## the second Core's chooser needs to name the Evolution it would produce -- and so
## the symmetry is a property of the lookup instead of something twenty-eight
## hand-written lines have to remember.
const PAIR_EVOLUTIONS := {
	0 * 8 + 1: PhaseBProgression.EvolutionId.SUPER_BLOOM,
	0 * 8 + 2: PhaseBProgression.EvolutionId.BRIAR_PODS,
	0 * 8 + 3: PhaseBProgression.EvolutionId.SEED_BANK,
	0 * 8 + 4: PhaseBProgression.EvolutionId.PIONEER,
	0 * 8 + 5: PhaseBProgression.EvolutionId.INOCULATOR,
	0 * 8 + 6: PhaseBProgression.EvolutionId.MYCELIAL_VINE,
	0 * 8 + 7: PhaseBProgression.EvolutionId.ROT,
	1 * 8 + 2: PhaseBProgression.EvolutionId.THORNBURST,
	1 * 8 + 3: PhaseBProgression.EvolutionId.FLOWERING_SEASON,
	1 * 8 + 4: PhaseBProgression.EvolutionId.REBOUND,
	1 * 8 + 5: PhaseBProgression.EvolutionId.BURSTBLOOM,
	1 * 8 + 6: PhaseBProgression.EvolutionId.WISTERIA,
	1 * 8 + 7: PhaseBProgression.EvolutionId.OVERRIPE,
	2 * 8 + 3: PhaseBProgression.EvolutionId.OLD_GROWTH,
	2 * 8 + 4: PhaseBProgression.EvolutionId.DEADFALL,
	2 * 8 + 5: PhaseBProgression.EvolutionId.HEDGE_BATTERY,
	2 * 8 + 6: PhaseBProgression.EvolutionId.BRIAR_CANE,
	2 * 8 + 7: PhaseBProgression.EvolutionId.DURIAN,
	3 * 8 + 4: PhaseBProgression.EvolutionId.COPPICING,
	3 * 8 + 5: PhaseBProgression.EvolutionId.ROOTSTOCK,
	3 * 8 + 6: PhaseBProgression.EvolutionId.HEARTWOOD,
	3 * 8 + 7: PhaseBProgression.EvolutionId.ORCHARD,
	4 * 8 + 5: PhaseBProgression.EvolutionId.DEADHEADING,
	4 * 8 + 6: PhaseBProgression.EvolutionId.ESPALIER,
	4 * 8 + 7: PhaseBProgression.EvolutionId.GRAFT,
	5 * 8 + 6: PhaseBProgression.EvolutionId.THORNWHIP,
	5 * 8 + 7: PhaseBProgression.EvolutionId.BURDOCK,
	6 * 8 + 7: PhaseBProgression.EvolutionId.GOURDVINE,
}


static func get_pair_evolution_for(first_path: int, second_path: int) -> int:
	## What an unordered Core pair becomes. Order never matters: Spore then Root and
	## Root then Spore are the same run and the same Seed Bank.
	if first_path == second_path:
		return PhaseBProgression.EvolutionId.NONE
	# Keyed on the sorted pair, packed into one integer, so both orders of the same
	# two Adaptations resolve to the same entry by construction.
	var key := mini(first_path, second_path) * 8 + maxi(first_path, second_path)
	return PAIR_EVOLUTIONS.get(key, PhaseBProgression.EvolutionId.NONE)


func get_pair_evolution_id() -> int:
	# A claimed pairing is frozen: nothing acquired afterwards -- no Branch, no
	# relic, no generated event -- may re-roll which Evolution the run holds.
	if evolution_status == PhaseBProgression.EvolutionStatus.EVOLVED:
		return active_evolution
	if not progression.has_primary_path() or not progression.has_secondary_path():
		return PhaseBProgression.EvolutionId.NONE
	return get_pair_evolution_for(progression.primary_path, progression.secondary_path)


func has_active_evolution(evolution_id: int) -> bool:
	return evolution_status == PhaseBProgression.EvolutionStatus.EVOLVED and active_evolution == evolution_id


func get_evolution_upgrade_rank_description(upgrade_id: int, rank: int) -> String:
	# Every rank of an Evolution line does something different, so the draft names
	# the rank it is about to buy rather than a per-level average.
	match upgrade_id:
		PhaseBProgression.UpgradeId.EVOLUTION_FLORAL_CASCADE:
			match rank:
				1:
					return "Cascade Force: chained Blooms keep +%d%% Force" % roundi(
						floral_cascade_force_per_rank * 100.0
					)
				2:
					return "Deep Cascade: chains propagate one generation further"
				3:
					return "Forced Germination: every %d Super Blooms germinate a Seed" % (
						floral_cascade_germination_cadence
					)
				4:
					return "Cascade Force II: another +%d%% chained Bloom Force" % roundi(
						floral_cascade_force_per_rank * 100.0
					)
				5:
					return "Grand Bloom: every %d Super Blooms erupt at %dx scale" % [
						floral_cascade_grand_cadence,
						roundi(floral_cascade_grand_scale),
					]
		PhaseBProgression.UpgradeId.EVOLUTION_TANGLEBURST:
			match rank:
				1:
					return "Tangled Germination: germination applies %d%% Entanglement" % (
						roundi(tangleburst_entanglement * 100.0)
					)
				2:
					return "Grasping Shoots: germination Ensnares already-Entangled enemies"
				3:
					return "Constricting Growth: germination drags nearby enemies inward"
				4:
					return "Aggressive Growth: fresh Seed ground ensnares far faster"
				5:
					return "Mass Entanglement: every %d Seeds pin a whole mob and seed it with %d%% Spore" % [
						tangleburst_pulse_cadence,
						roundi(tangleburst_pulse_spore * 100.0),
					]
		PhaseBProgression.UpgradeId.EVOLUTION_SEED_RESERVE:
			match rank:
				1:
					return "Expanded Reserve: +%d%% Seed Bank capacity" % roundi(
						seed_reserve_capacity_per_rank * 100.0
					)
				2:
					return "Heavy Seeding: Seeds bank %d%% faster" % roundi(
						seed_reserve_rate_bonus * 100.0
					)
				3:
					return "Rootburst: Season bursts deal +%d%% damage at +%d%% radius" % [
						roundi(rootburst_damage_bonus * 100.0),
						roundi(rootburst_radius_bonus * 100.0),
					]
				4:
					return "Fungal Reserve: every %d Seeds released raise a Fruiting Body that clouds at once" % (
						fungal_reserve_seeds
					)
				5:
					return "Mast Year: every Season fires a second full wave %.1fs later" % (
						germination_season_mast_delay
					)
		PhaseBProgression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD:
			match rank:
				1:
					return "Packed Thorns: +%d%% Briar Traps per harvest" % roundi(
						briar_payload_trap_yield * 100.0
					)
				2:
					return "Sensitive Traps: +%d%% trigger radius" % roundi(
						briar_payload_trigger_bonus * 100.0
					)
				3:
					return "Barbed Blast: trap blasts apply %d%% Entanglement" % roundi(
						briar_payload_entanglement * 100.0
					)
				4:
					return "Chain Fuse: +%d%% trap-to-trap chain range" % roundi(
						briar_payload_chain_bonus * 100.0
					)
				5:
					return "Briar Heart: every %d traps becomes a repeating blast" % (
						briar_payload_heart_cadence
					)
		PhaseBProgression.UpgradeId.EVOLUTION_SEASONAL_SURGE:
			match rank:
				1:
					return "Spring Pressure: +%d%% Flowering Bloom Force" % roundi(
						seasonal_surge_force_per_rank * 100.0
					)
				2:
					return "Encroachment: +%d%% conversion against hostile ground" % (
						roundi(seasonal_surge_conversion_bonus * 100.0)
					)
				3:
					return "Distributed Flowering: Blooms spread across the frontier"
				4:
					return "Spring Pressure II: another +%d%% Bloom Force" % roundi(
						seasonal_surge_force_per_rank * 100.0
					)
				5:
					return "Second Spring: %d Echo Blooms follow every Season" % (
						seasonal_surge_echo_count
					)
		PhaseBProgression.UpgradeId.EVOLUTION_ANCIENT_FURY:
			match rank:
				1:
					return "Deep Eruption: +%d%% eruption radius" % roundi(
						ancient_fury_radius_bonus * 100.0
					)
				2:
					return "Thorned Roots: eruptions Entangle survivors"
				3:
					return "Root Cascade: eruption kills erupt again at %d%% damage" % (
						roundi(ancient_fury_chain_damage_share * 100.0)
					)
				4:
					return "Restless Forest: erupts at %d%% Entanglement" % roundi(
						ancient_fury_trigger_threshold * 100.0
					)
				5:
					return "Forest Awakening: %d Entangled enemies wake %d eruptions" % [
						ancient_fury_awakening_enemies,
						ancient_fury_awakening_eruptions,
					]
		PhaseBProgression.UpgradeId.EVOLUTION_SECOND_FLUSH:
			match rank:
				1:
					return "Dense Reseeding: +%d%% Seeds buried in cut ground" % roundi(
						second_flush_seed_bonus * 100.0
					)
				2:
					return "Rapid Germination: buried Seeds erupt %d%% sooner" % roundi(
						second_flush_germination_cut * 100.0
					)
				3:
					return "Fertile Cut: Seeds on cut ground carry +%d%% Growth Mass" % roundi(
						second_flush_pruned_mass_bonus * 100.0
					)
				4:
					return "Blood and Soil: Cutting kills bury up to %d more Seeds" % (
						second_flush_kill_seed_cap
					)
				5:
					return "Second Flush: every %d eruptions a second wave at %d%%" % [
						second_flush_wave_cadence,
						roundi(second_flush_wave_share * 100.0),
					]
		PhaseBProgression.UpgradeId.EVOLUTION_COMPRESSION:
			match rank:
				1:
					return "Efficient Compression: +%d%% Force per cell collapsed" % roundi(
						compression_force_bonus * 100.0
					)
				2:
					return "Elastic Growth: the collapsed ground reclaims far faster"
				3:
					return "Inward Collapse: the compression drags enemies in first"
				4:
					return "Efficient Compression II: another +%d%% Force per cell" % roundi(
						compression_force_bonus * 100.0
					)
				5:
					return "Elastic Rebound: a second wave at %d%% Force after %.2fs" % [
						roundi(compression_second_wave_share * 100.0),
						compression_second_wave_delay,
					]
		PhaseBProgression.UpgradeId.EVOLUTION_SPLINTERSTORM:
			match rank:
				1:
					return "Thorn Harvest: +%d%% Cuttings from thorned Green" % roundi(
						splinterstorm_yield_bonus * 100.0
					)
				2:
					return "Piercing Splinters: +%d Pierce at %d%% damage" % [
						splinterstorm_extra_pierce,
						roundi(splinterstorm_pierce_falloff * 100.0),
					]
				3:
					return "Shatter: Cuttings split on fully Entangled enemies"
				4:
					return "Thorn Harvest II: another +%d%% thorn Cuttings" % roundi(
						splinterstorm_yield_bonus * 100.0
					)
				5:
					return "Deadfall Volley: every cycle fires %d heavy spikes" % (
						splinterstorm_volley_spikes
					)
		PhaseBProgression.UpgradeId.EVOLUTION_STOOL_REGROWTH:
			match rank:
				1:
					return "Mature Harvest: +%d%% Cuttings from Mature ground" % roundi(
						stool_regrowth_yield_bonus * 100.0
					)
				2:
					return "Vigorous Regrowth: cut Mature ground returns far faster"
				3:
					return "Root Memory: regrowth keeps %d%% of its former maturity" % roundi(
						stool_regrowth_memory_share * 100.0
					)
				4:
					return "Mature Harvest II: another +%d%% Mature Cuttings" % roundi(
						stool_regrowth_yield_bonus * 100.0
					)
				5:
					return "Second Harvest: regrowth releases a %d%% second volley" % roundi(
						stool_regrowth_second_share * 100.0
					)
		PhaseBProgression.UpgradeId.EVOLUTION_INOCULATOR:
			match rank:
				1:
					return "Thistle hits apply 4% Spore"
				2:
					return "Ricochet hits apply 6% Spore instead"
				3:
					return "Critical hits add another 8% Spore"
				4:
					return "Base Thistle-hit Spore rises to 6%"
				5:
					return "First hit at 100% Spore emits a 60% Spore pulse, once per enemy"
		PhaseBProgression.UpgradeId.EVOLUTION_BURSTBLOOM:
			match rank:
				1:
					return "Bloom-supported Thistles charge for 4s and add one 35% Bloomshot"
				2:
					return "Bloomshot charge lasts 6s"
				3:
					return "A critical direct Bloomshot hit gains 40% explosion radius"
				4:
					return "Bloomshot explosion rises to 50% Bloom Force"
				5:
					return "Normal Blooms trigger an immediate bonus volley from charged Thistles"
		PhaseBProgression.UpgradeId.EVOLUTION_HEDGE_BATTERY:
			match rank:
				1:
					return "Thistle hits apply 5% Entanglement, or 10% on your Green"
				2:
					return "Fully Entangled enemies take 20% more Thistle damage"
				3:
					return "Critical hits apply another 8% Entanglement"
				4:
					return "Hit Entanglement rises to 8%, or 16% on your Green"
				5:
					return "First hit on a fully Entangled enemy each second triggers another Thistle"
		PhaseBProgression.UpgradeId.EVOLUTION_ROOTSTOCK:
			match rank:
				1:
					return "A Thistle keeps firing for 3s after losing Green support"
				2:
					return "Every fifth firing cycle loads a 1.5x Heavy Thorn with knockback"
				3:
					return "Heavy Thorns pierce two enemies before Burr ricochets"
				4:
					return "Fully Mature support loads a Heavy Thorn every four cycles"
				5:
					return "Every third Heavy Thorn calls an 8s-cooldown network Heavy salvo"
		PhaseBProgression.UpgradeId.EVOLUTION_DEADHEADING:
			match rank:
				1:
					return "Releasing at least 4 Cuttings triggers a bonus volley from every Thistle"
				2:
					return "The volley inherits 35% of the current Pruning Charge damage bonus"
				3:
					return "Deadheading volleys gain +1 Pierce"
				4:
					return "A full Charge repeats the volley after 0.4s at 60% damage"
				5:
					return "A full Charge raises two temporary Thistles for 5s outside the cap"
		PhaseBProgression.UpgradeId.EVOLUTION_THORNWHIP:
			match rank:
				1:
					return "Two mounted Thistle heads fire once through each Vine sweep"
				2:
					return "Mount a third Thistle head"
				3:
					return "The outer head inherits Apical Dominance"
				4:
					return "Mount a fourth Thistle head"
				5:
					return "Every mounted head fires twice per sweep"
		PhaseBProgression.UpgradeId.EVOLUTION_BURDOCK:
			match rank:
				1:
					return "Each rolling Fruit carries one firing Thistle"
				2:
					return "Carried Thistles inherit all Thistle upgrades"
				3:
					return "Fruit collisions reset the carried Thistle, at most every 0.5s"
				4:
					return "Terminal Fruit raises a 5s temporary Thistle, maximum two"
				5:
					return "The terminal volley gains +2 ricochets and +50pp critical chance"
		PhaseBProgression.UpgradeId.EVOLUTION_MYCELIAL_VINE:
			match rank:
				1:
					return "Every Vine hit applies 15% Spore"
				2:
					return "Apical hits apply another 15% Spore"
				3:
					return "Vine kills count twice toward Seed Production"
				4:
					return "Vine deals 20% more damage to enemies at 50% Spore"
				5:
					return "Apical hits collapse Overgrown enemies (elite 25% max HP, boss 8%)"
		PhaseBProgression.UpgradeId.EVOLUTION_WISTERIA:
			match rank:
				1:
					return "A normal Bloom arms 3 blossoms along the next Vine sweep at 35% Force"
				2:
					return "The armed sweep grows a fourth blossom"
				3:
					return "The tip blossom reaches 70% Force at 1.35x radius"
				4:
					return "Sweep blossoms inherit 50% of Aftergrowth and Suppression"
				5:
					return "The blossom sequence repeats after 0.75s at 50% strength"
		PhaseBProgression.UpgradeId.EVOLUTION_BRIAR_CANE:
			match rank:
				1:
					return "Vine hits apply 15% Entanglement, or 25% on your Green"
				2:
					return "Fully Entangled enemies take 20% more Vine damage"
				3:
					return "Fully Entangled enemies are repelled 50%, or 100% on your Green"
				4:
					return "Apical hit Entanglement rises to 30%, or 50% on your Green"
				5:
					return "Hitting any fully Entangled enemy repels the whole sweep, +25% on Green"
		PhaseBProgression.UpgradeId.EVOLUTION_HEARTWOOD:
			match rank:
				1:
					return "Every fifth Vine sweep deals 1.5x damage at 1.15x reach"
				2:
					return "The Heartwood sweep's outer 40% is Apical"
				3:
					return "Starting a sweep on fully Mature Green advances the counter twice"
				4:
					return "The opposite sweep after Heartwood arrives 40% sooner"
				5:
					return "A root echo repeats the sector after 0.3s at 60% Vine damage"
		PhaseBProgression.UpgradeId.EVOLUTION_ESPALIER:
			match rank:
				1:
					return "Released Cuttings launch in the current 90-degree forward fan"
				2:
					return "Cuttings gain launch distance equal to 50% of Elongation"
				3:
					return "A full Charge adds a Vine sweep in the release direction"
				4:
					return "The bonus Vine inherits 50% of the Charge payout bonus"
				5:
					return "A second Cutting fan follows after 0.5s at 60% damage"
		PhaseBProgression.UpgradeId.EVOLUTION_GOURDVINE:
			match rank:
				1:
					return "Fruit attach to the outer next Vine sweep and detach at full extension"
				2:
					return "Attached Fruit deal 50% collision damage on Apical enemies"
				3:
					return "Detached Fruit gain 50% of Elongation as roll distance"
				4:
					return "Armed Fruit add 25% of Ripening to Vine Apical damage"
				5:
					return "Detached Fruit start 50% faster and first-hit damage rises 50%"
		PhaseBProgression.UpgradeId.EVOLUTION_ROT:
			match rank:
				1:
					return "Fruit collisions apply 20% Spore"
				2:
					return "Fruit Green accumulates Spore 50% faster for 4s"
				3:
					return "Fruit lose 50% less momentum against enemies at 50% Spore"
				4:
					return "Terminal Fruit emits a 40% Spore pulse in 80px"
				5:
					return "Every third terminal raises a guaranteed immediate Fruiting Body"
		PhaseBProgression.UpgradeId.EVOLUTION_OVERRIPE:
			match rank:
				1:
					return "Terminal Fruit adds a 65%-Force Bloom before bursting into territory"
				2:
					return "The first collision creates a 25% Bloom burst without stopping"
				3:
					return "Terminal Bloom launches 3 droplets"
				4:
					return "Terminal Bloom rises to 80% Force"
				5:
					return "Terminal Fruit launches two 40%-distance germinating fragments"
		PhaseBProgression.UpgradeId.EVOLUTION_DURIAN:
			match rank:
				1:
					return "Fruit collisions apply 30% Entanglement"
				2:
					return "Fruit lose 40% less momentum against Entangled enemies"
				3:
					return "Fully Entangled enemies take 25% more Fruit collision damage"
				4:
					return "Fresh Fruit Green ensnares 50% faster for 4s"
				5:
					return "Terminal Fruit apply 60% Entanglement and full outward Repulsion"
		PhaseBProgression.UpgradeId.EVOLUTION_ORCHARD:
			match rank:
				1:
					return "Every fourth terminal raises a Fruit sapling, maximum three"
				2:
					return "Saplings mature nearby Green 30% faster and regrow a little control"
				3:
					return "Normal releases distribute their unchanged Fruit count among saplings"
				4:
					return "Unsupported saplings stay dormant 5s and reactivate if Green returns"
				5:
					return "Every second release adds one Fruit per active sapling, maximum three"
		PhaseBProgression.UpgradeId.EVOLUTION_GRAFT:
			match rank:
				1:
					return "A 4+ Cutting release grafts the next Fruit for +3% damage each (max 12)"
				2:
					return "Grafted Fruit gain +2% Green area per Cutting (max 24%)"
				3:
					return "A graft of 8+ Cuttings loses 40% less momentum"
				4:
					return "A graft of 12+ Cuttings affects every Fruit in the next release"
				5:
					return "A full 16-Cutting release guarantees a +50% Prize Fruit"
	return ""


func is_pair_evolution_draftable() -> bool:
	return (
		evolution_status == PhaseBProgression.EvolutionStatus.READY
		and get_pair_evolution_id() != PhaseBProgression.EvolutionId.NONE
	)


func grant_evolution_if_ready() -> bool:
	if evolution_status != PhaseBProgression.EvolutionStatus.READY:
		return false
	active_evolution = get_pair_evolution_id()
	if active_evolution == PhaseBProgression.EvolutionId.NONE:
		return false
	evolution_status = PhaseBProgression.EvolutionStatus.EVOLVED
	evolution_changed.emit(evolution_status)
	return true


static func get_evolution_name(evolution_id: int) -> String:
	match evolution_id:
		PhaseBProgression.EvolutionId.SUPER_BLOOM:
			return "SUPER BLOOM"
		PhaseBProgression.EvolutionId.BRIAR_PODS:
			return "BRIAR PODS"
		PhaseBProgression.EvolutionId.THORNBURST:
			return "THORNBURST"
		PhaseBProgression.EvolutionId.SEED_BANK:
			return "SEED BANK"
		PhaseBProgression.EvolutionId.FLOWERING_SEASON:
			return "FLOWERING SEASON"
		PhaseBProgression.EvolutionId.OLD_GROWTH:
			return "OLD GROWTH"
		PhaseBProgression.EvolutionId.PIONEER:
			return "PIONEER"
		PhaseBProgression.EvolutionId.REBOUND:
			return "REBOUND"
		PhaseBProgression.EvolutionId.DEADFALL:
			return "DEADFALL"
		PhaseBProgression.EvolutionId.COPPICING:
			return "COPPICING"
		PhaseBProgression.EvolutionId.INOCULATOR:
			return "INOCULATOR"
		PhaseBProgression.EvolutionId.BURSTBLOOM:
			return "BURSTBLOOM"
		PhaseBProgression.EvolutionId.HEDGE_BATTERY:
			return "HEDGE BATTERY"
		PhaseBProgression.EvolutionId.ROOTSTOCK:
			return "ROOTSTOCK"
		PhaseBProgression.EvolutionId.DEADHEADING:
			return "DEADHEADING"
		PhaseBProgression.EvolutionId.THORNWHIP:
			return "THORNWHIP"
		PhaseBProgression.EvolutionId.BURDOCK:
			return "BURDOCK"
		PhaseBProgression.EvolutionId.MYCELIAL_VINE:
			return "MYCELIAL VINE"
		PhaseBProgression.EvolutionId.WISTERIA:
			return "WISTERIA"
		PhaseBProgression.EvolutionId.BRIAR_CANE:
			return "BRIAR CANE"
		PhaseBProgression.EvolutionId.HEARTWOOD:
			return "HEARTWOOD"
		PhaseBProgression.EvolutionId.ESPALIER:
			return "ESPALIER"
		PhaseBProgression.EvolutionId.GOURDVINE:
			return "GOURDVINE"
		PhaseBProgression.EvolutionId.ROT:
			return "ROT"
		PhaseBProgression.EvolutionId.OVERRIPE:
			return "OVERRIPE"
		PhaseBProgression.EvolutionId.DURIAN:
			return "DURIAN"
		PhaseBProgression.EvolutionId.ORCHARD:
			return "ORCHARD"
		PhaseBProgression.EvolutionId.GRAFT:
			return "GRAFT"
	return "NO EVOLUTION"


static func get_evolution_description(evolution_id: int) -> String:
	match evolution_id:
		PhaseBProgression.EvolutionId.SUPER_BLOOM:
			return "Germinating Seeds arm a Bloom that can chain into more Seeds."
		PhaseBProgression.EvolutionId.BRIAR_PODS:
			return "Germinating Seeds raise temporary thorn perimeters."
		PhaseBProgression.EvolutionId.THORNBURST:
			return "Blooms harvest the Bramble they claim into cascading Briar Traps."
		PhaseBProgression.EvolutionId.SEED_BANK:
			return "Mature ground banks Seeds and drops them onto the mob as bursts."
		PhaseBProgression.EvolutionId.FLOWERING_SEASON:
			return "Mature ground builds toward mass flowerings that spend maturity for Blooms."
		PhaseBProgression.EvolutionId.OLD_GROWTH:
			return "Entangled enemies on ancient ground trigger chaining root eruptions."
		PhaseBProgression.EvolutionId.PIONEER:
			return "Pruned Ground fills with dormant Seeds that all germinate together."
		PhaseBProgression.EvolutionId.REBOUND:
			return "Green collapses into a Bloom before it detonates, then explodes outward."
		PhaseBProgression.EvolutionId.DEADFALL:
			return "Pruning thorned Green turns its Bramble into a storm of spikes."
		PhaseBProgression.EvolutionId.COPPICING:
			return "Mature ground yields far more Cuttings and grows back fast."
		PhaseBProgression.EvolutionId.INOCULATOR:
			return "Thistle volleys inoculate enemies with Spore and rupture completed infections."
		PhaseBProgression.EvolutionId.BURSTBLOOM:
			return "Blooms charge supported Thistles with one explosive Bloomshot per firing event."
		PhaseBProgression.EvolutionId.HEDGE_BATTERY:
			return "Thistle volleys build Entanglement and relay fire through pinned enemies."
		PhaseBProgression.EvolutionId.ROOTSTOCK:
			return "Mature support hardens periodic thorns into piercing network salvos."
		PhaseBProgression.EvolutionId.DEADHEADING:
			return "Intentional Pruning releases command every Thistle to fire together."
		PhaseBProgression.EvolutionId.THORNWHIP:
			return "Thistle heads mount along the Vine and fire through every sweep sector."
		PhaseBProgression.EvolutionId.BURDOCK:
			return "Each Fruit carries a firing Thistle and plants temporary artillery at its end."
		PhaseBProgression.EvolutionId.MYCELIAL_VINE:
			return "Vine sweeps spread Spore and collapse infections struck by the apical tip."
		PhaseBProgression.EvolutionId.WISTERIA:
			return "Normal Blooms arm a blossom sequence along the next Vine sweep."
		PhaseBProgression.EvolutionId.BRIAR_CANE:
			return "Vine sweeps Entangle and repel enemies whether or not the sweep stands on Green."
		PhaseBProgression.EvolutionId.HEARTWOOD:
			return "Every fifth Vine sweep grows into a heavy, long-reaching root echo."
		PhaseBProgression.EvolutionId.ESPALIER:
			return "Pruning releases train Cuttings into the Vine's forward sweep sector."
		PhaseBProgression.EvolutionId.GOURDVINE:
			return "Fruit ride the outer Vine arc before launching with stored sweep momentum."
		PhaseBProgression.EvolutionId.ROT:
			return "Fruit spread Spore through collisions, trails, and terminal rupture."
		PhaseBProgression.EvolutionId.OVERRIPE:
			return "Fruit burst into Bloom pressure, droplets, and short-lived germinating fragments."
		PhaseBProgression.EvolutionId.DURIAN:
			return "Fruit accumulate Entanglement and finish rolls with a repelling thorn burst."
		PhaseBProgression.EvolutionId.ORCHARD:
			return "Completed rolls raise saplings that mature Green and join later releases."
		PhaseBProgression.EvolutionId.GRAFT:
			return "Pruning releases graft stored Cuttings into the next Fruit crop."
	return "Master one line from each selected path to unlock a pairing."


static func get_upgrade_evolution(upgrade_id: int) -> int:
	match upgrade_id:
		PhaseBProgression.UpgradeId.EVOLUTION_FLORAL_CASCADE:
			return PhaseBProgression.EvolutionId.SUPER_BLOOM
		PhaseBProgression.UpgradeId.EVOLUTION_TANGLEBURST:
			return PhaseBProgression.EvolutionId.BRIAR_PODS
		PhaseBProgression.UpgradeId.EVOLUTION_SEED_RESERVE:
			return PhaseBProgression.EvolutionId.SEED_BANK
		PhaseBProgression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD:
			return PhaseBProgression.EvolutionId.THORNBURST
		PhaseBProgression.UpgradeId.EVOLUTION_SEASONAL_SURGE:
			return PhaseBProgression.EvolutionId.FLOWERING_SEASON
		PhaseBProgression.UpgradeId.EVOLUTION_SECOND_FLUSH:
			return PhaseBProgression.EvolutionId.PIONEER
		PhaseBProgression.UpgradeId.EVOLUTION_COMPRESSION:
			return PhaseBProgression.EvolutionId.REBOUND
		PhaseBProgression.UpgradeId.EVOLUTION_SPLINTERSTORM:
			return PhaseBProgression.EvolutionId.DEADFALL
		PhaseBProgression.UpgradeId.EVOLUTION_STOOL_REGROWTH:
			return PhaseBProgression.EvolutionId.COPPICING
		PhaseBProgression.UpgradeId.EVOLUTION_ANCIENT_FURY:
			return PhaseBProgression.EvolutionId.OLD_GROWTH
		PhaseBProgression.UpgradeId.EVOLUTION_INOCULATOR:
			return PhaseBProgression.EvolutionId.INOCULATOR
		PhaseBProgression.UpgradeId.EVOLUTION_BURSTBLOOM:
			return PhaseBProgression.EvolutionId.BURSTBLOOM
		PhaseBProgression.UpgradeId.EVOLUTION_HEDGE_BATTERY:
			return PhaseBProgression.EvolutionId.HEDGE_BATTERY
		PhaseBProgression.UpgradeId.EVOLUTION_ROOTSTOCK:
			return PhaseBProgression.EvolutionId.ROOTSTOCK
		PhaseBProgression.UpgradeId.EVOLUTION_DEADHEADING:
			return PhaseBProgression.EvolutionId.DEADHEADING
		PhaseBProgression.UpgradeId.EVOLUTION_THORNWHIP:
			return PhaseBProgression.EvolutionId.THORNWHIP
		PhaseBProgression.UpgradeId.EVOLUTION_BURDOCK:
			return PhaseBProgression.EvolutionId.BURDOCK
		PhaseBProgression.UpgradeId.EVOLUTION_MYCELIAL_VINE:
			return PhaseBProgression.EvolutionId.MYCELIAL_VINE
		PhaseBProgression.UpgradeId.EVOLUTION_WISTERIA:
			return PhaseBProgression.EvolutionId.WISTERIA
		PhaseBProgression.UpgradeId.EVOLUTION_BRIAR_CANE:
			return PhaseBProgression.EvolutionId.BRIAR_CANE
		PhaseBProgression.UpgradeId.EVOLUTION_HEARTWOOD:
			return PhaseBProgression.EvolutionId.HEARTWOOD
		PhaseBProgression.UpgradeId.EVOLUTION_ESPALIER:
			return PhaseBProgression.EvolutionId.ESPALIER
		PhaseBProgression.UpgradeId.EVOLUTION_GOURDVINE:
			return PhaseBProgression.EvolutionId.GOURDVINE
		PhaseBProgression.UpgradeId.EVOLUTION_ROT:
			return PhaseBProgression.EvolutionId.ROT
		PhaseBProgression.UpgradeId.EVOLUTION_OVERRIPE:
			return PhaseBProgression.EvolutionId.OVERRIPE
		PhaseBProgression.UpgradeId.EVOLUTION_DURIAN:
			return PhaseBProgression.EvolutionId.DURIAN
		PhaseBProgression.UpgradeId.EVOLUTION_ORCHARD:
			return PhaseBProgression.EvolutionId.ORCHARD
		PhaseBProgression.UpgradeId.EVOLUTION_GRAFT:
			return PhaseBProgression.EvolutionId.GRAFT
	return PhaseBProgression.EvolutionId.NONE
