# Spore Path Additions — Current Playtest Baseline

This document defines the current implementation target for the two new Spore upgrade lines, **Sporulation** and **Fruiting Bodies**, plus the revised **BRIAR PODS** and **SEED BANK** Evolutions.

This version reflects late-wave playtesting where pure Spore + Root builds still struggled to survive large mobs. The main design conclusion is that damage over time alone is not enough to compete with burst-oriented builds such as Bloom and Pruning.

The revised direction is:

- **Base Spore** remains an infection and attrition engine.
- **BRIAR PODS** turns Bramble control into an outbreak containment engine.
- **SEED BANK** becomes a genuinely powerful burst-clear Evolution that converts stored Seeds and Mature Root territory into immediate mob deletion.

The ordinary Spore upgrade lines continue to follow the same structure as the other standard path upgrades: each rank improves one consistent numeric mechanic. Bespoke mechanics remain in the base system or Evolution lines.

---

# 1. Sporulation

> Enemies standing on Green gradually accumulate Spore. At full infection they become Overgrown, rapidly die, and spread infection through nearby enemies.

## Upgrade Line

| Rank | Spore accumulation bonus | Base accumulation rate |
|---|---:|---:|
| **0** | +0% | **5.00% Spore/sec** |
| **1** | +25% | **6.25% Spore/sec** |
| **2** | +50% | **7.50% Spore/sec** |
| **3** | +75% | **8.75% Spore/sec** |
| **4** | +100% | **10.00% Spore/sec** |
| **5** | +125% | **11.25% Spore/sec** |

**Per rank:** +25% Spore accumulation rate  
**At rank 5:** +125%

## Base Rules

- Sporulation is active at **rank 0 whenever the Spore path is active**.
- Enemies accumulate Spore while standing on player-owned Green.
- Spore buildup persists after leaving Green.
- Spore does **not decay**.
- Spore caps at **100%**.
- At 100%, the enemy becomes **Overgrown**.

## Overgrown

Once an enemy becomes Overgrown:

- Takes **25% max HP per second** as Spore damage.
- A full-health enemy dies from Overgrown alone in **4 seconds**.
- Emits a **Contagion Aura** while alive.
- Releases an **Overgrown Death Burst** on death.

### Contagion Aura

- Radius: **60 px**
- Applies **10% Spore/sec**
- Maximum duration: **4 seconds**
- Maximum total application to a nearby enemy: **40% Spore**

### Overgrown Death Burst

- Radius: **80 px**
- Applies **60% Spore**

### Epidemic Propagation

A nearby enemy that remains inside the Contagion Aura for the full Overgrown lifespan receives:

- **40% Spore** from Contagion
- **60% Spore** from the Death Burst
- **100% total Spore**

This allows one completed infection to create another completed infection.

Intended loop:

**Overgrown enemy → Contagion → death → Death Burst → nearby enemies hit 100% → new Overgrown enemies → outbreak propagates**

---

# 2. Fruiting Bodies

> Seeds germinating inside already-owned territory can become temporary fungal colonies that rapidly accelerate infection.

## Upgrade Line

| Rank | Fruiting Body chance |
|---|---:|
| **0** | 0% |
| **1** | **10%** |
| **2** | **20%** |
| **3** | **30%** |
| **4** | **40%** |
| **5** | **50%** |

**Per rank:** +10 percentage points Fruiting Body chance  
**At rank 5:** 50%

## Creation Rule

When a Seed germinates on already-owned Green:

- Roll the current Fruiting Body chance.
- On success, create a Fruiting Body at that germination site.
- Seeds germinating into unowned or hostile territory behave normally.

Recommended initial active Fruiting Body cap: **20**.

---

## Fruiting Body Lifecycle

| Time | Event |
|---:|---|
| **3s** | Spore Cloud |
| **6s** | Spore Cloud |
| **9s** | Spore Cloud |
| **12s** | Rupture |

Total lifetime: **12 seconds**

The third cloud and rupture remain separated by one full interval so the two effects are visually and mechanically distinct.

## Spore Cloud

- Interval: **3 seconds**
- Radius: **60 px**
- Applies **30% Spore**
- Occurs at **3s, 6s, and 9s**

## Rupture

At **12 seconds**:

- Radius: **80 px**
- Applies **75% Spore**
- Scatters **2 Seeds**
- Fruiting Body is destroyed

The rupture is primarily an infection event, not a conventional damage explosion.

---

# 3. Spatial Scale

The codebase uses pixels.

Use:

**1 m = 20 px**

Current Spore radii:

| Effect | Radius |
|---|---:|
| Overgrown Contagion Aura | **60 px** |
| Overgrown Death Burst | **80 px** |
| Fruiting Body Cloud | **60 px** |
| Fruiting Body Rupture | **80 px** |

Keep these values exported for playtest tuning.

---

# 4. Root Potency Interaction

Do not add separate Mature Green bonuses directly to Sporulation or Fruiting Bodies.

Root Potency remains the single system responsible for amplifying Spore mechanics on Mature ground.

## Amplified by Root Potency

### Passive Sporulation

Example:

- Rank 5 Sporulation: **11.25% Spore/sec**
- Maximum Root Potency on fully Mature ground: **+140%**
- Final rate: **27% Spore/sec**
- 0% → Overgrown: approximately **3.70 seconds**
- Overgrown → death: **4 seconds**
- Total passive 0% → death: approximately **7.70 seconds**

### Fruiting Body Spore Application

Root Potency amplifies:

- Fruiting Body Cloud Spore
- Fruiting Body Rupture Spore

Root Potency does **not** modify:

- Fruiting Body creation chance
- Fruiting Body lifespan
- Cloud interval
- Cloud radius
- Rupture radius
- Seed scatter count

## Not Amplified by Root Potency

Keep these fixed for tuning clarity:

- Overgrown Contagion Aura application
- Overgrown Death Burst application

---

# 5. Bramble Interaction

Bramble does not directly multiply Sporulation.

Its synergy remains spatial:

- Entanglement slows enemies.
- Grasping Roots can stop enemies.
- Enemies remain on Green longer.
- Dense clustering increases overlap between Fruiting Body Clouds, Contagion Auras, and Death Bursts.

The intended fantasy is a **containment outbreak**.

---

# 6. Revised BRIAR PODS Evolution

## BRIAR PODS — Spore + Bramble

> Germinating Seeds turn the battlefield into containment zones that hold enemies inside Spore-producing territory.

Line: **Tangleburst**

| Rank | Effect |
|---|---|
| **1** | **Tangled Germination** — germination applies **15% Entanglement**. |
| **2** | **Grasping Shoots** — germination roots enemies already at **70% or more Entanglement** for **0.35s**. |
| **3** | **Constricting Growth** — germination pulls nearby enemies inward **26 px**. |
| **4** | **Aggressive Growth** — fresh Seed ground gains **+50% Ensnare Rate for 3s**. |
| **5** | **Mass Entanglement** — every **5 Seed germinations** pins a nearby mob and immediately applies **35% Spore** to affected enemies. Elite pin strength remains **50%** and boss pin strength remains **20%**. |

### Intended Loop

**Germination → pull enemies inward → Entangle/root them → hold them on Green → Fruiting Bodies and Sporulation infect the cluster → first Overgrown deaths trigger epidemic propagation**

---

# 7. Reworked SEED BANK Evolution

## SEED BANK — Spore + Root

> Mature Root territory stores Seeds, then releases them in synchronized Germination Seasons that detonate into immediate fungal burst damage.

SEED BANK is intentionally much stronger than base Spore.

The purpose of the Evolution is to solve the inherent weakness of damage-over-time builds against rapidly spawning late-wave mobs by converting stored biological setup into **instantaneous burst-clear events**.

---

## Evolution Claim Effect — Germination Season

When SEED BANK is claimed:

- Mature Green begins banking Seeds.
- Every **8 seconds**, trigger a **Germination Season**.
- All currently banked Seeds are released simultaneously.
- Banked Seeds preferentially germinate beneath enemies standing on Green.
- Target dense enemy clusters when possible.
- Claiming SEED BANK immediately triggers a free **6-Seed Germination Season**.

The immediate Season ensures the Evolution produces a visible power spike the moment it is claimed.

---

## Rootburst

Every Seed released by Germination Season creates a **Rootburst** when it germinates.

| Property | Value |
|---|---:|
| Radius | **70 px** |
| Direct damage | **35% of standard enemy max HP** |
| Spore application | **50% Spore** |
| Overlap | **Allowed** |
| Root Potency amplification | **Damage and Spore application** |

Multiple Rootbursts can overlap and damage the same enemy.

This is intentional.

Dense mobs should be punished heavily by synchronized Seed releases.

---

## Fungal Collapse

If a Germination Season Rootburst causes an enemy to reach **100% Spore**, it triggers **Fungal Collapse**.

### Normal Enemies

- Die immediately.
- Trigger the normal Overgrown Death Burst.
- Count as an Overgrown death.

### Elites

- Take **50% max HP direct damage**.
- Become Overgrown.
- Do not die instantly from Fungal Collapse.

### Bosses

- Take **15% max HP direct damage**.
- Become Overgrown.
- Do not die instantly from Fungal Collapse.

This allows SEED BANK to cash infection out instantly against normal mobs while preserving longer fights against elites and bosses.

---

# 8. Seed Reserve Upgrade Line

| Rank | Upgrade | Effect |
|---|---|---|
| **Claim** | **Germination Season** | Every **8s**, release the Seed Bank at enemy clusters. Each Seed causes a Rootburst for **35% standard-enemy max HP** in **70 px** and applies **50% Spore**. Reaching 100% Spore from a Rootburst triggers Fungal Collapse. Immediately trigger a free **6-Seed Season**. |
| **1** | **Expanded Reserve** | **+50% Seed Bank capacity**. |
| **2** | **Heavy Seeding** | Seeds enter the Bank **50% faster**. |
| **3** | **Rootburst** | Germination Season Rootbursts deal **+40% damage** and gain **+20% radius**. |
| **4** | **Fungal Reserve** | Every **3 Seeds released** creates **1 guaranteed Fruiting Body**. Each guaranteed Fruiting Body immediately releases its first Spore Cloud. |
| **5** | **Mast Year** | Every Germination Season triggers a **second full-strength Seed wave 1.5 seconds later**. |

---

# 9. Rank 3 Rootburst Values

At Rank 3:

### Damage

Base Rootburst damage:

**35% standard-enemy max HP**

With +40% damage:

**49% standard-enemy max HP**

### Radius

Base radius:

**70 px**

With +20% radius:

**84 px**

These values are further amplified by Root Potency where applicable.

---

# 10. Root Potency + SEED BANK

SEED BANK is designed to reward fully developed Mature Root territory extremely strongly.

Root Potency amplifies:

- Rootburst direct damage
- Rootburst Spore application

Example at maximum Root Potency on fully Mature ground:

### Base Rootburst

- Damage: **35% × 2.4 = 84% standard-enemy max HP**
- Spore: **50% × 2.4 = 120% Spore**

A single Rootburst can therefore immediately Fungal Collapse a normal enemy on fully developed Mature territory.

### Rank 3 Rootburst

Rank 3 base damage:

**49% standard-enemy max HP**

With maximum Root Potency:

**49% × 2.4 = 117.6% standard-enemy max HP**

This is intentionally capable of killing normal enemies outright before even considering Fungal Collapse.

The intended fantasy is:

**ordinary Green = infection zone**

**fully Mature Root Network = fungal death zone**

---

# 11. Fungal Reserve

At Rank 4:

- Every **3 Seeds released by Germination Season** creates **1 guaranteed Fruiting Body**.
- Guaranteed Fruiting Bodies are separate from normal Fruiting Body chance rolls.
- Each guaranteed Fruiting Body immediately emits its first **30% Spore Cloud**.
- The Fruiting Body then continues its normal lifecycle from that point.

Example:

A 9-Seed Season creates:

- **3 guaranteed Fruiting Bodies**
- plus any Fruiting Bodies created through the normal Fruiting Bodies upgrade chance

At Rank 5 Fruiting Bodies, those same 9 Seeds would average roughly:

- 4 to 5 natural Fruiting Bodies
- 3 guaranteed Fruiting Bodies
- approximately 7 to 8 total Fruiting Bodies from one Season

---

# 12. Mast Year

At Rank 5:

Every Germination Season produces:

1. The normal full Seed wave.
2. A second **full-strength** Seed wave **1.5 seconds later**.

The second wave:

- Uses the same Seed count.
- Creates full Rootbursts.
- Can trigger Fungal Collapse.
- Counts toward Fungal Reserve.
- Can create normal Fruiting Bodies.
- Benefits fully from Root Potency.

Example:

A 9-Seed Bank produces:

- **9 Rootbursts**
- then **9 more Rootbursts 1.5s later**
- **18 total Seed germinations**
- **6 guaranteed Fruiting Bodies** from Fungal Reserve
- additional natural Fruiting Bodies
- overlapping Fungal Collapses
- cascading Overgrown Death Bursts

This is intended to be one of the strongest late-game screen-clear events in the game.

---

# 13. Updated Spore Upgrade Summary

| Line | Per rank | At rank 5 |
|---|---|---|
| **Seed Production** | Existing implementation | Existing implementation |
| **Growth Mass** | Existing implementation | Existing implementation |
| **Sporulation** | **+25% Spore accumulation rate** | **+125%** |
| **Fruiting Bodies** | **+10 percentage points Fruiting Body chance** | **50%** |

---

# 14. Current Combat Timing Targets

| Situation | Approximate time |
|---|---:|
| Rank 0 passive Sporulation: 0% → Overgrown | **20.0s** |
| Rank 0 passive Sporulation: 0% → death | **24.0s** |
| Rank 5 passive Sporulation: 0% → Overgrown | **8.89s** |
| Rank 5 passive Sporulation: 0% → death | **12.89s** |
| Rank 5 + max Root Potency: 0% → Overgrown | **3.70s** |
| Rank 5 + max Root Potency: 0% → death | **7.70s** |
| Instant 100% infection → death | **4.0s** |
| Fruiting Body first cloud | **3.0s** |
| Fruiting Body second cloud | **6.0s** |
| Fruiting Body third cloud | **9.0s** |
| Fruiting Body rupture | **12.0s** |
| Germination Season interval | **8.0s** |
| Mast Year second wave delay | **1.5s** |

---

# 15. Intended Power Curve

| Build State | Desired Feeling |
|---|---|
| Early Spore + Root | Functional setup and territory growth |
| Midgame unevolved | Increasing pressure from enemy density |
| Approaching Evolution | Strong incentive to finish one Spore line and one Root line |
| SEED BANK claimed | **Immediate major screen-clear power spike** |
| Seed Reserve Ranks 1–2 | Larger and more reliable Seasons |
| Rank 3 Rootburst | **Dense mobs begin dying immediately to synchronized bursts** |
| Rank 4 Fungal Reserve | Seasons leave behind major fungal infrastructure |
| Rank 5 Mast Year | **Late-game mob annihilation** |

---

# 16. Playtest Target

The damaging Seeds relic should **not** be required for Spore + Root to survive late waves.

The target behavior after SEED BANK is claimed is:

1. Enemy density begins to overwhelm passive Spore.
2. Germination Season fires.
3. Stored Seeds target dense enemy groups.
4. Overlapping Rootbursts deal immediate direct damage.
5. Rootbursts push enemies to 100% Spore.
6. Normal enemies Fungal Collapse immediately.
7. Their Death Bursts spread infection through the remaining mob.
8. Fungal Reserve leaves Fruiting Bodies behind.
9. Mast Year produces a second full burst wave.
10. The mob collapses faster than new enemies can replace it.

If SEED BANK still feels like another slow infection engine rather than a dramatic burst-clear event, it is not strong enough.

SEED BANK should feel like the moment a Spore + Root run stops barely surviving and starts weaponizing the entire Mature Root Network.
