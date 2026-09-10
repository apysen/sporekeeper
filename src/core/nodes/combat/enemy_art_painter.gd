class_name EnemyArtPainter
extends Node2D

## Draws one enemy role's art into a bake viewport.
##
## It owns no art of its own: it asks the combat director to draw the same
## routine the live frame uses, onto this canvas instead of the battlefield. That
## is the whole point -- one definition of what an enemy looks like, used both to
## bake the texture and, if the bake fails, to draw it directly.

var director: CombatDirector
var role := 0
var variant := 0
var body_radius := 10.0
var centre := Vector2.ZERO


func _draw() -> void:
	if director == null:
		return
	var subject := EnemyState.new()
	subject.active = true
	subject.role = role
	# The id is what the art reads for its per-enemy variation, so the variant
	# being baked is fed in through it rather than through a second parameter the
	# art would have to know about.
	subject.id = variant
	subject.position = centre
	subject.radius = body_radius
	# Baked clean: no flash, no escalation, nothing that belongs to a particular
	# enemy in a particular moment. Those stay live overlays.
	subject.hit_flash_remaining = 0.0
	subject.overgrown = false
	subject.territory_escalation = 1.0
	subject.territory_action_escalation_cap = 1.0
	subject.spore_damage_remaining = 0.0
	# Directional roles bake facing +X so the quad can simply be rotated.
	director._draw_enemy(self, subject, Vector2.RIGHT)
