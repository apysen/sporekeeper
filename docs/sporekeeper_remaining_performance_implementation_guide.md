# Sporekeeper Performance Optimization Guide, Third Pass
## Remaining work after the August 30 density-headroom pass

**Status:** New implementation roadmap  
**Engine:** Godot 4  
**Scope:** Remaining performance work only  

**Primary goals:**
1. Make **Max Fruit** pass the 16.67 ms headless p99 budget at 160 and then 200 enemies.
2. Remove the measured **88% duplicate TerritoryField write amplification** without changing territory results.
3. Establish a trustworthy **exported release-build rendered performance gate**.
4. Raise Campaign enemy density only after the real rendered frame, not just headless simulation, proves the headroom exists.

---

# 1. Executive conclusion

The second August 30 performance pass changes the optimization strategy.

The game does **not** currently need a broad data-oriented rewrite to support more enemies.

Measured headless simulation shows:

| Fixture | 130 enemies | 160 enemies | 200 enemies |
| --- | ---: | ---: | ---: |
| Generic saturation | 8.53 ms | 8.71 ms | 9.09 ms |
| Max Fruit | 18.18 ms | 18.71 ms | 22.22 ms |
| Thistle + Fruit | 15.29 ms | 16.08 ms | 17.68 ms |
| Thistle + Vine | 11.63 ms | 13.63 ms | 15.13 ms |

Going from 130 to 200 generic enemies costs only about **0.56 ms p99**.

All 28 Adaptation pairings now pass the 16.67 ms headless p99 target at the current 130-enemy cap. The previous worst pairing fell from roughly 34.9 ms to roughly 15 ms.

The remaining problem is therefore not "too many enemies."

It is **multiplicative work triggered by specific high-density mechanics**.

The highest-priority remaining examples are:

```text
Fruit AoE
    x many enemies hit
    x _damage_enemy consequences
    x death/on-hit/on-kill cascades

Territory stamps
    x many cells touched
    x repeated writes to the same cells

Rendered combat
    x unknown engine/render workload
    x effects/overdraw/UI/Canvas work not visible headlessly
```

The guiding rule for the next pass is:

> Do not redesign a large subsystem until a measured bar proves that subsystem is the bottleneck.

---

# 2. What the previous guide got wrong, and what should be retained

## Wrong diagnosis 1: Fruit trail writes were the primary Fruit cost

Measured reality:

```text
Fruit trail enqueue: about 0.03 ms
```

The large Fruit cost is now concentrated in:

```text
fruit_salad_ms   13.30 ms
blast_damage_ms  13.20 ms
fruitseeds_ms    10.10 ms
fruit_bloom_ms    9.24 ms
```

These paths funnel into `blast_enemies_in_radius`, then into `_damage_enemy` and its secondary consequences.

**Conclusion:** Do not rewrite Fruit movement, Fruit count, or trail spawning to solve the current Max Fruit headless bottleneck.

## Wrong diagnosis 2: Thistle needed a spatial grid immediately

The previous guide expected target acquisition and swept collision to dominate.

Measured reality at the bad spike:

```text
target acquisition: about 1.3 ms
swept collision:    about 1.6 ms
```

The actual issue was an unbounded ricochet search plus hidden linear accessors.

After targeted fixes, Thistle + Vine now holds **15.13 ms p99 at 200 enemies**.

**Conclusion:** Thistle architecture is currently good enough. Preserve its spectacle.

## Wrong diagnosis 3: Enemy representation needed to change before density could rise

Measured reality:

```text
130 generic enemies: 8.53 ms p99
200 generic enemies: 9.09 ms p99
```

**Conclusion:** A generic EnemyManager rewrite, MultiMesh conversion, or full SceneTree bypass is not currently justified for the 160 to 200 density range.

## What remains correct from the original guide

Several ideas now have strong measurement support:

- deterministic reference probes before algorithm changes
- exact dirty-cell coalescing for TerritoryField
- event-buffer architecture for very large hit/proc cascades
- actual rendered validation
- only moving to spatial grids, MultiMesh, GDExtension, or compute shaders after profiling justifies them

---

# 3. Research findings from other high-density games and simulations

This section separates **external evidence** from **Sporekeeper-specific recommendations**.

## 3.1 Soulstone Survivors: separate gameplay from presentation

Game Smithing documented a projectile-heavy torture case where an optimized implementation improved from about 72 ms per frame to about 20.9 ms per frame, which they described as roughly a 70% performance improvement.

Their published changes included:

- different projectile physics logic
- moving visual effects toward GPU-driven processing
- avoiding expensive disable/re-enable lifecycle work for pooled projectiles in their specific architecture

They have also stated publicly that late-game Soulstone Survivors can process **more than 500,000 hits per second** and tens of thousands of skill uses per second. Because showing strong feedback for every individual hit becomes both technically and visually impractical, they intentionally reduce or aggregate feedback as combat density rises.

### What this means for Sporekeeper

Sporekeeper should preserve **every gameplay-significant Fruit hit**, but it should not assume every hit requires an immediate full stack of:

```text
damage number
impact primitive
sound
screen feedback
source-colored flash
secondary cosmetic event
```

The Fruit cascade optimization should separate:

```text
AUTHORITATIVE GAMEPLAY EVENTS
from
PRESENTATION EVENTS
```

Gameplay events cannot be dropped.

Presentation events can be:

- coalesced
- pooled
- intensity-scaled
- rate-limited
- spatially merged

This is especially relevant because damage-number rendering already became a measurable rendered cost in Sporekeeper.

### Sources

Soulstone Survivors Devlog #12:  
https://gamehypes.com/news/devlog-12-new-game-mode-boss-projectile-performance

Developer discussion of extreme late-game hit counts:  
https://steamcommunity.com/app/2066020/discussions/0/603033444160643407/

## 3.2 Risk of Rain 2: explicit proc-chain state

Risk of Rain 2 represents hits with explicit metadata that includes damage, attacker, critical state, force, proc coefficient, and a **proc chain**.

Its item system uses a proc-chain mask so that many proc effects cannot activate themselves again within the same chain. This prevents item interactions from recursively escalating without bound.

Risk of Rain 2 also gives many high-frequency attacks lower proc coefficients. That is primarily a **balance system**, not a performance optimization, so Sporekeeper should not copy proc coefficients merely to save CPU.

The architectural lesson is more useful:

> A hit should carry enough chain metadata that downstream systems can make cheap, explicit decisions without reconstructing how the hit happened.

### What this means for Sporekeeper

Sporekeeper already has source tags and recursion rules.

The Fruit cascade rewrite should formalize those into a compact context object that travels with every generated gameplay event.

Example:

```gdscript
class_name ProcContext

var root_event_id: int
var parent_event_id: int
var chain_depth: int
var source_adaptation: int
var source_relic: int
var flags: int
var visited_trigger_mask: int
```

This should make rules such as:

```text
Fruit Salad can trigger X
X cannot trigger Fruit Salad again
kill-generated event cannot regenerate itself
secondary thorn cannot count as natural thorn
```

cheap and explicit.

Do **not** use the system to weaken existing legal interactions.

Use it to avoid:

- repeated trigger eligibility searches
- accidental recursion
- rebuilding source history from objects/signals
- deeply nested callback chains

### Sources

Risk of Rain 2 proc coefficients:  
https://riskofrain2.wiki.gg/wiki/Proc_Coefficient

Risk of Rain 2 damage and proc-chain behavior:  
https://riskofrain2.wiki.gg/wiki/Damage

## 3.3 Noita: dirty regions are the right model for a world field

Noita simulates an enormous changing pixel world.

In Petri Purho's GDC presentation, the world is divided into **64 x 64 chunks**, and each chunk keeps a **dirty rectangle** identifying the region that actually needs simulation.

Stable regions are not continuously reprocessed.

The system also uses a checkerboard schedule to make chunk updates safe across worker threads, but multithreading is not the important lesson for Sporekeeper yet.

The relevant lesson is:

> Track what changed, and only process the changed region.

### What this means for Sporekeeper

Sporekeeper already measured:

```text
5,266 territory cells touched
601 unique cells
about 88% duplicate writes
```

That is an unusually strong signal for dirty-region processing.

A first implementation does **not** need Noita-style threading.

It needs:

```text
dirty-cell membership
dirty-cell list
optional dirty bounds per territory chunk
```

Only after this proves useful should chunked worker-thread processing even be considered.

### Sources

GDC, Exploring the Tech and Design of Noita:  
https://www.youtube.com/watch?v=prXuyMCgbTc

Accessible technical summary:  
https://files.mindstudio-cdn.com/c1ecbf36-9ddb-4adb-85af-d13f05487bdf/documents/230ac481-1337-4e45-a22c-ea36efc943b6.html

## 3.4 Factorio: overlapping influence should become one shared registration

Factorio's developers described a performance problem with overlapping radar coverage.

The old logic let each source repeatedly ask the map to keep areas revealed.

For overlapping Roboports and radars, they changed this into a **registration-style system**:

```text
source registers chunk
    -> chunk counter increments

source stops covering chunk
    -> counter decrements

counter > 0
    -> chunk stays active/revealed
```

Overlapping sources therefore stop multiplying the same world-level work.

The developers also place selected chunks into update buckets so not everything needs processing every tick.

### What this means for Sporekeeper

This is closely analogous to repeated Fruit/Bloom/Green operations touching the same territory cells.

Do not let:

```text
Fruit A
Fruit B
Fruit C
Bloom
Fruitseed
```

each independently force the same expensive downstream cell work when their writes overlap.

Instead:

```text
many producers
    -> one TerritoryWriteBatch
    -> one compacted per-cell result
    -> one downstream invalidation
```

### Source

Factorio Friday Facts #421, Optimizations 2.0:  
https://www.factorio.com/blog/post/fff-421

## 3.5 Nintendo's ink patent: compact paint events plus persistent state

A Nintendo patent associated with the ink-territory game design describes:

- drawing operations represented as compact events such as weapon type, position, direction, strength, and ink color
- drawing state stored per pixel
- a persistent texture covering the play space
- GPU/stencil-buffer operations used when applying team-colored drawing
- a described texture size of **3200 x 3200 pixels**

This is patent material, not proof that every shipping Splatoon title uses the exact implementation described.

It is still valuable architectural evidence that territory-like gameplay can be represented as:

```text
compact draw command
    -> persistent field
```

rather than regenerating the whole presentation every frame.

### What this means for Sporekeeper

Do **not** build the GPU territory painter yet.

First determine whether territory **rendering** is actually a major part of the exported rendered-frame cost.

If it is, the next visual architecture should likely be:

```text
CPU gameplay TerritoryField
+
persistent GPU visual territory texture
+
compact visual paint commands
```

The CPU field remains authoritative.

Do not read the GPU texture back to answer gameplay questions.

### Source

Nintendo patent:  
https://patents.google.com/patent/US12397230B1/en

## 3.6 Godot: rendered profiling needs separate CPU/GPU metrics

Godot exposes separate per-viewport metrics for:

```text
CPU render time
GPU render time
objects drawn
primitives drawn
draw calls
```

It also provides an **overdraw debug mode** for finding pixels that are repeatedly shaded behind transparent/overlapping content.

Godot's profiler documentation explicitly warns that total frame time includes rendering and visual effects even when script and physics timing look healthy.

Godot also notes that profiling less optimized builds is less representative of real-world performance.

### What this means for Sporekeeper

The current rendered probe needs a second revision.

A single:

```text
frame_ms
```

does not tell us whether the missing time is:

```text
script
render-thread CPU submission
GPU fill rate
draw-call/state overhead
overdraw
particles
HUD
damage numbers
territory presentation
```

The exported release probe must record those dimensions independently.

### Sources

Godot Profiler:  
https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html

Godot RenderingServer:  
https://docs.godotengine.org/en/stable/classes/class_renderingserver.html

Godot profiling notes:  
https://docs.godotengine.org/en/latest/engine_details/development/profiling/index.html

Godot 2D particle systems:  
https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html

---

# 4. New priority order

The remaining work should be performed in this order.

```text
0. Exported release rendered baseline
1. Max Fruit cascade attribution
2. Fruit gameplay event pipeline
3. Territory duplicate-write coalescing
4. Territory differential reference probe
5. Rendered ablation matrix
6. Presentation coalescing where measured
7. Re-run density ladder at 160 and 200
8. Only then reconsider spatial grid / MultiMesh / EnemyManager
```

The reason release rendering is Step 0 is simple:

The game currently has a much larger difference between headless and rendered performance than between 130 and 200 enemies.

Current debug rendered measurements at 2560 x 1440:

| Enemies | Frame p50 | Frame p99 | Combat draw p99 | Enemy draw p99 |
| --- | ---: | ---: | ---: | ---: |
| 130 | 16.04 ms | 30.02 ms | 5.67 ms | 4.57 ms |
| 200 | 22.89 ms | 41.93 ms | 8.11 ms | 7.17 ms |

Enemy drawing is not large enough to explain the entire rendered gap.

The next benchmark has to identify what does.

---

# 5. Phase 0: make the rendered release probe authoritative

Create:

```text
rendered_release_density_probe.gd
```

or extend the existing `rendered_density_probe.gd`.

The same fixture must be runnable from an exported **release** build.

## 5.1 Required frame metrics

Record every sampled frame:

```text
total_frame_ms

combat_simulate_ms
combat_draw_ms

render_cpu_ms
render_gpu_ms

canvas_objects
canvas_primitives
canvas_draw_calls

damage_number_count
soft_vfx_count
particle_emitter_count
thorn_visual_count
fruit_visual_count
enemy_count
```

Use Godot:

```gdscript
var viewport_rid := get_viewport().get_viewport_rid()

RenderingServer.viewport_set_measure_render_time(
    viewport_rid,
    true
)
```

Then query:

```gdscript
RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
```

And Canvas stats:

```gdscript
RenderingServer.viewport_get_render_info(
    viewport_rid,
    RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,
    RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
)
```

Also gather:

```text
OBJECTS_IN_FRAME
PRIMITIVES_IN_FRAME
```

## 5.2 Benchmark conditions

Run at:

```text
1920 x 1080
2560 x 1440
```

for:

```text
130 enemies
160 enemies
200 enemies
```

Use the same deterministic fixtures where possible.

Test at minimum:

```text
generic saturation
max Fruit
Thistle + Fruit
Thistle + Vine
```

Warm up for at least:

```text
60 rendered frames
```

before sampling.

## 5.3 Required output

For each run:

```text
frame p50
frame p95
frame p99
frame max

render CPU p50/p95/p99
render GPU p50/p95/p99

draw calls p50/p99
objects p50/p99
primitives p50/p99

frames > 16.67
frames > 25
frames > 33.33
```

Also capture the **single worst frame's own values**.

Do not infer a worst frame by combining independent p99s.

## 5.4 Interpret the result before optimizing

### Case A: render CPU is high, GPU is low

Likely suspects:

- Canvas command submission
- many CanvasItems
- text
- many material/texture state changes
- `_draw()` reconstruction
- particle emitter management

Next step:

```text
render ablation matrix
```

Do not immediately lower visual resolution.

### Case B: GPU render time is high

Likely suspects:

- transparent overdraw
- large full-screen or near-full-screen transparent layers
- particle fill rate
- territory overlays
- expensive shaders
- high 1440p pixel cost

Run the same scene at 1080p.

If GPU cost drops roughly with pixel count while CPU time remains similar, the game is likely fill-rate/overdraw bound.

Use Godot's overdraw debug mode.

### Case C: render CPU and GPU are both low but total frame is high

The missing time is somewhere else.

Instrument:

```text
_process phases
physics
audio
UI layout
resource work
OS/driver stalls
other viewports
```

Do not blame rendering simply because headless is faster.


---

# 6. Phase 1: dissect the Max Fruit cascade before changing architecture

Current Max Fruit at 200:

```text
fruit_salad_ms    13.30
blast_damage_ms   13.20
fruitseeds_ms     10.10
fruit_bloom_ms     9.24
```

All roads lead into:

```text
blast_enemies_in_radius
    -> _damage_enemy
        -> hit consequences
        -> death consequences
        -> generated effects
```

The next job is to find what `_damage_enemy` actually spends time doing.

## 6.1 Add one-level-deeper counters

Add:

```text
damage_core_ms
damage_status_ms
damage_on_hit_ms
damage_on_kill_ms
damage_death_ms
damage_relic_ms
damage_adaptation_ms
damage_territory_ms
damage_feedback_ms
damage_number_spawn_ms
damage_vfx_enqueue_ms
damage_secondary_spawn_ms

damage_calls
kills_resolved
on_hit_callbacks
on_kill_callbacks
secondary_gameplay_events
secondary_cosmetic_events
max_proc_chain_depth
```

Hot loops should accumulate locally and report once per pass.

Do not put high-overhead profiling helpers inside every nested callback.

## 6.2 Add a worst-frame Fruit trace

For the worst sampled Max Fruit frame, record a compact causal tree.

Example:

```text
ROOT Fruit Bloom #82
  blast: 63 enemies
  direct hits: 63
  direct kills: 31

  generated:
    31 kill callbacks
    18 Fruitseed events
    11 Fruit Salad events
    7 relic events
    4 territory events

  generation depth:
    depth 0: 63
    depth 1: 71
    depth 2: 22
    depth 3: 3
```

Do not print every event during live profiling.

Store counters/records and dump them after the sample.

The important question is:

> Is 13 ms expensive because each `_damage_enemy` call is individually slow, or because one blast expands into hundreds or thousands of legal downstream calls?

Those need different fixes.

---

# 7. Phase 2: replace recursive Fruit consequences with an explicit event queue

Implement this only after Phase 1 confirms the cascade is the dominant remaining Fruit work.

The goal is **not** to reduce legal effects.

The goal is to make them:

- flat
- inspectable
- bounded by existing gameplay rules
- cheap to dispatch
- easier to batch
- easier to profile

## 7.1 Core event types

Start small.

```gdscript
enum CombatEventType {
    DAMAGE,
    KILL,
    TERRITORY,
    KNOCKBACK,
    SPAWN_GAMEPLAY,
    PRESENTATION
}
```

A conceptual damage event:

```gdscript
class_name DamageEvent

var target_id: int
var target_slot: int

var amount: float
var source_id: int
var source_adaptation: int
var source_relic: int

var is_critical: bool
var damage_flags: int

var proc_context: ProcContext
```

Avoid allocating one RefCounted object per event in the final hot path.

Start readable if needed, then move to packed parallel arrays or a reusable struct-like pool if allocation shows up.

## 7.2 Carry resolved enemy slot when safe

The new `_enemy_slot_by_id` map already makes lookups O(1).

Still, a blast has already resolved the target roster.

Avoid repeatedly converting:

```text
enemy ID -> slot
```

deep in the same event if the slot can be validated cheaply.

Event:

```text
target_id
target_slot
```

Validation:

```gdscript
if _slot_is_active_and_matches_id(target_slot, target_id):
    use slot
else:
    target_slot = _find_enemy(target_id)
```

This keeps the map a shortcut rather than authority, matching the safety rule already adopted.

## 7.3 ProcContext

Formalize chain state.

```gdscript
class_name ProcContext

var root_event_id: int
var parent_event_id: int
var chain_depth: int

var source_flags: int
var trigger_mask: int
```

Possible source bits:

```text
NATURAL_THORN
GENERATED_THORN
FRUIT_DIRECT
FRUIT_BLAST
FRUITSEED
FRUIT_SALAD
RELIC_GENERATED
EVOLUTION_GENERATED
```

The trigger mask should answer:

```text
Has this chain already used trigger X?
Is X allowed to respond to this source?
Does this generated hit qualify as natural?
```

without walking object ancestry or reconstructing the history.

## 7.4 Do not copy Risk of Rain 2's proc coefficient unless desired for balance

Risk of Rain 2 uses proc coefficients partly to keep rapid/multi-hit attacks from overperforming with item effects.

That is a game-balance choice.

Sporekeeper currently wants the relic/Adaptation interactions it already designed.

So:

**Do not lower Fruit proc chances for performance.**

First make the existing legal chain cheaper.

## 7.5 Flatten dispatch

Current conceptual pattern:

```text
damage_enemy()
    -> relic callback
        -> damage_enemy()
            -> kill callback
                -> blast()
                    -> damage_enemy()
```

Target:

```text
queue damage event

while gameplay_event_queue has events:
    event = next event
    resolve event
    append legal consequences
```

Use a ring buffer or indexed array.

Avoid `Array.pop_front()` because it may shift elements.

Example:

```gdscript
var events: Array
var read_index := 0

while read_index < events.size():
    var event = events[read_index]
    read_index += 1
    resolve(event)
```

Clear/reuse after the slice.

## 7.6 Preserve deterministic event order

This is non-negotiable.

Define the existing observable order before rewriting.

For example:

```text
1. direct damage
2. death state transition
3. on-hit gameplay effects
4. on-kill effects
5. generated blast events
6. territory consequences
7. presentation
```

Do not assume that is the current order. Read the existing code and document the actual semantics.

The new queue must reproduce it.

## 7.7 Separate gameplay from presentation at dispatch

After gameplay resolution, enqueue presentation records:

```text
DamageFeedbackEvent
ImpactEvent
SoundEvent
DeathVFXEvent
```

Then presentation may safely coalesce.

Example:

```text
31 Fruit blast hits in 40 px radius this frame
```

Gameplay:

```text
31 exact hits
```

Presentation:

```text
31 damage numbers if FULL
or
N aggregated numbers if IMPORTANT ONLY

1 stronger impact pulse
instead of
31 identical overlapping pulses

1 layered blast sound
instead of
31 simultaneous identical sounds
```

---

# 8. Phase 3: build `fruit_cascade_reference_probe.gd`

Do not deploy the event queue based only on final DPS.

The reference probe should compare the old implementation and event-queue implementation from identical snapshots.

## 8.1 Compare final authoritative state

For each enemy:

```text
active/dead
HP
status flags
Spore state
entanglement
Pincushion
position if knockback occurred
```

Global:

```text
TerritoryField bytes/state
generated gameplay objects
relic counters
Adaptation counters
run stats
```

## 8.2 Compare event counts

```text
direct hits
critical hits
kills
on-hit triggers
on-kill triggers
Fruitseed germinations
Fruit Blooms
Fruit Salads
relic-generated attacks
territory effects
```

## 8.3 Compare event order where gameplay-visible

Create a compact event signature:

```text
event type
target id
source type
root chain id
parent chain id
rounded damage or exact encoded value
```

Compare sequence.

If exact global event order is not gameplay-visible, compare order only within dependency chains.

Do not loosen the test merely to make the new system pass.

First understand every mismatch.

---

# 9. Phase 4: TerritoryField dirty-cell coalescing

This is now justified by direct measurement.

Example sampled bad frame:

```text
cells touched: 5,266
unique cells:    601
duplicate ratio: about 88%
```

That means a large majority of territory write work is touching cells already touched in the same batch.

## 9.1 First rule: not every write is safely coalescible

Do not simply turn:

```text
write
write
write
```

into:

```text
keep final value
```

until the semantics are classified.

Different write operations may be:

### Last-writer-wins

Example:

```text
set owner to X
```

if only the final owner matters.

### Max/min reducible

Example:

```text
strength = max(strength, incoming_strength)
```

### Additive

Example:

```text
strength += delta
```

### Ordered / non-commutative

Example:

```text
claim enemy territory
 -> trigger event
 -> later lose it
```

If the intermediate transition is gameplay-visible, it cannot be collapsed into only the final owner.

Classify every territory write path.

## 9.2 Add `TerritoryWriteOp`

Conceptual form:

```gdscript
enum TerritoryOpType {
    CLAIM,
    CORRUPT,
    MATURE,
    DAMAGE,
    STRENGTH_ADD,
    STRENGTH_MAX,
    CLEAR
}
```

Record:

```text
cell_id
op_type
value
source
sequence
```

The initial implementation can remain sequential while merely gathering duplicate statistics.

Then add safe reducers one operation type at a time.

## 9.3 Dirty membership

Use:

```gdscript
var dirty_flags := PackedByteArray()
var dirty_indices := PackedInt32Array()
```

When a cell is first touched:

```gdscript
if dirty_flags[cell_id] == 0:
    dirty_flags[cell_id] = 1
    dirty_indices.append(cell_id)
```

At the end:

```gdscript
for cell_id in dirty_indices:
    process_cell(cell_id)
    dirty_flags[cell_id] = 0

dirty_indices.clear()
```

Do not clear the entire field-sized flag array every frame.

## 9.4 Add per-cell operation accumulator only when needed

For safely reducible operations:

```text
pending_claim_owner[cell]
pending_strength_add[cell]
pending_strength_max[cell]
```

Avoid a Dictionary keyed by cell if the field already has compact indexed cells.

## 9.5 Chunk dirty rectangles

After simple dirty-cell coalescing works, add Noita-inspired chunk metadata only if downstream field processing still scans large regions.

Start with a benchmark.

Possible:

```text
32 x 32 gameplay cells per chunk
```

Each chunk tracks:

```text
dirty
min_x
min_y
max_x
max_y
dirty_cell_count
```

On cell touch:

```text
expand chunk dirty rect
```

Derived systems can then process only the changed rectangle.

Do not build multithreaded checkerboard updates yet.

Sporekeeper is one arena and the dirty list may already be enough.

## 9.6 Cache invalidation

Increment revisions once per completed authoritative batch where possible.

Example:

```text
control_revision
maturity_revision
topology_revision
visual_revision
```

Do not invalidate Root projection repeatedly for 100 writes that all happen before the next Root query.

But preserve mid-frame semantics if a system intentionally reads territory between writes.

If necessary, divide the simulation into explicit write barriers.

---

# 10. Phase 5: `territory_batch_reference_probe.gd`

This probe should be stricter than the existing argument-based validation.

## 10.1 Differential test

Given the same initial field and the same ordered write stream:

```text
OLD sequential implementation
vs
NEW batched implementation
```

Compare every cell.

Byte-identical where practical.

## 10.2 Test workloads

Include:

```text
single Fruit trail
16 Fruit overlapping
Fruit Bloom
Fruit Salad cascade
Fruitseed burst
Bloom wash
enemy corruption
Pruning recovery
Root-connected Green
mixed player/enemy writes to same cells
writes exactly on field boundaries
```

Randomized fixed-seed sequences:

```text
1,000+
```

## 10.3 Compare derived state

Not only raw cells:

```text
Territory %
Mature Green count
Root field revision
Root projection output
topology flags
control counts
any reward/proc counters driven by territory changes
```

---

# 11. Phase 6: rendered ablation matrix

Once the release build produces trustworthy render CPU/GPU numbers, identify the missing rendered cost by disabling visual layers one at a time.

Create debug runtime flags.

## 11.1 Ablation switches

```text
render_enemies
render_territory
render_damage_numbers
render_thorns
render_fruit
render_vine
render_soft_vfx
render_particles
render_hud
render_enemy_overlays
render_hit_flashes
render_world_decor
```

Never disable gameplay simulation for this test.

Only presentation.

## 11.2 Run matrix

At 130 and 200 enemies:

```text
FULL
FULL - territory
FULL - VFX
FULL - damage numbers
FULL - enemy art
FULL - HUD
FULL - particles
FULL - adaptation visuals
```

Record delta in:

```text
total frame p99
render CPU p99
render GPU p99
draw calls
objects
primitives
```

This answers:

```text
What is actually expensive to render?
```

instead of guessing.

---

# 12. Phase 7: interpret the rendered bottleneck

Do not implement all options below.

Choose based on the ablation result.

## 12.1 If territory presentation is GPU-heavy

Potential fix order:

1. inspect overdraw
2. reduce stacked transparent full-field layers
3. use a persistent territory render texture
4. update only changed visual regions/paint commands
5. consider lower internal territory visual resolution with smooth sampling
6. only then consider compute shaders

The Nintendo patent is relevant here:

```text
compact paint events
 -> persistent texture
```

The CPU gameplay field should remain separate.

## 12.2 If particles/VFX are expensive

Godot recommends `GPUParticles2D` for large particle counts unless there is a specific reason to use CPU particles.

Audit every high-volume effect:

```text
impact primitive
thorn trail
Fruit burst
Bloom burst
enemy death
territory motes
critical feedback
```

Classify:

```text
gameplay readable
important feedback
pure decoration
```

For pure decoration:

- use GPUParticles2D where appropriate
- combine identical emitters
- reduce overlapping emissions dynamically
- pool or keep emitters alive if lifecycle registration appears in profiling
- never reduce gameplay objects merely to reduce VFX

## 12.3 If damage numbers are still a major cost

The digit atlas already reduced 160-number draw median from:

```text
3.24 ms -> 1.38 ms
```

Do not undo it.

The next question is readability.

Current IMPORTANT ONLY behavior can produce roughly:

```text
17 -> 147 visible numbers
```

when fully ranked Thistle begins counting every critical as important.

Possible options:

### Option A: critical threshold

A crit is important only if:

```text
is_critical
AND
damage >= IMPORTANT_CRIT_THRESHOLD
```

### Option B: source-aware aggregation

For rapid repeated Thistle hits on one target within a very short window:

```text
24 CRIT
24 CRIT
24 CRIT
```

becomes:

```text
72 CRIT
```

on IMPORTANT ONLY.

FULL still shows every number.

### Option C: per-target display cooldown on IMPORTANT ONLY

Accumulate damage during the short cooldown.

Recommended default:

**Option B**, because it preserves the message "Thistle is critting hard" without filling the screen with nearly every individual hit.

## 12.4 If draw calls are high

Before MultiMesh, inspect why batching breaks.

Common causes:

```text
texture changes
material changes
different shaders
many custom CanvasItems
per-object special state
```

The baked digit atlas already demonstrates the value of putting many visual variants on one texture.

Apply the same idea only to measured high-volume layers.

## 12.5 If overdraw is high

Use Godot's overdraw debug mode.

Likely candidates in Sporekeeper:

```text
large transparent Green/territory overlays
soft VFX primitives
overlapping circular Bloom effects
dense Fruit effects
many full-alpha feathered sprites
screen-sized post effects
```

A large transparent quad still shades its transparent pixels.

If a texture has huge transparent margins, tighter geometry or more tightly packed sprites may help.

---

# 13. Phase 8: keep generic enemy architecture unchanged until it fails a threshold

Current generic scaling:

```text
130: 8.53 ms
200: 9.09 ms
```

That is excellent.

Do not rewrite it yet.

## 13.1 Trigger for a spatial grid

Implement a shared spatial grid only when a measured crowd-dependent query becomes significant.

Recommended trigger:

```text
one repeated crowd-query subsystem > 2.0 ms p99
at the intended shipping density
```

Examples:

```text
thistle targeting
Fruit candidate search
Cane target gather
enemy separation
```

## 13.2 Trigger for EnemyManager/data-oriented rewrite

Only consider if:

```text
generic saturation cost from 130 -> target density
adds more than about 3 to 4 ms p99
```

or profiler shows per-enemy SceneTree callbacks dominating.

At the current 200 result, this condition is not met.

## 13.3 Trigger for MultiMesh

Only consider if:

```text
enemy drawing becomes a dominant rendered CPU/draw-call cost
```

For example:

```text
enemy draw > 25% of total frame
AND
draw-call/object submission is the measured cause
```

Current debug evidence says enemy draw is near-linear and not enough to explain the total rendered frame.

## 13.4 Trigger for GDExtension

Only consider if a **pure-data tight loop** remains hot after algorithmic fixes.

Fix the algorithm first.

---

# 14. Phase 9: Campaign density unlock gates

Do not change Campaign's shipping cap from 130 merely because headless simulation passes.

Use two gates.

## 14.1 Headless simulation gate

For the candidate density:

```text
all required fixtures p99 <= 16.67 ms
```

and no rhythmic repeated spike.

### 160 target

Current blocker:

```text
Max Fruit 18.71 ms
```

Everything else in the primary table already passes.

### 200 target

Current blockers:

```text
Max Fruit        22.22 ms
Thistle + Fruit  17.68 ms
```

Thistle + Vine already passes.

## 14.2 Exported rendered gate

At the candidate density:

```text
release-build total frame p99 <= 16.67 ms
```

on the defined reference hardware/profile.

Also record:

```text
p50
p95
frames > 25 ms
frames > 33.33 ms
```

If occasional p99 exceeds 16.67 by a tiny amount but no recurring hitch is perceptible, make the final shipping threshold a design decision.

But do not use the headless result as a substitute.

---

# 15. New probe suite

Keep the existing probes.

Add:

## `rendered_release_density_probe.gd`

Purpose:

- authoritative release rendered performance
- CPU vs GPU render attribution
- Canvas stats
- 1080p vs 1440p scaling

## `fruit_cascade_probe.gd`

Purpose:

- deepest Fruit cost attribution
- causal chain volumes
- chain-depth histogram
- direct vs generated work

Output:

```text
damage calls
kills
on-hit
on-kill
generated events
max depth
subsystem times
```

## `fruit_cascade_reference_probe.gd`

Purpose:

- old vs event-queue equivalence
- final gameplay state
- event counts
- gameplay-visible event order

## `territory_batch_reference_probe.gd`

Purpose:

- exact old vs new TerritoryField comparison
- every cell
- derived state
- Root projection regression

## `render_ablation_probe.gd`

Purpose:

- automated presentation layer toggles
- CPU/GPU/render statistics
- identify actual rendered bottleneck

## `damage_feedback_density_probe.gd`

Purpose:

Measure:

```text
FULL
IMPORTANT ONLY current
IMPORTANT ONLY aggregated
OFF
```

at:

```text
max Thistle
max Fruit
Thistle + Fruit
```

Report:

```text
numbers spawned
numbers visible
draw CPU
draw calls
visual capture
```

---

# 16. Exact implementation sequence

## Step 1: exported rendered metrics

Add:

```text
render CPU
render GPU
Canvas draw calls
Canvas objects
Canvas primitives
```

to the rendered probe.

Run release export.

**Do not optimize rendering before this result.**

## Step 2: instrument `_damage_enemy`

Break Max Fruit's 13 ms blast cost into:

```text
damage
hit
kill
relic
Adaptation
territory
feedback
secondary spawn
```

Add worst-frame causal counts.

## Step 3: inspect for one more hidden repeated-work defect

Before event architecture, explicitly search the hot damage path for:

```text
by-id accessors
roster scans
field scans
repeated source lookup
repeated relic lookup
repeated target state lookup
repeated eligibility calculation
```

The previous pass found seven defects of this exact class.

Do not assume there cannot be an eighth.

## Step 4: implement Fruit gameplay event queue only if still justified

Flatten recursive hit/kill consequences.

Carry:

```text
target slot
source flags
ProcContext
chain mask
```

Preserve exact gameplay.

## Step 5: differential Fruit probe

Do not proceed until old/new agree.

## Step 6: implement Territory dirty-cell membership

First version:

```text
track duplicates
track unique cells
do not alter semantics
```

Then safely reduce only operation classes proven reducible.

## Step 7: differential Territory probe

Require exact result before deleting old path.

## Step 8: chunk dirty rects only if needed

If remaining territory time is still high because derived systems scan regions, add Noita-style per-chunk dirty rectangles.

Do not thread it yet.

## Step 9: run 160 and 200 headless density ladder

Expected next milestone:

```text
all fixtures pass 160
```

Then target:

```text
all fixtures pass 200
```

## Step 10: rendered ablation matrix

Use release build.

Identify:

```text
CPU-render bottleneck
GPU bottleneck
overdraw
damage feedback
territory visual
VFX
HUD
```

## Step 11: implement only the measured rendered fix

Examples:

```text
territory painter
GPU particle conversion
VFX coalescing
damage-number aggregation
atlas/material consolidation
```

Do not do all of them.

## Step 12: choose new Campaign enemy cap

Only after both:

```text
headless gate
release rendered gate
```

pass.

---

# 17. Things explicitly not scheduled anymore

These are **deferred**, not rejected.

Do not implement them unless later measurements trigger them.

- full data-oriented EnemyManager
- generic enemy SceneTree removal
- enemy MultiMesh conversion
- GDExtension rewrite
- compute-shader TerritoryField
- multithreaded territory simulation
- global combat spatial grid
- reducing Thistle thorn count
- reducing Burr ricochets
- reducing Fruit Set
- reducing enemy density as an optimization
- dropping gameplay relic/proc events under load

The second August 30 pass showed that large architecture changes would have attacked the wrong problems first.

---

# 18. Definition of done for the next performance pass

The remaining optimization pass is complete when:

- [ ] `Max Fruit <= 16.67 ms p99` at 160 enemies headlessly.
- [ ] `Thistle + Fruit <= 16.67 ms p99` at 200 enemies headlessly.
- [ ] Max Fruit is either below 16.67 ms at 200 or its exact remaining blocker is identified.
- [ ] `_damage_enemy` no longer contains hidden multiplicative scans in the Fruit torture fixture.
- [ ] Fruit gameplay cascades are bounded by explicit source/proc metadata rather than accidental call-stack behavior.
- [ ] Gameplay events are never dropped for performance.
- [ ] Territory duplicate writes are coalesced where mathematically/gameplay-equivalent.
- [ ] `territory_batch_reference_probe.gd` confirms old/new field equivalence.
- [ ] Root projection still matches existing validated behavior.
- [ ] An exported release build has authoritative rendered p50/p95/p99 measurements.
- [ ] Render CPU and GPU times are recorded separately.
- [ ] Canvas draw calls, objects, and primitive counts are recorded.
- [ ] The largest rendered layer is identified through ablation rather than guessed.
- [ ] IMPORTANT ONLY damage feedback remains genuinely less cluttered than FULL.
- [ ] No visual performance optimization silently weakens Adaptations or relics.
- [ ] Campaign density is raised only after both headless and release-rendered gates pass.

---

# 19. Expected likely outcome

Based on the current numbers, the most plausible near-term outcome is:

```text
Fruit cascade cleanup
    -> Max Fruit approaches/passes 160 budget

Territory duplicate coalescing
    -> removes another recurring high-tail field cost

both together
    -> Thistle + Fruit clears 200

release render attribution
    -> identifies one presentation bottleneck not visible headlessly
```

The generic enemy result suggests that **200 enemies is still a realistic target without a fundamental enemy-system rewrite**.

Whether 250 or 300 is worthwhile should be answered later.

The next step is not to build for 300.

It is to make 160 and 200 exact, stable, rendered, and measurable.

---

# 20. Performance philosophy going forward

## Rule 1: profile the multiplication

When cost rises with density, look for:

```text
Adaptation events x enemies
projectiles x targets
AoE hits x callbacks
territory stamps x cells
effects x presentation objects
```

before changing representation.

## Rule 2: cache facts, not guesses

The most successful fixes so far removed code that repeatedly asked a question whose answer was already known.

Examples:

```text
enemy position
enemy slot
open-ground line transmission
identical Fruit aim direction
Cane angular target window
```

Look for the same pattern first.

## Rule 3: overlap should get cheaper, not more expensive

This is the common lesson from Noita's dirty regions and Factorio's overlapping registrations.

If ten systems touch the same world region:

```text
do not perform ten full downstream updates
```

Record overlap and resolve the shared result once where semantics allow it.

## Rule 4: game state and feedback are different workloads

A Fruit blast may legally hit 100 enemies.

That does not mean the player needs:

```text
100 text operations
100 identical sounds
100 identical particles
100 separate screen pulses
```

Preserve the 100 hits.

Compress redundant presentation.

## Rule 5: do not optimize an unmeasured architecture

No spatial grid because "horde games use grids."

No MultiMesh because "there are 200 enemies."

No compute shader because "Splatoon uses GPU painting."

Each one needs a measured trigger.

## Rule 6: reference probes are part of the optimization

The Cane probe catching the non-unit-vector assumption is the model.

Any optimization that touches:

```text
target choice
event order
territory ownership
damage outcome
pool replacement
```

gets a reference implementation and differential probe before the old path is removed.

---

# 21. Research reference list

## High-density action and proc systems

**Soulstone Survivors, Devlog #12**  
Projectile optimization, GPU effects, object lifecycle costs.  
https://gamehypes.com/news/devlog-12-new-game-mode-boss-projectile-performance

**Soulstone Survivors developer discussion**  
Developer describes late-game hit volumes above 500,000 hits per second and why feedback must reduce dynamically.  
https://steamcommunity.com/app/2066020/discussions/0/603033444160643407/

**Risk of Rain 2 Wiki, Proc Coefficient**  
High-frequency attacks, proc coefficients, item effect scaling.  
https://riskofrain2.wiki.gg/wiki/Proc_Coefficient

**Risk of Rain 2 Wiki, Damage**  
Damage metadata, proc chains, proc masks, chained on-hit effects.  
https://riskofrain2.wiki.gg/wiki/Damage

## Field and world simulation

**GDC, Exploring the Tech and Design of Noita**  
64 x 64 chunks, dirty rectangles, checkerboard simulation.  
https://www.youtube.com/watch?v=prXuyMCgbTc

**Factorio Friday Facts #421, Optimizations 2.0**  
Overlapping radar registrations, shared chunk counters, update buckets.  
https://www.factorio.com/blog/post/fff-421

**Nintendo patent US12397230B1**  
Persistent per-pixel drawing state, drawing events, GPU/stencil operations, territory texture.  
https://patents.google.com/patent/US12397230B1/en

## Godot rendering and profiling

**Godot Profiler**  
https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html

**Godot RenderingServer**  
Per-viewport render CPU/GPU timing and Canvas draw/object/primitive statistics.  
https://docs.godotengine.org/en/stable/classes/class_renderingserver.html

**Godot Profiling**  
Notes on profiling representative optimized builds.  
https://docs.godotengine.org/en/latest/engine_details/development/profiling/index.html

**Godot 2D particle systems**  
GPU vs CPU particle behavior.  
https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html

---

# 22. Immediate next three tasks

If only three things are done next, do these:

### 1. Exported release rendered probe

Because the largest remaining unknown is the difference between:

```text
healthy headless performance
and
30 to 42 ms debug rendered p99
```

### 2. `_damage_enemy` Fruit cascade breakdown

Because Max Fruit is the only major headless blocker left at 160, and all four expensive Fruit paths converge there.

### 3. Territory dirty-cell reference implementation

Because an **88% duplicate write ratio** is the strongest direct evidence of redundant work still left in the project.

Do those before any large engine-level rewrite.
