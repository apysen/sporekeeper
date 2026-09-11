## Two things that happen without being aimed: Overgrow, which feeds the living
## frontier rather than a target, and Man-Eater, which turns the run's own Green into
## the thing that marks an enemy.
##
## Both are earned by an enemy's behaviour over time, so each block feeds the
## behaviour rather than forcing the effect.
class_name SmokeOvergrowManEater
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	var adaptations := prototype.adaptation_director

	# Overgrow is emergent: it injects Mass and Pressure into the living frontier
	# and lets the simulation decide, so it needs a frontier to act on at all.
	# The same opening, stepped the same number of times, with and without the
	# injection: what Overgrow buys is whatever the simulation makes of it.
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	SmokeFixtures.step_field(prototype.territory_field, 20)
	var green_without_overgrow := prototype.territory_field.get_player_cell_count()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	var overgrow_result := prototype.territory_field.overgrow(400.0, 400.0, 0.0)
	SmokeFixtures.step_field(prototype.territory_field, 20)
	report.check(
		overgrow_result.cell_count > 0
		and overgrow_result.mass_applied > 0.0
		and overgrow_result.pressure_applied > 0.0
		and prototype.territory_field.get_player_cell_count() > green_without_overgrow,
		"Overgrow injects Mass and Pressure along the frontier and the field resolves it"
	)

	# Production milestones announce themselves once and only once.
	prototype.metabolism.reset_metabolism()
	prototype.progression.reset_progression()
	var milestone_threshold := prototype.metabolism.production_milestones[0]
	prototype.progression.biomass_per_second = milestone_threshold + 1.0
	prototype.metabolism.advance(1.0 / 30.0)
	var milestones_after_first := prototype.metabolism.get_milestones_reached()
	prototype.metabolism.advance(1.0 / 30.0)
	report.check(
		milestones_after_first == 1
		and prototype.metabolism.get_milestones_reached() == 1,
		"a production milestone fires once when it is first reached"
	)
	prototype.metabolism.reset_metabolism()
	prototype.progression.reset_progression()

	# Bramble publishes its restraint as drawable tethers without simulating rope.
	prototype.progression.debug_select_paths(
		Progression.PathId.BRAMBLE,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	var tether_spot := SmokeFixtures.find_owned_cell_position(prototype)
	prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		tether_spot
	)
	prototype.combat.apply_entanglement_in_radius(tether_spot, 40.0, 1.0)
	prototype.bramble_director.advance(1.0 / 60.0)
	var tethers_drawn := prototype.overlay.get_active_tether_count()
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	prototype.bramble_director.advance(1.0 / 60.0)
	report.check(
		tethers_drawn > 0 and prototype.overlay.get_active_tether_count() == 0,
		"Bramble tethers appear on Entangled enemies and vanish with the path"
	)
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	prototype.territory_field.reset_field()

	# Man-Eater: enemies that graze on the run's Green long enough are marked, and
	# killing a marked one sprouts a plant out of the corpse that bites once. The
	# relic is paid for by the enemy, so nothing here is aimed or charged.
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	var man_eater := prototype.man_eater
	man_eater.reset_man_eater()
	var green_spot := SmokeFixtures.find_owned_cell_position(prototype)

	# Without the relic, grazing marks nobody.
	var grazer_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.GRAZER, green_spot
	)
	prototype.combat.enemy_ate_green.emit(
		grazer_id, 1.0, man_eater.required_consumption_seconds * 2.0
	)
	var marked_without_relic := man_eater.get_marked_count()
	prototype.progression._owned_relics[RelicCatalog.Id.MAN_EATER] = 1

	# The mark is earned by cumulative consumption, and it does not have to be
	# continuous: two short grazes add up to the same as one long one.
	prototype.combat.enemy_ate_green.emit(
		grazer_id, 1.0, man_eater.required_consumption_seconds * 0.5
	)
	var marked_halfway := man_eater.get_marked_count()
	var partial_progress := man_eater.get_consumption_seconds(grazer_id) > 0.0
	prototype.combat.enemy_ate_green.emit(
		grazer_id, 1.0, man_eater.required_consumption_seconds * 0.5
	)
	var marked_after := man_eater.is_marked(grazer_id)
	report.check(
		marked_without_relic == 0
		and marked_halfway == 0
		and partial_progress
		and marked_after,
		"MAN-EATER marks a grazer on cumulative Green consumption, not on one long graze"
	)

	# An unmarked corpse sprouts nothing; a marked one does, after its delay.
	var plain_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER, green_spot + Vector2(60.0, 0.0)
	)
	prototype.combat.damage_enemy_by_id(
		plain_id, 100000.0, CombatDirector.DeathSource.DEBUG
	)
	for _plain_tick in range(30):
		man_eater.advance(1.0 / 60.0)
	var maws_from_plain_corpse := man_eater.get_active_maw_count()
	prototype.combat.damage_enemy_by_id(
		grazer_id, 100000.0, CombatDirector.DeathSource.DEBUG
	)
	var erupted_instantly := man_eater.get_active_maw_count()
	for _erupt_tick in range(int(man_eater.eruption_delay_seconds * 60.0) + 4):
		man_eater.advance(1.0 / 60.0)
	var erupted_after_delay := man_eater.get_active_maw_count()
	report.check(
		maws_from_plain_corpse == 0
		and erupted_instantly == 0
		and erupted_after_delay == 1,
		"MAN-EATER sprouts only from a marked corpse, and only after its delay"
	)

	# The bite lands once, is capped in how many it takes, and then the plant dies.
	var prey := PackedInt32Array()
	for prey_index in range(man_eater.maximum_bite_targets + 3):
		prey.append(prototype.combat.spawn_enemy(
			EnemyKinds.Role.HEAVY_GRAZER,
			green_spot + Vector2(-20.0 + float(prey_index) * 6.0, 0.0)
		))
	var healthy_before := 0
	for prey_id in prey:
		if is_equal_approx(
			prototype.combat.get_enemy_health(prey_id),
			prototype.combat.heavy_grazer_profile.maximum_health
		):
			healthy_before += 1
	for _bite_tick in range(int(man_eater.maw_lifetime_seconds * 60.0) + 10):
		man_eater.advance(1.0 / 60.0)
	var bitten := 0
	for prey_id in prey:
		if prototype.combat.get_enemy_health(prey_id) < prototype.combat.heavy_grazer_profile.maximum_health:
			bitten += 1
	report.check(
		healthy_before == prey.size()
		and bitten > 0
		and bitten <= man_eater.maximum_bite_targets
		and man_eater.get_active_maw_count() == 0,
		"MAN-EATER bites once, takes no more than its cap, and the plant then dies (%d)"
			% bitten
	)

	# The global cooldown is the crowd-safety rule: a pile of marked deaths on one
	# frame cannot carpet the field with plants.
	man_eater.reset_man_eater()
	prototype.combat.reset_combat()
	var marked_pack := PackedInt32Array()
	for _pack_index in range(5):
		var packed_id := prototype.combat.spawn_enemy(
			EnemyKinds.Role.GRAZER, green_spot
		)
		marked_pack.append(packed_id)
		prototype.combat.enemy_ate_green.emit(
			packed_id, 1.0, man_eater.required_consumption_seconds
		)
	for packed_id in marked_pack:
		prototype.combat.damage_enemy_by_id(
			packed_id, 100000.0, CombatDirector.DeathSource.DEBUG
		)
	for _flood_tick in range(int(man_eater.eruption_delay_seconds * 60.0) + 4):
		man_eater.advance(1.0 / 60.0)
	report.check(
		man_eater.get_active_maw_count() <= 1
		and man_eater.get_eruption_count() <= 1 + man_eater.maximum_queued_eruptions,
		"MAN-EATER holds its global cooldown when a marked pack dies at once"
	)
	prototype.progression.reset_progression()
	prototype.combat.reset_combat()
	man_eater.reset_man_eater()

