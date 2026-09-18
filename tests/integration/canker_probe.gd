extends SceneTree

## The Canker system on a real field: what grows a Knot, what kills one, and the rule
## that it must never add an enemy.
##
## `canker_rules_probe` drives the ladder with numbers. This one drives the node, which
## is where the questions the arithmetic cannot answer live: whether the field's Rot
## measurement agrees with the thresholds it is compared against, whether a Knot can
## reach the player, whether reclaiming the ground actually removes one, and whether a
## redirected spawn is the same enemy through a different door or an extra enemy.
##
## Run: godot --headless --path . --script tests/integration/canker_probe.gd

const RUN_SCENE := "res://scenes/run/run.tscn"

var _failures := 0
## Signal flags live on the script rather than in the function that checks them:
## a GDScript lambda captures locals by value, so `warned = true` inside one sets a
## copy and the check that follows reads the original, unchanged.
var _warned := false
var _formed := false
var _withered := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _drive()
	if _failures == 0:
		print("CANKER: PASS")
		quit(0)
	else:
		push_error("CANKER: %d failure(s)" % _failures)
		quit(1)


func _drive() -> void:
	var run := await _load_run()
	if run == null:
		return
	run.set_process(false)
	run.player.input_enabled = false
	var director := run.canker_director
	var field := run.territory_field
	_check(director != null, "the run scene carries a Canker director")
	if director == null:
		return

	# Hand the enemy the whole board before the clock starts. Grandma is parked in one
	# corner so the exclusion radius has somewhere to exclude; without that every site
	# is too close to her and the placement rule, not the ladder, is what is measured.
	director.reset_director()
	field.make_field_hostile(0.85)
	field.recalculate_metrics_now()
	run.player.global_position = field.to_global(Vector2(40.0, 40.0))

	# The wave gate, checked on the worst board there is. The arena already opens with a
	# hostile basin that qualifies on its own, so without the gate a Canker forms about
	# twelve seconds into every run on ground nobody has had a chance to contest.
	# The real wave clock is driven here rather than faked, because the gate reads it.
	run.wave_director.reset_director()
	_check(
		run.wave_director.get_current_wave_number() < director.first_wave,
		"the run opens before the wave Cankers are gated on (wave %d of %d)"
			% [run.wave_director.get_current_wave_number(), director.first_wave]
	)
	_check(not director.is_armed(), "so the director is not yet armed")
	_advance(director, 120.0)
	_check(
		director.get_active_knot_count() == 0,
		"and no Knot forms before that wave, however lost the ground already is"
	)

	run.wave_director.debug_advance_time(
		float(director.first_wave - 1) * run.wave_director.wave_duration_seconds
	)
	_check(
		director.is_armed(),
		"reaching the gate wave arms the director (wave %d)"
			% [run.wave_director.get_current_wave_number()]
	)
	var measured := field.measure_rot_ratio_in_radius(
		field.tuning.arena_size * 0.5, director.sample_radius, director.sample_cell_stride
	)
	_check(
		measured > director.activation_rot_ratio,
		"a lost field measures as Rot the director would act on (%.2f)" % [measured]
	)

	director.canker_warning_started.connect(func(_position: Vector2) -> void: _warned = true)
	director.canker_formed.connect(func(_position: Vector2) -> void: _formed = true)

	# Short of the hold time, so the warning is proven to be a gate rather than a
	# decoration that happens to precede a Knot.
	_advance(director, director.hold_time - 1.0)
	_check(
		director.get_active_knot_count() == 0,
		"lost ground alone does not form a Knot before the hold time"
	)
	_advance(director, 2.0)
	_check(_warned, "holding Rot for the authored time raises a warning first")
	_check(
		director.get_active_knot_count() == 0,
		"and the warning is a real delay, not a label on the same frame"
	)

	_advance(director, director.warning_time + 1.0)
	_check(_formed and director.get_active_knot_count() > 0, "an unanswered warning forms a Knot")

	_advance(director, 60.0)
	_check(
		director.get_active_knot_count() <= director.maximum_active_knots,
		"a wholly lost field never exceeds the Knot cap (%d)"
			% [director.get_active_knot_count()]
	)

	var positions := director.get_active_knot_positions()
	var player_position := run.player.get_arena_position()
	var closest := INF
	for position in positions:
		closest = minf(closest, position.distance_to(player_position))
	_check(
		closest >= director.minimum_player_distance,
		"no Knot forms inside the exclusion around Grandma (%.0fpx)" % [closest]
	)
	if positions.size() > 1:
		var nearest_pair := INF
		for first in range(positions.size()):
			for second in range(first + 1, positions.size()):
				nearest_pair = minf(
					nearest_pair, positions[first].distance_to(positions[second])
				)
		_check(
			nearest_pair >= director.minimum_knot_spacing,
			"and two Knots never share one blob (%.0fpx apart)" % [nearest_pair]
		)

	_check_warning_is_a_promise(director)
	_check_redirection_is_topology_only(run, director)
	_check_reclaim_destroys(run, director, field)
	_check_variation(director)


func _check_warning_is_a_promise(director: CankerDirector) -> void:
	## A warning has to mean a Knot is coming *here*. Slots are reserved when a site
	## starts warning rather than when it forms, so a board that has gone entirely to
	## Rot telegraphs the two regions that will actually open and not the twenty-eight
	## that would like to. Without this the player learns the telegraph is noise.
	var warning := 0
	var active := 0
	for site in director._sites:
		if site.stage == CankerRules.Stage.WARNING:
			warning += 1
		elif site.stage == CankerRules.Stage.ACTIVE:
			active += 1
	_check(
		warning + active <= director.maximum_active_knots,
		"a wholly lost board telegraphs only the Knots it can deliver (%d warning, %d open)"
			% [warning, active]
	)


func _check_redirection_is_topology_only(run: RunRoot, director: CankerDirector) -> void:
	## Section 18's one critical rule. A Canker may change where an enemy enters and
	## must never change how many enter, so the population is counted across a fixed
	## number of spawn requests rather than the redirect being inspected on its own.
	_check(
		director.get_redirect_share() <= director.maximum_redirect_share,
		"the redirect share stays under its cap with every Knot up (%.2f)"
			% [director.get_redirect_share()]
	)
	run.combat.reset_combat()
	var requests := 60
	var spawned := 0
	for _index in range(requests):
		if run.combat.spawn_enemy(EnemyKinds.Role.HUNTER) != -1:
			spawned += 1
	_check(
		run.combat.get_active_enemy_count() == spawned,
		"every spawn request produces exactly one enemy, redirected or not (%d)" % [spawned]
	)
	_check(
		director.get_redirects_served() <= spawned,
		"and no more spawns are reported redirected than were actually made"
	)
	# The interior is meant to be used, not merely permitted. With the field wholly
	# hostile and two Knots up, some share of sixty ordinary spawns should have come
	# through one; zero would mean the path is wired but dead.
	_check(
		director.get_redirects_served() > 0,
		"reinforcements actually come through the interior (%d of %d)"
			% [director.get_redirects_served(), spawned]
	)

	var served_before := director.get_redirects_served()
	for _index in range(20):
		run.combat.spawn_enemy(EnemyKinds.Role.BOSS)
		run.combat.spawn_enemy(EnemyKinds.Role.RUSHER)
	_check(
		director.get_redirects_served() == served_before,
		"bosses and telegraphed Rushers are never redirected inside"
	)


func _check_reclaim_destroys(
	run: RunRoot, director: CankerDirector, field: TerritoryField
) -> void:
	## Damage must not be a route to this. The Knots are removed here by giving the
	## ground back to the player and by nothing else.
	var before := director.get_active_knot_count()
	if before == 0:
		_check(false, "there is a Knot to destroy")
		return
	director.canker_withered.connect(func(_position: Vector2) -> void: _withered = true)
	run.combat.reset_combat()
	# Taken back the way the game takes ground back. `neutralize_cells` is no help
	# here: it only releases ground the *player* holds, so on a lost field it is a no-op
	# and the Knot would appear to survive a reclaim that never happened.
	var knot_position := director.get_active_knot_positions()[0]
	var cell_pixels := field.tuning.arena_size.x / float(field.get_grid_width())
	var splat_radius_cells := director.sample_radius / maxf(1.0, cell_pixels) * 2.0
	for _wave in range(12):
		field.queue_splat(knot_position, 900.0, 6.0, splat_radius_cells, 1.0)
		for _step in range(8):
			field.step_simulation()
	field.recalculate_metrics_now()
	var ratio := field.measure_rot_ratio_in_radius(
		knot_position, director.sample_radius, director.sample_cell_stride
	)
	_check(
		ratio < director.destroy_rot_ratio,
		"reclaimed ground measures under the wither threshold (%.2f)" % [ratio]
	)
	_advance(director, director.destroy_hold_time + 2.0)
	_check(_withered, "taking the ground back withers the Knot")
	_check(
		director.get_active_knot_count() < before,
		"and the board has fewer Knots than it did (%d, was %d)"
			% [director.get_active_knot_count(), before]
	)
	_check(
		director.get_redirect_share() < director.maximum_redirect_share
		or director.get_active_knot_count() > 0,
		"redirection falls away with the Knot that caused it"
	)


func _check_variation(director: CankerDirector) -> void:
	## The art is authored in four variations and each Knot draws one at a random
	## rotation, so a field that grows several does not read as the same decal stamped
	## twice. Checked through the director's own draw so the seeding is the real one.
	var textures := {}
	var rotations: Array[float] = []
	for _run_index in range(40):
		director.set_run_seed(_run_index * 7919 + 13)
		director.reset_director()
		var site := CankerDirector.Site.new()
		director._open_knot(site)
		textures[site.texture_index] = true
		rotations.append(site.rotation)
	_check(
		textures.size() == CankerDirector.CANKER_TEXTURES.size(),
		"every authored Canker variation gets used (%d of %d)"
			% [textures.size(), CankerDirector.CANKER_TEXTURES.size()]
	)
	var distinct_rotations := {}
	var inside_circle := true
	for rotation in rotations:
		distinct_rotations[snappedf(rotation, 0.01)] = true
		if rotation < 0.0 or rotation > TAU:
			inside_circle = false
	_check(inside_circle, "and each is turned somewhere inside one full rotation")
	_check(
		distinct_rotations.size() > rotations.size() / 2,
		"with rotations that actually differ (%d distinct of %d)"
			% [distinct_rotations.size(), rotations.size()]
	)


func _advance(director: CankerDirector, seconds: float) -> void:
	# A fixed step near the evaluation period, so the ladder is driven the way a frame
	# would drive it rather than in one leap it could never see in play.
	var step := 0.25
	var remaining := seconds
	while remaining > 0.0:
		director.advance(minf(step, remaining))
		remaining -= step


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
