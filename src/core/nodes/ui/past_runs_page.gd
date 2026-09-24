class_name PastRunsPage
extends Control

## The menu's record of finished runs: a list on the left, and the one picked on the
## right with the same contribution table the result panel showed when it ended.
##
## Read from `MetaRecord.history`, which the run writes as it finishes. Runs that
## ended before the history existed are not in it -- the record only ever kept their
## totals -- so a player with finished runs and an empty list is told so rather than
## shown nothing.

signal closed

const LABEL_FONT: Font = preload("res://assets/fonts/beholden/Beholden-Medium.ttf")
const BACKING := Color(0.106, 0.114, 0.094, 0.97)
const PANEL := Color(0.0, 0.0, 0.0, 0.22)
const TEXT := Color(0.91, 0.875, 0.784, 1.0)
const MUTED := Color(0.663, 0.69, 0.608, 1.0)
const HELD := Color(0.698, 0.796, 0.51, 1.0)
const WITHERED := Color(0.643, 0.373, 0.424, 1.0)
const SELECTED := Color(0.831, 0.663, 0.31, 1.0)
const MARGIN := 32.0
const LIST_WIDTH := 360.0
const ROW_HEIGHT := 48.0
const BUTTON_STYLE: StyleBox = preload("res://assets/ui/wx_fantasy_button.tres")
const BUTTON_HOVER_STYLE: StyleBox = preload("res://assets/ui/wx_fantasy_button_hover.tres")
const BUTTON_PRESSED_STYLE: StyleBox = preload("res://assets/ui/wx_fantasy_button_pressed.tres")

var _history: Array = []
var _selected := -1
var _list: VBoxContainer
var _detail_header: Label
var _detail_build: Label
var _summary: RunSummary
var _detail_scroll: ScrollContainer
var _empty_label: Label
var _row_buttons: Array[Button] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func build() -> void:
	var backing := ColorRect.new()
	backing.color = BACKING
	backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)

	var title := _make_label("PAST RUNS", 30, HELD)
	title.position = Vector2(MARGIN, 22.0)
	title.size = Vector2(600.0, 44.0)
	add_child(title)

	# Built from the menu's own button styles and framed the same way, rather than
	# copied from a menu button: the frame installer strips a button's styles when it
	# frames it, so a copy of a framed button has nothing left to frame.
	var back := Button.new()
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_stylebox_override("normal", BUTTON_STYLE)
	back.add_theme_stylebox_override("focus", BUTTON_STYLE)
	back.add_theme_stylebox_override("hover", BUTTON_HOVER_STYLE)
	back.add_theme_stylebox_override("pressed", BUTTON_PRESSED_STYLE)
	back.add_theme_color_override("font_color", TEXT)
	back.add_theme_font_size_override("font_size", 16)
	back.text = "BACK"
	back.position = Vector2(1280.0 - MARGIN - 200.0, 20.0)
	back.size = Vector2(200.0, 48.0)
	back.visible = true
	back.pressed.connect(func() -> void: closed.emit())
	add_child(back)
	NinePatchButtonBorder.install_under(self)

	var list_panel := Panel.new()
	list_panel.add_theme_stylebox_override("panel", _flat(PANEL))
	list_panel.position = Vector2(MARGIN, 84.0)
	list_panel.size = Vector2(LIST_WIDTH, 720.0 - 84.0 - MARGIN)
	add_child(list_panel)
	var list_scroll := ScrollContainer.new()
	list_scroll.position = Vector2(8.0, 8.0)
	list_scroll.size = list_panel.size - Vector2(16.0, 16.0)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(list_scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size.x = list_scroll.size.x - 12.0
	_list.add_theme_constant_override("separation", 6)
	list_scroll.add_child(_list)

	var detail_left := MARGIN + LIST_WIDTH + 20.0
	var detail_width := 1280.0 - detail_left - MARGIN
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.position = Vector2(detail_left, 84.0)
	_detail_scroll.size = Vector2(detail_width, 720.0 - 84.0 - MARGIN)
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_detail_scroll)
	var detail := VBoxContainer.new()
	detail.custom_minimum_size.x = detail_width - 16.0
	detail.add_theme_constant_override("separation", 10)
	_detail_scroll.add_child(detail)
	_detail_header = _make_label("", 20, TEXT)
	_detail_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_detail_header)
	_detail_build = _make_label("", 12, MUTED)
	_detail_build.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_detail_build)
	_summary = RunSummary.new()
	_summary.custom_minimum_size = Vector2(detail_width - 32.0, 0.0)
	detail.add_child(_summary)

	_empty_label = _make_label("", 14, MUTED)
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.position = Vector2(detail_left, 300.0)
	_empty_label.size = Vector2(detail_width, 80.0)
	add_child(_empty_label)


## Reads the record fresh each time the page opens, so a run finished since the menu
## was built is on it.
func open(record: MetaRecord) -> void:
	visible = true
	_history = record.history
	for child in _list.get_children():
		child.queue_free()
	_row_buttons.clear()
	for index in range(_history.size()):
		var button := _make_row(_history[index], index)
		_list.add_child(button)
		_row_buttons.append(button)
	var empty := _history.is_empty()
	_detail_scroll.visible = not empty
	_empty_label.visible = empty
	if empty:
		_empty_label.text = (
			"No finished runs recorded yet. A run is added here when it ends."
			if record.runs_finished == 0
			else "Runs finished before this page existed only kept their totals. "
				+ "The next run you finish will appear here."
		)
		return
	_select(0)


func _select(index: int) -> void:
	_selected = index
	for row_index in range(_row_buttons.size()):
		_style_row(_row_buttons[row_index], row_index == index)
	var entry: Dictionary = _history[index]
	var victory := bool(entry.get("victory", false))
	_detail_header.text = "%s  —  %s\n%s" % [
		"FRONTIER HELD" if victory else "THE FRONTIER WITHERED",
		RunMode.mode_name(int(entry.get("mode", RunMode.Id.CAMPAIGN))),
		"Wave %d    Time %s    Level %d    Green %.1f%%    Blight %d    %s" % [
			int(entry.get("wave", 0)),
			_format_time(float(entry.get("seconds", 0.0))),
			int(entry.get("level", 0)),
			float(entry.get("green", 0.0)),
			int(entry.get("blight", 0)),
			_format_date(int(entry.get("unix_time", 0))),
		],
	]
	_detail_header.add_theme_color_override("font_color", HELD if victory else WITHERED)
	_detail_build.text = "ADAPTATIONS  %s\nEVOLUTIONS  %s\nRELICS  %s" % [
		_join(entry.get("adaptations", [])),
		_join(entry.get("evolutions", [])),
		_join(entry.get("relics", [])),
	]
	var stats := RunStats.new()
	stats.apply_state(entry.get("stats", {}))
	_summary.show_stats(stats, int(entry.get("claimable_cells", 1)))
	_summary.custom_minimum_size.y = _summary.get_required_height() + 12.0
	_detail_scroll.scroll_vertical = 0


func _make_row(entry: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", LABEL_FONT)
	button.add_theme_font_size_override("font_size", 13)
	var victory := bool(entry.get("victory", false))
	button.text = "  %s  ·  WAVE %d  ·  %s\n  %s  ·  %s" % [
		"HELD" if victory else "WITHERED",
		int(entry.get("wave", 0)),
		_format_time(float(entry.get("seconds", 0.0))),
		_join(entry.get("adaptations", []), " / "),
		_format_date(int(entry.get("unix_time", 0))),
	]
	button.add_theme_color_override("font_color", HELD if victory else WITHERED)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.pressed.connect(_select.bind(index))
	return button


func _style_row(button: Button, selected: bool) -> void:
	var colour := Color(SELECTED.r, SELECTED.g, SELECTED.b, 0.22) if selected else Color(1, 1, 1, 0.04)
	var style := _flat(colour)
	if selected:
		style.border_color = SELECTED
		style.border_width_left = 3
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", _flat(Color(1, 1, 1, 0.09)))
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


static func _flat(colour: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


static func _make_label(text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", LABEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label


static func _join(values: Variant, separator := ", ") -> String:
	var parts := PackedStringArray()
	if values is Array or values is PackedStringArray:
		for value in values:
			parts.append(String(value).capitalize() if String(value) == String(value).to_upper() else String(value))
	return separator.join(parts) if not parts.is_empty() else "—"


static func _format_time(seconds: float) -> String:
	var whole := maxi(0, int(seconds))
	return "%02d:%02d" % [whole / 60, whole % 60]


static func _format_date(unix_time: int) -> String:
	if unix_time <= 0:
		return ""
	var date := Time.get_datetime_dict_from_unix_time(unix_time)
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d" % [MONTHS[clampi(int(date["month"]) - 1, 0, 11)], int(date["day"])]
