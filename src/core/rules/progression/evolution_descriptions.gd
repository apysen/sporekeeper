class_name EvolutionDescriptions
extends RefCounted

## Every line of text the interface prints about an Evolution: its name, what it is,
## which line it grants, and what each rank of that line actually does.
##
## Four of the five are static, because a name is a name whatever the run is doing.
## `get_rank_description` is not: an Evolution rank is described in the same numbers
## the Evolution is tuned with, so it reads them off the node rather than restating
## them - a hover that quoted its own copy of a figure would drift the first time the
## tuning changed.
##
## That is the arrangement `UpgradeDescriptions` already uses next door, and the same
## rule applies here: every method is a read, and none of them may change anything.

var _evolutions: Evolutions


## Hands over the node the rank text is tuned from. The director calls this once its
## own exports are set.
func configure(evolutions: Evolutions) -> void:
	_evolutions = evolutions


func get_rank_description(upgrade_id: int, rank: int) -> String:
	# Every rank of an Evolution line does something different, so the draft names
	# the rank it is about to buy rather than a per-level average.
	match upgrade_id:
		Progression.UpgradeId.EVOLUTION_FLORAL_CASCADE:
			match rank:
				1:
					return "Cascade Force: chained Blooms keep +%d%% Force" % roundi(
						_evolutions.floral_cascade_force_per_rank * 100.0
					)
				2:
					return "Deep Cascade: chains propagate one generation further"
				3:
					return "Forced Germination: every %d Super Blooms germinate a Seed" % (
						_evolutions.floral_cascade_germination_cadence
					)
				4:
					return "Cascade Force II: another +%d%% chained Bloom Force" % roundi(
						_evolutions.floral_cascade_force_per_rank * 100.0
					)
				5:
					return "Grand Bloom: every %d Super Blooms erupt at %dx scale" % [
						_evolutions.floral_cascade_grand_cadence,
						roundi(_evolutions.floral_cascade_grand_scale),
					]
		Progression.UpgradeId.EVOLUTION_TANGLEBURST:
			match rank:
				1:
					return "Tangled Germination: germination applies %d%% Entanglement" % (
						roundi(_evolutions.tangleburst_entanglement * 100.0)
					)
				2:
					return "Grasping Shoots: germination Ensnares already-Entangled enemies"
				3:
					return "Constricting Growth: germination drags nearby enemies inward"
				4:
					return "Aggressive Growth: fresh Seed ground ensnares far faster"
				5:
					return "Mass Entanglement: every %d Seeds pin a whole mob and seed it with %d%% Spore" % [
						_evolutions.tangleburst_pulse_cadence,
						roundi(_evolutions.tangleburst_pulse_spore * 100.0),
					]
		Progression.UpgradeId.EVOLUTION_SEED_RESERVE:
			match rank:
				1:
					return "Expanded Reserve: +%d%% Seed Bank capacity" % roundi(
						_evolutions.seed_reserve_capacity_per_rank * 100.0
					)
				2:
					return "Heavy Seeding: Seeds bank %d%% faster" % roundi(
						_evolutions.seed_reserve_rate_bonus * 100.0
					)
				3:
					return "Rootburst: Season bursts deal +%d%% damage at +%d%% radius" % [
						roundi(_evolutions.rootburst_damage_bonus * 100.0),
						roundi(_evolutions.rootburst_radius_bonus * 100.0),
					]
				4:
					return "Fungal Reserve: every %d Seeds released raise a Fruiting Body that clouds at once" % (
						_evolutions.fungal_reserve_seeds
					)
				5:
					return "Mast Year: every Season fires a second full wave %.1fs later" % (
						_evolutions.germination_season_mast_delay
					)
		Progression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD:
			match rank:
				1:
					return "Packed Thorns: +%d%% Briar Traps per harvest" % roundi(
						_evolutions.briar_payload_trap_yield * 100.0
					)
				2:
					return "Sensitive Traps: +%d%% trigger radius" % roundi(
						_evolutions.briar_payload_trigger_bonus * 100.0
					)
				3:
					return "Barbed Blast: trap blasts apply %d%% Entanglement" % roundi(
						_evolutions.briar_payload_entanglement * 100.0
					)
				4:
					return "Chain Fuse: +%d%% trap-to-trap chain range" % roundi(
						_evolutions.briar_payload_chain_bonus * 100.0
					)
				5:
					return "Briar Heart: every %d traps becomes a repeating blast" % (
						_evolutions.briar_payload_heart_cadence
					)
		Progression.UpgradeId.EVOLUTION_SEASONAL_SURGE:
			match rank:
				1:
					return "Spring Pressure: +%d%% Flowering Bloom Force" % roundi(
						_evolutions.seasonal_surge_force_per_rank * 100.0
					)
				2:
					return "Encroachment: +%d%% conversion against hostile ground" % (
						roundi(_evolutions.seasonal_surge_conversion_bonus * 100.0)
					)
				3:
					return "Distributed Flowering: Blooms spread across the frontier"
				4:
					return "Spring Pressure II: another +%d%% Bloom Force" % roundi(
						_evolutions.seasonal_surge_force_per_rank * 100.0
					)
				5:
					return "Second Spring: %d Echo Blooms follow every Season" % (
						_evolutions.seasonal_surge_echo_count
					)
		Progression.UpgradeId.EVOLUTION_ANCIENT_FURY:
			match rank:
				1:
					return "Deep Eruption: +%d%% eruption radius" % roundi(
						_evolutions.ancient_fury_radius_bonus * 100.0
					)
				2:
					return "Thorned Roots: eruptions Entangle survivors"
				3:
					return "Root Cascade: eruption kills erupt again at %d%% damage" % (
						roundi(_evolutions.ancient_fury_chain_damage_share * 100.0)
					)
				4:
					return "Restless Forest: erupts at %d%% Entanglement" % roundi(
						_evolutions.ancient_fury_trigger_threshold * 100.0
					)
				5:
					return "Forest Awakening: %d Entangled enemies wake %d eruptions" % [
						_evolutions.ancient_fury_awakening_enemies,
						_evolutions.ancient_fury_awakening_eruptions,
					]
		Progression.UpgradeId.EVOLUTION_SECOND_FLUSH:
			match rank:
				1:
					return "Dense Reseeding: +%d%% Seeds buried in cut ground" % roundi(
						_evolutions.second_flush_seed_bonus * 100.0
					)
				2:
					return "Rapid Germination: buried Seeds erupt %d%% sooner" % roundi(
						_evolutions.second_flush_germination_cut * 100.0
					)
				3:
					return "Fertile Cut: Seeds on cut ground carry +%d%% Growth Mass" % roundi(
						_evolutions.second_flush_pruned_mass_bonus * 100.0
					)
				4:
					return "Blood and Soil: Cutting kills bury up to %d more Seeds" % (
						_evolutions.second_flush_kill_seed_cap
					)
				5:
					return "Second Flush: every %d eruptions a second wave at %d%%" % [
						_evolutions.second_flush_wave_cadence,
						roundi(_evolutions.second_flush_wave_share * 100.0),
					]
		Progression.UpgradeId.EVOLUTION_COMPRESSION:
			match rank:
				1:
					return "Efficient Compression: +%d%% Force per cell collapsed" % roundi(
						_evolutions.compression_force_bonus * 100.0
					)
				2:
					return "Elastic Growth: the collapsed ground reclaims far faster"
				3:
					return "Inward Collapse: the compression drags enemies in first"
				4:
					return "Efficient Compression II: another +%d%% Force per cell" % roundi(
						_evolutions.compression_force_bonus * 100.0
					)
				5:
					return "Elastic Rebound: a second wave at %d%% Force after %.2fs" % [
						roundi(_evolutions.compression_second_wave_share * 100.0),
						_evolutions.compression_second_wave_delay,
					]
		Progression.UpgradeId.EVOLUTION_SPLINTERSTORM:
			match rank:
				1:
					return "Thorn Harvest: +%d%% Cuttings from thorned Green" % roundi(
						_evolutions.splinterstorm_yield_bonus * 100.0
					)
				2:
					return "Piercing Splinters: +%d Pierce at %d%% damage" % [
						_evolutions.splinterstorm_extra_pierce,
						roundi(_evolutions.splinterstorm_pierce_falloff * 100.0),
					]
				3:
					return "Shatter: Cuttings split on fully Entangled enemies"
				4:
					return "Thorn Harvest II: another +%d%% thorn Cuttings" % roundi(
						_evolutions.splinterstorm_yield_bonus * 100.0
					)
				5:
					return "Deadfall Volley: every cycle fires %d heavy spikes" % (
						_evolutions.splinterstorm_volley_spikes
					)
		Progression.UpgradeId.EVOLUTION_STOOL_REGROWTH:
			match rank:
				1:
					return "Mature Harvest: +%d%% Cuttings from Mature ground" % roundi(
						_evolutions.stool_regrowth_yield_bonus * 100.0
					)
				2:
					return "Vigorous Regrowth: cut Mature ground returns far faster"
				3:
					return "Root Memory: regrowth keeps %d%% of its former maturity" % roundi(
						_evolutions.stool_regrowth_memory_share * 100.0
					)
				4:
					return "Mature Harvest II: another +%d%% Mature Cuttings" % roundi(
						_evolutions.stool_regrowth_yield_bonus * 100.0
					)
				5:
					return "Second Harvest: regrowth releases a %d%% second volley" % roundi(
						_evolutions.stool_regrowth_second_share * 100.0
					)
		Progression.UpgradeId.EVOLUTION_INOCULATOR:
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
		Progression.UpgradeId.EVOLUTION_BURSTBLOOM:
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
		Progression.UpgradeId.EVOLUTION_HEDGE_BATTERY:
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
		Progression.UpgradeId.EVOLUTION_ROOTSTOCK:
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
		Progression.UpgradeId.EVOLUTION_DEADHEADING:
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
		Progression.UpgradeId.EVOLUTION_THORNWHIP:
			match rank:
				1:
					return "Two mounted Thistle heads each drive one heavy thorn per sweep"
				2:
					return "Mount a third Thistle head"
				3:
					return "The outer head inherits Apical Dominance"
				4:
					return "Mount a fourth Thistle head"
				5:
					return "Every mounted head fires twice per sweep"
		Progression.UpgradeId.EVOLUTION_BURDOCK:
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
		Progression.UpgradeId.EVOLUTION_MYCELIAL_VINE:
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
		Progression.UpgradeId.EVOLUTION_WISTERIA:
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
		Progression.UpgradeId.EVOLUTION_BRIAR_CANE:
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
		Progression.UpgradeId.EVOLUTION_HEARTWOOD:
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
		Progression.UpgradeId.EVOLUTION_ESPALIER:
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
		Progression.UpgradeId.EVOLUTION_GOURDVINE:
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
		Progression.UpgradeId.EVOLUTION_ROT:
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
		Progression.UpgradeId.EVOLUTION_OVERRIPE:
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
		Progression.UpgradeId.EVOLUTION_DURIAN:
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
		Progression.UpgradeId.EVOLUTION_ORCHARD:
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
		Progression.UpgradeId.EVOLUTION_GRAFT:
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



static func upgrade_id_for(evolution_id: int) -> int:
	match evolution_id:
		Progression.EvolutionId.SUPER_BLOOM:
			return Progression.UpgradeId.EVOLUTION_FLORAL_CASCADE
		Progression.EvolutionId.BRIAR_PODS:
			return Progression.UpgradeId.EVOLUTION_TANGLEBURST
		Progression.EvolutionId.SEED_BANK:
			return Progression.UpgradeId.EVOLUTION_SEED_RESERVE
		Progression.EvolutionId.THORNBURST:
			return Progression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD
		Progression.EvolutionId.FLOWERING_SEASON:
			return Progression.UpgradeId.EVOLUTION_SEASONAL_SURGE
		Progression.EvolutionId.OLD_GROWTH:
			return Progression.UpgradeId.EVOLUTION_ANCIENT_FURY
		Progression.EvolutionId.PIONEER:
			return Progression.UpgradeId.EVOLUTION_SECOND_FLUSH
		Progression.EvolutionId.REBOUND:
			return Progression.UpgradeId.EVOLUTION_COMPRESSION
		Progression.EvolutionId.DEADFALL:
			return Progression.UpgradeId.EVOLUTION_SPLINTERSTORM
		Progression.EvolutionId.COPPICING:
			return Progression.UpgradeId.EVOLUTION_STOOL_REGROWTH
		Progression.EvolutionId.INOCULATOR:
			return Progression.UpgradeId.EVOLUTION_INOCULATOR
		Progression.EvolutionId.BURSTBLOOM:
			return Progression.UpgradeId.EVOLUTION_BURSTBLOOM
		Progression.EvolutionId.HEDGE_BATTERY:
			return Progression.UpgradeId.EVOLUTION_HEDGE_BATTERY
		Progression.EvolutionId.ROOTSTOCK:
			return Progression.UpgradeId.EVOLUTION_ROOTSTOCK
		Progression.EvolutionId.DEADHEADING:
			return Progression.UpgradeId.EVOLUTION_DEADHEADING
		Progression.EvolutionId.THORNWHIP:
			return Progression.UpgradeId.EVOLUTION_THORNWHIP
		Progression.EvolutionId.BURDOCK:
			return Progression.UpgradeId.EVOLUTION_BURDOCK
		Progression.EvolutionId.MYCELIAL_VINE:
			return Progression.UpgradeId.EVOLUTION_MYCELIAL_VINE
		Progression.EvolutionId.WISTERIA:
			return Progression.UpgradeId.EVOLUTION_WISTERIA
		Progression.EvolutionId.BRIAR_CANE:
			return Progression.UpgradeId.EVOLUTION_BRIAR_CANE
		Progression.EvolutionId.HEARTWOOD:
			return Progression.UpgradeId.EVOLUTION_HEARTWOOD
		Progression.EvolutionId.ESPALIER:
			return Progression.UpgradeId.EVOLUTION_ESPALIER
		Progression.EvolutionId.GOURDVINE:
			return Progression.UpgradeId.EVOLUTION_GOURDVINE
		Progression.EvolutionId.ROT:
			return Progression.UpgradeId.EVOLUTION_ROT
		Progression.EvolutionId.OVERRIPE:
			return Progression.UpgradeId.EVOLUTION_OVERRIPE
		Progression.EvolutionId.DURIAN:
			return Progression.UpgradeId.EVOLUTION_DURIAN
		Progression.EvolutionId.ORCHARD:
			return Progression.UpgradeId.EVOLUTION_ORCHARD
		Progression.EvolutionId.GRAFT:
			return Progression.UpgradeId.EVOLUTION_GRAFT
	return -1


static func evolution_name(evolution_id: int) -> String:
	match evolution_id:
		Progression.EvolutionId.SUPER_BLOOM:
			return "SUPER BLOOM"
		Progression.EvolutionId.BRIAR_PODS:
			return "BRIAR PODS"
		Progression.EvolutionId.THORNBURST:
			return "THORNBURST"
		Progression.EvolutionId.SEED_BANK:
			return "SEED BANK"
		Progression.EvolutionId.FLOWERING_SEASON:
			return "FLOWERING SEASON"
		Progression.EvolutionId.OLD_GROWTH:
			return "OLD GROWTH"
		Progression.EvolutionId.PIONEER:
			return "PIONEER"
		Progression.EvolutionId.REBOUND:
			return "REBOUND"
		Progression.EvolutionId.DEADFALL:
			return "DEADFALL"
		Progression.EvolutionId.COPPICING:
			return "COPPICING"
		Progression.EvolutionId.INOCULATOR:
			return "INOCULATOR"
		Progression.EvolutionId.BURSTBLOOM:
			return "BURSTBLOOM"
		Progression.EvolutionId.HEDGE_BATTERY:
			return "HEDGE BATTERY"
		Progression.EvolutionId.ROOTSTOCK:
			return "ROOTSTOCK"
		Progression.EvolutionId.DEADHEADING:
			return "DEADHEADING"
		Progression.EvolutionId.THORNWHIP:
			return "THORNWHIP"
		Progression.EvolutionId.BURDOCK:
			return "BURDOCK"
		Progression.EvolutionId.MYCELIAL_VINE:
			return "MYCELIAL VINE"
		Progression.EvolutionId.WISTERIA:
			return "WISTERIA"
		Progression.EvolutionId.BRIAR_CANE:
			return "BRIAR CANE"
		Progression.EvolutionId.HEARTWOOD:
			return "HEARTWOOD"
		Progression.EvolutionId.ESPALIER:
			return "ESPALIER"
		Progression.EvolutionId.GOURDVINE:
			return "GOURDVINE"
		Progression.EvolutionId.ROT:
			return "ROT"
		Progression.EvolutionId.OVERRIPE:
			return "OVERRIPE"
		Progression.EvolutionId.DURIAN:
			return "DURIAN"
		Progression.EvolutionId.ORCHARD:
			return "ORCHARD"
		Progression.EvolutionId.GRAFT:
			return "GRAFT"
	return "NO EVOLUTION"


static func evolution_description(evolution_id: int) -> String:
	match evolution_id:
		Progression.EvolutionId.SUPER_BLOOM:
			return "Germinating Seeds arm a Bloom that can chain into more Seeds."
		Progression.EvolutionId.BRIAR_PODS:
			return "Germinating Seeds raise temporary thorn perimeters."
		Progression.EvolutionId.THORNBURST:
			return "Blooms harvest the Bramble they claim into cascading Briar Traps."
		Progression.EvolutionId.SEED_BANK:
			return "Mature ground banks Seeds and drops them onto the mob as bursts."
		Progression.EvolutionId.FLOWERING_SEASON:
			return "Mature ground builds toward mass flowerings that spend maturity for Blooms."
		Progression.EvolutionId.OLD_GROWTH:
			return "Entangled enemies on ancient ground trigger chaining root eruptions."
		Progression.EvolutionId.PIONEER:
			return "Pruned Ground fills with dormant Seeds that all germinate together."
		Progression.EvolutionId.REBOUND:
			return "Green collapses into a Bloom before it detonates, then explodes outward."
		Progression.EvolutionId.DEADFALL:
			return "Pruning thorned Green turns its Bramble into a storm of spikes."
		Progression.EvolutionId.COPPICING:
			return "Mature ground yields far more Cuttings and grows back fast."
		Progression.EvolutionId.INOCULATOR:
			return "Thistle volleys inoculate enemies with Spore and rupture completed infections."
		Progression.EvolutionId.BURSTBLOOM:
			return "Blooms charge supported Thistles with one explosive Bloomshot per firing event."
		Progression.EvolutionId.HEDGE_BATTERY:
			return "Thistle volleys build Entanglement and relay fire through pinned enemies."
		Progression.EvolutionId.ROOTSTOCK:
			return "Mature support hardens periodic thorns into piercing network salvos."
		Progression.EvolutionId.DEADHEADING:
			return "Intentional Pruning releases command every Thistle to fire together."
		Progression.EvolutionId.THORNWHIP:
			return "Thistle heads mount along the Vine and fire through every sweep sector."
		Progression.EvolutionId.BURDOCK:
			return "Each Fruit carries a firing Thistle and plants temporary artillery at its end."
		Progression.EvolutionId.MYCELIAL_VINE:
			return "Vine sweeps spread Spore and collapse infections struck by the apical tip."
		Progression.EvolutionId.WISTERIA:
			return "Normal Blooms arm a blossom sequence along the next Vine sweep."
		Progression.EvolutionId.BRIAR_CANE:
			return "Vine sweeps Entangle and repel enemies whether or not the sweep stands on Green."
		Progression.EvolutionId.HEARTWOOD:
			return "Every fifth Vine sweep grows into a heavy, long-reaching root echo."
		Progression.EvolutionId.ESPALIER:
			return "Pruning releases train Cuttings into the Vine's forward sweep sector."
		Progression.EvolutionId.GOURDVINE:
			return "Fruit ride the outer Vine arc before launching with stored sweep momentum."
		Progression.EvolutionId.ROT:
			return "Fruit spread Spore through collisions, trails, and terminal rupture."
		Progression.EvolutionId.OVERRIPE:
			return "Fruit burst into Bloom pressure, droplets, and short-lived germinating fragments."
		Progression.EvolutionId.DURIAN:
			return "Fruit accumulate Entanglement and finish rolls with a repelling thorn burst."
		Progression.EvolutionId.ORCHARD:
			return "Completed rolls raise saplings that mature Green and join later releases."
		Progression.EvolutionId.GRAFT:
			return "Pruning releases graft stored Cuttings into the next Fruit crop."
	return "Master one line from each selected path to unlock a pairing."


static func evolution_for_upgrade(upgrade_id: int) -> int:
	match upgrade_id:
		Progression.UpgradeId.EVOLUTION_FLORAL_CASCADE:
			return Progression.EvolutionId.SUPER_BLOOM
		Progression.UpgradeId.EVOLUTION_TANGLEBURST:
			return Progression.EvolutionId.BRIAR_PODS
		Progression.UpgradeId.EVOLUTION_SEED_RESERVE:
			return Progression.EvolutionId.SEED_BANK
		Progression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD:
			return Progression.EvolutionId.THORNBURST
		Progression.UpgradeId.EVOLUTION_SEASONAL_SURGE:
			return Progression.EvolutionId.FLOWERING_SEASON
		Progression.UpgradeId.EVOLUTION_SECOND_FLUSH:
			return Progression.EvolutionId.PIONEER
		Progression.UpgradeId.EVOLUTION_COMPRESSION:
			return Progression.EvolutionId.REBOUND
		Progression.UpgradeId.EVOLUTION_SPLINTERSTORM:
			return Progression.EvolutionId.DEADFALL
		Progression.UpgradeId.EVOLUTION_STOOL_REGROWTH:
			return Progression.EvolutionId.COPPICING
		Progression.UpgradeId.EVOLUTION_ANCIENT_FURY:
			return Progression.EvolutionId.OLD_GROWTH
		Progression.UpgradeId.EVOLUTION_INOCULATOR:
			return Progression.EvolutionId.INOCULATOR
		Progression.UpgradeId.EVOLUTION_BURSTBLOOM:
			return Progression.EvolutionId.BURSTBLOOM
		Progression.UpgradeId.EVOLUTION_HEDGE_BATTERY:
			return Progression.EvolutionId.HEDGE_BATTERY
		Progression.UpgradeId.EVOLUTION_ROOTSTOCK:
			return Progression.EvolutionId.ROOTSTOCK
		Progression.UpgradeId.EVOLUTION_DEADHEADING:
			return Progression.EvolutionId.DEADHEADING
		Progression.UpgradeId.EVOLUTION_THORNWHIP:
			return Progression.EvolutionId.THORNWHIP
		Progression.UpgradeId.EVOLUTION_BURDOCK:
			return Progression.EvolutionId.BURDOCK
		Progression.UpgradeId.EVOLUTION_MYCELIAL_VINE:
			return Progression.EvolutionId.MYCELIAL_VINE
		Progression.UpgradeId.EVOLUTION_WISTERIA:
			return Progression.EvolutionId.WISTERIA
		Progression.UpgradeId.EVOLUTION_BRIAR_CANE:
			return Progression.EvolutionId.BRIAR_CANE
		Progression.UpgradeId.EVOLUTION_HEARTWOOD:
			return Progression.EvolutionId.HEARTWOOD
		Progression.UpgradeId.EVOLUTION_ESPALIER:
			return Progression.EvolutionId.ESPALIER
		Progression.UpgradeId.EVOLUTION_GOURDVINE:
			return Progression.EvolutionId.GOURDVINE
		Progression.UpgradeId.EVOLUTION_ROT:
			return Progression.EvolutionId.ROT
		Progression.UpgradeId.EVOLUTION_OVERRIPE:
			return Progression.EvolutionId.OVERRIPE
		Progression.UpgradeId.EVOLUTION_DURIAN:
			return Progression.EvolutionId.DURIAN
		Progression.UpgradeId.EVOLUTION_ORCHARD:
			return Progression.EvolutionId.ORCHARD
		Progression.UpgradeId.EVOLUTION_GRAFT:
			return Progression.EvolutionId.GRAFT
	return Progression.EvolutionId.NONE
