extends SceneTree

## Phase 3 draws two things the headless renderer cannot confirm: the persistent
## broken ring that marks a colony cut off from the main organism, and the pulse that
## fires at the moment the connection breaks. This grows an organism, cuts it in half,
## and renders the result so both can be looked at.


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
	if prototype == null:
		push_error("Phase B scene did not become current")
		quit(1)
		return
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype._set_simulation_paused(true)

	var field := prototype.territory_field
	var network := prototype.root_network
	
	network.reset_network()
	field.reset_field()

	var growth_origin := Vector2(
		field.tuning.arena_size.x * 0.24,
		field.tuning.arena_size.y * 0.54
	)
	for growth_step in range(10):
		field.queue_bloom(
			growth_origin + Vector2(0.0, float(growth_step - 5) * 9.0),
			6.0,
			1.0,
			6.0,
			2.4
		)
	for _grow_step in range(900):
		field.step_simulation()
	for _bank_step in range(360):
		field.step_simulation()
		network.advance(0.5, prototype.player.position)

	# Collected into an array rather than counted into an int: a lambda captures a
	# local by value, so an int incremented inside one never reaches the caller.
	var severed: Array = []
	network.colony_isolated.connect(
		func(_component_id: int, _biomass: float, centroid: Vector2) -> void:
			severed.append(centroid)
			prototype.overlay.spawn_sever_pulse(centroid)
	)
	var organism_centre := field.get_component_centroid(network.get_primary_component())
	var band_stamps := int(field.tuning.arena_size.y / 7.0)
	for band_step in range(band_stamps + 1):
		for _cut_repeat in range(3):
			field.queue_hostile_growth(
				Vector2(organism_centre.x, float(band_step) * 7.0),
				300.0,
				1.2
			)
	for _cut_step in range(120):
		field.step_simulation()
		network.advance(0.05, prototype.player.position)
	field.recalculate_metrics_now()

	var colonies := network.get_isolated_colony_positions()
	prototype.overlay.set_isolated_colonies(colonies)
	# One more sever pulse so the moment-of-breaking visual is in the frame alongside
	# the persistent markers; in play they are half a second apart.
	if not colonies.is_empty():
		prototype.overlay.spawn_sever_pulse(colonies[0])
	field.refresh_visuals_now()
	prototype.overlay.queue_redraw()
	await process_frame
	await process_frame

	var output_path := "res://.godot/colony_markers.png"
	var screenshot := root.get_texture().get_image()
	var save_error := screenshot.save_png(output_path)
	if save_error != OK:
		push_error("Unable to save colony marker screenshot: %s" % error_string(save_error))
		quit(1)
		return

	print(
		"COLONY_MARKER_PROBE: components=%d severed_events=%d colonies=%d "
		% [field.get_component_count(), severed.size(), colonies.size()]
		+ "primary=%.0f total=%.0f stranded=%.0f saved=%s"
		% [
			network.get_primary_reserve(),
			network.get_total_reserve(),
			network.get_total_reserve() - network.get_primary_reserve(),
			output_path,
		]
	)
	quit(0)
