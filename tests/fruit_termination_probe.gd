extends SceneTree

## A Fruit must always reach its terminal burst. It stops rolling by having its speed
## fall to zero, but two of the three things that reduce speed are multiplications --
## an obstacle bounce keeps 55% and an enemy collision keeps as little as 15% -- and a
## multiplication never reaches zero. A Fruit parked just above the stop threshold is
## invisible as motion, never bursts, never frees its pool slot, and keeps damaging
## anything that walks into it. This probe drives Fruit into the states that produce
## that residue and asserts every one of them terminates.

const STEP := 1.0 / 60.0
const GENEROUS_FRAMES := 3600

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
	var progression := prototype.progression
	progression.reset_progression()
	progression.debug_select_paths(
		Progression.PathId.FRUIT,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	prototype.adaptation_director.reset_adaptations()
	prototype.combat.reset_combat()

	_test_zero_deceleration_terminates(prototype)
	_test_residual_speed_terminates(prototype)
	_test_repeated_bounce_terminates(prototype)
	_test_repeated_collision_terminates(prototype)
	_test_no_fruit_outlives_its_roll(prototype)

	prototype.queue_free()
	await process_frame
	if _failures == 0:
		print("FRUIT_TERMINATION_PROBE: PASS")
		quit(0)
	else:
		push_error("FRUIT_TERMINATION_PROBE: %d failure(s)" % _failures)
		quit(1)


func _clear_fruit(prototype: RunRoot) -> void:
	for fruit in prototype.adaptation_director._fruits:
		fruit.active = false
	for fruitseed in prototype.adaptation_director._fruitseeds:
		fruitseed.active = false


func _frames_until_inactive(prototype: RunRoot, fruit) -> int:
	var adaptations := prototype.adaptation_director
	for frame in range(GENEROUS_FRAMES):
		if not fruit.active:
			return frame
		adaptations._advance_fruit(fruit, STEP)
	return -1


func _test_zero_deceleration_terminates(prototype: RunRoot) -> void:
	## Deceleration is the only thing that can drive a Fruit's speed to exactly zero;
	## the obstacle bounce and the collision momentum loss are both multiplications,
	## and a multiplication never arrives at zero. So a Fruit that has lost its
	## deceleration rolls until the bounces have ground it down to an imperceptible
	## crawl and then sits there forever -- active, stationary, and still dealing
	## contact damage to anything that walks into it. That is the permanent trap.
	var adaptations := prototype.adaptation_director
	var origin := prototype.territory_field.tuning.arena_size * 0.5
	_clear_fruit(prototype)
	var fruit = adaptations._spawn_fruit(origin, Vector2.RIGHT)
	if fruit == null:
		_check(false, "a Fruit could be spawned for the stalled-deceleration case")
		return
	fruit.deceleration = 0.0
	var frames := _frames_until_inactive(prototype, fruit)
	_check(
		frames >= 0,
		"a Fruit that lost its deceleration still bursts (took %d frames)" % frames
	)


func _test_residual_speed_terminates(prototype: RunRoot) -> void:
	## The exact shape a multiplication leaves behind: a speed far below anything the
	## eye reads as motion, but strictly greater than zero.
	var adaptations := prototype.adaptation_director
	var origin := prototype.territory_field.tuning.arena_size * 0.5
	for residue in [1e-3, 1e-9, 1e-18, 1e-30]:
		_clear_fruit(prototype)
		var fruit = adaptations._spawn_fruit(origin, Vector2.RIGHT)
		if fruit == null:
			_check(false, "a Fruit could be spawned for the residue case")
			return
		fruit.speed = float(residue)
		fruit.velocity = fruit.last_direction * fruit.speed
		var frames := _frames_until_inactive(prototype, fruit)
		_check(
			frames >= 0,
			"a Fruit left at %.12f px/s still reaches its burst (took %d frames)" % [
				residue,
				frames,
			]
		)


func _test_repeated_bounce_terminates(prototype: RunRoot) -> void:
	## An obstacle bounce keeps 55% of the speed. A Fruit wedged so that it bounces
	## every frame is the natural way to grind the speed down to a residue.
	var adaptations := prototype.adaptation_director
	var origin := prototype.territory_field.tuning.arena_size * 0.5
	_clear_fruit(prototype)
	var fruit = adaptations._spawn_fruit(origin, Vector2.RIGHT)
	if fruit == null:
		_check(false, "a Fruit could be spawned for the bounce case")
		return
	for _bounce in range(200):
		if not fruit.active:
			break
		adaptations._resolve_fruit_obstacle_bounce(
			fruit,
			fruit.position,
			fruit.position + fruit.last_direction * 2.0
		)
	var frames := _frames_until_inactive(prototype, fruit)
	_check(
		frames >= 0,
		"a Fruit ground down by 200 bounces still reaches its burst (took %d frames)" % frames
	)


func _test_repeated_collision_terminates(prototype: RunRoot) -> void:
	## Enemy collisions take a share of the momentum, and that share is also a
	## multiplication. A Fruit bowling through a dense pack takes many of them.
	var adaptations := prototype.adaptation_director
	var origin := prototype.territory_field.tuning.arena_size * 0.5
	_clear_fruit(prototype)
	var fruit = adaptations._spawn_fruit(origin, Vector2.RIGHT)
	if fruit == null:
		_check(false, "a Fruit could be spawned for the collision case")
		return
	for _hit in range(400):
		fruit.speed *= 0.68
		fruit.velocity = fruit.last_direction * fruit.speed
	var frames := _frames_until_inactive(prototype, fruit)
	_check(
		frames >= 0,
		"a Fruit slowed by 400 collisions still reaches its burst (took %d frames)" % frames
	)


func _test_no_fruit_outlives_its_roll(prototype: RunRoot) -> void:
	## Whatever happens to it, a Fruit is a roll and then a burst. Nothing should be
	## able to leave one sitting on the field as a permanent contact hazard.
	var adaptations := prototype.adaptation_director
	var origin := prototype.territory_field.tuning.arena_size * 0.5
	_clear_fruit(prototype)
	var fruit = adaptations._spawn_fruit(origin, Vector2.RIGHT)
	if fruit == null:
		_check(false, "a Fruit could be spawned for the lifetime case")
		return
	fruit.speed = 1e-24
	fruit.velocity = Vector2.ZERO
	var frames := _frames_until_inactive(prototype, fruit)
	_check(
		frames >= 0 and frames <= GENEROUS_FRAMES,
		"a stationary Fruit does not become permanent scenery (took %d frames)" % frames
	)
	_check(not fruit.active, "the stopped Fruit released its pool slot")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		push_error("FAIL: %s" % description)
