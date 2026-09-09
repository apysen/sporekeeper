# Clover Gambling System
## Master Design and Implementation Guide

**Project:** Sporekeeper  
**Element:** Plant  
**Status:** Current master specification  
**Engine:** Godot 4.x  
**Purpose:** This document is both the design source of truth and the implementation guide for the Clover gambling system.

> **Core rule:** Gambling is optional. A normal run must remain beatable without ever pulling the Clover lever. Clover exists to create volatility, spectacle, greed, desperate recoveries, and self-inflicted disasters.

---

# 1. System Overview

The Clover machine is a **1x3 slot machine** permanently housed in the right-side HUD panel.

The player wagers **Territory**, not Biomass.

The slot does not provide small consolation rewards. It is a **jackpot-only system**:

- Most spins whiff.
- A Path jackpot temporarily unleashes a fully maxed version of one Plant Path.
- Triple Clover triggers every Path jackpot at once.
- Triple Bust is catastrophic.
- Higher stakes risk more of the organism but substantially improve the chance of a positive jackpot.
- There is no gameplay cooldown after a spin. The player only has to wait for the current reel animation to finish.
- The player may spin while previous jackpot effects are still active.
- Repeated jackpot effects may stack.

The slot should feel like a dangerous optional accelerator, not a required progression system.

---

# 2. Relationship to Biomass and Metabolism

Biomass is **not** spent by the Clover machine.

Metabolism continues to develop automatically from **lifetime Biomass earned during the run**.

Current Biomass balance and lifetime Biomass should remain separate values.

Recommended data model:

```gdscript
var biomass_current: float
var biomass_lifetime: float
```

When Biomass is produced:

```gdscript
func add_biomass(amount: float) -> void:
    biomass_current += amount
    biomass_lifetime += amount
```

Metabolism derives its progression from `biomass_lifetime`.

The Clover machine never modifies `biomass_lifetime`.

This separation is important because it prevents gambling losses from undoing permanent run development.

---

# 3. Slot Machine Layout

The machine remains mechanically **1x3**.

```text
┌────────┬────────┬────────┐
│ REEL 1 │ REEL 2 │ REEL 3 │
└────────┴────────┴────────┘
              │
            LEVER
```

There are no paylines beyond the single 1x3 row.

There are no pair rewards.

There is no 3x3 slot logic.

---

# 4. Reel Symbols

The reel vocabulary is:

1. Root
2. Spore
3. Bloom
4. Bramble
5. Pruning
6. Thistle
7. Vine
8. Fruit
9. Clover
10. Bust

Represent these internally with an enum.

```gdscript
enum SlotSymbol {
    ROOT,
    SPORE,
    BLOOM,
    BRAMBLE,
    PRUNING,
    THISTLE,
    VINE,
    FRUIT,
    CLOVER,
    BUST
}
```

---

# 5. Winning Grammar

## 5.1 Path Jackpot

A Path jackpot occurs when the three visible symbols can all resolve to the same Path using Clover as a wild.

Examples:

```text
Bloom | Bloom | Bloom
Bloom | Bloom | Clover
Bloom | Clover | Bloom
Clover | Bloom | Bloom
Bloom | Clover | Clover
Clover | Bloom | Clover
Clover | Clover | Bloom
```

All seven examples above resolve to a **Bloom Jackpot**.

The same rule applies to Root, Spore, Bramble, Pruning, Thistle, Vine, and Fruit.

---

## 5.2 Clover Is Path-Only Wild

Clover may substitute for a missing **Path** symbol.

Clover never substitutes for Bust.

Therefore:

```text
Bust | Bust | Clover
```

is a whiff.

Clover should always read as a positive or potentially positive symbol.

---

## 5.3 Mixed Path + Clover Whiff

Clover does not arbitrarily choose between two different Paths.

Example:

```text
Bloom | Root | Clover
```

is a whiff.

There is no existing pair for Clover to complete.

---

## 5.4 Triple Clover

```text
Clover | Clover | Clover
```

triggers the **Clover Mega Jackpot**.

All eight Path jackpot events activate simultaneously.

---

## 5.5 Triple Bust

```text
Bust | Bust | Bust
```

triggers **Triple Bust**.

Bust severity depends strongly on stake level.

For All In, Triple Bust is an immediate terminal catastrophe.

---

## 5.6 Whiff

Any result that is not:

- a valid Path jackpot,
- Triple Clover,
- or Triple Bust

is a whiff.

A whiff provides no consolation reward.

---

# 6. Stake Levels

Use four discrete stake levels.

| Stake | Fraction of Currently Owned Green | Intended Feeling |
|---|---:|---|
| **Low** | **10%** | Recoverable gamble |
| **Medium** | **25%** | Serious commitment |
| **High** | **50%** | Reckless |
| **ALL IN** | **100%** | Salvation or disaster |

Suggested enum:

```gdscript
enum StakeTier {
    LOW,
    MEDIUM,
    HIGH,
    ALL_IN
}
```

Suggested tuning resource values:

```gdscript
const STAKE_FRACTIONS := {
    StakeTier.LOW: 0.10,
    StakeTier.MEDIUM: 0.25,
    StakeTier.HIGH: 0.50,
    StakeTier.ALL_IN: 1.00,
}
```

The percentage is always calculated from **currently owned Green at the instant the lever is pulled**.

Example:

If the player currently owns 3,000 Green cells:

- Low selects 300 cells.
- Medium selects 750.
- High selects 1,500.
- All In selects all 3,000.

Always round the target count deterministically.

Recommended:

```gdscript
target_cells = maxi(1, roundi(total_owned_cells * stake_fraction))
```

For All In:

```gdscript
target_cells = total_owned_cells
```

---

# 7. Minimum Buy-In

The player must have a meaningful established organism before gambling is allowed.

## Initial tuning target

> **At least 10% of the claimable board must be Established-or-better Green.**

Recommended constant:

```gdscript
const MIN_BUYIN_ESTABLISHED_FRACTION := 0.10
```

Eligibility:

```gdscript
var established_fraction := established_green_cells / float(total_claimable_cells)
var gambling_available := established_fraction >= MIN_BUYIN_ESTABLISHED_FRACTION
```

Use the territory system's existing **Established** maturity threshold.

Do not invent a second maturity definition solely for gambling.

The check should occur every time the player attempts to start a spin.

If the player drops below the minimum buy-in after a bad gamble, the machine becomes unavailable until the organism is rebuilt.

All In obeys the same minimum buy-in.

This prevents a player with a nearly nonexistent organism from using All In as a free lottery ticket.

---

# 8. Slot UI While Below Minimum Buy-In

The machine remains visible.

Do not hide it.

Disable the lever and show a compact explanation such as:

```text
MINIMUM BUY-IN
8.4 / 10.0% Established
```

Avoid a large tutorial panel.

When the requirement is reached, the lever becomes available immediately.

---

# 9. Territory Wager Selection

The wager is not an abstract percentage subtraction.

The player wagers a **physical region of Green territory**.

The region begins around the player's current position and expands through the organism until the required amount of Green has been selected.

The shape should be determined by:

- the current topology of the Green organism,
- player position,
- maturity,
- boundary exposure,
- and connectivity.

The selected region should not be forced into a perfect circle.

---

# 10. Desired Selection Behavior

## Player in the middle of a large patch

If the player is surrounded by Green in every direction, the wager naturally becomes approximately circular.

```text
GGGGGGGGGGGGG
GGGWWWWWWWGGG
GGWWWWWWWWWGG
GGWWWW@WWWWGG
GGWWWWWWWWWGG
GGGWWWWWWWGGG
GGGGGGGGGGGGG
```

`W` = wagered Green.

## Player on the edge

The selection should not extend into territory the player does not own.

It should pull inward through the organism.

```text
..............
....WWWWGGGGGG
....@WWWGGGGGG
....WWWWGGGGGG
....WWWWWGGGGG
....GGGGGGGGGG
```

The result should feel like the machine is taking a chunk of the organism around the player rather than stamping a geometric radius.

---

# 11. Maturity-Aware Selection

The region should prefer meaningful, structurally integrated territory over disposable immature slivers.

Fresh Green is still valid Green and can still be wagered, but it should be less attractive to the selection flood.

The goal is not to alter the wager amount.

The goal is to determine **which cells compose the wager**.

A player choosing Medium always risks exactly 25% of currently owned Green.

---

# 12. Recommended Territory Selection Algorithm

Use a priority flood over Green territory.

Do **not** create physics bodies for territory cells.

Use the existing territory arrays and topology data.

## 12.1 Find the origin

If the player is standing on Green:

```gdscript
origin_cell = player_cell
```

If the player is standing on Neutral or Hostile:

```gdscript
origin_cell = find_nearest_owned_green_cell(player_world_position)
```

If no Green exists, gambling cannot begin.

## 12.2 Cell priority

For each candidate Green cell, calculate a traversal cost.

Recommended starting formula:

```text
step_cost =
    1.00
    + 1.50 * (1 - maturity_normalized)
    + 1.00 * boundary_exposure
```

Where:

- `maturity_normalized` is clamped to `0.0 to 1.0`.
- `boundary_exposure` is the fraction of neighboring cells that are not owned Green.

Example:

```gdscript
func get_step_cost(cell: int) -> float:
    var maturity := clampf(territory_maturity[cell], 0.0, 1.0)
    var exposure := get_boundary_exposure(cell)
    return 1.0 + 1.5 * (1.0 - maturity) + 1.0 * exposure
```

This causes the selection to prefer:

- mature interior Green,
- connected tissue,
- lower-exposure regions,

while still originating near the player.

The exact coefficients are tuning values.

Recommended initial values:

```gdscript
const MATURITY_SELECTION_PENALTY := 1.50
const BOUNDARY_SELECTION_PENALTY := 1.00
```

## 12.3 Priority flood

Use Dijkstra-style expansion.

Pseudo-code:

```gdscript
func build_wager_selection(origin_cell: int, target_count: int) -> PackedInt32Array:
    var selected := PackedInt32Array()
    var visited := {}
    var frontier := MinHeap.new()

    frontier.push(origin_cell, 0.0)

    while not frontier.is_empty() and selected.size() < target_count:
        var entry = frontier.pop()
        var cell: int = entry.cell

        if visited.has(cell):
            continue

        visited[cell] = true

        if not is_owned_green(cell):
            continue

        selected.append(cell)

        for neighbor in get_green_neighbors(cell):
            if visited.has(neighbor):
                continue

            var next_cost := entry.cost + get_step_cost(neighbor)
            frontier.push(neighbor, next_cost)

    return selected
```

Use deterministic tie-breaking, such as cell index, so the preview does not flicker between equivalent cells.

---

# 13. Disconnected Green Components

If the player's connected component does not contain enough Green to satisfy the stake:

1. Select the entire reachable portion according to the normal flood.
2. Find the nearest remaining Green component.
3. Seed a second flood at the nearest Green cell in that component.
4. Continue until the exact target count is reached.
5. Repeat if necessary.

The wager may therefore contain multiple highlighted islands when the organism itself is disconnected.

This is desirable.

The wager should reflect the actual topology of the organism.

---

# 14. All In Selection

All In always selects **100% of currently owned Green**.

Player position does not affect which cells are mechanically selected because all Green is selected.

However, the **preview animation** should visually propagate outward from the player's position until the entire organism is highlighted.

Mechanically, selection should complete immediately.

The propagation is only presentation.

---

# 15. Preview Movement Behavior

The wager preview follows the player.

The committed wager does not.

> **Preview is player-relative. Committed wager is world-relative.**

---

# 16. Preview Update Rate

Do not rebuild the preview mask every rendered frame.

Recommended initial update rate:

```gdscript
const WAGER_PREVIEW_HZ := 10.0
const WAGER_PREVIEW_INTERVAL := 0.10
```

Recompute when:

- the preview is visible,
- the player has moved enough to change the seed cell,
- the stake level changed,
- or territory topology changed.

If the player remains within the same territory cell and nothing meaningful changed, reuse the existing selection.

---

# 17. Preview Visual Relaxation

The logical selection may update at 10 Hz.

The visual transition should be smoother.

Recommended visual blend:

```text
100 to 150 ms
```

Initial value:

```gdscript
const WAGER_VISUAL_BLEND_TIME := 0.12
```

Cells entering the preview fade into the wager treatment.

Cells leaving the preview fade back to normal.

---

# 18. Hover-Only Pulse Rule

The wager region **only pulses while the player is actively interacting with the slot machine or stake meter**.

Pointer behavior:

- Mouse over slot machine: show pulsing preview.
- Mouse over stake meter: show pulsing preview.
- Mouse leaves both: hide preview.

For controller/keyboard, focused slot controls may use the same state so the system remains usable without a mouse.

Do not show the pulsing preview during ordinary gameplay.

---

# 19. Preview Visual Parameters

Recommended initial values:

```text
Preview overlay base alpha: 0.22
Pulse amplitude: +/- 0.08
Pulse frequency: 1.6 Hz
Boundary emphasis: 2 to 3 px equivalent at 1080p
```

The highlight should contrast against Green without obscuring territory detail.

Use the project's existing palette rather than introducing an unrelated casino color scheme.

---

# 20. Stake Change Animation

Switching:

```text
10% -> 25% -> 50% -> 100%
```

should visibly grow the wager region through the organism.

Switching downward should visibly contract it.

Use the same ~120 ms visual blend.

---

# 21. Lever Pull and Commitment

At the exact instant the player successfully pulls the lever:

1. Validate minimum buy-in.
2. Validate the selected stake.
3. Recompute the preview once using the current player position and current territory state.
4. Calculate the target cell count.
5. Snapshot the selected cell IDs.
6. Store the current stake tier.
7. Hide the pulsing preview state.
8. Show the committed wager region as a static highlight.
9. Roll the slot outcome.
10. Start the reel animation.

Recommended structure:

```gdscript
class_name CloverWager
extends RefCounted

var stake_tier: int
var stake_fraction: float
var committed_cells: PackedInt32Array
var owned_green_count_at_commit: int
var commit_time: float
```

---

# 22. Committed Wager Does Not Follow the Player

Once the lever is pulled, movement cannot change the wager.

The player may run anywhere.

The selected region remains fixed in world space.

---

# 23. Territory Changes During a Spin

The world continues running during ordinary spins.

Therefore some committed cells may change state before the reels finish.

## Jackpot

Do not restore or rewind territory lost naturally during the spin.

A jackpot simply means the Clover machine itself does not consume the committed wager.

The highlight disappears.

## Partial-Stake Whiff

For each committed cell:

- If it is still Green at resolution, convert it to Neutral.
- If it is already Neutral, leave it Neutral.
- If it is already Hostile, leave it Hostile.

Never convert Hostile territory to Neutral as an accidental benefit.

## Partial-Stake Triple Bust

For each committed cell:

- Green becomes Hostile.
- Neutral becomes Hostile.
- Hostile remains Hostile.

## All In Whiff

At resolution, convert **all currently owned Green** to Neutral, including Green gained during the short spin.

Then begin the 3-second grace period.

## All In Triple Bust

Convert the entire claimable field to Hostile.

The run ends.

No grace period.

---

# 24. Slot Machine Availability During Events

There is no gameplay cooldown.

The only lever lock is the active reel sequence.

```text
READY -> SPINNING -> READY
```

The machine returns to `READY` as soon as the reel result has fully stopped and the payout has been dispatched.

Do not wait for the jackpot event itself to finish.

---

# 25. Gambling During Active Jackpot Effects

Allowed.

Examples:

- Spin during Root Jackpot.
- Spin during Bramble Jackpot.
- Spin while Pruning is active.
- Spin while Bloom effects are still resolving.
- Spin during Triple Clover.

The machine should not care whether a jackpot effect is already active.

---

# 26. Jackpot Stacking

## Discrete events

Spore and Bloom resolve as discrete events.

A second jackpot simply fires another full event.

## Timed events

Root, Bramble, and Pruning stack by **duration**, not by multiplying Level 5 strength.

Example:

Root has 9 seconds remaining.

The player hits another Root Jackpot.

```text
9 + 15 = 24 seconds remaining
```

Do not double the internal Root strength.

No hard duration cap is required initially.

---

# 27. Jackpot Power Contract

Every Path jackpot invokes that Path as though:

```text
Upgrade 1 = Level 5
Upgrade 2 = Level 5
Upgrade 3 = Level 5
Upgrade 4 = Level 5
```

The player does not need to own that Path.

The jackpot does not permanently grant the Path or its upgrades.

Recommended:

```gdscript
const CASINO_UPGRADE_LEVEL := 5
const CASINO_UPGRADE_VECTOR := [5, 5, 5, 5]
```

Use a temporary casino override rather than permanently mutating the player's build.

---

# 28. Casino Event Context

Recommended shared context object:

```gdscript
class_name CasinoPathContext
extends RefCounted

var is_casino_event := true
var virtual_upgrade_levels := PackedInt32Array([5, 5, 5, 5])
var territory_scale := 1.0
var source_position := Vector2.ZERO
var stake_tier := 0
```

Prefer reusing real Path logic.

Do not create completely separate casino-only versions unless the normal Path mechanic fundamentally cannot represent a one-shot event.

---

# 29. Relic Interaction Rule

Casino events should pass through the normal gameplay effect pipeline where possible.

Recommended rule:

- Universal relics may modify casino events if they normally modify that mechanic.
- Compatible Path relics may modify the casino event if their conditions are actually satisfied.
- The casino does not grant Path ownership.
- Relics that explicitly require the player to own/select a Path should continue to require ownership.

---

# 30. Jackpot Territory Scaling

A jackpot should always feel enormous, even when the player owns little Green.

Use:

> **large guaranteed base spectacle + sublinear scaling from owned Territory**

Recommended scale function:

```text
jackpot_scale = 0.75 + 0.75 * sqrt(owned_fraction)
```

Approximate values:

| Owned Green | Jackpot Scale |
|---:|---:|
| 5% | 0.92x |
| 10% | 0.99x |
| 25% | 1.13x |
| 50% | 1.28x |
| 75% | 1.40x |
| 100% | 1.50x |

Use this scale for event density, number of anchors, area coverage, or generated material.

Do not increase the virtual upgrade level above 5.

---

# 31. Path Jackpot Definitions

## 31.1 Spore Jackpot

**Type:** Discrete board-wide event

At resolution:

1. Create a casino Spore context.
2. Set all four Spore upgrade lines to Level 5.
3. Compute `jackpot_scale`.
4. Trigger a board-wide Spore event using the real Spore germination logic.
5. Allow Dormant Seed Throw, Spore Burst, damaging Seed relics, and other compatible systems to participate normally.

Do not give Spore a temporary timer unless normal maxed Spore mechanics later require one.

## 31.2 Bloom Jackpot

**Type:** Discrete board-wide event

At resolution:

1. Create a casino Bloom context.
2. Set all four Bloom upgrade lines to Level 5.
3. Compute `jackpot_scale`.
4. Trigger multiple Bloom events distributed across meaningful fronts or enemy concentrations.
5. Use the existing Bloom material physics.
6. Use normal Force, Mass, Satellite Bloom, Aftershock, impact, drag, wetting, and collision behavior.

Do not replace the physical Bloom simulation with a fake screen-wide damage pulse.

## 31.3 Root Jackpot

**Type:** Timed global event

**Base duration:** **15.0 seconds**

```gdscript
const ROOT_JACKPOT_DURATION := 15.0
```

During the effect:

- Root behaves as though all four upgrades are Level 5.
- The effect applies globally to eligible current Green.
- Newly created eligible Green during the timer should also receive the temporary Root behavior when appropriate.
- Existing root visuals should become clearly more active.
- Jackpot stacking adds another 15 seconds.

## 31.4 Bramble Jackpot

**Type:** Timed global event

**Initial duration:** **10.0 seconds**

```gdscript
const BRAMBLE_JACKPOT_DURATION := 10.0
```

During the effect:

- Bramble behaves as though all four upgrades are Level 5.
- Bramble should use its real knockback identity.
- Enemy mass, impulse, collision, and Bramble-specific physical responses continue to operate normally.
- Jackpot stacking adds another 10 seconds.

Recommended tuning band:

```text
8 to 12 seconds
```

Start at 10.

## 31.5 Pruning Jackpot

**Type:** Timed global event

**Initial duration:** **10.0 seconds**

```gdscript
const PRUNING_JACKPOT_DURATION := 10.0
```

During the effect:

- Pruning behaves as though all four upgrades are Level 5.
- The casino supplies generated clippings.
- The jackpot must not consume the player's real Green merely to operate.
- Angular momentum, orbiting behavior, release speed, ring behavior, and other real Pruning physics should remain intact.
- Jackpot stacking adds another 10 seconds.

## 31.6 Thistle Jackpot

**Type:** Timed global event

**Initial duration:** **10.0 seconds**

- Thistle behaves as though all four standard lines are Level 5.
- The network immediately establishes its five-turret ceiling where Green support
  exists and fires one readable bonus volley at current targets.
- The loan does not grant Thistle ownership or relic eligibility.
- Repeat jackpots add another 10 seconds.

## 31.7 Vine Jackpot

**Type:** Timed global event

**Initial duration:** **10.0 seconds**

- Vine behaves as though all four standard lines are Level 5.
- It immediately performs one green bonus sweep aimed at the targetable 90-degree
  sector containing the most enemies.
- The automatic Vine cadence continues for the rest of the loan.
- Repeat jackpots add another 10 seconds.

## 31.8 Fruit Jackpot

**Type:** Timed global event

**Initial duration:** **10.0 seconds**

- Fruit behaves as though all four standard lines are Level 5.
- It immediately releases the full six-Fruit batch; every Fruit uses its own trail,
  dense-sector fan trajectory, and randomized painting.
- Further batches use Fruit's normal wait-for-explosion plus one-second cooldown.
- Repeat jackpots add another 10 seconds.

## 31.9 Triple Clover

At resolution:

1. Compute `jackpot_scale` once.
2. Fire Spore Jackpot.
3. Fire Bloom Jackpot.
4. Add 15 seconds of Root Jackpot.
5. Add 10 seconds of Bramble Jackpot.
6. Add 10 seconds of Pruning Jackpot.
7. Add 10 seconds of Thistle Jackpot.
8. Add 10 seconds of Vine Jackpot.
9. Add 10 seconds of Fruit Jackpot.
10. Allow all eight systems to coexist.

Do not serialize the Path effects one after another.

---

# 32. Triple Bust Behavior

## Low, Medium, High

For the committed wager region:

```text
Green -> Hostile
Neutral -> Hostile
Hostile -> Hostile
```

The hostile conversion itself is the catastrophe.

If later testing shows Low-stake Triple Bust feels too weak, add a local hostile surge around the wound rather than changing unrelated global numbers.

## All In Triple Bust

All claimable territory becomes Hostile.

Then the run ends.

No 3-second grace period.

No rescue threshold.

---

# 33. Whiff Behavior

## Low, Medium, High

The committed region becomes Neutral.

The loss is localized and visible.

Do not distribute erosion across the whole board.

Do not merely subtract a Territory percentage number.

---

# 34. All In Whiff

At result resolution:

1. Convert all current owned Green to Neutral.
2. Suspend the ordinary zero-Territory loss check.
3. Begin a **3.0-second grace period**.
4. Display a large center-screen countdown.
5. Continue normal gameplay.
6. Allow existing Path and jackpot effects to continue.
7. The player must reclaim enough Green before the timer reaches 0.
8. Success returns the game to normal.
9. Failure ends the run.

---

# 35. All In Grace Period Numbers

```gdscript
const ALL_IN_GRACE_DURATION := 3.0
```

Initial recommended survival threshold:

> **Reclaim at least 5% of the claimable board before the timer reaches 0.**

```gdscript
const ALL_IN_RECOVERY_THRESHOLD := 0.05
```

Recommended tuning band:

```text
3% to 7%
```

Start at 5%.

Use raw owned Green for this emergency threshold.

Do not require Established maturity.

---

# 36. All In Countdown UI

The countdown appears in the middle of the arena.

Initial layout target at 1080p:

```text
       2.4

   RECLAIM 5%
```

Recommended:

```text
Countdown font size: ~96 px at 1080p
Secondary text: ~24 to 30 px
```

Display tenths continuously:

```text
3.0
2.9
2.8
...
0.1
0.0
```

Provide strong audiovisual hits at 3, 2, and 1.

The game does **not** pause.

---

# 37. Grace Period Success and Failure

Success:

```gdscript
if owned_green_fraction >= ALL_IN_RECOVERY_THRESHOLD:
    end_all_in_grace_success()
```

On success:

- remove countdown,
- restore normal zero-Territory defeat checks,
- do not grant bonus Territory,
- continue the run.

Failure:

```gdscript
if grace_time_remaining <= 0.0 and owned_green_fraction < ALL_IN_RECOVERY_THRESHOLD:
    trigger_run_loss()
```

The visible timer and backend deadline must match.

---

# 38. Existing Effects During All In Grace

All currently active gameplay systems continue.

Examples:

- Root Jackpot continues.
- Bramble Jackpot continues.
- Pruning Jackpot continues.
- Bloom droplets continue moving.
- Existing Seeds can germinate.
- Relics continue functioning.
- Enemies continue moving.

This allows improbable jackpot-assisted recoveries.

---

# 39. Odds Architecture

Do not use a strict marble bag.

Use **outcome-first RNG with soft pseudo-random drought protection**.

The backend determines the result class first.

The visible reels are then constructed to represent that legitimate result.

---

# 40. Initial Base Odds

These values are **initial playtest targets**, not permanent balance numbers.

| Stake | Path Jackpot | Triple Clover | Positive Total | Triple Bust | Whiff |
|---|---:|---:|---:|---:|---:|
| **Low 10%** | 9.5% | 0.5% | **10%** | 0.5% | **89.5%** |
| **Medium 25%** | 21% | 1% | **22%** | 2% | **76%** |
| **High 50%** | 38% | 2% | **40%** | 7% | **53%** |
| **ALL IN 100%** | 55% | 5% | **60%** | 15% | **25%** |

With a normal spin taking roughly 1.55 seconds:

| Stake | Base Positive Chance | Average Spins per Positive Jackpot | Approx. Spin Time |
|---|---:|---:|---:|
| Low | 10% | 10.0 | 15.5 sec |
| Medium | 22% | 4.55 | 7.0 sec |
| High | 40% | 2.5 | 3.9 sec |
| All In | 60% | 1.67 | 2.6 sec |

The player is trading territory risk for time and probability.

---

# 41. Odds Config Resource

Create a data-driven resource.

```gdscript
class_name CloverStakeOdds
extends Resource

@export var stake_fraction: float
@export var path_jackpot_chance: float
@export var triple_clover_chance: float
@export var triple_bust_chance: float
```

Recommended initial values:

```text
LOW:
  stake_fraction = 0.10
  path_jackpot_chance = 0.095
  triple_clover_chance = 0.005
  triple_bust_chance = 0.005

MEDIUM:
  stake_fraction = 0.25
  path_jackpot_chance = 0.21
  triple_clover_chance = 0.01
  triple_bust_chance = 0.02

HIGH:
  stake_fraction = 0.50
  path_jackpot_chance = 0.38
  triple_clover_chance = 0.02
  triple_bust_chance = 0.07

ALL_IN:
  stake_fraction = 1.00
  path_jackpot_chance = 0.55
  triple_clover_chance = 0.05
  triple_bust_chance = 0.15
```

Whiff is the remainder.

---

# 42. Path Jackpot Identity

After a Path Jackpot outcome is chosen, select the Path uniformly.

```text
Root: 20%
Spore: 20%
Bloom: 20%
Bramble: 20%
Pruning: 20%
```

Do not apply Path-specific pity.

---

# 43. Soft Jackpot Drought Protection

Begin protection only after a meaningful drought.

| Consecutive Spins Without Positive Jackpot | Extra Path Jackpot Chance |
|---:|---:|
| 0 to 4 | +0 pp |
| 5 | +3 pp |
| 6 | +6 pp |
| 7 | +10 pp |
| 8 | +15 pp |
| 9 | +22 pp |
| 10+ | +30 pp |

The added probability comes only from Whiff.

Do not increase Triple Bust.

Do not increase Triple Clover.

A positive jackpot resets the drought counter for that stake tier.

---

# 44. Drought Counter by Stake Tier

Maintain a separate drought counter for each stake.

```gdscript
var drought_by_stake := {
    StakeTier.LOW: 0,
    StakeTier.MEDIUM: 0,
    StakeTier.HIGH: 0,
    StakeTier.ALL_IN: 0,
}
```

This prevents cheap Low bets from charging pity for All In.

---

# 45. Positive Chance Caps

Recommended maximum positive chance after drought protection:

```text
Low: 40%
Medium: 55%
High: 60%
All In: 70%
```

The added chance increases Path Jackpot only.

Triple Clover remains fixed.

---

# 46. Triple Bust Anti-Streak Protection

Triple Bust should not happen twice in a row.

After any Triple Bust:

```text
Next spin: 0% Triple Bust
Second spin after: 50% of normal Triple Bust chance
Third spin onward: normal chance
```

If Bust probability is reduced, move the removed probability into **Whiff**, not Jackpot.

---

# 47. Triple Clover Has No Pity

Triple Clover remains fixed at its stake-dependent base chance.

Do not guarantee one per run.

---

# 48. Truthful Odds Display

If the UI displays odds, show the **actual current effective probability** after:

- stake selection,
- drought protection,
- Bust suppression.

Recommended compact UI:

```text
HIGH
50% TERRITORY

JACKPOT 47%
BUST 7%
```

Detailed odds may live in a tooltip.

---

# 49. Outcome Roll

Recommended:

```gdscript
func roll_outcome(stake: int) -> CloverOutcome:
    var odds := get_effective_odds(stake)
    var r := rng.randf()

    if r < odds.triple_clover:
        return CloverOutcome.TRIPLE_CLOVER

    r -= odds.triple_clover

    if r < odds.path_jackpot:
        return CloverOutcome.PATH_JACKPOT

    r -= odds.path_jackpot

    if r < odds.triple_bust:
        return CloverOutcome.TRIPLE_BUST

    return CloverOutcome.WHIFF
```

Use one deterministic run RNG source.

---

# 50. Constructing Visible Reel Results

The backend result is rolled when the lever is pulled.

Payout occurs after the reels stop.

The reel animation reveals the predetermined result.

---

# 51. Path Jackpot Display Mix

For selected Path `P`:

| Display Pattern | Weight |
|---|---:|
| `P / P / P` | 60% |
| two `P` + one Clover | 30% |
| one `P` + two Clovers | 10% |

Randomize Clover position uniformly.

---

# 52. Triple Clover and Bust Displays

Triple Clover:

```text
Clover | Clover | Clover
```

Triple Bust:

```text
Bust | Bust | Bust
```

---

# 53. Whiff Display Construction

Recommended:

```text
75% ordinary whiff
25% tease whiff
```

## Ordinary whiff

Generate a nonwinning combination where Reel 1 and Reel 2 are not identical.

## Tease whiff

The first two reels match exactly.

Recommended mix:

| Type | Share of Tease Whiffs |
|---|---:|
| Matching Path pair, third misses | 70% |
| Clover / Clover / Bust | 15% |
| Bust / Bust / non-Bust | 15% |

This keeps the slowdown uncertain.

---

# 54. Reel Animation Timing

## Normal spin

| Event | Time |
|---|---:|
| Lever pull | 0.00 sec |
| Reel 1 stop | **0.65 sec** |
| Reel 2 stop | **1.05 sec** |
| Reel 3 stop | **1.55 sec** |
| Machine ready | **~1.70 sec** |

Use acceleration, fast spin, deceleration, lock, and a tiny settle.

Recommended normal settle:

```text
4 to 8 px overshoot
50 to 80 ms return
```

---

# 55. Matching First Two Reels Slowdown

If Reel 1 and Reel 2 stop on the **same exact symbol**, Reel 3 enters the special slowdown.

Examples:

```text
Bloom | Bloom | ?
Root | Root | ?
Clover | Clover | ?
Bust | Bust | ?
```

This also occurs on tease whiffs.

---

# 56. Slowdown Timing

Recommended:

| Event | Time |
|---|---:|
| Reel 1 stop | 0.65 sec |
| Reel 2 stop | 1.05 sec |
| Slowdown begins | 1.05 sec |
| Reel becomes individually readable | ~1.65 sec |
| Reel 3 lock | **2.45 sec** |

Start at:

```gdscript
const TEASE_REEL_3_STOP_TIME := 2.45
```

---

# 57. First Matching-Pair Cinematic Per Run

The first time in each run that Reel 1 and Reel 2 match:

- pause gameplay,
- visually zoom/focus on the slot machine,
- allow Reel 3 to continue,
- perform the special slowdown,
- resolve Reel 3,
- return the slot to normal,
- resume gameplay.

This occurs whether the result becomes a jackpot, whiff, or Triple Bust.

---

# 58. First Cinematic Flag and Timing

```gdscript
var first_pair_focus_used := false
```

Recommended timing:

```text
Reel 2 stops: 1.05 sec
Pause begins: immediately
Focus in: 0.30 sec
Focused third-reel tease: ~0.95 sec
Result recognition: 0.10 sec
Focus out: 0.30 sec
Resume gameplay
```

Total gameplay pause target:

```text
~1.6 to 1.8 seconds
```

---

# 59. Godot Pause Implementation

Because the slot is UI, it must continue animating while the world is paused.

Recommended:

```gdscript
get_tree().paused = true
```

Slot-related nodes:

```gdscript
process_mode = Node.PROCESS_MODE_ALWAYS
```

Tweens:

```gdscript
var tween := create_tween()
tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
```

Use a centralized pause manager if the project already has one.

---

# 60. Zooming a HUD Slot in Godot

Because the machine lives in a `CanvasLayer`, `Camera2D.zoom` will not enlarge it.

Recommended approach:

- keep the normal slot in the right HUD,
- create a `SlotFocusLayer`,
- use a `SlotFocusProxy` that mirrors the current three reel visuals,
- dim the normal HUD,
- animate the proxy toward a larger focused presentation,
- restore the normal slot after the reveal.

Suggested focus scale:

```text
1.7x
```

Suggested arena dim:

```text
10 to 18%
```

Suggested other HUD opacity:

```text
40 to 60%
```

---

# 61. Later Matching-Pair Teases

After the first cinematic:

- do not pause,
- do not perform the full zoom,
- still slow Reel 3,
- optionally scale the slot to ~1.12x,
- optionally move it 20 to 30 px inward,
- return after Reel 3 locks.

---

# 62. Tease Audiovisual Language

## Matching Path pair

Use a rising mechanical tone.

## Clover pair

Use a brighter, stranger version.

## Bust pair

Use lower-pitched tension and machine rattle.

Do not reveal the final outcome before Reel 3 locks.

---

# 63. Rare Jackpot Rewind Easter Egg

Approximately **10% of eligible successful Path jackpots** use the fakeout rewind.

```gdscript
const JACKPOT_REWIND_CHANCE := 0.10
```

Eligibility:

- normal Path Jackpot,
- Reel 1 and Reel 2 match exactly,
- Reel 3 slowdown is active,
- not Triple Clover,
- not Triple Bust,
- not a whiff.

---

# 64. Rewind Animation

Sequence:

1. required final symbol approaches,
2. crosses the payline,
3. scrolls fully past,
4. brief fake-miss pause,
5. Reel 3 quickly reverses,
6. required symbol snaps back into place,
7. hard mechanical lock,
8. jackpot fires.

Recommended timings:

```text
Slow pass: 0.50 sec
Hold: 0.14 sec
Reverse snap: 0.16 sec
```

Total tease may extend to roughly 2.75 to 2.90 seconds.

Never use this animation for whiffs or Triple Busts.

---

# 65. Result Recognition Beat

After a meaningful final lock, wait:

```text
80 to 120 ms
```

Start at:

```gdscript
const RESULT_RECOGNITION_BEAT := 0.10
```

Then dispatch the battlefield event.

---

# 66. Wager Region Result Visuals

## Jackpot

Committed highlight fades back to normal Green over roughly:

```text
120 to 180 ms
```

## Whiff

The committed region drains to Neutral over:

```text
250 to 450 ms
```

## Triple Bust

The committed region converts to Hostile over:

```text
250 to 500 ms
```

## All In Triple Bust

Rapid field-wide hostile flood:

```text
0.60 to 0.90 sec
```

Then loss presentation.

---

# 67. Stake Meter UI

Use a notched selector:

```text
LOW    MED    HIGH    ALL IN
10%    25%    50%     100%
```

Default to Low on first unlock.

Remember the player's selected stake for the rest of the run.

---

# 68. HUD Information Priority

Default machine UI should show only:

- selected stake,
- Territory percentage at risk,
- current positive jackpot chance,
- current Triple Bust chance,
- lever state.

Example:

```text
HIGH
50% TERRITORY

JACKPOT 40%
BUST 7%
```

Detailed odds belong in a tooltip.

---

# 69. Slot Machine State Machine

Recommended machine states:

```gdscript
enum CloverMachineState {
    READY,
    SPINNING,
    FIRST_PAIR_FOCUS
}
```

Do not put active Path effects into this state machine.

---

# 70. Suggested Godot Node Structure

```text
Main
├── TerritorySystem
├── Player
├── Progression
├── CloverGamblingController
│   ├── CloverOddsController
│   ├── WagerSelector
│   ├── CloverEventRouter
│   └── AllInGraceController
├── CanvasLayer_HUD
│   ├── RightPanel
│   │   └── CloverMachineUI
│   │       ├── Reel1
│   │       ├── Reel2
│   │       ├── Reel3
│   │       ├── StakeMeter
│   │       ├── OddsReadout
│   │       └── LeverButton
│   ├── WagerOverlay
│   └── AllInCountdown
└── CanvasLayer_Focus
    ├── FocusDim
    └── SlotFocusProxy
```

---

# 71. Responsibility Separation

## `CloverGamblingController`

Owns:

- machine state,
- current stake,
- committed wager,
- outcome roll,
- reel result,
- spin lifecycle.

## `CloverOddsController`

Owns:

- base odds,
- effective odds,
- drought counters,
- Bust cooldown,
- Path selection.

## `WagerSelector`

Owns:

- preview region,
- player-relative flood,
- maturity-aware selection,
- disconnected component overflow,
- committed mask construction.

## `CloverEventRouter`

Owns:

- Path jackpot dispatch,
- Triple Clover dispatch,
- Triple Bust dispatch,
- whiff territory conversion.

## `AllInGraceController`

Owns:

- 3-second grace timer,
- defeat suppression,
- recovery threshold,
- center countdown UI,
- success/failure transition.

---

# 72. Signals

Recommended:

```gdscript
signal wager_preview_changed(cells: PackedInt32Array)
signal wager_committed(wager: CloverWager)

signal spin_started(stake_tier: int)
signal reel_stopped(reel_index: int, symbol: int)
signal pair_tease_started(symbol: int)
signal spin_resolved(outcome: int)

signal path_jackpot_started(path_id: int)
signal triple_clover_started()
signal triple_bust_started(stake_tier: int)
signal whiff_started(stake_tier: int)

signal all_in_grace_started(duration: float)
signal all_in_grace_recovered()
signal all_in_grace_failed()
```

Use signals so the slot UI does not directly mutate territory systems.

---

# 73. Run Reset

At run start:

```gdscript
current_stake = StakeTier.LOW
first_pair_focus_used = false

for stake in drought_by_stake:
    drought_by_stake[stake] = 0

spins_since_triple_bust = 999

clear_committed_wager()
cancel_all_in_grace()
clear_slot_focus()
```

Timed casino Path duration counters also reset.

---

# 74. Input Rules

The player cannot start another spin while reels are moving.

Do not queue a second spin.

The player must explicitly pull again after the machine returns to Ready.

---

# 75. Performance Targets

Initial targets:

```text
Wager preview rebuild: < 1.5 ms
Average preview CPU cost at 10 Hz: < 0.15 ms/frame equivalent
Committed wager snapshot: < 2.0 ms
Odds roll: negligible
```

If preview is too expensive:

1. reuse connected-component labels,
2. reuse maturity/exposure caches,
3. update only when player changes cell,
4. reduce preview to 8 Hz,
5. reuse arrays and heap storage.

---

# 76. Allocation Strategy

Avoid per-preview garbage.

Recommended:

- reuse scratch arrays,
- reuse a visited-generation array,
- use integer generation IDs,
- pool priority-queue storage if necessary,
- reuse visual mask buffers.

Do not create one Node or Sprite per wagered territory cell.

---

# 77. Territory Overlay Rendering

Use the existing territory renderer if possible.

Preferred:

- secondary wager mask texture,
- shader channel,
- or existing batched grid drawing.

Provide two logical overlay modes:

```text
PREVIEW_PULSE
COMMITTED_STATIC
```

---

# 78. Debug Views

Recommended development toggles:

```text
F6: Clover wager debug
F7: Clover odds debug
```

Wager debug should show:

- seed cell,
- target count,
- selected count,
- maturity,
- boundary exposure,
- component ID,
- priority,
- committed mask.

Odds debug should show:

- selected stake,
- base Path jackpot,
- drought bonus,
- Triple Clover,
- base Bust,
- Bust multiplier,
- final Whiff,
- drought count,
- predetermined result.

---

# 79. Telemetry

Log during internal testing:

```text
run_id
wave
time
stake_tier
owned_green_before_spin
established_green_before_spin
drought_count
effective_path_jackpot_chance
triple_clover_chance
triple_bust_chance
outcome
reel_symbols
first_pair_match
rewind_easter_egg
owned_green_after_result
all_in_grace_success
all_in_grace_recovery_time
```

Key questions:

- Which stakes do players actually use?
- Are Low bets being spammed?
- How many jackpots occur per run?
- How often does All In save or kill a run?
- Are long droughts still happening?
- Are Busts memorable rather than merely frustrating?

---

# 80. Initial Tuning Targets

| Metric | Starting Target |
|---|---:|
| Players who gamble at least once | 60 to 85% |
| Positive jackpots for an active gambler in 15 min | 3 to 6 |
| Triple Clover | Rare, often 0 per run |
| Triple Bust | Uncommon but visible across several runs |
| All In recovery success | 20 to 40% |
| Rewind Easter egg | 10% of eligible Path jackpots |
| First pair cinematic | Exactly once per run |
| Root Jackpot | 15 sec |
| Bramble Jackpot | 10 sec |
| Pruning Jackpot | 10 sec |
| Thistle Jackpot | 10 sec |
| Vine Jackpot | 10 sec |
| Fruit Jackpot | 10 sec |
| All In grace | 3 sec |
| Grace recovery threshold | 5% claimable board |
| Minimum buy-in | 10% Established+ board |

---

# 81. Balance Rule: Clover Must Not Be Required

Do not tune normal Path numbers under the assumption that Clover jackpots will rescue the player.

A coherent build and skilled play must be sufficient to win a normal run without using the slot.

Clover increases:

- variance,
- spectacle,
- comeback potential,
- greed,
- power ceiling,
- and self-inflicted danger.

It does not supply missing baseline power.

---

# 82. Balance Rule: Higher Stakes Must Have a Reason to Exist

Because jackpot strength does not directly scale with stake, higher stakes must buy meaningfully better odds and much faster access to jackpots.

If Low becomes obviously optimal because players can spam 10% bets:

1. increase Medium/High positive probability,
2. reduce Low positive probability,
3. rely on real-time combat pressure,
4. only then consider additional anti-spam rules.

Do not add a lever cooldown unless repeated playtesting proves it necessary.

---

# 83. Balance Rule: Do Not Make Whiffs Harmless

Low losing 10% should be recoverable but visible.

Medium losing 25% should create a serious wound.

High losing 50% should be alarming.

All In whiff should create a genuine 3-second emergency.

If Green passively reclaims these too quickly, inspect reclaim rate, wound topology, maturity loss, roots, and enemy pressure before increasing stake values.

---

# 84. Balance Rule: Bust Is Qualitatively Worse Than Whiff

Whiff:

```text
Green -> Neutral
```

Bust:

```text
Committed region -> Hostile
```

All In Bust:

```text
Entire field -> Hostile -> Run Loss
```

---

# 85. Wager Preview Test Cases

Automated and manual tests:

### Center of large patch
- compact approximately radial selection,
- exact target count.

### Edge
- pulls inward,
- no selection outside Green.

### Thin immature peninsula
- does not stop at disposable fresh tissue if selection needs to reach integrated territory.

### Neutral or Hostile under player
- nearest Green becomes seed.

### Disconnected islands
- local component first,
- nearest remaining component next.

### All In
- every Green cell selected.

---

# 86. Movement Preview Tests

While preview is active:

1. move through center Green,
2. verify region follows,
3. move to edge,
4. verify inward deformation,
5. move onto Neutral,
6. verify nearest Green seed,
7. switch stake while moving,
8. verify exact target count,
9. stop hovering,
10. verify preview disappears.

---

# 87. Commitment Tests

1. Preview Medium.
2. Pull lever.
3. Move across the arena.
4. Verify committed region remains fixed.
5. Change territory state during spin.
6. Resolve whiff.
7. Verify only still-Green committed cells become Neutral.
8. Verify already-Hostile cells do not become Neutral.

---

# 88. Odds Tests

Run at least:

```text
1,000,000 simulated spins per stake
```

Verify:

- base frequencies,
- drought thresholds,
- drought reset,
- Triple Clover fixed odds,
- immediate post-Bust immunity,
- 50% Bust probability on second post-Bust spin,
- normal Bust probability afterward,
- removed Bust probability becomes Whiff.

---

# 89. Reel Construction Tests

For at least 100,000 generated displays per outcome class:

- Path Jackpot resolves to selected Path.
- Triple Clover is exactly Clover/Clover/Clover.
- Triple Bust is exactly Bust/Bust/Bust.
- Whiff cannot accidentally resolve as a jackpot.
- Clover never completes Bust.
- `Path A / Path B / Clover` remains a whiff.

---

# 90. Slowdown Tests

Verify:

```text
Reel 1 == Reel 2
```

always triggers Reel 3 slowdown.

Verify:

```text
Reel 1 != Reel 2
```

does not.

The visible first two reels are authoritative.

---

# 91. First Cinematic Tests

Per run:

- first matching pair pauses/focuses,
- later matching pairs do not pause,
- slot UI continues processing while paused,
- world simulation stops,
- result resolves correctly,
- pause state restores correctly,
- run reset restores first-focus eligibility.

---

# 92. Rewind Easter Egg Tests

Verify:

- ~10% of eligible Path jackpots,
- never changes backend result,
- never occurs on whiff,
- never occurs on Triple Bust,
- always lands on the predetermined winning symbol.

Use deterministic seeds so it can be reproduced.

---

# 93. All In Grace Tests

### Whiff

Verify:

- all current Green becomes Neutral,
- zero-Territory loss is suspended,
- countdown begins at exactly 3.0,
- gameplay continues,
- threshold success ends grace,
- 0.0 failure ends run.

### Triple Bust

Verify:

- entire claimable field becomes Hostile,
- no countdown,
- no grace,
- run ends.

### Existing effects

Verify timed and discrete jackpot effects continue through grace.

---

# 94. Recommended Implementation Order

## Phase 1: Data and Odds
- enums,
- stake config,
- base odds,
- outcome-first roll,
- deterministic reel construction,
- unit tests.

## Phase 2: Wager Selection
- minimum buy-in,
- player-relative seed,
- priority flood,
- exact target count,
- disconnected components,
- debug overlay.

## Phase 3: Preview Interaction
- hover-only preview,
- 10 Hz rebuild,
- 120 ms visual relaxation,
- movement-following behavior,
- stake changes.

## Phase 4: Commitment and Territory Outcomes
- snapshot on lever pull,
- static committed mask,
- whiff -> Neutral,
- Bust -> Hostile,
- jackpot preservation.

## Phase 5: Reel Presentation
- 0.65 / 1.05 / 1.55 timing,
- mechanical settle,
- first-pair matching,
- 2.45-second Reel 3 tease.

## Phase 6: First Pair Cinematic
- once-per-run flag,
- paused world,
- focus proxy,
- ~1.7x slot focus.

## Phase 7: Jackpot Dispatch
- virtual `[5,5,5,5]`,
- Spore,
- Bloom,
- Root 15 sec,
- Bramble 10 sec,
- Pruning 10 sec with casino clippings,
- Triple Clover.

## Phase 8: Stacking
- repeated discrete events,
- timed duration addition,
- simultaneous Path effects.

## Phase 9: All In
- 100% preview,
- 3-second grace,
- 5% recovery threshold,
- center countdown,
- terminal Triple Bust.

## Phase 10: Odds Protection
- per-stake drought counters,
- positive caps,
- Bust anti-streak,
- truthful current odds.

## Phase 11: Rare Presentation
- 10% rewind Easter egg,
- unique audio,
- optional special Triple Clover variants.

---

# 95. Acceptance Criteria

- [ ] Slot is 1x3.
- [ ] Territory is wagered.
- [ ] Low = 10%.
- [ ] Medium = 25%.
- [ ] High = 50%.
- [ ] All In = 100%.
- [ ] Minimum buy-in is enforced.
- [ ] Preview originates around the player.
- [ ] Preview follows player movement.
- [ ] Preview pulls inward at edges.
- [ ] Preview is maturity-aware.
- [ ] Preview pulses only while interacting with the slot or stake meter.
- [ ] Lever pull freezes the exact wager region.
- [ ] Whiffs convert wagered Green to Neutral.
- [ ] Busts convert the wager region to Hostile.
- [ ] All In whiff starts a 3-second recovery state.
- [ ] All In Triple Bust turns the full field Hostile and ends the run.
- [ ] Path jackpots use virtual Level 5 across all four upgrades.
- [ ] Root lasts 15 sec.
- [ ] Bramble starts at 10 sec.
- [ ] Pruning starts at 10 sec.
- [ ] Pruning gets casino-generated clippings.
- [ ] Triple Clover fires all eight Path jackpots.
- [ ] Player may spin during active jackpots.
- [ ] Timed jackpots stack by duration.
- [ ] No lever cooldown exists beyond reel animation.
- [ ] Outcome-first RNG is implemented.
- [ ] Soft drought protection is implemented.
- [ ] Triple Bust cannot occur twice consecutively.
- [ ] Displayed odds are truthful.
- [ ] Reel 1 stops near 0.65 sec.
- [ ] Reel 2 stops near 1.05 sec.
- [ ] Reel 3 normally stops near 1.55 sec.
- [ ] Matching first two reels slow Reel 3 to ~2.45 sec.
- [ ] First matching pair per run triggers paused focus cinematic.
- [ ] Later pairs do not pause.
- [ ] 10% eligible jackpot rewind animation exists.
- [ ] Gambling is not required to beat a normal run.
- [ ] Automated odds and reel-validity tests pass.

---

# 96. Initial Constants Sheet

```text
MIN_BUYIN_ESTABLISHED_FRACTION = 0.10

LOW_STAKE = 0.10
MEDIUM_STAKE = 0.25
HIGH_STAKE = 0.50
ALL_IN_STAKE = 1.00

LOW_PATH_JACKPOT = 0.095
LOW_TRIPLE_CLOVER = 0.005
LOW_TRIPLE_BUST = 0.005

MEDIUM_PATH_JACKPOT = 0.21
MEDIUM_TRIPLE_CLOVER = 0.01
MEDIUM_TRIPLE_BUST = 0.02

HIGH_PATH_JACKPOT = 0.38
HIGH_TRIPLE_CLOVER = 0.02
HIGH_TRIPLE_BUST = 0.07

ALL_IN_PATH_JACKPOT = 0.55
ALL_IN_TRIPLE_CLOVER = 0.05
ALL_IN_TRIPLE_BUST = 0.15

DROUGHT_START_AFTER = 4 misses
DROUGHT_BONUS_5 = +0.03
DROUGHT_BONUS_6 = +0.06
DROUGHT_BONUS_7 = +0.10
DROUGHT_BONUS_8 = +0.15
DROUGHT_BONUS_9 = +0.22
DROUGHT_BONUS_10_PLUS = +0.30

LOW_POSITIVE_CAP = 0.40
MEDIUM_POSITIVE_CAP = 0.55
HIGH_POSITIVE_CAP = 0.60
ALL_IN_POSITIVE_CAP = 0.70

POST_BUST_NEXT_SPIN_MULTIPLIER = 0.0
POST_BUST_SECOND_SPIN_MULTIPLIER = 0.5
POST_BUST_THIRD_PLUS_MULTIPLIER = 1.0

WAGER_PREVIEW_HZ = 10.0
WAGER_VISUAL_BLEND_TIME = 0.12
WAGER_PREVIEW_ALPHA = 0.22
WAGER_PREVIEW_PULSE_AMPLITUDE = 0.08
WAGER_PREVIEW_PULSE_HZ = 1.6

MATURITY_SELECTION_PENALTY = 1.50
BOUNDARY_SELECTION_PENALTY = 1.00

REEL_1_STOP = 0.65
REEL_2_STOP = 1.05
REEL_3_NORMAL_STOP = 1.55
REEL_3_TEASE_STOP = 2.45

FIRST_FOCUS_SCALE = 1.70
FIRST_FOCUS_IN_TIME = 0.30
FIRST_FOCUS_OUT_TIME = 0.30

JACKPOT_REWIND_CHANCE = 0.10
REWIND_PASS_TIME = 0.50
REWIND_HOLD_TIME = 0.14
REWIND_SNAP_TIME = 0.16

RESULT_RECOGNITION_BEAT = 0.10

ROOT_JACKPOT_DURATION = 15.0
BRAMBLE_JACKPOT_DURATION = 10.0
PRUNING_JACKPOT_DURATION = 10.0

ALL_IN_GRACE_DURATION = 3.0
ALL_IN_RECOVERY_THRESHOLD = 0.05

JACKPOT_SCALE_BASE = 0.75
JACKPOT_SCALE_SQRT_COEFFICIENT = 0.75
```

---

# 97. Final Design Principles

1. **The wager must be visible.** The player sees the exact part of the organism being risked.
2. **The wager must hurt.** Whiffing creates a real territorial wound.
3. **Bust is qualitatively worse than whiff.** Neutral versus Hostile is the core distinction.
4. **Jackpots are enormous.** No small payouts.
5. **The arena is the payout screen.** The main spectacle happens on the battlefield.
6. **Higher stakes buy volatility and urgency.**
7. **The player may behave irresponsibly.** No cooldown after the reels finish.
8. **All In is literal.** 100% of the organism is on the table.
9. **All In whiff still creates gameplay.** Exactly 3 seconds to recover.
10. **All In Bust has no mercy.** The field becomes Hostile and the run ends.
11. **The slot should be understandable without a manual.**
12. **The backend may protect against ugly randomness, but displayed odds must be truthful.**
13. **The machine must never become mandatory.**
14. **Physics determines the shape of the wager.**
15. **Preview follows the player. Commitment does not.**
