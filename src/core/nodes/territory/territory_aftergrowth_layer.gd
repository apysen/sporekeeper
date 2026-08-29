class_name TerritoryAftergrowthLayer
extends Node2D

## Draws the temporary shield a Bloom leaves on the Green it touched.
##
## Its own layer rather than another pass inside the effects overlay, for the same
## reason the wager highlight is: it is a statement about the ground rather than an
## effect happening on top of it, and a CanvasItem can only carry one material, which
## the overlay has already spent.
##
## The shield is held per cell, because that is what territory damage is resolved
## against. What is drawn is a single mask stretched over the arena and reconstructed
## in the shader, so the sheet has the same soft border as the territory underneath it
## instead of reading as a grid of lit squares.
##
## Unlike the wager mask, this one is not binary: each cell carries how much shield is
## left, so the sheet thins where it is being eaten and pulls back from where it has
## been eaten through, without any of that being a second effect.

const AFTERGROWTH_SHADER := preload("res://assets/shaders/aftergrowth_field.gdshader")

@export_group("Collaborators")
## Supplies the arena rect the mask is stretched across.
@export var tuning: TerritoryPrototypeTuning
## Supplies the shield itself and the grid it is held on. The field's own lattice, so
## the sheet and the border it sits on are reconstructed from the same one.
@export var territory_field: TerritoryField
## Presentation options. Optional: without it the sheet is drawn at full strength,
## which is what this did before the settings existed.
@export var display_settings: PhaseBDisplaySettings

@export_group("Appearance")
## Pale growth laid over shielded Green. Bright enough to read against the run's own
## colour, transparent enough that the territory underneath stays legible.
@export var aftergrowth_color := Color(0.72, 1.0, 0.86, 1.0)
@export_range(0.0, 1.0, 0.01) var base_alpha := 0.30
## A slow shimmer, so a fresh shield reads as living growth rather than as a decal.
@export_range(0.0, 0.5, 0.01) var pulse_amplitude := 0.05
@export_range(0.0, 6.0, 0.1) var pulse_hz := 0.9
## Where the reconstructed shield counts as the edge of the sheet, and how wide that
## transition is. The midpoint is low on purpose: a nearly spent cell should still
## show something, because the shield fading out is the whole readout.
@export_range(0.0, 1.0, 0.01) var edge_midpoint := 0.12
@export_range(0.001, 0.5, 0.005) var edge_softness := 0.16
## Extra alpha in a band just inside the contour, and how deep that band reaches.
@export_range(0.0, 1.0, 0.01) var boundary_boost := 0.34
@export_range(0.001, 0.6, 0.01) var boundary_width := 0.26
## How strongly the fill follows what is left of the shield rather than merely whether
## there is one.
@export_range(0.0, 1.0, 0.01) var strength_weight := 0.70

@export_group("Smoothing")
## Blur passes run over the mask before it is uploaded. A shield stamped cell by cell
## still carries the lattice in its contour; one pass is enough to bend that out, and
## the reconstruction in the shader does the rest.
@export_range(0, 4, 1) var blur_passes := 1

var _mask_image: Image
var _mask_texture: ImageTexture
var _mask_material: ShaderMaterial
var _mask_bytes := PackedByteArray()
var _blur_bytes := PackedByteArray()
var _width := 0
var _height := 0
var _cell_count := 0
var _shielded := 0
## Whether the field's border settings have been copied across successfully yet.
var _appearance_mirrored := false


func _ready() -> void:
	assert(tuning != null, "TerritoryAftergrowthLayer requires TerritoryPrototypeTuning")
	assert(territory_field != null, "TerritoryAftergrowthLayer requires a TerritoryField")
	# The cubic reconstruction in the shader is built from four bilinear taps, so the
	# node has to be sampling linearly for it to mean anything.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_configure_material()
	_configure_buffers()
	visible = false


func _draw() -> void:
	if _mask_texture == null or _shielded <= 0:
		return
	draw_texture_rect(_mask_texture, Rect2(Vector2.ZERO, tuning.arena_size), false)


func refresh() -> void:
	## Called once a frame by the run. The field already keeps a compact list of the
	## cells carrying a shield, so a run with no Aftergrowth investment - and every
	## stretch of a run between Blooms - costs one integer comparison and nothing else.
	var cells := territory_field.get_aftergrowth_cells()
	if cells.is_empty():
		if _shielded > 0:
			_shielded = 0
			visible = false
			queue_redraw()
		return
	if not _appearance_mirrored:
		# Ready order puts the field first, but that is the scene's arrangement rather
		# than a guarantee. Binding on the first frame that actually needs it means a
		# reordered scene loses nothing.
		_mirror_field_appearance()
	_shielded = cells.size()
	_rebuild_mask(cells)
	visible = _friendly_scale() > 0.004
	queue_redraw()


func get_shielded_cell_count() -> int:
	return _shielded


func _friendly_scale() -> float:
	if display_settings == null:
		return 1.0
	return display_settings.get_friendly_effect_scale()


func _configure_material() -> void:
	var authored := material as ShaderMaterial
	if authored == null:
		_mask_material = ShaderMaterial.new()
		_mask_material.shader = AFTERGROWTH_SHADER
	else:
		_mask_material = authored.duplicate() as ShaderMaterial
	material = _mask_material
	_mask_material.set_shader_parameter("aftergrowth_color", aftergrowth_color)
	_mask_material.set_shader_parameter("base_alpha", base_alpha)
	_mask_material.set_shader_parameter("pulse_amplitude", pulse_amplitude)
	_mask_material.set_shader_parameter("pulse_hz", pulse_hz)
	_mask_material.set_shader_parameter("edge_midpoint", edge_midpoint)
	_mask_material.set_shader_parameter("edge_softness", edge_softness)
	_mask_material.set_shader_parameter("boundary_boost", boundary_boost)
	_mask_material.set_shader_parameter("boundary_width", boundary_width)
	_mask_material.set_shader_parameter("strength_weight", strength_weight)
	_mirror_field_appearance()


func _mirror_field_appearance() -> void:
	# Everything that decides where the ground's border is, and how ragged it is, is
	# read off the territory field's own material rather than authored a second time
	# here. Two copies of these numbers would drift the moment either is tuned, and
	# the symptom would be a shield whose edge no longer agrees with the Green it is
	# supposed to be part of.
	_mask_material.set_shader_parameter("field_tex", territory_field.get_field_texture())
	_mask_material.set_shader_parameter("field_size_px", tuning.arena_size)
	var field_material := territory_field.material as ShaderMaterial
	if field_material == null:
		return
	# Without the noise texture the tear would displace every pixel by the same
	# constant rather than wandering, which shifts the whole contour instead of
	# roughening it. Better a smooth edge than a uniformly wrong one.
	if field_material.get_shader_parameter("edge_noise_tex") == null:
		_mask_material.set_shader_parameter("edge_distortion_px", 0.0)
	_appearance_mirrored = territory_field.get_field_texture() != null
	for parameter in [
		"edge_noise_tex",
		"edge_noise_tile_px",
		"edge_distortion_px",
		"edge_softness_px",
		"ownership_threshold",
		"paint_threshold_scale",
		"front_paint_bias",
	]:
		var value: Variant = field_material.get_shader_parameter(parameter)
		if value != null:
			_mask_material.set_shader_parameter(parameter, value)


func _configure_buffers() -> void:
	_width = maxi(1, territory_field.get_grid_width())
	_height = maxi(1, territory_field.get_grid_height())
	_cell_count = _width * _height
	_mask_bytes.resize(_cell_count)
	_blur_bytes.resize(_cell_count)
	_mask_bytes.fill(0)
	_blur_bytes.fill(0)
	_mask_image = Image.create_empty(_width, _height, false, Image.FORMAT_R8)
	_mask_texture = ImageTexture.create_from_image(_mask_image)
	if _mask_material != null:
		# The field rebuilds its texture when the grid changes, so the reference has
		# to be taken again rather than held from ready.
		_mask_material.set_shader_parameter(
			"field_tex",
			territory_field.get_field_texture()
		)


func _rebuild_mask(cells: PackedInt32Array) -> void:
	if _mask_image == null or territory_field.get_grid_width() != _width:
		_configure_buffers()
	# Cleared whole because that is a native memset, then worked on only where the
	# shield actually is. Blurring the entire board for a sheet covering a fraction of
	# it costs more than laying the sheet did.
	_mask_bytes.fill(0)
	# What "full" means is the strongest shield on the board right now, so the fade
	# reads as this Bloom's shield being consumed rather than as a comparison against
	# a rank the run may not have taken.
	var strongest := 0.0
	for cell in cells:
		strongest = maxf(strongest, territory_field.get_cell_aftergrowth(cell))
	if strongest <= 0.0:
		_shielded = 0
		visible = false
		return
	var min_x := _width
	var max_x := -1
	var min_y := _height
	var max_y := -1
	for cell in cells:
		if cell < 0 or cell >= _cell_count:
			continue
		var share := clampf(territory_field.get_cell_aftergrowth(cell) / strongest, 0.0, 1.0)
		_mask_bytes[cell] = clampi(int(share * 255.0), 0, 255)
		var x := cell % _width
		var y := cell / _width
		if x < min_x:
			min_x = x
		if x > max_x:
			max_x = x
		if y < min_y:
			min_y = y
		if y > max_y:
			max_y = y
	if max_x >= 0 and blur_passes > 0:
		# One cell of reach per pass, plus one so the outermost ring the blur reads is
		# guaranteed to be the empty margin rather than stale values from last time.
		var margin := blur_passes + 1
		var rect_x0 := maxi(0, min_x - margin)
		var rect_x1 := mini(_width - 1, max_x + margin)
		var rect_y0 := maxi(0, min_y - margin)
		var rect_y1 := mini(_height - 1, max_y + margin)
		for _pass_index in range(blur_passes):
			_blur_rect(rect_x0, rect_y0, rect_x1, rect_y1)
	_mask_image.set_data(_width, _height, false, Image.FORMAT_R8, _mask_bytes)
	_mask_texture.update(_mask_image)


func _blur_rect(x0: int, y0: int, x1: int, y1: int) -> void:
	# A separable 1-2-1 kernel over the sheet's own bounding box. Reads are clamped to
	# the box, which is the same answer as clamping to zero because the box carries a
	# margin of empty cells on every side, and it means the pass never touches the
	# rest of the board.
	for y in range(y0, y1 + 1):
		var row := y * _width
		var previous: int = _mask_bytes[row + x0]
		var here: int = previous
		for x in range(x0, x1 + 1):
			var next: int = _mask_bytes[row + x + 1] if x < x1 else here
			_blur_bytes[row + x] = (previous + here * 2 + next) / 4
			previous = here
			here = next
	for y in range(y0, y1 + 1):
		var row := y * _width
		var above := (y - 1 if y > y0 else y) * _width
		var below := (y + 1 if y < y1 else y) * _width
		for x in range(x0, x1 + 1):
			var up: int = _blur_bytes[above + x]
			var here: int = _blur_bytes[row + x]
			var down: int = _blur_bytes[below + x]
			_mask_bytes[row + x] = (up + here * 2 + down) / 4
