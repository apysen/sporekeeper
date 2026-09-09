extends SceneTree

## What each named fixture costs as the crowd grows, with the subsystem split.
##
## The peak density probe answers one question well -- "does any of the 28
## pairings blow the budget at the shipping cap" -- and it answers it at exactly
## one density. That is the right shape for a regression gate and the wrong shape
## for deciding what the cap should be, because a subsystem that is linear in
## enemy count and one that is quadratic in it look identical at a single point.
##
## This probe runs the optimization guide's six named fixtures up a density ladder
## and reports the per-subsystem counters at every rung, so the scaling curve is
## visible rather than inferred. It is a measurement tool, not a pass/fail gate:
## it always exits zero unless the fixture itself fails to build. The gate stays
## in peak_density_probe.gd.
##
## Run:
##   godot --headless --script tests/density_ladder_probe.gd
##   godot --headless --script tests/density_ladder_probe.gd -- --densities=130,200 --fixtures=D
##   godot --headless --script tests/density_ladder_probe.gd -- --csv=user://ladder.csv

## Overridable with --frames=, because the churn fixture needs far longer than the
## others: it is the only one whose enemy count is an outcome rather than a setting,
## and ten seconds is not enough to see where that count is heading.
static var SAMPLE_FRAMES := 600
const STEP := 1.0 / 60.0
const TARGET_FRAME_MS := 16.67

## Frames run and discarded before sampling starts. The first frame of a fixture
## pays for things no later frame does -- the first volley, pools reaching their
## working size, caches filling -- and it was landing as the worst frame in the
## sample, which made the worst-frame breakdown describe start-up rather than
## steady-state combat. Half a second is enough to get past it without hiding the
## second-scale cadences the sample exists to catch.
const WARMUP_FRAMES := 30

## The guide's ladder. Each rung is only meaningful once the one below it is
## stable, so the table is read upward from the current cap rather than as a
## prediction that the top rung is reachable today.
static var DEFAULT_DENSITIES := PackedInt32Array([130, 160, 200, 250, 300])

## The crowd's role mix. Warden and Siege Corruptor are kept in deliberately: they
## are excluded from the baked enemy art and always draw in full detail, so a mix
## without them measures an enemy population the game never actually fields.
const STRESS_ROLES := [
	CombatDirector.EnemyRole.HUNTER,
	CombatDirector.EnemyRole.GRAZER,
	CombatDirector.EnemyRole.HEAVY_GRAZER,
	CombatDirector.EnemyRole.RUSHER,
	CombatDirector.EnemyRole.SABOTEUR,
	CombatDirector.EnemyRole.CORRUPTOR,
	CombatDirector.EnemyRole.COLONIZER,
	CombatDirector.EnemyRole.WARDEN,
	CombatDirector.EnemyRole.SIEGE_CORRUPTOR,
]

const PLANT_RELIC_COUNT := 5
const PRIMARY_RELIC_COUNT := 5
const SECONDARY_RELIC_COUNT := 4

## The six fixtures the guide names. Each isolates one thing:
##
##   A  base enemy scaling with nothing else running
##   B  Thistle volley p99 on its own
##   C  TerritoryField write cost on its own
##   D  both current bottlenecks together -- the torture test
##   E  Thistle volleys against high-frequency Vine collision
##   F  the Root projection win, kept permanently so Territory work cannot
##      quietly undo it
##   G  the same torture as D, but with a crowd that actually dies
##
## `paths` of [-1, -1] means an undrafted run: no Adaptation, no relics.
##
## Fixtures A to F hold density by making the crowd unkillable, which keeps the
## enemy count flat for the whole sample and is why their numbers are comparable.
## It also means they never run a death: no XP pickup, no volatile detonation, no
## overgrown burst, no kill signals, and -- the one that matters most -- no Seeds,
## since a Seed is paid for in kills and a Seed is a territory stamp. That is half
## of `_damage_enemy` and a whole gameplay loop, and none of it had been measured.
##
## G lets the crowd die and replaces it at the Campaign's own spawn interval rather
## than instantly. Refilling to full every frame was tried first and produced about
## 174 spawns a second against the Campaign's eight, which measured a crowd being
## annihilated and instantly resurrected -- a scenario the wave director cannot
## produce. Held to the real rate, density finds its own level, and where it settles
## is itself a result: a build that kills faster than the director spawns does not
## sit at the cap.
const FIXTURES := {
	"A": {
		"name": "generic_saturation",
		"paths": [-1, -1],
		"relics": false,
	},
	"B": {
		"name": "max_thistle",
		"paths": [Progression.PathId.THISTLE, Progression.PathId.BRAMBLE],
		"relics": true,
	},
	"C": {
		"name": "max_fruit",
		"paths": [Progression.PathId.FRUIT, Progression.PathId.BLOOM],
		"relics": true,
	},
	"D": {
		"name": "thistle_fruit",
		"paths": [Progression.PathId.THISTLE, Progression.PathId.FRUIT],
		"relics": true,
	},
	"E": {
		"name": "thistle_vine",
		"paths": [Progression.PathId.THISTLE, Progression.PathId.VINE],
		"relics": true,
	},
	"F": {
		"name": "root_fruit",
		"paths": [Progression.PathId.ROOT, Progression.PathId.FRUIT],
		"relics": true,
	},
	"G": {
		"name": "thistle_fruit_churn",
		"paths": [Progression.PathId.THISTLE, Progression.PathId.FRUIT],
		"relics": true,
		"churn": true,
	},
}

## The Campaign's final-invasion spawn cadence, which is the fastest the director
## ever replaces losses: a pack of three every 0.14 seconds, about 21 enemies a
## second. Fixture G refills at this rate and no faster.
##
## The pack size matters and was missed at first. The director calls `spawn_pack`,
## not `spawn_enemy`, so refilling one at a time ran at a third of the real rate and
## reported a crowd that collapsed further than it should have.
const CHURN_SPAWN_INTERVAL := 0.14
const CHURN_PACK_SIZE := 3

const FIXTURE_ORDER := ["A", "B", "C", "D", "E", "F", "G"]

var _churn_budget := 0.0

var _densities := DEFAULT_DENSITIES
var _fixture_keys: Array[String] = []
var _csv_path := ""
var _csv_rows: Array[String] = []
var _table_rows: Array[String] = []
var _commit := "unknown"


func _initialize() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	_parse_arguments()
	_commit = _read_commit()

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

	# The fixture owns the clock, exactly as the peak density probe does, so the
	# subsystem split is a real split rather than whatever order _process ran in.
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.combat.set_process(false)
	prototype.adaptation_director.set_process(false)
	prototype.overlay.set_process(false)
	prototype.player.maximum_health = 1000000000.0
	prototype.player.reset_player()

	print(
		"DENSITY_LADDER: %d fixture(s) x %d densities, %d frames each"
		% [_fixture_keys.size(), _densities.size(), SAMPLE_FRAMES]
	)
	_append_csv_header()

	for fixture_key in _fixture_keys:
		for density in _densities:
			await _run_fixture(prototype, fixture_key, density)

	_print_report()
	_write_csv()

	prototype.queue_free()
	await process_frame
	quit(0)


func _parse_arguments() -> void:
	for key in FIXTURE_ORDER:
		_fixture_keys.append(key)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--densities="):
			var wanted := PackedInt32Array()
			for piece in argument.trim_prefix("--densities=").split(",", false):
				var value := int(piece.strip_edges())
				if value > 0:
					wanted.append(value)
			if not wanted.is_empty():
				_densities = wanted
		elif argument.begins_with("--fixtures="):
			var chosen: Array[String] = []
			for piece in argument.trim_prefix("--fixtures=").split(",", false):
				var key := piece.strip_edges().to_upper()
				if FIXTURES.has(key):
					chosen.append(key)
			if not chosen.is_empty():
				_fixture_keys = chosen
		elif argument.begins_with("--frames="):
			var frames := int(argument.trim_prefix("--frames=").strip_edges())
			if frames > 0:
				SAMPLE_FRAMES = frames
		elif argument.begins_with("--csv="):
			_csv_path = argument.trim_prefix("--csv=").strip_edges()


func _read_commit() -> String:
	# Best effort. A row without a commit is still a usable measurement; a row
	# claiming the wrong commit is worse than one admitting it does not know.
	var output := []
	var status := OS.execute("git", ["rev-parse", "--short", "HEAD"], output, true)
	if status != 0 or output.is_empty():
		return "unknown"
	return String(output[0]).strip_edges()


func _run_fixture(prototype: RunRoot, fixture_key: String, density: int) -> void:
	var fixture: Dictionary = FIXTURES[fixture_key]
	var paths: Array = fixture["paths"]
	var first_path := int(paths[0])
	var second_path := int(paths[1])
	var drafted := first_path >= 0

	prototype.reset_run()
	prototype.progression.reset_progression()
	if drafted:
		prototype.progression.debug_select_paths(first_path, second_path)
		prototype.progression.debug_complete_evolution_requirements()
		prototype.progression.grant_evolution_if_ready()
		prototype.progression.debug_select_tertiary_path(
			_support_path_for(first_path, second_path)
		)
		for upgrade_id in range(Progression.UpgradeId.size()):
			var path_id := prototype.progression._get_upgrade_path(upgrade_id)
			if prototype.progression.has_path(path_id):
				prototype.progression._upgrade_levels[upgrade_id] = (
					prototype.progression.maximum_upgrade_level
				)
		if bool(fixture["relics"]):
			for relic_id in _relics_for(first_path, second_path):
				prototype.progression._owned_relics[relic_id] = 1
	prototype._apply_progression_modifiers()
	prototype.relic_director.apply_relics()

	prototype.wave_director.configure_mode(RunMode.Id.CAMPAIGN)
	prototype.wave_director.reset_director()
	prototype.wave_director.debug_advance_time(
		prototype.wave_director.final_invasion_time_seconds
	)

	# The shipped pool holds 160. Every rung above that has to grow it before the
	# crowd can exist, and growing it is the point: an enemy the pool cannot hold
	# is an enemy the measurement silently does not include.
	if density > prototype.combat.enemy_pool_size:
		prototype.combat.enemy_pool_size = density
		prototype.combat._configure_pools()
	prototype.combat.maximum_active_enemies = density

	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	prototype.combat.debug_fill_stress(
		0,
		prototype.combat.projectile_pool_size,
		prototype.combat.pickup_pool_size
	)

	var origin := Vector2(320.0, 300.0)
	prototype.player.global_position = prototype.territory_field.to_global(origin)
	for index in range(density):
		var ring := 30.0 + float(index % 7) * 22.0
		prototype.combat.spawn_enemy(
			STRESS_ROLES[index % STRESS_ROLES.size()],
			origin + Vector2.from_angle(float(index) * 2.39996) * ring
		)
	var spawned := prototype.combat.get_active_enemy_count()
	if spawned < density:
		push_warning(
			"DENSITY_LADDER: fixture %s wanted %d enemies, placed %d"
			% [fixture_key, density, spawned]
		)
	var churn := bool(fixture.get("churn", false))
	if not churn:
		# Unkillable, so the crowd holds at the rung for the whole sample instead of
		# thinning into an easier frame partway through.
		for enemy in prototype.combat._enemies:
			if not enemy.active:
				continue
			enemy.maximum_health = 1000000000.0
			enemy.health = enemy.maximum_health
	var holds_vine := (
		first_path == Progression.PathId.VINE
		or second_path == Progression.PathId.VINE
	)
	if holds_vine and prototype.combat.vine_whip != null:
		prototype.combat.vine_whip.build(origin, prototype.combat.get_cane_reach())
	prototype.combat.simulate_step(0.0)

	var total := PackedFloat32Array()
	var samples := {}
	for timer in PerfCounters.TIMER_NAMES:
		samples[timer] = PackedFloat32Array()
	var counter_totals := {}
	var counter_peaks := {}
	for counter in PerfCounters.COUNT_NAMES:
		counter_totals[counter] = 0
		counter_peaks[counter] = 0

	var worst_frame_ms := -1.0
	var worst_frame_index := -1
	var worst_frame := {}

	## Enemy count sampled through the run, so convergence can be seen rather than
	## inferred from where the count happened to be when the sample stopped.
	var density_trace := PackedInt32Array()
	var phase_run := PackedFloat32Array()
	var phase_combat := PackedFloat32Array()
	var phase_relics := PackedFloat32Array()
	var phase_adaptation := PackedFloat32Array()
	var phase_overlay := PackedFloat32Array()
	var phase_territory := PackedFloat32Array()

	_churn_budget = 0.0
	for _warmup_index in range(WARMUP_FRAMES):
		if churn:
			_refill(prototype, density, origin, STEP)
		prototype.advance_run(STEP)
		prototype.combat.simulate_step(STEP)
		prototype.relic_director.advance(STEP)
		prototype.adaptation_director.advance(STEP)
		prototype.overlay._process(STEP)
		if _warmup_index % 2 == 0:
			prototype.territory_field.step_simulation()
		else:
			prototype.territory_field.refresh_visuals_now()

	PerfCounters.begin_session()
	for frame_index in range(SAMPLE_FRAMES):
		PerfCounters.reset_frame()
		if churn:
			# Replacing losses before the frame runs, at the director's own rate. The
			# spawns land outside the measured phases below.
			_refill(prototype, density, origin, STEP)
		var frame_began := Time.get_ticks_usec()

		# The five top-level phases, timed here rather than in the game, because the
		# probe is what drives them one at a time. Without these the worst frame
		# reports most of itself as unattributed: the in-game counters only cover the
		# subsystems that have been suspected so far, which is exactly the bias that
		# makes a frame look mysterious.
		var phase_began := Time.get_ticks_usec()
		prototype.advance_run(STEP)
		phase_run.append(_ms_since(phase_began))

		phase_began = Time.get_ticks_usec()
		prototype.combat.simulate_step(STEP)
		phase_combat.append(_ms_since(phase_began))

		phase_began = Time.get_ticks_usec()
		prototype.relic_director.advance(STEP)
		phase_relics.append(_ms_since(phase_began))

		phase_began = Time.get_ticks_usec()
		prototype.adaptation_director.advance(STEP)
		phase_adaptation.append(_ms_since(phase_began))

		phase_began = Time.get_ticks_usec()
		prototype.overlay._process(STEP)
		phase_overlay.append(_ms_since(phase_began))
		# The field runs at its own rate, and the two halves alternate so one frame
		# never pays for both. Matching the peak density probe keeps the two tables
		# comparable.
		if churn and frame_index % 60 == 0:
			density_trace.append(prototype.combat.get_active_enemy_count())

		phase_began = Time.get_ticks_usec()
		# One territory operation per frame, alternating, because that is what the
		# field does when it runs itself. Its tuning is 30Hz simulation and 30Hz
		# render, so at 60fps both come due every other frame and its own _process
		# alternates them -- which works out to one or the other on every frame.
		# Stepping one frame in four, as this probe did originally, ran territory at
		# half the rate the game does and made every territory-heavy number optimistic.
		if frame_index % 2 == 0:
			prototype.territory_field.step_simulation()
		else:
			prototype.territory_field.refresh_visuals_now()
		phase_territory.append(_ms_since(phase_began))

		var frame_ms := float(Time.get_ticks_usec() - frame_began) / 1000.0
		total.append(frame_ms)
		# Percentiles are taken per subsystem, so the p99 of one bar and the p99 of
		# another need not come from the same frame -- which makes them useless for
		# asking what the slow frame actually did. Keep the worst frame's own
		# breakdown alongside them.
		if frame_ms > worst_frame_ms:
			worst_frame_ms = frame_ms
			worst_frame_index = frame_index
			worst_frame = PerfCounters.snapshot()
		for timer in PerfCounters.TIMER_NAMES:
			samples[timer].append(PerfCounters.get_timer_ms(timer))
		for counter in PerfCounters.COUNT_NAMES:
			var value := PerfCounters.get_count(counter)
			counter_totals[counter] = int(counter_totals[counter]) + value
			counter_peaks[counter] = maxi(int(counter_peaks[counter]), value)
	PerfCounters.end_session()

	_record(
		fixture_key,
		fixture,
		density,
		spawned,
		total,
		samples,
		counter_totals,
		counter_peaks
	)
	# Printed before the in-game bars, because these five account for the whole
	# frame by construction and the in-game counters are a breakdown inside them.
	_table_rows.append("DENSITY_LADDER   phases (median / p99):")
	for phase in [
		["run", phase_run],
		["combat.simulate_step", phase_combat],
		["relic_director", phase_relics],
		["adaptation_director", phase_adaptation],
		["overlay", phase_overlay],
		["territory", phase_territory],
	]:
		var phase_samples: PackedFloat32Array = phase[1]
		_table_rows.append(
			"DENSITY_LADDER     %-38s %8.3f %8.3f" % [
				phase[0], _median(phase_samples), _p99(phase_samples)
			]
		)
	if churn:
		# The crowd size is an outcome here, not a setting: the fixture starts full
		# and the build kills faster than the director replaces. A single endpoint
		# cannot say whether that has levelled off, so the whole trace is reported
		# and the last quarter of it is compared against the quarter before -- if the
		# two agree the count has stopped moving, and if they do not it is still
		# falling and no number from this run is an equilibrium.
		var trace := ""
		for count in density_trace:
			trace += "%d " % count
		_table_rows.append(
			"DENSITY_LADDER   enemies each second: %s" % trace.strip_edges()
		)
		if density_trace.size() >= 8:
			var quarter := density_trace.size() / 4
			var late := 0.0
			var earlier := 0.0
			for offset in range(quarter):
				late += float(density_trace[density_trace.size() - 1 - offset])
				earlier += float(
					density_trace[density_trace.size() - 1 - quarter - offset]
				)
			late /= float(quarter)
			earlier /= float(quarter)
			var drift := late - earlier
			# Judged against the series' own variability, not a fixed percentage. The
			# count oscillates by fifteen or more as waves land and are cleared, so a
			# drift of five is noise here and would be a trend in a steadier signal.
			# A fixed threshold called a converged run "still moving".
			var mean := 0.0
			for count in density_trace:
				mean += float(count)
			mean /= float(density_trace.size())
			var variance := 0.0
			for count in density_trace:
				variance += (float(count) - mean) * (float(count) - mean)
			var deviation := sqrt(variance / float(density_trace.size()))
			_table_rows.append(
				(
					"DENSITY_LADDER   last quarter %.1f vs previous %.1f (drift %+.1f, "
					+ "sd %.1f) -- %s"
				) % [
					late,
					earlier,
					drift,
					deviation,
					(
						"levelled off, drift is inside the noise"
						if absf(drift) < deviation
						else "still trending, not an equilibrium"
					),
				]
			)
	_record_worst_frame(fixture_key, worst_frame_index, worst_frame_ms, worst_frame)
	await process_frame


func _record(
	fixture_key: String,
	fixture: Dictionary,
	density: int,
	spawned: int,
	total: PackedFloat32Array,
	samples: Dictionary,
	counter_totals: Dictionary,
	counter_peaks: Dictionary
) -> void:
	var sorted := total.duplicate()
	sorted.sort()
	var median := _percentile(sorted, 0.50)
	var p95 := _percentile(sorted, 0.95)
	var p99 := _percentile(sorted, 0.99)
	var maximum := _percentile(sorted, 1.0)
	var over_16 := _count_over(total, TARGET_FRAME_MS)
	var over_25 := _count_over(total, 25.0)
	var over_33 := _count_over(total, 33.33)
	var label := "%s/%s" % [fixture_key, fixture["name"]]

	_table_rows.append(
		"DENSITY_LADDER %-20s %4d %8.3f %8.3f %8.3f %8.3f %5d %5d %5d" % [
			label,
			spawned,
			median,
			p95,
			p99,
			maximum,
			over_16,
			over_25,
			over_33,
		]
	)
	# The subsystems that actually ran, so an undrafted fixture does not print
	# twenty-one zero rows under itself.
	for timer in PerfCounters.TIMER_NAMES:
		var timer_samples: PackedFloat32Array = samples[timer]
		var timer_p99 := _p99(timer_samples)
		var timer_median := _median(timer_samples)
		if timer_p99 <= 0.0005 and timer_median <= 0.0005:
			continue
		_table_rows.append(
			"DENSITY_LADDER   %-40s %8.3f %8.3f" % [timer, timer_median, timer_p99]
		)
	for counter in PerfCounters.COUNT_NAMES:
		var counter_total := int(counter_totals[counter])
		if counter_total <= 0:
			continue
		_table_rows.append(
			"DENSITY_LADDER   %-40s %8.1f/frame  peak %d" % [
				counter,
				float(counter_total) / float(SAMPLE_FRAMES),
				int(counter_peaks[counter]),
			]
		)

	# One CSV row per subsystem, plus a "frame" row for the whole frame, so a
	# spreadsheet can pivot on subsystem_name without reshaping anything.
	_append_csv_row(
		fixture_key, fixture, density, spawned,
		median, p95, p99, maximum, over_16, over_25, over_33,
		"frame", median, p99, 0
	)
	for timer in PerfCounters.TIMER_NAMES:
		var timer_samples: PackedFloat32Array = samples[timer]
		_append_csv_row(
			fixture_key, fixture, density, spawned,
			median, p95, p99, maximum, over_16, over_25, over_33,
			String(timer), _median(timer_samples), _p99(timer_samples), 0
		)
	for counter in PerfCounters.COUNT_NAMES:
		_append_csv_row(
			fixture_key, fixture, density, spawned,
			median, p95, p99, maximum, over_16, over_25, over_33,
			String(counter), 0.0, 0.0, int(counter_totals[counter])
		)


func _refill(
	prototype: RunRoot, density: int, origin: Vector2, delta: float
) -> void:
	var combat := prototype.combat
	_churn_budget += delta
	var index := combat.get_active_enemy_count()
	while (
		_churn_budget >= CHURN_SPAWN_INTERVAL
		and combat.get_active_enemy_count() < density
	):
		_churn_budget -= CHURN_SPAWN_INTERVAL
		for _member in range(CHURN_PACK_SIZE):
			if combat.get_active_enemy_count() >= density:
				break
			var ring := 30.0 + float(index % 7) * 22.0
			if combat.spawn_enemy(
				STRESS_ROLES[index % STRESS_ROLES.size()],
				origin + Vector2.from_angle(float(index) * 2.39996) * ring
			) < 0:
				return
			index += 1
	# A budget that keeps growing would let one quiet stretch pay for a burst that
	# the director could never deliver.
	_churn_budget = minf(_churn_budget, CHURN_SPAWN_INTERVAL)


func _record_worst_frame(
	fixture_key: String,
	frame_index: int,
	frame_ms: float,
	snapshot: Dictionary
) -> void:
	if snapshot.is_empty():
		return
	_table_rows.append(
		"DENSITY_LADDER   worst frame #%d = %.3fms, made of:" % [frame_index, frame_ms]
	)
	var accounted := 0.0
	for timer in PerfCounters.TIMER_NAMES:
		var value := float(snapshot.get(timer, 0.0))
		if value <= 0.0005:
			continue
		accounted += value
		_table_rows.append(
			"DENSITY_LADDER     %-38s %8.3f" % [timer, value]
		)
	# Nested timers double-count against the frame, so this is a guide to where the
	# frame went rather than a sum that must reconcile. What matters is whether the
	# named subsystems reach the frame at all or leave most of it unexplained.
	_table_rows.append(
		"DENSITY_LADDER     %-38s %8.3f (top-level bars only)" % [
			"unattributed",
			frame_ms - (
				float(snapshot.get(PerfCounters.TIMER_THISTLE_TOTAL, 0.0))
				+ float(snapshot.get(PerfCounters.TIMER_FRUIT_TOTAL, 0.0))
				+ float(snapshot.get(PerfCounters.TIMER_TERRITORY_TOTAL, 0.0))
				+ float(snapshot.get(PerfCounters.TIMER_TERRITORY_VISUAL_PAINT, 0.0))
				+ float(snapshot.get(PerfCounters.TIMER_ENEMY_MANAGER_TOTAL, 0.0))
			),
		]
	)
	for counter in PerfCounters.COUNT_NAMES:
		var count_value := int(snapshot.get(counter, 0))
		if count_value <= 0:
			continue
		_table_rows.append(
			"DENSITY_LADDER     %-38s %8d" % [counter, count_value]
		)


func _append_csv_header() -> void:
	_csv_rows.append(
		"git_commit,build_type,renderer,resolution,density,spawned,fixture,"
		+ "adaptation_a,adaptation_b,relic_fixture,median_ms,p95_ms,p99_ms,max_ms,"
		+ "frames_over_16_67,frames_over_25,frames_over_33,sample_frames,"
		+ "subsystem_name,subsystem_median_ms,subsystem_p99_ms,subsystem_count_total"
	)


func _append_csv_row(
	fixture_key: String,
	fixture: Dictionary,
	density: int,
	spawned: int,
	median: float,
	p95: float,
	p99: float,
	maximum: float,
	over_16: int,
	over_25: int,
	over_33: int,
	subsystem_name: String,
	subsystem_median: float,
	subsystem_p99: float,
	subsystem_count: int
) -> void:
	var paths: Array = fixture["paths"]
	var first_name := (
		Progression.get_path_name(int(paths[0])) if int(paths[0]) >= 0 else "none"
	)
	var second_name := (
		Progression.get_path_name(int(paths[1])) if int(paths[1]) >= 0 else "none"
	)
	_csv_rows.append(
		"%s,%s,%s,%s,%d,%d,%s,%s,%s,%s,%.4f,%.4f,%.4f,%.4f,%d,%d,%d,%d,%s,%.4f,%.4f,%d" % [
			_commit,
			"debug" if OS.is_debug_build() else "release",
			_renderer_name(),
			"headless",
			density,
			spawned,
			"%s_%s" % [fixture_key, fixture["name"]],
			first_name,
			second_name,
			"full14" if bool(fixture["relics"]) else "none",
			median,
			p95,
			p99,
			maximum,
			over_16,
			over_25,
			over_33,
			SAMPLE_FRAMES,
			subsystem_name,
			subsystem_median,
			subsystem_p99,
			subsystem_count,
		]
	)


func _renderer_name() -> String:
	return str(
		ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")
	)


func _print_report() -> void:
	print("")
	print(
		"DENSITY_LADDER %-20s %4s %8s %8s %8s %8s %5s %5s %5s" % [
			"fixture", "n", "median", "p95", "p99", "max", ">16", ">25", ">33"
		]
	)
	for row in _table_rows:
		print(row)
	print("")
	print("DENSITY_LADDER: measurement only, no budget asserted. The gate is peak_density_probe.")


func _write_csv() -> void:
	if _csv_path.is_empty():
		return
	var file := FileAccess.open(_csv_path, FileAccess.WRITE)
	if file == null:
		push_error(
			"DENSITY_LADDER: cannot write %s (%s)"
			% [_csv_path, error_string(FileAccess.get_open_error())]
		)
		return
	for row in _csv_rows:
		file.store_line(row)
	file.close()
	print("DENSITY_LADDER: wrote %d rows to %s" % [_csv_rows.size(), _csv_path])


func _support_path_for(first_path: int, second_path: int) -> int:
	for path_id in range(Progression.PathId.size()):
		if path_id != first_path and path_id != second_path:
			return path_id
	return Progression.PathId.SPORE


func _relics_for(first_path: int, second_path: int) -> Array[int]:
	var chosen: Array[int] = []
	_append_pool_relics(chosen, RelicCatalog.Pool.PLANT, PLANT_RELIC_COUNT)
	_append_pool_relics(chosen, _pool_for_path(first_path), PRIMARY_RELIC_COUNT)
	_append_pool_relics(chosen, _pool_for_path(second_path), SECONDARY_RELIC_COUNT)
	return chosen


func _append_pool_relics(chosen: Array[int], pool: int, wanted: int) -> void:
	var taken := 0
	for relic_id in range(RelicCatalog.get_count()):
		if taken >= wanted:
			return
		if RelicCatalog.get_pool(relic_id) != pool:
			continue
		chosen.append(relic_id)
		taken += 1


func _pool_for_path(path_id: int) -> int:
	match path_id:
		Progression.PathId.SPORE:
			return RelicCatalog.Pool.SPORE
		Progression.PathId.BLOOM:
			return RelicCatalog.Pool.BLOOM
		Progression.PathId.BRAMBLE:
			return RelicCatalog.Pool.BRAMBLE
		Progression.PathId.ROOT:
			return RelicCatalog.Pool.ROOT
		Progression.PathId.PRUNING:
			return RelicCatalog.Pool.PRUNING
		Progression.PathId.THISTLE:
			return RelicCatalog.Pool.THISTLE
		Progression.PathId.VINE:
			return RelicCatalog.Pool.VINE
		Progression.PathId.FRUIT:
			return RelicCatalog.Pool.FRUIT
	return RelicCatalog.Pool.PLANT


func _ms_since(began_usec: int) -> float:
	return float(Time.get_ticks_usec() - began_usec) / 1000.0


func _count_over(samples: PackedFloat32Array, budget_ms: float) -> int:
	var over := 0
	for value in samples:
		if value > budget_ms:
			over += 1
	return over


func _median(samples: PackedFloat32Array) -> float:
	var sorted := samples.duplicate()
	sorted.sort()
	return _percentile(sorted, 0.50)


func _p99(samples: PackedFloat32Array) -> float:
	var sorted := samples.duplicate()
	sorted.sort()
	return _percentile(sorted, 0.99)


func _percentile(sorted_values: PackedFloat32Array, fraction: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := clampi(
		ceili(clampf(fraction, 0.0, 1.0) * float(sorted_values.size())) - 1,
		0,
		sorted_values.size() - 1
	)
	return sorted_values[index]
