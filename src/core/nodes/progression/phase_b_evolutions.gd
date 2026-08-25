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
## Entanglement above which germination roots an enemy at Tangleburst level two.
@export_range(0.0, 1.0, 0.01) var tangleburst_root_threshold := 0.70
## Root duration germination applies at Tangleburst level two.
@export_range(0.0, 3.0, 0.05) var tangleburst_root_seconds := 0.35
## Pixels a germinating Seed pulls nearby enemies inward at Tangleburst level three.
@export_range(0.0, 200.0, 1.0) var tangleburst_pull_pixels := 26.0
## Germinating Seeds between each mass Briar pulse at Tangleburst level five.
@export_range(1, 12, 1) var tangleburst_pulse_cadence := 5
## Share of a mass Briar pulse's Entanglement applied to elites.
@export_range(0.0, 1.0, 0.01) var tangleburst_elite_share := 0.50
## Share of a mass Briar pulse's Entanglement applied to bosses.
@export_range(0.0, 1.0, 0.01) var tangleburst_boss_share := 0.20
## Extra Seed-Bank storage per Expanded Reserve rank, at levels one and four.
@export_range(0.0, 1.0, 0.01) var seed_reserve_capacity_per_rank := 0.20
## Faster dormant-Seed accumulation at Seed Reserve level two.
@export_range(0.0, 1.0, 0.01) var seed_reserve_rate_bonus := 0.15
## Maturity a banked Seed inherits at Seed Reserve level three.
@export_range(0.0, 1.0, 0.01) var seed_reserve_maturity_inheritance := 0.20
## Germination Seasons between each Mast Year second wave at Seed Reserve level five.
@export_range(1, 12, 1) var seed_reserve_mast_cadence := 3
## Share of the first wave's Seeds released by a Mast Year second wave.
@export_range(0.0, 1.0, 0.01) var seed_reserve_mast_share := 0.50
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
## Ensnare-rate bonus Aggressive Growth leaves on freshly claimed Seed ground.
@export_range(0.0, 4.0, 0.05) var tangleburst_ensnare_bonus := 0.50
## Seconds that bonus lingers on the new ground.
@export_range(0.1, 20.0, 0.1) var tangleburst_ensnare_seconds := 3.0
## Radius multiple of the mass Briar pulse at Tangleburst level five.
@export_range(1.0, 6.0, 0.05) var tangleburst_pulse_radius_scale := 2.20

@export_group("Seed Bank")
## Dormant Seeds banked per second for each percentage point of Mature Green.
@export_range(0.0, 1.0, 0.001) var seed_bank_storage_per_mature_percent := 0.006
## Dormant Seeds the ecosystem can hold before banking stops.
@export_range(1.0, 60.0, 0.5) var seed_bank_capacity := 9.0
## Dormant Seeds required before a Germination Season fires.
@export_range(1.0, 40.0, 0.5) var germination_season_threshold := 5.0
## Highest number of Seeds one Germination Season may release at once.
@export_range(1, 40, 1) var germination_season_maximum_seeds := 12
## Arena pixels between the anchors a Germination Season spreads its Seeds across.
@export_range(20.0, 400.0, 5.0) var germination_season_spread_pixels := 150.0
## Seconds between a Mast Year's first and second germination wave.
@export_range(0.1, 6.0, 0.05) var germination_season_mast_delay := 1.5
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
	# Only the first two paths make the pairing. The support path never joins it,
	# so no second Evolution and no three-way pairing can ever form.
	return (
		path_id == progression.primary_path
		or path_id == progression.secondary_path
	)


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


func get_pair_evolution_id() -> int:
	# A claimed pairing is frozen: the support path chosen afterwards must never
	# re-roll which Evolution the run holds.
	if evolution_status == PhaseBProgression.EvolutionStatus.EVOLVED:
		return active_evolution
	if not progression.has_primary_path() or not progression.has_secondary_path():
		return PhaseBProgression.EvolutionId.NONE
	if is_evolution_path(PhaseBProgression.PathId.SPORE) and is_evolution_path(PhaseBProgression.PathId.BLOOM):
		return PhaseBProgression.EvolutionId.SUPER_BLOOM
	if is_evolution_path(PhaseBProgression.PathId.SPORE) and is_evolution_path(PhaseBProgression.PathId.BRAMBLE):
		return PhaseBProgression.EvolutionId.BRIAR_PODS
	if is_evolution_path(PhaseBProgression.PathId.BLOOM) and is_evolution_path(PhaseBProgression.PathId.BRAMBLE):
		return PhaseBProgression.EvolutionId.THORNBURST
	if is_evolution_path(PhaseBProgression.PathId.SPORE) and is_evolution_path(PhaseBProgression.PathId.ROOT):
		return PhaseBProgression.EvolutionId.SEED_BANK
	if is_evolution_path(PhaseBProgression.PathId.BLOOM) and is_evolution_path(PhaseBProgression.PathId.ROOT):
		return PhaseBProgression.EvolutionId.FLOWERING_SEASON
	if is_evolution_path(PhaseBProgression.PathId.BRAMBLE) and is_evolution_path(PhaseBProgression.PathId.ROOT):
		return PhaseBProgression.EvolutionId.OLD_GROWTH
	if is_evolution_path(PhaseBProgression.PathId.SPORE) and is_evolution_path(PhaseBProgression.PathId.PRUNING):
		return PhaseBProgression.EvolutionId.PIONEER
	if is_evolution_path(PhaseBProgression.PathId.BLOOM) and is_evolution_path(PhaseBProgression.PathId.PRUNING):
		return PhaseBProgression.EvolutionId.REBOUND
	if is_evolution_path(PhaseBProgression.PathId.BRAMBLE) and is_evolution_path(PhaseBProgression.PathId.PRUNING):
		return PhaseBProgression.EvolutionId.DEADFALL
	if is_evolution_path(PhaseBProgression.PathId.ROOT) and is_evolution_path(PhaseBProgression.PathId.PRUNING):
		return PhaseBProgression.EvolutionId.COPPICING
	return PhaseBProgression.EvolutionId.NONE


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
					return "Grasping Shoots: germination roots already-Entangled enemies"
				3:
					return "Constricting Growth: germination drags nearby enemies inward"
				4:
					return "Aggressive Growth: fresh Seed ground ensnares far faster"
				5:
					return "Mass Entanglement: every %d Seeds pin a whole mob" % (
						tangleburst_pulse_cadence
					)
		PhaseBProgression.UpgradeId.EVOLUTION_SEED_RESERVE:
			match rank:
				1:
					return "Expanded Reserve: +%d%% dormant Seed storage" % roundi(
						seed_reserve_capacity_per_rank * 100.0
					)
				2:
					return "Heavy Seeding: Seeds bank %d%% faster" % roundi(
						seed_reserve_rate_bonus * 100.0
					)
				3:
					return "Established Stock: banked Seeds inherit %d%% maturity" % (
						roundi(seed_reserve_maturity_inheritance * 100.0)
					)
				4:
					return "Expanded Reserve II: another +%d%% storage" % roundi(
						seed_reserve_capacity_per_rank * 100.0
					)
				5:
					return "Mast Year: every %d Seasons germinate twice" % (
						seed_reserve_mast_cadence
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
			return "Mature borders periodically produce Seeds that inherit their maturity."
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
	return PhaseBProgression.EvolutionId.NONE
