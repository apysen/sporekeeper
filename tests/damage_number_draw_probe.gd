extends SceneTree

## What drawing a screenful of damage numbers actually costs, in a real renderer.
##
## Every other probe here is headless, and `_draw` does not run headless -- the draw
## timers read exactly zero there. So the cost of the damage-number presentation has
## never been measured at all, only its slot allocation. This fills the pool, renders
## real frames, and reports the two parts separately: the string measurement, which
## is recomputed every frame for text that never changes, and everything else.
##
## Needs a display. Run without --headless:
##   godot --path . --script tests/damage_number_draw_probe.gd

const RENDER_FRAMES := 240


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
	prototype.player.input_enabled = false

	var combat := prototype.combat
	combat.reset_combat()

	# Every slot carrying a number, refilled as they expire, which is what a large
	# AoE landing on a crowd produces and the only state where the draw cost matters.
	var random := RandomNumberGenerator.new()
	random.seed = 20260830
	var pool_size := combat._damage_numbers.size()

	# Two passes over the same fixture. The second gives a share of the numbers a
	# larger point size, which is what "criticals read bigger" means in practice, so
	# the comparison answers whether mixing sizes costs anything rather than whether
	# drawing text costs anything.
	await _measure_pass(prototype, combat, random, pool_size, "uniform", 0.0)
	await _measure_pass(prototype, combat, random, pool_size, "mixed 20% crit", 0.20)

	prototype.queue_free()
	await process_frame
	quit(0)


func _measure_pass(
	prototype: RunRoot,
	combat: CombatDirector,
	random: RandomNumberGenerator,
	pool_size: int,
	label: String,
	critical_share: float
) -> void:
	combat.reset_combat()
	var draw_samples := PackedFloat32Array()
	var measure_samples := PackedFloat32Array()
	var frame_samples := PackedFloat32Array()

	PerfCounters.begin_session()
	for frame_index in range(RENDER_FRAMES):
		PerfCounters.reset_frame()
		# Replace only what expired. Spawning the whole pool every frame would make
		# spawn and draw happen equally often, which is not how these behave: a number
		# lives for damage_number_lifetime_seconds, so it is spawned once and drawn for
		# every frame of that. Measuring the refill rate wrong would make per-spawn
		# work look far more expensive relative to per-draw work than it is.
		var deficit := 0
		for damage_number in combat._damage_numbers:
			if not damage_number.active:
				deficit += 1
		for _refill in range(deficit):
			# Spawned as an actual critical rather than merely at the critical's point
			# size. The size is the cheap half of the difference; the outline it also
			# draws is eight more quads per glyph, and that is the half worth
			# measuring.
			var critical := random.randf() < critical_share
			combat._spawn_damage_number(
				Vector2(
					random.randf_range(60.0, 840.0),
					random.randf_range(60.0, 460.0)
				),
				random.randf_range(4.0, 20.0),
				random.randf_range(1.0, 99999.0),
				(
					combat.damage_number_critical_color if critical
					else Color(random.randf(), random.randf(), random.randf())
				),
				critical
			)
		combat.queue_redraw()
		var began := Time.get_ticks_usec()
		await process_frame
		frame_samples.append(float(Time.get_ticks_usec() - began) / 1000.0)
		draw_samples.append(
			PerfCounters.get_timer_ms(
				PerfCounters.TIMER_DAMAGE_NUMBER_DRAW
			)
		)
		measure_samples.append(
			PerfCounters.get_timer_ms(
				PerfCounters.TIMER_DAMAGE_NUMBER_MEASURE
			)
		)
	PerfCounters.end_session()

	var active := 0
	for damage_number in combat._damage_numbers:
		if damage_number.active:
			active += 1

	print(
		"DAMAGE_NUMBER_DRAW %-16s pool=%d active=%d renderer=%s" % [
			label,
			pool_size,
			active,
			ProjectSettings.get_setting(
				"rendering/renderer/rendering_method", "unknown"
			),
		]
	)
	print(
		"    draw    median %6.3fms  p99 %6.3fms"
		% [_median(draw_samples), _percentile_of(draw_samples, 0.99)]
	)
	print(
		"    measure median %6.3fms  p99 %6.3fms"
		% [_median(measure_samples), _percentile_of(measure_samples, 0.99)]
	)
	print(
		"    frame   median %6.3fms  p99 %6.3fms"
		% [_median(frame_samples), _percentile_of(frame_samples, 0.99)]
	)


func _median(samples: PackedFloat32Array) -> float:
	return _percentile_of(samples, 0.50)


func _percentile_of(samples: PackedFloat32Array, fraction: float) -> float:
	if samples.is_empty():
		return 0.0
	var sorted := samples.duplicate()
	sorted.sort()
	var index := clampi(
		ceili(clampf(fraction, 0.0, 1.0) * float(sorted.size())) - 1,
		0,
		sorted.size() - 1
	)
	return sorted[index]
