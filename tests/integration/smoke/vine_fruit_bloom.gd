## The three paths that put something physical on the battlefield: the Vine that
## replaces the Cane's aiming input, the Fruit that plants and travels, and the Bloom
## whose paint has to obey the ground it lands on.
##
## Most of this is about matter rather than damage - where a splat can reach, what a
## wall does to it, what a glob crosses on the way - so it paints its own lanes and
## reads the field's arrays back, rather than watching health bars.
class_name SmokeVineFruitBloom
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	# Base Cane follows facing; Vine deliberately replaces that input with the
	# targetable 90-degree sector holding the most enemies.
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	prototype.combat.reset_combat()
	prototype.player._facing = Vector2.RIGHT
	var cane_target_origin := prototype.player.get_arena_position()
	var base_right_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		cane_target_origin + Vector2(62.0, 0.0)
	)
	var base_up_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		cane_target_origin + Vector2(0.0, -62.0)
	)
	prototype.combat._cane_remaining = 0.0
	prototype.combat.simulate_step(0.0)
	var base_follows_facing := (
		prototype.combat.get_enemy_health(base_right_id)
		< prototype.combat.get_enemy_maximum_health(base_right_id)
		and is_equal_approx(
			prototype.combat.get_enemy_health(base_up_id),
			prototype.combat.get_enemy_maximum_health(base_up_id)
		)
	)
	prototype.combat.reset_combat()
	prototype.progression.debug_select_paths(
		Progression.PathId.VINE,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	var vine_down_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		cane_target_origin + Vector2(0.0, 62.0)
	)
	var vine_cluster_ids := PackedInt32Array()
	for vine_index in range(3):
		vine_cluster_ids.append(prototype.combat.spawn_enemy(
			EnemyKinds.Role.HUNTER,
			cane_target_origin + Vector2(-14.0 + 14.0 * float(vine_index), -66.0)
		))
	prototype.combat._cane_remaining = 0.0
	prototype.combat.simulate_step(0.0)
	# Vine resolves through its simulated body, so the stroke lands over its driving
	# window rather than on the frame it began.
	for _vine_sweep_frame in range(24):
		prototype.combat.simulate_step(1.0 / 60.0)
	var vine_cluster_hit := true
	for vine_enemy_id in vine_cluster_ids:
		vine_cluster_hit = (
			vine_cluster_hit
			and prototype.combat.get_enemy_health(vine_enemy_id)
			< prototype.combat.get_enemy_maximum_health(vine_enemy_id)
		)
	report.check(
		base_follows_facing
		and vine_cluster_hit
		and is_equal_approx(
			prototype.combat.get_enemy_health(vine_down_id),
			prototype.combat.get_enemy_maximum_health(vine_down_id)
		)
		and absf(prototype.combat._cane_visual_facing.angle_to(Vector2.UP)) < 0.22
		and prototype.combat.get_active_projectile_count() == 0,
		"Vine auto-targets the densest valid sector while base Cane follows facing"
	)

	# Fruit uses the same dense-sector choice, but every member of a release owns its
	# roll, art choice, trail spacing, planted fuse, and post-burst cooldown state.
	var adaptations := prototype.adaptation_director
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.FRUIT,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	prototype.player.reset_player()
	prototype.combat.reset_combat()
	adaptations.reset_adaptations()
	var fruit_origin := prototype.player.get_arena_position()
	prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		fruit_origin + Vector2(0.0, 92.0)
	)
	for fruit_cluster_index in range(3):
		prototype.combat.spawn_enemy(
			EnemyKinds.Role.HUNTER,
			fruit_origin + Vector2(-14.0 + 14.0 * float(fruit_cluster_index), -92.0)
		)
	adaptations._begin_normal_fruit_release()
	var aimed_fruit = null
	for candidate in adaptations._fruits:
		if candidate.active and not candidate.dropped_seed:
			aimed_fruit = candidate
			break
	report.check(
		aimed_fruit != null
		and is_equal_approx(aimed_fruit.speed, 300.0)
		and absf(aimed_fruit.velocity.normalized().angle_to(Vector2.UP)) < 0.22,
		"Fruit starts at 300 px/s toward the densest targetable enemy sector"
	)

	# Clear the shared origin stamps, then move three Fruits once in three directions.
	# A shared frame-level trail timer would produce only one branch here; independent
	# segment accumulators must leave a command on every branch.
	prototype.combat.reset_combat()
	adaptations.reset_adaptations()
	prototype.territory_field._commands.clear()
	var trail_fruits: Array = []
	for trail_direction in [Vector2.RIGHT, Vector2.UP, Vector2.LEFT]:
		var trail_fruit = adaptations._spawn_fruit(fruit_origin, trail_direction)
		if trail_fruit != null:
			trail_fruits.append(trail_fruit)
	prototype.territory_field._commands.clear()
	if not trail_fruits.is_empty():
		trail_fruits[0].remaining_distance = 0.0
	for trail_fruit in trail_fruits:
		adaptations._advance_fruit(trail_fruit, 0.12)
	var fruit_origin_cell := prototype.territory_field.local_to_cell(fruit_origin)
	var fruit_trail_right := false
	var fruit_trail_up := false
	var fruit_trail_left := false
	var fruit_trail_splats := 0
	for command in prototype.territory_field._commands:
		if command.kind != TerritoryField.TerritoryCommand.Kind.SPLAT:
			continue
		fruit_trail_splats += 1
		var cell_offset := command.cell_position - fruit_origin_cell
		fruit_trail_right = fruit_trail_right or cell_offset.x > 0.5
		fruit_trail_up = fruit_trail_up or cell_offset.y < -0.5
		fruit_trail_left = fruit_trail_left or cell_offset.x < -0.5
	var zero_distance_counter_did_not_stop: bool = (
		not trail_fruits.is_empty()
		and trail_fruits[0].active
		and trail_fruits[0].speed > 0.0
	)
	report.check(
		trail_fruits.size() == 3
		and fruit_trail_splats >= 3
		and fruit_trail_right
		and fruit_trail_up
		and fruit_trail_left
		and zero_distance_counter_did_not_stop,
		"every Fruit paints its own rolling trail and only zero velocity can stop it"
	)

	# The art choice is run-seeded but genuinely varies per Fruit. Planted ordinary
	# Fruit retains that choice; only the relic offspring uses Fruitseed art.
	adaptations.reset_adaptations()
	adaptations._random.seed = 0xC0FFEE
	var fruit_art_indices := {}
	var fruit_art_indices_valid := true
	for art_roll_index in range(18):
		var art_fruit = adaptations._spawn_fruit(
			fruit_origin,
			Vector2.RIGHT.rotated(0.02 * float(art_roll_index))
		)
		if art_fruit == null:
			continue
		fruit_art_indices[art_fruit.visual_index] = true
		fruit_art_indices_valid = (
			fruit_art_indices_valid
			and art_fruit.visual_index >= 0
			and art_fruit.visual_index < AdaptationDirector.FRUIT_TEXTURES.size()
		)
	report.check(
		fruit_art_indices_valid and fruit_art_indices.size() >= 3,
		"Fruit releases choose visibly varied paintings from the six-asset pool"
	)

	adaptations.reset_adaptations()
	prototype.combat.reset_combat()
	var terminal_position := fruit_origin + Vector2(48.0, 0.0)
	var terminal_enemy_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		terminal_position
	)
	var terminal_health_before := prototype.combat.get_enemy_health(terminal_enemy_id)
	var terminal_fruit = adaptations._spawn_fruit(terminal_position, Vector2.RIGHT)
	var terminal_visual_index: int = (
		terminal_fruit.visual_index if terminal_fruit != null else -1
	)
	if terminal_fruit != null:
		terminal_fruit.speed = 0.0
		terminal_fruit.velocity = Vector2.ZERO
		adaptations._advance_fruit(terminal_fruit, 0.0)
	var planted_fruit = null
	for fruitseed in adaptations._fruitseeds:
		if fruitseed.active and not fruitseed.dropped_seed:
			planted_fruit = fruitseed
			break
	var terminal_keeps_fruit_art: bool = (
		planted_fruit != null
		and planted_fruit.visual_index == terminal_visual_index
		and is_equal_approx(planted_fruit.remaining, adaptations.fruitseed_germination_seconds)
	)
	prototype.territory_field._commands.clear()
	adaptations._update_fruitseeds(adaptations.fruitseed_germination_seconds + 0.01)
	var terminal_queued_green := false
	for command in prototype.territory_field._commands:
		terminal_queued_green = (
			terminal_queued_green
			or command.kind == TerritoryField.TerritoryCommand.Kind.SEED
		)
	report.check(
		terminal_keeps_fruit_art
		and is_equal_approx(
			terminal_health_before - prototype.combat.get_enemy_health(terminal_enemy_id),
			adaptations.fruit_terminal_explosion_damage
		)
		and terminal_queued_green,
		"a stopped Fruit remains planted, then bursts for 10 damage and becomes territory"
	)

	adaptations.reset_adaptations()
	prototype.combat.reset_combat()
	adaptations._begin_normal_fruit_release()
	var first_release_count := adaptations._fruit_release_count
	# The clock starts at the launch. A Fruit still rolling, or still sitting on its
	# planted fuse, no longer holds the next release: that is what made Momentum a
	# cadence tax rather than a range upgrade.
	var cooldown_began_at_launch := is_equal_approx(
		adaptations._fruit_release_remaining,
		adaptations.fruit_release_interval
	)
	var cadence_fruit = null
	for candidate in adaptations._fruits:
		if candidate.active and not candidate.dropped_seed:
			cadence_fruit = candidate
			break
	if cadence_fruit != null:
		cadence_fruit.speed = 0.0
		cadence_fruit.velocity = Vector2.ZERO
		adaptations._advance_fruit(cadence_fruit, 0.0)
	adaptations._update_fruit_release_cadence(adaptations.fruit_release_interval - 0.01)
	var no_early_release := (
		adaptations._fruit_release_count == first_release_count
		and adaptations._has_live_normal_fruit_release()
	)
	adaptations._update_fruit_release_cadence(0.02)
	report.check(
		cooldown_began_at_launch
		and no_early_release
		and adaptations._fruit_release_count == first_release_count + 1,
		"Fruit's release cooldown runs from the launch, not from the previous batch bursting"
	)

	# Weighted Harvest is the exception, because it stores its batch on the Vine tip
	# instead of putting it in the air, and a second arming would overwrite it.
	adaptations.reset_adaptations()
	prototype.combat.reset_combat()
	adaptations._gourdvine_pending_count = 3
	var gourdvine_release_count := adaptations._fruit_release_count
	adaptations._update_fruit_release_cadence(adaptations.fruit_release_interval * 3.0)
	var gourdvine_holds_release := (
		adaptations._fruit_release_count == gourdvine_release_count
	)
	adaptations._gourdvine_pending_count = 0
	adaptations._update_fruit_release_cadence(adaptations.fruit_release_interval + 0.01)
	report.check(
		gourdvine_holds_release
		and adaptations._fruit_release_count == gourdvine_release_count + 1,
		"an armed Weighted Harvest holds the cadence until the sweep spends it"
	)
	adaptations.reset_adaptations()
	prototype.combat.reset_combat()

	# Every Evolution carries exactly one optional upgrade line, offered only to the
	# run that claimed that Evolution. Every pairing across the eight Paths has one;
	# the Pruning pairings used to fall through to no line at all, which left those
	# runs with nothing to draft and their Evolution stuck at its base effect.
	# The count is asserted against the enum rather than written down, so a pairing
	# added later cannot quietly ship without a line.
	var evolution_lines_are_paired := true
	var evolution_line_ids := PackedInt32Array()
	for evolution_id in range(1, Progression.EvolutionId.size()):
		var line_id := Evolutions.get_evolution_upgrade_id(evolution_id)
		if line_id < 0:
			continue
		evolution_lines_are_paired = (
			evolution_lines_are_paired
			and Evolutions.get_upgrade_evolution(line_id) == evolution_id
			and not evolution_line_ids.has(line_id)
		)
		evolution_line_ids.append(line_id)
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.BLOOM,
		Progression.PathId.BRAMBLE
	)
	var line_draftable_unevolved := prototype.progression._is_upgrade_draftable(
		Progression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD
	)
	prototype.progression.debug_complete_evolution_requirements()
	prototype.progression.grant_evolution_if_ready()
	var claimed_evolution_line_level := prototype.progression.get_owned_upgrade_level(
		Progression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD
	)
	var own_line_draftable := prototype.progression._is_upgrade_draftable(
		Progression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD
	)
	var other_line_draftable := prototype.progression._is_upgrade_draftable(
		Progression.UpgradeId.EVOLUTION_ANCIENT_FURY
	)
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD
	] = 2
	var rank_level := prototype.progression.get_evolution_upgrade_level()
	var rank_three_text := prototype.progression.get_upgrade_description(
		Progression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD
	)
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	report.check(
		evolution_lines_are_paired
		and evolution_line_ids.size() == Progression.EvolutionId.size() - 1
		and not line_draftable_unevolved
		and claimed_evolution_line_level == 1
		and own_line_draftable
		and not other_line_draftable
		and rank_level == 2
		and rank_three_text.contains("Barbed Blast"),
		"each Evolution has one optional line, drafted only by the run holding it"
	)

	# A line is not implemented because it exists in the enum. Every rank of every line
	# has to name what it does, because that text is what the draft shows the player, and
	# a blank rank is a rank nobody wrote.
	var blank_ranks := PackedStringArray()
	for evolution_id in range(1, Progression.EvolutionId.size()):
		var line_id := Evolutions.get_evolution_upgrade_id(evolution_id)
		if line_id < 0:
			continue
		for rank in range(1, prototype.progression.maximum_upgrade_level + 1):
			if prototype.evolutions.get_evolution_upgrade_rank_description(
				line_id, rank
			).is_empty():
				blank_ranks.append("%s r%d" % [
					Progression.get_upgrade_name(line_id),
					rank,
				])
	report.check(
		blank_ranks.is_empty(),
		"every Evolution rank says what it does (%s)" % (
			"all named" if blank_ranks.is_empty() else ", ".join(blank_ranks)
		)
	)

	# Spore Burst: germination itself has to hurt. Checked by damage rather than by kills
	# so the check survives any retune of how hard it hits.
	prototype.progression.reset_progression()
	prototype.combat.reset_combat()
	var burst_seat := prototype.player.get_arena_position()
	var burst_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		burst_seat + Vector2(18.0, 0.0)
	)
	var burst_full := prototype.combat.get_enemy_health(burst_id)
	prototype.spore_director.on_seed_germinated(burst_seat, 0)
	var burst_unrelicked := prototype.combat.get_enemy_health(burst_id)
	prototype.progression._owned_relics[RelicCatalog.Id.SPORE_BURST] = 1
	prototype.spore_director.on_seed_germinated(burst_seat, 0)
	var burst_relicked := prototype.combat.get_enemy_health(burst_id)
	report.check(
		burst_id >= 0
		and is_equal_approx(burst_unrelicked, burst_full)
		and burst_relicked < burst_unrelicked,
		"Spore Burst makes germination damage what is standing in it (%.1f to %.1f)"
			% [burst_unrelicked, burst_relicked]
	)
	prototype.combat.reset_combat()
	prototype.progression.reset_progression()

	# Bloom splatter: one eruption resolves into a central splat, gameplay globs,
	# satellites, and streaks rather than into a single expanding circle.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.BLOOM,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	var splatter_origin := SmokeFixtures.find_player_frontier(prototype.territory_field)
	var bloom := prototype.bloom_director
	bloom.reset_director()
	prototype.territory_field._commands.clear()
	bloom.on_bloom_detonated(splatter_origin, 0)
	# The central surge is immediate; everything else is now in the air.
	var immediate_kinds := {}
	for command in prototype.territory_field._commands:
		immediate_kinds[command.kind] = int(immediate_kinds.get(command.kind, 0)) + 1
	var central_splats := int(immediate_kinds.get(
		TerritoryField.TerritoryCommand.Kind.BLOOM, 0
	))
	var splats_before_flight := int(immediate_kinds.get(
		TerritoryField.TerritoryCommand.Kind.SPLAT, 0
	))
	var globs_in_flight := bloom.get_active_glob_count()
	for _flight_step in range(120):
		bloom.advance(1.0 / 60.0)
	var queued_kinds := {}
	for command in prototype.territory_field._commands:
		queued_kinds[command.kind] = int(queued_kinds.get(command.kind, 0)) + 1
	var thrown_splats := int(queued_kinds.get(
		TerritoryField.TerritoryCommand.Kind.SPLAT, 0
	))
	report.check(
		central_splats == 1
		and globs_in_flight > 1
		and splats_before_flight == 0
		and thrown_splats > 1
		and bloom.get_active_glob_count() == 0
		and prototype.overlay.get_active_splatter_count() == 1,
		"a Bloom throws its material and the splats are laid down where it lands"
	)

	# The point of throwing it: what the paint crosses decides where it ends up. The
	# same throw into a thick invasion falls short of one across the run's own Green.
	var field := prototype.territory_field
	var lane_y := field.tuning.arena_size.y * 0.5
	var green_origin := Vector2(field.tuning.arena_size.x * 0.12, lane_y)
	var hostile_origin := Vector2(field.tuning.arena_size.x * 0.60, lane_y)
	SmokeFixtures.paint_lane(field, green_origin, 1.0)
	SmokeFixtures.paint_lane(field, hostile_origin, -1.0)
	field.recalculate_metrics_now()

	var green_distance := SmokeFixtures.throw_one_glob(bloom, green_origin)
	var hostile_distance := SmokeFixtures.throw_one_glob(bloom, hostile_origin)
	report.check(
		green_distance > 0.0
		and hostile_distance > 0.0
		and green_distance > hostile_distance * 1.15,
		"thrown material carries further over the run's own Green than into hostile ground"
	)

	# Paint does not come apart into equal lumps. Drag acts on a droplet's
	# cross-section and is resisted by its Mass, so the fine mist leaves fastest and
	# stops almost at once while the heavy globs lumber out and carry.
	var mist_speed := 0.0
	var mist_range := 0.0
	var lump_speed := 0.0
	var lump_range := 0.0
	for entry in [[3.0, 0.108], [22.0, 42.592]]:
		for glob in bloom._globs:
			glob.active = false
		bloom._launch_glob(
			Vector2(120.0, field.tuning.arena_size.y * 0.5),
			Vector2.RIGHT,
			float(entry[0]),
			float(entry[1]),
			1.0,
			1.0,
			0
		)
		var launch_speed := 0.0
		for glob in bloom._globs:
			if glob.active:
				launch_speed = glob.velocity.length()
		for _fly in range(600):
			bloom.advance(1.0 / 60.0)
			if bloom.get_active_glob_count() == 0:
				break
		var reach := 0.0
		for glob in bloom._globs:
			reach = maxf(reach, glob.travelled)
		if float(entry[0]) < 10.0:
			mist_speed = launch_speed
			mist_range = reach
		else:
			lump_speed = launch_speed
			lump_range = reach
	# The ratio itself depends on what the droplets happen to cross, so the claim
	# under test is the ordering: the blast throws the mist faster and the heavy
	# glob still outruns it, because drag is resisted by Mass.
	report.check(
		mist_speed > lump_speed
		and lump_range > mist_range * 1.5,
		"fine mist is thrown fastest and falls short; heavy globs leave slower and carry"
	)

	# The same explosion sample fired at one pitch several times a second is what
	# makes a good effect grating, so each detonation is detuned inside a narrow band.
	var explosion_pitches := PackedFloat32Array()
	for _blast in range(12):
		prototype.combat.play_plant_explosion_sfx()
		explosion_pitches.append(prototype.combat.get_last_explosion_pitch_scale())
	var lowest := 9.0
	var highest := 0.0
	for pitch in explosion_pitches:
		lowest = minf(lowest, pitch)
		highest = maxf(highest, pitch)
	report.check(
		highest > lowest
		and lowest >= prototype.combat.explosion_minimum_pitch_scale
		and highest <= prototype.combat.explosion_maximum_pitch_scale
		and prototype.combat.explosion_maximum_pitch_scale
		/ prototype.combat.explosion_minimum_pitch_scale < 1.5,
		"every explosion detunes itself inside a band narrow enough to stay one sound"
	)

	# Something arriving with momentum dents established ground whatever it has
	# matured into. Growing into an old front is rightly hard; hitting one is a
	# different act, and without this a Bloom thrown at a mature red front was
	# absorbed by it.
	var slab_centre := Vector2(
		field.tuning.arena_size.x * 0.62,
		field.tuning.arena_size.y * 0.5
	)
	var slab_remaining := PackedInt32Array()
	for impact_break in [0.0, 2.0]:
		field.reset_field()
		field.step_simulation()
		var slab_cell := field.local_to_cell(slab_centre)
		var slab_width := int(field.tuning.field_size.x)
		for y in range(int(field.tuning.field_size.y)):
			for x in range(slab_width):
				if absf(float(y) - slab_cell.y) > 10.0 or absf(float(x) - slab_cell.x) > 10.0:
					continue
				var index := y * slab_width + x
				if field._claimable_mask[index] == 0:
					continue
				field._control[index] = -1.0
				field._maturity[index] = 1.0
		# A deliberately weak splat, so what shows is the dent and not the Mass.
		field.queue_splat(slab_centre, 2.0, 0.5, 6.0, 1.0, Vector2.RIGHT, 1.0, float(impact_break))
		field.step_simulation()
		var hostile := 0
		for y in range(int(field.tuning.field_size.y)):
			for x in range(slab_width):
				if absf(float(y) - slab_cell.y) > 10.0 or absf(float(x) - slab_cell.x) > 10.0:
					continue
				var index := y * slab_width + x
				if field._claimable_mask[index] == 0:
					continue
				if field._control[index] < -0.2:
					hostile += 1
		slab_remaining.append(hostile)
	report.check(
		slab_remaining.size() == 2
		and slab_remaining[0] > 400
		and slab_remaining[1] < slab_remaining[0] - 40,
		"an impact dents fully mature hostile ground that growth alone cannot touch"
	)

	# And the same thing end to end, which is what was actually broken: the unit
	# case above passed for months while a real Bloom still left no mark, because a
	# glob stamped its landing at the radius it had been flying at. Paint does not
	# do that — it flattens out across the surface it hits — and until it did, nine
	# droplet-sized footprints could not add up to a hole anyone could see. The
	# threshold is what an uninvested Bloom manages; the run's Mass line grows it.
	var bloom_dent := PackedInt32Array()
	for throw_bloom in [false, true]:
		field.reset_field()
		for _settle in range(10):
			field.step_simulation()
		var mature_front := 0
		for index in range(int(field.tuning.field_size.x) * int(field.tuning.field_size.y)):
			if field._claimable_mask[index] == 0 or field._control[index] >= -0.2:
				continue
			field._maturity[index] = 1.0
			mature_front += 1
		prototype.bloom_director.reset_director()
		if throw_bloom:
			prototype.bloom_director.on_bloom_detonated(
				field.find_player_frontier_near(prototype.player.get_arena_position()), 0
			)
		for _step in range(180):
			prototype.bloom_director.advance(1.0 / 60.0)
		field.step_simulation()
		var still_hostile := 0
		for index in range(int(field.tuning.field_size.x) * int(field.tuning.field_size.y)):
			if field._claimable_mask[index] != 0 and field._control[index] < -0.2:
				still_hostile += 1
		bloom_dent.append(mature_front - still_hostile)
	report.check(
		bloom_dent.size() == 2 and bloom_dent[0] == 0 and bloom_dent[1] > 40,
		"a thrown Bloom punches a visible hole in a fully mature hostile front"
	)

	# Basalt and the arena wall are surfaces, not sinks. Thrown paint used to stop
	# dead the instant it touched one, so the glob simply blinked out at the rock.
	# It should hit, lose what was driving into the face, and let what was running
	# along the face carry it down the surface until it pools against it.
	var wall_width := int(field.tuning.field_size.x)
	var wall_height := int(field.tuning.field_size.y)
	var wall_pixels_per_cell := field.tuning.arena_size.x / float(wall_width)
	var face_x := -1
	var face_y := -1
	for probe_y in range(int(wall_height * 0.3), int(wall_height * 0.7)):
		for probe_x in range(int(wall_width * 0.3), wall_width - 4):
			if (
				field._claimable_mask[probe_y * wall_width + probe_x] == 0
				and field._claimable_mask[probe_y * wall_width + probe_x - 6] != 0
			):
				face_x = probe_x
				face_y = probe_y
				break
		if face_x >= 0:
			break
	var face_travel := PackedFloat32Array()
	var face_gap := PackedFloat32Array()
	for allowed_contacts in [0, prototype.bloom_director.maximum_wall_contacts]:
		var previous_contacts := prototype.bloom_director.maximum_wall_contacts
		prototype.bloom_director.maximum_wall_contacts = int(allowed_contacts)
		prototype.bloom_director.reset_director()
		prototype.bloom_director._launch_glob(
			Vector2(
				(float(face_x) - 7.0 + 0.5) * wall_pixels_per_cell,
				(float(face_y) + 0.5) * wall_pixels_per_cell
			),
			Vector2.RIGHT, 22.0, 0.5, 1.0, 1.6, 0
		)
		var thrown = null
		for candidate in prototype.bloom_director._globs:
			if candidate.active:
				thrown = candidate
				break
		var contact_point := Vector2.ZERO
		var ran := 0.0
		for _step in range(400):
			var previous_position: Vector2 = thrown.position
			var contacts_before: int = thrown.wall_contacts
			prototype.bloom_director.advance(1.0 / 60.0)
			if thrown.wall_contacts > contacts_before and contact_point == Vector2.ZERO:
				contact_point = previous_position
			if contact_point != Vector2.ZERO and thrown.active:
				ran += thrown.position.distance_to(previous_position)
			if not thrown.active:
				break
		face_travel.append(ran)
		var rest := field.local_to_cell(thrown.position)
		var nearest := 999.0
		for offset_y in range(-6, 7):
			for offset_x in range(-6, 7):
				var sample_x := clampi(int(rest.x) + offset_x, 0, wall_width - 1)
				var sample_y := clampi(int(rest.y) + offset_y, 0, wall_height - 1)
				if field._claimable_mask[sample_y * wall_width + sample_x] == 0:
					nearest = minf(nearest, Vector2(offset_x, offset_y).length())
		face_gap.append(nearest)
		prototype.bloom_director.maximum_wall_contacts = previous_contacts
	report.check(
		face_x >= 0 and face_travel[0] <= 0.01 and face_travel[1] > 50.0,
		"paint thrown at an obstacle runs down its face instead of stopping dead"
	)
	report.check(
		face_gap[1] <= 3.0,
		(
			"paint running down a face stays against it rather than glancing away "
			+ "(gap %.2f -> %.2f cells; travel %.2f -> %.2fpx)"
		) % [face_gap[0], face_gap[1], face_travel[0], face_travel[1]]
	)

	# The scene file is the surface this interface is designed on, so what a node
	# declares is not a preview of the wording - it is the wording. Every line the
	# game prints is that node's own text with named placeholders filled in, so the
	# check is that each literal fragment the scene declares survives into the
	# running label, and that no placeholder survives: one left as typed means the
	# game had no value for a name the editor asked for.
	# The interface is authored across several scenes now - the run scene instances
	# the pause menu, the slot cabinet and the draft panel - so the surface this rule
	# guards is the run scene *and* everything it instances. Walking only the run
	# scene would quietly stop checking most of the wording in the game.
	var declared_texts := {}
	var declared_offsets := {}
	var packed_prototype: PackedScene = load("res://scenes/run/run.tscn")
	var scene_state := packed_prototype.get_state()
	var gather_declared := func(state: SceneState, prefix: String, recurse: Callable) -> void:
		for node_index in range(state.get_node_count()):
			var raw_path := str(state.get_node_path(node_index))
			var node_path := raw_path if prefix.is_empty() else "%s/%s" % [prefix, raw_path]
			if raw_path == ".":
				node_path = prefix
			for property_index in range(state.get_node_property_count(node_index)):
				var name_of := str(state.get_node_property_name(node_index, property_index))
				var value_of = state.get_node_property_value(node_index, property_index)
				if name_of == "text":
					declared_texts[node_path] = str(value_of)
				elif name_of.begins_with("offset_") and typeof(value_of) == TYPE_FLOAT:
					declared_offsets[[node_path, name_of]] = float(value_of)
			var instanced: PackedScene = state.get_node_instance(node_index)
			if instanced != null:
				recurse.call(instanced.get_state(), node_path, recurse)
	gather_declared.call(scene_state, "", gather_declared)
	# Against a fresh run: the placeholders describe a run's opening state, and by
	# this point the suite has drafted paths and populated the choice panel.
	prototype.reset_run()
	prototype._update_hud()
	var literals_of := func(value: String) -> PackedStringArray:
		# The words either side of every {placeholder}, which is what the author
		# controls and what therefore has to reach the screen unchanged.
		var fragments := PackedStringArray()
		var cursor := 0
		while cursor < value.length():
			var opened := value.find("{", cursor)
			if opened < 0:
				fragments.append(value.substr(cursor))
				break
			fragments.append(value.substr(cursor, opened - cursor))
			var closed := value.find("}", opened)
			if closed < 0:
				break
			cursor = closed + 1
		return fragments
	var unauthored_lines := PackedStringArray()
	for node_path in declared_texts.keys():
		if node_path.contains("ChoicePanel"):
			# The draft panel is filled from whatever the run rolls, out of templates
			# exported on the run controller rather than off the node.
			continue
		var declared_node := prototype.get_node_or_null(NodePath(node_path))
		if declared_node == null or not ("text" in declared_node):
			continue
		var printed := str(declared_node.text)
		var declared: String = declared_texts[node_path]
		if not declared.contains("{"):
			# A line with nothing to fill in has to be printed exactly as authored.
			if printed != declared and not printed.is_empty():
				unauthored_lines.append("%s printed %s" % [node_path, printed])
			continue
		if printed.contains("{"):
			unauthored_lines.append("%s left a placeholder: %s" % [node_path, printed])
			continue
		for fragment: String in literals_of.call(declared):
			if not fragment.is_empty() and not printed.contains(fragment):
				unauthored_lines.append(
					"%s dropped %s from %s" % [node_path, fragment, printed]
				)
	report.check(
		declared_texts.size() > 20 and unauthored_lines.is_empty(),
		"every line the game prints is the wording its scene node declares: %s" % (
			", ".join(unauthored_lines)
		)
	)

	# The same rule for layout, not just wording. A tool script that recomputes a
	# child's rect at load silently undoes anything placed by hand in the editor,
	# which is exactly what the drawer's meters did until it was taken out.
	var moved_by_code := PackedStringArray()
	for offset_key in declared_offsets.keys():
		var placed_path: String = offset_key[0]
		var property_name: String = offset_key[1]
		var placed_node := prototype.get_node_or_null(NodePath(placed_path)) as Control
		if placed_node == null:
			continue
		var live_value = placed_node.get(property_name)
		if absf(float(live_value) - float(declared_offsets[offset_key])) > 0.51:
			moved_by_code.append("%s.%s" % [placed_path.get_file(), property_name])
	report.check(
		moved_by_code.is_empty(),
		"nothing moves a control the scene placed by hand"
	)
	if not moved_by_code.is_empty():
		print("    moved by code: %s" % ", ".join(moved_by_code))
	if not unauthored_lines.is_empty():
		print("    lines the game rewrote: %s" % ", ".join(unauthored_lines))

	# A Bloom landing on the run's own established Green must not strip it. The
	# maturity ceiling that keeps newly taken ground rootless was being applied to
	# every player-held cell a splat touched, so firing a Bloom over your own mature
	# territory reset it — the exact opposite of what material settling onto growth
	# should do.
	var maturity_means := PackedFloat32Array()
	var maturity_losses := PackedInt32Array()
	for reinforcement in [0.0, prototype.bloom_director.landing_maturity_reinforcement]:
		var previous_reinforcement := prototype.bloom_director.landing_maturity_reinforcement
		prototype.bloom_director.landing_maturity_reinforcement = float(reinforcement)
		field.reset_field()
		for _settle in range(10):
			field.step_simulation()
		var owned := PackedInt32Array()
		for index in range(int(field.tuning.field_size.x) * int(field.tuning.field_size.y)):
			if field._claimable_mask[index] != 0 and field._control[index] > 0.2:
				field._maturity[index] = 0.80
				owned.append(index)
		prototype.bloom_director.reset_director()
		prototype.bloom_director.on_bloom_detonated(
			field.find_player_frontier_near(prototype.player.get_arena_position()), 0
		)
		for _step in range(180):
			prototype.bloom_director.advance(1.0 / 60.0)
		field.step_simulation()
		var total := 0.0
		var lost := 0
		for index in owned:
			total += field._maturity[index]
			if field._maturity[index] < 0.80 - 0.0001:
				lost += 1
		maturity_means.append(total / maxf(1.0, float(owned.size())))
		maturity_losses.append(lost)
		prototype.bloom_director.landing_maturity_reinforcement = previous_reinforcement
	report.check(
		maturity_losses[0] == 0 and maturity_losses[1] == 0,
		"a Bloom never strips maturity from ground the run already holds"
	)
	report.check(
		maturity_means[1] > maturity_means[0],
		"material landing on established Green thickens it instead"
	)
	# And how well it roots is the run's own Maturation, not a flat number: the
	# ecosystem's capacity to put down roots acting on material the Bloom delivered.
	var reinforcement_before := prototype.bloom_director.get_landing_maturity_reinforcement()
	prototype.metabolism.debug_grant_axis(Metabolism.SystemId.PHOTOSYNTHESIS, 8)
	prototype._apply_progression_modifiers()
	var reinforcement_after := prototype.bloom_director.get_landing_maturity_reinforcement()
	report.check(
		reinforcement_after > reinforcement_before * 1.2,
		"an ecosystem with Maturation behind it roots what a Bloom lands harder"
	)

	# What a Bloom throws is the ecosystem, so a glob landing on a Seed that is
	# already breaking ground settles whether that site establishes. Budgeted per
	# Bloom, and gated on the pairing that makes germination arm a chain at all.
	var inoculation_openings := PackedInt32Array()
	var inoculation_germinations := PackedInt32Array()
	for evolved in [false, true]:
		prototype.progression.debug_select_paths(
			Progression.PathId.BLOOM, Progression.PathId.SPORE
		)
		if evolved:
			prototype.progression.debug_complete_evolution_requirements()
			prototype.progression.grant_evolution_if_ready()
		prototype._apply_progression_modifiers()
		field.reset_field()
		for _settle in range(10):
			field.step_simulation()
		prototype.bloom_director.reset_director()
		# The overlay owns Seeds and holds its effects paused outside a live run, so
		# the harness has to clear it and let it tick for germination to resolve.
		prototype.overlay.clear_effects()
		var was_paused := prototype.overlay.effects_paused
		prototype.overlay.effects_paused = false
		var blast := field.find_player_frontier_near(prototype.player.get_arena_position())
		# A container, because a GDScript lambda captures locals by value and an
		# incremented int would never be seen out here.
		var germinated := PackedInt32Array([0])
		var counter := func(_position: Vector2, _depth: int) -> void:
			germinated[0] += 1
		prototype.overlay.seed_germinated_with_context.connect(counter)
		for ring_index in range(12):
			prototype.overlay.spawn_seed(
				blast + Vector2.from_angle(TAU * float(ring_index) / 12.0) * 110.0, 6.0, 0
			)
		prototype.bloom_director.on_bloom_detonated(blast, 0)
		for _step in range(180):
			prototype.bloom_director.advance(1.0 / 60.0)
			prototype.overlay._process(1.0 / 60.0)
		prototype.overlay.seed_germinated_with_context.disconnect(counter)
		prototype.overlay.effects_paused = was_paused
		inoculation_openings.append(prototype.bloom_director.get_inoculation_openings())
		inoculation_germinations.append(germinated[0])


	report.check(
		inoculation_openings[0] == 0,
		"without the pairing, thrown material does not crack Seeds open"
	)
	# Each generation of a chain gets its own budget, so the total is the budget
	# times the generations the pairing allows — and no more. A cracked Seed joins
	# the chain that cracked it; without that it reported the depth it was planted
	# at, every generation looked like the first, and one Bloom opened the field.
	var inoculation_ceiling := (
		prototype.evolutions.inoculation_seeds_per_bloom
		* (prototype.bloom_director.get_maximum_chain_depth() + 1)
	)
	report.check(
		inoculation_openings[1] >= prototype.evolutions.inoculation_seeds_per_bloom
		and inoculation_openings[1] <= inoculation_ceiling
		and inoculation_germinations[1] > inoculation_germinations[0],
		"thrown material establishes Seeds it lands on, and the chain it starts ends"
	)

	# A wall's corner dims what is behind it rather than deleting it. The old rule
	# was a yes-or-no ray, so one clipped cell erased everything past it and a ridge
	# on a rock shadowed far more than the ridge was worth.
	var rock_x := -1
	var rock_y := -1
	var rock_row := int(field.tuning.field_size.x)
	for y in range(int(field.tuning.field_size.y) / 3, int(field.tuning.field_size.y) * 2 / 3):
		for x in range(rock_row / 3, rock_row * 2 / 3):
			if field._claimable_mask[y * rock_row + x] == 0:
				rock_x = x
				rock_y = y
				break
		if rock_x >= 0:
			break
	var grazed := 0
	var clipped_transmission := 0.0
	var buried_transmission := 1.0
	if rock_x >= 0:
		var source_x := rock_x - 9
		var source_y := rock_y
		for offset in range(1, 12):
			var probe_x := rock_x + offset
			if probe_x >= rock_row:
				break
			if field._is_claimable_line_clear(source_x, source_y, probe_x, rock_y):
				continue
			var through := field._claimable_line_transmission(
				source_x,
				source_y,
				probe_x,
				rock_y,
				field.tuning.obstruction_falloff_per_cell
			)
			if offset <= 2:
				clipped_transmission = maxf(clipped_transmission, through)
			else:
				buried_transmission = minf(buried_transmission, through)
			grazed += 1
	report.check(
		rock_x >= 0
		and grazed > 0
		and clipped_transmission > 0.0
		and buried_transmission <= 0.0,
		"a clipped corner dims growth behind it while solid rock still stops it dead"
	)

	# Paint that arrives with speed does not land as a disc. It runs on along the
	# line it was travelling, so the ground it claims is stretched that way and sits
	# forward of the impact rather than centred on it.
	var footprints := {}
	for entry in [["still", Vector2.ZERO, 1.0], ["thrown", Vector2.RIGHT, 3.0]]:
		field.reset_field()
		for _settle in range(4):
			field.step_simulation()
		var impact := Vector2(
			field.tuning.arena_size.x * 0.78,
			field.tuning.arena_size.y * 0.28
		)
		var width := int(field.tuning.field_size.x)
		var height := int(field.tuning.field_size.y)
		var before := PackedFloat32Array()
		before.resize(width * height)
		for index in range(width * height):
			before[index] = field._control[index]
		field.queue_splat(impact, 30.0, 1.5, 4.0, 3.0, entry[1], float(entry[2]))
		field.step_simulation()
		var cell := field.local_to_cell(impact)
		var forward := -999.0
		var behind := 999.0
		var side := 0.0
		for y in range(height):
			for x in range(width):
				var index := y * width + x
				if field._control[index] - before[index] < 0.01:
					continue
				# The impact's own neighbourhood only: the rest of the field grows on
				# its own and would drown the measurement.
				if absf(float(x) - cell.x) > 16.0 or absf(float(y) - cell.y) > 16.0:
					continue
				forward = maxf(forward, float(x) - cell.x)
				behind = minf(behind, float(x) - cell.x)
				side = maxf(side, absf(float(y) - cell.y))
		footprints[entry[0]] = [forward, behind, side]
	var still_shape: Array = footprints["still"]
	var thrown_shape: Array = footprints["thrown"]
	report.check(
		float(thrown_shape[0]) > float(still_shape[0]) * 2.0
		and float(thrown_shape[0]) - float(thrown_shape[1])
		> float(thrown_shape[2]) * 2.0,
		"a landing runs on along its own travel instead of stamping a circle"
	)

	# Force is the blast's energy rather than its speed, so it arrives as a square
	# root: a much harder bang, not a proportionally longer throw.
	var weak_speed := 0.0
	var strong_speed := 0.0
	for force in [1.0, 4.0]:
		for glob in bloom._globs:
			glob.active = false
		bloom._launch_glob(
			Vector2(120.0, field.tuning.arena_size.y * 0.5),
			Vector2.RIGHT, 10.0, 4.0, 1.0, float(force),
			0
		)
		for glob in bloom._globs:
			if glob.active:
				if force < 2.0:
					weak_speed = glob.velocity.length()
				else:
					strong_speed = glob.velocity.length()
		for glob in bloom._globs:
			glob.active = false
	report.check(
		weak_speed > 0.0
		and is_equal_approx(strong_speed, weak_speed * 2.0),
		"Bloom Force feeds the blast as energy, so four times the Force is twice the throw"
	)

	# The focus ring is a controller affordance: a mouse player should never be
	# shown a white box parked on a button.
	# The pause menu will not open over a pending choice, and this block runs while
	# the run happens to have one on the table.
	var restore_choice := prototype._choice_kind
	prototype._choice_kind = RunRoot.ChoiceKind.NONE
	prototype._open_pause_menu()
	var focus_on_open := prototype.get_viewport().gui_get_focus_owner()
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	prototype._unhandled_input(pad)
	var focus_on_pad := prototype.get_viewport().gui_get_focus_owner()
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(4.0, 0.0)
	prototype._unhandled_input(mouse)
	var focus_after_mouse := prototype.get_viewport().gui_get_focus_owner()
	prototype._unhandled_input(pad)
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	prototype._unhandled_input(key)
	var focus_after_key := prototype.get_viewport().gui_get_focus_owner()
	prototype._close_pause_menu()
	prototype._choice_kind = restore_choice
	report.check(
		focus_on_open == null
		and focus_on_pad == prototype.pause_menu.resume_button
		and focus_after_mouse == null
		and focus_after_key == null,
		"the focus ring appears only for a controller and leaves on mouse or keyboard"
	)

	# Mass and Force are physically distinct: Mass decides how much material is
	# thrown, Push decides how far it goes. Both develop out of the same earnings, so
	# what has to hold is that each rides its own axis and the build can lean them
	# apart.
	prototype.metabolism.reset_metabolism()
	prototype.progression.reset_progression()
	for _bloom_unlock in range(
		int(prototype.metabolism.pressure_unlock_seconds * 30.0) + 30
	):
		prototype.metabolism.advance(1.0 / 30.0)
	var mass_before := prototype.bloom_director.get_bloom_mass_multiplier()
	var force_before := prototype.bloom_director.get_bloom_force_multiplier()
	prototype.progression.debug_select_paths(
		Progression.PathId.ROOT,
		Progression.PathId.SPORE
	)
	prototype.progression.add_biomass(4000.0)
	var mass_after := prototype.bloom_director.get_bloom_mass_multiplier()
	var mass_leaning_force := prototype.bloom_director.get_bloom_force_multiplier()
	prototype.progression.debug_select_paths(
		Progression.PathId.BLOOM,
		Progression.PathId.PRUNING
	)
	var push_leaning_force := prototype.bloom_director.get_bloom_force_multiplier()
	var push_leaning_mass := prototype.bloom_director.get_bloom_mass_multiplier()
	report.check(
		mass_after > mass_before
		and push_leaning_force > mass_leaning_force
		and push_leaning_mass < mass_after,
		"Bloom Mass rides Mass and Bloom Force rides Push, and the build leans them apart"
	)
	prototype.progression.reset_progression()
	prototype.metabolism.reset_metabolism()
	prototype.metabolism.reset_metabolism()

	# Geometry decides where the splatter can go: a splat is never thrown through
	# basalt, so a wall shortens the spray instead of painting past it.
	prototype.territory_field._commands.clear()
	var splats_clear_of_walls := true
	prototype.bloom_director.on_bloom_detonated(splatter_origin, 0)
	for command in prototype.territory_field._commands:
		if command.kind != TerritoryField.TerritoryCommand.Kind.SPLAT:
			continue
		var landing := prototype.territory_field.cell_to_local(command.cell_position)
		splats_clear_of_walls = (
			splats_clear_of_walls
			and prototype.territory_field.is_claimable_at_local(landing)
		)
	report.check(
		splats_clear_of_walls,
		"every thrown splat lands on claimable ground rather than inside basalt"
	)
	prototype.territory_field._commands.clear()
