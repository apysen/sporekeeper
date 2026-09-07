class_name PhaseBTerritoryComposition
extends Control

## The territory bar: how much of the arena the run holds, and how much of it Rot has
## taken. Two colours in one bar, with whatever neither of them holds left as bare
## track between them.
##
## It draws the bar's own authored fill art through a shader that tints it, rather than
## drawing a shape of its own. That is the whole reason the shader exists: a silhouette
## worked out in code was an approximation of the art and drifted from it at the caps,
## and a stack of flat rectangles with square ends on a soft-edged bar was the most
## visible thing wrong with the original.
##
## It applies to the inner ends too. Where the Green stops and where the Rot starts are
## not the ends of the drawn rectangle, so they get no cap from the nine-slice and were
## cut off square; the shader now stamps the art's own end cap there instead. All four
## ends of the two bodies are the same rounded shape, and it is the shape the health and
## XP bars end in. Where the two bodies run together the cut fades out entirely and the
## colours cross-fade, so they read as one body changing colour rather than as two
## pills touching. The shader does not animate and contains no TIME.
##
## Two colours and no more. It briefly carried four -- established Green and open soil
## as well -- and that was too many things to read at a glance on a strip thirty pixels
## tall. Open soil says what it needs to say by being empty, which is the same thing
## every other bar in the HUD means by empty, so it costs no colour at all. Established
## Green is still published by the field and still shown in the hover; it is simply not
## something this bar tries to say.
##
## The distinction it exists to make survives that trim intact: an arena that is mostly
## empty here is available soil and recoverable, while an arena that is mostly Rot is
## entrenched and is not. Those two situations used to render as the same empty space
## to the right of the fill.

## The authored fill art. The same StyleBox the ProgressBar would have used, which is
## what makes the silhouette match rather than approximate.
@export var fill_style: StyleBox
## Held Green. Taken from the authored territory_fill art (131, 161, 88) so this bar
## sits in the same palette as the health and XP bars beside it.
@export var green_color := Color(0.514, 0.631, 0.345)
## Ground the enemy holds. Sampled from the Rot wash the field actually paints with
## (81, 41, 59 -- a desaturated plum) and lifted for legibility at HUD size. It was
## previously a pure red that named nothing on the battlefield.
@export var hostile_color := Color(0.430, 0.215, 0.305)
## Half-width of the cross-fade where the two colours touch, as a fraction of the bar.
## The field has no hard line between Green and Rot and neither should its readout, and
## when the two bodies run together this is what makes the join a blend rather than a
## seam.
@export_range(0.0, 0.25, 0.001) var blend_fraction := 0.035

var _player_percent := 0.0
var _neutral_percent := 0.0
var _hostile_percent := 0.0
## Share of held Green that has matured. Kept because the field publishes it and the
## hover reads it, even though the bar itself no longer draws it.
var _mature_fraction_of_green := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh()


func set_composition(
	player_percent: float,
	neutral_percent: float,
	hostile_percent: float,
	mature_fraction_of_green: float
) -> void:
	_player_percent = clampf(player_percent, 0.0, 100.0)
	_neutral_percent = clampf(neutral_percent, 0.0, 100.0)
	_hostile_percent = clampf(hostile_percent, 0.0, 100.0)
	_mature_fraction_of_green = clampf(mature_fraction_of_green, 0.0, 100.0)
	_refresh()


func get_player_percent() -> float:
	return _player_percent


func get_mature_fraction_of_green() -> float:
	return _mature_fraction_of_green


func get_colour_edges() -> Vector2:
	## Where the Green ends and where the Rot begins, as fractions along the bar.
	## Everything between them is bare track. This is the only geometry this component
	## owns -- the shape is the bar's own art and the rest happens in the shader -- so
	## it is what the probe measures.
	var green_edge := clampf(_player_percent * 0.01, 0.0, 1.0)
	# Measured back from the right end rather than forward from the Green, so the Rot
	# always ends flush with the bar even when the three shares round imperfectly.
	var hostile_edge := clampf(1.0 - _hostile_percent * 0.01, 0.0, 1.0)
	return Vector2(green_edge, maxf(green_edge, hostile_edge))


func _refresh() -> void:
	var shader_material := material as ShaderMaterial
	if shader_material != null:
		var edges := get_colour_edges()
		shader_material.set_shader_parameter("bar_width_px", maxf(1.0, size.x))
		shader_material.set_shader_parameter("green_edge", edges.x)
		shader_material.set_shader_parameter("hostile_edge", edges.y)
		shader_material.set_shader_parameter("blend_width", blend_fraction)
		shader_material.set_shader_parameter("green_color", green_color)
		shader_material.set_shader_parameter("hostile_color", hostile_color)
		# Where the authored end cap lives in the art, so the shader can stamp that
		# same profile at the inner ends. Read off the StyleBox rather than typed into
		# the shader, so re-authoring the bar art cannot leave the inner ends a
		# different shape from the outer ones.
		var texture_style := fill_style as StyleBoxTexture
		if texture_style != null and texture_style.texture != null:
			shader_material.set_shader_parameter(
				"art_width_px",
				maxf(1.0, float(texture_style.texture.get_width()))
			)
			shader_material.set_shader_parameter(
				"cap_width_px",
				maxf(1.0, texture_style.texture_margin_left)
			)
	queue_redraw()


func _draw() -> void:
	# One draw spanning the whole bar. Where each colour actually stops is carved out of
	# it in the shader, because two separate draws would meet cap to cap and pinch in
	# the middle at the moment the unheld span closed.
	if fill_style == null:
		return
	draw_style_box(fill_style, Rect2(Vector2.ZERO, size))
