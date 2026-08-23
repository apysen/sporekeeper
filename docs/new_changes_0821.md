# Territory Roguelike – Remaining Design Changes for 12-Minute Dev Build

> **Scope note:** Sections 1–6 from the previous design-changes Markdown are already implemented and are intentionally omitted here.
>
> The current balancing target is the **12-minute dev build**. The eventual full game can still target approximately **25–30 minute runs**, but all current pacing, difficulty, Evolution timing, and build-completion tuning should be based on the 12-minute version.

---

# 1. Spore + Root Needs More Satisfaction, Not Necessarily More Base DPS

Spore + Root currently feels low-damage.

This is acceptable if:
- the build remains viable,
- its territorial and economic strengths are exceptional,
- its Evolution provides a satisfying payoff.

Do not automatically turn Root or Spore into direct-damage paths just to equalize DPS.

## Evolution Direction: Seed Bank / Germination Season

- Mature territory stores dormant Seeds over time.
- Stored Seeds visibly accumulate throughout the ecosystem.
- Periodically, a **Germination Season** occurs.
- Large numbers of stored Seeds germinate across Mature territory simultaneously.
- The result should cause a huge territorial expansion event.

### Intended Satisfaction

Instead of:

> "I just killed 100 enemies."

The payoff can be:

> **"My ecosystem just jumped from 40% to 55% territory in seconds."**

The event should be visually dramatic enough to meet the Evolution standard.

---

# 2. Evolution Design Standard

**Super Bloom remains the benchmark for Evolution satisfaction.**

Not every Evolution needs equivalent damage, but every Evolution should create an immediately recognizable payoff.

Every Evolution should provide at least one of:
- a visible chain reaction,
- a dramatic territorial swing,
- many simultaneous effects,
- a major transformation of an existing mechanic,
- a large offensive or crowd-control payoff.

Small passive bonuses belong in:
- upgrades,
- relics,
- normal Path mechanics.

They should not be the primary payoff of an Evolution.

> **An Evolution should make the player immediately recognize that their build has entered a new stage.**

---

# 3. Perfect Balance Is Not Required

The game is single-player.

Every Path pairing does **not** need to be equally strong.

It is acceptable for the game to have:
- S-tier combinations,
- average combinations,
- niche combinations,
- difficult combinations,
- combinations experienced players tend to avoid.

The goal is **viability and satisfaction**, not mathematical parity.

## Acceptable Imbalance

A pairing can have:
- lower DPS,
- weaker boss killing,
- worse economy,
- harder execution,

as long as it has a recognizable strength and can reasonably complete a normal run when played intelligently.

## Unacceptable Imbalance

Avoid pairings where:

> choosing the combination effectively means the run is already lost.

The player should not feel that selecting an Evolution was a mistake because the mechanic barely functions.

---

# 4. Do Not Balance Only Around DPS

Because territory is a core system, builds should be evaluated across multiple dimensions.

Useful metrics include:
- enemy kills per minute,
- damage per second,
- average Territory %,
- territory generated per minute,
- territory lost per minute,
- Biomass generation,
- enemy crowd-control uptime,
- boss kill time,
- player damage taken,
- survival rate,
- final win rate.

Example:

A Bramble + Spore build may reasonably have:
- mediocre DPS,
- excellent crowd control,
- excellent territory generation.

That can still be healthy.

However, enemy accumulation remains an important practical constraint. A build that cannot kill enough enemies can still be overwhelmed regardless of its territorial strengths.

---

# 5. Evolution Frees a Path Slot

To help specialized or low-damage builds survive the late game, completing an Evolution changes the player's build structure.

## New Build Progression

1. Choose Path 1.
2. Choose Path 2.
3. Meet the requirements for their Evolution.
4. Obtain the Evolution.
5. The two original Paths are condensed into **one Evolution slot**.
6. A new Path slot becomes available.
7. The player chooses **one additional Path** from the remaining four.
8. No second Evolution occurs during that run.

## Final Build Structure

> **1 Evolution + 1 supporting Path**

Example:
- Spore + Root evolve into Seed Bank.
- One Path slot opens.
- The player chooses Bramble.
- Final build becomes:
  - Seed Bank
  - Bramble

This allows specialized Evolutions to patch weaknesses later in the run.

---

# 6. Third Path Rules

- The third Path must be one of the four Paths not already used to create the Evolution.
- The constituent Paths of the Evolution cannot be selected again.
- The third Path uses its normal mechanics, upgrades, and relics.
- The third Path does **not** combine with the Evolution into another Evolution.
- No second Evolution occurs.
- No three-way Evolution system is required.
- No Evolution chaining is required.

This prevents combinatorial content explosion while allowing much more varied final builds.

---

# 7. Upgrade Slots After Evolution

The current six-stat-slot system should expand when the third Path becomes available.

## Recommended Structure

### Before Evolution
- 2 Paths
- 6 stat upgrade slots

### After Evolution
- 1 Evolution
- 1 new Path
- **8 stat upgrade slots**

The original six upgrades remain intact.

Evolution grants two additional stat slots so the supporting Path can meaningfully develop.

This avoids deleting or replacing the player's existing build.

---

# 8. Thornshot Multi-Target Upgrade

Add a new upgrade line for the Plant starting weapon, **Thornshot**.

## New Upgrade Concept: Additional Targets

> **Thornshot can target additional enemies simultaneously.**

Example progression:
- Base Thornshot: targets 1 enemy.
- Upgrade I: **+1 enemy targeted**.
- Further levels can add more simultaneous targets if playtesting supports it.

### Behavior

Instead of one projectile always firing at one nearest enemy, Thornshot can fire at several separate enemies during the same attack cycle.

Example:
- Base: 1 target
- +1 Target: 2 simultaneous targets
- +2 Targets: 3 simultaneous targets

### Purpose

This gives the protagonist's baseline weapon better **crowd-clearing scalability** without forcing every territory Path to become a damage Path.

It should especially help builds such as:
- Spore + Root,
- Root + Bramble,
- other territory/economy/control-heavy combinations.

### Important Balance Principle

The multi-target upgrade should improve **enemy coverage**, not dramatically multiply single-target boss DPS.

Preferred behavior:
- additional shots prioritize different enemies,
- multiple Thornshots should not stack onto the same target unless there are fewer valid enemies than projectiles.

This creates better horde management without turning Thornshot into an excessive boss-killing weapon.

---

# 9. Kudzu Replaces Swarm + Parasite

The previous Swarm and Parasite Paths overlapped too heavily.

Both ultimately created:
> Green territory behind enemy lines that spreads independently.

They are merged into one Path.

# Kudzu

**Implementation status: Not yet implemented.**

## Identity

> **Establish invasive independent footholds away from the main ecosystem and let them spread through Neutral and Hostile territory.**

### Distinction From Other Paths

- Spore creates Green from enemy deaths.
- Bloom pushes existing Green.
- Kudzu creates persistent remote expansion engines.

---

# 10. Kudzu Core Mechanic: Crowns

Kills made sufficiently far from existing Green contribute toward establishing a **Kudzu Crown**.

## Establishment

- Multiple eligible kills in roughly the same area are required.
- One random kill should not immediately create a Crown.
- The player deliberately fights in a region to establish a foothold.
- A new Crown has a rooting period.
- Crowns are vulnerable while rooting.

## Once Established

A Crown:
- creates a small Green foothold,
- sends runners outward,
- expands quickly through Neutral territory,
- expands more slowly through Hostile territory,
- can eventually connect back into another Green region.

## Crown Capacity

Crowns are limited.

Suggested prototype direction:
- approximately **2 active Crowns baseline**,
- investment can raise the limit to roughly **4–5**.

The capacity prevents automatic exponential map takeover.

## Crown Destruction

If a Crown is destroyed:
- territory still dependent only on that Crown begins to recede,
- territory that has already connected to the larger Green ecosystem survives.

This creates the lifecycle:

> **Establish → Defend → Spread → Connect → Stabilize**

---

# 11. Kudzu Runners

Established Crowns periodically send visible runners outward.

## Runner Behavior

Against Neutral territory:
- spread aggressively.

Against Hostile territory:
- spread more slowly,
- use Invasion Strength to overcome resistance.

Against Green territory:
- connect with the existing ecosystem.

The runners should visually resemble invasive vines crawling across the territory surface.

---

# 12. Kudzu Upgrade Lines

### 1. Crown Capacity
Allows additional simultaneous Crowns.

### 2. Rooting Speed
Crowns establish faster.

### 3. Runner Growth
Runners spread faster and farther.

### 4. Invasion Strength
Improves Kudzu growth through Hostile territory.

## Kudzu Design Constraint

Kudzu should not also become:
- the best damage Path,
- the best defensive Path,
- or the best economy Path.

Its primary strength is:

> **being somewhere Green is not supposed to be.**

Other Paths determine what those new Green regions do once established.

---

# 13. Kudzu Evolution Directions

## Spore + Kudzu: Sporulation

- Remote Seeds can develop into Kudzu Crowns.
- Established Crowns periodically launch Seeds into nearby enemy populations.
- Seeds create colonies.
- Colonies create additional Seeds.

### Intended Spectacle

> Multiple independent outbreaks spread across the arena simultaneously.

---

## Bloom + Kudzu: Wildflower Network

- Every active Kudzu Crown becomes a valid Bloom origin.
- Blooms activate sequentially across the Crown network.
- One Crown Blooming can trigger or accelerate the next.

### Intended Spectacle

> Huge Bloom explosions erupt across several distant regions of the arena in sequence.

---

## Bramble + Kudzu: Briar Bastions

- Kudzu colonies become powerful Bramble control zones.
- Threatened Crowns can cause their entire connected colony to erupt with roots and thorns.
- Several colonies can trigger independently.

### Intended Spectacle

> Multiple distant Green regions suddenly become aggressive crowd-control strongholds.

---

## Root + Kudzu: Rhizome Network

- Mature Kudzu colonies become connected through an underground Root Network.
- Connected colonies can share:
  - regeneration,
  - maturity support,
  - limited Biomass benefits,
  - recovery support.
- The network can periodically cause synchronized territorial growth.

### Intended Spectacle

> Roots visibly connect distant colonies and all connected Green regions surge together.

---

# 14. Pruning Replaces Wither

The previous name **Wither** has been removed.

# Pruning

**Implementation status: Not yet implemented.**

## Identity

> **Deliberately sacrifice part of the ecosystem to concentrate its growth into immediate offensive power.**

Pruning creates a unique risk/reward Path because Territory % is also the player's primary health resource.

---

# 15. Pruning Core Mechanic

## Pruning Cycle

Pruning periodically performs a **Pruning Cycle**.

A cycle:
1. removes a controlled amount of Green territory,
2. converts that removed Plant mass into **Cuttings**,
3. sends those Cuttings toward the player,
4. temporarily gives the player a large automatic offensive burst.

### Visual Sequence

> Green retracts → leaves and branches rip free → plant material spirals toward the protagonist → Cuttings launch into enemies

The payoff must be immediate and visually obvious.

---

# 16. Pruning Territory Rules

## Territory Selection Priority

Pruning should preferentially consume:
1. Fresh territory,
2. Established territory,
3. Mature territory only when necessary.

This prevents automatic Pruning from constantly destroying the most valuable Root territory.

## Fixed Territory Cost

Pruning should sacrifice a fixed amount of total claimable arena area rather than a percentage of current Green.

Suggested prototype range:

> **approximately 1.5–2.5% of total claimable arena area per cycle**

This keeps the cost predictable.

## Safety Floor

Pruning pauses automatically if Territory % becomes dangerously low.

Suggested prototype floor:

> **approximately 25–30% Territory**

An automatic Path mechanic should not directly kill the player by consuming the final territory.

---

# 17. Pruned Ground

Territory removed by Pruning becomes temporary **Pruned Ground**.

- Green can reclaim Pruned Ground faster than ordinary Neutral territory.
- The sacrifice remains real.
- Enemy pressure can still prevent recovery.
- Healthy ecosystems have a natural route back from Pruning.

This creates the intended cycle:

> **Grow → Prune → Attack → Regrow**

---

# 18. Cuttings

Cuttings are the immediate offensive reward from Pruning.

Suggested properties:
- finite quantity,
- high damage,
- automatically launched,
- useful against large enemies,
- capable of limited piercing,
- visually numerous during large Pruning events.

Pruning should provide direct offensive power that the other territory-focused Paths may lack.

---

# 19. Pruning Upgrade Lines

### 1. Pruning Frequency
Reduces the time between Pruning Cycles.

### 2. Cutting Yield
Creates more Cuttings from the same amount of sacrificed Green.

### 3. Cutting Damage
Increases Cutting damage.

### 4. Regrowth
Increases the speed at which Pruned Ground is reclaimed.

## Important Balance Rule

Normal upgrades should improve **efficiency**, not increase how much territory is sacrificed.

Avoid standard upgrades such as:
- +50% territory sacrificed,
- double territory cost for double reward.

This reduces the risk of exponential sacrifice/growth loops.

---

# 20. Pruning Evolution Directions

## Spore + Pruning: Coppice

- Pruning creates dormant Seeds throughout the cut area.
- After a delay, the Seeds germinate simultaneously.
- The player gets an immediate Cutting barrage followed by major regrowth.

### Intended Loop

> Territory retracts → Cuttings kill enemies → Seeds erupt → territory returns.

---

## Bloom + Pruning: Rebound

- Before Bloom detonates, nearby Green is pruned inward toward it.
- Territory visibly contracts toward the flower.
- Absorbed Plant mass greatly increases Bloom Force.
- The resulting Bloom launches a much larger forward territorial surge.

### Intended Spectacle

> The ecosystem collapses inward, then violently explodes outward.

---

## Bramble + Pruning: Deadfall

- Pruning Bramble-covered Green converts accumulated thorn growth into additional Cuttings.
- Large Bramble regions create huge spike volleys when pruned.

### Intended Spectacle

> A Green region retracts and becomes a screen-wide storm of thorns.

---

## Root + Pruning: Coppicing

- Mature territory becomes especially valuable to Prune.
- Mature Green generates substantially more Cuttings.
- The Root Network causes the region to regrow much faster afterward.

### Intended Loop

> Ancient forest → massive harvest → projectile storm → rapid regrowth → repeat.

---

## Kudzu + Pruning: Cuttings

- Some Cuttings become living propagules instead of attacks.
- Propagules fly across the arena.
- Successful propagules establish new Kudzu Crowns.
- Sacrificing one region can create several invasive fronts elsewhere.

### Intended Spectacle

> One ecosystem is cut apart and scattered across the arena, with some fragments killing enemies and others taking root.

---

# 21. 12-Minute Dev Build Pacing

All current testing should use the **12-minute run** as the primary pacing target.

The 30-minute target remains the intended eventual full-run structure, but it should not currently drive moment-to-moment balance.

## Suggested 12-Minute Structure

### 0:00–2:00 — Establishment

Goal:

> **Get the ecosystem started.**

- Starting Thornshot.
- Small starting Green circle.
- Early Seeds begin generating territory.
- Basic enemies.
- First XP upgrade choices.
- Enemy pressure should be manageable but noticeable.

### ~1:00–1:30 — Primary Path

- Offer 3 available Plant Paths.
- Player selects the first Path.

### ~2:30–3:00 — Secondary Path

- Offer 3 Paths from the remaining pool.
- Player selects the second Path.
- The two-Path build becomes locked.

### 3:00–5:30 — Specialization

Goal:

> **Understand what the pairing does.**

- Path interactions become visible.
- Relics begin shaping the build.
- Enemy compositions become more mixed.
- The player begins filling the six upgrade slots.

### 5:30–7:00 — Stress Test

Goal:

> **Expose the build's weakness before Evolution.**

- Increased enemy density.
- More specialized enemies.
- Build should be pressured but reasonably capable of surviving if played well.
- Evolution requirements should become achievable during this period.

### ~7:00 — Evolution

- The player's original two Paths combine.
- Evolution should cause a major power spike.
- The Evolution occupies one consolidated slot.
- Two additional stat upgrade slots become available, increasing the total from 6 to 8.

### 7:00–8:00 — Power Fantasy Window

- Give the player a short period to enjoy the Evolution.
- Do not immediately hard-counter the new mechanic.
- Enemy density may rise, but the player should briefly feel dramatically overpowered.

### ~8:00 — Third Path

- Offer a third Path from the four Paths not already consumed by the Evolution.
- The third Path cannot create another Evolution.
- The final build becomes:

> **1 Evolution + 1 supporting Path**

### 8:00–10:00 — Escalation

Goal:

> **Test the completed build.**

- Enemy density rises substantially.
- More mixed compositions.
- Multiple enemy roles attack different systems simultaneously.
- Elites become more common.
- Territorial pressure increases.

### 10:00–11:30 — Collapse Pressure

Goal:

> **Make the completed build work hard to stay alive.**

- Very high enemy density.
- Simultaneous threats to:
  - protagonist HP,
  - Green territory,
  - Seeds,
  - Crowns,
  - Mature territory.
- Stronger elite combinations.
- Enemy attacks may arrive from several directions.

### 11:30–12:00 — Dev-Build Extinction Event

Goal:

> **Controlled visual insanity.**

- Highest enemy density in the run.
- Multiple enemy archetypes simultaneously active.
- Completed builds should create large chain reactions and screen-filling effects.
- The player should initially feel like the wave is impossible.
- A strong completed build should be capable of surviving it.

### 12:00 — Dev-Build Victory

For the current test build:
- surviving the final invasion can be the win condition,
- or remaining enemies can become finite so the player can finish claiming the arena.

The eventual full game can expand this structure toward the planned ~30-minute run.

---

# 22. Late-Wave Difficulty Philosophy

The third Path dramatically raises the player's late-game power ceiling.

Later waves therefore need to become substantially harder.

However:

> **Do not primarily increase difficulty through enormous enemy HP multipliers.**

Late-game difficulty should come from:
- higher enemy density,
- more simultaneous threats,
- mixed enemy compositions,
- stronger territorial pressure,
- more elite modifiers,
- attacks from several directions,
- enemies that pressure different parts of the player's ecosystem.

## Example Late-Game Threat Mix

A late wave can simultaneously include:
- Hunters pressuring protagonist HP,
- Grazers removing Green territory,
- Saboteurs targeting Seeds or Crowns,
- Corruptors converting Green to Hostile territory,
- Wardens suppressing ecosystem mechanics,
- elites modifying enemy behavior.

The completed build should need several systems working together.

---

# 23. Late Enemy Specialization

Avoid making every late enemy simply an early enemy with much more HP.

Possible late-game variants include:

### Heavy Grazer
- Large and slow.
- Removes large amounts of Green.
- Resistant to knockback.
- Still vulnerable to slowing and prolonged Entanglement.

### Rusher
- Fast Hunter.
- Crosses Green quickly.
- Naturally reduces the effectiveness of passive Bramble control.

### Burrower
- Temporarily moves underneath Green.
- Emerges deeper inside the ecosystem.
- Bypasses simple outer defense.

### Siege Corruptor
- Establishes large corruption zones if ignored.

### Suppressor
- Creates an area that temporarily reduces ecosystem effectiveness.

Possible suppression targets:
- Seed germination,
- Bramble Ensnare Rate,
- Root bonuses,
- Bloom pressure,
- Kudzu rooting.

---

# 24. Elite Modifiers

Late-game elites should increasingly change rules instead of only increasing stats.

Possible modifiers:

### Unstoppable
- Cannot be rooted.
- Can still be slowed.

### Blighted
- Leaves Hostile territory behind.

### Ravenous
- Territory consumption accelerates if uninterrupted.

### Regenerative
- Heals unless recently damaged by the protagonist.

### Disruptive
- Weakens Green-territory effects nearby.

### Volatile
- Explodes on death.
- Can damage Green as well as nearby enemies.

---

# 25. Difficulty Escalation After Evolution and Third Path

Difficulty escalation should track build progression.

## After Evolution

- Increase spawn pressure.
- Increase mixed enemy compositions.
- Begin introducing more dangerous elites.

## After Third Path

- Enter the final escalation stage.
- Increase:
  - enemy density,
  - simultaneous territorial attacks,
  - elite frequency,
  - specialized enemy behavior.

The game can visibly communicate this transition with a threat-level event or equivalent presentation.

---

# 26. Current 12-Minute Prototype Balance Priorities

For the current dev build, prioritize testing:

1. **Can every reasonable two-Path build survive until Evolution?**
2. **Does Evolution create an obvious power spike?**
3. **Does the third Path meaningfully help cover weaknesses?**
4. **Does Thornshot multi-targeting reduce enemy-overwhelm problems without making Thornshot dominant?**
5. **Are low-DPS builds still capable of controlling enemy population enough to survive?**
6. **Does Bloom generate less raw territory than Seeds while still feeling powerful?**
7. **Does Root improve its paired mechanic enough to feel noticeable?**
8. **Can late waves threaten strong completed builds without relying on excessive enemy HP?**
9. **Do Evolutions create satisfying, unmistakable screen-level events?**
10. **Do Kudzu and Pruning each occupy a clearly different strategic niche once implemented?**

---

# 27. Long-Term 30-Minute Run

The intended full game can still target approximately **25–30 minute runs**.

Do not discard the larger pacing structure.

Instead, treat the 12-minute dev build as a compressed version of:

- Establishment
- Two-Path specialization
- Stress test
- Evolution
- Brief power fantasy
- Third Path
- Late escalation
- Extinction Event
- Domination / victory

When development moves to longer runs:
- expand the time between milestones,
- add more relic opportunities,
- introduce enemy archetypes more gradually,
- extend the post-Evolution build-development period,
- increase the length of late-game escalation,
- rebalance XP and Biomass progression around the longer duration.

For now:

> **All gameplay tuning should prioritize the 12-minute version.**

# 28. Evolution Upgrade System

After the player's first two Paths combine into an Evolution and the third Path becomes available, the player gains access to **one optional upgrade line for that Evolution**.

The two post-Evolution upgrade slots can therefore be used in one of two ways:

- **1 Evolution upgrade line + 1 upgrade line from the third Path**
- **2 upgrade lines from the third Path**

This creates a meaningful choice between:
- pushing the Evolution further,
- or using the third Path to solve a weakness in the existing build.

## Core Rules

- Every Evolution has **exactly one unique upgrade line**.
- Evolution upgrade lines have **5 levels**, matching normal stat upgrade lines.
- The Evolution must already feel complete and satisfying at Level 0.
- Evolution upgrades should make the defining mechanic:
  - happen more often,
  - affect more enemies,
  - cover more area,
  - chain farther,
  - become more reliable,
  - or gain a new capped secondary behavior.
- Evolution upgrade lines should generally **not** be five levels of raw damage scaling.
- Level 1 should be immediately noticeable.
- Levels 1–4 should usually improve coverage, reliability, frequency, or interaction strength.
- Level 5 should usually create a major capped spectacle effect.
- Recursive effects must use:
  - generation caps,
  - trigger limits,
  - global cooldowns,
  - target caps,
  - or damage falloff.
- Evolution upgrades should feel like an **optional overclock**, not a requirement for making a weak Evolution functional.

---

# 29. Spore + Bloom Evolution Upgrade

## Super Bloom

### Evolution Upgrade: Floral Cascade

Super Bloom is already the benchmark for Evolution satisfaction, so its upgrade line should increase chain spectacle without greatly increasing raw Plant mass generation.

#### Level 1 — Cascade Force
- Secondary Blooms retain approximately **15% more Bloom Force** from the Bloom that triggered them.
- Does not increase Plant Mass.

#### Level 2 — Deep Cascade
- Super Bloom chains can propagate **one additional generation** before stopping.

#### Level 3 — Forced Germination
- Every fourth Super Bloom immediately germinates one nearby active Seed.
- Suggested **2-second global cooldown**.

#### Level 4 — Cascade Force II
- Secondary Blooms retain another **15% Bloom Force**.
- Still does not increase Plant Mass.

#### Level 5 — Grand Bloom
- Every sixth Super Bloom becomes a **Grand Bloom**.
- Grand Bloom gains:
  - greatly increased area,
  - much stronger pressure,
  - stronger visual impact.
- Grand Bloom should not inject significant additional Plant Mass.

### Design Goal
> Make Super Bloom even more spectacular without allowing it to completely replace Spore as the best source of new Green territory.

---

# 30. Spore + Bramble Evolution Upgrade

## Briar Pods

### Evolution Upgrade: Tangleburst

Briar Pods should lean into **mass crowd control** rather than direct damage.

#### Level 1 — Tangled Germination
- Seed germination immediately applies additional Entanglement to enemies caught in the newly created Green.
- Suggested starting value: approximately **15% Entanglement**.

#### Level 2 — Grasping Shoots
- Enemies already above roughly 70% Entanglement when a Seed germinates are briefly rooted.
- Suggested additional root duration: approximately **0.35 seconds**.

#### Level 3 — Constricting Growth
- Germinating Seeds briefly pull nearby enemies toward their center before the Green patch fully expands.

#### Level 4 — Aggressive Growth
- Newly created Seed territory gains approximately **+50% Ensnare Rate for 3 seconds**.

#### Level 5 — Mass Entanglement
- Every fifth germinating Seed releases a large Briar pulse.
- Normal enemies caught by the pulse immediately reach maximum Entanglement.
- Elites receive a reduced amount.
- Bosses receive a much smaller amount.
- Use a short global cooldown if needed.

### Design Goal
> A large Seed-germination event should suddenly pin down major portions of an enemy mob.

---

# 31. Spore + Root Evolution Upgrade

## Seed Bank

### Evolution Upgrade: Seed Reserve

Seed Bank should become more satisfying through synchronized territorial events rather than direct damage.

#### Level 1 — Expanded Reserve
- Mature territory can store approximately **20% more dormant Seeds**.

#### Level 2 — Heavy Seeding
- Dormant Seeds accumulate approximately **15% faster**.

#### Level 3 — Established Stock
- Seeds released during Germination Season inherit a portion of the maturity of the territory that stored them.
- Suggested value: approximately **20% maturity inheritance**.
- Inheritance should be capped so Seeds cannot instantly become fully Mature.

#### Level 4 — Expanded Reserve II
- Seed storage capacity increases another **20%**.

#### Level 5 — Mast Year
- Every third Germination Season produces a second germination wave approximately 1.5 seconds later.
- The second wave contains roughly **50% as many Seeds** as the first.

### Design Goal
> Seed Bank should create enormous ecosystem-wide territorial surges even if its direct damage remains modest.

---

# 32. Spore + Kudzu Evolution Upgrade

## Sporulation

### Evolution Upgrade: Airborne Spores

#### Level 1 — Seed Volley
- Each Kudzu Crown launches **one additional Seed** whenever it produces Seeds.

#### Level 2 — Long-Distance Dispersal
- Crown-launched Seeds travel farther.
- They preferentially target areas farther from existing Green territory.

#### Level 3 — Establishment Burst
- When a new Crown finishes rooting, it immediately releases a radial Seed burst.

#### Level 4 — Rapid Sporulation
- Crowns produce Seeds approximately **15% more frequently**.

#### Level 5 — Crown Seed
- Every third Crown Seed volley contains one special Seed.
- If Crown Capacity is available, the special Seed attempts to establish another Kudzu Crown.
- If Crown Capacity is full, it becomes an oversized normal Seed instead.

### Design Goal
> Create escalating outbreaks across multiple parts of the arena without allowing infinite Crown multiplication.

---

# 33. Spore + Pruning Evolution Upgrade

## Coppice

### Evolution Upgrade: Second Flush

#### Level 1 — Dense Reseeding
- Pruning creates approximately **20% more dormant Seeds** in Pruned Ground.

#### Level 2 — Rapid Germination
- Those dormant Seeds germinate approximately **15% sooner**.

#### Level 3 — Fertile Cut
- Seeds germinating on Pruned Ground create approximately **20% more Growth Mass**.

#### Level 4 — Blood and Soil
- Kills caused by Cuttings during a Pruning Cycle can create bonus dormant Seeds in nearby Pruned Ground.
- Suggested cap: approximately **6 bonus Seeds per cycle**.

#### Level 5 — Second Flush
- Every third Pruning Cycle causes a second germination wave.
- The second wave contains roughly **50% of the first wave's Seed count**.

### Design Goal
> Territory retracts, Cuttings kill enemies, then the ecosystem regrows in one or two dramatic waves.

---

# 34. Bloom + Bramble Evolution Upgrade

## Thornburst

### Evolution Upgrade: Briar Payload

Because base Bramble is now mainly crowd control, Thornburst should provide a strong offensive payoff.

#### Level 1 — Packed Thorns
- Bloom generates approximately **20% more Briar Traps** from the same amount of Bramble-covered territory.

#### Level 2 — Sensitive Traps
- Briar Trap trigger radius increases approximately **20%**.

#### Level 3 — Barbed Blast
- Briar Trap explosions immediately apply a significant amount of Entanglement.
- Suggested value: approximately **35% Entanglement**.

#### Level 4 — Chain Fuse
- Trap-to-trap chain-reaction range increases approximately **20%**.
- Traps triggered by another trap may deal reduced damage if needed to control scaling.

#### Level 5 — Briar Heart
- Every fifth generated trap becomes a **Briar Heart**.
- Briar Hearts:
  - have a larger trigger radius,
  - can detonate multiple times,
  - apply strong Entanglement,
  - create much larger spike explosions.
- Suggested cap: approximately **one Briar Heart per Bloom**.

### Design Goal
> Thornburst should become a cascading living minefield rather than merely stronger passive Bramble.

---

# 35. Bloom + Root Evolution Upgrade

## Flowering Season

### Evolution Upgrade: Seasonal Surge

Bloom + Root is already a strong territory combination, so its upgrade line should emphasize **pressure and distribution**, not raw Plant mass.

#### Level 1 — Spring Pressure
- Flowering Season Blooms gain approximately **+15% Bloom Force**.
- No additional Plant Mass.

#### Level 2 — Encroachment
- Flowering Season Blooms gain approximately **+20% Conversion Pressure against Hostile territory only**.

#### Level 3 — Distributed Flowering
- Flowering Season preferentially places Blooms across different frontier sectors rather than clustering several Blooms in the same area.

#### Level 4 — Spring Pressure II
- Gain another approximately **+15% Bloom Force**.
- Still no additional Plant Mass.

#### Level 5 — Second Spring
- Shortly after Flowering Season ends, up to four **Echo Blooms** appear.
- Echo Blooms:
  - use roughly 35% normal Bloom Force,
  - inject **zero new Plant Mass**,
  - only push and deform existing Green territory.

### Critical Balance Rule
> Root + Bloom should become better at moving and contesting territory, not better than Seeds at generating new Green.

---

# 36. Bloom + Kudzu Evolution Upgrade

## Wildflower Network

### Evolution Upgrade: Relay Bloom

#### Level 1 — Faster Relay
- Time between consecutive Crown Blooms decreases approximately **20%**.

#### Level 2 — Building Pressure
- Each later Crown in the Bloom sequence gains additional Bloom Force.
- Suggested: **+10% Force per previous Crown**, capped around +30%.
- Does not increase Plant Mass.

#### Level 3 — Invasive Flowering
- Crown Blooms gain increased Conversion Pressure against Hostile territory.

#### Level 4 — Faster Relay II
- Relay delay decreases another approximately **20%**.

#### Level 5 — Synchronized Flowering
- After the final Crown in the sequence Blooms, all active Crowns simultaneously emit an Echo Bloom.
- Echo Blooms:
  - use roughly 30% normal Force,
  - generate zero new Plant Mass.
- Suggested global cooldown: approximately **10 seconds**.

### Design Goal
> Create a recognizable arena-wide chain of territorial explosions across disconnected colonies.

---

# 37. Bloom + Pruning Evolution Upgrade

## Rebound

### Evolution Upgrade: Compression

#### Level 1 — Efficient Compression
- Each unit of Green consumed by Rebound generates approximately **15% more Bloom Force**.

#### Level 2 — Elastic Growth
- Green reclaims Pruned Ground created by Rebound approximately **20% faster**.

#### Level 3 — Inward Collapse
- The compression stage pulls nearby enemies toward the Bloom before detonation.

#### Level 4 — Efficient Compression II
- Another approximately **15% improvement** to territory-to-Force conversion.
- Total conversion should be capped.

#### Level 5 — Elastic Rebound
- Roughly 1.25 seconds after the main Bloom detonates, it creates a second pressure wave at approximately **45% of the original Force**.
- The second wave:
  - requires no additional territory sacrifice,
  - creates no additional Plant Mass.

### Design Goal
> The ecosystem visibly collapses inward and then explodes outward in two dramatic pressure events.

---

# 38. Bramble + Root Evolution Upgrade

## Old Growth

### Evolution Upgrade: Ancient Fury

#### Level 1 — Deep Eruption
- Root eruption radius increases approximately **15%**.

#### Level 2 — Thorned Roots
- Root eruptions apply significant Entanglement to surviving enemies.

#### Level 3 — Root Cascade
- Enemies killed by a Root eruption can trigger **one additional generation of eruptions**.
- Secondary eruptions should deal reduced damage, such as approximately 70%, to control recursive scaling.

#### Level 4 — Restless Forest
- Old Growth can trigger when enemies reach approximately **85% Entanglement** instead of requiring complete Entanglement.

#### Level 5 — Forest Awakening
- When enough heavily Entangled enemies occupy Mature Green territory simultaneously, several Mature regions erupt at once.
- Example condition:
  - 6 or more qualifying enemies.
- Example effect:
  - up to 6 major Root eruptions across Mature territory.
- Suggested global cooldown: approximately **10 seconds**.

### Design Goal
> The ancient ecosystem should visibly wake up and attack the invasion across large portions of the arena.

---

# 39. Bramble + Kudzu Evolution Upgrade

## Briar Bastions

### Evolution Upgrade: Fortress Network

#### Level 1 — Defensive Response
- Bastion pulses apply approximately **20% more Entanglement**.

#### Level 2 — Repulsive Hedge
- Bastion pulses gain stronger knockback.

#### Level 3 — Lockdown
- Fully Entangled enemies caught by a Bastion pulse are briefly rooted.
- Elites and bosses receive reduced immobilization.

#### Level 4 — Living Rampart
- Bastion pulse cooldown decreases approximately **15%**.

#### Level 5 — Mutual Defense
- Whenever any Kudzu Crown falls below roughly 50% health, **every active Crown simultaneously triggers its Bastion pulse**.
- Suggested global cooldown: approximately **10–12 seconds**.

### Design Goal
> Multiple remote Green colonies should suddenly defend themselves at the same time.

---

# 40. Bramble + Pruning Evolution Upgrade

## Deadfall

### Evolution Upgrade: Splinterstorm

#### Level 1 — Thorn Harvest
- Pruning Bramble-covered Green produces approximately **20% more thorn Cuttings**.

#### Level 2 — Piercing Splinters
- Thorn Cuttings gain **+1 Pierce**.
- The pierced hit should deal reduced damage, such as approximately 60%.

#### Level 3 — Shatter
- When a Cutting strikes a fully Entangled enemy, it splits once into two smaller spikes that seek different nearby enemies.
- Split spikes deal substantially reduced damage.

#### Level 4 — Thorn Harvest II
- Gain another approximately **20% thorn Cutting yield**.

#### Level 5 — Deadfall Volley
- Every Pruning Cycle additionally launches a radial volley of large spikes.
- Suggested behavior:
  - approximately 8 large spikes,
  - high Pierce,
  - strong knockback,
  - damage falloff through consecutive enemies.

### Design Goal
> Bramble + Pruning should turn controlled Green territory into a visually overwhelming storm of wooden shrapnel.

---

# 41. Root + Kudzu Evolution Upgrade

## Rhizome Network

### Evolution Upgrade: Mycorrhizal Exchange

#### Level 1 — Nutrient Transfer
- The youngest connected Kudzu colony gains approximately **+15% Maturation Speed**.

#### Level 2 — Network Pressure
- Synchronized Rhizome growth surges gain approximately **+15% territorial pressure**.
- No additional Plant Mass.

#### Level 3 — Emergency Routing
- If a connected Crown is destroyed, part of its stored maturity or Root strength is redistributed to surviving Crowns instead of being completely lost.
- A Runner may also attempt to reclaim the lost area.
- Use a cooldown to prevent repeated exploitation.

#### Level 4 — Rapid Exchange
- Rhizome surge cooldown decreases approximately **15%**.

#### Level 5 — Systemic Flush
- Every third Rhizome surge simultaneously activates:
  - every Mature Kudzu colony,
  - the main Mature ecosystem.
- All connected regions surge outward together.
- The effect should emphasize pressure rather than free Plant Mass.

### Design Goal
> Distant Mature colonies should visibly behave as one interconnected organism.

---

# 42. Root + Pruning Evolution Upgrade

## Coppicing

### Evolution Upgrade: Stool Regrowth

#### Level 1 — Mature Harvest
- Pruning Mature territory generates approximately **15% more Cuttings**.

#### Level 2 — Vigorous Regrowth
- Pruned Mature Ground regrows approximately **20% faster**.

#### Level 3 — Root Memory
- Territory regrowing over formerly Mature Pruned Ground retains roughly **25% of its former maturity**.

#### Level 4 — Mature Harvest II
- Gain another approximately **15% Cutting yield** from Mature territory.

#### Level 5 — Second Harvest
- Once per Pruning Cycle, when roughly half of the Mature territory removed by that cycle has regrown, it releases a second Cutting volley equal to approximately **40% of the original harvest**.
- No additional territory is consumed.

### Design Goal
> Root + Pruning should create a repeating rhythm of harvest, devastation, rapid regrowth, and renewed offense.

---

# 43. Kudzu + Pruning Evolution Upgrade

## Vegetative Propagation

The previous Evolution name **Cuttings** should be changed to **Vegetative Propagation** to avoid confusion with Pruning's Cutting projectile resource.

### Evolution Upgrade: Clone Storm

#### Level 1 — Viable Cuttings
- Increase the percentage of Pruning Cuttings capable of becoming living propagules.
- Keep a cap on actual Crown-establishment attempts per cycle.

#### Level 2 — Rapid Rooting
- Propagules root approximately **20% faster**.

#### Level 3 — No Waste
- If Crown Capacity is full, living propagules no longer disappear.
- Instead, they seek an existing Crown and:
  - accelerate rooting,
  - repair the Crown,
  - or trigger a small Runner burst.

#### Level 4 — Successful Cloning
- Allow **one additional Crown-establishment attempt per Pruning Cycle**.
- Overall Crown Capacity still applies.

#### Level 5 — Clone Storm
- Every third Pruning Cycle guarantees several long-range living Cuttings.
- Suggested behavior:
  - approximately 2 major propagules launch toward distant valid territory.
- If Crown Capacity is available:
  - they attempt to establish Crowns.
- If capacity is full:
  - they create temporary satellite Green patches instead.

### Design Goal
> The player tears apart one ecosystem and physically scatters viable pieces of it across the arena to reproduce elsewhere.

---

# 44. Evolution Upgrade Balance Targets

Evolution upgrades should not all provide identical numerical power.

They should instead offer roughly equal **decision value**.

| Evolution Upgrade | Primary Payoff |
|---|---|
| Floral Cascade | More chain spectacle |
| Tangleburst | Mass crowd control |
| Seed Reserve | Large territory events |
| Airborne Spores | Remote propagation |
| Second Flush | Sacrifice and regrowth loop |
| Briar Payload | Burst damage |
| Seasonal Surge | Frontier pressure |
| Relay Bloom | Distributed Bloom chains |
| Compression | Burst territorial displacement |
| Ancient Fury | Reactive screen clearing |
| Fortress Network | Multi-front defense |
| Splinterstorm | Horde clearing |
| Mycorrhizal Exchange | Network scaling |
| Stool Regrowth | Harvest and regrowth cycle |
| Clone Storm | Remote proliferation |

## Global Balance Rules

- Evolution upgrade Level 1 should be noticeable immediately.
- Levels 1–4 should generally increase:
  - coverage,
  - frequency,
  - reliability,
  - interaction strength,
  - or controlled secondary effects.
- Avoid simply stacking raw damage every level.
- Level 5 should usually introduce a **capped spectacle event**.
- Any recursively triggered effect needs:
  - a generation cap,
  - global cooldown,
  - per-cycle trigger cap,
  - target cap,
  - or damage falloff.
- Additional targets, Pierce, and secondary chains should often use reduced damage on later hits.
- Bloom Evolution upgrades should favor:
  - Force,
  - Conversion Pressure,
  - synchronization,
  - positional coverage.
- Bloom Evolution upgrades should **not** substantially increase raw Plant Mass generation.
- Seeds remain the best source of genuinely new Green territory.
- The player should be able to skip the Evolution upgrade and invest both post-Evolution slots into the third Path without feeling like they made an obviously incorrect choice.

> **Level 0 Evolution should already be satisfying. Level 5 should make the player laugh at how absurd the build has become.**

