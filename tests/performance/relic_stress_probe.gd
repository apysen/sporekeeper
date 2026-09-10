extends SceneTree

## The relic stress fixtures docs/relics.md asks for.
##
## The general performance probe answers "does a crowded battlefield fit in a
## frame". This answers a different question: does each pool's worst build fit in
## a frame while its relics are all firing at once. Those are the cases where the
## per-relic caps and the global generated-event scheduler are actually load
## bearing, and the only way to know they hold is to build them and look.
##
## Every scenario reports the same row -- average, p95, p99 and peak frame time,
## what was on the field, and what the generated-event queue did -- so a
## regression shows up as a number moving rather than as a pass turning into a
## fail on one threshold.

const TARGET_FRAME_MS := 16.67
## Frames sampled per scenario. Long enough for cadences measured in seconds to
## fire several times at the simulated step below.
const SAMPLE_FRAMES := 150
const STEP := 1.0 / 60.0

var _failures := 0
var _rows: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_error := change_scene_to_file("res://scenes/run/run.tscn")
	if load_error != OK:
		push_error("Unable to load Sporekeeper run: %s" % error_string(load_error))
		quit(1)
		return
	await process_frame
	await process_frame
	var prototype := current_scene as RunRoot
	if prototype == null:
		push_error("Sporekeeper run scene did not become current")
		quit(1)
		return
	# Only the prototype's own _process is disabled, so the fixture controls the
	# clock. Combat, the Adaptation director and the overlay are driven below
	# exactly as a real frame drives them -- pausing the simulation here would
	# freeze the very systems the relics act through, and measure nothing.
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.combat.set_process(false)
	prototype.adaptation_director.set_process(false)
	prototype.overlay.set_process(false)

	_run_scenario(prototype, "1 crowd", [], [], 100, 0.0)
	_run_scenario(
		prototype,
		"2 thistle",
		[Progression.PathId.THISTLE, Progression.PathId.SPORE],
		[
			RelicCatalog.Id.CROWN_OF_THORNS,
			RelicCatalog.Id.FORKING_PATTERN,
			RelicCatalog.Id.PHYLLOTAXIS,
			RelicCatalog.Id.THORN_RELAY,
			RelicCatalog.Id.PINCUSHION,
			RelicCatalog.Id.ANSWERING_THORN,
		],
		80,
		0.0
	)
	_run_scenario(
		prototype,
		"3 spore",
		[Progression.PathId.SPORE, Progression.PathId.BLOOM],
		[
			RelicCatalog.Id.DOMINO_GERMINATION,
			RelicCatalog.Id.WINDBORNE,
			RelicCatalog.Id.VOLUNTEER,
			RelicCatalog.Id.PUFFBALL,
			RelicCatalog.Id.SPORE_BURST,
			RelicCatalog.Id.CROSS_POLLINATION,
		],
		80,
		0.0
	)
	_run_scenario(
		prototype,
		"4 bloom",
		[Progression.PathId.BLOOM, Progression.PathId.SPORE],
		[
			RelicCatalog.Id.FLOWERING_FRONT,
			RelicCatalog.Id.CHAIN_BLOOM,
			RelicCatalog.Id.SUPERBLOOM,
			RelicCatalog.Id.PETAL_SCATTER,
			RelicCatalog.Id.OVERKILL,
			RelicCatalog.Id.PERENNIAL,
		],
		90,
		0.0
	)
	_run_scenario(
		prototype,
		"5 pruning",
		[Progression.PathId.PRUNING, Progression.PathId.SPORE],
		[
			RelicCatalog.Id.WATERSPROUTS,
			RelicCatalog.Id.RETURN_STROKE,
			RelicCatalog.Id.BRUSH_PILE,
			RelicCatalog.Id.STUBBLE,
			RelicCatalog.Id.SKIMMING_CUT,
			RelicCatalog.Id.GREEN_MANURE,
		],
		80,
		0.0
	)
	_run_scenario(
		prototype,
		"6 vine",
		[Progression.PathId.VINE, Progression.PathId.SPORE],
		[
			RelicCatalog.Id.LIANA,
			RelicCatalog.Id.TWINING,
			RelicCatalog.Id.WHIPLASH,
			RelicCatalog.Id.CLIMBER,
			RelicCatalog.Id.GIRDLING,
			RelicCatalog.Id.TRELLIS,
		],
		80,
		184.0
	)
	_run_scenario(
		prototype,
		"7 fruit",
		[Progression.PathId.FRUIT, Progression.PathId.SPORE],
		[
			RelicCatalog.Id.NEWTONS_APPLE,
			RelicCatalog.Id.WINDFALL,
			RelicCatalog.Id.STEM_STEERING,
			RelicCatalog.Id.FRUIT_SALAD,
			RelicCatalog.Id.BRUISED_FRUIT,
			RelicCatalog.Id.BANK_SHOT,
		],
		100,
		0.0
	)
	# Hybrid Vigor duplicating a high-load Rare, across pools: the scheduler is the
	# only thing standing between this and an unbounded chain.
	_run_scenario(
		prototype,
		"8 hybrid",
		[Progression.PathId.BRAMBLE, Progression.PathId.SPORE],
		[
			RelicCatalog.Id.HYBRID_VIGOR,
			RelicCatalog.Id.BRIARBALL,
			RelicCatalog.Id.SNARE_VINE,
			RelicCatalog.Id.HOOKTHORN,
			RelicCatalog.Id.THORNBACK,
			RelicCatalog.Id.COMPOST_HEAP,
		],
		100,
		0.0
	)

	for row in _rows:
		print(row)
	prototype.queue_free()
	await process_frame
	if _failures == 0:
		print("RELIC_STRESS: PASS")
		quit(0)
		return
	push_error("RELIC_STRESS: %d scenario(s) over the frame budget" % _failures)
	quit(1)


func _run_scenario(
	prototype: RunRoot,
	label: String,
	paths: Array,
	relics: Array,
	enemies: int,
	vine_reach: float
) -> void:
	prototype.reset_run()
	prototype.progression.reset_progression()
	if paths.size() == 2:
		prototype.progression.offer_pruning_path = true
		prototype.progression.debug_select_paths(paths[0], paths[1])
	for relic_id in relics:
		prototype.progression._owned_relics[relic_id] = 1
	# Every line maxed, so the build is the worst case of itself rather than an
	# average one that happens to hold the relics.
	for upgrade_id in range(Progression.UpgradeId.size()):
		if paths.size() == 2 and prototype.progression._get_upgrade_path(upgrade_id) in paths:
			prototype.progression._upgrade_levels[upgrade_id] = (
				prototype.progression.maximum_upgrade_level
			)
	prototype._apply_progression_modifiers()
	prototype.relic_director.apply_relics()
	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()

	var origin := Vector2(320.0, 300.0)
	prototype.player.global_position = prototype.territory_field.to_global(origin)
	if vine_reach > 0.0 and prototype.combat.vine_whip != null:
		prototype.combat.vine_whip.build(origin, vine_reach)
	# Tightly bunched, which is the shape every cap in the document is written for.
	for index in range(enemies):
		var ring := 26.0 + float(index % 5) * 16.0
		prototype.combat.spawn_enemy(
			EnemyKinds.Role.HUNTER,
			origin + Vector2.from_angle(float(index) * 2.39996) * ring
		)
	prototype.combat.simulate_step(0.0)

	var samples := PackedFloat32Array()
	for frame_index in range(SAMPLE_FRAMES):
		# Hold the crowd up. These builds clear a static field in a couple of
		# seconds, and a fixture that spends most of its frames on an empty board is
		# measuring the aftermath rather than the pressure the document describes.
		_top_up(prototype, origin, enemies)
		var began := Time.get_ticks_usec()
		prototype.advance_run(STEP)
		prototype.combat.simulate_step(STEP)
		prototype.adaptation_director.advance(STEP)
		prototype.overlay._process(STEP)
		if frame_index % 4 == 0:
			prototype.territory_field.step_simulation()
		samples.append(float(Time.get_ticks_usec() - began) / 1000.0)
	_report(prototype, label, samples)


func _top_up(prototype: RunRoot, origin: Vector2, wanted: int) -> void:
	var missing := wanted - prototype.combat.get_active_enemy_count()
	# A few per frame rather than the whole shortfall at once, so the refill is not
	# itself the spike being measured.
	for index in range(mini(missing, 4)):
		var ring := 26.0 + float((prototype.combat.get_active_enemy_count() + index) % 5) * 16.0
		prototype.combat.spawn_enemy(
			EnemyKinds.Role.HUNTER,
			origin + Vector2.from_angle(
				float(prototype.combat.get_active_enemy_count() + index) * 2.39996
			) * ring
		)


func _report(prototype: RunRoot, label: String, samples: PackedFloat32Array) -> void:
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for value in samples:
		total += value
	var average := total / float(maxi(1, samples.size()))
	var peak := sorted[sorted.size() - 1]
	var relics := prototype.relic_director
	var blooms := prototype.bloom_director
	_rows.append(
		(
			"RELIC_STRESS %-10s avg=%.3fms p95=%.3fms p99=%.3fms peak=%.3fms "
			+ "enemies=%d effects=%d queue=%d/%d staggered=%d dropped=%d blooms=%d/%d"
		) % [
			label,
			average,
			_percentile(sorted, 0.95),
			_percentile(sorted, 0.99),
			peak,
			prototype.combat.get_active_enemy_count(),
			prototype.combat.get_active_projectile_count()
				+ prototype.overlay.get_active_seed_count()
				+ prototype.overlay.get_active_bloom_count(),
			relics.get_generated_queue_depth(),
			relics.get_generated_peak_depth(),
			relics.get_generated_staggered_count() + blooms.get_staggered_detonation_count(),
			relics.get_generated_dropped_count(),
			blooms.get_pending_detonation_count(),
			blooms.get_relic_bud_count(),
		]
	)
	# A fixture that produced no activity is not evidence of anything. Catching that
	# here is the difference between "this build is cheap" and "this build never ran".
	var effects := (
		prototype.combat.get_active_projectile_count()
		+ prototype.overlay.get_active_seed_count()
		+ prototype.overlay.get_active_bloom_count()
	)
	if effects <= 0 and prototype.combat.get_active_enemy_count() <= 0:
		_failures += 1
		push_error("RELIC_STRESS %s: fixture produced no activity to measure" % label)
	# p95 is what is asserted, not the average. One frame in twenty over budget is a
	# visible stutter, and a build whose average fits only because most of its frames
	# are quiet is exactly the case these fixtures exist to catch. The lone peak is
	# reported rather than failed on: a fixture's first frame is not the game's
	# worst frame.
	var p95 := _percentile(sorted, 0.95)
	if p95 > TARGET_FRAME_MS:
		_failures += 1
		push_error(
			"RELIC_STRESS %s: p95 %.3fms over the %.2fms budget (avg %.3fms, peak %.3fms)"
			% [label, p95, TARGET_FRAME_MS, average, peak]
		)
	if relics.get_generated_dropped_count() > 0:
		# Not a failure: the scheduler is allowed to drop under genuine overload, and
		# the document says the rarest survive. It is reported because a fixture that
		# starts dropping is telling us something changed.
		print(
			"RELIC_STRESS %s: scheduler dropped %d generated events"
			% [label, relics.get_generated_dropped_count()]
		)


func _percentile(sorted: PackedFloat32Array, share: float) -> float:
	if sorted.is_empty():
		return 0.0
	var index := int(floor(clampf(share, 0.0, 1.0) * float(sorted.size() - 1)))
	return sorted[clampi(index, 0, sorted.size() - 1)]
