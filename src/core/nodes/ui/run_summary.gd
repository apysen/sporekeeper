class_name RunSummary
extends Control

## The result screen's breakdown: what each part of the build did over the run.
##
## Vampire Survivors ends a run on a table of its weapons -- damage, time held, DPS --
## and that table is where a player learns what their build actually was, as opposed
## to what they thought it was. This is the same table for a garden: a row per
## contributor with its damage, its share of the total drawn as a bar, its DPS, its
## kills, and the Green it grew, and under it a line of tiles for the defensive side
## of the run, which a damage table on its own would leave out entirely.
##
## Drawn rather than built from Labels, the way the Trial card is: it is one object,
## laid out once, and a grid of forty Labels would be forty nodes to keep aligned.

const LABEL_FONT: Font = preload("res://assets/fonts/beholden/Beholden-Medium.ttf")
const HEADING_FONT_SIZE := 9
const ROW_FONT_SIZE := 12
const TILE_CAPTION_FONT_SIZE := 9
const TILE_VALUE_FONT_SIZE := 16
const ROW_HEIGHT := 21.0
const HEADING_HEIGHT := 18.0
const TILE_HEIGHT := 46.0
const TILE_GAP := 8.0
const SECTION_GAP := 12.0
const TEXT := Color(0.91, 0.875, 0.784, 1.0)
const MUTED := Color(0.663, 0.69, 0.608, 1.0)
const RULE := Color(0.663, 0.69, 0.608, 0.25)
const TILE_BACKING := Color(0.0, 0.0, 0.0, 0.22)
const BACKING := Color(0.106, 0.114, 0.094, 0.94)
const NEUTRAL_ACCENT := Color("d4a94f")
const TOTAL_ACCENT := Color(0.698, 0.796, 0.51, 1.0)
## Column right edges as a share of the width, except the name and bar, which are
## left edges. Shares rather than pixels so the table fits whatever the panel is.
const COLUMN_NAME := 0.0
const COLUMN_DAMAGE_RIGHT := 0.34
const COLUMN_BAR_LEFT := 0.37
const COLUMN_BAR_RIGHT := 0.60
const COLUMN_DPS_RIGHT := 0.72
const COLUMN_KILLS_RIGHT := 0.84
const COLUMN_GREEN_RIGHT := 1.0
## Grandma is 24 px across, which is about 60 cm of person: distances are shown in
## metres at that scale so a shove total reads as a distance rather than a pixel count.
const PIXELS_PER_METRE := 40.0
## Width of the name column on a path card.
const CARD_NAME_WIDTH := 96.0

var _stats: RunStats
## How many cells a full arena holds, which is what turns the field's control into a
## share of the arena a player can read.
var _claimable_cells := 1
var _ranked: Array[int] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_stats(stats: RunStats, claimable_cells: int) -> void:
	_stats = stats
	_claimable_cells = maxi(1, claimable_cells)
	_ranked = stats.get_ranked_sources() if stats != null else []
	queue_redraw()


## How tall the table needs to be for the rows it has, so the panel can be sized to it.
func get_required_height() -> float:
	var cards := _path_cards().size()
	return (
		HEADING_HEIGHT
		+ ROW_HEIGHT * float(maxi(_ranked.size(), 1) + 1)
		+ SECTION_GAP
		+ float(cards) * (TILE_HEIGHT + TILE_GAP)
		+ TILE_HEIGHT
	)


func _draw() -> void:
	if _stats == null:
		return
	var width := size.x
	var cursor := 0.0
	# The result panel is translucent, which suits three lines of text and not a table:
	# the arena behind it reads through the rows. The table brings its own backing.
	draw_rect(Rect2(-8.0, -6.0, width + 16.0, size.y + 12.0), BACKING, true)
	_draw_headings(width, cursor)
	cursor += HEADING_HEIGHT
	var top_damage := 0.0
	for source in _ranked:
		top_damage = maxf(top_damage, _stats.damage[source])
	var total_damage := _stats.get_total_damage()
	if _ranked.is_empty():
		_draw_text("Nothing in the garden dealt damage or grew Green.", 0.0, cursor, width, MUTED, ROW_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
		cursor += ROW_HEIGHT
	for index in range(_ranked.size()):
		var source := _ranked[index]
		if index % 2 == 1:
			draw_rect(Rect2(0.0, cursor, width, ROW_HEIGHT), Color(1.0, 1.0, 1.0, 0.03), true)
		_draw_row(
			source,
			cursor,
			width,
			_stats.damage[source] / top_damage if top_damage > 0.0 else 0.0,
			_stats.damage[source] / total_damage if total_damage > 0.0 else 0.0
		)
		cursor += ROW_HEIGHT
	draw_line(Vector2(0.0, cursor + 1.0), Vector2(width, cursor + 1.0), RULE, 1.0)
	_draw_total_row(cursor + 2.0, width)
	cursor += ROW_HEIGHT + SECTION_GAP
	for card in _path_cards():
		_draw_card(card, cursor, width)
		cursor += TILE_HEIGHT + TILE_GAP
	_draw_tiles(cursor, width)


## Bramble and Root hold what the rest of the build does rather than dealing damage or
## growing Green of their own, so a damage table undersells them. Each gets a line of
## its own numbers under the table, shown only when the path did something this run.
func _path_cards() -> Array:
	var cards := []
	if _stats == null:
		return cards
	if (
		_stats.bramble_shove_pixels > 0.0
		or _stats.bramble_movement_denied > 0.0
		or _stats.bramble_green_held > 0.0
	):
		cards.append([
			"Bramble",
			_source_color(RunStats.Source.BRAMBLE),
			[
				["GRAZERS SHOVED", "%sm" % _format_amount(_stats.bramble_shove_pixels / PIXELS_PER_METRE)],
				["ENSNARES", str(_stats.bramble_ensnares)],
				["ENEMY MOVEMENT DENIED", _format_duration(_stats.bramble_movement_denied)],
				["GREEN HELD BY THE HEDGE", _format_green(_stats.bramble_green_held)],
			],
		])
	if _stats.root_green_held > 0.0 or _stats.root_green_regrown > 0.0:
		cards.append([
			"Root",
			_source_color(RunStats.Source.ROOT),
			[
				["GREEN HELD BY MATURE STRENGTH", _format_green(_stats.root_green_held)],
				["GREEN REGENERATED", _format_green(_stats.root_green_regrown)],
				["PEAK MATURE GROUND", "%.1f%%" % _stats.peak_mature_percent],
			],
		])
	return cards


func _draw_card(card: Array, top: float, width: float) -> void:
	var accent: Color = card[1]
	var entries: Array = card[2]
	draw_rect(Rect2(0.0, top, width, TILE_HEIGHT), TILE_BACKING, true)
	draw_rect(Rect2(0.0, top, 4.0, TILE_HEIGHT), accent, true)
	_draw_text(
		String(card[0]).to_upper(), 12.0, top + (TILE_HEIGHT - ROW_HEIGHT) * 0.5,
		CARD_NAME_WIDTH, accent, ROW_FONT_SIZE
	)
	var left := CARD_NAME_WIDTH
	var cell_width := (width - left) / float(entries.size())
	for index in range(entries.size()):
		var cell_left := left + float(index) * cell_width
		if index > 0:
			draw_line(
				Vector2(cell_left, top + 8.0),
				Vector2(cell_left, top + TILE_HEIGHT - 8.0),
				RULE,
				1.0
			)
		_draw_text(entries[index][0], cell_left, top + 6.0, cell_width, MUTED, TILE_CAPTION_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_text(entries[index][1], cell_left, top + 20.0, cell_width, TEXT, TILE_VALUE_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)


## Enemy-seconds as a clock: 41s, 3m 12s, 1h 04m.
static func _format_duration(seconds: float) -> String:
	var whole := roundi(seconds)
	if whole < 60:
		return "%ds" % whole
	if whole < 3600:
		return "%dm %02ds" % [whole / 60, whole % 60]
	return "%dh %02dm" % [whole / 3600, (whole % 3600) / 60]


func _draw_headings(width: float, top: float) -> void:
	_draw_text("CONTRIBUTOR", COLUMN_NAME * width, top, 0.3 * width, MUTED, HEADING_FONT_SIZE)
	_draw_right("DAMAGE", COLUMN_DAMAGE_RIGHT * width, top, MUTED, HEADING_FONT_SIZE)
	_draw_text("SHARE", COLUMN_BAR_LEFT * width, top, 0.2 * width, MUTED, HEADING_FONT_SIZE)
	_draw_right("DPS", COLUMN_DPS_RIGHT * width, top, MUTED, HEADING_FONT_SIZE)
	_draw_right("KILLS", COLUMN_KILLS_RIGHT * width, top, MUTED, HEADING_FONT_SIZE)
	_draw_right("GREEN GROWN", COLUMN_GREEN_RIGHT * width, top, MUTED, HEADING_FONT_SIZE)
	draw_line(
		Vector2(0.0, top + HEADING_HEIGHT - 3.0),
		Vector2(width, top + HEADING_HEIGHT - 3.0),
		RULE,
		1.0
	)


func _draw_row(source: int, top: float, width: float, bar_fraction: float, share: float) -> void:
	var accent := _source_color(source)
	# A swatch in the source's own colour, so the row reads as the same thing the
	# Adaptation panel showed all run.
	draw_rect(Rect2(0.0, top + 6.0, 4.0, ROW_HEIGHT - 12.0), accent, true)
	_draw_text(RunStats.source_name(source), 10.0, top, 0.3 * width, TEXT, ROW_FONT_SIZE)
	_draw_right(
		_format_amount(_stats.damage[source]) if _stats.damage[source] > 0.0 else "-",
		COLUMN_DAMAGE_RIGHT * width,
		top,
		TEXT,
		ROW_FONT_SIZE
	)
	var bar_left := COLUMN_BAR_LEFT * width
	var bar_width := (COLUMN_BAR_RIGHT - COLUMN_BAR_LEFT) * width - 34.0
	var bar := Rect2(bar_left, top + 6.0, bar_width, ROW_HEIGHT - 12.0)
	draw_rect(bar, Color(accent.r, accent.g, accent.b, 0.15), true)
	if bar_fraction > 0.0:
		draw_rect(
			Rect2(bar.position, Vector2(bar.size.x * clampf(bar_fraction, 0.0, 1.0), bar.size.y)),
			accent,
			true
		)
	_draw_right(
		"%d%%" % roundi(share * 100.0) if share > 0.0 else "-",
		COLUMN_BAR_RIGHT * width,
		top,
		MUTED,
		ROW_FONT_SIZE - 2
	)
	var dps := _stats.get_dps(source)
	_draw_right(_format_amount(dps) if dps > 0.0 else "-", COLUMN_DPS_RIGHT * width, top, TEXT, ROW_FONT_SIZE)
	var kills := _stats.kills[source]
	_draw_right(str(kills) if kills > 0 else "-", COLUMN_KILLS_RIGHT * width, top, TEXT, ROW_FONT_SIZE)
	_draw_right(_format_green(_stats.green[source]), COLUMN_GREEN_RIGHT * width, top, TEXT, ROW_FONT_SIZE)


func _draw_total_row(top: float, width: float) -> void:
	_draw_text("TOTAL", 10.0, top, 0.3 * width, TOTAL_ACCENT, ROW_FONT_SIZE)
	_draw_right(_format_amount(_stats.get_total_damage()), COLUMN_DAMAGE_RIGHT * width, top, TOTAL_ACCENT, ROW_FONT_SIZE)
	var run_dps := _stats.get_total_damage() / maxf(_stats.now, 1.0)
	_draw_right(_format_amount(run_dps), COLUMN_DPS_RIGHT * width, top, TOTAL_ACCENT, ROW_FONT_SIZE)
	_draw_right(str(_stats.get_total_kills()), COLUMN_KILLS_RIGHT * width, top, TOTAL_ACCENT, ROW_FONT_SIZE)
	var green := 0.0
	for value in _stats.green:
		green += value
	_draw_right(_format_green(green), COLUMN_GREEN_RIGHT * width, top, TOTAL_ACCENT, ROW_FONT_SIZE)


## The defensive side of the run, which no damage column shows: what reached Grandma,
## what was kept off her, what she got back, and what the shield held for the ground.
func _draw_tiles(top: float, width: float) -> void:
	var tiles := [
		["DAMAGE TAKEN", _format_amount(_stats.damage_taken)],
		["KEPT OFF BY CANOPY & BARK", _format_amount(_stats.damage_prevented)],
		["HEALED", _format_amount(_stats.healing)],
		["GREEN SHIELDED BY AFTERGROWTH", _format_green(_stats.green_shielded)],
	]
	var tile_width := (width - TILE_GAP * float(tiles.size() - 1)) / float(tiles.size())
	for index in range(tiles.size()):
		var left := float(index) * (tile_width + TILE_GAP)
		draw_rect(Rect2(left, top, tile_width, TILE_HEIGHT), TILE_BACKING, true)
		_draw_text(tiles[index][0], left, top + 6.0, tile_width, MUTED, TILE_CAPTION_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_text(tiles[index][1], left, top + 20.0, tile_width, TEXT, TILE_VALUE_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)


func _source_color(source: int) -> Color:
	match source:
		RunStats.Source.SPORE:
			return AdaptationTree.get_path_hud_color(Progression.PathId.SPORE)
		RunStats.Source.BLOOM:
			return AdaptationTree.get_path_hud_color(Progression.PathId.BLOOM)
		RunStats.Source.BRAMBLE, RunStats.Source.MAN_EATER:
			return AdaptationTree.get_path_hud_color(Progression.PathId.BRAMBLE)
		RunStats.Source.ROOT:
			return AdaptationTree.get_path_hud_color(Progression.PathId.ROOT)
		RunStats.Source.PRUNING:
			return AdaptationTree.get_path_hud_color(Progression.PathId.PRUNING)
		RunStats.Source.THISTLE:
			return AdaptationTree.get_path_hud_color(Progression.PathId.THISTLE)
		RunStats.Source.VINE:
			return AdaptationTree.get_path_hud_color(Progression.PathId.VINE)
		RunStats.Source.FRUIT:
			return AdaptationTree.get_path_hud_color(Progression.PathId.FRUIT)
		RunStats.Source.SEEDS:
			return Color("8fb35a")
		RunStats.Source.OVERGROW:
			return TOTAL_ACCENT
	return NEUTRAL_ACCENT


## Whole numbers under ten thousand, then 12.3k, then 1.23M: the column has to stay
## narrow and a late-run total runs to seven digits.
static func _format_amount(value: float) -> String:
	if value >= 1000000.0:
		return "%.2fM" % (value / 1000000.0)
	if value >= 10000.0:
		return "%.1fk" % (value / 1000.0)
	return str(roundi(value))


## Control as a share of the arena. Cumulative, so it can pass 100%.
func _format_green(control: float) -> String:
	if control <= 0.0:
		return "-"
	var percent := control / float(_claimable_cells) * 100.0
	if percent < 0.1:
		return "<0.1%"
	return "%.1f%%" % percent


func _draw_text(
	text: String,
	left: float,
	top: float,
	width: float,
	color: Color,
	font_size: int,
	alignment := HORIZONTAL_ALIGNMENT_LEFT
) -> void:
	var line_height := ROW_HEIGHT if font_size >= ROW_FONT_SIZE else LABEL_FONT.get_height(font_size)
	draw_string(
		LABEL_FONT,
		Vector2(
			left,
			top + (line_height - LABEL_FONT.get_height(font_size)) * 0.5
			+ LABEL_FONT.get_ascent(font_size)
		),
		text,
		alignment,
		width,
		font_size,
		color
	)


func _draw_right(text: String, right: float, top: float, color: Color, font_size: int) -> void:
	var text_width := LABEL_FONT.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	var line_height := ROW_HEIGHT if font_size >= ROW_FONT_SIZE - 2 else LABEL_FONT.get_height(font_size)
	draw_string(
		LABEL_FONT,
		Vector2(
			right - text_width,
			top + (line_height - LABEL_FONT.get_height(font_size)) * 0.5
			+ LABEL_FONT.get_ascent(font_size)
		),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)
