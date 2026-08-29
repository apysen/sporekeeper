# New Adaptations

This document tracks newly designed Adaptations for Sporekeeper. Additional Adaptations will be added as their designs are finalized.

---

## Thistle

### Role
**Damage / Turret**

Thistle is the dedicated turret Adaptation. It turns Green territory into an automated firing network by growing stationary Thistle turrets that track nearby enemies and fire thorn projectiles.

Thistle does not spread Territory and does not provide defensive or support utility by default. Its purpose is sustained autonomous damage and projectile scaling.

### Core Behavior

- Thistle begins with **2 active turrets**.
- Turrets can only grow on Green territory.
- Each turret automatically acquires enemies within range and fires thorn projectiles at them.
- Turrets remain stationary while the Green beneath them survives.
- If the Green supporting a turret is lost, that turret is destroyed and can regrow elsewhere on valid Green.
- Turrets do not consume Green when created.
- Turret placement should favor useful firing positions while avoiding excessive overlap between existing turrets.

### Turret Count

Thistle gains additional turrets by diversifying across its upgrade branches.

| Distinct Thistle Upgrade Paths Chosen | Maximum Active Turrets |
|---:|---:|
| 1 | 2 |
| 2 | 3 |
| 3 | 4 |
| 4 | 5 |

- Investing additional ranks into an already chosen upgrade path does **not** increase turret count.
- Choosing a new distinct Thistle upgrade path increases the maximum active turret count by **1**.
- The maximum is **5 active turrets**.
- This creates a natural tradeoff between specializing heavily into a small number of upgrades early and diversifying to build a larger turret network.

---

## Upgrade Paths

All standard Thistle upgrade paths use uniform scaling. Unique per-level mechanics are reserved for Evolutions.

### Clustering

**Effect:** +1 projectile per rank.

| Rank | Bonus Projectiles |
|---:|---:|
| 1 | +1 |
| 2 | +2 |
| 3 | +3 |
| 4 | +4 |
| 5 | +5 |

- A base Thistle fires **1 projectile**.
- At rank 5, each firing cycle produces **6 total projectiles**.
- Additional projectiles should spread across different available targets when possible rather than automatically multiplying single-target damage.
- Visually, higher Clustering ranks should make each Thistle volley noticeably denser.

### Dehiscence

**Effect:** +15% attack speed per rank.

| Rank | Attack Speed Bonus |
|---:|---:|
| 1 | +15% |
| 2 | +30% |
| 3 | +45% |
| 4 | +60% |
| 5 | +75% |

- Dehiscence increases turret firing frequency.
- It should remain a straightforward multiplicative damage-scaling branch with no additional mechanics.
- Higher ranks should be clearly reflected in the turret's firing cadence and recoil animation.

### Burr

**Effect:** +1 ricochet target per rank.

| Rank | Additional Ricochet Targets |
|---:|---:|
| 1 | +1 |
| 2 | +2 |
| 3 | +3 |
| 4 | +4 |
| 5 | +5 |

- A projectile cannot hit the same enemy more than once during a single ricochet chain.
- Ricochets should initially deal full projectile damage unless playtesting shows that damage falloff is necessary.
- At rank 5, one thorn can hit its initial target and then ricochet to **5 additional enemies**.
- Ricochet trajectories should remain visually readable and visibly redirect from one enemy to the next.

### Needlepoint

**Effect:** +10 percentage points of critical-hit chance per rank.

| Rank | Crit Chance Bonus |
|---:|---:|
| 1 | +10% |
| 2 | +20% |
| 3 | +30% |
| 4 | +40% |
| 5 | +50% |

- Initial critical-hit multiplier: **2x damage**.
- Each projectile impact rolls its own critical-hit chance.
- Ricochet hits independently roll for critical hits rather than inheriting the result of the projectile's first impact.
- Critical hits should have clearly stronger visual and audio feedback than normal hits.

---

## Upgrade Synergies

Thistle's four upgrade paths are intentionally multiplicative with one another.

- **Clustering + Dehiscence:** dense volleys fired rapidly.
- **Clustering + Burr:** extremely high crowd coverage.
- **Clustering + Needlepoint:** many independent opportunities to critically hit.
- **Dehiscence + Burr:** constant ricocheting projectile pressure.
- **Dehiscence + Needlepoint:** high-frequency critical-hit generation.
- **Burr + Needlepoint:** each projectile gains several independent opportunities to critically hit.

A fully upgraded Thistle build can produce extremely high late-game projectile density. This is intentional because Thistle is a dedicated damage Adaptation and contributes no Territory generation by default.

---

## Visual Identity

Thistle turrets should read as botanical structures first and weapons second.

- A large spiked flower head acts as the turret's aiming body.
- The flower head physically rotates toward targets.
- Before firing, the head compresses or draws inward.
- Firing produces a strong recoil that bends the stalk backward slightly.
- The stalk then recovers and resumes tracking.
- Higher projectile counts should make the flower head appear increasingly clustered or multi-spined.
- The overall silhouette should remain recognizable even when several Thistles are active simultaneously.

At maximum deployment, the player should have **five visibly distinct Thistle turrets distributed across Green territory**, creating an autonomous crossfire network.

---

## Current Prototype Values

| Property | Value |
|---|---:|
| Starting Turrets | 2 |
| Maximum Turrets | 5 |
| Base Thorn Damage | 12 |
| Base Attack Interval | 1.10s |
| Base Range | 240 px |
| Thorn Speed / Lifetime | 460 px/s / 1.15s |
| Clustering | +1 projectile per rank |
| Dehiscence | +15% attack speed per rank |
| Burr | +1 ricochet target per rank |
| Needlepoint | +10% crit chance per rank |
| Crit Damage | 2x |
| Upgrade Ranks per Path | 5 |

These values are starting points for playtesting and can be tuned after the first implementation.

---

## Vine

### Role
**Damage / Directional Burst**

Vine is the dedicated single-sector damage Adaptation. It evolves Grandma's starting Cane attack into a massive living lash while preserving the Cane's directional, player-centered attack pattern.

Unlike the other damage Adaptations, Vine does not attempt to cover the entire battlefield. Its strength comes from concentrating very high damage into the targetable 90° area containing the most enemies.

### Cane to Vine

Grandma begins each run with a **Cane** as her default weapon.

The Cane:

- swings in a short frontal arc
- attacks in the direction Grandma is facing
- damages all enemies caught within the swing
- provides modest close-range damage before Adaptations are selected
- base Cane damage should be strong enough to **one-shot weak early-game fodder**
- standard early-game enemies should die in approximately **1 to 2 Cane swings**
- tougher early enemies should generally require around **3 Cane swings**
- the Cane should remain a viable baseline source of direct damage throughout the run, even when neither selected Adaptation is damage-focused
- dedicated damage Adaptations should still substantially outscale the Cane as the run develops
- current prototype target: **24 base damage**, subject to enemy-health tuning and playtesting

When Vine is selected, living growth extends from the Cane during each swing.

The underlying attack remains the same:

> Grandma swings the Cane, and the Vine lashes outward in that direction.

The base Cane and Vine use the same **fixed 90° frontal arc**. Base Cane centers it on Grandma's facing direction. Once Vine is selected, the automatic sweep instead centers on the in-reach, unobstructed sector containing the most targetable enemies. Equal sectors prefer the nearer/tighter cluster and then the direction closest to facing, keeping the result deterministic. The arc does not increase through standard Vine upgrades.

Vine does not create autonomous attacks elsewhere on the battlefield. Every Vine attack still originates from Grandma and remains one bounded sector; only its automatic aim source changes.

### Core Identity

Vine is designed around:

- very high directional damage
- strong elite and boss damage
- long forward reach
- rewarding player positioning relative to dense enemy lanes
- hitting several enemies when they naturally line up
- poor coverage behind Grandma
- lower total battlefield coverage than AoE-focused Adaptations

Vine should remain a single-direction attack throughout its standard upgrade progression.

Standard Vine upgrades should **not** add:

- additional attack directions
- radial lashes
- autonomous targeting
- multiple independent Vines
- ricochets
- territory spreading

The goal is to make one Cane swing increasingly powerful rather than turning Vine into another general AoE Adaptation.

---

## Upgrade Paths

All standard Vine upgrade paths use uniform scaling. Unique per-level mechanics are reserved for Evolutions.

### Elongation

**Effect:** +20% Vine reach per rank.

| Rank | Reach Bonus |
|---:|---:|
| 1 | +20% |
| 2 | +40% |
| 3 | +60% |
| 4 | +80% |
| 5 | +100% |

- At rank 5, Vine reaches **2x its base distance**.
- Elongation increases the length of the directional attack without substantially widening its arc.
- The Vine should become visibly longer at higher ranks.

### Lignification

**Effect:** +25% Vine damage per rank.

| Rank | Damage Bonus |
|---:|---:|
| 1 | +25% |
| 2 | +50% |
| 3 | +75% |
| 4 | +100% |
| 5 | +125% |

- Lignification is Vine's primary raw-damage branch.
- Higher ranks should make the Vine visually thicker, harder, and woodier.
- Vine is intended to have very high per-target damage compared with wider AoE Adaptations.

### Turgor

**Effect:** +15% Vine attack speed per rank.

| Rank | Attack Speed Bonus |
|---:|---:|
| 1 | +15% |
| 2 | +30% |
| 3 | +45% |
| 4 | +60% |
| 5 | +75% |

- Turgor increases the frequency of Cane/Vine swings.
- Even at high rank, Vine should retain a heavy, deliberate attack rhythm rather than becoming a rapid-fire attack.
- Higher ranks should visibly accelerate the Vine's extension, lash, and retraction cycle.

### Apical Dominance

**Effect:** +25% damage near the Vine tip per rank.

| Rank | Tip Damage Bonus |
|---:|---:|
| 1 | +25% |
| 2 | +50% |
| 3 | +75% |
| 4 | +100% |
| 5 | +125% |

- The outermost **25% of the Vine's reach** is considered the tip damage zone.
- Enemies struck closer to Grandma still receive normal Vine damage.
- Enemies struck by the tip receive the Apical Dominance damage bonus.
- This creates a directional spacing sweet spot and rewards deliberate positioning against elites and bosses.
- Elongation changes where the tip zone sits, creating a natural interaction between reach and precision.
- The Vine tip should become more visually pronounced as Apical Dominance increases.

---

## Upgrade Synergies

Vine's upgrade paths reinforce the same directional attack rather than adding new attack shapes.

- **Elongation + Lignification:** long-range heavy strikes.
- **Elongation + Apical Dominance:** larger spacing window for powerful tip hits.
- **Lignification + Apical Dominance:** extremely high elite and boss burst damage.
- **Turgor + Lignification:** frequent heavy Cane swings.
- **Turgor + Apical Dominance:** more opportunities to land precisely spaced tip hits.
- **Elongation + Turgor:** frequent long-range lane clearing.

A fully upgraded Vine should be capable of dealing exceptional damage into its chosen enemy sector while remaining significantly weaker at controlling enemies approaching from several separated directions.

---

## Visual Identity

Vine should preserve Grandma's Cane swing as the foundation of every attack.

### Base Cane
- short frontal sweep
- clearly animated physical Cane swing
- modest range and damage

### Early Vine
- a small living tendril extends from the Cane during the swing
- the attack is still visually dominated by the Cane itself

### Mid Vine
- the living extension becomes much longer and thicker
- the Vine visibly whips through enemies before retracting around the Cane

### Late Vine
- Grandma performs a relatively small Cane swing that unleashes an enormous living tendril
- the Vine can reach across a large portion of the arena
- high Lignification makes it resemble a thick woody limb
- high Apical Dominance gives the terminal tip a pronounced visual impact point
- the attack should feel like a botanical wrecking ball rather than a conventional projectile

The defining visual rhythm should remain a large directional:

> **WHAP**

rather than constant screen-wide damage.

---

## Current Prototype Values

| Property | Value |
|---|---:|
| Base Cane / Vine Damage | 24 |
| Base Attack Interval | 0.72s |
| Base Reach | 92 px |
| Cane / Vine Arc | 90° fixed frontal arc |
| Vine Aim | Densest targetable sector; no manual facing required |
| Elongation | +20% reach per rank |
| Lignification | +25% damage per rank |
| Turgor | +15% attack speed per rank |
| Apical Dominance | +25% tip damage per rank |
| Tip Damage Zone | Outermost 25% of Vine reach |
| Upgrade Ranks per Path | 5 |

These values are starting points for playtesting and can be tuned after implementation.


---

## Fruit

### Role
**Territory / Damage**

Fruit is a kinetic territory-spreading Adaptation built around large rolling fruit. Each fruit damages and knocks enemies aside while creating Green along its path, then establishes a larger Green foothold when it stops.

Fruit is intended to provide meaningful damage while remaining primarily valuable for directional territory expansion.

### Core Behavior

- Fruit periodically grows and drops from Green near Grandma.
- When released, fruit rolls toward the targetable 90° area containing the most enemies. Orchard and detached Gourdvine Fruit make the same decision from their own launch points.
- Fruit damages enemies it collides with.
- Fruit applies knockback based on its impact.
- Fruit leaves a narrow trail of immature Green over bare or corrupted ground as it rolls.
- Fruit begins with real velocity and constant deceleration. It stops only when velocity reaches zero; a hidden travel-distance counter never despawns it.
- When a fruit stops, the Fruit itself remains planted for a short fuse, explodes for light radial damage, and creates the larger terminal Green patch.
- Fruit does not require manual aiming or an additional input.
- Fruit should feel like a large, deliberate event rather than a constant rapid-fire attack.

The basic territory shape is:

> existing Green -> narrow rolling trail -> larger terminal foothold

This gives Fruit a distinct spreading geometry compared with other Territory-focused Adaptations.

### Physics Behavior

Fruit should visibly behave like a heavy rolling object.

- Small enemies cause little momentum loss.
- Normal enemies cause moderate momentum loss.
- Heavy enemies cause substantial momentum loss.
- Walls or major obstacles may redirect or bounce fruit with some momentum loss.
- Higher Momentum investment makes fruit harder to stop and allows it to travel farther through enemy groups.

Fruit should remain readable as a physical object rather than behaving like a conventional projectile.

---

## Upgrade Paths

All standard Fruit upgrade paths use uniform scaling. Unique per-level mechanics are reserved for Evolutions.

### Fruit Set

**Effect:** +1 fruit per release per rank.

| Rank | Fruits per Release |
|---:|---:|
| Base | 1 |
| 1 | 2 |
| 2 | 3 |
| 3 | 4 |
| 4 | 5 |
| 5 | 6 |

- Additional fruit spread into a fan centered on the dense-sector aim direction.
- Fruit should not all occupy the exact same trajectory.
- More fruit increases both enemy coverage and territory coverage.
- At rank 5, each release creates **6 rolling fruit**.

### Ripening

**Effect:** +25% Fruit damage per rank.

| Rank | Damage Bonus |
|---:|---:|
| 1 | +25% |
| 2 | +50% |
| 3 | +75% |
| 4 | +100% |
| 5 | +125% |

- Ripening is Fruit's primary damage specialization.
- Higher ranks should make fruit appear visually larger, heavier, and more mature.
- Visual size increases do not need to match collision-radius increases exactly.
- Fruit should hit significantly harder than broad AoE territory effects when it physically connects with an enemy.

### Momentum

**Effect:** +20% maximum roll distance per rank.

| Rank | Roll Distance Bonus |
|---:|---:|
| 1 | +20% |
| 2 | +40% |
| 3 | +60% |
| 4 | +80% |
| 5 | +100% |

- At rank 5, fruit can travel approximately **2x its base distance**.
- Longer travel creates more opportunities to hit enemies.
- Longer travel also creates longer strips of Green.
- Momentum should visually make fruit feel harder to stop rather than merely extending a hidden lifetime.

### Germination

**Effect:** +20% Fruit-created Green area per rank.

| Rank | Territory Area Bonus |
|---:|---:|
| 1 | +20% |
| 2 | +40% |
| 3 | +60% |
| 4 | +80% |
| 5 | +100% |

- Germination affects both the rolling Green trail and the terminal Fruit foothold.
- At rank 5, Fruit creates approximately **2x its base Green area**.
- Scaling should be based on total area rather than doubling trail width or patch radius directly.
- Higher Germination ranks should visibly create broader trails and larger terminal colonies.

---

## Upgrade Synergies

Fruit's four branches support several distinct build directions while preserving the same rolling-fruit mechanic.

- **Fruit Set + Germination:** maximum territory coverage through many large trails and footholds.
- **Ripening + Momentum:** fewer but extremely powerful long-range rolling impacts.
- **Fruit Set + Momentum:** many long-traveling fruit crossing the arena at once.
- **Ripening + Germination:** heavy fruit that both hit hard and establish substantial Green.
- **Fruit Set + Ripening:** large multi-fruit damage bursts.
- **Momentum + Germination:** long continuous corridors of Green ending in large footholds.

Fruit does not require an attack-speed upgrade path. Its releases should remain relatively large, discrete events so the rolling objects retain visual and mechanical weight.

---

## Visual Identity

Fruit should be one of the most physical and immediately readable Adaptations.

### Early Fruit
- one modest fruit drops and begins rolling
- it knocks through nearby enemies
- it leaves a thin Green trail
- it ends by planting a small foothold

### High Fruit Set
- multiple fruits drop together
- they fan outward across different trajectories
- the arena briefly resembles a botanical bowling alley

### High Ripening
- fruit becomes visibly oversized and heavy
- impact and knockback feedback become stronger
- large enemies visibly resist or slow the fruit

### High Momentum
- fruit travels much farther before stopping
- long Green corridors remain behind its route

### High Germination
- trails become visibly more substantial
- terminal Fruit patches become much larger

At maximum investment, Fruit should create a spectacle of giant produce rolling through enemy formations while carving Green corridors across the arena.

---

## Current Prototype Values

| Property | Value |
|---|---:|
| Base Fruits per Release | 1 |
| Cooldown | 1.0s after the prior release fully explodes |
| Collision Damage | 36 |
| Terminal Explosion | Up to 10 damage in 72 px before area scaling |
| Starting Velocity | 300 px/s |
| Unobstructed Stop Distance | 320 px |
| Planted Fuse | 0.5s |
| Fruit Set | +1 fruit per rank |
| Ripening | +25% damage per rank |
| Momentum | +20% roll distance per rank |
| Germination | +20% Fruit-created Green area per rank |
| Upgrade Ranks per Path | 5 |

The implemented base release cooldown is **1.0 second**, and it begins only after
every normal Fruit/fragment in the previous release has exploded. Base collision
damage is **36**; the terminal explosion deals up to **10** with radial falloff. Fruit
starts at **300 px/s**, stops naturally after **320 px** when unobstructed, and remains
planted for a **0.5-second** fuse. Rolling trail stamps use 0.18 mass, 0.60 pressure
cells, and a 1.30-cell radius every 20 px. Terminal growth uses 0.85 mass, 0.70
pressure, and 0.85 conversion multipliers. The normal terminal keeps its Fruit art;
`fruitseed.png` is reserved for the legendary Dropped Seed relic. Every spawned
normal Fruit independently chooses from the supplied watermelon, red-apple, peach,
orange, lemon, and strawberry paintings, and every Fruit owns its own trail-spacing
state so a multi-Fruit release paints every trajectory. Bloom, ordinary Seed, all
six Fruit paintings, and Fruitseed share the strong watercolor-granulation material.

# New Evolutions

This section covers the Evolutions created by pairing the new Adaptations
**Thistle, Vine, and Fruit** with the existing Adaptations and with one another.

Each Evolution is a **5-rank upgrade line**. Rank 1 is the Evolution claim itself
and establishes the hybrid mechanic. Ranks 2-4 deepen the interaction. Rank 5 is
the capstone.

General implementation rules:

- Evolution mechanics should reuse each Adaptation's existing systems rather than
  inventing unnecessary parallel resources.
- Bramble-based Evolutions should use Entanglement, rooting, thorn contact, and
  Repulsion. Their core effect must not require enemies to remain on owned Green;
  being on Green may strengthen the effect.
- Root Potency should already amplify compatible new Adaptation effects by default
  where those effects occur on Mature Green. Root Evolutions therefore add unique
  behavior beyond simply enabling Root amplification.
- Pruning Evolutions should use the existing Cutting ring, Charge, harvest, and
  release loop.
- Cane and Vine attacks use an automatic alternating sweep across the same frontal
  **90-degree sector**: left-to-right, then right-to-left, repeating.
- Vine Evolutions must preserve that automatic cadence unless the Evolution
  explicitly adds a bonus attack.
- Proc chains should be capped or bounded where needed to prevent exponential
  feedback, especially with Spore, Fruit Set, ricochets, and temporary entities.

---

## INOCULATOR — Thistle + Spore

*Thistle becomes a turret-based Spore delivery system.*

| Rank | Effect |
|---:|---|
| 1 | **Inoculated Thorns** — every Thistle hit applies **4 percentage points of Spore**. |
| 2 | **Burred Dose** — ricochet hits apply **6% Spore** instead of 4%. |
| 3 | **Septic Point** — critical hits apply an additional **8% Spore**. |
| 4 | **Concentrated Culture** — base Thistle application increases from 4% to **6%**. |
| 5 | **Forced Fruiting** — the first Thistle hit that pushes an enemy to 100% Spore immediately emits a **60% Spore pulse** around it. This can happen only once per enemy and does not prematurely kill the target. |

---

## BURSTBLOOM — Thistle + Bloom

*Bloom temporarily turns one thorn in each turret firing cycle into an explosive
Bloomshot.*

### Volley Definition

A **volley** means one complete firing event from one Thistle.

If Clustering causes that Thistle to fire multiple projectiles in one firing event,
**exactly one projectile is designated as the Bloomshot**. This should be the
primary or central thorn aimed at the turret's selected target.

Only the Bloomshot's **first enemy impact** creates a Bloom explosion. Burr ricochets
from that same projectile do not create additional Bloom explosions.

| Rank | Effect |
|---:|---|
| 1 | **Bloomshot** — when a normal Bloom touches the Green supporting a Thistle, that turret becomes Bloom-charged for **4 seconds**. One projectile from every firing event becomes a Bloomshot. Its first enemy impact explodes at **35% Bloom Force**. |
| 2 | **Lingering Charge** — Bloomshot duration increases from 4s to **6s**. |
| 3 | **Critical Bloom** — if the Bloomshot's direct hit critically strikes, its explosion radius increases by **40%**. |
| 4 | **Packed Pollen** — Bloomshot explosion strength rises from 35% to **50% Bloom Force**. |
| 5 | **Floral Salvo** — every normal Bloom immediately causes each Thistle it charges to fire **one bonus volley**. |

---

## HEDGE BATTERY — Thistle + Bramble

*Thistle fire builds and exploits Entanglement anywhere, with stronger application
while enemies are still standing on owned Green.*

| Rank | Effect |
|---:|---|
| 1 | **Suppressive Thorns** — every Thistle hit applies **5% Entanglement**. If the enemy is on owned Green, it applies **10%** instead. |
| 2 | **Pinned Target** — fully Entangled enemies take **+20% Thistle damage** regardless of where they are standing. |
| 3 | **Barbed Precision** — critical Thistle hits apply an additional **8% Entanglement**. |
| 4 | **Suppressive Thorns II** — base application becomes **8%**, or **16% on owned Green**. |
| 5 | **Crossfire** — the first Thistle hit against a fully Entangled enemy every 1 second causes the nearest other Thistle in range to immediately fire **one bonus volley** at it. |

---

## ROOTSTOCK — Thistle + Root

*Root anchors the turret network and lets it periodically fire heavy artillery.*

Root Potency should already amplify normal Thistle behavior by default where
applicable. ROOTSTOCK adds unique mechanics on top of that baseline amplification.

| Rank | Effect |
|---:|---|
| 1 | **Rooted Emplacement** — Thistles grow heavy Root anchors. If the Green beneath one is lost, it remains alive and firing for **3 seconds** before collapsing. |
| 2 | **Stored Tension** — every **5 Thistle firing cycles** loads a Heavy Thorn. The next volley replaces the primary thorn with a **1.5x damage Heavy Thorn** with much greater visual size and knockback. |
| 3 | **Root Cannon** — Heavy Thorns punch through up to **2 normal enemies** before ending or beginning any Burr ricochets. |
| 4 | **Deep Chamber** — a Thistle standing on fully Mature Green requires only **4 firing cycles** to load its next Heavy Thorn instead of 5. |
| 5 | **Artillery Salvo** — every third Heavy Thorn fired by the network causes all active Thistles to immediately fire one Heavy Thorn at their own current targets. Uses an **8-second shared cooldown**. |

---

## DEADHEADING — Thistle + Pruning

*Pruning releases trigger bursts of turret fire, and a fully charged release can
temporarily overgrow the turret network.*

| Rank | Effect |
|---:|---|
| 1 | **Cutback** — releasing at least **4 Cuttings** causes every active Thistle to immediately fire one bonus volley. |
| 2 | **Charged Cutback** — that bonus volley inherits **35% of the current Pruning Charge damage bonus**. |
| 3 | **Sharp Regrowth** — Cutback volleys gain **+1 Pierce**. |
| 4 | **Double Cutback** — a fully charged Pruning release produces a second Cutback volley **0.4 seconds later at 60% damage**. |
| 5 | **Deadhead Flush** — a fully charged release temporarily grows **2 additional Thistles for 5 seconds**. They inherit owned Thistle upgrades and do not count against the normal five-turret cap. |

---

## THORNWHIP — Thistle + Vine

*The automatic Vine sweep carries firing Thistle heads along its length.*

Vine continues its normal automatic back-and-forth 90-degree sweep. Mounted Thistles
fire as part of that sweep and are not manually commanded.

Mounted Thistles inherit **Thistle damage, Clustering, Burr, and Needlepoint**.
They do **not** inherit Dehiscence because their firing cadence is controlled by the
Vine sweep rather than the normal turret attack timer.

| Rank | Effect |
|---:|---|
| 1 | **Grafted Heads** — two small Thistle heads grow along the Vine. During each automatic 90-degree sweep, each fires once at nearby enemies inside the current sweep sector. |
| 2 | **Distributed Graft** — adds a **third** mounted Thistle head. |
| 3 | **Terminal Graft** — the outermost mounted head's projectiles inherit the current **Apical Dominance damage bonus**. |
| 4 | **Full Graft** — adds a **fourth** mounted Thistle head. |
| 5 | **Raking Fire** — every mounted head fires **twice per Vine sweep**, once during the first half of the arc and once during the second half. |

---

## BURDOCK — Thistle + Fruit

*Rolling Fruit becomes a mobile Thistle firing platform.*

| Rank | Effect |
|---:|---|
| 1 | **Armed Fruit** — each Fruit carries **1 Thistle head** that automatically fires while the Fruit rolls. |
| 2 | **Mobile Battery** — the mounted head inherits owned Thistle projectile upgrades. |
| 3 | **Impact Fire** — a Fruit collision immediately resets its mounted Thistle's attack cooldown, at most once every **0.5 seconds**. |
| 4 | **Planted Battery** — when a Fruit finishes rolling, it can leave behind a temporary Thistle for **5 seconds**. Maximum **2 temporary Burdock Thistles** at once. |
| 5 | **Burr Burst** — immediately before the Fruit stops, its mounted Thistle fires one empowered final volley with **+2 Ricochet targets** and **+50 percentage points Crit Chance**. |

---

## MYCELIAL VINE — Vine + Spore

*Vine becomes a directional infection applicator.*

| Rank | Effect |
|---:|---|
| 1 | **Spore Lash** — every Vine hit applies **15% Spore**. |
| 2 | **Mycelial Tip** — Apical-zone hits apply an additional **15% Spore**. |
| 3 | **Vector Harvest** — enemies killed by Vine count as **2 kills** toward Spore's Seed Production threshold. |
| 4 | **Diseased Tissue** — Vine deals **+20% damage** to enemies at 50% Spore or higher. |
| 5 | **Fungal Snap** — an Apical hit against an Overgrown enemy immediately collapses it: normal enemies die and perform their normal Overgrown death burst, elites take **25% max HP**, and bosses take **8% max HP**. |

---

## WISTERIA — Vine + Bloom

*Bloom arms the next automatic Vine sweep with a sequence of flowering detonations.*

Wisteria does not create Bloom explosions on every Vine attack. A normal Bloom arms
the **next automatic Vine attack**, preserving Bloom's existing cadence.

The blossom sequence follows the direction of the current Vine sweep. A
left-to-right sweep detonates left-to-right; the next right-to-left sweep reverses
that order.

| Rank | Effect |
|---:|---|
| 1 | **Flowering Lash** — every normal Bloom arms the next automatic Vine attack. That sweep grows **3 Wisteria blossoms** along its length, which detonate sequentially afterward at **35% Bloom Force**. The original Bloom still occurs. |
| 2 | **Dense Raceme** — adds **+1 Wisteria blossom**. |
| 3 | **Terminal Blossom** — the blossom at the Vine tip detonates at **70% Bloom Force** and **1.35x radius**. |
| 4 | **Protected Flowering** — Wisteria explosions inherit **50% of owned Aftergrowth and Suppression effects**. |
| 5 | **Second Flowering** — the blossom sequence repeats **0.75 seconds later at 50% strength**. |

---

## BRIAR CANE — Vine + Bramble

*The thorned Vine builds Entanglement and physically sweeps pests away from Grandma.*

The Evolution functions anywhere. Owned Green improves several effects but does not
gate the core mechanic.

Repulsion from Briar Cane pushes enemies **radially away from Grandma**, not
sideways in the current sweep direction. This keeps the behavior consistent across
the alternating left-to-right and right-to-left attacks.

| Rank | Effect |
|---:|---|
| 1 | **Briar Lash** — Vine hits apply **15% Entanglement** anywhere. Enemies on owned Green receive **25%** instead. |
| 2 | **Snared Target** — fully Entangled enemies take **+20% Vine damage**. |
| 3 | **Bramble Sweep** — fully Entangled enemies struck by Vine receive **50% of current Bramble Repulsion**, pushed away from Grandma. If they are on owned Green, they receive **100%** instead. |
| 4 | **Tangled Tip** — Apical-zone hits apply **30% Entanglement**, or **50% on owned Green**. |
| 5 | **Clear the Bed** — if a sweep hits a fully Entangled enemy, every enemy hit by that sweep receives a Repulsion pulse. Non-Entangled enemies receive **50% current Repulsion**, fully Entangled enemies receive **100%**, and either effect is **25% stronger on owned Green**. |

---

## HEARTWOOD — Vine + Root

*Root transforms periodic Vine attacks into oversized woody super-sweeps while
Mature Green accelerates the cycle rather than enabling it.*

Root Potency should already amplify compatible Vine behavior by default where
applicable. HEARTWOOD adds a separate periodic attack cycle.

| Rank | Effect |
|---:|---|
| 1 | **Heartwood Cycle** — every **5th Vine sweep** becomes a Heartwood Lash dealing **1.5x damage** at **1.15x reach**. The Vine becomes visibly thicker and woody for that attack. |
| 2 | **Deep Grain** — the outer **40%** of a Heartwood Lash counts as the Apical Dominance zone instead of the normal outer 25%. |
| 3 | **Mature Feed** — a Vine sweep that begins while Grandma stands on fully Mature Green advances the Heartwood counter by **2 instead of 1**. Heartwood still functions normally away from Green. |
| 4 | **Reaction Wood** — after a Heartwood Lash, the next opposite-direction sweep occurs **40% sooner**. |
| 5 | **Old Heart** — a Heartwood Lash is followed **0.3 seconds later** by a Root Echo sweeping through the same 90-degree sector for **60% Vine damage**. |

---

## ESPALIER — Vine + Pruning

*Pruning's Cutting release is trained into the same directional geometry as Vine.*

| Rank | Effect |
|---:|---|
| 1 | **Training Frame** — Pruning Cuttings are launched into a **90-degree forward fan** centered on Grandma's facing direction, matching Vine's attack geometry. |
| 2 | **Long Training** — Cutting launch distance gains **50% of Vine's Elongation bonus**. |
| 3 | **Coordinated Release** — a **fully charged** Pruning release immediately triggers one bonus Vine attack in the same direction. |
| 4 | **Tension Transfer** — that bonus Vine attack receives **50% of Pruning's Charge payout bonus**. |
| 5 | **Double Espalier** — a fully charged release fires a second Cutting fan **0.5 seconds later at 60% damage**. |

---

## GOURDVINE — Vine + Fruit

*Normal Fruit releases are delivered from the Vine's weighted tip rather than
creating additional Fruit outside Fruit's normal cadence.*

| Rank | Effect |
|---:|---|
| 1 | **Weighted Harvest** — when Fruit is ready to release, it attaches to the outer portion of the **next automatic Vine attack**. At maximum extension it detaches and begins its normal roll. Fruit Set still determines how many Fruits are attached and launched. |
| 2 | **Weighted Tip** — while attached, Fruit deals **50% of its normal collision damage** to enemies struck in the Apical zone. |
| 3 | **Momentum Transfer** — detached Fruit receives **50% of Vine's Elongation bonus** as additional roll distance. |
| 4 | **Heavy Cane** — while a Fruit release is armed, **25% of Ripening's damage bonus** also applies to Vine's Apical damage. |
| 5 | **Slingshot Harvest** — detached Fruit launches with **+50% initial speed** and deals **+50% damage to its first collision**. |

---

## ROT — Fruit + Spore

*Fruit becomes a rolling fungal vector.*

| Rank | Effect |
|---:|---|
| 1 | **Moldy Fruit** — Fruit collisions apply **20% Spore**. |
| 2 | **Contaminated Ground** — Green created by Fruit accumulates Spore on enemies **50% faster for 4 seconds**. |
| 3 | **Softened Hosts** — Fruit loses **50% less momentum** when colliding with enemies already at 50% Spore or higher. |
| 4 | **Rotten Core** — the terminal foothold releases a one-time **40% Spore pulse in 80 px**. |
| 5 | **Fruiting Rot** — every third terminal foothold raises a guaranteed **Fruiting Body**, which immediately performs its first cloud pulse. Existing Fruiting Body entity limits still apply. |

---

## OVERRIPE — Fruit + Bloom

*Fruit becomes unstable explosive produce while preserving both Fruit's travel and
Bloom's explosive identity.*

| Rank | Effect |
|---:|---|
| 1 | **Overripe Burst** — at the end of its roll, Fruit creates a Bloom explosion at **65% normal Bloom Force**, then performs its normal terminal territory burst. |
| 2 | **Bruising** — the first enemy collision made by each Fruit creates a small **25% Bloom burst** without stopping the Fruit. |
| 3 | **Juicy Detonation** — the terminal Bloom launches **3 Bloom droplets**. |
| 4 | **Packed Sugar** — terminal Burst rises from 65% to **80% Bloom Force**. |
| 5 | **Split Fruit** — the terminal explosion launches **2 smaller Fruit fragments**. Each rolls for **40% normal distance** and germinates at the end. Fragments cannot split again and cannot trigger Bruising. |

---

## DURIAN — Fruit + Bramble

*Fruit becomes a rolling thorn weapon that builds Entanglement and clears enemies
away from newly established territory.*

| Rank | Effect |
|---:|---|
| 1 | **Spiked Fruit** — Fruit collisions apply **30% Entanglement**. |
| 2 | **Tangled Momentum** — Fruit loses **40% less momentum** from Entangled enemies. |
| 3 | **Impalement** — fully Entangled enemies take **+25% Fruit collision damage**. |
| 4 | **Thorned Trail** — Green freshly created by Fruit gains **+50% Ensnare Rate for 4 seconds**. |
| 5 | **Durian Crash** — when the Fruit stops, enemies near the terminal foothold receive **60% Entanglement** and one full Bramble Repulsion outward from the impact. |

---

## ORCHARD — Fruit + Root

*Fruit terminal colonies become persistent rooted infrastructure and distributed
launch points.*

Root Potency should already amplify compatible Fruit behavior by default. ORCHARD
adds persistent saplings and distributed launch infrastructure instead.

| Rank | Effect |
|---:|---|
| 1 | **Sapling** — every **4 Fruit terminal germinations** raises an Orchard Sapling at the fourth foothold. Maximum **3 active Saplings**. |
| 2 | **Rooted Colony** — Green near a Sapling matures **30% faster** and gains a small additional local control-regrowth bonus. |
| 3 | **Distributed Harvest** — normal Fruit releases are distributed between Grandma and active Saplings. **Total Fruit count does not increase.** |
| 4 | **Perennial Roots** — if the Green beneath a Sapling is lost, the Sapling remains dormant for **5 seconds**. If the ground is reclaimed during that time, it immediately reactivates instead of dying. |
| 5 | **Bumper Crop** — every second normal Fruit release, each active Sapling produces **1 additional Fruit**, capped at **3 bonus Fruit total**. Bonus Fruit cannot create additional Orchard Saplings. |

---

## GRAFT — Fruit + Pruning

*Pruning's actual Cuttings become scion stock for the next Fruit release.*

Graft does not create a separate generic resource meter. The number of Cuttings in
an intentional Pruning release directly determines the graft.

| Rank | Effect |
|---:|---|
| 1 | **Scion Stock** — an intentional Pruning release containing at least **4 Cuttings** grafts the **first Fruit of the next normal Fruit release**. Each Cutting released adds **+3% Fruit collision damage**, up to 12 Cuttings or **+36%**. The stored graft is consumed by the next Fruit release. |
| 2 | **Fertile Union** — each stocked Cutting also adds **+2% Fruit-created Green area**, up to **+24%**. |
| 3 | **Hardy Union** — if the graft was created from **8 or more Cuttings**, the Grafted Fruit loses **40% less momentum** from enemy collisions. |
| 4 | **Multiple Scions** — if the Pruning release contained **12 or more Cuttings**, **every Fruit in the next Fruit release** becomes Grafted rather than only the first. |
| 5 | **Prize Fruit** — releasing a full **16-Cutting ring** guarantees a Prize Fruit in the next Fruit release. The first Fruit becomes enormous, gaining **+50% collision damage, +50% knockback, and +50% terminal Green area**. It replaces the first normal Fruit rather than adding an extra one. |

---

## New Evolution Matrix

| | Thistle | Vine | Fruit |
|---|---|---|---|
| **Spore** | INOCULATOR | MYCELIAL VINE | ROT |
| **Bloom** | BURSTBLOOM | WISTERIA | OVERRIPE |
| **Bramble** | HEDGE BATTERY | BRIAR CANE | DURIAN |
| **Root** | ROOTSTOCK | HEARTWOOD | ORCHARD |
| **Pruning** | DEADHEADING | ESPALIER | GRAFT |
| **Thistle** | — | THORNWHIP | BURDOCK |
| **Vine** | THORNWHIP | — | GOURDVINE |
| **Fruit** | BURDOCK | GOURDVINE | — |

# New Relics

These relics follow the existing relic design language:

- relics are permanent, non-leveling rule changes
- they do not consume upgrade slots
- they cannot be duplicated
- Path relics are available whenever that Adaptation is selected in a primary,
  secondary, or tertiary slot
- effects should generally modify existing Path behavior rather than add unrelated
  standalone damage systems
- Legendary effects can be dramatic, but should remain bounded by trigger counts,
  cooldowns, reduced-strength repeats, or entity caps

---

## Thistle Relics

### Seedhead
**Rarity:** Uncommon

When a Thistle collapses because the Green supporting it is lost, it fires one final
volley at **1.50x damage**.

- Triggers once per Thistle life.
- The final volley inherits Clustering, Burr, and Needlepoint normally.
- The final volley cannot trigger another Seedhead event.
- Temporary Thistles can use Seedhead unless a specific Evolution explicitly says
  otherwise.

### Phyllotaxis
**Rarity:** Rare

Every **5th firing cycle from an individual Thistle** adds a **48-degree** spiral
burst of **5 bonus thorns at 55% damage** around that turret's current aim direction.

- The normal volley still fires.
- Bonus thorns inherit Needlepoint.
- Bonus thorns do not inherit Clustering.
- Bonus thorns can use at most **1 Burr ricochet**, regardless of owned Burr rank.
- The bonus burst does not advance its own Phyllotaxis counter.

### Crown of Thorns
**Rarity:** Legendary

Every **12th normal Thistle firing cycle across the network** causes all active
Thistles to immediately fire one bonus volley at their current targets at
**55% damage**.

- Uses a **7-second internal cooldown**.
- Bonus volleys do not advance Crown of Thorns.
- Temporary Thistles may participate in the bonus volley but do not advance the
  trigger counter.
- Vine-mounted Thistles from THORNWHIP do not advance the trigger counter.

---

## Vine Relics

### Recurve
**Rarity:** Uncommon

Landing at least one hit in the Vine's Apical zone shortens the cooldown before the
**next opposite-direction sweep by 20%**.

- Does not stack.
- Multiple Apical hits during the same sweep still grant only one Recurve benefit.
- The bonus is consumed by the next Vine sweep.
- Cane and Vine preserve their normal alternating left-to-right / right-to-left
  90-degree sweep behavior.

### Trellis
**Rarity:** Rare

Consecutive Vine sweeps that land at least one Apical-zone hit build **Trellis**,
up to **3 stacks**.

Each stack adds **+5 percentage points** to the size of the Apical zone:

| Trellis Stacks | Apical Zone |
|---:|---:|
| 0 | Outer 25% |
| 1 | Outer 30% |
| 2 | Outer 35% |
| 3 | Outer 40% |

- A sweep that fails to land any Apical-zone hit removes all Trellis stacks.
- Trellis changes the sweet-spot size, not Vine reach or total arc width.
- The Vine tip should gain increasingly visible support/growth cues as stacks build.

### Twining
**Rarity:** Legendary

Every **4th Vine sweep** is followed **0.30 seconds later** by a second Vine tracing
the same 90-degree sweep at **55% damage**.

- The secondary Vine follows the same left-to-right or right-to-left direction as
  the triggering sweep.
- It inherits Vine reach and Apical geometry.
- It cannot advance the Twining counter.
- It cannot trigger another Twining repeat.
- Evolution-specific secondary effects should not recursively repeat unless
  explicitly authored for that Evolution.

---

## Fruit Relics

### Thick Rind
**Rarity:** Uncommon

Each Fruit completely ignores the **first enemy collision that would reduce its
momentum**.

- The collision still deals normal Fruit damage.
- The collision still applies normal knockback.
- The Fruit still creates Green normally.
- Thick Rind prevents only the momentum loss from that first qualifying collision.

### Bank Shot
**Rarity:** Rare

The first obstacle bounce of each Fruit preserves **90% of its incoming momentum**.
The next enemy collision after that bounce deals:

- **+40% damage**
- **+40% knockback**

Additional rules:

- Only one empowered post-bounce collision can occur per Fruit.
- Later obstacle bounces behave normally.
- The empowered impact should have clearly stronger visual and audio feedback.
- Bank Shot is intended to reward deliberately directing Fruit into walls or major
  obstacles before hitting enemies.

### Dropped Seed
**Rarity:** Legendary

Every **3rd Fruit that completes its roll** ejects a visible seed forward when it
breaks or finishes.

The Dropped Seed:

- travels **60% of the Fruit's normal roll distance**
- deals **65% of the Fruit's collision damage**
- leaves a narrow Green trail
- creates a terminal foothold at **50% of the Fruit's normal Germination area**
- does not count as a Fruit
- cannot trigger Fruit relics
- cannot create another Dropped Seed

Dropped Seed is intentionally generic to the Fruit Adaptation and does not assume
that every Fruit is a stone fruit or contains a pit.

---

## New Relic Summary

| Adaptation | Uncommon | Rare | Legendary |
|---|---|---|---|
| **Thistle** | Seedhead | Phyllotaxis | Crown of Thorns |
| **Vine** | Recurve | Trellis | Twining |
| **Fruit** | Thick Rind | Bank Shot | Dropped Seed |

These nine Path relics are the initial dedicated relic set for the three new
Adaptations. Additional Plant Synergy relics involving Thistle, Vine, and Fruit can
be designed separately.
