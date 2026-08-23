# Territory Roguelike — Relic System and Core Catalog

> **Current scope:** Long-term multi-element game, with Plant as the reference element and the 12-minute dev build as the current balancing target.
>
> This replaces the previous Plant-heavy 80-relic architecture.
>
> **New structure:**
> - Universal relics are shared by every element.
> - Each element gets a small element-specific pool.
> - Each normal Path gets only a few strong relics.
> - Cross-Path relics are curated instead of mandatory for every pairing.
> - Secret gambling Paths get a very small dedicated relic pool.

---

# 1. Relic Design Philosophy

Relics are permanent, non-leveling rule changes for the current run.

- **Normal upgrades change numbers.**
- **Relics change rules, triggers, targeting, timing, or interactions.**
- **Evolutions combine the two initial Paths into a major new behavior.**
- **Evolution upgrade lines overclock an Evolution after it already works.**
- **Biomass provides repeatable incremental scaling.**

A good relic should make the player think:

> **"That changes how my build works."**

rather than:

> "+15% more of something I already had."

## Inspiration

### Slay the Spire
- simple permanent rules,
- fixed counters,
- first-X-per-wave triggers,
- conditional bonuses,
- strategic tradeoffs,
- Rare and Legendary effects that change priorities.

### How Many Dudes?
- relics modify existing character mechanics,
- contextual reward pools,
- added targets and secondary effects,
- explicit cooldowns and stack caps,
- readable rule-breaking effects.

> **The best relics are simple to read and complicated only in the interactions they create.**

---

# 2. Long-Term Relic Architecture

## Universal Relics

Available to every element and only interact with systems shared across the whole game:
- Core Weapon,
- player HP,
- movement,
- enemy kills,
- elites,
- territory loss,
- XP,
- relic rewards,
- waves,
- optional objectives,
- Biomass if Biomass remains universal.

### Long-Term Target

> **20–25 Universal relics total across the entire game.**

The current core set begins with 12.

## Element Relics

Each element gets approximately:

> **6–8 element-specific relics**

These interact with the element's baseline territory behavior rather than a Path.

Examples:
- Plant: Green, baseline Seeds, maturity.
- Cinder: burning territory, ash, heat.
- Spark: charge, conduction, networks.
- Wave/Tide: flow, momentum, pressure.
- Necromancy: corpses, souls, death resources.

## Path Relics

Each normal Path gets:

> **3 strong relics**

A good three-relic set should usually include:
1. one broadly useful mechanic changer,
2. one build-shaping interaction,
3. one Rare or Legendary fantasy payoff.

Do not add filler simply to hit a quota.

## Synergy Relics

Cross-Path relics are curated.

There is no requirement to create two relics for all 15 pairings.

### Target

> **6–10 synergy relics per element**

Only add one when the interaction deserves to exist.

---

# 3. Mechanic-Tag Eligibility

Synergy relics should use mechanic requirements where practical instead of hard-coded pair names.

Example:

## Sticky Nectar
Requires:
- `Entanglement`
- `MatureGreen`

Normally this means Bramble + Root, but the relic can also become eligible if a third Path, Evolution, or future relic introduces the required mechanics.

This avoids needing separate pools for:
- initial Path pair,
- third Path,
- Evolution,
- Evolution + third Path.

---

# 4. Current Core Catalog Size

The currently defined core catalog contains **43 relics**.

| Pool | Count |
|---|---:|
| Universal, shared by all elements | 12 |
| Plant element | 7 |
| Spore | 3 |
| Bloom | 3 |
| Bramble | 3 |
| Root | 3 |
| Pruning | 3 |
| Curated Plant synergies | 5 |
| Secret Clover | 4 |
| **Total currently defined** | **43** |

The prototype currently implements 39 of these; the four Clover relics arrive with the secret gambling Path.

Carnivory was a sixth Path and is now one Legendary relic. Its three Path relics and the three synergies that reached into standing Maws retired with it: nothing in the catalog refers to a Maw that no longer exists.

Future elements reuse the Universal pool and only add their own element, Path, synergy, and gambling relics.

---

# 5. Relic Offer Rules

Relic rewards offer:

> **Choose 1 of 3**

Relics:
- do not consume upgrade slots,
- cannot be leveled,
- cannot duplicate.

## Before Primary Path
Eligible:
- Universal,
- current Element.

## After Primary Path
Eligible:
- Universal,
- Element,
- Primary Path.

## After Secondary Path
Eligible:
- Universal,
- Element,
- Primary Path,
- Secondary Path,
- any Synergy relic whose mechanic requirements are satisfied.

## After Evolution and Third Path
- third Path relics enter the pool,
- newly satisfied Synergy relics can enter the pool,
- no special third-Path synergy pool is needed.

## Secret Gambling Path
When the secret seventh Path is selected:
- its relic pool becomes eligible,
- the next relic reward guarantees at least one gambling-Path relic among the three offers.

---

# 6. Rarity Philosophy

## Common
Small but noticeable rule change.

## Uncommon
Creates a new interaction or condition.

## Rare
Build-shaping. The player may change positioning or priorities after taking it.

## Legendary
Run-changing and immediately noticeable in combat.

Rarity measures **rule impact**, not simply larger numbers.

---

# 7. Shared Terminology

## Core Weapon

Every element has one automatic starting weapon.

Examples:
- Plant: Thornshot.
- Future elements get their own equivalent.

Universal relics can modify the **Core Weapon** without caring which element is active.

---

# 8. Universal Relics

These are available to every element.

## Predator's Eye
**Rarity:** Common

Every 10th Core Weapon attack targets one additional enemy.

If no second valid enemy exists, the extra attack does not stack onto the original target.

**Purpose:** Crowd coverage without multiplying boss damage.

---

## Follow Through
**Rarity:** Common

When the Core Weapon kills an enemy, the next Core Weapon attack within 2 seconds gains +1 Pierce.

The bonus cannot stack.

---

## Adrenal Response
**Rarity:** Common

After the player takes HP damage, the next three Core Weapon attacks fire faster.

Suggested internal cooldown: 6 seconds.

---

## Clean Finish
**Rarity:** Common

Killing the final surviving enemy of a wave restores a small amount of player HP.

Does not trigger if the wave ends while enemies remain alive.

---

## Overpopulation
**Rarity:** Uncommon

Killing 6 enemies within 2 seconds primes the next enemy killed to explode.

The explosion cannot trigger another Overpopulation explosion.

---

## Last Bastion
**Rarity:** Uncommon

Once per wave, losing a large fixed amount of owned territory within a short window grants a temporary emergency buff.

Suggested buff:
- increased movement speed,
- increased Core Weapon attack rate.

Use an **absolute territory-loss value**, not a percentage of the arena.

---

## Blood in the Water
**Rarity:** Uncommon

The Core Weapon strongly prioritizes enemies below approximately 20% HP.

**Purpose:** Makes kill-trigger builds more reliable without adding raw damage.

---

## Salvage Rights
**Rarity:** Uncommon

Elite kills drop a small Biomass cache.

If Biomass later becomes a differently named universal economy resource, this relic follows that shared resource.

---

## Insurance Policy
**Rarity:** Rare

The first failed Optional Objective in a run still grants a reduced consolation reward.

Suggested value: approximately 40% of normal reward value.

---

## Recycling Bin
**Rarity:** Rare

The first time each run the player rerolls a relic reward, one replacement option is guaranteed to be at least the rarity of the relic it replaced.

Does not guarantee a higher rarity.

---

## Underdog
**Rarity:** Rare

When a large number of enemies are simultaneously near the player, the Core Weapon gains +1 target.

The bonus disappears when local enemy density falls.

---

## Encore
**Rarity:** Legendary

Every third non-Legendary triggered relic activation repeats once at reduced strength shortly afterward.

Rules:
- Encore cannot repeat itself,
- repeated relic effects cannot advance Encore,
- Legendary relics are excluded,
- permanent-object effects use a reduced temporary version if needed.

**Purpose:** Creates a late-game relic engine without uncontrolled recursion.

---

# 9. Plant Element Relics

Plant Element relics can appear in any Plant run regardless of chosen Paths.

## Green Thumb
**Rarity:** Common

The first time the player passes near each baseline Seed, that Seed immediately gains germination progress.

Each Seed can benefit once.

---

## Regrowth
**Rarity:** Uncommon

Recently lost Green leaves a temporary territorial memory.

If the area remains uncontested, Green reclaims the remembered area faster than ordinary Neutral territory.

---

## Compost
**Rarity:** Uncommon

Every fixed number of enemies killed on Mature Green produces a small Biomass payout.

Suggested counter:

> every 12 qualifying kills.

---

## Canopy
**Rarity:** Uncommon

The first time the player takes HP damage while standing on Mature Green, part of that hit is absorbed.

Suggested cooldown:

> 8 seconds.

---

## Resurrection Fern
**Rarity:** Rare

Once per wave, losing a large fixed amount of Green within a short window causes surviving Mature regions to release recovery pulses into nearby recently lost territory.

Use an absolute loss requirement rather than full-arena percentage.

---

## World Seed
**Rarity:** Legendary

After a large fixed kill milestone, a giant World Seed appears near the player.

The World Seed:
- takes several seconds to germinate,
- can be disrupted,
- creates a major Green growth event if it survives.

Only one World Seed can be active at once.

Suggested 12-minute milestone:

> approximately 120 qualifying kills.

---

## Man-Eater
**Rarity:** Legendary

Enemies standing on Green generate Hunger. At 30 Hunger a giant Maw erupts beneath the largest nearby group, devours normal enemies and heavily damages stronger ones, then converts its meal into a burst of Green.

Internally:
- 30 enemy-seconds of Hunger, capped per second so a late horde stays readable.
- The densest eligible cluster standing on Green is the target.
- ~0.7-second emergence telegraph, which enemies can walk out of.
- Up to 8 enemies caught.
- Normal enemies killed by the Bite are swallowed.
- Elites take a heavy share; bosses take a reduced Bite and are never swallowed.
- Devoured enemies come back as a Green splatter.
- Hunger resets, then a short lockout before it accumulates again.

Nothing about the Maw persists. There is no Maw HP, no Capacity, no Digestion, no Budding, and nothing standing on the field for an enemy to kill before it does anything.

**Purpose:** Carnivory's one genuinely exciting moment, kept whole. A mechanic with a single fantastic moment that cannot sustain an entire Path becomes a relic rather than being thrown away.

---

# 10. Spore Relics

## Hard Husk
**Rarity:** Common

Each Seed ignores the first interruption or Saboteur hit that would significantly delay or destroy it.

---

## Cross-Pollination
**Rarity:** Rare

When a Seed germinates, nearby active Seeds gain significant germination progress.

Suggested:

> approximately 25%.

Use a short receiving cooldown to prevent uncontrolled chain acceleration.

---

## Patient Zero
**Rarity:** Legendary

The first naturally generated Seed each wave becomes **Patient Zero**.

Patient Zero:
- ignores one additional interruption,
- and when it germinates, every other active Seed gains a large amount of germination progress.

Suggested:

> approximately 35%.

---

# 11. Bloom Relics

## Late Bloomer
**Rarity:** Uncommon

Bloom wind-up becomes longer, but the Bloom continuously gains Force and Conversion Pressure while charging.

The bonus is capped.

---

## Superbloom
**Rarity:** Rare

When two Bloom pressure waves substantially overlap, the overlap creates one reduced secondary shockwave.

The secondary shockwave:
- creates zero Plant Mass,
- uses a global cooldown.

---

## Perennial
**Rarity:** Legendary

The first successful Bloom each wave becomes a Perennial Flower.

It re-blooms twice later in the wave at reduced Force.

Re-blooms:
- create zero Plant Mass,
- occur several seconds apart.

Only one Perennial can exist at a time.

---

# 12. Bramble Relics

Current Bramble identity:

> Green is hazardous terrain that builds Entanglement and controls enemies.

## Snare Vine
**Rarity:** Uncommon

When Grasping Roots immobilizes an enemy, nearby enemies gain part of its Entanglement.

Suggested:
- up to 2 enemies,
- approximately 20% Entanglement.

---

## Living Rampart
**Rarity:** Rare

When a local Green region becomes heavily occupied by enemies, it enters **Rampart** state.

While active:
- Entanglement builds faster,
- Repulsion triggers more frequently.

Rampart ends when local enemy pressure falls.

---

## The Hedge
**Rarity:** Legendary

When enough enemies on Green become heavily Entangled simultaneously, a Briar Sweep travels across owned Green.

The Sweep:
- interrupts normal enemies,
- raises normal enemies on Green to at least a minimum Entanglement value,
- has reduced effect on elites and bosses.

Suggested global cooldown:

> 10 seconds.

---

# 13. Root Relics

Current Root identity:

> Mature Green amplifies the ecosystem and rewards keeping territory alive.

## Taproot
**Rarity:** Uncommon

The oldest sufficiently Mature region grows one visible Taproot.

The Taproot periodically repairs nearby damaged Green.

If its supporting territory is lost, another Taproot can eventually form elsewhere.

---

## Annual Rings
**Rarity:** Rare

Mature territory that survives long enough accumulates visible Annual Rings.

Suggested:
- one Ring per fixed survival interval,
- maximum 3 Rings per local region.

Each Ring increases Root Potency for mechanics operating in that region.

---

## World Tree
**Rarity:** Legendary

The oldest surviving Mature region eventually grows a unique World Tree.

While supported by Green, every several seconds the next eligible Plant Path event originating from Mature Green receives a reduced secondary echo from the World Tree.

If its supporting Green is lost:
- the World Tree dies,
- it reforms only after a substantial delay.

---

# 15. Pruning Relics

Current Pruning loop:

> Stand on Green → harvest continuously → orbiting spike ring grinds enemies → Charge rises → territory drain escalates → leave Green → charged ring fires outward.

## Gleaning Hook
**Rarity:** Uncommon

Every fixed number of enemies killed by the held ring adds a small amount of Charge without harvesting additional Green.

Suggested:
- every 8 qualifying kills,
- +5% Charge,
- maximum +15% bonus Charge per hold.

---

## Green Manure
**Rarity:** Rare

Enemies killed by the fired ring improve reclamation of the Pruned Ground created during that hold.

More discharge kills strengthen the temporary reclamation bonus up to a cap.

---

## Return Stroke
**Rarity:** Legendary

After the fired ring reaches maximum expansion, it contracts back toward the player once.

The returning ring:
- deals reduced damage,
- uses reduced knockback,
- cannot generate Charge,
- cannot retrigger release-based relic effects.

---

# 16. Curated Plant Synergy Relics

Plant does **not** require relics for all 15 Path pairings.

Current curated set:

> **8 synergy relics**

---

# 17. Pollinator

**Mechanic Requirements:**
- Seed
- Bloom

**Rarity:** Uncommon

When a Bloom detonates, it advances germination progress for a limited number of active Seeds caught in the pressure area.

Suggested:
- up to 3 Seeds,
- approximately 25% progress.

---

# 18. Seedbed

**Mechanic Requirements:**
- Seed
- Mature Green / Root Potency

**Rarity:** Rare

When a Seed germinates on Mature Green, it leaves a temporary Root Node.

For several seconds, the Root Node extends Mature-territory Root Potency into the newly created Green patch.

---

# 19. Tangled Wake

**Mechanic Requirements:**
- Bloom
- Entanglement

**Rarity:** Rare

Green newly pushed outward by a Bloom gains greatly increased Ensnare Rate for several seconds.

Suggested:

> 3 seconds.

---

# 20. Deep Snare

**Mechanic Requirements:**
- Entanglement
- Mature Green

**Rarity:** Uncommon

Entanglement decays much more slowly while enemies remain on Mature Green.

---

# 21. Stored Sap

**Mechanic Requirements:**
- Root
- Pruning Charge

**Rarity:** Rare

Each second spent harvesting Mature Green banks Sap.

When the Pruning ring is released, stored Sap causes surviving Mature Green to enter a temporary Root surge.

The surge improves:
- Root Potency,
- maturation of nearby recovering Green.

Total Sap per hold is capped.

---

# 22. Secret Seventh Path Relics

Every element has one secret gambling Path.

Plant's is:

# Clover

Clover is only available as the post-Evolution third Path.

Its relic pool is intentionally tiny.

### Target

> **4 gambling relics per element**

The gambling Path already has its own upgrade system, so its relics should add strange gambling rules rather than duplicate normal probability upgrades.

---

# 23. Clover Relics

## Bent Coin
**Rarity:** Common

Each Bust adds one **Pity**.

At 3 Pity:
- the next spin cannot contain more than one Bust symbol.

Pity then resets.

---

## Side Pot
**Rarity:** Uncommon

Chips earned while the normal Pot is already full accumulate in a small Side Pot.

On Jackpot:
- Side Pot Chips trigger additional minor symbol rewards.

On Bust:
- the Side Pot is lost.

---

## High Roller
**Rarity:** Rare

Every seventh spin becomes a **High Roller Spin**.

High Roller:
- doubles Jackpot effects,
- doubles Bust penalties.

The counter is always visible.

---

## The House Always Loses
**Rarity:** Legendary

Each time the player Busts, remove one Bust result from one reel for the rest of the run.

Maximum:

> 3 removals.

After the third removal:
- immediately gain one free spin.

---

# 24. Plant-Run Pool Size

A Plant run does not see all 43 currently defined relics.

## Before choosing Paths
Eligible:
- 12 Universal,
- 6 Plant.

Relevant pool:

> **18 relics**

## After choosing Spore + Bloom
Add:
- 3 Spore,
- 3 Bloom,
- Pollinator.

Relevant pool:

> **25 relics**

## After choosing Bramble as the third Path
Add:
- 3 Bramble,
- newly satisfied synergy relics such as Tangled Wake or Deep Snare.

The pool expands with the actual build rather than carrying every theoretical cross-Path relic from the beginning.

---

# 25. Long-Term Scope Estimate

Using this architecture for five elements:

## Universal
> **20–25 total**

## Element Relics
> 6–8 × 5 = **30–40**

## Normal Path Relics
25 normal Paths × 3:

> **75**

## Curated Synergy Relics
Approximately 6–10 per element:

> **30–50**

## Gambling Relics
Approximately 4 × 5:

> **20**

## Long-Term Total

> approximately **190–225 relics**

This is still a large finished-game catalog, but far more manageable than building a separate 70–80 relic catalog for every element.

---

# 26. Trigger Standards

## Fixed Counter
Examples:
- every 5 Maw kills,
- every 10 Core Weapon attacks,
- every 12 kills on Mature Green.

Preferred over arena-percentage thresholds.

## Per Object
Each Seed, Maw, Bloom, or other object tracks its own trigger.

## Per Enemy
Each enemy can activate the effect once or after a cooldown.

## Local Cooldown
The same region cannot trigger repeatedly in a short period.

## Global Cooldown
The entire relic waits before triggering again.

## Per Wave
Limited activations reset at the beginning of each wave.

---

# 27. Recursive Interaction Rules

Any loop resembling:

> A triggers B → B triggers A

must have at least one limiter:
- generation cap,
- global cooldown,
- per-object limit,
- target cap,
- reduced secondary damage,
- explicit `Cannot Trigger Relics` flag.

Examples:
- Overpopulation explosions cannot create another Overpopulation explosion.
- Feeding Ring free Bites cannot reset normal Digestion.
- Encore repeats cannot advance Encore.

---

# 28. Arena-Percentage Rule

Do not build relic activation around theoretical percentages of the entire arena unless actual run data proves the threshold is reliable.

Avoid:

> "Triggers when you lose 20% of the arena."

Prefer:

> "Triggers after losing X square units of owned territory within 2 seconds."

Prefer:
- local distances,
- local enemy density,
- fixed object counts,
- fixed territorial area,
- actual Path event counts.

This rule comes directly from the Kudzu and old Pruning implementation failures.

---

# 29. Player-Facing Description Style

Descriptions should be short.

### Cross-Pollination
> Germinating Seeds advance nearby Seeds by 25%.

### Trapdoor
> Idle Maws burrow to Green with higher Prey Pressure.

### Return Stroke
> Released Pruning rings return once at reduced power.

### High Roller
> Every 7th spin doubles Jackpot rewards and Bust penalties.

The collection screen can provide expanded details.

---

# 30. Relic Feedback

Triggered relics need visible feedback.

Use:
- relic icon flashes,
- counters,
- cooldown rings,
- world markers for persistent objects,
- distinctive Legendary trigger sounds.

Examples:
- Predator's Eye shows `8 / 10`.
- Patient Zero visibly marks the special Seed.
- World Tree displays the relic icon over the Tree.
- High Roller shows `5 / 7` on the slot UI.

---

# 31. Relic Testing Metrics

Log:
- pick rate,
- win rate,
- average acquisition time,
- trigger count,
- damage,
- enemies affected,
- crowd-control uptime,
- territory gained or recovered,
- Biomass generated,
- times offered but rejected.

A high pick rate alone does not automatically require a nerf.

A relic becomes a problem when it is both:
- overwhelmingly preferred,
- materially stronger across most builds.

Niche relics are acceptable.

Relics that almost never matter are not.

---

# 32. Current Development Recommendation

For the 12-minute Plant build:

> **Keep all currently implemented relics unlocked while balancing.**

Do not spend development time on meta unlocks yet.

First prove:
- the relic is fun,
- the relic actually triggers,
- the effect is visible,
- the effect does not recurse infinitely,
- the player understands why it matters.

---

# 33. Deprecated Relic Architecture

## No 6-Relic Requirement Per Path

Current target:

> **3 strong relics per normal Path**

Add a fourth later only if the idea genuinely deserves to exist.

## No 2-Relic Requirement Per Pairing

Not all Path pairs need cross-Path relics.

Evolutions already guarantee every initial Path pair gets a bespoke major interaction.

## No Plant-Only Universal Pool

Old Universal Plant relics are now split into:
- true Universal relics shared by every element,
- Plant Element relics.

## No Swarm / Parasite / Kudzu Relic Pools

Retired unless reused for a future element:
- Satellite Growth
- Runner Vine
- Daughter Colony
- Escape Pod
- Invasive Network
- Host Vector
- Symptomless Carrier
- Creeping Infection
- Host Collapse
- Green Plague

The necromancy-style enemy conversion concept should be saved for a future element rather than forced back into Plant.

## No Old Frontier-Only Bramble Relics

Bramble now controls enemies throughout Green.

## No Persistent-Maw Relics

Carnivory as a Path is retired, and with it every relic that reached into a standing Maw:
- Trapdoor
- Shared Hunger
- Apex Predator
- Carrion Garden
- Feeding Bloom
- Feeding Ring

The fantasy survives whole as the Man-Eater Legendary. The rule this establishes: when a mechanic has one fantastic moment but is not deep enough to sustain an entire Path, turn that moment into a relic rather than throwing it away.

## No Old Timed Pruning-Cycle Relics

Pruning now uses the held ring and Charge loop.

---

# 34. Core Catalog Summary

## Universal — All Elements
1. Predator's Eye — Common
2. Follow Through — Common
3. Adrenal Response — Common
4. Clean Finish — Common
5. Overpopulation — Uncommon
6. Last Bastion — Uncommon
7. Blood in the Water — Uncommon
8. Salvage Rights — Uncommon
9. Insurance Policy — Rare
10. Recycling Bin — Rare
11. Underdog — Rare
12. Encore — Legendary

## Plant Element
1. Green Thumb — Common
2. Regrowth — Uncommon
3. Compost — Uncommon
4. Canopy — Uncommon
5. Resurrection Fern — Rare
6. World Seed — Legendary
7. Man-Eater — Legendary

## Spore
1. Hard Husk — Common
2. Cross-Pollination — Rare
3. Patient Zero — Legendary

## Bloom
1. Late Bloomer — Uncommon
2. Superbloom — Rare
3. Perennial — Legendary

## Bramble
1. Snare Vine — Uncommon
2. Living Rampart — Rare
3. The Hedge — Legendary

## Root
1. Taproot — Uncommon
2. Annual Rings — Rare
3. World Tree — Legendary

## Pruning
1. Gleaning Hook — Uncommon
2. Green Manure — Rare
3. Return Stroke — Legendary

## Curated Plant Synergies
1. Pollinator — Seed + Bloom
2. Seedbed — Seed + Mature Green
4. Tangled Wake — Bloom + Entanglement
6. Deep Snare — Entanglement + Mature Green
7. Stored Sap — Root + Pruning

## Clover
1. Bent Coin — Common
2. Side Pot — Uncommon
3. High Roller — Rare
4. The House Always Loses — Legendary

---

# 35. Guiding Rule

> **Do not add a relic because a category has an empty slot. Add it because the game becomes more interesting when that relic exists.**

The smaller architecture should make each relic:
- easier to remember,
- easier to balance,
- more likely to appear,
- more likely to shape a run,
- easier to scale across Plant, Cinder, Spark, Wave/Tide, and Necromancy.
