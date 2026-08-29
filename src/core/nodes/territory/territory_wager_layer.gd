class_name TerritoryWagerLayer
extends Node2D

## Draws the region the Clover machine is about to take, or has already taken.
##
## Its own layer rather than another pass inside the effects overlay, because it is a
## statement about the ground rather than an effect happening on top of it: it belongs
## between the territory field and everything that moves around on it, and a CanvasItem
## can only carry one material, which the overlay has already spent.
##
## The selection arrives as a list of cells, because a wager is counted in cells. What
## is drawn is a single texture stretched over the arena and reconstructed in the shader,
## so the highlight has the same soft border as the territory underneath it instead of
## reading as a grid of lit squares.

const WAGER_SHADER := preload("res://assets/shaders/wager_field.gdshader")

@export_group("Collaborators")
## Supplies the arena rect the mask is stretched across.
@export var tuning: TerritoryPrototypeTuning
## Supplies the mask resolution. It is the field's own grid, so the highlight and the
## border it sits on are reconstructed from the same lattice and cannot drift apart.
@export var territory_field: TerritoryField

@export_group("Appearance")
## Fill laid over ground on the table. Bright enough to read against Green, transparent
## enough that the territory underneath stays legible: the player has to be able to see
## what the wager is made of, not only how big it is.
@export var wager_color := Color(1.0, 0.86, 0.35, 1.0)
@export_range(0.0, 1.0, 0.01) var base_alpha := 0.22
## How far the preview breathes either side of the base alpha, and how fast. A committed
## wager is drawn with the amplitude at zero rather than with a second material.
@export_range(0.0, 0.5, 0.01) var pulse_amplitude := 0.08
@export_range(0.0, 6.0, 0.1) var pulse_hz := 1.6
## Width of the reconstructed contour's transition, in mask units. Larger is softer.
@export_range(0.001, 0.5, 0.005) var edge_softness := 0.09
## Extra alpha in a band just inside the contour, and how deep that band reaches.
@export_range(0.0, 1.0, 0.01) var boundary_boost := 0.30
@export_range(0.001, 0.6, 0.01) var boundary_width := 0.22

@export_group("Smoothing")
## Blur passes run over the mask before it is uploaded. The selection is binary, and a
## binary mask reconstructed on its own still carries the lattice in its contour; one
## pass is enough to bend that out, and the threshold is symmetric so blurring does not
## quietly change how much ground the region covers.
@export_range(0, 4, 1) var blur_passes := 1

var _mask_image: Image
var _mask_texture: ImageTexture
var _mask_material: ShaderMaterial
var _mask_bytes := PackedByteArray()
var _blur_bytes := PackedByteArray()
var _width := 0
var _height := 0
var _cell_count := 0
var _cells := PackedInt32Array()
var _committed := false


func _ready() -> void:
	assert(tuning != null, "TerritoryWagerLayer requires TerritoryPrototypeTuning")
	assert(territory_field != null, "TerritoryWagerLayer requires a TerritoryField")
	# The cubic reconstruction in the shader is built from four bilinear taps, so the
	# node has to be sampling linearly for it to mean anything.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_configure_material()
	_configure_buffers()
	visible = false


func _draw() -> void:
	if _mask_texture == null or _cells.is_empty():
		return
	draw_texture_rect(_mask_texture, Rect2(Vector2.ZERO, tuning.arena_size), false)


func set_wager_cells(cells: PackedInt32Array, committed: bool) -> void:
	## The region about to be risked, or the one already frozen. Two states, not two
	## overlays: the preview breathes and follows the player, the committed wager is
	## fixed in world space, and drawing both through one mask with one flag is what
	## keeps the second from looking like a bug in the first.
	_cells = cells
	_committed = committed
	if _cells.is_empty():
		visible = false
		queue_redraw()
		return
	_rebuild_mask()
	_mask_material.set_shader_parameter(
		"pulse_amplitude",
		0.0 if committed else pulse_amplitude
	)
	visible = true
	queue_redraw()


func clear_wager() -> void:
	if _cells.is_empty():
		return
	set_wager_cells(PackedInt32Array(), false)


func get_wager_cell_count() -> int:
	return _cells.size()


func is_committed() -> bool:
	return _committed


func _configure_material() -> void:
	var authored := material as ShaderMaterial
	if authored == null:
		_mask_material = ShaderMaterial.new()
		_mask_material.shader = WAGER_SHADER
	else:
		_mask_material = authored.duplicate() as ShaderMaterial
	material = _mask_material
	_mask_material.set_shader_parameter("wager_color", wager_color)
	_mask_material.set_shader_parameter("base_alpha", base_alpha)
	_mask_material.set_shader_parameter("pulse_amplitude", pulse_amplitude)
	_mask_material.set_shader_parameter("pulse_hz", pulse_hz)
	_mask_material.set_shader_parameter("edge_midpoint", 0.5)
	_mask_material.set_shader_parameter("edge_softness", edge_softness)
	_mask_material.set_shader_parameter("boundary_boost", boundary_boost)
	_mask_material.set_shader_parameter("boundary_width", boundary_width)
	_mirror_field_edge()


func _mirror_field_edge() -> void:
	# The tear is the ground's, not this layer's. Copying the numbers off the field's
	# own material rather than authoring them a second time is what keeps the wager's
	# contour ragged in the same way, at the same scale, as the border it sits on;
	# two copies would drift apart the moment either is tuned.
	_mask_material.set_shader_parameter("field_size_px", tuning.arena_size)
	var field_material := territory_field.material as ShaderMaterial
	if field_material == null:
		return
	for parameter in ["edge_noise_tex", "edge_noise_tile_px", "edge_distortion_px"]:
		var value: Variant = field_material.get_shader_parameter(parameter)
		if value != null:
			_mask_material.set_shader_parameter(parameter, value)
	# Without the noise texture the tear would displace every pixel by the same
	# constant, which shifts the whole region instead of roughening its edge.
	if field_material.get_shader_parameter("edge_noise_tex") == null:
		_mask_material.set_shader_parameter("edge_distortion_px", 0.0)


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


func _rebuild_mask() -> void:
	if _mask_image == null or territory_field.get_grid_width() != _width:
		_configure_buffers()
	# Cleared whole because that is a native memset, then worked on only where the region
	# actually is. Blurring the entire board for a region covering a tenth of it was
	# costing more than the flood that chose the region.
	_mask_bytes.fill(0)
	var min_x := _width
	var max_x := -1
	var min_y := _height
	var max_y := -1
	for cell in _cells:
		if cell < 0 or cell >= _cell_count:
			continue
		_mask_bytes[cell] = 255
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
	# A separable 1-2-1 kernel over the region's own bounding box. Reads are clamped to
	# the box, which is the same answer as clamping to zero because the box carries a
	# margin of empty cells on every side, and it means the pass never touches the rest
	# of the board.
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
