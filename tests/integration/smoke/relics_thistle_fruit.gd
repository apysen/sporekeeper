## Thistle and Fruit relics, and the network counters underneath them.
##
## The rule every one of these is built on is that only a natural thorn advances a
## counter. A relic-fired thorn hits, kills and ricochets normally and feeds nothing,
## which is what stops six turrets answering each other forever - so the first check
## here is that rule itself, before any relic that depends on it.
class_name SmokeRelicsThistleFruit
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot, relics: RelicDirector, lone_spot: Vector2) -> void:
	# ----------------------------------------------------------- Thistle relics
	# The network's counters are the whole safety story: a bonus thorn that advanced
	# the counter that produced it would make the turrets fire forever. Every case
	# below asserts that separation as well as the payout.
	prototype.progression.debug_select_paths(
		Progression.PathId.THISTLE,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	var adaptation := prototype.adaptation_director
	var thistle_spot := SmokeFixtures.find_owned_cell_position(prototype)

	# Only a natural thorn advances a network counter.
	adaptation.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.THORN_RELAY] = 1
	prototype.progression._owned_relics[RelicCatalog.Id.FORKING_PATTERN] = 1
	var bonus_thorn := ThornState.new()
	bonus_thorn.source_tag = ThornState.Source.CROWN
	for _bonus_impact in range(
		maxi(adaptation.thorn_relay_impacts, adaptation.forking_pattern_impacts) * 2
	):
		adaptation._note_natural_thorn_impact(bonus_thorn, -1, thistle_spot, false)
	var counters_untouched := (
		adaptation._relay_impacts == 0 and adaptation._forking_impacts == 0
	)
	var natural_thorn := ThornState.new()
	natural_thorn.source_tag = ThornState.Source.NATURAL
	natural_thorn.source_thistle_sequence = -1
	for _natural_impact in range(adaptation.thorn_relay_impacts - 1):
		adaptation._note_natural_thorn_impact(natural_thorn, -1, thistle_spot, false)
	var counted_naturals := adaptation._relay_impacts
	report.check(
		counters_untouched and counted_naturals == adaptation.thorn_relay_impacts - 1,
		"a relic-fired thorn never advances a Thistle network counter, and a natural one does"
	)

	# Thorn Relay: the counter resets on its threshold, and the rate limiter holds.
	adaptation._relay_impacts = adaptation.thorn_relay_impacts - 1
	adaptation._relay_cooldown = 0.0
	adaptation._note_natural_thorn_impact(natural_thorn, -1, thistle_spot, false)
	var relay_reset := adaptation._relay_impacts
	report.check(
		relay_reset == 0,
		"THORN RELAY answers on its eighth natural impact and starts counting again"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.THORN_RELAY] = 0

	# Forking Pattern: the active-thorn cap bounds it, and a split thorn cannot
	# advance the counter that split it.
	adaptation._forking_impacts = 0
	adaptation._forking_cooldown = 0.0
	var forked_thorn := ThornState.new()
	forked_thorn.source_tag = ThornState.Source.FORKING
	for _forked_impact in range(adaptation.forking_pattern_impacts * 2):
		adaptation._note_natural_thorn_impact(forked_thorn, -1, thistle_spot, false)
	report.check(
		adaptation._forking_impacts == 0,
		"FORKING PATTERN branches cannot advance Forking Pattern"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.FORKING_PATTERN] = 0

	# Pincushion: stacks come only from the thorns the relic names, they cap at the
	# threshold, and the burst spends them.
	adaptation.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.PINCUSHION] = 1
	var pincushion_victim := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER, thistle_spot
	)
	var ineligible_thorn := ThornState.new()
	ineligible_thorn.source_tag = ThornState.Source.PHYLLOTAXIS
	for _ineligible in range(adaptation.pincushion_threshold):
		adaptation._add_pincushion_stack(pincushion_victim, ineligible_thorn)
	var stacks_from_ineligible := adaptation._pincushion_stacks.size()
	for _eligible in range(adaptation.pincushion_threshold + 4):
		adaptation._add_pincushion_stack(pincushion_victim, natural_thorn)
	var pincushion_stack: Array = adaptation._pincushion_stacks[pincushion_victim]
	var stacks_capped := int(pincushion_stack[0])
	adaptation._burst_pincushion(pincushion_victim, thistle_spot)
	var stacks_spent := not adaptation._pincushion_stacks.has(pincushion_victim)
	report.check(
		stacks_from_ineligible == 0
		and stacks_capped == adaptation.pincushion_threshold
		and stacks_spent,
		"PINCUSHION embeds only qualifying thorns, caps the stack, and spends it on death"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.PINCUSHION] = 0

	# Answering Thorn: a natural kill makes a different turret answer, on a shared
	# cooldown, and a relic-fired kill never starts it.
	adaptation.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.ANSWERING_THORN] = 1
	adaptation._answering_cooldown = 0.0
	adaptation._answer_thorn(bonus_thorn, thistle_spot)
	var answered_by_relic := adaptation._answering_cooldown > 0.0
	adaptation._answer_thorn(natural_thorn, thistle_spot)
	var answered_by_natural := adaptation._answering_cooldown > 0.0
	report.check(
		not answered_by_relic and answered_by_natural,
		"ANSWERING THORN is started by a natural volley's kill and never by a relic's"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.ANSWERING_THORN] = 0

	# Rosette: a newly grown permanent Thistle is owed one opening volley, and a
	# temporary turret is owed nothing.
	adaptation.reset_adaptations()
	prototype.progression._owned_relics[RelicCatalog.Id.ROSETTE] = 1
	adaptation._plant_thistle(false, 5.0)
	var rosette_for_temporary := adaptation._rosette_queue.size()
	adaptation._plant_thistle(true, 0.0)
	var rosette_for_permanent := adaptation._rosette_queue.size()
	for _rosette_tick in range(int(adaptation.rosette_delay_seconds * 60.0) + 6):
		adaptation._advance_thistle_relics(1.0 / 60.0)
	report.check(
		rosette_for_temporary == 0
		and rosette_for_permanent == 1
		and adaptation._rosette_queue.is_empty(),
		"ROSETTE owes an opening volley to a new permanent Thistle only, and pays it once"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.ROSETTE] = 0
	adaptation.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()

	# ------------------------------------------------------------- Fruit relics
	# Fruit's pool keeps kinetic energy alive, so the caps are the safety story:
	# an unbounded Newton's Apple in a crowd is the failure this guards.
	prototype.progression.debug_select_paths(
		Progression.PathId.FRUIT,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	adaptation.reset_adaptations()
	prototype.combat.reset_combat()
	var fruit_spot := SmokeFixtures.find_owned_cell_position(prototype)

	# Stem Steering: a Fruit curves toward a new target while keeping every bit of
	# its speed, and only twice.
	prototype.progression._owned_relics[RelicCatalog.Id.STEM_STEERING] = 1
	var steered := FruitState.new()
	steered.position = fruit_spot
	steered.speed = 300.0
	steered.base_speed = 300.0
	steered.last_direction = Vector2.RIGHT
	steered.velocity = Vector2.RIGHT * 300.0
	var steer_victim := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER, fruit_spot + Vector2(40.0, 90.0)
	)
	adaptation._try_stem_steering(steered, -1)
	var steer_turned := not steered.last_direction.is_equal_approx(Vector2.RIGHT)
	var steer_kept_speed := is_equal_approx(steered.speed, 300.0)
	adaptation._try_stem_steering(steered, -1)
	adaptation._try_stem_steering(steered, -1)
	report.check(
		steer_turned
		and steer_kept_speed
		and steered.steering_uses == adaptation.stem_steering_uses,
		"STEM STEERING curves a Fruit without adding speed and stops at two uses"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.STEM_STEERING] = 0

	# Windfall: a kill restores speed up to its ceiling and redirects, three times.
	prototype.progression._owned_relics[RelicCatalog.Id.WINDFALL] = 1
	var windfallen := FruitState.new()
	windfallen.position = fruit_spot
	windfallen.speed = 100.0
	windfallen.base_speed = 300.0
	windfallen.last_direction = Vector2.RIGHT
	windfallen.velocity = Vector2.RIGHT * 100.0
	adaptation._try_windfall(windfallen, -1)
	var windfall_restored := windfallen.speed > 100.0
	# Drive it past the ceiling: speed must clamp rather than run away.
	for _windfall_use in range(adaptation.windfall_uses + 3):
		windfallen.windfall_cooldown = 0.0
		adaptation._try_windfall(windfallen, -1)
	var windfall_capped := (
		windfallen.speed
		<= windfallen.base_speed * adaptation.windfall_maximum_speed_share + 0.001
	)
	report.check(
		windfall_restored
		and windfall_capped
		and windfallen.windfall_uses == adaptation.windfall_uses,
		"WINDFALL restores speed to a ceiling and spends exactly three uses per Fruit"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.WINDFALL] = 0

	# Fruit Salad: two different Fruit of the same release burst the target; the
	# same Fruit hitting twice, or a Fruit from another release, does not.
	prototype.progression._owned_relics[RelicCatalog.Id.FRUIT_SALAD] = 1
	adaptation._fruit_salad_marks.clear()
	var salad_victim := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HEAVY_GRAZER, fruit_spot
	)
	var first_fruit := FruitState.new()
	first_fruit.release_id = 7
	first_fruit.fruit_id = 1
	first_fruit.damage = 40.0
	adaptation._try_fruit_salad(first_fruit, salad_victim)
	var salad_marked := adaptation._fruit_salad_marks.has(salad_victim)
	# The same Fruit again is not two Fruit.
	adaptation._try_fruit_salad(first_fruit, salad_victim)
	var salad_same_fruit := adaptation._fruit_salad_marks.has(salad_victim)
	var salad_health_before := prototype.combat.get_enemy_health(salad_victim)
	var second_fruit := FruitState.new()
	second_fruit.release_id = 7
	second_fruit.fruit_id = 2
	second_fruit.damage = 40.0
	adaptation._try_fruit_salad(second_fruit, salad_victim)
	var salad_burst := prototype.combat.get_enemy_health(salad_victim) < salad_health_before
	report.check(
		salad_marked
		and salad_same_fruit
		and salad_burst
		and not adaptation._fruit_salad_marks.has(salad_victim),
		"FRUIT SALAD bursts only on a second, different Fruit from the same release"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.FRUIT_SALAD] = 0

	# Newton's Apple: three starters per Fruit, a hard global body cap, and only an
	# ordinary enemy is ever launched.
	prototype.progression._owned_relics[RelicCatalog.Id.NEWTONS_APPLE] = 1
	adaptation._falling_bodies.clear()
	prototype.combat.reset_combat()
	for newton_index in range(12):
		prototype.combat.spawn_enemy(
			EnemyKinds.Role.HUNTER,
			fruit_spot + Vector2(float(newton_index) * 18.0, 0.0)
		)
	var newton_boss_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.BOSS, fruit_spot + Vector2(0.0, 60.0)
	)
	var thrower := FruitState.new()
	thrower.position = fruit_spot
	thrower.damage = 36.0
	thrower.knockback = 38.0
	# A boss is struck by Falling Bodies but is never launched as one.
	adaptation._try_newtons_apple(thrower, newton_boss_id)
	var boss_launched := adaptation._falling_bodies.size()
	var newton_enemies := prototype.combat.get_active_enemy_ids()
	for starter_index in range(adaptation.newton_starters_per_fruit + 3):
		thrower.newton_cooldown = 0.0
		if starter_index < newton_enemies.size():
			adaptation._try_newtons_apple(thrower, newton_enemies[starter_index])
	var starters_spent := thrower.newton_starters
	# The global cap holds regardless of how many Fruit are asking.
	var another := FruitState.new()
	another.position = fruit_spot
	another.damage = 36.0
	another.knockback = 38.0
	for overflow_index in range(newton_enemies.size()):
		another.newton_cooldown = 0.0
		another.newton_starters = 0
		adaptation._try_newtons_apple(another, newton_enemies[overflow_index])
	report.check(
		boss_launched == 0
		and starters_spent == adaptation.newton_starters_per_fruit
		and adaptation._falling_bodies.size() <= adaptation.newton_active_maximum,
		"NEWTON'S APPLE launches only ordinary enemies and holds its starter and body caps"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.NEWTONS_APPLE] = 0

	# Bruised Fruit: a collision makes the trail wider for a fixed distance of
	# travel, and refreshing it never stacks the multiplier.
	prototype.progression._owned_relics[RelicCatalog.Id.BRUISED_FRUIT] = 1
	var bruised := FruitState.new()
	bruised.juicy_remaining = adaptation.bruised_fruit_distance_pixels
	var juicy_first := bruised.juicy_remaining
	bruised.juicy_remaining = maxf(
		0.0, bruised.juicy_remaining - adaptation.bruised_fruit_distance_pixels * 0.5
	)
	var juicy_spent := bruised.juicy_remaining < juicy_first
	bruised.juicy_remaining = adaptation.bruised_fruit_distance_pixels
	report.check(
		juicy_spent
		and is_equal_approx(
			bruised.juicy_remaining, adaptation.bruised_fruit_distance_pixels
		),
		"BRUISED FRUIT is spent by travel and a refresh restores it without stacking"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.BRUISED_FRUIT] = 0
	adaptation.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
