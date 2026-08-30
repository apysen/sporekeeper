class_name PhaseBBrambleDirector
extends Node

## Bramble: what the run's Bramble investment resolves to, and pushing those
## values into the systems that execute them. Bramble has no cadence and owns no
## entities of its own - its damage, Entanglement, roots and repulsion are
## resolved per enemy inside the combat loop, and its resistance is a field rule -
## so this component owns the path's tuning and its derived values rather than a
## per-frame simulation.

@export_group("Collaborators")
## Authoritative field that applies Bramble's resistance rule.
@export var territory_field: TerritoryField
## Combat component that resolves thorn contact, Entanglement, roots, and repulsion.
@export var combat: PhaseBCombatDirector
## Progression component that owns which lines the run has taken and at what level.
@export var progression: PhaseBProgression
## Overlay that draws the tethers this path publishes. Presentation only: the
## restraint itself stays deterministic inside the combat loop.
@export var overlay: TerritoryPrototypeOverlay

@export_group("Tethers")
## Enemies whose tethers may be drawn at once, so a horde stays readable and the
## presentation cost stays bounded however many bodies are on the Green.
@export_range(0, 200, 1) var maximum_drawn_tethers := 48
## Entanglement below which an enemy is not yet visibly tethered at all.
@export_range(0.0, 1.0, 0.01) var minimum_visible_entanglement := 0.08
## Tethers drawn on a fully Entangled enemy. Higher Entanglement means more and
## thicker strands, which is the whole readout the player gets.
@export_range(1, 8, 1) var maximum_strands := 3
## Pixels from the enemy at which a strand roots into the Green holding it.
@export_range(4.0, 120.0, 1.0) var anchor_radius_pixels := 26.0

var _tethered_enemies := {}

@export_group("Bramble Relics")
## Hookthorn: how long after a shove a collision still counts, how close counts as
## a collision, and what each body picks up. Elites and bosses take a reduced share
## of every Entanglement number in this pool.
@export_range(0.05, 2.0, 0.05) var hookthorn_window_seconds := 0.40
@export_range(4.0, 120.0, 1.0) var hookthorn_collision_pixels := 30.0
@export_range(0.0, 1.0, 0.01) var hookthorn_repelled_entanglement := 0.15
@export_range(0.0, 1.0, 0.01) var hookthorn_struck_entanglement := 0.20
@export_range(0.0, 5.0, 0.05) var hookthorn_enemy_cooldown_seconds := 0.75
## Thornback: the damaged Green answers a shove by shooting a thorn at somebody else.
@export_range(20.0, 600.0, 5.0) var thornback_range_pixels := 180.0
@export_range(0.0, 200.0, 1.0) var thornback_damage := 14.0
@export_range(0.0, 1.0, 0.01) var thornback_entanglement := 0.12
@export_range(0.0, 10.0, 0.05) var thornback_source_cooldown_seconds := 1.25
## Cocklebur: Entanglement carried off the Green on the enemy that picked it up.
@export_range(0.0, 1.0, 0.01) var cocklebur_minimum_entanglement := 0.50
@export_range(0.1, 20.0, 0.1) var cocklebur_seconds := 3.0
@export_range(0.0, 1.0, 0.01) var cocklebur_contact_entanglement := 0.10
@export_range(4.0, 120.0, 1.0) var cocklebur_contact_pixels := 26.0
@export_range(0.0, 5.0, 0.05) var cocklebur_same_target_cooldown := 0.75
@export_range(1, 20, 1) var cocklebur_maximum_targets := 4
## Briar Knot: what a heavily Entangled corpse leaves behind.
@export_range(0.0, 1.0, 0.01) var briar_knot_required_entanglement := 0.90
@export_range(0.5, 60.0, 0.5) var briar_knot_lifetime_seconds := 7.0
@export_range(10.0, 300.0, 2.0) var briar_knot_trigger_pixels := 72.0
@export_range(0.0, 2.0, 0.05) var briar_knot_trigger_delay := 0.15
@export_range(0.0, 200.0, 1.0) var briar_knot_pull_pixels := 42.0
@export_range(0.0, 1.0, 0.01) var briar_knot_entanglement := 0.40
@export_range(1, 20, 1) var briar_knot_maximum := 6
## Briarball: heavily Entangled deaths that roll up into one thorn ball.
@export_range(1, 20, 1) var briarball_deaths_required := 4
@export_range(0.5, 30.0, 0.5) var briarball_lifetime_seconds := 4.5
@export_range(20.0, 1200.0, 10.0) var briarball_speed := 240.0
@export_range(20.0, 1200.0, 10.0) var briarball_search_pixels := 420.0
@export_range(4.0, 120.0, 1.0) var briarball_contact_pixels := 26.0
@export_range(0.0, 200.0, 1.0) var briarball_damage := 24.0
@export_range(0.0, 1.0, 0.01) var briarball_entanglement := 0.30
@export_range(0.0, 200.0, 1.0) var briarball_repulsion_pixels := 40.0
@export_range(1, 40, 1) var briarball_maximum_hits := 8
@export_range(1, 8, 1) var briarball_active_maximum := 2
## Shared elite and boss shares. Applied after the flat value is decided, so one
## authored number stays readable across every relic in the pool.
@export_range(0.0, 1.0, 0.01) var relic_elite_entanglement_share := 0.75
@export_range(0.0, 1.0, 0.01) var relic_boss_entanglement_share := 0.40

## Enemies recently shoved by Repulsion, by id: [remaining, cooldown].
var _hookthorn_windows := {}
## Per-enemy Hookthorn cooldowns, so one shove cannot tangle a crowd repeatedly.
var _hookthorn_cooldowns := {}
## Per-source Thornback cooldowns, by enemy id.
var _thornback_cooldowns := {}
## Burr carriers, by id: [remaining, {target_id: cooldown}, unique_targets_hit].
var _burr_carriers := {}
## Standing Briar Knots, each [position, lifetime, arming].
var _knots: Array = []
## Rolling Briarballs, each [position, velocity, lifetime, {hit_id: true}].
var _briarballs: Array = []
var _briarball_charge := 0

@export_group("Resistance")
## Resistance multiplier applied to Green frontier cells whenever Bramble is
## selected. Durability is deliberately not an upgrade line; it overlaps Root.
@export_range(1.0, 4.0, 0.05) var base_resistance_multiplier := 1.15

@export_group("Entanglement")
## Movement-speed reduction applied to a fully Entangled enemy before upgrades.
@export_range(0.0, 0.9, 0.01) var base_slow_fraction := 0.15
## Additional fully-Entangled movement-speed reduction granted by each rank.
@export_range(0.0, 0.25, 0.01) var slow_per_level := 0.06
## Additive multiplier on Entanglement applied by Bramble effects per rank.
@export_range(0.0, 1.0, 0.01) var entanglement_potency_per_level := 0.15

@export_group("Ensnare Rate")
## Additive Entanglement build rate granted by each Ensnare Rate rank.
@export_range(0.0, 2.0, 0.01) var ensnare_per_level := 0.26

@export_group("Grasping Roots")
## Seconds a fully Entangled enemy is rooted whenever Bramble is selected.
@export_range(0.0, 5.0, 0.05) var base_root_seconds := 0.35
## Additional seconds of root granted by each Grasping Roots rank.
@export_range(0.0, 2.0, 0.05) var root_seconds_per_level := 0.35
## Seconds an enemy cannot be rooted again after Grasping Roots releases it, so a
## permanently Entangled enemy is held repeatedly rather than held forever.
@export_range(0.0, 20.0, 0.1) var root_immunity_seconds := 4.0

@export_group("Repulsion")
## Arena pixels an enemy damaging Green is shoved back whenever Bramble is
## selected. Retaliation is repulsion, not damage: the path controls, it does not
## passively kill.
@export_range(0.0, 400.0, 1.0) var base_repulsion_pixels := 26.0
## Additional repulsion distance granted by each Repulsion rank.
@export_range(0.0, 200.0, 1.0) var repulsion_pixels_per_level := 16.0


func _ready() -> void:
	assert(territory_field != null, "PhaseBBrambleDirector requires TerritoryField")
	assert(combat != null, "PhaseBBrambleDirector requires PhaseBCombatDirector")
	assert(progression != null, "PhaseBBrambleDirector requires PhaseBProgression")
	combat.enemy_repelled.connect(_on_enemy_repelled)
	combat.enemy_left_green.connect(_on_enemy_left_green)
	combat.enemy_died_entangled.connect(_on_enemy_died_entangled)


func reset_director() -> void:
	_tethered_enemies.clear()
	_hookthorn_windows.clear()
	_hookthorn_cooldowns.clear()
	_thornback_cooldowns.clear()
	_burr_carriers.clear()
	_knots.clear()
	_briarballs.clear()
	_briarball_charge = 0


func _has_relic(relic_id: int) -> bool:
	return progression.has_relic(relic_id)


func _entanglement_for(enemy_id: int, amount: float) -> float:
	## One authored number, reduced for the targets that are meant to resist it. Every
	## relic in this pool spends its Entanglement through here so the elite and boss
	## shares cannot drift apart between them.
	match combat.get_enemy_role(enemy_id):
		PhaseBCombatDirector.EnemyRole.BOSS:
			return amount * relic_boss_entanglement_share
		PhaseBCombatDirector.EnemyRole.ELITE:
			return amount * relic_elite_entanglement_share
	return amount


func advance_relics(delta: float) -> void:
	## The relic layer's own tick. Kept apart from advance(), which is presentation.
	_advance_timers(delta)
	_advance_hookthorn(delta)
	_advance_cocklebur(delta)
	_advance_knots(delta)
	_advance_briarballs(delta)


func _advance_timers(delta: float) -> void:
	for enemy_id in _hookthorn_cooldowns.keys():
		var remaining := float(_hookthorn_cooldowns[enemy_id]) - delta
		if remaining <= 0.0:
			_hookthorn_cooldowns.erase(enemy_id)
		else:
			_hookthorn_cooldowns[enemy_id] = remaining
	for enemy_id in _thornback_cooldowns.keys():
		var remaining := float(_thornback_cooldowns[enemy_id]) - delta
		if remaining <= 0.0:
			_thornback_cooldowns.erase(enemy_id)
		else:
			_thornback_cooldowns[enemy_id] = remaining


func _advance_hookthorn(delta: float) -> void:
	# A shove only counts as a collision for a moment after it starts. Outside that
	# window two enemies drifting into each other is just the crowd moving.
	for enemy_id in _hookthorn_windows.keys():
		var window: Array = _hookthorn_windows[enemy_id]
		window[0] = float(window[0]) - delta
		if float(window[0]) <= 0.0:
			_hookthorn_windows.erase(enemy_id)
			continue
		if _hookthorn_cooldowns.has(enemy_id):
			continue
		var shoved_position := combat.get_enemy_position(enemy_id)
		if shoved_position.x < 0.0:
			_hookthorn_windows.erase(enemy_id)
			continue
		for other_id in combat.get_active_enemy_ids():
			if other_id == enemy_id or _hookthorn_cooldowns.has(other_id):
				continue
			if combat.get_enemy_position(other_id).distance_to(shoved_position) > hookthorn_collision_pixels:
				continue
			combat.add_entanglement_to_enemy(
				enemy_id, _entanglement_for(enemy_id, hookthorn_repelled_entanglement)
			)
			combat.add_entanglement_to_enemy(
				other_id, _entanglement_for(other_id, hookthorn_struck_entanglement)
			)
			_hookthorn_cooldowns[enemy_id] = hookthorn_enemy_cooldown_seconds
			_hookthorn_cooldowns[other_id] = hookthorn_enemy_cooldown_seconds
			# One collision per shove. The window closes rather than staying open for
			# the rest of the slide, so a shove into a wall of bodies tangles one pair.
			_hookthorn_windows.erase(enemy_id)
			break


func _advance_cocklebur(delta: float) -> void:
	for enemy_id in _burr_carriers.keys():
		var carrier: Array = _burr_carriers[enemy_id]
		carrier[0] = float(carrier[0]) - delta
		if float(carrier[0]) <= 0.0:
			_burr_carriers.erase(enemy_id)
			continue
		var carrier_position := combat.get_enemy_position(enemy_id)
		if carrier_position.x < 0.0:
			_burr_carriers.erase(enemy_id)
			continue
		var touched: Dictionary = carrier[1]
		for target_id in touched.keys():
			var remaining := float(touched[target_id]) - delta
			if remaining <= 0.0:
				touched.erase(target_id)
			else:
				touched[target_id] = remaining
		if int(carrier[2]) >= cocklebur_maximum_targets:
			continue
		for other_id in combat.get_active_enemy_ids():
			if other_id == enemy_id or touched.has(other_id):
				continue
			if combat.get_enemy_position(other_id).distance_to(carrier_position) > cocklebur_contact_pixels:
				continue
			combat.add_entanglement_to_enemy(
				other_id, _entanglement_for(other_id, cocklebur_contact_entanglement)
			)
			touched[other_id] = cocklebur_same_target_cooldown
			carrier[2] = int(carrier[2]) + 1
			if int(carrier[2]) >= cocklebur_maximum_targets:
				break


func _advance_knots(delta: float) -> void:
	for index in range(_knots.size() - 1, -1, -1):
		var knot: Array = _knots[index]
		knot[1] = float(knot[1]) - delta
		if float(knot[1]) <= 0.0:
			_knots.remove_at(index)
			continue
		var knot_position: Vector2 = knot[0]
		if float(knot[2]) > 0.0:
			# Something is already inside it and the yank is winding up.
			knot[2] = float(knot[2]) - delta
			if float(knot[2]) > 0.0:
				continue
			_spring_knot(index, knot_position)
			continue
		for enemy_id in combat.get_active_enemy_ids():
			if combat.get_enemy_position(enemy_id).distance_to(knot_position) > briar_knot_trigger_pixels:
				continue
			knot[2] = maxf(0.0001, briar_knot_trigger_delay)
			break


func _spring_knot(index: int, knot_position: Vector2) -> void:
	# One use. The Knot resolves against whoever is closest when it actually springs,
	# which may not be whoever armed it.
	var caught := -1
	var nearest := briar_knot_trigger_pixels
	for enemy_id in combat.get_active_enemy_ids():
		var distance := combat.get_enemy_position(enemy_id).distance_to(knot_position)
		if distance <= nearest:
			nearest = distance
			caught = enemy_id
	if index < _knots.size():
		_knots.remove_at(index)
	if caught < 0:
		return
	combat.knockback_enemy_from(
		caught,
		knot_position + (combat.get_enemy_position(caught) - knot_position) * 2.0,
		briar_knot_pull_pixels
	)
	combat.add_entanglement_to_enemy(
		caught, _entanglement_for(caught, briar_knot_entanglement)
	)
	if overlay != null:
		# One sharp yank rather than an area explosion.
		overlay.spawn_relic_cue(
			TerritoryPrototypeOverlay.RelicCue.BITE,
			knot_position,
			briar_knot_trigger_pixels * 0.6,
			Color("b06fd7"),
			Vector2.ZERO,
			false,
			1.0,
			TerritoryPrototypeOverlay.RelicMotif.KNOT
		)


func _advance_briarballs(delta: float) -> void:
	for index in range(_briarballs.size() - 1, -1, -1):
		var ball: Array = _briarballs[index]
		ball[2] = float(ball[2]) - delta
		var hit: Dictionary = ball[3]
		if float(ball[2]) <= 0.0 or hit.size() >= briarball_maximum_hits:
			_briarballs.remove_at(index)
			continue
		var ball_position: Vector2 = ball[0]
		# Steer at the densest crowd it has not already been through, so the ball
		# reads as crashing through the fight rather than drifting.
		var target := _find_briarball_target(ball_position, hit)
		var heading: Vector2 = ball[1]
		if target.x >= 0.0:
			heading = ball_position.direction_to(target)
		if heading.length_squared() <= 0.000001:
			heading = Vector2.RIGHT
		var next_position := ball_position + heading * briarball_speed * delta
		if not territory_field.contains_local_point(next_position):
			_briarballs.remove_at(index)
			continue
		ball[0] = next_position
		ball[1] = heading
		for enemy_id in combat.get_active_enemy_ids():
			if hit.has(enemy_id) or hit.size() >= briarball_maximum_hits:
				continue
			if combat.get_enemy_position(enemy_id).distance_to(next_position) > briarball_contact_pixels:
				continue
			hit[enemy_id] = true
			combat.damage_enemy_by_id(
				enemy_id, briarball_damage, PhaseBCombatDirector.DeathSource.RELIC
			)
			combat.add_entanglement_to_enemy(
				enemy_id, _entanglement_for(enemy_id, briarball_entanglement)
			)
			combat.knockback_enemy_from(enemy_id, next_position, briarball_repulsion_pixels)
		if overlay != null:
			overlay.spawn_hostile_pulse(next_position, briarball_contact_pixels)


func _find_briarball_target(from_position: Vector2, hit: Dictionary) -> Vector2:
	var best := Vector2(-1.0, -1.0)
	var best_count := 0
	for enemy_id in combat.get_active_enemy_ids():
		if hit.has(enemy_id):
			continue
		var candidate := combat.get_enemy_position(enemy_id)
		if candidate.distance_to(from_position) > briarball_search_pixels:
			continue
		var count := 0
		for other_id in combat.get_active_enemy_ids():
			if combat.get_enemy_position(other_id).distance_to(candidate) <= briarball_contact_pixels * 4.0:
				count += 1
		if count > best_count:
			best_count = count
			best = candidate
	return best


func _on_enemy_repelled(enemy_id: int, from_position: Vector2, _direction: Vector2) -> void:
	if _has_relic(PhaseBRelicCatalog.Id.HOOKTHORN):
		_hookthorn_windows[enemy_id] = [hookthorn_window_seconds]
	if _has_relic(PhaseBRelicCatalog.Id.THORNBACK):
		_fire_thornback(enemy_id, from_position)


func _fire_thornback(source_id: int, from_position: Vector2) -> void:
	if _thornback_cooldowns.has(source_id):
		return
	# Aim at whoever is least tangled: the relic's job is to spread Entanglement
	# around the crowd, not to finish off the enemy already covered in it.
	var target := -1
	var lowest := INF
	for enemy_id in combat.get_active_enemy_ids():
		if enemy_id == source_id:
			continue
		if combat.get_enemy_position(enemy_id).distance_to(from_position) > thornback_range_pixels:
			continue
		var tangled := combat.get_enemy_entanglement(enemy_id)
		if tangled < lowest:
			lowest = tangled
			target = enemy_id
	if target < 0:
		# Nobody else in range. The triggering enemy is allowed to be the target
		# rather than the thorn being wasted.
		target = source_id
	_thornback_cooldowns[source_id] = thornback_source_cooldown_seconds
	combat.damage_enemy_by_id(
		target, thornback_damage, PhaseBCombatDirector.DeathSource.RELIC
	)
	combat.add_entanglement_to_enemy(
		target, _entanglement_for(target, thornback_entanglement)
	)


func _on_enemy_left_green(
	enemy_id: int,
	_local_position: Vector2,
	entanglement: float
) -> void:
	if not _has_relic(PhaseBRelicCatalog.Id.COCKLEBUR):
		return
	if entanglement < cocklebur_minimum_entanglement:
		return
	if _burr_carriers.has(enemy_id):
		# Leaving Green again while already carrying does not refresh the timer.
		return
	_burr_carriers[enemy_id] = [cocklebur_seconds, {}, 0]
	if overlay != null:
		# A carrier has to be identifiable off the Green, or the player cannot tell
		# which body is spreading thorns.
		overlay.spawn_relic_cue(
			TerritoryPrototypeOverlay.RelicCue.BAND,
			_local_position,
			cocklebur_contact_pixels,
			Color("b06fd7"),
			Vector2.ZERO,
			false,
			1.0,
			TerritoryPrototypeOverlay.RelicMotif.BURR
		)


func _on_enemy_died_entangled(
	local_position: Vector2,
	entanglement: float,
	_role: int
) -> void:
	if entanglement < briar_knot_required_entanglement:
		return
	if _has_relic(PhaseBRelicCatalog.Id.BRIAR_KNOT):
		if _knots.size() >= briar_knot_maximum:
			# The oldest Knot is replaced rather than the new one being dropped, so
			# the trap always marks where the fight actually is.
			_knots.remove_at(0)
		_knots.append([local_position, briar_knot_lifetime_seconds, 0.0])
	if not _has_relic(PhaseBRelicCatalog.Id.BRIARBALL):
		return
	_briarball_charge += 1
	if _briarball_charge < briarball_deaths_required:
		return
	if _briarballs.size() >= briarball_active_maximum:
		# The completed charge is preserved rather than spent, so the next expiry
		# releases the ball the player already paid four corpses for.
		return
	_briarball_charge = 0
	_briarballs.append([local_position, Vector2.ZERO, briarball_lifetime_seconds, {}])


func get_knot_count() -> int:
	return _knots.size()


func get_briarball_count() -> int:
	return _briarballs.size()


func get_burr_carrier_count() -> int:
	return _burr_carriers.size()


func advance(_delta: float) -> void:
	# Entanglement is tied to the Green field visually as well as mechanically: the
	# vines come out of the ground the enemy is standing on. The strands are pure
	# presentation, published once per frame as plain values, so no expensive rope
	# simulation is ever run and nothing here can change a combat result.
	if overlay == null:
		return
	if not has_path():
		if not _tethered_enemies.is_empty():
			_tethered_enemies.clear()
		overlay.set_tethers([])
		return
	var tethers: Array = []
	var still_held := {}
	for enemy_id in combat.get_active_enemy_ids():
		if tethers.size() >= maximum_drawn_tethers:
			break
		var strength := combat.get_enemy_entanglement(enemy_id)
		if strength < minimum_visible_entanglement:
			continue
		var enemy_position := combat.get_enemy_position(enemy_id)
		var coverage := territory_field.get_bramble_coverage_at_local(enemy_position)
		if coverage <= 0.0:
			continue
		var strands := maxi(1, int(ceil(strength * float(maximum_strands))))
		var anchor := enemy_position + Vector2.from_angle(
			float(enemy_id) * 2.39996
		) * anchor_radius_pixels
		if not territory_field.contains_local_point(anchor):
			anchor = enemy_position
		still_held[enemy_id] = enemy_position
		tethers.append(overlay.make_tether(anchor, enemy_position, strength, strands))
	overlay.set_tethers(tethers)
	# A restraint that ends does not simply disappear: the strands snap back, which
	# is the only feedback the player gets that something tore free.
	for released_id in _tethered_enemies:
		if still_held.has(released_id):
			continue
		var last_position: Vector2 = _tethered_enemies[released_id]
		overlay.spawn_tether_snap(
			last_position + Vector2.from_angle(float(released_id) * 2.39996)
				* anchor_radius_pixels,
			last_position
		)
	_tethered_enemies = still_held


func has_path() -> bool:
	# Active, not owned: a Bramble jackpot runs the path for a run that never took it.
	return progression.has_path_active(PhaseBProgression.PathId.BRAMBLE)


func get_resistance_multiplier() -> float:
	if not has_path():
		return 1.0
	return base_resistance_multiplier


func get_ensnare_multiplier() -> float:
	if not has_path():
		return 1.0
	return 1.0 + ensnare_per_level * float(
		progression.get_upgrade_level(PhaseBProgression.UpgradeId.BRAMBLE_ENSNARE_RATE)
	)


func get_slow_fraction() -> float:
	if not has_path():
		return 0.0
	return clampf(
		base_slow_fraction
		+ slow_per_level * float(
			progression.get_upgrade_level(
				PhaseBProgression.UpgradeId.BRAMBLE_ENTANGLEMENT
			)
		),
		0.0,
		0.85
	)


func get_entanglement_multiplier() -> float:
	# Entanglement deepens the effect Bramble applies, which is what a Briar Trap
	# or a root eruption hands an enemy on top of its damage.
	return 1.0 + entanglement_potency_per_level * float(
		progression.get_upgrade_level(PhaseBProgression.UpgradeId.BRAMBLE_ENTANGLEMENT)
	)


func get_root_seconds() -> float:
	# Grasping Roots: reaching maximum Entanglement pins an enemy in place. The
	# path is built on holding enemies still, so the base comes with selecting
	# Bramble and the line lengthens it.
	if not has_path():
		return 0.0
	return base_root_seconds + root_seconds_per_level * float(
		progression.get_upgrade_level(PhaseBProgression.UpgradeId.BRAMBLE_GRASPING_ROOTS)
	)


func get_root_immunity_seconds() -> float:
	return root_immunity_seconds


func get_repulsion_pixels() -> float:
	if not has_path():
		return 0.0
	return base_repulsion_pixels + repulsion_pixels_per_level * float(
		progression.get_upgrade_level(PhaseBProgression.UpgradeId.BRAMBLE_REPULSION)
	)


func apply_modifiers(root_network_bonus: float) -> void:
	# Bramble's rules live in the field and the combat loop, so applying the path
	# means handing both of them the run's current numbers.
	var enabled := has_path()
	territory_field.set_bramble_modifiers(enabled, get_resistance_multiplier())
	combat.set_bramble_modifiers(
		enabled,
		get_slow_fraction(),
		get_ensnare_multiplier(),
		get_root_seconds(),
		get_root_immunity_seconds(),
		get_repulsion_pixels(),
		progression.has_active_evolution(PhaseBProgression.EvolutionId.OLD_GROWTH),
		root_network_bonus
	)
	territory_field.set_old_growth_enabled(
		progression.has_active_evolution(PhaseBProgression.EvolutionId.OLD_GROWTH)
	)
