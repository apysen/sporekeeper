extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_error := change_scene_to_file("res://scenes/run/run.tscn")
	if load_error != OK:
		push_error("Unable to load Sporekeeper run: %s" % error_string(load_error))
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
	prototype.territory_field.reset_field()
	prototype.adaptation_director.reset_adaptations()
	prototype.progression.debug_select_paths(
		Progression.PathId.THISTLE,
		Progression.PathId.VINE
	)
	prototype._apply_progression_modifiers()
	prototype.adaptation_director.advance(1.0 / 60.0)

	var adaptations := prototype.adaptation_director
	var positions := PackedVector2Array()
	for thistle in adaptations._thistles:
		if thistle.active and thistle.permanent:
			positions.append(thistle.position)
	_check(positions.size() == 1, "choosing Thistle plants exactly one permanent turret")

	# The four Thistle lines used to buy turret slots. They buy carry now, so a
	# started line has to lengthen the ride and shorten the wait between rides.
	var bare_carry := adaptations.get_thistle_carry_seconds()
	var bare_cooldown := adaptations.get_thistle_stick_cooldown_seconds()
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.THISTLE_CLUSTERING
	] = 1
	var line_carry := adaptations.get_thistle_carry_seconds()
	var line_cooldown := adaptations.get_thistle_stick_cooldown_seconds()
	var capacity_held := adaptations._get_thistle_capacity() == 1
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.THISTLE_CLUSTERING
	] = 0
	_check(
		line_carry > bare_carry and line_cooldown < bare_cooldown and capacity_held,
		"a started Thistle line buys carry rather than a second turret"
	)

	var overlap_attempt := adaptations._plant_thistle(
		false,
		5.0,
		positions[0] if not positions.is_empty() else prototype.player.get_arena_position()
	)
	var all_separated := true
	var active_positions := PackedVector2Array()
	for thistle in prototype.adaptation_director._thistles:
		if thistle.active:
			active_positions.append(thistle.position)
	for first in range(active_positions.size()):
		for second in range(first + 1, active_positions.size()):
			if (
				active_positions[first].distance_to(active_positions[second])
				< prototype.adaptation_director.thistle_minimum_spacing_pixels - 0.01
			):
				all_separated = false
	_check(
		not overlap_attempt or all_separated,
		"explicit and temporary planting requests cannot overlap an active Thistle"
	)

	# Carry: walking over the turret catches it, it rides Grandma while it fires,
	# and a drop back onto supporting Green replants it there.
	adaptations.reset_adaptations()
	prototype.territory_field.reset_field()
	prototype._apply_progression_modifiers()
	adaptations.advance(1.0 / 60.0)
	var carried_turret: ThistleState = null
	for thistle in adaptations._thistles:
		if thistle.active and thistle.permanent:
			carried_turret = thistle
			break
	if carried_turret == null:
		_check(false, "a permanent Thistle is standing before the carry checks")
	else:
		var planted_at := carried_turret.position
		carried_turret.stick_cooldown_remaining = 0.0
		prototype.player.global_position = prototype.territory_field.to_global(planted_at)
		adaptations.advance(1.0 / 60.0)
		_check(carried_turret.carried, "walking through the Thistle catches it on Grandma")

		# It rides her, so it fires from wherever she is rather than from the ground.
		var walked_to := planted_at + Vector2(26.0, 0.0)
		prototype.player.global_position = prototype.territory_field.to_global(walked_to)
		adaptations.advance(1.0 / 60.0)
		_check(
			carried_turret.carried
			and carried_turret.position.distance_to(walked_to) < 0.01,
			"a carried Thistle travels with Grandma instead of holding its plot"
		)

		# Ride it out. It drops onto supporting Green and starts its cooldown.
		var carry_ticks := int(adaptations.get_thistle_carry_seconds() * 60.0) + 4
		for _tick in range(carry_ticks):
			adaptations.advance(1.0 / 60.0)
		_check(
			not carried_turret.carried
			and carried_turret.active
			and carried_turret.stick_cooldown_remaining > 0.0,
			"the Thistle works loose after its carry and cannot be picked straight back up"
		)
		_check(
			carried_turret.position.distance_to(planted_at) > 0.01,
			"the dropped Thistle takes root where it was carried to"
		)

		# Off the Green it withers instead of following her around forever.
		carried_turret.stick_cooldown_remaining = 0.0
		prototype.player.global_position = prototype.territory_field.to_global(
			carried_turret.position
		)
		adaptations.advance(1.0 / 60.0)
		var recaught := carried_turret.carried
		prototype.player.global_position = prototype.territory_field.to_global(
			Vector2(-4000.0, -4000.0)
		)
		for _tick in range(carry_ticks):
			adaptations.advance(1.0 / 60.0)
		_check(
			recaught and not carried_turret.active,
			"a Thistle dropped off supporting Green withers rather than replanting"
		)

		# Losing the turret costs real time, whichever way it was lost. Walk her back
		# onto the Green first, so what is being measured is the replant delay rather
		# than the absence of anywhere to replant.
		prototype.player.global_position = prototype.territory_field.to_global(planted_at)
		var early_ticks := int(adaptations.thistle_replant_seconds * 0.5 * 60.0)
		for _tick in range(early_ticks):
			adaptations.advance(1.0 / 60.0)
		var regrew_early := adaptations.get_active_thistle_count() > 0
		for _tick in range(int(adaptations.thistle_replant_seconds * 60.0) + 6):
			adaptations.advance(1.0 / 60.0)
		_check(
			not regrew_early and adaptations.get_active_thistle_count() > 0,
			"a lost Thistle leaves the ground bare for its replant delay before regrowing"
		)

	prototype.queue_free()
	await process_frame
	if _failures == 0:
		print("THISTLE_SPACING_PROBE: PASS")
		quit(0)
	else:
		push_error("THISTLE_SPACING_PROBE: %d failure(s)" % _failures)
		quit(1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		push_error("FAIL: %s" % description)
