# Campaign enemy scaling

This document describes the shipped Campaign configuration in
`WaveDirector`, `CombatDirector`, and the enemy profiles authored in
`scenes/run/run.tscn`.

Campaign lasts 1,800 seconds: 30 waves of 60 seconds. Wave 1 starts immediately.
Waves 2-30 normally reserve their first 5 seconds as a reinforcement-free break.
If the arena is empty, that break ends early. Regular reinforcements stop at
1,770 seconds, leaving the last 30 seconds of Wave 30 for cleanup.

## Important interpretation of the spawn counts

The per-wave table below is an exact deterministic reference under these stated
conditions:

- the director is advanced at 60 ticks per second;
- every wave receives its full 5-second break (an ignored live enemy was retained
  while measuring the schedule);
- spawned enemies are removed immediately, so the active-enemy limit never rejects
  a request;
- Colony Cores created by Colonizers are excluded.

The game does **not** guarantee these as successful spawn totals. It can have fewer
successful spawns because only 130 enemies may be active and a pack stops when that
limit is reached. It can have more scheduled reinforcements when the player clears
the arena and skips some or all of a 5-second break. The director issues at most one
pack per frame and does not catch up missed packs, so a substantially different
frame rate can also change the count. The role sequence itself is deterministic.

Abbreviations used below: H = Hunter, G = Grazer, HG = Heavy Grazer, R = Rusher,
S = Saboteur, C = Corruptor, SC = Siege Corruptor, Co = Colonizer, W = Warden,
E = Elite Rootbreaker, and B = Burrower Boss.

## Scheduled enemy requests by wave

| Wave | H | G | HG | R | S | C | SC | Co | W | E | B | Total |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 48 | 16 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 64 |
| 2 | 46 | 15 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 62 |
| 3 | 38 | 13 | 0 | 0 | 13 | 0 | 0 | 0 | 0 | 0 | 0 | 64 |
| 4 | 0 | 54 | 0 | 0 | 13 | 0 | 0 | 0 | 0 | 0 | 0 | 67 |
| 5 | 40 | 12 | 0 | 0 | 13 | 5 | 0 | 0 | 0 | 0 | 0 | 70 |
| 6 | 36 | 14 | 0 | 0 | 13 | 11 | 0 | 0 | 0 | 0 | 0 | 74 |
| 7 | 58 | 17 | 0 | 0 | 13 | 11 | 0 | 0 | 0 | 1 | 0 | 100 |
| 8 | 0 | 133 | 0 | 0 | 12 | 11 | 0 | 8 | 0 | 0 | 0 | 164 |
| 9 | 94 | 20 | 13 | 13 | 14 | 10 | 0 | 10 | 0 | 0 | 0 | 174 |
| 10 | 97 | 21 | 19 | 13 | 14 | 12 | 0 | 10 | 0 | 0 | 0 | 186 |
| 11 | 105 | 21 | 17 | 13 | 14 | 8 | 5 | 10 | 5 | 0 | 0 | 198 |
| 12 | 0 | 84 | 82 | 0 | 14 | 6 | 5 | 11 | 10 | 0 | 0 | 212 |
| 13 | 118 | 23 | 22 | 15 | 17 | 6 | 8 | 11 | 10 | 0 | 0 | 230 |
| 14 | 127 | 23 | 25 | 17 | 18 | 8 | 6 | 13 | 11 | 0 | 0 | 248 |
| 15 | 141 | 28 | 27 | 17 | 18 | 6 | 9 | 13 | 13 | 0 | 0 | 272 |
| 16 | 0 | 112 | 111 | 0 | 20 | 8 | 9 | 15 | 13 | 0 | 1 | 289 |
| 17 | 148 | 24 | 32 | 19 | 21 | 10 | 7 | 14 | 13 | 0 | 0 | 288 |
| 18 | 148 | 28 | 29 | 19 | 19 | 9 | 8 | 15 | 13 | 0 | 0 | 288 |
| 19 | 150 | 21 | 34 | 21 | 19 | 10 | 6 | 14 | 13 | 0 | 0 | 288 |
| 20 | 0 | 104 | 119 | 0 | 21 | 12 | 4 | 15 | 13 | 0 | 0 | 288 |
| 21 | 149 | 27 | 27 | 20 | 20 | 8 | 10 | 14 | 13 | 0 | 0 | 288 |
| 22 | 148 | 29 | 27 | 20 | 20 | 9 | 7 | 15 | 13 | 0 | 0 | 288 |
| 23 | 149 | 35 | 22 | 18 | 20 | 7 | 9 | 15 | 13 | 0 | 0 | 288 |
| 24 | 0 | 110 | 114 | 0 | 20 | 11 | 6 | 14 | 13 | 0 | 0 | 288 |
| 25 | 145 | 27 | 29 | 21 | 20 | 9 | 8 | 15 | 14 | 0 | 0 | 288 |
| 26 | 625 | 113 | 120 | 80 | 51 | 22 | 20 | 37 | 33 | 0 | 0 | 1,101 |
| 27 | 623 | 120 | 115 | 78 | 52 | 21 | 22 | 37 | 33 | 0 | 0 | 1,101 |
| 28 | 0 | 485 | 455 | 0 | 49 | 16 | 25 | 37 | 34 | 0 | 0 | 1,101 |
| 29 | 622 | 122 | 114 | 78 | 51 | 21 | 23 | 37 | 33 | 0 | 0 | 1,101 |
| 30 | 284 | 46 | 60 | 37 | 23 | 12 | 7 | 17 | 15 | 0 | 0 | 501 |

Wave 30 has only 25 seconds of regular spawning under the full-break assumption:
5 seconds of grace, 25 seconds of final-invasion reinforcements, then 30 seconds
of cleanup.

## Scaling by wave

Health and contact damage use continuous run time, so enemies from opposite ends
of the same early wave do not have exactly the same stats. The arrows below show
the multiplier at the start and end of each wave's clock interval. Endpoints are
the next wave boundary and are normally exclusive.

Territory pressure and XP use the enemy's numbered spawn wave, so those values are
constant for the entire wave. `+N / xM` in the XP column means the reward is the
larger of `base XP + N` and `ceil(base XP × M)`.

The modifier chance applies only to eligible late specialists: Heavy Grazers,
Rushers, and Siege Corruptors. The one scheduled Elite arrives before modifier
escalation begins. A successful roll assigns exactly one modifier.

| Wave | HP multiplier (extra HP) | Contact-damage multiplier | Territory-action multiplier | XP rule | Eligible modifier chance |
|---:|---:|---:|---:|---:|---:|
| 1 | x1.000→x1.133 (+0%→+13.3%) | x1.000→x1.067 | x1.0 | +0 / x1.0 | 0%→0% |
| 2 | x1.133→x1.267 (+13.3%→+26.7%) | x1.067→x1.133 | x1.1 | +1 / x1.1 | 0%→0% |
| 3 | x1.267→x1.400 (+26.7%→+40.0%) | x1.133→x1.200 | x1.2 | +2 / x1.2 | 0%→0% |
| 4 | x1.400→x1.533 (+40.0%→+53.3%) | x1.200→x1.267 | x1.3 | +3 / x1.3 | 0%→0% |
| 5 | x1.533→x1.667 (+53.3%→+66.7%) | x1.267→x1.333 | x1.4 | +4 / x1.4 | 0%→0% |
| 6 | x1.667→x1.800 (+66.7%→+80.0%) | x1.333→x1.400 | x1.5 | +5 / x1.5 | 0%→0% |
| 7 | x1.800→x1.933 (+80.0%→+93.3%) | x1.400→x1.467 | x1.6 | +6 / x1.6 | 0%→0% |
| 8 | x1.933→x2.067 (+93.3%→+106.7%) | x1.467→x1.533 | x1.7 | +7 / x1.7 | 0%→2.4% |
| 9 | x2.067→x2.200 (+106.7%→+120.0%) | x1.533→x1.600 | x1.8 | +8 / x1.8 | 2.4%→7.3% |
| 10 | x2.200→x2.333 (+120.0%→+133.3%) | x1.600→x1.667 | x1.9 | +9 / x1.9 | 7.3%→12.1% |
| 11 | x2.333→x2.467 (+133.3%→+146.7%) | x1.667→x1.733 | x2.0 | +10 / x2.0 | 12.1%→17.0% |
| 12 | x2.467→x2.600 (+146.7%→+160.0%) | x1.733→x1.800 | x2.1 | +11 / x2.1 | 17.0%→21.9% |
| 13 | x2.600→x2.733 (+160.0%→+173.3%) | x1.800→x1.867 | x2.2 | +12 / x2.2 | 21.9%→26.7% |
| 14 | x2.733→x2.867 (+173.3%→+186.7%) | x1.867→x1.933 | x2.3 | +13 / x2.3 | 26.7%→31.6% |
| 15 | x2.867→x3.000 (+186.7%→+200.0%) | x1.933→x2.000 | x2.4 | +14 / x2.4 | 31.6%→36.4% |
| 16 | x3.000 (+200%) | x2.000 | x2.5 | +15 / x2.5 | 36.4%→41.3% |
| 17 | x3.000 (+200%) | x2.000 | x2.6 | +16 / x2.6 | 41.3%→46.1% |
| 18 | x3.000 (+200%) | x2.000 | x2.7 | +17 / x2.7 | 46.1%→51.0% |
| 19 | x3.000 (+200%) | x2.000 | x2.8 | +18 / x2.8 | 51.0%→55.9% |
| 20 | x3.000 (+200%) | x2.000 | x2.9 | +19 / x2.9 | 55.9%→60.7% |
| 21 | x3.000 (+200%) | x2.000 | x3.0 | +20 / x3.0 | 60.7%→65.6% |
| 22 | x3.000 (+200%) | x2.000 | x3.1 | +21 / x3.1 | 65.6%→70.4% |
| 23 | x3.000 (+200%) | x2.000 | x3.2 | +22 / x3.2 | 70.4%→75.3% |
| 24 | x3.000 (+200%) | x2.000 | x3.3 | +23 / x3.3 | 75.3%→80.1% |
| 25 | x3.000 (+200%) | x2.000 | x3.4 | +24 / x3.4 | 80.1%→85.0% |
| 26 | x3.000 (+200%) | x2.000 | x3.5 | +25 / x3.5 | 85.0% |
| 27 | x3.000 (+200%) | x2.000 | x3.6 | +26 / x3.6 | 85.0% |
| 28 | x3.000 (+200%) | x2.000 | x3.7 | +27 / x3.7 | 85.0% |
| 29 | x3.000 (+200%) | x2.000 | x3.8 | +28 / x3.8 | 85.0% |
| 30 | x3.000 (+200%) | x2.000 | x3.9 | +29 / x3.9 | 85.0% |

The exact formulas for an enemy spawned at elapsed time `t` in wave `w` are:

```text
pressure = clamp(t / 900, 0, 1)
maximum HP = base HP × (1 + 2 × pressure)
contact damage = base contact damage × (1 + pressure)
territory action strength = base strength × (1 + 0.1 × (w - 1))
XP = max(base XP,
         ceil(round_to_0.0001(base XP × (1 + 0.1 × (w - 1)))),
         base XP + (w - 1))
```

Movement speed, contact interval, body radius, knockback resistance, action
interval, action radius, and role-specific caps do not receive run-pressure or
per-wave scaling.

## Enemy base profiles

The HP, damage, and XP columns are the values before the formulas above. “Full HP”
and “full damage” are the values from Wave 16 onward, after pressure reaches 100%.

| Enemy | Base HP | Full HP | Base contact damage | Full damage | Contact interval | Speed | Base XP | Territory behavior |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Hunter | 28 | 84 | 5.5 | 11 | 0.80 s | 68 | 2 | None |
| Grazer | 42 | 126 | 4 | 8 | 0.95 s | 52 | 3 | Grazes Green: strength 1.0 every 0.14 s, radius x1.6; rests 2.5 s after 14 actions |
| Heavy Grazer | 148 | 444 | 7 | 14 | 1.05 s | 31 | 11 | Grazes Green: strength 2.1 every 0.14 s, radius x2.3; rests 2.2 s after 18 actions; ignores 92% of knockback |
| Rusher | 24 | 72 | 5 | 10 | 0.70 s | 143 | 6 | None |
| Saboteur | 34 | 102 | 3 | 6 | 0.90 s | 78 | 4 | Hunts catalysts; strength 1.0 every 0.55 s after a 0.35 s delay, radius x0.75 |
| Corruptor | 58 | 174 | 4 | 8 | 1.00 s | 46 | 6 | Converts Green: strength 2.5 every 2.4 s after a 1.25 s delay, radius x1.15 |
| Siege Corruptor | 96 | 288 | 4 | 8 | 1.00 s | 38 | 12 | Converts Green: strength 2.2 every 2.0 s after a 1.25 s delay, radius x1.25; uninterrupted actions compound x1.22 to a x6 cap |
| Colonizer | 74 | 222 | 2 | 4 | 1.10 s | 40 | 8 | Keeps 185 px away and attempts a Colony Core every 7.5 s after a 3.0 s delay |
| Warden | 96 | 288 | 4.5 | 9 | 0.95 s | 38 | 10 | Suppresses maturity: strength 0.5 every 0.85 s after a 0.75 s delay, radius x3.0 |
| Colony Core | 90 | 270 | 0 | 0 | 1.00 s | 1 | 7 | Anchored hostile spread: strength 1.0 every 1.7 s after a 0.8 s delay, radius x1.55 |
| Elite Rootbreaker | 180 | 540 | 9 | 18 | 0.72 s | 55 | 28 | None by profile |
| Burrower Boss | 780 | 2,340 | 12 | 24 | 0.85 s | 34 | 100 | Eruption: strength 2.6 every 4.5 s after a 4.5 s delay, radius x2.8 |

The scheduled Elite actually arrives at 375 seconds with x1.833 health and x1.417
damage: **330 HP** and **12.75 contact damage**. The Boss is scheduled at 900
seconds, during Wave 16's break, and spawns when the break ends (or immediately if
the arena is empty): **2,340 HP** and **24 contact damage**.

Colony Cores are dynamic rather than part of a reinforcement pack. Colonizers can
maintain at most five active Cores across the arena, subject to placement and
spacing rules. A Core copies whatever scaling is live when the Colonizer creates
it, so its wave, HP, damage, territory multiplier, and XP are all based on that
creation time.

## How the enemy mix is selected

- Normal waves use a Grazer-led pack every fourth pressure-role selection. Waves
  divisible by four are Grazer surges, so every pack is Grazer-led.
- Starting at 450 seconds, every sixth eligible non-Grazer selection leads with a
  Rusher instead of a Hunter.
- From 495 seconds onward, 45% of Grazer selections become Heavy Grazers. The code
  implements the share deterministically through the shared variant sequence.
- Specialists replace only the first enemy in a pack. Priority is Warden (every
  11th pack), then Colonizer (9th), Corruptor (7th), then Saboteur (5th). If a
  specialist wins, the remainder of the pack keeps the pressure role.
- Saboteurs unlock at 115 seconds, Corruptors at 270, Colonizers at 430, and
  Wardens at 630.
- From 630 seconds onward, 50% of Corruptor selections become Siege Corruptors.
  Heavy and Siege selection share one deterministic variant counter, so their
  exact interleaving depends on the preceding selections.
- One Elite is scheduled at 375 seconds. One Boss is scheduled at 900 seconds.
  Each retries on later frames if the active-enemy cap initially rejects it.

## Cadence and pack-size escalation

Before the final invasion, the requested interval between packs is:

```text
interval = lerp(0.95 seconds, 0.38 seconds, pressure)
```

Pack size is 1 through 405 seconds. It changes to 2 as soon as pressure is greater
than 0.45, so the transition occurs just after 6:45 during Wave 7. At 1,500 seconds
(the start of Wave 26), the final invasion begins: pack size becomes 3 and the
requested interval becomes a fixed 0.14 seconds. The normal per-frame spawning
limit and the 130-active-enemy cap still apply.

## Eligible late-enemy modifiers

From 450 to 1,500 seconds, modifier chance rises linearly from 0% to 85%. It then
stays at 85%. Only Heavy Grazers, Rushers, and Siege Corruptors are eligible among
regular reinforcements. A successful roll chooses one of:

- **Unstoppable:** cannot be rooted or shoved, but can still be slowed.
- **Blighted:** stamps hostile growth every 18 pixels traveled; base stamp strength
  0.55 is multiplied by the current wave's territory multiplier.
- **Ravenous:** uninterrupted territory actions compound by at least x1.16, capped
  at x5 unless the role already has a higher cap.
- **Regenerative:** heals 9 HP/s unless player-originated damage has blocked healing
  for 2.2 seconds.
- **Disruptive:** applies 0.9 maturity suppression per second in a x2.4 radius.
- **Volatile:** on death deals 46 damage in a 74-pixel radius and applies 1.3
  territory erosion in a x1.6 radius.

These effects generally change behavior rather than the spawn-time HP, contact
damage, or XP formulas above.

## Experience gain and level-up rewards

Every defeated enemy creates one XP pickup carrying the value fixed when that
enemy originally spawned. This means an enemy spawned in Wave 8 and killed in Wave
9 still awards its Wave 8 XP. A pickup starts moving toward the player inside 165
pixels, or from any distance after it has existed for 7 seconds. XP is credited
when the pickup reaches the player. If all 180 pickup slots are occupied, new XP is
credited immediately instead of being lost.

### Exact XP awarded per enemy by spawn wave

Rusher and Corruptor share the same XP value and are combined as `R/C` below. CC
means Colony Core. These are per-enemy values, not totals for the wave; multiply
them by kills of that type to calculate XP earned. Elite and Boss XP appear only
in the waves where those milestone enemies spawn, but their values are included in
every row so the scaling rule remains explicit for debug or future spawns.

| Wave | H | G | S | R/C | CC | Co | W | HG | SC | E | B |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 2 | 3 | 4 | 6 | 7 | 8 | 10 | 11 | 12 | 28 | 100 |
| 2 | 3 | 4 | 5 | 7 | 8 | 9 | 11 | 13 | 14 | 31 | 110 |
| 3 | 4 | 5 | 6 | 8 | 9 | 10 | 12 | 14 | 15 | 34 | 120 |
| 4 | 5 | 6 | 7 | 9 | 10 | 11 | 13 | 15 | 16 | 37 | 130 |
| 5 | 6 | 7 | 8 | 10 | 11 | 12 | 14 | 16 | 17 | 40 | 140 |
| 6 | 7 | 8 | 9 | 11 | 12 | 13 | 15 | 17 | 18 | 42 | 150 |
| 7 | 8 | 9 | 10 | 12 | 13 | 14 | 16 | 18 | 20 | 45 | 160 |
| 8 | 9 | 10 | 11 | 13 | 14 | 15 | 17 | 19 | 21 | 48 | 170 |
| 9 | 10 | 11 | 12 | 14 | 15 | 16 | 18 | 20 | 22 | 51 | 180 |
| 10 | 11 | 12 | 13 | 15 | 16 | 17 | 19 | 21 | 23 | 54 | 190 |
| 11 | 12 | 13 | 14 | 16 | 17 | 18 | 20 | 22 | 24 | 56 | 200 |
| 12 | 13 | 14 | 15 | 17 | 18 | 19 | 21 | 24 | 26 | 59 | 210 |
| 13 | 14 | 15 | 16 | 18 | 19 | 20 | 22 | 25 | 27 | 62 | 220 |
| 14 | 15 | 16 | 17 | 19 | 20 | 21 | 23 | 26 | 28 | 65 | 230 |
| 15 | 16 | 17 | 18 | 20 | 21 | 22 | 24 | 27 | 29 | 68 | 240 |
| 16 | 17 | 18 | 19 | 21 | 22 | 23 | 25 | 28 | 30 | 70 | 250 |
| 17 | 18 | 19 | 20 | 22 | 23 | 24 | 26 | 29 | 32 | 73 | 260 |
| 18 | 19 | 20 | 21 | 23 | 24 | 25 | 27 | 30 | 33 | 76 | 270 |
| 19 | 20 | 21 | 22 | 24 | 25 | 26 | 28 | 31 | 34 | 79 | 280 |
| 20 | 21 | 22 | 23 | 25 | 26 | 27 | 29 | 32 | 35 | 82 | 290 |
| 21 | 22 | 23 | 24 | 26 | 27 | 28 | 30 | 33 | 36 | 84 | 300 |
| 22 | 23 | 24 | 25 | 27 | 28 | 29 | 31 | 35 | 38 | 87 | 310 |
| 23 | 24 | 25 | 26 | 28 | 29 | 30 | 32 | 36 | 39 | 90 | 320 |
| 24 | 25 | 26 | 27 | 29 | 30 | 31 | 33 | 37 | 40 | 93 | 330 |
| 25 | 26 | 27 | 28 | 30 | 31 | 32 | 34 | 38 | 41 | 96 | 340 |
| 26 | 27 | 28 | 29 | 31 | 32 | 33 | 35 | 39 | 42 | 98 | 350 |
| 27 | 28 | 29 | 30 | 32 | 33 | 34 | 36 | 40 | 44 | 101 | 360 |
| 28 | 29 | 30 | 31 | 33 | 34 | 35 | 37 | 41 | 45 | 104 | 370 |
| 29 | 30 | 31 | 32 | 34 | 35 | 36 | 38 | 42 | 46 | 107 | 380 |
| 30 | 31 | 32 | 33 | 35 | 36 | 37 | 39 | 43 | 47 | 110 | 390 |

### Level thresholds

Campaign starts at Level 1 with 0 XP. The XP needed to advance from the current
level is:

```text
required XP = max(1, round(7 × 1.20^(current level - 1)))
```

XP is spent from the current bar when the threshold is reached. Any excess remains
toward the next level. Each level gained normally pauses the run and presents one
choose-one-of-three upgrade draft. Only one draft may be pending, so a large XP
gain cannot open overlapping reward screens: after the player chooses, retained XP
is checked immediately and can open the next draft.

There is therefore no fixed number of seconds or waves between level-up rewards.
Their frequency is exactly the player's collected kill XP divided across the
thresholds below. The cumulative column is the minimum lifetime XP needed to reach
the destination level with no other XP spending.

| Level transition | XP for this level | Cumulative XP |
|---:|---:|---:|
| 1 → 2 | 7 | 7 |
| 2 → 3 | 8 | 15 |
| 3 → 4 | 10 | 25 |
| 4 → 5 | 12 | 37 |
| 5 → 6 | 15 | 52 |
| 6 → 7 | 17 | 69 |
| 7 → 8 | 21 | 90 |
| 8 → 9 | 25 | 115 |
| 9 → 10 | 30 | 145 |
| 10 → 11 | 36 | 181 |
| 11 → 12 | 43 | 224 |
| 12 → 13 | 52 | 276 |
| 13 → 14 | 62 | 338 |
| 14 → 15 | 75 | 413 |
| 15 → 16 | 90 | 503 |
| 16 → 17 | 108 | 611 |
| 17 → 18 | 129 | 740 |
| 18 → 19 | 155 | 895 |
| 19 → 20 | 186 | 1,081 |
| 20 → 21 | 224 | 1,305 |
| 21 → 22 | 268 | 1,573 |
| 22 → 23 | 322 | 1,895 |
| 23 → 24 | 386 | 2,281 |
| 24 → 25 | 464 | 2,745 |
| 25 → 26 | 556 | 3,301 |
| 26 → 27 | 668 | 3,969 |
| 27 → 28 | 801 | 4,770 |
| 28 → 29 | 962 | 5,732 |
| 29 → 30 | 1,154 | 6,886 |
| 30 → 31 | 1,385 | 8,271 |

The formula continues without a hard character-level cap. Individual upgrade
lines cap at rank 5. Before Evolution, at most eight different lines may occupy
upgrade slots; Evolution expands that to thirteen. An Evolution choice can occupy
one slot in a normal level-up offer and consumes that level's reward. When no valid
draft option remains, the level still advances and spends its XP, but 75% of that
level's required XP is converted to Biomass instead of showing an upgrade choice.
Campaign grants three upgrade-draft rerolls for the entire run.

The support-Adaptation choice due at 1,200 seconds is separate from leveling. It
is offered only after the paired paths have evolved, does not consume XP, and does
not replace a level-up reward. If another choice is already open, it waits.

## Relic acquisition schedule

A completed Campaign is authored to award **12 relic choices**:

| Source | Scheduled time | Wave | Relic choices |
|---|---:|---:|---:|
| Every third wave | 2:00 | 3 | 1 |
| Every third wave | 5:00 | 6 | 1 |
| Elite Rootbreaker defeat | Spawns at 6:15; defeat time varies | 7 or later | 1 |
| Every third wave | 8:00 | 9 | 1 |
| Every third wave | 11:00 | 12 | 1 |
| Every third wave | 14:00 | 15 | 1 |
| Burrower Boss defeat | Eligible at 15:00; spawns at 15:00-15:05 depending on the break; defeat time varies | 16 or later | 1 |
| Every third wave | 17:00 | 18 | 1 |
| Every third wave | 20:00 | 21 | 1 |
| Every third wave | 23:00 | 24 | 1 |
| Every third wave | 26:00 | 27 | 1 |
| Every third wave | 29:00 | 30 | 1 |
| **Total** |  |  | **12** |

The wave schedule contributes ten choices, on Waves 3, 6, 9, 12, 15, 18, 21,
24, 27, and 30. Defeating the one Elite and one Boss contributes two more. Each
reward offers up to three unowned eligible relics and the player takes one. The run
has two relic-offer rerolls, tracked separately from upgrade rerolls.

If the 130-active-enemy cap blocks the Elite or Boss at its scheduled time, the
director retries that milestone spawn every subsequent frame until a slot opens.

Wave rewards are debts rather than missable popups. If an upgrade, Evolution,
support, or relic choice is already on screen, the wave reward waits until the
panel clears. The simulation pauses while any choice is open, so run-clock reward
times do not pass behind an unresolved choice.

If the player has exhausted every eligible relic, a relic reward gives 24 Biomass
instead (`8 base Biomass × 3`). That settles the scheduled reward but does not add
a relic. Consequently, 12 is the number of authored relic opportunities in a
completed Campaign; the number actually owned can be lower only if the eligible
pool is exhausted and overflow conversion occurs.
