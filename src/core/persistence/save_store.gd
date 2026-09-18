class_name SaveStore
extends RefCounted

## The file a run in progress and the record of finished runs live in.
##
## The counterpart to `SettingsStore`, and the same doctrine: this is the only thing
## in the project that knows `save.dat` exists, what it holds, or that it is a
## compressed Variant rather than a `ConfigFile`. Callers hand over dictionaries and
## get dictionaries back.
##
## Binary rather than the `ConfigFile` the settings use, because a run snapshot is
## mostly per-cell float arrays - a `PackedFloat32Array` of seven thousand cells
## written as `ConfigFile` text is hundreds of kilobytes of decimal digits, and there
## is nothing in a save a player is meant to hand-edit.
##
## A missing file is the first launch, and a corrupt one is a crash mid-write or a
## save from a build that no longer exists. Neither is an error worth stopping for:
## both read as "no save", because the alternative is refusing to start the game over
## a file whose only purpose was to make starting faster.

const PATH := "user://save.dat"

## Bumped when the shape of what `write` stores changes in a way a previous file
## cannot be read as. `_migrate` is where an older file is brought forward; a file
## it cannot bring forward is discarded rather than half-read.
const VERSION := 1

const RUN_KEY := "run"
const META_KEY := "meta"
const VERSION_KEY := "version"


## Everything on file, or an empty Dictionary when there is no readable save.
static func read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var file := FileAccess.open_compressed(PATH, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		push_warning("SaveStore: %s could not be opened; treating it as no save" % PATH)
		return {}
	# `false` is the point: a save is data, and allowing objects in it would let a
	# file decide what code runs when the game starts.
	var stored: Variant = file.get_var(false)
	file.close()
	if not (stored is Dictionary):
		push_warning("SaveStore: %s did not hold a save; treating it as no save" % PATH)
		return {}
	var data: Dictionary = stored
	var version := int(data.get(VERSION_KEY, 0))
	if version == VERSION:
		return data
	return _migrate(data, version)


## The run in progress, or an empty Dictionary when the save holds no unfinished run -
## which is a save written after a victory or a defeat, and the ordinary case.
static func read_run() -> Dictionary:
	var run: Variant = read().get(RUN_KEY, {})
	return run if run is Dictionary else {}


static func has_run() -> bool:
	return not read_run().is_empty()


## The record of finished runs, or an empty Dictionary before the first one ends.
static func read_meta() -> Dictionary:
	var meta: Variant = read().get(META_KEY, {})
	return meta if meta is Dictionary else {}


## Replaces the run in progress, leaving the record of finished runs alone. An empty
## Dictionary clears it, which is what finishing a run does.
static func write_run(run: Dictionary) -> void:
	var data := read()
	data[RUN_KEY] = run
	_write(data)


static func clear_run() -> void:
	write_run({})


## Replaces the record of finished runs, leaving any run in progress alone.
static func write_meta(meta: Dictionary) -> void:
	var data := read()
	data[META_KEY] = meta
	_write(data)


## Removes the file outright. Nothing in the game calls this; it is here so a test can
## start from a machine that has never saved, which is a state no sequence of ordinary
## writes can get back to.
static func erase() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


static func _write(data: Dictionary) -> void:
	data[VERSION_KEY] = VERSION
	var file := FileAccess.open_compressed(PATH, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		push_warning("SaveStore: %s could not be written (%d)" % [PATH, FileAccess.get_open_error()])
		return
	file.store_var(data, false)
	file.close()


## Brings a file written by an older build forward, or returns empty to discard it.
##
## Each entry in `MIGRATIONS` takes a file at version *key* and returns it at version
## *key + 1*, so a save two versions behind is carried forward by running two of them
## in order rather than by one function that has to know every shape the file has ever
## had. A version with no entry is one nothing can be done with - a build whose saves
## predate the chain, or a gap left by a version that was never released - and the file
## is discarded rather than half-read.
##
## The chain is empty today because there is one version. What the seam buys is that
## the first build to change the shape adds one function and a number, and everything
## that reads a save keeps reading the current shape only.
const MIGRATIONS := {}


static func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	if from_version > VERSION:
		push_warning(
			"SaveStore: %s was written by a newer build (version %d); ignoring it"
				% [PATH, from_version]
		)
		return {}
	return apply_migrations(data, from_version, VERSION, MIGRATIONS)


## Runs a chain of migrations over a save, or returns empty when it cannot.
##
## The steps are a parameter rather than read from `MIGRATIONS` so that the chain can
## be exercised while the real one is empty. A seam nothing has ever run is a seam
## nobody should trust on the day it is first needed, which is the day a player's save
## depends on it - so `save_store_probe` runs this with a chain of its own and proves
## the stepping, the gap and the failure all behave.
static func apply_migrations(
	data: Dictionary, from_version: int, to_version: int, steps: Dictionary
) -> Dictionary:
	var migrated := data.duplicate(true)
	var version := from_version
	while version < to_version:
		if not steps.has(version):
			push_warning(
				"SaveStore: %s is version %d and nothing can carry it forward; starting fresh"
					% [PATH, version]
			)
			return {}
		var step: Callable = steps[version]
		var stepped: Variant = step.call(migrated)
		if not (stepped is Dictionary):
			push_warning(
				"SaveStore: the migration from version %d did not return a save; starting fresh"
					% version
			)
			return {}
		migrated = stepped
		version += 1
	migrated[VERSION_KEY] = to_version
	return migrated
