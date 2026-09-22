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
	## The second draft. Six more, written after the first six had been read back:
	## the set needed rules that ask about *where* the fight happens, *when* it
	## happens and *what does the killing*, because four of the original six are
	## answered by the same habit of standing on your own Green and holding still.
	##
	## Only ever appended to. A Trial's id is written into a save, so reordering this
	## enum would hand a continued run somebody else's rule.
	STILLNESS,
	PRESSURE,
	FRONTIER,
	CLEAN_GROUND,
	THE_CULL,
	GROUNDWORK,
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
	## Broken by an event, but only one that happens inside an opening window. The
	## card counts the window down rather than up, because what the player is managing
	## is how long is left of it.
	WINDOW,
}

const TRIALS := {
	Id.ROOTED: {
		"name": "ROOTED",
		## Aimed squarely at §2.4. A damage build answers a wave by going to it; this
		## says the wave has to be answered from the ground you already hold, which is
		## the one demand a bigger number cannot meet.
		"rule": "Stay on your own Green for the whole wave",
		"earn": "STAY ROOTED TO EARN",
		"fail": "Breaks the moment you stand on Rot or bare ground.",
		"judgement": Judgement.CONTINUOUS,
		"value": 0.0,
	},
	Id.UNTOUCHED: {
		"name": "UNTOUCHED",
		"rule": "Take no damage for the whole wave",
		"earn": "FINISH UNTOUCHED TO EARN",
		"fail": "Breaks on the first hit that lands on Grandma.",
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
		"rule": "Defeat no more than {value} enemies this wave",
		"earn": "KEEP YOUR PATIENCE TO EARN",
		## The count is the whole rule, so the failure is stated as the kill that ends
		## it. "Kill no more than 45" was read as "kill nothing for a while", which is
		## a different and much worse Trial.
		"fail": "Breaks on kill {next}. Killing fewer is always safe.",
		"judgement": Judgement.TALLY,
		## 56 on Wave 6, 76 on 11, 96 on 16, against a *played* run -- `pacing_probe`
		## with a 5-6 pair taking its upgrades -- that kills 66, 83 and 117 on those
		## waves. So the ceiling sits 15%, 8% and 18% under what the run does when it is
		## not thinking about the Trial, which is a rule that asks the player to skip
		## some fights rather than one that asks them to lose the wave.
		##
		## The flat 45 this started as was under the *passive* rate on every Trial wave
		## and a third under the played rate by Wave 16. It could not be held.
		"value": 56.0,
		"per_wave": 4.0,
	},
	Id.HIGH_WATER: {
		"name": "HIGH WATER",
		"rule": "Hold at least {value}% of the arena as Green, all wave",
		"earn": "HOLD THE HIGH WATER TO EARN",
		"fail": "Breaks the moment Green drops below {value}%.",
		"judgement": Judgement.CONTINUOUS,
		## A played run holds between 18% and 26% of the arena across the Trial waves,
		## and is on the way *down* through the back half. The 25% this was written at
		## sat above the run's own high-water mark on two of the three waves that can
		## offer it, so it broke on the first evaluation tick and read as a bug.
		"value": 15.0,
	},
	Id.RECLAMATION: {
		"name": "RECLAMATION",
		## Measured against per-wave movement of roughly a point either way, with the
		## back half of a run losing ground rather than gaining it. The 6 points this
		## asked for was two to three waves' worth of gain inside one wave.
		"rule": "End the wave holding {value}% more of the arena than when it began",
		"earn": "RECLAIM IT TO EARN",
		## The one rule that cannot be broken early, which is worth saying on the card:
		## ground lost in the first thirty seconds costs nothing if it is taken back.
		"fail": "Judged once, when the wave ends. Ground lost early costs nothing.",
		"judgement": Judgement.FINAL,
		"value": 3.0,
	},
	Id.LAST_GARDEN: {
		"name": "LAST GARDEN",
		"rule": "Keep the ringed ground at least {value}% Green",
		"earn": "DEFEND THE RING TO EARN",
		"fail": "Breaks the moment the ring falls below {value}%.",
		"judgement": Judgement.CONTINUOUS,
		"value": 50.0,
	},
	Id.STILLNESS: {
		"name": "STILLNESS",
		## The Trial Patience was being misread as. Both are about killing less, and
		## they are not the same rule: Patience is a ceiling on the whole wave, this is
		## a window at the start of it where nothing dies at all. Worth having both,
		## because the window is answered by running and the ceiling is answered by
		## choosing, and those are different skills.
		"rule": "Defeat nothing in the wave's first {value} seconds",
		"earn": "KEEP STILL TO EARN",
		"fail": "Breaks on the first kill inside the window. After it, kill freely.",
		"judgement": Judgement.WINDOW,
		## The hardest rule in the set and deliberately short because of it: the Cane
		## swings itself, and the measured first kill of a wave lands inside two seconds
		## on every wave past the first. Ten seconds is ten seconds of running, which is
		## the point -- but twenty was a wave spent entirely in retreat.
		"value": 10.0,
	},
	Id.PRESSURE: {
		"name": "PRESSURE",
		## Patience inverted, and the reason the set needed it: every other constraint
		## here is answered by killing less or standing still, so a player who reads
		## "Trial" as "play slower" is right four times out of six. This one breaks if
		## they do.
		"rule": "Never let more than {value} hostiles stand at once",
		"earn": "KEEP THE BOARD CLEAR TO EARN",
		"fail": "Breaks the moment hostile number {next} is standing.",
		"judgement": Judgement.CONTINUOUS,
		## 20 on Wave 6, 45 on 11, 70 on 16, against measured passive peaks of 21, 52
		## and 71. The board grows by roughly five a wave and a cap that does not grow
		## with it is a Trial that is merely difficult early and arithmetically
		## impossible late.
		"value": 20.0,
		"per_wave": 5.0,
	},
	Id.FRONTIER: {
		"name": "FRONTIER",
		## Rooted turned inside out, and it replaced a rule called Arm's Length that was
		## Untouched wearing a different sentence: a hostile close enough to break that
		## one is a hostile about to deal the damage that breaks this one, so the two
		## were held and lost in the same moment and by the same play.
		##
		## This is the opposite demand. Green heals Grandma and Rot does not hurt her,
		## so spending a wave off your own ground costs the regeneration and the safe
		## retreat without being a death sentence -- and it asks the build to work at
		## the frontier, which is where the wave is.
		"rule": "Fight the whole wave off your own Green",
		"earn": "STAY OUT THERE TO EARN",
		"fail": "Breaks the moment you stand on ground you already own.",
		"judgement": Judgement.CONTINUOUS,
		"value": 0.0,
	},
	Id.CLEAN_GROUND: {
		"name": "CLEAN GROUND",
		"rule": "Let no Canker form this wave",
		"earn": "KEEP THE GROUND CLEAN TO EARN",
		"fail": "Breaks the moment a warning ring becomes a Knot.",
		"judgement": Judgement.TALLY,
		"value": 0.0,
		## The wave Cankers start entrenching on. Offered before that, this is a free
		## relic.
		"from_wave": 6,
	},
	Id.THE_CULL: {
		"name": "THE CULL",
		## Was written as "no Corruptor or Saboteur standing", which needed the run to
		## ask the wave table what it was about to spawn, and needed the Trial to be
		## able to abandon itself when the roll came up without one -- two systems and a
		## third outcome, for one rule. Every wave sends enemies. Asking about all of
		## them costs nothing and says the same thing: finish what is in front of you
		## before the clock does.
		"rule": "End the wave with nothing left standing",
		"earn": "FINISH THE CULL TO EARN",
		"fail": "Judged once, when the wave ends. A single straggler breaks it.",
		"judgement": Judgement.FINAL,
		"value": 0.0,
	},
	Id.GROUNDWORK: {
		"name": "GROUNDWORK",
		## The Cane only swings at what is in front of Grandma, so a run that answers
		## everything at range or through the ground can go a whole wave barely landing
		## one. This says the wave has to be fought at the Cane's length, which is the
		## one demand a ranged roster cannot meet by building harder.
		"rule": "Defeat {value} enemies with the Cane this wave",
		"earn": "DO THE GROUNDWORK TO EARN",
		"fail": "Judged when the wave ends. Only the Cane's own kills count.",
		"judgement": Judgement.FINAL,
		## 25 on Wave 6, 35 on 11, 45 on 16, against a measured 28, 39 and 54 Cane kills
		## on those waves with a four-path roster standing still. So it asks for most of
		## what the Cane already does when nothing is asking it to.
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


static func get_rule(trial_id: int, wave_number := SCALING_REFERENCE_WAVE) -> String:
	## The sentence the card prints, with its number already in it. One sentence, in
	## the imperative, because a rule the player has to reconstruct from two numbers
	## and a label is a rule they will not track while something is eating the garden.
	##
	## Every one of them names its window -- "this wave", "all wave", "when the wave
	## ends" -- because a rule with no stated end is read as a rule about right now.
	return _fill(trial_id, String(_entry(trial_id).get("rule", "")), wave_number)


static func get_reward_lead(trial_id: int) -> String:
	## The line above the reward, in each Trial's own words. One shared "hold it to
	## earn" only ever described Reclamation, and a rule stated one way and rewarded in
	## another reads as boilerplate -- which is the fastest way to stop being read.
	return String(_entry(trial_id).get("earn", "COMPLETE IT TO EARN"))


static func get_fail_condition(
	trial_id: int, wave_number := SCALING_REFERENCE_WAVE
) -> String:
	## The second line: exactly what breaks the rule, or when it is judged. The rule
	## says what to do and this says what counts, which is the half that was missing --
	## "Kill no more than 45 enemies" does not say whether the 45th is the safe one.
	return _fill(trial_id, String(_entry(trial_id).get("fail", "")), wave_number)


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
	return base + per_wave * float(maxi(0, wave_number - SCALING_REFERENCE_WAVE))


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


static func _fill(trial_id: int, text: String, wave_number: int) -> String:
	## `{value}` is the rule's own number on this wave and `{next}` is the one past it,
	## which is what a tally actually breaks on.
	var value := get_value(trial_id, wave_number)
	return text.replace("{value}", _format_value(value)).replace(
		"{next}", _format_value(value + 1.0)
	)


static func _format_value(value: float) -> String:
	return "%d" % roundi(value) if is_equal_approx(value, round(value)) else "%.1f" % value
