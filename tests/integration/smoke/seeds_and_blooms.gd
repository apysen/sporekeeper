## Seeds colonise, Blooms displace.
##
## The pair is checked together because the distinction only exists in contrast: a
## Seed can take ground detached from the organism and a Bloom cannot, a Bloom drives
## an existing frontier outward and a Seed does not. Either one alone would look like
## the other.
class_name SmokeSeedsAndBlooms
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	var kill_position := Vector2(700.0, 360.0)
	for index in range(prototype.spore_director.get_seed_kill_threshold()):
		var enemy_id := prototype.combat.spawn_enemy(
			EnemyKinds.Role.HUNTER,
			kill_position + Vector2(float(index) * 3.0, 0.0)
		)
		prototype.combat.debug_damage_enemy(enemy_id, 10000.0)
	report.check(
		prototype.overlay.get_active_seed_count() == 1,
		"the configured kill threshold creates one Seed at a death site"
	)

	prototype.territory_field.reset_field()
	prototype.overlay.clear_effects()
	var hostile_seed_position := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.82,
		prototype.territory_field.tuning.arena_size.y * 0.52
	)
	var hostile_before := prototype.territory_field.get_control_at_local(hostile_seed_position)
	var explosion_count_before_seed := prototype.combat.get_plant_explosion_sfx_play_count()
	prototype.spore_director.on_seed_germinated(hostile_seed_position, 0)
	report.check(
		prototype.combat.plant_explosion_sfx != null
		and is_equal_approx(
			db_to_linear(prototype.combat._plant_explosion_audio.volume_db),
			0.50
		)
		and prototype.combat._plant_explosion_audio.bus
		== prototype.audio_settings.sfx_bus_name
		and prototype.combat.get_plant_explosion_sfx_play_count()
		== explosion_count_before_seed + 1,
		"Seed germination plays the half-volume explosion SFX on the capped bus"
	)
	SmokeFixtures.step_field(prototype.territory_field, 18)
	var hostile_after := prototype.territory_field.get_control_at_local(hostile_seed_position)
	report.check(
		hostile_before < -prototype.territory_field.tuning.ownership_threshold
		and hostile_after > prototype.territory_field.tuning.ownership_threshold,
		"a combat Seed germinates Green inside strong hostile territory"
	)

	# Seeds colonise, Blooms displace. A Seed must be able to claim ground detached
	# from Plant; a Bloom in that same spot must not.
	prototype.territory_field.reset_field()
	var detached_spot := hostile_seed_position
	var detached_before := prototype.territory_field.get_control_at_local(detached_spot)
	prototype.territory_field.queue_bloom(detached_spot, 4.0, 4.0, 4.0, 1.0)
	prototype.territory_field._apply_pending_commands()
	var detached_bloom_delta := (
		prototype.territory_field.get_control_at_local(detached_spot) - detached_before
	)
	prototype.territory_field.reset_field()
	prototype.territory_field.queue_seed_growth(detached_spot, 1.0, 1.0, 1.0, 1.0)
	prototype.territory_field._apply_pending_commands()
	var detached_seed_delta := (
		prototype.territory_field.get_control_at_local(detached_spot) - detached_before
	)
	report.check(
		detached_seed_delta > 0.0
		and detached_bloom_delta <= 0.0001,
		"a Seed adds mass to ground detached from Plant while a Bloom adds none"
	)

	prototype.territory_field.reset_field()
	var supported_origin := prototype.territory_field.find_player_frontier_near(
		detached_spot
	)
	var supported_before := prototype.territory_field.get_player_percent()
	prototype.territory_field.queue_bloom(supported_origin)
	SmokeFixtures.step_field(prototype.territory_field, 8)
	var supported_after := prototype.territory_field.get_player_percent()
	prototype.territory_field.reset_field()
	SmokeFixtures.step_field(prototype.territory_field, 8)
	var unbloomed_after := prototype.territory_field.get_player_percent()
	report.check(
		supported_origin.x >= 0.0
		and supported_after > unbloomed_after,
		"a Bloom rooted on the frontier drives owned territory outward"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.progression.debug_select_paths(
		Progression.PathId.BLOOM,
		Progression.PathId.SPORE
	)
	prototype.overlay.clear_effects()
	prototype.combat.reset_combat()
	prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		Vector2(
			prototype.territory_field.tuning.arena_size.x * 0.86,
			prototype.territory_field.tuning.arena_size.y * 0.5
		)
	)
	prototype.bloom_director._bloom_remaining = 0.0
	prototype.bloom_director.advance(0.016)
	var planted_bloom := prototype.overlay.get_active_bloom_count() > 0
	var bloom_on_owned_ground := false
	if planted_bloom:
		var bloom_spot := prototype.overlay.get_first_bloom_position()
		bloom_on_owned_ground = (
			prototype.territory_field.get_control_at_local(bloom_spot)
			> prototype.territory_field.tuning.ownership_threshold * 0.5
			or prototype.territory_field.find_player_frontier_near(
				bloom_spot
			).distance_to(bloom_spot) < 24.0
		)
	report.check(
		planted_bloom and bloom_on_owned_ground,
		"an automatic Bloom charges on the player's own frontier rather than at the enemy"
	)
	report.check(
		prototype.bloom_director.bloom_windup_seconds
		< prototype.territory_field.tuning.seed_charge_seconds,
		"a Bloom uses a shorter charge than a Seed's germination delay"
	)
	prototype.overlay.clear_effects()
	prototype.combat.reset_combat()
