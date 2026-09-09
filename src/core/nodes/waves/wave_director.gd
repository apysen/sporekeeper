class_name WaveDirector
extends Node

const RUN_MODE := preload("res://src/core/models/run/run_mode.gd")

signal wave_began(wave_number: int)
## The arena was cleared during a wave's opening break, so the break ended early.
## Quick keeps this; Campaign breaks are authored pauses and never end early.
signal grace_skipped(wave_number: int)
signal elite_arrived
signal boss_arrived
signal final_invasion_began
signal cleanup_began
## A Campaign wave whose completion opens one of the ten authored relic rewards.
signal wave_relic_earned(wave_number: int)

@export_group("Collaborators")
## Combat component that receives scaled enemy spawn requests from this director.
@export var combat: CombatDirector
## Territory component the Campaign's perimeter topology scores its sectors from.
@export var territory_field: TerritoryField
## Player component whose arena position the topology treats as the thing defended.
@export var player: Player

@export_group("Run Timeline")
## Total run length in seconds; reaching this time completes the survival objective.
@export_range(60.0, 1800.0, 1.0) var run_duration_seconds := 720.0
## Elapsed run time in seconds when the elite is first scheduled to spawn.
@export_range(10.0, 1800.0, 1.0) var elite_time_seconds := 150.0
## Elapsed run time in seconds when the Burrower boss is first scheduled to spawn.
@export_range(20.0, 1800.0, 1.0) var boss_time_seconds := 360.0
## Elapsed run time in seconds when final-invasion spawning begins.
@export_range(30.0, 1800.0, 1.0) var final_invasion_time_seconds := 600.0
## Seconds over which pressure ramps from opening to full: spawn cadence, pack
## size, enemy health and contact damage all read it.
##
## Deliberately separate from the final invasion. Those are two different
## questions -- how fast the run gets hard, and when the last wave arrives -- and
## tying them together is what made a longer run a slower one rather than a bigger
## one. Zero falls back to the invasion time, which is the behaviour Quick wants.
##
## Campaign no longer reads this at all: its pressure is authored per wave.
@export_range(0.0, 1800.0, 1.0) var pressure_ramp_seconds := 0.0
## Elapsed run time in seconds when reinforcements stop and cleanup begins.
@export_range(30.0, 1800.0, 1.0) var cleanup_time_seconds := 690.0

@export_group("Wave Cadence")
## Length of each numbered pressure wave in seconds.
@export_range(10.0, 180.0, 1.0) var wave_duration_seconds := 60.0
## Reinforcement-free seconds at the start of every wave after Wave 1.
@export_range(0.0, 30.0, 0.5) var wave_grace_period_seconds := 5.0
## Delay in seconds before Wave 1 sends its first regular reinforcement.
@export_range(0.0, 5.0, 0.05) var opening_spawn_delay_seconds := 0.65
## Seconds between regular reinforcement packs at the start of the run.
@export_range(0.05, 5.0, 0.01) var early_spawn_interval_seconds := 1.15
## Seconds between regular reinforcement packs near the final invasion.
@export_range(0.05, 5.0, 0.01) var late_spawn_interval_seconds := 0.32
## Fixed seconds between reinforcement packs during the final invasion.
@export_range(0.03, 2.0, 0.01) var final_spawn_interval_seconds := 0.12

@export_group("Campaign Scheduler")
## Reinforcement packs one frame may request. A hitch must not be paid back as a
## burst the player never saw coming, so catch-up is bounded rather than unlimited.
@export_range(1, 8, 1) var maximum_packs_per_frame := 2
## Intervals of scheduling debt retained across a hitch before the rest is dropped.
@export_range(1.0, 10.0, 0.5) var maximum_spawn_debt_intervals := 3.0
## Active actors above which ordinary reinforcements stop being requested, leaving
## the remainder of the hard cap reserved for the Elite, the Boss, and Colony Cores.
@export_range(10, 300, 1) var regular_reinforcement_cap := 124

@export_group("Per-Wave Scaling")
## Additive territory-erosion multiplier gained by newly spawned enemies each wave.
## Quick only: Campaign authors territory strength as its own curve.
@export_range(0.0, 1.0, 0.01) var territory_erosion_growth_per_wave := 0.10
## Proportional XP reward increase gained by newly spawned enemies each wave.
@export_range(0.0, 1.0, 0.01) var xp_reward_growth_per_wave := 0.10
## Minimum flat XP added per completed wave when proportional growth rounds too low.
@export_range(0, 10, 1) var xp_minimum_bonus_per_wave := 1
## Enemy-health multiplier reached when final-invasion pressure reaches 100%.
@export_range(1.0, 5.0, 0.05) var final_health_scale := 2.15
## Enemy contact-damage multiplier reached at 100% final-invasion pressure.
@export_range(1.0, 5.0, 0.05) var final_contact_damage_scale := 1.60
## Campaign XP multiplier reached at Wave 25. Deliberately far below the health
## curve: more durable enemies already reduce the kill rate, so matching the two
## would make dense late waves fund themselves.
@export_range(1.0, 6.0, 0.05) var campaign_final_xp_multiplier := 2.20

@export_group("Enemy Mix")
## Reinforcement-pack cycle outside a surge; every Nth regular pack leads with a Grazer.
@export_range(1, 20, 1) var grazer_pack_cycle := 4
## Wave cycle for deliberate Grazer surges; every Nth wave tests the frontier. Zero disables.
@export_range(0, 20, 1) var grazer_surge_wave_cycle := 4
## Reinforcement-pack cycle used during a Grazer surge wave; 1 makes every pack a Grazer.
@export_range(1, 20, 1) var grazer_surge_pack_cycle := 1
## Normalized final-invasion progress after which regular packs use the late size.
@export_range(0.0, 1.0, 0.01) var late_pack_progress := 0.62
## Number of enemies requested in each regular early-run reinforcement pack.
@export_range(1, 8, 1) var regular_pack_size := 1
## Number of enemies requested in each late-run reinforcement pack.
@export_range(1, 8, 1) var late_pack_size := 2
## Number of enemies requested per reinforcement pack during the final invasion.
@export_range(1, 12, 1) var final_pack_size := 3

@export_group("Role Introductions")
## Elapsed run time when regular packs begin including catalyst-hunting Saboteurs.
@export_range(0.0, 1800.0, 1.0) var saboteur_intro_seconds := 75.0
## Elapsed run time when regular packs begin including territory-converting Corruptors.
@export_range(0.0, 1800.0, 1.0) var corruptor_intro_seconds := 180.0
## Elapsed run time when regular packs begin including hostile-Core-building Colonizers.
@export_range(0.0, 1800.0, 1.0) var colonizer_intro_seconds := 285.0
## Elapsed run time when regular packs begin including maturity-suppressing Wardens.
@export_range(0.0, 1800.0, 1.0) var warden_intro_seconds := 420.0
## Reinforcement-pack cycle used after introduction; every Nth pack includes a Saboteur.
@export_range(2, 30, 1) var saboteur_pack_cycle := 5
## Reinforcement-pack cycle used after introduction; every Nth pack includes a Corruptor.
@export_range(2, 30, 1) var corruptor_pack_cycle := 7
## Reinforcement-pack cycle used after introduction; every Nth pack includes a Colonizer.
@export_range(2, 30, 1) var colonizer_pack_cycle := 9
## Reinforcement-pack cycle used after introduction; every Nth pack includes a Warden.
@export_range(2, 30, 1) var warden_pack_cycle := 11

@export_group("Late Specialists")
## Elapsed run time when Grazers begin arriving as the immovable Heavy variant.
## Late, because it is the answer to a frontier the run has had time to build.
@export_range(0.0, 1800.0, 1.0) var heavy_grazer_intro_seconds := 330.0
## Share of Grazer spawns that arrive Heavy once introduced.
@export_range(0.0, 1.0, 0.01) var heavy_grazer_share := 0.45
## Elapsed run time when regular packs begin including fast Rushers.
@export_range(0.0, 1800.0, 1.0) var rusher_intro_seconds := 300.0
## Reinforcement-pack cycle used after introduction; every Nth pack leads with a Rusher.
@export_range(2, 30, 1) var rusher_pack_cycle := 6
## Elapsed run time when Corruptors begin arriving as the escalating Siege variant.
@export_range(0.0, 1800.0, 1.0) var siege_corruptor_intro_seconds := 420.0
## Share of Corruptor spawns that arrive as Siege Corruptors once introduced.
@export_range(0.0, 1.0, 0.01) var siege_corruptor_share := 0.5

@export_group("Escalation")
## Elapsed run time at which elites may begin carrying rule changes at all. The
## design note ties this to the run's own progression rather than the clock, and
## the clock is the honest approximation of it: by here a run has a pairing, a
## build, and something for a rule change to be a change to.
##
## Quick only. Campaign gates rule changes on its authored per-wave stages.
@export_range(0.0, 1800.0, 1.0) var elite_modifier_intro_seconds := 300.0

var elapsed_seconds := 0.0
var announced_wave_number := 1
## The wave whose opening break has already been cut short by the arena being
## cleared. Latched per wave rather than recomputed, because the break must not come
## back the moment the first replacement enemy appears.
var _grace_skipped_wave := 0
var elite_spawned := false
var boss_spawned := false
var final_invasion_started := false
var cleanup_started := false

var _spawn_remaining := 0.0
var _spawn_pack_sequence := 0
var _grazer_pack_sequence := 0
## Bumped every time a specialist variant is chosen, so the Heavy and Siege shares
## alternate deterministically instead of being rolled. A run should not be able to
## get eight Heavy Grazers in a row because the dice said so.
var _variant_sequence := 0

## Whether this run is the authored 25-wave Campaign rather than Quick's ramp.
var _campaign_mode := false
var _wave_specs: Array[CampaignWaveSpec] = []
var _role_scaling_profiles := {}
var _topology := SpawnTopology.new()
var _run_seed := 0
## Scheduling debt in seconds, so pack timing is what the clock says rather than
## what the frame rate allowed.
var _spawn_debt_seconds := 0.0
## Index into the current wave's pack-size pattern; reset at every wave boundary.
var _pattern_index := 0
## The current wave's shuffled leader deck and how far through it the wave is.
var _leader_deck := PackedInt32Array()
var _leader_cursor := 0
var _leader_cycle := 0
var _deck_wave := 0
## Requests the Campaign issued and how many of them became live enemies. Both are
## telemetry: a wave that requests three hundred packs into a full cap is a
## different wave from one that requested eighty and spawned all of them.
var _packs_requested := 0
var _packs_rejected := 0
var _enemies_spawned := 0


## The authored values of every field configure_mode overwrites, captured before
## anything has had a chance to change them.
##
## The director is a scene node and outlives a run, so configuring Campaign used to
## be permanent: it wrote its thirty-minute timings over the exported defaults and
## the Quick branch returned without putting anything back. Starting a Quick run
## after a Campaign one therefore ran Quick on Campaign's clock -- a twelve minute
## mode with its boss at fifteen minutes and its ending at thirty.
var _authored_mode_values := {}


func _capture_authored_mode_values() -> void:
	if not _authored_mode_values.is_empty():
		return
	for field in [
		"run_duration_seconds",
		"elite_time_seconds",
		"boss_time_seconds",
		"final_invasion_time_seconds",
		"cleanup_time_seconds",
		"pressure_ramp_seconds",
		"wave_duration_seconds",
		"wave_grace_period_seconds",
		"early_spawn_interval_seconds",
		"late_spawn_interval_seconds",
		"final_spawn_interval_seconds",
		"late_pack_progress",
		"final_health_scale",
		"final_contact_damage_scale",
		"saboteur_intro_seconds",
		"corruptor_intro_seconds",
		"colonizer_intro_seconds",
		"warden_intro_seconds",
		"heavy_grazer_intro_seconds",
		"rusher_intro_seconds",
		"siege_corruptor_intro_seconds",
		"elite_modifier_intro_seconds",
	]:
		_authored_mode_values[field] = get(field)


func configure_mode(mode: int) -> void:
	# Quick retains the original 12-minute tuning. Campaign is the authored 25-wave,
	# 25-minute structure: fixed per-wave scaling, an authored composition table, and
	# milestones on waves rather than on a stopwatch.
	#
	# Every field is restored to what was authored before a mode is applied, so
	# configuring a mode says what that mode is rather than what has changed since
	# the last one.
	_capture_authored_mode_values()
	for field in _authored_mode_values:
		set(field, _authored_mode_values[field])
	_campaign_mode = mode == RUN_MODE.Id.CAMPAIGN
	if not _campaign_mode:
		_wave_specs.clear()
		return
	_wave_specs = CampaignWaves.build_wave_specs()
	_role_scaling_profiles = CampaignWaves.build_role_scaling_profiles()
	run_duration_seconds = CampaignWaves.CAMPAIGN_DURATION_SECONDS
	wave_duration_seconds = CampaignWaves.WAVE_DURATION_SECONDS
	# Both milestones are wave events now. The seconds are kept in step with the
	# wave table so anything still reading the clock reads the same moment.
	elite_time_seconds = (
		float(CampaignWaves.ELITE_WAVE - 1) * CampaignWaves.WAVE_DURATION_SECONDS
		+ CampaignWaves.ELITE_SPAWN_SECOND
	)
	boss_time_seconds = (
		float(CampaignWaves.BOSS_WAVE - 1) * CampaignWaves.WAVE_DURATION_SECONDS
		+ CampaignWaves.BOSS_SPAWN_SECOND
	)
	# The final wave is a wave, not a separate invasion phase bolted after one. It
	# announces itself at its own boundary and stops reinforcing at 24:45.
	final_invasion_time_seconds = (
		float(CampaignWaves.WAVE_COUNT - 1) * CampaignWaves.WAVE_DURATION_SECONDS
	)
	cleanup_time_seconds = CampaignWaves.FINAL_REINFORCEMENT_CUTOFF_SECONDS
	# Campaign breaks are authored per wave and never end early, so the shared
	# grace field is only the Quick behaviour and Campaign reads its spec instead.
	wave_grace_period_seconds = 0.0


func set_run_seed(seed_value: int) -> void:
	## Every deterministic Campaign draw hangs off this: the leader decks and the
	## sector the perimeter rotation starts from. Set before the run begins so a
	## seed replays a Campaign exactly.
	_run_seed = seed_value
	_topology.configure(
		territory_field.tuning.arena_size if territory_field != null else Vector2(1280.0, 720.0),
		absi(seed_value) % SpawnTopology.SECTOR_COUNT
	)
	_deck_wave = 0


func _ready() -> void:
	assert(combat != null, "WaveDirector requires CombatDirector")
	# Before anything can overwrite them, so a mode switch has an original to
	# return to.
	_capture_authored_mode_values()


func reset_director() -> void:
	elapsed_seconds = 0.0
	announced_wave_number = 1
	_grace_skipped_wave = 0
	elite_spawned = false
	boss_spawned = false
	final_invasion_started = false
	cleanup_started = false
	_spawn_remaining = opening_spawn_delay_seconds
	_spawn_pack_sequence = 0
	_grazer_pack_sequence = 0
	_variant_sequence = 0
	_spawn_debt_seconds = 0.0
	_pattern_index = 0
	_leader_deck = PackedInt32Array()
	_leader_cursor = 0
	_leader_cycle = 0
	_deck_wave = 0
	_packs_requested = 0
	_packs_rejected = 0
	_enemies_spawned = 0
	set_run_seed(_run_seed if _run_seed != 0 else (randi() | 1))
	_apply_enemy_spawn_scaling()
	combat.set_elite_modifier_pressure(0.0)


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	elapsed_seconds = minf(run_duration_seconds, elapsed_seconds + delta)
	_update_timeline_events()
	if _campaign_mode:
		_advance_campaign_topology(delta)
		_update_campaign_spawning(delta)
		return
	_update_enemy_spawning(delta)


func debug_advance_time(seconds: float) -> void:
	elapsed_seconds = clampf(
		elapsed_seconds + maxf(0.0, seconds),
		0.0,
		run_duration_seconds
	)
	_update_timeline_events()


func debug_spawn_boss() -> bool:
	if combat.has_active_boss():
		return false
	_apply_enemy_spawn_scaling()
	if combat.spawn_enemy(CombatDirector.EnemyRole.BOSS) == -1:
		return false
	boss_spawned = true
	return true


func is_campaign_mode() -> bool:
	return _campaign_mode


## The last wave the configured timeline reaches. Read off the same two fields the
## current wave is, so a mode that shortens the run reports its own ending rather
## than the Campaign's twenty-five.
func get_final_wave_number() -> int:
	return maxi(1, ceili(run_duration_seconds / maxf(1.0, wave_duration_seconds)))


func get_current_wave_number() -> int:
	return clampi(
		int(floor(elapsed_seconds / maxf(1.0, wave_duration_seconds))) + 1,
		1,
		get_final_wave_number()
	)


func get_wave_spec(wave_number: int) -> CampaignWaveSpec:
	## The authored configuration of one Campaign wave, or null outside Campaign.
	if _wave_specs.is_empty():
		return null
	return _wave_specs[clampi(wave_number, 1, _wave_specs.size()) - 1]


func get_current_wave_spec() -> CampaignWaveSpec:
	return get_wave_spec(get_current_wave_number())


func get_wave_display_name(wave_number: int) -> String:
	var spec := get_wave_spec(wave_number)
	return String(spec.display_name) if spec != null else ""


func get_seconds_into_wave() -> float:
	return fmod(elapsed_seconds, maxf(1.0, wave_duration_seconds))


func is_grace_period_active() -> bool:
	if elapsed_seconds >= run_duration_seconds or get_current_wave_number() == 1:
		return false
	var break_seconds := _get_opening_break_seconds()
	if break_seconds <= 0.0:
		return false
	# Campaign's opening break is an authored pause and is deliberately never cut
	# short: ending it early is what let clear speed change how many reinforcements
	# a wave actually scheduled.
	if not _campaign_mode and _grace_skipped_wave == get_current_wave_number():
		return false
	return get_seconds_into_wave() < break_seconds


func get_grace_remaining_seconds() -> float:
	if not is_grace_period_active():
		return 0.0
	return maxf(0.0, _get_opening_break_seconds() - get_seconds_into_wave())


func is_grazer_surge_wave() -> bool:
	if _campaign_mode:
		# Campaign says what a wave is about in its authored composition table
		# rather than by a repeating cycle.
		var spec := get_current_wave_spec()
		return spec != null and spec.display_name == &"Grazer Surge"
	if grazer_surge_wave_cycle <= 0 or cleanup_started:
		return false
	return get_current_wave_number() % grazer_surge_wave_cycle == 0


func is_complete() -> bool:
	return elapsed_seconds >= run_duration_seconds


func get_packs_requested() -> int:
	return _packs_requested


func get_packs_rejected_at_cap() -> int:
	return _packs_rejected


func get_enemies_spawned() -> int:
	return _enemies_spawned


func get_spawn_topology() -> SpawnTopology:
	return _topology


func report_sector_pressure(local_position: Vector2, amount: float) -> void:
	## Damage taken or Green lost, so the topology knows which side is actually
	## under pressure rather than only which side is crowded.
	if _campaign_mode:
		_topology.report_pressure(local_position, amount)


func _get_opening_break_seconds() -> float:
	if _campaign_mode:
		var spec := get_current_wave_spec()
		return spec.opening_break_seconds if spec != null else 0.0
	return minf(maxf(0.0, wave_grace_period_seconds), maxf(1.0, wave_duration_seconds))


func _update_timeline_events() -> void:
	_apply_enemy_spawn_scaling()
	# Waves are read off the clock rather than counted, so the crossing is
	# announced here once per wave even when debug time skips several at a time.
	var wave_number := get_current_wave_number()
	while announced_wave_number < wave_number:
		announced_wave_number += 1
		_on_wave_boundary_crossed(announced_wave_number)
		wave_began.emit(announced_wave_number)
	if _campaign_mode:
		_update_campaign_milestones()
	else:
		_update_quick_milestones()
	if not final_invasion_started and elapsed_seconds >= final_invasion_time_seconds:
		final_invasion_started = true
		_spawn_remaining = 0.0
		final_invasion_began.emit()
	if not cleanup_started and elapsed_seconds >= cleanup_time_seconds:
		cleanup_started = true
		cleanup_began.emit()
	if not _campaign_mode:
		_update_grace_skip()


func _on_wave_boundary_crossed(wave_number: int) -> void:
	# The pattern index and the leader deck both reset here, which is what makes a
	# wave's requested density a property of the wave rather than of when the
	# previous one happened to end.
	_pattern_index = 0
	_spawn_debt_seconds = 0.0
	_leader_deck = PackedInt32Array()
	_leader_cursor = 0
	_leader_cycle = 0
	if not _campaign_mode:
		return
	var previous := get_wave_spec(wave_number - 1)
	if previous != null and previous.grants_wave_relic:
		wave_relic_earned.emit(wave_number - 1)


func _update_quick_milestones() -> void:
	var milestone_spawn_allowed := not is_grace_period_active()
	if not elite_spawned and elapsed_seconds >= elite_time_seconds and milestone_spawn_allowed:
		if combat.spawn_enemy(CombatDirector.EnemyRole.ELITE) != -1:
			elite_spawned = true
			elite_arrived.emit()
	if not boss_spawned and elapsed_seconds >= boss_time_seconds and milestone_spawn_allowed:
		if combat.spawn_enemy(CombatDirector.EnemyRole.BOSS) != -1:
			boss_spawned = true
			boss_arrived.emit()


func _update_campaign_milestones() -> void:
	## Milestone actors are priority events: they own a reserved slot and keep
	## retrying until their entrance is valid, because the wave they define cannot
	## be silently skipped by a full arena.
	var spec := get_current_wave_spec()
	if spec == null:
		return
	var wave_number := get_current_wave_number()
	var second := get_seconds_into_wave()
	if (
		not elite_spawned
		and spec.elite_spawn_second >= 0.0
		and second >= spec.elite_spawn_second
	):
		if _spawn_milestone(CombatDirector.EnemyRole.ELITE):
			elite_spawned = true
			elite_arrived.emit()
	if (
		not boss_spawned
		and spec.boss_spawn_second >= 0.0
		and second >= spec.boss_spawn_second
	):
		if _spawn_milestone(CombatDirector.EnemyRole.BOSS):
			boss_spawned = true
			boss_arrived.emit()
	# A milestone whose wave has passed is still owed. Retrying it here is what
	# turns a rejected entrance into a delay rather than into a lost reward.
	if not elite_spawned and wave_number > CampaignWaves.ELITE_WAVE:
		if _spawn_milestone(CombatDirector.EnemyRole.ELITE):
			elite_spawned = true
			elite_arrived.emit()
	if not boss_spawned and wave_number > CampaignWaves.BOSS_WAVE:
		if _spawn_milestone(CombatDirector.EnemyRole.BOSS):
			boss_spawned = true
			boss_arrived.emit()


func _spawn_milestone(role: int) -> bool:
	# Scaling is applied for the milestone's own wave first, so an Elite delayed
	# into Wave 8 still fights as the Wave 6 Elite it was authored as.
	var milestone_wave := (
		CampaignWaves.ELITE_WAVE
		if role == CombatDirector.EnemyRole.ELITE
		else CampaignWaves.BOSS_WAVE
	)
	_apply_wave_scaling(get_wave_spec(milestone_wave))
	var spawned := combat.spawn_enemy(role) != -1
	_apply_enemy_spawn_scaling()
	return spawned


func _update_grace_skip() -> void:
	## Ends the opening break of a wave as soon as the arena is empty.
	##
	## Latched for the wave rather than answered fresh each frame: the moment the
	## break ends an enemy spawns, and a live check would put the break straight back
	## on and stall the wave it just released.
	if cleanup_started or combat == null:
		return
	var wave := get_current_wave_number()
	if _grace_skipped_wave == wave or wave == 1:
		return
	if get_seconds_into_wave() >= _get_opening_break_seconds():
		return
	if combat.get_active_enemy_count() > 0:
		return
	_grace_skipped_wave = wave
	grace_skipped.emit(wave)


func _advance_campaign_topology(delta: float) -> void:
	if territory_field == null:
		return
	_topology.advance(
		delta,
		territory_field,
		combat.get_active_enemy_positions(),
		player.get_arena_position() if player != null else territory_field.tuning.arena_size * 0.5
	)


func _update_campaign_spawning(delta: float) -> void:
	## A bounded debt scheduler rather than at most one pack per frame.
	##
	## The old timing tied requested density to the frame rate: a 30 fps machine
	## could not issue the packs a 0.28-second interval asks for, so the same wave
	## was a different wave on different hardware. Debt accumulates in seconds and
	## is spent in whole intervals, with the catch-up bounded so a hitch produces a
	## slightly late wave rather than a sudden wall.
	if cleanup_started or is_grace_period_active():
		return
	var spec := get_current_wave_spec()
	if spec == null:
		return
	var interval := _get_campaign_pack_interval(spec)
	_spawn_debt_seconds += delta
	var packs_this_frame := 0
	while (
		_spawn_debt_seconds >= interval
		and packs_this_frame < maximum_packs_per_frame
	):
		_spawn_debt_seconds -= interval
		_request_campaign_pack(spec)
		packs_this_frame += 1
	_spawn_debt_seconds = minf(
		_spawn_debt_seconds,
		interval * maximum_spawn_debt_intervals
	)


func _get_campaign_pack_interval(spec: CampaignWaveSpec) -> float:
	# The final wave tightens once the invasion is under way rather than arriving
	# at its closing rate, so the last minute has a shape of its own.
	if (
		spec.wave_index == CampaignWaves.WAVE_COUNT
		and get_seconds_into_wave() >= CampaignWaves.FINAL_WAVE_LATE_INTERVAL_SECOND
	):
		return CampaignWaves.FINAL_WAVE_LATE_INTERVAL
	return maxf(0.05, spec.pack_interval_seconds)


func _request_campaign_pack(spec: CampaignWaveSpec) -> void:
	## One scheduled request. A rejected ordinary request is recorded and discarded
	## rather than retried: retrying against a full cap turns the moment the arena
	## clears into a burst nobody asked for.
	_packs_requested += 1
	if combat.get_active_enemy_count() >= regular_reinforcement_cap:
		_packs_rejected += 1
		return
	var leader := _draw_leader_role(spec)
	var pack_size := _next_pack_size(spec)
	var sector := _topology.select_sector(
		spec.spawn_topology,
		leader,
		leader == CampaignWaves.ROLE_RUSHER,
		CampaignWaves.is_specialist_role(leader)
	)
	for index in range(pack_size):
		if combat.get_active_enemy_count() >= regular_reinforcement_cap:
			_packs_rejected += 1
			return
		var role := (
			leader
			if index == 0
			else CampaignWaves.get_follower_role(leader, index, spec.wave_index)
		)
		var point := _topology.get_spawn_point(
			sector,
			_get_spawn_margin(role)
		)
		if combat.spawn_enemy_near(role, point) != -1:
			_enemies_spawned += 1


func _get_spawn_margin(role: int) -> float:
	# The Rusher's whole role is arriving before the player has finished reacting,
	# so it is kept further out than the rest rather than allowed to appear closer.
	return 34.0 if role == CampaignWaves.ROLE_RUSHER else 26.0


func _next_pack_size(spec: CampaignWaveSpec) -> int:
	var pattern := CampaignWaves.get_pack_pattern(spec.pack_pattern)
	if pattern.is_empty():
		return 1
	var size := int(pattern[_pattern_index % pattern.size()])
	_pattern_index += 1
	return size


func _draw_leader_role(spec: CampaignWaveSpec) -> int:
	if _deck_wave != spec.wave_index or _leader_deck.is_empty():
		_deck_wave = spec.wave_index
		_leader_cycle = 0
		_leader_cursor = 0
		_leader_deck = CampaignWaves.shuffle_deck(
			CampaignWaves.build_leader_deck(spec),
			_run_seed,
			spec.wave_index,
			_leader_cycle
		)
	if _leader_cursor >= _leader_deck.size():
		# The same authored deck again, reshuffled, so the proportions hold across
		# a long wave without its second half repeating the order of its first.
		_leader_cycle += 1
		_leader_cursor = 0
		_leader_deck = CampaignWaves.shuffle_deck(
			CampaignWaves.build_leader_deck(spec),
			_run_seed,
			spec.wave_index,
			_leader_cycle
		)
	var role := _leader_deck[_leader_cursor]
	_leader_cursor += 1
	return role


func _update_enemy_spawning(delta: float) -> void:
	if cleanup_started:
		return
	if is_grace_period_active():
		_spawn_remaining = 0.0
		return
	_spawn_remaining -= delta
	if _spawn_remaining > 0.0:
		return
	var progress := _pressure_progress()
	# Grazers are a periodic territorial threat rather than the default body of a
	# pack, so a Bramble run is not permanently fighting its direct counter.
	var grazer_cycle := grazer_pack_cycle
	if is_grazer_surge_wave():
		grazer_cycle = grazer_surge_pack_cycle
	var role := CombatDirector.EnemyRole.HUNTER
	if _grazer_pack_sequence % maxi(1, grazer_cycle) == 0:
		role = CombatDirector.EnemyRole.GRAZER
		if _use_late_variant(heavy_grazer_intro_seconds, heavy_grazer_share):
			role = CombatDirector.EnemyRole.HEAVY_GRAZER
	elif (
		elapsed_seconds >= rusher_intro_seconds
		and _grazer_pack_sequence % maxi(2, rusher_pack_cycle) == 0
	):
		# The Rusher replaces the Hunter rather than accompanying it. A pack that is
		# a Hunter plus a faster Hunter is the same pack; a pack that arrives sooner
		# than the player expected is a different fight.
		role = CombatDirector.EnemyRole.RUSHER
	_grazer_pack_sequence += 1
	var pressure_role := role
	role = _select_regular_role(pressure_role)
	var pack_size := regular_pack_size
	if final_invasion_started:
		pack_size = final_pack_size
	elif progress > late_pack_progress:
		pack_size = late_pack_size
	if role == pressure_role:
		combat.spawn_pack(role, pack_size)
	else:
		combat.spawn_enemy(role)
		if pack_size > 1:
			combat.spawn_pack(pressure_role, pack_size - 1)
	var interval := lerpf(
		early_spawn_interval_seconds,
		late_spawn_interval_seconds,
		progress
	)
	if final_invasion_started:
		interval = final_spawn_interval_seconds
	_spawn_remaining = interval


func _select_regular_role(pressure_role: int) -> int:
	_spawn_pack_sequence += 1
	if (
		elapsed_seconds >= warden_intro_seconds
		and _spawn_pack_sequence % maxi(2, warden_pack_cycle) == 0
	):
		return CombatDirector.EnemyRole.WARDEN
	if (
		elapsed_seconds >= colonizer_intro_seconds
		and _spawn_pack_sequence % maxi(2, colonizer_pack_cycle) == 0
	):
		return CombatDirector.EnemyRole.COLONIZER
	if (
		elapsed_seconds >= corruptor_intro_seconds
		and _spawn_pack_sequence % maxi(2, corruptor_pack_cycle) == 0
	):
		if _use_late_variant(siege_corruptor_intro_seconds, siege_corruptor_share):
			return CombatDirector.EnemyRole.SIEGE_CORRUPTOR
		return CombatDirector.EnemyRole.CORRUPTOR
	if (
		elapsed_seconds >= saboteur_intro_seconds
		and _spawn_pack_sequence % maxi(2, saboteur_pack_cycle) == 0
	):
		return CombatDirector.EnemyRole.SABOTEUR
	return pressure_role


func _use_late_variant(intro_seconds: float, share: float) -> bool:
	# Deterministic rather than rolled. The share is honoured across successive
	# spawns without a run being able to draw the same variant eight times because
	# the dice allowed it, which is the difference between a mix and a streak.
	if elapsed_seconds < intro_seconds or share <= 0.0:
		return false
	if share >= 1.0:
		return true
	_variant_sequence += 1
	var period := maxi(2, int(round(1.0 / share)))
	return _variant_sequence % period == 0


func get_escalation_progress() -> float:
	# How far the run is into its escalation stage, which is what decides how often
	# the rules change. Zero until the run is far enough in to have a build worth
	# changing the rules of, then climbing to one at the final invasion.
	if _campaign_mode:
		var spec := get_current_wave_spec()
		return spec.modifier_chance if spec != null else 0.0
	if elapsed_seconds < elite_modifier_intro_seconds:
		return 0.0
	var span := maxf(1.0, final_invasion_time_seconds - elite_modifier_intro_seconds)
	return clampf((elapsed_seconds - elite_modifier_intro_seconds) / span, 0.0, 1.0)


func _apply_enemy_spawn_scaling() -> void:
	if _campaign_mode:
		_apply_wave_scaling(get_current_wave_spec())
		return
	var progress := _pressure_progress()
	var wave_number := get_current_wave_number()
	var wave_index := wave_number - 1
	combat.set_elite_modifier_pressure(get_escalation_progress())
	combat.set_enemy_scaling(
		lerpf(1.0, final_health_scale, progress),
		lerpf(1.0, final_contact_damage_scale, progress),
		1.0 + float(wave_index) * territory_erosion_growth_per_wave,
		wave_number,
		xp_reward_growth_per_wave,
		xp_minimum_bonus_per_wave
	)


func _apply_wave_scaling(spec: CampaignWaveSpec) -> void:
	## Every enemy spawned during a wave is built from that wave's fixed numbers.
	##
	## Fixed per wave rather than read from continuous run time on purpose: a wave
	## is the unit the player, the telemetry and a deterministic test all reason
	## about, and an enemy whose health depends on the second it spawned in cannot
	## be reasoned about by any of them.
	if spec == null:
		return
	combat.set_campaign_wave_scaling(
		spec.wave_index,
		spec.hp_multiplier,
		spec.contact_damage_multiplier,
		spec.movement_speed_multiplier,
		spec.territory_strength_multiplier,
		spec.territory_action_speed_multiplier,
		spec.cc_resistance,
		_get_campaign_xp_multiplier(spec.wave_index),
		_role_scaling_profiles
	)
	combat.set_modifier_stage(
		spec.modifier_chance,
		CampaignWaves.get_stage_modifiers(spec.modifier_pool_stage),
		spec.wave_index
	)


func _get_campaign_xp_multiplier(wave_number: int) -> float:
	return lerpf(
		1.0,
		campaign_final_xp_multiplier,
		CampaignWaves.get_wave_progress(wave_number)
	)


func _pressure_progress() -> float:
	var ramp := (
		pressure_ramp_seconds
		if pressure_ramp_seconds > 0.0
		else final_invasion_time_seconds
	)
	return clampf(elapsed_seconds / maxf(1.0, ramp), 0.0, 1.0)
