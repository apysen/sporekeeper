class_name PruningDirector
extends Node2D

## Pruning: stand in your own garden and burn it into blades.
## Territory is also the run's health, so this is the one path that spends the
## resource it is meant to protect.
##
## There is no cycle timer. Standing on your own Green harvests it continuously:
## the ground under you is stripped away and comes back up as Cuttings, which
## spiral in and orbit you. Holding the ring banks Charge, and Charge raises both
## how hard the ring grinds and how fast the harvest eats, so the longer you hold,
## the more dangerous the ring is and the faster your ecosystem disappears under
## your feet. Step off your Green, or run the ground out, and the whole ring fires
## outward at once with the Charge behind it.
##
## The Green a held ring eats does not reclaim itself while you are still holding:
## Pruned Ground only starts coming back once you let go. That is the sacrifice
## being real rather than cosmetic, and it is what makes this the glass cannon.

signal status_requested(message: String)
signal cycle_pruned(claimed_cells: int, cuttings: int)
## Captures the ring before reset for Deadheading, Espalier, and Graft.
signal ring_released(cuttings: int, charge: float, facing: Vector2, intentional: bool)

enum CuttingState {
	INACTIVE,
	GATHERING,
	ORBITING,
	LAUNCHED,
}

class Cutting:
	var state := CuttingState.INACTIVE
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var remaining := 0.0
	var gather_remaining := 0.0
	var damage := 0.0
	var pierce_remaining := 1
	## Damage kept after each enemy this Cutting passes through. A spike thrown by a
	## discharging hoop keeps far more of it than a loose one does.
	var pierce_falloff := 1.0
	var last_hit_enemy_id := -1
	var spin := 0.0
	## Return Stroke: how far this spike has travelled outward, and whether it has
	## turned around yet. A returning spike cannot bank Charge or fire release
	## relics again, so the stroke is a second pass rather than a second discharge.
	var travelled := 0.0
	var returning := false
	var maximum_travel := 0.0
	## Position in the ring, so the spikes stay evenly spaced as the count changes.
	var orbit_slot := 0
	## Thrown by a natural release rather than by a relic or an Evolution. Only these
	## may ricochet off terrain or sprout Watersprouts, so the flag travels with the
	## spike rather than being inferred later from how it happens to be moving.
	var natural_release := false
	## Skimming Cut is one ricochet per spike, ever.
	var has_ricocheted := false
	## 0 for a spike nothing sprouted, then 1 and 2 for the two Watersprout
	## generations. Generation 2 cannot reproduce.
	var sprout_generation := 0

@export_group("Collaborators")
## Evolutions component that owns the tuning for every Evolution this path takes
## part in. The behaviour stays here; the numbers live in one place.
@export var evolutions: Evolutions

## Authoritative field the harvest cuts from and the Pruned Ground belongs to.
@export var territory_field: TerritoryField
## Overlay used for the Seed visuals the Spore pairing germinates.
@export var overlay: TerritoryPrototypeOverlay
## Combat component supplying the player position and taking Cutting damage.
@export var combat: CombatDirector
## Progression component that supplies upgrade and evolution modifiers.
@export var progression: Progression
## Relic component consulted for the Pruning relics. Optional: without it the
## path behaves exactly as authored.
@export var relic_director: RelicDirector
## Root component supplying the Root Network amplification a cut reads. Optional:
## without it a Cutting is worth the same whatever age of Green it came out of.
@export var root_director: RootDirector

@export_group("Pruning Lines")
## Additive multiplier per Harvest Rate rank on how fast the ring strips the ground
## under the player. It buys spikes and it spends the ecosystem faster in the same
## breath, which is the honest version of a rate upgrade on this path.
@export_range(0.0, 2.0, 0.01) var pruning_harvest_rate_per_level := 0.18
## Additive multiplier on Cuttings raised from the same harvested ground, per rank.
@export_range(0.0, 2.0, 0.01) var pruning_cutting_yield_per_level := 0.22
## Additive damage multiplier per rank, applied to the orbiting ring and to what it
## launches alike.
@export_range(0.0, 2.0, 0.01) var pruning_cutting_damage_per_level := 0.30
## Additive multiplier per Charge rank on how fast Charge banks and how much the
## launch pays out for it.
@export_range(0.0, 2.0, 0.01) var pruning_charge_per_level := 0.22

@export_group("Harvest")
## Cells of Green per second the harvest strips at zero Charge while it is still
## raising spikes. There is no interval to wait out: the cost runs for exactly as
## long as the player stands on their own ground with a ring left to fill.
@export_range(0.0, 80.0, 0.5) var upkeep_cells_per_second := 9.0
## Cells per second at full Charge. The harvest accelerates faster than the ring's
## damage does, so filling a ring late in a hold costs much more ground.
@export_range(0.0, 200.0, 0.5) var upkeep_cells_per_second_at_charge := 18.0
## Cells per second a finished ring costs at the moment it fills. Filling is the
## expensive part, but a finished ring is never free.
@export_range(0.0, 40.0, 0.1) var maintenance_cells_per_second := 3.0
## Cells per second a finished ring costs at full Charge.
@export_range(0.0, 60.0, 0.1) var maintenance_cells_per_second_at_charge := 9.0
## Cells per second added for every second the ring has been held without firing.
## This is what stops a patch of Green feeding a ring forever: Charge caps out after
## a few seconds, so tying the whole cost to it left standing still sustainable. The
## escalation does not cap out, so every hold has an end.
@export_range(0.0, 8.0, 0.05) var upkeep_escalation_per_second := 0.80
## Ceiling on the escalating drain, so a very long hold ends quickly rather than
## deleting the whole ecosystem between two frames.
@export_range(1.0, 200.0, 1.0) var maximum_upkeep_cells_per_second := 60.0
## Arena pixels around the player the harvest eats from. Deliberately tight, so the
## hole opens under the player's feet where it can be seen.
@export_range(10.0, 240.0, 2.0) var upkeep_radius_pixels := 52.0
## Ground immediately under the player the harvest will not cut.
##
## Zero closed a loop that made the path impossible. The harvest is the only source of
## spikes; a Cutting can only join the ring if she has Green underfoot when it finishes
## gathering; and at zero the harvest took the cell she was standing on. So harvesting
## destroyed the condition for harvesting to produce anything, and she measured 55-60%
## of a bench off her own ground. The path stayed playable only because a Cutting with
## nowhere to go was launched at full damage -- which made running out of ground the
## optimal play, made the ring itself worth 0.01% of the damage, and made `Harvest Rate`
## measure *below* the bare Adaptation the moment that payout was taken away.
##
## A spared pad opens the loop without softening the cost. The harvest now works an
## annulus: she keeps her footing, so a Cutting she paid ground for actually becomes a
## spike. Standing still still ends the ring -- she strips the reachable ground, the
## harvest then finds nothing, and spikes wilt one at a time on
## `orbit_wilt_interval_seconds` until the ring has receded to nothing. The cost is the
## same cost, paid in a ring that shrinks rather than a ring that fires, and it is
## still only answered by walking onto fresh Green.
@export_range(0.0, 60.0, 0.5) var upkeep_inner_radius_pixels := 20.0
## Seconds the ring survives with no Green underfoot before it tears loose. She is
## now cutting the ground she stands on, so running dry is the normal end of every
## stationary moment rather than a mistake, and it has to leave enough time to walk
## to fresh Green. Too short and the path cannot be held while manoeuvring; too long
## and standing still costs nothing, which is the thing this is here to prevent.
@export_range(0.0, 4.0, 0.05) var footing_grace_seconds := 1.10
## How fast finding Green again pays the grace back, as a multiple of how fast being
## off it spends. Recovery drains the timer rather than clearing it, which is the
## whole mechanism: the cut leaves Pruned Ground that regrows under her within a
## second or two, and a timer that reset on a single frame of that regrowth let a
## player stand in one spot forever -- measured at 82% of the bench spent with no
## Green underfoot and the ring never once tearing loose. Draining means a flicker of
## regrowth is worth a flicker of grace, and only ground she has not already spent
## pays the debt off faster than standing still runs it up.
@export_range(0.5, 8.0, 0.1) var footing_recovery_rate := 1.50
## Share of the banked Charge payout a ring pays when it tears rather than when it is
## let go on purpose.
##
## The discharge is the path's payout and it is priced as a decision: hold the ring,
## bank the Charge, then step off your own Green and spend it. Cutting the ground out
## from under her made that decision fire itself -- the footing runs out every few
## seconds whether she meant it to or not -- and the bench found the result was not a
## ring build at all. With `orbit_contact_damage` set to 1.0, Pruning+Vine still did
## 93% of its damage: the orbiting ring is nearly irrelevant and the path is a Cutting
## cannon firing a free seven-times volley on a timer.
##
## So a tear is not a discharge. The spikes still fly, because a ring coming apart has
## to look like a ring coming apart, but the banked bonus is mostly not paid. The two
## are told apart by the ground she is standing on: Pruned Ground means she ground her
## own footing away, bare ground means she walked off her garden and meant it.
@export_range(0.0, 1.0, 0.05) var torn_ring_charge_share := 0.20
## Superseded, kept as the record of what was tried: a launch she did not choose used
## to pay this share of its damage. It is now worth nothing at all, because it does not
## happen -- a ring she did not spend is lost rather than fired. Left at its measured
## value so the reading below can be reproduced.
##
## Share of a Cutting's damage a launch she did not choose pays out.
##
## `torn_ring_charge_share` above is the first attempt at this and it attenuates the
## wrong term on the wrong event. Wrong term: it scales the banked Charge, and a ring
## that tore from starvation has no bank worth scaling -- against a boss the ring tears
## every 0.43s while Charge fills over about 4.8s at rank 3, so some 9% of it is banked
## when it goes, and sweeping the share across its whole range 0.00 to 1.00 moved a
## rooted row by 1.3%. Wrong event: the tear is not where the volley comes from.
##
## `_advance_gathering_cutting` is. A Cutting that finishes spiralling in while she has
## no Green underfoot has no ring to join, so it flies -- at full damage, without ever
## entering the ring, and therefore without passing the release at all. The harvest
## takes the cell she is standing on, so stripping her own footing is the *ordinary*
## state of a stationary hold: measured, she is off her ground 58% of a rooted bench.
## The positional cost is also the damage engine, and the engine pays full price.
##
## That is the whole path. Zeroing the aura cost a developed Pruning one point out of
## 7,595 against a boss; zeroing the Cuttings cost it 78%. It was never a ring build --
## it was a stream of free projectiles produced by running out of ground.
##
## So both routes that launch without being asked pay this share, and a deliberate
## discharge pays none of it: that one is a decision, costs the ring and a quarter of
## the ecosystem, and is still meant to be the largest number the path puts on screen.
## The spikes still fly either way, because a ring coming apart has to look like one.
@export_range(0.0, 1.0, 0.05) var unchosen_launch_damage_share := 0.30
## Cells of Green below which the harvest stops entirely. Counted in cells rather
## than as a share of the arena on purpose: a percentage floor gates the whole path
## on a state runs in this build rarely reach. What the floor is for is refusing to
## spend the last of the ecosystem, and that is a small absolute amount.
@export_range(0, 2000, 5) var safety_floor_cells := 40
## Seconds ground stays Pruned before it is ordinary neutral again. Pruned Ground
## reclaims fast, but only once the ring is let go.
@export_range(1.0, 120.0, 0.5) var pruned_ground_seconds := 12.0
## Control per second Green gains while retaking Pruned Ground.
@export_range(0.0, 4.0, 0.01) var pruned_regrowth_per_second := 1.30

@export_group("Cuttings")
## Cuttings produced per cell of harvested ground, before Cutting Yield.
@export_range(0.01, 4.0, 0.01) var cuttings_per_cell := 0.22
## Highest number of Cuttings one harvest step may raise, so a large drain in one
## frame cannot flood the pool.
@export_range(1, 200, 1) var maximum_cuttings_per_step := 26
## Cuttings preallocated for the whole run.
@export_range(8, 400, 1) var cutting_pool_size := 120
## Base damage of one Cutting before Cutting Damage applies.
## Moves with `orbit_contact_damage`; see the note there for why they are not separate
## decisions.
@export_range(1.0, 300.0, 1.0) var cutting_damage := 12.0
## Enemies one Cutting can strike before it is spent.
@export_range(1, 12, 1) var cutting_pierce := 2
## Damage retained after each enemy a Cutting passes through.
@export_range(0.05, 1.0, 0.01) var cutting_pierce_falloff := 0.65
## Seconds a Cutting spirals toward the player before it joins the ring.
@export_range(0.05, 4.0, 0.05) var cutting_gather_seconds := 0.55
## Pixels per second a Cutting travels once launched.
@export_range(60.0, 1200.0, 10.0) var cutting_speed_pixels_per_second := 520.0
## Seconds a launched Cutting survives.
@export_range(0.2, 8.0, 0.1) var cutting_lifetime_seconds := 1.60
## Arena pixels within which a flying Cutting strikes an enemy.
@export_range(2.0, 60.0, 1.0) var cutting_hit_radius_pixels := 12.0

@export_group("Orbit")
## Cuttings the ring may hold. A fuller harvest replaces the oldest spike rather
## than growing the ring forever, which keeps it legible.
## Leaves the ring may hold before Cutting Yield. Eight is the undeveloped ring; the
## line earns the rest back, which is what makes it the growth line.
@export_range(1, 40, 1) var orbit_capacity := 8
## Leaves a *fully developed* ring is measured against. Fullness -- which drives both
## the radius and the damage ramp -- is the leaf count over this, never over capacity.
##
## They have to be different numbers or Cutting Yield cannot do anything. Dividing by
## capacity means raising capacity raises the denominator too: eight leaves of eight
## and sixteen of sixteen are both a full ring, so the upgrade would buy leaves that
## are each worth proportionally less and the ring would end up exactly where it
## started. Against a fixed reference, every leaf is worth the same and buying
## capacity buys a bigger, harder ring.
@export_range(1, 40, 1) var orbit_reference_leaves := 16
## Leaves Cutting Yield adds to capacity per rank.
@export_range(0.0, 8.0, 0.5) var cutting_yield_leaves_per_rank := 3.0
## Seconds between raising one leaf, however fast the harvest is paying for them.
##
## The ring builds a leaf at a time and is meant to be watched doing it. Unthrottled,
## a developed harvest takes sixty cells a second at `cuttings_per_cell`, which is
## thirteen leaves a second -- a full ring in a little over one, appearing faster than
## it can be read. Held slightly slower than `orbit_wilt_interval_seconds`, so a ring
## is lost marginally faster than it is built and standing still is visibly expensive.
@export_range(0.0, 3.0, 0.05) var leaf_raise_interval_seconds := 0.45
## Seconds between replacement spikes once the ring is full. The ring turning over
## is intended; doing it several times a second is what made holding a finished
## ring a free homing volley launcher instead of a disc.
@export_range(0.0, 30.0, 0.1) var full_ring_replacement_seconds := 1.50
## The same interval once the run holds Deadfall. Base Pruning sheds a thorn now
## and then; Deadfall is what turns the ring into a thresher, throwing the torn-out
## thorns off it as fast as the harvest can raise them.
@export_range(0.0, 5.0, 0.01) var deadfall_replacement_seconds := 0.15
## Arena pixels from the player to the ring at one Cutting.
@export_range(10.0, 200.0, 1.0) var orbit_radius_pixels := 44.0
## Extra radius at a full ring, so a big harvest reads as a big ring.
## Pixels the ring's radius gains between an empty ring and a full one.
##
## Twenty-six on a base of forty-four was a detail. It is now the path's main
## investment: what a developed Pruning buys is *area*, because damage per body does
## not scale with a crowd and ground denied does. A full ring reaches 154px, which is a
## place rather than a halo, and a starved one recedes to 44 as its spikes wilt.
@export_range(0.0, 400.0, 1.0) var orbit_radius_growth_pixels := 110.0
## Radians per second the ring turns at zero Charge.
@export_range(0.1, 12.0, 0.1) var orbit_speed_radians := 2.4
## Extra turn rate at full Charge, which is what makes a banked ring read as loaded.
@export_range(0.0, 12.0, 0.1) var orbit_speed_charge_bonus := 3.4
## Arena pixels past the hoop that the dragged runners still reach. Everything
## inside the hoop is caught as well: the spikes are tied together by severed
## runners that sweep the whole enclosed ground, so an enemy that closes to contact
## is standing in the thicket rather than safely inside a bare circle.
@export_range(2.0, 60.0, 1.0) var orbit_reach_pixels := 18.0
## Damage one pass of the ring deals before Cutting Damage and Charge.
##
## Cut from 26.0 with `cutting_damage` alongside it, and the two have to move together
## or neither moves at all. Measured on the rank-3 siege bench: zeroing the ring alone
## cost 5,200 damage, zeroing the Cuttings alone cost 2,300, and zeroing both cost
## 23,600 -- whichever source is left simply takes over the kills. The same held for
## the defence: either one alone was enough to keep damage taken at zero against sixty
## enemies, and only removing both let anything reach her.
## Damage one pass of the ring deals before Cutting Damage and Charge.
##
## Cut hard, and deliberately. A ring whose damage is high enough to be a build's main
## output kills a 42-point Hunter on first contact, which means nothing ever crosses it
## and everything inside it is unreachable content. Low damage is what makes the space
## the ring encloses a space at all. Early, when a wave is four Hunters, this is most of
## what the path does; later it is a rounding error next to the ground it denies, which
## is the arc the path is being built for rather than a weakness in it.
## What one bite of the ring deals to each enemy standing in it, before Cutting Damage,
## Charge and the ring's size.
##
## Every body in reach takes it in full on its own cooldown. It was a budget divided
## among everything in reach for a while -- which held the ring's output constant
## however many it held, and on the crowds a late run is made of left each enemy a
## sliver. Measured then, a flat 20-point aura on the siege bench did 151,732 against a
## Cane-only 15,248; `orbit_maximum_targets_per_tick` is what bounds it now.
@export_range(0.5, 400.0, 0.5) var orbit_contact_damage := 16.0
## Seconds before the ring may strike the same enemy again.
@export_range(0.05, 3.0, 0.05) var orbit_hit_cooldown_seconds := 0.35
## Enemies one tick of the thicket may bite, nearest first.
##
## An aura's real output is its per-enemy damage multiplied by how many enemies are
## standing in it, and the second term is enemy density, which climbs all run. Every
## weapon of this shape in the genre bounds one of the two. Vampire Survivors bounds
## the first: Garlic does fifteen damage a second to a single target at max level and
## earns its place through the knockback and freeze-resistance it strips, not through
## damage. This thicket does about two hundred and fifty a second per body, so it has
## to bound the other.
##
## Nearest first, so the cap reads as the thicket being *crowded out* rather than as
## an arbitrary refusal: what it bites is what is pressed against it, which is what a
## player watching the ring would expect it to bite anyway.
@export_range(1, 60, 1) var orbit_maximum_targets_per_tick := 8
## Share of the ring's damage a ring of one spike deals, against a full ring of
## `orbit_capacity`. Between the two it is linear in the spike count.
##
## The thicket used to deal `orbit_contact_damage` flat the moment a single spike
## existed, so one spike bit exactly as hard as sixteen and the ring's damage was
## binary: up, or down. That is most of why the path resisted every nerf. Halving the
## Cutting yield changed nothing because the ring was already at full damage on its
## first spike, `orbit_capacity` and the shed timer were decorative, and the only
## number that moved output was how much of the run the ring existed at all -- which
## was 99% of it.
##
## Scaled, the ring becomes the thing it looks like: a thicket she builds by cutting
## fresh ground and loses by standing on ground she has already cut.
## Raised from 0.06. That value was chosen when a single spike dealt the ring's full damage
## and the ring was up 99% of every bench -- it exists to stop one spike hitting as hard as
## sixteen, and 6% did that by making a small ring worth nothing at all. Now that the ring is
## the path's damage and its size is a resource that has to be earned and held, the size a
## real build sustains is a *small* ring, and a curve whose floor is 6% reports that build as
## contributing almost nothing. The ceiling still belongs to a full ring; the floor no longer
## has to be zero.
@export_range(0.0, 1.0, 0.01) var orbit_lone_spike_damage_share := 0.25
## Seconds of harvesting that finds nothing before the ring loses a spike.
##
## The other half of the same rule. Without it a ring that had filled stayed filled:
## the harvest stopping cost her the *next* spike but never the ones she had, so
## standing still was free once the ring was built. Spikes wilt rather than launch --
## a ring starving is not a discharge, and paying her a volley for stopping would
## reward the thing this is here to discourage.
@export_range(0.05, 5.0, 0.05) var orbit_wilt_interval_seconds := 0.40
## Leaves the ring keeps however long the harvest finds nothing.
##
## Standing still costs her the ring's *area*, not the ring. Area is the currency the
## path trades in -- a full ring is 154px of denied ground and a bare one is 44 -- so
## letting stillness strip eleven leaves down to one is already a heavy, legible price
## paid continuously, which a binary loss is not. It also keeps the path present: a
## Pruning that can be switched off entirely by a pause is a Pruning that cannot be
## relied on to do anything, and every upgrade bought into it becomes conditional on
## never standing still.
##
## Recovery is the other half. Regrowing a ring means reaching unharvested Green, which
## is not always adjacent, so a ring that died outright would take longer to rebuild
## than the pause that killed it -- which makes the cost a tax on pausing rather than a
## decision about where to stand.
@export_range(0, 8, 1) var minimum_orbit_leaves := 1
## Whether the floor is *granted* as well as protected: a ring below its floor grows back
## up to it without needing ground to cut.
##
## It has to be, or the path has a cliff instead of a curve. Leaves come only from the
## harvest, the harvest needs Green in reach, and a wilting leaf is what replants Green --
## so with no ground there is no leaf, with no leaf there is nothing to wilt, and with
## nothing wilting there is never any ground. Measured on the 6% patch board, every Pruning
## row came back byte-identical to the bare Cane: 0.00 leaves, the ring up 2.7% of the
## bench, 100% of it with no Green underfoot. Not weak -- exactly nothing.
##
## One granted leaf is the seed that lets the loop turn over: it can wilt, its ground can be
## cut, and a second leaf can be raised from that. What a territory Adaptation beside her
## buys is then a *bigger* ring rather than the difference between a ring and none.
@export var grant_minimum_orbit_leaves := true
## Seconds the harvest may find nothing before the ring warns that a leaf is about to
## wilt. Read by the draw, not by the simulation: this changes what the player is told,
## never what happens.
##
## The point is that the ring is legible *before* it costs anything. Half a second of
## stillness flashes the leaves; the leaf itself goes at
## `orbit_wilt_interval_seconds`. So the ring is never lost to something the player
## could not see coming, and the flash is the mechanic teaching itself.
@export_range(0.0, 4.0, 0.05) var wilt_warning_seconds := 0.50
## Seconds of standing still after which a ring running dry counts as starvation rather
## than as a discharge she chose.
##
## The two have to be told apart, because one is the path's payout and the other is its
## failure. They used to be told apart by the ground underfoot -- bare meant she walked
## off and meant it, Pruned meant the harvest ate it while she stood there -- and the
## note at that call site records the proxy failing: after a harvest the ground all
## around her is Pruned, so stepping aside deliberately is indistinguishable from
## starving in place. A previous attempt to make starvation withhold the volley was
## reverted over exactly that.
##
## Asking whether she moved measures the thing itself instead of a consequence of it.
## Walking off her Green fires the ring, because she walked; standing until the harvest
## has eaten everything in reach withers it, because she did not.
@export_range(0.05, 2.0, 0.05) var release_intent_seconds := 0.25
## Green a wilting leaf sets down where it falls, as a share of an ordinary Seed's
## growth. Zero plants nothing.
##
## The ring is harvested ground she is carrying. When the harvest runs dry the ring
## recedes a leaf at a time, and a leaf that falls puts its ground back rather than
## vanishing -- so running out of Green under her feet replants the ground she is
## standing on, and the loop that starves the path also restores it. Failure is the
## rhythm rather than the punishment: harvest until the ground is spent, drop leaves,
## harvest the ground they made.
##
## Deliberately lossy, and this is the number that keeps the path honest. A leaf costs
## about 4.5 cells at `cuttings_per_cell`, and a Seed *grows* after it lands, so a
## generous share would make Pruning a net producer of territory and turn the ground
## cost into a ground profit. Fresh growth rather than a Bloom for the same reason: if
## a fallen leaf made Mature Green it would be manufacturing exactly what Root
## amplifies from. Watch `green` and `mature` on the bench against the bare Cane -- if
## Pruning ends a row with more ground than a build that never harvested, this is set
## too high.
@export_range(0.0, 1.0, 0.05) var wilted_leaf_growth_share := 0.55

@export_group("Charge")
## Seconds of unbroken holding to reach full Charge.
@export_range(0.5, 60.0, 0.5) var charge_seconds := 8.0
## Extra ring damage at full Charge.
@export_range(0.0, 6.0, 0.05) var orbit_charge_damage_bonus := 0.80
## Extra launch damage at full Charge. This is where a long hold pays out, and it
## has to be the largest number the path puts on screen: a discharge costs the ring
## and a quarter of the ecosystem to rebuild, so it cannot be worth a couple of
## seconds of grinding.
@export_range(0.0, 12.0, 0.05) var launch_charge_damage_bonus := 6.00
## Extra enemies a discharged spike drives through at full Charge, on top of the
## ordinary Cutting pierce. A bursting hoop is supposed to open a lane.
@export_range(0, 12, 1) var launch_pierce_at_charge := 4
## Damage a discharged spike keeps after each enemy it drives through. Far gentler
## than the ordinary falloff, because the whole point of the burst is that it goes
## all the way through a crowd rather than stopping in the front rank.
@export_range(0.05, 1.0, 0.01) var launch_pierce_falloff := 0.88
## The ready tell. Charge is otherwise drawn as a gradient -- longer spikes, brighter
## tint, a faster turn -- and a gradient has no ceiling the eye can find: a ring at
## 90% looks like a ring at 100%, so the player either releases early or holds a full
## ring for nothing. The pulse is a state change rather than more of the same signal.
@export_range(0.0, 8.0, 0.05) var full_charge_pulse_hz := 2.2
## How far the pulse dips between beats. At 0 the tell is a steady glow.
@export_range(0.0, 1.0, 0.01) var full_charge_pulse_depth := 0.60
@export var full_charge_pulse_color := Color("ffe98a")
## Arena pixels the pulsing hoop stands outside the ring, and the halo radius drawn
## on each spike.
@export_range(0.0, 40.0, 0.5) var full_charge_hoop_offset_pixels := 5.0
@export_range(0.0, 40.0, 0.5) var full_charge_halo_pixels := 6.5

@export_group("Vegetative Propagation")

@export_group("Relics")
## Ring kills between Gleaning Hook's free Charge.
## Gleaning Hook: kills the ring makes itself, paid back as ring.
##
## It used to bank Charge, and Charge is the one currency the rework demoted -- its
## only consumer is the payout multiplier on a deliberate discharge, and the discharge
## is now a small share of a path whose damage is the ring standing there. Measured on
## a walking 30% board with the ring spent at every fill, the relic was worth -0.6%:
## the tightest zero in the pool, and the only Pruning relic that measured *below*
## holding none.
##
## Its own sentence is "grants Charge without cutting more Green", and the thing that
## sentence is really about is the second half -- the ring being paid in blood instead
## of in ground.
##
## Buying leaves with it was tried first and measured byte-identical to holding no relic
## at all, for the reason that has now caught three separate levers on this path: a ring
## walking fresh Green runs at or near its capacity, so anything that adds to the
## harvest's debt is adding to a queue that is already longer than the shed cadence can
## spend. Leaves are not the scarce thing. **Ground is**, since the scarcity fix, and
## ground is what the relic's own sentence says it saves.
##
## So a payout cancels harvest debt instead: kills pay the upkeep the ring would
## otherwise have taken out of the run's own territory. Same promise, in the one
## currency the reworked path is actually short of.
@export_range(1, 40, 1) var gleaning_hook_kills := 8
## Cells of upkeep a payout cancels, and the most a single hold can be spared. Capped
## for the reason the Charge version was: a long hold against a crowd must not be able
## to run its ring for free, or the ground cost that is the whole point of the path
## stops being paid.
@export_range(0.5, 20.0, 0.5) var gleaning_hook_cells := 4.0
@export_range(1.0, 60.0, 1.0) var gleaning_hook_maximum_cells := 12.0
## Reclamation multiplier one Green Manure discharge kill is worth.
@export_range(0.0, 1.0, 0.01) var green_manure_per_kill := 0.09
## Largest reclamation multiplier Green Manure may reach.
@export_range(1.0, 8.0, 0.05) var green_manure_maximum := 2.60
## Seconds a Green Manure reclamation bonus lasts after the ring fires.
@export_range(1.0, 60.0, 0.5) var green_manure_seconds := 8.0
## Damage multiplier of a Return Stroke's contracting ring.
@export_range(0.05, 1.0, 0.01) var return_stroke_damage := 0.55
## Speed multiplier of the contracting ring.
@export_range(0.1, 2.0, 0.05) var return_stroke_speed := 0.80
## How wide Root Memory feeds maturity back, as a multiple of the harvest's own reach.
@export_range(0.5, 8.0, 0.1) var stool_regrowth_memory_radius_multiplier := 2.4
## Skimming Cut: how far a glancing spike looks for something new to hit, and what
## it keeps of its speed and damage after the bounce.
@export_range(20.0, 600.0, 5.0) var skimming_cut_range_pixels := 180.0
@export_range(0.1, 1.0, 0.01) var skimming_cut_speed_share := 0.75
@export_range(0.05, 1.0, 0.01) var skimming_cut_damage_share := 0.65
## Callus: how long the wound stays answerable, and what returning to it restores.
@export_range(0.5, 30.0, 0.5) var callus_window_seconds := 8.0
@export_range(10.0, 400.0, 2.0) var callus_radius_pixels := 70.0
@export_range(0.0, 1.0, 0.01) var callus_control := 0.14
@export_range(0.0, 2.0, 0.01) var callus_mass := 0.12
## Brush Pile: harvesting past half Charge stores bundles, each worth two spikes.
@export_range(0.0, 1.0, 0.01) var brush_pile_charge_threshold := 0.50
@export_range(1, 200, 1) var brush_pile_cells_per_bundle := 24
@export_range(1, 12, 1) var brush_pile_maximum_bundles := 4
@export_range(1, 8, 1) var brush_pile_cuttings_per_bundle := 2
@export_range(0.05, 1.0, 0.01) var brush_pile_damage_share := 0.55
@export_range(0.0, 2.0, 0.01) var brush_pile_delay_seconds := 0.18
## Stubble: how long a wound stays sharp and what crossing it costs.
@export_range(0.5, 30.0, 0.5) var stubble_seconds := 5.0
@export_range(10.0, 400.0, 2.0) var stubble_radius_pixels := 90.0
@export_range(0.05, 5.0, 0.05) var stubble_tick_seconds := 0.65
@export_range(0.0, 2.0, 0.01) var stubble_damage_share := 0.35
@export_range(1, 8, 1) var stubble_maximum_wounds := 1
## Watersprouts: what a killing spike leaves behind, and the caps that stop it
## turning one release into an unbounded thicket.
@export_range(1, 8, 1) var watersprout_children := 2
@export_range(0.05, 1.0, 0.01) var watersprout_damage_share := 0.55
@export_range(0.5, 3.0, 0.05) var watersprout_speed_share := 1.15
@export_range(20.0, 600.0, 5.0) var watersprout_range_pixels := 220.0
@export_range(1, 64, 1) var watersprout_release_maximum := 16
@export_range(1, 32, 1) var watersprout_frame_maximum := 8

var _cuttings: Array[Cutting] = []
var _pioneer_remaining := 0.0
var _pioneer_sites := PackedVector2Array()
var _pioneer_debt := 0.0
## Second Flush's own counters: Seeds owed by Cutting kills, eruptions so far, and the
## wave held back for the next one.
var _pioneer_kill_debt := 0.0
var _pioneer_kill_seeds := 0
var _pioneer_eruptions := 0
var _pioneer_second_wave := PackedVector2Array()
var _last_pioneer_positions := PackedVector2Array()
## Elastic Rebound's pending wave: where it lands, how hard, and how long until it does.
var _compression_wave_position := Vector2.ZERO
var _compression_wave_force := 0.0
var _compression_wave_remaining := 0.0
## Second Harvest: how much Mature ground the last cycle took, where it took it, and how
## many Cuttings the follow-up owes once it has grown back.
var _stool_watch_position := Vector2.ZERO
var _stool_watch_cells := 0
var _stool_watch_reward := 0
var _gleaning_kills := 0
var _upkeep_spared := 0.0
## Deadfall's volley cooldown. Its own, not the harvest's.
var _deadfall_volley_remaining := 0.0
var _gleaning_banked := 0.0
var _green_manure_kills := 0
var _green_manure_remaining := 0.0
var _cycles_run := 0
var _cuttings_launched := 0
var _cutting_debt := 0.0
var _replacement_remaining := 0.0
var _last_cycle_cells := 0
var _charge := 0.0
## Seconds the ring has been sitting at full Charge, which is the pulse's own clock.
## It starts at zero on the frame the ring fills so the first beat is its brightest.
var _full_charge_pulse := 0.0
## Whether the ring was already full last tick, so the frame it fills can be held at
## the top of the beat instead of starting one frame in.
var _was_fully_charged := false
var _orbit_angle := 0.0
## Counts down to the next leaf; see `leaf_raise_interval_seconds`.
var _leaf_raise_remaining := 0.0
## Seconds she has been standing still, and where she was last seen. Used to tell a
## discharge she chose from a ring that starved; see `release_intent_seconds`.
var _still_seconds := 0.0
var _last_player_position := Vector2.ZERO
## Whether she was moving on the frame her footing ran out.
var _left_deliberately := false
var _orbit_sequence := 0
var _hit_cooldowns := {}
var _upkeep_debt := 0.0
var _upkeep_cells_taken := 0
## Aftergrowth cells the harvest ate instead of Green.
var _shield_cells_taken := 0
var _rings_released := 0
var _holding := false
## Seconds since there was last Green under her feet; see `footing_grace_seconds`.
var _starved_seconds := 0.0
## Set when the ring tore, cleared when the footing debt is paid off in full. A torn
## ring does not begin re-forming the moment one cell of Green comes back underfoot.
var _torn := false
## Seconds since the harvest last found ground to cut; see `orbit_wilt_interval_seconds`.
var _unfed_seconds := 0.0
var _hold_seconds := 0.0

## Cells harvested past the Brush Pile threshold, and the bundles they have become.
var _brush_cells := 0
var _brush_bundles := 0
## The bonus volley waiting to go out behind the ring: [remaining, cuttings, damage].
var _brush_volley: Array = []
## The most recent wound: where it is, how long Callus will still answer, whether it
## has been spent, and whether the player has actually left it since the release.
var _callus_position := Vector2(-1.0, -1.0)
var _callus_remaining := 0.0
var _callus_used := false
var _callus_left_wound := false
## Sharp Pruned Ground, each [position, remaining, {enemy_id: cooldown}].
var _stubble_wounds: Array = []
## Watersprout children sown by the current release, and how many this frame.
var _watersprouts_this_release := 0
var _watersprouts_this_frame := 0

func _ready() -> void:
	assert(territory_field != null, "PruningDirector requires TerritoryField")
	assert(overlay != null, "PruningDirector requires TerritoryPrototypeOverlay")
	assert(combat != null, "PruningDirector requires CombatDirector")
	assert(progression != null, "PruningDirector requires Progression")
	_configure_pools()
	reset_director()

func reset_director() -> void:
	for cutting in _cuttings:
		cutting.state = CuttingState.INACTIVE
	_pioneer_remaining = 0.0
	_pioneer_sites = PackedVector2Array()
	_pioneer_debt = 0.0
	_pioneer_kill_debt = 0.0
	_pioneer_kill_seeds = 0
	_pioneer_eruptions = 0
	_pioneer_second_wave = PackedVector2Array()
	_last_pioneer_positions = PackedVector2Array()
	_compression_wave_position = Vector2.ZERO
	_compression_wave_force = 0.0
	_compression_wave_remaining = 0.0
	_stool_watch_position = Vector2.ZERO
	_stool_watch_cells = 0
	_stool_watch_reward = 0
	_gleaning_kills = 0
	_gleaning_banked = 0.0
	_upkeep_spared = 0.0
	_deadfall_volley_remaining = 0.0
	_green_manure_kills = 0
	_green_manure_remaining = 0.0
	_brush_cells = 0
	_brush_bundles = 0
	_brush_volley.clear()
	_callus_position = Vector2(-1.0, -1.0)
	_callus_remaining = 0.0
	_callus_used = false
	_callus_left_wound = false
	_stubble_wounds.clear()
	_watersprouts_this_release = 0
	_watersprouts_this_frame = 0
	_cycles_run = 0
	_cuttings_launched = 0
	_cutting_debt = 0.0
	_replacement_remaining = 0.0
	_last_cycle_cells = 0
	_charge = 0.0
	_full_charge_pulse = 0.0
	_was_fully_charged = false
	_orbit_angle = 0.0
	_orbit_sequence = 0
	_hit_cooldowns.clear()
	_upkeep_debt = 0.0
	_upkeep_cells_taken = 0
	_shield_cells_taken = 0
	_rings_released = 0
	_holding = false
	_hold_seconds = 0.0
	_starved_seconds = 0.0
	_torn = false
	_unfed_seconds = 0.0
	# The leaf cadence and the movement bookkeeping reset with everything else. Left out,
	# a stale `_leaf_raise_remaining` survives into the next run and its first harvest
	# cycle raises nothing -- which is a new run silently opening on a throttle it did
	# not earn, and is what the Coppicing smoke test caught.
	_leaf_raise_remaining = 0.0
	_still_seconds = 0.0
	_last_player_position = Vector2.ZERO
	_left_deliberately = false
	queue_redraw()

func advance(delta: float) -> void:
	if _green_manure_remaining > 0.0:
		_green_manure_remaining = maxf(0.0, _green_manure_remaining - delta)
		if _green_manure_remaining <= 0.0:
			_green_manure_kills = 0
			_apply_regrowth()
	_watersprouts_this_frame = 0
	_advance_brush_volley(delta)
	_deadfall_volley_remaining = maxf(0.0, _deadfall_volley_remaining - delta)
	_advance_callus(delta)
	_advance_stubble(delta)
	_advance_ring(delta)
	_advance_full_charge_pulse(delta)
	_advance_cuttings(delta)
	_advance_pioneer(delta)
	_advance_compression(delta)
	_advance_stool_regrowth(delta)
	_apply_regrowth()
	queue_redraw()

func get_cycles_run() -> int:
	return _cycles_run

func get_cuttings_launched() -> int:
	return _cuttings_launched

func get_last_cycle_cells() -> int:
	return _last_cycle_cells

func get_charge() -> float:
	return _charge


func is_fully_charged() -> bool:
	## A standing ring with nothing left to gain by holding it. Both halves matter:
	## Charge alone with no spikes up is not something to act on.
	return _charge >= 1.0 and get_orbit_count() > 0


func _advance_full_charge_pulse(delta: float) -> void:
	if not is_fully_charged():
		_full_charge_pulse = 0.0
		_was_fully_charged = false
		return
	if not _was_fully_charged:
		# The frame the ring fills is the top of the first beat rather than one frame
		# into it. Accumulating on this frame would show the player the tell already
		# a little way down from its brightest, which is the one moment it must not.
		_was_fully_charged = true
		_full_charge_pulse = 0.0
		return
	_full_charge_pulse += delta


## 1.0 at the top of a beat, dipping to 1 - depth between them. Cosine rather than
## sine so the clock starting at zero puts the first beat at its brightest, on the
## frame the player needs to notice.
func _get_full_charge_pulse() -> float:
	if not is_fully_charged():
		return 0.0
	var beat := 0.5 + 0.5 * cos(_full_charge_pulse * TAU * full_charge_pulse_hz)
	return 1.0 - full_charge_pulse_depth * (1.0 - beat)

func is_holding() -> bool:
	return _holding

func get_orbit_count() -> int:
	var count := 0
	for cutting in _cuttings:
		if cutting.state == CuttingState.ORBITING:
			count += 1
	return count

func get_orbit_capacity() -> int:
	## Leaves the ring may hold, with Cutting Yield's ranks on top of the base.
	return mini(
		orbit_reference_leaves,
		orbit_capacity + int(round(
			cutting_yield_leaves_per_rank
			* float(progression.get_upgrade_level(Progression.UpgradeId.PRUNING_CUTTING_YIELD))
		))
	)

func get_orbit_radius() -> float:
	var fullness := float(get_orbit_count()) / float(maxi(1, orbit_reference_leaves))
	return orbit_radius_pixels + orbit_radius_growth_pixels * clampf(fullness, 0.0, 1.0)

func get_upkeep_cells_per_second() -> float:
	# The harvest accelerates with Charge, and Harvest Rate buys more spikes at the
	# price of a faster burn. A ring that is already full drops to maintenance,
	# because the ecosystem pays for spikes rather than for time.
	var rate := lerpf(
		upkeep_cells_per_second,
		upkeep_cells_per_second_at_charge,
		_charge
	)
	if get_orbit_count() >= get_orbit_capacity():
		rate = lerpf(
			maintenance_cells_per_second,
			maintenance_cells_per_second_at_charge,
			_charge
		)
	# On top of that, the drain climbs for every second the ring has gone without
	# firing. Charge alone caps after a few seconds, which left a single patch of
	# Green able to feed a ring indefinitely; this is what gives every hold an end.
	rate += upkeep_escalation_per_second * _hold_seconds
	# Root cuts deeper into old wood: it raises leaves faster and burns the Green faster
	# with it, and the cap above is what keeps that from running away.
	#
	# Harvest Rate stays here, and taking it out was measured and reverted: leaves fell
	# from 1.40 to 1.14 without it, because the cells feed `_cutting_debt` and the
	# cadence gate needs banked debt to have anything to raise. Both halves matter.
	#
	# What the line could not do by wiring alone is be *worth* anything. Under a ring
	# capped in size by Cutting Yield, in damage by Cutting Edge and in fill rate by the
	# throttle, "harvest faster" has no dimension left to push on -- two wirings measured
	# 16,477 and 16,283 on siege against a bare 16,754, both of them negative. So the
	# line's value now lives in `orbit_wilt_interval_seconds` instead: it buys how long
	# the ring survives with no ground under it, which is the one axis a ring that can be
	# lost still has free.
	return (
		minf(maximum_upkeep_cells_per_second, rate)
		* get_pruning_harvest_rate_multiplier()
		* get_ring_root_multiplier()
	)

func get_hold_seconds() -> float:
	return _hold_seconds

func get_shield_cells_taken() -> int:
	return _shield_cells_taken


func get_upkeep_cells_taken() -> int:
	return _upkeep_cells_taken

func get_rings_released() -> int:
	return _rings_released

func get_charge_seconds() -> float:
	return charge_seconds / maxf(
		0.05,
		get_pruning_charge_multiplier() * get_ring_root_multiplier()
	)

func get_launch_charge_damage_bonus() -> float:
	return (
		launch_charge_damage_bonus
		* get_pruning_charge_multiplier()
		* get_ring_root_multiplier()
	)

func is_player_on_green() -> bool:
	return (
		territory_field.get_control_at_local(combat.player.get_arena_position())
		> territory_field.tuning.ownership_threshold
	)

func get_active_cutting_count() -> int:
	var count := 0
	for cutting in _cuttings:
		if cutting.state != CuttingState.INACTIVE:
			count += 1
	return count

func is_above_safety_floor() -> bool:
	return territory_field.get_player_cell_count() > safety_floor_cells

func get_cycle_target_cells() -> int:
	# What one second of harvesting costs at zero Charge. No line raises the cost on
	# its own; Harvest Rate does, and that is the line that also buys the spikes.
	return maxi(1, int(round(get_upkeep_cells_per_second())))

func prune_for_rebound(local_position: Vector2) -> float:
	# Rebound: a Bloom pulls the Green around it inward before it goes off, and
	# converts that mass into Force rather than into Cuttings. Returns the extra
	# Force multiplier the Bloom earned.
	if not progression.has_active_evolution(Progression.EvolutionId.REBOUND):
		return 0.0
	if not is_above_safety_floor():
		return 0.0
	var rank := get_evolution_rank(Progression.EvolutionId.REBOUND)
	# Elastic Growth: the thinned ground keeps its accelerated regrowth for longer, so
	# what Rebound draws out of it comes back sooner.
	var pruned_window := pruned_ground_seconds
	if rank >= 2:
		pruned_window *= evolutions.compression_regrowth_window
	if rank >= 3:
		# Inward Collapse: the ground is not the only thing dragged in. Done before the
		# harvest so the pull reads as the cause of the collapse rather than its echo.
		combat.pull_enemies_toward(
			local_position,
			evolutions.rebound_radius_pixels,
			evolutions.compression_pull_pixels
		)
	var harvest := territory_field.compress_territory_in_radius(
		local_position,
		evolutions.rebound_radius_pixels,
		evolutions.rebound_compression_floor,
		pruned_window
	)
	if harvest.cell_count <= 0:
		return 0.0
	# Efficient Compression, twice: the same cell of Green is worth more Force. The cap
	# is left where it is, so the ranks buy a steeper curve rather than a higher ceiling.
	var conversion := evolutions.rebound_force_per_cell
	if rank >= 1:
		conversion *= 1.0 + evolutions.compression_force_bonus
	if rank >= 4:
		conversion *= 1.0 + evolutions.compression_force_bonus
	var force := minf(
		evolutions.rebound_maximum_force,
		float(harvest.cell_count) * conversion
	)
	if rank >= 5:
		# Elastic Rebound: the collapse springs back a beat after the Bloom goes off. It
		# takes no further territory and makes no Plant Mass - it is the ground releasing
		# what the first detonation stored, not a second Bloom.
		_compression_wave_position = local_position
		_compression_wave_force = force * evolutions.compression_second_wave_share
		_compression_wave_remaining = evolutions.compression_second_wave_delay
	status_requested.emit(
		"REBOUND — %d cells collapsed into the Bloom." % harvest.cell_count
	)
	return force


func _advance_compression(delta: float) -> void:
	if _compression_wave_remaining <= 0.0:
		return
	_compression_wave_remaining -= delta
	if _compression_wave_remaining > 0.0:
		return
	_compression_wave_remaining = 0.0
	# Pressure and damage, no mass: the second wave shoves the frontier and hurts what is
	# standing in it without growing a single new cell of Green.
	territory_field.attribution = RunStats.Source.PRUNING
	territory_field.queue_bloom(
		_compression_wave_position,
		0.0,
		1.0 + _compression_wave_force,
		0.0,
		1.0
	)
	combat.damage_enemies_in_radius(
		_compression_wave_position,
		evolutions.compression_second_wave_radius,
		evolutions.compression_second_wave_damage * (1.0 + _compression_wave_force),
		CombatDirector.DeathSource.BLOOM
	)
	overlay.spawn_hostile_pulse(
		_compression_wave_position,
		evolutions.compression_second_wave_radius
	)
	status_requested.emit("ELASTIC REBOUND — the collapse springs back.")

func run_cycle_now() -> int:
	# Debug and test entry point for one second of the harvest the run performs
	# continuously while the player stands on their own ground.
	return _harvest(get_cycle_target_cells())

func grant_free_cuttings(wanted: int) -> int:
	## Clippings that cost the run no territory. Two things ask for them: a Clover
	## Pruning jackpot, which must not pay for itself with the ground it is rewarding,
	## and Second Harvest, where the regrowth itself is what pays.
	if wanted <= 0:
		return 0
	var room := maxi(0, get_orbit_capacity() - _get_committed_ring_count())
	if room <= 0:
		return 0
	# A real harvest carries the positions its spikes rise from. This one is generated:
	# a ring around the player, at the radius the orbit will settle to anyway.
	var gift := TerritoryField.PruneHarvest.new()
	var origin := combat.player.get_arena_position()
	var count := mini(wanted, room)
	for index in range(count):
		gift.positions.append(
			origin + Vector2.from_angle(TAU * float(index) / float(count)) * get_orbit_radius()
		)
	var raised := 0
	# _raise_cuttings throttles itself to one harvest step, which is the right rule for
	# ground being cut and the wrong one for a one-off gift, so the gift is paid out in
	# as many steps as it takes.
	while raised < count:
		var granted := _raise_cuttings(gift, count - raised)
		if granted <= 0:
			break
		raised += granted
	return raised


func release_ring_now() -> int:
	# Debug and test entry point for the release the run would trigger by moving.
	var orbiting := get_orbit_count()
	_release_ring("PRUNING — the ring fired.")
	return orbiting

func _configure_pools() -> void:
	_cuttings.clear()
	for _index in range(cutting_pool_size):
		_cuttings.append(Cutting.new())

func _apply_regrowth() -> void:
	# A turning ring suppresses reclamation entirely: the ground burned to keep it
	# alive stays burned for as long as it is alive. The moment the ring fires, the
	# cut ground starts coming back, which is the valve that keeps a run holding a
	# ring most of the time from bleeding to nothing.
	# Above its floor, not merely non-empty. The floor leaf is granted rather than cut for,
	# so it has bought none of the ground this suppression is charging for -- and because it
	# is always there, keying on `> 0` made the suppression permanent: cut ground never came
	# back at all, for the whole run. The Coppicing smoke test caught it reading a reclaim
	# rate of 0.000 where it expected 1.30, and it is the likeliest reason a Bloom-heavy
	# probe run watched its territory fall from 33.8% to 9.2%.
	if _holding and get_orbit_count() > minimum_orbit_leaves:
		territory_field.set_pruned_regrowth(0.0)
		return
	var regrowth := pruned_regrowth_per_second
	if progression.has_active_evolution(Progression.EvolutionId.COPPICING):
		# Coppicing: the Root Network drives the cut ground back much faster.
		regrowth *= evolutions.coppicing_regrowth_multiplier
		if get_evolution_rank(Progression.EvolutionId.COPPICING) >= 2:
			# Vigorous Regrowth: faster still, which is also what makes Second Harvest
			# arrive inside the same fight rather than two cycles later.
			regrowth *= evolutions.stool_regrowth_reclaim_bonus
	if _green_manure_remaining > 0.0:
		# Green Manure: what the discharge killed feeds the ground it was cut from,
		# and the more it killed the faster that ground comes back.
		regrowth *= minf(
			green_manure_maximum,
			1.0 + green_manure_per_kill * float(_green_manure_kills)
		)
	territory_field.set_pruned_regrowth(regrowth)

func _advance_ring(delta: float) -> void:
	for enemy_id in _hit_cooldowns.keys():
		_hit_cooldowns[enemy_id] = float(_hit_cooldowns[enemy_id]) - delta
		if _hit_cooldowns[enemy_id] <= 0.0:
			_hit_cooldowns.erase(enemy_id)
	# The footing debt, kept before anything decides whether the ring lives, because it
	# has to keep being paid back while the ring is down. Off Green it runs up, on Green
	# it drains; it is capped at the grace so that a long walk over bare ground is not a
	# debt she then has to stand still to clear, which would invert the whole mechanic.
	if is_player_on_green():
		_starved_seconds = maxf(0.0, _starved_seconds - delta * footing_recovery_rate)
	else:
		# Intent is captured on the frame the footing goes, not on the frame the ring
		# gives out. The release is `footing_grace_seconds` later -- over a second -- and
		# by then she is usually standing still whether she walked off deliberately or
		# stood until the harvest ate everything in reach, so asking at release time
		# reads the wrong moment and calls every discharge a starvation.
		if _starved_seconds <= 0.0:
			_left_deliberately = _still_seconds < release_intent_seconds
		_starved_seconds = minf(footing_grace_seconds, _starved_seconds + delta)
	# Losing the path outright, or spending the ecosystem down to the floor, ends the
	# hold at once. Losing the ground underfoot does not: she cuts that ground herself,
	# so it runs out constantly and she is given `footing_grace_seconds` to reach more.
	# A torn ring has to be earned back, not resumed. Without this the ring re-formed on
	# the first frame of Green after a tear and sat at 99% uptime through the whole
	# bench, which is why cutting its damage did so little: the path's output is its
	# coverage, and coverage was never interrupted.
	if _torn and _starved_seconds <= 0.0:
		_torn = false
	var can_hold := (
		progression.has_path_active(Progression.PathId.PRUNING)
		and is_above_safety_floor()
		and _starved_seconds < footing_grace_seconds
		and not _torn
	)
	if not can_hold:
		if get_orbit_count() > 0:
			# Running out of ground throws the ring outward. Whether that is a discharge
			# or a failure depends on why the ground went: Pruned Ground underfoot means
			# the harvest ate it while she stood there, which is the ring tearing; bare
			# ground means she walked off her own garden, which is her spending it.
			# Whether she was moving when the ground went, not what she is standing on
			# now. See `release_intent_seconds`.
			var chose_it := _left_deliberately
			if chose_it:
				_release_ring("PRUNING — you stepped off the Green; the ring fired.")
				_torn = true
			else:
				# Worded for the common case, which is no longer stepping off the Green
				# but standing still until the harvest has eaten it: the ground goes
				# away under her, and a message blaming her for leaving reads as a bug
				# the first few times it happens.
				# Worded for the common case, which is no longer stepping off the Green
				# but standing still until the harvest has eaten it: the ground goes
				# away under her, and a message blaming her for leaving reads as a bug
				# the first few times it happens.
				#
				# This branch was briefly made to *wither* the ring -- lose every spike
				# without launching any -- on the reasoning that running out of ground
				# should not pay a volley. Measured, it moved rooted and walking output
				# by the same 4% and did not widen the gap between them at all, which is
				# the only thing it was for, and it broke the test above it: after a
				# harvest the ground all around her is Pruned, so deliberately stepping
				# aside was indistinguishable from starving in place. Reverted.
				_release_ring(
					"PRUNING — no Green left underfoot; the ring tore loose.", false
				)
				_torn = true
		_holding = false
		_charge = 0.0
		_hold_seconds = 0.0
		_upkeep_debt = 0.0
		return
	_holding = true
	_hold_seconds += delta
	# A ring nothing is feeding thins out. The harvest resets this whenever it finds
	# ground; see `orbit_wilt_interval_seconds`.
	_unfed_seconds += delta
	# Harvest Rate lengthens this: the ring holds on longer with nothing to cut. See the
	# note in `get_upkeep_cells_per_second`.
	var wilt_interval := orbit_wilt_interval_seconds * maxf(
		0.05, get_pruning_harvest_rate_multiplier()
	)
	while _unfed_seconds >= wilt_interval:
		_unfed_seconds -= wilt_interval
		if not _wilt_oldest_spike():
			_unfed_seconds = 0.0
			break
	# Charge builds for as long as the ring is up, starving or not. Gating it on a
	# clear footing debt was a third tax on the same decision -- the harvest already
	# costs her the ground, and running the debt out already costs her the ring -- and
	# it quietly made the discharge, which is the path's payout, unreachable from a
	# short hold.
	var here := combat.player.get_arena_position()
	if here.distance_squared_to(_last_player_position) > 1.0:
		_still_seconds = 0.0
	else:
		_still_seconds += delta
	_last_player_position = here
	_leaf_raise_remaining = maxf(0.0, _leaf_raise_remaining - delta)
	_charge = minf(1.0, _charge + delta / maxf(0.05, get_charge_seconds()))
	_grant_floor_leaves()
	_run_harvest(delta)
	_turn_ring(delta)

func _grant_floor_leaves() -> void:
	## Grows the ring back up to its floor without charging ground for it.
	##
	## See `grant_minimum_orbit_leaves`: the floor has to be given, not only defended, or a
	## ring at zero can never reach one and the path is dead on any board too sparse to cut.
	##
	## Not while torn. A torn ring is earned back rather than resumed -- without that rule
	## the ring re-formed on the first frame of Green after a discharge and sat at 99%
	## uptime, which is most of why cutting its damage used to do so little.
	if not grant_minimum_orbit_leaves or _torn:
		return
	if not progression.has_path_active(Progression.PathId.PRUNING):
		return
	while get_orbit_count() < minimum_orbit_leaves:
		var cutting := _get_inactive_cutting()
		if cutting == null:
			return
		cutting.state = CuttingState.ORBITING
		# The granted leaf carries the ordinary Cutting damage, including its line, so the
		# floor is a floor on the ring's size and not a second, weaker kind of leaf.
		cutting.damage = cutting_damage * get_pruning_cutting_damage_multiplier()
		cutting.pierce_remaining = cutting_pierce
		cutting.last_hit_enemy_id = -1
		cutting.remaining = cutting_lifetime_seconds
		cutting.natural_release = false
		cutting.has_ricocheted = false
		cutting.sprout_generation = 0
		_orbit_sequence += 1
		cutting.orbit_slot = _orbit_sequence
		_position_orbit(get_orbit_count())

func _turn_ring(delta: float) -> void:
	var orbiting := get_orbit_count()
	if orbiting <= 0:
		return
	_orbit_angle += (orbit_speed_radians + orbit_speed_charge_bonus * _charge) * delta
	_position_orbit(orbiting)
	_apply_orbit_damage()

func _run_harvest(delta: float) -> void:
	# The harvest is the path. There is no interval to wait out: the ground under the
	# player is stripped continuously and comes straight back up as spikes.
	_replacement_remaining = maxf(0.0, _replacement_remaining - delta)
	_upkeep_debt += get_upkeep_cells_per_second() * delta
	if _upkeep_debt < 1.0:
		return
	if get_orbit_count() >= get_orbit_capacity() and not is_above_safety_floor():
		# A finished ring on an exhausted ecosystem simply stops eating rather than
		# throwing itself away.
		_upkeep_debt = 0.0
		return
	var wanted := int(floor(_upkeep_debt))
	_upkeep_debt -= float(wanted)
	_harvest(wanted)
	# A cycle that found nothing used to fire the ring on the spot. It cannot now: the
	# cut takes her own cell, so an empty cycle is what every stationary player gets
	# within a second or two, and firing there would make the path unholdable. The
	# grace timer in `_advance_ring` owns the release instead.

func _harvest(wanted_cells: int) -> int:
	if wanted_cells <= 0:
		return 0
	if not is_above_safety_floor():
		# The floor is not a failure: it is the path refusing to kill its own run.
		_last_cycle_cells = 0
		return 0
	# Bloom's Aftergrowth shield is harvested before the ground is: the shield is
	# disposable control, and eating it spares the Green underneath. Only what the
	# shield in reach cannot pay for is cut out of the territory itself.
	var shield := territory_field.strip_aftergrowth_in_radius(
		combat.player.get_arena_position(),
		upkeep_radius_pixels,
		wanted_cells
	)
	var harvest := territory_field.drain_territory_in_radius(
		combat.player.get_arena_position(),
		upkeep_radius_pixels,
		wanted_cells - shield.cell_count,
		pruned_ground_seconds,
		upkeep_inner_radius_pixels
	)
	# Only real ground counts as ground spent; the shield cells join the harvest after.
	var ground_cells := harvest.cell_count
	harvest.cell_count += shield.cell_count
	harvest.positions.append_array(shield.positions)
	_last_cycle_cells = harvest.cell_count
	if harvest.cell_count <= 0:
		return 0
	# Fed. Every cell the drain returns is fresh by construction -- Pruned Ground sits
	# at zero control and the drain only takes ground she still owns -- so finding any
	# ground at all is the signal that she has moved onto something worth cutting.
	_unfed_seconds = 0.0
	_cycles_run += 1
	_upkeep_cells_taken += ground_cells
	_shield_cells_taken += shield.cell_count
	# Both harvest relics are counted here rather than at the bottom of this function.
	# Below this point a full ring returns early on every frame between sheds, so a
	# relic whose sentence is about "continued harvesting" was being paid on the small
	# subset of cycles that finished by raising a leaf -- which, once the ring fills, is
	# a few frames a second out of every cycle that actually cuts ground.
	_note_brush_harvest(harvest.cell_count)
	_note_stubble_harvest(harvest.cell_count, combat.player.get_arena_position())
	# A full ring still sheds its oldest spike to take a new one — that is the ring
	# turning over, and it should happen. What it must not do is happen three times
	# a second: unthrottled, holding a finished ring was a free homing volley on tap
	# and the disc itself stopped being the damage. Between sheds the ground is
	# still spent, so holding a full ring costs territory either way.
	if _get_committed_ring_count() >= get_orbit_capacity():
		if _replacement_remaining > 0.0:
			# Bank toward the next shed rather than discarding it, but never bank
			# more than the one spike a shed is allowed to raise: a full ring must
			# not save up a volley to dump the moment the timer elapses.
			_cutting_debt = minf(
				_cutting_debt
				+ float(harvest.cell_count) * cuttings_per_cell,
				1.0
			)
			return 0
		_replacement_remaining = get_replacement_seconds()
	var cuttings := float(harvest.cell_count) * cuttings_per_cell
	if progression.has_active_evolution(Progression.EvolutionId.DEADFALL):
		# Deadfall: the thorns torn out with the Green become spikes of their own.
		# Thorn Harvest, twice: the same thorned cut is worth more of them.
		var splinter_rank := get_evolution_rank(Progression.EvolutionId.DEADFALL)
		var thorn_yield := evolutions.deadfall_cuttings_per_development
		if splinter_rank >= 1:
			thorn_yield *= 1.0 + evolutions.splinterstorm_yield_bonus
		if splinter_rank >= 4:
			thorn_yield *= 1.0 + evolutions.splinterstorm_yield_bonus
		cuttings += harvest.bramble_development * thorn_yield
	if progression.has_active_evolution(Progression.EvolutionId.COPPICING):
		# Coppicing: ancient ground is worth far more when it is finally cut.
		# Mature Harvest, twice: more of it still.
		var stool_rank := get_evolution_rank(Progression.EvolutionId.COPPICING)
		var mature_yield := evolutions.coppicing_cuttings_per_mature_cell
		if stool_rank >= 1:
			mature_yield *= 1.0 + evolutions.stool_regrowth_yield_bonus
		if stool_rank >= 4:
			mature_yield *= 1.0 + evolutions.stool_regrowth_yield_bonus
		cuttings += float(harvest.mature_cell_count) * mature_yield
		if stool_rank >= 3 and harvest.mature_cell_count > 0:
			# Root Memory: the ground remembers what it was. The regrowth over a Mature
			# cut comes back part-matured instead of starting from nothing.
			territory_field.queue_maturity_support(
				combat.player.get_arena_position(),
				evolutions.stool_regrowth_memory_share,
				stool_regrowth_memory_radius_multiplier
			)
		if stool_rank >= 5 and harvest.mature_cell_count > 0 and _stool_watch_cells <= 0:
			# Second Harvest: watch the ground this cycle took, and pay a second volley
			# once it has grown most of the way back. No further territory is spent.
			_stool_watch_position = combat.player.get_arena_position()
			_stool_watch_cells = harvest.mature_cell_count
			_stool_watch_reward = maxi(
				1,
				roundi(float(harvest.mature_cell_count) * mature_yield
					* evolutions.stool_regrowth_second_share)
			)
	# Older wood yields more spikes out of the same cut, measured on the Mature share
	# of the patch that was actually taken rather than on a single point.
	cuttings *= get_pruning_cutting_yield_multiplier() * get_harvest_root_multiplier(harvest)
	_cutting_debt += cuttings
	# A ring with room fills as fast as the harvest pays for it; a full one takes
	# exactly one replacement per shed rather than dumping whatever has banked.
	var room := maxi(0, get_orbit_capacity() - _get_committed_ring_count())
	if room <= 0:
		room = 1
	# One leaf per interval however much the harvest has banked. The debt keeps its
	# balance, so a rich cut is not thrown away -- it arrives as a steady thickening
	# rather than a ring that appears between two frames.
	var allowance := 0
	if progression.has_active_evolution(Progression.EvolutionId.DEADFALL):
		# Deadfall is the throttle coming off, not a faster setting of it. Its stated
		# contract is taking the ring "from shedding a thorn occasionally to firing them
		# continuously, which is exactly what base Pruning must not do on its own" -- so
		# the gate that makes base Pruning legible is what the evolution buys past.
		#
		# Quickening the interval was tried first and cannot work: the cap inside one
		# cycle is one leaf either way, so the extra thorn yield banked and never
		# arrived and the evolution measured identical to not owning it. This is the
		# first instalment of a larger bill -- every relic and evolution written against
		# the old launch stream has to be re-expressed against the ring.
		allowance = room
	elif _leaf_raise_remaining <= 0.0:
		allowance = 1
		# Harvest Rate buys cadence, not cells. It used to buy only a faster cut, which
		# the throttle then refused to convert -- measured, the line was worth +0.0%
		# against the bare Adaptation, identical to the digit, because banking more debt
		# per second cannot raise more leaves per second. What the ring wants from it is
		# recovery: how quickly a ring rebuilds after she has had to leave ground behind.
		_leaf_raise_remaining = leaf_raise_interval_seconds / maxf(
			0.05, get_pruning_harvest_rate_multiplier()
		)
	var raised := _raise_cuttings(
		harvest, mini(mini(int(floor(_cutting_debt)), room), allowance)
	)
	_cutting_debt -= float(raised)
	_bury_pioneer_seeds(harvest)
	_fire_deadfall_volley(harvest)
	cycle_pruned.emit(harvest.cell_count, raised)
	return raised

func _has_relic(relic_id: int) -> bool:
	return relic_director != null and relic_director.has(relic_id)

func get_cutting_debt() -> float:
	## Harvest banked toward the next leaf. Read by the suite, which has to be able to
	## see a relic paying into the ring rather than into a number nothing spends.
	return _cutting_debt


func get_gleaning_banked_cells() -> float:
	## Green this hold has been spared for its own kills. It banked Charge until the
	## rework made Charge the wrong currency to pay a ring in, and leaves the wrong one
	## to pay a ring that is already full.
	return _gleaning_banked


func get_upkeep_cells_spared() -> float:
	## Ground the harvest did not have to take, across the run. The relic's whole effect
	## is a subtraction, and a subtraction is invisible in every column the bench prints
	## unless something counts it.
	return _upkeep_spared

func get_green_manure_kills() -> int:
	return _green_manure_kills

func notify_ring_kill(outward: bool) -> void:
	# The ring reports its own kills so two relics can pay out on them without
	# either of them watching the combat loop.
	if get_evolution_rank(Progression.EvolutionId.PIONEER) >= 4:
		# Blood and Soil: what the spikes kill during a cycle is buried with the cut.
		# Banked as a fraction so a single kill is not worth a whole Seed, and capped so
		# a long hold cannot turn the arena into a nursery.
		_pioneer_kill_debt += evolutions.second_flush_seeds_per_kill
		while (
			_pioneer_kill_debt >= 1.0
			and _pioneer_kill_seeds < evolutions.second_flush_kill_seed_cap
		):
			_pioneer_kill_debt -= 1.0
			_pioneer_kill_seeds += 1
	if outward:
		if _has_relic(RelicCatalog.Id.GREEN_MANURE):
			_green_manure_kills += 1
			_green_manure_remaining = green_manure_seconds
			_apply_regrowth()
		return
	if not _has_relic(RelicCatalog.Id.GLEANING_HOOK):
		return
	_gleaning_kills += 1
	if _gleaning_kills < gleaning_hook_kills:
		return
	_gleaning_kills = 0
	# Ring without harvesting: it is paid in blood instead of in Green.
	var payout := minf(
		gleaning_hook_cells, gleaning_hook_maximum_cells - _gleaning_banked
	)
	if payout <= 0.0:
		return
	_gleaning_banked += payout
	# Cancelled off the debt the harvest has yet to take, so the ground is spared before
	# it is cut rather than repaid after. Never below zero: a relic may make the ring
	# cheaper and may not make it free, and a negative debt would bank credit across the
	# quiet stretches the scarcity exists to create.
	_upkeep_debt = maxf(0.0, _upkeep_debt - payout)
	_upkeep_spared += payout
	status_requested.emit("GLEANING HOOK — the ring pays for itself in blood.")

func _advance_brush_volley(delta: float) -> void:
	# The stored clippings go out behind the ring rather than with it, so the volley
	# reads as a second, messier wave instead of thickening the first.
	if _brush_volley.is_empty():
		return
	_brush_volley[0] = float(_brush_volley[0]) - delta
	if float(_brush_volley[0]) > 0.0:
		return
	var wanted := int(_brush_volley[1])
	var damage := float(_brush_volley[2])
	_brush_volley.clear()
	var facing := combat.player.get_facing_direction()
	var fired := 0
	for index in range(wanted):
		var cutting := _get_inactive_cutting()
		if cutting == null:
			break
		var spread := lerpf(-PI * 0.35, PI * 0.35, float(index) / float(maxi(1, wanted - 1)))
		cutting.position = combat.player.get_arena_position()
		cutting.damage = damage
		cutting.spin = facing.rotated(spread).angle()
		cutting.natural_release = false
		cutting.has_ricocheted = false
		cutting.sprout_generation = 0
		_launch_cutting(cutting)
		# Brush Pile spikes are slower and blunter than the ring's, and they cannot
		# start a Watersprout: the relic is a bonus volley, not a second release.
		cutting.velocity = facing.rotated(spread) * cutting_speed_pixels_per_second * 0.90
		cutting.pierce_remaining = 1
		cutting.maximum_travel = 0.0
		fired += 1
	if fired > 0:
		status_requested.emit("BRUSH PILE — the stored clippings go out behind the ring.")


func _advance_callus(delta: float) -> void:
	if _callus_remaining <= 0.0:
		return
	_callus_remaining = maxf(0.0, _callus_remaining - delta)
	if _callus_used or _callus_position.x < 0.0:
		return
	var distance := combat.player.get_arena_position().distance_to(_callus_position)
	if distance > callus_radius_pixels:
		# Standing on the wound when the ring fired is not returning to it. The
		# player has to actually leave before coming back can mean anything.
		_callus_left_wound = true
		return
	if not _callus_left_wound:
		return
	_callus_used = true
	territory_field.attribution = RunStats.Source.PRUNING
	territory_field.queue_seed_growth(
		_callus_position,
		callus_mass,
		callus_control,
		progression.get_conversion_multiplier(),
		1.0
	)
	if overlay != null:
		overlay.spawn_bloom(_callus_position)
	status_requested.emit("CALLUS — the wound knits closed where you stand.")


func _advance_stubble(delta: float) -> void:
	for index in range(_stubble_wounds.size() - 1, -1, -1):
		var wound: Array = _stubble_wounds[index]
		wound[1] = float(wound[1]) - delta
		if float(wound[1]) <= 0.0:
			_stubble_wounds.remove_at(index)
			continue
		var wound_position: Vector2 = wound[0]
		var cooldowns: Dictionary = wound[2]
		for enemy_id in cooldowns.keys():
			var remaining := float(cooldowns[enemy_id]) - delta
			if remaining <= 0.0:
				cooldowns.erase(enemy_id)
			else:
				cooldowns[enemy_id] = remaining
		var damage := (
			cutting_damage
			* get_pruning_cutting_damage_multiplier()
			* stubble_damage_share
		)
		for enemy_id in combat.get_active_enemy_ids():
			if cooldowns.has(enemy_id):
				continue
			if combat.get_enemy_position(enemy_id).distance_to(wound_position) > stubble_radius_pixels:
				continue
			# Reclaimed ground stops cutting. The wound is the hazard, so Green that
			# has grown back over it is no longer sharp.
			if territory_field.get_pruned_ground_at_local(
				combat.get_enemy_position(enemy_id)
			) <= 0.0:
				continue
			cooldowns[enemy_id] = stubble_tick_seconds
			combat.damage_enemy_by_id(
				enemy_id, damage, CombatDirector.DeathSource.RELIC
			)


func get_stubble_wound_count() -> int:
	return _stubble_wounds.size()


func has_pending_brush_volley() -> bool:
	## Whether a release has a Brush Pile volley still to arrive. Read by the suite,
	## which has to be able to tell "paid nothing" from "paid a moment later".
	return not _brush_volley.is_empty()


func get_brush_bundles() -> int:
	return _brush_bundles


func is_callus_armed() -> bool:
	return _callus_remaining > 0.0 and not _callus_used


func _note_stubble_harvest(cells: int, position: Vector2) -> void:
	## Stubble reads "Pruned Ground stays sharp for 5s, damaging enemies that cross the
	## wound", and it was planting its wound at the moment the ring was released.
	##
	## That was a relic about the harvest wired to the launch, and the launch is what
	## the rework demoted: in sustained play the ring is spent rarely and held for a
	## long time, so a Stubble bought for the ground Pruning cuts fired two or three
	## times a minute. Planted by the cut instead, it is worth what its own sentence
	## promises -- the ground she has just worked is dangerous to walk over -- and it
	## does it with every parameter it already had.
	if cells <= 0 or not _has_relic(RelicCatalog.Id.STUBBLE):
		return
	# A wound marks a patch of ground she has cut, and the harvest happens under her
	# several times a second -- so without this the two wounds were re-planted on top of
	# her every cycle and the relic was a damage aura that followed her around, worth
	# +55% on a crowd. Sharp ground is something you leave behind. One wound per patch,
	# spaced by its own radius, and standing still refreshes nothing.
	if not _stubble_wounds.is_empty():
		var newest: Array = _stubble_wounds[_stubble_wounds.size() - 1]
		if (newest[0] as Vector2).distance_to(position) < stubble_radius_pixels:
			return
	if _stubble_wounds.size() >= stubble_maximum_wounds:
		_stubble_wounds.remove_at(0)
	_stubble_wounds.append([position, stubble_seconds, {}])


func _note_brush_harvest(cells: int) -> void:
	# Only what is cut past the halfway mark counts. Below it the harvest is still
	# paying for the ring itself.
	if cells <= 0 or not _has_relic(RelicCatalog.Id.BRUSH_PILE):
		return
	if _charge < brush_pile_charge_threshold:
		return
	if _brush_bundles >= brush_pile_maximum_bundles:
		return
	_brush_cells += cells
	while (
		_brush_cells >= brush_pile_cells_per_bundle
		and _brush_bundles < brush_pile_maximum_bundles
	):
		_brush_cells -= brush_pile_cells_per_bundle
		_brush_bundles += 1


func _try_skimming_cut(cutting: Cutting) -> bool:
	## A natural spike glancing off terrain is redirected once instead of being
	## spent. Returns whether the spike survived the collision.
	if not _has_relic(RelicCatalog.Id.SKIMMING_CUT):
		return false
	if not cutting.natural_release or cutting.has_ricocheted:
		return false
	var target := combat.get_nearest_enemy_position(
		cutting.position, skimming_cut_range_pixels
	)
	if target.x < 0.0:
		return false
	cutting.has_ricocheted = true
	cutting.damage *= skimming_cut_damage_share
	cutting.velocity = (
		cutting.position.direction_to(target)
		* cutting.velocity.length()
		* skimming_cut_speed_share
	)
	cutting.pierce_remaining = maxi(1, cutting.pierce_remaining)
	# A ricochet must never carry the spike through the thing it bounced off, so it
	# is nudged back along its own heading before it resumes.
	cutting.position -= cutting.velocity.normalized() * 2.0
	return true


func _sprout_watersprouts(source: Cutting, from_position: Vector2) -> void:
	## A natural spike that kills sends up seeking children, and those children may
	## branch one final time. Every cap here is absolute: per release, per frame, and
	## two generations deep.
	if not _has_relic(RelicCatalog.Id.WATERSPROUTS):
		return
	if source.sprout_generation >= 2:
		return
	if not source.natural_release and source.sprout_generation == 0:
		return
	if _watersprouts_this_release >= watersprout_release_maximum:
		return
	var generation := source.sprout_generation + 1
	for _child in range(watersprout_children):
		if _watersprouts_this_release >= watersprout_release_maximum:
			return
		if _watersprouts_this_frame >= watersprout_frame_maximum:
			return
		var target := combat.get_nearest_enemy_position(
			from_position, watersprout_range_pixels
		)
		if target.x < 0.0:
			return
		var cutting := _get_inactive_cutting()
		if cutting == null:
			return
		cutting.position = from_position
		cutting.damage = source.damage * watersprout_damage_share
		cutting.spin = from_position.direction_to(target).angle()
		cutting.natural_release = false
		cutting.has_ricocheted = false
		cutting.sprout_generation = generation
		_launch_cutting(cutting)
		cutting.velocity = (
			from_position.direction_to(target)
			* cutting_speed_pixels_per_second
			* watersprout_speed_share
		)
		cutting.pierce_remaining = 1
		cutting.maximum_travel = 0.0
		_watersprouts_this_release += 1
		_watersprouts_this_frame += 1


func _raise_cuttings(harvest: TerritoryField.PruneHarvest, wanted: int) -> int:
	var count := clampi(wanted, 0, maximum_cuttings_per_step)
	if count <= 0 or harvest.positions.is_empty():
		return 0
	# Root Network: a spike is only as hard as the wood it was cut from, so the
	# damage rides the age of the ground this cycle actually took rather than the
	# maturity left behind after the cut — the harvest has already removed it.
	var damage := (
		cutting_damage
		* get_pruning_cutting_damage_multiplier()
		* get_harvest_root_multiplier(harvest)
	)
	var raised := 0
	for index in range(count):
		var cutting := _get_inactive_cutting()
		if cutting == null:
			break
		cutting.state = CuttingState.GATHERING
		cutting.position = harvest.positions[index % harvest.positions.size()]
		cutting.velocity = Vector2.ZERO
		cutting.gather_remaining = cutting_gather_seconds
		cutting.remaining = cutting_lifetime_seconds
		cutting.damage = damage
		cutting.pierce_remaining = cutting_pierce
		cutting.last_hit_enemy_id = -1
		cutting.spin = float(_orbit_sequence + index) * 0.7
		raised += 1
	_cuttings_launched += raised
	return raised

func get_ring_root_multiplier() -> float:
	# Root where the ring is standing. The harvest multiplier below measures a patch,
	# which is right for something cut out of the ground; the ring's own rates --
	# how fast it eats, how fast it charges -- happen at Grandma's feet, so they read
	# the ground she is on the way every other point effect in the game does.
	if root_director == null:
		return 1.0
	return root_director.get_network_multiplier_here(
		combat.player.get_arena_position()
	)


func get_harvest_root_multiplier(harvest: TerritoryField.PruneHarvest) -> float:
	# How old the cut was, as the share of it that came out of Mature ground. Every
	# other path scales Root by the maturity under a single effect; a harvest is a
	# patch rather than a point, so its own Mature share is that same measure. The
	# position is the cut's centre, which is what lets an Annual Rings region or a
	# Seedbed patch deepen the Network for a ring turning inside it.
	if root_director == null or harvest.cell_count <= 0:
		return 1.0
	return root_director.get_network_multiplier_at(
		combat.player.get_arena_position(),
		float(harvest.mature_cell_count) / float(harvest.cell_count)
	)


func is_wilt_imminent() -> bool:
	## Whether the ring is about to lose a leaf, for the warning flash.
	##
	## False at the floor: a ring that cannot shrink any further has nothing to warn
	## about, and a permanently flashing ring would teach the player to ignore it.
	return (
		_unfed_seconds >= wilt_warning_seconds
		and get_orbit_count() > minimum_orbit_leaves
	)

func get_replacement_seconds() -> float:
	# Deadfall's payoff is the rate itself. The Evolution takes the ring from
	# shedding a thorn occasionally to firing them continuously, which is exactly
	# what base Pruning must not do on its own.
	if progression.has_active_evolution(Progression.EvolutionId.DEADFALL):
		return deadfall_replacement_seconds
	return full_ring_replacement_seconds

func _get_committed_ring_count() -> int:
	# Everything the ring already owns: the spikes turning in it and the ones
	# spiralling in to join. A cutting in flight is a slot already spent.
	var count := 0
	for cutting in _cuttings:
		if (
			cutting.state == CuttingState.ORBITING
			or cutting.state == CuttingState.GATHERING
		):
			count += 1
	return count

func _get_inactive_cutting() -> Cutting:
	for cutting in _cuttings:
		if cutting.state == CuttingState.INACTIVE:
			return cutting
	return null

func _advance_cuttings(delta: float) -> void:
	var player_position := combat.player.get_arena_position()
	for cutting in _cuttings:
		match cutting.state:
			CuttingState.GATHERING:
				_advance_gathering_cutting(cutting, player_position, delta)
			CuttingState.LAUNCHED:
				_advance_launched_cutting(cutting, delta)

func _advance_gathering_cutting(
	cutting: Cutting,
	player_position: Vector2,
	delta: float
) -> void:
	# Plant material spirals in toward the player before it takes its place in the
	# ring, which is what makes the harvest read as the ecosystem gathering itself up.
	cutting.gather_remaining -= delta
	var progress := 1.0 - clampf(
		cutting.gather_remaining / maxf(0.01, cutting_gather_seconds),
		0.0,
		1.0
	)
	var toward := player_position - cutting.position
	var swirl := toward.orthogonal().normalized() * (1.0 - progress) * 220.0
	cutting.position += (toward.normalized() * 260.0 * progress + swirl) * delta
	cutting.spin += delta * 12.0
	if cutting.gather_remaining > 0.0:
		return
	# A player standing off their own ground has nothing to hold a ring together with,
	# so whatever had gathered is lost. It used to fly instead, at full damage, and that
	# one branch was the entire path: the harvest takes the cell she stands on, so being
	# off her own footing is the ordinary state of a stationary hold -- 58% of a rooted
	# bench -- and every Cutting raised in that state became a free projectile that never
	# touched the ring. Zeroing the ring's own damage cost a developed Pruning one point
	# out of 7,595; zeroing the Cuttings cost it 78%.
	#
	# Charging the launch less did not fix it, it broke the upgrade tree: at a 30% share
	# `Harvest Rate` measured *below* the bare Adaptation, because the harvest's output in
	# that state is launches and nothing else. Harvesting has to buy ring, or buying more
	# harvest cannot be worth anything. So the ground she spent is simply gone, which is
	# what spending ground on nothing should mean.
	if not is_player_on_green():
		cutting.state = CuttingState.INACTIVE
		return
	cutting.state = CuttingState.ORBITING
	_orbit_sequence += 1
	cutting.orbit_slot = _orbit_sequence
	_trim_orbit()

func _launch_cutting(cutting: Cutting, outward: bool = false) -> void:
	cutting.state = CuttingState.LAUNCHED
	# Set here rather than trusted from the caller. Cuttings are pooled, so a spike
	# recycled out of an earlier discharge still carried `natural_release` when the
	# ring shed it or a gather flew loose -- and that flag is what pays Green Manure,
	# what Skimming Cut redirects and what Watersprouts sprout from, so a recycled
	# spike was quietly claiming all three. Only a discharge is a natural release.
	cutting.natural_release = outward
	cutting.remaining = cutting_lifetime_seconds
	cutting.last_hit_enemy_id = -1
	cutting.pierce_remaining = cutting_pierce
	cutting.pierce_falloff = cutting_pierce_falloff
	if get_evolution_rank(Progression.EvolutionId.DEADFALL) >= 2:
		# Piercing Splinters: the spike goes through one more enemy, and lands softer for
		# doing it, so pierce widens a volley rather than squaring its damage.
		cutting.pierce_remaining += evolutions.splinterstorm_extra_pierce
		cutting.pierce_falloff = evolutions.splinterstorm_pierce_falloff
	var direction := Vector2.from_angle(cutting.spin)
	if outward:
		cutting.pierce_remaining = cutting_pierce + int(round(
			float(launch_pierce_at_charge) * _charge
		))
		cutting.pierce_falloff = launch_pierce_falloff
		# A discharging hoop bursts. Every spike keeps the heading it was already
		# travelling on, so the ring opens into an expanding wall of blades instead of
		# sixteen spikes converging on whichever enemy happened to be closest and
		# overkilling it while the crowd walks past.
		var centre := combat.player.get_arena_position()
		if not cutting.position.is_equal_approx(centre):
			direction = centre.direction_to(cutting.position)
		cutting.velocity = direction * cutting_speed_pixels_per_second
		cutting.travelled = 0.0
		cutting.returning = false
		# Return Stroke turns the spike around once it has run its distance out.
		cutting.maximum_travel = (
			cutting_speed_pixels_per_second * cutting_lifetime_seconds * 0.45
			if _has_relic(RelicCatalog.Id.RETURN_STROKE)
			else 0.0
		)
		return
	var target := combat.get_nearest_enemy_position(cutting.position, 9999.0)
	if target.x >= 0.0:
		direction = cutting.position.direction_to(target)
	cutting.velocity = direction * cutting_speed_pixels_per_second

func _trim_orbit() -> void:
	# A guard, not a mechanic: the harvest refuses to raise a spike the ring has no
	# room for, so this only fires if the capacity itself shrinks underneath a ring
	# that is already turning.
	while get_orbit_count() > get_orbit_capacity():
		var oldest: Cutting = null
		for cutting in _cuttings:
			if cutting.state != CuttingState.ORBITING:
				continue
			if oldest == null or cutting.orbit_slot < oldest.orbit_slot:
				oldest = cutting
		if oldest == null:
			return
		_launch_cutting(oldest)

func _position_orbit(orbiting: int) -> void:
	var centre := combat.player.get_arena_position()
	var radius := get_orbit_radius()
	var index := 0
	for cutting in _cuttings:
		if cutting.state != CuttingState.ORBITING:
			continue
		var angle := _orbit_angle + TAU * float(index) / float(maxi(1, orbiting))
		cutting.position = centre + Vector2.from_angle(angle) * radius
		cutting.spin = angle
		index += 1

func _apply_orbit_damage() -> void:
	# The thicket bites as a whole disc rather than per spike or as a bare hoop. An
	# enemy cannot slip between two blades, and closing to contact does not put it
	# safely inside an empty circle: the runners strung between the spikes sweep the
	# ground the hoop encloses. Each enemy keeps its own cooldown, so the thicket
	# grinds rather than deleting whatever brushes it, and one tick bites a bounded
	# number of them, so a denser crowd is not simply a larger number.
	var centre := combat.player.get_arena_position()
	var radius := get_orbit_radius()
	# Deliberately *not* multiplied by Cutting Damage. That line buys the damage of a
	# launched Cutting -- a finite, aimed thing that hits what the player pointed it
	# at -- and letting it also multiply the thicket put a stat multiplier on top of a
	# quantity already multiplied by how many bodies are standing in the disc. That is
	# the same stacked-axis shape the Thornwhip correction removed, and it is what the
	# rework's own section 35 says to look for first when a build runs away.
	#
	# Charge stays: it is the path's own tension, paid for in ground, and it is the
	# thing that makes holding the ring a decision rather than a default.
	#
	# There used to be a second, softer positional cost stacked here: a multiplier that
	# read how recently the ground underfoot had been stripped and cut both the spike
	# yield and this damage toward a quarter. It was a proxy for a cost the path did not
	# yet have. The harvest now takes the cell she is standing on outright, so the cost
	# is modelled rather than approximated, and keeping the proxy taxed the same
	# decision twice -- measured, it held the ring to six spikes of sixteen while she
	# was grazing properly, which quietly retired `orbit_capacity` and the shed timer
	# built around it.
	# Linear in the spike count, so the ring she has actually built is the ring that
	# bites. See `orbit_lone_spike_damage_share`.
	var spikes := get_orbit_count()
	var fullness := float(spikes) / float(maxi(1, orbit_reference_leaves))
	# Cutting Damage applies here now. It used to scale only loose Cuttings and the
	# volley, so once the ring became the output the line was buying nothing a player
	# could see: base Pruning and Pruning with every line bought measured within 3% of
	# each other. The path's damage line has to scale the path's damage.
	var damage := (
		orbit_contact_damage
		* get_pruning_cutting_damage_multiplier()
		* (1.0 + orbit_charge_damage_bonus * _charge)
		* lerpf(clampf(orbit_lone_spike_damage_share, 0.0, 1.0), 1.0, fullness)
	)
	# Every body anywhere in the ring takes the full bite on its own cooldown. It used
	# to be a budget divided by how many stood in reach, which made the ring's output
	# constant however many it held -- so on the crowds the late run is made of each
	# enemy took a sliver, and the path read as doing nothing. The per-tick cap below
	# still bounds how many it bites at once.
	var reach := radius + orbit_reach_pixels
	var ids := combat.get_active_enemy_ids()
	var positions := combat.get_active_enemy_positions()
	var candidates: Array = []
	for index in range(mini(ids.size(), positions.size())):
		var enemy_id := ids[index]
		var distance := positions[index].distance_to(centre)
		if distance > reach:
			continue
		if _hit_cooldowns.has(enemy_id):
			continue
		candidates.append([distance, enemy_id])
	# Only sorted when the cap actually binds. Most frames every body in the disc is
	# still on its own cooldown, so this is a handful of entries or none at all.
	if candidates.size() > orbit_maximum_targets_per_tick:
		candidates.sort_custom(
			func(first: Array, second: Array) -> bool: return first[0] < second[0]
		)
		candidates.resize(orbit_maximum_targets_per_tick)
	for candidate in candidates:
		var enemy_id: int = candidate[1]
		if combat.damage_enemy_by_id(
			enemy_id,
			damage,
			CombatDirector.DeathSource.CUTTING
		):
			if not combat.is_enemy_active(enemy_id):
				notify_ring_kill(false)
			_hit_cooldowns[enemy_id] = orbit_hit_cooldown_seconds

func _wilt_oldest_spike() -> bool:
	## Drops the ring's oldest spike outright. Returns whether there was one to drop.
	##
	## Wilted rather than launched: a spike that falls off a starving ring is ground
	## that ran out, not a shot she took, and `_launch_cutting` would hand her the
	## damage anyway.
	# The ring recedes toward its floor rather than through it. See
	# `minimum_orbit_leaves`.
	if get_orbit_count() <= minimum_orbit_leaves:
		return false
	var oldest: Cutting = null
	for cutting in _cuttings:
		if cutting.state != CuttingState.ORBITING:
			continue
		if oldest == null or cutting.orbit_slot < oldest.orbit_slot:
			oldest = cutting
	if oldest == null:
		return false
	# The leaf sets its ground down where it fell. See `wilted_leaf_growth_share`; this
	# is what makes a receding ring replant the ground that will refill it.
	if wilted_leaf_growth_share > 0.0 and territory_field != null:
		territory_field.attribution = RunStats.Source.PRUNING
		territory_field.queue_seed_growth(
			oldest.position,
			wilted_leaf_growth_share,
			wilted_leaf_growth_share,
			wilted_leaf_growth_share,
			wilted_leaf_growth_share
		)
	oldest.state = CuttingState.INACTIVE
	_position_orbit(get_orbit_count())
	return true

func _release_ring(message: String, intentional: bool = true) -> void:
	var released := 0
	var release_charge := _charge
	var release_facing := combat.player.get_facing_direction()
	# A torn ring keeps its spikes but mostly not its banked Charge: the payout is the
	# price of a decision, and a ring that came apart because the ground ran out was
	# not one.
	var payout := (
		1.0
		+ get_launch_charge_damage_bonus()
		* release_charge
		* (1.0 if intentional else clampf(torn_ring_charge_share, 0.0, 1.0))
	)
	var espalier_rank := get_evolution_rank(Progression.EvolutionId.ESPALIER)
	var orbiting := get_orbit_count()
	for cutting in _cuttings:
		if cutting.state != CuttingState.ORBITING:
			continue
		# A ring that came apart is lost, not fired. Counted as released so the tear is
		# still reported and still resets the hold, but nothing is thrown: paying her a
		# volley for running out of ground is what made starvation the optimal play, and
		# no share of that volley is small enough to stop being worth chasing while the
		# harvest that causes it is also the thing that feeds it.
		if not intentional:
			cutting.state = CuttingState.INACTIVE
			released += 1
			continue
		# A banked ring hits far harder than a loose Cutting, which is the whole
		# reason to hold one.
		cutting.damage *= payout
		cutting.natural_release = true
		cutting.has_ricocheted = false
		cutting.sprout_generation = 0
		_launch_cutting(cutting, true)
		if espalier_rank >= 1:
			var fan_progress := (
				0.5
				if orbiting <= 1
				else float(released) / float(orbiting - 1)
			)
			var fan_angle := lerpf(-PI * 0.25, PI * 0.25, fan_progress)
			cutting.velocity = (
				release_facing.rotated(fan_angle) * cutting_speed_pixels_per_second
			)
			if espalier_rank >= 2:
				var elongation_bonus := 0.10 * float(
					progression.get_upgrade_level(
						Progression.UpgradeId.VINE_ELONGATION
					)
				)
				cutting.remaining *= 1.0 + elongation_bonus
				cutting.maximum_travel *= 1.0 + elongation_bonus
		released += 1
	var wound_position := combat.player.get_arena_position()
	var bundles := _brush_bundles
	var bonus_damage := (
		cutting_damage
		* get_pruning_cutting_damage_multiplier()
		* payout
		* brush_pile_damage_share
	)
	_charge = 0.0
	_hold_seconds = 0.0
	# The footing debt deliberately survives a discharge. Clearing it here handed the
	# ring a fresh grace the instant it tore, so a player standing on bare ground got
	# an endless cycle of refill-and-tear rather than a path that had run out of
	# ground. Firing the ring does not put the Green back.
	_upkeep_debt = 0.0
	_gleaning_kills = 0
	_gleaning_banked = 0.0
	_green_manure_kills = 0
	# Brush resets completely on release, whether or not it had a full bundle.
	_brush_cells = 0
	_brush_bundles = 0
	_watersprouts_this_release = 0
	if released <= 0:
		return
	# Everything below is paid for a release she *chose*. The rework stopped a tear
	# firing its leaves for exactly one reason -- being paid for running out of ground
	# made starving the ring the optimal play -- and these three were reading `released`
	# rather than `intentional`, so the same reward came straight back through the relic
	# pool. Brush Pile is the plain case: its own wording is "release to fire up to 8
	# extra Cuttings", and a ring that came apart was not released.
	if not intentional:
		return
	if bundles > 0 and _has_relic(RelicCatalog.Id.BRUSH_PILE):
		_brush_volley = [
			brush_pile_delay_seconds,
			bundles * brush_pile_cuttings_per_bundle,
			bonus_damage,
		]
	if _has_relic(RelicCatalog.Id.CALLUS):
		_callus_position = wound_position
		_callus_remaining = callus_window_seconds
		_callus_used = false
		# Standing in the wound at the moment of release does not count as returning.
		_callus_left_wound = false
	_rings_released += 1
	ring_released.emit(released, release_charge, release_facing, intentional)
	status_requested.emit(message)


func fire_espalier_fan(count: int, facing: Vector2, damage_scale: float) -> int:
	## Rank 5's second fan spends no Green and cannot report another release. It
	## reuses the Cutting pool and collision resolver, so Pierce and walls stay exact.
	var wanted := mini(maxi(0, count), cutting_pool_size)
	var fired := 0
	var rank := get_evolution_rank(Progression.EvolutionId.ESPALIER)
	for index in range(wanted):
		var cutting := _get_inactive_cutting()
		if cutting == null:
			break
		var progress := 0.5 if wanted <= 1 else float(index) / float(wanted - 1)
		var angle := lerpf(-PI * 0.25, PI * 0.25, progress)
		cutting.state = CuttingState.LAUNCHED
		cutting.position = combat.player.get_arena_position()
		cutting.velocity = facing.rotated(angle) * cutting_speed_pixels_per_second
		cutting.remaining = cutting_lifetime_seconds
		if rank >= 2:
			cutting.remaining *= 1.0 + 0.10 * float(
				progression.get_upgrade_level(Progression.UpgradeId.VINE_ELONGATION)
			)
		cutting.damage = (
			cutting_damage
			* get_pruning_cutting_damage_multiplier()
			* maxf(0.0, damage_scale)
		)
		cutting.pierce_remaining = cutting_pierce
		cutting.pierce_falloff = cutting_pierce_falloff
		cutting.last_hit_enemy_id = -1
		cutting.travelled = 0.0
		cutting.returning = false
		cutting.maximum_travel = cutting_speed_pixels_per_second * cutting.remaining
		cutting.spin = angle
		fired += 1
	_cuttings_launched += fired
	return fired

func _advance_launched_cutting(cutting: Cutting, delta: float) -> void:
	cutting.remaining -= delta
	if cutting.remaining <= 0.0:
		_finish_cutting(cutting)
		return
	var step := cutting.velocity * delta
	var next_position := cutting.position + step
	# Cuttings are physical blades. Test the entire frame segment against the shared
	# obstacle mask so a fast spike cannot tunnel through a thin wall or rock.
	if not territory_field.is_growth_path_clear(cutting.position, next_position):
		# Skimming Cut turns the first terrain hit into a redirection. A spike that
		# has already glanced once is spent by the next one.
		if not _try_skimming_cut(cutting):
			_finish_cutting(cutting)
		return
	cutting.position = next_position
	if cutting.maximum_travel > 0.0 and not cutting.returning:
		cutting.travelled += step.length()
		if cutting.travelled >= cutting.maximum_travel:
			# The stroke comes back once, softer, and cannot bank Charge or fire a
			# release relic on the way in.
			cutting.returning = true
			cutting.damage *= return_stroke_damage
			cutting.remaining = maxf(cutting.remaining, cutting_lifetime_seconds * 0.6)
			cutting.velocity = (
				cutting.position.direction_to(combat.player.get_arena_position())
				* cutting_speed_pixels_per_second
				* return_stroke_speed
			)
	if not territory_field.contains_local_point(cutting.position):
		_finish_cutting(cutting)
		return
	var struck := combat.damage_first_enemy_in_radius(
		cutting.position,
		cutting_hit_radius_pixels,
		cutting.damage,
		CombatDirector.DeathSource.CUTTING,
		cutting.last_hit_enemy_id
	)
	if struck < 0:
		return
	var struck_position := combat.get_enemy_position(struck)
	cutting.last_hit_enemy_id = struck
	if not combat.is_enemy_active(struck):
		# Green Manure counts only the outward natural pass, so a Watersprout child
		# and a returning stroke are told apart here rather than downstream.
		if cutting.natural_release and not cutting.returning:
			notify_ring_kill(true)
		_sprout_watersprouts(
			cutting,
			struck_position if struck_position.x >= 0.0 else cutting.position
		)
	if (
		get_evolution_rank(Progression.EvolutionId.DEADFALL) >= 3
		and combat.get_enemy_entanglement(struck) >= evolutions.splinterstorm_shatter_threshold
	):
		# Shatter: a spike that finds an enemy already wrapped in thorns has something
		# solid to break against, and comes apart into two smaller ones that go looking
		# for whatever else is nearby. Splitting only on a fully Entangled target keeps
		# it as Bramble's payoff rather than a free doubling on every hit.
		_shatter_cutting(cutting)
	cutting.pierce_remaining -= 1
	# A pierced hit lands softer, so pierce widens a volley rather than squaring it.
	cutting.damage *= cutting.pierce_falloff
	if cutting.pierce_remaining <= 0:
		cutting.state = CuttingState.INACTIVE


func _fire_deadfall_volley(harvest: TerritoryField.PruneHarvest) -> void:
	## Deadfall Volley: a ring of heavy spikes thrown outward on top of whatever the
	## harvest raised. They come from the cut rather than from the ring, so the volley
	## does not eat the orbit the player is holding.
	##
	## On its own clock rather than on the harvest's. Reading the cycle meant the rate
	## was whatever the ground allowed -- several a second on fresh Green, and faster
	## again with Harvest Rate bought -- for a weapon that costs neither ring nor
	## territory. Nothing in the run should be strong enough to stop the run being
	## played, and an uncapped free volley at the harvest's cadence was exactly that.
	if get_evolution_rank(Progression.EvolutionId.DEADFALL) < 5:
		return
	if _deadfall_volley_remaining > 0.0:
		return
	var spikes := evolutions.splinterstorm_volley_spikes
	if spikes <= 0:
		return
	_deadfall_volley_remaining = evolutions.splinterstorm_volley_interval_seconds
	var origin := combat.player.get_arena_position()
	var damage := (
		cutting_damage
		* get_pruning_cutting_damage_multiplier()
		* evolutions.splinterstorm_volley_damage_scale
		* get_harvest_root_multiplier(harvest)
	)
	var launched := 0
	for index in range(spikes):
		var spike := _get_inactive_cutting()
		if spike == null:
			break
		var heading := Vector2.from_angle(TAU * float(index) / float(spikes))
		spike.state = CuttingState.LAUNCHED
		spike.position = origin + heading * cutting_hit_radius_pixels
		spike.velocity = heading * cutting_speed_pixels_per_second
		spike.remaining = cutting_lifetime_seconds
		spike.damage = damage
		# High pierce and a gentle falloff: the doc wants a wall of shrapnel that keeps
		# going through a crowd, with the damage tapering rather than stopping.
		spike.pierce_remaining = evolutions.splinterstorm_volley_pierce
		spike.pierce_falloff = evolutions.splinterstorm_pierce_falloff
		spike.last_hit_enemy_id = -1
		spike.spin = heading.angle()
		spike.travelled = 0.0
		spike.maximum_travel = 0.0
		spike.returning = false
		spike.gather_remaining = 0.0
		launched += 1
	if launched > 0:
		_cuttings_launched += launched
		status_requested.emit("DEADFALL VOLLEY — %d spikes tear outward." % launched)


func _advance_stool_regrowth(_delta: float) -> void:
	## Second Harvest: the cycle's Mature cut is watched, and once enough of it has grown
	## back the ground pays a second volley of Cuttings for free. It is the regrowth
	## itself that triggers it, which is what makes Vigorous Regrowth feed into it.
	if _stool_watch_cells <= 0:
		return
	if get_evolution_rank(Progression.EvolutionId.COPPICING) < 5:
		_stool_watch_cells = 0
		return
	var regrown := territory_field.count_owned_cells_in_radius(
		_stool_watch_position,
		upkeep_radius_pixels
	)
	if float(regrown) < float(_stool_watch_cells) * evolutions.stool_regrowth_second_threshold:
		return
	var reward := _stool_watch_reward
	_stool_watch_cells = 0
	_stool_watch_reward = 0
	if reward <= 0:
		return
	var granted := grant_free_cuttings(reward)
	if granted > 0:
		status_requested.emit(
			"SECOND HARVEST — the regrowth gives back %d Cuttings." % granted
		)


func _shatter_cutting(source: Cutting) -> void:
	for side in [-1.0, 1.0]:
		var splinter := _get_inactive_cutting()
		if splinter == null:
			return
		var target := combat.get_nearest_enemy_position(
			source.position,
			evolutions.splinterstorm_shatter_seek_pixels
		)
		var heading := source.velocity.normalized()
		if heading == Vector2.ZERO:
			heading = Vector2.RIGHT
		# Each half leaves at an angle and then turns toward whatever it can find, so a
		# shatter reads as the spike bursting rather than as two clones carrying on.
		heading = heading.rotated(side * 0.6)
		if target.x >= 0.0:
			heading = source.position.direction_to(target)
		splinter.state = CuttingState.LAUNCHED
		splinter.position = source.position
		splinter.velocity = heading * cutting_speed_pixels_per_second
		splinter.remaining = cutting_lifetime_seconds * 0.6
		splinter.damage = source.damage * evolutions.splinterstorm_shatter_share
		splinter.pierce_remaining = 1
		splinter.pierce_falloff = cutting_pierce_falloff
		splinter.last_hit_enemy_id = source.last_hit_enemy_id
		splinter.spin = heading.angle()
		splinter.travelled = 0.0
		splinter.maximum_travel = 0.0
		splinter.returning = false
		splinter.gather_remaining = 0.0
		_cuttings_launched += 1

func _finish_cutting(cutting: Cutting) -> void:
	cutting.state = CuttingState.INACTIVE
	cutting.returning = false
	cutting.travelled = 0.0
	cutting.maximum_travel = 0.0

func _draw_thicket() -> void:
	# The disc has to read as plant matter rather than as a magic aura, so it is drawn
	# as what it is: severed runners strung between the spikes, with cut leaf litter
	# turning over the ground they enclose.
	var orbiting := get_orbit_count()
	if orbiting <= 0:
		return
	var centre := combat.player.get_arena_position()
	var radius := get_orbit_radius()
	var hoop: PackedVector2Array = PackedVector2Array()
	for cutting in _cuttings:
		if cutting.state == CuttingState.ORBITING:
			hoop.append(cutting.position)
	if hoop.is_empty():
		return
	var tint := Color(0.52, 0.78, 0.36, 0.16).lerp(
		Color(0.86, 0.74, 0.24, 0.30),
		_charge
	)
	draw_circle(centre, radius, Color(tint.r, tint.g, tint.b, tint.a * 0.45))
	# Runners strung spike to spike: the hoop is woven, not drawn.
	for index in range(hoop.size()):
		var here := hoop[index]
		var next := hoop[(index + 1) % hoop.size()]
		var midpoint := (here + next) * 0.5
		var slack := centre.direction_to(midpoint) * 3.0
		draw_line(here, midpoint - slack, tint, 1.6, true)
		draw_line(midpoint - slack, next, tint, 1.6, true)
	# The ready tell: a hoop of light standing just outside the ring, beating on its
	# own clock. Drawn over the woven runners rather than tinted into them, because
	# the whole point is that it is not more of the Charge gradient.
	var pulse := _get_full_charge_pulse()
	if pulse > 0.0:
		var glow := full_charge_pulse_color
		draw_arc(
			centre,
			radius + full_charge_hoop_offset_pixels,
			0.0,
			TAU,
			48,
			Color(glow.r, glow.g, glow.b, glow.a * 0.85 * pulse),
			2.4 * pulse,
			true
		)
	# Cut litter turning over the enclosed ground, so the interior reads as swept
	# rather than as empty space inside a circle.
	var litter := Color(0.74, 0.86, 0.48, 0.34 + 0.28 * _charge)
	for index in range(9):
		var swirl := _orbit_angle * (1.0 + 0.35 * float(index % 3)) + float(index) * 0.7
		var reach := radius * (0.24 + 0.09 * float(index % 7))
		var leaf := centre + Vector2.from_angle(swirl) * reach
		var stem := Vector2.from_angle(swirl + PI * 0.5) * 2.6
		draw_line(leaf - stem, leaf + stem, litter, 1.4, true)

func get_evolution_rank(evolution_id: int) -> int:
	## The rank of this pairing's own Evolution line, or zero for a run holding a
	## different pairing. Every rank check below reads this rather than the raw level,
	## so a line can never be read by the Evolution it does not belong to.
	return progression.get_evolution_rank(evolution_id)


func _bury_pioneer_seeds(harvest: TerritoryField.PruneHarvest) -> void:
	# Coppice: the cut ground is seeded as it is taken, and germinates together a
	# moment later, so the harvest reads as retract, kill, then erupt.
	if not progression.has_active_evolution(Progression.EvolutionId.PIONEER):
		return
	if harvest.positions.is_empty():
		return
	var rank := get_evolution_rank(Progression.EvolutionId.PIONEER)
	# Dense Reseeding: the same cut buys more Seeds. Paid into the debt rather than into
	# the cap, so a small harvest gets denser instead of a large one simply reaching the
	# ceiling sooner.
	var density := 1.0 + evolutions.second_flush_seed_bonus * (1.0 if rank >= 1 else 0.0)
	_pioneer_debt += float(harvest.cell_count) * density
	# Blood and Soil: the kills the ring made during this cycle are worth Seeds of their
	# own, capped so a long hold cannot bury the whole board.
	if rank >= 4 and _pioneer_kill_seeds > 0:
		_pioneer_debt += float(_pioneer_kill_seeds) * float(evolutions.pioneer_cells_per_seed)
		_pioneer_kill_seeds = 0
	var capacity := evolutions.pioneer_seeds
	if rank >= 4:
		capacity += evolutions.second_flush_kill_seed_cap
	while _pioneer_debt >= float(evolutions.pioneer_cells_per_seed):
		_pioneer_debt -= float(evolutions.pioneer_cells_per_seed)
		if _pioneer_sites.size() >= capacity:
			break
		_pioneer_sites.append(
			harvest.positions[_pioneer_sites.size() % harvest.positions.size()]
		)
	if not _pioneer_sites.is_empty() and _pioneer_remaining <= 0.0:
		_pioneer_remaining = evolutions.pioneer_delay_seconds

func _advance_pioneer(delta: float) -> void:
	if _pioneer_remaining <= 0.0:
		return
	_pioneer_remaining -= delta
	if _pioneer_remaining > 0.0:
		return
	var rank := get_evolution_rank(Progression.EvolutionId.PIONEER)
	# Rapid Germination: the buried Seeds spend less time as a target before they open.
	var charge := -1.0
	if rank >= 2:
		charge = (
			territory_field.tuning.seed_charge_seconds
			* (1.0 - evolutions.second_flush_germination_cut)
		)
	# Remembered before the list is cleared, so a second wave has somewhere to land.
	_last_pioneer_positions = _pioneer_sites.duplicate()
	var planted := 0
	for site in _pioneer_sites:
		overlay.spawn_seed(
			site, charge, 0, evolutions.pioneer_seed_durability, RunStats.Source.PRUNING
		)
		planted += 1
	# Second Flush: every few eruptions the ground gives a second, smaller wave a moment
	# later. Held here rather than buried again through the harvest, because it must not
	# cost the run another cut to receive it.
	var pending := _pioneer_second_wave
	_pioneer_second_wave = PackedVector2Array()
	_pioneer_sites = PackedVector2Array()
	if planted > 0:
		_pioneer_eruptions += 1
		if (
			rank >= 5
			and evolutions.second_flush_wave_cadence > 0
			and _pioneer_eruptions % evolutions.second_flush_wave_cadence == 0
		):
			var wave_count := maxi(1, roundi(float(planted) * evolutions.second_flush_wave_share))
			for index in range(wave_count):
				_pioneer_second_wave.append(_last_pioneer_site(index))
			_pioneer_remaining = evolutions.pioneer_delay_seconds
		status_requested.emit(
			"PIONEER — %d Seeds erupt out of the ground the harvest cut." % planted
		)
	if not pending.is_empty():
		for site in pending:
			overlay.spawn_seed(
				site, charge, 0, evolutions.pioneer_seed_durability, RunStats.Source.PRUNING
			)
		status_requested.emit(
			"SECOND FLUSH — the cut ground gives a second wave of %d Seeds." % pending.size()
		)


func _last_pioneer_site(index: int) -> Vector2:
	if _last_pioneer_positions.is_empty():
		return combat.player.get_arena_position()
	return _last_pioneer_positions[index % _last_pioneer_positions.size()]

func _draw() -> void:
	_draw_thicket()
	for cutting in _cuttings:
		if cutting.state == CuttingState.INACTIVE:
			continue
		var body := Color(0.78, 0.90, 0.55, 0.95)
		if cutting.state == CuttingState.GATHERING:
			var leaf := Vector2.from_angle(cutting.spin) * 4.6
			draw_line(cutting.position - leaf, cutting.position + leaf, body, 2.0, true)
			continue
		if cutting.state == CuttingState.ORBITING:
			# Charge is drawn into the spikes themselves: a banked ring is longer,
			# brighter, and visibly turning faster.
			var loaded := Color(0.86, 1.0, 0.62, 0.95).lerp(
				Color(1.0, 0.92, 0.44, 1.0),
				_charge
			)
			var blade := Vector2.from_angle(cutting.spin + PI * 0.5) * (5.0 + 4.0 * _charge)
			draw_line(
				cutting.position - blade,
				cutting.position + blade,
				loaded,
				2.2 + 1.2 * _charge,
				true
			)
			draw_circle(cutting.position, 1.8 + 0.8 * _charge, loaded)
			# About to lose a leaf: the whole ring flares so the warning reads as the
			# ring's state rather than as one spike misbehaving. Drawn over the blade and
			# under the Charge halo, so a charged ring that is also starving shows both.
			if is_wilt_imminent():
				var warn := 0.5 + 0.5 * sin(_orbit_angle * 9.0)
				draw_circle(
					cutting.position,
					3.4 + 1.6 * warn,
					Color(1.0, 0.72, 0.36, 0.30 + 0.45 * warn)
				)
			var spike_pulse := _get_full_charge_pulse()
			if spike_pulse > 0.0:
				var halo := full_charge_pulse_color
				draw_circle(
					cutting.position,
					full_charge_halo_pixels * spike_pulse,
					Color(halo.r, halo.g, halo.b, halo.a * 0.32 * spike_pulse)
				)
			continue
		var direction := cutting.velocity.normalized()
		draw_line(
			cutting.position - direction * 7.0,
			cutting.position + direction * 4.0,
			body,
			2.4,
			true
		)
		draw_circle(cutting.position + direction * 4.0, 1.8, Color(0.94, 1.0, 0.80, 0.95))

func get_pruning_harvest_rate_multiplier() -> float:
	return 1.0 + pruning_harvest_rate_per_level * float(
		progression.get_upgrade_level(Progression.UpgradeId.PRUNING_HARVEST_RATE)
	)

func get_pruning_cutting_yield_multiplier() -> float:
	# Efficiency only: more spikes out of the same ground. Harvest Rate is the one
	# line that spends more territory, and it is priced as a trade rather than a gain.
	return 1.0 + pruning_cutting_yield_per_level * float(
		progression.get_upgrade_level(Progression.UpgradeId.PRUNING_CUTTING_YIELD)
	)

func get_pruning_cutting_damage_multiplier() -> float:
	return 1.0 + pruning_cutting_damage_per_level * float(
		progression.get_upgrade_level(Progression.UpgradeId.PRUNING_CUTTING_DAMAGE)
	)

func get_pruning_charge_multiplier() -> float:
	return 1.0 + pruning_charge_per_level * float(
		progression.get_upgrade_level(Progression.UpgradeId.PRUNING_CHARGE)
	)
