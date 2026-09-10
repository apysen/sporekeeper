extends SceneTree

## How many enemies are actually alive at each point in a Campaign run.
##
## Spawn rate is not density: enemies die. What decides whether a run reads as a
## swarm is the concurrent count, which is spawn rate minus kill rate against a
## hard ceiling. This simulates a real run with the Cane defending itself and
## samples what is standing, so the answer is measured rather than inferred.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/run/run.tscn")
	await process_frame
	await process_frame
	var p := current_scene as RunRoot
	p.set_process(false)
	p.player.input_enabled = false
	p.combat.set_process(false)
	p.adaptation_director.set_process(false)
	p.overlay.set_process(false)
	p.wave_director.configure_mode(RunMode.Id.CAMPAIGN)
	p.reset_run()
	p.wave_director.configure_mode(RunMode.Id.CAMPAIGN)
	# A run opens by asking for its first Core Adaptation, and the chooser pauses the
	# simulation until it is answered. The measurement is about spawn pressure, so it
	# answers with a full roster and gets on with it.
	p.progression.debug_select_paths(
		Progression.PathId.SPORE,
		Progression.PathId.ROOT
	)
	p.progression.debug_select_branch_paths(
		Progression.PathId.BRAMBLE,
		Progression.PathId.THISTLE
	)
	# The player cannot die out from under the measurement; what is being measured
	# is the pressure the run produces, not how long a passive player survives.
	p.player.maximum_health = 1000000.0
	p.player.heal(1000000.0)

	var step := 1.0 / 30.0
	var minutes := 16
	var next_sample := 30.0
	var elapsed := 0.0
	var peak := 0
	print("CAMPAIGN_DENSITY: cap=%d" % p.combat.maximum_active_enemies)
	while elapsed < float(minutes) * 60.0:
		elapsed += step
		p.advance_run(step)
		p.combat.simulate_step(step)
		p.adaptation_director.advance(step)
		if int(elapsed * 30.0) % 4 == 0:
			p.territory_field.step_simulation()
		peak = maxi(peak, p.combat.get_active_enemy_count())
		if elapsed >= next_sample:
			next_sample += 30.0
			print("  t=%5.1fm alive=%3d peak=%3d wave=%d" % [
				elapsed / 60.0,
				p.combat.get_active_enemy_count(),
				peak,
				p.wave_director.get_current_wave_number(),
			])
	quit(0)
