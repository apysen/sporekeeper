## How a run is built: the first level-up, the Core pair it commits to, and what the
## draft is allowed to offer once those slots are gone.
##
## The seed is pinned for the whole suite so every draft is the same hand, and the
## blocks that are about randomness clear it and roll their own. The reroll checks
## are the reason that matters: a draft that changed between runs could not be said
## to have rerolled into anything.
class_name SmokeDrafting
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	# A run opens on nothing but a Cane. The first upgrade arrives the way it always
	# has -- a few kills into wave one -- and taking a line is what enters its
	# Adaptation. No screen of bare Adaptations is ever presented.
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	report.check(
		prototype._choice_kind == RunRoot.ChoiceKind.NONE
		and not prototype.choice_panel.visible
		and prototype.progression.get_owned_adaptation_count() == 0
		and not prototype.territory_field.simulation_paused,
		"a run begins playing immediately rather than on an Adaptation choice"
	)
	prototype.progression._upgrade_offer_cursor = (
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT
	)
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var pre_path_options := prototype.progression.get_pending_upgrade_options()
	var pre_path_lines: Array[int] = []
	var pre_path_paths: Array[int] = []
	for option_id in pre_path_options:
		if not pre_path_lines.has(option_id):
			pre_path_lines.append(option_id)
		var option_path := prototype.progression._get_upgrade_path(option_id)
		if not pre_path_paths.has(option_path):
			pre_path_paths.append(option_path)
	report.check(
		prototype._choice_kind == RunRoot.ChoiceKind.UPGRADE
		and pre_path_options.size() == 3
		and pre_path_lines.size() == 3
		and pre_path_paths.size() >= 2,
		"the first level-up offers three distinct lines spread across the whole roster"
	)
	var committing_option := pre_path_options[0]
	var committing_path := prototype.progression._get_upgrade_path(committing_option)
	var committed_preview := prototype.progression.get_upgrade_committed_path(
		committing_option
	)
	prototype._choose_displayed_option(0)
	report.check(
		committed_preview == committing_path
		and prototype.progression.primary_path == committing_path
		and prototype.progression.owns_adaptation(committing_path)
		and prototype.progression.get_owned_upgrade_level(committing_option) == 1,
		"taking a line commits its Adaptation as Core 1"
	)
	# Owning it opens all four of its lines at rank 0, capped at three.
	var owned_lines := prototype.progression.get_adaptation_line_ids(committing_path)
	var all_lines_open := owned_lines.size() == Progression.LINES_PER_ADAPTATION
	for line_id in owned_lines:
		all_lines_open = (
			all_lines_open
			and prototype.progression._is_upgrade_draftable(line_id)
			and prototype.progression.get_upgrade_maximum_level(line_id) == 3
		)
	report.check(
		all_lines_open,
		"entering an Adaptation opens all four of its rank-3 lines at once"
	)
	# A second uncommitted line fills Core 2 and freezes the Evolution, with no
	# milestone and no timer involved.
	SmokeFixtures.take_offered_upgrade(prototype, Progression.UpgradeId.ROOT_MATURATION)
	report.check(
		prototype.progression.secondary_path == Progression.PathId.ROOT
		and prototype.progression.get_pair_evolution_id() != Progression.EvolutionId.NONE
		and prototype.progression.has_branch_slot_open(),
		"a second uncommitted line locks the Core pair, with the Branch slot already open"
	)
	# With both Cores committed and a Branch still empty, unowned lines stay on offer:
	# the roster's whole shape is available from the first level-up now, so a draft
	# narrows when the *slots* are full rather than when the Campaign says so.
	var narrowed := prototype.progression.get_ordinary_candidate_lines()
	var narrowed_to_owned := not narrowed.is_empty()
	for option_id in narrowed:
		narrowed_to_owned = (
			narrowed_to_owned
			and prototype.progression.owns_adaptation(
				prototype.progression._get_upgrade_path(option_id)
			)
		)
	report.check(
		not narrowed.is_empty() and not narrowed_to_owned,
		"an open Branch slot keeps unowned lines on offer"
	)
	# The clock still hands out nothing by itself. What changed is that the *room* is
	# there from the start: the Adaptation that fills it is drafted, and a run that never
	# takes the draft never gains one however long it stands around.
	prototype.debug_advance_time(600.0)
	prototype.debug_advance_time(600.0)
	report.check(
		prototype.progression.get_owned_adaptation_count() == 2
		and prototype.progression.has_branch_slot_open(),
		"time alone fills no slot, and the open Branch waits to be drafted into"
	)
	# The Elite pays its relic and its draft, and what fills the slot is drafted like
	# everything else.
	prototype.progression._pending_upgrade_options.clear()
	prototype.progression._pending_relic_options.clear()
	prototype._choice_kind = RunRoot.ChoiceKind.NONE
	prototype.choice_panel.visible = false
	prototype._on_elite_defeated()
	var branch_draft_offered := false
	var branch_draft_is_unowned := true
	if prototype.progression.is_pending_adaptation_draft():
		branch_draft_offered = true
		for option_id in prototype.progression.get_pending_upgrade_options():
			branch_draft_is_unowned = (
				branch_draft_is_unowned
				and not prototype.progression.owns_adaptation(
					prototype.progression._get_upgrade_path(option_id)
				)
			)
	report.check(
		prototype.progression.unlocked_branch_slots
		== prototype.progression.get_branch_slot_limit()
		and prototype.progression.has_branch_slot_open(),
		"the Elite pays without needing to sell permission the run already had"
	)
	report.check(
		branch_draft_offered and branch_draft_is_unowned,
		"the Elite's Adaptation reward is a draft of unowned lines, never a Path screen"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	var authored_rerolls := prototype.progression.rerolls_per_run
	SmokeFixtures.seed_run_adaptations(
		prototype,
		Progression.PathId.SPORE,
		Progression.PathId.ROOT
	)
	report.check(
		prototype.progression.rerolls_remaining == authored_rerolls
		and authored_rerolls > 0,
		"a fresh run starts with its authored upgrade-draft rerolls (%d)"
			% authored_rerolls
	)
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var first_roll := prototype.progression.get_pending_upgrade_options()
	var reroll_worked := prototype.progression.reroll_upgrade_choice()
	var second_roll := prototype.progression.get_pending_upgrade_options()
	var reroll_changed_offer := false
	for option_id in second_roll:
		if not first_roll.has(option_id):
			reroll_changed_offer = true
	report.check(
		reroll_worked
		and reroll_changed_offer
		and second_roll.size() == first_roll.size()
		and prototype.progression.rerolls_remaining == authored_rerolls - 1
		and prototype.progression.current_level == 2
		and prototype.choice_panel.reroll_button.visible
		and prototype.choice_panel.reroll_button.text
			== "REROLL  (%d LEFT)" % (authored_rerolls - 1),
		"a reroll redraws the same draft for a different offer without spending a level"
	)

	# Restarting a run has to deal a different hand. This was the bug: the draft walked
	# a cursor that started at the top of the enum every run and took three evenly
	# spaced candidates, so every run opened on the same three lines and a reroll only
	# stepped that cursor along a fixed sequence.
	var pinned_seed := prototype.progression.authored_run_seed
	prototype.progression.authored_run_seed = 0
	var openings := {}
	var rolled_seeds := {}
	for _fresh_run in range(12):
		prototype.reset_run()
		rolled_seeds[prototype.progression.run_seed] = true
		SmokeFixtures.seed_run_adaptations(
			prototype,
			Progression.PathId.SPORE,
			Progression.PathId.ROOT
		)
		prototype.progression.add_xp(prototype.progression.get_required_xp())
		var opening := ""
		for option_id in prototype.progression.get_pending_upgrade_options():
			opening += "%d," % option_id
		openings[opening] = true
	# Replaying a seed has to reproduce the run exactly, or a reported run cannot be
	# looked at. The same pin, twice, has to deal the same hand.
	var replays := {}
	for _replay in range(3):
		prototype.reset_run()
		prototype.progression.set_run_seed(0x5EED1234)
		SmokeFixtures.seed_run_adaptations(
			prototype,
			Progression.PathId.SPORE,
			Progression.PathId.ROOT
		)
		prototype.progression.add_xp(prototype.progression.get_required_xp())
		var replayed := ""
		for option_id in prototype.progression.get_pending_upgrade_options():
			replayed += "%d," % option_id
		replays[replayed] = true
	report.check(
		openings.size() >= 8
		and rolled_seeds.size() == 12
		and replays.size() == 1,
		"restarting deals a different hand, and a pinned seed replays one exactly "
			+ "(%d openings and %d seeds in 12 runs)" % [openings.size(), rolled_seeds.size()]
	)
	prototype.progression.authored_run_seed = pinned_seed
	prototype.reset_run()
	SmokeFixtures.seed_run_adaptations(
		prototype,
		Progression.PathId.SPORE,
		Progression.PathId.ROOT
	)
	prototype.progression.add_xp(prototype.progression.get_required_xp())


	# A reroll must actually change the offer. Stepping the cursor by one can land
	# on the same spread, which is what made the button look dead.
	var reroll_changes := 0
	var reroll_attempts := 0
	for _reroll_probe in range(prototype.progression.rerolls_remaining):
		var before_offer := prototype.progression.get_pending_upgrade_options()
		if not prototype.progression.reroll_upgrade_choice():
			break
		reroll_attempts += 1
		var after_offer := prototype.progression.get_pending_upgrade_options()
		var differs := false
		for option_id in after_offer:
			if before_offer.find(option_id) == -1:
				differs = true
		reroll_changes += 1 if differs else 0
	report.check(
		reroll_attempts > 0
		and reroll_changes == reroll_attempts
		and not prototype.progression.get_pending_upgrade_options().is_empty(),
		"every spent reroll returns a genuinely different offer"
	)
	for _spend_reroll in range(authored_rerolls - 1):
		prototype.progression.reroll_upgrade_choice()
	var exhausted_reroll := prototype.progression.reroll_upgrade_choice()
	report.check(
		not exhausted_reroll
		and prototype.progression.rerolls_remaining == 0
		and prototype.choice_panel.reroll_button.disabled
		and not prototype.progression.get_pending_upgrade_options().is_empty(),
		"a run spends exactly its authored rerolls and keeps its offer once they are gone"
	)
	prototype._choose_displayed_option(0)
	report.check(
		not prototype.choice_panel.reroll_button.visible,
		"the reroll control disappears with the draft panel"
	)
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	report.check(
		prototype.progression.rerolls_remaining == prototype.progression.rerolls_per_run,
		"restarting a run restores every reroll"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	var root_lines := PackedInt32Array([
		Progression.UpgradeId.ROOT_MATURATION,
		Progression.UpgradeId.ROOT_LATERAL_ROOTS,
		Progression.UpgradeId.ROOT_MATURE_STRENGTH,
		Progression.UpgradeId.ROOT_POTENCY,
	])
	var root_lines_belong := true
	for line_id in root_lines:
		root_lines_belong = (
			root_lines_belong
			and prototype.progression._get_upgrade_path(line_id)
			== Progression.PathId.ROOT
		)
	report.check(
		root_lines_belong and root_lines.size() == 4,
		"Root contributes its four GDD lines to the Plant roster"
	)

	prototype.progression.reset_progression()
	prototype.progression.offer_bramble_path = false
	var switched_off_offered := prototype.progression.get_acquirable_adaptations().has(
		Progression.PathId.BRAMBLE
	)
	var other_path_still_offered := prototype.progression.get_acquirable_adaptations().has(
		Progression.PathId.SPORE
	)
	prototype.progression.offer_bramble_path = true
	prototype.progression.reset_progression()
	report.check(
		not switched_off_offered
		and other_path_still_offered
		and prototype.progression.get_acquirable_adaptations().has(
			Progression.PathId.BRAMBLE
		),
		"a path switched off in the inspector is never enterable"
	)
	# One Core committed and one slot still open: the unowned lines stay on the
	# table, because taking one is how the second Core is entered.
	prototype.progression.reset_progression()
	prototype.progression.acquire_adaptation(Progression.PathId.SPORE)
	var open_slot_keeps_unowned := prototype.progression._is_upgrade_draftable(
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT
	)
	# Every slot filled -- both Cores and the Branch the run now starts with -- so the
	# draft narrows to what it holds. The narrowing is a property of the roster being
	# full, not of a milestone the Campaign has yet to reach.
	prototype.progression.acquire_adaptation(Progression.PathId.ROOT)
	for _branch in range(prototype.progression.get_branch_slot_limit()):
		prototype.progression.acquire_adaptation(Progression.PathId.THISTLE)
		prototype.progression.acquire_adaptation(Progression.PathId.VINE)
	report.check(
		open_slot_keeps_unowned
		and prototype.progression._is_upgrade_draftable(
			Progression.UpgradeId.SEED_PRODUCTION
		)
		and not prototype.progression._is_upgrade_draftable(
			Progression.UpgradeId.BRAMBLE_ENTANGLEMENT
		),
		"unowned lines stay draftable while a slot is open and vanish once none is"
	)
	prototype.progression.reset_progression()
	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false

	prototype.progression.debug_select_paths(
		Progression.PathId.ROOT,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	var root_base_maturation: float = prototype.territory_field.tuning.maturation_per_second
	var root_base_reach := prototype.root_director.get_lateral_reach()
	var root_base_resistance := prototype.territory_field.get_mature_resistance_multiplier()
	var root_base_network := prototype.root_director.get_network_bonus()
	for line_id in root_lines:
		prototype.progression._upgrade_levels[line_id] = 3
	prototype._apply_progression_modifiers()
	report.check(
		prototype.territory_field.tuning.maturation_per_second > root_base_maturation
		and prototype.root_director.get_lateral_reach() > root_base_reach
		and prototype.territory_field.get_mature_resistance_multiplier()
		> root_base_resistance
		and prototype.territory_field.tuning.regeneration_per_second > 0.0
		and prototype.root_director.get_network_bonus() > root_base_network,
		"Root's lines raise maturation, Lateral reach, Mature Strength, and Root Potency"
	)
	report.check(
		root_base_network > 0.0
		and prototype.root_director.get_network_bonus()
		> prototype.root_director.base_network_bonus,
		"Root Potency deepens the Root Network amplification Root already supplies"
	)

	# Lateral Roots: an established colony projects Root support into the younger
	# Green in front of it, and that support never crosses ground the run does not
	# hold. It also never makes the supported ground Mature.
	prototype.progression.debug_select_paths(
		Progression.PathId.ROOT,
		Progression.PathId.SPORE
	)
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.ROOT_LATERAL_ROOTS
	] = 5
	prototype._apply_progression_modifiers()
	var lateral_spot := SmokeFixtures.find_owned_cell_position(prototype)
	for _lateral_ripen in range(6):
		prototype.territory_field.queue_maturity_support(lateral_spot, 1.0, 4.0)
		prototype.territory_field.step_simulation()
	var lateral_reach := prototype.root_director.get_lateral_reach()
	var on_mature := prototype.territory_field.get_mature_projection_at(
		lateral_spot, lateral_reach
	)
	var raw_maturity := prototype.territory_field.get_maturity_at_local(lateral_spot)
	var projected := prototype.root_director.get_projected_maturity_at(
		lateral_spot, raw_maturity
	)
	# Off the board entirely there is no owned Green to carry support through.
	var unowned_projection := prototype.territory_field.get_mature_projection_at(
		Vector2(-500.0, -500.0), lateral_reach
	)
	report.check(
		lateral_reach > 0.0
		and on_mature > 0.0
		and projected >= raw_maturity
		and is_equal_approx(unowned_projection, 0.0),
		"LATERAL ROOTS projects Root support through owned Green and never off it"
	)
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.ROOT_LATERAL_ROOTS
	] = 0
	prototype._apply_progression_modifiers()

	prototype.progression.debug_select_paths(
		Progression.PathId.ROOT,
		Progression.PathId.SPORE
	)
	for line_id in root_lines:
		prototype.progression._upgrade_levels[line_id] = 5
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	var healing_cells := SmokeFixtures.find_player_frontier_cells(prototype.territory_field, 1)
	var healing_index := (
		healing_cells[0].y * prototype.territory_field.tuning.field_size.x
		+ healing_cells[0].x
	)
	prototype.territory_field._control[healing_index] = 0.30
	prototype.territory_field.step_simulation()
	var regenerated: float = prototype.territory_field._control[healing_index]
	prototype.territory_field.tuning.regeneration_per_second = 0.0
	prototype.territory_field.reset_field()
	prototype.territory_field._control[healing_index] = 0.30
	prototype.territory_field.step_simulation()
	var unregenerated: float = prototype.territory_field._control[healing_index]
	prototype._apply_progression_modifiers()
	report.check(
		regenerated > unregenerated,
		"Regeneration heals damaged Green that the player still holds"
	)
