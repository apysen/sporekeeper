class_name PhaseBPerfCounters
extends RefCounted

## The game-specific timing and volume counters the performance work is measured by.
##
## The Godot profiler answers "which frame was slow". It does not answer "that
## frame resolved 41,000 thorn/enemy candidate checks to land 12 hits", and that
## second number is the one that says whether an optimization worked. So the
## subsystems keep their own counters and the probes read them, per the
## optimization guide's requirement that results be comparable commit to commit
## rather than anecdotal.
##
## Everything here is off by default. A disabled counter costs one static bool
## read, and the hot loops are written to accumulate into a local and hand the
## total over once per pass rather than calling in per candidate.

## Wall-clock milliseconds spent inside a subsystem.
const TIMER_ENEMY_MANAGER_TOTAL := &"enemy_manager_total_ms"
const TIMER_ENEMY_MOVEMENT := &"enemy_movement_ms"
const TIMER_ENEMY_AI := &"enemy_ai_ms"
const TIMER_ENEMY_SEPARATION := &"enemy_separation_ms"
const TIMER_ENEMY_TERRITORY := &"enemy_territory_ms"

const TIMER_SPATIAL_GRID_BUILD := &"spatial_grid_build_ms"
const TIMER_SPATIAL_GRID_QUERY := &"spatial_grid_query_ms"

const TIMER_THISTLE_TOTAL := &"thistle_total_ms"
const TIMER_THISTLE_TARGETING := &"thistle_targeting_ms"
const TIMER_THISTLE_PROJECTILE_UPDATE := &"thistle_projectile_update_ms"
const TIMER_THISTLE_COLLISION := &"thistle_collision_ms"
## Everything a landed thorn sets off: damage, Pincushion, Inoculator, Hedge
## Battery, the answering thorn, Bloomshot, the relay. Split out from the
## projectile update because "the volley spike is in the scan" and "the volley
## spike is in the cascade the scan feeds" point at completely different fixes.
const TIMER_THISTLE_HIT_RESOLUTION := &"thistle_hit_resolution_ms"
## The three parts of resolving a hit, because "the cascade is expensive" and "the
## by-id reads that feed the cascade are expensive" want opposite fixes: the first
## wants batched event records, the second wants an id-to-slot map.
const TIMER_THISTLE_HIT_LOOKUP := &"thistle_hit_lookup_ms"
const TIMER_THISTLE_HIT_DAMAGE := &"thistle_hit_damage_ms"
const TIMER_THISTLE_HIT_CASCADE := &"thistle_hit_cascade_ms"
const TIMER_THISTLE_RICOCHET := &"thistle_ricochet_ms"
const TIMER_THISTLE_RELIC_LOGIC := &"thistle_relic_logic_ms"
const TIMER_THISTLE_VISUAL_SUBMISSION := &"thistle_visual_submission_ms"

## The cane/sweep cycle, and the densest-target query it makes. That query walks
## the whole roster with a path test per enemy and then sweeps every candidate
## sector against every target, so it is quadratic in the crowd twice over.
const TIMER_CANE_TOTAL := &"cane_total_ms"
const TIMER_CANE_TARGETING := &"cane_targeting_ms"
## Its two halves. Gathering walks the roster with a path query per enemy; the
## sector sweep is quadratic in whatever gathering returned. They need different
## fixes, so they are measured apart before either is attempted.
const TIMER_CANE_TARGET_GATHER := &"cane_target_gather_ms"
const TIMER_CANE_TARGET_SWEEP := &"cane_target_sweep_ms"
## Everything the stroke itself does once a direction has been chosen. Its loop is
## linear in the crowd, so any surprise in it has to be the cost of one iteration
## rather than the number of them -- and one iteration can run a full route query.
const TIMER_CANE_PERFORM := &"cane_perform_ms"
const TIMER_CANE_PERFORM_ROUTES := &"cane_perform_routes_ms"
## The sweep-started broadcast and the sound that goes with it. A Vine-driven
## stroke hands the hits to the rope and returns immediately, so on those frames
## these few lines are the entire cost of "performing" the sweep.
const TIMER_CANE_SWEEP_SIGNAL := &"cane_sweep_signal_ms"
const TIMER_CANE_SFX := &"cane_sfx_ms"

## The Vine runs continuously rather than only while attacking, so it belongs in
## the frame budget every frame and not only on sweeps.
const TIMER_VINE_TOTAL := &"vine_total_ms"
const TIMER_VINE_ADVANCE := &"vine_advance_ms"
const TIMER_VINE_HITS := &"vine_hits_ms"

const TIMER_TERRITORY_TOTAL := &"territory_total_ms"
const TIMER_TERRITORY_ENQUEUE := &"territory_enqueue_ms"
const TIMER_TERRITORY_BATCH := &"territory_batch_ms"
const TIMER_TERRITORY_VISUAL_PAINT := &"territory_visual_paint_ms"

const TIMER_FRUIT_TOTAL := &"fruit_total_ms"
const TIMER_FRUIT_COLLISION := &"fruit_collision_ms"
const TIMER_FRUIT_TRAIL_ENQUEUE := &"fruit_trail_enqueue_ms"
## The rest of the Fruit path, split out because collision and trail enqueue
## together came to half a millisecond while the whole bucket was fifteen, so the
## cost had to be somewhere that was not yet named.
const TIMER_FRUIT_RELICS := &"fruit_relics_ms"
const TIMER_FRUIT_ADVANCE := &"fruit_advance_ms"
const TIMER_FRUIT_SEEDS := &"fruit_seeds_ms"
const TIMER_FRUIT_RELEASE := &"fruit_release_ms"
## Inside one Fruit's movement step. The terrain bar covers the three field queries
## every Fruit makes every frame plus the bounce resolver they gate; the other two
## cover the per-Fruit work that only some Fruit do.
const TIMER_FRUIT_TERRAIN := &"fruit_terrain_ms"
const TIMER_FRUIT_BURDOCK := &"fruit_burdock_ms"
const TIMER_FRUIT_FINISH := &"fruit_finish_ms"
## What a Fruit landing on an enemy sets off, and the two halves of the seed layer.
const TIMER_FRUIT_HIT_RESOLUTION := &"fruit_hit_resolution_ms"
## The relic cascade a Fruit collision sets off, split so the next fix is chosen by
## measurement rather than by which name sounds expensive.
const TIMER_FRUIT_REDIRECT := &"fruit_redirect_ms"
const TIMER_FRUIT_SALAD := &"fruit_salad_ms"
const TIMER_FRUIT_NEWTON := &"fruit_newton_ms"
const TIMER_FRUIT_BLOOM := &"fruit_bloom_ms"

## Inside a radius blast: the per-enemy line-of-sight walk, and the damage plus
## whatever a kill sets off. Both are shared by every AoE in the game.
const TIMER_BLAST_LINE_OF_SIGHT := &"blast_line_of_sight_ms"
const TIMER_BLAST_DAMAGE := &"blast_damage_ms"
## Finding a slot for one floating damage number. Cosmetic, and a scan of the whole
## pool per damage instance.
const TIMER_DAMAGE_NUMBER_SPAWN := &"damage_number_spawn_ms"
const TIMER_FRUITSEEDS := &"fruitseeds_ms"
const TIMER_SAPLINGS := &"saplings_ms"

## Volumes. These are what distinguish "the algorithm got faster" from "the
## fixture happened to do less work this run".
const COUNT_SPATIAL_GRID_CANDIDATES_TOTAL := &"spatial_grid_candidates_total"
const COUNT_SPATIAL_GRID_CANDIDATES_MAX := &"spatial_grid_candidates_max"

## How many enemies survived the range and line-of-sight prune to reach the sector
## sweep. The sweep is quadratic in this, so it is the number that says whether a
## better algorithm is needed or a tighter prune would do.
const COUNT_CANE_TARGETS := &"cane_targets"
## The stroke reuses routes the targeting pass already computed. A miss means it
## pathfinds again for that enemy, so the ratio says whether the cache is doing its
## job or whether the stroke is quietly paying for a second search.
const COUNT_CANE_ROUTE_CACHE_HITS := &"cane_route_cache_hits"
const COUNT_CANE_ROUTE_CACHE_MISSES := &"cane_route_cache_misses"

const COUNT_THISTLES_FIRED := &"thistles_fired"
const COUNT_THORN_SEGMENTS_RESOLVED := &"thorn_segments_resolved"
const COUNT_THORN_CANDIDATE_CHECKS := &"thorn_candidate_checks"

const COUNT_TERRITORY_CELLS_TOUCHED := &"territory_cells_touched"
const COUNT_TERRITORY_UNIQUE_CELLS_CHANGED := &"territory_unique_cells_changed"
const COUNT_TERRITORY_DUPLICATE_CELL_WRITES := &"territory_duplicate_cell_writes"

const COUNT_FRUIT_TRAIL_SEGMENTS := &"fruit_trail_segments"

const COUNT_GENERATED_EVENTS_ENQUEUED := &"generated_events_enqueued"
const COUNT_GENERATED_EVENTS_PROCESSED := &"generated_events_processed"
const COUNT_GENERATED_EVENTS_DROPPED_COSMETIC := &"generated_events_dropped_cosmetic"

## Times the id-to-slot map missed and the linear search had to answer instead. A
## steady nonzero reading means the map is not being maintained somewhere, which
## costs speed but never correctness.
const COUNT_ENEMY_LOOKUP_FALLBACKS := &"enemy_lookup_fallbacks"

const COUNT_COMBAT_DYNAMIC_ALLOCATIONS := &"combat_dynamic_allocations"

## Every timer, in report order. Probes iterate this rather than the dictionary so
## a subsystem that never ran still reports a row of zeroes instead of vanishing.
const TIMER_NAMES: Array[StringName] = [
	TIMER_ENEMY_MANAGER_TOTAL,
	TIMER_ENEMY_MOVEMENT,
	TIMER_ENEMY_AI,
	TIMER_ENEMY_SEPARATION,
	TIMER_ENEMY_TERRITORY,
	TIMER_SPATIAL_GRID_BUILD,
	TIMER_SPATIAL_GRID_QUERY,
	TIMER_THISTLE_TOTAL,
	TIMER_THISTLE_TARGETING,
	TIMER_THISTLE_PROJECTILE_UPDATE,
	TIMER_THISTLE_COLLISION,
	TIMER_THISTLE_HIT_RESOLUTION,
	TIMER_THISTLE_HIT_LOOKUP,
	TIMER_THISTLE_HIT_DAMAGE,
	TIMER_THISTLE_HIT_CASCADE,
	TIMER_THISTLE_RICOCHET,
	TIMER_THISTLE_RELIC_LOGIC,
	TIMER_THISTLE_VISUAL_SUBMISSION,
	TIMER_CANE_TOTAL,
	TIMER_CANE_TARGETING,
	TIMER_CANE_TARGET_GATHER,
	TIMER_CANE_TARGET_SWEEP,
	TIMER_CANE_PERFORM,
	TIMER_CANE_PERFORM_ROUTES,
	TIMER_CANE_SWEEP_SIGNAL,
	TIMER_CANE_SFX,
	TIMER_VINE_TOTAL,
	TIMER_VINE_ADVANCE,
	TIMER_VINE_HITS,
	TIMER_TERRITORY_TOTAL,
	TIMER_TERRITORY_ENQUEUE,
	TIMER_TERRITORY_BATCH,
	TIMER_TERRITORY_VISUAL_PAINT,
	TIMER_FRUIT_TOTAL,
	TIMER_FRUIT_COLLISION,
	TIMER_FRUIT_TRAIL_ENQUEUE,
	TIMER_FRUIT_RELICS,
	TIMER_FRUIT_ADVANCE,
	TIMER_FRUIT_SEEDS,
	TIMER_FRUIT_RELEASE,
	TIMER_FRUIT_TERRAIN,
	TIMER_FRUIT_BURDOCK,
	TIMER_FRUIT_FINISH,
	TIMER_FRUIT_HIT_RESOLUTION,
	TIMER_FRUIT_REDIRECT,
	TIMER_FRUIT_SALAD,
	TIMER_FRUIT_NEWTON,
	TIMER_FRUIT_BLOOM,
	TIMER_BLAST_LINE_OF_SIGHT,
	TIMER_BLAST_DAMAGE,
	TIMER_DAMAGE_NUMBER_SPAWN,
	TIMER_FRUITSEEDS,
	TIMER_SAPLINGS,
]

const COUNT_NAMES: Array[StringName] = [
	COUNT_SPATIAL_GRID_CANDIDATES_TOTAL,
	COUNT_SPATIAL_GRID_CANDIDATES_MAX,
	COUNT_CANE_TARGETS,
	COUNT_CANE_ROUTE_CACHE_HITS,
	COUNT_CANE_ROUTE_CACHE_MISSES,
	COUNT_THISTLES_FIRED,
	COUNT_THORN_SEGMENTS_RESOLVED,
	COUNT_THORN_CANDIDATE_CHECKS,
	COUNT_TERRITORY_CELLS_TOUCHED,
	COUNT_TERRITORY_UNIQUE_CELLS_CHANGED,
	COUNT_TERRITORY_DUPLICATE_CELL_WRITES,
	COUNT_FRUIT_TRAIL_SEGMENTS,
	COUNT_GENERATED_EVENTS_ENQUEUED,
	COUNT_GENERATED_EVENTS_PROCESSED,
	COUNT_GENERATED_EVENTS_DROPPED_COSMETIC,
	COUNT_ENEMY_LOOKUP_FALLBACKS,
	COUNT_COMBAT_DYNAMIC_ALLOCATIONS,
]

## Counters that report the largest single observation rather than a sum. A
## candidate count of 20 averaged over a frame hides the one query that walked 400.
const MAXIMUM_COUNTS: Array[StringName] = [
	COUNT_SPATIAL_GRID_CANDIDATES_MAX,
]

static var enabled := false

static var _timer_ms := {}
static var _timer_open_usec := {}
static var _counts := {}


## Turn collection on and clear whatever the last fixture left behind. Probes call
## this; the game never does.
static func begin_session() -> void:
	enabled = true
	reset_frame()


static func end_session() -> void:
	enabled = false
	reset_frame()


## Called once per simulated frame, before the frame runs. Counters are per-frame
## so a probe can build a distribution and report p99 rather than an average.
static func reset_frame() -> void:
	_timer_ms.clear()
	_timer_open_usec.clear()
	_counts.clear()


static func timer_begin(timer: StringName) -> void:
	if not enabled:
		return
	_timer_open_usec[timer] = Time.get_ticks_usec()


static func timer_end(timer: StringName) -> void:
	if not enabled:
		return
	var opened: int = _timer_open_usec.get(timer, -1)
	if opened < 0:
		return
	_timer_open_usec.erase(timer)
	_timer_ms[timer] = (
		float(_timer_ms.get(timer, 0.0))
		+ float(Time.get_ticks_usec() - opened) / 1000.0
	)


## For a caller that already took its own start stamp, so a hot function does not
## pay for a dictionary write on entry as well as on exit.
static func timer_add_since(timer: StringName, began_usec: int) -> void:
	if not enabled:
		return
	_timer_ms[timer] = (
		float(_timer_ms.get(timer, 0.0))
		+ float(Time.get_ticks_usec() - began_usec) / 1000.0
	)


static func get_timer_ms(timer: StringName) -> float:
	return float(_timer_ms.get(timer, 0.0))


static func count(counter: StringName, amount: int = 1) -> void:
	if not enabled:
		return
	if counter in MAXIMUM_COUNTS:
		_counts[counter] = maxi(int(_counts.get(counter, 0)), amount)
		return
	_counts[counter] = int(_counts.get(counter, 0)) + amount


static func get_count(counter: StringName) -> int:
	return int(_counts.get(counter, 0))


## One frame's counters, flattened for a probe to append to its per-frame samples.
static func snapshot() -> Dictionary:
	var result := {}
	for timer in TIMER_NAMES:
		result[timer] = float(_timer_ms.get(timer, 0.0))
	for counter in COUNT_NAMES:
		result[counter] = int(_counts.get(counter, 0))
	return result
