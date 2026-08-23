class_name PhaseBMetabolism
extends Node

## Ecosystem Metabolism: the Biomass economy. The run buys levels in three
## physical development axes outright, at costs that climb steeply enough that
## specialising deeply eventually makes a neglected axis the better buy.
##
## Automatic allocation was tried and dropped: feeding the systems from a pool of
## points turned the economy into "allocate, then watch bars fill", which is less
## interactive than the purchases it replaced. Every level here is a decision the
## player makes at a moment they choose, and every purchase answers immediately in
## the simulation rather than only in a number.
##
## Photosynthesis is Mass, Meristem is Pressure, Cambium is Cohesion. The axes
## unfold across the run rather than all being on the table at second one. Those
## three are physical parameters of the territory simulation, so this component
## reports multipliers and the run controller pushes them into the field. It never
## writes the field itself, and it never holds the currency: the Biomass reserve
## stays on Progression and is spent through it.

signal levels_changed
signal system_unlocked(system_id: int)
signal purchased(system_id: int, level: int, cost: float)
signal level_reached(system_id: int, level: int)
signal breakthrough_choice_requested(system_id: int, options: PackedInt32Array)
signal breakthroughs_changed
signal production_milestone_reached(per_second: float, milestone_index: int)
signal overgrown(mass: float, pressure: float, cohesion: float)
signal status_requested(message: String)

enum SystemId {
	PHOTOSYNTHESIS,
	MERISTEM,
	CAMBIUM,
}

enum BreakthroughId {
	NONE,
	RAPID_CYCLING,
	STORAGE_ORGANS,
	APICAL_DOMINANCE,
	LATERAL_GROWTH,
	FLEXIBLE_TISSUE,
	WOODY_TISSUE,
}

@export_group("Collaborators")
## Progression component that owns the Biomass reserve this metabolism spends.
@export var progression: PhaseBProgression
## Authoritative field that receives Overgrow injections and metabolism pulses.
@export var territory_field: TerritoryField

@export_group("Unfolding")
## Elapsed run seconds at which Pressure becomes available to buy. Mass is on the
## table from the start; the other two arrive while the run is being played, so
## the economy gains capabilities instead of showing everything at second one.
@export_range(0.0, 600.0, 1.0) var pressure_unlock_seconds := 90.0
## Elapsed run seconds at which Cohesion becomes available to buy.
@export_range(0.0, 900.0, 1.0) var cohesion_unlock_seconds := 180.0

@export_group("Purchases")
## Biomass required to advance a system from level 1 to level 2.
@export_range(1.0, 500.0, 1.0) var level_base_cost := 20.0
## Multiplier applied to the level cost at every level. Exponential costs are what
## create the choice between cheaply raising a neglected system and paying heavily
## to specialise an advanced one: roughly 20, 35, 61, 107, 188, 328, 574.
@export_range(1.05, 4.0, 0.01) var level_cost_growth := 1.75
## Highest level a metabolism system may reach in one run.
@export_range(1, 60, 1) var maximum_level := 20
## Material budget one purchase injects into the territory on the axis it bought.
## A purchase the player cannot see in the simulation is only a number changing.
@export_range(0.0, 400.0, 1.0) var purchase_pulse_budget := 24.0

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

@export_group("Breakthroughs")
## Levels between behavioural Breakthrough choices for one system.
@export_range(1, 20, 1) var breakthrough_level_interval := 5
## Seconds between Rapid Cycling's small continuous Mass pulses.
@export_range(0.05, 10.0, 0.05) var rapid_cycling_interval_seconds := 0.65
## Seconds between Storage Organs' large periodic Mass releases.
@export_range(0.5, 30.0, 0.1) var storage_organs_interval_seconds := 6.00
## Share of a pulse's Mass that is released as outward Pressure. A pulse of pure
## Mass can only top up cells that are already full, so it was refused by the very
## frontier it was meant to push: the release has to shove as well as feed.
@export_range(0.0, 4.0, 0.05) var pulse_pressure_share := 0.85
## Mass budget released per Photosynthesis level by one metabolism pulse. At the
## old value a pulsing run and a non-pulsing one were within a twentieth of a
## percent of territory after ten seconds: the Breakthrough fired and nothing
## happened. It is priced to be seen.
@export_range(0.0, 600.0, 0.5) var pulse_mass_per_level := 42.0
## Fraction of the frontier one Apical Dominance injection concentrates into.
@export_range(0.02, 1.0, 0.01) var apical_focus_fraction := 0.18
## Frontier share Lateral Growth spreads an injection across. Above one on purpose:
## at exactly one it was the default, so the Breakthrough was a no-op that only
## looked like a choice. Lateral reaches further around the frontier than an
## uninvested run does, which is the opposite of Apical concentrating into a point.
@export_range(0.02, 6.0, 0.01) var lateral_focus_fraction := 2.40
## Pressure-advection multiplier supplied by Flexible Tissue, which lets Green
## deform far more before it breaks and rebound afterwards.
@export_range(0.5, 3.0, 0.01) var flexible_advection_multiplier := 1.35
## Extra regeneration per second supplied by Flexible Tissue's rebound.
@export_range(0.0, 2.0, 0.005) var flexible_rebound_per_second := 0.045
## Maturity-resistance multiplier supplied by Woody Tissue.
@export_range(1.0, 3.0, 0.01) var woody_resistance_multiplier := 1.30
## Pressure-advection multiplier supplied by Woody Tissue, which is what makes
## rigid Green hold its shape and then fail suddenly instead of bending.
@export_range(0.1, 1.0, 0.01) var woody_advection_multiplier := 0.72

@export_group("Overgrow")
## Fraction of the current Biomass Reserve one Overgrow spends.
@export_range(0.05, 1.0, 0.01) var overgrow_reserve_fraction := 0.50
## Smallest Reserve that may be spent on an Overgrow at all.
@export_range(1.0, 500.0, 1.0) var overgrow_minimum_reserve := 20.0
## Seconds before Overgrow may be pressed again.
@export_range(0.0, 120.0, 0.5) var overgrow_cooldown_seconds := 8.0

@export_group("Milestones")
## Biomass-per-second production milestones that each announce themselves once.
@export var production_milestones := PackedFloat32Array([
	10.0, 25.0, 50.0, 100.0, 250.0, 500.0
])
## Free Mass budget injected by the celebratory pulse at a production milestone.
@export_range(0.0, 400.0, 1.0) var milestone_pulse_mass := 45.0

var _levels := PackedInt32Array()
var _unlocked := PackedByteArray()
var _breakthroughs := PackedInt32Array()
var _pending_breakthrough_system := -1
var _pending_breakthrough_options := PackedInt32Array()
var _elapsed_seconds := 0.0
var _last_injection_mass := 0.0
var _injection_count := 0
var _pulse_accumulator := 0.0
var _pulse_charge := 0.0
var _overgrow_cooldown_remaining := 0.0
var _milestones_reached := 0
var _overgrow_count := 0


func _ready() -> void:
	assert(progression != null, "PhaseBMetabolism requires PhaseBProgression")
	assert(territory_field != null, "PhaseBMetabolism requires TerritoryField")
	reset_metabolism()


func reset_metabolism() -> void:
	_levels = PackedInt32Array([1, 1, 1])
	# Mass is the only axis on the table at the start. The rest arrive on the
	# clock, each announced when it does.
	_unlocked = PackedByteArray([1, 0, 0])
	_elapsed_seconds = 0.0
	_breakthroughs = PackedInt32Array([
		BreakthroughId.NONE,
		BreakthroughId.NONE,
		BreakthroughId.NONE,
	])
	_pending_breakthrough_system = -1
	_pending_breakthrough_options = PackedInt32Array()
	_pulse_accumulator = 0.0
	_pulse_charge = 0.0
	_overgrow_cooldown_remaining = 0.0
	_milestones_reached = 0
	_overgrow_count = 0
	_injection_count = 0
	levels_changed.emit()
	breakthroughs_changed.emit()


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	_overgrow_cooldown_remaining = maxf(0.0, _overgrow_cooldown_remaining - delta)
	_elapsed_seconds += delta
	_advance_unlocks()
	_advance_pulses(delta)
	_advance_milestones()


func _advance_unlocks() -> void:
	# The economy unfolds on the run clock. Each axis announces itself as the organ
	# that discovered it, and is immediately usable: no tutorial, no locked button
	# sitting on screen beforehand.
	for system_id in range(_unlocked.size()):
		if _unlocked[system_id] != 0:
			continue
		if _elapsed_seconds < get_unlock_seconds(system_id):
			continue
		_unlocked[system_id] = 1
		system_unlocked.emit(system_id)
		levels_changed.emit()


func try_purchase(system_id: int) -> bool:
	# One outright purchase. Costs climb steeply, so a deep specialisation
	# eventually prices itself out and the neglected axis becomes the better buy.
	if not can_purchase(system_id):
		return false
	var cost := get_level_cost(system_id)
	# spend_biomass reports what it actually took, and can_purchase has already
	# checked the Reserve covers it, so a short debit means something changed
	# underneath us and the level is not granted.
	if progression.spend_biomass(cost) < cost:
		return false
	_levels[system_id] += 1
	var level := _levels[system_id]
	purchased.emit(system_id, level, cost)
	level_reached.emit(system_id, level)
	levels_changed.emit()
	_pulse_purchase(system_id)
	status_requested.emit("%s LV. %d" % [
		get_axis_name(system_id).to_upper(),
		level,
	])
	_try_request_breakthrough(system_id)
	return true


func can_purchase(system_id: int) -> bool:
	if system_id < 0 or system_id >= _levels.size():
		return false
	if not is_system_unlocked(system_id):
		return false
	if _levels[system_id] >= maximum_level:
		return false
	return progression.biomass >= get_level_cost(system_id)


func has_affordable_purchase() -> bool:
	for system_id in range(_levels.size()):
		if can_purchase(system_id):
			return true
	return false


func _pulse_purchase(system_id: int) -> void:
	# The battlefield answers the purchase: material on Mass, a shove on Pressure,
	# a knitting-together on Cohesion. The axis bought is the one the ground shows.
	if purchase_pulse_budget <= 0.0:
		return
	match system_id:
		SystemId.PHOTOSYNTHESIS:
			_inject(purchase_pulse_budget, 0.0, 0.0)
		SystemId.MERISTEM:
			_inject(purchase_pulse_budget * 0.25, purchase_pulse_budget, 0.0)
		SystemId.CAMBIUM:
			_inject(purchase_pulse_budget * 0.25, 0.0, purchase_pulse_budget)


func _advance_pulses(delta: float) -> void:
	# Photosynthesis' Breakthrough decides the shape of its output rather than its
	# size: the same Mass either trickles out continuously or is stored and released
	# in a pulse the player can see the ecosystem breathe with.
	var breakthrough := _breakthroughs[SystemId.PHOTOSYNTHESIS]
	if breakthrough != BreakthroughId.RAPID_CYCLING and breakthrough != BreakthroughId.STORAGE_ORGANS:
		_pulse_accumulator = 0.0
		_pulse_charge = 0.0
		return
	var interval := (
		rapid_cycling_interval_seconds
		if breakthrough == BreakthroughId.RAPID_CYCLING
		else storage_organs_interval_seconds
	)
	var level_mass := pulse_mass_per_level * float(_levels[SystemId.PHOTOSYNTHESIS])
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


func _inject(
	mass: float,
	pressure: float,
	cohesion: float,
	focus_scale: float = 1.0
) -> void:
	_last_injection_mass = 0.0
	if territory_field == null:
		return
	var focus := get_injection_focus_fraction() * maxf(0.02, focus_scale)
	_injection_count += 1
	if is_equal_approx(focus, 1.0):
		_last_injection_mass = territory_field.overgrow(mass, pressure, cohesion).mass_applied
		return
	# Apical Dominance concentrates the same budget into a narrow slice of the
	# frontier, which the simulation resolves as protrusions and tendrils. Lateral
	# Growth does the reverse and spreads it further around the border than an
	# uninvested run reaches. Both are the same dial, read in both directions.
	var restored := territory_field.tuning.overgrow_frontier_sample_limit
	territory_field.tuning.overgrow_frontier_sample_limit = maxi(
		16,
		int(round(float(restored) * focus))
	)
	_last_injection_mass = territory_field.overgrow(mass, pressure, cohesion).mass_applied
	territory_field.tuning.overgrow_frontier_sample_limit = restored


func can_overgrow() -> bool:
	return (
		_overgrow_cooldown_remaining <= 0.0
		and progression.biomass >= overgrow_minimum_reserve
	)


func get_overgrow_cooldown_remaining() -> float:
	return _overgrow_cooldown_remaining


func get_overgrow_count() -> int:
	return _overgrow_count


func get_overgrow_cost() -> float:
	return progression.biomass * overgrow_reserve_fraction


func try_overgrow() -> bool:
	# Overgrow does not hand the run a fixed slice of territory. It converts the
	# Reserve into Mass, Pressure, and Cohesion in the proportions this run's
	# Metabolism actually is, injects them into the living frontier, and lets the
	# battlefield decide what that looks like.
	if not can_overgrow():
		return false
	var spent := get_overgrow_cost()
	if spent <= 0.0:
		return false
	progression.spend_biomass(spent)
	_overgrow_cooldown_remaining = overgrow_cooldown_seconds
	_overgrow_count += 1
	var mass := spent * get_identity_share(SystemId.PHOTOSYNTHESIS)
	var pressure := spent * get_identity_share(SystemId.MERISTEM)
	var cohesion := spent * get_identity_share(SystemId.CAMBIUM)
	_inject(mass, pressure, cohesion)
	overgrown.emit(mass, pressure, cohesion)
	status_requested.emit(
		"OVERGROW — %.0f Biomass spent as %.0f Mass, %.0f Pressure, %.0f Cohesion."
		% [spent, mass, pressure, cohesion]
	)
	return true


func get_identity_share(system_id: int) -> float:
	# Every axis takes part in an Overgrow, but what the run actually bought decides
	# how much of the burst becomes material, motion, or repair. Two runs pressing
	# the same button therefore get visibly different physical results.
	var total := 0
	for level in _levels:
		total += level
	if total <= 0:
		return 1.0 / float(maxi(1, _levels.size()))
	return float(get_level(system_id)) / float(total)


func is_system_unlocked(system_id: int) -> bool:
	if system_id < 0 or system_id >= _unlocked.size():
		return false
	return _unlocked[system_id] != 0


func get_unlocked_system_count() -> int:
	var count := 0
	for flag in _unlocked:
		if flag != 0:
			count += 1
	return count


func get_unlock_seconds(system_id: int) -> float:
	match system_id:
		SystemId.MERISTEM:
			return pressure_unlock_seconds
		SystemId.CAMBIUM:
			return cohesion_unlock_seconds
	return 0.0


func get_next_unlock_system() -> int:
	# At most the next one is ever teased; nothing beyond it is on screen.
	var best := -1
	var best_seconds := INF
	for system_id in range(_unlocked.size()):
		if _unlocked[system_id] != 0:
			continue
		var seconds := get_unlock_seconds(system_id)
		if seconds < best_seconds:
			best_seconds = seconds
			best = system_id
	return best


func debug_unlock_system(system_id: int) -> void:
	if system_id < 0 or system_id >= _unlocked.size() or _unlocked[system_id] != 0:
		return
	_unlocked[system_id] = 1
	system_unlocked.emit(system_id)
	levels_changed.emit()


func get_level(system_id: int) -> int:
	if system_id < 0 or system_id >= _levels.size():
		return 0
	return _levels[system_id]


func get_level_cost(system_id: int) -> float:
	return level_base_cost * pow(level_cost_growth, float(get_level(system_id) - 1))


func get_level_fraction(system_id: int) -> float:
	# How close the Reserve is to the next level of this axis. With outright
	# purchases the bar is affordability, not stored progress.
	var cost := get_level_cost(system_id)
	if cost <= 0.0:
		return 0.0
	return clampf(progression.biomass / cost, 0.0, 1.0)


func get_elapsed_seconds() -> float:
	return _elapsed_seconds


func get_milestones_reached() -> int:
	return _milestones_reached


func _try_request_breakthrough(system_id: int) -> void:
	if breakthrough_level_interval <= 0:
		return
	if _levels[system_id] % breakthrough_level_interval != 0:
		return
	if _breakthroughs[system_id] != BreakthroughId.NONE:
		# One authored branch per system for the prototype: later thresholds deepen
		# the choice already made rather than re-asking the same question.
		return
	_pending_breakthrough_system = system_id
	_pending_breakthrough_options = get_breakthrough_options(system_id)
	breakthrough_choice_requested.emit(system_id, _pending_breakthrough_options.duplicate())


static func get_breakthrough_options(system_id: int) -> PackedInt32Array:
	match system_id:
		SystemId.PHOTOSYNTHESIS:
			return PackedInt32Array([
				BreakthroughId.RAPID_CYCLING,
				BreakthroughId.STORAGE_ORGANS,
			])
		SystemId.MERISTEM:
			return PackedInt32Array([
				BreakthroughId.APICAL_DOMINANCE,
				BreakthroughId.LATERAL_GROWTH,
			])
		SystemId.CAMBIUM:
			return PackedInt32Array([
				BreakthroughId.FLEXIBLE_TISSUE,
				BreakthroughId.WOODY_TISSUE,
			])
	return PackedInt32Array()


func has_pending_breakthrough_choice() -> bool:
	return _pending_breakthrough_system >= 0


func get_pending_breakthrough_system() -> int:
	return _pending_breakthrough_system


func get_pending_breakthrough_options() -> PackedInt32Array:
	return _pending_breakthrough_options.duplicate()


func choose_breakthrough(breakthrough_id: int) -> bool:
	if _pending_breakthrough_system < 0:
		return false
	if _pending_breakthrough_options.find(breakthrough_id) == -1:
		return false
	_breakthroughs[_pending_breakthrough_system] = breakthrough_id
	_pending_breakthrough_system = -1
	_pending_breakthrough_options = PackedInt32Array()
	_pulse_accumulator = 0.0
	_pulse_charge = 0.0
	breakthroughs_changed.emit()
	status_requested.emit(
		"BREAKTHROUGH — %s." % get_breakthrough_name(breakthrough_id)
	)
	return true


func get_breakthrough(system_id: int) -> int:
	if system_id < 0 or system_id >= _breakthroughs.size():
		return BreakthroughId.NONE
	return _breakthroughs[system_id]


func has_breakthrough(breakthrough_id: int) -> bool:
	return _breakthroughs.find(breakthrough_id) != -1


func debug_grant_level(system_id: int, levels: int = 1) -> void:
	# Test and debug entry point: reach a level without paying its cost.
	if system_id < 0 or system_id >= _levels.size():
		return
	debug_unlock_system(system_id)
	for _step in range(maxi(1, levels)):
		if _levels[system_id] >= maximum_level:
			return
		_levels[system_id] += 1
		level_reached.emit(system_id, _levels[system_id])
		_try_request_breakthrough(system_id)
	levels_changed.emit()


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
	var multiplier := pow(
		cambium_resistance_per_level,
		float(get_level(SystemId.CAMBIUM) - 1)
	)
	if has_breakthrough(BreakthroughId.WOODY_TISSUE):
		multiplier *= woody_resistance_multiplier
	return multiplier


func get_cohesion_multiplier() -> float:
	# Reported to the field as one material property, so consumers ask the field
	# what the ground is like rather than asking the economy.
	return get_resistance_multiplier()


func get_regeneration_per_second() -> float:
	var regeneration := (
		cambium_regeneration_per_level
		* float(get_level(SystemId.CAMBIUM) - 1)
	)
	if has_breakthrough(BreakthroughId.FLEXIBLE_TISSUE):
		regeneration += flexible_rebound_per_second
	return regeneration


func get_advection_multiplier() -> float:
	# Flexible Green deforms heavily and springs back; Woody Green refuses to move
	# until it fails. Both read out of the same simulation parameter.
	if has_breakthrough(BreakthroughId.FLEXIBLE_TISSUE):
		return flexible_advection_multiplier
	if has_breakthrough(BreakthroughId.WOODY_TISSUE):
		return woody_advection_multiplier
	return 1.0


func get_fragment_decay_multiplier() -> float:
	return pow(
		cambium_fragment_decay_per_level,
		float(get_level(SystemId.CAMBIUM) - 1)
	)


func get_injection_focus_fraction() -> float:
	if has_breakthrough(BreakthroughId.APICAL_DOMINANCE):
		return apical_focus_fraction
	if has_breakthrough(BreakthroughId.LATERAL_GROWTH):
		return lateral_focus_fraction
	return 1.0


static func get_axis_name(system_id: int) -> String:
	# What the player buys is the physical axis; the organ name is how the run
	# discovered it. The drawer speaks in axes and the announcement in organs.
	match system_id:
		SystemId.PHOTOSYNTHESIS:
			return "Mass"
		SystemId.MERISTEM:
			return "Pressure"
		SystemId.CAMBIUM:
			return "Cohesion"
	return ""


static func get_purchase_verb(system_id: int) -> String:
	match system_id:
		SystemId.PHOTOSYNTHESIS:
			return "GROW"
		SystemId.MERISTEM:
			return "SURGE"
		SystemId.CAMBIUM:
			return "HARDEN"
	return "BUY"


static func get_axis_summary(system_id: int) -> String:
	match system_id:
		SystemId.PHOTOSYNTHESIS:
			return "More material"
		SystemId.MERISTEM:
			return "Push harder"
		SystemId.CAMBIUM:
			return "Hold together"
	return ""


static func get_unlock_line(system_id: int) -> String:
	match system_id:
		SystemId.MERISTEM:
			return "Spend Biomass to increase territorial Pressure."
		SystemId.CAMBIUM:
			return "Biomass can now reinforce and repair Green."
	return "Spend Biomass to build more territorial Mass."


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


static func get_breakthrough_name(breakthrough_id: int) -> String:
	match breakthrough_id:
		BreakthroughId.RAPID_CYCLING:
			return "RAPID CYCLING"
		BreakthroughId.STORAGE_ORGANS:
			return "STORAGE ORGANS"
		BreakthroughId.APICAL_DOMINANCE:
			return "APICAL DOMINANCE"
		BreakthroughId.LATERAL_GROWTH:
			return "LATERAL GROWTH"
		BreakthroughId.FLEXIBLE_TISSUE:
			return "FLEXIBLE TISSUE"
		BreakthroughId.WOODY_TISSUE:
			return "WOODY TISSUE"
	return "NO BREAKTHROUGH"


static func get_breakthrough_description(breakthrough_id: int) -> String:
	match breakthrough_id:
		BreakthroughId.RAPID_CYCLING:
			return "Mass is created continuously, in many small pulses."
		BreakthroughId.STORAGE_ORGANS:
			return "Mass accumulates and releases in large pulses; the Green breathes outward."
		BreakthroughId.APICAL_DOMINANCE:
			return "Pressure concentrates into protrusions and tendrils."
		BreakthroughId.LATERAL_GROWTH:
			return "Pressure spreads broadly across the whole frontier."
		BreakthroughId.FLEXIBLE_TISSUE:
			return "Green deforms heavily before breaking, and rebounds afterwards."
		BreakthroughId.WOODY_TISSUE:
			return "Green resists deformation, but fractures suddenly when overloaded."
	return ""
