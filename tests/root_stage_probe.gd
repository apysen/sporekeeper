extends SceneTree

## Phase 1 of the Root Metabolism rework asks one question: does sustained territory
## visibly become established? A passing assertion cannot answer that, because the
## answer is whether a person can see it. This holds ground long enough to root, then
## renders the banded ROOT DEPTH view and reports the stage histogram beside the
## image, so the numbers and the picture can be checked against each other.


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
	var field := prototype.territory_field

	# Hold the ground. Nothing else: no ability, no purchase, no injection. If the
	# stages move, they moved because the run kept what it had.
	for _step_index in range(900):
		field.step_simulation()
	field.recalculate_metrics_now()
	field.analyze_topology_now()

	# Sampled on a grid through the public local-position API rather than by reaching
	# into the cell arrays, so the probe stays a reader of the field and the field
	# gains no accessors it only ever needed for a probe.
	var histogram := PackedInt32Array([0, 0, 0, 0])
	var claimable := 0
	var samples := 160
	for sample_y in range(samples):
		for sample_x in range(samples):
			var point := Vector2(
				(float(sample_x) + 0.5) / float(samples) * field.tuning.arena_size.x,
				(float(sample_y) + 0.5) / float(samples) * field.tuning.arena_size.y
			)
			if not field.is_claimable_at_local(point):
				continue
			claimable += 1
			if field.get_control_at_local(point) <= field.tuning.ownership_threshold:
				continue
			histogram[field.get_root_stage(field.get_maturity_at_local(point))] += 1

	# Cycled through the prototype rather than the field directly, so the on-screen
	# view label agrees with what is actually being rendered. Driving the field alone
	# leaves the header naming a view the picture is not showing.
	while field.debug_view != TerritoryField.DebugView.ROOT:
		prototype._cycle_debug_view()
	field.refresh_visuals_now()
	await process_frame
	await process_frame

	var output_path := "res://.godot/root_stages.png"
	var screenshot := root.get_texture().get_image()
	var save_error := screenshot.save_png(output_path)
	if save_error != OK:
		push_error("Unable to save root stage screenshot: %s" % error_string(save_error))
		quit(1)
		return

	print(
		"ROOT_STAGE_PROBE: view=%s held=%.1f%% rooted=%.1f%% deep=%.1f%% "
		% [
			field.get_debug_view_name(),
			field.get_player_percent(),
			field.get_rooted_territory_percent(),
			field.get_deep_rooted_percent(),
		]
		+ "shallow=%d established=%d developed=%d late=%d claimable=%d saved=%s"
		% [
			histogram[TerritoryField.RootStage.SHALLOW],
			histogram[TerritoryField.RootStage.ESTABLISHED],
			histogram[TerritoryField.RootStage.DEVELOPED],
			histogram[TerritoryField.RootStage.LATE],
			claimable,
			output_path,
		]
	)
	quit(0)
