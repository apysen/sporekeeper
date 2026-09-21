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

---

## 9. Instrument corrections, 2026-09-19

Everything above was measured with three defects in the bench. All three push the same
way — against control kits and against single-target kits — which is the direction §3 and
§6 both concluded in, so they are worth stating before any of those numbers is acted on
again.

None of this overturns §6.1. That comparison was two *full runs* on the pacing probe, and
the ground-held gap it found is not a bench artifact. What is in question is the
forty-second pair table in §3, and the reading that several Adaptations "provide almost no
immediate combat value" that came out of it.

### 9.1 The bench was unseeded

`reset_run()` rolls a fresh run seed unless one is authored, and the bench never authored
one. Every row therefore had its own critical hits, its own Thistle placements and its own
spawn jitter, so two rows differed by the build *and* by the dice.

The size of that is not academic: before the fix, two of Thistle's four lines measured
**below** Thistle with no lines bought at all. A line cannot subtract. Any gap in §3
narrower than about eight per cent was noise.

Fixed: one pinned seed for the whole sweep, `--seed` to re-run a reading on a second one.
Vine is RNG-free and now reproduces to the digit across seeds, which is the check that the
pin works.

### 9.2 The board had almost no territory on it

The bench board is one Bloom grown for seven seconds: about **six per cent** of the arena,
with the held population entering from a ring outside it. Bramble damages and tangles
enemies standing *on Green*. Root amplifies from Mature Green. Spore germinates into it.
All three were being measured almost entirely off their own ground.

`--island` plants five Blooms and grows them to about 92%. Bramble+Root, rank 3, siege:

| | patch board (6% Green) | island board (92% Green) |
|---|---|---|
| mean slow on the board | 0.000 | **0.409** |
| mean Entanglement | 0.005 | **0.574** |
| share Ensnared | 0.000 | **0.239** |
| damage taken | 6 | **0** |
| ground lost over 40s | −24.1 | **−0.95** |

On the patch board three of Bramble's four lines were **bit-identical** to the Adaptation
with nothing bought. That is not a finding about Bramble.

The honest reading is that the two boards are two different questions, and both are real:
the patch board is roughly what minute two of a run looks like, and the island board is
roughly minute twelve. A control Adaptation genuinely does little in the first case. What
cannot be concluded from the patch board alone is that it does little *at all*.

### 9.3 The damage column was counting kills

`debug_damage_applied_total` clips every hit to the target's remaining health, so it
measures health removed rather than damage produced. On a held-population board that makes
it a proxy for kills — damage divided by kills came out at 28–29 in every single row of
every sweep — and it reads zero for any source landing on targets something else is
already killing.

`debug_damage_dealt_total` now accumulates the unclipped figure beside it. The gap between
the two is overkill, which is itself the number worth having about a single-target line
standing next to an area sweep. The cane-only row added to `--isolate` is the other half:
on a crowded board the universal Cane is most of the damage in every row, so an Adaptation
that doubles its own output still moves the total by a few per cent.

### 9.4 Vine, line by line — Elongation is not the driver

Rank 3, siege, seeded, over a cane-only baseline of 15,248 applied / 25,848 dealt:

| row | applied | dealt | kills | applied over Vine base |
|---|---:|---:|---:|---:|
| cane only | 15,248 | 25,848 | 530 | |
| Vine, no lines | 21,656 | 36,696 | 752 | — |
| Apical Dominance | 24,296 | 40,500 | 854 | +2,640 |
| **Elongation** | 24,644 | 41,784 | 857 | **+2,988** |
| Turgor | 27,252 | 46,392 | 957 | +5,596 |
| **Lignification** | 35,112 | 52,764 | 1,254 | **+13,456** |

Reach is the second *weakest* of the four, at roughly a fifth of Lignification on applied
damage and a third on dealt. Same ordering on both boards, both metrics, both seeds — and
re-run unchanged to the digit after the pause defect in §9.8 was fixed, because Vine reads
neither the overlay nor the field.

**Decision: do not reduce Elongation.** Section 11 of the rework makes the cut conditional
on confirming that reach is a primary source of Vine's dominance, and it is not. Vine is
strong because Lignification multiplies a weapon every build already has. If Vine is to be
cut, that is the line to look at — and that is a design call nobody has authorised.

### 9.5 Thistle, line by line — no case for a Burr nerf

Same conditions, re-run after the §9.8 fix:

| row | applied | dealt | kills | applied over Thistle base |
|---|---:|---:|---:|---:|
| cane only | 15,248 | 25,848 | 530 | |
| Thistle, no lines | 15,680 | 26,304 | 548 | — |
| Dehiscence | 15,728 | 26,172 | 548 | +48 |
| Needlepoint | 15,912 | 26,700 | 552 | +232 |
| Clustering | 16,328 | 26,928 | 575 | +648 |
| **Burr** | 16,520 | 26,784 | 578 | **+840** |

The whole Adaptation at rank 3, best line included, is about **eight per cent** over the
Cane — and siege geometry, sixty bodies at 130px, is the *best* case a ricochet line will
ever get.

Burr is Thistle's **strongest** line, which the paused bench had it second. Needlepoint,
which that bench read as exactly zero, contributes +232; the paused figure was the overkill
effect compounded by a frozen player.

**Decision: do not add Burr ricochet falloff.** It is the best line of an Adaptation that
contributes eight per cent over the universal weapon at full rank. Section 10 asks for
Thistle to be evaluated independently before the cut; independently it is not carrying
anything, and cutting its best line would only deepen that. Whatever made Thistle+Vine the
top pair in §3 was Vine and Thornwhip.

### 9.6 Bramble, and a change the corrections reversed

Bramble on the island board, rank 3, siege, over the same cane-only baseline:

As it stands now — chip back at 0.18, slow at 0.25, run after the §9.8 fix:

| row | applied | kills | slow | tangle | pinned | taken |
|---|---:|---:|---:|---:|---:|---:|
| cane only | 15,248 | 530 | 0.000 | 0.000 | 0.000 | 363 |
| Bramble, no lines | 18,056 | 631 | 0.115 | 0.414 | 0.016 | 336 |
| Repulsion | 18,056 | 631 | 0.115 | 0.414 | 0.016 | 336 |
| Grasping Thorns | 16,686 | 586 | 0.151 | 0.446 | 0.053 | 363 |
| Entanglement | 17,531 | 609 | 0.178 | 0.426 | 0.016 | 341 |
| Entanglement Rate | 19,046 | 664 | 0.135 | 0.482 | 0.020 | 363 |

Two things in that table are worth more than the ordering.

**Bramble's base mechanic is worth real damage on ground it owns**, at +18% applied and
+19% kills over the Cane with nothing bought — from an Adaptation the pair sweep called
near-worthless. (The +70% figure taken before the chip revert was three times this, which
is precisely the change that was reverted.)

But Bramble alone barely improves survival: 336 taken against the Cane's 363. The lockdown
in §9.8's Bramble+Root row — zero damage, 0.62 slow, 0.32 pinned — is **not Bramble**. It is
Bramble's Entanglement scaled by Root's Mature ground through the Network multiplier. The
pair is the mechanism, which is exactly what a pair Evolution is supposed to mean.

**Its control lines cost it kill throughput.** Entanglement takes the board from 0.115
slow to 0.178 and drops damage from 18,056 to 17,531; Grasping Thorns triples the pinned
share and drops it further. Slowed enemies walk into the thorns more slowly. That is a real
trade and it is invisible in any table that prints damage alone.

Repulsion is bit-identical to base in all eleven columns. On this board it does nothing
measurable at all. Worth a look; not a rework item.

#### The chip-damage buff, measured and reverted

The early-Path pass raised `bramble_contact_damage` from 0.18 to 0.55 on the strength of
the patch-board reading. Running the same isolation with the pre-change values:

| Bramble, no lines | applied | kills | over Cane | slow | tangle | pinned |
|---|---:|---:|---:|---:|---:|---:|
| 0.18 chip | 18,771 | 656 | +3,523 | 0.049 | 0.389 | 0.012 |
| 0.55 chip | 25,950 | 912 | **+10,702** | 0.040 | 0.315 | 0.009 |

(Both rows predate the §9.8 fix, so their absolute figures are low and their slow column is
suppressed. They were taken under identical conditions, so the comparison between them
stands; the current state of the Adaptation is the table above.)

The buff tripled Bramble's contribution — and **lowered its slow, Entanglement and pin**,
because bodies that die faster never live long enough to accumulate any. It converted the
control Adaptation into a damage Adaptation, which is the one thing that line must not do.

**Reverted**: chip back to 0.18, max-health share back to 0.0005. The base slow increase
(0.15 → 0.25) **stays** — it is visible at rank 1, costs no throughput, and is the axis
section 7 actually asked for.

This is the clearest case in the document for why the instrument mattered. The buff was a
reasonable response to the reading available at the time; the reading was wrong, and the
change it produced was backwards.

### 9.7 Two of the four early-Path changes never ran

The confirming measurement after reverting Bramble's chip damage came back **bit-identical
to the pre-change run** across all eleven columns — including the slow column, which the
same pass had supposedly raised from 0.15 to 0.25.

`base_slow_fraction` and `bloom_interval_seconds` are `@export`s, and `run.tscn` sets both:

```
bloom_interval_seconds = 15.0
base_slow_fraction = 0.1
```

A scene value overrides the script default, so editing the default changes nothing about
the running game. The early-Path pass edited defaults for both. **Neither change had ever
taken effect** — the game was running 0.1 slow and a 15-second Bloom throughout, and the
0.15 the script claimed was not the number either.

This is worth more than the two changes. Exports are the Inspector design surface in this
project, which means the scene is authoritative for anything it sets, and a tuning pass
that edits script defaults is tuning a fallback nobody reads. Both defaults now carry a
comment saying so.

Applied since:

- **Bramble base slow 0.1 → 0.25, in `run.tscn`**, which is where it takes effect.
- **Bloom's default put back to 13.0 and left alone.** Re-applying the shortening in the
  scene would be a new, unmeasured change resting on the same biased reading that produced
  the Bramble chip mistake, so Bloom's rank-1 item stays open rather than being guessed at
  twice.

It also means the chip-damage finding in §9.6 is *cleaner* than it looked: both rows there
were taken at 0.1 slow, so the control drop was caused entirely by the chip buff killing
bodies before they tangled, with nothing else moving.

With the slow finally applied in the scene, Bramble base at 0.18 chip:

| Bramble, no lines | applied | kills | slow | tangle | pinned |
|---|---:|---:|---:|---:|---:|
| 0.1 slow | 18,771 | 656 | 0.049 | 0.389 | 0.012 |
| **0.25 slow** | 18,285 | 635 | **0.111** | 0.407 | 0.013 |

Measured slow more than doubles for about 2.6% of kill throughput. That is the shape the
change was supposed to have and the exact inverse of the chip buff's: control up sharply,
damage essentially flat. It is the one early-Path change in the pass that is now evidenced
rather than assumed.

### 9.8 The bench was pausing itself — a fifth defect, and the worst of them

The corrected sweeps put Spore+Bloom, Spore+Pruning and Bloom+Pruning at rank 1
bit-identical to the cane-only row in all eleven columns, and isolating Spore showed it
identical to owning nothing at rank 1 *and* rank 3. Instrumenting the catalyst path found
the cause, and it was not Spore.

Seeds were being sown correctly all along — 36 of them from 144 kills, rising to 48 with
one rank of Seed Production, exactly as designed. **None of them ever opened.**

`RunRoot._refresh_simulation_pause()` sets `effects_paused` on the overlay and
`simulation_paused` on the field and the player. It fires on any heavy hit, and the only
thing that ever clears it is `RunRoot._process` — which a bench that steps every system by
hand never calls. One heavy hit, and those three systems stayed paused for the rest of the
row.

Spore, no lines, rank 1, clearable board:

| | sown | germinated | green | biomass | taken |
|---|---:|---:|---:|---:|---:|
| paused | 36 | **0** | 5.92 | 8.7 | **6** |
| fixed | 36 | **33** | 9.33 | 11.2 | **330** |

Note the last column. §1 of this document complained that "every pair took 6 points of
damage in forty seconds, the same 6", diagnosed it correctly as `player._physics_process`
never running, and added the call. The call was right and was being swallowed by the early
return on `simulation_paused`, so the symptom it was written to fix had never gone away.

The bench now asserts all three flags false every step, and reports `sown` and `seeds`
(Seeds planted against Seeds that broke ground) and `blooms` so that a row which reads as
nothing can say whether the mechanic fired and did nothing or never fired at all.

#### What it cost, and what survived

The bias ran hardest against the *weakest* builds on the survivability axis: an early heavy
hit froze the player, so doing nothing looked safe. On the corrected bench the cane-only
row takes 363 damage at rank 3 where it used to read 6.

- **Rank 1 is a different table.** Nothing is inert. The weakest pair is now +12% over the
  bare Cane rather than +0%, and Pruning — which read as contributing *nothing* at rank 1 —
  is in fact the strongest rank-1 Adaptation, occupying the top seven rows. Its harvest and
  regrowth run through the field, which was the thing being paused.
- **Rank 3 barely moved.** Damage, kills and ground are unchanged to the digit for almost
  every row; only the cane baseline and a few Spore rows shifted.
- **§9.6's Bramble+Root result survives and is stronger.** It took zero damage before and
  zero after, while the baseline moved from 6 to 363. A build 27th of 28 on damage is the
  only one in the sweep that a siege cannot touch.

The rank-1 story is not that some pairs have no build. It is **damage taken**: Pruning and
Vine openings take 6 to 28 over forty seconds, and everything else takes 200 to 330. That
is where the weak openings actually lose, and it is a column that was broken until now.

### 9.9 Root's Cane floor, isolated

The floor added in the early-Path pass, measured on the corrected bench with Root owned
and one line bought at a time. Clearable board, rank 1 then rank 3:

| Root, rank 1 | applied | kills | green | taken |
|---|---:|---:|---:|---:|
| cane only | 4,152 | 144 | 9.33 | 330 |
| Root, no lines | 4,170 | 144 | 9.46 | 330 |
| Maturation / Lateral Roots / Mature Strength | 4,170 | 144 | ~9.45 | 330 |
| **Root Potency** | **4,928** | **176** | 10.31 | 308 |

At rank 3 Root Potency reaches 5,488 and 196 kills, about **+32%** over the bare Cane
against **+19%** at rank 1.

Three things this settles.

**The floor works and is correctly sized.** A Root opening with nothing to amplify is no
longer bare-Cane output; it is about a fifth better at rank 1 and a third better at rank 3.
That is a floor rather than a conversion into a damage Path — Vine's opening is four to
five times larger.

**It is Root Potency's, not Root's.** With no lines bought the floor is +18 damage and zero
extra kills, because it reads the Network multiplier and the Network is what Potency buys.
A player who takes Root and never buys Potency still has no floor. Whether that is right is
a design question the rework does not answer; it is at least *legible*, since Potency is
the line whose whole description is amplification.

**An earlier reading of +46% was wrong.** It came from the broken sweep, where Spore and
Bloom read as zero and Root+Spore therefore looked like Root alone. It was neither Root
alone nor a correct figure.

### 9.10 Campaign archetypes and Provocation, driven end to end

Section 33.3 and 33.4, run for the first time: five three-Adaptation rosters through a
whole twenty-wave Campaign on the real wave clock, plus two Provocation policies. Upgrades
are taken by the greedy build-completing policy, so every "when" below is the *earliest* a
build can reach that state rather than the average one.

| roster | first Evolution | build complete | green @10 | green @end | taken @end | alive @end |
|---|---:|---:|---:|---:|---:|---:|
| Vine+Thistle+Pruning | min 8 | min 16 | 31.4 | 42.6 | 0 | 1 |
| Spore+Bloom+Root | min 8 | min 16 | 35.5 | 22.2 | 1,309 | 32 |
| Bramble+Root+Spore | min 8 | min 17 | 71.3 | 31.8 | 1,010 | 19 |
| Thistle+Spore+Root | min 8 | min 16 | 90.1 | 73.1 | 590 | 0 |
| Thistle+Vine+Root | min 8 | min 15 | 33.8 | 61.8 | 0 | 0 |

**The Evolution timing target is met exactly.** All five rosters reach their first Evolution
at minute 8, against the rework's 6-to-8-minute target. That is the single clearest
confirmation that the wave-8/14/18 reward schedule is placed correctly.

**Build completion is slightly late.** Minute 15 to 17 against a design that wants the
build "largely complete" before the final five minutes. One roster makes 15; three make 16;
the defensive roster needs 17. The last quarter is therefore still finishing the build for
most of them rather than testing it.

**The damage rosters end clean and the territory rosters do not.** Vine+Thistle+Pruning and
Thistle+Vine+Root end with nothing alive and zero damage taken. Spore+Bloom+Root ends with
thirty-two enemies still standing, 22% of the board, and 1,309 damage taken; Bramble+Root+
Spore ends with nineteen alive. The §6 finding survives the move to three Adaptations and
the new Campaign: the territory rosters are not ahead on territory *at the end*, whatever
they hold at minute 10.

#### Provocation

Same roster (Thistle+Spore+Root), three policies:

| policy | finished | Blight | provocations | Growth | green @10 |
|---|---:|---:|---:|---:|---:|
| never | 20:00 | 0 | 0 | 0 | 90.1 |
| moderate | 16:00 | V | 19 | 5 | 3.7 |
| aggressive | 16:00 | V | 19 | 5 | 64.1 |

Three things, and two of them are problems.

**The runtime lands where it was designed to.** Aggressive finishes at 16:00 against the
rework's 15-to-17-minute target for aggressive play. The four-minute compression cap is
doing exactly its job.

**Moderate and aggressive have converged.** Both take nineteen Provocations, both reach
Blight V, both finish at 16:00 — because the compression cap binds long before the policies
diverge. The rework wants a spread (conservative 19-20, moderate 17-19, aggressive 15-17)
and there is currently no moderate band at all: any player who Provokes at all ends up at
the cap. Either the cap is the wrong shape or the availability rule is too permissive.

**Fourteen of nineteen Provocations buy nothing permanent.** Blight reaches V and Growth
reaches its five-rank cap by roughly minute 7. Every call after that is speed only. That is
what §23 specifies, but at this call rate it means the permanent half of the mechanic is
spent in the first third of the run and the remaining two thirds are a pure accelerator.

### 9.11 What the corrections do not settle

The rank-1 and rank-3 **pair sweeps have not been re-run** on the corrected instrument, so
the §3 table still stands as written and still carries all three defects. That is the next
measurement, and it should be run on both boards, because §9.2 means one board cannot
answer it.

Of the four early-Path changes made on 2026-09-19, Bramble's chip damage has now been
measured and reverted. The other three — Root's Cane floor, Spore's Seed threshold,
Bloom's interval — still rest on the biased reading, and Bramble's case is the reason to
distrust them: all three were made to answer a board that gives territory Adaptations
nothing to work with, and at least one of them turned out to be pushing the wrong axis.

### 9.12 The bench cannot measure whether moving pays

Added when the harvest was changed to cut the ground under the player
(`upkeep_inner_radius_pixels = 0`), which makes Pruning's output a function of how she
moves. Two instruments were added for it and one limit turned out to be structural.

`--walk-radius N` sets the radius of the bench's walk lap; `--walk` alone keeps the old
70px default. The default lap is *narrower than Pruning's own 52px harvest disc*, so it
re-treads ground it just cut: it measures a player who fidgets, not one who relocates.

`--ring` reports Pruning's hold instead of its damage — percent of the bench the ring was
up, percent with no Green underfoot, and how many times the ring tore loose. These are the
only columns that speak to the positional rule directly.

The limit: **`--siege` holds its population at the arena centre**, so every step away from
the fight costs contact for every build alike. Measured at rank 3 on the island board, the
cane-only baseline falls from 15,248 to 9,696 between a 0px and a 260px lap — it loses
36% purely to being measured further from its own targets. Any Adaptation measured while
walking is charged that same toll on top of its own positional cost, and nothing in the
bench ever pays movement back.

So the bench can report what movement *costs* and it cannot report what movement *buys*.
Rooted tops the isolated Pruning table at every walk radius, and that ordering is a
property of where the targets are pinned, not a finding about the path. Comparisons across
walk radii have to be read as each build's ratio over the cane baseline at that same radius,
never as absolute damage; and even then, a build whose whole argument is repositioning is
being asked to prove it in a room where repositioning is defined as losing.

The three ring columns are the reading that survives this, because they are about the ring
rather than about the fight: rooted spends 73.8% of the bench with no Green underfoot and
tears the ring 8 times in 40 seconds, against 45.8% and 5 tears at a 120px lap. That is the
mechanic working. Whether it is *enough* pressure is a question for a played run.

### 9.13 Pruning's two damage sources are not separable

The single most useful thing the bench has produced, and it invalidates how every Pruning
number in sections 7.3b and 9 was read.

Pruning deals damage two ways: the orbiting ring (`orbit_contact_damage`) and the launched
Cuttings (`cutting_damage`). Measured at rank 3 on the island siege board, against a
baseline of 48,791:

| zeroed | damage lost | damage taken |
|---|---|---|
| ring alone | 5,174 | 0 |
| Cuttings alone | 2,255 | 0 |
| **both together** | **23,556** | **369** |

Neither source matters on its own and both matter enormously together, because whichever
one is left takes over the kills. The board is a fixed population under a weapon that
massively overkills it, so removing capacity does not remove throughput until there is not
enough capacity left to clear the board at all.

This has a direct consequence for how any Pruning change must be measured: **a lever pulled
by itself will read as noise even when it is large.** Four consecutive nerfs -- halving ring
damage, raising the hit cooldown, halving Cutting yield, and dropping the ring's target cap
from eight to two -- each moved total damage by under 10% and left damage taken at zero.
Yesterday's spent-ground multiplier measured as nothing for the same reason.

The same non-additivity governs the defence, which is the more important half. Either
source alone is enough to hold damage taken at zero against sixty enemies. Pruning's
zero-damage-taken result is therefore not a property of the ring or of the Cuttings; it is
a property of having two independent always-on 360-degree damage sources, and it cannot be
tuned away by weakening one of them.

#### And the response to damage is a threshold, not a slope

Both sources cut together, isolated at rank 3:

| ring + Cutting damage | damage | x cane | taken |
|---|---|---|---|
| 26.0 (original) | 48,791 | 3.20x | 0 |
| 17.0 | 45,164 | 2.96x | 11 |
| 13.0 | 43,820 | 2.87x | 11 |
| 8.0 | 40,644 | 2.67x | 94 |
| 5.0 | 34,674 | 2.27x | 286 |
| 3.0 | 28,925 | 1.90x | 347 |
| 1.0 | 25,235 | 1.66x | 369 |

A 50% damage cut costs 10% of output. The next 60% cut costs another 34%. Everything above
about 8.0 is overkill against a Hunter, so the bench cannot distinguish "strong" from
"absurd" anywhere in the upper half of that table -- the only column that responds at all
is `taken`.

Tuning to where that column looks healthy would mean cutting damage by 80%, which is a
literal 80% against anything the volley does not already overkill: a boss, an Elite, the
Hive Queen. **The siege bench cannot price a weapon against a tough single target, and a
number chosen from it will be wrong for one.** Anything tuned here has to be confirmed on a
boss wave before it is believed.

#### Uptime, not damage

The ring was up 99.2% of the bench even while tearing eight times, because a torn ring
re-formed on the first frame of Green. Pruning's output is its coverage. Coverage is
cheaper to move than damage and it does not misprice the path against a boss, so it is the
lever to reach for first: `footing_recovery_rate`, the re-form rule, and how long a tear
actually costs.
