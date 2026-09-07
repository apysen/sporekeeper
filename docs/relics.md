# Sporekeeper Relics

## Relic pool structure

Each normal relic pool uses a standardized rarity distribution:

- **3 Common**
- **2 Uncommon**
- **2 Rare**
- **1 Legendary**

This gives each Adaptation **8 dedicated relics**.

Plant relics use the same 8-relic structure and act as cross-system glue. They should create new trigger relationships between movement, Green, enemies, relics, territory, and Adaptations rather than function as generic stat bonuses.


## Relic offering and rarity rules

### Eligibility

A relic offer can contain only:

- **Plant relics**
- relics belonging to Adaptations the player permanently owns

A newly acquired support Adaptation joins the eligible relic pool immediately.

Relics from unowned Adaptations are never offered.

Temporary ranks or effects granted by Clover jackpots do **not**:

- make an Adaptation count as owned,
- unlock that Adaptation's relic pool,
- satisfy ownership checks for relics.

Clover does **not** have a relic pool. Clover remains its own slot-machine system and should not add dedicated relics to normal relic rewards.

### Offer generation

For each relic slot in a reward offer:

1. Determine the player's currently eligible relic pools.
2. Roll rarity.
3. Select an unowned eligible relic of that rarity.
4. Prevent duplicate relics within the same offer.
5. If that rarity is exhausted, fall downward:
   - Legendary → Rare → Uncommon → Common
   - Rare → Uncommon → Common
   - Uncommon → Common
6. Never fall upward to a higher rarity.

Plant relics share the eligible pool naturally. They do not receive a guaranteed offer slot.

Unless a future relic is explicitly designed as stackable, relics are **one-copy-per-run**.

### Rarity odds by run progression

Legendary relics remain possible before Evolution, but deliberately rare. This avoids creating a hidden-feeling rule where players can play many hours and conclude that Legendaries are simply impossible early.

| Run state | Common | Uncommon | Rare | Legendary |
|---|---:|---:|---:|---:|
| **1 owned Adaptation** | **72%** | **24%** | **3%** | **1%** |
| **2 Adaptations, pre-Evolution** | **64%** | **27%** | **7.5%** | **1.5%** |
| **Post-Evolution** | **57%** | **28%** | **12%** | **3%** |
| **Support Adaptation / late run** | **50%** | **29%** | **17%** | **4%** |

These percentages are rolled **per offered relic slot**, not once for the entire reward screen.

With three offered relics, a 1.5% Legendary slot chance produces roughly a **4.4% chance** that a pre-Evolution offer contains at least one Legendary. It should therefore be possible and memorable without becoming expected.

### Campaign relic acquisition

Campaign authors **12 relic opportunities** in a completed run:

- one after every third wave: Waves **3, 6, 9, 12, 15, 18, 21, 24, 27, and 30**,
- one for defeating the run's Elite,
- one for defeating the Boss.

Each opportunity offers up to three distinct unowned eligible relics and the player
takes one. Campaign grants **2 relic-offer rerolls**, tracked separately from upgrade
rerolls. If another upgrade, Evolution, support, or relic choice already occupies the
choice panel, the reward is queued until that choice resolves.

If every eligible relic is already owned, the opportunity pays **24 Biomass** instead
(`8 base Biomass × 3`). Therefore 12 is the authored opportunity count; the number of
relics actually acquired can be lower if the eligible pool is exhausted. Relics do
not count as Adaptation upgrades or Evolution ranks.

Quick mode uses the same every-third-wave rule across its 12 waves, plus its Elite
and Boss, for **6 authored relic opportunities**: Waves 3, 6, 9, and 12, then one
opportunity from each milestone enemy.

### Generated-event ownership rule

Relic-generated attacks and echoes should be tagged as generated events.

Unless a relic explicitly says otherwise:

- generated events may benefit from stats belonging to an Adaptation the player permanently owns,
- generated events may activate generic relic interactions,
- generated events do not create ownership,
- generated events do not unlock an unowned Adaptation's relic pool,
- generated events do not count as natural events for counters that explicitly require natural events.

---

## Numeric implementation standard

Every relic in the current 72-relic catalog is implemented. Numeric sections marked
**Current implementation** describe the live authored values and should be preserved
unless playtesting specifically justifies changing them.

For all future relics added to this document, specify at minimum when relevant:

- trigger threshold or proc chance,
- radius or targeting range,
- delay, duration, cooldown, and cadence,
- damage, Force, conversion, Growth Mass, or other strength multiplier,
- enemy-count requirement,
- elite and boss scaling,
- active-object and target caps,
- recursion and generated-event rules.

Generated effects should be tagged by source so relic recursion can be controlled without special-case guessing.

---

# Plant Relics

Plant relics are shared by all Plant builds. Their purpose is to connect systems that would otherwise operate separately.

## Common

### Garden Hose

**Player-facing description:** Travel far enough across your Green to spray a fan of fresh Green ahead of Grandma.

**Trigger:** Grandma travels across owned Green.

Traveling far enough across Green automatically sprays a fan of Green ahead of Grandma.

#### Current implementation

- Required movement on owned Green: **240 px**
- Movement counter pauses while Grandma is off Green and resumes when she returns.
- Teleports, knockback, forced movement, and position corrections do **not** add distance.
- Spray arc: **90 degrees**
- Spray range: **145 px**
- Spray projectiles: **5**
- Projectile angles relative to facing: **-40°, -20°, 0°, +20°, +40°**
- Each projectile deposits **0.11× baseline Seed Growth Mass**
- Total possible payload per spray: **0.55× baseline Seed Growth Mass**
- Deposit radius per projectile: **34 px**
- Projectile travel time to maximum range: **0.30s**
- Minimum internal cooldown after a spray: **0.35s**
- Spray creates Fresh Green only. It does not grant maturity.
- Invalid or basalt landing points contribute no territory.

#### Implementation notes

- Reset the 240 px movement counter only when the spray actually fires.
- The relic should use Grandma's current movement direction when the threshold is crossed.
- Garden Hose effects may trigger general territory-created systems, but do not count as Seed germination.

---

### Mulch

**Player-facing description:** Enemies that eat your Green store what they consume. Kill them to burst that stolen growth back around their corpse.

**Trigger:** An enemy that has consumed Green is killed.

Enemies remember part of the Green they personally destroy. Killing them releases that stored value around the corpse.

#### Current implementation

- Store **40%** of the Green Growth Mass or control-equivalent personally erased by that enemy.
- Stored amount persists until the enemy dies.
- Maximum stored amount per enemy: **0.60× baseline Seed Growth Mass**
- Minimum stored amount required to erupt: **0.15× baseline Seed Growth Mass**
- Death eruption radius: **95 px**
- Restore **100% of the stored Mulch reserve** on death.
- Restored territory is Fresh Green.
- Mulch deals **0 damage**.
- If the corpse is on invalid terrain, search for the nearest valid point within **48 px**.
- One enemy can release Mulch only once.

#### Implementation notes

- Track only Green that the enemy itself removes.
- Do not count Green lost through Pruning or other player-authored sacrifice mechanics.
- Stored Mulch should be visible on heavily fed enemies so the player can recognize high-value fertilizer targets.

---

### Mimosa

**Player-facing description:** Taking damage on Green makes the plants snap shut, blasting nearby enemies away.

**Trigger:** Grandma takes HP damage while standing on owned Green.

The Green beneath Grandma snaps shut and blasts nearby enemies away.

#### Current implementation

- Trigger radius: **120 px**
- Knockback strength: **0.55× rank-0 Bloom Force**
- Damage: **0**
- Territory conversion: **0**
- Cooldown: **5.0s**
- Normal enemy knockback: **100%**
- Elite knockback multiplier: **60%**
- Boss knockback multiplier: **25%**
- Trigger checks Grandma's territory state at the exact moment HP damage resolves.
- Damage fully prevented by another effect does **not** trigger Mimosa.

#### Implementation notes

- Mimosa is crowd control, not damage mitigation.
- Mimosa may trigger only once per incoming hit, including multihit attacks resolved on the same frame.

---

## Uncommon

### Compost Heap

**Player-facing description:** Enemies that die on Green build compost piles. Feed a pile enough corpses and it erupts, damaging enemies and growing Mature Green.

**Trigger:** Enemies die on Green.

Deaths on Green build visible compost piles. Enough corpse value causes the pile to erupt into damage and highly developed Green.

#### Current implementation

- Normal enemy death: **+1 Compost**
- Elite death: **+2 Compost**
- Boss death: **+5 Compost**
- Existing heap merge radius: **110 px**
- Eruption threshold: **6 Compost**
- Heap lifetime without a new contribution: **18s**
- Each contribution refreshes the lifetime to **18s**
- Delay after reaching threshold: **0.45s**
- Eruption damage: **36**
- Damage radius: **105 px**
- Territory radius: **90 px**
- Territory payload: **0.75× baseline Seed Growth Mass**
- Inner **55 px** of newly created owned Green is immediately set to **Mature**
- Outer Green follows normal maturity rules.
- Maximum active heaps: **8**
- A heap that reaches threshold stops accepting new Compost until after it erupts.

#### Implementation notes

- Prefer contributing to an existing nearby heap before spawning a new one.
- Compost Heap kills may trigger ordinary kill-based relics.
- The eruption itself cannot create another Compost contribution unless it kills a separate enemy that was already validly standing on Green.

---

### Man-Eater

**Player-facing description:** Enemies that graze on Green too long become marked. Kill one to sprout a carnivorous plant that bites nearby enemies.

**Trigger:** An enemy spends enough time actively consuming Green, becomes marked, and is later killed.

A marked enemy's corpse erupts into a temporary carnivorous plant that bites nearby enemies once.

#### Current implementation

- Required cumulative active Green-consumption time: **2.25s**
- Consumption time does not need to be continuous.
- Once marked, the mark lasts until death.
- Corpse-to-eruption delay: **0.30s**
- Maw lifetime: **1.20s**
- Bite occurs **0.25s** after eruption.
- Bite radius: **115 px**
- Maximum bite targets: **6**
- Base bite damage: **80**
- Elite damage multiplier: **50%**
- Boss damage multiplier: **25%**
- Pull toward Maw center before damage: **28 px**
- Global Man-Eater eruption cooldown: **0.75s**
- If multiple marked enemies die during cooldown, queue at most **1** additional eruption. Extra deaths during a full queue do not create Maws.

#### Implementation notes

- The mark should be visually obvious.
- Man-Eater damage counts as relic damage and may activate general kill-trigger relics.
- A Man-Eater eruption cannot directly mark enemies. Marking still requires actual Green consumption.

---

## Rare

### Grafting Tape

**Player-facing description:** Every 18s, an action from one primary Adaptation makes the other answer with its core event at 75% strength.

**Trigger:** Either of the two primary Adaptations performs a natural core event while Grafting Tape is ready.

The other primary Adaptation immediately performs one reduced core event.

#### Current implementation

- Global cooldown: **18s**
- Echo delay after the source event: **0.25s**
- Echo strength: **75%**
- Only the two primary pre-Evolution Adaptations are linked. The support Adaptation is not part of Grafting Tape.
- The echoed event costs no additional resource.
- Cooldown begins when the echoed event fires.
- If the echoed event has no legal target or placement, retry once after **0.50s**.
- If the retry also fails, consume only **9s** of cooldown instead of 18s.

#### Core-event mapping

Use these event definitions unless an Adaptation's final implementation explicitly overrides them:

- **Spore:** one Seed germination
- **Bloom:** one Bloom detonation
- **Bramble:** one Grasping Thorns activation
- **Root:** one eligible Root Network pulse or authored Root core event
- **Pruning:** one released Pruning ring
- **Thistle:** one Thistle network firing cycle
- **Vine:** one completed Vine sweep
- **Fruit:** one Fruit launch

#### Recursion rules

- Grafting Tape echoes can trigger other relics.
- Grafting Tape echoes cannot trigger Grafting Tape.
- Relic-generated echoes do not count as natural core events for Grafting Tape.

---

### Miracle-Gro

**Player-facing description:** Create enough new Green to prime your next eligible Adaptation event to repeat at 60% strength.

**Trigger:** Enough new owned Green is created.

Creating enough new Green primes the next eligible Adaptation event to repeat at reduced strength.

#### Current implementation

- Green creation required per charge: **2.5× baseline Seed Growth Mass**
- Count only newly created owned Green, not control recovery on already-owned Green.
- Maximum stored charges: **1**
- Green created while a charge is already stored does not build a second charge.
- Repeat delay: **0.35s**
- Repeat strength: **60%**
- The first eligible natural or Evolution Adaptation event consumes the charge.
- Charge has no expiration timer.

#### Strength rules

For scalable events, multiply authored offensive or territorial output by **0.60**, including damage, Force, conversion, Growth Mass, effect duration, and integer projectile/object counts where appropriate.

For integer counts:

`max(1, floor(original_count × 0.60))`

#### Recursion rules

- Miracle-Gro repeats can trigger other relics.
- Green created by Miracle-Gro's repeated event does **not** contribute toward charging Miracle-Gro.
- Miracle-Gro cannot repeat its own repeated event.
- Relic-generated territory already excluded from ordinary territory-created triggers remains excluded here.


---

## Legendary

### Hybrid Vigor

**Player-facing description:** Triggered relic effects have a 20% chance to repeat once at 60% strength.

**Trigger:** Another triggered relic effect activates.

Triggered relic effects have a chance to repeat once at reduced strength.

#### Current implementation

- Repeat chance per eligible relic activation: **20%**
- Repeat delay: **0.20s**
- Repeat strength: **60%**
- Maximum Hybrid Vigor repeats in any rolling **1.0s** window: **4**

#### Eligibility

Eligible:
- discrete triggered Common, Uncommon, Rare, and Legendary relic effects,
- damage bursts,
- spawned temporary attacks,
- territory pulses,
- forced Adaptation events.

Not eligible:
- passive always-on modifiers,
- rarity-roll modifiers,
- Hybrid Vigor itself,
- an effect already repeated by Hybrid Vigor.

#### Recursion rules

- A Hybrid Vigor repeat cannot roll Hybrid Vigor again.
- The repeated effect may activate other unrelated relics normally.
- Unique permanent objects cannot be permanently duplicated. If an effect would create one, create a temporary **60%-duration echo** instead.

---

# Spore Relics

Spore relics focus on Seeds creating more Seeds, failed Seeds remaining useful, and germination cascading into further germination.

## Shared Spore event definitions

For relic counters:

- A **natural germination** is any Seed whose germination progress reaches 100% normally, even if Green Thumb, Cross-Pollination, or another accelerator helped it reach 100%.
- A Seed created by Puffball, Windborne, or Volunteer can still naturally germinate.
- An **instant forced germination** from Domino Germination does not count toward Domino Germination's own natural-germination counter.
- Domino-forced germinations still count as germinations for Spore Burst, Cross-Pollination, and Windborne unless explicitly excluded.

## Common

### Hard Husk

**Player-facing description:** Each Seed ignores the first interruption that would destroy it.

Each Seed ignores the first interruption that would break or destroy it.

#### Current implementation

- Protection charges per Seed: **1**
- A qualifying interruption consumes the charge instead of breaking the Seed.
- After the charge is spent, the Seed behaves normally.
- The charge applies independently to every Seed.

#### Implementation notes

- Puffball should trigger only if a Seed is actually destroyed. Consuming Hard Husk does not count as destruction.

---

### Green Thumb

**Player-facing description:** Pass close to a Seed to instantly advance its germination by 35%. Once per Seed.

**Trigger:** Grandma passes near a Seed.

The first close pass advances that Seed's germination.

#### Current implementation

- Trigger radius: **46 px**
- Germination progress granted: **35 percentage points**
- Uses: **1 per Seed**
- No global cooldown.
- Each Seed tracks its own Green Thumb use.

#### Implementation notes

- Applies to baseline, Puffball, Windborne, and Volunteer Seeds.
- Crossing the radius multiple times does not grant additional progress to the same Seed.

---

### Puffball

**Player-facing description:** Destroyed Seeds burst into 3 fast-germinating Seedlings that create smaller patches of Green.

**Trigger:** A Seed is destroyed before germinating.

The Seed bursts into three smaller Seedlings that scatter nearby.

#### Current implementation

- Seedlings spawned: **3**
- Scatter distance: random **80 to 130 px**
- Minimum angular separation between Seedlings: **70 degrees**
- Airborne scatter duration: random **0.35 to 0.55s**
- Seedling germination-time multiplier: **0.625× baseline time**
- Equivalent germination speed: **1.60× baseline**
- Seedling Growth Mass: **45% of a normal Seed**
- Seedling interruption protection: **0 extra charges**
- Seedlings use normal Seed targeting and collision after landing.
- Maximum Puffball generations: **1**

#### Recursion rules

- Puffball Seedlings can trigger Green Thumb, Spore Burst, Cross-Pollination, Windborne, Volunteer interactions, and Domino Germination if they naturally germinate.
- Puffball Seedlings can **never trigger Puffball** when destroyed.

---

## Uncommon

### Spore Burst

**Player-facing description:** Every Seed germination erupts for 24 damage in an 84 px radius, scaling with Growth Mass.

**Trigger:** A Seed germinates.

Every germination causes a damaging fungal burst.

#### Current implementation

At **Growth Mass 1.0**:

- Damage: **24**
- Radius: **84 px**
- Damage scales with the Seed germination's Growth Mass.
- Burst occurs immediately at germination.

#### Implementation notes

- Applies to natural and forced germinations.
- Domino Germination can therefore create multiple sequential Spore Bursts.
- Spore Burst damage does not itself count as Seed damage for Seed-generation rules unless those rules explicitly use generic kills.

---

### Cross-Pollination

**Player-facing description:** Germinating a Seed advances nearby Seeds by 25%.

**Trigger:** A Seed germinates near other active Seeds.

Nearby Seeds gain germination progress.

#### Current implementation

- Germination progress granted: **25 percentage points**
- Radius: **165 px**
- Receiving cooldown per Seed: **0.85s**
- No fixed sender target cap beyond the radius check.
- A Seed on receiving cooldown ignores additional Cross-Pollination progress until the cooldown expires.

#### Implementation notes

- Applies to natural and forced germinations.
- Cross-Pollination may cause another Seed to naturally reach 100%. That resulting germination is a normal germination event.
- The 0.85s receiver cooldown is the primary anti-chain-rate limiter.

---

## Rare

### Windborne

**Player-facing description:** Every 5 germinations launches 3 Seeds toward distant non-Green ground.

**Trigger:** Every fifth germination.

A group of Seeds is launched toward distant non-Green territory.

#### Current implementation

- Trigger threshold: **5 germinations**
- Seeds launched per trigger: **3**
- Target distance from the triggering germination: **260 to 420 px**
- Preferred target: valid non-Green ground
- Landing separation between Windborne Seeds: at least **70 px**
- Flight duration: **0.70s**
- Windborne Seeds use **100% normal Seed germination time**
- Windborne Seeds use **100% normal Seed Growth Mass**
- Maximum active Windborne-created Seeds: **12**
- Counter carries excess progress normally.

#### Counter rules

These germinations **do** advance Windborne:
- baseline Seeds,
- Puffball Seedlings,
- Windborne Seeds,
- Volunteer Seeds,
- Domino-forced germinations.

Windborne does not trigger directly from a Seed merely being spawned.

#### Recursion note

Because Windborne creates 3 Seeds per 5 germinations, Windborne-only reproduction is subcritical. Its own Seeds may contribute toward later Windborne triggers.

---

### Volunteer

**Player-facing description:** Enemies killed on freshly germinated Seed Green have a 30% chance to plant a new Seed.

**Trigger:** An enemy dies on Green created by a recent Seed germination.

The death may plant a new Seed at the corpse.

#### Current implementation

- Recent Seed-Green eligibility window: **4.0s** after germination
- Proc chance per qualifying enemy death: **30%**
- Global Volunteer proc cooldown: **0.50s**
- Seeds created per proc: **1**
- Volunteer Seed germination time: **100% baseline**
- Volunteer Seed Growth Mass: **100% baseline**
- Maximum active Volunteer-created Seeds: **6**
- Spawn delay after enemy death: **0.20s**
- Spawn position: corpse location, moved to nearest valid ground within **40 px** if necessary

#### Recursion rules

- Green created by a Volunteer Seed is eligible to create more Volunteer Seeds during its own 4.0s recent-Green window.
- The 30% proc chance, 0.50s global cooldown, and 6-active-Seed cap are the recursion controls.
- One enemy death can create at most one Volunteer Seed.

---

## Legendary

### Domino Germination

**Player-facing description:** Every 10 natural germinations instantly germinates up to 6 other active Seeds in a cascade.

**Trigger:** Every tenth natural Seed germination.

Up to six active Seeds germinate one after another in a visible cascade.

#### Current implementation

- Natural germinations required: **10**
- Maximum Seeds forced per cascade: **6**
- Time between forced germinations: **0.16s**
- Maximum cascade duration with 6 Seeds: **0.80s**
- Seed selection priority: highest current germination progress first
- Tie-breaker: oldest active Seed first
- Only one cascade may execute at a time.
- At most **1 additional cascade** may be queued while one is active.

#### Forced-germination rules

Domino-forced germinations:
- trigger Spore Burst,
- trigger Cross-Pollination,
- advance Windborne,
- can create recent Seed-Green for Volunteer,
- activate other mechanics that explicitly care about germination,
- do **not** advance Domino Germination's own 10-germination counter.

Natural germinations that occur while a cascade is playing still advance the next Domino counter.

---

# Bloom Relics

Bloom relics treat Bloom's high lethality as the starting point. The pool focuses on converting kills and Bloom events into more effects rather than relying on enemies surviving the initial blast.

## Bloom baseline reference

Current authored Bloom behavior:

- First Bloom delay: **4.0s**
- Repeat cadence in the playable scene: **15.0s**
- Wind-up: **0.65s**
- Base center damage: **40**
- Physical droplets per normal Bloom: **6**

Unless a relic says otherwise, Bloom relic multipliers apply to the current stat-scaled Bloom event rather than replacing Bloom Force, Root Network, or other existing amplification.

## Bloom generated-event tags

Use source tags to prevent accidental recursion:

- `BLOOM_NATURAL`
- `BLOOM_EVOLUTION`
- `BLOOM_DEADHEADING`
- `BLOOM_CHAIN`
- `BLOOM_OVERKILL_ECHO`
- `BLOOM_SUPERBLOOM`
- `BLOOM_PERENNIAL`
- `BLOOM_FLOWERING_FRONT`

### Global Bloom relic safety caps

- Maximum relic-generated Bloom buds simultaneously active: **8**
- Maximum Bloom detonations resolved in one rendered frame: **4**
- Additional same-frame generated detonations are delayed in **0.05s** increments instead of being dropped.

These caps are implementation safeguards, not intended player-facing limits.

## Common

### Late Bloomer

**Player-facing description:** Blooms take 70% longer to charge, building up to 65% more Force and conversion.

Bloom charges longer but gains substantially more power during the extended wind-up.

#### Current implementation

- Wind-up multiplier: **1.70×**
- Base 0.65s wind-up becomes **1.105s**
- Maximum additional Force: **+65%**
- Maximum additional conversion: **+65%**
- Bonus ramps linearly from 0% to 65% over the full wind-up.
- Bloom cadence is unchanged.

#### Implementation notes

- Do not apply an extra standalone +65% damage multiplier if the existing Bloom Force pipeline already converts Force into damage.
- Preserve the current authored Bloom Force and conversion calculation order.

---

### Deadheading

**Player-facing description:** A Bloom destroyed during wind-up still detonates at half strength.

**Trigger:** A Bloom bud is destroyed or hostilely interrupted during wind-up.

The failed bud immediately releases a smaller emergency Bloom.

#### Current implementation

- Emergency detonation delay: **0.05s**
- Damage multiplier: **0.50×**
- Force multiplier: **0.50×**
- Conversion multiplier: **0.50×**
- Radius multiplier: **0.80×**
- Droplets: **3**
- Droplet payload: **0.50× normal**
- One Deadheading detonation maximum per destroyed bud.

#### Trigger rules

Valid:
- hostile destruction,
- Saboteur interruption,
- enemy suppression effect that explicitly cancels the Bloom.

Invalid:
- wave ending,
- run ending,
- invalid placement cleanup,
- player-authored cancellation.

#### Recursion rules

- Deadheading can trigger Petal Scatter, Superbloom, and Overkill.
- Deadheading may qualify as the parent for Chain Bloom.
- Deadheading cannot start Flowering Front.
- Deadheading does not count as the first natural Bloom for Perennial.

---

### Petal Scatter

**Player-facing description:** Enemies killed by a Bloom fling petals toward enemies outside the blast, dealing 45% of the Bloom's center damage.

**Trigger:** A Bloom kills an enemy.

Each qualifying kill can fling one damaging petal toward an enemy outside the original Bloom radius.

#### Current implementation

- Petals created per Bloom kill: **1**
- Maximum petals per Bloom event: **6**
- Target must be outside the source Bloom's damage radius at the moment targets are selected.
- Maximum acquisition range from the dead enemy: **240 px**
- Petal travel speed: **520 px/s**
- Petal hit radius: **12 px**
- Petal lifetime: **0.70s**
- Damage: **45% of the source Bloom's final center damage**
- Knockback: **0**
- Territory conversion: **0**
- Pierce: **0**
- If no valid outside target exists, that petal is not spawned.

#### Recursion rules

- Petal Scatter kills can activate general kill relics.
- Petal Scatter damage is not tagged as Bloom detonation damage.
- A Petal Scatter kill cannot create another Petal Scatter petal.

---

## Uncommon

### Chain Bloom

**Player-facing description:** A Bloom that kills at least 4 enemies plants a smaller 55%-strength Child Bloom beyond the blast.

**Trigger:** One qualifying Bloom kills at least four enemies.

A smaller Child Bloom is planted near the edge of the first blast toward enemies the first Bloom missed.

#### Current implementation

- Kill requirement: **4 enemies**
- Child Blooms per qualifying parent: **1**
- Child wind-up: **0.45s**
- Child damage multiplier: **0.55×**
- Child Force multiplier: **0.55×**
- Child conversion multiplier: **0.55×**
- Child radius multiplier: **0.75×**
- Child droplets: **3**
- Child droplet payload: **0.55×**
- Preferred placement: qualifying slain-enemy position nearest the densest enemy cluster outside the parent Bloom radius
- Search range for the outside cluster: **280 px**

#### Eligible parent tags

Eligible:
- `BLOOM_NATURAL`
- `BLOOM_EVOLUTION`
- `BLOOM_DEADHEADING`
- `BLOOM_PERENNIAL`
- `BLOOM_FLOWERING_FRONT`

Not eligible:
- `BLOOM_CHAIN`
- `BLOOM_OVERKILL_ECHO`
- `BLOOM_SUPERBLOOM`

#### Recursion rules

- A Chain Bloom cannot create another Chain Bloom.
- Chain Bloom can trigger Petal Scatter, Superbloom, and contribute to Overkill.
- Chain Bloom cannot begin or advance Flowering Front.

---

### Overkill

**Player-facing description:** Store 200 excess Bloom damage to make your next natural Bloom echo once at 45% strength.

**Trigger:** Bloom damage exceeds the HP an enemy had immediately before the hit.

Excess Bloom damage fills an Overkill meter. A full meter causes the next qualifying Bloom to detonate a second time.

#### Current implementation

- Overkill damage required: **200**
- Excess contribution per normal enemy: capped at **60**
- Excess contribution per elite: capped at **60**
- Excess contribution per boss: capped at **20**
- Maximum stored charges: **1**
- Overkill gained while a charge is already stored is ignored.
- Echo delay after the next qualifying Bloom: **0.40s**
- Echo damage multiplier: **0.45×**
- Echo Force multiplier: **0.45×**
- Echo conversion multiplier: **0.45×**
- Echo radius: **1.00× source Bloom radius**
- Echo Plant Mass: **0**
- Echo droplets: **0**

#### Qualifying Bloom for consuming the charge

- `BLOOM_NATURAL`
- `BLOOM_EVOLUTION`

#### Counter rules

Overkill can be accumulated by:
- Natural Blooms
- Evolution Blooms
- Deadheading
- Chain Bloom
- Perennial
- Flowering Front

Overkill cannot be accumulated by:
- Overkill Echo
- Superbloom secondary waves

#### Recursion rules

- Overkill Echo can trigger Petal Scatter and Superbloom.
- Overkill Echo cannot trigger Chain Bloom, Flowering Front, or another Overkill Echo.

---

## Rare

### Superbloom

**Player-facing description:** Two Blooms close together create a 55%-strength secondary wave. 5s cooldown.

Two Blooms occurring close together create an additional secondary pressure wave.

#### Current implementation

- Maximum center separation: **150 px**
- Bloom-event memory window: **1.20s**
- Secondary wave strength: **0.55× Force**
- Global cooldown: **5.0s**

#### Implementation target for explicit generated-wave behavior

- Secondary wave position: midpoint between the two qualifying Bloom centers
- Secondary damage multiplier: **0.55×** the newer Bloom's final center damage
- Secondary conversion multiplier: **0.55×** the newer Bloom's conversion
- Secondary radius: **0.85×** the newer Bloom's radius
- Plant Mass: **0**
- Droplets: **0**

#### Eligibility

All actual Bloom detonations can participate in the overlap check except `BLOOM_SUPERBLOOM` itself.

#### Recursion rules

- Superbloom can trigger Petal Scatter if its secondary wave kills enemies.
- Superbloom cannot trigger another Superbloom directly.
- Superbloom does not count toward Chain Bloom or Flowering Front.
- Superbloom does not contribute to Overkill.

---

### Perennial

**Player-facing description:** The first natural Bloom each wave re-blooms twice, 7s apart, at 60% strength.

The first successful natural Bloom each wave blooms twice more from the same location.

#### Current implementation

- Tracked Blooms per wave: **1**
- Re-blooms: **2**
- Time between re-blooms: **7.0s**
- First re-bloom: **7.0s** after the original
- Second re-bloom: **14.0s** after the original
- Re-bloom strength: **0.60× Force**

#### Explicit implementation target

- Damage multiplier: **0.60×**
- Conversion multiplier: **0.60×**
- Radius multiplier: **1.00×**
- Plant Mass: **0**
- Droplets: **0**
- Re-blooms occur at the original world position even if territory ownership there changes.
- Remaining scheduled re-blooms are canceled when the wave ends.

#### Recursion rules

- Perennial can trigger Petal Scatter, Chain Bloom, Superbloom, and contribute to Overkill.
- Perennial cannot start Flowering Front.
- Perennial does not count as a natural Bloom for another Perennial.

---

## Legendary

### Flowering Front

**Player-facing description:** A natural Bloom that kills 5 enemies starts a chain of up to 4 Child Blooms flowering forward through the enemy wave.

**Trigger:** A qualifying Bloom kills a large enemy group.

A Child Bloom appears beyond the original blast toward the next enemy concentration. Successful Child Blooms continue flowering across the battlefield.

#### Current implementation

##### Starting a chain

- Eligible starters: `BLOOM_NATURAL` and `BLOOM_EVOLUTION`
- Starter kill requirement: **5 enemies**
- Maximum active Flowering Front chains: **1**
- New chain cooldown after the previous chain ends: **8.0s**

##### Child placement

- Search for the densest valid enemy cluster outside the parent Bloom radius.
- Search range beyond the parent: **320 px**
- Preferred child-center distance from parent center: **1.05× parent radius**
- Clamp center-to-center distance to **110 to 220 px**
- If no valid hostile-side placement exists, terminate the chain.

##### Child behavior

- Wind-up: **0.50s**
- Generation 1 strength: **0.75× parent**
- Each later generation multiplies the previous generation's strength by **0.75×**
- Radius multiplier per child relative to its parent: **0.90×**
- Droplets per child: **4**
- Droplet payload uses the same strength multiplier as the child.
- Child Blooms use the current source Bloom's damage, Force, and conversion as their starting values before the generation multiplier.

##### Propagation

- Generation 1 child kill requirement to continue: **3 enemies**
- Generation 2 child kill requirement: **3 enemies**
- Generation 3 child kill requirement: **3 enemies**
- Generation 4 is the final child and cannot continue.
- Maximum Child Bloom generations: **4**

Approximate strength relative to the original starter:

- Generation 1: **75.0%**
- Generation 2: **56.25%**
- Generation 3: **42.19%**
- Generation 4: **31.64%**

#### Recursion rules

Flowering Front children:
- can trigger Petal Scatter,
- can trigger Superbloom,
- can contribute to Overkill,
- can qualify as a parent for Chain Bloom.

Flowering Front children:
- cannot start a second Flowering Front chain,
- cannot exceed the 4-generation cap.

Chain Blooms created from a Flowering Front child do not advance the Flowering Front chain.

---


# Bramble Relics

Bramble relics focus on converting Entanglement, Repulsion, roots, and dense enemy pressure into chained crowd-control events. The goal is not to turn Bramble into a raw damage Path, but to let crowd control itself create more crowd control.

## Bramble baseline reference

Current authored Bramble behavior includes:

- Base slow at any Entanglement: **10%**
- Full-Entanglement root duration: **0.35s**
- Base Repulsion distance: **26 px**
- Thorn contact damage interval: **0.45s**
- Thorn contact damage ramps up to **3.0×** at full Entanglement

Unless a relic says otherwise, Bramble relics use the enemy's actual current Entanglement value after normal upgrade and resistance calculations.

## Common

### Hookthorn

**Player-facing description:** Repel an enemy into another enemy to tangle both of them.

**Trigger:** Bramble Repulsion knocks an enemy into another enemy.

Both enemies gain additional Entanglement.

#### Current implementation

- Post-Repulsion collision window: **0.40s**
- Enemy-to-enemy collision distance: **30 px**
- Entanglement applied to the repelled enemy: **+15 percentage points**
- Entanglement applied to the struck enemy: **+20 percentage points**
- Maximum Hookthorn activations per Repulsion event: **1**
- Per-enemy Hookthorn cooldown: **0.75s**
- Elite Entanglement multiplier: **75%**
- Boss Entanglement multiplier: **40%**

#### Implementation notes

- Only displacement caused by Bramble Repulsion can qualify.
- Contact caused by ordinary movement or unrelated knockback does not qualify.
- Apply the target's elite or boss Entanglement multiplier after the flat percentage-point value is determined.
- Hookthorn may push either enemy to full Entanglement and therefore trigger normal Grasping Thorns behavior.
- Hookthorn cannot recursively retrigger from the same Repulsion event.

---

### Thornback

**Player-facing description:** Whenever Bramble Repulsion fires, the damaged Green shoots a thorn at another nearby enemy.

**Trigger:** An enemy damages Green strongly enough to trigger Bramble Repulsion.

A thorn launches from the damaged Green toward another nearby enemy.

#### Current implementation

- Thorns created per qualifying Repulsion: **1**
- Target acquisition range: **180 px**
- Target priority: valid enemy with the **lowest current Entanglement**
- Thorn damage: **14**
- Entanglement applied: **+12 percentage points**
- Projectile speed: **520 px/s**
- Projectile hit radius: **10 px**
- Projectile lifetime: **0.55s**
- Pierce: **0**
- Per-source-enemy cooldown: **1.25s**
- If another valid enemy exists, the triggering enemy cannot be selected.
- If no other valid target exists, the triggering enemy may be selected.

#### Implementation notes

- Thornback damage counts as relic damage.
- Thornback Entanglement can trigger normal full-Entanglement behavior.
- One enemy damaging multiple Green samples on the same frame can produce at most one Thornback projectile.

---

### Cocklebur

**Player-facing description:** Enemies leaving Green at 50% or more Entanglement carry burrs for 3s, tangling enemies they touch.

**Trigger:** An enemy leaves owned Green while significantly Entangled.

The enemy carries burrs with it and can spread Entanglement by touching other enemies.

#### Current implementation

- Minimum Entanglement required when leaving Green: **50%**
- Burr duration: **3.0s**
- Entanglement applied on contact: **+10 percentage points**
- Same-target contact cooldown: **0.75s**
- Maximum unique targets affected per Burr carrier: **4**
- Elite Entanglement multiplier: **75%**
- Boss Entanglement multiplier: **40%**
- Burr carrier retains normal Entanglement decay.
- Burr carrier does **not** create Green or Bramble territory beneath itself.

#### Implementation notes

- Burr is applied at the Green-to-non-Green boundary crossing.
- Re-entering Green does not remove Burr early.
- Leaving Green again while already carrying Burr does not refresh the timer.
- Cocklebur-applied Entanglement can trigger normal Grasping Thorns behavior.
- A Cocklebur carrier cannot spread Burr status itself. It spreads only Entanglement.

---

## Uncommon

### Snare Vine

**Player-facing description:** Ensnaring an enemy spreads 20% Entanglement to up to 2 nearby enemies.

**Trigger:** An enemy becomes Rooted from reaching full Entanglement.

Nearby enemies gain Entanglement.

#### Current implementation

- Entanglement applied: **+20 percentage points**
- Maximum targets: **2**
- Radius: **96 px**

#### Implementation notes

- Select the two nearest valid enemies within 96 px.
- Do not target the rooted source enemy.
- Apply normal elite and boss Entanglement resistance after the 20-point value is determined.
- Snare Vine-applied Entanglement may push another enemy to full Entanglement and trigger its normal root.
- A root caused by Snare Vine's spread may itself trigger Snare Vine if it is a genuinely new full-Entanglement root event.
- Existing Bramble anti-loop and root-immunity rules still apply.

---

### Briar Knot

**Player-facing description:** Enemies that die at 90% or more Entanglement leave a one-use knot that yanks and heavily tangles the next enemy nearby.

**Trigger:** An enemy dies while heavily Entangled.

Its remains become a temporary trap that snares the next enemy that approaches.

#### Current implementation

- Required Entanglement at death: **90%**
- Knot lifetime: **7.0s**
- Trigger radius: **72 px**
- Trigger delay after entry: **0.15s**
- Pull distance toward Knot center: **42 px**
- Normal-enemy Entanglement applied: **+40 percentage points**
- Normal-enemy forced root duration: **0.40s**
- Elite Entanglement applied: **+25 percentage points**
- Elite forced root duration: **0.20s**
- Boss Entanglement applied: **+15 percentage points**
- Boss forced root duration: **0s**
- Maximum active Briar Knots: **6**
- Uses per Knot: **1**

#### Implementation notes

- Spawn the Knot at the corpse location, moved to the nearest valid ground point within **32 px** if necessary.
- If the active-Knot cap is reached, replace the oldest Knot.
- A triggered Knot disappears immediately after resolving its pull and Entanglement.
- Briar Knot Entanglement can trigger normal Grasping Thorns behavior.
- Briar Knot kills nothing directly and therefore cannot create another Briar Knot by itself.

---

## Rare

### Living Rampart

**Player-facing description:** Pack 6 enemies into a 150 px Green patch to accelerate Ensnare and Repulsion.

Dense enemy groups standing in Green cause local Bramble behavior to accelerate sharply.

#### Current implementation

- Enemy requirement: **6**
- Density radius: **150 px**
- Entanglement Rate multiplier: **1.20×**
- Repulsion interval multiplier: **0.55×**
- Linger duration after density condition is lost: **1.5s**

#### Implementation notes

- Evaluate density around the affected Green region, not globally across the map.
- The effect remains active for 1.5s after the local enemy count falls below 6.
- Re-entering the density condition refreshes the linger timer.
- Living Rampart modifies Bramble's existing Ensnare and Repulsion cadence. It does not create separate relic-only roots or pushes.

---

### Briarball

**Player-facing description:** Every 4 heavily Entangled deaths creates a rolling Briarball that damages, repels, and tangles up to 8 enemies.

**Trigger:** Enough heavily Entangled enemies die.

Their accumulated thorns combine into a rolling Briarball that crashes through enemies.

#### Current implementation

- Qualifying deaths required: **4**
- Required Entanglement at death: **90%**
- Counter carries between qualifying deaths until it reaches 4.
- Spawn location: fourth qualifying corpse
- Briarball lifetime: **4.5s**
- Initial movement speed: **240 px/s**
- Target search range: **420 px**
- Preferred target: densest valid enemy cluster
- Contact radius: **26 px**
- Contact damage: **24**
- Entanglement per hit: **+30 percentage points**
- Repulsion distance per hit: **40 px**
- Maximum unique enemies hit per Briarball: **8**
- Same enemy can be hit only once by a given Briarball.
- Basalt collision retained-speed multiplier: **70%**
- Maximum active Briarballs: **2**

#### Implementation notes

- If the active cap is reached when the fourth qualifying death occurs, preserve the completed charge until an active Briarball expires.
- Briarball damage counts as relic damage.
- Briarball-applied Entanglement can trigger normal full-Entanglement roots and therefore Snare Vine.
- Briarball Repulsion can qualify for Hookthorn.
- Briarball kills can qualify as future Briarball deaths only if the victim had at least 90% Entanglement before death.
- A single enemy death can contribute only one Briarball charge.

---

## Legendary

### The Hedge

**Player-facing description:** When 6 enemies reach 70% Entanglement, a Briar Sweep races across your Green and drives the crowd toward full Entanglement.

**Trigger:** Enough enemies are simultaneously heavily Entangled.

A massive Briar Sweep travels across owned Green, pushing the entire enemy population toward full Entanglement.

#### Current implementation

- Required enemies: **6**
- Required Entanglement per qualifying enemy: **70%**
- Normal-enemy minimum Entanglement after the Sweep: **75%**
- Elite and boss floor multiplier: **35%**
- Cooldown: **10.0s**

#### Explicit implementation notes

- Normal enemies caught by the Sweep are raised to at least **75% Entanglement**. Enemies already above 75% keep their higher value.
- For elites and bosses, apply **35% of the normal floor effect** according to the existing implementation's resistance handling.
- The Sweep should travel visibly through connected owned Green instead of applying globally in one frame.
- Suggested visual travel speed: **520 px/s**
- Maximum visual Sweep duration: **1.5s**
- The 10.0s cooldown begins when the Sweep starts.
- Enemies pushed to full Entanglement by any secondary interaction caused after The Hedge may trigger normal roots and Snare Vine.
- The Hedge itself should not directly force a root unless the resulting Entanglement value reaches the normal 100% threshold.

---

# Bramble interaction examples

The intended relic engine is circular:

**Green damage → Repulsion → Hookthorn collision → more Entanglement → full Entanglement → root → Snare Vine → more Entanglement**

and:

**heavily Entangled death → Briar Knot or Briarball → more Entanglement → more roots → more Snare Vine triggers**

The Hedge acts as the high-end detonator that pushes a large battlefield population close enough to full Entanglement for the rest of the Bramble relic collection to cascade.



# Root System Changes

These changes accompany the Root relic rework and remove the player-facing Biomass/Metabolism management layer.

## Remove player-facing Biomass and active Metabolism

- Remove Biomass as a player-managed resource.
- Remove Biomass spending as the cost for active Root actions.
- Remove the player-facing active Metabolism layer, including the old **Overgrow**, **Deep Root**, **Pressurize**, **Translocate**, and **Regenerate** action loop.
- Remove Rooting / Storage / Circulation / Anchoring progression and Metamorphosis forks if they exist only to support that active economy.
- Metabolism may remain internally as hidden territory-strength logic, but the player should not need to monitor or manage a Metabolism meter.
- Player-facing Root should communicate through **Fresh Green**, **Mature Green**, **Root Network**, and **Root Potency**.

The purpose of this cut is to reduce cognitive load and keep attention on movement, territory, Adaptations, relics, and Clover rather than another parallel resource-management layer.

## Replace Biomass Yield with Lateral Roots

The old **Biomass Yield** Root upgrade line is removed.

### Lateral Roots

**Effect:** Mature Green projects Root Network strength through nearby connected owned Green.

| Rank | Additional Root Network reach |
|---|---:|
| 1 | **+24 px** |
| 2 | **+48 px** |
| 3 | **+72 px** |
| 4 | **+96 px** |
| 5 | **+120 px** |

#### Projection rule

For a point on connected owned Green outside fully Mature territory:

`projected_root_strength = 1 - (distance_to_nearest_qualifying_mature_green / lateral_root_reach)`

Clamp projected strength to **0.0–1.0**.

Use the stronger of:

- local Root Network strength from the territory directly underneath the effect, or
- projected Root Network strength supplied by nearby Mature Green.

#### Implementation notes

- Projection travels only through **contiguous owned Green**.
- Projection cannot cross Neutral, Hostile, void, basalt, walls, or rocks.
- Distance should follow connected territory rather than straight-line distance through blocked terrain.
- At rank 5, a point **60 px** from qualifying Mature Green receives **50% projected Root strength**.
- At **120 px or farther**, projected support is **0%**.
- Lateral Roots does not make supported territory Mature. It only extends Root Network influence.
- Root Potency still determines how strong Root Network amplification is once support reaches the effect.

## Final normal Root upgrade lines

| Upgrade line | Per-rank effect | Rank 5 |
|---|---:|---:|
| **Maturation Speed** | **+22% maturation rate** | **+110%** |
| **Lateral Roots** | **+24 px Root Network reach** | **+120 px** |
| **Mature Strength** | **+16% Mature resistance** and **+0.008 control/s recovery** | **+80%**, **+0.04/s** |
| **Root Potency** | **+22% Root Network amplification** | **+110%** |

---

# Root Relics

Root relics make Mature Green behave like one interconnected organism. They transmit growth, establishment, recovery, and Adaptation consequences through the Root Network without introducing another player-managed resource.

## Shared Ancient Territory placement rule

**Taproot, Annual Rings, and World Tree no longer choose the globally oldest Mature territory regardless of location.**

Whenever one of these relics needs to select a new supporting region:

1. Search owned Green within **320 px of Grandma**.
2. Require territory maturity of at least **90%**.
3. Group qualifying Green into connected Mature regions.
4. Ignore regions smaller than **16 owned cells**.
5. Among valid nearby regions, choose the region with the **oldest average territory age**.
6. Place the relic object at the valid Mature point nearest that region's center of mass.

If no valid region exists within 320 px:

- expand the search to **480 px**;
- if still none exists, choose the **nearest qualifying Mature region anywhere on the map**;
- do **not** fall back to the globally oldest region.

Selection priority:

**near Grandma → oldest qualifying region → central placement inside that region**

### Persistence

- Once Taproot or World Tree establishes on a region, it stays there until its supporting territory is lost.
- If it must reform or relocate, rerun the selection using Grandma's **current position**.
- Annual Rings uses the same rule when selecting each new tracked region, excluding regions it already tracks.

---

## Common

### Rootbound

**Player-facing description:** Spend 2.5s on deeply Mature Green to charge a root pulse. Carry it into younger Green to rapidly mature the area.

**Trigger:** Grandma remains on deeply Mature Green long enough to charge the Root Network, then enters younger owned Green.

The stored root pulse discharges into the younger territory and rapidly establishes it.

#### Current implementation

- Required continuous time on Green at **≥90% maturity:** **2.5s**
- Maximum stored charges: **1**
- Charge duration after leaving qualifying Mature Green: **4.0s**
- Discharge condition: enter owned Green below **60% maturity**
- Pulse radius: **95 px**
- Maturity granted: **+18 percentage points**
- Internal cooldown: **4.0s**
- Leaving owned Green entirely does not discharge the charge.
- Re-entering qualifying ≥90% Mature Green while charged does not create a second charge.

#### Implementation notes

- Rootbound should visually read as stored root energy carried by Grandma.
- Forced maturation from another effect does not itself create a Rootbound charge.

---

### Suckers

**Player-facing description:** When enemies tear away enough Mature Green, surviving roots sprout replacement Green back into the wound.

**Trigger:** Enemies destroy a substantial local amount of Mature Green.

Surviving roots around the wound throw out replacement shoots.

#### Current implementation

- Trigger threshold: enemy-caused destruction of **24 Mature owned cells within 1.0s**
- Local trigger grouping radius: **110 px**
- Suckers created: **2**
- Emergence delay: **0.45s**
- Each Sucker targets lost or hostile valid ground within **110 px**
- Growth per Sucker: **0.18× baseline Seed Growth Mass**
- Growth radius: **52 px**
- New Green begins at **25% maturity**
- Regional cooldown: **4.0s**
- Maximum active Suckers: **4**

#### Trigger exclusions

Do not trigger from Pruning sacrifice, Clover wagers, player-authored territory removal, scripted cleanup, or run/wave transitions.

#### Recursion rules

- Green created by Suckers can interact with normal territory-created systems.
- Sucker-created Green does not itself count as enemy loss for another Suckers trigger.

---

### Feeder Roots

**Player-facing description:** Every 4 natural Adaptation events amplified by Mature Green send a maturity pulse toward younger connected Green.

**Trigger:** Enough natural Adaptation events receive Root Network amplification from fully Mature Green.

The network sends a feeding pulse toward younger connected Green.

#### Current implementation

- Eligible amplified events required: **4**
- Source territory requirement: **≥90% maturity**
- Event must actually receive nonzero Root Network amplification.
- On the fourth event, target the lowest-maturity connected owned region within **240 px**
- Pulse travel speed: **440 px/s**
- Pulse radius: **80 px**
- Maturity granted: **+12 percentage points**
- Control recovery: **+0.08**
- Internal cooldown after firing: **2.0s**
- Maximum banked progress: **4/4**
- No second pulse can be banked.

#### Eligible natural event examples

- Seed germination
- Bloom detonation
- Bramble activation
- Pruning release
- Thistle network firing cycle
- Vine sweep
- Fruit launch

#### Recursion rules

- Relic-generated echoes may still receive Root amplification.
- Relic-generated echoes do **not** advance Feeder Roots.
- A Feeder Roots pulse does not count as an Adaptation event.

---

## Uncommon

### Taproot

**Player-facing description:** An old Mature region near Grandma becomes a Taproot, repairing nearby Green every 4s.

An old Mature region near Grandma becomes a persistent repair anchor.

#### Current implementation

- Repair interval: **4.0s**
- Repair Mass: **0.55×**
- Repair radius: **1.30×**

#### Updated placement rule

Taproot uses the **Shared Ancient Territory placement rule** instead of selecting the globally oldest Mature territory.

When the supporting region is lost:

- rerun the selection around Grandma's current position;
- establish on the oldest qualifying nearby region.

#### Implementation notes

- Taproot remains fixed after placement until its supporting territory is lost.
- It does not continuously follow Grandma.

---

### Graft Union

**Player-facing description:** Reconnect two established Green networks to mature both sides and echo the next nearby Adaptation event from the opposite side at 50% strength.

**Trigger:** Two previously disconnected owned Green networks reconnect.

The graft point releases a maturation surge and temporarily links the two sides for one Adaptation echo.

#### Current implementation

A reconnection qualifies when:

- both components contain at least **16 owned cells**;
- they have been disconnected for at least **3.0s**.

On connection:

- pulse radius on each side: **90 px**
- maturity granted: **+15 percentage points**
- armed duration: **5.0s**

While armed:

- first eligible natural Adaptation event within **120 px** of either endpoint echoes from the opposite endpoint;
- echo delay: **0.30s**
- echo strength: **50%**
- cooldown after echo: **8.0s**

#### Strength rules

Multiply scalable outputs by **0.50**, including damage, Force, conversion, Growth Mass, duration, and integer object/projectile counts where appropriate.

For integer counts:

`max(1, floor(original_count × 0.50))`

#### Recursion rules

- Graft Union echoes can trigger unrelated relics.
- Graft Union echoes cannot trigger Graft Union.
- Unique permanent objects are not permanently duplicated.
- Rhizome reconnections qualify for Graft Union.

---

## Rare

### Annual Rings

**Player-facing description:** Old Mature regions gain a Ring every 22s, up to 3, with each Ring increasing local Root Potency.

Long-lived Mature regions accumulate visible Rings that increase local Root Potency.

#### Current implementation

- Ring interval: **22.0s**
- Maximum Rings per region: **3**
- Maximum tracked regions: **4**
- Root Potency per Ring: **+0.14**
- Effect radius: **110 px**

#### Updated region-selection rule

When Annual Rings begins tracking a new region:

1. Apply the **Shared Ancient Territory placement rule**.
2. Exclude Mature regions already tracked by Annual Rings.
3. Choose the oldest remaining qualifying region near Grandma.
4. Expand to **480 px** only if necessary.
5. Fall back to the nearest valid untracked Mature region only if no nearby option exists.

#### Implementation notes

- Existing tracked regions remain tracked until invalidated by territory loss.
- Grandma moving away does not relocate an already tracked region.
- When a tracked region is lost and a slot becomes available, rerun selection using Grandma's current position.

---

### Rhizome

**Player-facing description:** A mature isolated colony that survives 10s grows a root corridor back to the main network.

**Trigger:** A sufficiently established isolated colony remains disconnected from the main Root Network.

The colony grows a visible root runner back toward the main organism.

#### Current implementation

- Minimum isolated colony size: **24 owned cells**
- Minimum average colony maturity: **70%**
- Required disconnected survival time: **10.0s**
- Maximum connection distance: **320 px**
- Rhizome growth duration: **1.20s**
- Corridor width: **28 px**
- Created corridor begins at **50% maturity**
- Successful-connection cooldown: **12.0s**
- Failed-route retry delay: **3.0s**
- Maximum active Rhizome runners: **1**

#### Routing

- Use obstacle-aware routing around basalt, walls, and rocks.
- Use the same broad routing and collision principles as Vine.
- If no valid route exists, retry after 3.0s without consuming the success cooldown.

#### On connection

- Both endpoints emit a **100 px** root pulse.
- Nearby owned Green gains **+10 percentage points maturity**.
- The reconnection qualifies for Graft Union.

---

## Legendary

### World Tree

**Player-facing description:** An ancient Mature region grows a World Tree. Every 6s, the next eligible Plant event on Mature Green echoes at 45% strength.

An ancient Mature region near Grandma grows the World Tree. Charged Plant events originating from established territory echo through the organism.

#### Current implementation

- Charge interval: **6.0s**
- Eligible-event echo strength: **45%**
- Reform delay after supporting territory is lost: **20.0s**
- World Tree provides no independent damage.

#### Updated placement rule

World Tree uses the **Shared Ancient Territory placement rule**.

On initial creation:

- choose the oldest qualifying Mature region near Grandma;
- place the Tree near that region's center of mass.

If its supporting territory is lost:

- wait the existing **20.0s** reform delay;
- rerun selection around Grandma's current position;
- grow the replacement Tree on the oldest qualifying nearby region.

#### Recursion rules

- World Tree echoes may activate unrelated relic interactions.
- World Tree echoes cannot cause a second World Tree echo from the same charge.
- The Tree remains fixed after establishing until its supporting territory is lost.

---

# Root interaction examples

The intended Root relic engine is based on network transmission:

**Mature Green powers natural Adaptation events → Feeder Roots establishes younger Green → Lateral Roots extends Root support farther forward**

and:

**isolated colony survives → Rhizome reconnects it → Graft Union arms → next Adaptation event echoes across the new connection**

while:

**Taproot, Annual Rings, and World Tree preferentially establish on old territory near Grandma instead of disappearing onto remote map edges.**



# Pruning Relics

Pruning relics focus on the full pruning cycle: harvesting Green, holding the orbiting Cutting ring, building Charge, releasing the ring, exploiting Cuttings, and reclaiming the wound afterward.

## Pruning baseline reference

Current authored Pruning behavior includes:

- Maximum orbiting Cuttings: **16**
- Full Charge time: **8.0s**
- Base Cutting damage: **26**
- Base held-ring contact damage: **26**
- Base Cutting Pierce: **2**
- Initial harvest drain: **15 cells/s**
- Harvest-drain escalation while held: **+5 cells/s²**

Unless a relic says otherwise, Pruning relic effects scale from the current stat-scaled Cutting damage and current released-ring behavior.

## Common

### Gleaning Hook

**Player-facing description:** Every 8 held-ring kills grants 5% Charge without cutting more Green, up to 15% per hold.

**Trigger:** The held Pruning ring kills enemies before release.

Held-ring kills contribute free Charge without consuming additional Green.

#### Current implementation

- Kills required per Charge bonus: **8**
- Charge granted: **+5 percentage points**
- Maximum bonus Charge per hold: **+15 percentage points**
- Maximum qualifying kill thresholds per hold: **3**
- Bonus Charge does not itself increase Green sacrifice.

#### Implementation notes

- Count only kills caused by the held orbiting ring.
- Released-ring kills do not contribute.
- Reset the per-hold kill counter and bonus cap after release or cancellation.
- Gleaning Hook can help reach 100% Charge sooner, but cannot raise Charge above the normal 100% cap.

---

### Skimming Cut

**Player-facing description:** The first time a released Cutting hits terrain, it ricochets toward a nearby enemy at 65% damage.

**Trigger:** A natural released Cutting hits basalt, a wall, or a rock.

The first obstacle collision redirects the Cutting toward a nearby enemy instead of immediately spending it.

#### Current implementation

- Ricochets per qualifying Cutting: **1**
- Target acquisition range from collision: **180 px**
- Ricochet speed: **75%** of pre-impact speed
- Ricochet damage multiplier: **65%**
- Remaining Pierce after ricochet: **1**
- Retarget delay: **0.05s**
- If no valid enemy exists within 180 px, spend the Cutting normally.
- A Cutting that has already ricocheted is destroyed by its next basalt/wall/rock collision.

#### Implementation notes

- Only natural outward released Cuttings qualify.
- The visual path must visibly glance from the collision point toward the new target.
- Skimming Cut does not allow Cuttings to pass through obstacles.
- A Skimming Cut ricochet can still start Watersprouts if it kills an enemy.
- Brush Pile, Return Stroke, and other relic-generated projectiles do not gain Skimming Cut unless explicitly stated.

---

### Callus

**Player-facing description:** After releasing Pruning, return to the wound within 8s to trigger one immediate reclamation pulse.

**Trigger:** After releasing Pruning, Grandma returns to Green that was cut during that specific hold.

Returning to the wound causes one local reclamation pulse.

#### Current implementation

- Eligibility window after release: **8.0s**
- Uses per Pruning release: **1**
- Trigger condition: Grandma enters Pruned Ground belonging to that release from outside the wound.
- Pulse radius: **70 px**
- Immediate control restoration: **+0.14**
- Plant Mass injection: **0.12× baseline Seed Growth Mass**
- Maturity granted: **0**
- Only territory belonging to the qualifying Pruning wound can be affected.

#### Implementation notes

- Standing on the wound when the ring releases does not trigger Callus.
- The player must leave and re-enter, or enter from outside after release.
- Callus cannot trigger on unrelated old Pruning wounds.
- Callus recovery can interact with ordinary territory-restoration systems but does not count as new Seed germination.

---

## Uncommon

### Brush Pile

**Player-facing description:** After 50% Charge, continued harvesting stores bonus Cuttings. Release to fire up to 8 extra Cuttings after the ring.

**Trigger:** The player continues harvesting after reaching 50% Charge.

Excess harvesting stores Brush bundles that release as a delayed bonus Cutting volley.

#### Current implementation

- Brush accumulation begins at **50% Charge**
- Additional harvested cells required per Brush bundle: **24**
- Maximum Brush bundles: **4**
- Bonus Cuttings per bundle: **2**
- Maximum bonus Cuttings per release: **8**
- Bonus Cutting damage multiplier: **55%**
- Bonus Cutting speed multiplier: **90%**
- Bonus Cutting Pierce: **1**
- Bonus volley delay after normal release: **0.18s**
- Brush resets completely after release or cancellation.

#### Implementation notes

- Green sacrificed to build Brush is still permanently removed until normal reclamation restores it.
- Brush Pile Cuttings do not start Watersprouts.
- Brush Pile Cuttings can damage enemies and activate ordinary generic kill relics.
- Brush Pile does not alter the maximum natural ring size of 16 Cuttings.

---

### Stubble

**Player-facing description:** Pruned Ground stays sharp for 5s, damaging enemies that cross the wound.

**Trigger:** Pruning is released.

The territory cut during that hold remains temporarily hazardous to enemies.

#### Current implementation

- Stubble duration: **5.0s**
- Affected area: Pruned Ground created by the most recent qualifying release
- Damage tick interval per enemy: **0.65s**
- Damage per tick: **35% of current Cutting damage**
- Rank-0 reference damage: **9.1**
- Knockback: **0**
- Pierce: not applicable
- Charge generation: **0**
- Maximum simultaneous Stubble wounds: **2**
- Reclaimed cells immediately stop dealing Stubble damage.

#### Implementation notes

- Each enemy tracks its own 0.65s Stubble tick cooldown.
- Stubble damage counts as relic damage.
- Stubble kills cannot start Watersprouts.
- When a third qualifying Stubble wound is created, remove the oldest remaining Stubble wound.
- Stubble ends early on cells that return to owned Green.

---

## Rare

### Green Manure

**Player-facing description:** Each released-ring kill speeds reclamation by 9%, up to 2.6x for 8s.

**Trigger:** Enemies are killed by the released Pruning ring.

Release kills accelerate reclamation of the Pruned Ground.

#### Current implementation

- Reclamation-speed bonus per qualifying kill: **+9%**
- Maximum reclamation-speed multiplier: **2.60×**
- Bonus duration: **8.0s**

#### Explicit implementation notes

- Approximately **18 qualifying kills** are required to reach the 2.60× cap from baseline.
- Qualifying kills:
  - natural outward released ring,
  - Return Stroke.
- Non-qualifying kills:
  - held ring,
  - Stubble,
  - Brush Pile,
  - Watersprouts,
  - unrelated relic-generated projectiles.
- Each qualifying kill refreshes the 8.0s duration.
- Clamp the final reclamation-speed multiplier at 2.60×.

---

### Return Stroke

**Player-facing description:** After expanding, the released ring sweeps back toward Grandma once at 55% damage.

After the released ring reaches maximum expansion, it contracts back toward Grandma for one reduced second pass.

#### Current implementation

- Returning damage multiplier: **55%**
- Returning speed multiplier: **80%**
- Charge generation: **0**
- Additional release-effect triggers: **0**

#### Implementation notes

- Return Stroke follows Grandma's current position during the return rather than the original release position.
- Return Stroke kills qualify for Green Manure.
- Return Stroke cannot start Watersprouts.
- Return Stroke cannot create another Return Stroke.
- Other generic on-hit or on-kill relics may react normally unless explicitly excluded.

---

## Legendary

### Watersprouts

**Player-facing description:** Kills from natural released Cuttings sprout 2 seeking Cuttings. Those children can branch one final time.

**Trigger:** A natural outward released Cutting kills an enemy.

The corpse erupts into new Cuttings that seek additional enemies. Generation-1 child kills may create one final generation.

#### Current implementation

### Generation 1

- Children per qualifying natural-Cutting kill: **2**
- Damage multiplier relative to parent natural Cutting: **55%**
- Speed multiplier: **115%**
- Pierce: **1**
- Target acquisition range: **220 px**
- Spawn delay after parent kill: **0.08s**
- Prefer two different targets when at least two valid enemies exist.

### Generation 2

- Children per qualifying Generation-1 kill: **2**
- Damage multiplier relative to Generation 1: **55%**
- Effective damage relative to original natural Cutting: **30.25%**
- Speed multiplier: **115%**
- Pierce: **1**
- Generation 2 cannot reproduce.

### Global limits

- Maximum Watersprout Cuttings spawned per natural Pruning release: **16**
- Maximum Watersprout child spawns resolved in one rendered frame: **8**
- Excess same-frame spawns are delayed in **0.04s** increments.
- If no valid target exists, do not spawn that child.
- Maximum reproduction depth: **2 generations**

#### Eligible Watersprout starters

Eligible:
- natural outward released Cuttings,
- a natural outward Cutting after a Skimming Cut ricochet.

Not eligible:
- held-ring contact kills,
- Brush Pile bonus Cuttings,
- Return Stroke,
- Stubble,
- Evolution splinters such as Deadfall-generated projectiles,
- other relic-generated projectiles.

#### Recursion rules

- Generation-1 Watersprouts may create Generation 2.
- Generation-2 Watersprouts cannot reproduce.
- Watersprout kills do not qualify for Green Manure.
- Watersprout kills may activate unrelated generic kill relics.
- The 16-child per-release cap is absolute across both generations combined.

---

# Pruning interaction examples

The intended Pruning relic engine turns one sacrificed-territory attack into a multi-stage offensive cycle:

**held-ring kills → Gleaning Hook → faster Charge**

then:

**continued harvesting → Brush Pile → bonus delayed volley**

then:

**release → natural Cutting kill → Watersprouts → branching child Cuttings**

while:

**obstacle hit → Skimming Cut → redirected natural Cutting → possible Watersprouts starter**

and afterward:

**released-ring kills → Green Manure → faster wound reclamation**

plus:

**return to the wound → Callus → immediate local recovery**

Pruning should feel like the player deliberately wounds the garden to create one attack that increasingly refuses to end.



# Thistle Relics

Thistle relics focus on a distributed turret network where one Thistle's attacks cause other Thistles to react. The relic pool should amplify firing coordination, impact chains, corpse-triggered thorns, and synchronized network events rather than simply multiply projectile count on every shot.

## Thistle baseline reference

Current authored Thistle behavior includes:

- Permanent Thistles: **2 to 5**
- Base thorn damage: **12**
- Clustering: **+1 projectile per rank**
- Maximum normal projectiles at Clustering rank 5: **6**
- Attack Speed: **+15% per rank**
- Maximum Attack Speed bonus at rank 5: **+75%**
- Burr: **+1 ricochet per rank**
- Maximum Burr ricochets at rank 5: **5**
- Needlepoint: **+10 percentage points critical chance per rank**
- Maximum Needlepoint crit chance at rank 5: **50%**
- Each ricochet independently rolls Needlepoint crit.
- Root Potency can add effective ranks to owned Thistle upgrades when the firing origin qualifies.

Unless a relic says otherwise, Thistle relics use the current stat-scaled thorn damage, projectile count, targeting, crit, and ricochet behavior.

## Network event definitions

A **natural firing cycle** is a normal permanent-Thistle attack generated by the Thistle's standard attack cadence.

Relic-generated volleys and bonus thorns are tagged separately and do not advance counters unless explicitly stated.

Recommended source tags:

- `THISTLE_NATURAL`
- `THISTLE_ROSETTE`
- `THISTLE_RELAY`
- `THISTLE_PINCUSHION`
- `THISTLE_SEEDHEAD`
- `THISTLE_ANSWERING_THORN`
- `THISTLE_PHYLLOTAXIS`
- `THISTLE_FORKING_PATTERN`
- `THISTLE_CROWN`

---

## Common

### Rosette

**Player-facing description:** Every time your Thistle takes root, including each time you set a carried one down, it immediately fires a 60%-damage opening volley.

**Trigger:** A permanent Thistle finishes growing, is replaced after its previous support is lost, or works loose from Grandma and takes root again.

The newly established turret immediately fires one reduced opening volley.

#### Current implementation

- Opening delay after placement: **0.25s**
- Damage multiplier: **60%**
- Projectile count: current Clustering projectile count
- Needlepoint: inherited normally
- Maximum Burr ricochets per Rosette thorn: **1**
- Rosette does **not** advance the normal Thistle attack cooldown.
- Rosette does **not** advance Phyllotaxis.
- Rosette does **not** advance Crown of Thorns.
- Temporary Evolution-created Thistles do **not** trigger Rosette.
- Permanent replacement Thistles **do** trigger Rosette.
- A carried Thistle dropped back onto supporting Green **does** trigger Rosette. With the network capped at one turret this is Rosette's main payout, and the stick cooldown is what bounds it.

#### Implementation notes

- Rosette should fire only after the turret has reached its normal active/targetable state.
- If no target is available at 0.25s, retry once after **0.35s**.
- If the retry fails, consume the Rosette event rather than storing it indefinitely.
- Rosette volleys may activate unrelated generic on-hit and on-kill relics.

---

### Thorn Relay

**Player-facing description:** Every 8 natural thorn hits, your Thistle answers with a bonus thorn at 42% damage, or 65% if a second Thistle is standing to answer instead.

**Trigger:** Enough natural thorn impacts occur across the Thistle network.

A different Thistle immediately fires one bonus thorn. With the permanent network capped at one turret there is usually no different Thistle, so the source turret answers itself at a reduced share rather than the relic reading as dead text.

#### Current implementation

- Natural thorn impacts required: **8**
- Counter scope: network-wide
- Bonus thorns per activation: **1**
- Bonus thorn damage multiplier: **65%**
- Responding turret: nearest active Thistle other than the turret responsible for impact #8; the source turret itself when it is the only one standing
- Solo-network damage share: **65%** of the listed multiplier
- If the responding turret has no current target, acquire one using ordinary Thistle targeting.
- Needlepoint: inherited normally
- Maximum Burr ricochets: **1**
- Clustering: not inherited
- Maximum Thorn Relay activations: **2 per second**

#### Counter rules

Impacts that advance Thorn Relay:
- natural Thistle thorns from `THISTLE_NATURAL`.

Impacts that do not advance Thorn Relay:
- Rosette,
- Thorn Relay bonus thorns,
- Pincushion,
- Seedhead,
- Answering Thorn,
- Phyllotaxis,
- Forking Pattern,
- Crown of Thorns,
- Evolution-generated Thistle attacks unless explicitly designated as natural.

#### Implementation notes

- Reset the impact counter to 0 after each activation.
- Excess same-frame natural impacts after the eighth impact may begin filling the next counter.
- A Thorn Relay bonus thorn may trigger generic hit or kill systems but cannot advance Thorn Relay, Crown, or Phyllotaxis.

---

### Pincushion

**Player-facing description:** Hit an enemy with 5 thorns before it dies to launch 3 embedded thorns from its corpse.

**Trigger:** An enemy absorbs enough natural Thistle projectile impacts and then dies.

Embedded thorns burst from the corpse toward nearby enemies.

#### Current implementation

- Embedded-thorn threshold: **5**
- Natural Thistle impact: **+1 embedded thorn**
- Maximum stored embedded thorns: **5**
- Stack expiration: **3.0s** after the most recent qualifying Thistle impact
- On death at 5 stacks: launch **3 thorns**
- Target acquisition range: **190 px**
- Prefer unique targets when possible
- Spawn delay after death: **0.10s**
- Damage multiplier: **45%**
- Needlepoint: inherited normally
- Burr ricochets: **0**
- Pierce: **0**
- One Pincushion eruption per enemy

#### Stack rules

Qualifying impacts:
- natural Thistle thorns,
- Rosette,
- Seedhead,
- Answering Thorn,
- Crown of Thorns.

Non-qualifying impacts:
- Pincushion thorns,
- Phyllotaxis,
- Forking Pattern,
- Thorn Relay bonus thorns.

#### Recursion rules

- Pincushion thorns cannot add Pincushion stacks.
- Pincushion kills cannot directly create another Pincushion eruption unless the victim had already independently reached 5 embedded thorns.
- Pincushion damage counts as relic damage and may activate generic kill relics.

---

## Uncommon

### Seedhead

**Player-facing description:** Your Thistle fires one final volley at 150% damage as it collapses, including when you drop it off the Green.

**Trigger:** A Thistle loses the Green supporting it and is about to collapse.

The dying turret fires one final empowered volley.

#### Current implementation

- Final-volley damage multiplier: **1.50×**
- Rank-0 thorn reference damage: **12**; the 1.50× final volley therefore deals **18** before other modifiers
- Inherits current Clustering projectile count
- Inherits current Burr ricochets
- Inherits current Needlepoint critical chance
- Inherits eligible Root Potency effective ranks
- Temporary Thistles qualify
- Uses per turret life: **1**

#### Implementation notes

- Resolve Seedhead before the turret is removed from the network.
- Seedhead does not prevent the turret from collapsing.
- Seedhead does not advance Crown or Phyllotaxis.
- Seedhead impacts may contribute Pincushion stacks.
- A permanent replacement turret created afterward may trigger Rosette.

---

### Answering Thorn

**Player-facing description:** When a natural volley gets a kill, your Thistle answers with another volley at 33% damage, or 50% if a second Thistle answers instead. 2.25s cooldown.

**Trigger:** A natural Thistle volley kills at least one enemy.

The nearest different Thistle answers with one reduced volley. With the permanent network capped at one turret, the killing turret answers itself at a reduced share instead.

#### Current implementation

- Trigger requirement: natural volley scores **at least 1 kill**
- Answer delay: **0.18s**
- Responding turret: nearest different active permanent Thistle with a valid target; the killing turret itself when it is the only one standing
- Solo-network damage share: **65%** of the listed multiplier
- Answering volley damage multiplier: **50%**
- Projectile count: current Clustering count
- Needlepoint: inherited normally
- Maximum Burr ricochets per thorn: **1**
- Global cooldown: **2.25s**
- Temporary Thistles may receive the answering volley.
- Temporary Thistles cannot initiate Answering Thorn.

#### Counter and recursion rules

- Answering Thorn does not advance Crown.
- Answering Thorn does not advance Phyllotaxis.
- Answering Thorn cannot trigger Answering Thorn.
- Answering Thorn impacts may contribute Pincushion stacks.
- Answering Thorn kills may activate unrelated generic kill relics.
- If no valid responding turret exists, consume the trigger and begin only **1.0s** of cooldown instead of 2.25s.

---

## Rare

### Phyllotaxis

**Player-facing description:** Every 5th natural firing cycle from your Thistle adds 5 spiral thorns at 55% damage.

Every fifth natural firing cycle from an individual Thistle adds a spiral packet of bonus thorns.

#### Current implementation

- Trigger cadence: every **5th natural firing cycle per individual turret**
- Bonus thorns: **5**
- Spiral packet arc: **48 degrees**
- Damage multiplier: **55%**
- Rank-0 thorn reference damage: **6.6**
- Rank-0 crit reference damage: **13.2**
- Needlepoint: inherited normally
- Maximum Burr ricochets: **1**
- Clustering: not inherited
- Phyllotaxis thorns do not advance Phyllotaxis.

#### Implementation notes

- Each permanent Thistle tracks its own 1-to-5 firing counter.
- Temporary Thistles do not maintain a persistent Phyllotaxis counter unless their existing implementation explicitly does.
- Phyllotaxis impacts do not advance Thorn Relay.
- Phyllotaxis thorns may activate unrelated generic hit and kill systems.

---

### Forking Pattern

**Player-facing description:** Every 12 natural thorn impacts makes the triggering hit split into 3 seeking thorns, or 4 if it crits.

**Trigger:** Every twelfth natural thorn impact across the network.

The triggering thorn impact branches into several new thorns aimed at enemies the original projectile has not yet hit.

#### Current implementation

- Natural thorn impacts required: **12**
- Counter scope: network-wide
- Base branches per trigger: **3**
- If the triggering impact is a critical hit: **4 branches**
- Target acquisition radius from impact: **210 px**
- Prefer unique targets
- First target cannot be the enemy hit by the triggering thorn
- Branch damage multiplier: **55%**
- Branch speed multiplier: **110%**
- Needlepoint: inherited normally
- Maximum Burr ricochets per branch: **1**
- Maximum Forking Pattern activations: **1 every 0.75s**
- Maximum simultaneously active Forking Pattern thorns: **8**

#### Counter rules

Only impacts from `THISTLE_NATURAL` advance Forking Pattern.

Forking Pattern branches:
- do not advance Forking Pattern,
- do not advance Thorn Relay,
- do not advance Crown,
- do not add Pincushion stacks.

#### Active-cap handling

- If fewer than the required branch slots are available under the 8-active-thorn cap, spawn only enough branches to reach the cap.
- Do not queue missing branches for later.

---

## Legendary

### Crown of Thorns

**Player-facing description:** Every 12 natural firing cycles, your Thistle fires 3 volleys in quick succession at 55% damage, or every standing Thistle fires together once if there is more than one. 7s cooldown.

**Trigger:** Enough normal permanent-Thistle firing cycles occur across the network.

Every active Thistle immediately fires a synchronized reduced volley. A network of one has nothing to synchronize with, so the sole Thistle fires the volley three times in quick succession instead of once.

#### Current implementation

- Natural permanent-Thistle firing cycles required: **12**
- Every active Thistle fires
- Bonus-volley damage multiplier: **55%**
- Shared cooldown: **7.0s**
- Solo network (1 active Thistle): **3** volleys spaced **0.14s** apart, each at the same 55%
- Temporary Thistles participate in the synchronized volley.
- Temporary Thistles do **not** advance the 12-cycle counter.
- Crown bonus volleys do not advance the counter.
- THORNWHIP and other explicitly generated volleys do not advance the counter.

#### Explicit implementation notes

- Crown begins its 7.0s cooldown when the synchronized volley fires.
- If the 12-cycle threshold is reached while Crown is on cooldown, do not bank an extra Crown trigger.
- After cooldown ends, begin counting fresh natural firing cycles from 0.
- Crown volleys inherit current Clustering projectile count.
- Crown volleys inherit Needlepoint.
- Crown volleys use existing authored Burr behavior unless the implementation already limits bonus-volley ricochets.
- Crown impacts may contribute Pincushion stacks.
- Crown itself cannot directly advance Thorn Relay, Forking Pattern, Phyllotaxis, or another Crown.

---

# Thistle interaction examples

The intended Thistle relic engine behaves like a distributed weapon network:

**natural volleys → kills → Answering Thorn → another turret fires**

while:

**natural impacts → Thorn Relay → a different turret adds a bonus thorn**

and:

**repeated hits → Pincushion → corpse launches more thorns**

with:

**impact #12 → Forking Pattern → branching projectiles**

and finally:

**12 natural firing cycles → Crown of Thorns → every turret fires at once**

Crown acts as the high-end detonator for the rest of the Thistle relic collection without directly advancing their counters itself.



# Vine Relics

Vine relics focus on precision, positioning, alternating 90-degree sweeps, Apical hits, obstacle-aware routing, and successful lashes causing additional lashes. The relic pool should reward accurate tip placement and good sweep timing rather than simply adding generic damage.

## Vine baseline reference

Current authored Vine behavior includes:

- Base Cane damage: **24**
- Base Cane reach: **92 px**
- Base automatic sweep cadence: **0.72s**
- Sweep geometry: **90-degree frontal sector**
- Sweep direction alternates automatically:
  - left-to-right,
  - then right-to-left,
  - repeating.
- Elongation: up to **+100% reach**
- Vine damage line: up to **+125% damage**
- Attack-speed line: up to **+75% attack speed**
- Apical Dominance: up to **+125% damage** in the outer **25%** of Vine reach
- Vine uses obstacle-aware routing around basalt, walls, and rocks.
- The visible Vine route and damaging Vine route must remain identical.
- Root Potency can add effective ranks to owned Vine upgrades when the sweep origin qualifies.

Unless a relic says otherwise, Vine relics use the current stat-scaled reach, damage, cadence, Apical geometry, alternating sweep direction, and obstacle-aware path.


## Persistent guided-whip physics rework

Vine should no longer appear only during attack sweeps.

The Vine is a **persistent physical appendage** attached to Grandma and remains visible on screen at all times. Between attacks it trails, bends, settles, and wraps around terrain. When the automatic attack cadence fires, the game drives the same already-existing Vine body through the next alternating sweep.

The intended feel is similar to a freely flexible whip being driven through a controlled stroke:

**persistent trailing Vine → tension builds → driven sweep → tip accelerates and cracks → slight overshoot → physical settling → opposite sweep**

The attack is still automatic. The player does **not** directly aim or control the Vine with the joystick.

### Core behavior

- Vine exists continuously from the moment the Adaptation is acquired.
- Vine remains attached to Grandma at all times.
- Never spawn a fresh attack-only Vine for each sweep.
- Never reset Vine segment positions to a default attack pose during ordinary gameplay.
- Preserve physical state between:
  - Grandma movement,
  - natural sweeps,
  - Recurve,
  - Twining,
  - Liana,
  - obstacle wrapping,
  - idle periods.
- The Vine may be hard-reset only for:
  - initial creation,
  - scene/run initialization,
  - true teleport or forced scene correction,
  - catastrophic simulation recovery.

### Passive state

Between attack windows:

- Vine remains fully visible.
- Vine continues physical simulation.
- Vine trails behind Grandma's movement.
- Vine can bend and wrap around basalt, walls, and rocks.
- Vine gradually settles when Grandma stops.
- Vine retains residual momentum from previous movement and attacks.
- Vine deals **0 damage** while passive.
- Passive Vine should not block or physically shove enemies.
- Enemies may visually pass through passive Vine segments.
- Terrain still constrains the Vine so it cannot visually pass through basalt.

This prevents Grandma from accidentally damaging enemies simply because the resting Vine flops into them.

### Active sweep state

When a Vine attack begins:

- Enable damage on the simulated Vine body for that sweep only.
- Drive the Vine through the next authored alternating stroke.
- Natural direction remains:
  - left-to-right,
  - right-to-left,
  - left-to-right,
  - repeating.
- The **driver** follows the intended 90-degree frontal sweep.
- The rest of the Vine follows through physics.
- Actual Vine geometry may lag, bend, wrap, and slightly overshoot the ideal 90-degree sector.
- Damage comes from the actual simulated Vine body, not an invisible radial sector.
- Each enemy can normally be damaged **once per sweep**.
- After the active sweep window ends, disable attack damage but continue simulating the Vine from its final physical state.

### Sweep geometry

The authored sweep remains the control target:

- Desired driver start: **-45 degrees**
- Desired driver end: **+45 degrees**
- Opposite sweep reverses those endpoints.
- Total authored driver arc: **90 degrees**

The physical Vine is allowed to distort this shape.

#### Current implementation

- Soft visual overshoot allowance: approximately **15 degrees** beyond either authored endpoint
- Typical visible total footprint in open terrain: approximately **90 to 120 degrees**
- Do not hard-clamp the entire rope to the 90-degree sector.
- If the free tip exceeds approximately **60 degrees** from the current forward axis in open terrain, apply a strong restoring guide force.
- Obstacle wrapping may temporarily produce larger local bends when physically justified.

The 90-degree arc is therefore the **driving intent**, not a rigid damage wedge.

---

## Godot 4.7.2 technical implementation notes

### Recommended architecture

Use a custom lightweight rope/whip simulation rather than a chain of `RigidBody2D` and `PinJoint2D` nodes.

Recommended node structure:

```text
VineWhip2D (Node2D)
├── VineVisual (Line2D or existing custom Vine renderer)
└── optional debug draw / collision visualization
```

Avoid creating one physics body per Vine segment. A custom position-based or Verlet solver is more deterministic, cheaper, easier to constrain to the authored sweep, and easier to keep synchronized with gameplay hit resolution.

### Simulation data

Store the Vine as compact arrays owned by the controller.

Recommended fields:

```gdscript
var points: PackedVector2Array
var previous_points: PackedVector2Array
var segment_rest_length: float
var sweep_id: int
var sweep_active: bool
var sweep_direction: int # -1 or +1
var sweep_phase: float
var hit_enemy_ids: Dictionary
```

If allocation pressure becomes measurable, replace temporary Dictionaries used per sweep with the project's existing bounded ID/set structure.

### Segment count and length

Use the current gameplay reach to determine physical Vine length.

#### Current implementation

- Target segment rest length: **12 px**
- Point count:

```text
ceil(current_vine_reach / 12 px) + 1
```

- Minimum points: **9**
- Maximum points at current expected reach: **18**
- Rebuild or smoothly resample the chain only when effective Vine reach materially changes.

At the baseline **92 px** Cane reach this produces approximately **9 points**.

At approximately **184 px** reach after +100% Elongation this produces approximately **17 points**.

Do not add extra visual length beyond the current gameplay reach simply to make the rope look more dramatic.

### Physics update

Run Vine simulation in `_physics_process(delta)`.

Use either Verlet integration or a simple position-based dynamics solver.

Recommended initial integration:

```text
velocity = (point - previous_point) * damping
next_point = point + velocity + guide_acceleration * delta²
```

#### Current implementation

Passive-state damping:
- **0.92**

Active-sweep damping:
- **0.96**

Constraint iterations per physics step:
- **4**

Maximum emergency substeps during a frame spike:
- **3**

Clamp simulation delta used by the Vine solver to:
- **1/30 s maximum per substep**

There is no gravity in the top-down arena.

### Player attachment

Point `0` is hard-attached to Grandma's Vine attachment point every physics tick.

For normal player movement:

- move only the anchor,
- allow the rest of the chain to trail naturally.

For teleport-like movement or scene correction:

- if Grandma moves more than **80 px in one physics tick**, translate all Vine points by the same player displacement before continuing the solver.

This prevents a teleport or recovery correction from producing a giant accidental whip impulse across the arena.

### Distance constraints

After integration, solve adjacent segment length constraints.

For each adjacent point pair:

```text
desired_distance = segment_rest_length
```

Move the two free points toward or away from one another until the segment approaches the desired length.

Point `0` remains fixed to Grandma.

#### Stretch tolerance

Normal solved stretch target:
- within **3%** of rest length after the final iteration

Temporary visual stretch during a hard sweep may reach approximately:
- **110%** of nominal local segment length before the solver strongly corrects it

The Vine should feel flexible, not rubbery.

### Guided sweep driver

Do not rotate every Vine point through the sweep.

Instead, drive only the attachment-side portion of the Vine toward the desired sweep angle and allow the rest of the body to follow physically.

Recommended approach:

- Point `0`: fixed to Grandma
- Point `1`: strong guide toward the current sweep driver direction
- Point `2`: weaker guide toward the same direction
- Remaining points: physics-dominant with only a light directional bias

#### Initial guide weights

- Point 1 guide weight: **1.00**
- Point 2 guide weight: **0.55**
- Remaining-point directional bias: taper from **0.20** near the base to **0.05** at the tip

This preserves attack reliability while allowing visible lag and whip behavior.

### Sweep timing

Preserve the existing automatic attack cadence.

The physics sweep duration is separate from the interval between attacks.

If the existing attack already has an authored active-sweep duration, preserve it and use it as the driver duration.

If no separate duration exists, initial target:

```text
active_sweep_duration =
clamp(current_attack_interval * 0.55, 0.12s, 0.28s)
```

This leaves a recovery/settling window even at high attack-speed ranks.

During the active duration:

- interpolate the driver angle through the 90-degree sector,
- use an ease-in/ease-out curve rather than constant angular velocity.

Recommended starting curve:
- `smoothstep` or equivalent cubic ease

The trailing tip should naturally reach its highest speed late in the sweep rather than moving as a rigid arm.

### Persisting momentum between alternating sweeps

Do not zero segment velocity at the end of an attack.

The physical state at the end of the left-to-right sweep becomes the starting state for the right-to-left sweep.

This is particularly important for:

- Recurve,
- Twining,
- Liana.

Recurve should feel like Grandma reverses the Vine while it still has residual momentum from the previous stroke.

Liana should look increasingly violent because four rapid alternating sweeps are acting on one continuous physical object.

---

## Obstacle collision and wrapping

The persistent Vine must continue to respect the same basalt, wall, and rock collision rules as the current obstacle-aware Vine.

The visual Vine and gameplay Vine must remain the **same physical path**.

### Do not use a separate invisible route for damage

The previous obstacle-aware route can remain useful as a routing and safety guide, but it should no longer be drawn as one shape while a separate rope simulation exists visually.

The final simulated chain is authoritative for:

- rendering,
- collision presentation,
- active-sweep hit detection,
- Apical location.

### Reuse existing obstacle data

Prefer the existing collision/navigation representation already used by movement, growth, and Vine obstacle routing.

Avoid issuing a full `PhysicsDirectSpaceState2D` query for every Vine point every frame if the game's existing static obstacle field can answer the same question more cheaply.

### Point collision resolution

After each constraint iteration:

1. test each free Vine point against static basalt/wall/rock space;
2. if a point penetrates solid terrain, project it to the nearest legal position plus a small clearance;
3. rerun segment constraints;
4. repeat through the normal solver iterations.

#### Initial collision clearance

- **2 px** beyond the obstacle boundary

### Prevent segment tunneling through corners

Point-only collision is not enough because a long segment may cut through the corner of a wall even when both endpoints are legal.

For each segment:

- test the segment from `points[i]` to `points[i + 1]` against the static obstacle representation;
- if it crosses an obstacle, use the existing obstacle-aware routing logic to identify the relevant bend/corner;
- convert that bend into a temporary wrap constraint.

### Temporary wrap constraints

A wrap constraint represents the Vine being caught around an obstacle corner.

Recommended data:

```text
wrap_world_position
chain_segment_index
obstacle_id_or_cell
```

When created:

- hold the relevant portion of the Vine around the corner with approximately **2 px** clearance;
- allow points on both sides to continue moving and tightening;
- preserve the total chain length.

Release the wrap constraint when:

- the segments on either side have clear line-of-sight around the obstacle,
- and that clear state persists for **2 consecutive physics frames**.

This avoids flickering between wrapped and unwrapped states at a corner.

### Existing route planner as recovery guide

If the custom rope solver enters a state where several adjacent segments are trying to cross the same obstacle:

- request the existing obstacle-aware Vine route,
- use its bends to seed or correct temporary wrap constraints,
- continue the normal physics simulation from that corrected state.

This preserves the current reliable wall-wrapping behavior while adding physical motion on top of it.

### Climber relic integration

Climber should use actual simulated wrapping.

A Climber activation requires:

- at least one active wrap constraint or confirmed routed obstacle bend during the sweep,
- an enemy hit by a Vine segment beyond that bend.

The cinch should replay the **actual post-bend simulated segment path**, not an independently calculated line.

---

## Gameplay hit detection from the physical Vine

During a damaging sweep, hit detection should follow the actual motion of the simulated segments.

Do not use the old static 90-degree wedge as the damaging shape.

### Swept segment collision

For each Vine segment, retain:

- previous physics-frame segment endpoints,
- current physics-frame segment endpoints.

Build a swept collision region covering the segment's motion between those two frames.

To avoid tunneling by the fast-moving tip, test enemy circles/collision radii against:

- previous segment,
- current segment,
- connecting motion between the two positions.

### Performance recommendation

Do not perform a full engine physics shape query independently for all Vine segments against all enemies.

Instead:

1. calculate a swept AABB for each moving Vine segment;
2. retrieve candidate enemies from the game's existing bounded enemy spatial structure;
3. run inexpensive analytic segment-to-circle or swept-segment distance checks;
4. mark an enemy hit for the current `sweep_id`.

Each enemy normally receives at most **1 Vine hit per sweep**.

### Multiple segment contacts

If multiple Vine segments contact the same enemy during the same sweep:

- resolve only one normal Vine hit;
- if any qualifying contact came from the Apical portion, treat the resolved hit as Apical;
- otherwise use normal Vine damage.

This prevents the physics rope from multiplying damage merely because several neighboring segments overlap one enemy.

---

## Physical Apical zone

Apical Dominance should use the actual final portion of the simulated Vine rather than radial distance from Grandma.

### Base rule

The outer **25% of Vine arc length** is the Apical zone.

For a segment at normalized chain position:

```text
chain_t = distance_along_vine / total_vine_length
```

Base Apical contact:

```text
chain_t >= 0.75
```

### Trellis integration

Trellis changes the physical Apical threshold:

| Trellis state | Apical portion | Chain threshold |
|---:|---:|---:|
| 0 | outer **25%** | `chain_t >= 0.75` |
| 1 | outer **30%** | `chain_t >= 0.70` |
| 2 | outer **35%** | `chain_t >= 0.65` |
| 3 | outer **40%** | `chain_t >= 0.60` |

This keeps Trellis mechanically identical in purpose while making the visible physical Vine itself define the sweet spot.

### Apical hit presentation

The game should be able to identify which simulated segment produced the Apical hit so effects such as:

- Recurve,
- Whiplash,
- Girdling,
- Trellis,
- Liana

all respond to the same physical contact event.

---

## Passive and active visual continuity

Feed the same simulation points into the Vine renderer every frame.

If the current Vine uses `Line2D`:

- update `Line2D.points` from the simulated positions,
- keep the node visible continuously,
- disable antialiasing if needed to preserve the game's pixel-art presentation,
- reuse the current Vine texture/material treatment rather than creating attack-only visuals.

If the current renderer is custom:

- draw directly from the same `PackedVector2Array`.

Do not maintain separate idle, attack, and obstacle-wrapping geometry.

There should be **one persistent Vine body**.

### Pause behavior

When gameplay is paused:

- freeze Vine simulation with the rest of gameplay,
- preserve all current points, previous points, wrap constraints, sweep state, and direction,
- resume from the same physical configuration.

### Catastrophic recovery

The normal solver should never reset the Vine simply because it looks awkward.

Only trigger recovery if the state is invalid, such as:

- non-finite coordinates,
- segment displacement far beyond solver limits,
- impossible obstacle penetration after all correction iterations.

#### Recovery target

- Build a legal relaxed Vine pose near Grandma.
- Blend current points toward the recovery pose over **0.20s** where possible.
- Hard-snap only if the existing simulation data is unusable.

---

## Physics rework validation targets

Add or extend a focused Vine probe to verify:

1. Vine remains visible and attached while idle.
2. Moving Grandma causes trailing motion without resetting the chain.
3. Left-to-right and right-to-left natural sweeps still alternate correctly.
4. Physical tip overshoot can exceed the ideal 90-degree driver arc slightly without attacking behind Grandma.
5. Passive Vine contact deals no damage.
6. Active sweep damage follows actual simulated segment positions.
7. One enemy receives at most one normal hit per sweep.
8. Apical hits come from the actual outer chain portion.
9. Trellis expands the physical Apical portion correctly.
10. Vine wraps around basalt without visual or damaging segments crossing through it.
11. A wrapped Vine can remain wrapped between attacks.
12. Moving away from the obstacle eventually releases the wrap cleanly.
13. Recurve reverses a continuously simulated Vine without resetting momentum.
14. Twining uses the current persistent Vine state.
15. Liana performs four rapid alternating sweeps on the same continuous Vine body.
16. Climber reuses the actual wrapped path.
17. Teleport-like player corrections shift the Vine safely without producing a giant accidental attack.
18. Late-wave stress with a maximum-length Vine remains inside the authored frame-time target.


## Vine event definitions

A **natural Vine sweep** is a normal automatic alternating Cane/Vine attack generated by the Adaptation's base cadence.

Relic-generated sweeps and secondary lashes should use distinct source tags and do not advance counters unless explicitly stated.

Recommended source tags:

- `VINE_NATURAL`
- `VINE_WHIPLASH`
- `VINE_RUNNER`
- `VINE_CLIMBER`
- `VINE_RECURVE`
- `VINE_GIRDLING`
- `VINE_TRELLIS`
- `VINE_TWINING`
- `VINE_LIANA`

---

## Common

### Whiplash

**Player-facing description:** Land an Apical hit to snap the Vine 70 px past its tip for 40% follow-up damage.

**Trigger:** A natural Vine sweep lands at least one Apical hit.

The Vine tip snaps farther beyond its normal endpoint and strikes enemies outside the original sweep.

#### Current implementation

- Apical hits required: **1**
- Maximum Whiplash activations per natural sweep: **1**
- Follow-up delay: **0.10s**
- Additional reach beyond the parent sweep endpoint: **70 px**
- Follow-up path width: **30 px**
- Damage: **40% of the parent sweep's current Apical-zone damage**
- Can hit only enemies **not already hit by the parent sweep**
- Uses the parent sweep's same outer sector and final tip direction.
- Uses obstacle-aware routing.
- Maximum obstacle bends: use the same authored Vine routing cap as the parent attack.
- No additional Apical multiplier is applied to Whiplash itself.

#### Counter and recursion rules

Whiplash:
- cannot trigger Whiplash,
- does not advance Recurve,
- does not build Girdling progress,
- does not build Trellis,
- does not advance Twining,
- does not advance Liana.

Whiplash may:
- trigger generic on-hit and on-kill relics,
- trigger Runner if Whiplash kills are explicitly allowed by a later balance pass. Initial implementation: **Whiplash kills do not trigger Runner**.

---

### Runner

**Player-facing description:** The first enemy killed by each natural sweep sprouts a Runner that lashes one nearby enemy for 45% damage.

**Trigger:** The first enemy killed by each natural Vine sweep.

The corpse sprouts a temporary Runner that lashes one nearby enemy.

#### Current implementation

- Maximum Runner spawns per natural sweep: **1**
- Spawn position: first qualifying Vine-killed enemy's corpse
- Activation delay: **0.30s**
- Target acquisition radius: **135 px**
- Prefer an enemy not hit by the parent natural sweep.
- Runner lash damage: **45% of the killing Vine hit**
- Runner lash width: **20 px**
- Runner maximum waiting lifetime if no target exists: **2.0s**
- Retarget interval while waiting: **0.15s**
- Maximum active Runners: **3**
- Runner uses obstacle-aware routing around basalt, walls, and rocks.
- Runner does not receive Apical Dominance.
- Runner has no independent sweep arc. It lashes directly from corpse to selected target.

#### Recursion rules

- Runner kills cannot create another Runner.
- Runner does not advance Recurve, Trellis, Twining, Girdling, or Liana.
- Runner may trigger unrelated generic hit and kill relics.
- If the active Runner cap is reached, the new Runner is not spawned.

---

### Climber

**Player-facing description:** Wrap Vine around terrain and hit beyond the bend to cinch that wrapped segment again for 40% damage.

**Trigger:** A Vine sweep contains at least one real obstacle bend and hits an enemy after the first bend.

The wrapped section of the Vine cinches tight and damages the bent segment again.

#### Current implementation

- Required obstacle bends: **at least 1**
- Required enemy hit after first bend: **at least 1**
- Maximum Climber activations per sweep: **1**
- Cinch delay: **0.12s**
- Cinch damage: **40% of current normal Vine damage**
- Affected route: only the Vine segment **after the first obstacle bend**
- Additional reach: **0**
- Additional Apical multiplier: **0**
- Uses the exact same routed geometry as the parent sweep after the first bend.
- Climber may hit enemies already hit by the parent sweep.

#### Recursion rules

- Climber cannot trigger Climber.
- Climber does not advance Recurve, Trellis, Twining, Girdling, or Liana.
- Climber may trigger generic on-hit and on-kill relics.
- Climber should never allow Vine damage through an obstacle the routed parent Vine did not actually traverse.

---

## Uncommon

### Recurve

**Player-facing description:** An Apical hit makes the next opposite-direction natural sweep arrive 20% sooner.

**Trigger:** A natural Vine sweep lands at least one Apical hit.

The next opposite-direction natural sweep occurs sooner.

#### Current implementation

- Next opposite-direction sweep timing multiplier: **0.80×**
- Equivalent timing reduction: **20% sooner**
- Maximum Recurve benefit stored: **1**
- Multiple Apical hits during the same sweep do not stack.
- Recurve is consumed by the next opposite-direction natural sweep.
- Recurve adds **0 damage**.

#### Implementation notes

- Recurve affects only the next natural automatic sweep.
- Relic-generated sweeps do not consume Recurve.
- Relic-generated sweeps do not grant Recurve.
- If the Vine attack direction somehow resets, preserve the normal authored left-right alternation rather than allowing Recurve to create two same-direction natural sweeps.

---

### Girdling

**Player-facing description:** Apical-hit the same enemy on 2 consecutive natural sweeps to Girdle it. Your next Vine hit crushes it for 75% bonus damage.

**Trigger:** The same enemy receives Apical hits from consecutive natural Vine sweeps.

The target becomes Girdled. The next Vine hit constricts it for bonus damage.

#### Current implementation

- Consecutive natural Apical hits required on the same target: **2**
- Maximum allowed time between qualifying natural sweeps: **2.5s**
- Girdled duration after the second qualifying Apical hit: **3.0s**
- Next qualifying Vine hit consumes Girdled.
- Constriction damage: **75% of current normal Vine damage**
- Constriction delay after consuming Girdled: **0.08s**
- Per-target cooldown after constriction: **4.0s**
- Maximum simultaneously Girdled enemies: **4**
- Bosses and elites can be Girdled normally unless their authored immunity explicitly prevents the underlying Vine hit.

#### Progress rules

Builds Girdling progress:
- natural Apical Vine hits.

Does not build Girdling progress:
- Whiplash,
- Runner,
- Climber,
- Twining,
- Liana,
- other relic-generated Vine attacks.

Consumes Girdled:
- next natural Vine hit,
- Whiplash hit,
- Climber hit,
- Twining hit,
- Liana hit.

#### Recursion rules

- Constriction damage cannot build or consume another Girdling mark.
- Constriction damage may trigger unrelated generic hit/kill relics.
- If the same-target streak is broken by a natural sweep that Apical-hits a different target instead, reset that target's consecutive Girdling progress.

---

## Rare

### Trellis

**Player-facing description:** Consecutive natural Apical sweeps widen the Apical zone from the outer 25% up to the outer 40%.

Consecutive natural sweeps that successfully land Apical hits progressively widen the Apical sweet spot.

#### Current implementation

| Consecutive successful natural sweeps | Apical zone |
|---:|---:|
| 0 | Outer **25%** of current reach |
| 1 | Outer **30%** |
| 2 | Outer **35%** |
| 3 | Outer **40%** |

#### Current behavior

- Maximum Trellis stacks: **3**
- A natural sweep without an Apical hit resets Trellis to 0.
- Reach is unchanged.
- Sweep geometry remains **90 degrees**.
- Damage multipliers are unchanged.
- Trellis only changes how much of the outer reach counts as Apical.

#### Implementation notes

- Relic-generated sweeps do not build Trellis.
- Relic-generated sweeps do not reset Trellis.
- Only natural automatic sweeps determine the Trellis streak.

---

### Twining

**Player-facing description:** Every 4th natural Vine sweep repeats after 0.30s at 55% damage.

**Trigger:** Every fourth natural Vine sweep.

The triggering sweep repeats once shortly afterward at reduced damage.

#### Current implementation

- Trigger cadence: every **4th natural Vine sweep**
- Repeat delay: **0.30s**
- Repeat damage multiplier: **55%**
- Reach: **100% current Vine reach**
- Sector: same selected **90-degree sector**
- Apical geometry: inherited normally
- Sweep direction: same direction as the triggering natural sweep
- Repeat cannot advance Twining.
- Repeat cannot recursively fire automatic-sweep Evolution secondary effects.

#### Updated interaction rules

Twining repeats may:
- trigger Whiplash,
- trigger Runner,
- consume an existing Girdling mark,
- trigger generic hit/kill relics.

Twining repeats do not:
- grant Recurve,
- build Girdling progress,
- build or reset Trellis,
- advance Liana,
- advance Twining.

#### Implementation notes

- Twining's repeat originates from Grandma's current position at repeat time.
- Recalculate obstacle-aware routing for the repeat using current geometry and current targets.
- Preserve the triggering sweep's direction, even if Grandma changes facing during the 0.30s delay.

---

## Legendary

### Liana

**Player-facing description:** Land Apical hits on 3 consecutive natural sweeps to unleash 4 rapid alternating sweeps at 60% damage.

**Trigger:** Three consecutive natural Vine sweeps each land at least one Apical hit.

The Vine enters a brief cascade of rapid alternating bonus sweeps.

#### Current implementation

### Trigger

- Consecutive successful natural Apical sweeps required: **3**
- A natural sweep without any Apical hit resets Liana progress to **0**
- Internal cooldown after a cascade begins: **5.0s**
- Liana trigger progress does not accumulate while Liana is on cooldown.
- Maximum active Liana cascades: **1**
- No second cascade may be queued.

### Cascade

- Bonus sweeps per cascade: **4**
- First bonus-sweep delay after triggering natural sweep: **0.12s**
- Time between bonus sweeps: **0.16s**
- Total time from first to fourth bonus sweep: **0.48s**
- Damage per bonus sweep: **60%**
- Reach: **100% current Vine reach**
- Apical geometry: inherited normally
- Apical Dominance: inherited normally
- Sweep sector: snapshot the triggering natural sweep's **90-degree sector**
- Each bonus sweep originates from Grandma's **current position**
- Bonus sweeps alternate direction normally:
  - first bonus uses the opposite direction from the triggering natural sweep,
  - second reverses,
  - third reverses,
  - fourth reverses.
- Obstacle-aware route is recalculated independently for each bonus sweep.

#### Interaction rules

Liana bonus sweeps may:
- trigger Whiplash,
- trigger Runner,
- consume existing Girdling,
- trigger unrelated generic hit and kill relics.

Liana bonus sweeps do not:
- advance Liana,
- advance Twining,
- grant Recurve,
- build Girdling progress,
- build or reset Trellis,
- recursively trigger automatic-sweep Evolution secondaries.

#### Performance and safety caps

- Maximum bonus sweeps per cascade: **4**
- Maximum simultaneously pending Liana sweeps: **4**
- If a bonus sweep cannot route legally around an obstacle, resolve only the legal portion of its path.
- Liana never damages through basalt, walls, or rocks.

---

# Vine interaction examples

The intended Vine relic engine uses precision as the ignition switch:

**natural Apical hit → Whiplash + Recurve**

then:

**faster opposite natural sweep → another Apical hit → Trellis widens the sweet spot**

while:

**same enemy receives consecutive Apical hits → Girdling**

and:

**natural sweep kill → Runner**

with:

**every fourth natural sweep → Twining**

and finally:

**three consecutive successful natural Apical sweeps → Liana → four rapid alternating bonus sweeps**

Obstacle-aware routing also becomes an offensive opportunity:

**Vine wraps around basalt → hits enemies beyond bend → Climber cinches the wrapped segment**

Vine should remain one large directional lash, but accurate placement and successful Apical timing can make that lash produce more and more secondary lashes.



# Fruit Relics

Fruit relics focus on kinetic chains: rolling Fruit, wall bounces, enemy collisions, steering, maintained momentum, Green trails, and knockback propagation. The goal is to make one rolling object increasingly able to redirect, preserve energy, create territory, and convert enemies into temporary projectiles.

## Fruit baseline reference

Current authored Fruit behavior includes:

- Base collision damage: **36**
- Base collision knockback: **38 px**
- Base launch speed: **300 px/s**
- Base roll distance: approximately **320 px**
- Normal obstacle-bounce velocity retention: **55%**
- Terminal fuse after stopping: **0.50s**
- Terminal burst damage: up to **10**
- Fruit cooldown begins only after the current Fruit release is fully finished.
- Base cooldown after release: **1.0s**
- Fruit Set can increase total Fruit count up to **6**
- Ripening increases Fruit collision/terminal damage.
- Momentum increases roll distance.
- Germination increases Green area.
- Root Potency can add effective ranks to owned Fruit upgrade lines when the Fruit launch origin qualifies.

Unless a relic says otherwise, Fruit relics scale from the current stat-scaled Fruit collision damage, knockback, roll behavior, and Green-generation values.

## Fruit event definitions

A **natural Fruit** is a normal Fruit created by the Fruit Adaptation's regular release.

Relic-generated child objects and secondary impacts should use distinct source tags.

Recommended source tags:

- `FRUIT_NATURAL`
- `FRUIT_THICK_RIND`
- `FRUIT_STEM_STEERING`
- `FRUIT_BRUISED`
- `FRUIT_BANK_SHOT`
- `FRUIT_SALAD`
- `FRUIT_DROPPED_SEED`
- `FRUIT_WINDFALL`
- `FRUIT_NEWTON_APPLE`

---

## Common

### Thick Rind

**Player-facing description:** The first enemy collision of each Fruit costs no momentum.

**Trigger:** The first qualifying enemy collision made by a natural Fruit.

The first enemy collision does not reduce Fruit momentum.

#### Current implementation

- Protected qualifying enemy collisions per Fruit: **1**
- Momentum loss on protected collision: **0%**
- Damage: unchanged
- Knockback: unchanged
- Green painting: unchanged
- Evolution and status effects: unchanged
- Protection is consumed after the first qualifying enemy collision.

#### Rank-0 reference

- Collision damage remains **36**
- Knockback remains **38 px**

#### Implementation notes

- Thick Rind prevents only collision-induced momentum loss.
- It does not prevent obstacle-bounce velocity loss.
- It does not restore speed already lost before the first enemy collision.
- Thick Rind cannot trigger from Dropped Seeds or Newton's Apple Falling Bodies.

---

### Stem Steering

**Player-facing description:** After hitting an enemy, a Fruit can curve up to 28 degrees toward another target while keeping its speed. Twice per Fruit.

**Trigger:** A natural Fruit collides with an enemy.

The Fruit curves toward another nearby enemy while preserving its current speed.

#### Current implementation

- Maximum steering events per Fruit: **2**
- Trigger: qualifying natural Fruit enemy collision
- Target acquisition radius from collision point: **180 px**
- Prefer enemies not previously hit by that Fruit.
- Maximum heading correction per steering event: **28 degrees**
- Steering interpolation duration: **0.12s**
- Preserve current Fruit speed exactly.
- Added speed: **0**
- Minimum remaining Fruit speed required: **90 px/s**
- If no valid target exists, preserve current trajectory.
- Elites and bosses may trigger Stem Steering normally.

#### Implementation notes

- Stem Steering changes heading only.
- It does not reset roll-distance accounting or deceleration.
- Stem Steering cannot trigger from Fruit Salad, Dropped Seed, or Newton's Apple impacts.
- Windfall may also redirect the same Fruit later, subject to its own limits.

---

### Bruised Fruit

**Player-facing description:** After hitting an enemy, Fruit paints a wider, denser Green trail for its next 72 px of travel.

**Trigger:** A natural Fruit collides with an enemy.

The Fruit becomes Juicy and paints a temporarily wider, denser Green trail.

#### Current implementation

- Juicy travel distance after qualifying collision: **72 px**
- Green trail area multiplier while Juicy: **1.75×**
- Green trail Growth Mass multiplier while Juicy: **1.35×**
- Duration is measured by Fruit travel distance, not time.
- Additional qualifying Fruit collisions refresh remaining Juicy distance to **72 px**.
- Juicy effects do not stack above:
  - **1.75× area**
  - **1.35× Growth Mass**
- Terminal foothold area: unchanged
- Terminal foothold Growth Mass: unchanged
- Additional damage: **0**

#### Implementation notes

- The Fruit should gain a visible bruised/juicy state while the effect is active.
- Juicy trail Green is ordinary Fruit-created Green and may interact with normal territory systems.
- Newton's Apple secondary impacts do not refresh Bruised Fruit.

---

## Uncommon

### Bank Shot

**Player-facing description:** The first wall bounce keeps 90% speed and empowers the next enemy collision with 40% more damage and knockback.

**Trigger:** The first obstacle bounce made by a natural Fruit.

The bounce preserves substantially more momentum and empowers the next enemy collision.

#### Current implementation

- First-bounce velocity retention: **90%**
- Normal Fruit obstacle-bounce retention: **55%**
- Next qualifying enemy-collision damage multiplier: **1.40×**
- Next qualifying enemy-collision knockback multiplier: **1.40×**
- Empowered collisions per Fruit: **1**
- Later obstacle bounces use normal Fruit behavior.

#### Rank-0 reference

- Empowered collision damage: **50.4**
- Empowered knockback: **53.2 px**

#### Implementation notes

- The empowered collision is consumed by the next qualifying natural Fruit enemy hit.
- Bank Shot's empowered collision can trigger Stem Steering, Bruised Fruit, Fruit Salad, Windfall, and Newton's Apple if those relics are otherwise eligible.
- Dropped Seeds do not inherit Bank Shot.

---

### Fruit Salad

**Player-facing description:** Hit the same enemy with 2 different Fruit from one release to burst it for damage and a splash of Green.

**Trigger:** Two different natural Fruit from the same release hit the same enemy within a short window.

The second hit bursts the target in juice.

#### Current implementation

- Mark duration after first Fruit hit: **1.25s**
- Mark stores:
  - `release_id`
  - `fruit_id`
- A different Fruit with the same `release_id` must hit during the mark window.
- Burst radius: **65 px**
- Burst damage: **45% of the second Fruit's current collision damage**
- Rank-0 reference burst damage: **16.2**
- Burst knockback: **20 px**
- Green splat radius: **48 px**
- Green payload: **0.15× baseline Seed Growth Mass**
- Maximum Fruit Salad activations per enemy per natural release: **1**
- Elites and bosses can trigger Fruit Salad normally.

#### Recursion rules

Fruit Salad:
- does not count as a Fruit collision,
- cannot trigger Fruit Salad,
- does not receive Bank Shot's empowered collision modifier,
- cannot trigger Newton's Apple,
- may activate unrelated generic damage or kill relics.

---

## Rare

### Dropped Seed

**Player-facing description:** Every 3rd completed Fruit ejects a smaller rolling Seed that damages enemies and paints Green.

**Trigger:** Every third non-seed Fruit that completes its roll.

The completed Fruit ejects a smaller rolling Seed.

#### Current implementation

- Trigger cadence: every **3rd completed non-seed Fruit**
- Launch speed: **300 px/s**
- Roll distance multiplier: **60%**
- Rank-0 reference roll distance: **192 px**
- Collision damage multiplier: **65%**
- Rank-0 reference collision damage: **23.4**
- Terminal burst damage multiplier: **65%**
- Rank-0 reference terminal burst damage: up to **6.5**
- Germination area multiplier: **50%**
- Leaves its own Green trail
- Does not count as Fruit for Fruit relic triggers
- Cannot create another Dropped Seed
- Does not hold the normal Fruit release cooldown open

#### Implementation notes

Dropped Seed cannot trigger:

- Thick Rind
- Stem Steering
- Bruised Fruit
- Bank Shot
- Fruit Salad
- Windfall
- Newton's Apple

Dropped Seed may still activate unrelated generic damage, kill, or territory systems unless explicitly excluded.

---

### Windfall

**Player-facing description:** A Fruit collision kill restores 22% of launch speed and redirects toward another enemy. Up to 3 times per Fruit.

**Trigger:** A natural Fruit kills an enemy with a direct collision.

The Fruit regains speed and curves toward another enemy.

#### Current implementation

- Trigger: direct natural Fruit collision kill
- Speed restored: **22% of that Fruit's current initial launch speed**
- Rank-0 reference speed restoration: **66 px/s**
- Maximum resulting Fruit speed: **110% of current initial launch speed**
- Target acquisition radius from kill: **220 px**
- Maximum heading correction: **35 degrees**
- Steering interpolation duration: **0.10s**
- Maximum Windfall activations per Fruit: **3**
- Minimum time between Windfall activations: **0.12s**
- Prefer enemies not previously hit by that Fruit.
- Windfall does not reset Fruit traveled-distance accounting.
- Momentum still determines the underlying roll/deceleration budget.

#### Recursion rules

Windfall triggers only from direct natural Fruit collision kills.

Windfall does not trigger from:
- Fruit Salad,
- Dropped Seed,
- Newton's Apple Falling Body impacts,
- terminal Fruit burst,
- unrelated relic damage.

---

## Legendary

### Newton's Apple

**Player-facing description:** Each Fruit can launch up to 3 enemies into nearby enemies. A launched enemy deals damage on impact and can knock that victim into one final target.

Newton's Apple should look like enemies are becoming physical projectiles, but it must use a bounded, performance-safe implementation rather than unrestricted rigid-body crowd physics.

#### Current implementation

#### Chain starters

- Maximum Newton's Apple chain starters per natural Fruit: **3**
- Minimum time between starters from the same Fruit: **0.25s**
- Only direct natural Fruit enemy collisions can start a chain.
- All other Fruit collisions behave normally once that Fruit has used all 3 starters.
- A qualifying normal enemy hit by the Fruit becomes a **Falling Body** if the global Newton's Apple budget is available.

#### Falling Body generation 1

The enemy launched directly by the Fruit:

- receives the Fruit's normal authored knockback,
- Falling Body active window: **0.45s**,
- may resolve at most **1** Falling Body collision.

If it hits another eligible enemy:

- secondary damage: **55% of the source Fruit's current collision damage**
- rank-0 reference: **19.8 damage**
- secondary knockback: **65% of the source Fruit's current collision knockback**
- rank-0 reference: **24.7 px**
- the struck normal enemy becomes the final Falling Body generation if budget allows.

#### Falling Body generation 2

The enemy launched by the Generation-1 collision:

- may resolve at most **1** final Falling Body collision.

On that final collision:

- damage: **30% of the source Fruit's current collision damage**
- rank-0 reference: **10.8 damage**
- knockback: **40% of the source Fruit's current collision knockback**
- rank-0 reference: **15.2 px**
- the struck enemy does **not** become another Falling Body.

The chain ends after this collision.

#### Falling Body damage rules

- Falling Body collisions **deal damage**.
- Falling Body damage counts as **relic damage**.
- The launched enemy does not take extra self-damage merely for being used as the projectile unless normal game logic already causes such damage.
- Falling Body damage can kill enemies.
- Falling Body kills may activate generic enemy-death relics.
- Falling Body impacts do **not** count as Fruit collisions.

Therefore Newton's Apple secondary impacts cannot trigger:

- Thick Rind
- Stem Steering
- Bruised Fruit
- Bank Shot
- Fruit Salad
- Windfall
- another Newton's Apple chain

#### Target-class rules

**Normal enemies**
- can become Falling Bodies,
- can propagate from Generation 1 to Generation 2.

**Elites**
- can be struck by Falling Bodies,
- take **50%** of the normal Falling Body damage for that generation,
- receive **35%** of the normal Falling Body knockback for that generation,
- cannot become a new Falling Body.

**Bosses**
- can be struck by Falling Bodies,
- take **25%** of the normal Falling Body damage for that generation,
- receive **0 knockback**,
- cannot propagate the chain.

#### Global performance budget

These caps are absolute regardless of enemy count.

- Maximum active Falling Bodies globally: **6**
- Maximum propagation depth: **2 Falling Body generations**
- Maximum secondary Newton's Apple impacts globally: **8 per second**
- Maximum secondary Newton's Apple impacts resolved in one physics frame: **2**
- Maximum candidate enemies tested per Falling Body trajectory: **16**
- Maximum qualifying collision per Falling Body: **1**

If a direct Fruit hit occurs while no Newton's Apple budget is available:

- resolve the Fruit hit normally,
- do **not** create a Falling Body,
- do not queue the missed Newton's Apple starter for later.

#### Performance-safe collision implementation

Do **not** convert enemies into unrestricted `RigidBody2D` projectiles.

When a Falling Body state begins:

1. calculate its intended knockback trajectory;
2. build a swept AABB around that short trajectory;
3. query the existing bounded enemy spatial structure;
4. inspect at most **16 candidate enemies**;
5. choose the earliest valid trajectory intersection;
6. store that enemy as the predicted collision target;
7. animate the launched enemy through its ordinary knockback;
8. resolve the stored collision when the body visually reaches the contact point.

Do not continuously search all nearby enemies every frame while the body is flying.

For Generation 2:

- repeat the same one-shot predicted trajectory query,
- resolve at most one final collision,
- end the chain.

#### Dense-enemy behavior

Newton's Apple workload must remain bounded even in extreme crowds.

Example:

If six Fruit collectively hit **200 enemies**, the system does **not** produce 400 extra chain events.

At absolute maximum:

- each Fruit can start only **3** chains,
- only **6 Falling Bodies** can exist globally at once,
- only **8 secondary impacts per second** can resolve,
- only **2 secondary impacts** can resolve in one physics frame.

The remaining Fruit hits behave normally.

#### Visual presentation

Use pooled lightweight VFX only:

- brief impact dust or leaf burst,
- short hit reaction,
- optional squash/rotation while airborne,
- no unique particle system allocation per collision.

The visual goal is:

**Fruit hits enemy → enemy flies → crashes into another enemy → that enemy flies into one final target**

without turning the enemy crowd into a full rigid-body simulation.

---

# Fruit interaction examples

The intended Fruit relic engine is based on maintaining kinetic energy and converting collisions into further consequences:

**Fruit hits enemy → Stem Steering redirects**

while:

**Fruit hit → Bruised Fruit → wider Green trail**

and:

**wall bounce → Bank Shot → empowered collision**

with:

**two Fruit hit same enemy → Fruit Salad**

then:

**collision kill → Windfall → speed restored + redirect**

and finally:

**direct Fruit hit → Newton's Apple starter → Falling Body collision → one final Falling Body collision**

Fruit should feel like botanical bowling where the Fruit remain the primary simulated projectiles and enemies occasionally become short-lived, budgeted secondary projectiles.



# Relic VFX language

The relic system can become extremely dense late in Campaign. VFX should therefore prioritize **cause recognition** over raw particle count.

A player should be able to glance at a chain and understand which Adaptation or relic caused the next event.

## Global VFX rules

- Natural Adaptation events remain the visually strongest version of their effect.
- Relic-generated echoes should use the same visual family but at approximately **70 to 85% visual intensity**.
- Generated copies should never look stronger than the natural event that caused them.
- Prefer:
  - short shape changes,
  - directional trails,
  - ground pulses,
  - object deformation,
  - clear timing,
  - brief color/value shifts.
- Avoid solving readability by adding large particle emitters to every trigger.
- Reuse pooled particles, decals, impact sprites, and trails.
- Legendary activations should have a recognizable signature cue, but avoid long hit-stop, full-screen flashes, or repeated camera shake during chain-heavy moments.
- If several relic effects resolve within one frame, stagger their strongest visual accents by **0.04 to 0.08s** where gameplay timing permits.
- Use the mechanics-help color language and Path iconography when an effect would otherwise be ambiguous.

## Plant VFX notes

### Garden Hose
- Use five clearly separated spray streams rather than a fog cone.
- Streams should leave small wet/leafy impacts where Green is deposited.
- Keep the effect low to the ground so it does not obscure enemies.

### Mulch
- Heavily fed enemies gradually gain a visible dark-green/brown "stuffed with mulch" treatment.
- On death, the stored Green should burst outward from the corpse as soil and leaf fragments rather than looking like a generic heal.

### Compost Heap
- Heap visibly grows with each corpse contribution.
- At threshold, briefly swell before eruption so the player can anticipate the payoff.

### Man-Eater
- Mark grazers with a small tooth/leaf or closing-jaw motif.
- Maw eruption should be one strong bite animation rather than a persistent large VFX cloud.

### Grafting Tape
- When the paired Adaptation answers, briefly draw a thin graft/stitch visual between the source event and the echoed Adaptation icon or origin.
- Keep this subtle enough that the in-world echo remains the main event.

### Miracle-Gro
- When charged, give Grandma or the next eligible Adaptation origin a small swollen-bud indicator.
- The repeated event should look slightly oversized or leave a brief green afterimage.

### Hybrid Vigor
- Repeated relic effects should use a quick "double image" or ghosted after-effect.
- Do not duplicate the full Legendary activation flash every time Hybrid Vigor procs.

## Spore VFX notes

### Puffball
- Destroyed Seed pops into a soft radial puff before three Seedlings visibly arc away.
- Seedlings should be smaller and visually lighter than normal Seeds.

### Windborne
- Windborne Seeds should arc high enough to read as long-distance dispersal.
- Use a drifting spore trail rather than a projectile streak.

### Domino Germination
- Give each forced germination a brief connecting pulse through the ground or a traveling spore sparkle.
- Preserve the **0.16s** cadence visually so the cascade reads as a fuse moving through the colony instead of six simultaneous pops.

## Bloom VFX notes

### Chain Bloom
- Child Bloom bud should visibly plant before its **0.45s** wind-up.
- Use a smaller flower silhouette than a natural Bloom.

### Overkill
- A charged Overkill state can make the next natural Bloom bud appear swollen or double-layered.
- The 0.40s echo should read as a pressure aftershock, not a second full flower.

### Superbloom
- Use an overlapping petal-ring shockwave centered between the two qualifying Blooms.

### Flowering Front
- This should have the clearest propagation language in Bloom:
  - Bloom detonates,
  - a short root/petal streak races toward the next frontier point,
  - a new bud visibly rises,
  - next detonation follows.
- Each later generation may be slightly smaller/dimmer according to its strength multiplier.

## Bramble VFX notes

### Hookthorn
- On enemy-to-enemy collision, briefly stretch a thorny strand between the two bodies before it snaps.

### Cocklebur
- Burr-covered enemies should visibly carry a few thorn clusters so the player can identify them outside Green.

### Briar Knot
- Keep the trap low and compact until triggered.
- Trigger should use one sharp yank line rather than an area explosion.

### Briarball
- Visually read as a rolling tumbleweed of thorns.
- Rotation speed should correlate with movement speed.

### The Hedge
- Briar Sweep should travel visibly through connected Green as a moving ridge of thorns.
- Do not apply the whole-map visual in one frame.

## Root VFX notes

### Rootbound
- Charged Grandma carries a small root-hair halo around her feet.
- Discharge should look like roots rapidly threading into younger Green.

### Feeder Roots
- Pulse should visibly travel through owned Green toward the target instead of teleporting.

### Taproot, Annual Rings, World Tree
- Their world objects should share an "ancient growth" visual family.
- Because they now spawn near Grandma's oldest nearby territory, keep them readable enough to become recognizable landmarks.

### Graft Union
- Reconnection should send two pulses away from the graft point, one into each previously separated component.
- The eventual 50% echo should briefly flash the graft point first.

### Rhizome
- The connecting root should visibly grow along the actual routed path over **1.20s**.
- Avoid a simple instant line draw.

### World Tree
- When charged, show a subtle pulse in the trunk/canopy.
- On echo, send a root-light pulse from the Tree toward the echoed event origin.

## Pruning VFX notes

### Skimming Cut
- Ricochet should visibly spark or chip against basalt before changing direction.

### Callus
- Reclamation pulse should look like wound tissue knitting closed rather than a generic Green explosion.

### Brush Pile
- Stored Brush bundles should be visible as extra clippings orbiting or collecting near the held ring.
- Bonus volley should have a slightly rougher, messier trajectory than the primary ring.

### Stubble
- Keep hazardous Pruned Ground readable through short cut stalks or pale sharp remnants.
- Avoid tall visuals that hide enemies.

### Return Stroke
- Returning ring should use the same Cutting geometry with a thinner or slightly dimmer trail.

### Watersprouts
- Child Cuttings should visibly branch from the corpse with a twig-splitting motion.
- Generation 2 should be slightly smaller/dimmer than Generation 1.

## Thistle VFX notes

### Thorn Relay
- Use a very fast network ping between the triggering impact and the responding Thistle.
- The ping should be thin and disappear before the bonus thorn fires.

### Pincushion
- Embedded thorns should visibly accumulate in the enemy as stacks rise.
- On death, stored thorns visibly pull free before launching.

### Answering Thorn
- Responding Thistle briefly nods or flexes toward the source turret before firing.

### Phyllotaxis
- Spiral thorns need a clearly different radial geometry from ordinary clustered shots.

### Forking Pattern
- Triggering thorn should split with a sharp angular crack, not a soft particle burst.

### Crown of Thorns
- All Thistles briefly brighten or raise their seedheads together before the synchronized volley.
- Keep the pre-fire cue extremely short so it reads as coordination rather than a charge-up attack.

## Vine VFX notes

Vine already has a dedicated persistent guided-whip physics specification earlier in this document.

Additional relic language:

### Apical hit
- Use a short, sharp tip flash and crack sound at the actual physical tip contact.
- Avoid highlighting the entire Vine.

### Whiplash
- Continue the existing physical tip trajectory beyond the successful Apical hit.
- Do not spawn a detached second Vine.

### Climber
- Wrapped Vine should visibly tension around the obstacle before the cinch.

### Girdling
- Target receives a visible tightening vine band or bark-pressure mark.
- Consumption should use one quick constriction snap.

### Twining
- Repeat uses the same persistent Vine body.
- A faint after-trail can distinguish the repeated stroke without duplicating the Vine sprite.

### Liana
- Build a subtle tip-brightness cue over the three successful Apical sweeps.
- During the cascade, use the actual continuously simulated Vine with stronger motion trails rather than four extra Vine objects.

## Fruit VFX notes

### Bruised Fruit
- Fruit should visibly darken or bruise after collision.
- Juicy state leaves thicker splat marks along the next 72 px.

### Bank Shot
- First empowered bounce gets one sharp impact star and a brief squash.
- Armed Fruit can show a small glint until its empowered enemy hit is consumed.

### Fruit Salad
- Use a compact juice burst centered on the target, with a clear Green splat on the ground.

### Windfall
- On kill, Fruit briefly squashes, snaps toward the new heading, and regains a short motion streak.

### Newton's Apple
- Falling Bodies should use:
  - short leaf/juice motion streaks,
  - a slight airborne rotation,
  - one pooled impact burst when they hit.
- Do not add independent physics debris for each launched enemy.
- Generation 2 can use a slightly dimmer trail so the chain depth is readable.

---

# Relic performance budgets

The purpose of these budgets is to guarantee that relic spectacle remains bounded even when late Campaign has around 100 or more enemies on screen.

Relic effects may be visually chaotic. Their worst-case CPU and object counts should not be.

## Global generated-event scheduler

Initial implementation target:

- Maximum relic-generated secondary combat events resolved in one physics frame: **12**
- Maximum queued secondary events: **48**
- Events beyond the per-frame budget are staggered into later physics frames in **0.04 to 0.05s** increments where their individual relic rules permit.
- Never delay direct player inputs or natural Adaptation attacks to satisfy this scheduler.
- Do not allocate a new container or event object for every trigger. Use pooled or compact reusable event records.
- If the 48-event queue is full, preserve higher-rarity and player-visible chain events first:
  1. Legendary
  2. Rare
  3. Uncommon
  4. Common
- A dropped secondary event must never corrupt a relic's counter or leave a permanent object in an invalid state.

This global scheduler is a safety net. Individual relic caps remain authoritative.

## Legendary hard budgets

| Legendary | Hard budget |
|---|---|
| **Hybrid Vigor** | Max **4 repeats per rolling 1.0s**; a repeat cannot roll Hybrid Vigor again |
| **Domino Germination** | Max **6 forced germinations per cascade**; max **1 queued cascade** |
| **Flowering Front** | Max **1 active chain**, **4 Child Bloom generations**, and global Bloom cap of **8 relic-generated buds** |
| **The Hedge** | One traveling Sweep; **10s cooldown**; no independent per-enemy spawned objects |
| **World Tree** | One echo per **6s charge**; one charged event at a time |
| **Watersprouts** | Max **16 child Cuttings per natural release**, **2 generations**, max **8 child spawns in one frame** |
| **Crown of Thorns** | One synchronized volley per trigger, **7s cooldown**; turret count already bounded by Thistle cap |
| **Liana** | Exactly **4 bonus sweeps**, max **1 active cascade**, no queued second cascade |
| **Newton's Apple** | Max **3 starters per Fruit**, **6 active Falling Bodies**, **8 secondary impacts/s**, **2 impacts/frame**, **16 trajectory candidates**, **2 generations** |

## Secondary hot-path caps

| Relic/system | Budget |
|---|---|
| **Man-Eater** | **0.75s** global eruption cooldown and max **1 queued Maw** |
| **Compost Heap** | Max **8 active heaps** |
| **Windborne** | Max **12 active Windborne-created Seeds** |
| **Volunteer** | Max **6 active Volunteer-created Seeds** |
| **Bloom generated events** | Max **4 Bloom detonations resolved in one rendered frame**; stagger extras |
| **Briar Knot** | Max **6 active Knots** |
| **Briarball** | Max **2 active Briarballs** |
| **Stubble** | Max **2 simultaneous Stubble wounds** |
| **Forking Pattern** | Max **8 active forked thorns** and **1 trigger per 0.75s** |
| **Thorn Relay** | Max **2 activations per second** |
| **Runner** | Max **3 active Runners** |
| **Vine physics** | Approx. **9 to 18 points**, **4 solver iterations**, max **3 emergency substeps** |
| **Fruit Salad** | One burst per enemy per release |
| **Windfall** | Max **3 activations per Fruit** |

## Performance validation scenarios

At minimum, run the relic stress probe against:

1. **100 tightly bunched enemies**
2. Maximum projectile-density Thistle build with Crown + Forking Pattern + Phyllotaxis
3. Spore build with Domino + Windborne + Volunteer
4. Bloom build with Flowering Front + Chain Bloom + Superbloom
5. Pruning release with 16 natural Cuttings + full Watersprouts cap + Return Stroke
6. Persistent max-length Vine during Liana while wrapped around basalt
7. Six-Fruit release with Windfall + Newton's Apple inside a 100-enemy cluster
8. Cross-pool Plant Legendary test with Hybrid Vigor duplicating a high-load Rare effect

Record:

- average frame time,
- p95,
- p99,
- peak frame time,
- active enemies,
- active projectiles/effects,
- relic-generated event queue depth,
- skipped or staggered secondary events.

Target remains a **16.67ms 60 FPS frame budget** under authored stress fixtures.

---

# Final redundancy and balance matrix

This matrix is not a demand for equal role coverage. Each Adaptation should remain biased toward its fantasy. It is a final check for accidental sameness and missing identity.

Legend:

- **High:** a major part of the pool
- **Medium:** meaningfully represented
- **Low:** present but secondary
- **None:** intentionally absent

| Pool | Offense | Territory | Defense | Control | Propagation | Positioning | Recovery | Cross-system | Identity check |
|---|---|---|---|---|---|---|---|---|---|
| **Plant** | Medium | High | Medium | Medium | High | Medium | High | High | Shared glue between otherwise separate systems |
| **Spore** | Medium | High | Low | Low | High | Medium | Low | Medium | Seeds create, survive, and accelerate more Seeds |
| **Bloom** | High | Medium | Low | Medium | High | Low | None | Medium | One lethal Bloom turns into additional Bloom events |
| **Bramble** | Medium | None | High | High | High | Medium | None | Low | Crowd control recursively creates more crowd control |
| **Root** | None | High | High | Low | Medium | Medium | High | High | Mature territory acts as one transmitting organism |
| **Pruning** | High | Medium | Low | Low | High | Medium | High | Low | One harvested release branches into more cuts, then heals its wound |
| **Thistle** | High | None | Low | Low | High | Medium | None | Low | A distributed turret network passes firing events around |
| **Vine** | High | None | Low | Medium | High | High | None | Low | Precision and geometry ignite repeated physical lashes |
| **Fruit** | High | Medium | Low | High | High | High | None | Low | Kinetic energy propagates through rolls, steering, and collisions |

## Redundancy watch list

No relic is removed by this review. These are the combinations to watch first in playtesting.

### Plant: event-repeat density

Potential overlap:
- Grafting Tape
- Miracle-Gro
- Hybrid Vigor

All three create additional events, but their triggers are intentionally different:

- Grafting Tape links the two primary Adaptations.
- Miracle-Gro converts territory creation into one stored repeat.
- Hybrid Vigor probabilistically repeats relic effects.

**Watch for:** Plant relic offers feeling like three variations of "do it again."

If this happens, Plant is the first pool where one repeat relic should be replaced.

### Spore: Seed-generation density

Potential overlap:
- Puffball
- Windborne
- Volunteer

They create Seeds from different situations:

- failed Seed,
- repeated germination,
- enemy death on fresh Seed Green.

**Current verdict:** acceptable and strongly on-theme.

**Watch for:** active Seed counts becoming the true limiting factor rather than interesting trigger conditions.

### Bloom: additional-Bloom density

Potential overlap:
- Chain Bloom
- Perennial
- Flowering Front
- Superbloom as a secondary wave

**Current verdict:** intentional. Bloom's relic identity is propagation through explosions.

**Watch for:** generated Blooms becoming visually indistinguishable.

VFX source language and source tags are mandatory here.

### Bramble: Entanglement application density

Many relics add or spread Entanglement.

**Current verdict:** intentional. Bramble's engine is Entanglement feedback.

**Watch for:** full Entanglement becoming so automatic that player positioning and Green ownership stop mattering.

### Root: maturation acceleration density

Potential overlap:
- Rootbound
- Feeder Roots
- Graft Union
- Rhizome endpoint pulses

**Current verdict:** acceptable because each rewards a different network behavior.

**Watch for:** stacking several Root relics causing the entire map to remain effectively Mature with no meaningful frontier.

### Pruning: secondary-release density

Potential overlap:
- Brush Pile
- Return Stroke
- Watersprouts

They differ in source:
- risky extra harvesting,
- automatic return pass,
- kill-triggered branching.

**Current verdict:** acceptable.

**Watch for:** late Pruning turning into generic projectile spam instead of one readable harvested ring.

### Thistle: extra-fire density

Potential overlap:
- Thorn Relay
- Answering Thorn
- Phyllotaxis
- Forking Pattern
- Crown of Thorns

**Current verdict:** the heaviest intentional concentration in any pool.

This is acceptable only if each event has a distinct visual rhythm:
- relay ping,
- answering volley,
- spiral,
- split,
- synchronized Crown.

**Watch for:** the player losing the ability to tell a normal Thistle firing cycle from relic-generated fire.

### Vine: extra-lash density

Potential overlap:
- Whiplash
- Runner
- Twining
- Liana

**Current verdict:** acceptable because the persistent physics Vine makes their geometry visibly different.

**Watch for:** Liana + Twining + Recurve making the natural alternating cadence unreadable.

Do not solve this by resetting Vine physics between attacks.

### Fruit: paired functional overlap

Potential overlap:
- Thick Rind and Bank Shot both preserve momentum
- Stem Steering and Windfall both redirect Fruit

Their triggers differ:

- Thick Rind rewards first enemy contact.
- Bank Shot rewards terrain use.
- Stem Steering rewards any collision.
- Windfall rewards kills.

**Current verdict:** acceptable.

**Watch for:** Thick Rind + Bank Shot making Momentum upgrades feel unnecessary, or Stem Steering + Windfall making Fruit pathing feel fully homing rather than physical.

## Final balance conclusion

The pools are intentionally asymmetric.

The clearest identities are:

- **Spore:** propagation through germination
- **Bloom:** propagation through explosions
- **Bramble:** propagation through control
- **Root:** propagation through territory/network state
- **Pruning:** propagation through a harvested release
- **Thistle:** propagation through distributed firing
- **Vine:** propagation through precision and physical lash geometry
- **Fruit:** propagation through kinetic collisions
- **Plant:** cross-system glue

The strongest redundancy watch items are:

1. Plant's three repeat-style relics
2. Bloom's multiple additional-Bloom effects
3. Thistle's extra-fire density
4. Vine's extra-lash density

These should be the first four areas tested for readability and sameness before replacing any relic mechanically.


# Current Relic Count

| Pool | Common | Uncommon | Rare | Legendary | Total |
|---|---:|---:|---:|---:|---:|
| Plant | 3 | 2 | 2 | 1 | 8 |
| Spore | 3 | 2 | 2 | 1 | 8 |
| Bloom | 3 | 2 | 2 | 1 | 8 |
| Bramble | 3 | 2 | 2 | 1 | 8 |
| Root | 3 | 2 | 2 | 1 | 8 |
| Pruning | 3 | 2 | 2 | 1 | 8 |
| Thistle | 3 | 2 | 2 | 1 | 8 |
| Vine | 3 | 2 | 2 | 1 | 8 |
| Fruit | 3 | 2 | 2 | 1 | 8 |
| **Current total** | **27** | **18** | **18** | **9** | **72** |

## Remaining Adaptation pools

All eight Adaptation relic pools are currently specified.
