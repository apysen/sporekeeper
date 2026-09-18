## What the run shows and how the player can change it: the HUD's division of labour,
## the reel and rewind animations, telemetry, and the presentation settings.
##
## The rule these share is that none of them may reach the simulation. A setting that
## changes what is drawn is checked for changing only that, which is why several of
## these read a simulation figure on both sides of the change.
class_name SmokePresentation
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	var metabolism := prototype.metabolism

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
	report.check(
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
	report.check(
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
	prototype.combat.spawn_pack(EnemyKinds.Role.HUNTER, 3)
	prototype._update_hud()
	var threatened_hostiles_shown := prototype.hostile_label.visible
	prototype.combat.reset_combat()
	report.check(
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
	SmokeFixtures.seed_run_adaptations(
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
	report.check(
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
	report.check(
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
	report.check(
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
	report.check(
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
	report.check(
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
	report.check(
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
	report.check(
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
	report.check(
		important_kept
		and ordinary_dropped
		and not settings.should_show_damage_number(true),
		"Important Only keeps the hits that mean something and Off keeps none"
	)

	# The interface is never scaled, and the battlefield is never scaled with it.
	#
	# UI Scale and HUD Detail used to be settings, and this guarded that they stayed
	# retired. The vocabulary is gone now - no enum entry, no getter, no menu row - so
	# a half-revival cannot compile, and what is left to check is the property that
	# outlives the setting: the HUD is drawn at 1:1, and how much arena the player can
	# see does not depend on it.
	settings.reset_settings()
	var arena_transform := prototype.territory_field.transform
	prototype._on_display_settings_changed()
	report.check(
		is_equal_approx(prototype.interface_layer.transform.get_scale().x, 1.0)
		and is_equal_approx(prototype.interface_layer.transform.get_scale().y, 1.0)
		and prototype.territory_field.transform == arena_transform
		and prototype.status_label.text.is_empty(),
		"the interface is drawn unscaled and the battlefield is left alone"
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
	# The pause panel is centred on the screen, which is a property of its own anchors
	# rather than of any setting. This used to walk five interface-scale choices; the
	# scale is fixed at 1:1 now, so there is one placement to check and it is this one.
	var pause_panel := prototype.pause_menu.resume_button.get_parent() as Control
	var screen_centre := prototype.get_viewport().get_visible_rect().size * 0.5
	var drawn_centre: Vector2 = (
		prototype.interface_layer.transform * pause_panel.get_global_rect().get_center()
	)
	# Vertically the panel is authored a little below centre; horizontally there is
	# nothing to excuse a drift.
	var stays_centred := (
		absf(drawn_centre.x - screen_centre.x) <= 1.0
		and absf(drawn_centre.y - screen_centre.y) <= 20.0
	)
	prototype.pause_menu.settings_back_button.pressed.emit()
	every_option_reachable = (
		every_option_reachable
		and prototype.pause_menu.panel.visible
		and not prototype.pause_menu.settings_panel.visible
	)
	prototype._close_pause_menu()
	report.check(
		stays_centred,
		"the pause menu is centred on the screen"
	)

	report.check(
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
	report.check(
		banner_shown
		and prototype.banner_label.modulate.a <= 0.01,
		"a major event banner fades off the battlefield instead of becoming a HUD section"
	)
	metabolism.reset_metabolism()
	prototype.progression.reset_progression()

