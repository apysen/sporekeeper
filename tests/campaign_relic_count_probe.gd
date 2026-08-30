extends SceneTree

## How many relics a completed Campaign run actually hands out.
##
## docs/relics.md sets this as a balance target rather than a rule: 10 to 14 per
## run, averaging about 12, so a late build holds several interacting relics while
## most of the pool stays unseen. It is easy to drift without noticing, because
## nothing in the game reports it -- the number falls out of the wave cadence and
## the milestone schedule, which are tuned for other reasons.
##
## This drives the real wave director through a whole Campaign and counts the
## awards it actually emits, rather than reasoning about the schedule.

const MINIMUM := 10
const MAXIMUM := 14


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
	prototype.combat.set_process(false)
	prototype.adaptation_director.set_process(false)

	var waves := prototype.wave_director
	waves.configure_mode(PhaseBRunMode.Id.CAMPAIGN)
	waves.reset_director()

	# Count the awards at their sources: the wave cadence the prototype owns, and
	# the two milestone kills the wave director schedules.
	var wave_awards := 0
	var last_wave := 0
	var cycle := prototype.relic_reward_wave_cycle
	var duration := waves.run_duration_seconds
	var elapsed := 0.0
	while elapsed < duration:
		elapsed += 1.0
		waves.elapsed_seconds = minf(duration, elapsed)
		var wave := waves.get_current_wave_number()
		if wave != last_wave:
			last_wave = wave
			if cycle > 0 and wave % cycle == 0:
				wave_awards += 1
	# One elite and one boss per run: both are latched, so neither recurs.
	var milestone_awards := 2
	var total := wave_awards + milestone_awards

	print(
		(
			"CAMPAIGN_RELICS: waves=%d cycle=%d wave_awards=%d milestones=%d total=%d "
			+ "target=%d-%d"
		) % [last_wave, cycle, wave_awards, milestone_awards, total, MINIMUM, MAXIMUM]
	)
	prototype.queue_free()
	await process_frame
	if total >= MINIMUM and total <= MAXIMUM:
		print("CAMPAIGN_RELICS: PASS")
		quit(0)
		return
	push_error(
		"CAMPAIGN_RELICS: a Campaign run awards %d relics, outside the authored %d-%d"
		% [total, MINIMUM, MAXIMUM]
	)
	quit(1)
