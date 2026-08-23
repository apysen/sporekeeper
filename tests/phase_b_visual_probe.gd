extends SceneTree


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
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	prototype._apply_progression_modifiers()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	prototype.combat.spawn_pack(PhaseBCombatDirector.EnemyRole.HUNTER, 10)
	prototype.combat.spawn_pack(PhaseBCombatDirector.EnemyRole.GRAZER, 6)
	prototype.combat.spawn_enemy(PhaseBCombatDirector.EnemyRole.SABOTEUR, Vector2(118.0, 166.0))
	prototype.combat.spawn_enemy(PhaseBCombatDirector.EnemyRole.CORRUPTOR, Vector2(220.0, 425.0))
	prototype.combat.spawn_enemy(PhaseBCombatDirector.EnemyRole.COLONIZER, Vector2(615.0, 82.0))
	prototype.combat.spawn_enemy(PhaseBCombatDirector.EnemyRole.WARDEN, Vector2(825.0, 168.0))
	prototype.combat.spawn_enemy(PhaseBCombatDirector.EnemyRole.COLONY_CORE, Vector2(780.0, 440.0))
	prototype.combat.spawn_enemy(PhaseBCombatDirector.EnemyRole.ELITE, Vector2(760.0, 320.0))
	prototype.overlay.spawn_seed(Vector2(704.0, 408.0), 8.0)
	prototype.overlay.plant_bloom(Vector2(592.0, 286.0), 8.0)
	prototype.combat.spawn_briar_pod(
		Vector2(340.0, 330.0),
		prototype.evolutions.briar_pod_radius_pixels,
		prototype.evolutions.briar_pod_duration_seconds,
		prototype.evolutions.briar_pod_contact_multiplier
	)
	prototype.territory_field.queue_bloom(Vector2(662.0, 413.0))
	for _step_index in range(10):
		prototype.territory_field.step_simulation()
	# The fixture documents an established border, so develop the thorns the same
	# way a settled frontier would rather than capturing a bare fresh edge.
	prototype.territory_field.debug_establish_bramble()
	prototype.territory_field.refresh_visuals_now()
	prototype.combat.damage_enemies_in_radius(
		Vector2(760.0, 320.0),
		1.0,
		48.0,
		PhaseBCombatDirector.DeathSource.BLOOM
	)
	prototype.run_label.text = (
		"Visual fixture: thorned Green frontier, Briar Pod, full enemy roster, Seed, and Bloom."
	)
	prototype.run_label.text = "SUPPRESSION SIEGE     05:00 REMAINING     22 HOSTILES"
	await process_frame
	await process_frame

	var screenshot := root.get_texture().get_image()
	if screenshot == null:
		push_error("The active renderer did not provide a screenshot image")
		quit(1)
		return
	var output_path := "res://.godot/phase_b_prototype.png"
	var save_error := screenshot.save_png(output_path)
	if save_error != OK:
		push_error("Unable to save Phase B screenshot: %s" % error_string(save_error))
		quit(1)
		return
	prototype._open_pause_menu()
	await process_frame
	await process_frame
	var pause_screenshot := root.get_texture().get_image()
	if pause_screenshot == null:
		push_error("The active renderer did not provide a pause-menu screenshot")
		quit(1)
		return
	var pause_output_path := "res://.godot/phase_b_pause_menu.png"
	var pause_save_error := pause_screenshot.save_png(pause_output_path)
	if pause_save_error != OK:
		push_error("Unable to save pause-menu screenshot: %s" % error_string(pause_save_error))
		quit(1)
		return
	print(
		"PHASE_B_VISUAL_PROBE: saved %s and %s (%dx%d)" % [
			output_path,
			pause_output_path,
			screenshot.get_width(),
			screenshot.get_height(),
		]
	)
	quit(0)
