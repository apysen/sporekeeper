class_name PhaseBRelicCatalog
extends RefCounted

## The authored relic catalog: identity, rarity, pool, eligibility, and player
## text for every relic in the run. It is pure data with no scene dependencies,
## so drafting rules, the HUD, and the tests all read the same table.
##
## Relics are permanent, non-levelling rule changes. A relic changes a rule, a
## trigger, targeting, timing, or an interaction; a normal upgrade line is what
## changes a number. Nothing in this file is a percentage of the arena: triggers
## are fixed counters, per-object limits, local density, or absolute territory,
## which is the standing rule for this game's relic design.
##
## Eligibility is expressed as required Mechanics rather than as hard-coded path
## pairs. A synergy relic becomes offerable the moment the run provides both of
## its mechanics, whether that came from the initial pair, the support path, or
## an Evolution, so no separate pool is needed for each of those cases.

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	LEGENDARY,
}

enum Pool {
	## Shared by every element; touches only universal systems.
	UNIVERSAL,
	## Plant's own baseline behaviour: Green, Seeds, maturity.
	ELEMENT,
	## Belongs to one normal Path.
	PATH,
	## Curated cross-mechanic relic.
	SYNERGY,
	## Rules about the Clover machine itself.
	GAMBLING,
}

enum Mechanic {
	SEED,
	BLOOM,
	ENTANGLEMENT,
	MATURE_GREEN,
	ROOT_POTENCY,
	PRUNING_RING,
	PRUNING_CHARGE,
	## Reserved for the optional-objective layer, which the prototype does not
	## have yet. A relic requiring it is authored but never offered, so it turns
	## on by itself the day objectives arrive.
	OPTIONAL_OBJECTIVE,
	## The Clover machine. Baseline rather than earned: the master guide houses the
	## machine permanently in the side panel, so every run can reach it.
	GAMBLING,
}

enum Id {
	# Universal.
	PREDATORS_EYE,
	FOLLOW_THROUGH,
	ADRENAL_RESPONSE,
	CLEAN_FINISH,
	OVERPOPULATION,
	LAST_BASTION,
	BLOOD_IN_THE_WATER,
	SALVAGE_RIGHTS,
	INSURANCE_POLICY,
	RECYCLING_BIN,
	UNDERDOG,
	ENCORE,
	# Plant element.
	GREEN_THUMB,
	REGROWTH,
	COMPOST,
	CANOPY,
	RESURRECTION_FERN,
	WORLD_SEED,
	MAN_EATER,
	# Spore.
	HARD_HUSK,
	SPORE_BURST,
	CROSS_POLLINATION,
	PATIENT_ZERO,
	# Bloom.
	LATE_BLOOMER,
	SUPERBLOOM,
	PERENNIAL,
	# Bramble.
	SNARE_VINE,
	LIVING_RAMPART,
	THE_HEDGE,
	# Root.
	TAPROOT,
	ANNUAL_RINGS,
	WORLD_TREE,
	# Pruning.
	GLEANING_HOOK,
	GREEN_MANURE,
	RETURN_STROKE,
	# Curated Plant synergies.
	POLLINATOR,
	SEEDBED,
	TANGLED_WAKE,
	DEEP_SNARE,
	STORED_SAP,
	# Clover. Rules about the machine itself rather than about the battlefield it
	# pays out onto, which is what keeps them from being upgrade lines with a
	# different name.
	BENT_COIN,
	SIDE_POT,
	HIGH_ROLLER,
	THE_HOUSE_ALWAYS_LOSES,
}


static func get_count() -> int:
	return Id.size()


static func get_relic_name(relic_id: int) -> String:
	match relic_id:
		Id.PREDATORS_EYE:
			return "Predator's Eye"
		Id.FOLLOW_THROUGH:
			return "Follow Through"
		Id.ADRENAL_RESPONSE:
			return "Adrenal Response"
		Id.CLEAN_FINISH:
			return "Clean Finish"
		Id.OVERPOPULATION:
			return "Overpopulation"
		Id.LAST_BASTION:
			return "Last Bastion"
		Id.BLOOD_IN_THE_WATER:
			return "Blood in the Water"
		Id.SALVAGE_RIGHTS:
			return "Salvage Rights"
		Id.INSURANCE_POLICY:
			return "Insurance Policy"
		Id.RECYCLING_BIN:
			return "Recycling Bin"
		Id.UNDERDOG:
			return "Underdog"
		Id.ENCORE:
			return "Encore"
		Id.GREEN_THUMB:
			return "Green Thumb"
		Id.REGROWTH:
			return "Regrowth"
		Id.COMPOST:
			return "Compost"
		Id.CANOPY:
			return "Canopy"
		Id.RESURRECTION_FERN:
			return "Resurrection Fern"
		Id.WORLD_SEED:
			return "World Seed"
		Id.MAN_EATER:
			return "Man-Eater"
		Id.HARD_HUSK:
			return "Hard Husk"
		Id.SPORE_BURST:
			return "Spore Burst"
		Id.CROSS_POLLINATION:
			return "Cross-Pollination"
		Id.PATIENT_ZERO:
			return "Patient Zero"
		Id.LATE_BLOOMER:
			return "Late Bloomer"
		Id.SUPERBLOOM:
			return "Superbloom"
		Id.PERENNIAL:
			return "Perennial"
		Id.SNARE_VINE:
			return "Snare Vine"
		Id.LIVING_RAMPART:
			return "Living Rampart"
		Id.THE_HEDGE:
			return "The Hedge"
		Id.TAPROOT:
			return "Taproot"
		Id.ANNUAL_RINGS:
			return "Annual Rings"
		Id.WORLD_TREE:
			return "World Tree"
		Id.GLEANING_HOOK:
			return "Gleaning Hook"
		Id.GREEN_MANURE:
			return "Green Manure"
		Id.RETURN_STROKE:
			return "Return Stroke"
		Id.POLLINATOR:
			return "Pollinator"
		Id.SEEDBED:
			return "Seedbed"
		Id.TANGLED_WAKE:
			return "Tangled Wake"
		Id.DEEP_SNARE:
			return "Deep Snare"
		Id.STORED_SAP:
			return "Stored Sap"
		Id.BENT_COIN:
			return "Bent Coin"
		Id.SIDE_POT:
			return "Side Pot"
		Id.HIGH_ROLLER:
			return "High Roller"
		Id.THE_HOUSE_ALWAYS_LOSES:
			return "The House Always Loses"
	return "Unknown Relic"


static func get_relic_description(relic_id: int) -> String:
	# Player-facing text stays one short line. The rule, not its numbers.
	match relic_id:
		Id.PREDATORS_EYE:
			return "Every 10th Thornshot volley takes one extra target."
		Id.FOLLOW_THROUGH:
			return "A Thornshot kill gives the next volley +1 Pierce."
		Id.ADRENAL_RESPONSE:
			return "Taking damage makes your next three volleys fire faster."
		Id.CLEAN_FINISH:
			return "Clearing the field of hostiles restores health."
		Id.OVERPOPULATION:
			return "Six fast kills prime the next kill to explode."
		Id.LAST_BASTION:
			return "Losing a lot of Green at once grants speed and attack rate."
		Id.BLOOD_IN_THE_WATER:
			return "Thornshot prioritises badly wounded enemies."
		Id.SALVAGE_RIGHTS:
			return "Elite kills drop a Biomass cache."
		Id.INSURANCE_POLICY:
			return "Your first failed objective still pays a consolation reward."
		Id.RECYCLING_BIN:
			return "Your first relic reroll keeps at least the rarity it replaced."
		Id.UNDERDOG:
			return "Thornshot takes an extra target while you are swarmed."
		Id.ENCORE:
			return "Every third relic trigger repeats once, weaker."
		Id.GREEN_THUMB:
			return "Walking past a Seed advances it, once per Seed."
		Id.REGROWTH:
			return "Recently lost Green is reclaimed far faster while uncontested."
		Id.COMPOST:
			return "Every 12 kills on Mature Green pays out Biomass."
		Id.CANOPY:
			return "Mature Green absorbs part of the damage you take."
		Id.RESURRECTION_FERN:
			return "Losing a lot of Green makes Mature ground pulse it back."
		Id.WORLD_SEED:
			return "A huge World Seed grows after 120 kills."
		Id.MAN_EATER:
			return "Enemies on Green feed a giant Maw that erupts and eats them."
		Id.HARD_HUSK:
			return "Every Seed shrugs off the first hit that would break it."
		Id.SPORE_BURST:
			return "Germination detonates, damaging everything around the new growth."
		Id.CROSS_POLLINATION:
			return "Germinating Seeds advance nearby Seeds by 25%."
		Id.PATIENT_ZERO:
			return "The first Seed of each wave is tougher and advances all others."
		Id.LATE_BLOOMER:
			return "Blooms charge longer and gain Force while they do."
		Id.SUPERBLOOM:
			return "Overlapping Blooms create a secondary shockwave."
		Id.PERENNIAL:
			return "The first Bloom of each wave re-blooms twice."
		Id.SNARE_VINE:
			return "Rooting an enemy spreads Entanglement to those beside it."
		Id.LIVING_RAMPART:
			return "Crowded Green ensnares faster and repels more often."
		Id.THE_HEDGE:
			return "Mass Entanglement sends a Briar Sweep across your Green."
		Id.TAPROOT:
			return "Your oldest Mature ground grows a Taproot that repairs Green."
		Id.ANNUAL_RINGS:
			return "Long-lived Mature regions gain Rings that deepen Root Potency."
		Id.WORLD_TREE:
			return "A World Tree echoes Plant events that start on Mature Green."
		Id.GLEANING_HOOK:
			return "Ring kills bank Charge without eating more Green."
		Id.GREEN_MANURE:
			return "Kills by the fired ring speed the reclamation it left behind."
		Id.RETURN_STROKE:
			return "Released Pruning rings return once at reduced power."
		Id.POLLINATOR:
			return "Blooms advance up to three Seeds caught in the pressure."
		Id.SEEDBED:
			return "Seeds on Mature Green leave a Root Node in the new patch."
		Id.TANGLED_WAKE:
			return "Green a Bloom just pushed out ensnares far faster."
		Id.DEEP_SNARE:
			return "Entanglement barely decays on Mature Green."
		Id.STORED_SAP:
			return "Harvesting Mature Green banks Sap that surges Root on release."
		Id.BENT_COIN:
			return "Every third Triple Bust is bent into a whiff instead."
		Id.SIDE_POT:
			return "Whiffs build a Side Pot that swells the next jackpot. A Bust empties it."
		Id.HIGH_ROLLER:
			return "Every seventh spin doubles the jackpot and doubles the Bust."
		Id.THE_HOUSE_ALWAYS_LOSES:
			return "Each Triple Bust permanently cuts Bust odds. The third one is on the house."
	return ""


static func get_rarity(relic_id: int) -> int:
	match relic_id:
		Id.PREDATORS_EYE, Id.FOLLOW_THROUGH, Id.ADRENAL_RESPONSE, Id.CLEAN_FINISH, \
		Id.GREEN_THUMB, Id.HARD_HUSK, Id.BENT_COIN:
			return Rarity.COMMON
		Id.OVERPOPULATION, Id.LAST_BASTION, Id.BLOOD_IN_THE_WATER, Id.SALVAGE_RIGHTS, \
		Id.REGROWTH, Id.COMPOST, Id.CANOPY, Id.LATE_BLOOMER, Id.SNARE_VINE, \
		Id.TAPROOT, Id.GLEANING_HOOK, Id.POLLINATOR, Id.DEEP_SNARE, Id.SPORE_BURST, 		Id.SIDE_POT:
			return Rarity.UNCOMMON
		Id.INSURANCE_POLICY, Id.RECYCLING_BIN, Id.UNDERDOG, Id.RESURRECTION_FERN, \
		Id.CROSS_POLLINATION, Id.SUPERBLOOM, Id.LIVING_RAMPART, Id.ANNUAL_RINGS, \
		Id.GREEN_MANURE, Id.SEEDBED, Id.TANGLED_WAKE, Id.STORED_SAP, Id.HIGH_ROLLER:
			return Rarity.RARE
		Id.ENCORE, Id.WORLD_SEED, Id.PATIENT_ZERO, Id.PERENNIAL, Id.THE_HEDGE, \
		Id.WORLD_TREE, Id.MAN_EATER, Id.RETURN_STROKE, Id.THE_HOUSE_ALWAYS_LOSES:
			return Rarity.LEGENDARY
	return Rarity.COMMON


static func get_rarity_name(rarity: int) -> String:
	match rarity:
		Rarity.COMMON:
			return "COMMON"
		Rarity.UNCOMMON:
			return "UNCOMMON"
		Rarity.RARE:
			return "RARE"
		Rarity.LEGENDARY:
			return "LEGENDARY"
	return ""


static func get_rarity_color(rarity: int) -> Color:
	match rarity:
		Rarity.COMMON:
			return Color("b9c7bd")
		Rarity.UNCOMMON:
			return Color("8fe86a")
		Rarity.RARE:
			return Color("6fc8ff")
		Rarity.LEGENDARY:
			return Color("ffd24a")
	return Color.WHITE


static func get_pool(relic_id: int) -> int:
	match relic_id:
		Id.PREDATORS_EYE, Id.FOLLOW_THROUGH, Id.ADRENAL_RESPONSE, Id.CLEAN_FINISH, \
		Id.OVERPOPULATION, Id.LAST_BASTION, Id.BLOOD_IN_THE_WATER, Id.SALVAGE_RIGHTS, \
		Id.INSURANCE_POLICY, Id.RECYCLING_BIN, Id.UNDERDOG, Id.ENCORE:
			return Pool.UNIVERSAL
		Id.GREEN_THUMB, Id.REGROWTH, Id.COMPOST, Id.CANOPY, Id.RESURRECTION_FERN, \
		Id.WORLD_SEED, Id.MAN_EATER:
			return Pool.ELEMENT
		Id.POLLINATOR, Id.SEEDBED, Id.TANGLED_WAKE, Id.DEEP_SNARE, Id.STORED_SAP:
			return Pool.SYNERGY
		Id.BENT_COIN, Id.SIDE_POT, Id.HIGH_ROLLER, Id.THE_HOUSE_ALWAYS_LOSES:
			return Pool.GAMBLING
	return Pool.PATH


static func get_owning_path(relic_id: int) -> int:
	# Path pool only. Everything else reports no owning path.
	match relic_id:
		Id.HARD_HUSK, Id.SPORE_BURST, Id.CROSS_POLLINATION, Id.PATIENT_ZERO:
			return PhaseBProgression.PathId.SPORE
		Id.LATE_BLOOMER, Id.SUPERBLOOM, Id.PERENNIAL:
			return PhaseBProgression.PathId.BLOOM
		Id.SNARE_VINE, Id.LIVING_RAMPART, Id.THE_HEDGE:
			return PhaseBProgression.PathId.BRAMBLE
		Id.TAPROOT, Id.ANNUAL_RINGS, Id.WORLD_TREE:
			return PhaseBProgression.PathId.ROOT
		Id.GLEANING_HOOK, Id.GREEN_MANURE, Id.RETURN_STROKE:
			return PhaseBProgression.PathId.PRUNING
	return PhaseBProgression.UNSELECTED_PATH


static func get_mechanic_requirements(relic_id: int) -> PackedInt32Array:
	# Synergy relics name mechanics, never path pairs, so a third path or an
	# Evolution that introduces the mechanic makes the relic eligible on its own.
	match relic_id:
		Id.POLLINATOR:
			return PackedInt32Array([Mechanic.SEED, Mechanic.BLOOM])
		Id.SEEDBED:
			return PackedInt32Array([Mechanic.SEED, Mechanic.ROOT_POTENCY])
		Id.TANGLED_WAKE:
			return PackedInt32Array([Mechanic.BLOOM, Mechanic.ENTANGLEMENT])
		Id.DEEP_SNARE:
			return PackedInt32Array([Mechanic.ENTANGLEMENT, Mechanic.MATURE_GREEN])
		Id.STORED_SAP:
			return PackedInt32Array([Mechanic.ROOT_POTENCY, Mechanic.PRUNING_CHARGE])
		Id.BENT_COIN, Id.SIDE_POT, Id.HIGH_ROLLER, Id.THE_HOUSE_ALWAYS_LOSES:
			return PackedInt32Array([Mechanic.GAMBLING])
		Id.INSURANCE_POLICY:
			return PackedInt32Array([Mechanic.OPTIONAL_OBJECTIVE])
	return PackedInt32Array()


static func get_path_mechanics(path_id: int) -> PackedInt32Array:
	# What holding a path gives the run. Seeds and maturity are baseline Plant
	# behaviour and are provided without any path at all.
	match path_id:
		PhaseBProgression.PathId.SPORE:
			return PackedInt32Array([Mechanic.SEED])
		PhaseBProgression.PathId.BLOOM:
			return PackedInt32Array([Mechanic.BLOOM])
		PhaseBProgression.PathId.BRAMBLE:
			return PackedInt32Array([Mechanic.ENTANGLEMENT])
		PhaseBProgression.PathId.ROOT:
			return PackedInt32Array([Mechanic.ROOT_POTENCY])
		PhaseBProgression.PathId.PRUNING:
			return PackedInt32Array([Mechanic.PRUNING_RING, Mechanic.PRUNING_CHARGE])
	return PackedInt32Array()


static func get_baseline_mechanics() -> PackedInt32Array:
	return PackedInt32Array([Mechanic.SEED, Mechanic.MATURE_GREEN, Mechanic.GAMBLING])


static func get_mechanic_name(mechanic_id: int) -> String:
	match mechanic_id:
		Mechanic.SEED:
			return "Seed"
		Mechanic.BLOOM:
			return "Bloom"
		Mechanic.ENTANGLEMENT:
			return "Entanglement"
		Mechanic.MATURE_GREEN:
			return "Mature Green"
		Mechanic.ROOT_POTENCY:
			return "Root Potency"
		Mechanic.PRUNING_RING:
			return "Pruning Ring"
		Mechanic.PRUNING_CHARGE:
			return "Pruning Charge"
		Mechanic.OPTIONAL_OBJECTIVE:
			return "Optional Objective"
		Mechanic.GAMBLING:
			return "Clover"
	return ""


static func is_legendary(relic_id: int) -> bool:
	return get_rarity(relic_id) == Rarity.LEGENDARY
