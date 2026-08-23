extends SceneTree

const TARGET_FRAME_MS := 16.67


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var tuning := load("res://data/territory/phase_a_tuning.tres") as TerritoryPrototypeTuning
	var field := TerritoryField.new()
	field.tuning = tuning
	root.add_child(field)
	await process_frame
	field.simulation_paused = true

	for warmup_index in range(20):
		if warmup_index % 10 == 0:
			field.queue_bloom(Vector2(480.0 + warmup_index, 270.0))
		field.step_simulation()
	field.refresh_visuals_now()

	var simulation_steps := 180
	var simulation_started := Time.get_ticks_usec()
	for step_index in range(simulation_steps):
		if step_index % 30 == 0:
			field.queue_bloom(Vector2(340.0 + float(step_index % 90), 270.0))
		field.step_simulation()
	var simulation_ms := float(Time.get_ticks_usec() - simulation_started) / 1000.0
	var average_simulation_ms := simulation_ms / float(simulation_steps)

	var combined_frames := 90
	var combined_started := Time.get_ticks_usec()
	for frame_index in range(combined_frames):
		if frame_index % 15 == 0:
			field.queue_bloom(Vector2(400.0 + float(frame_index), 330.0))
		if frame_index % 2 == 0:
			field.step_simulation()
			field.refresh_visuals_now()
	var combined_ms := float(Time.get_ticks_usec() - combined_started) / 1000.0
	var average_combined_frame_ms := combined_ms / float(combined_frames)
	var measured_step_ms := field.get_average_step_ms()
	var measured_render_ms := field.get_average_render_ms()
	var within_budget := (
		average_simulation_ms <= TARGET_FRAME_MS
		and measured_render_ms <= TARGET_FRAME_MS
		and average_combined_frame_ms <= TARGET_FRAME_MS
	)

	var report := (
		"TERRITORY_PERFORMANCE: simulation_avg=%.3fms combined_60fps_frame_avg=%.3fms "
		+ "measured_step_avg=%.3fms measured_render_avg=%.3fms target=%.2fms"
	) % [
			average_simulation_ms,
			average_combined_frame_ms,
			measured_step_ms,
			measured_render_ms,
			TARGET_FRAME_MS,
		]
	print(report)

	field.queue_free()
	await process_frame
	if within_budget:
		print("TERRITORY_PERFORMANCE: PASS")
		quit(0)
	else:
		push_error("TERRITORY_PERFORMANCE: frame budget exceeded")
		quit(1)
