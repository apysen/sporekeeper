# Two-day rework summary

Covers the work from **Biomass becomes Ecosystem Metabolism** (2026-08-22) through
the end of 2026-08-23. Gameplay only — what changed for the player, and why.

Organised by system rather than by day, because several of these were built, played,
and then replaced within the window. The order matters more than the dates.

---

## The direction this work is heading

> **As many mechanics and paths as possible should depend on real-world physics.**

This is the standing goal the window's biggest changes were made against, and it is
worth stating plainly because it decides arguments that tuning cannot.

The test is not whether an equation can be pointed at. It is whether the real behaviour
produces something we would otherwise have to author case by case — and whether it
produces the *right* thing when nobody is tuning it. Bloom is the worked example:

- Droplet size, weight and launch speed follow from one blast breaking one quantity of
  material apart, so mist and heavy globs sort themselves out without either being
  authored. The mist stops short and the lumps carry, because drag acts on
  cross-section and is resisted by weight.
- Paint flattens on impact into a splat several times its own width, wider the faster
  it arrives. That single fact is what finally let a Bloom dent a mature front, after
  two rounds of tuning numbers that were never the problem.
- More material behind the same blast means less energy per unit of it, so the breakup
  coarsens. Investing in Mass therefore buys **more droplets, not bigger ones**, and
  that falls out of conservation rather than being a balance decision.
- A hit on a wall splits into the part driving into the face and the part running along
  it, which is why a glob thrown square at a rock marks it hard and a glancing one keeps
  going. Nothing special-cases either.

Where reality does not translate, the honest substitute is named rather than faked: the
arena is seen from above, so nothing holds paint against a wall the way gravity would,
and the stand-in is wetting — a liquid clings to a surface it has touched.

And where the physics costs more than it gives, it goes. A true shortest-path
calculation for how growth flows around obstacles was built, worked, and was thrown
away for costing six times what the frame could afford; the cheaper rule reaches the
same result on screen.

`docs/physics_opportunities.md` carries this forward, surveying every remaining path
against the real behaviour it is currently approximating with a multiplier. Two rank
first because each *deletes* authored numbers rather than adding them: Spore's fragment
survival as nucleation — whether a detached patch of Green is above or below the size at
which it can hold together — and Pruning's ring as angular momentum, where a spike's
mass and radius decide the disc's spin rather than a tuned rate.

---

## 1. The economy: allocated, then bought

**Where it started.** The five repeatable percentage purchases were deleted. In their
place, three universal systems the whole run is made of — **Mass**, **Pressure**, and
**Cohesion** — fed by distributing eight allocation points, with the Reserve acting as
a genuine buffer that an unsustainable configuration burns through and then throttles
against.

**Where it ended.** Allocation was scrapped within the day. Feeding the systems from a
pool turned the economy into "allocate, then watch bars fill", which was less
interactive than the purchases it replaced. Levels are now **bought outright** at 20,
35, 61, 107, 188, 328, 574 Biomass, and nothing levels with time.

What survived both versions:

- **The economy unfolds on the run clock.** Mass from the start, Pressure at 1:30,
  Cohesion at 3:00. Each announces itself when it arrives and is usable immediately,
  so the run opens simple and grows rather than presenting everything at once.
- **Every purchase answers on the battlefield.** Mass injects material, Pressure a
  shove, Cohesion a knitting-together, so the axis bought is the one the ground shows.
  A purchase that only moved a number would not be a purchase worth making.
- **Breakthroughs every fifth level** change how the ecosystem behaves rather than how
  large a number is: whether Mass trickles out or arrives in pulses, whether Pressure
  concentrates into tendrils or spreads along the whole border, whether Green bends and
  rebounds or holds and then fails suddenly.
- **Overgrow** spends half the Reserve along the living frontier, split by the levels
  the run actually bought. Two builds pressing the same button get visibly different
  results: open ground spreads, a gap funnels the same budget into a jet, and a torn
  ecosystem spends it sealing itself.

**Breakthroughs audited against a control.** Two of six worked. **Lateral Growth did
nothing at all** — it spread growth exactly as wide as a run that had never taken it.
The Mass pulses were too small to notice: a pulsing run and a non-pulsing one finished
within a twentieth of a percent of each other. Pulses are far larger now and carry
Pressure as well as Mass, because a pulse of pure Mass can only top up ground that is
already full.

**Storage Organs is still the weak half of its pair**, recorded rather than papered
over: its rare large release lands on a border already near full, so most of it is
refused. Rapid Cycling is the better choice at every point measured.

---

## 2. Relics

- The catalog is authored to fixed pool sizes: 12 Universal, 6 Plant, 3 per Path, 8
  curated synergies. 44 exist today; the planned 48 arrives with the four Clover
  relics and the secret gambling Path.
- Rewards are **choose one of three**, weighted by rarity and drawn without
  replacement, and arrive on a **wave schedule** — every fourth wave, alongside the
  elite and the boss. Relic rerolls exist separately from upgrade rerolls, which is
  also what makes Recycling Bin mean anything: it guarantees a replacement at least
  as rare as what it replaced.
- **A synergy relic unlocks the moment the run can actually do both things it needs**,
  whether that came from the opening pair, a support path, or an Evolution — rather
  than being gated on a specific pairing.
- Path milestones and relic rewards share the choice panel, so a path choice is asked
  first and the relic waits rather than being dropped. A reward with nothing left to
  offer still pays out as Biomass.
- The relic row shows what the run holds in the order it was taken, with each relic's
  trigger counter on the slot itself: Predator's Eye reads `8 / 10`, Overpopulation
  reads `PRIMED`, The Hedge reads its cooldown.
- **Every loop where one relic can feed another carries a limiter.** An Overpopulation
  blast cannot spend or advance the next charge, Encore never repeats Legendaries or
  anything that leaves a permanent object, and Seed-advancing relics respect a cooldown
  on each Seed.

---

## 3. Carnivory to Man-Eater

The clearest case in the window of playtesting changing a design rather than tuning it.

1. **It never worked.** A full run with Carnivory as the primary path produced **zero
   Buds, zero Maws, zero Bites in 390 seconds**.
2. **The cause was not the numbers.** The path banked its Prey Pressure only from
   enemies standing on ground the run owns — but enemies eat the frontier from the
   *hostile* side, so almost nothing was ever credited. Once frontier attackers fed the
   Green they were eating: first Maw at 142.5s, 8 Buds, 49 Bites.
3. **Then the model was rebuilt.** Maw hit points were stripped entirely and the
   territory carried the predator instead. A Bud became the whole of the vulnerability
   — it needs Green under it and a Saboteur can cut it down — while a grown Maw stands
   as long as its **root zone** holds enough Green, retracting when the ground is taken
   and rising again when it closes back over. Same run: first Maw at 90s, both slots
   held from 120s onward, **113 Bites against 40**. The predator persisted instead of
   churning.
4. **Then the Path was scrapped anyway.** As a Path, Maws had to answer how many there
   are, how durable, how they reposition, what happens when swarmed, and how four
   upgrade lines and five Evolutions scale them. None of that made the fantasy better.
   The fantasy was one moment: a giant plant erupts out of the Green and eats a mob.

**Man-Eater** is that moment as a Plant Legendary. Hunger builds from enemies standing
on Green — one enemy needs the full 30 seconds, five need six, fifteen need two, capped
per second so a late horde stays readable. When it fills, the densest cluster on Green
is chosen, the ground bulges for 0.7s — **an event enemies can walk out of, not
invisible damage** — and the jaws close on up to eight. Normal enemies are swallowed,
elites take 55% of the Bite, a boss takes 30% and is never eaten. The meal comes back as
a Bloom at the site, so the enemies become more Plant. Then it retracts completely.

No hit points, no capacity, no digestion, no budding, no placement problem, and nothing
left standing for an enemy to kill before it does anything.

> **The rule this established:** when a mechanic has one fantastic moment but is not
> deep enough to sustain a Path, turn that moment into a relic rather than throwing it
> away.

---

## 4. Bloom: from stamped circle to thrown paint

The longest arc in the window, and the one with the most wrong turns.

**It became a splatter.** One Bloom stopped stamping one circle and resolved into a
central surge plus thrown material. Mass and Force were kept meaningfully separate:
Mass is how much material is thrown, Force is how far and how hard it goes. High Mass
with low Force is a thick splash near the source; low Mass with high Force is a thin
far-reaching spray.

**The thrown material became real.** Each piece now has a position, a speed and a
weight, and what it crosses decides where it ends up. Basalt stops it dead, hostile
ground drags hard on it, and the run's own Green barely slows it — paint slides on wet
paint. The streak behind a throw is the trail of something moving rather than marks
placed along a line decided in advance.

**It atomised.** A bursting liquid does not break into equal lumps — it breaks into a
spectrum, mostly fine mist with a few heavy globs, and each droplet's size decides what
happens to it. Fine mist is thrown fastest and stops almost immediately; a heavy glob
leaves slower and carries. **The first version had this backwards**, launching every
droplet with the same energy so the mist outran everything; an explosion delivers energy
per unit of weight, so they all leave at a similar speed and drag does the sorting.

**It landed where it was thrown.** Landings had been symmetric circles pushing outward
in every direction — nothing about a splat knew which way the paint had been travelling.
A splat is now stretched along its own travel, its centre sits forward of the impact, and
it shoves the ground it claims downrange.

**It finally dented hostile ground.** Reported three times before it was fixed, because
twice I fixed what I assumed rather than what I measured. The limiter was not the
material and not the impact force — it was that a glob marked the ground at the size it
had been flying at, so nine droplet-sized marks could never add up to a hole. Real paint
flattens on impact into a splat several times its own width, wider the faster it arrives.
**A Bloom thrown at a mature red front went from denting 55 cells to 443.**

**It became throw-led.** The throw, not the central surge, is now how Bloom takes ground.
The surge is cut back to the blast's footprint — the material that never got airborne —
and the rest is thrown, because the throw is the only part of a Bloom that arrives with
momentum, and momentum is what breaks established ground instead of negotiating with it.
Calibrated back to the strength Bloom had before any of this:

| | open ground | mature front |
|---|---|---|
| the old surge-led Bloom | +66 green, 68 dent | +38 green, 45 dent |
| throw-led, no investment | +55 green, 70 dent | +54 green, 68 dent |

Same total strength, different shape: slightly weaker on open ground, substantially
better against a matured front. Investing in Mass buys **more droplets**, not bigger ones
— droplet size is set by the blast tearing the material apart, not by how much material
there is.

**Walls became surfaces.** Paint used to stop dead and vanish against a rock. A hit now
splits: what was driving into the face splatters there, and what was running along the
face carries the glob down the surface until it pools against it. A glob thrown square at
a rock still marks it hard; one that catches it at an angle mostly keeps going.

**Landings have no roots.** Thrown paint is wet material sitting on top of the ground
rather than territory that grew there, so the Green it wins is fragile and the hostile
front takes it back on its own. The throw opens ground; the run has to follow it up to
keep it. Paint landing on ground the run *already* holds thickens it instead, and how
well it roots rides the run's Maturation.

**Inoculation** (Bloom + Spore) closes the loop: a glob landing on a Seed that is already
breaking ground establishes it, and since a germination arms a chained Bloom, the throw
carries itself into the next one.

---

## 5. Pruning was a homing-volley launcher wearing a ring

Reported as an Evolution being always on. It was not — measured side by side, a run
without the Evolution and a run with it raised the same spikes, and **the gate was never
leaking**.

The real fault was the ring turning over. A full ring shed its oldest spike the moment a
new one arrived, and the harvest kept raising spikes while the ring was already full: **78
spikes raised in a 10-second hold, 62 of them fired off as free homing volleys** — about
six a second, for as long as the player held the ring. The disc, which is meant to be the
path's identity and its damage, was incidental.

A full ring now sheds on a timer rather than on arrival. Same hold after: 20 raised, 4
shed, and it still eats the same 358 cells, so holding a finished ring costs exactly as
much territory as before.

**Deadfall keeps the rapid fire**, because that is what the Evolution should have been all
along — 0.7 shed per second on base Pruning against 5.7 with it. The same feel the bug
had, now as the payoff for taking the pairing.

---

## 6. Territory

- **Walls dim growth instead of deleting everything behind them.** Spreading used to
  refuse a cell outright if anything at all blocked the line to it, so one clipped corner
  erased everything behind it and the shadow widened with distance — a ridge on a basalt
  rock cost far more spread than the ridge was worth. Growth now weakens as it works past
  an obstruction and stops only against real thickness of stone.
- **Buying a level pours in rather than snapping.** An injection used to land in a single
  step, so the border jumped a visible distance between two frames, which read as a number
  changing rather than the ecosystem growing. The same total now arrives over a short ramp.
- **The three axes each show what they do to the border**, as three different actions
  rather than three tints of one flash: Mass swells at the frontier as material arriving,
  Pressure leaves it as a shove travelling outward, and Cohesion knits along it. Two of
  the three previously had no visual at all.

---

## 7. What the player reads

- **The sidebar says only what is true**, and every detailed Biomass decision moved into a
  drawer that opens when asked for and closes after the decision.
- **Contextual information hides itself.** The hostile count appears only when there are
  hostiles to warn about; an axis the run has not discovered is absent rather than sitting
  there disabled; both slot rows show what the run holds plus the one slot it is working
  toward, so the interface visibly grows instead of opening as a wall of padlocks.
- **Major progression events take the battlefield briefly** — a new organ, a Breakthrough,
  a production milestone — and then fade, rather than each earning a permanent panel.
- **Relic and upgrade descriptions on hover never worked.** The text was correct all along;
  the rows were being rebuilt ten times a second, so no hover ever survived long enough to
  appear. This affected upgrades just as much as relics.
- **Carnivory's trigger got a telegraph** before the Path was retired: the hungriest patch
  of Green announced itself with a breathing glow and a closing ring, because a building
  site had looked exactly like dead ground.
- **The controller focus box is a controller affordance now** — it appears on a pad button
  and disappears the moment the mouse moves or a key is pressed.
- **Explosions detune themselves slightly** on every play, within a band narrow enough that
  a dozen in a row still read as one sound.

---

## 8. How this was worked out

Worth stating, because it changed several outcomes:

- **Measure before claiming.** Three separate reports had a different cause than the one
  hypothesised — Pruning's gate was not leaking, the relic tooltips were not missing, and
  the splatter's problem was never its material.
- **Compare against a control.** This is what exposed Lateral Growth doing nothing and the
  Mass pulses being invisible; both looked plausible until a run without them scored the
  same.
- **Test the thing the player sees.** A check on the impact mechanism passed for months
  while a real Bloom left no mark on the field. The test that matters throws a real Bloom
  at a real mature front.
- **Say what could not be fixed.** Storage Organs remains the weak half of its pair.
