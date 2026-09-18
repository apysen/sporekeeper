class_name RootStages
extends RefCounted

## How developed the ground under a point is, as four named bands of maturity.
##
## The bands are a rule rather than a reading: they are thresholds over a number, they
## need no field to be asked about, and Pruning harvests in the same bands - so the
## stages the interface names and the order the cycle eats in cannot drift apart while
## they are derived from one place.
##
## `TerritoryField.RootStage` is this enum, so every existing call site keeps working
## and there is still only one set of names.

enum Stage {
	SHALLOW,
	ESTABLISHED,
	DEVELOPED,
	LATE,
}


## Where ground stops being fresh and starts carrying roots. Half of the mature
## threshold rather than a number of its own, so re-tuning maturity moves both.
static func established_threshold(tuning: TerritoryPrototypeTuning) -> float:
	return tuning.mature_threshold * 0.5


static func stage_for(tuning: TerritoryPrototypeTuning, maturity: float) -> int:
	if maturity >= tuning.deep_root_threshold:
		return Stage.LATE
	if maturity >= tuning.mature_threshold:
		return Stage.DEVELOPED
	if maturity >= established_threshold(tuning):
		return Stage.ESTABLISHED
	return Stage.SHALLOW


static func stage_name(stage: int) -> String:
	match stage:
		Stage.LATE:
			return "Late"
		Stage.DEVELOPED:
			return "Developed"
		Stage.ESTABLISHED:
			return "Established"
		_:
			return "Shallow"
