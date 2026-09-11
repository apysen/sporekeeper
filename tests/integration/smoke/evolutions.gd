## What a pair of Cores is worth: the Evolution only the pair can reach, the
## Branches that complete an Adaptation without ever touching it, and the relic pool
## each of those unlocks.
##
## It runs on the drafted build the blocks above leave behind rather than building
## its own, because what is being checked is what ownership entitles a run to.
class_name SmokeEvolutions
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	# Four Adaptations, three ranks each, one Evolution from the Core pair alone.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.SPORE,
		Progression.PathId.ROOT
	)
	var ready_before_investment := prototype.progression.evolution_status
	# One mastered line in each Core is deliberately not enough.
	prototype.progression._upgrade_levels[Progression.UpgradeId.GROWTH_MASS] = 3
	prototype.progression._upgrade_levels[Progression.UpgradeId.ROOT_MATURATION] = 3
	prototype.progression._update_evolution_readiness()
	var ready_with_one_each := prototype.progression.evolution_status
	# Two in one Core and one in the other is not enough either.
	prototype.progression._upgrade_levels[Progression.UpgradeId.SPORULATION] = 3
	prototype.progression._update_evolution_readiness()
	var ready_with_lopsided := prototype.progression.evolution_status
	prototype.progression._upgrade_levels[Progression.UpgradeId.ROOT_POTENCY] = 3
	prototype.progression._update_evolution_readiness()
	report.check(
		ready_before_investment == Progression.EvolutionStatus.NOT_READY
		and ready_with_one_each == Progression.EvolutionStatus.NOT_READY
		and ready_with_lopsided == Progression.EvolutionStatus.NOT_READY
		and prototype.progression.evolution_status == Progression.EvolutionStatus.READY,
		"Evolution needs two mastered lines in each Core, not one and not two in one"
	)
	prototype.progression.grant_evolution_if_ready()
	var claimed_evolution := prototype.progression.active_evolution
	var evolution_line := Evolutions.get_evolution_upgrade_id(claimed_evolution)
	report.check(
		claimed_evolution == Progression.EvolutionId.SEED_BANK
		and prototype.progression.get_owned_upgrade_level(evolution_line) == 1
		and prototype.progression.get_upgrade_maximum_level(evolution_line) == 5
		and prototype.progression.get_upgrade_maximum_level(
			Progression.UpgradeId.GROWTH_MASS
		) == 3,
		"claiming Evolution grants rank 1 of a five-rank line while ordinary lines stop at three"
	)

	# Branches are complete Adaptations that never touch the Evolution. A Branch
	# cannot be entered before its milestone has opened room for it.
	var branch_before_milestone := prototype.progression.acquire_adaptation(
		Progression.PathId.BRAMBLE
	)
	prototype.progression.unlock_branch_slot()
	var branch_one := prototype.progression.acquire_adaptation(
		Progression.PathId.BRAMBLE
	)
	prototype.progression.unlock_branch_slot()
	var branch_two := prototype.progression.acquire_adaptation(
		Progression.PathId.THISTLE
	)
	var fifth_refused := not prototype.progression.acquire_adaptation(
		Progression.PathId.BLOOM
	)
	report.check(
		not branch_before_milestone
		and branch_one
		and branch_two
		and fifth_refused
		and prototype.progression.get_owned_adaptation_count() == 4
		and prototype.progression.is_branch_adaptation(Progression.PathId.BRAMBLE)
		and not prototype.progression.is_evolution_path(Progression.PathId.BRAMBLE)
		and prototype.progression.get_pair_evolution_id() == claimed_evolution,
		"a Branch waits for its milestone, then completes the roster without re-rolling the Evolution"
	)
	# A mastered Branch line must not satisfy the Core gate either.
	for branch_line in prototype.progression.get_adaptation_line_ids(
		Progression.PathId.BRAMBLE
	):
		prototype.progression._upgrade_levels[branch_line] = 3
	report.check(
		prototype.progression.is_adaptation_mastered(Progression.PathId.BRAMBLE)
		and prototype.progression.get_mastered_line_count(
			Progression.PathId.SPORE
		) == 2,
		"a mastered Branch counts toward its own mastery and never toward the Core gate"
	)

	# Every relic pool the roster owns, and only those.
	var eligible_pools := prototype.progression.get_eligible_relic_pool_ids()
	report.check(
		eligible_pools.size() == 5
		and eligible_pools.has(RelicCatalog.Pool.PLANT)
		and eligible_pools.has(RelicCatalog.Pool.THISTLE)
		and not eligible_pools.has(RelicCatalog.Pool.BLOOM)
		and prototype.progression.get_relic_run_state()
		== RelicCatalog.RunState.FULL_ROSTER,
		"a full roster opens Plant plus four Adaptation relic pools and the deepest rarity table"
	)

	# Every ordinary offer is drawn from the unrestricted pool: no Adaptation holds a
	# guaranteed slot, and a mastered one drops out of the draw entirely.
	for thistle_line in prototype.progression.get_adaptation_line_ids(
		Progression.PathId.THISTLE
	):
		prototype.progression._upgrade_levels[thistle_line] = 3
	var mastered_offered := false
	for _screen in range(12):
		prototype.progression._pending_upgrade_options.clear()
		if not prototype.progression._roll_upgrade_options():
			continue
		for option_id in prototype.progression.get_pending_upgrade_options():
			if option_id < 0:
				continue
			if (
				prototype.progression._get_upgrade_path(option_id)
				== Progression.PathId.THISTLE
			):
				mastered_offered = true
	report.check(
		not mastered_offered,
		"a mastered Adaptation stops appearing in ordinary offers"
	)
