extends SceneTree

## Does the cheap sector rejection ever change where the Cane aims?
##
## `get_densest_target_direction` decides a gameplay-visible thing -- which way the
## sweep goes -- through a four-stage tie-breaker on count, then summed distance,
## then summed angular error, then deviation from facing, at 0.0001 thresholds. The
## sweep was made cheaper by letting a dot product reject targets that are plainly
## outside a candidate's sector before `angle_to` is called on them. That is only
## legitimate if it rejects exactly what the angle test would have rejected, and a
## tie-breaker this fine can turn a hair's-width disagreement into a different
## chosen direction.
##
## So this does not reason about it. It builds randomized crowds, runs the shipping
## path and the reference path over the same field, and requires the answers to be
## identical -- not close, identical, because the two differ only in an early-out
## that is supposed to be a no-op.
##
## Layouts are chosen to put targets exactly where the argument is weakest: sitting
## on the sector edge, clustered so ties are common, and spread so the rejection
## fires constantly.
##
## Run: godot --headless --script tests/cane_targeting_reference_probe.gd

const CASES_PER_LAYOUT := 220
const SECTOR_DEGREES := [8.0, 24.0, 60.0, 90.0, 140.0, 200.0, 359.0]
const DENSITIES := [1, 2, 7, 25, 80, 160]

## How far the sorted mode's chosen direction may sit from the reference's before
## it counts as a failure rather than as arithmetic noise.
##
## The sorted mode is mathematically equal to the reference but not bit-identical,
## so on a layout where two candidates are separated by less than the tie-breaker's
## own 1e-4 thresholds it can settle the tie the other way. What must not happen is
## the two picking *substantially* different directions, which would mean the window
## or the sums are wrong rather than merely rounded differently. A tenth of a degree
## is far below anything a player could see and far above float noise.
const SORTED_ANGLE_TOLERANCE := 0.0018

var _checked := 0
var _mismatches: Array[String] = []
var _unstable := 0
var _sorted_differs := 0
var _sorted_worst_angle := 0.0
var _sorted_reported := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_error := change_scene_to_file("res://scenes/run/phase_b_prototype.tscn")
	if load_error != OK:
		push_error("Unable to load Phase B prototype: %s" % error_string(load_error))
		quit(1)
		return
	await process_frame
	await process_frame
	var prototype := current_scene as PhaseBPrototype
	if prototype == null:
		push_error("Phase B prototype scene did not become current")
		quit(1)
		return
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.combat.set_process(false)
	prototype.adaptation_director.set_process(false)
	prototype.overlay.set_process(false)

	var combat := prototype.combat
	if combat.enemy_pool_size < 200:
		combat.enemy_pool_size = 200
		combat._configure_pools()
	combat.maximum_active_enemies = 200

	# Both routing modes. With auto-targeting on, gathering runs a path query per
	# enemy and the reachable set can differ from the straight-line one, so the
	# comparison has to cover it rather than assume the sweep sees the same targets.
	for auto_targets in [false, true]:
		combat.set_cane_auto_targeting(auto_targets)
		await _run_layout(prototype, "scattered", auto_targets)
		await _run_layout(prototype, "clustered", auto_targets)
		await _run_layout(prototype, "sector_edge", auto_targets)
		await _run_layout(prototype, "collinear", auto_targets)
	combat.set_cane_auto_targeting(false)

	prototype.queue_free()
	await process_frame

	if _unstable > 0:
		print(
			"CANE_TARGETING_REFERENCE: %d cases skipped -- the reference path did not "
			% _unstable
			+ "agree with itself on an unchanged field, so they say nothing about the "
			+ "dot rejection."
		)
	print(
		(
			"CANE_TARGETING_REFERENCE: sorted mode differed from the reference on "
			+ "%d of %d cases (%.2f%%), worst separation %.9f rad (%.5f deg), "
			+ "tolerance %.9f rad"
		) % [
			_sorted_differs,
			_checked,
			100.0 * float(_sorted_differs) / float(maxi(1, _checked)),
			_sorted_worst_angle,
			rad_to_deg(_sorted_worst_angle),
			SORTED_ANGLE_TOLERANCE,
		]
	)
	if _mismatches.is_empty():
		print(
			(
				"CANE_TARGETING_REFERENCE: PASS (%d comparisons; dot-prune identical, "
				+ "sorted within tolerance)"
			) % _checked
		)
		quit(0)
		return
	for line in _mismatches:
		print(line)
	push_error(
		"CANE_TARGETING_REFERENCE: %d of %d comparisons disagree"
		% [_mismatches.size(), _checked]
	)
	quit(1)


func _run_layout(prototype: PhaseBPrototype, layout: String, auto_targets: bool) -> void:
	var combat := prototype.combat
	var random := RandomNumberGenerator.new()
	for case_index in range(CASES_PER_LAYOUT):
		# Seeded per case, so a failure names a case that can be replayed exactly.
		var seed_value := (
			hash(layout) * 1000003
			+ case_index * 31
			+ (7919 if auto_targets else 0)
		)
		random.seed = seed_value

		prototype.territory_field.reset_field()
		combat.reset_combat()

		var origin := Vector2(
			random.randf_range(200.0, 440.0),
			random.randf_range(200.0, 400.0)
		)
		prototype.player.global_position = prototype.territory_field.to_global(origin)

		var sector: float = SECTOR_DEGREES[random.randi() % SECTOR_DEGREES.size()]
		var density: int = DENSITIES[random.randi() % DENSITIES.size()]
		var reach := random.randf_range(40.0, 460.0)
		_place_enemies(combat, random, layout, origin, density, sector, reach)

		var facing := Vector2.from_angle(random.randf_range(-PI, PI))

		# The control. Two runs of the *same* path over an unchanged field must agree,
		# or the comparison below is measuring the search's own instability rather
		# than anything the dot rejection did.
		var control_a := combat.debug_densest_target_direction_reference(
			origin, reach, sector, facing
		)
		var control_b := combat.debug_densest_target_direction_reference(
			origin, reach, sector, facing
		)
		if control_a != control_b:
			_unstable += 1
			if _unstable <= 6:
				_mismatches.append(
					(
						"CANE_TARGETING_REFERENCE UNSTABLE (reference disagrees with "
						+ "itself) layout=%s auto=%s seed=%d sector=%.1f density=%d "
						+ "reach=%.1f a=%s b=%s"
					) % [
						layout, auto_targets, seed_value, sector, density, reach,
						control_a, control_b,
					]
				)
			await process_frame
			continue

		# Both fast modes against the same reference, because they carry different
		# guarantees. DOT_PRUNE only skips work whose outcome was already settled, so
		# it must match exactly. SORTED re-derives the angular error from sorted
		# scalars, so it is mathematically equal but not bit-identical, and what
		# matters is how far apart the chosen directions ever get.
		var pruned := combat.debug_densest_target_direction_mode(
			origin, reach, sector, facing,
			PhaseBCombatDirector.DensestTargetMode.DOT_PRUNE
		)
		var sorted_result := combat.debug_densest_target_direction_mode(
			origin, reach, sector, facing,
			PhaseBCombatDirector.DensestTargetMode.SORTED
		)
		var reference := combat.debug_densest_target_direction_reference(
			origin, reach, sector, facing
		)
		_checked += 1
		if pruned != reference:
			_mismatches.append(
				(
					"CANE_TARGETING_REFERENCE dot-prune mismatch layout=%s auto=%s "
					+ "seed=%d sector=%.1f density=%d reach=%.1f fast=%s reference=%s"
				) % [
					layout, auto_targets, seed_value, sector, density, reach,
					pruned, reference,
				]
			)
		if sorted_result != reference:
			var apart := absf(sorted_result.angle_to(reference))
			_sorted_differs += 1
			_sorted_worst_angle = maxf(_sorted_worst_angle, apart)
			if apart > SORTED_ANGLE_TOLERANCE and _sorted_reported < 8:
				_sorted_reported += 1
				_mismatches.append(
					(
						"CANE_TARGETING_REFERENCE sorted diverged beyond tolerance "
						+ "layout=%s auto=%s seed=%d sector=%.1f density=%d reach=%.1f "
						+ "sorted=%s reference=%s angle_apart=%.9f"
					) % [
						layout, auto_targets, seed_value, sector, density, reach,
						sorted_result, reference, apart,
					]
				)
		await process_frame


func _place_enemies(
	combat: PhaseBCombatDirector,
	random: RandomNumberGenerator,
	layout: String,
	origin: Vector2,
	density: int,
	sector_degrees: float,
	reach: float
) -> void:
	var half_angle := deg_to_rad(sector_degrees * 0.5)
	var base_angle := random.randf_range(-PI, PI)
	for index in range(density):
		var angle := 0.0
		var radius := 0.0
		match layout:
			"clustered":
				# Many enemies inside one narrow arc, so candidates tie on count and
				# the decision falls through to the later tie-break stages.
				angle = base_angle + random.randf_range(-0.05, 0.05)
				radius = random.randf_range(20.0, maxf(24.0, reach))
			"sector_edge":
				# Sitting on the boundary the dot product is asked to rule on. If the
				# cheap test can ever disagree with `angle_to`, it disagrees here.
				var edge := base_angle + (
					half_angle if index % 2 == 0 else -half_angle
				)
				angle = edge + random.randf_range(-1.0e-6, 1.0e-6)
				radius = random.randf_range(20.0, maxf(24.0, reach))
			"collinear":
				# Identical directions at different distances: count ties are forced,
				# so the distance-sum stage decides.
				angle = base_angle
				radius = 20.0 + float(index) * 9.0
			_:
				angle = random.randf_range(-PI, PI)
				radius = random.randf_range(10.0, maxf(24.0, reach * 1.4))
		var position := origin + Vector2.from_angle(angle) * radius
		combat.spawn_enemy(
			PhaseBCombatDirector.EnemyRole.GRAZER if index % 2 == 0
			else PhaseBCombatDirector.EnemyRole.RUSHER,
			position
		)
