## Bramble and Root, the two paths that act on ground rather than on enemies:
## Entanglement and the shove that answers it, and the support an established colony
## projects into its own interior.
##
## Both read the field's frontier and development masks directly, because what they
## do is only visible as a difference between the frontier and the ground behind it.
class_name SmokeBrambleRoot
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	var adaptations := prototype.adaptation_director

	# Its other three lines are open at rank 0 straight away, and with the second
	# Core slot still free the rest of the roster stays on the table beside them.
	prototype.progression._pending_upgrade_options.clear()
	var bramble_upgrade_options := prototype.progression.get_ordinary_candidate_lines()
	var open_slot_draft_paths: Array[int] = []
	for option_id in bramble_upgrade_options:
		var upgrade_path := prototype.progression._get_upgrade_path(option_id)
		if not open_slot_draft_paths.has(upgrade_path):
			open_slot_draft_paths.append(upgrade_path)
	report.check(
		bramble_upgrade_options.has(Progression.UpgradeId.BRAMBLE_ENTANGLEMENT_RATE)
		and bramble_upgrade_options.has(Progression.UpgradeId.BRAMBLE_REPULSION)
		and open_slot_draft_paths.has(Progression.PathId.BLOOM),
		"drafts expose Bramble's remaining lines and keep the roster open for Core 2"
	)

	prototype.territory_field.debug_establish_bramble()
	var frontier_position := SmokeFixtures.find_player_frontier(prototype.territory_field)
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	var bramble_enemy := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.BOSS,
		frontier_position
	)
	var untangled_tick := prototype.combat.get_bramble_tick_damage(bramble_enemy, 1.0)
	var bramble_enemy_health_before := bramble_enemy.health
	prototype.combat.simulate_step(0.0)
	var crossing_damage := bramble_enemy_health_before - bramble_enemy.health
	var contact_hit_flash := prototype.combat.get_enemy_hit_flash_remaining(bramble_enemy.id)
	# Entanglement builds over seconds, so contact is measured across a stay rather
	# than on the frame the enemy arrives.
	var entangled_health_before := bramble_enemy.health
	for _bramble_step in range(40):
		bramble_enemy.position = frontier_position
		prototype.combat.simulate_step(0.1)
	var entangled_damage := entangled_health_before - bramble_enemy.health
	var entangled_tick := prototype.combat.get_bramble_tick_damage(bramble_enemy, 1.0)
	var baseline_bramble_speed_multiplier := bramble_enemy.movement_speed_multiplier
	report.check(
		frontier_position.x >= 0.0
		and crossing_damage > untangled_tick
		and bramble_enemy.entanglement > 0.5
		and entangled_tick > untangled_tick
		and entangled_damage > 0.0
		and baseline_bramble_speed_multiplier < 1.0
		and bramble_enemy.active
		and contact_hit_flash > 0.0
		and prototype.combat.get_active_damage_number_count() > 0,
		"crossing the hedge stings once, then Entanglement ramps thorn damage and slow"
	)

	# Leaving Green sheds Entanglement gradually rather than resetting it, so a
	# brief step off the territory does not shake the thorns loose.
	var entanglement_peak := bramble_enemy.entanglement
	var neutral_position := Vector2(6.0, 6.0)
	bramble_enemy.position = neutral_position
	prototype.combat.simulate_step(0.1)
	var briefly_left := bramble_enemy.entanglement
	for _neutral_step in range(40):
		bramble_enemy.position = neutral_position
		prototype.combat.simulate_step(0.1)
	report.check(
		is_equal_approx(
			prototype.territory_field.get_bramble_coverage_at_local(neutral_position),
			0.0
		)
		and briefly_left < entanglement_peak
		and briefly_left > entanglement_peak * 0.8
		and is_equal_approx(bramble_enemy.entanglement, 0.0)
		and is_equal_approx(bramble_enemy.movement_speed_multiplier, 1.0),
		"Entanglement decays off Green instead of resetting the moment contact breaks"
	)

	var slow_before_entanglement_line := prototype.bramble_director.get_slow_fraction()
	# Maxed rather than one rank, because the draft above may already have taken a
	# rank in these lines and the check is that investing deepens the control.
	prototype.progression._upgrade_levels[Progression.UpgradeId.BRAMBLE_ENTANGLEMENT] = (
		prototype.progression.maximum_upgrade_level
	)
	prototype.progression._upgrade_levels[Progression.UpgradeId.BRAMBLE_REPULSION] = 1
	prototype.progression._upgrade_levels[Progression.UpgradeId.BRAMBLE_ENTANGLEMENT_RATE] = (
		prototype.progression.maximum_upgrade_level
	)
	prototype._apply_progression_modifiers()
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	var repelled_enemy := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.ELITE,
		frontier_position
	)
	var repulsion_health_before := repelled_enemy.health
	var repulsion_position_before := repelled_enemy.position
	prototype.combat.repel_territory_attacker(repelled_enemy)
	# The shove travels over time rather than teleporting, so nothing has moved yet
	# on the frame the pulse fires.
	var instant_shove := repulsion_position_before.distance_to(repelled_enemy.position)
	var launched_knockback := repelled_enemy.knockback_remaining > 0.0
	# The pulse itself must deal nothing. Ordinary chip ticks keep resolving while
	# the enemy slides across Green, so damage is sampled on the pulse frame alone.
	var pulse_damage := repulsion_health_before - repelled_enemy.health
	var travelled_partway := 0.0
	var knockback_steps := 0
	while repelled_enemy.knockback_remaining > 0.0 and knockback_steps < 120:
		prototype.combat.simulate_step(1.0 / 60.0)
		knockback_steps += 1
		if knockback_steps == 2:
			travelled_partway = repulsion_position_before.distance_to(
				repelled_enemy.position
			)
	var shoved_distance := repulsion_position_before.distance_to(repelled_enemy.position)
	var repeat_position_before := repelled_enemy.position
	for _repulsion_attempt in range(4):
		prototype.combat.repel_territory_attacker(repelled_enemy)
	var repeat_shove := repeat_position_before.distance_to(repelled_enemy.position)
	report.check(
		launched_knockback
		and is_equal_approx(instant_shove, 0.0)
		and travelled_partway > 0.0
		and travelled_partway < shoved_distance
		and knockback_steps > 1
		and shoved_distance > 0.0
		and is_equal_approx(pulse_damage, 0.0)
		and is_equal_approx(repeat_shove, 0.0)
		and prototype.bramble_director.get_slow_fraction()
		> slow_before_entanglement_line
		and prototype.bramble_director.get_entanglement_rate_multiplier() > 1.0,
		"Repulsion slides a territory attacker out over time without damaging it, once per cooldown"
	)

	# Every way an enemy weakens Green counts as an attack, not erosion alone.
	var repelled_behaviours := true
	var checked_behaviours := 0
	for weakening_role in [
		EnemyKinds.Role.GRAZER,
		EnemyKinds.Role.CORRUPTOR,
		EnemyKinds.Role.WARDEN,
	]:
		prototype.combat.reset_combat()
		prototype.combat._cane_remaining = 999.0
		var weakening_enemy := SmokeFixtures.spawn_bramble_contact_enemy(
			prototype,
			weakening_role,
			frontier_position
		)
		# Give the enemy a frame of contact so its ground sample is populated.
		prototype.combat.simulate_step(0.0)
		weakening_enemy.position = frontier_position
		weakening_enemy.bramble_repulsion_remaining = 0.0
		weakening_enemy.knockback_remaining = 0.0
		prototype.combat._perform_enemy_territory_action(weakening_enemy)
		repelled_behaviours = (
			repelled_behaviours and weakening_enemy.knockback_remaining > 0.0
		)
		checked_behaviours += 1
	report.check(
		checked_behaviours == 3 and repelled_behaviours,
		"grazing, hostile conversion, and maturity suppression all trigger Repulsion"
	)

	# Grasping Roots: full Entanglement pins an enemy, then an immunity window stops
	# it from being pinned again immediately.
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.BRAMBLE_GRASPING_THORNS
	] = 1
	prototype._apply_progression_modifiers()
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	var rooted_enemy := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.ELITE,
		frontier_position
	)
	rooted_enemy.entanglement = 0.5
	prototype.combat.simulate_step(0.0)
	var half_entangled_root := rooted_enemy.bramble_ensnare_remaining
	rooted_enemy.entanglement = 1.0
	rooted_enemy.position = frontier_position
	prototype.combat.simulate_step(0.0)
	var ensnare_seconds := rooted_enemy.bramble_ensnare_remaining
	var ensnare_duration_for_indicator := rooted_enemy.bramble_ensnare_duration
	var rooted_speed := rooted_enemy.movement_speed_multiplier
	# Serve out the hold, then confirm the immunity window blocks an instant re-root.
	for _root_step in range(30):
		rooted_enemy.position = frontier_position
		rooted_enemy.entanglement = 1.0
		prototype.combat.simulate_step(0.05)
	report.check(
		is_equal_approx(half_entangled_root, 0.0)
		and ensnare_seconds > 0.0
		and is_equal_approx(ensnare_seconds, prototype.bramble_director.get_ensnare_seconds())
		and is_equal_approx(rooted_speed, 0.0)
		and is_equal_approx(rooted_enemy.bramble_ensnare_remaining, 0.0)
		and rooted_enemy.bramble_ensnare_immunity_remaining > 0.0,
		"Grasping Roots pins a fully Entangled enemy, then holds it immune for a spell"
	)
	report.check(
		is_equal_approx(ensnare_duration_for_indicator, ensnare_seconds)
		and ensnare_duration_for_indicator > 0.0,
		"a rooted enemy records the hold's full length so its indicator can unwind"
	)
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.BRAMBLE_GRASPING_THORNS
	] = 0
	prototype._apply_progression_modifiers()

	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	# The starting foothold is small and sits away from basalt, so Green is grown
	# onto the upper island first. The rule under test is that unclaimable ground
	# never becomes damaging frontier, not where the fixture happens to begin.
	var basalt_approach := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.350,
		prototype.territory_field.tuning.arena_size.y * 0.340
	)
	prototype.territory_field.queue_seed_growth(basalt_approach, 4.0, 0.0, 1.0, 2.5)
	prototype.territory_field._apply_pending_commands()
	SmokeFixtures.step_field(prototype.territory_field, 2)
	prototype.territory_field.debug_establish_bramble()
	frontier_position = SmokeFixtures.find_player_frontier(prototype.territory_field)
	var green_rock_cell := SmokeFixtures.find_green_unclaimable_cell(prototype.territory_field)
	var green_rock_index := (
		green_rock_cell.y * prototype.territory_field.tuning.field_size.x
		+ green_rock_cell.x
	)
	report.check(
		green_rock_cell.x >= 0
		and prototype.territory_field._claimable_mask[green_rock_index] != 0
		and prototype.territory_field._control[green_rock_index]
		> prototype.territory_field.tuning.ownership_threshold
		and not prototype.territory_field._is_player_frontier_cell(
			green_rock_cell.x,
			green_rock_cell.y
		),
		"unclaimable arena and basalt edges do not become damaging Bramble frontier"
	)
	# Measure erosion on the pristine fixture, not on the ground grown out toward
	# the basalt above, because every leg of this comparison resets the field.
	prototype.territory_field.reset_field()
	frontier_position = SmokeFixtures.find_player_frontier(prototype.territory_field)
	prototype.territory_field.set_bramble_modifiers(false, 1.0)
	var unarmored_before := prototype.territory_field.get_control_at_local(frontier_position)
	prototype.territory_field.queue_erosion(frontier_position, 0.45, 0.5)
	prototype.territory_field._apply_pending_commands()
	var unarmored_loss := (
		unarmored_before - prototype.territory_field.get_control_at_local(frontier_position)
	)
	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.territory_field.debug_establish_bramble()
	var armored_before := prototype.territory_field.get_control_at_local(frontier_position)
	prototype.territory_field.queue_erosion(frontier_position, 0.45, 0.5)
	prototype.territory_field._apply_pending_commands()
	var armored_loss := (
		armored_before - prototype.territory_field.get_control_at_local(frontier_position)
	)
	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(false, 1.0)
	var unarmored_conversion_before := (
		prototype.territory_field.get_control_at_local(frontier_position)
	)
	prototype.territory_field.queue_hostile_growth(frontier_position, 0.45, 0.5)
	prototype.territory_field._apply_pending_commands()
	var unarmored_conversion_loss := (
		unarmored_conversion_before
		- prototype.territory_field.get_control_at_local(frontier_position)
	)
	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.territory_field.debug_establish_bramble()
	var armored_conversion_before := (
		prototype.territory_field.get_control_at_local(frontier_position)
	)
	prototype.territory_field.queue_hostile_growth(frontier_position, 0.45, 0.5)
	prototype.territory_field._apply_pending_commands()
	var armored_conversion_loss := (
		armored_conversion_before
		- prototype.territory_field.get_control_at_local(frontier_position)
	)
	report.check(
		unarmored_loss > 0.0
		and armored_loss > 0.0
		and armored_loss < unarmored_loss
		and unarmored_conversion_loss > 0.0
		and armored_conversion_loss > 0.0
		and armored_conversion_loss < unarmored_conversion_loss,
		"selecting Bramble alone hardens the Green frontier against erosion and conversion"
	)

	var field_tuning := prototype.territory_field.tuning
	var contact_band := prototype.combat.bramble_frontier_band_pixels
	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	var growing_frontier := SmokeFixtures.find_player_frontier(prototype.territory_field)
	var fresh_strength := prototype.territory_field.get_bramble_strength_at_local(
		growing_frontier,
		contact_band
	)
	SmokeFixtures.step_field(prototype.territory_field, int(round(field_tuning.simulation_hz * 1.5)))
	var developing_strength := prototype.territory_field.get_bramble_strength_at_local(
		growing_frontier,
		contact_band
	)
	SmokeFixtures.step_field(prototype.territory_field, int(round(field_tuning.simulation_hz * 2.5)))
	var developed_strength := prototype.territory_field.get_bramble_strength_at_local(
		growing_frontier,
		contact_band
	)
	report.check(
		is_equal_approx(fresh_strength, field_tuning.bramble_minimum_strength)
		and developing_strength > fresh_strength
		and developing_strength < 1.0
		and developed_strength > developing_strength
		and is_equal_approx(developed_strength, 1.0),
		"newly exposed Bramble starts near minimum strength and matures to full thorns over seconds"
	)

	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	var development_cells := SmokeFixtures.find_player_frontier_cells(prototype.territory_field, 2)
	var field_width := prototype.territory_field.tuning.field_size.x
	var fresh_index := development_cells[0].y * field_width + development_cells[0].x
	var mature_index := development_cells[1].y * field_width + development_cells[1].x
	prototype.territory_field._maturity[fresh_index] = 0.0
	prototype.territory_field._maturity[mature_index] = 1.0
	prototype.territory_field._bramble_development[fresh_index] = 0.0
	prototype.territory_field._bramble_development[mature_index] = 0.0
	prototype.territory_field.step_simulation()
	report.check(
		development_cells[0].x >= 0
		and prototype.territory_field._player_frontier_mask[fresh_index] != 0
		and prototype.territory_field._player_frontier_mask[mature_index] != 0
		and prototype.territory_field._bramble_development[mature_index]
		> prototype.territory_field._bramble_development[fresh_index],
		"mature Green establishes Bramble faster than freshly created territory"
	)

	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.territory_field.debug_establish_bramble()
	var wound_position := SmokeFixtures.find_player_frontier(prototype.territory_field)
	var wound_cell := prototype.territory_field.local_to_cell(wound_position)
	var wound_index := (
		int(round(wound_cell.y)) * field_width + int(round(wound_cell.x))
	)
	var wound_development_before: float = (
		prototype.territory_field._bramble_development[wound_index]
	)
	var wound_steps := PackedFloat32Array()
	for _wound_bite in range(3):
		prototype.territory_field.queue_erosion(wound_position, 0.45, 0.5)
		prototype.territory_field._apply_pending_commands()
		wound_steps.append(prototype.territory_field._bramble_development[wound_index])
	var wound_degrades_in_bands := true
	var previous_wound_development := wound_development_before
	for wound_step in wound_steps:
		wound_degrades_in_bands = (
			wound_degrades_in_bands
			and wound_step < previous_wound_development
			and previous_wound_development - wound_step
			<= field_tuning.bramble_disturbance_maximum_step + 0.0001
		)
		previous_wound_development = wound_step
	report.check(
		is_equal_approx(wound_development_before, 1.0)
		and wound_degrades_in_bands
		and wound_steps[0] > 0.0
		and wound_steps[2] < wound_steps[0],
		"erosion degrades established thorns through bands instead of erasing them"
	)
	report.check(
		prototype.territory_field._bramble_alert[wound_index] > 0.0,
		"a bitten frontier section is flagged as under attack so it regrows faster"
	)

	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.territory_field.step_simulation()
	var behind_index := SmokeFixtures.find_deep_owned_cell(prototype.territory_field, contact_band)
	var behind_position := prototype.territory_field.cell_to_local(
		Vector2(behind_index % field_width, behind_index / field_width)
	)
	var interior_coverage := prototype.territory_field.get_bramble_coverage_at_local(
		behind_position
	)
	var interior_frontier_strength := prototype.territory_field.get_bramble_strength_at_local(
		behind_position,
		contact_band
	)
	prototype.territory_field.set_bramble_modifiers(false, 1.0)
	var unarmed_coverage := prototype.territory_field.get_bramble_coverage_at_local(
		behind_position
	)
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	report.check(
		behind_index >= 0
		and is_equal_approx(interior_coverage, 1.0)
		and is_equal_approx(interior_frontier_strength, 0.0)
		and is_equal_approx(unarmed_coverage, 0.0),
		"every cell of owned Green carries Bramble even where no frontier hedge stands"
	)

	# Bury a stretch of frontier under friendly growth: the hedge bonus goes, the
	# hazard itself does not, which is what frees Bramble from frontier geometry.
	var buried_cells := SmokeFixtures.find_player_frontier_cells(prototype.territory_field, 1)
	var buried_index := buried_cells[0].y * field_width + buried_cells[0].x
	var buried_position := prototype.territory_field.cell_to_local(
		Vector2(buried_cells[0])
	)
	prototype.territory_field.queue_seed_growth(buried_position, 3.0, 0.0, 1.0, 2.0)
	prototype.territory_field._apply_pending_commands()
	SmokeFixtures.step_field(prototype.territory_field, 6)
	var buried_strength := prototype.territory_field.get_bramble_strength_at_local(
		buried_position,
		contact_band
	)
	report.check(
		prototype.territory_field._player_frontier_mask[buried_index] == 0
		and is_equal_approx(buried_strength, 0.0)
		and is_equal_approx(
			prototype.territory_field.get_bramble_coverage_at_local(buried_position),
			1.0
		),
		"ground the frontier moves off keeps its Bramble and only loses the hedge bonus"
	)

	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	var mature_start_cells := SmokeFixtures.find_player_frontier_cells(prototype.territory_field, 2)
	var mature_start_index := mature_start_cells[0].y * field_width + mature_start_cells[0].x
	var bare_index := mature_start_cells[1].y * field_width + mature_start_cells[1].x
	prototype.territory_field._maturity[mature_start_index] = 1.0
	prototype.territory_field._maturity[bare_index] = 0.0
	prototype.territory_field._bramble_development[mature_start_index] = 0.0
	prototype.territory_field._bramble_development[bare_index] = 0.0
	prototype.territory_field.step_simulation()
	report.check(
		prototype.territory_field._bramble_development[mature_start_index]
		>= field_tuning.bramble_mature_starting_development
		and prototype.territory_field._bramble_development[bare_index]
		< field_tuning.bramble_mature_starting_development,
		"newly exposed Mature Green starts with thorns while fresh ground starts bare"
	)

	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.territory_field.debug_establish_bramble()
	var tough_position := SmokeFixtures.find_player_frontier(prototype.territory_field)
	var tough_cell := prototype.territory_field.local_to_cell(tough_position)
	var tough_index := (
		int(round(tough_cell.y)) * field_width + int(round(tough_cell.x))
	)
	var developed_control_before: float = prototype.territory_field._control[tough_index]
	prototype.territory_field.queue_erosion(tough_position, 0.45, 0.5)
	prototype.territory_field._apply_pending_commands()
	var developed_control_loss := (
		developed_control_before - prototype.territory_field._control[tough_index]
	)
	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	var fresh_control_before: float = prototype.territory_field._control[tough_index]
	prototype.territory_field.queue_erosion(tough_position, 0.45, 0.5)
	prototype.territory_field._apply_pending_commands()
	var fresh_control_loss := (
		fresh_control_before - prototype.territory_field._control[tough_index]
	)
	report.check(
		fresh_control_loss > 0.0
		and developed_control_loss > 0.0
		and developed_control_loss < fresh_control_loss,
		"Grazers chew Fresh ground quickly but slow down against established thorns"
	)

	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	SmokeFixtures.step_field(prototype.territory_field, 4)
	var rebuilt_frontier := SmokeFixtures.maximum_frontier_development(prototype.territory_field)
	report.check(
		rebuilt_frontier > 0.0,
		"a frontier that has just moved grows a fresh hedge without any stored memory"
	)

	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.territory_field.debug_establish_bramble()
	var harvest_position := SmokeFixtures.find_player_frontier(prototype.territory_field)
	var far_cells := SmokeFixtures.find_player_frontier_cells(prototype.territory_field, 1)
	var far_index := far_cells[0].y * field_width + far_cells[0].x
	var distant_index := SmokeFixtures.find_distant_frontier_index(
		prototype.territory_field,
		harvest_position,
		260.0
	)
	var distant_before := 0.0
	if distant_index >= 0:
		distant_before = prototype.territory_field._bramble_development[distant_index]
	var harvest := prototype.territory_field.harvest_bramble_in_radius(
		harvest_position,
		110.0
	)
	var harvested_cell_cleared := is_equal_approx(
		prototype.territory_field._bramble_development[far_index],
		0.0
	)
	var distant_after := 0.0
	if distant_index >= 0:
		distant_after = prototype.territory_field._bramble_development[distant_index]
	report.check(
		harvest.amount > 0.0
		and harvest.cell_count > 0
		and harvested_cell_cleared
		and distant_index >= 0
		and is_equal_approx(distant_before, distant_after),
		"harvesting consumes thorns only inside its own radius and never elsewhere"
	)


	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.territory_field.debug_establish_bramble()
	prototype.combat.set_bramble_modifiers(true, 0.0)
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	var single_tick_frontier := SmokeFixtures.find_player_frontier(prototype.territory_field)
	var single_tick_enemy := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.BOSS,
		single_tick_frontier
	)
	# Already inside the hedge, so only the repeating tick is measured.
	single_tick_enemy.was_on_bramble = true
	var single_tick_health_before := single_tick_enemy.health
	prototype.combat.simulate_step(0.0)
	var single_tick_damage := single_tick_health_before - single_tick_enemy.health
	var single_tick_expected := prototype.combat.get_bramble_tick_damage(
		single_tick_enemy,
		1.0
	)
	report.check(
		is_equal_approx(single_tick_damage, single_tick_expected),
		"thorn damage resolves once per enemy from local strength instead of stacking per Green cell"
	)

	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	var crossing_enemy := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.BOSS,
		single_tick_frontier
	)
	var crossing_health_before := crossing_enemy.health
	prototype.combat.simulate_step(0.0)
	var first_crossing_damage := crossing_health_before - crossing_enemy.health
	var repeat_crossing_before := crossing_enemy.health
	for _crossing_attempt in range(4):
		crossing_enemy.position = single_tick_frontier
		crossing_enemy.was_on_bramble = false
		crossing_enemy.bramble_damage_remaining = 999.0
		prototype.combat.simulate_step(0.0)
	var repeat_crossing_damage := repeat_crossing_before - crossing_enemy.health
	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	var fresh_crossing_enemy := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.BOSS,
		SmokeFixtures.find_player_frontier(prototype.territory_field)
	)
	var fresh_crossing_health := fresh_crossing_enemy.health
	prototype.combat.simulate_step(0.0)
	var fresh_crossing_damage := fresh_crossing_health - fresh_crossing_enemy.health
	report.check(
		first_crossing_damage > single_tick_expected
		and is_equal_approx(repeat_crossing_damage, 0.0)
		and fresh_crossing_damage < first_crossing_damage,
		"the hedge crossing hit needs established thorns and respects a per-enemy cooldown"
	)

	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.territory_field.debug_establish_bramble()
	prototype.combat.set_bramble_modifiers(true, 0.0)
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	var thorn_frontier := SmokeFixtures.find_player_frontier(prototype.territory_field)
	prototype.combat.set_enemy_scaling(1.0, 1.0)
	var small_enemy := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.HUNTER,
		thorn_frontier
	)
	var large_enemy := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.BOSS,
		thorn_frontier
	)
	var small_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	var large_tick := prototype.combat.get_bramble_tick_damage(large_enemy, 1.0)
	report.check(
		small_enemy != null
		and large_enemy != null
		and large_enemy.maximum_health > small_enemy.maximum_health
		and small_tick > prototype.combat.bramble_contact_damage
		and large_tick > small_tick
		and is_equal_approx(
			large_tick - small_tick,
			(large_enemy.maximum_health - small_enemy.maximum_health)
			* prototype.combat.bramble_max_health_damage_fraction
		),
		"thorn ticks add a maximum-health component so thorns keep scaling into late-game health pools"
	)

	var bramble_lines_are_control_shaped := true
	for bramble_line in [
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT,
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT_RATE,
		Progression.UpgradeId.BRAMBLE_GRASPING_THORNS,
		Progression.UpgradeId.BRAMBLE_REPULSION,
	]:
		bramble_lines_are_control_shaped = (
			bramble_lines_are_control_shaped
			and prototype.progression._get_upgrade_path(bramble_line)
			== Progression.PathId.BRAMBLE
		)
	var thorn_damage_tick_before := prototype.combat.get_bramble_tick_damage(
		small_enemy,
		1.0
	)
	for bramble_line in [
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT,
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT_RATE,
		Progression.UpgradeId.BRAMBLE_GRASPING_THORNS,
		Progression.UpgradeId.BRAMBLE_REPULSION,
	]:
		prototype.progression._upgrade_levels[bramble_line] = (
			prototype.progression.maximum_upgrade_level
		)
	prototype._apply_progression_modifiers()
	var thorn_damage_tick_after := prototype.combat.get_bramble_tick_damage(
		small_enemy,
		1.0
	)
	for bramble_line in [
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT,
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT_RATE,
		Progression.UpgradeId.BRAMBLE_GRASPING_THORNS,
		Progression.UpgradeId.BRAMBLE_REPULSION,
	]:
		prototype.progression._upgrade_levels[bramble_line] = 0
	prototype._apply_progression_modifiers()
	prototype.combat.set_bramble_modifiers(true, 0.0)
	report.check(
		bramble_lines_are_control_shaped
		and is_equal_approx(thorn_damage_tick_after, thorn_damage_tick_before),
		"every Bramble line is crowd control: maxing all four leaves thorn damage flat"
	)

	var fresh_contact_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	small_enemy.entanglement = 0.5
	var half_entangled_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	small_enemy.entanglement = 1.0
	var fully_entangled_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	small_enemy.entanglement = 0.0
	report.check(
		half_entangled_tick > fresh_contact_tick
		and fully_entangled_tick > half_entangled_tick
		and is_equal_approx(
			fully_entangled_tick,
			fresh_contact_tick * prototype.combat.bramble_entangled_damage_multiplier
		),
		"Entanglement ramps thorn damage from a modest first touch to an authored maximum"
	)

	# Exercise the real Root path gate without disturbing the primary-only run this
	# longer scenario is about. Temporarily filling the unused support slot makes
	# RootDirector see a genuinely held Root path, then the exact state is restored.
	var unrooted_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	small_enemy.bramble_ground_maturity = 1.0
	var fresh_ground_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	var previous_tertiary_path := prototype.progression.tertiary_path
	prototype.progression.tertiary_path = Progression.PathId.ROOT
	var mature_ground_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	small_enemy.bramble_ground_maturity = 0.0
	var root_network_fresh_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	prototype.progression.tertiary_path = previous_tertiary_path
	report.check(
		is_equal_approx(fresh_ground_tick, unrooted_tick)
		and mature_ground_tick > fresh_ground_tick
		and is_equal_approx(root_network_fresh_tick, unrooted_tick),
		"the Root Network sharpens thorns on Mature ground and only for a run holding Root"
	)

	var isolated_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	small_enemy.bramble_horde_count = 2
	var crowded_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	small_enemy.bramble_horde_count = 500
	var capped_horde_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	small_enemy.bramble_horde_count = 0
	report.check(
		crowded_tick > isolated_tick
		and capped_horde_tick > crowded_tick
		and is_equal_approx(
			capped_horde_tick,
			isolated_tick * (1.0 + prototype.combat.bramble_horde_damage_maximum_bonus)
		),
		"local horde pressure strengthens a besieged Bramble section within a fixed cap"
	)

	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	var shared_enemies: Array[EnemyState] = []
	var shared_health_before := PackedFloat32Array()
	for _shared_index in range(4):
		var shared_enemy := SmokeFixtures.spawn_bramble_contact_enemy(
			prototype,
			EnemyKinds.Role.HUNTER,
			thorn_frontier
		)
		shared_enemy.was_on_bramble = true
		shared_enemies.append(shared_enemy)
		shared_health_before.append(shared_enemy.health)
	prototype.combat.simulate_step(0.0)
	var shared_expected_tick := prototype.combat.get_bramble_tick_damage(
		shared_enemies[0],
		1.0
	)
	var undivided_damage := true
	for shared_index in range(shared_enemies.size()):
		var shared_damage := (
			shared_health_before[shared_index] - shared_enemies[shared_index].health
		)
		undivided_damage = (
			undivided_damage
			and is_equal_approx(shared_damage, shared_expected_tick)
		)
	report.check(
		shared_enemies.size() == 4
		and shared_expected_tick > isolated_tick
		and undivided_damage,
		"every enemy on one stretch of Green takes its own full thorn tick, never a divided share"
	)

	prototype._apply_progression_modifiers()

	# The pairing closes the same way it opened: a second uncommitted line is
	# drafted, and taking it freezes the run's Evolution.
	SmokeFixtures.acquire_adaptation(prototype, Progression.PathId.SPORE)
	report.check(
		prototype.progression.secondary_path == Progression.PathId.SPORE
		and prototype.progression.primary_path == Progression.PathId.BRAMBLE
		and prototype.progression.get_pair_evolution_id()
		== Progression.EvolutionId.BRIAR_PODS,
		"acquiring the second Core locks the run pairing and its Evolution"
	)

	prototype.progression._upgrade_offer_cursor = (
		Progression.UpgradeId.BLOOM_FORCE
	)
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var locked_draft_options := prototype.progression.get_pending_upgrade_options()
	var locked_draft_is_filtered := not locked_draft_options.is_empty()
	for option_id in locked_draft_options:
		var locked_path := prototype.progression._get_upgrade_path(option_id)
		locked_draft_is_filtered = (
			locked_draft_is_filtered
			and (
				locked_path == Progression.UNSELECTED_PATH
				or prototype.progression.has_path(locked_path)
			)
		)
	report.check(
		locked_draft_is_filtered
		and not locked_draft_options.has(Progression.UpgradeId.BLOOM_FORCE),
		"a run holding both paths narrows its drafts back to the committed lines"
	)
	prototype._choose_displayed_option(0)

	prototype.progression.debug_complete_evolution_requirements()
	var briar_ready := prototype.progression.grant_evolution_if_ready()
	prototype.combat.reset_combat()
	var briar_center := Vector2(330.0, 360.0)
	prototype.spore_director.on_seed_germinated(briar_center, 0)
	report.check(
		briar_ready
		and prototype.progression.active_evolution
		== Progression.EvolutionId.BRIAR_PODS
		and prototype.combat.get_active_briar_pod_count() == 1,
		"Spore plus Bramble evolves into Briar Pods that raise temporary thorn perimeters"
	)
	prototype.combat._cane_remaining = 999.0
	var briar_ring_position := (
		briar_center + Vector2(prototype.evolutions.briar_pod_radius_pixels, 0.0)
	)
	var briar_enemy := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.BOSS,
		briar_ring_position
	)
	var briar_enemy_health_before := briar_enemy.health
	for _briar_step in range(20):
		briar_enemy.position = briar_ring_position
		prototype.combat.simulate_step(0.1)
	report.check(
		briar_enemy.health < briar_enemy_health_before
		and briar_enemy.entanglement > 0.0
		and briar_enemy.movement_speed_multiplier < 1.0,
		"a Briar Pod's visible perimeter applies amplified Bramble damage and slow"
	)
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	var briar_wall_center := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.475,
		prototype.territory_field.tuning.arena_size.y * 0.20
	)
	var briar_wall_shadow := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.56,
		prototype.territory_field.tuning.arena_size.y * 0.20
	)
	prototype.combat.spawn_briar_pod(
		briar_wall_center,
		briar_wall_center.distance_to(briar_wall_shadow),
		prototype.evolutions.briar_pod_duration_seconds,
		prototype.evolutions.briar_pod_contact_multiplier
	)
	var briar_shadow_enemy_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.ELITE,
		briar_wall_shadow
	)
	var briar_shadow_health_before := prototype.combat.get_enemy_health(briar_shadow_enemy_id)
	prototype.combat.simulate_step(0.0)
	report.check(
		is_equal_approx(
			prototype.combat.get_enemy_health(briar_shadow_enemy_id),
			briar_shadow_health_before
		),
		"Briar Pod damage cannot extend through basalt walls"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.progression.debug_select_paths(
		Progression.PathId.BLOOM,
		Progression.PathId.BRAMBLE
	)
	prototype.advance_run(4.10)
	report.check(
		prototype.overlay.get_active_bloom_count() == 1,
		"the Bloom path automatically plants a visible windup near a threat"
	)
	prototype.progression.debug_complete_evolution_requirements()
	var thornburst_ready := prototype.progression.grant_evolution_if_ready()

	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.combat.reset_combat()
	var trap_position := SmokeFixtures.find_deep_owned_position(prototype.territory_field)
	# No frontier hedge is established here: the harvest draws on the Bramble
	# covering the territory, which is what frees Thornburst from frontier geometry.
	prototype.bloom_director.on_bloom_detonated(trap_position, 0)
	var traps_from_harvest := prototype.combat.get_active_briar_trap_count()
	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(false, 1.0)
	prototype.bloom_director.on_bloom_detonated(trap_position, 0)
	var traps_without_bramble := prototype.combat.get_active_briar_trap_count()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	report.check(
		thornburst_ready
		and prototype.progression.active_evolution
		== Progression.EvolutionId.THORNBURST
		and traps_from_harvest > 0
		and traps_without_bramble == 0,
		"Thornburst harvests Bramble-covered territory into a field of Briar Traps"
	)

	# A trap waits for prey, blows once, and lights its neighbours.
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	prototype.combat.spawn_briar_trap(trap_position, 60.0, 12.0, 30.0, 0.30)
	prototype.combat.spawn_briar_trap(
		trap_position + Vector2(70.0, 0.0),
		60.0,
		12.0,
		30.0,
		0.30
	)
	var armed_traps := prototype.combat.get_active_briar_trap_count()
	prototype.combat.simulate_step(0.05)
	var idle_traps := prototype.combat.get_active_briar_trap_count()
	var trap_victim := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.ELITE,
		trap_position
	)
	var trap_victim_health_before := trap_victim.health
	prototype.combat.simulate_step(0.0)
	var trap_damage_dealt := trap_victim_health_before - trap_victim.health
	var trap_entanglement_applied := trap_victim.entanglement
	var traps_after_trigger := prototype.combat.get_active_briar_trap_count()
	prototype.combat.simulate_step(
		prototype.combat.briar_trap_chain_delay_seconds + 0.01
	)
	report.check(
		armed_traps == 2
		and idle_traps == 2
		and traps_after_trigger == 1
		and trap_damage_dealt > 0.0
		and trap_entanglement_applied > 0.0
		and prototype.combat.get_active_briar_trap_count() == 0,
		"a triggered Briar Trap detonates and chains into the traps beside it"
	)

	prototype.combat.reset_combat()
	prototype.combat.spawn_briar_trap(trap_position, 60.0, 1.0, 30.0, 0.30)
	prototype.combat.simulate_step(1.10)
	report.check(
		prototype.combat.get_active_briar_trap_count() == 0,
		"an untriggered Briar Trap rots away instead of filling the arena with mines"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	SmokeFixtures.seed_run_adaptations(
		prototype,
		Progression.PathId.SPORE,
		Progression.PathId.ROOT
	)
	var offered_level := prototype.progression.current_level
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	report.check(
		prototype.choice_panel.visible
		and prototype.territory_field.simulation_paused
		and prototype.progression.has_pending_upgrade_choice(),
		"level-up pauses the living field and presents a three-choice upgrade offer"
	)
	var selected_upgrade := prototype.progression.get_pending_upgrade_options()[0]
	prototype._choose_displayed_option(0)
	report.check(
		prototype.progression.current_level == offered_level + 1
		and prototype.progression.get_upgrade_level(selected_upgrade) == 1
		and not prototype.choice_panel.visible,
		"choosing an upgrade commits a growth line and resumes play"
	)

	prototype.progression.reset_progression()
	prototype.progression.acquire_adaptation(Progression.PathId.THISTLE)
	var final_level_upgrade := Progression.UpgradeId.THISTLE_CLUSTERING
	prototype.progression._upgrade_levels[final_level_upgrade] = (
		prototype.progression.maximum_upgrade_level - 1
	)
	# Thistle is the run's only Adaptation and its other three lines are mastered, so
	# the line under test is the only ordinary candidate the screen can draw.
	for other_line in prototype.progression.get_adaptation_line_ids(
		Progression.PathId.THISTLE
	):
		if other_line != final_level_upgrade:
			prototype.progression._upgrade_levels[other_line] = (
				prototype.progression.get_upgrade_maximum_level(other_line)
			)
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var final_level_offer_index := prototype.progression.get_pending_upgrade_options().find(
		final_level_upgrade
	)
	report.check(
		final_level_offer_index >= 0
		and prototype.choice_panel.buttons[final_level_offer_index].text.contains("LEVEL 2 → 3")
		and not prototype.choice_panel.buttons[final_level_offer_index].text.contains("3/3"),
		"a final-rank draft says level 2 to 3 instead of presenting itself as already 3/3"
	)
	prototype._choose_displayed_option(final_level_offer_index)
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var post_max_options := prototype.progression.get_pending_upgrade_options()
	var post_max_options_are_valid := not post_max_options.has(final_level_upgrade)
	for option_id in post_max_options:
		post_max_options_are_valid = (
			post_max_options_are_valid
			and prototype.progression.get_upgrade_level(option_id)
			< prototype.progression.maximum_upgrade_level
		)
	report.check(
		post_max_options_are_valid,
		"an upgrade at level 5 is excluded from every subsequent draft option"
	)
	prototype._choose_displayed_option(0)

	# Rate zones and the Living Rampart. Nothing in the suite covered either until
	# they were lifted out of the director into their own rules, and a rule with no
	# check behind it is one that can be moved wrongly without anything saying so.
	prototype.combat.reset_combat()
	prototype.combat.clear_rampart()
	var zone_home := SmokeFixtures.find_owned_cell_with_clearance(prototype, 90.0)
	var zone_far := zone_home + Vector2(220.0, 0.0)
	prototype.combat.add_entanglement_rate_zone(zone_home, 40.0, 0.50, 4.0)
	report.check(
		is_equal_approx(
			prototype.combat._get_entanglement_rate_zone_bonus(zone_home), 0.50
		)
		and is_equal_approx(
			prototype.combat._get_entanglement_rate_zone_bonus(zone_far), 0.0
		)
		and prototype.combat.get_active_entanglement_rate_zone_count() == 1,
		"a rate zone raises the rate under it and leaves the ground beyond it alone"
	)

	# A Fruit trail stamps a patch every few pixels, so equal patches close together
	# have to become one rather than hundreds. Patches that are not equal overlap
	# instead, and the strongest wins: adding them would make a doubled-back trail
	# worth several times a straight one for no reason a player could see.
	prototype.combat.add_entanglement_rate_zone(
		zone_home + Vector2(6.0, 0.0), 40.0, 0.50, 4.0
	)
	var merged_count := prototype.combat.get_active_entanglement_rate_zone_count()
	prototype.combat.add_entanglement_rate_zone(zone_home, 40.0, 0.80, 4.0)
	report.check(
		merged_count == 1
		and prototype.combat.get_active_entanglement_rate_zone_count() == 2
		and is_equal_approx(
			prototype.combat._get_entanglement_rate_zone_bonus(zone_home), 0.80
		),
		"equal rate zones merge and overlapping ones take the strongest, not the sum"
	)

	# The patches run on a clock; a Rampart does not. It is read beside them because
	# it raises the same rate, but it stands until the relic takes it down, which is
	# why it is not simply a patch with a very long duration.
	prototype.combat.set_rampart(zone_home, 60.0, 0.30, 0.25)
	for _zone_frame in range(300):
		prototype.combat.simulate_step(1.0 / 30.0)
	report.check(
		prototype.combat.get_active_entanglement_rate_zone_count() == 0
		and prototype.combat.is_in_rampart(zone_home)
		and not prototype.combat.is_in_rampart(zone_far)
		and is_equal_approx(
			prototype.combat._get_entanglement_rate_zone_bonus(zone_home), 0.30
		),
		"timed rate zones expire on their own clock and the standing Rampart outlives them"
	)

	# Two sets of patches, one rule. Stamping Spore ground must not put anything on
	# the Entanglement ground, which is the one thing sharing an implementation
	# could quietly break.
	prototype.combat.clear_rampart()
	prototype.combat.add_spore_rate_zone(zone_home, 40.0, 0.50, 4.0)
	report.check(
		prototype.combat.get_active_spore_rate_zone_count() == 1
		and prototype.combat.get_active_entanglement_rate_zone_count() == 0
		and is_equal_approx(
			prototype.combat._get_spore_rate_zone_bonus(zone_home), 0.50
		)
		and is_equal_approx(
			prototype.combat._get_entanglement_rate_zone_bonus(zone_home), 0.0
		),
		"Spore patches and Entanglement patches are two separate sets of ground"
	)

	# The Rampart's other half, which is not a rate at all: inside one, the Green is
	# allowed to shove again far sooner than it is anywhere else.
	SmokeFixtures.thorn_all_owned_ground(prototype)
	prototype.combat.reset_combat()
	var shoved_in_rampart := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.GRAZER,
		zone_home
	)
	prototype.combat.repel_territory_attacker(shoved_in_rampart)
	var open_ground_cooldown := shoved_in_rampart.bramble_repulsion_remaining
	shoved_in_rampart.bramble_repulsion_remaining = 0.0
	prototype.combat.set_rampart(zone_home, 60.0, 0.30, 0.25)
	prototype.combat.repel_territory_attacker(shoved_in_rampart)
	var rampart_cooldown := shoved_in_rampart.bramble_repulsion_remaining
	prototype.combat.clear_rampart()
	report.check(
		open_ground_cooldown > 0.0
		and rampart_cooldown > 0.0
		and rampart_cooldown < open_ground_cooldown,
		"the Green inside a Rampart may shove again sooner than the Green outside it"
			+ " (%.2fs against %.2fs)" % [rampart_cooldown, open_ground_cooldown]
	)
