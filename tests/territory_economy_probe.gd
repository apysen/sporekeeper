extends SceneTree

## Biomass multiplies two territory numbers by two coefficients, and the whole formula
## is only meaningful if both numbers are the same kind of quantity. They were not: the
## mature term was fed "what share of my Green is Mature" against a coefficient meant
## for "what share of the arena is Mature Green". A small fully established foothold
## therefore paid as though it had established most of the board.
##
## The bug was invisible while almost no starting ground cleared the mature threshold,
## so the check that matters is not a number but the invariant: the two inputs are
## shares of the same whole, and the mature one can never exceed the Green one.

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var tuning := load("res://data/territory/phase_a_tuning.tres") as TerritoryPrototypeTuning
	_check(tuning != null, "prototype tuning resource loads")
	if tuning == null:
		quit(1)
		return

	var field := TerritoryField.new()
	field.tuning = tuning
	root.add_child(field)
	field.reset_field()
	field.recalculate_metrics_now()

	var green := field.get_player_percent()
	var fraction := field.get_mature_fraction_of_green()
	var arena := field.get_mature_percent_of_arena()

	# Mature Green is a subset of Green, so its share of the arena cannot exceed
	# Green's. The old input could and routinely did.
	_check(
		arena <= green + 0.001,
		"Mature arena share never exceeds Green arena share (%.2f <= %.2f)"
			% [arena, green]
	)
	_check(
		fraction > green,
		"the fraction of Green and the share of arena are genuinely different numbers (%.2f vs %.2f)"
			% [fraction, arena]
	)
	# The two published metrics must agree with each other: the arena share is the
	# Green share scaled by how much of it has established.
	_check(
		absf(arena - green * fraction * 0.01) < 0.01,
		"the two maturity metrics are consistent (%.3f vs %.3f)"
			% [arena, green * fraction * 0.01]
	)

	# Deliberately left out of the tree: tick_biomass is pure arithmetic over its
	# arguments, and _ready() asserts on collaborators this has no reason to build.
	var progression := Progression.new()
	progression.tick_biomass(1.0, green, arena, 1.0)
	var corrected := progression.biomass_per_second
	progression.tick_biomass(1.0, green, fraction, 1.0)
	var with_old_input := progression.biomass_per_second
	_check(
		with_old_input > corrected * 4.0,
		"feeding the fraction instead of the arena share still inflates income (%.3f vs %.3f)"
			% [with_old_input, corrected]
	)

	# The compatibility coefficient exists to hold the opening economy still while the
	# territory rework is tested. If someone retunes it, this should be the thing that
	# notices the starting rate moved.
	progression.tick_biomass(1.0, green, arena, 1.0)
	_check(
		absf(progression.biomass_per_second - 0.163) < 0.02,
		"the opening economy holds its pre-correction rate (%.4f Biomass/s)"
			% progression.biomass_per_second
	)

	print(
		"TERRITORY_ECONOMY: green=%.2f%% mature_fraction=%.2f mature_arena=%.2f biomass=%.4f/s"
		% [green, fraction, arena, progression.biomass_per_second]
	)

	if _failures > 0:
		push_error("TERRITORY_ECONOMY: %d failure(s)" % _failures)
		quit(1)
		return
	print("TERRITORY_ECONOMY: PASS")
	quit(0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures += 1
	push_error("FAIL: %s" % description)
