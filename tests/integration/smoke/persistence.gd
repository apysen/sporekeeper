## Saving a run and continuing it.
##
## What a save has to be is not "the file loads" but "the run you get back is the run
## you left". So the shape of every check here is the same: put the run into a state
## nothing about a fresh run resembles, capture it, tear the run down to a fresh one,
## restore, and ask the run itself what it holds - through the same accessors the game
## uses, rather than by comparing the dictionary to itself.
##
## Nothing here touches `user://save.dat`. The bytes round trip is done in memory with
## the same encoder `SaveStore` writes with; the file itself is `save_store_probe`'s
## subject, where it can be backed up and put back. A suite that saved over the player's
## own run would be doing the exact thing this feature exists to prevent.
class_name SmokePersistence
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	var held_seed := prototype.progression.run_seed
	var held_authored_seed := prototype.progression.authored_run_seed

	# A run that looks nothing like a fresh one: a build, levels, a relic, biomass,
	# damage taken, ground fought over, and a clock well past the opening wave.
	SmokeFixtures.grow_test_ecosystem(prototype)
	SmokeFixtures.acquire_adaptation(prototype, Progression.PathId.SPORE)
	SmokeFixtures.acquire_adaptation(prototype, Progression.PathId.BLOOM)
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	prototype.progression.add_biomass(140.0)
	# Offered and taken rather than written in, so what is captured is a relic the run
	# owns the way a run owns one. The pool is picked over by the modules above, so the
	# offer is forced rather than drawn.
	var eligible := prototype.progression.get_eligible_relics()
	if not eligible.is_empty():
		prototype.progression._pending_relic_options = PackedInt32Array([eligible[0]])
		prototype.progression.choose_relic(eligible[0])
	# From full health, so the number restored is a wound and not the floor a dead
	# player is already sitting on.
	prototype.player.reset_player()
	prototype.player.apply_damage(12.0)
	prototype.wave_director.debug_advance_time(180.0)
	SmokeFixtures.step_field(prototype.territory_field, 4)
	prototype.territory_field.recalculate_metrics_now()

	var expected := _describe(prototype)
	var snapshot := prototype.capture_snapshot()
	report.check(
		snapshot.run_seed == prototype.progression.run_seed
		and snapshot.wave_number == prototype.wave_director.get_current_wave_number()
		and snapshot.elapsed_seconds > 0.0,
		"a snapshot carries the run's identity: its seed, its wave and its clock"
	)

	# Through bytes rather than straight back in, because a field that survives being
	# handed between two objects in one process is not evidence that it survives being
	# written to disk: the arrays are the bulk of a save and the encoder is where a
	# Packed array's type is kept or lost.
	var encoded := var_to_bytes(snapshot.to_dictionary())
	var decoded: Variant = bytes_to_var(encoded)
	report.check(
		decoded is Dictionary,
		"a snapshot survives being encoded the way the save file encodes it (%d bytes)"
			% encoded.size()
	)
	var restored := RunSnapshot.from_dictionary(decoded if decoded is Dictionary else {})
	# Every system in `SYSTEM_KEYS` has to actually put something in, or a key is being
	# carried that nothing writes. The Cankers are named here because they are the one
	# whose absence is invisible in a prototype run: it has no Knots to lose, so only the
	# shape of what it stored says the interior front is on file at all. What a saved Knot
	# comes back as is `canker_probe`'s subject, on a board that has one.
	report.check(
		int(restored.get_system("cankers").get("site_count", 0))
			== prototype.canker_director.capture_state().get("site_count", -1),
		"a snapshot carries the Canker board, site for site"
	)

	# The seed is pinned back on before the restore rather than after: reset_run rolls
	# a fresh one, and the rest of the suite runs on the authored seed it was given.
	prototype.progression.authored_run_seed = held_authored_seed
	report.check(
		prototype.restore_snapshot(restored),
		"a saved run is restored onto a fresh run without being refused"
	)

	var actual := _describe(prototype)
	for key in expected:
		report.check(
			_matches(expected[key], actual.get(key)),
			"a continued run keeps its %s (%s)" % [key, str(expected[key])]
		)

	# A fresh run is the control: if reset_run did not actually clear what the restore
	# then put back, every check above would pass against a run that was never reset.
	prototype.reset_run()
	var fresh := _describe(prototype)
	var differences := 0
	for key in expected:
		if not _matches(expected[key], fresh.get(key)):
			differences += 1
	report.check(
		differences >= 6,
		"a fresh run differs from the saved one in %d of the %d things checked"
			% [differences, expected.size()]
	)

	# A field from an arena of another size is refused rather than stretched onto this
	# one, and refusing is reported so the run can start fresh instead of half-loaded.
	var wrong_size := snapshot.get_system("field").duplicate()
	wrong_size["width"] = int(wrong_size.get("width", 0)) + 1
	report.check(
		not prototype.territory_field.apply_state(wrong_size),
		"a field saved at a different grid size is refused"
	)

	prototype.reset_run()
	prototype.progression.authored_run_seed = held_authored_seed
	prototype.progression.set_run_seed(held_seed)
	prototype.wave_director.set_run_seed(held_seed)


## What the run holds, asked of the run rather than of the save. Every value is one a
## fresh run does not have, so a restore that quietly did nothing cannot pass.
static func _describe(prototype: RunRoot) -> Dictionary:
	var progression := prototype.progression
	return {
		"seed": progression.run_seed,
		"level": progression.current_level,
		"adaptations": progression.get_owned_adaptations(),
		"relics": progression.get_owned_relic_names().size(),
		"biomass": progression.biomass,
		"biomass earned": progression.biomass_earned_total,
		"health": prototype.player.get_health(),
		"clock": prototype.wave_director.elapsed_seconds,
		"wave": prototype.wave_director.get_current_wave_number(),
		"held ground": prototype.territory_field.get_player_cell_count(),
	}


static func _matches(expected: Variant, actual: Variant) -> bool:
	if expected is float:
		return actual is float and is_equal_approx(expected, actual)
	if expected is PackedInt32Array:
		return actual is PackedInt32Array and expected == actual
	return expected == actual
