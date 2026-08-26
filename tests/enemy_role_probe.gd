extends SceneTree

## Every role, spawned across the board and rendered, then measured for ink. A role
## with no case in the draw match is simply invisible - it spawns, chases, damages and
## dies without ever appearing - and nothing that checks behaviour would notice.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/run/phase_b_prototype.tscn")
	await process_frame
	await process_frame
	var prototype := current_scene as PhaseBPrototype
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype._set_simulation_paused(true)
	var combat := prototype.combat
	combat.reset_combat()
	var arena := prototype.territory_field.tuning.arena_size
	# Every role the enum declares, so a role added later cannot be forgotten by this
	# check the way it was forgotten by the draw match.
	var roles: Array[int] = []
	for role in range(PhaseBCombatDirector.EnemyRole.size()):
		roles.append(role)
	for index in range(roles.size()):
		combat.spawn_enemy(roles[index], Vector2(
			arena.x * (float(index) + 0.5) / float(roles.size()),
			arena.y * 0.5
		))
	# The Siege Corruptor is drawn part-way through its escalation, because how far
	# along it is is the whole of what its design has to say.
	for enemy in combat._enemies:
		if enemy.active and enemy.role == PhaseBCombatDirector.EnemyRole.SIEGE_CORRUPTOR:
			enemy.territory_action_escalation_cap = maxf(
				2.0,
				enemy.territory_action_escalation_cap
			)
			enemy.territory_escalation = 1.0 + (
				enemy.territory_action_escalation_cap - 1.0
			) * 0.6
	combat.queue_redraw()
	await process_frame
	await process_frame
	var shot := root.get_texture().get_image()
	shot.save_png("res://.godot/enemy_roles.png")
	var render_scale := float(shot.get_width()) / 1280.0
	var report := ""
	var invisible := 0
	for enemy in combat._enemies:
		if not enemy.active:
			continue
		var centre := Vector2(
			(combat.position.x + enemy.position.x) * render_scale,
			(combat.position.y + enemy.position.y) * render_scale
		)
		var painted := 0
		for offset_x in range(-34, 35, 2):
			for offset_y in range(-34, 35, 2):
				var x := int(centre.x) + offset_x
				var y := int(centre.y) + offset_y
				if x < 0 or y < 0 or x >= shot.get_width() or y >= shot.get_height():
					continue
				# A body is anything that is not the ground it stands on.
				var sample := shot.get_pixel(x, y)
				if sample.r > 0.25 and sample.r > sample.g * 1.10:
					painted += 1
		report += "%d:%d " % [enemy.role, painted]
		if painted < 20:
			invisible += 1
	print("ENEMY_PROBE: painted per role -> %s" % report)
	print("ENEMY_PROBE: %s" % ("PASS" if invisible == 0 else "FAIL, %d invisible" % invisible))
	quit(0 if invisible == 0 else 1)
