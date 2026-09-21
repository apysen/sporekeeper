extends SceneTree

## Root Potency reaches Thistle, Vine, and Fruit one line at a time. Counts get one
## whole unit out of Mature ground; every other line gets its own per-rank bonus
## multiplied by the Network where the effect resolves. Nothing here goes through
## virtual ranks any more, which is what used to make a Fruit release look random.
const BONUS_LINES := {
	Progression.UpgradeId.VINE_ELONGATION: 0.20,
	Progression.UpgradeId.VINE_LIGNIFICATION: 0.25,
	Progression.UpgradeId.VINE_TURGOR: 0.15,
	Progression.UpgradeId.VINE_APICAL_DOMINANCE: 0.25,
	Progression.UpgradeId.FRUIT_RIPENING: 0.25,
	Progression.UpgradeId.FRUIT_MOMENTUM: 0.20,
	Progression.UpgradeId.FRUIT_GERMINATION: 0.20,
	Progression.UpgradeId.THISTLE_DEHISCENCE: 0.15,
	Progression.UpgradeId.THISTLE_NEEDLEPOINT: 1.0,
}

const COUNT_LINES := [
	Progression.UpgradeId.FRUIT_SET,
	Progression.UpgradeId.THISTLE_CLUSTERING,
	Progression.UpgradeId.THISTLE_BURR,
]

const OWNED_LINES := [
	Progression.UpgradeId.VINE_ELONGATION,
	Progression.UpgradeId.VINE_LIGNIFICATION,
	Progression.UpgradeId.VINE_TURGOR,
	Progression.UpgradeId.VINE_APICAL_DOMINANCE,
	Progression.UpgradeId.FRUIT_SET,
	Progression.UpgradeId.FRUIT_RIPENING,
	Progression.UpgradeId.FRUIT_MOMENTUM,
	Progression.UpgradeId.FRUIT_GERMINATION,
	Progression.UpgradeId.THISTLE_CLUSTERING,
	Progression.UpgradeId.THISTLE_DEHISCENCE,
	Progression.UpgradeId.THISTLE_BURR,
	Progression.UpgradeId.THISTLE_NEEDLEPOINT,
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://scenes/run/run.tscn") != OK:
		quit(1)
		return
	await process_frame
	await process_frame
	var prototype := current_scene as RunRoot
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

	var network := prototype.root_director.get_network_multiplier_here(origin)
	_check(network > 1.0, "Mature ground under the player is amplifying at all")
	# A line takes a share of the Network rather than all of it. The whole multiplier
	# made Root Potency a second rank multiplier stacked on the line's own rank, which
	# is where Root+Vine's runaway lived. The share is the contract now, so the probe
	# reads it from the director rather than hard-coding the old full-strength rule --
	# but it still asserts the shape, and `amplification > 1.0` below still requires
	# that a line on Mature ground is genuinely amplified.
	var amplification := (
		1.0
		+ (network - 1.0) * prototype.adaptation_director.root_line_network_share
	)
	_check(
		amplification > 1.0 and amplification <= network,
		"a line takes a share of the Network, and that share amplifies it"
	)

	for upgrade_id in BONUS_LINES:
		_check(
			is_equal_approx(
				prototype.adaptation_director._root_scaled_bonus(
					upgrade_id, BONUS_LINES[upgrade_id], origin
				),
				BONUS_LINES[upgrade_id] * amplification
			),
			"rank-1 %s takes its own bonus times its share of the Network" % (
				Progression.get_upgrade_name(upgrade_id)
			)
		)
	for upgrade_id in COUNT_LINES:
		_check(
			prototype.adaptation_director._root_count_step(upgrade_id, origin) == 1,
			"%s takes exactly one whole unit from Potency" % (
				Progression.get_upgrade_name(upgrade_id)
			)
		)

	_test_rooted_glow(prototype, origin)
	_test_off_mature_ground(prototype, origin)
	_test_thistle_outputs(prototype, origin, amplification)
	_test_vine_outputs(prototype, amplification, network)
	_test_fruit_outputs(prototype, origin, amplification)
	_test_jackpot_gates(prototype, origin)

	prototype.queue_free()
	await process_frame
	if _failures == 0:
		print("ROOT_NEW_ADAPTATIONS_PROBE: PASS")
		quit(0)
	else:
		push_error("ROOT_NEW_ADAPTATIONS_PROBE: %d failure(s)" % _failures)
		quit(1)


func _configure_owned_build(prototype: RunRoot) -> void:
	var progression := prototype.progression
	progression.reset_progression()
	progression.debug_select_paths(
		Progression.PathId.ROOT,
		Progression.PathId.THISTLE
	)
	progression.debug_select_tertiary_path(Progression.PathId.VINE)
	progression._upgrade_levels[Progression.UpgradeId.ROOT_POTENCY] = 5
	for upgrade_id in OWNED_LINES:
		progression._upgrade_levels[upgrade_id] = 1
	prototype._apply_progression_modifiers()
	prototype.adaptation_director.reset_adaptations()
	prototype.combat.reset_combat()


func _test_rooted_glow(prototype: RunRoot, origin: Vector2) -> void:
	## The light is the whole-unit gate made visible, so it has to agree with the
	## payout on both edges. If these ever diverge the player is being told a lie at
	## exactly the moment the count changes under them.
	var adaptations := prototype.adaptation_director
	adaptations._update_rooted_glow(0.016)
	var lit_on_mature := (
		adaptations._player_rooted_glow.lit
		and adaptations._root_count_step(
			Progression.UpgradeId.FRUIT_SET, origin
		) == 1
	)
	_check(lit_on_mature, "the light is on exactly where the whole unit is paid")
	_check(
		adaptations._player_rooted_glow.network > 1.0
		and is_equal_approx(
			adaptations._player_rooted_glow.network,
			prototype.root_director.get_network_multiplier_here(origin)
		),
		"the light reports the Network depth under it"
	)
	# Crossing an edge flares, which is the event the player actually needs to catch.
	_check(
		adaptations._player_rooted_glow.flare > 0.0,
		"crossing onto Mature ground flares"
	)
	var resting := prototype.player.get_arena_position()
	prototype.player.position = prototype.player.position + Vector2(4000.0, 4000.0)
	adaptations._update_rooted_glow(0.016)
	_check(
		not adaptations._player_rooted_glow.lit
		and adaptations._player_rooted_glow.flare > 0.0,
		"stepping off Mature ground goes dark and flares on the way out"
	)
	prototype.player.position = prototype.player.position - Vector2(4000.0, 4000.0)
	adaptations._update_rooted_glow(0.016)
	_check(
		is_equal_approx(prototype.player.get_arena_position().x, resting.x)
		and is_equal_approx(prototype.player.get_arena_position().y, resting.y)
		and adaptations._player_rooted_glow.lit,
		"the light comes back when the ground does"
	)


func _test_off_mature_ground(prototype: RunRoot, origin: Vector2) -> void:
	## Root deepens the ground it has aged. Bare ground gets no whole unit, and the
	## bonus scale falls back to 1.0 rather than snapping between two authored values.
	var adaptations := prototype.adaptation_director
	var bare := origin + Vector2(400.0, 400.0)
	_check(
		adaptations._root_count_step(Progression.UpgradeId.FRUIT_SET, bare) == 0
		and adaptations._root_count_step(
			Progression.UpgradeId.THISTLE_CLUSTERING, bare
		) == 0,
		"no whole unit is paid off Mature ground"
	)
	_check(
		is_equal_approx(
			adaptations._root_bonus_scale(
				Progression.UpgradeId.THISTLE_NEEDLEPOINT, bare
			),
			1.0
		)
		and is_equal_approx(
			adaptations._root_bonus_scale(Progression.UpgradeId.FRUIT_MOMENTUM, bare),
			1.0
		),
		"Potency amplifies nothing off Mature ground"
	)


func _test_thistle_outputs(
	prototype: RunRoot,
	origin: Vector2,
	amplification: float
) -> void:
	## Clustering and Burr are counts and get one whole unit; Dehiscence and
	## Needlepoint are rates and get their own per-rank bonus amplified. Needlepoint
	## is critical damage now rather than critical chance, and the Network scales the
	## bonus it grants the same way it scaled the odds it used to grant.
	var adaptations := prototype.adaptation_director
	var enemy_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.BOSS,
		origin + Vector2(48.0, 0.0)
	)
	adaptations._spawn_thorn(origin, enemy_id, 1.0, 0, false, false, 0.0)
	var thorn = adaptations._thorns[0]
	_check(thorn.ricochets_remaining == 2, "Burr rank 1 plus Potency gives one more ricochet")
	_check(
		is_zero_approx(thorn.critical_chance_bonus)
		and is_equal_approx(
			thorn.critical_damage_bonus,
			adaptations.thistle_needlepoint_critical_damage_per_rank * amplification
		),
		"Needlepoint critical damage is its own bonus times its share of the Network"
	)
	_check(
		is_equal_approx(thorn.damage, adaptations.thistle_damage),
		"Root no longer adds blanket Thistle damage"
	)
	_check(
		is_equal_approx(
			adaptations._get_thistle_attack_interval(origin),
			adaptations.thistle_attack_interval / (1.0 + 0.15 * amplification)
		),
		"Dehiscence attack speed is its own bonus times the Network"
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


func _test_vine_outputs(
	prototype: RunRoot, amplification: float, network: float
) -> void:
	var combat := prototype.combat
	_check(
		is_equal_approx(combat._cane_reach_multiplier, 1.0 + 0.20 * amplification),
		"Elongation reach is its own bonus times the Network"
	)
	# Lignification plus Root's own Cane floor. The floor is not a Vine line: it is
	# what Root pays a run that has not yet found anything to amplify, and it lands on
	# the Cane whether or not Vine is owned. It shows up here because this build owns
	# both, and the two are checked together so neither can quietly absorb the other.
	# The floor reads the *whole* Network, not a line's share of it: it is not a line.
	var cane_floor := (
		(network - 1.0) * prototype.adaptation_director.root_cane_network_share
	)
	_check(
		is_equal_approx(
			combat._cane_damage_multiplier,
			1.0 + 0.25 * amplification + cane_floor
		),
		"Lignification damage is its own bonus times the Network, over Root's Cane floor"
	)
	_check(
		cane_floor > 0.0,
		"Root standing on Mature ground makes the Cane itself heavier"
	)
	_check(
		is_equal_approx(
			combat._cane_cooldown_multiplier,
			1.0 / (1.0 + 0.15 * amplification)
		),
		"Turgor cadence is its own bonus times the Network"
	)
	_check(
		is_equal_approx(combat._cane_apical_damage_bonus, 0.25 * amplification),
		"Apical Dominance is its own bonus times the Network"
	)


func _test_fruit_outputs(
	prototype: RunRoot,
	origin: Vector2,
	amplification: float
) -> void:
	var adaptations := prototype.adaptation_director
	var ripening := 1.0 + 0.25 * amplification
	var fruit = adaptations._spawn_fruit(origin, Vector2.RIGHT)
	_check(
		is_equal_approx(fruit.damage, adaptations.fruit_collision_damage * ripening),
		"Ripening collision damage is its own bonus times the Network"
	)
	_check(
		is_equal_approx(
			fruit.terminal_damage,
			adaptations.fruit_terminal_explosion_damage * ripening
		),
		"Ripening terminal damage is its own bonus times the Network"
	)
	_check(
		is_equal_approx(
			fruit.normal_roll_distance,
			adaptations.fruit_roll_distance_pixels * (1.0 + 0.20 * amplification)
		),
		"Momentum roll distance is its own bonus times the Network"
	)
	_check(
		is_equal_approx(fruit.germination_multiplier, 1.0 + 0.20 * amplification),
		"Germination area is its own bonus times the Network"
	)
	for candidate in adaptations._fruits:
		candidate.active = false
	adaptations._begin_normal_fruit_release()
	_check(
		adaptations.get_active_fruit_count() == 3,
		"Fruit Set rank 1 plus Potency releases base 1 plus 2 Fruit, whatever the rank"
	)

	# The count is the bug this probe exists for: five Potency ranks must still be
	# worth exactly one Fruit, so a release does not change size as ranks are bought.
	prototype.progression._upgrade_levels[Progression.UpgradeId.ROOT_POTENCY] = 1
	for candidate in adaptations._fruits:
		candidate.active = false
	adaptations._begin_normal_fruit_release()
	_check(
		adaptations.get_active_fruit_count() == 3,
		"one Potency rank releases the same count as five"
	)
	prototype.progression._upgrade_levels[Progression.UpgradeId.ROOT_POTENCY] = 5


func _test_jackpot_gates(prototype: RunRoot, origin: Vector2) -> void:
	var progression := prototype.progression
	var adaptations := prototype.adaptation_director
	var fruit_set := Progression.UpgradeId.FRUIT_SET
	progression._upgrade_levels[fruit_set] = 0
	progression.set_casino_path_active(Progression.PathId.FRUIT, true)
	_check(
		adaptations._root_count_step(fruit_set, origin) == 0,
		"Fruit jackpot does not make unowned Fruit Set eligible for Potency"
	)
	progression.set_casino_path_active(Progression.PathId.FRUIT, false)
	progression._upgrade_levels[fruit_set] = 1
	progression._upgrade_levels[Progression.UpgradeId.ROOT_POTENCY] = 0
	progression.set_casino_path_active(Progression.PathId.ROOT, true)
	# A Root jackpot runs the path, and it now lends Fruit and Vine exactly what it
	# already lends Spore, Bloom, Bramble and Pruning: the Network at its lent
	# strength, read through the one multiplier every consumer reads.
	var lent_network := prototype.root_director.get_network_multiplier_here(origin)
	var lent_share := (
		1.0
		+ (lent_network - 1.0) * adaptations.root_line_network_share
	)
	_check(
		is_equal_approx(adaptations._root_bonus_scale(fruit_set, origin), lent_share)
		and adaptations._root_bonus_scale(fruit_set, origin) > 1.0,
		"a Root jackpot lends Fruit the same share of the Network every other line reads"
	)
	progression.set_casino_path_active(Progression.PathId.ROOT, false)
	progression._upgrade_levels[Progression.UpgradeId.ROOT_POTENCY] = 5


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		push_error("FAIL: %s" % description)
