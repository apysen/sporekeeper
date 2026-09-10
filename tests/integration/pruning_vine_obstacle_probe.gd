extends SceneTree

const RIDGE_LEFT := Vector2(310.0, 70.0)
const RIDGE_RIGHT := Vector2(650.0, 70.0)

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

	_test_growth_route(prototype)
	_test_cutting_stops_at_ridge(prototype)
	_test_vine_wraps_around_ridge(prototype)

	prototype.queue_free()
	await process_frame
	if _failures == 0:
		print("PRUNING_VINE_OBSTACLE_PROBE: PASS")
		quit(0)
	else:
		push_error("PRUNING_VINE_OBSTACLE_PROBE: %d failure(s)" % _failures)
		quit(1)


func _test_growth_route(prototype: RunRoot) -> void:
	var field := prototype.territory_field
	var route := field.get_growth_path(RIDGE_LEFT, RIDGE_RIGHT)
	_check(
		not field.is_growth_path_clear(RIDGE_LEFT, RIDGE_RIGHT),
		"the ridge fixture is directly obstructed"
	)
	_check(route.size() > 2, "the route bends around the ridge")
	var every_segment_clear := route.size() > 1
	for index in range(1, route.size()):
		every_segment_clear = (
			every_segment_clear
			and field.is_growth_path_clear(route[index - 1], route[index])
		)
	_check(every_segment_clear, "every wrapped route segment stays outside basalt")
	_check(
		field.get_growth_path_length(route) > RIDGE_LEFT.distance_to(RIDGE_RIGHT),
		"wrapping consumes more attack length than a straight line"
	)


func _test_cutting_stops_at_ridge(prototype: RunRoot) -> void:
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 9999.0
	var enemy_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.BOSS,
		RIDGE_RIGHT
	)
	var health_before := prototype.combat.get_enemy_health(enemy_id)
	var cutting := prototype.pruning_director._cuttings[0]
	cutting.state = PruningDirector.CuttingState.LAUNCHED
	cutting.position = RIDGE_LEFT
	cutting.velocity = RIDGE_LEFT.direction_to(RIDGE_RIGHT) * RIDGE_LEFT.distance_to(RIDGE_RIGHT)
	cutting.remaining = 2.0
	cutting.damage = 9999.0
	cutting.pierce_remaining = 1
	cutting.last_hit_enemy_id = -1
	prototype.pruning_director._advance_launched_cutting(cutting, 1.0)
	_check(
		cutting.state == PruningDirector.CuttingState.INACTIVE,
		"a Cutting is spent when its frame segment reaches the ridge"
	)
	_check(
		is_equal_approx(prototype.combat.get_enemy_health(enemy_id), health_before),
		"a Cutting cannot damage an enemy through the ridge"
	)


func _test_vine_wraps_around_ridge(prototype: RunRoot) -> void:
	prototype.combat.reset_combat()
	prototype.player.global_position = prototype.territory_field.to_global(RIDGE_LEFT)
	prototype.combat._cane_remaining = 9999.0
	var enemy_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.BOSS,
		RIDGE_RIGHT
	)
	var route := prototype.territory_field.get_growth_path(RIDGE_LEFT, RIDGE_RIGHT)
	var route_length := prototype.territory_field.get_growth_path_length(route)
	prototype.combat._cane_auto_targets = false
	prototype.combat.cane_reach_pixels = route_length + 1.0
	var health_before := prototype.combat.get_enemy_health(enemy_id)
	prototype.combat._perform_cane_sweep(Vector2.RIGHT, true, 1.0, 1.0, true)
	_check(
		is_equal_approx(prototype.combat.get_enemy_health(enemy_id), health_before),
		"the ordinary Cane remains blocked by the ridge"
	)

	prototype.combat._cane_auto_targets = true
	prototype.combat.cane_reach_pixels = maxf(
		RIDGE_LEFT.distance_to(RIDGE_RIGHT),
		route_length - prototype.combat.get_enemy_radius(enemy_id) - 2.0
	)
	prototype.combat._perform_cane_sweep(Vector2.RIGHT, true, 1.0, 1.0, true)
	_check(
		is_equal_approx(prototype.combat.get_enemy_health(enemy_id), health_before),
		"Vine cannot reach around the ridge when the wrapped route exceeds its length"
	)

	prototype.combat.cane_reach_pixels = route_length + 1.0
	prototype.combat._perform_cane_sweep(Vector2.RIGHT, true, 1.0, 1.0, true)
	_check(
		prototype.combat.get_enemy_health(enemy_id) < health_before,
		"Vine reaches and damages an enemy around the ridge"
	)
	_check(
		prototype.combat._cane_visual_path.size() > 2,
		"the visible Vine uses the same bent route as the hit"
	)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		push_error("FAIL: %s" % description)
