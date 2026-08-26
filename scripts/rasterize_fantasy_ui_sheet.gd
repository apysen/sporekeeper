extends SceneTree

## Rasterises the Fantasy UI pack's vector sheet, once at native size and once at eight
## times it, for `scripts/cut_fantasy_ui_from_vector.py` to cut surfaces out of.
##
## Godot does the rasterising because Godot is already here: `Image.load_svg_from_string`
## renders at any scale, which keeps the asset pipeline free of an SVG dependency. The
## native-size render is what the cutter matches the pack's shipped PNGs against to find
## each sprite; the large one is what it actually cuts.
##
##     godot --headless --path . --script scripts/rasterize_fantasy_ui_sheet.gd

const SOURCE := "D:/GameDev/GodotUI/kenney/fantasy-ui-borders/Vector/fantasy-ui-borders.svg"
const SUPERSAMPLE := 8.0


func _initialize() -> void:
	var vector := FileAccess.get_file_as_string(SOURCE)
	if vector.is_empty():
		push_error("No vector sheet at %s" % SOURCE)
		quit(1)
		return
	for scale: float in [1.0, SUPERSAMPLE]:
		var image := Image.new()
		var failure := image.load_svg_from_string(vector, scale)
		if failure != OK:
			push_error("Vector sheet failed at %.0fx: %s" % [scale, error_string(failure)])
			quit(1)
			return
		var destination := "res://.godot/sheet_%dx.png" % int(scale)
		image.save_png(destination)
		print("RASTER: %s at %dx%d" % [destination, image.get_width(), image.get_height()])
	quit(0)
