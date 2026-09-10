extends SceneTree

## What the 25-wave Campaign's authored pressure actually produces, wave by wave.
##
## Difficulty is six curves, not one, and the point of printing them side by side
## is that a tuning pass can see which one it is about to move. Requested density is
## printed with them because a wave's pack interval and pack pattern are as much a
## part of its pressure as its health multiplier -- and because requests are not
## spawns: the 130-enemy cap and the 124-actor reinforcement reserve reject many
## late requests, which is exactly the number a late-wave tuning question is about.
##
## Run: godot --headless --script tests/integration/campaign_pressure_probe.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file("res://scenes/run/run.tscn")
	await process_frame
	await process_frame
	var prototype := current_scene as RunRoot
	prototype.set_process(false)
	prototype.combat.set_process(false)
	var director := prototype.wave_director
	director.configure_mode(RunMode.Id.CAMPAIGN)
	print("wave  identity              hp    dmg    move   terr   act    cc    mod   break  int   pattern      packs  relic")
	for wave_number in range(1, CampaignWaves.WAVE_COUNT + 1):
		var spec := director.get_wave_spec(wave_number)
		var pattern := CampaignWaves.get_pack_pattern(spec.pack_pattern)
		var average_pack := 0.0
		for size in pattern:
			average_pack += float(size)
		average_pack /= maxf(1.0, float(pattern.size()))
		var spawning_seconds := spec.duration_seconds - spec.opening_break_seconds
		var requests := spawning_seconds / maxf(0.01, spec.pack_interval_seconds)
		print("%4d  %-20s %.2f  %.2f  %.3f  %.2f  %.3f  %3d%%  %3d%%  %.2f  %.2f  %-12s %5d  %s" % [
			wave_number,
			String(spec.display_name),
			spec.hp_multiplier,
			spec.contact_damage_multiplier,
			spec.movement_speed_multiplier,
			spec.territory_strength_multiplier,
			spec.territory_action_speed_multiplier,
			roundi(spec.cc_resistance * 100.0),
			roundi(spec.modifier_chance * 100.0),
			spec.opening_break_seconds,
			spec.pack_interval_seconds,
			String(spec.pack_pattern),
			roundi(requests * average_pack),
			"relic" if spec.grants_wave_relic else "",
		])
	print("")
	_report_role_scaling()
	_report_composition(director)
	quit(0)


func _report_role_scaling() -> void:
	## The exceptions, which is where movement pressure is actually decided. A role
	## taking the whole movement curve and one taking half of it are different
	## enemies at Wave 25 even though the wave hands them the same number.
	print("role scaling at Wave 25 (movement x%.3f, action x%.3f):" % [
		CampaignWaves.get_movement_speed_multiplier(CampaignWaves.WAVE_COUNT),
		CampaignWaves.get_territory_action_speed_multiplier(CampaignWaves.WAVE_COUNT),
	])
	var profiles := CampaignWaves.build_role_scaling_profiles()
	var wave_move := CampaignWaves.get_movement_speed_multiplier(
		CampaignWaves.WAVE_COUNT
	)
	var role_ids := profiles.keys()
	role_ids.sort()
	for role_id in role_ids:
		var profile: EnemyRoleScalingProfile = profiles[role_id]
		print("  role %2d  move x%.3f  action_factor %.2f  rest_only %s  modifier_from_wave %d" % [
			role_id,
			1.0 + (wave_move - 1.0) * profile.movement_scaling_factor,
			profile.action_speed_scaling_factor,
			profile.scales_rest_interval_only,
			profile.modifier_eligible_from_wave,
		])


func _report_composition(director: WaveDirector) -> void:
	## Whether a wave's shuffled leader deck really delivers its authored weights.
	## The deck exists so it does, and a probe that never checks it is a probe that
	## would not notice the day it stopped.
	print("")
	print("leader deck check (100 draws per wave, authored vs drawn):")
	for wave_number in [1, 6, 13, 18, 25]:
		var spec := director.get_wave_spec(wave_number)
		var deck := CampaignWaves.shuffle_deck(
			CampaignWaves.build_leader_deck(spec),
			12345,
			wave_number,
			0
		)
		var counts := {}
		for role in deck:
			counts[role] = int(counts.get(role, 0)) + 1
		var parts := PackedStringArray()
		var roles := spec.role_weights.keys()
		roles.sort()
		for role in roles:
			parts.append("%d:%d/%d" % [
				role,
				int(counts.get(role, 0)),
				int(spec.role_weights[role]),
			])
		print("  wave %2d  %s" % [wave_number, " ".join(parts)])
