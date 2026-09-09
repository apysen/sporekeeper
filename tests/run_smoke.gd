extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_error := change_scene_to_file("res://scenes/run/run.tscn")
	_check(load_error == OK, "Sporekeeper scene resource loads")
	if load_error != OK:
		quit(1)
		return
	await process_frame
	await process_frame

	var prototype := current_scene as RunRoot
	_check(prototype != null, "Sporekeeper scene becomes the current prototype")
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
		"Sporekeeper gameplay systems and all enemy profiles are authored as visible scene nodes"
	)
	# Texture-backed Button styles are presented by real NinePatchRect children.
	# The Button keeps ownership of input and text, while only each border's center
	# edge strips stretch. Every raster botanical painting shares the deliberately strong
	# watercolor material rather than relying on per-asset treatment.
	var ui_buttons := prototype.find_children("*", "Button", true, false)
	var button_borders_are_sliced := not ui_buttons.is_empty()
	for button_node in ui_buttons:
		var button := button_node as Button
		var border := button.get_node_or_null("NinePatchBorder") as NinePatchRect
		button_borders_are_sliced = (
			button_borders_are_sliced
			and border != null
			and border.axis_stretch_horizontal == NinePatchRect.AXIS_STRETCH_MODE_STRETCH
			and border.axis_stretch_vertical == NinePatchRect.AXIS_STRETCH_MODE_STRETCH
			and border.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		)
	var botanical_material := prototype.overlay.material as ShaderMaterial
	var fruit_material := prototype.adaptation_director.material as ShaderMaterial
	var fruit_art_loaded := AdaptationDirector.FRUIT_TEXTURES.size() == 6
	for fruit_texture in AdaptationDirector.FRUIT_TEXTURES:
		fruit_art_loaded = fruit_art_loaded and fruit_texture != null
	_check(
		button_borders_are_sliced,
		"every run Button owns a correctly sliced NinePatchRect border"
	)
	_check(
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
		CombatDirector.EnemyRole.HUNTER
	)
	_check(
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
	_check(
		is_equal_approx(prototype.combat.grazer_profile.territory_action_strength, 1.0)
		and is_equal_approx(prototype.combat.boss_profile.territory_action_strength, 2.60),
		"Grazer and Burrower retain their authored territory pressure"
	)
	_check(
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
	_check(
		is_equal_approx(prototype.player.green_healing_per_second, 1.0),
		"established Green restores one health per second"
	)
	var contact_roles := PackedInt32Array([
		CombatDirector.EnemyRole.HUNTER,
		CombatDirector.EnemyRole.GRAZER,
		CombatDirector.EnemyRole.SABOTEUR,
		CombatDirector.EnemyRole.CORRUPTOR,
		CombatDirector.EnemyRole.COLONIZER,
		CombatDirector.EnemyRole.WARDEN,
		CombatDirector.EnemyRole.COLONY_CORE,
		CombatDirector.EnemyRole.ELITE,
		CombatDirector.EnemyRole.BOSS,
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
		and prototype.wave_label.text == (
			"WAVE 1 / %d" % prototype.get_final_wave_number()
		),
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
	# The arena is empty here, and an empty arena is the case the grace no longer
	# waits out: clearing a wave is what asks for the next one. That the grace still
	# runs in full while an enemy is alive is asserted in wave_cadence_probe, which
	# owns its own fixture rather than inheriting this one.
	_check(
		prototype.get_current_wave_number() == 2
		and prototype.combat.get_active_enemy_count() == 0
		and not prototype.is_wave_grace_period_active()
		and is_zero_approx(prototype.get_wave_grace_remaining_seconds()),
		"a cleared arena ends the wave grace instead of holding the next wave back"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype._set_simulation_paused(true)
	var wave_one_hunter_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER
	)
	var wave_one_grazer_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.GRAZER
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
		CombatDirector.EnemyRole.HUNTER
	)
	var wave_two_grazer_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.GRAZER
	)
	var wave_two_boss_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.BOSS
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
		CombatDirector.EnemyRole.HUNTER
	)
	var wave_three_grazer_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.GRAZER
	)
	var wave_three_boss_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.BOSS
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
	# A run opens on the Adaptation chooser, and a modal choice is not something
	# Escape may pause over. Answer it first, then the pause menu is reachable.
	_seed_run_adaptations(
		prototype,
		Progression.PathId.SPORE,
		Progression.PathId.ROOT
	)
	var pause_elapsed_before := prototype.get_elapsed_seconds()
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	prototype._unhandled_input(escape_event)
	prototype._process(1.0)
	_check(
		prototype.is_pause_menu_open()
		and prototype.pause_menu.visible
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
	var ambient_music_stream := prototype.run_audio.ambient_music.stream as AudioStreamWAV
	_check(
		ambient_music_stream != null
		and ambient_music_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
		and ambient_music_stream.loop_begin == 0
		and ambient_music_stream.loop_end
		== roundi(ambient_music_stream.get_length() * ambient_music_stream.mix_rate),
		"the forest theme loops across its complete sample range"
	)
	_check(
		prototype.run_audio.ambient_music.autoplay
		and prototype.run_audio.ambient_music == prototype.get_node("RunAudio/AmbientMusic")
		and prototype.run_audio.ambient_music.playing
		and prototype.run_audio.ambient_music.bus == prototype.audio_settings.music_bus_name,
		"the scene-authored forest theme is already playing on the Music bus"
	)
	await create_timer(0.25).timeout
	_check(
		prototype.run_audio.ambient_music.playing
		and prototype.run_audio.ambient_music.get_playback_position() > 0.05,
		"forest music remains active and advances beyond its opening instant"
	)
	prototype.pause_menu.volume_slider.value = 100.0
	_check(
		not AudioServer.is_bus_mute(sfx_bus_index)
		and is_equal_approx(
			db_to_linear(AudioServer.get_bus_volume_db(sfx_bus_index)),
			prototype.audio_settings.sfx_max_linear_volume
		)
		and prototype.pause_menu.volume_value.text == "100%",
		"displayed SFX volume 100% is capped at 20% linear output"
	)
	prototype.pause_menu.volume_slider.value = 37.0
	_check(
		not AudioServer.is_bus_mute(sfx_bus_index)
		and is_equal_approx(
			db_to_linear(AudioServer.get_bus_volume_db(sfx_bus_index)),
			0.37 * prototype.audio_settings.sfx_max_linear_volume
		)
		and prototype.pause_menu.volume_value.text == "37%",
		"the pause-menu slider scales the capped SFX bus immediately"
	)
	prototype.pause_menu.volume_slider.value = 0.0
	_check(
		AudioServer.is_bus_mute(sfx_bus_index)
		and prototype.pause_menu.volume_value.text == "0%",
		"setting pause-menu volume to zero mutes the SFX bus"
	)
	AudioServer.set_bus_volume_db(sfx_bus_index, original_sfx_volume_db)
	AudioServer.set_bus_mute(sfx_bus_index, original_sfx_mute)
	prototype.pause_menu.volume_slider.set_value_no_signal(
		0.0
		if original_sfx_mute
		else clampf(
			db_to_linear(original_sfx_volume_db)
			/ prototype.audio_settings.sfx_max_linear_volume,
			0.0,
			1.0
		) * 100.0
	)
	prototype.pause_menu._update_volume_label()
	prototype.pause_menu.music_volume_slider.value = 100.0
	_check(
		not AudioServer.is_bus_mute(music_bus_index)
		and is_equal_approx(
			db_to_linear(AudioServer.get_bus_volume_db(music_bus_index)),
			prototype.audio_settings.music_max_linear_volume
		)
		and prototype.pause_menu.music_volume_value.text == "100%",
		"displayed Music volume 100% is capped at 20% linear output"
	)
	var sfx_mute_before_music_change := AudioServer.is_bus_mute(sfx_bus_index)
	var sfx_volume_before_music_change := AudioServer.get_bus_volume_db(sfx_bus_index)
	prototype.pause_menu.music_volume_slider.value = 43.0
	_check(
		not AudioServer.is_bus_mute(music_bus_index)
		and is_equal_approx(
			db_to_linear(AudioServer.get_bus_volume_db(music_bus_index)),
			0.43 * prototype.audio_settings.music_max_linear_volume
		)
		and prototype.pause_menu.music_volume_value.text == "43%"
		and AudioServer.is_bus_mute(sfx_bus_index) == sfx_mute_before_music_change
		and is_equal_approx(
			AudioServer.get_bus_volume_db(sfx_bus_index),
			sfx_volume_before_music_change
		),
		"the pause-menu Music slider scales independently from SFX"
	)
	prototype.pause_menu.music_volume_slider.value = 0.0
	_check(
		AudioServer.is_bus_mute(music_bus_index)
		and prototype.pause_menu.music_volume_value.text == "0%",
		"setting pause-menu Music volume to zero mutes only the Music bus"
	)
	AudioServer.set_bus_volume_db(music_bus_index, original_music_volume_db)
	AudioServer.set_bus_mute(music_bus_index, original_music_mute)
	prototype.pause_menu.music_volume_slider.set_value_no_signal(
		0.0
		if original_music_mute
		else clampf(
			db_to_linear(original_music_volume_db)
			/ prototype.audio_settings.music_max_linear_volume,
			0.0,
			1.0
		) * 100.0
	)
	prototype.pause_menu._update_music_volume_label()
	prototype.pause_menu.resume_button.pressed.emit()
	_check(
		not prototype.is_pause_menu_open()
		and not prototype.pause_menu.visible
		and not prototype.combat.simulation_paused,
		"Resume closes the pause overlay and restores gameplay simulation"
	)
	prototype.debug_advance_time(12.0)
	prototype._open_pause_menu()
	prototype.pause_menu.glossary_button.pressed.emit()
	_check(
		prototype._mechanics_help.is_glossary_open()
		and prototype.is_pause_menu_open()
		and prototype.pause_menu.visible,
		"Glossary opens from the pause menu without resuming simulation"
	)
	prototype._close_glossary()
	_check(
		prototype.pause_menu.fullscreen_button.pressed.is_connected(
			Callable(prototype.pause_menu, "_toggle_fullscreen")
		)
		and prototype.pause_menu.quit_button.pressed.is_connected(
			Callable(prototype.pause_menu, "_request_quit")
		)
		# The menu only reports the request; the run root is what actually quits, so
		# the chain is only wired if both halves of it are.
		and prototype.pause_menu.quit_requested.is_connected(
			Callable(prototype, "_quit_from_pause_menu")
		),
		"fullscreen and desktop quit actions are wired to their pause-menu buttons"
	)
	prototype._set_simulation_paused(true)
	var hunter_position := prototype.player.get_arena_position() + Vector2(90.0, 0.0)
	var hunter_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
		hunter_position
	)
	# Cane's intentional 24-damage baseline now exactly kills the ordinary Hunter.
	# Give this pooled Hunter enough fixture health to observe a non-lethal flash
	# before the later automatic sweeps finish the kill being tested below.
	var feedback_hunter := prototype.combat._find_enemy(hunter_id)
	if feedback_hunter != null:
		feedback_hunter.maximum_health = prototype.combat.cane_damage * 3.0
		feedback_hunter.health = feedback_hunter.maximum_health
		feedback_hunter.speed = 0.0
	# Saved presentation settings belong to the player, not the test machine. This
	# feedback fixture explicitly asks for full numbers so an existing user setting
	# cannot turn the object under test off before the assertion observes it.
	prototype.display_settings.set_choice(
		DisplaySettings.OptionId.DAMAGE_NUMBERS,
		DisplaySettings.DamageNumbers.FULL
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
		"the automatic base Cane kills a Hunter inside its facing sector"
	)
	_check(
		prototype.combat.cane_swing_sfx != null
		and prototype.combat.get_cane_sfx_play_count() > 0
		and prototype.combat._cane_audio.bus == prototype.audio_settings.sfx_bus_name,
		"each automatic Cane sweep plays the authored swing SFX"
	)
	_check(
		observed_hit_flash and observed_damage_number,
		"Cane damage produces an enemy hit flash and a pooled floating number"
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
		+ Vector2(prototype.combat.cane_reach_pixels + 150.0, 0.0)
	)
	var outside_range_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
		outside_range_position
	)
	prototype.combat.simulate_step(0.20)
	_check(
		outside_range_id != -1
		and prototype.combat.is_enemy_active(outside_range_id)
		and prototype.combat.get_active_projectile_count() == 0,
		"Cane still sweeps without damaging an enemy beyond its authored reach"
	)

	prototype.combat.reset_combat()
	var cane_wall_source := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.475,
		prototype.territory_field.tuning.arena_size.y * 0.20
	)
	var cane_blocked_target := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.56,
		prototype.territory_field.tuning.arena_size.y * 0.20
	)
	var cane_visible_target := Vector2(
		cane_wall_source.x,
		prototype.territory_field.tuning.arena_size.y * 0.51
	)
	prototype.player.global_position = prototype.territory_field.to_global(cane_wall_source)
	var blocked_target_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
		cane_blocked_target
	)
	var visible_target_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
		cane_visible_target
	)
	var dense_visible_direction := prototype.combat.get_densest_target_direction(
		cane_wall_source,
		500.0,
		45.0,
		Vector2.RIGHT
	)
	_check(
		not prototype.territory_field.is_growth_path_clear(
			cane_wall_source,
			cane_blocked_target
		)
		and prototype.territory_field.is_growth_path_clear(
			cane_wall_source,
			cane_visible_target
		)
		and cane_wall_source.distance_to(cane_blocked_target)
		< cane_wall_source.distance_to(cane_visible_target)
		and absf(dense_visible_direction.angle_to(
			cane_wall_source.direction_to(cane_visible_target)
		)) < 0.001,
		"dense-sector targeting ignores a closer enemy behind basalt"
	)
	prototype.combat.perform_bonus_cane_sweep(Vector2.RIGHT, true)
	var visible_reach_scale := (
		cane_wall_source.distance_to(cane_visible_target)
		/ prototype.combat.get_cane_reach()
		+ 0.1
	)
	prototype.combat.perform_bonus_cane_sweep(
		cane_wall_source.direction_to(cane_visible_target),
		false,
		1.0,
		visible_reach_scale
	)
	_check(
		prototype.combat.get_enemy_health(visible_target_id)
		< prototype.combat.hunter_profile.maximum_health
		and is_equal_approx(
			prototype.combat.get_enemy_health(blocked_target_id),
			prototype.combat.hunter_profile.maximum_health
		),
		"Cane sectors damage an unobstructed enemy but never pass through basalt"
	)

	prototype.player.reset_player()
	prototype.combat.reset_combat()
	var sweep_origin := prototype.player.get_arena_position()
	var upper_enemy_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
		sweep_origin + Vector2(58.0, -18.0)
	)
	var lower_enemy_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
		sweep_origin + Vector2(68.0, 20.0)
	)
	var beyond_reach_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
		sweep_origin + Vector2(prototype.combat.cane_reach_pixels + 80.0, 0.0)
	)
	var sector_hits := prototype.combat.perform_bonus_cane_sweep(Vector2.RIGHT, true)
	_check(
		sector_hits == 2
		and prototype.combat.get_enemy_health(upper_enemy_id)
		< prototype.combat.hunter_profile.maximum_health
		and prototype.combat.get_enemy_health(lower_enemy_id)
		< prototype.combat.hunter_profile.maximum_health
		and is_equal_approx(
			prototype.combat.get_enemy_health(beyond_reach_id),
			prototype.combat.hunter_profile.maximum_health
		)
		and prototype.combat.get_active_projectile_count() == 0,
		"one Cane sector hits every in-reach enemy once and allocates no projectile"
	)

	prototype.combat.reset_combat()
	var navigation_target := Vector2(310.0, 70.0)
	var navigation_start := Vector2(650.0, 70.0)
	prototype.player.global_position = prototype.territory_field.to_global(navigation_target)
	prototype.combat._cane_remaining = 999.0
	var navigating_enemy_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
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
		CombatDirector.EnemyRole.SABOTEUR,
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
		CombatDirector.EnemyRole.CORRUPTOR,
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
		CombatDirector.EnemyRole.WARDEN,
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
		CombatDirector.EnemyRole.COLONIZER,
		Vector2(700.0, 360.0)
	)
	prototype.combat.simulate_step(0.0)
	prototype.combat.colonizer_profile.first_territory_action_delay_seconds = (
		original_colonizer_delay
	)
	_check(
		colonizer_id != -1
		and prototype.combat.get_active_enemy_count_by_role(
			CombatDirector.EnemyRole.COLONY_CORE
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
		CombatDirector.EnemyRole.COLONY_CORE,
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
			CombatDirector.EnemyRole.HUNTER,
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
		Progression.PathId.BLOOM,
		Progression.PathId.SPORE
	)
	prototype.overlay.clear_effects()
	prototype.combat.reset_combat()
	prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
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

	# A run opens on nothing but a Cane. The first upgrade arrives the way it always
	# has -- a few kills into wave one -- and taking a line is what enters its
	# Adaptation. No screen of bare Adaptations is ever presented.
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	_check(
		prototype._choice_kind == RunRoot.ChoiceKind.NONE
		and not prototype.choice_panel.visible
		and prototype.progression.get_owned_adaptation_count() == 0
		and not prototype.territory_field.simulation_paused,
		"a run begins playing immediately rather than on an Adaptation choice"
	)
	prototype.progression._upgrade_offer_cursor = (
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT
	)
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var pre_path_options := prototype.progression.get_pending_upgrade_options()
	var pre_path_lines: Array[int] = []
	var pre_path_paths: Array[int] = []
	for option_id in pre_path_options:
		if not pre_path_lines.has(option_id):
			pre_path_lines.append(option_id)
		var option_path := prototype.progression._get_upgrade_path(option_id)
		if not pre_path_paths.has(option_path):
			pre_path_paths.append(option_path)
	_check(
		prototype._choice_kind == RunRoot.ChoiceKind.UPGRADE
		and pre_path_options.size() == 3
		and pre_path_lines.size() == 3
		and pre_path_paths.size() >= 2,
		"the first level-up offers three distinct lines spread across the whole roster"
	)
	var committing_option := pre_path_options[0]
	var committing_path := prototype.progression._get_upgrade_path(committing_option)
	var committed_preview := prototype.progression.get_upgrade_committed_path(
		committing_option
	)
	prototype._choose_displayed_option(0)
	_check(
		committed_preview == committing_path
		and prototype.progression.primary_path == committing_path
		and prototype.progression.owns_adaptation(committing_path)
		and prototype.progression.get_owned_upgrade_level(committing_option) == 1,
		"taking a line commits its Adaptation as Core 1"
	)
	# Owning it opens all four of its lines at rank 0, capped at three.
	var owned_lines := prototype.progression.get_adaptation_line_ids(committing_path)
	var all_lines_open := owned_lines.size() == Progression.LINES_PER_ADAPTATION
	for line_id in owned_lines:
		all_lines_open = (
			all_lines_open
			and prototype.progression._is_upgrade_draftable(line_id)
			and prototype.progression.get_upgrade_maximum_level(line_id) == 3
		)
	_check(
		all_lines_open,
		"entering an Adaptation opens all four of its rank-3 lines at once"
	)
	# A second uncommitted line fills Core 2 and freezes the Evolution, with no
	# milestone and no timer involved.
	_take_offered_upgrade(prototype, Progression.UpgradeId.ROOT_MATURATION)
	_check(
		prototype.progression.secondary_path == Progression.PathId.ROOT
		and prototype.progression.get_pair_evolution_id() != Progression.EvolutionId.NONE
		and not prototype.progression.has_branch_slot_open(),
		"a second uncommitted line locks the Core pair, and no Branch slot exists yet"
	)
	# With both Cores committed and no Branch earned, drafts narrow to what is owned.
	var narrowed := prototype.progression.get_ordinary_candidate_lines()
	var narrowed_to_owned := not narrowed.is_empty()
	for option_id in narrowed:
		narrowed_to_owned = (
			narrowed_to_owned
			and prototype.progression.owns_adaptation(
				prototype.progression._get_upgrade_path(option_id)
			)
		)
	_check(
		narrowed_to_owned,
		"drafts narrow to the owned Adaptations once no slot is open"
	)
	# Running the clock out never offers an Adaptation: the room for a Branch is
	# earned from the Elite and the Boss, not from a timer.
	prototype.debug_advance_time(600.0)
	prototype.debug_advance_time(600.0)
	_check(
		prototype.progression.get_owned_adaptation_count() == 2
		and prototype.progression.unlocked_branch_slots == 0,
		"no elapsed-time milestone ever opens a Branch slot"
	)
	# Beating the Elite does, and what fills it is drafted like everything else.
	prototype.progression._pending_upgrade_options.clear()
	prototype.progression._pending_relic_options.clear()
	prototype._choice_kind = RunRoot.ChoiceKind.NONE
	prototype.choice_panel.visible = false
	prototype._on_elite_defeated()
	var branch_draft_offered := false
	var branch_draft_is_unowned := true
	if prototype.progression.is_pending_branch_upgrade_choice():
		branch_draft_offered = true
		for option_id in prototype.progression.get_pending_upgrade_options():
			branch_draft_is_unowned = (
				branch_draft_is_unowned
				and not prototype.progression.owns_adaptation(
					prototype.progression._get_upgrade_path(option_id)
				)
			)
	_check(
		prototype.progression.unlocked_branch_slots == 1
		and prototype.progression.has_branch_slot_open(),
		"defeating the Elite earns room for a third Adaptation"
	)
	_check(
		branch_draft_offered and branch_draft_is_unowned,
		"the Elite's Adaptation reward is a draft of unowned lines, never a Path screen"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	var authored_rerolls := prototype.progression.rerolls_per_run
	_seed_run_adaptations(
		prototype,
		Progression.PathId.SPORE,
		Progression.PathId.ROOT
	)
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
		and prototype.choice_panel.reroll_button.visible
		and prototype.choice_panel.reroll_button.text
			== "REROLL  (%d LEFT)" % (authored_rerolls - 1),
		"a reroll redraws the same draft for a different offer without spending a level"
	)

	# Restarting a run has to deal a different hand. This was the bug: the draft walked
	# a cursor that started at the top of the enum every run and took three evenly
	# spaced candidates, so every run opened on the same three lines and a reroll only
	# stepped that cursor along a fixed sequence.
	var pinned_seed := prototype.progression.authored_run_seed
	prototype.progression.authored_run_seed = 0
	var openings := {}
	var rolled_seeds := {}
	for _fresh_run in range(12):
		prototype.reset_run()
		rolled_seeds[prototype.progression.run_seed] = true
		_seed_run_adaptations(
			prototype,
			Progression.PathId.SPORE,
			Progression.PathId.ROOT
		)
		prototype.progression.add_xp(prototype.progression.get_required_xp())
		var opening := ""
		for option_id in prototype.progression.get_pending_upgrade_options():
			opening += "%d," % option_id
		openings[opening] = true
	# Replaying a seed has to reproduce the run exactly, or a reported run cannot be
	# looked at. The same pin, twice, has to deal the same hand.
	var replays := {}
	for _replay in range(3):
		prototype.reset_run()
		prototype.progression.set_run_seed(0x5EED1234)
		_seed_run_adaptations(
			prototype,
			Progression.PathId.SPORE,
			Progression.PathId.ROOT
		)
		prototype.progression.add_xp(prototype.progression.get_required_xp())
		var replayed := ""
		for option_id in prototype.progression.get_pending_upgrade_options():
			replayed += "%d," % option_id
		replays[replayed] = true
	_check(
		openings.size() >= 8
		and rolled_seeds.size() == 12
		and replays.size() == 1,
		"restarting deals a different hand, and a pinned seed replays one exactly "
			+ "(%d openings and %d seeds in 12 runs)" % [openings.size(), rolled_seeds.size()]
	)
	prototype.progression.authored_run_seed = pinned_seed
	prototype.reset_run()
	_seed_run_adaptations(
		prototype,
		Progression.PathId.SPORE,
		Progression.PathId.ROOT
	)
	prototype.progression.add_xp(prototype.progression.get_required_xp())


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
		and prototype.choice_panel.reroll_button.disabled
		and not prototype.progression.get_pending_upgrade_options().is_empty(),
		"a run spends exactly its authored rerolls and keeps its offer once they are gone"
	)
	prototype._choose_displayed_option(0)
	_check(
		not prototype.choice_panel.reroll_button.visible,
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
		Progression.UpgradeId.ROOT_MATURATION,
		Progression.UpgradeId.ROOT_LATERAL_ROOTS,
		Progression.UpgradeId.ROOT_MATURE_STRENGTH,
		Progression.UpgradeId.ROOT_POTENCY,
	])
	var root_lines_belong := true
	for line_id in root_lines:
		root_lines_belong = (
			root_lines_belong
			and prototype.progression._get_upgrade_path(line_id)
			== Progression.PathId.ROOT
		)
	_check(
		root_lines_belong and root_lines.size() == 4,
		"Root contributes its four GDD lines to the Plant roster"
	)

	prototype.progression.reset_progression()
	prototype.progression.offer_bramble_path = false
	var switched_off_offered := prototype.progression.get_acquirable_adaptations().has(
		Progression.PathId.BRAMBLE
	)
	var other_path_still_offered := prototype.progression.get_acquirable_adaptations().has(
		Progression.PathId.SPORE
	)
	prototype.progression.offer_bramble_path = true
	prototype.progression.reset_progression()
	_check(
		not switched_off_offered
		and other_path_still_offered
		and prototype.progression.get_acquirable_adaptations().has(
			Progression.PathId.BRAMBLE
		),
		"a path switched off in the inspector is never enterable"
	)
	# One Core committed and one slot still open: the unowned lines stay on the
	# table, because taking one is how the second Core is entered.
	prototype.progression.reset_progression()
	prototype.progression.acquire_adaptation(Progression.PathId.SPORE)
	var open_slot_keeps_unowned := prototype.progression._is_upgrade_draftable(
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT
	)
	# Both Cores committed and no Branch earned: nothing is open, so the draft
	# narrows to what the run holds.
	prototype.progression.acquire_adaptation(Progression.PathId.ROOT)
	_check(
		open_slot_keeps_unowned
		and prototype.progression._is_upgrade_draftable(
			Progression.UpgradeId.SEED_PRODUCTION
		)
		and not prototype.progression._is_upgrade_draftable(
			Progression.UpgradeId.BRAMBLE_ENTANGLEMENT
		),
		"unowned lines stay draftable while a slot is open and vanish once none is"
	)
	prototype.progression.reset_progression()
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false

	prototype.progression.debug_select_paths(
		Progression.PathId.ROOT,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	var root_base_maturation: float = prototype.territory_field.tuning.maturation_per_second
	var root_base_reach := prototype.root_director.get_lateral_reach()
	var root_base_resistance := prototype.territory_field.get_mature_resistance_multiplier()
	var root_base_network := prototype.root_director.get_network_bonus()
	for line_id in root_lines:
		prototype.progression._upgrade_levels[line_id] = 3
	prototype._apply_progression_modifiers()
	_check(
		prototype.territory_field.tuning.maturation_per_second > root_base_maturation
		and prototype.root_director.get_lateral_reach() > root_base_reach
		and prototype.territory_field.get_mature_resistance_multiplier()
		> root_base_resistance
		and prototype.territory_field.tuning.regeneration_per_second > 0.0
		and prototype.root_director.get_network_bonus() > root_base_network,
		"Root's lines raise maturation, Lateral reach, Mature Strength, and Root Potency"
	)
	_check(
		root_base_network > 0.0
		and prototype.root_director.get_network_bonus()
		> prototype.root_director.base_network_bonus,
		"Root Potency deepens the Root Network amplification Root already supplies"
	)

	# Lateral Roots: an established colony projects Root support into the younger
	# Green in front of it, and that support never crosses ground the run does not
	# hold. It also never makes the supported ground Mature.
	prototype.progression.debug_select_paths(
		Progression.PathId.ROOT,
		Progression.PathId.SPORE
	)
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.ROOT_LATERAL_ROOTS
	] = 5
	prototype._apply_progression_modifiers()
	var lateral_spot := _find_owned_cell_position(prototype)
	for _lateral_ripen in range(6):
		prototype.territory_field.queue_maturity_support(lateral_spot, 1.0, 4.0)
		prototype.territory_field.step_simulation()
	var lateral_reach := prototype.root_director.get_lateral_reach()
	var on_mature := prototype.territory_field.get_mature_projection_at(
		lateral_spot, lateral_reach
	)
	var raw_maturity := prototype.territory_field.get_maturity_at_local(lateral_spot)
	var projected := prototype.root_director.get_projected_maturity_at(
		lateral_spot, raw_maturity
	)
	# Off the board entirely there is no owned Green to carry support through.
	var unowned_projection := prototype.territory_field.get_mature_projection_at(
		Vector2(-500.0, -500.0), lateral_reach
	)
	_check(
		lateral_reach > 0.0
		and on_mature > 0.0
		and projected >= raw_maturity
		and is_equal_approx(unowned_projection, 0.0),
		"LATERAL ROOTS projects Root support through owned Green and never off it"
	)
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.ROOT_LATERAL_ROOTS
	] = 0
	prototype._apply_progression_modifiers()

	prototype.progression.debug_select_paths(
		Progression.PathId.ROOT,
		Progression.PathId.SPORE
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
		== Progression.EvolutionId.SEED_BANK,
		"Spore plus Root pairs into Seed Bank"
	)
	prototype.progression.debug_select_paths(
		Progression.PathId.BLOOM,
		Progression.PathId.ROOT
	)
	_check(
		prototype.progression.get_pair_evolution_id()
		== Progression.EvolutionId.FLOWERING_SEASON,
		"Bloom plus Root pairs into Flowering Season"
	)
	prototype.progression.debug_select_paths(
		Progression.PathId.BRAMBLE,
		Progression.PathId.ROOT
	)
	_check(
		prototype.progression.get_pair_evolution_id()
		== Progression.EvolutionId.OLD_GROWTH,
		"Bramble plus Root pairs into Old Growth"
	)

	prototype.progression.debug_select_paths(
		Progression.PathId.SPORE,
		Progression.PathId.ROOT
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
	# Claiming Seed Bank is itself a Season: the free wave lands at once rather than
	# waiting out the clock, which is the power spike the Evolution is sold on.
	prototype.spore_director._seed_bank_storage = 0.0
	prototype.spore_director.advance(0.016)
	var claim_season_seeds := prototype.overlay.get_active_seed_count()
	prototype.overlay.clear_effects()
	# From there the Season is a clock. Storage alone does not fire one; the interval
	# elapsing does, and it spends what the Bank had stored.
	prototype.spore_director._seed_bank_storage = (
		prototype.evolutions.germination_season_threshold
	)
	prototype.spore_director.advance(0.016)
	var seeds_before_interval := prototype.overlay.get_active_seed_count()
	prototype.spore_director.advance(
		prototype.evolutions.germination_season_interval
	)
	_check(
		seed_bank_granted
		and prototype.progression.active_evolution
		== Progression.EvolutionId.SEED_BANK
		and claim_season_seeds > 1
		and seeds_before_interval == 0
		and prototype.overlay.get_active_seed_count() > 1
		and prototype.spore_director.get_seed_bank_storage() < 1.0,
		"claiming Seed Bank fires a free Season, and later Seasons run on the clock"
	)
	prototype.overlay.clear_effects()

	prototype.progression.debug_select_paths(
		Progression.PathId.BLOOM,
		Progression.PathId.ROOT
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
		Progression.PathId.BRAMBLE,
		Progression.PathId.ROOT
	)
	prototype.progression.debug_complete_evolution_requirements()
	var old_growth_granted := prototype.progression.grant_evolution_if_ready()
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
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
		CombatDirector.EnemyRole.HUNTER,
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
	prototype.combat._cane_remaining = 999.0

	# Mature interior erupts once the enemy standing on it is heavily Entangled.
	prototype.territory_field._maturity[interior_index] = 1.0
	prototype.territory_field._territory_age[interior_index] = (
		prototype.territory_field.tuning.age_reference_seconds
	)
	var mature_enemy := _spawn_bramble_contact_enemy(
		prototype,
		CombatDirector.EnemyRole.HUNTER,
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
	prototype.combat._cane_remaining = 999.0
	var cascade_enemy: CombatDirector.EnemyState = _spawn_bramble_contact_enemy(
		prototype,
		CombatDirector.EnemyRole.HUNTER,
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
		Progression.UpgradeId.EVOLUTION_ANCIENT_FURY
	] = 3
	prototype._apply_progression_modifiers()
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	cascade_enemy = _spawn_bramble_contact_enemy(
		prototype,
		CombatDirector.EnemyRole.HUNTER,
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
		CombatDirector.EnemyRole.HUNTER,
		interior_spot
	)
	disabled_enemy.entanglement = 1.0
	var disabled_eruptions_before := prototype.combat.get_active_root_eruption_count()
	prototype.combat.simulate_step(0.0)
	_check(
		prototype.combat.get_active_root_eruption_count() == disabled_eruptions_before,
		"Mature ground never erupts for a run that has not evolved Old Growth"
	)

	# Four Adaptations, three ranks each, one Evolution from the Core pair alone.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.SPORE,
		Progression.PathId.ROOT
	)
	var ready_before_investment := prototype.progression.evolution_status
	# One mastered line in each Core is deliberately not enough.
	prototype.progression._upgrade_levels[Progression.UpgradeId.GROWTH_MASS] = 3
	prototype.progression._upgrade_levels[Progression.UpgradeId.ROOT_MATURATION] = 3
	prototype.progression._update_evolution_readiness()
	var ready_with_one_each := prototype.progression.evolution_status
	# Two in one Core and one in the other is not enough either.
	prototype.progression._upgrade_levels[Progression.UpgradeId.SPORULATION] = 3
	prototype.progression._update_evolution_readiness()
	var ready_with_lopsided := prototype.progression.evolution_status
	prototype.progression._upgrade_levels[Progression.UpgradeId.ROOT_POTENCY] = 3
	prototype.progression._update_evolution_readiness()
	_check(
		ready_before_investment == Progression.EvolutionStatus.NOT_READY
		and ready_with_one_each == Progression.EvolutionStatus.NOT_READY
		and ready_with_lopsided == Progression.EvolutionStatus.NOT_READY
		and prototype.progression.evolution_status == Progression.EvolutionStatus.READY,
		"Evolution needs two mastered lines in each Core, not one and not two in one"
	)
	prototype.progression.grant_evolution_if_ready()
	var claimed_evolution := prototype.progression.active_evolution
	var evolution_line := Evolutions.get_evolution_upgrade_id(claimed_evolution)
	_check(
		claimed_evolution == Progression.EvolutionId.SEED_BANK
		and prototype.progression.get_owned_upgrade_level(evolution_line) == 1
		and prototype.progression.get_upgrade_maximum_level(evolution_line) == 5
		and prototype.progression.get_upgrade_maximum_level(
			Progression.UpgradeId.GROWTH_MASS
		) == 3,
		"claiming Evolution grants rank 1 of a five-rank line while ordinary lines stop at three"
	)

	# Branches are complete Adaptations that never touch the Evolution. A Branch
	# cannot be entered before its milestone has opened room for it.
	var branch_before_milestone := prototype.progression.acquire_adaptation(
		Progression.PathId.BRAMBLE
	)
	prototype.progression.unlock_branch_slot()
	var branch_one := prototype.progression.acquire_adaptation(
		Progression.PathId.BRAMBLE
	)
	prototype.progression.unlock_branch_slot()
	var branch_two := prototype.progression.acquire_adaptation(
		Progression.PathId.THISTLE
	)
	var fifth_refused := not prototype.progression.acquire_adaptation(
		Progression.PathId.BLOOM
	)
	_check(
		not branch_before_milestone
		and branch_one
		and branch_two
		and fifth_refused
		and prototype.progression.get_owned_adaptation_count() == 4
		and prototype.progression.is_branch_adaptation(Progression.PathId.BRAMBLE)
		and not prototype.progression.is_evolution_path(Progression.PathId.BRAMBLE)
		and prototype.progression.get_pair_evolution_id() == claimed_evolution,
		"a Branch waits for its milestone, then completes the roster without re-rolling the Evolution"
	)
	# A mastered Branch line must not satisfy the Core gate either.
	for branch_line in prototype.progression.get_adaptation_line_ids(
		Progression.PathId.BRAMBLE
	):
		prototype.progression._upgrade_levels[branch_line] = 3
	_check(
		prototype.progression.is_adaptation_mastered(Progression.PathId.BRAMBLE)
		and prototype.progression.get_mastered_line_count(
			Progression.PathId.SPORE
		) == 2,
		"a mastered Branch counts toward its own mastery and never toward the Core gate"
	)

	# Every relic pool the roster owns, and only those.
	var eligible_pools := prototype.progression.get_eligible_relic_pool_ids()
	_check(
		eligible_pools.size() == 5
		and eligible_pools.has(RelicCatalog.Pool.PLANT)
		and eligible_pools.has(RelicCatalog.Pool.THISTLE)
		and not eligible_pools.has(RelicCatalog.Pool.BLOOM)
		and prototype.progression.get_relic_run_state()
		== RelicCatalog.RunState.FULL_ROSTER,
		"a full roster opens Plant plus four Adaptation relic pools and the deepest rarity table"
	)

	# Every ordinary offer is drawn from the unrestricted pool: no Adaptation holds a
	# guaranteed slot, and a mastered one drops out of the draw entirely.
	for thistle_line in prototype.progression.get_adaptation_line_ids(
		Progression.PathId.THISTLE
	):
		prototype.progression._upgrade_levels[thistle_line] = 3
	var mastered_offered := false
	for _screen in range(12):
		prototype.progression._pending_upgrade_options.clear()
		if not prototype.progression._roll_upgrade_options():
			continue
		for option_id in prototype.progression.get_pending_upgrade_options():
			if option_id < 0:
				continue
			if (
				prototype.progression._get_upgrade_path(option_id)
				== Progression.PathId.THISTLE
			):
				mastered_offered = true
	_check(
		not mastered_offered,
		"a mastered Adaptation stops appearing in ordinary offers"
	)

	# Base Cane follows facing; Vine deliberately replaces that input with the
	# targetable 90-degree sector holding the most enemies.
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	prototype.combat.reset_combat()
	prototype.player._facing = Vector2.RIGHT
	var cane_target_origin := prototype.player.get_arena_position()
	var base_right_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
		cane_target_origin + Vector2(62.0, 0.0)
	)
	var base_up_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
		cane_target_origin + Vector2(0.0, -62.0)
	)
	prototype.combat._cane_remaining = 0.0
	prototype.combat.simulate_step(0.0)
	var base_follows_facing := (
		prototype.combat.get_enemy_health(base_right_id)
		< prototype.combat.hunter_profile.maximum_health
		and is_equal_approx(
			prototype.combat.get_enemy_health(base_up_id),
			prototype.combat.hunter_profile.maximum_health
		)
	)
	prototype.combat.reset_combat()
	prototype.progression.debug_select_paths(
		Progression.PathId.VINE,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	var vine_down_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
		cane_target_origin + Vector2(0.0, 62.0)
	)
	var vine_cluster_ids := PackedInt32Array()
	for vine_index in range(3):
		vine_cluster_ids.append(prototype.combat.spawn_enemy(
			CombatDirector.EnemyRole.HUNTER,
			cane_target_origin + Vector2(-14.0 + 14.0 * float(vine_index), -66.0)
		))
	prototype.combat._cane_remaining = 0.0
	prototype.combat.simulate_step(0.0)
	# Vine resolves through its simulated body, so the stroke lands over its driving
	# window rather than on the frame it began.
	for _vine_sweep_frame in range(24):
		prototype.combat.simulate_step(1.0 / 60.0)
	var vine_cluster_hit := true
	for vine_enemy_id in vine_cluster_ids:
		vine_cluster_hit = (
			vine_cluster_hit
			and prototype.combat.get_enemy_health(vine_enemy_id)
			< prototype.combat.hunter_profile.maximum_health
		)
	_check(
		base_follows_facing
		and vine_cluster_hit
		and is_equal_approx(
			prototype.combat.get_enemy_health(vine_down_id),
			prototype.combat.hunter_profile.maximum_health
		)
		and absf(prototype.combat._cane_visual_facing.angle_to(Vector2.UP)) < 0.22
		and prototype.combat.get_active_projectile_count() == 0,
		"Vine auto-targets the densest valid sector while base Cane follows facing"
	)

	# Fruit uses the same dense-sector choice, but every member of a release owns its
	# roll, art choice, trail spacing, planted fuse, and post-burst cooldown state.
	var adaptations := prototype.adaptation_director
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.FRUIT,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	prototype.player.reset_player()
	prototype.combat.reset_combat()
	adaptations.reset_adaptations()
	var fruit_origin := prototype.player.get_arena_position()
	prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
		fruit_origin + Vector2(0.0, 92.0)
	)
	for fruit_cluster_index in range(3):
		prototype.combat.spawn_enemy(
			CombatDirector.EnemyRole.HUNTER,
			fruit_origin + Vector2(-14.0 + 14.0 * float(fruit_cluster_index), -92.0)
		)
	adaptations._begin_normal_fruit_release()
	var aimed_fruit = null
	for candidate in adaptations._fruits:
		if candidate.active and not candidate.dropped_seed:
			aimed_fruit = candidate
			break
	_check(
		aimed_fruit != null
		and is_equal_approx(aimed_fruit.speed, 300.0)
		and absf(aimed_fruit.velocity.normalized().angle_to(Vector2.UP)) < 0.22,
		"Fruit starts at 300 px/s toward the densest targetable enemy sector"
	)

	# Clear the shared origin stamps, then move three Fruits once in three directions.
	# A shared frame-level trail timer would produce only one branch here; independent
	# segment accumulators must leave a command on every branch.
	prototype.combat.reset_combat()
	adaptations.reset_adaptations()
	prototype.territory_field._commands.clear()
	var trail_fruits: Array = []
	for trail_direction in [Vector2.RIGHT, Vector2.UP, Vector2.LEFT]:
		var trail_fruit = adaptations._spawn_fruit(fruit_origin, trail_direction)
		if trail_fruit != null:
			trail_fruits.append(trail_fruit)
	prototype.territory_field._commands.clear()
	if not trail_fruits.is_empty():
		trail_fruits[0].remaining_distance = 0.0
	for trail_fruit in trail_fruits:
		adaptations._advance_fruit(trail_fruit, 0.12)
	var fruit_origin_cell := prototype.territory_field.local_to_cell(fruit_origin)
	var fruit_trail_right := false
	var fruit_trail_up := false
	var fruit_trail_left := false
	var fruit_trail_splats := 0
	for command in prototype.territory_field._commands:
		if command.kind != TerritoryField.TerritoryCommand.Kind.SPLAT:
			continue
		fruit_trail_splats += 1
		var cell_offset := command.cell_position - fruit_origin_cell
		fruit_trail_right = fruit_trail_right or cell_offset.x > 0.5
		fruit_trail_up = fruit_trail_up or cell_offset.y < -0.5
		fruit_trail_left = fruit_trail_left or cell_offset.x < -0.5
	var zero_distance_counter_did_not_stop: bool = (
		not trail_fruits.is_empty()
		and trail_fruits[0].active
		and trail_fruits[0].speed > 0.0
	)
	_check(
		trail_fruits.size() == 3
		and fruit_trail_splats >= 3
		and fruit_trail_right
		and fruit_trail_up
		and fruit_trail_left
		and zero_distance_counter_did_not_stop,
		"every Fruit paints its own rolling trail and only zero velocity can stop it"
	)

	# The art choice is run-seeded but genuinely varies per Fruit. Planted ordinary
	# Fruit retains that choice; only the relic offspring uses Fruitseed art.
	adaptations.reset_adaptations()
	adaptations._random.seed = 0xC0FFEE
	var fruit_art_indices := {}
	var fruit_art_indices_valid := true
	for art_roll_index in range(18):
		var art_fruit = adaptations._spawn_fruit(
			fruit_origin,
			Vector2.RIGHT.rotated(0.02 * float(art_roll_index))
		)
		if art_fruit == null:
			continue
		fruit_art_indices[art_fruit.visual_index] = true
		fruit_art_indices_valid = (
			fruit_art_indices_valid
			and art_fruit.visual_index >= 0
			and art_fruit.visual_index < AdaptationDirector.FRUIT_TEXTURES.size()
		)
	_check(
		fruit_art_indices_valid and fruit_art_indices.size() >= 3,
		"Fruit releases choose visibly varied paintings from the six-asset pool"
	)

	adaptations.reset_adaptations()
	prototype.combat.reset_combat()
	var terminal_position := fruit_origin + Vector2(48.0, 0.0)
	var terminal_enemy_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
		terminal_position
	)
	var terminal_health_before := prototype.combat.get_enemy_health(terminal_enemy_id)
	var terminal_fruit = adaptations._spawn_fruit(terminal_position, Vector2.RIGHT)
	var terminal_visual_index: int = (
		terminal_fruit.visual_index if terminal_fruit != null else -1
	)
	if terminal_fruit != null:
		terminal_fruit.speed = 0.0
		terminal_fruit.velocity = Vector2.ZERO
		adaptations._advance_fruit(terminal_fruit, 0.0)
	var planted_fruit = null
	for fruitseed in adaptations._fruitseeds:
		if fruitseed.active and not fruitseed.dropped_seed:
			planted_fruit = fruitseed
			break
	var terminal_keeps_fruit_art: bool = (
		planted_fruit != null
		and planted_fruit.visual_index == terminal_visual_index
		and is_equal_approx(planted_fruit.remaining, adaptations.fruitseed_germination_seconds)
	)
	prototype.territory_field._commands.clear()
	adaptations._update_fruitseeds(adaptations.fruitseed_germination_seconds + 0.01)
	var terminal_queued_green := false
	for command in prototype.territory_field._commands:
		terminal_queued_green = (
			terminal_queued_green
			or command.kind == TerritoryField.TerritoryCommand.Kind.SEED
		)
	_check(
		terminal_keeps_fruit_art
		and is_equal_approx(
			terminal_health_before - prototype.combat.get_enemy_health(terminal_enemy_id),
			adaptations.fruit_terminal_explosion_damage
		)
		and terminal_queued_green,
		"a stopped Fruit remains planted, then bursts for 10 damage and becomes territory"
	)

	adaptations.reset_adaptations()
	prototype.combat.reset_combat()
	adaptations._begin_normal_fruit_release()
	var first_release_count := adaptations._fruit_release_count
	# The clock starts at the launch. A Fruit still rolling, or still sitting on its
	# planted fuse, no longer holds the next release: that is what made Momentum a
	# cadence tax rather than a range upgrade.
	var cooldown_began_at_launch := is_equal_approx(
		adaptations._fruit_release_remaining,
		adaptations.fruit_release_interval
	)
	var cadence_fruit = null
	for candidate in adaptations._fruits:
		if candidate.active and not candidate.dropped_seed:
			cadence_fruit = candidate
			break
	if cadence_fruit != null:
		cadence_fruit.speed = 0.0
		cadence_fruit.velocity = Vector2.ZERO
		adaptations._advance_fruit(cadence_fruit, 0.0)
	adaptations._update_fruit_release_cadence(adaptations.fruit_release_interval - 0.01)
	var no_early_release := (
		adaptations._fruit_release_count == first_release_count
		and adaptations._has_live_normal_fruit_release()
	)
	adaptations._update_fruit_release_cadence(0.02)
	_check(
		cooldown_began_at_launch
		and no_early_release
		and adaptations._fruit_release_count == first_release_count + 1,
		"Fruit's release cooldown runs from the launch, not from the previous batch bursting"
	)

	# Weighted Harvest is the exception, because it stores its batch on the Vine tip
	# instead of putting it in the air, and a second arming would overwrite it.
	adaptations.reset_adaptations()
	prototype.combat.reset_combat()
	adaptations._gourdvine_pending_count = 3
	var gourdvine_release_count := adaptations._fruit_release_count
	adaptations._update_fruit_release_cadence(adaptations.fruit_release_interval * 3.0)
	var gourdvine_holds_release := (
		adaptations._fruit_release_count == gourdvine_release_count
	)
	adaptations._gourdvine_pending_count = 0
	adaptations._update_fruit_release_cadence(adaptations.fruit_release_interval + 0.01)
	_check(
		gourdvine_holds_release
		and adaptations._fruit_release_count == gourdvine_release_count + 1,
		"an armed Weighted Harvest holds the cadence until the sweep spends it"
	)
	adaptations.reset_adaptations()
	prototype.combat.reset_combat()

	# Every Evolution carries exactly one optional upgrade line, offered only to the
	# run that claimed that Evolution. Every pairing across the eight Paths has one;
	# the Pruning pairings used to fall through to no line at all, which left those
	# runs with nothing to draft and their Evolution stuck at its base effect.
	# The count is asserted against the enum rather than written down, so a pairing
	# added later cannot quietly ship without a line.
	var evolution_lines_are_paired := true
	var evolution_line_ids := PackedInt32Array()
	for evolution_id in range(1, Progression.EvolutionId.size()):
		var line_id := Evolutions.get_evolution_upgrade_id(evolution_id)
		if line_id < 0:
			continue
		evolution_lines_are_paired = (
			evolution_lines_are_paired
			and Evolutions.get_upgrade_evolution(line_id) == evolution_id
			and not evolution_line_ids.has(line_id)
		)
		evolution_line_ids.append(line_id)
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.BLOOM,
		Progression.PathId.BRAMBLE
	)
	var line_draftable_unevolved := prototype.progression._is_upgrade_draftable(
		Progression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD
	)
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	var claimed_evolution_line_level := prototype.progression.get_owned_upgrade_level(
		Progression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD
	)
	var own_line_draftable := prototype.progression._is_upgrade_draftable(
		Progression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD
	)
	var other_line_draftable := prototype.progression._is_upgrade_draftable(
		Progression.UpgradeId.EVOLUTION_ANCIENT_FURY
	)
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD
	] = 2
	var rank_level := prototype.progression.get_evolution_upgrade_level()
	var rank_three_text := prototype.progression.get_upgrade_description(
		Progression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD
	)
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	_check(
		evolution_lines_are_paired
		and evolution_line_ids.size() == Progression.EvolutionId.size() - 1
		and not line_draftable_unevolved
		and claimed_evolution_line_level == 1
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
	for evolution_id in range(1, Progression.EvolutionId.size()):
		var line_id := Evolutions.get_evolution_upgrade_id(evolution_id)
		if line_id < 0:
			continue
		for rank in range(1, prototype.progression.maximum_upgrade_level + 1):
			if prototype.evolutions.get_evolution_upgrade_rank_description(
				line_id, rank
			).is_empty():
				blank_ranks.append("%s r%d" % [
					Progression.get_upgrade_name(line_id),
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
		CombatDirector.EnemyRole.HUNTER,
		burst_seat + Vector2(18.0, 0.0)
	)
	var burst_full := prototype.combat.get_enemy_health(burst_id)
	prototype.spore_director.on_seed_germinated(burst_seat, 0)
	var burst_unrelicked := prototype.combat.get_enemy_health(burst_id)
	prototype.progression._owned_relics[RelicCatalog.Id.SPORE_BURST] = 1
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
		Progression.PathId.BLOOM,
		Progression.PathId.SPORE
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
		(
			"paint running down a face stays against it rather than glancing away "
			+ "(gap %.2f -> %.2f cells; travel %.2f -> %.2fpx)"
		) % [face_gap[0], face_gap[1], face_travel[0], face_travel[1]]
	)

	# The scene file is the surface this interface is designed on, so what a node
	# declares is not a preview of the wording - it is the wording. Every line the
	# game prints is that node's own text with named placeholders filled in, so the
	# check is that each literal fragment the scene declares survives into the
	# running label, and that no placeholder survives: one left as typed means the
	# game had no value for a name the editor asked for.
	# The interface is authored across several scenes now - the run scene instances
	# the pause menu, the slot cabinet and the draft panel - so the surface this rule
	# guards is the run scene *and* everything it instances. Walking only the run
	# scene would quietly stop checking most of the wording in the game.
	var declared_texts := {}
	var declared_offsets := {}
	var packed_prototype: PackedScene = load("res://scenes/run/run.tscn")
	var scene_state := packed_prototype.get_state()
	var gather_declared := func(state: SceneState, prefix: String, recurse: Callable) -> void:
		for node_index in range(state.get_node_count()):
			var raw_path := str(state.get_node_path(node_index))
			var node_path := raw_path if prefix.is_empty() else "%s/%s" % [prefix, raw_path]
			if raw_path == ".":
				node_path = prefix
			for property_index in range(state.get_node_property_count(node_index)):
				var name_of := str(state.get_node_property_name(node_index, property_index))
				var value_of = state.get_node_property_value(node_index, property_index)
				if name_of == "text":
					declared_texts[node_path] = str(value_of)
				elif name_of.begins_with("offset_") and typeof(value_of) == TYPE_FLOAT:
					declared_offsets[[node_path, name_of]] = float(value_of)
			var instanced: PackedScene = state.get_node_instance(node_index)
			if instanced != null:
				recurse.call(instanced.get_state(), node_path, recurse)
	gather_declared.call(scene_state, "", gather_declared)
	# Against a fresh run: the placeholders describe a run's opening state, and by
	# this point the suite has drafted paths and populated the choice panel.
	prototype.reset_run()
	prototype._update_hud()
	var literals_of := func(value: String) -> PackedStringArray:
		# The words either side of every {placeholder}, which is what the author
		# controls and what therefore has to reach the screen unchanged.
		var fragments := PackedStringArray()
		var cursor := 0
		while cursor < value.length():
			var opened := value.find("{", cursor)
			if opened < 0:
				fragments.append(value.substr(cursor))
				break
			fragments.append(value.substr(cursor, opened - cursor))
			var closed := value.find("}", opened)
			if closed < 0:
				break
			cursor = closed + 1
		return fragments
	var unauthored_lines := PackedStringArray()
	for node_path in declared_texts.keys():
		if node_path.contains("ChoicePanel"):
			# The draft panel is filled from whatever the run rolls, out of templates
			# exported on the run controller rather than off the node.
			continue
		var declared_node := prototype.get_node_or_null(NodePath(node_path))
		if declared_node == null or not ("text" in declared_node):
			continue
		var printed := str(declared_node.text)
		var declared: String = declared_texts[node_path]
		if not declared.contains("{"):
			# A line with nothing to fill in has to be printed exactly as authored.
			if printed != declared and not printed.is_empty():
				unauthored_lines.append("%s printed %s" % [node_path, printed])
			continue
		if printed.contains("{"):
			unauthored_lines.append("%s left a placeholder: %s" % [node_path, printed])
			continue
		for fragment: String in literals_of.call(declared):
			if not fragment.is_empty() and not printed.contains(fragment):
				unauthored_lines.append(
					"%s dropped %s from %s" % [node_path, fragment, printed]
				)
	_check(
		declared_texts.size() > 20 and unauthored_lines.is_empty(),
		"every line the game prints is the wording its scene node declares: %s" % (
			", ".join(unauthored_lines)
		)
	)

	# The same rule for layout, not just wording. A tool script that recomputes a
	# child's rect at load silently undoes anything placed by hand in the editor,
	# which is exactly what the drawer's meters did until it was taken out.
	var moved_by_code := PackedStringArray()
	for offset_key in declared_offsets.keys():
		var placed_path: String = offset_key[0]
		var property_name: String = offset_key[1]
		var placed_node := prototype.get_node_or_null(NodePath(placed_path)) as Control
		if placed_node == null:
			continue
		var live_value = placed_node.get(property_name)
		if absf(float(live_value) - float(declared_offsets[offset_key])) > 0.51:
			moved_by_code.append("%s.%s" % [placed_path.get_file(), property_name])
	_check(
		moved_by_code.is_empty(),
		"nothing moves a control the scene placed by hand"
	)
	if not moved_by_code.is_empty():
		print("    moved by code: %s" % ", ".join(moved_by_code))
	if not unauthored_lines.is_empty():
		print("    lines the game rewrote: %s" % ", ".join(unauthored_lines))

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
	prototype.metabolism.debug_grant_axis(Metabolism.SystemId.PHOTOSYNTHESIS, 8)
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
			Progression.PathId.BLOOM, Progression.PathId.SPORE
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
	prototype._choice_kind = RunRoot.ChoiceKind.NONE
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
		and focus_on_pad == prototype.pause_menu.resume_button
		and focus_after_mouse == null
		and focus_after_key == null,
		"the focus ring appears only for a controller and leaves on mouse or keyboard"
	)

	# Mass and Force are physically distinct: Mass decides how much material is
	# thrown, Push decides how far it goes. Both develop out of the same earnings, so
	# what has to hold is that each rides its own axis and the build can lean them
	# apart.
	prototype.metabolism.reset_metabolism()
	prototype.progression.reset_progression()
	for _bloom_unlock in range(
		int(prototype.metabolism.pressure_unlock_seconds * 30.0) + 30
	):
		prototype.metabolism.advance(1.0 / 30.0)
	var mass_before := prototype.bloom_director.get_bloom_mass_multiplier()
	var force_before := prototype.bloom_director.get_bloom_force_multiplier()
	prototype.progression.debug_select_paths(
		Progression.PathId.ROOT,
		Progression.PathId.SPORE
	)
	prototype.progression.add_biomass(4000.0)
	var mass_after := prototype.bloom_director.get_bloom_mass_multiplier()
	var mass_leaning_force := prototype.bloom_director.get_bloom_force_multiplier()
	prototype.progression.debug_select_paths(
		Progression.PathId.BLOOM,
		Progression.PathId.PRUNING
	)
	var push_leaning_force := prototype.bloom_director.get_bloom_force_multiplier()
	var push_leaning_mass := prototype.bloom_director.get_bloom_mass_multiplier()
	_check(
		mass_after > mass_before
		and push_leaning_force > mass_leaning_force
		and push_leaning_mass < mass_after,
		"Bloom Mass rides Mass and Bloom Force rides Push, and the build leans them apart"
	)
	prototype.progression.reset_progression()
	prototype.metabolism.reset_metabolism()
	prototype.metabolism.reset_metabolism()

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
		Progression.PathId.BRAMBLE,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	var tether_spot := _find_owned_cell_position(prototype)
	prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
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

	# Man-Eater: enemies that graze on the run's Green long enough are marked, and
	# killing a marked one sprouts a plant out of the corpse that bites once. The
	# relic is paid for by the enemy, so nothing here is aimed or charged.
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	var man_eater := prototype.man_eater
	man_eater.reset_man_eater()
	var green_spot := _find_owned_cell_position(prototype)

	# Without the relic, grazing marks nobody.
	var grazer_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.GRAZER, green_spot
	)
	prototype.combat.enemy_ate_green.emit(
		grazer_id, 1.0, man_eater.required_consumption_seconds * 2.0
	)
	var marked_without_relic := man_eater.get_marked_count()
	prototype.progression._owned_relics[RelicCatalog.Id.MAN_EATER] = 1

	# The mark is earned by cumulative consumption, and it does not have to be
	# continuous: two short grazes add up to the same as one long one.
	prototype.combat.enemy_ate_green.emit(
		grazer_id, 1.0, man_eater.required_consumption_seconds * 0.5
	)
	var marked_halfway := man_eater.get_marked_count()
	var partial_progress := man_eater.get_consumption_seconds(grazer_id) > 0.0
	prototype.combat.enemy_ate_green.emit(
		grazer_id, 1.0, man_eater.required_consumption_seconds * 0.5
	)
	var marked_after := man_eater.is_marked(grazer_id)
	_check(
		marked_without_relic == 0
		and marked_halfway == 0
		and partial_progress
		and marked_after,
		"MAN-EATER marks a grazer on cumulative Green consumption, not on one long graze"
	)

	# An unmarked corpse sprouts nothing; a marked one does, after its delay.
	var plain_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER, green_spot + Vector2(60.0, 0.0)
	)
	prototype.combat.damage_enemy_by_id(
		plain_id, 100000.0, CombatDirector.DeathSource.DEBUG
	)
	for _plain_tick in range(30):
		man_eater.advance(1.0 / 60.0)
	var maws_from_plain_corpse := man_eater.get_active_maw_count()
	prototype.combat.damage_enemy_by_id(
		grazer_id, 100000.0, CombatDirector.DeathSource.DEBUG
	)
	var erupted_instantly := man_eater.get_active_maw_count()
	for _erupt_tick in range(int(man_eater.eruption_delay_seconds * 60.0) + 4):
		man_eater.advance(1.0 / 60.0)
	var erupted_after_delay := man_eater.get_active_maw_count()
	_check(
		maws_from_plain_corpse == 0
		and erupted_instantly == 0
		and erupted_after_delay == 1,
		"MAN-EATER sprouts only from a marked corpse, and only after its delay"
	)

	# The bite lands once, is capped in how many it takes, and then the plant dies.
	var prey := PackedInt32Array()
	for prey_index in range(man_eater.maximum_bite_targets + 3):
		prey.append(prototype.combat.spawn_enemy(
			CombatDirector.EnemyRole.HEAVY_GRAZER,
			green_spot + Vector2(-20.0 + float(prey_index) * 6.0, 0.0)
		))
	var healthy_before := 0
	for prey_id in prey:
		if is_equal_approx(
			prototype.combat.get_enemy_health(prey_id),
			prototype.combat.heavy_grazer_profile.maximum_health
		):
			healthy_before += 1
	for _bite_tick in range(int(man_eater.maw_lifetime_seconds * 60.0) + 10):
		man_eater.advance(1.0 / 60.0)
	var bitten := 0
	for prey_id in prey:
		if prototype.combat.get_enemy_health(prey_id) < prototype.combat.heavy_grazer_profile.maximum_health:
			bitten += 1
	_check(
		healthy_before == prey.size()
		and bitten > 0
		and bitten <= man_eater.maximum_bite_targets
		and man_eater.get_active_maw_count() == 0,
		"MAN-EATER bites once, takes no more than its cap, and the plant then dies (%d)"
			% bitten
	)

	# The global cooldown is the crowd-safety rule: a pile of marked deaths on one
	# frame cannot carpet the field with plants.
	man_eater.reset_man_eater()
	prototype.combat.reset_combat()
	var marked_pack := PackedInt32Array()
	for _pack_index in range(5):
		var packed_id := prototype.combat.spawn_enemy(
			CombatDirector.EnemyRole.GRAZER, green_spot
		)
		marked_pack.append(packed_id)
		prototype.combat.enemy_ate_green.emit(
			packed_id, 1.0, man_eater.required_consumption_seconds
		)
	for packed_id in marked_pack:
		prototype.combat.damage_enemy_by_id(
			packed_id, 100000.0, CombatDirector.DeathSource.DEBUG
		)
	for _flood_tick in range(int(man_eater.eruption_delay_seconds * 60.0) + 4):
		man_eater.advance(1.0 / 60.0)
	_check(
		man_eater.get_active_maw_count() <= 1
		and man_eater.get_eruption_count() <= 1 + man_eater.maximum_queued_eruptions,
		"MAN-EATER holds its global cooldown when a marked pack dies at once"
	)
	prototype.progression.reset_progression()
	prototype.combat.reset_combat()
	man_eater.reset_man_eater()


	# Pruning: the run cuts its own ecosystem back and fires the harvest outward.
	prototype.progression.reset_progression()
	prototype.progression.offer_pruning_path = true
	prototype.progression.debug_select_paths(
		Progression.PathId.PRUNING,
		Progression.PathId.SPORE
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
	prototype.combat._cane_remaining = 9999.0
	var cutting_target := _spawn_bramble_contact_enemy(
		prototype,
		CombatDirector.EnemyRole.BOSS,
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
	prototype.combat._cane_remaining = 9999.0
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
		CombatDirector.EnemyRole.BOSS,
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
	prototype.evolutions.evolution_status = Progression.EvolutionStatus.EVOLVED
	prototype.evolutions.active_evolution = Progression.EvolutionId.DEADFALL
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
		CombatDirector.EnemyRole.BOSS,
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
		if cutting.state != PruningDirector.CuttingState.LAUNCHED:
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
		if cutting.state == PruningDirector.CuttingState.LAUNCHED:
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
		Progression.UpgradeId.PRUNING_CUTTING_YIELD,
		Progression.UpgradeId.PRUNING_CUTTING_DAMAGE,
		Progression.UpgradeId.PRUNING_CHARGE,
	]:
		prototype.progression._upgrade_levels[quiet_line] = 3
	var cost_unchanged := pruning.get_cycle_target_cells() == cells_before_upgrades
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.PRUNING_HARVEST_RATE
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
		Progression.UpgradeId.PRUNING_HARVEST_RATE,
		Progression.UpgradeId.PRUNING_CUTTING_YIELD,
		Progression.UpgradeId.PRUNING_CUTTING_DAMAGE,
		Progression.UpgradeId.PRUNING_CHARGE,
	]:
		prototype.progression._upgrade_levels[pruning_line] = 0

	# The five Pruning pairings.
	var pruning_pairings := [
		[Progression.PathId.SPORE, Progression.EvolutionId.PIONEER],
		[Progression.PathId.BLOOM, Progression.EvolutionId.REBOUND],
		[Progression.PathId.BRAMBLE, Progression.EvolutionId.DEADFALL],
		[Progression.PathId.ROOT, Progression.EvolutionId.COPPICING],
	]
	var pruning_pairings_resolve := true
	for pairing in pruning_pairings:
		prototype.progression.debug_select_paths(
			Progression.PathId.PRUNING,
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
		Progression.PathId.PRUNING,
		Progression.PathId.SPORE
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
		Progression.PathId.PRUNING,
		Progression.PathId.BLOOM
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
		Progression.PathId.PRUNING,
		Progression.PathId.BRAMBLE
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
		Progression.PathId.PRUNING,
		Progression.PathId.SPORE
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
		Progression.PathId.PRUNING,
		Progression.PathId.ROOT
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
		Progression.PathId.PRUNING,
		Progression.PathId.SPORE
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
	prototype.combat._cane_remaining = 999.0
	var grazing_enemy := _spawn_bramble_contact_enemy(
		prototype,
		CombatDirector.EnemyRole.GRAZER,
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
	# Bramble is entered the only way any Adaptation is: by drafting one of its
	# upgrade lines out of an ordinary level-up. The frontier arms the moment it is.
	_acquire_adaptation(prototype, Progression.PathId.BRAMBLE)
	_check(
		prototype.progression.owns_adaptation(Progression.PathId.BRAMBLE)
		and prototype.territory_field.is_bramble_enabled(),
		"drafting a Bramble line immediately arms the authoritative Green frontier"
	)

	# Its other three lines are open at rank 0 straight away, and with the second
	# Core slot still free the rest of the roster stays on the table beside them.
	prototype.progression._pending_upgrade_options.clear()
	var bramble_upgrade_options := prototype.progression.get_ordinary_candidate_lines()
	var open_slot_draft_paths: Array[int] = []
	for option_id in bramble_upgrade_options:
		var upgrade_path := prototype.progression._get_upgrade_path(option_id)
		if not open_slot_draft_paths.has(upgrade_path):
			open_slot_draft_paths.append(upgrade_path)
	_check(
		bramble_upgrade_options.has(Progression.UpgradeId.BRAMBLE_ENTANGLEMENT_RATE)
		and bramble_upgrade_options.has(Progression.UpgradeId.BRAMBLE_REPULSION)
		and open_slot_draft_paths.has(Progression.PathId.BLOOM),
		"drafts expose Bramble's remaining lines and keep the roster open for Core 2"
	)

	prototype.territory_field.debug_establish_bramble()
	var frontier_position := _find_player_frontier(prototype.territory_field)
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	var bramble_enemy := _spawn_bramble_contact_enemy(
		prototype,
		CombatDirector.EnemyRole.BOSS,
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
	prototype.progression._upgrade_levels[Progression.UpgradeId.BRAMBLE_ENTANGLEMENT] = (
		prototype.progression.maximum_upgrade_level
	)
	prototype.progression._upgrade_levels[Progression.UpgradeId.BRAMBLE_REPULSION] = 1
	prototype.progression._upgrade_levels[Progression.UpgradeId.BRAMBLE_ENTANGLEMENT_RATE] = (
		prototype.progression.maximum_upgrade_level
	)
	prototype._apply_progression_modifiers()
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	var repelled_enemy := _spawn_bramble_contact_enemy(
		prototype,
		CombatDirector.EnemyRole.ELITE,
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
		and prototype.bramble_director.get_entanglement_rate_multiplier() > 1.0,
		"Repulsion slides a territory attacker out over time without damaging it, once per cooldown"
	)

	# Every way an enemy weakens Green counts as an attack, not erosion alone.
	var repelled_behaviours := true
	var checked_behaviours := 0
	for weakening_role in [
		CombatDirector.EnemyRole.GRAZER,
		CombatDirector.EnemyRole.CORRUPTOR,
		CombatDirector.EnemyRole.WARDEN,
	]:
		prototype.combat.reset_combat()
		prototype.combat._cane_remaining = 999.0
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
		Progression.UpgradeId.BRAMBLE_GRASPING_THORNS
	] = 1
	prototype._apply_progression_modifiers()
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	var rooted_enemy := _spawn_bramble_contact_enemy(
		prototype,
		CombatDirector.EnemyRole.ELITE,
		frontier_position
	)
	rooted_enemy.entanglement = 0.5
	prototype.combat.simulate_step(0.0)
	var half_entangled_root := rooted_enemy.bramble_ensnare_remaining
	rooted_enemy.entanglement = 1.0
	rooted_enemy.position = frontier_position
	prototype.combat.simulate_step(0.0)
	var ensnare_seconds := rooted_enemy.bramble_ensnare_remaining
	var ensnare_duration_for_indicator := rooted_enemy.bramble_ensnare_duration
	var rooted_speed := rooted_enemy.movement_speed_multiplier
	# Serve out the hold, then confirm the immunity window blocks an instant re-root.
	for _root_step in range(30):
		rooted_enemy.position = frontier_position
		rooted_enemy.entanglement = 1.0
		prototype.combat.simulate_step(0.05)
	_check(
		is_equal_approx(half_entangled_root, 0.0)
		and ensnare_seconds > 0.0
		and is_equal_approx(ensnare_seconds, prototype.bramble_director.get_ensnare_seconds())
		and is_equal_approx(rooted_speed, 0.0)
		and is_equal_approx(rooted_enemy.bramble_ensnare_remaining, 0.0)
		and rooted_enemy.bramble_ensnare_immunity_remaining > 0.0,
		"Grasping Roots pins a fully Entangled enemy, then holds it immune for a spell"
	)
	_check(
		is_equal_approx(ensnare_duration_for_indicator, ensnare_seconds)
		and ensnare_duration_for_indicator > 0.0,
		"a rooted enemy records the hold's full length so its indicator can unwind"
	)
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.BRAMBLE_GRASPING_THORNS
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
	prototype.combat._cane_remaining = 999.0
	var single_tick_frontier := _find_player_frontier(prototype.territory_field)
	var single_tick_enemy := _spawn_bramble_contact_enemy(
		prototype,
		CombatDirector.EnemyRole.BOSS,
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
	prototype.combat._cane_remaining = 999.0
	var crossing_enemy := _spawn_bramble_contact_enemy(
		prototype,
		CombatDirector.EnemyRole.BOSS,
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
	prototype.combat._cane_remaining = 999.0
	var fresh_crossing_enemy := _spawn_bramble_contact_enemy(
		prototype,
		CombatDirector.EnemyRole.BOSS,
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
	prototype.combat._cane_remaining = 999.0
	var thorn_frontier := _find_player_frontier(prototype.territory_field)
	prototype.combat.set_enemy_scaling(1.0, 1.0)
	var small_enemy := _spawn_bramble_contact_enemy(
		prototype,
		CombatDirector.EnemyRole.HUNTER,
		thorn_frontier
	)
	var large_enemy := _spawn_bramble_contact_enemy(
		prototype,
		CombatDirector.EnemyRole.BOSS,
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
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT,
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT_RATE,
		Progression.UpgradeId.BRAMBLE_GRASPING_THORNS,
		Progression.UpgradeId.BRAMBLE_REPULSION,
	]:
		bramble_lines_are_control_shaped = (
			bramble_lines_are_control_shaped
			and prototype.progression._get_upgrade_path(bramble_line)
			== Progression.PathId.BRAMBLE
		)
	var thorn_damage_tick_before := prototype.combat.get_bramble_tick_damage(
		small_enemy,
		1.0
	)
	for bramble_line in [
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT,
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT_RATE,
		Progression.UpgradeId.BRAMBLE_GRASPING_THORNS,
		Progression.UpgradeId.BRAMBLE_REPULSION,
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
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT,
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT_RATE,
		Progression.UpgradeId.BRAMBLE_GRASPING_THORNS,
		Progression.UpgradeId.BRAMBLE_REPULSION,
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

	# Exercise the real Root path gate without disturbing the primary-only run this
	# longer scenario is about. Temporarily filling the unused support slot makes
	# RootDirector see a genuinely held Root path, then the exact state is restored.
	var unrooted_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	small_enemy.bramble_ground_maturity = 1.0
	var fresh_ground_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	var previous_tertiary_path := prototype.progression.tertiary_path
	prototype.progression.tertiary_path = Progression.PathId.ROOT
	var mature_ground_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	small_enemy.bramble_ground_maturity = 0.0
	var root_network_fresh_tick := prototype.combat.get_bramble_tick_damage(small_enemy, 1.0)
	prototype.progression.tertiary_path = previous_tertiary_path
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
	prototype.combat._cane_remaining = 999.0
	var shared_enemies: Array[CombatDirector.EnemyState] = []
	var shared_health_before := PackedFloat32Array()
	for _shared_index in range(4):
		var shared_enemy := _spawn_bramble_contact_enemy(
			prototype,
			CombatDirector.EnemyRole.HUNTER,
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

	# The pairing closes the same way it opened: a second uncommitted line is
	# drafted, and taking it freezes the run's Evolution.
	_acquire_adaptation(prototype, Progression.PathId.SPORE)
	_check(
		prototype.progression.secondary_path == Progression.PathId.SPORE
		and prototype.progression.primary_path == Progression.PathId.BRAMBLE
		and prototype.progression.get_pair_evolution_id()
		== Progression.EvolutionId.BRIAR_PODS,
		"acquiring the second Core locks the run pairing and its Evolution"
	)

	prototype.progression._upgrade_offer_cursor = (
		Progression.UpgradeId.BLOOM_FORCE
	)
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var locked_draft_options := prototype.progression.get_pending_upgrade_options()
	var locked_draft_is_filtered := not locked_draft_options.is_empty()
	for option_id in locked_draft_options:
		var locked_path := prototype.progression._get_upgrade_path(option_id)
		locked_draft_is_filtered = (
			locked_draft_is_filtered
			and (
				locked_path == Progression.UNSELECTED_PATH
				or prototype.progression.has_path(locked_path)
			)
		)
	_check(
		locked_draft_is_filtered
		and not locked_draft_options.has(Progression.UpgradeId.BLOOM_FORCE),
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
		== Progression.EvolutionId.BRIAR_PODS
		and prototype.combat.get_active_briar_pod_count() == 1,
		"Spore plus Bramble evolves into Briar Pods that raise temporary thorn perimeters"
	)
	prototype.combat._cane_remaining = 999.0
	var briar_ring_position := (
		briar_center + Vector2(prototype.evolutions.briar_pod_radius_pixels, 0.0)
	)
	var briar_enemy := _spawn_bramble_contact_enemy(
		prototype,
		CombatDirector.EnemyRole.BOSS,
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
	prototype.combat._cane_remaining = 999.0
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
		CombatDirector.EnemyRole.ELITE,
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
		Progression.PathId.BLOOM,
		Progression.PathId.BRAMBLE
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
		== Progression.EvolutionId.THORNBURST
		and traps_from_harvest > 0
		and traps_without_bramble == 0,
		"Thornburst harvests Bramble-covered territory into a field of Briar Traps"
	)

	# A trap waits for prey, blows once, and lights its neighbours.
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
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
		CombatDirector.EnemyRole.ELITE,
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
	_seed_run_adaptations(
		prototype,
		Progression.PathId.SPORE,
		Progression.PathId.ROOT
	)
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
		"choosing an upgrade commits a growth line and resumes play"
	)

	prototype.progression.reset_progression()
	prototype.progression.acquire_adaptation(Progression.PathId.THISTLE)
	var final_level_upgrade := Progression.UpgradeId.THISTLE_CLUSTERING
	prototype.progression._upgrade_levels[final_level_upgrade] = (
		prototype.progression.maximum_upgrade_level - 1
	)
	# Thistle is the run's only Adaptation and its other three lines are mastered, so
	# the line under test is the only ordinary candidate the screen can draw.
	for other_line in prototype.progression.get_adaptation_line_ids(
		Progression.PathId.THISTLE
	):
		if other_line != final_level_upgrade:
			prototype.progression._upgrade_levels[other_line] = (
				prototype.progression.get_upgrade_maximum_level(other_line)
			)
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var final_level_offer_index := prototype.progression.get_pending_upgrade_options().find(
		final_level_upgrade
	)
	_check(
		final_level_offer_index >= 0
		and prototype.choice_panel.buttons[final_level_offer_index].text.contains("LEVEL 2 → 3")
		and not prototype.choice_panel.buttons[final_level_offer_index].text.contains("3/3"),
		"a final-rank draft says level 2 to 3 instead of presenting itself as already 3/3"
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

	# Ecosystem Metabolism. Nothing here is bought and nothing here is clicked: the
	# three axes develop out of the Biomass the run has earned across its whole life,
	# along the same cost curve the old shop charged.
	var metabolism := prototype.metabolism
	metabolism.reset_metabolism()
	prototype.progression.reset_progression()
	var mass_level_before := metabolism.get_level(Metabolism.SystemId.PHOTOSYNTHESIS)
	for _idle_step in range(300):
		metabolism.advance(1.0 / 30.0)
	_check(
		metabolism.get_level(Metabolism.SystemId.PHOTOSYNTHESIS) == mass_level_before,
		"the run clock alone never moves a physical axis"
	)

	# Earning is what develops it, and the rank arrives where the cost curve says it
	# should rather than at some second opinion about the price.
	metabolism.reset_metabolism()
	prototype.progression.reset_progression()
	var mass_id := Metabolism.SystemId.PHOTOSYNTHESIS
	var second_rank_cost := metabolism.get_cumulative_rank_cost(2)
	var mass_share := metabolism.get_axis_share(mass_id)
	prototype.progression.add_biomass(second_rank_cost / mass_share * 0.96)
	var short_of_the_rank := metabolism.get_level(mass_id)
	prototype.progression.add_biomass(second_rank_cost / mass_share * 0.08)
	_check(
		short_of_the_rank == 1 and metabolism.get_level(mass_id) == 2,
		"an axis reaches its next rank when lifetime earnings pay the curve price"
	)

	# Spending must never take development back. This is the whole reason lifetime
	# earnings are tracked apart from the balance: a Clover spin or an Overgrow can
	# empty the run pocket, and the organism it has already become stays.
	var rank_before_spending := metabolism.get_level(mass_id)
	prototype.progression.spend_biomass(1000000.0)
	_check(
		is_equal_approx(prototype.progression.biomass, 0.0)
		and metabolism.get_level(mass_id) == rank_before_spending,
		"spending the reserve to nothing never costs the run a rank it has developed"
	)

	# The build leans the ladder. A run down Bramble develops Hold out of the same
	# earnings a run down Bloom spends on Push, without either being asked to allocate.
	metabolism.reset_metabolism()
	prototype.progression.reset_progression()
	for _unlock_step in range(int(metabolism.cohesion_unlock_seconds * 30.0) + 60):
		metabolism.advance(1.0 / 30.0)
	var even_hold_share := metabolism.get_axis_share(Metabolism.SystemId.CAMBIUM)
	prototype.progression.debug_select_paths(
		Progression.PathId.BRAMBLE,
		Progression.PathId.SPORE
	)
	var leaned_hold_share := metabolism.get_axis_share(Metabolism.SystemId.CAMBIUM)
	_check(
		leaned_hold_share > even_hold_share,
		"the Paths a run is built from lean the ladder toward the axis they feed "
			+ "(%.2f against %.2f)" % [leaned_hold_share, even_hold_share]
	)

	# The economy unfolds on the run clock: Mass from the first second, the other two
	# while the run is being played, so it opens simple and gains capabilities.
	metabolism.reset_metabolism()
	prototype.progression.reset_progression()
	var push_locked_at_the_start := not metabolism.is_system_unlocked(
		Metabolism.SystemId.MERISTEM
	)
	for _push_step in range(int(metabolism.pressure_unlock_seconds * 30.0) + 30):
		metabolism.advance(1.0 / 30.0)
	_check(
		metabolism.is_system_unlocked(Metabolism.SystemId.PHOTOSYNTHESIS)
		and push_locked_at_the_start
		and metabolism.is_system_unlocked(Metabolism.SystemId.MERISTEM),
		"Mass is available from the start and Push arrives on the run clock"
	)
	metabolism.reset_metabolism()
	prototype.progression.reset_progression()

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
	var all_slot_paths_present := CloverSlot.PATH_SYMBOLS.size() == Progression.PathId.size()
	var mapped_slot_paths := {}
	for path_symbol in CloverSlot.PATH_SYMBOLS:
		var mapped_path := prototype._path_id_for_symbol(path_symbol)
		all_slot_paths_present = (
			all_slot_paths_present
			and CloverSlot.is_path_symbol(path_symbol)
			and mapped_path >= 0
			and prototype.slot_panel.symbol_texture(path_symbol) != null
		)
		mapped_slot_paths[mapped_path] = true
	_check(
		all_slot_paths_present
		and mapped_slot_paths.size() == Progression.PathId.size()
		and CloverSlot.PATH_SYMBOLS.has(CloverSlot.Symbol.THISTLE)
		and CloverSlot.PATH_SYMBOLS.has(CloverSlot.Symbol.VINE)
		and CloverSlot.PATH_SYMBOLS.has(CloverSlot.Symbol.FRUIT)
		and CloverSlot.resolve_outcome(PackedInt32Array([
			CloverSlot.Symbol.FRUIT,
			CloverSlot.Symbol.CLOVER,
			CloverSlot.Symbol.FRUIT,
		])) == CloverSlot.Outcome.PATH_JACKPOT,
		"all eight Paths have unique reel mappings and icons, including the three Adaptations"
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
	prototype.slot_panel._on_hover_changed(true)
	var previewed := machine.get_preview_cells().duplicate()
	prototype.slot_panel._on_hover_changed(false)
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
		Progression.UpgradeId.ROOT_MATURATION
	)
	var slots_before := prototype.progression.get_slotted_upgrades().size()
	jackpots.light(Progression.PathId.ROOT)
	var lent := prototype.progression.get_upgrade_level(
		Progression.UpgradeId.ROOT_MATURATION
	)
	var lent_other_path := prototype.progression.get_upgrade_level(
		Progression.UpgradeId.BLOOM_FORCE
	)
	var owns_path := prototype.progression.has_path(Progression.PathId.ROOT)
	var stacked := jackpots.light(Progression.PathId.ROOT)
	jackpots.advance(jackpots.root_seconds + 0.01)
	var still_lit := jackpots.is_active(Progression.PathId.ROOT)
	jackpots.advance(jackpots.root_seconds + 0.01)
	_check(
		lent == prototype.progression.casino_upgrade_level
		and lent_other_path == 0
		and not owns_path
		and prototype.progression.get_owned_upgrade_level(
			Progression.UpgradeId.ROOT_MATURATION
		) == owned_before
		and prototype.progression.get_slotted_upgrades().size() == slots_before
		and is_equal_approx(stacked, jackpots.root_seconds * 2.0)
		and still_lit
		and not jackpots.is_active(Progression.PathId.ROOT)
		and prototype.progression.get_upgrade_level(
			Progression.UpgradeId.ROOT_MATURATION
		) == owned_before,
		"a jackpot runs the Path at its ceiling for a stacking duration, grants no ownership, and gives it all back"
	)

	# The three new faces must pay real, immediately readable Path events, not merely
	# light a timer whose mechanic remains dormant until some later cadence.
	prototype.progression.reset_progression()
	jackpots.reset_jackpots()
	prototype.territory_field.reset_field()
	prototype.player.reset_player()
	prototype.combat.reset_combat()
	adaptations.reset_adaptations()
	prototype._apply_progression_modifiers()
	var adaptation_jackpot_origin := prototype.player.get_arena_position()
	prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
		adaptation_jackpot_origin + Vector2(96.0, 0.0)
	)
	prototype._on_path_jackpot(CloverSlot.Symbol.THISTLE, 1.0)
	var jackpot_thorns := 0
	for thorn in adaptations._thorns:
		if thorn.active:
			jackpot_thorns += 1
	# The jackpot lends Thistle its firing numbers, not extra turrets. The network is
	# one Thistle, so a loan that expires in ten seconds cannot leave a second
	# permanent turret standing behind it.
	var thistle_jackpot_fired := (
		jackpots.is_active(Progression.PathId.THISTLE)
		and adaptations.get_active_thistle_count() == 1
		and jackpot_thorns > 0
	)

	jackpots.reset_jackpots()
	prototype.progression.reset_progression()
	prototype.combat.reset_combat()
	adaptations.reset_adaptations()
	prototype._apply_progression_modifiers()
	var vine_jackpot_enemy := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
		adaptation_jackpot_origin + Vector2(96.0, 0.0)
	)
	var vine_jackpot_health := prototype.combat.get_enemy_health(vine_jackpot_enemy)
	prototype._on_path_jackpot(CloverSlot.Symbol.VINE, 1.0)
	for _vine_jackpot_frame in range(24):
		prototype.combat.simulate_step(1.0 / 60.0)
	var vine_jackpot_fired := (
		jackpots.is_active(Progression.PathId.VINE)
		and prototype.combat.get_enemy_health(vine_jackpot_enemy) < vine_jackpot_health
		and prototype.combat._cane_auto_targets
	)

	jackpots.reset_jackpots()
	prototype.progression.reset_progression()
	prototype.combat.reset_combat()
	adaptations.reset_adaptations()
	prototype._apply_progression_modifiers()
	prototype._on_path_jackpot(CloverSlot.Symbol.FRUIT, 1.0)
	var jackpot_fruit_at_start_speed := true
	for fruit in adaptations._fruits:
		if fruit.active and not fruit.dropped_seed:
			jackpot_fruit_at_start_speed = (
				jackpot_fruit_at_start_speed
				and is_equal_approx(fruit.speed, adaptations.fruit_speed_pixels_per_second)
			)
	# Four Fruit, which is Fruit Set's rank-3 maximum: the jackpot runs the
	# Adaptation at its real ceiling, and that ceiling is three ranks now.
	var fruit_jackpot_fired := (
		jackpots.is_active(Progression.PathId.FRUIT)
		and adaptations.get_active_fruit_count() == 4
		and jackpot_fruit_at_start_speed
	)
	_check(
		thistle_jackpot_fired and vine_jackpot_fired and fruit_jackpot_fired,
		"Thistle, Vine, and Fruit reel faces fire their real max-rank battlefield events"
	)
	jackpots.reset_jackpots()
	prototype.progression.reset_progression()
	adaptations.reset_adaptations()
	prototype.combat.reset_combat()
	prototype._apply_progression_modifiers()

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
	jackpots.light(Progression.PathId.BRAMBLE)
	jackpots.light(Progression.PathId.ROOT)
	var lit_slow := prototype.bramble_director.get_slow_fraction()
	var lit_thorns := prototype.territory_field.is_bramble_enabled()
	var lit_maturation := prototype.root_director.get_maturation_multiplier()
	var lit_pruning := prototype.progression.has_path_active(
		Progression.PathId.PRUNING
	)
	jackpots.light(Progression.PathId.PRUNING)
	var lit_pruning_after := prototype.progression.has_path_active(
		Progression.PathId.PRUNING
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
		and not prototype.progression.has_path_active(Progression.PathId.PRUNING),
		"the loan is handed back when the timer runs out"
	)

	# The jackpot stacks on top of what the run already owns rather than raising it to a
	# floor. A player who has already maxed a line bought that ceiling, and handing it
	# back what it owned would be no reward for the path the run is built around.
	prototype.progression.reset_progression()
	jackpots.reset_jackpots()
	prototype.progression.debug_select_paths(
		Progression.PathId.ROOT,
		Progression.PathId.BRAMBLE
	)
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.ROOT_MATURATION
	] = prototype.progression.maximum_upgrade_level
	var owned_rank := prototype.progression.get_owned_upgrade_level(
		Progression.UpgradeId.ROOT_MATURATION
	)
	jackpots.light(Progression.PathId.ROOT)
	var maxed_with_jackpot := prototype.progression.get_upgrade_level(
		Progression.UpgradeId.ROOT_MATURATION
	)
	var unowned_with_jackpot := prototype.progression.get_upgrade_level(
		Progression.UpgradeId.ROOT_LATERAL_ROOTS
	)
	# Ownership is still ownership: a relic that requires the player to have selected a
	# path must keep requiring it, whatever the reels paid.
	var borrowed_ownership := prototype.progression.has_path(
		Progression.PathId.PRUNING
	)
	jackpots.light(Progression.PathId.PRUNING)
	_check(
		owned_rank == prototype.progression.maximum_upgrade_level
		and maxed_with_jackpot == owned_rank + prototype.progression.casino_upgrade_level
		and unowned_with_jackpot == prototype.progression.casino_upgrade_level
		and not borrowed_ownership
		and not prototype.progression.has_path(Progression.PathId.PRUNING)
		and prototype.progression.get_owned_upgrade_level(
			Progression.UpgradeId.ROOT_MATURATION
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
	prototype.progression._owned_relics[RelicCatalog.Id.HARD_HUSK] = 1
	prototype.progression._owned_relics[RelicCatalog.Id.DOMINO_GERMINATION] = 1
	prototype._update_relic_slots()
	var common_edge := prototype.relic_slots.get_slot_border_color(0)
	var legendary_edge := prototype.relic_slots.get_slot_border_color(1)
	var empty_edge := prototype.relic_slots.get_slot_border_color(2)
	var slot_names_rarity := prototype.relic_slots.get_slot_tooltip(1).contains("LEGENDARY")
	# Hue only: the row keeps its own border alpha so a rarity cannot quietly change how
	# solid a slot looks, only what colour it is.
	var same_hue := func(edge: Color, rarity: int) -> bool:
		var wanted := RelicCatalog.get_rarity_color(rarity)
		return (
			is_equal_approx(edge.r, wanted.r)
			and is_equal_approx(edge.g, wanted.g)
			and is_equal_approx(edge.b, wanted.b)
		)
	_check(
		same_hue.call(common_edge, RelicCatalog.Rarity.COMMON)
		and same_hue.call(legendary_edge, RelicCatalog.Rarity.LEGENDARY)
		and not common_edge.is_equal_approx(legendary_edge)
		and not legendary_edge.is_equal_approx(empty_edge)
		and slot_names_rarity,
		"a relic slot is coloured by its rarity and still names it in words"
	)
	prototype.progression.reset_progression()
	prototype._update_relic_slots()

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

	# The release is poured in over a ramp rather than dropped in one step, so the
	# border grows into the ground instead of jumping a visible distance between two
	# frames. It still has to arrive, and it still has to be the whole of it.
	metabolism.reset_metabolism()
	prototype.progression.reset_progression()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	prototype.territory_field.recalculate_metrics_now()
	metabolism.debug_grant_axis(Metabolism.SystemId.PHOTOSYNTHESIS, 1)
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

	# The three systems are the physical parameters: Mass, Pressure, Cohesion. They
	# rise together out of one pool of lifetime earnings, and all three reach the
	# simulation.
	metabolism.reset_metabolism()
	prototype.progression.reset_progression()
	for _axis_unlock in range(int(metabolism.cohesion_unlock_seconds * 30.0) + 60):
		metabolism.advance(1.0 / 30.0)
	prototype._apply_progression_modifiers()
	var spread_before := prototype.territory_field.tuning.natural_spread_rate
	var cohesion_before := prototype.territory_field.get_cohesion_multiplier()
	prototype.progression.add_biomass(6000.0)
	metabolism.advance(1.0 / 30.0)
	prototype._apply_progression_modifiers()
	_check(
		prototype.territory_field.tuning.natural_spread_rate > spread_before
		and prototype.territory_field.get_cohesion_multiplier() > cohesion_before
		and metabolism.get_mass_multiplier() > 1.0,
		"earning moves Mass, Pressure, and Cohesion in the simulation itself"
	)

	# The HUD rules: the sidebar says what is true, the drawer is where decisions
	# are made, and anything with nothing to say is not on screen.
	metabolism.reset_metabolism()
	prototype.progression.reset_progression()
	prototype.combat.reset_combat()
	prototype._update_hud()
	var quiet_hostiles_shown := prototype.hostile_label.visible
	prototype.combat.spawn_pack(CombatDirector.EnemyRole.HUNTER, 3)
	prototype._update_hud()
	var threatened_hostiles_shown := prototype.hostile_label.visible
	prototype.combat.reset_combat()
	_check(
		not quiet_hostiles_shown
		and threatened_hostiles_shown
		and prototype.hostile_label.text.contains("3"),
		"the hostile count appears only while there are hostiles to warn about"
	)

	# The first matching pair of a run stops the battlefield and lets the third reel
	# resolve on its own. Once per run: the point is the first time, and a game that
	# paused every time two reels agreed would be a game that pauses constantly.
	var machine_focus := prototype.slot_machine
	prototype.reset_run()
	_seed_run_adaptations(
		prototype,
		Progression.PathId.SPORE,
		Progression.PathId.ROOT
	)
	machine_focus.reset_machine()
	var cinematic_before := prototype.is_pair_cinematic_active()
	prototype._on_pair_tease_started(CloverSlot.Symbol.BLOOM, true)
	var cinematic_running := prototype.is_pair_cinematic_active()
	var field_held := prototype.territory_field.simulation_paused
	# Long enough to carry the focus in, the reel, and the focus back out.
	for _focus_step in range(600):
		prototype.slot_panel.advance_focus(1.0 / 60.0)
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
		prototype.slot_panel.advance_focus(1.0 / 60.0)
	_check(
		later_focus
		and not later_pause
		and prototype.slot_panel.pair_tease_scale < prototype.slot_panel.pair_focus_scale,
		"a later matching pair leans the panel in without pausing the run"
	)

	# The rewind is an animation and never a rig. Its stages have to run in order and
	# land the reel back on the symbol the machine rolled before the lever finished
	# moving, so the fakeout cannot change what was already decided.
	var rewind_stages := PackedInt32Array()
	var rewind_offsets := PackedFloat32Array()
	if machine_focus.rewind_seconds.size() >= 3:
		var probe_reel := prototype.slot_panel.reel_window(2)
		if probe_reel != null:
			var total := machine_focus.tease_reel_stop_seconds
			for span in machine_focus.rewind_seconds:
				total += span
			var step := 0.02
			var sampled := 0.0
			while sampled < total:
				sampled += step
				var stage := machine_focus.get_rewind_stage()
				if stage != SlotMachine.RewindStage.NONE:
					if rewind_stages.is_empty() or rewind_stages[-1] != stage:
						rewind_stages.append(stage)
					rewind_offsets.append(prototype.slot_panel._reel_offset[2])
	_check(
		machine_focus.jackpot_rewind_chance > 0.0
		and machine_focus.rewind_seconds.size() == 3
		and SlotMachine.RewindStage.PASS < SlotMachine.RewindStage.HOLD
		and SlotMachine.RewindStage.HOLD < SlotMachine.RewindStage.SNAP,
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
		DisplaySettings.OptionId.FRIENDLY_EFFECTS,
		DisplaySettings.FriendlyEffects.QUARTER
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
		DisplaySettings.OptionId.ENEMY_TELEGRAPHS,
		DisplaySettings.EnemyTelegraphs.HIGH_CONTRAST
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
		DisplaySettings.OptionId.TERRITORY_DETAIL,
		DisplaySettings.TerritoryDetail.LOW
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
		DisplaySettings.OptionId.DAMAGE_NUMBERS,
		DisplaySettings.DamageNumbers.IMPORTANT_ONLY
	)
	var important_kept := settings.should_show_damage_number(true)
	var ordinary_dropped := not settings.should_show_damage_number(false)
	settings.set_choice(
		DisplaySettings.OptionId.DAMAGE_NUMBERS,
		DisplaySettings.DamageNumbers.OFF
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
	settings.set_choice(DisplaySettings.OptionId.UI_SCALE, 4)
	prototype._on_display_settings_changed()
	_check(
		is_equal_approx(prototype.interface_layer.transform.get_scale().x, 1.25)
		and prototype.territory_field.transform == arena_transform,
		"UI Scale scales the interface and leaves the battlefield alone"
	)

	# HUD Detail reveals more of the same layout rather than a second design, so the
	# same label carries more. The status line says nothing at rest now that the run
	# clock is gone, so Compact is silence and Detailed is the metabolism readout.
	settings.reset_settings()
	prototype._update_hud()
	var compact_status := prototype.status_label.text
	settings.set_choice(
		DisplaySettings.OptionId.HUD_DETAIL,
		DisplaySettings.HudDetail.DETAILED
	)
	prototype._update_hud()
	_check(
		compact_status.is_empty()
		and prototype.status_label.text.contains("MASS")
		and prototype.status_label.text.contains("HOLD"),
		"Detailed reveals more on the line Compact already had"
	)

	# Every option cycles through its own list and wraps, which is what makes one
	# button per row a complete control rather than a one-way ratchet.
	settings.reset_settings()
	var every_option_cycles := true
	for option_id in range(DisplaySettings.OptionId.size()):
		var count := DisplaySettings.get_choice_count(option_id)
		var opening := settings.get_choice(option_id)
		for _cycle_step in range(count):
			settings.cycle_choice(option_id)
		if settings.get_choice(option_id) != opening or count < 2:
			every_option_cycles = false
		if DisplaySettings.get_option_name(option_id).is_empty():
			every_option_cycles = false
	# Every option needs a control the player can actually reach, and this check used to
	# pass with an array of seven nulls: the controls were authored detached from the
	# pause panel and hidden, so the settings existed and nothing on screen drove them.
	var every_option_reachable := (
		prototype.pause_menu.setting_buttons.size() == 5
	)
	prototype._open_pause_menu()
	every_option_reachable = (
		every_option_reachable
		and prototype.pause_menu.settings_button != null
		and prototype.pause_menu.settings_button.is_visible_in_tree()
	)
	prototype.pause_menu.settings_button.pressed.emit()
	every_option_reachable = (
		every_option_reachable
		and prototype.pause_menu.settings_panel.visible
		and not prototype.pause_menu.panel.visible
	)
	for option_id in range(prototype.pause_menu.setting_buttons.size()):
		var setting_button := prototype.pause_menu.setting_buttons[option_id]
		if setting_button == null or not setting_button.is_visible_in_tree():
			every_option_reachable = false
			continue
		if setting_button.get_parent() != prototype.pause_menu.settings_panel:
			every_option_reachable = false
		# The row says its own name and its own value, and pressing it moves the value.
		var before_text := setting_button.text
		prototype.pause_menu._cycle_setting(option_id)
		if (
			setting_button.text == before_text
			or not setting_button.text.begins_with(
				DisplaySettings.get_option_name(option_id)
			)
		):
			every_option_reachable = false
	# The interface scale has to leave the screen where it is. A CanvasLayer scales
	# about its corner, so scaling the interface used to slide all of it toward one
	# corner - and the pause menu, which is centred by its own anchors, went with it.
	var pause_panel := prototype.pause_menu.resume_button.get_parent() as Control
	var screen_centre := prototype.get_viewport().get_visible_rect().size * 0.5
	var stays_centred := true
	for scale_choice in range(
		DisplaySettings.get_choice_count(DisplaySettings.OptionId.UI_SCALE)
	):
		settings.set_choice(DisplaySettings.OptionId.UI_SCALE, scale_choice)
		var drawn_centre: Vector2 = (
			prototype.interface_layer.transform * pause_panel.get_global_rect().get_center()
		)
		# Vertically the panel is authored a little below centre, and that offset scales
		# with everything else; horizontally there is nothing to excuse a drift.
		if absf(drawn_centre.x - screen_centre.x) > 1.0:
			stays_centred = false
		if absf(drawn_centre.y - screen_centre.y) > 20.0:
			stays_centred = false
	settings.set_choice(
		DisplaySettings.OptionId.UI_SCALE,
		DisplaySettings.get_choice_count(DisplaySettings.OptionId.UI_SCALE) / 2
	)
	prototype.pause_menu.settings_back_button.pressed.emit()
	every_option_reachable = (
		every_option_reachable
		and prototype.pause_menu.panel.visible
		and not prototype.pause_menu.settings_panel.visible
	)
	prototype._close_pause_menu()
	_check(
		stays_centred,
		"the pause menu stays centred at every interface scale"
	)

	_check(
		every_option_cycles
		and every_option_reachable,
		"every presentation option is named, cycles its own list, and has a control in "
			+ "the pause menu that moves it"
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

	# The Adaptation tree keeps each owned Adaptation's four authored lines together,
	# with the Evolution between the two Cores and the unearned Branch rows locked
	# beneath it.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.BRAMBLE,
		Progression.PathId.ROOT
	)
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT
	] = 3
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.ROOT_MATURE_STRENGTH
	] = 2
	prototype._apply_progression_modifiers()
	prototype._update_hud()
	var slot_row := prototype.upgrade_slots
	var filled_tooltip := slot_row.get_slot_tooltip(0)
	var empty_tooltip := slot_row.get_slot_tooltip(2)
	var locked_tooltip := prototype._evolution_upgrade_slot.get_slot_tooltip(0)
	var expected_slow := roundi(prototype.bramble_director.get_slow_fraction() * 100.0)
	_check(
		slot_row.get_slot_count() == 4
		and prototype._secondary_upgrade_slots.get_slot_count() == 4
		and prototype._evolution_upgrade_slot.get_slot_count() == 1
		and prototype._support_upgrade_slots.get_slot_count() == 4
		and prototype._branch_two_upgrade_slots.get_slot_count() == 4
		# Every row is named plainly; nothing marks one Adaptation over another.
		and prototype._path_one_label.text == "BRAMBLE"
		and prototype._path_two_label.text == "ROOT"
		and prototype._support_path_label.text == "BRANCH 1"
		and prototype._branch_two_label.text == "BRANCH 2"
		and prototype._support_path_emblem_lock.visible
		and prototype._branch_two_emblem_lock.visible
		and not prototype._support_path_emblem.visible
		and filled_tooltip.contains("Entanglement")
		and filled_tooltip.contains("3/3")
		and filled_tooltip.contains("up to %d%% slow" % expected_slow)
		and empty_tooltip.contains("Available on an upgrade draft")
		and locked_tooltip.contains("two lines in each Core"),
		"the Adaptation tree groups four lines per Adaptation and locks both Branches"
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
	prototype.progression._owned_relics[RelicCatalog.Id.GREEN_THUMB] = 1
	prototype._update_hud()
	var relic_tooltip := prototype.relic_slots.get_slot_tooltip(0)
	prototype.progression._owned_relics[RelicCatalog.Id.GREEN_THUMB] = 0
	_check(
		relic_tooltip.contains("Green Thumb")
		and relic_tooltip.contains(
			RelicCatalog.get_relic_description(RelicCatalog.Id.GREEN_THUMB)
		)
		and relic_tooltip.contains("COMMON"),
		"a held relic's hover carries its name, rarity, and what the relic actually does"
	)

	# A locked slot carries the icon and no text at all; an empty one keeps only its
	# marker.
	_check(
		slot_row.locked_icon != null
		and prototype._evolution_upgrade_slot.is_slot_locked_icon_visible(0)
		and prototype._support_upgrade_slots.is_slot_locked_icon_visible(0)
		and prototype._evolution_upgrade_slot.get_slot_level_text(0).is_empty()
		# A bought line reads against its own ceiling, so 2 of 3 is never mistaken
		# for a barely-started five-rank line. An unbought one keeps only its marker.
		and slot_row.get_slot_level_text(2).is_empty()
		and slot_row.get_slot_level_text(0) == "3/3",
		"a bought line shows its rank against a rank-3 ceiling and an empty one its marker"
	)

	# Upgrade order remains stable, and claiming the Evolution fills the central node
	# without touching either Branch row: Branches come from the Elite and the Boss,
	# never from evolving.
	var slotted_before := prototype.progression.get_slotted_upgrades()
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.ROOT_POTENCY
	] = 1
	var slotted_after := prototype.progression.get_slotted_upgrades()
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	prototype._apply_progression_modifiers()
	prototype._update_hud()
	var branch_tooltip := prototype._support_upgrade_slots.get_slot_tooltip(0)
	_check(
		slotted_after.size() == slotted_before.size() + 1
		and slotted_after[0] == slotted_before[0]
		and slotted_after[1] == slotted_before[1]
		and prototype._evolution_upgrade_slot.get_slot_level_text(0) == "1/5"
		and prototype._support_path_emblem_lock.visible
		and branch_tooltip.contains("Elite Rootbreaker"),
		"a line keeps its slot, and evolving never opens a Branch row"
	)

	# The tree's silhouette is stable: locked nodes unlock in place rather than
	# making the HUD jump when Evolution is claimed.
	_check(
		slot_row.get_slot_count() == 4
		and prototype._secondary_upgrade_slots.get_slot_count() == 4
		and prototype._support_upgrade_slots.get_slot_count() == 4,
		"the upgrade tree keeps its path-grouped silhouette as states unlock"
	)

	# What the editor authored is what the game prints. Each line is re-authored
	# here the way it would be re-typed on the node in the editor, the HUD is asked to
	# refresh, and the running label is read back: wording, spacing and which values
	# appear at all follow the scene rather than a format string in code.
	var authored_probes := [
		[prototype.slots_label, "LINES {filled} OF {total}"],
		[prototype.health_label, "VITALITY {current}"],
		[prototype.territory_label, "HELD {green} PERCENT"],
		[prototype.xp_label, "LVL {level}"],
		[prototype.hostile_label, "{hostiles} ENEMIES ABOUT"],
		[prototype.wave_label, "ROUND {wave}"],
	]
	var authored_reaches_game := true
	var authored_report := ""
	for probe: Array in authored_probes:
		var label: Label = probe[0]
		var authored: String = probe[1]
		prototype._authored.set_template(label, authored)
	prototype._on_health_changed(
		prototype.player.get_health(),
		prototype.player.maximum_health
	)
	prototype._on_xp_changed(
		prototype.progression.current_level,
		prototype.progression.current_xp,
		prototype.progression.get_required_xp()
	)
	prototype._on_territory_metrics_changed(
		prototype.territory_field.get_player_percent(), 0.0, 0.0, 0.0, 0
	)
	prototype._update_hud()
	for probe: Array in authored_probes:
		var label: Label = probe[0]
		var authored: String = probe[1]
		# Every word outside a placeholder has to survive verbatim, and no placeholder
		# may survive: one left as typed means nothing filled it in.
		var printed := label.text
		var intact := not printed.contains("{")
		for word in authored.split(" "):
			if word.begins_with("{"):
				continue
			intact = intact and printed.contains(word)
		if not intact:
			authored_reaches_game = false
			authored_report += " [%s authored %s, printed %s]" % [
				label.name, authored, printed
			]
	_check(
		authored_reaches_game,
		"wording authored in the editor reaches the running game:%s" % authored_report
	)
	# A placeholder the author deletes simply stops appearing, rather than shifting
	# every later value onto the wrong slot the way a positional format would.
	prototype._authored.set_template(prototype.slots_label, "UPGRADES")
	prototype._update_hud()
	_check(
		prototype.slots_label.text == "UPGRADES",
		"a line with no placeholders is printed exactly as authored"
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
	var rarity_named := prototype.choice_panel.buttons[0].text.contains(
		RelicCatalog.get_rarity_name(
			RelicCatalog.get_rarity(relic_offer[0])
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
	prototype._choice_kind = RunRoot.ChoiceKind.NONE
	prototype.choice_panel.visible = false

	# An offer may contain Plant relics and relics of Adaptations the run owns,
	# and nothing else. Ownership is the gate: a Clover jackpot lends an
	# Adaptation's behaviour for ten seconds and must not open its relic pool.
	prototype.progression.reset_progression()
	var plant_always := prototype.progression.is_relic_eligible(
		RelicCatalog.Id.GARDEN_HOSE
	)
	var unowned_locked := prototype.progression.is_relic_eligible(
		RelicCatalog.Id.THE_HEDGE
	)
	prototype.progression.debug_select_paths(
		Progression.PathId.BRAMBLE,
		Progression.PathId.PRUNING
	)
	var owned_unlocked := prototype.progression.is_relic_eligible(
		RelicCatalog.Id.THE_HEDGE
	)
	var still_unowned := prototype.progression.is_relic_eligible(
		RelicCatalog.Id.DOMINO_GERMINATION
	)
	prototype.progression.set_casino_path_active(Progression.PathId.SPORE, true)
	var borrowed_stays_locked := prototype.progression.is_relic_eligible(
		RelicCatalog.Id.DOMINO_GERMINATION
	)
	prototype.progression.set_casino_path_active(Progression.PathId.SPORE, false)
	_check(
		plant_always
		and not unowned_locked
		and owned_unlocked
		and not still_unowned
		and not borrowed_stays_locked,
		"relic eligibility is Plant plus owned Adaptations, and a jackpot loan never counts"
	)

	# Every pool is the shape the master document specifies, which the downward
	# rarity fallback in the offer roll relies on.
	var pool_grid := {}
	for catalog_relic in range(RelicCatalog.get_count()):
		var pool_key := RelicCatalog.get_pool(catalog_relic)
		var rarity_key := RelicCatalog.get_rarity(catalog_relic)
		if not pool_grid.has(pool_key):
			pool_grid[pool_key] = [0, 0, 0, 0]
		pool_grid[pool_key][rarity_key] += 1
	var pools_well_formed := pool_grid.size() == RelicCatalog.Pool.size()
	for pool_key in pool_grid:
		pools_well_formed = pools_well_formed and pool_grid[pool_key] == [3, 2, 2, 1]
	_check(
		RelicCatalog.get_count() == 72 and pools_well_formed,
		"the catalog holds 72 relics as nine pools of 3 Common, 2 Uncommon, 2 Rare, 1 Legendary"
	)

	# Rarity is rolled per offered slot and may only ever fall downward, so an
	# exhausted rarity can never manufacture a rarer relic than the odds produced.
	var fallback_candidates := PackedInt32Array([
		RelicCatalog.Id.GARDEN_HOSE,
		RelicCatalog.Id.MULCH,
	])
	var fell_downward := prototype.progression._draw_relic_of_rarity(
		fallback_candidates, RelicCatalog.Rarity.LEGENDARY
	)
	var exhausted := prototype.progression._draw_relic_of_rarity(
		PackedInt32Array(), RelicCatalog.Rarity.COMMON
	)
	var odds_sum := 0.0
	for share in prototype.progression.get_relic_rarity_odds():
		odds_sum += share
	_check(
		fallback_candidates.has(fell_downward)
		and exhausted == -1
		and is_equal_approx(odds_sum, 1.0),
		"a slot's rarity roll falls downward only, and the odds table is a whole probability"
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

	var lone_spot := _find_owned_cell_position(prototype)
	# Hard Husk: the first interruption is shrugged off entirely rather than
	# softened, so a Saboteur cannot chip a Seed down through the shield.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.HARD_HUSK] = 1
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
	prototype.progression._owned_relics[RelicCatalog.Id.HARD_HUSK] = 0
	relics.apply_relics()
	prototype.overlay.clear_effects()

	# Cross-Pollination advances nearby Seeds, and the receiving cooldown is what
	# stops a field of Seeds accelerating each other without end.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.CROSS_POLLINATION] = 1
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
	prototype.progression._owned_relics[RelicCatalog.Id.CROSS_POLLINATION] = 0
	prototype.overlay.clear_effects()

	# Puffball: a Seed broken before it opens is not wasted, and the Seedlings it
	# scatters can never Puffball again. That generation cap is the whole recursion
	# control, so it is asserted rather than assumed.
	var spore := prototype.spore_director
	spore.reset_director()
	prototype.overlay.clear_effects()
	prototype.progression._owned_relics[RelicCatalog.Id.PUFFBALL] = 1
	var puff_spot := _find_owned_cell_position(prototype)
	prototype.overlay.spawn_seed(puff_spot, 8.0, 0, 1.0)
	# Destroyed for real rather than by emitting the signal, so the wiring from a
	# Saboteur's hit through to the scatter is what the case actually covers.
	prototype.overlay.damage_nearest_catalyst(puff_spot, 30.0, 99.0)
	var puff_airborne := prototype.overlay.get_active_seed_count()
	for _puff_tick in range(60):
		spore.advance(1.0 / 60.0)
	var seedlings := prototype.overlay.get_seed_ids()
	# A Seedling breaking must not scatter a second generation.
	var second_generation := 0
	if seedlings.size() > 0:
		var seedling_position := prototype.overlay.get_seed_position(seedlings[0])
		prototype.overlay.damage_nearest_catalyst(seedling_position, 8.0, 99.0)
		for _settle in range(60):
			spore.advance(1.0 / 60.0)
		second_generation = prototype.overlay.get_seed_ids().size() - (seedlings.size() - 1)
	_check(
		puff_airborne == 0
		and seedlings.size() == spore.puffball_seedlings
		and second_generation <= 0,
		"PUFFBALL scatters Seedlings from a broken Seed and they cannot Puffball again"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.PUFFBALL] = 0

	# Windborne: every fifth germination throws Seeds at ground the run does not
	# hold. It is deliberately subcritical, so the count is what is asserted.
	spore.reset_director()
	prototype.overlay.clear_effects()
	prototype.progression._owned_relics[RelicCatalog.Id.WINDBORNE] = 1
	var wind_spot := _find_owned_cell_position(prototype)
	for germination in range(spore.windborne_germination_interval):
		spore._note_germination(wind_spot)
	var wind_pending := spore._pending_seeds.size()
	for _wind_tick in range(90):
		spore.advance(1.0 / 60.0)
	var wind_landed := prototype.overlay.get_active_seed_count()
	_check(
		wind_pending > 0
		and wind_pending <= spore.windborne_seeds
		and wind_landed == wind_pending,
		"WINDBORNE launches on its fifth germination and every Seed it throws lands"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.WINDBORNE] = 0

	# Volunteer: a death on Green a Seed has just made can plant another. The proc
	# roll is pinned so the test measures the rule and not the dice.
	spore.reset_director()
	prototype.overlay.clear_effects()
	prototype.progression._owned_relics[RelicCatalog.Id.VOLUNTEER] = 1
	var authored_volunteer_chance := spore.volunteer_chance
	spore.volunteer_chance = 1.0
	var volunteer_spot := _find_owned_cell_position(prototype)
	# A death with no recent germination behind it must plant nothing.
	spore._try_volunteer(volunteer_spot)
	var volunteer_without_green := spore._pending_seeds.size()
	spore._note_germination(volunteer_spot)
	spore._try_volunteer(volunteer_spot)
	var volunteer_after_green := spore._pending_seeds.size()
	# The global cooldown has to stop a pile of corpses planting a Seed each.
	spore._try_volunteer(volunteer_spot)
	var volunteer_on_cooldown := spore._pending_seeds.size()
	spore.volunteer_chance = authored_volunteer_chance
	_check(
		volunteer_without_green == 0
		and volunteer_after_green == 1
		and volunteer_on_cooldown == 1,
		"VOLUNTEER plants only on freshly germinated Green, and its cooldown holds"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.VOLUNTEER] = 0

	# Domino Germination: the tenth natural germination opens a cascade, and the
	# forced germinations inside it never advance the counter that made them.
	spore.reset_director()
	prototype.overlay.clear_effects()
	prototype.progression._owned_relics[RelicCatalog.Id.DOMINO_GERMINATION] = 1
	var domino_spot := _find_owned_cell_position(prototype)
	for _domino_seed in range(spore.domino_cascade_seeds + 2):
		prototype.overlay.spawn_seed(domino_spot, 20.0, 0, 1.0)
	var domino_before := prototype.overlay.get_active_seed_count()
	for _domino_germination in range(spore.domino_natural_germinations):
		spore._note_germination(domino_spot)
	var cascade_armed := spore._domino_cascade.size()
	for _domino_tick in range(120):
		spore.advance(1.0 / 60.0)
	var domino_after := prototype.overlay.get_active_seed_count()
	_check(
		cascade_armed == spore.domino_cascade_seeds
		and domino_before - domino_after == spore.domino_cascade_seeds
		and spore._domino_progress == 0
		and spore._domino_cascade.is_empty(),
		"DOMINO GERMINATION forces one capped cascade and its own links never refeed it"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.DOMINO_GERMINATION] = 0
	spore.reset_director()
	prototype.overlay.clear_effects()

	# ------------------------------------------------------------- Bloom relics
	# Every one of these is a rule about what a detonation is allowed to cause, so
	# each case asserts the rule and its recursion limiter rather than a number.
	var bloom_relics := prototype.bloom_director
	var bloom_spot := _find_owned_cell_position(prototype)

	# Deadheading: a bud killed during its wind-up still opens, at reduced strength,
	# and the emergency Bloom it leaves cannot Deadhead again.
	bloom_relics.reset_director()
	prototype.overlay.clear_effects()
	prototype.progression._owned_relics[RelicCatalog.Id.DEADHEADING] = 1
	prototype.overlay.plant_bloom(
		bloom_spot, 4.0, 0, 1.0, BloomDirector.SourceTag.NATURAL
	)
	prototype.overlay.damage_nearest_catalyst(bloom_spot, 30.0, 99.0)
	var deadheaded := bloom_relics._pending_detonations.size()
	var deadheaded_strength := 0.0
	if deadheaded > 0:
		deadheaded_strength = float(bloom_relics._pending_detonations[0][3])
	# An emergency Bloom must not be able to leave another one behind it.
	bloom_relics.on_bloom_interrupted(
		bloom_spot, BloomDirector.SourceTag.DEADHEADING, 1.0
	)
	var deadhead_recursed := bloom_relics._pending_detonations.size() - deadheaded
	_check(
		deadheaded == 1
		and is_equal_approx(deadheaded_strength, bloom_relics.deadheading_strength)
		and deadhead_recursed == 0,
		"DEADHEADING opens a broken bud at half strength and cannot Deadhead itself"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.DEADHEADING] = 0

	# Overkill: damage spent past an enemy's health banks, and the charge is spent
	# by the next natural Bloom rather than by the blast that filled the meter.
	bloom_relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.OVERKILL] = 1
	bloom_relics._bank_overkill(bloom_relics.overkill_required * 0.5)
	var half_charged := bloom_relics._overkill_charged
	bloom_relics._bank_overkill(bloom_relics.overkill_required * 0.5)
	var charged := bloom_relics._overkill_charged
	# A relic-planted Bloom is not what the charge was promised to.
	var spent_by_child := bloom_relics.try_spend_overkill(
		bloom_spot, BloomDirector.SourceTag.CHAIN
	)
	var spent_by_natural := bloom_relics.try_spend_overkill(
		bloom_spot, BloomDirector.SourceTag.NATURAL
	)
	var spent_twice := bloom_relics.try_spend_overkill(
		bloom_spot, BloomDirector.SourceTag.NATURAL
	)
	_check(
		not half_charged
		and charged
		and not spent_by_child
		and spent_by_natural
		and not spent_twice,
		"OVERKILL banks to a threshold and only a natural Bloom spends the charge"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.OVERKILL] = 0

	# Chain Bloom: enough kills plant one smaller child beyond the blast, and a
	# child can never plant another.
	bloom_relics.reset_director()
	prototype.overlay.clear_effects()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.CHAIN_BLOOM] = 1
	# A crowd well outside the blast for the child to aim at.
	for chain_index in range(6):
		prototype.combat.spawn_enemy(
			CombatDirector.EnemyRole.HUNTER,
			bloom_spot + Vector2(150.0 + float(chain_index) * 6.0, 0.0)
		)
	var chain_report := CombatDirector.BlastReport.new()
	chain_report.kills = bloom_relics.chain_bloom_kills
	bloom_relics._try_chain_bloom(
		bloom_spot, BloomDirector.SourceTag.NATURAL, 1.0, 60.0, chain_report
	)
	var chain_planted := prototype.overlay.get_active_bloom_count()
	bloom_relics._try_chain_bloom(
		bloom_spot, BloomDirector.SourceTag.CHAIN, 1.0, 60.0, chain_report
	)
	var chain_recursed := prototype.overlay.get_active_bloom_count() - chain_planted
	# Too few kills must plant nothing at all.
	var thin_report := CombatDirector.BlastReport.new()
	thin_report.kills = bloom_relics.chain_bloom_kills - 1
	bloom_relics._try_chain_bloom(
		bloom_spot, BloomDirector.SourceTag.NATURAL, 1.0, 60.0, thin_report
	)
	var chain_under_threshold := (
		prototype.overlay.get_active_bloom_count() - chain_planted - chain_recursed
	)
	_check(
		chain_planted == 1 and chain_recursed == 0 and chain_under_threshold == 0,
		"CHAIN BLOOM plants one child on enough kills and a child cannot chain again"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.CHAIN_BLOOM] = 0

	# Flowering Front: a natural Bloom that kills enough starts a chain that walks
	# forward and stops at its authored generation cap.
	bloom_relics.reset_director()
	prototype.overlay.clear_effects()
	prototype.progression._owned_relics[RelicCatalog.Id.FLOWERING_FRONT] = 1
	var front_report := CombatDirector.BlastReport.new()
	front_report.kills = bloom_relics.flowering_front_starter_kills
	var front_started := bloom_relics._try_flowering_front(
		bloom_spot, BloomDirector.SourceTag.NATURAL, 1.0, front_report
	)
	# Walk the chain to its cap. Each child is cleared off the field first so the
	# bud cap is not what stops it: the generation cap has to be what does.
	var generations := 1
	for _front_step in range(bloom_relics.flowering_front_generations + 3):
		prototype.overlay.clear_effects()
		if not bloom_relics._try_flowering_front(
			bloom_spot, BloomDirector.SourceTag.FLOWERING_FRONT, 1.0, front_report
		):
			break
		generations += 1
	var front_cooled := bloom_relics._front_cooldown > 0.0
	_check(
		front_started
		and generations == bloom_relics.flowering_front_generations
		and front_cooled,
		"FLOWERING FRONT walks a chain to its generation cap and then cools down"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.FLOWERING_FRONT] = 0

	# Petal Scatter: one petal per kill, thrown only at enemies the blast missed.
	bloom_relics.reset_director()
	prototype.overlay.clear_effects()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.PETAL_SCATTER] = 1
	# One enemy inside the blast radius and two outside it.
	prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER, bloom_spot + Vector2(20.0, 0.0)
	)
	for petal_index in range(2):
		prototype.combat.spawn_enemy(
			CombatDirector.EnemyRole.HUNTER,
			bloom_spot + Vector2(120.0, float(petal_index) * 30.0)
		)
	var petal_report := CombatDirector.BlastReport.new()
	petal_report.kills = 3
	petal_report.kill_positions = PackedVector2Array([bloom_spot, bloom_spot, bloom_spot])
	bloom_relics._scatter_petals(bloom_spot, 60.0, 100.0, petal_report)
	var petals_thrown := bloom_relics._petals.size()
	_check(
		petals_thrown == 2,
		"PETAL SCATTER throws one petal per kill and only at enemies outside the blast (%d)"
			% petals_thrown
	)
	prototype.progression._owned_relics[RelicCatalog.Id.PETAL_SCATTER] = 0
	bloom_relics.reset_director()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()

	# ----------------------------------------------------------- Bramble relics
	# The pool's engine is Entanglement feeding itself, so each case asserts both
	# that the rule fires and that the limiter which stops it looping holds.
	var bramble := prototype.bramble_director
	var bramble_spot := _find_owned_cell_position(prototype)

	# Hookthorn: a shoved enemy that collides with another tangles both, once per
	# shove, and then both sit on a cooldown.
	bramble.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.HOOKTHORN] = 1
	var shoved_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER, bramble_spot
	)
	var struck_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
		bramble_spot + Vector2(bramble.hookthorn_collision_pixels * 0.5, 0.0)
	)
	prototype.combat.enemy_repelled.emit(shoved_id, bramble_spot, Vector2.RIGHT)
	bramble.advance_relics(1.0 / 60.0)
	var hook_shoved := prototype.combat.get_enemy_entanglement(shoved_id)
	var hook_struck := prototype.combat.get_enemy_entanglement(struck_id)
	# The window closed on the collision, so a second tick must add nothing.
	bramble.advance_relics(1.0 / 60.0)
	var hook_no_repeat := is_equal_approx(
		prototype.combat.get_enemy_entanglement(struck_id), hook_struck
	)
	_check(
		hook_shoved > 0.0 and hook_struck > hook_shoved and hook_no_repeat,
		"HOOKTHORN tangles both bodies once per shove and cannot retrigger from it"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.HOOKTHORN] = 0

	# Thornback: a shove makes the Green shoot a thorn at the least tangled enemy
	# other than the one that was shoved.
	bramble.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.THORNBACK] = 1
	var thorn_source := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER, bramble_spot
	)
	var thorn_target := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER, bramble_spot + Vector2(90.0, 0.0)
	)
	var thorn_health_before := prototype.combat.get_enemy_health(thorn_target)
	prototype.combat.enemy_repelled.emit(thorn_source, bramble_spot, Vector2.RIGHT)
	var thorn_hit := prototype.combat.get_enemy_health(thorn_target) < thorn_health_before
	var thorn_tangled := prototype.combat.get_enemy_entanglement(thorn_target) > 0.0
	# The per-source cooldown has to stop a grazing cadence firing a stream of them.
	var health_after_first := prototype.combat.get_enemy_health(thorn_target)
	prototype.combat.enemy_repelled.emit(thorn_source, bramble_spot, Vector2.RIGHT)
	var thorn_on_cooldown := is_equal_approx(
		prototype.combat.get_enemy_health(thorn_target), health_after_first
	)
	_check(
		thorn_hit and thorn_tangled and thorn_on_cooldown,
		"THORNBACK shoots one thorn per shove and its source cooldown holds"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.THORNBACK] = 0

	# Cocklebur: only an enemy that leaves Green heavily Entangled carries burrs,
	# and leaving again does not refresh the timer.
	bramble.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.COCKLEBUR] = 1
	var carrier_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER, bramble_spot
	)
	prototype.combat.enemy_left_green.emit(
		carrier_id, bramble_spot, bramble.cocklebur_minimum_entanglement - 0.1
	)
	var burr_under_threshold := bramble.get_burr_carrier_count()
	prototype.combat.enemy_left_green.emit(
		carrier_id, bramble_spot, bramble.cocklebur_minimum_entanglement
	)
	var burr_carried := bramble.get_burr_carrier_count()
	# A carrier spreads Entanglement by touch, and only to bodies it has not
	# already burred.
	var burr_target := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
		bramble_spot + Vector2(bramble.cocklebur_contact_pixels * 0.5, 0.0)
	)
	bramble.advance_relics(1.0 / 60.0)
	var burr_spread := prototype.combat.get_enemy_entanglement(burr_target)
	bramble.advance_relics(1.0 / 60.0)
	var burr_capped := is_equal_approx(
		prototype.combat.get_enemy_entanglement(burr_target), burr_spread
	)
	_check(
		burr_under_threshold == 0 and burr_carried == 1 and burr_spread > 0.0 and burr_capped,
		"COCKLEBUR burrs only a heavily Entangled leaver and respects its touch cooldown"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.COCKLEBUR] = 0

	# Briar Knot: a heavily Entangled corpse leaves a one-use trap, and the active
	# cap replaces the oldest rather than refusing the newest.
	bramble.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.BRIAR_KNOT] = 1
	prototype.combat.enemy_died_entangled.emit(
		bramble_spot,
		bramble.briar_knot_required_entanglement - 0.1,
		CombatDirector.EnemyRole.HUNTER
	)
	var knot_under_threshold := bramble.get_knot_count()
	for knot_index in range(bramble.briar_knot_maximum + 3):
		prototype.combat.enemy_died_entangled.emit(
			bramble_spot + Vector2(float(knot_index) * 400.0, 0.0),
			1.0,
			CombatDirector.EnemyRole.HUNTER
		)
	var knots_capped := bramble.get_knot_count()
	# One use: an enemy walking into a Knot springs it and the Knot is gone.
	bramble.reset_director()
	prototype.combat.enemy_died_entangled.emit(
		bramble_spot, 1.0, CombatDirector.EnemyRole.HUNTER
	)
	var caught_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER, bramble_spot
	)
	for _knot_tick in range(30):
		bramble.advance_relics(1.0 / 60.0)
	_check(
		knot_under_threshold == 0
		and knots_capped == bramble.briar_knot_maximum
		and bramble.get_knot_count() == 0
		and prototype.combat.get_enemy_entanglement(caught_id) > 0.0,
		"BRIAR KNOT arms on a tangled corpse, caps its count, and springs exactly once"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.BRIAR_KNOT] = 0

	# Briarball: four heavily Entangled deaths roll into one ball, and the active
	# cap preserves a completed charge rather than spending it into nothing.
	bramble.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.BRIARBALL] = 1
	for _ball_death in range(bramble.briarball_deaths_required - 1):
		prototype.combat.enemy_died_entangled.emit(
			bramble_spot, 1.0, CombatDirector.EnemyRole.HUNTER
		)
	var ball_under_charge := bramble.get_briarball_count()
	prototype.combat.enemy_died_entangled.emit(
		bramble_spot, 1.0, CombatDirector.EnemyRole.HUNTER
	)
	var ball_rolled := bramble.get_briarball_count()
	# A ball damages and tangles what it rolls over.
	var rolled_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
		bramble_spot + Vector2(bramble.briarball_contact_pixels * 0.5, 0.0)
	)
	var rolled_health := prototype.combat.get_enemy_health(rolled_id)
	bramble.advance_relics(1.0 / 60.0)
	_check(
		ball_under_charge == 0
		and ball_rolled == 1
		and prototype.combat.get_enemy_health(rolled_id) < rolled_health
		and prototype.combat.get_enemy_entanglement(rolled_id) > 0.0,
		"BRIARBALL rolls on its fourth tangled corpse and crashes through the crowd"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.BRIARBALL] = 0
	bramble.reset_director()
	prototype.combat.reset_combat()

	# ----------------------------------------------------------- Pruning relics
	# Pruning's pool turns one release into a cycle, so every case here asserts the
	# limiter as well as the payout: an unbounded Pruning build is the failure mode.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.PRUNING,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	var pruning_relics := prototype.pruning_director
	var prune_spot := _find_owned_cell_position(prototype)
	prototype.player.global_position = prototype.territory_field.to_global(prune_spot)

	# Brush Pile: only Green cut past half Charge is stored, the bundle count is
	# capped, and a release empties the store whether or not it was full.
	pruning_relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.BRUSH_PILE] = 1
	pruning_relics._charge = pruning_relics.brush_pile_charge_threshold - 0.1
	pruning_relics._note_brush_harvest(pruning_relics.brush_pile_cells_per_bundle * 2)
	var brush_below_threshold := pruning_relics.get_brush_bundles()
	pruning_relics._charge = pruning_relics.brush_pile_charge_threshold
	pruning_relics._note_brush_harvest(
		pruning_relics.brush_pile_cells_per_bundle * (pruning_relics.brush_pile_maximum_bundles + 3)
	)
	var brush_capped := pruning_relics.get_brush_bundles()
	_check(
		brush_below_threshold == 0
		and brush_capped == pruning_relics.brush_pile_maximum_bundles,
		"BRUSH PILE stores only what is cut past half Charge and stops at its cap"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.BRUSH_PILE] = 0

	# Callus: standing in the wound when the ring fires is not returning to it. The
	# player has to leave and come back before the pulse is owed.
	pruning_relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.CALLUS] = 1
	pruning_relics._callus_position = prune_spot
	pruning_relics._callus_remaining = pruning_relics.callus_window_seconds
	pruning_relics._callus_used = false
	pruning_relics._callus_left_wound = false
	prototype.player.global_position = prototype.territory_field.to_global(prune_spot)
	pruning_relics._advance_callus(1.0 / 60.0)
	var callus_standing_still := pruning_relics._callus_used
	# Leave the wound, then come back.
	prototype.player.global_position = prototype.territory_field.to_global(
		prune_spot + Vector2(pruning_relics.callus_radius_pixels * 2.0, 0.0)
	)
	pruning_relics._advance_callus(1.0 / 60.0)
	prototype.player.global_position = prototype.territory_field.to_global(prune_spot)
	pruning_relics._advance_callus(1.0 / 60.0)
	var callus_paid := pruning_relics._callus_used
	# One pulse per release: a second return is worth nothing.
	pruning_relics._advance_callus(1.0 / 60.0)
	_check(
		not callus_standing_still and callus_paid and not pruning_relics.is_callus_armed(),
		"CALLUS pays once, and only after the player has actually left the wound"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.CALLUS] = 0

	# Stubble: the wound stays sharp, each enemy is on its own tick cooldown, and
	# only two wounds are ever hazardous at once.
	pruning_relics.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.STUBBLE] = 1
	for stubble_wound_index in range(pruning_relics.stubble_maximum_wounds + 2):
		pruning_relics._stubble_wounds.append([
			prune_spot + Vector2(float(stubble_wound_index) * 500.0, 0.0),
			pruning_relics.stubble_seconds,
			{},
		])
		if pruning_relics._stubble_wounds.size() > pruning_relics.stubble_maximum_wounds:
			pruning_relics._stubble_wounds.remove_at(0)
	var stubble_capped := pruning_relics.get_stubble_wound_count()
	# A wound expires rather than lingering.
	for _stubble_tick in range(int(pruning_relics.stubble_seconds * 60.0) + 10):
		pruning_relics._advance_stubble(1.0 / 60.0)
	_check(
		stubble_capped == pruning_relics.stubble_maximum_wounds
		and pruning_relics.get_stubble_wound_count() == 0,
		"STUBBLE keeps at most two sharp wounds and each one expires on its own clock"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.STUBBLE] = 0

	# Skimming Cut: a natural spike glances off terrain toward a new target once,
	# and a spike that has already glanced is spent by its next collision.
	pruning_relics.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.SKIMMING_CUT] = 1
	prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER, prune_spot + Vector2(60.0, 0.0)
	)
	var skimmer := pruning_relics._get_inactive_cutting()
	skimmer.position = prune_spot
	skimmer.damage = 40.0
	skimmer.velocity = Vector2(200.0, 0.0)
	skimmer.natural_release = true
	skimmer.has_ricocheted = false
	var skimmed := pruning_relics._try_skimming_cut(skimmer)
	var skim_damage_cut := skimmer.damage < 40.0
	var skim_again := pruning_relics._try_skimming_cut(skimmer)
	# A relic-thrown spike is not a natural release and never glances.
	var relic_spike := pruning_relics._get_inactive_cutting()
	relic_spike.position = prune_spot
	relic_spike.damage = 40.0
	relic_spike.velocity = Vector2(200.0, 0.0)
	relic_spike.natural_release = false
	var relic_skimmed := pruning_relics._try_skimming_cut(relic_spike)
	_check(
		skimmed and skim_damage_cut and not skim_again and not relic_skimmed,
		"SKIMMING CUT redirects a natural spike once and never a relic-thrown one"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.SKIMMING_CUT] = 0

	# Watersprouts: a natural killing spike sprouts children, those children may
	# branch once more, and generation two is the end of it.
	pruning_relics.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.WATERSPROUTS] = 1
	for sprout_index in range(8):
		prototype.combat.spawn_enemy(
			CombatDirector.EnemyRole.HUNTER,
			prune_spot + Vector2(40.0 + float(sprout_index) * 12.0, 0.0)
		)
	var parent := pruning_relics._get_inactive_cutting()
	parent.position = prune_spot
	parent.damage = 40.0
	parent.natural_release = true
	parent.sprout_generation = 0
	pruning_relics._sprout_watersprouts(parent, prune_spot)
	var generation_one := pruning_relics._watersprouts_this_release
	# A generation-2 spike must not reproduce at all.
	var final_child := pruning_relics._get_inactive_cutting()
	final_child.position = prune_spot
	final_child.damage = 20.0
	final_child.natural_release = false
	final_child.sprout_generation = 2
	pruning_relics._sprout_watersprouts(final_child, prune_spot)
	var after_final := pruning_relics._watersprouts_this_release
	# The per-release cap is absolute across both generations.
	pruning_relics._watersprouts_this_release = pruning_relics.watersprout_release_maximum
	pruning_relics._sprout_watersprouts(parent, prune_spot)
	var at_cap := pruning_relics._watersprouts_this_release
	_check(
		generation_one == pruning_relics.watersprout_children
		and after_final == generation_one
		and at_cap == pruning_relics.watersprout_release_maximum,
		"WATERSPROUTS branches twice, stops at generation two, and honours its release cap"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.WATERSPROUTS] = 0
	pruning_relics.reset_director()
	prototype.combat.reset_combat()
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()

	# ----------------------------------------------------------- Thistle relics
	# The network's counters are the whole safety story: a bonus thorn that advanced
	# the counter that produced it would make the turrets fire forever. Every case
	# below asserts that separation as well as the payout.
	prototype.progression.debug_select_paths(
		Progression.PathId.THISTLE,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	var adaptation := prototype.adaptation_director
	var thistle_spot := _find_owned_cell_position(prototype)

	# Only a natural thorn advances a network counter.
	adaptation.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.THORN_RELAY] = 1
	prototype.progression._owned_relics[RelicCatalog.Id.FORKING_PATTERN] = 1
	var bonus_thorn := AdaptationDirector.ThornState.new()
	bonus_thorn.source_tag = AdaptationDirector.ThornSource.CROWN
	for _bonus_impact in range(
		maxi(adaptation.thorn_relay_impacts, adaptation.forking_pattern_impacts) * 2
	):
		adaptation._note_natural_thorn_impact(bonus_thorn, -1, thistle_spot, false)
	var counters_untouched := (
		adaptation._relay_impacts == 0 and adaptation._forking_impacts == 0
	)
	var natural_thorn := AdaptationDirector.ThornState.new()
	natural_thorn.source_tag = AdaptationDirector.ThornSource.NATURAL
	natural_thorn.source_thistle_sequence = -1
	for _natural_impact in range(adaptation.thorn_relay_impacts - 1):
		adaptation._note_natural_thorn_impact(natural_thorn, -1, thistle_spot, false)
	var counted_naturals := adaptation._relay_impacts
	_check(
		counters_untouched and counted_naturals == adaptation.thorn_relay_impacts - 1,
		"a relic-fired thorn never advances a Thistle network counter, and a natural one does"
	)

	# Thorn Relay: the counter resets on its threshold, and the rate limiter holds.
	adaptation._relay_impacts = adaptation.thorn_relay_impacts - 1
	adaptation._relay_cooldown = 0.0
	adaptation._note_natural_thorn_impact(natural_thorn, -1, thistle_spot, false)
	var relay_reset := adaptation._relay_impacts
	_check(
		relay_reset == 0,
		"THORN RELAY answers on its eighth natural impact and starts counting again"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.THORN_RELAY] = 0

	# Forking Pattern: the active-thorn cap bounds it, and a split thorn cannot
	# advance the counter that split it.
	adaptation._forking_impacts = 0
	adaptation._forking_cooldown = 0.0
	var forked_thorn := AdaptationDirector.ThornState.new()
	forked_thorn.source_tag = AdaptationDirector.ThornSource.FORKING
	for _forked_impact in range(adaptation.forking_pattern_impacts * 2):
		adaptation._note_natural_thorn_impact(forked_thorn, -1, thistle_spot, false)
	_check(
		adaptation._forking_impacts == 0,
		"FORKING PATTERN branches cannot advance Forking Pattern"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.FORKING_PATTERN] = 0

	# Pincushion: stacks come only from the thorns the relic names, they cap at the
	# threshold, and the burst spends them.
	adaptation.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.PINCUSHION] = 1
	var pincushion_victim := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER, thistle_spot
	)
	var ineligible_thorn := AdaptationDirector.ThornState.new()
	ineligible_thorn.source_tag = AdaptationDirector.ThornSource.PHYLLOTAXIS
	for _ineligible in range(adaptation.pincushion_threshold):
		adaptation._add_pincushion_stack(pincushion_victim, ineligible_thorn)
	var stacks_from_ineligible := adaptation._pincushion_stacks.size()
	for _eligible in range(adaptation.pincushion_threshold + 4):
		adaptation._add_pincushion_stack(pincushion_victim, natural_thorn)
	var pincushion_stack: Array = adaptation._pincushion_stacks[pincushion_victim]
	var stacks_capped := int(pincushion_stack[0])
	adaptation._burst_pincushion(pincushion_victim, thistle_spot)
	var stacks_spent := not adaptation._pincushion_stacks.has(pincushion_victim)
	_check(
		stacks_from_ineligible == 0
		and stacks_capped == adaptation.pincushion_threshold
		and stacks_spent,
		"PINCUSHION embeds only qualifying thorns, caps the stack, and spends it on death"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.PINCUSHION] = 0

	# Answering Thorn: a natural kill makes a different turret answer, on a shared
	# cooldown, and a relic-fired kill never starts it.
	adaptation.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.ANSWERING_THORN] = 1
	adaptation._answering_cooldown = 0.0
	adaptation._answer_thorn(bonus_thorn, thistle_spot)
	var answered_by_relic := adaptation._answering_cooldown > 0.0
	adaptation._answer_thorn(natural_thorn, thistle_spot)
	var answered_by_natural := adaptation._answering_cooldown > 0.0
	_check(
		not answered_by_relic and answered_by_natural,
		"ANSWERING THORN is started by a natural volley's kill and never by a relic's"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.ANSWERING_THORN] = 0

	# Rosette: a newly grown permanent Thistle is owed one opening volley, and a
	# temporary turret is owed nothing.
	adaptation.reset_adaptations()
	prototype.progression._owned_relics[RelicCatalog.Id.ROSETTE] = 1
	adaptation._plant_thistle(false, 5.0)
	var rosette_for_temporary := adaptation._rosette_queue.size()
	adaptation._plant_thistle(true, 0.0)
	var rosette_for_permanent := adaptation._rosette_queue.size()
	for _rosette_tick in range(int(adaptation.rosette_delay_seconds * 60.0) + 6):
		adaptation._advance_thistle_relics(1.0 / 60.0)
	_check(
		rosette_for_temporary == 0
		and rosette_for_permanent == 1
		and adaptation._rosette_queue.is_empty(),
		"ROSETTE owes an opening volley to a new permanent Thistle only, and pays it once"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.ROSETTE] = 0
	adaptation.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()

	# ------------------------------------------------------------- Fruit relics
	# Fruit's pool keeps kinetic energy alive, so the caps are the safety story:
	# an unbounded Newton's Apple in a crowd is the failure this guards.
	prototype.progression.debug_select_paths(
		Progression.PathId.FRUIT,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	adaptation.reset_adaptations()
	prototype.combat.reset_combat()
	var fruit_spot := _find_owned_cell_position(prototype)

	# Stem Steering: a Fruit curves toward a new target while keeping every bit of
	# its speed, and only twice.
	prototype.progression._owned_relics[RelicCatalog.Id.STEM_STEERING] = 1
	var steered := AdaptationDirector.FruitState.new()
	steered.position = fruit_spot
	steered.speed = 300.0
	steered.base_speed = 300.0
	steered.last_direction = Vector2.RIGHT
	steered.velocity = Vector2.RIGHT * 300.0
	var steer_victim := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER, fruit_spot + Vector2(40.0, 90.0)
	)
	adaptation._try_stem_steering(steered, -1)
	var steer_turned := not steered.last_direction.is_equal_approx(Vector2.RIGHT)
	var steer_kept_speed := is_equal_approx(steered.speed, 300.0)
	adaptation._try_stem_steering(steered, -1)
	adaptation._try_stem_steering(steered, -1)
	_check(
		steer_turned
		and steer_kept_speed
		and steered.steering_uses == adaptation.stem_steering_uses,
		"STEM STEERING curves a Fruit without adding speed and stops at two uses"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.STEM_STEERING] = 0

	# Windfall: a kill restores speed up to its ceiling and redirects, three times.
	prototype.progression._owned_relics[RelicCatalog.Id.WINDFALL] = 1
	var windfallen := AdaptationDirector.FruitState.new()
	windfallen.position = fruit_spot
	windfallen.speed = 100.0
	windfallen.base_speed = 300.0
	windfallen.last_direction = Vector2.RIGHT
	windfallen.velocity = Vector2.RIGHT * 100.0
	adaptation._try_windfall(windfallen, -1)
	var windfall_restored := windfallen.speed > 100.0
	# Drive it past the ceiling: speed must clamp rather than run away.
	for _windfall_use in range(adaptation.windfall_uses + 3):
		windfallen.windfall_cooldown = 0.0
		adaptation._try_windfall(windfallen, -1)
	var windfall_capped := (
		windfallen.speed
		<= windfallen.base_speed * adaptation.windfall_maximum_speed_share + 0.001
	)
	_check(
		windfall_restored
		and windfall_capped
		and windfallen.windfall_uses == adaptation.windfall_uses,
		"WINDFALL restores speed to a ceiling and spends exactly three uses per Fruit"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.WINDFALL] = 0

	# Fruit Salad: two different Fruit of the same release burst the target; the
	# same Fruit hitting twice, or a Fruit from another release, does not.
	prototype.progression._owned_relics[RelicCatalog.Id.FRUIT_SALAD] = 1
	adaptation._fruit_salad_marks.clear()
	var salad_victim := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HEAVY_GRAZER, fruit_spot
	)
	var first_fruit := AdaptationDirector.FruitState.new()
	first_fruit.release_id = 7
	first_fruit.fruit_id = 1
	first_fruit.damage = 40.0
	adaptation._try_fruit_salad(first_fruit, salad_victim)
	var salad_marked := adaptation._fruit_salad_marks.has(salad_victim)
	# The same Fruit again is not two Fruit.
	adaptation._try_fruit_salad(first_fruit, salad_victim)
	var salad_same_fruit := adaptation._fruit_salad_marks.has(salad_victim)
	var salad_health_before := prototype.combat.get_enemy_health(salad_victim)
	var second_fruit := AdaptationDirector.FruitState.new()
	second_fruit.release_id = 7
	second_fruit.fruit_id = 2
	second_fruit.damage = 40.0
	adaptation._try_fruit_salad(second_fruit, salad_victim)
	var salad_burst := prototype.combat.get_enemy_health(salad_victim) < salad_health_before
	_check(
		salad_marked
		and salad_same_fruit
		and salad_burst
		and not adaptation._fruit_salad_marks.has(salad_victim),
		"FRUIT SALAD bursts only on a second, different Fruit from the same release"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.FRUIT_SALAD] = 0

	# Newton's Apple: three starters per Fruit, a hard global body cap, and only an
	# ordinary enemy is ever launched.
	prototype.progression._owned_relics[RelicCatalog.Id.NEWTONS_APPLE] = 1
	adaptation._falling_bodies.clear()
	prototype.combat.reset_combat()
	for newton_index in range(12):
		prototype.combat.spawn_enemy(
			CombatDirector.EnemyRole.HUNTER,
			fruit_spot + Vector2(float(newton_index) * 18.0, 0.0)
		)
	var newton_boss_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.BOSS, fruit_spot + Vector2(0.0, 60.0)
	)
	var thrower := AdaptationDirector.FruitState.new()
	thrower.position = fruit_spot
	thrower.damage = 36.0
	thrower.knockback = 38.0
	# A boss is struck by Falling Bodies but is never launched as one.
	adaptation._try_newtons_apple(thrower, newton_boss_id)
	var boss_launched := adaptation._falling_bodies.size()
	var newton_enemies := prototype.combat.get_active_enemy_ids()
	for starter_index in range(adaptation.newton_starters_per_fruit + 3):
		thrower.newton_cooldown = 0.0
		if starter_index < newton_enemies.size():
			adaptation._try_newtons_apple(thrower, newton_enemies[starter_index])
	var starters_spent := thrower.newton_starters
	# The global cap holds regardless of how many Fruit are asking.
	var another := AdaptationDirector.FruitState.new()
	another.position = fruit_spot
	another.damage = 36.0
	another.knockback = 38.0
	for overflow_index in range(newton_enemies.size()):
		another.newton_cooldown = 0.0
		another.newton_starters = 0
		adaptation._try_newtons_apple(another, newton_enemies[overflow_index])
	_check(
		boss_launched == 0
		and starters_spent == adaptation.newton_starters_per_fruit
		and adaptation._falling_bodies.size() <= adaptation.newton_active_maximum,
		"NEWTON'S APPLE launches only ordinary enemies and holds its starter and body caps"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.NEWTONS_APPLE] = 0

	# Bruised Fruit: a collision makes the trail wider for a fixed distance of
	# travel, and refreshing it never stacks the multiplier.
	prototype.progression._owned_relics[RelicCatalog.Id.BRUISED_FRUIT] = 1
	var bruised := AdaptationDirector.FruitState.new()
	bruised.juicy_remaining = adaptation.bruised_fruit_distance_pixels
	var juicy_first := bruised.juicy_remaining
	bruised.juicy_remaining = maxf(
		0.0, bruised.juicy_remaining - adaptation.bruised_fruit_distance_pixels * 0.5
	)
	var juicy_spent := bruised.juicy_remaining < juicy_first
	bruised.juicy_remaining = adaptation.bruised_fruit_distance_pixels
	_check(
		juicy_spent
		and is_equal_approx(
			bruised.juicy_remaining, adaptation.bruised_fruit_distance_pixels
		),
		"BRUISED FRUIT is spent by travel and a refresh restores it without stacking"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.BRUISED_FRUIT] = 0
	adaptation.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()

	# A long relic description wraps inside its card instead of widening it. A
	# Button's minimum width otherwise includes the whole unwrapped line, so the
	# longest relic in the catalog was pushing the reward box past its own panel.
	prototype.progression.reset_progression()
	var widest_relic := 0
	for catalog_id in range(RelicCatalog.get_count()):
		if (
			RelicCatalog.get_relic_description(catalog_id).length()
			> RelicCatalog.get_relic_description(widest_relic).length()
		):
			widest_relic = catalog_id
	prototype._show_choice(
		RunRoot.ChoiceKind.RELIC, PackedInt32Array([widest_relic])
	)
	# The card has to lay out before its size means anything.
	await process_frame
	await process_frame
	var relic_card := prototype.choice_panel.button_one
	var card_fits := (
		relic_card.size.x <= prototype.choice_panel.size.x
		and relic_card.get_combined_minimum_size().x <= prototype.choice_panel.size.x
	)
	var wraps := relic_card.autowrap_mode != TextServer.AUTOWRAP_OFF
	prototype._choice_kind = RunRoot.ChoiceKind.NONE
	prototype._choice_ids.clear()
	prototype.choice_panel.visible = false
	_check(
		wraps and card_fits,
		"a long relic description wraps inside its card rather than widening the box"
	)

	# The tray has to hold a whole run's relics. Campaign awards twelve, so a row
	# that stopped at six was hiding half of what the player had earned.
	prototype.progression.reset_progression()
	var campaign_relic_target := 14
	for tray_relic in range(campaign_relic_target):
		prototype.progression._owned_relics[tray_relic] = 1
	prototype._update_relic_slots()
	var shown := prototype.relic_slots.get_slot_count()
	var every_relic_named := true
	for tray_index in range(campaign_relic_target):
		if prototype.relic_slots.get_slot_tooltip(tray_index).is_empty():
			every_relic_named = false
			break
	prototype.progression.reset_progression()
	prototype._update_relic_slots()
	_check(
		shown >= campaign_relic_target and every_relic_named,
		"the relic tray shows a whole run's relics rather than stopping at six (%d)"
			% shown
	)

	# --------------------------------------------------------------- Relic VFX
	# Two of the document's VFX rules are mechanical rather than artistic, so they
	# are enforced in code and checked here: a generated echo is drawn weaker than
	# what caused it, and same-frame accents are spread so a chain reads in order.
	prototype.overlay.clear_relic_cues()
	prototype.overlay.spawn_relic_cue(
		TerritoryPrototypeOverlay.RelicCue.GHOST, Vector2(100.0, 100.0), 40.0, Color.WHITE
	)
	var natural_intensity := prototype.overlay.get_last_relic_cue_intensity()
	var first_lead_in := prototype.overlay.get_last_relic_cue_lead_in()
	prototype.overlay.spawn_relic_cue(
		TerritoryPrototypeOverlay.RelicCue.GHOST,
		Vector2(100.0, 100.0),
		40.0,
		Color.WHITE,
		Vector2.ZERO,
		true
	)
	var echo_intensity := prototype.overlay.get_last_relic_cue_intensity()
	var second_lead_in := prototype.overlay.get_last_relic_cue_lead_in()
	# An echo of an echo can only get quieter: intensity is held under its source.
	prototype.overlay.spawn_relic_cue(
		TerritoryPrototypeOverlay.RelicCue.GHOST,
		Vector2(100.0, 100.0),
		40.0,
		Color.WHITE,
		Vector2.ZERO,
		true,
		echo_intensity
	)
	var nested_echo := prototype.overlay.get_last_relic_cue_intensity()
	_check(
		is_equal_approx(natural_intensity, 1.0)
		and echo_intensity >= prototype.overlay.echo_intensity_minimum - 0.001
		and echo_intensity <= prototype.overlay.echo_intensity_maximum + 0.001
		and nested_echo <= echo_intensity + 0.001
		and is_equal_approx(first_lead_in, 0.0)
		and second_lead_in >= prototype.overlay.cue_stagger_seconds - 0.001,
		"a relic echo is drawn weaker than its source and same-frame accents are staggered"
	)
	# Spin is what carries the effects whose identity is rotation. It accumulates
	# with the cue's age rather than with its progress, so a long-lived cue keeps
	# turning instead of easing to a stop halfway through.
	prototype.overlay.clear_relic_cues()
	prototype.overlay.spawn_relic_cue(
		TerritoryPrototypeOverlay.RelicCue.GHOST,
		Vector2(100.0, 100.0),
		40.0,
		Color.WHITE,
		Vector2.RIGHT,
		false,
		1.0,
		TerritoryPrototypeOverlay.RelicMotif.SWIRL,
		2.0
	)
	var spun_cue: Object = prototype.overlay._relic_cues[0]
	var spin_rate := float(spun_cue.spin)
	var still_at_start := spin_rate * TAU * 0.0
	var turned_after := spin_rate * TAU * 0.25
	_check(
		is_equal_approx(still_at_start, 0.0)
		and turned_after > 0.0
		and is_equal_approx(spin_rate, 2.0),
		"a cue can carry a spin rate, so a rolling effect turns as it plays"
	)
	prototype.overlay.clear_relic_cues()

	# ------------------------------------------------------------- Plant relics
	# Plant is the glue pool, and two of its relics repeat other relics' effects,
	# so the recursion limiters here are the ones guarding the whole catalog.
	relics.reset_director()
	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	var plant_spot := _find_owned_cell_position(prototype)

	# Garden Hose: distance is counted on owned Green only, a teleport-sized step
	# never banks any of it, and the counter resets only when the spray fires.
	prototype.progression._owned_relics[RelicCatalog.Id.GARDEN_HOSE] = 1
	relics._garden_hose_travel = 0.0
	relics._garden_hose_last_position = plant_spot
	prototype.player.global_position = prototype.territory_field.to_global(
		plant_spot + Vector2(400.0, 0.0)
	)
	relics._advance_garden_hose()
	var hose_ignored_jump := relics._garden_hose_travel
	relics._garden_hose_last_position = plant_spot
	prototype.player.global_position = prototype.territory_field.to_global(
		plant_spot + Vector2(20.0, 0.0)
	)
	relics._advance_garden_hose()
	var hose_counted_step := relics._garden_hose_travel
	_check(
		is_equal_approx(hose_ignored_jump, 0.0) and hose_counted_step > 0.0,
		"GARDEN HOSE counts ordinary travel on Green and never a teleport-sized jump"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.GARDEN_HOSE] = 0

	# Mulch: only what an enemy itself eats is stored, it is capped, and one corpse
	# releases it exactly once.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.MULCH] = 1
	relics.notify_green_eaten(41, 0.5)
	var mulch_stored := relics.get_mulch_store(41)
	for _mulch_bite in range(40):
		relics.notify_green_eaten(41, 1.0)
	var mulch_capped := relics.get_mulch_store(41)
	relics._release_mulch(41, plant_spot)
	var mulch_released := relics.get_mulch_store(41)
	_check(
		mulch_stored > 0.0
		and mulch_capped <= relics.mulch_maximum_store + 0.001
		and is_equal_approx(mulch_released, 0.0),
		"MULCH stores a share of what an enemy eats, caps it, and releases it once"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.MULCH] = 0

	# Compost Heap: corpses merge into a nearby pile, an elite is worth more than a
	# hunter, the pile erupts on its threshold, and the active count is capped.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.COMPOST_HEAP] = 1
	relics._add_compost(plant_spot, 1)
	var heaps_started := relics.get_compost_heap_count()
	relics._add_compost(plant_spot + Vector2(10.0, 0.0), 1)
	var heaps_merged := relics.get_compost_heap_count()
	# Exactly up to the threshold and no further: a heap at threshold stops
	# accepting, so extra corpses would correctly start new piles instead.
	for _compost_corpse in range(relics.compost_threshold - 2):
		relics._add_compost(plant_spot + Vector2(10.0, 0.0), 1)
	for _compost_tick in range(int(relics.compost_eruption_delay * 60.0) + 6):
		relics.advance(1.0 / 60.0)
	var heap_erupted := relics.get_compost_heap_count() == 0
	for far_heap in range(relics.compost_maximum_heaps + 4):
		relics._add_compost(plant_spot + Vector2(float(far_heap) * 300.0, 0.0), 1)
	_check(
		heaps_started == 1
		and heaps_merged == 1
		and heap_erupted
		and relics.get_compost_heap_count() <= relics.compost_maximum_heaps,
		"COMPOST HEAP merges nearby corpses, erupts on its threshold, and caps its piles"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.COMPOST_HEAP] = 0

	# Miracle-Gro: new Green banks one charge, a second charge cannot stack behind
	# it, and the next Adaptation event spends it.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.MIRACLE_GRO] = 1
	relics.notify_green_created(relics.miracle_gro_required_mass * 0.5)
	var gro_half := relics.is_miracle_gro_charged()
	relics.notify_green_created(relics.miracle_gro_required_mass * 0.5)
	var gro_charged := relics.is_miracle_gro_charged()
	relics.notify_green_created(relics.miracle_gro_required_mass * 4.0)
	var gro_spent := relics.consume_miracle_gro()
	var gro_spent_twice := relics.consume_miracle_gro()
	_check(
		not gro_half
		and gro_charged
		and is_equal_approx(gro_spent, relics.miracle_gro_strength)
		and is_equal_approx(gro_spent_twice, 0.0),
		"MIRACLE-GRO banks one repeat at a time and the next event spends it"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.MIRACLE_GRO] = 0

	# Grafting Tape: ready, spent, and then held on its cooldown.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.GRAFTING_TAPE] = 1
	var tape_ready := relics.is_grafting_tape_ready()
	var tape_strength := relics.consume_grafting_tape()
	var tape_on_cooldown := not relics.is_grafting_tape_ready()
	_check(
		tape_ready
		and is_equal_approx(tape_strength, relics.grafting_tape_strength)
		and tape_on_cooldown,
		"GRAFTING TAPE answers once and then holds its cooldown"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.GRAFTING_TAPE] = 0

	# Hybrid Vigor: a repeat can never roll another repeat, Hybrid Vigor never
	# repeats itself, and the rolling window bounds how many land at once.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.HYBRID_VIGOR] = 1
	relics.hybrid_vigor_chance = 1.0
	relics._try_hybrid_vigor(RelicCatalog.Id.HYBRID_VIGOR)
	var vigor_self_repeat := relics._generated_events.size()
	relics._repeating = true
	relics._try_hybrid_vigor(RelicCatalog.Id.SNARE_VINE)
	relics._repeating = false
	var vigor_from_repeat := relics._generated_events.size()
	for _vigor_roll in range(relics.hybrid_vigor_window_maximum + 5):
		relics._try_hybrid_vigor(RelicCatalog.Id.SNARE_VINE)
	var vigor_windowed := relics._generated_events.size()
	_check(
		vigor_self_repeat == 0
		and vigor_from_repeat == 0
		and vigor_windowed == relics.hybrid_vigor_window_maximum,
		"HYBRID VIGOR never repeats itself or a repeat, and its rolling window holds"
	)

	# The global scheduler drains its queue on a budget rather than dropping what
	# the player earned, and a full queue keeps the rarest events.
	var queued_before := relics._generated_events.size()
	for _drain_tick in range(120):
		relics.advance(1.0 / 60.0)
	var drained := relics._generated_events.is_empty()
	relics._generated_events.clear()
	for _fill in range(relics.generated_event_queue_maximum):
		relics._queue_generated_event(
			RelicCatalog.Id.SNARE_VINE, plant_spot, 0.5, 99.0
		)
	var accepted_legendary := relics._queue_generated_event(
		RelicCatalog.Id.THE_HEDGE, plant_spot, 0.5, 99.0
	)
	_check(
		queued_before > 0 and drained and accepted_legendary,
		"the generated-event queue drains on its frame budget and a full one keeps the rarest"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.HYBRID_VIGOR] = 0
	relics.reset_director()
	prototype.combat.reset_combat()

	# -------------------------------------------------------------- Root relics
	# Root transmits through Mature Green rather than adding a resource to manage,
	# so these cases check what the network does, not what the player spends.
	relics.reset_director()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	var root_spot := _find_owned_cell_position(prototype)

	# The Shared Ancient Territory rule places near Grandma rather than on the
	# globally oldest cell, which is the whole point of replacing it.
	for _ripen_ancient in range(6):
		prototype.territory_field.queue_maturity_support(root_spot, 1.0, 4.0)
		prototype.territory_field.step_simulation()
	prototype.player.global_position = prototype.territory_field.to_global(root_spot)
	# The region list is sampled on the shared topology clock, so a relic that reads
	# it has to be held and one sample has to have run.
	prototype.progression._owned_relics[RelicCatalog.Id.TAPROOT] = 1
	relics._topology_remaining = 0.0
	relics._advance_topology(1.0 / 60.0)
	var ancient_site := relics._find_ancient_site()
	var ancient_is_near := (
		ancient_site.x >= 0.0
		and ancient_site.distance_to(root_spot) <= relics.ancient_expanded_search_pixels
	)
	# A region already tracked is skipped, which is what lets Annual Rings hold
	# several distinct regions instead of stacking them all on one.
	var excluded_site := relics._find_ancient_site(
		PackedVector2Array([ancient_site]), 4000.0
	)
	_check(
		ancient_is_near and excluded_site.x < 0.0,
		"the Ancient Territory rule places near Grandma and skips regions already tracked"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.TAPROOT] = 0

	# Rootbound: charged by continuous time on deep Green, carried, and spent by
	# walking into young Green rather than by standing still.
	prototype.progression._owned_relics[RelicCatalog.Id.ROOTBOUND] = 1
	relics._rootbound_standing = 0.0
	relics._rootbound_carrying = 0.0
	relics._rootbound_cooldown = 0.0
	prototype.player.global_position = prototype.territory_field.to_global(root_spot)
	for _charge_tick in range(int(relics.rootbound_charge_seconds * 60.0) + 6):
		relics._advance_rootbound(1.0 / 60.0)
	var rootbound_carrying := relics._rootbound_carrying > 0.0
	# Stepping off owned Green entirely must not discharge it.
	var off_green := prototype.territory_field.find_player_frontier_near(root_spot)
	relics._advance_rootbound(1.0 / 60.0)
	var rootbound_held := relics._rootbound_carrying > 0.0
	_check(
		rootbound_carrying and rootbound_held,
		"ROOTBOUND charges on deep Green and keeps the pulse until young Green takes it"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.ROOTBOUND] = 0

	# Suckers: only enemy-caused loss counts, and the relic answers once per
	# regional cooldown rather than once per cell.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.SUCKERS] = 1
	relics.notify_mature_green_lost(relics.suckers_lost_cells - 1)
	relics._advance_suckers(1.0 / 60.0)
	var suckers_under_threshold := relics._pending_suckers.size()
	relics.notify_mature_green_lost(2)
	relics._advance_suckers(1.0 / 60.0)
	var suckers_sprouted := relics._pending_suckers.size()
	# A second wound inside the cooldown must not sprout again.
	relics.notify_mature_green_lost(relics.suckers_lost_cells * 2)
	relics._advance_suckers(1.0 / 60.0)
	var suckers_on_cooldown := relics._pending_suckers.size()
	_check(
		suckers_under_threshold == 0
		and suckers_sprouted == relics.suckers_count
		and suckers_on_cooldown == suckers_sprouted,
		"SUCKERS answers a real wound once, and its regional cooldown holds"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.SUCKERS] = 0

	# Feeder Roots: only amplified natural events on deep Green count, and a
	# relic-generated echo never advances it.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.FEEDER_ROOTS] = 1
	relics.notify_amplified_event(root_spot, 1.0)
	var feeder_unamplified := relics._feeder_events
	relics._repeating = true
	relics.notify_amplified_event(root_spot, 1.5)
	relics._repeating = false
	var feeder_from_echo := relics._feeder_events
	for _feeder_event in range(relics.feeder_roots_events - 1):
		relics.notify_amplified_event(root_spot, 1.5)
	var feeder_counted := relics._feeder_events
	_check(
		feeder_unamplified == 0
		and feeder_from_echo == 0
		and feeder_counted == relics.feeder_roots_events - 1,
		"FEEDER ROOTS counts only amplified natural events, never an unamplified one or an echo"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.FEEDER_ROOTS] = 0

	# Graft Union: arms on a reconnection, is spent once, and then holds cooldown.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.GRAFT_UNION] = 1
	var graft_unarmed := relics.is_graft_union_armed()
	# Component count comes off the shared topology cache, so the split and the
	# rejoin are driven through that seam rather than by rearranging the board.
	relics._cached_component_count = 2
	relics._advance_graft_union(1.0 / 60.0)
	var graft_saw_split := relics._graft_components > 1
	relics._graft_split_seconds = relics.graft_union_separation_seconds
	relics._cached_component_count = 1
	relics._advance_graft_union(1.0 / 60.0)
	var graft_armed := relics.is_graft_union_armed()
	var graft_strength := relics.consume_graft_union()
	var graft_spent_twice := relics.consume_graft_union()
	_check(
		not graft_unarmed
		and graft_saw_split
		and graft_armed
		and is_equal_approx(graft_strength, relics.graft_union_strength)
		and is_equal_approx(graft_spent_twice, 0.0),
		"GRAFT UNION arms when a long-split network rejoins and its echo is spent once"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.GRAFT_UNION] = 0

	# Rhizome: a whole organism offers no colony to reconnect, and the field's own
	# component query is what decides that rather than the relic guessing.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.RHIZOME] = 1
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	var whole_organism := prototype.territory_field.find_isolated_colony(
		relics.rhizome_minimum_cells, relics.rhizome_minimum_maturity
	)
	for _rhizome_tick in range(int(relics.rhizome_survival_seconds * 60.0) + 10):
		relics._advance_rhizome(1.0 / 60.0)
	_check(
		whole_organism.x < 0.0
		and prototype.territory_field.get_owned_component_count() >= 1
		and relics._rhizome_growing <= 0.0,
		"RHIZOME finds nothing to reconnect while the organism is in one piece"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.RHIZOME] = 0
	relics.reset_director()
	prototype.combat.reset_combat()

	# -------------------------------------------------------------- Vine relics
	# Vine's pool is ignited by precision, and Apical now means real contact from
	# the outer portion of the simulated rope. These cases check the streaks and
	# the limiters; the rope's own physics has its own probe.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.VINE,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	var vine := prototype.adaptation_director
	vine.reset_adaptations()
	prototype.combat.reset_combat()
	var vine_spot := _find_owned_cell_position(prototype)
	prototype.player.global_position = prototype.territory_field.to_global(vine_spot)

	# The Cane resolves through the rope while Vine is held, and through its
	# authored sector otherwise. That switch is what the whole rework rests on.
	var vine_drives := prototype.combat.is_vine_driven()
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	var sector_drives := prototype.combat.is_vine_driven()
	prototype.progression.debug_select_paths(
		Progression.PathId.VINE,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	_check(
		vine_drives and not sector_drives,
		"the Cane resolves through the simulated Vine only while Vine is held"
	)

	# Girdling: consecutive natural Apical hits on the same enemy mark it, a gap
	# breaks the streak, and the next Vine contact spends the mark.
	vine.reset_adaptations()
	prototype.progression._owned_relics[RelicCatalog.Id.GIRDLING] = 1
	var girdled_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HEAVY_GRAZER, vine_spot + Vector2(40.0, 0.0)
	)
	vine._natural_sweep_index = 1
	vine._note_vine_apical_hit(girdled_id, 30.0)
	# Two hits inside one sweep are one hit's worth of progress.
	vine._note_vine_apical_hit(girdled_id, 30.0)
	var girdle_after_one := int(vine._girdling[girdled_id][0])
	vine._natural_sweep_index = 2
	vine._note_vine_apical_hit(girdled_id, 30.0)
	var girdle_marked := float(vine._girdling[girdled_id][2]) > 0.0
	var girdle_health := prototype.combat.get_enemy_health(girdled_id)
	vine._try_consume_girdling(girdled_id, 30.0)
	var girdle_crushed := prototype.combat.get_enemy_health(girdled_id) < girdle_health
	var girdle_spent := not vine._girdling.has(girdled_id)
	# A broken streak starts over rather than carrying its progress.
	vine._girdling.clear()
	vine._girdling_cooldowns.clear()
	vine._natural_sweep_index = 10
	vine._note_vine_apical_hit(girdled_id, 30.0)
	vine._natural_sweep_index = 14
	vine._note_vine_apical_hit(girdled_id, 30.0)
	var girdle_streak_reset := int(vine._girdling[girdled_id][0]) == 1
	_check(
		girdle_after_one == 1
		and girdle_marked
		and girdle_crushed
		and girdle_spent
		and girdle_streak_reset,
		"GIRDLING builds on consecutive Apical sweeps, breaks on a gap, and is spent once"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.GIRDLING] = 0

	# Runner: one sprout per natural sweep, capped, and it lashes a neighbour.
	vine.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.RUNNER] = 1
	var runner_victim := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER, vine_spot + Vector2(30.0, 0.0)
	)
	vine._runners.append([vine_spot, 0.0, 25.0])
	var runner_health := prototype.combat.get_enemy_health(runner_victim)
	vine._advance_vine_relics(1.0 / 60.0)
	_check(
		vine._runners.is_empty()
		and prototype.combat.get_enemy_health(runner_victim) < runner_health,
		"RUNNER lashes a neighbour from the corpse and is spent by doing it"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.RUNNER] = 0

	# Whiplash: reaches past the tip, and only enemies the parent sweep missed.
	vine.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.WHIPLASH] = 1
	vine._current_sweep_reach = 60.0
	var beyond_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HEAVY_GRAZER, vine_spot + Vector2(90.0, 0.0)
	)
	var already_hit_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HEAVY_GRAZER, vine_spot + Vector2(100.0, 0.0)
	)
	vine._cane_sweep_hits.append(already_hit_id)
	var beyond_health := prototype.combat.get_enemy_health(beyond_id)
	var already_health := prototype.combat.get_enemy_health(already_hit_id)
	vine._try_whiplash(vine_spot, Vector2.RIGHT, 40.0)
	_check(
		prototype.combat.get_enemy_health(beyond_id) < beyond_health
		and is_equal_approx(
			prototype.combat.get_enemy_health(already_hit_id), already_health
		),
		"WHIPLASH snaps past the tip and never re-hits what the parent sweep reached"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.WHIPLASH] = 0

	# Climber: requires a real bend in the rope and a hit past it. Without a wrap
	# it must do nothing at all, which is what stops it reaching through terrain.
	vine.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.CLIMBER] = 1
	var climber_victim := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HEAVY_GRAZER, vine_spot + Vector2(20.0, 0.0)
	)
	var climber_health := prototype.combat.get_enemy_health(climber_victim)
	vine._sweep_bend_index = -1
	vine._sweep_hit_past_bend = false
	vine._try_climber(40.0)
	var climber_without_bend := is_equal_approx(
		prototype.combat.get_enemy_health(climber_victim), climber_health
	)
	# A bend with nothing hit past it is still not a Climber.
	vine._sweep_bend_index = 2
	vine._sweep_hit_past_bend = false
	vine._try_climber(40.0)
	var climber_without_hit := is_equal_approx(
		prototype.combat.get_enemy_health(climber_victim), climber_health
	)
	_check(
		climber_without_bend and climber_without_hit,
		"CLIMBER cinches only a Vine that actually wrapped and struck past the bend"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.CLIMBER] = 0

	# Liana: three consecutive successful Apical sweeps unleash the cascade, a
	# failed sweep resets the streak, and the cascade is exactly four sweeps.
	vine.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.LIANA] = 1
	for _liana_sweep in range(vine.liana_required_sweeps - 1):
		vine._current_sweep_apical_hit = true
		vine._on_cane_sweep_finished(vine_spot, Vector2.RIGHT, true, 92.0, 1, false)
	var liana_building := vine._liana_progress
	# A sweep with no Apical hit breaks it.
	vine._current_sweep_apical_hit = false
	vine._on_cane_sweep_finished(vine_spot, Vector2.RIGHT, true, 92.0, 0, false)
	var liana_reset := vine._liana_progress
	for _liana_again in range(vine.liana_required_sweeps):
		vine._current_sweep_apical_hit = true
		vine._on_cane_sweep_finished(vine_spot, Vector2.RIGHT, true, 92.0, 1, false)
	var liana_cascade := vine._liana_remaining
	var liana_cooling := vine._liana_cooldown > 0.0
	_check(
		liana_building == vine.liana_required_sweeps - 1
		and liana_reset == 0
		and liana_cascade == vine.liana_bonus_sweeps
		and liana_cooling,
		"LIANA needs three consecutive Apical sweeps, resets on a miss, and casts four"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.LIANA] = 0

	# Continuity: every relic-driven stroke has to drive the rope that is already
	# there. A relic that rebuilt the Vine would look like it was being respawned
	# per attack, which is the whole thing the physics rework exists to stop.
	var whip: VineWhip = prototype.combat.vine_whip
	prototype.player.global_position = prototype.territory_field.to_global(vine_spot)
	prototype.combat.simulate_step(1.0 / 60.0)
	var rope_is_driving := prototype.combat.is_vine_driven() and whip.is_built()

	# Recurve reverses a rope that is still carrying momentum: the next stroke
	# arrives sooner and starts from exactly where the last one left the body.
	prototype.progression._owned_relics[RelicCatalog.Id.RECURVE] = 1
	vine._recurve_armed = false
	vine._on_cane_enemy_hit(-1, vine_spot, 0.9, true, 10.0, false, false)
	var recurve_armed := vine._recurve_armed
	var before_recurve := whip.points.duplicate()
	var sweep_before := whip.get_sweep_id()
	prototype.combat.perform_bonus_cane_sweep(Vector2.RIGHT, false)
	var recurve_continuous := true
	for point_index in range(before_recurve.size()):
		if not before_recurve[point_index].is_equal_approx(whip.points[point_index]):
			recurve_continuous = false
			break
	_check(
		rope_is_driving
		and recurve_armed
		and whip.get_sweep_id() == sweep_before + 1
		and recurve_continuous
		and whip.get_point_count() == before_recurve.size(),
		"RECURVE reverses the continuously simulated Vine without resetting its momentum"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.RECURVE] = 0

	# Twining's repeat is a stroke of the same body, not a second Vine.
	prototype.progression._owned_relics[RelicCatalog.Id.TWINING] = 1
	for _twine_settle in range(10):
		prototype.combat.simulate_step(1.0 / 60.0)
	var before_twining := whip.points.duplicate()
	var twining_sweep_before := whip.get_sweep_id()
	prototype.combat.perform_bonus_cane_sweep(
		Vector2.RIGHT, true, vine.twining_damage_share
	)
	var twining_continuous := true
	for point_index in range(before_twining.size()):
		if not before_twining[point_index].is_equal_approx(whip.points[point_index]):
			twining_continuous = false
			break
	_check(
		whip.get_sweep_id() == twining_sweep_before + 1
		and twining_continuous
		and whip.get_point_count() == before_twining.size(),
		"TWINING repeats on the persistent Vine state rather than spawning a second one"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.TWINING] = 0

	# Liana's cascade is four strokes of one rope, alternating, with the body never
	# rebuilt between them.
	prototype.progression._owned_relics[RelicCatalog.Id.LIANA] = 1
	vine.reset_adaptations()
	for _liana_settle in range(10):
		prototype.combat.simulate_step(1.0 / 60.0)
	var liana_points_before := whip.get_point_count()
	var liana_sweep_before := whip.get_sweep_id()
	vine._liana_remaining = vine.liana_bonus_sweeps
	vine._liana_step = 0.0
	vine._liana_facing = Vector2.RIGHT
	var liana_rebuilt := false
	for _liana_tick in range(int(vine.liana_interval_seconds * 60.0) * 6 + 30):
		vine._advance_vine_relics(1.0 / 60.0)
		if whip.get_point_count() != liana_points_before:
			liana_rebuilt = true
	_check(
		whip.get_sweep_id() - liana_sweep_before == vine.liana_bonus_sweeps
		and not liana_rebuilt
		and vine._liana_remaining == 0,
		"LIANA drives exactly four alternating strokes through one continuous Vine body"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.LIANA] = 0

	# Climber reads a real wrap, not a sharp curve. A rope whipping through open
	# ground bends hard under its own momentum and must never read as wrapped.
	prototype.progression._owned_relics[RelicCatalog.Id.CLIMBER] = 1
	var open_wrap := whip.is_wrapped()
	var curved_hard := whip.get_bend_count() > 0
	vine._sweep_bend_index = whip.get_wrap_index()
	var climber_armed_in_the_open := vine._sweep_bend_index >= 0
	_check(
		not open_wrap and not climber_armed_in_the_open,
		"CLIMBER reads an actual wrap rather than a rope merely bent by its own swing"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.CLIMBER] = 0

	vine.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()

	# Snare Vine spreads a capped share of a root to the nearest few enemies.
	prototype.combat.reset_combat()
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.SNARE_VINE] = 1
	relics.apply_relics()
	var snare_ids := PackedInt32Array()
	for snare_index in range(4):
		snare_ids.append(prototype.combat.spawn_enemy(
			CombatDirector.EnemyRole.HUNTER,
			lone_spot + Vector2.from_angle(float(snare_index) * 1.2) * 30.0
		))
	prototype.combat.enemy_ensnared.emit(lone_spot)
	var snared := 0
	for snare_id in snare_ids:
		if prototype.combat.get_enemy_entanglement(snare_id) > 0.0:
			snared += 1
	_check(
		snared > 0 and snared <= relics.snare_vine_targets,
		"SNARE VINE spreads Entanglement to a capped number of neighbours"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.SNARE_VINE] = 0
	prototype.combat.reset_combat()

	# Gleaning Hook banks Charge off ring kills, capped per hold.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.PRUNING,
		Progression.PathId.SPORE
	)
	prototype.progression._owned_relics[RelicCatalog.Id.GLEANING_HOOK] = 1
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
	prototype.progression._owned_relics[RelicCatalog.Id.GLEANING_HOOK] = 0

	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	relics.reset_director()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	prototype.territory_field.reset_field()

	# Relic rewards are on a wave schedule as well as on the elite and the boss.
	# A crossing owes the run a relic only on the authored cycle, and the debt is
	# paid out by the run loop once no other choice holds the panel.
	var relic_cycle := prototype.relic_reward_wave_cycle
	prototype._owed_wave_relics = 0
	# A panel held open, so the debt is observed rather than immediately settled:
	# what is being checked is which crossings owe a relic, not how fast the run
	# loop pays one out.
	var held_choice_kind := prototype._choice_kind
	prototype._choice_kind = RunRoot.ChoiceKind.RELIC
	prototype._on_wave_began(relic_cycle + 1)
	var off_cycle_owed := prototype._owed_wave_relics
	prototype._on_wave_began(relic_cycle * 2)
	var on_cycle_owed := prototype._owed_wave_relics
	prototype._choice_kind = held_choice_kind
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
		prototype.progression.evolution_status == Progression.EvolutionStatus.READY,
		"maxing one Spore and one Bloom line marks Evolution Ready"
	)
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var evolution_draft := prototype.progression.get_pending_upgrade_options()
	var evolution_index := evolution_draft.find(
		Progression.EVOLUTION_DRAFT_OPTION
	)
	var evolution_button_text := ""
	if evolution_index >= 0:
		evolution_button_text = prototype.choice_panel.buttons[evolution_index].text
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
			Progression.EVOLUTION_DRAFT_OPTION
		),
		"a ready pairing survives a reroll so it cannot be drafted away"
	)
	prototype._choose_displayed_option(
		prototype.progression.get_pending_upgrade_options().find(
			Progression.EVOLUTION_DRAFT_OPTION
		)
	)
	_check(
		prototype.progression.evolution_status == Progression.EvolutionStatus.EVOLVED
		and prototype.progression.active_evolution
		== Progression.EvolutionId.SUPER_BLOOM
		and prototype.progression.get_evolution_upgrade_level() == 1,
		"choosing the pairing grants Super Bloom and its rank-1 line immediately"
	)

	# An Evolution line's hover has to grow with the line. Every rank does something
	# different, so a single "now" line threw away most of what the run had bought:
	# the hover is the only place the finished build can be read back.
	var evolution_upgrade_id := Evolutions.get_evolution_upgrade_id(
		Progression.EvolutionId.SUPER_BLOOM
	)
	prototype._update_hud()
	var hover_rank_one_tooltip := prototype._evolution_upgrade_slot.get_slot_tooltip(0)
	prototype.progression._upgrade_levels[evolution_upgrade_id] = 3
	prototype._apply_progression_modifiers()
	prototype._update_hud()
	var hover_rank_three_tooltip := prototype._evolution_upgrade_slot.get_slot_tooltip(0)
	var hover_rank_one_text := prototype.evolutions.get_evolution_upgrade_rank_description(
		evolution_upgrade_id,
		1
	)
	var hover_rank_three_text := prototype.evolutions.get_evolution_upgrade_rank_description(
		evolution_upgrade_id,
		3
	)
	_check(
		not hover_rank_one_text.is_empty()
		and not hover_rank_three_text.is_empty()
		and hover_rank_one_tooltip.contains(hover_rank_one_text)
		and not hover_rank_one_tooltip.contains(hover_rank_three_text)
		and hover_rank_three_tooltip.contains(hover_rank_one_text)
		and hover_rank_three_tooltip.contains(hover_rank_three_text)
		and hover_rank_three_tooltip.split("
").size()
		> hover_rank_one_tooltip.split("
").size(),
		"an Evolution hover lists every rank the run owns, not only the newest"
	)
	prototype.progression._upgrade_levels[evolution_upgrade_id] = 1
	prototype._apply_progression_modifiers()
	prototype._update_hud()
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	_check(
		not prototype.progression.get_pending_upgrade_options().has(
			Progression.EVOLUTION_DRAFT_OPTION
		),
		"an evolved run stops offering the pairing in later drafts"
	)
	prototype._choose_displayed_option(0)

	prototype.combat.reset_combat()
	# The relic fixtures above have been handing this run relics all along, and an
	# exhausted pool pays a Compost Cache instead of opening a panel. The reward
	# under test is the relic, so the pool is restocked first.
	prototype.progression._owned_relics.fill(0)
	var boss_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.BOSS,
		Vector2(760.0, 330.0)
	)
	prototype.combat.debug_damage_enemy(boss_id, 100000.0)
	# The Boss opens the last Branch position, so its Adaptation offer comes first
	# and the relic follows once that choice is made -- by which time the new
	# Adaptation's relic pool is already eligible.
	if prototype.progression.is_pending_branch_upgrade_choice():
		prototype._choose_displayed_option(0)
	_check(
		prototype.choice_panel.visible
		and prototype.choice_panel.header.text == "ELITE RELIC",
		"defeating the boss pays out a relic once its Adaptation offer is answered"
	)
	prototype._choose_displayed_option(0)

	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	var chain_center := Vector2(735.0, 350.0)
	for index in range(prototype.evolutions.secondary_kills_per_seed):
		prototype.combat.spawn_enemy(
			CombatDirector.EnemyRole.HUNTER,
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
		CombatDirector.EnemyRole.HUNTER,
		wall_open_side
	)
	var shadow_enemy_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
		wall_shadow
	)
	prototype.combat.damage_enemies_in_radius(
		wall_source,
		150.0,
		10000.0,
		CombatDirector.DeathSource.BLOOM
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
			CombatDirector.EnemyRole.ELITE
		) == 1,
		"the shortened timeline introduces its elite milestone"
	)
	prototype.debug_advance_time(
		prototype.wave_director.boss_time_seconds
		- prototype.wave_director.elite_time_seconds
	)
	_check(
		not prototype.combat.has_active_boss()
		and prototype.is_wave_grace_period_active(),
		"the Burrower waits through the grace period at its wave milestone"
	)
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
			CombatDirector.EnemyRole.SABOTEUR,
		],
		[
			prototype.wave_director.corruptor_intro_seconds,
			prototype.wave_director.corruptor_pack_cycle,
			CombatDirector.EnemyRole.CORRUPTOR,
		],
		[
			prototype.wave_director.colonizer_intro_seconds,
			prototype.wave_director.colonizer_pack_cycle,
			CombatDirector.EnemyRole.COLONIZER,
		],
		[
			prototype.wave_director.warden_intro_seconds,
			prototype.wave_director.warden_pack_cycle,
			CombatDirector.EnemyRole.WARDEN,
		],
	]
	for specialist_entry in specialist_schedule:
		prototype.wave_director.elapsed_seconds = specialist_entry[0]
		prototype.wave_director._spawn_pack_sequence = specialist_entry[1] - 1
		specialist_schedule_is_authored = (
			specialist_schedule_is_authored
			and prototype.wave_director._select_regular_role(
				CombatDirector.EnemyRole.HUNTER
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
		CombatDirector.EnemyRole.HUNTER
	) == CombatDirector.EnemyRole.SIEGE_CORRUPTOR
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
		CombatDirector.EnemyRole.HEAVY_GRAZER
	)
	var heavy := prototype.combat._enemies[0]
	for candidate in prototype.combat._enemies:
		if candidate.active and candidate.id == heavy_id:
			heavy = candidate
	var heavy_start := heavy.position
	prototype.combat._begin_knockback(heavy, Vector2.RIGHT, 60.0)
	var heavy_shove := heavy.knockback_speed
	prototype.combat.reset_combat()
	var light_id := prototype.combat.spawn_enemy(CombatDirector.EnemyRole.GRAZER)
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
		CombatDirector.EnemyRole.SIEGE_CORRUPTOR
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
		CombatDirector.DeathSource.CANE,
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
		CombatDirector.EnemyRole.ELITE
	)
	# Read at the final invasion, which is where the escalation curve tops out.
	waves.elapsed_seconds = waves.final_invasion_time_seconds
	prototype.combat.set_elite_modifier_pressure(waves.get_escalation_progress())
	var modified_rolls := 0
	for _roll in range(40):
		if prototype.combat._roll_elite_modifier(
			CombatDirector.EnemyRole.ELITE
		) != CombatDirector.EliteModifier.NONE:
			modified_rolls += 1
	var hunter_never_modified := prototype.combat._roll_elite_modifier(
		CombatDirector.EnemyRole.HUNTER
	) == CombatDirector.EliteModifier.NONE
	_check(
		unmodified == CombatDirector.EliteModifier.NONE
		and modified_rolls > 20
		and hunter_never_modified
		and is_equal_approx(waves.get_escalation_progress(), 1.0),
		"rule changes are gated behind the run's escalation and never reach the "
			+ "body of a pack (%d of 40 late rolls)" % modified_rolls
	)

	# Unstoppable: cannot be held, can still be slowed.
	prototype.combat.reset_combat()
	prototype.combat.debug_force_elite_modifier(
		CombatDirector.EliteModifier.UNSTOPPABLE
	)
	var unstoppable_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.ELITE
	)
	var unstoppable := prototype.combat._enemies[0]
	for candidate in prototype.combat._enemies:
		if candidate.active and candidate.id == unstoppable_id:
			unstoppable = candidate
	unstoppable.bramble_ensnare_remaining = 5.0
	unstoppable.movement_speed_multiplier = 0.4
	prototype.combat._advance_elite_modifier(unstoppable, 1.0 / 60.0)
	_check(
		unstoppable.elite_modifier == CombatDirector.EliteModifier.UNSTOPPABLE
		and is_equal_approx(unstoppable.bramble_ensnare_remaining, 0.0)
		and is_equal_approx(unstoppable.movement_speed_multiplier, 0.4),
		"an Unstoppable elite breaks a hold and stays slowed"
	)

	# Regenerative: heals, unless the protagonist is the one who hit it. Bramble is
	# deliberately not enough, which is what makes it a change to a build.
	prototype.combat.reset_combat()
	prototype.combat.debug_force_elite_modifier(
		CombatDirector.EliteModifier.REGENERATIVE
	)
	var regen_id := prototype.combat.spawn_enemy(CombatDirector.EnemyRole.ELITE)
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
		CombatDirector.DeathSource.CANE,
		0
	)
	var regen_after_shot := regen.health
	prototype.combat._advance_elite_modifier(regen, 0.5)
	var regen_blocked := is_equal_approx(regen.health, regen_after_shot)
	prototype.combat._damage_enemy(
		regen,
		1.0,
		CombatDirector.DeathSource.BRAMBLE,
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
		CombatDirector.EliteModifier.VOLATILE
	)
	var volatile_id := prototype.combat.spawn_enemy(CombatDirector.EnemyRole.ELITE)
	var volatile := prototype.combat._enemies[0]
	for candidate in prototype.combat._enemies:
		if candidate.active and candidate.id == volatile_id:
			volatile = candidate
	var bystander_id := prototype.combat.spawn_enemy(
		CombatDirector.EnemyRole.HUNTER,
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
		CombatDirector.DeathSource.CANE,
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
	prototype.combat.spawn_enemy(CombatDirector.EnemyRole.HUNTER)
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
		and prototype.get_run_state() == RunRoot.RunState.RUNNING
		and prototype.status_label.text.contains("CLEAR THE FIELD"),
		"the clock running out leaves the run going while hostiles are still standing"
	)
	prototype.combat.debug_kill_all()
	# The killing blow can hand the player a level, and a pending draft holds the
	# run open until it is taken; victory lands on the far side of that choice.
	for _final_frame in range(8):
		# Any open panel is answered, not just a draft: victory lands on the far side
		# of every choice the run is still holding out for.
		if prototype.choice_panel.visible:
			prototype._choose_displayed_option(0)
		prototype.advance_run(1.0 / 60.0)
		if prototype.get_run_state() != RunRoot.RunState.RUNNING:
			break
	_check(
		prototype.combat.get_active_enemy_count() == 0
		and prototype.get_run_state() == RunRoot.RunState.VICTORY,
		"clearing the last hostiles after the timeline ends produces victory"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.apply_damage(prototype.player.get_max_health() * 2.0)
	_check(
		prototype.get_run_state() == RunRoot.RunState.DEFEAT,
		"losing all player HP ends the run immediately"
	)

	prototype.queue_free()
	await process_frame
	if _failures == 0:
		print("RUN_SMOKE: PASS")
		quit(0)
	else:
		push_error("RUN_SMOKE: %d failure(s)" % _failures)
		quit(1)


func _find_open_ground_position(prototype: RunRoot) -> Vector2:
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


func _thorn_all_owned_ground(prototype: RunRoot) -> void:
	# Thorns on every owned cell, not only the frontier, so a cycle that eats the
	# interior still tears some out and Deadfall has something to convert.
	var field := prototype.territory_field
	for index in range(field._bramble_development.size()):
		if field._control[index] > field.tuning.ownership_threshold:
			field._bramble_development[index] = 1.0


func _grow_test_ecosystem(prototype: RunRoot) -> void:
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
	prototype: RunRoot,
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


func _stand_on_owned_ground(prototype: RunRoot) -> Vector2:
	# The harvest happens under the player, so a Pruning check has to put the player
	# on their own ground first. In a run that is the whole input to the path.
	var spot := _find_owned_cell_position(prototype)
	prototype.player.global_position = prototype.territory_field.to_global(spot)
	return spot


func _find_owned_cell_position(prototype: RunRoot) -> Vector2:
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


func _throw_one_glob(bloom: BloomDirector, origin: Vector2) -> float:
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


func _acquire_adaptation(prototype: RunRoot, path_id: int) -> void:
	## Enters one Adaptation the way a run does: by drafting one of its lines. The
	## fixture forces the offer onto the line it wants rather than waiting for the
	## seed to deal it, but the commitment itself goes through choose_upgrade.
	if prototype.progression.owns_adaptation(path_id):
		return
	var lines := prototype.progression.get_adaptation_line_ids(path_id)
	if lines.is_empty():
		return
	prototype.progression._pending_upgrade_options = PackedInt32Array([lines[0]])
	prototype.progression.choose_upgrade(lines[0])


func _seed_run_adaptations(
	prototype: RunRoot,
	first_core: int,
	second_core: int
) -> void:
	## A Core pair committed, so a fixture that is about to draft has an owned build
	## to draft into.
	prototype.progression.debug_select_paths(first_core, second_core)


func _take_offered_upgrade(prototype: RunRoot, upgrade_id: int) -> void:
	## Spends a level on one named line. The draft is weighted rather than walked
	## from a cursor, so a fixture that needs a specific line puts it on the screen
	## instead of re-rolling seeds until it appears; the commitment itself still goes
	## through the run's own selection path.
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	if not prototype.progression.get_pending_upgrade_options().has(upgrade_id):
		prototype.progression._pending_upgrade_options = PackedInt32Array([upgrade_id])
		prototype._choice_ids = PackedInt32Array([upgrade_id])
	prototype._choose_displayed_option(
		maxi(0, prototype._choice_ids.find(upgrade_id))
	)


func _spawn_bramble_contact_enemy(
	prototype: RunRoot,
	role: int,
	local_position: Vector2
) -> CombatDirector.EnemyState:
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
