extends SceneTree

## What one frame costs at the densest the game ever gets, for every pairing.
##
## The other probes each hold one variable still: the performance probe fills the
## enemy pool but drafts a light build, the wave probe runs real frames on three
## paths, and the relic fixtures crowd 100 enemies around one pool at a time. This
## one stacks all of it -- the concurrent enemy cap at the worst role mix, both
## other pools full, an evolved three-path build with every line maxed, and a full
## 14-relic load -- and then sweeps all 28 Adaptation pairings through it.
##
## Every pairing reports the same row, split by subsystem, because "the frame is
## too long" is not actionable and "Thistle's thorn update is 13ms of it" is. A
## pairing is over budget on p99 rather than on peak: one slow frame in six hundred
## is a hitch, but a p99 above the budget is a build that does not hold 60fps.

## Frames sampled per pairing. Long enough for the second-scale cadences (thorn
## volleys, Fruit releases, Bloom charges) to fire many times over.
const SAMPLE_FRAMES := 600
const STEP := 1.0 / 60.0
const TARGET_FRAME_MS := 16.67

## The roles are cycled rather than sampled, so the crowd always contains the
## expensive ones. Warden and Siege Corruptor matter most: they are excluded from
## the baked enemy art and always draw in full detail.
const STRESS_ROLES := [
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

## Fourteen relics -- the top of the document's 10-14 per run -- drawn from the
## pools the pairing actually owns, so every scenario carries a legal build rather
## than one the drafting rules would never assemble.
const PLANT_RELIC_COUNT := 5
const PRIMARY_RELIC_COUNT := 5
const SECONDARY_RELIC_COUNT := 4

var _rows: Array[String] = []
var _over_budget: Array[String] = []


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

	# The fixture owns the clock. Every system below is driven by hand exactly as a
	# real frame drives it, so the per-subsystem split is a real split rather than
	# whatever order _process happened to run in.
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.combat.set_process(false)
	prototype.adaptation_director.set_process(false)
	prototype.overlay.set_process(false)
	prototype.player.maximum_health = 1000000000.0
	prototype.player.reset_player()

	print(
		"PEAK_DENSITY: sweeping every pairing at the enemy cap, %d frames each"
		% SAMPLE_FRAMES
	)
	for first_path in range(PhaseBProgression.PathId.size()):
		for second_path in range(first_path + 1, PhaseBProgression.PathId.size()):
			await _run_pairing(prototype, first_path, second_path)

	print("")
	print(
		"PEAK_DENSITY %-17s %9s %9s %9s %6s | %8s %8s %8s" % [
			"pairing", "median", "p95", "p99", "over", "combat", "terrain", "adapt"
		]
	)
	for row in _rows:
		print(row)

	prototype.queue_free()
	await process_frame
	if _over_budget.is_empty():
		print("PEAK_DENSITY: PASS (every pairing holds p99 within %.2fms)" % TARGET_FRAME_MS)
		quit(0)
		return
	print("")
	print("PEAK_DENSITY: over budget -> %s" % ", ".join(_over_budget))
	push_error(
		"PEAK_DENSITY: %d of 28 pairings exceed the %.2fms p99 budget at peak density"
		% [_over_budget.size(), TARGET_FRAME_MS]
	)
	quit(1)


func _run_pairing(prototype: PhaseBPrototype, first_path: int, second_path: int) -> void:
	prototype.reset_run()
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(first_path, second_path)
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	prototype.progression.debug_select_tertiary_path(
		_support_path_for(first_path, second_path)
	)
	# Every line of every owned Path maxed, so the build is the worst case of
	# itself rather than an average one that happens to hold the relics.
	for upgrade_id in range(PhaseBProgression.UpgradeId.size()):
		var path_id := prototype.progression._get_upgrade_path(upgrade_id)
		if prototype.progression.has_path(path_id):
			prototype.progression._upgrade_levels[upgrade_id] = (
				prototype.progression.maximum_upgrade_level
			)
	for relic_id in _relics_for(first_path, second_path):
		prototype.progression._owned_relics[relic_id] = 1
	prototype._apply_progression_modifiers()
	prototype.relic_director.apply_relics()

	# Campaign, at the end of the timeline: the spawn scaling every enemy below is
	# built with is the late-run one rather than the opening one.
	prototype.wave_director.configure_mode(PhaseBRunMode.Id.CAMPAIGN)
	prototype.wave_director.reset_director()
	prototype.wave_director.debug_advance_time(
		prototype.wave_director.final_invasion_time_seconds
	)

	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	# Projectile and pickup pools full, no enemies from the helper: the crowd below
	# is built by hand so it can carry the expensive roles.
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
	# Unkillable, so the crowd stays at the cap for the whole sample instead of
	# thinning into an easier frame halfway through.
	for enemy in prototype.combat._enemies:
		if not enemy.active:
			continue
		enemy.maximum_health = 1000000000.0
		enemy.health = enemy.maximum_health
	var holds_vine := (
		first_path == PhaseBProgression.PathId.VINE
		or second_path == PhaseBProgression.PathId.VINE
	)
	if holds_vine and prototype.combat.vine_whip != null:
		prototype.combat.vine_whip.build(origin, prototype.combat.get_cane_reach())
	prototype.combat.simulate_step(0.0)

	var combat := PackedFloat32Array()
	var relics := PackedFloat32Array()
	var adaptation := PackedFloat32Array()
	var overlay := PackedFloat32Array()
	var territory := PackedFloat32Array()
	var total := PackedFloat32Array()

	for frame_index in range(SAMPLE_FRAMES):
		var frame_began := Time.get_ticks_usec()

		var began := Time.get_ticks_usec()
		prototype.advance_run(STEP)
		var run_ms := _since(began)

		began = Time.get_ticks_usec()
		prototype.combat.simulate_step(STEP)
		combat.append(_since(began))

		began = Time.get_ticks_usec()
		prototype.relic_director.advance(STEP)
		relics.append(_since(began) + run_ms)

		began = Time.get_ticks_usec()
		prototype.adaptation_director.advance(STEP)
		adaptation.append(_since(began))

		began = Time.get_ticks_usec()
		prototype.overlay._process(STEP)
		overlay.append(_since(began))

		began = Time.get_ticks_usec()
		if frame_index % 4 == 0:
			prototype.territory_field.step_simulation()
		elif frame_index % 4 == 2:
			prototype.territory_field.refresh_visuals_now()
		territory.append(_since(began))

		total.append(_since(frame_began))

	var label := "%s+%s" % [
		PhaseBProgression.get_path_name(first_path),
		PhaseBProgression.get_path_name(second_path),
	]
	var total_sorted := total.duplicate()
	total_sorted.sort()
	var p99 := _percentile(total_sorted, 0.99)
	# The count of frames actually over the budget matters more than any one
	# percentile here: a build whose p95 is comfortable and whose p99 is double the
	# budget is spiking on a cadence, not running heavy, and those are different bugs.
	var over_count := 0
	for frame_ms in total:
		if frame_ms > TARGET_FRAME_MS:
			over_count += 1
	_rows.append(
		"PEAK_DENSITY %-17s %7.3fms %7.3fms %7.3fms %4d/%d | %6.3fms %6.3fms %6.3fms" % [
			label,
			_percentile(total_sorted, 0.50),
			_percentile(total_sorted, 0.95),
			p99,
			over_count,
			SAMPLE_FRAMES,
			_p99(combat),
			_p99(territory),
			_p99(adaptation),
		]
	)
	if p99 > TARGET_FRAME_MS:
		_over_budget.append("%s (%.1fms)" % [label, p99])
	await process_frame


func _support_path_for(first_path: int, second_path: int) -> int:
	# The evolved run's third Path. Deterministic rather than chosen, so a pairing
	# measures the same build every time it is run.
	for path_id in range(PhaseBProgression.PathId.size()):
		if path_id != first_path and path_id != second_path:
			return path_id
	return PhaseBProgression.PathId.SPORE


func _relics_for(first_path: int, second_path: int) -> Array[int]:
	var chosen: Array[int] = []
	_append_pool_relics(chosen, PhaseBRelicCatalog.Pool.PLANT, PLANT_RELIC_COUNT)
	_append_pool_relics(chosen, _pool_for_path(first_path), PRIMARY_RELIC_COUNT)
	_append_pool_relics(chosen, _pool_for_path(second_path), SECONDARY_RELIC_COUNT)
	return chosen


func _append_pool_relics(chosen: Array[int], pool: int, wanted: int) -> void:
	var taken := 0
	for relic_id in range(PhaseBRelicCatalog.get_count()):
		if taken >= wanted:
			return
		if PhaseBRelicCatalog.get_pool(relic_id) != pool:
			continue
		chosen.append(relic_id)
		taken += 1


func _pool_for_path(path_id: int) -> int:
	match path_id:
		PhaseBProgression.PathId.SPORE:
			return PhaseBRelicCatalog.Pool.SPORE
		PhaseBProgression.PathId.BLOOM:
			return PhaseBRelicCatalog.Pool.BLOOM
		PhaseBProgression.PathId.BRAMBLE:
			return PhaseBRelicCatalog.Pool.BRAMBLE
		PhaseBProgression.PathId.ROOT:
			return PhaseBRelicCatalog.Pool.ROOT
		PhaseBProgression.PathId.PRUNING:
			return PhaseBRelicCatalog.Pool.PRUNING
		PhaseBProgression.PathId.THISTLE:
			return PhaseBRelicCatalog.Pool.THISTLE
		PhaseBProgression.PathId.VINE:
			return PhaseBRelicCatalog.Pool.VINE
		PhaseBProgression.PathId.FRUIT:
			return PhaseBRelicCatalog.Pool.FRUIT
	return PhaseBRelicCatalog.Pool.PLANT


func _since(began_usec: int) -> float:
	return float(Time.get_ticks_usec() - began_usec) / 1000.0


func _average(samples: PackedFloat32Array) -> float:
	var total := 0.0
	for value in samples:
		total += value
	return total / float(maxi(1, samples.size()))


func _p99(samples: PackedFloat32Array) -> float:
	var sorted := samples.duplicate()
	sorted.sort()
	return _percentile(sorted, 0.99)


func _percentile(sorted_values: PackedFloat32Array, fraction: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := clampi(
		ceili(clampf(fraction, 0.0, 1.0) * float(sorted_values.size())) - 1,
		0,
		sorted_values.size() - 1
	)
	return sorted_values[index]
