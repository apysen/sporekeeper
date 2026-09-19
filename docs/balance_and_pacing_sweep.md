# Balance and pacing: a measured sweep

**2026-09-18/19.** Every Core pair driven through the same forty seconds on the same
board, at three rank levels and under two pressures, plus three whole runs driven minute
by minute on the real wave clock. Nothing here is read off an Inspector and multiplied in
my head, because that is exactly the method that cannot see the things this document is
about: reach, target supply, and what a build is standing on.

The instruments are `tools/balance_bench.gd` and `tools/pacing_probe.gd`. Both are
described in their own headers; the short version and its limits are below, because a
number is only worth as much as the conditions it was taken under.

---

## 1. How it was measured, and what that cannot tell you

**The bench** puts the same Green island on the same field, commits a Core pair, buys all
eight of its lines to the same rank, and holds a fixed population of Hunters on the board
by respawning each one that dies. It steps combat, the path directors, the catalyst
overlay and the field by hand at a fixed delta. What it reports is damage actually
applied, kills, ground held at the end, Biomass earned, and damage that got through.

Two conditions:

- **22 Hunters entering from 230px** - the ordinary bench, a board a build can keep clear.
- **60 Hunters entering from 130px** (`--siege`) - a board it cannot, which is the only
  condition under which "how much does this build *stop*" is a measurable question.

**The pacing probe** drives a real run on the real wave schedule, answering each level-up
by policy: claim the Evolution on sight, then rank it, then finish whichever Core line is
nearest its ceiling. That last rule matters more than it sounds - see §5.

**Grandma stands still and cannot die in either instrument.** That is the honest limit.
It under-reads every kit that pays for movement - Thistle carry, Fruit rolls, Pruning
charges - and reads turrets and sweeps at full value. It also excludes the Clover machine
and relics entirely, so what is compared is Adaptations rather than runs. Where a number
below is a floor rather than a reading, it says so.

---

## 2. The headline

Four things came out of this that are worth acting on, in this order:

1. **One Thornwhip rank is worth sixteen ordinary ranks.** Its first rank - the only one a
   Quick run reaches - adds +50% to a pair that is already top-three, for a single pick,
   where sixteen ordinary picks add +48%. It multiplies four axes that are each already
   multiplicative, and runs to +115% at a rank neither mode reaches. §4.
2. **The territory Adaptations are not better at territory, and the gap is not a
   percentage.** Over a full Quick run Spore+Root takes **1,872** damage to Thistle+Vine's
   **27**, loses the board by minute seven, and finishes holding 0.6% of the arena against
   53%. There is currently no axis on which those pairs lead - not ground, not Biomass, not
   damage taken. §6.
3. **Player output outgrows the wave curve by roughly an order of magnitude.** Enemy
   health rises ×1.9 across a Quick run while a committed build's damage per minute rises
   about ×60. The back half of a run is decided by minute six. §5.
4. **Pruning, which nobody has complained about, is the strongest Adaptation under
   pressure.** Every Pruning pair takes 17 damage in forty seconds of being surrounded by
   sixty enemies - Thistle+Vine takes 209 - and four of the seven are in the top eight for
   output. If Thistle+Vine is the build that feels overpowered, Pruning is the one that
   measures that way. §3.2.

---

## 3. The pair sweep

Forty seconds, 22 held Hunters, every line at rank 3, no Evolution. Sorted by damage
applied. `green` is the share of the arena held at the end, starting from 5.97% for every
row.

| pair | damage | kills | green % | mature % | biomass |
|---|---|---|---|---|---|
| Root+Vine | 13,244 | 473 | 42.6 | 33.7 | 38.4 |
| Pruning+Vine | 13,132 | 469 | 35.0 | 25.1 | 27.1 |
| Thistle+Vine | 12,144 | 432 | 31.4 | 24.1 | 26.1 |
| Pruning+Thistle | 11,512 | 409 | 32.5 | 15.6 | 19.4 |
| Vine+Fruit | 11,321 | 404 | 58.3 | 40.0 | 42.8 |
| Thistle+Fruit | 10,585 | 373 | 50.8 | 33.9 | 35.6 |
| Pruning+Fruit | 10,472 | 373 | 48.6 | 28.3 | 32.5 |
| Spore+Vine | 10,388 | 371 | 42.6 | 34.1 | 38.3 |
| Bloom+Vine | 10,220 | 365 | 30.7 | 19.5 | 23.2 |
| Bramble+Pruning | 10,046 | 358 | 24.9 | 16.0 | 18.3 |
| Bloom+Pruning | 9,940 | 355 | 24.6 | 16.4 | 18.3 |
| Bramble+Vine | 9,762 | 348 | 27.8 | 21.3 | 22.5 |
| Root+Pruning | 9,604 | 343 | 29.5 | 21.4 | 22.5 |
| Spore+Pruning | 9,244 | 330 | 34.8 | 18.1 | 22.7 |
| Bramble+Thistle | 8,680 | 305 | 18.4 | 13.7 | 15.6 |
| Spore+Thistle | 8,591 | 304 | 28.4 | 20.3 | 21.0 |
| Bloom+Thistle | 8,524 | 298 | 20.7 | 14.2 | 16.7 |
| Root+Fruit | 7,584 | 270 | 53.4 | 35.1 | 35.0 |
| Spore+Fruit | 7,487 | 264 | 29.5 | 20.8 | 22.3 |
| Root+Thistle | 7,380 | 258 | 21.1 | 16.8 | 19.4 |
| Bloom+Fruit | 7,348 | 259 | 37.4 | 24.3 | 27.6 |
| Bramble+Fruit | 7,096 | 252 | 28.6 | 19.3 | 21.6 |
| **Spore+Bramble** | 5,638 | 198 | 11.7 | 10.1 | 12.6 |
| **Spore+Bloom** | 5,581 | 196 | 18.6 | 14.0 | 16.7 |
| **Bloom+Bramble** | 5,226 | 182 | 14.4 | 10.9 | 13.6 |
| **Spore+Root** | 5,218 | 184 | 12.3 | 10.8 | 14.2 |
| **Bloom+Root** | 5,108 | 179 | 17.2 | 14.0 | 16.1 |
| **Bramble+Root** | 4,991 | 173 | 10.6 | 9.6 | 12.6 |

Mean 8,788. The spread from best to worst is **2.65×**, and it is not noise: the ordering
is stable across reruns because the bench is deterministic.

**Vine is in seven of the top nine rows.** Every pair containing Vine beats the mean.
Every pair containing neither Vine, Thistle, Pruning nor Fruit is in the bottom six.

### 3.1 The same sweep at rank 1

Every line at rank 1 instead of 3 - roughly where a build stands in the first three
minutes. Mean 5,918. The Cane on its own, with a pair committed and nothing bought into
it, deals **4,152**.

| pair | damage | over bare Cane |
|---|---|---|
| Pruning+Fruit | 9,996 | +141% |
| Vine+Fruit | 8,278 | +99% |
| Thistle+Vine | 8,224 | +98% |
| Root+Vine | 8,036 | +94% |
| Pruning+Vine | 7,700 | +85% |
| …every other Vine pair | 7,538–7,588 | +82% |
| Thistle pairs (not Vine) | 5,272–6,753 | +27–63% |
| Bramble+Root | 4,371 | +5% |
| **Spore+Root, Spore+Bloom, Spore+Pruning, Bloom+Root, Bloom+Pruning, Root+Pruning** | **4,152** | **+0%** |
| **Spore+Bramble, Bloom+Bramble, Bramble+Pruning** | **4,104** | **−1%** |

Nine pairs are, at rank 1, **indistinguishable from having no Adaptations at all**. Not
"weak" - identical, to the point of returning the same number to the digit, because their
first rank adds nothing that removes a body. A player who opens Spore+Root spends the
first three minutes playing a run with no build in it, and that is most of what "territory
builds are harder" is.

Vine, by contrast, is worth +98% on its first rank.

### 3.2 The same sweep under siege

Sixty Hunters entering at 130px, every line at rank 3 - a board no build clears, which is
the only condition where "what does this build *stop*" can be read. Mean 42,098.

| pair | damage | kills | green % | damage taken |
|---|---|---|---|---|
| **Pruning+Vine** | 77,924 | 2,783 | 40.0 | **17** |
| Root+Vine | 65,996 | 2,357 | 49.2 | 176 |
| **Pruning+Fruit** | 61,292 | 2,189 | 30.4 | **17** |
| **Pruning+Thistle** | 60,612 | 2,163 | 26.1 | **17** |
| Vine+Fruit | 59,836 | 2,137 | 36.1 | 149 |
| **Bloom+Pruning** | 59,024 | 2,108 | 26.5 | **17** |
| **Bramble+Pruning** | 57,607 | 2,056 | 25.9 | **17** |
| **Root+Pruning** | 57,484 | 2,053 | 23.6 | **17** |
| **Spore+Pruning** | 56,994 | 2,035 | 25.5 | **17** |
| Bloom+Vine | 54,768 | 1,956 | 34.0 | 215 |
| Thistle+Vine | 53,564 | 1,913 | 28.6 | 209 |
| Spore+Vine | 53,435 | 1,907 | 48.6 | 242 |
| Bramble+Vine | 52,817 | 1,885 | 32.1 | 215 |
| Thistle+Fruit | 34,732 | 1,231 | 18.4 | 209 |
| Spore+Fruit | 34,569 | 1,231 | 22.9 | 226 |
| Root+Fruit | 33,728 | 1,196 | 24.1 | 226 |
| Bloom+Fruit | 33,413 | 1,188 | 24.0 | 259 |
| Bramble+Fruit | 31,113 | 1,099 | 19.9 | 215 |
| Spore+Thistle | 28,445 | 1,000 | 16.9 | 352 |
| Spore+Bramble | 25,822 | 911 | 13.5 | 347 |
| Spore+Bloom | 25,643 | 903 | 23.8 | 347 |
| Root+Thistle | 25,248 | 882 | 20.8 | 369 |
| Bramble+Thistle | 24,242 | 855 | 12.6 | 369 |
| Bloom+Thistle | 24,040 | 844 | 19.9 | 347 |
| Spore+Root | 23,979 | 841 | 13.8 | 358 |
| Bramble+Root | 22,202 | 783 | 11.6 | 358 |
| Bloom+Bramble | 20,804 | 720 | 16.6 | 363 |
| Bloom+Root | 19,408 | 658 | 21.5 | 341 |

Three things in that table were not visible anywhere else.

**Pruning is the best Adaptation in the game under pressure, and nobody said so.** Every
one of the seven Pruning pairs took exactly **17** damage across forty seconds of being
surrounded by sixty enemies, and four of them are in the top eight for damage. Its ring
harvests the ground around her, which is both an attack and a wall, and being surrounded
is the condition it is best in. Thistle+Vine, the pair under suspicion, took **209**.

**Damage taken is inversely correlated with damage dealt.** The top of the table takes
17-242; the bottom takes 341-369. There is no row that trades output for safety. In the
measured conditions, killing the thing *is* the defence, which is the core reason the
defensive Adaptations do not compensate for their output (§6.3).

**Every build gains about the same amount from a crowd.** Thistle+Vine goes 12,144 →
53,564 from 22 targets to 60 (×4.4); Bramble+Root goes 4,991 → 22,202 (×4.4). The mean
goes ×4.8 for ×2.7 the targets. So density makes *every* build stronger per enemy, which
matters for §7.4: the game's main difficulty lever is the one that helps the player most.

**The bottom six share a property**: they are pairs of Adaptations that have no base
output of their own. Root multiplies what a partner does (Root+Vine is the best row in
the table and Root+Thistle is a bottom-half row - see §6.2), Bramble converts held ground
into slow and shove, Spore converts kills into Seeds, Bloom converts a cadence into an
area. Pair two of those together and there is nothing for either to multiply.

---

## 4. Thistle+Vine, and Thornwhip

### 4.1 Before the Evolution

Thistle+Vine sits third at rank 3 and is beaten by Root+Vine and Pruning+Vine, so on the
bench alone the pair is strong rather than broken. It stays third under siege as well
(§3.2). **Before the Evolution, Thistle+Vine is a strong pair and not an outlier** - the
measurement does not support the stronger version of the complaint, and the reason it
still *feels* like one is probably §4.3 rather than §4.1.

The arithmetic behind the pair, all four lines at rank 3:

- **Vine**: damage ×1.75, cadence ×1.45, reach ×1.6 - and reach is a *radius*, so the
  swept area goes ×2.56. Multiplied out that is **6.5× the base Cane** for twelve picks,
  before the apical bonus.
- **Thistle**: Clustering takes one thorn to four, Burr gives each thorn three extra
  **full-damage** ricochet targets, so one firing event goes from 1 hit to **16**;
  Needlepoint takes critical damage from 2× to 5× at a 10% rate, worth ×1.4 expected;
  Dehiscence cuts the interval to 0.76s. That is 12 × 16 × 1.4 / 0.76 ≈ **354 damage per
  second from one turret**, when there are sixteen targets to find.

Neither of those is unreasonable on its own. They are listed here because Thornwhip
multiplies them together.

### 4.2 Thornwhip

Mounted Thistle heads fire through each Vine sweep. At rank 5: **four heads, twice per
sweep**, and each head fires a full Clustering volley of thorns that carry full Burr
ricochets and full Needlepoint criticals.

Per Vine sweep, at Thistle rank 3: 2 packets × 4 heads × 4 thorns × 4 targets =
**128 thorn hits**, at 12 damage and ×1.4 expected criticals ≈ **2,150 damage per sweep**.
At Vine rank 3 the sweep cadence is 0.497s, so the ceiling is about **4,300 damage per
second** - target-limited, which means it rises with the crowd.

Measured, rank 3 lines, 22 targets, against the same pair's unevolved 12,144:

| Evolution rank | what it adds | damage | vs. unevolved | picks spent |
|---|---|---|---|---|
| 1 | two mounted heads | 18,212 | **+50%** | 1 |
| 2 | a third head | 20,012 | +65% | 2 |
| 3 | outer head inherits Apical | 20,672 | +70% | 3 |
| 4 | a fourth head | 22,133 | +82% | 4 |
| 5 | every head fires twice | 26,143 | **+115%** | 5 |

At rank 5 under siege it deals 95,705 against the sweep's 42,098 mean (**2.27×**), takes
**22** damage where the unevolved pair takes 209, and holds 58.4% of the arena against
sixty enemies.

**The first rank is the problem, not the fifth.** One pick buys +50%. For comparison,
going from every line at rank 1 to every line at rank 3 - **sixteen** ordinary picks -
buys +48%. A single Thornwhip rank is worth sixteen ordinary ranks, and that is true at
the rank both modes actually reach (§5.3).

For comparison, here is what every Evolution is worth on the same bench, as a percentage
added to its own pair's unevolved damage:

| Evolution (pair) | damage delta | note |
|---|---|---|
| Thornwhip (Thistle+Vine) | **+115%** | |
| Burdock (Thistle+Fruit) | +100% | also the second-largest, also Thistle |
| Super Bloom (Spore+Bloom) | +89% | on a bottom-six pair - this one is working |
| Bramble+Pruning | +41% | |
| Pruning+Thistle | +35% | |
| Bramble+Root | +30% | |
| Bloom+Fruit | +46% | and green 37% → **95.9%** |
| Root+Vine | +8% | |
| Root+Pruning | +3% | |
| Vine+Fruit, Pruning+Fruit, Spore+Bramble, Bloom+Bramble, Bramble+Vine, Spore+Vine | **0% or negative** | no measurable damage contribution |

Two separate problems are visible in that column. Thornwhip and Burdock - the two Thistle
Evolutions - are worth roughly a whole second build. Six Evolutions are worth nothing
measurable in damage, though two of them (Bloom+Fruit, and Bloom+Root at +40% ground) are
clearly paying in territory instead, which this bench does capture and which the table
above does not rank on.

### 4.3 Why it compounds

Thornwhip is not a big number added to a build. It is a **fourth multiplication** on a
chain that already has three:

```
thorns per event   ×  targets per thorn  ×  critical expectation  ×  events per sweep
   (Clustering)         (Burr)               (Needlepoint)           (Thornwhip r5)
      4             ×      4              ×       1.4            ×       8
```

Every one of those is bought with ordinary picks, and every one multiplies the others.
The sweep cadence that fires them is itself bought (Turgor, ×1.45). This is why it reads
as broken rather than strong: nothing in it is individually outrageous.

---

## 5. Pacing

### 5.1 The upgrade curve

Level *n* costs `round(7 × growth^(n-1))`, with growth **1.34 in Quick** and **1.20 in
Campaign**. Cumulative:

| level | Quick cumulative XP | Campaign cumulative XP |
|---|---|---|
| 6 | 99 | 69 |
| 12 | 671 | 276 |
| 18 | 3,976 | 895 |
| 24 | 23,108 | 2,745 |

Campaign is **8.4× cheaper** at level 24 for a run that is only ~2× longer. Two modes,
two quite different relationships between a run and its build.

### 5.2 What a Quick run actually reaches

Thistle+Vine, Quick, driven on the real schedule:

| minute | wave | level | picks | core ranks | evo | kills | green % | Hunter HP | cumulative damage |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 2 | 6 | 5 | 5/24 | 0 | 48 | 5.9 | 31 | 1,603 |
| 3 | 4 | 12 | 12 | 11/24 | 0 | 161 | 8.5 | 38 | 6,226 |
| 6 | 7 | 16 | 16 | 15/24 | 0 | 377 | 16.2 | 47 | 19,898 |
| 9 | 10 | 21 | 22 | 19/24 | 1 | 982 | 34.6 | 57 | 91,499 |
| 12 | 12 | 26 | 27 | 23/24 | 1 | 2,854 | 53.2 | — | 328,208 |

Damage per minute goes from **1,603 to about 95,000**: roughly **×60**. A Hunter goes from
31 health to 60: **×1.9**. Spawn density rises about ×9.6 over the same period. Multiply
the last two and the demand on the player rises perhaps ×18 while supply rises ×60.

That gap is the "slow" feeling. It is not that the early game is slow; it is that after
about minute six the run stops being able to threaten a committed damage build, and the
remaining six minutes are spent watching a build that has already won.

### 5.3 When the Evolution arrives

This is the number the whole Evolution question turns on, and it is worth stating
carefully because the first measurement of it was wrong.

The pairing unlocks on **two mastered lines in each Core** - twelve targeted picks. Both
pick policies I drove it with claimed it at **pick 21-22, around minute nine or ten of
twelve**, and neither ever bought a second rank of it.

That is not the policy's fault, and it is worth being precise about why, because it is a
deliberate rule doing it. `_weighted_take` halves the weight of any line whose Adaptation
is already represented on the screen being built - *"three lines of one Adaptation is a
screen that only decides how fast, never what"*. The draft is actively spreading offers
across Adaptations, so a player trying to master four specific lines out of a pool of
sixteen-plus is fighting the weighting the whole way.

A full Campaign run, same pair, same policy, measured end to end:

| minute | wave | level | picks | evo rank | kills | green % | Hunter HP | damage | taken |
|---|---|---|---|---|---|---|---|---|---|
| 5 | 6 | 15 | 14 | 0 | 382 | 5.8 | 42 | 18,504 | 120 |
| 7 | 8 | 17 | 17 | **1** | 615 | 7.8 | 48 | 38,566 | 229 |
| 11 | 12 | 21 | 21 | **2** | 1,344 | 21.6 | 60 | 115,842 | 229 |
| 13 | 14 | 22 | 23 | **3** | 1,758 | 31.0 | 66 | 170,754 | 248 |
| 19 | 20 | 25 | 26 | 3 | 3,178 | 33.0 | — | 425,350 | 248 |
| 25 | 25 | 28 | 29 | **3** | 5,656 | 33.4 | — | 978,420 | 248 |

So the honest version: **neither mode reaches rank 5.** Quick claims the pairing around
minute nine or ten and finishes at rank 1. Campaign claims it at minute seven, reaches
rank 3 by minute thirteen, and is still at rank 3 when the run ends twelve minutes later.

That does not make it less of a problem - §4.2 shows rank 1 is already +50% for one pick -
but it does mean the +115% ceiling is a number nobody plays against, and a fix aimed only
at rank 5 would change nothing anybody experiences.

The Campaign run also takes **248 damage across twenty-five minutes** while dealing
978,420, against enemies that end at ×3.2 the opening health. Nothing in that run was ever
in danger.

### 5.4 Build order decides a Quick run more than the pair does

The same pair, the same seed, the same schedule, two pick orders:

| | Vine damage early | Thistle first |
|---|---|---|
| green % at 6:00 | 16.2 | 9.2 |
| green % at 12:00 | **53.2** | **0.0** |
| enemies alive at 11:00 | ~20 | **127** (cap is 130) |
| kills | 2,854 | 2,629 |

The second run lost the board. Lignification - Vine's damage line - came at pick 27 of 27,
so the Cane stayed at base damage while Hunter health climbed from 31 to 60, the frontier
went backwards, and once Green was gone the Thistles had nowhere to stand. A stationary
player exaggerates this, but the shape is real: **the first three picks decide a Quick
run**, and they are drawn from a weighted pool rather than chosen from the whole roster.

---

## 6. Why the territory pairs lose

### 6.1 They are not ahead on territory

Two full Quick runs, same schedule, same pick policy (the spread policy of §5.4, which is
the one that plays Thistle+Vine well):

| | Thistle+Vine | Spore+Root |
|---|---|---|
| kills at 12:00 | 2,854 | 2,567 |
| damage at 12:00 | 328,208 | 290,956 |
| **green % at 12:00** | **53.2** | **36.1** |
| green % at 6:00 | 16.2 | 8.2 |
| Biomass earned | higher at every sample | |

The damage pair holds more ground than the territory pair, at every sample, in a run
where neither player moved. That is the finding, and it is not subtle.

### 6.1b What a Spore+Root run actually looks like

The full run, minute by minute. `alive` is the enemy population - it only climbs when the
schedule is spawning faster than the build can clear - and `taken` is cumulative damage
through Grandma, who has 100 maximum health and cannot die here.

| minute | alive | green % | kills | damage dealt | damage taken |
|---|---|---|---|---|---|
| 1 | 8 | 5.5 | 46 | 1,553 | **237** |
| 3 | 10 | 6.6 | 158 | 6,067 | 858 |
| 5 | 18 | 8.5 | 287 | 13,411 | 1,446 |
| 6 | 30 | 9.3 | 357 | 17,380 | 1,757 |
| 7 | **70** | 4.9 | 487 | 28,684 | 1,872 |
| 8 | **110** | 1.6 | 655 | 53,051 | 1,872 |
| 10 | **128** | 1.2 | 1,170 | 108,719 | 1,872 |
| 12 | 90 | **0.6** | 1,627 | 165,272 | 1,872 |

The population cap is 130. This build reaches it by minute ten, the frontier collapses
from 9.3% to under 1%, and the run is mathematically over around minute seven - the
damage-taken column stops rising there because the run had already ended and only the
combat loop kept stepping.

**Grandma takes 237 damage in the first minute** - more than twice her maximum health -
against wave-two Hunters. Thistle+Vine takes **27 across the entire twelve minutes**.
That is a 70× difference in incoming damage between two Core pairs the game offers on the
same screen, and it is visible by the sixty-second mark.

The pick order was Growth Mass ×3, Maturation Speed, Seed Production ×3 - twelve picks
into Spore and Root before anything that removes a body, because *nothing in either
Adaptation removes a body*.

The reason is mechanical: **ground is taken by clearing the enemies that are eroding it.**
Killing is a territory stat, and the paths that kill best therefore also hold most. Spore,
Root and Bramble each convert something into something that is not clear rate - Root into
maturity and amplification, Bramble into slow and shove, Spore into Seeds - and the loop
never closes back into removing the bodies that are eating the frontier.

### 6.2 Root is a multiplier, not a path

Root+Vine is the **best** row in the table (13,244) and Root+Thistle is a bottom-half row
(7,380), while Bramble+Root and Spore+Root are the two worst. Root's four lines are
+66% maturation, +72px network reach, +48% mature resistance, +66% network amplification.
Only the last of those does anything for output, and only for a partner that has output to
amplify - and only over Mature ground, which takes time the bench's forty seconds barely
gives it.

That is a coherent design for a support Adaptation. What is missing is the rule that stops
a player from pairing two supports and getting a build with nothing in it.

### 6.3 Defence does not compensate

The full siege table is §3.2, and it is unambiguous: the four pairs that take the **most**
damage are Root+Thistle, Bramble+Thistle, Bloom+Bramble and Bramble+Root - three of the
four contain a defensive Adaptation. Bramble+Root takes 358 while Thistle+Vine takes 209
and every Pruning pair takes 17.

Bramble's slow and shove are real and measurable. They are simply worth less than removing
the attacker, and there is no density at which that reverses.

---

## 7. What I would change

Ordered by how much it moves, with the specific number in each case. None of this has been
applied - these are proposals, and every one of them is a design call rather than a bug
fix.

**The proposals are written up properly in `docs/balance_change_proposals.md`**, with the
file and symbol for each, and with the Thornwhip options measured rather than predicted.
What follows is the reasoning; that document is the list to work from.

### 7.1 Thornwhip

The goal is to take out one multiplication, not to shave a percentage - **and to aim it at
rank 1**, which is where +50% of the +115% already is and the only rank a Quick run sees.

- **Mounted heads fire one thorn, not a Clustering volley.** `_fire_mounted_head` currently
  reads `THISTLE_CLUSTERING` for its projectile count; dropping that takes the rank-5
  ceiling from 128 thorn hits per sweep to 32. Clustering still does everything it does for
  the planted Thistle.
- **Or: mounted thorns carry at most one ricochet.** `_spawn_thorn` already takes a
  `ricochet_cap_override`, so this is passing `1` instead of `-1` - one line, and it keeps
  the volley visual intact.

Either alone applies at every rank, including the first, and brings the pair to roughly
+30% from its Evolution - which is where the middle of the Evolution table sits. Doing both
would take it under, and is not recommended.

- **Rank 5 at 60%.** `Splinterstorm` already uses exactly this shape - *"a full Charge
  repeats the volley after 0.4s at 60% damage"* - so a second packet at 60% is an
  established precedent rather than a new rule.

### 7.2 Thistle's base multiplication

- **Burr ricochets at reduced damage.** The line's own description says "+1 **full-damage**
  ricochet target per thorn", which is the strongest possible form of that mechanic. At
  70% per bounce a rank-3 thorn goes from 4.0 to 3.1 effective targets, and the line still
  reads as what it is.

### 7.3 Vine's reach

- **Elongation +12% per rank rather than +20%.** Reach is a radius and the sweep is an arc,
  so the line currently buys area quadratically: rank 3 is ×2.56 area. At 12% it is ×1.75,
  which is still the strongest single line in the game and no longer the best pick in the
  game by a distance.

### 7.3b Pruning

Not part of the original question, and the number that surprised me most. The orbiting
Cutting ring is a permanent area attack centred on the player, fed by harvesting her own
Green, and being surrounded is the situation it is designed for. At rank 3 it is +90%
damage, +54% harvest rate, +66% yield.

It pays a real cost - `upkeep_cells_per_second` 9.0, spent out of the ecosystem - and the
siege table shows Pruning pairs holding a little less ground than Vine pairs. But
Pruning+Vine is simultaneously **first in damage, third in ground held, and tied for least
damage taken**, which is not a trade.

Before touching a number here I would want a run played with it, because this is the one
finding in this document that contradicts nobody's experience - it may simply be that the
Green cost bites in real play in a way a bench that regrows the island cannot show.

### 7.4 The pressure curve

- **Quick's `final_health_scale` 2.15 → 3.2**, and **`final_contact_damage_scale` 1.6 →
  2.0**. Quick currently ends softer than Campaign starts. This does not fix the ×60/×1.9
  divergence on its own - nothing that only touches enemy health will - but it puts the
  last four minutes back into the fight.
- **Density is not difficulty.** Going from 22 enemies to 60 multiplies the mean build's
  output by ×4.8 while multiplying the threat by ×2.7, because arcs, ricochets and rings
  all hit more per activation while each body's health stays where it was. The Quick
  schedule's main escalation lever - spawn interval 1.15s → 0.32s → 0.12s - therefore
  makes the player *relatively stronger* as the run goes on. That is the mechanism behind
  the ×60-against-×1.9 divergence in §5.2, and no amount of extra spawning will fix it.

  What escalates a fight against area damage is enemies that are individually worth
  killing and individually dangerous: health, elite modifiers, and roles that punish
  standing in one place. Campaign already does more of this than Quick (×3.6 health,
  modifiers from wave 4, six specialist roles); Quick does almost none of it.

### 7.5 The territory pairs

The first thing to fix is not the ceiling, it is **rank 1**. Nine pairs deal exactly the
bare Cane's damage with one rank in every line (§3.1), and Spore+Root has taken twice
Grandma's health by the sixty-second mark (§6.1b). Whatever else changes, every
Adaptation's first rank should do something that either removes a body or stops one -
that is the rank the run is survived on, and four Adaptations currently spend it on
properties of the ground.

Then, the cheapest interventions that do not redesign anything:

- **Give Bramble a damage line that scales with maturity.** It is the one path whose
  entire output is applied to enemies standing on your ground and whose damage does not
  grow with the run.
- **Let Root's amplification reach the Cane.** Root currently amplifies Vine, Thistle and
  Fruit lines the player owns. A Spore+Root run owns none of them, so Root amplifies
  nothing at all - which is why it is in the bottom two.

Neither of those closes the gap by itself, and the honest summary is that **territory is
not a win condition**: the only mechanical consequence of holding ground is Biomass income,
and the only exit from Biomass is Metabolism, which buys more ground. Until ground converts
into clear rate somewhere, a territory pair is a build that compounds into its own
currency.

---

## 8. What this did not measure

- **Movement.** Thistle carry, Fruit rolls and Pruning charges all pay for repositioning
  and all read low here. Their rows are floors.
- **Relics and the Clover machine.** Excluded from the bench entirely. A real run's power
  curve is above the one in §5.
- **Survival as a player experiences it.** Grandma cannot die in either instrument, so
  "how close was that" is not in any column.
- **Campaign's texture.** One full Campaign run is measured (§5.3), but only for
  Thistle+Vine and only as a schedule: what the modifier pool, the six specialist roles and
  the two boss milestones do to a *weak* pair over twenty-five minutes is not in here.
- **Every pair but two, over a whole run.** The 28-pair tables are forty-second benches.
  Only Thistle+Vine and Spore+Root were driven end to end, and the Spore+Root run is the
  one that showed a collapse a bench cannot: population reaching the cap, and the board
  going with it.
