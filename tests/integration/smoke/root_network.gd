## The Root Network: Seasons on the clock, Mature ground that erupts under a held
## enemy, and the cascade Ancient Fury buys.
##
## An eruption is an interior effect, so most of this stands somewhere deliberately
## far from the frontier - the hedge reaches a few cells in, and ground within it
## would answer for the wrong reason.
class_name SmokeRootNetwork
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	prototype.territory_field.reset_field()
	var root_mature_cell := SmokeFixtures.find_player_frontier_cells(prototype.territory_field, 1)[0]
	var root_mature_index := (
		root_mature_cell.y * prototype.territory_field.tuning.field_size.x + root_mature_cell.x
	)
	var root_mature_spot := prototype.territory_field.cell_to_local(Vector2(root_mature_cell))
	prototype.territory_field._maturity[root_mature_index] = 1.0
	var root_mature_control_before: float = prototype.territory_field._control[root_mature_index]
	prototype.territory_field.queue_erosion(root_mature_spot, 0.45, 0.5)
	prototype.territory_field._apply_pending_commands()
	var hardened_loss := (
		root_mature_control_before - prototype.territory_field._control[root_mature_index]
	)
	prototype.territory_field.set_mature_resistance_multiplier(1.0)
	prototype.territory_field.reset_field()
	prototype.territory_field._maturity[root_mature_index] = 1.0
	prototype.territory_field.queue_erosion(root_mature_spot, 0.45, 0.5)
	prototype.territory_field._apply_pending_commands()
	var plain_loss := (
		root_mature_control_before - prototype.territory_field._control[root_mature_index]
	)
	prototype._apply_progression_modifiers()
	report.check(
		hardened_loss > 0.0 and hardened_loss < plain_loss,
		"Mature Resistance hardens settled Plant against erosion"
	)

	report.check(
		prototype.progression.get_pair_evolution_id()
		== Progression.EvolutionId.SEED_BANK,
		"Spore plus Root pairs into Seed Bank"
	)
	prototype.progression.debug_select_paths(
		Progression.PathId.BLOOM,
		Progression.PathId.ROOT
	)
	report.check(
		prototype.progression.get_pair_evolution_id()
		== Progression.EvolutionId.FLOWERING_SEASON,
		"Bloom plus Root pairs into Flowering Season"
	)
	prototype.progression.debug_select_paths(
		Progression.PathId.BRAMBLE,
		Progression.PathId.ROOT
	)
	report.check(
		prototype.progression.get_pair_evolution_id()
		== Progression.EvolutionId.OLD_GROWTH,
		"Bramble plus Root pairs into Old Growth"
	)

	prototype.progression.debug_select_paths(
		Progression.PathId.SPORE,
		Progression.PathId.ROOT
	)
	prototype.progression.debug_complete_evolution_requirements()
	var seed_bank_granted := prototype.progression.grant_evolution_if_ready()
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	SmokeFixtures.step_field(prototype.territory_field, 2)
	for mature_index in range(prototype.territory_field._maturity.size()):
		if prototype.territory_field._player_frontier_mask[mature_index] != 0:
			prototype.territory_field._maturity[mature_index] = 1.0
	prototype.overlay.clear_effects()
	prototype.combat.reset_combat()
	# Claiming Seed Bank is itself a Season: the free wave lands at once rather than
	# waiting out the clock, which is the power spike the Evolution is sold on.
	prototype.spore_director._seed_bank_storage = 0.0
	prototype.spore_director.advance(0.016)
	var claim_season_seeds := prototype.overlay.get_active_seed_count()
	prototype.overlay.clear_effects()
	# From there the Season is a clock. Storage alone does not fire one; the interval
	# elapsing does, and it spends what the Bank had stored.
	prototype.spore_director._seed_bank_storage = (
		prototype.evolutions.germination_season_threshold
	)
	prototype.spore_director.advance(0.016)
	var seeds_before_interval := prototype.overlay.get_active_seed_count()
	prototype.spore_director.advance(
		prototype.evolutions.germination_season_interval
	)
	report.check(
		seed_bank_granted
		and prototype.progression.active_evolution
		== Progression.EvolutionId.SEED_BANK
		and claim_season_seeds > 1
		and seeds_before_interval == 0
		and prototype.overlay.get_active_seed_count() > 1
		and prototype.spore_director.get_seed_bank_storage() < 1.0,
		"claiming Seed Bank fires a free Season, and later Seasons run on the clock"
	)
	prototype.overlay.clear_effects()

	prototype.progression.debug_select_paths(
		Progression.PathId.BLOOM,
		Progression.PathId.ROOT
	)
	prototype.progression.debug_complete_evolution_requirements()
	var flowering_granted := prototype.progression.grant_evolution_if_ready()
	prototype._apply_progression_modifiers()
	prototype.bloom_director._flowering_charge = (
		prototype.evolutions.flowering_season_charge_required
	)
	prototype.bloom_director.advance(0.016)
	# The bloom count is an authored balance value, so the check is that the stored
	# charge is spent on the flowering the run actually authors, not on a fixed number.
	var authored_flowering_blooms := prototype.evolutions.flowering_season_bloom_count
	var flowering_blooms := prototype.overlay.get_active_bloom_count()
	report.check(
		flowering_granted
		and authored_flowering_blooms > 0
		and flowering_blooms > 0
		and flowering_blooms <= authored_flowering_blooms
		and prototype.bloom_director.get_flowering_charge() < 1.0,
		"Flowering Season spends its stored charge on its authored flowering (%d of %d Blooms)"
			% [flowering_blooms, authored_flowering_blooms]
	)
	prototype.overlay.clear_effects()

	prototype.progression.debug_select_paths(
		Progression.PathId.BRAMBLE,
		Progression.PathId.ROOT
	)
	prototype.progression.debug_complete_evolution_requirements()
	var old_growth_granted := prototype.progression.grant_evolution_if_ready()
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	prototype.combat.set_bramble_modifiers(true, 0.30, 1.0, 0.0, 4.0, 0.0, true)
	var field_width_og := prototype.territory_field.tuning.field_size.x
	var interior_index := SmokeFixtures.find_deep_owned_cell(
		prototype.territory_field,
		prototype.combat.bramble_frontier_band_pixels
	)
	var interior_spot := prototype.territory_field.cell_to_local(
		Vector2(interior_index % field_width_og, interior_index / field_width_og)
	)
	# Fresh interior is hazardous but never wakes the Root Network.
	prototype.territory_field._maturity[interior_index] = 0.20
	prototype.territory_field._territory_age[interior_index] = 0.0
	var fresh_enemy := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.HUNTER,
		interior_spot
	)
	fresh_enemy.entanglement = 1.0
	var fresh_health_before := fresh_enemy.health
	var eruptions_before := prototype.combat.get_active_root_eruption_count()
	prototype.combat.simulate_step(0.0)
	var fresh_interior_damage := fresh_health_before - fresh_enemy.health
	var fresh_eruptions := (
		prototype.combat.get_active_root_eruption_count() - eruptions_before
	)
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0

	# Mature interior erupts once the enemy standing on it is heavily Entangled.
	prototype.territory_field._maturity[interior_index] = 1.0
	prototype.territory_field._territory_age[interior_index] = (
		prototype.territory_field.tuning.age_reference_seconds
	)
	var mature_enemy := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.HUNTER,
		interior_spot
	)
	mature_enemy.entanglement = 0.0
	prototype.combat.simulate_step(0.0)
	var untangled_eruptions := prototype.combat.get_active_root_eruption_count()
	mature_enemy.entanglement = 1.0
	mature_enemy.bramble_damage_remaining = 0.0
	mature_enemy.bramble_eruption_remaining = 0.0
	var mature_health_before := mature_enemy.health
	prototype.combat.simulate_step(0.0)
	var mature_interior_damage := mature_health_before - mature_enemy.health
	report.check(
		old_growth_granted
		and prototype.territory_field.is_old_growth_enabled()
		and fresh_interior_damage > 0.0
		and fresh_eruptions == 0
		and untangled_eruptions == 0
		and prototype.combat.get_active_root_eruption_count() > untangled_eruptions
		and mature_interior_damage > fresh_interior_damage,
		"Old Growth erupts under heavily Entangled enemies on ancient ground alone"
	)

	# A kill inside the Root Network wakes the ground under the next enemy.
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	var cascade_enemy: EnemyState = SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.HUNTER,
		interior_spot
	)
	cascade_enemy.health = 1.0
	prototype.combat._erupt_root_network(interior_spot, 0)
	var queued_cascade := false
	for pending in prototype.combat._pending_eruptions:
		queued_cascade = queued_cascade or pending.active
	# Kill-chaining is the Ancient Fury Root Cascade rank, not base Old Growth.
	var base_chain_queued := false
	for pending in prototype.combat._pending_eruptions:
		base_chain_queued = base_chain_queued or pending.active
	report.check(
		not base_chain_queued,
		"base Old Growth erupts without chaining until Ancient Fury buys the cascade"
	)
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.EVOLUTION_ANCIENT_FURY
	] = 3
	prototype._apply_progression_modifiers()
	prototype.combat.reset_combat()
	prototype.combat._cane_remaining = 999.0
	cascade_enemy = SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.HUNTER,
		interior_spot
	)
	cascade_enemy.health = 1.0
	prototype.combat._erupt_root_network(interior_spot, 0)
	queued_cascade = false
	for pending in prototype.combat._pending_eruptions:
		queued_cascade = queued_cascade or pending.active
	var cascade_eruptions_before := prototype.combat.get_active_root_eruption_count()
	# Clear the retrigger guard first: the eruption just fired above already armed
	# it, and the point of this check is what a fresh burst does.
	prototype.combat._old_growth_sfx_retrigger_remaining = 0.0
	var old_growth_cue_before := prototype.combat.get_old_growth_sfx_play_count()
	# Fire several eruptions inside one frame: the cue must swell once, not once
	# per eruption, or a cascade turns into a stack of identical voices.
	var eruptions_this_cascade := 5
	for _cascade_index in range(eruptions_this_cascade):
		prototype.combat._erupt_root_network(interior_spot, 1)
	var old_growth_cue_count := prototype.combat.get_old_growth_sfx_play_count()
	prototype.combat.simulate_step(
		prototype.combat.old_growth_eruption_chain_delay_seconds + 0.01
	)
	report.check(
		not cascade_enemy.active
		and queued_cascade
		and prototype.combat.get_active_root_eruption_count() > cascade_eruptions_before,
		"a root eruption kill chains another eruption through the Root Network"
	)
	report.check(
		prototype.combat.old_growth_sfx != null
		and old_growth_cue_count == old_growth_cue_before + 1
		and eruptions_this_cascade > 1,
		"the Root Network erupting plays its cue, and a cascade swells once rather than per eruption"
	)

	prototype.combat.set_bramble_modifiers(true, 0.30, 1.0, 0.0, 4.0, 0.0, false)
	prototype.combat.reset_combat()
	var disabled_enemy := SmokeFixtures.spawn_bramble_contact_enemy(
		prototype,
		EnemyKinds.Role.HUNTER,
		interior_spot
	)
	disabled_enemy.entanglement = 1.0
	var disabled_eruptions_before := prototype.combat.get_active_root_eruption_count()
	prototype.combat.simulate_step(0.0)
	report.check(
		prototype.combat.get_active_root_eruption_count() == disabled_eruptions_before,
		"Mature ground never erupts for a run that has not evolved Old Growth"
	)
