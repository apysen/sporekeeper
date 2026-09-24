extends SceneTree

## Campaign runs without the Clover machine. The run already asks for enough
## attention without a side game to gamble on, so the cabinet is gone, the
## Adaptation rows take the space it held, and nothing behind it turns. Quick
## still gets the whole machine, authored where the scene put it.
##
## The two modes also run different rosters -- Campaign three Adaptations, Quick four
## -- and the panel has to say so. A locked Branch row is a promise that the slot will
## open, and Campaign never opens the second one.

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
		is_equal_approx(campaign.adaptation_tree.position.y, cabinet_top),
		"Campaign moves the Adaptation rows up into the space the cabinet held",
	)
	# The lever is the only way to stake ground, and it answers nothing in Campaign.
	var spins_before := campaign.slot_machine.get_spin_count()
	campaign.slot_panel.pull_lever()
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
	campaign.adaptation_tree.refresh()
	_check(
		campaign.progression.get_branch_slot_limit() == 1
		and campaign.adaptation_tree.branch_one_frame.visible
		and not campaign.adaptation_tree.branch_two_frame.visible,
		"Campaign shows one Branch row, because it only ever opens one Branch slot",
	)
	_check(
		campaign.adaptation_tree.branch_one_label.text == "BRANCH",
		"and names it plainly rather than numbering a row nothing follows",
	)
	_check(
		campaign.adaptation_tree.evolution_slot.get_slot_count()
		== Evolutions.TARGET_ACTIVE_EVOLUTIONS,
		"and shows a socket for each Evolution the run is built to grow",
	)

	# One rhythm down the whole column. The panel is five stacked things authored in
	# three different files -- the rows and sockets in the Adaptation scene, the button
	# and the card in the run scene, and the Campaign shift in code -- so the gap
	# between them is exactly the measurement nobody notices going wrong.
	var column: Array[Control] = [
		campaign.adaptation_tree.get_node("Path1Frame/Path1EmblemFrame"),
		campaign.adaptation_tree.get_node("Path2Frame/Path2EmblemFrame"),
		campaign.adaptation_tree.get_node("SupportFrame/SupportEmblemFrame"),
		campaign.adaptation_tree.evolution_slot,
		campaign.provoke_button,
		campaign.trial_card,
	]
	var gaps := PackedFloat32Array()
	for index in range(1, column.size()):
		gaps.append(
			column[index].get_global_rect().position.y
			- column[index - 1].get_global_rect().end.y
		)
	var uniform := true
	for gap in gaps:
		uniform = uniform and is_equal_approx(gap, AdaptationTree.ROW_GAP)
	_check(
		uniform,
		"the side panel keeps one gap between everything on it: %s" % str(gaps),
	)

	# Provocation is the Campaign's difficulty dial, and every part of what it costs is
	# invisible: a Blight level is permanent, the surge lands half a minute later, and
	# the compression allowance is spent silently. The button has to say all three
	# before it is pressed.
	var provoke_body := campaign._provoke_tooltip_body()
	_check(
		provoke_body.contains("Growth")
		and provoke_body.contains("Blight")
		and provoke_body.contains("surge")
		and provoke_body.contains("no limit"),
		"the Provoke tooltip states the reward, the permanent cost and the immediate one",
	)
	# There is no waiting any more, so there is nothing to tell the player to wait for.
	# The button answers on the first frame of a run.
	_check(
		campaign.wave_director.can_provoke()
		and not provoke_body.contains("Not available"),
		"and the button answers immediately, with no window to wait out",
	)
	# "A Blight level, which is permanent" is true and useless on its own: the player is
	# being asked to make the rest of the run worse and has to be able to see by how
	# much, and by how much again if they press it.
	campaign.wave_director._blight_level = 2
	var blight_body := campaign._provoke_tooltip_body()
	_check(
		blight_body.contains("Blight II now")
		and blight_body.contains("+16% wave budget")
		and blight_body.contains("+8% enemy health")
		and blight_body.contains("+4% contact damage")
		and blight_body.contains("92% price")
		and blight_body.contains("Blight III would be")
		and blight_body.contains("+24% wave budget"),
		"and prints what this Blight does to the garden, and what the next one adds",
	)
	# And it keeps climbing past the levels the old table had glyphs for, because
	# Provocation has no limit: a run that pressed twelve times reads a numeral and a
	# multiplier that is still going up, not a ceiling that quietly stopped charging it.
	campaign.wave_director._blight_level = 12
	var deep_body := campaign._provoke_tooltip_body()
	_check(
		deep_body.contains("Blight XII now")
		and deep_body.contains("+96% wave budget")
		and deep_body.contains("Blight XIII would be")
		and BlightTable.get_level_name(19) == "XIX",
		"and keeps counting in numerals past the five the table used to stop at",
	)
	campaign.wave_director._blight_level = 0
	# The card itself cannot be asserted on from here: a HUD tooltip dismisses itself
	# the moment the pointer is not near what it belongs to, and the pointer in a probe
	# is wherever the desktop left it. So what is held is the wiring -- that a hover
	# reaches the run at all, which is the part a scene edit can silently drop.
	_check(
		campaign.provoke_button.mouse_entered.is_connected(campaign._on_provoke_hovered),
		"and the button's hover is wired to the run that draws the card",
	)

	var quick: RunRoot = await _load_run(RunMode.Id.QUICK)
	_check(quick.slot_panel.visible, "Quick still has the Clover cabinet")
	_check(
		quick.adaptation_tree.position.y > quick.slot_panel.position.y,
		"Quick leaves the Adaptation rows where the scene authored them, below the cabinet",
	)
	quick.adaptation_tree.refresh()
	_check(
		quick.progression.get_branch_slot_limit() == 2
		and quick.adaptation_tree.branch_two_frame.visible
		and quick.adaptation_tree.branch_one_label.text == "BRANCH 1",
		"Quick keeps both Branch rows, and numbers them",
	)

	if _failures == 0:
		print("CAMPAIGN_NO_CLOVER_PROBE: PASS")
		quit(0)
	else:
		push_error("CAMPAIGN_NO_CLOVER_PROBE: %d failure(s)" % _failures)
		quit(1)
