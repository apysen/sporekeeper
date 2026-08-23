# Real Physics for the Remaining Paths

> A survey of where each path currently fakes a physical behaviour with a
> multiplier, which real equation describes what it is pretending to be, and what
> would change in play if the equation replaced the multiplier.
>
> The test for including something here: the equation has to **produce behaviour we
> would otherwise have to author case by case**. A formula that just renames a
> multiplier is not worth the complexity.

---

# 0. What the field already is

Worth naming before adding anything, because three of the equations below are
already in the codebase without being called by their names.

`territory_field.step_simulation` runs, per cell, per fixed step:

```
diffusion  = (neighbour_average - control) * diffusion_rate / resistance
sharpening = control * (1 - control²) * sharpening_rate
advection  = pressure field transporting control
```

Those are not arbitrary. Together they are a **phase-field model**:

- The diffusion term is a discrete Laplacian — **Fick's second law**,
  `∂φ/∂t = D∇²φ`, with `1/resistance` acting as a spatially varying diffusivity.
- The sharpening term `φ(1 − φ²)` is the derivative of the double-well potential
  `f(φ) = ¼(1 − φ²)²`. Combined with the Laplacian this is the **Allen–Cahn
  equation**, `∂φ/∂t = M(ε²∇²φ − f'(φ))`, the standard model for a two-phase
  interface that stays sharp while it moves.
- The advection term makes it a **reaction–diffusion–advection** system.

This matters for two reasons. First, the border behaviour that feels emergent
already is emergent, and it comes from a real model — so extending it with more
real physics is coherent rather than bolted on. Second, Allen–Cahn has a known
consequence the game is not yet using: **motion by mean curvature**,
`v_n = −γκ`, where an interface moves inward proportional to how sharply it is
curved. That single property is the root of §6 below.

Literature worth reading: Allen & Cahn 1979; Cahn–Hilliard 1958 for the
mass-conserving variant; Provatas & Elder, *Phase-Field Methods in Materials
Science and Engineering* for the practical treatment.

---

# 1. Spore — nucleation theory

## What it does now
A Seed is placed, charges for a fixed time, then germinates and stamps growth.
Satellite patches that land isolated survive or die by
`small_fragment_decay_per_second`, a flat timer applied to any region under
`small_fragment_cell_limit` cells. The threshold is a number we picked.

## The real equation
**Classical nucleation theory.** A new phase forming inside another pays surface
energy and gains bulk energy:

```
ΔG(r) = −(4/3)πr³ Δg_v  +  4πr² γ
```

Setting `dΔG/dr = 0` gives the **critical radius**:

```
r* = 2γ / Δg_v
```

Below `r*`, the surface term dominates and the nucleus dissolves. Above it, growth
is downhill and the nucleus runs away. `γ` is surface tension (how much the border
costs), `Δg_v` is the bulk driving force (how favourable it is to be Green there).

The companion equation is **KJMA/Avrami** for how a field of nuclei fills a space:

```
X(t) = 1 − exp(−(kt)ⁿ)
```

with `n` reflecting nucleation and growth dimensionality — the S-curve every
"territory fills in" process actually follows.

## What changes in play
Fragment survival stops being a flat rule and becomes a consequence. A satellite
splat that lands on neutral ground has a low `Δg_v`, so it needs to be large to
survive; the same splat landing next to friendly Green has a higher driving force
and survives at half the size. Mass investment raises `Δg_v`, so a Mass build
*literally lowers the critical radius* and its scatter starts taking root — which
is the fantasy the Mass axis is selling and currently only approximates.

It also gives Cohesion a real meaning: Cohesion is `γ`. High Cohesion raises the
critical radius, so a cohesive ecosystem throws fewer surviving satellites but
holds its main body harder. That is a genuine trade rather than two upgrades that
both say "better".

## Implementation sketch
In `territory_field`, replace the fragment-decay pass with a per-region test:
compute each isolated region's effective radius from its cell count
(`r = sqrt(cells/π)`), compute `r*` from local support and the cohesion
multiplier, and decay regions below it *at a rate proportional to how far below*
rather than uniformly. Cost: one extra pass over the topology data already
computed for `analyze_topology_now`. Risk: low — it replaces a rule that already
exists with a better-motivated one.

---

# 2. Bloom — secondary atomisation (already half done)

## What it does now
Since the splatter rework: droplets with size-distributed radii, mass ∝ r³, equal
specific energy at launch, quadratic drag with the ballistic coefficient, and
directional landing smears. That part is done and measured.

## What is still missing
Real bursts do not decide droplet sizes once at t=0. A droplet that is moving fast
enough relative to the air keeps breaking up, governed by the **Weber number**:

```
We = ρ_air · v² · d / σ
```

Above a critical value (≈12 for bag breakup, ≈40+ for shear breakup) a droplet is
unstable and shatters into smaller ones. Since `We ∝ v²d`, the *big fast* droplets
break and the *small slow* ones do not — automatically producing the observed
pattern where a violent burst is finer than a gentle one.

The size distribution itself has a standard form, **Rosin–Rammler**:

```
R(d) = exp(−(d/d̄)^n)
```

which is what the current `droplet_size_bias` is approximating by hand.

## What changes in play
Bloom Force stops being "throws further" and becomes "atomises harder". A
high-Force Bloom shatters its own globs mid-flight into fine mist that falls
short — so Force alone produces a wide, thin, close spray, while Force *with* Mass
produces globs big enough to survive breakup and carry. That is a real interaction
between the two axes that we would otherwise have to fake.

## Implementation sketch
In `_advance_glob`, compute `We` each step; above the critical value split the glob
into 2–3 children conserving mass (`r_child = r/∛n`), with a small velocity spread.
The pool already exists. Cost: low. Risk: needs a cap on splits per glob to bound
the pool.

---

# 3. Bramble — Bingham plastic, not a slow multiplier

## What it does now
`get_slow_fraction()` returns a clamped fraction, and an enemy's speed is
multiplied by `1 − slow`. Entanglement builds toward 1.0 and rooting triggers at a
threshold. Every part of that is authored.

## The real equation
Brambles are not a viscous fluid, they are a **Bingham plastic** — a material with
a *yield stress* that does not move at all until the applied stress exceeds it, and
flows with a plastic viscosity above it:

```
τ = τ_y + μ_p · γ̇          (for τ > τ_y; no flow below τ_y)
```

Solved for an enemy pushing through with force `F`:

```
v = max(0, (F − τ_y) / μ_p)
```

Entanglement raises `τ_y`. This is the physics of pushing through mud, wet
concrete, or a thicket, and it is *exactly* what Grasping Roots is trying to
express with a special case.

The build-up should be a **first-order rate process** approaching saturation:

```
dE/dt = k(1 − E)    →    E(t) = 1 − exp(−kt)
```

rather than a linear ramp with a clamp.

## What changes in play
Rooting stops being a threshold check and becomes emergent: a weak enemy's force is
below the yield stress, so it is pinned — no special case, no timer. A heavy elite
pushing with more force keeps moving, slowly. A boss walks through brambles that
completely stop a swarm, without anyone writing "bosses ignore roots".

Entanglement upgrades become "raise the yield stress", which automatically pins
progressively stronger enemies as it grows. The Bramble fantasy — *the field
decides who can move* — falls out of one inequality.

## Implementation sketch
Give each enemy profile a `push_force` (mass × speed is a reasonable proxy from
existing data). In `phase_b_combat_director`, replace the slow multiplier with the
Bingham solve, using `τ_y = base_yield · entanglement · bramble_development`. Cost:
moderate — it touches every enemy's movement. Risk: **this is the one on this list
that changes combat balance globally.** Worth prototyping behind a flag.

---

# 4. Root — Darcy flow and percolation

## What it does now
Maturity accrues per cell, mature ground gives resistance and a `network_bonus`
read at a position. "Connected" territory is not actually modelled: a mature cell
gives its bonus whether or not it is attached to anything.

## The real equations
**Darcy's law** for flow through a porous medium:

```
q = −(k/μ) ∇P
```

Flux is permeability times pressure gradient. Mature Green = high `k`. This is
precisely the "Vascular Transport" mechanic sketched in the incremental doc:
support flows *through* connected tissue instead of being applied uniformly.

**Percolation theory** for whether the network is connected at all. For site
percolation on a square lattice the threshold is:

```
p_c ≈ 0.5927
```

Below that occupation fraction, a lattice has only isolated clusters; above it, a
spanning cluster appears — abruptly, not gradually. It is a genuine phase
transition, and the game is already a lattice.

## What changes in play
Root stops being "+% to things" and becomes infrastructure. A run whose Mature
Green forms a spanning cluster gets support delivered everywhere along it; a run
whose territory is a scatter of islands does not, however much total territory it
owns. Pruning cutting a corridor becomes strategically real, because severing a
neck *disconnects* everything past it rather than removing a percentage.

The percolation threshold gives the player a genuine, learnable cliff: territory
approaching `p_c` behaves qualitatively differently from territory just past it,
and Root's whole purpose becomes getting the network over that line and keeping it
there.

## Implementation sketch
The topology pass already labels connected regions (`analyze_topology_now`).
Extend it to compute, per region, whether it contains the player's core, and solve
a cheap iterative Darcy relaxation for "support" over mature cells only —
essentially the same relaxation the field already does for control, on a second
channel. `get_network_bonus_at` then reads that channel instead of local maturity.
Cost: moderate; it is one more field channel and one more relaxation pass.
Risk: performance — worth measuring against the existing per-frame budget.

---

# 5. Pruning — angular momentum and hoop stress

## What it does now
The ring spins at `orbit_speed_radians` plus a charge bonus, holds up to
`orbit_capacity` spikes regardless of their number, sheds on a timer, and launches
at an authored speed. The spin, the capacity and the launch speed are three
unrelated authored numbers.

## The real equations
A ring of orbiting masses is a rigid body. **Angular momentum**:

```
L = Iω        I = Σ mᵢrᵢ²
```

If the harvest adds spikes without adding angular momentum, `ω` must fall: the ring
*slows as it fills*. Spending Biomass or Charge to add momentum speeds it back up.

**Release velocity** is then not authored at all — a spike let go of a rotating
ring leaves tangentially at:

```
v = ω × r
```

**Hoop stress** decides when the ring cannot hold together:

```
σ_θ = ρ ω² r²
```

Above the material's yield strength the ring fails — which is a physical reason the
hold has to end, replacing the current escalating-drain timer.

## What changes in play
Every Pruning decision becomes one trade expressed in one equation. A wide ring
(large `r`) carries more spikes and launches them faster, but its hoop stress goes
as `r²` so it tears itself apart sooner. A dense ring spins slower and hits softer
but holds. Charge becomes *angular momentum you are buying*, and the launch payout
stops needing its own multiplier because `v = ωr` already pays out more for a
faster, wider ring.

The shed rate we just tuned by hand would come out of the same place: a ring past
its stress limit sheds spikes because it physically cannot hold them.

## Implementation sketch
Track `_angular_momentum` instead of `_orbit_angle` velocity. On raising a spike,
add its `m·r²` to `I` and recompute `ω = L/I`. Charge adds `L`. On release, set the
cutting's velocity to `ω·r` tangential plus the existing outward component. Replace
the hold-end timer with a hoop-stress check. Cost: moderate, contained entirely in
`phase_b_pruning_director`. Risk: low — the path is self-contained and well tested.

---

# 6. Cross-cutting — surface tension and Rayleigh–Plateau

## The observation
Allen–Cahn already implies motion by mean curvature, `v_n = −γκ`: a boundary moves
inward where it curves sharply. The field has the machinery but does not expose
`γ` as a gameplay quantity.

If it did, one more real phenomenon comes free. **Rayleigh–Plateau instability**: a
cylinder of fluid is unstable to perturbations longer than its circumference —

```
λ > π · d
```

— and pinches off into droplets. A narrow neck of territory longer than roughly π
times its width *cannot* persist under surface tension. It necks and separates.

## What changes in play
Long thin corridors of Green break up on their own, and the width at which they
survive is set by Cohesion. That is the strongest argument for the Cohesion axis
the game could have: without it, an aggressive Pressure build stretches itself into
filaments that pinch off; with it, the same shape holds. It also makes Pruning's
corridor-cutting and Root's connectivity meaningful against the same physical rule.

## Implementation sketch
Expose `γ` as the cohesion multiplier already computed, and add the curvature term
explicitly to the step: estimate `κ` from the discrete Laplacian of the sign field
and move the interface by `−γκ`. The neck instability then emerges; it does not
need separate code. Cost: one term in the existing loop. Risk: this changes the
feel of *every* border in the game — prototype behind a tuning flag set to zero.

---

# 7. Two smaller ones

## Man-Eater — Holling's disc equation
Hunger currently accumulates linearly with enemy count and is capped. The standard
model for a predator's intake against prey density is **Holling type II**:

```
f(N) = aN / (1 + a·h·N)
```

where `a` is search rate and `h` is handling time. It saturates naturally, which is
what `maximum_hunger_per_second` is doing by hand — but it saturates *smoothly* and
gives a principled meaning to the cap: a Maw can only handle so many bodies per
second.

## Biomass — logistic growth
Production is currently linear in territory percentage. Ecology's standard model
is:

```
dB/dt = rB(1 − B/K)
```

with carrying capacity `K` set by territory. This gives automatic diminishing
returns and makes expanding `K` — taking more ground — the way to break a plateau,
which is exactly the loop the incremental doc asks for and currently gets by
authoring cost curves instead.

---

# 8. Recommendation

Ranked by *behaviour gained per unit of risk*:

| # | Change | Gain | Risk |
|---|---|---|---|
| 1 | **Spore: critical radius** | Fragment survival becomes physical; Mass and Cohesion get honest opposing roles | Low — replaces an existing rule |
| 2 | **Pruning: angular momentum** | Three authored numbers collapse into one equation; the ring's trade becomes real | Low — self-contained |
| 3 | **Bloom: Weber breakup** | Force and Mass interact for real | Low — extends work already done |
| 4 | **Root: Darcy + percolation** | Connectivity finally matters; Root becomes infrastructure | Moderate — new field channel, watch performance |
| 5 | **Cohesion: curvature + Rayleigh–Plateau** | The best argument for the Cohesion axis; corridors behave | High — changes every border |
| 6 | **Bramble: Bingham plastic** | Rooting stops being a special case | High — touches all enemy movement |

Start with 1 and 2. They are contained, they each delete authored numbers rather
than adding them, and both are measurable with the probes already used for the
splatter work.
