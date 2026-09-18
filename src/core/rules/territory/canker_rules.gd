class_name CankerRules
extends RefCounted

## The arithmetic behind an entrenched hostile structure, with no field to ask.
##
## A Canker is what long-held Rot turns into when the player stops contesting it. The
## decisions are all thresholds over one measured ratio and one clock, so they live
## here where a test can drive them directly rather than inside the node that happens
## to own the timers.
##
## Deliberately not here: how the ratio is measured, where a site sits, and what a
## formed Knot looks like. Those need the field, the arena, and a CanvasItem.

## The incubation ladder from section 16. A site climbs it by holding Rot and falls
## straight back to INACTIVE the moment it stops.
enum Stage {
	INACTIVE,
	ACCUMULATING,
	WARNING,
	ACTIVE,
}


## Whether a site holds enough Rot to start, or to keep, climbing toward a Knot.
##
## Separate from `has_collapsed` on purpose. One threshold for both directions makes
## the stage flicker every time a frontier breathes across it, which is the entire
## reason section 15.1 asks for hysteresis.
static func qualifies(rot_ratio: float, activation_ratio: float) -> bool:
	return rot_ratio >= activation_ratio


## Whether the player has pushed a site far enough back to stop its progress. The gap
## between this and `qualifies` is the dead band: inside it a site neither advances
## nor resets, so ground being fought over stays where it is until somebody wins.
static func has_collapsed(rot_ratio: float, cancel_ratio: float) -> bool:
	return rot_ratio < cancel_ratio


## Whether a formed Knot has lost its ground and should wither. Reclaiming is the only
## way to kill one, so this is the whole destruction condition; there is no health to
## compare against and nothing damage can do here directly.
static func should_wither(rot_ratio: float, destroy_ratio: float) -> bool:
	return rot_ratio < destroy_ratio


## What share of ordinary reinforcements enter through Knots rather than the perimeter.
##
## Capped rather than accumulated. Two Knots are meant to open a second front, not to
## retire the perimeter: section 18 is explicit that a Canker changes spawn topology
## and never spawn quantity, and an uncapped per-Knot chance quietly does the second.
static func redirect_share(knot_count: int, share_per_knot: float, maximum: float) -> float:
	if knot_count <= 0:
		return 0.0
	return minf(float(knot_count) * maxf(0.0, share_per_knot), maxf(0.0, maximum))


## How strongly a site deserves the next Knot, given it already qualifies.
##
## Rot ratio and persistence both count, because they answer different questions: the
## ratio says the ground is lost now, the clock says the player has had time to notice.
## A site that has been ignored for a long while outranks one that just tipped over,
## which is what makes a Knot read as a consequence rather than as bad luck.
static func candidate_score(rot_ratio: float, held_seconds: float, hold_time: float) -> float:
	var persistence := clampf(held_seconds / maxf(0.001, hold_time), 0.0, 1.0)
	return clampf(rot_ratio, 0.0, 1.0) + persistence * 0.5


## Whether a site is far enough from everything that would make a Knot unfair or
## redundant. Distances are squared by the caller's convention elsewhere in the
## project; here they are plain, because this runs a few dozen times a second at most.
##
## Grandma's radius is the one that matters for fairness: a Knot that forms on top of
## the player turns an ignored corner of the board into instant damage.
static func is_site_clear(
	distance_to_player: float,
	minimum_player_distance: float,
	distance_to_nearest_knot: float,
	minimum_knot_spacing: float
) -> bool:
	if distance_to_player < minimum_player_distance:
		return false
	if distance_to_nearest_knot >= 0.0 and distance_to_nearest_knot < minimum_knot_spacing:
		return false
	return true


## The next stage and clocks for one site, given what it measured this tick.
##
## Returned as a small typed result rather than mutating a candidate, so the ladder can
## be tested one transition at a time without building a director. The node applies it.
static func advance_stage(
	stage: Stage,
	rot_ratio: float,
	hold_timer: float,
	warning_timer: float,
	delta: float,
	settings: Settings
) -> Transition:
	var result := Transition.new()
	result.stage = stage
	result.hold_timer = hold_timer
	result.warning_timer = warning_timer
	match stage:
		Stage.INACTIVE:
			if qualifies(rot_ratio, settings.activation_ratio):
				result.stage = Stage.ACCUMULATING
				result.hold_timer = 0.0
		Stage.ACCUMULATING:
			if has_collapsed(rot_ratio, settings.cancel_ratio):
				result.stage = Stage.INACTIVE
				result.hold_timer = 0.0
				result.reset = true
			else:
				result.hold_timer = hold_timer + delta
				if result.hold_timer >= settings.hold_time:
					result.stage = Stage.WARNING
					result.warning_timer = settings.warning_time
					result.entered_warning = true
		Stage.WARNING:
			if has_collapsed(rot_ratio, settings.cancel_ratio):
				result.stage = Stage.INACTIVE
				result.hold_timer = 0.0
				result.warning_timer = 0.0
				result.reset = true
				result.cancelled_warning = true
			else:
				result.warning_timer = warning_timer - delta
				if result.warning_timer <= 0.0:
					result.stage = Stage.ACTIVE
					result.warning_timer = 0.0
					result.formed = true
		Stage.ACTIVE:
			if should_wither(rot_ratio, settings.destroy_ratio):
				result.hold_timer = hold_timer + delta
				if result.hold_timer >= settings.destroy_hold_time:
					result.stage = Stage.INACTIVE
					result.hold_timer = 0.0
					result.withered = true
			else:
				# Reclaiming has to be sustained. A Bloom that clears the ground for a
				# frame and loses it again should not take a Knot with it.
				result.hold_timer = 0.0
	return result


## How far along the visible telegraph a site is, as zero to one.
##
## Section 22 asks the ground to say what is coming before any text does, and every
## part of that presentation - vein density, pulse rate, how far the tendrils have
## drawn in - is driven from this one number so they cannot fall out of step.
static func telegraph_progress(
	stage: Stage,
	hold_timer: float,
	warning_timer: float,
	settings: Settings
) -> float:
	match stage:
		Stage.ACCUMULATING:
			return clampf(hold_timer / maxf(0.001, settings.hold_time), 0.0, 1.0)
		Stage.WARNING, Stage.ACTIVE:
			return 1.0
		_:
			return 0.0


## The tuning one evaluation reads, gathered so a call does not take eight floats in an
## order nobody can remember.
class Settings:
	extends RefCounted
	var activation_ratio := 0.65
	var cancel_ratio := 0.50
	var hold_time := 10.0
	var warning_time := 2.5
	var destroy_ratio := 0.35
	var destroy_hold_time := 1.0


## One site's new state, plus the edges worth reacting to. The flags exist because a
## caller needs to know a Knot *became* active, not merely that it is.
class Transition:
	extends RefCounted
	var stage := Stage.INACTIVE
	var hold_timer := 0.0
	var warning_timer := 0.0
	var reset := false
	var entered_warning := false
	var cancelled_warning := false
	var formed := false
	var withered := false
