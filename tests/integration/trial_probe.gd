extends SceneTree

## Does a Trial actually start, hold, break and pay?
##
## The four things a Trial has to do are: appear on the wave the table says, be
## judged by its own rule rather than by whether the wave went well, owe a relic when
## it is held, and owe nothing at all when it is broken. That last one is the
## contract - section 27 is explicit that failing a Trial must not cost the run
## anything - and it is the one a future change is most likely to break quietly.
##
## Run: godot --headless --path . --script tests/integration/trial_probe.gd

const STEP := 1.0 / 60.0

var _failures: Array[String] = []
var _checks := 0


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
	prototype.combat.set_process(false)

	_check_wave_table()
	_check_trials_are_occasional(prototype)
	_check_scaling_rules()
	_check_every_rule_reads(prototype)
	_check_hold_pays(prototype)
	_check_break_costs_nothing(prototype)
	_check_arming_and_slack(prototype)
	_check_goals(prototype)
	_check_cull_measures_the_board()

	prototype.queue_free()
	await process_frame
	if _failures.is_empty():
		print("TRIAL: PASS (%d checks)" % _checks)
		quit(0)
		return
	for line in _failures:
		print(line)
	push_error("TRIAL: %d failure(s)" % _failures.size())
	quit(1)


func _check_wave_table() -> void:
	## Where a Trial is *allowed* to appear -- never during Germination, and never on a
	## wave that already owes a milestone, because a relic landing in the same breath as
	## a Trial's relic reads as one reward rather than two. Whether one actually appears
	## is a roll, and `_check_trials_are_occasional` covers that.
	_checks += 1
	var specs := CampaignWaves.build_wave_specs()
	var trial_waves := PackedInt32Array()
	for spec in specs:
		if spec.grants_trial:
			trial_waves.append(spec.wave_index)
	if trial_waves.is_empty():
		_failures.append("TRIAL: no wave in the Campaign carries a Trial")
		return
	for wave in trial_waves:
		var spec := specs[wave - 1]
		if spec.act == CampaignWaves.Act.GERMINATION:
			_failures.append(
				"TRIAL: wave %d carries a Trial during Germination, before there is a "
				% wave + "build for a rule to constrain"
			)
			return
		if spec.grants_wave_relic or spec.grants_evolution_reward:
			_failures.append(
				"TRIAL: wave %d owes a Trial and another reward at once" % wave
			)
			return
		if spec.grants_path_draft:
			_failures.append(
				"TRIAL: wave %d owes a Trial and an Adaptation draft at once" % wave
			)
			return
		if (
			spec.elite_spawn_second >= 0.0
			or spec.boss_spawn_second >= 0.0
			or spec.hive_queen_spawn_second >= 0.0
		):
			_failures.append(
				"TRIAL: wave %d sets a rule about how to play a wave a boss walks into"
				% wave
			)
			return
	print(
		"TRIAL      Trials may appear on %s, none in Act I, none doubled up"
		% str(trial_waves)
	)


func _check_trials_are_occasional(prototype: RunRoot) -> void:
	## A Trial is meant to be an event, not an appointment. What this holds to is the
	## two ends of the roll -- that the run can decline to set one at all, and that it
	## stops at its own cap however many eligible waves go by -- because the interesting
	## middle is a random variable and a test that asserts on one is a test that fails
	## on a Tuesday.
	_checks += 1
	var eligible: Array = CampaignWaves.TRIAL_ELIGIBLE_WAVES
	var chance_before := prototype.trial_chance

	prototype.trial_chance = 0.0
	prototype._trials_offered = 0
	prototype._trial_director.reset_trials()
	for wave in eligible:
		prototype._on_trial_wave_began(int(wave))
	if prototype._trials_offered != 0:
		_failures.append(
			"TRIAL: a run that rolled against every Trial still set %d"
			% prototype._trials_offered
		)
		prototype.trial_chance = chance_before
		return

	prototype.trial_chance = 1.0
	prototype._trials_offered = 0
	for wave in eligible:
		prototype._on_trial_wave_began(int(wave))
	var cap := mini(prototype.maximum_trials_per_run, eligible.size())
	if prototype._trials_offered != cap:
		_failures.append(
			"TRIAL: %d eligible waves at certainty set %d Trials rather than %d"
			% [eligible.size(), prototype._trials_offered, cap]
		)
		prototype.trial_chance = chance_before
		return

	prototype.trial_chance = chance_before
	prototype._trials_offered = 0
	prototype._trial_director.reset_trials()
	print(
		"TRIAL      %d eligible waves, at most %d a run, none of them guaranteed"
		% [eligible.size(), cap]
	)


func _check_scaling_rules() -> void:
	## Three rules count something the wave itself produces, and the wave produces
	## roughly twice as much of it by Wave 16 as by Wave 6. What this guards is that
	## the number on the card moves with it -- and that the sentence the player reads
	## is the sentence they are judged by, which is the failure that would be invisible
	## in play until someone lost a Trial they had met.
	_checks += 1
	var scaling := [
		TrialCatalog.Id.FRENZY,
		TrialCatalog.Id.PRESSURE,
		TrialCatalog.Id.GROUNDWORK,
	]
	for trial_id in scaling:
		var early := TrialCatalog.get_value(trial_id, 6)
		var late := TrialCatalog.get_value(trial_id, 16)
		if late <= early:
			_failures.append(
				"TRIAL: %s asks the same on Wave 16 as on Wave 6 (%.0f)"
				% [TrialCatalog.get_trial_name(trial_id), early]
			)
			return
		if TrialCatalog.get_rule(trial_id, 16) == TrialCatalog.get_rule(trial_id, 6):
			_failures.append(
				"TRIAL: %s prints Wave 6's number on Wave 16"
				% TrialCatalog.get_trial_name(trial_id)
			)
			return
	# And the rest must not move, or a rule about a percentage of the arena would
	# quietly ask for more than the arena has.
	for trial_id in range(TrialCatalog.get_count()):
		if scaling.has(trial_id):
			continue
		if not is_equal_approx(
			TrialCatalog.get_value(trial_id, 6), TrialCatalog.get_value(trial_id, 16)
		):
			_failures.append(
				"TRIAL: %s scales with the wave and should not"
				% TrialCatalog.get_trial_name(trial_id)
			)
			return
	print("TRIAL      the counted rules grow with the wave and the rest do not")


func _check_every_rule_reads(prototype: RunRoot) -> void:
	## Every Trial in the catalogue has to produce its three sentences with their
	## numbers already in them, and a progress line that does not crash on a board it
	## has never seen.
	_checks += 1
	var director := prototype._trial_director
	for trial_id in range(TrialCatalog.get_count()):
		# The rule on the card and the whole rule in its tooltip. Either left as a
		# template would print a brace at the player.
		for line in [
			TrialCatalog.get_rule(trial_id),
			TrialCatalog.get_detail(trial_id),
		]:
			if line.is_empty() or line.contains("{"):
				_failures.append(
					"TRIAL: %s prints an unfinished line: '%s'"
					% [TrialCatalog.get_trial_name(trial_id), line]
				)
				return
		# Read in a glance mid-fight, so it is held to five words.
		var words := TrialCatalog.get_rule(trial_id, 16).split(" ", false).size()
		if words > 5:
			_failures.append(
				"TRIAL: %s's card rule runs to %d words"
				% [TrialCatalog.get_trial_name(trial_id), words]
			)
			return
		# A live rule has to be able to say what is going wrong over Grandma.
		if (
			TrialCatalog.get_judgement(trial_id) == TrialCatalog.Judgement.CONTINUOUS
			and (TrialCatalog.get_warning(trial_id).is_empty() or TrialCatalog.get_slack(trial_id) <= 0.0)
		):
			_failures.append(
				"TRIAL: %s is judged live with no warning or no slack"
				% TrialCatalog.get_trial_name(trial_id)
			)
			return
		director.begin_trial(trial_id)
		var progress := director.get_progress_text()
		if progress.is_empty():
			_failures.append(
				"TRIAL: %s has no progress line" % TrialCatalog.get_trial_name(trial_id)
			)
			return
	director.reset_trials()
	print("TRIAL      all %d rules print finished sentences and a progress line"
		% TrialCatalog.get_count())


func _check_hold_pays(prototype: RunRoot) -> void:
	## A Trial nobody breaks pays a relic.
	_checks += 1
	var director := prototype._trial_director
	prototype._owed_trial_relics = 0
	director.begin_trial(TrialCatalog.Id.UNTOUCHED)
	for _step in range(30):
		director.advance(STEP)
	director.resolve_trial()
	# The relic is owed and waiting on the card, not handed over: the payout is a button
	# now, because a boundary queue could bury it.
	if not director.is_reward_unclaimed():
		_failures.append("TRIAL: a held Trial left nothing on the card to claim")
		return
	if prototype._owed_trial_relics != 1:
		_failures.append(
			"TRIAL: holding a Trial owed %d relics rather than 1"
			% prototype._owed_trial_relics
		)
		return
	# And pressing it pays. Emitted directly rather than clicked, because what this
	# holds is that a claim reaches the reward queue -- where the pointer was is the
	# panel's business.
	director.reward_claimed.emit(TrialCatalog.Id.UNTOUCHED)
	if prototype._owed_trial_relics != 0:
		_failures.append("TRIAL: claiming the reward did not spend what the Trial owed")
		return
	print("TRIAL      a held Trial owes its relic, and the card pays it when pressed")


func _check_break_costs_nothing(prototype: RunRoot) -> void:
	## A broken Trial owes nothing, and costs nothing: no health, no territory, no
	## end to the run. The whole point of the mechanic is that it can be declined
	## halfway through.
	_checks += 1
	var director := prototype._trial_director
	prototype._owed_trial_relics = 0
	var health_before := prototype.player.get_health()
	var green_before := prototype.territory_field.get_player_percent()
	var state_before := prototype.get_run_state()

	director.begin_trial(TrialCatalog.Id.UNTOUCHED)
	_run_past_arming(director)
	for _hit in range(roundi(TrialCatalog.get_value(TrialCatalog.Id.UNTOUCHED)) + 1):
		director.note_damage_taken()
	if director.get_state() != TrialDirector.State.BROKEN:
		_failures.append("TRIAL: one hit past the allowance did not break Untouched")
		return
	director.resolve_trial()

	if prototype._owed_trial_relics != 0:
		_failures.append("TRIAL: a broken Trial still paid a relic")
		return
	if not is_equal_approx(prototype.player.get_health(), health_before):
		_failures.append("TRIAL: breaking a Trial cost health")
		return
	if not is_equal_approx(
		prototype.territory_field.get_player_percent(), green_before
	):
		_failures.append("TRIAL: breaking a Trial cost territory")
		return
	if prototype.get_run_state() != state_before:
		_failures.append("TRIAL: breaking a Trial changed the run state")
		return
	print("TRIAL      a broken Trial pays nothing and costs nothing")


func _run_past_arming(director: TrialDirector) -> void:
	for _step in range(ceili(TrialDirector.ARMING_SECONDS / STEP) + 1):
		director.advance(STEP)


func _check_arming_and_slack(prototype: RunRoot) -> void:
	## Nothing is judged while a Trial is arming, and a live rule that is being broken
	## drains its slack rather than ending on the spot.
	##
	## Both halves are the fix for a Trial handed out while Grandma is standing in the
	## wrong place: Rooted, offered with her off her Green, used to break on its first
	## evaluation, a quarter of a second after the card appeared.
	_checks += 1
	var director := prototype._trial_director
	var field := prototype.territory_field
	field.neutralize_all_owned()
	field.recalculate_metrics_now()
	# Standing on bare ground: Rooted is broken from the first instant it is judged.
	director.begin_trial(TrialCatalog.Id.ROOTED)
	for _step in range(ceili((TrialDirector.ARMING_SECONDS - 0.5) / STEP)):
		director.advance(STEP)
	if director.get_state() != TrialDirector.State.ACTIVE:
		_failures.append("TRIAL: Rooted was judged while it was still arming")
		return
	# Past arming, and a second into the slack.
	for _step in range(ceili(1.5 / STEP)):
		director.advance(STEP)
	if director.get_state() != TrialDirector.State.ACTIVE:
		_failures.append("TRIAL: Rooted broke before its slack ran out")
		return
	var cue := director.get_world_cue()
	if cue.is_empty() or String(cue["text"]) != TrialCatalog.get_warning(TrialCatalog.Id.ROOTED):
		_failures.append("TRIAL: a draining rule showed nothing over Grandma")
		return
	for _step in range(ceili((TrialCatalog.get_slack(TrialCatalog.Id.ROOTED) + 0.5) / STEP)):
		director.advance(STEP)
	if director.get_state() != TrialDirector.State.BROKEN:
		_failures.append("TRIAL: Rooted outlived its slack")
		return
	director.reset_trials()
	print("TRIAL      a Trial is not judged while arming, and a live rule drains slack before it breaks")


func _check_goals(prototype: RunRoot) -> void:
	## Frenzy is done the moment its burst lands, and a goal never reached fails at the
	## boundary rather than passing for having survived.
	_checks += 1
	var director := prototype._trial_director
	director.begin_trial(TrialCatalog.Id.FRENZY)
	_run_past_arming(director)
	var ask := roundi(TrialCatalog.get_value(TrialCatalog.Id.FRENZY))
	# Spread wider than the window first: these must not count as one burst.
	for _kill in range(ask - 1):
		director.note_kill()
		for _step in range(ceili(TrialCatalog.get_burst_window(TrialCatalog.Id.FRENZY) / STEP)):
			director.advance(STEP)
	if director.get_state() != TrialDirector.State.ACTIVE:
		_failures.append("TRIAL: Frenzy counted kills that were seconds apart as one burst")
		return
	for _kill in range(ask):
		director.note_kill()
	if director.get_state() != TrialDirector.State.WON:
		_failures.append("TRIAL: %d kills in an instant did not complete Frenzy" % ask)
		return
	director.reset_trials()
	director.begin_trial(TrialCatalog.Id.GROUNDWORK)
	_run_past_arming(director)
	director.resolve_trial()
	if director.get_state() != TrialDirector.State.BROKEN:
		_failures.append("TRIAL: a goal nobody reached passed at the boundary")
		return
	director.reset_trials()
	prototype._owed_trial_relics = 0
	print("TRIAL      Frenzy completes on a real burst, and an unreached goal fails")


func _check_cull_measures_the_board() -> void:
	## The Cull asks for half the board it began on, never under its floor. A fixed
	## number per wave was free for a build that clears and out of reach for one that
	## holds: measured, 16 and 59 standing at the end of Wave 16.
	_checks += 1
	var cull := TrialCatalog.Id.THE_CULL
	var floor_value := TrialCatalog.get_value(cull, 16)
	var cases := [[0, floor_value], [16, maxf(floor_value, 8.0)], [59, 29.0]]
	for case in cases:
		var asked := TrialCatalog.get_value_for_board(cull, 16, int(case[0]))
		if not is_equal_approx(asked, float(case[1])):
			_failures.append(
				"TRIAL: The Cull on a board of %d asks %.0f, not %.0f"
				% [int(case[0]), asked, float(case[1])]
			)
			return
	# And the card prints the settled number, not the floor.
	if not TrialCatalog.get_rule(cull, 16, 29.0).contains("29"):
		_failures.append("TRIAL: The Cull's card does not print the number it settled on")
		return
	print("TRIAL      The Cull asks for half the board it began on")
