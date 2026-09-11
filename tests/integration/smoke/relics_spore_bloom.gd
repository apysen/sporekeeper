## The relics of the two paths that put something in the ground: a Seed that has to
## survive long enough to open, and a Bloom that has to be worth the ground it takes.
##
## Almost every one of these is a proc with a limiter on it, so each block drives the
## trigger twice - once to earn it and once to prove the limiter holds. A relic engine
## that feeds itself is the failure this catalog exists to guard against.
class_name SmokeRelicsSporeBloom
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot, relics: RelicDirector, lone_spot: Vector2) -> void:
	# ------------------------------------------------------------- Spore relics
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
