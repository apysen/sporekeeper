# Sporekeeper Performance Optimization Implementation Guide
## Godot 4 high-density combat, Thistle tail-latency, and TerritoryField optimization

**Status:** Proposed implementation plan  
**Based on:** August 30, 2026 authoritative implementation state and peak-density profiling  
**Primary objective:** Raise sustainable enemy density above the current 130-enemy cap without sacrificing combat readability, Adaptation power, or territory fidelity  
**Frame target:** 60 FPS, with **p99 simulation frame time under 16.67 ms** at the target density  
**Recommended density milestones:** 160 -> 200 -> 250 -> 300 concurrent enemies

---

# 1. Why this work is needed

The current performance profile does **not** look like a game that has reached a fundamental rendering or simulation ceiling.

The August 30 peak-density probe shows:

- Median simulation frame time is healthy across all Adaptation pairings: roughly **3.4 to 9.0 ms**.
- The remaining problem is **tail latency**, experienced as periodic stutter rather than sustained low FPS.
- Twelve of 28 Adaptation pairings remain over the 16.67 ms p99 budget at the current 130-enemy cap.
- Every failing pairing contains **Thistle or Fruit**.
- **Thistle:** about 4 to 5 ms median, around 11 ms p95, and 10 to 30 ms spikes on volley cadence.
- **Fruit:** about 15 ms in the Adaptation director and raises TerritoryField cost from a baseline around 8.4 ms to roughly 12 to 16 ms because of repeated Green trail writes.
- Worst current rows:
  - Thistle + Fruit: about **34.8 ms p99**
  - Thistle + Vine: about **30.0 ms p99**
- Root already demonstrated the value of structural optimization:
  - old behavior: per-enemy flood fill
  - new behavior: one field-wide cached projection
  - Root + Fruit combat p99 improved from roughly **40.9 ms to 3.95 ms**

The Root result is the model for the rest of this work.

The goal is **not** to visually simplify Thistle, reduce Fruit count, reduce enemy count, or weaken late-game builds. The goal is to replace repeated high-level work with shared, cached, batched, or data-oriented work.

---

# 2. Research basis

The implementation direction is based on several relevant examples.

## 2.1 Godot's own high-object-count guidance

Godot documents that the SceneTree is convenient but has additional memory and processing overhead compared with direct server APIs. For very large quantities of simple objects, Godot recommends lower-level Server and RID approaches.

Godot's official **Bullet Shower** demo manages 500 bullets centrally without representing each bullet as a normal scene node. The demo explicitly exists to demonstrate that large quantities of 2D objects can be managed more efficiently with low-level APIs.

Godot also recommends **MultiMesh** for efficiently rendering very large numbers of repeated visual instances. For a few thousand simple instances, GDScript is generally sufficient, while `RenderingServer.multimesh_set_buffer()` and GDExtension become options for much larger workloads.

## 2.2 Vampire Survivors

The original Vampire Survivors implementation became heavily CPU-bound in late-game combat. The developer specifically identified physics calculations on a single CPU core as the primary bottleneck rather than the raw amount being drawn. The engine migration reportedly produced roughly a tenfold benchmark performance increase.

The relevant lesson for Sporekeeper is that a screen full of sprites is not automatically the expensive part. Physics, collision, target searches, per-object callbacks, and repeated gameplay queries can dominate.

## 2.3 Risk of Rain 2

Risk of Rain 2 deliberately limits one dimension of combat complexity. Its Director systems use spawning budgets and, under normal conditions, stop spawning when the map is overcrowded. Difficulty can continue increasing through enemy quality, elite tiers, and spawn-credit decisions instead of allowing every dimension of simulation complexity to grow without bound.

Sporekeeper should use the same general principle while targeting a much higher raw 2D population:

> Allow visual enemy density to scale aggressively, but keep expensive simulation dimensions bounded.

Examples include:

- maximum candidate count per targeting query
- maximum ricochet target searches
- maximum expensive AI decisions per second
- maximum secondary proc recursion
- bounded territory dirty regions
- capped heavy specialist population

## 2.4 Nintendo ink-territory patent

A Nintendo patent describing ink-based territory rendering represents the world drawing state with a persistent texture covering the play area and uses GPU operations and a stencil buffer to write team ownership. It also describes compact "drawing events" from which the larger drawing state can be reconstructed.

This is not source code for Splatoon and should not be treated as proof of the exact shipping implementation. It is still highly relevant architectural evidence:

> Represent territory as persistent field state and apply compact paint operations to it, rather than repeatedly rebuilding large amounts of geometry or high-level objects.

For Sporekeeper, that maps naturally to:

- a compact CPU gameplay field
- a persistent GPU visual field
- batched paint commands such as circles, capsules, lines, splats, and washes

---

# 3. Performance principles for Sporekeeper

These rules should govern the entire optimization pass.

## 3.1 Preserve gameplay before preserving implementation

Do **not** solve performance by:

- reducing Thistle's visible thorn count
- lowering Crown of Thorns volley size
- reducing Fruit Set
- removing ricochets
- visually deleting enemies
- lowering the Campaign enemy cap
- making territory trails thinner solely for performance
- dropping gameplay relic procs when the system is overloaded

Those change the game to fit the current architecture.

Instead, make the architecture support the game.

## 3.2 Separate simulation from presentation

A visual object does not automatically need to be a gameplay Node.

Examples:

- A thorn can look like a projectile while being one record in a packed projectile array.
- A Grazer can look fully animated while its state is one index in `EnemyManager`.
- A Fruit trail can look continuous while gameplay territory is updated in coarser cells.
- Thirty Crown thorns can appear to launch simultaneously while expensive secondary calculations are distributed across several frames during their travel time.

## 3.3 Share work across objects

Any query that asks the same world-level question repeatedly should immediately be suspicious.

Bad:

```text
for every thorn:
    scan every enemy

for every Fruit:
    update territory immediately

for every enemy:
    perform its own large territory search
```

Preferred:

```text
build one spatial index
share it across combat systems

collect one frame of territory paint operations
apply them as a batch

calculate one reusable field result
query it cheaply
```

## 3.4 Optimize p99, not only average frame time

The current median is already healthy.

Every benchmark must report:

- median
- p95
- p99
- maximum frame time
- number of frames above 16.67 ms
- number of frames above 25 ms
- number of frames above 33.33 ms

For Thistle specifically, also record frame time relative to the nearest volley event.

---

# 4. Target architecture

The long-term architecture should move toward this:

```text
                           SPOREKEEPER

                       CombatSimulation
                              |
          +-------------------+-------------------+
          |                   |                   |
     EnemyManager       ProjectileManager   TerritoryManager
          |                   |                   |
          |                   |                   |
    packed enemy data     packed thorns      CPU gameplay grid
          |                   |                   |
          +---------+---------+                   |
                    |                             |
               SpatialGrid                TerritoryWriteBatch
                    |                             |
          +---------+---------+                   |
          |         |         |                   |
       Thistle    Fruit     Vine/Bloom      GPU visual painter
          |                                           |
    MultiMesh /                                  persistent
    centralized draw                           territory texture
```

Complex specialists can remain normal Godot scene objects initially.

The largest population classes should become data-oriented first.

---

# 5. Phase 0: establish a non-negotiable benchmark harness

Do this before changing architecture.

The existing `peak_density_probe.gd` is a strong base. Expand it rather than replacing it.

## 5.1 Add density sweep modes

Run every important test at:

```text
130 enemies
160 enemies
200 enemies
250 enemies
300 enemies
```

Do not immediately make 300 the shipping target.

Each optimization phase should unlock the next benchmark density only when the lower one is stable.

## 5.2 Required benchmark fixtures

At minimum:

### A. Generic enemy saturation

- no Adaptations
- no relics
- worst representative role mix
- test 130 through 300 enemies

Purpose: establish base enemy-system scaling.

### B. Maximum Thistle

- evolved three-Adaptation run
- Thistle fully ranked
- worst Thistle relic package
- enough enemies to maintain target saturation
- include Crown of Thorns, Burr, Pincushion, Phyllotaxis, Forking Pattern, Thorn Relay, and any Evolution effects that increase thorn workload

Purpose: isolate volley p99.

### C. Maximum Fruit

- fully ranked Fruit
- 16 Fruit release case
- continuous Green trail writing
- enemies crossing the painted region
- territory maturity and control writes enabled

Purpose: isolate TerritoryField writes.

### D. Thistle + Fruit

This remains the most important torture test because it combines both current bottlenecks.

### E. Thistle + Vine

Preserve this because it is currently one of the worst p99 combinations and exercises high-frequency geometric collision alongside Thistle volleys.

### F. Root + Fruit regression

This should remain permanently in the suite to make sure new Territory work does not regress the successful Root projection optimization.

## 5.3 Add custom timing buckets

Add explicit timing around:

```text
enemy_manager_total_ms
enemy_movement_ms
enemy_ai_ms
enemy_separation_ms
enemy_territory_ms

spatial_grid_build_ms
spatial_grid_query_ms
spatial_grid_candidates_total
spatial_grid_candidates_max

thistle_total_ms
thistle_targeting_ms
thistle_projectile_update_ms
thistle_collision_ms
thistle_ricochet_ms
thistle_relic_logic_ms
thistle_visual_submission_ms
thistles_fired
thorn_segments_resolved
thorn_candidate_checks

territory_total_ms
territory_enqueue_ms
territory_batch_ms
territory_cells_touched
territory_unique_cells_changed
territory_duplicate_cell_writes
territory_visual_paint_ms

fruit_total_ms
fruit_collision_ms
fruit_trail_enqueue_ms
fruit_trail_segments

generated_events_enqueued
generated_events_processed
generated_events_dropped_cosmetic
```

Do not rely only on the Godot profiler for these. Keep game-specific counters in automated probes so results can be compared commit to commit.

## 5.4 Save benchmark output in machine-readable form

Recommended CSV columns:

```text
git_commit
build_type
renderer
resolution
density
adaptation_a
adaptation_b
support
relic_fixture
median_ms
p95_ms
p99_ms
max_ms
frames_over_16_67
frames_over_25
frames_over_33
subsystem_name
subsystem_median_ms
subsystem_p99_ms
```

This makes regressions visible instead of anecdotal.

---

# 6. Phase 1: build one shared 2D spatial grid

This is the highest-priority shared optimization.

Thistle should be the first consumer, but the grid should be designed for every combat system.

## 6.1 Why a uniform grid fits Sporekeeper

Sporekeeper has:

- one fixed on-screen arena
- many similarly sized enemies
- many local-radius queries
- many projectiles
- many AoEs
- no huge streaming open world

That is almost the ideal case for a uniform spatial hash/grid.

A quadtree is probably unnecessary initially.

## 6.2 Recommended cell size

Start with:

```text
64 px
```

Benchmark:

```text
48 px
64 px
80 px
96 px
```

The best cell size is the one that minimizes:

```text
grid rebuild cost + candidate filtering cost
```

Do not choose it aesthetically.

## 6.3 Data layout

Prefer indexed arrays over Dictionaries of objects.

Example:

```gdscript
class_name CombatSpatialGrid

var cell_size: float = 64.0
var columns: int
var rows: int

# One PackedInt32Array or reusable Array[int] per cell.
var cells: Array[PackedInt32Array]

# Enemy data remains authoritative in EnemyManager.
var enemy_manager: EnemyManager
```

For maximum performance, avoid allocating new arrays during every query.

Use a reusable query buffer:

```gdscript
var query_buffer := PackedInt32Array()
```

or caller-owned scratch buffers.

## 6.4 Rebuild once per simulation tick

Pseudo-flow:

```gdscript
func rebuild(enemy_positions: PackedVector2Array) -> void:
    clear_counts_without_reallocating()

    for enemy_id in enemy_positions.size():
        var cell := world_to_cell(enemy_positions[enemy_id])
        insert(enemy_id, cell)
```

The first implementation can use arrays per cell.

If allocation or clearing becomes expensive, move to a flat linked/indexed representation:

```text
cell_heads[cell_index]
next_enemy[enemy_index]
```

This avoids rebuilding many dynamic arrays.

## 6.5 Query APIs

Implement only a small set of optimized primitives.

```gdscript
query_circle(center, radius, out_ids)
query_aabb(rect, out_ids)
query_capsule(start, end, radius, out_ids)
query_nearest(center, radius, max_candidates, exclusions, out_ids)
```

Important:

`query_nearest()` should have a **hard candidate budget**.

Example:

```text
MAX_THISTLE_TARGET_CANDIDATES = 16
MAX_BURR_TARGET_CANDIDATES = 12
MAX_VINE_SEGMENT_CANDIDATES = 24
```

The spatial query can stop after gathering enough valid local candidates rather than examining every enemy in every overlapping cell.

## 6.6 Deduplication

A large enemy can appear in multiple cells only if you choose multi-cell insertion.

Prefer one-cell insertion by enemy center initially.

Then enlarge the search region by the maximum enemy radius.

That avoids per-query duplicate removal.

## 6.7 Acceptance gate

At 130 enemies:

- grid rebuild p99 under **0.25 ms**
- normal local query median candidate count under **20**
- no combat system performs full-array target scans in ordinary operation
- all current gameplay collision/target-selection regression tests pass

Then rerun at 200 enemies.

---

# 7. Phase 2: eliminate Thistle volley spikes

This should be the first major combat optimization.

The goal is not merely lower average Thistle cost.

The goal is:

> Remove the p99 spike synchronized with volleys.

## 7.1 Instrument one volley end to end

For each volley, log:

```text
volley_id
source_thistle_count
initial_thorn_count
ricochet_segments
forked_segments
candidate_checks
unique_targets_hit
hit_events
kill_events
relic_events
CPU time from launch to final scheduled result
worst single-frame CPU time
```

This will reveal whether the spike is mostly:

- target acquisition
- projectile spawning
- Area2D/physics collision
- ricochet search
- event signaling
- relic bookkeeping
- VFX
- all of the above at once

## 7.2 Replace per-thorn global targeting

Never allow:

```gdscript
for enemy in all_enemies:
    ...
```

inside a thorn.

At fire time:

```gdscript
var candidates := spatial_grid.query_nearest(
    thistle_position,
    acquisition_radius,
    MAX_THISTLE_TARGET_CANDIDATES
)
```

Do that **once per Thistle volley**, not once per thorn.

Then distribute targets.

Example:

```text
six thorns
12 candidate enemies

thorn 0 -> candidate 0
thorn 1 -> candidate 1
thorn 2 -> candidate 2
...
```

Clustering rules can intentionally assign several thorns to the same target.

## 7.3 Cache target packets briefly

A Thistle does not need a fresh expensive target query every simulation frame.

Recommended target-packet lifetime:

```text
0.10 to 0.20 seconds
```

Invalidate early if:

- target died
- target became invalid
- target moved outside a generous validity radius
- gameplay explicitly requires retargeting

This reduces repeated target search while preserving responsive behavior.

## 7.4 Convert thorns to pure-data projectiles

Target architecture:

```gdscript
class_name ThistleProjectileManager

var positions: PackedVector2Array
var previous_positions: PackedVector2Array
var velocities: PackedVector2Array
var damage: PackedFloat32Array
var source_ids: PackedInt32Array
var target_ids: PackedInt32Array
var ricochets_left: PackedByteArray
var flags: PackedInt32Array
var alive: PackedByteArray
```

Do not create one node per thorn.

Avoid for ordinary thorns:

- `Area2D`
- `CollisionShape2D`
- `_physics_process()`
- per-thorn `Timer`
- per-thorn signals
- per-thorn SceneTree lifecycle

Manage them in one update loop.

## 7.5 Use swept collision against spatial candidates

Fast projectiles should use the segment from:

```text
previous_position -> current_position
```

Query a capsule/AABB around that segment from the shared spatial grid.

Then run a cheap geometric test against those candidates.

For a circular enemy collider:

```text
distance from enemy center to projectile segment <= enemy_radius + thorn_radius
```

This prevents tunneling without requiring a Godot physics body for every thorn.

## 7.6 Ricochets must be local and bounded

When Burr triggers:

1. Start at the impact position.
2. Query only nearby spatial cells.
3. Gather at most `MAX_BURR_TARGET_CANDIDATES`.
4. Exclude invalid or already-hit enemies according to Burr's actual rules.
5. Pick the best target.
6. Continue.

Never rescan all enemies.

Recommended initial bound:

```text
MAX_BURR_TARGET_CANDIDATES = 12
```

If this changes targeting in edge cases, increase to 16 before changing gameplay rules.

## 7.7 Add per-projectile hit history cheaply

Do not allocate a Dictionary or Set per thorn.

If a thorn only needs to remember a handful of ricochet targets, use a small fixed array:

```text
hit_0
hit_1
hit_2
hit_3
hit_4
hit_5
```

or one reusable packed buffer per active projectile slot.

The maximum history size is already naturally bounded by ricochet count.

## 7.8 Aggregate Thistle hit results

Instead of emitting many gameplay signals during the projectile loop, append compact results:

```gdscript
struct-like data:
    enemy_id
    source_id
    damage
    flags
```

Conceptual buffers:

```text
damage_events[]
kill_candidates[]
pincushion_increments[]
network_trigger_counts[]
```

Then process them in batches after projectile movement.

This avoids deep call chains such as:

```text
thorn hit
 -> signal
 -> enemy damage
 -> signal
 -> relic director
 -> signal
 -> adaptation director
 -> spawn secondary thorn
```

Prefer:

```text
simulation produces event records
 -> event processor resolves bounded consequences
```

## 7.9 Store timed states as timestamps

For lightweight Thistle status effects such as Pincushion expiry:

Bad:

```text
one Timer node per enemy/status
```

Preferred:

```gdscript
enemy.pincushion_expires_at = simulation_time + duration
```

Check only when:

- the enemy is updated
- a thorn hits it
- the status is rendered
- a relevant gameplay query occurs

## 7.10 Micro-stagger computation while preserving visual simultaneity

This is specifically useful for Crown and other synchronized volleys.

The player should still see all thorns leave together.

However, secondary calculations can be assigned across the projectile's travel frames.

Example:

```text
frame N:
  visually launch all 30
  resolve planning/collision slice 0

frame N+1:
  resolve slice 1

frame N+2:
  resolve slice 2
```

At 60 FPS, two extra frames are about 33 ms.

Because the projectile already takes time to travel, this can be visually indistinguishable if scheduled correctly.

Important:

- Do not delay an impact past the frame in which the visual projectile reaches it.
- Do not alter damage timing enough to change player outcomes.
- Use this only for work that can be computed before the visible impact.

## 7.11 Optional: pre-plan thorn routes

If Thistle projectiles are sufficiently fast and target-seeking behavior is simple, a volley can build a short route plan:

```text
thorn A:
  target 52 -> ricochet 17 -> ricochet 83

thorn B:
  target 9 -> ricochet 22
```

The visual projectile then follows the already-selected route.

Revalidate each target before impact:

- if alive and valid, use planned hit
- otherwise perform one bounded local retarget query

This turns repeated collision/retarget work into occasional exception handling.

Do not implement this until the simpler manager + spatial-grid approach is measured.

## 7.12 Render thorns in one batch

Use either:

- `MultiMeshInstance2D`, if it fits the current thorn art pipeline
- one centralized `_draw()` implementation
- low-level `RenderingServer` canvas items if profiling shows the SceneTree renderer path remains significant

Keep projectile simulation independent from projectile rendering.

## 7.13 Thistle acceptance gate

At 130 enemies with the maximum-Thistle fixture:

- Thistle subsystem median under **5 ms**
- Thistle subsystem p95 under **8 ms**
- Thistle subsystem p99 under **10 ms**
- full simulation p99 under **16.67 ms**
- fewer than **3 frames over budget per 600**
- Crown remains visually simultaneous
- Burr, Pincushion, Forking, Phyllotaxis, and Evolution behavior match baseline gameplay

Then test 160 and 200 enemies.

---

# 8. Phase 3: redesign TerritoryField writes around batching

Fruit is telling us that **number of Fruit entities is not the main problem**.

Do not reduce Fruit count.

The expensive behavior is repeated field mutation.

## 8.1 Introduce TerritoryPaintCommand

Every system that changes field control should stop mutating the field directly.

Instead, enqueue commands.

Example:

```gdscript
enum PaintShape {
    CIRCLE,
    CAPSULE,
    LINE,
    POLYGON,
    WASH
}

class TerritoryPaintCommand:
    var shape: PaintShape
    var start: Vector2
    var end: Vector2
    var radius: float
    var owner: int
    var strength: float
    var source: int
    var flags: int
```

Fruit trails naturally become `CAPSULE` commands.

Bloom becomes a `CIRCLE` or radial command.

Seed occupation can become a circle or small patch command.

Enemy corruption becomes the same interface with a different owner.

This gives the entire game one write pipeline.

## 8.2 Collect writes for the whole simulation tick

Flow:

```text
Fruit updates
 -> enqueue commands

Bloom detonates
 -> enqueue commands

Enemies graze/corrupt
 -> enqueue commands

Seeds spread
 -> enqueue commands

end of field-write phase
 -> TerritoryManager applies batch
```

Do not immediately:

- invalidate topology
- recalculate percentage
- invalidate Root projection
- update visual texture

after every individual stamp.

## 8.3 Coalesce overlapping dirty regions

Track the field cells affected by the entire command batch.

Use a reusable dirty bitset:

```gdscript
var dirty_cells := PackedByteArray()
var dirty_indices := PackedInt32Array()
```

When a cell becomes dirty for the first time this tick:

```gdscript
dirty_cells[cell_id] = 1
dirty_indices.append(cell_id)
```

Repeated Fruit passes over the same cell do not add it again.

After the batch:

```text
process final changed cells once
clear only dirty_indices
```

This avoids clearing the entire dirty array every frame.

## 8.4 Separate "cells touched" from "cells changed"

A paint command may overlap 500 cells but only change 80.

Track both.

```text
territory_cells_touched
territory_unique_cells_touched
territory_cells_actually_changed
```

Expensive downstream invalidation should depend on **actual changes**, not overlap tests.

## 8.5 Invalidate caches once per batch

Current Root projection uses `_field_revision`.

Keep that architecture.

But instead of incrementing the revision for every Fruit stamp:

```text
apply all commands
if any gameplay cell actually changed:
    field_revision += 1
```

If systems need mid-tick consistency, define explicit simulation phases:

```text
1. movement
2. attacks
3. enqueue territory writes
4. apply territory batch
5. territory-dependent queries
6. cache build on demand
```

This is better than allowing arbitrary field reads halfway through an incomplete write batch.

## 8.6 Fruit trail representation

Fruit should emit a swept capsule from its previous position to its current position:

```text
start = previous_position
end = current_position
radius = trail_radius
```

This gives a continuous trail even if Fruit moves farther than the trail radius in one frame.

Do not place many tiny circle stamps along the path unless the visual system specifically needs them.

One capsule can replace many overlapping circles.

## 8.7 Update territory percentage incrementally

Do not rescan the field.

When a cell changes owner:

```gdscript
owner_counts[old_owner] -= 1
owner_counts[new_owner] += 1
```

Territory percentage becomes:

```gdscript
float(owner_counts[PLAYER]) / playable_cell_count
```

This should be nearly free.

## 8.8 Make maturity lazy or event-driven

Do not update every owned cell's maturity every frame.

Preferred model:

```text
cell_owned_since
cell_maturity_modifier
```

Calculate maturity when queried:

```gdscript
maturity = maturity_function(sim_time - owned_since, modifiers)
```

If the current design requires discrete maturity transitions, maintain a queue/bucket of cells whose next transition is pending.

Example:

```text
maturity bucket at t+1.0 s
maturity bucket at t+2.0 s
```

Fully mature cells require no continuous update until disturbed.

## 8.9 Dirty topology only when topology-relevant state changes

Not every territory write should force every derived cache to rebuild.

Split revision counters if useful:

```text
control_revision
maturity_revision
topology_revision
visual_revision
```

Then:

- Root mature projection depends on control + maturity
- simple ownership percentage depends only on control deltas
- visual painter depends on visual commands
- topology analysis may depend only on specific ownership transitions

This prevents unrelated changes from invalidating expensive caches.

## 8.10 Territory batching acceptance gate

At 130 enemies with maximum Fruit:

- TerritoryField p99 below **8 ms**
- Fruit + Territory combined p99 below **12 ms**
- duplicate write ratio is measured and reduced substantially
- 16-Fruit release remains no slower than required by visible trail coverage
- Root projection regression test remains exact
- territory percentage and maturity results match baseline

Then test 160 and 200 enemies.

---

# 9. Phase 4: separate CPU gameplay territory from GPU visual territory

Do this only after CPU batching is implemented and measured.

The CPU field should remain authoritative for gameplay.

The GPU representation is presentation.

## 9.1 CPU gameplay field

Use a resolution chosen for gameplay accuracy, not visual smoothness.

Example target options for a 1600 x 900 arena:

```text
4 px cells:
400 x 225 = 90,000 cells

8 px cells:
200 x 113 = about 22,600 cells
```

Benchmark actual gameplay sensitivity before changing resolution.

Store compact data:

```text
owner
maturity/state bits
strength if required
timestamps or indices into auxiliary arrays
```

Prefer packed arrays over per-cell objects.

Possible layout:

```gdscript
var owner := PackedByteArray()
var maturity_state := PackedByteArray()
var owned_since := PackedFloat32Array()
var strength := PackedFloat32Array()
```

If a value is not required for every cell, store it separately or derive it.

## 9.2 Persistent SubViewport visual painter

First GPU prototype:

- create one SubViewport matching the chosen visual territory texture resolution
- set transparent background as appropriate
- use `CLEAR_MODE_NEVER`
- update only when paint commands exist
- draw batched paint primitives into it
- display the resulting ViewportTexture on the arena

The viewport texture persists rather than being cleared every frame.

This is a good first implementation because it is much simpler than compute shaders.

## 9.3 Visual commands

The CPU paint batch can also emit presentation commands:

```text
visual capsule
visual splat
visual Bloom wash
visual corruption stamp
```

These do not need to be one-to-one with CPU cells.

The CPU field may be coarse.

The GPU output can be smooth.

## 9.4 Avoid CPU texture readback

Do **not** make gameplay depend on reading the visual territory texture back from the GPU each frame.

The CPU grid is authoritative.

GPU readback introduces synchronization and can destroy the benefit of offloading visual painting.

## 9.5 Optional compute-shader path

Only explore this if SubViewport painting remains a proven bottleneck.

Godot compute shaders:

- require a RenderingDevice renderer such as Forward+ or Mobile
- have weaker reliability on some mobile GPU/driver combinations
- require careful RID lifecycle management
- should avoid immediate `sync()` calls that stall the CPU waiting for GPU completion

Possible compute path:

```text
CPU creates compact paint-command buffer
 -> upload command buffer
 -> compute shader applies stamps to territory image
 -> render image directly
```

Do not move authoritative gameplay territory to GPU unless there is an extremely strong reason.

That would make gameplay queries, determinism, debugging, and readback more complicated.

## 9.6 GPU territory acceptance gate

Measure in an actual rendered build.

Requirements:

- visual territory painting below **1.5 ms p99 CPU submission cost**
- no visible trail gaps
- no loss of border readability
- no frame hitch from viewport updates
- gameplay field and visual field remain perceptually aligned
- renderer-specific test on every intended renderer/platform

---

# 10. Phase 5: centralize generic enemy simulation

Do this after Thistle and Territory are under control.

Otherwise changing enemies at the same time makes profiling difficult.

## 10.1 Hybrid architecture first

Do **not** immediately convert every enemy.

Keep full Nodes for:

- bosses
- Warden
- Siege Corruptor
- unusually complex scripted enemies
- enemies whose unique behavior is easier to maintain as a scene

Convert high-population generic roles first.

Likely candidates:

- basic Grazer
- Rusher
- other simple fodder roles

## 10.2 Enemy data-oriented layout

Target:

```gdscript
class_name EnemyManager

var active_count: int

var positions: PackedVector2Array
var previous_positions: PackedVector2Array
var velocities: PackedVector2Array

var hp: PackedFloat32Array
var max_hp: PackedFloat32Array

var radius: PackedFloat32Array
var role: PackedByteArray
var variant: PackedByteArray
var state: PackedByteArray
var flags: PackedInt32Array

var attack_cooldown: PackedFloat32Array
var ai_next_update: PackedFloat32Array
var territory_next_update: PackedFloat32Array

var pincushion_stacks: PackedByteArray
var pincushion_expiry: PackedFloat32Array
```

Avoid one Dictionary per enemy.

Avoid object references in hot loops where integer IDs work.

## 10.3 Stable IDs and slot reuse

Use integer enemy IDs.

When an enemy dies:

- mark slot free
- add index to a free list
- reuse it for the next spawn

Do not continuously resize large packed arrays during combat.

Alternative:

- compact active arrays by swap-removing the dead entry
- update external ID mapping

Choose whichever best fits current targeting references.

## 10.4 Separate cheap and expensive updates

Every enemy does not need every behavior at 60 Hz.

Recommended initial schedule:

```text
position integration:             60 Hz or 30 Hz
collision with player/walls:      60 Hz where necessary
generic steering:                 20 to 30 Hz
target/path decisions:            10 to 20 Hz
enemy-enemy separation:           20 to 30 Hz
territory evaluation/grazing:     10 to 20 Hz
status expiry checks:             on update or interaction
specialist strategic logic:       role-specific, often 10 to 20 Hz
```

Use interpolation for visuals when simulation is below render rate.

## 10.5 Stagger AI phases

Do not let all 250 enemies reconsider AI on the same frame.

Assign an update bucket when spawned:

```text
enemy_id % AI_BUCKET_COUNT
```

Example with 4 buckets:

```text
frame 0 -> bucket 0
frame 1 -> bucket 1
frame 2 -> bucket 2
frame 3 -> bucket 3
```

At 60 FPS, each bucket is still updated 15 times per second.

Movement can continue every frame from the most recent steering result.

This is a direct way to reduce p99 spikes.

## 10.6 Replace enemy-enemy physics with local separation

Do not require full physics-body collision among all generic enemies unless gameplay depends on exact collision.

Use the shared spatial grid.

For each enemy at its separation update:

1. inspect own and adjacent cells
2. gather a bounded set of nearest neighbors
3. accumulate a separation vector
4. apply limited displacement/steering

Example:

```gdscript
for neighbor_id in spatial_grid.query_circle(pos, separation_radius):
    if neighbor_id == self_id:
        continue

    var delta := pos - enemy_positions[neighbor_id]
    var distance_sq := delta.length_squared()

    if distance_sq < desired_spacing_sq:
        separation += normalized_or_safe(delta) * weight
```

Bound the number of processed neighbors.

Generic crowd overlap can be approximate.

Preserve accurate collision only for gameplay-critical interactions.

## 10.7 Walls and obstacles

If the arena walls are static:

- precompute a collision/signed-distance or occupancy representation if practical
- use cheap local resolution for generic enemies
- reserve PhysicsServer2D bodies for interactions that need them

Do not build a complex navigation solution if enemies mostly need local steering around a fixed one-screen arena.

## 10.8 Damage processing

Batch incoming damage by enemy ID each simulation slice where possible.

Example:

```text
damage_accumulator[enemy_id] += damage
```

Then resolve:

```text
hp -= accumulated_damage
if hp <= 0:
    queue death
```

Preserve ordering only where ordering affects gameplay.

Crit numbers and hit VFX can still be emitted individually or aggregated visually.

---

# 11. Phase 6: batch enemy rendering

The August 30 enemy-art bake makes this especially attractive.

## 11.1 MultiMesh by compatible visual group

Use a small number of `MultiMeshInstance2D` batches.

Potential grouping:

```text
Grazer batch
Rusher batch
Heavy Grazer batch
other role batches
```

If atlas/material design allows it, compatible roles can share a batch.

Pass per-instance information through:

- transform
- color
- custom data

Custom data can encode:

```text
variant
animation frame
elite flag
hit flash
infection/overgrown amount
facing
```

A shader selects the correct atlas region and overlay state.

## 11.2 Allocate maximum instance count once

Example:

```text
MAX_GENERIC_ENEMIES = 320
```

Allocate once.

Update:

```text
visible_instance_count = active_count
```

Avoid reallocating the MultiMesh each spawn/despawn.

## 11.3 Bulk buffer update

Start with normal per-instance setters.

Profile.

If submission becomes hot, move toward:

```text
RenderingServer.multimesh_set_buffer()
```

with one packed buffer update per batch.

Godot documentation specifically notes that a GDExtension/C++ path can build the entire linear MultiMesh state efficiently and upload it in one call.

Do not jump to C++ until profiling justifies it.

## 11.4 Preserve important overlays

The current baked enemy art already has shared state overlays.

Do not reintroduce many child nodes for:

- hit flash
- overgrown
- infection marker
- elite tint

Prefer shader/custom-data overlays where possible.

Warden and Siege Corruptor can remain on the current specialized rendering path initially.

## 11.5 Enemy-rendering acceptance gate

In an actual rendered 300-enemy test:

- enemy rendering CPU submission cost should not scale linearly like hundreds of independent draw objects
- enemy visuals remain readable
- hit flash remains visible
- infection marker remains visible
- role silhouette remains clear
- no role silently falls back to generic geometry at high density
- no frame hitch during large spawn/death bursts

---

# 12. Phase 7: centralize gameplay events and eliminate signal storms

The current generated-event scheduler already bounds relic recursion well.

Extend the same idea to high-frequency combat events.

## 12.1 Event buffers

Examples:

```text
DamageEvent
KillEvent
TerritoryWriteEvent
ThistleHitEvent
KnockbackEvent
PickupSpawnEvent
CosmeticEvent
```

Hot loops append compact records.

Dedicated processors resolve them at deterministic points.

## 12.2 Distinguish gameplay from cosmetics

Gameplay events must never be silently dropped for performance.

Safe to shed or coalesce under extreme load:

- duplicate impact particles
- small debris
- repeated tiny hit flashes
- overlapping sound instances
- redundant floating damage numbers

Unsafe to drop:

- damage
- territory conversion
- projectile hits
- relic gameplay procs
- enemy deaths
- healing
- Root interactions

## 12.3 Coalesce cosmetic output

Examples:

Instead of 35 identical thorn impact particles in one 20 px area:

```text
spawn 8 stronger impact particles
```

Instead of 20 identical impact sounds in one frame:

```text
play one sound with intensity derived from hit count
```

This preserves perceived intensity while bounding presentation cost.

---

# 13. Phase 8: physics-server and RID migration only where useful

Do not convert the entire project to raw RIDs.

Use them where a profiling hotspot proves the SceneTree is the issue.

Good candidates:

- simple projectile collision bodies
- large quantities of generic enemies if custom collision is still needed
- repeated low-level visual objects

Poor candidates:

- Grandma
- complex bosses
- UI
- one-off interactables
- systems that are already comfortably under budget

Important Godot rule:

If an object already has a Node representation, avoid trying to control the same server object simultaneously through a separate RID architecture. Create low-level objects explicitly as low-level objects.

Always manage RID lifetimes carefully.

---

# 14. Phase 9: GDExtension fallback

GDExtension should be a **late optimization**, not Phase 1.

The likely C++ candidates are very narrow:

```text
spatial-grid rebuild/query
enemy packed-array update
thorn swept-collision loop
territory command rasterization
MultiMesh buffer packing
```

These are excellent native-code candidates because they:

- are tight loops
- operate on contiguous data
- have simple inputs/outputs
- can avoid SceneTree access
- can potentially be threaded

Do not move gameplay architecture into C++ just to make a bad algorithm faster.

The order is:

```text
better algorithm
 -> better data layout
 -> fewer allocations
 -> batching
 -> lower update frequency
 -> native code if still needed
```

---

# 15. Allocation policy

Frame-time spikes in managed gameplay code are often caused by allocation churn even when average CPU time looks acceptable.

During combat hot paths, avoid:

```text
new Array every query
new Dictionary every projectile
temporary object for each hit
creating/freeing nodes during volleys
string construction in gameplay loops
dynamic signal connection/disconnection
frequent packed-array resizing
```

Prefer:

```text
preallocated pools
free lists
reusable scratch arrays
integer IDs
fixed-size small hit histories
ring buffers
dirty-index lists
```

Add a debug counter:

```text
combat_dynamic_allocations
```

Even if exact allocation instrumentation is difficult, track known object/pool expansions.

A pool expansion during a torture fixture should be treated as a warning.

---

# 16. Threading strategy

Do not start by multithreading everything.

Godot SceneTree objects are not generally something to mutate freely from worker threads.

Good future worker-thread tasks include pure-data work:

- build part of the spatial grid into thread-local buffers
- prepare MultiMesh transform/custom-data arrays
- evaluate generic AI steering from snapshots
- rasterize territory command coverage into temporary buffers
- build candidate packets

Then apply results on the main simulation thread.

Important:

- no worker should mutate authoritative arrays while another system reads them
- use clear simulation snapshots or double buffers
- benchmark synchronization overhead
- at 200 to 300 enemies, algorithmic fixes may make threading unnecessary

---

# 17. Recommended simulation schedule

A possible final 60 FPS frame:

```text
FRAME START

1. player input
2. Grandma movement
3. Vine Verlet update

4. generic enemy movement integration
5. scheduled enemy AI bucket
6. scheduled enemy separation bucket

7. rebuild shared spatial grid

8. Adaptation fire decisions
9. Thistle projectile manager
10. Fruit simulation
11. Bloom / Bramble / Pruning / Spore logic

12. aggregate combat events
13. resolve damage / deaths / knockback

14. collect territory commands
15. apply TerritoryWriteBatch
16. increment relevant field revisions once
17. resolve territory-dependent effects

18. generated relic event slice

19. build enemy visual instance buffers
20. build thorn visual instance buffer
21. submit visual territory paint commands

FRAME END
```

The exact order should preserve current gameplay semantics.

The important change is that each high-frequency subsystem has one defined phase instead of recursively triggering arbitrary work throughout the frame.

---

# 18. Enemy-density progression plan

Do not simply change:

```text
MAX_ENEMIES = 130
```

to 300.

Raise the cap only after benchmark gates.

## Milestone A: 160 enemies

Required:

- all 28 pairings p99 under 16.67 ms in headless simulation
- Thistle p99 fixed
- no TerritoryField outlier above budget
- actual rendered test remains close to 60 FPS

## Milestone B: 200 enemies

Required:

- generic saturation full-frame p99 under 12 ms headless
- Thistle + Fruit full-frame p99 under 16.67 ms
- no more than 1 percent of frames over budget in rendered torture test
- no major visual downgrade

If this passes, **200 becomes the recommended new Campaign cap**.

## Milestone C: 250 enemies

Attempt after enemy-manager and render batching work.

Required:

- normal Campaign builds remain under budget
- worst torture builds may approach budget but cannot produce obvious rhythmic stutter
- role readability remains acceptable

## Milestone D: 300 enemies

Treat this as a stretch target.

Do not compromise gameplay quality just to display "300" in a benchmark.

If 250 feels visually saturated and technically stable, that may be the correct shipping cap.

---

# 19. Campaign spawning after the cap rises

A higher cap should not mean "spawn maximum enemies immediately."

Keep the existing pressure system, but allow concurrency to continue scaling farther into the run.

Suggested first test curve:

```text
0:00      35 target concurrent
1:30      70
3:00      110
4:30      145
6:00      175
7:30      200
boss      pressure/composition peak
```

Exact values require playtesting.

The purpose is to stop the Campaign from reaching its concurrency ceiling at 4.5 minutes and then staying pinned there.

After the chosen cap is reached, continue increasing difficulty through:

- specialist composition
- elite frequency
- enemy speed
- territory damage
- attack pattern interaction
- formation pressure
- role synergy

Do not continue increasing every cost dimension at once.

---

# 20. Thistle-specific implementation checklist

## Target acquisition

- [ ] Remove all full-enemy-array target scans from thorn logic.
- [ ] Query shared spatial grid.
- [ ] Query once per Thistle volley where possible.
- [ ] Cache candidate packets for 0.10 to 0.20 seconds.
- [ ] Bound candidate count.

## Projectile representation

- [ ] Replace thorn nodes with manager-owned data.
- [ ] Preallocate projectile capacity for worst legal build.
- [ ] Use slot reuse/free list.
- [ ] Use swept segment collision.
- [ ] Remove per-thorn timers.
- [ ] Remove per-thorn signals.

## Burr

- [ ] Local query at impact.
- [ ] Maximum 12 to 16 candidates.
- [ ] Fixed-size hit history.
- [ ] No global retarget scans.

## Volley spikes

- [ ] Add `volley_id`.
- [ ] Profile candidate checks per volley.
- [ ] Profile projectile spawn work.
- [ ] Profile relic/event work.
- [ ] Micro-stagger precomputable work.
- [ ] Preserve simultaneous visual launch.

## Relic logic

- [ ] Aggregate hit events.
- [ ] Process Pincushion as compact enemy state.
- [ ] Preserve current recursion/source-tag rules.
- [ ] Never drop gameplay events.
- [ ] Coalesce only presentation effects.

## Rendering

- [ ] Centralized draw or MultiMesh.
- [ ] No one-Sprite2D-per-thorn requirement.
- [ ] Batch hit VFX.
- [ ] Batch audio.

---

# 21. Fruit and Territory-specific implementation checklist

## Fruit

- [ ] Keep 6 -> 11 -> 16 Fruit scaling unchanged.
- [ ] Emit one swept capsule trail command per Fruit movement segment.
- [ ] Do not place many tiny CPU Green stamps along the same path.
- [ ] Batch all Fruit writes for the tick.
- [ ] Measure duplicate touched cells.

## TerritoryField

- [ ] Central `TerritoryManager`.
- [ ] `TerritoryPaintCommand` API.
- [ ] Dirty-cell bitset.
- [ ] Dirty-index list.
- [ ] Apply actual changes once.
- [ ] Increment owner totals incrementally.
- [ ] Invalidate derived caches once per relevant batch.
- [ ] Split revision counters if useful.
- [ ] Avoid whole-field iteration in normal frames.

## Maturity

- [ ] Replace continuous field-wide maturation with timestamp/lazy logic or transition queues.
- [ ] Mature cells cost nothing until disturbed.
- [ ] Root projection cache remains exact.

## Visual territory

- [ ] Persistent SubViewport prototype.
- [ ] Clear mode Never.
- [ ] Update only when paint commands exist.
- [ ] No gameplay GPU readback.
- [ ] Compute shader only if profiling proves necessary.

---

# 22. Enemy-system implementation checklist

## Generic data

- [ ] Convert one simple role first.
- [ ] Integer stable IDs.
- [ ] Packed arrays.
- [ ] Preallocated capacity.
- [ ] No hot-loop Dictionary-per-enemy access.
- [ ] No Timer nodes for simple cooldowns.

## Update scheduling

- [ ] Movement at appropriate high frequency.
- [ ] AI at 10 to 30 Hz.
- [ ] Separation at 20 to 30 Hz.
- [ ] Territory decisions at 10 to 20 Hz.
- [ ] Stagger enemy update buckets.

## Collision

- [ ] Spatial-grid local separation.
- [ ] Bound neighbor count.
- [ ] Preserve accurate player and important hazard collisions.
- [ ] Remove generic enemy-enemy physics where not gameplay-critical.

## Rendering

- [ ] MultiMesh prototype for one role.
- [ ] Atlas baked variants.
- [ ] Instance custom data for visual states.
- [ ] Fixed capacity.
- [ ] Update visible instance count.
- [ ] Bulk buffer only if profiling requires it.

---

# 23. Regression risks

## 23.1 Determinism/order changes

Batching damage or territory writes can alter outcomes if the old system depended on execution order.

Before batching, document rules for:

- simultaneous kills
- overkill
- on-hit vs on-kill
- territory overwrite priority
- maturity timing
- multiple teams/sources painting the same cell during one tick

Define deterministic tie-breaking.

Example:

```text
sort by simulation phase
then command priority
then source ID
```

Only add sorting if actual gameplay semantics require it because sorting itself has a cost.

## 23.2 Visual/gameplay territory mismatch

CPU and GPU fields can disagree visually if commands are transformed differently.

Create a debug overlay that can show the CPU territory grid over the rendered Green.

Include a test mode:

```text
F9: toggle CPU ownership-cell outlines
```

## 23.3 Projectile tunneling

Replacing physics projectiles with data projectiles requires swept collision.

Never use only current-position point tests for fast thorns.

## 23.4 MultiMesh state bugs

Common risks:

- stale transforms in unused slots
- wrong visible-instance count
- incorrect atlas variant
- stale hit flash/custom data
- incorrect facing

Add a visual stress probe for every enemy role.

## 23.5 Pool exhaustion

A legal build should never silently fail because a projectile/event pool is too small.

When a pool exhausts in debug:

```text
push_error()
record telemetry
grow once if allowed
```

Then increase the configured legal capacity.

Shipping behavior should not lose gameplay events.

---

# 24. Validation probes to add

Keep all existing probes and add:

## `spatial_grid_probe.gd`

Tests:

- same results as brute-force query for randomized enemy layouts
- boundary cells
- enemies exactly on cell edges
- circle/capsule query correctness
- nearest-query correctness within configured candidate bounds
- no duplicate IDs

## `thistle_volley_probe.gd`

Records:

- volley thorn count
- ricochet count
- candidate checks
- p95/p99 frame time
- output damage compared with baseline
- target sequence validity

## `thorn_collision_reference_probe.gd`

Run old and new collision systems against deterministic recorded enemy trajectories.

Assert equivalent hit results within defined tolerances.

## `territory_batch_reference_probe.gd`

Run:

```text
old sequential write implementation
vs
new command-batch implementation
```

Compare every gameplay cell after a deterministic sequence.

## `territory_visual_alignment_probe.gd`

Rendered-driver probe.

Compare selected CPU cells with expected visible territory output.

## `enemy_manager_reference_probe.gd`

For the first converted enemy role:

- run old Node implementation and new data implementation from the same initial state
- compare position, HP, state transitions, attacks, and territory effects

## `density_ladder_probe.gd`

Automated:

```text
130
160
200
250
300
```

Output full subsystem timing table.

## `allocation_stress_probe.gd`

Assert no pool growth after warm-up during a peak-density fixture.

---

# 25. Debug visualization tools

Performance architecture is much easier to validate when visible.

Add optional developer overlays.

## Spatial grid

Show:

- grid lines
- enemy count per cell
- cells touched by current query
- candidate IDs selected

## Territory

Show:

- CPU cell boundaries
- dirty cells this tick
- cells actually changed
- duplicate-touch heatmap
- Root projection values

## Thistle

Show:

- volley ID
- cached target packet
- initial target line
- ricochet query radius
- planned path if preplanning is enabled
- candidate count beside each impact

## Enemy scheduling

Color generic enemies by AI update bucket.

This makes it obvious whether expensive updates are properly distributed.

---

# 26. Performance telemetry for development builds

Display a compact developer HUD:

```text
FPS / frame ms
simulation median / p95 / p99

Enemies: 217 / 250
Generic nodes: 12
Managed enemies: 205

Thorns: 146
Thistle candidate checks: 892

Territory commands: 23
Cells touched: 1,421
Unique changed: 388
Duplicate ratio: 72.7%

Spatial grid build: 0.18 ms
Enemy update: 2.4 ms
Thistle: 3.8 ms
Fruit: 2.1 ms
Territory: 3.0 ms
```

This will make future performance regressions much easier to diagnose during normal play.

---

# 27. Exact recommended implementation order

Do **not** start with enemy MultiMesh or compute shaders.

Use this order:

## Step 1
Extend profiling and create density-ladder fixtures.

## Step 2
Implement the shared spatial grid.

## Step 3
Route Thistle target acquisition and Burr through the grid.

Measure.

## Step 4
Convert thorns to a centralized lightweight projectile manager.

Measure.

## Step 5
Aggregate Thistle gameplay events and remove remaining volley-time signal/timer churn.

Measure.

### Decision gate A

If all 130-enemy pairings are now below budget, move to 160/200 testing.

Do not optimize Thistle further unless needed.

## Step 6
Add `TerritoryPaintCommand` and batch field writes.

Measure maximum Fruit.

## Step 7
Convert Fruit trail to swept capsule commands and coalesce dirty cells.

Measure.

## Step 8
Make territory percentage/maturity/cache invalidation incremental or lazy.

Measure.

### Decision gate B

If Thistle + Fruit at 200 enemies is below budget, consider 200 the new provisional Campaign cap.

## Step 9
Prototype persistent SubViewport territory rendering in a branch.

Compare actual rendered builds.

Only keep it if it meaningfully reduces CPU cost or improves future scalability.

## Step 10
Convert one basic enemy role to `EnemyManager`.

Measure old vs new role at 130, 200, 300 entities.

## Step 11
Add AI buckets and local spatial separation.

Measure.

## Step 12
Convert remaining high-count basic enemy roles.

## Step 13
Batch basic enemy rendering with MultiMesh.

Measure actual render frame.

### Decision gate C

Attempt 250 and 300 enemies.

## Step 14
Only if profiling still identifies tight pure-data loops as bottlenecks, move those loops to GDExtension/C++.

## Step 15
Only if territory visual painting remains a GPU/CPU bottleneck after the SubViewport path, prototype compute-shader painting.

---

# 28. Expected outcome

The expected optimization stack is:

```text
Root:
per-enemy world query
 -> shared cached field query
 -> already completed

Thistle:
per-thorn / per-volley repeated work
 -> shared spatial query
 -> lightweight projectile arrays
 -> batched hit/event resolution
 -> bounded local ricochet search

Fruit:
many immediate territory writes
 -> swept paint commands
 -> one TerritoryWriteBatch
 -> unique dirty-cell processing

Territory visual:
CPU-heavy direct updates
 -> persistent GPU painting

Enemies:
many high-level per-object updates
 -> centralized packed simulation
 -> scheduled AI
 -> local spatial separation
 -> batched rendering
```

The key prediction is:

1. **Thistle should be the easiest remaining p99 problem to eliminate** because its spikes are synchronized to discrete volleys.
2. **TerritoryField is the most valuable foundational optimization** because Fruit is exposing a shared field-write bottleneck that affects current and future Adaptations.
3. **EnemyManager is what converts those savings into higher population density.**

The first realistic target should be **200 concurrent enemies at a stable 60 FPS**.

After that, test 250 and 300 rather than assuming either is automatically correct.

The shipping cap should be set by:

- p99 frame stability
- visual readability
- battlefield feel
- specialist clarity

not by the current architecture's limitations.

---

# 29. Definition of done

This performance project is complete when:

- [ ] All 28 Adaptation pairings pass the p99 budget at the chosen Campaign enemy cap.
- [ ] Thistle no longer produces rhythmic volley stutter.
- [ ] Thistle visual/projectile counts are not reduced for performance.
- [ ] Fruit 6/11/16 scaling remains intact.
- [ ] Fruit trails no longer make TerritoryField a dominant frame cost.
- [ ] Root projection behavior remains exact.
- [ ] Gameplay relic events are never dropped under load.
- [ ] Basic enemies can exceed the old 130 cap without SceneTree overhead becoming dominant.
- [ ] Rendered performance is validated, not only headless simulation.
- [ ] Enemy role readability is preserved at peak density.
- [ ] No new pool allocation occurs during a warmed-up peak-density run.
- [ ] Debug probes can identify the dominant subsystem of any future slow frame.
- [ ] Campaign density progression is retuned around the new proven cap.

---

# 30. Reference material

- Godot Engine documentation: **Optimization using Servers**  
  https://docs.godotengine.org/en/latest/tutorials/performance/using_servers.html

- Godot official demo: **Bullet Shower**  
  https://github.com/godotengine/godot-demo-projects/tree/master/2d/bullet_shower

- Godot Engine documentation: **Optimization using MultiMeshes**  
  https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html

- Godot Engine documentation: **Using Viewports**  
  https://docs.godotengine.org/en/latest/tutorials/rendering/viewports.html

- Godot Engine documentation: **Using compute shaders**  
  https://docs.godotengine.org/en/stable/tutorials/shaders/compute_shaders.html

- Vampire Survivors developer discussion describing the original physics bottleneck and new-engine benchmark improvement  
  https://steamcommunity.com/app/1794680/discussions/0/3425571923630043488/

- Risk of Rain 2 Wiki: **Directors**  
  https://riskofrain2.wiki.gg/wiki/Directors

- Nintendo ink-territory patent, JP6543361B2 / related family  
  https://patents.google.com/patent/JP6543361B2/en

---

## Final implementation rule

Whenever a performance problem appears, ask these questions in order:

1. **Are many objects independently asking the same question?**  
   Share or cache the answer.

2. **Are many objects represented as Nodes even though they only need data?**  
   Centralize them.

3. **Are many writes targeting the same field in one frame?**  
   Batch and deduplicate them.

4. **Does the gameplay require exact 60 Hz work, or only smooth 60 Hz presentation?**  
   Lower and stagger simulation frequency where safe.

5. **Is the GPU better suited to the work?**  
   Move visual painting or repeated drawing there without making gameplay depend on GPU readback.

6. **Is the remaining hotspot a tight pure-data loop after all of the above?**  
   Only then consider GDExtension/C++.

That philosophy should let Sporekeeper increase density while preserving the visual excess and systemic interactions that make the late game fun.
