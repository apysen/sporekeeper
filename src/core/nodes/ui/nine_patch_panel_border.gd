class_name NinePatchPanelBorder
extends NinePatchRect

## Presents a texture-backed Panel style through a real NinePatchRect. This keeps
## each source corner at its native dimensions and stretches only the edge centers.

var _panel: Control
var _syncing := false


static func install_under(root: Node) -> void:
	var panels: Array[Control] = []
	_collect_panels(root, panels)
	for panel in panels:
		if panel.get_node_or_null("NinePatchBorder") != null:
			continue
		var style := panel.get_theme_stylebox(&"panel")
		if not style is StyleBoxTexture:
			continue
		var border := NinePatchPanelBorder.new()
		border.name = "NinePatchBorder"
		panel.add_child(border)


static func _collect_panels(node: Node, result: Array[Control]) -> void:
	if node is Panel or node is PanelContainer:
		result.append(node as Control)
	for child in node.get_children(true):
		_collect_panels(child, result)


func _ready() -> void:
	_panel = get_parent() as Control
	if _panel == null:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	_panel.theme_changed.connect(_sync_style)
	_sync_style()


func _sync_style() -> void:
	if _syncing or _panel == null:
		return
	var source := _panel.get_theme_stylebox(&"panel") as StyleBoxTexture
	if source == null:
		return
	_syncing = true
	texture = source.texture
	patch_margin_left = roundi(source.texture_margin_left)
	patch_margin_top = roundi(source.texture_margin_top)
	patch_margin_right = roundi(source.texture_margin_right)
	patch_margin_bottom = roundi(source.texture_margin_bottom)
	draw_center = source.draw_center
	modulate = source.modulate_color
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = source.content_margin_left
	empty.content_margin_top = source.content_margin_top
	empty.content_margin_right = source.content_margin_right
	empty.content_margin_bottom = source.content_margin_bottom
	_panel.add_theme_stylebox_override(&"panel", empty)
	_syncing = false
