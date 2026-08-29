class_name PhaseBPruningDirector
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

@export_group("Collaborators")
## Evolutions component that owns the tuning for every Evolution this path takes
## part in. The behaviour stays here; the numbers live in one place.
@export var evolutions: PhaseBEvolutions

## Authoritative field the harvest cuts from and the Pruned Ground belongs to.
@export var territory_field: TerritoryField
## Overlay used for the Seed visuals the Spore pairing germinates.
@export var overlay: TerritoryPrototypeOverlay
## Combat component supplying the player position and taking Cutting damage.
@export var combat: PhaseBCombatDirector
## Progression component that supplies upgrade and evolution modifiers.
@export var progression: PhaseBProgression
## Relic component consulted for the Pruning relics. Optional: without it the
## path behaves exactly as authored.
@export var relic_director: PhaseBRelicDirector
## Root component supplying the Root Network amplification a cut reads. Optional:
## without it a Cutting is worth the same whatever age of Green it came out of.
@export var root_director: PhaseBRootDirector

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
## Ground immediately under the player the harvest will not cut. The harvest only
## runs while the player is standing on their own Green, so cutting the cell they
## are standing on stops the harvest after a single step. Sparing this much leaves
## the footing intact and opens the hole in a ring around the player, which is also
## what makes the cut legible: a hole exactly underneath is hidden by the Gardener.
@export_range(0.0, 60.0, 0.5) var upkeep_inner_radius_pixels := 7.0
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
@export_range(1.0, 300.0, 1.0) var cutting_damage := 26.0
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
@export_range(1, 40, 1) var orbit_capacity := 16
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
@export_range(0.0, 200.0, 1.0) var orbit_radius_growth_pixels := 26.0
## Radians per second the ring turns at zero Charge.
@export_range(0.1, 12.0, 0.1) var orbit_speed_radians := 2.4
## Extra turn rate at full Charge, which is what makes a banked ring read as loaded.
@export_range(0.0, 12.0, 0.1) var orbit_speed_charge_bonus := 3.4
## Arena pixels past the hoop that the dragged runners still reach. Everything
## inside the hoop is caught as well: the spikes are tied together by severed
## runners that sweep the whole enclosed ground, so an enemy that closes to contact
## is standing in the thicket rather than safely inside a bare circle.
@export_range(2.0, 60.0, 1.0) var orbit_reach_pixels := 18.0
## Damage one pass of the ring deals before Cutting Damage and Charge. This is a
## glass cannon: the ring kills what stands in it, and it costs the ecosystem.
@export_range(0.5, 200.0, 0.5) var orbit_contact_damage := 26.0
## Seconds before the ring may strike the same enemy again.
@export_range(0.05, 3.0, 0.05) var orbit_hit_cooldown_seconds := 0.35

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

@export_group("Vegetative Propagation")

@export_group("Relics")
## Ring kills between Gleaning Hook's free Charge.
@export_range(1, 40, 1) var gleaning_hook_kills := 8
## Charge one Gleaning Hook payout is worth.
@export_range(0.01, 0.5, 0.01) var gleaning_hook_charge := 0.05
## Most Charge Gleaning Hook may add across a single hold.
@export_range(0.01, 1.0, 0.01) var gleaning_hook_maximum := 0.15
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
## Sap banked per second spent harvesting Mature Green under Stored Sap.
@export_range(0.05, 5.0, 0.05) var stored_sap_per_second := 0.65
## Sap one hold may bank.
@export_range(0.5, 40.0, 0.5) var stored_sap_maximum := 8.0
## Maturity a Sap surge feeds back into surviving Mature Green per unit of Sap.
@export_range(0.0, 0.5, 0.005) var stored_sap_maturity := 0.055
## Radius in pixels a released Sap surge covers.
@export_range(40.0, 600.0, 5.0) var stored_sap_radius_pixels := 190.0
## How wide Root Memory feeds maturity back, as a multiple of the harvest's own reach.
@export_range(0.5, 8.0, 0.1) var stool_regrowth_memory_radius_multiplier := 2.4

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
var _gleaning_banked := 0.0
var _green_manure_kills := 0
var _green_manure_remaining := 0.0
var _stored_sap := 0.0
var _cycles_run := 0
var _cuttings_launched := 0
var _cutting_debt := 0.0
var _replacement_remaining := 0.0
var _last_cycle_cells := 0
var _charge := 0.0
var _orbit_angle := 0.0
var _orbit_sequence := 0
var _hit_cooldowns := {}
var _upkeep_debt := 0.0
var _upkeep_cells_taken := 0
var _rings_released := 0
var _holding := false
var _hold_seconds := 0.0

func _ready() -> void:
	assert(territory_field != null, "PhaseBPruningDirector requires TerritoryField")
	assert(overlay != null, "PhaseBPruningDirector requires TerritoryPrototypeOverlay")
	assert(combat != null, "PhaseBPruningDirector requires PhaseBCombatDirector")
	assert(progression != null, "PhaseBPruningDirector requires PhaseBProgression")
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
	_green_manure_kills = 0
	_green_manure_remaining = 0.0
	_stored_sap = 0.0
	_cycles_run = 0
	_cuttings_launched = 0
	_cutting_debt = 0.0
	_replacement_remaining = 0.0
	_last_cycle_cells = 0
	_charge = 0.0
	_orbit_angle = 0.0
	_orbit_sequence = 0
	_hit_cooldowns.clear()
	_upkeep_debt = 0.0
	_upkeep_cells_taken = 0
	_rings_released = 0
	_holding = false
	_hold_seconds = 0.0
	queue_redraw()

func advance(delta: float) -> void:
	if _green_manure_remaining > 0.0:
		_green_manure_remaining = maxf(0.0, _green_manure_remaining - delta)
		if _green_manure_remaining <= 0.0:
			_green_manure_kills = 0
			_apply_regrowth()
	_advance_ring(delta)
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

func is_holding() -> bool:
	return _holding

func get_orbit_count() -> int:
	var count := 0
	for cutting in _cuttings:
		if cutting.state == CuttingState.ORBITING:
			count += 1
	return count

func get_orbit_radius() -> float:
	var fullness := float(get_orbit_count()) / float(maxi(1, orbit_capacity))
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
	if get_orbit_count() >= orbit_capacity:
		rate = lerpf(
			maintenance_cells_per_second,
			maintenance_cells_per_second_at_charge,
			_charge
		)
	# On top of that, the drain climbs for every second the ring has gone without
	# firing. Charge alone caps after a few seconds, which left a single patch of
	# Green able to feed a ring indefinitely; this is what gives every hold an end.
	rate += upkeep_escalation_per_second * _hold_seconds
	return (
		minf(maximum_upkeep_cells_per_second, rate)
		* get_pruning_harvest_rate_multiplier()
	)

func get_hold_seconds() -> float:
	return _hold_seconds

func get_upkeep_cells_taken() -> int:
	return _upkeep_cells_taken

func get_rings_released() -> int:
	return _rings_released

func get_charge_seconds() -> float:
	return charge_seconds / maxf(0.05, get_pruning_charge_multiplier())

func get_launch_charge_damage_bonus() -> float:
	return launch_charge_damage_bonus * get_pruning_charge_multiplier()

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
	if not progression.has_active_evolution(PhaseBProgression.EvolutionId.REBOUND):
		return 0.0
	if not is_above_safety_floor():
		return 0.0
	var rank := get_evolution_rank(PhaseBProgression.EvolutionId.REBOUND)
	# Elastic Growth: the crater keeps its accelerated reclaim for longer, so the ground
	# Rebound spends comes back rather than being a permanent hole in the organism.
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
	var harvest := territory_field.prune_territory_in_radius(
		local_position,
		evolutions.rebound_radius_pixels,
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
		PhaseBCombatDirector.DeathSource.BLOOM
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
	var room := maxi(0, orbit_capacity - _get_committed_ring_count())
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
	if _holding and get_orbit_count() > 0:
		territory_field.set_pruned_regrowth(0.0)
		return
	var regrowth := pruned_regrowth_per_second
	if progression.has_active_evolution(PhaseBProgression.EvolutionId.COPPICING):
		# Coppicing: the Root Network drives the cut ground back much faster.
		regrowth *= evolutions.coppicing_regrowth_multiplier
		if get_evolution_rank(PhaseBProgression.EvolutionId.COPPICING) >= 2:
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
	var can_hold := (
		progression.has_path_active(PhaseBProgression.PathId.PRUNING)
		and is_player_on_green()
		and is_above_safety_floor()
	)
	if not can_hold:
		if get_orbit_count() > 0:
			# Stepping off your own ground throws the ring outward.
			_release_ring("PRUNING — the ring tore loose as you left the Green.")
		_holding = false
		_charge = 0.0
		_hold_seconds = 0.0
		_upkeep_debt = 0.0
		return
	_holding = true
	_hold_seconds += delta
	_charge = minf(1.0, _charge + delta / maxf(0.05, get_charge_seconds()))
	_run_harvest(delta)
	_turn_ring(delta)

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
	_advance_stored_sap(delta)
	_replacement_remaining = maxf(0.0, _replacement_remaining - delta)
	_upkeep_debt += get_upkeep_cells_per_second() * delta
	if _upkeep_debt < 1.0:
		return
	if get_orbit_count() >= orbit_capacity and not is_above_safety_floor():
		# A finished ring on an exhausted ecosystem simply stops eating rather than
		# throwing itself away.
		_upkeep_debt = 0.0
		return
	var wanted := int(floor(_upkeep_debt))
	_upkeep_debt -= float(wanted)
	_harvest(wanted)
	if _last_cycle_cells > 0:
		return
	# Nothing left underfoot, so there is nothing feeding the ring any longer.
	if get_orbit_count() > 0:
		_release_ring("PRUNING — nothing left underfoot; the ring fired.", false)
	_holding = false
	_charge = 0.0
	_hold_seconds = 0.0

func _harvest(wanted_cells: int) -> int:
	if wanted_cells <= 0:
		return 0
	if not is_above_safety_floor():
		# The floor is not a failure: it is the path refusing to kill its own run.
		_last_cycle_cells = 0
		return 0
	var harvest := territory_field.drain_territory_in_radius(
		combat.player.get_arena_position(),
		upkeep_radius_pixels,
		wanted_cells,
		pruned_ground_seconds,
		upkeep_inner_radius_pixels
	)
	_last_cycle_cells = harvest.cell_count
	if harvest.cell_count <= 0:
		return 0
	_cycles_run += 1
	_upkeep_cells_taken += harvest.cell_count
	# A full ring still sheds its oldest spike to take a new one — that is the ring
	# turning over, and it should happen. What it must not do is happen three times
	# a second: unthrottled, holding a finished ring was a free homing volley on tap
	# and the disc itself stopped being the damage. Between sheds the ground is
	# still spent, so holding a full ring costs territory either way.
	if _get_committed_ring_count() >= orbit_capacity:
		if _replacement_remaining > 0.0:
			# Bank toward the next shed rather than discarding it, but never bank
			# more than the one spike a shed is allowed to raise: a full ring must
			# not save up a volley to dump the moment the timer elapses.
			_cutting_debt = minf(_cutting_debt + float(harvest.cell_count) * cuttings_per_cell, 1.0)
			return 0
		_replacement_remaining = get_replacement_seconds()
	var cuttings := float(harvest.cell_count) * cuttings_per_cell
	if progression.has_active_evolution(PhaseBProgression.EvolutionId.DEADFALL):
		# Deadfall: the thorns torn out with the Green become spikes of their own.
		# Thorn Harvest, twice: the same thorned cut is worth more of them.
		var splinter_rank := get_evolution_rank(PhaseBProgression.EvolutionId.DEADFALL)
		var thorn_yield := evolutions.deadfall_cuttings_per_development
		if splinter_rank >= 1:
			thorn_yield *= 1.0 + evolutions.splinterstorm_yield_bonus
		if splinter_rank >= 4:
			thorn_yield *= 1.0 + evolutions.splinterstorm_yield_bonus
		cuttings += harvest.bramble_development * thorn_yield
	if progression.has_active_evolution(PhaseBProgression.EvolutionId.COPPICING):
		# Coppicing: ancient ground is worth far more when it is finally cut.
		# Mature Harvest, twice: more of it still.
		var stool_rank := get_evolution_rank(PhaseBProgression.EvolutionId.COPPICING)
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
	cuttings *= get_pruning_cutting_yield_multiplier()
	_cutting_debt += cuttings
	# A ring with room fills as fast as the harvest pays for it; a full one takes
	# exactly one replacement per shed rather than dumping whatever has banked.
	var room := maxi(0, orbit_capacity - _get_committed_ring_count())
	if room <= 0:
		room = 1
	var raised := _raise_cuttings(harvest, mini(int(floor(_cutting_debt)), room))
	_cutting_debt -= float(raised)
	_bury_pioneer_seeds(harvest)
	_fire_deadfall_volley(harvest)
	cycle_pruned.emit(harvest.cell_count, raised)
	return raised

func _has_relic(relic_id: int) -> bool:
	return relic_director != null and relic_director.has(relic_id)

func get_stored_sap() -> float:
	return _stored_sap

func get_gleaning_banked_charge() -> float:
	return _gleaning_banked

func get_green_manure_kills() -> int:
	return _green_manure_kills

func notify_ring_kill(outward: bool) -> void:
	# The ring reports its own kills so two relics can pay out on them without
	# either of them watching the combat loop.
	if get_evolution_rank(PhaseBProgression.EvolutionId.PIONEER) >= 4:
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
		if _has_relic(PhaseBRelicCatalog.Id.GREEN_MANURE):
			_green_manure_kills += 1
			_green_manure_remaining = green_manure_seconds
			_apply_regrowth()
		return
	if not _has_relic(PhaseBRelicCatalog.Id.GLEANING_HOOK):
		return
	_gleaning_kills += 1
	if _gleaning_kills < gleaning_hook_kills:
		return
	_gleaning_kills = 0
	# Charge without harvesting: the ring is paid in blood instead of in Green.
	var payout := minf(gleaning_hook_charge, gleaning_hook_maximum - _gleaning_banked)
	if payout <= 0.0:
		return
	_gleaning_banked += payout
	_charge = clampf(_charge + payout, 0.0, 1.0)
	status_requested.emit("GLEANING HOOK — the ring banks Charge off its own kills.")

func _advance_stored_sap(delta: float) -> void:
	if not _has_relic(PhaseBRelicCatalog.Id.STORED_SAP):
		_stored_sap = 0.0
		return
	if not _holding or get_orbit_count() <= 0:
		return
	if not territory_field.is_mature_player_territory_at_local(
		combat.player.get_arena_position()
	):
		return
	_stored_sap = minf(stored_sap_maximum, _stored_sap + stored_sap_per_second * delta)

func _release_stored_sap() -> void:
	if _stored_sap <= 0.0:
		return
	var sap := _stored_sap
	_stored_sap = 0.0
	var centre := combat.player.get_arena_position()
	var fed := 0
	for index in range(6):
		var site := territory_field.find_mature_player_frontier_near(
			centre + Vector2.from_angle(float(index) * 1.047) * stored_sap_radius_pixels * 0.6
		)
		if site.x < 0.0:
			continue
		# The surge feeds maturity back into ground that survived the harvest,
		# which is what makes Root and Pruning worth running together.
		territory_field.queue_maturity_support(site, sap * stored_sap_maturity, 1.6)
		overlay.spawn_bloom(site)
		fed += 1
	if fed > 0:
		status_requested.emit(
			"STORED SAP — %.1f Sap surges back into the old ground." % sap
		)

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


func get_replacement_seconds() -> float:
	# Deadfall's payoff is the rate itself. The Evolution takes the ring from
	# shedding a thorn occasionally to firing them continuously, which is exactly
	# what base Pruning must not do on its own.
	if progression.has_active_evolution(PhaseBProgression.EvolutionId.DEADFALL):
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
	# A player standing off their own ground has nothing to hold a ring together
	# with, so whatever had gathered simply flies.
	if not is_player_on_green():
		_launch_cutting(cutting)
		return
	cutting.state = CuttingState.ORBITING
	_orbit_sequence += 1
	cutting.orbit_slot = _orbit_sequence
	_trim_orbit()

func _launch_cutting(cutting: Cutting, outward: bool = false) -> void:
	cutting.state = CuttingState.LAUNCHED
	cutting.remaining = cutting_lifetime_seconds
	cutting.last_hit_enemy_id = -1
	cutting.pierce_remaining = cutting_pierce
	cutting.pierce_falloff = cutting_pierce_falloff
	if get_evolution_rank(PhaseBProgression.EvolutionId.DEADFALL) >= 2:
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
			if _has_relic(PhaseBRelicCatalog.Id.RETURN_STROKE)
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
	while get_orbit_count() > orbit_capacity:
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
	# grinds rather than deleting whatever brushes it.
	var centre := combat.player.get_arena_position()
	var radius := get_orbit_radius()
	var damage := (
		orbit_contact_damage
		* get_pruning_cutting_damage_multiplier()
		* (1.0 + orbit_charge_damage_bonus * _charge)
	)
	var reach := radius + orbit_reach_pixels
	var ids := combat.get_active_enemy_ids()
	var positions := combat.get_active_enemy_positions()
	for index in range(mini(ids.size(), positions.size())):
		var enemy_id := ids[index]
		if _hit_cooldowns.has(enemy_id):
			continue
		if positions[index].distance_to(centre) > reach:
			continue
		if combat.damage_enemy_by_id(
			enemy_id,
			damage,
			PhaseBCombatDirector.DeathSource.CUTTING
		):
			if not combat.is_enemy_active(enemy_id):
				notify_ring_kill(false)
			_hit_cooldowns[enemy_id] = orbit_hit_cooldown_seconds

func _release_ring(message: String, intentional: bool = true) -> void:
	var released := 0
	var release_charge := _charge
	var release_facing := combat.player.get_facing_direction()
	var payout := 1.0 + get_launch_charge_damage_bonus() * release_charge
	var espalier_rank := get_evolution_rank(PhaseBProgression.EvolutionId.ESPALIER)
	var orbiting := get_orbit_count()
	for cutting in _cuttings:
		if cutting.state != CuttingState.ORBITING:
			continue
		# A banked ring hits far harder than a loose Cutting, which is the whole
		# reason to hold one.
		cutting.damage *= payout
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
						PhaseBProgression.UpgradeId.VINE_ELONGATION
					)
				)
				cutting.remaining *= 1.0 + elongation_bonus
				cutting.maximum_travel *= 1.0 + elongation_bonus
		released += 1
	_release_stored_sap()
	_charge = 0.0
	_hold_seconds = 0.0
	_upkeep_debt = 0.0
	_gleaning_kills = 0
	_gleaning_banked = 0.0
	_green_manure_kills = 0
	if released <= 0:
		return
	_rings_released += 1
	ring_released.emit(released, release_charge, release_facing, intentional)
	status_requested.emit(message)


func fire_espalier_fan(count: int, facing: Vector2, damage_scale: float) -> int:
	## Rank 5's second fan spends no Green and cannot report another release. It
	## reuses the Cutting pool and collision resolver, so Pierce and walls stay exact.
	var wanted := mini(maxi(0, count), cutting_pool_size)
	var fired := 0
	var rank := get_evolution_rank(PhaseBProgression.EvolutionId.ESPALIER)
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
				progression.get_upgrade_level(PhaseBProgression.UpgradeId.VINE_ELONGATION)
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
		PhaseBCombatDirector.DeathSource.CUTTING,
		cutting.last_hit_enemy_id
	)
	if struck < 0:
		return
	cutting.last_hit_enemy_id = struck
	if not combat.is_enemy_active(struck):
		notify_ring_kill(true)
	if (
		get_evolution_rank(PhaseBProgression.EvolutionId.DEADFALL) >= 3
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
	## Deadfall Volley: every cycle throws a ring of heavy spikes outward on top of
	## whatever the harvest raised. They come from the cut rather than from the ring, so
	## the volley does not eat the orbit the player is holding.
	if get_evolution_rank(PhaseBProgression.EvolutionId.DEADFALL) < 5:
		return
	var spikes := evolutions.splinterstorm_volley_spikes
	if spikes <= 0:
		return
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
	if get_evolution_rank(PhaseBProgression.EvolutionId.COPPICING) < 5:
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
	if not progression.has_active_evolution(evolution_id):
		return 0
	return progression.get_evolution_upgrade_level()


func _bury_pioneer_seeds(harvest: TerritoryField.PruneHarvest) -> void:
	# Coppice: the cut ground is seeded as it is taken, and germinates together a
	# moment later, so the harvest reads as retract, kill, then erupt.
	if not progression.has_active_evolution(PhaseBProgression.EvolutionId.PIONEER):
		return
	if harvest.positions.is_empty():
		return
	var rank := get_evolution_rank(PhaseBProgression.EvolutionId.PIONEER)
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
	var rank := get_evolution_rank(PhaseBProgression.EvolutionId.PIONEER)
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
		overlay.spawn_seed(site, charge, 0, evolutions.pioneer_seed_durability)
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
			overlay.spawn_seed(site, charge, 0, evolutions.pioneer_seed_durability)
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
		progression.get_upgrade_level(PhaseBProgression.UpgradeId.PRUNING_HARVEST_RATE)
	)

func get_pruning_cutting_yield_multiplier() -> float:
	# Efficiency only: more spikes out of the same ground. Harvest Rate is the one
	# line that spends more territory, and it is priced as a trade rather than a gain.
	return 1.0 + pruning_cutting_yield_per_level * float(
		progression.get_upgrade_level(PhaseBProgression.UpgradeId.PRUNING_CUTTING_YIELD)
	)

func get_pruning_cutting_damage_multiplier() -> float:
	return 1.0 + pruning_cutting_damage_per_level * float(
		progression.get_upgrade_level(PhaseBProgression.UpgradeId.PRUNING_CUTTING_DAMAGE)
	)

func get_pruning_charge_multiplier() -> float:
	return 1.0 + pruning_charge_per_level * float(
		progression.get_upgrade_level(PhaseBProgression.UpgradeId.PRUNING_CHARGE)
	)
