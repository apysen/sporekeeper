extends SceneTree

## Every framed surface carries a border band, and a control that sits flush against a
## thin edge ends up underneath a thick one the moment the frame art changes. This walks
## the interface with everything on screen at once and fails on any control whose rect
## reaches into the frame band of the panel it sits in - read off that panel's own style
## rather than assumed, because the tray wears a slimmer frame than the panels do.
##
## It also checks that no control is drawn over its neighbour. `get_global_rect()`
## reports a control's unscaled box, so a label carrying a `scale` covers more of
## the screen than its rect admits - which is how a readout came to be printing
## underneath the button beside it while every rect still looked clear. Ink is
## measured instead: the text's own width, placed by its alignment, through the
## control's full global transform.

const FRAME_MARGIN := 14.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/run/run.tscn")
	await process_frame
	await process_frame
	var prototype := current_scene as RunRoot
	prototype.set_process(false)
	prototype.player.input_enabled = false
	# Everything that can be on screen at once, so nothing is judged while hidden.
	prototype._open_pause_menu()
	await process_frame
	await process_frame
	var offenders := 0
	for panel in _panels(prototype.interface_layer):
		# Each panel's own frame, read off the style it actually uses rather than assumed:
		# the tray wears a slimmer one than the panels do.
		var style := panel.get_theme_stylebox("panel") as StyleBoxTexture
		var band := FRAME_MARGIN
		if style != null:
			band = maxf(style.texture_margin_top, style.texture_margin_bottom)
		var inner: Rect2 = panel.get_global_rect().grow(-band)
		for child in panel.get_children():
			var control := child as Control
			if control == null or not control.visible:
				continue
			var rect := control.get_global_rect()
			# Some labels are parented to a panel but deliberately live outside it - the
			# wave and clock sit across the top of the screen. A control whose middle is
			# not inside the panel is not being framed by it.
			if not panel.get_global_rect().has_point(rect.get_center()):
				continue
			var over_top: float = inner.position.y - rect.position.y
			var over_bottom: float = rect.end.y - inner.end.y
			var over_left: float = inner.position.x - rect.position.x
			var over_right: float = rect.end.x - inner.end.x
			var worst := maxf(maxf(over_top, over_bottom), maxf(over_left, over_right))
			if worst > 0.5:
				offenders += 1
				print("ALIGN: %s/%s intrudes %.0fpx (top %.0f bottom %.0f left %.0f right %.0f)" % [
					panel.name,
					control.name,
					worst,
					over_top,
					over_bottom,
					over_left,
					over_right,
				])
	# Neighbours, by what each one actually puts on the screen.
	var collisions := 0
	for panel in _panels(prototype.interface_layer):
		var drawn: Array = []
		for child in panel.get_children():
			var control := child as Control
			if control == null or not control.is_visible_in_tree():
				continue
			if not (control is Label or control is Button):
				continue
			var ink := _ink_rect(control)
			if ink.size.x > 0.5 and ink.size.y > 0.5:
				drawn.append([control, ink])
		for first in range(drawn.size()):
			for second in range(first + 1, drawn.size()):
				var one: Rect2 = drawn[first][1]
				var two: Rect2 = drawn[second][1]
				var shared := one.intersection(two)
				if shared.size.x > 1.0 and shared.size.y > 1.0:
					collisions += 1
					print("ALIGN: %s/%s is drawn over %s by %.0fx%.0fpx" % [
						panel.name,
						(drawn[first][0] as Control).name,
						(drawn[second][0] as Control).name,
						shared.size.x,
						shared.size.y,
					])
	print("ALIGN: %d controls intrude into a frame, %d overlap a neighbour" % [
		offenders, collisions
	])
	var failed := offenders + collisions
	print("ALIGN: %s" % ("PASS" if failed == 0 else "FAIL"))
	quit(0 if failed == 0 else 1)


func _ink_rect(control: Control) -> Rect2:
	# What the control puts on the screen, through its own transform so a scale counts.
	# A Button draws its background across its whole box; a Label draws only its text,
	# placed inside the box by its alignment.
	var local := Rect2(Vector2.ZERO, control.size)
	var label := control as Label
	if label != null:
		var font := label.get_theme_font("font")
		var font_size := label.get_theme_font_size("font")
		if font == null:
			return Rect2()
		var widest := 0.0
		for line in label.text.split(String.chr(10)):
			widest = maxf(widest, font.get_string_size(line, 0, -1, font_size).x)
		widest = minf(widest, control.size.x)
		var left := 0.0
		match label.horizontal_alignment:
			HORIZONTAL_ALIGNMENT_CENTER:
				left = (control.size.x - widest) * 0.5
			HORIZONTAL_ALIGNMENT_RIGHT:
				left = control.size.x - widest
		# The same in the other axis: a label given more height than its lines need
		# draws nothing in the slack, and counting the slack as ink would report a
		# collision between two things that never touch.
		var tall := minf(
			font.get_height(font_size) * label.get_line_count(), control.size.y
		)
		var top := 0.0
		match label.vertical_alignment:
			VERTICAL_ALIGNMENT_CENTER:
				top = (control.size.y - tall) * 0.5
			VERTICAL_ALIGNMENT_BOTTOM:
				top = control.size.y - tall
		local = Rect2(Vector2(left, top), Vector2(widest, tall))
	var transform := control.get_global_transform()
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

func _panels(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children():
		if child is Panel and (child as Control).visible:
			found.append(child)
		found.append_array(_panels(child))
	return found
