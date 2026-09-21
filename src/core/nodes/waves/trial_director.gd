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

const LABEL_FONT: Font = preload("res://assets/fonts/beholden/Beholden-Medium.ttf")
const CARD_SIZE := Vector2(286.0, 96.0)
const CARD_MARGIN := Vector2(18.0, 18.0)
const BACKING := Color(0.09, 0.102, 0.082, 0.93)
const BORDER_HOLDING := Color(0.769, 0.604, 0.314, 1.0)
const BORDER_BROKEN := Color(0.43, 0.215, 0.305, 1.0)
const BORDER_WON := Color(0.467, 1.0, 0.816, 1.0)
const TEXT := Color(0.91, 0.875, 0.784, 1.0)
const MUTED := Color(0.663, 0.69, 0.608, 1.0)
## How often the continuous rules are judged. Four times a second is far finer than
## anything a player can react to and far coarser than a frame, so a Trial cannot be
## failed by a single unlucky physics step.
const EVALUATION_SECONDS := 0.25

enum State {
	NONE,
	ACTIVE,
	BROKEN,
	WON,
}

var territory_field: TerritoryField
var player: Player

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


func setup(field: TerritoryField, run_player: Player) -> void:
	territory_field = field
	player = run_player
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func reset_trials() -> void:
	_state = State.NONE
	_trial_id = -1
	_tally = 0
	_since_evaluation = 0.0
	_has_marked_region = false
	queue_redraw()


func begin_trial(trial_id: int) -> void:
	## Starts a Trial, capturing whatever the rule will be judged against.
	##
	## An unanswered Trial is abandoned rather than failed if one is somehow still
	## live: a Trial that ran past its wave has lost its meaning either way, and
	## failing it would pay the player nothing while telling them they lost something.
	if territory_field == null:
		return
	_trial_id = trial_id
	_state = State.ACTIVE
	_tally = 0
	_since_evaluation = 0.0
	_opening_green = territory_field.get_player_percent()
	_has_marked_region = false
	if TrialCatalog.is_marked_region_trial(trial_id):
		_marked_region = _choose_marked_region()
		_has_marked_region = true
	trial_started.emit(trial_id)
	queue_redraw()


func advance(delta: float) -> void:
	if _state != State.ACTIVE or delta <= 0.0:
		return
	_since_evaluation += delta
	if _since_evaluation < EVALUATION_SECONDS:
		return
	_since_evaluation = 0.0
	if TrialCatalog.get_judgement(_trial_id) != TrialCatalog.Judgement.CONTINUOUS:
		queue_redraw()
		return
	if not _continuous_rule_holds():
		_break_trial()
	queue_redraw()


func resolve_trial() -> void:
	## Called at the wave boundary that ends the Trial. A rule that was never broken
	## and is answered at the end is judged here; everything else already knows.
	if _state == State.NONE:
		return
	if _state == State.ACTIVE:
		_state = State.WON if _final_rule_holds() else State.BROKEN
	var success := _state == State.WON
	trial_resolved.emit(_trial_id, success)
	queue_redraw()


func note_kill() -> void:
	## Reported by the run. Only Patience counts them, but the report is unconditional
	## so the run does not have to know which Trial is live.
	if _state != State.ACTIVE or _trial_id != TrialCatalog.Id.PATIENCE:
		return
	_tally += 1
	if float(_tally) > TrialCatalog.get_value(_trial_id):
		_break_trial()


func note_damage_taken() -> void:
	if _state != State.ACTIVE or _trial_id != TrialCatalog.Id.UNTOUCHED:
		return
	_break_trial()


func is_active() -> bool:
	return _state == State.ACTIVE


func get_trial_id() -> int:
	return _trial_id


func get_state() -> int:
	return _state


func get_progress_text() -> String:
	## The line under the rule. A continuous rule can only say whether it still holds;
	## a tally can say how much room is left, which is the number the player is
	## actually managing.
	match _state:
		State.BROKEN:
			return "BROKEN"
		State.WON:
			return "HELD"
	match _trial_id:
		TrialCatalog.Id.PATIENCE:
			return "%d of %d" % [_tally, roundi(TrialCatalog.get_value(_trial_id))]
		TrialCatalog.Id.RECLAMATION:
			var gained := territory_field.get_player_percent() - _opening_green
			return "%+.1f of %+.0f points" % [
				gained, TrialCatalog.get_value(_trial_id)
			]
		TrialCatalog.Id.HIGH_WATER:
			return "%.1f%% held" % territory_field.get_player_percent()
		TrialCatalog.Id.LAST_GARDEN:
			return "%.0f%% of the marked ground" % (_marked_region_green() * 100.0)
	return "holding"


func get_marked_region() -> Vector2:
	return _marked_region


func has_marked_region() -> bool:
	return _has_marked_region and _state == State.ACTIVE


func _break_trial() -> void:
	if _state != State.ACTIVE:
		return
	_state = State.BROKEN
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
				>= TrialCatalog.get_value(_trial_id)
			)
		TrialCatalog.Id.LAST_GARDEN:
			return (
				_marked_region_green() * 100.0
				>= TrialCatalog.get_value(_trial_id)
			)
	# Untouched has no state to sample: it is broken by an event or not at all.
	return true


func _final_rule_holds() -> bool:
	if _trial_id == TrialCatalog.Id.RECLAMATION:
		return (
			territory_field.get_player_percent() - _opening_green
			>= TrialCatalog.get_value(_trial_id)
		)
	# Everything else survived its own judgement to get here.
	return true


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
	if _state == State.NONE or _trial_id < 0:
		return
	var origin := Vector2(
		size.x - CARD_SIZE.x - CARD_MARGIN.x,
		CARD_MARGIN.y
	)
	var card := Rect2(origin, CARD_SIZE)
	draw_rect(card, BACKING, true)
	var border := BORDER_HOLDING
	if _state == State.BROKEN:
		border = BORDER_BROKEN
	elif _state == State.WON:
		border = BORDER_WON
	draw_rect(card, border, false, 2.0)
	var heading := TrialCatalog.get_trial_name(_trial_id)
	draw_string(
		LABEL_FONT,
		origin + Vector2(14.0, 28.0),
		heading,
		HORIZONTAL_ALIGNMENT_LEFT,
		CARD_SIZE.x - 28.0,
		18,
		border
	)
	draw_multiline_string(
		LABEL_FONT,
		origin + Vector2(14.0, 50.0),
		TrialCatalog.get_rule(_trial_id),
		HORIZONTAL_ALIGNMENT_LEFT,
		CARD_SIZE.x - 28.0,
		13,
		2,
		TEXT if _state != State.BROKEN else MUTED
	)
	draw_string(
		LABEL_FONT,
		origin + Vector2(14.0, CARD_SIZE.y - 12.0),
		get_progress_text(),
		HORIZONTAL_ALIGNMENT_LEFT,
		CARD_SIZE.x - 28.0,
		12,
		MUTED
	)


## What a save has to carry: which Trial is live, how it is doing, and the two things
## it is being judged against. The card rebuilds itself from these.
func capture_state() -> Dictionary:
	return {
		"state": _state,
		"trial_id": _trial_id,
		"tally": _tally,
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
	_opening_green = float(state.get("opening_green", 0.0))
	_marked_region = state.get("marked_region", Vector2.ZERO)
	_has_marked_region = bool(state.get("has_marked_region", false))
	queue_redraw()
