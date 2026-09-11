## Every relic, one at a time: what earns it its proc, what bounds it, and what it
## must never do.
##
## Each block installs one relic, drives the exact situation it names, and clears up
## after itself, so the order they appear in is the order the roster is written and
## not a dependency. They share the run's Green and the same handful of scratch
## positions rather than regrowing a territory each time, which is why this is one
## module and not one per relic.
class_name SmokeRelicRules
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	# ---------------------------------------------------------------- relic rules
	# Every relic below is a rule change, so each check asserts the rule rather
	# than a number, and the recursion limiters get their own checks because a
	# relic engine that feeds itself is the failure mode this catalog guards.
	prototype.progression.reset_progression()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	var relics := prototype.relic_director
	relics.reset_director()

	var lone_spot := SmokeFixtures.find_owned_cell_position(prototype)
	# Hard Husk: the first interruption is shrugged off entirely rather than
	# softened, so a Saboteur cannot chip a Seed down through the shield.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.HARD_HUSK] = 1
	relics.apply_relics()
	prototype.overlay.clear_effects()
	var husk_spot := SmokeFixtures.find_owned_cell_position(prototype)
	var husk_seed := prototype.overlay.spawn_seed(husk_spot, 4.0, 0, 1.0)
	prototype.overlay.damage_nearest_catalyst(husk_spot, 30.0, 99.0)
	var survived_first := prototype.overlay.has_seed(husk_seed)
	prototype.overlay.damage_nearest_catalyst(husk_spot, 30.0, 99.0)
	report.check(
		survived_first and not prototype.overlay.has_seed(husk_seed),
		"HARD HUSK ignores the first hit outright and the second still lands"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.HARD_HUSK] = 0
	relics.apply_relics()
	prototype.overlay.clear_effects()

	# Cross-Pollination advances nearby Seeds, and the receiving cooldown is what
	# stops a field of Seeds accelerating each other without end.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.CROSS_POLLINATION] = 1
	relics.apply_relics()
	var pollen_spot := SmokeFixtures.find_owned_cell_position(prototype)
	var neighbour_seed := prototype.overlay.spawn_seed(
		pollen_spot + Vector2(30.0, 0.0),
		6.0,
		0,
		1.0
	)
	var neighbour_before := prototype.overlay.get_seed_progress(neighbour_seed)
	relics._on_seed_germinated(pollen_spot, 0)
	var neighbour_after := prototype.overlay.get_seed_progress(neighbour_seed)
	relics._on_seed_germinated(pollen_spot, 0)
	var neighbour_capped := prototype.overlay.get_seed_progress(neighbour_seed)
	report.check(
		neighbour_after > neighbour_before
		and is_equal_approx(neighbour_capped, neighbour_after),
		"CROSS-POLLINATION advances nearby Seeds and its cooldown stops a chain"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.CROSS_POLLINATION] = 0
	prototype.overlay.clear_effects()

	# Puffball: a Seed broken before it opens is not wasted, and the Seedlings it
	# scatters can never Puffball again. That generation cap is the whole recursion
	# control, so it is asserted rather than assumed.
	var spore := prototype.spore_director
	spore.reset_director()
	prototype.overlay.clear_effects()
	prototype.progression._owned_relics[RelicCatalog.Id.PUFFBALL] = 1
	var puff_spot := SmokeFixtures.find_owned_cell_position(prototype)
	prototype.overlay.spawn_seed(puff_spot, 8.0, 0, 1.0)
	# Destroyed for real rather than by emitting the signal, so the wiring from a
	# Saboteur's hit through to the scatter is what the case actually covers.
	prototype.overlay.damage_nearest_catalyst(puff_spot, 30.0, 99.0)
	var puff_airborne := prototype.overlay.get_active_seed_count()
	for _puff_tick in range(60):
		spore.advance(1.0 / 60.0)
	var seedlings := prototype.overlay.get_seed_ids()
	# A Seedling breaking must not scatter a second generation.
	var second_generation := 0
	if seedlings.size() > 0:
		var seedling_position := prototype.overlay.get_seed_position(seedlings[0])
		prototype.overlay.damage_nearest_catalyst(seedling_position, 8.0, 99.0)
		for _settle in range(60):
			spore.advance(1.0 / 60.0)
		second_generation = prototype.overlay.get_seed_ids().size() - (seedlings.size() - 1)
	report.check(
		puff_airborne == 0
		and seedlings.size() == spore.puffball_seedlings
		and second_generation <= 0,
		"PUFFBALL scatters Seedlings from a broken Seed and they cannot Puffball again"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.PUFFBALL] = 0

	# Windborne: every fifth germination throws Seeds at ground the run does not
	# hold. It is deliberately subcritical, so the count is what is asserted.
	spore.reset_director()
	prototype.overlay.clear_effects()
	prototype.progression._owned_relics[RelicCatalog.Id.WINDBORNE] = 1
	var wind_spot := SmokeFixtures.find_owned_cell_position(prototype)
	for germination in range(spore.windborne_germination_interval):
		spore._note_germination(wind_spot)
	var wind_pending := spore._pending_seeds.size()
	for _wind_tick in range(90):
		spore.advance(1.0 / 60.0)
	var wind_landed := prototype.overlay.get_active_seed_count()
	report.check(
		wind_pending > 0
		and wind_pending <= spore.windborne_seeds
		and wind_landed == wind_pending,
		"WINDBORNE launches on its fifth germination and every Seed it throws lands"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.WINDBORNE] = 0

	# Volunteer: a death on Green a Seed has just made can plant another. The proc
	# roll is pinned so the test measures the rule and not the dice.
	spore.reset_director()
	prototype.overlay.clear_effects()
	prototype.progression._owned_relics[RelicCatalog.Id.VOLUNTEER] = 1
	var authored_volunteer_chance := spore.volunteer_chance
	spore.volunteer_chance = 1.0
	var volunteer_spot := SmokeFixtures.find_owned_cell_position(prototype)
	# A death with no recent germination behind it must plant nothing.
	spore._try_volunteer(volunteer_spot)
	var volunteer_without_green := spore._pending_seeds.size()
	spore._note_germination(volunteer_spot)
	spore._try_volunteer(volunteer_spot)
	var volunteer_after_green := spore._pending_seeds.size()
	# The global cooldown has to stop a pile of corpses planting a Seed each.
	spore._try_volunteer(volunteer_spot)
	var volunteer_on_cooldown := spore._pending_seeds.size()
	spore.volunteer_chance = authored_volunteer_chance
	report.check(
		volunteer_without_green == 0
		and volunteer_after_green == 1
		and volunteer_on_cooldown == 1,
		"VOLUNTEER plants only on freshly germinated Green, and its cooldown holds"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.VOLUNTEER] = 0

	# Domino Germination: the tenth natural germination opens a cascade, and the
	# forced germinations inside it never advance the counter that made them.
	spore.reset_director()
	prototype.overlay.clear_effects()
	prototype.progression._owned_relics[RelicCatalog.Id.DOMINO_GERMINATION] = 1
	var domino_spot := SmokeFixtures.find_owned_cell_position(prototype)
	for _domino_seed in range(spore.domino_cascade_seeds + 2):
		prototype.overlay.spawn_seed(domino_spot, 20.0, 0, 1.0)
	var domino_before := prototype.overlay.get_active_seed_count()
	for _domino_germination in range(spore.domino_natural_germinations):
		spore._note_germination(domino_spot)
	var cascade_armed := spore._domino_cascade.size()
	for _domino_tick in range(120):
		spore.advance(1.0 / 60.0)
	var domino_after := prototype.overlay.get_active_seed_count()
	report.check(
		cascade_armed == spore.domino_cascade_seeds
		and domino_before - domino_after == spore.domino_cascade_seeds
		and spore._domino_progress == 0
		and spore._domino_cascade.is_empty(),
		"DOMINO GERMINATION forces one capped cascade and its own links never refeed it"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.DOMINO_GERMINATION] = 0
	spore.reset_director()
	prototype.overlay.clear_effects()

	# ------------------------------------------------------------- Bloom relics
	# Every one of these is a rule about what a detonation is allowed to cause, so
	# each case asserts the rule and its recursion limiter rather than a number.
	var bloom_relics := prototype.bloom_director
	var bloom_spot := SmokeFixtures.find_owned_cell_position(prototype)

	# Deadheading: a bud killed during its wind-up still opens, at reduced strength,
	# and the emergency Bloom it leaves cannot Deadhead again.
	bloom_relics.reset_director()
	prototype.overlay.clear_effects()
	prototype.progression._owned_relics[RelicCatalog.Id.DEADHEADING] = 1
	prototype.overlay.plant_bloom(
		bloom_spot, 4.0, 0, 1.0, BloomDirector.SourceTag.NATURAL
	)
	prototype.overlay.damage_nearest_catalyst(bloom_spot, 30.0, 99.0)
	var deadheaded := bloom_relics._pending_detonations.size()
	var deadheaded_strength := 0.0
	if deadheaded > 0:
		deadheaded_strength = float(bloom_relics._pending_detonations[0][3])
	# An emergency Bloom must not be able to leave another one behind it.
	bloom_relics.on_bloom_interrupted(
		bloom_spot, BloomDirector.SourceTag.DEADHEADING, 1.0
	)
	var deadhead_recursed := bloom_relics._pending_detonations.size() - deadheaded
	report.check(
		deadheaded == 1
		and is_equal_approx(deadheaded_strength, bloom_relics.deadheading_strength)
		and deadhead_recursed == 0,
		"DEADHEADING opens a broken bud at half strength and cannot Deadhead itself"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.DEADHEADING] = 0

	# Overkill: damage spent past an enemy's health banks, and the charge is spent
	# by the next natural Bloom rather than by the blast that filled the meter.
	bloom_relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.OVERKILL] = 1
	bloom_relics._bank_overkill(bloom_relics.overkill_required * 0.5)
	var half_charged := bloom_relics._overkill_charged
	bloom_relics._bank_overkill(bloom_relics.overkill_required * 0.5)
	var charged := bloom_relics._overkill_charged
	# A relic-planted Bloom is not what the charge was promised to.
	var spent_by_child := bloom_relics.try_spend_overkill(
		bloom_spot, BloomDirector.SourceTag.CHAIN
	)
	var spent_by_natural := bloom_relics.try_spend_overkill(
		bloom_spot, BloomDirector.SourceTag.NATURAL
	)
	var spent_twice := bloom_relics.try_spend_overkill(
		bloom_spot, BloomDirector.SourceTag.NATURAL
	)
	report.check(
		not half_charged
		and charged
		and not spent_by_child
		and spent_by_natural
		and not spent_twice,
		"OVERKILL banks to a threshold and only a natural Bloom spends the charge"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.OVERKILL] = 0

	# Chain Bloom: enough kills plant one smaller child beyond the blast, and a
	# child can never plant another.
	bloom_relics.reset_director()
	prototype.overlay.clear_effects()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.CHAIN_BLOOM] = 1
	# A crowd well outside the blast for the child to aim at.
	for chain_index in range(6):
		prototype.combat.spawn_enemy(
			EnemyKinds.Role.HUNTER,
			bloom_spot + Vector2(150.0 + float(chain_index) * 6.0, 0.0)
		)
	var chain_report := CombatDirector.BlastReport.new()
	chain_report.kills = bloom_relics.chain_bloom_kills
	bloom_relics._try_chain_bloom(
		bloom_spot, BloomDirector.SourceTag.NATURAL, 1.0, 60.0, chain_report
	)
	var chain_planted := prototype.overlay.get_active_bloom_count()
	bloom_relics._try_chain_bloom(
		bloom_spot, BloomDirector.SourceTag.CHAIN, 1.0, 60.0, chain_report
	)
	var chain_recursed := prototype.overlay.get_active_bloom_count() - chain_planted
	# Too few kills must plant nothing at all.
	var thin_report := CombatDirector.BlastReport.new()
	thin_report.kills = bloom_relics.chain_bloom_kills - 1
	bloom_relics._try_chain_bloom(
		bloom_spot, BloomDirector.SourceTag.NATURAL, 1.0, 60.0, thin_report
	)
	var chain_under_threshold := (
		prototype.overlay.get_active_bloom_count() - chain_planted - chain_recursed
	)
	report.check(
		chain_planted == 1 and chain_recursed == 0 and chain_under_threshold == 0,
		"CHAIN BLOOM plants one child on enough kills and a child cannot chain again"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.CHAIN_BLOOM] = 0

	# Flowering Front: a natural Bloom that kills enough starts a chain that walks
	# forward and stops at its authored generation cap.
	bloom_relics.reset_director()
	prototype.overlay.clear_effects()
	prototype.progression._owned_relics[RelicCatalog.Id.FLOWERING_FRONT] = 1
	var front_report := CombatDirector.BlastReport.new()
	front_report.kills = bloom_relics.flowering_front_starter_kills
	var front_started := bloom_relics._try_flowering_front(
		bloom_spot, BloomDirector.SourceTag.NATURAL, 1.0, front_report
	)
	# Walk the chain to its cap. Each child is cleared off the field first so the
	# bud cap is not what stops it: the generation cap has to be what does.
	var generations := 1
	for _front_step in range(bloom_relics.flowering_front_generations + 3):
		prototype.overlay.clear_effects()
		if not bloom_relics._try_flowering_front(
			bloom_spot, BloomDirector.SourceTag.FLOWERING_FRONT, 1.0, front_report
		):
			break
		generations += 1
	var front_cooled := bloom_relics._front_cooldown > 0.0
	report.check(
		front_started
		and generations == bloom_relics.flowering_front_generations
		and front_cooled,
		"FLOWERING FRONT walks a chain to its generation cap and then cools down"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.FLOWERING_FRONT] = 0

	# Petal Scatter: one petal per kill, thrown only at enemies the blast missed.
	bloom_relics.reset_director()
	prototype.overlay.clear_effects()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.PETAL_SCATTER] = 1
	# One enemy inside the blast radius and two outside it.
	prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER, bloom_spot + Vector2(20.0, 0.0)
	)
	for petal_index in range(2):
		prototype.combat.spawn_enemy(
			EnemyKinds.Role.HUNTER,
			bloom_spot + Vector2(120.0, float(petal_index) * 30.0)
		)
	var petal_report := CombatDirector.BlastReport.new()
	petal_report.kills = 3
	petal_report.kill_positions = PackedVector2Array([bloom_spot, bloom_spot, bloom_spot])
	bloom_relics._scatter_petals(bloom_spot, 60.0, 100.0, petal_report)
	var petals_thrown := bloom_relics._petals.size()
	report.check(
		petals_thrown == 2,
		"PETAL SCATTER throws one petal per kill and only at enemies outside the blast (%d)"
			% petals_thrown
	)
	prototype.progression._owned_relics[RelicCatalog.Id.PETAL_SCATTER] = 0
	bloom_relics.reset_director()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()

	# ----------------------------------------------------------- Bramble relics
	# The pool's engine is Entanglement feeding itself, so each case asserts both
	# that the rule fires and that the limiter which stops it looping holds.
	var bramble := prototype.bramble_director
	var bramble_spot := SmokeFixtures.find_owned_cell_position(prototype)

	# Hookthorn: a shoved enemy that collides with another tangles both, once per
	# shove, and then both sit on a cooldown.
	bramble.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.HOOKTHORN] = 1
	var shoved_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER, bramble_spot
	)
	var struck_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		bramble_spot + Vector2(bramble.hookthorn_collision_pixels * 0.5, 0.0)
	)
	prototype.combat.enemy_repelled.emit(shoved_id, bramble_spot, Vector2.RIGHT)
	bramble.advance_relics(1.0 / 60.0)
	var hook_shoved := prototype.combat.get_enemy_entanglement(shoved_id)
	var hook_struck := prototype.combat.get_enemy_entanglement(struck_id)
	# The window closed on the collision, so a second tick must add nothing.
	bramble.advance_relics(1.0 / 60.0)
	var hook_no_repeat := is_equal_approx(
		prototype.combat.get_enemy_entanglement(struck_id), hook_struck
	)
	report.check(
		hook_shoved > 0.0 and hook_struck > hook_shoved and hook_no_repeat,
		"HOOKTHORN tangles both bodies once per shove and cannot retrigger from it"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.HOOKTHORN] = 0

	# Thornback: a shove makes the Green shoot a thorn at the least tangled enemy
	# other than the one that was shoved.
	bramble.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.THORNBACK] = 1
	var thorn_source := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER, bramble_spot
	)
	var thorn_target := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER, bramble_spot + Vector2(90.0, 0.0)
	)
	var thorn_health_before := prototype.combat.get_enemy_health(thorn_target)
	prototype.combat.enemy_repelled.emit(thorn_source, bramble_spot, Vector2.RIGHT)
	var thorn_hit := prototype.combat.get_enemy_health(thorn_target) < thorn_health_before
	var thorn_tangled := prototype.combat.get_enemy_entanglement(thorn_target) > 0.0
	# The per-source cooldown has to stop a grazing cadence firing a stream of them.
	var health_after_first := prototype.combat.get_enemy_health(thorn_target)
	prototype.combat.enemy_repelled.emit(thorn_source, bramble_spot, Vector2.RIGHT)
	var thorn_on_cooldown := is_equal_approx(
		prototype.combat.get_enemy_health(thorn_target), health_after_first
	)
	report.check(
		thorn_hit and thorn_tangled and thorn_on_cooldown,
		"THORNBACK shoots one thorn per shove and its source cooldown holds"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.THORNBACK] = 0

	# Cocklebur: only an enemy that leaves Green heavily Entangled carries burrs,
	# and leaving again does not refresh the timer.
	bramble.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.COCKLEBUR] = 1
	var carrier_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER, bramble_spot
	)
	prototype.combat.enemy_left_green.emit(
		carrier_id, bramble_spot, bramble.cocklebur_minimum_entanglement - 0.1
	)
	var burr_under_threshold := bramble.get_burr_carrier_count()
	prototype.combat.enemy_left_green.emit(
		carrier_id, bramble_spot, bramble.cocklebur_minimum_entanglement
	)
	var burr_carried := bramble.get_burr_carrier_count()
	# A carrier spreads Entanglement by touch, and only to bodies it has not
	# already burred.
	var burr_target := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		bramble_spot + Vector2(bramble.cocklebur_contact_pixels * 0.5, 0.0)
	)
	bramble.advance_relics(1.0 / 60.0)
	var burr_spread := prototype.combat.get_enemy_entanglement(burr_target)
	bramble.advance_relics(1.0 / 60.0)
	var burr_capped := is_equal_approx(
		prototype.combat.get_enemy_entanglement(burr_target), burr_spread
	)
	report.check(
		burr_under_threshold == 0 and burr_carried == 1 and burr_spread > 0.0 and burr_capped,
		"COCKLEBUR burrs only a heavily Entangled leaver and respects its touch cooldown"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.COCKLEBUR] = 0

	# Briar Knot: a heavily Entangled corpse leaves a one-use trap, and the active
	# cap replaces the oldest rather than refusing the newest.
	bramble.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.BRIAR_KNOT] = 1
	prototype.combat.enemy_died_entangled.emit(
		bramble_spot,
		bramble.briar_knot_required_entanglement - 0.1,
		EnemyKinds.Role.HUNTER
	)
	var knot_under_threshold := bramble.get_knot_count()
	for knot_index in range(bramble.briar_knot_maximum + 3):
		prototype.combat.enemy_died_entangled.emit(
			bramble_spot + Vector2(float(knot_index) * 400.0, 0.0),
			1.0,
			EnemyKinds.Role.HUNTER
		)
	var knots_capped := bramble.get_knot_count()
	# One use: an enemy walking into a Knot springs it and the Knot is gone.
	bramble.reset_director()
	prototype.combat.enemy_died_entangled.emit(
		bramble_spot, 1.0, EnemyKinds.Role.HUNTER
	)
	var caught_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER, bramble_spot
	)
	for _knot_tick in range(30):
		bramble.advance_relics(1.0 / 60.0)
	report.check(
		knot_under_threshold == 0
		and knots_capped == bramble.briar_knot_maximum
		and bramble.get_knot_count() == 0
		and prototype.combat.get_enemy_entanglement(caught_id) > 0.0,
		"BRIAR KNOT arms on a tangled corpse, caps its count, and springs exactly once"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.BRIAR_KNOT] = 0

	# Briarball: four heavily Entangled deaths roll into one ball, and the active
	# cap preserves a completed charge rather than spending it into nothing.
	bramble.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.BRIARBALL] = 1
	for _ball_death in range(bramble.briarball_deaths_required - 1):
		prototype.combat.enemy_died_entangled.emit(
			bramble_spot, 1.0, EnemyKinds.Role.HUNTER
		)
	var ball_under_charge := bramble.get_briarball_count()
	prototype.combat.enemy_died_entangled.emit(
		bramble_spot, 1.0, EnemyKinds.Role.HUNTER
	)
	var ball_rolled := bramble.get_briarball_count()
	# A ball damages and tangles what it rolls over.
	var rolled_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		bramble_spot + Vector2(bramble.briarball_contact_pixels * 0.5, 0.0)
	)
	var rolled_health := prototype.combat.get_enemy_health(rolled_id)
	bramble.advance_relics(1.0 / 60.0)
	report.check(
		ball_under_charge == 0
		and ball_rolled == 1
		and prototype.combat.get_enemy_health(rolled_id) < rolled_health
		and prototype.combat.get_enemy_entanglement(rolled_id) > 0.0,
		"BRIARBALL rolls on its fourth tangled corpse and crashes through the crowd"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.BRIARBALL] = 0
	bramble.reset_director()
	prototype.combat.reset_combat()

	# ----------------------------------------------------------- Pruning relics
	# Pruning's pool turns one release into a cycle, so every case here asserts the
	# limiter as well as the payout: an unbounded Pruning build is the failure mode.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.PRUNING,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	var pruning_relics := prototype.pruning_director
	var prune_spot := SmokeFixtures.find_owned_cell_position(prototype)
	prototype.player.global_position = prototype.territory_field.to_global(prune_spot)

	# Brush Pile: only Green cut past half Charge is stored, the bundle count is
	# capped, and a release empties the store whether or not it was full.
	pruning_relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.BRUSH_PILE] = 1
	pruning_relics._charge = pruning_relics.brush_pile_charge_threshold - 0.1
	pruning_relics._note_brush_harvest(pruning_relics.brush_pile_cells_per_bundle * 2)
	var brush_below_threshold := pruning_relics.get_brush_bundles()
	pruning_relics._charge = pruning_relics.brush_pile_charge_threshold
	pruning_relics._note_brush_harvest(
		pruning_relics.brush_pile_cells_per_bundle * (pruning_relics.brush_pile_maximum_bundles + 3)
	)
	var brush_capped := pruning_relics.get_brush_bundles()
	report.check(
		brush_below_threshold == 0
		and brush_capped == pruning_relics.brush_pile_maximum_bundles,
		"BRUSH PILE stores only what is cut past half Charge and stops at its cap"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.BRUSH_PILE] = 0

	# Callus: standing in the wound when the ring fires is not returning to it. The
	# player has to leave and come back before the pulse is owed.
	pruning_relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.CALLUS] = 1
	pruning_relics._callus_position = prune_spot
	pruning_relics._callus_remaining = pruning_relics.callus_window_seconds
	pruning_relics._callus_used = false
	pruning_relics._callus_left_wound = false
	prototype.player.global_position = prototype.territory_field.to_global(prune_spot)
	pruning_relics._advance_callus(1.0 / 60.0)
	var callus_standing_still := pruning_relics._callus_used
	# Leave the wound, then come back.
	prototype.player.global_position = prototype.territory_field.to_global(
		prune_spot + Vector2(pruning_relics.callus_radius_pixels * 2.0, 0.0)
	)
	pruning_relics._advance_callus(1.0 / 60.0)
	prototype.player.global_position = prototype.territory_field.to_global(prune_spot)
	pruning_relics._advance_callus(1.0 / 60.0)
	var callus_paid := pruning_relics._callus_used
	# One pulse per release: a second return is worth nothing.
	pruning_relics._advance_callus(1.0 / 60.0)
	report.check(
		not callus_standing_still and callus_paid and not pruning_relics.is_callus_armed(),
		"CALLUS pays once, and only after the player has actually left the wound"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.CALLUS] = 0

	# Stubble: the wound stays sharp, each enemy is on its own tick cooldown, and
	# only two wounds are ever hazardous at once.
	pruning_relics.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.STUBBLE] = 1
	for stubble_wound_index in range(pruning_relics.stubble_maximum_wounds + 2):
		pruning_relics._stubble_wounds.append([
			prune_spot + Vector2(float(stubble_wound_index) * 500.0, 0.0),
			pruning_relics.stubble_seconds,
			{},
		])
		if pruning_relics._stubble_wounds.size() > pruning_relics.stubble_maximum_wounds:
			pruning_relics._stubble_wounds.remove_at(0)
	var stubble_capped := pruning_relics.get_stubble_wound_count()
	# A wound expires rather than lingering.
	for _stubble_tick in range(int(pruning_relics.stubble_seconds * 60.0) + 10):
		pruning_relics._advance_stubble(1.0 / 60.0)
	report.check(
		stubble_capped == pruning_relics.stubble_maximum_wounds
		and pruning_relics.get_stubble_wound_count() == 0,
		"STUBBLE keeps at most two sharp wounds and each one expires on its own clock"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.STUBBLE] = 0

	# Skimming Cut: a natural spike glances off terrain toward a new target once,
	# and a spike that has already glanced is spent by its next collision.
	pruning_relics.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.SKIMMING_CUT] = 1
	prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER, prune_spot + Vector2(60.0, 0.0)
	)
	var skimmer := pruning_relics._get_inactive_cutting()
	skimmer.position = prune_spot
	skimmer.damage = 40.0
	skimmer.velocity = Vector2(200.0, 0.0)
	skimmer.natural_release = true
	skimmer.has_ricocheted = false
	var skimmed := pruning_relics._try_skimming_cut(skimmer)
	var skim_damage_cut := skimmer.damage < 40.0
	var skim_again := pruning_relics._try_skimming_cut(skimmer)
	# A relic-thrown spike is not a natural release and never glances.
	var relic_spike := pruning_relics._get_inactive_cutting()
	relic_spike.position = prune_spot
	relic_spike.damage = 40.0
	relic_spike.velocity = Vector2(200.0, 0.0)
	relic_spike.natural_release = false
	var relic_skimmed := pruning_relics._try_skimming_cut(relic_spike)
	report.check(
		skimmed and skim_damage_cut and not skim_again and not relic_skimmed,
		"SKIMMING CUT redirects a natural spike once and never a relic-thrown one"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.SKIMMING_CUT] = 0

	# Watersprouts: a natural killing spike sprouts children, those children may
	# branch once more, and generation two is the end of it.
	pruning_relics.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.WATERSPROUTS] = 1
	for sprout_index in range(8):
		prototype.combat.spawn_enemy(
			EnemyKinds.Role.HUNTER,
			prune_spot + Vector2(40.0 + float(sprout_index) * 12.0, 0.0)
		)
	var parent := pruning_relics._get_inactive_cutting()
	parent.position = prune_spot
	parent.damage = 40.0
	parent.natural_release = true
	parent.sprout_generation = 0
	pruning_relics._sprout_watersprouts(parent, prune_spot)
	var generation_one := pruning_relics._watersprouts_this_release
	# A generation-2 spike must not reproduce at all.
	var final_child := pruning_relics._get_inactive_cutting()
	final_child.position = prune_spot
	final_child.damage = 20.0
	final_child.natural_release = false
	final_child.sprout_generation = 2
	pruning_relics._sprout_watersprouts(final_child, prune_spot)
	var after_final := pruning_relics._watersprouts_this_release
	# The per-release cap is absolute across both generations.
	pruning_relics._watersprouts_this_release = pruning_relics.watersprout_release_maximum
	pruning_relics._sprout_watersprouts(parent, prune_spot)
	var at_cap := pruning_relics._watersprouts_this_release
	report.check(
		generation_one == pruning_relics.watersprout_children
		and after_final == generation_one
		and at_cap == pruning_relics.watersprout_release_maximum,
		"WATERSPROUTS branches twice, stops at generation two, and honours its release cap"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.WATERSPROUTS] = 0
	pruning_relics.reset_director()
	prototype.combat.reset_combat()
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()

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

	# A long relic description wraps inside its card instead of widening it. A
	# Button's minimum width otherwise includes the whole unwrapped line, so the
	# longest relic in the catalog was pushing the reward box past its own panel.
	prototype.progression.reset_progression()
	var widest_relic := 0
	for catalog_id in range(RelicCatalog.get_count()):
		if (
			RelicCatalog.get_relic_description(catalog_id).length()
			> RelicCatalog.get_relic_description(widest_relic).length()
		):
			widest_relic = catalog_id
	prototype._show_choice(
		RunRoot.ChoiceKind.RELIC, PackedInt32Array([widest_relic])
	)
	# The card has to lay out before its size means anything. The suite reaches the
	# frame through the run rather than by name: `process_frame` is the SceneTree's
	# own signal, and this is no longer running inside the SceneTree script.
	var tree := prototype.get_tree()
	await tree.process_frame
	await tree.process_frame
	var relic_card := prototype.choice_panel.button_one
	var card_fits := (
		relic_card.size.x <= prototype.choice_panel.size.x
		and relic_card.get_combined_minimum_size().x <= prototype.choice_panel.size.x
	)
	var wraps := relic_card.autowrap_mode != TextServer.AUTOWRAP_OFF
	prototype._choice_kind = RunRoot.ChoiceKind.NONE
	prototype._choice_ids.clear()
	prototype.choice_panel.visible = false
	report.check(
		wraps and card_fits,
		"a long relic description wraps inside its card rather than widening the box"
	)

	# The tray has to hold a whole run's relics. Campaign awards twelve, so a row
	# that stopped at six was hiding half of what the player had earned.
	prototype.progression.reset_progression()
	var campaign_relic_target := 14
	for tray_relic in range(campaign_relic_target):
		prototype.progression._owned_relics[tray_relic] = 1
	prototype.relic_tray.refresh()
	var shown := prototype.relic_tray.slots.get_slot_count()
	var every_relic_named := true
	for tray_index in range(campaign_relic_target):
		if prototype.relic_tray.slots.get_slot_tooltip(tray_index).is_empty():
			every_relic_named = false
			break
	prototype.progression.reset_progression()
	prototype.relic_tray.refresh()
	report.check(
		shown >= campaign_relic_target and every_relic_named,
		"the relic tray shows a whole run's relics rather than stopping at six (%d)"
			% shown
	)

	# --------------------------------------------------------------- Relic VFX
	# Two of the document's VFX rules are mechanical rather than artistic, so they
	# are enforced in code and checked here: a generated echo is drawn weaker than
	# what caused it, and same-frame accents are spread so a chain reads in order.
	prototype.overlay.clear_relic_cues()
	prototype.overlay.spawn_relic_cue(
		TerritoryPrototypeOverlay.RelicCue.GHOST, Vector2(100.0, 100.0), 40.0, Color.WHITE
	)
	var natural_intensity := prototype.overlay.get_last_relic_cue_intensity()
	var first_lead_in := prototype.overlay.get_last_relic_cue_lead_in()
	prototype.overlay.spawn_relic_cue(
		TerritoryPrototypeOverlay.RelicCue.GHOST,
		Vector2(100.0, 100.0),
		40.0,
		Color.WHITE,
		Vector2.ZERO,
		true
	)
	var echo_intensity := prototype.overlay.get_last_relic_cue_intensity()
	var second_lead_in := prototype.overlay.get_last_relic_cue_lead_in()
	# An echo of an echo can only get quieter: intensity is held under its source.
	prototype.overlay.spawn_relic_cue(
		TerritoryPrototypeOverlay.RelicCue.GHOST,
		Vector2(100.0, 100.0),
		40.0,
		Color.WHITE,
		Vector2.ZERO,
		true,
		echo_intensity
	)
	var nested_echo := prototype.overlay.get_last_relic_cue_intensity()
	report.check(
		is_equal_approx(natural_intensity, 1.0)
		and echo_intensity >= prototype.overlay.echo_intensity_minimum - 0.001
		and echo_intensity <= prototype.overlay.echo_intensity_maximum + 0.001
		and nested_echo <= echo_intensity + 0.001
		and is_equal_approx(first_lead_in, 0.0)
		and second_lead_in >= prototype.overlay.cue_stagger_seconds - 0.001,
		"a relic echo is drawn weaker than its source and same-frame accents are staggered"
	)
	# Spin is what carries the effects whose identity is rotation. It accumulates
	# with the cue's age rather than with its progress, so a long-lived cue keeps
	# turning instead of easing to a stop halfway through.
	prototype.overlay.clear_relic_cues()
	prototype.overlay.spawn_relic_cue(
		TerritoryPrototypeOverlay.RelicCue.GHOST,
		Vector2(100.0, 100.0),
		40.0,
		Color.WHITE,
		Vector2.RIGHT,
		false,
		1.0,
		TerritoryPrototypeOverlay.RelicMotif.SWIRL,
		2.0
	)
	var spun_cue: Object = prototype.overlay._relic_cues[0]
	var spin_rate := float(spun_cue.spin)
	var still_at_start := spin_rate * TAU * 0.0
	var turned_after := spin_rate * TAU * 0.25
	report.check(
		is_equal_approx(still_at_start, 0.0)
		and turned_after > 0.0
		and is_equal_approx(spin_rate, 2.0),
		"a cue can carry a spin rate, so a rolling effect turns as it plays"
	)
	prototype.overlay.clear_relic_cues()

	# ------------------------------------------------------------- Plant relics
	# Plant is the glue pool, and two of its relics repeat other relics' effects,
	# so the recursion limiters here are the ones guarding the whole catalog.
	relics.reset_director()
	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	var plant_spot := SmokeFixtures.find_owned_cell_position(prototype)

	# Garden Hose: distance is counted on owned Green only, a teleport-sized step
	# never banks any of it, and the counter resets only when the spray fires.
	prototype.progression._owned_relics[RelicCatalog.Id.GARDEN_HOSE] = 1
	relics._garden_hose_travel = 0.0
	relics._garden_hose_last_position = plant_spot
	prototype.player.global_position = prototype.territory_field.to_global(
		plant_spot + Vector2(400.0, 0.0)
	)
	relics._advance_garden_hose()
	var hose_ignored_jump := relics._garden_hose_travel
	relics._garden_hose_last_position = plant_spot
	prototype.player.global_position = prototype.territory_field.to_global(
		plant_spot + Vector2(20.0, 0.0)
	)
	relics._advance_garden_hose()
	var hose_counted_step := relics._garden_hose_travel
	report.check(
		is_equal_approx(hose_ignored_jump, 0.0) and hose_counted_step > 0.0,
		"GARDEN HOSE counts ordinary travel on Green and never a teleport-sized jump"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.GARDEN_HOSE] = 0

	# Mulch: only what an enemy itself eats is stored, it is capped, and one corpse
	# releases it exactly once.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.MULCH] = 1
	relics.notify_green_eaten(41, 0.5)
	var mulch_stored := relics.get_mulch_store(41)
	for _mulch_bite in range(40):
		relics.notify_green_eaten(41, 1.0)
	var mulch_capped := relics.get_mulch_store(41)
	relics._release_mulch(41, plant_spot)
	var mulch_released := relics.get_mulch_store(41)
	report.check(
		mulch_stored > 0.0
		and mulch_capped <= relics.mulch_maximum_store + 0.001
		and is_equal_approx(mulch_released, 0.0),
		"MULCH stores a share of what an enemy eats, caps it, and releases it once"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.MULCH] = 0

	# Compost Heap: corpses merge into a nearby pile, an elite is worth more than a
	# hunter, the pile erupts on its threshold, and the active count is capped.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.COMPOST_HEAP] = 1
	relics._add_compost(plant_spot, 1)
	var heaps_started := relics.get_compost_heap_count()
	relics._add_compost(plant_spot + Vector2(10.0, 0.0), 1)
	var heaps_merged := relics.get_compost_heap_count()
	# Exactly up to the threshold and no further: a heap at threshold stops
	# accepting, so extra corpses would correctly start new piles instead.
	for _compost_corpse in range(relics.compost_threshold - 2):
		relics._add_compost(plant_spot + Vector2(10.0, 0.0), 1)
	for _compost_tick in range(int(relics.compost_eruption_delay * 60.0) + 6):
		relics.advance(1.0 / 60.0)
	var heap_erupted := relics.get_compost_heap_count() == 0
	for far_heap in range(relics.compost_maximum_heaps + 4):
		relics._add_compost(plant_spot + Vector2(float(far_heap) * 300.0, 0.0), 1)
	report.check(
		heaps_started == 1
		and heaps_merged == 1
		and heap_erupted
		and relics.get_compost_heap_count() <= relics.compost_maximum_heaps,
		"COMPOST HEAP merges nearby corpses, erupts on its threshold, and caps its piles"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.COMPOST_HEAP] = 0

	# Miracle-Gro: new Green banks one charge, a second charge cannot stack behind
	# it, and the next Adaptation event spends it.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.MIRACLE_GRO] = 1
	relics.notify_green_created(relics.miracle_gro_required_mass * 0.5)
	var gro_half := relics.is_miracle_gro_charged()
	relics.notify_green_created(relics.miracle_gro_required_mass * 0.5)
	var gro_charged := relics.is_miracle_gro_charged()
	relics.notify_green_created(relics.miracle_gro_required_mass * 4.0)
	var gro_spent := relics.consume_miracle_gro()
	var gro_spent_twice := relics.consume_miracle_gro()
	report.check(
		not gro_half
		and gro_charged
		and is_equal_approx(gro_spent, relics.miracle_gro_strength)
		and is_equal_approx(gro_spent_twice, 0.0),
		"MIRACLE-GRO banks one repeat at a time and the next event spends it"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.MIRACLE_GRO] = 0

	# Grafting Tape: ready, spent, and then held on its cooldown.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.GRAFTING_TAPE] = 1
	var tape_ready := relics.is_grafting_tape_ready()
	var tape_strength := relics.consume_grafting_tape()
	var tape_on_cooldown := not relics.is_grafting_tape_ready()
	report.check(
		tape_ready
		and is_equal_approx(tape_strength, relics.grafting_tape_strength)
		and tape_on_cooldown,
		"GRAFTING TAPE answers once and then holds its cooldown"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.GRAFTING_TAPE] = 0

	# Hybrid Vigor: a repeat can never roll another repeat, Hybrid Vigor never
	# repeats itself, and the rolling window bounds how many land at once.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.HYBRID_VIGOR] = 1
	relics.hybrid_vigor_chance = 1.0
	relics._try_hybrid_vigor(RelicCatalog.Id.HYBRID_VIGOR)
	var vigor_self_repeat := relics._generated_events.size()
	relics._repeating = true
	relics._try_hybrid_vigor(RelicCatalog.Id.SNARE_VINE)
	relics._repeating = false
	var vigor_from_repeat := relics._generated_events.size()
	for _vigor_roll in range(relics.hybrid_vigor_window_maximum + 5):
		relics._try_hybrid_vigor(RelicCatalog.Id.SNARE_VINE)
	var vigor_windowed := relics._generated_events.size()
	report.check(
		vigor_self_repeat == 0
		and vigor_from_repeat == 0
		and vigor_windowed == relics.hybrid_vigor_window_maximum,
		"HYBRID VIGOR never repeats itself or a repeat, and its rolling window holds"
	)

	# The global scheduler drains its queue on a budget rather than dropping what
	# the player earned, and a full queue keeps the rarest events.
	var queued_before := relics._generated_events.size()
	for _drain_tick in range(120):
		relics.advance(1.0 / 60.0)
	var drained := relics._generated_events.is_empty()
	relics._generated_events.clear()
	for _fill in range(relics.generated_event_queue_maximum):
		relics._queue_generated_event(
			RelicCatalog.Id.SNARE_VINE, plant_spot, 0.5, 99.0
		)
	var accepted_legendary := relics._queue_generated_event(
		RelicCatalog.Id.THE_HEDGE, plant_spot, 0.5, 99.0
	)
	report.check(
		queued_before > 0 and drained and accepted_legendary,
		"the generated-event queue drains on its frame budget and a full one keeps the rarest"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.HYBRID_VIGOR] = 0
	relics.reset_director()
	prototype.combat.reset_combat()

	# -------------------------------------------------------------- Root relics
	# Root transmits through Mature Green rather than adding a resource to manage,
	# so these cases check what the network does, not what the player spends.
	relics.reset_director()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	var root_spot := SmokeFixtures.find_owned_cell_position(prototype)

	# The Shared Ancient Territory rule places near Grandma rather than on the
	# globally oldest cell, which is the whole point of replacing it.
	for _ripen_ancient in range(6):
		prototype.territory_field.queue_maturity_support(root_spot, 1.0, 4.0)
		prototype.territory_field.step_simulation()
	prototype.player.global_position = prototype.territory_field.to_global(root_spot)
	# The region list is sampled on the shared topology clock, so a relic that reads
	# it has to be held and one sample has to have run.
	prototype.progression._owned_relics[RelicCatalog.Id.TAPROOT] = 1
	relics._topology_remaining = 0.0
	relics._advance_topology(1.0 / 60.0)
	var ancient_site := relics._find_ancient_site()
	var ancient_is_near := (
		ancient_site.x >= 0.0
		and ancient_site.distance_to(root_spot) <= relics.ancient_expanded_search_pixels
	)
	# A region already tracked is skipped, which is what lets Annual Rings hold
	# several distinct regions instead of stacking them all on one.
	var excluded_site := relics._find_ancient_site(
		PackedVector2Array([ancient_site]), 4000.0
	)
	report.check(
		ancient_is_near and excluded_site.x < 0.0,
		"the Ancient Territory rule places near Grandma and skips regions already tracked"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.TAPROOT] = 0

	# Rootbound: charged by continuous time on deep Green, carried, and spent by
	# walking into young Green rather than by standing still.
	prototype.progression._owned_relics[RelicCatalog.Id.ROOTBOUND] = 1
	relics._rootbound_standing = 0.0
	relics._rootbound_carrying = 0.0
	relics._rootbound_cooldown = 0.0
	prototype.player.global_position = prototype.territory_field.to_global(root_spot)
	for _charge_tick in range(int(relics.rootbound_charge_seconds * 60.0) + 6):
		relics._advance_rootbound(1.0 / 60.0)
	var rootbound_carrying := relics._rootbound_carrying > 0.0
	# Stepping off owned Green entirely must not discharge it.
	var off_green := prototype.territory_field.find_player_frontier_near(root_spot)
	relics._advance_rootbound(1.0 / 60.0)
	var rootbound_held := relics._rootbound_carrying > 0.0
	report.check(
		rootbound_carrying and rootbound_held,
		"ROOTBOUND charges on deep Green and keeps the pulse until young Green takes it"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.ROOTBOUND] = 0

	# Suckers: only enemy-caused loss counts, and the relic answers once per
	# regional cooldown rather than once per cell.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.SUCKERS] = 1
	relics.notify_mature_green_lost(relics.suckers_lost_cells - 1)
	relics._advance_suckers(1.0 / 60.0)
	var suckers_under_threshold := relics._pending_suckers.size()
	relics.notify_mature_green_lost(2)
	relics._advance_suckers(1.0 / 60.0)
	var suckers_sprouted := relics._pending_suckers.size()
	# A second wound inside the cooldown must not sprout again.
	relics.notify_mature_green_lost(relics.suckers_lost_cells * 2)
	relics._advance_suckers(1.0 / 60.0)
	var suckers_on_cooldown := relics._pending_suckers.size()
	report.check(
		suckers_under_threshold == 0
		and suckers_sprouted == relics.suckers_count
		and suckers_on_cooldown == suckers_sprouted,
		"SUCKERS answers a real wound once, and its regional cooldown holds"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.SUCKERS] = 0

	# Feeder Roots: only amplified natural events on deep Green count, and a
	# relic-generated echo never advances it.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.FEEDER_ROOTS] = 1
	relics.notify_amplified_event(root_spot, 1.0)
	var feeder_unamplified := relics._feeder_events
	relics._repeating = true
	relics.notify_amplified_event(root_spot, 1.5)
	relics._repeating = false
	var feeder_from_echo := relics._feeder_events
	for _feeder_event in range(relics.feeder_roots_events - 1):
		relics.notify_amplified_event(root_spot, 1.5)
	var feeder_counted := relics._feeder_events
	report.check(
		feeder_unamplified == 0
		and feeder_from_echo == 0
		and feeder_counted == relics.feeder_roots_events - 1,
		"FEEDER ROOTS counts only amplified natural events, never an unamplified one or an echo"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.FEEDER_ROOTS] = 0

	# Graft Union: arms on a reconnection, is spent once, and then holds cooldown.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.GRAFT_UNION] = 1
	var graft_unarmed := relics.is_graft_union_armed()
	# Component count comes off the shared topology cache, so the split and the
	# rejoin are driven through that seam rather than by rearranging the board.
	relics._cached_component_count = 2
	relics._advance_graft_union(1.0 / 60.0)
	var graft_saw_split := relics._graft_components > 1
	relics._graft_split_seconds = relics.graft_union_separation_seconds
	relics._cached_component_count = 1
	relics._advance_graft_union(1.0 / 60.0)
	var graft_armed := relics.is_graft_union_armed()
	var graft_strength := relics.consume_graft_union()
	var graft_spent_twice := relics.consume_graft_union()
	report.check(
		not graft_unarmed
		and graft_saw_split
		and graft_armed
		and is_equal_approx(graft_strength, relics.graft_union_strength)
		and is_equal_approx(graft_spent_twice, 0.0),
		"GRAFT UNION arms when a long-split network rejoins and its echo is spent once"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.GRAFT_UNION] = 0

	# Rhizome: a whole organism offers no colony to reconnect, and the field's own
	# component query is what decides that rather than the relic guessing.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.RHIZOME] = 1
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	var whole_organism := prototype.territory_field.find_isolated_colony(
		relics.rhizome_minimum_cells, relics.rhizome_minimum_maturity
	)
	for _rhizome_tick in range(int(relics.rhizome_survival_seconds * 60.0) + 10):
		relics._advance_rhizome(1.0 / 60.0)
	report.check(
		whole_organism.x < 0.0
		and prototype.territory_field.get_owned_component_count() >= 1
		and relics._rhizome_growing <= 0.0,
		"RHIZOME finds nothing to reconnect while the organism is in one piece"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.RHIZOME] = 0
	relics.reset_director()
	prototype.combat.reset_combat()

	# -------------------------------------------------------------- Vine relics
	# Vine's pool is ignited by precision, and Apical now means real contact from
	# the outer portion of the simulated rope. These cases check the streaks and
	# the limiters; the rope's own physics has its own probe.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.VINE,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	var vine := prototype.adaptation_director
	vine.reset_adaptations()
	prototype.combat.reset_combat()
	var vine_spot := SmokeFixtures.find_owned_cell_position(prototype)
	prototype.player.global_position = prototype.territory_field.to_global(vine_spot)

	# The Cane resolves through the rope while Vine is held, and through its
	# authored sector otherwise. That switch is what the whole rework rests on.
	var vine_drives := prototype.combat.is_vine_driven()
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	var sector_drives := prototype.combat.is_vine_driven()
	prototype.progression.debug_select_paths(
		Progression.PathId.VINE,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	report.check(
		vine_drives and not sector_drives,
		"the Cane resolves through the simulated Vine only while Vine is held"
	)

	# Girdling: consecutive natural Apical hits on the same enemy mark it, a gap
	# breaks the streak, and the next Vine contact spends the mark.
	vine.reset_adaptations()
	prototype.progression._owned_relics[RelicCatalog.Id.GIRDLING] = 1
	var girdled_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HEAVY_GRAZER, vine_spot + Vector2(40.0, 0.0)
	)
	vine._natural_sweep_index = 1
	vine._note_vine_apical_hit(girdled_id, 30.0)
	# Two hits inside one sweep are one hit's worth of progress.
	vine._note_vine_apical_hit(girdled_id, 30.0)
	var girdle_after_one := int(vine._girdling[girdled_id][0])
	vine._natural_sweep_index = 2
	vine._note_vine_apical_hit(girdled_id, 30.0)
	var girdle_marked := float(vine._girdling[girdled_id][2]) > 0.0
	var girdle_health := prototype.combat.get_enemy_health(girdled_id)
	vine._try_consume_girdling(girdled_id, 30.0)
	var girdle_crushed := prototype.combat.get_enemy_health(girdled_id) < girdle_health
	var girdle_spent := not vine._girdling.has(girdled_id)
	# A broken streak starts over rather than carrying its progress.
	vine._girdling.clear()
	vine._girdling_cooldowns.clear()
	vine._natural_sweep_index = 10
	vine._note_vine_apical_hit(girdled_id, 30.0)
	vine._natural_sweep_index = 14
	vine._note_vine_apical_hit(girdled_id, 30.0)
	var girdle_streak_reset := int(vine._girdling[girdled_id][0]) == 1
	report.check(
		girdle_after_one == 1
		and girdle_marked
		and girdle_crushed
		and girdle_spent
		and girdle_streak_reset,
		"GIRDLING builds on consecutive Apical sweeps, breaks on a gap, and is spent once"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.GIRDLING] = 0

	# Runner: one sprout per natural sweep, capped, and it lashes a neighbour.
	vine.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.RUNNER] = 1
	var runner_victim := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER, vine_spot + Vector2(30.0, 0.0)
	)
	vine._runners.append([vine_spot, 0.0, 25.0])
	var runner_health := prototype.combat.get_enemy_health(runner_victim)
	vine._advance_vine_relics(1.0 / 60.0)
	report.check(
		vine._runners.is_empty()
		and prototype.combat.get_enemy_health(runner_victim) < runner_health,
		"RUNNER lashes a neighbour from the corpse and is spent by doing it"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.RUNNER] = 0

	# Whiplash: reaches past the tip, and only enemies the parent sweep missed.
	vine.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.WHIPLASH] = 1
	vine._current_sweep_reach = 60.0
	var beyond_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HEAVY_GRAZER, vine_spot + Vector2(90.0, 0.0)
	)
	var already_hit_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HEAVY_GRAZER, vine_spot + Vector2(100.0, 0.0)
	)
	vine._cane_sweep_hits.append(already_hit_id)
	var beyond_health := prototype.combat.get_enemy_health(beyond_id)
	var already_health := prototype.combat.get_enemy_health(already_hit_id)
	vine._try_whiplash(vine_spot, Vector2.RIGHT, 40.0)
	report.check(
		prototype.combat.get_enemy_health(beyond_id) < beyond_health
		and is_equal_approx(
			prototype.combat.get_enemy_health(already_hit_id), already_health
		),
		"WHIPLASH snaps past the tip and never re-hits what the parent sweep reached"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.WHIPLASH] = 0

	# Climber: requires a real bend in the rope and a hit past it. Without a wrap
	# it must do nothing at all, which is what stops it reaching through terrain.
	vine.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.CLIMBER] = 1
	var climber_victim := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HEAVY_GRAZER, vine_spot + Vector2(20.0, 0.0)
	)
	var climber_health := prototype.combat.get_enemy_health(climber_victim)
	vine._sweep_bend_index = -1
	vine._sweep_hit_past_bend = false
	vine._try_climber(40.0)
	var climber_without_bend := is_equal_approx(
		prototype.combat.get_enemy_health(climber_victim), climber_health
	)
	# A bend with nothing hit past it is still not a Climber.
	vine._sweep_bend_index = 2
	vine._sweep_hit_past_bend = false
	vine._try_climber(40.0)
	var climber_without_hit := is_equal_approx(
		prototype.combat.get_enemy_health(climber_victim), climber_health
	)
	report.check(
		climber_without_bend and climber_without_hit,
		"CLIMBER cinches only a Vine that actually wrapped and struck past the bend"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.CLIMBER] = 0

	# Liana: three consecutive successful Apical sweeps unleash the cascade, a
	# failed sweep resets the streak, and the cascade is exactly four sweeps.
	vine.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.LIANA] = 1
	for _liana_sweep in range(vine.liana_required_sweeps - 1):
		vine._current_sweep_apical_hit = true
		vine._on_cane_sweep_finished(vine_spot, Vector2.RIGHT, true, 92.0, 1, false)
	var liana_building := vine._liana_progress
	# A sweep with no Apical hit breaks it.
	vine._current_sweep_apical_hit = false
	vine._on_cane_sweep_finished(vine_spot, Vector2.RIGHT, true, 92.0, 0, false)
	var liana_reset := vine._liana_progress
	for _liana_again in range(vine.liana_required_sweeps):
		vine._current_sweep_apical_hit = true
		vine._on_cane_sweep_finished(vine_spot, Vector2.RIGHT, true, 92.0, 1, false)
	var liana_cascade := vine._liana_remaining
	var liana_cooling := vine._liana_cooldown > 0.0
	report.check(
		liana_building == vine.liana_required_sweeps - 1
		and liana_reset == 0
		and liana_cascade == vine.liana_bonus_sweeps
		and liana_cooling,
		"LIANA needs three consecutive Apical sweeps, resets on a miss, and casts four"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.LIANA] = 0

	# Continuity: every relic-driven stroke has to drive the rope that is already
	# there. A relic that rebuilt the Vine would look like it was being respawned
	# per attack, which is the whole thing the physics rework exists to stop.
	var whip: VineWhip = prototype.combat.vine_whip
	prototype.player.global_position = prototype.territory_field.to_global(vine_spot)
	prototype.combat.simulate_step(1.0 / 60.0)
	var rope_is_driving := prototype.combat.is_vine_driven() and whip.is_built()

	# Recurve reverses a rope that is still carrying momentum: the next stroke
	# arrives sooner and starts from exactly where the last one left the body.
	prototype.progression._owned_relics[RelicCatalog.Id.RECURVE] = 1
	vine._recurve_armed = false
	vine._on_cane_enemy_hit(-1, vine_spot, 0.9, true, 10.0, false, false)
	var recurve_armed := vine._recurve_armed
	var before_recurve := whip.points.duplicate()
	var sweep_before := whip.get_sweep_id()
	prototype.combat.perform_bonus_cane_sweep(Vector2.RIGHT, false)
	var recurve_continuous := true
	for point_index in range(before_recurve.size()):
		if not before_recurve[point_index].is_equal_approx(whip.points[point_index]):
			recurve_continuous = false
			break
	report.check(
		rope_is_driving
		and recurve_armed
		and whip.get_sweep_id() == sweep_before + 1
		and recurve_continuous
		and whip.get_point_count() == before_recurve.size(),
		"RECURVE reverses the continuously simulated Vine without resetting its momentum"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.RECURVE] = 0

	# Twining's repeat is a stroke of the same body, not a second Vine.
	prototype.progression._owned_relics[RelicCatalog.Id.TWINING] = 1
	for _twine_settle in range(10):
		prototype.combat.simulate_step(1.0 / 60.0)
	var before_twining := whip.points.duplicate()
	var twining_sweep_before := whip.get_sweep_id()
	prototype.combat.perform_bonus_cane_sweep(
		Vector2.RIGHT, true, vine.twining_damage_share
	)
	var twining_continuous := true
	for point_index in range(before_twining.size()):
		if not before_twining[point_index].is_equal_approx(whip.points[point_index]):
			twining_continuous = false
			break
	report.check(
		whip.get_sweep_id() == twining_sweep_before + 1
		and twining_continuous
		and whip.get_point_count() == before_twining.size(),
		"TWINING repeats on the persistent Vine state rather than spawning a second one"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.TWINING] = 0

	# Liana's cascade is four strokes of one rope, alternating, with the body never
	# rebuilt between them.
	prototype.progression._owned_relics[RelicCatalog.Id.LIANA] = 1
	vine.reset_adaptations()
	for _liana_settle in range(10):
		prototype.combat.simulate_step(1.0 / 60.0)
	var liana_points_before := whip.get_point_count()
	var liana_sweep_before := whip.get_sweep_id()
	vine._liana_remaining = vine.liana_bonus_sweeps
	vine._liana_step = 0.0
	vine._liana_facing = Vector2.RIGHT
	var liana_rebuilt := false
	for _liana_tick in range(int(vine.liana_interval_seconds * 60.0) * 6 + 30):
		vine._advance_vine_relics(1.0 / 60.0)
		if whip.get_point_count() != liana_points_before:
			liana_rebuilt = true
	report.check(
		whip.get_sweep_id() - liana_sweep_before == vine.liana_bonus_sweeps
		and not liana_rebuilt
		and vine._liana_remaining == 0,
		"LIANA drives exactly four alternating strokes through one continuous Vine body"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.LIANA] = 0

	# Climber reads a real wrap, not a sharp curve. A rope whipping through open
	# ground bends hard under its own momentum and must never read as wrapped.
	prototype.progression._owned_relics[RelicCatalog.Id.CLIMBER] = 1
	var open_wrap := whip.is_wrapped()
	var curved_hard := whip.get_bend_count() > 0
	vine._sweep_bend_index = whip.get_wrap_index()
	var climber_armed_in_the_open := vine._sweep_bend_index >= 0
	report.check(
		not open_wrap and not climber_armed_in_the_open,
		"CLIMBER reads an actual wrap rather than a rope merely bent by its own swing"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.CLIMBER] = 0

	vine.reset_adaptations()
	prototype.combat.reset_combat()
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()

	# Snare Vine spreads a capped share of a root to the nearest few enemies.
	prototype.combat.reset_combat()
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.SNARE_VINE] = 1
	relics.apply_relics()
	var snare_ids := PackedInt32Array()
	for snare_index in range(4):
		snare_ids.append(prototype.combat.spawn_enemy(
			EnemyKinds.Role.HUNTER,
			lone_spot + Vector2.from_angle(float(snare_index) * 1.2) * 30.0
		))
	prototype.combat.enemy_ensnared.emit(lone_spot)
	var snared := 0
	for snare_id in snare_ids:
		if prototype.combat.get_enemy_entanglement(snare_id) > 0.0:
			snared += 1
	report.check(
		snared > 0 and snared <= relics.snare_vine_targets,
		"SNARE VINE spreads Entanglement to a capped number of neighbours"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.SNARE_VINE] = 0
	prototype.combat.reset_combat()

	# Gleaning Hook banks Charge off ring kills, capped per hold.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.PRUNING,
		Progression.PathId.SPORE
	)
	prototype.progression._owned_relics[RelicCatalog.Id.GLEANING_HOOK] = 1
	prototype._apply_progression_modifiers()
	relics.apply_relics()
	var gleaning := prototype.pruning_director
	gleaning.reset_director()
	gleaning._charge = 0.0
	var payouts := int(ceil(gleaning.gleaning_hook_maximum / gleaning.gleaning_hook_charge)) + 2
	for _gleaning_kill in range(gleaning.gleaning_hook_kills * payouts):
		gleaning.notify_ring_kill(false)
	report.check(
		gleaning.get_gleaning_banked_charge() > 0.0
		and gleaning.get_gleaning_banked_charge()
		<= gleaning.gleaning_hook_maximum + 0.0001,
		"GLEANING HOOK banks Charge from ring kills and stops at its cap"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.GLEANING_HOOK] = 0

	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
	relics.reset_director()
	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	prototype.territory_field.reset_field()
