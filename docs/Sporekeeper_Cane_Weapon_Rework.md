# Cane Weapon Rework

## Purpose

Replace **Thornshot** as Grandma's universal starting weapon with the **Cane**.

The Cane is a simple, always-available melee weapon that gives every build a reliable
baseline source of direct damage without consuming Adaptation identity.

The Cane has **no dedicated upgrade paths**. Players who want to turn the Cane into a
major damage source do so by selecting the **Vine Adaptation**.

---

## Remove Thornshot

Remove Thornshot as the player's default weapon.

Also remove all three universal Thornshot upgrade lines:

- **Thornshot Power**
- **Thornshot Tempo**
- **Thornshot Volley**

These lines should no longer appear in the upgrade draft and should no longer consume
upgrade slots.

Any relics, UI text, tooltips, telemetry, or other systems that explicitly reference
Thornshot will need to be reviewed separately and either removed or reworked for Cane.

---

## Cane — Base Weapon

Grandma begins every run with her Cane.

### Base Behavior

- Attacks automatically every **0.72 seconds**.
- Reaches **92 px** from Grandma.
- Covers a fixed **90-degree frontal arc**.
- Attacks alternate back and forth:
  - left-to-right sweep
  - right-to-left sweep
  - repeat
- The 90-degree sector is centered on Grandma's current facing direction when each
  sweep begins.
- Every enemy physically crossed by the sweep can be hit once.
- The Cane is not a projectile and does not use projectile targeting, Pierce,
  ricochet, or projectile-count rules.
- The Cane does not spread Territory.
- The Cane does not require Green to function.

### Base Damage Target

Current prototype base damage:

**24 damage per enemy hit**

Balance the Cane around enemy survivability rather than treating 24 as an immutable
number.

Target early-game behavior:

- **Weak fodder:** approximately 1 Cane hit
- **Standard early enemy:** approximately 1-2 Cane hits
- **Tough early enemy:** approximately 3 Cane hits

The Cane should remain useful as a baseline source of direct damage when a build does
not select a dedicated damage Adaptation, but it should be substantially outscaled by
developed damage builds later in the run.

---

## No Cane Upgrade Lines

The Cane should **not** have its own upgrade branches.

Reasons:

1. **Keeps the universal weapon simple.** Every player understands the Cane immediately.
2. **Protects Adaptation identity.** Damage progression should primarily come from the
   selected Adaptations rather than generic starter-weapon upgrades.
3. **Makes Vine meaningful.** Vine is the dedicated Cane-focused damage Adaptation and
   transforms the same 90-degree sweep into a much larger and more powerful living lash.
4. **Reduces draft clutter.** Removing the three Thornshot lines frees upgrade-slot and
   draft space for Adaptation-specific builds.
5. **Avoids mandatory generic upgrades.** Players should not feel forced to spend several
   ranks maintaining the starter weapon before investing in their actual build.

The Cane's baseline damage should therefore be tuned generously enough to serve as the
game's universal offensive floor without needing its own progression tree.

---

## Vine Interaction

Selecting **Vine** evolves the Cane's attack rather than adding a separate autonomous
weapon.

Vine preserves the Cane's core behavior:

- automatic attacks
- fixed frontal **90-degree sector**
- alternating left-to-right and right-to-left sweeps

Vine changes the aim source: it no longer requires Grandma to face the intended
direction. Every automatic Vine sweep selects the in-reach, unobstructed 90-degree
sector containing the most targetable enemies. Ties prefer the nearer/tighter cluster
and then the sector closest to Grandma's facing, so the result remains deterministic.
Base Cane still uses facing. The live Vine shaft, tip, and sector telegraph are green.

Vine then scales that attack through its own Adaptation upgrade paths:

- **Elongation** — reach
- **Lignification** — damage
- **Turgor** — attack speed
- **Apical Dominance** — bonus damage near the outer tip

This makes the relationship explicit:

> **Cane is the universal baseline. Vine is the Cane build.**

---

## Implemented Checklist

- [x] Replace Thornshot weapon logic with one hit-once Cane sector.
- [x] Set Cane to **24 damage**, **0.72s** cadence, **92 px** reach, and a fixed 90° arc.
- [x] Alternate the visible sweep direction every automatic attack.
- [x] Remove all three Thornshot lines and projectile/Pierce assumptions.
- [x] Rework the five Thornshot-dependent universal relics for Cane.
- [x] Make Vine modify Cane directly, auto-target the densest valid sector, and render green.
