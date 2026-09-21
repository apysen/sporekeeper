extends SceneTree

const RUN_MODE := preload("res://src/core/models/run/run_mode.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed := true
	RUN_MODE.set_selected(RUN_MODE.Id.QUICK)
	var load_error := change_scene_to_file("res://scenes/run/run.tscn")
	if load_error != OK:
		push_error("Unable to load run scene: %s" % error_string(load_error))
		quit(1)
		return
	await process_frame
	await process_frame
	var quick := current_scene as RunRoot
	passed = passed and quick != null
	passed = passed and is_equal_approx(quick.wave_director.run_duration_seconds, 720.0)
	passed = passed and is_equal_approx(quick.progression.xp_requirement_growth, 1.34)

	RUN_MODE.set_selected(RUN_MODE.Id.CAMPAIGN)
	load_error = change_scene_to_file("res://scenes/run/run.tscn")
	if load_error != OK:
		push_error("Unable to reload run scene: %s" % error_string(load_error))
		quit(1)
		return
	await process_frame
	await process_frame
	var campaign := current_scene as RunRoot
	passed = passed and campaign != null
	# Campaign is the authored 20-wave structure. Its milestones are wave events, and
	# the seconds below are those waves expressed on the clock rather than a second
	# schedule that could drift away from the wave table.
	passed = passed and campaign.wave_director.is_campaign_mode()
	passed = passed and is_equal_approx(campaign.wave_director.run_duration_seconds, 1200.0)
	passed = passed and is_equal_approx(campaign.wave_director.wave_duration_seconds, 60.0)
	passed = passed and is_equal_approx(campaign.wave_director.elite_time_seconds, 270.0)
	passed = passed and is_equal_approx(campaign.wave_director.boss_time_seconds, 542.5)
	passed = passed and is_equal_approx(campaign.wave_director.final_invasion_time_seconds, 1140.0)
	passed = passed and is_equal_approx(campaign.wave_director.cleanup_time_seconds, 1185.0)
	passed = passed and is_equal_approx(campaign.progression.xp_requirement_growth, 1.18)
	# Three Adaptations rather than four, handed out on the wave table rather than
	# drawn: the two structural Campaign rules the rework is built on.
	passed = passed and campaign.progression.get_maximum_owned_adaptations() == 3
	passed = passed and campaign.progression.authored_path_drafts
	# The whole schedule is present and its endpoints are the authored curve.
	var final_spec := campaign.wave_director.get_wave_spec(CampaignWaves.WAVE_COUNT)
	passed = passed and final_spec != null
	passed = passed and final_spec.act == CampaignWaves.Act.BLIGHT
	passed = passed and is_equal_approx(final_spec.hp_multiplier, 3.60)
	passed = passed and is_equal_approx(final_spec.contact_damage_multiplier, 2.25)
	passed = passed and is_equal_approx(final_spec.territory_strength_multiplier, 3.20)
	passed = passed and is_equal_approx(final_spec.cc_resistance, 0.20)
	passed = passed and final_spec.grants_wave_relic == false
	passed = passed and final_spec.sustains_final_pressure
	var opening_spec := campaign.wave_director.get_wave_spec(1)
	passed = passed and opening_spec.act == CampaignWaves.Act.GERMINATION
	passed = passed and is_equal_approx(opening_spec.hp_multiplier, 1.10)
	passed = passed and is_zero_approx(opening_spec.opening_break_seconds)
	passed = passed and opening_spec.grants_path_draft
	passed = passed and opening_spec.threat_budget > 0.0
	# Ordinary lines stop at three in both modes; the Evolution keeps its five.
	passed = passed and campaign.progression.maximum_upgrade_level == 3
	passed = passed and campaign.progression.evolution_maximum_upgrade_level == 5
	# Quick is four Adaptations and draws its Paths from ordinary level-ups, and
	# switching into Campaign and back must say so rather than leaving Campaign's
	# rules behind on a Quick run.
	campaign.progression.configure_mode(RUN_MODE.Id.QUICK)
	passed = passed and campaign.progression.get_maximum_owned_adaptations() == 4
	passed = passed and not campaign.progression.authored_path_drafts
	if passed:
		print("RUN_MODE: PASS")
	else:
		push_error("RUN_MODE: configuration mismatch")
	quit(0 if passed else 1)
