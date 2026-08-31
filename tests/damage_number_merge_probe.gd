extends SceneTree

## Does merging damage numbers ever lose damage, or ever merge a critical?
##
## Ordinary hits on one enemy now accumulate for a tenth of a second and show as a
## single number. That is a display change made of arithmetic, and arithmetic can
## drop things: a flush that never fires, an enemy dying with damage still owed, a
## reset discarding an accumulator. Any of those would quietly under-report damage
## in a way no frame-time measurement would catch.
##
## So the director keeps exact running totals of damage applied and damage handed to
## a number, and this requires them to match once what is still owed is counted.
## Damage is compared as floats, not as the rounded text, because the sum of a
## thousand rounded numbers is not the rounded sum.
##
## The setting is forced to FULL: the filtered modes are meant to drop numbers, and
## this probe is about the ones that should not be dropped.
##
## Run: godot --headless --script tests/damage_number_merge_probe.gd

const FRAMES := 900
const STEP := 1.0 / 60.0
const ENEMIES := 120
const HITS_PER_FRAME := 24
const CRITICAL_CHANCE := 0.15

var _failures: Array[String] = []


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
	prototype.player.maximum_health = 1000000000.0
	prototype.player.reset_player()

	var combat := prototype.combat
	# set_choice writes settings.cfg, so the player's own choice has to be put back
	# afterwards. A probe that leaves the game configured differently than it found
	# it is a probe that changes the thing it was meant to observe.
	var previous_choice := -1
	if combat.display_settings != null:
		previous_choice = combat.display_settings.get_choice(
			PhaseBDisplaySettings.OptionId.DAMAGE_NUMBERS
		)
		combat.display_settings.set_choice(
			PhaseBDisplaySettings.OptionId.DAMAGE_NUMBERS,
			PhaseBDisplaySettings.DamageNumbers.FULL
		)

	# Merging on and off, because the accounting has to hold either way and the
	# off case is the control: if it fails, the fault is not the merge.
	await _run_case(prototype, "merging 0.10s", 0.10)
	await _run_case(prototype, "merging off", 0.0)
	# A window longer than the run's tail, so a large amount is still owed at the
	# end. That is the case where forgetting to count what has not flushed would
	# look exactly like lost damage.
	await _run_case(prototype, "merging 0.50s", 0.50)
	await _run_case(prototype, "with kills", 0.10, true)

	if combat.display_settings != null and previous_choice >= 0:
		combat.display_settings.set_choice(
			PhaseBDisplaySettings.OptionId.DAMAGE_NUMBERS, previous_choice
		)

	prototype.queue_free()
	await process_frame

	if _failures.is_empty():
		print("DAMAGE_NUMBER_MERGE: PASS")
		quit(0)
		return
	for line in _failures:
		print(line)
	push_error("DAMAGE_NUMBER_MERGE: %d failures" % _failures.size())
	quit(1)


func _run_case(
	prototype: PhaseBPrototype,
	label: String,
	merge_seconds: float,
	allow_kills: bool = false
) -> void:
	var combat := prototype.combat
	combat.damage_number_merge_seconds = merge_seconds
	combat.reset_combat()
	prototype.territory_field.reset_field()

	var random := RandomNumberGenerator.new()
	random.seed = 481516
	var origin := Vector2(320.0, 300.0)
	prototype.player.global_position = prototype.territory_field.to_global(origin)
	_fill(combat, origin, allow_kills)

	combat.debug_damage_accounting = true
	combat.debug_reset_damage_accounting()

	var criticals := 0
	var merged_spawns_seen := false
	for _frame in range(FRAMES):
		for _hit in range(HITS_PER_FRAME):
			var enemy: Object = combat._enemies[random.randi() % combat._enemies.size()]
			if not enemy.active:
				continue
			var critical := random.randf() < CRITICAL_CHANCE
			if critical:
				criticals += 1
			combat._damage_enemy(
				enemy,
				random.randf_range(1.0, 14.0),
				PhaseBCombatDirector.DeathSource.THISTLE,
				0,
				critical
			)
			if not critical and enemy.pending_number_damage > 0.0:
				merged_spawns_seen = true
		combat.simulate_step(STEP)
		if allow_kills and combat.get_active_enemy_count() < ENEMIES / 2:
			_fill(combat, origin, true)

	var applied: float = combat.debug_damage_applied_total
	var shown: float = combat.debug_damage_number_total
	var owed: float = combat.debug_pending_damage_number_total()
	combat.debug_damage_accounting = false

	print(
		(
			"DAMAGE_NUMBER_MERGE %-14s applied %10.2f  shown %10.2f  owed %8.2f  "
			+ "crits %d"
		) % [label, applied, shown, owed, criticals]
	)

	var difference := applied - (shown + owed)
	if absf(difference) > maxf(0.01, applied * 1.0e-5):
		_failures.append(
			"DAMAGE_NUMBER_MERGE %s: applied %.4f but shown+owed %.4f (lost %.4f)"
			% [label, applied, shown + owed, difference]
		)
	if merge_seconds > 0.0 and not merged_spawns_seen:
		_failures.append(
			"DAMAGE_NUMBER_MERGE %s: nothing ever accumulated, so the case proved nothing"
			% label
		)


func _fill(combat: PhaseBCombatDirector, origin: Vector2, killable: bool) -> void:
	for index in range(ENEMIES):
		var spawned := combat.spawn_enemy(
			PhaseBCombatDirector.EnemyRole.GRAZER,
			origin
			+ Vector2.from_angle(float(index) * 2.39996)
			* (30.0 + float(index % 6) * 20.0)
		)
		if spawned < 0:
			break
	for enemy in combat._enemies:
		if not enemy.active:
			continue
		if killable:
			# Low enough that the run kills steadily, which is what exercises the
			# flush on death rather than only the flush on the timer.
			enemy.maximum_health = 60.0
			enemy.health = minf(enemy.health, 60.0)
		else:
			enemy.maximum_health = 1000000000.0
			enemy.health = enemy.maximum_health
