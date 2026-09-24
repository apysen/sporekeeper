class_name MechanicsHelp
extends Control

signal glossary_closed
## A one-off notice was dismissed. The run listens so it can start the simulation again.
signal notice_closed

const BORDER_TEXTURE := preload("res://assets/ui/kenney/panel-border-008.png")
## The run's own button art. The glossary builds its buttons in code rather than in a
## scene, which is the only reason they were ever stock grey: nothing was authored for
## them to inherit from.
const BUTTON_STYLE := preload("res://assets/ui/button_style.tres")
const BUTTON_HOVER_STYLE := preload("res://assets/ui/button_hover_style.tres")
const BUTTON_DISABLED_STYLE := preload("res://assets/ui/button_disabled_style.tres")
const GOLD := Color(0.769, 0.604, 0.314, 1.0)
const GOLD_BRIGHT := Color(0.96, 0.83, 0.48, 1.0)
const NOTICE_DIM := Color(0.003, 0.008, 0.011, 0.86)
## Air left around a highlighted control, so the frame sits off the thing rather than
## on it.
const NOTICE_HIGHLIGHT_PADDING := 6.0
## How wide a notice is. Its height is whatever its words need.
const NOTICE_WIDTH := 660.0
const NOTICE_BUTTON_WIDTH := 200.0
const NOTICE_BUTTON_GAP := 14.0
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
	"AFTERGROWTH": "A temporary shield Bloom leaves on Green. Hostile territory damage eats through Aftergrowth before it touches the Green underneath.",
	"ACT": "One quarter of a Campaign. Germination establishes your build, Encroachment brings the first specialists and the first Canker risk, Infestation completes the build against coordinated attacks, and Blight tests the finished thing. An act decides which encounters the garden is allowed to send, so a wave that is going badly still sends problems from its own act.",
	"BLIGHT": "How much harder the garden has become because you kept Provoking it. Each rewarded Provocation raises it one level, it never falls, and the final encounter inherits whatever you built up. Most of it is the Threat Director's budget: at high Blight the garden can afford its expensive attacks far more often, while an individual enemy is only slightly tougher.",
	"GROWTH": "A small universal stat - damage, attack speed, movement, reach, health, armour or regeneration - paid out for surviving a wave you called in early. Each one is capped, they add rather than multiply, and the whole set a run can collect is worth less than one Adaptation.",
	"PROVOCATION": "Calling the next wave in early. Everything already on the field stays there, the wave's quiet ending is skipped, the next one arrives with a Surge at its front, and your Blight rises permanently. Calling it earlier buys more danger, not more reward.",
	"SURGE": "The immediate cost of Provoking. The earlier you call a wave, the more of its pressure arrives at the very start of it instead of being spread across the minute. Temporary, unlike Blight.",
	"THREAT": "What an attack costs the garden to send. Every wave has a budget and a list of attacks it may buy, so a late wave is dangerous because it can afford Siege Pushes and elite spearheads - not because it puts more bodies on the board.",
	"AMPLIFICATION": "The boost Root Potency gives another plant mechanic. The upgrade shows the affected value whenever amplification applies.",
	"BLOOM": "A plant event that bursts outward, damages enemies, and reclaims territory. Bloom upgrades change its force, frequency, and aftermath.",
	"CANKER": "A hostile structure that grows where Rot has been held long enough to settle. Damage cannot remove one - reinforcements keep arriving through it until you take the ground back.",
	"CUTTINGS": "What you get back for Pruning your own Green. Cuttings feed Pruning attacks and recovery effects.",
	"ENSNARE": "A Bramble condition that stops an enemy moving, though it can still attack. Grasping Thorns applies it, and a snared enemy is briefly immune afterwards.",
	"ENTANGLEMENT": "A buildup on enemies standing on Green, and the more of it they carry the slower they move. Filling the bar Ensnares them if you have Bramble.",
	"GERMINATION": "The moment a Seed opens and creates Green. Germination speed sets how long a planted Seed takes to become territory.",
	"GREEN": "Territory the ecosystem controls. Green feeds the ecosystem's growth and powers many plant-path effects.",
	"MASS": "The amount of living material added to the field. More Mass creates more Green when growth effects resolve.",
	"MATURE": "Green that has aged and settled, producing more value and powering the Root Network. The golden Root Network light only appears under Grandma while she stands on it.",
	"OVERGROW": "An active burst that spends the growth you have banked. It drives Mass and Pressure into the frontier you choose and hardens the Green there.",
	"PRESSURE": "The outward force of Green against hostile territory. More Pressure helps reclaim and expand the field.",
	"PRUNING": "A plant path that cuts your own Green on purpose, trading it for Cuttings, attacks, and fresh regrowth. The cut lands where you are standing, so a ring held in one place eats its own footing and tears loose — keep walking onto fresh Green to hold it.",
	"REPULSION": "A Bramble effect that pushes enemies away from defended Green and its frontier.",
	"ROOT NETWORK": "The web Mature Green forms, carrying Root Potency into the plant mechanics that can use it. While you own Root, a slow golden light breathes under Grandma and under each planted Thistle standing on Mature Green, brighter where the Network runs deeper. Effects that gain a whole extra unit from Root Potency, such as one more Fruit or thorn, only gain it while that light is lit.",
	"ROOT POTENCY": "The strength of the Root Network. It amplifies the effects that work from Mature Green.",
	"SEED": "A planted growth source that creates Green when it germinates.",
	"SUPPRESSION": "A temporary Bloom condition that cuts how much territory damage the affected enemies deal.",
	"TERRITORY": "The living field that Green, hostile growth, and neutral ground fight over. How much of it you hold is one of the things the run is scored on.",
	"THISTLE": "A plant path that grows a single turret on Green, never more than one. Walk Grandma through it and the Thistle rides along firing from her side, then takes root where she is standing, withering if it comes loose off Green.",
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


## Strips the title off the front of a slot's tooltip text, so a card does not print
## its own heading twice. Static because every row that owns slots needs it and none
## of them should own a copy.
static func tooltip_body(value: String, title: String) -> String:
	var body := value.strip_edges()
	if body.begins_with(title):
		body = body.trim_prefix(title).strip_edges()
	return body


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


var _notice_overlay: Control
var _notice_pages: Array = []
var _notice_page := 0


func show_notices(pages: Array) -> void:
	## A short sequence of one-off notices, advanced by the button on each.
	##
	## Pages rather than one long panel because the two things a new Campaign has to
	## explain -- the button that sets the difficulty, and the cards that hand out
	## optional rules -- are unrelated, and a player reading about the second is no
	## longer looking at the first.
	if _notice_overlay != null or pages.is_empty():
		return
	_notice_pages = pages
	_notice_page = 0
	_show_notice_page()


func _show_notice_page() -> void:
	var page: Dictionary = _notice_pages[_notice_page]
	var last := _notice_page >= _notice_pages.size() - 1
	show_notice(
		String(page.get("heading", "")),
		String(page.get("body", "")),
		String(page.get("button", "GOT IT" if last else "NEXT")),
		page.get("highlight", Rect2())
	)


func _advance_notice() -> void:
	if _notice_page >= _notice_pages.size() - 1:
		_notice_pages = []
		close_notice()
		return
	_notice_page += 1
	_close_notice_overlay()
	_show_notice_page()


func show_notice(
	heading_text: String,
	body_text: String,
	dismiss_text: String,
	highlight := Rect2()
) -> void:
	## A single panel in the middle of the screen with one button on it.
	##
	## Built on demand rather than authored, because it is shown once per player and a
	## scene node for it would sit in every run forever. It borrows the glossary's frame
	## and column so a notice looks like the rest of the interface without a second set
	## of styling to keep in step.
	if _notice_overlay != null:
		return
	_notice_overlay = Control.new()
	_notice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_notice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_notice_overlay)
	_add_notice_dim(highlight)
	# Centred by a container rather than by four offsets, so the panel is exactly as
	# tall as its own text. A fixed height left the short page floating in a box with
	# half of it empty, and would have clipped a longer one.
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_overlay.add_child(centre)
	var panel := _make_framed_panel(Vector2(NOTICE_WIDTH, 0.0))
	centre.add_child(panel)
	var column := _content_column(panel, 26)
	var heading := Label.new()
	heading.text = heading_text
	heading.add_theme_color_override("font_color", GOLD_BRIGHT)
	heading.add_theme_font_size_override("font_size", 22)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var body := RichTextLabel.new()
	body.bbcode_enabled = false
	body.fit_content = true
	body.scroll_active = false
	body.text = body_text
	body.custom_minimum_size.x = NOTICE_WIDTH - 52.0
	body.add_theme_font_size_override("normal_font_size", 13)
	column.add_child(body)
	# Air between the last line and the button. The column's own separation is sized for
	# lines of a paragraph, and a button sitting that close to a sentence reads as part
	# of it.
	var gap := Control.new()
	gap.custom_minimum_size.y = NOTICE_BUTTON_GAP
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	# Centred at a button's width rather than stretched to the panel. A control as wide
	# as the text it follows stops looking like something you press.
	var button_row := CenterContainer.new()
	column.add_child(button_row)
	var dismiss := Button.new()
	dismiss.text = dismiss_text
	dismiss.custom_minimum_size = Vector2(NOTICE_BUTTON_WIDTH, 0.0)
	_style_glossary_button(dismiss)
	dismiss.pressed.connect(_advance_notice)
	button_row.add_child(dismiss)


func _add_notice_dim(highlight: Rect2) -> void:
	## The dim, with a hole in it.
	##
	## A note that points at a button while covering the button is asking the player to
	## take its word for where things are. Four bands around the rect rather than a
	## shader: the hole is always a control's own rectangle, the bands are exact, and
	## nothing here needs to survive a resize because the notice does not outlive one.
	##
	## Input is still blocked everywhere, including over the hole. The player is meant
	## to see the thing, not press it while being told what it does.
	var full := get_viewport_rect()
	if highlight.size.x <= 0.0 or highlight.size.y <= 0.0:
		_add_dim_band(full)
		return
	var hole := highlight.grow(NOTICE_HIGHLIGHT_PADDING).intersection(full)
	_add_dim_band(Rect2(full.position, Vector2(full.size.x, hole.position.y - full.position.y)))
	_add_dim_band(Rect2(
		Vector2(full.position.x, hole.end.y),
		Vector2(full.size.x, full.end.y - hole.end.y)
	))
	_add_dim_band(Rect2(
		Vector2(full.position.x, hole.position.y),
		Vector2(hole.position.x - full.position.x, hole.size.y)
	))
	_add_dim_band(Rect2(
		Vector2(hole.end.x, hole.position.y),
		Vector2(full.end.x - hole.end.x, hole.size.y)
	))
	# A blocker over the hole, invisible, so the thing being pointed at cannot be used
	# while it is being explained.
	var blocker := Control.new()
	blocker.position = hole.position
	blocker.size = hole.size
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_notice_overlay.add_child(blocker)
	# And a frame around it, because an undimmed rectangle in a dimmed screen reads as
	# a gap until something says it is the subject.
	var outline := ReferenceRect.new()
	outline.position = hole.position
	outline.size = hole.size
	outline.border_color = GOLD_BRIGHT
	outline.border_width = 2.0
	outline.editor_only = false
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_overlay.add_child(outline)


func _add_dim_band(band: Rect2) -> void:
	if band.size.x <= 0.0 or band.size.y <= 0.0:
		return
	var dim := ColorRect.new()
	dim.position = band.position
	dim.size = band.size
	dim.color = NOTICE_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_notice_overlay.add_child(dim)


func is_notice_open() -> bool:
	return _notice_overlay != null


func close_notice() -> void:
	if _notice_overlay == null:
		return
	_close_notice_overlay()
	_notice_pages = []
	notice_closed.emit()


func _close_notice_overlay() -> void:
	if _notice_overlay == null:
		return
	_notice_overlay.queue_free()
	_notice_overlay = null


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
	_style_glossary_button(close)
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
		_style_glossary_button(tab)
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
	# After the page is built, so it reaches every button on it at once. The overlay is
	# already in the tree, which is what lets each border run its own `_ready` and
	# capture the style it is replacing.
	NinePatchButtonBorder.install_under(_glossary_overlay)
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


## Dresses a button the glossary built itself in the same art every other button in
## the run wears. `NinePatchButtonBorder.install_under` is what actually draws it: a
## StyleBoxTexture assigned straight to a Button is stretched, corners and all, which
## is the whole reason that class exists.
func _style_glossary_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", BUTTON_STYLE)
	button.add_theme_stylebox_override("hover", BUTTON_HOVER_STYLE)
	button.add_theme_stylebox_override("pressed", BUTTON_HOVER_STYLE)
	button.add_theme_stylebox_override("disabled", BUTTON_DISABLED_STYLE)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", GOLD_BRIGHT)


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
