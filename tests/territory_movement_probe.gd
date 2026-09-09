extends SceneTree

## Phase 1 of the Territory Consequence rework asks whether established ground is
## worth standing on. The claim is narrow and testable: movement reads a small patch
## rather than one cell, only owned Green pays, what it pays scales with age, and the
## bonus does not strobe when the frontier breathes. This exercises the composition
## too, because the whole reason movement was refactored is that relic and territory
## speed must not overwrite one another.

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var tuning := load("res://data/territory/phase_a_tuning.tres") as TerritoryPrototypeTuning
	_check(tuning != null, "prototype tuning resource loads")
	if tuning == null:
		quit(1)
		return

	var field := TerritoryField.new()
	field.tuning = tuning
	root.add_child(field)
	field.reset_field()

	var player := Player.new()
	player.territory_field = field
	root.add_child(player)
	player.reset_player()

	# Ground with no owner pays nothing. Losing territory takes an advantage away; it
	# never leaves the run slower than its own baseline.
	var neutral_point := Vector2(tuning.arena_size.x * 0.16, tuning.arena_size.y * 0.12)
	_place(player, field, neutral_point)
	player._update_territory_speed()
	_check(
		is_equal_approx(player.get_speed_multiplier(), 1.0),
		"neutral ground moves at base speed (%.4f)" % player.get_speed_multiplier()
	)

	var hostile_point := Vector2(tuning.arena_size.x * 0.82, tuning.arena_size.y * 0.52)
	_check(
		field.get_control_at_local(hostile_point) < -tuning.ownership_threshold,
		"the hostile sample point is genuinely Rot"
	)
	_place(player, field, hostile_point)
	player._update_territory_speed()
	_check(
		is_equal_approx(player.get_speed_multiplier(), 1.0),
		"Rot moves at base speed, with no slow applied (%.4f)"
			% player.get_speed_multiplier()
	)

	# The authored foothold opens fully established, so it is the run's Mature Green.
	var home_point := Vector2(
		tuning.starting_plant_center.x * tuning.arena_size.x,
		tuning.starting_plant_center.y * tuning.arena_size.y
	)
	_place(player, field, home_point)
	player._update_territory_speed()
	var mature_multiplier := player.get_speed_multiplier()
	_check(
		is_equal_approx(mature_multiplier, 1.0 + player.mature_green_speed_bonus),
		"fully mature Green reaches the configured maximum (%.4f)" % mature_multiplier
	)

	# Fresh Green is owned but unestablished, so it is worth approximately nothing.
	field.queue_seed_growth(neutral_point)
	_step(field, 20)
	_place(player, field, neutral_point)
	player._update_territory_speed()
	var fresh_multiplier := player.get_speed_multiplier()
	_check(
		field.is_owned_at_local(neutral_point)
		and fresh_multiplier > 1.0
		and fresh_multiplier < 1.0 + player.mature_green_speed_bonus * 0.25,
		"freshly claimed Green is owned but pays almost nothing (%.4f)" % fresh_multiplier
	)

	# Age is what the bonus pays for, so holding the same ground must raise it and
	# never lower it.
	var previous := fresh_multiplier
	var monotonic := true
	for _hold in range(8):
		_step(field, 60)
		player._update_territory_speed()
		var current := player.get_speed_multiplier()
		monotonic = monotonic and current >= previous - 0.0001
		previous = current
	_check(
		monotonic and previous > fresh_multiplier,
		"holding ground raises the bonus monotonically (%.4f -> %.4f)"
			% [fresh_multiplier, previous]
	)

	# Multiple samples, not one nearest cell. Stated precisely: somewhere on the board
	# the patch must disagree with what the cell underfoot alone would have said. The
	# hysteresis is cleared before each read so this measures sampling and nothing
	# else, and the sweep also proves the sample radius still spans the lattice - a
	# radius under one cell puts every offset back in the middle cell and quietly
	# degrades into the single-cell read.
	var disagreements := 0
	var comparisons := 0
	for sample_y in range(6, 58, 3):
		for sample_x in range(6, 106, 3):
			var probe := field.cell_to_local(Vector2(sample_x, sample_y))
			if not field.is_claimable_at_local(probe):
				continue
			comparisons += 1
			player._territory_bonus_active = false
			_place(player, field, probe)
			player._update_territory_speed()
			var patch_multiplier := player.get_speed_multiplier()
			var cell_multiplier := 1.0
			if field.is_owned_at_local(probe):
				cell_multiplier = 1.0 + player.mature_green_speed_bonus * (
					field.get_maturity_at_local(probe)
				)
			if absf(patch_multiplier - cell_multiplier) > 0.0001:
				disagreements += 1
	_check(
		comparisons > 100 and disagreements > 0,
		"movement samples a patch rather than the single cell underfoot (%d of %d differ)"
			% [disagreements, comparisons]
	)

	# Hysteresis: the bonus must not toggle on a control average parked between the
	# grant and release thresholds.
	_place(player, field, home_point)
	player._update_territory_speed()
	_check(
		player.get_speed_multiplier() > 1.0,
		"the bonus is active on home ground before the hysteresis check"
	)
	var toggles := 0
	var was_active := player.get_speed_multiplier() > 1.0
	for _flicker in range(40):
		field.queue_erosion(home_point, 0.35, 1.0)
		field.step_simulation()
		player._update_territory_speed()
		var now_active := player.get_speed_multiplier() > 1.0
		if now_active != was_active:
			toggles += 1
			was_active = now_active
	_check(
		toggles <= 1,
		"an eroding frontier does not strobe the bonus (%d transitions)" % toggles
	)

	# Composition: the two owners must not overwrite one another. The frontier above
	# was deliberately eroded, so the field is reset first and home ground is mature
	# again; measuring composition on ground this probe just destroyed would compare
	# two base-speed readings and pass for the wrong reason.
	field.reset_field()
	player.set_relic_speed_multiplier(1.5)
	_place(player, field, home_point)
	player._update_territory_speed()
	var composed := player.get_speed_multiplier()
	_place(player, field, hostile_point)
	player._update_territory_speed()
	var relic_only := player.get_speed_multiplier()
	_check(
		is_equal_approx(relic_only, 1.5)
		and composed > relic_only,
		"territory and relic speed compose instead of overwriting (%.4f, %.4f)"
			% [composed, relic_only]
	)
	player.set_relic_speed_multiplier(1.0)

	if _failures > 0:
		push_error("TERRITORY_MOVEMENT: %d failure(s)" % _failures)
		quit(1)
		return
	print("TERRITORY_MOVEMENT: PASS")
	quit(0)


func _place(player: Player, field: TerritoryField, local_position: Vector2) -> void:
	player.global_position = field.to_global(local_position)


func _step(field: TerritoryField, count: int) -> void:
	for _index in range(count):
		field.step_simulation()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures += 1
	push_error("FAIL: %s" % description)
