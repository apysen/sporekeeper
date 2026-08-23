class_name PhaseBPrototype
extends Node2D

enum RunState {
	RUNNING,
	VICTORY,
	DEFEAT,
}

enum ChoiceKind {
	NONE,
	UPGRADE,
	RELIC,
	PATH,
	BREAKTHROUGH,
}

@export_group("Gameplay Components")
## Authoritative territory simulation used for ownership, maturity, and run-loss checks.
@export var territory_field: TerritoryField
## Presentation adapter that draws the territory field and authored Seed/Bloom effects.
@export var overlay: TerritoryPrototypeOverlay
## Player component whose health and movement state this run coordinates.
@export var player: PhaseBPlayer
## Combat component responsible for enemies, Thornshot, damage, pickups, and combat audio.
@export var combat: PhaseBCombatDirector
## Progression component responsible for XP drafts, Biomass, relics, and evolution.
@export var progression: PhaseBProgression
## Evolutions component owning every Evolution's state and tuning.
@export var evolutions: PhaseBEvolutions
## Ecosystem Metabolism component that automates the Biomass economy and owns
## Photosynthesis, Meristem, Cambium, their Breakthroughs, and Overgrow.
@export var metabolism: PhaseBMetabolism
## Relic component that owns every triggered relic: its counters, its cooldowns,
## its per-wave state, and the persistent objects relics leave in the arena.
@export var relic_director: PhaseBRelicDirector
## Wave component responsible for the run timeline, scaling, and enemy reinforcement schedule.
@export var wave_director: PhaseBWaveDirector
## Plant component responsible for Seeds, Blooms, explosions, and Super Bloom chains.
@export var spore_director: PhaseBSporeDirector
## Bloom component that owns the Bloom cadence, detonations, and Bloom evolutions.
@export var bloom_director: PhaseBBloomDirector
## Bramble component that owns that path's tuning and pushes it into the systems.
@export var bramble_director: PhaseBBrambleDirector
## Root component that owns that path's tuning and its field rules.
@export var root_director: PhaseBRootDirector
## Man-Eater component: the Legendary relic's Hunger, its Bite, and the meal it
## turns back into Green.
@export var man_eater: PhaseBManEater
## Pruning component that owns the cycle, its Cuttings, and Pruned Ground.
@export var pruning_director: PhaseBPruningDirector
## Shared SFX and music bus names plus the pause-slider output caps.
@export var audio_settings: PhaseBAudioSettings

@export_group("Boss Feedback")
## Pixel radius of the visible hostile pulse emitted when the boss erupts.
@export_range(16.0, 300.0, 1.0) var eruption_pulse_radius_pixels := 96.0

@export_group("Run Survival")
## Seconds Green territory may remain at zero before the run ends in defeat.
@export_range(0.0, 30.0, 0.5) var zero_territory_grace_seconds := 6.0

@export_group("Input")
## Stick deflection that counts as the player reaching for the controller. Below it
## a resting stick cannot flicker the focus ring on by itself.
@export_range(0.05, 1.0, 0.01) var controller_stick_deadzone := 0.35

@export_group("Event Banner")
## Seconds a major-event banner holds the battlefield before it fades away.
@export_range(0.5, 12.0, 0.1) var banner_seconds := 2.60
## Seconds of that time spent fading, so the banner leaves rather than vanishing.
@export_range(0.1, 6.0, 0.1) var banner_fade_seconds := 1.10

@export_group("Ecosystem Feedback")
## How much longer the border's answer to a purchase lingers than the release that
## caused it. A little over one keeps the visual alive to the end of the pour.
@export_range(0.5, 4.0, 0.05) var injection_visual_duration_scale := 1.35

@export_group("Relic Rewards")
## Waves between scheduled relic rewards; every Nth wave puts one on the table.
## Zero turns the schedule off and leaves relics to the elite and the boss.
@export_range(0, 12, 1) var relic_reward_wave_cycle := 4

@export_group("Interface Wiring")
## Audio player that starts and loops the authored ambient forest theme.
@export var ambient_music_audio: AudioStreamPlayer
## Progress bar that displays the player's current health fraction.
@export var health_bar: ProgressBar
## Label that displays current and maximum player health numerically.
@export var health_label: Label
## Progress bar that displays the percentage of the arena controlled by Green.
@export var territory_bar: ProgressBar
## Label that displays Green territory percentage and the Seed-progress tooltip.
@export var territory_label: Label
## Progress bar that displays XP earned toward the next level.
@export var xp_bar: ProgressBar
## Label that displays the current level and numerical XP requirement.
@export var xp_label: Label
## Label that displays wave number, wave name, time remaining, and active hostiles.
@export var run_label: Label
## The hostile-count warning, its own node so the panel can place it.
@export var hostile_label: Label
## Label that displays the Biomass economy: Reserve, Production, Consumption, Net.
@export var biomass_label: Label
## Label that displays selected Plant paths, mastery readiness, and active evolution.
@export var evolution_label: Label
## Label that lists relics acquired during the current run.
@export var relics_label: Label
## Label used for milestone, combat, upgrade, and failure-status messages.
## Row of rounded slots showing which relics the run holds.
@export var relic_slots: PhaseBUpgradeSlots
## Label that summarizes the six upgrade-line slots in the bottom tray.
@export var slots_label: Label
## Row of rounded slots showing the growth lines the run has taken.
@export var upgrade_slots: PhaseBUpgradeSlots
## Panel shown while the player chooses an upgrade or relic.
@export var choice_panel: Panel
## Heading label for the active upgrade or relic draft.
@export var choice_header: Label
## Button used for the first authored upgrade or relic choice.
@export var choice_button_one: Button
## Button used for the second authored upgrade or relic choice.
@export var choice_button_two: Button
## Button used for the third authored upgrade or relic choice.
@export var choice_button_three: Button
## Button used for a fourth option, which only path offers currently need.
@export var choice_button_four: Button
## Button that spends one of the run's rerolls to redraw the current upgrade offer.
@export var choice_reroll_button: Button
## Allocation control for Photosynthesis. Left click adds a point, right click
## takes one back; the bar it draws is the level's automatic progress.
@export var photosynthesis_button: PhaseBMetabolismButton
## Allocation control for Meristem; see Photosynthesis Button.
@export var meristem_button: PhaseBMetabolismButton
## Allocation control for Cambium; see Photosynthesis Button.
@export var cambium_button: PhaseBMetabolismButton
## Button that spends half the Biomass Reserve as one Overgrow injection.
@export var overgrow_button: Button
## Label that reports the Breakthroughs the run holds and its next unlock.
@export var metabolism_label: Label
## Bottom drawer that owns every detailed Biomass decision. Closed by default: the
## sidebar says what is true, and decisions are made down here.
@export var metabolism_drawer: Control
## Bottom-bar control that opens the Biomass drawer.
@export var biomass_button: Button
## Large transient banner over the battlefield for major progression events.
@export var banner_label: Label
## Side-panel button that resets the current run to its initial state.
@export var reset_button: Button
## Panel shown when the run reaches victory or defeat.
@export var result_panel: Panel
## Heading label used for the victory or defeat result.
@export var result_header: Label
## Label that explains the outcome and summarizes final run statistics.
@export var result_detail: Label
## Full-screen interface layer shown while the pause menu is open.
@export var pause_overlay: Control
## Button that closes the pause menu and resumes gameplay.
@export var pause_resume_button: Button
## Slider that controls the SFX bus within the configured output cap.
@export var pause_volume_slider: HSlider
## Label that displays the current SFX slider percentage.
@export var pause_volume_value: Label
## Slider that controls the Music bus independently within its output cap.
@export var pause_music_volume_slider: HSlider
## Label that displays the current Music slider percentage.
@export var pause_music_volume_value: Label
## Button that toggles between windowed and fullscreen display modes.
@export var pause_fullscreen_button: Button
## Button that resets the current run while the pause menu is open.
@export var pause_restart_button: Button
## Button that exits the running game application.
@export var pause_quit_button: Button

var choice_buttons: Array[Button] = []
var metabolism_buttons: Array[PhaseBMetabolismButton] = []

var _run_state := RunState.RUNNING
var _final_stand_announced := false
## The growth-line caption as authored on the label, captured before anything
## overwrites it, so editing the text in the editor survives into play. Two integer
## placeholders receive the filled and total slots, one receives the filled count,
## and text with none is shown exactly as authored.
var _slots_label_format := "GROWTH LINES  //  %d OF %d"
var _choice_kind := ChoiceKind.NONE
var _choice_ids := PackedInt32Array()
var _zero_territory_remaining := 0.0
var _owed_wave_relics := 0
var _banner_remaining := 0.0
var _drawer_open := false
## Whether the last input came from a controller. The focus ring is a controller
## affordance: with a mouse in hand it is a white box sitting on a button nobody is
## about to press, so it is only shown once a pad is actually being used.
var _controller_active := false
## Authored row lengths, captured before the rows are trimmed to what the run has.
var _maximum_upgrade_slots := 8
var _maximum_relic_slots := 6
var _hud_accumulator := 0.0
var _base_natural_spread_rate := 0.0
var _base_maturity_resistance_bonus := 0.0
var _base_pressure_advection := 0.0
var _base_small_fragment_decay := 0.0
var _pause_menu_open := false
var _sfx_bus_index := -1
var _music_bus_index := -1


func _ready() -> void:
	assert(territory_field != null, "PhaseBPrototype requires TerritoryField")
	assert(overlay != null, "PhaseBPrototype requires TerritoryPrototypeOverlay")
	assert(player != null, "PhaseBPrototype requires PhaseBPlayer")
	assert(combat != null, "PhaseBPrototype requires PhaseBCombatDirector")
	assert(progression != null, "PhaseBPrototype requires PhaseBProgression")
	assert(wave_director != null, "PhaseBPrototype requires PhaseBWaveDirector")
	assert(spore_director != null, "PhaseBPrototype requires PhaseBSporeDirector")
	assert(bloom_director != null, "PhaseBPrototype requires PhaseBBloomDirector")
	assert(bramble_director != null, "PhaseBPrototype requires PhaseBBrambleDirector")
	assert(root_director != null, "PhaseBPrototype requires PhaseBRootDirector")
	assert(man_eater != null, "PhaseBPrototype requires PhaseBManEater")
	assert(metabolism != null, "PhaseBPrototype requires PhaseBMetabolism")
	assert(relic_director != null, "PhaseBPrototype requires PhaseBRelicDirector")
	assert(pruning_director != null, "PhaseBPrototype requires PhaseBPruningDirector")
	assert(audio_settings != null, "PhaseBPrototype requires PhaseBAudioSettings")
	assert(metabolism_drawer != null, "PhaseBPrototype requires the Biomass drawer")
	# The authored row lengths are the ceiling the run grows toward, so they are
	# read once before either row is trimmed to what the run currently holds.
	if upgrade_slots != null:
		_maximum_upgrade_slots = upgrade_slots.slot_count
	if relic_slots != null:
		_maximum_relic_slots = relic_slots.slot_count
	assert(biomass_button != null, "PhaseBPrototype requires the Biomass drawer button")
	assert(banner_label != null, "PhaseBPrototype requires the event banner")
	assert(ambient_music_audio != null, "PhaseBPrototype requires its ambient music player")
	choice_buttons = [
		choice_button_one,
		choice_button_two,
		choice_button_three,
		choice_button_four,
	]
	metabolism_buttons = [
		photosynthesis_button,
		meristem_button,
		cambium_button,
	]
	var required_interface_controls: Array[Control] = [
		health_bar,
		health_label,
		territory_bar,
		territory_label,
		xp_bar,
		xp_label,
		run_label,
		hostile_label,
		biomass_label,
		evolution_label,
		relics_label,
		relic_slots,
		slots_label,
		upgrade_slots,
		choice_panel,
		choice_header,
		choice_button_one,
		choice_button_two,
		choice_button_three,
		choice_button_four,
		choice_reroll_button,
		photosynthesis_button,
		meristem_button,
		cambium_button,
		overgrow_button,
		metabolism_label,
		reset_button,
		result_panel,
		result_header,
		result_detail,
		pause_overlay,
		pause_resume_button,
		pause_volume_slider,
		pause_volume_value,
		pause_music_volume_slider,
		pause_music_volume_value,
		pause_fullscreen_button,
		pause_restart_button,
		pause_quit_button,
	]
	for interface_control in required_interface_controls:
		assert(
			interface_control != null,
			"PhaseBPrototype has an unwired Interface reference at index %d of %d"
			% [required_interface_controls.find(interface_control), required_interface_controls.size()]
		)

	_base_natural_spread_rate = territory_field.tuning.natural_spread_rate
	_base_maturity_resistance_bonus = territory_field.tuning.maturity_resistance_bonus
	_base_pressure_advection = territory_field.tuning.pressure_advection
	_base_small_fragment_decay = territory_field.tuning.small_fragment_decay_per_second

	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	combat.xp_collected.connect(progression.add_xp)
	combat.elite_defeated.connect(_on_elite_defeated)
	combat.boss_defeated.connect(_on_boss_defeated)
	wave_director.wave_began.connect(_on_wave_began)
	wave_director.elite_arrived.connect(_on_elite_arrived)
	wave_director.boss_arrived.connect(_on_boss_arrived)
	wave_director.final_invasion_began.connect(_on_final_invasion_began)
	wave_director.cleanup_began.connect(_on_cleanup_began)
	if slots_label != null:
		_slots_label_format = slots_label.text
	spore_director.status_requested.connect(_set_status)
	bloom_director.status_requested.connect(_set_status)
	combat.boss_erupted.connect(_on_boss_erupted)
	man_eater.status_requested.connect(_set_status)
	metabolism.status_requested.connect(_set_status)
	relic_director.status_requested.connect(_set_status)
	progression.relics_changed.connect(relic_director.apply_relics)
	metabolism.levels_changed.connect(_update_metabolism_controls)
	metabolism.system_unlocked.connect(_on_metabolism_system_unlocked)
	metabolism.purchased.connect(_on_metabolism_purchased)
	biomass_button.pressed.connect(_toggle_metabolism_drawer)
	metabolism.breakthroughs_changed.connect(_on_breakthroughs_changed)
	metabolism.breakthrough_choice_requested.connect(_on_breakthrough_choice_requested)
	metabolism.production_milestone_reached.connect(_on_production_milestone_reached)
	pruning_director.status_requested.connect(_set_status)
	progression.upgrade_choice_requested.connect(_on_upgrade_choice_requested)
	progression.relic_choice_requested.connect(_on_relic_choice_requested)
	progression.path_choice_requested.connect(_on_path_choice_requested)
	progression.upgrades_changed.connect(_apply_progression_modifiers)
	progression.paths_changed.connect(_apply_progression_modifiers)
	progression.metabolism_changed.connect(_apply_progression_modifiers)
	progression.relics_changed.connect(_apply_progression_modifiers)
	progression.evolution_changed.connect(_on_evolution_changed)
	progression.xp_changed.connect(_on_xp_changed)
	progression.biomass_changed.connect(_on_biomass_changed)
	territory_field.metrics_changed.connect(_on_territory_metrics_changed)

	for index in range(choice_buttons.size()):
		choice_buttons[index].pressed.connect(_choose_displayed_option.bind(index))
	for index in range(metabolism_buttons.size()):
		metabolism_buttons[index].pressed.connect(_buy_metabolism_level.bind(index))
	overgrow_button.pressed.connect(_press_overgrow)
	metabolism.injection_started.connect(_on_injection_started)
	choice_reroll_button.pressed.connect(_reroll_upgrade_choice)
	progression.rerolls_changed.connect(_on_rerolls_changed)
	reset_button.pressed.connect(reset_run)
	pause_resume_button.pressed.connect(_close_pause_menu)
	pause_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	pause_music_volume_slider.value_changed.connect(_on_music_volume_changed)
	pause_fullscreen_button.pressed.connect(_toggle_fullscreen)
	pause_restart_button.pressed.connect(_restart_from_pause_menu)
	pause_quit_button.pressed.connect(_quit_from_pause_menu)
	_configure_ambient_music()
	_configure_volume_control()
	_update_fullscreen_button()

	overlay.show_annotations = false
	reset_run()


func _process(delta: float) -> void:
	if (
		_run_state == RunState.RUNNING
		and _choice_kind == ChoiceKind.NONE
		and not _pause_menu_open
	):
		advance_run(delta)
	_hud_accumulator += delta
	if _hud_accumulator >= 0.10:
		_hud_accumulator = 0.0
		_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	_note_input_device(event)
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		if _pause_menu_open:
			_close_pause_menu()
		elif _choice_kind == ChoiceKind.NONE:
			_open_pause_menu()
		get_viewport().set_input_as_handled()
		return
	if _pause_menu_open:
		return
	match event.keycode:
		KEY_R:
			reset_run()
		KEY_F6:
			debug_advance_time(120.0)
		KEY_F7:
			progression.add_xp(progression.get_required_xp())
			_set_status("Debug: enough XP added for the next upgrade choice.")
		KEY_F8:
			progression.debug_complete_evolution_requirements()
			_set_status(
				"Debug: %s mastery completed; the evolution is offered at the next level."
				% _get_path_pair_label()
			)
		KEY_F9:
			if wave_director.debug_spawn_boss():
				_set_status("Debug: the Burrower has surfaced early.")
		KEY_F10:
			# The relic pool is far larger than a run sees, so testing one by hand
			# needs a way to be offered relics without farming elites.
			if progression.request_relic_choice():
				_set_status("Debug: a relic reward is on the table.")
		KEY_B:
			_toggle_metabolism_drawer()
		KEY_F11:
			_report_man_eater_state()


func _report_man_eater_state() -> void:
	# Hunger is invisible field-adjacent state, so a run that has not seen the Maw
	# come up has no way to tell whether it is close. This prints what the relic
	# actually holds.
	var report := (
		"MAN-EATER  held=%s  hunger %.1f / %.1f (%d%%)  meals %d  swallowed %d  lockout %.1fs"
		% [
			"yes" if man_eater.is_held() else "no",
			man_eater.get_hunger(),
			man_eater.hunger_threshold,
			int(round(man_eater.get_hunger_fraction() * 100.0)),
			man_eater.get_meal_count(),
			man_eater.get_swallowed_count(),
			man_eater.get_lockout_remaining(),
		]
	)
	print(report)
	_set_status(report)


func advance_run(delta: float) -> void:
	if delta <= 0.0 or _run_state != RunState.RUNNING:
		return
	progression.tick_biomass(
		delta,
		territory_field.get_player_percent(),
		territory_field.get_mature_player_percent(),
		root_director.get_biomass_yield_multiplier()
	)

	wave_director.advance(delta)
	# Path milestones share the panel with relic rewards and land on the same wave
	# boundaries, so the path choice is asked first and the relic waits its turn.
	_request_due_path_choice()
	_grant_owed_wave_relic()
	if _choice_kind != ChoiceKind.NONE:
		return
	metabolism.advance(delta)
	relic_director.advance(delta)
	spore_director.advance(delta)
	bloom_director.advance(delta)
	bramble_director.advance(delta)
	man_eater.advance(delta)
	pruning_director.advance(delta)
	_update_territory_failure(delta)
	_advance_banner(delta)

	if wave_director.is_complete():
		# The timeline running out stops reinforcements; it does not win the run.
		# Whatever is still standing has to be cleared first.
		if not _final_stand_announced:
			_final_stand_announced = true
			_set_status(
				"FINAL STAND — the invasion is spent. Clear the last hostiles to win."
			)
		if combat.get_active_enemy_count() == 0:
			_finish_run(true, "The final invasion broke against a living frontier.")


func reset_run() -> void:
	_run_state = RunState.RUNNING
	_final_stand_announced = false
	_choice_kind = ChoiceKind.NONE
	_choice_ids.clear()
	_pause_menu_open = false
	_zero_territory_remaining = zero_territory_grace_seconds
	_owed_wave_relics = 0
	_hud_accumulator = 999.0
	choice_panel.visible = false
	result_panel.visible = false
	pause_overlay.visible = false
	territory_field.tuning.natural_spread_rate = _base_natural_spread_rate
	territory_field.tuning.maturity_resistance_bonus = _base_maturity_resistance_bonus
	territory_field.tuning.pressure_advection = _base_pressure_advection
	territory_field.tuning.small_fragment_decay_per_second = _base_small_fragment_decay
	root_director.reset_director()
	territory_field.simulation_paused = false
	overlay.effects_paused = false
	overlay.clear_effects()
	territory_field.reset_field()
	progression.reset_progression()
	metabolism.reset_metabolism()
	relic_director.reset_director()
	player.reset_player()
	combat.reset_combat()
	wave_director.reset_director()
	spore_director.reset_director()
	bloom_director.reset_director()
	man_eater.reset_man_eater()
	pruning_director.reset_director()
	_refresh_simulation_pause()
	_apply_progression_modifiers()
	_set_status("The frontier is alive. Move with WASD; Thornshot fires automatically.")
	_update_hud()


func debug_advance_time(seconds: float) -> void:
	if _run_state != RunState.RUNNING:
		return
	wave_director.debug_advance_time(seconds)
	_request_due_path_choice()
	_grant_owed_wave_relic()
	_set_status("Debug: timeline advanced to %s." % _format_time(get_elapsed_seconds()))
	_update_hud()


func get_elapsed_seconds() -> float:
	return wave_director.elapsed_seconds


func get_run_state() -> int:
	return _run_state


func get_kills_toward_seed() -> int:
	return spore_director.get_kills_toward_seed()


func get_current_wave_number() -> int:
	return wave_director.get_current_wave_number()


func is_wave_grace_period_active() -> bool:
	return wave_director.is_grace_period_active()


func get_wave_grace_remaining_seconds() -> float:
	return wave_director.get_grace_remaining_seconds()


func _update_territory_failure(delta: float) -> void:
	if territory_field.get_player_percent() > 0.01:
		_zero_territory_remaining = zero_territory_grace_seconds
		return
	_zero_territory_remaining -= delta
	if _zero_territory_remaining <= 0.0:
		_finish_run(false, "Green territory remained extinct beyond the grace period.")


func _on_wave_began(wave_number: int) -> void:
	if relic_reward_wave_cycle <= 0 or wave_number % relic_reward_wave_cycle != 0:
		return
	_owed_wave_relics += 1


func _grant_owed_wave_relic() -> void:
	# A wave can turn over while a draft or a path choice is already on the table,
	# so the reward waits for the panel to clear instead of being dropped. An
	# offer that finds nothing left to give pays out as Biomass inside
	# Progression, which still settles the debt.
	if _owed_wave_relics <= 0 or _run_state != RunState.RUNNING:
		return
	if _choice_kind != ChoiceKind.NONE or progression.has_pending_relic_choice():
		return
	_owed_wave_relics -= 1
	if progression.request_relic_choice():
		_set_status(
			"WAVE %d — the frontier yields a relic." % wave_director.get_current_wave_number()
		)


func _on_elite_arrived() -> void:
	_set_status("ELITE ROOTBREAKER — defeat it to choose a relic.")


func _on_boss_arrived() -> void:
	_set_status("THE BURROWER SURFACES — its eruptions erase Green.")


func _on_final_invasion_began() -> void:
	_set_status("FINAL INVASION — hold the frontier for two more minutes.")


func _on_cleanup_began() -> void:
	_set_status("LAST ROOTS — no more reinforcements. Survive the remaining hostiles.")


func _on_elite_defeated() -> void:
	if not progression.request_relic_choice():
		_set_status("Elite defeated; its surplus converted into Biomass.")


func _on_boss_defeated() -> void:
	if progression.request_relic_choice():
		_set_status("BOSS DEFEATED — claim a relic from its remains.")
	else:
		_set_status("Boss defeated; the frontier absorbs its remaining Biomass.")

func _on_upgrade_choice_requested(options: PackedInt32Array) -> void:
	_show_choice(ChoiceKind.UPGRADE, options)


func _on_rerolls_changed(_remaining: int) -> void:
	_update_reroll_button()


func _reroll_upgrade_choice() -> void:
	if _choice_kind == ChoiceKind.RELIC:
		# A relic reward now shows three of a large pool, so redrawing it can
		# genuinely change what is on the table.
		if progression.reroll_relic_choice():
			_set_status(
				"Relic offer redrawn. %d reroll(s) left this run."
				% progression.get_relic_rerolls_remaining()
			)
		return
	if _choice_kind != ChoiceKind.UPGRADE:
		return
	if progression.reroll_upgrade_choice():
		_set_status("Draft rerolled. %d reroll(s) left this run." % progression.rerolls_remaining)


func _update_reroll_button() -> void:
	if not is_instance_valid(choice_reroll_button):
		return
	# Upgrade and relic drafts both sample a pool, so both can be redrawn. Path
	# and Breakthrough offers present every option there is, so they cannot.
	if _choice_kind == ChoiceKind.RELIC:
		choice_reroll_button.visible = true
		var relic_rerolls := progression.get_relic_rerolls_remaining()
		choice_reroll_button.disabled = relic_rerolls <= 0
		choice_reroll_button.text = "REROLL  (%d LEFT)" % relic_rerolls
		return
	choice_reroll_button.visible = _choice_kind == ChoiceKind.UPGRADE
	choice_reroll_button.disabled = progression.rerolls_remaining <= 0
	choice_reroll_button.text = "REROLL  (%d LEFT)" % progression.rerolls_remaining


func _on_relic_choice_requested(options: PackedInt32Array) -> void:
	_show_choice(ChoiceKind.RELIC, options)


func _on_path_choice_requested(options: PackedInt32Array, _selecting_primary: bool) -> void:
	_show_choice(ChoiceKind.PATH, options)


func _show_choice(kind: int, options: PackedInt32Array) -> void:
	_choice_kind = kind
	_choice_ids = options.duplicate()
	_update_reroll_button()
	match kind:
		ChoiceKind.UPGRADE:
			choice_header.text = "ROOT MEMORY"
		ChoiceKind.RELIC:
			choice_header.text = "ELITE RELIC"
		ChoiceKind.BREAKTHROUGH:
			var system_id := metabolism.get_pending_breakthrough_system()
			choice_header.text = "%s BREAKTHROUGH" % (
				PhaseBMetabolism.get_system_name(system_id).to_upper()
			)
		ChoiceKind.PATH:
			if progression.is_pending_primary_path_choice():
				choice_header.text = "PRIMARY PLANT PATH"
			elif progression.has_secondary_path():
				choice_header.text = "SUPPORT PLANT PATH"
			else:
				choice_header.text = "SECONDARY PLANT PATH"
	for index in range(choice_buttons.size()):
		var button := choice_buttons[index]
		if index >= _choice_ids.size():
			button.visible = false
			continue
		button.visible = true
		button.modulate = Color.WHITE
		var option_id := _choice_ids[index]
		if kind == ChoiceKind.UPGRADE and option_id == PhaseBProgression.EVOLUTION_DRAFT_OPTION:
			var pair_evolution := progression.get_pair_evolution_id()
			button.text = "%s   EVOLUTION\n%s" % [
				PhaseBEvolutions.get_evolution_name(pair_evolution),
				PhaseBEvolutions.get_evolution_description(pair_evolution),
			]
		elif kind == ChoiceKind.UPGRADE:
			var current_upgrade_level := progression.get_upgrade_level(option_id)
			button.text = "%s   LEVEL %d → %d\n%s" % [
				PhaseBProgression.get_upgrade_name(option_id),
				current_upgrade_level,
				current_upgrade_level + 1,
				progression.get_upgrade_description(option_id),
			]
		elif kind == ChoiceKind.RELIC:
			# Rarity is the readout of how much the relic changes, so it is named
			# on the button rather than only implied by the effect text.
			button.text = "%s   %s\n%s" % [
				PhaseBProgression.get_relic_name(option_id),
				PhaseBRelicCatalog.get_rarity_name(
					PhaseBRelicCatalog.get_rarity(option_id)
				),
				progression.get_relic_description(option_id),
			]
			button.modulate = PhaseBRelicCatalog.get_rarity_color(
				PhaseBRelicCatalog.get_rarity(option_id)
			)
		elif kind == ChoiceKind.BREAKTHROUGH:
			button.text = "%s\n%s" % [
				PhaseBMetabolism.get_breakthrough_name(option_id),
				PhaseBMetabolism.get_breakthrough_description(option_id),
			]
		else:
			button.text = "%s\n%s" % [
				PhaseBProgression.get_path_name(option_id).to_upper(),
				PhaseBProgression.get_path_description(option_id),
			]
	choice_panel.visible = true
	_refresh_simulation_pause()


func _choose_displayed_option(index: int) -> void:
	if index < 0 or index >= _choice_ids.size():
		return
	var selected_id := _choice_ids[index]
	var prior_kind := _choice_kind
	_choice_kind = ChoiceKind.NONE
	_choice_ids.clear()
	choice_panel.visible = false
	_update_reroll_button()
	if prior_kind == ChoiceKind.UPGRADE and selected_id == PhaseBProgression.EVOLUTION_DRAFT_OPTION:
		var evolved_pair := _get_path_pair_label()
		if progression.choose_pair_evolution():
			_set_status("%s has evolved into %s." % [
				evolved_pair,
				PhaseBEvolutions.get_evolution_name(progression.active_evolution),
			])
	elif prior_kind == ChoiceKind.UPGRADE:
		var committed_path := progression.get_upgrade_committed_path(selected_id)
		var commits_primary := not progression.has_primary_path()
		if progression.choose_upgrade(selected_id):
			if committed_path == PhaseBProgression.UNSELECTED_PATH:
				_set_status(
					"Upgrade rooted: %s." % PhaseBProgression.get_upgrade_name(selected_id)
				)
			else:
				_set_status("Upgrade rooted: %s. Your %s path is now %s." % [
					PhaseBProgression.get_upgrade_name(selected_id),
					"primary" if commits_primary else "secondary",
					PhaseBProgression.get_path_name(committed_path),
				])
	elif prior_kind == ChoiceKind.RELIC:
		if progression.choose_relic(selected_id):
			_set_status("Relic claimed: %s." % PhaseBProgression.get_relic_name(selected_id))
	elif prior_kind == ChoiceKind.BREAKTHROUGH:
		metabolism.choose_breakthrough(selected_id)
	else:
		if progression.choose_path(selected_id):
			_set_status("Path rooted: %s." % PhaseBProgression.get_path_name(selected_id))
	_request_due_path_choice()
	_grant_owed_wave_relic()
	_refresh_simulation_pause()


func _request_due_path_choice() -> void:
	if _choice_kind != ChoiceKind.NONE or _run_state != RunState.RUNNING:
		return
	var elapsed := get_elapsed_seconds()
	if (
		not progression.has_primary_path()
		and elapsed >= wave_director.primary_path_choice_seconds
	):
		progression.request_primary_path_choice()
		return
	if (
		progression.has_primary_path()
		and not progression.has_secondary_path()
		and elapsed >= wave_director.secondary_path_choice_seconds
	):
		progression.request_secondary_path_choice()
		return
	if (
		progression.is_tertiary_path_available()
		and elapsed >= wave_director.tertiary_path_choice_seconds
	):
		progression.request_tertiary_path_choice()


func _buy_metabolism_level(system_id: int) -> void:
	# One outright purchase. The world response comes from the Metabolism itself,
	# so what the player sees is the ecosystem answering, not a card animating.
	if metabolism.try_purchase(system_id):
		combat.play_plant_explosion_sfx()
	else:
		_set_status(
			"Not enough Biomass for %s yet."
			% PhaseBMetabolism.get_axis_name(system_id)
		)
	_update_metabolism_controls()


func _on_metabolism_purchased(system_id: int, level: int, _cost: float) -> void:
	if level % metabolism.breakthrough_level_interval == 0:
		return
	_set_status("%s LV. %d" % [
		PhaseBMetabolism.get_axis_name(system_id).to_upper(),
		level,
	])


func _on_metabolism_system_unlocked(system_id: int) -> void:
	# A new capability announces itself over the battlefield, is added to the
	# drawer, and is usable immediately. No lock icon ever sat there waiting.
	_show_banner("NEW ORGAN\n%s" % PhaseBMetabolism.get_system_name(system_id).to_upper())
	_set_status("%s — %s" % [
		PhaseBMetabolism.get_system_name(system_id).to_upper(),
		PhaseBMetabolism.get_unlock_line(system_id),
	])
	_update_metabolism_controls()


func _toggle_metabolism_drawer() -> void:
	_set_metabolism_drawer_open(not _drawer_open)


func _set_metabolism_drawer_open(open: bool) -> void:
	_drawer_open = open
	metabolism_drawer.visible = open
	biomass_button.text = "BIOMASS  [B]" if not open else "CLOSE  [B]"
	if open:
		_update_metabolism_controls()


func _show_banner(text: String) -> void:
	# Major events get the battlefield's attention briefly and then give it back.
	# Nothing here earns a permanent HUD section.
	if banner_label == null:
		return
	banner_label.text = text
	banner_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_banner_remaining = banner_seconds


func _advance_banner(delta: float) -> void:
	if _banner_remaining <= 0.0:
		return
	_banner_remaining = maxf(0.0, _banner_remaining - delta)
	var fade := clampf(_banner_remaining / maxf(0.05, banner_fade_seconds), 0.0, 1.0)
	banner_label.modulate = Color(1.0, 1.0, 1.0, fade)


func _on_injection_started(
	mass: float,
	pressure: float,
	cohesion: float,
	cells: PackedInt32Array
) -> void:
	# The border answers a purchase in the axis that was bought. Mass swells, Pressure
	# shoves outward, Cohesion knits along the frontier — three different actions, so
	# the player can tell which one they paid for without reading the number.
	var described := territory_field.describe_frontier_cells(cells)
	overlay.spawn_injection(
		described[0],
		described[1],
		mass,
		pressure,
		cohesion,
		metabolism.injection_ramp_seconds * injection_visual_duration_scale
	)


func _press_overgrow() -> void:
	if metabolism.try_overgrow():
		combat.play_plant_explosion_sfx()
	else:
		_set_status("Not enough Biomass banked to Overgrow yet.")
	_update_metabolism_controls()


func _on_breakthroughs_changed() -> void:
	_apply_progression_modifiers()


func _on_breakthrough_choice_requested(system_id: int, options: PackedInt32Array) -> void:
	# A Breakthrough is a behavioural fork, so it announces itself over the
	# battlefield and then holds the run while it is answered.
	_show_banner("%s LV. %d
BREAKTHROUGH READY" % [
		PhaseBMetabolism.get_axis_name(system_id).to_upper(),
		metabolism.get_level(system_id),
	])
	_show_choice(ChoiceKind.BREAKTHROUGH, options)


func _on_production_milestone_reached(per_second: float, _index: int) -> void:
	combat.play_old_growth_sfx()
	_show_banner("%s BIOMASS / SEC" % _format_compact(per_second))
	_set_status(
		"PRODUCTION MILESTONE — the ecosystem now makes %.0f Biomass every second."
		% per_second
	)


func _apply_progression_modifiers() -> void:
	if not is_instance_valid(territory_field) or not is_instance_valid(combat):
		return
	territory_field.tuning.natural_spread_rate = (
		_base_natural_spread_rate * progression.get_expansion_multiplier()
	)
	root_director.apply_modifiers(progression.get_maturation_multiplier())
	territory_field.tuning.maturity_resistance_bonus = (
		_base_maturity_resistance_bonus * progression.get_resistance_multiplier()
	)
	combat.set_combat_modifiers(
		progression.get_thornshot_damage_multiplier(),
		progression.get_thornshot_cooldown_multiplier(),
		progression.get_thornshot_target_count()
	)
	bramble_director.apply_modifiers(root_director.get_network_bonus())
	var evolution_rank := progression.get_evolution_upgrade_level()
	combat.set_evolution_upgrade_modifiers(
		evolutions.briar_payload_trigger_bonus if evolution_rank >= 2 else 0.0,
		evolutions.briar_payload_chain_bonus if evolution_rank >= 4 else 0.0,
		evolutions.briar_payload_entanglement if evolution_rank >= 3 else 0.0,
		evolutions.briar_payload_heart_cadence if evolution_rank >= 5 else 0,
		evolutions.ancient_fury_radius_bonus if evolution_rank >= 1 else 0.0,
		evolutions.ancient_fury_entanglement if evolution_rank >= 2 else 0.0,
		evolutions.ancient_fury_chain_damage_share,
		evolution_rank >= 3,
		(
			evolutions.ancient_fury_trigger_threshold
			if evolution_rank >= 4
			else 1.0
		),
		evolutions.ancient_fury_awakening_enemies if evolution_rank >= 5 else 0,
		evolutions.ancient_fury_awakening_eruptions if evolution_rank >= 5 else 0,
		evolutions.ancient_fury_awakening_cooldown
	)
	combat.set_mass_entanglement_shares(
		evolutions.tangleburst_elite_share,
		evolutions.tangleburst_boss_share
	)
	territory_field.set_old_growth_enabled(
		progression.has_active_evolution(PhaseBProgression.EvolutionId.OLD_GROWTH)
	)
	# Metabolism and Root both change what the material is, so both are folded into
	# the same field parameters here rather than each writing the field directly.
	territory_field.set_cohesion_multiplier(
		metabolism.get_cohesion_multiplier() * root_director.get_cohesion_multiplier()
	)
	territory_field.tuning.pressure_advection = clampf(
		_base_pressure_advection
		* metabolism.get_advection_multiplier()
		* root_director.get_pressure_transmission_multiplier(),
		0.0,
		1.0
	)
	territory_field.tuning.small_fragment_decay_per_second = (
		_base_small_fragment_decay
		* metabolism.get_fragment_decay_multiplier()
		* root_director.get_fragment_decay_multiplier()
	)
	_update_metabolism_controls()
	_update_hud()


func _on_boss_erupted(local_position: Vector2) -> void:
	overlay.spawn_hostile_pulse(local_position, eruption_pulse_radius_pixels)
	_set_status("Burrower eruption: nearby Green is being stripped away.")


func _on_health_changed(current: float, maximum: float) -> void:
	if not is_node_ready():
		return
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "HP  %d / %d" % [roundi(current), roundi(maximum)]


func _on_player_died() -> void:
	_finish_run(false, "The Gardener fell beneath the hostile swarm.")


func _on_xp_changed(level: int, current_xp: int, required_xp: int) -> void:
	if not is_node_ready():
		return
	xp_bar.max_value = required_xp
	xp_bar.value = current_xp
	xp_label.text = "LEVEL %d     XP %d / %d" % [level, current_xp, required_xp]


func _on_biomass_changed(current: float, per_second: float) -> void:
	if not is_node_ready():
		return
	# The reserve and what it is earning, and nothing else. A soft dot appears only
	# when a decision is actually affordable; everything else lives in the drawer.
	# One line, matching the tray's own layout: the heading it used to carry cost a
	# line of the tray and repeated what the column already says.
	var ready_marker := "   ●" if metabolism.has_affordable_purchase() else ""
	biomass_label.text = "%s        +%.1f/s%s" % [
		_format_compact(current),
		per_second,
		ready_marker,
	]
	biomass_label.modulate = Color("c7ffa1")
	_update_metabolism_controls()


func _format_compact(value: float) -> String:
	# Fixed shapes so a growing economy never changes the width of its own column.
	var magnitude := absf(value)
	if magnitude >= 1000000.0:
		return "%.2fM" % (value / 1000000.0)
	if magnitude >= 10000.0:
		return "%.1fK" % (value / 1000.0)
	if magnitude >= 1000.0:
		return "%s" % _with_thousands_separator(int(round(value)))
	return "%d" % int(round(value))


func _with_thousands_separator(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	var count := 0
	for index in range(digits.length() - 1, -1, -1):
		grouped = digits[index] + grouped
		count += 1
		if count % 3 == 0 and index > 0:
			grouped = "," + grouped
	return ("-" if value < 0 else "") + grouped


func _on_evolution_changed(_status: int) -> void:
	_update_hud()


func _on_territory_metrics_changed(
	player_percent: float,
	_hostile_percent: float,
	_neutral_percent: float,
	_mature_player_percent: float,
	_fragment_count: int
) -> void:
	if not is_node_ready():
		return
	territory_bar.value = player_percent
	territory_label.text = "GREEN TERRITORY  %.1f%%" % player_percent


func _finish_run(victory: bool, detail: String) -> void:
	if _run_state != RunState.RUNNING:
		return
	_run_state = RunState.VICTORY if victory else RunState.DEFEAT
	_refresh_simulation_pause()
	result_header.text = "FRONTIER HELD" if victory else "THE FRONTIER WITHERED"
	result_header.modulate = Color("91ffaf") if victory else Color("ff7e80")
	result_detail.text = "%s\n\nTime  %s    Level  %d    Green  %.1f%%" % [
		detail,
		_format_time(get_elapsed_seconds()),
		progression.current_level,
		territory_field.get_player_percent(),
	]
	result_panel.visible = true


func is_pause_menu_open() -> bool:
	return _pause_menu_open


func _open_pause_menu() -> void:
	if _pause_menu_open or _choice_kind != ChoiceKind.NONE:
		return
	_pause_menu_open = true
	pause_overlay.visible = true
	_update_fullscreen_button()
	_refresh_simulation_pause()
	# Focus is only taken for a controller. A mouse player gets no ring to explain.
	_refresh_focus_ring()


func _note_input_device(event: InputEvent) -> void:
	# The device that produced the last event decides whether the ring is shown. A
	# pad shows it; touching the mouse or the keyboard takes it away again.
	var controller := false
	if event is InputEventJoypadButton and event.pressed:
		controller = true
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		controller = absf(motion.axis_value) >= controller_stick_deadzone
	elif (
		event is InputEventMouseMotion
		or event is InputEventMouseButton
		or event is InputEventKey
	):
		controller = false
	else:
		return
	if controller == _controller_active:
		return
	_controller_active = controller
	_refresh_focus_ring()


func _refresh_focus_ring() -> void:
	if _controller_active:
		if _pause_menu_open and pause_resume_button != null:
			pause_resume_button.grab_focus()
		return
	# Nothing focused means nothing draws a focus ring, which is the whole fix: the
	# box was Godot telling a mouse player where the controller cursor is.
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()


func is_controller_active() -> bool:
	return _controller_active


func _close_pause_menu() -> void:
	if not _pause_menu_open:
		return
	_pause_menu_open = false
	pause_overlay.visible = false
	_refresh_simulation_pause()


func _restart_from_pause_menu() -> void:
	reset_run()


func _quit_from_pause_menu() -> void:
	get_tree().quit()


func _configure_ambient_music() -> void:
	var wav_stream := ambient_music_audio.stream as AudioStreamWAV
	var repaired_loop_bounds := false
	if wav_stream != null:
		var full_stream_sample_count := roundi(wav_stream.get_length() * wav_stream.mix_rate)
		if wav_stream.loop_begin != 0 or wav_stream.loop_end <= wav_stream.loop_begin:
			wav_stream.loop_begin = 0
			wav_stream.loop_end = full_stream_sample_count
			repaired_loop_bounds = true
		if wav_stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			repaired_loop_bounds = true
	if repaired_loop_bounds:
		ambient_music_audio.stop()
	call_deferred("_ensure_ambient_music_playing")


func _ensure_ambient_music_playing() -> void:
	if ambient_music_audio.stream != null and not ambient_music_audio.playing:
		ambient_music_audio.play()


func _configure_volume_control() -> void:
	_sfx_bus_index = AudioServer.get_bus_index(audio_settings.sfx_bus_name)
	if _sfx_bus_index < 0:
		pause_volume_slider.set_value_no_signal(0.0)
		pause_volume_value.text = "UNAVAILABLE"
	else:
		var sfx_linear_volume := 0.0
		if not AudioServer.is_bus_mute(_sfx_bus_index):
			sfx_linear_volume = db_to_linear(AudioServer.get_bus_volume_db(_sfx_bus_index))
		pause_volume_slider.set_value_no_signal(
			clampf(
				sfx_linear_volume / maxf(audio_settings.sfx_max_linear_volume, 0.0001),
				0.0,
				1.0
			) * 100.0
		)
		_update_volume_label()

	_music_bus_index = AudioServer.get_bus_index(audio_settings.music_bus_name)
	if _music_bus_index < 0:
		pause_music_volume_slider.set_value_no_signal(0.0)
		pause_music_volume_value.text = "UNAVAILABLE"
	else:
		var music_linear_volume := 0.0
		if not AudioServer.is_bus_mute(_music_bus_index):
			music_linear_volume = db_to_linear(AudioServer.get_bus_volume_db(_music_bus_index))
		pause_music_volume_slider.set_value_no_signal(
			clampf(
				music_linear_volume / maxf(
					audio_settings.music_max_linear_volume,
					0.0001
				),
				0.0,
				1.0
			) * 100.0
		)
		_update_music_volume_label()


func _on_sfx_volume_changed(value: float) -> void:
	if _sfx_bus_index < 0:
		return
	var linear_volume := (
		clampf(value / 100.0, 0.0, 1.0)
		* audio_settings.sfx_max_linear_volume
	)
	var muted := linear_volume <= 0.0001
	AudioServer.set_bus_mute(_sfx_bus_index, muted)
	if not muted:
		AudioServer.set_bus_volume_db(_sfx_bus_index, linear_to_db(linear_volume))
	_update_volume_label()


func _update_volume_label() -> void:
	pause_volume_value.text = "%d%%" % roundi(pause_volume_slider.value)


func _on_music_volume_changed(value: float) -> void:
	if _music_bus_index < 0:
		return
	var linear_volume := (
		clampf(value / 100.0, 0.0, 1.0)
		* audio_settings.music_max_linear_volume
	)
	var muted := linear_volume <= 0.0001
	AudioServer.set_bus_mute(_music_bus_index, muted)
	if not muted:
		AudioServer.set_bus_volume_db(_music_bus_index, linear_to_db(linear_volume))
	_update_music_volume_label()


func _update_music_volume_label() -> void:
	pause_music_volume_value.text = "%d%%" % roundi(pause_music_volume_slider.value)


func _toggle_fullscreen() -> void:
	var enter_fullscreen := not _is_fullscreen()
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if enter_fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	pause_fullscreen_button.text = (
		"EXIT FULLSCREEN" if enter_fullscreen else "ENTER FULLSCREEN"
	)
	call_deferred("_update_fullscreen_button")


func _update_fullscreen_button() -> void:
	pause_fullscreen_button.text = (
		"EXIT FULLSCREEN" if _is_fullscreen() else "ENTER FULLSCREEN"
	)


func _is_fullscreen() -> bool:
	var window_mode := DisplayServer.window_get_mode()
	return (
		window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)


func _refresh_simulation_pause() -> void:
	_set_simulation_paused(
		_pause_menu_open
		or _choice_kind != ChoiceKind.NONE
		or _run_state != RunState.RUNNING
	)


func _set_simulation_paused(paused: bool) -> void:
	territory_field.simulation_paused = paused
	overlay.effects_paused = paused
	player.set_simulation_paused(paused)
	combat.set_simulation_paused(paused)


func _update_hud() -> void:
	if not is_node_ready():
		return
	var remaining := maxf(
		0.0,
		wave_director.run_duration_seconds - get_elapsed_seconds()
	)
	var wave_text := "WAVE %d" % get_current_wave_number()
	if is_wave_grace_period_active():
		wave_text = "WAVE %d IN %02ds" % [
			get_current_wave_number(),
			ceili(get_wave_grace_remaining_seconds()),
		]
	var clock_text := "%s REMAINING" % _format_time(remaining)
	if wave_director.is_complete():
		# No clock left to report: what remains between the player and victory is the
		# hostiles still standing.
		clock_text = "CLEAR THE FIELD"
	# Absence communicates zero: the hostile count is a warning, so it appears only
	# while there is something to warn about.
	var hostiles := combat.get_active_enemy_count()
	# The wave and the clock, one per line, as the scene lays the label out. The
	# wave's phase name used to share the first line behind a "//"; the panel is laid
	# out for two lines now and the name is gone with it.
	run_label.text = "%s                    %s" % [wave_text, clock_text]
	# Its own node, so it can be placed and seen in the editor rather than being
	# concatenated onto a line that has no room for it. The text is always written
	# and only the visibility is switched, so what the scene declares is the shape
	# it always carries.
	hostile_label.text = "%d HOSTILES" % hostiles
	hostile_label.visible = hostiles > 0
	var threshold := spore_director.get_seed_kill_threshold()
	territory_label.tooltip_text = "Seed progress: %d / %d kills" % [
		spore_director.get_kills_toward_seed(),
		threshold,
	]
	match progression.evolution_status:
		PhaseBProgression.EvolutionStatus.READY:
			evolution_label.text = "%s READY  //  CHOOSE IT AT THE NEXT LEVEL" % (
				PhaseBEvolutions.get_evolution_name(progression.get_pair_evolution_id())
			)
			evolution_label.modulate = Color("e9ff72")
		PhaseBProgression.EvolutionStatus.EVOLVED:
			var evolution_detail := "GERMINATION CHAINS"
			match progression.active_evolution:
				PhaseBProgression.EvolutionId.BRIAR_PODS:
					evolution_detail = "SEEDS RAISE THORN RINGS"
				PhaseBProgression.EvolutionId.THORNBURST:
					evolution_detail = "BLOOMS SOW BRIAR TRAPS"
				PhaseBProgression.EvolutionId.SEED_BANK:
					evolution_detail = "MATURE BORDERS BANK SEEDS"
				PhaseBProgression.EvolutionId.FLOWERING_SEASON:
					evolution_detail = "MATURE GROUND MASS FLOWERS"
				PhaseBProgression.EvolutionId.OLD_GROWTH:
					evolution_detail = "ANCIENT ROOTS ERUPT"
				PhaseBProgression.EvolutionId.COPPICE:
					evolution_detail = "CUT GROUND ERUPTS WITH SEEDS"
				PhaseBProgression.EvolutionId.REBOUND:
					evolution_detail = "GREEN COLLAPSES INTO BLOOMS"
				PhaseBProgression.EvolutionId.DEADFALL:
					evolution_detail = "THORNS BECOME SPIKE STORMS"
				PhaseBProgression.EvolutionId.COPPICING:
					evolution_detail = "ANCIENT GROUND HARVESTS BIG"
			# Once evolved the run has a support slot to fill, and the label is the
			# only place that reads out what the completed build is made of.
			var support_detail := evolution_detail
			if progression.has_tertiary_path():
				support_detail = "+ %s" % PhaseBProgression.get_path_name(
					progression.tertiary_path
				).to_upper()
			elif progression.is_tertiary_path_available():
				support_detail = "SUPPORT PATH AT %s" % _format_time(
					wave_director.tertiary_path_choice_seconds
				)
			evolution_label.text = "%s  //  %s" % [
				PhaseBEvolutions.get_evolution_name(progression.active_evolution),
				support_detail,
			]
			evolution_label.modulate = Color("77ffd0")
		_:
			# Nothing worth announcing until a pairing is actually in reach.
			evolution_label.text = ""
			evolution_label.modulate = Color("93aab0")
	# The relics heading is a fixed word the scene owns; the run's Paths are read
	# from the slots beneath it rather than from this line.
	_update_relic_slots()
	slots_label.text = _format_slots_caption()
	_update_upgrade_slots()
	_update_metabolism_controls()


func _format_slots_caption() -> String:
	# The authored caption decides how much it wants to say: both counts, just the
	# filled one, or nothing at all beyond its own words.
	var placeholders := _slots_label_format.count("%d")
	if placeholders >= 2:
		return _slots_label_format % [
			progression.get_slotted_upgrades().size(),
			progression.get_upgrade_slot_count(),
		]
	if placeholders == 1:
		return _slots_label_format % progression.get_slotted_upgrades().size()
	return _slots_label_format


func _update_relic_slots() -> void:
	if relic_slots == null:
		return
	# The pool is far larger than the row, so the row shows what the run actually
	# holds, in the order it was taken, with the trigger counter a relic needs to
	# be readable on the slot itself.
	var held := PackedInt32Array()
	for relic_id in range(PhaseBRelicCatalog.get_count()):
		if progression.has_relic(relic_id):
			held.append(relic_id)
	# One empty socket beyond what the run holds: enough to say more are coming,
	# without a permanent row of placeholders for relics it may never take.
	relic_slots.slot_count = clampi(held.size() + 1, 1, _maximum_relic_slots)
	# The empty slot names where the next relic comes from, so the authored wave
	# cadence is what the tooltip reports rather than a number written twice.
	var empty_hint := "Empty relic slot.\nDefeat an elite or the boss to choose a relic."
	if relic_reward_wave_cycle > 0:
		empty_hint = (
			"Empty relic slot.\nEvery %d waves, the elite, and the boss each offer one."
			% relic_reward_wave_cycle
		)
	for index in range(relic_slots.get_slot_count()):
		if index >= held.size():
			relic_slots.set_slot(
				index,
				relic_slots.empty_marker,
				"",
				empty_hint,
				PhaseBUpgradeSlots.SlotState.EMPTY
			)
			continue
		var relic_id := held[index]
		var relic_name := PhaseBProgression.get_relic_name(relic_id)
		var rarity := PhaseBRelicCatalog.get_rarity(relic_id)
		var tooltip := "%s   %s\n%s" % [
			relic_name,
			PhaseBRelicCatalog.get_rarity_name(rarity),
			progression.get_relic_description(relic_id),
		]
		var counter := relic_director.get_relic_counter_text(relic_id)
		if not counter.is_empty():
			tooltip += "\nProgress: %s" % counter
		relic_slots.set_slot(
			index,
			_get_initials(relic_name),
			counter,
			tooltip,
			PhaseBUpgradeSlots.SlotState.FILLED
		)


func _get_initials(source: String) -> String:
	# Two letters taken from an authored name, so a slot reads at a glance and
	# never needs a second name kept in sync with it.
	var words := source.split(" ", false)
	if words.size() >= 2:
		return (words[0].substr(0, 1) + words[1].substr(0, 1)).to_upper()
	if words.size() == 1:
		return words[0].substr(0, 2).to_upper()
	return "--"


func _update_upgrade_slots() -> void:
	if upgrade_slots == null:
		return
	var slotted := progression.get_slotted_upgrades()
	var unlocked := progression.get_upgrade_slot_count()
	# The strip shows what the run has plus the one slot it is working toward, so
	# the interface visibly grows instead of opening on a row of padlocks.
	upgrade_slots.slot_count = mini(_maximum_upgrade_slots, unlocked + 1)
	for index in range(upgrade_slots.get_slot_count()):
		if index < slotted.size():
			var upgrade_id := slotted[index]
			upgrade_slots.set_slot(
				index,
				_get_upgrade_abbreviation(upgrade_id),
				# The slot shows the rank alone; the hover carries it against the cap.
				"%d" % progression.get_upgrade_level(upgrade_id),
				_build_upgrade_tooltip(upgrade_id),
				PhaseBUpgradeSlots.SlotState.FILLED
			)
		elif index < unlocked:
			upgrade_slots.set_slot(
				index,
				upgrade_slots.empty_marker,
				"",
				"Empty growth slot.\nTake a new upgrade line at a level-up to fill it.",
				PhaseBUpgradeSlots.SlotState.EMPTY
			)
		else:
			upgrade_slots.set_slot(
				index,
				"",
				"",
				(
					"Locked growth slot.\nClaiming your pair Evolution consolidates "
					+ "both paths into one slot and opens %d more, so the support "
					+ "path can be developed without replacing what you already have."
				) % progression.evolution_bonus_upgrade_slots,
				PhaseBUpgradeSlots.SlotState.LOCKED
			)


func _get_upgrade_abbreviation(upgrade_id: int) -> String:
	return _get_initials(PhaseBProgression.get_upgrade_name(upgrade_id))


func _build_upgrade_tooltip(upgrade_id: int) -> String:
	# What the line is, what one more rank buys, and what the run's numbers
	# actually resolve to right now.
	var level := progression.get_upgrade_level(upgrade_id)
	var lines := PackedStringArray()
	lines.append("%s   %d/%d" % [
		PhaseBProgression.get_upgrade_name(upgrade_id),
		level,
		progression.maximum_upgrade_level,
	])
	var per_rank := progression.get_upgrade_description(upgrade_id)
	if not per_rank.is_empty():
		var rank_label := "Next rank" if level < progression.maximum_upgrade_level else "Maxed"
		lines.append("%s: %s" % [rank_label, per_rank])
	var resolved := _get_upgrade_resolved_effect(upgrade_id)
	if not resolved.is_empty():
		lines.append("Now: %s" % resolved)
	return "\n".join(lines)


func _get_upgrade_resolved_effect(upgrade_id: int) -> String:
	# The finished numbers, read from the same values the systems use, so the hover
	# text can never drift from what the run is actually doing.
	match upgrade_id:
		PhaseBProgression.UpgradeId.THORNSHOT_POWER:
			var damage := combat.thornshot_damage * progression.get_thornshot_damage_multiplier()
			return "%.1f damage per Thornshot (+%d%%)" % [
				damage,
				roundi((progression.get_thornshot_damage_multiplier() - 1.0) * 100.0),
			]
		PhaseBProgression.UpgradeId.THORNSHOT_TEMPO:
			var interval := (
				combat.thornshot_cooldown_seconds
				* progression.get_thornshot_cooldown_multiplier()
			)
			return "%.2fs between volleys (%.1f per second)" % [
				interval,
				1.0 / maxf(0.01, interval),
			]
		PhaseBProgression.UpgradeId.THORNSHOT_VOLLEY:
			return "%d enemies targeted at once" % progression.get_thornshot_target_count()
		PhaseBProgression.UpgradeId.SEED_PRODUCTION:
			return "%d kills per Seed" % spore_director.get_seed_kill_threshold()
		PhaseBProgression.UpgradeId.GROWTH_MASS:
			return "%d%% Seed growth mass" % roundi(
				spore_director.get_seed_mass_multiplier() * 100.0
			)
		PhaseBProgression.UpgradeId.BLOOM_FORCE:
			return "%d%% Bloom force, %.0f Bloom damage" % [
				roundi(bloom_director.get_bloom_force_multiplier() * 100.0),
				bloom_director.bloom_damage * bloom_director.get_bloom_force_multiplier(),
			]
		PhaseBProgression.UpgradeId.BLOOM_FREQUENCY:
			return "a Bloom every %.1fs" % (
				bloom_director.bloom_interval_seconds
				* bloom_director.get_bloom_interval_multiplier()
			)
		PhaseBProgression.UpgradeId.BRAMBLE_ENTANGLEMENT:
			return "up to %d%% slow when fully Entangled" % roundi(
				bramble_director.get_slow_fraction() * 100.0
			)
		PhaseBProgression.UpgradeId.BRAMBLE_ENSNARE_RATE:
			var rate := (
				combat.bramble_entanglement_per_second
				* bramble_director.get_ensnare_multiplier()
			)
			return "fully Entangled after %.1fs on Green" % (1.0 / maxf(0.01, rate))
		PhaseBProgression.UpgradeId.BRAMBLE_GRASPING_ROOTS:
			return "%.2fs root, then %.0fs immune" % [
				bramble_director.get_root_seconds(),
				bramble_director.get_root_immunity_seconds(),
			]
		PhaseBProgression.UpgradeId.BRAMBLE_REPULSION:
			return "%.0f px knockback on territory attackers" % (
				bramble_director.get_repulsion_pixels()
			)
		PhaseBProgression.UpgradeId.ROOT_MATURATION:
			return "%d%% maturation rate" % roundi(
				root_director.get_maturation_multiplier() * 100.0
			)
		PhaseBProgression.UpgradeId.ROOT_BIOMASS_YIELD:
			return "%d%% Biomass from Mature Green" % roundi(
				root_director.get_biomass_yield_multiplier() * 100.0
			)
		PhaseBProgression.UpgradeId.ROOT_MATURE_STRENGTH:
			return "%.2fx Mature resistance, +%.3f control per second" % [
				root_director.get_mature_resistance_multiplier(),
				root_director.get_regeneration_per_second(),
			]
		PhaseBProgression.UpgradeId.ROOT_POTENCY:
			return "+%d%% from fully Mature ground" % roundi(
				root_director.get_network_bonus() * 100.0
			)
		PhaseBProgression.UpgradeId.PRUNING_HARVEST_RATE:
			return "%.1f cells per second held, %.1f at full Charge" % [
				pruning_director.upkeep_cells_per_second
				* pruning_director.get_pruning_harvest_rate_multiplier(),
				pruning_director.upkeep_cells_per_second_at_charge
				* pruning_director.get_pruning_harvest_rate_multiplier(),
			]
		PhaseBProgression.UpgradeId.PRUNING_CUTTING_YIELD:
			return "%.2f Cuttings per cell harvested" % (
				pruning_director.cuttings_per_cell
				* pruning_director.get_pruning_cutting_yield_multiplier()
			)
		PhaseBProgression.UpgradeId.PRUNING_CUTTING_DAMAGE:
			return "%.0f thicket damage per bite, %.0f per launched Cutting" % [
				pruning_director.orbit_contact_damage
				* pruning_director.get_pruning_cutting_damage_multiplier(),
				pruning_director.cutting_damage
				* pruning_director.get_pruning_cutting_damage_multiplier(),
			]
		PhaseBProgression.UpgradeId.PRUNING_CHARGE:
			return "full Charge in %.1fs, +%d%% launch damage" % [
				pruning_director.get_charge_seconds(),
				roundi(pruning_director.get_launch_charge_damage_bonus() * 100.0),
			]
	if PhaseBEvolutions.get_upgrade_evolution(upgrade_id) != PhaseBProgression.EvolutionId.NONE:
		# An Evolution line's ranks each do something different, so what it is doing
		# now is the description of the rank the run has actually reached.
		var evolution_level := progression.get_upgrade_level(upgrade_id)
		if evolution_level <= 0:
			return ""
		return evolutions.get_evolution_upgrade_rank_description(
			upgrade_id,
			evolution_level
		)
	return ""


func _update_metabolism_controls() -> void:
	if not is_node_ready():
		return
	for system_id in range(metabolism_buttons.size()):
		var button := metabolism_buttons[system_id]
		var unlocked := metabolism.is_system_unlocked(system_id)
		# An axis the run has not discovered is not on screen at all, rather than
		# sitting there disabled: the interface grows with the run.
		button.visible = unlocked
		if not unlocked:
			continue
		var level := metabolism.get_level(system_id)
		var cost := metabolism.get_level_cost(system_id)
		var axis := PhaseBMetabolism.get_axis_name(system_id).to_upper()
		# The wording is a positioned Label owned by the button, not the Button's own
		# centred text, so the drawer can place it. The meter is placed the same way
		# and no longer needs a blank line reserved for it.
		button.set_display_text("%s   LV %d
[ %s  %s ]   %s" % [
			axis,
			level,
			PhaseBMetabolism.get_purchase_verb(system_id),
			_format_compact(cost),
			PhaseBMetabolism.get_axis_summary(system_id),
		])
		var meter := button.get_meter()
		if meter != null:
			meter.value = metabolism.get_level_fraction(system_id)
		var breakthrough := metabolism.get_breakthrough(system_id)
		var lines := PackedStringArray([
			"%s — %s" % [
				PhaseBMetabolism.get_axis_name(system_id),
				PhaseBMetabolism.get_system_name(system_id),
			],
			PhaseBMetabolism.get_system_description(system_id),
			"",
			"Level %d. The next level costs %s Biomass, and each one costs "
				% [level, _format_compact(cost)]
				+ "%d%% more than the last." % roundi(
					(metabolism.level_cost_growth - 1.0) * 100.0
				),
		])
		var to_breakthrough := metabolism.breakthrough_level_interval - (
			level % maxi(1, metabolism.breakthrough_level_interval)
		)
		if breakthrough == PhaseBMetabolism.BreakthroughId.NONE:
			lines.append("Breakthrough in %d level(s)." % to_breakthrough)
		else:
			lines.append("Breakthrough: %s — %s" % [
				PhaseBMetabolism.get_breakthrough_name(breakthrough),
				PhaseBMetabolism.get_breakthrough_description(breakthrough),
			])
		button.tooltip_text = "\n".join(lines)
		button.disabled = not metabolism.can_purchase(system_id)

	var overgrow_cost := metabolism.get_overgrow_cost()
	var cooldown := metabolism.get_overgrow_cooldown_remaining()
	overgrow_button.text = (
		"OVERGROW  %.0f" % overgrow_cost
		if cooldown <= 0.0
		else "OVERGROW  %.1fs" % cooldown
	)
	overgrow_button.disabled = not metabolism.can_overgrow()
	overgrow_button.tooltip_text = (
		"Spend %d%% of the Biomass Reserve as one injection of Mass, Pressure, and "
		% roundi(metabolism.overgrow_reserve_fraction * 100.0)
		+ "Cohesion along the whole living frontier.\n\n"
		+ "It does not hand you a fixed slice of territory: the battlefield decides "
		+ "what the injection becomes. Open ground spreads, a gap funnels a jet, a "
		+ "torn ecosystem seals itself.\n\n"
		+ "This run's split: %d%% Mass, %d%% Pressure, %d%% Cohesion." % [
			roundi(metabolism.get_identity_share(
				PhaseBMetabolism.SystemId.PHOTOSYNTHESIS
			) * 100.0),
			roundi(metabolism.get_identity_share(
				PhaseBMetabolism.SystemId.MERISTEM
			) * 100.0),
			roundi(metabolism.get_identity_share(
				PhaseBMetabolism.SystemId.CAMBIUM
			) * 100.0),
		]
	)

	if metabolism_drawer != null:
		var reserve_label := metabolism_drawer.get_node_or_null("Reserve") as Label
		if reserve_label != null:
			reserve_label.text = "BIOMASS %s" % _format_compact(progression.biomass)

	# The footer teases at most the next thing to arrive, and otherwise reports
	# what the run has already committed to.
	var breakthrough_names := PackedStringArray()
	for system_id in range(metabolism_buttons.size()):
		var held := metabolism.get_breakthrough(system_id)
		if held != PhaseBMetabolism.BreakthroughId.NONE:
			breakthrough_names.append(PhaseBMetabolism.get_breakthrough_name(held))
	var next_system := metabolism.get_next_unlock_system()
	if next_system >= 0:
		var arrives := maxf(
			0.0,
			metabolism.get_unlock_seconds(next_system) - metabolism.get_elapsed_seconds()
		)
		metabolism_label.text = "NEXT ORGAN IN %s" % _format_time(arrives)
	elif breakthrough_names.is_empty():
		metabolism_label.text = "NEXT BREAKTHROUGH: %s LV %d" % [
			PhaseBMetabolism.get_axis_name(_get_nearest_breakthrough_system()).to_upper(),
			metabolism.breakthrough_level_interval,
		]
	else:
		metabolism_label.text = "  //  ".join(breakthrough_names)


func _get_nearest_breakthrough_system() -> int:
	# Whichever axis is closest to its first Breakthrough is the one worth naming.
	var best := 0
	var best_distance := 999
	for system_id in range(metabolism_buttons.size()):
		if metabolism.get_breakthrough(system_id) != PhaseBMetabolism.BreakthroughId.NONE:
			continue
		if not metabolism.is_system_unlocked(system_id):
			continue
		var interval := maxi(1, metabolism.breakthrough_level_interval)
		var distance := interval - (metabolism.get_level(system_id) % interval)
		if distance < best_distance:
			best_distance = distance
			best = system_id
	return best


func _format_time(seconds: float) -> String:
	var total_seconds := maxi(0, int(ceil(seconds)))
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]


func _get_path_pair_label() -> String:
	if not progression.has_primary_path():
		return "UNCHOSEN PATHS"
	if not progression.has_secondary_path():
		return PhaseBProgression.get_path_name(progression.primary_path).to_upper()
	return "%s + %s" % [
		PhaseBProgression.get_path_name(progression.primary_path).to_upper(),
		PhaseBProgression.get_path_name(progression.secondary_path).to_upper(),
	]


func _set_status(_message: String) -> void:
	# The run no longer carries a field-signal readout. Systems still announce what
	# they did, so the signal stays available for a future surface without every
	# caller having to know whether one exists.
	pass
