extends SceneTree

## Does the O(1) damage-number slot reuse pick the same slot the scan did?
##
## Floating damage numbers are cosmetic, but they are also the single largest cost
## in the worst fixture, because finding a slot for one used to scan the whole pool
## and then scan it again for the oldest when the pool was full. A blast landing on
## a hundred enemies paid that a hundred times.
##
## The replacement maintains both answers instead of searching for them. That is
## only safe if it recycles the same slot the scan would have, so this reimplements
## the original selection rule -- first inactive by index, else max age, ties to the
## lowest index -- reads it against the live pool before each spawn, and checks the
## slot that actually changed.
##
## It also asserts the cursor invariant, because a cursor that has drifted above a
## free slot would silently skip the slot the old scan would have chosen.
##
## A queue of slots in activation order was tried as a fast replacement for the
## full-pool scan, on the reasoning that uniform ageing makes activation order the
## same as age order. This probe disproved that under sustained saturation, so the
## full-pool case is still the original scan and this stands guard over it.
##
## Run: godot --headless --script tests/damage_number_pool_probe.gd

const SPAWNS := 4000
## Long enough that numbers expire mid-run and slots are genuinely recycled, rather
## than the pool simply filling once and staying full.
const STEP := 1.0 / 60.0

var _checked := 0
var _mismatches: Array[String] = []
var _invariant_failures: Array[String] = []
var _saturated_spawns := 0


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
	prototype.combat.set_process(false)
	prototype.adaptation_director.set_process(false)

	var combat := prototype.combat
	combat.reset_combat()

	var random := RandomNumberGenerator.new()
	random.seed = 20260830

	for spawn_index in range(SPAWNS):
		# Two regimes, because they exercise different halves of the replacement. The
		# first lets numbers expire so slots are genuinely recycled and the cursor is
		# pushed around; the second starves the clock so the pool saturates and every
		# spawn goes through the full-pool path, which is the one that used to scan
		# twice and the one whose tie-breaking is easiest to get wrong.
		var saturating := spawn_index >= SPAWNS / 2
		var advance_chance := 0.02 if saturating else 0.18
		if random.randf() < advance_chance:
			combat._update_damage_numbers(STEP * random.randf_range(0.5, 4.0))

		var expected := _reference_selection(combat)
		if expected < 0:
			# The reference found nothing to recycle, which the real one must agree
			# with; spawning anyway would prove nothing.
			continue
		if _pool_is_full(combat):
			_saturated_spawns += 1

		# Identified by the impact position rather than by the text, because two
		# numbers can legitimately read the same and, under saturation, dozens share
		# an age of zero. A random float pair is unique in practice.
		var marker := Vector2(
			random.randf_range(60.0, 800.0), random.randf_range(60.0, 420.0)
		)
		combat._spawn_damage_number(
			marker,
			random.randf_range(4.0, 20.0),
			random.randf_range(1.0, 9999.0),
			Color.WHITE
		)

		var actual := _slot_holding(combat, marker)
		_checked += 1
		if actual != expected and _mismatches.size() < 8:
			_mismatches.append(
				(
					"DAMAGE_NUMBER_POOL mismatch spawn=%d expected slot %d, "
					+ "took slot %d (pool full: %s)"
				) % [spawn_index, expected, actual, _pool_is_full(combat)]
			)
		_check_invariants(combat, spawn_index)

	prototype.queue_free()
	await process_frame

	print(
		"DAMAGE_NUMBER_POOL: %d spawns compared, %d of them against a full pool"
		% [_checked, _saturated_spawns]
	)
	if _mismatches.is_empty() and _invariant_failures.is_empty():
		print("DAMAGE_NUMBER_POOL: PASS (same slot every time, invariants hold)")
		quit(0)
		return
	for line in _mismatches:
		print(line)
	for line in _invariant_failures:
		print(line)
	push_error(
		"DAMAGE_NUMBER_POOL: %d selection mismatches, %d invariant failures"
		% [_mismatches.size(), _invariant_failures.size()]
	)
	quit(1)


func _reference_selection(combat: PhaseBCombatDirector) -> int:
	## The rule exactly as it was written before: the first inactive slot by index,
	## otherwise the slot with the greatest age, ties going to the lowest index.
	var selected := -1
	var oldest_age := -1.0
	for index in range(combat._damage_numbers.size()):
		var damage_number: Object = combat._damage_numbers[index]
		if not damage_number.active:
			return index
		if damage_number.age > oldest_age:
			oldest_age = damage_number.age
			selected = index
	return selected


func _pool_is_full(combat: PhaseBCombatDirector) -> bool:
	for damage_number in combat._damage_numbers:
		if not damage_number.active:
			return false
	return true


func _slot_holding(combat: PhaseBCombatDirector, marker: Vector2) -> int:
	## Which slot the spawn landed in, found by the impact position it was given.
	for index in range(combat._damage_numbers.size()):
		var damage_number: Object = combat._damage_numbers[index]
		if damage_number.active and damage_number.impact_position == marker:
			return index
	return -1


func _check_invariants(combat: PhaseBCombatDirector, spawn_index: int) -> void:
	if _invariant_failures.size() >= 6:
		return
	# Everything below the cursor must be active, or the free-slot search can skip
	# a slot the old scan would have found.
	for index in range(mini(combat._damage_number_free_cursor, combat._damage_numbers.size())):
		if not combat._damage_numbers[index].active:
			_invariant_failures.append(
				"DAMAGE_NUMBER_POOL cursor invariant broken at spawn %d: slot %d is free but below cursor %d"
				% [spawn_index, index, combat._damage_number_free_cursor]
			)
			return
