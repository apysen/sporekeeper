class_name TerritoryObstacleLayer
extends Node2D

## Draws basalt a second time, as the topmost gameplay layer, so nothing can be shown
## on top of the rock.
##
## The territory field already paints rock underneath the whole board. This repaints
## exactly the same rock above everything else, which is a countermeasure rather than
## a fix for any one overlay: every layer that stretches a coarse per-cell mask over
## the arena and reconstructs it smoothly bleeds a little past the frontier it was
## stamped against, and clipping each of them individually means solving the same
## problem again for every layer added afterwards. Rock that occludes is one rule that
## cannot be forgotten.
##
## The mask, the tear and the colour all come from the territory shader verbatim, and
## the numbers that decide where the rock's edge falls are mirrored off the field's own
## material rather than authored twice, so the two copies cannot drift apart and show a
## seam where they overlap.

const OBSTACLE_SHADER := preload("res://assets/shaders/obstacle_field.gdshader")

@export_group("Collaborators")
## Supplies the arena rect the field texture is stretched across.
@export var tuning: TerritoryPrototypeTuning
## Supplies the field texture and the border settings this has to match.
@export var territory_field: TerritoryField

var _material: ShaderMaterial
var _bound := false


func _ready() -> void:
	assert(tuning != null, "TerritoryObstacleLayer requires TerritoryPrototypeTuning")
	assert(territory_field != null, "TerritoryObstacleLayer requires a TerritoryField")
	# The cubic reconstruction in the shader is built from four bilinear taps, so the
	# node has to be sampling linearly for it to mean anything.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_configure_material()


func _process(_delta: float) -> void:
	# The rock itself never moves, but the texture it is read from is rebuilt every
	# time the field steps, and the board can be reset under it. Redrawing is a single
	# full-screen quad the GPU was going to composite anyway.
	if not _bound:
		_bind()
	queue_redraw()


func _draw() -> void:
	var field_texture := territory_field.get_field_texture()
	if field_texture == null:
		return
	draw_texture_rect(field_texture, Rect2(Vector2.ZERO, tuning.arena_size), false)


func _configure_material() -> void:
	var authored := material as ShaderMaterial
	if authored == null:
		_material = ShaderMaterial.new()
		_material.shader = OBSTACLE_SHADER
	else:
		_material = authored.duplicate() as ShaderMaterial
	material = _material
	_bind()


func _bind() -> void:
	# Where the rock's edge falls is the field's decision, not this layer's. Copying
	# the numbers instead of re-authoring them is what keeps the repaint sitting
	# exactly on the original rather than a pixel or two off it.
	_material.set_shader_parameter("field_size_px", tuning.arena_size)
	var field_material := territory_field.material as ShaderMaterial
	if field_material == null:
		return
	for parameter in [
		"edge_noise_tex",
		"edge_noise_tile_px",
		"edge_distortion_px",
		"edge_softness_px",
		"wall_color",
		"rock_base_color",
		"rock_shadow_color",
		"rock_shadow_depth",
		"rock_highlight_lift",
		"wall_border_cells",
		"rock_mottle_tile_px",
		"rock_texture_amount",
		"board_edge_cells",
	]:
		var value: Variant = field_material.get_shader_parameter(parameter)
		if value != null:
			_material.set_shader_parameter(parameter, value)
	# Without the noise texture the tear would displace every pixel by the same
	# constant, which shifts the whole contour instead of roughening it - and this
	# copy would then sit visibly beside the rock it is meant to cover.
	if field_material.get_shader_parameter("edge_noise_tex") == null:
		_material.set_shader_parameter("edge_distortion_px", 0.0)
	_bound = territory_field.get_field_texture() != null
