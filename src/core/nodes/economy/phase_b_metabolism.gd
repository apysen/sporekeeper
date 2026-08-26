class_name PhaseBMetabolism
extends Node

## Ecosystem Metabolism: what the organism's tissue is physically like, and the one
## verb that spends its reserve.
##
## Mass, Push and Hold are not bought. The shop was tried and dropped: a drawer where
## the player clicks whichever number looks useful is a solved order wearing the costume
## of a decision, and every click of it interrupted the run to answer a question with
## one right answer. The three axes now develop on their own out of the Biomass the run
## has earned across its whole life, along the same cost curve the shop charged, so the
## climb is what buying everything in the best order would have given without any of
## the clicking.
##
## Lifetime earnings, never the balance. A currency the player can lose - to a Clover
## spin, to an Overgrow, to a starving organism - must not be able to take developed
## physiology back with it, so what has been earned is remembered separately from what
## is still in hand.
##
## The build leans the ladder rather than dividing it evenly: Root and Spore feed Mass,
## Bloom and Pruning feed Push, Bramble feeds Hold. A run therefore develops into the
## physique its Paths describe without ever being asked to allocate anything.
##
## What is left here is two things. The axes, published as multipliers the run
## controller pushes into the simulation - this component never writes the field's
## parameters itself. And Overgrow: the single metabolic discharge that converts the
## Reserve into something happening on the battlefield.

signal levels_changed
signal system_unlocked(system_id: int)
signal production_milestone_reached(per_second: float, milestone_index: int)
signal overgrown(mass: float, pressure: float, cohesion: float)
## A metabolic action resolved, with what it cost. Carried so the battlefield and the
## status line can answer a discharge with something larger than a number changing.
signal action_performed(action_id: int, local_position: Vector2, spent: float)
## A release has begun pouring into the border, with the cells it was sampled onto.
## Carries the three axes separately so what the ground shows can say which one the
## run actually developed.
signal injection_started(
	mass: float,
	pressure: float,
	cohesion: float,
	cells: PackedInt32Array
)
signal status_requested(message: String)

enum SystemId {
	PHOTOSYNTHESIS,
	MERISTEM,
	CAMBIUM,
}

## Overgrow is the whole of the metabolism's vocabulary. It stays an enum rather than
## becoming a bare function so a second discharge is an entry here and a case in one
## match, rather than a second copy of the aim, debit and cooldown flow.
enum ActionId {
	OVERGROW,
}

@export_group("Collaborators")
## Progression component that owns the Biomass reserve this metabolism spends, and the
## lifetime earnings the three axes develop out of.
@export var progression: PhaseBProgression
## Authoritative field that receives Overgrow injections and metabolism pulses.
@export var territory_field: TerritoryField

@export_group("Injection")
## Seconds a release takes to pour into the border. Spending it in one step made
## the frontier jump between two frames, which reads as a number changing rather
## than as the ecosystem growing into the ground.
@export_range(0.05, 3.0, 0.05) var injection_ramp_seconds := 0.55
## Steps a release is delivered in across that ramp. The border is redrawn every
## frame regardless, and the simulation diffuses between steps, so more steps than
## this buys nothing visible and costs the frame budget.
@export_range(2, 60, 1) var injection_slice_count := 12
## Releases that may be pouring at once. A rank queues one, so a burst of them - or a
## run that earns quickly without the clock advancing between - would otherwise pile
## up without bound, and every frame pays for every one still open. Past this the
## oldest is delivered in full at once, which is what a burst should look like anyway.
@export_range(1, 64, 1) var maximum_pending_injections := 6

@export_group("Unfolding")
## Elapsed run seconds at which Push begins developing. Mass is on the table from the
## start; the other two arrive while the run is being played, so the economy gains
## capabilities instead of showing everything at second one.
@export_range(0.0, 600.0, 1.0) var pressure_unlock_seconds := 90.0
## Elapsed run seconds at which Hold begins developing.
@export_range(0.0, 900.0, 1.0) var cohesion_unlock_seconds := 180.0

@export_group("Physiology")
## Highest rank an axis may reach. A clamp on a readout rather than a budget: nothing
## is spent on an axis, so this only stops a very long run from reporting a physique
## the tuning was never checked against.
@export_range(1, 60, 1) var maximum_level := 20
## Lifetime Biomass the first rank above one costs. The shop's own opening price, kept
## so the automatic climb lands where buying would have.
@export_range(1.0, 500.0, 1.0) var rank_cost_base := 20.0
## How much steeper each successive rank is. The shop charged 20, 35, 61, 107, 188,
## 328, 574, which is this ratio: specialising deeply eventually costs more than the
## organism can earn, and the ladder slows rather than running away.
@export_range(1.05, 4.0, 0.01) var rank_cost_growth := 1.75
## How hard a maxed Path leans the ladder toward the axis it feeds. At zero the three
## axes split lifetime earnings evenly; higher and a committed build develops visibly
## into the physique its Paths describe.
@export_range(0.0, 4.0, 0.05) var path_lean_weight := 1.0
## Material budget one rank injects into the territory when an axis first reaches it.
## A physique that changes without the ground showing it is only a number changing.
@export_range(0.0, 400.0, 1.0) var rank_pulse_budget := 24.0

@export_group("System Effects")
## Plant Mass multiplier gained per Photosynthesis level above one.
@export_range(1.0, 3.0, 0.01) var photosynthesis_mass_per_level := 1.13
## Biomass production multiplier gained per Photosynthesis level above one.
@export_range(1.0, 3.0, 0.01) var photosynthesis_production_per_level := 1.16
## Maturation multiplier gained per Photosynthesis level above one.
@export_range(1.0, 3.0, 0.01) var photosynthesis_maturation_per_level := 1.08
## Frontier pressure multiplier gained per Meristem level above one.
@export_range(1.0, 3.0, 0.01) var meristem_pressure_per_level := 1.15
## Passive frontier spread multiplier gained per Meristem level above one.
@export_range(1.0, 3.0, 0.01) var meristem_spread_per_level := 1.11
## Hostile-conversion multiplier gained per Meristem level above one.
@export_range(1.0, 3.0, 0.01) var meristem_conversion_per_level := 1.10
## Maturity-resistance multiplier gained per Cambium level above one.
@export_range(1.0, 3.0, 0.01) var cambium_resistance_per_level := 1.12
## Control recovered per second per Cambium level above one, which is how Green
## heals rather than only resisting.
@export_range(0.0, 1.0, 0.001) var cambium_regeneration_per_level := 0.010
## Small-fragment survival multiplier gained per Cambium level above one. Cohesive
## Green tears into isolated scraps less readily.
@export_range(0.1, 1.0, 0.01) var cambium_fragment_decay_per_level := 0.90

@export_group("Overgrow")
## Fraction of the current Biomass Reserve one Overgrow spends.
@export_range(0.05, 1.0, 0.01) var overgrow_reserve_fraction := 0.50
## Smallest Reserve that may be spent on an Overgrow at all.
@export_range(1.0, 500.0, 1.0) var overgrow_minimum_reserve := 20.0
## Seconds before Overgrow may be pressed again.
@export_range(0.0, 120.0, 0.5) var overgrow_cooldown_seconds := 8.0
## How far around the player a release serves its border first. The doc asks for a
## cheap spatial approximation of demand rather than routing, and this is it: the
## front the player ran to is fed before the rest of the organism.
@export_range(0.0, 900.0, 5.0) var overgrow_focus_radius := 190.0

@export_group("Milestones")
## Biomass-per-second production milestones that each announce themselves once.
@export var production_milestones := PackedFloat32Array([
	10.0, 25.0, 50.0, 100.0, 250.0, 500.0
])
## Free Mass budget injected by the celebratory pulse at a production milestone.
@export_range(0.0, 400.0, 1.0) var milestone_pulse_mass := 45.0

## Rank each axis was last seen at, so a rank that arrives on its own still answers on
## the battlefield the way a bought one used to.
var _announced_levels := PackedInt32Array([1, 1, 1])
## Which axes have been announced as available, so the arrival is said once.
var _announced_unlocks := PackedInt32Array([0, 0, 0])
var _elapsed_seconds := 0.0
var _last_injection_mass := 0.0
var _injection_count := 0
var _pending_injections: Array[PendingInjection] = []
## Cooldown remaining on each metabolic action, indexed by ActionId.
var _action_cooldowns := PackedFloat32Array([0.0])
var _milestones_reached := 0
var _overgrow_count := 0


func _ready() -> void:
	assert(progression != null, "PhaseBMetabolism requires PhaseBProgression")
	assert(territory_field != null, "PhaseBMetabolism requires TerritoryField")
	reset_metabolism()


func reset_metabolism() -> void:
	_announced_levels = PackedInt32Array([1, 1, 1])
	_announced_unlocks = PackedInt32Array([0, 0, 0])
	_elapsed_seconds = 0.0
	_last_injection_mass = 0.0
	_injection_count = 0
	_pending_injections.clear()
	_action_cooldowns = PackedFloat32Array([0.0])
	_milestones_reached = 0
	_overgrow_count = 0
	levels_changed.emit()


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	for action_id in range(_action_cooldowns.size()):
		_action_cooldowns[action_id] = maxf(0.0, _action_cooldowns[action_id] - delta)
	_elapsed_seconds += delta
	_advance_unlocks()
	_advance_ranks()
	_advance_injections(delta)
	_advance_milestones()


func _advance_unlocks() -> void:
	# An axis the run has not discovered yet is absent rather than sitting there greyed
	# out, so the run opens simple and gains capabilities while it is being played.
	for system_id in range(_announced_unlocks.size()):
		if _announced_unlocks[system_id] != 0 or not is_system_unlocked(system_id):
			continue
		_announced_unlocks[system_id] = 1
		system_unlocked.emit(system_id)
		status_requested.emit("%s — %s." % [
			get_axis_name(system_id).to_upper(),
			get_axis_summary(system_id),
		])


func _advance_ranks() -> void:
	# The axes rise without being bought, so the moment one rises is the moment the
	# ground has to say so. The shop answered every purchase with a visible release;
	# that requirement did not go away when the shopping did, it just stopped having a
	# button to hang off.
	var changed := false
	for system_id in range(_announced_levels.size()):
		var level := get_level(system_id)
		if level <= _announced_levels[system_id]:
			# Ranks cannot fall here - lifetime earnings only ever grow - but a reset
			# puts them back, and the readout follows rather than latching.
			if level != _announced_levels[system_id]:
				_announced_levels[system_id] = level
				changed = true
			continue
		_announced_levels[system_id] = level
		changed = true
		_pulse_rank(system_id)
		status_requested.emit("%s RANK %d" % [
			get_axis_name(system_id).to_upper(),
			level,
		])
	if changed:
		levels_changed.emit()


func _pulse_rank(system_id: int) -> void:
	# Material on Mass, a shove on Push, a knitting-together on Hold. The axis that
	# rose is the one the ground shows.
	if rank_pulse_budget <= 0.0:
		return
	match system_id:
		SystemId.PHOTOSYNTHESIS:
			_inject(rank_pulse_budget, 0.0, 0.0)
		SystemId.MERISTEM:
			_inject(rank_pulse_budget * 0.25, rank_pulse_budget, 0.0)
		SystemId.CAMBIUM:
			_inject(rank_pulse_budget * 0.25, 0.0, rank_pulse_budget)


func _advance_milestones() -> void:
	if _milestones_reached >= production_milestones.size():
		return
	var threshold := production_milestones[_milestones_reached]
	if progression.biomass_per_second < threshold:
		return
	var index := _milestones_reached
	_milestones_reached += 1
	production_milestone_reached.emit(threshold, index)
	status_requested.emit("PRODUCTION MILESTONE — %.0f Biomass per second." % threshold)
	if milestone_pulse_mass > 0.0:
		_inject(milestone_pulse_mass, milestone_pulse_mass * 0.5, 0.0)


func get_injection_count() -> int:
	# How many times the ecosystem has actually released material. Counted rather
	# than inferred: the last-injection reading persists between releases, so
	# watching it says nothing about when a pulse happened.
	return _injection_count


func get_last_injection_mass() -> float:
	# What the last injection actually put into the field, so a rank can be checked
	# against the simulation rather than against its own intention.
	return _last_injection_mass


class PendingInjection:
	## A release the ecosystem is still pouring in. Spending the whole budget in one
	## simulation step made the border jump a visible distance between two frames,
	## which reads as the number changing rather than as the ecosystem growing. The
	## same total is delivered, over a short ramp, along the stretch of border it was
	## sampled onto — so what the player sees is the material arriving.
	var cells := PackedInt32Array()
	var mass := 0.0
	var pressure := 0.0
	var cohesion := 0.0
	var elapsed := 0.0
	var duration := 0.0
	## How much of the release has already been poured, on a smooth curve, so each
	## frame delivers the difference and the totals come out exact.
	var delivered := 0.0


func _advance_injections(delta: float) -> void:
	if _pending_injections.is_empty() or territory_field == null:
		return
	for index in range(_pending_injections.size() - 1, -1, -1):
		var pending: PendingInjection = _pending_injections[index]
		pending.elapsed += delta
		var progress := clampf(pending.elapsed / maxf(0.0001, pending.duration), 0.0, 1.0)
		# Smoothstep: the release starts and finishes gently instead of switching on.
		var eased := progress * progress * (3.0 - 2.0 * progress)
		# Delivered in a fixed number of steps rather than once per frame. A release
		# touches every cell it was sampled onto, so paying that on all 60 frames of
		# a second cost about a millisecond of the budget at the stress peak while
		# looking no different: the field's own diffusion smooths between steps.
		var slice := eased - pending.delivered
		var quantum := 1.0 / float(maxi(1, injection_slice_count))
		if slice < quantum and progress < 1.0:
			continue
		pending.delivered = eased
		if slice > 0.0:
			var applied := territory_field.apply_overgrow(
				pending.cells,
				pending.mass * slice,
				pending.pressure * slice,
				pending.cohesion * slice
			)
			_last_injection_mass += applied.mass_applied
		if progress >= 1.0:
			_pending_injections.remove_at(index)


func _flush_injection(pending: PendingInjection) -> void:
	# Everything this release still owes the field, handed over in one step.
	var remaining := 1.0 - pending.delivered
	if remaining <= 0.0 or territory_field == null:
		return
	pending.delivered = 1.0
	_last_injection_mass += territory_field.apply_overgrow(
		pending.cells,
		pending.mass * remaining,
		pending.pressure * remaining,
		pending.cohesion * remaining
	).mass_applied


func get_pending_injection_count() -> int:
	return _pending_injections.size()


func _inject(
	mass: float,
	pressure: float,
	cohesion: float,
	focus_scale: float = 1.0,
	focus_position: Vector2 = Vector2.INF
) -> void:
	_last_injection_mass = 0.0
	if territory_field == null:
		return
	_injection_count += 1
	# Sampled once, against the whole budget, so the ramp keeps feeding the border
	# the release was aimed at instead of picking a narrower one every frame.
	var cells := territory_field.sample_overgrow_frontier(
		mass + pressure,
		focus_position,
		overgrow_focus_radius * maxf(0.02, focus_scale)
	)
	if cells.is_empty():
		return
	while _pending_injections.size() >= maximum_pending_injections:
		_flush_injection(_pending_injections[0])
		_pending_injections.remove_at(0)
	var pending := PendingInjection.new()
	pending.cells = cells
	pending.mass = mass
	pending.pressure = pressure
	pending.cohesion = cohesion
	pending.duration = maxf(0.0001, injection_ramp_seconds)
	_pending_injections.append(pending)
	injection_started.emit(mass, pressure, cohesion, cells)


func get_action_cooldown_remaining(action_id: int) -> float:
	if action_id < 0 or action_id >= _action_cooldowns.size():
		return 0.0
	return _action_cooldowns[action_id]


func is_action_unlocked(_action_id: int) -> bool:
	# Overgrow is the run's metabolic discharge and every run has it from the first
	# second. Nothing gates it, because nothing is bought.
	return true


func get_action_cost(action_id: int) -> float:
	if action_id == ActionId.OVERGROW:
		return get_spendable_reserve() * overgrow_reserve_fraction
	return 0.0


func can_perform(action_id: int) -> bool:
	if get_action_cooldown_remaining(action_id) > 0.0:
		return false
	return get_spendable_reserve() >= overgrow_minimum_reserve


func can_overgrow() -> bool:
	return can_perform(ActionId.OVERGROW)


func get_spendable_reserve() -> float:
	# One reserve, held by Progression, spent from wherever the player is standing.
	# Nothing strands it and nothing has to be fetched home.
	if progression == null:
		return 0.0
	return progression.biomass


func get_overgrow_cooldown_remaining() -> float:
	return get_action_cooldown_remaining(ActionId.OVERGROW)


func get_overgrow_count() -> int:
	return _overgrow_count


func get_overgrow_cost() -> float:
	return get_action_cost(ActionId.OVERGROW)


func try_overgrow(focus_position: Vector2 = Vector2.INF) -> bool:
	# Overgrow does not hand the run a fixed slice of territory. It converts the
	# Reserve into Mass, Pressure, and Cohesion in the proportions this run's physique
	# actually is, injects them into the living frontier, and lets the battlefield
	# decide what that looks like.
	var spent := _spend_action(ActionId.OVERGROW)
	if spent <= 0.0:
		return false
	_overgrow_count += 1
	var mass := spent * get_identity_share(SystemId.PHOTOSYNTHESIS)
	var pressure := spent * get_identity_share(SystemId.MERISTEM)
	var cohesion := spent * get_identity_share(SystemId.CAMBIUM)
	_inject(mass, pressure, cohesion, 1.0, focus_position)
	overgrown.emit(mass, pressure, cohesion)
	action_performed.emit(ActionId.OVERGROW, focus_position, spent)
	status_requested.emit(
		"OVERGROW — %.0f Biomass spent as %.0f Mass, %.0f Pressure, %.0f Cohesion."
		% [spent, mass, pressure, cohesion]
	)
	return true


func _spend_action(action_id: int) -> float:
	# One debit, one cooldown, one place. A short debit means the reserve changed
	# underneath the press, and the command shrinks to what was actually there rather
	# than being granted anyway.
	if not can_perform(action_id):
		return 0.0
	var cost := get_action_cost(action_id)
	if cost <= 0.0:
		return 0.0
	var spent := progression.spend_biomass(cost)
	if spent <= 0.0:
		return 0.0
	_action_cooldowns[action_id] = get_action_cooldown_seconds(action_id)
	return spent


func get_action_cooldown_seconds(action_id: int) -> float:
	if action_id == ActionId.OVERGROW:
		return overgrow_cooldown_seconds
	return 0.0


static func get_action_name(action_id: int) -> String:
	if action_id == ActionId.OVERGROW:
		return "OVERGROW"
	return ""


static func get_action_summary(action_id: int) -> String:
	if action_id == ActionId.OVERGROW:
		return (
			"Release the reserve into the frontier you aim at, as material and "
			+ "outward shove in the proportions this organism is built from. The "
			+ "battlefield decides what that becomes."
		)
	return ""


func get_identity_share(system_id: int) -> float:
	# Every developed axis takes part in an Overgrow, and the organism's physique
	# decides how much of the burst becomes material, motion, or repair. Two runs
	# pressing the same button therefore get visibly different physical results, and a
	# run that has not discovered Push yet spends the whole burst as material.
	if not is_system_unlocked(system_id):
		return 0.0
	var total := 0
	for axis in range(_announced_levels.size()):
		if is_system_unlocked(axis):
			total += get_level(axis)
	if total <= 0:
		# Mass is unlocked from the first second and never below rank one, so this is
		# unreachable in play; it keeps a component with no field behind it honest.
		return 1.0 if system_id == SystemId.PHOTOSYNTHESIS else 0.0
	return float(get_level(system_id)) / float(total)


func is_system_unlocked(system_id: int) -> bool:
	match system_id:
		SystemId.PHOTOSYNTHESIS:
			return true
		SystemId.MERISTEM:
			return _elapsed_seconds >= pressure_unlock_seconds
		SystemId.CAMBIUM:
			return _elapsed_seconds >= cohesion_unlock_seconds
	return false


static func get_axis_paths(system_id: int) -> PackedInt32Array:
	# Which Paths lean the ladder toward which axis. Root and Spore are both about
	# producing and holding more material; Bloom and Pruning are both about hitting
	# the front harder; Bramble is what refuses to be moved.
	match system_id:
		SystemId.PHOTOSYNTHESIS:
			return PackedInt32Array([
				PhaseBProgression.PathId.ROOT,
				PhaseBProgression.PathId.SPORE,
			])
		SystemId.MERISTEM:
			return PackedInt32Array([
				PhaseBProgression.PathId.BLOOM,
				PhaseBProgression.PathId.PRUNING,
			])
		SystemId.CAMBIUM:
			return PackedInt32Array([PhaseBProgression.PathId.BRAMBLE])
	return PackedInt32Array()


func get_axis_weight(system_id: int) -> float:
	# What share of the run's earnings this axis develops out of. One for existing,
	# plus however far the run has actually come down the Paths that feed it - so a
	# build leans its own physique without ever being handed an allocation screen.
	if not is_system_unlocked(system_id):
		return 0.0
	var weight := 1.0
	if progression != null:
		for path_id in get_axis_paths(system_id):
			weight += path_lean_weight * progression.get_path_rank_fraction(path_id)
	return weight


func get_axis_share(system_id: int) -> float:
	var total := 0.0
	for axis in range(_announced_levels.size()):
		total += get_axis_weight(axis)
	if total <= 0.0:
		return 0.0
	return get_axis_weight(system_id) / total


func get_lifetime_biomass() -> float:
	# The whole of what the run has ever earned, never the balance. Spending is what
	# the reserve is for; development is what the run has been.
	return progression.biomass_earned_total if progression != null else 0.0


func get_axis_lifetime(system_id: int) -> float:
	return get_lifetime_biomass() * get_axis_share(system_id)


func get_rank_cost(level: int) -> float:
	# What the shop charged for this rank: 20, 35, 61, 107, 188, 328, 574. Kept so the
	# automatic climb lands where buying in the best order would have.
	if level <= 1:
		return 0.0
	return rank_cost_base * pow(rank_cost_growth, float(level - 2))


func get_cumulative_rank_cost(level: int) -> float:
	# Everything the run would have had to earn to stand at this rank.
	if level <= 1:
		return 0.0
	return rank_cost_base * (pow(rank_cost_growth, float(level - 1)) - 1.0) / (
		rank_cost_growth - 1.0
	)


func get_level(system_id: int) -> int:
	# The highest rank this axis's share of lifetime earnings has paid for. One while
	# the axis is undiscovered, so an axis the run cannot see yet is also an axis that
	# multiplies nothing.
	if system_id < 0 or system_id >= _announced_levels.size():
		return 0
	if not is_system_unlocked(system_id):
		return 1
	var earned := get_axis_lifetime(system_id)
	if earned <= 0.0 or rank_cost_base <= 0.0:
		return 1
	var ranks: float = floor(
		log(1.0 + earned * (rank_cost_growth - 1.0) / rank_cost_base)
		/ log(rank_cost_growth)
	)
	return clampi(1 + int(ranks), 1, maximum_level)


func get_axis_progress(system_id: int) -> float:
	# How far this axis has come toward its next rank, for a meter that reports growth
	# rather than a bar waiting on a button.
	var level := get_level(system_id)
	if level >= maximum_level or not is_system_unlocked(system_id):
		return 1.0 if level >= maximum_level else 0.0
	var floor_cost := get_cumulative_rank_cost(level)
	var next_cost := get_cumulative_rank_cost(level + 1)
	if next_cost <= floor_cost:
		return 0.0
	return clampf(
		(get_axis_lifetime(system_id) - floor_cost) / (next_cost - floor_cost),
		0.0,
		1.0
	)


func get_next_rank_cost(system_id: int) -> float:
	# Lifetime Biomass this axis still needs, in the axis's own share rather than in
	# the run's total, so the readout answers the question it is asked.
	var level := get_level(system_id)
	if level >= maximum_level:
		return 0.0
	return maxf(0.0, get_cumulative_rank_cost(level + 1) - get_axis_lifetime(system_id))


func get_elapsed_seconds() -> float:
	return _elapsed_seconds


func get_milestones_reached() -> int:
	return _milestones_reached


func debug_grant_axis(system_id: int, ranks: int = 1) -> void:
	# Pays the run the lifetime earnings the ranks would have cost rather than writing
	# a level directly, so a debug lever cannot produce a physique the game itself
	# could never reach.
	if progression == null or ranks <= 0:
		return
	var target := clampi(get_level(system_id) + ranks, 1, maximum_level)
	var share := get_axis_share(system_id)
	if share <= 0.0:
		return
	var needed := get_cumulative_rank_cost(target) - get_axis_lifetime(system_id)
	if needed <= 0.0:
		return
	progression.add_biomass(needed / share)
	_advance_ranks()


func get_mass_multiplier() -> float:
	return pow(
		photosynthesis_mass_per_level,
		float(get_level(SystemId.PHOTOSYNTHESIS) - 1)
	)


func get_production_multiplier() -> float:
	return pow(
		photosynthesis_production_per_level,
		float(get_level(SystemId.PHOTOSYNTHESIS) - 1)
	)


func get_maturation_multiplier() -> float:
	return pow(
		photosynthesis_maturation_per_level,
		float(get_level(SystemId.PHOTOSYNTHESIS) - 1)
	)


func get_pressure_multiplier() -> float:
	return pow(meristem_pressure_per_level, float(get_level(SystemId.MERISTEM) - 1))


func get_spread_multiplier() -> float:
	return pow(meristem_spread_per_level, float(get_level(SystemId.MERISTEM) - 1))


func get_conversion_multiplier() -> float:
	return pow(meristem_conversion_per_level, float(get_level(SystemId.MERISTEM) - 1))


func get_resistance_multiplier() -> float:
	return pow(cambium_resistance_per_level, float(get_level(SystemId.CAMBIUM) - 1))


func get_cohesion_multiplier() -> float:
	# Reported to the field as one material property, so consumers ask the field
	# what the ground is like rather than asking the economy.
	return get_resistance_multiplier()


func get_regeneration_per_second() -> float:
	return cambium_regeneration_per_level * float(get_level(SystemId.CAMBIUM) - 1)


func get_advection_multiplier() -> float:
	# Kept as the one place the simulation asks how readily this organism deforms, so
	# a future physiology has somewhere to answer from.
	return 1.0


func get_fragment_decay_multiplier() -> float:
	return pow(
		cambium_fragment_decay_per_level,
		float(get_level(SystemId.CAMBIUM) - 1)
	)


static func get_axis_name(system_id: int) -> String:
	# The physical axis, in the plainest words available: what the ground is made of,
	# how hard it pushes, how well it holds. The organ name is how the run discovered
	# it, and stays for announcements.
	match system_id:
		SystemId.PHOTOSYNTHESIS:
			return "Mass"
		SystemId.MERISTEM:
			return "Push"
		SystemId.CAMBIUM:
			return "Hold"
	return ""


static func get_axis_summary(system_id: int) -> String:
	match system_id:
		SystemId.PHOTOSYNTHESIS:
			return "More material"
		SystemId.MERISTEM:
			return "Push harder"
		SystemId.CAMBIUM:
			return "Hold together"
	return ""


static func get_system_name(system_id: int) -> String:
	match system_id:
		SystemId.PHOTOSYNTHESIS:
			return "Photosynthesis"
		SystemId.MERISTEM:
			return "Meristem"
		SystemId.CAMBIUM:
			return "Cambium"
	return "Unknown System"


static func get_system_channel(system_id: int) -> String:
	match system_id:
		SystemId.PHOTOSYNTHESIS:
			return "Mass"
		SystemId.MERISTEM:
			return "Pressure"
		SystemId.CAMBIUM:
			return "Cohesion"
	return ""


static func get_system_description(system_id: int) -> String:
	match system_id:
		SystemId.PHOTOSYNTHESIS:
			return (
				"Mass. How much raw Plant material the ecosystem produces. The Green "
				+ "visibly swells because it is making more of itself."
			)
		SystemId.MERISTEM:
			return (
				"Pressure. How aggressively Green pushes and moves. High Meristem "
				+ "exploits gaps and weak fronts and deforms whatever it meets."
			)
		SystemId.CAMBIUM:
			return (
				"Cohesion. Structural integrity. Weak Green tears; strong Green bends, "
				+ "holds together, and rebounds."
			)
	return ""
