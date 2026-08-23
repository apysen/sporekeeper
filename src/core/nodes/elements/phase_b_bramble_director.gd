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
	return progression.has_path(PhaseBProgression.PathId.BRAMBLE)


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
