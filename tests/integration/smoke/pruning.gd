## Pruning: the path that spends the run's own territory, and every rule that stops
## it spending the last of it.
##
## The harvest happens under the player, so almost everything here has to stand
## somewhere specific first - and a held ring eats the ground it stands on, which is
## why the fixtures graze rather than stand still.
class_name SmokePruning
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	var adaptations := prototype.adaptation_director

	# Pruning: the run cuts its own ecosystem back and fires the harvest outward.
	prototype.progression.reset_progression()
	prototype.progression.offer_pruning_path = true
	prototype.progression.debug_select_paths(
		Progression.PathId.PRUNING,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	var pruning := prototype.pruning_director
	pruning.reset_director()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	SmokeFixtures.grow_test_ecosystem(prototype)
	SmokeFixtures.stand_on_owned_ground(prototype)
	var green_before_cycle := prototype.territory_field.get_player_percent()
	var target_cells := pruning.get_cycle_target_cells()
	var launched := pruning.run_cycle_now()
	prototype.territory_field.recalculate_metrics_now()
	report.check(
		target_cells > 0
		and launched > 0
		and pruning.get_last_cycle_cells() > 0
		and pruning.get_last_cycle_cells() <= target_cells
		and prototype.territory_field.get_player_percent() < green_before_cycle
		and pruning.get_active_cutting_count() == launched,
		"standing on your own Green harvests it and raises Cuttings out of it"
	)

	# There is no cycle interval. The harvest is continuous for exactly as long as the
	# player stands on their own ground, so the only input is where you stand.
	prototype.territory_field.reset_field()
	SmokeFixtures.grow_test_ecosystem(prototype)
	pruning.reset_director()
	var harvest_home := SmokeFixtures.stand_on_owned_ground(prototype)
	for hold_step in range(60):
		SmokeFixtures.graze_owned_ground(prototype, harvest_home, float(hold_step) * 0.10)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
	var held_cells := pruning.get_upkeep_cells_taken()
	pruning.reset_director()
	var open_stand := SmokeFixtures.find_open_ground_position(prototype)
	prototype.player.global_position = prototype.territory_field.to_global(open_stand)
	# The ring coasts for `footing_grace_seconds` after the Green underfoot runs out,
	# and the harvest coasts with it -- it can still reach Green inside its own radius
	# even while she is standing on bare ground. What stops is everything after the
	# grace, so the reading is taken from there rather than from the step she left.
	for _grace_step in range(int(ceil((pruning.footing_grace_seconds + 0.2) * 60.0))):
		prototype.player.global_position = prototype.territory_field.to_global(open_stand)
		pruning.advance(1.0 / 60.0)
	var cells_after_grace := pruning.get_upkeep_cells_taken()
	for _idle_step in range(60):
		prototype.player.global_position = prototype.territory_field.to_global(open_stand)
		pruning.advance(1.0 / 60.0)
	report.check(
		held_cells > 0
		and not pruning.is_player_on_green()
		and pruning.get_upkeep_cells_taken() == cells_after_grace,
		"the harvest has no cooldown: it runs while you stand on Green and, once the "
			+ "footing grace is spent, not otherwise"
	)


	# A cycle takes the youngest ground it can find before it touches the oldest.
	prototype.territory_field.reset_field()
	SmokeFixtures.grow_test_ecosystem(prototype)
	var oldest_spot := SmokeFixtures.stand_on_owned_ground(prototype)
	var oldest_cell := prototype.territory_field.local_to_cell(oldest_spot)
	var oldest_index := (
		int(round(oldest_cell.y)) * prototype.territory_field.tuning.field_size.x
		+ int(round(oldest_cell.x))
	)
	prototype.territory_field._maturity[oldest_index] = 1.0
	pruning.run_cycle_now()
	report.check(
		prototype.territory_field._control[oldest_index] > 0.0,
		"the harvest eats Fresh ground before it touches Mature ground"
	)

	# The cut opens around the player rather than off to one side of them. The scan
	# used to walk the bounding box row by row and stop the moment it had its quota,
	# which for the small quota a continuous harvest asks for meant it never reached
	# past the top rows: the hole appeared above the Gardener instead of under them.
	prototype.territory_field.reset_field()
	SmokeFixtures.grow_test_ecosystem(prototype)
	pruning.reset_director()
	var centred_home := SmokeFixtures.stand_on_owned_ground(prototype)
	prototype.player.global_position = prototype.territory_field.to_global(centred_home)
	var centred_harvest := prototype.territory_field.drain_territory_in_radius(
		centred_home,
		pruning.upkeep_radius_pixels,
		6,
		pruning.pruned_ground_seconds,
		pruning.upkeep_inner_radius_pixels
	)
	var cut_above := 0
	var cut_below := 0
	var furthest_cut := 0.0
	for cut_position in centred_harvest.positions:
		if cut_position.y < centred_home.y:
			cut_above += 1
		elif cut_position.y > centred_home.y:
			cut_below += 1
		furthest_cut = maxf(furthest_cut, cut_position.distance_to(centred_home))
	report.check(
		centred_harvest.cell_count > 0
		and cut_above > 0
		and cut_below > 0
		and furthest_cut <= pruning.upkeep_radius_pixels + 1.0,
		"the harvest opens around the player instead of biting off one side "
			+ "(%d above, %d below, furthest %.1fpx)" % [cut_above, cut_below, furthest_cut]
	)

	# And it takes the ground the player is standing on. This is the positional cost of
	# the path: the cut is not a hole opened politely around her, it is the ground she
	# is standing in going away, so a ring held in one spot starves itself. The harvest
	# is gated on standing on Green, which is why `footing_grace_seconds` exists -- the
	# ring survives long enough to reach more, and no longer.
	report.check(
		is_zero_approx(pruning.upkeep_inner_radius_pixels)
		and prototype.territory_field.get_control_at_local(centred_home)
			<= prototype.territory_field.tuning.ownership_threshold
		and not pruning.is_player_on_green()
		and pruning.footing_grace_seconds > 0.0,
		"the harvest cuts the ground out from under the player"
	)

	# Cut ground comes back faster than ordinary neutral ground.
	prototype.territory_field.reset_field()
	SmokeFixtures.grow_test_ecosystem(prototype)
	pruning.reset_director()
	pruning.run_cycle_now()
	var pruned_spot := Vector2(-1.0, -1.0)
	for probe_y in range(2, 60):
		for probe_x in range(2, 108):
			var probe := prototype.territory_field.cell_to_local(Vector2(probe_x, probe_y))
			if prototype.territory_field.get_pruned_ground_at_local(probe) > 0.0:
				pruned_spot = probe
				break
		if pruned_spot.x >= 0.0:
			break
	report.check(
		pruned_spot.x >= 0.0
		and prototype.territory_field.get_pruned_ground_at_local(pruned_spot) > 0.0,
		"ground the harvest cut is marked as Pruned Ground"
	)

	# A held ring suppresses reclamation entirely, so the ground it burns stays burned
	# until the player lets go. This is the sacrifice being real rather than cosmetic:
	# without it the drained cells came back inside a fifth of a second.
	prototype.territory_field.reset_field()
	SmokeFixtures.grow_test_ecosystem(prototype)
	pruning.reset_director()
	# Far enough from the edge that a graze lap fits. `stand_on_owned_ground` returns
	# the first owned cell scanning from the corner, and most of a lap around that one
	# is off the field -- she ends up shuffling inside her own harvest radius, which
	# starves the ring and is the opposite of the hold this is measuring.
	var burn_home := SmokeFixtures.find_owned_cell_with_clearance(
		prototype, pruning.upkeep_radius_pixels * 1.7
	)
	prototype.player.global_position = prototype.territory_field.to_global(burn_home)
	for burn_step in range(90):
		SmokeFixtures.graze_owned_ground(prototype, burn_home, float(burn_step) * 0.07)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
		SmokeFixtures.step_field(prototype.territory_field, 1)
	prototype.territory_field.recalculate_metrics_now()
	var green_while_held := prototype.territory_field.get_player_percent()
	var regrowth_while_held := prototype.territory_field._pruned_regrowth_per_second
	prototype.player.global_position = prototype.territory_field.to_global(
		SmokeFixtures.find_open_ground_position(prototype)
	)
	# Past the footing grace, not one frame past stepping off: the ring is allowed a
	# moment off Green now, and letting go is what happens when that moment runs out.
	for _let_go_step in range(int(ceil((pruning.footing_grace_seconds + 0.2) * 60.0))):
		pruning.advance(1.0 / 60.0)
	SmokeFixtures.step_field(
		prototype.territory_field,
		int(prototype.territory_field.tuning.simulation_hz * 3.0)
	)
	prototype.territory_field.recalculate_metrics_now()
	report.check(
		pruning.is_holding() == false
		and is_equal_approx(regrowth_while_held, 0.0)
		and prototype.territory_field.get_player_percent() > green_while_held,
		"a held ring stops the burned ground reclaiming until the player lets go"
	)

	# Cuttings gather to the player, then launch and strike.
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 9999.0
	var cutting_target := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.BOSS,
		prototype.player.get_arena_position() + Vector2(60.0, 0.0)
	)
	var cutting_health_before := cutting_target.health
	pruning.run_cycle_now()
	for _cutting_step in range(240):
		cutting_target.position = prototype.player.get_arena_position() + Vector2(60.0, 0.0)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
		if cutting_target.health < cutting_health_before:
			break
	report.check(
		cutting_target.health < cutting_health_before,
		"Cuttings gather to the player and then strike what is nearby"
	)

	# Cuttings orbit while the player stands on their own Green, grinding what comes
	# into the ring, and fire outward when the ground is gone or left behind.
	prototype.territory_field.reset_field()
	SmokeFixtures.grow_test_ecosystem(prototype)
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 9999.0
	pruning.reset_director()
	var ring_home := SmokeFixtures.find_owned_cell_with_clearance(
		prototype, pruning.upkeep_radius_pixels * 1.7
	)
	prototype.player.global_position = prototype.territory_field.to_global(ring_home)
	# The ring fills over a few seconds of grazing. Standing still burns the ground
	# out from underneath and fires the ring, which is the loop working, so the
	# fixture moves the way a run has to.
	for gather_step in range(240):
		SmokeFixtures.graze_owned_ground(prototype, ring_home, float(gather_step) * 0.04)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
	var ring_victim := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.BOSS,
		prototype.combat.player.get_arena_position()
			+ Vector2(pruning.get_orbit_radius(), 0.0)
	)
	var ring_health_before := ring_victim.health
	var orbiting := 0
	for ring_step in range(120):
		SmokeFixtures.graze_owned_ground(prototype, ring_home, float(240 + ring_step) * 0.04)
		# The ring widens as the harvest fills it and it travels with the player, so
		# the victim is held on the band rather than at a radius measured once.
		ring_victim.position = (
			prototype.combat.player.get_arena_position()
			+ Vector2(pruning.get_orbit_radius(), 0.0)
		)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
		orbiting = maxi(orbiting, pruning.get_orbit_count())
	report.check(
		orbiting > 0
		and orbiting <= pruning.orbit_capacity
		and ring_victim.health < ring_health_before,
		"Cuttings orbit the player on their own Green and grind what enters the ring"
	)

	# A full ring turns over on a timer. Shedding the oldest spike to take a new one
	# is the ring working; doing it every third of a second is not, and that turned
	# holding into a free homing volley with the disc beside the point.
	var capacity_reached := false
	for capacity_step in range(900):
		SmokeFixtures.graze_owned_ground(prototype, ring_home, float(capacity_step) * 0.04)
		pruning.advance(1.0 / 60.0)
		if pruning.get_orbit_count() >= pruning.orbit_capacity:
			capacity_reached = true
			break
	var launched_at_capacity := pruning.get_cuttings_launched()
	var cells_at_capacity := pruning.get_upkeep_cells_taken()
	var held_seconds := 6.0
	for shed_step in range(int(held_seconds * 60.0)):
		SmokeFixtures.graze_owned_ground(prototype, ring_home, float(900 + shed_step) * 0.04)
		pruning.advance(1.0 / 60.0)
	var shed := pruning.get_cuttings_launched() - launched_at_capacity
	var allowed := int(ceil(held_seconds / pruning.full_ring_replacement_seconds)) + 1
	# The ring may fire partway through if the ground under it runs out, which is
	# the loop working; what is under test is the rate, not the ring surviving.
	report.check(
		capacity_reached
		and shed > 0
		and shed <= allowed
		and pruning.get_upkeep_cells_taken() > cells_at_capacity,
		"a full ring sheds on its authored interval and still costs the ground it stands on"
	)

	# Deadfall's payoff is that rate. The Evolution takes the ring from shedding a
	# thorn now and then to throwing them off continuously, which is precisely what
	# base Pruning must not do on its own.
	# Read the Evolution's rate without disturbing the run the checks below are
	# standing in: the pairing itself is covered where the Evolutions are.
	var base_interval := pruning.get_replacement_seconds()
	var restore_status := prototype.evolutions.evolution_status
	var restore_evolution := prototype.evolutions.active_evolution
	prototype.evolutions.evolution_status = Progression.EvolutionStatus.EVOLVED
	prototype.evolutions.active_evolution = Progression.EvolutionId.DEADFALL
	var deadfall_interval := pruning.get_replacement_seconds()
	prototype.evolutions.evolution_status = restore_status
	prototype.evolutions.active_evolution = restore_evolution
	report.check(
		is_equal_approx(base_interval, pruning.full_ring_replacement_seconds)
		and is_equal_approx(deadfall_interval, pruning.deadfall_replacement_seconds)
		and deadfall_interval < base_interval * 0.5
		and is_equal_approx(pruning.get_replacement_seconds(), base_interval),
		"DEADFALL turns the ring's occasional shed into continuous fire"
	)

	# The thicket is a disc, not a bare hoop. An enemy that closes all the way to
	# contact is standing in the runners strung between the spikes, not safely inside
	# an empty circle, which is the difference between this and a tripwire.
	prototype.territory_field.reset_field()
	SmokeFixtures.grow_test_ecosystem(prototype)
	pruning.reset_director()
	var inside_home := SmokeFixtures.stand_on_owned_ground(prototype)
	for inside_build in range(600):
		if pruning.get_orbit_count() >= 4:
			break
		SmokeFixtures.graze_owned_ground(prototype, inside_home, float(inside_build) * 0.04)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
	var inside_victim := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.BOSS,
		prototype.combat.player.get_arena_position()
	)
	var inside_health_before := inside_victim.health
	var inside_orbit := 0
	for inside_step in range(60):
		SmokeFixtures.graze_owned_ground(prototype, inside_home, float(400 + inside_step) * 0.04)
		inside_victim.position = prototype.combat.player.get_arena_position()
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
		inside_orbit = maxi(inside_orbit, pruning.get_orbit_count())
	report.check(
		inside_orbit > 0
		and inside_victim.health < inside_health_before,
		"the thicket sweeps everything the hoop encloses, not only what crosses it"
	)

	# Holding banks Charge and eats the ground underfoot. The player has to graze
	# across their own territory to keep feeding it, because standing still burns
	# the ground out from under them and fires the ring.
	prototype.territory_field.reset_field()
	SmokeFixtures.grow_test_ecosystem(prototype)
	pruning.reset_director()
	var charge_home := SmokeFixtures.stand_on_owned_ground(prototype)
	var charge_before := pruning.get_charge()
	var upkeep_before := pruning.get_upkeep_cells_taken()
	var charge_peak := 0.0
	for charge_step in range(int(pruning.charge_seconds * 60.0)):
		SmokeFixtures.graze_owned_ground(prototype, charge_home, float(charge_step) * 0.04)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
		charge_peak = maxf(charge_peak, pruning.get_charge())
	report.check(
		charge_before < 1.0
		and charge_peak > charge_before
		and pruning.get_upkeep_cells_taken() > upkeep_before,
		"holding the ring banks Charge and eats the Green underfoot to do it"
	)

	# Standing on one patch of Green must not feed a ring forever. The drain climbs
	# for every second the ring goes without firing, so a hold that never moves runs
	# its own footing out and fires, however much Green it started on.
	prototype.territory_field.reset_field()
	SmokeFixtures.grow_test_ecosystem(prototype)
	pruning.reset_director()
	var camp := SmokeFixtures.stand_on_owned_ground(prototype)
	var camp_rings_before := pruning.get_rings_released()
	var camp_early_rate := 0.0
	var camp_late_rate := 0.0
	for camp_step in range(3600):
		prototype.player.global_position = prototype.territory_field.to_global(camp)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
		if pruning.get_orbit_count() >= pruning.orbit_capacity and camp_early_rate <= 0.0:
			camp_early_rate = pruning.get_upkeep_cells_per_second()
		if pruning.get_hold_seconds() > 20.0:
			camp_late_rate = maxf(camp_late_rate, pruning.get_upkeep_cells_per_second())
		if pruning.get_rings_released() > camp_rings_before:
			break
	report.check(
		pruning.get_rings_released() > camp_rings_before
		and pruning.get_hold_seconds() < 60.0
		and (camp_late_rate == 0.0 or camp_late_rate > camp_early_rate),
		"a ring held on one patch of Green burns its own footing out and fires"
	)

	# Upkeep has to outgrow the ring's own damage, or a hold never ends. The check is
	# on the rule rather than on one authored ratio: the property used to live in the
	# Charge ramp alone, and it now lives mostly in the escalation, so comparing the
	# two Charge-scaled rates measured the wrong thing once those were tuned closer
	# together.
	var upkeep_at_zero := pruning.upkeep_cells_per_second
	var upkeep_ceiling := pruning.maximum_upkeep_cells_per_second
	report.check(
		pruning.upkeep_escalation_per_second > 0.0
		and upkeep_ceiling / maxf(0.01, upkeep_at_zero)
		> (1.0 + pruning.orbit_charge_damage_bonus)
		and pruning.upkeep_cells_per_second_at_charge >= upkeep_at_zero
		and pruning.launch_charge_damage_bonus > pruning.orbit_charge_damage_bonus,
		"upkeep outgrows the orbit, and the launch is what a long hold actually buys"
	)

	# Stepping off the Green throws the ring. A fresh ring first, since grazing has
	# already burned the ground the previous one was standing on.
	prototype.territory_field.reset_field()
	SmokeFixtures.grow_test_ecosystem(prototype)
	pruning.reset_director()
	# The whole ring is about to be measured, so it has to be somewhere the whole ring
	# exists: clear of the field edge by more than the orbit radius it will spin at.
	var release_home := SmokeFixtures.find_owned_cell_with_clearance(
		prototype, pruning.get_orbit_radius() + 30.0
	)
	prototype.player.global_position = prototype.territory_field.to_global(release_home)
	# Build only until the ring is loaded. Grazing on burned ground drops the ring on
	# its own, so a fixture that keeps going past a full ring measures nothing.
	for regather_step in range(600):
		if pruning.get_orbit_count() >= 4:
			break
		SmokeFixtures.graze_owned_ground(prototype, release_home, float(regather_step) * 0.04)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
	var rings_before := pruning.get_rings_released()
	var orbit_before_release := pruning.get_orbit_count()
	# Step off the Green, do not teleport off it. The ring orbits the player, so a
	# jump to the far side of the arena releases it from wherever the player used to
	# be and most of the spikes are culled before anything can look at them.
	var open_ground := SmokeFixtures.find_open_ground_near(prototype, release_home)
	prototype.player.global_position = prototype.territory_field.to_global(open_ground)
	# The ring is given `footing_grace_seconds` off Green before it tears -- she cuts
	# her own footing out constantly now, so an instant release would make the path
	# unholdable. What is under test is that the grace ends in a discharge.
	# Stop on the release, not after a fixed span. The checks below read the spikes the
	# discharge threw, and a spike that has been flying for another second has spent its
	# pierce on whatever it met on the way.
	for _release_step in range(int(ceil((pruning.footing_grace_seconds + 0.5) * 60.0))):
		pruning.advance(1.0 / 60.0)
		if pruning.get_rings_released() > rings_before:
			break
	report.check(
		orbit_before_release > 0
		and pruning.get_orbit_count() == 0
		and pruning.get_rings_released() > rings_before
		and is_equal_approx(pruning.get_charge(), 0.0),
		"leaving your own Green fires the whole ring outward and spends the Charge"
	)

	# A discharging hoop bursts outward rather than converging. Sixteen spikes all
	# seeking the nearest enemy overkills one target while the crowd walks past, and
	# it does not read as a ring coming apart either.
	var burst_outward := 0
	var burst_total := 0
	var burst_centre := prototype.combat.player.get_arena_position()
	for cutting in pruning._cuttings:
		if (
			cutting.state != PruningDirector.CuttingState.LAUNCHED
			or not cutting.natural_release
		):
			continue
		burst_total += 1
		if burst_centre.direction_to(cutting.position).dot(
			cutting.velocity.normalized()
		) > 0.7:
			burst_outward += 1
	report.check(
		burst_total > 1 and burst_outward == burst_total,
		"a discharging ring bursts outward instead of converging on one enemy"
	)

	# The discharge is the payout, so it has to be the largest number the path puts on
	# screen rather than a couple of seconds of grinding.
	report.check(
		pruning.launch_charge_damage_bonus >= 4.0 * pruning.orbit_charge_damage_bonus,
		"a banked discharge pays out far more for Charge than holding the ring does"
	)

	# A bursting spike drives through a crowd instead of stopping in the front rank.
	# Only the spikes the discharge threw. The ring is allowed a moment off Green before
	# it tears, and ordinary Cuttings launched during the gather are still in the air
	# when it does -- reading the whole pool took the minimum falloff across both and
	# reported the burst as no harder-driving than a loose Cutting, which is the pool
	# talking rather than the burst.
	var burst_pierce := 0
	var burst_falloff := 1.0
	for cutting in pruning._cuttings:
		if (
			cutting.state == PruningDirector.CuttingState.LAUNCHED
			and cutting.natural_release
		):
			burst_pierce = maxi(burst_pierce, cutting.pierce_remaining)
			burst_falloff = minf(burst_falloff, cutting.pierce_falloff)
	report.check(
		burst_pierce >= pruning.cutting_pierce
		and burst_falloff > pruning.cutting_pierce_falloff
		and pruning.launch_pierce_at_charge > 0,
		"discharged spikes drive further through a crowd than a loose Cutting does "
			+ "(pierce %d vs %d, falloff %.3f vs %.3f)"
			% [
				burst_pierce, pruning.cutting_pierce,
				burst_falloff, pruning.cutting_pierce_falloff
			]
	)


	# The safety floor stops the path spending the last of the run's ground. It is
	# counted in cells, not as a share of the arena: a percentage floor gates the
	# whole path on a state runs rarely reach, which switches Pruning off entirely.
	prototype.territory_field.reset_field()
	for strip_index in range(prototype.territory_field._control.size()):
		if prototype.territory_field._control[strip_index] > 0.0:
			prototype.territory_field._control[strip_index] = 0.0
	prototype.territory_field.recalculate_metrics_now()
	var cycles_before_floor := pruning.get_cycles_run()
	var launched_at_floor := pruning.run_cycle_now()
	report.check(
		prototype.territory_field.get_player_cell_count() <= pruning.safety_floor_cells
		and not pruning.is_above_safety_floor()
		and launched_at_floor == 0
		and pruning.get_cycles_run() == cycles_before_floor,
		"Pruning pauses rather than spending the last of the run's territory"
	)

	# The starting foothold must be able to prune. Gating the path on a percentage
	# of the arena meant a real run never reached it and nothing ever fired.
	prototype.territory_field.reset_field()
	prototype.territory_field.recalculate_metrics_now()
	report.check(
		prototype.territory_field.get_player_percent() < 10.0
		and pruning.is_above_safety_floor()
		and pruning.get_cycle_target_cells() > 0,
		"a run on its starting foothold can still run a Pruning Cycle"
	)

	# Cut ground grows itself back, so a cycle is a loan rather than a bleed.
	prototype.territory_field.reset_field()
	SmokeFixtures.grow_test_ecosystem(prototype)
	SmokeFixtures.stand_on_owned_ground(prototype)
	var green_before_loan := prototype.territory_field.get_player_percent()
	pruning.run_cycle_now()
	prototype.player.global_position = prototype.territory_field.to_global(
		SmokeFixtures.find_open_ground_position(prototype)
	)
	pruning.advance(1.0 / 60.0)
	prototype.territory_field.recalculate_metrics_now()
	var green_after_cut := prototype.territory_field.get_player_percent()
	SmokeFixtures.step_field(
		prototype.territory_field,
		int(prototype.territory_field.tuning.simulation_hz * 6.0)
	)
	var green_after_regrowth := prototype.territory_field.get_player_percent()
	report.check(
		green_after_cut < green_before_loan
		and green_after_regrowth > green_after_cut,
		"Pruned Ground grows back once the ring is let go, so a burn is a loan"
	)

	# Three of the four lines buy efficiency out of the same ground. Harvest Rate is
	# the one that spends more, and it is priced as a trade: more spikes per second
	# and a faster burn in the same rank, never one without the other.
	var cells_before_upgrades := pruning.get_cycle_target_cells()
	for quiet_line in [
		Progression.UpgradeId.PRUNING_CUTTING_YIELD,
		Progression.UpgradeId.PRUNING_CUTTING_DAMAGE,
		Progression.UpgradeId.PRUNING_CHARGE,
	]:
		prototype.progression._upgrade_levels[quiet_line] = 3
	var cost_unchanged := pruning.get_cycle_target_cells() == cells_before_upgrades
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.PRUNING_HARVEST_RATE
	] = 3
	report.check(
		cost_unchanged
		and prototype.pruning_director.get_pruning_cutting_yield_multiplier() > 1.0
		and prototype.pruning_director.get_pruning_cutting_damage_multiplier() > 1.0
		and prototype.pruning_director.get_pruning_charge_multiplier() > 1.0
		and pruning.get_charge_seconds() < pruning.charge_seconds
		and pruning.get_launch_charge_damage_bonus() > pruning.launch_charge_damage_bonus
		and prototype.pruning_director.get_pruning_harvest_rate_multiplier() > 1.0
		and pruning.get_cycle_target_cells() > cells_before_upgrades,
		"Pruning lines buy efficiency, and only Harvest Rate spends more to get more"
	)
	for pruning_line in [
		Progression.UpgradeId.PRUNING_HARVEST_RATE,
		Progression.UpgradeId.PRUNING_CUTTING_YIELD,
		Progression.UpgradeId.PRUNING_CUTTING_DAMAGE,
		Progression.UpgradeId.PRUNING_CHARGE,
	]:
		prototype.progression._upgrade_levels[pruning_line] = 0

	# The five Pruning pairings.
	var pruning_pairings := [
		[Progression.PathId.SPORE, Progression.EvolutionId.PIONEER],
		[Progression.PathId.BLOOM, Progression.EvolutionId.REBOUND],
		[Progression.PathId.BRAMBLE, Progression.EvolutionId.DEADFALL],
		[Progression.PathId.ROOT, Progression.EvolutionId.COPPICING],
	]
	var pruning_pairings_resolve := true
	for pairing in pruning_pairings:
		prototype.progression.debug_select_paths(
			Progression.PathId.PRUNING,
			pairing[0]
		)
		pruning_pairings_resolve = (
			pruning_pairings_resolve
			and prototype.progression.get_pair_evolution_id() == pairing[1]
		)
	report.check(
		pruning_pairings_resolve and pruning_pairings.size() == 4,
		"Pruning pairs into its four authored Evolutions"
	)

	# Coppice: the cut ground erupts with Seeds a moment later.
	prototype.progression.debug_select_paths(
		Progression.PathId.PRUNING,
		Progression.PathId.SPORE
	)
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	prototype.territory_field.reset_field()
	SmokeFixtures.grow_test_ecosystem(prototype)
	prototype.overlay.clear_effects()
	pruning.reset_director()
	SmokeFixtures.stand_on_owned_ground(prototype)
	for _pioneer_harvest in range(14):
		pruning.run_cycle_now()
	var seeds_before_pioneer := prototype.overlay.get_active_seed_count()
	for _pioneer_step in range(int(prototype.evolutions.pioneer_delay_seconds * 60.0) + 6):
		pruning.advance(1.0 / 60.0)
	report.check(
		seeds_before_pioneer == 0
		and prototype.overlay.get_active_seed_count() > 1,
		"Coppice germinates the ground the harvest cut, a moment after it cuts it"
	)

	# Rebound: a Bloom collapses the Green around it and gains Force for it.
	prototype.progression.debug_select_paths(
		Progression.PathId.PRUNING,
		Progression.PathId.BLOOM
	)
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	prototype.territory_field.reset_field()
	SmokeFixtures.grow_test_ecosystem(prototype)
	var rebound_spot := SmokeFixtures.find_owned_cell_position(prototype)
	var rebound_green_before := prototype.territory_field.get_player_percent()
	var rebound_force := pruning.prune_for_rebound(rebound_spot)
	prototype.territory_field.recalculate_metrics_now()
	report.check(
		rebound_force > 0.0
		and rebound_force <= prototype.evolutions.rebound_maximum_force
		and prototype.territory_field.get_player_percent() < rebound_green_before,
		"Rebound collapses Green into the Bloom and pays it back as Force"
	)

	# Deadfall: thorns torn out with the Green become extra Cuttings.
	prototype.progression.debug_select_paths(
		Progression.PathId.PRUNING,
		Progression.PathId.BRAMBLE
	)
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	SmokeFixtures.grow_test_ecosystem(prototype)
	SmokeFixtures.thorn_all_owned_ground(prototype)
	pruning.reset_director()
	prototype.combat.reset_combat()
	SmokeFixtures.stand_on_owned_ground(prototype)
	var deadfall_cuttings := pruning.run_cycle_now()
	prototype.progression.debug_select_paths(
		Progression.PathId.PRUNING,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	SmokeFixtures.grow_test_ecosystem(prototype)
	SmokeFixtures.thorn_all_owned_ground(prototype)
	pruning.reset_director()
	SmokeFixtures.stand_on_owned_ground(prototype)
	var plain_cuttings := pruning.run_cycle_now()
	report.check(
		deadfall_cuttings > plain_cuttings,
		"Deadfall turns the thorns the harvest tears out into extra Cuttings"
	)

	# Coppicing: Mature ground is worth more, and comes back faster.
	prototype.progression.debug_select_paths(
		Progression.PathId.PRUNING,
		Progression.PathId.ROOT
	)
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	SmokeFixtures.grow_test_ecosystem(prototype)
	for maturity_index in range(prototype.territory_field._maturity.size()):
		if prototype.territory_field._control[maturity_index] > 0.2:
			prototype.territory_field._maturity[maturity_index] = 1.0
	pruning.reset_director()
	prototype.combat.reset_combat()
	SmokeFixtures.stand_on_owned_ground(prototype)
	var coppicing_cuttings := pruning.run_cycle_now()
	# Reclamation is only compared once the ring is let go, since holding one stops
	# reclamation outright.
	prototype.player.global_position = prototype.territory_field.to_global(
		SmokeFixtures.find_open_ground_position(prototype)
	)
	pruning.advance(1.0 / 60.0)
	var coppicing_regrowth := prototype.territory_field._pruned_regrowth_per_second
	prototype.progression.debug_select_paths(
		Progression.PathId.PRUNING,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	pruning.advance(1.0 / 60.0)
	var plain_regrowth := prototype.territory_field._pruned_regrowth_per_second
	report.check(
		coppicing_cuttings > 0
		and coppicing_regrowth > plain_regrowth,
		"Coppicing pays out on ancient ground and drives it back faster"
	)
	prototype.territory_field.reset_field()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.progression.reset_progression()
	prototype.man_eater.reset_man_eater()
	prototype.overlay.clear_effects()
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.progression.reset_progression()
	prototype.man_eater.reset_man_eater()
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.progression.reset_progression()
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false

	var surge_waves := 0
	var normal_waves := 0
	for wave_index in range(1, 13):
		prototype.wave_director.elapsed_seconds = (
			float(wave_index - 1) * prototype.wave_director.wave_duration_seconds + 6.0
		)
		if prototype.wave_director.is_grazer_surge_wave():
			surge_waves += 1
		else:
			normal_waves += 1
	prototype.wave_director.elapsed_seconds = (
		float(prototype.wave_director.grazer_surge_wave_cycle - 2)
		* prototype.wave_director.wave_duration_seconds
		+ 6.0
	)
	var normal_wave_is_surge := prototype.wave_director.is_grazer_surge_wave()
	prototype.wave_director.elapsed_seconds = (
		float(prototype.wave_director.grazer_surge_wave_cycle)
		* prototype.wave_director.wave_duration_seconds
		- 6.0
	)
	report.check(
		surge_waves == 3
		and normal_waves == 9
		and prototype.wave_director.grazer_pack_cycle > 1
		and prototype.wave_director.is_grazer_surge_wave()
		and not normal_wave_is_surge,
		"Grazers lead a minority of packs outside the announced surge waves"
	)
	prototype.wave_director.reset_director()

	var grazer_profile := prototype.combat.grazer_profile
	report.check(
		grazer_profile.territory_actions_before_recovery > 0
		and grazer_profile.territory_recovery_seconds
		> grazer_profile.territory_action_interval_seconds,
		"Grazers graze in bursts followed by a recovery window"
	)
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	var grazing_enemy := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.GRAZER,
		prototype.territory_field.cell_to_local(
			Vector2(SmokeFixtures.find_player_frontier_cells(prototype.territory_field, 1)[0])
		)
	)
	var recovery_observed := false
	var bursts := 0
	for _grazing_step in range(600):
		grazing_enemy.territory_actions_taken = (
			grazer_profile.territory_actions_before_recovery - 1
		)
		grazing_enemy.territory_action_remaining = 0.0
		prototype.combat.simulate_step(1.0 / 60.0)
		bursts += 1
		if (
			grazing_enemy.territory_action_remaining
			> grazer_profile.territory_action_interval_seconds
		):
			recovery_observed = true
			break
	report.check(
		recovery_observed and bursts > 0,
		"a Grazer that finishes a burst pauses far longer than its normal action cadence"
	)
	prototype.combat.reset_combat()
	# Bramble is entered the only way any Adaptation is: by drafting one of its
	# upgrade lines out of an ordinary level-up. The frontier arms the moment it is.
	SmokeFixtures.acquire_adaptation(prototype, Progression.PathId.BRAMBLE)
	report.check(
		prototype.progression.owns_adaptation(Progression.PathId.BRAMBLE)
		and prototype.territory_field.is_bramble_enabled(),
		"drafting a Bramble line immediately arms the authoritative Green frontier"
	)
