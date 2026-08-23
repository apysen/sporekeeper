extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var tuning := load("res://data/territory/phase_a_tuning.tres") as TerritoryPrototypeTuning
	_check(tuning != null, "prototype tuning resource loads")
	if tuning == null:
		quit(1)
		return

	var field := await _create_field(tuning)
	_check(
		field.get_player_percent() > 2.0 and field.get_player_percent() < 12.0,
		"fixture begins on a small Green foothold (%.2f%%)" % field.get_player_percent()
	)
	# The foothold opens besieged: hostile ground wraps it on every side, so the run
	# has to convert enemy territory rather than race into open neutral ground.
	var siege_reach := 1.5
	var besieged_on_every_side := true
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var probe := Vector2(
			(
				tuning.starting_plant_center.x
				+ direction.x * tuning.starting_plant_radius.x * siege_reach
			) * tuning.arena_size.x,
			(
				tuning.starting_plant_center.y
				+ direction.y * tuning.starting_plant_radius.y * siege_reach
			) * tuning.arena_size.y
		)
		besieged_on_every_side = (
			besieged_on_every_side
			and field.get_control_at_local(probe) < -tuning.ownership_threshold
		)
	_check(
		tuning.starting_hostile_ring > 0.0 and besieged_on_every_side,
		"hostile ground surrounds the starting foothold on every side"
	)
	_check(field.get_hostile_percent() > 5.0, "fixture begins with meaningful hostile territory")
	_check(field.get_neutral_percent() > 5.0, "fixture begins with meaningful neutral territory")
	_check(
		absf(
			field.get_player_percent()
			+ field.get_hostile_percent()
			+ field.get_neutral_percent()
			- 100.0
		) < 0.01,
		"published territory percentages sum to 100"
	)

	var ridge_point := Vector2(tuning.arena_size.x * 0.505, tuning.arena_size.y * 0.20)
	_check(not field.is_claimable_at_local(ridge_point), "basalt ridge is unclaimable")
	_check(
		not field.is_claimable_at_local(
			Vector2(tuning.arena_size.x * 0.350, tuning.arena_size.y * 0.235)
		)
		and not field.is_claimable_at_local(
			Vector2(tuning.arena_size.x * 0.625, tuning.arena_size.y * 0.845)
		),
		"both basalt islands are unclaimable obstacles"
	)
	var natural_player_before := field.get_player_percent()
	var natural_maturity_before := field.get_maturity_at_local(
		Vector2(tuning.arena_size.x * 0.235, tuning.arena_size.y * 0.535)
	)
	_step(field, 60)
	# A besieged foothold trades ground at its border instead of spreading into open
	# neutral space, so the fixture is checked for holding rather than for growth.
	_check(
		field.get_player_percent() > natural_player_before * 0.70
		and field.get_player_percent() > 1.0,
		"the besieged foothold holds its ground without an ability (%.2f%%)"
			% field.get_player_percent()
	)
	_check(
		field.get_maturity_at_local(Vector2(tuning.arena_size.x * 0.235, tuning.arena_size.y * 0.535))
		> natural_maturity_before,
		"owned territory matures continuously"
	)
	field.reset_field()

	var weak_hostile := Vector2(tuning.arena_size.x * 0.690, tuning.arena_size.y * 0.765)
	var hostile_before := field.get_control_at_local(weak_hostile)
	_check(
		hostile_before < -tuning.ownership_threshold,
		"weak-hostile basin begins visibly hostile (control %.2f)" % hostile_before
	)
	field.queue_bloom(weak_hostile)
	_step(field, 14)
	var isolated_bloom_after := field.get_control_at_local(weak_hostile)
	field.reset_field()
	field.queue_seed_growth(weak_hostile)
	_step(field, 14)
	var isolated_seed_after := field.get_control_at_local(weak_hostile)
	_check(
		isolated_seed_after > isolated_bloom_after + 0.20,
		"a Seed colonises isolated hostile ground where a Bloom alone cannot reach"
	)

	field.reset_field()
	_step(field, 14)
	var natural_percent := field.get_player_percent()
	field.reset_field()
	var frontier_origin := field.find_player_frontier_near(weak_hostile)
	field.queue_bloom(frontier_origin)
	_step(field, 14)
	var frontier_bloom_percent := field.get_player_percent()
	field.reset_field()
	field.queue_bloom(weak_hostile)
	_step(field, 14)
	var unsupported_bloom_percent := field.get_player_percent()
	_check(
		frontier_origin.x >= 0.0
		and frontier_bloom_percent > natural_percent
		and unsupported_bloom_percent <= natural_percent + 0.01,
		"a Bloom surges the existing frontier outward but does nothing detached from Plant"
	)

	# Blooms fire far less often than Seeds, so one burst must claim at least as
	# much ground as one germination does from the same place.
	field.reset_field()
	field.queue_seed_growth(frontier_origin)
	_step(field, 30)
	var seed_from_frontier := field.get_player_percent()
	field.reset_field()
	field.queue_bloom(frontier_origin)
	_step(field, 30)
	var bloom_from_frontier := field.get_player_percent()
	field.reset_field()
	_step(field, 30)
	var settled_natural := field.get_player_percent()
	_check(
		bloom_from_frontier - settled_natural
		>= seed_from_frontier - settled_natural,
		"one Bloom claims at least as much ground as one Seed from the same frontier"
	)

	# The frontier a Bloom actually roots on in play faces the hostile side, so it
	# has to break through contested ground rather than only expand into neutral.
	var hostile_core := Vector2(tuning.arena_size.x * 0.765, tuning.arena_size.y * 0.515)
	var contested_origin := field.find_player_frontier_near(hostile_core)
	var contested_control := field.get_control_at_local(contested_origin)
	field.reset_field()
	field.queue_bloom(contested_origin)
	_step(field, 30)
	var contested_bloom := field.get_player_percent()
	field.reset_field()
	field.queue_seed_growth(contested_origin)
	_step(field, 30)
	var contested_seed := field.get_player_percent()
	_check(
		contested_control > tuning.ownership_threshold,
		"the frontier query returns owned ground rather than the cell beside it"
	)
	_check(
		contested_bloom > contested_seed,
		"a Bloom drives through a contested border harder than a Seed does"
	)

	var wall_source := Vector2(tuning.arena_size.x * 0.475, tuning.arena_size.y * 0.20)
	var wall_shadow := Vector2(tuning.arena_size.x * 0.535, tuning.arena_size.y * 0.20)
	var wall_open_side := Vector2(tuning.arena_size.x * 0.415, tuning.arena_size.y * 0.20)
	_check(
		field.is_claimable_at_local(wall_source)
		and field.is_claimable_at_local(wall_shadow)
		and field.is_claimable_at_local(wall_open_side),
		"wall-occlusion fixture uses claimable source and targets"
	)
	_check(
		field.is_growth_path_clear(wall_source, wall_open_side)
		and not field.is_growth_path_clear(wall_source, wall_shadow),
		"arena-mask visibility exposes open space and blocks the wall shadow"
	)

	field.reset_field()
	# A Bloom displaces Plant that already exists, so the occlusion fixture needs a
	# foothold to surge from before it can show what the wall blocks.
	field.queue_seed_growth(wall_source)
	_step(field, 2)
	var bloom_shadow_before := field.get_control_at_local(wall_shadow)
	var bloom_open_before := field.get_control_at_local(wall_open_side)
	field.queue_bloom(wall_source)
	field.step_simulation()
	var bloom_shadow_delta := field.get_control_at_local(wall_shadow) - bloom_shadow_before
	var bloom_open_delta := field.get_control_at_local(wall_open_side) - bloom_open_before
	var bloom_shadow_pressure := field.get_pressure_at_local(wall_shadow).length()
	_check(bloom_open_delta > 0.05, "Bloom still affects an unobstructed target")
	_check(
		absf(bloom_shadow_delta) < 0.02 and bloom_shadow_pressure < 0.001,
		"wall blocks Bloom mass and pressure (mass %.3f, pressure %.3f)"
		% [bloom_shadow_delta, bloom_shadow_pressure]
	)

	field.reset_field()
	var seed_shadow_before := field.get_control_at_local(wall_shadow)
	var seed_open_before := field.get_control_at_local(wall_open_side)
	field.queue_seed_growth(wall_source)
	field.step_simulation()
	var seed_shadow_delta := field.get_control_at_local(wall_shadow) - seed_shadow_before
	var seed_open_delta := field.get_control_at_local(wall_open_side) - seed_open_before
	var seed_shadow_pressure := field.get_pressure_at_local(wall_shadow).length()
	_check(seed_open_delta > 0.05, "Seed still affects an unobstructed target")
	_check(
		absf(seed_shadow_delta) < 0.02 and seed_shadow_pressure < 0.001,
		"wall blocks Seed mass and pressure (mass %.3f, pressure %.3f)"
		% [seed_shadow_delta, seed_shadow_pressure]
	)

	field.reset_field()
	var corrupt_shadow_before := field.get_control_at_local(wall_shadow)
	var corrupt_open_before := field.get_control_at_local(wall_open_side)
	field.queue_hostile_growth(wall_source, 1.0, 3.0)
	field.step_simulation()
	var corrupt_shadow_delta := (
		field.get_control_at_local(wall_shadow) - corrupt_shadow_before
	)
	var corrupt_open_delta := field.get_control_at_local(wall_open_side) - corrupt_open_before
	_check(corrupt_open_delta < -0.05, "hostile growth converts an unobstructed target")
	_check(
		absf(corrupt_shadow_delta) < 0.02,
		"wall blocks Corruptor and Colony Core hostile growth (mass %.3f)"
		% corrupt_shadow_delta
	)

	field.reset_field()
	field.queue_seed_growth(wall_source)
	field.queue_seed_growth(wall_open_side)
	field.queue_seed_growth(wall_shadow)
	_step(field, 18)
	var suppress_open_before := field.get_maturity_at_local(wall_open_side)
	var suppress_shadow_before := field.get_maturity_at_local(wall_shadow)
	field.queue_maturity_suppression(wall_source, 0.5, 3.0)
	field.step_simulation()
	var suppress_open_after := field.get_maturity_at_local(wall_open_side)
	var suppress_shadow_after := field.get_maturity_at_local(wall_shadow)
	_check(
		suppress_open_before > 0.0 and suppress_open_after < suppress_open_before,
		"Warden suppression reduces maturity in its unobstructed zone"
	)
	_check(
		suppress_shadow_before > 0.0
		and suppress_shadow_after >= suppress_shadow_before - 0.01,
		"wall blocks a Warden suppression zone"
	)

	field.reset_field()
	var open_ground := Vector2(tuning.arena_size.x * 0.16, tuning.arena_size.y * 0.12)
	var open_before := field.get_control_at_local(open_ground)
	field.queue_seed_growth(open_ground)
	_step(field, 18)
	var open_after := field.get_control_at_local(open_ground)
	_check(open_after > open_before + 0.25, "Seed creates dense growth on open neutral ground")

	field.reset_field()
	var hostile_seed_point := Vector2(tuning.arena_size.x * 0.82, tuning.arena_size.y * 0.52)
	var hostile_seed_before := field.get_control_at_local(hostile_seed_point)
	field.queue_seed_growth(hostile_seed_point)
	_step(field, 18)
	var hostile_seed_after := field.get_control_at_local(hostile_seed_point)
	_check(
		hostile_seed_before < -tuning.ownership_threshold
		and hostile_seed_after > tuning.ownership_threshold,
		"Seed establishes Green growth inside strong hostile territory (%.2f -> %.2f)"
		% [hostile_seed_before, hostile_seed_after]
	)

	field.reset_field()
	var mature_core := Vector2(tuning.arena_size.x * 0.235, tuning.arena_size.y * 0.535)
	var maturity := field.get_maturity_at_local(mature_core)
	var core_before := field.get_control_at_local(mature_core)
	field.queue_erosion(mature_core)
	field.step_simulation()
	var core_loss := core_before - field.get_control_at_local(mature_core)
	_check(maturity > 0.45, "fixture includes Mature territory")
	_check(core_loss > 0.0 and core_loss < tuning.grazer_erosion_per_stamp * 0.70, "maturity resists Grazer erosion")

	field.reset_field()
	var initial_regions := field.get_fragment_count()
	var cut_y := tuning.arena_size.y * 0.535
	for cut_x in range(12, 476, 9):
		field.queue_erosion(Vector2(float(cut_x), cut_y))
	field.step_simulation()
	field.analyze_topology_now()
	var split_regions := field.get_fragment_count()
	_check(
		split_regions > initial_regions,
		"a Grazer-width channel splits Green territory (%d -> %d regions)" % [initial_regions, split_regions]
	)

	field.reset_field()
	var mirror := await _create_field(tuning)
	var deterministic_point := Vector2(tuning.arena_size.x * 0.44, tuning.arena_size.y * 0.49)
	field.queue_bloom(deterministic_point)
	mirror.queue_bloom(deterministic_point)
	_step(field, 30)
	_step(mirror, 30)
	field.recalculate_metrics_now()
	mirror.recalculate_metrics_now()
	_check(
		is_equal_approx(field.get_player_percent(), mirror.get_player_percent())
		and is_equal_approx(
			field.get_control_at_local(deterministic_point),
			mirror.get_control_at_local(deterministic_point)
		),
		"identical commands and fixed steps produce identical territory"
	)

	field.queue_free()
	mirror.queue_free()
	await process_frame

	if _failures == 0:
		print("TERRITORY_PROTOTYPE_SMOKE: PASS")
		quit(0)
	else:
		push_error("TERRITORY_PROTOTYPE_SMOKE: %d failure(s)" % _failures)
		quit(1)


func _create_field(tuning: TerritoryPrototypeTuning) -> TerritoryField:
	var field := TerritoryField.new()
	field.tuning = tuning
	field.simulation_paused = true
	root.add_child(field)
	await process_frame
	return field


func _step(field: TerritoryField, count: int) -> void:
	for _index in range(count):
		field.step_simulation()
	field.recalculate_metrics_now()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		push_error("FAIL: %s" % description)
