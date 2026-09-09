extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_style("res://assets/ui/panel_style.tres", 12, "run panel style")
	_check_style("res://assets/ui/tray_style.tres", 4, "tray style")
	_check_style("res://assets/ui/slot_style.tres", 8, "slot style")
	_check_style("res://assets/ui/button_style.tres", 12, "run button style")
	_check_style("res://assets/ui/button_hover_style.tres", 12, "run hover style")
	_check_style("res://assets/ui/button_disabled_style.tres", 4, "run disabled style")
	_check_style("res://assets/ui/wx_panel_ornate.tres", 24, "ornate panel style")
	_check_style("res://assets/ui/wx_panel_plain.tres", 20, "plain panel style")
	_check_style("res://assets/ui/wx_fantasy_button.tres", 24, "fantasy button style")
	_check_style("res://assets/ui/wx_fantasy_button_hover.tres", 24, "fantasy hover style")
	_check_style("res://assets/ui/wx_fantasy_button_pressed.tres", 24, "fantasy pressed style")
	if change_scene_to_file("res://scenes/menu/home_screen.tscn") != OK:
		quit(1)
		return
	await process_frame
	await process_frame
	var home := current_scene
	_check_border(home.get_node("MenuPage/TitlePanel") as Control, 24, "title panel")
	for path in [
		"MenuPage/CampaignButton",
		"MenuPage/PlayButton",
		"MenuPage/SettingsButton",
		"MenuPage/QuitButton",
	]:
		_check_border(home.get_node(path) as Control, 24, path)
	var campaign := home.get_node("MenuPage/CampaignButton") as Button
	Input.warp_mouse(campaign.get_global_rect().get_center() * 2.0)
	await process_frame
	await process_frame
	_check_border(campaign, 24, "hovered campaign button")
	_save("res://.godot/kenney_borders_title.png")

	if change_scene_to_file("res://scenes/run/run.tscn") != OK:
		quit(1)
		return
	await process_frame
	await process_frame
	var prototype := current_scene as RunRoot
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype._set_simulation_paused(true)
	_check_border(prototype.get_node("Interface/SidePanel") as Control, 12, "side panel")
	_check_border(prototype.get_node("Interface/UpgradeTray") as Control, 4, "relic tray")
	_check_border(prototype.relic_slots.get_node("Slot1") as Control, 8, "relic slot")
	_check_border(prototype.upgrade_slots.get_node("Slot1") as Control, 8, "adaptation slot")
	_check_border(prototype.pause_menu.resume_button, 12, "pause button")
	prototype.pause_menu.resume_button.disabled = true
	await process_frame
	_check_border(prototype.pause_menu.resume_button, 4, "disabled pause button")
	prototype.pause_menu.resume_button.disabled = false
	Input.warp_mouse(prototype.pause_menu.resume_button.get_global_rect().get_center() * 2.0)
	await process_frame
	await process_frame
	_check_border(prototype.pause_menu.resume_button, 12, "hovered pause button")
	_save("res://.godot/kenney_borders_run_hud.png")
	if _failed:
		quit(1)
		return
	print("KENNEY_BORDER_VISUAL_PROBE: PASS")
	quit(0)


func _check_border(control: Control, expected_margin: int, label: String) -> void:
	if control == null:
		push_error("Missing %s control" % label)
		_failed = true
		return
	var border := control.get_node_or_null("NinePatchBorder") as NinePatchRect
	var valid := (
		border != null
		and border.patch_margin_left == expected_margin
		and border.patch_margin_top == expected_margin
		and border.patch_margin_right == expected_margin
		and border.patch_margin_bottom == expected_margin
		and border.axis_stretch_horizontal == NinePatchRect.AXIS_STRETCH_MODE_STRETCH
		and border.axis_stretch_vertical == NinePatchRect.AXIS_STRETCH_MODE_STRETCH
		and border.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
	)
	if not valid:
		push_error(
			"%s does not preserve its %dpx source corners: border=%s margins=%s filter=%s axes=%s/%s"
			% [
				label,
				expected_margin,
				border,
				(
					Vector4(
						border.patch_margin_left,
						border.patch_margin_top,
						border.patch_margin_right,
						border.patch_margin_bottom
					)
					if border != null
					else Vector4.ZERO
				),
				border.texture_filter if border != null else -1,
				border.axis_stretch_horizontal if border != null else -1,
				border.axis_stretch_vertical if border != null else -1,
			]
		)
		_failed = true


func _check_style(path: String, expected_margin: int, label: String) -> void:
	var style := load(path) as StyleBoxTexture
	var valid := (
		style != null
		and roundi(style.texture_margin_left) == expected_margin
		and roundi(style.texture_margin_top) == expected_margin
		and roundi(style.texture_margin_right) == expected_margin
		and roundi(style.texture_margin_bottom) == expected_margin
	)
	if not valid:
		push_error("%s does not use its measured %dpx source corners" % [label, expected_margin])
		_failed = true


func _save(path: String) -> void:
	var image := root.get_texture().get_image()
	if image == null or image.save_png(path) != OK:
		push_error("Unable to save %s" % path)
		_failed = true
