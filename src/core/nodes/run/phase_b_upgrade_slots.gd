@tool
class_name PhaseBUpgradeSlots
extends Control

## The run's growth lines as a row of rounded square slots. The widget owns only
## presentation: what a slot says and what its hover text reads are handed in by
## the run controller, which is the node that can see both the progression
## multipliers and the base values they act on.
##
## Runs as a tool script so the row builds itself in the editor too. Every visual
## property below rebuilds the row the moment it is changed, and the editor fills
## the slots with sample contents so a filled, an empty, and a locked slot are all
## on screen while they are being styled.

enum SlotState {
	EMPTY,
	FILLED,
	LOCKED,
}

@export_group("Layout")
## Slots drawn in the row, including the ones an Evolution unlocks later.
@export_range(1, 16, 1) var slot_count := 8:
	set(value):
		if slot_count == value:
			return
		slot_count = value
		_rebuild()
## Side length of each rounded square slot in pixels.
@export_range(16.0, 96.0, 1.0) var slot_size := 42.0:
	set(value):
		if slot_size == value:
			return
		slot_size = value
		_rebuild()
## Gap between slots in pixels.
@export_range(0.0, 32.0, 1.0) var slot_spacing := 7.0:
	set(value):
		if slot_spacing == value:
			return
		slot_spacing = value
		_rebuild()
## Corner rounding as a share of the slot's side.
@export_range(0.0, 0.5, 0.01) var corner_radius_scale := 0.24:
	set(value):
		if corner_radius_scale == value:
			return
		corner_radius_scale = value
		_rebuild()
## Border thickness of every slot in pixels.
@export_range(0, 6, 1) var border_width := 1:
	set(value):
		if border_width == value:
			return
		border_width = value
		_rebuild()
## Font size of the abbreviation on a filled slot.
@export_range(6, 32, 1) var title_font_size := 11:
	set(value):
		if title_font_size == value:
			return
		title_font_size = value
		_rebuild()
## Font size of the level readout under it.
@export_range(6, 32, 1) var level_font_size := 9:
	set(value):
		if level_font_size == value:
			return
		level_font_size = value
		_rebuild()

@export_group("Contents")
## Icon drawn in a slot the Evolution has not unlocked yet, in place of any text.
@export var locked_icon: Texture2D:
	set(value):
		if locked_icon == value:
			return
		locked_icon = value
		_rebuild()
## Side length of that icon as a share of the slot. The drawn icon is centred in
## the slot and capped by it, so this is the dial for how much of the square the
## lock fills.
@export_range(0.1, 1.0, 0.01) var locked_icon_scale := 0.72:
	set(value):
		if locked_icon_scale == value:
			return
		locked_icon_scale = value
		_rebuild()
## Tint applied to that icon. Defaults to the locked border colour when left white.
@export var locked_icon_modulate := Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		if locked_icon_modulate == value:
			return
		locked_icon_modulate = value
		_rebuild()
## Nudge applied to the lock icon in pixels, after it is centred.
@export var locked_icon_offset := Vector2.ZERO:
	set(value):
		if locked_icon_offset == value:
			return
		locked_icon_offset = value
		_rebuild()
## Marker drawn in a slot that is open but empty.
@export var empty_marker := "+":
	set(value):
		if empty_marker == value:
			return
		empty_marker = value
		_rebuild()
## Font size of that marker, which is usually worth setting larger than the
## abbreviation on a filled slot.
@export_range(6, 48, 1) var empty_marker_font_size := 16:
	set(value):
		if empty_marker_font_size == value:
			return
		empty_marker_font_size = value
		_rebuild()
## Vertical placement of the abbreviation, as a share of the slot.
@export_range(0.0, 1.0, 0.01) var title_offset_scale := 0.16:
	set(value):
		if title_offset_scale == value:
			return
		title_offset_scale = value
		_rebuild()
## Vertical placement of the level readout, as a share of the slot.
@export_range(0.0, 1.0, 0.01) var level_offset_scale := 0.52:
	set(value):
		if level_offset_scale == value:
			return
		level_offset_scale = value
		_rebuild()
## Horizontal nudge applied to everything drawn inside a slot: the abbreviation,
## the level readout, and the lock icon move together. Centred text is rounded to
## whole pixels, so a slot whose contents look a hair left of centre is corrected
## here rather than by re-centring each element separately.
##
## Whole pixels only, and deliberately so. Godot snaps a Control's rect to the
## pixel grid, so a fractional nudge moves each element at the value where its own
## rect happens to cross a pixel boundary. The elements start from different
## fractional origins, which made them appear to take turns moving; stepping in
## whole pixels is what keeps them in lockstep.
@export_range(-12.0, 12.0, 1.0) var content_offset_x := 0.0:
	set(value):
		if content_offset_x == value:
			return
		content_offset_x = value
		_rebuild()
## Vertical nudge applied to everything drawn inside a slot, on top of the two
## placement shares above. Whole pixels, for the same reason.
@export_range(-12.0, 12.0, 1.0) var content_offset_y := 0.0:
	set(value):
		if content_offset_y == value:
			return
		content_offset_y = value
		_rebuild()

@export_group("Art")
## Optional textured StyleBox used for the slot square. When set, the art supplies
## the shape and bevel and the palette below only tints it, so a filled, empty or
## locked slot still reads as itself. Left empty, slots are drawn flat as before.
@export var slot_texture_style: StyleBox:
	set(value):
		if slot_texture_style == value:
			return
		slot_texture_style = value
		_rebuild()

@export_group("Palette")
## Fill of a slot with nothing in it yet.
@export var empty_color := Color(0.055, 0.085, 0.075, 0.90):
	set(value):
		if empty_color == value:
			return
		empty_color = value
		_rebuild()
## Fill of a slot holding a growth line.
@export var filled_color := Color(0.075, 0.185, 0.130, 0.96):
	set(value):
		if filled_color == value:
			return
		filled_color = value
		_rebuild()
## Fill of a slot an Evolution has not unlocked yet.
@export var locked_color := Color(0.045, 0.050, 0.058, 0.90):
	set(value):
		if locked_color == value:
			return
		locked_color = value
		_rebuild()
## Border of an empty slot.
@export var empty_border := Color(0.22, 0.36, 0.32, 0.70):
	set(value):
		if empty_border == value:
			return
		empty_border = value
		_rebuild()
## Border of a slot holding a growth line.
@export var filled_border := Color(0.38, 0.92, 0.58, 0.90):
	set(value):
		if filled_border == value:
			return
		filled_border = value
		_rebuild()
## Border of a locked slot.
@export var locked_border := Color(0.30, 0.26, 0.20, 0.75):
	set(value):
		if locked_border == value:
			return
		locked_border = value
		_rebuild()

var _slot_panels: Array[Panel] = []
var _slot_titles: Array[Label] = []
var _slot_levels: Array[Label] = []
var _slot_locks: Array[TextureRect] = []


func _enter_tree() -> void:
	# The editor only runs _ready when a scene is instantiated, so a node that was
	# already in an open scene when the script became a tool script would stay
	# empty until reload. Building on enter covers both.
	if Engine.is_editor_hint():
		_build_slots()
		_fill_editor_preview()


func _ready() -> void:
	_build_slots()
	if Engine.is_editor_hint():
		_fill_editor_preview()


func _rebuild() -> void:
	# Property setters fire before the node is in the tree during load, so the
	# initial build is left to _ready and only later edits rebuild in place.
	if not is_node_ready():
		return
	_build_slots()
	if Engine.is_editor_hint():
		_fill_editor_preview()


func _fill_editor_preview() -> void:
	# Sample contents so a filled, an empty, and a locked slot are all visible
	# while the row is being styled. Play overwrites every slot on the first HUD
	# refresh, so nothing here can leak into a run.
	for index in range(_slot_panels.size()):
		if index == 0:
			set_slot(index, "TP", "3", "", SlotState.FILLED)
		elif index == 1:
			set_slot(index, "EN", "5", "", SlotState.FILLED)
		elif index >= _slot_panels.size() - 2:
			set_slot(index, "", "", "", SlotState.LOCKED)
		else:
			set_slot(index, "+", "", "", SlotState.EMPTY)


func get_slot_count() -> int:
	return _slot_panels.size()


func get_slot_tooltip(index: int) -> String:
	# Read back for tests and for anything that wants to mirror the hover text.
	if index < 0 or index >= _slot_panels.size():
		return ""
	return _slot_panels[index].tooltip_text


func get_slot_level_text(index: int) -> String:
	if index < 0 or index >= _slot_levels.size():
		return ""
	return _slot_levels[index].text


func is_slot_locked_icon_visible(index: int) -> bool:
	if index < 0 or index >= _slot_locks.size():
		return false
	return _slot_locks[index].visible


func set_slot(
	index: int,
	title: String,
	level_text: String,
	tooltip: String,
	state: int
) -> void:
	if index < 0 or index >= _slot_panels.size():
		return
	var panel := _slot_panels[index]
	panel.tooltip_text = tooltip
	panel.add_theme_stylebox_override("panel", _build_style(state))
	# A locked slot says everything it needs to with the icon alone.
	var locked := state == SlotState.LOCKED
	_slot_locks[index].visible = locked and locked_icon != null
	_slot_titles[index].visible = not _slot_locks[index].visible
	_slot_titles[index].text = title
	_slot_titles[index].add_theme_font_size_override(
		"font_size",
		empty_marker_font_size if state == SlotState.EMPTY else title_font_size
	)
	_slot_levels[index].text = level_text
	_slot_levels[index].visible = not level_text.is_empty()
	match state:
		SlotState.FILLED:
			_slot_titles[index].add_theme_color_override(
				"font_color",
				Color(0.84, 1.0, 0.88)
			)
			_slot_levels[index].add_theme_color_override(
				"font_color",
				Color(0.55, 0.92, 0.70)
			)
		SlotState.LOCKED:
			_slot_titles[index].add_theme_color_override(
				"font_color",
				Color(0.52, 0.46, 0.36)
			)
			_slot_levels[index].add_theme_color_override(
				"font_color",
				Color(0.44, 0.39, 0.31)
			)
		_:
			_slot_titles[index].add_theme_color_override(
				"font_color",
				Color(0.40, 0.55, 0.50)
			)
			_slot_levels[index].add_theme_color_override(
				"font_color",
				Color(0.33, 0.46, 0.42)
			)


func _build_slots() -> void:
	for child in get_children(true):
		remove_child(child)
		child.queue_free()
	_slot_panels.clear()
	_slot_titles.clear()
	_slot_levels.clear()
	_slot_locks.clear()
	# Snapped once, here, rather than left to each Control to round on its own.
	var nudge := Vector2(roundf(content_offset_x), roundf(content_offset_y))
	for index in range(slot_count):
		var panel := Panel.new()
		panel.name = "Slot%d" % (index + 1)
		panel.position = Vector2(float(index) * (slot_size + slot_spacing), 0.0)
		panel.size = Vector2(slot_size, slot_size)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.add_theme_stylebox_override("panel", _build_style(SlotState.EMPTY))
		# Generated rather than authored, so the children are never written into the
		# scene: the row is rebuilt from these properties every time it loads.
		add_child(panel, false, Node.INTERNAL_MODE_FRONT)

		var title := Label.new()
		title.name = "Title"
		title.position = Vector2(
			nudge.x,
			roundf(slot_size * title_offset_scale) + nudge.y
		)
		title.size = Vector2(slot_size, slot_size * 0.34)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", title_font_size)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(title)

		var level := Label.new()
		level.name = "Level"
		level.position = Vector2(
			nudge.x,
			roundf(slot_size * level_offset_scale) + nudge.y
		)
		level.size = Vector2(slot_size, slot_size * 0.34)
		level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		level.add_theme_font_size_override("font_size", level_font_size)
		level.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(level)

		var lock := TextureRect.new()
		lock.name = "Lock"
		lock.texture = locked_icon
		# Anchored to the whole slot and inset evenly, rather than positioned and
		# sized by hand: a hand-placed rect is re-laid out against the texture's own
		# minimum size, which is what pushed the icon toward the bottom right.
		lock.set_anchors_preset(Control.PRESET_FULL_RECT)
		# The inset is rounded too: at a fractional origin the icon's rect crosses
		# the pixel grid at different nudge values than the labels do, which is what
		# made the icon and the text move one at a time.
		var inset := roundf(
			slot_size * (1.0 - clampf(locked_icon_scale, 0.05, 1.0)) * 0.5
		)
		lock.offset_left = inset + roundf(locked_icon_offset.x) + nudge.x
		lock.offset_top = inset + roundf(locked_icon_offset.y) + nudge.y
		lock.offset_right = -inset + roundf(locked_icon_offset.x) + nudge.x
		lock.offset_bottom = -inset + roundf(locked_icon_offset.y) + nudge.y
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.modulate = (
			locked_border
			if locked_icon_modulate == Color(1.0, 1.0, 1.0, 1.0)
			else locked_icon_modulate
		)
		lock.visible = false
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(lock)

		_slot_panels.append(panel)
		_slot_titles.append(title)
		_slot_levels.append(level)
		_slot_locks.append(lock)


func _build_style(state: int) -> StyleBox:
	if slot_texture_style != null:
		return _build_texture_style(state)
	var style := StyleBoxFlat.new()
	match state:
		SlotState.FILLED:
			style.bg_color = filled_color
			style.border_color = filled_border
			style.set_border_width_all(border_width)
		SlotState.LOCKED:
			style.bg_color = locked_color
			style.border_color = locked_border
			style.set_border_width_all(border_width)
		_:
			style.bg_color = empty_color
			style.border_color = empty_border
			style.set_border_width_all(border_width)
	style.set_corner_radius_all(int(round(slot_size * corner_radius_scale)))
	return style


func _build_texture_style(state: int) -> StyleBox:
	# One piece of art, tinted per state. The border colours the flat styles use are
	# what the eye actually reads a slot's state from, so they become the tint here
	# rather than being thrown away with the flat box.
	var style: StyleBoxTexture = slot_texture_style.duplicate()
	match state:
		SlotState.FILLED:
			style.modulate_color = filled_border
		SlotState.LOCKED:
			style.modulate_color = locked_border
		_:
			style.modulate_color = empty_border
	return style
