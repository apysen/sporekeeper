extends SceneTree

## The stake selector: that its bar is drawn, at the thickness it is meant to be, and
## that its knob answers to all three of the states it carries art for.
##
## The thickness is worth measuring rather than trusting. A Slider draws its track at
## whatever height the stylebox reports as its minimum, unlike a ProgressBar, which
## stretches its style across the whole control - and a StyleBoxTexture's minimum is its
## margins, not its texture. A track style with no vertical margin is drawn zero pixels
## tall and simply is not there, which is not a mistake anything else would catch.

## Half the height of the HP, Green and XP meters, which is what the stake is meant to
## be: a smaller claim on the panel than the run's own vitals.
const THICKNESS_RATIO := 0.5


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file("res://scenes/run/run.tscn")
	await process_frame
	await process_frame
	var prototype := current_scene as RunRoot
	prototype.set_process(false)
	prototype.player.input_enabled = false
	var slider := prototype.slot_panel.wager_slider as WagerSlider
	var failures := PackedStringArray()
	if slider == null:
		print("WAGER_SLIDER: the stake selector is not a WagerSlider")
		quit(1)
		return

	var drawn := _track_height(slider)
	var meter := prototype.xp_bar.size.y
	var wanted := meter * THICKNESS_RATIO
	if absf(drawn - wanted) > 1.5:
		failures.append(
			"bar is %.0fpx where the meters are %.0f, wanted %.0f" % [drawn, meter, wanted]
		)
	if drawn <= 0.5:
		failures.append("the bar is not drawn at all")
	# The knob sits on the bar rather than replacing it, and must not be so large that
	# it drives the control's own height.
	# Nothing about this control takes its size from the theme any more, so it can be
	# dragged to any size and the bar and knob follow. Check that they actually do.
	var was := slider.size
	slider.size = Vector2(120.0, 24.0)
	if slider.size.y > 24.5:
		failures.append(
			"the control will not shrink below %.0fpx - something still pins it" % slider.size.y
		)
	if slider.bar_rect().size.y > 24.0 or slider.knob_rect().size.x > 120.0:
		failures.append("the bar or knob does not follow the control it is drawn in")
	slider.size = was
	# And it is cut larger than it is drawn, which is the whole of why it stays legible
	# on a display bigger than the 1280x720 this interface is laid out in.
	var knob := slider.current_grabber_texture()
	if knob == null:
		failures.append("no knob")
	elif knob.get_height() < slider.knob_size * 2.0:
		failures.append(
			"knob art is %dpx for %.0f units - no detail to spare when magnified" % [
				knob.get_height(), slider.knob_size
			]
		)

	# Three states, and the held one wins while the cursor is still over the knob.
	var seen := PackedStringArray()
	seen.append(slider.current_grabber_texture().resource_path)
	slider._on_pointed_at()
	seen.append(slider.current_grabber_texture().resource_path)
	slider._on_held()
	seen.append(slider.current_grabber_texture().resource_path)
	slider._on_released(true)
	slider._on_pointed_away()
	if seen[0] == seen[1] or seen[1] == seen[2] or seen[0] == seen[2]:
		failures.append("the knob's three states are not three distinct textures")
	if slider.current_grabber_texture().resource_path != seen[0]:
		failures.append("the knob does not return to rest")

	print("WAGER_SLIDER: bar %.0fpx against a %.0fpx meter" % [drawn, meter])
	for failure in failures:
		print("WAGER_SLIDER: %s" % failure)
	print("WAGER_SLIDER: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func _track_height(slider: WagerSlider) -> float:
	# What the slider actually draws, which is its own business now rather than
	# something the theme decides.
	return slider.bar_rect().size.y
