@tool
class_name WagerSlider
extends HSlider

## The stake selector: it draws its own bar, its own fill and its own knob, and takes no
## size from the theme.
##
## Three things the stock Slider will not do, all worth doing on the one control that
## spends territory.
##
## **It cannot be freely sized.** A Slider measures itself against its grabber icon and
## its track stylebox, so the control has a floor it cannot be dragged below and the knob
## has to be whatever the icon is. Everything the theme would have contributed is empty
## here - a one-pixel transparent grabber, an empty track - so the node can be dragged to
## any size in the editor, and the bar and the knob are drawn to whatever it is.
##
## **It cannot say what state the knob is in.** The theme carries two grabber icons and
## uses the second for hovered, focused and held alike, so reaching for the knob and
## having it in hand look identical.
##
## **It cannot draw art at more detail than the canvas.** This project lays its interface
## out in 1280x720 and stretches the canvas to whatever the display is, so on a 1440p
## screen every UI texture is magnified twice over. Fonts survive it - Godot re-rasterises
## them at the drawn scale - but a texture handed straight to a control is drawn one texel
## per canvas unit and has no more detail to give. Drawn into a rect this script chooses,
## the art can be several times the size it occupies and the magnified canvas still has
## texels to sample. The knob textures are 192px for the ~48 units they occupy.
##
## The ticks are drawn here for the same reason. The Slider draws them as part of its
## own handling of the draw notification, and a script's `_draw` runs after that, so
## anything this paints lands on top of them - the bar included, which is exactly what
## buried them. The scene hands the theme a transparent tick so the Slider draws none,
## and they are painted afterwards with the bar already down. `tick_count`,
## `ticks_on_borders` and `ticks_position` stay the Slider's own properties and still
## say how many there are, whether the ends count, and which side of the bar they
## take - this only moves the drawing later so the bar cannot bury them.
##
## Nothing here writes a theme override. A `@tool` script that does gets the override
## saved into the scene file, embedded image and all.
##
## Runs as a tool script, so dragging any of this in the editor shows what the game draws.

@export_group("Bar")
## How thick the bar is drawn, in canvas units, whatever height the node is dragged to.
## The HP, Green and XP meters stand at 32; this is meant to read as half of one.
@export_range(2.0, 64.0, 1.0) var bar_thickness := 16.0:
	set(value):
		bar_thickness = value
		queue_redraw()
## The empty bar, drawn across the whole width.
@export var track_style: StyleBox:
	set(value):
		track_style = value
		queue_redraw()
## The staked part, drawn from the left to the middle of the knob.
@export var fill_style: StyleBox:
	set(value):
		fill_style = value
		queue_redraw()

@export_group("Ticks")
## How far a tick reaches below the bar, in canvas units.
@export_range(0.0, 32.0, 1.0) var tick_length := 8.0:
	set(value):
		tick_length = value
		queue_redraw()
## How wide each tick is drawn.
@export_range(1.0, 8.0, 1.0) var tick_thickness := 2.0:
	set(value):
		tick_thickness = value
		queue_redraw()
## How far a tick sits clear of the bar. Which side of the bar it sits on is the
## Slider's own `Ticks Position`; this is the distance. Negative pulls them back
## toward the bar and then over it.
@export_range(-48.0, 48.0, 1.0) var tick_gap := 2.0:
	set(value):
		tick_gap = value
		queue_redraw()
@export var tick_color := Color(0.337, 0.376, 0.322, 1.0):
	set(value):
		tick_color = value
		queue_redraw()

@export_group("Handle")
## How many canvas units across the knob is drawn. Free in both directions: nothing else
## takes its size from this, and the textures are several times larger than any value it
## is likely to hold.
@export_range(4.0, 128.0, 1.0) var knob_size := 48.0:
	set(value):
		knob_size = value
		queue_redraw()
## At rest.
@export var grabber_texture: Texture2D:
	set(value):
		grabber_texture = value
		queue_redraw()
## Under the cursor, or holding focus: the knob is reachable.
@export var grabber_hover_texture: Texture2D:
	set(value):
		grabber_hover_texture = value
		queue_redraw()
## In hand and moving.
@export var grabber_pressed_texture: Texture2D:
	set(value):
		grabber_pressed_texture = value
		queue_redraw()

var _pointed_at := false
var _held := false


func _ready() -> void:
	mouse_entered.connect(_on_pointed_at)
	mouse_exited.connect(_on_pointed_away)
	drag_started.connect(_on_held)
	drag_ended.connect(_on_released)
	value_changed.connect(_on_value_changed)
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var bar := bar_rect()
	if track_style != null:
		track_style.draw(get_canvas_item(), bar)
	# Before the fill, not after: a tick the stake has already passed is a mark on
	# ground the player has bought, and it belongs under the paint rather than over it.
	# Ticks placed clear of the bar are untouched by this - the fill never reaches them.
	_draw_ticks(bar)
	if fill_style != null:
		# To the middle of the knob rather than to its leading edge, so the bar reads as
		# ending where the knob says the value is.
		var stopped := knob_rect().get_center().x
		if stopped > bar.position.x:
			fill_style.draw(
				get_canvas_item(),
				Rect2(bar.position, Vector2(stopped - bar.position.x, bar.size.y))
			)
	var knob := current_grabber_texture()
	if knob != null:
		draw_texture_rect(knob, knob_rect(), false)


## The marks along the bar, at the count, ends and side the Slider's own tick
## properties describe, painted after the bar rather than under it.
func _draw_ticks(bar: Rect2) -> void:
	if tick_count < 2 or tick_length <= 0.0 or tick_color.a <= 0.0:
		return
	var travel: float = maxf(size.x - tick_thickness, 0.0)
	# Where the top of a mark sits, once per row of them: `Both` is the only setting
	# that asks for two.
	var rows := PackedFloat32Array()
	var above: float = bar.position.y - tick_gap - tick_length
	var below: float = bar.end.y + tick_gap
	match ticks_position:
		TICK_POSITION_TOP_LEFT:
			rows.append(above)
		TICK_POSITION_BOTH:
			rows.append(above)
			rows.append(below)
		TICK_POSITION_CENTER:
			# Across the bar rather than clear of it, so the gap has nothing to say.
			rows.append(bar.get_center().y - tick_length * 0.5)
		_:
			rows.append(below)
	for index in range(tick_count):
		if not ticks_on_borders and (index == 0 or index == tick_count - 1):
			continue
		var along: float = float(index) / float(tick_count - 1)
		for top: float in rows:
			draw_rect(
				Rect2(
					Vector2(roundf(along * travel), roundf(top)),
					Vector2(tick_thickness, tick_length)
				),
				tick_color
			)


## The bar, centred in whatever height the node has been given.
func bar_rect() -> Rect2:
	var thickness: float = minf(bar_thickness, size.y)
	return Rect2(
		Vector2(0.0, roundf((size.y - thickness) * 0.5)),
		Vector2(size.x, thickness)
	)


## Where the knob is drawn, in this control's own coordinates: it travels the width less
## its own size, and is centred across.
func knob_rect() -> Rect2:
	var span: float = maxf(max_value - min_value, 0.0001)
	var ratio: float = clampf((value - min_value) / span, 0.0, 1.0)
	var travel: float = maxf(size.x - knob_size, 0.0)
	return Rect2(
		Vector2(roundf(ratio * travel), roundf((size.y - knob_size) * 0.5)),
		Vector2(knob_size, knob_size)
	)


## The art the knob is wearing right now. Held wins over pointed at: the cursor is over
## the knob throughout a drag, and a knob that reads as merely hovered while it is being
## moved is the wrong of the two.
func current_grabber_texture() -> Texture2D:
	var resting := grabber_texture
	if resting == null:
		return null
	var pointed := grabber_hover_texture if grabber_hover_texture != null else resting
	var held := grabber_pressed_texture if grabber_pressed_texture != null else pointed
	if _held:
		return held
	return pointed if _pointed_at else resting


func _on_pointed_at() -> void:
	_pointed_at = true
	queue_redraw()


func _on_pointed_away() -> void:
	_pointed_at = false
	queue_redraw()


func _on_held() -> void:
	_held = true
	queue_redraw()


func _on_released(_value_changed: bool) -> void:
	_held = false
	queue_redraw()


func _on_value_changed(_value: float) -> void:
	queue_redraw()


func _set(property: StringName, _value: Variant) -> bool:
	# `tick_count`, `ticks_on_borders` and `ticks_position` are the Slider's own, and
	# the Slider has no reason to redraw for them now that it draws no ticks itself.
	# Returning false lets the property be set normally; this only listens.
	if str(property).begins_with("tick"):
		call_deferred("queue_redraw")
	return false
