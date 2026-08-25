class_name PhaseBMetabolism
extends Node

## Ecosystem Metabolism: what the organism's tissue is physically like, and the
## verbs that spend its reserve.
##
## Mass, Pressure, and Cohesion are no longer bought. Two economies were tried on top
## of them and both failed for the same reason: a shop where the player picks whichever
## number looks useful is a solved order wearing the costume of a decision, and an
## automatic ladder fed by lifetime earnings is a bar filling itself. The master doc's
## answer is that the player develops *physiology* while the simulation uses *physical
## parameters*, so the three axes stay and stop being a purchase surface. They now
## describe the organism: what the run developed its roots into, and how much organism
## there actually is.
##
## What is left here is therefore two things. The axes, read out of Root Metabolism and
## the field and published as multipliers the run controller pushes into the simulation
## - this component still never writes the field's parameters itself. And the metabolic
## actions: large strategic commands that convert the reserve into something happening
## on the battlefield. The currency belongs to the root network's components, so every
## one of them is paid for out of the organism that will benefit.

signal levels_changed
signal production_milestone_reached(per_second: float, milestone_index: int)
signal overgrown(mass: float, pressure: float, cohesion: float)
## A metabolic action other than Overgrow resolved, with what it cost. Carried so the
## battlefield and the status line can answer a large strategic command with something
## larger than a number changing.
signal action_performed(action_id: int, local_position: Vector2, spent: float)
## A release has begun pouring into the border, with the cells it was sampled onto.
## Carries the three axes separately so what the ground shows can say which one the
## player actually bought.
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

## The metabolic actions. Overgrow is the one every run has; the other four are the
## doc's future verbs, and each is unlocked by the developmental domain whose character
## it expresses. Developing a domain therefore buys a capability rather than only a
## coefficient, which is what makes the fifth unfolding layer a layer at all.
enum ActionId {
	## Always available. Releases the reserve into the frontier as material and shove.
	OVERGROW,
	## Rooting. Establishes the ground around the player far faster for a moment.
	DEEP_ROOT,
	## Storage. Empties the reserve as one outward shove against hostile ground.
	PRESSURIZE,
	## Circulation. Drags what the outlying colonies are holding back to the organism.
	TRANSLOCATE,
	## Anchoring. Repairs damaged rooted territory around the player.
	REGENERATE,
}

@export_group("Collaborators")
## Progression component that owns the Biomass reserve this metabolism spends.
@export var progression: PhaseBProgression
## Authoritative field that receives Overgrow injections and metabolism pulses.
@export var territory_field: TerritoryField
## Root Metabolism's component reserves. Every metabolic action spends the main
## organism's reserve and discharges through the component that paid, and the three
## axes are read out of the domains this node develops, so it is required rather than
## optional: without it there is no economy and no physiology.
@export var root_network: PhaseBRootNetwork

@export_group("Injection")
## Seconds a release takes to pour into the border. Spending it in one step made
## the frontier jump between two frames, which reads as a number changing rather
## than as the ecosystem growing into the ground.
@export_range(0.05, 3.0, 0.05) var injection_ramp_seconds := 0.55
## Steps a release is delivered in across that ramp. The border is redrawn every
## frame regardless, and the simulation diffuses between steps, so more steps than
## this buys nothing visible and costs the frame budget.
@export_range(2, 60, 1) var injection_slice_count := 12
## Releases that may be pouring at once. A purchase queues one, so a burst of them
## — or a run that buys without the clock advancing between — would otherwise pile
## up without bound, and every frame pays for every one still open. Past this the
## oldest is delivered in full at once, which is what a burst should look like
## anyway.
@export_range(1, 64, 1) var maximum_pending_injections := 6

@export_group("Physiology")
## Highest rank an axis may describe. It is a clamp on a readout rather than a budget:
## nothing is spent on an axis, so this only stops a runaway organism from reporting a
## physique the tuning was never checked against.
@export_range(1, 60, 1) var maximum_level := 20
## Rooted territory, as a percentage of the claimable board, worth one rank on every
## axis. This is the half of the physique that no development can buy: a large healthy
## organism is physically more massive, pushes harder, and holds together better than a
## small one, because it is made of more of itself. It is also what makes the economy
## follow the simulation rather than the other way round.
@export_range(1.0, 100.0, 0.5) var rooted_percent_per_rank := 12.0
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

@export_group("Metamorphosis Effects")
## Seconds between Distributed Nodules' small continuous Mass pulses. Storage spread
## through the network releases what it holds constantly and in small amounts.
@export_range(0.05, 10.0, 0.05) var nodule_pulse_interval_seconds := 0.65
## Seconds between Central Taproot's large periodic Mass releases. Storage concentrated
## into one structure fills, and then empties, and the ground breathes with it.
@export_range(0.5, 30.0, 0.1) var taproot_pulse_interval_seconds := 6.00
## Share of a pulse's Mass that is released as outward Pressure. A pulse of pure
## Mass can only top up cells that are already full, so it was refused by the very
## frontier it was meant to push: the release has to shove as well as feed.
@export_range(0.0, 4.0, 0.05) var pulse_pressure_share := 0.85
## Mass budget released per Mass rank by one metabolism pulse. At the old value a
## pulsing run and a non-pulsing one were within a twentieth of a percent of territory
## after ten seconds: the effect fired and nothing happened. It is priced to be seen.
@export_range(0.0, 600.0, 0.5) var pulse_mass_per_level := 42.0
## Fraction of the frontier one Cardiac Pumping release concentrates into. A pumped
## circulation delivers its charge as a shove through a narrow slice of border, which
## the simulation resolves as protrusions and tendrils.
@export_range(0.02, 1.0, 0.01) var cardiac_focus_fraction := 0.18
## Frontier share Continuous Peristalsis spreads a release across. Above one on
## purpose: at exactly one it would be the default, and a metamorphosis that changes
## nothing only looks like a choice. A flowing circulation reaches further around the
## frontier than an undeveloped one, which is the opposite of a pump concentrating.
@export_range(0.02, 6.0, 0.01) var peristalsis_focus_fraction := 2.40
## Pressure-advection multiplier supplied by Fibrous Mat, which lets a wide shallow
## organism deform far more before it breaks and rebound afterwards.
@export_range(0.5, 3.0, 0.01) var fibrous_advection_multiplier := 1.35
## Extra regeneration per second supplied by Fibrous Mat's rebound.
@export_range(0.0, 2.0, 0.005) var fibrous_rebound_per_second := 0.045
## Pressure-advection multiplier supplied by Deep Taproots, which is what makes
## anchored Green hold its shape and then fail suddenly instead of bending.
@export_range(0.1, 1.0, 0.01) var taproot_advection_multiplier := 0.72

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

@export_group("Metabolic Actions")
## Domain rank an action's unlocking domain must reach before the action exists. The
## doc is explicit that these are large strategic commands rather than maintenance
## buttons, and one is easier to keep that way than four handed over at once.
@export_range(1, 10, 1) var action_unlock_rank := 1
## Fraction of the main organism's reserve one Deep Root spends.
@export_range(0.05, 1.0, 0.01) var deep_root_reserve_fraction := 0.35
## Seconds before Deep Root may be pressed again.
@export_range(0.0, 120.0, 0.5) var deep_root_cooldown_seconds := 10.0
## Maturity delivered per unit of Biomass a Deep Root spends. Far above the trickle the
## player's standing support pays, because this is the whole reserve arriving at once.
@export_range(0.0, 0.5, 0.0005) var deep_root_maturity_per_biomass := 0.030
## Reach of a Deep Root, as a multiple of the field's stamp radius.
@export_range(0.1, 12.0, 0.1) var deep_root_radius_multiplier := 5.2
## Fraction of the main organism's reserve one Pressurize spends.
@export_range(0.05, 1.0, 0.01) var pressurize_reserve_fraction := 0.60
## Seconds before Pressurize may be pressed again.
@export_range(0.0, 120.0, 0.5) var pressurize_cooldown_seconds := 14.0
## What a Pressurize turns its spend into, as a multiple of an equal Overgrow's shove.
## It buys no material at all, so the same Biomass has to be worth more as motion or
## the action is a worse Overgrow with a longer cooldown.
@export_range(1.0, 6.0, 0.05) var pressurize_pressure_multiplier := 2.60
## Fraction of the main organism's reserve one Regenerate spends.
@export_range(0.05, 1.0, 0.01) var regenerate_reserve_fraction := 0.40
## Seconds before Regenerate may be pressed again.
@export_range(0.0, 120.0, 0.5) var regenerate_cooldown_seconds := 12.0
## What a Regenerate turns its spend into, as a multiple of an equal Overgrow's repair.
@export_range(1.0, 8.0, 0.05) var regenerate_repair_multiplier := 3.20
## Radius around the player a Regenerate searches for damaged rooted ground.
@export_range(20.0, 900.0, 5.0) var regenerate_radius := 210.0
## Seconds before Translocate may be pressed again.
@export_range(0.0, 240.0, 0.5) var translocate_cooldown_seconds := 30.0
## Share of a colony's reserve that survives the journey home. Translocate is the one
## exception to a colony's Biomass being unreachable, so it has to cost something:
## moving it through ground the organism does not hold loses part of it.
@export_range(0.05, 1.0, 0.01) var translocate_recovery_fraction := 0.65
## Smallest total held outside the main organism that is worth a Translocate.
@export_range(1.0, 500.0, 1.0) var translocate_minimum_stranded := 15.0

@export_group("Milestones")
## Biomass-per-second production milestones that each announce themselves once.
@export var production_milestones := PackedFloat32Array([
	10.0, 25.0, 50.0, 100.0, 250.0, 500.0
])
## Free Mass budget injected by the celebratory pulse at a production milestone.
@export_range(0.0, 400.0, 1.0) var milestone_pulse_mass := 45.0

## Rank each axis was last seen at, so a rank that arrives on its own can still
## answer on the battlefield the way a bought one used to.
var _announced_levels := PackedInt32Array([1, 1, 1])
var _elapsed_seconds := 0.0
var _last_injection_mass := 0.0
var _injection_count := 0
var _pending_injections: Array[PendingInjection] = []
var _pulse_accumulator := 0.0
var _pulse_charge := 0.0
## Cooldown remaining on each metabolic action, indexed by ActionId.
var _action_cooldowns := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
var _milestones_reached := 0
var _overgrow_count := 0


func _ready() -> void:
	assert(progression != null, "PhaseBMetabolism requires PhaseBProgression")
	assert(territory_field != null, "PhaseBMetabolism requires TerritoryField")
	assert(root_network != null, "PhaseBMetabolism requires PhaseBRootNetwork")
	reset_metabolism()


func reset_metabolism() -> void:
	_announced_levels = PackedInt32Array([1, 1, 1])
	_elapsed_seconds = 0.0
	_last_injection_mass = 0.0
	_injection_count = 0
	_pending_injections.clear()
	_pulse_accumulator = 0.0
	_pulse_charge = 0.0
	_action_cooldowns = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
	_milestones_reached = 0
	_overgrow_count = 0
	levels_changed.emit()


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	for action_id in range(_action_cooldowns.size()):
		_action_cooldowns[action_id] = maxf(0.0, _action_cooldowns[action_id] - delta)
	_elapsed_seconds += delta
	_advance_ranks()
	_advance_injections(delta)
	_advance_pulses(delta)
	_advance_milestones()


func _advance_ranks() -> void:
	# The axes rise without being bought, so the moment one rises is the moment the
	# ground has to say so. Every other economy this component has carried answered a
	# rank with a visible release; that requirement did not go away when the shopping
	# did, it just stopped having a button to hang off.
	var changed := false
	for system_id in range(_announced_levels.size()):
		var level := get_level(system_id)
		if level <= _announced_levels[system_id]:
			# Ranks can fall: the organism can be cut down to a fraction of itself and
			# the physique honestly follows it. A fall is not announced, because the
			# player is already watching the thing that caused it.
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


func _advance_pulses(delta: float) -> void:
	# The Storage metamorphosis decides the shape of the organism's output rather than
	# its size: the same Mass either trickles out continuously through nodules spread
	# across the network, or is gathered into the taproot and released in a pulse the
	# player can watch the ecosystem breathe with.
	if root_network == null:
		_pulse_accumulator = 0.0
		_pulse_charge = 0.0
		return
	var nodules := root_network.has_metamorphosis(
		PhaseBRootNetwork.MetamorphosisId.DISTRIBUTED_NODULES
	)
	var taproot := root_network.has_metamorphosis(
		PhaseBRootNetwork.MetamorphosisId.CENTRAL_TAPROOT
	)
	if not nodules and not taproot:
		_pulse_accumulator = 0.0
		_pulse_charge = 0.0
		return
	var interval := (
		nodule_pulse_interval_seconds
		if nodules
		else taproot_pulse_interval_seconds
	)
	var level_mass := pulse_mass_per_level * float(get_level(SystemId.PHOTOSYNTHESIS))
	_pulse_charge += level_mass * delta
	_pulse_accumulator += delta
	if _pulse_accumulator < interval:
		return
	_pulse_accumulator -= interval
	var mass := _pulse_charge
	_pulse_charge = 0.0
	if mass <= 0.0:
		return
	_inject(mass, mass * pulse_pressure_share, 0.0)


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
	# What the last injection actually put into the field, so a purchase can be
	# checked against the simulation rather than against its own intention.
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
	focus_position: Vector2 = Vector2.INF,
	component_id: int = -1
) -> void:
	_last_injection_mass = 0.0
	if territory_field == null:
		return
	var focus := get_injection_focus_fraction() * maxf(0.02, focus_scale)
	_injection_count += 1
	# Cardiac Pumping concentrates the same budget into a narrow slice of the frontier,
	# which the simulation resolves as protrusions and tendrils. Continuous Peristalsis
	# does the reverse and spreads it further around the border than an undeveloped run
	# reaches. Both are the same dial, read in both directions.
	var restored := territory_field.tuning.overgrow_frontier_sample_limit
	if not is_equal_approx(focus, 1.0):
		territory_field.tuning.overgrow_frontier_sample_limit = maxi(
			16,
			int(round(float(restored) * focus))
		)
	# Sampled once, against the whole budget, so the ramp keeps feeding the border
	# the release was aimed at instead of picking a narrower one every frame.
	# Circulation carries a release further, the same way it carries the support the
	# player draws while standing: one domain, one meaning.
	var reach := overgrow_focus_radius
	if root_network != null:
		reach *= root_network.get_reach_multiplier()
	var cells := territory_field.sample_overgrow_frontier(
		mass + pressure,
		focus_position,
		reach,
		component_id
	)
	territory_field.tuning.overgrow_frontier_sample_limit = restored
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


static func get_action_domain(action_id: int) -> int:
	# Every domain unlocks exactly one verb, and the verb expresses what the domain is
	# for. Developing therefore buys a capability rather than only a coefficient, which
	# is the difference between the fifth unfolding layer being a layer and being a
	# coefficient the player was told about.
	match action_id:
		ActionId.DEEP_ROOT:
			return PhaseBRootNetwork.DomainId.ROOTING
		ActionId.PRESSURIZE:
			return PhaseBRootNetwork.DomainId.STORAGE
		ActionId.TRANSLOCATE:
			return PhaseBRootNetwork.DomainId.CIRCULATION
		ActionId.REGENERATE:
			return PhaseBRootNetwork.DomainId.ANCHORING
	return -1


func is_action_unlocked(action_id: int) -> bool:
	# Overgrow is the run's first metabolic discharge and is never gated. The rest
	# arrive as the organism develops the physiology that could perform them.
	var domain := get_action_domain(action_id)
	if domain < 0:
		return true
	if root_network == null:
		return false
	return root_network.get_development_level(domain) >= action_unlock_rank


func get_action_cost(action_id: int) -> float:
	# What pressing it now would take. Translocate is the exception and always reads
	# zero: it does not spend the organism's reserve, it goes and fetches one.
	var reserve := get_spendable_reserve()
	match action_id:
		ActionId.OVERGROW:
			return reserve * overgrow_reserve_fraction
		ActionId.DEEP_ROOT:
			return reserve * deep_root_reserve_fraction
		ActionId.PRESSURIZE:
			return reserve * pressurize_reserve_fraction
		ActionId.REGENERATE:
			return reserve * regenerate_reserve_fraction
	return 0.0


func get_stranded_reserve() -> float:
	# Biomass the run owns and cannot reach, which is the entire subject of Translocate.
	if root_network == null:
		return 0.0
	return maxf(
		0.0,
		root_network.get_total_reserve() - root_network.get_primary_reserve()
	)


func can_perform(action_id: int) -> bool:
	if not is_action_unlocked(action_id):
		return false
	if get_action_cooldown_remaining(action_id) > 0.0:
		return false
	if action_id == ActionId.TRANSLOCATE:
		return get_stranded_reserve() >= translocate_minimum_stranded
	return get_spendable_reserve() >= overgrow_minimum_reserve


func can_overgrow() -> bool:
	return can_perform(ActionId.OVERGROW)


func get_spendable_reserve() -> float:
	# What the run can actually spend, which is the main organism's reserve alone.
	# Biomass held by a colony that is cut off is real and is still producing, but it
	# is not reachable until the ground reconnects - or until a Translocate goes and
	# drags what is left of it home.
	if root_network == null:
		return 0.0
	return root_network.get_primary_reserve()


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
	var discharge := spent * root_network.get_discharge_multiplier()
	var mass := discharge * get_identity_share(SystemId.PHOTOSYNTHESIS)
	var pressure := discharge * get_identity_share(SystemId.MERISTEM)
	var cohesion := discharge * get_identity_share(SystemId.CAMBIUM)
	_inject(
		mass,
		pressure,
		cohesion,
		1.0,
		focus_position,
		root_network.get_primary_component()
	)
	overgrown.emit(mass, pressure, cohesion)
	action_performed.emit(ActionId.OVERGROW, focus_position, spent)
	status_requested.emit(
		"OVERGROW — %.0f Biomass spent as %.0f Mass, %.0f Pressure, %.0f Cohesion."
		% [spent, mass, pressure, cohesion]
	)
	return true


func _spend_action(action_id: int) -> float:
	# One debit, one cooldown, one place. Every action pays out of the organism that
	# will benefit, and a short debit means the ground changed underneath the press and
	# the command shrinks to what was actually there rather than being granted anyway.
	if not can_perform(action_id):
		return 0.0
	var cost := get_action_cost(action_id)
	if cost <= 0.0:
		return 0.0
	var spent := root_network.spend_from_primary(cost)
	if spent <= 0.0:
		return 0.0
	_action_cooldowns[action_id] = get_action_cooldown_seconds(action_id)
	return spent


func get_action_cooldown_seconds(action_id: int) -> float:
	match action_id:
		ActionId.OVERGROW:
			return overgrow_cooldown_seconds
		ActionId.DEEP_ROOT:
			return deep_root_cooldown_seconds
		ActionId.PRESSURIZE:
			return pressurize_cooldown_seconds
		ActionId.REGENERATE:
			return regenerate_cooldown_seconds
		ActionId.TRANSLOCATE:
			return translocate_cooldown_seconds
	return 0.0


func try_deep_root(focus_position: Vector2) -> bool:
	# Rooting's verb. The whole reserve arrives at one place as establishment, so
	# ground the player is standing on becomes productive infrastructure in seconds
	# rather than over the minute it would ordinarily take.
	if not focus_position.is_finite():
		return false
	var spent := _spend_action(ActionId.DEEP_ROOT)
	if spent <= 0.0:
		return false
	territory_field.queue_maturity_support(
		focus_position,
		spent * deep_root_maturity_per_biomass,
		deep_root_radius_multiplier * root_network.get_reach_multiplier()
	)
	action_performed.emit(ActionId.DEEP_ROOT, focus_position, spent)
	status_requested.emit(
		"DEEP ROOT — %.0f Biomass driven into the ground underfoot." % spent
	)
	return true


func try_pressurize(focus_position: Vector2) -> bool:
	# Storage's verb. The reserve is released as motion and nothing else: it buys no
	# material, so the same Biomass has to be worth more as a shove than it would have
	# been as an Overgrow, or the action is a worse Overgrow with a longer cooldown.
	var spent := _spend_action(ActionId.PRESSURIZE)
	if spent <= 0.0:
		return false
	var discharge := (
		spent
		* pressurize_pressure_multiplier
		* root_network.get_discharge_multiplier()
	)
	_inject(
		0.0,
		discharge,
		0.0,
		1.0,
		focus_position,
		root_network.get_primary_component()
	)
	action_performed.emit(ActionId.PRESSURIZE, focus_position, spent)
	status_requested.emit(
		"PRESSURIZE — %.0f Biomass released as one outward shove." % spent
	)
	return true


func try_regenerate(focus_position: Vector2) -> bool:
	# Anchoring's verb. Pure Cohesion, which the field already spends on whatever is
	# damaged rather than on whatever is furthest forward - thin Green thickens and
	# hostile ground beside it is pushed back toward neutral.
	var spent := _spend_action(ActionId.REGENERATE)
	if spent <= 0.0:
		return false
	var restored_here := (
		spent
		* regenerate_repair_multiplier
		* root_network.get_discharge_multiplier()
	)
	_inject(
		0.0,
		0.0,
		restored_here,
		maxf(0.02, regenerate_radius / maxf(1.0, overgrow_focus_radius)),
		focus_position,
		root_network.get_primary_component()
	)
	action_performed.emit(ActionId.REGENERATE, focus_position, spent)
	status_requested.emit(
		"REGENERATE — %.0f Biomass spent sealing damaged ground." % spent
	)
	return true


func try_translocate(focus_position: Vector2 = Vector2.INF) -> bool:
	# Circulation's verb, and the one exception to a severed colony's Biomass being
	# unreachable. It has to cost something or the rule it breaks was never a rule:
	# moving reserve through ground the organism does not hold loses part of it, and
	# what arrives is what survived the journey.
	if not can_perform(ActionId.TRANSLOCATE):
		return false
	var recovered := root_network.translocate_to_primary(translocate_recovery_fraction)
	if recovered <= 0.0:
		return false
	_action_cooldowns[ActionId.TRANSLOCATE] = translocate_cooldown_seconds
	action_performed.emit(ActionId.TRANSLOCATE, focus_position, recovered)
	status_requested.emit(
		"TRANSLOCATE — %.0f Biomass dragged home from the outlying colonies." % recovered
	)
	return true


static func get_action_name(action_id: int) -> String:
	match action_id:
		ActionId.OVERGROW:
			return "OVERGROW"
		ActionId.DEEP_ROOT:
			return "DEEP ROOT"
		ActionId.PRESSURIZE:
			return "PRESSURIZE"
		ActionId.TRANSLOCATE:
			return "TRANSLOCATE"
		ActionId.REGENERATE:
			return "REGENERATE"
	return ""


static func get_action_summary(action_id: int) -> String:
	match action_id:
		ActionId.OVERGROW:
			return (
				"Release the reserve into the frontier you aim at, as material and "
				+ "outward shove in the proportions this organism is built from. The "
				+ "battlefield decides what that becomes."
			)
		ActionId.DEEP_ROOT:
			return (
				"Drive the reserve into the ground around you. Everything nearby "
				+ "establishes at once instead of over the next minute."
			)
		ActionId.PRESSURIZE:
			return (
				"Empty the reserve as one shove and nothing else. It creates no Plant "
				+ "material at all; it moves what is already there."
			)
		ActionId.TRANSLOCATE:
			return (
				"Drag home what the cut-off colonies are still holding. Part of it is "
				+ "lost on the way through ground you do not own."
			)
		ActionId.REGENERATE:
			return (
				"Spend the reserve sealing damaged ground. It goes where the organism "
				+ "is thin, not where it is furthest forward."
			)
	return ""


func get_identity_share(system_id: int) -> float:
	# Every axis takes part in an Overgrow, but the organism's physique decides how
	# much of the burst becomes material, motion, or repair. Two runs pressing the same
	# button therefore get visibly different physical results.
	var total := 0
	for axis in range(_announced_levels.size()):
		total += get_level(axis)
	if total <= 0:
		return 1.0 / float(maxi(1, _announced_levels.size()))
	return float(get_level(system_id)) / float(total)


func debug_grant_axis(system_id: int, ranks: int = 1) -> void:
	# Raises an axis by developing the domain that governs it, because that is the
	# only thing that raises one. A debug lever that wrote the rank directly would be
	# able to produce a physique the game cannot actually reach.
	if root_network == null:
		return
	var domain := get_axis_domain(system_id)
	for _rank in range(maxi(0, ranks)):
		root_network.debug_grant_development(domain)
	_advance_ranks()


static func get_axis_domain(system_id: int) -> int:
	# The doc's own mapping, in one place. Root storage and available biological
	# material influence Mass; vascular output influences Pressure; root anchoring and
	# tissue structure influence Cohesion. The player develops physiology; the
	# simulation reads physical parameters; this is the join between them.
	match system_id:
		SystemId.PHOTOSYNTHESIS:
			return PhaseBRootNetwork.DomainId.STORAGE
		SystemId.MERISTEM:
			return PhaseBRootNetwork.DomainId.CIRCULATION
		SystemId.CAMBIUM:
			return PhaseBRootNetwork.DomainId.ANCHORING
	return PhaseBRootNetwork.DomainId.STORAGE


func get_organism_rank_bonus() -> int:
	# The half of the physique nothing can be spent on. A large healthy organism is
	# physically more massive, pushes harder, and holds together better than a small
	# one, because it is made of more of itself - so the economy follows the simulation
	# rather than the simulation being decorated by the economy.
	if territory_field == null or rooted_percent_per_rank <= 0.0:
		return 0
	return int(floor(
		territory_field.get_rooted_territory_percent() / rooted_percent_per_rank
	))


func get_axis_progress(system_id: int) -> float:
	# How far the organism has come toward its next rank on this axis, for a meter that
	# reports growth. Only the organism half moves continuously; a domain rank arrives
	# whole, so it is the remainder of the rooted percentage that fills the bar.
	if territory_field == null or rooted_percent_per_rank <= 0.0:
		return 0.0
	if get_level(system_id) >= maximum_level:
		return 1.0
	var rooted := territory_field.get_rooted_territory_percent()
	return clampf(
		fposmod(rooted, rooted_percent_per_rank) / rooted_percent_per_rank,
		0.0,
		1.0
	)


func get_level(system_id: int) -> int:
	# One rank for existing, one per rank of the domain that governs this axis, and one
	# per slice of the board the organism has actually rooted.
	if system_id < 0 or system_id >= _announced_levels.size():
		return 0
	var developed := 0
	if root_network != null:
		developed = root_network.get_development_level(get_axis_domain(system_id))
	return clampi(1 + developed + get_organism_rank_bonus(), 1, maximum_level)


func get_elapsed_seconds() -> float:
	return _elapsed_seconds


func get_milestones_reached() -> int:
	return _milestones_reached


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
	# The axis half. Anchoring's own metamorphoses are applied by the root network,
	# which is also what knows whether the ground being asked about is old enough for
	# Deep Taproots to be defending it at all.
	return pow(cambium_resistance_per_level, float(get_level(SystemId.CAMBIUM) - 1))


func get_cohesion_multiplier() -> float:
	# Reported to the field as one material property, so consumers ask the field
	# what the ground is like rather than asking the economy.
	return get_resistance_multiplier()


func get_regeneration_per_second() -> float:
	var regeneration := (
		cambium_regeneration_per_level
		* float(get_level(SystemId.CAMBIUM) - 1)
	)
	if _has_metamorphosis(PhaseBRootNetwork.MetamorphosisId.FIBROUS_MAT):
		regeneration += fibrous_rebound_per_second
	return regeneration


func get_advection_multiplier() -> float:
	# A wide fibrous mat deforms heavily and springs back; deeply anchored Green
	# refuses to move until it fails. Both read out of the same simulation parameter,
	# which is what makes them two shapes of one organism rather than two effects.
	if _has_metamorphosis(PhaseBRootNetwork.MetamorphosisId.FIBROUS_MAT):
		return fibrous_advection_multiplier
	if _has_metamorphosis(PhaseBRootNetwork.MetamorphosisId.DEEP_TAPROOTS):
		return taproot_advection_multiplier
	return 1.0


func get_fragment_decay_multiplier() -> float:
	return pow(
		cambium_fragment_decay_per_level,
		float(get_level(SystemId.CAMBIUM) - 1)
	)


func get_injection_focus_fraction() -> float:
	if _has_metamorphosis(PhaseBRootNetwork.MetamorphosisId.CARDIAC_PUMPING):
		return cardiac_focus_fraction
	if _has_metamorphosis(PhaseBRootNetwork.MetamorphosisId.CONTINUOUS_PERISTALSIS):
		return peristalsis_focus_fraction
	return 1.0


func _has_metamorphosis(metamorphosis_id: int) -> bool:
	# One guarded read, so every consumer above stays a single legible line and none of
	# them has to know that the physiology lives on another node.
	return root_network != null and root_network.has_metamorphosis(metamorphosis_id)


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
