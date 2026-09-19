extends SceneTree

## The Hive Queen: when she arrives, what she does, and what the run calls her.
##
## She is the run's second boss and the first enemy whose threat is not her own body.
## The Burrower comes to the player and erases ground on the way; she settles out of
## reach and grows Colony Cores, so the fight is about the board she makes rather than
## about her. Three separate things have to hold and none of them implies another: her
## schedule, her brood, and her boss-ness - the last because a dozen rules elsewhere
## mean "a boss" and every one of them used to be written as "== BOSS".
##
## Run: godot --headless --path . --script tests/integration/hive_queen_probe.gd

const RUN_SCENE := "res://scenes/run/run.tscn"

var _failures := 0
## Signal counts are script members, not locals: a GDScript lambda captures a local by
## value, so `arrived = true` inside one sets a copy the check never reads.
var _arrived := 0
var _queen_defeated := 0
var _boss_defeated := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _drive()
	if _failures == 0:
		print("HIVE_QUEEN: PASS")
		quit(0)
	else:
		push_error("HIVE_QUEEN: %d failure(s)" % _failures)
		quit(1)


func _drive() -> void:
	var run := await _load_run()
	if run == null:
		return
	run.set_process(false)
	run.player.input_enabled = false
	_check(run.combat.hive_queen_profile != null, "the roster carries a Hive Queen profile")
	if run.combat.hive_queen_profile == null:
		return

	_check_schedule(run)
	_check_arrival(run)
	_check_is_a_boss(run)
	_check_brood(run)
	_check_keeps_her_distance(run)
	_check_death(run)
	_check_milestone_survives_a_save(run)


func _check_schedule(run: RunRoot) -> void:
	## Both modes, because the two schedules are authored in different places and only
	## one of them is a wave table.
	var waves := run.wave_director
	waves.configure_mode(RunMode.Id.QUICK)
	waves.reset_director()
	_check(
		waves.hive_queen_time_seconds > waves.boss_time_seconds
		and waves.hive_queen_time_seconds < waves.final_invasion_time_seconds,
		"Quick puts her between the Burrower and the final invasion (%.0fs in %.0f..%.0f)"
			% [
				waves.hive_queen_time_seconds,
				waves.boss_time_seconds,
				waves.final_invasion_time_seconds,
			]
	)

	waves.configure_mode(RunMode.Id.CAMPAIGN)
	waves.reset_director()
	var scheduling_waves := PackedInt32Array()
	for wave_number in range(1, CampaignWaves.WAVE_COUNT + 1):
		var spec := waves.get_wave_spec(wave_number)
		if spec != null and spec.hive_queen_spawn_second >= 0.0:
			scheduling_waves.append(wave_number)
	_check(
		scheduling_waves == PackedInt32Array([CampaignWaves.HIVE_QUEEN_WAVE]),
		"exactly one Campaign wave calls her, and it is wave %d (%s)"
			% [CampaignWaves.HIVE_QUEEN_WAVE, str(scheduling_waves)]
	)
	var queen_wave := waves.get_wave_spec(CampaignWaves.HIVE_QUEEN_WAVE)
	_check(
		queen_wave != null and not queen_wave.grants_wave_relic,
		"her wave grants no relic of its own, so her reward arrives on its own"
	)
	_check(
		is_equal_approx(
			waves.hive_queen_time_seconds,
			float(CampaignWaves.HIVE_QUEEN_WAVE - 1) * CampaignWaves.WAVE_DURATION_SECONDS
			+ CampaignWaves.HIVE_QUEEN_SPAWN_SECOND
		),
		"and the Campaign clock agrees with the Campaign wave table (%.1fs)"
			% [waves.hive_queen_time_seconds]
	)
	# Back to the mode the rest of this probe drives.
	waves.configure_mode(RunMode.Id.QUICK)
	waves.reset_director()


func _check_arrival(run: RunRoot) -> void:
	## Driven on the real clock rather than by spawning her directly, because what is
	## under test is the schedule firing once - not that a spawn works.
	run.reset_run()
	run.set_process(false)
	run.player.input_enabled = false
	run.wave_director.hive_queen_arrived.connect(func() -> void: _arrived += 1)
	var waves := run.wave_director
	run.debug_advance_time(waves.hive_queen_time_seconds - 5.0)
	_check(
		_queen_count(run) == 0 and _arrived == 0,
		"she is not on the board before her minute"
	)
	# Her minute is a wave boundary, so the opening break holds her exactly as it holds
	# the Burrower. A milestone that ignored the break would be walking into a wave that
	# has not started yet.
	run.debug_advance_time(5.0)
	_check(
		_queen_count(run) == 0 and run.is_wave_grace_period_active(),
		"and waits through the wave's opening break rather than cutting it short"
	)
	run.debug_advance_time(waves.wave_grace_period_seconds)
	_check(
		_queen_count(run) == 1 and _arrived == 1,
		"she arrives when the break ends, and announces it once (%d on the board, %d arrivals)"
			% [_queen_count(run), _arrived]
	)
	run.debug_advance_time(120.0)
	_check(
		_queen_count(run) == 1 and _arrived == 1,
		"and the schedule never hands out a second one"
	)


func _check_is_a_boss(run: RunRoot) -> void:
	## Every rule that reduces a pulse, raises an overkill cap or refuses a spawn
	## redirect means "a boss" rather than "the Burrower". Asked through the predicate
	## those rules now share, and through two of the rules themselves.
	_check(
		EnemyKinds.is_boss(EnemyKinds.Role.HIVE_QUEEN)
		and EnemyKinds.is_boss(EnemyKinds.Role.BOSS)
		and not EnemyKinds.is_boss(EnemyKinds.Role.COLONIZER),
		"the boss predicate covers both bosses and nothing else"
	)
	_check(run.combat.has_active_boss(), "a live Hive Queen answers has_active_boss")
	var queen_id := _queen_id(run)
	_check(
		queen_id != -1 and run.combat.is_enemy_resistant(queen_id),
		"and resists the crowd control meant for the horde"
	)


func _check_brood(run: RunRoot) -> void:
	## The fight itself. She is allowed a Colonizer's whole brood, and the point of the
	## exception is that being a boss does not shrink it: the reserved-core rule exists
	## so a milestone can still *enter* a crowded arena, and she has already entered.
	run.combat.reset_combat()
	run.territory_field.reset_field()
	var arena := run.territory_field.tuning.arena_size
	run.player.global_position = run.territory_field.to_global(Vector2(60.0, 60.0))
	var queen_id := run.combat.spawn_enemy(EnemyKinds.Role.HIVE_QUEEN, arena * 0.55)
	_check(queen_id != -1, "a Hive Queen can be placed for the brood checks")
	if queen_id == -1:
		return
	var profile := run.combat.hive_queen_profile
	_check(
		profile.maximum_active_summons > run.combat.milestone_reserved_colony_cores,
		"her brood is larger than the Cores reserved around a milestone (%d against %d)"
			% [profile.maximum_active_summons, run.combat.milestone_reserved_colony_cores]
	)
	_simulate(run, profile.first_territory_action_delay_seconds + 0.5)
	_check(_core_count(run) >= 1, "she plants a Colony Core without moving to do it")
	_simulate(run, profile.territory_action_interval_seconds * 10.0)
	_check(
		_core_count(run) == profile.maximum_active_summons,
		"she fills her authored brood and stops there (%d of %d)"
			% [_core_count(run), profile.maximum_active_summons]
	)
	var queen_position := run.combat.get_enemy_position(queen_id)
	var closest := INF
	for enemy_id in run.combat.get_active_enemy_ids():
		if run.combat.get_enemy_role(enemy_id) != EnemyKinds.Role.COLONY_CORE:
			continue
		closest = minf(
			closest, run.combat.get_enemy_position(enemy_id).distance_to(queen_position)
		)
	_check(
		closest >= profile.summon_spacing_pixels,
		"no Core is planted inside her own spacing (%.0fpx of %.0f)"
			% [closest, profile.summon_spacing_pixels]
	)
	# Cutting one back has to be worth doing and must not be permanent: the answer to a
	# Queen is to keep the brood down while you reach her.
	var cleared := -1
	for enemy_id in run.combat.get_active_enemy_ids():
		if run.combat.get_enemy_role(enemy_id) == EnemyKinds.Role.COLONY_CORE:
			cleared = enemy_id
			break
	run.combat.debug_damage_enemy(cleared, 100000.0)
	_check(
		_core_count(run) == profile.maximum_active_summons - 1,
		"killing a Core takes it off the board"
	)
	_simulate(run, profile.territory_action_interval_seconds * 3.0)
	_check(
		_core_count(run) == profile.maximum_active_summons,
		"and she grows it back, so the brood is something to keep cutting rather than a one-off"
	)


func _check_keeps_her_distance(run: RunRoot) -> void:
	## The whole reason she reads differently from the Burrower on sight. A boss that
	## closed to contact would be the Burrower in another palette.
	var queen_id := _queen_id(run)
	if queen_id == -1:
		_check(false, "a Hive Queen is on the board for the distance check")
		return
	var queen_position := run.combat.get_enemy_position(queen_id)
	# Standing on top of her is the case that would expose a chaser.
	run.player.global_position = run.territory_field.to_global(
		queen_position + Vector2(30.0, 0.0)
	)
	_simulate(run, 4.0)
	var separation := run.combat.get_enemy_position(queen_id).distance_to(
		run.player.get_arena_position()
	)
	_check(
		separation > 30.0,
		"she backs away from a player standing on her rather than trading contact (%.0fpx)"
			% [separation]
	)


func _check_death(run: RunRoot) -> void:
	run.combat.hive_queen_defeated.connect(func() -> void: _queen_defeated += 1)
	run.combat.boss_defeated.connect(func() -> void: _boss_defeated += 1)
	var queen_id := _queen_id(run)
	var cores_before := _core_count(run)
	run.combat.debug_damage_enemy(queen_id, 1000000.0)
	_check(
		_queen_defeated == 1 and _boss_defeated == 0,
		"her death is her own event rather than the Burrower's (%d queen, %d burrower)"
			% [_queen_defeated, _boss_defeated]
	)
	_check(
		cores_before > 0 and _core_count(run) == cores_before,
		"and her Cores outlive her, so the ground she took still has to be taken back"
	)


func _check_milestone_survives_a_save(run: RunRoot) -> void:
	## A run saved after she has been and gone must not owe her again. The flag is one
	## line of the wave director's state, and what it prevents is a second Queen on a
	## continued run.
	var waves := run.wave_director
	waves.hive_queen_spawned = true
	var state := waves.capture_state()
	waves.reset_director()
	_check(
		not waves.hive_queen_spawned,
		"resetting the director owes the Queen again, so the restore has something to prove"
	)
	waves.apply_state(state)
	_check(
		waves.hive_queen_spawned,
		"a resumed run remembers that the Hive Queen has already been"
	)


func _simulate(run: RunRoot, seconds: float) -> void:
	# Stepped rather than leapt: her action cadence and the core placement search are
	# both per-step, and one large step would collapse the schedule being measured.
	var step := 0.25
	var remaining := seconds
	while remaining > 0.0:
		run.combat.simulate_step(minf(step, remaining))
		remaining -= step


func _queen_count(run: RunRoot) -> int:
	return run.combat.get_active_enemy_count_by_role(EnemyKinds.Role.HIVE_QUEEN)


func _core_count(run: RunRoot) -> int:
	return run.combat.get_active_enemy_count_by_role(EnemyKinds.Role.COLONY_CORE)


func _queen_id(run: RunRoot) -> int:
	for enemy_id in run.combat.get_active_enemy_ids():
		if run.combat.get_enemy_role(enemy_id) == EnemyKinds.Role.HIVE_QUEEN:
			return enemy_id
	return -1


func _load_run() -> RunRoot:
	if change_scene_to_file(RUN_SCENE) != OK:
		_check(false, "the run scene loads")
		return null
	await process_frame
	await process_frame
	var run := current_scene as RunRoot
	if run == null:
		_check(false, "the run scene becomes a RunRoot")
		return null
	return run


func _check(passed: bool, description: String) -> void:
	if passed:
		print("PASS: %s" % description)
		return
	_failures += 1
	push_error("FAIL: %s" % description)
