extends SceneTree

const RUN_MODE := preload("res://src/core/models/run/phase_b_run_mode.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed := true
	RUN_MODE.set_selected(RUN_MODE.Id.QUICK)
	var load_error := change_scene_to_file("res://scenes/run/phase_b_prototype.tscn")
	if load_error != OK:
		push_error("Unable to load run scene: %s" % error_string(load_error))
		quit(1)
		return
	await process_frame
	await process_frame
	var quick := current_scene as PhaseBPrototype
	passed = passed and quick != null
	passed = passed and is_equal_approx(quick.wave_director.run_duration_seconds, 720.0)
	passed = passed and is_equal_approx(quick.progression.xp_requirement_growth, 1.34)

	RUN_MODE.set_selected(RUN_MODE.Id.CAMPAIGN)
	load_error = change_scene_to_file("res://scenes/run/phase_b_prototype.tscn")
	if load_error != OK:
		push_error("Unable to reload run scene: %s" % error_string(load_error))
		quit(1)
		return
	await process_frame
	await process_frame
	var campaign := current_scene as PhaseBPrototype
	passed = passed and campaign != null
	passed = passed and is_equal_approx(campaign.wave_director.run_duration_seconds, 1800.0)
	passed = passed and is_equal_approx(campaign.wave_director.elite_time_seconds, 375.0)
	passed = passed and is_equal_approx(campaign.wave_director.boss_time_seconds, 900.0)
	passed = passed and is_equal_approx(campaign.wave_director.final_invasion_time_seconds, 1500.0)
	passed = passed and is_equal_approx(campaign.wave_director.cleanup_time_seconds, 1725.0)
	passed = passed and is_equal_approx(campaign.wave_director.final_health_scale, 3.0)
	passed = passed and is_equal_approx(campaign.wave_director.final_contact_damage_scale, 2.0)
	passed = passed and is_equal_approx(campaign.progression.xp_requirement_growth, 1.20)
	passed = passed and is_equal_approx(campaign.wave_director.final_spawn_interval_seconds, 0.14)
	if passed:
		print("PHASE_B_RUN_MODE: PASS")
	else:
		push_error("PHASE_B_RUN_MODE: configuration mismatch")
	quit(0 if passed else 1)
