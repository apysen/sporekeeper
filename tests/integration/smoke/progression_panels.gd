## The two panels a run reads its own build off: the Adaptation tree and the relic
## row, plus the offer that fills them.
##
## These are checks about what is drawn and what is worded, so they assert against
## the live nodes rather than against the directors underneath. Where a rule is
## involved - which relics a pool may offer, which way rarity is allowed to move -
## it is the rule the panel depends on to be honest.
class_name SmokeProgressionPanels
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	# The Adaptation tree keeps each owned Adaptation's four authored lines together,
	# with the Evolutions between the two Cores and the unearned Branch rows locked
	# beneath it. Quick opens both Branch slots, so both rows are on the panel here;
	# Campaign opens one and `campaign_no_clover_probe` is where that shape is held.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.BRAMBLE,
		Progression.PathId.ROOT
	)
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT
	] = 3
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.ROOT_MATURE_STRENGTH
	] = 2
	prototype._apply_progression_modifiers()
	prototype._update_hud()
	var slot_row := prototype.adaptation_tree.core_one_slots
	var filled_tooltip := slot_row.get_slot_tooltip(0)
	var empty_tooltip := slot_row.get_slot_tooltip(2)
	var locked_tooltip := prototype.adaptation_tree.evolution_slot.get_slot_tooltip(0)
	var expected_slow := roundi(prototype.bramble_director.get_slow_fraction() * 100.0)
	report.check(
		slot_row.get_slot_count() == 4
		and prototype.adaptation_tree.core_two_slots.get_slot_count() == 4
		# Two sockets from the first frame of the run, both empty: a run is built to
		# grow two Evolutions and an empty socket is how it says the second is coming.
		and prototype.adaptation_tree.evolution_slot.get_slot_count() == 2
		and prototype.adaptation_tree.branch_one_slots.get_slot_count() == 4
		and prototype.adaptation_tree.branch_two_slots.get_slot_count() == 4
		# Every row is named plainly; nothing marks one Adaptation over another.
		and prototype.adaptation_tree.core_one_label.text == "BRAMBLE"
		and prototype.adaptation_tree.core_two_label.text == "ROOT"
		and prototype.adaptation_tree.branch_one_label.text == "BRANCH 1"
		and prototype.adaptation_tree.branch_two_label.text == "BRANCH 2"
		and prototype.adaptation_tree.branch_one_emblem_lock.visible
		and prototype.adaptation_tree.branch_two_emblem_lock.visible
		and not prototype.adaptation_tree.branch_one_emblem.visible
		and filled_tooltip.contains("Entanglement")
		and filled_tooltip.contains("3/3")
		and filled_tooltip.contains("up to %d%% slow" % expected_slow)
		and empty_tooltip.contains("Available on an upgrade draft")
		and locked_tooltip.contains("two lines in each Core"),
		"the Adaptation tree groups four lines per Adaptation and locks both Branches"
	)

	# A slot has to survive the HUD refreshing under it. The rows re-assert their
	# length several times a second, and rebuilding on an assignment that changed
	# nothing destroyed every slot ten times a second: long enough to draw, never
	# long enough to finish the half-second hover a tooltip needs.
	var relic_panel := prototype.relic_tray.slots.get_child(0, true)
	var upgrade_panel := slot_row.get_child(0, true)
	var relic_instance := relic_panel.get_instance_id()
	var upgrade_instance := upgrade_panel.get_instance_id()
	for _refresh in range(5):
		prototype._update_hud()
	report.check(
		is_instance_valid(relic_panel)
		and prototype.relic_tray.slots.get_child(0, true).get_instance_id() == relic_instance
		and is_instance_valid(upgrade_panel)
		and slot_row.get_child(0, true).get_instance_id() == upgrade_instance,
		"slots survive a HUD refresh, so a hover can last long enough to raise a tooltip"
	)

	# A held relic explains itself on hover, the way an upgrade line does.
	prototype.progression._owned_relics[RelicCatalog.Id.GREEN_THUMB] = 1
	prototype._update_hud()
	var relic_tooltip := prototype.relic_tray.slots.get_slot_tooltip(0)
	prototype.progression._owned_relics[RelicCatalog.Id.GREEN_THUMB] = 0
	report.check(
		relic_tooltip.contains("Green Thumb")
		and relic_tooltip.contains(
			RelicCatalog.get_relic_description(RelicCatalog.Id.GREEN_THUMB)
		)
		and relic_tooltip.contains("COMMON"),
		"a held relic's hover carries its name, rarity, and what the relic actually does"
	)

	# A locked slot carries the icon and no text at all; an empty one keeps only its
	# marker.
	report.check(
		slot_row.locked_icon != null
		and prototype.adaptation_tree.evolution_slot.is_slot_locked_icon_visible(0)
		and prototype.adaptation_tree.branch_one_slots.is_slot_locked_icon_visible(0)
		and prototype.adaptation_tree.evolution_slot.get_slot_level_text(0).is_empty()
		# A bought line reads against its own ceiling, so 2 of 3 is never mistaken
		# for a barely-started five-rank line. An unbought one keeps only its marker.
		and slot_row.get_slot_level_text(2).is_empty()
		and slot_row.get_slot_level_text(0) == "3/3",
		"a bought line shows its rank against a rank-3 ceiling and an empty one its marker"
	)

	# Upgrade order remains stable, and claiming the Evolution fills the central node
	# without touching either Branch row: Branches come from the Elite and the Boss,
	# never from evolving.
	var slotted_before := prototype.progression.get_slotted_upgrades()
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.ROOT_POTENCY
	] = 1
	var slotted_after := prototype.progression.get_slotted_upgrades()
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	prototype._apply_progression_modifiers()
	prototype._update_hud()
	var branch_tooltip := prototype.adaptation_tree.branch_one_slots.get_slot_tooltip(0)
	report.check(
		slotted_after.size() == slotted_before.size() + 1
		and slotted_after[0] == slotted_before[0]
		and slotted_after[1] == slotted_before[1]
		and prototype.adaptation_tree.evolution_slot.get_slot_level_text(0) == "1/5"
		and prototype.adaptation_tree.branch_one_emblem_lock.visible
		and branch_tooltip.contains("Elite Rootbreaker"),
		"a line keeps its slot, and evolving never opens a Branch row"
	)

	# The tree's silhouette is stable: locked nodes unlock in place rather than
	# making the HUD jump when Evolution is claimed.
	report.check(
		slot_row.get_slot_count() == 4
		and prototype.adaptation_tree.core_two_slots.get_slot_count() == 4
		and prototype.adaptation_tree.branch_one_slots.get_slot_count() == 4,
		"the upgrade tree keeps its path-grouped silhouette as states unlock"
	)

	# What the editor authored is what the game prints. Each line is re-authored
	# here the way it would be re-typed on the node in the editor, the HUD is asked to
	# refresh, and the running label is read back: wording, spacing and which values
	# appear at all follow the scene rather than a format string in code.
	# The third entry is the AuthoredText that owns each label. Re-typing wording in
	# the editor reaches the registry belonging to the scene the node lives in, so a
	# label inside a sub-scene is re-authored through that sub-scene's own registry.
	var authored_probes := [
		[
			prototype.adaptation_tree.heading_label,
			"LINES {filled} OF {total}",
			prototype.adaptation_tree._authored,
		],
		[prototype.health_label, "VITALITY {current}", prototype._authored],
		[prototype.territory_label, "HELD {green} PERCENT", prototype._authored],
		[prototype.xp_label, "LVL {level}", prototype._authored],
		[prototype.hostile_label, "{hostiles} ENEMIES ABOUT", prototype._authored],
		[prototype.wave_label, "ROUND {wave}", prototype._authored],
	]
	var authored_reaches_game := true
	var authored_report := ""
	for probe: Array in authored_probes:
		var label: Label = probe[0]
		var authored: String = probe[1]
		var registry: AuthoredText = probe[2]
		registry.set_template(label, authored)
	prototype._on_health_changed(
		prototype.player.get_health(),
		prototype.player.maximum_health
	)
	prototype._on_xp_changed(
		prototype.progression.current_level,
		prototype.progression.current_xp,
		prototype.progression.get_required_xp()
	)
	prototype._on_territory_metrics_changed(
		prototype.territory_field.get_player_percent(), 0.0, 0.0, 0.0, 0
	)
	prototype._update_hud()
	for probe: Array in authored_probes:
		var label: Label = probe[0]
		var authored: String = probe[1]
		# Every word outside a placeholder has to survive verbatim, and no placeholder
		# may survive: one left as typed means nothing filled it in.
		var printed := label.text
		var intact := not printed.contains("{")
		for word in authored.split(" "):
			if word.begins_with("{"):
				continue
			intact = intact and printed.contains(word)
		if not intact:
			authored_reaches_game = false
			authored_report += " [%s authored %s, printed %s]" % [
				label.name, authored, printed
			]
	report.check(
		authored_reaches_game,
		"wording authored in the editor reaches the running game:%s" % authored_report
	)
	# A placeholder the author deletes simply stops appearing, rather than shifting
	# every later value onto the wrong slot the way a positional format would.
	prototype.adaptation_tree._authored.set_template(
		prototype.adaptation_tree.heading_label, "UPGRADES"
	)
	prototype._update_hud()
	report.check(
		prototype.adaptation_tree.heading_label.text == "UPGRADES",
		"a line with no placeholders is printed exactly as authored"
	)
	prototype.progression.reset_progression()
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false

	# Relic rewards are choose-one-of-three out of a pool far larger than the run
	# will ever see, weighted by rarity, and no relic can be offered twice.
	prototype.progression.request_relic_choice()
	var relic_offer := prototype.progression.get_pending_relic_options()
	var relic_offer_is_valid := (
		relic_offer.size() == prototype.progression.relic_offer_count
	)
	var seen_relics := {}
	for offered_id in relic_offer:
		relic_offer_is_valid = (
			relic_offer_is_valid
			and prototype.progression.is_relic_eligible(offered_id)
			and not seen_relics.has(offered_id)
		)
		seen_relics[offered_id] = true
	report.check(
		prototype.choice_panel.visible and relic_offer_is_valid,
		"elite relic rewards offer three distinct eligible relics on the paused panel"
	)

	# The button says what kind of rule change it is, because rarity is the
	# readout of impact rather than of raw numbers.
	var rarity_named := prototype.choice_panel.buttons[0].text.contains(
		RelicCatalog.get_rarity_name(
			RelicCatalog.get_rarity(relic_offer[0])
		)
	)
	var claimed_relic := relic_offer[0]
	prototype._choose_displayed_option(0)
	report.check(
		rarity_named and prototype.progression.has_relic(claimed_relic),
		"a relic offer names its rarity and the claimed relic is granted"
	)

	# A relic already held is never offered again.
	prototype.progression.request_relic_choice()
	var second_offer := prototype.progression.get_pending_relic_options()
	report.check(
		second_offer.find(claimed_relic) == -1,
		"a relic the run already holds is excluded from later offers"
	)

	# Relic offers can be rerolled now that they are a sample rather than the
	# whole pool, and the reroll spends its own budget.
	var rerolls_before := prototype.progression.get_relic_rerolls_remaining()
	var rerolled := prototype.progression.reroll_relic_choice()
	report.check(
		rerolled
		and prototype.progression.get_relic_rerolls_remaining() == rerolls_before - 1
		and prototype.progression.get_pending_relic_options().size()
		== prototype.progression.relic_offer_count,
		"a relic reward can be rerolled from its own reroll budget"
	)
	prototype.progression._pending_relic_options.clear()
	prototype._choice_kind = RunRoot.ChoiceKind.NONE
	prototype.choice_panel.visible = false

	# An offer may contain Plant relics and relics of Adaptations the run owns,
	# and nothing else. Ownership is the gate: a Clover jackpot lends an
	# Adaptation's behaviour for ten seconds and must not open its relic pool.
	prototype.progression.reset_progression()
	var plant_always := prototype.progression.is_relic_eligible(
		RelicCatalog.Id.GARDEN_HOSE
	)
	var unowned_locked := prototype.progression.is_relic_eligible(
		RelicCatalog.Id.THE_HEDGE
	)
	prototype.progression.debug_select_paths(
		Progression.PathId.BRAMBLE,
		Progression.PathId.PRUNING
	)
	var owned_unlocked := prototype.progression.is_relic_eligible(
		RelicCatalog.Id.THE_HEDGE
	)
	var still_unowned := prototype.progression.is_relic_eligible(
		RelicCatalog.Id.DOMINO_GERMINATION
	)
	prototype.progression.set_casino_path_active(Progression.PathId.SPORE, true)
	var borrowed_stays_locked := prototype.progression.is_relic_eligible(
		RelicCatalog.Id.DOMINO_GERMINATION
	)
	prototype.progression.set_casino_path_active(Progression.PathId.SPORE, false)
	report.check(
		plant_always
		and not unowned_locked
		and owned_unlocked
		and not still_unowned
		and not borrowed_stays_locked,
		"relic eligibility is Plant plus owned Adaptations, and a jackpot loan never counts"
	)

	# Every pool is the shape the master document specifies, which the downward
	# rarity fallback in the offer roll relies on.
	var pool_grid := {}
	for catalog_relic in range(RelicCatalog.get_count()):
		var pool_key := RelicCatalog.get_pool(catalog_relic)
		var rarity_key := RelicCatalog.get_rarity(catalog_relic)
		if not pool_grid.has(pool_key):
			pool_grid[pool_key] = [0, 0, 0, 0]
		pool_grid[pool_key][rarity_key] += 1
	var pools_well_formed := pool_grid.size() == RelicCatalog.Pool.size()
	for pool_key in pool_grid:
		pools_well_formed = pools_well_formed and pool_grid[pool_key] == [3, 2, 2, 1]
	report.check(
		RelicCatalog.get_count() == 72 and pools_well_formed,
		"the catalog holds 72 relics as nine pools of 3 Common, 2 Uncommon, 2 Rare, 1 Legendary"
	)

	# Rarity is rolled per offered slot and may only ever fall downward, so an
	# exhausted rarity can never manufacture a rarer relic than the odds produced.
	var fallback_candidates := PackedInt32Array([
		RelicCatalog.Id.GARDEN_HOSE,
		RelicCatalog.Id.MULCH,
	])
	var fell_downward := prototype.progression._draw_relic_of_rarity(
		fallback_candidates, RelicCatalog.Rarity.LEGENDARY
	)
	var exhausted := prototype.progression._draw_relic_of_rarity(
		PackedInt32Array(), RelicCatalog.Rarity.COMMON
	)
	var odds_sum := 0.0
	for share in prototype.progression.get_relic_rarity_odds():
		odds_sum += share
	report.check(
		fallback_candidates.has(fell_downward)
		and exhausted == -1
		and is_equal_approx(odds_sum, 1.0),
		"a slot's rarity roll falls downward only, and the odds table is a whole probability"
	)
