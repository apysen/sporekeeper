extends SceneTree

## The full-Charge release cue. Charge is otherwise drawn as a gradient -- longer
## spikes, a warmer tint, a faster turn -- and a gradient has no ceiling the eye can
## find, so a ring at 90% looks like a ring at 100%. The pulse is the state change
## that says release now, and it has to be off everywhere it would be a lie.

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://scenes/run/run.tscn") != OK:
		push_error("Unable to load Sporekeeper run")
		quit(1)
		return
	await process_frame
	await process_frame
	var prototype := current_scene as RunRoot
	if prototype == null:
		push_error("Sporekeeper run scene did not become current")
		quit(1)
		return
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype._set_simulation_paused(true)
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.PRUNING,
		Progression.PathId.ROOT
	)
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	for _grow_step in range(400):
		prototype.territory_field.step_simulation()

	var pruning := prototype.pruning_director
	pruning.reset_director()
	var home := prototype.player.get_arena_position()
	_check(pruning.is_player_on_green(), "the probe is standing on ground the ring can eat")

	# Holding builds the ring and the Charge together. Nothing is shown while it fills:
	# a tell that fades up is the gradient again.
	var quiet_while_charging := true
	var reached_full := false
	var charge_ticks := int(pruning.get_charge_seconds() * 60.0) + 120
	for _hold_step in range(charge_ticks):
		prototype.player.global_position = prototype.territory_field.to_global(home)
		pruning.advance(1.0 / 60.0)
		prototype.territory_field.step_simulation()
		if pruning.is_fully_charged():
			reached_full = true
			break
		if pruning._get_full_charge_pulse() != 0.0:
			quiet_while_charging = false
	_check(reached_full, "an unbroken hold fills the ring")
	_check(quiet_while_charging, "nothing pulses while the ring is still filling")

	# The clock starts on the frame the ring fills, so the first beat is the brightest
	# one -- the beat the player has to catch.
	_check(
		is_equal_approx(pruning._get_full_charge_pulse(), 1.0),
		"the tell opens at its brightest on the frame the ring fills"
	)

	var brightest := 0.0
	var dimmest := 1.0
	for _beat_step in range(90):
		prototype.player.global_position = prototype.territory_field.to_global(home)
		pruning.advance(1.0 / 60.0)
		if not pruning.is_fully_charged():
			break
		var beat := pruning._get_full_charge_pulse()
		brightest = maxf(brightest, beat)
		dimmest = minf(dimmest, beat)
	_check(
		brightest >= 0.99
		and dimmest <= 1.0 - pruning.full_charge_pulse_depth + 0.02,
		"a full ring beats between bright and its authored dim"
	)

	# Charge with no ring behind it is not something to act on, so the tell goes with
	# the spikes rather than beating over an empty hoop.
	pruning.reset_director()
	pruning._charge = 1.0
	_check(
		pruning.get_orbit_count() == 0
		and not pruning.is_fully_charged()
		and pruning._get_full_charge_pulse() == 0.0,
		"a spent ring shows nothing however much Charge is nominally standing"
	)

	prototype.queue_free()
	await process_frame
	if _failures == 0:
		print("PRUNING_CHARGE_TELL_PROBE: PASS")
		quit(0)
	else:
		push_error("PRUNING_CHARGE_TELL_PROBE: %d failure(s)" % _failures)
		quit(1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		push_error("FAIL: %s" % description)
