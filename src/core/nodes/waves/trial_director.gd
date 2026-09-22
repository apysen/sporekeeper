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
const RULE_FONT_SIZE := 12
## The line under the rule, which says exactly what breaks it. Smaller and quieter
## than the rule, because it is read once and then remembered.
const FAIL_FONT_SIZE := 10
const REWARD_FONT_SIZE := 12
const SMALL_FONT_SIZE := 9
const STATE_FONT_SIZE := 11
const DIVIDER_HEIGHT := 11.0
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
## What a held Trial is worth: the run's ordinary relic offer, rolled from the whole
## pool rather than from anything an elite would have dropped. Stated in one line,
## because a reward the card has to explain is a reward the player will not weigh
## against the risk of playing to the rule. The lead-in above it is each Trial's own,
## and lives in the catalog beside the rule it belongs to.
const REWARD_TEXT := "A RELIC REWARD"
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
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func reset_trials() -> void:
	_state = State.NONE
	_trial_id = -1
	_tally = 0
	_elapsed = 0.0
	_since_evaluation = 0.0
	_has_marked_region = false
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
	if _state != State.ACTIVE or delta <= 0.0:
		return
	_elapsed += delta
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


func note_kill(death_source: int = -1) -> void:
	## Reported by the run, with what landed the killing blow, because three of the
	## rules care about a kill and each cares about a different thing: Patience counts
	## them, Stillness cares when one happened, and Groundwork cares what did it. The
	## report stays unconditional so the run does not have to know which Trial is live.
	if _state != State.ACTIVE:
		return
	match _trial_id:
		TrialCatalog.Id.PATIENCE:
			_tally += 1
			if float(_tally) > TrialCatalog.get_value(_trial_id, _wave_number):
				_break_trial()
		TrialCatalog.Id.STILLNESS:
			if _elapsed < TrialCatalog.get_value(_trial_id, _wave_number):
				_break_trial()
		TrialCatalog.Id.GROUNDWORK:
			# Only the Cane's own swings. Everything else on the roster is the run
			# answering the wave from somewhere else, which is what this rule is
			# asking the player to stop doing for a minute.
			if death_source == CombatDirector.DeathSource.CANE:
				_tally += 1


func note_canker_formed() -> void:
	## A warning ring that finished entrenching. Clean Ground is the only rule that
	## watches for one, and it allows none.
	if _state != State.ACTIVE or _trial_id != TrialCatalog.Id.CLEAN_GROUND:
		return
	_tally += 1
	if float(_tally) > TrialCatalog.get_value(_trial_id, _wave_number):
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
			return "%d of %d kills" % [
				_tally, roundi(TrialCatalog.get_value(_trial_id, _wave_number))
			]
		TrialCatalog.Id.RECLAMATION:
			var gained := territory_field.get_player_percent() - _opening_green
			return "%+.1f%% — need %+.0f%%" % [
				gained, TrialCatalog.get_value(_trial_id, _wave_number)
			]
		TrialCatalog.Id.HIGH_WATER:
			return "%.1f%% — need %.0f%%" % [
				territory_field.get_player_percent(),
				TrialCatalog.get_value(_trial_id, _wave_number),
			]
		TrialCatalog.Id.LAST_GARDEN:
			return "ring %.0f%% — need %.0f%%" % [
				_marked_region_green() * 100.0, TrialCatalog.get_value(_trial_id, _wave_number)
			]
		TrialCatalog.Id.STILLNESS:
			var left := TrialCatalog.get_value(_trial_id, _wave_number) - _elapsed
			return "%.0fs of stillness left" % left if left > 0.0 else "window held"
		TrialCatalog.Id.PRESSURE:
			return "%d of %d standing" % [
				combat.get_active_enemy_count() if combat != null else 0,
				roundi(TrialCatalog.get_value(_trial_id, _wave_number)),
			]
		TrialCatalog.Id.CLEAN_GROUND:
			return "no Canker yet" if _tally <= 0 else "%d formed" % _tally
		TrialCatalog.Id.THE_CULL:
			var standing := _standing()
			return "clear" if standing <= 0 else "%d still standing" % standing
		TrialCatalog.Id.GROUNDWORK:
			return "%d of %d by the Cane" % [
				_tally, roundi(TrialCatalog.get_value(_trial_id, _wave_number))
			]
	return "holding"


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
				>= TrialCatalog.get_value(_trial_id, _wave_number)
			)
		TrialCatalog.Id.LAST_GARDEN:
			return (
				_marked_region_green() * 100.0
				>= TrialCatalog.get_value(_trial_id, _wave_number)
			)
		TrialCatalog.Id.PRESSURE:
			if combat == null:
				return true
			return (
				float(combat.get_active_enemy_count())
				<= TrialCatalog.get_value(_trial_id, _wave_number)
			)
		TrialCatalog.Id.FRONTIER:
			# Rooted's own test, read the other way round.
			if player == null:
				return true
			return (
				territory_field.get_control_at_local(player.get_arena_position())
				<= territory_field.tuning.ownership_threshold
			)
	# Untouched and Stillness have no state to sample: they are broken by an event
	# inside their window, or not at all.
	return true


func _final_rule_holds() -> bool:
	match _trial_id:
		TrialCatalog.Id.RECLAMATION:
			return (
				territory_field.get_player_percent() - _opening_green
				>= TrialCatalog.get_value(_trial_id, _wave_number)
			)
		TrialCatalog.Id.THE_CULL:
			return _standing() <= 0
		TrialCatalog.Id.GROUNDWORK:
			return float(_tally) >= TrialCatalog.get_value(_trial_id, _wave_number)
	# Everything else survived its own judgement to get here.
	return true


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
	if _state == State.NONE or _trial_id < 0:
		return
	_ensure_styles()
	var accent := _accent()
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

	var broken := _state == State.BROKEN
	var cursor := body.position.y + 12.0
	cursor = _draw_centered(
		_quoted_name(), TITLE_FONT_SIZE, MUTED if broken else accent, cursor
	) + 5.0
	cursor = _draw_wrapped(
		TrialCatalog.get_rule(_trial_id, _wave_number),
		RULE_FONT_SIZE,
		MUTED if broken else TEXT,
		cursor
	) + 4.0
	# What actually breaks it, under the rule rather than folded into it. A rule and
	# its failure condition are two different sentences and were being asked to be one.
	cursor = _draw_wrapped(
		TrialCatalog.get_fail_condition(_trial_id, _wave_number), FAIL_FONT_SIZE, MUTED, cursor
	) + 7.0
	cursor = _draw_divider(cursor, Color(accent.r, accent.g, accent.b, 0.45)) + 7.0
	cursor = _draw_centered(
		TrialCatalog.get_reward_lead(_trial_id), SMALL_FONT_SIZE, MUTED, cursor
	) + 2.0
	cursor = _draw_centered(
		REWARD_TEXT, REWARD_FONT_SIZE, MUTED if broken else BORDER_HOLDING, cursor
	) + 7.0
	_draw_state_strip(cursor, accent)


func _quoted_name() -> String:
	return "\"%s\"" % TrialCatalog.get_trial_name(_trial_id)


func _draw_tab(accent: Color) -> void:
	## Drawn after the frame so it sits on top of the border it overlaps.
	var label := "TRIAL"
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


func _draw_divider(top: float, color: Color) -> float:
	## The reference's row of dashes, as two short rules with three pips between them.
	var middle := size.x * 0.5
	var line_y := top + DIVIDER_HEIGHT * 0.5
	draw_line(Vector2(PADDING + 8.0, line_y), Vector2(middle - 20.0, line_y), color, 1.0)
	draw_line(
		Vector2(middle + 20.0, line_y),
		Vector2(size.x - PADDING - 8.0, line_y),
		color,
		1.0
	)
	for offset in [-11.0, 0.0, 11.0]:
		draw_rect(Rect2(middle + offset - 1.5, line_y - 1.5, 3.0, 3.0), color, true)
	return top + DIVIDER_HEIGHT


func _draw_state_strip(top: float, accent: Color) -> void:
	## How the Trial is going, on its own strip so the one part of the card that moves
	## while the wave runs is the one part the eye knows where to find.
	var strip := Rect2(Vector2(PADDING, top), Vector2(_inner_width(), STRIP_HEIGHT))
	_strip_style.bg_color = Color(accent.r, accent.g, accent.b, 0.14)
	_strip_style.border_color = Color(accent.r, accent.g, accent.b, 0.5)
	draw_style_box(_strip_style, strip)
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
	## How much of the rule's allowance has been spent, or -1 for a rule with no number
	## in it. Untouched and Rooted are broken by an event rather than by a quantity, so
	## a bar for either of them could only ever be full or gone.
	match _trial_id:
		TrialCatalog.Id.PATIENCE:
			return float(_tally) / maxf(TrialCatalog.get_value(_trial_id, _wave_number), 1.0)
		TrialCatalog.Id.STILLNESS:
			return _elapsed / maxf(TrialCatalog.get_value(_trial_id, _wave_number), 0.001)
		TrialCatalog.Id.GROUNDWORK:
			return float(_tally) / maxf(TrialCatalog.get_value(_trial_id, _wave_number), 1.0)
		TrialCatalog.Id.PRESSURE:
			if combat == null:
				return -1.0
			return (
				float(combat.get_active_enemy_count())
				/ maxf(TrialCatalog.get_value(_trial_id, _wave_number), 1.0)
			)
		TrialCatalog.Id.RECLAMATION:
			var gained := territory_field.get_player_percent() - _opening_green
			return gained / maxf(TrialCatalog.get_value(_trial_id, _wave_number), 0.001)
		TrialCatalog.Id.HIGH_WATER:
			return (
				territory_field.get_player_percent()
				/ maxf(TrialCatalog.get_value(_trial_id, _wave_number), 0.001)
			)
		TrialCatalog.Id.LAST_GARDEN:
			return (
				_marked_region_green()
				* 100.0
				/ maxf(TrialCatalog.get_value(_trial_id, _wave_number), 0.001)
			)
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
	## The card is as tall as its own rule needs it to be, which is the one thing about
	## it the scene cannot know: the sentences run to one, two or three lines at the
	## width the side panel gives them.
	if _state == State.NONE or _trial_id < 0:
		return
	size.y = (
		TAB_HEIGHT
		- TAB_OVERLAP
		+ 12.0
		+ LABEL_FONT.get_height(TITLE_FONT_SIZE)
		+ 5.0
		+ _wrapped_height(TrialCatalog.get_rule(_trial_id, _wave_number), RULE_FONT_SIZE)
		+ 4.0
		+ _wrapped_height(
			TrialCatalog.get_fail_condition(_trial_id, _wave_number), FAIL_FONT_SIZE
		)
		+ 7.0
		+ DIVIDER_HEIGHT
		+ 7.0
		+ LABEL_FONT.get_height(SMALL_FONT_SIZE)
		+ 2.0
		+ LABEL_FONT.get_height(REWARD_FONT_SIZE)
		+ 7.0
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
	_opening_green = float(state.get("opening_green", 0.0))
	_marked_region = state.get("marked_region", Vector2.ZERO)
	_has_marked_region = bool(state.get("has_marked_region", false))
	_resize_card()
	queue_redraw()
