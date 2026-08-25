class_name PhaseBCloverTelemetry
extends Node

## What the Clover machine actually did, recorded per spin.
##
## The master guide's questions are all comparative - which stakes players use, how
## often All In saves a run rather than ending it, whether droughts are still
## happening - and none of them can be answered by watching one spin. So every spin
## is written down as one row, in the order the guide lists, and the run can be asked
## for the whole table afterwards.
##
## It records and does not judge. Nothing here changes odds, and nothing here is read
## by the machine: a telemetry component that fed back into the thing it measures
## would stop measuring it. It is also strictly opt-in - `enabled` off means no
## allocation per spin at all, because this exists for internal testing and a shipped
## run should not pay for it.

## A spin was written down. Carried so a debug view can print the newest row without
## asking for the whole table every frame.
signal spin_recorded(row: Dictionary)

@export_group("Collaborators")
## The machine being watched. Its signals are the only things that write a row.
@export var slot_machine: PhaseBSlotMachine
## Odds source, for the chances that were actually in force when the lever moved.
@export var clover_odds: PhaseBCloverOdds
## Field, for how much Green the organism held either side of the result.
@export var territory_field: TerritoryField
## Grace controller, for whether an All In whiff was survived and how long it took.
@export var all_in_grace: PhaseBAllInGrace
## Wave director, for the wave and the run clock a spin happened on.
@export var wave_director: PhaseBWaveDirector

@export_group("Recording")
## Off by default. This is a development instrument, and a shipped run should not
## be paying for a dictionary per spin to answer questions nobody is asking.
@export var enabled := false
## Rows kept before the oldest is dropped. A twelve-minute run cannot produce more
## spins than this, so in practice it is a guard against a session left running.
@export_range(16, 4096, 16) var maximum_rows := 512
## Print each row as it is recorded. Useful while playing; unreadable in a suite.
@export var print_rows := false

var _rows: Array[Dictionary] = []
var _run_id := ""
## Captured when the lever moves, because half of a row describes the board as it was
## before the spin resolved and that board no longer exists by the time it does.
var _pending := {}


func _ready() -> void:
	reset_telemetry()
	if slot_machine != null:
		slot_machine.spin_started.connect(_on_spin_started)
		slot_machine.spin_resolved.connect(_on_spin_resolved)
	if all_in_grace != null:
		all_in_grace.grace_recovered.connect(_on_grace_recovered)
		all_in_grace.grace_failed.connect(_on_grace_failed)


func reset_telemetry() -> void:
	_rows.clear()
	_pending.clear()
	# Enough to tell two runs of one session apart, which is all a run id is for.
	_run_id = "%d-%d" % [Time.get_ticks_msec(), randi() % 100000]


func get_run_id() -> String:
	return _run_id


func get_row_count() -> int:
	return _rows.size()


func get_rows() -> Array[Dictionary]:
	return _rows


func get_last_row() -> Dictionary:
	return _rows[-1] if not _rows.is_empty() else {}


func _on_spin_started(stake: int, committed: PackedInt32Array) -> void:
	if not enabled:
		return
	# The half of the row that describes the board the player bet on. Taken now
	# because the result is about to change it, and a "before" measured afterwards
	# is not a before.
	_pending = {
		"run_id": _run_id,
		"wave": wave_director.get_current_wave_number() if wave_director != null else 0,
		"time": wave_director.elapsed_seconds if wave_director != null else 0.0,
		"stake_tier": stake,
		"wagered_cells": committed.size(),
		"owned_green_before_spin": (
			territory_field.get_player_cell_count() if territory_field != null else 0
		),
		"established_green_before_spin": (
			territory_field.get_established_cell_count() if territory_field != null else 0
		),
		"drought_count": clover_odds.get_drought(stake) if clover_odds != null else 0,
	}
	# The chances that were actually in force when the lever moved, read from the one
	# place the readout reads them, so what is logged is what was printed and what was
	# rolled rather than a third opinion.
	var odds := (
		clover_odds.get_effective_odds(stake) if clover_odds != null else {}
	)
	_pending["effective_path_jackpot_chance"] = odds.get("path_jackpot", 0.0)
	_pending["triple_clover_chance"] = odds.get("triple_clover", 0.0)
	_pending["triple_bust_chance"] = odds.get("triple_bust", 0.0)
	_pending["whiff_chance"] = odds.get("whiff", 0.0)


func _on_spin_resolved(outcome: int, path_symbol: int, stake: int) -> void:
	if not enabled or _pending.is_empty():
		return
	var row := _pending.duplicate()
	_pending.clear()
	row["outcome"] = outcome
	row["outcome_name"] = CloverSlot.get_outcome_name(outcome)
	row["path_symbol"] = path_symbol
	row["reel_symbols"] = (
		slot_machine.get_last_symbols().duplicate() if slot_machine != null else PackedInt32Array()
	)
	var symbols: PackedInt32Array = row["reel_symbols"]
	row["first_pair_match"] = symbols.size() >= 2 and symbols[0] == symbols[1]
	row["rewind_easter_egg"] = slot_machine.is_rewinding() if slot_machine != null else false
	row["owned_green_after_result"] = (
		territory_field.get_player_cell_count() if territory_field != null else 0
	)
	# Filled in later if this spin turns out to have started a grace period, because
	# the answer does not exist yet at the moment the spin resolves.
	row["all_in_grace_success"] = null
	row["all_in_grace_recovery_time"] = 0.0
	row["stake_tier"] = stake
	_append(row)


func _on_grace_recovered(_seconds_remaining: float) -> void:
	_close_grace_row(true)


func _on_grace_failed() -> void:
	_close_grace_row(false)


func _close_grace_row(survived: bool) -> void:
	# The grace outcome belongs to the spin that caused it, so it is written back onto
	# that row rather than becoming a row of its own with nothing else in it.
	if not enabled or _rows.is_empty():
		return
	var row := _rows[-1]
	row["all_in_grace_success"] = survived
	# How long the rescue took, which is the grace window minus what was left of it.
	row["all_in_grace_recovery_time"] = (
		maxf(0.0, all_in_grace.grace_duration - all_in_grace.get_remaining_seconds())
		if all_in_grace != null
		else 0.0
	)
	spin_recorded.emit(row)


func _append(row: Dictionary) -> void:
	_rows.append(row)
	while _rows.size() > maximum_rows:
		_rows.remove_at(0)
	if print_rows:
		print("CLOVER %s" % describe_row(row))
	spin_recorded.emit(row)


static func describe_row(row: Dictionary) -> String:
	# One line per spin, in the guide's own order, so a log can be read down a column
	# rather than being reformatted before anyone can look at it.
	return (
		"wave %d  %.1fs  stake %d  green %d>%d  drought %d  "
		% [
			row.get("wave", 0),
			row.get("time", 0.0),
			row.get("stake_tier", 0),
			row.get("owned_green_before_spin", 0),
			row.get("owned_green_after_result", 0),
			row.get("drought_count", 0),
		]
		+ "jackpot %.3f  clover %.3f  bust %.3f  -> %s%s%s"
		% [
			row.get("effective_path_jackpot_chance", 0.0),
			row.get("triple_clover_chance", 0.0),
			row.get("triple_bust_chance", 0.0),
			row.get("outcome_name", ""),
			"  [pair]" if row.get("first_pair_match", false) else "",
			"  [rewind]" if row.get("rewind_easter_egg", false) else "",
		]
	)


func describe_run() -> String:
	# The guide's questions, answered off the table rather than by reading it. Which
	# stakes were used, how many jackpots a run produced, how long the droughts got,
	# and whether All In saved the run or ended it.
	if _rows.is_empty():
		return "CLOVER TELEMETRY: no spins recorded."
	var stake_counts := PackedInt32Array([0, 0, 0, 0])
	var jackpots := 0
	var busts := 0
	var whiffs := 0
	var clovers := 0
	var longest_drought := 0
	var grace_survived := 0
	var grace_failed := 0
	for row in _rows:
		var stake: int = row.get("stake_tier", 0)
		if stake >= 0 and stake < stake_counts.size():
			stake_counts[stake] += 1
		longest_drought = maxi(longest_drought, int(row.get("drought_count", 0)))
		match int(row.get("outcome", -1)):
			CloverSlot.Outcome.PATH_JACKPOT:
				jackpots += 1
			CloverSlot.Outcome.TRIPLE_CLOVER:
				clovers += 1
			CloverSlot.Outcome.TRIPLE_BUST:
				busts += 1
			CloverSlot.Outcome.WHIFF:
				whiffs += 1
		var grace = row.get("all_in_grace_success", null)
		if grace == true:
			grace_survived += 1
		elif grace == false:
			grace_failed += 1
	return (
		"CLOVER TELEMETRY %s: %d spins  stakes %d/%d/%d/%d  "
		% [
			_run_id,
			_rows.size(),
			stake_counts[0],
			stake_counts[1],
			stake_counts[2],
			stake_counts[3],
		]
		+ "jackpots %d  clovers %d  busts %d  whiffs %d  longest drought %d  "
		% [jackpots, clovers, busts, whiffs, longest_drought]
		+ "All In survived %d / failed %d" % [grace_survived, grace_failed]
	)
