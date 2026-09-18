class_name Nucleation
extends RefCounted

## Whether a patch of Green is large enough to survive on its own.
##
## Classical nucleation, borrowed wholesale: a satellite smaller than the critical
## radius costs more border than its bulk can pay for and is reclaimed, and one larger
## takes root. It is the rule behind whether scatter becomes colonies, and it is pure
## arithmetic over authored tuning and two measurements - which is why it lives here
## rather than inside the field that happens to measure them.

## r* = 2y / dg.
##
## Cohesion is the surface tension: a cohesive ecosystem raises the cost of having a
## border at all, so it throws fewer surviving satellites and holds its main body
## harder. Mass is the bulk driving force and lowers r*, so a Mass build's scatter
## literally starts taking root - which is the fantasy that axis has always been
## selling and only ever approximated.
static func critical_radius(
	tuning: TerritoryPrototypeTuning,
	cohesion_multiplier: float,
	driving_multiplier: float,
	average_maturity: float,
	support_fraction: float
) -> float:
	var gamma := tuning.nucleation_surface_tension * maxf(0.05, cohesion_multiplier)
	var driving := (
		tuning.nucleation_driving_force
		* maxf(0.05, driving_multiplier)
		* lerpf(
			1.0 - tuning.nucleation_maturity_share,
			1.0,
			clampf(average_maturity, 0.0, 1.0)
		)
		* (1.0 + tuning.nucleation_support_bonus * clampf(support_fraction, 0.0, 1.0))
	)
	return 2.0 * gamma / maxf(0.0001, driving)
