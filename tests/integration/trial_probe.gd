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
	_check_every_rule_reads(prototype)
	_check_hold_pays(prototype)
	_check_break_costs_nothing(prototype)

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
	## One Trial per act after Germination, and never on a wave that already owes a
	## milestone: a relic landing in the same breath as a Trial's relic reads as one
	## reward rather than two.
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
	print("TRIAL      Trial waves %s, none in Act I, none doubled up" % str(trial_waves))


func _check_every_rule_reads(prototype: RunRoot) -> void:
	## Every Trial in the catalogue has to produce a sentence with its number already
	## in it, and a progress line that does not crash on a board it has never seen.
	_checks += 1
	var director := prototype._trial_director
	for trial_id in range(TrialCatalog.get_count()):
		var rule := TrialCatalog.get_rule(trial_id)
		if rule.is_empty() or rule.contains("{value}"):
			_failures.append(
				"TRIAL: %s prints an unfinished rule: '%s'"
				% [TrialCatalog.get_trial_name(trial_id), rule]
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
	print("TRIAL      all %d rules print a finished sentence and a progress line"
		% TrialCatalog.get_count())


func _check_hold_pays(prototype: RunRoot) -> void:
	## A Trial nobody breaks pays a relic.
	_checks += 1
	var director := prototype._trial_director
	prototype._owed_trial_relics = 0
	director.begin_trial(TrialCatalog.Id.PATIENCE)
	for _step in range(30):
		director.advance(STEP)
	director.resolve_trial()
	if prototype._owed_trial_relics != 1:
		_failures.append(
			"TRIAL: holding a Trial owed %d relics rather than 1"
			% prototype._owed_trial_relics
		)
		return
	print("TRIAL      a held Trial owes its relic")


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

	director.begin_trial(TrialCatalog.Id.PATIENCE)
	for _kill in range(roundi(TrialCatalog.get_value(TrialCatalog.Id.PATIENCE)) + 1):
		director.note_kill()
	if director.get_state() != TrialDirector.State.BROKEN:
		_failures.append("TRIAL: killing past the allowance did not break Patience")
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
