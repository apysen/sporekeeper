class_name CampaignWaves
extends RefCounted

## The authored 25-wave Campaign, in one place.
##
## Every wave of the Campaign is a CampaignWaveSpec built here from the authored
## curves and composition tables. Keeping the whole schedule in one builder rather
## than as twenty-five files on disk means a curve is edited as a curve -- the six
## pressure lerps are five lines, not twenty-five hand-copied numbers that can
## drift apart -- while the director still only ever reads a resource.
##
## The six coordinated curves are health, contact damage, movement speed, territory
## strength, territory action speed, and composition. Raw enemy count is a
## supporting tool: Sporekeeper turns density into kills, corpses, contagion and
## collisions, so bodies alone can strengthen a finished build instead of
## threatening it.

const WAVE_COUNT := 25
const WAVE_DURATION_SECONDS := 60.0
const CAMPAIGN_DURATION_SECONDS := 1500.0
## Reinforcements stop here so the final quarter-minute is fought, not spawned into.
const FINAL_REINFORCEMENT_CUTOFF_SECONDS := 1485.0

## Enemy role ids, mirrored from CombatDirector.EnemyRole. Duplicated as
## constants so the authored table below reads as a table rather than as a column
## of fully qualified enum paths, and so this model never depends on a node script.
const ROLE_HUNTER := 0
const ROLE_GRAZER := 1
const ROLE_ELITE := 2
const ROLE_BOSS := 3
const ROLE_SABOTEUR := 4
const ROLE_CORRUPTOR := 5
const ROLE_COLONIZER := 6
const ROLE_WARDEN := 7
const ROLE_COLONY_CORE := 8
const ROLE_HEAVY_GRAZER := 9
const ROLE_RUSHER := 10
const ROLE_SIEGE_CORRUPTOR := 11

## Modifier ids, mirrored from CombatDirector.EliteModifier.
const MODIFIER_NONE := 0
const MODIFIER_UNSTOPPABLE := 1
const MODIFIER_BLIGHTED := 2
const MODIFIER_RAVENOUS := 3
const MODIFIER_REGENERATIVE := 4
const MODIFIER_DISRUPTIVE := 5
const MODIFIER_VOLATILE := 6

## Wave-25 end multipliers. Wave 25 is the top of each smooth curve and applies no
## extra final-wave spike: the last wave is brutal because everything has matured
## together, not because a hidden multiplier lands on it.
const OPENING_HP_MULTIPLIER := 1.10
const FINAL_HP_MULTIPLIER := 3.60
const OPENING_CONTACT_MULTIPLIER := 1.05
const FINAL_CONTACT_MULTIPLIER := 2.25
const OPENING_MOVEMENT_MULTIPLIER := 1.00
const FINAL_MOVEMENT_MULTIPLIER := 1.15
const OPENING_TERRITORY_MULTIPLIER := 1.10
const FINAL_TERRITORY_MULTIPLIER := 3.20
const OPENING_ACTION_SPEED_MULTIPLIER := 1.00
const FINAL_ACTION_SPEED_MULTIPLIER := 1.22

## Crowd-control resistance and modifier chance per wave, indexed from Wave 1.
##
## These two are authored tables rather than lerps because they are not straight
## lines. Resistance holds at nothing until Wave 9 -- Bramble and Fruit deserve a
## third of the run where their control is worth exactly what it says -- and then
## climbs unevenly. Modifier chance opens slowly, steps up at the Wave 13 Boss, and
## steps again after the Wave 18 showcase, so the last third is fought against
## behaviour rather than against larger numbers.
##
## Plain Arrays rather than Packed ones because only a plain Array literal is a
## constant expression in GDScript; a Packed constructor is a call, and a call
## cannot initialise a const.
const CC_RESISTANCE_BY_WAVE := [
	0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00,
	0.02, 0.03, 0.04, 0.05, 0.07, 0.08, 0.09, 0.10,
	0.11, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.20,
]
const MODIFIER_CHANCE_BY_WAVE := [
	0.00, 0.00, 0.00, 0.05, 0.06, 0.08, 0.10, 0.12,
	0.14, 0.16, 0.18, 0.20, 0.23, 0.26, 0.29, 0.32,
	0.35, 0.40, 0.43, 0.46, 0.49, 0.52, 0.55, 0.60, 0.70,
]

## Waves whose completion opens one of the Campaign's ten relic opportunities. The
## Elite and Boss defeats are the other two.
const RELIC_WAVES := [3, 6, 9, 12, 15, 18, 21, 24]

const ELITE_WAVE := 6
const ELITE_SPAWN_SECOND := 35.0
const BOSS_WAVE := 13
## Immediately after the wave's opening cue, which is its authored break.
const BOSS_SPAWN_SECOND := 2.5

## Wave at which the objective specialists join the modifier system.
const LATE_MODIFIER_ROLE_WAVE := 13

## Pack-size sequences. The index resets at each wave boundary, which is what makes
## requested density deterministic rather than a function of when the last wave
## happened to end.
const PACK_PATTERNS := {
	&"ONE": [1],
	&"ONE_ONE_ONE_TWO": [1, 1, 1, 2],
	&"ONE_ONE_TWO": [1, 1, 2],
	&"ONE_TWO": [1, 2],
	&"TWO": [2],
	&"TWO_TWO_TWO_THREE": [2, 2, 2, 3],
	&"TWO_TWO_THREE": [2, 2, 3],
	&"TWO_THREE": [2, 3],
	&"THREE": [3],
}

## Perimeter placement profiles. Each names a way of choosing which of the eight
## perimeter sectors a pack enters from, so a wave's pressure has a shape rather
## than only a size.
const TOPOLOGY_EVEN_RING := &"EVEN_RING"
const TOPOLOGY_TWO_SIDE_PINCER := &"TWO_SIDE_PINCER"
const TOPOLOGY_CLUSTERED_FRONT := &"CLUSTERED_FRONT"
const TOPOLOGY_WEAK_SIDE_RUSH := &"WEAK_SIDE_RUSH"
const TOPOLOGY_SPECIALIST_OPPOSITE_PACK := &"SPECIALIST_OPPOSITE_PACK"
const TOPOLOGY_COLONIZER_DISTRACTION := &"COLONIZER_DISTRACTION"
const TOPOLOGY_THREE_FRONT_PRESSURE := &"THREE_FRONT_PRESSURE"
const TOPOLOGY_FINAL_ROTATION := &"FINAL_ROTATION"

## Mixed into the run seed per wave so two runs shuffle their leader decks
## differently while one run replays exactly.
const PRIME_WAVE_SEED := 7919

## Wave 25 tightens once the invasion is under way rather than arriving at its
## final rate: the cue, the opening rate, then the closing rate, then silence.
const FINAL_WAVE_LATE_INTERVAL := 0.22
const FINAL_WAVE_LATE_INTERVAL_SECOND := 25.0

## Wave identity, cadence, composition, and topology. One row per wave, in the
## order the player meets them. Everything else on a spec is a curve this builder
## evaluates, so a row says what makes its wave different and nothing else.
##
## Role weights are percentages of non-milestone reinforcement leaders and sum to
## 100 in every row.
const AUTHORED_WAVES := [
	{
		"name": &"Garden Under Attack", "break": 0.0, "interval": 0.80,
		"pattern": &"ONE", "topology": TOPOLOGY_EVEN_RING,
		"roles": {ROLE_HUNTER: 70, ROLE_GRAZER: 30},
	},
	{
		"name": &"Sabotage", "break": 4.0, "interval": 0.78,
		"pattern": &"ONE", "topology": TOPOLOGY_EVEN_RING,
		"roles": {ROLE_HUNTER: 55, ROLE_GRAZER: 30, ROLE_SABOTEUR: 15},
	},
	{
		"name": &"Corruption", "break": 4.0, "interval": 0.76,
		"pattern": &"ONE", "topology": TOPOLOGY_EVEN_RING,
		"roles": {ROLE_HUNTER: 45, ROLE_GRAZER: 25, ROLE_SABOTEUR: 15, ROLE_CORRUPTOR: 15},
	},
	{
		"name": &"Grazer Surge", "break": 3.5, "interval": 0.74,
		"pattern": &"ONE", "topology": TOPOLOGY_CLUSTERED_FRONT,
		"roles": {ROLE_GRAZER: 65, ROLE_HUNTER: 15, ROLE_SABOTEUR: 10, ROLE_HEAVY_GRAZER: 10},
	},
	{
		"name": &"Rush", "break": 3.5, "interval": 0.72,
		"pattern": &"ONE_ONE_ONE_TWO", "topology": TOPOLOGY_TWO_SIDE_PINCER,
		"roles": {
			ROLE_HUNTER: 45, ROLE_RUSHER: 20, ROLE_GRAZER: 20,
			ROLE_SABOTEUR: 10, ROLE_CORRUPTOR: 5,
		},
	},
	{
		"name": &"Rootbreaker", "break": 3.5, "interval": 0.70,
		"pattern": &"ONE_ONE_TWO", "topology": TOPOLOGY_CLUSTERED_FRONT,
		"roles": {
			ROLE_HUNTER: 40, ROLE_GRAZER: 20, ROLE_HEAVY_GRAZER: 10,
			ROLE_RUSHER: 10, ROLE_SABOTEUR: 10, ROLE_CORRUPTOR: 10,
		},
	},
	{
		"name": &"Colonization", "break": 3.0, "interval": 0.68,
		"pattern": &"ONE_TWO", "topology": TOPOLOGY_COLONIZER_DISTRACTION,
		"roles": {
			ROLE_HUNTER: 30, ROLE_GRAZER: 20, ROLE_COLONIZER: 15, ROLE_HEAVY_GRAZER: 10,
			ROLE_SABOTEUR: 10, ROLE_CORRUPTOR: 10, ROLE_RUSHER: 5,
		},
	},
	{
		"name": &"Mixed Pressure", "break": 3.0, "interval": 0.66,
		"pattern": &"TWO", "topology": TOPOLOGY_COLONIZER_DISTRACTION,
		"roles": {
			ROLE_HUNTER: 30, ROLE_GRAZER: 20, ROLE_HEAVY_GRAZER: 10, ROLE_RUSHER: 10,
			ROLE_SABOTEUR: 10, ROLE_CORRUPTOR: 10, ROLE_COLONIZER: 10,
		},
	},
	{
		"name": &"Warden", "break": 3.0, "interval": 0.64,
		"pattern": &"TWO", "topology": TOPOLOGY_WEAK_SIDE_RUSH,
		"roles": {
			ROLE_HUNTER: 25, ROLE_GRAZER: 15, ROLE_HEAVY_GRAZER: 10, ROLE_RUSHER: 10,
			ROLE_SABOTEUR: 10, ROLE_CORRUPTOR: 10, ROLE_COLONIZER: 10, ROLE_WARDEN: 10,
		},
	},
	{
		"name": &"Horde", "break": 3.0, "interval": 0.62,
		"pattern": &"TWO", "topology": TOPOLOGY_CLUSTERED_FRONT,
		"roles": {
			ROLE_HUNTER: 45, ROLE_GRAZER: 20, ROLE_HEAVY_GRAZER: 15, ROLE_RUSHER: 20,
		},
	},
	{
		"name": &"Siege", "break": 2.5, "interval": 0.60,
		"pattern": &"TWO", "topology": TOPOLOGY_TWO_SIDE_PINCER,
		"roles": {
			ROLE_HUNTER: 25, ROLE_GRAZER: 15, ROLE_HEAVY_GRAZER: 10, ROLE_RUSHER: 10,
			ROLE_CORRUPTOR: 15, ROLE_SIEGE_CORRUPTOR: 10, ROLE_SABOTEUR: 5,
			ROLE_COLONIZER: 5, ROLE_WARDEN: 5,
		},
	},
	{
		"name": &"Specialist Mix", "break": 2.5, "interval": 0.58,
		"pattern": &"TWO", "topology": TOPOLOGY_TWO_SIDE_PINCER,
		"roles": {
			ROLE_HUNTER: 15, ROLE_GRAZER: 10, ROLE_HEAVY_GRAZER: 10, ROLE_RUSHER: 5,
			ROLE_SABOTEUR: 15, ROLE_CORRUPTOR: 15, ROLE_SIEGE_CORRUPTOR: 10,
			ROLE_COLONIZER: 10, ROLE_WARDEN: 10,
		},
	},
	{
		"name": &"Burrower", "break": 2.5, "interval": 0.56,
		"pattern": &"TWO", "topology": TOPOLOGY_TWO_SIDE_PINCER,
		"roles": {
			ROLE_HUNTER: 25, ROLE_GRAZER: 15, ROLE_HEAVY_GRAZER: 10, ROLE_RUSHER: 10,
			ROLE_SABOTEUR: 10, ROLE_CORRUPTOR: 10, ROLE_SIEGE_CORRUPTOR: 5,
			ROLE_COLONIZER: 10, ROLE_WARDEN: 5,
		},
	},
	{
		"name": &"Recovery Denied", "break": 2.5, "interval": 0.54,
		"pattern": &"TWO", "topology": TOPOLOGY_SPECIALIST_OPPOSITE_PACK,
		"roles": {
			ROLE_GRAZER: 30, ROLE_HEAVY_GRAZER: 30, ROLE_HUNTER: 15, ROLE_SABOTEUR: 5,
			ROLE_CORRUPTOR: 5, ROLE_SIEGE_CORRUPTOR: 5, ROLE_COLONIZER: 5, ROLE_WARDEN: 5,
		},
	},
	{
		"name": &"Rush Hour", "break": 2.5, "interval": 0.52,
		"pattern": &"TWO", "topology": TOPOLOGY_WEAK_SIDE_RUSH,
		"roles": {
			ROLE_RUSHER: 35, ROLE_HUNTER: 35, ROLE_GRAZER: 10, ROLE_HEAVY_GRAZER: 5,
			ROLE_SABOTEUR: 5, ROLE_CORRUPTOR: 5, ROLE_SIEGE_CORRUPTOR: 5,
		},
	},
	{
		"name": &"Siege Line", "break": 2.0, "interval": 0.50,
		"pattern": &"TWO", "topology": TOPOLOGY_SPECIALIST_OPPOSITE_PACK,
		"roles": {
			ROLE_CORRUPTOR: 20, ROLE_SIEGE_CORRUPTOR: 20, ROLE_WARDEN: 15,
			ROLE_COLONIZER: 10, ROLE_HEAVY_GRAZER: 10, ROLE_GRAZER: 10,
			ROLE_HUNTER: 10, ROLE_SABOTEUR: 5,
		},
	},
	{
		"name": &"Swarm", "break": 2.0, "interval": 0.48,
		"pattern": &"TWO", "topology": TOPOLOGY_CLUSTERED_FRONT,
		"roles": {
			ROLE_HUNTER: 50, ROLE_GRAZER: 25, ROLE_HEAVY_GRAZER: 15, ROLE_RUSHER: 10,
		},
	},
	{
		"name": &"Mutation", "break": 2.0, "interval": 0.46,
		"pattern": &"TWO", "topology": TOPOLOGY_SPECIALIST_OPPOSITE_PACK,
		"roles": {
			ROLE_HUNTER: 20, ROLE_GRAZER: 15, ROLE_HEAVY_GRAZER: 15, ROLE_RUSHER: 10,
			ROLE_SABOTEUR: 10, ROLE_CORRUPTOR: 10, ROLE_SIEGE_CORRUPTOR: 10,
			ROLE_COLONIZER: 5, ROLE_WARDEN: 5,
		},
	},
	{
		"name": &"Colony War", "break": 2.0, "interval": 0.44,
		"pattern": &"TWO", "topology": TOPOLOGY_THREE_FRONT_PRESSURE,
		"roles": {
			ROLE_COLONIZER: 25, ROLE_CORRUPTOR: 15, ROLE_SIEGE_CORRUPTOR: 10,
			ROLE_WARDEN: 10, ROLE_HUNTER: 15, ROLE_GRAZER: 10,
			ROLE_HEAVY_GRAZER: 10, ROLE_RUSHER: 5,
		},
	},
	{
		"name": &"Devour", "break": 2.0, "interval": 0.42,
		"pattern": &"TWO", "topology": TOPOLOGY_THREE_FRONT_PRESSURE,
		"roles": {
			ROLE_HEAVY_GRAZER: 35, ROLE_GRAZER: 25, ROLE_HUNTER: 10, ROLE_CORRUPTOR: 10,
			ROLE_SIEGE_CORRUPTOR: 10, ROLE_COLONIZER: 5, ROLE_WARDEN: 5,
		},
	},
	{
		"name": &"Combined Arms", "break": 1.5, "interval": 0.38,
		"pattern": &"TWO_TWO_TWO_THREE", "topology": TOPOLOGY_THREE_FRONT_PRESSURE,
		"roles": {
			ROLE_HUNTER: 20, ROLE_GRAZER: 15, ROLE_HEAVY_GRAZER: 10, ROLE_RUSHER: 10,
			ROLE_SABOTEUR: 10, ROLE_CORRUPTOR: 10, ROLE_SIEGE_CORRUPTOR: 10,
			ROLE_COLONIZER: 8, ROLE_WARDEN: 7,
		},
	},
	{
		"name": &"Breach", "break": 1.5, "interval": 0.37,
		"pattern": &"TWO_TWO_THREE", "topology": TOPOLOGY_WEAK_SIDE_RUSH,
		"roles": {
			ROLE_RUSHER: 30, ROLE_SIEGE_CORRUPTOR: 20, ROLE_CORRUPTOR: 10,
			ROLE_HUNTER: 15, ROLE_HEAVY_GRAZER: 10, ROLE_WARDEN: 10, ROLE_SABOTEUR: 5,
		},
	},
	{
		"name": &"Infestation", "break": 1.5, "interval": 0.36,
		"pattern": &"TWO_THREE", "topology": TOPOLOGY_COLONIZER_DISTRACTION,
		"roles": {
			ROLE_SABOTEUR: 15, ROLE_CORRUPTOR: 15, ROLE_SIEGE_CORRUPTOR: 15,
			ROLE_COLONIZER: 15, ROLE_WARDEN: 15, ROLE_HEAVY_GRAZER: 10,
			ROLE_RUSHER: 10, ROLE_HUNTER: 5,
		},
	},
	{
		"name": &"Collapse", "break": 1.5, "interval": 0.34,
		"pattern": &"THREE", "topology": TOPOLOGY_THREE_FRONT_PRESSURE,
		"roles": {
			ROLE_HUNTER: 15, ROLE_GRAZER: 10, ROLE_HEAVY_GRAZER: 15, ROLE_RUSHER: 10,
			ROLE_SABOTEUR: 10, ROLE_CORRUPTOR: 10, ROLE_SIEGE_CORRUPTOR: 10,
			ROLE_COLONIZER: 10, ROLE_WARDEN: 10,
		},
	},
	{
		"name": &"Final Invasion", "break": 1.25, "interval": 0.28,
		"pattern": &"THREE", "topology": TOPOLOGY_FINAL_ROTATION,
		"roles": {
			ROLE_HUNTER: 15, ROLE_GRAZER: 10, ROLE_HEAVY_GRAZER: 15, ROLE_RUSHER: 10,
			ROLE_SABOTEUR: 10, ROLE_CORRUPTOR: 10, ROLE_SIEGE_CORRUPTOR: 10,
			ROLE_COLONIZER: 10, ROLE_WARDEN: 10,
		},
	},
]


static func get_wave_count() -> int:
	return WAVE_COUNT


static func build_wave_specs() -> Array[CampaignWaveSpec]:
	## The whole Campaign, built once and handed to the director.
	var specs: Array[CampaignWaveSpec] = []
	for index in range(AUTHORED_WAVES.size()):
		specs.append(_build_wave_spec(index + 1, AUTHORED_WAVES[index]))
	return specs


static func _build_wave_spec(wave_number: int, authored: Dictionary) -> CampaignWaveSpec:
	var spec := CampaignWaveSpec.new()
	spec.wave_index = wave_number
	spec.display_name = authored["name"]
	spec.duration_seconds = WAVE_DURATION_SECONDS
	spec.opening_break_seconds = authored["break"]
	spec.hp_multiplier = get_hp_multiplier(wave_number)
	spec.contact_damage_multiplier = get_contact_damage_multiplier(wave_number)
	spec.movement_speed_multiplier = get_movement_speed_multiplier(wave_number)
	spec.territory_strength_multiplier = get_territory_strength_multiplier(wave_number)
	spec.territory_action_speed_multiplier = get_territory_action_speed_multiplier(wave_number)
	spec.cc_resistance = get_cc_resistance(wave_number)
	spec.modifier_chance = get_modifier_chance(wave_number)
	spec.pack_interval_seconds = authored["interval"]
	spec.pack_pattern = authored["pattern"]
	spec.role_weights = authored["roles"].duplicate()
	spec.spawn_topology = authored["topology"]
	spec.modifier_pool_stage = get_modifier_pool_stage(wave_number)
	spec.elite_spawn_second = ELITE_SPAWN_SECOND if wave_number == ELITE_WAVE else -1.0
	spec.boss_spawn_second = BOSS_SPAWN_SECOND if wave_number == BOSS_WAVE else -1.0
	spec.grants_wave_relic = RELIC_WAVES.has(wave_number)
	return spec


static func get_wave_progress(wave_number: int) -> float:
	## Position of a wave along every global curve, from 0 at Wave 1 to 1 at Wave 25.
	return float(clampi(wave_number, 1, WAVE_COUNT) - 1) / float(WAVE_COUNT - 1)


static func get_hp_multiplier(wave_number: int) -> float:
	return lerpf(
		OPENING_HP_MULTIPLIER,
		FINAL_HP_MULTIPLIER,
		get_wave_progress(wave_number)
	)


static func get_contact_damage_multiplier(wave_number: int) -> float:
	return lerpf(
		OPENING_CONTACT_MULTIPLIER,
		FINAL_CONTACT_MULTIPLIER,
		get_wave_progress(wave_number)
	)


static func get_movement_speed_multiplier(wave_number: int) -> float:
	return lerpf(
		OPENING_MOVEMENT_MULTIPLIER,
		FINAL_MOVEMENT_MULTIPLIER,
		get_wave_progress(wave_number)
	)


static func get_territory_strength_multiplier(wave_number: int) -> float:
	return lerpf(
		OPENING_TERRITORY_MULTIPLIER,
		FINAL_TERRITORY_MULTIPLIER,
		get_wave_progress(wave_number)
	)


static func get_territory_action_speed_multiplier(wave_number: int) -> float:
	return lerpf(
		OPENING_ACTION_SPEED_MULTIPLIER,
		FINAL_ACTION_SPEED_MULTIPLIER,
		get_wave_progress(wave_number)
	)


static func get_cc_resistance(wave_number: int) -> float:
	## Nothing before Wave 9, then a climb to 20% at Wave 25. Never an immunity:
	## every root, shove and slow still lands, shortened.
	return float(CC_RESISTANCE_BY_WAVE[clampi(wave_number, 1, WAVE_COUNT) - 1])


static func get_modifier_chance(wave_number: int) -> float:
	## Rule changes begin at Wave 4 and accelerate after the Wave 18 showcase, so
	## the last third of the Campaign is fought against behaviour rather than only
	## against larger numbers.
	return float(MODIFIER_CHANCE_BY_WAVE[clampi(wave_number, 1, WAVE_COUNT) - 1])


static func get_modifier_pool_stage(wave_number: int) -> int:
	var wave := clampi(wave_number, 1, WAVE_COUNT)
	if wave <= 3:
		return 0
	if wave <= 8:
		return 1
	if wave <= 12:
		return 2
	if wave <= 17:
		return 3
	return 4


static func get_stage_modifiers(stage: int) -> PackedInt32Array:
	## What a wave's rule changes can be. Each stage adds to the last rather than
	## replacing it, so a modifier the player has learned to read never disappears.
	match stage:
		1:
			return PackedInt32Array([MODIFIER_REGENERATIVE, MODIFIER_UNSTOPPABLE])
		2:
			return PackedInt32Array([
				MODIFIER_REGENERATIVE, MODIFIER_UNSTOPPABLE,
				MODIFIER_BLIGHTED, MODIFIER_DISRUPTIVE,
			])
		3:
			return PackedInt32Array([
				MODIFIER_REGENERATIVE, MODIFIER_UNSTOPPABLE,
				MODIFIER_BLIGHTED, MODIFIER_DISRUPTIVE, MODIFIER_RAVENOUS,
			])
		4:
			return PackedInt32Array([
				MODIFIER_REGENERATIVE, MODIFIER_UNSTOPPABLE,
				MODIFIER_BLIGHTED, MODIFIER_DISRUPTIVE,
				MODIFIER_RAVENOUS, MODIFIER_VOLATILE,
			])
	return PackedInt32Array()


static func get_pack_pattern(pattern_id: StringName) -> Array:
	if PACK_PATTERNS.has(pattern_id):
		return PACK_PATTERNS[pattern_id]
	return PACK_PATTERNS[&"ONE"]


static func build_role_scaling_profiles() -> Dictionary:
	## Role id to EnemyRoleScalingProfile.
	##
	## Movement is the sensitive one. A Rusher that received the whole Wave 25
	## movement curve would arrive faster than the reaction window the role exists
	## to test, so it takes half of it and the Boss takes less still. Grazers keep
	## their authored bite cadence and scale only the rest between bursts.
	var profiles := {}
	profiles[ROLE_HUNTER] = _role_profile(ROLE_HUNTER, 1.00, 0.00)
	var grazer := _role_profile(ROLE_GRAZER, 1.00, 1.00)
	grazer.scales_rest_interval_only = true
	profiles[ROLE_GRAZER] = grazer
	var heavy_grazer := _role_profile(ROLE_HEAVY_GRAZER, 1.10, 1.00)
	heavy_grazer.scales_rest_interval_only = true
	heavy_grazer.modifier_eligible_from_wave = 4
	profiles[ROLE_HEAVY_GRAZER] = heavy_grazer
	var rusher := _role_profile(ROLE_RUSHER, 0.50, 0.00)
	rusher.modifier_eligible_from_wave = 4
	profiles[ROLE_RUSHER] = rusher
	profiles[ROLE_SABOTEUR] = _role_profile(ROLE_SABOTEUR, 0.90, 0.85)
	profiles[ROLE_CORRUPTOR] = _role_profile(ROLE_CORRUPTOR, 0.85, 0.85)
	var siege := _role_profile(ROLE_SIEGE_CORRUPTOR, 0.85, 0.80)
	siege.modifier_eligible_from_wave = 4
	profiles[ROLE_SIEGE_CORRUPTOR] = siege
	var colonizer := _role_profile(ROLE_COLONIZER, 0.80, 0.75)
	colonizer.modifier_eligible_from_wave = LATE_MODIFIER_ROLE_WAVE
	profiles[ROLE_COLONIZER] = colonizer
	var warden := _role_profile(ROLE_WARDEN, 0.80, 0.75)
	warden.modifier_eligible_from_wave = LATE_MODIFIER_ROLE_WAVE
	profiles[ROLE_WARDEN] = warden
	profiles[ROLE_COLONY_CORE] = _role_profile(ROLE_COLONY_CORE, 0.00, 0.75)
	var elite := _role_profile(ROLE_ELITE, 0.50, 0.00)
	elite.role_cc_resistance = 0.20
	profiles[ROLE_ELITE] = elite
	var boss := _role_profile(ROLE_BOSS, 0.40, 0.65)
	boss.role_cc_resistance = 0.35
	profiles[ROLE_BOSS] = boss
	return profiles


static func _role_profile(
	role_id: int,
	movement_factor: float,
	action_factor: float
) -> EnemyRoleScalingProfile:
	var profile := EnemyRoleScalingProfile.new()
	profile.role_id = role_id
	profile.movement_scaling_factor = movement_factor
	profile.action_speed_scaling_factor = action_factor
	return profile


static func build_leader_deck(spec: CampaignWaveSpec) -> PackedInt32Array:
	## A hundred entries in the authored proportions, consumed one per pack.
	##
	## Deliberately a deck rather than a weighted roll per pack. Independent rolls
	## produce streaks -- eight Colonizers in a row because the dice allowed it --
	## and a wave whose identity is its composition cannot survive that. The deck
	## guarantees the proportions and the shuffle keeps the order unpredictable.
	var deck := PackedInt32Array()
	var roles := spec.role_weights.keys()
	roles.sort()
	for role in roles:
		for _entry in range(int(spec.role_weights[role])):
			deck.append(int(role))
	if deck.is_empty():
		deck.append(ROLE_HUNTER)
	# An under-filled row still produces a full deck rather than a short one, so a
	# mis-authored wave degrades into slightly wrong proportions instead of into a
	# reshuffle every few packs.
	var authored_size := deck.size()
	var index := 0
	while deck.size() < 100:
		deck.append(deck[index % authored_size])
		index += 1
	return deck


static func shuffle_deck(
	deck: PackedInt32Array,
	run_seed: int,
	wave_index: int,
	cycle: int
) -> PackedInt32Array:
	## Fisher-Yates from a generator seeded by the run, the wave and the reshuffle
	## count, so one seed replays exactly and a long wave does not repeat its own
	## order when the deck is exhausted.
	var shuffled := deck.duplicate()
	var random := RandomNumberGenerator.new()
	random.seed = run_seed + wave_index * PRIME_WAVE_SEED + cycle * 104729
	for index in range(shuffled.size() - 1, 0, -1):
		var swap := random.randi() % (index + 1)
		var held := shuffled[index]
		shuffled[index] = shuffled[swap]
		shuffled[swap] = held
	return shuffled


static func is_specialist_role(role: int) -> bool:
	## A role whose presence changes what the pack is about rather than how large
	## it is. Follower rules cap how many of these one pack may carry.
	return role in [
		ROLE_SABOTEUR, ROLE_CORRUPTOR, ROLE_SIEGE_CORRUPTOR,
		ROLE_COLONIZER, ROLE_WARDEN,
	]


static func get_follower_role(
	leader_role: int,
	follower_index: int,
	wave_number: int
) -> int:
	## What accompanies a leader. Pressure roles bring more pressure; a specialist
	## brings escort rather than a second copy of itself, because two Colonizers
	## through one entrance is a problem the player cannot split.
	match leader_role:
		ROLE_HUNTER:
			# One Rusher per pack before Wave 21, so a Hunter pack stays a Hunter
			# pack rather than quietly becoming a Rusher pack.
			if wave_number >= 21:
				return ROLE_RUSHER if follower_index % 2 == 1 else ROLE_HUNTER
			if follower_index == 1 and wave_number >= 5:
				return ROLE_RUSHER
			return ROLE_HUNTER
		ROLE_GRAZER:
			if wave_number >= 14:
				return ROLE_HEAVY_GRAZER if follower_index % 2 == 1 else ROLE_GRAZER
			if follower_index == 1 and wave_number >= 4:
				return ROLE_HEAVY_GRAZER
			return ROLE_GRAZER
		ROLE_HEAVY_GRAZER:
			if wave_number >= 14:
				return ROLE_HEAVY_GRAZER if follower_index % 2 == 1 else ROLE_GRAZER
			return ROLE_GRAZER
		ROLE_RUSHER:
			return ROLE_HUNTER
	if is_specialist_role(leader_role):
		# Waves 24 and 25 may mix a second specialist in, never a third.
		if wave_number >= 24 and follower_index == 1:
			return ROLE_HUNTER if leader_role == ROLE_WARDEN else ROLE_HEAVY_GRAZER
		return ROLE_GRAZER if follower_index % 2 == 1 else ROLE_HUNTER
	return ROLE_HUNTER
