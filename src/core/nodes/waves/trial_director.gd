class_name TrialDirector
extends Control

## One Trial at a time: the rule, whether it still holds, and the card that says so.
##
## A Trial runs for exactly one wave. It is offered at a wave boundary, watched for
## the minute, and answered at the next boundary. Nothing about it is compulsory and
## nothing is taken away for breaking it -- a broken Trial simply stops being worth
## anything, which is how Die in the Dungeon handles a failed challenge and is what
## §27 asks for when it says failure "should not necessarily end the run".
##
## The card is the other half of the design. A rule the player cannot see is a rule
## they are not playing around, so it sits on screen for the whole wave with its
## state on it, rather than being announced once in a banner and then remembered.
##
## This is a prototype. What it does not do yet, deliberately:
##
## - Only one Trial is ever live. Into the Breach runs up to three bonus objectives
##   per mission and scales the mission's threat with how many it carries, which is
##   the better shape and needs the wave table to know about it.
## - Nothing is offered or declined. The wave table decides, the player answers.
## - The reward is a relic, always. §27 lists five kinds and picking between them is
##   a design question, not a prototype one.

signal trial_started(trial_id: int)
## Answered, one way or the other. `success` is what decides whether a reward is owed.
signal trial_resolved(trial_id: int, success: bool)
## The player pressed the card to take what a held Trial owes them.
##
## A held Trial used to pay itself at the wave boundary, into a reward queue that a
## boundary is already the busiest moment of -- so a relic the player had earned could
## sit behind a draft and never be seen. Claiming is explicit now: the card says the
## reward is there, and it waits until it is asked for.
signal reward_claimed(trial_id: int)
## The rule broke mid-wave. Announced the moment it happens, so the player learns it on
## the battlefield rather than at the next boundary.
signal trial_broken(trial_id: int)
## A goal was reached before the wave ended. Done is done; it still pays at the boundary.
signal trial_completed(trial_id: int)

const LABEL_FONT: Font = preload("res://assets/fonts/beholden/Beholden-Medium.ttf")
## The card is a plaque rather than a line of status text, built the way Die in the
## Dungeon builds a challenge: the word TRIAL on a tab above the frame, the rule in
## the middle written as a sentence, what holding it is worth stated underneath, and
## how it is going along the bottom. The shape is the point. A challenge that looks
## like an object the wave handed you is one the player plays around; the same words
## set in a row of HUD text read as a log entry and get ignored.
const TAB_HEIGHT := 22.0
## How far the tab sinks into the frame, so the two read as one plaque rather than as
## a label resting on a box.
const TAB_OVERLAP := 6.0
const PADDING := 13.0
const TITLE_FONT_SIZE := 16
const TAB_FONT_SIZE := 10
## The rule is the one line read mid-fight, so it is the largest thing on the card
## after the name.
const RULE_FONT_SIZE := 14
const STATE_FONT_SIZE := 11
const STRIP_HEIGHT := 20.0
const CORNER_RADIUS := 7
const BACKING := Color(0.106, 0.114, 0.094, 0.96)
const SHADOW := Color(0.0, 0.0, 0.0, 0.32)
## The tab carries the accent as a fill, so the word on it is written in the dark the
## rest of the card is made of.
const TAB_TEXT := Color(0.086, 0.094, 0.078, 1.0)
const BORDER_HOLDING := Color(0.769, 0.604, 0.314, 1.0)
const BORDER_BROKEN := Color(0.43, 0.215, 0.305, 1.0)
const BORDER_WON := Color(0.467, 1.0, 0.816, 1.0)
const TEXT := Color(0.91, 0.875, 0.784, 1.0)
const MUTED := Color(0.663, 0.69, 0.608, 1.0)
## What the strip says once the Trial is held and the reward is waiting to be taken.
const CLAIM_TEXT := "REAP YOUR REWARD"
## How often the continuous rules are judged. Four times a second is far finer than
## anything a player can react to and far coarser than a frame, so a Trial cannot be
## failed by a single unlucky physics step.
const EVALUATION_SECONDS := 0.25
## How long a broken card flashes before it leaves the panel. A broken Trial is worth
## nothing for the rest of the wave, so the card says so once and gets out of the way.
const BREAK_FLASH_SECONDS := 0.9
const BREAK_FLASH_COUNT := 2
const BREAK_FLASH := Color(0.95, 0.18, 0.16, 1.0)
## Pulses per second on the claim strip while a reward waits.
const CLAIM_PULSE_RATE := 1.4
## Seconds after a Trial is handed out before anything is judged. The card counts it
## down. Without it a rule about where to stand was judged a quarter of a second after
## it appeared, so it broke on wherever the player happened to be when the wave turned.
const ARMING_SECONDS := 4.0
## Momentum: how far Grandma has to have moved across the last few evaluations to count
## as moving. Three samples at a quarter of a second each is three quarters of a second.
const MOMENTUM_SAMPLES := 3
const MOMENTUM_DISTANCE := 28.0
## How long a counted event (a hit, a Canker) is announced over Grandma.
const CUE_FLASH_SECONDS := 1.4
## Colour of a live rule that is draining its slack, on the card and over Grandma.
const DRAINING := Color(0.93, 0.42, 0.33, 1.0)

enum State {
	NONE,
	ACTIVE,
	BROKEN,
	WON,
}

var territory_field: TerritoryField
var player: Player
## The board, for the rules that are about what is standing on it rather than about
## the ground. Optional: a Trial with no combat director to ask simply holds.
var combat: CombatDirector

var _state := State.NONE
var _trial_id := -1
var _since_evaluation := 0.0
## What the rule is measured against, captured when the Trial starts: Reclamation
## needs the Green it began with, Last Garden needs the ground it marked.
var _opening_green := 0.0
var _marked_region := Vector2.ZERO
var _has_marked_region := false
## Tally rules count here. Kills are reported in rather than read off the combat
## director, because what a Trial counts is what the run told it happened.
var _tally := 0
## Seconds since the Trial began, which is what Stillness' opening window is measured
## against. Kept here rather than read off the wave director because a Trial starts
## when it is begun, and a provoked wave does not start its clock where the last one
## left off.
var _elapsed := 0.0
## The wave this Trial was offered on. Three of the rules state a number that grows
## with the wave, so the card cannot print its own sentence without it, and neither
## can the rule judge itself. Captured at the start and carried through the save,
## because a continued run must be judged by the card it was shown.
var _wave_number := TrialCatalog.SCALING_REFERENCE_WAVE
## Whether a held Trial is still owed to the player. The card's bottom strip becomes a
## button while this is true, and nothing pays out until it is pressed.
var _reward_unclaimed := false
## Seconds left on the broken card's flash, and whether the card has left the panel.
## Hidden is a matter of drawing only: a broken Last Garden keeps its state, because
## its red ring on the arena is how the player sees which ground they lost.
var _flash_remaining := 0.0
var _hidden := false
var _pulse_phase := 0.0
## Seconds before the rule starts being judged. See `ARMING_SECONDS`.
var _arming_remaining := 0.0
## What is left of a CONTINUOUS rule's allowance, and whether it is draining right now.
var _slack_remaining := 0.0
var _violating := false
## Frenzy: kill times inside the window, and the most the window has held.
var _kill_times: Array[float] = []
var _best_burst := 0
## Momentum: where Grandma was at the last few evaluations.
var _recent_positions: Array[Vector2] = []
## A counted event just happened and is being shown over Grandma.
var _cue_flash_remaining := 0.0
## An outcome -- broken, done, held -- announced over Grandma for a moment. It outlives
## the ACTIVE state on purpose: the announcement is of the Trial ending.
var _event_text := ""
## The number a board-measured rule settled on when it began, or -1 for a rule whose
## number is the catalog's. Kept rather than re-measured, because the card has to go on
## saying the number the player was shown.
var _settled_value := -1.0
var _event_remaining := 0.0
const EVENT_SECONDS := 2.0
## Built once and coloured per state at draw time. The card redraws four times a
## second, which is no reason to allocate five style boxes four times a second.
var _panel_style: StyleBoxFlat
var _shadow_style: StyleBoxFlat
var _inset_style: StyleBoxFlat
var _tab_style: StyleBoxFlat
var _strip_style: StyleBoxFlat


func setup(
	field: TerritoryField, run_player: Player, combat_director: CombatDirector = null
) -> void:
	territory_field = field
	player = run_player
	combat = combat_director
	_set_claimable(false)


## Whether the card is standing in for a real Trial. An example is drawn and never
## judged: the intro note needs a card on the panel to point at, and a note that
## started a Trial would be paying out a relic for reading it.
var _example := false


func show_example(trial_id: int, wave_number: int) -> void:
	_trial_id = trial_id
	_wave_number = wave_number
	_state = State.ACTIVE
	_tally = 0
	_elapsed = 0.0
	_reward_unclaimed = false
	_has_marked_region = false
	_flash_remaining = 0.0
	_hidden = false
	_arming_remaining = 0.0
	_slack_remaining = TrialCatalog.get_slack(trial_id)
	_violating = false
	_example = true
	tooltip_text = TrialCatalog.get_detail(trial_id, wave_number)
	_set_claimable(false)
	_resize_card()
	queue_redraw()


func clear_example() -> void:
	if not _example:
		return
	_example = false
	reset_trials()


func is_reward_unclaimed() -> bool:
	return _reward_unclaimed


func _set_claimable(claimable: bool) -> void:
	# Passing rather than ignoring while there is nothing to press, so the card still
	# answers a hover with its tooltip -- the whole rule lives there now.
	mouse_filter = (
		Control.MOUSE_FILTER_STOP if claimable else Control.MOUSE_FILTER_PASS
	)


func _process(delta: float) -> void:
	if _flash_remaining > 0.0:
		_flash_remaining -= delta
		if _flash_remaining <= 0.0:
			_flash_remaining = 0.0
			_hidden = true
		queue_redraw()
	if _reward_unclaimed and not _hidden:
		_pulse_phase = fmod(_pulse_phase + delta * CLAIM_PULSE_RATE, 1.0)
		queue_redraw()


## Flashes the card red, then takes it off the panel.
func _begin_break_flash() -> void:
	if _example or _hidden:
		return
	_flash_remaining = BREAK_FLASH_SECONDS
	queue_redraw()


## Clears a claimed card. Nothing is left for it to say.
func _dismiss() -> void:
	_state = State.NONE
	_trial_id = -1
	_has_marked_region = false
	_flash_remaining = 0.0
	_hidden = false
	queue_redraw()


func is_card_shown() -> bool:
	return _state != State.NONE and _trial_id >= 0 and not _hidden


func _gui_input(event: InputEvent) -> void:
	if not _reward_unclaimed:
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _strip_rect().has_point(click.position):
		return
	var claimed := _trial_id
	_reward_unclaimed = false
	_set_claimable(false)
	accept_event()
	reward_claimed.emit(claimed)
	_dismiss()


func reset_trials() -> void:
	_reward_unclaimed = false
	_set_claimable(false)
	_example = false
	_state = State.NONE
	_trial_id = -1
	_tally = 0
	_elapsed = 0.0
	_since_evaluation = 0.0
	_has_marked_region = false
	_flash_remaining = 0.0
	_hidden = false
	_pulse_phase = 0.0
	_arming_remaining = 0.0
	_violating = false
	_kill_times.clear()
	_best_burst = 0
	_recent_positions.clear()
	_cue_flash_remaining = 0.0
	_event_remaining = 0.0
	_settled_value = -1.0
	tooltip_text = ""
	queue_redraw()


func begin_trial(
	trial_id: int, wave_number := TrialCatalog.SCALING_REFERENCE_WAVE
) -> void:
	## Starts a Trial, capturing whatever the rule will be judged against.
	##
	## An unanswered Trial is abandoned rather than failed if one is somehow still
	## live: a Trial that ran past its wave has lost its meaning either way, and
	## failing it would pay the player nothing while telling them they lost something.
	if territory_field == null:
		return
	_trial_id = trial_id
	_wave_number = wave_number
	_state = State.ACTIVE
	_flash_remaining = 0.0
	_hidden = false
	_pulse_phase = 0.0
	_arming_remaining = ARMING_SECONDS
	_slack_remaining = TrialCatalog.get_slack(trial_id)
	_violating = false
	_kill_times.clear()
	_best_burst = 0
	_recent_positions.clear()
	_cue_flash_remaining = 0.0
	_settled_value = -1.0
	if TrialCatalog.get_board_share(trial_id) > 0.0:
		_settled_value = TrialCatalog.get_value_for_board(trial_id, wave_number, _standing())
	tooltip_text = TrialCatalog.get_detail(trial_id, wave_number, _value())
	_tally = 0
	_elapsed = 0.0
	_since_evaluation = 0.0
	_opening_green = territory_field.get_player_percent()
	_has_marked_region = false
	if TrialCatalog.is_marked_region_trial(trial_id):
		_marked_region = _choose_marked_region()
		_has_marked_region = true
	_resize_card()
	trial_started.emit(trial_id)
	queue_redraw()


func advance(delta: float) -> void:
	if _example:
		# An example is a picture of a card, not a rule. Nothing about it is judged, so
		# it cannot be broken by whatever the board happens to be doing behind the note.
		return
	_cue_flash_remaining = maxf(0.0, _cue_flash_remaining - delta)
	_event_remaining = maxf(0.0, _event_remaining - delta)
	if _state != State.ACTIVE or delta <= 0.0:
		return
	_elapsed += delta
	if _arming_remaining > 0.0:
		_arming_remaining = maxf(0.0, _arming_remaining - delta)
		queue_redraw()
		return
	_since_evaluation += delta
	if _since_evaluation < EVALUATION_SECONDS:
		return
	var step := _since_evaluation
	_since_evaluation = 0.0
	if player != null:
		_recent_positions.append(player.get_arena_position())
		while _recent_positions.size() > MOMENTUM_SAMPLES + 1:
			_recent_positions.remove_at(0)
	if TrialCatalog.get_judgement(_trial_id) == TrialCatalog.Judgement.CONTINUOUS:
		# Breaking the rule costs slack rather than the Trial. Only running the slack
		# out ends it, so a step off the Green is a thing to recover from.
		_violating = not _continuous_rule_holds()
		if _violating:
			_slack_remaining = maxf(0.0, _slack_remaining - step)
			if _slack_remaining <= 0.0:
				_break_trial()
	queue_redraw()


func resolve_trial() -> void:
	## Called at the wave boundary that ends the Trial. A rule that was never broken
	## and is answered at the end is judged here; everything else already knows.
	if _state == State.NONE:
		return
	if _state == State.ACTIVE:
		_state = State.WON if _final_rule_holds() else State.BROKEN
		if _state == State.BROKEN:
			_begin_break_flash()
	var success := _state == State.WON
	if success:
		_announce("RELIC READY")
	_reward_unclaimed = success
	_set_claimable(success)
	trial_resolved.emit(_trial_id, success)
	_resize_card()
	queue_redraw()


func note_kill(death_source: int = -1) -> void:
	## Reported by the run with what landed the killing blow: Frenzy counts how close
	## together kills land, and Groundwork counts only the Cane's.
	if _state != State.ACTIVE or _arming_remaining > 0.0:
		return
	match _trial_id:
		TrialCatalog.Id.FRENZY:
			var window := TrialCatalog.get_burst_window(_trial_id)
			_kill_times.append(_elapsed)
			while not _kill_times.is_empty() and _kill_times[0] < _elapsed - window:
				_kill_times.remove_at(0)
			_best_burst = maxi(_best_burst, _kill_times.size())
			if float(_kill_times.size()) >= _value():
				_complete_trial()
		TrialCatalog.Id.GROUNDWORK:
			if death_source == CombatDirector.DeathSource.CANE:
				_tally += 1
				if float(_tally) >= _value():
					_complete_trial()


func note_canker_formed() -> void:
	## A warning ring that finished entrenching. Clean Ground allows none.
	if _state != State.ACTIVE or _trial_id != TrialCatalog.Id.CLEAN_GROUND:
		return
	if _arming_remaining > 0.0:
		return
	_count_event()


func note_damage_taken() -> void:
	if _state != State.ACTIVE or _trial_id != TrialCatalog.Id.UNTOUCHED:
		return
	if _arming_remaining > 0.0:
		return
	_count_event()


## One more of what a COUNTED rule allows, shown over Grandma, and the Trial broken if
## that was one too many.
func _count_event() -> void:
	_tally += 1
	_cue_flash_remaining = CUE_FLASH_SECONDS
	if float(_tally) > _value():
		_break_trial()
	queue_redraw()


## What the rule allows or asks for on this Trial: the settled number when there is
## one, and the catalog's for this wave otherwise.
func _value() -> float:
	if _settled_value >= 0.0:
		return _settled_value
	return TrialCatalog.get_value(_trial_id, _wave_number)


func _complete_trial() -> void:
	if _state != State.ACTIVE:
		return
	_state = State.WON
	_announce("TRIAL DONE")
	trial_completed.emit(_trial_id)
	queue_redraw()


## What to say over Grandma right now, or empty for nothing.
##
## Reading the card means looking away from the fight, so the moments that matter are
## told where the player is already looking: a live rule draining its slack, a hit or a
## Canker counted against the allowance, and a Frenzy building toward its number.
func _announce(text: String) -> void:
	if _example:
		return
	_event_text = text
	_event_remaining = EVENT_SECONDS


func get_world_cue() -> Dictionary:
	if _example:
		return {}
	if _event_remaining > 0.0:
		return {
			"text": _event_text,
			"fraction": _event_remaining / EVENT_SECONDS,
			"urgent": _event_text == "TRIAL BROKEN",
		}
	if _state != State.ACTIVE:
		return {}
	if _arming_remaining > 0.0:
		# The rule itself, over Grandma, with a ring filling toward the moment it starts
		# counting: the whole of the Trial's introduction, given where she is looking.
		return {
			"text": TrialCatalog.get_rule(_trial_id, _wave_number, _value()).to_upper(),
			"fraction": 1.0 - _arming_remaining / ARMING_SECONDS,
			"urgent": false,
		}
	var value := _value()
	match TrialCatalog.get_judgement(_trial_id):
		TrialCatalog.Judgement.CONTINUOUS:
			if not _violating:
				return {}
			var slack := maxf(0.01, TrialCatalog.get_slack(_trial_id))
			return {
				"text": TrialCatalog.get_warning(_trial_id),
				"fraction": _slack_remaining / slack,
				"urgent": true,
			}
		TrialCatalog.Judgement.COUNTED:
			if _cue_flash_remaining <= 0.0:
				return {}
			var left := maxi(0, roundi(value) - _tally)
			var text := TrialCatalog.get_warning(_trial_id)
			if _trial_id == TrialCatalog.Id.UNTOUCHED:
				text = "%d %s LEFT" % [left, "HIT" if left == 1 else "HITS"]
			return {
				"text": text,
				"fraction": float(left) / maxf(1.0, value),
				"urgent": true,
			}
	if _trial_id == TrialCatalog.Id.FRENZY and _kill_times.size() >= 3:
		return {
			"text": "%d / %d" % [_kill_times.size(), roundi(value)],
			"fraction": float(_kill_times.size()) / maxf(1.0, value),
			"urgent": false,
		}
	return {}


func is_active() -> bool:
	return _state == State.ACTIVE


func get_trial_id() -> int:
	return _trial_id


func get_wave_number() -> int:
	return _wave_number


func get_state() -> int:
	return _state


func get_progress_text() -> String:
	## The strip along the bottom of the card: a few characters that say how the rule
	## is going, never a sentence.
	match _state:
		State.BROKEN:
			return "BROKEN"
		State.WON:
			return "DONE"
	if _arming_remaining > 0.0:
		return "STARTS IN %d" % ceili(_arming_remaining)
	var value := _value()
	if _violating:
		return "%s  %.1fs" % [TrialCatalog.get_warning(_trial_id), _slack_remaining]
	match _trial_id:
		TrialCatalog.Id.UNTOUCHED:
			var left := maxi(0, roundi(value) - _tally)
			return "%d %s LEFT" % [left, "HIT" if left == 1 else "HITS"]
		TrialCatalog.Id.FRENZY:
			return "BEST %d / %d" % [_best_burst, roundi(value)]
		TrialCatalog.Id.RECLAMATION:
			var gained := territory_field.get_player_percent() - _opening_green
			return "%+.1f%% / +%d%%" % [gained, roundi(value)]
		TrialCatalog.Id.HIGH_WATER:
			return "%.0f%% / %d%%" % [territory_field.get_player_percent(), roundi(value)]
		TrialCatalog.Id.LAST_GARDEN:
			return "RING %.0f%%" % (_marked_region_green() * 100.0)
		TrialCatalog.Id.PRESSURE:
			return "%d / %d" % [
				combat.get_active_enemy_count() if combat != null else 0, roundi(value)
			]
		TrialCatalog.Id.CLEAN_GROUND:
			return "NO CANKER"
		TrialCatalog.Id.THE_CULL:
			return "%d STANDING" % _standing()
		TrialCatalog.Id.GROUNDWORK:
			return "%d / %d" % [_tally, roundi(value)]
	return "HOLDING"


func get_marked_region() -> Vector2:
	return _marked_region


func has_marked_region() -> bool:
	## Still worth drawing once the rule has been broken: the ring turning red is how
	## the player finds out which ground they lost. The run clears it at the wave
	## boundary, so a dead Trial's mark never outlives the wave it belonged to.
	return _has_marked_region and _state != State.NONE


func _break_trial() -> void:
	if _state != State.ACTIVE:
		return
	_state = State.BROKEN
	_violating = false
	_announce("TRIAL BROKEN")
	_begin_break_flash()
	trial_broken.emit(_trial_id)
	queue_redraw()


func _continuous_rule_holds() -> bool:
	match _trial_id:
		TrialCatalog.Id.ROOTED:
			if player == null:
				return true
			return (
				territory_field.get_control_at_local(player.get_arena_position())
				> territory_field.tuning.ownership_threshold
			)
		TrialCatalog.Id.HIGH_WATER:
			return (
				territory_field.get_player_percent()
				>= _value()
			)
		TrialCatalog.Id.LAST_GARDEN:
			return (
				_marked_region_green() * 100.0
				>= _value()
			)
		TrialCatalog.Id.PRESSURE:
			if combat == null:
				return true
			return (
				float(combat.get_active_enemy_count())
				<= _value()
			)
		TrialCatalog.Id.MOMENTUM:
			if _recent_positions.size() <= MOMENTUM_SAMPLES:
				return true
			return (
				_recent_positions[0].distance_to(_recent_positions[-1])
				>= MOMENTUM_DISTANCE
			)
		TrialCatalog.Id.FRONTIER:
			# Rooted's own test, read the other way round.
			if player == null:
				return true
			return (
				territory_field.get_control_at_local(player.get_arena_position())
				<= territory_field.tuning.ownership_threshold
			)
	return true


func _final_rule_holds() -> bool:
	match _trial_id:
		TrialCatalog.Id.RECLAMATION:
			return (
				territory_field.get_player_percent() - _opening_green
				>= _value()
			)
		TrialCatalog.Id.THE_CULL:
			return float(_standing()) <= _value()
	# A goal still ACTIVE at the boundary was never reached; every other rule survived
	# its own judgement to get here.
	return TrialCatalog.get_judgement(_trial_id) != TrialCatalog.Judgement.GOAL


func _standing() -> int:
	## What The Cull is judged on: everything the wave still has on the board.
	return combat.get_active_enemy_count() if combat != null else 0


func _marked_region_green() -> float:
	## Share of the marked circle the run currently owns, sampled on the field's own
	## cells rather than on a grid of guesses, so the number the card prints is the
	## number the simulation would agree with.
	if not _has_marked_region:
		return 0.0
	var owned := 0
	var counted := 0
	var radius_squared := (
		TrialCatalog.MARKED_REGION_RADIUS * TrialCatalog.MARKED_REGION_RADIUS
	)
	for index in range(territory_field.get_cell_count()):
		var position := territory_field.get_cell_local_position(index)
		if position.distance_squared_to(_marked_region) > radius_squared:
			continue
		counted += 1
		if territory_field.is_owned_cell(index):
			owned += 1
	if counted <= 0:
		return 0.0
	return float(owned) / float(counted)


func _choose_marked_region() -> Vector2:
	## Ground worth defending and not already safe: the owned cell furthest from
	## Grandma. Marking where she is standing would ask for nothing; marking bare Rot
	## would ask for a reclaim rather than a hold, which is Reclamation's job.
	var origin := (
		player.get_arena_position()
		if player != null
		else territory_field.tuning.arena_size * 0.5
	)
	var best := territory_field.tuning.arena_size * 0.5
	var best_distance := -1.0
	for index in range(territory_field.get_cell_count()):
		if not territory_field.is_owned_cell(index):
			continue
		var position := territory_field.get_cell_local_position(index)
		var distance := position.distance_squared_to(origin)
		if distance > best_distance:
			best_distance = distance
			best = position
	return best


func _draw() -> void:
	## The plaque, drawn in one pass from the top down.
	##
	## Everything is measured off the font rather than off a table of magic offsets,
	## so a rule that wraps to three lines pushes the reward and the state strip down
	## instead of printing over them. `_resize_card` walks the same layout and is what
	## the node is sized to.
	if not is_card_shown():
		return
	_ensure_styles()
	var accent := _accent()
	var flash := _break_flash_strength()
	if flash > 0.0:
		accent = accent.lerp(BREAK_FLASH, flash)
	var body := Rect2(
		Vector2(0.0, TAB_HEIGHT - TAB_OVERLAP),
		Vector2(size.x, maxf(size.y - (TAB_HEIGHT - TAB_OVERLAP), 1.0))
	)
	_shadow_style.bg_color = SHADOW
	draw_style_box(_shadow_style, Rect2(body.position + Vector2(0.0, 3.0), body.size))
	_panel_style.bg_color = BACKING
	_panel_style.border_color = accent
	draw_style_box(_panel_style, body)
	# The second frame the reference draws just inside the first. It is what stops a
	# dark panel with a bright edge from reading as a tooltip.
	_inset_style.border_color = Color(accent.r, accent.g, accent.b, 0.28)
	draw_style_box(_inset_style, body.grow(-5.0))
	_draw_tab(accent)

	# Three things and no more: what it is called, the five words of the rule, and how
	# it is going. The whole rule is the tooltip, for the player who stops to read it;
	# the one mid-fight gets a glance's worth.
	var broken := _state == State.BROKEN
	var cursor := body.position.y + 10.0
	cursor = _draw_centered(
		TrialCatalog.get_trial_name(_trial_id), TITLE_FONT_SIZE, MUTED if broken else accent, cursor
	) + 4.0
	cursor = _draw_wrapped(
		TrialCatalog.get_rule(_trial_id, _wave_number, _value()),
		RULE_FONT_SIZE,
		MUTED if broken else TEXT,
		cursor
	) + 8.0
	_draw_state_strip(cursor, DRAINING if _violating else accent)
	if flash > 0.0:
		draw_rect(body, Color(BREAK_FLASH.r, BREAK_FLASH.g, BREAK_FLASH.b, 0.45 * flash), true)


## 0 to 1: how red the card is at this moment of its break flash. Blinks rather than
## fading, so it reads as an alarm rather than as the card dimming.
func _break_flash_strength() -> float:
	if _flash_remaining <= 0.0:
		return 0.0
	var progress := 1.0 - _flash_remaining / BREAK_FLASH_SECONDS
	return 0.5 - 0.5 * cos(progress * TAU * BREAK_FLASH_COUNT)


func _draw_tab(accent: Color) -> void:
	## Drawn after the frame so it sits on top of the border it overlaps.
	# The reward rides on the tab rather than on a line of its own: a Trial always pays
	# a relic, and saying so costs one word where it used to cost two lines.
	var label := "TRIAL · RELIC"
	var width := (
		LABEL_FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, TAB_FONT_SIZE).x
		+ 30.0
	)
	var tab := Rect2(Vector2((size.x - width) * 0.5, 0.0), Vector2(width, TAB_HEIGHT))
	_tab_style.bg_color = accent
	draw_style_box(_tab_style, tab)
	draw_string(
		LABEL_FONT,
		Vector2(tab.position.x, LABEL_FONT.get_ascent(TAB_FONT_SIZE) + 5.0),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		tab.size.x,
		TAB_FONT_SIZE,
		TAB_TEXT
	)


func _draw_centered(text: String, font_size: int, color: Color, top: float) -> float:
	draw_string(
		LABEL_FONT,
		Vector2(PADDING, top + LABEL_FONT.get_ascent(font_size)),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		_inner_width(),
		font_size,
		color
	)
	return top + LABEL_FONT.get_height(font_size)


func _draw_wrapped(text: String, font_size: int, color: Color, top: float) -> float:
	draw_multiline_string(
		LABEL_FONT,
		Vector2(PADDING, top + LABEL_FONT.get_ascent(font_size)),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		_inner_width(),
		font_size,
		-1,
		color
	)
	return top + _wrapped_height(text, font_size)


func _strip_rect() -> Rect2:
	## Where the state strip is drawn, which is also where the claim is pressed. Derived
	## from the card's own height so the two cannot drift: the strip is the last thing
	## laid out, one padding up from the bottom.
	return Rect2(
		Vector2(PADDING, size.y - PADDING - STRIP_HEIGHT),
		Vector2(_inner_width(), STRIP_HEIGHT)
	)


func _draw_state_strip(top: float, accent: Color) -> void:
	## How the Trial is going, on its own strip so the one part of the card that moves
	## while the wave runs is the one part the eye knows where to find.
	var strip := Rect2(Vector2(PADDING, top), Vector2(_inner_width(), STRIP_HEIGHT))
	_strip_style.bg_color = Color(accent.r, accent.g, accent.b, 0.14)
	_strip_style.border_color = Color(accent.r, accent.g, accent.b, 0.5)
	draw_style_box(_strip_style, strip)
	if _reward_unclaimed:
		# Filled rather than outlined, because it is a button now and the rest of the
		# card is not. The wording is an instruction: a strip that said HELD was a
		# statement of fact the player had no reason to touch.
		# It pulses, because a reward that waits on a press has to ask for it.
		var pulse := 0.5 - 0.5 * cos(_pulse_phase * TAU)
		_strip_style.bg_color = Color(accent.r, accent.g, accent.b, lerpf(0.6, 1.0, pulse))
		draw_style_box(_strip_style, strip)
		draw_rect(
			strip.grow(1.0 + 3.0 * pulse),
			Color(accent.r, accent.g, accent.b, 0.7 * (1.0 - pulse)),
			false,
			2.0
		)
		draw_string(
			LABEL_FONT,
			Vector2(
				strip.position.x,
				(
					strip.position.y
					+ (STRIP_HEIGHT - LABEL_FONT.get_height(STATE_FONT_SIZE)) * 0.5
					+ LABEL_FONT.get_ascent(STATE_FONT_SIZE)
				)
			),
			CLAIM_TEXT,
			HORIZONTAL_ALIGNMENT_CENTER,
			strip.size.x,
			STATE_FONT_SIZE,
			TAB_TEXT
		)
		return
	var fraction := _progress_fraction()
	if fraction >= 0.0 and _state == State.ACTIVE:
		# A rule with a number in it gets the number drawn as well as written: the
		# strip fills as the allowance is spent, so how close the Trial is to breaking
		# is readable without stopping to parse "31 of 45".
		var filled := strip.grow(-2.0)
		filled.size.x *= clampf(fraction, 0.0, 1.0)
		draw_rect(filled, Color(accent.r, accent.g, accent.b, 0.22), true)
	draw_string(
		LABEL_FONT,
		Vector2(
			strip.position.x,
			(
				strip.position.y
				+ (STRIP_HEIGHT - LABEL_FONT.get_height(STATE_FONT_SIZE)) * 0.5
				+ LABEL_FONT.get_ascent(STATE_FONT_SIZE)
			)
		),
		get_progress_text().to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER,
		strip.size.x,
		STATE_FONT_SIZE,
		accent
	)


func _progress_fraction() -> float:
	## How full the strip's bar is, or -1 for no bar. For a live rule it is the slack
	## left, so the bar emptying is the rule running out; for a count it is the room
	## left; for a goal it is how close it is.
	if _arming_remaining > 0.0:
		return 1.0 - _arming_remaining / ARMING_SECONDS
	var value := _value()
	match TrialCatalog.get_judgement(_trial_id):
		TrialCatalog.Judgement.CONTINUOUS:
			var slack := TrialCatalog.get_slack(_trial_id)
			return _slack_remaining / slack if slack > 0.0 else -1.0
		TrialCatalog.Judgement.COUNTED:
			if value <= 0.0:
				return -1.0
			return clampf((value - float(_tally)) / value, 0.0, 1.0)
	match _trial_id:
		TrialCatalog.Id.FRENZY:
			return float(_best_burst) / maxf(1.0, value)
		TrialCatalog.Id.GROUNDWORK:
			return float(_tally) / maxf(1.0, value)
		TrialCatalog.Id.RECLAMATION:
			var gained := territory_field.get_player_percent() - _opening_green
			return gained / maxf(0.001, value)
	return -1.0

func _accent() -> Color:
	match _state:
		State.BROKEN:
			return BORDER_BROKEN
		State.WON:
			return BORDER_WON
	return BORDER_HOLDING


func _inner_width() -> float:
	return maxf(size.x - PADDING * 2.0, 1.0)


func _wrapped_height(text: String, font_size: int) -> float:
	return LABEL_FONT.get_multiline_string_size(
		text, HORIZONTAL_ALIGNMENT_CENTER, _inner_width(), font_size
	).y


func _resize_card() -> void:
	## The card is as tall as its rule needs: the name, the rule wrapped to the width
	## the side panel gives it, and the strip. `_draw` walks the same layout.
	if _state == State.NONE or _trial_id < 0:
		return
	size.y = (
		TAB_HEIGHT
		- TAB_OVERLAP
		+ 10.0
		+ LABEL_FONT.get_height(TITLE_FONT_SIZE)
		+ 4.0
		+ _wrapped_height(TrialCatalog.get_rule(_trial_id, _wave_number, _value()), RULE_FONT_SIZE)
		+ 8.0
		+ STRIP_HEIGHT
		+ PADDING
	)

func _ensure_styles() -> void:
	if _panel_style != null:
		return
	_panel_style = StyleBoxFlat.new()
	_panel_style.set_corner_radius_all(CORNER_RADIUS)
	_panel_style.set_border_width_all(2)
	_shadow_style = StyleBoxFlat.new()
	_shadow_style.set_corner_radius_all(CORNER_RADIUS)
	_inset_style = StyleBoxFlat.new()
	_inset_style.draw_center = false
	_inset_style.set_corner_radius_all(maxi(CORNER_RADIUS - 3, 1))
	_inset_style.set_border_width_all(1)
	_tab_style = StyleBoxFlat.new()
	_tab_style.corner_radius_top_left = CORNER_RADIUS
	_tab_style.corner_radius_top_right = CORNER_RADIUS
	_tab_style.corner_radius_bottom_left = 0
	_tab_style.corner_radius_bottom_right = 0
	_strip_style = StyleBoxFlat.new()
	_strip_style.set_corner_radius_all(4)
	_strip_style.set_border_width_all(1)


## What a save has to carry: which Trial is live, how it is doing, and the two things
## it is being judged against. The card rebuilds itself from these.
func capture_state() -> Dictionary:
	return {
		"state": _state,
		"trial_id": _trial_id,
		"tally": _tally,
		"elapsed": _elapsed,
		"wave_number": _wave_number,
		"reward_unclaimed": _reward_unclaimed,
		"arming": _arming_remaining,
		"slack": _slack_remaining,
		"best_burst": _best_burst,
		"settled_value": _settled_value,
		"hidden": _hidden or _flash_remaining > 0.0,
		"opening_green": _opening_green,
		"marked_region": _marked_region,
		"has_marked_region": _has_marked_region,
	}


func apply_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_state = int(state.get("state", State.NONE))
	_trial_id = int(state.get("trial_id", -1))
	_tally = int(state.get("tally", 0))
	_elapsed = float(state.get("elapsed", 0.0))
	_wave_number = int(
		state.get("wave_number", TrialCatalog.SCALING_REFERENCE_WAVE)
	)
	_reward_unclaimed = bool(state.get("reward_unclaimed", false))
	_arming_remaining = float(state.get("arming", 0.0))
	_slack_remaining = float(state.get("slack", TrialCatalog.get_slack(_trial_id)))
	_best_burst = int(state.get("best_burst", 0))
	_settled_value = float(state.get("settled_value", -1.0))
	_violating = false
	tooltip_text = TrialCatalog.get_detail(_trial_id, _wave_number, _value()) if _trial_id >= 0 else ""
	_flash_remaining = 0.0
	_hidden = bool(state.get("hidden", _state == State.BROKEN))
	_set_claimable(_reward_unclaimed)
	_opening_green = float(state.get("opening_green", 0.0))
	_marked_region = state.get("marked_region", Vector2.ZERO)
	_has_marked_region = bool(state.get("has_marked_region", false))
	_resize_card()
	queue_redraw()
