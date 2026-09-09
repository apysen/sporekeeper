extends SceneTree

## The reel faces, rendered large enough to see the outline, and measured: a ring drawn
## from a shape that reaches its own texture edge smears along that edge, so what is
## checked is whether the outline touches the corners of its rect - a round symbol's
## ring never should.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/run/run.tscn")
	await process_frame
	await process_frame
	var prototype := current_scene as RunRoot
	prototype.set_process(false)
	prototype.player.input_enabled = false
	await process_frame
	var shot := root.get_texture().get_image()
	shot.save_png("res://.godot/symbols.png")
	var render_scale := float(shot.get_width()) / 1280.0
	var corners_inked := 0
	var faces := 0
	for reel in [prototype.slot_panel.reel_one, prototype.slot_panel.reel_two, prototype.slot_panel.reel_three]:
		for child in reel.get_children():
			var face := child as TextureRect
			if face == null or not face.is_visible_in_tree():
				continue
			var rect := face.get_global_rect()
			if rect.size.x < 4.0:
				continue
			faces += 1
			# The four corners of the face's own rect. A symbol is a rounded shape in
			# the middle of its texture; ink in the corner means the ring found the
			# texture border rather than the silhouette.
			for corner in [
				rect.position + Vector2(1.0, 1.0),
				Vector2(rect.end.x - 2.0, rect.position.y + 1.0),
				Vector2(rect.position.x + 1.0, rect.end.y - 2.0),
				rect.end - Vector2(2.0, 2.0),
			]:
				var x := int(corner.x * render_scale)
				var y := int(corner.y * render_scale)
				if x < 0 or y < 0 or x >= shot.get_width() or y >= shot.get_height():
					continue
				var pixel := shot.get_pixel(x, y)
				# The outline is near-black and opaque; the reel strip behind is not.
				if pixel.a > 0.5 and pixel.r < 0.2 and pixel.g < 0.2 and pixel.b < 0.2:
					corners_inked += 1
	# And each symbol has to sit in the middle of the window painted behind it. The
	# reels were placed by hand a third of a unit right of the glass, which reads as the
	# symbol leaning against one side of its own window.
	var off_centre := 0.0
	for reel in [prototype.slot_panel.reel_one, prototype.slot_panel.reel_two, prototype.slot_panel.reel_three]:
		var window: Rect2 = reel.get_global_rect()
		for child in reel.get_children():
			var face := child as TextureRect
			if face == null or not face.is_visible_in_tree():
				continue
			var rect := face.get_global_rect()
			# The face is centred in its reel, and the reel is centred on the glass, so
			# any drift shows up as the two centres parting.
			off_centre = maxf(
				off_centre,
				absf(rect.get_center().x - window.get_center().x)
			)
	print("SYMBOL_PROBE: worst face offset %.2f px from its window" % off_centre)
	if off_centre > 0.5:
		corners_inked += 1

	print("SYMBOL_PROBE: %d inked corners across %d faces" % [corners_inked, faces])
	print("SYMBOL_PROBE: %s" % ("PASS" if corners_inked == 0 else "FAIL"))
	quit(0 if corners_inked == 0 else 1)
