# Territory Roguelike — Current Non-Relic Implementation Changes

> This file tracks current gameplay and systems changes that still need to be implemented.
>
> Relics are intentionally excluded and remain in `territory_roguelike_comprehensive_relics.md`.
>
> Current balance target: **12-minute development build**. The eventual full game can expand toward approximately **25–30 minute runs**.

---

# 1. Current Plant Path Roster

Plant has five normal Paths plus the Clover gambling machine.

1. **Spore** — enemy death becomes delayed territorial growth through Seeds.
2. **Bloom** — existing Green violently expands through splatter and pressure.
3. **Bramble** — Green controls enemies through Entanglement, rooting, and repulsion.
4. **Root** — Mature Green becomes stronger and amplifies other Plant systems.
5. **Pruning** — Green is harvested into an offensive ring and discharged outward.

Clover is not a Path. It is a machine permanently housed in the side panel that
wagers Territory, and it is specified in `docs/gambling_master_implementation_guide.md`
rather than here.

---

# 2. Secret Seventh Path — Clover

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

# 3. Clover Core Mechanic

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

# 4. Clover Busts and Rigging

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

# 5. Incremental System Overhaul

The Biomass system should become a defining mechanic rather than a row of repeatable percentage upgrades.

Current problem:

> Purchases are impactful, but the player can mostly click whichever number seems useful without building a deliberate economy.

Replace the primarily manual shop with an automated **Ecosystem Metabolism** system.

Biomass becomes:

- an economic resource,
- a reserve,
- and fuel for the territory physics.

---

# 6. Ecosystem Metabolism

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

# 7. Metabolism Allocation

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

# 8. Automatic Leveling

Allocated Biomass should automatically fill Metabolism level bars.

Example:

> Meristem Lv. 4  
> ████████░░ 82 / 100

When filled:

# MERISTEM LV. 5

Then the next level costs significantly more.

Do not require repeated manual upgrade clicks.

---

# 9. Exponential Costs

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

# 10. Metabolism Breakthroughs

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

# 11. Biomass HUD

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

# 12. Overgrow

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

# 13. Overgrow and Metabolism

Overgrow should inherit the player's Metabolism identity.

## High Photosynthesis
More of the effect becomes Mass.

## High Meristem
More becomes outward Pressure.

## High Cambium
More becomes repair, cohesion, and stabilization.

Two players pressing Overgrow should be able to get visibly different physical results.

---

# 14. Incremental Dopamine

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

# 15. Territory Physics Becomes Core Gameplay

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

# 16. Physical Identity of Plant

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

# 17. Paths as Physics Manipulators

## Spore
Adds localized new Mass through biological growth.

## Bloom
Violently ejects and pushes Mass.

## Bramble
Makes Green resist enemy movement and physically restrain invaders.

## Root
Changes material properties of Mature Green.

## Pruning
Removes territorial Mass and converts it into an offensive physical object.

This should make the Paths feel like different ways of manipulating one shared ecosystem rather than unrelated abilities.

---

# 18. Bloom Splatter Rework

Bloom should visually and physically resemble a violent **paint splatter** rather than a clean expanding circle.

Core sequence:

> Flower charges → erupts → large central splat → globs and streaks spray outward → splats inject real Green Mass → simulation resolves connection, pressure, and survival.

Bloom is the main Plant mechanic associated with splatter.

Spore should remain more like organic point growth.

---

# 19. Bloom Is Not a Fixed Splat Texture

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

# 20. Bloom Mass vs Force

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

# 21. Bloom Droplet Simulation

Do not make every visible droplet a full gameplay object.

Possible prototype:

- 40–80 visible droplets,
- 8–15 meaningful field splats.

Use particles/shaders for microdroplets.

Use the field simulation for the important globs.

This keeps the effect spectacular without requiring hundreds of physics bodies.

---

# 22. Bloom Satellite Green

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

# 23. Bloom vs Hostile Territory

Green splatter should not automatically recolor Hostile material.

Instead:

- Green Mass collides with Hostile material,
- weak splats flatten or disappear,
- strong impacts dent or displace the hostile frontier,
- large globs can establish Green islands,
- competing material resolves through the shared field simulation.

The battlefield should look like two living materials pushing into each other.

---

# 24. Bloom and Arena Geometry

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

# 25. Super Bloom Spectacle

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

# 26. Bramble Physical Presentation

Entanglement should be visually tied to the Green field.

Possible presentation:

- vines tether enemies to Green,
- higher Entanglement creates additional/thicker tethers,
- moving enemies visibly stretch them,
- fully Entangled enemies become strongly restrained,
- broken restraints snap visibly.

The underlying movement logic can remain deterministic rather than using expensive rope simulation.

---

# 27. Root Physical Presentation

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

# 28. Pruning as Mass Conversion

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

# 29. Simulation Architecture Direction

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

# 30. Prototype Resolution

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

# 31. Gameplay Physics Over Scientific Physics

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

# 32. Final System Relationship

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

# 33. Desired Run Fantasy

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

# 34. Recommended Implementation Order

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

## Phase 6 — Clover
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

# 35. Current Design Standard

Every major new mechanic should contribute to at least two of the following:

- an interesting gameplay decision,
- visible change to the territory simulation,
- emergent interaction,
- incremental escalation,
- immediate audiovisual satisfaction.

The game should increasingly feel like:

> **a roguelike build system controlling an incremental physics experiment that gets completely out of hand.**
