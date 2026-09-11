## Every relic, one at a time, grouped by the pool it is drawn from.
##
## This file is the shared ground the six groups stand on and nothing else. It resets
## the run, takes the relic director, and finds the one owned cell the groups measure
## from - `lone_spot` is passed down rather than re-found, because each group changes
## the territory it runs on and a second scan would not return the same cell.
##
## Each group installs one relic at a time, drives the exact situation it names, and
## clears up after itself, so the order they run in is the order the catalog is
## written and not a dependency.
class_name SmokeRelicRules
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	# ---------------------------------------------------------------- relic rules
	# Every relic below is a rule change, so each check asserts the rule rather
	# than a number, and the recursion limiters get their own checks because a
	# relic engine that feeds itself is the failure mode this catalog guards.
	prototype.progression.reset_progression()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	var relics := prototype.relic_director
	relics.reset_director()

	var lone_spot := SmokeFixtures.find_owned_cell_position(prototype)

	SmokeRelicsSporeBloom.run(report, prototype, relics, lone_spot)

	SmokeRelicsBramblePruning.run(report, prototype, relics, lone_spot)

	SmokeRelicsThistleFruit.run(report, prototype, relics, lone_spot)

	await SmokeRelicsPresentation.run(report, prototype, relics, lone_spot)

	SmokeRelicsPlantRoot.run(report, prototype, relics, lone_spot)

	SmokeRelicsVine.run(report, prototype, relics, lone_spot)

	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	relics.reset_director()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	prototype.territory_field.reset_field()
