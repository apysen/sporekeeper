extends SceneTree

const TARGET_FRAME_MS := 16.67
const WAVE_SAMPLE_FRAMES := 180
const WARMUP_FRAMES := 45


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
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

	_prepare_stress_run(prototype)
	var all_within_budget := true
	for wave_number in [10, 11, 12]:
		_prepare_wave(prototype, wave_number)
		for _warmup in range(WARMUP_FRAMES):
			await process_frame
		var frame_times: Array[float] = []
		var draw_calls_total := 0.0
		for _sample in range(WAVE_SAMPLE_FRAMES):
			var frame_started_at := Time.get_ticks_usec()
			await process_frame
			frame_times.append(float(Time.get_ticks_usec() - frame_started_at) / 1000.0)
			draw_calls_total += Performance.get_monitor(
				Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME
			)
		frame_times.sort()
		var average_ms := 0.0
		for frame_ms in frame_times:
			average_ms += frame_ms
		average_ms /= float(frame_times.size())
		var p95_ms := _percentile(frame_times, 0.95)
		var p99_ms := _percentile(frame_times, 0.99)
		var peak_ms := frame_times[frame_times.size() - 1]
		var average_draw_calls := draw_calls_total / float(frame_times.size())
		var wave_within_budget := p99_ms <= TARGET_FRAME_MS
		all_within_budget = all_within_budget and wave_within_budget
		print(
			(
				"WAVE_STRESS: wave=%d avg=%.3fms p95=%.3fms p99=%.3fms peak=%.3fms "
				+ "enemies=%d pickups=%d draw_calls=%.1f target=%.2fms"
			) % [
				wave_number,
				average_ms,
				p95_ms,
				p99_ms,
				peak_ms,
				prototype.combat.get_active_enemy_count(),
				prototype.combat.get_active_pickup_count(),
				average_draw_calls,
				TARGET_FRAME_MS,
			]
		)

	prototype.queue_free()
	await process_frame
	if all_within_budget:
		print("WAVE_STRESS: PASS")
		quit(0)
	else:
		push_error("WAVE_STRESS: p99 frame budget exceeded")
		quit(1)


func _prepare_stress_run(prototype: RunRoot) -> void:
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.player.maximum_health = 1000000000.0
	prototype.player.reset_player()
	prototype.progression.debug_select_paths(
		Progression.PathId.SPORE,
		Progression.PathId.ROOT
	)
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	prototype.progression.debug_select_tertiary_path(Progression.PathId.BRAMBLE)
	prototype._apply_progression_modifiers()
	prototype.combat.reset_combat()
	prototype.combat.debug_fill_stress(
		prototype.combat.maximum_active_enemies,
		prototype.combat.projectile_pool_size,
		prototype.combat.pickup_pool_size
	)
	for enemy in prototype.combat._enemies:
		if not enemy.active:
			continue
		enemy.maximum_health = 1000000000.0
		enemy.health = enemy.maximum_health
	prototype.wave_director.reset_director()
	prototype._set_simulation_paused(false)
	prototype.set_process(true)


func _prepare_wave(prototype: RunRoot, wave_number: int) -> void:
	var target_seconds := (
		float(wave_number - 1) * prototype.wave_director.wave_duration_seconds
		+ prototype.wave_director.wave_grace_period_seconds
		+ 1.0
	)
	prototype.wave_director.debug_advance_time(
		maxf(0.0, target_seconds - prototype.wave_director.elapsed_seconds)
	)


func _percentile(sorted_values: Array[float], fraction: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := clampi(
		ceili(clampf(fraction, 0.0, 1.0) * float(sorted_values.size())) - 1,
		0,
		sorted_values.size() - 1
	)
	return sorted_values[index]
