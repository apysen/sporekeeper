class_name TrialCatalog
extends RefCounted

## The Trials, as rules rather than as objectives.
##
## Section 27 of the Campaign rework sketches Trials as goals laid on top of a wave —
## reclaim this much Rot, kill that elite before it escapes. The trouble with a goal
## is that a stronger build simply reaches it sooner, which makes it another thing
## damage solves, and §2.4 exists because damage already solves everything.
##
## So these are written the way Die in the Dungeon writes its challenges: as a
## *restriction on how the wave is played*, stated as one sentence, visible the whole
## time, optional, and unpunished if broken. "Do not leave your own Green" cannot be
## answered by killing faster. Neither can "kill no more than twelve". A constraint
## changes what a strong build *is* for sixty seconds, which is the thing an objective
## cannot do.
##
## Two of the six are still goals — Reclamation and Last Garden — because §27 asks for
## them by name and because a run that only ever meets restrictions never gets asked
## to go and take something back. The mix is deliberate.
##
## Into the Breach is the other reference, for a rule it applies that this does not
## yet: there, a mission carrying more optional objectives is itself made harder, so
## the objectives double as a difficulty dial the player can read before committing.
## Worth stealing once Trials have been played; noted here rather than guessed at.

enum Id {
	ROOTED,
	UNTOUCHED,
	## Was Patience, a ceiling on kills. Every build kills on its own and more of them
	## each wave, so a cap on killing was a rule the run's own growth broke for the
	## player -- impossible late, and never fun early. Frenzy asks the opposite: kill a
	## crowd all at once, which a stronger build can do and still has to set up.
	FRENZY,
	HIGH_WATER,
	RECLAMATION,
	LAST_GARDEN,
	## Was Stillness, "kill nothing in the first ten seconds", which the Cane broke by
	## swinging on its own. Momentum is the movement rule that was underneath it.
	##
	## Both slots were renamed in place rather than appended: a Trial's id is written
	## into a save, and a slot keeps its number.
	MOMENTUM,
	PRESSURE,
	FRONTIER,
	CLEAN_GROUND,
	THE_CULL,
	GROUNDWORK,
}

## How a Trial is judged, which decides what the director watches and what the card's
## meter shows.
enum Judgement {
	## A state that has to hold. Time spent breaking it drains the Trial's slack, and
	## only running the slack out breaks the Trial: a rule that ended on the first
	## misstep was a rule about where the player happened to be standing when it was
	## handed to them.
	CONTINUOUS,
	## Events the wave allows `value` of. The next one breaks it.
	COUNTED,
	## Something to do once, any time in the wave. Done is done.
	GOAL,
	## Answered when the wave ends.
	FINAL,
}

## Every rule is written twice. `short` is what the card and the banner print, and it
## is held to five words or fewer, because it is read in a glance between two things
## trying to kill Grandma. `detail` is the whole rule, and lives in the card's tooltip
## for the player who stops to read it. `warning` is the one word shown over Grandma
## while a live rule is draining its slack, so the moment she is breaking it is told to
## her where she is looking rather than on the side panel.
const TRIALS := {
	Id.ROOTED: {
		"name": "ROOTED",
		"short": "Stay on your Green",
		"detail": "Time off your own Green drains a {slack}-second allowance. Run it out and the Trial breaks.",
		"warning": "OFF GREEN",
		"judgement": Judgement.CONTINUOUS,
		"slack": 4.0,
		"value": 0.0,
	},
	Id.UNTOUCHED: {
		"name": "UNTOUCHED",
		## One hit ending it asked for a flawless minute against a board that grows every
		## wave. Three is still a wave played carefully.
		"short": "Take {value} hits or fewer",
		"detail": "Hit number {next} breaks the Trial.",
		"warning": "HIT",
		"judgement": Judgement.COUNTED,
		"value": 3.0,
	},
	Id.FRENZY: {
		"name": "FRENZY",
		"short": "Kill {value} within 3 seconds",
		"detail": "Land {value} kills inside any three seconds of the wave. Gather them up, then set them off.",
		"judgement": Judgement.GOAL,
		"window": 3.0,
		## 13 on Wave 6, 16 on 11, 17 on 13, 19 on 16. A played run that is not trying
		## lands at most 9-10, 12, 12 and 15 kills in any three seconds of those waves
		## (`pacing_probe`, Bloom+Thistle+Vine and Pruning+Bramble+Root), so the ask is
		## about a third over what the build does on its own: it has to be set up.
		"value": 13.0,
		"per_wave": 0.6,
	},
	Id.HIGH_WATER: {
		"name": "HIGH WATER",
		"short": "Hold {value}% Green",
		"detail": "Time with less than {value}% of the arena Green drains a {slack}-second allowance.",
		"warning": "LOW GREEN",
		"judgement": Judgement.CONTINUOUS,
		"slack": 5.0,
		## A played run holds 18-26% across the Trial waves and is falling through the
		## back half; 25% sat above the run's own high-water mark.
		"value": 15.0,
	},
	Id.RECLAMATION: {
		"name": "RECLAMATION",
		"short": "Gain {value}% Green",
		"detail": "Judged when the wave ends, against the Green you started it with. Ground lost early costs nothing if you take it back.",
		"judgement": Judgement.FINAL,
		## Per-wave movement is about a point either way in a played run.
		"value": 3.0,
	},
	Id.LAST_GARDEN: {
		"name": "LAST GARDEN",
		"short": "Keep the ring Green",
		"detail": "Time with the ring under {value}% Green drains a {slack}-second allowance.",
		"warning": "RING FALLING",
		"judgement": Judgement.CONTINUOUS,
		"slack": 5.0,
		"value": 50.0,
	},
	Id.MOMENTUM: {
		"name": "MOMENTUM",
		"short": "Keep moving",
		"detail": "Standing still drains a {slack}-second allowance. Keep walking and it never runs.",
		"warning": "MOVE",
		"judgement": Judgement.CONTINUOUS,
		"slack": 5.0,
		"value": 0.0,
	},
	Id.PRESSURE: {
		"name": "PRESSURE",
		"short": "Keep under {value} enemies",
		"detail": "Time with more than {value} hostiles on the board drains a {slack}-second allowance.",
		"warning": "TOO MANY",
		"judgement": Judgement.CONTINUOUS,
		"slack": 5.0,
		## Measured passive peaks of 21, 52 and 71 on Waves 6, 11 and 16.
		"value": 20.0,
		"per_wave": 5.0,
	},
	Id.FRONTIER: {
		"name": "FRONTIER",
		"short": "Stay off your Green",
		"detail": "Time on your own Green drains a {slack}-second allowance. Fight out where the wave is.",
		"warning": "ON GREEN",
		"judgement": Judgement.CONTINUOUS,
		"slack": 5.0,
		"value": 0.0,
	},
	Id.CLEAN_GROUND: {
		"name": "CLEAN GROUND",
		"short": "Let no Canker form",
		"detail": "Breaks the moment a warning ring becomes a Knot. Get to the rings before they finish.",
		"warning": "CANKER",
		"judgement": Judgement.COUNTED,
		"value": 0.0,
		## The wave Cankers start entrenching on. Offered before that, this is free.
		"from_wave": 6,
	},
	Id.THE_CULL: {
		"name": "THE CULL",
		## "Nothing left standing" met waves that spawn up to their last second, so it
		## asked for the one moment a wave cannot give. A few stragglers is the ask a
		## strong clear can actually answer.
		"short": "At most {value} left standing",
		"detail": "The board was counted when the Trial began. End the wave with no more than half that -- {value} -- still standing.",
		"judgement": Judgement.FINAL,
		## Half the board as it stood when the Trial began, and never under `value`.
		##
		## A fixed number per wave could not serve both kinds of build. A played
		## Bloom+Thistle+Vine run ends Wave 16 with 16 standing; Pruning+Bramble+Root,
		## which holds the board rather than clearing it, ends it with 59. Any one number
		## was either free for the first or out of reach for the second. Measured against
		## the board the player is actually facing, it asks the same of both: clear half
		## of what is in front of you.
		"board_share": 0.5,
		"value": 3.0,
	},
	Id.GROUNDWORK: {
		"name": "GROUNDWORK",
		"short": "Kill {value} with the Cane",
		"detail": "Only kills the Cane lands itself count. Done the moment you reach it.",
		"judgement": Judgement.GOAL,
		## 25 on Wave 6, 45 on 16, against 28 and 54 Cane kills measured from a standing
		## four-path roster.
		"value": 25.0,
		"per_wave": 2.0,
	},
}

## Radius in arena pixels of the region Last Garden marks.
const MARKED_REGION_RADIUS := 150.0

## The wave a scaling Trial's stated number belongs to: the first wave that carries a
## Trial at all. A Trial offered on Wave 6 uses its `value` as written, and every wave
## after that adds its `per_wave`.
const SCALING_REFERENCE_WAVE := 6


static func get_count() -> int:
	return Id.size()


static func get_trial_name(trial_id: int) -> String:
	return String(_entry(trial_id).get("name", ""))


static func get_rule(
	trial_id: int, wave_number := SCALING_REFERENCE_WAVE, value := -1.0
) -> String:
	## The five words the card prints, with the number already in them. `value` is the
	## number a live Trial settled on, for a rule that measures the board it began on.
	return _fill(trial_id, String(_entry(trial_id).get("short", "")), wave_number, value)


static func get_detail(
	trial_id: int, wave_number := SCALING_REFERENCE_WAVE, value := -1.0
) -> String:
	## The whole rule, for the card's tooltip.
	return _fill(trial_id, String(_entry(trial_id).get("detail", "")), wave_number, value)


static func get_board_share(trial_id: int) -> float:
	## Share of the board a rule asks for, measured when it begins, or zero for a rule
	## whose number is fixed.
	return float(_entry(trial_id).get("board_share", 0.0))


static func get_value_for_board(trial_id: int, wave_number: int, standing: int) -> float:
	## A board-measured rule's number, given what was standing when it began. Never
	## under the catalog's own value, so an empty board still leaves something to do.
	var floor_value := get_value(trial_id, wave_number)
	var share := get_board_share(trial_id)
	if share <= 0.0:
		return floor_value
	return maxf(floor_value, floorf(float(standing) * share))


static func get_warning(trial_id: int) -> String:
	## The word shown over Grandma while she is breaking a live rule. Empty for rules
	## that are only answered at the end, which have no moment to warn about.
	return String(_entry(trial_id).get("warning", ""))


static func get_slack(trial_id: int) -> float:
	## Seconds a CONTINUOUS rule may be broken for before the Trial is.
	return float(_entry(trial_id).get("slack", 0.0))


static func get_burst_window(trial_id: int) -> float:
	return float(_entry(trial_id).get("window", 0.0))


static func get_judgement(trial_id: int) -> int:
	return int(_entry(trial_id).get("judgement", Judgement.FINAL))


static func get_value(trial_id: int, wave_number := SCALING_REFERENCE_WAVE) -> float:
	## What the rule allows or asks for on a given wave.
	##
	## Three of the twelve are a count of things the wave itself produces -- kills, a
	## standing board, kills off the Cane -- and all three of those roughly double
	## between the first Trial wave and the last. A fixed number against a growing wave
	## is a Trial that means something different every time it is offered, which is the
	## one thing an optional challenge cannot afford: the player has to be able to read
	## the card and know whether it is worth trying.
	var entry := _entry(trial_id)
	var base := float(entry.get("value", 0.0))
	var per_wave := float(entry.get("per_wave", 0.0))
	if is_zero_approx(per_wave):
		return base
	# Whole numbers, because they are counts and because the card prints them.
	return roundf(base + per_wave * float(maxi(0, wave_number - SCALING_REFERENCE_WAVE)))


static func is_available(trial_id: int, wave_number: int) -> bool:
	## Whether a wave can offer this Trial at all. Most can be offered from the first
	## wave that carries one; the two that depend on a system the run has not started
	## yet say so, because an unfailable Trial pays a relic for nothing and teaches the
	## player to stop reading the card.
	return wave_number >= int(_entry(trial_id).get("from_wave", 0))


static func get_available(wave_number: int) -> PackedInt32Array:
	var available := PackedInt32Array()
	for trial_id in range(get_count()):
		if is_available(trial_id, wave_number):
			available.append(trial_id)
	return available


static func is_marked_region_trial(trial_id: int) -> bool:
	return trial_id == Id.LAST_GARDEN


static func _entry(trial_id: int) -> Dictionary:
	return TRIALS.get(trial_id, {})


static func _fill(trial_id: int, text: String, wave_number: int, override := -1.0) -> String:
	## `{value}` is the rule's own number on this wave and `{next}` is the one past it,
	## which is what a tally actually breaks on.
	var value := override if override >= 0.0 else get_value(trial_id, wave_number)
	return text.replace("{value}", _format_value(value)).replace(
		"{next}", _format_value(value + 1.0)
	).replace("{slack}", _format_value(get_slack(trial_id)))


static func _format_value(value: float) -> String:
	return "%d" % roundi(value) if is_equal_approx(value, round(value)) else "%.1f" % value
