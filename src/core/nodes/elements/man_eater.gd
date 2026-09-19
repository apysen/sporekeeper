class_name ManEater
extends Node

## Man-Eater: enemies that graze on the run's Green too long become marked, and
## killing a marked one sprouts a carnivorous plant out of the corpse that bites
## once and dies.
##
## The relic is paid for by the enemy, not by the player: nothing here is aimed,
## charged, or spent. An enemy that eats enough Green earns the mark, and the
## reward arrives wherever that enemy happened to die.
##
## Marking requires actual consumption. A Maw's own bite can kill, and its kills
## can feed generic kill relics, but a bite can never mark anybody -- otherwise a
## single grazer could seed a chain of Maws that never stops.

signal status_requested(message: String)

@export_group("Collaborators")
## Overlay used for the bite's telegraph and its eruption pulse.
@export var overlay: TerritoryPrototypeOverlay
## Combat component supplying grazing reports, kills, and the bite's damage.
@export var combat: CombatDirector
## Progression component consulted for whether the relic is held.
@export var progression: Progression

@export_group("Marking")
## Cumulative seconds an enemy has to spend actively eating Green before it is
## marked. It does not have to be continuous: a grazer that wanders off and comes
## back is still the same grazer.
@export_range(0.1, 30.0, 0.05) var required_consumption_seconds := 2.25

@export_group("The Maw")
## Delay between the marked enemy dying and the plant breaking ground.
@export_range(0.0, 3.0, 0.05) var eruption_delay_seconds := 0.30
## How long the Maw stands before sinking back down.
@export_range(0.1, 10.0, 0.05) var maw_lifetime_seconds := 1.20
## When the jaws close, measured from the eruption.
@export_range(0.0, 5.0, 0.05) var bite_delay_seconds := 0.25
## Reach of that one bite.
@export_range(10.0, 400.0, 1.0) var bite_radius_pixels := 115.0
## Most enemies one bite may take.
@export_range(1, 32, 1) var maximum_bite_targets := 6
## Damage the bite deals to an ordinary enemy.
@export_range(1.0, 2000.0, 1.0) var bite_damage := 80.0
## Shares of that damage taken by the two resistant classes.
@export_range(0.0, 1.0, 0.01) var elite_damage_share := 0.50
@export_range(0.0, 1.0, 0.01) var boss_damage_share := 0.25
## How far the jaws drag prey inward before biting.
@export_range(0.0, 200.0, 1.0) var pull_pixels := 28.0

@export_group("Safety")
## Global cooldown between eruptions, so a wave of marked deaths cannot carpet the
## field with plants on one frame.
@export_range(0.0, 10.0, 0.05) var eruption_cooldown_seconds := 0.75
## Eruptions that may wait behind the cooldown. Deaths past a full queue are lost
## rather than banked: the relic answers the fight in front of the player.
@export_range(0, 8, 1) var maximum_queued_eruptions := 1

## Seconds of grazing each enemy has done, by id. An enemy leaves this the moment
## it is marked, so the dictionary only ever holds enemies still working toward it.
var _consumption := {}
## Marked enemies, by id. The mark lasts until death, whatever the enemy does next.
var _marked := {}
## Maws currently standing, each [position, remaining, bite_remaining, bitten].
var _maws: Array = []
## Corpses owed a Maw, each [position, remaining].
var _pending: Array = []
var _cooldown := 0.0
var _eruptions := 0


func _ready() -> void:
	assert(combat != null, "ManEater requires CombatDirector")
	assert(progression != null, "ManEater requires Progression")
	combat.enemy_ate_green.connect(_on_enemy_ate_green)
	combat.enemy_killed.connect(_on_enemy_killed)
	reset_man_eater()


func reset_man_eater() -> void:
	_consumption.clear()
	_marked.clear()
	_maws.clear()
	_pending.clear()
	_cooldown = 0.0
	_eruptions = 0


func is_held() -> bool:
	return progression.has_relic(RelicCatalog.Id.MAN_EATER)


func get_marked_count() -> int:
	return _marked.size()


func get_active_maw_count() -> int:
	return _maws.size()


func get_eruption_count() -> int:
	return _eruptions


func get_cooldown_remaining() -> float:
	return _cooldown


func is_marked(enemy_id: int) -> bool:
	return _marked.has(enemy_id)


func get_consumption_seconds(enemy_id: int) -> float:
	return float(_consumption.get(enemy_id, 0.0))


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if not is_held():
		# Losing the relic ends the plants that are already up rather than leaving
		# them chewing on their own.
		if not _maws.is_empty() or not _pending.is_empty():
			_maws.clear()
			_pending.clear()
		return
	_advance_pending(delta)
	_advance_maws(delta)


func _advance_pending(delta: float) -> void:
	for index in range(_pending.size() - 1, -1, -1):
		var owed: Array = _pending[index]
		owed[1] = float(owed[1]) - delta
		if float(owed[1]) > 0.0:
			continue
		if _cooldown > 0.0:
			# Still inside the global cooldown. The corpse keeps waiting rather than
			# erupting early or being thrown away.
			continue
		_pending.remove_at(index)
		_erupt(owed[0])


func _erupt(site: Vector2) -> void:
	_cooldown = eruption_cooldown_seconds
	_eruptions += 1
	_maws.append([site, maw_lifetime_seconds, bite_delay_seconds, false])
	if overlay != null:
		overlay.spawn_bloom(site)
	status_requested.emit("MAN-EATER — something with teeth comes up out of the corpse.")


func _advance_maws(delta: float) -> void:
	for index in range(_maws.size() - 1, -1, -1):
		var maw: Array = _maws[index]
		maw[1] = float(maw[1]) - delta
		if not bool(maw[3]):
			maw[2] = float(maw[2]) - delta
			if float(maw[2]) <= 0.0:
				maw[3] = true
				_bite(maw[0])
		if float(maw[1]) <= 0.0:
			_maws.remove_at(index)


func _bite(site: Vector2) -> void:
	# One bite, capped in how many it can take, dragging prey in first so the jaws
	# read as closing on the crowd rather than as a ring of damage.
	var taken := 0
	for enemy_id in combat.get_active_enemy_ids():
		if taken >= maximum_bite_targets:
			break
		if combat.get_enemy_position(enemy_id).distance_to(site) > bite_radius_pixels:
			continue
		if pull_pixels > 0.0:
			combat.knockback_enemy_from(
				enemy_id,
				site + (combat.get_enemy_position(enemy_id) - site) * 2.0,
				pull_pixels
			)
		var damage := bite_damage
		match combat.get_enemy_role(enemy_id):
			EnemyKinds.Role.BOSS, EnemyKinds.Role.HIVE_QUEEN:
				damage *= boss_damage_share
			EnemyKinds.Role.ELITE:
				damage *= elite_damage_share
		# Relic damage: a Maw's kill may feed generic kill relics, and can never
		# mark anybody, because marking only comes from eating Green.
		combat.damage_enemy_by_id(
			enemy_id, damage, CombatDirector.DeathSource.RELIC
		)
		taken += 1
	if overlay != null:
		# One strong bite animation rather than a lingering cloud.
		overlay.spawn_relic_cue(
			TerritoryPrototypeOverlay.RelicCue.BITE,
			site,
			bite_radius_pixels,
			Color("e8746a"),
			Vector2.ZERO,
			false,
			1.0,
			TerritoryPrototypeOverlay.RelicMotif.BURST
		)
	if taken > 0:
		status_requested.emit("MAN-EATER — the jaws close on %d." % taken)


func _on_enemy_ate_green(enemy_id: int, _mass: float, seconds: float) -> void:
	if not is_held() or seconds <= 0.0:
		return
	if _marked.has(enemy_id):
		return
	var eaten := float(_consumption.get(enemy_id, 0.0)) + seconds
	if eaten < required_consumption_seconds:
		_consumption[enemy_id] = eaten
		return
	_consumption.erase(enemy_id)
	_marked[enemy_id] = true
	if overlay != null:
		# The mark has to be obvious: the player is being told which corpse is worth
		# making, and that is only useful before the enemy dies.
		overlay.spawn_relic_cue(
			TerritoryPrototypeOverlay.RelicCue.BAND,
			combat.get_enemy_position(enemy_id),
			22.0,
			Color("e8746a")
		)


func _on_enemy_killed(
	local_position: Vector2,
	_xp_value: int,
	_role: int,
	_death_source: int,
	_chain_depth: int
) -> void:
	var enemy_id := combat.get_last_killed_enemy_id()
	_consumption.erase(enemy_id)
	if not _marked.has(enemy_id):
		return
	_marked.erase(enemy_id)
	if not is_held():
		return
	if _cooldown > 0.0 and _pending.size() >= maximum_queued_eruptions:
		# Cooling down with the queue already full. This death simply does not make
		# a Maw, which is the whole of the relic's crowd-safety rule.
		return
	_pending.append([local_position, eruption_delay_seconds])
