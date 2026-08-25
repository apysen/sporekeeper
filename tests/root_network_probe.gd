extends SceneTree

## Phase 7 moves the root system onto the battlefield: vessels running out of each
## organism, pulses that favour the ground the player is standing on, and a severed
## colony that keeps its roots and loses its flow. None of that can be confirmed by an
## assertion about whether it was drawn correctly, so it is rendered and looked at.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_error := change_scene_to_file("res://scenes/run/phase_b_prototype.tscn")
	if load_error != OK:
		push_error("Unable to load Phase B scene: %s" % error_string(load_error))
		quit(1)
		return
	await process_frame
	await process_frame
	var prototype := current_scene as PhaseBPrototype
	prototype.player.input_enabled = false
	var field := prototype.territory_field
	var network := prototype.root_network
	
	network.reset_network()
	field.reset_field()

	var origin := Vector2(field.tuning.arena_size.x * 0.24, field.tuning.arena_size.y * 0.54)
	for growth in range(10):
		field.queue_bloom(origin + Vector2(0.0, float(growth - 5) * 9.0), 6.0, 1.0, 6.0, 2.4)
	for _grow in range(900):
		field.step_simulation()
	for _bank in range(300):
		field.step_simulation()
		network.advance(0.5, prototype.player.position)

	# Cut it, so the render contains both an organism that flows and a colony that has
	# stopped: the difference between them is the thing being checked.
	var heart := field.get_component_centroid(network.get_primary_component())
	for band in range(int(field.tuning.arena_size.y / 7.0) + 1):
		for _repeat in range(3):
			field.queue_hostile_growth(Vector2(heart.x, float(band) * 7.0), 300.0, 1.2)
	for _cut in range(120):
		field.step_simulation()
		network.advance(0.05, prototype.player.position)
	field.recalculate_metrics_now()

	prototype._advance_root_layer(prototype.root_layer_interval_seconds + 0.01)
	prototype.overlay.set_isolated_colonies(network.get_isolated_colony_positions())
	prototype.overlay.spawn_root_surge(heart, prototype.root_surge_seconds)
	prototype._set_root_inspect(true)
	# Advanced part-way so the pulses are caught mid-vessel rather than at either end.
	prototype.overlay._advance_root_flow(0.4)
	field.refresh_visuals_now()
	prototype.overlay.queue_redraw()
	await process_frame
	await process_frame

	var output_path := "res://.godot/root_network.png"
	var save_error := root.get_texture().get_image().save_png(output_path)
	if save_error != OK:
		push_error("Unable to save root network screenshot: %s" % error_string(save_error))
		quit(1)
		return
	var flowing := 0
	for vessel in prototype.overlay._root_vessels:
		if vessel["flowing"]:
			flowing += 1
	print(
		"ROOT_NETWORK_PROBE: components=%d vessels=%d flowing=%d colonies=%d "
		% [
			field.get_component_count(),
			prototype.overlay.get_root_vessel_count(),
			flowing,
			network.get_isolated_colony_positions().size(),
		]
		+ "primary=%.0f stranded=%.0f saved=%s"
		% [
			network.get_primary_reserve(),
			network.get_total_reserve() - network.get_primary_reserve(),
			output_path,
		]
	)
	quit(0)
