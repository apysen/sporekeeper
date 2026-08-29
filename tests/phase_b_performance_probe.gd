extends SceneTree

const TARGET_FRAME_MS := 16.67


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
	prototype._set_simulation_paused(true)
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.BRAMBLE,
		PhaseBProgression.PathId.SPORE
	)
	# A relic engine is exactly the kind of layer that quietly eats a frame, so
	# the stress case holds every relic that does per-frame or per-enemy work:
	# the crowd-density scan, the Seed proximity check, and the Entanglement
	# sweep, plus the standing world objects that redraw every frame.
	for stressed_relic in [
		PhaseBRelicCatalog.Id.GREEN_THUMB,
		PhaseBRelicCatalog.Id.LIVING_RAMPART,
		PhaseBRelicCatalog.Id.THE_HEDGE,
		PhaseBRelicCatalog.Id.SNARE_VINE,
		PhaseBRelicCatalog.Id.TAPROOT,
		PhaseBRelicCatalog.Id.ANNUAL_RINGS,
		PhaseBRelicCatalog.Id.WORLD_TREE,
	]:
		prototype.progression._owned_relics[stressed_relic] = 1
	prototype._apply_progression_modifiers()
	prototype.relic_director.apply_relics()
	prototype.combat.reset_combat()
	for pod_index in range(prototype.combat.briar_pod_pool_size):
		prototype.combat.spawn_briar_pod(
			Vector2(
				150.0 + float(pod_index % 4) * 210.0,
				120.0 + float(pod_index / 4) * 170.0
			),
			prototype.evolutions.briar_pod_radius_pixels,
			prototype.evolutions.briar_pod_duration_seconds,
			prototype.evolutions.briar_pod_contact_multiplier
		)
	prototype.combat.debug_fill_stress(
		prototype.combat.maximum_active_enemies,
		prototype.combat.projectile_pool_size,
		prototype.combat.pickup_pool_size
	)
	prototype.player.global_position = prototype.territory_field.to_global(Vector2(180.0, 270.0))
	# Prime the shared route field without consuming any pooled stress entities.
	prototype.combat.simulate_step(0.0)

	var sample_frames := 120
	var started_at := Time.get_ticks_usec()
	var peak_frame_ms := 0.0
	var peak_frame_index := -1
	for frame_index in range(sample_frames):
		if frame_index % 24 == 0:
			var navigation_x := 180.0 + float((frame_index / 24) % 5) * 145.0
			prototype.player.global_position = prototype.territory_field.to_global(
				Vector2(navigation_x, 270.0)
			)
		var frame_started_at := Time.get_ticks_usec()
		prototype.combat.simulate_step(1.0 / 120.0)
		prototype.relic_director.advance(1.0 / 120.0)
		if frame_index % 4 == 0:
			prototype.territory_field.step_simulation()
		elif frame_index % 4 == 2:
			prototype.territory_field.refresh_visuals_now()
		var frame_ms := float(Time.get_ticks_usec() - frame_started_at) / 1000.0
		if frame_ms > peak_frame_ms:
			peak_frame_ms = frame_ms
			peak_frame_index = frame_index
	var elapsed_ms := float(Time.get_ticks_usec() - started_at) / 1000.0
	var average_frame_ms := elapsed_ms / float(sample_frames)
	var within_pool_cap := (
		prototype.combat.get_active_enemy_count()
		<= prototype.combat.maximum_active_enemies
	)
	var within_budget := average_frame_ms <= TARGET_FRAME_MS and peak_frame_ms <= TARGET_FRAME_MS

	print(
		(
			"PHASE_B_PERFORMANCE: stress_avg=%.3fms peak=%.3fms@%d active_enemies=%d "
			+ "projectiles=%d pickups=%d relics=%d target=%.2fms"
		) % [
			average_frame_ms,
			peak_frame_ms,
			peak_frame_index,
			prototype.combat.get_active_enemy_count(),
			prototype.combat.get_active_projectile_count(),
			prototype.combat.get_active_pickup_count(),
			prototype.progression.get_owned_relic_names().size(),
			TARGET_FRAME_MS,
		]
	)

	prototype.queue_free()
	await process_frame
	if within_pool_cap and within_budget:
		print("PHASE_B_PERFORMANCE: PASS")
		quit(0)
	else:
		push_error("PHASE_B_PERFORMANCE: pool cap or frame budget exceeded")
		quit(1)
