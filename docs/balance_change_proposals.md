# Proposed balance changes

**2026-09-19.** Nothing here is applied. Each entry names the file and symbol, the current
value, the proposed one, and what it is expected to do - and where that expectation was
*measured* rather than reasoned about, the measurement is given.

The evidence is in `docs/balance_and_pacing_sweep.md`. The instruments are
`tools/balance_bench.gd` and `tools/pacing_probe.gd`, and every number below can be
reproduced with the commands in §7.

Priority order, which is also the order I would apply them in:

| | change | kind | confidence |
|---|---|---|---|
| P1 | Thornwhip's mounted heads | one multiplication removed | **measured** |
| P2 | Burr ricochets lose damage per bounce | tuning | predicted |
| P3 | Vine's Elongation per rank | tuning | predicted |
| P4 | The dead first rank on four Adaptations | design | measured problem, proposed fix untested |
| P5 | Quick's pressure curve | tuning | measured problem, partial fix |
| P6 | Pruning | watch, do not change yet | measured, unexplained |

---

## P1. Thornwhip's mounted heads

**File.** `src/core/nodes/elements/adaptation_director.gd` - `_fire_mounted_head` and
`_fire_thornwhip`.

**The problem.** A mounted head fires a full Clustering volley of thorns, and each of those
thorns carries full Burr ricochets and full Needlepoint criticals. At rank 5 that is
2 packets × 4 heads × 4 thorns × 4 targets = **128 thorn hits per Vine sweep**. The
Evolution is a fourth multiplication on a chain that already has three, and its *first*
rank - the only one a Quick run reaches - is worth +50% for one pick, where sixteen
ordinary picks are worth +48%.

**The change.**

```gdscript
# _fire_mounted_head: was 1 + Clustering (+ Root step)
var projectile_count := 1

# _fire_thornwhip: was 1.0
var scale := 2.0
```

The first half removes the multiplication. The second half is what stops that from making
rank 1 pointless: the head hits once, for twice as much, so the Evolution still reads as a
mounted Thistle rather than as a footnote.

**Measured**, 22 targets, all eight lines at rank 3, against the same pair's unevolved
12,144:

| Evolution rank | now | P1 | option A alone | option B alone |
|---|---|---|---|---|
| 1 | 18,212 (+50%) | **14,044 (+16%)** | 13,156 (+8%) | 15,528 (+28%) |
| 3 | 20,672 (+70%) | **16,516 (+36%)** | — | — |
| 5 | 26,143 (+115%) | **20,296 (+67%)** | 17,632 (+45%) | 23,238 (+91%) |

*Option A* is the projectile-count change on its own; *option B* is leaving the volley
alone and capping the mounted thorns at one ricochet each (`_spawn_thorn`'s
`ricochet_cap_override`, `-1` → `1`).

**Why P1 over either alone.** Option A alone lands rank 1 at +8%, which is not worth a
pick - the ladder then only pays at rank 4 and 5, which Quick never sees. Option B leaves
rank 5 at +91%, still nearly double the next-best Evolution. P1 gives +16 / +36 / +67 for
one / three / five picks: roughly 13% per pick instead of 50% for the first, a rank-3 value
sitting at the median of the Evolution table, and a rank-5 value that is still top three
without being a second build.

**Risk.** The head damage doubling is a number I picked and measured once. If +16% at rank
1 reads as too weak in play, `scale` is the dial, and it moves the whole ladder together.

---

## P2. Burr ricochets lose damage per bounce

**File.** `src/core/nodes/elements/adaptation_director.gd` - the damage calculation in the
thorn-hit path (`var damage := thorn.damage * (...)`), plus a new export beside the other
Thistle tuning.

**The problem.** The line's own description reads "+1 **full-damage** ricochet target per
thorn", which is the strongest possible form of the mechanic: at rank 3 every thorn is four
thorns. Combined with Clustering, one firing event goes from 1 hit to 16 before any
Evolution touches it.

**The change.** `thorn.ricochet_depth` is already tracked and incremented on every hop, so
this is a multiply at the point of damage:

```gdscript
@export_range(0.0, 1.0, 0.05) var thistle_ricochet_damage_share := 0.70

# in the hit path, before the critical multiplier is applied:
damage *= pow(thistle_ricochet_damage_share, float(thorn.ricochet_depth))
```

**Predicted, not measured.** A rank-3 thorn goes from 4.0 effective full-damage targets to
1 + 0.7 + 0.49 + 0.343 = **2.53**, so Thistle's per-event output falls about 37%. Worth
measuring before and after with `--pair 5-6` and `--pair 2-5`, because Thistle pairs sit
across the middle of the table and this moves all of them.

**Also.** `UpgradeDescriptions` says "full-damage" in the Burr text. If this lands, that
word has to go, or the line is lying on the screen it is bought from.

---

## P3. Vine's Elongation per rank

**File.** `src/core/nodes/elements/adaptation_director.gd` - `_refresh_vine_modifiers`.

**The problem.** Reach is a *radius* and the sweep is an arc, so the line buys area
quadratically. At rank 3, +20% per rank is ×1.6 reach and **×2.56 swept area**, on top of
×1.75 damage and ×1.45 cadence from the other three lines. Vine's first rank alone is worth
+98% over the bare Cane, and Vine appears in seven of the top nine rows of the rank-3
sweep.

**The change.** `0.20` → `0.12` in the Elongation term. At rank 3 that is ×1.36 reach and
×1.85 area.

**Predicted, not measured.**

**Worth doing at the same time.** All four Vine per-rank values are **literals in the
function** - `0.25`, `0.15`, `0.20`, `0.25` - not exports. Vine is the only Adaptation whose
line values cannot be tuned in the Inspector, which is most of why this document had to
measure it rather than read it. Promoting them to exports beside the Thistle block costs
nothing and makes the next pass of this a tuning session instead of a code change.

---

## P4. The dead first rank

**The problem, measured.** With one rank in every line, **nine pairs deal exactly the bare
Cane's damage** - 4,152, identical to the digit, because their first rank removes no
bodies. Spore+Root takes **237 damage in the first minute** of a real run, more than twice
Grandma's maximum health, and loses the board by minute seven.

This is the largest effect in the whole sweep and the only one that is a design question
rather than a number. Three candidate fixes, none tested:

**P4a. Bramble's chip damage is too small to matter.** `bramble_contact_damage` is 0.18 per
`bramble_damage_interval_seconds` 0.45 - **0.4 damage per second**, ×3.0 when fully
entangled. A 28-health Hunter standing in Bramble dies in seventy seconds. Raising the base
to ~0.55 (1.2/second) would make the path's one offensive number visible at rank 1 without
touching its ceiling.

**P4b. Root amplifies nothing in a Root build.** `_root_amplifies_line` only amplifies Vine,
Thistle and Fruit lines *the player already owns*. A Spore+Root run owns none of them, so
Root's headline mechanic does nothing at all - which is why Root+Vine is the best row in the
table and Spore+Root is the second-worst. Letting Root Potency reach the Cane itself would
give every Root build a floor.

**P4c. Spore and Bloom pay on a delay that their first rank cannot afford.** Both convert
something into something that eventually removes bodies. Neither has a rank-1 effect that
removes one now.

**The target to measure against.** After any of these, re-run the rank-1 sweep: no pair
should sit within 5% of the bare Cane's 4,152, and I would want every pair at **+25% or
better** before calling it fixed.

---

## P5. Quick's pressure curve

**File.** `src/core/nodes/waves/wave_director.gd` - the exported defaults. The scene does
not override them, so the script values are the live ones.

- `final_health_scale` **2.15 → 3.20**
- `final_contact_damage_scale` **1.60 → 2.00**

**The problem, measured.** Across a Quick run a committed build's damage per minute rises
about ×60 while a Hunter's health rises ×1.9. Quick currently ends softer than Campaign
begins.

**Honest limits of this change.** Campaign already ends at ×3.6 health, and the measured
Campaign run took **248 damage across twenty-five minutes** while dealing 978,420. Health
alone does not close a ×60-against-×1.9 gap; it buys back the last four minutes of Quick,
nothing more. The real answer is P4 (builds that scale less steeply) and the note in P7.

---

## P6. Pruning - measured, unexplained, do not change yet

Every one of the seven Pruning pairs took **17 damage** across forty seconds surrounded by
sixty enemies. Thistle+Vine took 209 and Bramble+Root took 358. Four of the seven are in the
top eight for output, and Pruning+Vine is first in the siege table while holding the third
most ground.

The orbiting Cutting ring is a permanent area attack centred on the player, fed by
harvesting her own Green, and being surrounded is the condition it is designed for. It pays
`upkeep_cells_per_second` 9.0 out of the ecosystem.

**No change proposed**, because this is the one finding that contradicts nobody's
experience - the Green cost may well bite in real play in a way a bench that regrows the
island and never lets Grandma die cannot show. It wants a played run before a number moves.

---

## P7. Do not add spawn density as difficulty

Not a change - a constraint on future ones. Going from 22 enemies to 60 multiplies the mean
build's output by **×4.8** against **×2.7** the threat, because arcs, ricochets and rings
all hit more per activation while each body's health stays where it was. Quick's main
escalation lever is spawn interval (1.15s → 0.32s → 0.12s), so the schedule currently makes
the player relatively stronger as it runs.

What escalates a fight against area damage is enemies that are individually worth killing
and individually dangerous: health, elite modifiers, and roles that punish standing still.
Campaign does some of this; Quick does almost none.

---

## 8. How to check any of this

```
# one pair, rank 3, no Evolution
godot --headless --path . --script tools/balance_bench.gd -- --pair 5-6

# the whole roster, at the rank a build reaches in the first minutes
godot --headless --path . --script tools/balance_bench.gd -- --ranks 1

# one Evolution rank at a time
godot --headless --path . --script tools/balance_bench.gd -- --pair 5-6 --evo-rank 3

# surrounded, which is the only condition that measures defence
godot --headless --path . --script tools/balance_bench.gd -- --siege

# a whole run on the real wave clock
godot --headless --path . --script tools/pacing_probe.gd -- --pair 0-3
godot --headless --path . --script tools/pacing_probe.gd -- --pair 5-6 --campaign
```

Path ids: Spore 0, Bloom 1, Bramble 2, Root 3, Pruning 4, Thistle 5, Vine 6, Fruit 7.

A full 28-pair sweep takes about seven minutes; a Quick pacing run about fifteen; a Campaign
run about half an hour. Both instruments are deterministic, so a before-and-after pair of
runs is a real comparison rather than two samples.
