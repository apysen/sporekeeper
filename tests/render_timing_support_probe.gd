extends SceneTree

## Does this project's renderer actually report GPU frame time?
##
## The third-pass guide's Phase 0 branches its whole interpretation on the split
## between render CPU and render GPU: high CPU with low GPU means one fix, high GPU
## means a different one. That decision tree is worthless if the GPU number is not
## real, and `viewport_get_measured_render_time_gpu` is documented as unreliable on
## some drivers -- GL Compatibility especially, which is what this project ships.
##
## So this answers the question before anything is built on the assumption. It
## renders a real frame under load, reads both halves, and says plainly whether the
## GPU figure is present, plausible and responsive to load.
##
## "Responsive" is the part that matters. A driver can return a fixed nonzero
## constant, or the CPU number again, either of which looks like success. So the
## probe renders a light scene and a heavy one and reports whether the GPU figure
## moved between them.
##
## Needs a display. Run without --headless, once per renderer:
##   godot --path . --script tests/render_timing_support_probe.gd
##   godot --path . --rendering-method forward_plus --script tests/render_timing_support_probe.gd
##   godot --path . --rendering-method mobile --script tests/render_timing_support_probe.gd

const WARMUP_FRAMES := 60
const SAMPLE_FRAMES := 180
## Enough enemies that the heavy pass is unmistakably more work than the light one.
const HEAVY_ENEMIES := 200

const STRESS_ROLES := [
	PhaseBCombatDirector.EnemyRole.HUNTER,
	PhaseBCombatDirector.EnemyRole.GRAZER,
	PhaseBCombatDirector.EnemyRole.HEAVY_GRAZER,
	PhaseBCombatDirector.EnemyRole.RUSHER,
	PhaseBCombatDirector.EnemyRole.SABOTEUR,
	PhaseBCombatDirector.EnemyRole.CORRUPTOR,
	PhaseBCombatDirector.EnemyRole.COLONIZER,
	PhaseBCombatDirector.EnemyRole.WARDEN,
	PhaseBCombatDirector.EnemyRole.SIEGE_CORRUPTOR,
]

var _viewport_rid: RID


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
	prototype.player.input_enabled = false
	prototype.player.maximum_health = 1000000000.0
	prototype.player.reset_player()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	_viewport_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport_rid, true)
	# Measurement is not retroactive and the first frames after enabling it can read
	# zero while the timing queries fill, so nothing is sampled until well after.
	for _settle in range(WARMUP_FRAMES):
		await process_frame

	print(
		"RENDER_TIMING: configured=%s active=%s adapter=%s window=%s"
		% [
			ProjectSettings.get_setting(
				"rendering/renderer/rendering_method", "unknown"
			),
			_active_rendering_method(),
			RenderingServer.get_video_adapter_name(),
			DisplayServer.window_get_size(),
		]
	)

	var light := await _sample(prototype, 0, "light (no enemies)")
	var heavy := await _sample(prototype, HEAVY_ENEMIES, "heavy (%d enemies)" % HEAVY_ENEMIES)

	_report(light, heavy)

	RenderingServer.viewport_set_measure_render_time(_viewport_rid, false)
	prototype.queue_free()
	await process_frame
	quit(0)


func _sample(prototype: PhaseBPrototype, density: int, label: String) -> Dictionary:
	var combat := prototype.combat
	if density > combat.enemy_pool_size:
		combat.enemy_pool_size = density
		combat._configure_pools()
	combat.maximum_active_enemies = maxi(1, density)
	prototype.reset_run()
	combat.reset_combat()
	prototype.territory_field.reset_field()

	var origin := Vector2(320.0, 300.0)
	prototype.player.global_position = prototype.territory_field.to_global(origin)
	for index in range(density):
		var ring := 30.0 + float(index % 7) * 22.0
		combat.spawn_enemy(
			STRESS_ROLES[index % STRESS_ROLES.size()],
			origin + Vector2.from_angle(float(index) * 2.39996) * ring
		)
	for enemy in combat._enemies:
		if enemy.active:
			enemy.maximum_health = 1000000000.0
			enemy.health = enemy.maximum_health

	for _warmup in range(WARMUP_FRAMES):
		await process_frame

	var frame := PackedFloat32Array()
	var cpu := PackedFloat32Array()
	var gpu := PackedFloat32Array()
	var draw_calls := PackedInt32Array()
	var objects := PackedInt32Array()
	var primitives := PackedInt32Array()

	for _sample_index in range(SAMPLE_FRAMES):
		var began := Time.get_ticks_usec()
		await process_frame
		frame.append(float(Time.get_ticks_usec() - began) / 1000.0)
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(_viewport_rid))
		draw_calls.append(_canvas_info(RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		objects.append(_canvas_info(RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME))
		primitives.append(_canvas_info(RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))

	var result := {
		"label": label,
		"frame": _median(frame),
		"cpu": _median(cpu),
		"gpu": _median(gpu),
		"gpu_max": _maximum(gpu),
		"gpu_nonzero": _count_above(gpu, 0.0001),
		"draw_calls": _median_int(draw_calls),
		"objects": _median_int(objects),
		"primitives": _median_int(primitives),
		"samples": SAMPLE_FRAMES,
	}
	print(
		"RENDER_TIMING %-24s frame %6.3f  cpu %6.3f  gpu %6.3f  draws %5d  objects %6d  prims %7d"
		% [
			label,
			result["frame"],
			result["cpu"],
			result["gpu"],
			result["draw_calls"],
			result["objects"],
			result["primitives"],
		]
	)
	return result


func _active_rendering_method() -> String:
	## ProjectSettings reports what the project asks for, not what is running, so a
	## --rendering-method override on the command line would be invisible. Only the
	## RenderingDevice-backed methods expose a device, which separates Forward+ and
	## Mobile from GL Compatibility.
	if RenderingServer.get_rendering_device() == null:
		return "gl_compatibility"
	return "forward_plus/mobile (RenderingDevice present)"


func _canvas_info(info: int) -> int:
	return RenderingServer.viewport_get_render_info(
		_viewport_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, info
	)


func _report(light: Dictionary, heavy: Dictionary) -> void:
	print("")
	var gpu_present: bool = int(heavy["gpu_nonzero"]) > 0
	var gpu_moved := absf(float(heavy["gpu"]) - float(light["gpu"])) > 0.05
	var gpu_tracks_cpu := (
		absf(float(heavy["gpu"]) - float(heavy["cpu"])) < 0.001
		and absf(float(light["gpu"]) - float(light["cpu"])) < 0.001
	)
	var draws_moved: bool = int(heavy["draw_calls"]) != int(light["draw_calls"])

	print(
		"RENDER_TIMING: gpu reported on %d of %d heavy frames"
		% [heavy["gpu_nonzero"], heavy["samples"]]
	)
	print(
		"RENDER_TIMING: gpu light %.3fms -> heavy %.3fms (max %.3fms)"
		% [light["gpu"], heavy["gpu"], heavy["gpu_max"]]
	)
	print(
		"RENDER_TIMING: canvas draw calls light %d -> heavy %d"
		% [light["draw_calls"], heavy["draw_calls"]]
	)
	print("")

	if not gpu_present:
		print(
			"RENDER_TIMING: VERDICT gpu timing UNAVAILABLE on this renderer. The "
			+ "guide's Phase 0 CPU-vs-GPU decision tree cannot be driven from it."
		)
	elif gpu_tracks_cpu:
		print(
			"RENDER_TIMING: VERDICT gpu timing MIRRORS cpu exactly, so it is not a "
			+ "real GPU measurement. Treat it as unavailable."
		)
	elif not gpu_moved:
		print(
			"RENDER_TIMING: VERDICT gpu timing is present but did not respond to a "
			+ "large change in load, so it is not trustworthy as a bottleneck signal."
		)
	else:
		print(
			"RENDER_TIMING: VERDICT gpu timing is USABLE -- present, distinct from "
			+ "cpu, and it moved with load."
		)

	if draws_moved:
		print(
			"RENDER_TIMING: canvas render info is usable and responds to load, so "
			+ "draw calls/objects/primitives can carry the analysis regardless."
		)
	else:
		print(
			"RENDER_TIMING: canvas render info did NOT respond to load. Check that "
			+ "the counts are being read from the right viewport."
		)


func _median(samples: PackedFloat32Array) -> float:
	if samples.is_empty():
		return 0.0
	var sorted := samples.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func _median_int(samples: PackedInt32Array) -> int:
	if samples.is_empty():
		return 0
	var sorted := samples.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func _maximum(samples: PackedFloat32Array) -> float:
	var largest := 0.0
	for value in samples:
		largest = maxf(largest, value)
	return largest


func _count_above(samples: PackedFloat32Array, threshold: float) -> int:
	var count := 0
	for value in samples:
		if value > threshold:
			count += 1
	return count
