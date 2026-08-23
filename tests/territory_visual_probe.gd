extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_error := change_scene_to_file("res://scenes/run/territory_prototype.tscn")
	if load_error != OK:
		push_error("Unable to load territory prototype scene: %s" % error_string(load_error))
		quit(1)
		return

	await process_frame
	await process_frame
	var prototype := current_scene as TerritoryPrototype
	if prototype == null:
		push_error("Territory prototype scene did not become current")
		quit(1)
		return

	prototype.territory_field.queue_bloom(Vector2(482.0, 270.0))
	prototype.overlay.spawn_bloom(Vector2(482.0, 270.0))
	var hostile_seed_position := Vector2(
		prototype.tuning.arena_size.x * 0.82,
		prototype.tuning.arena_size.y * 0.52
	)
	prototype.overlay.spawn_seed(hostile_seed_position)
	prototype.grazer.launch(292.0)

	var sampled_frame_count := 118
	var sampling_started_usec := Time.get_ticks_usec()
	for _frame in range(sampled_frame_count):
		await process_frame
	var sampling_seconds := float(Time.get_ticks_usec() - sampling_started_usec) / 1000000.0
	var sampled_fps := float(sampled_frame_count) / sampling_seconds
	var germination_wait := maxf(
		0.0,
		prototype.tuning.seed_charge_seconds + 0.25 - sampling_seconds
	)
	if germination_wait > 0.0:
		await create_timer(germination_wait).timeout
	await create_timer(0.12).timeout
	var hostile_seed_control := prototype.territory_field.get_control_at_local(hostile_seed_position)
	if hostile_seed_control <= prototype.tuning.ownership_threshold:
		push_error("Hostile-area Seed did not establish Green territory: %.2f" % hostile_seed_control)
		quit(1)
		return

	prototype.territory_field.queue_bloom(Vector2(662.0, 413.0))
	prototype.overlay.spawn_bloom(Vector2(662.0, 413.0))
	prototype.overlay.spawn_seed(Vector2(742.0, 132.0))
	var wall_bloom_position := Vector2(
		prototype.tuning.arena_size.x * 0.475,
		prototype.tuning.arena_size.y * 0.20
	)
	prototype.territory_field.queue_bloom(wall_bloom_position)
	prototype.overlay.spawn_bloom(wall_bloom_position)
	await create_timer(0.20).timeout
	prototype._reset_prototype()
	await process_frame
	await process_frame

	var screenshot := root.get_texture().get_image()
	var output_path := "res://.godot/phase_a_prototype.png"
	var save_error := screenshot.save_png(output_path)
	if save_error != OK:
		push_error("Unable to save territory prototype screenshot: %s" % error_string(save_error))
		quit(1)
		return

	print(
		"TERRITORY_VISUAL_PROBE: saved %s (%dx%d), sampled_fps=%.1f, hostile_seed_control=%.2f"
		% [
			output_path,
			screenshot.get_width(),
			screenshot.get_height(),
			sampled_fps,
			hostile_seed_control,
		]
	)
	quit(0)
