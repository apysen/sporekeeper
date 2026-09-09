# Performance benchmark output

Machine-readable results from the optimization work described in
`docs/performance_optimization_implementation_guide.md`. Every file here is a
measurement of one commit, kept so regressions show up as a diff rather than as
somebody's recollection of how fast it used to feel.

## Probes

### `tests/peak_density_probe.gd` — the gate

All 28 Adaptation pairings at the shipping enemy cap. Asserts a p99 budget and
exits non-zero when a pairing breaks it. This is the probe that decides whether a
change may land.

```
godot --headless --path . --script tests/peak_density_probe.gd
```

### `tests/density_ladder_probe.gd` — the measurement

The guide's six named fixtures, run up a density ladder with the per-subsystem
timing and volume counters. Answers "how does this scale" rather than "does this
pass", so it never fails a build.

```
godot --headless --path . --script tests/density_ladder_probe.gd
godot --headless --path . --script tests/density_ladder_probe.gd -- --fixtures=D --densities=130,200
godot --headless --path . --script tests/density_ladder_probe.gd -- --csv=res://docs/benchmarks/density_ladder_130.csv
```

| flag | default | meaning |
| --- | --- | --- |
| `--fixtures=` | `A,B,C,D,E,F` | which fixtures to run |
| `--densities=` | `130,160,200,250,300` | concurrent enemy counts |
| `--csv=` | none | write the machine-readable rows to this path |

Fixtures:

| key | name | isolates |
| --- | --- | --- |
| A | `generic_saturation` | base enemy scaling, no Adaptation, no relics |
| B | `max_thistle` | Thistle volley p99 |
| C | `max_fruit` | TerritoryField write cost |
| D | `thistle_fruit` | both current bottlenecks together — the torture test |
| E | `thistle_vine` | Thistle volleys against high-frequency Vine collision |
| F | `root_fruit` | the Root projection win, kept so Territory work cannot undo it |

Above 160 enemies the probe grows `enemy_pool_size` and rebuilds the combat pools
before spawning, because the shipped pool holds 160 and an enemy the pool cannot
hold is an enemy the measurement silently would not include.

## Counters

`PerfCounters` (`src/core/models/run/perf_counters.gd`) holds the
game-specific timers and volume counters. It is **off by default** — a disabled
counter costs one static bool read, and the hot loops accumulate into a local and
report once per pass rather than calling in per candidate. Only probes turn it on.

## CSV schema

One row per subsystem per fixture per density, plus a `frame` row for the whole
frame, so a spreadsheet can pivot on `subsystem_name` without reshaping anything.

```
git_commit, build_type, renderer, resolution, density, spawned, fixture,
adaptation_a, adaptation_b, relic_fixture,
median_ms, p95_ms, p99_ms, max_ms,
frames_over_16_67, frames_over_25, frames_over_33, sample_frames,
subsystem_name, subsystem_median_ms, subsystem_p99_ms, subsystem_count_total
```

`subsystem_median_ms` / `subsystem_p99_ms` are populated for timer rows;
`subsystem_count_total` is populated for volume rows. A subsystem that never ran
still emits a row of zeroes rather than vanishing, so two runs stay diffable.

Note that the territory timers show a median of zero: the field steps on one frame
in four and repaints on another, matching how the game drives it, so most frames
genuinely spend nothing there. Read territory on p99, not on median.

## Baseline

`density_ladder_130.csv` — commit `f4dd417`, debug build, GL Compatibility,
headless, 600 frames per fixture.

| fixture | median | p95 | p99 | max | frames > 16.67ms |
| --- | --- | --- | --- | --- | --- |
| A generic saturation | 2.91 | 7.67 | 8.89 | 11.32 | 0 / 600 |
| B max Thistle | 5.55 | 12.86 | 20.38 | 52.14 | 9 / 600 |
| C max Fruit | 3.56 | 21.46 | 34.72 | 42.13 | 67 / 600 |
| D Thistle + Fruit | 7.49 | 20.17 | 34.33 | 50.62 | 73 / 600 |
| E Thistle + Vine | 9.14 | 18.44 | 30.61 | 50.93 | 49 / 600 |
| F Root + Fruit | 3.87 | 17.79 | 23.56 | 41.19 | 38 / 600 |

This reproduces the guide's headline figures: Thistle + Fruit at 34.3 ms p99
against its stated 34.8, Thistle + Vine at 30.6 against its stated 30.0. Fixture A
confirms the guide's central claim that generic enemy density is not the ceiling —
130 enemies with no Adaptation running never touch the budget once in 600 frames.

The gate probe was re-run on the same commit after the counters landed and is
unchanged: 12 of 28 pairings over the 16.67 ms p99 budget, every failing pairing
holding Thistle or Fruit, Thistle + Fruit at 34.65 ms and Thistle + Vine at
30.00 ms. Counters are disabled on that path, and the numbers match the guide's
authoritative profile, so the instrumentation costs nothing measurable when off.

### What the subsystem split shows that the guide did not

**The Thistle volley spike is in hit resolution, not in target acquisition or
collision.** Fixture E, p99: the whole thorn update is 15.88 ms, of which
`thistle_hit_resolution_ms` is 14.41 ms. Collision is 1.60 ms and targeting is
1.28 ms. Fixture B says the same at smaller scale — 10.92 ms of update, 9.47 ms of
it resolution. The expensive thing is the cascade a landed thorn sets off, not the
scan that found it. A spatial grid alone therefore addresses roughly 3 ms of a
16 ms spike; the guide's §7.8 (aggregate hit events, resolve in batches) is the
change that matters, and §7.2/§7.5 are supporting work rather than the fix.

**Fruit's cost is collision, not trail writing.** The guide attributes Fruit to
"repeated Green trail writes". `fruit_trail_enqueue_ms` p99 is 0.03 ms — free.
`fruit_collision_ms` p99 is 10.2 ms, and it appears at that size in every fixture
holding Fruit (C 10.23, D 10.05, F 10.32). It is `_find_fruit_segment_hit`, which
calls `combat.get_enemy_position(id)` and `get_enemy_radius(id)` per enemy per
Fruit — and those are scans of the enemy pool by id, so the loop is roughly
O(fruits x enemies^2). The neighbouring thorn path already fixed exactly this by
hoisting the packed roster once per pass; Fruit never got the same treatment.

#### Fruit collision: fixed

`_find_fruit_segment_hit` now reads the packed roster once instead of asking
`combat` for a position and a radius per enemy, matching what the thorn loop
already does. The same three arrays, read at the same moment, paired by index, so
the enemy chosen is unchanged.

`density_ladder_130_fruit_fix.csv`. `fruit_collision_ms` p99:

| fixture | before | after |
| --- | --- | --- |
| C max Fruit | 10.23 | 0.49 |
| D Thistle + Fruit | 10.05 | 0.46 |
| F Root + Fruit | 10.32 | 0.63 |

In the gate probe the `adapt` column for every Fruit pairing without Thistle falls
from about 15 ms to about 5.6 ms, and frames over budget fall sharply:

| pairing | p99 before | p99 after | over budget before | after |
| --- | --- | --- | --- | --- |
| Bramble + Fruit | 27.26 | 21.87 | 44 / 600 | 13 / 600 |
| Root + Fruit | 23.15 | 20.92 | 37 / 600 | 10 / 600 |
| Pruning + Fruit | 21.88 | 20.42 | 33 / 600 | 10 / 600 |
| Thistle + Fruit | 34.65 | 35.03 | 68 / 600 | 23 / 600 |

Read that carefully: the change removes about 10 ms of **continuous** cost, so the
body of the distribution improves a lot — p95 on Thistle + Fruit drops from 19.97
to 15.35, and the over-budget frame count falls by roughly two thirds — while p99
barely moves and **no pairing clears the budget**. The gate still reports 12 of 28.
The extreme tail is set by a rarer, larger event that this fix does not touch, and
`fruit_total_ms` p99 is still 15.57 ms in fixture C with collision and trail
enqueue together accounting for half a millisecond of it. That residual is the
next thing to find; the release cadence (16 Fruit created in one frame) is the
obvious suspect and is not yet instrumented.

#### Thistle ricochet search: fixed

Splitting `thistle_hit_resolution_ms` into lookup / damage / cascade accounted for
under 2 ms of a 14.5 ms bucket. The remainder was `_find_ricochet_target`, the
Burr search, which scanned every active enemy while calling
`combat.get_enemy_position(id)` per enemy — quadratic in the crowd for the same
reason Fruit collision was — and then ran `territory_field.is_growth_path_clear`,
a line walk across the field, per enemy per ricochet per thorn. This is exactly
the guide's §7.6 "never rescan all enemies", and it was costing more than every
other part of the Thistle path put together.

The roster is now read once. Same arrays, same moment, paired by index, and the
distance prune still runs before the line-of-sight walk, so the target chosen is
unchanged.

| fixture | metric | before | after |
| --- | --- | --- | --- |
| B max Thistle | frame p99 | 19.69 | **12.94** |
| B max Thistle | frames over budget | 7 / 600 | **2 / 600** |
| B max Thistle | `thistle_total_ms` p99 | 11.09 | **4.81** |
| E Thistle + Vine | frame p99 | 29.66 | **16.63** |
| E Thistle + Vine | frames over budget | 46 / 600 | **6 / 600** |
| E Thistle + Vine | `thistle_total_ms` p99 | 15.83 | **4.95** |
| E Thistle + Vine | `thistle_hit_resolution_ms` p99 | 14.50 | **2.74** |

`thistle_ricochet_ms` p99 is now 0.54 ms (B) and 1.37 ms (E).

In the gate probe the over-budget list falls from **12 of 28 pairings to 6**, and
every remaining failure holds Fruit. Thistle is off the list entirely:

| pairing | p99 baseline | p99 now |
| --- | --- | --- |
| Root + Thistle | 32.57 | **13.24** |
| Thistle + Vine | 30.00 | **15.85** |
| Bramble + Thistle | 19.74 | **12.28** (Pruning + Thistle row; Bramble similar) |
| Spore / Bloom / Pruning + Thistle | 18.4–18.8 | all under budget |
| Thistle + Fruit | 34.65 | **23.57** — still over, on the Fruit side |

Remaining over budget: Spore + Fruit 21.1, Bloom + Fruit 36.1, Bramble + Fruit
23.3, Root + Fruit 24.3, Pruning + Fruit 21.2, Thistle + Fruit 23.6. The `terrain`
column carries 11.8–13.3 ms in every one of those rows, so the next fix is the
territory write batching in §8.3 — which the 88% duplicate ratio below already
argues for.

#### Territory stamp transmission: fixed

Capturing the worst frame's own breakdown — rather than reading independent
per-subsystem percentiles, which need not come from the same frame — showed the
42.45 ms frame in fixture C was `territory_batch_ms` **22.74 ms** plus
`fruit_seeds_ms` 12.37 ms.

`_stamp_growth` and `_stamp_bloom_surge` were calling
`_claimable_line_transmission` — a Bresenham walk from the stamp source — once
per cell, making a stamp `O(radius^3)`. That function returns exactly 1.0 when its
ray crosses no blocked cell, and a Bresenham ray between two points in an
axis-aligned box never leaves that box (the diagonal corner peeks included). So
one `O(radius^2)` scan of the box, widened to hold the source, proves every ray
inside it is 1.0. The stamps now skip the walks entirely on open ground. This is
exact rather than approximate, and `green_wash_probe` returns byte-identical
output across the change — 66.2% green, 1,762,381 owned pixels, `max_drift`
0.0000.

#### Fruit release aim: fixed

With the territory spike gone, the worst frame became `fruit_release_ms` **33.19
ms** — a number that had been invisible because it fires so rarely that its own
p99 across 600 frames read 0.009 ms. `_begin_normal_fruit_release` called
`_get_fruit_aim_direction` once per Fruit, and that walks the whole enemy roster
with a path test per enemy before sweeping every candidate sector against every
target. A 16-Fruit release asked the identical question sixteen times about the
same origin, on the one frame that could least afford it. It is now computed once
per distinct origin.

Fixture C across the whole session:

| | baseline | after collision fix | after territory fix | after aim fix |
| --- | --- | --- | --- | --- |
| p99 | 34.72 | 34.70 | 31.74 | **19.39** |
| frames over 16.67 | 67 / 600 | 14 / 600 | 12 / 600 | **8 / 600** |
| frames over 33 | 8 / 600 | 8 / 600 | 6 / 600 | **1 / 600** |

### Gate result

All 28 pairings now hold p99 within 16.67 ms at the 130 cap. The probe passes.

| | baseline | now |
| --- | --- | --- |
| pairings over budget | **12 / 28** | **0 / 28** |
| worst pairing | Bloom + Fruit 34.88 | Thistle + Fruit 15.82 |
| Thistle + Fruit | 34.65 | 15.82 |
| Thistle + Vine | 30.00 | 14.91 |
| Root + Thistle | 32.57 | 12.43 |
| Bloom + Fruit | 34.88 | 13.78 |
| Root + Fruit | 23.15 | 14.37 |

This clears the guide's **Decision Gate A**, so the ladder moves to 160 and 200.

### The pattern behind all four fixes

None of them needed new architecture. Every one was the same defect: a hot loop
asking a question whose answer it already had, or could have had once instead of
`n` times.

| site | shape |
| --- | --- |
| `_find_fruit_segment_hit` | by-id accessor per enemy, each a pool scan |
| `_find_ricochet_target` | by-id accessor per enemy, plus a field line walk per enemy |
| `_stamp_growth` / `_stamp_bloom_surge` | a source-to-cell ray walk per cell |
| `_begin_normal_fruit_release` | an identical roster-wide aim query per Fruit |

The guide's own §3.3 names this — "any query that asks the same world-level
question repeatedly should immediately be suspicious" — and its final rule puts it
first: *are many objects independently asking the same question?* Four answers to
that question took the suite from 12 failures to none, with no spatial grid, no
data-oriented rewrite, no MultiMesh, and no GDExtension. Those remain the right
tools for raising the cap; they were not what was wrong at 130.

Worth sweeping the remaining by-id accessors on the same grounds: the combat
director has 51 separate `for enemy in _enemies` loops, and every public
`get_enemy_*(id)` on it is one of them.

## The 160 and 200 rungs

`density_ladder_160_200.csv`, same commit and build.

| fixture | 130 | 160 | 200 |
| --- | --- | --- | --- |
| A generic saturation | 8.89 | **9.22** | **9.65** |
| C max Fruit | 19.39 | 19.74 | 26.12 |
| D Thistle + Fruit | 15.82 | 21.11 | 24.13 |
| E Thistle + Vine | 14.91 | 23.15 | 30.14 |

**Milestone A was not met at that point.** See the updated ladder at the end —
after the cane work, 160 is very close and fixture E clears 200 outright.

Fixture A is the important row. Going from 130 to 200 enemies — 54% more crowd —
costs **0.76 ms**, and `enemy_manager_total_ms` p99 is 1.39 ms at 200. Raw enemy
density is very nearly free, exactly as the guide argues. What does not scale is
the per-Adaptation work that runs against the crowd.

Ranked by what the 200-enemy rung actually spends:

1. **`fruit_advance_ms` 19.38 ms** (fixture C) — the single largest named cost
   anywhere in the suite now. `_advance_fruit` makes three territory queries per
   Fruit per frame (`contains_local_point`, `is_claimable_at_local`,
   `is_growth_path_clear`) plus the bounce resolver, and 16 Fruit pay it every
   frame.
2. ~~The Vine, uninstrumented~~ — **wrong; it is the cane.** See below.
3. **`territory_total_ms` 10.6–11.8 ms** — the open-ground skip removed the clear
   cases; what remains is stamps near obstacles, which still walk per cell. This
   is where §8.3's dirty-cell coalescing and §8.6's swept capsules belong.
4. **`thistle_targeting_ms` 5.41 ms** (fixture D at 200, against 0.02 ms at 130).
   This is the full-roster target scan, and it is the first number in the suite
   that a shared spatial grid would directly fix. Phase 1 now has measured
   justification it did not have at 130.

### What fixture E at 200 actually spends — and it is not the Vine

The guess above was wrong, which is why it was instrumented rather than acted on.
The Vine is cheap: `vine_total_ms` p99 is **2.81 ms**, of which the Verlet advance
is 0.40 ms. The 12 ms attributed to it came from misreading the gate probe's
`combat` column, which is all of `simulate_step`, not the Vine.

Two probe changes were needed before the number could be read at all:

- **30 warm-up frames**, discarded before sampling. The worst frame in the sample
  was frame #1 — first volley, pools reaching working size, caches filling — so
  the worst-frame breakdown was describing start-up rather than combat.
- **Per-phase timing in the probe itself**, around each of the six calls the probe
  makes. The in-game counters only cover subsystems that had already been
  suspected, so anything unsuspected showed up as an unattributed remainder. It
  was 23.45 ms of a 36.53 ms frame.

With those in place, fixture E at 200:

| bar | p99 |
| --- | --- |
| `combat.simulate_step` (phase) | 24.97 |
| `cane_total_ms` | **23.99** |
| `cane_targeting_ms` | 13.35 |
| `cane_target_sweep_ms` | **12.09** |
| `cane_target_gather_ms` | 1.25 |
| `vine_total_ms` | 2.81 |
| `enemy_manager_total_ms` | 1.44 |

`get_densest_target_direction` is the dominant cost in fixture E — the same
function already fixed on the Fruit release path, reached here from
`_update_cane`. This time it cannot be deduplicated: the cane calls it once per
sweep, so the function itself has to get cheaper.

The split says which half. Gathering — the roster walk with a path query per
enemy — is 1.25 ms. The **sector sweep is 12.09 ms**, and `cane_targets` peaks at
**195**: it builds three candidate directions per target and tests every candidate
against every target, so 585 x 195 ≈ 114,000 `Vector2.angle_to` calls, each an
`atan2`, in one frame.

This one is not another safe hoist, and it is left undone deliberately. Two
options, both with a caveat:

1. **Replace the containment test with a dot product.** `angle > half_angle` and
   `dot < cos(half_angle)` are the same condition, and most targets fail it, so
   most of the 114,000 `atan2` calls become multiplications. The exact
   `angle_to` is still needed for the targets that pass, to accumulate
   `alignment_error`. Small, mostly mechanical.
2. **Angular sort plus a two-pointer sweep**, `O(n log n)` instead of `O(n^2)`.

Both touch a deliberate four-level tie-break chain — count, then distance sum,
then alignment error, then facing difference, at 0.0001 thresholds — whose comment
says it exists to guarantee a maximal angular window without depending on pool
order. Either change can flip a tie for targets sitting within float epsilon of a
threshold. That is a gameplay-visible aiming decision, so it wants an author's
call and a reference probe, not an unattended rewrite.

#### Hybrid dot rejection: done, and smaller than hoped

Option 1 was built to that shape: the dot product is allowed to reject only what
is plainly outside a candidate's sector, everything near the boundary still goes
through `angle_to`, and the tie-breaker is untouched. Both paths are one function
body differing by a flag, so they cannot drift, and
`debug_densest_target_direction_reference()` keeps the pre-optimization behaviour
available to probes permanently.

**The probe caught a real bug on the first run — 42 of 1,760 comparisons
disagreed, some by 2.9 radians.** A control comparing the reference against itself
never fired, so the search was deterministic and the fault was the rejection's.
Every mismatch had auto-targeting on, and the cause is worth recording because it
is latent in the original code:

> These "direction" vectors are not unit vectors. Gathering divides the
> straight-line offset by `distance`, and with auto-targeting `distance` has by
> then been reassigned to the routed path length, which is longer than the straight
> line — so the stored direction comes out shorter than one. `angle_to` never
> noticed, because atan2 of cross over dot is scale invariant. A dot product is
> not: it returns `|a||b|cos(angle)`, so against short vectors it reads as a wider
> angle than the real one and rejects targets that are actually inside the sector.

Fixed by building unit copies once per call for the rejection alone. The probe now
reports **1,760 comparisons, every one identical**, across both routing modes,
four layouts chosen to attack the argument (targets on the sector edge at 1e-6,
collinear sets that force count ties into the distance stage), seven sector widths
and densities to 160. `peak_density_probe` still passes at the 130 cap.

The gain is **`cane_target_sweep_ms` p99 12.09 -> 10.04 ms**, not the 8-10 ms that
looked available. The prune can only skip targets outside a sector, and in a crowd
packed around the player few are: `cane_targets` peaks at **195 of 200**, and at
60-140 degree sectors most of those genuinely fall inside most candidates' sectors.

Instrumenting the stroke as well now accounts for the whole cane at 200 enemies:

| bar | p99 |
| --- | --- |
| `cane_total_ms` | **21.89** |
| `cane_targeting_ms` | 11.28 |
| — `cane_target_gather_ms` | 1.23 |
| — `cane_target_sweep_ms` | 10.04 |
| `cane_perform_ms` | **10.27** |

Which reframes option 2. An angular sort addresses the 10.04 ms sweep and nothing
else — under half the cane — so even a perfect `O(n log n)` version leaves roughly
11-12 ms in gathering and the stroke. `cane_perform_ms` is 10.27 ms that has never
been looked inside, and every unexamined bar in this session so far has turned out
to hide the same `O(n^2)` accessor pattern. That is the cheaper place to look
first.

#### The stroke was not the stroke — `_collect_enemy_targets`

Looking there first was right. With the Vine driving, `_perform_cane_sweep`
returns early and the rope resolves the hits, so the loop everything was attributed
to never runs. **`cane_sweep_signal_ms` was 10.13 ms of the 10.21 ms**: one
`emit`. The sound was 0.06 ms.

The listener chain is `cane_sweep_started` -> `_fire_thornwhip` ->
`_fire_mounted_head` (two to four heads per sweep) -> `_collect_enemy_targets`,
and the last two both called `combat.get_enemy_position(enemy_id)` per enemy.
Fifth and sixth instances of the same defect. `_collect_enemy_targets` also runs on
every Thistle fire, so one hoist landed in two unrelated bars. Its candidate list,
comparator and ordering are deliberately untouched.

| fixture E at 200 | before | after |
| --- | --- | --- |
| frame p99 | 28.07 | **19.83** |
| frames over 25 ms | 29 / 600 | **2 / 600** |
| `cane_total_ms` | 21.71 | **14.70** |
| `cane_sweep_signal_ms` | 10.13 | **3.11** |
| `thistle_targeting_ms` | 5.41 | **0.30** |

#### Angular sort: built, and it is the largest single win

With the stroke fixed, the sector sweep went from under half the cane to two
thirds of it, which made option 2 worth building after all.

Target angles are sorted once per call and laid out three times — shifted down a
turn, as measured, shifted up a turn — so a candidate's window is one contiguous
run with no wrap-around case to get wrong (a window is narrower than a full turn,
so no target can appear in one twice). Each candidate then costs three binary
searches instead of a pass over every target: the count is the window width, the
distance sum is a prefix-sum difference, and splitting the window at the
candidate's own angle turns the sum of `|candidate - target|` into two more
prefix-sum differences.

All three evaluation modes are kept behind `DensestTargetMode`, sharing one body
and one tie-breaker, so a regression can be bisected by changing one constant.

**The divergence I expected did not appear.** The sorted mode forms the angular
error as a difference of two `atan2` results rather than one `atan2` of a cross
and a dot, and sums in sorted rather than pool order, so it was predicted to be
mathematically equal but not bit-identical — a real risk against a tie-breaker
with 1e-4 thresholds. Measured: **0 of 1,760 cases differed, worst separation
0.000000000 rad.** The probe keeps a tolerance and reports the rate regardless, so
if a future change does start splitting ties the number will be visible rather
than assumed.

| fixture E at 200 | before sort | after sort |
| --- | --- | --- |
| frame p99 | 19.83 | **15.06** |
| frame max | 27.29 | **22.14** |
| frames over budget | 30 / 600 | **2 / 600** |
| `cane_total_ms` | 14.70 | **7.19** |
| `cane_target_sweep_ms` | 9.96 | **2.10** |

Note what this means for the guide's plan. The Thistle spike was never target
acquisition or swept collision — the two things §7.2 and §7.5 address, and the two
things a shared spatial grid would fix. It was one unbounded search that the guide
does name, in §7.6, but schedules as part of a later step. The same root cause as
the Fruit collision fix: an `O(n^2)` by-id scan hidden behind an accessor that
reads like a lookup.

**The duplicate write ratio is real and large.** Fixture C peaks at 5,403 cells
touched in one batch against 4,747 duplicates — an 88% duplicate ratio, with only
666 unique cells actually reached. This is the strongest confirmation in the set
for §8.3's dirty-cell coalescing.

**Territory still costs about 12 ms p99 with Fruit** (C 11.98, D 11.91, F 12.49)
against 8.2–8.4 ms without it, which matches the guide's stated 8.4 ms baseline
rising to 12–16 ms almost exactly.

**Fixture F is not where the guide's 3.95 ms Root + Fruit figure came from.** At
23.56 ms p99 it is dominated by the same Fruit collision and territory cost as C.
The 3.95 ms number is `tests/fruit_scaling_probe.gd`, whose fixture is far
lighter — a 6-Fruit release rather than a peak-density crowd — and that probe
still reports 3.7–3.9 ms for root+fruit today, so the Root projection win is
intact. Fixture F is built to the guide's spec and is a valid regression row, but
`fruit_scaling_probe` and `mature_projection_probe` are the probes that actually
defend the projection, and both still pass.

## The ladder after the cane work

`density_ladder_160_200_after.csv`. Frame p99, against the same fixtures before it:

| fixture | 160 before | 160 after | 200 before | 200 after |
| --- | --- | --- | --- | --- |
| A generic saturation | 9.22 | **8.92** | 9.65 | **9.08** |
| C max Fruit | 19.74 | 19.29 | 26.12 | 27.23 |
| D Thistle + Fruit | 21.11 | **16.99** | 24.13 | **19.67** |
| E Thistle + Vine | 23.15 | **16.99** | 30.14 | **15.25** |

**Fixture E now holds 200 enemies under budget** — 15.25 ms p99, one frame over in
600, a maximum of 16.72 ms. It was the worst scaler in the suite an hour ago.

Milestone A is close but not met: C, D and E sit at 19.29, 16.99 and 16.99 against
a 16.67 budget. D and E are within a third of a millisecond of it.

Fixture C is unchanged, as expected — no cane work touches Fruit. It is now the
only fixture that is clearly out, and its cost was already located: `fruit_advance_ms`
19.38 ms (three territory queries per Fruit per frame plus the bounce resolver) and
`territory_total_ms` around 12 ms (stamps near obstacles still walking per cell).
Those two are what stand between the current state and Milestone A.

One oddity worth not explaining away: fixture E is *faster* at 200 than at 160
(15.25 vs 16.99). The layouts differ — enemies are placed on `index % 7` rings, so
the crowd geometry is not a scaled copy — and E at 200 shows one frame over budget
against nine at 160. It is more likely a real property of the two layouts than
noise, but it has not been investigated.

## Gate history

| stage | pairings over budget | worst pairing |
| --- | --- | --- |
| baseline | **12 / 28** | Bloom + Fruit 34.88 |
| after four shared-answer fixes | 0 / 28 | Thistle + Fruit 15.82 |
| after the cane work | **0 / 28** | Thistle + Fruit 15.12 |

Thistle + Vine, the second-worst pairing at baseline, went 30.00 -> **12.01 ms**.

## The systemic fix: O(1) enemy lookup

Chasing fixture C's remaining cost produced two more wrong guesses and then the
root cause of most of them.

`fruit_advance_ms` was 19-20 ms, and the three territory queries every Fruit makes
every frame — the thing named as the suspect above — turned out to be
**`fruit_terrain_ms` 0.038 ms**. Splitting further:

| bar | p99 |
| --- | --- |
| `fruit_hit_resolution_ms` | 19.50 |
| `fruitseeds_ms` | 10.44 |
| `saplings_ms` | 0.003 |
| `fruit_terrain_ms` | 0.038 |
| `fruit_burdock_ms` | 0.015 |
| `fruit_finish_ms` | 0.013 |

`_resolve_fruit_enemy_hit` asks combat about the same enemy eight to ten times —
`is_enemy_active`, `get_enemy_spore`, `get_enemy_entanglement`,
`knockback_enemy_from`, `damage_enemy_by_id`, `add_spore_to_enemy`,
`add_entanglement_to_enemy`, and more — and **every one of those was a linear scan
of the enemy pool.** `_resolve_thorn_hit` does the same six times. That is the same
defect as the six fixes before it, but rather than patch each call site it was
worth fixing where it lives.

`CombatDirector` now keeps `_enemy_slot_by_id`, maintained on spawn and
cleared on reset, and all sixteen by-id accessors funnel through `_find_enemy`.
The map is **a shortcut, never the authority**: a slot is accepted only if it still
holds an active enemy with the id asked for, and anything else falls through to the
original linear scan. A stale or missing entry can make a lookup slower; it cannot
make it wrong. `enemy_lookup_fallbacks` counts how often that happens, and it reads
**zero** across a 600-frame 200-enemy fixture.

The fix reached further than the fifteen accessors rewritten by hand:
`knockback_enemy_from`, `add_spore_to_enemy` and `add_entanglement_to_enemy`
already routed through `_find_enemy`, so they became O(1) without being touched.

| fixture C at 200 | before | after |
| --- | --- | --- |
| frame p99 | 27.35 | **22.95** |
| `fruit_total_ms` | 21.20 | **15.07** |
| `fruit_hit_resolution_ms` | 19.50 | **12.17** |

Still the largest remaining bar. The worst frame shows 21.2 ms in hit resolution
even with lookups now free, so what is left is the cascade itself — `_try_fruit_salad`,
`_try_newtons_apple`, `_try_stem_steering`, `_try_windfall`, `_create_fruit_bloom` —
none of which has been looked inside. `fruitseeds_ms` at 10.43 ms and
`territory_batch_ms` at 6.5 ms are the other two.

### A note on the rendered probes

`enemy_role_probe` joins `green_wash_probe` and `root_stage_probe` as a probe that
reads the framebuffer (`root.get_texture().get_image()`) and therefore cannot run
under `--headless` — it fails with "Parameter t is null" rather than a real
assertion. Run those three with a display. All three pass there.
