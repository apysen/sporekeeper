extends SceneTree

## Bakes the ten digits of Beholden Regular into one strip, for damage numbers.
##
## A damage number is drawn with `draw_string` today, which re-shapes the text on
## every call: at a screenful of a hundred and sixty numbers that is the single
## largest cost in the rendered frame. Drawing digit quads out of one texture skips
## shaping entirely and keeps every number on one texture, so the whole layer
## batches instead of walking a font atlas per glyph.
##
## The cells are uniform, so indexing the strip is arithmetic and no glyph is ever
## clipped, but the layout is not: stepping by a uniform advance sized for a "0"
## left a "1" adrift in the middle of its slot, which read as loose letter-spacing.
## Each digit's own advance is written out beside the texture and the drawing code
## steps by that.
##
## White glyphs on transparent, so the damage source's feedback colour can be
## applied as a modulate and the shadow can be the same quads drawn dark and
## offset.
##
## Needs a display, because it renders. Run without --headless:
##   godot --path . --script tools/bake_damage_digit_atlas.gd

const FONT_PATH := "res://assets/fonts/beholden/Beholden-Regular.ttf"
const OUTPUT_PATH := "res://assets/ui/damage_digits.png"
## Metrics for the strip, written beside it. The cells are uniform so a glyph is
## never clipped, but the digits are not: laying them out on a uniform advance left
## a "1" adrift in a cell sized for a "0". So each digit's own advance travels with
## the texture, and the drawing code steps by that.
const METRICS_PATH := "res://assets/ui/damage_digits.json"
## Baked well above the sizes it is drawn at -- 16pt for a normal hit, 22 for a
## critical -- so scaling down stays clean and a larger critical size later does not
## need a re-bake.
const BAKE_FONT_SIZE := 64
## Breathing room around each glyph so neighbouring cells cannot bleed into one
## another once the texture is filtered and scaled.
const CELL_PADDING := 2


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var font: FontFile = load(FONT_PATH)
	if font == null:
		push_error("Could not load %s" % FONT_PATH)
		quit(1)
		return

	# One cell wide enough for the widest digit, so no glyph is clipped, plus each
	# digit's own advance so the layout can be proportional.
	var cell_size := Vector2i.ZERO
	var advances := PackedFloat32Array()
	for digit in range(10):
		var glyph_size := font.get_string_size(
			str(digit), HORIZONTAL_ALIGNMENT_LEFT, -1.0, BAKE_FONT_SIZE
		)
		advances.append(glyph_size.x)
		cell_size.x = maxi(cell_size.x, int(ceil(glyph_size.x)))
		cell_size.y = maxi(cell_size.y, int(ceil(glyph_size.y)))
	cell_size.x += CELL_PADDING * 2
	cell_size.y += CELL_PADDING * 2

	var viewport := SubViewport.new()
	viewport.size = Vector2i(cell_size.x * 10, cell_size.y)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := DigitStripPainter.new()
	painter.font = font
	painter.font_size = BAKE_FONT_SIZE
	painter.cell_size = cell_size
	painter.padding = CELL_PADDING
	viewport.add_child(painter)
	root.add_child(viewport)

	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	if image == null or image.is_empty():
		push_error(
			"The strip never resolved. This needs a rendering driver -- run it "
			+ "without --headless."
		)
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_PATH).get_base_dir()
	)
	var save_error := image.save_png(OUTPUT_PATH)
	if save_error != OK:
		push_error("Could not write %s: %s" % [OUTPUT_PATH, error_string(save_error)])
		quit(1)
		return

	var metrics := {
		"bake_font_size": BAKE_FONT_SIZE,
		"cell_width": cell_size.x,
		"cell_height": cell_size.y,
		"advances": Array(advances),
	}
	var metrics_file := FileAccess.open(METRICS_PATH, FileAccess.WRITE)
	if metrics_file == null:
		push_error(
			"Could not write %s: %s"
			% [METRICS_PATH, error_string(FileAccess.get_open_error())]
		)
		quit(1)
		return
	metrics_file.store_string(JSON.stringify(metrics, "	"))
	metrics_file.close()

	# Printed so the drawing code can be checked against the strip it is reading,
	# rather than the two agreeing only by coincidence.
	print(
		"DIGIT_ATLAS: wrote %s  cell=%dx%d  strip=%dx%d  font_size=%d  padding=%d"
		% [
			OUTPUT_PATH,
			cell_size.x,
			cell_size.y,
			image.get_width(),
			image.get_height(),
			BAKE_FONT_SIZE,
			CELL_PADDING,
		]
	)
	var opaque := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.05:
				opaque += 1
	print("DIGIT_ATLAS: advances %s" % str(advances))
	print(
		"DIGIT_ATLAS: %d opaque pixels (%.1f%% of the strip)"
		% [opaque, 100.0 * float(opaque) / float(image.get_width() * image.get_height())]
	)
	if opaque == 0:
		push_error("The strip is blank -- the font rendered nothing.")
		quit(1)
		return
	quit(0)


class DigitStripPainter:
	extends Node2D

	var font: FontFile
	var font_size := 64
	var cell_size := Vector2i.ZERO
	var padding := 4

	func _draw() -> void:
		for digit in range(10):
			var text := str(digit)
			var glyph_size := font.get_string_size(
				text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size
			)
			# Centred in its cell horizontally, sitting on a common baseline
			# vertically, so every digit lines up when they are drawn side by side.
			var origin := Vector2(
				float(digit * cell_size.x) + (float(cell_size.x) - glyph_size.x) * 0.5,
				float(padding) + font.get_ascent(font_size)
			)
			draw_string(
				font,
				origin,
				text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				font_size,
				Color.WHITE
			)
