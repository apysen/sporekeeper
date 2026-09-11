## What each role does that no other role does: the Saboteur hunting a charging
## Seed, the Corruptor turning Green hostile, the Warden suppressing maturity, and
## the navigation that gets any of them there.
##
## The arena's basalt is doing as much work as the enemies in this block - a role
## that walks around a wall and a targeting rule that refuses to shoot through one
## are the same fact seen from two sides.
class_name SmokeEnemyRoles
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	prototype.combat.reset_combat()
	var outside_range_position := (
		prototype.player.get_arena_position()
		+ Vector2(prototype.combat.cane_reach_pixels + 150.0, 0.0)
	)
	var outside_range_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		outside_range_position
	)
	prototype.combat.simulate_step(0.20)
	report.check(
		outside_range_id != -1
		and prototype.combat.is_enemy_active(outside_range_id)
		and prototype.combat.get_active_projectile_count() == 0,
		"Cane still sweeps without damaging an enemy beyond its authored reach"
	)

	prototype.combat.reset_combat()
	var cane_wall_source := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.475,
		prototype.territory_field.tuning.arena_size.y * 0.20
	)
	var cane_blocked_target := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.56,
		prototype.territory_field.tuning.arena_size.y * 0.20
	)
	var cane_visible_target := Vector2(
		cane_wall_source.x,
		prototype.territory_field.tuning.arena_size.y * 0.51
	)
	prototype.player.global_position = prototype.territory_field.to_global(cane_wall_source)
	var blocked_target_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		cane_blocked_target
	)
	var visible_target_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		cane_visible_target
	)
	var dense_visible_direction := prototype.combat.get_densest_target_direction(
		cane_wall_source,
		500.0,
		45.0,
		Vector2.RIGHT
	)
	report.check(
		not prototype.territory_field.is_growth_path_clear(
			cane_wall_source,
			cane_blocked_target
		)
		and prototype.territory_field.is_growth_path_clear(
			cane_wall_source,
			cane_visible_target
		)
		and cane_wall_source.distance_to(cane_blocked_target)
		< cane_wall_source.distance_to(cane_visible_target)
		and absf(dense_visible_direction.angle_to(
			cane_wall_source.direction_to(cane_visible_target)
		)) < 0.001,
		"dense-sector targeting ignores a closer enemy behind basalt"
	)
	prototype.combat.perform_bonus_cane_sweep(Vector2.RIGHT, true)
	var visible_reach_scale := (
		cane_wall_source.distance_to(cane_visible_target)
		/ prototype.combat.get_cane_reach()
		+ 0.1
	)
	prototype.combat.perform_bonus_cane_sweep(
		cane_wall_source.direction_to(cane_visible_target),
		false,
		1.0,
		visible_reach_scale
	)
	# Each body is measured against its own maximum, never against the authored
	# profile. By this point in the run the wave curve is live, so a Hunter spawns
	# with 28.64 health where the profile says 28.0 - and an untouched enemy compared
	# against the profile reads as damaged, which is the opposite of what is meant.
	report.check(
		prototype.combat.get_enemy_health(visible_target_id)
		< prototype.combat.get_enemy_maximum_health(visible_target_id)
		and is_equal_approx(
			prototype.combat.get_enemy_health(blocked_target_id),
			prototype.combat.get_enemy_maximum_health(blocked_target_id)
		),
		"Cane sectors damage an unobstructed enemy but never pass through basalt"
	)

	prototype.player.reset_player()
	prototype.combat.reset_combat()
	var sweep_origin := prototype.player.get_arena_position()
	var upper_enemy_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		sweep_origin + Vector2(58.0, -18.0)
	)
	var lower_enemy_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		sweep_origin + Vector2(68.0, 20.0)
	)
	var beyond_reach_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		sweep_origin + Vector2(prototype.combat.cane_reach_pixels + 80.0, 0.0)
	)
	var sector_hits := prototype.combat.perform_bonus_cane_sweep(Vector2.RIGHT, true)
	report.check(
		sector_hits == 2
		and prototype.combat.get_enemy_health(upper_enemy_id)
		< prototype.combat.get_enemy_maximum_health(upper_enemy_id)
		and prototype.combat.get_enemy_health(lower_enemy_id)
		< prototype.combat.get_enemy_maximum_health(lower_enemy_id)
		and is_equal_approx(
			prototype.combat.get_enemy_health(beyond_reach_id),
			prototype.combat.get_enemy_maximum_health(beyond_reach_id)
		)
		and prototype.combat.get_active_projectile_count() == 0,
		"one Cane sector hits every in-reach enemy once and allocates no projectile"
	)

	prototype.combat.reset_combat()
	var navigation_target := Vector2(310.0, 70.0)
	var navigation_start := Vector2(650.0, 70.0)
	prototype.player.global_position = prototype.territory_field.to_global(navigation_target)
	prototype.combat._cane_remaining = 999.0
	var navigating_enemy_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		navigation_start
	)
	var maximum_navigation_y := navigation_start.y
	for _navigation_step in range(900):
		prototype.combat.simulate_step(1.0 / 60.0)
		var navigation_position := prototype.combat.get_enemy_position(navigating_enemy_id)
		if navigation_position.x < -90000.0:
			break
		maximum_navigation_y = maxf(maximum_navigation_y, navigation_position.y)
	var navigation_end := prototype.combat.get_enemy_position(navigating_enemy_id)
	report.check(
		navigation_end.x > -90000.0
		and maximum_navigation_y > 205.0
		and navigation_end.distance_to(navigation_target)
		< navigation_start.distance_to(navigation_target) - 150.0,
		(
			"a Hunter detours through the central opening instead of sticking to the basalt ridge "
			+ "(max_y %.1f, end %.1f/%.1f, remaining %.1f)"
		) % [
			maximum_navigation_y,
			navigation_end.x,
			navigation_end.y,
			navigation_end.distance_to(navigation_target),
		]
	)

	prototype.player.reset_player()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	var catalyst_position := Vector2(700.0, 360.0)
	var original_saboteur_delay := (
		prototype.combat.saboteur_profile.first_territory_action_delay_seconds
	)
	prototype.combat.saboteur_profile.first_territory_action_delay_seconds = 0.0
	prototype.overlay.spawn_seed(catalyst_position, 10.0, 0, 1.0)
	var saboteur_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.SABOTEUR,
		catalyst_position
	)
	prototype.combat.simulate_step(0.0)
	prototype.combat.saboteur_profile.first_territory_action_delay_seconds = (
		original_saboteur_delay
	)
	report.check(
		saboteur_id != -1 and prototype.overlay.get_active_seed_count() == 0,
		"a Saboteur seeks and destroys a vulnerable charging Seed"
	)

	var mature_green_position := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.235,
		prototype.territory_field.tuning.arena_size.y * 0.535
	)
	prototype.territory_field.reset_field()
	prototype.combat.reset_combat()
	var green_before_corruption := (
		prototype.territory_field.get_control_at_local(mature_green_position)
	)
	var original_corruptor_delay := (
		prototype.combat.corruptor_profile.first_territory_action_delay_seconds
	)
	prototype.combat.corruptor_profile.first_territory_action_delay_seconds = 0.0
	var corruptor_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.CORRUPTOR,
		mature_green_position
	)
	prototype.combat.simulate_step(0.0)
	prototype.combat.corruptor_profile.first_territory_action_delay_seconds = (
		original_corruptor_delay
	)
	SmokeFixtures.step_field(prototype.territory_field, 1)
	var green_after_corruption := (
		prototype.territory_field.get_control_at_local(mature_green_position)
	)
	report.check(
		corruptor_id != -1
		and green_before_corruption > prototype.territory_field.tuning.ownership_threshold
		and green_after_corruption < green_before_corruption - 0.20,
		"a Corruptor converts established Green toward hostile material"
	)

	prototype.territory_field.reset_field()
	prototype.combat.reset_combat()
	var original_warden_delay := (
		prototype.combat.warden_profile.first_territory_action_delay_seconds
	)
	prototype.combat.warden_profile.first_territory_action_delay_seconds = 0.0
	var maturity_before_suppression := (
		prototype.territory_field.get_maturity_at_local(mature_green_position)
	)
	var control_before_suppression := (
		prototype.territory_field.get_control_at_local(mature_green_position)
	)
	var warden_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.WARDEN,
		mature_green_position
	)
	prototype.combat.simulate_step(0.0)
	prototype.combat.warden_profile.first_territory_action_delay_seconds = original_warden_delay
	SmokeFixtures.step_field(prototype.territory_field, 1)
	report.check(
		warden_id != -1
		and prototype.territory_field.get_maturity_at_local(mature_green_position)
		< maturity_before_suppression
		and prototype.territory_field.get_control_at_local(mature_green_position)
		> prototype.territory_field.tuning.ownership_threshold
		and control_before_suppression
		> prototype.territory_field.tuning.ownership_threshold,
		"a Warden suppresses maturity without directly erasing Green control"
	)

	prototype.combat.reset_combat()
	var original_colonizer_delay := (
		prototype.combat.colonizer_profile.first_territory_action_delay_seconds
	)
	prototype.combat.colonizer_profile.first_territory_action_delay_seconds = 0.0
	var colonizer_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.COLONIZER,
		Vector2(700.0, 360.0)
	)
	prototype.combat.simulate_step(0.0)
	prototype.combat.colonizer_profile.first_territory_action_delay_seconds = (
		original_colonizer_delay
	)
	report.check(
		colonizer_id != -1
		and prototype.combat.get_active_enemy_count_by_role(
			EnemyKinds.Role.COLONY_CORE
		) == 1,
		"a Colonizer establishes one destructible hostile Colony Core"
	)

	prototype.territory_field.reset_field()
	prototype.combat.reset_combat()
	var green_before_core := prototype.territory_field.get_control_at_local(mature_green_position)
	var original_core_delay := (
		prototype.combat.colony_core_profile.first_territory_action_delay_seconds
	)
	prototype.combat.colony_core_profile.first_territory_action_delay_seconds = 0.0
	var colony_core_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.COLONY_CORE,
		mature_green_position
	)
	prototype.combat.simulate_step(0.0)
	prototype.combat.colony_core_profile.first_territory_action_delay_seconds = original_core_delay
	SmokeFixtures.step_field(prototype.territory_field, 1)
	report.check(
		colony_core_id != -1
		and prototype.combat.get_enemy_position(colony_core_id).is_equal_approx(
			mature_green_position
		)
		and prototype.territory_field.get_control_at_local(mature_green_position)
		< green_before_core,
		"an anchored Colony Core continuously roots hostile territory around itself"
	)
