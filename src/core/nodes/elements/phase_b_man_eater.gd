class_name PhaseBManEater
extends Node2D

## Man-Eater: the Legendary relic that eats a horde.
##
## Carnivory used to be a Path, which meant Maws had to answer every question a
## twelve-minute build asks — how many, how durable, how they reposition, what
## happens when they are swarmed, how four upgrade lines and five Evolutions scale
## them. None of that made the fantasy better. The fantasy was always one moment:
## a giant plant erupts out of the Green and eats a mob.
##
## So nothing here persists. Enemies standing on Green build Hunger; when it fills,
## the ground bulges under the densest cluster, the jaws come up, they close, and
## the whole thing goes back underground. There is no Maw to kill, no capacity to
## manage, and no AI standing around between meals.
##
## The event is physical on both sides: Green is pulled inward before the eruption
## and thrown back outward afterward, and what the Maw swallows returns to the
## ecosystem as Plant Mass. Enemies invade Green, Green gets hungry, the Plant eats
## them, and the enemies become more Plant.

signal hunger_changed(hunger: float, threshold: float)
signal telegraphed(local_position: Vector2)
signal devoured(local_position: Vector2, swallowed: int, damaged: int)
signal status_requested(message: String)

enum State {
	## Held but not yet fed enough to matter.
	DORMANT,
	## The ground is bulging and the Green around it is being drawn in.
	TELEGRAPHING,
	## The jaws are closed and the Maw is sinking back out of sight.
	RETRACTING,
}

@export_group("Collaborators")
## Authoritative field the Maw pulls Green out of and splatters back into.
@export var territory_field: TerritoryField
## Overlay used for the visible feeding burst the meal turns into.
@export var overlay: TerritoryPrototypeOverlay
## Combat component supplying enemy positions and taking the Bite's damage.
@export var combat: PhaseBCombatDirector
## Progression component that reports whether the run holds the relic.
@export var progression: PhaseBProgression

@export_group("Hunger")
## Hunger added per second by one enemy standing on the run's Green. One enemy
## takes the full threshold; a horde takes seconds. Late invasions are supposed to
## set this relic off constantly.
@export_range(0.0, 10.0, 0.05) var hunger_per_enemy_second := 1.0
## Enemy-seconds of Hunger that summon the Maw.
@export_range(1.0, 300.0, 1.0) var hunger_threshold := 30.0
## Highest Hunger one second may add however many bodies are standing on Green, so
## a late horde cannot drive the relic past the point of being readable.
@export_range(1.0, 60.0, 0.5) var maximum_hunger_per_second := 12.0
## Seconds after a meal before Hunger begins accumulating again.
@export_range(0.0, 30.0, 0.1) var feeding_lockout_seconds := 2.50

@export_group("The Bite")
## Seconds the ground bulges before the jaws close, so the Maw is a battlefield
## event the player can read and enemies can walk out of.
@export_range(0.05, 3.0, 0.05) var telegraph_seconds := 0.70
## Pixel radius the jaws close over.
@export_range(20.0, 400.0, 2.0) var jaw_radius_pixels := 132.0
## Enemies one Bite may catch.
@export_range(1, 32, 1) var maximum_prey := 8
## Damage the Bite deals to anything it closes on. Normal enemies caught inside
## the jaws are swallowed outright rather than chipped.
@export_range(10.0, 4000.0, 10.0) var bite_damage := 900.0
## Share of the Bite an Elite takes. Elites are hurt badly and never swallowed.
@export_range(0.0, 2.0, 0.05) var elite_damage_share := 0.55
## Share of the Bite a boss takes. A boss is bitten, never eaten.
@export_range(0.0, 2.0, 0.05) var boss_damage_share := 0.30
## Fraction of the jaw radius inside which a normal enemy is deep enough in the
## mouth to be swallowed whole.
@export_range(0.1, 1.0, 0.05) var swallow_radius_share := 0.85
## Pixels a caught enemy is dragged toward the throat before the jaws close.
@export_range(0.0, 400.0, 5.0) var swallow_pull_pixels := 46.0

@export_group("Physical Response")
## Green Mass drawn inward per second while the ground bulges.
@export_range(0.0, 400.0, 1.0) var contraction_mass_per_second := 26.0
## Green Mass thrown back out per enemy the Maw actually swallowed.
@export_range(0.0, 200.0, 1.0) var splatter_mass_per_meal := 22.0
## Outward pressure the same splatter carries, which is what spreads the meal.
@export_range(0.0, 200.0, 1.0) var splatter_pressure_per_meal := 9.0
## Seconds the jaws stay visible after closing, before the Maw is gone entirely.
@export_range(0.05, 3.0, 0.05) var retract_seconds := 0.55

@export_group("Targeting")
## Radius in pixels used to weigh how good a cluster of enemies is to bite.
@export_range(20.0, 500.0, 5.0) var cluster_radius_pixels := 118.0
## Control above which ground counts as the run's own Green for both Hunger and
## for where the Maw may erupt.
@export_range(0.0, 1.0, 0.01) var green_control_threshold := 0.12

var _state := State.DORMANT
var _hunger := 0.0
var _timer := 0.0
var _lockout := 0.0
var _site := Vector2(-1.0, -1.0)
var _meals := 0
var _swallowed_total := 0
var _pulse := 0.0


func _ready() -> void:
	assert(territory_field != null, "PhaseBManEater requires TerritoryField")
	assert(combat != null, "PhaseBManEater requires PhaseBCombatDirector")
	assert(progression != null, "PhaseBManEater requires PhaseBProgression")
	reset_man_eater()


func reset_man_eater() -> void:
	_state = State.DORMANT
	_hunger = 0.0
	_timer = 0.0
	_lockout = 0.0
	_site = Vector2(-1.0, -1.0)
	_meals = 0
	_swallowed_total = 0
	_pulse = 0.0
	queue_redraw()


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	if not is_held():
		if _hunger > 0.0 or _state != State.DORMANT:
			reset_man_eater()
		return
	_pulse += delta
	match _state:
		State.DORMANT:
			_advance_hunger(delta)
		State.TELEGRAPHING:
			_advance_telegraph(delta)
		State.RETRACTING:
			_timer -= delta
			if _timer <= 0.0:
				_state = State.DORMANT
				_site = Vector2(-1.0, -1.0)
	queue_redraw()


func is_held() -> bool:
	return progression.has_relic(PhaseBRelicCatalog.Id.MAN_EATER)


func _advance_hunger(delta: float) -> void:
	# Hunger is enemy-seconds spent standing on Green and nothing more. One enemy
	# needs the whole threshold; a pack of five needs a fifth of it; an invasion
	# sets the relic off almost as fast as it arrives.
	if _lockout > 0.0:
		_lockout = maxf(0.0, _lockout - delta)
		return
	var feeders := 0
	for position in combat.get_active_enemy_positions():
		if territory_field.get_control_at_local(position) > green_control_threshold:
			feeders += 1
	if feeders <= 0:
		return
	var gain := minf(
		hunger_per_enemy_second * float(feeders),
		maximum_hunger_per_second
	) * delta
	_hunger += gain
	hunger_changed.emit(_hunger, hunger_threshold)
	if _hunger < hunger_threshold:
		return
	var site := _find_densest_cluster()
	if site.x < 0.0:
		# Nothing worth eating stands on Green just now. The Hunger keeps, so the
		# Maw takes the next group instead of wasting itself on empty ground.
		_hunger = hunger_threshold
		return
	_begin_telegraph(site)


func _begin_telegraph(site: Vector2) -> void:
	_state = State.TELEGRAPHING
	_site = site
	_timer = telegraph_seconds
	_hunger = 0.0
	telegraphed.emit(site)
	status_requested.emit("MAN-EATER — something enormous is coming up under them.")


func _advance_telegraph(delta: float) -> void:
	_timer -= delta
	# The ground gathers itself before it opens: Green around the site is drawn
	# inward, which is the tell as much as the bulge is.
	if contraction_mass_per_second > 0.0:
		territory_field.queue_maturity_support(
			_site,
			contraction_mass_per_second * delta * 0.01,
			1.0
		)
	if swallow_pull_pixels > 0.0:
		combat.pull_enemies_toward(
			_site,
			jaw_radius_pixels,
			swallow_pull_pixels * delta / maxf(0.05, telegraph_seconds)
		)
	if _timer > 0.0:
		return
	_chomp()


func _chomp() -> void:
	var caught := _collect_prey()
	var damaged := 0
	var before := combat.get_active_enemy_count()
	for enemy_id in caught:
		# A normal enemy inside the jaws is not chipped down, it is eaten. Elites
		# are hurt badly and bosses are bitten, and neither is ever swallowed.
		var share := 1.0
		var role := combat.get_enemy_role(enemy_id)
		if role == PhaseBCombatDirector.EnemyRole.BOSS:
			share = boss_damage_share
		elif role == PhaseBCombatDirector.EnemyRole.ELITE:
			share = elite_damage_share
		else:
			damaged += 1
		combat.damage_enemy_by_id(
			enemy_id,
			bite_damage * share,
			PhaseBCombatDirector.DeathSource.MAN_EATER
		)
	# What went down the throat is whatever stopped existing when the jaws shut.
	var swallowed := maxi(0, before - combat.get_active_enemy_count())
	damaged = maxi(0, caught.size() - swallowed)
	_meals += 1
	_swallowed_total += swallowed
	_state = State.RETRACTING
	_timer = retract_seconds
	_lockout = feeding_lockout_seconds
	_spit_the_meal(swallowed)
	devoured.emit(_site, swallowed, damaged)
	if swallowed > 0:
		status_requested.emit(
			"MAN-EATER — %d swallowed whole, and the Green takes what is left."
			% swallowed
		)
	else:
		status_requested.emit("MAN-EATER — the jaws close on a survivor.")


func _spit_the_meal(swallowed: int) -> void:
	# What it ate becomes Plant. The loop closes: enemies invade Green, Green gets
	# hungry, the Plant eats them, and the enemies come back as more Plant.
	if swallowed <= 0:
		return
	# A Bloom command is the field's own local injection, so the meal comes back as
	# Green through the same path every other Plant event uses. The bigger the
	# mouthful, the heavier the splatter.
	var meal := float(swallowed)
	territory_field.queue_bloom(
		_site,
		1.0 + splatter_mass_per_meal * meal * 0.01,
		1.0 + splatter_pressure_per_meal * meal * 0.01,
		1.6,
		1.0 + meal * 0.05
	)
	if overlay != null:
		overlay.spawn_bloom(_site)
	combat.play_plant_explosion_sfx()


func _collect_prey() -> PackedInt32Array:
	# Closest first, so a full mouth takes the bodies actually inside the jaws.
	var candidates: Array = []
	for enemy_id in combat.get_active_enemy_ids():
		var position := combat.get_enemy_position(enemy_id)
		var distance := position.distance_to(_site)
		if distance > jaw_radius_pixels:
			continue
		candidates.append([distance, enemy_id])
	candidates.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var caught := PackedInt32Array()
	for entry in candidates:
		if caught.size() >= maximum_prey:
			break
		caught.append(int(entry[1]))
	return caught


func _find_densest_cluster() -> Vector2:
	# The best meal, not the nearest one: every enemy standing on Green is scored
	# by how many others stand with it, and the Maw comes up under the winner.
	var best_position := Vector2(-1.0, -1.0)
	var best_score := 0
	var radius_squared := cluster_radius_pixels * cluster_radius_pixels
	var positions := combat.get_active_enemy_positions()
	for candidate in positions:
		if territory_field.get_control_at_local(candidate) <= green_control_threshold:
			continue
		var score := 0
		for other in positions:
			if candidate.distance_squared_to(other) <= radius_squared:
				score += 1
		if score > best_score:
			best_score = score
			best_position = candidate
	return best_position


func get_hunger() -> float:
	return _hunger


func get_hunger_fraction() -> float:
	return clampf(_hunger / maxf(0.01, hunger_threshold), 0.0, 1.0)


func get_state() -> int:
	return _state


func get_site() -> Vector2:
	return _site


func get_meal_count() -> int:
	return _meals


func get_swallowed_count() -> int:
	return _swallowed_total


func get_lockout_remaining() -> float:
	return _lockout


func _draw() -> void:
	if _site.x < 0.0:
		return
	match _state:
		State.TELEGRAPHING:
			_draw_telegraph()
		State.RETRACTING:
			_draw_jaws()


func _draw_telegraph() -> void:
	# The ground swells and the soil is drawn toward the middle. What is about to
	# be inside the mouth is exactly what the ring encloses.
	var progress := 1.0 - clampf(_timer / maxf(0.05, telegraph_seconds), 0.0, 1.0)
	var radius := jaw_radius_pixels * (0.55 + 0.45 * progress)
	draw_circle(_site, radius, Color(0.16, 0.30, 0.12, 0.20 + 0.35 * progress))
	draw_arc(
		_site,
		radius,
		0.0,
		TAU,
		48,
		Color(Color("b6ff6a"), 0.35 + 0.5 * progress),
		2.0 + 2.0 * progress,
		true
	)
	# Soil creases converging on the throat.
	var creases := 10
	for index in range(creases):
		var angle := TAU * float(index) / float(creases) + _pulse * 0.4
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(
			_site + direction * radius,
			_site + direction * radius * (0.45 - 0.25 * progress),
			Color(0.55, 0.95, 0.45, 0.25 + 0.4 * progress),
			1.5 + progress,
			true
		)


func _draw_jaws() -> void:
	# Closed, and sinking. The jaws stay a moment so the Bite is something the
	# player watches happen rather than a damage number appearing.
	var sink := clampf(_timer / maxf(0.05, retract_seconds), 0.0, 1.0)
	var radius := jaw_radius_pixels * (0.35 + 0.35 * sink)
	draw_circle(_site, radius, Color(0.06, 0.14, 0.06, 0.92 * sink))
	draw_circle(_site, radius, Color(Color("b6ff6a"), 0.85 * sink), false, 3.0, true)
	var teeth := 12
	for index in range(teeth):
		var angle := TAU * float(index) / float(teeth)
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(
			_site + direction * radius,
			_site + direction * radius * 0.55,
			Color(0.85, 1.0, 0.72, 0.75 * sink),
			2.0,
			true
		)
