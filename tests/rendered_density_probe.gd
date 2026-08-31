extends SceneTree

## What a real frame costs at density, with the picture actually being drawn.
##
## Every other performance probe here drives the simulation by hand and never
## renders. That was the right way to find the algorithmic problems, and it found
## seven, but it means the guide's requirement that rendered performance be
## validated rather than inferred has gone unmet: `_draw` does not run headless, so
## every draw timer in the suite reads exactly zero.
##
## This one lets the engine run the frame. It reports the whole frame, the part of
## it spent in the combat director's `_draw`, and the enemy and damage-number
## layers inside that -- so a rendered regression can be attributed rather than
## just noticed.
##
## It asserts nothing. Rendered numbers depend on the machine, the driver and the
## window size in a way the headless gate does not, so this is a measurement to be
## read next to the headless table, not a pass/fail to be wired into CI.
##
## Needs a display. Run without --headless:
##   godot --path . --script tests/rendered_density_probe.gd
##   godot --path . --script tests/rendered_density_probe.gd -- --densities=130,200

const SAMPLE_FRAMES := 300
## Frames discarded before sampling, for the same reason the headless ladder does
## it: the first volley and the pools reaching working size are not steady state.
const WARMUP_FRAMES := 45

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

var _densities := PackedInt32Array([130, 200])
var _viewport_rid: RID


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--densities="):
			var wanted := PackedInt32Array()
			for piece in argument.trim_prefix("--densities=").split(",", false):
				var value := int(piece.strip_edges())
				if value > 0:
					wanted.append(value)
			if not wanted.is_empty():
				_densities = wanted

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
	# The scene runs itself here. That is the point: this measures the frame the
	# engine actually produces, not a hand-driven reconstruction of one.
	prototype.player.input_enabled = false
	prototype.player.maximum_health = 1000000000.0
	prototype.player.reset_player()
	# Vsync would put the wait for the next vblank inside the frame time and hide
	# what the frame actually costs. The draw timers are unaffected either way, but
	# the frame column is meaningless with it on.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Splitting the frame into render and not-render is the whole point of running
	# this at all: without it a heavy rendered frame cannot be told apart from a
	# heavy simulated one. render_timing_support_probe confirms both halves are real
	# on this project's renderer.
	_viewport_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport_rid, true)

	print(
		"RENDERED_DENSITY: renderer=%s window=%s vsync=%d"
		% [
			ProjectSettings.get_setting(
				"rendering/renderer/rendering_method", "unknown"
			),
			DisplayServer.window_get_size(),
			DisplayServer.window_get_vsync_mode(),
		]
	)
	print(
		"RENDERED_DENSITY %5s %9s %9s %8s %8s %8s %8s %7s %8s"
		% [
			"n", "frame p50", "frame p99", "rndCPU", "rndGPU", "combat", "enemy",
			"draws", "prims",
		]
	)
	for density in _densities:
		await _run_density(prototype, density)

	prototype.queue_free()
	await process_frame
	quit(0)


func _run_density(prototype: PhaseBPrototype, density: int) -> void:
	var combat := prototype.combat
	if density > combat.enemy_pool_size:
		combat.enemy_pool_size = density
		combat._configure_pools()
	combat.maximum_active_enemies = density

	prototype.reset_run()
	# A drafted, evolved build, so the picture under test is the one the game
	# actually renders in a late run: thorns in flight, Fruit rolling, territory
	# being painted, and damage numbers over the whole crowd. Without this the
	# fixture draws a still life and the damage-number layer reads zero.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		PhaseBProgression.PathId.THISTLE, PhaseBProgression.PathId.FRUIT
	)
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	for upgrade_id in range(PhaseBProgression.UpgradeId.size()):
		var path_id := prototype.progression._get_upgrade_path(upgrade_id)
		if prototype.progression.has_path(path_id):
			prototype.progression._upgrade_levels[upgrade_id] = (
				prototype.progression.maximum_upgrade_level
			)
	prototype._apply_progression_modifiers()
	prototype.relic_director.apply_relics()
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
	# Unkillable, so the crowd on screen holds at the target for the whole sample.
	for enemy in combat._enemies:
		if not enemy.active:
			continue
		enemy.maximum_health = 1000000000.0
		enemy.health = enemy.maximum_health

	for _warmup in range(WARMUP_FRAMES):
		await process_frame

	var frame_samples := PackedFloat32Array()
	var draw_samples := PackedFloat32Array()
	var enemy_samples := PackedFloat32Array()
	var damage_number_samples := PackedFloat32Array()
	var render_cpu_samples := PackedFloat32Array()
	var render_gpu_samples := PackedFloat32Array()
	var draw_call_samples := PackedInt32Array()
	var primitive_samples := PackedInt32Array()

	PhaseBPerfCounters.begin_session()
	for _frame in range(SAMPLE_FRAMES):
		PhaseBPerfCounters.reset_frame()
		var began := Time.get_ticks_usec()
		await process_frame
		frame_samples.append(float(Time.get_ticks_usec() - began) / 1000.0)
		draw_samples.append(
			PhaseBPerfCounters.get_timer_ms(PhaseBPerfCounters.TIMER_COMBAT_DRAW)
		)
		enemy_samples.append(
			PhaseBPerfCounters.get_timer_ms(PhaseBPerfCounters.TIMER_ENEMY_DRAW)
		)
		damage_number_samples.append(
			PhaseBPerfCounters.get_timer_ms(
				PhaseBPerfCounters.TIMER_DAMAGE_NUMBER_DRAW
			)
		)
		render_cpu_samples.append(
			RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid)
		)
		render_gpu_samples.append(
			RenderingServer.viewport_get_measured_render_time_gpu(_viewport_rid)
		)
		draw_call_samples.append(
			RenderingServer.viewport_get_render_info(
				_viewport_rid,
				RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,
				RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
			)
		)
		primitive_samples.append(
			RenderingServer.viewport_get_render_info(
				_viewport_rid,
				RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,
				RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME
			)
		)
	PhaseBPerfCounters.end_session()

	var frame_median := _percentile_of(frame_samples, 0.50)
	var render_cpu_median := _percentile_of(render_cpu_samples, 0.50)
	var render_gpu_median := _percentile_of(render_gpu_samples, 0.50)
	print(
		"RENDERED_DENSITY %5d %8.3f %8.3f %7.3f %7.3f %7.3f %7.3f %7d %8d" % [
			combat.get_active_enemy_count(),
			frame_median,
			_percentile_of(frame_samples, 0.99),
			render_cpu_median,
			render_gpu_median,
			_percentile_of(draw_samples, 0.50),
			_percentile_of(enemy_samples, 0.50),
			_median_int(draw_call_samples),
			_median_int(primitive_samples),
		]
	)
	# The part of the frame that is not the renderer and not the combat director's
	# own drawing. If this dominates, a rendering optimisation cannot reach it.
	print(
		"RENDERED_DENSITY       of which render %.3fms (%.0f%%), not-render %.3fms (%.0f%%)"
		% [
			render_cpu_median + render_gpu_median,
			100.0 * (render_cpu_median + render_gpu_median) / maxf(0.001, frame_median),
			frame_median - render_cpu_median - render_gpu_median,
			100.0
			* (frame_median - render_cpu_median - render_gpu_median)
			/ maxf(0.001, frame_median),
		]
	)


func _median_int(samples: PackedInt32Array) -> int:
	if samples.is_empty():
		return 0
	var sorted := samples.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


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
