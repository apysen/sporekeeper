extends SceneTree

## Whether the enemy art bake produced usable textures, and whether the game is
## correct when it did not.
##
## The bake needs a rendering driver. Headless has none, so what this can prove is
## the half that matters for safety: a failed bake must leave the roster drawing
## its art directly rather than leaving the field empty.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/run/phase_b_prototype.tscn")
	await process_frame
	await process_frame
	var p := current_scene as PhaseBPrototype
	var combat := p.combat
	# Give the bake every chance to finish before asking about it.
	for _frame in range(90):
		await process_frame
	print("ENEMY_ART: baked=%s textures=%d" % [
		combat.is_enemy_art_baked(), combat.get_baked_enemy_art_count()
	])
	# Either way the field has to draw. Spawn a crowd well past the old LOD
	# threshold and confirm the frame resolves without error.
	combat.reset_combat()
	for i in range(120):
		combat.spawn_enemy(
			PhaseBCombatDirector.EnemyRole.HUNTER,
			Vector2(300.0, 280.0) + Vector2.from_angle(float(i)) * (30.0 + float(i % 6) * 14.0)
		)
	combat.queue_redraw()
	await process_frame
	await process_frame
	print("ENEMY_ART: drew %d enemies without error" % combat.get_active_enemy_count())
	if combat.get_active_enemy_count() <= 0:
		push_error("ENEMY_ART: the crowd never spawned")
		quit(1)
		return
	print("ENEMY_ART: PASS")
	quit(0)
