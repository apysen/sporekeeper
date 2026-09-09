class_name SpawnTopology
extends RefCounted

## Where a reinforcement pack enters the arena.
##
## A wave that always arrives evenly is a wave the player answers once and then
## stops reading. The Campaign's late pressure comes as much from geometry as from
## numbers: a breach on the side with no Green, a Colonizer placed in the quiet
## quarter while the fight is elsewhere, a Warden opposite the pack that is
## actually threatening. This scores the eight perimeter sectors so those requests
## can be made in words rather than as hand-picked coordinates.
##
## Scores are recalculated at most four times per second. The arena does not change
## fast enough to justify a per-pack sweep of the territory grid, and a stable
## score is also a more readable one -- the weak side does not flicker between two
## sectors while three packs are placed.

const SECTOR_COUNT := 8
const REFRESH_INTERVAL_SECONDS := 0.25
## How far inward from the perimeter a sector's Green is sampled.
const CONTROL_BAND_PIXELS := 220.0
## Samples taken along each sector's arc when scoring its inward band.
const CONTROL_SAMPLES := 6
## Half-life in seconds of the remembered damage and territory loss per sector.
const PRESSURE_MEMORY_SECONDS := 6.0

var _arena_size := Vector2(1280.0, 720.0)
var _refresh_remaining := 0.0
## Owned coverage and maturity of each sector's inward band, 0 to 1.
var _control_score := PackedFloat32Array()
## Live enemies attributed to each sector.
var _enemy_pressure := PackedFloat32Array()
## Decaying memory of player damage and territory loss originating per sector.
var _recent_pressure := PackedFloat32Array()
var _dominant_sector := 0
var _weakest_sector := 0
var _quiet_sector := 0
## Rotation cursors, one per profile family, so two profiles used in the same wave
## do not share a cursor and collapse onto the same sector.
var _ring_cursor := 0
var _front_cursor := 0
var _front_repeat := 0
var _pincer_cursor := 0
var _pincer_step := 0
var _three_front_cursor := 0
var _final_step := 0
var _last_sector := -1
var _repeat_count := 0
## Walks the entrance across a sector's arc so a clustered front is a front rather
## than a single doorway three packs deep.
var _jitter_step := 0


func configure(arena_size: Vector2, starting_sector: int) -> void:
	_arena_size = arena_size
	_control_score.resize(SECTOR_COUNT)
	_control_score.fill(0.0)
	_enemy_pressure.resize(SECTOR_COUNT)
	_enemy_pressure.fill(0.0)
	_recent_pressure.resize(SECTOR_COUNT)
	_recent_pressure.fill(0.0)
	_refresh_remaining = 0.0
	# The run seed picks where the ring starts, so two runs do not open from the
	# same corner while one run still replays exactly.
	_ring_cursor = posmod(starting_sector, SECTOR_COUNT)
	_front_cursor = _ring_cursor
	_pincer_cursor = _ring_cursor
	_pincer_step = 0
	_three_front_cursor = _ring_cursor
	_front_repeat = 0
	_final_step = 0
	_last_sector = -1
	_repeat_count = 0
	_dominant_sector = _ring_cursor
	_weakest_sector = _ring_cursor
	_quiet_sector = posmod(_ring_cursor + 4, SECTOR_COUNT)


func advance(
	delta: float,
	territory_field: TerritoryField,
	enemy_positions: PackedVector2Array,
	player_position: Vector2
) -> void:
	if delta <= 0.0:
		return
	# Memory fades on its own clock rather than only when a sector is rescored, so
	# a quiet sector really does become quiet again instead of staying marked by
	# something that happened a minute ago.
	var decay := exp(-delta / PRESSURE_MEMORY_SECONDS)
	for index in range(_recent_pressure.size()):
		_recent_pressure[index] *= decay
	_refresh_remaining -= delta
	if _refresh_remaining > 0.0:
		return
	_refresh_remaining = REFRESH_INTERVAL_SECONDS
	_rescore(territory_field, enemy_positions, player_position)


func report_pressure(local_position: Vector2, amount: float) -> void:
	## Player damage or territory loss, attributed to the sector it came from. What
	## the arena is doing to the player is part of where the next pack should go.
	if amount <= 0.0 or _recent_pressure.is_empty():
		return
	_recent_pressure[get_sector_of(local_position)] += amount


func get_sector_of(local_position: Vector2) -> int:
	var center := _arena_size * 0.5
	var offset := local_position - center
	if offset.length_squared() <= 0.0001:
		return 0
	var angle := fposmod(offset.angle(), TAU)
	return clampi(
		int(angle / TAU * float(SECTOR_COUNT)),
		0,
		SECTOR_COUNT - 1
	)


func get_sector_center_angle(sector: int) -> float:
	return (float(posmod(sector, SECTOR_COUNT)) + 0.5) / float(SECTOR_COUNT) * TAU


func get_dominant_fight_sector() -> int:
	return _dominant_sector


func get_weakest_control_sector() -> int:
	return _weakest_sector


func get_quiet_sector() -> int:
	return _quiet_sector


func get_opposite_fight_sector() -> int:
	return posmod(_dominant_sector + SECTOR_COUNT / 2, SECTOR_COUNT)


func get_control_score(sector: int) -> float:
	if _control_score.is_empty():
		return 0.0
	return _control_score[posmod(sector, SECTOR_COUNT)]


func get_enemy_pressure(sector: int) -> float:
	if _enemy_pressure.is_empty():
		return 0.0
	return _enemy_pressure[posmod(sector, SECTOR_COUNT)]


func select_sector(
	profile: StringName,
	leader_role: int,
	is_rusher: bool,
	is_specialist: bool
) -> int:
	## The sector this pack should enter from, chosen by the wave's authored profile
	## and what the pack is. The profile describes the wave's shape; the role
	## overrides inside it are the exceptions the design names by hand -- Rushers at
	## the weak side, Colonizers away from the fight.
	var sector := _ring_cursor
	match profile:
		CampaignWaves.TOPOLOGY_EVEN_RING:
			sector = _advance_ring(3)
		CampaignWaves.TOPOLOGY_TWO_SIDE_PINCER:
			sector = _advance_pincer()
		CampaignWaves.TOPOLOGY_CLUSTERED_FRONT:
			sector = _advance_front()
		CampaignWaves.TOPOLOGY_WEAK_SIDE_RUSH:
			sector = _weakest_sector if is_rusher else _advance_ring(3)
		CampaignWaves.TOPOLOGY_SPECIALIST_OPPOSITE_PACK:
			sector = get_opposite_fight_sector() if is_specialist else _dominant_sector
		CampaignWaves.TOPOLOGY_COLONIZER_DISTRACTION:
			if leader_role == CampaignWaves.ROLE_COLONIZER:
				sector = _quiet_sector
			elif is_rusher:
				sector = _weakest_sector
			else:
				sector = _advance_ring(3)
		CampaignWaves.TOPOLOGY_THREE_FRONT_PRESSURE:
			if is_specialist:
				sector = get_opposite_fight_sector()
			else:
				sector = _advance_three_front()
		CampaignWaves.TOPOLOGY_FINAL_ROTATION:
			sector = _advance_final_rotation(is_specialist)
		_:
			sector = _advance_ring(3)
	sector = posmod(sector, SECTOR_COUNT)
	# No profile may pin three consecutive packs on one sector unless it is a
	# clustered front, which is the one profile whose whole point is doing so.
	if sector == _last_sector:
		_repeat_count += 1
		if (
			_repeat_count >= 2
			and profile != CampaignWaves.TOPOLOGY_CLUSTERED_FRONT
		):
			sector = posmod(sector + 2, SECTOR_COUNT)
			_repeat_count = 0
	else:
		_repeat_count = 0
	_last_sector = sector
	return sector


func get_spawn_point(sector: int, margin: float) -> Vector2:
	## A point on the perimeter inside the named sector. The angle is jittered
	## across the sector rather than pinned to its middle, so a clustered front is a
	## front and not a single doorway.
	var span := TAU / float(SECTOR_COUNT)
	_jitter_step += 1
	var fraction := float(_jitter_step % 7) / 7.0
	return _perimeter_point(
		get_sector_center_angle(sector) + (fraction - 0.5) * span * 0.8,
		margin
	)


func _perimeter_point(angle: float, margin: float) -> Vector2:
	# Cast the direction onto the arena rectangle rather than onto a circle, so the
	# corners are reachable entrances too and a sector's arc covers real ground.
	var center := _arena_size * 0.5
	var direction := Vector2.from_angle(angle)
	var half := Vector2(
		maxf(1.0, center.x - margin),
		maxf(1.0, center.y - margin)
	)
	var scale_x := half.x / maxf(0.0001, absf(direction.x))
	var scale_y := half.y / maxf(0.0001, absf(direction.y))
	return center + direction * minf(scale_x, scale_y)


func _advance_ring(minimum_separation: int) -> int:
	var sector := _ring_cursor
	_ring_cursor = posmod(_ring_cursor + minimum_separation, SECTOR_COUNT)
	return sector


func _advance_pincer() -> int:
	# Two fronts, three sectors apart, alternating. Far enough that holding one
	# exposes the other, and the pair walks the perimeter every two exchanges so the
	# same two doors are not used for a whole minute.
	_pincer_step += 1
	var near_side := _pincer_step % 2 == 0
	if _pincer_step % 4 == 0:
		_pincer_cursor = posmod(_pincer_cursor + 1, SECTOR_COUNT)
	return _pincer_cursor if near_side else posmod(_pincer_cursor + 3, SECTOR_COUNT)


func _advance_front() -> int:
	# Several packs through one 90-degree front, then the front moves.
	_front_repeat += 1
	if _front_repeat >= 3:
		_front_repeat = 0
		_front_cursor = posmod(_front_cursor + 3, SECTOR_COUNT)
		return _front_cursor
	return posmod(_front_cursor + _front_repeat - 1, SECTOR_COUNT)


func _advance_three_front() -> int:
	var step := _three_front_cursor % 3
	_three_front_cursor += 1
	# Three fronts at least 75 degrees apart, which on eight sectors is two apart.
	return posmod(_dominant_sector + step * 3, SECTOR_COUNT)


func _advance_final_rotation(is_specialist: bool) -> int:
	## Two pressure fronts, then a weak-side breach, then a quiet-side specialist.
	## Predictable on purpose: the last wave should be survivable by reading it.
	var step := _final_step % 4
	_final_step += 1
	if is_specialist:
		return _quiet_sector
	match step:
		0:
			return _dominant_sector
		1:
			return get_opposite_fight_sector()
		2:
			return _weakest_sector
	return _quiet_sector


func _rescore(
	territory_field: TerritoryField,
	enemy_positions: PackedVector2Array,
	player_position: Vector2
) -> void:
	if territory_field == null:
		return
	_arena_size = territory_field.tuning.arena_size
	for sector in range(SECTOR_COUNT):
		_control_score[sector] = _score_control(territory_field, sector)
		_enemy_pressure[sector] = 0.0
	for position in enemy_positions:
		_enemy_pressure[get_sector_of(position)] += 1.0
	var player_sector := get_sector_of(player_position)
	var weakest := 0
	var dominant := 0
	var quiet := 0
	var weakest_score := INF
	var dominant_score := -INF
	var quiet_score := INF
	for sector in range(SECTOR_COUNT):
		var control := _control_score[sector]
		if control < weakest_score:
			weakest_score = control
			weakest = sector
		var pressure := _enemy_pressure[sector] + _recent_pressure[sector]
		if pressure > dominant_score:
			dominant_score = pressure
			dominant = sector
		# The sector Grandma is standing in is never the quiet one: a Colonizer
		# placed there is not a distraction, it is the fight.
		if sector != player_sector and pressure < quiet_score:
			quiet_score = pressure
			quiet = sector
	_weakest_sector = weakest
	_dominant_sector = dominant
	_quiet_sector = quiet


func _score_control(territory_field: TerritoryField, sector: int) -> float:
	# Owned coverage and average maturity of the inward band, combined into one
	# number because a sector defended by fresh Green and one defended by mature
	# Green are not the same weak side.
	var span := TAU / float(SECTOR_COUNT)
	var base_angle := get_sector_center_angle(sector) - span * 0.5
	var owned := 0.0
	var maturity := 0.0
	var samples := 0
	for arc_step in range(CONTROL_SAMPLES):
		var angle := base_angle + span * (float(arc_step) + 0.5) / float(CONTROL_SAMPLES)
		var direction := Vector2.from_angle(angle)
		var edge := _perimeter_point(angle, 8.0)
		for depth_step in range(3):
			var depth := CONTROL_BAND_PIXELS * (float(depth_step) + 1.0) / 3.0
			var sample := edge - direction * depth
			sample.x = clampf(sample.x, 0.0, _arena_size.x - 1.0)
			sample.y = clampf(sample.y, 0.0, _arena_size.y - 1.0)
			samples += 1
			if territory_field.is_owned_at_local(sample):
				owned += 1.0
				maturity += territory_field.get_maturity_at_local(sample)
	if samples <= 0:
		return 0.0
	var coverage := owned / float(samples)
	var average_maturity := maturity / maxf(1.0, owned)
	return coverage * (0.6 + 0.4 * average_maturity)
