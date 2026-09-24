extends SceneTree

## What a Trial actually looks like on the panel.
##
## `trial_probe` proves the rules are judged; it would not notice a card whose rule
## prints over its own reward, a plaque drawn off the bottom of the side panel, or a
## state strip the same colour as the frame behind it. This starts each of the six
## Trials in turn and saves a frame of the panel, so the card can be looked at.
##
## The two that a still frame is actually needed for are the longest rule, which is
## the one that decides how tall the card has to be, and a broken Trial, because
## every colour on the card changes at once when a rule goes.
##
## Needs a real window: it reads the rendered frame. Run without `--headless`:
##     godot --path . --script tests/integration/trial_visual_probe.gd

const RUN_SCENE := "res://scenes/run/run.tscn"
## The side panel, in viewport pixels. The card is the bottom third of it.
const PANEL_RECT := Rect2i(1004, 24, 252, 688)

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _drive()
	if _failures == 0:
		print("TRIAL_VISUAL_PROBE: PASS")
		quit(0)
	else:
		push_error("TRIAL_VISUAL_PROBE: %d failure(s)" % _failures)
		quit(1)


func _drive() -> void:
	# Campaign, because the card is laid out under an Adaptation panel that only moves
	# up into the Clover machine's place when the machine is gone.
	RunMode.set_selected(RunMode.Id.CAMPAIGN)
	if change_scene_to_file(RUN_SCENE) != OK:
		_check(false, "the run scene loads")
		return
	await process_frame
	await process_frame
	var run := current_scene as RunRoot
	if run == null:
		_check(false, "the run scene becomes a RunRoot")
		return
	run.set_process(false)
	run.player.input_enabled = false
	run.combat.set_process(false)
	# The run opens on its first draft, and the draft brings its tooltips, which are
	# drawn over the panel. What is being photographed is the panel.
	run.choice_panel.visible = false
	for child in run.interface_layer.get_children():
		if child is MechanicsHelp:
			(child as MechanicsHelp).visible = false
	var card := run.trial_card
	_check(card != null, "the run scene carries a Trial card")
	if card == null:
		return

	var panel_bottom := PANEL_RECT.position.y + PANEL_RECT.size.y
	for trial_id in range(TrialCatalog.get_count()):
		card.begin_trial(trial_id)
		await _draw_frames()
		var name := TrialCatalog.get_trial_name(trial_id).to_lower().replace(" ", "_")
		await _save("res://.godot/trial_card_%s.png" % name)
		var bottom := card.global_position.y + card.size.y
		_check(
			bottom <= float(panel_bottom),
			(
				"%s fits the panel it is drawn on (ends at %d, panel ends at %d)"
				% [TrialCatalog.get_trial_name(trial_id), roundi(bottom), panel_bottom]
			)
		)

	# And a broken one, which is the state every colour on the card changes for.
	card.begin_trial(TrialCatalog.Id.UNTOUCHED)
	# Past the opening grace, then one hit more than the rule allows.
	for _step in range(ceili(TrialDirector.ARMING_SECONDS * 60.0) + 1):
		card.advance(1.0 / 60.0)
	for _hit in range(roundi(TrialCatalog.get_value(TrialCatalog.Id.UNTOUCHED)) + 1):
		card.note_damage_taken()
	await _draw_frames()
	await _save("res://.godot/trial_card_broken.png")
	_check(
		card.get_state() == TrialDirector.State.BROKEN,
		"a broken Trial is photographed in its broken state"
	)

	# The provoke button lives under the same heading and is the other thing the
	# Campaign panel gained, so it is in these frames whether or not it is ready.
	_check(
		run.provoke_button != null and run.provoke_button.visible,
		"the Campaign panel carries a Provoke button"
	)


func _draw_frames() -> void:
	for index in range(3):
		await process_frame


func _save(path: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		_check(false, "a frame can be read for %s" % path)
		return
	# The window is not always the project's own resolution, so the rendered frame is
	# rarely one pixel per viewport pixel. Cropping by viewport coordinates without
	# this returns a magnified corner of the panel.
	var scale := (
		float(image.get_width()) / maxf(float(root.get_visible_rect().size.x), 1.0)
	)
	var region := Rect2i(
		Vector2i(Vector2(PANEL_RECT.position) * scale),
		Vector2i(Vector2(PANEL_RECT.size) * scale)
	)
	region = region.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if region.size.x <= 0 or region.size.y <= 0:
		_check(false, "the panel is inside the rendered frame for %s" % path)
		return
	image.get_region(region).save_png(path)


func _check(passed: bool, description: String) -> void:
	if passed:
		print("PASS: %s" % description)
		return
	_failures += 1
	print("FAIL: %s" % description)
