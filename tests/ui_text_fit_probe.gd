extends SceneTree

## A font swap changes every text metric at once, and a box that fit one font fits no
## other by luck. This measures what the game actually writes, in the font it is actually
## written in, against the box the scene gave it to write in.
##
## It measures the authored template as well as the rendered line. The scene is where
## the wording is edited, so what the editor draws has to fit too - a template wider
## than its box is a box that looks broken while it is being arranged, even though the
## live line it prints is narrower.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/run/phase_b_prototype.tscn")
	await process_frame
	await process_frame
	var prototype := current_scene as PhaseBPrototype
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype._open_pause_menu()
	prototype._update_hud()
	await process_frame
	await process_frame
	var overflowing := 0
	for node in _labels(prototype.interface_layer):
		var text := ""
		var font_size := 16
		if node is Label:
			text = (node as Label).text
			font_size = (node as Label).get_theme_font_size("font")
		elif node is Button:
			text = (node as Button).text
			font_size = (node as Button).get_theme_font_size("font")
		if text.strip_edges().is_empty():
			continue
		var font := (node as Control).get_theme_font("font")
		if font == null:
			continue
		var widest := 0.0
		for line in text.split(String.chr(10)):
			widest = maxf(widest, font.get_string_size(line, 0, -1, font_size).x)
		var room := (node as Control).size.x
		if node is Button:
			room -= 12.0
		if widest > room:
			overflowing += 1
			print("OVERFLOW: %s needs %.0fpx in %.0fpx - %s" % [
				node.name, widest, room, text.split(String.chr(10))[0]
			])
	# And again with what the editor shows: the authored template, in the same box.
	var declared := {}
	var packed: PackedScene = load("res://scenes/run/phase_b_prototype.tscn")
	var state := packed.get_state()
	for node_index in range(state.get_node_count()):
		for property_index in range(state.get_node_property_count(node_index)):
			if state.get_node_property_name(node_index, property_index) != "text":
				continue
			declared[str(state.get_node_path(node_index))] = str(
				state.get_node_property_value(node_index, property_index)
			)
	var previews := 0
	for node_path: String in declared.keys():
		var node := prototype.get_node_or_null(NodePath(node_path)) as Control
		if node == null or not node.is_visible_in_tree():
			continue
		var template: String = declared[node_path]
		if template.strip_edges().is_empty():
			continue
		var preview_font := node.get_theme_font("font")
		if preview_font == null:
			continue
		var preview_size := node.get_theme_font_size("font")
		var preview_widest := 0.0
		for line in template.split(String.chr(10)):
			preview_widest = maxf(
				preview_widest, preview_font.get_string_size(line, 0, -1, preview_size).x
			)
		# A placeholder stands in for a value and is nearly always the longer of the
		# two, so a template is allowed a tenth over the box before it counts: past
		# that the box is too small to author the line in, which is a real fault.
		var preview_room := (node.size.x - (12.0 if node is Button else 0.0)) * 1.1
		if preview_widest > preview_room:
			previews += 1
			print("PREVIEW: %s needs %.0fpx in %.0fpx - %s" % [
				node.name, preview_widest, preview_room / 1.1,
				template.split(String.chr(10))[0],
			])
	print("TEXT_FIT: %d controls overflow, %d templates overflow" % [
		overflowing, previews
	])
	var failed := overflowing + previews
	print("TEXT_FIT: %s" % ("PASS" if failed == 0 else "FAIL"))
	quit(0 if failed == 0 else 1)

func _labels(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children():
		if (child is Label or child is Button) and (child as Control).is_visible_in_tree():
			found.append(child)
		found.append_array(_labels(child))
	return found
