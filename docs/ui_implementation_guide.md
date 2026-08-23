# Territory Roguelike — UI Implementation Guide

> **Goal:** Create the cleanest possible combat UI while still exposing the information players need to make good decisions.
>
> **Core principle:** The game should feel like a **physics simulation with a restrained scientific instrument panel**, not an incremental dashboard with a game happening beside it.
>
> **Primary rule:** Minimize the number of things the player has to consciously parse at once.

---

# 1. UI Architecture

Use three clear information layers.

## Right Sidebar — Current State
Use for information the player may need at any moment:
- HP
- Green Territory
- XP
- run timer / current phase
- urgent warnings
- Biomass Reserve
- current Biomass production rate
- compact build summary

Do **not** use the right sidebar for detailed build management.

## Bottom Bar / Decision Drawer — Choices
Use for:
- normal upgrades
- Biomass purchases
- Path choices
- Breakthrough choices
- detailed subsystem inspection

The bottom bar can expand upward temporarily when the player wants to make a decision.

## Battlefield — Consequences
Use the world itself to communicate:
- territory strength
- Bloom Mass and Force
- Prey Pressure
- Maw state
- Root maturity
- Bramble Entanglement
- Pruning material

Whenever the battlefield can explain a mechanic clearly, do not duplicate it with permanent HUD text.

---

# 2. Permanent HUD Test

Before adding a permanent element, ask:

1. Does the player need this during combat?
2. Do they need it frequently?
3. Is it actionable?
4. Can the world communicate it instead?
5. Can it appear only while relevant?
6. Can it live in the bottom drawer?

Only information that survives this test belongs permanently on screen.

---

# 3. Right Sidebar Structure

Keep four sections:

1. Run State
2. Survival
3. Biomass
4. Build Summary

Do not fill unused sidebar space just because it exists. Empty space improves readability.

---

# 4. Run State

Always show:
- run timer
- current major phase/objective when relevant

Example:

```text
RUN
08:41
FIRST GERMINATION
```

Contextual values should only appear while useful.

Bad:

```text
0 HOSTILES
```

Better:

```text
⚠ 3 HOSTILES
```

Hide the line when hostiles return to zero.

---

# 5. Survival Section

Always show the three critical combat resources.

## HP

```text
HP       86 / 100
█████████████░░░
```

## Green Territory

```text
GREEN      42.7%
███████░░░░░░░░
```

## XP

```text
LV 7       44 / 83
█████████░░░░░░
```

Do not show secondary calculations here.

---

# 6. Biomass HUD

Default persistent display:

```text
BIOMASS
428             +24.6/s
```

Do not permanently show all of these at once:
- Reserve
- Production
- Consumption
- Net
- Mass level
- Pressure level
- Cohesion level
- multiple progress bars
- free points
- Overgrow

That turns the combat HUD into an analytics panel.

---

# 7. Temporary Consumption

Only show consumption while Biomass is actually being consumed.

```text
BIOMASS
428       +24.6/s   -8.0/s
```

Never display useless values like `-0.0/s`.

---

# 8. Upgrade Availability

When an incremental decision is ready, use a compact indicator.

```text
BIOMASS   428   +24.6/s   ●
```

The dot can pulse softly.

Clicking Biomass or pressing a hotkey opens the detailed drawer.

---

# 9. Bottom Bar

Use the bottom bar as the main build-management surface.

Closed state example:

```text
UPGRADES
[TP] [EN] [+] [+] [+] [+]             [ BIOMASS ]
```

The exact labels can change, but the role should remain consistent.

---

# 10. Biomass Decision Drawer

Click Biomass or press its hotkey to expand the bottom bar upward.

Use the drawer for:
- exact subsystem levels
- exact costs
- Breakthrough progress
- current Breakthrough effects
- detailed production/consumption math
- major Biomass actions
- tooltips

Example:

```text
┌──────────────────────────────────────────────────────────────┐
│ ECOSYSTEM DEVELOPMENT                     BIOMASS 428        │
│                                                              │
│ MASS                 PRESSURE              COHESION           │
│ Lv 4                 Lv 2                  Lv 3               │
│ ███████░░            ███░░░░░             █████░░░           │
│                                                              │
│ [ GROW 120 ]         [ SURGE 75 ]          [ HARDEN 95 ]      │
│ More material        Push harder           Hold together      │
│                                                              │
│ NEXT BREAKTHROUGH: MASS LV 5                                 │
└──────────────────────────────────────────────────────────────┘
```

Close the drawer after the decision.

---

# 11. Progressive Disclosure

Do not show every future system from second one.

At the beginning:
- show only active upgrade slots
- show only active relic slots
- show only unlocked incremental mechanics

When a new system becomes available:
1. announce it briefly
2. add it to the relevant drawer
3. expand the UI only as needed

At most, tease the **next** upcoming unlock.

---

# 12. Locked Slots

Avoid long rows of lock icons.

Prefer:
- active slots only
- optionally one next locked slot

When a slot unlocks:
- animate the strip expanding
- briefly highlight the new slot
- stop drawing attention after a few seconds

The interface itself should visibly progress.

---

# 13. Temporary Major Events

Major progression events should appear briefly over the battlefield.

Examples:

```text
MASS LV. 5
BREAKTHROUGH READY
```

```text
NEW SYSTEM
CAMBIUM
```

```text
100 BIOMASS / SEC
```

Then disappear.

Do not create permanent HUD sections for one-time discoveries.

---

# 14. Breakthrough Choices

Breakthroughs should temporarily pause or heavily slow the game.

Show:
- two clear choices
- concise behavior descriptions
- strong visual distinction

After selection:
- return immediately to combat
- retain only a small icon or tooltip summary if needed

---

# 15. Build Summary

Use a compact persistent summary.

Example:

```text
BUILD
[SP] [BL]   [◆] [◆] [◆]
```

Use different visual grammar for:
- Paths
- upgrades
- relics

Do not make them all look like identical slots.

---

# 16. Remove Duplicate Information

If the same build information appears in both the right sidebar and bottom bar, decide which area owns it.

Good pattern:
- right side = compact summary
- bottom = interactive detail

Avoid two visually similar slot grids.

---

# 17. Visual Grammar

Use consistent forms.

## Bars
- HP
- Territory
- XP

## Numbers
- Biomass
- production rate
- timer

## Small square icons
- relics
- passive modifiers

## Rectangular modules
- selectable upgrades
- Path choices
- interactive buttons

## World-space visuals
- Prey Pressure
- Root state
- Entanglement
- Bloom strength
- Pruning material

---

# 18. Reduce Box Clutter

Do not border every value.

Use:
- spacing
- alignment
- typography
- thin separators

Reserve boxes for:
- clickable controls
- selected items
- meaningful grouping
- warnings

---

# 19. Color Hierarchy

Use a limited palette.

## Neutral blue-gray
- normal borders
- secondary labels
- inactive state

## Plant green
- Biomass
- Green Territory
- Plant-system highlights

## Red
- danger
- HP loss
- enemy warnings

## Rarity colors
Only when rarity itself matters.

Avoid decorative use of many accent colors simultaneously.

---

# 20. Contextual Information

Hide information when it has nothing useful to say.

Examples:
- no Hostiles line at zero
- no Consumption line at zero
- no boss UI outside boss encounters
- no objective warning after objective resolution
- no upgrade-ready label when nothing is affordable

Absence can communicate zero.

---

# 21. Tooltips

Use tooltips for:
- definitions
- formulas
- secondary effects
- detailed descriptions

Do not hide strategically necessary state behind hover.

Good:

```text
BIOMASS 428   +24.6/s
```

Hover:
> Biomass is generated by controlled territory and spent on ecosystem development.

---

# 22. Fixed Layout and Muscle Memory

Keep UI controls stationary.

Use:
- fixed-width numeric columns
- right-aligned values
- tabular numerals
- fixed-size buttons
- stable icon positions

Avoid:
- buttons changing width as costs grow
- labels shifting because values get longer
- cards changing height after purchase

The player should eventually use the interface by muscle memory.

---

# 23. Numeric Formatting

Use compact notation for large values.

Examples:
- 1,240
- 12.4K
- 1.28M

Do not allow number length to alter the layout.

Keep decimal precision consistent.

---

# 24. World-Space Communication

Prefer information on the object itself.

## Maw
Bud swells as Prey Pressure approaches threshold.

## Seed
Germination visible through growth stage.

## Bramble
More/thicker tethers represent higher Entanglement.

## Root
Mature Green becomes denser or more fibrous.

## Bloom
Higher Mass = larger splats.
Higher Force = longer/faster splatter.

## Pruning
Ring visibly accumulates harvested material.

---

# 25. Battlefield Readability Priority

Use this visual priority order.

## Highest
1. Player
2. Enemy attacks that can damage the player
3. Important enemy silhouettes
4. Critical objectives/interactables

## Medium
5. Territory boundary
6. Seeds/Maws/important structures
7. Hostile territory

## Lowest
8. Friendly projectiles
9. Bloom micro-splatter
10. decorative vegetation
11. cosmetic particles

Lower-priority effects must visually yield during peak chaos.

---

# 26. Friendly VFX Intensity

Add a separate setting:

## Friendly Effect Intensity
- 100%
- 75%
- 50%
- 25%

Affect:
- friendly projectile trails
- decorative Bloom particles
- nonessential friendly effects

Do not reduce enemy telegraph visibility with this setting.

---

# 27. Enemy Telegraph Visibility

Enemy danger must remain readable regardless of friendly settings.

Possible option:

## Enemy Telegraphs
- Normal
- High Contrast

Do not use one global opacity slider for both friendly and hostile effects.

---

# 28. Territory Detail Setting

Add:

## Territory Detail
- High
- Medium
- Low

Reduce only cosmetic detail:
- micro-splatter
- decorative vegetation
- tiny root strands
- secondary ripples
- cosmetic debris

Gameplay simulation remains identical.

---

# 29. Damage Number Settings

Add:

## Damage Numbers
- Full
- Important Only
- Off

Important Only can show:
- crits
- elite/boss hits
- large ability hits
- major healing/resource events

---

# 30. Player Highlight

Add:

## Player Highlight
- Off
- Outline
- Strong

This becomes increasingly important as splatter, enemies, vines, and orbiting effects fill the arena.

---

# 31. UI Scale

Support UI scaling.

Suggested presets:
- 80%
- 90%
- 100%
- 110%
- 125%

Do not solve clutter by making the default UI tiny.

---

# 32. HUD Detail Mode

Add:

## HUD Detail
- Compact
- Detailed

### Compact
Default.
Shows only:
- HP
- Territory
- XP
- Biomass
- production
- essential warnings
- compact build summary

### Detailed
May additionally show:
- consumption
- subsystem levels
- more counters
- cooldown values
- relic trigger progress

Use the same layout with extra information revealed, not a separate design.

---

# 33. Relic Trigger Feedback

When a relic activates:
- flash its icon
- show a cooldown ring when relevant
- show a counter only if the player can plan around it

Do not permanently expose every hidden relic counter.

---

# 34. Notification Priority

Use three levels.

## Minor
Small HUD-local feedback.
Examples:
- upgrade available
- relic trigger
- small milestone

## Major
Center/top battlefield banner.
Examples:
- Breakthrough
- new Path
- new system

## Critical
Strong warning.
Examples:
- territory near collapse
- boss phase
- dangerous hostile objective

Minor notifications must never visually compete with critical information.

---

# 35. Sound as UI

Use sound to reduce the need for text.

Examples:
- Biomass milestone sound
- upgrade-ready ping
- Maw emergence cue
- Breakthrough fanfare
- low-territory warning

The player should not need to watch the sidebar constantly.

---

# 36. Motion Rules

Motion should imply meaning.

Good:
- new slot expands
- upgrade-ready dot pulses
- changed number flashes briefly
- warning breathes
- progress completes

Avoid:
- constant decorative pulsing
- bouncing labels
- moving inactive panels

---

# 37. Default Combat Density

The normal combat screen should contain:
- one large battlefield
- one narrow information rail
- one shallow bottom build bar

Avoid:
- floating windows
- multiple simultaneous side panels
- permanent upgrade trees
- tooltip clouds

---

# 38. Suggested Compact HUD

```text
RUN  08:41
FIRST GERMINATION

HP       86 / 100
█████████████░░

GREEN      42.7%
███████░░░░░░░░

LV 7       44 / 83
█████████░░░░░░

────────────────

BIOMASS
428        +24.6/s   ●

────────────────

BUILD
[SP] [BL]   [◆] [◆] [◆]


[ RESTART RUN ]
```

This is the target density for ordinary combat.

---

# 39. Initial Run UI

At run start, show only systems that matter immediately.

Do not begin with:
- multiple lock icons
- future Path slots
- future relic slots
- advanced Biomass systems
- disabled buttons

Let the interface grow with the run.

---

# 40. New-System Reveal Pattern

When a system unlocks:

1. Brief announcement.
2. One-sentence explanation.
3. Add its control to the drawer.
4. Let the player use it immediately.
5. Remove tutorial text afterward.

Example:

```text
NEW ORGAN
CAMBIUM
Green can now reinforce damaged territory.
```

---

# 41. Readability Testing

Test at:
- empty early game
- normal midgame
- dense late-game horde
- Super Bloom chain
- heavy Bramble build
- full Carnivory build
- Pruning discharge
- boss encounter
- low Green emergency
- maximum particle density

A HUD that looks clean at zero enemies is not necessarily a clean HUD.

---

# 42. Screenshot Test

At each milestone:

1. Capture peak-chaos screenshot.
2. Shrink to half size.
3. Check whether you can instantly identify:
   - player
   - major enemies
   - enemy attacks
   - Green boundary
   - HP
   - Territory
   - Biomass
4. Reduce noise if any fail.

---

# 43. Five-Second Test

Show a gameplay screenshot to someone unfamiliar with the build for five seconds.

Ask:
- Where is your health?
- How much territory do you control?
- What resource are you accumulating?
- Where would you click to upgrade?
- Where is the player?
- What is dangerous?

If they cannot answer quickly, strengthen hierarchy.

---

# 44. Avoid UI Creep

For every new mechanic, use this order:

1. Can the battlefield show it?
2. Can it appear contextually?
3. Can it live in the bottom drawer?
4. Can it live in a tooltip?
5. Only then add permanent HUD.

Never add a permanent widget by default.

---

# 45. Final UI Standard

The finished interface should feel:
- sparse
- stable
- readable
- contextual
- responsive
- integrated with the simulation

> **The right sidebar tells me what is true.  
> The bottom drawer is where I make decisions.  
> The battlefield shows me what those decisions did.**
