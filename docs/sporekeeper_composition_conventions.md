# Sporekeeper composition conventions

Sporekeeper is the Godot project for the fixed-screen elemental territory-control
survivor game described by the Territory Survivor GDD. Scenes are composition
roots: they assemble small, typed nodes and wire collaborators through exported
Inspector references. A component owns one reason to change; roots coordinate
the order in which components act.

The complete arena is active and visible throughout a run; gameplay does not
switch to an offscreen or background production model. The authoritative world
is the continuous territory field plus ordinary gameplay entities. Visual
particles and shaders may exaggerate that world, but they never decide
territory ownership, damage, rewards, or progression.

## Core rules

- Give reusable behavior a `class_name` so it is an actual Godot type.
- Store scene-bound components as authored children rather than creating a
  hidden subsystem graph inside one controller.
- Instance a self-contained region of the tree as its own scene once it has a
  script's worth of rules of its own. The run scene should say where a region
  sits and what it is wired to; the region's own scene says what it contains.
- A sub-scene reports intent upward with typed signals and takes narrow commands
  downward. A parent that reaches through a sub-scene into its grandchildren has
  gained a file and kept the coupling.
- A sub-scene that needs a collaborator from the parent scene is handed it once,
  through an explicit `setup()` the parent calls from its own `_ready`. Do not
  author a NodePath that climbs out of a scene to find one.
- Use typed `@export` references for collaborators and UI elements. Avoid `$`,
  `get_node()`, group searches, and string paths in gameplay code.
- Expose narrow commands, immutable results, and typed signals. Do not reach
  into another component's private state or mutable buffers.
- Keep authored definitions, mutable run state, pure rules, simulation buffers,
  and presentation separate. They have different lifetimes and test needs.
- Put designer-facing tuning on the definition or component that consumes it.
  The GDD's numerical examples remain prototype targets, not hidden constants.
- Measure cooldowns, income, maturation, waves, and effects in simulation time,
  never frames. Rendering frame rate must not rebalance the run.
- Keep fixed-step gameplay deterministic enough to reproduce a seed and command
  stream. Random choices come from owned random-number sources, not global calls
  scattered through nodes.
- Keep autoloads rare. Only application state or services that truly survive
  scene replacement belong there; a run's systems live under its run root.
- Biomass is earned during an active run. Loading a save must not invent offline
  income unless a later design decision explicitly introduces that feature.

## Authoritative territory boundary

`TerritoryField` is the only component allowed to mutate authoritative spatial
territory data. Abilities, enemies, relics, objectives, and bosses submit typed
effect commands; none receives writable access to field arrays or textures.

- The field owns control, maturity, and any enabled effect layers such as Plant
  Infection, along with the arena's unclaimable mask.
- Mass, pressure, erosion, conversion, and infection are gameplay operations.
  Their final values and exact equations are prototype tuning, but their meaning
  must stay stable across abilities and elements.
- The simulation advances at a fixed cadence with bounded catch-up work. It
  processes a buffered command set in a stable phase order, publishes results,
  and only then exposes the new state to consumers.
- `TerritoryMetrics` derives player, hostile, and neutral area percentages and
  maturity-weighted area from field snapshots. UI and economy code consume
  those metrics rather than scanning the field independently.
- A sampled array or texture is an implementation detail, not a tile-based game
  rule. Frontiers must read as continuous and react to arena geometry, pressure,
  resistance, and nearby material.
- `TerritoryRenderer` turns field snapshots into organic borders, deformation,
  splatter, ripples, and element-specific materials. Decorative particles and
  physics bodies never feed results back into the gameplay field.
- Expensive topology such as fragments and colonies is calculated by one owned
  service at a controlled cadence. Other systems consume stable fragment or
  colony identifiers rather than performing their own flood fills.
- Enemies use cached or batched territory queries. Hundreds of agents must not
  perform arbitrary per-pixel reads every rendered frame.

The field remains the single source of truth even if prototyping changes its
resolution or moves some work between CPU arrays and texture-backed passes.
See `docs/territory_simulation_architecture.md` for the full contract.

## Run update order

`RunRoot` coordinates, but does not implement, this order:

1. Sample player intent and move the player.
2. Update automatic targeting, weapons, enemies, and direct combat.
3. Resolve deaths and gameplay triggers into typed events and territory-effect
   commands.
4. Advance fixed territory steps and publish field deltas and metrics.
5. Advance waves, objectives, Biomass, build progression, and win/loss checks
   from the published results.
6. Present the resulting state through HUD, animation, audio, and visual effects.

Systems may queue work for a later phase; they must not force another system to
run recursively. This is especially important for relic chains and evolutions,
which should look explosive without producing unbounded same-tick loops.

## Feature boundaries

- **Application** owns boot, menus, settings, save selection, and transitions
  into and out of a run. It does not retain live run nodes.
- **Run** composes the arena, territory simulation, player, combat, enemy and
  wave directors, build systems, Biomass economy, objectives, HUD, and outcome
  evaluation. `RunRoot` coordinates those peers but owns none of their rules.
- **Arena** owns fixed-screen geometry, spawn regions, unclaimable masks, and
  authored encounter anchors. It does not decide current ownership or wave
  composition.
- **Territory simulation** owns the spatial field and physical-looking frontier
  response. It reports area, topology, and typed territorial events; it does not
  grant XP, Biomass, relics, or victory.
- **Territory effects** translate an authored ability or enemy action into field
  commands. Plant Seeds, Blooms, Grazer trails, boss ruptures, and similar
  mechanics use the same command boundary instead of editing pixels directly.
- **Player** owns movement and personal HP. The player controller expresses
  movement intent; automatic weapons and targeting are separate components.
- **Combat** owns hit resolution, damage, death, XP drops, and combat targeting.
  A death event may trigger an elemental mechanic, but combat does not decide
  how that mechanic changes territory.
- **Elements** are content packages over shared run contracts. An element owns
  its starting weapon, baseline territorial behavior, six paths, stat lines,
  relic catalog, evolutions, definitions, and presentation. Plant is the first
  reference package, not logic hard-coded into shared systems.
- **Enemy ecosystem** owns the element-agnostic Hunter, Grazer, Saboteur,
  Corruptor, Colonizer, and Warden roles plus elites and bosses. Roles select
  targets and issue actions; shared combat and territory systems resolve them.
- **Waves** own the authored timeline, composition, previews, breaks, elites,
  bosses, and final invasion. A wave director does not change player upgrades or
  territory buffers directly.
- **Optional objectives** observe published run events and metrics. They report
  completion once and hand a typed reward request to progression; failure never
  becomes a run-loss condition.
- **Upgrade drafting** owns XP, one-of-three offers, six occupied upgrade-line
  slots, line levels, and Primary/Secondary path commitment. Upgrade definitions
  describe numeric modifiers; draft UI only sends selection intent.
- **Relics** are binary, non-slotted rule modifiers. They subscribe to explicit
  domain events or decorate rule inputs; they do not poll the scene tree.
  `RelicCatalog` is the authored table - identity, rarity, pool, mechanic
  requirements, and player text - and is pure data with no scene dependencies, so
  drafting, the HUD, and the tests all read the same rows. `RelicDirector`
  owns the runtime of every *triggered* relic: its counters, cooldowns, per-wave
  flags, and the persistent world objects a relic leaves in the arena. A relic
  that is only a rule parameter is never simulated there; it is pushed once, when
  the relic set changes, into whichever component already owns that rule, so Core
  Weapon rules stay in combat, HP rules stay on the player, and field rules stay
  in the field. Eligibility is expressed as required Mechanics rather than as
  path pairs, so a relic unlocks the moment the run can actually do the thing it
  needs, whether that came from the initial pair, the support path, or an
  Evolution. Every relic trigger is a fixed counter, a per-object limit, local
  enemy density, or an absolute amount of territory - never a percentage of the
  arena. Any loop where one relic can feed another carries at least one limiter:
  a generation cap, a global cooldown, a per-object limit, or an explicit source
  that cannot re-trigger the effect that produced it.
- **Evolution** owns pairing eligibility and the single active evolution. Maxing
  one line from each selected path marks `EVOLUTION READY`, and the upgrade draft
  then offers the pairing as a choice until the player claims it.
- **Biomass economy** consumes territory and maturity metrics, accumulates the
  run currency as a Reserve, and exposes production, consumption, and net income.
  It has no writable access to territory. There is no repeatable purchase shop:
  `Metabolism` allocates a small number of discrete points across
  Photosynthesis (Mass), Meristem (Pressure), and Cambium (Cohesion), draws
  Biomass out of the Reserve at a rate set by that allocation, levels each system
  automatically on an exponential cost curve, and offers one behavioural
  Breakthrough per system. Those three are physical parameters of the simulation,
  so Metabolism reports multipliers and the run root pushes them into the field.
  Overgrow spends a share of the Reserve as one injection of Mass, Pressure, and
  Cohesion into the living frontier and lets the simulation decide the outcome.
- **Run survival** combines the two independent failure layers. Player HP and
  Territory % keep separate owners; the run director evaluates their reported
  state, including any eventual territory grace-period rule.
- **Meta progression** owns unlocks, discoveries, collection data, difficulty,
  and low-cap permanent modifiers. It never mutates a live run behind the run
  configuration boundary.
- **UI** presents read-only view models and sends explicit player intent. The HUD,
  draft screen, Biomass panel, wave preview, objective display, and collection
  screens do not edit simulation or entity state directly.
- **Persistence** serializes stable identifiers and data values, never live node
  references or rendering resources. Save schema, migrations, settings, meta
  progression, and any supported suspended-run snapshot remain separate.

When adding a feature, extend the component that owns its responsibility or add
a sibling and wire it at the nearest composition root. Do not grow `RunRoot`,
`TerritoryField`, or the player controller merely because they can reach most of
the game.

## Sporekeeper reference composition

The playable Sporekeeper scene demonstrates this convention directly. Its run root
coordinates `AudioSettings`, `Progression`, and `WaveDirector` under
`GameplayComponents`, and every Plant path under a single `Paths` parent:
`SporeDirector`, `BloomDirector`, `BrambleDirector`, `RootDirector`, and
`PruningDirector`. Each path owns its own component rather than sharing one Plant
director, so a path's tuning, its derived values, its evolutions, and the signals
it listens to all live together and are found in one place.

`Progression` keeps what belongs to the run rather than to a path: levels, draft
and reroll state, path commitment, relics, evolution status, and the Biomass
economy. A path's numbers live on that path's component, which reads levels back
from `Progression`. Root's Biomass yield therefore arrives at `tick_biomass` as an
argument instead of `Progression` reaching into a path, and a component that needs
another path's amplification holds a reference to it: both Spore and Bloom read
the Root Network from `RootDirector`, and Bloom reads Entanglement potency from
`BrambleDirector`. Bramble and Root own no entities and have no cadence, so their
components own tuning and apply their rules to the field and combat rather than
simulating anything themselves. `Player`, `TerritoryField`,
and `CombatDirector` remain peers because each owns a separate simulation
boundary. Enemy archetypes are typed children under
`CombatDirector/EnemyProfiles`, where designers can change combat statistics,
targeting priority, navigation clearance, and territory behavior without
editing a script. The current tree exposes Hunter, Grazer, Saboteur, Corruptor,
Colonizer, Warden, Colony Core, Elite Rootbreaker, and Burrower profiles. The
four specialist introduction times and pack cycles remain on `WaveDirector`
because they are encounter scheduling rather than archetype behavior.

Plant path timing also remains on `WaveDirector`, while `Progression` owns the
primary/secondary commitment that path upgrades can settle on their own,
upgrade drafts that stay wide until both paths are committed, four Bramble lines,
four Root lines,
and pairing evolution state. `TerritoryField` publishes Bramble coverage over
owned Green, the cached frontier with its per-cell hedge development, one
harvest command for mechanics that consume Bramble, and development-scaled
Bramble resistance for enemy field commands. `CombatDirector` consumes both for
thorn chip damage, Entanglement, crossing hits, Grasping Roots, Repulsion, root eruptions,
and the pooled Briar Pod and Briar Trap entities. `SporeDirector` turns Seed
germination into Briar Pods for Spore/Bramble, and `BloomDirector` turns a
Bloom's harvest into Briar Traps for Bloom/Bramble. The shader only visualizes thorned ground; it does not
decide any Bramble gameplay result.

Keep future tuning beside the component that reads it. Add a field to an enemy
profile when it changes one archetype, to `CombatDirector` when it changes
shared combat resolution, to `WaveDirector` when it changes spawn scheduling,
or to the director of the path it belongs to: `SporeDirector` for Seeds, Briar
Pods, and the Seed Bank, `BloomDirector` for Blooms, Thornburst, and Flowering
Season, and `PruningDirector` for the harvest, Cuttings, and the orbiting
ring. A pairing evolution
lives with the path whose mechanic it changes, which is why Super Bloom's chain
depth sits on `BloomDirector` even though a Seed arms it. Avoid
reintroducing a single run-tuning Resource that couples those owners together.
The interface is being pulled out of the run scene one region at a time. Five
regions have moved - the pause menu, the slot cabinet, the draft panel, the enemy
roster and the run's audio - taking the run scene from 163 authored nodes to 101
and the run root from 86 exported references to 52. The remaining region, the
Adaptation tree, waits on its description logic moving to `src/core/rules/`.

`Interface/PauseMenu` is instanced from `scenes/ui/menus/pause_menu.tscn` and owns
the pause panel, the settings page, the volume and fullscreen controls, and the
dev-control card, along with the authored wording for all of them. It reports
`opened`, `closed`, `settings_toggled`, `glossary_requested`, `main_menu_requested`
and `quit_requested`; the run root decides what each of those costs the run,
because what pausing means - which simulations stop - is a run rule and not a
menu's business. `MechanicsHelp` deliberately did not move with it: the same
tooltip stack serves HUD and reward hovers that have nothing to do with pausing,
so it stays owned by the run root and the menu asks for the glossary rather than
opening it.

See `docs/run_composition.md` for the exact authored tree and Inspector map.
