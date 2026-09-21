extends SceneTree

## What the 20-wave Campaign's authored pressure actually produces, wave by wave.
##
## Difficulty is six curves plus a budget, not one number, and the point of printing
## them side by side is that a tuning pass can see which one it is about to move.
##
## The budget column replaced a requested-density column, and the difference is the
## whole Threat Director rework: a wave used to be a pack interval and a pack size,
## so its pressure could only grow by putting more bodies on the board, and the
## 130-enemy cap then quietly rejected most of what a late wave asked for. A wave is
## now a threat budget spent on named recipes, so the interesting number is not how
## many packs it wanted but what it could afford -- the "bodies" column below is the
## budget divided by the average price of the recipes the wave may buy, which is the
## honest estimate of how crowded the wave actually gets.
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
	print("wave act identity              hp    dmg    move   terr   act    cc    mod   break  budget  packs  bodies  relic")
	for wave_number in range(1, CampaignWaves.WAVE_COUNT + 1):
		var spec := director.get_wave_spec(wave_number)
		var average_price := 0.0
		var average_size := 0.0
		for recipe_id in spec.recipe_ids:
			average_price += float(EncounterRecipes.get_cost(recipe_id))
			average_size += float(EncounterRecipes.get_members(recipe_id).size())
		var recipes := maxf(1.0, float(spec.recipe_ids.size()))
		average_price /= recipes
		average_size /= recipes
		var packs := spec.threat_budget / maxf(1.0, average_price)
		print("%4d %3d  %-20s %.2f  %.2f  %.3f  %.2f  %.3f  %3d%%  %3d%%  %.2f  %6.0f  %5d  %6d  %s" % [
			wave_number,
			spec.act,
			String(spec.display_name),
			spec.hp_multiplier,
			spec.contact_damage_multiplier,
			spec.movement_speed_multiplier,
			spec.territory_strength_multiplier,
			spec.territory_action_speed_multiplier,
			roundi(spec.cc_resistance * 100.0),
			roundi(spec.modifier_chance * 100.0),
			spec.opening_break_seconds,
			spec.threat_budget,
			roundi(packs),
			roundi(packs * average_size),
			"relic" if spec.grants_wave_relic else "",
		])
	print("")
	_report_role_scaling()
	_report_recipes(director)
	_report_blight()
	quit(0)


func _report_role_scaling() -> void:
	## The exceptions, which is where movement pressure is actually decided. A role
	## taking the whole movement curve and one taking half of it are different
	## enemies at the final wave even though the wave hands them the same number.
	print("role scaling at Wave %d (movement x%.3f, action x%.3f):" % [
		CampaignWaves.WAVE_COUNT,
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


func _report_recipes(director: WaveDirector) -> void:
	## What each act is actually allowed to send, and what it costs.
	##
	## The act gate is the part worth watching: a wave whose budget has grown past an
	## expensive recipe still cannot buy one the act has not opened, so a run going
	## badly in Act I meets Act I problems rather than the Act IV answer to them.
	print("")
	print("recipe prices and act gates:")
	var recipe_ids := EncounterRecipes.RECIPES.keys()
	recipe_ids.sort()
	for recipe_id in recipe_ids:
		var members := EncounterRecipes.get_members(recipe_id)
		var roles := PackedStringArray()
		for role in members:
			roles.append(str(role))
		print("  %-22s cost %3d  act %d  bodies %d  roles %s%s%s" % [
			String(recipe_id),
			EncounterRecipes.get_cost(recipe_id),
			EncounterRecipes.get_minimum_act(recipe_id),
			members.size(),
			" ".join(roles),
			"  split" if EncounterRecipes.is_split(recipe_id) else "",
			"  interior" if EncounterRecipes.is_interior(recipe_id) else "",
		])
	print("")
	print("what each wave may buy:")
	for wave_number in range(1, CampaignWaves.WAVE_COUNT + 1):
		var spec := director.get_wave_spec(wave_number)
		var names := PackedStringArray()
		for recipe_id in spec.recipe_ids:
			names.append(String(recipe_id))
		print("  wave %2d  act %d  %s" % [wave_number, spec.act, " ".join(names)])


func _report_blight() -> void:
	## What a run that kept Provoking is actually fighting. Budget moves several
	## times as far as health and damage do, which is the design: the difficulty a
	## player chose should arrive as harder encounters rather than as longer fights.
	print("")
	print("blight:")
	for level in range(BlightTable.MAXIMUM_LEVEL + 1):
		print("  %-3s budget x%.2f  hp x%.2f  damage x%.2f  specialist price x%.2f" % [
			BlightTable.get_level_name(level),
			BlightTable.get_budget_multiplier(level),
			BlightTable.get_health_multiplier(level),
			BlightTable.get_damage_multiplier(level),
			BlightTable.get_specialist_price_multiplier(level),
		])
