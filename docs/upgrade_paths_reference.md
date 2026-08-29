# Upgrade Path Reference

Every base weapon/Adaptation, ordinary upgrade line, and pair Evolution currently
implemented in the game. Values are cross-checked against the live progression,
combat, and element directors. Numbers are the current `@export` defaults; where the
playable scene overrides a script default, that override is stated explicitly.

## How a build is assembled

A run picks **two paths** — primary and secondary — out of eight. Those two decide
which Evolution the run can reach, and the pairing is frozen once claimed.

1. **Draft upgrade lines.** Every ordinary line ranks 1 → 5
   (`maximum_upgrade_level = 5`).
   A run may have **8 different lines** started at once (`upgrade_slot_count`);
   once all eight slots are occupied, only lines already started are offered.
2. **Master one line in each of the two paths.** Taking any single line of the
   primary and any single line of the secondary to rank 5 sets the Evolution to
   READY (`_has_maxed_path_line`, `phase_b_progression.gd:1285`).
3. **Claim the Evolution.** It appears in the draft as its own option. Claiming it
   immediately grants rank 1 of that Evolution's line and grants **+5 upgrade slots**
   (`evolution_bonus_upgrade_slots`), so all 13 Adaptation positions can run at once:
   eight paired-path lines, one Evolution line, and four support-path lines.
4. **Root a support upgrade.** Only after evolving does a **tertiary** slot open
   (`is_tertiary_path_available`). Its reward offers real rank-1 upgrades from
   unused paths; choosing one commits that upgrade's path as Support. The support
   path never joins the pairing — no
   second Evolution and no three-way pairing can ever form.

Two other things reach these lines from outside the draft:

- **Clover jackpots** lend a lit path its rank-5 ceiling for their duration
  (`casino_upgrade_level = 5`). This is additive to owned ranks: an owned rank 5
  line behaves as rank 10 during the jackpot, rank 4 as rank 9, and an unowned line
  as rank 5. The loan does not grant path ownership, upgrade slots, or relic access.
- **Relics** modify path mechanics without occupying an upgrade slot; they are
  catalogued separately in [relics.md](relics.md).

## Universal base weapon: Cane

Every run starts with Cane. It has **no upgrade lines**, so the universal weapon no
longer adds draft clutter or consumes an upgrade slot.

- **Behavior:** automatically sweeps a fixed **90° frontal sector** every **0.72s**,
  centered on the player's current facing. It reaches **92 px**, alternates its
  visible left-to-right/right-to-left stroke, executes even into empty space, and
  hits every unobstructed enemy in the sector once. It is an area attack and creates
  no projectile.
- **Base damage:** **24** to every enemy hit.
- **Vine exception:** selecting Vine turns the stroke green and replaces facing aim
  with deterministic auto-targeting. It chooses the in-reach, unobstructed 90°
  sector containing the most enemies; ties prefer the nearer/tighter cluster and
  then the direction closest to facing.

## Base damage at a glance

“No direct damage” means the mechanic can still amplify another attack, apply a
status, spread territory, or gain damage through an Evolution/relic.

| Source | Base behavior and direct damage |
|---|---|
| **Cane** | 24 per enemy in its 90°/92 px sweep |
| **Spore / Seed** | Seed growth deals 0 direct damage; Overgrown deals 25% target max HP per second for 4s |
| **Bloom** | Up to 40 at the center of the normal radial blast, falling to 48% at its edge |
| **Bramble** | 0.18 + 0.05% target max HP per 0.45s thorn tick; 1.0 on first developed-hedge crossing |
| **Root** | 0 direct damage; locally amplifies compatible effects from Mature Green |
| **Pruning** | 26 per ring-contact bite and 26 per launched Cutting |
| **Thistle** | 12 per thorn; each impact rolls its own 2× critical chance |
| **Vine** | Uses Cane's 24 base damage; Lignification/Apical Dominance scale that sweep |
| **Fruit** | 36 per collision and up to 10 from the terminal burst |

---

## The eight paths

### Spore

> Seed catalysts turn kills into deliberate bursts of new Green.

Base behavior: when Spore is active, every **5 kills** creates a Seed at the death
site. A Seed charges and then germinates into Green; Root can shorten that charge on
mature ground. Enemies standing on owned Green gain **5% Spore per second**;
at 100% they become Overgrown and lose 25% of max HP per second for four seconds.
Spore has no flat base hit: its damage is the **25% max-health-per-second Overgrown
effect**. Overgrown contagion is 10% Spore/second in 60 px and its death burst is
60% Spore in 80 px. The optional Spore Burst relic adds **24 damage** in an 84 px
radius at Growth Mass 1.
The base epidemic, Seed production, and germination all work before any Spore line
is purchased. The lines below tune those systems; they do not switch the base
Spore loop on.

| Line | Per rank | At rank 5 |
|---|---|---|
| **Seed Production** | One fewer kill required per Seed | 5 kills → 2 |
| **Growth Mass** | +24% Seed growth mass | +120% |
| **Sporulation** | +25% Spore accumulation rate | +125% |
| **Fruiting Bodies** | +10pp chance an internal germination raises a colony | 50% |

Spore is the only path whose mechanics run before any of its lines are taken. While
Spore is active, enemies standing on owned Green accumulate **5% Spore per second**;
at 100% they become **Overgrown** and lose **25% of max HP per second**, dying four
seconds later. Sporulation multiplies only the accumulation rate. Overgrown applies
identically to bosses and elites — no cap, no resistance — so the gate is reaching
100%, not the damage after it.

Overgrown is also how Spore scales into dense packs. A dying Overgrown enemy emits a
**Contagion Aura** — 10% Spore/sec in 60 px, so 40% over its four-second lethal phase
— and on death an **80 px burst for 60% Spore**. Forty plus sixty is a hundred: an
enemy that stays beside an Overgrown one for its whole death throes becomes Overgrown
itself, with no Seed and no Fruiting Body involved. That is the epidemic loop, and it
is why both numbers are deliberately **exempt from Root Potency** — amplifying a
self-propagating loop's own feedback term makes it untunable.

A **Fruiting Body** is raised when a Seed germinates on ground the run already owns
and the chance roll succeeds. Every colony behaves identically whatever rank raised
it: a 30% Spore cloud in 60 px at 3s, 6s and 9s, then at 12s a 75% Spore rupture in
80 px that scatters 2 Seeds. At most 20 exist at once — the entity pool is the cap.

Seed Production starts at `baseline_seed_kill_threshold = 5` and clamps at
`minimum_seed_kill_threshold = 2`, so **the line is fully spent at rank 3** —
ranks 4 and 5 buy nothing. Worth knowing before drafting it to 5 for the Evolution
gate; Growth Mass is the cheaper line to master for that purpose.

### Bloom

> Periodic radial surges reclaim space and convert hostile territory.

Base behavior: Bloom plants a charge on the Green frontier after a **4-second first
delay**, then repeats every **15 seconds in the playable scene** (the script default
is 13 seconds). After a 0.65-second wind-up it detonates, applying territory
pressure and enemy damage in its radius, then throws six physics-based droplets
that spread the Bloom's material. Droplets can cross neutral/hostile Green and
bounce from obstacles; Bloom Frequency shortens the cadence and Bloom Force makes
the detonation stronger.
Base damage: the center of a normal Bloom deals **40 damage** before Bloom Force,
Root Network amplification, and distance falloff. Droplets are territory payload;
they do not have a separate enemy-damage value.

| Line | Per rank | At rank 5 |
|---|---|---|
| **Bloom Force** | +25% Bloom pressure and damage | +125% |
| **Bloom Frequency** | 14% shorter interval (×0.86) | ~47% shorter |
| **Aftergrowth** | +8 temporary control on Bloomed Green for 4s | 40 |
| **Suppression** | −8pp Territory damage from Bloom-struck enemies for 4s | −40% |

Aftergrowth and Suppression are one four-second **tempo window** seen from two sides.
Every Bloom lays a disposable control buffer over the Green it touches and makes the
enemies it struck worse at eating Green. The shield is stored apart from real control,
so consuming it is never a territory loss, never costs maturity, and never changes
ownership; damage order is **suppress → shield → Green (with Mature Strength)**.
Neither line touches Bloom damage, radius, pressure, conversion, or maturity — those
stay Bloom Force's and Root's.

### Bramble

> Your Green entangles, slows, roots, and repels whatever stands on it.

Base behavior: enemies touching owned Green accumulate Entanglement. At full
Entanglement, they are slowed and periodically rooted; Bramble applies its
frontier-resistance multiplier and shoves enemies back when they damage Green. In
the playable scene the base values are **10% slow**, **1.0x frontier resistance**,
**0.35s roots**, and **26 px repulsion**. The base Entanglement build multiplier is
1.0x; the upgrade lines increase the slow, build rate, root duration, or shove
distance. Bramble has no independent timer or spawned pool.
Base thorn contact damage is **0.18 + 0.05% of the enemy's max health per tick**,
every **0.45 seconds**; at full Entanglement it is multiplied up to **3.0x**. A
first crossing of a developed frontier hedge also deals **1.0 damage**; hedge
strength can add up to **60%** to contact damage, while nearby attackers add **8%
each**, capped at **60%**.

| Line | Per rank | At rank 5 |
|---|---|---|
| **Entanglement** | +5pp slow and +10% Bramble-applied Entanglement potency | +25pp slow, +50% potency |
| **Ensnare Rate** | +10% faster Entanglement build-up on your Green | +50% |
| **Grasping Roots** | +0.35s root on enemies reaching full Entanglement | +1.75s |
| **Repulsion** | +16 px knockback when an enemy damages your territory | +80 px |

### Root

> Age Green into a Root Network that amplifies everything else your build does.

Base behavior: Root exposes Maturation Speed, makes Mature Green harder to erode,
and lets damaged Green regrow control. Mature ground also publishes a local
Root Network multiplier: the script starts at **1.30x on fully Mature ground**
(1.0x on fresh ground), before Root Potency ranks and relic bonuses. That multiplier
is sampled where an effect happens, so it can strengthen Seed mass and germination
speed, Bloom force and cadence, Bramble effects, Pruning Cuttings, Thistle shots,
Vine sweeps, and Fruit launched from that ground. Root does not spawn an entity or
run on its own cadence.
Root has **no direct damage value**. It amplifies damage authored by other systems
when they occur on mature ground.

| Line | Per rank | At rank 5 |
|---|---|---|
| **Maturation Speed** | +22% territory maturation rate | +110% |
| **Biomass Yield** | +20% Biomass from Mature Green | +100% |
| **Mature Strength** | +16% Mature resistance, +0.008 control/s regrowth | +80%, +0.04/s |
| **Root Potency** | +22% Root Network amplification from Mature ground | +110% |

Root Potency is the one line that scales other paths rather than itself. Every
consumer asks `root_director.get_network_multiplier_at(position, maturity)`, so the
amplification is read where the effect happens and is scaled by the age of the ground
under it — fresh Green gets nothing at any rank.

| Amplified | Path | Site |
|---|---|---|
| Seed inherited growth mass | Spore | `phase_b_spore_director.gd` |
| Germination speed (Seed charge time) | Spore | `get_germination_seconds_at` |
| Bloom Force | Bloom | `on_bloom_detonated` |
| Bloom cadence (interval to the next Bloom) | Bloom | `advance` |
| Entanglement accrual rate | Bramble | `_get_entanglement_rate` |
| Bramble tick damage | Bramble | `get_bramble_tick_damage` |
| Repulsion knockback distance | Bramble | `repel_territory_attacker` |
| Spore accumulation rate | Spore | `_update_enemy_spore` |
| Fruiting Body cloud and rupture Spore | Spore | `_get_fruiting_body_spore` |
| Cutting damage | Pruning | `_raise_cuttings` |
| Deadfall Volley spike damage | Pruning | `_fire_deadfall_volley` |
| Thorn damage | Thistle | firing turret position |
| Cane/Vine damage | Vine | player position at sweep start |
| Collision, terminal damage, and territory area | Fruit | Fruit launch origin |

Pruning is the one path measured over a patch rather than at a point: a harvest cuts
many cells at once, so its Root maturity is the **Mature share of the cut**
(`harvest.mature_cell_count / harvest.cell_count`) rather than the maturity left
behind, which the harvest has already removed. Cutting damage is the hook, not
Cutting yield — yield from Mature ground is COPPICING's identity, and amplifying it
here would blur the Evolution. The orbiting ring's own contact damage is deliberately
left alone: the player prunes the ground beneath them, so by the time the ring sweeps
it that ground is freshly cut and would read almost no maturity.

The line carries a `base_network_bonus` of 0.30 that applies at rank 0, so owning Root
at all is worth +30% on fully Mature ground before any Potency rank is bought, rising
to +140% at rank 5. Two relics, Annual Rings and Seedbed, add further Root Potency
locally inside their own regions, on top of the run-wide bonus.

### Pruning

> Burn the Green under your feet into an orbiting ring of blades.

Base behavior: while the player stands on owned Green, the ring harvests a tight
patch beneath them and converts the removed ground into Cuttings. Cuttings gather
into an orbiting ring of up to **16**, deal contact damage, and are launched as the
ring cycles. Holding the ring builds Charge for **8 seconds**; releasing it pays out
a stronger launch, but harvesting continuously drains the ecosystem. In the
playable scene the base harvest drain is **15 cells/second** and its hold escalation
is **5 cells/second²** (script defaults are 9 and 0.8). Pruning stops at its safety
floor and lets the cut ground reclaim after release.
Base damage: each Cutting deals **26 damage**, and the ring's direct contact pass
also deals **26 damage**, before Cutting Edge, Charge, Root Network, and pierce
falloff. A normal Cutting pierces **2 enemies**.

| Line | Per rank | At rank 5 |
|---|---|---|
| **Harvest Rate** | +18% harvest rate | +90% |
| **Cutting Yield** | +22% Cuttings from the same harvested ground | +110% |
| **Cutting Edge** | +30% ring and Cutting damage | +150% |
| **Charge** | +22% Charge rate and launch payout | +110% |

### Thistle

> Supported Green grows stationary damage turrets that track and fire on enemies.

Base behavior: selecting Thistle maintains **2 permanent turrets** on owned Green.
Each attacks every **1.10s**, targets unobstructed enemies within **240 px**, and
fires a **460 px/s** thorn with a **1.15s** lifetime. Losing the supporting Green
destroys the turret immediately unless ROOTSTOCK supplies its three-second grace.
Turrets consume no Green. Starting a distinct Thistle line raises the permanent cap:
two started lines allow 3 turrets, three allow 4, and all four allow the maximum 5.

Base damage: **12 per thorn**. Base critical chance is 0%; Needlepoint adds chance
and every impact—including each Burr ricochet—rolls independently for **2× damage**.
Ricochets deal full damage and cannot revisit an enemy in the same chain.

| Line | Per rank | At rank 5 |
|---|---|---|
| **Clustering** | +1 thorn per firing event | 6 total thorns |
| **Dehiscence** | +15% attack speed | +75%; 1.10s → 0.629s interval |
| **Burr** | +1 full-damage ricochet target per thorn | 5 ricochets (6 total hits possible) |
| **Needlepoint** | +10 percentage points critical chance | 50% chance at 2× damage |

Clustering distributes its projectiles across distinct available targets before
wrapping. Dehiscence divides the base interval by `1 + 0.15 × rank`; it is not a
flat subtraction. Root Potency samples the maturity under the firing turret and
multiplies thorn damage there.

### Vine

> Cane grows into a long, green, high-damage directional lash.

Base behavior: Vine modifies the universal Cane rather than spawning a second
weapon. It keeps Cane's **0.72s** cadence, **92 px** reach, fixed **90° sector**, and
hit-every-enemy-once resolution. Vine strokes automatically aim at the targetable
sector containing the most enemies instead of requiring the player to face it.
Range and basalt line-of-sight are part of that decision. The visible shaft, tip,
and sector telegraph are green.

Base damage: **24 per enemy**, inherited from Cane. The normal Apical zone is the
outermost **25%** of current reach. Root Potency multiplies Vine damage when the
sweep starts from Mature Green.

| Line | Per rank | At rank 5 |
|---|---|---|
| **Elongation** | +20% reach | +100%; 92 px → 184 px |
| **Lignification** | +25% damage | +125%; 24 → 54 before Apical/Root/relics |
| **Turgor** | +15% attack speed | +75%; 0.72s → 0.411s interval |
| **Apical Dominance** | +25% damage in the outer 25% | +125%; 2.25× the post-Lignification hit at the tip |

Elongation and Lignification are additive from their base (`1 + per-rank bonus`).
Turgor divides cooldown by its speed multiplier. Apical Dominance multiplies the
already Lignified/Root-amplified hit and never widens the 90° arc.

### Fruit

> Heavy rolling Fruit bowls through enemies, paints a corridor, then becomes the
> planted Fruit that bursts into a terminal territory foothold.

Base behavior: one Fruit launches toward the targetable **90° sector with the most
enemies**. It starts at **300 px/s** and decelerates continuously to zero; the base
unobstructed stopping distance is **320 px**. It never despawns because a distance
counter elapsed. Enemy collisions deal damage/knockback and reduce actual velocity;
ordinary collision momentum loss starts at **32%** and is weighted by enemy mass.
Obstacles reflect the roll while preserving **55%** momentum. Each collision applies
**38 px knockback** before mass resistance.

The roll stamps immature Green every **20 px** (0.18 mass, 0.60 pressure cells,
1.30-cell radius before Germination scaling). At velocity zero, the same Fruit art
remains planted for a **0.5s fuse**—it does not turn into the Fruitseed image—then
explodes into territory. The base terminal growth multipliers are **0.85 mass**,
**0.70 pressure**, and **0.85 hostile conversion**. Its damage/evolution effect
radius is **72 px** before area scaling. `fruitseed.png` is used only by the
legendary Dropped Seed relic.

Base damage: **36 per enemy collision** plus up to **10 terminal explosion damage**
at the center (standard radial falloff reaches 48%, or 4.8 damage, at the edge).
Ripening and Root Network scale both values. Graft, Prize Fruit, Bank Shot, Durian,
and first-collision bonuses modify collision damage only.
The next release's **1.0s cooldown begins only after every normal Fruit and fragment
from the previous release has exploded**; legendary Dropped Seeds do not hold it.

| Line | Per rank | At rank 5 |
|---|---|---|
| **Fruit Set** | +1 Fruit per release | 6 total Fruit |
| **Ripening** | +25% collision and terminal damage | +125%; 81 collision, 22.5 terminal center |
| **Momentum** | +20% unobstructed roll distance | +100%; 320 px → 640 px |
| **Germination** | +20% total Fruit-created Green area | +100%; 2× trail/terminal area budget |

Multiple Fruit fan around the dense-sector aim rather than sharing one exact line.
Germination scales total area: mass/pressure scale linearly and radii use the square
root of the area multiplier. Every Fruit owns its own trail-spacing accumulator, so
all trajectories paint even inside one multi-Fruit release. Each normal Fruit chooses
one of the six supplied watermelon, red-apple, peach, orange, lemon, and strawberry
paintings using the run-seeded adaptation RNG; its planted state keeps that painting.
Bloom, Seed, all six Fruit paintings, and the relic-only Fruitseed painting use the
same deliberately visible watercolor-granulation material.

---

## Build matrix

Twenty-eight pairings, one Evolution each. Pairing is symmetric: primary/secondary
order does not change the result. A tertiary support Path never changes it.

| | Spore | Bloom | Bramble | Root | Pruning | Thistle | Vine | Fruit |
|---|---|---|---|---|---|---|---|---|
| **Spore** | — | SUPER BLOOM | BRIAR PODS | SEED BANK | PIONEER | INOCULATOR | MYCELIAL VINE | ROT |
| **Bloom** | SUPER BLOOM | — | THORNBURST | FLOWERING SEASON | REBOUND | BURSTBLOOM | WISTERIA | OVERRIPE |
| **Bramble** | BRIAR PODS | THORNBURST | — | OLD GROWTH | DEADFALL | HEDGE BATTERY | BRIAR CANE | DURIAN |
| **Root** | SEED BANK | FLOWERING SEASON | OLD GROWTH | — | COPPICING | ROOTSTOCK | HEARTWOOD | ORCHARD |
| **Pruning** | PIONEER | REBOUND | DEADFALL | COPPICING | — | DEADHEADING | ESPALIER | GRAFT |
| **Thistle** | INOCULATOR | BURSTBLOOM | HEDGE BATTERY | ROOTSTOCK | DEADHEADING | — | THORNWHIP | BURDOCK |
| **Vine** | MYCELIAL VINE | WISTERIA | BRIAR CANE | HEARTWOOD | ESPALIER | THORNWHIP | — | GOURDVINE |
| **Fruit** | ROT | OVERRIPE | DURIAN | ORCHARD | GRAFT | BURDOCK | GOURDVINE | — |

---

## Evolution lines

Each Evolution has authored, non-uniform ranks. For the original ten pairings, the
claim establishes the base Evolution and unlocks a separate five-purchase line. For
the eighteen Thistle/Vine/Fruit pairings, the claim itself is **rank 1** and four
later purchases advance it through ranks 2–5. The draft always names the exact next
rank effect and `get_upgrade_maximum_level()` enforces the correct ceiling.

### Evolution damage baselines

These are the damage values before the Evolution rank effects and other path
modifiers. Evolutions that reuse a path attack inherit that attack's base damage.

| Evolution | Base damage |
|---|---|
| **SUPER BLOOM** | Chained Blooms inherit Bloom's **40 damage**, then use the base 1.22× chained-Bloom multiplier |
| **BRIAR PODS** | No separate flat hit; pod contact uses Bramble's thorn damage at **1.5×** |
| **SEED BANK** | Rootburst deals **35% of current standard-enemy max HP** and applies 50% Spore |
| **THORNBURST** | Briar Trap deals **46 damage**, with up to +80% from fully Mature harvested ground |
| **FLOWERING SEASON** | Season Blooms inherit Bloom's **40 damage**; Echo Blooms use 35% Force |
| **OLD GROWTH** | Root eruption deals **34 damage** before age scaling |
| **PIONEER** | Buried Seeds have no separate hit; they use normal Seed germination |
| **REBOUND** | Elastic Rebound's second wave deals **34 damage** before its Force scaling |
| **DEADFALL** | Deadfall spikes use the **26-damage Cutting** base, then the authored 1.6× volley scale |
| **COPPICING** | No separate damage; it modifies Cuttings and regrowth |
| **INOCULATOR** | Thistle still deals **12/thorn**; Spore application adds no direct hit damage |
| **BURSTBLOOM** | **12/thorn** plus a 35%-Force Bloomshot: up to **14** Bloom damage (20 at rank 4's 50% Force) |
| **HEDGE BATTERY** | **12/thorn**; rank 2 adds 20% against fully Entangled targets (**14.4**) |
| **ROOTSTOCK** | **12** ordinary thorn; Heavy Thorn is **18** (1.5×) before Root/crit |
| **DEADHEADING** | Bonus volleys inherit **12/thorn**; Charge can scale them and rank 4 repeats at 60% |
| **THORNWHIP** | Every mounted shot inherits the **12-damage Thistle thorn** and its projectile upgrades |
| **BURDOCK** | **36** Fruit collision + **12** per carried thorn + up to **10** terminal burst |
| **MYCELIAL VINE** | **24** Cane/Vine; rank 4 adds 20% (**28.8**) at ≥50% Spore; rank 5 also deals max-HP collapse damage |
| **WISTERIA** | **24** Vine plus blossoms up to **14** each at 35% Bloom Force; tip is **28** at 70% Force |
| **BRIAR CANE** | **24** Vine; rank 2 adds 20% (**28.8**) against fully Entangled targets |
| **HEARTWOOD** | **24** normal Vine; every fifth is **36** at 1.5×; rank-5 Root Echo is **14.4** at 60% |
| **ESPALIER** | **26/Cutting** plus a rank-3 bonus **24-damage Vine** sweep; Charge can scale both authored packets |
| **GOURDVINE** | **24** Vine + **36** Fruit collision + **10** terminal center; attached Apical Fruit hit is **18** at rank 2 |
| **ROT** | **36** collision + **10** terminal center; added Spore effects deal no separate flat hit |
| **OVERRIPE** | **36** collision + **10** terminal; 25%-Force Bruise is **10**, terminal Bloom **26** (or **32** at rank 4) |
| **DURIAN** | **36** collision + **10** terminal; rank-3 full-Entanglement collision is **45** |
| **ORCHARD** | Each Fruit keeps **36** collision + **10** terminal center; Saplings add no direct damage themselves |
| **GRAFT** | Starts from **36** collision + **10** terminal; +3%/Cutting and Prize Fruit scale collision only, while rank 2/Prize scale territory area |

### SUPER BLOOM — Spore + Bloom
*Germinating Seeds arm a Bloom that can chain into more Seeds.*
Line: **Floral Cascade**

| Rank | Effect |
|---|---|
| 1 | **Cascade Force** — chained Blooms keep +15% Force |
| 2 | **Deep Cascade** — chains propagate one generation further |
| 3 | **Forced Germination** — every 4 Super Blooms germinate a Seed |
| 4 | **Cascade Force II** — another +15% chained Bloom Force |
| 5 | **Grand Bloom** — every 6 Super Blooms erupt at 1.8× scale |

### BRIAR PODS — Spore + Bramble
*Germinating Seeds raise temporary thorn perimeters.*
Line: **Tangleburst**

| Rank | Effect |
|---|---|
| 1 | **Tangled Germination** — germination applies 15% Entanglement |
| 2 | **Grasping Shoots** — germination roots already-Entangled enemies (≥70%, 0.35s) |
| 3 | **Constricting Growth** — germination drags nearby enemies inward (26 px) |
| 4 | **Aggressive Growth** — fresh Seed ground ensnares far faster (+50% for 3s) |
| 5 | **Mass Entanglement** — every 5 Seeds pin a whole mob (50% elites, 20% bosses) and seed it with 35% Spore |

### SEED BANK — Spore + Root
*Mature ground banks Seeds and drops them onto the mob as bursts.*
Line: **Seed Reserve**

Claiming it fires a free **6-Seed Season** at once. From then on a **Germination
Season** runs every **8 seconds**, spending whatever the Bank has stored. Season Seeds
are placed on enemies standing in your Green — densest cluster first — and each one
**Rootbursts** as it opens: **70 px**, damage worth **35% of a standard enemy's max
HP**, and **50% Spore**, both amplified by Root Potency. Anything a Rootburst pushes
to 100% Spore suffers **Fungal Collapse**: normal enemies die on the spot (still
firing their Overgrown death burst), elites take 50% max HP and turn Overgrown,
bosses take 15%.

| Rank | Effect |
|---|---|
| 1 | **Expanded Reserve** — +50% Seed Bank capacity |
| 2 | **Heavy Seeding** — Seeds bank 50% faster |
| 3 | **Rootburst** — Season bursts deal +40% damage at +20% radius |
| 4 | **Fungal Reserve** — every 3 Seeds released raise a guaranteed Fruiting Body that clouds immediately |
| 5 | **Mast Year** — every Season fires a second full-strength wave 1.5s later |

### THORNBURST — Bloom + Bramble
*Blooms harvest the Bramble they claim into cascading Briar Traps.*
Line: **Briar Payload**

| Rank | Effect |
|---|---|
| 1 | **Packed Thorns** — +20% Briar Traps per harvest |
| 2 | **Sensitive Traps** — +20% trigger radius |
| 3 | **Barbed Blast** — trap blasts apply 35% Entanglement |
| 4 | **Chain Fuse** — +20% trap-to-trap chain range |
| 5 | **Briar Heart** — every 5 traps becomes a repeating blast |

### FLOWERING SEASON — Bloom + Root
*Mature ground builds toward mass flowerings that spend maturity for Blooms.*
Line: **Seasonal Surge**

| Rank | Effect |
|---|---|
| 1 | **Spring Pressure** — +15% Flowering Bloom Force |
| 2 | **Encroachment** — +20% conversion against hostile ground |
| 3 | **Distributed Flowering** — Blooms spread across the frontier |
| 4 | **Spring Pressure II** — another +15% Bloom Force |
| 5 | **Second Spring** — 4 Echo Blooms follow every Season (at 35% Force) |

### OLD GROWTH — Bramble + Root
*Entangled enemies on ancient ground trigger chaining root eruptions.*
Line: **Ancient Fury**

| Rank | Effect |
|---|---|
| 1 | **Deep Eruption** — +15% eruption radius |
| 2 | **Thorned Roots** — eruptions Entangle survivors (30%) |
| 3 | **Root Cascade** — eruption kills erupt again at 70% damage |
| 4 | **Restless Forest** — erupts at 85% Entanglement instead of full |
| 5 | **Forest Awakening** — 6 Entangled enemies wake 6 eruptions (10s cooldown) |

### PIONEER — Spore + Pruning
*Pruned Ground fills with dormant Seeds that all germinate together.*
Line: **Second Flush**

| Rank | Effect |
|---|---|
| 1 | **Dense Reseeding** — +20% Seeds buried in cut ground |
| 2 | **Rapid Germination** — buried Seeds erupt 15% sooner |
| 3 | **Fertile Cut** — Seeds on cut ground carry +20% Growth Mass |
| 4 | **Blood and Soil** — Cutting kills bury up to 6 more Seeds |
| 5 | **Second Flush** — every 3 eruptions a second wave at 50% |

### REBOUND — Bloom + Pruning
*Green collapses into a Bloom before it detonates, then explodes outward.*
Line: **Compression**

| Rank | Effect |
|---|---|
| 1 | **Efficient Compression** — +15% Force per cell collapsed |
| 2 | **Elastic Growth** — the collapsed ground reclaims far faster |
| 3 | **Inward Collapse** — the compression drags enemies in first (46 px) |
| 4 | **Efficient Compression II** — another +15% Force per cell |
| 5 | **Elastic Rebound** — a second wave at 45% Force after 1.25s |

### DEADFALL — Bramble + Pruning
*Pruning thorned Green turns its Bramble into a storm of spikes.*
Line: **Splinterstorm**

| Rank | Effect |
|---|---|
| 1 | **Thorn Harvest** — +20% Cuttings from thorned Green |
| 2 | **Piercing Splinters** — +1 Pierce at 60% damage |
| 3 | **Shatter** — Cuttings split on fully Entangled enemies (≥90%) |
| 4 | **Thorn Harvest II** — another +20% thorn Cuttings |
| 5 | **Deadfall Volley** — every cycle fires 8 heavy spikes (1.6× damage, 4 Pierce) |

### COPPICING — Root + Pruning
*Mature ground yields far more Cuttings and grows back fast.*
Line: **Stool Regrowth**

| Rank | Effect |
|---|---|
| 1 | **Mature Harvest** — +15% Cuttings from Mature ground |
| 2 | **Vigorous Regrowth** — cut Mature ground returns far faster (1.2×) |
| 3 | **Root Memory** — regrowth keeps 25% of its former maturity |
| 4 | **Mature Harvest II** — another +15% Mature Cuttings |
| 5 | **Second Harvest** — regrowth releases a second volley |

### INOCULATOR — Thistle + Spore
*Thistle becomes an automatic Spore-delivery network.*

| Rank | Effect |
|---:|---|
| 1 | **Inoculated Thorns** — every Thistle hit applies 4% Spore |
| 2 | **Burred Dose** — ricochet hits apply 6% Spore instead |
| 3 | **Septic Point** — critical hits apply an additional 8% Spore |
| 4 | **Concentrated Culture** — base hit application rises from 4% to 6% |
| 5 | **Forced Fruiting** — the first hit that pushes an enemy to 100% emits a 60% Spore pulse in 60 px, once per enemy; it does not prematurely kill the target |

Damage remains **12 per thorn** (24 on a 2× critical) before other modifiers.

### BURSTBLOOM — Thistle + Bloom
*A normal Bloom gives supported Thistles a timed explosive Bloomshot charge.*

| Rank | Effect |
|---:|---|
| 1 | **Bloomshot** — a Bloom touching a Thistle's supporting Green charges it for 4s; one primary thorn in every volley explodes on its first direct impact at 35% Bloom Force |
| 2 | **Lingering Charge** — charge duration rises to 6s |
| 3 | **Critical Bloom** — a critical direct Bloomshot hit gains 40% explosion radius |
| 4 | **Packed Pollen** — explosion strength rises to 50% Bloom Force |
| 5 | **Floral Salvo** — each normal Bloom immediately triggers one bonus volley from every Thistle it charges |

The timed charge persists for its full duration; firing does not consume it. Burr
ricochets from the designated thorn cannot make more explosions. At base Bloom
damage, the added blast deals up to **14** at 35% Force or **20** at 50% Force.

### HEDGE BATTERY — Thistle + Bramble
*Thistle fire builds and exploits Entanglement anywhere.*

| Rank | Effect |
|---:|---|
| 1 | **Suppressive Thorns** — hits apply 5% Entanglement, or 10% on owned Green |
| 2 | **Pinned Target** — fully Entangled enemies take +20% Thistle damage |
| 3 | **Barbed Precision** — critical hits apply another 8% Entanglement |
| 4 | **Suppressive Thorns II** — base application becomes 8%, or 16% on Green |
| 5 | **Crossfire** — the first Thistle hit on a fully Entangled enemy each second commands the nearest other Thistle to fire a bonus volley at it |

Rank-2 ordinary thorn damage is **14.4** against a fully Entangled target before
critical/Root modifiers.

### ROOTSTOCK — Thistle + Root
*Roots keep turrets alive briefly and load periodic heavy artillery.*

| Rank | Effect |
|---:|---|
| 1 | **Rooted Emplacement** — a turret keeps firing for 3s after losing Green support |
| 2 | **Stored Tension** — every fifth firing cycle replaces the primary thorn with a 1.5× Heavy Thorn and 34 px knockback |
| 3 | **Root Cannon** — Heavy Thorns pierce up to 2 normal enemies before any Burr ricochets; elites and bosses stop the punch-through |
| 4 | **Deep Chamber** — fully Mature owned Green loads a Heavy Thorn every fourth cycle |
| 5 | **Artillery Salvo** — every third Heavy Thorn across the whole network commands all active Thistles to fire one Heavy Thorn; shared 8s cooldown |

Ordinary thorns deal **12**; Heavy Thorns deal **18** before critical and local Root
Potency. The rank-5 counter is network-wide, not per turret.

### DEADHEADING — Thistle + Pruning
*Intentional Cutting releases command the turret network.*

| Rank | Effect |
|---:|---|
| 1 | **Cutback** — releasing at least 4 Cuttings triggers one bonus volley from every active Thistle |
| 2 | **Charged Cutback** — that volley inherits 35% of the current Pruning Charge damage bonus |
| 3 | **Sharp Regrowth** — Cutback volleys gain +1 Pierce |
| 4 | **Double Cutback** — a full-Charge release repeats after 0.4s at 60% damage |
| 5 | **Deadhead Flush** — a full-Charge release grows 2 temporary Thistles for 5s outside the normal five-turret cap |

Every projectile starts from the normal **12-damage** Thistle thorn and inherits
Clustering, Burr, Needlepoint, and Root Potency as applicable.

### THORNWHIP — Thistle + Vine
*Mounted Thistle heads fire through every automatic Vine sweep.*

| Rank | Effect |
|---:|---|
| 1 | **Grafted Heads** — 2 heads each fire once at valid enemies inside the current 90° sweep sector |
| 2 | **Distributed Graft** — add a third head |
| 3 | **Terminal Graft** — the outer head inherits the current Apical Dominance damage bonus |
| 4 | **Full Graft** — add a fourth head |
| 5 | **Raking Fire** — every mounted head fires twice per sweep |

Mounted shots use **12-damage** thorns and inherit Clustering, Burr, and Needlepoint;
they do not inherit Dehiscence because Vine owns their cadence.

### BURDOCK — Thistle + Fruit
*Every rolling Fruit carries a mobile Thistle head.*

| Rank | Effect |
|---:|---|
| 1 | **Armed Fruit** — one carried head fires automatically while Fruit rolls |
| 2 | **Mobile Battery** — carried shots inherit owned Thistle projectile upgrades |
| 3 | **Impact Fire** — a Fruit collision resets the head's timer, at most once every 0.5s |
| 4 | **Planted Battery** — terminal Fruit can leave a 5s temporary Thistle; maximum 2 Burdock temporaries |
| 5 | **Burr Burst** — immediately before stopping, fire a final volley with +2 ricochets and +50pp critical chance |

Damage packets are **36 collision**, **12 per carried thorn**, and up to **10** from
the terminal Fruit explosion before upgrades and other multipliers.

### MYCELIAL VINE — Vine + Spore
*The green auto-targeting Vine becomes a directional infection applicator.*

| Rank | Effect |
|---:|---|
| 1 | **Spore Lash** — every Vine hit applies 15% Spore |
| 2 | **Mycelial Tip** — Apical hits apply another 15% |
| 3 | **Vector Harvest** — Vine kills count as 2 kills toward Seed Production |
| 4 | **Diseased Tissue** — Vine deals +20% damage to enemies already at 50% Spore |
| 5 | **Fungal Snap** — an Apical hit against an already-Overgrown enemy collapses it: normal targets die with their normal burst, elites take 25% max HP, bosses 8% |

Base Vine damage is **24**; Diseased Tissue raises that packet to **28.8** before
Lignification, Apical, Root, and relic multipliers.

### WISTERIA — Vine + Bloom
*A normal Bloom arms the next automatic Vine sweep with flowering detonations.*

| Rank | Effect |
|---:|---|
| 1 | **Flowering Lash** — the armed sweep queues 3 blossoms along its direction, detonating sequentially at 35% Bloom Force |
| 2 | **Dense Raceme** — add a fourth blossom |
| 3 | **Terminal Blossom** — the outer blossom uses 70% Force and 1.35× radius |
| 4 | **Protected Flowering** — blossoms inherit 50% of owned Aftergrowth and Suppression |
| 5 | **Second Flowering** — repeat the sequence 0.75s later at 50% strength |

The original Bloom still happens. Blossoms are staggered by **0.10s** in sweep order.
At 40 base Bloom damage, ordinary blossoms deal up to **14**, the terminal blossom
**28**, and the rank-5 repeat deals half-strength packets.

### BRIAR CANE — Vine + Bramble
*The Vine builds Entanglement and sweeps pests radially away from Grandma.*

| Rank | Effect |
|---:|---|
| 1 | **Briar Lash** — hits apply 15% Entanglement, or 25% on owned Green |
| 2 | **Snared Target** — already-fully-Entangled enemies take +20% Vine damage |
| 3 | **Bramble Sweep** — those full targets receive 50% current Bramble Repulsion, or 100% on Green |
| 4 | **Tangled Tip** — Apical application becomes 30%, or 50% on Green |
| 5 | **Clear the Bed** — if the sweep hit a fully Entangled enemy, every hit enemy is repelled: 50% if not full, 100% if full, either 25% stronger on Green |

Base damage is **24**, or **28.8** against an already-full target before other
modifiers. Repulsion is away from Grandma, independent of visual sweep direction.

### HEARTWOOD — Vine + Root
*Every fifth Vine becomes an oversized woody super-sweep.*

| Rank | Effect |
|---:|---|
| 1 | **Heartwood Cycle** — every fifth sweep deals 1.5× damage at 1.15× reach |
| 2 | **Deep Grain** — the outer 40% of Heartwood reach counts as Apical |
| 3 | **Mature Feed** — a sweep starting on fully Mature Green advances the counter by 2 instead of 1 |
| 4 | **Reaction Wood** — the next opposite sweep arrives 40% sooner |
| 5 | **Old Heart** — after 0.3s, a Root Echo repeats the same sector at 60% Vine damage |

Before upgrades/Root Potency, normal damage is **24**, Heartwood is **36**, and its
Root Echo is **14.4**. A Heartwood hit cannot strike one enemy twice within that sweep.

### ESPALIER — Vine + Pruning
*Pruning's released ring is trained into Vine's forward geometry.*

| Rank | Effect |
|---:|---|
| 1 | **Training Frame** — Cuttings launch in a 90° forward fan centered on facing |
| 2 | **Long Training** — Cutting distance gains 50% of Vine's Elongation bonus |
| 3 | **Coordinated Release** — a fully charged release adds one bonus Vine sweep in that direction |
| 4 | **Tension Transfer** — the bonus Vine receives 50% of Pruning's Charge payout bonus |
| 5 | **Double Espalier** — a fully charged release adds a second Cutting fan after 0.5s at 60% damage |

Base packets are **26 per Cutting** and **24 per bonus Vine hit** before their
respective upgrade, Charge, and Root multipliers.

### GOURDVINE — Vine + Fruit
*A normal Fruit release rides the next automatic Vine and launches from its tip.*

| Rank | Effect |
|---:|---|
| 1 | **Weighted Harvest** — ready Fruit attach to the next automatic Vine and detach at full extension; Fruit Set still controls count |
| 2 | **Weighted Tip** — attached Fruit deal 50% normal collision damage to Apical enemies struck by the sweep |
| 3 | **Momentum Transfer** — detached Fruit gain 50% of Vine's Elongation bonus as roll distance |
| 4 | **Heavy Cane** — while armed, 25% of Ripening's bonus also applies to Vine's Apical damage |
| 5 | **Slingshot Harvest** — detached Fruit start 50% faster and their first collision deals +50% damage |

Fruit launch from the Vine tip toward the densest valid enemy sector. Base packets
are **24 Vine**, **18 attached-Fruit Apical** at rank 2, **36 rolling collision**, and
up to **10 terminal**.

### ROT — Fruit + Spore
*Fruit becomes a rolling fungal vector.*

| Rank | Effect |
|---:|---|
| 1 | **Moldy Fruit** — collisions apply 20% Spore |
| 2 | **Contaminated Ground** — Fruit Green accumulates Spore 50% faster for 4s |
| 3 | **Softened Hosts** — Fruit loses 50% less momentum against enemies already at 50% Spore |
| 4 | **Rotten Core** — terminal Fruit emits a one-time 40% Spore pulse in 80 px |
| 5 | **Fruiting Rot** — every third terminal raises a guaranteed Fruiting Body that performs its first cloud immediately; normal entity limits remain |

Direct damage remains **36 collision + up to 10 terminal** before Fruit modifiers.

### OVERRIPE — Fruit + Bloom
*Fruit becomes unstable explosive produce.*

| Rank | Effect |
|---:|---|
| 1 | **Overripe Burst** — terminal Fruit adds a 65%-Force Bloom before bursting into territory |
| 2 | **Bruising** — the first enemy collision creates a 25%-Force Bloom burst without stopping Fruit |
| 3 | **Juicy Detonation** — the terminal Bloom launches 3 droplets |
| 4 | **Packed Sugar** — terminal Bloom rises to 80% Force |
| 5 | **Split Fruit** — terminal Bloom launches 2 fragments; each rolls 40% normal distance and germinates, but cannot split or trigger Bruising |

At base values, collision is **36**, the Fruit terminal burst is up to **10**, Bruising
is up to **10 Bloom damage**, and the terminal Bloom is up to **26** (rank 4: **32**).

### DURIAN — Fruit + Bramble
*Rolling thorn Fruit builds Entanglement and clears its landing zone.*

| Rank | Effect |
|---:|---|
| 1 | **Spiked Fruit** — collisions apply 30% Entanglement |
| 2 | **Tangled Momentum** — Fruit loses 40% less momentum against Entangled enemies |
| 3 | **Impalement** — already-fully-Entangled enemies take +25% collision damage |
| 4 | **Thorned Trail** — fresh Fruit Green gains +50% Ensnare Rate for 4s |
| 5 | **Durian Crash** — terminal Fruit applies 60% Entanglement nearby and one full Bramble Repulsion outward |

Base collision is **36**, rank-3 collision is **45** against a full target, and the
base terminal explosion remains up to **10**.

### ORCHARD — Fruit + Root
*Terminal colonies become persistent Saplings and distributed launch points.*

| Rank | Effect |
|---:|---|
| 1 | **Sapling** — every fourth eligible Fruit terminal raises a Sapling; maximum 3 |
| 2 | **Rooted Colony** — nearby Green matures 30% faster and gains a small control-regrowth support pulse |
| 3 | **Distributed Harvest** — normal releases distribute the unchanged Fruit count between Grandma and active Saplings |
| 4 | **Perennial Roots** — unsupported Saplings remain dormant for 5s and reactivate if Green returns |
| 5 | **Bumper Crop** — every second normal release adds one Fruit per active Sapling, capped at 3 bonus Fruit; bonuses cannot raise Saplings |

Saplings deal **0 direct damage**. Every Fruit they launch retains **36 collision**
and up to **10 terminal** before upgrades/Root Potency.

### GRAFT — Fruit + Pruning
*Actual Cuttings from an intentional release become stock for the next Fruit batch.*

| Rank | Effect |
|---:|---|
| 1 | **Scion Stock** — a 4+ Cutting release grafts the first next Fruit; each stocked Cutting adds +3% collision damage, max 12/+36% |
| 2 | **Fertile Union** — each stocked Cutting adds +2% Fruit-created Green area, max +24% |
| 3 | **Hardy Union** — a graft with 8+ Cuttings loses 40% less enemy-collision momentum |
| 4 | **Multiple Scions** — a 12+ Cutting graft affects every Fruit in the next release |
| 5 | **Prize Fruit** — a full 16-Cutting ring makes the first next Fruit enormous: +50% collision damage, +50% knockback, +50% terminal Green area; it replaces rather than adds a Fruit |

At 12 stocked Cuttings, base collision rises from **36 to 48.96**. A Prize Fruit's
additional 1.5× raises that to **73.44** if both apply. Graft/Prize do not increase
the separate **10-damage** terminal explosion; Fertile Union/Prize increase territory
area instead. Stored stock is consumed by the next normal release even if a pool is full.

---

## Reading the matrix as builds

The pairings fall into three rough families:

- **Seed engines** — SUPER BLOOM, SEED BANK, PIONEER. Spore paired with anything
  that manufactures germination events. These builds win by covering the arena, and
  their damage is whatever the germinations happen to be carrying.
- **Crowd-control kill zones** — BRIAR PODS, THORNBURST, OLD GROWTH, DEADFALL.
  Bramble paired with anything that converts held enemies into damage. Entanglement
  is the currency; every one of these lines reads it.
- **Territory economy** — FLOWERING SEASON, REBOUND, COPPICING. Ground itself is
  spent and regrown for payouts. Root pairs here supply maturity; Pruning pairs
  spend it.
- **Turret networks** — INOCULATOR, BURSTBLOOM, HEDGE BATTERY, ROOTSTOCK,
  DEADHEADING, THORNWHIP, BURDOCK. Thistle contributes repeated 12-damage projectiles
  while its partner changes payload, timing, support, or mobility.
- **Directional lashes** — MYCELIAL VINE, WISTERIA, BRIAR CANE, HEARTWOOD, ESPALIER,
  GOURDVINE. These preserve Vine's automatic dense-sector 90° sweep while adding
  statuses or explicitly bounded bonus packets.
- **Kinetic territory** — ROT, OVERRIPE, DURIAN, ORCHARD, GRAFT. Fruit keeps its
  velocity/trail/terminal loop; the pairing changes what collisions and terminal
  bursts carry.

Root is the broadest amplifier. Root Potency multiplies compatible Spore, Bloom,
Bramble, Pruning Cutting, Thistle, Vine, and Fruit output where it originates on
Mature Green. ROOTSTOCK, HEARTWOOD, and ORCHARD add mechanics beyond that baseline
amplification; COPPICING separately specializes the Mature-ground harvest/regrowth
loop while launched Cutting damage still receives normal Root Potency.
