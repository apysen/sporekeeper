class_name PhaseBRelicCatalog
extends RefCounted

## The authored relic catalog: identity, rarity, pool, and player text for every
## relic in the run. It is pure data with no scene dependencies, so drafting
## rules, the HUD, and the tests all read the same table.
##
## Relics are permanent, non-levelling rule changes. A relic changes a rule, a
## trigger, targeting, timing, or an interaction; a normal upgrade line is what
## changes a number. Nothing in this file is a percentage of the arena: triggers
## are fixed counters, per-object limits, local density, or absolute territory,
## which is the standing rule for this game's relic design.
##
## Structure follows docs/relics.md, which is the master document. Nine pools of
## eight relics each -- 3 Common, 2 Uncommon, 2 Rare, 1 Legendary -- for 72 total.
## Plant is shared by every run and exists to glue otherwise separate systems
## together. The other eight pools each belong to one Adaptation and unlock only
## when the run permanently owns that Adaptation.
##
## Clover deliberately has no relic pool. It stays its own slot machine rather
## than paying rent in the normal relic reward.

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	LEGENDARY,
}

enum Pool {
	## Shared by every build. Cross-system glue rather than generic stat bonuses.
	PLANT,
	SPORE,
	BLOOM,
	BRAMBLE,
	ROOT,
	PRUNING,
	THISTLE,
	VINE,
	FRUIT,
}

## Which rarity table an offer rolls against. The run gets deeper tables as it
## acquires Adaptations, so Legendaries stay possible early without being the
## expectation.
enum RunState {
	SINGLE_ADAPTATION,
	TWO_PRE_EVOLUTION,
	POST_EVOLUTION,
	## Every Core and Branch slot filled: five eligible pools, forty relics.
	FULL_ROSTER,
}

enum Id {
	# Plant. Shared cross-system glue.
	GARDEN_HOSE,
	MULCH,
	MIMOSA,
	COMPOST_HEAP,
	MAN_EATER,
	GRAFTING_TAPE,
	MIRACLE_GRO,
	HYBRID_VIGOR,
	# Spore. Seeds create, survive, and accelerate more Seeds.
	HARD_HUSK,
	GREEN_THUMB,
	PUFFBALL,
	SPORE_BURST,
	CROSS_POLLINATION,
	WINDBORNE,
	VOLUNTEER,
	DOMINO_GERMINATION,
	# Bloom. One lethal Bloom turns into additional Bloom events.
	LATE_BLOOMER,
	DEADHEADING,
	PETAL_SCATTER,
	CHAIN_BLOOM,
	OVERKILL,
	SUPERBLOOM,
	PERENNIAL,
	FLOWERING_FRONT,
	# Bramble. Crowd control recursively creates more crowd control.
	HOOKTHORN,
	THORNBACK,
	COCKLEBUR,
	SNARE_VINE,
	BRIAR_KNOT,
	LIVING_RAMPART,
	BRIARBALL,
	THE_HEDGE,
	# Root. Mature territory acts as one transmitting organism.
	ROOTBOUND,
	SUCKERS,
	FEEDER_ROOTS,
	TAPROOT,
	GRAFT_UNION,
	ANNUAL_RINGS,
	RHIZOME,
	WORLD_TREE,
	# Pruning. One harvested release branches, then heals its own wound.
	GLEANING_HOOK,
	SKIMMING_CUT,
	CALLUS,
	BRUSH_PILE,
	STUBBLE,
	GREEN_MANURE,
	RETURN_STROKE,
	WATERSPROUTS,
	# Thistle. One turret, so the pool is about what a single Thistle can be made to
	# do twice: answer itself, fire again, and pay out every time it takes root.
	ROSETTE,
	THORN_RELAY,
	PINCUSHION,
	SEEDHEAD,
	ANSWERING_THORN,
	PHYLLOTAXIS,
	FORKING_PATTERN,
	CROWN_OF_THORNS,
	# Vine. Precision and geometry ignite repeated physical lashes.
	WHIPLASH,
	RUNNER,
	CLIMBER,
	RECURVE,
	GIRDLING,
	TRELLIS,
	TWINING,
	LIANA,
	# Fruit. Kinetic energy propagates through rolls, steering, and collisions.
	THICK_RIND,
	STEM_STEERING,
	BRUISED_FRUIT,
	BANK_SHOT,
	FRUIT_SALAD,
	DROPPED_SEED,
	WINDFALL,
	NEWTONS_APPLE,
}

## Every pool holds exactly this shape. The drafting rules lean on it when a
## rarity is exhausted and the roll has to fall downward.
const POOL_SIZE := 8
const COMMONS_PER_POOL := 3
const UNCOMMONS_PER_POOL := 2
const RARES_PER_POOL := 2
const LEGENDARIES_PER_POOL := 1


static func get_count() -> int:
	return Id.size()


static func get_relic_name(relic_id: int) -> String:
	match relic_id:
		Id.GARDEN_HOSE:
			return "Garden Hose"
		Id.MULCH:
			return "Mulch"
		Id.MIMOSA:
			return "Mimosa"
		Id.COMPOST_HEAP:
			return "Compost Heap"
		Id.MAN_EATER:
			return "Man-Eater"
		Id.GRAFTING_TAPE:
			return "Grafting Tape"
		Id.MIRACLE_GRO:
			return "Miracle-Gro"
		Id.HYBRID_VIGOR:
			return "Hybrid Vigor"
		Id.HARD_HUSK:
			return "Hard Husk"
		Id.GREEN_THUMB:
			return "Green Thumb"
		Id.PUFFBALL:
			return "Puffball"
		Id.SPORE_BURST:
			return "Spore Burst"
		Id.CROSS_POLLINATION:
			return "Cross-Pollination"
		Id.WINDBORNE:
			return "Windborne"
		Id.VOLUNTEER:
			return "Volunteer"
		Id.DOMINO_GERMINATION:
			return "Domino Germination"
		Id.LATE_BLOOMER:
			return "Late Bloomer"
		Id.DEADHEADING:
			return "Deadheading"
		Id.PETAL_SCATTER:
			return "Petal Scatter"
		Id.CHAIN_BLOOM:
			return "Chain Bloom"
		Id.OVERKILL:
			return "Overkill"
		Id.SUPERBLOOM:
			return "Superbloom"
		Id.PERENNIAL:
			return "Perennial"
		Id.FLOWERING_FRONT:
			return "Flowering Front"
		Id.HOOKTHORN:
			return "Hookthorn"
		Id.THORNBACK:
			return "Thornback"
		Id.COCKLEBUR:
			return "Cocklebur"
		Id.SNARE_VINE:
			return "Snare Vine"
		Id.BRIAR_KNOT:
			return "Briar Knot"
		Id.LIVING_RAMPART:
			return "Living Rampart"
		Id.BRIARBALL:
			return "Briarball"
		Id.THE_HEDGE:
			return "The Hedge"
		Id.ROOTBOUND:
			return "Rootbound"
		Id.SUCKERS:
			return "Suckers"
		Id.FEEDER_ROOTS:
			return "Feeder Roots"
		Id.TAPROOT:
			return "Taproot"
		Id.GRAFT_UNION:
			return "Graft Union"
		Id.ANNUAL_RINGS:
			return "Annual Rings"
		Id.RHIZOME:
			return "Rhizome"
		Id.WORLD_TREE:
			return "World Tree"
		Id.GLEANING_HOOK:
			return "Gleaning Hook"
		Id.SKIMMING_CUT:
			return "Skimming Cut"
		Id.CALLUS:
			return "Callus"
		Id.BRUSH_PILE:
			return "Brush Pile"
		Id.STUBBLE:
			return "Stubble"
		Id.GREEN_MANURE:
			return "Green Manure"
		Id.RETURN_STROKE:
			return "Return Stroke"
		Id.WATERSPROUTS:
			return "Watersprouts"
		Id.ROSETTE:
			return "Rosette"
		Id.THORN_RELAY:
			return "Thorn Relay"
		Id.PINCUSHION:
			return "Pincushion"
		Id.SEEDHEAD:
			return "Seedhead"
		Id.ANSWERING_THORN:
			return "Answering Thorn"
		Id.PHYLLOTAXIS:
			return "Phyllotaxis"
		Id.FORKING_PATTERN:
			return "Forking Pattern"
		Id.CROWN_OF_THORNS:
			return "Crown of Thorns"
		Id.WHIPLASH:
			return "Whiplash"
		Id.RUNNER:
			return "Runner"
		Id.CLIMBER:
			return "Climber"
		Id.RECURVE:
			return "Recurve"
		Id.GIRDLING:
			return "Girdling"
		Id.TRELLIS:
			return "Trellis"
		Id.TWINING:
			return "Twining"
		Id.LIANA:
			return "Liana"
		Id.THICK_RIND:
			return "Thick Rind"
		Id.STEM_STEERING:
			return "Stem Steering"
		Id.BRUISED_FRUIT:
			return "Bruised Fruit"
		Id.BANK_SHOT:
			return "Bank Shot"
		Id.FRUIT_SALAD:
			return "Fruit Salad"
		Id.DROPPED_SEED:
			return "Dropped Seed"
		Id.WINDFALL:
			return "Windfall"
		Id.NEWTONS_APPLE:
			return "Newton's Apple"
	return "Unknown Relic"


static func get_relic_description(relic_id: int) -> String:
	# Player-facing text, taken from the master document. These state the rule and
	# the number the player actually needs, not the full tuning sheet.
	match relic_id:
		Id.GARDEN_HOSE:
			return "Travel far enough across your Green to spray a fan of fresh Green ahead of Grandma."
		Id.MULCH:
			return "Enemies that eat your Green store what they consume. Kill them to burst that growth back around the corpse."
		Id.MIMOSA:
			return "Taking damage on Green makes the plants snap shut, blasting nearby enemies away."
		Id.COMPOST_HEAP:
			return "Enemies that die on Green build compost piles. Feed a pile enough corpses and it erupts into damage and Mature Green."
		Id.MAN_EATER:
			return "Enemies that graze on Green too long become marked. Kill one to sprout a carnivorous plant that bites nearby enemies."
		Id.GRAFTING_TAPE:
			return "Every 18s, an action from one Core Adaptation makes the other Core answer with its own event at 75% strength. Branches are never linked."
		Id.MIRACLE_GRO:
			return "Create enough new Green to prime your next eligible Adaptation event to repeat at 60% strength."
		Id.HYBRID_VIGOR:
			return "Triggered relic effects have a 20% chance to repeat once at 60% strength."
		Id.HARD_HUSK:
			return "Each Seed ignores the first interruption that would destroy it."
		Id.GREEN_THUMB:
			return "Pass close to a Seed to instantly advance its germination by 35%. Once per Seed."
		Id.PUFFBALL:
			return "Destroyed Seeds burst into 3 fast-germinating Seedlings that create smaller patches of Green."
		Id.SPORE_BURST:
			return "Every Seed germination erupts for 24 damage in an 84 px radius, scaling with Growth Mass."
		Id.CROSS_POLLINATION:
			return "Germinating a Seed advances nearby Seeds by 25%."
		Id.WINDBORNE:
			return "Every 5 germinations launches 3 Seeds toward distant non-Green ground."
		Id.VOLUNTEER:
			return "Enemies killed on freshly germinated Seed Green have a 30% chance to plant a new Seed."
		Id.DOMINO_GERMINATION:
			return "Every 10 natural germinations instantly germinates up to 6 other active Seeds in a cascade."
		Id.LATE_BLOOMER:
			return "Blooms take 70% longer to charge, building up to 65% more Force and conversion."
		Id.DEADHEADING:
			return "A Bloom destroyed during wind-up still detonates at half strength."
		Id.PETAL_SCATTER:
			return "Enemies killed by a Bloom fling petals at enemies outside the blast for 45% of its center damage."
		Id.CHAIN_BLOOM:
			return "A Bloom that kills at least 4 enemies plants a smaller 55%-strength Child Bloom beyond the blast."
		Id.OVERKILL:
			return "Store 200 excess Bloom damage to make your next natural Bloom echo once at 45% strength."
		Id.SUPERBLOOM:
			return "Two Blooms close together create a 55%-strength secondary wave. 5s cooldown."
		Id.PERENNIAL:
			return "The first natural Bloom each wave re-blooms twice, 7s apart, at 60% strength."
		Id.FLOWERING_FRONT:
			return "A natural Bloom that kills 5 enemies starts a chain of up to 4 Child Blooms flowering through the wave."
		Id.HOOKTHORN:
			return "Repel an enemy into another enemy to tangle both of them."
		Id.THORNBACK:
			return "Whenever Bramble Repulsion fires, the damaged Green shoots a thorn at another nearby enemy."
		Id.COCKLEBUR:
			return "Enemies leaving Green at 50% or more Entanglement carry burrs for 3s, tangling enemies they touch."
		Id.SNARE_VINE:
			return "Rooting an enemy spreads 20% Entanglement to up to 2 nearby enemies."
		Id.BRIAR_KNOT:
			return "Enemies that die at 90% or more Entanglement leave a one-use knot that yanks and tangles the next enemy near it."
		Id.LIVING_RAMPART:
			return "Pack 6 enemies into a 150 px Green patch to accelerate Ensnare and Repulsion."
		Id.BRIARBALL:
			return "Every 4 heavily Entangled deaths creates a rolling Briarball that damages, repels, and tangles up to 8 enemies."
		Id.THE_HEDGE:
			return "When 6 enemies reach 70% Entanglement, a Briar Sweep races across your Green and drives the crowd toward full Entanglement."
		Id.ROOTBOUND:
			return "Spend 2.5s on deeply Mature Green to charge a root pulse. Carry it into younger Green to rapidly mature the area."
		Id.SUCKERS:
			return "When enemies tear away enough Mature Green, surviving roots sprout replacement Green back into the wound."
		Id.FEEDER_ROOTS:
			return "Every 4 natural Adaptation events amplified by Mature Green send a maturity pulse toward younger connected Green."
		Id.TAPROOT:
			return "An old Mature region near Grandma becomes a Taproot, repairing nearby Green every 4s."
		Id.GRAFT_UNION:
			return "Reconnect two established Green networks to mature both sides and echo the next nearby Adaptation event at 50% strength."
		Id.ANNUAL_RINGS:
			return "Old Mature regions gain a Ring every 22s, up to 3, with each Ring increasing local Root Potency."
		Id.RHIZOME:
			return "A mature isolated colony that survives 10s grows a root corridor back to the main network."
		Id.WORLD_TREE:
			return "An ancient Mature region grows a World Tree. Every 6s, the next eligible Plant event on Mature Green echoes at 45% strength."
		Id.GLEANING_HOOK:
			return "Every 8 held-ring kills grants 5% Charge without cutting more Green, up to 15% per hold."
		Id.SKIMMING_CUT:
			return "The first time a released Cutting hits terrain, it ricochets toward a nearby enemy at 65% damage."
		Id.CALLUS:
			return "After releasing Pruning, return to the wound within 8s to trigger one immediate reclamation pulse."
		Id.BRUSH_PILE:
			return "After 50% Charge, continued harvesting stores bonus Cuttings. Release to fire up to 8 extra Cuttings after the ring."
		Id.STUBBLE:
			return "Pruned Ground stays sharp for 5s, damaging enemies that cross the wound."
		Id.GREEN_MANURE:
			return "Each released-ring kill speeds reclamation by 9%, up to 2.6x for 8s."
		Id.RETURN_STROKE:
			return "After expanding, the released ring sweeps back toward Grandma once at 55% damage."
		Id.WATERSPROUTS:
			return "Kills from natural released Cuttings sprout 2 seeking Cuttings. Those children can branch one final time."
		Id.ROSETTE:
			return "Every time your Thistle takes root, including each time you set a carried one down, it immediately fires a 60%-damage opening volley."
		Id.THORN_RELAY:
			return "Every 8 natural thorn hits, your Thistle answers with a bonus thorn at 42% damage, or 65% if a second Thistle is standing to answer instead."
		Id.PINCUSHION:
			return "Hit an enemy with 5 thorns before it dies to launch 3 embedded thorns from its corpse."
		Id.SEEDHEAD:
			return "Your Thistle fires one final volley at 150% damage as it collapses, including when you drop it off the Green."
		Id.ANSWERING_THORN:
			return "When a natural volley gets a kill, your Thistle answers with another volley at 33% damage, or 50% if a second Thistle answers instead. 2.25s cooldown."
		Id.PHYLLOTAXIS:
			return "Every 5th natural firing cycle from your Thistle adds 5 spiral thorns at 55% damage."
		Id.FORKING_PATTERN:
			return "Every 12 natural thorn impacts makes the triggering hit split into 3 seeking thorns, or 4 if it crits."
		Id.CROWN_OF_THORNS:
			return "Every 12 natural firing cycles, your Thistle fires 3 volleys in quick succession at 55% damage, or every standing Thistle fires together once if there is more than one. 7s cooldown."
		Id.WHIPLASH:
			return "Land an Apical hit to snap the Vine 70 px past its tip for 40% follow-up damage."
		Id.RUNNER:
			return "The first enemy killed by each natural sweep sprouts a Runner that lashes one nearby enemy for 45% damage."
		Id.CLIMBER:
			return "Wrap Vine around terrain and hit beyond the bend to cinch that wrapped segment again for 40% damage."
		Id.RECURVE:
			return "An Apical hit makes the next opposite-direction natural sweep arrive 20% sooner."
		Id.GIRDLING:
			return "Apical-hit the same enemy on 2 consecutive natural sweeps to Girdle it. Your next Vine hit crushes it for 75% bonus damage."
		Id.TRELLIS:
			return "Consecutive natural Apical sweeps widen the Apical zone from the outer 25% up to the outer 40%."
		Id.TWINING:
			return "Every 4th natural Vine sweep repeats after 0.30s at 55% damage."
		Id.LIANA:
			return "Land Apical hits on 3 consecutive natural sweeps to unleash 4 rapid alternating sweeps at 60% damage."
		Id.THICK_RIND:
			return "The first enemy collision of each Fruit costs no momentum."
		Id.STEM_STEERING:
			return "After hitting an enemy, a Fruit can curve up to 28 degrees toward another target while keeping its speed. Twice per Fruit."
		Id.BRUISED_FRUIT:
			return "After hitting an enemy, Fruit paints a wider, denser Green trail for its next 72 px of travel."
		Id.BANK_SHOT:
			return "The first wall bounce keeps 90% speed and empowers the next enemy collision with 40% more damage and knockback."
		Id.FRUIT_SALAD:
			return "Hit the same enemy with 2 different Fruit from one release to burst it for damage and a splash of Green."
		Id.DROPPED_SEED:
			return "Every 3rd completed Fruit ejects a smaller rolling Seed that damages enemies and paints Green."
		Id.WINDFALL:
			return "A Fruit collision kill restores 22% of launch speed and redirects toward another enemy. Up to 3 times per Fruit."
		Id.NEWTONS_APPLE:
			return "Each Fruit can launch up to 3 enemies into nearby enemies. A launched enemy damages what it hits and can knock that victim into one final target."
	return ""


static func get_rarity(relic_id: int) -> int:
	match relic_id:
		Id.GARDEN_HOSE, Id.MULCH, Id.MIMOSA, \
		Id.HARD_HUSK, Id.GREEN_THUMB, Id.PUFFBALL, \
		Id.LATE_BLOOMER, Id.DEADHEADING, Id.PETAL_SCATTER, \
		Id.HOOKTHORN, Id.THORNBACK, Id.COCKLEBUR, \
		Id.ROOTBOUND, Id.SUCKERS, Id.FEEDER_ROOTS, \
		Id.GLEANING_HOOK, Id.SKIMMING_CUT, Id.CALLUS, \
		Id.ROSETTE, Id.THORN_RELAY, Id.PINCUSHION, \
		Id.WHIPLASH, Id.RUNNER, Id.CLIMBER, \
		Id.THICK_RIND, Id.STEM_STEERING, Id.BRUISED_FRUIT:
			return Rarity.COMMON
		Id.COMPOST_HEAP, Id.MAN_EATER, \
		Id.SPORE_BURST, Id.CROSS_POLLINATION, \
		Id.CHAIN_BLOOM, Id.OVERKILL, \
		Id.SNARE_VINE, Id.BRIAR_KNOT, \
		Id.TAPROOT, Id.GRAFT_UNION, \
		Id.BRUSH_PILE, Id.STUBBLE, \
		Id.SEEDHEAD, Id.ANSWERING_THORN, \
		Id.RECURVE, Id.GIRDLING, \
		Id.BANK_SHOT, Id.FRUIT_SALAD:
			return Rarity.UNCOMMON
		Id.GRAFTING_TAPE, Id.MIRACLE_GRO, \
		Id.WINDBORNE, Id.VOLUNTEER, \
		Id.SUPERBLOOM, Id.PERENNIAL, \
		Id.LIVING_RAMPART, Id.BRIARBALL, \
		Id.ANNUAL_RINGS, Id.RHIZOME, \
		Id.GREEN_MANURE, Id.RETURN_STROKE, \
		Id.PHYLLOTAXIS, Id.FORKING_PATTERN, \
		Id.TRELLIS, Id.TWINING, \
		Id.DROPPED_SEED, Id.WINDFALL:
			return Rarity.RARE
		Id.HYBRID_VIGOR, Id.DOMINO_GERMINATION, Id.FLOWERING_FRONT, \
		Id.THE_HEDGE, Id.WORLD_TREE, Id.WATERSPROUTS, \
		Id.CROWN_OF_THORNS, Id.LIANA, Id.NEWTONS_APPLE:
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
		Id.GARDEN_HOSE, Id.MULCH, Id.MIMOSA, Id.COMPOST_HEAP, Id.MAN_EATER, \
		Id.GRAFTING_TAPE, Id.MIRACLE_GRO, Id.HYBRID_VIGOR:
			return Pool.PLANT
		Id.HARD_HUSK, Id.GREEN_THUMB, Id.PUFFBALL, Id.SPORE_BURST, \
		Id.CROSS_POLLINATION, Id.WINDBORNE, Id.VOLUNTEER, Id.DOMINO_GERMINATION:
			return Pool.SPORE
		Id.LATE_BLOOMER, Id.DEADHEADING, Id.PETAL_SCATTER, Id.CHAIN_BLOOM, \
		Id.OVERKILL, Id.SUPERBLOOM, Id.PERENNIAL, Id.FLOWERING_FRONT:
			return Pool.BLOOM
		Id.HOOKTHORN, Id.THORNBACK, Id.COCKLEBUR, Id.SNARE_VINE, \
		Id.BRIAR_KNOT, Id.LIVING_RAMPART, Id.BRIARBALL, Id.THE_HEDGE:
			return Pool.BRAMBLE
		Id.ROOTBOUND, Id.SUCKERS, Id.FEEDER_ROOTS, Id.TAPROOT, \
		Id.GRAFT_UNION, Id.ANNUAL_RINGS, Id.RHIZOME, Id.WORLD_TREE:
			return Pool.ROOT
		Id.GLEANING_HOOK, Id.SKIMMING_CUT, Id.CALLUS, Id.BRUSH_PILE, \
		Id.STUBBLE, Id.GREEN_MANURE, Id.RETURN_STROKE, Id.WATERSPROUTS:
			return Pool.PRUNING
		Id.ROSETTE, Id.THORN_RELAY, Id.PINCUSHION, Id.SEEDHEAD, \
		Id.ANSWERING_THORN, Id.PHYLLOTAXIS, Id.FORKING_PATTERN, Id.CROWN_OF_THORNS:
			return Pool.THISTLE
		Id.WHIPLASH, Id.RUNNER, Id.CLIMBER, Id.RECURVE, \
		Id.GIRDLING, Id.TRELLIS, Id.TWINING, Id.LIANA:
			return Pool.VINE
	return Pool.FRUIT


static func get_pool_name(pool_id: int) -> String:
	match pool_id:
		Pool.PLANT:
			return "Plant"
		Pool.SPORE:
			return "Spore"
		Pool.BLOOM:
			return "Bloom"
		Pool.BRAMBLE:
			return "Bramble"
		Pool.ROOT:
			return "Root"
		Pool.PRUNING:
			return "Pruning"
		Pool.THISTLE:
			return "Thistle"
		Pool.VINE:
			return "Vine"
		Pool.FRUIT:
			return "Fruit"
	return ""


static func get_owning_path(relic_id: int) -> int:
	# Plant belongs to no Adaptation and is always eligible. Every other pool is
	# gated on permanently owning the Adaptation it is named for.
	match get_pool(relic_id):
		Pool.SPORE:
			return PhaseBProgression.PathId.SPORE
		Pool.BLOOM:
			return PhaseBProgression.PathId.BLOOM
		Pool.BRAMBLE:
			return PhaseBProgression.PathId.BRAMBLE
		Pool.ROOT:
			return PhaseBProgression.PathId.ROOT
		Pool.PRUNING:
			return PhaseBProgression.PathId.PRUNING
		Pool.THISTLE:
			return PhaseBProgression.PathId.THISTLE
		Pool.VINE:
			return PhaseBProgression.PathId.VINE
		Pool.FRUIT:
			return PhaseBProgression.PathId.FRUIT
	return PhaseBProgression.UNSELECTED_PATH


static func get_pool_for_path(path_id: int) -> int:
	match path_id:
		PhaseBProgression.PathId.SPORE:
			return Pool.SPORE
		PhaseBProgression.PathId.BLOOM:
			return Pool.BLOOM
		PhaseBProgression.PathId.BRAMBLE:
			return Pool.BRAMBLE
		PhaseBProgression.PathId.ROOT:
			return Pool.ROOT
		PhaseBProgression.PathId.PRUNING:
			return Pool.PRUNING
		PhaseBProgression.PathId.THISTLE:
			return Pool.THISTLE
		PhaseBProgression.PathId.VINE:
			return Pool.VINE
		PhaseBProgression.PathId.FRUIT:
			return Pool.FRUIT
	return Pool.PLANT


static func get_rarity_odds(run_state: int) -> PackedFloat32Array:
	# Rolled per offered relic slot, never once for the whole reward screen.
	# Legendaries stay reachable before the Evolution on purpose: a player should
	# never play for hours and conclude that early Legendaries are simply a lie.
	# Indexed by Rarity.
	match run_state:
		RunState.SINGLE_ADAPTATION:
			return PackedFloat32Array([0.72, 0.24, 0.03, 0.01])
		RunState.TWO_PRE_EVOLUTION:
			return PackedFloat32Array([0.64, 0.27, 0.075, 0.015])
		RunState.POST_EVOLUTION:
			return PackedFloat32Array([0.57, 0.28, 0.12, 0.03])
		RunState.FULL_ROSTER:
			return PackedFloat32Array([0.50, 0.29, 0.17, 0.04])
	return PackedFloat32Array([0.72, 0.24, 0.03, 0.01])


static func is_legendary(relic_id: int) -> bool:
	return get_rarity(relic_id) == Rarity.LEGENDARY
