extends SceneTree

var _report := SmokeReport.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_error := change_scene_to_file("res://scenes/run/run.tscn")
	_report.check(load_error == OK, "Sporekeeper scene resource loads")
	if load_error != OK:
		quit(1)
		return
	await process_frame
	await process_frame

	var prototype := current_scene as RunRoot
	_report.check(prototype != null, "Sporekeeper scene becomes the current prototype")
	if prototype == null:
		quit(1)
		return
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype._set_simulation_paused(true)
	# The authored scene carries development switches for narrowing a playtest to a
	# few paths. The suite pins them on so a narrowed playtest can never quietly
	# change what these checks cover; the block that exercises them flips its own.
	prototype.progression.offer_spore_path = true
	prototype.progression.offer_bloom_path = true
	prototype.progression.offer_bramble_path = true
	prototype.progression.offer_root_path = true
	prototype.progression.offer_pruning_path = true
	prototype.progression.offer_thistle_path = true
	prototype.progression.offer_vine_path = true
	prototype.progression.offer_fruit_path = true
	# Drafting draws at random, and a suite whose drafts change between runs cannot
	# be trusted when it fails. The seed is pinned here so every check below sees the
	# same run; the block that covers the randomness clears it and rolls its own.
	prototype.progression.authored_run_seed = 0x51DE0001
	prototype.progression.set_run_seed(prototype.progression.authored_run_seed)
	_report.check(
		prototype.audio_settings.get_parent().name == &"GameplayComponents"
		and prototype.progression.get_parent().name == &"GameplayComponents"
		and prototype.wave_director.get_parent().name == &"GameplayComponents"
		and prototype.spore_director.get_parent().name == &"Paths"
		and prototype.bloom_director.get_parent().name == &"Paths"
		and prototype.bramble_director.get_parent().name == &"Paths"
		and prototype.root_director.get_parent().name == &"Paths"
		and prototype.metabolism.get_parent().name == &"GameplayComponents"
		and prototype.combat.hunter_profile.get_parent().name == &"EnemyProfiles"
		and prototype.combat.grazer_profile.get_parent().name == &"EnemyProfiles"
		and prototype.combat.saboteur_profile.get_parent().name == &"EnemyProfiles"
		and prototype.combat.corruptor_profile.get_parent().name == &"EnemyProfiles"
		and prototype.combat.colonizer_profile.get_parent().name == &"EnemyProfiles"
		and prototype.combat.warden_profile.get_parent().name == &"EnemyProfiles"
		and prototype.combat.colony_core_profile.get_parent().name == &"EnemyProfiles"
		and prototype.combat.elite_profile.get_parent().name == &"EnemyProfiles"
		and prototype.combat.boss_profile.get_parent().name == &"EnemyProfiles",
		"Sporekeeper gameplay systems and all enemy profiles are authored as visible scene nodes"
	)
	# Texture-backed Button styles are presented by real NinePatchRect children.
	# The Button keeps ownership of input and text, while only each border's center
	# edge strips stretch. Every raster botanical painting shares the deliberately strong
	# watercolor material rather than relying on per-asset treatment.
	# A border exists to stop a StyleBoxTexture being stretched. Once one is installed
	# the Button's own texture style is replaced by a StyleBoxEmpty, so a Button still
	# holding a StyleBoxTexture is one the border never reached - which is the actual
	# failure, and is checked as such. A Button drawing the engine's own StyleBoxFlat
	# has nothing to slice and correctly has no border, which is why this asks about
	# the style rather than demanding a border from every Button it can find.
	#
	# Nothing in the run is in that state today - the glossary's thirteen runtime-built
	# buttons wear the run's art like the rest - but the distinction is the point: the
	# check is about texture styles being sliced, not about every Button owning a node.
	var ui_buttons := prototype.find_children("*", "Button", true, false)
	var bordered_buttons := 0
	var button_borders_are_sliced := true
	for button_node in ui_buttons:
		var button := button_node as Button
		var normal_style := button.get_theme_stylebox(&"normal")
		if normal_style is StyleBoxTexture:
			button_borders_are_sliced = false
			continue
		var border := button.get_node_or_null("NinePatchBorder") as NinePatchRect
		if border == null:
			# A StyleBoxEmpty here is the fingerprint the border leaves when it captures
			# a texture style - and no Button is authored with one - so finding it
			# without a border means the border went away and the Button is now drawing
			# no background at all. Anything else is the engine's own flat style, which
			# is a Button that never had a border and correctly still has none.
			button_borders_are_sliced = (
				button_borders_are_sliced and not (normal_style is StyleBoxEmpty)
			)
			continue
		bordered_buttons += 1
		button_borders_are_sliced = (
			button_borders_are_sliced
			and border.axis_stretch_horizontal == NinePatchRect.AXIS_STRETCH_MODE_STRETCH
			and border.axis_stretch_vertical == NinePatchRect.AXIS_STRETCH_MODE_STRETCH
			and border.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		)
	# The same self-guard the wording check carries: a filter that matched nothing
	# would pass silently and vouch for a surface it had stopped looking at.
	button_borders_are_sliced = button_borders_are_sliced and bordered_buttons >= 10
	var botanical_material := prototype.overlay.material as ShaderMaterial
	var fruit_material := prototype.adaptation_director.material as ShaderMaterial
	var fruit_art_loaded := AdaptationDirector.FRUIT_TEXTURES.size() == 6
	for fruit_texture in AdaptationDirector.FRUIT_TEXTURES:
		fruit_art_loaded = fruit_art_loaded and fruit_texture != null
	_report.check(
		button_borders_are_sliced,
		"every run Button owns a correctly sliced NinePatchRect border"
	)
	_report.check(
		botanical_material != null
		and fruit_material != null
		and botanical_material.shader == fruit_material.shader
		and float(botanical_material.get_shader_parameter("granulation_strength")) >= 0.40
		and float(botanical_material.get_shader_parameter("paper_lift")) >= 0.10
		and prototype.overlay.seed_texture != null
		and prototype.overlay.bloom_texture != null
		and fruit_art_loaded
		and AdaptationDirector.FRUITSEED_TEXTURE != null,
		"Bloom, Seed, all six Fruit paintings, and Fruitseed share visible watercolor granulation"
	)
	var original_hunter_health := prototype.combat.hunter_profile.maximum_health
	var original_hunter_behavior := prototype.combat.hunter_profile.territory_behavior
	prototype.combat.hunter_profile.maximum_health = 37.0
	prototype.combat.hunter_profile.territory_behavior = (
		EnemyProfile.TerritoryBehavior.GRAZE_GREEN
	)
	prototype.combat.reset_combat()
	prototype.combat.set_enemy_scaling(1.0, 1.0)
	var inspector_authored_enemy_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER
	)
	_report.check(
		is_equal_approx(
			prototype.combat.get_enemy_health(inspector_authored_enemy_id),
			37.0
		)
		and prototype.combat.get_enemy_territory_behavior(inspector_authored_enemy_id)
		== EnemyProfile.TerritoryBehavior.GRAZE_GREEN,
		"new enemies snapshot health and behavior edited on their Inspector profile"
	)
	prototype.combat.hunter_profile.maximum_health = original_hunter_health
	prototype.combat.hunter_profile.territory_behavior = original_hunter_behavior
	prototype.combat.reset_combat()
	_report.check(
		is_equal_approx(prototype.combat.grazer_profile.territory_action_strength, 1.0)
		and is_equal_approx(prototype.combat.boss_profile.territory_action_strength, 2.60),
		"Grazer and Burrower retain their authored territory pressure"
	)
	_report.check(
		prototype.combat.saboteur_profile.territory_behavior
		== EnemyProfile.TerritoryBehavior.SABOTAGE_CATALYST
		and prototype.combat.corruptor_profile.territory_behavior
		== EnemyProfile.TerritoryBehavior.CORRUPT_GREEN
		and prototype.combat.colonizer_profile.territory_behavior
		== EnemyProfile.TerritoryBehavior.ESTABLISH_COLONY
		and prototype.combat.warden_profile.territory_behavior
		== EnemyProfile.TerritoryBehavior.SUPPRESS_MATURITY
		and prototype.combat.colony_core_profile.movement_behavior
		== EnemyProfile.MovementBehavior.ANCHORED,
		"the Inspector profiles expose each specialist's distinct GDD behavior"
	)
	_report.check(
		is_equal_approx(prototype.player.green_healing_per_second, 1.0),
		"established Green restores one health per second"
	)
	var contact_roles := PackedInt32Array([
		EnemyKinds.Role.HUNTER,
		EnemyKinds.Role.GRAZER,
		EnemyKinds.Role.SABOTEUR,
		EnemyKinds.Role.CORRUPTOR,
		EnemyKinds.Role.COLONIZER,
		EnemyKinds.Role.WARDEN,
		EnemyKinds.Role.COLONY_CORE,
		EnemyKinds.Role.ELITE,
		EnemyKinds.Role.BOSS,
	])
	var expected_contact_damage := PackedFloat32Array([
		5.5,
		4.0,
		3.0,
		4.0,
		2.0,
		4.5,
		0.0,
		9.0,
		12.0,
	])
	var enemy_contact_damage_is_halved := true
	for role_index in range(contact_roles.size()):
		prototype.player.reset_player()
		prototype.combat.reset_combat()
		prototype.combat.set_enemy_scaling(1.0, 1.0)
		var health_before_contact := prototype.player.get_health()
		var contact_enemy_id := prototype.combat.spawn_enemy(
			contact_roles[role_index],
			prototype.player.get_arena_position()
		)
		prototype.combat.simulate_step(0.0)
		enemy_contact_damage_is_halved = (
			enemy_contact_damage_is_halved
			and contact_enemy_id != -1
			and is_equal_approx(
				health_before_contact - prototype.player.get_health(),
				expected_contact_damage[role_index]
			)
		)
	_report.check(
		enemy_contact_damage_is_halved,
		"legacy contact damage remains halved and every new role uses its authored pressure"
	)
	prototype.player.reset_player()
	prototype.combat.reset_combat()
	prototype.player.apply_damage(10.0)
	var health_before_photosynthesis := prototype.player.get_health()
	prototype.player.set_simulation_paused(false)
	prototype.player._physics_process(1.0)
	prototype.player.set_simulation_paused(true)
	_report.check(
		is_equal_approx(
			prototype.player.get_health() - health_before_photosynthesis,
			1.0
		),
		"one second in established Green heals exactly one health"
	)
	prototype.player.reset_player()
	_report.check(
		is_equal_approx(db_to_linear(prototype.combat.xp_collect_sfx_volume_db), 0.50),
		"XP collection SFX plays at half its previous linear volume"
	)

	await SmokeWaves.run(_report, prototype)

	SmokeEnemyRoles.run(_report, prototype)

	SmokeSeedsAndBlooms.run(_report, prototype)

	SmokeDrafting.run(_report, prototype)

	SmokeRootNetwork.run(_report, prototype)

	SmokeEvolutions.run(_report, prototype)

	SmokeVineFruitBloom.run(_report, prototype)

	SmokeOvergrowManEater.run(_report, prototype)

	SmokePruning.run(_report, prototype)

	SmokeBrambleRoot.run(_report, prototype)

	SmokeEconomy.run(_report, prototype)

	SmokeCloverMachine.run(_report, prototype)

	SmokePresentation.run(_report, prototype)

	SmokeProgressionPanels.run(_report, prototype)

	await SmokeRelicRules.run(_report, prototype)

	SmokeMilestones.run(_report, prototype)

	SmokeEndgame.run(_report, prototype)

	prototype.queue_free()
	await process_frame
	if _report.failures == 0:
		print("RUN_SMOKE: PASS")
		quit(0)
	else:
		push_error("RUN_SMOKE: %d failure(s)" % _report.failures)
		quit(1)
