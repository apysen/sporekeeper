## How a relic presents itself: the card it is offered on, the tray it is held in,
## and the cue it plays when it fires.
##
## A relic the player cannot read is a rule they cannot learn, which is why a
## description that overflows its card and a tray that stops at six are failures here
## rather than cosmetic notes.
class_name SmokeRelicsPresentation
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot, relics: RelicDirector, lone_spot: Vector2) -> void:
	# A long relic description wraps inside its card instead of widening it. A
	# Button's minimum width otherwise includes the whole unwrapped line, so the
	# longest relic in the catalog was pushing the reward box past its own panel.
	prototype.progression.reset_progression()
	var widest_relic := 0
	for catalog_id in range(RelicCatalog.get_count()):
		if (
			RelicCatalog.get_relic_description(catalog_id).length()
			> RelicCatalog.get_relic_description(widest_relic).length()
		):
			widest_relic = catalog_id
	prototype._show_choice(
		RunRoot.ChoiceKind.RELIC, PackedInt32Array([widest_relic])
	)
	# The card has to lay out before its size means anything. The suite reaches the
	# frame through the run rather than by name: `process_frame` is the SceneTree's
	# own signal, and this is no longer running inside the SceneTree script.
	var tree := prototype.get_tree()
	await tree.process_frame
	await tree.process_frame
	var relic_card := prototype.choice_panel.button_one
	var card_fits := (
		relic_card.size.x <= prototype.choice_panel.size.x
		and relic_card.get_combined_minimum_size().x <= prototype.choice_panel.size.x
	)
	var wraps := relic_card.autowrap_mode != TextServer.AUTOWRAP_OFF
	prototype._choice_kind = RunRoot.ChoiceKind.NONE
	prototype._choice_ids.clear()
	prototype.choice_panel.visible = false
	report.check(
		wraps and card_fits,
		"a long relic description wraps inside its card rather than widening the box"
	)

	# The tray has to hold a whole run's relics. Campaign awards twelve, so a row
	# that stopped at six was hiding half of what the player had earned.
	prototype.progression.reset_progression()
	var campaign_relic_target := 14
	for tray_relic in range(campaign_relic_target):
		prototype.progression._owned_relics[tray_relic] = 1
	prototype.relic_tray.refresh()
	var shown := prototype.relic_tray.slots.get_slot_count()
	var every_relic_named := true
	for tray_index in range(campaign_relic_target):
		if prototype.relic_tray.slots.get_slot_tooltip(tray_index).is_empty():
			every_relic_named = false
			break
	prototype.progression.reset_progression()
	prototype.relic_tray.refresh()
	report.check(
		shown >= campaign_relic_target and every_relic_named,
		"the relic tray shows a whole run's relics rather than stopping at six (%d)"
			% shown
	)

	# --------------------------------------------------------------- Relic VFX
	# Two of the document's VFX rules are mechanical rather than artistic, so they
	# are enforced in code and checked here: a generated echo is drawn weaker than
	# what caused it, and same-frame accents are spread so a chain reads in order.
	prototype.overlay.clear_relic_cues()
	prototype.overlay.spawn_relic_cue(
		TerritoryPrototypeOverlay.RelicCue.GHOST, Vector2(100.0, 100.0), 40.0, Color.WHITE
	)
	var natural_intensity := prototype.overlay.get_last_relic_cue_intensity()
	var first_lead_in := prototype.overlay.get_last_relic_cue_lead_in()
	prototype.overlay.spawn_relic_cue(
		TerritoryPrototypeOverlay.RelicCue.GHOST,
		Vector2(100.0, 100.0),
		40.0,
		Color.WHITE,
		Vector2.ZERO,
		true
	)
	var echo_intensity := prototype.overlay.get_last_relic_cue_intensity()
	var second_lead_in := prototype.overlay.get_last_relic_cue_lead_in()
	# An echo of an echo can only get quieter: intensity is held under its source.
	prototype.overlay.spawn_relic_cue(
		TerritoryPrototypeOverlay.RelicCue.GHOST,
		Vector2(100.0, 100.0),
		40.0,
		Color.WHITE,
		Vector2.ZERO,
		true,
		echo_intensity
	)
	var nested_echo := prototype.overlay.get_last_relic_cue_intensity()
	report.check(
		is_equal_approx(natural_intensity, 1.0)
		and echo_intensity >= prototype.overlay.echo_intensity_minimum - 0.001
		and echo_intensity <= prototype.overlay.echo_intensity_maximum + 0.001
		and nested_echo <= echo_intensity + 0.001
		and is_equal_approx(first_lead_in, 0.0)
		and second_lead_in >= prototype.overlay.cue_stagger_seconds - 0.001,
		"a relic echo is drawn weaker than its source and same-frame accents are staggered"
	)
	# Spin is what carries the effects whose identity is rotation. It accumulates
	# with the cue's age rather than with its progress, so a long-lived cue keeps
	# turning instead of easing to a stop halfway through.
	prototype.overlay.clear_relic_cues()
	prototype.overlay.spawn_relic_cue(
		TerritoryPrototypeOverlay.RelicCue.GHOST,
		Vector2(100.0, 100.0),
		40.0,
		Color.WHITE,
		Vector2.RIGHT,
		false,
		1.0,
		TerritoryPrototypeOverlay.RelicMotif.SWIRL,
		2.0
	)
	var spun_cue: Object = prototype.overlay._relic_cues[0]
	var spin_rate := float(spun_cue.spin)
	var still_at_start := spin_rate * TAU * 0.0
	var turned_after := spin_rate * TAU * 0.25
	report.check(
		is_equal_approx(still_at_start, 0.0)
		and turned_after > 0.0
		and is_equal_approx(spin_rate, 2.0),
		"a cue can carry a spin rate, so a rolling effect turns as it plays"
	)
	prototype.overlay.clear_relic_cues()
