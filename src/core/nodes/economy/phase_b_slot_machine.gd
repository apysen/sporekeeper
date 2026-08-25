class_name PhaseBSlotMachine
extends Node

## The Clover machine: a 1x3 slot permanently housed in the right-hand panel, wagering
## Territory rather than Biomass.
##
## What the player stakes is a physical region of the organism, chosen around wherever
## they are standing, and what they win is a Plant Path unleashed at full strength on
## the battlefield. Those are two different axes on purpose. Biomass is never touched:
## Metabolism keeps developing from the run's lifetime earnings whatever the reels do,
## so gambling can cost the run its body without ever undoing its growth.
##
## There are no small prizes. Most spins pay nothing at all, a jackpot is enormous, and
## a Triple Bust turns the wagered ground hostile. The stake notch does not buy a bigger
## prize - the prize is already a maxed Path - it buys better odds and a worse floor, so
## the slider reads as how much of the organism the run can currently afford to lose.
##
## The only lock on the lever is the reels still turning. That is deliberate: a player
## may spin again the instant the machine is ready, during an active jackpot, or into
## the wreckage of the last one.

## The lever went down. The faces are already decided - a slot machine knows its answer
## the moment the lever moves - and the wager region is already frozen, but nothing has
## been paid or taken until the reels stop.
signal spin_started(stake: int, committed_cells: PackedInt32Array)
## One reel came to rest on this face.
signal reel_stopped(reel_index: int, symbol: int)
## The first two reels matched. The third is now in its slowdown, and the run does not
## yet know whether this is a jackpot, a whiff or a catastrophe.
signal pair_tease_started(symbol: int, first_of_run: bool)
## The line has been read and the territory consequence has been applied.
signal spin_resolved(outcome: int, path_symbol: int, stake: int)
## A Path won and wants its event fired at this strength, at this many places.
signal path_jackpot(path_symbol: int, jackpot_scale: float)
## Every Path at once.
signal clover_jackpot(jackpot_scale: float)
## An All In whiff took the whole organism. The run has three seconds.
signal all_in_wiped()
## An All In Bust. The field is hostile and the run is over.
signal all_in_ruined()
## The preview region changed. Emitted only while the preview is being shown.
signal wager_preview_changed(cells: PackedInt32Array)

enum State {
	READY,
	SPINNING,
}

@export_group("Collaborators")
## The organism the wager is taken from and the consequence is written back to.
@export var territory_field: TerritoryField
## Chance, protection, and the construction of the visible faces.
@export var odds: PhaseBCloverOdds
## Which cells this stake would take right now.
@export var wager_selector: PhaseBWagerSelector

@export_group("Buy-In")
## Share of the claimable board that must be Established-or-better Green before the
## lever will move. A run with almost nothing left must not be able to use All In as a
## free lottery ticket, so the requirement applies to every stake including that one.
@export_range(0.0, 0.5, 0.005) var minimum_buyin_established_fraction := 0.10

@export_group("Reel Timing")
## When each reel comes to rest, in seconds after the lever goes down. The gap between
## the second and the third is the only tension a slot machine has to offer.
@export var reel_stop_seconds := PackedFloat32Array([0.65, 1.05, 1.55])
## When the third reel stops instead, if the first two matched. Nearly a second longer,
## and it applies to a Bust pair exactly as it does to a winning pair, so the slowdown
## itself never reveals which one is coming.
@export_range(1.0, 5.0, 0.05) var tease_reel_stop_seconds := 2.45
## Pause between the last reel locking and the battlefield event, so the line is read
## before the arena erupts.
@export_range(0.0, 0.5, 0.01) var result_recognition_beat := 0.10

@export_group("Presentation")
## Share of eligible Path jackpots where the winning face scrolls past, hesitates, and
## snaps back. Never used on a whiff or a Bust: the animation would then be a lie about
## a result that has already been decided.
@export_range(0.0, 1.0, 0.01) var jackpot_rewind_chance := 0.10
## How much longer a rewind keeps the third reel turning: the slow pass, the hold, and
## the reverse snap.
@export var rewind_seconds := PackedFloat32Array([0.50, 0.14, 0.16])

@export_group("Jackpot Scale")
## A jackpot must feel enormous even when the run owns almost nothing, so the guaranteed
## base is large and Territory only bends it upward.
@export_range(0.0, 4.0, 0.05) var jackpot_scale_base := 0.75
@export_range(0.0, 4.0, 0.05) var jackpot_scale_territory := 0.75

@export_group("Preview")
## How often the preview region is rebuilt while it is on screen. Ten times a second is
## far below the frame rate and far above what the eye reads as lag.
@export_range(1.0, 60.0, 1.0) var preview_hz := 10.0

@export_group("Bust")
## How hostile the wagered ground becomes on a Bust. Well past the ownership threshold,
## because a Bust has to leave something that must be fought back through rather than
## simply empty ground.
@export_range(0.2, 1.0, 0.05) var bust_hostile_control := 0.75

var _state := State.READY
var _stake := CloverSlot.Stake.LOW
var _elapsed := 0.0
var _reels_reported := 0
var _tease := false
var _rewind := false
var _first_pair_focus_used := false
var _pair_tease_announced := false
var _symbols := PackedInt32Array([
	CloverSlot.Symbol.CLOVER,
	CloverSlot.Symbol.CLOVER,
	CloverSlot.Symbol.CLOVER,
])
var _outcome := CloverSlot.Outcome.WHIFF
var _path_symbol := -1
var _committed := PackedInt32Array()
var _committed_owned_count := 0
var _spin_count := 0
var _preview_visible := false
var _preview_cells := PackedInt32Array()
var _preview_accumulator := 0.0
var _preview_seed_cell := -1
var _preview_stake := -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	assert(territory_field != null, "PhaseBSlotMachine requires a TerritoryField")
	assert(odds != null, "PhaseBSlotMachine requires PhaseBCloverOdds")
	assert(wager_selector != null, "PhaseBSlotMachine requires PhaseBWagerSelector")
	_rng.randomize()
	reset_machine()


func reset_machine() -> void:
	_state = State.READY
	# Low on a fresh run. The selected notch is otherwise remembered for the whole run,
	# because re-picking it after every spin would turn a decision into a chore.
	_stake = CloverSlot.Stake.LOW
	_elapsed = 0.0
	_reels_reported = 0
	_tease = false
	_rewind = false
	_first_pair_focus_used = false
	_pair_tease_announced = false
	_symbols = PackedInt32Array([
		CloverSlot.Symbol.CLOVER,
		CloverSlot.Symbol.CLOVER,
		CloverSlot.Symbol.CLOVER,
	])
	_outcome = CloverSlot.Outcome.WHIFF
	_path_symbol = -1
	_committed = PackedInt32Array()
	_committed_owned_count = 0
	_spin_count = 0
	_preview_visible = false
	_preview_cells = PackedInt32Array()
	_preview_accumulator = 0.0
	_preview_seed_cell = -1
	_preview_stake = -1
	if odds != null:
		odds.reset_odds()


# --- Stake and eligibility ------------------------------------------------------


func set_stake(stake: int) -> void:
	var wanted := clampi(stake, 0, CloverSlot.Stake.size() - 1)
	if wanted == _stake:
		return
	_stake = wanted
	# The region grows or contracts immediately rather than at the next preview tick,
	# so moving the notch reads as the wager itself changing size.
	_preview_stake = -1


func get_stake() -> int:
	return _stake


func get_stake_fraction() -> float:
	return CloverSlot.get_stake_fraction(_stake)


func get_established_fraction() -> float:
	if territory_field == null:
		return 0.0
	var claimable := territory_field.get_claimable_cell_count()
	if claimable <= 0:
		return 0.0
	return float(territory_field.get_established_cell_count()) / float(claimable)


func is_buy_in_met() -> bool:
	return get_established_fraction() >= minimum_buyin_established_fraction


func can_spin() -> bool:
	return (
		_state == State.READY
		and is_buy_in_met()
		and territory_field != null
		and territory_field.get_player_cell_count() > 0
	)


func get_state() -> int:
	return _state


func get_spin_count() -> int:
	return _spin_count


func get_effective_odds() -> Dictionary:
	return odds.get_effective_odds(_stake)


# --- Preview --------------------------------------------------------------------


func set_preview_visible(visible_now: bool, player_local_position := Vector2.ZERO) -> void:
	## The region only shows while the player is actually looking at the machine. A
	## permanent pulsing overlay would make the arena unreadable during the ninety-odd
	## percent of a run that has nothing to do with gambling.
	if visible_now == _preview_visible:
		return
	_preview_visible = visible_now
	if visible_now:
		_preview_stake = -1
		_rebuild_preview(player_local_position)
	else:
		_preview_cells = PackedInt32Array()
		wager_preview_changed.emit(_preview_cells)


func is_preview_visible() -> bool:
	return _preview_visible


func get_preview_cells() -> PackedInt32Array:
	return _preview_cells


func advance_preview(delta: float, player_local_position: Vector2) -> void:
	if not _preview_visible:
		return
	_preview_accumulator += delta
	var interval := 1.0 / maxf(1.0, preview_hz)
	if _preview_accumulator < interval:
		return
	_preview_accumulator = 0.0
	var seed_cell := territory_field.local_to_cell_index(player_local_position)
	if seed_cell == _preview_seed_cell and _preview_stake == _stake:
		# Same cell, same notch. The board may still be moving underneath, but rebuilding
		# for that alone would spend the budget on a region nobody can see change.
		return
	_rebuild_preview(player_local_position)


func _rebuild_preview(player_local_position: Vector2) -> void:
	_preview_seed_cell = territory_field.local_to_cell_index(player_local_position)
	_preview_stake = _stake
	_preview_cells = wager_selector.select(_stake, player_local_position)
	wager_preview_changed.emit(_preview_cells)


# --- The spin -------------------------------------------------------------------


func try_spin(player_local_position: Vector2) -> bool:
	if not can_spin():
		return false
	# The House Always Loses pays a free spin when its last Bust face comes off. It costs
	# no territory at all, so the wager is skipped rather than refunded.
	var free_spin := odds.take_free_spin()
	# The wager is recomputed once here rather than reusing whatever the preview last
	# drew. The preview follows the player; the committed region is world-fixed from
	# this instant, and the two must not be allowed to disagree by a tick.
	_committed = (
		PackedInt32Array()
		if free_spin
		else wager_selector.select(_stake, player_local_position)
	)
	if _committed.is_empty() and not free_spin:
		return false
	_committed_owned_count = territory_field.get_player_cell_count()
	_outcome = odds.roll_outcome(_stake)
	_path_symbol = odds.pick_path() if _outcome == CloverSlot.Outcome.PATH_JACKPOT else -1
	_symbols = odds.build_display(_outcome, _path_symbol)
	_tease = _symbols[0] == _symbols[1]
	_rewind = (
		_tease
		and _outcome == CloverSlot.Outcome.PATH_JACKPOT
		and _rng.randf() < jackpot_rewind_chance
	)
	_elapsed = 0.0
	_reels_reported = 0
	_pair_tease_announced = false
	_spin_count += 1
	_state = State.SPINNING
	# The preview stops pulsing the moment the wager stops being hypothetical.
	_preview_visible = false
	_preview_cells = PackedInt32Array()
	wager_preview_changed.emit(_preview_cells)
	spin_started.emit(_stake, _committed)
	return true


func advance(delta: float) -> void:
	if _state != State.SPINNING:
		return
	_elapsed += delta
	while _reels_reported < 3 and _elapsed >= get_reel_stop_seconds(_reels_reported):
		reel_stopped.emit(_reels_reported, _symbols[_reels_reported])
		_reels_reported += 1
		if _reels_reported == 2 and _tease and not _pair_tease_announced:
			_pair_tease_announced = true
			var first := not _first_pair_focus_used
			_first_pair_focus_used = true
			pair_tease_started.emit(_symbols[0], first)
	if _elapsed < get_reveal_duration():
		return
	_state = State.READY
	_resolve()


func get_reel_stop_seconds(reel_index: int) -> float:
	if reel_index < 0 or reel_index >= 3:
		return 0.0
	if reel_index < 2:
		return reel_stop_seconds[reel_index]
	if not _tease:
		return reel_stop_seconds[2]
	var stop := tease_reel_stop_seconds
	if _rewind:
		for span in rewind_seconds:
			stop += span
	return stop


func get_reveal_duration() -> float:
	return get_reel_stop_seconds(2) + result_recognition_beat


func is_revealing() -> bool:
	return _state == State.SPINNING


func is_reel_spinning(reel_index: int) -> bool:
	return _state == State.SPINNING and _elapsed < get_reel_stop_seconds(reel_index)


func is_teasing() -> bool:
	return _state == State.SPINNING and _tease and _elapsed >= reel_stop_seconds[1]


func is_rewinding() -> bool:
	return _rewind


## Stages of the rewind, in order. The animation is the whole of what a rewind is -
## the result was decided before the reels moved and is never changed by it - so the
## stages live here beside the timings that reserve them rather than being a second
## opinion held by whatever draws the reel.
enum RewindStage {
	## Not rewinding, or not yet at the point where the tease begins.
	NONE,
	## The winning symbol crosses the payline and keeps going.
	PASS,
	## It sits past the line, apparently missed.
	HOLD,
	## The reel reverses and it snaps back into place.
	SNAP,
}


func get_rewind_stage() -> int:
	# Which part of the fakeout the third reel is in. Measured from the point the reel
	# would have stopped at without one, so the ordinary tease timing is untouched and
	# a rewind is purely an extension of it.
	if not _rewind or _state != State.SPINNING:
		return RewindStage.NONE
	var into := _elapsed - tease_reel_stop_seconds
	if into < 0.0:
		return RewindStage.NONE
	var edge := 0.0
	for stage in range(rewind_seconds.size()):
		edge += rewind_seconds[stage]
		if into < edge:
			return RewindStage.PASS + stage
	return RewindStage.NONE


func get_rewind_stage_fraction() -> float:
	# How far through the current stage, so the drawing can move something across it.
	if not _rewind or _state != State.SPINNING:
		return 0.0
	var into := _elapsed - tease_reel_stop_seconds
	if into < 0.0:
		return 0.0
	var edge := 0.0
	for stage in range(rewind_seconds.size()):
		var span := maxf(0.0001, rewind_seconds[stage])
		if into < edge + span:
			return clampf((into - edge) / span, 0.0, 1.0)
		edge += span
	return 1.0


func get_elapsed_seconds() -> float:
	return _elapsed


func get_last_symbols() -> PackedInt32Array:
	return _symbols


func get_last_outcome() -> int:
	return _outcome


func get_last_path_symbol() -> int:
	return _path_symbol


func get_committed_cells() -> PackedInt32Array:
	return _committed


func get_jackpot_scale() -> float:
	## Large guaranteed spectacle, bent upward by how much of the board the run holds.
	## Square-rooted so owning the whole arena is worth half again as much as owning a
	## corner of it rather than twenty times as much.
	if territory_field == null:
		return jackpot_scale_base
	var claimable := territory_field.get_claimable_cell_count()
	if claimable <= 0:
		return jackpot_scale_base
	var owned := float(territory_field.get_player_cell_count()) / float(claimable)
	return jackpot_scale_base + jackpot_scale_territory * sqrt(clampf(owned, 0.0, 1.0))


func _resolve() -> void:
	# Read before the outcome is noted, in both cases. The Side Pot is emptied by the
	# result it pays into, and High Roller's counter advances on the same call, so asking
	# afterwards would cash a pot that had already been spent and double the wrong spin.
	var scale := get_jackpot_scale() + odds.get_side_pot_scale_bonus()
	var doubled := odds.is_high_roller_spin()
	if doubled:
		scale *= 2.0
	odds.note_outcome(_stake, _outcome)
	match _outcome:
		CloverSlot.Outcome.PATH_JACKPOT:
			# The wager is simply not taken. Ground lost to the enemy while the reels
			# were turning stays lost: a jackpot means the machine did not eat the
			# organism, not that the last two seconds are rewound.
			path_jackpot.emit(_path_symbol, scale)
		CloverSlot.Outcome.TRIPLE_CLOVER:
			clover_jackpot.emit(scale)
			for symbol in CloverSlot.PATH_SYMBOLS:
				path_jackpot.emit(symbol, scale)
		CloverSlot.Outcome.TRIPLE_BUST:
			if _stake == CloverSlot.Stake.ALL_IN:
				territory_field.make_field_hostile(bust_hostile_control)
				all_in_ruined.emit()
			else:
				# High Roller doubles what it costs as well as what it pays. The region is
				# already fixed, so the doubling lands on how hostile the ground becomes
				# rather than on how much of it there is: the wager the player agreed to
				# is still the wager they lose.
				territory_field.make_cells_hostile(
					_committed,
					minf(1.0, bust_hostile_control * (2.0 if doubled else 1.0))
				)
		_:
			if _stake == CloverSlot.Stake.ALL_IN:
				# Everything, including Green grown during the spin. All In is literal.
				territory_field.neutralize_all_owned()
				all_in_wiped.emit()
			else:
				territory_field.neutralize_cells(_committed)
	spin_resolved.emit(_outcome, _path_symbol, _stake)
	_committed = PackedInt32Array()
