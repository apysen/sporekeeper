# Sporekeeper territory simulation architecture

Sporekeeper uses a continuous, physics-inspired territory field for a fixed-screen
survivor arena. Territorial material grows, pushes, resists, erodes, fragments,
and converts; it is not a board of discrete gameplay tiles. The complete arena
remains visible and active throughout a run.

This document turns the Territory Survivor GDD into an implementation contract
for the Godot project. It intentionally does not lock the open prototype values
identified by the GDD: field resolution, exact mass/pressure/conversion math,
starting territory, maturity curves, fragment decay, the territory-loss grace
period, and the number of hostile factions all require playtesting.

## Locked experience versus prototype implementation

The following experience requirements are stable even if the implementation
changes:

- Player, hostile, and neutral territory form organic continuous regions.
- Mass and pressure can deform a frontier rather than recolor a perfect shape.
- Arena obstacles and channels influence how territorial pressure spreads.
- Enemy actions can erase, convert, suppress, tunnel through, or split territory.
- Disconnected pieces remain real owned area; element rules decide whether small
  fragments decay, stabilize, or become colonies.
- Maturity is continuous. Fresh, Established, and Mature are presentation bands,
  not three discrete simulation states.
- All owned area contributes equally to Territory %, while maturity changes
  resistance, Biomass value, and mechanic eligibility.
- Player Territory % is the primary strategic health bar, separate from player
  HP. The field reports state; the run director owns victory and defeat.
- The game remains readable while strong builds create large chain reactions and
  visually exaggerated effects.

An internal sampled lattice is permitted and expected. It is a numerical
representation of a continuous field, not a grid exposed as placement cells,
movement tiles, or binary capture squares. Rendering interpolates and deforms
the samples into a continuous frontier.

## Authority and representation

`TerritoryField` is the sole authority for spatial territory state. The initial
prototype should favor deterministic, testable gameplay buffers and a separate
texture-based renderer. The current project uses Godot's GL Compatibility
renderer, so no design rule may depend on a particular GPU-only compute path.
A later backend may move proven work to the GPU only if it preserves gameplay
queries, reproducibility, debug visibility, and supported hardware behavior.

The field has these semantic layers. Their packing and resolution remain an
implementation choice:

| Layer | Meaning | Authority notes |
| --- | --- | --- |
| Control | Neutral or faction ownership plus local control strength | Source for area and frontier calculations |
| Maturity | Continuous age/stability of controlled material | Resets or transfers according to explicit conversion rules |
| Transient pressure | Short-lived directional or radial displacement influence | Cleared or dissipated by fixed-step rules |
| Effect layers | Element-specific spatial state, beginning with Plant Infection | Registered explicitly; never hidden in a shader |
| Arena mask | Claimable space, permanent obstacles, and authored special regions | Comes from arena data and is immutable during ordinary play |
| Suppression mask | Temporary Warden, boss, or objective restrictions | Applied by typed effects with owned lifetimes |

Resistance is normally derived from owner profile, maturity, temporary effects,
relic modifiers, and local conditions. Cache it only if profiling shows a need;
there must still be one rule that defines it. Visual color is derived from field
state and never serves as the only ownership record.

Use one explicit world-to-field transform owned by the arena/field boundary.
Player targeting, enemies, effects, metrics, debug tools, and rendering all use
that transform rather than independently rounding world positions.

## Territory effect command boundary

Gameplay systems request spatial changes through immutable
`TerritoryEffectCommand` values. A command identifies its source and faction,
shape or sampled mask, world transform, timing, and the operations it applies,
such as:

- add or remove territorial mass;
- apply radial or directional pressure;
- erode control along a path;
- add conversion strength against hostile material;
- add or consume an element-specific layer such as Infection;
- create or remove temporary suppression;
- request topology-sensitive behavior from an already published fragment or
  colony identifier.

Commands use stable source IDs and a monotonically assigned sequence so equal
inputs resolve in a repeatable order. An effect cannot hold a writable buffer,
read a renderer texture as gameplay state, or invoke another effect recursively.
Results publish after the field step as typed events and read-only snapshots.

Long-lived objects such as Seeds, Bloom buds, Colony Cores, and Warden zones may
exist as scene entities because players and enemies can target them. Those nodes
own health, telegraphs, and lifetime; their spatial influence still enters the
field through commands.

## Fixed-step update

Rendering and input may run at a variable frame rate, but territory rules use a
fixed simulation step and preallocated work buffers. A bounded accumulator may
perform a small number of catch-up steps after a hitch. When the budget is
exhausted, the game must avoid an unbounded catch-up spiral; record the overload
for profiling and use the chosen safe degradation policy.

Each field step follows an explicit phase order:

1. Freeze the commands queued for this step and sort them by phase, source, and
   sequence. Newly triggered work is queued for a later step.
2. Apply arena and active suppression masks.
3. Stamp injections, erosion, conversion, infection, and pressure into scratch
   buffers without presenting a partially updated field.
4. Resolve local propagation, displacement, and frontier competition using the
   current prototype's authored rules.
5. Resolve ownership changes and update maturity according to the final owner.
6. Advance fragment decay and other field-wide timed behavior at their declared
   cadence.
7. Publish changed regions, territory metrics, territorial events, and any due
   topology results from a coherent post-step snapshot.
8. Hand changed data to the renderer and debug views without granting either
   writable access to gameplay buffers.

Phase order is part of saved/prototype versioning. Changing it can change a run
even when every individual formula remains the same.

## Metrics, topology, and queries

`TerritoryMetrics` is the only owner of aggregate area calculations. It derives:

- claimable arena area;
- player, hostile, and neutral area and percentages;
- maturity distribution or maturity-weighted player area for Biomass;
- optional summaries needed by objectives and difficulty composition.

Territory % uses owned area without a maturity multiplier. `BiomassEconomy`
consumes the published maturity summary and owns currency accumulation; the
field never awards or spends Biomass. `RunSurvival` consumes Territory % and
owns any future zero-territory grace timer. Victory checks combine field metrics
with remaining hostile-core rules outside the field.

`TerritoryTopology` owns connected-region analysis for fragments and colonies.
It operates on stable snapshots and may run less often than the core field step.
It publishes stable region IDs, bounds, area, age, and connectivity changes.
Swarm, Colonizers, objectives, and UI consume those results rather than starting
their own flood fills. A delayed topology result must never block field updates.

Read-heavy consumers use a shared query snapshot or a batched query service:

- weapons request target candidates from combat spatial indexing, not the field;
- enemies sample only the territory facts needed by their role;
- Bramble combat samples cached ownership and a cached frontier representation;
- placement of Blooms, Seeds, and Colony Cores uses authored candidate queries;
- AI does not scan the full field or read back a rendered texture per agent.

## Plant reference mechanics

Plant is the first element used to prove the shared architecture. Its mechanics
map to the territory boundary as follows:

- **Baseline Seeds:** the element runtime counts eligible enemy deaths. A Seed
  is a targetable timed entity; germination submits a low-impulse Plant mass
  command that applies wherever it lands, including ground the player does not
  hold. Seeds are the only Plant mechanic that colonises detached territory.
  Combat owns the death, the Seed owns its charge and durability, and the field
  owns the resulting growth.
- **Spore:** changes Seed production, germination timing, mass, durability, and
  event interactions. It does not implement a second growth solver.
- **Bloom:** a visible bud chooses a location on the published Plant frontier,
  winds up briefly, then submits radial mass, pressure, damage, and conversion
  intents to their owning systems. Bloom mass is scaled by the Plant support the
  field finds between the cell and the burst origin, so a Bloom displaces
  territory that already exists and cannot colonise detached ground. Its shape
  emerges from the field and arena geometry rather than a forced circular recolor.
  One eruption is not one stamp. It resolves into a central surge plus a small
  number of thrown splats — globs, satellites, and directional streaks — each of
  which is its own field command carrying its own Mass, Force, and radius. Mass
  and Force stay physically distinct: Mass decides how much material is thrown and
  therefore how thick the resulting territory is and whether an isolated patch
  survives at all; Force decides how far it travels, how elongated it is, and how
  hard it shoves. Thrown splats colonise rather than displace, so a glob that
  clears a wall can establish a detached island that must then survive fragment
  decay, reconnect, and mature on its own merits. Where a splat lands is not
  chosen: each thrown lump is an object with a velocity, and the ground it crosses
  stops it. Basalt and the arena edge stop it dead, hostile ground drags hard and
  charges Mass per pixel crossed, neutral ground costs a little, and the run's own
  Green barely slows it. A wall therefore shortens the spray sideways, a corridor
  funnels a jet, a pillar splits the throw around it, and a Bloom fired into a
  thick invasion falls short of the same Bloom across friendly ground — none of
  those cases is written down anywhere. The streak is the trail the object leaves
  as it goes, spent out of the Mass it is still carrying. Cosmetic microdroplets are drawn by the overlay and are
  never field objects: roughly a dozen splats reach the simulation while dozens
  of droplets reach only the screen.
- **Bramble:** weaponizes owned Plant territory itself. The field publishes
  coverage — whether a cell is claimed Plant ground — and, separately, per-cell
  frontier development as a bonus layer. Combat owns Entanglement, the per-enemy
  accumulator that turns coverage into escalating damage and slow, along with
  crossing hits and repulsion cooldowns. Because the hazard follows ownership
  rather than geometry, holes, moving borders, and buried thorns change the
  bonus and never the hazard.
- **Root:** modifies maturation, mature resistance, recovery, and
  maturity-weighted Biomass rules, and publishes the Root Network amplification
  that other mechanics scale by the maturity of the ground they act from. The field owns the recovery rule as a per-step
  control gain on ground the player still holds, and owns the extra resistance
  applied to cells past the Mature threshold; progression owns how much of either
  the run has earned. Age is a separate explicit field layer counting the seconds
  a cell has held the same owner while past the Mature threshold, reset whenever
  that ownership or maturity lapses. It is authoritative data for Age-scaled
  mechanics and relics, never inferred from a rendered texture.
- **Man-Eater:** the Legendary relic that ate Carnivory. It owns its own Hunger —
  enemy-seconds counted off enemy positions, not a field channel — and asks the
  field only two things: whether a point is the run's own Green, and to spend the
  meal as a local Bloom command afterwards. Nothing persists on the field between
  eruptions, so the field carries no Prey Pressure buffer at all any more.
- **Swarm:** consumes topology results so viable fragments can resist decay,
  become colonies, and create independent fronts. Colony entities do not become
  alternate owners of territory pixels.
- **Parasite:** writes Plant Infection into hostile material through commands.
  Infection weakens resistance or enables rupture according to pure rules;
  visible veins render the authoritative infection layer.

Plant mechanics must use shared commands and published events. Future Fire,
Lightning, Ice, or other elements may register different effect layers and
rules without inheriting Plant terminology or one-to-one path equivalents.

## Physical parameters and the incremental economy

The field exposes the material as gameplay properties — ownership, mass,
pressure, resistance, maturity, cohesion, and age — and the incremental economy
changes those parameters rather than adding a separate progression layer on top.
`Metabolism` reports Photosynthesis as Mass, Meristem as Pressure, and
Cambium as Cohesion; the run root folds those, together with whatever Root has
earned, into the field's spread rate, resistance bonus, cohesion multiplier,
pressure advection, and fragment decay. A Breakthrough changes the shape of a
parameter rather than its size: Woody Tissue lowers advection and raises
resistance so Green holds its shape and then fails suddenly, Flexible Tissue
raises advection and adds rebound so it deforms and springs back, and Apical
Dominance narrows how widely an injection is distributed so Pressure concentrates
into protrusions instead of spreading across the whole frontier.

`overgrow()` is the one bulk injection the field offers. It samples the current
player frontier, derives each cell's outward normal from the Plant behind it, and
adds Mass, outward Pressure, and repair in the caller's proportions. Nothing
about the outcome is authored: open frontier spreads broadly, a gap funnels the
same budget into a jet because only the cells at the gap have an outward normal
pointing through it, and a torn ecosystem spends the repair share thickening thin
Green and pushing back hostile material beside it. Callers pass budgets and read
back what was applied; they never learn which cells were touched.

The Sporekeeper implementation now maintains a compact cached mask of player cells
that border claimable non-player cells, plus a parallel 0-to-1 development value
per cell. Both refresh alongside the fixed field step, so per-enemy Bramble
contact queries scan only a small local band and do not reconstruct the whole
frontier. Unclaimable basalt neighbors never create a thorn boundary.

Development is a property of the cell, not of the border as a whole. A frontier
cell grows toward full strength at a rate scaled by its own maturity, and erosion
or hostile conversion knocks development down at the cells they touch, limited to
a bounded bite per stamp so thorns degrade through bands instead of vanishing.

Frontier development is a bonus layer, not the mechanic. A cell that stops
being a frontier cell decays to bare, and the Bramble hazard on that ground is
untouched, so there is no dormant store, no frontier memory, and no relocation
rule to maintain. Ground the border moves off simply loses its hedge bonus.

`harvest_bramble_in_radius` is the one entry point for consuming Bramble. It
sums each covered cell's territory power plus whatever development stood on it,
clears development inside the inner part of a radius, reports the total and its
power-weighted mean maturity, and leaves the rim alone because that is where the
new frontier will stand. An element mechanic converts that report into its own
effect; the field never decides what harvested Bramble becomes. Coverage is a
single-cell query and reports presence rather than strength, and the frontier
band query reports the strongest development it touches and never the sum, so
convoluted geometry cannot multiply one enemy's exposure.

Enemy erosion and hostile-growth stamps consult the exact frontier rule when
applying Bramble's frontier resistance, interpolated by that cell's development so fresh
wounds are not instantly armored. The Siege Thorns relic reports a besieged
multiplier from combat, which the field folds into that same rule so resistance
keeps one definition. The reported value is derived from the number of enemies
currently touching the frontier and is capped, so a large wave hardens the
border without making it invulnerable. The procedural shader reads the same
authoritative development value only to grow visible stems into thorn tips.

Briar Pods are pooled temporary combat boundaries created by evolved Seeds;
they do not claim territory or become a second ownership source. Because a Pod
is a deliberately conjured perimeter with a finite lifetime rather than exposed
ground, it arrives at its authored strength instead of developing. Briar Traps
are a second pooled combat entity, armed in place by a Thornburst Bloom's
harvest: combat owns their trigger, blast, and chaining, and each detonation
emits a typed event that the element runtime turns into a normal wall-occluded
territory command. Root eruptions are pooled the same way, chaining through
combat while the field supplies only the Age and maturity they read. This
preserves the field command boundary for every Bramble pair evolution.

## Enemy and boss interactions

Enemy roles stay element-agnostic and express their territory behavior through
the same boundary:

- **Hunter** primarily pressures player HP and normally needs only local terrain
  queries for navigation or presentation.
- **Grazer** emits erosion along its traveled path. If a channel splits player
  control, topology reports the resulting fragments.
- **Saboteur** targets vulnerable temporary element entities such as Seeds or
  Bloom buds, falling back to Fresh territory through a batched query.
- **Corruptor** issues hostile conversion or hostile-mass commands rather than
  painting the render target.
- **Colonizer** chooses an arena-approved location, creates a targetable hostile
  Colony Core, and lets that core issue hostile growth commands.
- **Warden** owns a visible suppression zone whose mask and lifetime are applied
  explicitly to named systems or field operations.
- **Burrower** traces a telegraphed erosion/displacement path and an eruption
  command; tunnels are gameplay results, not a decal-only effect.
- **Hive Queen** creates hostile cores through the Colonizer contract and does
  not maintain a private copy of hostile territory.

The Sporekeeper run now implements all six core roles through visible typed
enemy profiles. Corruptor and Colony Core actions submit wall-occluded hostile
growth commands, while Warden actions submit wall-occluded maturity suppression
commands. Saboteurs navigate to targetable Seed/Bloom entities but still require
a clear path for the damaging interaction itself. These agents never write the
field buffers or sample territory rendering.

Enemy deaths remain combat events. Element paths and relics decide what those
deaths trigger, which prevents increased enemy density from automatically
granting territory unless the build can process the horde successfully.

## Relics, evolutions, and chain safety

Relics and evolutions modify typed rule inputs, transform commands before they
enter the queue, or react to published domain events. They do not patch field
buffers or connect arbitrary scene signals at runtime.

Every triggered effect carries an origin chain ID and chain depth or equivalent
safety metadata. Reduced secondary proc rates, cooldowns, per-step budgets,
resource consumption, and authored chain-depth limits may control cascades. A
Super Bloom chain should appear self-sustaining at high power without creating
an actual infinite same-frame loop or starving input and UI.
Thornburst uses an Inspector-authored cooldown, while Briar Pods use a fixed
preallocated pool and finite lifetime, providing equivalent safety for the two
Bramble pair evolutions.

## Rendering and readability

`TerritoryRenderer` receives read-only field output and owns:

- continuous border reconstruction and interpolation;
- player, hostile, and neutral material presentation;
- element-specific surface texture, density, and motion;
- maturity cues such as density, roots, saturation, or texture;
- infection veins, suppression zones, growth wind-ups, and damage feedback;
- debug modes for control, maturity, pressure, infection, resistance, masks,
  dirty regions, and topology identifiers.

Use packed buffers and batched texture updates rather than a Node, Sprite, or
physics body per sample. Decorative splatter, particles, ripples, distortion,
and short-lived bodies can amplify an event, but removing every decorative
effect must leave gameplay results unchanged.

Ownership and threats must remain legible at peak density. Do not rely only on
hue: borders, texture, motion, and iconography should continue to distinguish
player, hostile, neutral, Fresh growth, temporary catalysts, infection, and
hostile cores under heavy combat VFX.

## Performance contract

The prototype must establish a representative stress fixture before optimizing
the algorithm. Measure field update, metrics, topology, renderer upload, enemy
territory queries, and total frame time separately.

- Store field channels in compact packed arrays or images; never allocate one
  engine object per field sample.
- Reuse command, scratch, event, and query buffers across steps.
- Track changed bounds or spatial chunks if full-field work exceeds budget.
  Optimization must not introduce seams or change command results at chunk edges.
- Recompute static arena masks only when arena geometry changes.
- Amortize aggregate metrics and topology where play does not require every-step
  results, while keeping the Territory % HUD responsive and trustworthy.
- Pool frequently spawned enemies, projectiles, pickups, Seed/Bloom entities,
  and visual effects. Avoid instantiate/free churn inside combat loops.
- Cache node references and authored definitions. Do not use scene-tree searches
  or string dispatch in simulation, AI, or per-frame combat paths.
- Target a responsive 60 fps frame budget on supported target hardware and
  profile the dense prototype case before expanding content scope.

A higher-resolution or GPU-backed field is not inherently better. Choose the
lowest resolution and simplest backend that produces convincing continuous
deformation, accurate player-facing percentages, deterministic rules, and the
required performance on target hardware.

## Persistence and versioning

Meta progression never needs the live territory field. If suspended-run saving
is implemented, serialize semantic field channels, run RNG state, stable entity
IDs, pending commands, fixed-step time, and schema/algorithm version—not GPU
handles, scene nodes, material resources, or a screenshot of the rendered
territory. Loading must reproduce the same next authoritative step.

Changes to field encoding, resolution, phase order, ownership rules, or topology
IDs require a migration or an explicit policy that older suspended runs cannot
resume. Loading a save never grants closed-time Biomass.

## Prototype verification contract

The Phase A territory sandbox must verify:

1. Green, hostile, and neutral regions form a stable continuous frontier in one
   fixed-screen arena.
2. Slow baseline expansion into neutral space is tunable and reproducible.
3. Bloom pressure behaves differently in open ground, on a hostile frontier, in
   a choke point, inside an enclosure, and against a weak pocket.
4. Seed growth injects thicker, lower-impulse mass than Bloom.
5. A Grazer can erode a channel and split one region into real fragments.
6. Fragments remain owned and follow explicit size/element decay rules.
7. Continuous maturity increases resistance without changing survival area.
8. Player, hostile, and neutral percentages are accurate, stable, and cheap to
   publish.
9. Debug views explain control, pressure, maturity, resistance, infection, and
   conversion without relying on final art.
10. Deformation, splatter, pressure, and recovery remain readable and satisfying
    at the agreed stress load.

Sporekeeper must additionally verify that Cane/Adaptation deaths, baseline Seeds, Spore,
Bloom, Bramble, a small relic pool, all three available pairing evolutions
claimed from the level-up draft, XP, and Biomass interact through the documented
boundaries. Automated tests should
cover path commitment and filtering, frontier contact damage/slow/resistance,
Briar Pod lifetime and Thornburst cooldown, deterministic command
streams, frame-rate independence, edge masks, conversion, fragment topology,
maturity, metrics, chain limits, renderer non-authority, save round trips, and
representative performance probes.

Prototype measurements decide the open values. Update authored definitions and
record the decision in the GDD or a decision log; do not bury a newly locked
rule inside `TerritoryField`.
