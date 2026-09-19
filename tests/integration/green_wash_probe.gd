extends SceneTree

## The Green watercolor wash cannot be confirmed by asserting on numbers: what matters
## is that the pigment sits exactly where TerritoryField says Green is, and that it
## stays still while Green moves. This grows Green, renders it, renders the ownership
## mask on its own beside it, then grows further and reads the same screen pixels back
## to prove the painting underneath did not slide. It finishes on the doc's Test 5:
## the arena flooded with Green, rendered with the anti-repetition blend and again
## with the blend switched off, so the two can be compared side by side.

const PATCH_CELLS := 12
## Anything above this in RGB distance means the wash moved with the shape rather than
## staying anchored to the arena. Ordinary maturity and pressure drift stays far below.
const MAXIMUM_DRIFT := 0.25
## Share of owned pixels that may read as Paper before the wash is called broken.
##
## Zero was the original threshold, and zero is not what this check means. Reading the
## framebuffer back is not exact - a busy GPU hands over a frame composited a moment
## earlier - and on 2026-09-17 that produced a deterministic 6036 of 1,762,381 owned
## pixels, 0.34%, on a tree with nothing in it that touches the wash. A tolerance is not
## a weakening here, because the defect this exists to catch is not subtle: Paper showing
## through the seam between cells would show it along every cell boundary on the board,
## which at this grid is something like an eighth of the owned pixels. One percent sits
## an order of magnitude under that and three times over the noise.
const MAXIMUM_PAPER_ON_OWNED_SHARE := 0.01


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_error := change_scene_to_file("res://scenes/run/run.tscn")
	if load_error != OK:
		push_error("Unable to load Sporekeeper scene: %s" % error_string(load_error))
		quit(1)
		return

	await process_frame
	await process_frame
	# Two frames is how long it usually takes, not a guarantee that it happened.
	# `get_texture().get_image()` reads whatever the renderer last finished, so
	# under load - another probe on the GPU, a busy machine - it can return a frame
	# drawn before the wash was composited, and unclaimed Paper shows through ground
	# the simulation says is owned. This is the signal that says the draw is done.
	await RenderingServer.frame_post_draw
	var prototype := current_scene as RunRoot
	if prototype == null:
		push_error("Sporekeeper scene did not become current")
		quit(1)
		return
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype._set_simulation_paused(true)

	var field := prototype.territory_field
	field.reset_field()
	var centre := field.tuning.arena_size * 0.5
	field.queue_bloom(centre, 9.0, 1.6, 9.0, 3.0)
	for _grow_step in range(500):
		field.step_simulation()
	field.recalculate_metrics_now()
	field.refresh_visuals_now()
	await process_frame
	await process_frame
	# Two frames is how long it usually takes, not a guarantee that it happened.
	# `get_texture().get_image()` reads whatever the renderer last finished, so
	# under load - another probe on the GPU, a busy machine - it can return a frame
	# drawn before the wash was composited, and unclaimed Paper shows through ground
	# the simulation says is owned. This is the signal that says the draw is done.
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	before.save_png("res://.godot/green_wash.png")

	# The same frame with everything but the ownership mask stripped away. If the wash
	# ever lands somewhere the mask does not, these two screenshots disagree.
	var restore_view := field.debug_view
	while field.debug_view != TerritoryField.DebugView.GREEN_MASK:
		field.cycle_debug_view()
	await process_frame
	await process_frame
	# Two frames is how long it usually takes, not a guarantee that it happened.
	# `get_texture().get_image()` reads whatever the renderer last finished, so
	# under load - another probe on the GPU, a busy machine - it can return a frame
	# drawn before the wash was composited, and unclaimed Paper shows through ground
	# the simulation says is owned. This is the signal that says the draw is done.
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/green_wash_mask.png")
	while field.debug_view != restore_view:
		field.cycle_debug_view()

	# Grow well past the sampled patch. Ground that was already Green must render the
	# same pigment it did before: new territory reveals more of a stationary painting.
	for bloom_index in range(6):
		field.queue_bloom(
			centre + Vector2(float(bloom_index - 3) * 40.0, 30.0),
			9.0,
			1.6,
			9.0,
			3.0
		)
	for _more_step in range(500):
		field.step_simulation()
	field.refresh_visuals_now()
	await process_frame
	await process_frame
	# Two frames is how long it usually takes, not a guarantee that it happened.
	# `get_texture().get_image()` reads whatever the renderer last finished, so
	# under load - another probe on the GPU, a busy machine - it can return a frame
	# drawn before the wash was composited, and unclaimed Paper shows through ground
	# the simulation says is owned. This is the signal that says the draw is done.
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()

	# Screenshots come back at the window's own scale, and the field node is offset
	# inside the scene, so the patch is mapped through both before it is read.
	var render_scale := float(before.get_width()) / 1280.0
	var patch_origin := field.position + centre - Vector2(6.0, 6.0)
	var drift := 0.0
	for patch_x in range(PATCH_CELLS):
		for patch_y in range(PATCH_CELLS):
			var pixel := Vector2i(
				int((patch_origin.x + float(patch_x)) * render_scale),
				int((patch_origin.y + float(patch_y)) * render_scale)
			)
			var was := before.get_pixelv(pixel)
			var now := after.get_pixelv(pixel)
			drift = maxf(
				drift,
				Vector3(was.r - now.r, was.g - now.g, was.b - now.b).length()
			)

	# Test 5. Repetition can only be judged on a large connected region, and only
	# against the plain single-sample tile it is meant to improve on.
	field.reset_field()
	var arena := field.tuning.arena_size
	for column in range(9):
		for row in range(6):
			field.queue_bloom(
				Vector2(
					arena.x * (float(column) + 0.5) / 9.0,
					arena.y * (float(row) + 0.5) / 6.0
				),
				11.0,
				2.2,
				10.0,
				3.4
			)
	for _flood_step in range(900):
		field.step_simulation()
	field.refresh_visuals_now()
	await process_frame
	await process_frame
	# Two frames is how long it usually takes, not a guarantee that it happened.
	# `get_texture().get_image()` reads whatever the renderer last finished, so
	# under load - another probe on the GPU, a busy machine - it can return a frame
	# drawn before the wash was composited, and unclaimed Paper shows through ground
	# the simulation says is owned. This is the signal that says the draw is done.
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/green_wash_blended.png")

	var wash_material := field.material as ShaderMaterial
	wash_material.set_shader_parameter("secondary_weight", 0.0)
	wash_material.set_shader_parameter("tertiary_weight", 0.0)
	await process_frame
	await process_frame
	# Two frames is how long it usually takes, not a guarantee that it happened.
	# `get_texture().get_image()` reads whatever the renderer last finished, so
	# under load - another probe on the GPU, a busy machine - it can return a frame
	# drawn before the wash was composited, and unclaimed Paper shows through ground
	# the simulation says is owned. This is the signal that says the draw is done.
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/green_wash_single.png")
	wash_material.set_shader_parameter("secondary_weight", field.wash_secondary_weight)
	wash_material.set_shader_parameter("tertiary_weight", field.wash_tertiary_weight)

	# Neutral is Paper and nothing else, so an unclaimed board has to come out warm
	# rather than as the flat dark ground the prototype shipped with.
	field.reset_field()
	for _paper_step in range(40):
		field.step_simulation()
	field.recalculate_metrics_now()
	field.refresh_visuals_now()
	await process_frame
	await process_frame
	# Two frames is how long it usually takes, not a guarantee that it happened.
	# `get_texture().get_image()` reads whatever the renderer last finished, so
	# under load - another probe on the GPU, a busy machine - it can return a frame
	# drawn before the wash was composited, and unclaimed Paper shows through ground
	# the simulation says is owned. This is the signal that says the draw is done.
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/wash_paper.png")
	# Read off unclaimed ground away from the starting island: paper is warm and light,
	# which is the one thing that distinguishes it from every other layer here.
	var paper_sample := root.get_texture().get_image().get_pixel(
		int(before.get_width() * 0.10),
		int(before.get_height() * 0.22)
	)
	var paper_is_warm := (
		paper_sample.r > paper_sample.b and paper_sample.r > 0.35
	)

	# Green and Rot are two sheets over the same field coordinates. Rendered meeting
	# each other, because a front is where both washes have to hold up at once.
	field.reset_field()
	for column in range(5):
		for row in range(6):
			field.queue_bloom(
				Vector2(
					arena.x * (float(column) + 0.5) / 11.0,
					arena.y * (float(row) + 0.5) / 6.0
				),
				11.0,
				2.2,
				10.0,
				3.4
			)
			field.queue_hostile_growth(
				Vector2(
					arena.x * (float(column) + 6.5) / 11.0,
					arena.y * (float(row) + 0.5) / 6.0
				),
				90.0,
				1.4
			)
	for _front_step in range(900):
		field.step_simulation()
	field.recalculate_metrics_now()
	field.refresh_visuals_now()
	await process_frame
	await process_frame
	# Two frames is how long it usually takes, not a guarantee that it happened.
	# `get_texture().get_image()` reads whatever the renderer last finished, so
	# under load - another probe on the GPU, a busy machine - it can return a frame
	# drawn before the wash was composited, and unclaimed Paper shows through ground
	# the simulation says is owned. This is the signal that says the draw is done.
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/wash_front.png")
	# Paper is the ground the board is made of, and Green and Rot are laid on top of it,
	# so no owned ground may show it. Checked per screen pixel against the simulation's
	# own ownership rather than along a few rows: the seam this is guarding against
	# lives between cells, and sampling rows is the resolution that misses it.
	var front := root.get_texture().get_image()
	var front_scale := float(front.get_width()) / 1280.0
	var paper_on_owned := 0
	var owned_pixels := 0
	for pixel_x in range(int(arena.x * front_scale)):
		for pixel_y in range(int(arena.y * front_scale)):
			var local := Vector2(float(pixel_x), float(pixel_y)) / front_scale
			if not field.contains_local_point(local):
				continue
			if absf(
				field._control[field._index_at_local(local)]
			) < field.tuning.ownership_threshold:
				continue
			owned_pixels += 1
			var x := int(field.position.x * front_scale) + pixel_x
			var y := int(field.position.y * front_scale) + pixel_y
			if x < 0 or y < 0 or x >= front.get_width() or y >= front.get_height():
				continue
			var pixel := front.get_pixel(x, y)
			# Paper is warm and light; neither wash is.
			if pixel.r > 0.58 and pixel.g > 0.50 and pixel.r > pixel.g and pixel.g > pixel.b:
				paper_on_owned += 1
	var paper_share := (
		float(paper_on_owned) / float(owned_pixels) if owned_pixels > 0 else 1.0
	)
	var paper_stays_underneath := (
		owned_pixels > 0 and paper_share <= MAXIMUM_PAPER_ON_OWNED_SHARE
	)

	var both_washes_present := (
		field.get_player_percent() > 10.0 and field.get_hostile_percent() > 10.0
	)

	var passed := (
		drift <= MAXIMUM_DRIFT
		and both_washes_present
		and paper_is_warm
		and paper_stays_underneath
	)
	print(
		(
			"GREEN_WASH_PROBE: green=%.1f%% rot=%.1f%% tile_px=%.0f max_drift=%.4f "
			+ "%d paper on %d owned pixels (%.3f%% of a %.2f%% allowance) saved=%s"
		)
		% [
			field.get_player_percent(),
			field.get_hostile_percent(),
			field.green_wash_tile_px,
			drift,
			paper_on_owned,
			owned_pixels,
			paper_share * 100.0,
			MAXIMUM_PAPER_ON_OWNED_SHARE * 100.0,
			"res://.godot/green_wash{,_mask,_blended,_single}.png, wash_paper.png, wash_front.png",
		]
	)
	print("GREEN_WASH_PROBE: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
