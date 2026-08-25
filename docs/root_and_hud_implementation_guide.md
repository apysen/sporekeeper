# Root Metabolism & HUD Redesign
## Research-Backed Implementation Guide

**Project:** Territory roguelike / Elemental  
**Status:** Prototype specification  
**Purpose:** Replace the old Root Path and Mass / Pressure / Cohesion purchase system with an interactive, physical incremental layer, then redesign the HUD around that system without cluttering the battlefield.

> **North star:** The player should not feel like they are leveling a spreadsheet. They should feel like they are growing, operating, and occasionally endangering a living organism.

---

# 1. Executive Summary

The proposed redesign removes **Root as a selectable Path** and promotes its strongest ideas into a universal system beneath every build.

Green territory grows roots. Rooted territory becomes productive infrastructure. That infrastructure generates and stores Biomass. The player then makes a continual choice between:

- **Consume:** spend Biomass now to influence the battlefield.
- **Compound:** spend Biomass on permanent root development that increases what the organism can do later.

The root network handles routine logistics automatically, while the player remains responsible for the interesting decisions: where to move, when to discharge reserves, what permanent physiology to develop, and whether immediate survival is worth delaying long-term growth.

The intended loop is:

**Claim Green → Hold Green → Root Green → Generate Biomass → Spend or Save → Develop Roots → Claim More Green**

The HUD follows the same philosophy. Important information should be:

- visible when the player needs it;
- close to the player's locus of attention when it is urgent;
- represented through the battlefield itself whenever possible;
- hidden, collapsed, or moved into an inspect layer when it is strategic rather than urgent.

The resulting experience should be visually clean during normal play, but highly legible under pressure.

---

# 2. Project Basis

This guide incorporates the current project direction established in:

- `rework_summary_0822_0823.md`
- `physics_opportunities.md`

Important existing decisions carried forward:

- The entire arena remains visible on one screen.
- Territory % is the primary fail condition.
- The player also has separate HP.
- The player moves manually while attacks are largely automatic.
- Bloom is now physical thrown material, with splats, drag, mass, force, impact flattening, and wall interactions.
- Bloom paint begins unrooted and fragile.
- Spore produces Seeds that can establish satellite colonies.
- Pruning consumes territory as part of its offensive identity.
- Bramble uses territory as defensive structure.
- Carnivory has been removed as a Path and its best spectacle was preserved as the Man-Eater Legendary relic.
- The old Metabolism system currently uses Mass, Pressure, and Cohesion, but its pricing creates a strong incentive to keep all three around the same level.
- The UI direction is already contextual: hidden systems stay hidden until relevant, detailed decisions live in drawers, and major events appear briefly rather than permanently occupying the screen.
- Root was already drifting toward maturity, connectivity, transport, support flow, and infrastructure, which makes it a natural candidate for promotion into a universal system.

---

# 3. Research Synthesis: What Players Tend to Want From Incremental Systems

The redesign should not copy one existing incremental game. The useful pattern across player discussions is that people consistently praise a small set of feelings and consistently complain about a small set of failure modes.

## 3.1 What players commonly praise

### Unfolding

Players repeatedly praise incremental games that begin simple and reveal additional systems gradually.

The important part is not simply unlocking more buttons. A good unfolding system changes the player's understanding of the original loop.

For this project:

**Early:** Green creates roots.  
**Later:** roots produce Biomass.  
**Later:** roots store it.  
**Later:** disconnected colonies become independent economies.  
**Later:** the player actively routes and discharges the network.  
**Later:** the network develops specialized physiology.

The player should repeatedly discover that the territory system has more depth than they first assumed.

### Visible escalation

Players respond strongly when increasing power changes what the game visibly looks like.

For this project, late-run progression should be readable with the UI hidden:

- more root coverage;
- thicker major roots;
- visible vascular pulses;
- storage structures;
- dramatic reconnection events;
- stronger metabolic discharges;
- more active fronts;
- larger differences between fresh and deeply established territory.

A minute-1 screenshot and a minute-12 screenshot should look like different stages of an organism's life.

### Active play that changes decisions, not merely speed

An important distinction in active incremental discussions is between:

> clicking or playing to make a number rise faster

and:

> active play changing what the system actually does.

This system should favor the second.

The player's movement can bias metabolic support. The player's decision to spend Biomass can rescue a front, trigger an expansion, or delay permanent growth. The active layer should change the organism's behavior rather than simply multiplying production.

### Automation of obsolete work

Players often enjoy automating repetitive actions once they stop being interesting.

The rule for this project should be:

> **Automate logistics. Preserve decisions.**

The root network may automatically:

- establish beneath sustained Green;
- transport Biomass;
- recognize disconnected components;
- fill available storage;
- redistribute routine support.

The player should not:

- click individual roots;
- manually transfer Biomass cell by cell;
- refill organs on a timer;
- repeatedly activate an obvious action simply because its cooldown ended.

### Meaningful compounding

A satisfying incremental system repeatedly asks whether current resources should create current power or future power.

This is the central decision of Root Metabolism:

> **Do I burn my reserve to survive this wave, or keep it so my organism permanently develops?**

That conflict should remain relevant throughout the run.

---

## 3.2 What players commonly dislike

### Flat percentage ladders

A sequence like:

- +10% production
- +15% production
- +20% production

can create growth, but it rarely creates memorable build identity by itself.

The old Mass / Pressure / Cohesion model risks this, especially when pricing becomes a stronger decision-maker than battlefield conditions.

### Solved purchase orders

If one route is mathematically efficient enough that experienced players eventually execute it automatically, the apparent choice disappears.

The player should not be asking:

> "Which axis is cheapest?"

The player should be asking:

> "What does my organism need right now?"

### Busywork presented as interaction

Constantly clicking a button is not automatically interactive.

If the answer is obvious every time, the game should eventually automate it.

### Progression that removes the core game

The root economy must not eventually make positioning, survival, waves, territory control, and Path identity irrelevant.

The incremental layer should expand the scale of the action game, not replace it.

### Hidden irreversible traps

The system can contain tradeoffs, but it should not require a guide to avoid a dead run.

Players should be able to understand the immediate consequence of a developmental choice before committing.

---

# 4. The Novel Opportunity

The strongest opportunity in this project is not simply "an action game with incremental upgrades."

It is:

> **An action roguelite where the incremental economy is a destructible, spatial organism growing beneath the battlefield.**

The economy exists in the same space as combat.

The player:

- creates economic infrastructure by holding territory;
- destroys economic infrastructure when established Green is lost;
- creates isolated economies with Spore;
- creates temporarily unproductive territory with Bloom;
- sacrifices productive infrastructure through Pruning;
- protects and exploits that infrastructure through other Paths;
- uses their own position to influence where stored power becomes useful.

This is substantially less common than conventional incremental trees, generators, prestige layers, factories, and passive multipliers.

The design should preserve this difference rather than slowly drifting back toward a traditional upgrade shop.

---

# 5. Design Thesis

## 5.1 Root is no longer a Path

Root is promoted from:

> one defensive territory build

to:

> the infrastructure every build grows on.

This is the inverse of the Carnivory decision.

Carnivory had one strong spectacle but not enough systemic depth to justify an entire Path, so its best moment became a relic.

Root has the opposite problem. Its strongest ideas are too fundamental to territory health and connectivity to remain isolated inside one Path.

---

## 5.2 Biomass becomes a physical economic output

Biomass should still be represented numerically for clarity, but the number should describe a real state of the organism.

Bad model:

> The UI says +5 Biomass/s because Territory % is 50%.

Desired model:

> Established rooted cells are actually producing Biomass, the network has finite storage, disconnected components have separate reserves, and the displayed number summarizes that simulation.

The simulation should create the economy.

The economy should not merely trigger an animation pretending a simulation exists.

---

## 5.3 Mass, Pressure, and Cohesion can survive underneath

The player-facing upgrade system does not need to expose Mass Lv. 7, Pressure Lv. 6, Cohesion Lv. 6.

Those concepts can remain extremely useful as simulation variables.

For example:

- root storage and available biological material can influence Mass;
- vascular output can influence Pressure;
- root anchoring and tissue structure can influence Cohesion.

The difference is that the player develops **physiology**, while the simulation uses **physical parameters**.

---

# 6. Core Incremental Loop

## 6.1 Claim

Paths and normal territory mechanics create Green.

Fresh Green is valuable tactically because it changes ownership, but it is not yet mature infrastructure.

## 6.2 Hold

A patch must remain meaningfully Green long enough to establish roots.

This makes holding territory distinct from merely touching it.

## 6.3 Root

Sustained Green develops root depth.

Prototype variable:

```text
root_depth: 0.0 → 1.0
```

A simple first implementation is preferable to an immediately complicated biological model:

```text
if control > ROOT_GREEN_THRESHOLD:
    root_depth += root_growth_rate * maturity_factor * dt
else:
    root_depth -= root_decay_rate * hostility_factor * dt
```

The first prototype only needs to prove one idea:

> **Temporary Green and established Green are economically different.**

## 6.4 Produce

Rooted territory generates Biomass.

First-pass production:

```text
cell_output =
    green_strength
    * root_depth
    * productivity_constant
```

This creates a useful distinction:

**70% fresh Green** can be economically weaker than **45% deeply rooted Green**.

Territory quantity and territory quality become separate axes.

## 6.5 Store

Produced Biomass enters the storage capacity of the root component that produced it.

For the MVP, storage should exist per connected root component rather than per cell.

```text
RootComponent:
    component_id
    rooted_cell_count
    biomass_current
    biomass_capacity
    biomass_generation_rate
    connected_to_primary_network
```

## 6.6 Spend

Biomass has two competing uses.

### Consume

Spend it for immediate battlefield power.

### Compound

Spend it to permanently develop the root system for the remainder of the run.

This is the central economic decision.

---

# 7. Root Connectivity

Rooted Green should form connected components.

Do not immediately implement a full fluid network.

Start with topology.

## 7.1 Main organism

The connected component containing the primary player ecosystem becomes the main root network.

Its reserve is the main Biomass reserve.

## 7.2 Satellite colonies

Disconnected rooted territory becomes a local colony.

It:

- produces Biomass locally;
- has limited local storage;
- cannot instantly draw from the main network;
- can survive temporarily on its local reserve;
- becomes fully integrated when Green reconnects it to the primary organism.

## 7.3 Reconnection event

When two root networks merge:

1. the connection visibly establishes;
2. a pulse moves through the newly joined roots;
3. local reserves synchronize according to the simulation rules;
4. the player receives a subtle but satisfying audiovisual confirmation.

This should become a recognizable game event.

---

# 8. Player as Metabolic Control Signal

This is the primary interactive mechanic to prototype.

The root network automates routine transport.

The player influences where support becomes valuable.

## 8.1 Metabolic attraction field

The player's current position creates a local demand or attraction field.

Connected roots preferentially direct available support toward that region.

This does not need true shortest-path routing in the prototype.

A cheap spatial approximation is preferable.

## 8.2 Intended feeling

The player notices a frontier collapsing.

They physically run toward it.

As they approach:

- nearby roots brighten;
- pulses begin favoring that direction;
- local metabolic support builds;
- active root abilities become more effective there.

The player has manipulated the incremental system simply by moving intelligently.

## 8.3 Why this matters

The incremental layer is no longer:

> wait until Biomass reaches 300.

It becomes:

> I have 190 stored, the west is collapsing, I can move there and turn that reserve into something useful.

Movement remains the player's primary continuous input.

Metabolism should piggyback on that instead of inventing a second management game.

---

# 9. Active Biomass Spending

The root system needs active uses before permanent development is added.

If producing and spending Biomass is not satisfying by itself, a larger progression tree will not fix it.

## 9.1 Overgrow

Overgrow should become the first active metabolic discharge.

**Function:**

Release a portion of the stored Biomass through the connected root network and into frontier growth.

Its shape should depend on the actual connected organism rather than a global arbitrary effect.

Possible first-pass behavior:

- spends a fixed percentage of the main reserve;
- prioritizes frontier near the player;
- propagation weakens with network distance;
- disconnected colonies use only their own reserve;
- visible pulses travel through roots before the surge.

## 9.2 Future metabolic actions

Do not implement all of these immediately, but the system can eventually support verbs such as:

### Regenerate
Spend Biomass to rapidly restore damaged rooted territory.

### Pressurize
Release stored pressure through the network to shove or destabilize hostile territory.

### Deep Root
Spend Biomass to accelerate establishment in the player's local region.

### Translocate
Temporarily pull reserve from safe interior components toward the player's current region.

These should be large strategic commands, not maintenance buttons.

---

# 10. Compound vs Consume

This is the primary incremental tension.

Example:

**Current reserve:** 260 Biomass  
**Next permanent development:** 300 Biomass

A dangerous wave begins.

The player can:

- save the reserve and attempt to survive conventionally;
- spend 120 on Regenerate;
- spend 180 on Overgrow and try to seize more productive land;
- wait for 300 and immediately strengthen the organism.

No option should always be correct.

A good run should include moments where the player regrets spending too early and other moments where greedily saving almost gets them killed.

That is useful tension.

---

# 11. Permanent Root Development

Do not begin by creating a huge tree.

First prove that permanent development creates better decisions than the old stat levels.

## 11.1 Prototype developments

Use three equal-cost experimental developments:

### Rapid Rooting
New sustained Green establishes roots substantially faster.

### Storage Tissue
The primary network gains considerably more reserve capacity.

### Conductive Roots
The player's metabolic influence reaches farther through connected Green.

These are temporary prototype mechanics.

Their purpose is to test three different incremental strategies:

- expansion;
- banking;
- active control.

## 11.2 Immediate feedback requirement

Every permanent development must visibly affect the battlefield immediately.

Examples:

**Rapid Rooting:** a growth pulse runs through young Green and fine root hairs appear.

**Storage Tissue:** visible nodules form and begin filling.

**Conductive Roots:** a strong pulse travels through the connected network and briefly reveals its increased reach.

Never let the player buy a major development and only see:

```text
root_growth_multiplier = 1.25
```

even if that is the internal implementation.

---

# 12. Later Physiology

Only after the MVP works should the prototype upgrades be replaced by a proper developmental system.

Possible physiological directions:

| Direction | Governs |
|---|---|
| **Rooting** | how quickly claimed territory becomes productive |
| **Storage** | how much reserve can be banked and where it lives |
| **Circulation** | how quickly and how far support travels |
| **Anchoring** | how established territory resists separation and erosion |

These are not intended as four traditional level bars.

They are developmental domains.

Deep investment should eventually create **metamorphoses** rather than simply larger numbers.

---

# 13. Metamorphoses

A metamorphosis should change the architecture of the organism.

Examples:

## Storage

### Central Taproot
Most reserve is concentrated into a powerful central structure.

**Strengths:**
- huge capacity;
- strong central discharge;
- dramatic compounding.

**Weakness:**
- separated colonies lose access to the central reserve.

### Distributed Nodules
Storage is spread throughout the network.

**Strengths:**
- disconnected regions retain meaningful reserves;
- resilient to severing.

**Weakness:**
- lower peak central capacity.

---

## Circulation

### Cardiac Pumping
Support moves in large rhythmic pulses.

### Continuous Peristalsis
Support travels continuously and smoothly throughout connected roots.

Neither should simply be the superior option.

---

## Rooting

### Colonial Roots
Disconnected Green establishes strong independent root colonies.

### Aggressive Branching
Connected Green roots newly captured frontier extremely quickly.

---

## Anchoring

### Fibrous Mat
Wide, distributed anchoring makes fronts difficult to peel away.

### Deep Taproots
Smaller areas become extremely difficult to uproot once mature.

---

# 14. Unfolding Schedule

Do not expose the whole system at minute zero.

Suggested order:

## Layer 1
**Green can root.**

Player learns:

> held territory becomes different from fresh territory.

## Layer 2
**Roots generate Biomass.**

Player learns:

> mature territory is my economy.

## Layer 3
**Roots store Biomass.**

Player learns:

> I can bank power.

## Layer 4
**Overgrow consumes Biomass.**

Player learns:

> spending and saving compete.

## Layer 5
**Permanent development.**

Player learns:

> Biomass can compound.

## Layer 6
**Connectivity.**

Player experiences a disconnected colony and later reconnects it.

## Layer 7
**Metamorphosis.**

The organism begins developing qualitatively different physiology.

The player should have time to understand each layer before the next appears.

---

# 15. Path Integration

Prefer emergent interactions over explicit "+X% while rooted" rules.

## 15.1 Bloom

Bloom paint is already unrooted.

Therefore:

1. Bloom violently seizes territory.
2. The splattered Green remains economically weak and fragile.
3. Holding the area allows roots to establish beneath it.
4. Rooting turns temporary conquest into actual organism.

This makes Bloom's existing distinction between wet paint and established territory more important.

## 15.2 Spore

A Seed creates a satellite colony.

The colony initially owns an independent root network.

This creates:

**Seed → colony → local roots → local Biomass → physical connection → integration with primary organism**

Spore Burst becomes economically meaningful automatically.

## 15.3 Bramble

Bramble can naturally perform differently on mature rooted territory because the ground beneath it is more stable and better supplied.

Do not immediately add explicit Root bonuses.

First observe what the universal system already creates.

## 15.4 Pruning

Pruning becomes especially interesting.

Harvesting territory may now consume:

- immediate Green;
- mature roots;
- productive infrastructure;
- stored local Biomass.

Therefore Pruning creates a natural tension:

> immediate offensive material versus long-term economic infrastructure.

This is much stronger than an authored synergy percentage.

## 15.5 Clover

Do not integrate Clover until the base root system works.

---

# 16. Root Visualization

The root network must carry a large part of the incremental feedback that would otherwise require HUD elements.

## 16.1 Normal visibility

Roots should be subtle during normal combat.

The player should perceive that established Green is alive without having every root line compete with enemies and projectiles.

Use:

- low contrast;
- low opacity;
- broad shapes rather than fine noise;
- slow motion;
- sparse pulses.

## 16.2 Inspect visibility

When the player opens the Root/Metabolism inspect state, increase visibility of:

- major roots;
- connected components;
- storage organs;
- current flow;
- isolated colonies;
- player influence region.

The inspect state can temporarily dim nonessential battlefield decoration.

## 16.3 Developmental stages

### Shallow
Fine hairs. Sparse network.

### Established
Visible branches under mature Green.

### Developed
Thicker vascular trunks and local storage structures.

### Late
Large arteries, rhythmic pulses, visibly specialized physiology, and dramatic discharge events.

## 16.4 Severing

When a meaningful root connection is cut:

- pulse movement stops across the break;
- the far region slowly loses vascular activity;
- an audible low-frequency connection tone disappears;
- the disconnected region should not instantly look dead.

The player should understand that it has become isolated.

## 16.5 Reconnection

When connection returns:

- roots visibly join;
- a bright but brief pulse crosses the new bridge;
- downstream roots reactivate;
- stored/local states synchronize;
- use a distinctive reconnection sound.

---

# 17. Performance Strategy

Do not build the most physically accurate transport model first.

The project already learned that a true shortest-path growth simulation could be much more expensive than the visible benefit justified.

## 17.1 MVP

Use:

- component labeling;
- local influence;
- low-frequency root updates;
- one reserve per component;
- simplified propagation.

## 17.2 Later possibility

A low-resolution support field may eventually approximate vascular transport.

It should:

- update less frequently than territory control;
- support downsampling;
- be independently toggleable;
- have performance instrumentation from the first implementation.

## 17.3 Do not initially implement

- individual Biomass particles;
- full root pathfinding;
- per-cell storage;
- continuous fluid dynamics;
- a detailed root mesh simulation.

The player needs believable behavior, not a graduate thesis running at 15 FPS.

---

# 18. HUD Research: What Players Consistently Want

The HUD research produced a very consistent pattern.

Players do not universally want "less HUD."

They want **less irrelevant HUD**.

A clean interface fails when it hides information the player needs. A detailed interface fails when everything competes for attention at once.

The most reliable principle is:

> **Minimal by default, informative on demand, immediate when dangerous.**

---

# 19. Current HUD Assessment

The supplied current-game screenshot is a useful constraint.

The current layout already has several strengths worth preserving.

## 19.1 What is already working

### The arena owns the screen

The center of the display is almost completely unobstructed.

That is particularly important for this game because the player needs to read:

- territory boundaries;
- approaching enemies;
- Bloom trajectories and splats;
- Pruning objects;
- Bramble fields;
- root activity;
- the player's own movement space.

Do not sacrifice that advantage.

### Information is edge-anchored

The current HUD uses strong edge anchors instead of floating panels throughout the arena.

Keep this.

### The overall silhouette is compact

The HUD already looks closer to an action game's status layer than an RPG dashboard.

That is appropriate.

### There is substantial negative space

This gives the new Root system room to communicate through the battlefield without immediately requiring more panels.

---

## 19.2 Primary future risk

The **right-side vertical rail** is the most likely place for future clutter.

If every new system adds another permanent section, it can slowly become:

- Paths;
- relics;
- Path counters;
- Root reserve;
- income;
- root developments;
- disconnected colonies;
- objectives;
- cooldowns;
- status effects.

That would preserve the central arena but still force the player to scan a dense dashboard during action.

The redesign should prevent that now.

---

# 20. HUD Information Hierarchy

Every HUD datum should belong to one of four tiers.

## Tier 1: Survival-critical

The player may need this within a fraction of a second.

Examples:

- Territory %;
- player HP;
- immediate lethal warnings.

These remain permanently visible.

## Tier 2: Action-critical

The player needs this to make a decision during combat.

Examples:

- available Biomass reserve;
- whether Overgrow is usable;
- active Path-specific trigger state when immediately relevant.

These should be visible or appear contextually.

## Tier 3: Strategic

The player needs this when planning, not while dodging.

Examples:

- Biomass income rate;
- root development details;
- disconnected component statistics;
- exact relic descriptions;
- Path upgrade descriptions.

These belong in hover, inspect, pause, or drawer states.

## Tier 4: Diagnostic

The game needs this for debugging, but players do not need it.

Examples:

- root_depth numeric value;
- pressure coefficient;
- component ID;
- network conductivity;
- raw nucleation thresholds.

Never expose these in the normal HUD.

---

# 21. Recommended HUD Architecture

The current edge-based structure should remain, but each area should have one clear job.

## 21.1 Left edge: survival and immediate run state

The left side should answer:

> **Am I okay?**

Keep the most urgent information here.

Recommended permanent content:

- Territory % as the visually dominant meter;
- player HP as the secondary survival meter;
- wave/time information if it remains important enough for moment-to-moment planning.

Do not add root-development details here.

### Territory must dominate HP

Territory is the game's primary fail condition.

Its meter should have greater visual weight than player HP.

This can be accomplished through:

- size;
- stronger silhouette;
- position;
- animation under danger.

Do not rely only on different colors.

---

## 21.2 Right edge: build inventory

The right side should answer:

> **What does this run contain?**

Use it primarily for persistent run composition:

- selected Paths;
- relic icons;
- Path/Evolution state;
- compact trigger counters attached directly to the relevant icon.

Do not use the right rail as the home for every dynamic numeric system.

### Relics

Keep them icon-first.

Counters such as:

`8 / 10`

or:

`PRIMED`

belong directly on or immediately beside the relic icon.

Descriptions appear only on hover, controller focus, or pause.

### Path information

Show the identity of the Path permanently.

Show detailed Path state only when it matters.

Example:

A Pruning ring does not need a permanent text panel saying how many spikes exist if the ring itself clearly shows them.

---

## 21.3 Root Metabolism: battlefield-first, HUD-second

Do **not** create a large permanent Root panel.

Root state should primarily be communicated through:

- root visibility;
- pulses;
- storage organs;
- territorial maturity;
- severing;
- reconnection;
- local response around the player.

The HUD only summarizes the part of the system that is necessary for decision-making.

Recommended permanent Root HUD:

### Biomass Reserve

One compact element containing:

- current stored Biomass;
- approximate capacity;
- development-ready state.

Avoid adding separate permanent readouts for:

- income;
- capacity;
- root coverage;
- flow rate;
- network health.

Those can exist in inspect mode.

---

# 22. Biomass HUD Design

Biomass is now both a currency and an emergency reserve.

It deserves permanent visibility, but it should remain compact.

## 22.1 Recommended element

Use one **organic reserve emblem** rather than a traditional resource panel.

It could contain:

```text
          184
      [root icon]
       reserve fill
```

Conceptually:

- central icon represents the root system;
- a radial or vessel-like fill indicates approximate reserve saturation;
- the numeric amount remains available for exact decisions;
- a small pulse indicates that a permanent development is affordable.

Do not show:

`184 / 300 | +6.34/s | Root 58% | Flow 1.22`

during normal combat.

That is inspect-mode information.

---

## 22.2 Development-ready state

When a permanent development becomes affordable:

- the Biomass element changes silhouette or grows a small bud;
- one subtle animation plays;
- optionally play a restrained sound;
- do not flash indefinitely.

The player should know:

> I can develop something now.

They should not be nagged into immediately opening the menu.

---

## 22.3 Spending feedback

When Biomass is spent:

- drain the reserve visualization smoothly;
- visibly send the corresponding energy through the battlefield roots;
- animate the HUD element and battlefield event as one continuous action.

The HUD should look like it is reporting what the organism did, not independently changing a number.

---

# 23. Active Root Ability HUD

The active incremental layer should not become a conventional MMO ability bar.

## 23.1 Overgrow

Overgrow can use one compact action element.

Recommended placement:

- near the Biomass element, because it directly spends Biomass;
- or bottom-center if controller readability requires a stronger action prompt.

Avoid placing a large button permanently in the center.

## 23.2 Affordability

If Overgrow cannot be meaningfully used:

- keep its icon quiet;
- do not continuously show red error text.

When sufficient reserve exists:

- strengthen the icon;
- show the input prompt briefly if needed.

## 23.3 Multiple future metabolic actions

If the system eventually contains several root verbs, do not immediately create four permanent buttons.

Possible escalation:

**1 unlocked:** one icon.  
**2 unlocked:** compact pair.  
**3+ unlocked:** radial selection or contextual cycling.

The action HUD should unfold with the system.

---

# 24. Contextual HUD Rules

A major research theme is that information should disappear when it has no current value.

Use these rules aggressively.

## Hostile count

Visible only while hostiles are present or incoming.

## Biomass income

Show temporarily when:

- production changes significantly;
- the player opens Root inspect;
- a new development alters production.

Do not show it permanently unless testing demonstrates that players actually use it during combat.

## Disconnected colony warning

Only show when:

- a meaningful rooted region becomes isolated;
- it contains enough territory or stored Biomass to matter.

Use a small battlefield marker near the actual colony before adding a sidebar warning.

## Root-development prompt

Appear when affordable, then settle into a quiet ready state.

## Wave objective

Show during introduction and while active.

Collapse after comprehension.

---

# 25. Use the Battlefield as HUD

This game has an unusually strong opportunity to move state information out of panels entirely.

## 25.1 Root maturity

Do not show `Rooted: 63%`.

Let rooted Green look different.

## 25.2 Support flow

Do not show a flow arrow panel.

Let pulses actually move through roots.

## 25.3 Disconnection

Do not primarily show:

`NETWORK DISCONNECTED`

Let the severed region visibly stop receiving pulses.

A brief text warning may reinforce it, but the world carries the information.

## 25.4 Player metabolic influence

The player should be able to perceive that nearby roots are responding to them through:

- increased pulse intensity;
- directional flow;
- subtle ground/root highlighting.

No permanent influence-radius circle is necessary.

An exact radius can appear in inspect mode.

## 25.5 Storage

Storage organs should visibly swell or brighten as they fill.

The exact total remains in the Biomass HUD.

---

# 26. Visual Hierarchy

A beautiful HUD is not one with the fewest pixels.

It is one where the player's eye knows what matters.

## Priority order

During normal combat:

1. player;
2. immediate enemy threats;
3. territory boundary;
4. lethal Territory/HP state;
5. Path spectacle and active mechanics;
6. Biomass availability;
7. build inventory;
8. strategic statistics.

If a HUD element visually competes with items 1 through 3, it is too loud.

---

# 27. Shape Before Color

Do not communicate essential states through color alone.

This matters both for readability and accessibility.

Examples:

### Territory danger

Not just:

green → yellow → red.

Also:

- meter silhouette changes;
- low Territory pulses;
- border animation becomes unstable.

### Biomass ready

Not just:

icon becomes brighter green.

Also:

- reserve bud appears;
- outline expands once;
- unique ready-state shape.

### Disconnected roots

Not just:

roots become gray.

Also:

- pulse stops;
- root animation changes;
- sever point has a recognizable break.

Color should reinforce state, not carry state alone.

---

# 28. Color Discipline

The battlefield already depends heavily on color to communicate ownership.

Therefore the HUD should use color conservatively.

## Rules

- Reserve the player's territory color for player/ecosystem state.
- Reserve hostile territory color for hostile state.
- Avoid inventing a rainbow of one-off system colors.
- Use neutral dark/light values for most HUD framing.
- Use saturation primarily for state changes and warnings.
- Keep permanent decorative elements less saturated than gameplay state.

This prevents the interface from competing with the territory itself.

---

# 29. Typography

Player feedback and accessibility guidance consistently identify tiny text and overly decorative fonts as common interface failures.

## Default approach

Use the game's stylized font for:

- major headings;
- Path names;
- short event announcements.

Use a highly legible UI face for:

- numbers;
- descriptions;
- counters;
- tooltips;
- resource values.

Aesthetic unity should come from framing, spacing, iconography, and motion rather than making every tiny number use a decorative typeface.

## Size

For a 1080p target:

- critical HUD values should be comfortably readable at normal desktop/TV distance;
- do not treat tiny text as sophistication;
- provide UI scaling;
- test at 100%, 125%, and 150% scale.

Accessibility references recommend treating roughly 28 px at 1080p as a minimum rather than an ideal for living-room readability.

---

# 30. Contrast

The battlefield contains constantly changing colors and textures.

HUD text therefore needs protection from the background.

Use:

- subtle dark backing plates;
- outlines;
- drop shadows;
- local blur/dimming where appropriate.

Accessibility guidance commonly uses a 4.5:1 contrast ratio as a useful target for normal text.

Do not rely on a translucent pale label sitting directly over bright Green or hostile territory.

---

# 31. Icon Design

One Steam UI complaint that recurs in strategy/action games is that highly detailed icons often become unreadable at actual HUD scale.

## Rules

HUD icons should:

- have distinct silhouettes;
- use few internal details;
- remain identifiable when viewed small;
- avoid relying on tiny symbols inside tiny symbols;
- use consistent stroke/shape language.

Relic illustrations can be beautiful at reward-screen size.

Their HUD versions should be simplified representations of the same concept if necessary.

---

# 32. Spacing and Grouping

The current HUD already benefits from open central space.

Preserve that feeling inside the edge panels too.

Do not pack every element into adjoining framed rectangles.

Use spacing to communicate grouping.

Example right rail:

```text
PATHS

[path] [path]


RELICS

[relic]
[relic]
[relic]
```

is easier to parse than six equally bordered modules touching one another.

Whitespace is functional.

---

# 33. Animation Rules

Motion is one of the most powerful attention tools available.

Do not waste it on decoration.

## Permanent HUD

Mostly still.

## State changed

One brief animation.

## Urgent state

Repeated motion only while urgency remains.

## Ready state

One animation when first becoming ready, then a quiet persistent indicator.

## Root network

Continuous movement is acceptable because it represents actual flow, but keep normal flow slow and subtle.

The player's eye should react to **changes in motion**, not constant visual noise.

---

# 34. Current HUD Redesign Recommendation

Do not rebuild the current HUD from scratch.

Iterate its existing silhouette.

## Left

Keep the current compact left-side anchor.

Use it for:

1. Territory;
2. HP;
3. wave/time if required.

Increase hierarchy between Territory and HP if they currently read with similar visual weight.

## Right

Retain the current vertical run-information region, but aggressively restrict its job.

It should primarily contain:

- Path identity;
- Evolution state;
- Relics;
- relic trigger counters.

Do not add Root statistics here.

## Root/Biomass

Add one compact reserve element physically associated with the active metabolic action.

Possible locations to prototype:

### Option A: lower-left under survival state
Good for strong association with core resources.

### Option B: bottom-center
Good for active ability readability and controller input.

### Option C: lower-right beneath the build rail
Good if it remains visually isolated from the relic list.

**Recommendation:** test A and B first. Avoid extending the existing right rail downward until it becomes a dashboard.

---

# 35. Root Inspect Layer

The game needs a way to expose deeper information without carrying it permanently.

Create a dedicated **Root Inspect** state.

Possible activation:

- hold a key/button;
- press the Biomass/root HUD element;
- pause and select the root tab.

## Inspect reveals

- root depth visualization;
- main network;
- disconnected colonies;
- local reserves;
- major storage structures;
- support flow;
- player influence region;
- current production;
- permanent developments.

## Inspect does not need to freeze the game by default

If readability allows, it can be a hold-to-inspect overlay.

If testing shows players cannot safely process it while moving, allow an accessibility/UX option to pause or slow time while inspecting.

---

# 36. Reward and Development Screens

When a permanent physiological development is chosen, the reward screen should remain extremely focused.

## Show

- three choices maximum;
- large clear icon;
- short name;
- one-sentence mechanical effect;
- small visual preview if practical.

## Avoid

- multiple paragraphs;
- five stat lines;
- hidden mathematical interactions;
- elaborate nested prerequisites.

The effect should be understandable before selection.

If a choice needs a wiki explanation, simplify it.

---

# 37. Tooltips

The project previously discovered that tooltips failed because UI rows were being rebuilt repeatedly.

Fix the architecture before adding more hover content.

## Rule

Rebuild layout only when structure changes.

Update dynamic values without destroying and recreating the UI element.

This matters for:

- relic counters;
- Biomass;
- Root reserve;
- Path triggers;
- upgrade states.

## Tooltip content

Keep concise.

Recommended structure:

**Name**  
One-line effect.

Optional second line only if necessary:

*Interaction or special condition.*

Do not put lore and mechanics into the same tiny combat tooltip.

---

# 38. Controller and Mouse Behavior

The controller focus box already changes based on input device.

Preserve that behavior.

## Mouse

- hover reveals tooltip;
- movement immediately removes controller focus treatment.

## Controller

- focus state only appears when controller navigation is active;
- focused icons may expand or show descriptions in a side bubble;
- avoid requiring precise cursor-like navigation.

## Keyboard

- do not leave controller focus boxes permanently visible.

---

# 39. Accessibility Baseline

A clean HUD should not achieve beauty by becoming difficult to read.

Implement or reserve architecture for:

- HUD scale;
- text scale;
- high-contrast mode;
- adjustable HUD opacity;
- colorblind-safe territory alternatives;
- reduced flashing;
- reduced root/background motion;
- separate UI and effects volume;
- remappable Root Inspect and metabolic-action controls.

No essential state should rely on color alone.

---

# 40. HUD Clutter Budget

Treat permanent HUD space as a finite resource.

Before adding any permanent element, ask:

1. Does the player need this during combat?
2. Does it change quickly enough that memory is insufficient?
3. Can the battlefield communicate it instead?
4. Can it be contextual?
5. Can it live in inspect mode?
6. Does another existing element already communicate the same thing?

If the first two answers are not clearly yes, the element should probably not be permanent.

---

# 41. Suggested Permanent HUD Inventory

Target normal combat state:

## Always visible

- Territory %
- player HP
- wave/time if genuinely useful
- current Biomass reserve
- selected Path identities
- relic icons

## Contextual

- hostile count
- objective
- Root development ready
- metabolic-action affordability
- isolated-colony warning
- important relic trigger
- Evolution event

## Inspect / pause

- Biomass generation rate
- root coverage %
- root component count
- per-colony reserves
- development details
- complete relic descriptions
- exact Path mechanics
- network visualization

This is intentionally much less information than the simulation contains.

---

# 42. HUD A/B Tests

Before committing to the final Root UI, run controlled tests.

## Test A: Biomass placement

Compare:

- lower-left;
- bottom-center.

Measure:

- how quickly players notice reserve changes;
- how often they glance away from the battlefield;
- whether they notice Overgrow availability.

## Test B: Root visibility

Compare:

- always subtle;
- mostly hidden until active;
- visibility based on maturity.

Measure:

- whether players can identify rooted versus fresh Green;
- whether roots visually clutter enemy/projectile readability.

## Test C: Development-ready notification

Compare:

- pulsing icon;
- brief banner plus quiet icon;
- sound plus icon.

Measure:

- missed developments;
- annoyance;
- whether players feel pressured to immediately open the menu.

## Test D: Inspect layer

Compare:

- hold overlay during live action;
- toggle overlay;
- pause/slow-time inspect.

Measure:

- comprehension;
- interruption;
- accidental deaths while reading.

---

# 43. Instrumentation

Record the following for Root-system testing:

```text
territory_percent
rooted_territory_percent
deep_rooted_percent
biomass_generated_total
biomass_stored_current
biomass_spent_active
biomass_spent_development
overgrow_uses
root_components
largest_component_size
isolated_component_count
territory_lost
rooted_territory_lost
time_between_development_purchases
player_distance_from_highest_demand_front
```

Record each Biomass decision:

```text
timestamp
current_biomass
action
territory_percent
rooted_percent
active_hostile_count
largest_component_state
```

For HUD testing, also record where practical:

```text
time_to_open_root_inspect_after_disconnect
time_to_use_overgrow_after_affordable
development_ready_duration_before_selection
hud_scale_setting
input_device
```

The goal is not merely to determine whether the player won.

The goal is to understand:

> **What information did the player use to decide what to do with the organism?**

---

# 44. Implementation Order

## Phase 0: Feature flags

- Disable Root Path selection behind a flag.
- Disable the old Mass / Pressure / Cohesion purchase system behind a flag.
- Keep both available for A/B comparison.
- Preserve current stable build.

## Phase 1: Root field

Implement `root_depth`.

Add debug visualization.

No economy yet.

**Question:** Does sustained territory visibly become established?

## Phase 2: Root productivity

Generate Biomass from rooted territory.

Add one reserve per connected component.

**Question:** Does holding territory feel economically valuable?

## Phase 3: Connectivity

Label rooted components.

Implement local reserves for isolated colonies.

Add sever/reconnect visualization.

**Question:** Does territory geometry matter economically?

## Phase 4: Active Overgrow

Convert Overgrow to spend actual reserve.

Add visible discharge through roots.

Bias it toward the player's region.

**Question:** Is Biomass fun to actively spend before permanent upgrades exist?

## Phase 5: Player metabolic influence

Implement a cheap influence field around the player.

No expensive pathfinding.

**Question:** Does movement meaningfully influence the incremental layer?

## Phase 6: Three prototype developments

Add:

- Rapid Rooting;
- Storage Tissue;
- Conductive Roots.

Use equal cost.

**Question:** Do players naturally choose different developmental priorities?

## Phase 7: HUD integration

Implement:

- compact Biomass reserve;
- development-ready state;
- contextual Overgrow affordance;
- Root Inspect overlay.

Do not add permanent root-stat panels.

**Question:** Can players understand and operate the system without clutter?

## Phase 8: Path integration

Test Bloom, Spore, Bramble, and Pruning against the root system.

Prefer emergent behavior.

## Phase 9: Proper physiology

Replace prototype developments with the final developmental domains and metamorphoses.

Only do this after the loop is proven.

---

# 45. Explicit Things Not to Build Yet

Do not currently implement:

- full Darcy-flow simulation;
- individual Biomass particles;
- manually placeable roots;
- an extensive root skill tree;
- prestige;
- multiple root currencies;
- dozens of adaptations;
- root-specific relics;
- complicated Path/root bonuses;
- per-cell storage;
- full surface-tension gameplay;
- old Root Evolutions;
- a large permanent Root HUD panel.

These are all tempting ways to bury an unproven loop under content.

---

# 46. Prototype Success Criteria

The first version succeeds only if most answers are yes.

## Comprehension

Can a player explain:

> "Green that survives grows roots, roots make Biomass, Biomass lets me actively use or permanently develop the organism."

## Visual progression

Can someone identify the late-run screenshot without a timer?

## Interaction

Does movement visibly affect where metabolic support becomes useful?

## Spending tension

Do players sometimes spend Biomass immediately and sometimes greedily save it?

## No purchase algorithm

Does the correct decision depend on current battlefield conditions?

## Continuous play

Does combat continue naturally while the incremental system develops?

## No chores

Does any repeated input immediately feel like something the game should automate?

## Topology

Does severing and reconnecting rooted territory matter enough that players notice?

## Development impact

Can players tell what changed shortly after developing the network?

## HUD clarity

Can players answer the important questions at a glance without staring at the sidebars?

---

# 47. Ten-Second HUD Test

At any normal combat moment, a player should be able to answer these questions within roughly ten seconds without opening a menu:

1. How close am I to losing Territory?
2. How close am I to dying personally?
3. How much Biomass do I have available?
4. Can I trigger my important metabolic action?
5. What Paths am I running?
6. What major relic effects are currently relevant?
7. Is something unusual happening to my root network?

They should **not** need to know, during those same ten seconds:

- exact root conductivity;
- exact production per second;
- every colony's stored reserve;
- every relic description;
- every physiological coefficient.

---

# 48. Visual North Star

The late-game fantasy should not be:

> **Biomass 2,450. Root Level 12.**

It should be:

> **I grew this thing.**

The player should see:

- old territory becoming biologically dense;
- distant Spore colonies developing their own root systems;
- Bloom splats transitioning from wet conquest into anchored organism;
- major root trunks connecting formerly separate regions;
- storage organs filling;
- pulses following the player's movement;
- Pruning visibly sacrificing valuable established ground;
- enormous reserve discharges racing through the network;
- a battlefield whose economic history is visible in its physical structure.

The HUD should quietly support that spectacle rather than sitting on top of it.

---

# 49. Final Design Rules

1. **The battlefield is the incremental interface.**
2. **The root network automates logistics, not decisions.**
3. **Biomass must always represent a real state of the organism.**
4. **Every permanent development should change visible behavior.**
5. **Immediate spending and long-term compounding must compete.**
6. **Territory quantity and territory quality should both matter.**
7. **Connectivity should create gameplay without manual routing.**
8. **Movement should interact with Metabolism because movement is already the player's primary verb.**
9. **Do not add a UI element when the battlefield can communicate the same state.**
10. **Permanent HUD information must earn permanent screen space.**
11. **Minimalism must never hide survival-critical information.**
12. **Use shape, animation, sound, and color together rather than relying on color alone.**
13. **Automate anything that becomes an obvious repeated action.**
14. **Do not build the final progression tree until the base root loop is fun.**
15. **If the system feels like waiting for another currency bar to fill, redesign the interaction before adding content.**

---

# 50. Research References

The design recommendations above were informed by player discussions, reviews, and accessibility guidance covering incremental progression and game HUD design. Especially useful themes came from discussions around active versus idle progression, unfolding mechanics, automation, visible escalation, UI overload, contextual HUDs, readable iconography, and diegetic feedback.

## Incremental / progression references

- Reddit, r/incremental_games: discussions on unfolding mechanics, automation, active versus idle play, physics-driven incrementals, prestige fatigue, and meaningful choices.
- Steam player reviews and discussions for **Orb of Creation**, **Gnorp Apologue**, **Sixty Four**, **To The Core**, **Nova Drift**, **Hades**, **Brotato**, and related progression-heavy games.
- Community discussions criticizing solved upgrade paths, invisible percentage progression, repetitive maintenance, and progression systems that eventually play the game for the player.

## HUD / UI references

- Reddit, r/gamedesign: **How to Properly Design a HUD**
- Reddit, r/gamedev: discussions on clean versus zero-HUD interfaces
- Reddit, r/gaming: favorite game HUD discussions, including repeated praise for **Dead Space**, **Metroid Prime**, and other interfaces that move information into the world
- Reddit, r/gamedev: **4 very quick fixes to improve your game's HUD** (2026), emphasizing removal of unnecessary permanent information
- Steam Community feedback on clutter, small icons, inconsistent fonts, and combat readability in action-oriented games
- Game Accessibility Guidelines:
  - readable default font sizes
  - high contrast between UI and changing backgrounds
  - no essential information conveyed through color alone
  - adjustable interface size
  - clear text formatting
  - keeping temporary critical information inside the player's eye-line

## Useful URLs

- https://gameaccessibilityguidelines.com/basic/
- https://gameaccessibilityguidelines.com/provide-high-contrast-between-text-ui-and-background/
- https://gameaccessibilityguidelines.com/use-an-easily-readable-default-font-size/
- https://gameaccessibilityguidelines.com/use-simple-clear-text-formatting/
- https://www.reddit.com/r/gamedesign/comments/imnci9/
- https://www.reddit.com/r/gamedev/comments/1d4syo5/
- https://www.reddit.com/r/gaming/comments/15qn8s4/
- https://www.reddit.com/r/gamedev/comments/1vqrk3m/

---

# 51. Immediate Next Prototype

The first meaningful build should contain only:

- Green;
- root depth;
- root-generated Biomass;
- root connectivity;
- connected-component storage;
- player-biased Overgrow;
- three temporary permanent root developments;
- one compact Biomass HUD element;
- a Root Inspect overlay.

Do not add final physiology, additional active root abilities, or large amounts of content until this version already creates the following thought naturally:

> **"I need to hold this land so it roots. I want to connect that colony. I'm saving for development, but I really want to dump my reserve into this front right now."**

If the player starts thinking that without being instructed to, the redesign is working.
