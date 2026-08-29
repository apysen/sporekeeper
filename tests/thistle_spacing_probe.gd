extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_error := change_scene_to_file("res://scenes/run/phase_b_prototype.tscn")
	if load_error != OK:
		push_error("Unable to load Phase B prototype: %s" % error_string(load_error))
		quit(1)
		return
	await process_frame
	await process_frame
	var prototype := current_scene as PhaseBPrototype
	if prototype == null:
		push_error("Phase B prototype scene did not become current")
		quit(1)
		return
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype._set_simulation_paused(true)

	prototype.progression.reset_progression()
	prototype.territory_field.reset_field()
	prototype.adaptation_director.reset_adaptations()
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.THISTLE,
		PhaseBProgression.PathId.VINE
	)
	prototype._apply_progression_modifiers()
	prototype.adaptation_director.advance(1.0 / 60.0)

	var positions := PackedVector2Array()
	for thistle in prototype.adaptation_director._thistles:
		if thistle.active and thistle.permanent:
			positions.append(thistle.position)
	_check(positions.size() == 2, "choosing Thistle plants its initial pair")
	if positions.size() == 2:
		_check(
			positions[0].distance_to(positions[1])
			>= prototype.adaptation_director.thistle_minimum_spacing_pixels - 0.01,
			"the initial Thistles reserve separate visual footprints"
		)

	var overlap_attempt := prototype.adaptation_director._plant_thistle(
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
