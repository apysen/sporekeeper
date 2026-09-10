class_name BrambleDamage
extends RefCounted

## What a stretch of thorns does to one body standing in it, and how fast that body
## tangles.
##
## Both are chip damage resolved per enemy from that enemy's own Entanglement: thorn
## damage is never divided between the enemies sharing a stretch of Green, and there
## is no Thorn Damage upgrade line. The flat and max-health parts are fixed, and
## everything that grows comes from control and the Evolutions.
##
## The authored tuning is copied in once through `configure`, because it is Inspector
## design surface on `CombatDirector` and is not written to during a run. Everything
## that *does* move during a run arrives as an argument instead - the live rate
## multiplier the Evolutions drive, the local zone bonus, and the Root Network
## multiplier, which is the one part that cannot come here at all: it reads the
## territory field and the Root director, and pure rules may not touch a node.

var _contact_damage := 0.0
var _max_health_damage_fraction := 0.0
var _entangled_damage_multiplier := 1.0
var _frontier_damage_bonus := 0.0
var _horde_damage_per_attacker := 0.0
var _horde_damage_maximum_bonus := 0.0
var _entanglement_per_second := 0.0
var _frontier_entanglement_bonus := 0.0


## Copies the authored thorn tuning. The director calls this from its own `_ready`,
## after the scene has set its exports and before anything asks a question.
func configure(
	contact_damage: float,
	max_health_damage_fraction: float,
	entangled_damage_multiplier: float,
	frontier_damage_bonus: float,
	horde_damage_per_attacker: float,
	horde_damage_maximum_bonus: float,
	entanglement_per_second: float,
	frontier_entanglement_bonus: float
) -> void:
	_contact_damage = contact_damage
	_max_health_damage_fraction = max_health_damage_fraction
	_entangled_damage_multiplier = entangled_damage_multiplier
	_frontier_damage_bonus = frontier_damage_bonus
	_horde_damage_per_attacker = horde_damage_per_attacker
	_horde_damage_maximum_bonus = horde_damage_maximum_bonus
	_entanglement_per_second = entanglement_per_second
	_frontier_entanglement_bonus = frontier_entanglement_bonus


## One thorn tick against one body.
##
## A bigger enemy takes more from the same thorns - the max-health share is what keeps
## a hedge relevant against a boss - and a crowd standing in the same thorns makes them
## worse for everyone in it, up to a cap, so a pack cannot be farmed indefinitely by
## standing still.
func get_tick_damage(
	enemy: EnemyState, contact_strength: float, network_multiplier: float
) -> float:
	var base_damage := (
		_contact_damage + enemy.maximum_health * _max_health_damage_fraction
	)
	var entanglement_multiplier := lerpf(
		1.0, _entangled_damage_multiplier, clampf(enemy.entanglement, 0.0, 1.0)
	)
	var frontier_multiplier := (
		1.0 + _frontier_damage_bonus * enemy.bramble_frontier_strength
	)
	var horde_multiplier := 1.0 + minf(
		float(enemy.bramble_horde_count) * _horde_damage_per_attacker,
		_horde_damage_maximum_bonus
	)
	return (
		base_damage
		* contact_strength
		* entanglement_multiplier
		* frontier_multiplier
		* horde_multiplier
		* network_multiplier
	)


## How fast this body tangles while it stands in the thorns.
func get_entanglement_rate(
	enemy: EnemyState,
	contact_strength: float,
	rate_multiplier: float,
	zone_bonus: float,
	network_multiplier: float
) -> float:
	var frontier_bonus := (
		1.0 + _frontier_entanglement_bonus * enemy.bramble_frontier_strength
	)
	return (
		_entanglement_per_second
		* rate_multiplier
		* contact_strength
		* frontier_bonus
		* (1.0 + zone_bonus)
		* network_multiplier
	)
