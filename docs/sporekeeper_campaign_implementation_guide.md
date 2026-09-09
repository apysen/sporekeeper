# Sporekeeper 25-Wave Campaign Implementation Guide

## 1. Purpose

This guide replaces the current 30-wave Campaign with a 25-wave, 25-minute structure designed around the new four-Adaptation build model.

The Campaign must feel dangerous from the first minute, remain readable, and increase pressure steadily without depending on a giant late-game enemy-count spike. Difficulty comes from six coordinated curves:

1. enemy health;
2. contact damage;
3. movement speed;
4. territory-action strength;
5. territory-action speed;
6. enemy composition, modifiers, and spawn topology.

Raw enemy count is a supporting pressure tool, not the primary scaler. Sporekeeper has many effects that become stronger with density, including kills, corpses, collisions, contagion, germination, Bloom chains, Thistle impacts, and Fruit chains. Excess bodies can therefore strengthen a completed player build instead of threatening it.

## 2. Final Campaign contract

| Rule | Final value |
|---|---:|
| Campaign length | 25 minutes |
| Wave count | 25 |
| Wave duration | 60 seconds |
| First wave start | Immediate |
| Normal active-enemy cap | 130 |
| Regular reinforcement cap | 124 |
| Reserved milestone/core capacity | 6 |
| Core Adaptations | 2 |
| Branch Adaptations | 2 |
| Ordinary lines per Adaptation | 4 |
| Ordinary line maximum | Rank 3 |
| Evolutions | 1, determined by the Core pair |
| Evolution line maximum | Preserve authored rank 5 |
| Relic opportunities | 10 |
| Upgrade rerolls | Preserve the existing Campaign allowance |
| Relic-offer rerolls | 2 |
| Final reinforcement cutoff | 24:45 |
| Victory check | 25:00 |

The six reserved active slots are for the Elite Rootbreaker, Burrower Boss, and dynamically created Colony Cores. Regular reinforcements stop at 124 active actors so milestone enemies cannot be rejected by a full ordinary crowd.

Victory occurs at 25:00 if Grandma is alive and the run has not already failed through the existing territory-loss condition. Remaining non-boss enemies retreat or dissolve through the normal victory cleanup. The Burrower Boss is intended to be defeated during the run, but an unfinished Boss should not make the final victory check ambiguous. If the Boss remains alive at 25:00, the run is not complete and enters a boss-cleanup state with no further regular reinforcements.

## 3. Structural progression

| Run point | Player progression | Enemy purpose |
|---|---|---|
| Before Wave 1 | Choose Core Adaptation 1 | Establish the run's first mechanic |
| After Wave 1 | Choose Core Adaptation 2 | Lock the Evolution pair early |
| Waves 2-5 | Rank Core lines | Introduce basic territory and positioning threats |
| Wave 6 | Elite Rootbreaker milestone | First major build check |
| Elite defeated | Choose Branch Adaptation 1 | Add breadth without changing the Evolution |
| Waves 7-12 | Build toward the Evolution | Add the full specialist vocabulary |
| Wave 13 | Burrower Boss milestone | Midpoint viability check |
| Boss defeated | Choose Branch Adaptation 2 | Complete the four-Adaptation roster |
| Waves 14-18 | Mature Evolution and relic interactions | Increase behavior, control resistance, and modifier pressure |
| Waves 19-24 | Test the completed build | Combine the full enemy roster in authored scenarios |
| Wave 25 | Final invasion | Maximum pressure without a raw stat cliff |

The Evolution remains progression-driven. It becomes eligible when the player masters any two ordinary lines in each Core Adaptation. An ordinary line is mastered at rank 3, so readiness requires at least 12 focused ordinary purchases. Evolution is not automatically granted on a fixed wave.

## 4. Data-driven architecture

Create a `CampaignWaveSpec` Resource for every wave. Do not hard-code wave-number branches throughout `WaveDirector`.

Recommended resource fields:

```gdscript
class_name CampaignWaveSpec
extends Resource

@export var wave_index: int
@export var display_name: StringName
@export var duration_seconds: float = 60.0
@export var opening_break_seconds: float

@export var hp_multiplier: float
@export var contact_damage_multiplier: float
@export var movement_speed_multiplier: float
@export var territory_strength_multiplier: float
@export var territory_action_speed_multiplier: float
@export_range(0.0, 1.0) var cc_resistance: float
@export_range(0.0, 1.0) var modifier_chance: float

@export var pack_interval_seconds: float
@export var pack_pattern: StringName
@export var role_weights: Dictionary
@export var spawn_topology: StringName
@export var modifier_pool_stage: int

@export var elite_spawn_second: float = -1.0
@export var boss_spawn_second: float = -1.0
@export var grants_wave_relic: bool = false
```

Create a separate `EnemyRoleScalingProfile` Resource so role exceptions are authored rather than scattered across enemy scripts.

```gdscript
class_name EnemyRoleScalingProfile
extends Resource

@export var role_id: StringName
@export var movement_scaling_factor: float = 1.0
@export var action_speed_scaling_factor: float = 1.0
@export var receives_global_cc_resistance: bool = true
@export var modifier_eligible_from_wave: int = 999
@export var scales_action_interval: bool = true
@export var scales_rest_interval_only: bool = false
```

The wave Resource is the authoritative Campaign configuration. Enemy scripts should receive a resolved spawn-time scaling snapshot and should not query the current wave every frame.

## 5. Global scaling formulas

For wave `w`, where `w` is clamped to 1 through 25:

```text
p = (w - 1) / 24

hp_multiplier               = lerp(1.10, 3.60, p)
contact_damage_multiplier   = lerp(1.05, 2.25, p)
movement_speed_multiplier   = lerp(1.00, 1.15, p)
territory_strength_multiplier = lerp(1.10, 3.20, p)
territory_action_speed_multiplier = lerp(1.00, 1.22, p)
```

Use the wave's fixed multipliers for every enemy spawned during that wave. Do not use continuous run time for HP and damage. Fixed per-wave values make balancing, telemetry, deterministic tests, and player expectations easier to interpret.

### 5.1 Complete scaling table

| Wave | HP | Contact damage | Move speed | Territory strength | Action speed | CC resistance | Modifier chance |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 1.10x | 1.05x | 1.000x | 1.10x | 1.000x | 0% | 0% |
| 2 | 1.20x | 1.10x | 1.006x | 1.19x | 1.009x | 0% | 0% |
| 3 | 1.31x | 1.15x | 1.013x | 1.28x | 1.018x | 0% | 0% |
| 4 | 1.41x | 1.20x | 1.019x | 1.36x | 1.028x | 0% | 5% |
| 5 | 1.52x | 1.25x | 1.025x | 1.45x | 1.037x | 0% | 6% |
| 6 | 1.62x | 1.30x | 1.031x | 1.54x | 1.046x | 0% | 8% |
| 7 | 1.73x | 1.35x | 1.038x | 1.63x | 1.055x | 0% | 10% |
| 8 | 1.83x | 1.40x | 1.044x | 1.71x | 1.064x | 0% | 12% |
| 9 | 1.93x | 1.45x | 1.050x | 1.80x | 1.073x | 2% | 14% |
| 10 | 2.04x | 1.50x | 1.056x | 1.89x | 1.083x | 3% | 16% |
| 11 | 2.14x | 1.55x | 1.063x | 1.98x | 1.092x | 4% | 18% |
| 12 | 2.25x | 1.60x | 1.069x | 2.06x | 1.101x | 5% | 20% |
| 13 | 2.35x | 1.65x | 1.075x | 2.15x | 1.110x | 7% | 23% |
| 14 | 2.45x | 1.70x | 1.081x | 2.24x | 1.119x | 8% | 26% |
| 15 | 2.56x | 1.75x | 1.088x | 2.33x | 1.128x | 9% | 29% |
| 16 | 2.66x | 1.80x | 1.094x | 2.41x | 1.138x | 10% | 32% |
| 17 | 2.77x | 1.85x | 1.100x | 2.50x | 1.147x | 11% | 35% |
| 18 | 2.87x | 1.90x | 1.106x | 2.59x | 1.156x | 13% | 40% |
| 19 | 2.98x | 1.95x | 1.113x | 2.68x | 1.165x | 14% | 43% |
| 20 | 3.08x | 2.00x | 1.119x | 2.76x | 1.174x | 15% | 46% |
| 21 | 3.18x | 2.05x | 1.125x | 2.85x | 1.183x | 16% | 49% |
| 22 | 3.29x | 2.10x | 1.131x | 2.94x | 1.193x | 17% | 52% |
| 23 | 3.39x | 2.15x | 1.138x | 3.03x | 1.202x | 18% | 55% |
| 24 | 3.50x | 2.20x | 1.144x | 3.11x | 1.211x | 19% | 60% |
| 25 | 3.60x | 2.25x | 1.150x | 3.20x | 1.220x | 20% | 70% |

Wave 25 is the maximum of each smooth curve. It does not apply an extra boss-style global multiplier.

### 5.2 Spawn-time stat snapshot

```text
maximum_hp = round(base_hp * hp_multiplier)
contact_damage = base_contact_damage * contact_damage_multiplier

effective_move_multiplier =
    1 + (movement_speed_multiplier - 1) * role_move_factor

movement_speed = base_speed * effective_move_multiplier

territory_action_strength =
    base_territory_strength * territory_strength_multiplier

effective_action_multiplier =
    1 + (territory_action_speed_multiplier - 1) * role_action_factor

scaled_action_interval =
    base_action_interval / effective_action_multiplier
```

Round HP only after all spawn-time HP modifiers are applied. Keep damage as a float until the damage presentation layer rounds it for UI display.

## 6. Role-specific scaling

Movement speed is a highly sensitive pressure variable. Use the global bonus selectively.

| Enemy | Move factor | Action factor | Special rule |
|---|---:|---:|---|
| Hunter | 1.00 | 0.00 | No territory action |
| Grazer | 1.00 | 1.00 | Keep 0.14s bite cadence fixed; scale only the 2.5s rest |
| Heavy Grazer | 1.10 | 1.00 | Keep 0.14s bite cadence fixed; scale only the 2.2s rest |
| Rusher | 0.50 | 0.00 | Wave 25 speed is about 153.7, not 164.5 |
| Saboteur | 0.90 | 0.85 | Scale the repeated sabotage action, not its initial telegraph |
| Corruptor | 0.85 | 0.85 | Preserve its 1.25s first-action delay |
| Siege Corruptor | 0.85 | 0.80 | Preserve its 1.25s first-action delay and existing compounding cap |
| Colonizer | 0.80 | 0.75 | Preserve the 3.0s first Core delay |
| Warden | 0.80 | 0.75 | Preserve the 0.75s first-action delay |
| Colony Core | 0.00 | 0.75 | Anchored; inherit creation-wave scaling |
| Elite Rootbreaker | 0.50 | 0.00 | Uses authored milestone behavior |
| Burrower Boss | 0.40 | 0.65 | Uses authored boss telegraphs and territory action |

For Grazers:

```text
scaled_rest = base_rest / effective_action_multiplier
```

Do not accelerate the 0.14-second grazing tick. Faster rests create more pressure while preserving the readability and simulation assumptions of a grazing burst.

Do not scale normal contact intervals. Faster movement and higher contact damage already increase player pressure. Shortening contact intervals would stack another difficult-to-read damage multiplier.

## 7. Crowd-control resistance

Global CC resistance begins at Wave 9 and reaches 20% at Wave 25. It reduces magnitude or duration but never grants immunity.

```text
root_duration = authored_root_duration * (1 - cc_resistance)
knockback_distance = authored_knockback_distance * (1 - cc_resistance)
slow_intensity = authored_slow_intensity * (1 - cc_resistance)
```

Rules:

- Preserve existing role-specific knockback resistance, then apply global CC resistance to the remaining knockback.
- Apply resistance to Bramble roots, Bramble Repulsion, Fruit knockback, Vine control, and other player-authored root, shove, or slow effects.
- Do not reduce Entanglement accumulation itself. Reduce the slow and root payoff after Entanglement becomes full.
- Do not apply global CC resistance to forced cinematic displacement.
- Boss and Elite resistance may include an additional authored role multiplier, but they must remain visibly affectable.
- `Unstoppable` keeps its existing exception: it blocks roots and shoves but still permits slowing.

Example: a 2.10-second Bramble root becomes 1.68 seconds at Wave 25 before any role-specific boss or Elite reduction.

## 8. Break and reinforcement cadence

| Waves | Opening break |
|---|---:|
| 1 | 0.0s |
| 2-3 | 4.0s |
| 4-6 | 3.5s |
| 7-10 | 3.0s |
| 11-15 | 2.5s |
| 16-20 | 2.0s |
| 21-24 | 1.5s |
| 25 | 1.25s authored final-wave cue |

The opening break is a fixed authored pause. Do not end it early merely because the arena is empty. This removes the current behavior where clear speed changes scheduled reinforcement totals.

### 8.1 Pack patterns

| Pattern ID | Sequence | Average enemies per pack |
|---|---|---:|
| `ONE` | 1 | 1.00 |
| `ONE_ONE_ONE_TWO` | 1, 1, 1, 2 | 1.25 |
| `ONE_ONE_TWO` | 1, 1, 2 | 1.33 |
| `ONE_TWO` | 1, 2 | 1.50 |
| `TWO` | 2 | 2.00 |
| `TWO_TWO_TWO_THREE` | 2, 2, 2, 3 | 2.25 |
| `TWO_TWO_THREE` | 2, 2, 3 | 2.33 |
| `TWO_THREE` | 2, 3 | 2.50 |
| `THREE` | 3 | 3.00 |

The sequence index resets at each wave boundary. This makes requested density deterministic.

### 8.2 Cadence table

| Wave | Break | Pack interval | Pattern | Approx. requests before cap |
|---:|---:|---:|---|---:|
| 1 | 0.0s | 0.80s | ONE | 75 |
| 2 | 4.0s | 0.78s | ONE | 71 |
| 3 | 4.0s | 0.76s | ONE | 73 |
| 4 | 3.5s | 0.74s | ONE | 76 |
| 5 | 3.5s | 0.72s | ONE_ONE_ONE_TWO | 98 |
| 6 | 3.5s | 0.70s | ONE_ONE_TWO | 107 plus Elite |
| 7 | 3.0s | 0.68s | ONE_TWO | 125 |
| 8 | 3.0s | 0.66s | TWO | 172 |
| 9 | 3.0s | 0.64s | TWO | 178 |
| 10 | 3.0s | 0.62s | TWO | 182 |
| 11 | 2.5s | 0.60s | TWO | 190 |
| 12 | 2.5s | 0.58s | TWO | 198 |
| 13 | 2.5s | 0.56s | TWO | 204 plus Boss |
| 14 | 2.5s | 0.54s | TWO | 212 |
| 15 | 2.5s | 0.52s | TWO | 220 |
| 16 | 2.0s | 0.50s | TWO | 232 |
| 17 | 2.0s | 0.48s | TWO | 240 |
| 18 | 2.0s | 0.46s | TWO | 252 |
| 19 | 2.0s | 0.44s | TWO | 262 |
| 20 | 2.0s | 0.42s | TWO | 276 |
| 21 | 1.5s | 0.38s | TWO_TWO_TWO_THREE | 344 |
| 22 | 1.5s | 0.37s | TWO_TWO_THREE | 369 |
| 23 | 1.5s | 0.36s | TWO_THREE | 405 |
| 24 | 1.5s | 0.34s | THREE | 516 |
| 25 | 1.25s | 0.28s, then 0.22s | THREE | About 522 |

These are scheduled requests under a free active-cap assumption, not guaranteed live counts. They are included as deterministic QA targets. The 130-active cap and ordinary reinforcement reserve will reject or delay many late requests.

Wave 25 timing:

- 0.00-1.25s: final invasion cue;
- 1.25-25.00s: three-enemy packs every 0.28s;
- 25.00-45.00s: three-enemy packs every 0.22s;
- 45.00-60.00s: no new regular reinforcements;
- at 60.00s: victory or boss-cleanup check.

If late-wave density disproportionately strengthens kill engines, increase durability, specialist share, or topology pressure before increasing requested bodies further.

## 9. Frame-rate-independent scheduler

Replace the current at-most-one-pack-per-frame timing with a bounded debt scheduler.

```gdscript
spawn_debt_seconds += delta
var packs_this_frame := 0

while spawn_debt_seconds >= current_interval \
and packs_this_frame < MAX_PACKS_PER_FRAME:
    spawn_debt_seconds -= current_interval
    request_next_pack()
    packs_this_frame += 1

spawn_debt_seconds = min(spawn_debt_seconds, current_interval * 3.0)
```

Use `MAX_PACKS_PER_FRAME = 2`. Retain at most three intervals of debt so a hitch does not produce an enormous catch-up burst. A rejected ordinary pack still consumes its scheduled request. Do not keep retrying ordinary packs against a full cap. Elite and Boss requests are priority events and retry until their reserved slot is available.

Track both `packs_requested` and `enemies_spawned` in telemetry.

## 10. Role composition by wave

Weights are percentages of non-milestone reinforcement leaders. Pack followers normally use the same pressure role unless a wave explicitly enables mixed-role packs.

Abbreviations: H Hunter, G Grazer, HG Heavy Grazer, R Rusher, S Saboteur, C Corruptor, SC Siege Corruptor, Co Colonizer, W Warden.

| Wave | Identity | Role weights | Milestone |
|---:|---|---|---|
| 1 | Garden Under Attack | H70, G30 | None |
| 2 | Sabotage | H55, G30, S15 | None |
| 3 | Corruption | H45, G25, S15, C15 | Wave relic |
| 4 | Grazer Surge | G65, H15, S10, HG10 | None |
| 5 | Rush | H45, R20, G20, S10, C5 | None |
| 6 | Rootbreaker | H40, G20, HG10, R10, S10, C10 | Elite at 35s; wave relic |
| 7 | Colonization | H30, G20, Co15, HG10, S10, C10, R5 | None |
| 8 | Mixed Pressure | H30, G20, HG10, R10, S10, C10, Co10 | None |
| 9 | Warden | H25, G15, HG10, R10, S10, C10, Co10, W10 | Wave relic |
| 10 | Horde | H45, G20, HG15, R20 | None |
| 11 | Siege | H25, G15, HG10, R10, C15, SC10, S5, Co5, W5 | None |
| 12 | Specialist Mix | H15, G10, HG10, R5, S15, C15, SC10, Co10, W10 | Wave relic |
| 13 | Burrower | H25, G15, HG10, R10, S10, C10, SC5, Co10, W5 | Boss after opening cue |
| 14 | Recovery Denied | G30, HG30, H15, S5, C5, SC5, Co5, W5 | None |
| 15 | Rush Hour | R35, H35, G10, HG5, S5, C5, SC5 | Wave relic |
| 16 | Siege Line | C20, SC20, W15, Co10, HG10, G10, H10, S5 | None |
| 17 | Swarm | H50, G25, HG15, R10 | None |
| 18 | Mutation | H20, G15, HG15, R10, S10, C10, SC10, Co5, W5 | Wave relic; modifier showcase |
| 19 | Colony War | Co25, C15, SC10, W10, H15, G10, HG10, R5 | None |
| 20 | Devour | HG35, G25, H10, C10, SC10, Co5, W5 | None |
| 21 | Combined Arms | H20, G15, HG10, R10, S10, C10, SC10, Co8, W7 | Wave relic |
| 22 | Breach | R30, SC20, C10, H15, HG10, W10, S5 | None |
| 23 | Infestation | S15, C15, SC15, Co15, W15, HG10, R10, H5 | None |
| 24 | Collapse | H15, G10, HG15, R10, S10, C10, SC10, Co10, W10 | Wave relic |
| 25 | Final Invasion | H15, G10, HG15, R10, S10, C10, SC10, Co10, W10 | Final survival |

### 10.1 Deterministic role deck

For each wave:

1. Build a 100-entry leader deck from the authored percentages.
2. Shuffle it with `run_seed + wave_index * PRIME_WAVE_SEED`.
3. Consume one entry per pack.
4. Reshuffle the same authored deck when exhausted, using an incremented cycle seed.
5. Do not use independent weighted random rolls for every pack. The deck prevents long accidental streaks while preserving run-to-run order variation.

For multi-enemy packs, the first actor is the leader. Followers use a follower table appropriate to that leader:

- Hunter leader: Hunter or Rusher, with no more than one Rusher per pack before Wave 21.
- Grazer leader: Grazer or Heavy Grazer, with no more than one Heavy Grazer per pack before Wave 14.
- Specialist leader: one specialist plus Hunter/Grazer pressure followers.
- Colonizer and Warden: never place two of the same specialist in one pack.
- Wave 24-25: mixed-role followers are permitted, but no pack may contain more than two specialists.

## 11. Enemy introductions and authored teaching

Every introduction needs a short visual or audio tell the first time it appears in a run. Do not stop combat for a tutorial card.

| Enemy | First wave | Teaching purpose |
|---|---:|---|
| Hunter | 1 | Direct pressure on Grandma |
| Grazer | 1 | Enemies consume Green |
| Saboteur | 2 | Catalysts and placed systems can be hunted |
| Corruptor | 3 | Hostile conversion must be interrupted |
| Heavy Grazer | 4 | Slow, durable territory assault |
| Rusher | 5 | Positioning and reaction check |
| Elite Rootbreaker | 6 | First build milestone |
| Colonizer | 7 | Off-front objective and Colony Core management |
| Warden | 9 | Mature Green can be suppressed |
| Siege Corruptor | 11 | Repeated uninterrupted actions compound |
| Burrower Boss | 13 | Midpoint viability check |

## 12. Spawn topology system

Divide the arena perimeter into eight sectors. Recalculate sector scores at most four times per second.

For each sector, track:

- distance to Grandma;
- owned Green coverage in the inward 220 px band;
- average maturity of owned Green;
- current enemy count;
- recent player damage and territory loss;
- whether the sector is inside the current dominant combat front.

Derived selections:

```text
weakest_control_sector = lowest owned coverage and maturity score
dominant_fight_sector = highest nearby enemy pressure score
opposite_fight_sector = perimeter sector nearest 180 degrees from dominant fight
quiet_sector = lowest recent enemy pressure outside Grandma's immediate sector
```

### 12.1 Topology profiles

| Profile | Use |
|---|---|
| `EVEN_RING` | Rotate through perimeter sectors with generous separation |
| `TWO_SIDE_PINCER` | Alternate between two sectors separated by 120-180 degrees |
| `CLUSTERED_FRONT` | Spawn several consecutive packs within one 90-degree front |
| `WEAK_SIDE_RUSH` | Place Rusher leaders in the weakest-control sector |
| `SPECIALIST_OPPOSITE_PACK` | Put a specialist opposite the current large pressure pack |
| `COLONIZER_DISTRACTION` | Put Colonizers in a quiet sector away from the main fight |
| `THREE_FRONT_PRESSURE` | Rotate between three sectors with at least 75 degrees of separation |
| `FINAL_ROTATION` | Two pressure fronts, then a weak-side breach, then a quiet-side specialist |

### 12.2 Topology schedule

| Waves | Topology rules |
|---|---|
| 1-3 | `EVEN_RING`; never use the same sector more than twice consecutively |
| 4-6 | Mix `EVEN_RING`, `CLUSTERED_FRONT`, and occasional `TWO_SIDE_PINCER` |
| 7-9 | Add `COLONIZER_DISTRACTION`; Rusher packs may use `WEAK_SIDE_RUSH` |
| 10-13 | Use pincers and concentrated fronts; place Wardens opposite large packs when possible |
| 14-18 | Add `SPECIALIST_OPPOSITE_PACK` and two-front sequences |
| 19-23 | Use three-front pressure, weak-side Rushers, and quiet-side Colonizers |
| 24 | Aggressive `THREE_FRONT_PRESSURE` with specialist opposition |
| 25 | `FINAL_ROTATION` with a predictable four-step repeating logic but run-seeded starting sector |

### 12.3 Spawn fairness

- Never spawn a normal enemy within 220 px of Grandma.
- Never spawn a Rusher within 280 px of Grandma.
- Keep the existing perimeter entrance presentation.
- Telegraph ordinary packs for at least 0.75s early, 0.65s midgame, and 0.55s in Waves 21-25.
- Telegraph Elite and Boss entrances for at least 1.5s.
- A topology request that has no valid point searches adjacent sectors before falling back to the safest valid perimeter point.
- Do not place a Colonizer where its first legal Core site is invalid.
- Do not choose a weak-side sector solely because the player has no Green there if basalt makes it tactically unreachable.

## 13. Modifier progression

Only one modifier may be assigned to an enemy.

### 13.1 Eligible roles

- Heavy Grazer, Rusher, and Siege Corruptor are eligible as soon as modifier rolls begin.
- Colonizer and Warden become eligible at Wave 13.
- Hunter, Grazer, Saboteur, Corruptor, Colony Core, Elite, and Boss do not receive random modifiers.
- Colony Cores inherit wave scaling but never inherit their Colonizer's modifier.

### 13.2 Unlock stages

| Waves | Available modifiers |
|---|---|
| 1-3 | None |
| 4-8 | Regenerative, Unstoppable |
| 9-12 | Add Blighted, Disruptive |
| 13-17 | Add Ravenous |
| 18-25 | Add Volatile |

Preserve the current modifier mechanics and numbers unless targeted playtesting shows a specific issue:

- Unstoppable: cannot be rooted or shoved, but can be slowed.
- Blighted: stamps hostile growth every 18 px traveled.
- Ravenous: uninterrupted territory actions compound with the existing caps.
- Regenerative: heals 9 HP/s after 2.2s without player-originated damage.
- Disruptive: applies maturity suppression in its authored radius.
- Volatile: deals its authored death damage and territory erosion.

Wave 18 is the modifier showcase. It uses the table's 40% chance but guarantees that the first six eligible enemies collectively demonstrate at least three different available modifiers. This guarantee is tutorial shaping, not a permanent random bias.

## 14. Elite and Boss milestones

### 14.1 Elite Rootbreaker

- Spawn at 35 seconds into Wave 6.
- Use Wave 6 global scaling unless the Elite profile contains a deliberate milestone override.
- Spawn through a reserved slot.
- Continue retrying the spawn if its selected entrance is temporarily invalid.
- Persist across the wave boundary until killed.
- On death, queue an Elite relic opportunity and Branch Adaptation 1.
- If the Elite survives past Wave 7, show a small persistent milestone marker but do not increase its stats again.

### 14.2 Burrower Boss

- Spawn immediately after Wave 13's 2.5-second opening cue.
- Use Wave 13 global scaling for its base profile.
- Preserve authored eruption telegraphs and apply the role action factor of 0.65.
- Persist until killed.
- On death, queue a Boss relic opportunity and Branch Adaptation 2.
- If the Boss remains alive when Wave 14 begins, regular waves continue. The delayed Branch is an organic penalty, not a run lock.
- If still alive at 25:00, enter boss cleanup with no ordinary reinforcements.

## 15. Relic reward schedule

Campaign authors ten relic opportunities:

1. Wave completion rewards at Waves 3, 6, 9, 12, 15, 18, 21, and 24.
2. One Elite defeat reward.
3. One Boss defeat reward.

Each opportunity offers up to three distinct eligible unowned relics and the player takes one. Preserve the two Campaign relic rerolls.

When several rewards are ready together, use this queue order:

1. milestone relic;
2. Branch Adaptation acquisition;
3. scheduled wave relic;
4. pending ordinary upgrade choices.

Pause Campaign time while any full-screen selection is open. Enemies and physics must also pause. Continue to queue rewards rather than opening one panel on top of another.

Remove the obsolete 24 Biomass fallback. If every eligible relic is owned, grant a `Compost Cache` instead:

- heal 20% of Grandma's maximum HP;
- restore 0.75x baseline Seed Growth Mass as Fresh Green at the nearest valid owned frontier point;
- if no valid owned point exists, center the restoration on the nearest valid point to Grandma;
- this is a reward event, not Seed germination, and does not unlock any relic pool.

## 16. XP and upgrade pacing targets

Enemy XP must support four owned Adaptations with four ordinary lines at three ranks each, plus the existing five-rank Evolution. The full permanent surface is 48 ordinary ranks and approximately five Evolution ranks. A normal Campaign should not guarantee all 53 purchases.

Use the existing XP curve as a starting point, then tune base rewards and level thresholds to hit these median-run checkpoints:

| Checkpoint | Median total purchases | Expected build state |
|---|---:|---|
| End Wave 3 | 6-8 | Both Core Adaptations established |
| Elite spawn in Wave 6 | 11-14 | Evolution close or READY for a focused Core build |
| End Wave 9 | 17-21 | Focused build has claimed Evolution |
| Boss spawn in Wave 13 | 24-28 | Branch 1 developed and Evolution active |
| End Wave 18 | 33-38 | Four Adaptations active and at least one mastered |
| Start Wave 25 | 42-47 | Two or three Adaptations mastered; remaining lines partial |

The player should commonly master one Adaptation, should be able to master two with deliberate Focus, and should not normally master all four plus the Evolution. Cultivation Focus guaranteed at least one eligible line from the Focused Adaptation in each ordinary three-card offer; it was removed from the build on 2026-09-04, leaving the drought guards to carry that job. Without that guarantee, the eventual 16-line candidate pool can delay intentional investment even when the XP curve is correct.

Do not scale XP at the same rate as HP. More durable enemies already reduce kill rate. First implement the wave structure, then adjust XP from observed level timing.

Recommended XP rule for initial testing:

```text
xp_wave_multiplier = lerp(1.00, 2.20, (wave - 1) / 24)
xp_reward = max(base_xp, round(base_xp * xp_wave_multiplier))
```

Colony Cores use the creation wave's XP multiplier. Elite and Boss keep their authored base XP before the wave multiplier. If the median build misses the target ranks, adjust the player XP threshold curve before increasing late enemy XP enough to make dense waves self-funding.

### 16.1 Scaling response to the four-line, three-rank structure

Keep the complete 25-wave enemy scaling table unchanged for the first integrated playtest.

The new progression model is broader but does not clearly increase raw power:

| Progression model | Ordinary ranks | Power shape |
|---|---:|---|
| 2 lines x 5 ranks x 4 Adaptations | 40 | Higher peak values in chosen lines |
| 4 lines x 3 ranks x 4 Adaptations | 48 | More utility and breadth, lower peak line values |

The player gains access to every defensive and utility line in the four owned Adaptations, but major offensive lines stop at 60% of their former rank-5 total. Therefore do not raise HP, damage, speed, density, or modifier chance merely because eight more ordinary ranks exist.

Use these as the initial unchanged Wave 25 targets:

| Scaling | Initial Wave 25 target |
|---|---:|
| HP | 3.60x |
| Contact damage | 2.25x |
| Movement speed | 1.15x |
| Territory strength | 3.20x |
| Territory action speed | 1.22x |
| CC resistance | 20% |
| Modifier chance | 70% |

Expected tuning risk:

- Lower offensive maxima may leave Waves 18-25 saturated at the 130-enemy cap.
- Access to Aftergrowth, Suppression, Mature Strength, Lateral Roots, Repulsion, Germination, and other utility lines may make established Green unusually stable.

If late kill speed is too low, reduce Wave 25 HP toward 3.35x to 3.45x and interpolate the reduction from approximately Wave 13 onward. Do not compensate first by adding more bodies.

If Green is too stable while enemy kill speed remains healthy, increase specialist composition pressure before changing global stats. Preferred adjustments are more Heavy Grazers, Siege Corruptors, quiet-side Colonizers, and opposite-front Wardens. Only after composition testing should Wave 25 territory strength move toward 3.30x or action speed toward 1.24x.

Do not change both late HP and territory pressure in the same tuning pass. Isolate whether the problem is insufficient player damage or excessive garden stability.

## 17. Active-cap and specialist safeguards

- `MAX_ACTIVE_ENEMIES = 130` remains the hard simulation cap.
- Ordinary packs may spawn only while active actors are below 124.
- Colony Cores count toward the total cap and use at most five of the six reserved slots.
- The Elite or Boss owns the final reserved slot.
- If the milestone actor is alive, Colonizers may create at most four Cores.
- Never delete a live ordinary enemy to make room for a milestone actor.
- A rejected ordinary request is recorded and discarded.
- A rejected milestone request retries.
- Wave 25 cannot raise the active cap.

These rules keep the Campaign inside the established 130-enemy performance gate while ensuring authored milestones appear.

## 18. Presentation

Every wave card should communicate its identity rather than expose raw multipliers.

Examples:

- `WAVE 4 - GRAZER SURGE`
- `WAVE 6 - ROOTBREAKER`
- `WAVE 13 - BURROWER`
- `WAVE 18 - MUTATION`
- `WAVE 25 - FINAL INVASION`

Use a short botanical field-guide subtitle for first introductions. Modifier introductions should use the enemy's existing visual marker rather than another modal explanation.

For Wave 25:

- briefly quiet the reinforcement audio during the 1.25-second cue;
- show the invasion title centrally;
- tint perimeter spawn tells without tinting owned Green or Rot itself;
- at 24:45, clearly signal that reinforcements have stopped;
- keep combat fully active through the final 15 seconds.

## 19. Telemetry

Record at minimum:

```text
campaign_wave_started
campaign_wave_completed
wave_pack_requested
wave_pack_rejected_active_cap
wave_enemy_spawned
wave_enemy_killed
wave_enemy_alive_peak
wave_role_spawned
wave_modifier_spawned
wave_spawn_sector_selected
wave_spawn_topology_used
wave_damage_to_grandma
wave_green_control_lost
wave_green_control_created
wave_mature_green_suppressed
wave_colony_core_created
elite_spawned
elite_killed
boss_spawned
boss_killed
branch_adaptation_granted
relic_offer_queued
campaign_failure
campaign_victory
```

For failure, record:

- wave and elapsed second;
- owned Adaptations, ordinary line ranks, and current Focus;
- Evolution state and rank;
- relics owned;
- active enemy counts by role;
- current Green percentage and Mature Green percentage;
- last ten seconds of HP and territory damage by source.

## 20. Validation plan

### 20.1 Deterministic schedule tests

- Every wave lasts exactly 60 seconds.
- Opening breaks do not end early.
- Pack sequence resets per wave.
- Request totals match the cadence table at 60, 120, and 240 simulation ticks per second.
- Frame hitches cannot produce more than two pack requests in one frame.
- Regular spawning ends at 24:45.
- No ordinary request is issued after the final cutoff.

### 20.2 Scaling tests

- Spawn one of every role on Waves 1, 13, and 25 and assert HP, damage, speed, territory strength, and action interval.
- Verify Rusher and Boss movement factors.
- Verify Grazer bite cadence remains 0.14s while rest changes.
- Verify Colony Cores inherit their creation-wave snapshot.
- Verify contact interval never receives global action-speed scaling.

### 20.3 Composition tests

- Generate at least 100 seeded runs and verify each wave's leader deck matches authored weights.
- Verify no early pack contains an illegal duplicate specialist.
- Verify Wave 18 demonstrates at least three modifier types in its first six eligible spawns.
- Verify Wave 25 never exceeds the two-specialist-per-pack rule.

### 20.4 Spawn fairness tests

- No normal spawn appears inside the 220 px Grandma exclusion.
- No Rusher appears inside 280 px.
- Colonizers receive a legal Core placement region.
- Rushers prefer the weakest valid control sector in late waves.
- Colonizers prefer a quiet sector away from the dominant fight.
- Invalid basalt sectors fall back safely.

### 20.5 Progression tests

Test at least these build families:

- epidemic: Spore Core;
- burst territory: Bloom Core;
- control: Bramble Core;
- amplifier: Root Core;
- close-range damage: Pruning Core;
- projectile network: Thistle Core;
- directional damage: Vine Core;
- kinetic spread: Fruit Core.

For each family, run low, median, and high relic luck seeds. Confirm that density does not make high-trigger builds safer than lower-density authored pressure waves.

Also verify:

- all ordinary lines stop at rank 3 while preserving their current per-rank values;
- Evolution becomes READY only after two mastered lines in each Core;
- a focused build can normally reach readiness between Waves 6 and 9;
- the Focused Adaptation appears in every eligible ordinary offer;
- at least one Adaptation is commonly mastered by Wave 18;
- typical successful runs enter Wave 25 with 42-47 total purchases rather than all 53;
- lower-priority defensive lines are delayed by choice rather than permanently unavailable.

### 20.6 Performance tests

- Preserve the 130-active-enemy hard cap.
- Profile Wave 17, Wave 21, Wave 24, and Wave 25 separately.
- Test generic crowds and maximum Thistle, Fruit, Vine, and cross-trigger builds.
- Test a churning killable crowd because Seeds and territory stamps are more expensive than a static crowd.
- Compare rank-3 maximum offense against the former rank-5 fixtures so lower projectile and Fruit counts do not hide an enemy-clearance bottleneck.
- Keep steady-crowd p99 below 16.67 ms at the 130 cap.
- Record territory batch time separately from enemy update time.

## 21. Initial balance acceptance targets

These are tuning targets, not promises about every player:

- Wave 1 requires movement but does not commonly kill an attentive player.
- Wave 4 forces the player to actively protect Green.
- Wave 6 can defeat a scattered or under-ranked build.
- Wave 8 exposes builds with no answer to mixed pressure.
- Wave 10 can kill a bad build despite its lower specialist count.
- Wave 13 determines whether the Core pair and early relics form a viable engine.
- Waves 18-24 remain threatening after all four Adaptations are owned.
- Wave 25 is deliberately brutal but contains no hidden stat spike.
- A median focused build claims Evolution between Waves 6 and 9.
- A typical successful run masters at least one Adaptation but does not complete all 53 permanent purchases.
- Waves 18-25 do not remain permanently pinned at the active-enemy cap because rank-3 offense cannot clear reinforcements.
- Full access to defensive lines does not make territory loss negligible.
- No single wave causes more than a 15 percentage point jump in failure rate unless it is Wave 6, 13, or 25.
- Fewer than 5% of player HP hits should occur within 1.0 second of an enemy's initial perimeter appearance.

## 22. Implementation order

1. Add `CampaignWaveSpec` and `EnemyRoleScalingProfile` Resources.
2. Replace continuous HP/damage pressure with fixed wave snapshots.
3. Add movement, action-speed, and CC-resistance scaling.
4. Replace frame-dependent pack timing with the bounded debt scheduler.
5. Author all 25 wave Resources, role decks, and pack patterns.
6. Implement the perimeter topology scorer and safety checks.
7. Move Elite to Wave 6 and Boss to Wave 13.
8. Integrate Branch rewards and the ten relic opportunities.
9. Integrate rank-3 ordinary progression, the two-mastered-lines-per-Core Evolution gate, and Cultivation Focus. *(Focus removed from the build 2026-09-04.)*
10. Replace the Biomass exhaustion reward with Compost Cache.
11. Add telemetry and deterministic schedule tests.
12. Run progression, balance, and performance fixtures.
13. Tune XP thresholds first, then late HP or specialist territory pressure from isolated playtest evidence.

## 23. Explicit removals from the old Campaign

Remove or disable these old Campaign rules:

- 30-wave, 1,800-second duration;
- the Wave 26 final-invasion cliff;
- fixed five-second breaks on Waves 2-30;
- early-ending breaks when the arena is empty;
- continuous-time HP and contact-damage scaling;
- HP and damage becoming flat from Wave 16 onward;
- the fixed 0.14-second, three-enemy final-invasion spam;
- frame-rate-dependent at-most-one-pack scheduling;
- the Wave 30 thirty-second cleanup structure;
- Campaign relic rewards on Waves 27 and 30;
- player-facing Biomass as the exhausted-relic fallback.

The replacement Campaign should feel hard because enemy behavior, composition, territory pressure, and authored attack geometry mature alongside the player's build. It should not wait until the final minutes to become dangerous.
