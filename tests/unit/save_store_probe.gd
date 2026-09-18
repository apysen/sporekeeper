extends SceneTree

## The save file itself: what `SaveStore` writes, what it refuses to read, and what it
## leaves alone.
##
## `user://save.dat` is the player's own run. A probe that wrote test data over it
## would destroy the thing the feature exists to protect, so this one reads the file
## into memory first and puts the bytes back at the end - including putting *no file*
## back, which is the state of a machine that has never saved and is not reachable by
## writing anything.
##
## Run: godot --headless --path . --script tests/unit/save_store_probe.gd

var _failures := 0
var _held_bytes := PackedByteArray()
var _held_file := false


func _initialize() -> void:
	_hold_existing_save()
	_run()
	_restore_existing_save()
	if _failures == 0:
		print("SAVE_STORE: PASS")
		quit(0)
	else:
		push_error("SAVE_STORE: %d failure(s)" % _failures)
		quit(1)


func _run() -> void:
	SaveStore.erase()
	_check(SaveStore.read().is_empty(), "a machine that has never saved reads as no save")
	_check(not SaveStore.has_run(), "and is offered no run to continue")
	_check(
		MetaRecord.from_dictionary(SaveStore.read_meta()).runs_finished == 0,
		"and has finished no runs"
	)

	var snapshot := RunSnapshot.new()
	snapshot.mode = RunMode.Id.CAMPAIGN
	snapshot.run_seed = 0x5AFE0001
	snapshot.wave_number = 14
	snapshot.elapsed_seconds = 921.5
	snapshot.set_system("progression", {
		"current_level": 9,
		"upgrade_levels": PackedInt32Array([1, 0, 3]),
		"biomass": 42.5,
	})
	snapshot.set_system("field", {"control": PackedFloat32Array([0.25, -0.75])})
	SaveStore.write_run(snapshot.to_dictionary())

	var read_back := RunSnapshot.from_dictionary(SaveStore.read_run())
	_check(SaveStore.has_run(), "a written run is offered back")
	_check(
		read_back.mode == snapshot.mode
		and read_back.run_seed == snapshot.run_seed
		and read_back.wave_number == snapshot.wave_number
		and is_equal_approx(read_back.elapsed_seconds, snapshot.elapsed_seconds),
		"the run's identity survives the file"
	)
	# The types are the point, not just the values: a Packed array that came back as a
	# generic Array would still compare equal element by element and would then be
	# rejected by every `is PackedInt32Array` guard that reads it.
	var progression_state := read_back.get_system("progression")
	var field_state := read_back.get_system("field")
	_check(
		progression_state.get("upgrade_levels") is PackedInt32Array
		and progression_state.get("upgrade_levels") == PackedInt32Array([1, 0, 3])
		and field_state.get("control") is PackedFloat32Array,
		"packed arrays come back packed rather than as generic arrays"
	)
	_check(int(progression_state.get("current_level", 0)) == 9, "a system's own state survives")

	var record := MetaRecord.from_dictionary(SaveStore.read_meta())
	record.record_run(RunMode.Id.CAMPAIGN, false, 14, 812.0)
	record.record_run(RunMode.Id.QUICK, true, 9, 400.0)
	record.record_run(RunMode.Id.QUICK, false, 22, 150.0)
	SaveStore.write_meta(record.to_dictionary())
	var stored_record := MetaRecord.from_dictionary(SaveStore.read_meta())
	_check(
		stored_record.runs_finished == 3 and stored_record.victories == 1,
		"finished runs and victories accumulate across the file"
	)
	_check(
		stored_record.best_wave_by_mode[RunMode.Id.QUICK] == 22
		and stored_record.best_wave_by_mode[RunMode.Id.CAMPAIGN] == 14,
		"each mode keeps its own best wave rather than sharing one"
	)
	_check(
		is_equal_approx(stored_record.best_biomass_by_mode[RunMode.Id.QUICK], 400.0),
		"a worse run does not overwrite a better one's best"
	)

	# The two halves of the file are written by different moments - a wave boundary and
	# the end of a run - so neither may take the other with it.
	_check(SaveStore.has_run(), "writing the record leaves the run in progress alone")
	SaveStore.clear_run()
	_check(
		not SaveStore.has_run()
		and MetaRecord.from_dictionary(SaveStore.read_meta()).runs_finished == 3,
		"clearing the run leaves the record of finished runs alone"
	)

	# A file that is not a save at all. A crash mid-write leaves one, and the only
	# acceptable behavior is to start the game without a save - never to refuse to start.
	var corrupt := FileAccess.open(SaveStore.PATH, FileAccess.WRITE)
	corrupt.store_string("this is not a save")
	corrupt.close()
	_check(SaveStore.read().is_empty(), "a corrupt file reads as no save rather than failing")
	_check(not SaveStore.has_run(), "and offers nothing to continue")

	# A save from a build that does not exist yet. Reading it as though it were this
	# build's would be a wrong resume rather than a missing one.
	var newer := {SaveStore.VERSION_KEY: SaveStore.VERSION + 1, SaveStore.RUN_KEY: {"mode": 1}}
	var file := FileAccess.open_compressed(
		SaveStore.PATH, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD
	)
	file.store_var(newer, false)
	file.close()
	_check(SaveStore.read().is_empty(), "a save from a newer build is ignored rather than read")

	SaveStore.erase()
	_check(not FileAccess.file_exists(SaveStore.PATH), "erasing removes the file outright")

	_check_migrations()


## The migration chain, run with a chain of its own.
##
## The real `MIGRATIONS` is empty, because there is one version and nothing to carry
## forward. A seam that has never run is one nobody should trust on the day it is first
## needed - which is the day someone's save depends on it - so it is exercised here
## with steps this probe writes.
func _check_migrations() -> void:
	var steps := {
		1: func(data: Dictionary) -> Dictionary:
			data["carried"] = str(data.get("carried", "")) + "1to2"
			return data,
		2: func(data: Dictionary) -> Dictionary:
			data["carried"] = str(data.get("carried", "")) + "+2to3"
			return data,
	}
	var carried := SaveStore.apply_migrations({"run": {"mode": 1}}, 1, 3, steps)
	_check(
		str(carried.get("carried", "")) == "1to2+2to3",
		"a save two versions behind is carried forward one step at a time"
	)
	_check(
		int(carried.get(SaveStore.VERSION_KEY, 0)) == 3
		and (carried.get("run") as Dictionary).get("mode") == 1,
		"and arrives stamped with the version it was brought to, carrying its contents"
	)
	_check(
		SaveStore.apply_migrations({"kept": true}, 3, 3, {}).get("kept") == true,
		"a save already at the current version is passed through untouched"
	)
	# A gap is a version nothing can carry forward - a build whose saves predate the
	# chain, or a version that was never released. Discarded rather than half-read.
	_check(
		SaveStore.apply_migrations({"run": {}}, 1, 3, {2: steps[2]}).is_empty(),
		"a version with no migration is discarded rather than partly applied"
	)
	_check(
		SaveStore.apply_migrations({"run": {}}, 1, 2, {
			1: func(_data: Dictionary) -> Variant: return null,
		}).is_empty(),
		"a migration that does not return a save discards it rather than storing nothing"
	)


## The player's save, held as bytes rather than as a parsed dictionary: whatever is in
## it goes back exactly, including a file this build would refuse to read.
func _hold_existing_save() -> void:
	_held_file = FileAccess.file_exists(SaveStore.PATH)
	if not _held_file:
		return
	var file := FileAccess.open(SaveStore.PATH, FileAccess.READ)
	if file == null:
		_held_file = false
		return
	_held_bytes = file.get_buffer(file.get_length())
	file.close()


func _restore_existing_save() -> void:
	if not _held_file:
		SaveStore.erase()
		return
	var file := FileAccess.open(SaveStore.PATH, FileAccess.WRITE)
	if file == null:
		push_error("SAVE_STORE: could not put the machine's own save back")
		_failures += 1
		return
	file.store_buffer(_held_bytes)
	file.close()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		push_error("FAIL: %s" % description)
