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
	## Constraints. None of these can be brute-forced by output.
	ROOTED,
	UNTOUCHED,
	PATIENCE,
	HIGH_WATER,
	## Goals, from §27.
	RECLAMATION,
	LAST_GARDEN,
}

## How a Trial is judged, which decides what the director has to watch.
##
## CONTINUOUS is checked every evaluation tick and fails the moment it is broken;
## TALLY counts an event and fails when the count passes its allowance; FINAL is only
## answered when the wave ends. The distinction matters for the card: a continuous
## rule can say "holding", a tally can say "7 of 12", and a final can only say what it
## is currently worth.
enum Judgement {
	CONTINUOUS,
	TALLY,
	FINAL,
}

const TRIALS := {
	Id.ROOTED: {
		"name": "ROOTED",
		## Aimed squarely at §2.4. A damage build answers a wave by going to it; this
		## says the wave has to be answered from the ground you already hold, which is
		## the one demand a bigger number cannot meet.
		"rule": "Do not step off your own Green",
		"judgement": Judgement.CONTINUOUS,
		"value": 0.0,
	},
	Id.UNTOUCHED: {
		"name": "UNTOUCHED",
		"rule": "Take no damage",
		"judgement": Judgement.CONTINUOUS,
		"value": 0.0,
	},
	Id.PATIENCE: {
		"name": "PATIENCE",
		## The bluntest instrument in the set, and the most useful one. A build whose
		## whole answer is clear speed has to find a different answer for a minute, and
		## every Adaptation that slows, pins, pushes or reclaims is suddenly the good
		## one. Deliberately generous: the number is meant to be a ceiling a damage
		## build bumps into, not a chore a territory build has to work at.
		"rule": "Kill no more than {value} enemies",
		"judgement": Judgement.TALLY,
		"value": 45.0,
	},
	Id.HIGH_WATER: {
		"name": "HIGH WATER",
		"rule": "Never let Green fall below {value}% of the arena",
		"judgement": Judgement.CONTINUOUS,
		"value": 25.0,
	},
	Id.RECLAMATION: {
		"name": "RECLAMATION",
		"rule": "Finish the wave holding {value} points more Green than you started",
		"judgement": Judgement.FINAL,
		"value": 6.0,
	},
	Id.LAST_GARDEN: {
		"name": "LAST GARDEN",
		"rule": "Keep the marked ground above {value}% Green",
		"judgement": Judgement.CONTINUOUS,
		"value": 50.0,
	},
}

## Radius in arena pixels of the region Last Garden marks.
const MARKED_REGION_RADIUS := 150.0


static func get_count() -> int:
	return Id.size()


static func get_trial_name(trial_id: int) -> String:
	return String(_entry(trial_id).get("name", ""))


static func get_rule(trial_id: int) -> String:
	## The sentence the card prints, with its number already in it. One sentence, in
	## the imperative, because a rule the player has to reconstruct from two numbers
	## and a label is a rule they will not track while something is eating the garden.
	var entry := _entry(trial_id)
	return String(entry.get("rule", "")).replace(
		"{value}", _format_value(float(entry.get("value", 0.0)))
	)


static func get_judgement(trial_id: int) -> int:
	return int(_entry(trial_id).get("judgement", Judgement.FINAL))


static func get_value(trial_id: int) -> float:
	return float(_entry(trial_id).get("value", 0.0))


static func is_marked_region_trial(trial_id: int) -> bool:
	return trial_id == Id.LAST_GARDEN


static func _entry(trial_id: int) -> Dictionary:
	return TRIALS.get(trial_id, {})


static func _format_value(value: float) -> String:
	return "%d" % roundi(value) if is_equal_approx(value, round(value)) else "%.1f" % value
