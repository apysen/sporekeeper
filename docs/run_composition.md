# The Sporekeeper run scene

Sporekeeper is the first complete playable survival loop from the Territory
Survivor GDD. Launching the project now opens
`scenes/run/run.tscn`; the Phase A territory lab remains intact at
`scenes/run/territory_prototype.tscn` for focused field comparisons.

## Controls

- Move with WASD or the arrow keys.
- Cane automatically sweeps the 90° sector Grandma faces. Selecting Vine turns the
  stroke green and auto-aims each sweep into the valid sector containing the most enemies.
- Spend earned Biomass with the five buttons in the right-hand panel.
- Commit to a primary Plant path at 00:45 and a different secondary path at
  03:00, or claim either earlier by taking an upgrade from that path; each path
  offer pauses the field.
- Choose an eligible upgrade or relic when the run pauses for a draft. Each run
  carries three rerolls that redraw an upgrade offer without spending a level.
- Press R to restart the run.
- Prototype debug controls: F6 advances the timeline by two minutes, F7 grants
  enough XP for the next draft, F8 completes the selected path pair's evolution
  prerequisites so the next draft offers it, F9 spawns the boss, and F10 puts a
  relic reward on the table.

## Editing gameplay in Godot

Open `scenes/run/run.tscn` and select a component in the Scene
dock. Gameplay values are grouped on the node that consumes them, so the
Inspector is the main balancing surface; there is no shared Sporekeeper tuning file
whose fields silently belong to unrelated systems.

```text
RunRoot
├── GameplayComponents
│   ├── AudioSettings
│   ├── Progression
│   ├── Metabolism
│   └── WaveDirector
├── Paths
│   ├── SporeDirector
│   ├── BloomDirector
│   ├── BrambleDirector
│   ├── RootDirector
│   ├── ManEater
│   └── PruningDirector
├── TerritoryField
├── CombatDirector
│   └── EnemyProfiles      (scenes/enemies/enemy_profiles.tscn)
│       ├── Hunter
│       ├── Grazer
│       ├── Saboteur
│       ├── Corruptor
│       ├── Colonizer
│       ├── Warden
│       ├── ColonyCore
│       ├── EliteRootbreaker
│       └── BurrowerBoss
├── Player
├── RunAudio               (scenes/run/run_audio.tscn)
└── Interface
    ├── SidePanel
    │   ├── SlotMachinePanel   (scenes/ui/hud/slot_machine_panel.tscn)
    │   └── AdaptationTree     (scenes/ui/hud/adaptation_tree.tscn)
    ├── RelicTray          (scenes/ui/hud/relic_tray.tscn)
    ├── ChoicePanel        (scenes/ui/drafts/choice_panel.tscn)
    ├── ResultPanel
    └── PauseMenu          (scenes/ui/menus/pause_menu.tscn)
```

Sub-scenes are listed with the file they are instanced from. Open that file to
edit their contents; the run scene only decides where they sit and what they are
wired to. Each owns its own presentation and reports what happened as typed
signals, rather than letting the run root reach into its children:

| Sub-scene | Owns | Reports |
| --- | --- | --- |
| `PauseMenu` | Pause panel, settings page, volume and fullscreen controls, dev-control card | `opened`, `closed`, `settings_toggled`, `glossary_requested`, `main_menu_requested`, `quit_requested` |
| `SlotMachinePanel` | Reels and their near-miss rewind, the lever, the wager notch, the odds readout, pair-focus scaling | `spin_started`, `spin_refused`, `cinematic_started`, `cinematic_ended` |
| `AdaptationTree` | The two Core rows, the Evolution between them, and the two Branch rows | `slot_hovered` |
| `RelicTray` | The fixed heading and the relic row, including the empty socket that names the next reward | `slot_hovered` |
| `ChoicePanel` | A heading, four cards and a reroll - and nothing about what a card means | `option_chosen`, `reroll_requested`, `option_hovered` |
| `EnemyProfiles` | The authored enemy roster, one child per archetype | nothing; `CombatDirector` reads it |
| `RunAudio` | The ambient theme and the three Clover voices | nothing; callers ask it to play |

Every interface region of the run scene is now a sub-scene. The Adaptation rows
went last but one, and only after the upgrade-description logic they draw with had
moved to `src/core/rules/progression/upgrade_descriptions.gd` - extracting the
scene first would have given it nothing to draw with except a call back into the
run root, which is the coupling inverted rather than removed. The rules move first.

Both slot rows report a hover rather than showing one. The tooltip stack they
would draw into is shared with the reward hovers that belong to neither of them,
so `RunRoot._show_slot_tooltip` owns it and each row only says what was hovered
and where. The wording each row prints comes from `UpgradeDescriptions`, which the
run root and the rows each hold, so neither reaches through the other for a string.

The principal editing surfaces are:

| Select this node | Adjust these Inspector groups |
| --- | --- |
| `Player` | Health, movement speed and radius, Green healing rate and maturity threshold |
| `CombatDirector` | Cane sweep damage/cadence/reach/sector targeting, Bramble flat and max-health thorn chip damage, Entanglement, Ensnare and Repulsion, Old Growth, Briar Pod/Trap pools, combat audio, hit feedback, pool limits, and shared navigation clearance |
| Any node under `EnemyProfiles` | Health, speed, contact damage, XP, size, target priority, movement and territory behaviors, action cadence/strength, grazing burst and recovery window, catalyst sensing, preferred range, and Colony Core limits |
| `WaveDirector` | Run and path-choice milestones, Final Stand naming, wave/grace cadence, spawn rate, Grazer pack cycle and surge waves, specialist introduction times/cycles, per-wave XP/territory growth, and end-of-run enemy scaling |
| `BrambleDirector` | Bramble's base resistance, Entanglement slow and potency, Ensnare rate, Grasping Thorns duration and immunity, and Repulsion distance |
| `RootDirector` | Maturation rate, Biomass yield, Mature resistance and regrowth, and the Root Network amplification every other path reads |
| `ManEater` | Hunger per enemy-second and its threshold, the telegraph, jaw radius, Bite damage and the elite and boss shares, and the Green the meal comes back as |
| `SporeDirector` | Seed durability, kills per Seed, Briar Pods and Tangleburst, and the Seed Bank's storage, threshold, spread, and Mast Year delay |
| `BloomDirector` | Bloom timing, telegraph, damage and durability, Super Bloom chain depth and cascade, Flowering Season charge and Echo Blooms, and Thornburst harvest yield and Briar Trap strength |
| `AdaptationDirector` | Thistle turret/thorn pools, Vine pair triggers, Fruit velocity/trails/terminal bursts, and all new Evolution/relic runtime rules |
| `Progression` | XP curve, rerolls, eight-path eligibility, ordinary/Evolution rank ceilings, Biomass economy, and relic effects |
| `Metabolism` | Level costs and their growth, when Pressure and Cohesion unlock, the material a purchase injects, Breakthrough interval and effects, Overgrow's share and cooldown, and the production milestones |
| `AudioSettings` | SFX/Music buses and the linear output represented by 100% on each pause-menu slider |
| `Interface/PauseMenu` | Pause and settings wording, the fullscreen and unavailable-volume alternates, and the controller stick deadzone that shows the focus ring |
| `TerritoryField` | Expand its `Tuning` resource to adjust authoritative field simulation, Seed/Bloom shapes, maturation, Age, territory resistance, and the Bramble hedge development curve |

Enemy profiles are copied into an enemy when it spawns. Editing a profile
therefore affects future spawns and does not retroactively rewrite enemies that
are already alive. This makes mid-run Inspector experimentation predictable.
The profile's `Role` identifies which slot it belongs to; change actual
territory behavior with the separate `Territory Behavior` dropdown.

## Implemented run

The run lasts twelve minutes. Hunters pressure player HP and Grazers erode Green
territory from the opening wave. Saboteurs enter the mix at 01:15, the elite
arrives at 02:30, Corruptors begin at 03:00, Colonizers at 04:45, the Burrower
boss at 06:00, and Wardens at 07:00. The final invasion begins at 10:00 and
reinforcements stop at 11:30. The clock running out at 12:00 does not win the run
by itself: it retires the timeline and the run enters a Final Stand, where nothing
more spawns and victory waits until the last hostile still on the field is
cleared. The HUD swaps its countdown for CLEAR THE FIELD and names the era FINAL
STAND, leaving the survivor count as the objective. Every defeat condition still
applies during it, so a run can still be lost after the clock is spent. Losing all
player HP ends the run immediately; losing all Green territory starts a
six-second recovery grace period.

The timeline is divided into sixty-second pressure waves. Enemies snapshot the
current wave when they spawn: territory-retaking attacks gain 10% strength per
completed wave, and XP rewards gain 10% proportionally with a guaranteed
minimum increase of one XP per completed wave. The numbered wave is shown in
the run HUD alongside the named era. Wave 1 begins immediately. The first five
seconds of Wave 2 and every later wave are a visible grace countdown: existing
enemies remain active, but regular reinforcements and scheduled elite or boss
arrivals wait until the countdown ends.

Grazers lead roughly a quarter of regular reinforcement packs rather than the
whole late run. Every fourth wave is instead an announced GRAZER SURGE that
names itself in the run HUD, so heavy territorial pressure arrives as a
deliberate test of the frontier. A Grazer also grazes in bursts and then pauses
to recover, which opens windows for the frontier to grow back.

Each core role has its GDD-defined job. Saboteurs use obstacle-aware navigation
to hunt charging Seeds and Blooms, then fall back to eroding Fresh Green.
Corruptors turn Green control into hostile material. Colonizers avoid close
combat and establish destructible, stationary Colony Cores; each Core grows
hostile territory until destroyed. Wardens project a visible zone that suppresses
Green maturity without directly damaging player control. Their profiles and
introduction cadences are independent Inspector-editable values.

Root is the scaling and ecosystem-amplification path. Its territory ages
faster, settled Green resists erosion harder and regrows the damage it keeps,
and Mature area pays more Biomass. Its real payload is the Root Network: any
Plant mechanic that operates out of Mature ground runs stronger. Seeds
germinating from Mature Green carry more mass, Blooms opening on it push
harder, and thorns growing in it bite harder and ensnare faster. Root has no
new entity of its own; it makes the run's other path better the longer the
ecosystem lives.

The two paths inherit those identities. Spore is about enemies dying and new
growth appearing where they fell, so its lines raise Seed production and growth
mass. Bloom is about the existing ecosystem erupting outward, so its lines raise
Bloom frequency and force.

Enemy deaths drop magnetic XP. Level-ups pause the simulation and offer up to
three eligible choices. Cane has no upgrade lines. Each of the eight Paths—Spore,
Bloom, Bramble, Root, Pruning, Thistle, Vine, and Fruit—owns four five-rank lines.
While either Path slot is open, drafts spread offers across all enabled Paths; taking
a line from an uncommitted Path fills the next slot immediately. Once both slots are
committed, drafts narrow to those Paths until the Evolution opens a tertiary support
slot. Already-maxed lines remain excluded, and the Evolution grants two additional
line slots when claimed.

The primary-path milestone offers all eight implemented paths. The later
secondary milestone offers only the remaining paths, permanently locking a
two-path run. Maxing one line associated with each selected path marks its pair
Evolution Ready, and the evolution is then offered directly in the level-up
draft. It holds one of the three slots until it is taken, survives a reroll, and
disappears once claimed, so a completed pairing can never be missed or drafted
away. Defeating the boss pays out a relic like the elite does.

Seeds and Blooms do opposite jobs. A **Seed colonises**: every configured number
of non-chain kills plants one at the death site, it charges long enough to be
destroyed by a Saboteur, and it then establishes dense Green growth even on
ground the player does not hold, which makes it the tool for filling holes,
taking footholds, and creating disconnected territory. A **Bloom displaces**: it
triggers periodically from the player's own border, roots on the frontier cell
facing the nearest threat, charges briefly, and bursts outward with pressure and
mass that only land where Plant material already stands nearby. A Bloom detached
from Plant territory does nothing, so it advances and deforms an existing
frontier rather than claiming new ground. Charging Seeds
and Blooms have Inspector-tuned durability and show damage feedback while a
Saboteur attacks them. Seed/Bloom effects, enemy radial damage, hostile growth,
and Warden suppression all respect basalt wall occlusion.

Super Bloom makes each germinating Seed arm a Bloom. Kills from that detonation
can create a reduced-rate secondary Seed. Chain depth is capped at two so the
effect can cascade without becoming an infinite same-frame loop.

Bramble makes the territory itself hazardous. Every cell of owned Green the
field reports as claimed damages enemies standing on it, so the path does not
depend on frontier geometry at all: holes opening and closing, a border pushed
back and forth by Blooms, a ring of Green around an interior hole, and a
Grazer chewing a channel all leave the hazard intact. Coverage is presence,
never strength, so no arrangement of Green can multiply a single enemy's
exposure.

The hazard is deliberately weak on contact, because a developed run can cover
most of the arena with it. What makes it lethal is **Entanglement**: an enemy
standing on Green accumulates a 0-to-1 Entanglement value that raises both its
thorn damage, up to an authored multiple of the base tick, and the movement
slow it suffers. Entanglement decays off Green rather than resetting, so
briefly stepping out does not shake it loose. A fast enemy therefore crosses
Green almost untouched, while a Grazer that settles into it, or a tanky enemy
that grinds forward through it, is progressively taken apart.

Bramble is a crowd-control path, not a passive damage path. Thorn damage is a
fixed chip effect with no upgrade line behind it: a small flat amount plus a
fraction of the target's maximum health, so it stays relevant against late-game
health pools without ever becoming the reason enemies die. An enemy crossing the
starting Green island leaves with most of its health at every level of
investment; one that camps in Green is worn down slowly. All four Bramble lines
buy control instead. Entanglement raises the maximum slow, Entanglement Rate builds
Entanglement faster, Grasping Thorns pins enemies that reach full Entanglement,
and Repulsion shoves attackers off the territory they are eating. Bramble grows
stronger because Green covers more of the arena, because enemies spend longer
inside it, and because its Evolutions convert that control into damage.

A tick is resolved once per enemy from its own Entanglement, and is never divided
among the enemies sharing a stretch of Green. A crowded section also gains a
capped local horde bonus.

Reaching full Entanglement triggers Grasping Thorns: the enemy is **Ensnared** where
it stands, unable to move at all until the hold expires, and thorned runners burst
visibly beneath it. A held enemy is drawn with those runners clamped around its feet
under its own body, so the body stays readable, and with a ring that unwinds from a
full circle to nothing as the hold runs out, which reads as a timer on how long the
enemy has left to serve. An Ensnare outlives the ground that caused it, so an enemy
shoved or grown off the Green mid-hold still serves it out. Each enemy is then immune for a
spell, so a permanently Entangled enemy is held repeatedly rather than held
forever.

The frontier hedge is now a bonus layer on top of that coverage. Every frontier
cell still carries a 0-to-1 development value that climbs to full strength over
roughly four seconds, develops up to twice as fast on Mature Green, degrades in
bands under attack rather than being erased, thickens faster while a section is
under attack, and decays once the cell stops being a frontier. Standing in a
developed hedge adds thorn damage and builds Entanglement faster, and crossing
an established hedge deals a one-off hit on a per-enemy cooldown. Because the
hedge is only a bonus, thorns no longer need a dormant store or any frontier
memory: ground the border moves off simply loses the bonus and keeps the
Bramble. Basalt edges are excluded because only claimable non-Green ground
creates a hedge.

Enemies that weaken Green territory are repelled rather than hurt: a knockback
pulse shoves the attacker down the territory gradient, toward the nearest way out
of the Green, on a per-enemy cooldown so a rapidly grazing enemy cannot set off
dozens of pulses a second. Every way an enemy weakens Green counts, not erosion
alone: grazing and eruptions, Corruptor conversion and hostile spread, Warden
maturity suppression, a Colony Core planted in the territory, and a Saboteur
cutting down a catalyst standing on it. The attacker must be standing on Green
for the pulse to fire, so an enemy working ground the player does not hold is
left alone. The shove travels over its own window rather than teleporting: the
enemy slides out and eases to a stop, staggered so it cannot chase, act on
territory, or land contact damage until it lands. It advances in small steps that
stop against basalt, and Mature ground pushes harder through the Root Network. That is what makes Repulsion the Grazer's
problem specifically: it interrupts the grazing instead of adding a second damage
source. Developed thorns are also inherently harder to graze through, so a Grazer
chews Fresh ground quickly and slows markedly against an established hedge.

The Root Network erupting plays its own cue. A cascade can fire several eruptions
inside a single frame, so the cue is held behind a short retrigger guard and a
capped polyphony: a cascade swells once rather than stacking one voice per
eruption.

The shader reads the same authoritative values: a sparse thorn texture across
all owned Green for the hazard, and bare stems growing into sharp tips along the
frontier as development rises, without the shader deciding damage or resistance.

Root pairs into three more evolutions. Spore plus Root becomes Seed Bank, where
Mature borders periodically bank a Seed that inherits their maturity as extra
growth mass, with no enemy death required. Bloom plus Root becomes Flowering
Season, where Mature area charges a meter that spends itself on several
simultaneous Blooms and consumes maturity at each site, which Root then regrows.
Bramble plus Root becomes Old Growth, which wakes the ancient forest up.
Because Bramble already damages everything on Green, Old Growth goes further
than interior damage: an enemy that becomes heavily Entangled while standing on
Mature ground is seized by the Root Network, and roots and thorn spikes erupt
out of the ground to strike everything around it. Eruption damage sharpens with
that ground's Age, and a kill made by an eruption sets off another eruption
beneath the next enemy, so a mob wading into ancient territory cascades across
the network instead of dying one at a time.

Spore plus Bramble evolves into Briar Pods: germinating Seeds raise pooled,
temporary thorn perimeters with amplified contact effects. Bloom plus Bramble
evolves into Thornburst, which turns a Bloom into a minefield planter. A
detonating Bloom harvests the Bramble covering the ground it is claiming — the
area of Green it covers, plus whatever hedge development stood there — and
scatters that yield as Briar Traps through the newly claimed territory. Traps
arm in place, detonate when an enemy comes close, deal heavy area thorn damage,
apply Entanglement, and shove the border outward a little; each detonation also
lights the traps beside it after a short fuse, so a dense wave walking into a
freshly claimed field sets off a visible cascade. Traps rot away on a timer, so
the arena never fills with mines. Trap damage is authored on the evolution and
amplified by the maturity of the ground harvested rather than by any Bramble
line, Entanglement deepens the hold they apply, and Bloom Mass, Force, and
Frequency decide how wide, how forceful, and how often a trap field is sown.
This is where a Bramble run's control turns into damage. Spore plus Bloom
continues to evolve into Super Bloom.

Man-Eater is what Carnivory became. As a Path, Maws had to hold up an entire
twelve-minute build, which meant answering how many there are, how durable they
are, how they reposition, what happens when they are swarmed, and how four upgrade
lines and five Evolutions scale them. None of those questions made the fantasy
better, and the fantasy was only ever one moment: a giant plant erupts out of the
Green and eats a mob. So the Path is gone and the moment is a Legendary relic.

Enemies standing on Green build Hunger, one enemy-second each, capped per second
so a late horde stays readable. One enemy alone needs the whole threshold; five
need a fifth of it; an invasion sets it off almost as fast as it arrives. When
Hunger fills, the densest cluster standing on Green is chosen, the ground bulges
beneath it for about three quarters of a second - long enough to be a battlefield
event enemies can walk out of rather than invisible damage - and then the jaws
close on up to eight of them. Normal enemies are swallowed whole, elites take a
heavy share, and a boss is bitten but never eaten. What went down comes back up as
Green: the meal is spent as a Bloom command at the site, so enemies invade Green,
Green gets hungry, the Plant eats them, and the enemies become more Plant. Then it
retracts completely. There is no Maw HP, no Capacity, no Digestion, no Budding, and
nothing left standing for an enemy to kill before it does anything.


Pruning is the fifth Plant path and the only one that spends the resource the run
is trying to protect. There is no cycle timer and nothing to wait for: standing on
your own Green harvests it. The ground under the player is stripped continuously,
youngest first, so Fresh goes before Established and Mature only when nothing else
is left, and what it takes comes straight back up as Cuttings that spiral in and
take a place in a ring orbiting the player. Severed runners are strung between the
spikes, so the ring is a thicket rather than a hoop: it grinds everything inside the
circle it encloses, not only what crosses the rim. An enemy cannot slip between two
blades, and closing all the way to contact puts it in the middle of the thicket
rather than safely inside an empty ring. Each enemy carries its own cooldown, so it
grinds rather than deleting whatever brushes it.

Holding banks Charge, and Charge raises the ring's damage, its turn rate, and how
fast the harvest eats. The ecosystem pays for spikes rather than for time: while the
ring still has room the harvest runs hard, and once it is full it drops to a smaller
maintenance drain. On top of both, the drain climbs for every second the ring has
gone without firing, and that escalation does not cap. Charge alone caps after a few
seconds, which left a single patch of Green able to feed a ring indefinitely; the
escalation is what gives every hold an end regardless of how much ground it started
on. A held ring runs its own footing out in well under a minute. Reclamation is suppressed for as long as the
ring is turning, so the Green burned under the player stays burned and only starts
coming back the moment the ring fires. The harvest stops entirely below a floor
counted in cells rather than as a share of the arena, because a percentage floor
gates the path on a state runs rarely reach and switches it off for the whole run.

Stepping off your own Green, or running the ground out from under yourself, bursts
the hoop. Every spike keeps the heading it was already travelling on, so the ring
opens into an expanding wall of blades rather than sixteen spikes converging on
whichever enemy happened to be nearest. A discharged spike drives much further
through a crowd than a loose Cutting does, gaining pierce with Charge and keeping
most of its damage through each enemy it passes.

The discharge is the payout and is sized like it. It has to be, because it costs the
whole ring and roughly a quarter of the ecosystem to build another: a burst worth two
seconds of grinding would make firing a punishment and camping the correct play. At
full Charge a spike carries seven times its base damage through six enemies; at zero
Charge the same burst is modest, so a discharge you did not earn stays small. That
gradient is the decision the path is built around, and it is why cashing out early
against a swarm and holding for a boss are both real answers. Its four
lines are Harvest Rate, Cutting Yield, Cutting Edge, and Charge. Three of them buy
efficiency out of the same ground; Harvest Rate is the only one that spends more,
and it is priced as a trade, buying spikes per second and burn per second in the
same rank.

Pruning pairs into five Evolutions. Spore plus Pruning becomes Pioneer, seeding the
harvested ground as it is taken so it erupts in batches a moment later. It was called
Coppice, which was one letter from Root plus Pruning's Coppicing and named the wrong
thing besides: coppicing is regrowth from a cut stool, and this pairing regrows from
seed on disturbed ground, which is what a pioneer species does. Bloom plus Pruning
becomes Rebound, where a detonating Bloom collapses the Green around it inward and
converts that mass into Force rather than new Plant Mass, capped so the collapse
cannot compound. Bramble plus Pruning becomes Deadfall, turning the thorns torn out
with the Green into extra spikes. Root plus Pruning becomes Coppicing, paying out
far more Cuttings for ancient ground and driving the cut ground back much faster.

All ten pairings now carry an optional five-rank Evolution line: Pioneer takes Second
Flush, Rebound takes Compression, Deadfall takes Splinterstorm, and Coppicing takes
Stool Regrowth, alongside the six that already had one.

Biomass accrues from Green area and Mature Green area, and the side panel reads
it as a running economy: Reserve, Production, Consumption, and Net. Nothing is
purchased. The player distributes eight discrete allocation points across
Photosynthesis (Mass), Meristem (Pressure), and Cambium (Cohesion) - left click a
system to allocate a point, right click to take one back - and allocated points
draw Biomass out of the Reserve at a fixed rate per point. Each system's level
bar then fills itself on an exponential cost curve, so the real decision is
between cheaply developing a neglected system and paying heavily to specialise an
advanced one. Reallocating changes the future investment rate; levels already
earned are never refunded. An allocation the economy cannot yet pay for is not
blocked: it burns the Reserve and throttles back to whatever income covers, which
is what makes the Reserve a genuine buffer.

Every fifth level offers a Breakthrough through the same paused choice panel, and
a Breakthrough changes the simulation rather than a number. Photosynthesis
chooses between Rapid Cycling, which creates Mass continuously in small pulses,
and Storage Organs, which banks it and releases it in large ones so the Green
visibly breathes outward. Meristem chooses between Apical Dominance, which
concentrates Pressure into protrusions and tendrils, and Lateral Growth, which
spreads it across the whole frontier. Cambium chooses between Flexible Tissue,
which deforms heavily and rebounds, and Woody Tissue, which resists deformation
and then fails suddenly.

Overgrow is the one instant Biomass action. It spends half the Reserve and
converts it into an injection of Mass, Pressure, and Cohesion along the living
frontier, split in the proportions the run's own allocation is - it does not hand
out a predetermined slice of territory. What that becomes is whatever the
battlefield makes of it: open ground spreads broadly, a narrow passage funnels
the same budget into a jet, and a torn ecosystem spends it sealing itself instead.
Reaching a production milestone announces itself once, plays a cue, and grants a
small free pulse.

The relic catalog holds 44 entries across four pools, and a run only ever sees the
part of it the build can actually use. The planned 48 adds the four Clover relics
of the secret gambling Path, which the prototype does not implement yet.

Twelve Universal relics touch nothing element-specific: the Core Weapon, player
HP, kills, elites, waves, and territory loss. Six Plant Element relics work off
Green, baseline Seeds, and maturity. Each of the six Paths carries three - one
broadly useful mechanic changer, one build-shaper, and one Legendary fantasy
payoff - and eight curated synergy relics sit across mechanic pairs. The four
relics that predated this catalog (Volatile Germination, Thornwood, Fertile
Ground, Siege Thorns) have been retired along with their rules, so every pool now
matches its authored size.

Rewards are choose-one-of-three, weighted by rarity, and a relic can never be
offered twice or levelled. Each run also carries two relic rerolls, separate from
its upgrade rerolls, because an offer is now a sample of a large pool rather than
everything that is left.

Eligibility is decided by Mechanics rather than by path names. Seeds and Mature
Green are baseline, so relics keyed to them are live from the start; Entanglement
arrives with Bramble, Root Potency with Root, the ring and Charge with Pruning,
and so on. A synergy relic becomes offerable the moment the run
provides both mechanics it names, whether that came from the initial pair, the
support path taken after the Evolution, or an Evolution itself - so there is no
separate pool for any of those cases. Insurance Policy names a mechanic the
prototype does not have yet (optional objectives), so it is authored, never
offered, and turns on by itself the day that layer lands.

Relics that change a rule parameter are pushed straight into the component that
owns the rule: Predator's Eye, Follow Through, Adrenal Response, Blood in the
Water, Underdog and Deep Snare live inside combat's own Cane and contact
rules, Canopy lives on the player's damage rule, Regrowth is a field layer, and
Hard Husk is a property of every Seed the overlay makes. Everything with a
counter, a cooldown, a per-wave limit, or a persistent object is run by
`RelicDirector`, which draws its own world markers so a Taproot, a World Tree, a
Rampart, a Briar Sweep, and a marked Patient Zero or World Seed are all visible
and defensible.

Triggers are deliberately concrete. Overpopulation counts six kills in two
seconds; Compost counts twelve kills on Mature Green; Carrion Garden counts five
Maw kills; Predator's Eye counts ten volleys. Last Bastion and Resurrection Fern
watch for an absolute number of owned cells lost inside a short window rather
than a share of the arena, which is the standing rule after the Kudzu and timed
Pruning failures. Living Rampart and Underdog read local enemy density.

Every loop that could feed itself carries a limiter. An Overpopulation blast
cannot spend or advance the next Overpopulation charge, because relic damage
carries its own death source. Encore skips Legendary triggers entirely, its own
repeats never advance its counter, and it does not repeat relics that create
permanent objects. Cross-Pollination and Pollinator can only advance a Seed that
is off its receiving cooldown. A Feeding Ring free Bite is reduced and does not
reset normal Digestion. The Hedge, Superbloom, and the Shared Hunger relic each
hold a global cooldown, and Gleaning Hook caps what it can bank in one hold.

## Implementation and validation

The territory field remains a deterministic packed-array simulation. Combat
uses preallocated pools sized for 160 enemies, 96 generic secondary projectiles,
and 180 XP pickups, with at most 130 active enemies. Cane allocates no projectile;
Thistle and Fruit use their own bounded pools. Bloom, Seed, Fruit, and Fruitseed use
raster botanical art with shared watercolor granulation, while telegraphs and field
layers remain procedural at the 1280 by 720 reference viewport.

Run all headless behavior and performance checks with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1
```

The Sporekeeper smoke suite covers movement, automatic combat, XP drops, kill-to-
Seed conversion, hostile-area germination, automatic Bloom windups, two-path
selection and draft filtering, all four Bramble lines staying crowd control,
territory-wide thorn chip damage, Entanglement build and decay, hedge crossing
and Repulsion cooldowns, Grasping Thorns holds and their immunity window, the
Root Network, Briar Trap cascades, root eruptions, every Bramble
and Root pair evolution, upgrade and relic choices,
Biomass modifiers, Super Bloom propagation, wall-shadowed radial damage, every
specialist action, Colony Core placement and growth, specialist wave scheduling,
per-wave XP and territory-pressure scaling, five-second wave grace countdowns,
Inspector-authored enemy profiles, timeline milestones, victory, and HP defeat.
It also checks all eight slot faces and mappings, immediate Thistle/Vine/Fruit
jackpot events, Vine dense-sector targeting, per-Fruit trail painting and seeded art
variation, planted Fruit damage/cooldown order, tiled NinePatch button borders, and
the shared high-contrast botanical watercolor material.
The navigation probe also verifies that
Corruptors, Wardens, Colonizers, and catalyst-hunting Saboteurs route around
obstacles without corner stalls.
The stress probe exercises the full enemy cap, all twelve pooled Briar Pod
boundaries, and saturated projectile/XP pools against the 16.67 ms prototype
frame budget.

## Art status

The live scene uses supplied raster paintings for Seed, Bloom, six randomized Fruit
variants, and the Dropped Seed relic. They share
`assets/shaders/botanical_art_watercolor.gdshader` and the generated
`assets/art/shared/watercolor_granulation.png`, with intentionally strong pigment
pooling, paper lift, and translucent-edge breakup. Procedural fallbacks and the
remaining Gardener, enemy, projectile, pickup, and Bramble drawings can still be
replaced independently of authoritative gameplay.
The territory shader and arena mask should remain separate from decorative art
so appearance cannot change ownership or collision results.
