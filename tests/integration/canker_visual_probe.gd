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
