## The last stretch of a run: the enemies the schedule saves for late, the modifiers
## that make an elite a different problem rather than a bigger one, and the two ways
## a run can end.
##
## Everything here mutates `prototype.wave_director.elapsed_seconds` to reach a point
## on the timeline the run would otherwise take minutes to arrive at, so it runs last -
## it leaves the clock at the end of the run and the run itself finished.
class_name SmokeEndgame
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	# Late specialists. The design note is explicit that a late enemy must not be an
	# early enemy with a bigger health bar, so each of these has to be reachable from
	# the schedule and has to behave differently once it arrives.
	var waves := prototype.wave_director
	waves.elapsed_seconds = waves.siege_corruptor_intro_seconds
	waves._spawn_pack_sequence = waves.corruptor_pack_cycle - 1
	waves._variant_sequence = maxi(2, int(round(1.0 / waves.siege_corruptor_share))) - 1
	var siege_scheduled := waves._select_regular_role(
		EnemyKinds.Role.HUNTER
	) == EnemyKinds.Role.SIEGE_CORRUPTOR
	report.check(
		siege_scheduled
		and waves.heavy_grazer_intro_seconds > waves.saboteur_intro_seconds
		and waves.rusher_intro_seconds > waves.saboteur_intro_seconds,
		"the late specialists are scheduled, and only after the early roles"
	)

	# The Heavy Grazer's rule change is that Bramble's shove stops answering it. Its
	# slow deliberately still does: one number governing both would make it immune to
	# Bramble rather than immune to being moved.
	prototype.combat.reset_combat()
	var heavy_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HEAVY_GRAZER
	)
	var heavy := prototype.combat._enemies[0]
	for candidate in prototype.combat._enemies:
		if candidate.active and candidate.id == heavy_id:
			heavy = candidate
	var heavy_start := heavy.position
	prototype.combat._begin_knockback(heavy, Vector2.RIGHT, 60.0)
	var heavy_shove := heavy.knockback_speed
	prototype.combat.reset_combat()
	var light_id := prototype.combat.spawn_enemy(EnemyKinds.Role.GRAZER)
	var light := prototype.combat._enemies[0]
	for candidate in prototype.combat._enemies:
		if candidate.active and candidate.id == light_id:
			light = candidate
	prototype.combat._begin_knockback(light, Vector2.RIGHT, 60.0)
	report.check(
		heavy_start.x >= 0.0
		and heavy_shove < light.knockback_speed * 0.2
		and prototype.combat.heavy_grazer_profile.knockback_resistance > 0.5
		and is_equal_approx(prototype.combat.heavy_grazer_profile.territory_action_escalation, 1.0),
		"a Heavy Grazer shrugs off the shove that moves an ordinary Grazer "
			+ "(%.1f against %.1f)" % [heavy_shove, light.knockback_speed]
	)

	# The Siege Corruptor's rule change is that ignoring it is what makes it bad. Its
	# conversion compounds while it is left alone and is reset by being hit, so the
	# condition is genuinely "if ignored" rather than a timer.
	prototype.combat.reset_combat()
	var siege_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.SIEGE_CORRUPTOR
	)
	var siege := prototype.combat._enemies[0]
	for candidate in prototype.combat._enemies:
		if candidate.active and candidate.id == siege_id:
			siege = candidate
	for _siege_action in range(6):
		prototype.combat._perform_enemy_territory_action(siege)
	var escalated := siege.territory_escalation
	prototype.combat._damage_enemy(
		siege,
		1.0,
		CombatDirector.DeathSource.CANE,
		0
	)
	report.check(
		escalated > 1.5
		and escalated <= prototype.combat.siege_corruptor_profile.territory_action_escalation_cap
		and is_equal_approx(siege.territory_escalation, 1.0),
		"an ignored Siege Corruptor compounds its conversion and one hit resets it "
			+ "(reached %.2fx)" % escalated
	)

	# Elite modifiers. Each one has to change a rule rather than a number, and the
	# roll has to be gated until the run has a build worth changing the rules of.
	prototype.combat.reset_combat()
	prototype.combat.set_elite_modifier_pressure(0.0)
	var unmodified := prototype.combat._roll_elite_modifier(
		EnemyKinds.Role.ELITE
	)
	# Read at the final invasion, which is where the escalation curve tops out.
	waves.elapsed_seconds = waves.final_invasion_time_seconds
	prototype.combat.set_elite_modifier_pressure(waves.get_escalation_progress())
	var modified_rolls := 0
	for _roll in range(40):
		if prototype.combat._roll_elite_modifier(
			EnemyKinds.Role.ELITE
		) != EnemyKinds.EliteModifier.NONE:
			modified_rolls += 1
	var hunter_never_modified := prototype.combat._roll_elite_modifier(
		EnemyKinds.Role.HUNTER
	) == EnemyKinds.EliteModifier.NONE
	report.check(
		unmodified == EnemyKinds.EliteModifier.NONE
		and modified_rolls > 20
		and hunter_never_modified
		and is_equal_approx(waves.get_escalation_progress(), 1.0),
		"rule changes are gated behind the run's escalation and never reach the "
			+ "body of a pack (%d of 40 late rolls)" % modified_rolls
	)

	# Unstoppable: cannot be held, can still be slowed.
	prototype.combat.reset_combat()
	prototype.combat.debug_force_elite_modifier(
		EnemyKinds.EliteModifier.UNSTOPPABLE
	)
	var unstoppable_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.ELITE
	)
	var unstoppable := prototype.combat._enemies[0]
	for candidate in prototype.combat._enemies:
		if candidate.active and candidate.id == unstoppable_id:
			unstoppable = candidate
	unstoppable.bramble_ensnare_remaining = 5.0
	unstoppable.movement_speed_multiplier = 0.4
	prototype.combat._advance_elite_modifier(unstoppable, 1.0 / 60.0)
	report.check(
		unstoppable.elite_modifier == EnemyKinds.EliteModifier.UNSTOPPABLE
		and is_equal_approx(unstoppable.bramble_ensnare_remaining, 0.0)
		and is_equal_approx(unstoppable.movement_speed_multiplier, 0.4),
		"an Unstoppable elite breaks a hold and stays slowed"
	)

	# Regenerative: heals, unless the protagonist is the one who hit it. Bramble is
	# deliberately not enough, which is what makes it a change to a build.
	prototype.combat.reset_combat()
	prototype.combat.debug_force_elite_modifier(
		EnemyKinds.EliteModifier.REGENERATIVE
	)
	var regen_id := prototype.combat.spawn_enemy(EnemyKinds.Role.ELITE)
	var regen := prototype.combat._enemies[0]
	for candidate in prototype.combat._enemies:
		if candidate.active and candidate.id == regen_id:
			regen = candidate
	regen.health = regen.maximum_health * 0.5
	var regen_wounded := regen.health
	prototype.combat._advance_elite_modifier(regen, 0.5)
	var regen_healed := regen.health
	prototype.combat._damage_enemy(
		regen,
		1.0,
		CombatDirector.DeathSource.CANE,
		0
	)
	var regen_after_shot := regen.health
	prototype.combat._advance_elite_modifier(regen, 0.5)
	var regen_blocked := is_equal_approx(regen.health, regen_after_shot)
	prototype.combat._damage_enemy(
		regen,
		1.0,
		CombatDirector.DeathSource.BRAMBLE,
		0
	)
	regen.regeneration_block_remaining = 0.0
	prototype.combat._advance_elite_modifier(regen, 0.5)
	report.check(
		regen_healed > regen_wounded
		and regen_blocked
		and regen.health > regen_after_shot - 1.0,
		"a Regenerative elite heals until the protagonist hits it"
	)

	# Volatile: the kill answers back, on the enemies nearby and on the ground.
	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	SmokeFixtures.grow_test_ecosystem(prototype)
	prototype.combat.debug_force_elite_modifier(
		EnemyKinds.EliteModifier.VOLATILE
	)
	var volatile_id := prototype.combat.spawn_enemy(EnemyKinds.Role.ELITE)
	var volatile := prototype.combat._enemies[0]
	for candidate in prototype.combat._enemies:
		if candidate.active and candidate.id == volatile_id:
			volatile = candidate
	var bystander_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		volatile.position + Vector2(10.0, 0.0)
	)
	var bystander := prototype.combat._enemies[0]
	for candidate in prototype.combat._enemies:
		if candidate.active and candidate.id == bystander_id:
			bystander = candidate
	var bystander_health := bystander.health
	var detonations: Array = []
	prototype.combat.elite_detonated.connect(
		func(_position: Vector2, _radius: float) -> void:
			detonations.append(true)
	)
	prototype.combat._damage_enemy(
		volatile,
		volatile.health + 1.0,
		CombatDirector.DeathSource.CANE,
		0
	)
	report.check(
		detonations.size() == 1
		and bystander.health < bystander_health,
		"a Volatile elite detonates on death and damages what is standing near it"
	)
	prototype.combat.reset_combat()
	prototype.wave_director.elapsed_seconds = prototype.wave_director.final_invasion_time_seconds
	prototype.debug_advance_time(
		prototype.wave_director.cleanup_time_seconds
		- prototype.wave_director.final_invasion_time_seconds
	)
	report.check(
		prototype.wave_director.cleanup_started,
		"the timeline enters its cleanup phase"
	)
	# Leave a hostile standing as the clock runs out: the timeline ending must not
	# hand the player a win while anything is still alive.
	prototype.combat.spawn_enemy(EnemyKinds.Role.HUNTER)
	prototype.advance_run(
		prototype.wave_director.run_duration_seconds
		- prototype.wave_director.cleanup_time_seconds
	)
	var survivors_at_time_out := prototype.combat.get_active_enemy_count()
	# The HUD refreshes on its own cadence, which is not what this check is about.
	prototype._update_hud()
	report.check(
		prototype.wave_director.is_complete()
		and survivors_at_time_out > 0
		and prototype.get_run_state() == RunRoot.RunState.RUNNING
		and prototype.status_label.text.contains("CLEAR THE FIELD"),
		"the clock running out leaves the run going while hostiles are still standing"
	)
	prototype.combat.debug_kill_all()
	# The killing blow can hand the player a level, and a pending draft holds the
	# run open until it is taken; victory lands on the far side of that choice.
	for _final_frame in range(8):
		# Any open panel is answered, not just a draft: victory lands on the far side
		# of every choice the run is still holding out for.
		if prototype.choice_panel.visible:
			prototype._choose_displayed_option(0)
		prototype.advance_run(1.0 / 60.0)
		if prototype.get_run_state() != RunRoot.RunState.RUNNING:
			break
	report.check(
		prototype.combat.get_active_enemy_count() == 0
		and prototype.get_run_state() == RunRoot.RunState.VICTORY,
		"clearing the last hostiles after the timeline ends produces victory"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.apply_damage(prototype.player.get_max_health() * 2.0)
	report.check(
		prototype.get_run_state() == RunRoot.RunState.DEFEAT,
		"losing all player HP ends the run immediately"
	)
