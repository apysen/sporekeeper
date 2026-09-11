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

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype._set_simulation_paused(true)
	_report.check(
		is_equal_approx(prototype.wave_director.wave_grace_period_seconds, 5.0)
		and not prototype.is_wave_grace_period_active()
		and is_zero_approx(prototype.get_wave_grace_remaining_seconds())
		and prototype.wave_label.text == (
			"WAVE 1 / %d" % prototype.get_final_wave_number()
		),
		"wave one begins immediately without a grace countdown"
	)
	prototype.advance_run(0.65)
	_report.check(
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
	_report.check(
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
		EnemyKinds.Role.HUNTER
	)
	var wave_one_grazer_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.GRAZER
	)
	_report.check(
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
		EnemyKinds.Role.HUNTER
	)
	var wave_two_grazer_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.GRAZER
	)
	var wave_two_boss_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.BOSS
	)
	_report.check(
		prototype.get_current_wave_number() == 2
		and prototype.combat.get_enemy_xp_value(wave_two_hunter_id) == 3
		and prototype.combat.get_enemy_xp_value(wave_two_boss_id) == 110
		and is_equal_approx(
			prototype.combat.get_enemy_territory_erosion_scale(wave_two_grazer_id),
			1.10
		),
		"wave two raises common and boss XP while adding 10% territory pressure"
	)
	_report.check(
		prototype.combat.get_enemy_xp_value(wave_one_hunter_id) == 2
		and is_equal_approx(
			prototype.combat.get_enemy_territory_erosion_scale(wave_one_grazer_id),
			1.0
		),
		"enemies keep the scaling from the wave in which they spawned"
	)
	prototype.debug_advance_time(prototype.wave_director.wave_duration_seconds)
	var wave_three_hunter_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER
	)
	var wave_three_grazer_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.GRAZER
	)
	var wave_three_boss_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.BOSS
	)
	_report.check(
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
	_report.check(
		prototype.player.get_arena_position().x > start_position.x + 20.0,
		"manual movement advances the Gardener across claimable ground"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	# A run opens on the Adaptation chooser, and a modal choice is not something
	# Escape may pause over. Answer it first, then the pause menu is reachable.
	SmokeFixtures.seed_run_adaptations(
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
	_report.check(
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
	_report.check(
		ambient_music_stream != null
		and ambient_music_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
		and ambient_music_stream.loop_begin == 0
		and ambient_music_stream.loop_end
		== roundi(ambient_music_stream.get_length() * ambient_music_stream.mix_rate),
		"the forest theme loops across its complete sample range"
	)
	_report.check(
		prototype.run_audio.ambient_music.autoplay
		and prototype.run_audio.ambient_music == prototype.get_node("RunAudio/AmbientMusic")
		and prototype.run_audio.ambient_music.playing
		and prototype.run_audio.ambient_music.bus == prototype.audio_settings.music_bus_name,
		"the scene-authored forest theme is already playing on the Music bus"
	)
	await create_timer(0.25).timeout
	_report.check(
		prototype.run_audio.ambient_music.playing
		and prototype.run_audio.ambient_music.get_playback_position() > 0.05,
		"forest music remains active and advances beyond its opening instant"
	)
	prototype.pause_menu.volume_slider.value = 100.0
	_report.check(
		not AudioServer.is_bus_mute(sfx_bus_index)
		and is_equal_approx(
			db_to_linear(AudioServer.get_bus_volume_db(sfx_bus_index)),
			prototype.audio_settings.sfx_max_linear_volume
		)
		and prototype.pause_menu.volume_value.text == "100%",
		"displayed SFX volume 100% is capped at 20% linear output"
	)
	prototype.pause_menu.volume_slider.value = 37.0
	_report.check(
		not AudioServer.is_bus_mute(sfx_bus_index)
		and is_equal_approx(
			db_to_linear(AudioServer.get_bus_volume_db(sfx_bus_index)),
			0.37 * prototype.audio_settings.sfx_max_linear_volume
		)
		and prototype.pause_menu.volume_value.text == "37%",
		"the pause-menu slider scales the capped SFX bus immediately"
	)
	prototype.pause_menu.volume_slider.value = 0.0
	_report.check(
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
	_report.check(
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
	_report.check(
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
	_report.check(
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
	_report.check(
		not prototype.is_pause_menu_open()
		and not prototype.pause_menu.visible
		and not prototype.combat.simulation_paused,
		"Resume closes the pause overlay and restores gameplay simulation"
	)
	prototype.debug_advance_time(12.0)
	prototype._open_pause_menu()
	prototype.pause_menu.glossary_button.pressed.emit()
	_report.check(
		prototype._mechanics_help.is_glossary_open()
		and prototype.is_pause_menu_open()
		and prototype.pause_menu.visible,
		"Glossary opens from the pause menu without resuming simulation"
	)
	prototype._close_glossary()
	_report.check(
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
		EnemyKinds.Role.HUNTER,
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
	_report.check(hunter_id != -1, "a pooled Hunter can be spawned")
	_report.check(
		not prototype.combat.is_enemy_active(hunter_id),
		"the automatic base Cane kills a Hunter inside its facing sector"
	)
	_report.check(
		prototype.combat.cane_swing_sfx != null
		and prototype.combat.get_cane_sfx_play_count() > 0
		and prototype.combat._cane_audio.bus == prototype.audio_settings.sfx_bus_name,
		"each automatic Cane sweep plays the authored swing SFX"
	)
	_report.check(
		observed_hit_flash and observed_damage_number,
		"Cane damage produces an enemy hit flash and a pooled floating number"
	)
	_report.check(prototype.combat.get_active_pickup_count() > 0, "enemy death produces pooled XP")
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
	_report.check(
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
	_report.check(
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
	_report.check(
		is_equal_approx(prototype.combat.get_last_xp_collect_pitch_scale(), 1.0),
		"the first XP circle after the timeout plays at default pitch"
	)

	prototype.combat.reset_combat()
	var outside_range_position := (
		prototype.player.get_arena_position()
		+ Vector2(prototype.combat.cane_reach_pixels + 150.0, 0.0)
	)
	var outside_range_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		outside_range_position
	)
	prototype.combat.simulate_step(0.20)
	_report.check(
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
		EnemyKinds.Role.HUNTER,
		cane_blocked_target
	)
	var visible_target_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		cane_visible_target
	)
	var dense_visible_direction := prototype.combat.get_densest_target_direction(
		cane_wall_source,
		500.0,
		45.0,
		Vector2.RIGHT
	)
	_report.check(
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
	# Each body is measured against its own maximum, never against the authored
	# profile. By this point in the run the wave curve is live, so a Hunter spawns
	# with 28.64 health where the profile says 28.0 - and an untouched enemy compared
	# against the profile reads as damaged, which is the opposite of what is meant.
	_report.check(
		prototype.combat.get_enemy_health(visible_target_id)
		< prototype.combat.get_enemy_maximum_health(visible_target_id)
		and is_equal_approx(
			prototype.combat.get_enemy_health(blocked_target_id),
			prototype.combat.get_enemy_maximum_health(blocked_target_id)
		),
		"Cane sectors damage an unobstructed enemy but never pass through basalt"
	)

	prototype.player.reset_player()
	prototype.combat.reset_combat()
	var sweep_origin := prototype.player.get_arena_position()
	var upper_enemy_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		sweep_origin + Vector2(58.0, -18.0)
	)
	var lower_enemy_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		sweep_origin + Vector2(68.0, 20.0)
	)
	var beyond_reach_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		sweep_origin + Vector2(prototype.combat.cane_reach_pixels + 80.0, 0.0)
	)
	var sector_hits := prototype.combat.perform_bonus_cane_sweep(Vector2.RIGHT, true)
	_report.check(
		sector_hits == 2
		and prototype.combat.get_enemy_health(upper_enemy_id)
		< prototype.combat.get_enemy_maximum_health(upper_enemy_id)
		and prototype.combat.get_enemy_health(lower_enemy_id)
		< prototype.combat.get_enemy_maximum_health(lower_enemy_id)
		and is_equal_approx(
			prototype.combat.get_enemy_health(beyond_reach_id),
			prototype.combat.get_enemy_maximum_health(beyond_reach_id)
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
		EnemyKinds.Role.HUNTER,
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
	_report.check(
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
		EnemyKinds.Role.SABOTEUR,
		catalyst_position
	)
	prototype.combat.simulate_step(0.0)
	prototype.combat.saboteur_profile.first_territory_action_delay_seconds = (
		original_saboteur_delay
	)
	_report.check(
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
		EnemyKinds.Role.CORRUPTOR,
		mature_green_position
	)
	prototype.combat.simulate_step(0.0)
	prototype.combat.corruptor_profile.first_territory_action_delay_seconds = (
		original_corruptor_delay
	)
	SmokeFixtures.step_field(prototype.territory_field, 1)
	var green_after_corruption := (
		prototype.territory_field.get_control_at_local(mature_green_position)
	)
	_report.check(
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
		EnemyKinds.Role.WARDEN,
		mature_green_position
	)
	prototype.combat.simulate_step(0.0)
	prototype.combat.warden_profile.first_territory_action_delay_seconds = original_warden_delay
	SmokeFixtures.step_field(prototype.territory_field, 1)
	_report.check(
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
		EnemyKinds.Role.COLONIZER,
		Vector2(700.0, 360.0)
	)
	prototype.combat.simulate_step(0.0)
	prototype.combat.colonizer_profile.first_territory_action_delay_seconds = (
		original_colonizer_delay
	)
	_report.check(
		colonizer_id != -1
		and prototype.combat.get_active_enemy_count_by_role(
			EnemyKinds.Role.COLONY_CORE
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
		EnemyKinds.Role.COLONY_CORE,
		mature_green_position
	)
	prototype.combat.simulate_step(0.0)
	prototype.combat.colony_core_profile.first_territory_action_delay_seconds = original_core_delay
	SmokeFixtures.step_field(prototype.territory_field, 1)
	_report.check(
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
			EnemyKinds.Role.HUNTER,
			kill_position + Vector2(float(index) * 3.0, 0.0)
		)
		prototype.combat.debug_damage_enemy(enemy_id, 10000.0)
	_report.check(
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
	_report.check(
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
	SmokeFixtures.step_field(prototype.territory_field, 18)
	var hostile_after := prototype.territory_field.get_control_at_local(hostile_seed_position)
	_report.check(
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
	_report.check(
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
	SmokeFixtures.step_field(prototype.territory_field, 8)
	var supported_after := prototype.territory_field.get_player_percent()
	prototype.territory_field.reset_field()
	SmokeFixtures.step_field(prototype.territory_field, 8)
	var unbloomed_after := prototype.territory_field.get_player_percent()
	_report.check(
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
		EnemyKinds.Role.HUNTER,
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
	_report.check(
		planted_bloom and bloom_on_owned_ground,
		"an automatic Bloom charges on the player's own frontier rather than at the enemy"
	)
	_report.check(
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
	_report.check(
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
	_report.check(
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
	_report.check(
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
	_report.check(
		all_lines_open,
		"entering an Adaptation opens all four of its rank-3 lines at once"
	)
	# A second uncommitted line fills Core 2 and freezes the Evolution, with no
	# milestone and no timer involved.
	SmokeFixtures.take_offered_upgrade(prototype, Progression.UpgradeId.ROOT_MATURATION)
	_report.check(
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
	_report.check(
		narrowed_to_owned,
		"drafts narrow to the owned Adaptations once no slot is open"
	)
	# Running the clock out never offers an Adaptation: the room for a Branch is
	# earned from the Elite and the Boss, not from a timer.
	prototype.debug_advance_time(600.0)
	prototype.debug_advance_time(600.0)
	_report.check(
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
	_report.check(
		prototype.progression.unlocked_branch_slots == 1
		and prototype.progression.has_branch_slot_open(),
		"defeating the Elite earns room for a third Adaptation"
	)
	_report.check(
		branch_draft_offered and branch_draft_is_unowned,
		"the Elite's Adaptation reward is a draft of unowned lines, never a Path screen"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	var authored_rerolls := prototype.progression.rerolls_per_run
	SmokeFixtures.seed_run_adaptations(
		prototype,
		Progression.PathId.SPORE,
		Progression.PathId.ROOT
	)
	_report.check(
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
	_report.check(
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
		SmokeFixtures.seed_run_adaptations(
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
		SmokeFixtures.seed_run_adaptations(
			prototype,
			Progression.PathId.SPORE,
			Progression.PathId.ROOT
		)
		prototype.progression.add_xp(prototype.progression.get_required_xp())
		var replayed := ""
		for option_id in prototype.progression.get_pending_upgrade_options():
			replayed += "%d," % option_id
		replays[replayed] = true
	_report.check(
		openings.size() >= 8
		and rolled_seeds.size() == 12
		and replays.size() == 1,
		"restarting deals a different hand, and a pinned seed replays one exactly "
			+ "(%d openings and %d seeds in 12 runs)" % [openings.size(), rolled_seeds.size()]
	)
	prototype.progression.authored_run_seed = pinned_seed
	prototype.reset_run()
	SmokeFixtures.seed_run_adaptations(
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
	_report.check(
		reroll_attempts > 0
		and reroll_changes == reroll_attempts
		and not prototype.progression.get_pending_upgrade_options().is_empty(),
		"every spent reroll returns a genuinely different offer"
	)
	for _spend_reroll in range(authored_rerolls - 1):
		prototype.progression.reroll_upgrade_choice()
	var exhausted_reroll := prototype.progression.reroll_upgrade_choice()
	_report.check(
		not exhausted_reroll
		and prototype.progression.rerolls_remaining == 0
		and prototype.choice_panel.reroll_button.disabled
		and not prototype.progression.get_pending_upgrade_options().is_empty(),
		"a run spends exactly its authored rerolls and keeps its offer once they are gone"
	)
	prototype._choose_displayed_option(0)
	_report.check(
		not prototype.choice_panel.reroll_button.visible,
		"the reroll control disappears with the draft panel"
	)
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	_report.check(
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
	_report.check(
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
	_report.check(
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
	_report.check(
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
	_report.check(
		prototype.territory_field.tuning.maturation_per_second > root_base_maturation
		and prototype.root_director.get_lateral_reach() > root_base_reach
		and prototype.territory_field.get_mature_resistance_multiplier()
		> root_base_resistance
		and prototype.territory_field.tuning.regeneration_per_second > 0.0
		and prototype.root_director.get_network_bonus() > root_base_network,
		"Root's lines raise maturation, Lateral reach, Mature Strength, and Root Potency"
	)
	_report.check(
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
	var lateral_spot := SmokeFixtures.find_owned_cell_position(prototype)
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
	_report.check(
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
	var healing_cells := SmokeFixtures.find_player_frontier_cells(prototype.territory_field, 1)
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
	_report.check(
		regenerated > unregenerated,
		"Regeneration heals damaged Green that the player still holds"
	)

	prototype.territory_field.reset_field()
	var root_mature_cell := SmokeFixtures.find_player_frontier_cells(prototype.territory_field, 1)[0]
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
	_report.check(
		hardened_loss > 0.0 and hardened_loss < plain_loss,
		"Mature Resistance hardens settled Plant against erosion"
	)

	_report.check(
		prototype.progression.get_pair_evolution_id()
		== Progression.EvolutionId.SEED_BANK,
		"Spore plus Root pairs into Seed Bank"
	)
	prototype.progression.debug_select_paths(
		Progression.PathId.BLOOM,
		Progression.PathId.ROOT
	)
	_report.check(
		prototype.progression.get_pair_evolution_id()
		== Progression.EvolutionId.FLOWERING_SEASON,
		"Bloom plus Root pairs into Flowering Season"
	)
	prototype.progression.debug_select_paths(
		Progression.PathId.BRAMBLE,
		Progression.PathId.ROOT
	)
	_report.check(
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
	SmokeFixtures.step_field(prototype.territory_field, 2)
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
	_report.check(
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
	_report.check(
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
	var interior_index := SmokeFixtures.find_deep_owned_cell(
		prototype.territory_field,
		prototype.combat.bramble_frontier_band_pixels
	)
	var interior_spot := prototype.territory_field.cell_to_local(
		Vector2(interior_index % field_width_og, interior_index / field_width_og)
	)
	# Fresh interior is hazardous but never wakes the Root Network.
	prototype.territory_field._maturity[interior_index] = 0.20
	prototype.territory_field._territory_age[interior_index] = 0.0
	var fresh_enemy := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.HUNTER,
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
	var mature_enemy := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.HUNTER,
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
	_report.check(
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
	var cascade_enemy: EnemyState = SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.HUNTER,
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
	_report.check(
		not base_chain_queued,
		"base Old Growth erupts without chaining until Ancient Fury buys the cascade"
	)
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.EVOLUTION_ANCIENT_FURY
	] = 3
	prototype._apply_progression_modifiers()
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	cascade_enemy = SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.HUNTER,
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
	_report.check(
		not cascade_enemy.active
		and queued_cascade
		and prototype.combat.get_active_root_eruption_count() > cascade_eruptions_before,
		"a root eruption kill chains another eruption through the Root Network"
	)
	_report.check(
		prototype.combat.old_growth_sfx != null
		and old_growth_cue_count == old_growth_cue_before + 1
		and eruptions_this_cascade > 1,
		"the Root Network erupting plays its cue, and a cascade swells once rather than per eruption"
	)

	prototype.combat.set_bramble_modifiers(true, 0.30, 1.0, 0.0, 4.0, 0.0, false)
	prototype.combat.reset_combat()
	var disabled_enemy := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.HUNTER,
		interior_spot
	)
	disabled_enemy.entanglement = 1.0
	var disabled_eruptions_before := prototype.combat.get_active_root_eruption_count()
	prototype.combat.simulate_step(0.0)
	_report.check(
		prototype.combat.get_active_root_eruption_count() == disabled_eruptions_before,
		"Mature ground never erupts for a run that has not evolved Old Growth"
	)

	SmokeEvolutions.run(_report, prototype)

	SmokeVineFruitBloom.run(_report, prototype)

	SmokeOvergrowManEater.run(_report, prototype)

	SmokePruning.run(_report, prototype)

	SmokeBrambleRoot.run(_report, prototype)

	SmokeEconomyClover.run(_report, prototype)

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
