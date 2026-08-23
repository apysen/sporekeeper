class_name PhaseBWaveDirector
extends Node

signal wave_began(wave_number: int)
signal elite_arrived
signal boss_arrived
signal final_invasion_began
signal cleanup_began

@export_group("Collaborators")
## Combat component that receives scaled enemy spawn requests from this director.
@export var combat: PhaseBCombatDirector

@export_group("Run Timeline")
## Total run length in seconds; reaching this time completes the survival objective.
@export_range(60.0, 1200.0, 1.0) var run_duration_seconds := 720.0
## Elapsed run time in seconds when the elite is first scheduled to spawn.
@export_range(10.0, 600.0, 1.0) var elite_time_seconds := 150.0
## Elapsed run time in seconds when the Burrower boss is first scheduled to spawn.
@export_range(20.0, 900.0, 1.0) var boss_time_seconds := 360.0
## Elapsed run time in seconds when final-invasion spawning begins.
@export_range(30.0, 1100.0, 1.0) var final_invasion_time_seconds := 600.0
## Elapsed run time in seconds when reinforcements stop and cleanup begins.
@export_range(30.0, 1150.0, 1.0) var cleanup_time_seconds := 690.0
## Elapsed run time when the player commits to the first of Plant's three paths.
@export_range(0.0, 600.0, 1.0) var primary_path_choice_seconds := 75.0
## Elapsed run time when the player commits to a second path and locks the run pairing.
@export_range(0.0, 900.0, 1.0) var secondary_path_choice_seconds := 180.0
## Earliest elapsed run time at which an evolved run is offered its support path.
## A run that evolves later than this is offered the path as soon as it evolves.
@export_range(0.0, 1200.0, 1.0) var tertiary_path_choice_seconds := 480.0

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
@export_range(0.0, 1100.0, 1.0) var saboteur_intro_seconds := 75.0
## Elapsed run time when regular packs begin including territory-converting Corruptors.
@export_range(0.0, 1100.0, 1.0) var corruptor_intro_seconds := 180.0
## Elapsed run time when regular packs begin including hostile-Core-building Colonizers.
@export_range(0.0, 1100.0, 1.0) var colonizer_intro_seconds := 285.0
## Elapsed run time when regular packs begin including maturity-suppressing Wardens.
@export_range(0.0, 1100.0, 1.0) var warden_intro_seconds := 420.0
## Reinforcement-pack cycle used after introduction; every Nth pack includes a Saboteur.
@export_range(2, 30, 1) var saboteur_pack_cycle := 5
## Reinforcement-pack cycle used after introduction; every Nth pack includes a Corruptor.
@export_range(2, 30, 1) var corruptor_pack_cycle := 7
## Reinforcement-pack cycle used after introduction; every Nth pack includes a Colonizer.
@export_range(2, 30, 1) var colonizer_pack_cycle := 9
## Reinforcement-pack cycle used after introduction; every Nth pack includes a Warden.
@export_range(2, 30, 1) var warden_pack_cycle := 11

var elapsed_seconds := 0.0
var announced_wave_number := 1
var elite_spawned := false
var boss_spawned := false
var final_invasion_started := false
var cleanup_started := false

var _spawn_remaining := 0.0
var _spawn_pack_sequence := 0
var _grazer_pack_sequence := 0


func _ready() -> void:
	assert(combat != null, "PhaseBWaveDirector requires PhaseBCombatDirector")


func reset_director() -> void:
	elapsed_seconds = 0.0
	announced_wave_number = 1
	elite_spawned = false
	boss_spawned = false
	final_invasion_started = false
	cleanup_started = false
	_spawn_remaining = opening_spawn_delay_seconds
	_spawn_pack_sequence = 0
	_grazer_pack_sequence = 0
	_apply_enemy_spawn_scaling()


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
		return PhaseBCombatDirector.EnemyRole.CORRUPTOR
	if (
		elapsed_seconds >= saboteur_intro_seconds
		and _spawn_pack_sequence % maxi(2, saboteur_pack_cycle) == 0
	):
		return PhaseBCombatDirector.EnemyRole.SABOTEUR
	return pressure_role


func _apply_enemy_spawn_scaling() -> void:
	var progress := _pressure_progress()
	var wave_number := get_current_wave_number()
	var wave_index := wave_number - 1
	combat.set_enemy_scaling(
		lerpf(1.0, final_health_scale, progress),
		lerpf(1.0, final_contact_damage_scale, progress),
		1.0 + float(wave_index) * territory_erosion_growth_per_wave,
		wave_number,
		xp_reward_growth_per_wave,
		xp_minimum_bonus_per_wave
	)


func _pressure_progress() -> float:
	return clampf(
		elapsed_seconds / maxf(1.0, final_invasion_time_seconds),
		0.0,
		1.0
	)
