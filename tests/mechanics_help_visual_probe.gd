extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://scenes/run/run.tscn") != OK:
		quit(1)
		return
	await process_frame
	await process_frame
	var prototype := current_scene as RunRoot
	if prototype == null:
		quit(1)
		return
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype._set_simulation_paused(true)
	prototype._show_choice(
		RunRoot.ChoiceKind.UPGRADE,
		PackedInt32Array([Progression.UpgradeId.SEED_PRODUCTION])
	)
	prototype._on_reward_hovered(0, prototype.choice_panel.button_one)
	await process_frame
	await process_frame
	prototype._mechanics_help.source_exited()
	await create_timer(0.25).timeout
	if not prototype._mechanics_help._stack.visible:
		push_error("Reward definitions disappeared after leaving the reward")
		quit(1)
		return
	if prototype._mechanics_help._stack.get_child_count() != 1:
		push_error("Seed reward did not produce exactly its one referenced mechanic card")
		quit(1)
		return
	var reward_gap := (
		prototype._mechanics_help._stack.position.x
		- prototype.choice_panel.get_global_rect().end.x
	)
	if not is_equal_approx(reward_gap, MechanicsHelp.REWARD_GAP):
		push_error("Reward definitions are not tucked against the reward panel")
		quit(1)
		return
	_save("res://.godot/mechanics_reward_tooltip.png")
	prototype._mechanics_help.show_reward_tooltips(
		"Overgrow spends Biomass to add Mass, Pressure, and Cohesion.",
		prototype.choice_panel.get_global_rect()
	)
	await process_frame
	await process_frame
	if prototype._mechanics_help._stack.get_child_count() != 5:
		push_error("Reward side panel did not show every referenced mechanic")
		quit(1)
		return
	var biomass_keys := prototype._mechanics_help._referenced_keys(
		"Gain 20% more Biomass from Mature Green."
	)
	if biomass_keys.has("MASS") or not biomass_keys.has("BIOMASS"):
		push_error("Biomass incorrectly opened the Mass mechanic: %s" % [biomass_keys])
		quit(1)
		return
	prototype.choice_panel.visible = false
	prototype._choice_kind = RunRoot.ChoiceKind.NONE
	prototype._choice_ids.clear()
	prototype._mechanics_help.hide_tooltip()
	prototype.relic_tray.slots.set_slot(
		0,
		"RB",
		"",
		"ROOTED BARK\nGain defense while standing on Mature Green. Root Potency improves the effect.",
		UpgradeSlots.SlotState.FILLED
	)
	Input.warp_mouse(prototype.relic_tray.slots.get_slot_global_rect(0).get_center() * 2.0)
	prototype.relic_tray._on_slot_hovered(0)
	await process_frame
	await process_frame
	var relic_source := prototype.relic_tray.slots.get_slot_global_rect(0)
	var relic_card := prototype._mechanics_help._stack.get_rect()
	if absf(relic_source.position.y - relic_card.end.y - MechanicsHelp.HUD_GAP) > 1.0:
		push_error("Relic tooltip is not directly above its bottom-tray slot")
		quit(1)
		return
	Input.warp_mouse(prototype._mechanics_help._stack.get_rect().get_center() * 2.0)
	await process_frame
	if not prototype._mechanics_help._stack.visible:
		push_error("HUD tooltip disappeared while moving from its slot into the card")
		quit(1)
		return
	_save("res://.godot/mechanics_live_hud_tooltip.png")
	prototype._mechanics_help._on_keyword_hovered("ROOT POTENCY", 0)
	await process_frame
	await process_frame
	_save("res://.godot/mechanics_nested_tooltip.png")
	prototype._mechanics_help.hide_tooltip()
	prototype._mechanics_help.set_process(false)
	prototype._mechanics_help.show_hud_tooltip(
		"GREEN", "Metabolism shapes Green.", relic_source
	)
	await process_frame
	await process_frame
	prototype._mechanics_help._on_keyword_hovered("METABOLISM", 0)
	await process_frame
	await process_frame
	var cycle_depth := prototype._mechanics_help._stack.get_child_count()
	prototype._mechanics_help._on_keyword_hovered("GREEN", 1)
	await process_frame
	if cycle_depth != 2 or prototype._mechanics_help._stack.get_child_count() != cycle_depth:
		push_error(
			"Nested mechanics can reopen an already visible ancestor tooltip: before=%d after=%d keys=%s"
			% [
				cycle_depth,
				prototype._mechanics_help._stack.get_child_count(),
				prototype._mechanics_help._open_tooltip_keys(),
			]
		)
		quit(1)
		return
	if prototype._mechanics_help._linkify(
		MechanicsHelp.ENTRIES["METABOLISM"], PackedStringArray(["GREEN"])
	).contains("[url=GREEN]"):
		push_error("An open ancestor mechanic remains clickable in a nested tooltip")
		quit(1)
		return
	prototype._mechanics_help.set_process(true)
	Input.warp_mouse(Vector2(2400.0, 160.0))
	await process_frame
	await process_frame
	if prototype._mechanics_help._stack.visible:
		push_error("HUD tooltip stayed open after the cursor moved away")
		quit(1)
		return
	prototype._mechanics_help.hide_tooltip()
	prototype.adaptation_tree.core_one_slots.set_slot(
		0,
		"RB",
		"",
		"ROOTED BARK\nGain defense while standing on Mature Green.",
		UpgradeSlots.SlotState.FILLED
	)
	Input.warp_mouse(prototype.adaptation_tree.core_one_slots.get_slot_global_rect(0).get_center() * 2.0)
	prototype.adaptation_tree._on_slot_hovered(0, prototype.adaptation_tree.core_one_slots)
	await process_frame
	await process_frame
	var adaptation_source := prototype.adaptation_tree.core_one_slots.get_slot_global_rect(0)
	var adaptation_card := prototype._mechanics_help._stack.get_rect()
	if absf(adaptation_source.position.x - adaptation_card.end.x - MechanicsHelp.HUD_GAP) > 1.0:
		push_error(
			"Adaptation tooltip is not directly beside its right-side slot: source=%s card=%s"
			% [adaptation_source, adaptation_card]
		)
		quit(1)
		return
	_save("res://.godot/mechanics_adaptation_tooltip.png")
	prototype._mechanics_help.hide_tooltip()
	prototype._open_pause_menu()
	Input.warp_mouse(prototype.relic_tray.slots.get_slot_global_rect(0).get_center() * 2.0)
	prototype.relic_tray._on_slot_hovered(0)
	await process_frame
	await process_frame
	_save("res://.godot/mechanics_paused_hud_tooltip.png")
	prototype._mechanics_help.hide_tooltip()
	prototype._open_glossary()
	await process_frame
	await process_frame
	_save("res://.godot/mechanics_glossary.png")
	print("MECHANICS_HELP_VISUAL_PROBE: PASS")
	quit(0)


func _save(path: String) -> void:
	var image := root.get_texture().get_image()
	if image == null or image.save_png(path) != OK:
		push_error("Unable to save %s" % path)
