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
	# Campaign is the authored 25-wave structure. Its milestones are wave events, and
	# the seconds below are those waves expressed on the clock rather than a second
	# schedule that could drift away from the wave table.
	passed = passed and campaign.wave_director.is_campaign_mode()
	passed = passed and is_equal_approx(campaign.wave_director.run_duration_seconds, 1500.0)
	passed = passed and is_equal_approx(campaign.wave_director.wave_duration_seconds, 60.0)
	passed = passed and is_equal_approx(campaign.wave_director.elite_time_seconds, 335.0)
	passed = passed and is_equal_approx(campaign.wave_director.boss_time_seconds, 722.5)
	passed = passed and is_equal_approx(campaign.wave_director.final_invasion_time_seconds, 1440.0)
	passed = passed and is_equal_approx(campaign.wave_director.cleanup_time_seconds, 1485.0)
	passed = passed and is_equal_approx(campaign.progression.xp_requirement_growth, 1.20)
	# The whole schedule is present and its endpoints are the authored curve.
	var final_spec := campaign.wave_director.get_wave_spec(25)
	passed = passed and final_spec != null
	passed = passed and is_equal_approx(final_spec.hp_multiplier, 3.60)
	passed = passed and is_equal_approx(final_spec.contact_damage_multiplier, 2.25)
	passed = passed and is_equal_approx(final_spec.territory_strength_multiplier, 3.20)
	passed = passed and is_equal_approx(final_spec.cc_resistance, 0.20)
	passed = passed and final_spec.grants_wave_relic == false
	var opening_spec := campaign.wave_director.get_wave_spec(1)
	passed = passed and is_equal_approx(opening_spec.hp_multiplier, 1.10)
	passed = passed and is_zero_approx(opening_spec.opening_break_seconds)
	# Ordinary lines stop at three in both modes; the Evolution keeps its five.
	passed = passed and campaign.progression.maximum_upgrade_level == 3
	passed = passed and campaign.progression.evolution_maximum_upgrade_level == 5
	if passed:
		print("PHASE_B_RUN_MODE: PASS")
	else:
		push_error("PHASE_B_RUN_MODE: configuration mismatch")
	quit(0 if passed else 1)
