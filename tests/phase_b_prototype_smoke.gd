extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_error := change_scene_to_file("res://scenes/run/phase_b_prototype.tscn")
	_check(load_error == OK, "Phase B scene resource loads")
	if load_error != OK:
		quit(1)
		return
	await process_frame
	await process_frame

	var prototype := current_scene as PhaseBPrototype
	_check(prototype != null, "Phase B scene becomes the current prototype")
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
	_check(
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
		"Phase B gameplay systems and all enemy profiles are authored as visible scene nodes"
	)
	var original_hunter_health := prototype.combat.hunter_profile.maximum_health
	var original_hunter_behavior := prototype.combat.hunter_profile.territory_behavior
	prototype.combat.hunter_profile.maximum_health = 37.0
	prototype.combat.hunter_profile.territory_behavior = (
		PhaseBEnemyProfile.TerritoryBehavior.GRAZE_GREEN
	)
	prototype.combat.reset_combat()
	prototype.combat.set_enemy_scaling(1.0, 1.0)
	var inspector_authored_enemy_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER
	)
	_check(
		is_equal_approx(
			prototype.combat.get_enemy_health(inspector_authored_enemy_id),
			37.0
		)
		and prototype.combat.get_enemy_territory_behavior(inspector_authored_enemy_id)
		== PhaseBEnemyProfile.TerritoryBehavior.GRAZE_GREEN,
		"new enemies snapshot health and behavior edited on their Inspector profile"
	)
	prototype.combat.hunter_profile.maximum_health = original_hunter_health
	prototype.combat.hunter_profile.territory_behavior = original_hunter_behavior
	prototype.combat.reset_combat()
	_check(
		is_equal_approx(prototype.combat.grazer_profile.territory_action_strength, 1.0)
		and is_equal_approx(prototype.combat.boss_profile.territory_action_strength, 2.60),
		"Grazer and Burrower retain their authored territory pressure"
	)
	_check(
		prototype.combat.saboteur_profile.territory_behavior
		== PhaseBEnemyProfile.TerritoryBehavior.SABOTAGE_CATALYST
		and prototype.combat.corruptor_profile.territory_behavior
		== PhaseBEnemyProfile.TerritoryBehavior.CORRUPT_GREEN
		and prototype.combat.colonizer_profile.territory_behavior
		== PhaseBEnemyProfile.TerritoryBehavior.ESTABLISH_COLONY
		and prototype.combat.warden_profile.territory_behavior
		== PhaseBEnemyProfile.TerritoryBehavior.SUPPRESS_MATURITY
		and prototype.combat.colony_core_profile.movement_behavior
		== PhaseBEnemyProfile.MovementBehavior.ANCHORED,
		"the Inspector profiles expose each specialist's distinct GDD behavior"
	)
	_check(
		is_equal_approx(prototype.player.green_healing_per_second, 1.0),
		"established Green restores one health per second"
	)
	var contact_roles := PackedInt32Array([
		PhaseBCombatDirector.EnemyRole.HUNTER,
		PhaseBCombatDirector.EnemyRole.GRAZER,
		PhaseBCombatDirector.EnemyRole.SABOTEUR,
		PhaseBCombatDirector.EnemyRole.CORRUPTOR,
		PhaseBCombatDirector.EnemyRole.COLONIZER,
		PhaseBCombatDirector.EnemyRole.WARDEN,
		PhaseBCombatDirector.EnemyRole.COLONY_CORE,
		PhaseBCombatDirector.EnemyRole.ELITE,
		PhaseBCombatDirector.EnemyRole.BOSS,
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
	_check(
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
	_check(
		is_equal_approx(
			prototype.player.get_health() - health_before_photosynthesis,
			1.0
		),
		"one second in established Green heals exactly one health"
	)
	prototype.player.reset_player()
	_check(
		is_equal_approx(db_to_linear(prototype.combat.xp_collect_sfx_volume_db), 0.50),
		"XP collection SFX plays at half its previous linear volume"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype._set_simulation_paused(true)
	_check(
		is_equal_approx(prototype.wave_director.wave_grace_period_seconds, 5.0)
		and not prototype.is_wave_grace_period_active()
		and is_zero_approx(prototype.get_wave_grace_remaining_seconds())
		and prototype.wave_label.text.begins_with("WAVE 1"),
		"wave one begins immediately without a grace countdown"
	)
	prototype.advance_run(0.65)
	_check(
		prototype.combat.get_active_enemy_count() > 0,
		"wave-one reinforcements use the original immediate spawn timer"
	)
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype._set_simulation_paused(true)
	prototype.debug_advance_time(prototype.wave_director.wave_duration_seconds)
	_check(
		prototype.get_current_wave_number() == 2
		and prototype.is_wave_grace_period_active()
		and is_equal_approx(prototype.get_wave_grace_remaining_seconds(), 5.0)
		and prototype.combat.get_active_enemy_count() == 0
		and prototype.wave_label.text.contains("WAVE 2 IN 05s"),
		"each later wave also begins with the five-second reinforcement grace"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype._set_simulation_paused(true)
	var wave_one_hunter_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER
	)
	var wave_one_grazer_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.GRAZER
	)
	_check(
		prototype.get_current_wave_number() == 1
		and prototype.combat.get_enemy_xp_value(wave_one_hunter_id) == 2
		and is_equal_approx(
			prototype.combat.get_enemy_territory_erosion_scale(wave_one_grazer_id),
			1.0
		),
		"wave one enemies retain their authored XP and territory pressure"
	)
	prototype.debug_advance_time(prototype.wave_director.wave_duration_seconds)
	var wave_two_hunter_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER
	)
	var wave_two_grazer_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.GRAZER
	)
	var wave_two_boss_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.BOSS
	)
	_check(
		prototype.get_current_wave_number() == 2
		and prototype.combat.get_enemy_xp_value(wave_two_hunter_id) == 3
		and prototype.combat.get_enemy_xp_value(wave_two_boss_id) == 110
		and is_equal_approx(
			prototype.combat.get_enemy_territory_erosion_scale(wave_two_grazer_id),
			1.10
		),
		"wave two raises common and boss XP while adding 10% territory pressure"
	)
	_check(
		prototype.combat.get_enemy_xp_value(wave_one_hunter_id) == 2
		and is_equal_approx(
			prototype.combat.get_enemy_territory_erosion_scale(wave_one_grazer_id),
			1.0
		),
		"enemies keep the scaling from the wave in which they spawned"
	)
	prototype.debug_advance_time(prototype.wave_director.wave_duration_seconds)
	var wave_three_hunter_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER
	)
	var wave_three_grazer_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.GRAZER
	)
	var wave_three_boss_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.BOSS
	)
	_check(
		prototype.get_current_wave_number() == 3
		and prototype.combat.get_enemy_xp_value(wave_three_hunter_id) == 4
		and prototype.combat.get_enemy_xp_value(wave_three_boss_id) == 120
		and is_equal_approx(
			prototype.combat.get_enemy_territory_erosion_scale(wave_three_grazer_id),
			1.20
		)
		and prototype.wave_label.text.contains("WAVE 3"),
		"each completed minute advances the visible XP and territory scaling wave"
	)

	var start_position := prototype.player.get_arena_position()
	prototype.player.move_with_intent(Vector2.RIGHT, 0.20)
	_check(
		prototype.player.get_arena_position().x > start_position.x + 20.0,
		"manual movement advances the Gardener across claimable ground"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	var pause_elapsed_before := prototype.get_elapsed_seconds()
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	prototype._unhandled_input(escape_event)
	prototype._process(1.0)
	_check(
		prototype.is_pause_menu_open()
		and prototype.pause_overlay.visible
		and prototype.territory_field.simulation_paused
		and prototype.overlay.effects_paused
		and prototype.player.simulation_paused
		and prototype.combat.simulation_paused
		and is_equal_approx(prototype.get_elapsed_seconds(), pause_elapsed_before),
		"Escape opens a responsive pause overlay and freezes every gameplay system"
	)
	var sfx_bus_index := AudioServer.get_bus_index(prototype.audio_settings.sfx_bus_name)
	var music_bus_index := AudioServer.get_bus_index(prototype.audio_settings.music_bus_name)
	var original_sfx_mute := AudioServer.is_bus_mute(sfx_bus_index)
	var original_sfx_volume_db := AudioServer.get_bus_volume_db(sfx_bus_index)
	var original_music_mute := AudioServer.is_bus_mute(music_bus_index)
	var original_music_volume_db := AudioServer.get_bus_volume_db(music_bus_index)
	var ambient_music_stream := prototype.ambient_music_audio.stream as AudioStreamWAV
	_check(
		ambient_music_stream != null
		and ambient_music_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
		and ambient_music_stream.loop_begin == 0
		and ambient_music_stream.loop_end
		== roundi(ambient_music_stream.get_length() * ambient_music_stream.mix_rate),
		"the forest theme loops across its complete sample range"
	)
	_check(
		prototype.ambient_music_audio.autoplay
		and prototype.ambient_music_audio == prototype.get_node("AmbientMusic")
		and prototype.ambient_music_audio.playing
		and prototype.ambient_music_audio.bus == prototype.audio_settings.music_bus_name,
		"the scene-authored forest theme is already playing on the Music bus"
	)
	await create_timer(0.25).timeout
	_check(
		prototype.ambient_music_audio.playing
		and prototype.ambient_music_audio.get_playback_position() > 0.05,
		"forest music remains active and advances beyond its opening instant"
	)
	prototype.pause_volume_slider.value = 100.0
	_check(
		not AudioServer.is_bus_mute(sfx_bus_index)
		and is_equal_approx(
			db_to_linear(AudioServer.get_bus_volume_db(sfx_bus_index)),
			prototype.audio_settings.sfx_max_linear_volume
		)
		and prototype.pause_volume_value.text == "100%",
		"displayed SFX volume 100% is capped at 20% linear output"
	)
	prototype.pause_volume_slider.value = 37.0
	_check(
		not AudioServer.is_bus_mute(sfx_bus_index)
		and is_equal_approx(
			db_to_linear(AudioServer.get_bus_volume_db(sfx_bus_index)),
			0.37 * prototype.audio_settings.sfx_max_linear_volume
		)
		and prototype.pause_volume_value.text == "37%",
		"the pause-menu slider scales the capped SFX bus immediately"
	)
	prototype.pause_volume_slider.value = 0.0
	_check(
		AudioServer.is_bus_mute(sfx_bus_index)
		and prototype.pause_volume_value.text == "0%",
		"setting pause-menu volume to zero mutes the SFX bus"
	)
	AudioServer.set_bus_volume_db(sfx_bus_index, original_sfx_volume_db)
	AudioServer.set_bus_mute(sfx_bus_index, original_sfx_mute)
	prototype.pause_volume_slider.set_value_no_signal(
		0.0
		if original_sfx_mute
		else clampf(
			db_to_linear(original_sfx_volume_db)
			/ prototype.audio_settings.sfx_max_linear_volume,
			0.0,
			1.0
		) * 100.0
	)
	prototype._update_volume_label()
	prototype.pause_music_volume_slider.value = 100.0
	_check(
		not AudioServer.is_bus_mute(music_bus_index)
		and is_equal_approx(
			db_to_linear(AudioServer.get_bus_volume_db(music_bus_index)),
			prototype.audio_settings.music_max_linear_volume
		)
		and prototype.pause_music_volume_value.text == "100%",
		"displayed Music volume 100% is capped at 20% linear output"
	)
	var sfx_mute_before_music_change := AudioServer.is_bus_mute(sfx_bus_index)
	var sfx_volume_before_music_change := AudioServer.get_bus_volume_db(sfx_bus_index)
	prototype.pause_music_volume_slider.value = 43.0
	_check(
		not AudioServer.is_bus_mute(music_bus_index)
		and is_equal_approx(
			db_to_linear(AudioServer.get_bus_volume_db(music_bus_index)),
			0.43 * prototype.audio_settings.music_max_linear_volume
		)
		and prototype.pause_music_volume_value.text == "43%"
		and AudioServer.is_bus_mute(sfx_bus_index) == sfx_mute_before_music_change
		and is_equal_approx(
			AudioServer.get_bus_volume_db(sfx_bus_index),
			sfx_volume_before_music_change
		),
		"the pause-menu Music slider scales independently from SFX"
	)
	prototype.pause_music_volume_slider.value = 0.0
	_check(
		AudioServer.is_bus_mute(music_bus_index)
		and prototype.pause_music_volume_value.text == "0%",
		"setting pause-menu Music volume to zero mutes only the Music bus"
	)
	AudioServer.set_bus_volume_db(music_bus_index, original_music_volume_db)
	AudioServer.set_bus_mute(music_bus_index, original_music_mute)
	prototype.pause_music_volume_slider.set_value_no_signal(
		0.0
		if original_music_mute
		else clampf(
			db_to_linear(original_music_volume_db)
			/ prototype.audio_settings.music_max_linear_volume,
			0.0,
			1.0
		) * 100.0
	)
	prototype._update_music_volume_label()
	prototype.pause_resume_button.pressed.emit()
	_check(
		not prototype.is_pause_menu_open()
		and not prototype.pause_overlay.visible
		and not prototype.combat.simulation_paused,
		"Resume closes the pause overlay and restores gameplay simulation"
	)
	prototype.debug_advance_time(12.0)
	prototype._open_pause_menu()
	prototype.pause_restart_button.pressed.emit()
	_check(
		prototype.get_run_state() == PhaseBPrototype.RunState.RUNNING
		and is_zero_approx(prototype.get_elapsed_seconds())
		and not prototype.is_pause_menu_open()
		and not prototype.pause_overlay.visible,
		"Restart Run resets the active run and closes the pause menu"
	)
	_check(
		prototype.pause_fullscreen_button.pressed.is_connected(
			Callable(prototype, "_toggle_fullscreen")
		)
		and prototype.pause_quit_button.pressed.is_connected(
			Callable(prototype, "_quit_from_pause_menu")
		),
		"fullscreen and desktop quit actions are wired to their pause-menu buttons"
	)
	prototype._set_simulation_paused(true)
	var hunter_position := prototype.player.get_arena_position() + Vector2(90.0, 0.0)
	var hunter_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER,
		hunter_position
	)
	var observed_hit_flash := false
	var observed_damage_number := false
	for _step_index in range(180):
		prototype.combat.simulate_step(1.0 / 60.0)
		observed_hit_flash = (
			observed_hit_flash
			or prototype.combat.get_enemy_hit_flash_remaining(hunter_id) > 0.0
		)
		observed_damage_number = (
			observed_damage_number
			or prototype.combat.get_active_damage_number_count() > 0
		)
		if not prototype.combat.is_enemy_active(hunter_id):
			break
	_check(hunter_id != -1, "a pooled Hunter can be spawned")
	_check(
		not prototype.combat.is_enemy_active(hunter_id),
		"automatic Thornshot targets and kills a nearby Hunter"
	)
	_check(
		prototype.combat.thornshot_shoot_sfx != null
		and prototype.combat.get_thornshot_sfx_play_count() > 0
		and prototype.combat._thornshot_audio.bus == prototype.audio_settings.sfx_bus_name,
		"each successfully fired Thornshot plays the authored shoot SFX"
	)
	_check(
		observed_hit_flash and observed_damage_number,
		"Thornshot damage produces an enemy hit flash and a pooled floating number"
	)
	_check(prototype.combat.get_active_pickup_count() > 0, "enemy death produces pooled XP")
	for pickup_index in range(3):
		var chained_pickup = prototype.combat._pickups[pickup_index]
		chained_pickup.active = true
		chained_pickup.position = prototype.player.get_arena_position()
		chained_pickup.xp_value = 1
		chained_pickup.age = 0.0
	prototype.combat.simulate_step(0.0)
	var xp_voice_zero = prototype.combat._xp_collect_audio_voices[0]
	var xp_voice_one = prototype.combat._xp_collect_audio_voices[1]
	var xp_voice_two = prototype.combat._xp_collect_audio_voices[2]
	_check(
		prototype.combat.xp_collect_sfx != null
		and prototype.combat.get_xp_collect_sfx_play_count() == 3
		and prototype.combat.get_xp_collect_chain_count() == 3
		and is_equal_approx(xp_voice_zero.pitch_scale, 1.0)
		and xp_voice_one.pitch_scale > xp_voice_zero.pitch_scale
		and xp_voice_two.pitch_scale > xp_voice_one.pitch_scale
		and xp_voice_zero.bus == prototype.audio_settings.sfx_bus_name,
		"collecting consecutive XP circles plays an ascending pooled SFX chain"
	)
	prototype.combat.simulate_step(prototype.combat.xp_collect_pitch_reset_seconds)
	_check(
		prototype.combat.get_xp_collect_chain_count() == 0
		and is_equal_approx(prototype.combat.get_last_xp_collect_pitch_scale(), 1.0),
		"one second without collected XP resets the pitch chain"
	)
	var reset_pitch_pickup = prototype.combat._pickups[3]
	reset_pitch_pickup.active = true
	reset_pitch_pickup.position = prototype.player.get_arena_position()
	reset_pitch_pickup.xp_value = 1
	reset_pitch_pickup.age = 0.0
	prototype.combat.simulate_step(0.0)
	_check(
		is_equal_approx(prototype.combat.get_last_xp_collect_pitch_scale(), 1.0),
		"the first XP circle after the timeout plays at default pitch"
	)

	prototype.combat.reset_combat()
	var outside_range_position := (
		prototype.player.get_arena_position()
		+ Vector2(prototype.combat.thornshot_range_pixels + 150.0, 0.0)
	)
	var outside_range_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER,
		outside_range_position
	)
	prototype.combat.simulate_step(0.20)
	_check(
		outside_range_id != -1
		and prototype.combat.is_enemy_active(outside_range_id)
		and prototype.combat.get_active_projectile_count() == 0,
		"Thornshot does not acquire or fire at an enemy beyond its authored range"
	)

	prototype.combat.reset_combat()
	var thornshot_wall_source := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.475,
		prototype.territory_field.tuning.arena_size.y * 0.20
	)
	var thornshot_blocked_target := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.56,
		prototype.territory_field.tuning.arena_size.y * 0.20
	)
	var thornshot_visible_target := Vector2(
		thornshot_wall_source.x,
		prototype.territory_field.tuning.arena_size.y * 0.51
	)
	prototype.player.global_position = prototype.territory_field.to_global(thornshot_wall_source)
	var blocked_target_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER,
		thornshot_blocked_target
	)
	var visible_target_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER,
		thornshot_visible_target
	)
	var selected_visible_enemy := prototype.combat._get_nearest_enemy()
	_check(
		not prototype.territory_field.is_growth_path_clear(
			thornshot_wall_source,
			thornshot_blocked_target
		)
		and prototype.territory_field.is_growth_path_clear(
			thornshot_wall_source,
			thornshot_visible_target
		)
		and thornshot_wall_source.distance_to(thornshot_blocked_target)
		< thornshot_wall_source.distance_to(thornshot_visible_target)
		and selected_visible_enemy != null
		and selected_visible_enemy.id == visible_target_id,
		"Thornshot skips a closer enemy behind basalt and acquires the nearest visible enemy"
	)
	prototype.combat._thornshot_remaining = 0.0
	prototype.combat.simulate_step(1.0 / 60.0)
	prototype.combat._thornshot_remaining = 999.0
	for _visibility_step in range(30):
		prototype.combat.simulate_step(1.0 / 60.0)
	_check(
		prototype.combat.get_enemy_health(visible_target_id)
		< prototype.combat.hunter_profile.maximum_health
		and is_equal_approx(
			prototype.combat.get_enemy_health(blocked_target_id),
			prototype.combat.hunter_profile.maximum_health
		),
		"the fired Thornshot damages only the unobstructed target"
	)

	prototype.player.reset_player()
	prototype.combat.reset_combat()
	var original_pierce := prototype.combat.thornshot_pierce
	prototype.combat.thornshot_pierce = 2
	var shot_origin := prototype.player.get_arena_position()
	var near_enemy_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER,
		shot_origin + Vector2(100.0, 0.0)
	)
	var beyond_travel_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER,
		shot_origin + Vector2(prototype.combat.thornshot_range_pixels + 80.0, 0.0)
	)
	prototype.combat.simulate_step(0.20)
	prototype.combat._thornshot_remaining = 999.0
	for _range_step in range(36):
		prototype.combat.simulate_step(1.0 / 60.0)
	_check(
		prototype.combat.get_enemy_health(near_enemy_id)
		< prototype.combat.hunter_profile.maximum_health
		and is_equal_approx(
			prototype.combat.get_enemy_health(beyond_travel_id),
			prototype.combat.hunter_profile.maximum_health
		)
		and prototype.combat.get_active_projectile_count() == 0,
		"a piercing Thornshot expires at its range boundary instead of continuing across the arena"
	)
	prototype.combat.thornshot_pierce = original_pierce

	prototype.combat.reset_combat()
	var navigation_target := Vector2(310.0, 70.0)
	var navigation_start := Vector2(650.0, 70.0)
	prototype.player.global_position = prototype.territory_field.to_global(navigation_target)
	prototype.combat._thornshot_remaining = 999.0
	var navigating_enemy_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER,
		navigation_start
	)
	var maximum_navigation_y := navigation_start.y
	for _navigation_step in range(900):
		prototype.combat.simulate_step(1.0 / 60.0)
		var navigation_position := prototype.combat.get_enemy_position(navigating_enemy_id)
		if navigation_position.x < -90000.0:
			break
		maximum_navigation_y = maxf(maximum_navigation_y, navigation_position.y)
	var navigation_end := prototype.combat.get_enemy_position(navigating_enemy_id)
	_check(
		navigation_end.x > -90000.0
		and maximum_navigation_y > 205.0
		and navigation_end.distance_to(navigation_target)
		< navigation_start.distance_to(navigation_target) - 150.0,
		(
			"a Hunter detours through the central opening instead of sticking to the basalt ridge "
			+ "(max_y %.1f, end %.1f/%.1f, remaining %.1f)"
		) % [
			maximum_navigation_y,
			navigation_end.x,
			navigation_end.y,
			navigation_end.distance_to(navigation_target),
		]
	)

	prototype.player.reset_player()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	var catalyst_position := Vector2(700.0, 360.0)
	var original_saboteur_delay := (
		prototype.combat.saboteur_profile.first_territory_action_delay_seconds
	)
	prototype.combat.saboteur_profile.first_territory_action_delay_seconds = 0.0
	prototype.overlay.spawn_seed(catalyst_position, 10.0, 0, 1.0)
	var saboteur_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.SABOTEUR,
		catalyst_position
	)
	prototype.combat.simulate_step(0.0)
	prototype.combat.saboteur_profile.first_territory_action_delay_seconds = (
		original_saboteur_delay
	)
	_check(
		saboteur_id != -1 and prototype.overlay.get_active_seed_count() == 0,
		"a Saboteur seeks and destroys a vulnerable charging Seed"
	)

	var mature_green_position := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.235,
		prototype.territory_field.tuning.arena_size.y * 0.535
	)
	prototype.territory_field.reset_field()
	prototype.combat.reset_combat()
	var green_before_corruption := (
		prototype.territory_field.get_control_at_local(mature_green_position)
	)
	var original_corruptor_delay := (
		prototype.combat.corruptor_profile.first_territory_action_delay_seconds
	)
	prototype.combat.corruptor_profile.first_territory_action_delay_seconds = 0.0
	var corruptor_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.CORRUPTOR,
		mature_green_position
	)
	prototype.combat.simulate_step(0.0)
	prototype.combat.corruptor_profile.first_territory_action_delay_seconds = (
		original_corruptor_delay
	)
	_step_field(prototype.territory_field, 1)
	var green_after_corruption := (
		prototype.territory_field.get_control_at_local(mature_green_position)
	)
	_check(
		corruptor_id != -1
		and green_before_corruption > prototype.territory_field.tuning.ownership_threshold
		and green_after_corruption < green_before_corruption - 0.20,
		"a Corruptor converts established Green toward hostile material"
	)

	prototype.territory_field.reset_field()
	prototype.combat.reset_combat()
	var original_warden_delay := (
		prototype.combat.warden_profile.first_territory_action_delay_seconds
	)
	prototype.combat.warden_profile.first_territory_action_delay_seconds = 0.0
	var maturity_before_suppression := (
		prototype.territory_field.get_maturity_at_local(mature_green_position)
	)
	var control_before_suppression := (
		prototype.territory_field.get_control_at_local(mature_green_position)
	)
	var warden_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.WARDEN,
		mature_green_position
	)
	prototype.combat.simulate_step(0.0)
	prototype.combat.warden_profile.first_territory_action_delay_seconds = original_warden_delay
	_step_field(prototype.territory_field, 1)
	_check(
		warden_id != -1
		and prototype.territory_field.get_maturity_at_local(mature_green_position)
		< maturity_before_suppression
		and prototype.territory_field.get_control_at_local(mature_green_position)
		> prototype.territory_field.tuning.ownership_threshold
		and control_before_suppression
		> prototype.territory_field.tuning.ownership_threshold,
		"a Warden suppresses maturity without directly erasing Green control"
	)

	prototype.combat.reset_combat()
	var original_colonizer_delay := (
		prototype.combat.colonizer_profile.first_territory_action_delay_seconds
	)
	prototype.combat.colonizer_profile.first_territory_action_delay_seconds = 0.0
	var colonizer_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.COLONIZER,
		Vector2(700.0, 360.0)
	)
	prototype.combat.simulate_step(0.0)
	prototype.combat.colonizer_profile.first_territory_action_delay_seconds = (
		original_colonizer_delay
	)
	_check(
		colonizer_id != -1
		and prototype.combat.get_active_enemy_count_by_role(
			PhaseBCombatDirector.EnemyRole.COLONY_CORE
		) == 1,
		"a Colonizer establishes one destructible hostile Colony Core"
	)

	prototype.territory_field.reset_field()
	prototype.combat.reset_combat()
	var green_before_core := prototype.territory_field.get_control_at_local(mature_green_position)
	var original_core_delay := (
		prototype.combat.colony_core_profile.first_territory_action_delay_seconds
	)
	prototype.combat.colony_core_profile.first_territory_action_delay_seconds = 0.0
	var colony_core_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.COLONY_CORE,
		mature_green_position
	)
	prototype.combat.simulate_step(0.0)
	prototype.combat.colony_core_profile.first_territory_action_delay_seconds = original_core_delay
	_step_field(prototype.territory_field, 1)
	_check(
		colony_core_id != -1
		and prototype.combat.get_enemy_position(colony_core_id).is_equal_approx(
			mature_green_position
		)
		and prototype.territory_field.get_control_at_local(mature_green_position)
		< green_before_core,
		"an anchored Colony Core continuously roots hostile territory around itself"
	)

	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	var kill_position := Vector2(700.0, 360.0)
	for index in range(prototype.spore_director.get_seed_kill_threshold()):
		var enemy_id := prototype.combat.spawn_enemy(
			PhaseBCombatDirector.EnemyRole.HUNTER,
			kill_position + Vector2(float(index) * 3.0, 0.0)
		)
		prototype.combat.debug_damage_enemy(enemy_id, 10000.0)
	_check(
		prototype.overlay.get_active_seed_count() == 1,
		"the configured kill threshold creates one Seed at a death site"
	)

	prototype.territory_field.reset_field()
	prototype.overlay.clear_effects()
	var hostile_seed_position := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.82,
		prototype.territory_field.tuning.arena_size.y * 0.52
	)
	var hostile_before := prototype.territory_field.get_control_at_local(hostile_seed_position)
	var explosion_count_before_seed := prototype.combat.get_plant_explosion_sfx_play_count()
	prototype.spore_director.on_seed_germinated(hostile_seed_position, 0)
	_check(
		prototype.combat.plant_explosion_sfx != null
		and is_equal_approx(
			db_to_linear(prototype.combat._plant_explosion_audio.volume_db),
			0.50
		)
		and prototype.combat._plant_explosion_audio.bus
		== prototype.audio_settings.sfx_bus_name
		and prototype.combat.get_plant_explosion_sfx_play_count()
		== explosion_count_before_seed + 1,
		"Seed germination plays the half-volume explosion SFX on the capped bus"
	)
	_step_field(prototype.territory_field, 18)
	var hostile_after := prototype.territory_field.get_control_at_local(hostile_seed_position)
	_check(
		hostile_before < -prototype.territory_field.tuning.ownership_threshold
		and hostile_after > prototype.territory_field.tuning.ownership_threshold,
		"a combat Seed germinates Green inside strong hostile territory"
	)

	# Seeds colonise, Blooms displace. A Seed must be able to claim ground detached
	# from Plant; a Bloom in that same spot must not.
	prototype.territory_field.reset_field()
	var detached_spot := hostile_seed_position
	var detached_before := prototype.territory_field.get_control_at_local(detached_spot)
	prototype.territory_field.queue_bloom(detached_spot, 4.0, 4.0, 4.0, 1.0)
	prototype.territory_field._apply_pending_commands()
	var detached_bloom_delta := (
		prototype.territory_field.get_control_at_local(detached_spot) - detached_before
	)
	prototype.territory_field.reset_field()
	prototype.territory_field.queue_seed_growth(detached_spot, 1.0, 1.0, 1.0, 1.0)
	prototype.territory_field._apply_pending_commands()
	var detached_seed_delta := (
		prototype.territory_field.get_control_at_local(detached_spot) - detached_before
	)
	_check(
		detached_seed_delta > 0.0
		and detached_bloom_delta <= 0.0001,
		"a Seed adds mass to ground detached from Plant while a Bloom adds none"
	)

	prototype.territory_field.reset_field()
	var supported_origin := prototype.territory_field.find_player_frontier_near(
		detached_spot
	)
	var supported_before := prototype.territory_field.get_player_percent()
	prototype.territory_field.queue_bloom(supported_origin)
	_step_field(prototype.territory_field, 8)
	var supported_after := prototype.territory_field.get_player_percent()
	prototype.territory_field.reset_field()
	_step_field(prototype.territory_field, 8)
	var unbloomed_after := prototype.territory_field.get_player_percent()
	_check(
		supported_origin.x >= 0.0
		and supported_after > unbloomed_after,
		"a Bloom rooted on the frontier drives owned territory outward"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.BLOOM,
		PhaseBProgression.PathId.SPORE
	)
	prototype.overlay.clear_effects()
	prototype.combat.reset_combat()
	prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER,
		Vector2(
			prototype.territory_field.tuning.arena_size.x * 0.86,
			prototype.territory_field.tuning.arena_size.y * 0.5
		)
	)
	prototype.bloom_director._bloom_remaining = 0.0
	prototype.bloom_director.advance(0.016)
	var planted_bloom := prototype.overlay.get_active_bloom_count() > 0
	var bloom_on_owned_ground := false
	if planted_bloom:
		var bloom_spot := prototype.overlay.get_first_bloom_position()
		bloom_on_owned_ground = (
			prototype.territory_field.get_control_at_local(bloom_spot)
			> prototype.territory_field.tuning.ownership_threshold * 0.5
			or prototype.territory_field.find_player_frontier_near(
				bloom_spot
			).distance_to(bloom_spot) < 24.0
		)
	_check(
		planted_bloom and bloom_on_owned_ground,
		"an automatic Bloom charges on the player's own frontier rather than at the enemy"
	)
	_check(
		prototype.bloom_director.bloom_windup_seconds
		< prototype.territory_field.tuning.seed_charge_seconds,
		"a Bloom uses a shorter charge than a Seed's germination delay"
	)
	prototype.overlay.clear_effects()
	prototype.combat.reset_combat()

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.progression._upgrade_offer_cursor = (
		PhaseBProgression.UpgradeId.BRAMBLE_ENTANGLEMENT
	)
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var pre_path_upgrade_options := prototype.progression.get_pending_upgrade_options()
	var pre_path_lines: Array[int] = []
	var pre_path_paths: Array[int] = []
	for option_id in pre_path_upgrade_options:
		if not pre_path_lines.has(option_id):
			pre_path_lines.append(option_id)
		var option_path := prototype.progression._get_upgrade_path(option_id)
		if not pre_path_paths.has(option_path):
			pre_path_paths.append(option_path)
	_check(
		pre_path_upgrade_options.size() == 3
		and pre_path_lines.size() == 3
		and pre_path_paths.size() >= 2
		and pre_path_upgrade_options.has(
			PhaseBProgression.UpgradeId.BRAMBLE_ENTANGLEMENT
		),
		"the opening draft offers three distinct lines spread across every path"
	)

	var committing_option := PhaseBProgression.UpgradeId.BRAMBLE_ENTANGLEMENT
	var committing_index := pre_path_upgrade_options.find(committing_option)
	var committed_path_preview := prototype.progression.get_upgrade_committed_path(
		committing_option
	)
	prototype._choose_displayed_option(committing_index)
	_check(
		committed_path_preview == PhaseBProgression.PathId.BRAMBLE
		and prototype.progression.primary_path == PhaseBProgression.PathId.BRAMBLE
		and prototype.progression.has_path(PhaseBProgression.PathId.BRAMBLE)
		and prototype.territory_field.is_bramble_enabled()
		and not prototype.progression.has_secondary_path(),
		"taking a path line before the milestone commits that path as the primary"
	)
	prototype.debug_advance_time(prototype.wave_director.primary_path_choice_seconds)
	_check(
		not prototype.progression.has_pending_path_choice()
		and prototype.progression.primary_path == PhaseBProgression.PathId.BRAMBLE,
		"an auto-committed run is never asked to choose its primary path again"
	)
	prototype.debug_advance_time(
		prototype.wave_director.secondary_path_choice_seconds
		- prototype.get_elapsed_seconds()
	)
	var auto_secondary_options := prototype.progression.get_pending_path_options()
	_check(
		not prototype.progression.is_pending_primary_path_choice()
		and auto_secondary_options.size() == PhaseBProgression.PathId.size() - 1
		and not auto_secondary_options.has(PhaseBProgression.PathId.BRAMBLE),
		"the secondary milestone still offers the two remaining paths after an auto-commit"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	_take_offered_upgrade(prototype, PhaseBProgression.UpgradeId.BLOOM_FREQUENCY)
	var auto_primary := prototype.progression.primary_path
	_take_offered_upgrade(prototype, PhaseBProgression.UpgradeId.BRAMBLE_ENTANGLEMENT)
	_check(
		auto_primary == PhaseBProgression.PathId.BLOOM
		and prototype.progression.primary_path == PhaseBProgression.PathId.BLOOM
		and prototype.progression.secondary_path == PhaseBProgression.PathId.BRAMBLE
		and prototype.territory_field.is_bramble_enabled(),
		"a second uncommitted path line fills the secondary slot without waiting for its milestone"
	)
	prototype.debug_advance_time(
		prototype.wave_director.secondary_path_choice_seconds + 1.0
	)
	_check(
		not prototype.progression.has_pending_path_choice()
		and prototype.progression.has_secondary_path(),
		"a fully committed run is never asked to choose a path at either milestone"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var universal_options := prototype.progression.get_pending_upgrade_options()
	var universal_index := 0
	for option_index in range(universal_options.size()):
		if (
			prototype.progression._get_upgrade_path(universal_options[option_index])
			== PhaseBProgression.UNSELECTED_PATH
		):
			universal_index = option_index
			break
	prototype._choose_displayed_option(universal_index)
	_check(
		not prototype.progression.has_primary_path(),
		"taking a universal line leaves the path commitment open"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	var authored_rerolls := prototype.progression.rerolls_per_run
	_check(
		prototype.progression.rerolls_remaining == authored_rerolls
		and authored_rerolls > 0,
		"a fresh run starts with its authored upgrade-draft rerolls (%d)"
			% authored_rerolls
	)
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var first_roll := prototype.progression.get_pending_upgrade_options()
	var reroll_worked := prototype.progression.reroll_upgrade_choice()
	var second_roll := prototype.progression.get_pending_upgrade_options()
	var reroll_changed_offer := false
	for option_id in second_roll:
		if not first_roll.has(option_id):
			reroll_changed_offer = true
	_check(
		reroll_worked
		and reroll_changed_offer
		and second_roll.size() == first_roll.size()
		and prototype.progression.rerolls_remaining == authored_rerolls - 1
		and prototype.progression.current_level == 2
		and prototype.choice_reroll_button.visible
		and prototype.choice_reroll_button.text
			== "REROLL  (%d LEFT)" % (authored_rerolls - 1),
		"a reroll redraws the same draft for a different offer without spending a level"
	)

	# A reroll must actually change the offer. Stepping the cursor by one can land
	# on the same spread, which is what made the button look dead.
	var reroll_changes := 0
	var reroll_attempts := 0
	for _reroll_probe in range(prototype.progression.rerolls_remaining):
		var before_offer := prototype.progression.get_pending_upgrade_options()
		if not prototype.progression.reroll_upgrade_choice():
			break
		reroll_attempts += 1
		var after_offer := prototype.progression.get_pending_upgrade_options()
		var differs := false
		for option_id in after_offer:
			if before_offer.find(option_id) == -1:
				differs = true
		reroll_changes += 1 if differs else 0
	_check(
		reroll_attempts > 0
		and reroll_changes == reroll_attempts
		and not prototype.progression.get_pending_upgrade_options().is_empty(),
		"every spent reroll returns a genuinely different offer"
	)
	for _spend_reroll in range(authored_rerolls - 1):
		prototype.progression.reroll_upgrade_choice()
	var exhausted_reroll := prototype.progression.reroll_upgrade_choice()
	_check(
		not exhausted_reroll
		and prototype.progression.rerolls_remaining == 0
		and prototype.choice_reroll_button.disabled
		and not prototype.progression.get_pending_upgrade_options().is_empty(),
		"a run spends exactly its authored rerolls and keeps its offer once they are gone"
	)
	prototype._choose_displayed_option(0)
	_check(
		not prototype.choice_reroll_button.visible,
		"the reroll control disappears with the draft panel"
	)
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	_check(
		prototype.progression.rerolls_remaining == prototype.progression.rerolls_per_run,
		"restarting a run restores every reroll"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	var root_lines := PackedInt32Array([
		PhaseBProgression.UpgradeId.ROOT_MATURATION,
		PhaseBProgression.UpgradeId.ROOT_BIOMASS_YIELD,
		PhaseBProgression.UpgradeId.ROOT_MATURE_STRENGTH,
		PhaseBProgression.UpgradeId.ROOT_POTENCY,
	])
	var root_lines_belong := true
	for line_id in root_lines:
		root_lines_belong = (
			root_lines_belong
			and prototype.progression._get_upgrade_path(line_id)
			== PhaseBProgression.PathId.ROOT
		)
	_check(
		root_lines_belong and root_lines.size() == 4,
		"Root contributes its four GDD lines to the Plant roster"
	)

	prototype.progression.reset_progression()
	prototype.progression.offer_bramble_path = false
	var narrowed_milestone := prototype.progression.request_primary_path_choice()
	var narrowed_path_options := prototype.progression.get_pending_path_options()
	var switched_off_line_draftable := prototype.progression._is_upgrade_draftable(
		PhaseBProgression.UpgradeId.BRAMBLE_ENTANGLEMENT
	)
	var universal_line_still_draftable := prototype.progression._is_upgrade_draftable(
		PhaseBProgression.UpgradeId.THORNSHOT_POWER
	)
	prototype.progression.offer_bramble_path = true
	prototype.progression.reset_progression()
	_check(
		narrowed_milestone
		and not narrowed_path_options.has(PhaseBProgression.PathId.BRAMBLE)
		and narrowed_path_options.size() == PhaseBProgression.PathId.size() - 1
		and not switched_off_line_draftable
		and universal_line_still_draftable
		and prototype.progression._is_upgrade_draftable(
			PhaseBProgression.UpgradeId.BRAMBLE_ENTANGLEMENT
		),
		"a path switched off in the inspector leaves the milestone and every draft"
	)
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false

	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.ROOT,
		PhaseBProgression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	var root_base_maturation: float = prototype.territory_field.tuning.maturation_per_second
	var root_base_biomass := prototype.root_director.get_biomass_yield_multiplier()
	var root_base_resistance := prototype.territory_field.get_mature_resistance_multiplier()
	var root_base_network := prototype.root_director.get_network_bonus()
	for line_id in root_lines:
		prototype.progression._upgrade_levels[line_id] = 3
	prototype._apply_progression_modifiers()
	_check(
		prototype.territory_field.tuning.maturation_per_second > root_base_maturation
		and prototype.root_director.get_biomass_yield_multiplier() > root_base_biomass
		and prototype.territory_field.get_mature_resistance_multiplier()
		> root_base_resistance
		and prototype.territory_field.tuning.regeneration_per_second > 0.0
		and prototype.root_director.get_network_bonus() > root_base_network,
		"Root's lines raise maturation, Biomass yield, Mature Strength, and Root Potency"
	)
	_check(
		root_base_network > 0.0
		and prototype.root_director.get_network_bonus()
		> prototype.root_director.base_network_bonus,
		"Root Potency deepens the Root Network amplification Root already supplies"
	)

	prototype.progression.tick_biomass(
		1.0,
		20.0,
		10.0,
		prototype.root_director.get_biomass_yield_multiplier()
	)
	var root_yield_income := prototype.progression.biomass_per_second
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.SPORE,
		PhaseBProgression.PathId.BLOOM
	)
	prototype.progression.tick_biomass(
		1.0,
		20.0,
		10.0,
		prototype.root_director.get_biomass_yield_multiplier()
	)
	_check(
		root_yield_income > prototype.progression.biomass_per_second,
		"Biomass Yield pays out only while the Root path is held"
	)

	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.ROOT,
		PhaseBProgression.PathId.SPORE
	)
	for line_id in root_lines:
		prototype.progression._upgrade_levels[line_id] = 5
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	var healing_cells := _find_player_frontier_cells(prototype.territory_field, 1)
	var healing_index := (
		healing_cells[0].y * prototype.territory_field.tuning.field_size.x
		+ healing_cells[0].x
	)
	prototype.territory_field._control[healing_index] = 0.30
	prototype.territory_field.step_simulation()
	var regenerated: float = prototype.territory_field._control[healing_index]
	prototype.territory_field.tuning.regeneration_per_second = 0.0
	prototype.territory_field.reset_field()
	prototype.territory_field._control[healing_index] = 0.30
	prototype.territory_field.step_simulation()
	var unregenerated: float = prototype.territory_field._control[healing_index]
	prototype._apply_progression_modifiers()
	_check(
		regenerated > unregenerated,
		"Regeneration heals damaged Green that the player still holds"
	)

	prototype.territory_field.reset_field()
	var root_mature_cell := _find_player_frontier_cells(prototype.territory_field, 1)[0]
	var root_mature_index := (
		root_mature_cell.y * prototype.territory_field.tuning.field_size.x + root_mature_cell.x
	)
	var root_mature_spot := prototype.territory_field.cell_to_local(Vector2(root_mature_cell))
	prototype.territory_field._maturity[root_mature_index] = 1.0
	var root_mature_control_before: float = prototype.territory_field._control[root_mature_index]
	prototype.territory_field.queue_erosion(root_mature_spot, 0.45, 0.5)
	prototype.territory_field._apply_pending_commands()
	var hardened_loss := (
		root_mature_control_before - prototype.territory_field._control[root_mature_index]
	)
	prototype.territory_field.set_mature_resistance_multiplier(1.0)
	prototype.territory_field.reset_field()
	prototype.territory_field._maturity[root_mature_index] = 1.0
	prototype.territory_field.queue_erosion(root_mature_spot, 0.45, 0.5)
	prototype.territory_field._apply_pending_commands()
	var plain_loss := (
		root_mature_control_before - prototype.territory_field._control[root_mature_index]
	)
	prototype._apply_progression_modifiers()
	_check(
		hardened_loss > 0.0 and hardened_loss < plain_loss,
		"Mature Resistance hardens settled Plant against erosion"
	)

	_check(
		prototype.progression.get_pair_evolution_id()
		== PhaseBProgression.EvolutionId.SEED_BANK,
		"Spore plus Root pairs into Seed Bank"
	)
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.BLOOM,
		PhaseBProgression.PathId.ROOT
	)
	_check(
		prototype.progression.get_pair_evolution_id()
		== PhaseBProgression.EvolutionId.FLOWERING_SEASON,
		"Bloom plus Root pairs into Flowering Season"
	)
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.BRAMBLE,
		PhaseBProgression.PathId.ROOT
	)
	_check(
		prototype.progression.get_pair_evolution_id()
		== PhaseBProgression.EvolutionId.OLD_GROWTH,
		"Bramble plus Root pairs into Old Growth"
	)

	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.SPORE,
		PhaseBProgression.PathId.ROOT
	)
	prototype.progression.debug_complete_evolution_requirements()
	var seed_bank_granted := prototype.progression.grant_evolution_if_ready()
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	_step_field(prototype.territory_field, 2)
	for mature_index in range(prototype.territory_field._maturity.size()):
		if prototype.territory_field._player_frontier_mask[mature_index] != 0:
			prototype.territory_field._maturity[mature_index] = 1.0
	prototype.overlay.clear_effects()
	prototype.combat.reset_combat()
	# Seed Bank banks dormant Seeds and releases them in one Germination Season.
	prototype.spore_director._seed_bank_storage = 0.0
	prototype.spore_director.advance(0.016)
	var banked_without_season := prototype.overlay.get_active_seed_count()
	prototype.spore_director._seed_bank_storage = (
		prototype.evolutions.germination_season_threshold
	)
	prototype.spore_director.advance(0.016)
	_check(
		seed_bank_granted
		and prototype.progression.active_evolution
		== PhaseBProgression.EvolutionId.SEED_BANK
		and banked_without_season == 0
		and prototype.overlay.get_active_seed_count() > 1
		and prototype.spore_director.get_seed_bank_storage() < 1.0,
		"a Germination Season empties the Seed bank into many simultaneous Seeds"
	)
	prototype.overlay.clear_effects()

	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.BLOOM,
		PhaseBProgression.PathId.ROOT
	)
	prototype.progression.debug_complete_evolution_requirements()
	var flowering_granted := prototype.progression.grant_evolution_if_ready()
	prototype._apply_progression_modifiers()
	prototype.bloom_director._flowering_charge = (
		prototype.evolutions.flowering_season_charge_required
	)
	prototype.bloom_director.advance(0.016)
	# The bloom count is an authored balance value, so the check is that the stored
	# charge is spent on the flowering the run actually authors, not on a fixed number.
	var authored_flowering_blooms := prototype.evolutions.flowering_season_bloom_count
	var flowering_blooms := prototype.overlay.get_active_bloom_count()
	_check(
		flowering_granted
		and authored_flowering_blooms > 0
		and flowering_blooms > 0
		and flowering_blooms <= authored_flowering_blooms
		and prototype.bloom_director.get_flowering_charge() < 1.0,
		"Flowering Season spends its stored charge on its authored flowering (%d of %d Blooms)"
			% [flowering_blooms, authored_flowering_blooms]
	)
	prototype.overlay.clear_effects()

	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.BRAMBLE,
		PhaseBProgression.PathId.ROOT
	)
	prototype.progression.debug_complete_evolution_requirements()
	var old_growth_granted := prototype.progression.grant_evolution_if_ready()
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	prototype.combat.reset_combat()
	prototype.combat._thornshot_remaining = 999.0
	prototype.combat.set_bramble_modifiers(true, 0.30, 1.0, 0.0, 4.0, 0.0, true)
	var field_width_og := prototype.territory_field.tuning.field_size.x
	var interior_index := _find_deep_owned_cell(
		prototype.territory_field,
		prototype.combat.bramble_frontier_band_pixels
	)
	var interior_spot := prototype.territory_field.cell_to_local(
		Vector2(interior_index % field_width_og, interior_index / field_width_og)
	)
	# Fresh interior is hazardous but never wakes the Root Network.
	prototype.territory_field._maturity[interior_index] = 0.20
	prototype.territory_field._territory_age[interior_index] = 0.0
	var fresh_enemy := _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.HUNTER,
		interior_spot
	)
	fresh_enemy.entanglement = 1.0
	var fresh_health_before := fresh_enemy.health
	var eruptions_before := prototype.combat.get_active_root_eruption_count()
	prototype.combat.simulate_step(0.0)
	var fresh_interior_damage := fresh_health_before - fresh_enemy.health
	var fresh_eruptions := (
		prototype.combat.get_active_root_eruption_count() - eruptions_before
	)
	prototype.combat.reset_combat()
	prototype.combat._thornshot_remaining = 999.0

	# Mature interior erupts once the enemy standing on it is heavily Entangled.
	prototype.territory_field._maturity[interior_index] = 1.0
	prototype.territory_field._territory_age[interior_index] = (
		prototype.territory_field.tuning.age_reference_seconds
	)
	var mature_enemy := _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.HUNTER,
		interior_spot
	)
	mature_enemy.entanglement = 0.0
	prototype.combat.simulate_step(0.0)
	var untangled_eruptions := prototype.combat.get_active_root_eruption_count()
	mature_enemy.entanglement = 1.0
	mature_enemy.bramble_damage_remaining = 0.0
	mature_enemy.bramble_eruption_remaining = 0.0
	var mature_health_before := mature_enemy.health
	prototype.combat.simulate_step(0.0)
	var mature_interior_damage := mature_health_before - mature_enemy.health
	_check(
		old_growth_granted
		and prototype.territory_field.is_old_growth_enabled()
		and fresh_interior_damage > 0.0
		and fresh_eruptions == 0
		and untangled_eruptions == 0
		and prototype.combat.get_active_root_eruption_count() > untangled_eruptions
		and mature_interior_damage > fresh_interior_damage,
		"Old Growth erupts under heavily Entangled enemies on ancient ground alone"
	)

	# A kill inside the Root Network wakes the ground under the next enemy.
	prototype.combat.reset_combat()
	prototype.combat._thornshot_remaining = 999.0
	var cascade_enemy: PhaseBCombatDirector.EnemyState = _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.HUNTER,
		interior_spot
	)
	cascade_enemy.health = 1.0
	prototype.combat._erupt_root_network(interior_spot, 0)
	var queued_cascade := false
	for pending in prototype.combat._pending_eruptions:
		queued_cascade = queued_cascade or pending.active
	# Kill-chaining is the Ancient Fury Root Cascade rank, not base Old Growth.
	var base_chain_queued := false
	for pending in prototype.combat._pending_eruptions:
		base_chain_queued = base_chain_queued or pending.active
	_check(
		not base_chain_queued,
		"base Old Growth erupts without chaining until Ancient Fury buys the cascade"
	)
	prototype.progression._upgrade_levels[
		PhaseBProgression.UpgradeId.EVOLUTION_ANCIENT_FURY
	] = 3
	prototype._apply_progression_modifiers()
	prototype.combat.reset_combat()
	prototype.combat._thornshot_remaining = 999.0
	cascade_enemy = _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.HUNTER,
		interior_spot
	)
	cascade_enemy.health = 1.0
	prototype.combat._erupt_root_network(interior_spot, 0)
	queued_cascade = false
	for pending in prototype.combat._pending_eruptions:
		queued_cascade = queued_cascade or pending.active
	var cascade_eruptions_before := prototype.combat.get_active_root_eruption_count()
	# Clear the retrigger guard first: the eruption just fired above already armed
	# it, and the point of this check is what a fresh burst does.
	prototype.combat._old_growth_sfx_retrigger_remaining = 0.0
	var old_growth_cue_before := prototype.combat.get_old_growth_sfx_play_count()
	# Fire several eruptions inside one frame: the cue must swell once, not once
	# per eruption, or a cascade turns into a stack of identical voices.
	var eruptions_this_cascade := 5
	for _cascade_index in range(eruptions_this_cascade):
		prototype.combat._erupt_root_network(interior_spot, 1)
	var old_growth_cue_count := prototype.combat.get_old_growth_sfx_play_count()
	prototype.combat.simulate_step(
		prototype.combat.old_growth_eruption_chain_delay_seconds + 0.01
	)
	_check(
		not cascade_enemy.active
		and queued_cascade
		and prototype.combat.get_active_root_eruption_count() > cascade_eruptions_before,
		"a root eruption kill chains another eruption through the Root Network"
	)
	_check(
		prototype.combat.old_growth_sfx != null
		and old_growth_cue_count == old_growth_cue_before + 1
		and eruptions_this_cascade > 1,
		"the Root Network erupting plays its cue, and a cascade swells once rather than per eruption"
	)

	prototype.combat.set_bramble_modifiers(true, 0.30, 1.0, 0.0, 4.0, 0.0, false)
	prototype.combat.reset_combat()
	var disabled_enemy := _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.HUNTER,
		interior_spot
	)
	disabled_enemy.entanglement = 1.0
	var disabled_eruptions_before := prototype.combat.get_active_root_eruption_count()
	prototype.combat.simulate_step(0.0)
	_check(
		prototype.combat.get_active_root_eruption_count() == disabled_eruptions_before,
		"Mature ground never erupts for a run that has not evolved Old Growth"
	)

	# The Evolution consolidates the pairing into one slot and frees a third.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.SPORE,
		PhaseBProgression.PathId.ROOT
	)
	var slots_before_evolution := prototype.progression.get_upgrade_slot_count()
	var tertiary_before_evolution := prototype.progression.is_tertiary_path_available()
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	var evolution_before_support := prototype.progression.active_evolution
	var offered_support := prototype.progression.request_tertiary_path_choice()
	var support_options := prototype.progression.get_pending_path_options()
	var support_excludes_pairing := (
		not support_options.has(PhaseBProgression.PathId.SPORE)
		and not support_options.has(PhaseBProgression.PathId.ROOT)
	)
	_check(
		not tertiary_before_evolution
		and prototype.progression.is_tertiary_path_available()
		and offered_support
		and support_options.size() == PhaseBProgression.PathId.size() - 2
		and support_excludes_pairing,
		"claiming the Evolution frees a support slot offering only the unused paths"
	)
	prototype.progression.choose_path(PhaseBProgression.PathId.BRAMBLE)
	_check(
		prototype.progression.tertiary_path == PhaseBProgression.PathId.BRAMBLE
		and prototype.progression.has_path(PhaseBProgression.PathId.BRAMBLE)
		and not prototype.progression.is_evolution_path(PhaseBProgression.PathId.BRAMBLE)
		and prototype.progression.active_evolution == evolution_before_support
		and prototype.progression.get_pair_evolution_id() == evolution_before_support
		and not prototype.progression.is_tertiary_path_available(),
		"the support path joins the build without re-rolling or adding an Evolution"
	)
	_check(
		prototype.progression.get_upgrade_slot_count()
		== slots_before_evolution + prototype.progression.evolution_bonus_upgrade_slots
		and prototype.progression.evolution_bonus_upgrade_slots > 0,
		"evolving widens the upgrade slots instead of replacing the lines already taken"
	)
	var support_line_draftable := prototype.progression._is_upgrade_draftable(
		PhaseBProgression.UpgradeId.BRAMBLE_ENTANGLEMENT
	)
	var unused_line_draftable := prototype.progression._is_upgrade_draftable(
		PhaseBProgression.UpgradeId.BLOOM_FORCE
	)
	_check(
		support_line_draftable and not unused_line_draftable,
		"drafts narrow to the support path once it is chosen"
	)

	# Thornshot Volley buys coverage: a wider volley takes different targets and
	# only doubles up when there are fewer enemies in range than shots.
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	prototype.combat.reset_combat()
	var volley_origin := prototype.player.get_arena_position()
	var single_target_count := prototype.combat.get_thornshot_target_count()
	prototype.progression._upgrade_levels[
		PhaseBProgression.UpgradeId.THORNSHOT_VOLLEY
	] = 2
	prototype._apply_progression_modifiers()
	var widened_target_count := prototype.combat.get_thornshot_target_count()
	for volley_index in range(3):
		prototype.combat.spawn_enemy(
			PhaseBCombatDirector.EnemyRole.HUNTER,
			volley_origin + Vector2(40.0 + 12.0 * float(volley_index), 0.0)
		)
	prototype.combat._thornshot_remaining = 0.0
	prototype.combat.simulate_step(0.0)
	var volley_projectiles := prototype.combat.get_active_projectile_count()
	var volley_cues := prototype.combat.get_thornshot_sfx_play_count()
	prototype.combat._collect_thornshot_targets(widened_target_count)
	var distinct_targets: Array[int] = []
	for volley_target in prototype.combat._thornshot_targets:
		if not distinct_targets.has(volley_target.id):
			distinct_targets.append(volley_target.id)
	prototype.combat.reset_combat()
	prototype.combat.spawn_enemy(PhaseBCombatDirector.EnemyRole.HUNTER, volley_origin + Vector2(40.0, 0.0))
	prototype.combat._collect_thornshot_targets(widened_target_count)
	var lone_enemy_shots := prototype.combat._thornshot_targets.size()
	prototype.combat.reset_combat()
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	_check(
		single_target_count == 1
		and widened_target_count == 3
		and volley_projectiles == widened_target_count
		and volley_cues == 1
		and distinct_targets.size() == 3
		and lone_enemy_shots == widened_target_count,
		"Thornshot Volley fires one shot per distinct target and one cue per volley"
	)

	# Every Evolution carries exactly one optional upgrade line, offered only to the
	# run that claimed that Evolution. All ten pairings now have one: the four Pruning
	# pairings used to fall through to no line at all, which left those runs with
	# nothing to draft and their Evolution stuck at its base effect for the whole run.
	# The count is asserted against the enum rather than written down, so a pairing
	# added later cannot quietly ship without a line.
	var evolution_lines_are_paired := true
	var evolution_line_ids := PackedInt32Array()
	for evolution_id in range(1, PhaseBProgression.EvolutionId.size()):
		var line_id := PhaseBEvolutions.get_evolution_upgrade_id(evolution_id)
		if line_id < 0:
			continue
		evolution_lines_are_paired = (
			evolution_lines_are_paired
			and PhaseBEvolutions.get_upgrade_evolution(line_id) == evolution_id
			and not evolution_line_ids.has(line_id)
		)
		evolution_line_ids.append(line_id)
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.BLOOM,
		PhaseBProgression.PathId.BRAMBLE
	)
	var line_draftable_unevolved := prototype.progression._is_upgrade_draftable(
		PhaseBProgression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD
	)
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	var own_line_draftable := prototype.progression._is_upgrade_draftable(
		PhaseBProgression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD
	)
	var other_line_draftable := prototype.progression._is_upgrade_draftable(
		PhaseBProgression.UpgradeId.EVOLUTION_ANCIENT_FURY
	)
	prototype.progression._upgrade_levels[
		PhaseBProgression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD
	] = 2
	var rank_level := prototype.progression.get_evolution_upgrade_level()
	var rank_three_text := prototype.progression.get_upgrade_description(
		PhaseBProgression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD
	)
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	_check(
		evolution_lines_are_paired
		and evolution_line_ids.size() == PhaseBProgression.EvolutionId.size() - 1
		and not line_draftable_unevolved
		and own_line_draftable
		and not other_line_draftable
		and rank_level == 2
		and rank_three_text.contains("Barbed Blast"),
		"each Evolution has one optional line, drafted only by the run holding it"
	)

	# A line is not implemented because it exists in the enum. Every rank of every line
	# has to name what it does, because that text is what the draft shows the player, and
	# a blank rank is a rank nobody wrote.
	var blank_ranks := PackedStringArray()
	for evolution_id in range(1, PhaseBProgression.EvolutionId.size()):
		var line_id := PhaseBEvolutions.get_evolution_upgrade_id(evolution_id)
		if line_id < 0:
			continue
		for rank in range(1, prototype.progression.maximum_upgrade_level + 1):
			if prototype.evolutions.get_evolution_upgrade_rank_description(
				line_id, rank
			).is_empty():
				blank_ranks.append("%s r%d" % [
					PhaseBProgression.get_upgrade_name(line_id),
					rank,
				])
	_check(
		blank_ranks.is_empty(),
		"every Evolution rank says what it does (%s)" % (
			"all named" if blank_ranks.is_empty() else ", ".join(blank_ranks)
		)
	)

	# Spore Burst: germination itself has to hurt. Checked by damage rather than by kills
	# so the check survives any retune of how hard it hits.
	prototype.progression.reset_progression()
	prototype.combat.reset_combat()
	var burst_seat := prototype.player.get_arena_position()
	var burst_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER,
		burst_seat + Vector2(18.0, 0.0)
	)
	var burst_full := prototype.combat.get_enemy_health(burst_id)
	prototype.spore_director.on_seed_germinated(burst_seat, 0)
	var burst_unrelicked := prototype.combat.get_enemy_health(burst_id)
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.SPORE_BURST] = 1
	prototype.spore_director.on_seed_germinated(burst_seat, 0)
	var burst_relicked := prototype.combat.get_enemy_health(burst_id)
	_check(
		burst_id >= 0
		and is_equal_approx(burst_unrelicked, burst_full)
		and burst_relicked < burst_unrelicked,
		"Spore Burst makes germination damage what is standing in it (%.1f to %.1f)"
			% [burst_unrelicked, burst_relicked]
	)
	prototype.combat.reset_combat()
	prototype.progression.reset_progression()

	# Bloom splatter: one eruption resolves into a central splat, gameplay globs,
	# satellites, and streaks rather than into a single expanding circle.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.BLOOM,
		PhaseBProgression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	var splatter_origin := _find_player_frontier(prototype.territory_field)
	var bloom := prototype.bloom_director
	bloom.reset_director()
	prototype.territory_field._commands.clear()
	bloom.on_bloom_detonated(splatter_origin, 0)
	# The central surge is immediate; everything else is now in the air.
	var immediate_kinds := {}
	for command in prototype.territory_field._commands:
		immediate_kinds[command.kind] = int(immediate_kinds.get(command.kind, 0)) + 1
	var central_splats := int(immediate_kinds.get(
		TerritoryField.TerritoryCommand.Kind.BLOOM, 0
	))
	var splats_before_flight := int(immediate_kinds.get(
		TerritoryField.TerritoryCommand.Kind.SPLAT, 0
	))
	var globs_in_flight := bloom.get_active_glob_count()
	for _flight_step in range(120):
		bloom.advance(1.0 / 60.0)
	var queued_kinds := {}
	for command in prototype.territory_field._commands:
		queued_kinds[command.kind] = int(queued_kinds.get(command.kind, 0)) + 1
	var thrown_splats := int(queued_kinds.get(
		TerritoryField.TerritoryCommand.Kind.SPLAT, 0
	))
	_check(
		central_splats == 1
		and globs_in_flight > 1
		and splats_before_flight == 0
		and thrown_splats > 1
		and bloom.get_active_glob_count() == 0
		and prototype.overlay.get_active_splatter_count() == 1,
		"a Bloom throws its material and the splats are laid down where it lands"
	)

	# The point of throwing it: what the paint crosses decides where it ends up. The
	# same throw into a thick invasion falls short of one across the run's own Green.
	var field := prototype.territory_field
	var lane_y := field.tuning.arena_size.y * 0.5
	var green_origin := Vector2(field.tuning.arena_size.x * 0.12, lane_y)
	var hostile_origin := Vector2(field.tuning.arena_size.x * 0.60, lane_y)
	_paint_lane(field, green_origin, 1.0)
	_paint_lane(field, hostile_origin, -1.0)
	field.recalculate_metrics_now()

	var green_distance := _throw_one_glob(bloom, green_origin)
	var hostile_distance := _throw_one_glob(bloom, hostile_origin)
	_check(
		green_distance > 0.0
		and hostile_distance > 0.0
		and green_distance > hostile_distance * 1.15,
		"thrown material carries further over the run's own Green than into hostile ground"
	)

	# Paint does not come apart into equal lumps. Drag acts on a droplet's
	# cross-section and is resisted by its Mass, so the fine mist leaves fastest and
	# stops almost at once while the heavy globs lumber out and carry.
	var mist_speed := 0.0
	var mist_range := 0.0
	var lump_speed := 0.0
	var lump_range := 0.0
	for entry in [[3.0, 0.108], [22.0, 42.592]]:
		for glob in bloom._globs:
			glob.active = false
		bloom._launch_glob(
			Vector2(120.0, field.tuning.arena_size.y * 0.5),
			Vector2.RIGHT,
			float(entry[0]),
			float(entry[1]),
			1.0,
			1.0,
			0
		)
		var launch_speed := 0.0
		for glob in bloom._globs:
			if glob.active:
				launch_speed = glob.velocity.length()
		for _fly in range(600):
			bloom.advance(1.0 / 60.0)
			if bloom.get_active_glob_count() == 0:
				break
		var reach := 0.0
		for glob in bloom._globs:
			reach = maxf(reach, glob.travelled)
		if float(entry[0]) < 10.0:
			mist_speed = launch_speed
			mist_range = reach
		else:
			lump_speed = launch_speed
			lump_range = reach
	# The ratio itself depends on what the droplets happen to cross, so the claim
	# under test is the ordering: the blast throws the mist faster and the heavy
	# glob still outruns it, because drag is resisted by Mass.
	_check(
		mist_speed > lump_speed
		and lump_range > mist_range * 1.5,
		"fine mist is thrown fastest and falls short; heavy globs leave slower and carry"
	)

	# The same explosion sample fired at one pitch several times a second is what
	# makes a good effect grating, so each detonation is detuned inside a narrow band.
	var explosion_pitches := PackedFloat32Array()
	for _blast in range(12):
		prototype.combat.play_plant_explosion_sfx()
		explosion_pitches.append(prototype.combat.get_last_explosion_pitch_scale())
	var lowest := 9.0
	var highest := 0.0
	for pitch in explosion_pitches:
		lowest = minf(lowest, pitch)
		highest = maxf(highest, pitch)
	_check(
		highest > lowest
		and lowest >= prototype.combat.explosion_minimum_pitch_scale
		and highest <= prototype.combat.explosion_maximum_pitch_scale
		and prototype.combat.explosion_maximum_pitch_scale
		/ prototype.combat.explosion_minimum_pitch_scale < 1.5,
		"every explosion detunes itself inside a band narrow enough to stay one sound"
	)

	# Something arriving with momentum dents established ground whatever it has
	# matured into. Growing into an old front is rightly hard; hitting one is a
	# different act, and without this a Bloom thrown at a mature red front was
	# absorbed by it.
	var slab_centre := Vector2(
		field.tuning.arena_size.x * 0.62,
		field.tuning.arena_size.y * 0.5
	)
	var slab_remaining := PackedInt32Array()
	for impact_break in [0.0, 2.0]:
		field.reset_field()
		field.step_simulation()
		var slab_cell := field.local_to_cell(slab_centre)
		var slab_width := int(field.tuning.field_size.x)
		for y in range(int(field.tuning.field_size.y)):
			for x in range(slab_width):
				if absf(float(y) - slab_cell.y) > 10.0 or absf(float(x) - slab_cell.x) > 10.0:
					continue
				var index := y * slab_width + x
				if field._claimable_mask[index] == 0:
					continue
				field._control[index] = -1.0
				field._maturity[index] = 1.0
		# A deliberately weak splat, so what shows is the dent and not the Mass.
		field.queue_splat(slab_centre, 2.0, 0.5, 6.0, 1.0, Vector2.RIGHT, 1.0, float(impact_break))
		field.step_simulation()
		var hostile := 0
		for y in range(int(field.tuning.field_size.y)):
			for x in range(slab_width):
				if absf(float(y) - slab_cell.y) > 10.0 or absf(float(x) - slab_cell.x) > 10.0:
					continue
				var index := y * slab_width + x
				if field._claimable_mask[index] == 0:
					continue
				if field._control[index] < -0.2:
					hostile += 1
		slab_remaining.append(hostile)
	_check(
		slab_remaining.size() == 2
		and slab_remaining[0] > 400
		and slab_remaining[1] < slab_remaining[0] - 40,
		"an impact dents fully mature hostile ground that growth alone cannot touch"
	)

	# And the same thing end to end, which is what was actually broken: the unit
	# case above passed for months while a real Bloom still left no mark, because a
	# glob stamped its landing at the radius it had been flying at. Paint does not
	# do that — it flattens out across the surface it hits — and until it did, nine
	# droplet-sized footprints could not add up to a hole anyone could see. The
	# threshold is what an uninvested Bloom manages; the run's Mass line grows it.
	var bloom_dent := PackedInt32Array()
	for throw_bloom in [false, true]:
		field.reset_field()
		for _settle in range(10):
			field.step_simulation()
		var mature_front := 0
		for index in range(int(field.tuning.field_size.x) * int(field.tuning.field_size.y)):
			if field._claimable_mask[index] == 0 or field._control[index] >= -0.2:
				continue
			field._maturity[index] = 1.0
			mature_front += 1
		prototype.bloom_director.reset_director()
		if throw_bloom:
			prototype.bloom_director.on_bloom_detonated(
				field.find_player_frontier_near(prototype.player.get_arena_position()), 0
			)
		for _step in range(180):
			prototype.bloom_director.advance(1.0 / 60.0)
		field.step_simulation()
		var still_hostile := 0
		for index in range(int(field.tuning.field_size.x) * int(field.tuning.field_size.y)):
			if field._claimable_mask[index] != 0 and field._control[index] < -0.2:
				still_hostile += 1
		bloom_dent.append(mature_front - still_hostile)
	_check(
		bloom_dent.size() == 2 and bloom_dent[0] == 0 and bloom_dent[1] > 40,
		"a thrown Bloom punches a visible hole in a fully mature hostile front"
	)

	# Basalt and the arena wall are surfaces, not sinks. Thrown paint used to stop
	# dead the instant it touched one, so the glob simply blinked out at the rock.
	# It should hit, lose what was driving into the face, and let what was running
	# along the face carry it down the surface until it pools against it.
	var wall_width := int(field.tuning.field_size.x)
	var wall_height := int(field.tuning.field_size.y)
	var wall_pixels_per_cell := field.tuning.arena_size.x / float(wall_width)
	var face_x := -1
	var face_y := -1
	for probe_y in range(int(wall_height * 0.3), int(wall_height * 0.7)):
		for probe_x in range(int(wall_width * 0.3), wall_width - 4):
			if (
				field._claimable_mask[probe_y * wall_width + probe_x] == 0
				and field._claimable_mask[probe_y * wall_width + probe_x - 6] != 0
			):
				face_x = probe_x
				face_y = probe_y
				break
		if face_x >= 0:
			break
	var face_travel := PackedFloat32Array()
	var face_gap := PackedFloat32Array()
	for allowed_contacts in [0, prototype.bloom_director.maximum_wall_contacts]:
		var previous_contacts := prototype.bloom_director.maximum_wall_contacts
		prototype.bloom_director.maximum_wall_contacts = int(allowed_contacts)
		prototype.bloom_director.reset_director()
		prototype.bloom_director._launch_glob(
			Vector2(
				(float(face_x) - 7.0 + 0.5) * wall_pixels_per_cell,
				(float(face_y) + 0.5) * wall_pixels_per_cell
			),
			Vector2.RIGHT, 22.0, 0.5, 1.0, 1.6, 0
		)
		var thrown = null
		for candidate in prototype.bloom_director._globs:
			if candidate.active:
				thrown = candidate
				break
		var contact_point := Vector2.ZERO
		var ran := 0.0
		for _step in range(400):
			var previous_position: Vector2 = thrown.position
			var contacts_before: int = thrown.wall_contacts
			prototype.bloom_director.advance(1.0 / 60.0)
			if thrown.wall_contacts > contacts_before and contact_point == Vector2.ZERO:
				contact_point = previous_position
			if contact_point != Vector2.ZERO and thrown.active:
				ran += thrown.position.distance_to(previous_position)
			if not thrown.active:
				break
		face_travel.append(ran)
		var rest := field.local_to_cell(thrown.position)
		var nearest := 999.0
		for offset_y in range(-6, 7):
			for offset_x in range(-6, 7):
				var sample_x := clampi(int(rest.x) + offset_x, 0, wall_width - 1)
				var sample_y := clampi(int(rest.y) + offset_y, 0, wall_height - 1)
				if field._claimable_mask[sample_y * wall_width + sample_x] == 0:
					nearest = minf(nearest, Vector2(offset_x, offset_y).length())
		face_gap.append(nearest)
		prototype.bloom_director.maximum_wall_contacts = previous_contacts
	_check(
		face_x >= 0 and face_travel[0] <= 0.01 and face_travel[1] > 50.0,
		"paint thrown at an obstacle runs down its face instead of stopping dead"
	)
	_check(
		face_gap[1] <= 3.0,
		"paint running down a face stays against it rather than glancing away"
	)

	# The scene file is the surface this interface is designed on, so what a node
	# declares has to be the shape the game writes into it. A placeholder describing
	# an older version of its own line makes the editor lie about the layout being
	# arranged. Compared by shape rather than by value — digits are normalised — so a
	# live number moving does not count as a disagreement.
	var declared_texts := {}
	var packed_prototype: PackedScene = load("res://scenes/run/phase_b_prototype.tscn")
	var scene_state := packed_prototype.get_state()
	for node_index in range(scene_state.get_node_count()):
		var node_path := str(scene_state.get_node_path(node_index))
		for property_index in range(scene_state.get_node_property_count(node_index)):
			if scene_state.get_node_property_name(node_index, property_index) != "text":
				continue
			declared_texts[node_path] = str(
				scene_state.get_node_property_value(node_index, property_index)
			)
	# Against a fresh run: the placeholders describe a run's opening state, and by
	# this point the suite has drafted paths and populated the choice panel.
	prototype.reset_run()
	prototype._update_hud()
	prototype._update_metabolism_controls()
	var shape_of := func(value: String) -> String:
		var shaped := ""
		for character in value:
			shaped += "#" if character >= "0" and character <= "9" else character
		return shaped
	var stale_placeholders := PackedStringArray()
	for node_path in declared_texts.keys():
		if node_path.contains("ChoicePanel"):
			# The draft panel is filled from whatever the run rolls, so its
			# placeholders can only ever be an example of the shape rather than a
			# match. Everything else writes a fixed shape and is held to it.
			continue
		var declared_node := prototype.get_node_or_null(NodePath(node_path))
		if declared_node == null or not ("text" in declared_node):
			continue
		if shape_of.call(str(declared_node.text)) != shape_of.call(declared_texts[node_path]):
			stale_placeholders.append(node_path)
	_check(
		declared_texts.size() > 20 and stale_placeholders.is_empty(),
		"every scene placeholder matches the shape the game writes into it"
	)

	# The same rule for layout, not just wording. A tool script that recomputes a
	# child's rect at load silently undoes anything placed by hand in the editor,
	# which is exactly what the drawer's meters did until it was taken out.
	var moved_by_code := PackedStringArray()
	for node_index in range(scene_state.get_node_count()):
		var placed_path := str(scene_state.get_node_path(node_index))
		var placed_node := prototype.get_node_or_null(NodePath(placed_path)) as Control
		if placed_node == null:
			continue
		for property_index in range(scene_state.get_node_property_count(node_index)):
			var property_name := str(
				scene_state.get_node_property_name(node_index, property_index)
			)
			if not property_name.begins_with("offset_"):
				continue
			var declared_value = scene_state.get_node_property_value(
				node_index, property_index
			)
			if typeof(declared_value) != TYPE_FLOAT:
				continue
			var live_value = placed_node.get(property_name)
			if absf(float(live_value) - float(declared_value)) > 0.51:
				moved_by_code.append("%s.%s" % [placed_path.get_file(), property_name])
	_check(
		moved_by_code.is_empty(),
		"nothing moves a control the scene placed by hand"
	)
	if not moved_by_code.is_empty():
		print("    moved by code: %s" % ", ".join(moved_by_code))
	if not stale_placeholders.is_empty():
		print("    stale placeholders: %s" % ", ".join(stale_placeholders))

	# A Bloom landing on the run's own established Green must not strip it. The
	# maturity ceiling that keeps newly taken ground rootless was being applied to
	# every player-held cell a splat touched, so firing a Bloom over your own mature
	# territory reset it — the exact opposite of what material settling onto growth
	# should do.
	var maturity_means := PackedFloat32Array()
	var maturity_losses := PackedInt32Array()
	for reinforcement in [0.0, prototype.bloom_director.landing_maturity_reinforcement]:
		var previous_reinforcement := prototype.bloom_director.landing_maturity_reinforcement
		prototype.bloom_director.landing_maturity_reinforcement = float(reinforcement)
		field.reset_field()
		for _settle in range(10):
			field.step_simulation()
		var owned := PackedInt32Array()
		for index in range(int(field.tuning.field_size.x) * int(field.tuning.field_size.y)):
			if field._claimable_mask[index] != 0 and field._control[index] > 0.2:
				field._maturity[index] = 0.80
				owned.append(index)
		prototype.bloom_director.reset_director()
		prototype.bloom_director.on_bloom_detonated(
			field.find_player_frontier_near(prototype.player.get_arena_position()), 0
		)
		for _step in range(180):
			prototype.bloom_director.advance(1.0 / 60.0)
		field.step_simulation()
		var total := 0.0
		var lost := 0
		for index in owned:
			total += field._maturity[index]
			if field._maturity[index] < 0.80 - 0.0001:
				lost += 1
		maturity_means.append(total / maxf(1.0, float(owned.size())))
		maturity_losses.append(lost)
		prototype.bloom_director.landing_maturity_reinforcement = previous_reinforcement
	_check(
		maturity_losses[0] == 0 and maturity_losses[1] == 0,
		"a Bloom never strips maturity from ground the run already holds"
	)
	_check(
		maturity_means[1] > maturity_means[0],
		"material landing on established Green thickens it instead"
	)
	# And how well it roots is the run's own Maturation, not a flat number: the
	# ecosystem's capacity to put down roots acting on material the Bloom delivered.
	var reinforcement_before := prototype.bloom_director.get_landing_maturity_reinforcement()
	prototype.metabolism.debug_grant_axis(PhaseBMetabolism.SystemId.PHOTOSYNTHESIS, 8)
	prototype._apply_progression_modifiers()
	var reinforcement_after := prototype.bloom_director.get_landing_maturity_reinforcement()
	_check(
		reinforcement_after > reinforcement_before * 1.2,
		"an ecosystem with Maturation behind it roots what a Bloom lands harder"
	)

	# What a Bloom throws is the ecosystem, so a glob landing on a Seed that is
	# already breaking ground settles whether that site establishes. Budgeted per
	# Bloom, and gated on the pairing that makes germination arm a chain at all.
	var inoculation_openings := PackedInt32Array()
	var inoculation_germinations := PackedInt32Array()
	for evolved in [false, true]:
		prototype.progression.debug_select_paths(
			PhaseBProgression.PathId.BLOOM, PhaseBProgression.PathId.SPORE
		)
		if evolved:
			prototype.progression.debug_complete_evolution_requirements()
			prototype.progression.grant_evolution_if_ready()
		prototype._apply_progression_modifiers()
		field.reset_field()
		for _settle in range(10):
			field.step_simulation()
		prototype.bloom_director.reset_director()
		# The overlay owns Seeds and holds its effects paused outside a live run, so
		# the harness has to clear it and let it tick for germination to resolve.
		prototype.overlay.clear_effects()
		var was_paused := prototype.overlay.effects_paused
		prototype.overlay.effects_paused = false
		var blast := field.find_player_frontier_near(prototype.player.get_arena_position())
		# A container, because a GDScript lambda captures locals by value and an
		# incremented int would never be seen out here.
		var germinated := PackedInt32Array([0])
		var counter := func(_position: Vector2, _depth: int) -> void:
			germinated[0] += 1
		prototype.overlay.seed_germinated_with_context.connect(counter)
		for ring_index in range(12):
			prototype.overlay.spawn_seed(
				blast + Vector2.from_angle(TAU * float(ring_index) / 12.0) * 110.0, 6.0, 0
			)
		prototype.bloom_director.on_bloom_detonated(blast, 0)
		for _step in range(180):
			prototype.bloom_director.advance(1.0 / 60.0)
			prototype.overlay._process(1.0 / 60.0)
		prototype.overlay.seed_germinated_with_context.disconnect(counter)
		prototype.overlay.effects_paused = was_paused
		inoculation_openings.append(prototype.bloom_director.get_inoculation_openings())
		inoculation_germinations.append(germinated[0])


	_check(
		inoculation_openings[0] == 0,
		"without the pairing, thrown material does not crack Seeds open"
	)
	# Each generation of a chain gets its own budget, so the total is the budget
	# times the generations the pairing allows — and no more. A cracked Seed joins
	# the chain that cracked it; without that it reported the depth it was planted
	# at, every generation looked like the first, and one Bloom opened the field.
	var inoculation_ceiling := (
		prototype.evolutions.inoculation_seeds_per_bloom
		* (prototype.bloom_director.get_maximum_chain_depth() + 1)
	)
	_check(
		inoculation_openings[1] >= prototype.evolutions.inoculation_seeds_per_bloom
		and inoculation_openings[1] <= inoculation_ceiling
		and inoculation_germinations[1] > inoculation_germinations[0],
		"thrown material establishes Seeds it lands on, and the chain it starts ends"
	)

	# A wall's corner dims what is behind it rather than deleting it. The old rule
	# was a yes-or-no ray, so one clipped cell erased everything past it and a ridge
	# on a rock shadowed far more than the ridge was worth.
	var rock_x := -1
	var rock_y := -1
	var rock_row := int(field.tuning.field_size.x)
	for y in range(int(field.tuning.field_size.y) / 3, int(field.tuning.field_size.y) * 2 / 3):
		for x in range(rock_row / 3, rock_row * 2 / 3):
			if field._claimable_mask[y * rock_row + x] == 0:
				rock_x = x
				rock_y = y
				break
		if rock_x >= 0:
			break
	var grazed := 0
	var clipped_transmission := 0.0
	var buried_transmission := 1.0
	if rock_x >= 0:
		var source_x := rock_x - 9
		var source_y := rock_y
		for offset in range(1, 12):
			var probe_x := rock_x + offset
			if probe_x >= rock_row:
				break
			if field._is_claimable_line_clear(source_x, source_y, probe_x, rock_y):
				continue
			var through := field._claimable_line_transmission(
				source_x,
				source_y,
				probe_x,
				rock_y,
				field.tuning.obstruction_falloff_per_cell
			)
			if offset <= 2:
				clipped_transmission = maxf(clipped_transmission, through)
			else:
				buried_transmission = minf(buried_transmission, through)
			grazed += 1
	_check(
		rock_x >= 0
		and grazed > 0
		and clipped_transmission > 0.0
		and buried_transmission <= 0.0,
		"a clipped corner dims growth behind it while solid rock still stops it dead"
	)

	# Paint that arrives with speed does not land as a disc. It runs on along the
	# line it was travelling, so the ground it claims is stretched that way and sits
	# forward of the impact rather than centred on it.
	var footprints := {}
	for entry in [["still", Vector2.ZERO, 1.0], ["thrown", Vector2.RIGHT, 3.0]]:
		field.reset_field()
		for _settle in range(4):
			field.step_simulation()
		var impact := Vector2(
			field.tuning.arena_size.x * 0.78,
			field.tuning.arena_size.y * 0.28
		)
		var width := int(field.tuning.field_size.x)
		var height := int(field.tuning.field_size.y)
		var before := PackedFloat32Array()
		before.resize(width * height)
		for index in range(width * height):
			before[index] = field._control[index]
		field.queue_splat(impact, 30.0, 1.5, 4.0, 3.0, entry[1], float(entry[2]))
		field.step_simulation()
		var cell := field.local_to_cell(impact)
		var forward := -999.0
		var behind := 999.0
		var side := 0.0
		for y in range(height):
			for x in range(width):
				var index := y * width + x
				if field._control[index] - before[index] < 0.01:
					continue
				# The impact's own neighbourhood only: the rest of the field grows on
				# its own and would drown the measurement.
				if absf(float(x) - cell.x) > 16.0 or absf(float(y) - cell.y) > 16.0:
					continue
				forward = maxf(forward, float(x) - cell.x)
				behind = minf(behind, float(x) - cell.x)
				side = maxf(side, absf(float(y) - cell.y))
		footprints[entry[0]] = [forward, behind, side]
	var still_shape: Array = footprints["still"]
	var thrown_shape: Array = footprints["thrown"]
	_check(
		float(thrown_shape[0]) > float(still_shape[0]) * 2.0
		and float(thrown_shape[0]) - float(thrown_shape[1])
		> float(thrown_shape[2]) * 2.0,
		"a landing runs on along its own travel instead of stamping a circle"
	)

	# Force is the blast's energy rather than its speed, so it arrives as a square
	# root: a much harder bang, not a proportionally longer throw.
	var weak_speed := 0.0
	var strong_speed := 0.0
	for force in [1.0, 4.0]:
		for glob in bloom._globs:
			glob.active = false
		bloom._launch_glob(
			Vector2(120.0, field.tuning.arena_size.y * 0.5),
			Vector2.RIGHT, 10.0, 4.0, 1.0, float(force),
			0
		)
		for glob in bloom._globs:
			if glob.active:
				if force < 2.0:
					weak_speed = glob.velocity.length()
				else:
					strong_speed = glob.velocity.length()
		for glob in bloom._globs:
			glob.active = false
	_check(
		weak_speed > 0.0
		and is_equal_approx(strong_speed, weak_speed * 2.0),
		"Bloom Force feeds the blast as energy, so four times the Force is twice the throw"
	)

	# The focus ring is a controller affordance: a mouse player should never be
	# shown a white box parked on a button.
	# The pause menu will not open over a pending choice, and this block runs while
	# the run happens to have one on the table.
	var restore_choice := prototype._choice_kind
	prototype._choice_kind = PhaseBPrototype.ChoiceKind.NONE
	prototype._open_pause_menu()
	var focus_on_open := prototype.get_viewport().gui_get_focus_owner()
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	prototype._unhandled_input(pad)
	var focus_on_pad := prototype.get_viewport().gui_get_focus_owner()
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(4.0, 0.0)
	prototype._unhandled_input(mouse)
	var focus_after_mouse := prototype.get_viewport().gui_get_focus_owner()
	prototype._unhandled_input(pad)
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	prototype._unhandled_input(key)
	var focus_after_key := prototype.get_viewport().gui_get_focus_owner()
	prototype._close_pause_menu()
	prototype._choice_kind = restore_choice
	_check(
		focus_on_open == null
		and focus_on_pad == prototype.pause_resume_button
		and focus_after_mouse == null
		and focus_after_key == null,
		"the focus ring appears only for a controller and leaves on mouse or keyboard"
	)

	# Mass and Force are physically distinct: Mass decides how much material is
	# thrown, Force decides how far it goes.
	var mass_before := prototype.bloom_director.get_bloom_mass_multiplier()
	var force_before := prototype.bloom_director.get_bloom_force_multiplier()
	prototype.metabolism.debug_grant_axis(
		PhaseBMetabolism.SystemId.PHOTOSYNTHESIS,
		3
	)
	var mass_after := prototype.bloom_director.get_bloom_mass_multiplier()
	var force_after_mass := prototype.bloom_director.get_bloom_force_multiplier()
	prototype.metabolism.debug_grant_axis(PhaseBMetabolism.SystemId.MERISTEM, 3)
	var force_after := prototype.bloom_director.get_bloom_force_multiplier()
	_check(
		mass_after > mass_before
		and is_equal_approx(force_after_mass, force_before)
		and force_after > force_before,
		"Bloom Mass and Bloom Force move independently of one another"
	)
	prototype.metabolism.reset_metabolism()
	prototype.root_network.reset_network()

	# Geometry decides where the splatter can go: a splat is never thrown through
	# basalt, so a wall shortens the spray instead of painting past it.
	prototype.territory_field._commands.clear()
	var splats_clear_of_walls := true
	prototype.bloom_director.on_bloom_detonated(splatter_origin, 0)
	for command in prototype.territory_field._commands:
		if command.kind != TerritoryField.TerritoryCommand.Kind.SPLAT:
			continue
		var landing := prototype.territory_field.cell_to_local(command.cell_position)
		splats_clear_of_walls = (
			splats_clear_of_walls
			and prototype.territory_field.is_claimable_at_local(landing)
		)
	_check(
		splats_clear_of_walls,
		"every thrown splat lands on claimable ground rather than inside basalt"
	)
	prototype.territory_field._commands.clear()

	# Overgrow is emergent: it injects Mass and Pressure into the living frontier
	# and lets the simulation decide, so it needs a frontier to act on at all.
	# The same opening, stepped the same number of times, with and without the
	# injection: what Overgrow buys is whatever the simulation makes of it.
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	_step_field(prototype.territory_field, 20)
	var green_without_overgrow := prototype.territory_field.get_player_cell_count()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	var overgrow_result := prototype.territory_field.overgrow(400.0, 400.0, 0.0)
	_step_field(prototype.territory_field, 20)
	_check(
		overgrow_result.cell_count > 0
		and overgrow_result.mass_applied > 0.0
		and overgrow_result.pressure_applied > 0.0
		and prototype.territory_field.get_player_cell_count() > green_without_overgrow,
		"Overgrow injects Mass and Pressure along the frontier and the field resolves it"
	)

	# Production milestones announce themselves once and only once.
	prototype.metabolism.reset_metabolism()
	prototype.progression.reset_progression()
	var milestone_threshold := prototype.metabolism.production_milestones[0]
	prototype.progression.biomass_per_second = milestone_threshold + 1.0
	prototype.metabolism.advance(1.0 / 30.0)
	var milestones_after_first := prototype.metabolism.get_milestones_reached()
	prototype.metabolism.advance(1.0 / 30.0)
	_check(
		milestones_after_first == 1
		and prototype.metabolism.get_milestones_reached() == 1,
		"a production milestone fires once when it is first reached"
	)
	prototype.metabolism.reset_metabolism()
	prototype.progression.reset_progression()

	# Bramble publishes its restraint as drawable tethers without simulating rope.
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.BRAMBLE,
		PhaseBProgression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	var tether_spot := _find_owned_cell_position(prototype)
	prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER,
		tether_spot
	)
	prototype.combat.apply_entanglement_in_radius(tether_spot, 40.0, 1.0)
	prototype.bramble_director.advance(1.0 / 60.0)
	var tethers_drawn := prototype.overlay.get_active_tether_count()
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	prototype.bramble_director.advance(1.0 / 60.0)
	_check(
		tethers_drawn > 0 and prototype.overlay.get_active_tether_count() == 0,
		"Bramble tethers appear on Entangled enemies and vanish with the path"
	)
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	prototype.territory_field.reset_field()

	# Man-Eater: the Legendary relic that replaced the Path. Enemies standing on
	# Green build Hunger; when it fills, a giant Maw comes up under the densest
	# group, eats it, and goes back underground. Nothing about it persists.
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	var man_eater := prototype.man_eater
	man_eater.reset_man_eater()
	var green_spot := _find_owned_cell_position(prototype)
	var unheld_hunger_seconds := man_eater.hunger_threshold * 2.0
	_spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.HUNTER,
		green_spot
	)
	man_eater.advance(unheld_hunger_seconds)
	var dormant_without_relic := man_eater.get_hunger() <= 0.0
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.MAN_EATER] = 1
	# One enemy alone has to stand there for the whole threshold.
	man_eater.advance(1.0)
	var lone_hunger := man_eater.get_hunger()
	for _pack_body in range(4):
		_spawn_bramble_contact_enemy(
			prototype,
			PhaseBCombatDirector.EnemyRole.HUNTER,
			green_spot
		)
	man_eater.advance(1.0)
	var pack_hunger := man_eater.get_hunger() - lone_hunger
	_check(
		dormant_without_relic
		and is_equal_approx(lone_hunger, man_eater.hunger_per_enemy_second)
		and pack_hunger > lone_hunger * 4.0,
		"Hunger is enemy-seconds on Green: a pack feeds it as fast as its bodies"
	)

	# The Maw does not appear the instant Hunger fills: the ground telegraphs first,
	# which is what makes it a battlefield event rather than free invisible damage.
	man_eater.advance(man_eater.hunger_threshold)
	var telegraphing := man_eater.get_state() == PhaseBManEater.State.TELEGRAPHING
	var telegraph_site := man_eater.get_site()
	var enemies_before := prototype.combat.get_active_enemy_count()
	var still_alive_during_telegraph := (
		prototype.combat.get_active_enemy_count() == enemies_before
	)
	man_eater.advance(man_eater.telegraph_seconds + 0.01)
	_check(
		telegraphing
		and telegraph_site.x >= 0.0
		and still_alive_during_telegraph
		and prototype.combat.get_active_enemy_count() < enemies_before
		and man_eater.get_meal_count() == 1,
		"Hunger telegraphs under the densest group and only then closes the jaws"
	)

	# What it ate is gone, and the Hunger with it.
	_check(
		man_eater.get_swallowed_count() > 0
		and is_equal_approx(man_eater.get_hunger(), 0.0)
		and man_eater.get_lockout_remaining() > 0.0,
		"the meal is swallowed whole, and Hunger resets behind a short lockout"
	)

	# The Maw is an event, not a structure: once it has retracted nothing remains
	# for an enemy to attack.
	man_eater.advance(man_eater.retract_seconds + 0.01)
	_check(
		man_eater.get_state() == PhaseBManEater.State.DORMANT
		and man_eater.get_site().x < 0.0,
		"the Maw retracts completely, leaving nothing standing to be killed"
	)

	# A boss is bitten, never eaten.
	prototype.combat.reset_combat()
	man_eater.reset_man_eater()
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.MAN_EATER] = 1
	var boss := _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.BOSS,
		green_spot
	)
	var boss_health_before := boss.health
	man_eater.advance(man_eater.hunger_threshold * 2.0)
	man_eater.advance(man_eater.telegraph_seconds + 0.01)
	_check(
		boss != null
		and boss.active
		and boss.health < boss_health_before
		and boss.health
		> boss_health_before - man_eater.bite_damage,
		"a boss takes a reduced Bite and is never swallowed"
	)
	prototype.progression.reset_progression()
	prototype.combat.reset_combat()
	man_eater.reset_man_eater()


	# Pruning: the run cuts its own ecosystem back and fires the harvest outward.
	prototype.progression.reset_progression()
	prototype.progression.offer_pruning_path = true
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.PRUNING,
		PhaseBProgression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	var pruning := prototype.pruning_director
	pruning.reset_director()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	_grow_test_ecosystem(prototype)
	_stand_on_owned_ground(prototype)
	var green_before_cycle := prototype.territory_field.get_player_percent()
	var target_cells := pruning.get_cycle_target_cells()
	var launched := pruning.run_cycle_now()
	prototype.territory_field.recalculate_metrics_now()
	_check(
		target_cells > 0
		and launched > 0
		and pruning.get_last_cycle_cells() > 0
		and pruning.get_last_cycle_cells() <= target_cells
		and prototype.territory_field.get_player_percent() < green_before_cycle
		and pruning.get_active_cutting_count() == launched,
		"standing on your own Green harvests it and raises Cuttings out of it"
	)

	# There is no cycle interval. The harvest is continuous for exactly as long as the
	# player stands on their own ground, so the only input is where you stand.
	prototype.territory_field.reset_field()
	_grow_test_ecosystem(prototype)
	pruning.reset_director()
	var harvest_home := _stand_on_owned_ground(prototype)
	for _hold_step in range(60):
		prototype.player.global_position = prototype.territory_field.to_global(harvest_home)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
	var held_cells := pruning.get_upkeep_cells_taken()
	pruning.reset_director()
	var open_stand := _find_open_ground_position(prototype)
	prototype.player.global_position = prototype.territory_field.to_global(open_stand)
	for _idle_step in range(60):
		prototype.player.global_position = prototype.territory_field.to_global(open_stand)
		pruning.advance(1.0 / 60.0)
	_check(
		held_cells > 0
		and not pruning.is_player_on_green()
		and pruning.get_upkeep_cells_taken() == 0,
		"the harvest has no cooldown: it runs while you stand on Green and not otherwise"
	)

	# A cycle takes the youngest ground it can find before it touches the oldest.
	prototype.territory_field.reset_field()
	_grow_test_ecosystem(prototype)
	var oldest_spot := _stand_on_owned_ground(prototype)
	var oldest_cell := prototype.territory_field.local_to_cell(oldest_spot)
	var oldest_index := (
		int(round(oldest_cell.y)) * prototype.territory_field.tuning.field_size.x
		+ int(round(oldest_cell.x))
	)
	prototype.territory_field._maturity[oldest_index] = 1.0
	pruning.run_cycle_now()
	_check(
		prototype.territory_field._control[oldest_index] > 0.0,
		"the harvest eats Fresh ground before it touches Mature ground"
	)

	# The cut opens around the player rather than off to one side of them. The scan
	# used to walk the bounding box row by row and stop the moment it had its quota,
	# which for the small quota a continuous harvest asks for meant it never reached
	# past the top rows: the hole appeared above the Gardener instead of under them.
	prototype.territory_field.reset_field()
	_grow_test_ecosystem(prototype)
	pruning.reset_director()
	var centred_home := _stand_on_owned_ground(prototype)
	prototype.player.global_position = prototype.territory_field.to_global(centred_home)
	var centred_harvest := prototype.territory_field.drain_territory_in_radius(
		centred_home,
		pruning.upkeep_radius_pixels,
		6,
		pruning.pruned_ground_seconds,
		pruning.upkeep_inner_radius_pixels
	)
	var cut_above := 0
	var cut_below := 0
	var furthest_cut := 0.0
	for cut_position in centred_harvest.positions:
		if cut_position.y < centred_home.y:
			cut_above += 1
		elif cut_position.y > centred_home.y:
			cut_below += 1
		furthest_cut = maxf(furthest_cut, cut_position.distance_to(centred_home))
	_check(
		centred_harvest.cell_count > 0
		and cut_above > 0
		and cut_below > 0
		and furthest_cut <= pruning.upkeep_radius_pixels + 1.0,
		"the harvest opens around the player instead of biting off one side "
			+ "(%d above, %d below, furthest %.1fpx)" % [cut_above, cut_below, furthest_cut]
	)

	# And it spares the ground the player is standing on. The harvest only runs while
	# they are on their own Green, so cutting the cell underfoot would switch off the
	# thing that is running it after a single step.
	_check(
		prototype.territory_field.get_control_at_local(centred_home)
		> prototype.territory_field.tuning.ownership_threshold
		and pruning.is_player_on_green()
		and pruning.upkeep_inner_radius_pixels > 0.0,
		"the harvest leaves the player's own footing intact"
	)

	# Cut ground comes back faster than ordinary neutral ground.
	prototype.territory_field.reset_field()
	_grow_test_ecosystem(prototype)
	pruning.reset_director()
	pruning.run_cycle_now()
	var pruned_spot := Vector2(-1.0, -1.0)
	for probe_y in range(2, 60):
		for probe_x in range(2, 108):
			var probe := prototype.territory_field.cell_to_local(Vector2(probe_x, probe_y))
			if prototype.territory_field.get_pruned_ground_at_local(probe) > 0.0:
				pruned_spot = probe
				break
		if pruned_spot.x >= 0.0:
			break
	_check(
		pruned_spot.x >= 0.0
		and prototype.territory_field.get_pruned_ground_at_local(pruned_spot) > 0.0,
		"ground the harvest cut is marked as Pruned Ground"
	)

	# A held ring suppresses reclamation entirely, so the ground it burns stays burned
	# until the player lets go. This is the sacrifice being real rather than cosmetic:
	# without it the drained cells came back inside a fifth of a second.
	prototype.territory_field.reset_field()
	_grow_test_ecosystem(prototype)
	pruning.reset_director()
	var burn_home := _stand_on_owned_ground(prototype)
	for _burn_step in range(90):
		prototype.player.global_position = prototype.territory_field.to_global(burn_home)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
		_step_field(prototype.territory_field, 1)
	prototype.territory_field.recalculate_metrics_now()
	var green_while_held := prototype.territory_field.get_player_percent()
	var regrowth_while_held := prototype.territory_field._pruned_regrowth_per_second
	prototype.player.global_position = prototype.territory_field.to_global(
		_find_open_ground_position(prototype)
	)
	pruning.advance(1.0 / 60.0)
	_step_field(prototype.territory_field, int(prototype.territory_field.tuning.simulation_hz * 3.0))
	prototype.territory_field.recalculate_metrics_now()
	_check(
		pruning.is_holding() == false
		and is_equal_approx(regrowth_while_held, 0.0)
		and prototype.territory_field.get_player_percent() > green_while_held,
		"a held ring stops the burned ground reclaiming until the player lets go"
	)

	# Cuttings gather to the player, then launch and strike.
	prototype.combat.reset_combat()
	prototype.combat._thornshot_remaining = 9999.0
	var cutting_target := _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.BOSS,
		prototype.player.get_arena_position() + Vector2(60.0, 0.0)
	)
	var cutting_health_before := cutting_target.health
	pruning.run_cycle_now()
	for _cutting_step in range(240):
		cutting_target.position = prototype.player.get_arena_position() + Vector2(60.0, 0.0)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
		if cutting_target.health < cutting_health_before:
			break
	_check(
		cutting_target.health < cutting_health_before,
		"Cuttings gather to the player and then strike what is nearby"
	)

	# Cuttings orbit while the player stands on their own Green, grinding what comes
	# into the ring, and fire outward when the ground is gone or left behind.
	prototype.territory_field.reset_field()
	_grow_test_ecosystem(prototype)
	prototype.combat.reset_combat()
	prototype.combat._thornshot_remaining = 9999.0
	pruning.reset_director()
	var ring_home := _stand_on_owned_ground(prototype)
	# The ring fills over a few seconds of grazing. Standing still burns the ground
	# out from underneath and fires the ring, which is the loop working, so the
	# fixture moves the way a run has to.
	for gather_step in range(240):
		_graze_owned_ground(prototype, ring_home, float(gather_step) * 0.04)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
	var ring_victim := _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.BOSS,
		prototype.combat.player.get_arena_position()
			+ Vector2(pruning.get_orbit_radius(), 0.0)
	)
	var ring_health_before := ring_victim.health
	var orbiting := 0
	for ring_step in range(120):
		_graze_owned_ground(prototype, ring_home, float(240 + ring_step) * 0.04)
		# The ring widens as the harvest fills it and it travels with the player, so
		# the victim is held on the band rather than at a radius measured once.
		ring_victim.position = (
			prototype.combat.player.get_arena_position()
			+ Vector2(pruning.get_orbit_radius(), 0.0)
		)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
		orbiting = maxi(orbiting, pruning.get_orbit_count())
	_check(
		orbiting > 0
		and orbiting <= pruning.orbit_capacity
		and ring_victim.health < ring_health_before,
		"Cuttings orbit the player on their own Green and grind what enters the ring"
	)

	# A full ring turns over on a timer. Shedding the oldest spike to take a new one
	# is the ring working; doing it every third of a second is not, and that turned
	# holding into a free homing volley with the disc beside the point.
	var capacity_reached := false
	for _capacity_step in range(900):
		_graze_owned_ground(prototype, ring_home, 8.0)
		pruning.advance(1.0 / 60.0)
		if pruning.get_orbit_count() >= pruning.orbit_capacity:
			capacity_reached = true
			break
	var launched_at_capacity := pruning.get_cuttings_launched()
	var cells_at_capacity := pruning.get_upkeep_cells_taken()
	var held_seconds := 6.0
	for _hold_step in range(int(held_seconds * 60.0)):
		_graze_owned_ground(prototype, ring_home, 8.0)
		pruning.advance(1.0 / 60.0)
	var shed := pruning.get_cuttings_launched() - launched_at_capacity
	var allowed := int(ceil(held_seconds / pruning.full_ring_replacement_seconds)) + 1
	# The ring may fire partway through if the ground under it runs out, which is
	# the loop working; what is under test is the rate, not the ring surviving.
	_check(
		capacity_reached
		and shed > 0
		and shed <= allowed
		and pruning.get_upkeep_cells_taken() > cells_at_capacity,
		"a full ring sheds on its authored interval and still costs the ground it stands on"
	)

	# Deadfall's payoff is that rate. The Evolution takes the ring from shedding a
	# thorn now and then to throwing them off continuously, which is precisely what
	# base Pruning must not do on its own.
	# Read the Evolution's rate without disturbing the run the checks below are
	# standing in: the pairing itself is covered where the Evolutions are.
	var base_interval := pruning.get_replacement_seconds()
	var restore_status := prototype.evolutions.evolution_status
	var restore_evolution := prototype.evolutions.active_evolution
	prototype.evolutions.evolution_status = PhaseBProgression.EvolutionStatus.EVOLVED
	prototype.evolutions.active_evolution = PhaseBProgression.EvolutionId.DEADFALL
	var deadfall_interval := pruning.get_replacement_seconds()
	prototype.evolutions.evolution_status = restore_status
	prototype.evolutions.active_evolution = restore_evolution
	_check(
		is_equal_approx(base_interval, pruning.full_ring_replacement_seconds)
		and is_equal_approx(deadfall_interval, pruning.deadfall_replacement_seconds)
		and deadfall_interval < base_interval * 0.5
		and is_equal_approx(pruning.get_replacement_seconds(), base_interval),
		"DEADFALL turns the ring's occasional shed into continuous fire"
	)

	# The thicket is a disc, not a bare hoop. An enemy that closes all the way to
	# contact is standing in the runners strung between the spikes, not safely inside
	# an empty circle, which is the difference between this and a tripwire.
	prototype.territory_field.reset_field()
	_grow_test_ecosystem(prototype)
	pruning.reset_director()
	var inside_home := _stand_on_owned_ground(prototype)
	for inside_build in range(600):
		if pruning.get_orbit_count() >= 4:
			break
		_graze_owned_ground(prototype, inside_home, float(inside_build) * 0.04)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
	var inside_victim := _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.BOSS,
		prototype.combat.player.get_arena_position()
	)
	var inside_health_before := inside_victim.health
	var inside_orbit := 0
	for inside_step in range(60):
		_graze_owned_ground(prototype, inside_home, float(400 + inside_step) * 0.04)
		inside_victim.position = prototype.combat.player.get_arena_position()
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
		inside_orbit = maxi(inside_orbit, pruning.get_orbit_count())
	_check(
		inside_orbit > 0
		and inside_victim.health < inside_health_before,
		"the thicket sweeps everything the hoop encloses, not only what crosses it"
	)

	# Holding banks Charge and eats the ground underfoot. The player has to graze
	# across their own territory to keep feeding it, because standing still burns
	# the ground out from under them and fires the ring.
	prototype.territory_field.reset_field()
	_grow_test_ecosystem(prototype)
	pruning.reset_director()
	var charge_home := _stand_on_owned_ground(prototype)
	var charge_before := pruning.get_charge()
	var upkeep_before := pruning.get_upkeep_cells_taken()
	var charge_peak := 0.0
	for charge_step in range(int(pruning.charge_seconds * 60.0)):
		_graze_owned_ground(prototype, charge_home, float(charge_step) * 0.04)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
		charge_peak = maxf(charge_peak, pruning.get_charge())
	_check(
		charge_before < 1.0
		and charge_peak > charge_before
		and pruning.get_upkeep_cells_taken() > upkeep_before,
		"holding the ring banks Charge and eats the Green underfoot to do it"
	)

	# Standing on one patch of Green must not feed a ring forever. The drain climbs
	# for every second the ring goes without firing, so a hold that never moves runs
	# its own footing out and fires, however much Green it started on.
	prototype.territory_field.reset_field()
	_grow_test_ecosystem(prototype)
	pruning.reset_director()
	var camp := _stand_on_owned_ground(prototype)
	var camp_rings_before := pruning.get_rings_released()
	var camp_early_rate := 0.0
	var camp_late_rate := 0.0
	for camp_step in range(3600):
		prototype.player.global_position = prototype.territory_field.to_global(camp)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
		if pruning.get_orbit_count() >= pruning.orbit_capacity and camp_early_rate <= 0.0:
			camp_early_rate = pruning.get_upkeep_cells_per_second()
		if pruning.get_hold_seconds() > 20.0:
			camp_late_rate = maxf(camp_late_rate, pruning.get_upkeep_cells_per_second())
		if pruning.get_rings_released() > camp_rings_before:
			break
	_check(
		pruning.get_rings_released() > camp_rings_before
		and pruning.get_hold_seconds() < 60.0
		and (camp_late_rate == 0.0 or camp_late_rate > camp_early_rate),
		"a ring held on one patch of Green burns its own footing out and fires"
	)

	# Upkeep has to outgrow the ring's own damage, or a hold never ends. The check is
	# on the rule rather than on one authored ratio: the property used to live in the
	# Charge ramp alone, and it now lives mostly in the escalation, so comparing the
	# two Charge-scaled rates measured the wrong thing once those were tuned closer
	# together.
	var upkeep_at_zero := pruning.upkeep_cells_per_second
	var upkeep_ceiling := pruning.maximum_upkeep_cells_per_second
	_check(
		pruning.upkeep_escalation_per_second > 0.0
		and upkeep_ceiling / maxf(0.01, upkeep_at_zero)
		> (1.0 + pruning.orbit_charge_damage_bonus)
		and pruning.upkeep_cells_per_second_at_charge >= upkeep_at_zero
		and pruning.launch_charge_damage_bonus > pruning.orbit_charge_damage_bonus,
		"upkeep outgrows the orbit, and the launch is what a long hold actually buys"
	)

	# Stepping off the Green throws the ring. A fresh ring first, since grazing has
	# already burned the ground the previous one was standing on.
	prototype.territory_field.reset_field()
	_grow_test_ecosystem(prototype)
	pruning.reset_director()
	var release_home := _stand_on_owned_ground(prototype)
	# Build only until the ring is loaded. Grazing on burned ground drops the ring on
	# its own, so a fixture that keeps going past a full ring measures nothing.
	for regather_step in range(600):
		if pruning.get_orbit_count() >= 4:
			break
		_graze_owned_ground(prototype, release_home, float(regather_step) * 0.04)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
	var rings_before := pruning.get_rings_released()
	var orbit_before_release := pruning.get_orbit_count()
	var open_ground := _find_open_ground_position(prototype)
	prototype.player.global_position = prototype.territory_field.to_global(open_ground)
	pruning.advance(1.0 / 60.0)
	_check(
		orbit_before_release > 0
		and pruning.get_orbit_count() == 0
		and pruning.get_rings_released() > rings_before
		and is_equal_approx(pruning.get_charge(), 0.0),
		"leaving your own Green fires the whole ring outward and spends the Charge"
	)

	# A discharging hoop bursts outward rather than converging. Sixteen spikes all
	# seeking the nearest enemy overkills one target while the crowd walks past, and
	# it does not read as a ring coming apart either.
	var burst_outward := 0
	var burst_total := 0
	var burst_centre := prototype.combat.player.get_arena_position()
	for cutting in pruning._cuttings:
		if cutting.state != PhaseBPruningDirector.CuttingState.LAUNCHED:
			continue
		burst_total += 1
		if burst_centre.direction_to(cutting.position).dot(
			cutting.velocity.normalized()
		) > 0.7:
			burst_outward += 1
	_check(
		burst_total > 1 and burst_outward == burst_total,
		"a discharging ring bursts outward instead of converging on one enemy"
	)

	# The discharge is the payout, so it has to be the largest number the path puts on
	# screen rather than a couple of seconds of grinding.
	_check(
		pruning.launch_charge_damage_bonus >= 4.0 * pruning.orbit_charge_damage_bonus,
		"a banked discharge pays out far more for Charge than holding the ring does"
	)

	# A bursting spike drives through a crowd instead of stopping in the front rank.
	var burst_pierce := 0
	var burst_falloff := 1.0
	for cutting in pruning._cuttings:
		if cutting.state == PhaseBPruningDirector.CuttingState.LAUNCHED:
			burst_pierce = maxi(burst_pierce, cutting.pierce_remaining)
			burst_falloff = minf(burst_falloff, cutting.pierce_falloff)
	_check(
		burst_pierce >= pruning.cutting_pierce
		and burst_falloff > pruning.cutting_pierce_falloff
		and pruning.launch_pierce_at_charge > 0,
		"discharged spikes drive further through a crowd than a loose Cutting does"
	)


	# The safety floor stops the path spending the last of the run's ground. It is
	# counted in cells, not as a share of the arena: a percentage floor gates the
	# whole path on a state runs rarely reach, which switches Pruning off entirely.
	prototype.territory_field.reset_field()
	for strip_index in range(prototype.territory_field._control.size()):
		if prototype.territory_field._control[strip_index] > 0.0:
			prototype.territory_field._control[strip_index] = 0.0
	prototype.territory_field.recalculate_metrics_now()
	var cycles_before_floor := pruning.get_cycles_run()
	var launched_at_floor := pruning.run_cycle_now()
	_check(
		prototype.territory_field.get_player_cell_count() <= pruning.safety_floor_cells
		and not pruning.is_above_safety_floor()
		and launched_at_floor == 0
		and pruning.get_cycles_run() == cycles_before_floor,
		"Pruning pauses rather than spending the last of the run's territory"
	)

	# The starting foothold must be able to prune. Gating the path on a percentage
	# of the arena meant a real run never reached it and nothing ever fired.
	prototype.territory_field.reset_field()
	prototype.territory_field.recalculate_metrics_now()
	_check(
		prototype.territory_field.get_player_percent() < 10.0
		and pruning.is_above_safety_floor()
		and pruning.get_cycle_target_cells() > 0,
		"a run on its starting foothold can still run a Pruning Cycle"
	)

	# Cut ground grows itself back, so a cycle is a loan rather than a bleed.
	prototype.territory_field.reset_field()
	_grow_test_ecosystem(prototype)
	_stand_on_owned_ground(prototype)
	var green_before_loan := prototype.territory_field.get_player_percent()
	pruning.run_cycle_now()
	prototype.player.global_position = prototype.territory_field.to_global(
		_find_open_ground_position(prototype)
	)
	pruning.advance(1.0 / 60.0)
	prototype.territory_field.recalculate_metrics_now()
	var green_after_cut := prototype.territory_field.get_player_percent()
	_step_field(
		prototype.territory_field,
		int(prototype.territory_field.tuning.simulation_hz * 6.0)
	)
	var green_after_regrowth := prototype.territory_field.get_player_percent()
	_check(
		green_after_cut < green_before_loan
		and green_after_regrowth > green_after_cut,
		"Pruned Ground grows back once the ring is let go, so a burn is a loan"
	)

	# Three of the four lines buy efficiency out of the same ground. Harvest Rate is
	# the one that spends more, and it is priced as a trade: more spikes per second
	# and a faster burn in the same rank, never one without the other.
	var cells_before_upgrades := pruning.get_cycle_target_cells()
	for quiet_line in [
		PhaseBProgression.UpgradeId.PRUNING_CUTTING_YIELD,
		PhaseBProgression.UpgradeId.PRUNING_CUTTING_DAMAGE,
		PhaseBProgression.UpgradeId.PRUNING_CHARGE,
	]:
		prototype.progression._upgrade_levels[quiet_line] = 3
	var cost_unchanged := pruning.get_cycle_target_cells() == cells_before_upgrades
	prototype.progression._upgrade_levels[
		PhaseBProgression.UpgradeId.PRUNING_HARVEST_RATE
	] = 3
	_check(
		cost_unchanged
		and prototype.pruning_director.get_pruning_cutting_yield_multiplier() > 1.0
		and prototype.pruning_director.get_pruning_cutting_damage_multiplier() > 1.0
		and prototype.pruning_director.get_pruning_charge_multiplier() > 1.0
		and pruning.get_charge_seconds() < pruning.charge_seconds
		and pruning.get_launch_charge_damage_bonus() > pruning.launch_charge_damage_bonus
		and prototype.pruning_director.get_pruning_harvest_rate_multiplier() > 1.0
		and pruning.get_cycle_target_cells() > cells_before_upgrades,
		"Pruning lines buy efficiency, and only Harvest Rate spends more to get more"
	)
	for pruning_line in [
		PhaseBProgression.UpgradeId.PRUNING_HARVEST_RATE,
		PhaseBProgression.UpgradeId.PRUNING_CUTTING_YIELD,
		PhaseBProgression.UpgradeId.PRUNING_CUTTING_DAMAGE,
		PhaseBProgression.UpgradeId.PRUNING_CHARGE,
	]:
		prototype.progression._upgrade_levels[pruning_line] = 0

	# The five Pruning pairings.
	var pruning_pairings := [
		[PhaseBProgression.PathId.SPORE, PhaseBProgression.EvolutionId.PIONEER],
		[PhaseBProgression.PathId.BLOOM, PhaseBProgression.EvolutionId.REBOUND],
		[PhaseBProgression.PathId.BRAMBLE, PhaseBProgression.EvolutionId.DEADFALL],
		[PhaseBProgression.PathId.ROOT, PhaseBProgression.EvolutionId.COPPICING],
	]
	var pruning_pairings_resolve := true
	for pairing in pruning_pairings:
		prototype.progression.debug_select_paths(
			PhaseBProgression.PathId.PRUNING,
			pairing[0]
		)
		pruning_pairings_resolve = (
			pruning_pairings_resolve
			and prototype.progression.get_pair_evolution_id() == pairing[1]
		)
	_check(
		pruning_pairings_resolve and pruning_pairings.size() == 4,
		"Pruning pairs into its four authored Evolutions"
	)

	# Coppice: the cut ground erupts with Seeds a moment later.
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.PRUNING,
		PhaseBProgression.PathId.SPORE
	)
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	prototype.territory_field.reset_field()
	_grow_test_ecosystem(prototype)
	prototype.overlay.clear_effects()
	pruning.reset_director()
	_stand_on_owned_ground(prototype)
	for _pioneer_harvest in range(14):
		pruning.run_cycle_now()
	var seeds_before_pioneer := prototype.overlay.get_active_seed_count()
	for _pioneer_step in range(int(prototype.evolutions.pioneer_delay_seconds * 60.0) + 6):
		pruning.advance(1.0 / 60.0)
	_check(
		seeds_before_pioneer == 0
		and prototype.overlay.get_active_seed_count() > 1,
		"Coppice germinates the ground the harvest cut, a moment after it cuts it"
	)

	# Rebound: a Bloom collapses the Green around it and gains Force for it.
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.PRUNING,
		PhaseBProgression.PathId.BLOOM
	)
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	prototype.territory_field.reset_field()
	_grow_test_ecosystem(prototype)
	var rebound_spot := _find_owned_cell_position(prototype)
	var rebound_green_before := prototype.territory_field.get_player_percent()
	var rebound_force := pruning.prune_for_rebound(rebound_spot)
	prototype.territory_field.recalculate_metrics_now()
	_check(
		rebound_force > 0.0
		and rebound_force <= prototype.evolutions.rebound_maximum_force
		and prototype.territory_field.get_player_percent() < rebound_green_before,
		"Rebound collapses Green into the Bloom and pays it back as Force"
	)

	# Deadfall: thorns torn out with the Green become extra Cuttings.
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.PRUNING,
		PhaseBProgression.PathId.BRAMBLE
	)
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	_grow_test_ecosystem(prototype)
	_thorn_all_owned_ground(prototype)
	pruning.reset_director()
	prototype.combat.reset_combat()
	_stand_on_owned_ground(prototype)
	var deadfall_cuttings := pruning.run_cycle_now()
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.PRUNING,
		PhaseBProgression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	_grow_test_ecosystem(prototype)
	_thorn_all_owned_ground(prototype)
	pruning.reset_director()
	_stand_on_owned_ground(prototype)
	var plain_cuttings := pruning.run_cycle_now()
	_check(
		deadfall_cuttings > plain_cuttings,
		"Deadfall turns the thorns the harvest tears out into extra Cuttings"
	)

	# Coppicing: Mature ground is worth more, and comes back faster.
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.PRUNING,
		PhaseBProgression.PathId.ROOT
	)
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	_grow_test_ecosystem(prototype)
	for maturity_index in range(prototype.territory_field._maturity.size()):
		if prototype.territory_field._control[maturity_index] > 0.2:
			prototype.territory_field._maturity[maturity_index] = 1.0
	pruning.reset_director()
	prototype.combat.reset_combat()
	_stand_on_owned_ground(prototype)
	var coppicing_cuttings := pruning.run_cycle_now()
	# Reclamation is only compared once the ring is let go, since holding one stops
	# reclamation outright.
	prototype.player.global_position = prototype.territory_field.to_global(
		_find_open_ground_position(prototype)
	)
	pruning.advance(1.0 / 60.0)
	var coppicing_regrowth := prototype.territory_field._pruned_regrowth_per_second
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.PRUNING,
		PhaseBProgression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	pruning.advance(1.0 / 60.0)
	var plain_regrowth := prototype.territory_field._pruned_regrowth_per_second
	_check(
		coppicing_cuttings > 0
		and coppicing_regrowth > plain_regrowth,
		"Coppicing pays out on ancient ground and drives it back faster"
	)
	prototype.territory_field.reset_field()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.progression.reset_progression()
	prototype.man_eater.reset_man_eater()
	prototype.overlay.clear_effects()
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.progression.reset_progression()
	prototype.man_eater.reset_man_eater()
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.progression.reset_progression()
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false

	var surge_waves := 0
	var normal_waves := 0
	for wave_index in range(1, 13):
		prototype.wave_director.elapsed_seconds = (
			float(wave_index - 1) * prototype.wave_director.wave_duration_seconds + 6.0
		)
		if prototype.wave_director.is_grazer_surge_wave():
			surge_waves += 1
		else:
			normal_waves += 1
	prototype.wave_director.elapsed_seconds = (
		float(prototype.wave_director.grazer_surge_wave_cycle - 2)
		* prototype.wave_director.wave_duration_seconds
		+ 6.0
	)
	var normal_wave_is_surge := prototype.wave_director.is_grazer_surge_wave()
	prototype.wave_director.elapsed_seconds = (
		float(prototype.wave_director.grazer_surge_wave_cycle)
		* prototype.wave_director.wave_duration_seconds
		- 6.0
	)
	_check(
		surge_waves == 3
		and normal_waves == 9
		and prototype.wave_director.grazer_pack_cycle > 1
		and prototype.wave_director.is_grazer_surge_wave()
		and not normal_wave_is_surge,
		"Grazers lead a minority of packs outside the announced surge waves"
	)
	prototype.wave_director.reset_director()

	var grazer_profile := prototype.combat.grazer_profile
	_check(
		grazer_profile.territory_actions_before_recovery > 0
		and grazer_profile.territory_recovery_seconds
		> grazer_profile.territory_action_interval_seconds,
		"Grazers graze in bursts followed by a recovery window"
	)
	prototype.combat.reset_combat()
	prototype.combat._thornshot_remaining = 999.0
	var grazing_enemy := _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.GRAZER,
		prototype.territory_field.cell_to_local(
			Vector2(_find_player_frontier_cells(prototype.territory_field, 1)[0])
		)
	)
	var recovery_observed := false
	var bursts := 0
	for _grazing_step in range(600):
		grazing_enemy.territory_actions_taken = (
			grazer_profile.territory_actions_before_recovery - 1
		)
		grazing_enemy.territory_action_remaining = 0.0
		prototype.combat.simulate_step(1.0 / 60.0)
		bursts += 1
		if (
			grazing_enemy.territory_action_remaining
			> grazer_profile.territory_action_interval_seconds
		):
			recovery_observed = true
			break
	_check(
		recovery_observed and bursts > 0,
		"a Grazer that finishes a burst pauses far longer than its normal action cadence"
	)
	prototype.combat.reset_combat()
	prototype.debug_advance_time(prototype.wave_director.primary_path_choice_seconds)
	var primary_path_options := prototype.progression.get_pending_path_options()
	_check(
		prototype.choice_panel.visible
		and prototype.choice_header.text == "PRIMARY PLANT PATH"
		and primary_path_options.size() == PhaseBProgression.PathId.size()
		and primary_path_options.has(PhaseBProgression.PathId.BRAMBLE)
		and primary_path_options.has(PhaseBProgression.PathId.ROOT),
		"the first path milestone offers every Plant path through the paused choice panel"
	)
	var bramble_choice_index := primary_path_options.find(PhaseBProgression.PathId.BRAMBLE)
	prototype._choose_displayed_option(bramble_choice_index)
	_check(
		prototype.progression.has_path(PhaseBProgression.PathId.BRAMBLE)
		and prototype.territory_field.is_bramble_enabled(),
		"choosing Bramble immediately arms the authoritative Green frontier"
	)

	prototype.progression._upgrade_offer_cursor = (
		PhaseBProgression.UpgradeId.BRAMBLE_ENTANGLEMENT
	)
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var bramble_upgrade_options := prototype.progression.get_pending_upgrade_options()
	var open_slot_draft_paths: Array[int] = []
	for option_id in bramble_upgrade_options:
		var upgrade_path := prototype.progression._get_upgrade_path(option_id)
		if not open_slot_draft_paths.has(upgrade_path):
			open_slot_draft_paths.append(upgrade_path)
	_check(
		bramble_upgrade_options.has(PhaseBProgression.UpgradeId.BRAMBLE_ENTANGLEMENT)
		and open_slot_draft_paths.size() >= 2,
		"drafts expose Bramble's lines and keep offering other paths while a slot is open"
	)
	prototype._choose_displayed_option(0)

	prototype.territory_field.debug_establish_bramble()
	var frontier_position := _find_player_frontier(prototype.territory_field)
	prototype.combat.reset_combat()
	prototype.combat._thornshot_remaining = 999.0
	var bramble_enemy := _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.BOSS,
		frontier_position
	)
	var untangled_tick := prototype.combat.get_bramble_tick_damage(bramble_enemy, 1.0)
	var bramble_enemy_health_before := bramble_enemy.health
	prototype.combat.simulate_step(0.0)
	var crossing_damage := bramble_enemy_health_before - bramble_enemy.health
	var contact_hit_flash := prototype.combat.get_enemy_hit_flash_remaining(bramble_enemy.id)
	# Entanglement builds over seconds, so contact is measured across a stay rather
	# than on the frame the enemy arrives.
	var entangled_health_before := bramble_enemy.health
	for _bramble_step in range(40):
		bramble_enemy.position = frontier_position
		prototype.combat.simulate_step(0.1)
	var entangled_damage := entangled_health_before - bramble_enemy.health
	var entangled_tick := prototype.combat.get_bramble_tick_damage(bramble_enemy, 1.0)
	var baseline_bramble_speed_multiplier := bramble_enemy.movement_speed_multiplier
	_check(
		frontier_position.x >= 0.0
		and crossing_damage > untangled_tick
		and bramble_enemy.entanglement > 0.5
		and entangled_tick > untangled_tick
		and entangled_damage > 0.0
		and baseline_bramble_speed_multiplier < 1.0
		and bramble_enemy.active
		and contact_hit_flash > 0.0
		and prototype.combat.get_active_damage_number_count() > 0,
		"crossing the hedge stings once, then Entanglement ramps thorn damage and slow"
	)

	# Leaving Green sheds Entanglement gradually rather than resetting it, so a
	# brief step off the territory does not shake the thorns loose.
	var entanglement_peak := bramble_enemy.entanglement
	var neutral_position := Vector2(6.0, 6.0)
	bramble_enemy.position = neutral_position
	prototype.combat.simulate_step(0.1)
	var briefly_left := bramble_enemy.entanglement
	for _neutral_step in range(40):
		bramble_enemy.position = neutral_position
		prototype.combat.simulate_step(0.1)
	_check(
		is_equal_approx(
			prototype.territory_field.get_bramble_coverage_at_local(neutral_position),
			0.0
		)
		and briefly_left < entanglement_peak
		and briefly_left > entanglement_peak * 0.8
		and is_equal_approx(bramble_enemy.entanglement, 0.0)
		and is_equal_approx(bramble_enemy.movement_speed_multiplier, 1.0),
		"Entanglement decays off Green instead of resetting the moment contact breaks"
	)

	var slow_before_entanglement_line := prototype.bramble_director.get_slow_fraction()
	# Maxed rather than one rank, because the draft above may already have taken a
	# rank in these lines and the check is that investing deepens the control.
	prototype.progression._upgrade_levels[PhaseBProgression.UpgradeId.BRAMBLE_ENTANGLEMENT] = (
		prototype.progression.maximum_upgrade_level
	)
	prototype.progression._upgrade_levels[PhaseBProgression.UpgradeId.BRAMBLE_REPULSION] = 1
	prototype.progression._upgrade_levels[PhaseBProgression.UpgradeId.BRAMBLE_ENSNARE_RATE] = (
		prototype.progression.maximum_upgrade_level
	)
	prototype._apply_progression_modifiers()
	prototype.combat.reset_combat()
	prototype.combat._thornshot_remaining = 999.0
	var repelled_enemy := _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.ELITE,
		frontier_position
	)
	var repulsion_health_before := repelled_enemy.health
	var repulsion_position_before := repelled_enemy.position
	prototype.combat.repel_territory_attacker(repelled_enemy)
	# The shove travels over time rather than teleporting, so nothing has moved yet
	# on the frame the pulse fires.
	var instant_shove := repulsion_position_before.distance_to(repelled_enemy.position)
	var launched_knockback := repelled_enemy.knockback_remaining > 0.0
	# The pulse itself must deal nothing. Ordinary chip ticks keep resolving while
	# the enemy slides across Green, so damage is sampled on the pulse frame alone.
	var pulse_damage := repulsion_health_before - repelled_enemy.health
	var travelled_partway := 0.0
	var knockback_steps := 0
	while repelled_enemy.knockback_remaining > 0.0 and knockback_steps < 120:
		prototype.combat.simulate_step(1.0 / 60.0)
		knockback_steps += 1
		if knockback_steps == 2:
			travelled_partway = repulsion_position_before.distance_to(
				repelled_enemy.position
			)
	var shoved_distance := repulsion_position_before.distance_to(repelled_enemy.position)
	var repeat_position_before := repelled_enemy.position
	for _repulsion_attempt in range(4):
		prototype.combat.repel_territory_attacker(repelled_enemy)
	var repeat_shove := repeat_position_before.distance_to(repelled_enemy.position)
	_check(
		launched_knockback
		and is_equal_approx(instant_shove, 0.0)
		and travelled_partway > 0.0
		and travelled_partway < shoved_distance
		and knockback_steps > 1
		and shoved_distance > 0.0
		and is_equal_approx(pulse_damage, 0.0)
		and is_equal_approx(repeat_shove, 0.0)
		and prototype.bramble_director.get_slow_fraction()
		> slow_before_entanglement_line
		and prototype.bramble_director.get_ensnare_multiplier() > 1.0,
		"Repulsion slides a territory attacker out over time without damaging it, once per cooldown"
	)

	# Every way an enemy weakens Green counts as an attack, not erosion alone.
	var repelled_behaviours := true
	var checked_behaviours := 0
	for weakening_role in [
		PhaseBCombatDirector.EnemyRole.GRAZER,
		PhaseBCombatDirector.EnemyRole.CORRUPTOR,
		PhaseBCombatDirector.EnemyRole.WARDEN,
	]:
		prototype.combat.reset_combat()
		prototype.combat._thornshot_remaining = 999.0
		var weakening_enemy := _spawn_bramble_contact_enemy(
			prototype,
			weakening_role,
			frontier_position
		)
		# Give the enemy a frame of contact so its ground sample is populated.
		prototype.combat.simulate_step(0.0)
		weakening_enemy.position = frontier_position
		weakening_enemy.bramble_repulsion_remaining = 0.0
		weakening_enemy.knockback_remaining = 0.0
		prototype.combat._perform_enemy_territory_action(weakening_enemy)
		repelled_behaviours = (
			repelled_behaviours and weakening_enemy.knockback_remaining > 0.0
		)
		checked_behaviours += 1
	_check(
		checked_behaviours == 3 and repelled_behaviours,
		"grazing, hostile conversion, and maturity suppression all trigger Repulsion"
	)

	# Grasping Roots: full Entanglement pins an enemy, then an immunity window stops
	# it from being pinned again immediately.
	prototype.progression._upgrade_levels[
		PhaseBProgression.UpgradeId.BRAMBLE_GRASPING_ROOTS
	] = 1
	prototype._apply_progression_modifiers()
	prototype.combat.reset_combat()
	prototype.combat._thornshot_remaining = 999.0
	var rooted_enemy := _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.ELITE,
		frontier_position
	)
	rooted_enemy.entanglement = 0.5
	prototype.combat.simulate_step(0.0)
	var half_entangled_root := rooted_enemy.bramble_root_remaining
	rooted_enemy.entanglement = 1.0
	rooted_enemy.position = frontier_position
	prototype.combat.simulate_step(0.0)
	var root_seconds := rooted_enemy.bramble_root_remaining
	var root_duration_for_indicator := rooted_enemy.bramble_root_duration
	var rooted_speed := rooted_enemy.movement_speed_multiplier
	# Serve out the hold, then confirm the immunity window blocks an instant re-root.
	for _root_step in range(30):
		rooted_enemy.position = frontier_position
		rooted_enemy.entanglement = 1.0
		prototype.combat.simulate_step(0.05)
	_check(
		is_equal_approx(half_entangled_root, 0.0)
		and root_seconds > 0.0
		and is_equal_approx(root_seconds, prototype.bramble_director.get_root_seconds())
		and is_equal_approx(rooted_speed, 0.0)
		and is_equal_approx(rooted_enemy.bramble_root_remaining, 0.0)
		and rooted_enemy.bramble_root_immunity_remaining > 0.0,
		"Grasping Roots pins a fully Entangled enemy, then holds it immune for a spell"
	)
	_check(
		is_equal_approx(root_duration_for_indicator, root_seconds)
		and root_duration_for_indicator > 0.0,
		"a rooted enemy records the hold's full length so its indicator can unwind"
	)
	prototype.progression._upgrade_levels[
		PhaseBProgression.UpgradeId.BRAMBLE_GRASPING_ROOTS
	] = 0
	prototype._apply_progression_modifiers()

	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	# The starting foothold is small and sits away from basalt, so Green is grown
	# onto the upper island first. The rule under test is that unclaimable ground
	# never becomes damaging frontier, not where the fixture happens to begin.
	var basalt_approach := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.350,
		prototype.territory_field.tuning.arena_size.y * 0.340
	)
	prototype.territory_field.queue_seed_growth(basalt_approach, 4.0, 0.0, 1.0, 2.5)
	prototype.territory_field._apply_pending_commands()
	_step_field(prototype.territory_field, 2)
	prototype.territory_field.debug_establish_bramble()
	frontier_position = _find_player_frontier(prototype.territory_field)
	var green_rock_cell := _find_green_unclaimable_cell(prototype.territory_field)
	var green_rock_index := (
		green_rock_cell.y * prototype.territory_field.tuning.field_size.x
		+ green_rock_cell.x
	)
	_check(
		green_rock_cell.x >= 0
		and prototype.territory_field._claimable_mask[green_rock_index] != 0
		and prototype.territory_field._control[green_rock_index]
		> prototype.territory_field.tuning.ownership_threshold
		and not prototype.territory_field._is_player_frontier_cell(
			green_rock_cell.x,
			green_rock_cell.y
		),
		"unclaimable arena and basalt edges do not become damaging Bramble frontier"
	)
	# Measure erosion on the pristine fixture, not on the ground grown out toward
	# the basalt above, because every leg of this comparison resets the field.
	prototype.territory_field.reset_field()
	frontier_position = _find_player_frontier(prototype.territory_field)
	prototype.territory_field.set_bramble_modifiers(false, 1.0)
	var unarmored_before := prototype.territory_field.get_control_at_local(frontier_position)
	prototype.territory_field.queue_erosion(frontier_position, 0.45, 0.5)
	prototype.territory_field._apply_pending_commands()
	var unarmored_loss := (
		unarmored_before - prototype.territory_field.get_control_at_local(frontier_position)
	)
	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.territory_field.debug_establish_bramble()
	var armored_before := prototype.territory_field.get_control_at_local(frontier_position)
	prototype.territory_field.queue_erosion(frontier_position, 0.45, 0.5)
	prototype.territory_field._apply_pending_commands()
	var armored_loss := (
		armored_before - prototype.territory_field.get_control_at_local(frontier_position)
	)
	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(false, 1.0)
	var unarmored_conversion_before := (
		prototype.territory_field.get_control_at_local(frontier_position)
	)
	prototype.territory_field.queue_hostile_growth(frontier_position, 0.45, 0.5)
	prototype.territory_field._apply_pending_commands()
	var unarmored_conversion_loss := (
		unarmored_conversion_before
		- prototype.territory_field.get_control_at_local(frontier_position)
	)
	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.territory_field.debug_establish_bramble()
	var armored_conversion_before := (
		prototype.territory_field.get_control_at_local(frontier_position)
	)
	prototype.territory_field.queue_hostile_growth(frontier_position, 0.45, 0.5)
	prototype.territory_field._apply_pending_commands()
	var armored_conversion_loss := (
		armored_conversion_before
		- prototype.territory_field.get_control_at_local(frontier_position)
	)
	_check(
		unarmored_loss > 0.0
		and armored_loss > 0.0
		and armored_loss < unarmored_loss
		and unarmored_conversion_loss > 0.0
		and armored_conversion_loss > 0.0
		and armored_conversion_loss < unarmored_conversion_loss,
		"selecting Bramble alone hardens the Green frontier against erosion and conversion"
	)

	var field_tuning := prototype.territory_field.tuning
	var contact_band := prototype.combat.bramble_frontier_band_pixels
	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	var growing_frontier := _find_player_frontier(prototype.territory_field)
	var fresh_strength := prototype.territory_field.get_bramble_strength_at_local(
		growing_frontier,
		contact_band
	)
	_step_field(prototype.territory_field, int(round(field_tuning.simulation_hz * 1.5)))
	var developing_strength := prototype.territory_field.get_bramble_strength_at_local(
		growing_frontier,
		contact_band
	)
	_step_field(prototype.territory_field, int(round(field_tuning.simulation_hz * 2.5)))
	var developed_strength := prototype.territory_field.get_bramble_strength_at_local(
		growing_frontier,
		contact_band
	)
	_check(
		is_equal_approx(fresh_strength, field_tuning.bramble_minimum_strength)
		and developing_strength > fresh_strength
		and developing_strength < 1.0
		and developed_strength > developing_strength
		and is_equal_approx(developed_strength, 1.0),
		"newly exposed Bramble starts near minimum strength and matures to full thorns over seconds"
	)

	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	var development_cells := _find_player_frontier_cells(prototype.territory_field, 2)
	var field_width := prototype.territory_field.tuning.field_size.x
	var fresh_index := development_cells[0].y * field_width + development_cells[0].x
	var mature_index := development_cells[1].y * field_width + development_cells[1].x
	prototype.territory_field._maturity[fresh_index] = 0.0
	prototype.territory_field._maturity[mature_index] = 1.0
	prototype.territory_field._bramble_development[fresh_index] = 0.0
	prototype.territory_field._bramble_development[mature_index] = 0.0
	prototype.territory_field.step_simulation()
	_check(
		development_cells[0].x >= 0
		and prototype.territory_field._player_frontier_mask[fresh_index] != 0
		and prototype.territory_field._player_frontier_mask[mature_index] != 0
		and prototype.territory_field._bramble_development[mature_index]
		> prototype.territory_field._bramble_development[fresh_index],
		"mature Green establishes Bramble faster than freshly created territory"
	)

	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.territory_field.debug_establish_bramble()
	var wound_position := _find_player_frontier(prototype.territory_field)
	var wound_cell := prototype.territory_field.local_to_cell(wound_position)
	var wound_index := (
		int(round(wound_cell.y)) * field_width + int(round(wound_cell.x))
	)
	var wound_development_before: float = (
		prototype.territory_field._bramble_development[wound_index]
	)
	var wound_steps := PackedFloat32Array()
	for _wound_bite in range(3):
		prototype.territory_field.queue_erosion(wound_position, 0.45, 0.5)
		prototype.territory_field._apply_pending_commands()
		wound_steps.append(prototype.territory_field._bramble_development[wound_index])
	var wound_degrades_in_bands := true
	var previous_wound_development := wound_development_before
	for wound_step in wound_steps:
		wound_degrades_in_bands = (
			wound_degrades_in_bands
			and wound_step < previous_wound_development
			and previous_wound_development - wound_step
			<= field_tuning.bramble_disturbance_maximum_step + 0.0001
		)
		previous_wound_development = wound_step
	_check(
		is_equal_approx(wound_development_before, 1.0)
		and wound_degrades_in_bands
		and wound_steps[0] > 0.0
		and wound_steps[2] < wound_steps[0],
		"erosion degrades established thorns through bands instead of erasing them"
	)
	_check(
		prototype.territory_field._bramble_alert[wound_index] > 0.0,
		"a bitten frontier section is flagged as under attack so it regrows faster"
	)

	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.territory_field.step_simulation()
	var behind_index := _find_deep_owned_cell(prototype.territory_field, contact_band)
	var behind_position := prototype.territory_field.cell_to_local(
		Vector2(behind_index % field_width, behind_index / field_width)
	)
	var interior_coverage := prototype.territory_field.get_bramble_coverage_at_local(
		behind_position
	)
	var interior_frontier_strength := prototype.territory_field.get_bramble_strength_at_local(
		behind_position,
		contact_band
	)
	prototype.territory_field.set_bramble_modifiers(false, 1.0)
	var unarmed_coverage := prototype.territory_field.get_bramble_coverage_at_local(
		behind_position
	)
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	_check(
		behind_index >= 0
		and is_equal_approx(interior_coverage, 1.0)
		and is_equal_approx(interior_frontier_strength, 0.0)
		and is_equal_approx(unarmed_coverage, 0.0),
		"every cell of owned Green carries Bramble even where no frontier hedge stands"
	)

	# Bury a stretch of frontier under friendly growth: the hedge bonus goes, the
	# hazard itself does not, which is what frees Bramble from frontier geometry.
	var buried_cells := _find_player_frontier_cells(prototype.territory_field, 1)
	var buried_index := buried_cells[0].y * field_width + buried_cells[0].x
	var buried_position := prototype.territory_field.cell_to_local(
		Vector2(buried_cells[0])
	)
	prototype.territory_field.queue_seed_growth(buried_position, 3.0, 0.0, 1.0, 2.0)
	prototype.territory_field._apply_pending_commands()
	_step_field(prototype.territory_field, 6)
	var buried_strength := prototype.territory_field.get_bramble_strength_at_local(
		buried_position,
		contact_band
	)
	_check(
		prototype.territory_field._player_frontier_mask[buried_index] == 0
		and is_equal_approx(buried_strength, 0.0)
		and is_equal_approx(
			prototype.territory_field.get_bramble_coverage_at_local(buried_position),
			1.0
		),
		"ground the frontier moves off keeps its Bramble and only loses the hedge bonus"
	)

	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	var mature_start_cells := _find_player_frontier_cells(prototype.territory_field, 2)
	var mature_start_index := mature_start_cells[0].y * field_width + mature_start_cells[0].x
	var bare_index := mature_start_cells[1].y * field_width + mature_start_cells[1].x
	prototype.territory_field._maturity[mature_start_index] = 1.0
	prototype.territory_field._maturity[bare_index] = 0.0
	prototype.territory_field._bramble_development[mature_start_index] = 0.0
	prototype.territory_field._bramble_development[bare_index] = 0.0
	prototype.territory_field.step_simulation()
	_check(
		prototype.territory_field._bramble_development[mature_start_index]
		>= field_tuning.bramble_mature_starting_development
		and prototype.territory_field._bramble_development[bare_index]
		< field_tuning.bramble_mature_starting_development,
		"newly exposed Mature Green starts with thorns while fresh ground starts bare"
	)

	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.territory_field.debug_establish_bramble()
	var tough_position := _find_player_frontier(prototype.territory_field)
	var tough_cell := prototype.territory_field.local_to_cell(tough_position)
	var tough_index := (
		int(round(tough_cell.y)) * field_width + int(round(tough_cell.x))
	)
	var developed_control_before: float = prototype.territory_field._control[tough_index]
	prototype.territory_field.queue_erosion(tough_position, 0.45, 0.5)
	prototype.territory_field._apply_pending_commands()
	var developed_control_loss := (
		developed_control_before - prototype.territory_field._control[tough_index]
	)
	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	var fresh_control_before: float = prototype.territory_field._control[tough_index]
	prototype.territory_field.queue_erosion(tough_position, 0.45, 0.5)
	prototype.territory_field._apply_pending_commands()
	var fresh_control_loss := (
		fresh_control_before - prototype.territory_field._control[tough_index]
	)
	_check(
		fresh_control_loss > 0.0
		and developed_control_loss > 0.0
		and developed_control_loss < fresh_control_loss,
		"Grazers chew Fresh ground quickly but slow down against established thorns"
	)

	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	_step_field(prototype.territory_field, 4)
	var rebuilt_frontier := _maximum_frontier_development(prototype.territory_field)
	_check(
		rebuilt_frontier > 0.0,
		"a frontier that has just moved grows a fresh hedge without any stored memory"
	)

	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.territory_field.debug_establish_bramble()
	var harvest_position := _find_player_frontier(prototype.territory_field)
	var far_cells := _find_player_frontier_cells(prototype.territory_field, 1)
	var far_index := far_cells[0].y * field_width + far_cells[0].x
	var distant_index := _find_distant_frontier_index(
		prototype.territory_field,
		harvest_position,
		260.0
	)
	var distant_before := 0.0
	if distant_index >= 0:
		distant_before = prototype.territory_field._bramble_development[distant_index]
	var harvest := prototype.territory_field.harvest_bramble_in_radius(
		harvest_position,
		110.0
	)
	var harvested_cell_cleared := is_equal_approx(
		prototype.territory_field._bramble_development[far_index],
		0.0
	)
	var distant_after := 0.0
	if distant_index >= 0:
		distant_after = prototype.territory_field._bramble_development[distant_index]
	_check(
		harvest.amount > 0.0
		and harvest.cell_count > 0
		and harvested_cell_cleared
		and distant_index >= 0
		and is_equal_approx(distant_before, distant_after),
		"harvesting consumes thorns only inside its own radius and never elsewhere"
	)


	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.territory_field.debug_establish_bramble()
	prototype.combat.set_bramble_modifiers(true, 0.0)
	prototype.combat.reset_combat()
	prototype.combat._thornshot_remaining = 999.0
	var single_tick_frontier := _find_player_frontier(prototype.territory_field)
	var single_tick_enemy := _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.BOSS,
		single_tick_frontier
	)
	# Already inside the hedge, so only the repeating tick is measured.
	single_tick_enemy.was_on_bramble = true
	var single_tick_health_before := single_tick_enemy.health
	prototype.combat.simulate_step(0.0)
	var single_tick_damage := single_tick_health_before - single_tick_enemy.health
	var single_tick_expected := prototype.combat.get_bramble_tick_damage(
		single_tick_enemy,
		1.0
	)
	_check(
		is_equal_approx(single_tick_damage, single_tick_expected),
		"thorn damage resolves once per enemy from local strength instead of stacking per Green cell"
	)

	prototype.combat.reset_combat()
	prototype.combat._thornshot_remaining = 999.0
	var crossing_enemy := _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.BOSS,
		single_tick_frontier
	)
	var crossing_health_before := crossing_enemy.health
	prototype.combat.simulate_step(0.0)
	var first_crossing_damage := crossing_health_before - crossing_enemy.health
	var repeat_crossing_before := crossing_enemy.health
	for _crossing_attempt in range(4):
		crossing_enemy.position = single_tick_frontier
		crossing_enemy.was_on_bramble = false
		crossing_enemy.bramble_damage_remaining = 999.0
		prototype.combat.simulate_step(0.0)
	var repeat_crossing_damage := repeat_crossing_before - crossing_enemy.health
	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.combat.reset_combat()
	prototype.combat._thornshot_remaining = 999.0
	var fresh_crossing_enemy := _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.BOSS,
		_find_player_frontier(prototype.territory_field)
	)
	var fresh_crossing_health := fresh_crossing_enemy.health
	prototype.combat.simulate_step(0.0)
	var fresh_crossing_damage := fresh_crossing_health - fresh_crossing_enemy.health
	_check(
		first_crossing_damage > single_tick_expected
		and is_equal_approx(repeat_crossing_damage, 0.0)
		and fresh_crossing_damage < first_crossing_damage,
		"the hedge crossing hit needs established thorns and respects a per-enemy cooldown"
	)

	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.territory_field.debug_establish_bramble()
	prototype.combat.set_bramble_modifiers(true, 0.0)
	prototype.combat.reset_combat()
	prototype.combat._thornshot_remaining = 999.0
	var thorn_frontier := _find_player_frontier(prototype.territory_field)
	prototype.combat.set_enemy_scaling(1.0, 1.0)
	var small_enemy := _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.HUNTER,
		thorn_frontier
	)
	var large_enemy := _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.BOSS,
		thorn_frontier
	)
	var small_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	var large_tick := prototype.combat.get_bramble_tick_damage(large_enemy, 1.0)
	_check(
		small_enemy != null
		and large_enemy != null
		and large_enemy.maximum_health > small_enemy.maximum_health
		and small_tick > prototype.combat.bramble_contact_damage
		and large_tick > small_tick
		and is_equal_approx(
			large_tick - small_tick,
			(large_enemy.maximum_health - small_enemy.maximum_health)
			* prototype.combat.bramble_max_health_damage_fraction
		),
		"thorn ticks add a maximum-health component so thorns keep scaling into late-game health pools"
	)

	var bramble_lines_are_control_shaped := true
	for bramble_line in [
		PhaseBProgression.UpgradeId.BRAMBLE_ENTANGLEMENT,
		PhaseBProgression.UpgradeId.BRAMBLE_ENSNARE_RATE,
		PhaseBProgression.UpgradeId.BRAMBLE_GRASPING_ROOTS,
		PhaseBProgression.UpgradeId.BRAMBLE_REPULSION,
	]:
		bramble_lines_are_control_shaped = (
			bramble_lines_are_control_shaped
			and prototype.progression._get_upgrade_path(bramble_line)
			== PhaseBProgression.PathId.BRAMBLE
		)
	var thorn_damage_tick_before := prototype.combat.get_bramble_tick_damage(
		small_enemy,
		1.0
	)
	for bramble_line in [
		PhaseBProgression.UpgradeId.BRAMBLE_ENTANGLEMENT,
		PhaseBProgression.UpgradeId.BRAMBLE_ENSNARE_RATE,
		PhaseBProgression.UpgradeId.BRAMBLE_GRASPING_ROOTS,
		PhaseBProgression.UpgradeId.BRAMBLE_REPULSION,
	]:
		prototype.progression._upgrade_levels[bramble_line] = (
			prototype.progression.maximum_upgrade_level
		)
	prototype._apply_progression_modifiers()
	var thorn_damage_tick_after := prototype.combat.get_bramble_tick_damage(
		small_enemy,
		1.0
	)
	for bramble_line in [
		PhaseBProgression.UpgradeId.BRAMBLE_ENTANGLEMENT,
		PhaseBProgression.UpgradeId.BRAMBLE_ENSNARE_RATE,
		PhaseBProgression.UpgradeId.BRAMBLE_GRASPING_ROOTS,
		PhaseBProgression.UpgradeId.BRAMBLE_REPULSION,
	]:
		prototype.progression._upgrade_levels[bramble_line] = 0
	prototype._apply_progression_modifiers()
	prototype.combat.set_bramble_modifiers(true, 0.0)
	_check(
		bramble_lines_are_control_shaped
		and is_equal_approx(thorn_damage_tick_after, thorn_damage_tick_before),
		"every Bramble line is crowd control: maxing all four leaves thorn damage flat"
	)

	var fresh_contact_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	small_enemy.entanglement = 0.5
	var half_entangled_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	small_enemy.entanglement = 1.0
	var fully_entangled_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	small_enemy.entanglement = 0.0
	_check(
		half_entangled_tick > fresh_contact_tick
		and fully_entangled_tick > half_entangled_tick
		and is_equal_approx(
			fully_entangled_tick,
			fresh_contact_tick * prototype.combat.bramble_entangled_damage_multiplier
		),
		"Entanglement ramps thorn damage from a modest first touch to an authored maximum"
	)

	var unrooted_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	small_enemy.bramble_ground_maturity = 1.0
	var fresh_ground_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	prototype.combat.set_bramble_modifiers(true, 0.0, 1.0, 0.0, 4.0, 0.0, false, 0.50)
	var mature_ground_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	small_enemy.bramble_ground_maturity = 0.0
	var root_network_fresh_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	prototype.combat.set_bramble_modifiers(true, 0.0)
	_check(
		is_equal_approx(fresh_ground_tick, unrooted_tick)
		and mature_ground_tick > fresh_ground_tick
		and is_equal_approx(root_network_fresh_tick, unrooted_tick),
		"the Root Network sharpens thorns on Mature ground and only for a run holding Root"
	)

	var isolated_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	small_enemy.bramble_horde_count = 2
	var crowded_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	small_enemy.bramble_horde_count = 500
	var capped_horde_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	small_enemy.bramble_horde_count = 0
	_check(
		crowded_tick > isolated_tick
		and capped_horde_tick > crowded_tick
		and is_equal_approx(
			capped_horde_tick,
			isolated_tick * (1.0 + prototype.combat.bramble_horde_damage_maximum_bonus)
		),
		"local horde pressure strengthens a besieged Bramble section within a fixed cap"
	)

	prototype.combat.reset_combat()
	prototype.combat._thornshot_remaining = 999.0
	var shared_enemies: Array[PhaseBCombatDirector.EnemyState] = []
	var shared_health_before := PackedFloat32Array()
	for _shared_index in range(4):
		var shared_enemy := _spawn_bramble_contact_enemy(
			prototype,
			PhaseBCombatDirector.EnemyRole.HUNTER,
			thorn_frontier
		)
		shared_enemy.was_on_bramble = true
		shared_enemies.append(shared_enemy)
		shared_health_before.append(shared_enemy.health)
	prototype.combat.simulate_step(0.0)
	var shared_expected_tick := prototype.combat.get_bramble_tick_damage(
		shared_enemies[0],
		1.0
	)
	var undivided_damage := true
	for shared_index in range(shared_enemies.size()):
		var shared_damage := (
			shared_health_before[shared_index] - shared_enemies[shared_index].health
		)
		undivided_damage = (
			undivided_damage
			and is_equal_approx(shared_damage, shared_expected_tick)
		)
	_check(
		shared_enemies.size() == 4
		and shared_expected_tick > isolated_tick
		and undivided_damage,
		"every enemy on one stretch of Green takes its own full thorn tick, never a divided share"
	)

	prototype._apply_progression_modifiers()

	prototype.debug_advance_time(
		prototype.wave_director.secondary_path_choice_seconds - prototype.get_elapsed_seconds()
	)
	var secondary_path_options := prototype.progression.get_pending_path_options()
	_check(
		prototype.choice_header.text == "SECONDARY PLANT PATH"
		and secondary_path_options.size() == PhaseBProgression.PathId.size() - 1
		and not secondary_path_options.has(PhaseBProgression.PathId.BRAMBLE),
		"the second path milestone excludes the committed primary path and locks a two-path build"
	)
	var spore_choice_index := secondary_path_options.find(PhaseBProgression.PathId.SPORE)
	prototype._choose_displayed_option(spore_choice_index)

	prototype.progression._upgrade_offer_cursor = (
		PhaseBProgression.UpgradeId.BLOOM_FORCE
	)
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var locked_draft_options := prototype.progression.get_pending_upgrade_options()
	var locked_draft_is_filtered := not locked_draft_options.is_empty()
	for option_id in locked_draft_options:
		var locked_path := prototype.progression._get_upgrade_path(option_id)
		locked_draft_is_filtered = (
			locked_draft_is_filtered
			and (
				locked_path == PhaseBProgression.UNSELECTED_PATH
				or prototype.progression.has_path(locked_path)
			)
		)
	_check(
		locked_draft_is_filtered
		and not locked_draft_options.has(PhaseBProgression.UpgradeId.BLOOM_FORCE),
		"a run holding both paths narrows its drafts back to the committed lines"
	)
	prototype._choose_displayed_option(0)

	prototype.progression.debug_complete_evolution_requirements()
	var briar_ready := prototype.progression.grant_evolution_if_ready()
	prototype.combat.reset_combat()
	var briar_center := Vector2(330.0, 360.0)
	prototype.spore_director.on_seed_germinated(briar_center, 0)
	_check(
		briar_ready
		and prototype.progression.active_evolution
		== PhaseBProgression.EvolutionId.BRIAR_PODS
		and prototype.combat.get_active_briar_pod_count() == 1,
		"Spore plus Bramble evolves into Briar Pods that raise temporary thorn perimeters"
	)
	prototype.combat._thornshot_remaining = 999.0
	var briar_ring_position := (
		briar_center + Vector2(prototype.evolutions.briar_pod_radius_pixels, 0.0)
	)
	var briar_enemy := _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.BOSS,
		briar_ring_position
	)
	var briar_enemy_health_before := briar_enemy.health
	for _briar_step in range(20):
		briar_enemy.position = briar_ring_position
		prototype.combat.simulate_step(0.1)
	_check(
		briar_enemy.health < briar_enemy_health_before
		and briar_enemy.entanglement > 0.0
		and briar_enemy.movement_speed_multiplier < 1.0,
		"a Briar Pod's visible perimeter applies amplified Bramble damage and slow"
	)
	prototype.combat.reset_combat()
	prototype.combat._thornshot_remaining = 999.0
	var briar_wall_center := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.475,
		prototype.territory_field.tuning.arena_size.y * 0.20
	)
	var briar_wall_shadow := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.56,
		prototype.territory_field.tuning.arena_size.y * 0.20
	)
	prototype.combat.spawn_briar_pod(
		briar_wall_center,
		briar_wall_center.distance_to(briar_wall_shadow),
		prototype.evolutions.briar_pod_duration_seconds,
		prototype.evolutions.briar_pod_contact_multiplier
	)
	var briar_shadow_enemy_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.ELITE,
		briar_wall_shadow
	)
	var briar_shadow_health_before := prototype.combat.get_enemy_health(briar_shadow_enemy_id)
	prototype.combat.simulate_step(0.0)
	_check(
		is_equal_approx(
			prototype.combat.get_enemy_health(briar_shadow_enemy_id),
			briar_shadow_health_before
		),
		"Briar Pod damage cannot extend through basalt walls"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.BLOOM,
		PhaseBProgression.PathId.BRAMBLE
	)
	prototype.advance_run(4.10)
	_check(
		prototype.overlay.get_active_bloom_count() == 1,
		"the Bloom path automatically plants a visible windup near a threat"
	)
	prototype.progression.debug_complete_evolution_requirements()
	var thornburst_ready := prototype.progression.grant_evolution_if_ready()

	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	prototype.combat.reset_combat()
	var trap_position := _find_deep_owned_position(prototype.territory_field)
	# No frontier hedge is established here: the harvest draws on the Bramble
	# covering the territory, which is what frees Thornburst from frontier geometry.
	prototype.bloom_director.on_bloom_detonated(trap_position, 0)
	var traps_from_harvest := prototype.combat.get_active_briar_trap_count()
	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	prototype.territory_field.set_bramble_modifiers(false, 1.0)
	prototype.bloom_director.on_bloom_detonated(trap_position, 0)
	var traps_without_bramble := prototype.combat.get_active_briar_trap_count()
	prototype.territory_field.set_bramble_modifiers(true, 2.0)
	_check(
		thornburst_ready
		and prototype.progression.active_evolution
		== PhaseBProgression.EvolutionId.THORNBURST
		and traps_from_harvest > 0
		and traps_without_bramble == 0,
		"Thornburst harvests Bramble-covered territory into a field of Briar Traps"
	)

	# A trap waits for prey, blows once, and lights its neighbours.
	prototype.combat.reset_combat()
	prototype.combat._thornshot_remaining = 999.0
	prototype.combat.spawn_briar_trap(trap_position, 60.0, 12.0, 30.0, 0.30)
	prototype.combat.spawn_briar_trap(
		trap_position + Vector2(70.0, 0.0),
		60.0,
		12.0,
		30.0,
		0.30
	)
	var armed_traps := prototype.combat.get_active_briar_trap_count()
	prototype.combat.simulate_step(0.05)
	var idle_traps := prototype.combat.get_active_briar_trap_count()
	var trap_victim := _spawn_bramble_contact_enemy(
		prototype,
		PhaseBCombatDirector.EnemyRole.ELITE,
		trap_position
	)
	var trap_victim_health_before := trap_victim.health
	prototype.combat.simulate_step(0.0)
	var trap_damage_dealt := trap_victim_health_before - trap_victim.health
	var trap_entanglement_applied := trap_victim.entanglement
	var traps_after_trigger := prototype.combat.get_active_briar_trap_count()
	prototype.combat.simulate_step(
		prototype.combat.briar_trap_chain_delay_seconds + 0.01
	)
	_check(
		armed_traps == 2
		and idle_traps == 2
		and traps_after_trigger == 1
		and trap_damage_dealt > 0.0
		and trap_entanglement_applied > 0.0
		and prototype.combat.get_active_briar_trap_count() == 0,
		"a triggered Briar Trap detonates and chains into the traps beside it"
	)

	prototype.combat.reset_combat()
	prototype.combat.spawn_briar_trap(trap_position, 60.0, 1.0, 30.0, 0.30)
	prototype.combat.simulate_step(1.10)
	_check(
		prototype.combat.get_active_briar_trap_count() == 0,
		"an untriggered Briar Trap rots away instead of filling the arena with mines"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	var offered_level := prototype.progression.current_level
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	_check(
		prototype.choice_panel.visible
		and prototype.territory_field.simulation_paused
		and prototype.progression.has_pending_upgrade_choice(),
		"level-up pauses the living field and presents a three-choice upgrade offer"
	)
	var selected_upgrade := prototype.progression.get_pending_upgrade_options()[0]
	prototype._choose_displayed_option(0)
	_check(
		prototype.progression.current_level == offered_level + 1
		and prototype.progression.get_upgrade_level(selected_upgrade) == 1
		and not prototype.choice_panel.visible,
		"choosing an upgrade commits one of the six growth lines and resumes play"
	)

	prototype.progression.reset_progression()
	var final_level_upgrade := PhaseBProgression.UpgradeId.THORNSHOT_POWER
	prototype.progression._upgrade_levels[final_level_upgrade] = (
		prototype.progression.maximum_upgrade_level - 1
	)
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var final_level_offer_index := prototype.progression.get_pending_upgrade_options().find(
		final_level_upgrade
	)
	_check(
		final_level_offer_index >= 0
		and prototype.choice_buttons[final_level_offer_index].text.contains("LEVEL 4 → 5")
		and not prototype.choice_buttons[final_level_offer_index].text.contains("5/5"),
		"a final-rank draft clearly says level 4 to 5 instead of presenting itself as already 5/5"
	)
	prototype._choose_displayed_option(final_level_offer_index)
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var post_max_options := prototype.progression.get_pending_upgrade_options()
	var post_max_options_are_valid := not post_max_options.has(final_level_upgrade)
	for option_id in post_max_options:
		post_max_options_are_valid = (
			post_max_options_are_valid
			and prototype.progression.get_upgrade_level(option_id)
			< prototype.progression.maximum_upgrade_level
		)
	_check(
		post_max_options_are_valid,
		"an upgrade at level 5 is excluded from every subsequent draft option"
	)
	prototype._choose_displayed_option(0)

	# Ecosystem Metabolism. Nothing here is bought any more: the three axes describe
	# the organism, so what moves them is the physiology the run developed and how much
	# organism there actually is. Nothing must be buyable, and nothing must move on the
	# run clock alone.
	var metabolism := prototype.metabolism
	var network := prototype.root_network
	metabolism.reset_metabolism()
	network.reset_network()
	prototype.progression.reset_progression()
	var mass_level_before := metabolism.get_level(PhaseBMetabolism.SystemId.PHOTOSYNTHESIS)
	var cambium_before := metabolism.get_level(PhaseBMetabolism.SystemId.CAMBIUM)
	for _idle_step in range(300):
		metabolism.advance(1.0 / 30.0)
	_check(
		metabolism.get_level(PhaseBMetabolism.SystemId.PHOTOSYNTHESIS) == mass_level_before
		and metabolism.get_level(PhaseBMetabolism.SystemId.CAMBIUM) == cambium_before,
		"the run clock alone never moves a physical axis"
	)

	# Each axis is governed by exactly one developmental domain, and developing that
	# domain is what raises it. The doc's own mapping: storage feeds Mass, vascular
	# output feeds Push, anchoring feeds Hold.
	var axis_moves := true
	for system_id in [
		PhaseBMetabolism.SystemId.PHOTOSYNTHESIS,
		PhaseBMetabolism.SystemId.MERISTEM,
		PhaseBMetabolism.SystemId.CAMBIUM,
	]:
		var before: int = metabolism.get_level(system_id)
		network.debug_grant_development(PhaseBMetabolism.get_axis_domain(system_id))
		if metabolism.get_level(system_id) != before + 1:
			axis_moves = false
	_check(
		axis_moves,
		"each physical axis is raised by the developmental domain the doc assigns it"
	)

	# The other half of the physique cannot be bought at all: a larger rooted organism
	# is physically more massive, pushes harder, and holds together better, so the
	# economy follows the simulation rather than decorating it.
	metabolism.reset_metabolism()
	network.reset_network()
	var organism_bonus := metabolism.get_organism_rank_bonus()
	var rooted_percent := prototype.territory_field.get_rooted_territory_percent()
	_check(
		organism_bonus == int(floor(rooted_percent / metabolism.rooted_percent_per_rank))
		and metabolism.get_level(PhaseBMetabolism.SystemId.PHOTOSYNTHESIS)
		== 1 + organism_bonus,
		"an axis carries the organism's own rooted size as well as its developed rank"
	)

	# The Clover machine. Territory is the stake and the payout is a Path event, which is
	# the point of the whole feature: what is risked comes off the organism and what is
	# won lands on the battlefield, so they are not one axis wearing two names.
	var machine := prototype.slot_machine
	var clover_odds := prototype.clover_odds
	var selector := prototype.wager_selector
	var jackpots := prototype.clover_jackpots
	var grace := prototype.all_in_grace
	machine.reset_machine()
	clover_odds.reset_odds()
	jackpots.reset_jackpots()
	grace.reset_grace()
	prototype.progression.reset_progression()

	# The winning grammar. A Clover stands in for a missing Path symbol and for nothing
	# else: it never completes a Bust, and it never picks between two different Paths.
	var wild_completes := CloverSlot.resolve_outcome(PackedInt32Array([
		CloverSlot.Symbol.BLOOM,
		CloverSlot.Symbol.CLOVER,
		CloverSlot.Symbol.BLOOM,
	]))
	var clover_bust := CloverSlot.resolve_outcome(PackedInt32Array([
		CloverSlot.Symbol.BUST,
		CloverSlot.Symbol.BUST,
		CloverSlot.Symbol.CLOVER,
	]))
	var mixed_paths := CloverSlot.resolve_outcome(PackedInt32Array([
		CloverSlot.Symbol.BLOOM,
		CloverSlot.Symbol.ROOT,
		CloverSlot.Symbol.CLOVER,
	]))
	_check(
		wild_completes == CloverSlot.Outcome.PATH_JACKPOT
		and CloverSlot.resolve_path(PackedInt32Array([
			CloverSlot.Symbol.BLOOM,
			CloverSlot.Symbol.CLOVER,
			CloverSlot.Symbol.BLOOM,
		])) == CloverSlot.Symbol.BLOOM
		and clover_bust == CloverSlot.Outcome.WHIFF
		and mixed_paths == CloverSlot.Outcome.WHIFF
		and CloverSlot.resolve_outcome(PackedInt32Array([
			CloverSlot.Symbol.CLOVER,
			CloverSlot.Symbol.CLOVER,
			CloverSlot.Symbol.CLOVER,
		])) == CloverSlot.Outcome.TRIPLE_CLOVER,
		"a Clover completes a Path pair, never a Bust, and never chooses between two Paths"
	)

	# The reels are built to represent a result that was already decided, so a face the
	# machine draws must never resolve to a different outcome than the one it was asked
	# for. A whiff that accidentally reads as a jackpot is the one bug in a slot machine
	# that cannot be argued with.
	var display_mismatches := 0
	var whiff_teases := 0
	for _display_index in range(4000):
		for outcome in [
			CloverSlot.Outcome.WHIFF,
			CloverSlot.Outcome.PATH_JACKPOT,
			CloverSlot.Outcome.TRIPLE_CLOVER,
			CloverSlot.Outcome.TRIPLE_BUST,
		]:
			var wanted_path := clover_odds.pick_path()
			var faces := clover_odds.build_display(outcome, wanted_path)
			if CloverSlot.resolve_outcome(faces) != outcome:
				display_mismatches += 1
			if outcome == CloverSlot.Outcome.PATH_JACKPOT \
				and CloverSlot.resolve_path(faces) != wanted_path:
				display_mismatches += 1
			if outcome == CloverSlot.Outcome.WHIFF and faces[0] == faces[1]:
				whiff_teases += 1
	_check(
		display_mismatches == 0 and whiff_teases > 0,
		"every constructed line shows exactly the result it was built for, teases included (%d teases, %d mismatches)"
			% [whiff_teases, display_mismatches]
	)

	# Truthful odds. Whatever protection is running underneath, the four outcome chances
	# have to be a probability distribution, because they are also the numbers printed
	# on the readout.
	var odds_sum_error := 0.0
	for stake in range(CloverSlot.Stake.size()):
		var stake_odds := clover_odds.get_effective_odds(stake)
		odds_sum_error = maxf(odds_sum_error, absf(
			float(stake_odds["path_jackpot"])
			+ float(stake_odds["triple_clover"])
			+ float(stake_odds["triple_bust"])
			+ float(stake_odds["whiff"])
			- 1.0
		))
	_check(odds_sum_error < 0.0001, "the printed odds are a complete distribution")

	# Drought protection begins only after a real drought, takes its extra chance out of
	# Whiff alone, and is counted per stake so cheap Low spins cannot charge up pity and
	# have it cashed out on an All In.
	clover_odds.reset_odds()
	var dry_base := clover_odds.get_effective_odds(CloverSlot.Stake.MEDIUM)
	for _dry_spin in range(clover_odds.drought_grace_spins):
		clover_odds.note_outcome(CloverSlot.Stake.MEDIUM, CloverSlot.Outcome.WHIFF)
	var dry_at_grace := clover_odds.get_effective_odds(CloverSlot.Stake.MEDIUM)
	clover_odds.note_outcome(CloverSlot.Stake.MEDIUM, CloverSlot.Outcome.WHIFF)
	var dry_past_grace := clover_odds.get_effective_odds(CloverSlot.Stake.MEDIUM)
	var untouched_stake := clover_odds.get_effective_odds(CloverSlot.Stake.ALL_IN)
	_check(
		is_equal_approx(float(dry_at_grace["path_jackpot"]), float(dry_base["path_jackpot"]))
		and float(dry_past_grace["path_jackpot"]) > float(dry_base["path_jackpot"])
		and is_equal_approx(
			float(dry_past_grace["triple_clover"]), float(dry_base["triple_clover"])
		)
		and is_equal_approx(
			float(dry_past_grace["triple_bust"]), float(dry_base["triple_bust"])
		)
		and float(dry_past_grace["whiff"]) < float(dry_base["whiff"])
		and clover_odds.get_drought(CloverSlot.Stake.ALL_IN) == 0
		and is_equal_approx(
			float(untouched_stake["path_jackpot"]),
			clover_odds.path_jackpot_chances[CloverSlot.Stake.ALL_IN]
		),
		"pity starts after a drought, comes only out of Whiff, and does not cross stakes"
	)

	# A positive result clears the drought for that stake, and no drought can push the
	# positive chance past the cap: without one, a long Low drought would eventually pay
	# better than All In and there would be no reason to take a real risk.
	for _long_dry in range(40):
		clover_odds.note_outcome(CloverSlot.Stake.LOW, CloverSlot.Outcome.WHIFF)
	var capped := clover_odds.get_effective_odds(CloverSlot.Stake.LOW)
	clover_odds.note_outcome(CloverSlot.Stake.LOW, CloverSlot.Outcome.PATH_JACKPOT)
	var after_win := clover_odds.get_effective_odds(CloverSlot.Stake.LOW)
	_check(
		float(capped["positive"]) <= clover_odds.positive_caps[CloverSlot.Stake.LOW] + 0.0001
		and float(capped["positive"]) > float(after_win["positive"])
		and clover_odds.get_drought(CloverSlot.Stake.LOW) == 0,
		"a drought is capped and a win clears it (%.3f capped, %.3f after)"
			% [float(capped["positive"]), float(after_win["positive"])]
	)

	# Triple Bust cannot happen twice in a row, and the probability taken off it becomes
	# Whiff rather than Jackpot: a catastrophe must not make the next spin generous.
	clover_odds.reset_odds()
	var bust_normal := clover_odds.get_effective_odds(CloverSlot.Stake.HIGH)
	clover_odds.note_outcome(CloverSlot.Stake.HIGH, CloverSlot.Outcome.TRIPLE_BUST)
	var bust_next := clover_odds.get_effective_odds(CloverSlot.Stake.HIGH)
	clover_odds.note_outcome(CloverSlot.Stake.HIGH, CloverSlot.Outcome.WHIFF)
	var bust_second := clover_odds.get_effective_odds(CloverSlot.Stake.HIGH)
	_check(
		is_equal_approx(float(bust_next["triple_bust"]), 0.0)
		and is_equal_approx(
			float(bust_second["triple_bust"]), float(bust_normal["triple_bust"]) * 0.5
		)
		and float(bust_next["whiff"]) > float(bust_normal["whiff"])
		and is_equal_approx(
			float(bust_next["path_jackpot"]), float(bust_normal["path_jackpot"])
		),
		"a Bust cannot immediately repeat, and the removed chance becomes Whiff"
	)
	clover_odds.reset_odds()

	# The wager is a physical region of the organism, sized exactly by the notch and
	# made only of ground the run actually holds.
	var owned_cells := prototype.territory_field.collect_owned_cells()
	_check(owned_cells.size() > 0, "the starting island gives the machine something to wager")
	# Seeded in the middle of the island rather than at its first cell in index order,
	# which is a corner of it: a flood that starts on the rim has nowhere inward to go
	# and would say nothing about how the selection prefers integrated tissue. The
	# centroid of a horseshoe need not be Green, which is exactly the case the selector
	# is meant to handle by seeding at the nearest owned cell instead.
	var seat := Vector2.ZERO
	for cell in owned_cells:
		seat += prototype.territory_field.get_cell_local_position(cell)
	seat /= float(owned_cells.size())
	var wrong_stake_sizes := 0
	var unowned_in_wager := 0
	for stake in range(CloverSlot.Stake.size()):
		var region := selector.select(stake, seat)
		if region.size() != selector.get_target_cell_count(stake, owned_cells.size()):
			wrong_stake_sizes += 1
		for cell in region:
			if not prototype.territory_field.is_owned_cell(cell):
				unowned_in_wager += 1
	var all_in_region := selector.select(CloverSlot.Stake.ALL_IN, seat)
	var repeat_region := selector.select(CloverSlot.Stake.MEDIUM, seat)
	_check(
		wrong_stake_sizes == 0
		and unowned_in_wager == 0
		and all_in_region.size() == owned_cells.size()
		and repeat_region == selector.select(CloverSlot.Stake.MEDIUM, seat),
		"every notch stakes exactly its share of owned Green, All In takes all of it, and the same board picks the same cells"
	)

	# The flood starts under the player. It is the one thing about the wager the player
	# can aim, and it is easy to break from the outside without breaking the selector:
	# the field sits at an offset inside the scene, so handing it the player's global
	# position instead of its arena position seeds the region a dozen cells away, misses
	# Green entirely, and quietly falls back to the nearest owned cell. Both the selector
	# and the path the interface actually drives are checked, because only the second of
	# those two ever went wrong.
	var player_seat := prototype.player.get_arena_position()
	var player_cell := prototype.territory_field.local_to_cell_index(player_seat)
	var stands_on_green := prototype.territory_field.is_owned_cell(player_cell)
	var player_region := selector.select(CloverSlot.Stake.MEDIUM, player_seat)
	prototype._on_slot_hover_changed(true)
	var previewed := machine.get_preview_cells().duplicate()
	prototype._on_slot_hover_changed(false)
	_check(
		stands_on_green
		and player_region.has(player_cell)
		and previewed.has(player_cell),
		"the wager is seeded on the cell the player is standing on, through the interface as well as directly"
	)

	# The selection prefers integrated tissue over the exposed rim, so a lost bet costs
	# the organism something it will feel rather than a fringe it was about to lose.
	var wager_exposure := 0.0
	for cell in repeat_region:
		wager_exposure += prototype.territory_field.get_cell_boundary_exposure(cell)
	var board_exposure := 0.0
	for cell in owned_cells:
		board_exposure += prototype.territory_field.get_cell_boundary_exposure(cell)
	_check(
		wager_exposure / float(maxi(1, repeat_region.size()))
			<= board_exposure / float(maxi(1, owned_cells.size())) + 0.0001,
		"the wager reaches inward rather than skimming the boundary"
	)

	# The region is drawn from a mask at the field's own resolution rather than as one
	# rectangle per cell, so the highlight reconstructs into the same kind of soft
	# border as the ground it sits on. What the layer is holding has to stay the region
	# it was handed, and an empty region has to leave nothing on the arena.
	var layer := prototype.wager_layer
	layer.set_wager_cells(repeat_region, false)
	var drawn := layer.get_wager_cell_count() == repeat_region.size() and layer.visible
	layer.set_wager_cells(repeat_region, true)
	var committed_static := layer.is_committed()
	layer.clear_wager()
	_check(
		drawn and committed_static and not layer.visible and layer.get_wager_cell_count() == 0,
		"the wager layer draws exactly the region it is given and clears completely"
	)

	# The buy-in is enforced on every stake including All In, so a run with almost
	# nothing left cannot use the machine as a free lottery ticket.
	machine.minimum_buyin_established_fraction = 1.0
	var blocked := not machine.can_spin() and not machine.try_spin(seat)
	machine.minimum_buyin_established_fraction = 0.0
	_check(blocked and machine.can_spin(), "the lever will not move below the minimum buy-in")

	# The result is decided when the lever goes down and applied when the reels stop. The
	# reveal is drama, not a second roll.
	clover_odds.path_jackpot_chances = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	clover_odds.triple_clover_chances = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	clover_odds.triple_bust_chances = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	machine.reset_machine()
	machine.minimum_buyin_established_fraction = 0.0
	machine.set_stake(CloverSlot.Stake.MEDIUM)
	var resolutions: Array = []
	var on_resolved := func(outcome: int, _path: int, _stake: int) -> void:
		resolutions.append(outcome)
	machine.spin_resolved.connect(on_resolved)
	var green_before := prototype.territory_field.get_player_cell_count()
	var pulled := machine.try_spin(seat)
	var committed := machine.get_committed_cells().duplicate()
	var faces_at_pull := machine.get_last_symbols().duplicate()
	machine.advance(machine.get_reel_stop_seconds(2) * 0.5)
	var applied_mid_spin := not resolutions.is_empty()
	var still_turning := machine.is_revealing() and machine.is_reel_spinning(2)
	var locked_out := not machine.can_spin() and not machine.try_spin(seat)
	machine.advance(machine.get_reveal_duration())
	_check(
		pulled
		and committed.size() > 0
		and not applied_mid_spin
		and still_turning
		and locked_out
		and not machine.is_revealing()
		and machine.get_last_symbols() == faces_at_pull
		and resolutions.size() == 1
		and resolutions[0] == CloverSlot.Outcome.WHIFF,
		"the wager is frozen at the pull, nothing is applied mid-spin, and the reels land on what was rolled"
	)

	# A lost wager takes the ground it named, and only that ground.
	var still_green := 0
	for cell in committed:
		if prototype.territory_field.is_owned_cell(cell):
			still_green += 1
	_check(
		still_green == 0
		and prototype.territory_field.get_player_cell_count() < green_before,
		"a whiff drains the committed region to neutral"
	)

	# Left to right, and a matching first pair slows the third reel. The visible reels
	# are authoritative: the slowdown follows what reels one and two show, whether that
	# is heading for a jackpot or for a catastrophe.
	_check(
		machine.get_reel_stop_seconds(0) < machine.get_reel_stop_seconds(1)
		and machine.get_reel_stop_seconds(1) < machine.get_reel_stop_seconds(2),
		"the reels come to rest one after another rather than all at once"
	)

	# Bust turns the region hostile rather than merely emptying it, which is the whole
	# difference between an expensive spin and a catastrophe.
	clover_odds.triple_bust_chances = PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
	clover_odds.reset_odds()
	machine.reset_machine()
	machine.minimum_buyin_established_fraction = 0.0
	machine.set_stake(CloverSlot.Stake.LOW)
	prototype.territory_field.reset_field()
	var bust_seat := prototype.territory_field.get_cell_local_position(
		prototype.territory_field.collect_owned_cells()[0]
	)
	machine.try_spin(bust_seat)
	var bust_region := machine.get_committed_cells().duplicate()
	var tease_stop := machine.get_reel_stop_seconds(2)
	machine.advance(machine.get_reveal_duration() + 0.01)
	var left_green := 0
	var left_neutral := 0
	for cell in bust_region:
		if prototype.territory_field.is_owned_cell(cell):
			left_green += 1
		elif prototype.territory_field.get_control_at_local(
			prototype.territory_field.get_cell_local_position(cell)
		) >= 0.0:
			left_neutral += 1
	_check(
		bust_region.size() > 0
		and left_green == 0
		and left_neutral == 0
		and tease_stop > machine.reel_stop_seconds[2],
		"Triple Bust turns the wagered ground hostile, and its matching pair slows the third reel"
	)

	# A jackpot lends the Path its ceiling and takes it back. Nothing is added to the
	# build: the loan must not fill a growth-line slot or unlock an Evolution.
	prototype.progression.reset_progression()
	jackpots.reset_jackpots()
	var owned_before := prototype.progression.get_owned_upgrade_level(
		PhaseBProgression.UpgradeId.ROOT_MATURATION
	)
	var slots_before := prototype.progression.get_slotted_upgrades().size()
	jackpots.light(PhaseBProgression.PathId.ROOT)
	var lent := prototype.progression.get_upgrade_level(
		PhaseBProgression.UpgradeId.ROOT_MATURATION
	)
	var lent_other_path := prototype.progression.get_upgrade_level(
		PhaseBProgression.UpgradeId.BLOOM_FORCE
	)
	var owns_path := prototype.progression.has_path(PhaseBProgression.PathId.ROOT)
	var stacked := jackpots.light(PhaseBProgression.PathId.ROOT)
	jackpots.advance(jackpots.root_seconds + 0.01)
	var still_lit := jackpots.is_active(PhaseBProgression.PathId.ROOT)
	jackpots.advance(jackpots.root_seconds + 0.01)
	_check(
		lent == prototype.progression.casino_upgrade_level
		and lent_other_path == 0
		and not owns_path
		and prototype.progression.get_owned_upgrade_level(
			PhaseBProgression.UpgradeId.ROOT_MATURATION
		) == owned_before
		and prototype.progression.get_slotted_upgrades().size() == slots_before
		and is_equal_approx(stacked, jackpots.root_seconds * 2.0)
		and still_lit
		and not jackpots.is_active(PhaseBProgression.PathId.ROOT)
		and prototype.progression.get_upgrade_level(
			PhaseBProgression.UpgradeId.ROOT_MATURATION
		) == owned_before,
		"a jackpot runs the Path at its ceiling for a stacking duration, grants no ownership, and gives it all back"
	)

	# A timed jackpot has to reach the ground. Bramble, Root and Pruning all gate their
	# mechanics on owning the path, and Bramble and Root push their numbers into the field
	# and the combat loop once when the build changes rather than reading them every
	# frame. A jackpot that only raised upgrade levels therefore produced nothing at all:
	# levels nobody was reading, on a mechanic nobody had switched on.
	prototype.progression.reset_progression()
	jackpots.reset_jackpots()
	prototype._apply_progression_modifiers()
	var unowned_slow := prototype.bramble_director.get_slow_fraction()
	var unowned_thorns := prototype.territory_field.is_bramble_enabled()
	var unowned_maturation := prototype.root_director.get_maturation_multiplier()
	# Through the signal, so what is checked is the path the machine actually takes.
	jackpots.light(PhaseBProgression.PathId.BRAMBLE)
	jackpots.light(PhaseBProgression.PathId.ROOT)
	var lit_slow := prototype.bramble_director.get_slow_fraction()
	var lit_thorns := prototype.territory_field.is_bramble_enabled()
	var lit_maturation := prototype.root_director.get_maturation_multiplier()
	var lit_pruning := prototype.progression.has_path_active(
		PhaseBProgression.PathId.PRUNING
	)
	jackpots.light(PhaseBProgression.PathId.PRUNING)
	var lit_pruning_after := prototype.progression.has_path_active(
		PhaseBProgression.PathId.PRUNING
	)
	_check(
		unowned_slow == 0.0
		and not unowned_thorns
		and lit_slow > 0.0
		and lit_thorns
		and lit_maturation > unowned_maturation
		and not lit_pruning
		and lit_pruning_after,
		"a timed jackpot switches the path on and pushes its numbers into the field (slow %.2f, maturation %.2fx)"
			% [lit_slow, lit_maturation]
	)

	# It is a loan and it has to be handed back. A jackpot that never re-pushed the
	# ordinary values on the way out would leave the run permanently maxed on whatever
	# it last won, which is a far worse bug than the one it came from.
	jackpots.advance(
		maxf(jackpots.root_seconds, maxf(jackpots.bramble_seconds, jackpots.pruning_seconds))
		+ 0.01
	)
	_check(
		prototype.bramble_director.get_slow_fraction() == 0.0
		and not prototype.territory_field.is_bramble_enabled()
		and is_equal_approx(
			prototype.root_director.get_maturation_multiplier(), unowned_maturation
		)
		and not prototype.progression.has_path_active(PhaseBProgression.PathId.PRUNING),
		"the loan is handed back when the timer runs out"
	)

	# The jackpot stacks on top of what the run already owns rather than raising it to a
	# floor. A player who has already maxed a line bought that ceiling, and handing it
	# back what it owned would be no reward for the path the run is built around.
	prototype.progression.reset_progression()
	jackpots.reset_jackpots()
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.ROOT,
		PhaseBProgression.PathId.BRAMBLE
	)
	prototype.progression._upgrade_levels[
		PhaseBProgression.UpgradeId.ROOT_MATURATION
	] = prototype.progression.maximum_upgrade_level
	var owned_rank := prototype.progression.get_owned_upgrade_level(
		PhaseBProgression.UpgradeId.ROOT_MATURATION
	)
	jackpots.light(PhaseBProgression.PathId.ROOT)
	var maxed_with_jackpot := prototype.progression.get_upgrade_level(
		PhaseBProgression.UpgradeId.ROOT_MATURATION
	)
	var unowned_with_jackpot := prototype.progression.get_upgrade_level(
		PhaseBProgression.UpgradeId.ROOT_BIOMASS_YIELD
	)
	# Ownership is still ownership: a relic that requires the player to have selected a
	# path must keep requiring it, whatever the reels paid.
	var borrowed_ownership := prototype.progression.has_path(
		PhaseBProgression.PathId.PRUNING
	)
	jackpots.light(PhaseBProgression.PathId.PRUNING)
	_check(
		owned_rank == prototype.progression.maximum_upgrade_level
		and maxed_with_jackpot == owned_rank + prototype.progression.casino_upgrade_level
		and unowned_with_jackpot == prototype.progression.casino_upgrade_level
		and not borrowed_ownership
		and not prototype.progression.has_path(PhaseBProgression.PathId.PRUNING)
		and prototype.progression.get_owned_upgrade_level(
			PhaseBProgression.UpgradeId.ROOT_MATURATION
		) == owned_rank,
		"a jackpot adds its ceiling to the owned rank (%d becomes %d) and never grants the path"
			% [owned_rank, maxed_with_jackpot]
	)
	jackpots.reset_jackpots()
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()

	# A colony core planted inside a wall cannot be damaged from any direction, because
	# every radial source tests the line from its centre to the target and no line reaches
	# into solid rock. The run then cannot be won, since clearing the field is a victory
	# condition. So the placement steps clear of the wall, or does not happen.
	prototype.combat.reset_combat()
	var wall_position := Vector2.ZERO
	var field_for_walls := prototype.territory_field
	for cell in range(field_for_walls.get_cell_count()):
		if field_for_walls.is_claimable_cell(cell):
			continue
		var candidate := field_for_walls.get_cell_local_position(cell)
		if field_for_walls.contains_local_point(candidate):
			wall_position = candidate
			break
	var site := prototype.combat._find_colony_core_site(wall_position)
	var placed_clear := site == Vector2.INF or field_for_walls.is_diamond_claimable_at_local(
		site,
		prototype.combat.colony_core_profile.body_radius_pixels
	)
	# And an ordinary position is left exactly where the Colonizer stood.
	var open_position := field_for_walls.get_cell_local_position(
		field_for_walls.collect_owned_cells()[0]
	)
	var open_site := prototype.combat._find_colony_core_site(open_position)
	_check(
		wall_position != Vector2.ZERO
		and not field_for_walls.is_diamond_claimable_at_local(
			wall_position,
			prototype.combat.colony_core_profile.body_radius_pixels
		)
		and placed_clear
		and open_site == open_position,
		"a colony core is never planted inside a wall, and an unobstructed one does not move"
	)
	prototype.combat.reset_combat()

	# The relic row carries rarity on the slot itself, so a collection reads at a glance
	# rather than only under the pointer. Colour is never the only signal: the tooltip
	# still names the rarity in words.
	prototype.progression.reset_progression()
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.HARD_HUSK] = 1
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.PATIENT_ZERO] = 1
	prototype._update_relic_slots()
	var common_edge := prototype.relic_slots.get_slot_border_color(0)
	var legendary_edge := prototype.relic_slots.get_slot_border_color(1)
	var empty_edge := prototype.relic_slots.get_slot_border_color(2)
	var slot_names_rarity := prototype.relic_slots.get_slot_tooltip(1).contains("LEGENDARY")
	# Hue only: the row keeps its own border alpha so a rarity cannot quietly change how
	# solid a slot looks, only what colour it is.
	var same_hue := func(edge: Color, rarity: int) -> bool:
		var wanted := PhaseBRelicCatalog.get_rarity_color(rarity)
		return (
			is_equal_approx(edge.r, wanted.r)
			and is_equal_approx(edge.g, wanted.g)
			and is_equal_approx(edge.b, wanted.b)
		)
	_check(
		same_hue.call(common_edge, PhaseBRelicCatalog.Rarity.COMMON)
		and same_hue.call(legendary_edge, PhaseBRelicCatalog.Rarity.LEGENDARY)
		and not common_edge.is_equal_approx(legendary_edge)
		and not legendary_edge.is_equal_approx(empty_edge)
		and slot_names_rarity,
		"a relic slot is coloured by its rarity and still names it in words"
	)
	prototype.progression.reset_progression()
	prototype._update_relic_slots()

	# The four Clover relics are rules about the machine rather than about the ground it
	# pays out onto. Each is checked through the odds table, because that is where they
	# have to be visible: the readout may not print one number and roll another.
	clover_odds.reset_odds()
	prototype.progression.reset_progression()
	var plain_bust := float(
		clover_odds.get_effective_odds(CloverSlot.Stake.HIGH)["triple_bust"]
	)
	# Bent Coin: Busts bend the coin, and the spin after the third cannot Bust at all.
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.BENT_COIN] = 1
	for _bust in range(clover_odds.bent_coin_pity):
		clover_odds.note_outcome(CloverSlot.Stake.HIGH, CloverSlot.Outcome.TRIPLE_BUST)
	var bent_ready := clover_odds.is_bent_coin_ready()
	var bent_bust := float(
		clover_odds.get_effective_odds(CloverSlot.Stake.HIGH)["triple_bust"]
	)
	clover_odds.note_outcome(CloverSlot.Stake.HIGH, CloverSlot.Outcome.WHIFF)
	var bent_spent := not clover_odds.is_bent_coin_ready()
	_check(
		plain_bust > 0.0 and bent_ready and bent_bust == 0.0 and bent_spent,
		"Bent Coin makes the spin after its third Bust unable to Bust, then spends itself"
	)

	# Side Pot: built out of whiffs, cashed into a jackpot, lost to a Bust.
	clover_odds.reset_odds()
	prototype.progression.reset_progression()
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.SIDE_POT] = 1
	for _whiff in range(4):
		clover_odds.note_outcome(CloverSlot.Stake.MEDIUM, CloverSlot.Outcome.WHIFF)
	var pot_built := clover_odds.get_side_pot()
	var pot_bonus := clover_odds.get_side_pot_scale_bonus()
	clover_odds.note_outcome(CloverSlot.Stake.MEDIUM, CloverSlot.Outcome.PATH_JACKPOT)
	var pot_cashed := clover_odds.get_side_pot()
	for _whiff in range(3):
		clover_odds.note_outcome(CloverSlot.Stake.MEDIUM, CloverSlot.Outcome.WHIFF)
	clover_odds.note_outcome(CloverSlot.Stake.MEDIUM, CloverSlot.Outcome.TRIPLE_BUST)
	_check(
		pot_built == 4
		and pot_bonus > 0.0
		and pot_cashed == 0
		and clover_odds.get_side_pot() == 0,
		"the Side Pot builds on whiffs, empties into a jackpot, and is lost to a Bust"
	)

	# High Roller: every seventh spin, and the player can see it coming.
	clover_odds.reset_odds()
	prototype.progression.reset_progression()
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.HIGH_ROLLER] = 1
	var doubled_spins := 0
	var announced_before := false
	for spin in range(clover_odds.high_roller_cadence * 2):
		if clover_odds.is_high_roller_spin():
			doubled_spins += 1
			announced_before = announced_before or clover_odds.get_high_roller_countdown() == 1
		clover_odds.note_outcome(CloverSlot.Stake.LOW, CloverSlot.Outcome.WHIFF)
	_check(
		doubled_spins == 2 and announced_before,
		"High Roller doubles one spin in %d and says so before it is taken (%d of them)"
			% [clover_odds.high_roller_cadence, doubled_spins]
	)

	# The House Always Loses: each Bust tears a Bust face off for good, and the last one
	# pays for itself.
	clover_odds.reset_odds()
	prototype.progression.reset_progression()
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.THE_HOUSE_ALWAYS_LOSES] = 1
	var house_before := float(
		clover_odds.get_effective_odds(CloverSlot.Stake.HIGH)["triple_bust"]
	)
	for _bust in range(clover_odds.house_removal_limit + 2):
		clover_odds.note_outcome(CloverSlot.Stake.HIGH, CloverSlot.Outcome.TRIPLE_BUST)
		clover_odds.note_outcome(CloverSlot.Stake.HIGH, CloverSlot.Outcome.WHIFF)
		clover_odds.note_outcome(CloverSlot.Stake.HIGH, CloverSlot.Outcome.WHIFF)
	var house_after := float(
		clover_odds.get_effective_odds(CloverSlot.Stake.HIGH)["triple_bust"]
	)
	var free_spins := clover_odds.get_free_spins()
	var free_taken := clover_odds.take_free_spin()
	_check(
		clover_odds.get_house_removals() == clover_odds.house_removal_limit
		and house_after < house_before
		and free_spins == 1
		and free_taken
		and not clover_odds.take_free_spin(),
		"The House Always Loses cuts Bust odds three times and pays one free spin"
	)
	clover_odds.reset_odds()
	prototype.progression.reset_progression()

	# All In whiff: everything goes, the ordinary extinction countdown is held off, and
	# the run gets exactly three seconds to put something back.
	prototype.territory_field.reset_field()
	grace.reset_grace()
	# Measured against the board that actually exists rather than against the shipped
	# five percent, so the check is about the rule and not about how big the starting
	# island happens to be this build.
	var authored_threshold := grace.recovery_threshold
	grace.recovery_threshold = grace.get_recovered_fraction() * 0.5
	grace.begin()
	var suppressing := grace.is_suppressing_defeat()
	var started_at := grace.get_remaining_seconds()
	var failures: Array = []
	var recoveries: Array = []
	var on_failed := func() -> void:
		failures.append(true)
	var on_recovered := func(_left: float) -> void:
		recoveries.append(true)
	grace.grace_failed.connect(on_failed)
	grace.grace_recovered.connect(on_recovered)
	# Recovery first: the board still holds its starting island, which is above the
	# threshold, so the very first tick has to read as a rescue.
	grace.advance(0.1)
	var rescued := recoveries.size() == 1 and not grace.is_active()
	prototype.territory_field.neutralize_all_owned()
	grace.recovery_threshold = authored_threshold
	grace.begin()
	grace.advance(grace.grace_duration + 0.01)
	grace.grace_failed.disconnect(on_failed)
	grace.grace_recovered.disconnect(on_recovered)
	_check(
		suppressing
		and is_equal_approx(started_at, grace.grace_duration)
		and rescued
		and failures.size() == 1
		and not grace.is_suppressing_defeat(),
		"the All In grace period suspends defeat, ends the moment the board is rebuilt, and ends the run when it is not"
	)

	machine.spin_resolved.disconnect(on_resolved)
	clover_odds.path_jackpot_chances = PackedFloat32Array([0.095, 0.21, 0.38, 0.55])
	clover_odds.triple_clover_chances = PackedFloat32Array([0.005, 0.01, 0.02, 0.05])
	clover_odds.triple_bust_chances = PackedFloat32Array([0.005, 0.02, 0.07, 0.15])
	clover_odds.reset_odds()
	jackpots.reset_jackpots()
	grace.reset_grace()
	machine.reset_machine()
	prototype.territory_field.reset_field()
	prototype.progression.reset_progression()

	# An undeveloped organism on an empty board is physically ordinary: every
	# multiplier the field reads is neutral, so the economy adds nothing until either
	# the run develops something or the organism actually grows.
	metabolism.reset_metabolism()
	prototype.root_network.reset_network()
	prototype.progression.reset_progression()
	metabolism.advance(60.0)
	_check(
		is_equal_approx(metabolism.get_mass_multiplier(), 1.0)
		and is_equal_approx(metabolism.get_pressure_multiplier(), 1.0)
		and is_equal_approx(metabolism.get_resistance_multiplier(), 1.0),
		"an undeveloped organism leaves every physical parameter of the field alone"
	)

	# Phase 2: Biomass is produced by rooted ground into the reserve of the connected
	# component that produced it. The claim being tested is the doc's, that territory
	# quality is an axis separate from territory quantity: the same cells are worth
	# more once they have rooted, so a run that holds ground out-earns one that only
	# touches it.
	network = prototype.root_network
	network.reset_network()
	prototype.territory_field.reset_field()
	_step_field(field, 2)
	prototype.territory_field.analyze_topology_now()
	network.advance(1.0, prototype.player.position)
	var fresh_generation := network.get_primary_generation_per_second()
	_step_field(field, 900)
	prototype.territory_field.analyze_topology_now()
	network.advance(1.0, prototype.player.position)
	var rooted_generation := network.get_primary_generation_per_second()
	_check(
		rooted_generation > fresh_generation * 1.5 and fresh_generation >= 0.0,
		"the same ground earns more once it has rooted (%.3f/s fresh, %.3f/s rooted)"
			% [fresh_generation, rooted_generation]
	)

	# Production has to reach a reserve, and that reserve has to be the component's.
	network.reset_network()
	for _advance_step in range(20):
		network.advance(0.5, prototype.player.position)
	var banked := network.get_primary_reserve()
	_check(
		banked > 0.0
		and network.get_total_reserve() >= banked
		and network.get_primary_component() >= 0,
		"rooted ground banks Biomass into its own component's reserve (%.1f)" % banked
	)

	# Storage is finite, so a component that is full stops rather than growing without
	# limit. This is what gives Storage Tissue something to buy later.
	var capacity := network.get_primary_capacity()
	for _fill_step in range(400):
		network.advance(1.0, prototype.player.position)
	_check(
		capacity > 0.0
		and network.get_primary_reserve() <= capacity + 0.001
		and is_equal_approx(network.get_primary_reserve(), capacity),
		"a component's reserve fills to its capacity and stops (%.1f of %.1f)"
			% [network.get_primary_reserve(), capacity]
	)

	# Relabelling must not mint or destroy Biomass. Labels are handed out in scan
	# order and shuffle whenever the ecosystem changes shape, so the carry across a
	# topology pass is the one thing standing between per-component reserves and
	# numbers that jump between unrelated regions.
	var total_before := network.get_total_reserve()
	prototype.territory_field.analyze_topology_now()
	network.advance(0.0001, prototype.player.position)
	var total_after := network.get_total_reserve()
	_check(
		absf(total_after - total_before) < maxf(1.0, total_before * 0.05),
		"a topology relabel carries reserves instead of minting or dropping them "
			+ "(%.1f then %.1f)" % [total_before, total_after]
	)

	# Spending draws on the main organism alone. A colony that is cut off keeps its
	# own Biomass, which is the reason components own reserves at all.
	var primary_before := network.get_primary_reserve()
	var spent := network.spend_from_primary(primary_before * 0.5)
	_check(
		spent > 0.0
		and is_equal_approx(network.get_primary_reserve(), primary_before - spent)
		and network.spend_from_primary(1000000.0) <= network.get_primary_capacity(),
		"spending draws from the main organism and cannot overdraw it"
	)

	# Translocate is the one exception to a severed colony's Biomass being unreachable,
	# and it has to cost something or the rule it breaks was never a rule.
	network.reset_network()
	_check(
		metabolism.translocate_recovery_fraction < 1.0
		and not metabolism.can_perform(PhaseBMetabolism.ActionId.TRANSLOCATE),
		"Translocate loses part of what it moves, and refuses when nothing is stranded"
	)

	# Phase 3: does territory geometry matter economically? It does if a run cannot
	# spend what its severed ground is holding, and if cutting the organism is an
	# event the player is told about where it happened.
	# Back to authored tuning first. By this point the suite is holding every Root
	# line at maximum, and Mature Strength plus regeneration make established ground
	# so hard to peel apart that a band strong enough to divide it erases it instead.
	# That is the path working; it just is not what this block is measuring.
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	network.reset_network()
	prototype.territory_field.reset_field()
	# Rooted enough to be worth announcing and banked enough to be worth stranding.
	# A colony that is neither is deliberately invisible to this system, so a cut made
	# before the ground has established would correctly report nothing at all.
	# Grown into an organism worth cutting. A foothold of a few dozen cells cannot be
	# divided by any band wide enough to reach across it: the band erases it instead,
	# which is a smaller ecosystem being destroyed rather than a network being severed.
	var growth_origin := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.24,
		prototype.territory_field.tuning.arena_size.y * 0.54
	)
	for growth_step in range(10):
		prototype.territory_field.queue_bloom(
			growth_origin + Vector2(0.0, float(growth_step - 5) * 9.0),
			6.0,
			1.0,
			6.0,
			2.4
		)
	_step_field(prototype.territory_field, 900)
	# Stepped and advanced in the order the run itself uses: the field drives its own
	# topology pass on its own cadence and the network advances once per step. Forcing
	# an extra relabel between advances would hand the network two of them to consume
	# with one mapping, which is not a situation the running game can produce.
	for _bank_step in range(360):
		prototype.territory_field.step_simulation()
		network.advance(0.5, prototype.player.position)
	prototype.territory_field.recalculate_metrics_now()
	var colonies_before := network.get_isolated_colony_positions().size()
	_check(
		network.get_total_reserve() >= network.get_primary_reserve()
		and prototype.territory_field.get_component_count() >= 1,
		"the arena's separate green regions each hold their own reserve"
	)

	var severed: Array = []
	var reconnected: Array = []
	var on_severed := func(_id: int, biomass: float, centroid: Vector2) -> void:
		severed.append([biomass, centroid])
	var on_reconnected := func(_id: int, biomass: float, centroid: Vector2) -> void:
		reconnected.append([biomass, centroid])
	network.colony_isolated.connect(on_severed)
	network.colony_reconnected.connect(on_reconnected)

	# Cut the main organism in half with a hostile band straight through it.
	var organism_centre := prototype.territory_field.get_component_centroid(
		network.get_primary_component()
	)
	# The band has to cross the whole organism, not merely reach across its middle, or
	# what it makes is a dent rather than two networks.
	var arena_height := prototype.territory_field.tuning.arena_size.y
	var band_stamps := int(arena_height / 7.0)
	for band_step in range(band_stamps + 1):
		var cut_position := Vector2(
			organism_centre.x,
			float(band_step) * 7.0
		)
		for _cut_repeat in range(3):
			prototype.territory_field.queue_hostile_growth(cut_position, 300.0, 1.2)
	for _cut_step in range(120):
		prototype.territory_field.step_simulation()
		network.advance(0.05, prototype.player.position)
	prototype.territory_field.recalculate_metrics_now()

	var cut_reported_near_the_cut := not severed.is_empty()
	for entry in severed:
		var centroid: Vector2 = entry[1]
		if absf(centroid.y - organism_centre.y) > prototype.territory_field.tuning.arena_size.y * 0.25:
			cut_reported_near_the_cut = false
	_check(
		cut_reported_near_the_cut,
		"cutting the organism reports the severed colonies where the cut happened (%d)"
			% severed.size()
	)

	# The regression that made this worth checking: which component counts as the main
	# organism moves on its own, because the player walks onto different green or the
	# largest-component fallback follows the biggest thing on the board. Before the
	# continuity guard, that alone reported the run's own untouched territory as having
	# just rejoined the organism. Cutting ground apart must never announce a rejoining.
	_check(
		reconnected.is_empty(),
		"severing ground never reports a reconnection (%d spurious)" % reconnected.size()
	)

	# The point of all of it: the run cannot spend what its severed ground holds.
	var strandable_total := network.get_total_reserve()
	network.spend_from_primary(1000000.0)
	_check(
		strandable_total > 0.0
		and network.get_total_reserve() > 0.0
		and is_equal_approx(network.get_primary_reserve(), 0.0),
		"draining the main organism leaves the severed colonies' Biomass out of reach "
			+ "(%.1f still held)" % network.get_total_reserve()
	)

	# The colonies are marked where they actually are, before any of it is a sidebar.
	var colony_positions := network.get_isolated_colony_positions()
	var colonies_are_on_the_field := not colony_positions.is_empty()
	for colony_position in colony_positions:
		if not prototype.territory_field.contains_local_point(colony_position):
			colonies_are_on_the_field = false
	prototype.overlay.set_isolated_colonies(colony_positions)
	_check(
		colonies_are_on_the_field
		and prototype.overlay.get_isolated_colony_count() == colony_positions.size()
		and colony_positions.size() >= colonies_before,
		"each isolated colony is marked on the battlefield at its own position (%d)"
			% colony_positions.size()
	)

	# A colony has to be worth mentioning. Raised past anything on the board, nothing
	# is announced and nothing is marked, so a torn scrap of frontier stays quiet.
	var restore_cells := network.colony_alert_minimum_rooted_cells
	var restore_biomass := network.colony_alert_minimum_biomass
	network.colony_alert_minimum_rooted_cells = 100000
	network.colony_alert_minimum_biomass = 1000000.0
	_check(
		network.get_isolated_colony_positions().is_empty(),
		"a colony too small and too poor to matter is never reported"
	)
	network.colony_alert_minimum_rooted_cells = restore_cells
	network.colony_alert_minimum_biomass = restore_biomass

	# Phase 4: Overgrow spends the reserve that actually exists, aimed where the
	# player is standing, and travels only through the organism that paid for it.
	network.reset_network()
	for _refill_step in range(240):
		prototype.territory_field.step_simulation()
		network.advance(0.5, prototype.player.position)
	prototype.territory_field.recalculate_metrics_now()
	metabolism.reset_metabolism()
	prototype.progression.reset_progression()

	# The reserve Overgrow can see is the main organism's, not the run's old single
	# number and not the total including what is stranded.
	_check(
		is_equal_approx(metabolism.get_spendable_reserve(), network.get_primary_reserve())
		and network.get_total_reserve() > network.get_primary_reserve()
		and is_equal_approx(prototype.progression.biomass, 0.0),
		"Overgrow spends the main organism's reserve, not the run's or the colonies' "
			+ "(%.0f of %.0f)" % [network.get_primary_reserve(), network.get_total_reserve()]
	)

	# Aimed at the player. The same border, sampled with and without a focus, has to
	# come out closer to the player when the release is aimed.
	var primary_id := network.get_primary_component()
	var aim_point := prototype.territory_field.get_component_centroid(primary_id)
	var unfocused_cells := prototype.territory_field.sample_overgrow_frontier(400.0)
	var focused_cells := prototype.territory_field.sample_overgrow_frontier(
		400.0,
		aim_point,
		metabolism.overgrow_focus_radius,
		primary_id
	)
	var mean_distance := func(cells: PackedInt32Array) -> float:
		var described: Array = prototype.territory_field.describe_frontier_cells(cells)
		var positions: PackedVector2Array = described[0]
		if positions.is_empty():
			return INF
		var total := 0.0
		for position in positions:
			total += position.distance_to(aim_point)
		return total / float(positions.size())
	var unfocused_distance: float = mean_distance.call(unfocused_cells)
	var focused_distance: float = mean_distance.call(focused_cells)
	_check(
		not focused_cells.is_empty() and focused_distance < unfocused_distance,
		"a release is aimed at the player's front rather than spread evenly "
			+ "(%.0f away focused, %.0f unfocused)" % [focused_distance, unfocused_distance]
	)

	# It travels through the organism that paid, so a colony's border is not fed by
	# the main reserve. Every cell the release reaches belongs to the paying component.
	var reached_only_the_payer := true
	for cell_index in focused_cells:
		if prototype.territory_field.get_component_id_at_index(cell_index) != primary_id:
			reached_only_the_payer = false
	_check(
		reached_only_the_payer,
		"a release reaches only the border of the component that paid for it"
	)

	# Pressing it actually moves the reserve, and the cooldown stops a second press.
	var reserve_before_press := network.get_primary_reserve()
	var expected_cost := metabolism.get_overgrow_cost()
	var pressed := metabolism.try_overgrow(prototype.player.position)
	_check(
		pressed
		and expected_cost > 0.0
		and network.get_primary_reserve() < reserve_before_press
		and absf(
			(reserve_before_press - network.get_primary_reserve()) - expected_cost
		) < maxf(1.0, expected_cost * 0.05)
		and not metabolism.can_overgrow(),
		"pressing Overgrow spends the organism's reserve and then has to recharge"
	)

	# With the organism drained, there is nothing to press even though colonies are
	# still holding Biomass. That is the tension the whole system exists to create.
	network.spend_from_primary(1000000.0)
	_check(
		not metabolism.can_overgrow()
		and not metabolism.try_overgrow(prototype.player.position)
		and network.get_total_reserve() > 0.0,
		"a drained organism cannot Overgrow while its severed colonies still hold Biomass"
	)

	# Aiming. Pressing Overgrow asks where rather than releasing, and the run keeps
	# going while the player decides, so the reserve must not move until they commit.
	network.reset_network()
	for _aim_bank_step in range(240):
		prototype.territory_field.step_simulation()
		network.advance(0.5, prototype.player.position)
	prototype.territory_field.recalculate_metrics_now()
	metabolism.reset_metabolism()
	prototype._set_metabolism_drawer_open(true)
	var reserve_at_aim := network.get_primary_reserve()
	prototype._press_action(PhaseBMetabolism.ActionId.OVERGROW)
	_check(
		prototype._overgrow_aiming
		and prototype.overlay.is_aiming_overgrow()
		and not prototype.metabolism_drawer.visible
		and is_equal_approx(network.get_primary_reserve(), reserve_at_aim),
		"pressing Overgrow opens an aim, hides the drawer, and spends nothing yet"
	)

	# The crosshair follows the mouse and is clamped to the arena, so dragging past
	# the edge leaves it on the nearest ground rather than stranding it.
	var arena_size := prototype.territory_field.tuning.arena_size
	var aimed_at := Vector2(arena_size.x * 0.32, arena_size.y * 0.42)
	var motion := InputEventMouseMotion.new()
	motion.position = prototype.territory_field.to_global(aimed_at)
	prototype._unhandled_input(motion)
	var followed_the_mouse := prototype.overlay.get_overgrow_aim_position().distance_to(
		aimed_at
	) < 1.0
	var beyond := InputEventMouseMotion.new()
	beyond.position = prototype.territory_field.to_global(
		Vector2(arena_size.x + 400.0, arena_size.y + 400.0)
	)
	prototype._unhandled_input(beyond)
	var clamped := prototype.overlay.get_overgrow_aim_position()
	_check(
		followed_the_mouse
		and is_equal_approx(clamped.x, arena_size.x)
		and is_equal_approx(clamped.y, arena_size.y),
		"the crosshair follows the mouse and stays inside the arena"
	)

	# Right click backs out and costs nothing.
	var cancel := InputEventMouseButton.new()
	cancel.button_index = MOUSE_BUTTON_RIGHT
	cancel.pressed = true
	prototype._unhandled_input(cancel)
	_check(
		not prototype._overgrow_aiming
		and not prototype.overlay.is_aiming_overgrow()
		and is_equal_approx(network.get_primary_reserve(), reserve_at_aim),
		"backing out of an aim releases nothing and keeps the reserve"
	)

	# Left click commits, at the point clicked rather than at the player.
	prototype._press_action(PhaseBMetabolism.ActionId.OVERGROW)
	var commit := InputEventMouseButton.new()
	commit.button_index = MOUSE_BUTTON_LEFT
	commit.pressed = true
	commit.position = prototype.territory_field.to_global(aimed_at)
	var injected: Array = []
	var on_injected := func(
		_mass: float,
		_pressure: float,
		_cohesion: float,
		cells: PackedInt32Array
	) -> void:
		injected.append(cells)
	metabolism.injection_started.connect(on_injected)
	prototype._unhandled_input(commit)
	metabolism.injection_started.disconnect(on_injected)
	var released_where_aimed := not injected.is_empty()
	if released_where_aimed:
		var described: Array = prototype.territory_field.describe_frontier_cells(injected[0])
		var positions: PackedVector2Array = described[0]
		var mean := Vector2.ZERO
		for position in positions:
			mean += position
		mean /= maxf(1.0, float(positions.size()))
		released_where_aimed = (
			mean.distance_to(aimed_at) < mean.distance_to(prototype.player.position)
		)
	_check(
		not prototype._overgrow_aiming
		and not prototype.overlay.is_aiming_overgrow()
		and network.get_primary_reserve() < reserve_at_aim
		and released_where_aimed,
		"clicking commits the release at the crosshair rather than at the player"
	)

	# With nothing banked there is nothing to aim, so the button refuses rather than
	# opening a crosshair the player cannot use.
	network.spend_from_primary(1000000.0)
	prototype._press_action(PhaseBMetabolism.ActionId.OVERGROW)
	_check(
		not prototype._overgrow_aiming and not prototype.overlay.is_aiming_overgrow(),
		"an unaffordable Overgrow never opens an aim"
	)

	# Phase 5: the player is a demand signal. Standing on the organism pulls part of
	# what it produces into the ground underfoot, where it establishes roots faster.
	# The question is whether moving actually changes the incremental layer, so the
	# measurement is the same ground with the player standing somewhere else.
	network.reset_network()
	prototype.territory_field.reset_field()
	var influence_origin := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.24,
		prototype.territory_field.tuning.arena_size.y * 0.54
	)
	for influence_growth in range(10):
		prototype.territory_field.queue_bloom(
			influence_origin + Vector2(0.0, float(influence_growth - 5) * 9.0),
			6.0,
			1.0,
			6.0,
			2.4
		)
	for _settle_step in range(120):
		prototype.territory_field.step_simulation()
	prototype.territory_field.recalculate_metrics_now()
	prototype.territory_field.analyze_topology_now()
	network.advance(0.5, influence_origin)

	# Two points inside the same organism, far enough apart that one is outside the
	# other's reach, so the only difference between them is where the player stood.
	var attended := influence_origin
	var neglected := influence_origin + Vector2(0.0, 150.0)
	var primary_for_influence := network.get_primary_component()
	var both_are_the_organism := (
		prototype.territory_field.get_component_id_at_local(attended) == primary_for_influence
		and prototype.territory_field.get_component_id_at_local(neglected)
			== primary_for_influence
	)
	var attended_before := prototype.territory_field.get_maturity_at_local(attended)
	var neglected_before := prototype.territory_field.get_maturity_at_local(neglected)
	for _attend_step in range(120):
		prototype.territory_field.step_simulation()
		network.advance(0.5, attended)
	prototype.territory_field.recalculate_metrics_now()
	var attended_gain := (
		prototype.territory_field.get_maturity_at_local(attended) - attended_before
	)
	var neglected_gain := (
		prototype.territory_field.get_maturity_at_local(neglected) - neglected_before
	)
	_check(
		both_are_the_organism
		and network.get_support_per_second() > 0.0
		and attended_gain > neglected_gain,
		"ground the player stands on establishes faster than ground they only own "
			+ "(%.3f attended, %.3f neglected)" % [attended_gain, neglected_gain]
	)

	# What the diversion actually costs, measured on a field rebuilt the same way each
	# time: run one leaves the ground more mature than it found it, so a run measured
	# after it would out-produce the first for that reason alone rather than for this
	# one. Both windows below are therefore taken from the same starting ground.
	var bank_with_diversion := func(fraction: float, advances: int) -> float:
		network.support_diversion_fraction = fraction
		network.reset_network()
		prototype.territory_field.reset_field()
		for rebuild_step in range(10):
			prototype.territory_field.queue_bloom(
				influence_origin + Vector2(0.0, float(rebuild_step - 5) * 9.0),
				6.0,
				1.0,
				6.0,
				2.4
			)
		for _rebuild_settle in range(120):
			prototype.territory_field.step_simulation()
		prototype.territory_field.recalculate_metrics_now()
		prototype.territory_field.analyze_topology_now()
		for _rebuild_advance in range(advances):
			prototype.territory_field.step_simulation()
			network.advance(0.5, attended)
		return network.get_primary_reserve()
	var restore_diversion := network.support_diversion_fraction

	# Immediately it is a cost: the share directed into the ground is not in the
	# reserve, so a run that supports has banked less than one that did not.
	var short_supporting: float = bank_with_diversion.call(restore_diversion, 12)
	var short_banking: float = bank_with_diversion.call(0.0, 12)
	_check(
		short_banking > short_supporting,
		"directing support costs reserve straight away (%.1f banked while supporting, "
			% short_supporting
			+ "%.1f while not)" % short_banking
	)

	# Given time it pays for itself. Ground that establishes faster produces more, and
	# the compounding overtakes what was diverted to cause it, so attending a front is
	# an investment in that front rather than a toll paid for standing there. That the
	# two windows disagree is the point: the cost is immediate, the return is not.
	var long_supporting: float = bank_with_diversion.call(restore_diversion, 120)
	var long_banking: float = bank_with_diversion.call(0.0, 120)
	network.support_diversion_fraction = restore_diversion
	_check(
		long_supporting > long_banking,
		"and pays for itself by compounding (%.0f banked while supporting, %.0f while "
			% [long_supporting, long_banking]
			+ "not, over ten times the window)"
	)

	# Standing off the organism directs nothing. Support poured into ground the network
	# does not hold would be a way to lose Biomass by walking.
	network.reset_network()
	var off_the_organism := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.93,
		prototype.territory_field.tuning.arena_size.y * 0.90
	)
	for _off_step in range(20):
		prototype.territory_field.step_simulation()
		network.advance(0.5, off_the_organism)
	_check(
		prototype.territory_field.get_component_id_at_local(off_the_organism)
			!= network.get_primary_component()
		and is_equal_approx(network.get_support_per_second(), 0.0),
		"a player standing off their own ground directs no support into it"
	)

	# Phase 6: three permanent developments at one price. The point of equal pricing is
	# that the question is never which is cheapest, so the run has to answer what the
	# organism needs instead.
	network.reset_network()
	network.support_diversion_fraction = 0.0
	prototype.territory_field.reset_field()
	for _develop_bank in range(400):
		prototype.territory_field.step_simulation()
		network.advance(0.5, prototype.player.position)
	prototype.territory_field.recalculate_metrics_now()
	# Captured before anything is bought. Buying emits the development signal, which
	# the run answers by re-applying its modifiers, so a reading taken after the
	# purchase is already the developed one and would compare a value with itself.
	prototype._apply_progression_modifiers()
	var maturation_before := prototype.territory_field.tuning.maturation_per_second
	var first_cost := network.get_development_cost()
	var prices_are_equal := true
	for domain_id in range(4):
		if not is_equal_approx(network.get_development_cost(), first_cost):
			prices_are_equal = false
	_check(
		prices_are_equal and first_cost > 0.0,
		"all four domains cost the same, so none of them is the cheap one"
	)

	# Buying one raises the price of all three, not of the one bought, so specialising
	# is never discounted and never punished relative to spreading.
	var reserve_for_development := network.get_primary_reserve()
	var bought_rapid := network.try_develop(PhaseBRootNetwork.DomainId.ROOTING)
	var cost_after := network.get_development_cost()
	_check(
		bought_rapid
		and network.get_development_level(PhaseBRootNetwork.DomainId.ROOTING) == 1
		and network.get_primary_reserve() < reserve_for_development
		and cost_after > first_cost
		and is_equal_approx(cost_after, first_cost * network.development_cost_growth),
		"developing a domain raises the price of all four by the same step"
	)

	# Each of the four has to actually do the different thing it claims. Rooting
	# establishes ground faster, Storage banks more before overflowing, Circulation
	# carries the player's influence further, and Anchoring makes what is already held
	# harder to take away.
	# Priced down for the effect checks only, so all four can be bought from one
	# reserve. What each does is the point here; what it costs was the point above.
	var restore_development_cost := network.development_base_cost
	network.development_base_cost = 10.0
	# Refilled first: the reserve is capacity-bound, and the purchase above took most
	# of it, which is the storage pressure the developments exist to answer.
	for _refill_for_development in range(200):
		prototype.territory_field.step_simulation()
		network.advance(0.5, prototype.player.position)
	prototype.territory_field.recalculate_metrics_now()
	var maturation_after := prototype.territory_field.tuning.maturation_per_second
	var capacity_before := network.get_primary_capacity()
	network.try_develop(PhaseBRootNetwork.DomainId.STORAGE)
	var capacity_after := network.get_primary_capacity()
	var reach_before := network.get_reach_multiplier()
	var bought_circulation := network.try_develop(PhaseBRootNetwork.DomainId.CIRCULATION)
	var reach_after := network.get_reach_multiplier()
	var resistance_before := network.get_anchor_resistance_multiplier()
	var decay_before := network.get_anchor_fragment_decay_multiplier()
	var bought_all_four := (
		bought_circulation
		and network.try_develop(PhaseBRootNetwork.DomainId.ANCHORING)
	)
	_check(
		bought_all_four
		and maturation_after > maturation_before
		and capacity_after > capacity_before
		and reach_after > reach_before
		and network.get_anchor_resistance_multiplier() > resistance_before
		and network.get_anchor_fragment_decay_multiplier() < decay_before,
		"the four domains move four different things (%.4f/s maturation, "
			% maturation_after
			+ "%.0f capacity, %.2fx reach, %.2fx resistance)" % [
				capacity_after,
				reach_after,
				network.get_anchor_resistance_multiplier(),
			]
	)

	# Circulation widens what a release actually favours, and the ring the player aims
	# with has to widen by the same amount or the aim would lie about the effect.
	prototype._aiming_action = PhaseBMetabolism.ActionId.OVERGROW
	_check(
		is_equal_approx(
			prototype._get_overgrow_reach(),
			prototype.metabolism.overgrow_focus_radius * network.get_reach_multiplier()
		),
		"the aiming ring shows the reach Circulation actually bought"
	)

	# Every domain hands the run a verb at its first rank, and all four are now open.
	var every_action_unlocked := true
	for action_id in range(5):
		if not prototype.metabolism.is_action_unlocked(action_id):
			every_action_unlocked = false
	_check(
		every_action_unlocked
		and not is_equal_approx(
			PhaseBMetabolism.get_action_domain(PhaseBMetabolism.ActionId.DEEP_ROOT),
			PhaseBMetabolism.get_action_domain(PhaseBMetabolism.ActionId.PRESSURIZE)
		),
		"developing all four domains unlocks all four metabolic verbs"
	)

	network.development_base_cost = restore_development_cost

	# Nothing is bought without the reserve to buy it, and a refused purchase changes
	# neither the levels nor the reserve.
	network.spend_from_primary(1000000.0)
	var levels_before_refusal := network.get_total_development_levels()
	_check(
		not network.can_develop()
		and not network.try_develop(PhaseBRootNetwork.DomainId.ROOTING)
		and network.get_total_development_levels() == levels_before_refusal
		and is_equal_approx(network.get_primary_reserve(), 0.0),
		"a development the organism cannot afford is refused whole"
	)

	# The drawer is the developmental domains and nothing else now.
	prototype._update_metabolism_controls()
	# The button draws its wording into a Label it owns rather than into the Button's
	# own centred text, so that is where the drawer is read from.
	var drawer_shows_developments := prototype.metabolism_buttons[0].get_caption(
	).text.contains("ROOTING")
	var drawer_shows_axes := prototype.metabolism_buttons[3].get_caption(
	).text.contains("ANCHORING")
	_check(
		drawer_shows_developments and drawer_shows_axes,
		"the drawer shows developments under the root economy and axes without it"
	)
	network.support_diversion_fraction = 0.35

	# Phase 7: the battlefield carries the root system and the HUD only summarises it.
	network.reset_network()
	prototype.territory_field.reset_field()
	for _hud_bank in range(300):
		prototype.territory_field.step_simulation()
		network.advance(0.5, prototype.player.position)
	prototype.territory_field.recalculate_metrics_now()
	prototype._advance_root_layer(prototype.root_layer_interval_seconds + 0.01)
	var drawn_vessels := prototype.overlay.get_root_vessel_count()
	_check(
		drawn_vessels > 0,
		"the root network is drawn on the battlefield rather than described in a panel "
			+ "(%d vessels)" % drawn_vessels
	)

	# Root's own signature under the Green. Every run has the metabolism's vessels;
	# only a run that took the Root path grows a mat of hairs into the ground it holds,
	# and it thickens as the path's own lines are ranked up. Root is the path about
	# what held ground becomes, so what it changes is what held ground looks like.
	prototype.progression.reset_progression()
	prototype._advance_root_layer(prototype.root_layer_interval_seconds + 0.01)
	var mat_without_root := prototype.overlay.get_root_mat_anchor_count()
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.ROOT,
		PhaseBProgression.PathId.SPORE
	)
	prototype._advance_root_layer(prototype.root_layer_interval_seconds + 0.01)
	var mat_with_root := prototype.overlay.get_root_mat_anchor_count()
	var thin_mat := prototype.overlay._root_mat_strength
	prototype.progression._upgrade_levels[
		PhaseBProgression.UpgradeId.ROOT_MATURATION
	] = prototype.progression.maximum_upgrade_level
	prototype._advance_root_layer(prototype.root_layer_interval_seconds + 0.01)
	var thick_mat := prototype.overlay._root_mat_strength
	_check(
		mat_without_root == 0
		and mat_with_root > 0
		and thin_mat > 0.0
		and thick_mat > thin_mat,
		"the Root path grows a visible root mat under held Green, thickening with its "
			+ "ranks (%d anchors, %.2f to %.2f)" % [mat_with_root, thin_mat, thick_mat]
	)
	prototype.progression.reset_progression()
	prototype._advance_root_layer(prototype.root_layer_interval_seconds + 0.01)

	# Flow stops where the organism ends. A colony keeps its roots and loses its
	# pulses, which is how the ground says it has been cut off without a line of text.
	var flowing_components := 0
	var still_components := 0
	for vessel in prototype.overlay._root_vessels:
		if vessel["flowing"]:
			flowing_components += 1
		else:
			still_components += 1
	_check(
		flowing_components == 1 and still_components >= 1,
		"only the organism the run can spend from carries flow (%d flowing, %d still)"
			% [flowing_components, still_components]
	)

	# The root layer is rebuilt on its own cadence, not per frame. Sampling the field
	# every frame would cost a full pass to show something that changes twice a second.
	prototype.overlay.set_root_vessels([])
	prototype._advance_root_layer(prototype.root_layer_interval_seconds * 0.25)
	var rebuilt_too_soon := prototype.overlay.get_root_vessel_count() > 0
	prototype._advance_root_layer(prototype.root_layer_interval_seconds + 0.01)
	_check(
		not rebuilt_too_soon and prototype.overlay.get_root_vessel_count() > 0,
		"the drawn root layer follows the topology cadence rather than the frame rate"
	)

	# Inspect is held, live, and leaves nothing behind. Everything it shows is state
	# the normal HUD deliberately does not carry.
	prototype._set_root_inspect(true)
	var inspect_shows_reserves := (
		prototype.overlay.is_root_inspect()
		and not prototype.overlay._root_reserves.is_empty()
	)
	prototype._set_root_inspect(false)
	_check(
		inspect_shows_reserves
		and not prototype.overlay.is_root_inspect()
		and prototype.overlay._root_reserves.is_empty(),
		"the root inspect layer is held, and releasing it leaves nothing on screen"
	)

	# The permanent line reports the reserve against the ceiling it can actually hit,
	# and buds only when a development is affordable.
	# Driven the way the run drives it: the line is written from Progression's biomass
	# signal, which the root economy mirrors every frame, not from the HUD refresh.
	var mirror_reserve := func() -> void:
		prototype.progression.set_biomass_from_network(
			network.get_primary_reserve(),
			network.get_primary_generation_per_second()
		)
	mirror_reserve.call()
	var line_has_capacity := prototype.biomass_label.text.contains("/")
	var budded_when_affordable := (
		prototype.biomass_label.text.contains("❦") == network.can_develop()
	)
	network.spend_from_primary(1000000.0)
	mirror_reserve.call()
	_check(
		line_has_capacity
		and budded_when_affordable
		and not prototype.biomass_label.text.contains("❦"),
		"the Biomass line shows the ceiling and buds only while a development is ready"
	)

	# A release runs hot through the vessels before it reaches the border.
	prototype.overlay.spawn_root_surge(Vector2(100.0, 100.0), 0.8)
	var surging := prototype.overlay._root_surge_remaining > 0.0
	prototype.overlay._advance_root_flow(1.2)
	_check(
		surging and is_equal_approx(prototype.overlay._root_surge_remaining, 0.0),
		"a release is carried through the roots and then stops"
	)

	network.colony_isolated.disconnect(on_severed)
	network.colony_reconnected.disconnect(on_reconnected)
	prototype.overlay.set_root_vessels([])
	network.reset_network()
	prototype.overlay.set_isolated_colonies(PackedVector2Array())
	prototype.territory_field.reset_field()
	prototype.progression.reset_progression()

	# A rank answers in the simulation, not only in the number. Nothing is bought any
	# more, so what has to be checked is that a rank arriving on its own still puts
	# material into the ground the way a bought one used to.
	metabolism.reset_metabolism()
	network.reset_network()
	prototype.progression.reset_progression()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	prototype.territory_field.recalculate_metrics_now()
	metabolism.debug_grant_axis(PhaseBMetabolism.SystemId.PHOTOSYNTHESIS, 1)
	# The release is poured in over a ramp rather than dropped in one step, so the
	# border grows into the ground instead of jumping a visible distance between two
	# frames. It still has to arrive, and it still has to be the whole of it.
	var pouring := metabolism.get_pending_injection_count()
	var mid_pour := 0.0
	for pour_step in range(60):
		metabolism.advance(1.0 / 60.0)
		if pour_step == 8:
			mid_pour = metabolism.get_last_injection_mass()
	_check(
		metabolism.rank_pulse_budget > 0.0
		and pouring == 1
		and mid_pour > 0.0
		and metabolism.get_last_injection_mass() > mid_pour
		and metabolism.get_pending_injection_count() == 0,
		"reaching a rank pours material into the territory over a visible ramp"
	)

	# The three systems are the physical parameters: Mass, Pressure, Cohesion.
	var spread_before := prototype.territory_field.tuning.natural_spread_rate
	var cohesion_before := prototype.territory_field.get_cohesion_multiplier()
	metabolism.debug_grant_axis(PhaseBMetabolism.SystemId.MERISTEM, 3)
	metabolism.debug_grant_axis(PhaseBMetabolism.SystemId.CAMBIUM, 3)
	prototype._apply_progression_modifiers()
	_check(
		prototype.territory_field.tuning.natural_spread_rate > spread_before
		and prototype.territory_field.get_cohesion_multiplier() > cohesion_before
		and metabolism.get_mass_multiplier() > 1.0,
		"Storage, Circulation, and Anchoring move Mass, Pressure, and Cohesion"
	)

	# A metamorphosis is a permanent architectural fork that reaches the simulation.
	# It is offered exactly once per domain, at the rank the doc puts it at, and it
	# holds the drawer until it is answered.
	metabolism.reset_metabolism()
	network.reset_network()
	for _anchor_rank in range(network.metamorphosis_rank):
		network.debug_grant_development(PhaseBRootNetwork.DomainId.ANCHORING)
	var metamorphosis_offered := network.has_pending_metamorphosis()
	var development_held := not network.can_develop()
	var advection_before := prototype.territory_field.tuning.pressure_advection
	network.choose_metamorphosis(PhaseBRootNetwork.MetamorphosisId.DEEP_TAPROOTS)
	prototype._apply_progression_modifiers()
	_check(
		metamorphosis_offered
		and development_held
		and network.get_metamorphosis(PhaseBRootNetwork.DomainId.ANCHORING)
		== PhaseBRootNetwork.MetamorphosisId.DEEP_TAPROOTS
		and prototype.territory_field.tuning.pressure_advection < advection_before,
		"a domain's metamorphosis is offered once, holds the drawer, and reaches the field"
	)

	# Neither half of a pair is the better one. Central Taproot concentrates the
	# reserve and abandons the colonies; Distributed Nodules does the reverse. The
	# check is that they disagree in opposite directions about the same two numbers.
	network.reset_network()
	for _storage_rank in range(network.metamorphosis_rank):
		network.debug_grant_development(PhaseBRootNetwork.DomainId.STORAGE)
	network.choose_metamorphosis(PhaseBRootNetwork.MetamorphosisId.CENTRAL_TAPROOT)
	var taproot_discharge := network.get_discharge_multiplier()
	network.reset_network()
	for _nodule_rank in range(network.metamorphosis_rank):
		network.debug_grant_development(PhaseBRootNetwork.DomainId.STORAGE)
	network.choose_metamorphosis(PhaseBRootNetwork.MetamorphosisId.DISTRIBUTED_NODULES)
	_check(
		taproot_discharge > network.get_discharge_multiplier()
		and network.central_taproot_colony_capacity
		< network.distributed_nodules_colony_capacity
		and network.central_taproot_primary_capacity
		> network.distributed_nodules_primary_capacity,
		"the Storage metamorphoses trade the same two numbers against each other"
	)
	network.reset_network()

	# Overgrow spends the Reserve into the material rather than granting territory.
	metabolism.reset_metabolism()
	network.reset_network()
	prototype.progression.reset_progression()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	prototype.territory_field.recalculate_metrics_now()
	# The reserve belongs to the organism, so it is earned rather than handed over.
	for _overgrow_bank in range(120):
		prototype.territory_field.step_simulation()
		network.advance(0.5, prototype.player.get_arena_position())
	var overgrow_reserve := network.get_primary_reserve()
	var overgrow_log: Array = []
	metabolism.overgrown.connect(
		func(mass: float, pressure: float, cohesion: float) -> void:
			overgrow_log.append([mass, pressure, cohesion])
	)
	var overgrew := metabolism.try_overgrow(prototype.player.get_arena_position())
	var overgrow_split: Array = (
		overgrow_log[0] if not overgrow_log.is_empty() else [0.0, 0.0, 0.0]
	)
	_check(
		overgrew
		and is_equal_approx(
			network.get_primary_reserve(),
			overgrow_reserve * (1.0 - metabolism.overgrow_reserve_fraction)
		)
		and float(overgrow_split[0]) > 0.0
		and float(overgrow_split[1]) > 0.0
		and not metabolism.can_overgrow(),
		"Overgrow spends half the organism's reserve, then goes on cooldown"
	)

	# The identity split follows the physique the run actually developed, so two
	# organisms pressing the same button get different physical results.
	metabolism.reset_metabolism()
	network.reset_network()
	metabolism.debug_grant_axis(PhaseBMetabolism.SystemId.MERISTEM, 4)
	_check(
		metabolism.get_identity_share(PhaseBMetabolism.SystemId.MERISTEM)
		> metabolism.get_identity_share(PhaseBMetabolism.SystemId.PHOTOSYNTHESIS),
		"Overgrow inherits the organism's own physique"
	)
	metabolism.reset_metabolism()
	network.reset_network()
	prototype.progression.reset_progression()

	# The HUD rules: the sidebar says what is true, the drawer is where decisions
	# are made, and anything with nothing to say is not on screen.
	metabolism.reset_metabolism()
	prototype.progression.reset_progression()
	prototype.combat.reset_combat()
	prototype._update_hud()
	var quiet_hostiles_shown := prototype.hostile_label.visible
	prototype.combat.spawn_pack(PhaseBCombatDirector.EnemyRole.HUNTER, 3)
	prototype._update_hud()
	var threatened_hostiles_shown := prototype.hostile_label.visible
	prototype.combat.reset_combat()
	_check(
		not quiet_hostiles_shown
		and threatened_hostiles_shown
		and prototype.hostile_label.text.contains("3"),
		"the hostile count appears only while there are hostiles to warn about"
	)

	# The Biomass line is the reserve and its rate, with a dot only when a decision
	# is actually affordable. Consumption and net are gone: nothing drains now.
	prototype.progression.reset_progression()
	prototype._update_hud()
	var broke_line := prototype.biomass_label.text
	# The ready state is a bud rather than a dot, because the doc asks for a change of
	# silhouette rather than a brighter version of the same mark. Priced down for this
	# check alone: what is being tested is that the line changes shape when a
	# development becomes affordable, not what a development happens to cost.
	var restore_bud_cost := network.development_base_cost
	network.development_base_cost = 1.0
	network.debug_fill_primary_reserve()
	# The label is written when the reserve is mirrored into Progression, which is
	# what the run loop does every frame, so the check goes through that same path
	# rather than poking the label.
	prototype.progression.set_biomass_from_network(
		network.get_primary_reserve(),
		network.get_primary_generation_per_second()
	)
	prototype._update_hud()
	var affordable_line := prototype.biomass_label.text
	_check(
		not broke_line.contains("
")
		and broke_line.contains("/s")
		and not broke_line.contains("CONSUMPTION")
		and not broke_line.contains("❦")
		and affordable_line.contains("❦"),
		"the Biomass line is one line of reserve and rate, budding only when it can be spent"
	)
	network.development_base_cost = restore_bud_cost

	# Every detailed Biomass decision lives in the drawer, and the drawer is closed
	# until it is asked for.
	var drawer_closed := not prototype.metabolism_drawer.visible
	prototype._toggle_metabolism_drawer()
	var drawer_open := prototype.metabolism_drawer.visible
	prototype._toggle_metabolism_drawer()
	_check(
		drawer_closed
		and drawer_open
		and not prototype.metabolism_drawer.visible
		and prototype.rooting_button.get_parent() == prototype.metabolism_drawer
		and prototype.overgrow_button.get_parent() == prototype.metabolism_drawer,
		"the Biomass drawer owns the detailed controls and opens only on request"
	)

	# A verb the organism cannot yet perform is not on screen at all rather than
	# sitting there disabled: the drawer grows with the run.
	metabolism.reset_metabolism()
	network.reset_network()
	prototype._update_metabolism_controls()
	var deep_root_hidden := not prototype.deep_root_button.visible
	var overgrow_shown := prototype.overgrow_button.visible
	network.debug_grant_development(PhaseBRootNetwork.DomainId.ROOTING)
	prototype._update_metabolism_controls()
	_check(
		deep_root_hidden
		and overgrow_shown
		and prototype.deep_root_button.visible
		and not prototype.pressurize_button.visible,
		"an undeveloped metabolic verb is absent from the drawer rather than sitting locked"
	)
	network.reset_network()

	# The first matching pair of a run stops the battlefield and lets the third reel
	# resolve on its own. Once per run: the point is the first time, and a game that
	# paused every time two reels agreed would be a game that pauses constantly.
	var machine_focus := prototype.slot_machine
	prototype.reset_run()
	machine_focus.reset_machine()
	var cinematic_before := prototype.is_pair_cinematic_active()
	prototype._on_pair_tease_started(CloverSlot.Symbol.BLOOM, true)
	var cinematic_running := prototype.is_pair_cinematic_active()
	var field_held := prototype.territory_field.simulation_paused
	# Long enough to carry the focus in, the reel, and the focus back out.
	for _focus_step in range(600):
		prototype._advance_pair_focus(1.0 / 60.0)
	_check(
		not cinematic_before
		and cinematic_running
		and field_held
		and not prototype.is_pair_cinematic_active()
		and not prototype.territory_field.simulation_paused,
		"the first matching pair holds the battlefield still and then gives it back"
	)

	# A later pair leans the panel in without stopping anything, which is the whole
	# difference between the cinematic and the tease.
	prototype._on_pair_tease_started(CloverSlot.Symbol.BLOOM, false)
	var later_focus := prototype.is_pair_focus_active()
	var later_pause := prototype.territory_field.simulation_paused
	for _tease_step in range(600):
		prototype._advance_pair_focus(1.0 / 60.0)
	_check(
		later_focus
		and not later_pause
		and prototype.pair_tease_scale < prototype.pair_focus_scale,
		"a later matching pair leans the panel in without pausing the run"
	)

	# The rewind is an animation and never a rig. Its stages have to run in order and
	# land the reel back on the symbol the machine rolled before the lever finished
	# moving, so the fakeout cannot change what was already decided.
	var rewind_stages := PackedInt32Array()
	var rewind_offsets := PackedFloat32Array()
	if machine_focus.rewind_seconds.size() >= 3:
		var probe_reel := prototype._reel_window(2)
		if probe_reel != null:
			var total := machine_focus.tease_reel_stop_seconds
			for span in machine_focus.rewind_seconds:
				total += span
			var step := 0.02
			var sampled := 0.0
			while sampled < total:
				sampled += step
				var stage := machine_focus.get_rewind_stage()
				if stage != PhaseBSlotMachine.RewindStage.NONE:
					if rewind_stages.is_empty() or rewind_stages[-1] != stage:
						rewind_stages.append(stage)
					rewind_offsets.append(prototype._reel_offset[2])
	_check(
		machine_focus.jackpot_rewind_chance > 0.0
		and machine_focus.rewind_seconds.size() == 3
		and PhaseBSlotMachine.RewindStage.PASS < PhaseBSlotMachine.RewindStage.HOLD
		and PhaseBSlotMachine.RewindStage.HOLD < PhaseBSlotMachine.RewindStage.SNAP,
		"the rewind reserves a pass, a hold, and a reverse snap, in that order"
	)

	# Telemetry records and never judges: nothing it holds is read by the machine, and
	# with it switched off it costs a run nothing at all.
	var telemetry := prototype.clover_telemetry
	telemetry.reset_telemetry()
	telemetry.enabled = false
	telemetry._on_spin_started(CloverSlot.Stake.LOW, PackedInt32Array([1, 2, 3]))
	telemetry._on_spin_resolved(CloverSlot.Outcome.WHIFF, -1, CloverSlot.Stake.LOW)
	var silent_rows := telemetry.get_row_count()
	telemetry.enabled = true
	telemetry._on_spin_started(CloverSlot.Stake.ALL_IN, PackedInt32Array([1, 2, 3]))
	telemetry._on_spin_resolved(
		CloverSlot.Outcome.PATH_JACKPOT,
		CloverSlot.Symbol.ROOT,
		CloverSlot.Stake.ALL_IN
	)
	var row := telemetry.get_last_row()
	_check(
		silent_rows == 0
		and telemetry.get_row_count() == 1
		and int(row.get("stake_tier", -1)) == CloverSlot.Stake.ALL_IN
		and row.has("owned_green_before_spin")
		and row.has("owned_green_after_result")
		and row.has("effective_path_jackpot_chance")
		and row.has("triple_bust_chance")
		and telemetry.describe_run().contains("jackpots 1"),
		"telemetry writes one row per spin, only when it is switched on"
	)
	telemetry.enabled = false
	telemetry.reset_telemetry()

	# Presentation settings. The guide's central rule is that these are not one
	# global opacity dial: turning your own spectacle down to see the fight must not
	# turn down the thing that tells you the fight is about to hit you.
	var settings := prototype.display_settings
	settings.reset_settings()
	var quiet_friendly := settings.get_friendly_effect_scale()
	settings.set_choice(
		PhaseBDisplaySettings.OptionId.FRIENDLY_EFFECTS,
		PhaseBDisplaySettings.FriendlyEffects.QUARTER
	)
	_check(
		settings.get_friendly_effect_scale() < quiet_friendly
		and is_equal_approx(settings.get_telegraph_alpha_scale(), 1.0)
		and settings.get_telegraph_width_bonus() >= 0.0,
		"quietening friendly effects leaves enemy telegraphs exactly as they were"
	)

	# And High Contrast raises them above normal rather than merely declining to
	# lower them, because the option exists to make danger louder.
	settings.set_choice(
		PhaseBDisplaySettings.OptionId.ENEMY_TELEGRAPHS,
		PhaseBDisplaySettings.EnemyTelegraphs.HIGH_CONTRAST
	)
	_check(
		settings.get_telegraph_alpha_scale() > 1.0
		and settings.get_telegraph_width_bonus() > 0.0,
		"High Contrast makes enemy telegraphs brighter and thicker than Normal"
	)

	# Territory Detail is cosmetic only. The doc is explicit that the simulation is
	# identical at every level, so dropping to Low must not move a field parameter.
	var spread_at_high := prototype.territory_field.tuning.natural_spread_rate
	var maturation_at_high := prototype.territory_field.tuning.maturation_per_second
	settings.set_choice(
		PhaseBDisplaySettings.OptionId.TERRITORY_DETAIL,
		PhaseBDisplaySettings.TerritoryDetail.LOW
	)
	_check(
		is_equal_approx(
			prototype.territory_field.tuning.natural_spread_rate,
			spread_at_high
		)
		and is_equal_approx(
			prototype.territory_field.tuning.maturation_per_second,
			maturation_at_high
		)
		and is_equal_approx(settings.get_territory_detail_scale(), 0.0),
		"Territory Detail changes only cosmetic detail and never the simulation"
	)

	# Damage Numbers: Important Only keeps what carries information and drops the
	# stream of small hits.
	settings.set_choice(
		PhaseBDisplaySettings.OptionId.DAMAGE_NUMBERS,
		PhaseBDisplaySettings.DamageNumbers.IMPORTANT_ONLY
	)
	var important_kept := settings.should_show_damage_number(true)
	var ordinary_dropped := not settings.should_show_damage_number(false)
	settings.set_choice(
		PhaseBDisplaySettings.OptionId.DAMAGE_NUMBERS,
		PhaseBDisplaySettings.DamageNumbers.OFF
	)
	_check(
		important_kept
		and ordinary_dropped
		and not settings.should_show_damage_number(true),
		"Important Only keeps the hits that mean something and Off keeps none"
	)

	# UI Scale scales the interface and deliberately not the battlefield: scaling the
	# HUD must not change how much arena the player can see.
	settings.reset_settings()
	var arena_transform := prototype.territory_field.transform
	settings.set_choice(PhaseBDisplaySettings.OptionId.UI_SCALE, 4)
	prototype._on_display_settings_changed()
	_check(
		is_equal_approx(prototype.interface_layer.transform.get_scale().x, 1.25)
		and prototype.territory_field.transform == arena_transform,
		"UI Scale scales the interface and leaves the battlefield alone"
	)

	# HUD Detail reveals more of the same layout rather than a second design, so the
	# same label carries more.
	settings.reset_settings()
	prototype._update_hud()
	var compact_clock := prototype.clock_label.text
	settings.set_choice(
		PhaseBDisplaySettings.OptionId.HUD_DETAIL,
		PhaseBDisplaySettings.HudDetail.DETAILED
	)
	prototype._update_hud()
	_check(
		prototype.clock_label.text.length() > compact_clock.length()
		and prototype.clock_label.text.begins_with(compact_clock.substr(0, 4)),
		"Detailed reveals more on the line Compact already had"
	)

	# Every option cycles through its own list and wraps, which is what makes one
	# button per row a complete control rather than a one-way ratchet.
	settings.reset_settings()
	var every_option_cycles := true
	for option_id in range(PhaseBDisplaySettings.OptionId.size()):
		var count := PhaseBDisplaySettings.get_choice_count(option_id)
		var opening := settings.get_choice(option_id)
		for _cycle_step in range(count):
			settings.cycle_choice(option_id)
		if settings.get_choice(option_id) != opening or count < 2:
			every_option_cycles = false
		if PhaseBDisplaySettings.get_option_name(option_id).is_empty():
			every_option_cycles = false
	_check(
		every_option_cycles
		and prototype.setting_buttons.size() == PhaseBDisplaySettings.OptionId.size(),
		"every presentation option is named, cycles its own list, and wraps"
	)
	settings.reset_settings()
	prototype._on_display_settings_changed()

	# A major event takes the battlefield briefly and then gives it back.
	prototype._show_banner("NEW ORGAN")
	var banner_shown := prototype.banner_label.modulate.a > 0.9
	prototype._advance_banner(prototype.banner_seconds + 0.1)
	_check(
		banner_shown
		and prototype.banner_label.modulate.a <= 0.01,
		"a major event banner fades off the battlefield instead of becoming a HUD section"
	)
	metabolism.reset_metabolism()
	prototype.progression.reset_progression()

	# The growth-line slots: what the run holds plus the one it is working toward.
	# The row grows with the run rather than opening as a wall of padlocks, and each
	# slot carries its own resolved hover text.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.BRAMBLE,
		PhaseBProgression.PathId.ROOT
	)
	prototype.progression._upgrade_levels[
		PhaseBProgression.UpgradeId.THORNSHOT_POWER
	] = 3
	prototype.progression._upgrade_levels[
		PhaseBProgression.UpgradeId.BRAMBLE_ENTANGLEMENT
	] = 2
	prototype._apply_progression_modifiers()
	prototype._update_hud()
	var slot_row := prototype.upgrade_slots
	var filled_tooltip := slot_row.get_slot_tooltip(0)
	var empty_tooltip := slot_row.get_slot_tooltip(2)
	var locked_tooltip := slot_row.get_slot_tooltip(
		prototype.progression.upgrade_slot_count
	)
	var expected_damage := (
		prototype.combat.thornshot_damage
		* prototype.progression.get_thornshot_damage_multiplier()
	)
	_check(
		slot_row.get_slot_count()
		== prototype.progression.get_upgrade_slot_count() + 1
		and slot_row.get_slot_count()
		< prototype.progression.upgrade_slot_count
			+ prototype.progression.evolution_bonus_upgrade_slots
		and filled_tooltip.contains("Thornshot Power")
		and filled_tooltip.contains("3/5")
		and filled_tooltip.contains("%.1f damage per Thornshot" % expected_damage)
		and empty_tooltip.contains("Empty growth slot")
		and locked_tooltip.contains("Locked growth slot"),
		"the growth tray shows what the run holds, one slot ahead, and no further"
	)

	# A slot has to survive the HUD refreshing under it. The rows re-assert their
	# length several times a second, and rebuilding on an assignment that changed
	# nothing destroyed every slot ten times a second: long enough to draw, never
	# long enough to finish the half-second hover a tooltip needs.
	var relic_panel := prototype.relic_slots.get_child(0, true)
	var upgrade_panel := slot_row.get_child(0, true)
	var relic_instance := relic_panel.get_instance_id()
	var upgrade_instance := upgrade_panel.get_instance_id()
	for _refresh in range(5):
		prototype._update_hud()
	_check(
		is_instance_valid(relic_panel)
		and prototype.relic_slots.get_child(0, true).get_instance_id() == relic_instance
		and is_instance_valid(upgrade_panel)
		and slot_row.get_child(0, true).get_instance_id() == upgrade_instance,
		"slots survive a HUD refresh, so a hover can last long enough to raise a tooltip"
	)

	# A held relic explains itself on hover, the way an upgrade line does.
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.PREDATORS_EYE] = 1
	prototype._update_hud()
	var relic_tooltip := prototype.relic_slots.get_slot_tooltip(0)
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.PREDATORS_EYE] = 0
	_check(
		relic_tooltip.contains("Predator's Eye")
		and relic_tooltip.contains(
			PhaseBRelicCatalog.get_relic_description(PhaseBRelicCatalog.Id.PREDATORS_EYE)
		)
		and relic_tooltip.contains("COMMON"),
		"a held relic's hover carries its name, rarity, and what the relic actually does"
	)

	# A locked slot carries the icon and no text at all; an empty one keeps only its
	# marker.
	_check(
		slot_row.locked_icon != null
		and slot_row.is_slot_locked_icon_visible(
			prototype.progression.upgrade_slot_count
		)
		and slot_row.get_slot_level_text(
			prototype.progression.upgrade_slot_count
		).is_empty()
		and slot_row.get_slot_level_text(2).is_empty()
		and slot_row.get_slot_level_text(0) == "3",
		"a filled slot shows its rank alone, locked slots the icon alone, empty slots nothing"
	)

	# Slots keep their order, and the last two unlock on evolving.
	var slotted_before := prototype.progression.get_slotted_upgrades()
	prototype.progression._upgrade_levels[
		PhaseBProgression.UpgradeId.ROOT_POTENCY
	] = 1
	var slotted_after := prototype.progression.get_slotted_upgrades()
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	prototype._apply_progression_modifiers()
	prototype._update_hud()
	var unlocked_tooltip := slot_row.get_slot_tooltip(
		prototype.progression.upgrade_slot_count
	)
	_check(
		slotted_after.size() == slotted_before.size() + 1
		and slotted_after[0] == slotted_before[0]
		and slotted_after[1] == slotted_before[1]
		and not unlocked_tooltip.contains("Locked growth slot")
		and prototype.slots_label.text == prototype._format_slots_caption(),
		"a line keeps its slot for the run, and evolving unlocks the last two"
	)

	# The row grew with the run: it never showed the evolution's slots in advance.
	_check(
		slot_row.get_slot_count()
		> prototype.progression.upgrade_slot_count
		and slot_row.get_slot_count()
		<= prototype.progression.upgrade_slot_count
			+ prototype.progression.evolution_bonus_upgrade_slots,
		"claiming the Evolution expands the growth tray toward its authored ceiling"
	)

	# The caption is whatever the label was authored with: both counts, the filled
	# count, or plain words.
	var authored_caption := prototype._slots_label_format
	prototype._slots_label_format = "LINES %d OF %d"
	var two_count_caption := prototype._format_slots_caption()
	prototype._slots_label_format = "LINES %d"
	var one_count_caption := prototype._format_slots_caption()
	prototype._slots_label_format = "UPGRADES"
	var plain_caption := prototype._format_slots_caption()
	prototype._update_hud()
	var plain_reached_label := prototype.slots_label.text
	prototype._slots_label_format = authored_caption
	_check(
		two_count_caption == "LINES %d OF %d" % [
			prototype.progression.get_slotted_upgrades().size(),
			prototype.progression.get_upgrade_slot_count(),
		]
		and one_count_caption == "LINES %d" % (
			prototype.progression.get_slotted_upgrades().size()
		)
		and plain_caption == "UPGRADES"
		and plain_reached_label == "UPGRADES",
		"an authored growth-line caption reaches the running game unchanged"
	)
	prototype.progression.reset_progression()
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false

	# Relic rewards are choose-one-of-three out of a pool far larger than the run
	# will ever see, weighted by rarity, and no relic can be offered twice.
	prototype.progression.request_relic_choice()
	var relic_offer := prototype.progression.get_pending_relic_options()
	var relic_offer_is_valid := (
		relic_offer.size() == prototype.progression.relic_offer_count
	)
	var seen_relics := {}
	for offered_id in relic_offer:
		relic_offer_is_valid = (
			relic_offer_is_valid
			and prototype.progression.is_relic_eligible(offered_id)
			and not seen_relics.has(offered_id)
		)
		seen_relics[offered_id] = true
	_check(
		prototype.choice_panel.visible and relic_offer_is_valid,
		"elite relic rewards offer three distinct eligible relics on the paused panel"
	)

	# The button says what kind of rule change it is, because rarity is the
	# readout of impact rather than of raw numbers.
	var rarity_named := prototype.choice_buttons[0].text.contains(
		PhaseBRelicCatalog.get_rarity_name(
			PhaseBRelicCatalog.get_rarity(relic_offer[0])
		)
	)
	var claimed_relic := relic_offer[0]
	prototype._choose_displayed_option(0)
	_check(
		rarity_named and prototype.progression.has_relic(claimed_relic),
		"a relic offer names its rarity and the claimed relic is granted"
	)

	# A relic already held is never offered again.
	prototype.progression.request_relic_choice()
	var second_offer := prototype.progression.get_pending_relic_options()
	_check(
		second_offer.find(claimed_relic) == -1,
		"a relic the run already holds is excluded from later offers"
	)

	# Relic offers can be rerolled now that they are a sample rather than the
	# whole pool, and the reroll spends its own budget.
	var rerolls_before := prototype.progression.get_relic_rerolls_remaining()
	var rerolled := prototype.progression.reroll_relic_choice()
	_check(
		rerolled
		and prototype.progression.get_relic_rerolls_remaining() == rerolls_before - 1
		and prototype.progression.get_pending_relic_options().size()
		== prototype.progression.relic_offer_count,
		"a relic reward can be rerolled from its own reroll budget"
	)
	prototype.progression._pending_relic_options.clear()
	prototype._choice_kind = PhaseBPrototype.ChoiceKind.NONE
	prototype.choice_panel.visible = false

	# Eligibility follows mechanics, not path names. A synergy relic is locked
	# until the run actually provides both mechanics it needs, whichever slot
	# supplied them.
	prototype.progression.reset_progression()
	var locked_without_both := prototype.progression.is_relic_eligible(
		PhaseBRelicCatalog.Id.STORED_SAP
	)
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.ROOT,
		PhaseBProgression.PathId.PRUNING
	)
	var unlocked_with_both := prototype.progression.is_relic_eligible(
		PhaseBRelicCatalog.Id.STORED_SAP
	)
	var path_relic_locked := prototype.progression.is_relic_eligible(
		PhaseBRelicCatalog.Id.THE_HEDGE
	)
	var universal_always := prototype.progression.is_relic_eligible(
		PhaseBRelicCatalog.Id.PREDATORS_EYE
	)
	_check(
		not locked_without_both
		and unlocked_with_both
		and not path_relic_locked
		and universal_always,
		"relic eligibility follows mechanics and paths rather than hard-coded pairs"
	)

	# ---------------------------------------------------------------- relic rules
	# Every relic below is a rule change, so each check asserts the rule rather
	# than a number, and the recursion limiters get their own checks because a
	# relic engine that feeds itself is the failure mode this catalog guards.
	prototype.progression.reset_progression()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	var relics := prototype.relic_director
	relics.reset_director()

	# Predator's Eye: a strictly distinct extra target every tenth volley, and
	# nothing at all when there is no second enemy to take it.
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.PREDATORS_EYE] = 1
	relics.apply_relics()
	var lone_spot := _find_owned_cell_position(prototype)
	prototype.player.global_position = prototype.territory_field.to_global(lone_spot)
	prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER,
		lone_spot + Vector2(40.0, 0.0)
	)
	var lone_volley_shots := 0
	for _lone_volley in range(relics.predators_eye_interval):
		prototype.combat._thornshot_remaining = 0.0
		var before := prototype.combat.get_active_projectile_count()
		prototype.combat.simulate_step(1.0 / 60.0)
		lone_volley_shots = prototype.combat.get_active_projectile_count() - before
	var lone_extra_blocked := lone_volley_shots <= 1

	prototype.combat.reset_combat()
	for crowd_index in range(4):
		prototype.combat.spawn_enemy(
			PhaseBCombatDirector.EnemyRole.HUNTER,
			lone_spot + Vector2.from_angle(float(crowd_index) * 1.4) * 60.0
		)
	prototype.combat._predators_eye_progress = relics.predators_eye_interval - 1
	prototype.combat._thornshot_remaining = 0.0
	var crowd_before := prototype.combat.get_active_projectile_count()
	prototype.combat.simulate_step(1.0 / 60.0)
	var crowd_shots := prototype.combat.get_active_projectile_count() - crowd_before
	_check(
		lone_extra_blocked and crowd_shots == 2,
		"PREDATOR'S EYE adds a distinct extra target, and nothing when alone"
	)
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.PREDATORS_EYE] = 0

	# Overpopulation: six fast kills prime one explosion, and the explosion can
	# neither consume the next charge nor count toward it.
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.OVERPOPULATION] = 1
	relics.apply_relics()
	relics.reset_director()
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.OVERPOPULATION] = 1
	for _prime_kill in range(relics.overpopulation_kills):
		prototype.combat.enemy_killed.emit(
			lone_spot,
			1,
			PhaseBCombatDirector.EnemyRole.HUNTER,
			PhaseBCombatDirector.DeathSource.THORNSHOT,
			0
		)
	var primed := relics._overpopulation_primed
	# A relic kill must not be able to spend the charge.
	prototype.combat.enemy_killed.emit(
		lone_spot,
		1,
		PhaseBCombatDirector.EnemyRole.HUNTER,
		PhaseBCombatDirector.DeathSource.RELIC,
		0
	)
	var still_primed := relics._overpopulation_primed
	prototype.combat.enemy_killed.emit(
		lone_spot,
		1,
		PhaseBCombatDirector.EnemyRole.HUNTER,
		PhaseBCombatDirector.DeathSource.THORNSHOT,
		0
	)
	_check(
		primed and still_primed and not relics._overpopulation_primed,
		"OVERPOPULATION primes on a kill streak and its own blast cannot chain"
	)
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.OVERPOPULATION] = 0

	# Encore: every third non-Legendary trigger repeats once, Legendary triggers
	# are excluded, and a repeat can never advance the counter that made it.
	relics.reset_director()
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.ENCORE] = 1
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.COMPOST] = 1
	relics.apply_relics()
	for _legendary_trigger in range(5):
		relics._notify_triggered(PhaseBRelicCatalog.Id.WORLD_SEED)
	var legendary_ignored := relics._encore_counter == 0
	for _common_trigger in range(relics.encore_interval):
		relics._notify_triggered(PhaseBRelicCatalog.Id.COMPOST)
	var queued := relics._encore_queue.size() == 1
	var counter_after_queue := relics._encore_counter
	for _settle in range(int(relics.encore_delay_seconds * 60.0) + 8):
		relics.advance(1.0 / 60.0)
	_check(
		legendary_ignored
		and queued
		and counter_after_queue == 0
		and relics._encore_queue.is_empty()
		and relics._encore_counter == 0,
		"ENCORE skips Legendary triggers and its repeats never advance itself"
	)
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.ENCORE] = 0
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.COMPOST] = 0

	# Compost is a fixed counter on Mature ground, not an arena percentage.
	relics.reset_director()
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.COMPOST] = 1
	relics.apply_relics()
	var mature_spot := _find_owned_cell_position(prototype)
	for _ripen in range(4):
		prototype.territory_field.queue_maturity_support(mature_spot, 1.0, 3.0)
		prototype.territory_field.step_simulation()
	var biomass_before_compost := prototype.progression.biomass
	for _compost_kill in range(relics.compost_kills):
		prototype.combat.enemy_killed.emit(
			mature_spot,
			1,
			PhaseBCombatDirector.EnemyRole.HUNTER,
			PhaseBCombatDirector.DeathSource.THORNSHOT,
			0
		)
	_check(
		prototype.progression.biomass > biomass_before_compost,
		"COMPOST pays out on a fixed count of kills on Mature Green"
	)
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.COMPOST] = 0

	# Canopy absorbs part of a hit taken on Mature Green, then goes on cooldown.
	relics.reset_director()
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.CANOPY] = 1
	relics.apply_relics()
	prototype.player.reset_player()
	prototype.player.global_position = prototype.territory_field.to_global(mature_spot)
	prototype.player.apply_damage(20.0)
	var absorbed_loss := prototype.player.get_max_health() - prototype.player.get_health()
	var on_cooldown := prototype.player.get_damage_absorption_remaining() > 0.0
	_check(
		absorbed_loss < 20.0 and absorbed_loss > 0.0 and on_cooldown,
		"CANOPY absorbs part of a hit on Mature Green and then waits"
	)
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.CANOPY] = 0
	relics.apply_relics()

	# Hard Husk: the first interruption is shrugged off entirely rather than
	# softened, so a Saboteur cannot chip a Seed down through the shield.
	relics.reset_director()
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.HARD_HUSK] = 1
	relics.apply_relics()
	prototype.overlay.clear_effects()
	var husk_spot := _find_owned_cell_position(prototype)
	var husk_seed := prototype.overlay.spawn_seed(husk_spot, 4.0, 0, 1.0)
	prototype.overlay.damage_nearest_catalyst(husk_spot, 30.0, 99.0)
	var survived_first := prototype.overlay.has_seed(husk_seed)
	prototype.overlay.damage_nearest_catalyst(husk_spot, 30.0, 99.0)
	_check(
		survived_first and not prototype.overlay.has_seed(husk_seed),
		"HARD HUSK ignores the first hit outright and the second still lands"
	)
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.HARD_HUSK] = 0
	relics.apply_relics()
	prototype.overlay.clear_effects()

	# Cross-Pollination advances nearby Seeds, and the receiving cooldown is what
	# stops a field of Seeds accelerating each other without end.
	relics.reset_director()
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.CROSS_POLLINATION] = 1
	relics.apply_relics()
	var pollen_spot := _find_owned_cell_position(prototype)
	var neighbour_seed := prototype.overlay.spawn_seed(
		pollen_spot + Vector2(30.0, 0.0),
		6.0,
		0,
		1.0
	)
	var neighbour_before := prototype.overlay.get_seed_progress(neighbour_seed)
	relics._on_seed_germinated(pollen_spot, 0)
	var neighbour_after := prototype.overlay.get_seed_progress(neighbour_seed)
	relics._on_seed_germinated(pollen_spot, 0)
	var neighbour_capped := prototype.overlay.get_seed_progress(neighbour_seed)
	_check(
		neighbour_after > neighbour_before
		and is_equal_approx(neighbour_capped, neighbour_after),
		"CROSS-POLLINATION advances nearby Seeds and its cooldown stops a chain"
	)
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.CROSS_POLLINATION] = 0
	prototype.overlay.clear_effects()

	# Regrowth is a field rule: lost ground remembers it was ours and comes back.
	relics.reset_director()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	var memory_spot := _find_owned_cell_position(prototype)
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.REGROWTH] = 1
	relics.apply_relics()
	prototype.territory_field.step_simulation()
	var remembered := prototype.territory_field.get_regrowth_memory_at_local(memory_spot)
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.REGROWTH] = 0
	relics.apply_relics()
	var forgotten := prototype.territory_field.get_regrowth_memory_at_local(memory_spot)
	_check(
		remembered > 0.0 and forgotten <= 0.0,
		"REGROWTH remembers owned ground, and turning it off clears the layer"
	)

	# Blood in the Water changes what the Core Weapon wants, not what it hits for.
	prototype.combat.reset_combat()
	prototype.player.global_position = prototype.territory_field.to_global(lone_spot)
	var healthy_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER,
		lone_spot + Vector2(40.0, 0.0)
	)
	var wounded_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER,
		lone_spot + Vector2(150.0, 0.0)
	)
	prototype.combat.damage_enemy_by_id(
		wounded_id,
		prototype.combat.get_enemy_health(wounded_id) * 0.9,
		PhaseBCombatDirector.DeathSource.DEBUG
	)
	prototype.combat.set_relic_rules(0, 0.0, 0.55, 0.0, 0, 0.0, 1.0)
	prototype.combat._collect_thornshot_targets(1)
	var nearest_first := prototype.combat._thornshot_targets[0].id == healthy_id
	prototype.combat.set_relic_rules(0, 0.0, 0.55, 0.20, 0, 0.0, 1.0)
	prototype.combat._collect_thornshot_targets(1)
	var wounded_first := prototype.combat._thornshot_targets[0].id == wounded_id
	prototype.combat.set_relic_rules(0, 0.0, 0.55, 0.0, 0, 0.0, 1.0)
	_check(
		nearest_first and wounded_first,
		"BLOOD IN THE WATER repoints the Core Weapon at badly wounded enemies"
	)

	# Snare Vine spreads a capped share of a root to the nearest few enemies.
	prototype.combat.reset_combat()
	relics.reset_director()
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.SNARE_VINE] = 1
	relics.apply_relics()
	var snare_ids := PackedInt32Array()
	for snare_index in range(4):
		snare_ids.append(prototype.combat.spawn_enemy(
			PhaseBCombatDirector.EnemyRole.HUNTER,
			lone_spot + Vector2.from_angle(float(snare_index) * 1.2) * 30.0
		))
	prototype.combat.enemy_rooted.emit(lone_spot)
	var snared := 0
	for snare_id in snare_ids:
		if prototype.combat.get_enemy_entanglement(snare_id) > 0.0:
			snared += 1
	_check(
		snared > 0 and snared <= relics.snare_vine_targets,
		"SNARE VINE spreads Entanglement to a capped number of neighbours"
	)
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.SNARE_VINE] = 0
	prototype.combat.reset_combat()

	# Gleaning Hook banks Charge off ring kills, capped per hold.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.PRUNING,
		PhaseBProgression.PathId.SPORE
	)
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.GLEANING_HOOK] = 1
	prototype._apply_progression_modifiers()
	relics.apply_relics()
	var gleaning := prototype.pruning_director
	gleaning.reset_director()
	gleaning._charge = 0.0
	var payouts := int(ceil(gleaning.gleaning_hook_maximum / gleaning.gleaning_hook_charge)) + 2
	for _gleaning_kill in range(gleaning.gleaning_hook_kills * payouts):
		gleaning.notify_ring_kill(false)
	_check(
		gleaning.get_gleaning_banked_charge() > 0.0
		and gleaning.get_gleaning_banked_charge()
		<= gleaning.gleaning_hook_maximum + 0.0001,
		"GLEANING HOOK banks Charge from ring kills and stops at its cap"
	)
	prototype.progression._owned_relics[PhaseBRelicCatalog.Id.GLEANING_HOOK] = 0

	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	relics.reset_director()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	prototype.territory_field.reset_field()

	# Insurance Policy needs a mechanic the prototype does not have, so it is
	# authored but never offered until the objective layer exists.
	_check(
		not prototype.progression.is_relic_eligible(
			PhaseBRelicCatalog.Id.INSURANCE_POLICY
		),
		"a relic requiring an unimplemented mechanic is never offered"
	)
	prototype.progression.reset_progression()

	# Relic rewards are on a wave schedule as well as on the elite and the boss.
	# A crossing owes the run a relic only on the authored cycle, and the debt is
	# paid out by the run loop once no other choice holds the panel.
	var relic_cycle := prototype.relic_reward_wave_cycle
	prototype._owed_wave_relics = 0
	prototype._on_wave_began(relic_cycle + 1)
	var off_cycle_owed := prototype._owed_wave_relics
	prototype._on_wave_began(relic_cycle * 2)
	var on_cycle_owed := prototype._owed_wave_relics
	prototype._owed_wave_relics = 0
	_check(
		relic_cycle > 0 and off_cycle_owed == 0 and on_cycle_owed == 1,
		"every %dth wave owes the run a relic reward and the waves between owe none"
		% relic_cycle
	)
	_check(
		prototype.wave_director.announced_wave_number
		== prototype.wave_director.get_current_wave_number(),
		"the wave director has announced every wave the run clock has crossed"
	)

	prototype.progression.debug_complete_evolution_requirements()
	_check(
		prototype.progression.evolution_status == PhaseBProgression.EvolutionStatus.READY,
		"maxing one Spore and one Bloom line marks Evolution Ready"
	)
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var evolution_draft := prototype.progression.get_pending_upgrade_options()
	var evolution_index := evolution_draft.find(
		PhaseBProgression.EVOLUTION_DRAFT_OPTION
	)
	var evolution_button_text := ""
	if evolution_index >= 0:
		evolution_button_text = prototype.choice_buttons[evolution_index].text
	_check(
		evolution_index >= 0
		and evolution_draft.size() == 3
		and evolution_button_text.contains("SUPER BLOOM")
		and evolution_button_text.contains("EVOLUTION"),
		"a ready pairing is offered inside the level-up draft alongside two upgrades"
	)
	prototype.progression.reroll_upgrade_choice()
	_check(
		prototype.progression.get_pending_upgrade_options().has(
			PhaseBProgression.EVOLUTION_DRAFT_OPTION
		),
		"a ready pairing survives a reroll so it cannot be drafted away"
	)
	prototype._choose_displayed_option(
		prototype.progression.get_pending_upgrade_options().find(
			PhaseBProgression.EVOLUTION_DRAFT_OPTION
		)
	)
	_check(
		prototype.progression.evolution_status == PhaseBProgression.EvolutionStatus.EVOLVED
		and prototype.progression.active_evolution
		== PhaseBProgression.EvolutionId.SUPER_BLOOM,
		"choosing the pairing in the draft grants Super Bloom immediately"
	)
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	_check(
		not prototype.progression.get_pending_upgrade_options().has(
			PhaseBProgression.EVOLUTION_DRAFT_OPTION
		),
		"an evolved run stops offering the pairing in later drafts"
	)
	prototype._choose_displayed_option(0)

	prototype.combat.reset_combat()
	var boss_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.BOSS,
		Vector2(760.0, 330.0)
	)
	prototype.combat.debug_damage_enemy(boss_id, 100000.0)
	_check(
		prototype.choice_panel.visible
		and prototype.choice_header.text == "ELITE RELIC",
		"defeating the boss now pays out a relic instead of gating the evolution"
	)
	prototype._choose_displayed_option(0)

	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	var chain_center := Vector2(735.0, 350.0)
	for index in range(prototype.evolutions.secondary_kills_per_seed):
		prototype.combat.spawn_enemy(
			PhaseBCombatDirector.EnemyRole.HUNTER,
			chain_center + Vector2(float(index) * 2.0, 0.0)
		)
	var explosion_count_before_bloom := prototype.combat.get_plant_explosion_sfx_play_count()
	prototype.bloom_director.on_bloom_detonated(chain_center, 1)
	_check(
		prototype.combat.get_plant_explosion_sfx_play_count()
		== explosion_count_before_bloom + 1,
		"Bloom and Super Bloom detonations play the authored explosion SFX"
	)
	_check(
		prototype.overlay.get_active_seed_count() == 1,
		"Super Bloom kills propagate one safeguarded secondary Seed"
	)

	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	var wall_source := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.475,
		prototype.territory_field.tuning.arena_size.y * 0.20
	)
	var wall_open_side := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.415,
		prototype.territory_field.tuning.arena_size.y * 0.20
	)
	var wall_shadow := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.56,
		prototype.territory_field.tuning.arena_size.y * 0.20
	)
	_check(
		prototype.territory_field.is_growth_path_clear(wall_source, wall_open_side)
		and not prototype.territory_field.is_growth_path_clear(wall_source, wall_shadow),
		"combat occlusion fixture has an open target and a target behind basalt"
	)
	var open_enemy_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER,
		wall_open_side
	)
	var shadow_enemy_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER,
		wall_shadow
	)
	prototype.combat.damage_enemies_in_radius(
		wall_source,
		150.0,
		10000.0,
		PhaseBCombatDirector.DeathSource.BLOOM
	)
	_check(
		not prototype.combat.is_enemy_active(open_enemy_id)
		and prototype.combat.is_enemy_active(shadow_enemy_id),
		"Bloom and germination damage cannot hit enemies through basalt walls"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.debug_advance_time(prototype.wave_director.elite_time_seconds)
	_check(
		prototype.combat.get_active_enemy_count_by_role(
			PhaseBCombatDirector.EnemyRole.ELITE
		) == 1,
		"the shortened timeline introduces its elite milestone"
	)
	var timeline_primary_index := prototype.progression.get_pending_path_options().find(
		PhaseBProgression.PathId.SPORE
	)
	prototype._choose_displayed_option(timeline_primary_index)
	prototype.debug_advance_time(
		prototype.wave_director.boss_time_seconds
		- prototype.wave_director.elite_time_seconds
	)
	_check(
		not prototype.combat.has_active_boss()
		and prototype.is_wave_grace_period_active(),
		"the Burrower waits through the grace period at its wave milestone"
	)
	var timeline_secondary_index := prototype.progression.get_pending_path_options().find(
		PhaseBProgression.PathId.BLOOM
	)
	prototype._choose_displayed_option(timeline_secondary_index)
	prototype.debug_advance_time(prototype.wave_director.wave_grace_period_seconds)
	_check(
		prototype.combat.has_active_boss(),
		"the Burrower arrives immediately after its milestone grace ends"
	)
	prototype.debug_advance_time(
		prototype.wave_director.final_invasion_time_seconds - prototype.get_elapsed_seconds()
	)
	_check(
		prototype.wave_director.final_invasion_started,
		"the final invasion phase begins on the timeline"
	)
	var specialist_schedule_is_authored := true
	var specialist_schedule: Array[Array] = [
		[
			prototype.wave_director.saboteur_intro_seconds,
			prototype.wave_director.saboteur_pack_cycle,
			PhaseBCombatDirector.EnemyRole.SABOTEUR,
		],
		[
			prototype.wave_director.corruptor_intro_seconds,
			prototype.wave_director.corruptor_pack_cycle,
			PhaseBCombatDirector.EnemyRole.CORRUPTOR,
		],
		[
			prototype.wave_director.colonizer_intro_seconds,
			prototype.wave_director.colonizer_pack_cycle,
			PhaseBCombatDirector.EnemyRole.COLONIZER,
		],
		[
			prototype.wave_director.warden_intro_seconds,
			prototype.wave_director.warden_pack_cycle,
			PhaseBCombatDirector.EnemyRole.WARDEN,
		],
	]
	for specialist_entry in specialist_schedule:
		prototype.wave_director.elapsed_seconds = specialist_entry[0]
		prototype.wave_director._spawn_pack_sequence = specialist_entry[1] - 1
		specialist_schedule_is_authored = (
			specialist_schedule_is_authored
			and prototype.wave_director._select_regular_role(
				PhaseBCombatDirector.EnemyRole.HUNTER
			) == specialist_entry[2]
		)
	_check(
		specialist_schedule_is_authored,
		"the wave schedule introduces all four specialist roles at authored cadences"
	)

	# Late specialists. The design note is explicit that a late enemy must not be an
	# early enemy with a bigger health bar, so each of these has to be reachable from
	# the schedule and has to behave differently once it arrives.
	var waves := prototype.wave_director
	waves.elapsed_seconds = waves.siege_corruptor_intro_seconds
	waves._spawn_pack_sequence = waves.corruptor_pack_cycle - 1
	waves._variant_sequence = maxi(2, int(round(1.0 / waves.siege_corruptor_share))) - 1
	var siege_scheduled := waves._select_regular_role(
		PhaseBCombatDirector.EnemyRole.HUNTER
	) == PhaseBCombatDirector.EnemyRole.SIEGE_CORRUPTOR
	_check(
		siege_scheduled
		and waves.heavy_grazer_intro_seconds > waves.saboteur_intro_seconds
		and waves.rusher_intro_seconds > waves.saboteur_intro_seconds,
		"the late specialists are scheduled, and only after the early roles"
	)

	# The Heavy Grazer's rule change is that Bramble's shove stops answering it. Its
	# slow deliberately still does: one number governing both would make it immune to
	# Bramble rather than immune to being moved.
	prototype.combat.reset_combat()
	var heavy_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HEAVY_GRAZER
	)
	var heavy := prototype.combat._enemies[0]
	for candidate in prototype.combat._enemies:
		if candidate.active and candidate.id == heavy_id:
			heavy = candidate
	var heavy_start := heavy.position
	prototype.combat._begin_knockback(heavy, Vector2.RIGHT, 60.0)
	var heavy_shove := heavy.knockback_speed
	prototype.combat.reset_combat()
	var light_id := prototype.combat.spawn_enemy(PhaseBCombatDirector.EnemyRole.GRAZER)
	var light := prototype.combat._enemies[0]
	for candidate in prototype.combat._enemies:
		if candidate.active and candidate.id == light_id:
			light = candidate
	prototype.combat._begin_knockback(light, Vector2.RIGHT, 60.0)
	_check(
		heavy_start.x >= 0.0
		and heavy_shove < light.knockback_speed * 0.2
		and prototype.combat.heavy_grazer_profile.knockback_resistance > 0.5
		and is_equal_approx(prototype.combat.heavy_grazer_profile.territory_action_escalation, 1.0),
		"a Heavy Grazer shrugs off the shove that moves an ordinary Grazer "
			+ "(%.1f against %.1f)" % [heavy_shove, light.knockback_speed]
	)

	# The Siege Corruptor's rule change is that ignoring it is what makes it bad. Its
	# conversion compounds while it is left alone and is reset by being hit, so the
	# condition is genuinely "if ignored" rather than a timer.
	prototype.combat.reset_combat()
	var siege_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.SIEGE_CORRUPTOR
	)
	var siege := prototype.combat._enemies[0]
	for candidate in prototype.combat._enemies:
		if candidate.active and candidate.id == siege_id:
			siege = candidate
	for _siege_action in range(6):
		prototype.combat._perform_enemy_territory_action(siege)
	var escalated := siege.territory_escalation
	prototype.combat._damage_enemy(
		siege,
		1.0,
		PhaseBCombatDirector.DeathSource.THORNSHOT,
		0
	)
	_check(
		escalated > 1.5
		and escalated <= prototype.combat.siege_corruptor_profile.territory_action_escalation_cap
		and is_equal_approx(siege.territory_escalation, 1.0),
		"an ignored Siege Corruptor compounds its conversion and one hit resets it "
			+ "(reached %.2fx)" % escalated
	)

	# Elite modifiers. Each one has to change a rule rather than a number, and the
	# roll has to be gated until the run has a build worth changing the rules of.
	prototype.combat.reset_combat()
	prototype.combat.set_elite_modifier_pressure(0.0)
	var unmodified := prototype.combat._roll_elite_modifier(
		PhaseBCombatDirector.EnemyRole.ELITE
	)
	# Read at the final invasion, which is where the escalation curve tops out.
	waves.elapsed_seconds = waves.final_invasion_time_seconds
	prototype.combat.set_elite_modifier_pressure(waves.get_escalation_progress())
	var modified_rolls := 0
	for _roll in range(40):
		if prototype.combat._roll_elite_modifier(
			PhaseBCombatDirector.EnemyRole.ELITE
		) != PhaseBCombatDirector.EliteModifier.NONE:
			modified_rolls += 1
	var hunter_never_modified := prototype.combat._roll_elite_modifier(
		PhaseBCombatDirector.EnemyRole.HUNTER
	) == PhaseBCombatDirector.EliteModifier.NONE
	_check(
		unmodified == PhaseBCombatDirector.EliteModifier.NONE
		and modified_rolls > 20
		and hunter_never_modified
		and is_equal_approx(waves.get_escalation_progress(), 1.0),
		"rule changes are gated behind the run's escalation and never reach the "
			+ "body of a pack (%d of 40 late rolls)" % modified_rolls
	)

	# Unstoppable: cannot be held, can still be slowed.
	prototype.combat.reset_combat()
	prototype.combat.debug_force_elite_modifier(
		PhaseBCombatDirector.EliteModifier.UNSTOPPABLE
	)
	var unstoppable_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.ELITE
	)
	var unstoppable := prototype.combat._enemies[0]
	for candidate in prototype.combat._enemies:
		if candidate.active and candidate.id == unstoppable_id:
			unstoppable = candidate
	unstoppable.bramble_root_remaining = 5.0
	unstoppable.movement_speed_multiplier = 0.4
	prototype.combat._advance_elite_modifier(unstoppable, 1.0 / 60.0)
	_check(
		unstoppable.elite_modifier == PhaseBCombatDirector.EliteModifier.UNSTOPPABLE
		and is_equal_approx(unstoppable.bramble_root_remaining, 0.0)
		and is_equal_approx(unstoppable.movement_speed_multiplier, 0.4),
		"an Unstoppable elite breaks a hold and stays slowed"
	)

	# Regenerative: heals, unless the protagonist is the one who hit it. Bramble is
	# deliberately not enough, which is what makes it a change to a build.
	prototype.combat.reset_combat()
	prototype.combat.debug_force_elite_modifier(
		PhaseBCombatDirector.EliteModifier.REGENERATIVE
	)
	var regen_id := prototype.combat.spawn_enemy(PhaseBCombatDirector.EnemyRole.ELITE)
	var regen := prototype.combat._enemies[0]
	for candidate in prototype.combat._enemies:
		if candidate.active and candidate.id == regen_id:
			regen = candidate
	regen.health = regen.maximum_health * 0.5
	var regen_wounded := regen.health
	prototype.combat._advance_elite_modifier(regen, 0.5)
	var regen_healed := regen.health
	prototype.combat._damage_enemy(
		regen,
		1.0,
		PhaseBCombatDirector.DeathSource.THORNSHOT,
		0
	)
	var regen_after_shot := regen.health
	prototype.combat._advance_elite_modifier(regen, 0.5)
	var regen_blocked := is_equal_approx(regen.health, regen_after_shot)
	prototype.combat._damage_enemy(
		regen,
		1.0,
		PhaseBCombatDirector.DeathSource.BRAMBLE,
		0
	)
	regen.regeneration_block_remaining = 0.0
	prototype.combat._advance_elite_modifier(regen, 0.5)
	_check(
		regen_healed > regen_wounded
		and regen_blocked
		and regen.health > regen_after_shot - 1.0,
		"a Regenerative elite heals until the protagonist hits it"
	)

	# Volatile: the kill answers back, on the enemies nearby and on the ground.
	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	_grow_test_ecosystem(prototype)
	prototype.combat.debug_force_elite_modifier(
		PhaseBCombatDirector.EliteModifier.VOLATILE
	)
	var volatile_id := prototype.combat.spawn_enemy(PhaseBCombatDirector.EnemyRole.ELITE)
	var volatile := prototype.combat._enemies[0]
	for candidate in prototype.combat._enemies:
		if candidate.active and candidate.id == volatile_id:
			volatile = candidate
	var bystander_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.HUNTER,
		volatile.position + Vector2(10.0, 0.0)
	)
	var bystander := prototype.combat._enemies[0]
	for candidate in prototype.combat._enemies:
		if candidate.active and candidate.id == bystander_id:
			bystander = candidate
	var bystander_health := bystander.health
	var detonations: Array = []
	prototype.combat.elite_detonated.connect(
		func(_position: Vector2, _radius: float) -> void:
			detonations.append(true)
	)
	prototype.combat._damage_enemy(
		volatile,
		volatile.health + 1.0,
		PhaseBCombatDirector.DeathSource.THORNSHOT,
		0
	)
	_check(
		detonations.size() == 1
		and bystander.health < bystander_health,
		"a Volatile elite detonates on death and damages what is standing near it"
	)
	prototype.combat.reset_combat()
	prototype.wave_director.elapsed_seconds = prototype.wave_director.final_invasion_time_seconds
	prototype.debug_advance_time(
		prototype.wave_director.cleanup_time_seconds
		- prototype.wave_director.final_invasion_time_seconds
	)
	_check(
		prototype.wave_director.cleanup_started,
		"the timeline enters its cleanup phase"
	)
	# Leave a hostile standing as the clock runs out: the timeline ending must not
	# hand the player a win while anything is still alive.
	prototype.combat.spawn_enemy(PhaseBCombatDirector.EnemyRole.HUNTER)
	prototype.advance_run(
		prototype.wave_director.run_duration_seconds
		- prototype.wave_director.cleanup_time_seconds
	)
	var survivors_at_time_out := prototype.combat.get_active_enemy_count()
	# The HUD refreshes on its own cadence, which is not what this check is about.
	prototype._update_hud()
	_check(
		prototype.wave_director.is_complete()
		and survivors_at_time_out > 0
		and prototype.get_run_state() == PhaseBPrototype.RunState.RUNNING
		and prototype.clock_label.text.contains("CLEAR THE FIELD"),
		"the clock running out leaves the run going while hostiles are still standing"
	)
	prototype.combat.debug_kill_all()
	# The killing blow can hand the player a level, and a pending draft holds the
	# run open until it is taken; victory lands on the far side of that choice.
	for _final_frame in range(8):
		if prototype.choice_panel.visible:
			prototype._choose_displayed_option(0)
		prototype.advance_run(1.0 / 60.0)
		if prototype.get_run_state() != PhaseBPrototype.RunState.RUNNING:
			break
	_check(
		prototype.combat.get_active_enemy_count() == 0
		and prototype.get_run_state() == PhaseBPrototype.RunState.VICTORY,
		"clearing the last hostiles after the timeline ends produces victory"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.apply_damage(prototype.player.get_max_health() * 2.0)
	_check(
		prototype.get_run_state() == PhaseBPrototype.RunState.DEFEAT,
		"losing all player HP ends the run immediately"
	)

	prototype.queue_free()
	await process_frame
	if _failures == 0:
		print("PHASE_B_PROTOTYPE_SMOKE: PASS")
		quit(0)
	else:
		push_error("PHASE_B_PROTOTYPE_SMOKE: %d failure(s)" % _failures)
		quit(1)


func _find_open_ground_position(prototype: PhaseBPrototype) -> Vector2:
	var field := prototype.territory_field
	var width := field.tuning.field_size.x
	for y in range(3, field.tuning.field_size.y - 3):
		for x in range(3, width - 3):
			var index := y * width + x
			if field._claimable_mask[index] == 0:
				continue
			if field._control[index] <= field.tuning.ownership_threshold:
				return field.cell_to_local(Vector2(x, y))
	return Vector2(-1.0, -1.0)


func _thorn_all_owned_ground(prototype: PhaseBPrototype) -> void:
	# Thorns on every owned cell, not only the frontier, so a cycle that eats the
	# interior still tears some out and Deadfall has something to convert.
	var field := prototype.territory_field
	for index in range(field._bramble_development.size()):
		if field._control[index] > field.tuning.ownership_threshold:
			field._bramble_development[index] = 1.0


func _grow_test_ecosystem(prototype: PhaseBPrototype) -> void:
	# A territory big enough to prune, since the starting foothold sits under the
	# safety floor by design.
	var arena := prototype.territory_field.tuning.arena_size
	for grow_index in range(14):
		var grow_spot := Vector2(
			arena.x * (0.18 + 0.06 * float(grow_index % 7)),
			arena.y * (0.30 + 0.30 * float(grow_index / 7))
		)
		prototype.territory_field.queue_seed_growth(grow_spot, 4.0, 0.0, 1.0, 3.0)
	prototype.territory_field._apply_pending_commands()
	_step_field(prototype.territory_field, 40)


func _graze_owned_ground(
	prototype: PhaseBPrototype,
	home: Vector2,
	angle: float
) -> void:
	# Pruning's harvest eats the ground under the player, so a fixture that stands
	# still burns its own footing out. Grazing is what a run actually does to keep a
	# ring turning, and it is what the fixture has to do too.
	var graze := home + Vector2.from_angle(angle) * 46.0
	if prototype.territory_field.get_control_at_local(graze) > (
		prototype.territory_field.tuning.ownership_threshold
	):
		prototype.player.global_position = prototype.territory_field.to_global(graze)


func _stand_on_owned_ground(prototype: PhaseBPrototype) -> Vector2:
	# The harvest happens under the player, so a Pruning check has to put the player
	# on their own ground first. In a run that is the whole input to the path.
	var spot := _find_owned_cell_position(prototype)
	prototype.player.global_position = prototype.territory_field.to_global(spot)
	return spot


func _find_owned_cell_position(prototype: PhaseBPrototype) -> Vector2:
	var field := prototype.territory_field
	var width := field.tuning.field_size.x
	for y in range(3, field.tuning.field_size.y - 3):
		for x in range(3, width - 3):
			if field._control[y * width + x] > 0.5:
				return field.cell_to_local(Vector2(x, y))
	return Vector2(-1.0, -1.0)


func _restore_green_in_radius(
	field: TerritoryField,
	local_position: Vector2,
	radius_pixels: float
) -> void:
	# Write the ground back rather than waiting on the field to reclaim it, so a
	# check about territory does not also depend on how fast Green happens to
	# spread that day.
	var cell := field.local_to_cell(local_position)
	var width := int(field.tuning.field_size.x)
	var height := int(field.tuning.field_size.y)
	var radius_cells := radius_pixels / (field.tuning.arena_size.x / float(width))
	for y in range(height):
		for x in range(width):
			if Vector2(float(x), float(y)).distance_to(cell) > radius_cells:
				continue
			var index := y * width + x
			if field._claimable_mask[index] == 0:
				continue
			field._control[index] = 1.0
	field.recalculate_metrics_now()


func _step_field(field: TerritoryField, count: int) -> void:
	for _index in range(count):
		field.step_simulation()
	field.recalculate_metrics_now()



func _paint_lane(field: TerritoryField, origin: Vector2, control: float) -> void:
	# A wide corridor of one owner, so a thrown glob crosses nothing else.
	var width := int(field.tuning.field_size.x)
	var height := int(field.tuning.field_size.y)
	var cell := field.local_to_cell(origin)
	for y in range(height):
		for x in range(width):
			if absf(float(y) - cell.y) > 6.0:
				continue
			if float(x) < cell.x - 2.0 or float(x) > cell.x + 40.0:
				continue
			var index := y * width + x
			if field._claimable_mask[index] == 0:
				continue
			field._control[index] = control


func _throw_one_glob(bloom: PhaseBBloomDirector, origin: Vector2) -> float:
	# One glob, thrown along the lane, flown until it lands. The answer is how far
	# it actually got.
	for glob in bloom._globs:
		glob.active = false
	bloom._launch_glob(origin, Vector2.RIGHT, bloom.glob_launch_speed, 4.0, 2.0, 1.0, 0)
	var travelled := 0.0
	for _step in range(240):
		bloom.advance(1.0 / 60.0)
		if bloom.get_active_glob_count() == 0:
			break
	for glob in bloom._globs:
		travelled = maxf(travelled, glob.travelled)
	return travelled

func _find_player_frontier(field: TerritoryField) -> Vector2:
	# Return the centre of a real frontier cell so callers that convert the
	# position back into a cell index land on the cell they were shown.
	var cells := _find_player_frontier_cells(field, 1)
	if cells[0].x < 0:
		return Vector2(-1.0, -1.0)
	return field.cell_to_local(Vector2(cells[0]))


func _take_offered_upgrade(prototype: PhaseBPrototype, upgrade_id: int) -> void:
	prototype.progression._upgrade_offer_cursor = upgrade_id
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var options := prototype.progression.get_pending_upgrade_options()
	prototype._choose_displayed_option(maxi(0, options.find(upgrade_id)))


func _spawn_bramble_contact_enemy(
	prototype: PhaseBPrototype,
	role: int,
	local_position: Vector2
) -> PhaseBCombatDirector.EnemyState:
	var enemy_id := prototype.combat.spawn_enemy(role, local_position)
	for enemy in prototype.combat._enemies:
		if enemy.id == enemy_id:
			enemy.position = local_position
			return enemy
	return null


func _maximum_frontier_development(field: TerritoryField) -> float:
	var maximum := 0.0
	for index in range(field._bramble_development.size()):
		if field._player_frontier_mask[index] == 0:
			continue
		maximum = maxf(maximum, field._bramble_development[index])
	return maximum


func _find_distant_frontier_index(
	field: TerritoryField,
	local_position: Vector2,
	minimum_distance: float
) -> int:
	var width := field.tuning.field_size.x
	for y in range(2, field.tuning.field_size.y - 2):
		for x in range(2, width - 2):
			var index := y * width + x
			if field._player_frontier_mask[index] == 0:
				continue
			if field._bramble_development[index] <= 0.0:
				continue
			if field.cell_to_local(Vector2(x, y)).distance_to(local_position) < minimum_distance:
				continue
			return index
	return -1


func _find_deep_owned_position(field: TerritoryField) -> Vector2:
	var index := _find_deep_owned_cell(field, 12.0)
	if index < 0:
		return Vector2(-1.0, -1.0)
	var width := field.tuning.field_size.x
	return field.cell_to_local(Vector2(index % width, index / width))


func _find_deep_owned_cell(field: TerritoryField, band_pixels: float) -> int:
	# Owned ground far enough from any border that the frontier hedge cannot reach
	# it, so an interior-only effect can be measured on its own.
	var width := field.tuning.field_size.x
	for y in range(3, field.tuning.field_size.y - 3):
		for x in range(3, width - 3):
			var index := y * width + x
			if (
				field._player_frontier_mask[index] != 0
				or field._control[index] <= field.tuning.ownership_threshold
			):
				continue
			if field.is_player_frontier_at_local(
				field.cell_to_local(Vector2(x, y)),
				band_pixels
			):
				continue
			return index
	return -1


func _find_owned_cell_behind_frontier(field: TerritoryField) -> int:
	var width := field.tuning.field_size.x
	for y in range(2, field.tuning.field_size.y - 2):
		for x in range(2, width - 2):
			var index := y * width + x
			if (
				field._player_frontier_mask[index] != 0
				or field._control[index] <= field.tuning.ownership_threshold
			):
				continue
			var touches_frontier := (
				field._player_frontier_mask[index - 1] != 0
				or field._player_frontier_mask[index + 1] != 0
				or field._player_frontier_mask[index - width] != 0
				or field._player_frontier_mask[index + width] != 0
			)
			if touches_frontier:
				return index
	return -1


func _find_player_frontier_cells(field: TerritoryField, wanted: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var width := field.tuning.field_size.x
	for y in range(2, field.tuning.field_size.y - 2):
		for x in range(2, width - 2):
			if field._player_frontier_mask[y * width + x] == 0:
				continue
			found.append(Vector2i(x, y))
			if found.size() >= wanted:
				return found
	while found.size() < wanted:
		found.append(Vector2i(-1, -1))
	return found


func _minimum_frontier_development(field: TerritoryField) -> float:
	var minimum := 1.0
	for index in range(field._bramble_development.size()):
		if field._player_frontier_mask[index] == 0:
			continue
		minimum = minf(minimum, field._bramble_development[index])
	return minimum


func _find_green_unclaimable_cell(field: TerritoryField) -> Vector2i:
	var width := field.tuning.field_size.x
	var height := field.tuning.field_size.y
	for y in range(2, height - 2):
		for x in range(2, width - 2):
			var index := y * width + x
			if (
				field._claimable_mask[index] == 0
				or field._control[index] <= field.tuning.ownership_threshold
			):
				continue
			var touches_rock := (
				field._claimable_mask[index - 1] == 0
				or field._claimable_mask[index + 1] == 0
				or field._claimable_mask[index - width] == 0
				or field._claimable_mask[index + width] == 0
			)
			if touches_rock and not field._is_player_frontier_cell(x, y):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		push_error("FAIL: %s" % description)
