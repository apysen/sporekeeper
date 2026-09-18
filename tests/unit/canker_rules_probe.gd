extends SceneTree

## The Canker ladder, driven one transition at a time with no field in the room.
##
## Every rule this covers is a threshold or a clock, and the value of testing them here
## is that a hostile field takes ten seconds of simulation to produce and this takes
## none. What the node does with the answers is the integration probe's business.
##
## Run: godot --headless --path . --script tests/unit/canker_rules_probe.gd

var _failures := 0


func _initialize() -> void:
	_run()
	if _failures == 0:
		print("CANKER_RULES: PASS")
		quit(0)
	else:
		push_error("CANKER_RULES: %d failure(s)" % _failures)
		quit(1)


func _run() -> void:
	_check_hysteresis()
	_check_ladder()
	_check_destruction()
	_check_redirect_share()
	_check_placement()
	_check_scoring()


func _check_hysteresis() -> void:
	_check(CankerRules.qualifies(0.65, 0.65), "a site at the activation ratio qualifies")
	_check(not CankerRules.qualifies(0.64, 0.65), "and one just under it does not")
	_check(CankerRules.has_collapsed(0.49, 0.50), "Rot under the cancel ratio collapses a site")
	_check(not CankerRules.has_collapsed(0.50, 0.50), "and Rot at it does not")
	# The gap is the whole point: ground between the two thresholds is contested, and a
	# site sitting in it must neither climb nor reset, or the stage flickers every time
	# a frontier breathes across one number.
	var settings := _settings()
	var dead_band := CankerRules.advance_stage(
		CankerRules.Stage.ACCUMULATING, 0.55, 3.0, 0.0, 0.25, settings
	)
	_check(
		dead_band.stage == CankerRules.Stage.ACCUMULATING and not dead_band.reset,
		"a site inside the dead band keeps the progress it had"
	)
	var idle := CankerRules.advance_stage(
		CankerRules.Stage.INACTIVE, 0.55, 0.0, 0.0, 0.25, settings
	)
	_check(
		idle.stage == CankerRules.Stage.INACTIVE,
		"and an inactive site in the dead band does not start climbing"
	)


func _check_ladder() -> void:
	var settings := _settings()
	var started := CankerRules.advance_stage(
		CankerRules.Stage.INACTIVE, 0.70, 0.0, 0.0, 0.25, settings
	)
	_check(started.stage == CankerRules.Stage.ACCUMULATING, "enough Rot starts a site climbing")

	var stage := CankerRules.Stage.ACCUMULATING
	var hold := 0.0
	var warning := 0.0
	var ticks := 0
	var entered_warning := false
	while ticks < 200 and stage != CankerRules.Stage.WARNING:
		var step := CankerRules.advance_stage(stage, 0.70, hold, warning, 0.25, settings)
		stage = step.stage
		hold = step.hold_timer
		warning = step.warning_timer
		entered_warning = entered_warning or step.entered_warning
		ticks += 1
	_check(stage == CankerRules.Stage.WARNING, "held Rot reaches the warning stage")
	_check(entered_warning, "and announces the edge rather than only the state")
	_check(
		is_equal_approx(float(ticks) * 0.25, settings.hold_time),
		"after exactly the authored hold time (%.2fs)" % [float(ticks) * 0.25]
	)

	var lost := CankerRules.advance_stage(CankerRules.Stage.WARNING, 0.20, 0.0, 1.0, 0.25, settings)
	_check(lost.stage == CankerRules.Stage.INACTIVE, "reclaiming during the warning cancels it")
	_check(lost.cancelled_warning, "and says so, so the telegraph can be called off")

	ticks = 0
	var formed := false
	while ticks < 200 and stage == CankerRules.Stage.WARNING:
		var step := CankerRules.advance_stage(stage, 0.70, hold, warning, 0.25, settings)
		stage = step.stage
		hold = step.hold_timer
		warning = step.warning_timer
		formed = formed or step.formed
		ticks += 1
	_check(stage == CankerRules.Stage.ACTIVE and formed, "a warning left alone forms a Knot")


func _check_destruction() -> void:
	var settings := _settings()
	# Damage is not in this function anywhere, which is the design: the only route from
	# ACTIVE back to INACTIVE is the Rot ratio falling and staying down.
	var holding := CankerRules.advance_stage(
		CankerRules.Stage.ACTIVE, 0.80, 0.0, 0.0, 0.25, settings
	)
	_check(holding.stage == CankerRules.Stage.ACTIVE, "a Knot on its own ground stays")

	var flicker := CankerRules.advance_stage(
		CankerRules.Stage.ACTIVE, 0.20, 0.6, 0.0, 0.25, settings
	)
	_check(flicker.stage == CankerRules.Stage.ACTIVE, "a Knot part-way through withering survives")
	var recovered := CankerRules.advance_stage(
		CankerRules.Stage.ACTIVE, 0.90, 0.6, 0.0, 0.25, settings
	)
	_check(
		recovered.hold_timer == 0.0,
		"and ground lost back to the enemy resets the wither clock rather than banking it"
	)

	var stage := CankerRules.Stage.ACTIVE
	var hold := 0.0
	var withered := false
	var ticks := 0
	while ticks < 100 and stage == CankerRules.Stage.ACTIVE:
		var step := CankerRules.advance_stage(stage, 0.10, hold, 0.0, 0.25, settings)
		stage = step.stage
		hold = step.hold_timer
		withered = withered or step.withered
		ticks += 1
	_check(withered and stage == CankerRules.Stage.INACTIVE, "sustained reclaim withers a Knot")


func _check_redirect_share() -> void:
	_check(CankerRules.redirect_share(0, 0.15, 0.25) == 0.0, "no Knots redirect nothing")
	_check(
		is_equal_approx(CankerRules.redirect_share(1, 0.15, 0.25), 0.15),
		"one Knot redirects its own share"
	)
	# The cap is what keeps a Canker a change of topology rather than a change of
	# volume. Two Knots must not simply double the interior pressure.
	_check(
		is_equal_approx(CankerRules.redirect_share(2, 0.15, 0.25), 0.25),
		"two Knots are capped rather than stacked (0.25, not 0.30)"
	)
	_check(
		is_equal_approx(CankerRules.redirect_share(9, 0.15, 0.25), 0.25),
		"and the cap holds however many there are"
	)
	_check(
		CankerRules.redirect_share(3, 0.15, 0.25) <= 1.0,
		"the share can never exceed every spawn"
	)


func _check_placement() -> void:
	_check(
		CankerRules.is_site_clear(400.0, 210.0, -1.0, 220.0),
		"a lone site far from Grandma is clear"
	)
	_check(
		not CankerRules.is_site_clear(120.0, 210.0, -1.0, 220.0),
		"a site too close to Grandma is refused"
	)
	_check(
		not CankerRules.is_site_clear(400.0, 210.0, 90.0, 220.0),
		"and so is one sharing a blob with an existing Knot"
	)
	_check(
		CankerRules.is_site_clear(400.0, 210.0, 260.0, 220.0),
		"a site a full spacing away from another Knot is allowed"
	)


func _check_scoring() -> void:
	var fresh := CankerRules.candidate_score(0.90, 0.5, 10.0)
	var ignored := CankerRules.candidate_score(0.70, 10.0, 10.0)
	# Persistence is what makes a Knot read as a consequence. Ground the player has had
	# ten seconds to notice outranks ground that just tipped over, even when the ratio
	# there is higher.
	_check(ignored > fresh, "long-ignored ground outranks freshly lost ground")
	_check(
		CankerRules.candidate_score(0.80, 40.0, 10.0)
		== CankerRules.candidate_score(0.80, 10.0, 10.0),
		"and persistence stops counting once the hold is complete"
	)
	var settings := _settings()
	_check(
		CankerRules.telegraph_progress(CankerRules.Stage.INACTIVE, 0.0, 0.0, settings) == 0.0,
		"quiet ground telegraphs nothing"
	)
	_check(
		is_equal_approx(
			CankerRules.telegraph_progress(CankerRules.Stage.ACCUMULATING, 5.0, 0.0, settings),
			0.5
		),
		"a site half-way through its hold telegraphs half-way"
	)
	_check(
		CankerRules.telegraph_progress(CankerRules.Stage.WARNING, 10.0, 1.0, settings) == 1.0,
		"and a warning site telegraphs fully"
	)


func _settings() -> CankerRules.Settings:
	var settings := CankerRules.Settings.new()
	settings.activation_ratio = 0.65
	settings.cancel_ratio = 0.50
	settings.hold_time = 10.0
	settings.warning_time = 2.5
	settings.destroy_ratio = 0.35
	settings.destroy_hold_time = 1.0
	return settings


func _check(passed: bool, description: String) -> void:
	if passed:
		print("PASS: %s" % description)
		return
	_failures += 1
	push_error("FAIL: %s" % description)
