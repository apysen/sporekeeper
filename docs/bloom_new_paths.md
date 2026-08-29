# Bloom Path Additions

This document defines the two new Bloom upgrade lines, **Aftergrowth** and **Suppression**, and how they integrate with the existing Bloom path and its Evolutions.

The current Bloom path already has two core upgrade lines:

- **Bloom Force** increases Bloom pressure, damage, and range.
- **Bloom Frequency** reduces the interval between Blooms.

Because Bloom Force already improves range and Bloom's base behavior already reclaims territory through the Bloom itself, the two new lines should not duplicate radius, damage, conversion, or basic territory restoration.

The new lines instead give Bloom a second identity beyond burst damage:

> **Bloom temporarily swings the territory war in the player's favor after each detonation.**

---

# 1. Aftergrowth

> Green touched by a Bloom gains a temporary protective layer that must be destroyed before the underlying Territory can be damaged.

Aftergrowth acts as a **temporary shield for Territory**.

## Upgrade Line

| Rank | Aftergrowth shield |
|---|---:|
| **0** | 0 control |
| **1** | **8 temporary control** |
| **2** | **16 temporary control** |
| **3** | **24 temporary control** |
| **4** | **32 temporary control** |
| **5** | **40 temporary control** |

**Per rank:** +8 temporary control  
**At rank 5:** 40 temporary control

## Base Behavior

When a Bloom affects player-owned Green:

- Apply **Aftergrowth** to the affected Green.
- Duration: **4 seconds**
- Aftergrowth creates a temporary control buffer above the territory's real control value.
- Incoming Territory damage is applied to Aftergrowth first.
- Only damage remaining after the Aftergrowth buffer reaches 0 affects the underlying Green.
- Any unused Aftergrowth disappears when the 4-second duration expires.
- Reapplying Aftergrowth refreshes the duration and restores the shield to the current rank's full value.
- Aftergrowth does not stack beyond the current rank's maximum shield.

Example at Rank 5:

A cell has:

- **100 real Green control**
- **40 Aftergrowth**

Enemies must remove the 40-point Aftergrowth shield before they can begin reducing the underlying 100 Green control.

## Scope

Aftergrowth applies to:

- Existing friendly Green inside the Bloom
- Green reclaimed by the Bloom
- Green newly created by the Bloom

Aftergrowth does not:

- Increase Territory resistance
- Restore maturity
- Increase maturation rate
- Increase real territorial control
- Increase Bloom damage
- Increase Bloom radius
- Increase Bloom conversion pressure

This keeps Aftergrowth separate from Root's Mature Strength.

### Important Implementation Rule

Aftergrowth must be stored separately from normal Territory control.

Do not implement it by temporarily raising the cell's real control value above its normal maximum.

Treat it as a distinct temporary shield value so that:

- Losing Aftergrowth does not count as losing real Green.
- Expiring Aftergrowth does not create a Territory-loss event.
- Root maturity is unaffected while only the Aftergrowth shield is being damaged.
- Systems that read actual control continue to see the true underlying Green value.

---

# 2. Suppression

> Enemies struck by a Bloom temporarily become less effective at consuming Green.

## Upgrade Line

| Rank | Enemy Territory damage reduction |
|---|---:|
| **0** | 0% |
| **1** | **-8%** |
| **2** | **-16%** |
| **3** | **-24%** |
| **4** | **-32%** |
| **5** | **-40%** |

**Per rank:** -8 percentage points enemy Territory damage  
**At rank 5:** -40%

## Base Behavior

When an enemy is hit by a Bloom:

- Apply **Suppressed**.
- Duration: **4 seconds**
- Suppressed enemies deal less damage to player-owned Territory.
- The reduction is determined by the current Suppression rank.
- Reapplying Suppression refreshes the duration.
- Suppression does not stack with itself.

Suppression affects enemy damage to Territory only.

It does not reduce:

- Damage dealt directly to the player
- Enemy movement speed
- Enemy attack speed
- Enemy health
- Enemy damage taken
- Entanglement resistance

This keeps Suppression focused specifically on the territory-control layer.

---

# 3. Bloom Tempo Window

Aftergrowth and Suppression are intentionally paired.

A Bloom creates two temporary defensive effects:

1. **The ground receives a disposable Territory shield.**
2. **The enemies become worse at destroying Territory.**

At Rank 5:

- Bloomed Green receives **40 temporary control** for 4 seconds.
- Bloom-hit enemies deal **40% less Territory damage** for 4 seconds.

Example:

If an enemy normally deals 10 Territory damage:

- Rank 5 Suppression reduces that hit to **6 damage**.
- A Rank 5 Aftergrowth shield contains **40 temporary control**.
- That enemy therefore needs roughly **7 hits** to break the shield before it can begin damaging the underlying Green.

This creates a short period after each Bloom where the player has a strong territorial advantage without duplicating Root's permanent resistance mechanics.

---

# 4. Interaction with Bloom Force

Bloom Force remains the line that improves the physical power of the Bloom.

It already governs:

- Bloom damage
- Bloom pressure
- Bloom range

Aftergrowth and Suppression do not duplicate these effects.

Bloom Force naturally increases the value of both new lines because a larger Bloom:

- Shields more Green with Aftergrowth
- Applies Suppression to more enemies

This is emergent synergy rather than an explicit multiplier.

---

# 5. Interaction with Bloom Frequency

Bloom Frequency reduces the interval between Blooms.

More frequent Blooms naturally increase:

- Aftergrowth uptime
- Suppression uptime

Repeated Blooms can refresh existing Aftergrowth shields and Suppression durations.

A Bloom that lands before the previous Aftergrowth duration expires restores the affected Green's Aftergrowth shield back to the full amount for the current rank.

The shield does not stack beyond that amount.

---

# 6. Bramble Interaction

Bloom + Bramble should function as a **hold-the-line** pairing.

Bramble needs enemies to remain on Green long enough for Entanglement to accumulate. Large mobs can undermine this by rapidly destroying the Green beneath themselves.

Aftergrowth and Suppression improve that situation without modifying Bramble's own stats.

## Intended Loop

**Enemies enter Green → Bramble begins Entangling them → Bloom detonates → Green receives Aftergrowth → enemies become Suppressed → the shield absorbs incoming Territory damage → Bramble gets more time to reach full Entanglement → THORNBURST converts the trapped battlefield into damage**

### Aftergrowth Contribution

- Gives Bramble-covered Green disposable HP.
- Buys additional time for Entanglement to accumulate.
- Protects newly reclaimed Bloom territory while Bramble establishes control.

### Suppression Contribution

- Reduces the rate at which enemies consume both the Aftergrowth shield and the real Green beneath it.
- Continues affecting enemies for four seconds even if they move outside the original Bloom area.

---

# 7. Root Interaction

Bloom + Root should function as a **Root Network preservation** pairing.

Root gains power from old, Mature Green. Losing Mature territory removes both the Territory and the time investment required to develop it.

Aftergrowth protects that investment without duplicating Mature Strength.

## Intended Loop

**Mature Root territory comes under pressure → Bloom detonates → Aftergrowth shields the Root Network → Suppression weakens attacking enemies → the temporary shield is consumed before Mature Green takes damage → Root maturity and Root Potency remain online longer**

### Distinction from Mature Strength

**Mature Strength:**

- Makes Mature Green intrinsically more resistant.
- Applies as long as the territory remains Mature.
- Reduces actual damage reaching the Green.

**Aftergrowth:**

- Adds temporary disposable control.
- Lasts only 4 seconds.
- Must be depleted before actual Green is touched.
- Can apply to fresh or Mature Green.

These two defenses should layer rather than duplicate each other.

### Damage Order

For Bloom + Root, resolve Territory damage in this order:

1. Apply **Suppression** to the enemy's outgoing Territory damage.
2. Apply the remaining damage to **Aftergrowth**.
3. If Aftergrowth is depleted, apply excess damage to the underlying Green using any applicable **Mature Strength** resistance.
4. Only actual Green damage can threaten maturity or ownership.

This creates a layered defensive structure:

**weaken attacker → consume temporary shield → reach fortified Mature Green**

Aftergrowth does **not** restore maturity that has already been lost.

---

# 8. Pruning Interaction

Bloom + Pruning should function as a **territory cycling and recovery** pairing.

Pruning deliberately consumes the player's own Green. Bloom then gives returning or reclaimed Green a temporary window of protection.

## Intended Loop

**Prune Green → gain Cuttings and offensive pressure → territory begins returning → Bloom detonates → returned Green gains Aftergrowth → nearby enemies become Suppressed → the shield protects the recovering Territory before the next harvest**

Aftergrowth does not prevent Pruning from intentionally consuming Green.

Player-driven Pruning should bypass or ignore Aftergrowth rather than consuming the shield first.

The shield exists to protect Territory from **hostile Territory damage**, not from deliberate player mechanics.

Suppression likewise does not interfere with the player's own territory-sacrifice systems.

---

# 9. Spore Interaction

Bloom already pairs strongly with Spore through **SUPER BLOOM**, so the new lines are not designed specifically around Spore.

They still provide indirect value.

### Aftergrowth

- Shields Seed-created Green.
- Gives newly germinated territory time to remain owned.
- Keeps Sporulation and other Green-dependent Spore mechanics active longer.

### Suppression

- Reduces the speed at which enemies erase Seed-created territory.
- Gives Sporulation more time to act on enemies standing on Green.

These are secondary benefits rather than the primary reason to draft the lines.

---

# 10. Existing Bloom Evolutions

The current Bloom pairings remain:

| Pairing | Evolution |
|---|---|
| **Bloom + Spore** | SUPER BLOOM |
| **Bloom + Bramble** | THORNBURST |
| **Bloom + Root** | FLOWERING SEASON |
| **Bloom + Pruning** | REBOUND |

The new Bloom lines should complement these Evolutions rather than replace their mechanics.

---

# 11. SUPER BLOOM Interaction

## SUPER BLOOM — Spore + Bloom

SUPER BLOOM already focuses on chaining Bloom events through Seed germination.

Aftergrowth and Suppression naturally benefit from those extra Blooms:

- Chained Blooms can place Aftergrowth shields across more Green.
- Chained Blooms can repeatedly Suppress large enemy packs.
- More Bloom events create more temporary protection for Seed-created territory.

No direct Evolution changes are required initially.

---

# 12. THORNBURST Interaction

## THORNBURST — Bloom + Bramble

THORNBURST harvests Bramble claimed by Blooms into Briar Traps.

Aftergrowth and Suppression improve the setup leading into those trap events:

- Aftergrowth keeps Bramble territory intact longer.
- Suppression reduces enemy pressure on the Bramble field.
- Longer-lived Bramble gives THORNBURST more reliable material to harvest.

No explicit Entanglement multiplier should be added to either new Bloom line.

---

# 13. FLOWERING SEASON Interaction

## FLOWERING SEASON — Bloom + Root

FLOWERING SEASON spends Mature-ground buildup to produce mass Bloom events.

The new lines make those events defensive as well as offensive:

- Aftergrowth places temporary shields across the surviving Root Network.
- Suppression weakens enemies attacking Mature Green.
- Mass Bloom events can create broad four-second protection windows.

Aftergrowth must not restore spent or destroyed maturity.

This keeps FLOWERING SEASON centered on spending maturity for Bloom events while allowing those events to protect the remaining Root Network.

---

# 14. REBOUND Interaction

## REBOUND — Bloom + Pruning

REBOUND collapses Green inward before exploding outward.

Aftergrowth should apply to Green reclaimed or recreated by the outward Bloom.

Suppression should apply normally to enemies struck by the Rebound explosion.

The intended sequence is:

**Collapse → inward pull → outward Bloom → returned Green gains Aftergrowth → surviving enemies become Suppressed**

Player-driven collapse should not waste Aftergrowth shields before the Rebound occurs.

This strengthens REBOUND's identity as a violent territory reset that leaves the player in a temporarily favorable battlefield state.

---

# 15. Final Bloom Upgrade Structure

| Line | Per rank | At rank 5 | Purpose |
|---|---|---|---|
| **Bloom Force** | Existing implementation | Existing implementation | Damage, pressure, and range |
| **Bloom Frequency** | Existing implementation | Existing implementation | Bloom cadence |
| **Aftergrowth** | **+8 temporary control for 4s** | **40 temporary control** | Shield Bloomed Green |
| **Suppression** | **-8 percentage points enemy Territory damage for 4s** | **-40%** | Weaken enemies hit by Bloom |

---

# 16. Defensive Identity Separation

The three defensive paths should now have clearly different methods of protecting Territory.

| Path | Defensive identity |
|---|---|
| **Bloom** | Creates short **tempo windows** through temporary Territory shields and enemy Suppression |
| **Root** | Makes old territory permanently harder to destroy through maturity, resistance, and regrowth |
| **Bramble** | Prevents enemies from effectively attacking by slowing, rooting, and repelling them |

The distinction should remain visible in play:

### Bloom

**Burst → shield → suppress → window expires**

### Root

**Mature → reinforce → regenerate → persist**

### Bramble

**Entangle → slow → root → repel**

---

# 17. Design Goals

The four Bloom lines answer four distinct questions:

| Line | Question |
|---|---|
| **Bloom Force** | How powerful and large is each Bloom? |
| **Bloom Frequency** | How often does Bloom happen? |
| **Aftergrowth** | How much temporary protection does Bloom leave behind? |
| **Suppression** | How dangerous are enemies after Bloom? |

The two new lines intentionally avoid:

- Additional Bloom damage
- Additional Bloom radius
- Additional Bloom pressure
- Direct territory restoration
- Permanent Territory resistance
- Maturity bonuses
- Entanglement bonuses
- Pruning-specific bonuses
- Seed-specific bonuses

---

# 18. Playtest Targets

Aftergrowth and Suppression should be judged primarily by whether they create a noticeable **four-second tempo swing** after each Bloom.

A successful Bloom should create a short period where:

1. Hostile control is pushed back by the base Bloom.
2. Friendly Green receives a visible temporary shield.
3. Bloom-hit enemies become worse at destroying Territory.
4. Bramble gets time to Entangle.
5. Root's Mature territory is protected before its actual control is damaged.
6. Pruning gets time to stabilize recovering Green.
7. Spore gets more time to operate on owned Green.

## Aftergrowth Readability

The player should be able to tell when Territory still has Aftergrowth remaining.

Recommended visual direction:

- Thin brighter edge or secondary outline on shielded Green
- Shield effect visibly weakens as temporary control is consumed
- Brief Bloom-like shimmer when Aftergrowth is refreshed
- No separate permanent HUD meter

The effect should read directly on the battlefield.

## Initial Tuning Rule

If Aftergrowth feels irrelevant:

1. Increase the **shield amount** first.
2. Keep the **4-second duration** fixed initially.

If Suppression feels irrelevant:

1. Increase the **Territory damage reduction** first.
2. Keep the **4-second duration** fixed initially.

Avoid solving weak performance by extending both effects into near-permanent buffs. Their identity depends on Bloom creating short, powerful periods of battlefield control.
