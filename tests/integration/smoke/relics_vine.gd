## Vine relics: every one of them a stroke of the rope the Cane is already driving.
##
## The rule they share is continuity - a relic-driven sweep has to move the body that
## is out there rather than conjure a second one - so most of these check where the
## rope is as much as what it hit.
class_name SmokeRelicsVine
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot, relics: RelicDirector, lone_spot: Vector2) -> void:
	# -------------------------------------------------------------- Vine relics
	# Vine's pool is ignited by precision, and Apical now means real contact from
	# the outer portion of the simulated rope. These cases check the streaks and
	# the limiters; the rope's own physics has its own probe.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.VINE,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	var vine := prototype.adaptation_director
	vine.reset_adaptations()
	prototype.combat.reset_combat()
	var vine_spot := SmokeFixtures.find_owned_cell_position(prototype)
	prototype.player.global_position = prototype.territory_field.to_global(vine_spot)

	# The Cane resolves through the rope while Vine is held, and through its
	# authored sector otherwise. That switch is what the whole rework rests on.
	var vine_drives := prototype.combat.is_vine_driven()
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	var sector_drives := prototype.combat.is_vine_driven()
	prototype.progression.debug_select_paths(
		Progression.PathId.VINE,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	report.check(
		vine_drives and not sector_drives,
		"the Cane resolves through the simulated Vine only while Vine is held"
	)

	# Girdling: consecutive natural Apical hits on the same enemy mark it, a gap
	# breaks the streak, and the next Vine contact spends the mark.
	vine.reset_adaptations()
	prototype.progression._owned_relics[RelicCatalog.Id.GIRDLING] = 1
	var girdled_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HEAVY_GRAZER, vine_spot + Vector2(40.0, 0.0)
	)
	vine._natural_sweep_index = 1
	vine._note_vine_apical_hit(girdled_id, 30.0)
	# Two hits inside one sweep are one hit's worth of progress.
	vine._note_vine_apical_hit(girdled_id, 30.0)
	var girdle_after_one := int(vine._girdling[girdled_id][0])
	vine._natural_sweep_index = 2
	vine._note_vine_apical_hit(girdled_id, 30.0)
	var girdle_marked := float(vine._girdling[girdled_id][2]) > 0.0
	var girdle_health := prototype.combat.get_enemy_health(girdled_id)
	vine._try_consume_girdling(girdled_id, 30.0)
	var girdle_crushed := prototype.combat.get_enemy_health(girdled_id) < girdle_health
	var girdle_spent := not vine._girdling.has(girdled_id)
	# A broken streak starts over rather than carrying its progress.
	vine._girdling.clear()
	vine._girdling_cooldowns.clear()
	vine._natural_sweep_index = 10
	vine._note_vine_apical_hit(girdled_id, 30.0)
	vine._natural_sweep_index = 14
	vine._note_vine_apical_hit(girdled_id, 30.0)
	var girdle_streak_reset := int(vine._girdling[girdled_id][0]) == 1
	report.check(
		girdle_after_one == 1
		and girdle_marked
		and girdle_crushed
		and girdle_spent
		and girdle_streak_reset,
		"GIRDLING builds on consecutive Apical sweeps, breaks on a gap, and is spent once"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.GIRDLING] = 0

	# Runner: one sprout per natural sweep, capped, and it lashes a neighbour.
	vine.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.RUNNER] = 1
	var runner_victim := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER, vine_spot + Vector2(30.0, 0.0)
	)
	vine._runners.append([vine_spot, 0.0, 25.0])
	var runner_health := prototype.combat.get_enemy_health(runner_victim)
	vine._advance_vine_relics(1.0 / 60.0)
	report.check(
		vine._runners.is_empty()
		and prototype.combat.get_enemy_health(runner_victim) < runner_health,
		"RUNNER lashes a neighbour from the corpse and is spent by doing it"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.RUNNER] = 0

	# Whiplash: reaches past the tip, and only enemies the parent sweep missed.
	vine.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.WHIPLASH] = 1
	vine._current_sweep_reach = 60.0
	var beyond_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HEAVY_GRAZER, vine_spot + Vector2(90.0, 0.0)
	)
	var already_hit_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HEAVY_GRAZER, vine_spot + Vector2(100.0, 0.0)
	)
	vine._cane_sweep_hits.append(already_hit_id)
	var beyond_health := prototype.combat.get_enemy_health(beyond_id)
	var already_health := prototype.combat.get_enemy_health(already_hit_id)
	vine._try_whiplash(vine_spot, Vector2.RIGHT, 40.0)
	report.check(
		prototype.combat.get_enemy_health(beyond_id) < beyond_health
		and is_equal_approx(
			prototype.combat.get_enemy_health(already_hit_id), already_health
		),
		"WHIPLASH snaps past the tip and never re-hits what the parent sweep reached"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.WHIPLASH] = 0

	# Climber: requires a real bend in the rope and a hit past it. Without a wrap
	# it must do nothing at all, which is what stops it reaching through terrain.
	vine.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.CLIMBER] = 1
	var climber_victim := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HEAVY_GRAZER, vine_spot + Vector2(20.0, 0.0)
	)
	var climber_health := prototype.combat.get_enemy_health(climber_victim)
	vine._sweep_bend_index = -1
	vine._sweep_hit_past_bend = false
	vine._try_climber(40.0)
	var climber_without_bend := is_equal_approx(
		prototype.combat.get_enemy_health(climber_victim), climber_health
	)
	# A bend with nothing hit past it is still not a Climber.
	vine._sweep_bend_index = 2
	vine._sweep_hit_past_bend = false
	vine._try_climber(40.0)
	var climber_without_hit := is_equal_approx(
		prototype.combat.get_enemy_health(climber_victim), climber_health
	)
	report.check(
		climber_without_bend and climber_without_hit,
		"CLIMBER cinches only a Vine that actually wrapped and struck past the bend"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.CLIMBER] = 0

	# Liana: three consecutive successful Apical sweeps unleash the cascade, a
	# failed sweep resets the streak, and the cascade is exactly four sweeps.
	vine.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.LIANA] = 1
	for _liana_sweep in range(vine.liana_required_sweeps - 1):
		vine._current_sweep_apical_hit = true
		vine._on_cane_sweep_finished(vine_spot, Vector2.RIGHT, true, 92.0, 1, false)
	var liana_building := vine._liana_progress
	# A sweep with no Apical hit breaks it.
	vine._current_sweep_apical_hit = false
	vine._on_cane_sweep_finished(vine_spot, Vector2.RIGHT, true, 92.0, 0, false)
	var liana_reset := vine._liana_progress
	for _liana_again in range(vine.liana_required_sweeps):
		vine._current_sweep_apical_hit = true
		vine._on_cane_sweep_finished(vine_spot, Vector2.RIGHT, true, 92.0, 1, false)
	var liana_cascade := vine._liana_remaining
	var liana_cooling := vine._liana_cooldown > 0.0
	report.check(
		liana_building == vine.liana_required_sweeps - 1
		and liana_reset == 0
		and liana_cascade == vine.liana_bonus_sweeps
		and liana_cooling,
		"LIANA needs three consecutive Apical sweeps, resets on a miss, and casts four"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.LIANA] = 0

	# Continuity: every relic-driven stroke has to drive the rope that is already
	# there. A relic that rebuilt the Vine would look like it was being respawned
	# per attack, which is the whole thing the physics rework exists to stop.
	var whip: VineWhip = prototype.combat.vine_whip
	prototype.player.global_position = prototype.territory_field.to_global(vine_spot)
	prototype.combat.simulate_step(1.0 / 60.0)
	var rope_is_driving := prototype.combat.is_vine_driven() and whip.is_built()

	# Recurve reverses a rope that is still carrying momentum: the next stroke
	# arrives sooner and starts from exactly where the last one left the body.
	prototype.progression._owned_relics[RelicCatalog.Id.RECURVE] = 1
	vine._recurve_armed = false
	vine._on_cane_enemy_hit(-1, vine_spot, 0.9, true, 10.0, false, false)
	var recurve_armed := vine._recurve_armed
	var before_recurve := whip.points.duplicate()
	var sweep_before := whip.get_sweep_id()
	prototype.combat.perform_bonus_cane_sweep(Vector2.RIGHT, false)
	var recurve_continuous := true
	for point_index in range(before_recurve.size()):
		if not before_recurve[point_index].is_equal_approx(whip.points[point_index]):
			recurve_continuous = false
			break
	report.check(
		rope_is_driving
		and recurve_armed
		and whip.get_sweep_id() == sweep_before + 1
		and recurve_continuous
		and whip.get_point_count() == before_recurve.size(),
		"RECURVE reverses the continuously simulated Vine without resetting its momentum"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.RECURVE] = 0

	# Twining's repeat is a stroke of the same body, not a second Vine.
	prototype.progression._owned_relics[RelicCatalog.Id.TWINING] = 1
	for _twine_settle in range(10):
		prototype.combat.simulate_step(1.0 / 60.0)
	var before_twining := whip.points.duplicate()
	var twining_sweep_before := whip.get_sweep_id()
	prototype.combat.perform_bonus_cane_sweep(
		Vector2.RIGHT, true, vine.twining_damage_share
	)
	var twining_continuous := true
	for point_index in range(before_twining.size()):
		if not before_twining[point_index].is_equal_approx(whip.points[point_index]):
			twining_continuous = false
			break
	report.check(
		whip.get_sweep_id() == twining_sweep_before + 1
		and twining_continuous
		and whip.get_point_count() == before_twining.size(),
		"TWINING repeats on the persistent Vine state rather than spawning a second one"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.TWINING] = 0

	# Liana's cascade is four strokes of one rope, alternating, with the body never
	# rebuilt between them.
	prototype.progression._owned_relics[RelicCatalog.Id.LIANA] = 1
	vine.reset_adaptations()
	for _liana_settle in range(10):
		prototype.combat.simulate_step(1.0 / 60.0)
	var liana_points_before := whip.get_point_count()
	var liana_sweep_before := whip.get_sweep_id()
	vine._liana_remaining = vine.liana_bonus_sweeps
	vine._liana_step = 0.0
	vine._liana_facing = Vector2.RIGHT
	var liana_rebuilt := false
	for _liana_tick in range(int(vine.liana_interval_seconds * 60.0) * 6 + 30):
		vine._advance_vine_relics(1.0 / 60.0)
		if whip.get_point_count() != liana_points_before:
			liana_rebuilt = true
	report.check(
		whip.get_sweep_id() - liana_sweep_before == vine.liana_bonus_sweeps
		and not liana_rebuilt
		and vine._liana_remaining == 0,
		"LIANA drives exactly four alternating strokes through one continuous Vine body"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.LIANA] = 0

	# Climber reads a real wrap, not a sharp curve. A rope whipping through open
	# ground bends hard under its own momentum and must never read as wrapped.
	prototype.progression._owned_relics[RelicCatalog.Id.CLIMBER] = 1
	var open_wrap := whip.is_wrapped()
	var curved_hard := whip.get_bend_count() > 0
	vine._sweep_bend_index = whip.get_wrap_index()
	var climber_armed_in_the_open := vine._sweep_bend_index >= 0
	report.check(
		not open_wrap and not climber_armed_in_the_open,
		"CLIMBER reads an actual wrap rather than a rope merely bent by its own swing"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.CLIMBER] = 0

	vine.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()

	# Snare Vine spreads a capped share of a root to the nearest few enemies.
	prototype.combat.reset_combat()
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.SNARE_VINE] = 1
	relics.apply_relics()
	var snare_ids := PackedInt32Array()
	for snare_index in range(4):
		snare_ids.append(prototype.combat.spawn_enemy(
			EnemyKinds.Role.HUNTER,
			lone_spot + Vector2.from_angle(float(snare_index) * 1.2) * 30.0
		))
	prototype.combat.enemy_ensnared.emit(lone_spot)
	var snared := 0
	for snare_id in snare_ids:
		if prototype.combat.get_enemy_entanglement(snare_id) > 0.0:
			snared += 1
	report.check(
		snared > 0 and snared <= relics.snare_vine_targets,
		"SNARE VINE spreads Entanglement to a capped number of neighbours"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.SNARE_VINE] = 0
	prototype.combat.reset_combat()

	# Gleaning Hook spares the ground the ring would have cut, capped per hold. It
	# banked Charge until the Pruning rework made the launch a minority of the path's
	# damage; buying leaves with it instead measured byte-identical to holding no relic,
	# because a walking ring runs at capacity and leaves are not what it is short of.
	# Ground is, since the scarcity fix, and ground is what its own sentence saves.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.PRUNING,
		Progression.PathId.SPORE
	)
	prototype.progression._owned_relics[RelicCatalog.Id.GLEANING_HOOK] = 1
	prototype._apply_progression_modifiers()
	relics.apply_relics()
	var gleaning := prototype.pruning_director
	gleaning.reset_director()
	gleaning._charge = 0.0
	var payouts := int(
		ceil(gleaning.gleaning_hook_maximum_cells / gleaning.gleaning_hook_cells)
	) + 2
	for _gleaning_kill in range(gleaning.gleaning_hook_kills * payouts):
		gleaning.notify_ring_kill(false)
	report.check(
		gleaning.get_gleaning_banked_cells() > 0.0
		and gleaning.get_gleaning_banked_cells()
		<= gleaning.gleaning_hook_maximum_cells + 0.0001
		and is_equal_approx(
			gleaning.get_upkeep_cells_spared(), gleaning.get_gleaning_banked_cells()
		),
		"GLEANING HOOK spares the ground the ring would have cut, and stops at its cap"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.GLEANING_HOOK] = 0
