class_name WaveDirector
extends Node

const RUN_MODE := preload("res://src/core/models/run/run_mode.gd")

signal wave_began(wave_number: int)
## The arena was cleared during a wave's opening break, so the break ended early.
## Quick keeps this; Campaign breaks are authored pauses and never end early.
signal grace_skipped(wave_number: int)
signal elite_arrived
signal boss_arrived
## The Hive Queen has entered. Its own event rather than a second `boss_arrived`,
## because the run says something different about her and because a listener that
## counted boss arrivals would otherwise start counting two.
signal hive_queen_arrived
signal final_invasion_began
signal cleanup_began
## A Campaign wave whose completion opens one of the ten authored relic rewards.
signal wave_relic_earned(wave_number: int)
## A Campaign wave milestone that offers every Evolution the run now qualifies for.
signal evolution_reward_earned(wave_number: int)
## A Campaign wave that hands the player a draft of Adaptations they do not own.
signal path_draft_earned(wave_number: int)
## The player called the next wave early, giving up the seconds carried here.
signal wave_provoked(wave_number: int, seconds_skipped: float)
## Blight rose, because a rewarded Provocation was taken.
signal blight_changed(level: int)
## A provoked wave was survived, so a Growth choice is owed.
signal growth_reward_earned
## A Campaign wave that sets a Trial, and the wave boundary that answers the last one.
## Both carry the wave they belong to so a listener can tell them apart in a log.
signal trial_wave_began(wave_number: int)
signal trial_wave_ended(wave_number: int)

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
## Elapsed run time in seconds when the Hive Queen is first scheduled to spawn.
##
## Quick's own number: three minutes after the Burrower and one before the final
## invasion, which leaves room to clear her brood before the last phase arrives on
## top of it. Campaign overwrites this from its wave table.
@export_range(20.0, 1800.0, 1.0) var hive_queen_time_seconds := 540.0
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
## Encounter recipes one frame may place. A hitch releases several intervals of
## credit at once, and a burst the player never saw coming must not be how it is
## paid back, so catch-up is spread across frames rather than being unlimited.
@export_range(1, 8, 1) var maximum_packs_per_frame := 2
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
## Campaign XP multiplier reached at the final wave.
##
## Raised with the Threat Director, and for its sake. Late Campaign now buys quality
## instead of population, so a late wave puts far fewer bodies on the board than the
## old density curve did; without more XP per body, a twenty-minute Campaign would
## finish its build later than the twenty-five-minute one it replaced. Still well
## under the health curve, so a dense wave does not fund itself.
@export_range(1.0, 6.0, 0.05) var campaign_final_xp_multiplier := 3.00

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

@export_group("Provocation")
## Seconds into a wave after which the next one may always be called early.
##
## Forty of sixty, so Provocation is reaching into the peak and the recovery rather
## than skipping the wave. A player who wants the run to go faster gives up the only
## part of it that was going to be quiet.
@export_range(0.0, 120.0, 1.0) var provoke_unlock_seconds := 40.0
## The other door: a wave whose released threat has mostly been cleared is provokable
## sooner. Both conditions are needed, so a lull thirty seconds in does not count as
## having beaten a wave that has barely started.
##
## Deliberately measured against threat the Director actually released and the player
## actually removed, never against theoretical build strength -- the Campaign is not
## allowed to read Grandma's damage and respond to it.
@export_range(0.0, 1.0, 0.01) var provoke_release_floor := 0.40
@export_range(0.0, 1.0, 0.01) var provoke_cleared_fraction := 0.80
## Seconds of Campaign a run may skip by Provoking, across the whole run.
##
## Four minutes of twenty, so an aggressive run finishes around sixteen and a
## conservative one around twenty. Uncapped, nineteen Provocations at twenty-odd
## seconds each would take a twenty-minute Campaign under thirteen, and the
## structure needs time to breathe however far ahead of it the player is: the point
## of Provocation is a faster, more dangerous run, not a different, shorter game.
@export_range(0.0, 900.0, 5.0) var maximum_provoked_seconds := 240.0
## Surge credit granted per second of recovery given up.
##
## The immediate, temporary half of a Provocation. Called five seconds early it is a
## nudge; called twenty seconds early it is most of another encounter arriving at the
## front of a wave that has not finished opening. Earlier calls buy danger, never a
## larger permanent reward -- that asymmetry is what stops "provoke as early as
## possible" from being the only correct way to play.
@export_range(0.0, 200.0, 0.5) var surge_credit_per_second := 14.0

@export_group("Escalation")
## Elapsed run time at which elites may begin carrying rule changes at all. The
## design note ties this to the run's own progression rather than the clock, and
## the clock is the honest approximation of it: by here a run has a pairing, a
## build, and something for a rule change to be a change to.
##
## Quick only. Campaign gates rule changes on its authored per-wave stages.
@export_range(0.0, 1800.0, 1.0) var elite_modifier_intro_seconds := 300.0

var elapsed_seconds := 0.0
## Seconds actually played, which Provocation makes shorter than the schedule.
##
## `elapsed_seconds` is the Campaign's *position*: the wave, the curves and every
## milestone are read off it, and Provocation moves it forward by the recovery the
## player gave up. This is the wall clock beside it, so a run that finished Wave 20
## in seventeen minutes records seventeen minutes rather than twenty.
var real_elapsed_seconds := 0.0
var announced_wave_number := 1
## The wave whose opening break has already been cut short by the arena being
## cleared. Latched per wave rather than recomputed, because the break must not come
## back the moment the first replacement enemy appears.
var _grace_skipped_wave := 0
var elite_spawned := false
var boss_spawned := false
var hive_queen_spawned := false
var final_invasion_started := false
var cleanup_started := false

var _spawn_remaining := 0.0
var _spawn_pack_sequence := 0
var _grazer_pack_sequence := 0
## Bumped every time a specialist variant is chosen, so the Heavy and Siege shares
## alternate deterministically instead of being rolled. A run should not be able to
## get eight Heavy Grazers in a row because the dice said so.
var _variant_sequence := 0

## Whether this run is the authored 20-wave Campaign rather than Quick's ramp.
var _campaign_mode := false
var _wave_specs: Array[CampaignWaveSpec] = []
var _role_scaling_profiles := {}
var _topology := SpawnTopology.new()
var _run_seed := 0
## The run's permanent Blight, raised one level by each rewarded Provocation and
## never lowered. Read by the budget, by enemy health and damage, and by the price
## the Director pays for its expensive recipes.
var _blight_level := 0
## Provocations taken, the Campaign seconds they have skipped between them, and the
## surge waiting to be injected into the next wave.
var _provocations := 0
var _provoked_seconds := 0.0
var _pending_surge_credit := 0.0
## The waves whose end each owes a Growth reward. Paid when that wave ends rather
## than at the moment of the call: the Growth is the reward for living through the
## encounter, not for asking for it.
##
## A list rather than one wave, because a player can Provoke out of a wave they were
## already owed a Growth for -- they still survived it, and a single slot would have
## quietly dropped the first reward every time the second was earned.
var _growth_owed_waves := PackedInt32Array()
## How the current Campaign wave spends itself.
var _threat := ThreatDirector.new()
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
		"hive_queen_time_seconds",
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
	hive_queen_time_seconds = (
		float(CampaignWaves.HIVE_QUEEN_WAVE - 1) * CampaignWaves.WAVE_DURATION_SECONDS
		+ CampaignWaves.HIVE_QUEEN_SPAWN_SECOND
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
	hive_queen_spawned = false
	final_invasion_started = false
	cleanup_started = false
	real_elapsed_seconds = 0.0
	_blight_level = 0
	_provocations = 0
	_provoked_seconds = 0.0
	_pending_surge_credit = 0.0
	_growth_owed_waves = PackedInt32Array()
	_spawn_remaining = opening_spawn_delay_seconds
	_spawn_pack_sequence = 0
	_grazer_pack_sequence = 0
	_variant_sequence = 0
	_packs_requested = 0
	_packs_rejected = 0
	_enemies_spawned = 0
	set_run_seed(_run_seed if _run_seed != 0 else (randi() | 1))
	_apply_enemy_spawn_scaling()
	combat.set_elite_modifier_pressure(0.0)
	blight_changed.emit(_blight_level)
	_begin_campaign_wave(1)


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	real_elapsed_seconds += delta
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
	if combat.spawn_enemy(EnemyKinds.Role.BOSS) == -1:
		return false
	boss_spawned = true
	return true


func debug_spawn_hive_queen() -> bool:
	## The Queen's counterpart to `debug_spawn_boss`, for a probe that wants the fight
	## without the twenty waves in front of it. `has_active_boss` covers both bosses,
	## so this refuses while either is up rather than putting two on the board.
	if combat.has_active_boss():
		return false
	_apply_enemy_spawn_scaling()
	if combat.spawn_enemy(EnemyKinds.Role.HIVE_QUEEN) == -1:
		return false
	hive_queen_spawned = true
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


## Whether the player may call the next wave in right now.
##
## Two doors. The first is the clock: forty seconds into a sixty-second wave, which
## is the point at which what remains is the peak and the recovery. The second is
## having actually finished it -- most of the wave's threat released, and most of
## what was released already dead.
##
## The second door reads threat the Director spent and enemies that are no longer on
## the board. It never reads Grandma's damage, her build, or her Paths: the Campaign
## responds to what the player has *done*, and a difficulty system that reads what
## they are capable of is the thing this rework exists to avoid.
func can_provoke() -> bool:
	if not _campaign_mode or cleanup_started or is_complete():
		return false
	if get_current_wave_number() >= get_final_wave_number():
		return false
	if is_grace_period_active():
		return false
	if not has_provocation_budget():
		return false
	if get_seconds_into_wave() >= provoke_unlock_seconds:
		return true
	if _threat.get_released_fraction() < provoke_release_floor:
		return false
	return get_cleared_threat_fraction() >= provoke_cleared_fraction


## Share of the threat this wave has released that is no longer standing.
##
## Measured as spent-minus-alive rather than by counting kills, because what matters
## is whether the board is clear and an enemy that walked off a cliff of Bramble
## damage counts the same as one the Cane killed. Alive threat is priced with the
## same table the Director bought them from, so a wave holding one Siege Corruptor
## is not "cleared" the way a wave holding one Hunter is.
func get_cleared_threat_fraction() -> float:
	var spent := _threat.get_spent()
	if spent <= 0.0:
		return 0.0
	var alive := 0.0
	for role in EncounterRecipes.THREAT_COSTS:
		alive += float(
			combat.get_active_enemy_count_by_role(int(role))
			* EncounterRecipes.get_role_cost(int(role))
		)
	return clampf((spent - alive) / spent, 0.0, 1.0)


## Calls the next wave in early. Returns the seconds of recovery given up, or zero
## when the call was refused.
##
## Everything already on the board stays on it. That is the whole mechanic: the next
## wave arrives on top of what the player has not finished, without the authored
## pause that would normally separate them, with a Surge at its front proportional
## to how early it was called, and with the run permanently one level more Blighted
## if that level was still available to buy.
func provoke() -> float:
	if not can_provoke():
		return 0.0
	var wave_number := get_current_wave_number()
	var skipped := _seconds_left_in_wave()
	if skipped <= 0.0:
		return 0.0
	_provoked_seconds += skipped
	# The schedule jumps; the wall clock does not. `elapsed_seconds` is where the
	# Campaign is, and Provocation is the player moving the Campaign forward -- which
	# is why a provoked run finishes Wave 20 in less than twenty minutes.
	elapsed_seconds = minf(run_duration_seconds, elapsed_seconds + skipped)
	_provocations += 1
	_pending_surge_credit += skipped * surge_credit_per_second
	if _blight_level < BlightTable.MAXIMUM_LEVEL:
		_blight_level += 1
		# Owed to the wave this call is about to start, and paid when that wave ends.
		_growth_owed_waves.append(wave_number + 1)
		blight_changed.emit(_blight_level)
	wave_provoked.emit(wave_number, skipped)
	_update_timeline_events()
	return skipped


## Whether the run has enough of its compression allowance left to call this wave.
##
## Separate from `can_provoke` because the two refusals are not the same thing and
## must not print the same sentence. "Not yet, hold the wave longer" is true when the
## window has not opened; it is a lie when the window is open and the run has simply
## spent its four minutes, and a player told to wait longer for something that will
## never come again learns to distrust the prompt.
##
## The whole remainder has to fit: a partial skip would charge a Blight level and
## leave the run mid-wave. As the allowance runs down this tapers -- only later,
## smaller calls still fit -- rather than stopping dead.
func has_provocation_budget() -> bool:
	if not _campaign_mode:
		return false
	return _provoked_seconds + _seconds_left_in_wave() <= maximum_provoked_seconds


func _seconds_left_in_wave() -> float:
	return maxf(0.0, wave_duration_seconds - get_seconds_into_wave())


func debug_set_blight(level: int) -> void:
	## Forces the run's Blight, so "is Blight V materially harder than Blight 0" can
	## be answered by running the same build at both rather than by reading the table
	## and multiplying in one's head. The wave in progress is rebuilt underneath it,
	## because the budget it was handed was priced at the old level.
	_blight_level = BlightTable.clamp_level(level)
	blight_changed.emit(_blight_level)
	_begin_campaign_wave(get_current_wave_number())


func get_blight_level() -> int:
	return _blight_level


func get_blight_name() -> String:
	return BlightTable.get_level_name(_blight_level)


func get_provocation_count() -> int:
	return _provocations


func get_seconds_left_in_wave() -> float:
	## What a Provocation right now would skip, which is the number the button's own
	## tooltip is about. Public because the cost of a call is stated to the player
	## before they make it rather than reported after it.
	return _seconds_left_in_wave()


func get_provoked_seconds() -> float:
	return _provoked_seconds


func get_wave_threat_budget() -> float:
	return _threat.get_budget()


func get_wave_threat_spent() -> float:
	return _threat.get_spent()


func get_current_act() -> int:
	return CampaignWaves.get_act(get_current_wave_number()) if _campaign_mode else 0


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
	if not _campaign_mode:
		return
	var previous := get_wave_spec(wave_number - 1)
	if previous != null and previous.grants_wave_relic:
		wave_relic_earned.emit(wave_number - 1)
	# A Provocation's Growth is the reward for living through the wave it called,
	# which is the wave that has just ended.
	var still_owed := PackedInt32Array()
	for owed_wave in _growth_owed_waves:
		if wave_number > owed_wave:
			growth_reward_earned.emit()
		else:
			still_owed.append(owed_wave)
	_growth_owed_waves = still_owed
	_begin_campaign_wave(wave_number)
	var spec := get_wave_spec(wave_number)
	if spec == null:
		return
	# Both are offers rather than grants: what the run is eligible for is Progression's
	# question, and a wave that opens a door nobody can walk through simply opens it.
	if spec.grants_path_draft:
		path_draft_earned.emit(wave_number)
	if spec.grants_evolution_reward:
		evolution_reward_earned.emit(wave_number)
	# The Trial that was running is answered before a new one is set, so a Trial wave
	# followed immediately by another cannot swallow the first one's reward.
	if previous != null and previous.grants_trial:
		trial_wave_ended.emit(wave_number - 1)
	if spec.grants_trial:
		trial_wave_began.emit(wave_number)


func _update_quick_milestones() -> void:
	var milestone_spawn_allowed := not is_grace_period_active()
	if not elite_spawned and elapsed_seconds >= elite_time_seconds and milestone_spawn_allowed:
		if combat.spawn_enemy(EnemyKinds.Role.ELITE) != -1:
			elite_spawned = true
			elite_arrived.emit()
	if not boss_spawned and elapsed_seconds >= boss_time_seconds and milestone_spawn_allowed:
		if combat.spawn_enemy(EnemyKinds.Role.BOSS) != -1:
			boss_spawned = true
			boss_arrived.emit()
	if (
		not hive_queen_spawned
		and elapsed_seconds >= hive_queen_time_seconds
		and milestone_spawn_allowed
	):
		if combat.spawn_enemy(EnemyKinds.Role.HIVE_QUEEN) != -1:
			hive_queen_spawned = true
			hive_queen_arrived.emit()


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
		if _spawn_milestone(EnemyKinds.Role.ELITE):
			elite_spawned = true
			elite_arrived.emit()
	if (
		not boss_spawned
		and spec.boss_spawn_second >= 0.0
		and second >= spec.boss_spawn_second
	):
		if _spawn_milestone(EnemyKinds.Role.BOSS):
			boss_spawned = true
			boss_arrived.emit()
	if (
		not hive_queen_spawned
		and spec.hive_queen_spawn_second >= 0.0
		and second >= spec.hive_queen_spawn_second
	):
		if _spawn_milestone(EnemyKinds.Role.HIVE_QUEEN):
			hive_queen_spawned = true
			hive_queen_arrived.emit()
	# A milestone whose wave has passed is still owed. Retrying it here is what
	# turns a rejected entrance into a delay rather than into a lost reward.
	if not elite_spawned and wave_number > CampaignWaves.ELITE_WAVE:
		if _spawn_milestone(EnemyKinds.Role.ELITE):
			elite_spawned = true
			elite_arrived.emit()
	if not boss_spawned and wave_number > CampaignWaves.BOSS_WAVE:
		if _spawn_milestone(EnemyKinds.Role.BOSS):
			boss_spawned = true
			boss_arrived.emit()
	if not hive_queen_spawned and wave_number > CampaignWaves.HIVE_QUEEN_WAVE:
		if _spawn_milestone(EnemyKinds.Role.HIVE_QUEEN):
			hive_queen_spawned = true
			hive_queen_arrived.emit()


func _spawn_milestone(role: int) -> bool:
	# Scaling is applied for the milestone's own wave first, so an Elite delayed
	# into Wave 8 still fights as the Wave 6 Elite it was authored as.
	var milestone_wave := CampaignWaves.BOSS_WAVE
	if role == EnemyKinds.Role.ELITE:
		milestone_wave = CampaignWaves.ELITE_WAVE
	elif role == EnemyKinds.Role.HIVE_QUEEN:
		milestone_wave = CampaignWaves.HIVE_QUEEN_WAVE
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
	## The Threat Director spending one frame's worth of the wave's budget.
	##
	## The old scheduler was a pack interval and a pack size, and a bounded debt
	## counter so the frame rate could not change how many packs a wave issued. The
	## budget replaces all three: credit is released on the wave's own clock, so a
	## hitch defers a purchase rather than losing it, and how many enemies a wave
	## placed is a property of what it bought rather than of how often it was asked.
	if cleanup_started:
		return
	var spec := get_current_wave_spec()
	if spec == null:
		return
	# Released during the opening break too -- the release curve already treats the
	# break as time the wave is not spending in, so this is a no-op rather than an
	# exception somebody has to remember.
	_threat.advance(delta)
	if is_grace_period_active():
		return
	var placed := 0
	while placed < maximum_packs_per_frame:
		if combat.get_active_enemy_count() >= regular_reinforcement_cap:
			# Recorded and dropped, exactly as a rejected pack always was. Retrying
			# against a full cap turns the moment the arena clears into a burst
			# nobody asked for.
			_packs_rejected += 1
			return
		var recipe := _threat.next_purchase(_has_canker_entrance())
		if recipe == &"":
			return
		_packs_requested += 1
		_place_recipe(spec, recipe)
		placed += 1


func _begin_campaign_wave(wave_number: int) -> void:
	## Hands one wave's budget, recipe list and act gate to the Threat Director, with
	## Blight on the budget and any Surge the player just bought injected at its front.
	if not _campaign_mode:
		return
	var spec := get_wave_spec(wave_number)
	if spec == null:
		return
	_threat.begin_wave(
		spec.wave_index,
		spec.act,
		spec.threat_budget * BlightTable.get_budget_multiplier(_blight_level),
		spec.recipe_ids,
		spec.duration_seconds,
		spec.opening_break_seconds,
		_blight_level,
		spec.sustains_final_pressure,
		_run_seed
	)
	if _pending_surge_credit > 0.0:
		_threat.add_surge_credit(_pending_surge_credit)
		_pending_surge_credit = 0.0


func _has_canker_entrance() -> bool:
	## Whether an interior recipe has anywhere to come out of. The Director never
	## makes a Canker; it only notices that territory failure has made one.
	return combat != null and combat.has_active_cankers()


func _place_recipe(spec: CampaignWaveSpec, recipe_id: StringName) -> void:
	## One bought pack, put on the board.
	##
	## The recipe names its own topology, because a Siege Push entering from a
	## rotating ring is not a siege. The wave's profile is the fallback for a recipe
	## that has no opinion, which keeps a wave's authored shape meaningful without
	## letting it overrule a pack whose whole identity is where it comes from.
	var members := EncounterRecipes.get_members(recipe_id)
	if members.is_empty():
		return
	var leader := members[0]
	var topology := EncounterRecipes.get_topology(recipe_id)
	if topology == &"":
		topology = spec.spawn_topology
	var sector := _topology.select_sector(
		topology,
		leader,
		leader == CampaignWaves.ROLE_RUSHER,
		CampaignWaves.is_specialist_role(leader)
	)
	var opposite := posmod(sector + SpawnTopology.SECTOR_COUNT / 2, SpawnTopology.SECTOR_COUNT)
	var split := EncounterRecipes.is_split(recipe_id)
	var interior := EncounterRecipes.is_interior(recipe_id)
	var half := members.size() / 2
	for index in range(members.size()):
		if combat.get_active_enemy_count() >= regular_reinforcement_cap:
			_packs_rejected += 1
			return
		var role := members[index]
		# A split pack is two fronts, not one larger one: its second half enters
		# opposite the first, which is the entire content of an encounter that exists
		# to ask a stationary build to be in two places.
		var entry := sector if not (split and index >= half) else opposite
		var point := _topology.get_spawn_point(entry, _get_spawn_margin(role))
		var spawned := (
			combat.spawn_enemy_from_canker(role, point)
			if interior
			else combat.spawn_enemy_near(role, point)
		)
		if spawned != -1:
			_enemies_spawned += 1


func _get_spawn_margin(role: int) -> float:
	# The Rusher's whole role is arriving before the player has finished reacting,
	# so it is kept further out than the rest rather than allowed to appear closer.
	return 34.0 if role == CampaignWaves.ROLE_RUSHER else 26.0


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
	var role := EnemyKinds.Role.HUNTER
	if _grazer_pack_sequence % maxi(1, grazer_cycle) == 0:
		role = EnemyKinds.Role.GRAZER
		if _use_late_variant(heavy_grazer_intro_seconds, heavy_grazer_share):
			role = EnemyKinds.Role.HEAVY_GRAZER
	elif (
		elapsed_seconds >= rusher_intro_seconds
		and _grazer_pack_sequence % maxi(2, rusher_pack_cycle) == 0
	):
		# The Rusher replaces the Hunter rather than accompanying it. A pack that is
		# a Hunter plus a faster Hunter is the same pack; a pack that arrives sooner
		# than the player expected is a different fight.
		role = EnemyKinds.Role.RUSHER
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
	var selection := QuickComposition.select_role(
		_quick_schedule(), elapsed_seconds, _spawn_pack_sequence, _variant_sequence, pressure_role
	)
	_variant_sequence = selection.variant_sequence
	return selection.role


## The authored schedule, read at the moment of the decision rather than kept, so a
## cycle edited in the Inspector during a playtest is obeyed by the next pack.
func _quick_schedule() -> QuickComposition.Schedule:
	var schedule := QuickComposition.Schedule.new()
	schedule.warden_intro_seconds = warden_intro_seconds
	schedule.warden_pack_cycle = warden_pack_cycle
	schedule.colonizer_intro_seconds = colonizer_intro_seconds
	schedule.colonizer_pack_cycle = colonizer_pack_cycle
	schedule.corruptor_intro_seconds = corruptor_intro_seconds
	schedule.corruptor_pack_cycle = corruptor_pack_cycle
	schedule.saboteur_intro_seconds = saboteur_intro_seconds
	schedule.saboteur_pack_cycle = saboteur_pack_cycle
	schedule.siege_corruptor_intro_seconds = siege_corruptor_intro_seconds
	schedule.siege_corruptor_share = siege_corruptor_share
	return schedule


func _use_late_variant(intro_seconds: float, share: float) -> bool:
	var variant := QuickComposition.next_variant(
		elapsed_seconds, intro_seconds, share, _variant_sequence
	)
	_variant_sequence = int(variant[1])
	return bool(variant[0])


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
	# Blight rides on the authored curves rather than replacing them, and it moves
	# health and damage by a fraction of what it moves the budget by. A player who
	# chose a harder run should meet harder encounters, not the same encounter with a
	# longer time-to-kill.
	combat.set_campaign_wave_scaling(
		spec.wave_index,
		spec.hp_multiplier * BlightTable.get_health_multiplier(_blight_level),
		spec.contact_damage_multiplier * BlightTable.get_damage_multiplier(_blight_level),
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


## Where the run is on its timeline.
##
## The clock is the whole of it: `elapsed_seconds` decides the wave, the milestones,
## the scaling and the composition, so restoring the clock restores the schedule.
## What is captured alongside it is the state that cannot be derived from the clock -
## the events that fire once and would otherwise fire a second time, and the cursors
## that make a wave's packs deterministic within it.
##
## `_wave_specs`, `_role_scaling_profiles` and `_authored_mode_values` are not kept.
## They come from `configure_mode` and the authored resources, which means a resumed
## run gets this build's tuning rather than the tuning of the build that saved.
func capture_state() -> Dictionary:
	return {
		"elapsed_seconds": elapsed_seconds,
		"announced_wave_number": announced_wave_number,
		"grace_skipped_wave": _grace_skipped_wave,
		"elite_spawned": elite_spawned,
		"boss_spawned": boss_spawned,
		"hive_queen_spawned": hive_queen_spawned,
		"final_invasion_started": final_invasion_started,
		"cleanup_started": cleanup_started,
		"real_elapsed_seconds": real_elapsed_seconds,
		"blight_level": _blight_level,
		"provocations": _provocations,
		"provoked_seconds": _provoked_seconds,
		"pending_surge_credit": _pending_surge_credit,
		"growth_owed_waves": _growth_owed_waves,
		"spawn_remaining": _spawn_remaining,
		"spawn_pack_sequence": _spawn_pack_sequence,
		"grazer_pack_sequence": _grazer_pack_sequence,
		"variant_sequence": _variant_sequence,
		"run_seed": _run_seed,
		"packs_requested": _packs_requested,
		"packs_rejected": _packs_rejected,
		"enemies_spawned": _enemies_spawned,
	}


func apply_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	set_run_seed(int(state.get("run_seed", _run_seed)))
	elapsed_seconds = float(state.get("elapsed_seconds", 0.0))
	announced_wave_number = maxi(1, int(state.get("announced_wave_number", 1)))
	_grace_skipped_wave = int(state.get("grace_skipped_wave", 0))
	elite_spawned = bool(state.get("elite_spawned", false))
	boss_spawned = bool(state.get("boss_spawned", false))
	hive_queen_spawned = bool(state.get("hive_queen_spawned", false))
	final_invasion_started = bool(state.get("final_invasion_started", false))
	cleanup_started = bool(state.get("cleanup_started", false))
	real_elapsed_seconds = float(state.get("real_elapsed_seconds", elapsed_seconds))
	_blight_level = BlightTable.clamp_level(int(state.get("blight_level", 0)))
	_provocations = int(state.get("provocations", 0))
	_provoked_seconds = float(state.get("provoked_seconds", 0.0))
	_pending_surge_credit = float(state.get("pending_surge_credit", 0.0))
	var owed: Variant = state.get("growth_owed_waves")
	_growth_owed_waves = (
		owed as PackedInt32Array if owed is PackedInt32Array else PackedInt32Array()
	)
	_spawn_remaining = float(state.get("spawn_remaining", 0.0))
	_spawn_pack_sequence = int(state.get("spawn_pack_sequence", 0))
	_grazer_pack_sequence = int(state.get("grazer_pack_sequence", 0))
	_variant_sequence = int(state.get("variant_sequence", 0))
	_packs_requested = int(state.get("packs_requested", 0))
	_packs_rejected = int(state.get("packs_rejected", 0))
	_enemies_spawned = int(state.get("enemies_spawned", 0))
	# The wave in progress is rebuilt rather than restored: its budget, act and
	# recipe list come from this build's tables, and a resumed run gets the schedule
	# the current build authors rather than the one the save was written against.
	# What is restored is everything that cannot be derived -- the clock, the Blight
	# the player chose, and the Growth a Provocation still owes them.
	_begin_campaign_wave(get_current_wave_number())
	blight_changed.emit(_blight_level)
