# Sporekeeper Campaign Pacing and Balance Rework

**Status:** Design specification and implementation recommendation  
**Scope:** Campaign mode only  
**Target runtime:** Approximately 20 minutes maximum at baseline pace  
**Primary goals:** Improve pacing, reduce runaway late-game dominance, preserve powerful builds, strengthen weak early-game Adaptations, and make territory matter as more than a passive percentage.

---

# 1. Executive Summary

Sporekeeper's current Campaign structure has two major problems:

1. **Build power matures too early relative to the remaining runtime.**
2. **Raw damage currently solves too many problems at once.**

The measured Campaign run showed a strong build reaching its first Evolution around minute 7 and Evolution rank 3 around minute 13, then continuing for another 12 minutes while becoming increasingly dominant. The late run therefore has too much time after the build's most meaningful progression has already happened.

The pair sweep also showed that several early Path combinations provide almost no immediate combat value, while damage-heavy combinations solve offense, defense, and territory control simultaneously. This means the game currently rewards killing more than it rewards defensive or territory-focused mechanics, even when those mechanics are supposed to be the identity of the build.

The proposed Campaign rework addresses these problems through a new structure:

- Reduce Campaign from 25 minutes to approximately **20 minutes maximum**
- Reduce normal Path count from 4 to **3 Paths**
- Keep **4 upgrades per Path, 3 ranks each**
- Allow approximately **2 Evolutions per run**
- Make Evolutions available through **eligible Path relationships** rather than fixed pairing locks
- Separate Evolution rewards from ordinary level-up rewards
- Replace density-heavy difficulty scaling with a **Threat Director**
- Use curated enemy composition recipes instead of pure procedural spawning
- Add **run-wide Provocation**, allowing strong players to summon the next wave early
- Make Provocation permanently increase **Blight**
- Make earlier Provocations create a temporary **Surge**
- Reward successful Provocations with small **universal Growth choices**
- Keep Cankers driven by territory failure rather than the enemy Director
- Avoid hidden difficulty scaling based on Grandma's DPS or build strength
- Preserve the ability for powerful builds to become visibly absurd
- Fix weak rank-1 Adaptations before aggressively nerfing strong Paths

The central pacing philosophy becomes:

> The player should become powerful quickly, complete their build before the end of the run, and then spend the final portion of Campaign proving that the build can survive increasingly dangerous situations.

The game should respond to strong builds by presenting harder problems, not by secretly cancelling their stats.

---

# 2. Design Goals

## 2.1 Build identity should appear early

By roughly the first quarter of the run, the player should understand what their build is becoming.

A Path should not require several minutes of investment before producing a visible or useful effect.

Every Path should contribute meaningfully at rank 1 through at least one of the following:

- immediate damage
- enemy control
- territory defense
- territory reclamation
- survivability
- meaningful support for an already-owned combat mechanic

A Path may remain low-DPS if it compensates through another axis that actually matters during real encounters.

## 2.2 Player power should grow quickly

Sporekeeper should retain the survivor-like fantasy of rapid escalation.

The player should feel substantially stronger at minute 5 than at minute 1, and dramatically stronger at minute 10 than at minute 5.

The goal is not to flatten the player's power curve.

The goal is to make the enemy ecosystem and Campaign structure continue creating meaningful decisions after the player becomes powerful.

## 2.3 The final quarter should be the hardest part of Campaign

The last 5 minutes should test a mostly completed build.

They should not primarily function as additional build assembly time.

Late Campaign difficulty should come from:

- specialists
- elites
- threatening combinations
- territorial crises
- individually dangerous enemies
- coordinated pressure
- Cankers
- bosses and milestone encounters

It should not come mainly from placing more weak bodies on screen.

## 2.4 Damage should not solve every problem

Currently, killing enemies faster also:

- protects Grandma
- protects Green
- reduces territory erosion
- prevents enemy population buildup
- indirectly improves board control

That makes high-damage builds unusually good at every axis.

The rework should create encounters where:

- slowing matters
- displacement matters
- mature Green matters
- reclamation matters
- territory retention matters
- distributed defense matters
- movement matters

Damage should remain important, but not sufficient for every challenge.

## 2.5 Strong builds must still feel strong

Do not use hidden scaling that directly cancels build strength.

Avoid systems such as:

- enemy HP scaling directly from Grandma's DPS
- enemy damage scaling from theoretical build power
- intentionally spawning specific counters because a certain Path is owned
- adjusting enemy stats so that weak and strong builds have similar kill times

If the player creates an extreme build, they should visibly experience that power.

Difficulty should respond through encounter structure, enemy quality, voluntary Provocation, and authored Campaign progression.

---

# 3. Campaign Runtime

## Required Change

Reduce the natural Campaign runtime from approximately **25 minutes to approximately 20 minutes**.

The 20-minute value should be treated as a **maximum natural runtime**, not necessarily the exact duration of every successful run.

Provocation can allow strong players to finish earlier.

## Why

The current measured Campaign progression reaches:

- first Evolution around minute 7
- Evolution rank 2 around minute 11
- Evolution rank 3 around minute 13
- end of run around minute 25

This leaves roughly half of the current Campaign after the major Evolution progression is already complete.

A 20-minute structure keeps enough time for the player to enjoy a mature build without forcing the run to spend another 10 to 12 minutes in mostly solved combat.

## Target Emotional Arc

### 0:00 to 5:00
**Build identity**

The player establishes their Paths and early upgrade direction.

### 5:00 to 10:00
**Synergy**

The first major interactions come online. The first Evolution becomes possible.

### 10:00 to 15:00
**Transformation**

The second major Evolution opportunity appears. The build approaches maturity.

### 15:00 to 20:00
**Examination**

The build is largely complete. The game now asks whether it can survive increasingly dangerous enemy compositions and territory pressure.

---

# 4. Campaign Act Structure

The 20-minute Campaign should be divided into four broad acts.

These acts do not need to be heavily labeled in the UI, but the enemy pool and encounter structure should clearly change.

## Act I: Germination

**Approximate waves:** 1 to 5  
**Natural time:** 0 to 5 minutes

### Goals

- establish the player's initial build
- introduce basic enemies
- teach current enemy roles
- avoid immediate lethal pressure
- give every Path time to demonstrate its identity

### Enemy composition

Mostly cheap enemies.

Specialists should be limited or introduced carefully.

### Player progression

The player should acquire all three Paths by the end of this act or shortly after.

## Act II: Encroachment

**Approximate waves:** 6 to 10  
**Natural time:** 5 to 10 minutes

### Goals

- begin serious build synergy
- introduce mixed enemy compositions
- introduce first major Canker risk
- create first meaningful pressure spike
- provide first Evolution opportunity

### Enemy composition

Specialists become normal components of encounter recipes.

The Director begins using more expensive units rather than simply increasing population.

### Player progression

The first Evolution should normally become available somewhere in the **6 to 8 minute** region if its requirements have been satisfied.

## Act III: Infestation

**Approximate waves:** 11 to 15  
**Natural time:** 10 to 15 minutes

### Goals

- complete the core build
- introduce stronger elite and specialist combinations
- increase territory consequences
- provide the second major Evolution opportunity
- make enemy composition matter more than raw population

### Enemy composition

More coordinated recipes.

Examples:

- elite spearhead
- siege push
- split pressure
- rush assault
- Canker reinforcement

### Player progression

The player should be approaching a mature build by roughly minute 13 to 15.

## Act IV: Blight

**Approximate waves:** 16 to 19  
**Natural time:** 15 to 19 minutes

### Goals

- stress-test the completed build
- minimize filler
- maximize threatening compositions
- create serious territory crises
- force movement and prioritization
- prepare for the final encounter

The player's main progression during this act should come from final upgrades, Growth rewards, relic interactions, and tactical execution rather than discovering the basic identity of the build.

## Finale

**Approximate wave:** 20

The final encounter should test the systems the run has built toward.

The final boss or final encounter should inherit the current Blight state.

Repeated Provocation should therefore make the finale substantially harder.

---

# 5. Path Structure

## Required Change

Reduce the normal Campaign Path limit from **4 Paths to 3 Paths**.

Retain:

- 1 base Path acquisition
- 4 upgrades per Path
- 3 ranks per upgrade

## Why Three Paths

With three owned Paths:

- A
- B
- C

there are exactly three possible pair relationships:

- A + B
- A + C
- B + C

This provides enough Evolution variety without creating excessive upgrade dilution or six competing pair relationships.

Three Paths also allow each individual Path to occupy a larger portion of the player's run identity.

## Optional Future Exception

A fourth Path may eventually be introduced as a rare exceptional reward.

This should not be part of normal Campaign balance.

Possible sources:

- rare relic
- special event
- major achievement reward
- unusual Clover result
- late-run unique encounter

A fourth Path should feel like the run is breaking normal rules.

---

# 6. Path Acquisition Timing

## Recommended

Separate Path acquisition from ordinary upgrade randomness.

A possible structure:

- **Start:** choose Path 1
- **Around 2 minutes:** choose Path 2
- **Around 4 to 5 minutes:** choose Path 3

The exact timing requires playtesting.

## Why

The measured pacing data showed that early upgrade ordering can determine whether a build functions at all.

The identity of the player's build should not depend entirely on whether random upgrade rolls cooperate.

Randomness should influence how the build develops, not whether the player is allowed to obtain a coherent build.

---

# 7. Rank-1 Path Functionality

## Required Balance Goal

Every Path must provide meaningful value immediately.

The current benchmark found several rank-1 pairings performing at or near bare-Cane output.

This is unacceptable for the early Campaign pacing target.

## Important Clarification

The target should **not** be:

> Every rank-1 Path must increase DPS by the same amount.

Instead:

> Every rank-1 Path must materially improve the player's ability to survive, control, reclaim, defend, or kill.

## Root

Root currently works best when it amplifies an already productive partner.

A Root build with no compatible output mechanic can receive almost no immediate benefit.

### Recommended Direction

Allow Root to improve at least one universal baseline mechanic such as the Cane, or otherwise provide immediate defensive/territorial value strong enough to function without a high-output partner.

Do not turn Root into a generic damage Path.

The goal is to give Root a floor.

## Bramble

Current contact damage is too small to create meaningful immediate threat.

### Recommended Direction

Increase or redesign Bramble's early contact effect so enemies meaningfully care about standing in Bramble.

Possible directions:

- stronger chip damage
- stronger slow tied to mature territory
- damage that increases with time spent inside Bramble
- displacement or stagger thresholds
- territory-based punishment that does not require high DPS

## Spore and Bloom

Both can create delayed value rather than immediate body removal.

### Recommended Direction

Give the first rank a visible early-game contribution.

This does not need to be direct damage.

Possible examples:

- immediate small reclamation
- enemy weakening
- temporary control
- short-lived territory protection
- effects triggered by first kill or first successful spread event

The exact mechanics still require design work.

---

# 8. Evolution System

## Required Structural Change

Evolutions should no longer be permanently determined by an early Path pairing.

Instead:

> Any Evolution whose Path requirements are currently satisfied becomes eligible to appear in an Evolution reward.

## Example

If Grandma owns:

- Root
- Vine
- Thistle

then these Evolution relationships may become eligible:

- Root + Vine
- Root + Thistle
- Vine + Thistle

The player is not required to declare one pair in advance.

## Normal Evolution Count

Target approximately **2 Evolutions per normal Campaign run**.

This provides enough transformation without turning every possible Path pairing into active mechanical clutter.

## Path Reuse

A Path should be allowed to participate in more than one Evolution.

Example:

- Root + Vine evolves
- Vine remains eligible for Vine + Thistle later

Taking one Evolution should not consume either Path.

## Eligibility

The exact threshold is not yet decided.

The system should require meaningful investment in both Paths.

Possible requirements include:

- both Paths owned
- minimum number of distinct upgrades in both Paths
- minimum total ranks invested across the pair
- mastery of specific lines

Avoid requiring both Paths to be completely maxed if that prevents multiple Evolutions from appearing within a 20-minute run.

## Evolution Rewards

Evolutions should come from special reward moments rather than normal level-up rolls.

Potential sources:

- wave milestones
- bosses
- major elites
- Trials
- special Campaign events

When an Evolution reward occurs:

1. collect all currently eligible Evolutions
2. randomly select a small number
3. present them as a choice
4. allow the player to adapt to the offered result

The exact number of offered Evolutions should be tuned, but **up to 3** is a strong starting point.

## Timing Targets

Recommended:

- first Evolution: approximately 6 to 8 minutes
- further Evolution development: 9 to 13 minutes
- second Evolution opportunity: approximately 10 to 15 minutes

The build should generally be mature before the final 5 minutes.

---

# 9. Thornwhip Balance Change

## Required Near-Term Change

Implement the proposed Thornwhip mounted-head correction before broadly nerfing Thistle.

Current Thornwhip multiplies:

- mounted heads
- Clustering projectile count
- Burr ricochets
- Needlepoint critical scaling
- Vine sweep cadence

This produces excessive multiplicative scaling.

## Recommended Implementation

Mounted heads fire **one thorn** instead of a full Clustering volley.

Compensate the mounted thorn with increased damage so the Evolution still feels substantial.

The measured proposal used approximately:

```gdscript
var projectile_count := 1
var scale := 2.0
```

Measured damage improvement over unevolved Thistle + Vine became approximately:

- Evolution rank 1: +16%
- Evolution rank 3: +36%
- Evolution rank 5: +67%

This is substantially healthier than the current:

- +50%
- +70%
- +115%

## Why This Approach

This removes an entire multiplicative axis.

That is preferable to globally reducing Thistle damage just because one Evolution creates an extreme interaction.

---

# 10. Burr Ricochet Tuning

## Status

**Do not implement immediately.**

The proposal to reduce damage on successive Burr ricochets remains plausible, but it affects all Thistle builds.

Base Thistle is not universally dominant in the measured pair sweep.

## Recommended Process

1. implement Thornwhip correction
2. fix weak early Paths
3. rerun pair sweep
4. evaluate Thistle independently
5. test several ricochet falloff values if needed

Potential test values:

- 0.85
- 0.80
- 0.75
- 0.70

Do not jump directly to 0.70 without new measurements.

---

# 11. Vine Elongation Tuning

## Status

**Needs isolated testing before implementation.**

Vine is clearly strong across the current pair sweep, but the measurements do not isolate Elongation from Vine's other upgrades.

## Required Code Quality Change

Move Vine's hard-coded per-rank tuning values into exported variables.

This allows rapid balancing without code edits.

## Recommended Test

Benchmark each Vine upgrade independently:

- damage
- cadence
- reach
- other Vine scaling

Measure:

- damage
- targets hit
- effective coverage
- kills
- territory held
- damage taken

Only reduce Elongation after confirming that reach is a primary source of Vine dominance.

---

# 12. Pruning

## Required Decision

**Do not nerf Pruning yet.**

The current siege benchmark strongly favors Pruning's design conditions:

- Grandma stands still
- enemies surround her
- the Cutting ring has constant target access
- the simulation may underrepresent the real ecological cost

## Required Next Step

Run full Campaign playtests with Pruning before changing numbers.

Measure:

- Green loss from upkeep
- territory collapse risk
- actual movement requirements
- defensive value
- damage taken
- output
- interaction with Cankers

---

# 13. Threat Director

## Required Structural Change

Move away from raw spawn density as the main late-game difficulty mechanism.

Introduce a **Threat Director**.

## Core Concept

Each enemy receives a Threat Cost.

Illustrative values only:

| Enemy | Example Threat Cost |
|---|---:|
| Hunter | 10 |
| Rusher | 15 |
| Grazer | 18 |
| Heavy Grazer | 35 |
| Siege Corruptor | 45 |
| Elite Rusher | 55 |
| Elite Heavy | 80 |

Each wave receives a total threat budget.

The Director spends that budget on a legal encounter composition.

## Why

More enemies can increase the efficiency of:

- Vine sweeps
- Thistle ricochets
- Pruning rings
- AoE effects
- multi-target Evolutions

Late difficulty therefore needs to increasingly spend budget on **higher-quality threats**, not simply larger populations.

---

# 14. Curated Encounter Recipes

## Required Design Recommendation

Do not allow the Threat Director to randomly purchase arbitrary enemies until its budget is empty.

Instead, provide curated encounter recipes.

Possible recipes:

## Rush Assault

High movement pressure.

Typical contents:

- Rushers
- Hunters
- optional elite leader

## Heavy Front

Slow but dangerous pushing pressure.

Typical contents:

- Heavy Grazers
- supporting Hunters
- displacement or territory erosion support

## Siege Push

Attacks territory structure rather than simply chasing Grandma.

Typical contents:

- Siege Corruptor
- escorts
- optional ranged support

## Split Pressure

Creates simultaneous threats on different sides of the arena.

Useful for challenging stationary or highly localized builds.

## Elite Spearhead

One expensive elite plus a smaller supporting force.

Useful for testing single-target priority without dramatically increasing total density.

## Canker Reinforcement

Uses an existing Canker as a focal point for enemy pressure.

The Director does not create the Canker itself.

---

# 15. Enemy Pool Gating

Campaign progression determines what the Director is allowed to use.

Example:

## Act I

- basic enemies
- minimal specialist access

## Act II

- first meaningful specialists
- basic mixed recipes

## Act III

- elites
- advanced specialist combinations
- Canker reinforcement recipes

## Act IV

- highest-cost packages
- elite specialists
- coordinated combinations
- minimal filler

This keeps progression authored even though individual encounters vary.

---

# 16. Wave Pressure Rhythm

## Recommended

Each normal wave should have an internal pressure rhythm.

Conceptually:

1. **Build-up**
2. **Peak**
3. **Recovery**

A possible 60-second prototype:

- 0 to 10 sec: establish composition
- 10 to 35 sec: build pressure
- 35 to 50 sec: peak
- 50 to 60 sec: recovery

Exact times require playtesting.

## Purpose

This creates contrast.

Without recovery periods, constant pressure becomes emotionally flat.

The recovery period also creates a meaningful resource that Provocation can remove.

---

# 17. Run-Wide Provocation

## Required New Mechanic

Allow the player to summon the next wave early.

Provocation should be available throughout the Campaign, not only for the final boss.

## Core Behavior

When Provocation is activated:

1. current enemies remain alive
2. the next wave begins immediately
3. the normal recovery period is skipped
4. a temporary Surge may be applied
5. if this is a rewarded Provocation, permanent Blight increases
6. surviving the provoked encounter grants a Growth choice

## Core Fantasy

The player is saying:

> My build is ready. Give me the future now.

---

# 18. Provocation Availability

## Recommended Prototype Rule

A 60-second wave becomes naturally provokable after approximately **40 seconds**.

This is a starting point only.

A later refinement could also unlock Provocation earlier if the player has already eliminated most of the current wave's threat budget.

Possible hybrid rule:

Provocation becomes available when either:

- 40 seconds have elapsed
- or 70 to 80% of the current wave's threat has been cleared

This rewards dominant play without directly reading theoretical DPS.

---

# 19. Campaign Runtime Under Provocation

The natural Campaign remains approximately 20 minutes.

Expected successful runtimes might become:

- conservative run: 19 to 20 minutes
- moderate Provocation: 17 to 19 minutes
- aggressive Provocation: 15 to 17 minutes

Do not allow Campaign compression to become extreme.

A strong run should be faster, but the progression structure still needs time to breathe.

---

# 20. Blight

## Required New Mechanic

Rewarded Provocation permanently increases **Blight**.

Blight represents the ecosystem becoming more dangerous because Grandma deliberately accelerated it.

## Design Principle

Blight should increase difficulty primarily through:

- Director budget
- composition quality
- specialist access
- elite affordability

Raw HP and damage can increase modestly, but should not dominate the system.

## Prototype Blight Table

**These values are starting points only and require benchmarking.**

| Blight | Director Budget | Enemy HP | Enemy Damage | Composition |
|---|---:|---:|---:|---|
| 0 | baseline | baseline | baseline | normal |
| I | +8% | +4% | +2% | slightly more specialists |
| II | +16% | +8% | +4% | elites more affordable |
| III | +24% | +12% | +6% | stronger mixed compositions |
| IV | +32% | +16% | +8% | elite specialists common |
| V | +40% | +20% | +10% | highest-cost packages |

## Visibility

Blight should be clearly visible in the HUD.

Example:

**BLIGHT III**

The player should always understand why the run has become harder.

---

# 21. Surge

## Required Companion Mechanic

Separate immediate Provocation danger from permanent Blight.

### Blight

Permanent difficulty.

### Surge

Temporary front-loaded threat caused by calling the next wave especially early.

## Recommended Behavior

The earlier the player Provokes, the larger the initial Director credit injection for the next encounter.

Illustrative example:

- 5 seconds early: small Surge
- 10 seconds early: moderate Surge
- 20 seconds early: large Surge

The bonus should be spent primarily at the beginning of the next wave so early Provocation creates a clear immediate consequence.

## Important Rule

Earlier Provocation should increase **danger**, not dramatically increase permanent rewards.

---

# 22. Growth Rewards

## Required New Reward Type

After surviving a rewarded Provocation, Grandma receives:

> Choose 1 of 3 Growths.

Growths are universal stat increases.

## Candidate Stats

- Damage
- Attack Speed
- Movement Speed
- Area or Reach
- Max HP
- Armor or damage reduction
- Recovery

## Design Rules

Growth should:

- remain mechanically simple
- be smaller than Path upgrades
- not create unique new mechanics
- use additive stacking where possible
- have per-stat rank caps
- never become more important than Paths, relics, or Evolutions

## Example Scale

Prototype examples only:

- +4% Damage
- +4% Attack Speed
- +5% Movement Speed
- +4% Area
- +8 Max HP

These values require real testing.

---

# 23. Growth Caps

## Recommended

Limit rewarded Provocations to approximately **4 to 6 Growth rewards** during a standard Campaign.

Individual stats should also have caps.

Example:

- Damage: 3 ranks
- Attack Speed: 3 ranks
- Movement Speed: 3 ranks
- Area: 2 ranks
- Max HP: 4 ranks
- Defense: 3 ranks

Exact caps require balancing.

## After Maximum Rewarded Blight

The player may still Provoke.

Additional Provocations can still:

- advance the run
- overlap waves
- create Surge
- accelerate milestone encounters

But they no longer grant additional Growth if the reward cap has been reached.

---

# 24. No Bonus XP for Provocation

## Required Rule

Do not add a direct Provocation XP multiplier.

Avoid:

- +25% XP for provoking
- bonus level-up currency based on time saved
- large raw economy bonuses

Provocation already provides:

- shorter runtime
- Growth
- earlier access to future milestones
- more intense combat

Adding significant XP bonuses risks making Provocation automatically optimal.

---

# 25. Earlier Provocation Should Not Give Larger Permanent Growth

## Required Rule

Do not use:

- 5 seconds early = +3% Damage
- 20 seconds early = +12% Damage

This creates a positive feedback loop:

strong build  
→ provoke earlier  
→ receive more power  
→ clear faster  
→ provoke even earlier

Earlier calls should primarily increase **Surge**.

Permanent Growth should remain broadly consistent.

---

# 26. Cankers

## Required Structural Rule

Cankers should remain driven by **territory state**, not purchased directly by the Threat Director.

The player should understand:

> This Canker exists because I lost control of that part of the garden.

## Director Interaction

Cankers may influence the Director.

Possible interactions:

- nearby spawn bias
- Canker reinforcement recipes
- reduced Threat Cost for certain Rot-aligned specialists near a Canker
- elite guardian opportunities
- stronger pressure on neglected regions

This allows the systems to communicate without merging them.

## Campaign Escalation

Possible progression:

- Act I: no Cankers or extremely limited formation
- Act II: first meaningful Canker risk
- Act III: multiple Cankers possible
- Act IV: Cankers interact strongly with elite or specialist pressure

Exact rules require prototyping.

---

# 27. Territory Trials

## Status

**Prototype recommendation, not required for first implementation.**

Trials could create objectives that raw DPS cannot automatically solve.

Potential Trials:

## Reclamation

Recover a target amount of Rot territory.

## Last Garden

Keep a marked region above a Green threshold.

## Split Front

Protect two distant regions simultaneously.

## Rot Tide

Survive temporary increased Rot pressure.

## The Hunt

Kill a dangerous elite before it escapes, transforms, or reaches an objective.

## Migration

Prevent a large enemy procession from crossing the garden.

## Canker Purge

Reclaim the region surrounding a dangerous Canker.

## Reward

Successful Trials could provide:

- Evolution reward
- relic choice
- Evolution reroll
- rare Growth
- special run reward

Failure should not necessarily end the run.

The player may simply lose the premium reward or suffer a temporary consequence.

---

# 28. No Hidden Build-Based Difficulty Scaling

## Required Rule

Do not scale enemy stats directly from:

- Grandma's current DPS
- theoretical build strength
- Path combination
- current damage multipliers
- Evolution count

Avoid:

> High DPS build = automatically more enemy HP.

This makes upgrades feel less meaningful and creates perverse optimization incentives.

## Also Avoid Explicit Counterpicking

Do not intentionally choose enemies because they counter the player's current Paths.

Example to avoid:

> Player owns Vine, therefore increase anti-Vine enemy weighting.

The Campaign should contain enemies capable of challenging Vine regardless of whether Vine is currently owned.

---

# 29. Accepted Difficulty Philosophy

Two systems should carry the majority of Campaign difficulty.

## Primary: Player-Controlled Provocation

The player voluntarily makes the Campaign:

- faster
- more dangerous
- permanently higher-Blight

This is the preferred adaptive difficulty mechanism because the player chooses it.

## Secondary: Threat Director

Campaign progression naturally increases:

- Director budget
- enemy quality
- specialist access
- elite access
- composition complexity

This creates better late-game threats without hidden rubber-banding.

---

# 30. Things Not To Add Yet

Do not immediately add every brainstormed pacing mechanic.

Hold the following systems for later evaluation:

- Flourish temporary super-state
- automatic enemy mutations triggered by Evolutions
- extensive adaptive difficulty
- fourth normal Path
- complex secondary currencies
- large Provocation economy bonuses
- direct DPS-based difficulty
- heavy stat rubber-banding

The proposed structure is already substantial enough to prototype and measure.

---

# 31. Major Campaign Milestones

## Recommended Starting Structure

### Wave 5

First major checkpoint.

Possible rewards:

- relic
- Path milestone
- major upgrade choice

### Wave 10

Midpoint encounter.

Strong candidate for:

- guaranteed Evolution reward if eligible
- major elite or miniboss
- important relic

### Wave 15

Completed-build checkpoint.

Strong candidate for:

- second Evolution opportunity
- high-quality relic
- major territory Trial

### Wave 20

Final encounter.

Uses current:

- Blight
- Canker state
- Campaign act rules
- completed build

Provocation can cause these milestones to arrive earlier in real time.

The wave number, not the absolute clock, determines progression.

---

# 32. Recommended Implementation Order

## Phase 1: Structural Campaign Prototype

Implement:

1. 20-minute Campaign target
2. 20-wave backbone
3. four Campaign acts
4. three-Path limit
5. wave pressure rhythm
6. basic Provocation
7. wave overlap after Provocation

Do not add Growth or Blight yet.

The first question is whether calling waves early is intrinsically fun.

## Phase 2: Threat Director

Implement:

1. Threat Costs
2. per-wave budget
3. Act-gated enemy pools
4. curated encounter recipes
5. stronger late-game shift from quantity to enemy quality

Benchmark performance carefully.

Do not allow the Director to create uncontrolled density spikes.

## Phase 3: Blight and Surge

Add:

1. permanent Blight
2. Director budget scaling
3. modest HP/damage scaling
4. specialist and elite weighting changes
5. temporary Surge based on how early the wave is called

Test whether repeated Provocation creates a meaningful net difficulty increase.

## Phase 4: Growth

Add:

1. 1-of-3 Growth rewards
2. small universal stat bonuses
3. per-stat caps
4. total rewarded Provocation cap

Verify that Growth is tempting but does not fully cancel Blight.

## Phase 5: Evolution Rework

Implement:

1. eligible Path-pair relationships
2. special Evolution reward pool
3. two-Evolution run target
4. Path reuse between Evolutions
5. Campaign milestone Evolution rewards

Retune eligibility around the 20-minute Campaign.

## Phase 6: Early Path Rebalance

Fix:

- Root early floor
- Bramble early relevance
- Spore early usefulness
- Bloom early usefulness
- any other dead rank-1 lines

Rerun rank-1 pair benchmark.

## Phase 7: Known Outlier Tuning

Implement Thornwhip mounted-head fix.

Then retest:

- Thistle
- Vine
- Pruning
- major Evolution interactions

Only after that should Burr or Vine Elongation receive global nerfs.

## Phase 8: Canker Integration

Make Cankers interact with:

- Campaign acts
- Director recipes
- spawn geography
- Blight
- late-game territorial pressure

Keep Canker creation territory-driven.

## Phase 9: Optional Trials

Prototype only after the base system is fun.

The goal is to determine whether objective-based pressure improves build diversity enough to justify another layer.

---

# 33. Testing Requirements

The new structure should be tested at several levels.

## 33.1 Rank-1 Pair Sweep

Purpose:

Verify that no Path combination effectively has no build during the opening minutes.

Track:

- damage
- kills
- damage taken
- Green held
- enemy population
- territory recovery
- control effects where measurable

Do not use raw DPS alone as the pass/fail criterion.

## 33.2 Rank-3 Pair Sweep

Purpose:

Measure mature base-Path relationships before Evolutions.

Compare against the current spread.

Watch for:

- new multiplicative outliers
- support Paths becoming mandatory
- excessive AoE scaling
- territory Paths still failing to produce meaningful board control

## 33.3 Full Campaign Archetype Runs

Do not test only one strong pair.

Create representative three-Path builds.

At minimum:

### Damage-heavy

Example role mix:

- Vine
- Thistle
- Pruning

### Territory-heavy

Example role mix:

- Spore
- Bloom
- Root

### Defensive/control-heavy

Example role mix:

- Bramble
- Root
- another low-direct-damage Path

### Mixed

One direct damage Path plus territory and support.

### Evolution-heavy synergy case

A build expected to create strong pair interactions.

Track every minute:

- level
- upgrade count
- Path ranks
- Evolution state
- enemy population
- damage
- damage taken
- Green %
- Canker count
- Director budget used
- enemy composition
- Blight
- Provocation count

## 33.4 Provocation Tests

Test at least:

### Never Provoke

Expected runtime near baseline maximum.

### Moderate Provocation

Player Provokes occasionally after regaining control.

### Aggressive Provocation

Player Provokes at earliest reasonable opportunities.

### Overconfident Provocation

Player intentionally creates dangerous wave overlap.

Questions:

- Does the mechanic create memorable risk?
- Is Provocation ever a bad decision?
- Is Growth too rewarding?
- Does Blight remain meaningful?
- Can aggressive players finish faster without trivializing the finale?
- Does Surge create immediate danger without causing unavoidable deaths?

---

# 34. Balance Success Criteria

The following are better targets than forcing all builds toward equal DPS.

## Opening

- every Path has visible rank-1 value
- no coherent build feels absent for the first several minutes
- early draft order can influence a run but should not automatically decide it

## Midgame

- first Evolution appears around the intended timing
- player power accelerates noticeably
- different Path relationships create distinct play patterns
- enemy composition begins to matter

## Late Game

- mature builds still feel powerful
- final 5 minutes remain dangerous
- density is not the only source of threat
- high-DPS builds face meaningful non-DPS problems
- territory builds have situations where their strengths matter
- Provocation meaningfully changes the run
- Blight V is materially harder than Blight 0

## Finale

The final encounter should remain threatening at high Blight without nullifying the player's build.

---

# 35. Balance Philosophy Going Forward

When a build is too strong, first ask:

> What multiplicative interaction is producing this result?

Do not immediately reduce global damage values.

When a build is too weak, first ask:

> Does this build have a meaningful way to solve the problems the Campaign is asking?

Do not immediately add generic damage.

When late Campaign is too easy, first ask:

> Is the game presenting harder problems, or merely more targets?

Do not immediately increase density.

When a strong player becomes bored, first ask:

> Can Provocation let them voluntarily accelerate the run?

Do not secretly buff enemies based on their DPS.

---

# 36. Current Decision Status

## Effectively Agreed

- 20-minute maximum Campaign target
- 3 normal Paths
- 4 upgrades per Path
- 3 ranks per upgrade
- approximately 2 Evolutions per run
- Evolution eligibility based on owned Path relationships
- Evolutions separated from ordinary level-up rewards
- Paths may participate in more than one Evolution
- late difficulty should emphasize enemy quality over density
- Threat Director
- curated encounter recipes
- run-wide Provocation
- current enemies remain when the next wave is Provoked
- permanent Blight from rewarded Provocation
- temporary Surge from especially early Provocation
- small universal Growth choices
- no large bonus XP for Provocation
- earlier Provocation should increase danger more than permanent reward
- Cankers remain territory-driven
- no hidden DPS-based enemy scaling
- no explicit build counterpicking
- Thornwhip interaction should be fixed before broad Thistle nerfs
- Pruning should be watched before changing

## Recommended but Needs Prototype Validation

- exactly 20 waves
- 60-second natural wave duration
- Provocation unlock around 40 seconds
- 4 to 6 Growth rewards
- Blight cap around V for rewarded scaling
- specific Blight percentages
- exact Threat Costs
- exact Growth percentages
- Path acquisition at start / ~2 min / ~4 to 5 min
- Evolution reward timing at specific wave milestones
- specific encounter recipes
- Trials

## Explicitly Deferred

- universal Flourish mechanic
- Evolution-triggered enemy mutation system
- normal fourth Path
- strong hidden adaptive difficulty
- DPS-based HP scaling
- extensive new currencies
- major bonus rewards proportional to how early the player Provokes

---

# 37. Final Intended Campaign Experience

A normal Campaign should begin with Grandma establishing a small but functional build.

Within the first few minutes, all three Paths become visible parts of the run.

The enemy ecosystem begins simply, then starts introducing specialist combinations.

Around the first third of the run, the player's Path relationships begin producing Evolution opportunities.

The player becomes powerful quickly.

If they feel ahead of the Campaign, they can Provoke the next wave early.

Provocation removes recovery time, overlaps enemy pressure, creates Surge, permanently raises Blight, and eventually earns small universal Growth.

Repeated Provocation creates a faster but more dangerous Campaign.

Meanwhile, lost territory can develop into Cankers, causing persistent geographic consequences that raw damage alone cannot always erase instantly.

By roughly minute 15, the player's build is largely complete.

The final five minutes are not about waiting for more upgrade ranks.

They are about surviving the strongest enemy combinations, protecting the garden, managing Cankers, deciding whether to continue Provoking, and proving that the ecosystem the player built can survive the Blight they chose to unleash.

The intended fantasy is:

> **Grandma grows an increasingly absurd botanical ecosystem while deliberately daring the infestation to escalate faster. The garden becomes powerful enough to feel broken, and the world becomes dangerous enough to make that power necessary.**
