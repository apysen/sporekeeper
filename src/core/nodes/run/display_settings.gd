class_name DisplaySettings
extends Node

## The player-facing presentation options, in one place.
##
## The UI guide is explicit that these are not one global opacity slider. Friendly
## effects and enemy telegraphs are separate settings on purpose: a player who turns
## the spectacle down to see what is happening must not thereby turn down the thing
## that tells them they are about to be hit. Territory Detail is separate again, and
## is cosmetic only - the doc's rule is that the gameplay simulation stays identical
## at every level, so nothing here is allowed to reach a field parameter.
##
## Every option is an index into an authored list rather than a free value. Presets
## are what the doc asks for, they keep the settings panel to one control per row,
## and they make a setting something a player can describe to someone else.
##
## This node holds the choices and announces them. It never draws anything and never
## reads the run: consumers ask it what to draw, which is what keeps a new consumer
## from needing a new signal.

## Any option changed. Consumers re-read what they care about rather than each
## option carrying its own signal, because most consumers care about exactly one and
## re-reading is a field access.
signal settings_changed

enum OptionId {
	## Friendly projectile trails, decorative Bloom particles, and the rest of the
	## spectacle the run makes on its own behalf.
	FRIENDLY_EFFECTS,
	## How loudly enemy danger announces itself. Never lowered by the friendly
	## setting: the doc's rule is that danger stays readable regardless.
	ENEMY_TELEGRAPHS,
	## Cosmetic territory detail only - micro-splatter, decorative vegetation, fine
	## root strands, secondary ripples. The simulation is untouched at every level.
	TERRITORY_DETAIL,
	## Damage numbers: all of them, the ones that matter, or none.
	DAMAGE_NUMBERS,
	## How hard the Gardener is marked out against a full battlefield.
	PLAYER_HIGHLIGHT,
}

enum FriendlyEffects {
	FULL,
	THREE_QUARTERS,
	HALF,
	QUARTER,
}

enum EnemyTelegraphs {
	NORMAL,
	HIGH_CONTRAST,
}

enum TerritoryDetail {
	HIGH,
	MEDIUM,
	LOW,
}

enum DamageNumbers {
	FULL,
	IMPORTANT_ONLY,
	OFF,
}

enum PlayerHighlight {
	OFF,
	OUTLINE,
	STRONG,
}

@export_group("Defaults")
## Starting index for each option, in OptionId order. Authored rather than hard
## coded so a playtest can ship with a different default without a code change.
@export var default_choices := PackedInt32Array([0, 0, 0, 0, 1])

@export_group("Friendly Effects")
## Multiplier applied to friendly effect alpha and particle counts at each level.
@export var friendly_effect_scales := PackedFloat32Array([1.0, 0.75, 0.5, 0.25])

@export_group("Enemy Telegraphs")
## Alpha multiplier applied to enemy telegraphs at Normal and High Contrast. Above
## one at High Contrast on purpose: the option exists to make danger louder, and a
## setting that only ever removes things cannot do that.
@export var telegraph_alpha_scales := PackedFloat32Array([1.0, 1.45])
## Extra width, in pixels, added to a telegraph's outline at each level.
@export var telegraph_width_bonuses := PackedFloat32Array([0.0, 1.8])

@export_group("Territory Detail")
## Multiplier on the count of cosmetic territory decorations at High, Medium, Low.
@export var territory_detail_scales := PackedFloat32Array([1.0, 0.55, 0.0])

@export_group("Player Highlight")
## Width in pixels of the ring drawn around the player at Off, Outline, Strong.
@export var player_highlight_widths := PackedFloat32Array([0.0, 1.6, 3.2])
## Alpha of that ring at each level.
@export var player_highlight_alphas := PackedFloat32Array([0.0, 0.55, 0.95])

@export_group("UI Scale")
## The authored presets, as multipliers.
@export var ui_scale_presets := PackedFloat32Array([0.8, 0.9, 1.0, 1.1, 1.25])

var _choices := PackedInt32Array()


## Where the player's choices live between sessions. Presentation options and the two
## volumes are chosen once and expected to stay chosen: without this, opening settings
## from the home screen would change nothing about the run that follows it, because the
## run builds its own settings node and would start from the authored defaults again.
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "display"
const AUDIO_SECTION := "audio"


func _ready() -> void:
	reset_settings()
	load_settings()


func reset_settings() -> void:
	_choices = default_choices.duplicate()
	# A short default array would silently leave later options unset, and an option
	# that reads as index zero because nobody authored it is a setting nobody chose.
	while _choices.size() < OptionId.size():
		_choices.append(0)
	settings_changed.emit()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for option_id in range(OptionId.size()):
		var key := get_option_key(option_id)
		if not config.has_section_key(SETTINGS_SECTION, key):
			continue
		# Clamped on the way in: a config written by an older build can name a choice
		# this one no longer has, and an out-of-range index is worse than a default.
		_choices[option_id] = clampi(
			int(config.get_value(SETTINGS_SECTION, key, _choices[option_id])),
			0,
			maxi(0, get_choice_count(option_id) - 1)
		)
	settings_changed.emit()


func save_settings() -> void:
	var config := ConfigFile.new()
	# Loaded first so writing a display choice cannot discard the audio section, which
	# is written by whoever owns the volume sliders rather than from here.
	config.load(SETTINGS_PATH)
	for option_id in range(OptionId.size()):
		config.set_value(SETTINGS_SECTION, get_option_key(option_id), _choices[option_id])
	config.save(SETTINGS_PATH)


static func get_option_key(option_id: int) -> String:
	# The enum's own name, so a reordered enum cannot silently reassign saved choices
	# to different options the way a numeric key would.
	return OptionId.keys()[option_id] if option_id < OptionId.size() else "unknown"


static func load_volume(key: String, fallback: float) -> float:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return fallback
	return clampf(float(config.get_value(AUDIO_SECTION, key, fallback)), 0.0, 1.0)


static func save_volume(key: String, value: float) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(AUDIO_SECTION, key, clampf(value, 0.0, 1.0))
	config.save(SETTINGS_PATH)


func get_choice(option_id: int) -> int:
	if option_id < 0 or option_id >= _choices.size():
		return 0
	return _choices[option_id]


func set_choice(option_id: int, choice: int) -> void:
	if option_id < 0 or option_id >= _choices.size():
		return
	var count := get_choice_count(option_id)
	if count <= 0:
		return
	var clamped := clampi(choice, 0, count - 1)
	if _choices[option_id] == clamped:
		return
	_choices[option_id] = clamped
	settings_changed.emit()
	save_settings()


func cycle_choice(option_id: int, step: int = 1) -> void:
	# The panel is one button per row and pressing it advances the setting, so the
	# wrap belongs here rather than in the button: every caller wraps the same way.
	var count := get_choice_count(option_id)
	if count <= 0:
		return
	_choices[option_id] = posmod(get_choice(option_id) + step, count)
	settings_changed.emit()
	save_settings()


static func get_choice_count(option_id: int) -> int:
	match option_id:
		OptionId.FRIENDLY_EFFECTS:
			return FriendlyEffects.size()
		OptionId.ENEMY_TELEGRAPHS:
			return EnemyTelegraphs.size()
		OptionId.TERRITORY_DETAIL:
			return TerritoryDetail.size()
		OptionId.DAMAGE_NUMBERS:
			return DamageNumbers.size()
		OptionId.PLAYER_HIGHLIGHT:
			return PlayerHighlight.size()
	return 0


static func get_option_name(option_id: int) -> String:
	match option_id:
		OptionId.FRIENDLY_EFFECTS:
			return "FRIENDLY EFFECTS"
		OptionId.ENEMY_TELEGRAPHS:
			return "ENEMY TELEGRAPHS"
		OptionId.TERRITORY_DETAIL:
			return "TERRITORY DETAIL"
		OptionId.DAMAGE_NUMBERS:
			return "DAMAGE NUMBERS"
		OptionId.PLAYER_HIGHLIGHT:
			return "PLAYER HIGHLIGHT"
	return ""


static func get_choice_name(option_id: int, choice: int) -> String:
	match option_id:
		OptionId.FRIENDLY_EFFECTS:
			return ["100%", "75%", "50%", "25%"][clampi(choice, 0, 3)]
		OptionId.ENEMY_TELEGRAPHS:
			return ["NORMAL", "HIGH CONTRAST"][clampi(choice, 0, 1)]
		OptionId.TERRITORY_DETAIL:
			return ["HIGH", "MEDIUM", "LOW"][clampi(choice, 0, 2)]
		OptionId.DAMAGE_NUMBERS:
			return ["FULL", "IMPORTANT ONLY", "OFF"][clampi(choice, 0, 2)]
		OptionId.PLAYER_HIGHLIGHT:
			return ["OFF", "OUTLINE", "STRONG"][clampi(choice, 0, 2)]
	return ""


static func get_option_description(option_id: int) -> String:
	match option_id:
		OptionId.FRIENDLY_EFFECTS:
			return (
				"How much of your own spectacle is drawn: projectile trails, "
				+ "decorative Bloom particles, and other effects nothing depends on. "
				+ "It never touches enemy telegraphs."
			)
		OptionId.ENEMY_TELEGRAPHS:
			return (
				"How loudly incoming danger announces itself. High Contrast makes "
				+ "telegraphs brighter and thicker rather than merely leaving them "
				+ "alone while everything else quietens."
			)
		OptionId.TERRITORY_DETAIL:
			return (
				"Cosmetic detail on the ground: micro-splatter, fine root strands, "
				+ "secondary ripples. The simulation itself is identical at every "
				+ "level, so this cannot change what happens."
			)
		OptionId.DAMAGE_NUMBERS:
			return (
				"Important Only keeps the numbers that carry information - hits on "
				+ "elites and bosses, and large ability hits - and drops the stream "
				+ "of small ones."
			)
		OptionId.PLAYER_HIGHLIGHT:
			return (
				"How hard the Gardener is marked out. Worth raising once splatter, "
				+ "vines, and an orbiting ring are all on screen at once."
			)
	return ""


func get_friendly_effect_scale() -> float:
	return _scale_from(friendly_effect_scales, get_choice(OptionId.FRIENDLY_EFFECTS), 1.0)


func get_telegraph_alpha_scale() -> float:
	return _scale_from(telegraph_alpha_scales, get_choice(OptionId.ENEMY_TELEGRAPHS), 1.0)


func get_telegraph_width_bonus() -> float:
	return _scale_from(telegraph_width_bonuses, get_choice(OptionId.ENEMY_TELEGRAPHS), 0.0)


func get_territory_detail_scale() -> float:
	return _scale_from(territory_detail_scales, get_choice(OptionId.TERRITORY_DETAIL), 1.0)


func get_player_highlight_width() -> float:
	return _scale_from(player_highlight_widths, get_choice(OptionId.PLAYER_HIGHLIGHT), 0.0)


func get_player_highlight_alpha() -> float:
	return _scale_from(player_highlight_alphas, get_choice(OptionId.PLAYER_HIGHLIGHT), 0.0)


## What a settings row prints when the scene leaves its wording blank: the option's
## name beside its current value, and the name over its description.
##
## Both menus draw the same rows. Writing the composition out in each of them is how
## the home screen's tooltip came to be the bare description while the pause menu's
## named the option first - the same row, saying two different things depending on
## which screen you opened it from.
const ROW_TEXT_FALLBACK := "{name}   {value}"
const ROW_TOOLTIP_FALLBACK := "{name}

{detail}"


## The values a row's wording is rendered with, whichever menu is drawing it.
static func get_row_values(option_id: int, choice: int) -> Dictionary:
	return {
		"name": get_option_name(option_id),
		"value": get_choice_name(option_id, choice),
		"detail": get_option_description(option_id),
	}


func should_show_damage_number(is_important: bool) -> bool:
	# The one question every damage number asks. Keeping it here rather than at each
	# call site means a fourth level would be one change instead of several.
	match get_choice(OptionId.DAMAGE_NUMBERS):
		DamageNumbers.OFF:
			return false
		DamageNumbers.IMPORTANT_ONLY:
			return is_important
	return true


func _scale_from(values: PackedFloat32Array, index: int, fallback: float) -> float:
	# An authored array shorter than its option list is an authoring mistake rather
	# than a state the game should crash on, so a missing entry reads as the neutral
	# value and the setting simply does nothing until it is filled in.
	if index < 0 or index >= values.size():
		return fallback
	return values[index]
