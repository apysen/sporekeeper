class_name MechanicsHelp
extends Control

signal glossary_closed

const BORDER_TEXTURE := preload("res://assets/ui/kenney/panel-border-008.png")
const GOLD := Color(0.769, 0.604, 0.314, 1.0)
const GOLD_BRIGHT := Color(0.96, 0.83, 0.48, 1.0)
const OLIVE := Color(0.09, 0.102, 0.082, 0.98)
const TEXT := Color(0.91, 0.875, 0.784, 1.0)
const MUTED := Color(0.663, 0.69, 0.608, 1.0)
const BORDER_CORNER_SIZE := 8
const REWARD_GAP := 6.0
const HUD_GAP := 6.0

enum TooltipMode {
	NONE,
	REWARD,
	HUD,
}

const ENTRIES := {
	"AFTERGROWTH": "A temporary shield left on Green by Bloom. Hostile territory damage removes Aftergrowth before it damages the Green underneath.",
	"AMPLIFICATION": "The increase granted by Root Potency to another plant mechanic. The affected value is shown beside the upgrade when amplification applies.",
	"BIOMASS": "The ecosystem's renewable currency. Green and Mature Green produce it; Metabolism and Overgrow use it.",
	"BLOOM": "A plant event that bursts outward, damages enemies, and reclaims territory. Bloom upgrades change its force, frequency, and aftermath.",
	"BREAKTHROUGH": "A major Metabolism milestone. Reaching one unlocks a stronger expression of that metabolic system.",
	"CAMBIUM": "The Cohesion branch of Metabolism. It improves the strength and staying power of Green territory.",
	"COHESION": "How well Green holds together under hostile pressure. More Cohesion makes territory harder to break apart.",
	"CUTTINGS": "Material harvested by Pruning your own Green. Cuttings feed Pruning attacks and recovery effects.",
	"ENSNARE": "A Bramble control condition that prevents an enemy from moving for its duration. Ensnared enemies may still attack. Grasping Thorns is the line that applies it, and an Ensnared enemy is briefly immune afterwards rather than held forever.",
	"ENTANGLEMENT": "A buildup applied to enemies on Green. More Entanglement means a stronger slow; reaching full buildup Ensnares the enemy if Bramble is selected.",
	"GERMINATION": "The moment a Seed opens and creates Green. Germination speed controls how long a planted Seed takes to become territory.",
	"GREEN": "Territory controlled by the ecosystem. Green generates Biomass and enables many plant-path effects.",
	"MASS": "The amount of living material added to the field. More Mass creates more Green when growth effects resolve.",
	"MATURE": "Green that has aged and stabilized. Mature Green produces more value and powers the Root Network. Standing on it is worth checking: the golden Root Network light appears under Grandma only while she is on Mature Green.",
	"MERISTEM": "The Pressure branch of Metabolism. It improves the ecosystem's ability to push hostile territory back.",
	"METABOLISM": "Automatic long-run development powered by lifetime Biomass. Its three branches improve Mass, Pressure, and Cohesion.",
	"OVERGROW": "An active discharge that spends part of the Biomass Reserve and injects Mass, Pressure, and Cohesion into the chosen frontier.",
	"PHOTOSYNTHESIS": "The Mass branch of Metabolism. It improves how much living material the ecosystem produces.",
	"PRESSURE": "The outward force of Green against hostile territory. More Pressure helps reclaim and expand the field.",
	"PRUNING": "A plant path that deliberately harvests Green for Cuttings, attacks, and regrowth opportunities.",
	"REPULSION": "A Bramble effect that pushes enemies away from defended Green and its frontier.",
	"ROOT NETWORK": "The infrastructure formed by Mature Green. It carries Root Potency into compatible plant mechanics. While you own Root, a slow golden light breathes under Grandma and under each planted Thistle whenever that point is standing on Mature Green, and the stronger the light the deeper the Network there. It flares as you cross onto Mature Green and flares again as you leave it. Effects that gain a whole extra unit from Root Potency -- one more Fruit, thorn, or ricochet -- only gain it while that light is lit.",
	"ROOT POTENCY": "The strength of the Root Network. It amplifies compatible effects operating from Mature Green.",
	"SEED": "A planted growth source that creates Green when it germinates.",
	"SUPPRESSION": "A temporary Bloom condition that reduces how much territory damage affected enemies deal.",
	"TERRITORY": "The living field contested by Green, hostile growth, and neutral ground. Territory percentage is a core survival objective.",
	"THISTLE": "A plant path that grows a single turret on Green, and never more than one. Walk Grandma through it and the Thistle catches on her, firing from her side for a few seconds before it works loose and takes root wherever she is standing. Let it work loose off Green and it withers. Starting a Thistle line lengthens the carry and shortens the wait before it will catch again.",
	"THORNBURST": "A Bloom and Bramble evolution that turns prepared Bramble territory into a burst of thorn damage and traps.",
}

var _stack: VBoxContainer
var _glossary_overlay: Control
var _glossary_entries: VBoxContainer
var _letter_tabs := {}
var _active_letter := "ALL"
var _tooltip_mode := TooltipMode.NONE
var _source_rect := Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", 8)
	_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	_stack.visible = false
	add_child(_stack)
	_build_glossary()


func _process(_delta: float) -> void:
	if _tooltip_mode != TooltipMode.HUD or not _stack.visible:
		return
	var inspection_area := _source_rect.merge(_stack.get_rect()).grow(34.0)
	if not inspection_area.has_point(get_local_mouse_position()):
		hide_tooltip()


func show_hud_tooltip(title: String, description: String, anchor: Rect2) -> void:
	_tooltip_mode = TooltipMode.HUD
	_source_rect = anchor
	_clear_stack()
	_add_tooltip_card(title, description, 0, true)
	_stack.visible = false
	await get_tree().process_frame
	_fit_stack_to_content()
	var viewport_size := get_viewport_rect().size
	var desired: Vector2
	if anchor.get_center().y >= viewport_size.y * 0.78:
		# Relics live in the bottom tray, so their card belongs directly above them.
		desired = Vector2(anchor.position.x, anchor.position.y - _stack.size.y - HUD_GAP)
	elif anchor.get_center().x >= viewport_size.x * 0.72:
		# Adaptations live against the right edge; keep their card beside the slot.
		desired = Vector2(
			anchor.position.x - _stack.size.x - HUD_GAP,
			anchor.get_center().y - _stack.size.y * 0.5
		)
	else:
		desired = Vector2(anchor.end.x + HUD_GAP, anchor.position.y)
	_stack.position = desired
	_clamp_stack()
	_stack.visible = true


func show_reward_tooltips(source: String, anchor: Rect2) -> void:
	_tooltip_mode = TooltipMode.REWARD
	_source_rect = anchor
	_clear_stack()
	var keys := _referenced_keys(source)
	for key: String in keys:
		_add_tooltip_card(key, ENTRIES[key], _stack.get_child_count(), false)
	if keys.is_empty():
		_stack.visible = false
		return
	_stack.visible = false
	await get_tree().process_frame
	_fit_stack_to_content()
	_stack.position = Vector2(anchor.end.x + REWARD_GAP, anchor.position.y)
	_clamp_stack()
	_stack.visible = true


func source_exited() -> void:
	# Reward definitions stay pinned until another reward is hovered or the reward
	# screen closes. HUD dismissal is spatial and handled in _process.
	pass


func hide_tooltip() -> void:
	_tooltip_mode = TooltipMode.NONE
	_stack.visible = false
	_clear_stack()


func open_glossary() -> void:
	hide_tooltip()
	_active_letter = "ALL"
	_refresh_glossary()
	_glossary_overlay.visible = true


func close_glossary() -> void:
	_glossary_overlay.visible = false
	glossary_closed.emit()


func is_glossary_open() -> bool:
	return _glossary_overlay != null and _glossary_overlay.visible


func _add_tooltip_card(title: String, description: String, level: int, allow_links: bool) -> void:
	var mechanic_key := title.to_upper()
	var excluded_keys := _open_tooltip_keys()
	if not excluded_keys.has(mechanic_key):
		excluded_keys.append(mechanic_key)
	var card := _make_framed_panel(Vector2(300.0, 0.0))
	card.set_meta(&"mechanic_key", mechanic_key)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_stack.add_child(card)
	var content := _content_column(card, 16)
	var heading := Label.new()
	heading.text = title.to_upper()
	heading.add_theme_color_override("font_color", GOLD_BRIGHT)
	heading.add_theme_font_size_override("font_size", 15)
	content.add_child(heading)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.custom_minimum_size = Vector2(268.0, 0.0)
	body.add_theme_color_override("default_color", TEXT)
	body.add_theme_font_size_override("normal_font_size", 12)
	body.text = _linkify(description, excluded_keys) if allow_links else description
	if allow_links:
		body.meta_hover_started.connect(_on_keyword_hovered.bind(level))
	content.add_child(body)


func _on_keyword_hovered(meta: Variant, level: int) -> void:
	var key := String(meta).to_upper()
	if not ENTRIES.has(key) or _open_tooltip_keys().has(key):
		return
	while _stack.get_child_count() > level + 1:
		var child := _stack.get_child(_stack.get_child_count() - 1)
		_stack.remove_child(child)
		child.queue_free()
	_add_tooltip_card(key, ENTRIES[key], level + 1, true)
	_clamp_stack.call_deferred()


func _referenced_keys(source: String) -> Array[String]:
	var found: Array[String] = []
	var keys := ENTRIES.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for key: String in keys:
		if _contains_mechanic_term(source, key):
			# A longer phrase owns its words: Root Potency should not also produce
			# separate Root and Potency cards.
			var covered := false
			for existing in found:
				if (" %s " % existing).contains(" %s " % key):
					covered = true
					break
			if not covered:
				found.append(key)
	return found


func _contains_mechanic_term(source: String, key: String) -> bool:
	var lower := source.to_lower()
	var needle := key.to_lower()
	var start := lower.find(needle)
	while start >= 0:
		var before_ok := start == 0 or not _is_word_character(source.unicode_at(start - 1))
		var after := start + key.length()
		var after_ok := after == source.length() or not _is_word_character(source.unicode_at(after))
		if before_ok and after_ok:
			return true
		start = lower.find(needle, start + 1)
	return false


func _clamp_stack() -> void:
	var viewport_size := get_viewport_rect().size
	_stack.position.x = clampf(_stack.position.x, 12.0, maxf(12.0, viewport_size.x - _stack.size.x - 12.0))
	_stack.position.y = clampf(_stack.position.y, 12.0, maxf(12.0, viewport_size.y - _stack.size.y - 12.0))


func _fit_stack_to_content() -> void:
	# A free-standing Container does not shrink itself after a taller tooltip stack
	# is removed. Resetting it prevents a prior reward stack from displacing a later
	# one-card HUD tooltip to the top of the viewport.
	_stack.reset_size()
	_stack.size = _stack.get_combined_minimum_size()


func _open_tooltip_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	for child in _stack.get_children():
		var key := String(child.get_meta(&"mechanic_key", ""))
		if not key.is_empty():
			keys.append(key)
	return keys


func _linkify(source: String, excluded: PackedStringArray = PackedStringArray()) -> String:
	var keys := ENTRIES.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var lower := source.to_lower()
	var result := ""
	var cursor := 0
	while cursor < source.length():
		var matched := ""
		for key: String in keys:
			if excluded.has(key) or cursor + key.length() > source.length():
				continue
			if lower.substr(cursor, key.length()) != key.to_lower():
				continue
			var before_ok := cursor == 0 or not _is_word_character(source.unicode_at(cursor - 1))
			var after := cursor + key.length()
			var after_ok := after == source.length() or not _is_word_character(source.unicode_at(after))
			if before_ok and after_ok:
				matched = key
				break
		if matched.is_empty():
			result += source.substr(cursor, 1)
			cursor += 1
			continue
		var visible := source.substr(cursor, matched.length())
		result += "[url=%s][color=#f5d47b]%s[/color][/url]" % [matched, visible]
		cursor += matched.length()
	return result


func _is_word_character(codepoint: int) -> bool:
	return (
		codepoint >= 48 and codepoint <= 57
		or codepoint >= 65 and codepoint <= 90
		or codepoint >= 97 and codepoint <= 122
		or codepoint == 95
	)


func _build_glossary() -> void:
	_glossary_overlay = Control.new()
	_glossary_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glossary_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_glossary_overlay.visible = false
	add_child(_glossary_overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.003, 0.008, 0.011, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_glossary_overlay.add_child(dim)
	var panel := _make_framed_panel(Vector2(900.0, 620.0))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -450.0
	panel.offset_top = -310.0
	panel.offset_right = 450.0
	panel.offset_bottom = 310.0
	_glossary_overlay.add_child(panel)
	var root := _content_column(panel, 24)
	var header_row := HBoxContainer.new()
	root.add_child(header_row)
	var title := Label.new()
	title.text = "FIELD GLOSSARY"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", GOLD_BRIGHT)
	title.add_theme_font_size_override("font_size", 22)
	header_row.add_child(title)
	var close := Button.new()
	close.text = "CLOSE  [ESC]"
	close.custom_minimum_size = Vector2(140.0, 38.0)
	close.pressed.connect(close_glossary)
	header_row.add_child(close)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 5)
	root.add_child(tabs)
	var letters := PackedStringArray(["ALL"])
	for key: String in ENTRIES.keys():
		var letter := key.left(1)
		if not letters.has(letter):
			letters.append(letter)
	letters.sort()
	letters.erase("ALL")
	letters.insert(0, "ALL")
	for letter in letters:
		var tab := Button.new()
		tab.text = letter
		tab.custom_minimum_size = Vector2(44.0 if letter != "ALL" else 58.0, 34.0)
		tab.pressed.connect(_select_letter.bind(letter))
		tabs.add_child(tab)
		_letter_tabs[letter] = tab
	var divider := HSeparator.new()
	root.add_child(divider)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_glossary_entries = VBoxContainer.new()
	_glossary_entries.custom_minimum_size.x = 820.0
	_glossary_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_glossary_entries.add_theme_constant_override("separation", 10)
	scroll.add_child(_glossary_entries)
	_refresh_glossary()


func _select_letter(letter: String) -> void:
	_active_letter = letter
	_refresh_glossary()


func _refresh_glossary() -> void:
	for letter: String in _letter_tabs:
		var tab := _letter_tabs[letter] as Button
		tab.add_theme_color_override(
			"font_color", GOLD_BRIGHT if letter == _active_letter else TEXT
		)
	for child in _glossary_entries.get_children():
		_glossary_entries.remove_child(child)
		child.queue_free()
	var keys := ENTRIES.keys()
	keys.sort()
	for key: String in keys:
		if _active_letter != "ALL" and not key.begins_with(_active_letter):
			continue
		var row := VBoxContainer.new()
		row.custom_minimum_size.y = 54.0
		var heading := Label.new()
		heading.text = key
		heading.add_theme_color_override("font_color", GOLD_BRIGHT)
		heading.add_theme_font_size_override("font_size", 13)
		row.add_child(heading)
		var definition := Label.new()
		definition.text = ENTRIES[key]
		definition.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		definition.add_theme_color_override("font_color", TEXT)
		row.add_child(definition)
		_glossary_entries.add_child(row)


func _make_framed_panel(minimum: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	var background := StyleBoxFlat.new()
	background.bg_color = OLIVE
	background.content_margin_left = 12.0
	background.content_margin_top = 12.0
	background.content_margin_right = 12.0
	background.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", background)
	var border := NinePatchRect.new()
	border.texture = BORDER_TEXTURE
	border.set_patch_margin(SIDE_LEFT, BORDER_CORNER_SIZE)
	border.set_patch_margin(SIDE_TOP, BORDER_CORNER_SIZE)
	border.set_patch_margin(SIDE_RIGHT, BORDER_CORNER_SIZE)
	border.set_patch_margin(SIDE_BOTTOM, BORDER_CORNER_SIZE)
	border.draw_center = false
	border.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	border.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	border.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	border.modulate = GOLD
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(border)
	return panel


func _content_column(panel: PanelContainer, margin_size: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", margin_size)
	margin.add_theme_constant_override("margin_top", margin_size)
	margin.add_theme_constant_override("margin_right", margin_size)
	margin.add_theme_constant_override("margin_bottom", margin_size)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	return column


func _clear_stack() -> void:
	if _stack == null:
		return
	for child in _stack.get_children():
		_stack.remove_child(child)
		child.queue_free()
	_stack.reset_size()
