class_name PhaseBRootNetwork
extends Node

## Root Metabolism, Phase 2: Biomass is produced by rooted ground and stored by the
## connected component that produced it.
##
## The old economy computed a rate from two territory percentages, which meant the
## number described a formula rather than the ecosystem. Here the field sums control
## x maturity over the cells of each connected component, this node turns that weight
## into a rate and pours it into that component's own reserve, and the number the run
## reads is a total of reserves that actually exist. Holding ground is worth something
## because the ground is worth something.
##
## Reserves belong to components, and components are relabelled every topology pass,
## so what a reserve is attached to is resolved through the field's overlap between
## passes rather than through raw labels. A component that splits divides its reserve
## between the pieces in proportion to the ground each kept; components that merge
## sum theirs.

signal reserves_changed(primary: float, total: float)
## A permanent development was bought. The doc requires every one of these to show
## itself on the battlefield immediately, so this carries what is needed to do that
## rather than only what changed in the numbers.
signal developed(domain_id: int, level: int, cost: float)
## A domain has developed far enough to change the organism's architecture, and the
## run has two ways it can go. Raised once per domain.
signal metamorphosis_choice_requested(domain_id: int, options: PackedInt32Array)
## The choice was taken. Carried so the battlefield can show the organism becoming a
## different kind of thing rather than a number changing.
signal metamorphosed(domain_id: int, metamorphosis_id: int)
## Cardiac Pumping delivered a beat, with what it carried. A pumped circulation that
## looks exactly like a continuous one is two names for one mechanic, so the beat has
## to be visible on the battlefield at the moment it lands.
signal support_pulsed(local_position: Vector2, biomass: float)

## The four developmental domains. These replace the three prototype developments the
## MVP shipped with: those existed to find out whether expansion, banking, and active
## control were three strategies a player would actually choose between, and they were.
## What they were not is physiology - three unrelated multipliers with no architecture
## underneath them. A domain is a part of the organism that can develop, and past a
## certain depth it stops being a bigger number and becomes a different body plan.
enum DomainId {
	## How quickly claimed territory becomes productive.
	ROOTING,
	## How much reserve can be banked, and where it lives.
	STORAGE,
	## How quickly and how far support travels.
	CIRCULATION,
	## How well established territory resists separation and erosion.
	ANCHORING,
}

## The metamorphoses, two per domain. Neither of a pair is the better one: each buys a
## strength by accepting the weakness the other does not have, which is the only way a
## permanent irreversible choice is a decision rather than a correct answer.
enum MetamorphosisId {
	NONE,
	## Rooting.
	COLONIAL_ROOTS,
	AGGRESSIVE_BRANCHING,
	## Storage.
	CENTRAL_TAPROOT,
	DISTRIBUTED_NODULES,
	## Circulation.
	CARDIAC_PUMPING,
	CONTINUOUS_PERISTALSIS,
	## Anchoring.
	FIBROUS_MAT,
	DEEP_TAPROOTS,
}
## Ground that was part of the main organism last pass is no longer connected to it,
## and left with this much Biomass. Only raised for a colony big enough or rich
## enough to be worth telling the player about.
signal colony_isolated(component_id: int, biomass: float, centroid: Vector2)
## A colony that was on its own has rejoined the main organism, bringing this much
## Biomass back into the reserve the run can actually spend.
signal colony_reconnected(component_id: int, biomass: float, centroid: Vector2)

@export_group("Collaborators")
## Authoritative field supplying component membership, production weight, and overlap.
@export var territory_field: TerritoryField

@export_group("Production")
## Biomass per second produced by one unit of production weight, where a cell at full
## control and full maturity contributes one unit. The doc's productivity constant.
@export_range(0.0, 4.0, 0.001) var biomass_per_weight_per_second := 0.055

@export_group("Storage")
## Reserve capacity contributed by each rooted cell in a component. Storage is per
## component rather than per cell: the doc rules out per-cell storage for the MVP.
@export_range(0.0, 20.0, 0.05) var capacity_per_rooted_cell := 1.60
## Capacity a component has before any of its ground is rooted, so a young colony can
## bank something at all rather than overflowing from its first second.
@export_range(0.0, 500.0, 1.0) var base_capacity := 40.0

@export_group("Player Influence")
## Share of the main organism's production that is directed to the ground around the
## player instead of being banked. It is a redirection, not a bonus: the network
## automates transport, and where the player stands is the demand it answers.
@export_range(0.0, 1.0, 0.01) var support_diversion_fraction := 0.35
## Reach of that support, as a multiple of the field's stamp radius. The doc asks for
## a cheap local field rather than routing, so this is a radius around the player and
## nothing more.
@export_range(0.1, 8.0, 0.1) var influence_radius_multiplier := 3.4
## Maturity delivered per unit of diverted Biomass. What the support does is establish
## roots faster where the player is, so ground the player defends becomes productive
## sooner than ground they merely own.
@export_range(0.0, 0.2, 0.0005) var support_maturity_per_biomass := 0.0075

@export_group("Development")
## Cost of the next development, whichever one it is. The price rises with how many
## have been bought and never with which: the doc is explicit that the player should
## be asking what the organism needs, not which line is cheapest, and equal pricing is
## the only way to keep that question from having a wrong answer.
@export_range(10.0, 5000.0, 10.0) var development_base_cost := 240.0
## What each development already bought multiplies the next one's price by.
@export_range(1.0, 3.0, 0.01) var development_cost_growth := 1.55
## Extra maturation rate per rank of Rooting, as a multiplier on the field's.
@export_range(0.0, 2.0, 0.01) var rooting_per_level := 0.35
## Extra reserve capacity per rank of Storage.
@export_range(0.0, 2.0, 0.01) var storage_per_level := 0.45
## Extra metabolic reach per rank of Circulation, applied both to the support the
## player draws while standing and to how far a release carries.
@export_range(0.0, 2.0, 0.01) var circulation_per_level := 0.30
## Maturity-resistance multiplier gained per rank of Anchoring. Anchoring is the only
## domain that does nothing for growth: it buys the organism the ability to keep what
## it already has, which is what makes it the choice a run reaches for when it is
## losing ground rather than when it is taking it.
@export_range(1.0, 2.0, 0.01) var anchoring_resistance_per_level := 1.10
## Small-fragment survival multiplier per rank of Anchoring; below one on purpose,
## because a lower decay rate is a fragment that survives longer.
@export_range(0.1, 1.0, 0.01) var anchoring_fragment_decay_per_level := 0.90

@export_group("Metamorphosis")
## Rank a domain must reach before it offers its metamorphosis. Layer 7 of the doc's
## unfolding schedule, and the last thing the economy reveals: three ranks of a domain
## is far enough in that the run has already learned what that domain does.
@export_range(1, 10, 1) var metamorphosis_rank := 3
## Primary-component capacity multiplier granted by Central Taproot.
@export_range(1.0, 4.0, 0.05) var central_taproot_primary_capacity := 1.75
## What Central Taproot leaves a severed colony, as a share of its ordinary capacity.
## The weakness is the whole point: the reserve lives in the middle, so ground that is
## cut off is cut off from the reserve as well.
@export_range(0.05, 1.0, 0.05) var central_taproot_colony_capacity := 0.35
## Discharge multiplier granted by Central Taproot, so a concentrated reserve also
## empties harder than a distributed one.
@export_range(1.0, 3.0, 0.05) var central_taproot_discharge := 1.40
## Primary-component capacity multiplier granted by Distributed Nodules.
@export_range(0.1, 1.0, 0.05) var distributed_nodules_primary_capacity := 0.85
## Colony capacity multiplier granted by Distributed Nodules.
@export_range(1.0, 5.0, 0.05) var distributed_nodules_colony_capacity := 2.40
## Seconds between Cardiac Pumping's support beats. Between them nothing is delivered
## and the diverted share accumulates, so the same budget arrives as a shove.
@export_range(0.2, 10.0, 0.05) var cardiac_interval_seconds := 1.60
## Reach multiplier applied to one Cardiac beat, which is what makes a beat read as a
## surge through the network rather than as the ordinary trickle arriving late.
@export_range(1.0, 4.0, 0.05) var cardiac_beat_reach := 1.65
## Extra support Continuous Peristalsis carries, for flowing without the losses a
## pulsed system pays between beats.
@export_range(1.0, 3.0, 0.01) var peristalsis_support_multiplier := 1.22
## Reach multiplier Continuous Peristalsis adds, smaller than a Cardiac beat's and
## paid every frame rather than at intervals.
@export_range(1.0, 3.0, 0.01) var peristalsis_reach := 1.15
## Share of an isolated colony's production Colonial Roots turns into its own maturity
## support, so cut-off ground establishes itself instead of only banking.
@export_range(0.0, 1.0, 0.05) var colonial_roots_support_fraction := 0.45
## Maturation multiplier Aggressive Branching adds to the connected organism.
@export_range(1.0, 3.0, 0.05) var aggressive_branching_maturation := 1.55
## Fragment-decay multiplier granted by Fibrous Mat. A wide anchoring mat is what makes
## a front hard to peel away, which is a statement about scraps surviving.
@export_range(0.05, 1.0, 0.01) var fibrous_mat_fragment_decay := 0.45
## Resistance multiplier granted by Fibrous Mat; deliberately the smaller of the two.
@export_range(1.0, 3.0, 0.01) var fibrous_mat_resistance := 1.12
## Resistance multiplier granted by Deep Taproots, which is the larger one and applies
## to ground that has had time to mature rather than to the whole organism.
@export_range(1.0, 4.0, 0.01) var deep_taproots_resistance := 1.85
## Maturity a cell must carry before Deep Taproots defends it at all.
@export_range(0.0, 1.0, 0.01) var deep_taproots_maturity_threshold := 0.55

@export_group("Colony Alerts")
## Rooted cells a severed colony must hold before it is worth announcing. The doc is
## explicit that a disconnection is only reported when it is meaningful; every scrap
## of ground torn off a frontier would otherwise raise one.
@export_range(0, 500, 1) var colony_alert_minimum_rooted_cells := 12
## Biomass a severed colony must carry to be announced regardless of its size, so a
## small but well-stocked colony is not lost quietly.
@export_range(0.0, 500.0, 1.0) var colony_alert_minimum_biomass := 25.0

## Reserve held by each current component, indexed by its current label.
var _reserves := PackedFloat32Array()
var _primary_component := -1
var _primary_reserve := 0.0
var _total_reserve := 0.0
var _primary_generation := 0.0
var _isolated_component_count := 0
var _support_per_second := 0.0
var _domain_levels := PackedInt32Array([0, 0, 0, 0])
## The metamorphosis each domain settled on, indexed by domain. NONE until the domain
## reaches its rank and the run answers.
var _metamorphoses := PackedInt32Array([
	MetamorphosisId.NONE,
	MetamorphosisId.NONE,
	MetamorphosisId.NONE,
	MetamorphosisId.NONE,
])
## Domain whose metamorphosis has been offered and not yet answered, or -1.
var _pending_metamorphosis_domain := -1
## Seconds since the last Cardiac beat, and what has accumulated waiting for one.
var _cardiac_accumulator := 0.0
var _cardiac_stored_support := 0.0
## The topology pass whose relabel has already been carried. The field's overlap
## describes one relabel; applying it twice would redistribute reserves that are
## already indexed by the labels it maps onto.
var _carried_generation := -1
## Whether the last carry actually consumed a new relabel, which is the only moment
## connectivity can have changed.
var _relabeled_this_advance := false


func _ready() -> void:
	assert(territory_field != null, "PhaseBRootNetwork requires TerritoryField")
	reset_network()


func reset_network() -> void:
	_reserves = PackedFloat32Array()
	_primary_component = -1
	_primary_reserve = 0.0
	_total_reserve = 0.0
	_primary_generation = 0.0
	_isolated_component_count = 0
	_support_per_second = 0.0
	_domain_levels = PackedInt32Array([0, 0, 0, 0])
	_metamorphoses = PackedInt32Array([
		MetamorphosisId.NONE,
		MetamorphosisId.NONE,
		MetamorphosisId.NONE,
		MetamorphosisId.NONE,
	])
	_pending_metamorphosis_domain = -1
	_cardiac_accumulator = 0.0
	_cardiac_stored_support = 0.0
	_carried_generation = -1
	reserves_changed.emit(0.0, 0.0)


func advance(delta: float, player_position: Vector2) -> void:
	if delta <= 0.0:
		return
	_cardiac_accumulator += delta
	# The primary is recorded before anything moves, because sever and reconnect are
	# both statements about which component the player's ground used to be.
	var previous_primary := _primary_component
	_carry_reserves_across_relabel()
	# The primary is resolved before production so the player's share can be taken out
	# of what the organism makes this step rather than out of what it had already
	# banked. Taken afterwards, a component sitting at capacity discarded its
	# production and then paid for support again out of its reserve, which drained a
	# full network for standing still.
	_resolve_primary(player_position)
	_produce(delta, player_position)
	_primary_reserve = get_component_reserve(_primary_component)
	if _relabeled_this_advance:
		_announce_connectivity_changes(previous_primary)
	reserves_changed.emit(_primary_reserve, _total_reserve)


func _carry_reserves_across_relabel() -> void:
	# The field hands over the overlap between the previous pass's components and
	# this one's. Each previous reserve is divided among the components that took its
	# ground, in proportion to how much of it they took, which divides on a split and
	# sums on a merge without either case being special-cased.
	# One relabel per advance is assumed, and the run guarantees it: the field runs a
	# topology pass twice a second and this advances every frame. The overlap only ever
	# describes the most recent relabel, so consuming two at once would map reserves
	# through labels that had already been replaced.
	var generation := territory_field.get_topology_generation()
	_relabeled_this_advance = generation != _carried_generation
	if not _relabeled_this_advance:
		return
	_carried_generation = generation
	var component_count := territory_field.get_component_count()
	var overlap_count := territory_field.get_component_overlap_count()
	var carried := PackedFloat32Array()
	carried.resize(component_count)
	carried.fill(0.0)
	if overlap_count > 0 and not _reserves.is_empty():
		var previous_totals := PackedInt32Array()
		previous_totals.resize(_reserves.size())
		previous_totals.fill(0)
		for overlap_index in range(overlap_count):
			var previous_id := territory_field.get_component_overlap_previous(overlap_index)
			if previous_id < previous_totals.size():
				previous_totals[previous_id] += (
					territory_field.get_component_overlap_cells(overlap_index)
				)
		for overlap_index in range(overlap_count):
			var current_id := territory_field.get_component_overlap_current(overlap_index)
			var previous_id := territory_field.get_component_overlap_previous(overlap_index)
			if current_id >= component_count or previous_id >= _reserves.size():
				continue
			var previous_total := previous_totals[previous_id]
			if previous_total <= 0:
				continue
			var share := (
				float(territory_field.get_component_overlap_cells(overlap_index))
				/ float(previous_total)
			)
			carried[current_id] += _reserves[previous_id] * share
	_reserves = carried


func _produce(delta: float, player_position: Vector2) -> void:
	var component_count := territory_field.get_component_count()
	if _reserves.size() != component_count:
		_reserves.resize(component_count)
	var supporting := _should_direct_support(player_position)
	# Cardiac Pumping holds the diverted share back and delivers it in one beat. The
	# beat is decided once per step rather than per component so a single organism
	# cannot pump twice in a frame by being labelled twice.
	var cardiac := has_metamorphosis(MetamorphosisId.CARDIAC_PUMPING)
	var beating := cardiac and _cardiac_accumulator >= cardiac_interval_seconds
	_support_per_second = 0.0
	_total_reserve = 0.0
	for component_id in range(component_count):
		var weight := territory_field.get_component_production_weight(component_id)
		var capacity := get_component_capacity(component_id)
		var produced := weight * biomass_per_weight_per_second * delta
		if supporting and component_id == _primary_component and produced > 0.0:
			# The player's share never reaches the reserve, so support costs exactly
			# what banking would have gained and nothing more. At capacity the rest
			# would have been discarded anyway, which is why support keeps flowing
			# from a full network for free.
			var diverted := produced * support_diversion_fraction
			produced -= diverted
			_support_per_second = (
				weight * biomass_per_weight_per_second * support_diversion_fraction
			)
			if has_metamorphosis(MetamorphosisId.CONTINUOUS_PERISTALSIS):
				# Flowing rather than pumping loses nothing between beats, so the same
				# diversion carries further and delivers more of itself.
				diverted *= peristalsis_support_multiplier
				_support_per_second *= peristalsis_support_multiplier
			if cardiac:
				# Between beats the share is held rather than spent. What the player sees
				# is nothing, nothing, nothing, a surge - which is the difference between
				# the two circulations and the only reason to prefer either.
				_cardiac_stored_support += diverted
				if beating:
					territory_field.queue_maturity_support(
						player_position,
						_cardiac_stored_support * support_maturity_per_biomass,
						(
							influence_radius_multiplier
							* get_reach_multiplier()
							* cardiac_beat_reach
						)
					)
					support_pulsed.emit(player_position, _cardiac_stored_support)
					_cardiac_stored_support = 0.0
			else:
				territory_field.queue_maturity_support(
					player_position,
					diverted * support_maturity_per_biomass,
					influence_radius_multiplier * get_reach_multiplier()
				)
		elif (
			component_id != _primary_component
			and produced > 0.0
			and has_metamorphosis(MetamorphosisId.COLONIAL_ROOTS)
		):
			# Colonial Roots: a colony that is on its own establishes itself rather than
			# only banking against a reconnection that may never come. The support is
			# spent at the colony, out of the colony's own production, so severed ground
			# is genuinely independent instead of being fed from a network it cannot
			# reach.
			var colonial := produced * colonial_roots_support_fraction
			produced -= colonial
			territory_field.queue_maturity_support(
				territory_field.get_component_centroid(component_id),
				colonial * support_maturity_per_biomass,
				influence_radius_multiplier * get_reach_multiplier()
			)
		# A full component stops producing rather than silently discarding the
		# overflow, so a run that is banking can see that it needs more storage.
		_reserves[component_id] = clampf(_reserves[component_id] + produced, 0.0, capacity)
		_total_reserve += _reserves[component_id]
	if beating:
		_cardiac_accumulator = 0.0


func _should_direct_support(player_position: Vector2) -> bool:
	# The player is a demand signal, not a second management game. Standing on the
	# organism's ground pulls part of what that organism is producing into the ground
	# underfoot, where it establishes roots faster. Movement is already the player's
	# continuous input, so this reads it rather than asking for another one.
	if support_diversion_fraction <= 0.0 or _primary_component < 0:
		return false
	# Only while the player is standing on the organism that would be paying. Support
	# flowing to someone standing in hostile territory would be poured into ground the
	# network does not hold, which is a way to lose Biomass by walking.
	return territory_field.get_component_id_at_local(player_position) == _primary_component


func _resolve_primary(player_position: Vector2) -> void:
	# The main organism is the component the player is standing in. Off its own
	# ground - crossing neutral ground, or pushed into hostile territory - the run
	# keeps the largest component as its main network rather than losing its reserve
	# for as long as the player is off the grass.
	var component_count := territory_field.get_component_count()
	var primary := territory_field.get_component_id_at_local(player_position)
	if primary < 0 or primary >= component_count:
		primary = _largest_component()
	_primary_component = primary
	_primary_reserve = get_component_reserve(primary)
	_primary_generation = (
		territory_field.get_component_production_weight(primary)
		* biomass_per_weight_per_second
	)
	var isolated := 0
	for component_id in range(component_count):
		if component_id != primary and _reserves[component_id] > 0.0:
			isolated += 1
	_isolated_component_count = isolated


func _announce_connectivity_changes(previous_primary: int) -> void:
	# Both events are read straight off the overlap the carry already used. A piece of
	# the main organism that now answers to a different component was severed; a
	# component that now answers to the main organism has reconnected. Nothing has to
	# be tracked between passes beyond which component was primary.
	if previous_primary < 0:
		return
	# Which component counts as the main organism can move without any ground having
	# moved: the player walks onto different green, or the largest component changes
	# and the fallback follows it. Reconnection therefore requires the current primary
	# to be continuous with the previous one. Without that check, the run's own
	# untouched territory reports itself as having just rejoined the organism the
	# moment it becomes the biggest thing on the board.
	var primary_is_continuous := false
	for overlap_index in range(territory_field.get_component_overlap_count()):
		if (
			territory_field.get_component_overlap_current(overlap_index) == _primary_component
			and territory_field.get_component_overlap_previous(overlap_index) == previous_primary
		):
			primary_is_continuous = true
			break
	for overlap_index in range(territory_field.get_component_overlap_count()):
		var current_id := territory_field.get_component_overlap_current(overlap_index)
		var previous_id := territory_field.get_component_overlap_previous(overlap_index)
		if previous_id == previous_primary and current_id != _primary_component:
			if _is_colony_worth_announcing(current_id):
				colony_isolated.emit(
					current_id,
					get_component_reserve(current_id),
					territory_field.get_component_centroid(current_id)
				)
		elif (
			primary_is_continuous
			and current_id == _primary_component
			and previous_id != previous_primary
		):
			# The reserve announced is the colony's own, not the merged total, because
			# what the player needs to know is how much came back.
			if _is_colony_worth_announcing(current_id):
				colony_reconnected.emit(
					current_id,
					get_component_reserve(current_id),
					territory_field.get_component_centroid(current_id)
				)


func _is_colony_worth_announcing(component_id: int) -> bool:
	return (
		territory_field.get_component_rooted_cells(component_id)
		>= colony_alert_minimum_rooted_cells
		or get_component_reserve(component_id) >= colony_alert_minimum_biomass
	)


func get_isolated_colony_positions() -> PackedVector2Array:
	# Where the colonies actually are, so the battlefield can carry the warning before
	# any of it reaches a sidebar.
	var positions := PackedVector2Array()
	for component_id in range(territory_field.get_component_count()):
		if component_id == _primary_component:
			continue
		if not _is_colony_worth_announcing(component_id):
			continue
		positions.append(territory_field.get_component_centroid(component_id))
	return positions


func get_support_per_second() -> float:
	return _support_per_second


func get_isolated_colony_reserves() -> PackedFloat32Array:
	# Parallel to get_isolated_colony_positions, so a colony's marker can say what the
	# run is losing access to rather than only that something is out there.
	var reserves := PackedFloat32Array()
	for component_id in range(territory_field.get_component_count()):
		if component_id == _primary_component:
			continue
		if not _is_colony_worth_announcing(component_id):
			continue
		reserves.append(get_component_reserve(component_id))
	return reserves


func _largest_component() -> int:
	var best := -1
	var best_cells := -1
	for component_id in range(territory_field.get_component_count()):
		var cells := territory_field.get_component_rooted_cells(component_id)
		if cells > best_cells:
			best_cells = cells
			best = component_id
	return best


func get_component_capacity(component_id: int) -> float:
	var capacity := (
		base_capacity
		+ float(territory_field.get_component_rooted_cells(component_id))
		* capacity_per_rooted_cell
	) * get_storage_multiplier()
	# Where the reserve lives is the whole Storage metamorphosis, so it is applied here
	# rather than to one global number: the same organism holds a different amount
	# depending on which part of it is being asked.
	var central := component_id == _primary_component
	if has_metamorphosis(MetamorphosisId.CENTRAL_TAPROOT):
		capacity *= (
			central_taproot_primary_capacity
			if central
			else central_taproot_colony_capacity
		)
	elif has_metamorphosis(MetamorphosisId.DISTRIBUTED_NODULES):
		capacity *= (
			distributed_nodules_primary_capacity
			if central
			else distributed_nodules_colony_capacity
		)
	return capacity


func get_development_level(domain_id: int) -> int:
	if domain_id < 0 or domain_id >= _domain_levels.size():
		return 0
	return _domain_levels[domain_id]


func get_total_development_levels() -> int:
	var total := 0
	for level in _domain_levels:
		total += level
	return total


func get_development_cost() -> float:
	# One price for all four, so the question a player answers is which the organism
	# needs rather than which is affordable.
	return development_base_cost * pow(
		development_cost_growth,
		float(get_total_development_levels())
	)


func can_develop() -> bool:
	# A domain waiting on its metamorphosis blocks the drawer: the run has already been
	# asked a question and buying past it would answer it by accident.
	return _pending_metamorphosis_domain < 0 and _primary_reserve >= get_development_cost()


func try_develop(domain_id: int) -> bool:
	if domain_id < 0 or domain_id >= _domain_levels.size():
		return false
	if not can_develop():
		return false
	var cost := get_development_cost()
	var spent := spend_from_primary(cost)
	if spent < cost:
		# The reserve moved underneath the purchase, so nothing is granted and what was
		# taken is put back rather than the run paying for half a development.
		if spent > 0.0 and _primary_component >= 0:
			_reserves[_primary_component] += spent
			_primary_reserve = _reserves[_primary_component]
			_total_reserve += spent
		return false
	_domain_levels[domain_id] += 1
	developed.emit(domain_id, _domain_levels[domain_id], cost)
	_try_request_metamorphosis(domain_id)
	return true


func _try_request_metamorphosis(domain_id: int) -> void:
	# Layer 7. A domain asks its question exactly once, at the rank where it has enough
	# behind it that the answer is about the organism the run has actually grown.
	if _metamorphoses[domain_id] != MetamorphosisId.NONE:
		return
	if _domain_levels[domain_id] < metamorphosis_rank:
		return
	_pending_metamorphosis_domain = domain_id
	metamorphosis_choice_requested.emit(
		domain_id,
		get_metamorphosis_options(domain_id)
	)


func has_pending_metamorphosis() -> bool:
	return _pending_metamorphosis_domain >= 0


func get_pending_metamorphosis_domain() -> int:
	return _pending_metamorphosis_domain


func choose_metamorphosis(metamorphosis_id: int) -> bool:
	if _pending_metamorphosis_domain < 0:
		return false
	var domain_id := _pending_metamorphosis_domain
	if not get_metamorphosis_options(domain_id).has(metamorphosis_id):
		return false
	_metamorphoses[domain_id] = metamorphosis_id
	_pending_metamorphosis_domain = -1
	metamorphosed.emit(domain_id, metamorphosis_id)
	return true


func debug_fill_primary_reserve() -> void:
	# Fills the main organism to capacity, for exercising what a full reserve unlocks
	# without waiting for the ground to earn it. It resolves the organism first if the
	# network has not advanced yet, so the lever works on a board that has been reset
	# rather than only on one that has already been played.
	var component_count := territory_field.get_component_count()
	if _reserves.size() != component_count:
		_reserves.resize(component_count)
	if _primary_component < 0 or _primary_component >= _reserves.size():
		_primary_component = _largest_component()
	if _primary_component < 0 or _primary_component >= _reserves.size():
		return
	_reserves[_primary_component] = get_component_capacity(_primary_component)
	_primary_reserve = _reserves[_primary_component]
	_total_reserve = 0.0
	for reserve in _reserves:
		_total_reserve += reserve
	reserves_changed.emit(_primary_reserve, _total_reserve)


func debug_grant_development(domain_id: int) -> void:
	# A free rank, for exercising what a domain does without waiting out the reserve
	# that would ordinarily buy it. It goes through the same metamorphosis check as a
	# bought rank, so the fork is reachable this way too.
	if domain_id < 0 or domain_id >= _domain_levels.size():
		return
	_domain_levels[domain_id] += 1
	developed.emit(domain_id, _domain_levels[domain_id], 0.0)
	_try_request_metamorphosis(domain_id)


func get_metamorphosis(domain_id: int) -> int:
	if domain_id < 0 or domain_id >= _metamorphoses.size():
		return MetamorphosisId.NONE
	return _metamorphoses[domain_id]


func has_metamorphosis(metamorphosis_id: int) -> bool:
	return _metamorphoses.has(metamorphosis_id)


static func get_metamorphosis_options(domain_id: int) -> PackedInt32Array:
	# The pairing is a property of the domain and lives in one place, so the panel that
	# offers the choice and the code that validates the answer cannot disagree about
	# which two a domain has.
	match domain_id:
		DomainId.ROOTING:
			return PackedInt32Array([
				MetamorphosisId.COLONIAL_ROOTS,
				MetamorphosisId.AGGRESSIVE_BRANCHING,
			])
		DomainId.STORAGE:
			return PackedInt32Array([
				MetamorphosisId.CENTRAL_TAPROOT,
				MetamorphosisId.DISTRIBUTED_NODULES,
			])
		DomainId.CIRCULATION:
			return PackedInt32Array([
				MetamorphosisId.CARDIAC_PUMPING,
				MetamorphosisId.CONTINUOUS_PERISTALSIS,
			])
		DomainId.ANCHORING:
			return PackedInt32Array([
				MetamorphosisId.FIBROUS_MAT,
				MetamorphosisId.DEEP_TAPROOTS,
			])
	return PackedInt32Array()


func get_maturation_multiplier() -> float:
	# Rooting: sustained Green establishes faster, so claimed ground turns into
	# productive infrastructure sooner. The expansion domain.
	var multiplier := 1.0 + rooting_per_level * float(
		get_development_level(DomainId.ROOTING)
	)
	if has_metamorphosis(MetamorphosisId.AGGRESSIVE_BRANCHING):
		multiplier *= aggressive_branching_maturation
	return multiplier


func get_storage_multiplier() -> float:
	# Storage: the network banks more before it overflows. The banking domain.
	return 1.0 + storage_per_level * float(get_development_level(DomainId.STORAGE))


func get_reach_multiplier() -> float:
	# Circulation: the player's influence carries further through connected Green, both
	# while standing and when releasing. The active-control domain.
	var multiplier := 1.0 + circulation_per_level * float(
		get_development_level(DomainId.CIRCULATION)
	)
	if has_metamorphosis(MetamorphosisId.CONTINUOUS_PERISTALSIS):
		multiplier *= peristalsis_reach
	return multiplier


func get_discharge_multiplier() -> float:
	# What a release is worth. Only Central Taproot moves it: a reserve concentrated in
	# one structure empties harder than one spread through the whole organism.
	if has_metamorphosis(MetamorphosisId.CENTRAL_TAPROOT):
		return central_taproot_discharge
	return 1.0


func get_anchor_resistance_multiplier() -> float:
	# Anchoring, as the field's maturity resistance. Fibrous Mat holds a wide front
	# together loosely; Deep Taproots make a smaller, older core almost immovable.
	var multiplier := pow(
		anchoring_resistance_per_level,
		float(get_development_level(DomainId.ANCHORING))
	)
	if has_metamorphosis(MetamorphosisId.FIBROUS_MAT):
		multiplier *= fibrous_mat_resistance
	elif has_metamorphosis(MetamorphosisId.DEEP_TAPROOTS):
		multiplier *= deep_taproots_resistance
	return multiplier


func get_anchor_fragment_decay_multiplier() -> float:
	# Lower is better here: it is the rate at which a scrap of Green gives up. Fibrous
	# Mat is the one that keeps the scraps, which is what "hard to peel away" means at
	# the resolution the field actually simulates.
	var multiplier := pow(
		anchoring_fragment_decay_per_level,
		float(get_development_level(DomainId.ANCHORING))
	)
	if has_metamorphosis(MetamorphosisId.FIBROUS_MAT):
		multiplier *= fibrous_mat_fragment_decay
	return multiplier


func get_deep_taproot_threshold() -> float:
	# Deep Taproots defends ground that has had time to become old. Below the threshold
	# it does nothing at all, which is the weakness the wide mat does not have.
	if has_metamorphosis(MetamorphosisId.DEEP_TAPROOTS):
		return deep_taproots_maturity_threshold
	return 0.0


static func get_development_name(domain_id: int) -> String:
	match domain_id:
		DomainId.ROOTING:
			return "Rooting"
		DomainId.STORAGE:
			return "Storage"
		DomainId.CIRCULATION:
			return "Circulation"
		DomainId.ANCHORING:
			return "Anchoring"
		_:
			return "Development"


static func get_development_caption(domain_id: int) -> String:
	# What fits on the button. The drawer's captions are two or three words wide by
	# design, and a sentence there runs into the button beside it; the sentence lives
	# in the tooltip and the status line, which have room for it.
	match domain_id:
		DomainId.ROOTING:
			return "Roots faster"
		DomainId.STORAGE:
			return "Banks more"
		DomainId.CIRCULATION:
			return "Reaches further"
		DomainId.ANCHORING:
			return "Holds ground"
		_:
			return ""


static func get_development_summary(domain_id: int) -> String:
	match domain_id:
		DomainId.ROOTING:
			return "Held ground establishes roots faster."
		DomainId.STORAGE:
			return "The network banks more before it overflows."
		DomainId.CIRCULATION:
			return "Your influence carries further through the roots."
		DomainId.ANCHORING:
			return "Established Green resists erosion and tearing."
		_:
			return ""


static func get_metamorphosis_name(metamorphosis_id: int) -> String:
	match metamorphosis_id:
		MetamorphosisId.COLONIAL_ROOTS:
			return "COLONIAL ROOTS"
		MetamorphosisId.AGGRESSIVE_BRANCHING:
			return "AGGRESSIVE BRANCHING"
		MetamorphosisId.CENTRAL_TAPROOT:
			return "CENTRAL TAPROOT"
		MetamorphosisId.DISTRIBUTED_NODULES:
			return "DISTRIBUTED NODULES"
		MetamorphosisId.CARDIAC_PUMPING:
			return "CARDIAC PUMPING"
		MetamorphosisId.CONTINUOUS_PERISTALSIS:
			return "CONTINUOUS PERISTALSIS"
		MetamorphosisId.FIBROUS_MAT:
			return "FIBROUS MAT"
		MetamorphosisId.DEEP_TAPROOTS:
			return "DEEP TAPROOTS"
	return "NO METAMORPHOSIS"


static func get_metamorphosis_description(metamorphosis_id: int) -> String:
	# Both halves of the trade, always, because a metamorphosis is permanent and a
	# permanent choice presented as pure upside is a choice the player did not make.
	match metamorphosis_id:
		MetamorphosisId.COLONIAL_ROOTS:
			return (
				"Severed ground roots itself from its own production. Colonies survive "
				+ "alone; the main organism grows no faster."
			)
		MetamorphosisId.AGGRESSIVE_BRANCHING:
			return (
				"Connected Green roots newly taken frontier far faster. Anything cut "
				+ "off gains nothing."
			)
		MetamorphosisId.CENTRAL_TAPROOT:
			return (
				"The reserve concentrates into one structure: far more capacity and a "
				+ "heavier discharge. A severed colony keeps almost nothing."
			)
		MetamorphosisId.DISTRIBUTED_NODULES:
			return (
				"Storage spreads through the network. Severing costs you little; the "
				+ "central reserve peaks lower."
			)
		MetamorphosisId.CARDIAC_PUMPING:
			return (
				"Support is withheld and delivered as periodic surges that reach much "
				+ "further. Between beats nothing arrives."
			)
		MetamorphosisId.CONTINUOUS_PERISTALSIS:
			return (
				"Support flows without pause, carrying more of itself and reaching "
				+ "further every moment. It never surges."
			)
		MetamorphosisId.FIBROUS_MAT:
			return (
				"A wide shallow mat. Torn scraps of Green hold on far longer, so fronts "
				+ "are hard to peel away. Mature ground is no tougher than before."
			)
		MetamorphosisId.DEEP_TAPROOTS:
			return (
				"Mature ground becomes almost impossible to uproot. Young Green is left "
				+ "exactly as fragile as it was."
			)
	return ""


func get_component_reserve(component_id: int) -> float:
	if component_id < 0 or component_id >= _reserves.size():
		return 0.0
	return _reserves[component_id]


func get_primary_component() -> int:
	return _primary_component


func get_primary_reserve() -> float:
	return _primary_reserve


func get_primary_capacity() -> float:
	return get_component_capacity(_primary_component)


func get_primary_generation_per_second() -> float:
	return _primary_generation


func get_total_reserve() -> float:
	return _total_reserve


func get_isolated_component_count() -> int:
	return _isolated_component_count


func translocate_to_primary(recovery_fraction: float) -> float:
	# Circulation's verb, resolved here because reserves belong to components and this
	# is the only node that may move one. Every component that is not the main organism
	# is emptied, part of what it held survives the journey through ground the organism
	# does not hold, and the rest is gone rather than being quietly refunded.
	#
	# The primary is still capped: a colony's reserve arriving at a full organism is
	# overflow, exactly as its own production would have been, so a run cannot use
	# Translocate to hold more than its storage allows.
	if _primary_component < 0 or _primary_component >= _reserves.size():
		return 0.0
	var gathered := 0.0
	for component_id in range(_reserves.size()):
		if component_id == _primary_component:
			continue
		gathered += _reserves[component_id]
		_reserves[component_id] = 0.0
	if gathered <= 0.0:
		return 0.0
	var arriving := gathered * clampf(recovery_fraction, 0.0, 1.0)
	var capacity := get_component_capacity(_primary_component)
	var before := _reserves[_primary_component]
	_reserves[_primary_component] = clampf(before + arriving, 0.0, capacity)
	var accepted := _reserves[_primary_component] - before
	_primary_reserve = _reserves[_primary_component]
	_total_reserve = 0.0
	for reserve in _reserves:
		_total_reserve += reserve
	reserves_changed.emit(_primary_reserve, _total_reserve)
	return accepted


func spend_from_primary(amount: float) -> float:
	# Spending draws on the main organism only. A colony that is cut off holds its own
	# Biomass and cannot be drawn from until the ground reconnects, which is the whole
	# reason components own reserves rather than the run owning one number.
	if amount <= 0.0 or _primary_component < 0 or _primary_component >= _reserves.size():
		return 0.0
	var spent := minf(amount, _reserves[_primary_component])
	_reserves[_primary_component] -= spent
	_primary_reserve = _reserves[_primary_component]
	_total_reserve = maxf(0.0, _total_reserve - spent)
	reserves_changed.emit(_primary_reserve, _total_reserve)
	return spent
