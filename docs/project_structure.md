# Sporekeeper project structure

This guide defines the intended layout for Sporekeeper, the Godot implementation
of the fixed-screen territory-control survivor game in the Territory Survivor
GDD. Create folders when their first files are added rather than committing
empty directories. Choose a location by responsibility, data lifetime, and
dependency direction—not by the first screen that happens to use a file.

The repository currently contains the design baseline, the preserved Phase A
territory lab, and a playable Sporekeeper Godot 4.7 prototype using the GL
Compatibility renderer. The structure below remains the target for production
growth; some prototype responsibilities are intentionally consolidated while
their contracts are being validated.

The GDD's Section 21 Unity assumption predates the actual project scaffold. For
this repository, `project.godot` is the engine source of truth and Godot 4.7 is
the implementation baseline; the GDD remains authoritative for gameplay and
content design. If the engine decision changes, update the GDD, project, and
these architecture documents together.

## Intended layout

**This tree is the target, not an inventory.** Roughly a third of the directories in it
do not exist, because the content they are for does not: there is one arena, one boss,
no pickup scenes and no authored objectives, and creating the folders early would put
empty directories in the tree to satisfy a document. A folder here is a decision about
where something goes *when it is built* - which is what makes it useful the day it is.

What is built today is `src/core/` entire - `entities`, `models`, `nodes`, `rules` and
`persistence`, with all six rule domains - along with `tests/`, `tools/`, `scripts/`,
and the parts of `scenes/` and `data/` that have content. `tools/check_structure.gd`
enforces the direction that matters: everything that exists must be described here, so
a new folder cannot appear without a line saying what belongs in it.

```text
assets/                         Imported source assets and shared presentation
  audio/                        Music, ambience, combat, territory, and UI cues
  fonts/                        Font source files
  materials/                    CanvasItem materials and shared palettes
  shaders/                      Territory surface, borders, distortion, and VFX
  textures/
    arenas/                     Backgrounds, masks, and permanent obstacles
    elements/
      shared/                   Shared elemental presentation
      plant/                    Plant territory, paths, weapons, and effects
    enemies/                    Roles, elites, bosses, and hostile territory
    pickups/                    XP and reward presentation
    ui/                         HUD, draft, Biomass, objective, and menu art
  ui/                           Imported UI art, shared Godot themes, and the
                              StyleBoxTexture resources that dress the panels,
                              buttons, slots and bars
data/                           Authored Resource instances; no mutable run state
  arenas/                       Geometry, masks, spawn regions, and tuning
  elements/
    shared/                     Framework defaults and common stat vocabulary
    plant/
      paths/                    Spore, Bloom, Bramble, Root, Pruning
      upgrades/                 Four numeric stat lines per Plant path
      relics/                   Universal, path, cross-path, and legendary relics
      evolutions/               The fifteen Plant path-pair evolutions
      weapons/                  Cane and element-level combat definitions
  enemies/                      Roles, variants, elite modifiers, and bosses
  objectives/                   Optional wave-objective definitions and rewards
  progression/                  Unlocks, collection entries, and difficulty data
  waves/                        Timelines, compositions, previews, and bosses
docs/                           GDD, composition rules, architecture, and guides
scenes/                         Godot composition resources grouped by feature
  app/                          Boot, menus, collection, settings, and transitions
  run/                          Run root and fixed-screen gameplay composition
  arenas/                       Arena geometry and authored encounter anchors
  territory/                    Field, renderer, metrics, and debug overlays
  player/                       Movement, HP, targeting, and automatic weapons
  elements/
    shared/                     Reusable element/path/relic effect adapters
    plant/                      Seeds, Blooms, Plant effects, and presentation
  enemies/
    shared/                     Movement, combat, targeting, and common feedback
    roles/                      Hunter, Grazer, Saboteur, Corruptor, Colonizer, Warden
    bosses/                     Burrower, Hive Queen, and future bosses
  pickups/                      XP and run-reward pickups
  ui/
    hud/                        Territory %, player HP, Biomass, wave, and build
    drafts/                     Upgrade, path, relic, and evolution choices
    menus/                      Main, pause, settings, collection, and results
    objectives/                 Optional objective status and rewards
  vfx/                          Non-authoritative reusable presentation scenes
scripts/                        Maintenance, validation, import, and test runners
                              (`run_tests.ps1` discovers and runs every test)
src/core/
  entities/                     Serializable mutable state; no scene references
    meta/                       What the player keeps when a run ends
                              (`meta_record.gd`: finished runs, victories, bests)
    run/                        A run in progress, as `run_snapshot.gd` - identity
                              plus one state dictionary per system that owns some
  models/                       Resource classes for immutable authored definitions
    arenas/                     Bounds, masks, spawn regions, and arena metadata
    combat/                     Damage, weapon, projectile, and targeting definitions
    economy/                    Biomass, wager, and Clover-machine vocabulary
    elements/                   Element, path, territorial mechanic, and stat schemas
    enemies/                    Role, variant, elite, and boss definitions
    progression/               Upgrade, relic, evolution, unlock, and reward schemas
                              (`relic_catalog.gd` is the authored relic table)
    run/                        Mode, launch intent, authored text, and counters
                              (`run_mode.gd` and `run_launch.gd` carry the menu's
                              two choices into the run scene)
    territory/                 Field tuning, effect shapes, and material profiles
    waves/                      Wave, objective, composition, and timeline schemas
  nodes/                        Scene-bound typed components
    app/                        Application and scene-transition lifetime
    arena/                      Geometry masks and fixed-screen arena adapters
    combat/                     Hits, damage, deaths, targeting, and projectiles
    economy/                    Biomass runtime and Ecosystem Metabolism
    elements/                   Shared element runtime plus Plant implementation
    enemies/                    Agents, roles, spawning, elites, and bosses
    player/                     Movement intent, health, and automatic weapon adapters
    progression/               XP draft, paths, relics, evolution, meta adapters
                              (`relic_director.gd` runs triggered relics,
                              `evolutions.gd` owns every Evolution and its tuning)
    run/                        Run root, outcome, event routing, and orchestration
    territory/                  Field, command queue, metrics, topology, and renderer
    ui/                         HUD, menus, drafts, objectives, and view models
    waves/                      Wave timeline, previews, breaks, and objectives
  rules/                        Pure or scene-independent game rules
    combat/                     Damage, targeting, and navigation calculations
    economy/                    Biomass income, costs, and reward settlement
    elements/                   Path mechanics that resolve without a node:
                              rate zones, standing regions, and amplification
    progression/               Draft pools, slot rules, eligibility, unlocks, and
                              the text the interface prints about any of them
    territory/                 Field operations, ownership, maturity, and infection
    waves/                      Objective evaluation and composition selection
  persistence/                 Save schema, migrations, settings, and serialization
                              (`settings_store.gd` owns `user://settings.cfg`,
                              `save_store.gd` owns `user://save.dat`)
tests/
  fixtures/                     Setup helpers and the shared pass/fail ledger
  integration/                  Headless scene, simulation, and complete-loop suites
    smoke/                      One topic each of the run-wide smoke suite
  performance/                  Field, renderer-upload, query, and enemy-load probes
  unit/                         Pure rules, definitions, state, and schema tests
tools/                          Offline checks and asset bakes; no runtime code
                              (`shadowed_names.gd` also runs inside the smoke suite;
                              `check_structure.gd` enforces this document)
```

## Dependency direction

Authored scenes compose `src/core/nodes/`. Nodes may use `rules`, `entities`,
`models`, and `persistence`; models and pure rules must not depend on nodes,
scenes, UI, rendering resources, or autoload singletons. `data/` contains
instances of model Resources and may reference presentation assets explicitly,
but it contains no mutable state from a run.

Keep named `.gd` runtime code under `src/core/` and matching `.tscn` composition
under `scenes/`. Avoid embedded scene scripts: named scripts are searchable,
testable, and reusable. Assets and documentation contain no hidden runtime rules.

The central direction is:

```text
authored data -> pure rules and serializable state -> scene-bound nodes -> UI/VFX
```

Events and read-only snapshots may travel outward. Player intent and typed
commands may travel inward through public interfaces. UI, VFX, enemies, relics,
and objectives do not receive writable territory buffers.

## Where new files belong

Static authored content belongs in `data/<domain>/` as `.tres` resources backed
by schema classes in `src/core/models/<domain>/`. For example, a
`RelicDefinition` names eligibility, rarity, description, and a stable effect
identifier. It does not find the player, subscribe to live signals, or mutate a
run. A scene adapter resolves that identifier through an explicit effect
registry owned by the relevant system.

Mutable values that must survive scene replacement or run suspension belong in
`src/core/entities/`. Entity state contains stable identifiers and serializable
values, never nodes, callables, signals, textures, or direct Resource ownership.

The live owner of that state is still its node: `Progression` holds the selected
paths, line levels, relic ids and evolution state while a run is being played,
and hands them over through `capture_state` and `apply_state`. The entity is the
*saved* form - `RunSnapshot` assembles one dictionary per system and knows what
is in none of them. Each system stays the authority on which of its fields are
the run and which are the build's authored tuning, which is a question only that
system can answer.

Rules that do not need the scene tree belong in `src/core/rules/`. This includes
draft eligibility, weighted offers, upgrade-slot constraints, evolution
eligibility, Biomass curves, objective checks, reward settlement, resistance
calculation, and deterministic territory-cell operations. Keeping these rules
pure allows the build and simulation contracts to be tested without rendering.

Anything that reads player input, processes a Godot callback, owns an engine
physics body, draws, uploads a texture, plays audio, or adapts a rule to a live
scene belongs in `src/core/nodes/<capability>/`. Put its composition scene under
the matching `scenes/<feature>/` folder.

Presentation-only effects belong under `scenes/vfx/` and `assets/`. A splash,
particle, ripple, or temporary Rigidbody may visualize an authoritative event,
but gameplay code never samples it to decide ownership, pressure, damage,
rewards, or objectives.

## Territory system placement

The continuous territory world deliberately spans several layers:

- `models/territory/` defines field resolution, fixed-step tuning, channel
  semantics, effect shapes, and element material profiles.
- `rules/territory/` owns deterministic local operations for mass, pressure,
  erosion, conversion, maturity, resistance, and Plant Infection.
- `nodes/territory/territory_field.gd` owns authoritative packed field buffers
  and applies a buffered command stream at a fixed simulation step.
- `nodes/territory/territory_metrics.gd` derives player, hostile, and neutral
  area plus maturity-weighted summaries without duplicating ownership rules.
- `nodes/territory/territory_topology.gd` owns controlled fragment and colony
  detection at an appropriate cadence.
- `nodes/territory/territory_renderer.gd` converts read-only field output into
  textures, continuous frontiers, element materials, and debug views.
- the field's saved state is the per-cell arrays that carry history, captured by
  `territory_field.gd` itself into the `field` dictionary of a `RunSnapshot`.
  Masks, topology, metrics and the projection are derived and recomputed on load
  rather than stored, so a save cannot hold an answer that disagrees with the
  cells it came from.

Do not move territory ownership into shaders, collision bodies, arena code,
enemy agents, the HUD, or an element controller. The complete design and
extension contract is in `docs/territory_simulation_architecture.md`.

## Shared framework and element content

The run framework is shared across elements: fixed-screen arena, continuous
territory, movement-only input, automatic attacks, personal HP, Territory %,
waves, 13 Adaptation-line slots, two-path commitment, relic rewards, one pairing
evolution, Biomass, objectives, and meta progression.

Each element is a content package within that framework. Plant supplies its own
starting weapon, baseline Seed mechanic, six paths, twenty-four path stat lines,
relic pools, fifteen evolutions, presentation, and any element-specific field
layer such as Infection. Shared code must use element definitions and contracts;
it must not branch on `if element == plant` merely because Plant is built first.

Place reusable element mechanics in `shared/`. Put Plant-only names, scenes,
definitions, and visuals in `plant/`. Future Fire, Lightning, Ice, or other
elements may have entirely different verbs and do not need Plant-shaped Seeds,
Blooms, colonies, or infection.

## Waves, objectives, and enemies

Wave definitions describe timing, composition, previews, elites, bosses, and
breaks. Enemy role definitions remain element-agnostic. Optional objectives
observe published events or metrics and settle rewards through progression;
they do not inspect arbitrary scene nodes or become loss conditions.

Keep director logic separate:

- the wave director decides what should spawn and when;
- the spawn service creates pooled agents at arena-approved locations;
- enemy agents select and pursue targets according to their role;
- combat resolves hits and deaths;
- territory effects resolve Grazer erosion, Corruptor conversion, Colonizer
  growth, Warden suppression, and boss field actions;
- an optional adaptive director may choose authored compositions from current
  Territory %, but it does not secretly scale unrelated systems.

## Persistence

Persistence code belongs in `src/core/persistence/`. Settings, meta progression,
collection discoveries, difficulty state, and any supported suspended-run save
are separate documents with independent schema versions. Persist stable IDs and
plain values. Never serialize live nodes, signal connections, rendering handles,
or wall-clock timestamps as a way to grant Biomass while the game is closed.

## Tests

Mirror each architectural boundary under test:

- Unit-test ownership resolution, maturity, resistance, infection, area
  aggregation, deterministic command ordering, Biomass income and costs, six-slot
  drafting, path commitment, relic eligibility, evolution readiness, objectives,
  unlocks, and save migrations.
- Integration-test fixed-screen arena composition, player movement and automatic
  attacks, Seed/Bloom/Bramble effects, Grazer fragmentation, territory and
  player-HP loss conditions, wave breaks, rewards, two-path commitment, all
  three implemented Plant pair evolutions, final invasion, domination cleanup,
  and results persistence.
- Performance-test field steps, texture updates, topology analysis, cached
  territory queries, pooled combat effects, and representative enemy density.
  Profile on supported target hardware and preserve a responsive 60 fps frame
  budget under the agreed prototype stress case.
- Verify that changing visual material, particles, display resolution, or frame
  rate does not change authoritative area, maturity, damage, or rewards.

Run every test with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1 -Filter "save_*" -SkipPerformance
powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1 -ListOnly
```

The runner imports once, then runs the static checks and every script under `tests/`
that `extends SceneTree` - so a new probe is picked up by existing, and a topic module
or fixture is skipped without being listed anywhere. Probes that call `get_texture`,
`save_png` or `Input.warp_mouse` are given a real window, because those block forever
under `--headless`; the rest run headless. A hung probe is killed at
`-TimeoutSeconds` and reported as a timeout rather than holding the run.

The current Sporekeeper composition is `scenes/run/run.tscn`. Its
visible `GameplayComponents` children own audio settings, progression, the
Ecosystem Metabolism economy, wave direction, and Plant behavior; `CombatDirector/EnemyProfiles` owns nine
Inspector-editable profiles: all six core roles, the Colonizer's Colony Core,
the elite Rootbreaker, and the Burrower boss. Player, combat, and territory
tuning lives on the component that consumes it rather than in one cross-system
run Resource. The prototype offers Spore, Bloom, and Bramble at its primary
path milestone and then locks one different secondary path. Bramble's cached
frontier, thorn development, and resistance remain authoritative in
`TerritoryField`, while `CombatDirector` resolves contact damage, slow,
repulsion, and pooled Briar Pod boundaries.
The Phase A comparison fixture remains available at
`scenes/run/territory_prototype.tscn`. See `docs/run_composition.md` for the
complete node tree, editing guide, controls, implemented scope, and verification.

## Adding to the game

Start with `docs/sporekeeper_composition_conventions.md` to identify the owner,
then use this guide to place its definition, state, rule, adapter, scene, assets,
and tests. Consult `docs/Territory_Survivor_Game_Design_Document.docx` for locked
game rules and `docs/territory_simulation_architecture.md` for spatial behavior.
Create a new top-level folder only for a genuinely new architectural category,
not for one feature that can live inside an existing domain.
