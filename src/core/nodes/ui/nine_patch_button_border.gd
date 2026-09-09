class_name NinePatchButtonBorder
extends NinePatchRect

## Replaces a Button's StyleBoxTexture drawing with a real NinePatchRect. The
## corners remain fixed while only the middle edge strips stretch. The Button
## remains the input owner and still draws its own text.

const STYLE_NAMES := [
	&"normal",
	&"pressed",
	&"hover",
	&"disabled",
	&"hover_pressed",
	&"focus",
]

var _button: Button
var _styles := {}
var _last_draw_mode := -1
var _last_focused := false


static func install_under(root: Node) -> void:
	var buttons: Array[Button] = []
	_collect_buttons(root, buttons)
	for button in buttons:
		if button.get_node_or_null("NinePatchBorder") != null:
			continue
		var border := NinePatchButtonBorder.new()
		border.name = "NinePatchBorder"
		button.add_child(border)


static func _collect_buttons(node: Node, result: Array[Button]) -> void:
	if node is Button:
		result.append(node as Button)
	for child in node.get_children():
		_collect_buttons(child, result)


func _ready() -> void:
	_button = get_parent() as Button
	if _button == null:
		set_process(false)
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	_capture_styles()
	_update_for_draw_mode(true)


func _process(_delta: float) -> void:
	_update_for_draw_mode(false)


func _capture_styles() -> void:
	for style_name in STYLE_NAMES:
		var style := _button.get_theme_stylebox(style_name)
		if style is StyleBoxTexture:
			_styles[style_name] = style as StyleBoxTexture
	# A transparent replacement prevents the original stretched StyleBox from
	# showing beneath this node. Preserve content margins for container-sized rows.
	for style_name in STYLE_NAMES:
		# Focus is an overlay in many themes. If it is not itself texture-backed,
		# leave it intact instead of silently removing keyboard-focus feedback.
		if style_name == &"focus" and not _styles.has(style_name):
			continue
		var source: StyleBoxTexture = _style_for_name(style_name)
		if source == null:
			continue
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = source.content_margin_left
		empty.content_margin_top = source.content_margin_top
		empty.content_margin_right = source.content_margin_right
		empty.content_margin_bottom = source.content_margin_bottom
		_button.add_theme_stylebox_override(style_name, empty)


func _update_for_draw_mode(force: bool) -> void:
	if _button == null:
		return
	var draw_mode := _button.get_draw_mode()
	var focused := _button.has_focus()
	if not force and draw_mode == _last_draw_mode and focused == _last_focused:
		return
	_last_draw_mode = draw_mode
	_last_focused = focused
	var style_name := &"normal"
	match draw_mode:
		BaseButton.DRAW_PRESSED:
			style_name = &"pressed"
		BaseButton.DRAW_HOVER:
			style_name = &"hover"
		BaseButton.DRAW_DISABLED:
			style_name = &"disabled"
		BaseButton.DRAW_HOVER_PRESSED:
			style_name = &"hover_pressed"
	if draw_mode == BaseButton.DRAW_NORMAL and focused and _styles.has(&"focus"):
		style_name = &"focus"
	var style: StyleBoxTexture = _style_for_name(style_name)
	visible = style != null
	if style == null:
		return
	texture = style.texture
	patch_margin_left = roundi(style.texture_margin_left)
	patch_margin_top = roundi(style.texture_margin_top)
	patch_margin_right = roundi(style.texture_margin_right)
	patch_margin_bottom = roundi(style.texture_margin_bottom)
	draw_center = style.draw_center
	modulate = style.modulate_color


func _style_for_name(style_name: StringName) -> StyleBoxTexture:
	var style := _styles.get(style_name) as StyleBoxTexture
	if style != null:
		return style
	if style_name == &"hover_pressed":
		style = _styles.get(&"pressed") as StyleBoxTexture
	elif style_name == &"disabled":
		style = _styles.get(&"normal") as StyleBoxTexture
	elif style_name == &"focus":
		style = _styles.get(&"normal") as StyleBoxTexture
	if style == null:
		style = _styles.get(&"normal") as StyleBoxTexture
	return style
