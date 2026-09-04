extends SceneTree

## Thistle is deliberately absent: its four lines take Root amplification in
## authored form rather than as virtual ranks, and _test_thistle_outputs checks
## that shape instead.
const ADAPTATION_UPGRADES := [
	PhaseBProgression.UpgradeId.VINE_ELONGATION,
	PhaseBProgression.UpgradeId.VINE_LIGNIFICATION,
	PhaseBProgression.UpgradeId.VINE_TURGOR,
	PhaseBProgression.UpgradeId.VINE_APICAL_DOMINANCE,
	PhaseBProgression.UpgradeId.FRUIT_SET,
	PhaseBProgression.UpgradeId.FRUIT_RIPENING,
	PhaseBProgression.UpgradeId.FRUIT_MOMENTUM,
	PhaseBProgression.UpgradeId.FRUIT_GERMINATION,
]

const THISTLE_UPGRADES := [
	PhaseBProgression.UpgradeId.THISTLE_CLUSTERING,
	PhaseBProgression.UpgradeId.THISTLE_DEHISCENCE,
	PhaseBProgression.UpgradeId.THISTLE_BURR,
	PhaseBProgression.UpgradeId.THISTLE_NEEDLEPOINT,
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://scenes/run/phase_b_prototype.tscn") != OK:
		quit(1)
		return
	await process_frame
	await process_frame
	var prototype := current_scene as PhaseBPrototype
	if prototype == null:
		quit(1)
		return
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype._set_simulation_paused(true)
	_configure_owned_build(prototype)

	var origin := prototype.player.get_arena_position()
	var cell := prototype.territory_field.local_to_cell_index(origin)
	prototype.territory_field._control[cell] = 1.0
	prototype.territory_field._maturity[cell] = 1.0
	prototype.adaptation_director._refresh_vine_modifiers()

	for upgrade_id in ADAPTATION_UPGRADES:
		_check(
			prototype.adaptation_director._effective_upgrade(upgrade_id, origin) == 6,
			"owned %s receives five Potency ranks" % PhaseBProgression.get_upgrade_name(upgrade_id)
		)
	for upgrade_id in THISTLE_UPGRADES:
		_check(
			prototype.adaptation_director._effective_upgrade(upgrade_id, origin) == 1,
			"owned %s takes no virtual Potency ranks" % PhaseBProgression.get_upgrade_name(
				upgrade_id
			)
		)
	_test_thistle_outputs(prototype, origin)
	_test_vine_outputs(prototype)
	_test_fruit_outputs(prototype, origin)
	_test_jackpot_gates(prototype, origin)

	prototype.queue_free()
	await process_frame
	if _failures == 0:
		print("ROOT_NEW_ADAPTATIONS_PROBE: PASS")
		quit(0)
	else:
		push_error("ROOT_NEW_ADAPTATIONS_PROBE: %d failure(s)" % _failures)
		quit(1)


func _configure_owned_build(prototype: PhaseBPrototype) -> void:
	var progression := prototype.progression
	progression.reset_progression()
	progression.debug_select_paths(
		PhaseBProgression.PathId.ROOT,
		PhaseBProgression.PathId.THISTLE
	)
	progression.debug_select_tertiary_path(PhaseBProgression.PathId.VINE)
	progression._upgrade_levels[PhaseBProgression.UpgradeId.ROOT_POTENCY] = 5
	for upgrade_id in ADAPTATION_UPGRADES + THISTLE_UPGRADES:
		progression._upgrade_levels[upgrade_id] = 1
	prototype._apply_progression_modifiers()
	prototype.adaptation_director.reset_adaptations()
	prototype.combat.reset_combat()


func _test_thistle_outputs(prototype: PhaseBPrototype, origin: Vector2) -> void:
	## Thistle's four lines each take Root Potency in the shape that line is about:
	## Clustering and Burr are counts and get one whole unit, Dehiscence and
	## Needlepoint are rates and get Potency's own amplification.
	var adaptations := prototype.adaptation_director
	var amplification := prototype.root_director.get_network_multiplier_here(origin)
	_check(amplification > 1.0, "Mature ground under the turret is amplifying at all")
	var enemy_id := prototype.combat.spawn_enemy(
		PhaseBCombatDirector.EnemyRole.BOSS,
		origin + Vector2(48.0, 0.0)
	)
	adaptations._spawn_thorn(origin, enemy_id, 1.0, 0, false, false, 0.0)
	var thorn = adaptations._thorns[0]
	_check(thorn.ricochets_remaining == 2, "Burr rank 1 plus Potency gives one more ricochet")
	_check(
		is_equal_approx(thorn.critical_chance_bonus, 0.10 * amplification),
		"Needlepoint critical chance is scaled by Potency's amplification"
	)
	_check(is_equal_approx(thorn.damage, adaptations.thistle_damage), "Root no longer adds blanket Thistle damage")
	_check(
		is_equal_approx(
			adaptations._get_thistle_attack_interval(origin),
			adaptations.thistle_attack_interval / (1.15 * amplification)
		),
		"Dehiscence attack speed is scaled by Potency's amplification"
	)
	for candidate in adaptations._thorns:
		candidate.active = false
	var thistle = adaptations._thistles[0]
	thistle.active = true
	thistle.position = origin
	adaptations._fire_thistle(thistle)
	_check(
		adaptations.get_active_thorn_count() == 3,
		"Clustering rank 1 plus Potency fires base 1 plus 2 thorns"
	)

	# Off Mature ground none of it applies: Root deepens the ground it has aged, and
	# a turret standing on fresh Green is a plain turret.
	var bare := origin + Vector2(400.0, 400.0)
	_check(
		adaptations._thistle_root_step(
			PhaseBProgression.UpgradeId.THISTLE_CLUSTERING, bare
		) == 0
		and is_equal_approx(
			adaptations._thistle_root_scale(
				PhaseBProgression.UpgradeId.THISTLE_NEEDLEPOINT, bare
			),
			1.0
		),
		"Potency amplifies nothing for a Thistle standing off Mature ground"
	)


func _test_vine_outputs(prototype: PhaseBPrototype) -> void:
	var combat := prototype.combat
	_check(is_equal_approx(combat._cane_reach_multiplier, 2.20), "Elongation uses 6 effective ranks")
	_check(is_equal_approx(combat._cane_damage_multiplier, 2.50), "Lignification uses 6 effective ranks")
	_check(is_equal_approx(combat._cane_cooldown_multiplier, 1.0 / 1.90), "Turgor uses 6 effective ranks")
	_check(is_equal_approx(combat._cane_apical_damage_bonus, 1.50), "Apical Dominance uses 6 effective ranks")


func _test_fruit_outputs(prototype: PhaseBPrototype, origin: Vector2) -> void:
	var adaptations := prototype.adaptation_director
	var fruit = adaptations._spawn_fruit(origin, Vector2.RIGHT)
	_check(is_equal_approx(fruit.damage, adaptations.fruit_collision_damage * 2.50), "Ripening uses 6 effective ranks")
	_check(
		is_equal_approx(fruit.terminal_damage, adaptations.fruit_terminal_explosion_damage * 2.50),
		"Ripening scales terminal damage at 6 effective ranks"
	)
	_check(is_equal_approx(fruit.normal_roll_distance, adaptations.fruit_roll_distance_pixels * 2.20), "Momentum uses 6 effective ranks")
	_check(is_equal_approx(fruit.germination_multiplier, 2.20), "Germination uses 6 effective ranks")
	for candidate in adaptations._fruits:
		candidate.active = false
	adaptations._begin_normal_fruit_release()
	_check(adaptations.get_active_fruit_count() == 7, "Fruit Set produces base 1 plus 6 Fruit")


func _test_jackpot_gates(prototype: PhaseBPrototype, origin: Vector2) -> void:
	var progression := prototype.progression
	var adaptations := prototype.adaptation_director
	var fruit_set := PhaseBProgression.UpgradeId.FRUIT_SET
	progression._upgrade_levels[fruit_set] = 0
	progression.set_casino_path_active(PhaseBProgression.PathId.FRUIT, true)
	_check(
		adaptations._effective_upgrade(fruit_set, origin) == progression.casino_upgrade_level,
		"Fruit jackpot does not make unowned Fruit Set eligible for Potency"
	)
	progression.set_casino_path_active(PhaseBProgression.PathId.FRUIT, false)
	progression._upgrade_levels[fruit_set] = 1
	progression._upgrade_levels[PhaseBProgression.UpgradeId.ROOT_POTENCY] = 0
	progression.set_casino_path_active(PhaseBProgression.PathId.ROOT, true)
	_check(
		adaptations._effective_upgrade(fruit_set, origin) == 1,
		"Root jackpot does not substitute for purchased Root Potency"
	)
	progression.set_casino_path_active(PhaseBProgression.PathId.ROOT, false)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		push_error("FAIL: %s" % description)
