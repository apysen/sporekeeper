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
