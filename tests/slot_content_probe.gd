extends SceneTree

## Where a slot's abbreviation and level actually sit inside the slot square.
##
## Both rows stack two labels in bands placed by exported fractions of the slot, which
## is a design surface worth keeping, and a pair of fractions that reads as centred is
## not the same thing as ink that lands in the middle. The fractions place boxes; what
## the player sees is the text inside them, and a font's ascent and descent are not
## symmetric. This measures the ink - the union of both labels' drawn text, through the
## row's own transform - against the centre of the square it is drawn in.

const TOLERANCE := 0.75


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file("res://scenes/run/phase_b_prototype.tscn")
	await process_frame
	await process_frame
	var prototype := current_scene as PhaseBPrototype
	prototype.set_process(false)
	prototype.player.input_enabled = false
	# Both rows need something in them to be measured, and a relic slot only fills
	# when the run actually holds a relic.
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.BRAMBLE,
		PhaseBProgression.PathId.SPORE
	)
	for _draw in range(3):
		prototype.progression.request_relic_choice()
		var offered := prototype.progression.get_pending_relic_options()
		if offered.size() > 0:
			prototype.progression.choose_relic(offered[0])
	prototype._update_hud()
	await process_frame
	await process_frame

	var offenders := 0
	for row: PhaseBUpgradeSlots in [prototype.relic_slots, prototype.upgrade_slots]:
		if row == null:
			continue
		for index in range(row.get_slot_count()):
			var panel := row._slot_panels[index]
			if panel == null:
				continue
			var title := panel.get_node_or_null("Title") as Label
			var level := panel.get_node_or_null("Level") as Label
			if title == null or not title.visible or title.text.is_empty():
				continue
			if level == null or not level.visible or level.text.is_empty():
				# An empty slot carries one marker and is measured on its own.
				pass
			var ink := _ink_rect(title)
			if level != null and level.visible and not level.text.is_empty():
				ink = ink.merge(_ink_rect(level))
			var square := Rect2(
				panel.get_global_position(),
				panel.size * panel.get_global_transform().get_scale()
			)
			var drift := ink.get_center() - square.get_center()
			if absf(drift.x) > TOLERANCE or absf(drift.y) > TOLERANCE:
				offenders += 1
				print("SLOT: %s[%d] '%s' sits %+.2f,%+.2f from centre" % [
					row.name, index, title.text, drift.x, drift.y
				])
	print("SLOT_CONTENT: %d slots off centre" % offenders)
	print("SLOT_CONTENT: %s" % ("PASS" if offenders == 0 else "FAIL"))
	quit(0 if offenders == 0 else 1)


func _ink_rect(label: Label) -> Rect2:
	# The text's own extent, placed inside its box by the two alignments, through the
	# label's full global transform so a scaled row is measured where it is drawn.
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font")
	if font == null:
		return Rect2()
	var widest := 0.0
	for line in label.text.split(String.chr(10)):
		widest = maxf(widest, font.get_string_size(line, 0, -1, font_size).x)
	widest = minf(widest, label.size.x)
	var tall := minf(font.get_height(font_size) * label.get_line_count(), label.size.y)
	var left := 0.0
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			left = (label.size.x - widest) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			left = label.size.x - widest
	var top := 0.0
	match label.vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER:
			top = (label.size.y - tall) * 0.5
		VERTICAL_ALIGNMENT_BOTTOM:
			top = label.size.y - tall
	var local := Rect2(Vector2(left, top), Vector2(widest, tall))
	var transform := label.get_global_transform()
	var corners := PackedVector2Array([
		transform * local.position,
		transform * Vector2(local.end.x, local.position.y),
		transform * Vector2(local.position.x, local.end.y),
		transform * local.end,
	])
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(corner)
	return bounds
