# Sporekeeper Four-Adaptation Progression Implementation Guide

## 1. Purpose

This guide replaces the current two-Path, one-Evolution, one-support structure with a four-Adaptation build model based on breadth, deliberate investment, and complete Adaptation mastery.

The final structure is:

> Four Adaptations maximum. Two Core Adaptations, two Branch Adaptations, all four ordinary lines available in every owned Adaptation, three ranks per ordinary line, and exactly one five-rank Evolution determined only by the Core pair.

This replaces the experimental 2-of-4 specialization proposal. The player no longer permanently rejects half of an Adaptation's lines. Lower-priority utility upgrades can remain useful later in a run without being forced to compete for half of an Adaptation's permanent identity.

## 2. Final rules

| Rule | Final value |
|---|---:|
| Maximum permanently owned Adaptations | 4 |
| Core Adaptations | 2 |
| Branch Adaptations | 2 |
| Ordinary lines per owned Adaptation | 4 |
| Maximum ordinary line rank | 3 |
| Ordinary ranks needed to master one Adaptation | 12 |
| Maximum ordinary ranks across four Adaptations | 48 |
| Evolutions | Exactly 1 per run |
| Evolution pairing | Core pair only |
| Evolution ranks | Preserve the existing authored maximum of 5 |
| Branch Evolutions | None |
| Current support system | Removed |
| Relic eligibility | Plant pool plus every permanently owned Adaptation pool |
| Maximum eligible relic catalog in one run | 40 relics |
| Clover ownership behavior | Temporary only; never grants permanent ownership |

The complete permanent upgrade surface is 48 ordinary ranks plus the existing Evolution claim and up to five authored Evolution ranks. A normal Campaign should not guarantee enough purchases to maximize all 53 possible ranks.

## 3. Design intent

### 3.1 Complete investment fantasy

Mastering an Adaptation means owning everything that Adaptation offers.

Example:

```text
BLOOM - MASTERED

Bloom Force      3/3
Bloom Frequency  3/3
Aftergrowth      3/3
Suppression      3/3
```

The player can prioritize Force and Frequency first, then add Aftergrowth and Suppression when territory defense becomes important. Aftergrowth may be lower priority without becoming a permanent mistake.

### 3.2 Breadth with a hard ceiling

The player may own four of eight Adaptations. Every owned Adaptation contributes its base mechanic, four ordinary lines, and relic pool. The four-Adaptation cap prevents a run from activating the entire botanical arsenal.

### 3.3 Lower vertical extremes

Ordinary lines retain their current per-rank values but stop at rank 3. Do not compress old rank-5 totals into three purchases.

This means:

- Bloom Force reaches +75%, not +125%;
- Ripening reaches +75%, not +125%;
- Thistle reaches four thorns, three ricochets, and 30% critical chance rather than six thorns, five ricochets, and 50% critical chance;
- Fruit Set reaches four Fruit per release rather than six;
- all four lines can be owned without recreating the most dangerous five-rank multiplicative ceilings.

### 3.4 Variety comes from the complete run structure

Internal line exclusion is no longer responsible for most build variety. Variety comes from:

- choosing four of eight Adaptations;
- selecting which two are the Core pair;
- one of 28 Evolutions;
- the order in which ordinary lines are developed;
- which Adaptations are fully mastered;
- ten Campaign relic choices from five eligible pools;
- relic rarity and cross-system interactions.

Choosing four of eight creates 70 possible Adaptation rosters before Core-pair identity, investment order, Evolution rank, and relics are considered.

## 4. Terminology

### Core Adaptation

One of the first two permanently acquired Adaptations. The unordered Core pair determines the run's only Evolution.

### Branch Adaptation

The third or fourth permanently acquired Adaptation. Branches provide their complete base mechanics, all four ordinary lines, and relic-pool access. They never form another Evolution.

### Ordinary line

One of the four stat-style upgrade lines belonging to an Adaptation. Every line starts at rank 0 and may reach rank 3.

### Mastered line

An ordinary line at rank 3.

### Mastered Adaptation

An owned Adaptation with all four ordinary lines at rank 3.

### Focused Adaptation

The owned Adaptation guaranteed representation in ordinary three-card upgrade offers while it still has an eligible unmaxed line.

### Owned Adaptation

An Adaptation acquired as Core or Branch. Ownership activates its base mechanic immediately and unlocks its relic pool. Temporary Clover levels, Evolution-generated events, and relic-generated events do not create ownership.

## 5. Why the ownership cap remains four

Every Adaptation has a meaningful rank-0 mechanic:

| Adaptation | Base mechanic granted by ownership |
|---|---|
| Spore | Kill-driven Seeds and the Overgrown epidemic |
| Bloom | Periodic frontier Blooms and territory droplets |
| Bramble | Entanglement, slowing, roots, thorn contact, and Repulsion |
| Root | Mature Green, Root Network projection, and baseline local amplification |
| Pruning | Green harvest, orbiting Cuttings, Charge, and released Cutting attacks |
| Thistle | Permanent supported turrets |
| Vine | Cane becomes the persistent guided physics whip |
| Fruit | Rolling Fruit collisions, Green trail, and terminal growth |

Unlimited ownership would eventually run most combat and territory systems simultaneously and unlock all 72 relics. Four owned Adaptations expose five eight-relic pools when Plant is included, for 40 eligible relics. This is already a large interaction surface.

## 6. Campaign acquisition sequence

| Run point | Acquisition |
|---|---|
| Before Wave 1 | Choose Core Adaptation 1 |
| After Wave 1 | Choose Core Adaptation 2 and lock the Evolution pair |
| Elite Rootbreaker defeated in Wave 6 | Choose Branch Adaptation 1 |
| Burrower Boss defeated from Wave 13 onward | Choose Branch Adaptation 2 |

If the Elite or Boss survives beyond its intended wave, its Branch reward is delayed until it dies. The run continues.

Campaign time, enemies, and physics pause during every Adaptation selection.

Acquiring an Adaptation:

1. adds it to the appropriate Core or Branch slot;
2. activates its base mechanic;
3. initializes all four line ranks at 0;
4. adds all four lines to the ordinary upgrade candidate pool;
5. unlocks its relic pool immediately;
6. makes it eligible to become the Focused Adaptation;
7. updates the HUD.

No free ordinary rank is granted merely for acquiring an Adaptation.

## 7. Adaptation selection interface

Show every currently unowned Adaptation. Do not randomize Core or Branch availability.

The chooser displays:

- Adaptation name and emblem;
- base mechanic summary;
- role tags such as Territory, Damage, Control, Amplifier, or Defense;
- all four ordinary line names and rank-3 maximums;
- for Core 2, the Evolution that would result from pairing with Core 1;
- for Branches, a clear `DOES NOT CHANGE EVOLUTION` label.

The second Core preview includes:

```text
CORE PAIR
Spore + Root

EVOLUTION
Seed Bank

Unlock condition:
Master any 2 Spore lines
and any 2 Root lines.
```

No specialization confirmation follows Adaptation acquisition. All four lines are available automatically.

## 8. Run-state data model

Add one authoritative `RunAdaptationState` owned by progression.

```gdscript
class_name RunAdaptationState
extends Resource

@export var core_adaptation_ids: Array[StringName] = []
@export var branch_adaptation_ids: Array[StringName] = []

# line_id -> permanent rank 0 through 3
@export var ordinary_line_ranks: Dictionary = {}

@export var focused_adaptation_id: StringName = &""

@export var evolution_id: StringName = &""
@export var evolution_claimed: bool = false
@export var evolution_rank: int = 0

@export var pending_adaptation_choice: StringName = &""
@export var acquisition_order: Array[StringName] = []
```

### 8.1 Required invariants

Validate after every mutation and on save load:

```text
core_adaptation_ids.size() <= 2
branch_adaptation_ids.size() <= 2
owned_adaptation_count <= 4
no Adaptation appears in both arrays
no duplicate Adaptation id
every ordinary line belongs to an owned Adaptation
ordinary line rank is between 0 and 3
focused_adaptation_id is empty or permanently owned
evolution_id matches only the unordered Core pair
Branch ids never participate in evolution_id
evolution_rank follows the authored Evolution schema
```

Expose read-only helpers:

```gdscript
func owns_adaptation(id: StringName) -> bool
func is_core_adaptation(id: StringName) -> bool
func is_branch_adaptation(id: StringName) -> bool
func get_ordinary_line_rank(line_id: StringName) -> int
func is_line_mastered(line_id: StringName) -> bool
func get_mastered_line_count(adaptation_id: StringName) -> int
func is_adaptation_mastered(adaptation_id: StringName) -> bool
func set_focused_adaptation(id: StringName) -> bool
func can_claim_evolution() -> bool
func get_owned_relic_pool_ids() -> Array[StringName]
```

All combat and relic systems must call `owns_adaptation`. Do not infer ownership from a nonzero line rank, temporary jackpot rank, Evolution event, or active entity.

## 9. Ordinary rank model

### 9.1 Rank application

```text
new_rank = min(3, old_rank + 1)
```

Apply one rank, refresh dependent systems, update the HUD, emit telemetry, and recalculate Evolution readiness.

### 9.2 Preserve per-rank values

Current per-rank values remain unchanged unless this guide explicitly identifies an exception. Rank 3 is the new ordinary maximum.

Do not use either of these compression models:

```text
new rank 1 = old rank 1
new rank 2 = old rank 3
new rank 3 = old rank 5
```

or:

```text
new per-rank value = old rank-5 total / 3
```

Both would deliver former maximum power in only 12 purchases per Adaptation and create large early spikes.

### 9.3 Mastery

When all four ordinary lines reach rank 3:

- set `adaptation_mastered = true`;
- play the Adaptation mastery flourish once;
- show `MASTERED` in its HUD row;
- clear Focus if this was the Focused Adaptation;
- do not grant a hidden combat bonus unless one is explicitly authored later.

Mastery is presentation and completion state, not an additional multiplier.

## 10. Upgrade drafting and Cultivation Focus

> **Not currently implemented (removed 2026-09-04).** Focus was pulled from the build
> for playtesting. Sections 10.1 and the guaranteed Focus slot in 10.2 do not describe
> the shipping game: every ordinary offer is drawn from the unrestricted weighted pool,
> and the drought guards carry the anti-starvation job on their own. The design below
> is retained as the spec to restore from.

Four owned Adaptations can expose 16 ordinary lines plus the Evolution. A Focus system prevents the large late candidate pool from blocking deliberate investment.

### 10.1 Setting Focus

- The player may Focus one permanently owned Adaptation.
- Core 1 becomes the default Focus when the run begins.
- The player may change Focus from the Adaptation HUD while the game is paused.
- Focus can also be changed during the normal between-wave pause.
- Changing Focus costs no reroll or resource.
- A mastered Adaptation cannot remain Focused.
- Acquiring a Branch does not automatically steal Focus.

### 10.2 Candidate construction

For every standard upgrade reward:

1. Collect every ordinary line from owned Adaptations with rank below 3.
2. If Evolution is READY but unclaimed, add the Evolution claim card.
3. If Evolution is claimed and its authored line has a purchasable next rank, add that exact next-rank card.
4. Exclude maxed ordinary lines.
5. Exclude lines from unowned Adaptations.
6. Exclude temporary Clover overlays from permanent candidate state.
7. Prevent duplicate candidates within one offer.

### 10.3 Three-card offer generation

When the Focused Adaptation has an eligible ordinary line:

- Slot 1 is selected from its eligible lines.
- Slots 2 and 3 are selected without replacement from the full remaining candidate pool.
- When possible, the final screen contains at least two different Adaptations.

When Focus is empty or the Focused Adaptation has no eligible line:

- select all three cards from the full candidate pool;
- clear invalid Focus before presenting the screen.

Evolution claim and Evolution rank cards are unrestricted candidates. They may occupy Slots 2 or 3. When the Evolution claim drought guard forces the claim card, it may replace Slot 3 but never the guaranteed Focus card.

### 10.4 Line drought guard

Recommended weights:

```text
base line weight = 1.0
not offered in previous 2 upgrade screens = 1.5
not offered in previous 4 upgrade screens = force into next legal unrestricted slot
same exact line appeared last screen = 0.65
```

The drought history is tracked per line. A line forced by Focus still resets its drought counter.

### 10.5 Rerolls

- An upgrade reroll rebuilds the screen from the same current ranks and Focus.
- Slot 1 remains an eligible Focus line but should prefer a different Focus line when possible.
- The full three-card screen may not repeat identically unless fewer than four total candidates exist.
- Rerolls do not change Focus automatically.

### 10.6 Fully complete build

If no ordinary or Evolution candidate remains:

- stop generating additional level-up choice panels;
- continue accumulating XP only for telemetry;
- show `GARDEN COMPLETE` once;
- do not introduce an infinite generic stat-upgrade loop.

## 11. Evolution rules

### 11.1 Pair determination

As soon as Core 2 is acquired:

```text
evolution_id = evolution_matrix[unordered_pair(core_1, core_2)]
```

This value is frozen for the run.

### 11.2 Readiness

Evolution becomes READY when:

```text
mastered_line_count(Core 1) >= 2
AND
mastered_line_count(Core 2) >= 2
```

This requires at least 12 ordinary purchases:

- 6 ranks in Core 1;
- 6 ranks in Core 2.

Only permanent ordinary ranks count.

The following do not count:

- mastered Branch lines;
- temporary Clover jackpot ranks;
- relic bonuses;
- generated events carrying Core Adaptation tags;
- Adaptation ownership without ordinary rank investment.

### 11.3 Claim

Claiming Evolution:

- activates only the precomputed Core-pair Evolution;
- never opens another Adaptation slot by itself;
- does not grant additional upgrade slots;
- does not unlock Branch Evolutions;
- emits `evolution_claimed` with both Core ids;
- updates relic rarity state to at least the post-Evolution tier.

Preserve the current authored Evolution schemas:

- The original ten Evolutions keep a separate claim state followed by the authored five-purchase line.
- The eighteen Thistle, Vine, and Fruit pairings keep claim as rank 1 followed by ranks 2 through 5.
- Keep `evolution_claimed` separate from `evolution_rank` so both schemas remain representable.

Do not reduce Evolution lines to three ranks. Their ranks contain unique authored mechanics rather than repeated ordinary stat increments, and compressing them would require redesigning all 28 Evolutions.

### 11.4 Evolution matrix

Pairing is symmetric.

| | Spore | Bloom | Bramble | Root | Pruning | Thistle | Vine | Fruit |
|---|---|---|---|---|---|---|---|---|
| Spore | - | Super Bloom | Briar Pods | Seed Bank | Pioneer | Inoculator | Mycelial Vine | Rot |
| Bloom | Super Bloom | - | Thornburst | Flowering Season | Rebound | Burstbloom | Wisteria | Overripe |
| Bramble | Briar Pods | Thornburst | - | Old Growth | Deadfall | Hedge Battery | Briar Cane | Durian |
| Root | Seed Bank | Flowering Season | Old Growth | - | Coppicing | Rootstock | Heartwood | Orchard |
| Pruning | Pioneer | Rebound | Deadfall | Coppicing | - | Deadheading | Espalier | Graft |
| Thistle | Inoculator | Burstbloom | Hedge Battery | Rootstock | Deadheading | - | Thornwhip | Burdock |
| Vine | Mycelial Vine | Wisteria | Briar Cane | Heartwood | Espalier | Thornwhip | - | Gourdvine |
| Fruit | Rot | Overripe | Durian | Orchard | Graft | Burdock | Gourdvine | - |

Do not change existing Evolution mechanics, damage packets, source tags, recursion rules, or rank effects as part of this progression restructure. Validate their balance against lower rank-3 ordinary maxima before changing them individually.

## 12. Branch Adaptation rules

Branches are full permanent Adaptations with three exceptions:

1. They cannot determine or replace the run's Evolution.
2. Their mastered lines cannot satisfy the Core Evolution gate.
3. Core-only relic interactions do not include them.

Everything else works normally:

- base mechanic activates immediately;
- all four ordinary lines become available at rank 0;
- all four lines can reach rank 3;
- the Adaptation's relic pool becomes eligible immediately;
- Root Network can amplify compatible Branch effects;
- Branch natural events may trigger generic relics;
- a Branch may be Focused;
- a Branch can become fully mastered.

Example:

```text
Core 1: Spore
Core 2: Root
Evolution: Seed Bank
Branch 1: Bramble
Branch 2: Thistle
```

This remains a Seed Bank build. Bramble and Thistle add complete ordinary development surfaces, but Briar Pods, Rootstock, Hedge Battery, and Inoculator never become claimable.

## 13. Path roster at rank 3

### 13.1 Spore

Base mechanic:

- every five kills creates a Seed before Seed Production ranks;
- Seeds germinate into Green;
- enemies on owned Green accumulate Spore;
- full Spore causes the four-second Overgrown lethal effect;
- Overgrown contagion and death bursts remain active at rank 0.

| Line | Per rank | Rank 3 maximum |
|---|---|---|
| Seed Production | One fewer kill required per Seed | 5 kills to 2 |
| Growth Mass | +24% Seed growth mass | +72% |
| Sporulation | +25% Spore accumulation rate | +75% |
| Fruiting Bodies | +10 percentage points colony chance | 30% |

The three-rank cap fixes the old dead-rank problem naturally. Seed Production now improves on every available rank:

```text
rank 0: 5 kills
rank 1: 4 kills
rank 2: 3 kills
rank 3: 2 kills
```

Remove the experimental fractional kill-credit proposal. Preserve the existing integer threshold and minimum of 2.

### 13.2 Bloom

Base mechanic:

- first Bloom after four seconds;
- normal playable interval remains 15 seconds before Frequency;
- detonation damages enemies and applies territory pressure;
- six physics droplets distribute territory payload.

| Line | Per rank | Rank 3 maximum |
|---|---|---|
| Bloom Force | +25% Bloom pressure and damage | +75% |
| Bloom Frequency | interval multiplied by 0.86 | 0.636x interval, about 36% shorter |
| Aftergrowth | +8 temporary control on Bloomed Green for 4s | 24 control |
| Suppression | -8 percentage points territory damage from struck enemies for 4s | -24% |

Aftergrowth and Suppression remain supplemental tempo defenses. They no longer need to justify permanent exclusion of Force or Frequency.

### 13.3 Bramble

Base mechanic:

- enemies touching owned Green build Entanglement;
- full Entanglement slows and roots;
- Green damage can repel attackers;
- thorn contact damage and developed-frontier crossing damage remain active.

| Line | Per rank | Rank 3 maximum |
|---|---|---|
| Entanglement | +5 percentage point slow and +10% Bramble potency | +15pp slow, +30% potency |
| Ensnare Rate | +10% Entanglement buildup | +30% |
| Grasping Roots | +0.35s root duration | +1.05s |
| Repulsion | +16 px shove | +48 px |

Global Campaign CC resistance reduces final slow, root duration, and shove distance, but does not reduce buildup toward full Entanglement.

### 13.4 Root

Base mechanic:

- territory matures;
- Mature Green resists erosion and can regrow control;
- fully Mature Green supplies the baseline 1.30x Root Network multiplier;
- compatible effects sample the network where they originate.

| Line | Per rank | Rank 3 maximum |
|---|---|---|
| Maturation Speed | +22% maturation rate | +66% |
| Lateral Roots | +24 px Root Network reach | +72 px |
| Mature Strength | +16% resistance and +0.008 control/s regrowth | +48%, +0.024/s |
| Root Potency | +22% Root Network amplification | +66% beyond the base network bonus |

Root ownership and Potency may amplify compatible effects from Core or Branch Adaptations.

Vine and Fruit take that amplification as virtual ranks on a started line. Thistle does
not: each of its four lines takes Potency in authored form instead -- +1 thorn on
Clustering, +1 ricochet on Burr, and Potency's own multiplier on Dehiscence's attack
rate and Needlepoint's critical damage. Thistle thorn damage is never amplified. Both
routes share the same gate: Mature player ground under the effect, and a line the run
has already started.

### 13.5 Pruning

Base mechanic:

- standing on owned Green harvests a local patch;
- Cuttings form an orbiting ring;
- each Cutting and ring-contact bite starts from 26 damage;
- holding up to eight seconds builds Charge;
- releasing launches the stored ring.

| Line | Per rank | Rank 3 maximum |
|---|---|---|
| Harvest Rate | +18% harvest rate | +54% |
| Cutting Yield | +22% Cuttings from the same ground | +66% |
| Cutting Edge | +30% ring and Cutting damage | +90% |
| Charge | +22% Charge rate and payout | +66% |

The existing safety floor, reclaim behavior, and 16-Cutting ring cap remain.

### 13.6 Thistle

Base mechanic:

- maintain exactly one permanent turret on supported Green, and never more;
- the turret attacks every 1.10 seconds within 240 px;
- base thorn damage is 12;
- critical hits deal 2x damage;
- support loss destroys the turret unless another authored effect grants grace;
- any loss of the permanent turret, from support loss or from a bad drop, leaves the
  plot empty for 5 seconds before a replacement grows;
- walking Grandma within 15 px catches the turret on her for 3 seconds, during which
  it fires from her position and support is not evaluated;
- a carried turret that works loose over supported Green replants there and will not
  catch again for 7 seconds; one that works loose off supported Green withers.

| Line | Per rank | Rank 3 maximum |
|---|---|---|
| Clustering | +1 thorn per firing event | 4 total thorns |
| Dehiscence | +15% attack speed | +45%; about 0.759s interval |
| Burr | +1 full-damage ricochet target | 3 ricochets, 4 total hits possible |
| Needlepoint | +10 percentage points critical chance | 30% |

The distinct-started-line rule now buys carry rather than turrets:

| Distinct Thistle lines at rank 1 or higher | Carry | Stick cooldown |
|---:|---:|---:|
| 0 | 3.00s | 7.00s |
| 1 | 3.25s | 6.45s |
| 2 | 3.50s | 5.90s |
| 3 | 3.75s | 5.35s |
| 4 | 4.00s | 4.80s |

Temporary Evolution or relic turrets — Burdock's planted heads, Deadhead Flush's pair —
are unaffected by the permanent cap of one and continue to stack on top of it.

### 13.7 Vine

Base mechanic:

- replaces Cane's instant sector resolver with the persistent simulated Vine;
- keeps the 0.72-second base cadence, 92 px reach, and 90-degree driving sector;
- auto-targets the reachable unobstructed sector containing the densest enemy group;
- uses actual rope-segment contact for damage;
- remains visible and physically continuous between sweeps.

| Line | Per rank | Rank 3 maximum |
|---|---|---|
| Elongation | +20% reach | +60%; 147.2 px |
| Lignification | +25% damage | +75%; 42 base hit before Apical and Root |
| Turgor | +15% attack speed | +45%; about 0.497s interval |
| Apical Dominance | +25% damage in outer 25% | 1.75x post-Lignification tip hit |

The physical Vine exists at full base behavior through ownership alone.

### 13.8 Fruit

Base mechanic:

- release one rolling Fruit toward the densest targetable 90-degree sector;
- base speed 300 px/s and unobstructed stopping distance 320 px;
- collision deals 36 damage and 38 px knockback;
- Fruit stamps Green every 20 px;
- terminal burst deals up to 10 damage and establishes Green;
- the next normal release waits until all normal Fruit and fragments have terminated, then uses the one-second cooldown.

| Line | Per rank | Rank 3 maximum |
|---|---|---|
| Fruit Set | +1 Fruit per release | 4 total Fruit |
| Ripening | +25% collision and terminal damage | +75%; 63 collision, 17.5 terminal center |
| Momentum | +20% unobstructed roll distance | +60%; 512 px |
| Germination | +20% total Fruit-created Green area | +60% |

All four Fruit dimensions remain available, but their reduced maxima prevent six simultaneous high-damage Fruit from becoming the ordinary baseline.

## 14. Cross-system interaction rules

### 14.1 Core and Branch parity

Unless a mechanic explicitly says `Core`, it treats Core and Branch Adaptations identically.

Examples:

- Root Potency can amplify Fruit whether Fruit is Core or Branch.
- Miracle-Gro can repeat an eligible Branch natural event.
- generic kill, territory, collision, or status interactions can cross Core and Branch boundaries.
- Focus changes draft representation only and has no combat effect.

### 14.2 Core-only effects

Keep these limited to the first two Adaptations:

- Evolution pairing and readiness;
- Grafting Tape's linked pair;
- the Evolution relationship shown in the HUD;
- telemetry fields describing primary build identity.

Update Grafting Tape terminology from `primary Adaptations` to `Core Adaptations`. Its behavior remains an 18-second Core-to-Core echo at 75% strength.

### 14.3 Generated events

Generated events:

- may use stats from a permanently owned Adaptation;
- may trigger generic relic interactions when permitted;
- do not create ownership;
- do not grant ordinary ranks;
- do not unlock relic pools;
- do not satisfy Evolution readiness;
- do not count as natural events when a counter explicitly requires a natural event.

## 15. Relic integration

### 15.1 Eligible pools

At every relic offer:

```text
eligible_pool_ids = [PLANT]
eligible_pool_ids += permanently_owned_adaptation_ids
```

Pool growth:

| Owned state | Eligible pools | Eligible relic catalog |
|---|---:|---:|
| Core 1 only | 2 | 16 |
| Both Cores | 3 | 24 |
| Branch 1 acquired | 4 | 32 |
| Branch 2 acquired | 5 | 40 |

Every pool contains three Common, two Uncommon, two Rare, and one Legendary relic.

### 15.2 Rarity state

| Run state | Common | Uncommon | Rare | Legendary |
|---|---:|---:|---:|---:|
| 1 owned Adaptation | 72% | 24% | 3% | 1% |
| 2 Cores, pre-Evolution | 64% | 27% | 7.5% | 1.5% |
| Evolution claimed or 3 owned Adaptations | 57% | 28% | 12% | 3% |
| 4 owned Adaptations | 50% | 29% | 17% | 4% |

If several rows apply, use the furthest progression state.

### 15.3 Offer generation

Preserve the existing process:

1. resolve eligible pools;
2. roll rarity per slot;
3. select an unowned eligible relic of that rarity;
4. prevent duplicates within the offer;
5. fall downward if the rarity is exhausted;
6. never fall upward;
7. keep relics one-copy-per-run unless explicitly authored otherwise.

Plant relics receive no guaranteed slot. Focus does not affect relic selection.

### 15.4 Campaign opportunities

The 25-wave Campaign has ten authored opportunities:

- Waves 3, 6, 9, 12, 15, 18, 21, and 24;
- Elite Rootbreaker defeat;
- Burrower Boss defeat.

### 15.5 Exhausted pool fallback

Remove the obsolete `24 Biomass` reward. Use `Compost Cache`:

- heal 20% maximum HP;
- restore 0.75x baseline Seed Growth Mass as Fresh Green at a valid nearby owned frontier point;
- tag it as a reward event, not Seed germination.

## 16. Clover interaction

Clover is removed from the main Campaign. Shorter Mode may preserve it.

Treat jackpot ranks as a temporary overlay:

```text
effective_line_rank = permanent_line_rank + casino_line_rank
```

Rules:

- casino ranks never change permanent ordinary ranks;
- a jackpot may temporarily affect an unowned line if the Shorter Mode machine already permits it;
- temporary ranks do not grant ownership;
- temporary ranks do not unlock relic pools;
- temporary ranks do not satisfy Evolution readiness;
- temporary ranks do not count toward Adaptation mastery or Focus completion;
- temporary ranks do not permanently increase Thistle's turret cap;
- on expiration, only the casino overlay disappears;
- the HUD uses a distinct gold temporary outline.

## 17. HUD implementation

Preserve the compact right-side `ADAPTATIONS` layout and slot-machine space in modes where Clover remains present.

### 17.1 Row structure

Each owned Adaptation uses one compact horizontal row:

```text
[BASE EMBLEM] [LINE 1] [LINE 2] [LINE 3] [LINE 4]
```

Every line icon displays three compact rank pips:

- rank 0: botanical outline with three empty pips;
- rank 1: one filled pip;
- rank 2: two filled pips;
- rank 3: fully flowered icon and `MAX` tooltip;
- temporary Clover rank: gold outer rim without changing permanent pips.

The Focused Adaptation receives a small watering-can, sun, or leaf-pointer marker beside its base emblem. Do not recolor the whole row in a way that could be confused with Evolution or rarity.

### 17.2 Grouping

Order rows as:

1. Core 1;
2. Core 2;
3. Evolution connector and Evolution emblem;
4. Branch 1;
5. Branch 2.

Use compact `CORE` and `BRANCH` labels. The Evolution connector visually joins only the two Core base emblems.

### 17.3 Mastery presentation

When all four lines reach rank 3:

- the base emblem flowers once;
- the row gains a restrained botanical frame;
- the tooltip shows `ADAPTATION MASTERED`;
- no permanent HUD space is added;
- Focus clears and the player is prompted to select a new Focus at the next safe pause.

### 17.4 Tooltips

Ordinary line tooltip includes:

- current rank out of 3;
- exact current value;
- exact next-rank value;
- relevant owned-Adaptation interactions;
- `MAX` at rank 3.

Branch base tooltip includes `Branch Adaptation: does not affect Evolution`.

## 18. Choice queue and pause behavior

Use one queue for all full-screen choices:

```text
MILESTONE_RELIC
BRANCH_ADAPTATION
WAVE_RELIC
EVOLUTION_OR_UPGRADE
```

Rules:

- one panel may be open at a time;
- Campaign time and physics remain paused until the queue is empty;
- Adaptation acquisition initializes all four rank-0 lines immediately;
- save the queue state so closing and reopening cannot skip an Adaptation reward;
- Focus changes from the HUD pause do not enter the reward queue.

At the end of Wave 6, the common order is:

1. Elite relic offer;
2. Branch 1 chooser;
3. Wave 6 relic offer;
4. pending ordinary level-ups.

At Boss defeat:

1. Boss relic offer;
2. Branch 2 chooser;
3. other queued choices.

## 19. Removal of the current support and specialization systems

Remove or retire:

- `is_tertiary_path_available` as a progression gate;
- the post-Evolution support reward;
- support-path commitment through a rank-1 upgrade card;
- the rule that Evolution grants additional upgrade slots;
- the dynamic 8 to 13 `upgrade_slot_count` expansion;
- the experimental exact-two-line specialization screen;
- `selected_line_ids` and locked-line state;
- any draft exclusion based on 2-of-4 selection;
- locked-line HUD art and tooltips;
- the experimental fractional Spore kill-credit accumulator;
- the experimental four-turret Thistle maximum;
- support terminology in relic eligibility and reward queues.

Compatibility aliases may remain temporarily:

```text
primary_path_id   -> core_adaptation_ids[0]
secondary_path_id -> core_adaptation_ids[1]
tertiary_path_id  -> branch_adaptation_ids[0]
```

New logic reads `RunAdaptationState` directly.

## 20. Save migration

### 20.1 From the original five-rank structure

1. Map old primary and secondary to Core 1 and Core 2.
2. Preserve the existing Evolution pair and Evolution state.
3. Map the old support path to Branch 1 if present.
4. Keep every owned ordinary line.
5. Clamp every ordinary rank to 3.
6. Convert each removed rank above 3 into one pending ordinary upgrade choice.
7. Leave Branch 2 empty unless its new milestone has already passed.
8. If the Boss milestone has passed and Branch 2 is absent, queue Branch 2 acquisition.
9. Remove old upgrade-slot counts after migration succeeds.

### 20.2 From the experimental 2-of-4 schema

1. Preserve all Core and Branch ownership.
2. Unlock all four authored lines in every owned Adaptation.
3. Discard `selected_line_ids` and locked-line state.
4. Preserve ranks on previously selected lines, clamped to 3.
5. Initialize previously locked lines at rank 0.
6. Refund ranks above 3 as pending ordinary upgrade choices.
7. Preserve Evolution claim and rank state.
8. Recalculate readiness under the two-mastered-lines-per-Core rule.

Persist:

```text
adaptation_state_schema_version = 3
```

Migration must be idempotent. Development builds may invalidate active-run saves instead, but must preserve account unlocks, settings, and statistics.

## 21. Signals and event contracts

Recommended progression signals:

```gdscript
signal adaptation_acquired(adaptation_id, slot_kind, slot_index)
signal ordinary_line_rank_changed(line_id, old_rank, new_rank)
signal adaptation_mastered(adaptation_id)
signal focused_adaptation_changed(old_id, new_id)
signal core_pair_locked(core_a, core_b, evolution_id)
signal evolution_ready(evolution_id)
signal evolution_claimed(evolution_id)
signal evolution_rank_changed(evolution_id, old_rank, new_rank)
signal branch_reward_unlocked(branch_index, source_milestone)
signal relic_pools_changed(eligible_pool_ids)
```

Combat directors subscribe only to events relevant to their Adaptation. Relic-offer code subscribes to `relic_pools_changed`. HUD code reads authoritative state after each signal.

## 22. Telemetry

Record:

```text
adaptation_choice_opened
adaptation_acquired
adaptation_focus_changed
upgrade_offer_generated
upgrade_offer_focus_slot
upgrade_offer_rerolled
ordinary_line_ranked
ordinary_line_mastered
adaptation_mastered
evolution_ready
evolution_claimed
evolution_ranked
branch_reward_unlocked
branch_reward_delayed
garden_completed
```

For each run, retain:

- Core pair;
- Branch ids;
- wave and time of each acquisition;
- every Focus change;
- wave and time each line and Adaptation was mastered;
- wave and time Evolution became READY and was claimed;
- every skipped and selected upgrade candidate;
- relic eligibility state at every relic offer;
- final ranks and relics;
- failure wave or victory.

Useful balance questions:

- How many Adaptations are mastered in completed runs?
- Which ordinary lines are consistently delayed until last?
- Does a lower-priority line become worthwhile when its wave pressure appears?
- Does Focus cause excessive repetition?
- How often is Evolution delayed because the player develops Branch lines?
- Which Branches are chosen to repair each Core pair?
- Does access to every defensive line make late Green too stable?
- Does the rank-3 offensive ceiling leave late enemies alive too long?

## 23. Automated tests

### 23.1 State invariants

- Cannot own more than four Adaptations.
- Cannot acquire the same Adaptation twice.
- Every owned Adaptation exposes exactly four ordinary lines.
- Ordinary ranks clamp at 3.
- Branch cannot enter the Evolution pair.
- Save/load preserves ranks, ownership, Focus, and Evolution state.

### 23.2 Evolution matrix

- Test all 28 unordered Core pairs.
- Core order does not change the Evolution.
- One mastered line in each Core is insufficient.
- Two mastered lines in only one Core are insufficient.
- Two mastered lines in each Core set READY.
- Mastered Branch lines do not affect readiness.
- Clover ranks do not affect readiness.
- No second Evolution becomes eligible after Branch acquisition.

### 23.3 Draft and Focus

- Slot 1 belongs to the Focused Adaptation when it has an eligible line.
- Focus never produces a maxed line.
- Slots 2 and 3 use the unrestricted pool.
- At least two Adaptations appear when possible.
- Four-screen drought guard forces a missing line into an unrestricted slot.
- Rerolls do not return the identical screen when alternatives exist.
- Focus clears when its Adaptation is mastered.
- Fully complete builds stop opening choice panels.

### 23.4 Relics

- Core 1 unlocks Plant plus one Adaptation pool.
- Core 2 adds its pool.
- Each Branch adds its pool immediately.
- Ordinary ranks and Focus do not change relic eligibility.
- Temporary Clover ranks do not change relic eligibility.
- Four owned Adaptations expose exactly 40 possible relics before one-copy exclusions.
- Grafting Tape links only the two Cores.

### 23.5 Path exceptions

- Seed Production uses 5, 4, 3, and 2-kill thresholds at ranks 0 through 3.
- Thistle cap progresses 2, 3, 4, and 5 through distinct started lines.
- Temporary ranks do not permanently change turret cap.
- Vine exists continuously at rank 0 when owned.
- Root amplifies compatible Branch effects.
- Every ordinary line applies its existing per-rank value exactly three times.

## 24. Balance validation

### 24.1 Rank checkpoints

Test every ordinary line at ranks 0, 1, 2, and 3. Record:

- damage or territory output;
- effect on survival and Green stability;
- performance cost;
- reliance on a specific Evolution or relic;
- whether rank 3 feels complete despite being lower than the former rank-5 ceiling.

Lower-priority utility lines do not need equal pick priority at every wave. They do need a plausible point in the Campaign where the player values them.

### 24.2 Full-build coverage

There are 28 Core pairs and 15 ways to choose two Branches from the remaining six, for 420 Core/Branch roster combinations.

Automate state-construction validation for all 420. Use curated combat fixtures for high-risk combinations:

- Spore + Bloom Core, Thistle + Fruit Branch;
- Thistle + Vine Core, Root + Fruit Branch;
- Root + Fruit Core, Bramble + Thistle Branch;
- Spore + Pruning Core, Bloom + Fruit Branch;
- Bramble + Root Core, Thistle + Vine Branch;
- Bloom + Pruning Core, Spore + Fruit Branch.

### 24.3 Progression checkpoints

| Point | Expected state |
|---|---|
| Wave 1 | Core 1 base plus early ranks |
| Wave 3 | Both Core bases and 6-8 total purchases |
| Wave 6 | 11-14 purchases; Evolution close or READY for a focused build |
| Wave 9 | 17-21 purchases; focused build has claimed Evolution |
| Wave 13 | 24-28 purchases; Branch 1 developed and Evolution active |
| Wave 18 | 33-38 purchases; four Adaptations active and at least one mastered |
| Wave 25 | 42-47 purchases; two or three mastered Adaptations, remaining lines partial |

Fully mastering one Adaptation should be common. Mastering two should be achievable. Mastering all four plus Evolution should require exceptional progression.

## 25. Performance validation

Four base mechanics and up to 48 ordinary ranks can run simultaneously. Treat this as a new performance surface.

Required scenarios:

- all four owned Adaptations at rank 0;
- one Adaptation fully mastered at 12 ranks;
- all 16 ordinary lines at rank 3;
- maxed Core Evolution plus both Branch bases;
- Plant relic plus four Adaptation relic pools active;
- killable churning crowd with Spore, Bloom, Fruit, and Thistle;
- persistent Vine with Fruit collisions and Thistle projectiles;
- Root Network queries supporting all three other owned Adaptations.

Maintain:

- 130 active-enemy cap;
- existing entity caps for Fruiting Bodies, Thistles, Fruit fragments, and relic-generated objects;
- generated-event source tags and recursion guards;
- global generated-event scheduler budgets from the relic system.

The reduced rank-3 maxima should lower peak projectile, Fruit, Vine, and propagation counts relative to rank 5, but four fully developed Adaptations may still overlap more systems than the old three-Adaptation structure.

## 26. Player-facing text

Core selection:

```text
Choose your first Core Adaptation.
Your two Core Adaptations determine your Evolution.
```

Branch selection:

```text
Choose a Branch Adaptation.
Branches add new mechanics and relics but do not change your Evolution.
```

Focus:

```text
Focus Adaptation
At least one upgrade from this Adaptation will appear in each ordinary upgrade offer.
```

Evolution READY:

```text
EVOLUTION READY
You mastered two lines in each Core.
Spore + Root can become Seed Bank.
```

Adaptation mastery:

```text
BLOOM MASTERED
All Bloom upgrades have reached rank 3.
```

Avoid referring to ordinary lines as separate Adaptations. The Adaptation is the base system; the four lines develop it.

## 27. Implementation order

1. Update `RunAdaptationState` for four owned Adaptations and rank-3 ordinary lines.
2. Convert ownership checks to `owns_adaptation`.
3. Implement the all-roster Adaptation chooser.
4. Expose all four ordinary lines on acquisition.
5. Clamp ordinary line maximums to 3 while preserving per-rank values.
6. Implement Cultivation Focus and the guaranteed Focus offer slot. *(Implemented, then removed 2026-09-04; see the note on section 10.)*
7. Replace upgrade-slot draft logic with owned-line candidate generation.
8. Freeze Evolution from the Core pair.
9. Require two mastered lines in each Core for readiness.
10. Preserve five-rank authored Evolution progression.
11. Remove Evolution's slot grant and the tertiary support reward.
12. Add Branch 1 and Branch 2 milestone rewards.
13. Restore the integer Spore Seed Production threshold.
14. Restore Thistle's five-turret distinct-line progression.
15. Update HUD rows to three rank pips and add Focus/mastery presentation.
16. Update relic pool eligibility and Core-only terminology.
17. Implement schema-version-3 save migration.
18. Add telemetry and automated tests.
19. Run 28 Evolution tests, 420 roster state tests, and curated four-Adaptation performance fixtures.

## 28. Explicitly removed behavior

The following behavior must no longer exist in the main Campaign:

- unlimited permanent Adaptation ownership;
- more than four permanently owned Adaptations;
- five ordinary ranks per line;
- permanent 2-of-4 line selection;
- locked ordinary lines;
- a mandatory specialization screen after Adaptation acquisition;
- support as a special post-Evolution tertiary slot;
- support acquisition through one free rank-1 card;
- Evolution granting additional upgrade slots;
- Branch Adaptations changing the Evolution pair;
- multiple Evolutions from the four owned Adaptations;
- temporary Clover ranks creating ownership, relic eligibility, mastery, or Evolution progress;
- player-facing Biomass as a relic-exhaustion reward.

The completed structure lets the player master an Adaptation completely while preserving meaningful run-level choices through the four-Adaptation roster, Core pair, Evolution, investment order, Focus, and relics.
