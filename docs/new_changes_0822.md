# Territory Roguelike — Current Non-Relic Implementation Changes

> This file tracks current gameplay and systems changes that still need to be implemented.
>
> Relics are intentionally excluded and remain in `territory_roguelike_comprehensive_relics.md`.
>
> Current balance target: **12-minute development build**. The eventual full game can expand toward approximately **25–30 minute runs**.

---

# 1. Current Plant Path Roster

Plant has six normal Paths plus one secret seventh gambling Path.

1. **Spore** — enemy death becomes delayed territorial growth through Seeds.
2. **Bloom** — existing Green violently expands through splatter and pressure.
3. **Bramble** — Green controls enemies through Entanglement, rooting, and repulsion.
4. **Root** — Mature Green becomes stronger and amplifies other Plant systems.
5. **Carnivory** — Green grows autonomous predators where enemies invade it.
6. **Pruning** — Green is harvested into an offensive ring and discharged outward.
7. **Clover** — secret gambling Path available only as the post-Evolution third Path.

Kudzu is removed from the active Plant roster.

---

# 2. Carnivory Replaces Kudzu

## Identity

> **Enemies invading Green feed the growth of predatory plants.**

Carnivory should add new functionality to owned territory instead of acting as another territory-expansion Path.

## Local Prey Pressure

Enemies spending time on Green generate **local Prey Pressure**.

- Use local enemy-seconds or a similar local metric.
- Do not use whole-arena territory percentages.
- Dense late-game invasions should naturally create Prey Pressure faster.
- High-pressure areas become the places where predators grow.

Conceptual trigger:

> Enemies collectively spend roughly 10 enemy-seconds inside a local Green region.

Exact values are tunable.

---

# 3. Maw System

When local Prey Pressure reaches its threshold:

1. A **Maw Bud** emerges.
2. The Bud visibly grows.
3. It becomes an active **Maw**.

## Maw Behavior

1. Detect nearby prey.
2. Open with a visible telegraph.
3. Snap shut.
4. Damage several enemies inside its Jawspan.
5. Enter **Digestion**.
6. Bite again after Digestion completes.

## Territory Dependency

- Maws must remain planted on Green.
- Losing the underlying Green uproots or destroys the Maw.
- Maw growth should visibly draw material from the surrounding ecosystem.

## Capacity

Maw count must remain capped.

Prototype direction:

- low investment: about 2 Maws,
- high investment: about 5–6 Maws.

At capacity, either prevent a new Maw or replace the oldest/least useful one.

---

# 4. Carnivory Damage Model

Maws should cover hordes without multiplying full damage by every enemy caught.

Possible model:

> Each Bite has a total damage budget that is distributed among captured enemies.

Example:

- 1 enemy: ~500 total damage.
- 5 enemies: ~100 each.

Partial splitting can be tested if perfect division feels too weak.

The goal is:

> **More prey increases coverage, not unlimited damage multiplication.**

---

# 5. Carnivory Upgrade Lines

Prototype four normal upgrade lines:

## Bite Force
Increases Bite damage.

## Jawspan
Increases Bite area and maximum prey caught.

## Digestion
Reduces the time between Bites.

## Budding
Increases Prey Pressure conversion and can eventually increase Maw Capacity.

Possible specialization:

- **Boss:** Bite Force + Digestion.
- **Horde:** Jawspan + Budding.

---

# 6. Carnivory Evolutions

The five old Kudzu pairings should be replaced by Carnivory pairings.

## Spore + Carnivory — Snap Pods

> Seed → predator → kill → Seed.

Possible behavior:

- Seeds germinating beneath enemy groups temporarily form snapping mouths.
- Permanent Maws finishing Digestion can spit out Seeds.
- Late game becomes a field of snaptraps erupting under mobs.

## Bloom + Carnivory — Feeding Frenzy

> Bloom wakes the predator network.

Possible behavior:

- Maws inside a Bloom event snap simultaneously.
- Bloom expansion scatters temporary Maw Buds into newly claimed Green.

Presentation:

> Bloom charges → mouths open → synchronized Bite → splatter surge → new mouths emerge.

## Bramble + Carnivory — Strangletrap

> Bramble captures prey and Carnivory eats it.

Possible behavior:

- heavily Entangled enemies become Prey,
- nearby Maws extend long vines,
- vines drag trapped enemies toward the jaws,
- Bite resolves after the pull.

## Root + Carnivory — Ancient Hunger

> Old Green grows enormous predators.

Possible behavior:

- Maws rooted in Mature Green can become Elder Maws,
- Elder Maws are slower but much larger,
- digestion can feed Root systems or Elder Maw growth.

## Pruning + Carnivory — Uprooting

> Pruning tears predators out of the ecosystem and weaponizes them.

Possible behavior:

- harvested Maws become orbiting snapping heads in the Pruning ring,
- they Bite enemies within the held ring,
- released heads travel outward with the ring,
- they Bite along the route,
- they may replant where the ring ends.

This must use the current active Pruning ring, not the obsolete timed Pruning Cycle.

---

# 7. Secret Seventh Path — Clover

Clover is the secret Plant gambling Path.

## Selection Rules

- Cannot be Primary.
- Cannot be Secondary.
- Does not create normal Evolutions.
- Can only appear as the third Path after the initial pair has evolved.
- Requires a special unlock condition before it can appear.

Possible first-time presentation:

# CLOVER
> Feeling lucky?

Selecting it causes the slot-machine UI to appear.

---

# 8. Clover Core Mechanic

Normal gameplay earns **Chips**.

When enough Chips are collected:

> the slot machine spins automatically.

The Chip trigger should remain simple. A fixed kill counter is a good prototype.

Potential symbols:

- Seed
- Flower
- Bramble
- Root
- Maw
- Cutting
- Clover / Wild
- Bust

## Match Structure

### One symbol
Minor effect.

### Two matching
Stronger effect.

### Three matching
Jackpot.

### Triple Clover
Mega Jackpot.

Mega Jackpot can trigger one major event from all six normal Plant Paths.

---

# 9. Clover Busts and Rigging

Busts should create meaningful downside without randomly ending a run.

Possible penalties:

- lose Chips,
- temporary reduction in Green pressure,
- short enemy speed increase,
- spawn a special elite.

Avoid huge random territory deletion.

Clover upgrades should gradually let the player cheat the machine.

Possible upgrade directions:

- **Loaded Reels** — better symbol weighting.
- **Hold** — matching symbols can remain locked.
- **Double Down** — bigger Jackpots and bigger Busts.
- **Free Spin** — chance for another spin, with a hard chain cap.

The presentation should become increasingly suspicious and casino-like as Clover improves.

---

# 10. Incremental System Overhaul

The Biomass system should become a defining mechanic rather than a row of repeatable percentage upgrades.

Current problem:

> Purchases are impactful, but the player can mostly click whichever number seems useful without building a deliberate economy.

Replace the primarily manual shop with an automated **Ecosystem Metabolism** system.

Biomass becomes:

- an economic resource,
- a reserve,
- and fuel for the territory physics.

---

# 11. Ecosystem Metabolism

Start with three universal Plant metabolism systems.

## Photosynthesis — Mass

Controls how much raw Plant material the ecosystem produces.

Higher Photosynthesis means:

- more territorial Mass,
- more long-term Green,
- stronger economic potential.

Physical fantasy:

> The ecosystem visibly swells because it is producing more material.

## Meristem — Pressure

Controls how aggressively Green pushes and moves.

Higher Meristem means:

- stronger outward frontier pressure,
- more aggressive deformation,
- better exploitation of gaps and weak fronts.

Physical fantasy:

> Green becomes increasingly eager to move.

## Cambium — Cohesion

Controls structural integrity.

Higher Cambium means:

- more cohesion,
- greater resistance to tearing,
- stronger recovery,
- more elastic or rigid behavior depending on Breakthroughs.

Physical fantasy:

> Weak Green tears. Strong Green bends, holds together, and rebounds.

---

# 12. Metabolism Allocation

Use a small number of discrete allocation points instead of precise sliders.

Prototype:

> **8 total points**

Example:

### Photosynthesis
● ● ● ● ○ ○ ○ ○

### Meristem
● ● ● ○ ○ ○ ○ ○

### Cambium
● ○ ○ ○ ○ ○ ○ ○

The player may reallocate points during the run.

Important rule:

> Allocation changes future investment rate. Already earned levels are not refunded.

---

# 13. Automatic Leveling

Allocated Biomass should automatically fill Metabolism level bars.

Example:

> Meristem Lv. 4  
> ████████░░ 82 / 100

When filled:

# MERISTEM LV. 5

Then the next level costs significantly more.

Do not require repeated manual upgrade clicks.

---

# 14. Exponential Costs

Metabolism costs should increase exponentially.

Conceptual example:

- Lv. 1: 10
- Lv. 2: 18
- Lv. 3: 32
- Lv. 4: 58
- Lv. 5: 104
- Lv. 6: 187
- Lv. 7: 337

Exact numbers are tunable.

The goal is to create a real decision between:

- cheaply developing a neglected system,
- or paying heavily to specialize an already advanced one.

---

# 15. Metabolism Breakthroughs

Every major threshold should offer a behavioral choice.

Prototype:

> every 5 levels.

## Photosynthesis Lv. 5

### Rapid Cycling
Mass is created continuously in many small pulses.

### Storage Organs
Mass accumulates and releases in larger periodic pulses, making Green visibly breathe outward.

## Meristem Lv. 5

### Apical Dominance
Pressure concentrates into protrusions and tendrils.

### Lateral Growth
Pressure spreads broadly across the frontier.

## Cambium Lv. 5

### Flexible Tissue
Green deforms heavily before breaking and rebounds afterward.

### Woody Tissue
Green resists deformation but fractures more suddenly when overloaded.

Breakthroughs should visibly alter the simulation.

---

# 16. Biomass HUD

Show Biomass as a running economy.

Suggested HUD:

### Reserve
`428`

### Production
`+24.6 / sec`

### Consumption
`-17.2 / sec`

### Net
`+7.4 / sec`

Stored Biomass becomes an actual buffer.

The player can intentionally run an unsustainable configuration for a short time by burning reserves.

---

# 17. Overgrow

Add one major instant-dopamine Biomass action:

# OVERGROW

Prototype:

> Spend 50% of current Biomass Reserve.

Do **not** directly add a predetermined percentage of territory.

Instead, convert the spent Biomass into a temporary injection of:

- Plant Mass,
- territorial Pressure.

Then let the simulation decide what happens.

## Possible Outcomes

### Open space
Broad expansion.

### Narrow passage
Pressure funnels through the gap into a territorial jet.

### Grazer trench
Mass rushes into the damaged channel.

### Hostile front
Green compresses against hostile material and seeks weak points.

### Damaged ecosystem
Material fills holes and reconnects territory.

The same button should produce different outcomes because the battlefield state is different.

---

# 18. Overgrow and Metabolism

Overgrow should inherit the player's Metabolism identity.

## High Photosynthesis
More of the effect becomes Mass.

## High Meristem
More becomes outward Pressure.

## High Cambium
More becomes repair, cohesion, and stabilization.

Two players pressing Overgrow should be able to get visibly different physical results.

---

# 19. Incremental Dopamine

Add simple celebration around economic growth.

Prototype production milestones:

- 10 Biomass/sec
- 25/sec
- 50/sec
- 100/sec
- 250/sec
- 500/sec

On first reaching a milestone:

- large HUD announcement,
- satisfying sound,
- small free ecosystem pulse,
- stronger visual intensity.

After the core Metabolism prototype works, consider:

## Critical Harvest
Rare production ticks gain a large multiplier.

## Biomass Overflow
Once storage is full, excess Biomass converts into small automatic physical growth pulses.

These are secondary additions, not requirements for the first prototype.

---

# 20. Territory Physics Becomes Core Gameplay

Territory should behave like a living material rather than a static painted texture.

The simulation should expose gameplay properties such as:

- Ownership
- Mass
- Pressure
- Resistance
- Maturity
- Cohesion
- optionally directional Velocity / Flow

Paths and incremental upgrades manipulate these properties.

The physics simulation determines the resulting shape and movement of territory.

---

# 21. Physical Identity of Plant

Plant should behave like a **living viscoelastic material**.

It can:

- grow,
- bulge,
- stretch,
- flow through gaps,
- split,
- reconnect,
- repair,
- thicken with age,
- deform under enemy pressure.

## Fresh Green
Soft, fragile, easy to deform.

## Established Green
Reference behavior.

## Mature Green
Denser, more cohesive, more resistant, better at transmitting force.

Root further exaggerates these differences.

---

# 22. Paths as Physics Manipulators

## Spore
Adds localized new Mass through biological growth.

## Bloom
Violently ejects and pushes Mass.

## Bramble
Makes Green resist enemy movement and physically restrain invaders.

## Root
Changes material properties of Mature Green.

## Carnivory
Turns local enemy pressure into organisms embedded in Green.

## Pruning
Removes territorial Mass and converts it into an offensive physical object.

This should make the Paths feel like different ways of manipulating one shared ecosystem rather than unrelated abilities.

---

# 23. Bloom Splatter Rework

Bloom should visually and physically resemble a violent **paint splatter** rather than a clean expanding circle.

Core sequence:

> Flower charges → erupts → large central splat → globs and streaks spray outward → splats inject real Green Mass → simulation resolves connection, pressure, and survival.

Bloom is the main Plant mechanic associated with splatter.

Spore should remain more like organic point growth.

---

# 24. Bloom Is Not a Fixed Splat Texture

Do not simply stamp one irregular decal.

A Bloom should create multiple contributions:

- one large central splat,
- several medium gameplay globs,
- smaller satellite splashes,
- directional streaks,
- cosmetic microdroplets.

Each meaningful splat injects Mass and/or Pressure into the field.

The final shape emerges from the simulation.

---

# 25. Bloom Mass vs Force

Keep Bloom Mass and Bloom Force physically distinct.

## Bloom Mass

Controls:

- amount of material thrown,
- central splat size,
- major glob size,
- resulting territory thickness,
- survival of satellite patches.

### High Mass / Low Force
Large thick splash near the source.

## Bloom Force

Controls:

- splatter distance,
- elongation,
- velocity,
- knockback,
- hostile displacement,
- pressure through channels.

### Low Mass / High Force
Thin, far-reaching spray.

## High Mass / High Force
Huge arena-painting eruption.

Players should be able to recognize their Bloom build from its physical appearance.

---

# 26. Bloom Droplet Simulation

Do not make every visible droplet a full gameplay object.

Possible prototype:

- 40–80 visible droplets,
- 8–15 meaningful field splats.

Use particles/shaders for microdroplets.

Use the field simulation for the important globs.

This keeps the effect spectacular without requiring hundreds of physics bodies.

---

# 27. Bloom Satellite Green

Large splats can create temporary disconnected Green regions.

These patches:

- become real territory if enough Mass survives,
- can be destroyed while isolated,
- can naturally connect to the main ecosystem,
- can mature,
- can accumulate Prey Pressure,
- can eventually grow Maws.

Example emergent chain:

> Bloom splat → isolated Green patch → enemies invade → Prey Pressure → Maw Bud → Maw.

---

# 28. Bloom vs Hostile Territory

Green splatter should not automatically recolor Hostile material.

Instead:

- Green Mass collides with Hostile material,
- weak splats flatten or disappear,
- strong impacts dent or displace the hostile frontier,
- large globs can establish Green islands,
- competing material resolves through the shared field simulation.

The battlefield should look like two living materials pushing into each other.

---

# 29. Bloom and Arena Geometry

Bloom should react differently to geometry.

## Open Arena
Broad radial splatter.

## Wall
Impact spreads sideways.

## Corridor
Pressure funnels forward into long streaks or jets.

## Pillar
Splatter divides and wraps around both sides.

## Porous Arena
Globs settle into separated pockets and irregular islands.

This makes automatic Bloom positioning meaningful.

---

# 30. Super Bloom Spectacle

Super Bloom should become one of the main visual benchmarks for the entire game.

Possible chain:

> Seed germinates  
> → SPLAT  
> → nearby Seed advances  
> → SPLAT  
> → more Seeds activate  
> → SPLAT SPLAT SPLAT

The arena should rapidly become covered in overlapping irregular Green impacts.

Those splats remain real territory and continue to:

- connect,
- deform,
- mature,
- get consumed,
- support Maws,
- interact with future Blooms.

---

# 31. Bramble Physical Presentation

Entanglement should be visually tied to the Green field.

Possible presentation:

- vines tether enemies to Green,
- higher Entanglement creates additional/thicker tethers,
- moving enemies visibly stretch them,
- fully Entangled enemies become strongly restrained,
- broken restraints snap visibly.

The underlying movement logic can remain deterministic rather than using expensive rope simulation.

---

# 32. Root Physical Presentation

Root should increasingly become:

> **the Path that changes the material properties of old Green.**

Rooted Mature Green can have:

- higher cohesion,
- lower fragmentation,
- stronger recovery,
- better transmission of pressure,
- stronger amplification of other Plant mechanics.

A Bloom interacting with heavily Rooted territory should physically behave differently from one interacting with Fresh Green.

---

# 33. Pruning as Mass Conversion

Pruning should visibly remove Mass from Green.

Harvested material contributes to:

- orbiting spike density,
- ring visuals,
- Charge,
- discharge.

The ring should feel constructed from the ecosystem itself.

The player is performing:

> territory → harvested material → weapon.

---

# 34. Simulation Architecture Direction

Avoid building territory from hundreds or thousands of Unity Rigidbody objects.

Preferred direction:

> **2D gameplay field + exaggerated visual layer**

Potential implementation tools:

- RenderTexture,
- ComputeShader,
- GPU texture/buffer simulation,
- another low-resolution field representation.

Possible field channels:

- Ownership
- Mass
- Pressure
- Resistance
- Maturity
- Cohesion
- optional Velocity / directional flow

Shaders and particles can upscale and exaggerate the gameplay field.

---

# 35. Prototype Resolution

Start with a moderate field resolution.

Possible candidates:

- 128 × 128
- 256 × 256

Choose based on:

- visual quality,
- enemy count,
- update cost,
- mobile/target hardware requirements.

The goal is not scientific fluid accuracy.

The goal is responsive, readable, emergent territory behavior.

---

# 36. Gameplay Physics Over Scientific Physics

Use simplified, deterministic rules for:

- mass transfer,
- pressure,
- resistance,
- erosion,
- recovery,
- displacement.

Use visuals to exaggerate:

- splashing,
- rippling,
- stretching,
- deformation,
- rebounding,
- fracture,
- flowing around obstacles.

Target:

> **a convincing physics toy, not a scientific fluid simulator.**

---

# 37. Final System Relationship

The intended architecture is:

## Paths
Change the rules.

## Relics
Create unusual interactions and triggers.

## Incremental Metabolism
Changes the physical parameters.

## Physics Simulation
Determines what actually happens on the battlefield.

These systems should feed into one another rather than feeling like separate progression layers.

---

# 38. Desired Run Fantasy

Early run:

- small,
- thin,
- weak,
- slow,
- fragile Green patch.

Late run:

- enormous Mass production,
- high territorial Pressure,
- strong Cohesion,
- splatter covering the arena,
- Green squeezing through channels,
- damaged territory visibly resealing,
- giant Root networks,
- Maws growing from invasion zones,
- Pruning ripping chunks of the ecosystem into weapons.

The intended feeling is:

> **"I didn't just increase a stat. I turned this material into a monster."**

---

# 39. Recommended Implementation Order

## Phase 1 — Shared Territory Field
Prototype:
- Ownership,
- Mass,
- Pressure,
- Resistance/Cohesion,
- Maturity.

## Phase 2 — Bloom Splatter
Implement:
- central splat,
- gameplay globs,
- cosmetic droplets,
- Mass vs Force,
- geometry interaction.

## Phase 3 — Metabolism
Implement:
- Photosynthesis,
- Meristem,
- Cambium,
- 8 allocation points,
- automatic leveling,
- exponential costs.

## Phase 4 — Breakthroughs
Add one Lv. 5 branch choice for each Metabolism system.

## Phase 5 — Overgrow
Convert Biomass Reserve into temporary Mass + Pressure.

## Phase 6 — Carnivory
Implement:
- local Prey Pressure,
- Maw Bud,
- Maw,
- Bite,
- Digestion,
- Maw Capacity.

## Phase 7 — Carnivory Evolutions
Replace the five obsolete Kudzu pairings.

## Phase 8 — Clover
Implement:
- Chips,
- slot-machine UI,
- symbol effects,
- Jackpots,
- Busts,
- gambling upgrade lines.

## Phase 9 — Cross-System Physics Polish
Implement:
- Bramble tethers,
- Root material behavior,
- Pruning mass conversion,
- Super Bloom splatter spectacle,
- production milestone feedback.

---

# 40. Current Design Standard

Every major new mechanic should contribute to at least two of the following:

- an interesting gameplay decision,
- visible change to the territory simulation,
- emergent interaction,
- incremental escalation,
- immediate audiovisual satisfaction.

The game should increasingly feel like:

> **a roguelike build system controlling an incremental physics experiment that gets completely out of hand.**
