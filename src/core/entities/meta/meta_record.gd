class_name MetaRecord
extends RefCounted

## What the player keeps when a run ends.
##
## The whole of meta-progression today is a record: how many runs have finished, how
## many were held, and how far the best one got in each mode. Nothing in a run reads
## it - it unlocks nothing and grants nothing - because inventing unlocks to justify
## the file would be building a feature nobody asked for. It exists so the run that
## just ended is not forgotten, and so whoever builds unlocks has somewhere to put them.
##
## Serializable state, so it is a plain holder with no node and no scene: the dictionary
## it converts to is what `SaveStore` writes, and nothing else knows its shape.

const MODE_COUNT := 2
## Finished runs kept in the history, newest first. Each carries its whole contribution
## table, so the list is capped rather than left to grow with every run ever played.
const HISTORY_LIMIT := 40

var runs_finished := 0
var victories := 0
## Indexed by `RunMode.Id`, so a Quick record and a Campaign record never mix - the
## two modes do not face the same waves and a wave number means a different thing in
## each.
var runs_by_mode := PackedInt32Array([0, 0])
var victories_by_mode := PackedInt32Array([0, 0])
var best_wave_by_mode := PackedInt32Array([0, 0])
var best_biomass_by_mode := PackedFloat32Array([0.0, 0.0])
## When the last run ended, as Unix seconds. Zero when none has.
var last_finished_unix_time := 0
## One dictionary per finished run, newest first, for the Past Runs page. Shaped by
## the run that wrote it -- mode, outcome, wave, time, level, Green, the build and its
## `RunStats` -- and read back only by that page, so a field it does not know is kept
## and a field it misses is shown as absent.
var history: Array = []


## Puts a finished run at the top of the history and drops the oldest past the cap.
func add_history(entry: Dictionary) -> void:
	history.push_front(entry)
	if history.size() > HISTORY_LIMIT:
		history.resize(HISTORY_LIMIT)


## Folds one finished run in. Returns nothing: the record is the accumulation, and a
## caller that wants to know what changed should read the fields it cares about.
func record_run(mode: int, victory: bool, wave_number: int, biomass_earned: float) -> void:
	var slot := clampi(mode, 0, MODE_COUNT - 1)
	runs_finished += 1
	runs_by_mode[slot] += 1
	if victory:
		victories += 1
		victories_by_mode[slot] += 1
	best_wave_by_mode[slot] = maxi(best_wave_by_mode[slot], wave_number)
	best_biomass_by_mode[slot] = maxf(best_biomass_by_mode[slot], biomass_earned)
	last_finished_unix_time = int(Time.get_unix_time_from_system())


func to_dictionary() -> Dictionary:
	return {
		"runs_finished": runs_finished,
		"victories": victories,
		"runs_by_mode": runs_by_mode,
		"victories_by_mode": victories_by_mode,
		"best_wave_by_mode": best_wave_by_mode,
		"best_biomass_by_mode": best_biomass_by_mode,
		"last_finished_unix_time": last_finished_unix_time,
		"history": history,
	}


## A record from a dictionary, defaulting every field that is missing or the wrong
## type. An empty dictionary is the first launch and returns a fresh record, which is
## why this never fails: there is no reading of this file that should stop the game.
static func from_dictionary(data: Dictionary) -> MetaRecord:
	var record := MetaRecord.new()
	record.runs_finished = int(data.get("runs_finished", 0))
	record.victories = int(data.get("victories", 0))
	record.runs_by_mode = _int_field(data, "runs_by_mode")
	record.victories_by_mode = _int_field(data, "victories_by_mode")
	record.best_wave_by_mode = _int_field(data, "best_wave_by_mode")
	record.best_biomass_by_mode = _float_field(data, "best_biomass_by_mode")
	record.last_finished_unix_time = int(data.get("last_finished_unix_time", 0))
	var stored_history: Variant = data.get("history", [])
	if stored_history is Array:
		for entry in stored_history:
			if entry is Dictionary:
				record.history.append(entry)
	return record


## Always `MODE_COUNT` long, whatever the file said. A short array here would crash
## the first `record_run` after a mode is added, on a save written before it existed.
static func _int_field(data: Dictionary, key: String) -> PackedInt32Array:
	var values := PackedInt32Array()
	var stored: Variant = data.get(key)
	if stored is PackedInt32Array:
		values = stored
	values.resize(MODE_COUNT)
	return values


static func _float_field(data: Dictionary, key: String) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	var stored: Variant = data.get(key)
	if stored is PackedFloat32Array:
		values = stored
	values.resize(MODE_COUNT)
	return values
