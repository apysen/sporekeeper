class_name SettingsStore
extends RefCounted

## The file the player's choices live in between sessions.
##
## This is the only thing in the project that knows `settings.cfg` exists, what
## sections it has, or that it is a `ConfigFile` at all. Callers hand over names and
## values; how those are written is not their business, and a format change should
## not reach past this file.
##
## It deliberately knows nothing about *which* settings exist. Display choices are an
## enum on `DisplaySettings` and the volumes are named by the menus that own the
## sliders, so the meaning of a key, and any clamping it needs, stays with whoever
## understands it. This stores strings and numbers.

const PATH := "user://settings.cfg"
const DISPLAY_SECTION := "display"
const AUDIO_SECTION := "audio"
## Things the game has shown the player once and does not show again. Not a setting in
## the sense the other two sections are -- nobody chose it -- but it belongs in the same
## file for the same reason: it has to survive the session that wrote it.
const SEEN_SECTION := "seen"


## Every display choice on file, keyed by name. Empty when there is no file yet,
## which is the first run and not an error.
static func read_display() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return {}
	var stored := {}
	for key in config.get_section_keys(DISPLAY_SECTION):
		stored[key] = config.get_value(DISPLAY_SECTION, key)
	return stored


## Writes every display choice at once.
##
## The file is read back first so that writing a display choice cannot discard the
## audio section, which is written by whoever owns the volume sliders rather than
## from here.
static func write_display(values: Dictionary) -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	for key in values:
		config.set_value(DISPLAY_SECTION, key, values[key])
	config.save(PATH)


static func read_volume(key: String, fallback: float) -> float:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return fallback
	return clampf(float(config.get_value(AUDIO_SECTION, key, fallback)), 0.0, 1.0)


static func write_volume(key: String, value: float) -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value(AUDIO_SECTION, key, clampf(value, 0.0, 1.0))
	config.save(PATH)


static func has_seen(key: String) -> bool:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return false
	return bool(config.get_value(SEEN_SECTION, key, false))


static func mark_seen(key: String) -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value(SEEN_SECTION, key, true)
	config.save(PATH)


static func forget_seen(key: String) -> void:
	## Shows a one-off note again. Nothing in the game calls this -- it is for a probe
	## that has to photograph a note it can only be shown once, and for whoever needs to
	## see the thing again without deleting the whole settings file.
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	if not config.has_section_key(SEEN_SECTION, key):
		return
	config.erase_section_key(SEEN_SECTION, key)
	config.save(PATH)
