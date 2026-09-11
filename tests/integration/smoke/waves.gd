## The wave timeline: when a wave starts, what it sends, and what each wave is
## worth.
##
## Every check here drives `wave_director`'s clock directly rather than waiting one
## out, because a wave is minutes long and there are twenty of them. What is being
## measured is the schedule and the scaling an enemy carries away from it, not the
## fight.
##
## The one thing it does wait out is the ambient track, which needs real time to
## advance a playback position and cannot be driven by a clock the suite sets.
class_name SmokeWaves
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype._set_simulation_paused(true)
	report.check(
		is_equal_approx(prototype.wave_director.wave_grace_period_seconds, 5.0)
		and not prototype.is_wave_grace_period_active()
		and is_zero_approx(prototype.get_wave_grace_remaining_seconds())
		and prototype.wave_label.text == (
			"WAVE 1 / %d" % prototype.get_final_wave_number()
		),
		"wave one begins immediately without a grace countdown"
	)
	prototype.advance_run(0.65)
	report.check(
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
	report.check(
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
	report.check(
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
	report.check(
		prototype.get_current_wave_number() == 2
		and prototype.combat.get_enemy_xp_value(wave_two_hunter_id) == 3
		and prototype.combat.get_enemy_xp_value(wave_two_boss_id) == 110
		and is_equal_approx(
			prototype.combat.get_enemy_territory_erosion_scale(wave_two_grazer_id),
			1.10
		),
		"wave two raises common and boss XP while adding 10% territory pressure"
	)
	report.check(
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
	report.check(
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
	report.check(
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
	report.check(
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
	report.check(
		ambient_music_stream != null
		and ambient_music_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
		and ambient_music_stream.loop_begin == 0
		and ambient_music_stream.loop_end
		== roundi(ambient_music_stream.get_length() * ambient_music_stream.mix_rate),
		"the forest theme loops across its complete sample range"
	)
	report.check(
		prototype.run_audio.ambient_music.autoplay
		and prototype.run_audio.ambient_music == prototype.get_node("RunAudio/AmbientMusic")
		and prototype.run_audio.ambient_music.playing
		and prototype.run_audio.ambient_music.bus == prototype.audio_settings.music_bus_name,
		"the scene-authored forest theme is already playing on the Music bus"
	)
	# Real time has to pass for a playback position to advance, and the timer is
	# reached through the run: `create_timer` is the SceneTree's own, and this block
	# no longer runs inside the SceneTree script.
	await prototype.get_tree().create_timer(0.25).timeout
	report.check(
		prototype.run_audio.ambient_music.playing
		and prototype.run_audio.ambient_music.get_playback_position() > 0.05,
		"forest music remains active and advances beyond its opening instant"
	)
	prototype.pause_menu.volume_slider.value = 100.0
	report.check(
		not AudioServer.is_bus_mute(sfx_bus_index)
		and is_equal_approx(
			db_to_linear(AudioServer.get_bus_volume_db(sfx_bus_index)),
			prototype.audio_settings.sfx_max_linear_volume
		)
		and prototype.pause_menu.volume_value.text == "100%",
		"displayed SFX volume 100% is capped at 20% linear output"
	)
	prototype.pause_menu.volume_slider.value = 37.0
	report.check(
		not AudioServer.is_bus_mute(sfx_bus_index)
		and is_equal_approx(
			db_to_linear(AudioServer.get_bus_volume_db(sfx_bus_index)),
			0.37 * prototype.audio_settings.sfx_max_linear_volume
		)
		and prototype.pause_menu.volume_value.text == "37%",
		"the pause-menu slider scales the capped SFX bus immediately"
	)
	prototype.pause_menu.volume_slider.value = 0.0
	report.check(
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
	report.check(
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
	report.check(
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
	report.check(
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
	report.check(
		not prototype.is_pause_menu_open()
		and not prototype.pause_menu.visible
		and not prototype.combat.simulation_paused,
		"Resume closes the pause overlay and restores gameplay simulation"
	)
	prototype.debug_advance_time(12.0)
	prototype._open_pause_menu()
	prototype.pause_menu.glossary_button.pressed.emit()
	report.check(
		prototype._mechanics_help.is_glossary_open()
		and prototype.is_pause_menu_open()
		and prototype.pause_menu.visible,
		"Glossary opens from the pause menu without resuming simulation"
	)
	prototype._close_glossary()
	report.check(
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
	report.check(hunter_id != -1, "a pooled Hunter can be spawned")
	report.check(
		not prototype.combat.is_enemy_active(hunter_id),
		"the automatic base Cane kills a Hunter inside its facing sector"
	)
	report.check(
		prototype.combat.cane_swing_sfx != null
		and prototype.combat.get_cane_sfx_play_count() > 0
		and prototype.combat._cane_audio.bus == prototype.audio_settings.sfx_bus_name,
		"each automatic Cane sweep plays the authored swing SFX"
	)
	report.check(
		observed_hit_flash and observed_damage_number,
		"Cane damage produces an enemy hit flash and a pooled floating number"
	)
	report.check(prototype.combat.get_active_pickup_count() > 0, "enemy death produces pooled XP")
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
	report.check(
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
	report.check(
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
	report.check(
		is_equal_approx(prototype.combat.get_last_xp_collect_pitch_scale(), 1.0),
		"the first XP circle after the timeout plays at default pitch"
	)
