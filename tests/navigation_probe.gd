extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_error := change_scene_to_file("res://scenes/run/run.tscn")
	if load_error != OK:
		push_error("Unable to load Sporekeeper run: %s" % error_string(load_error))
		quit(1)
		return
	await process_frame
	await process_frame
	var prototype := current_scene as RunRoot
	if prototype == null:
		push_error("Sporekeeper run scene did not become current")
		quit(1)
		return
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype._set_simulation_paused(true)

	_run_navigation_fixture(
		prototype,
		"upper ridge",
		Vector2(310.0, 70.0),
		Vector2(650.0, 70.0),
		18.0,
		CombatDirector.EnemyRole.HUNTER,
		21.5
	)
	_run_navigation_fixture(
		prototype,
		"upper island",
		Vector2(245.0, 128.0),
		Vector2(430.0, 128.0),
		12.0,
		CombatDirector.EnemyRole.HUNTER,
		21.5
	)
	_run_navigation_fixture(
		prototype,
		"lower island",
		Vector2(505.0, 455.0),
		Vector2(705.0, 455.0),
		12.0,
		CombatDirector.EnemyRole.GRAZER,
		23.5
	)
	_run_navigation_fixture(
		prototype,
		"upper ridge corner",
		Vector2(430.0, 265.0),
		Vector2(545.0, 185.0),
		12.0,
		CombatDirector.EnemyRole.ELITE,
		28.5
	)
	_run_navigation_fixture(
		prototype,
		"lower ridge corner",
		Vector2(430.0, 295.0),
		Vector2(545.0, 370.0),
		12.0,
		CombatDirector.EnemyRole.HUNTER,
		21.5
	)
	_run_navigation_fixture(
		prototype,
		"Corruptor at lower ridge",
		Vector2(430.0, 295.0),
		Vector2(545.0, 370.0),
		15.0,
		CombatDirector.EnemyRole.CORRUPTOR,
		24.5
	)
	_run_navigation_fixture(
		prototype,
		"Warden at upper ridge",
		Vector2(250.0, 70.0),
		Vector2(650.0, 70.0),
		24.0,
		CombatDirector.EnemyRole.WARDEN,
		26.0
	)
	_run_navigation_fixture(
		prototype,
		"boss at upper ridge",
		Vector2(310.0, 70.0),
		Vector2(650.0, 70.0),
		30.0,
		CombatDirector.EnemyRole.BOSS,
		40.5
	)
	_run_saboteur_catalyst_fixture(prototype)
	_run_colonizer_spacing_fixture(prototype)
	_run_navigation_fixture(
		prototype,
		"boss at lower island",
		Vector2(505.0, 455.0),
		Vector2(705.0, 455.0),
		18.0,
		CombatDirector.EnemyRole.BOSS,
		40.5
	)

	prototype.queue_free()
	await process_frame
	if _failures == 0:
		print("NAVIGATION_PROBE: PASS")
		quit(0)
	else:
		push_error("NAVIGATION_PROBE: %d failure(s)" % _failures)
		quit(1)


func _run_navigation_fixture(
	prototype: RunRoot,
	fixture_name: String,
	target: Vector2,
	start: Vector2,
	maximum_seconds: float,
	role: int,
	contact_distance: float
) -> void:
	prototype.player.reset_player()
	prototype.player.global_position = prototype.territory_field.to_global(target)
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	var enemy_id := prototype.combat.spawn_enemy(
		role,
		start
	)
	var reached_target := false
	var longest_stall := 0.0
	var current_stall := 0.0
	var previous_position := prototype.combat.get_enemy_position(enemy_id)
	var step_count := int(ceil(maximum_seconds * 60.0))
	for _step_index in range(step_count):
		prototype.combat.simulate_step(1.0 / 60.0)
		var position := prototype.combat.get_enemy_position(enemy_id)
		if position.distance_to(target) <= contact_distance:
			reached_target = true
			break
		if position.distance_squared_to(previous_position) <= 0.01:
			current_stall += 1.0 / 60.0
			longest_stall = maxf(longest_stall, current_stall)
		else:
			current_stall = 0.0
		previous_position = position
	var final_position := prototype.combat.get_enemy_position(enemy_id)
	_check(
		reached_target and longest_stall < 0.75,
		"%s routes around its obstacle without a corner stall (remaining %.1f, stall %.2fs)"
		% [fixture_name, final_position.distance_to(target), longest_stall]
	)


func _run_saboteur_catalyst_fixture(prototype: RunRoot) -> void:
	var catalyst_target := Vector2(310.0, 70.0)
	var start := Vector2(650.0, 70.0)
	prototype.player.reset_player()
	prototype.player.global_position = prototype.territory_field.to_global(Vector2(850.0, 450.0))
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	prototype.combat._cane_remaining = 999.0
	prototype.overlay.spawn_seed(catalyst_target, 60.0, 0, 1.0)
	var enemy_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.SABOTEUR,
		start
	)
	var maximum_y := start.y
	var longest_stall := 0.0
	var current_stall := 0.0
	var previous_position := prototype.combat.get_enemy_position(enemy_id)
	for _step_index in range(18 * 60):
		prototype.combat.simulate_step(1.0 / 60.0)
		var position := prototype.combat.get_enemy_position(enemy_id)
		maximum_y = maxf(maximum_y, position.y)
		if position.distance_squared_to(previous_position) <= 0.01:
			current_stall += 1.0 / 60.0
			longest_stall = maxf(longest_stall, current_stall)
		else:
			current_stall = 0.0
			previous_position = position
		if prototype.overlay.get_active_seed_count() == 0:
			break
	_check(
		prototype.overlay.get_active_seed_count() == 0
		and maximum_y > 205.0
		and longest_stall < 0.75,
		(
			"Saboteur paths around basalt to destroy a hidden Seed "
			+ "(max_y %.1f, stall %.2fs)"
		) % [maximum_y, longest_stall]
	)


func _run_colonizer_spacing_fixture(prototype: RunRoot) -> void:
	var target := Vector2(150.0, 70.0)
	var start := Vector2(650.0, 70.0)
	prototype.player.reset_player()
	prototype.player.global_position = prototype.territory_field.to_global(target)
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	prototype.combat._cane_remaining = 999.0
	var enemy_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.COLONIZER,
		start
	)
	var maximum_y := start.y
	var longest_stall := 0.0
	var current_stall := 0.0
	var previous_position := prototype.combat.get_enemy_position(enemy_id)
	for _step_index in range(24 * 60):
		prototype.combat.simulate_step(1.0 / 60.0)
		var position := prototype.combat.get_enemy_position(enemy_id)
		maximum_y = maxf(maximum_y, position.y)
		if position.distance_squared_to(previous_position) <= 0.01:
			current_stall += 1.0 / 60.0
			longest_stall = maxf(longest_stall, current_stall)
		else:
			current_stall = 0.0
			previous_position = position
		if (
			maximum_y > 205.0
			and position.distance_to(target)
			<= prototype.combat.colonizer_profile.preferred_distance_pixels * 1.15
		):
			break
	var final_position := prototype.combat.get_enemy_position(enemy_id)
	_check(
		maximum_y > 205.0
		and final_position.distance_to(target)
		<= prototype.combat.colonizer_profile.preferred_distance_pixels * 1.15
		and longest_stall < 0.75,
		(
			"Colonizer routes around basalt before holding its preferred range "
			+ "(max_y %.1f, range %.1f, stall %.2fs)"
		) % [maximum_y, final_position.distance_to(target), longest_stall]
	)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		push_error("FAIL: %s" % description)
