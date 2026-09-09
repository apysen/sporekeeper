extends SceneTree

const PAIRS := [
	[Progression.PathId.SPORE, Progression.PathId.BLOOM, "spore_bloom"],
	[Progression.PathId.BRAMBLE, Progression.PathId.ROOT, "bramble_root"],
	[Progression.PathId.PRUNING, Progression.PathId.THISTLE, "pruning_thistle"],
	[Progression.PathId.VINE, Progression.PathId.FRUIT, "vine_fruit"],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://scenes/run/run.tscn") != OK:
		quit(1)
		return
	await process_frame
	await process_frame
	var prototype := current_scene as RunRoot
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype._set_simulation_paused(true)
	for pair in PAIRS:
		if not prototype.progression.debug_select_paths(pair[0], pair[1]):
			push_error("Unable to select adaptation icon test pair")
			quit(1)
			return
		await process_frame
		await process_frame
		if not _check_icon(
			prototype._path_one_emblem_icon,
			prototype._path_one_emblem,
			prototype._get_path_emblem_texture(pair[0])
		) or not _check_icon(
			prototype._path_two_emblem_icon,
			prototype._path_two_emblem,
			prototype._get_path_emblem_texture(pair[1])
		):
			quit(1)
			return
		_save("res://.godot/adaptation_icons_%s.png" % pair[2])
	for path_id in range(Progression.PathId.size()):
		if prototype._get_path_emblem_texture(path_id) == null:
			push_error("Path %d has no circular adaptation icon" % path_id)
			quit(1)
			return
	print("ADAPTATION_EMBLEM_VISUAL_PROBE: PASS")
	quit(0)


func _check_icon(icon: TextureRect, label: Label, expected: Texture2D) -> bool:
	var centered := icon.get_global_rect().get_center().distance_to(
		(icon.get_parent() as Control).get_global_rect().get_center()
	) <= 0.01
	var valid := (
		icon.visible
		and not label.visible
		and icon.texture == expected
		and icon.size == Vector2(24.0, 24.0)
		and icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		and centered
	)
	if not valid:
		push_error(
			"Adaptation emblem is missing or off-center: icon=%s size=%s centered=%s label=%s"
			% [icon.texture, icon.size, centered, label.visible]
		)
	return valid


func _save(path: String) -> void:
	var image := root.get_texture().get_image()
	if image == null or image.save_png(path) != OK:
		push_error("Unable to save %s" % path)
