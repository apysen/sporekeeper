extends SceneTree

## What a Canker actually looks like on the board.
##
## `canker_probe` proves the ladder and the spawn rule; neither of those would notice a
## Knot drawn at the wrong scale, a painting that never loads, or a telegraph invisible
## against Rot. This drives one site through entrenchment, warning and establishment and
## saves a frame at each, so the presentation can be looked at rather than assumed.
##
## Needs a real window: it reads the rendered frame. Run without `--headless`:
##     godot --path . --script tests/integration/canker_visual_probe.gd

const RUN_SCENE := "res://scenes/run/run.tscn"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _drive()
	if _failures == 0:
		print("CANKER_VISUAL_PROBE: PASS")
		quit(0)
	else:
		push_error("CANKER_VISUAL_PROBE: %d failure(s)" % _failures)
		quit(1)


func _drive() -> void:
	if change_scene_to_file(RUN_SCENE) != OK:
		_check(false, "the run scene loads")
		return
	await process_frame
	await process_frame
	var run := current_scene as RunRoot
	if run == null:
		_check(false, "the run scene becomes a RunRoot")
		return
	run.set_process(false)
	run.player.input_enabled = false
	var director := run.canker_director
	var field := run.territory_field

	for texture in CankerDirector.CANKER_TEXTURES:
		_check(texture != null, "every authored Canker painting is present and imported")

	field.make_field_hostile(0.85)
	field.recalculate_metrics_now()
	field.refresh_visuals_now()
	run.player.global_position = field.to_global(Vector2(60.0, 60.0))
	director.reset_director()

	# Past the gate wave, then part-way into the hold: the entrenching ring, gathering.
	run.wave_director.debug_advance_time(
		float(director.first_wave) * run.wave_director.wave_duration_seconds
	)
	_advance(director, director.hold_time * 0.6)
	await _draw_frames()
	await _save("res://.godot/canker_entrenching.png")

	# Into the warning, where the rings close and the pulse quickens.
	_advance(director, director.hold_time * 0.45)
	await _draw_frames()
	await _save("res://.godot/canker_warning.png")

	# And established, which is the frame the paintings appear in.
	_advance(director, director.warning_time + 1.5)
	_check(director.get_active_knot_count() > 0, "a Knot is established to photograph")
	await _draw_frames()
	await _save("res://.godot/canker_knot.png")

	# Several Knots, each drawing its own variation at its own angle. This is the frame
	# that would show four identical stamps if the variation were not wired.
	_advance(director, 40.0)
	await _draw_frames()
	await _save("res://.godot/canker_field.png")
	var positions := director.get_active_knot_positions()
	_check(positions.size() > 0, "the field carries Knots to look at (%d)" % [positions.size()])
	for position in positions:
		_check(
			field.contains_local_point(position),
			"and every Knot is drawn inside the arena"
		)

	await _check_edge_clipping(director, field)
	await _check_warning_text(run, director, field)


func _check_warning_text(run: RunRoot, director: CankerDirector, field: TerritoryField) -> void:
	## Section 22.3 asks for "a short local warning ... near the region rather than
	## presented as a full-screen global catastrophe". So the thing to prove is not that a
	## string exists but that ink lands on the board beside the site - and then stops when
	## the warning does, because a warning that outlives its cause is worse than none.
	##
	## Measured as a difference between the same band with the warning on and with it off,
	## rather than as a count of pale pixels. The first frame taken here had a relic choice
	## panel across the middle of the field and the label behind it, which an absolute
	## count reads as "no text" and a band near the wall reads as "text" off the stonework.
	## A difference cannot be fooled by either, because the board is identical in both
	## frames but for the words.
	var arena := field.tuning.arena_size
	# The interface is a CanvasLayer over the arena, and the run has been advanced through
	# a wave by the checks above, so something is usually open on it. What is being looked
	# at is the field.
	var interface_was_visible := run.interface_layer.visible
	run.interface_layer.visible = false

	var middle := await _label_ink(director, field, arena * 0.5, CankerRules.Stage.WARNING)
	await _save("res://.godot/canker_warning_text.png")
	_check(
		middle > 40,
		"the warning puts its text on the board beside the region (%d px of ink)" % [middle]
	)

	# Against the wall, which is the ground a player abandons first and so the likeliest
	# place for this text to be needed. It is pulled back inside rather than clipped into
	# half a word.
	var edge_position := Vector2(arena.x * 0.5, arena.y - 4.0)
	var edge := await _label_ink(director, field, edge_position, CankerRules.Stage.WARNING)
	await _save("res://.godot/canker_warning_text_edge.png")
	_check(
		edge > 40,
		"a warning against the wall keeps its words on the board (%d px of ink)" % [edge]
	)
	var edge_image := root.get_texture().get_image()
	if edge_image != null:
		var reference := _sample_outside(edge_image, field, Vector2(arena.x * 0.25, arena.y * 0.5))
		_check(
			_color_distance(_sample_outside(edge_image, field, edge_position), reference) <= 0.12,
			"and paints none of them through the wall"
		)
	# And the name, which is the only place in the game the word appears. The glossary has
	# a CANKER entry, and an entry for a word the player never reads is the closed loop the
	# glossary was cut back to remove on the 17th - so what makes that entry honest is this
	# text existing on the board.
	var named := await _label_ink(director, field, arena * 0.5, CankerRules.Stage.ACTIVE)
	await _save("res://.godot/canker_formed_text.png")
	_check(
		named > 40,
		"a Knot that opens says what it is (%d px of ink)" % [named]
	)

	run.interface_layer.visible = interface_was_visible
	director.reset_director()


func _label_ink(
	director: CankerDirector,
	field: TerritoryField,
	local_position: Vector2,
	stage: CankerRules.Stage
) -> int:
	## Pale pixels a label adds to the ground around a site: the band with one site at that
	## stage, less the same band with nothing there at all. The frame is left showing the
	## label, so a caller can save it.
	director.reset_director()
	var band := _label_band(field, local_position)
	await _draw_frames()
	var without := _count_light_pixels(root.get_texture().get_image(), field, band)
	var site := CankerDirector.Site.new()
	site.position = local_position
	site.stage = stage
	# Past the fade-in and short of the fade-out, so the text is at full strength in both
	# cases rather than being measured somewhere on a ramp.
	site.warning_timer = maxf(0.0, director.warning_time - director.label_fade_seconds - 0.2)
	site.age = director.label_fade_seconds + 0.2
	director._sites.append(site)
	director.queue_redraw()
	await _draw_frames()
	var with_warning := _count_light_pixels(root.get_texture().get_image(), field, band)
	return with_warning - without


func _label_band(field: TerritoryField, local_position: Vector2) -> Rect2:
	## Ground around the site that the label could land on, clipped to the inside of the
	## wall. A box rather than the strip directly underneath, for the reason the edge case
	## exists at all: a label against the bottom wall is slid back up inside it, so a band
	## that only looked below the site would miss exactly the placement being checked.
	##
	## Clipping to the playable bounds is not tidiness. The HUD outside the wall is full of
	## pale text, and a band that ran past the boundary would count the interface as proof
	## the field had been painted on.
	return Rect2(local_position - Vector2(200.0, 200.0), Vector2(400.0, 400.0)).intersection(
		field.get_playable_bounds_local()
	)


func _count_light_pixels(image: Image, field: TerritoryField, band: Rect2) -> int:
	## Pixels that look like the label's near-white. Counted rather than matched exactly,
	## because the text is anti-aliased over an outline and no single pixel is the authored
	## colour; what the count is for is the difference between two frames, not its own size.
	if image == null:
		return 0
	var transform := root.get_final_transform() * field.get_global_transform_with_canvas()
	var start := transform * band.position
	var end := transform * band.end
	var count := 0
	for pixel_y in range(int(minf(start.y, end.y)), int(maxf(start.y, end.y))):
		if pixel_y < 0 or pixel_y >= image.get_height():
			continue
		for pixel_x in range(int(minf(start.x, end.x)), int(maxf(start.x, end.x))):
			if pixel_x < 0 or pixel_x >= image.get_width():
				continue
			var pixel := image.get_pixel(pixel_x, pixel_y)
			var lowest := minf(pixel.r, minf(pixel.g, pixel.b))
			var highest := maxf(pixel.r, maxf(pixel.g, pixel.b))
			if lowest > 0.80 and highest - lowest < 0.14:
				count += 1
	return count


func _check_edge_clipping(director: CankerDirector, field: TerritoryField) -> void:
	## Ground against the wall is the first ground a player gives up, so a Knot has to be
	## able to grow there. What it must not do is paint through the wall - the layer is
	## clipped to the playable field, and this is the frame that shows it.
	var arena := field.tuning.arena_size
	var corners: Array[Vector2] = [
		Vector2(2.0, 2.0),
		Vector2(arena.x - 2.0, 2.0),
		Vector2(2.0, arena.y - 2.0),
		Vector2(arena.x - 2.0, arena.y - 2.0),
		Vector2(arena.x * 0.5, 1.0),
	]
	director.reset_director()
	for index in range(corners.size()):
		var site := CankerDirector.Site.new()
		site.position = corners[index]
		site.stage = CankerRules.Stage.ACTIVE
		site.age = 10.0
		site.texture_index = index
		site.rotation = float(index) * 0.7
		director._sites.append(site)
	director.queue_redraw()
	await _draw_frames()
	await _save("res://.godot/canker_edge_clipping.png")
	var image := root.get_texture().get_image()
	if image == null:
		_check(false, "a frame could be read for the clipping check")
		return
	# Sampled just outside the field on each side, in the strip a 150px painting centred
	# on the boundary would otherwise cover. The wall there has to look like the wall.
	var reference := _sample_outside(image, field, Vector2(arena.x * 0.5, arena.y * 0.5))
	var clean := true
	for corner in corners:
		var outside := _sample_outside(image, field, corner)
		if _color_distance(outside, reference) > 0.12:
			clean = false
	_check(clean, "nothing a Knot draws reaches past the outer wall")


func _color_distance(first: Color, second: Color) -> float:
	return (
		absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)
	) / 3.0


func _sample_outside(image: Image, field: TerritoryField, local_position: Vector2) -> Color:
	## The point just beyond the wall on the nearest side of the given field position.
	var arena := field.tuning.arena_size
	var outside := local_position
	var left := local_position.x
	var right := arena.x - local_position.x
	var top := local_position.y
	var bottom := arena.y - local_position.y
	var nearest := minf(minf(left, right), minf(top, bottom))
	if is_equal_approx(nearest, left):
		outside.x = -14.0
	elif is_equal_approx(nearest, right):
		outside.x = arena.x + 14.0
	elif is_equal_approx(nearest, top):
		outside.y = -14.0
	else:
		outside.y = arena.y + 14.0
	# Field local -> canvas -> actual framebuffer pixels. The last step is the one worth
	# spelling out: the run is authored at a base resolution and the window stretches it,
	# so a canvas coordinate used directly as a pixel index reads the wrong part of the
	# screen by exactly the stretch factor.
	var canvas_point := field.get_global_transform_with_canvas() * outside
	var screen_point := root.get_final_transform() * canvas_point
	var pixel := Vector2i(
		clampi(int(screen_point.x), 0, image.get_width() - 1),
		clampi(int(screen_point.y), 0, image.get_height() - 1)
	)
	return image.get_pixelv(pixel)


func _advance(director: CankerDirector, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		director.advance(minf(0.25, remaining))
		remaining -= 0.25


func _draw_frames() -> void:
	await process_frame
	await process_frame


func _save(path: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		_check(false, "a frame could be read for %s" % [path])
		return
	image.save_png(path)


func _check(passed: bool, description: String) -> void:
	if passed:
		print("PASS: %s" % description)
		return
	_failures += 1
	push_error("FAIL: %s" % description)
