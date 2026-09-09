extends SceneTree

## Campaign runs without the Clover machine. The run already asks for enough
## attention without a side game to gamble on, so the cabinet is gone, the
## Adaptation rows take the space it held, and nothing behind it turns. Quick
## still gets the whole machine, authored where the scene put it.

var _failures := 0

func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures += 1
	push_error("FAIL: %s" % description)


func _load_run(mode: int) -> RunRoot:
	RunMode.set_selected(mode)
	if change_scene_to_file("res://scenes/run/run.tscn") != OK:
		push_error("FAIL: the run scene did not load")
		quit(1)
		return null
	await process_frame
	await process_frame
	var prototype := current_scene as RunRoot
	prototype.player.input_enabled = false
	return prototype


func _run() -> void:
	var campaign: RunRoot = await _load_run(RunMode.Id.CAMPAIGN)
	var cabinet_top := campaign.slot_panel.position.y
	_check(not campaign.slot_panel.visible, "Campaign hides the Clover cabinet")
	_check(
		is_equal_approx(campaign.get_node("%UpgradeSection").position.y, cabinet_top),
		"Campaign moves the Adaptation rows up into the space the cabinet held",
	)
	# The lever is the only way to stake ground, and it answers nothing in Campaign.
	var spins_before := campaign.slot_machine.get_spin_count()
	campaign._pull_lever()
	for _step in range(120):
		campaign.advance_run(1.0 / 60.0)
	_check(
		campaign.slot_machine.get_spin_count() == spins_before,
		"a Campaign lever pull stakes nothing and turns no reel",
	)
	_check(
		campaign.slot_machine.get_committed_cells().is_empty(),
		"Campaign commits no ground to the machine",
	)

	var quick: RunRoot = await _load_run(RunMode.Id.QUICK)
	_check(quick.slot_panel.visible, "Quick still has the Clover cabinet")
	_check(
		quick.get_node("%UpgradeSection").position.y > quick.slot_panel.position.y,
		"Quick leaves the Adaptation rows where the scene authored them, below the cabinet",
	)

	if _failures == 0:
		print("CAMPAIGN_NO_CLOVER_PROBE: PASS")
		quit(0)
	else:
		push_error("CAMPAIGN_NO_CLOVER_PROBE: %d failure(s)" % _failures)
		quit(1)
