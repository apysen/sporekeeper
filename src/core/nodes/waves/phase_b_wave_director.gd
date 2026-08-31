class_name PhaseBWaveDirector
extends Node

const RUN_MODE := preload("res://src/core/models/run/phase_b_run_mode.gd")

signal wave_began(wave_number: int)
## The arena was cleared during a wave's opening break, so the break ended early.
signal grace_skipped(wave_number: int)
signal elite_arrived
signal boss_arrived
signal final_invasion_began
signal cleanup_began

@export_group("Collaborators")
## Combat component that receives scaled enemy spawn requests from this director.
@export var combat: PhaseBCombatDirector

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
@export_range(0.0, 1800.0, 1.0) var pressure_ramp_seconds := 0.0
## Elapsed run time in seconds when reinforcements stop and cleanup begins.
@export_range(30.0, 1800.0, 1.0) var cleanup_time_seconds := 690.0
## Earliest elapsed run time at which an evolved run is offered its support path.
## A run that evolves later than this is offered the path as soon as it evolves.
@export_range(0.0, 1800.0, 1.0) var tertiary_path_choice_seconds := 480.0

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

@export_group("Per-Wave Scaling")
## Additive territory-erosion multiplier gained by newly spawned enemies each wave.
@export_range(0.0, 1.0, 0.01) var territory_erosion_growth_per_wave := 0.10
## Proportional XP reward increase gained by newly spawned enemies each wave.
@export_range(0.0, 1.0, 0.01) var xp_reward_growth_per_wave := 0.10
## Minimum flat XP added per completed wave when proportional growth rounds too low.
@export_range(0, 10, 1) var xp_minimum_bonus_per_wave := 1
## Enemy-health multiplier reached when final-invasion pressure reaches 100%.
@export_range(1.0, 5.0, 0.05) var final_health_scale := 2.15
## Enemy contact-damage multiplier reached at 100% final-invasion pressure.
@export_range(1.0, 5.0, 0.05) var final_contact_damage_scale := 1.60

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
		"tertiary_path_choice_seconds",
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
	# Quick retains the original 12-minute tuning. Campaign stretches the authored
	# milestones and introduces a gentler XP curve so 30 minutes keeps producing
	# meaningful adaptation choices while its final pressure still escalates.
	#
	# Every field is restored to what was authored before a mode is applied, so
	# configuring a mode says what that mode is rather than what has changed since
	# the last one.
	_capture_authored_mode_values()
	for field in _authored_mode_values:
		set(field, _authored_mode_values[field])
	if mode != RUN_MODE.Id.CAMPAIGN:
		return
	run_duration_seconds = 1800.0
	elite_time_seconds = 375.0
	boss_time_seconds = 900.0
	final_invasion_time_seconds = 1500.0
	# The last thirty seconds, which is the shape Quick already had: 690 of 720.
	# At 1725 the cleanup ran for seventy-five seconds and began in wave 29, so the
	# whole of wave 30 had no reinforcements in it -- the final wave of a thirty
	# minute run was an empty one. Campaign was meant to stretch Quick's milestones,
	# not to restructure the ending.
	cleanup_time_seconds = 1770.0
	# Pressure builds on its own clock rather than across the whole timeline. A
	# thirty-minute run should be a bigger run than a twelve-minute one, not a
	# slower one, so it reaches full pressure around the boss and then holds there
	# until the invasion rather than creeping toward it for twenty-five minutes.
	pressure_ramp_seconds = 900.0
	tertiary_path_choice_seconds = 1200.0
	# The opening was slower than Quick's, not faster: a longer run was reading as
	# an emptier one. Campaign now opens denser than Quick and doubles its packs
	# before the boss instead of at the fifteen-minute mark.
	early_spawn_interval_seconds = 0.95
	late_spawn_interval_seconds = 0.38
	final_spawn_interval_seconds = 0.14
	late_pack_progress = 0.45
	final_health_scale = 3.0
	final_contact_damage_scale = 2.0
	# Role introductions follow the pressure ramp rather than the whole timeline.
	# Stretched across thirty minutes, the specialists that make a wave feel
	# different arrived long after the wave that needed them.
	saboteur_intro_seconds = 115.0
	corruptor_intro_seconds = 270.0
	colonizer_intro_seconds = 430.0
	warden_intro_seconds = 630.0
	heavy_grazer_intro_seconds = 495.0
	rusher_intro_seconds = 450.0
	siege_corruptor_intro_seconds = 630.0
	elite_modifier_intro_seconds = 450.0


func _ready() -> void:
	assert(combat != null, "PhaseBWaveDirector requires PhaseBCombatDirector")
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
	_apply_enemy_spawn_scaling()
	combat.set_elite_modifier_pressure(0.0)


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	elapsed_seconds = minf(run_duration_seconds, elapsed_seconds + delta)
	_update_timeline_events()
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
	if combat.spawn_enemy(PhaseBCombatDirector.EnemyRole.BOSS) == -1:
		return false
	boss_spawned = true
	return true


func get_current_wave_number() -> int:
	var wave_duration := maxf(1.0, wave_duration_seconds)
	var maximum_wave := maxi(1, ceili(run_duration_seconds / wave_duration))
	return clampi(
		int(floor(elapsed_seconds / wave_duration)) + 1,
		1,
		maximum_wave
	)


func is_grace_period_active() -> bool:
	if elapsed_seconds >= run_duration_seconds or get_current_wave_number() == 1:
		return false
	# A break the player has already earned their way out of. Clearing the arena is
	# the whole point of a wave, and standing in an empty one waiting for a timer is
	# the game withholding the next wave from someone who has asked for it.
	if _grace_skipped_wave == get_current_wave_number():
		return false
	var wave_duration := maxf(1.0, wave_duration_seconds)
	var grace_duration := minf(maxf(0.0, wave_grace_period_seconds), wave_duration)
	return fmod(elapsed_seconds, wave_duration) < grace_duration


func get_grace_remaining_seconds() -> float:
	if not is_grace_period_active():
		return 0.0
	return maxf(
		0.0,
		wave_grace_period_seconds
		- fmod(elapsed_seconds, maxf(1.0, wave_duration_seconds))
	)


func is_grazer_surge_wave() -> bool:
	if grazer_surge_wave_cycle <= 0 or cleanup_started:
		return false
	return get_current_wave_number() % grazer_surge_wave_cycle == 0


func is_complete() -> bool:
	return elapsed_seconds >= run_duration_seconds


func _update_timeline_events() -> void:
	_apply_enemy_spawn_scaling()
	# Waves are read off the clock rather than counted, so the crossing is
	# announced here once per wave even when debug time skips several at a time.
	var wave_number := get_current_wave_number()
	while announced_wave_number < wave_number:
		announced_wave_number += 1
		wave_began.emit(announced_wave_number)
	var milestone_spawn_allowed := not is_grace_period_active()
	if not elite_spawned and elapsed_seconds >= elite_time_seconds and milestone_spawn_allowed:
		if combat.spawn_enemy(PhaseBCombatDirector.EnemyRole.ELITE) != -1:
			elite_spawned = true
			elite_arrived.emit()
	if not boss_spawned and elapsed_seconds >= boss_time_seconds and milestone_spawn_allowed:
		if combat.spawn_enemy(PhaseBCombatDirector.EnemyRole.BOSS) != -1:
			boss_spawned = true
			boss_arrived.emit()
	if not final_invasion_started and elapsed_seconds >= final_invasion_time_seconds:
		final_invasion_started = true
		_spawn_remaining = 0.0
		final_invasion_began.emit()
	if not cleanup_started and elapsed_seconds >= cleanup_time_seconds:
		cleanup_started = true
		cleanup_began.emit()
	_update_grace_skip()


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
	var wave_duration := maxf(1.0, wave_duration_seconds)
	var grace_duration := minf(maxf(0.0, wave_grace_period_seconds), wave_duration)
	if fmod(elapsed_seconds, wave_duration) >= grace_duration:
		return
	if combat.get_active_enemy_count() > 0:
		return
	_grace_skipped_wave = wave
	grace_skipped.emit(wave)


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
	var role := PhaseBCombatDirector.EnemyRole.HUNTER
	if _grazer_pack_sequence % maxi(1, grazer_cycle) == 0:
		role = PhaseBCombatDirector.EnemyRole.GRAZER
		if _use_late_variant(heavy_grazer_intro_seconds, heavy_grazer_share):
			role = PhaseBCombatDirector.EnemyRole.HEAVY_GRAZER
	elif (
		elapsed_seconds >= rusher_intro_seconds
		and _grazer_pack_sequence % maxi(2, rusher_pack_cycle) == 0
	):
		# The Rusher replaces the Hunter rather than accompanying it. A pack that is
		# a Hunter plus a faster Hunter is the same pack; a pack that arrives sooner
		# than the player expected is a different fight.
		role = PhaseBCombatDirector.EnemyRole.RUSHER
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
		return PhaseBCombatDirector.EnemyRole.WARDEN
	if (
		elapsed_seconds >= colonizer_intro_seconds
		and _spawn_pack_sequence % maxi(2, colonizer_pack_cycle) == 0
	):
		return PhaseBCombatDirector.EnemyRole.COLONIZER
	if (
		elapsed_seconds >= corruptor_intro_seconds
		and _spawn_pack_sequence % maxi(2, corruptor_pack_cycle) == 0
	):
		if _use_late_variant(siege_corruptor_intro_seconds, siege_corruptor_share):
			return PhaseBCombatDirector.EnemyRole.SIEGE_CORRUPTOR
		return PhaseBCombatDirector.EnemyRole.CORRUPTOR
	if (
		elapsed_seconds >= saboteur_intro_seconds
		and _spawn_pack_sequence % maxi(2, saboteur_pack_cycle) == 0
	):
		return PhaseBCombatDirector.EnemyRole.SABOTEUR
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
	if elapsed_seconds < elite_modifier_intro_seconds:
		return 0.0
	var span := maxf(1.0, final_invasion_time_seconds - elite_modifier_intro_seconds)
	return clampf((elapsed_seconds - elite_modifier_intro_seconds) / span, 0.0, 1.0)


func _apply_enemy_spawn_scaling() -> void:
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


func _pressure_progress() -> float:
	var ramp := (
		pressure_ramp_seconds
		if pressure_ramp_seconds > 0.0
		else final_invasion_time_seconds
	)
	return clampf(elapsed_seconds / maxf(1.0, ramp), 0.0, 1.0)
