extends SceneTree

## What a Fruit release costs as the count climbs.
##
## The peak-density sweep found Root+Fruit spiking to a 40ms combat frame while
## every other Fruit pairing sat near 4ms. The suspicion is the count itself: a
## normal release is 1 + Fruit Set, Root Potency adds its owned ranks on mature
## ground, and a Clover jackpot on Fruit lends the whole line ceiling on top. This
## walks those three states and reports the count actually released beside the
## combat cost, so the relationship is measured rather than assumed.

const SAMPLE_FRAMES := 300
const STEP := 1.0 / 60.0
const TARGET_FRAME_MS := 16.67

## The exact relic load the peak-density sweep gives a Root+Fruit run.
const PLANT_RELICS: Array[int] = [
	PhaseBRelicCatalog.Id.GARDEN_HOSE,
	PhaseBRelicCatalog.Id.MULCH,
	PhaseBRelicCatalog.Id.MIMOSA,
	PhaseBRelicCatalog.Id.COMPOST_HEAP,
	PhaseBRelicCatalog.Id.MAN_EATER,
]
const ROOT_RELICS: Array[int] = [
	PhaseBRelicCatalog.Id.ROOTBOUND,
	PhaseBRelicCatalog.Id.SUCKERS,
	PhaseBRelicCatalog.Id.FEEDER_ROOTS,
	PhaseBRelicCatalog.Id.TAPROOT,
	PhaseBRelicCatalog.Id.GRAFT_UNION,
]
const FRUIT_RELICS: Array[int] = [
	PhaseBRelicCatalog.Id.THICK_RIND,
	PhaseBRelicCatalog.Id.STEM_STEERING,
	PhaseBRelicCatalog.Id.BRUISED_FRUIT,
	PhaseBRelicCatalog.Id.BANK_SHOT,
]
const STRESS_ROLES: Array[int] = [
	PhaseBCombatDirector.EnemyRole.HUNTER,
	PhaseBCombatDirector.EnemyRole.GRAZER,
	PhaseBCombatDirector.EnemyRole.HEAVY_GRAZER,
	PhaseBCombatDirector.EnemyRole.RUSHER,
	PhaseBCombatDirector.EnemyRole.SABOTEUR,
	PhaseBCombatDirector.EnemyRole.CORRUPTOR,
	PhaseBCombatDirector.EnemyRole.COLONIZER,
	PhaseBCombatDirector.EnemyRole.WARDEN,
	PhaseBCombatDirector.EnemyRole.SIEGE_CORRUPTOR,
]

var _rows: Array[String] = []
var _bisect_rows: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	var load_error := change_scene_to_file("res://scenes/run/phase_b_prototype.tscn")
	if load_error != OK:
		push_error("Unable to load Phase B prototype: %s" % error_string(load_error))
		quit(1)
		return
	await process_frame
	await process_frame
	var prototype := current_scene as PhaseBPrototype
	if prototype == null:
		push_error("Phase B prototype scene did not become current")
		quit(1)
		return
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.combat.set_process(false)
	prototype.adaptation_director.set_process(false)
	prototype.overlay.set_process(false)
	prototype.player.maximum_health = 1000000000.0
	prototype.player.reset_player()

	await _run_case(prototype, "fruit alone", false, false, false)
	await _run_case(prototype, "+ root, young", true, false, false)
	await _run_case(prototype, "+ root, mature", true, true, false)
	await _run_case(prototype, "+ clover jackpot", true, true, true)

	# The count is only half the question. The sweep's Root+Fruit row carried a
	# 14-relic load and the full role mix, and that is the row that spiked, so the
	# relics are bisected here by pool against the same crowd.
	var root_fruit := [PhaseBProgression.PathId.ROOT, PhaseBProgression.PathId.FRUIT]
	var root_spore := [PhaseBProgression.PathId.ROOT, PhaseBProgression.PathId.SPORE]
	var fruit_spore := [PhaseBProgression.PathId.FRUIT, PhaseBProgression.PathId.SPORE]
	await _run_bisect(prototype, "root+fruit, no relic", root_fruit, [], true)
	await _run_bisect(prototype, "root+fruit, all 14", root_fruit, PLANT_RELICS + ROOT_RELICS + FRUIT_RELICS, true)
	await _run_bisect(prototype, "root+fruit, no evo", root_fruit, [], false)
	await _run_bisect(prototype, "root+spore", root_spore, [], true)
	await _run_bisect(prototype, "fruit+spore", fruit_spore, [], true)

	print(
		"FRUIT_SCALING %-18s %6s %6s | %9s %9s %9s" % [
			"case", "count", "peak", "median", "p95", "p99"
		]
	)
	for row in _rows:
		print(row)
	print("")
	print(
		"FRUIT_BISECT  %-22s %6s %6s | %9s %9s %9s" % [
			"case", "count", "peak", "median", "p95", "p99"
		]
	)
	for row in _bisect_rows:
		print(row)
	prototype.queue_free()
	await process_frame
	print("FRUIT_SCALING: done")
	quit(0)


func _run_case(
	prototype: PhaseBPrototype,
	label: String,
	with_root: bool,
	mature_ground: bool,
	casino: bool
) -> void:
	prototype.reset_run()
	prototype.progression.reset_progression()
	prototype.progression.clear_casino_paths()
	var support := (
		PhaseBProgression.PathId.ROOT
		if with_root
		else PhaseBProgression.PathId.SPORE
	)
	prototype.progression.debug_select_paths(PhaseBProgression.PathId.FRUIT, support)
	for upgrade_id in range(PhaseBProgression.UpgradeId.size()):
		var path_id := prototype.progression._get_upgrade_path(upgrade_id)
		if prototype.progression.has_path(path_id):
			prototype.progression._upgrade_levels[upgrade_id] = (
				prototype.progression.maximum_upgrade_level
			)
	if casino:
		prototype.progression.set_casino_path_active(
			PhaseBProgression.PathId.FRUIT,
			true
		)
	prototype._apply_progression_modifiers()
	prototype.relic_director.apply_relics()

	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()

	var origin := Vector2(320.0, 300.0)
	prototype.player.global_position = prototype.territory_field.to_global(origin)
	if mature_ground:
		_force_mature_ground(prototype.territory_field, origin, 90.0)

	for index in range(prototype.combat.maximum_active_enemies):
		var ring := 30.0 + float(index % 7) * 22.0
		prototype.combat.spawn_enemy(
			PhaseBCombatDirector.EnemyRole.HUNTER,
			origin + Vector2.from_angle(float(index) * 2.39996) * ring
		)
	for enemy in prototype.combat._enemies:
		if not enemy.active:
			continue
		enemy.maximum_health = 1000000000.0
		enemy.health = enemy.maximum_health
	prototype.combat.simulate_step(0.0)

	# What one release will actually put on the field, read the same way the
	# release itself reads it.
	var released := (
		1
		+ prototype.progression.get_upgrade_level(PhaseBProgression.UpgradeId.FRUIT_SET)
		+ prototype.adaptation_director._root_count_step(
			PhaseBProgression.UpgradeId.FRUIT_SET,
			origin
		)
	)

	var combat := PackedFloat32Array()
	var peak_fruit := 0
	for _frame_index in range(SAMPLE_FRAMES):
		var began := Time.get_ticks_usec()
		prototype.combat.simulate_step(STEP)
		combat.append(float(Time.get_ticks_usec() - began) / 1000.0)
		prototype.adaptation_director.advance(STEP)
		peak_fruit = maxi(peak_fruit, prototype.adaptation_director.get_active_fruit_count())

	var sorted := combat.duplicate()
	sorted.sort()
	_rows.append(
		"FRUIT_SCALING %-18s %6d %6d | %7.3fms %7.3fms %7.3fms" % [
			label,
			released,
			peak_fruit,
			_percentile(sorted, 0.50),
			_percentile(sorted, 0.95),
			_percentile(sorted, 0.99),
		]
	)
	await process_frame


func _run_bisect(
	prototype: PhaseBPrototype,
	label: String,
	paths: Array,
	relics: Array[int],
	with_evolution: bool
) -> void:
	prototype.reset_run()
	prototype.progression.reset_progression()
	prototype.progression.clear_casino_paths()
	prototype.progression.debug_select_paths(paths[0], paths[1])
	if with_evolution:
		prototype.progression.debug_complete_evolution_requirements()
		prototype.progression.grant_evolution_if_ready()
		prototype.progression.debug_select_tertiary_path(_third_path(paths))
	for upgrade_id in range(PhaseBProgression.UpgradeId.size()):
		var path_id := prototype.progression._get_upgrade_path(upgrade_id)
		if prototype.progression.has_path(path_id):
			prototype.progression._upgrade_levels[upgrade_id] = (
				prototype.progression.maximum_upgrade_level
			)
	for relic_id in relics:
		prototype.progression._owned_relics[relic_id] = 1
	prototype._apply_progression_modifiers()
	prototype.relic_director.apply_relics()

	prototype.wave_director.configure_mode(PhaseBRunMode.Id.CAMPAIGN)
	prototype.wave_director.reset_director()
	prototype.wave_director.debug_advance_time(
		prototype.wave_director.final_invasion_time_seconds
	)
	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	prototype.combat.debug_fill_stress(
		0,
		prototype.combat.projectile_pool_size,
		prototype.combat.pickup_pool_size
	)

	var origin := Vector2(320.0, 300.0)
	prototype.player.global_position = prototype.territory_field.to_global(origin)
	for index in range(prototype.combat.maximum_active_enemies):
		var ring := 30.0 + float(index % 7) * 22.0
		prototype.combat.spawn_enemy(
			STRESS_ROLES[index % STRESS_ROLES.size()],
			origin + Vector2.from_angle(float(index) * 2.39996) * ring
		)
	for enemy in prototype.combat._enemies:
		if not enemy.active:
			continue
		enemy.maximum_health = 1000000000.0
		enemy.health = enemy.maximum_health
	prototype.combat.simulate_step(0.0)

	var released := (
		1
		+ prototype.progression.get_upgrade_level(PhaseBProgression.UpgradeId.FRUIT_SET)
		+ prototype.adaptation_director._root_count_step(
			PhaseBProgression.UpgradeId.FRUIT_SET,
			origin
		)
	)
	var combat := PackedFloat32Array()
	var peak_fruit := 0
	var worst_ms := 0.0
	var worst_overgrown := 0
	var peak_overgrown := 0
	# A Saboteur's catalyst flow field is rebuilt whenever the nearest catalyst
	# lands in a different navigation cell. Sampling the target index beside the
	# frame cost separates "this build is heavy" from "this build keeps moving the
	# target the flood fill is built around".
	var last_catalyst_index := prototype.combat._navigation_catalyst_target_index
	var retarget_frames := 0
	var retarget_ms := 0.0
	var steady_ms := 0.0
	for frame_index in range(SAMPLE_FRAMES):
		prototype.advance_run(STEP)
		var began := Time.get_ticks_usec()
		prototype.combat.simulate_step(STEP)
		var frame_ms := float(Time.get_ticks_usec() - began) / 1000.0
		combat.append(frame_ms)
		if frame_ms > worst_ms:
			worst_ms = frame_ms
			worst_overgrown = _count_overgrown(prototype)
		var catalyst_index := prototype.combat._navigation_catalyst_target_index
		if catalyst_index != last_catalyst_index:
			last_catalyst_index = catalyst_index
			retarget_frames += 1
			retarget_ms += frame_ms
		else:
			steady_ms += frame_ms
		prototype.relic_director.advance(STEP)
		prototype.adaptation_director.advance(STEP)
		prototype.overlay._process(STEP)
		if frame_index % 4 == 0:
			prototype.territory_field.step_simulation()
		peak_fruit = maxi(peak_fruit, prototype.adaptation_director.get_active_fruit_count())
		peak_overgrown = maxi(peak_overgrown, _count_overgrown(prototype))
	var spike_frames := PackedInt32Array()
	var spike_fruit := PackedInt32Array()
	for index in range(combat.size()):
		if combat[index] > 12.0:
			spike_frames.append(index)
	print(
		(
			"FRUIT_SPIKES  %-22s spikes=%2d peak_overgrown=%3d on_worst_frame=%3d at=%s"
		) % [
			label,
			spike_frames.size(),
			peak_overgrown,
			worst_overgrown,
			str(spike_frames).substr(0, 90),
		]
	)
	var steady_frames := SAMPLE_FRAMES - retarget_frames
	print(
		"FRUIT_RETARGET %-22s retargets=%3d avg_on_retarget=%7.3fms avg_steady=%7.3fms" % [
			label,
			retarget_frames,
			retarget_ms / float(maxi(1, retarget_frames)),
			steady_ms / float(maxi(1, steady_frames)),
		]
	)

	var sorted := combat.duplicate()
	sorted.sort()
	_bisect_rows.append(
		"FRUIT_BISECT  %-22s %6d %6d | %7.3fms %7.3fms %7.3fms" % [
			label,
			released,
			peak_fruit,
			_percentile(sorted, 0.50),
			_percentile(sorted, 0.95),
			_percentile(sorted, 0.99),
		]
	)
	await process_frame


func _count_overgrown(prototype: PhaseBPrototype) -> int:
	var count := 0
	for enemy in prototype.combat._enemies:
		if enemy.active and enemy.overgrown:
			count += 1
	return count


func _third_path(paths: Array) -> int:
	for path_id in range(PhaseBProgression.PathId.size()):
		if path_id != paths[0] and path_id != paths[1]:
			return path_id
	return PhaseBProgression.PathId.SPORE


func _force_mature_ground(field: TerritoryField, origin: Vector2, radius: float) -> void:
	# Root Potency only pays out on fully mature owned ground, which a freshly reset
	# field does not have anywhere. Written straight into the field rather than
	# simulated, because the probe is about the Fruit count and not about how long
	# maturing takes.
	var step: float = field.tuning.arena_size.x / float(field._width)
	var samples := int(radius / maxf(1.0, step)) + 1
	for y in range(-samples, samples + 1):
		for x in range(-samples, samples + 1):
			var offset := Vector2(float(x) * step, float(y) * step)
			if offset.length() > radius:
				continue
			var point := origin + offset
			if not field.contains_local_point(point):
				continue
			var index := field._index_at_local(point)
			field._claimable_mask[index] = 1
			field._control[index] = 1.0
			field._maturity[index] = 1.0


func _percentile(sorted_values: PackedFloat32Array, fraction: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := clampi(
		ceili(clampf(fraction, 0.0, 1.0) * float(sorted_values.size())) - 1,
		0,
		sorted_values.size() - 1
	)
	return sorted_values[index]
