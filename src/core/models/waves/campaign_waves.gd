class_name CampaignWaves
extends RefCounted

## The authored 20-wave Campaign, in one place.
##
## Every wave of the Campaign is a CampaignWaveSpec built here from the authored
## curves and encounter tables. Keeping the whole schedule in one builder rather than
## as twenty files on disk means a curve is edited as a curve -- the six pressure
## lerps are five lines, not twenty hand-copied numbers that can drift apart -- while
## the director still only ever reads a resource.
##
## Twenty minutes rather than twenty-five, in four acts. The measured Campaign
## reached its last meaningful Evolution rank around minute thirteen and then ran for
## another twelve, so half of it was spent after the build had finished becoming
## itself. The four acts name what each quarter is for: establish a build, make it
## interact, complete it, then find out whether it survives.
##
## A wave is a **threat budget** and a list of encounter recipes, not a pack interval
## and a pack size. Raw enemy count is not a difficulty lever in this game: Sporekeeper
## turns density into kills, corpses, contagion and collisions, so bodies alone
## strengthen a finished build instead of threatening it. A late wave is dangerous
## here because its recipe list contains Siege Pushes and Elite Spearheads and its
## budget can afford them, not because it places three Hunters where Wave 1 placed one.

const WAVE_COUNT := 20
const WAVE_DURATION_SECONDS := 60.0
const CAMPAIGN_DURATION_SECONDS := 1200.0
## Reinforcements stop here so the final quarter-minute is fought, not spawned into.
const FINAL_REINFORCEMENT_CUTOFF_SECONDS := 1185.0

## The four acts, and where each one ends.
##
## Not labelled heavily in the interface -- the wave card already says what the wave
## is -- but the enemy pool, the Canker rules and the recipe gating all read them, so
## the boundaries are real even where they are not announced.
enum Act {
	## Waves 1-5. Establish the build; basic enemies; nothing lethal yet.
	GERMINATION = 1,
	## Waves 6-10. First synergy, first specialists as ordinary members, first Canker.
	ENCROACHMENT = 2,
	## Waves 11-15. Complete the build; coordinated recipes; territory consequences.
	INFESTATION = 3,
	## Waves 16-20. Stress-test a finished build. Minimal filler, maximum composition.
	BLIGHT = 4,
}

const ACT_LAST_WAVES := [5, 10, 15, 20]
const ACT_NAMES := ["Germination", "Encroachment", "Infestation", "Blight"]

## Short names for the roles, so the authored table below reads as a table rather
## than as a column of fully qualified enum paths. These were hand-copied integers
## while the enum lived on `CombatDirector` and a model could not name a node; now
## that the vocabulary is a model itself, they are the enum, and the table can no
## longer drift from it.
const ROLE_HUNTER := EnemyKinds.Role.HUNTER
const ROLE_GRAZER := EnemyKinds.Role.GRAZER
const ROLE_ELITE := EnemyKinds.Role.ELITE
const ROLE_BOSS := EnemyKinds.Role.BOSS
const ROLE_SABOTEUR := EnemyKinds.Role.SABOTEUR
const ROLE_CORRUPTOR := EnemyKinds.Role.CORRUPTOR
const ROLE_COLONIZER := EnemyKinds.Role.COLONIZER
const ROLE_WARDEN := EnemyKinds.Role.WARDEN
const ROLE_COLONY_CORE := EnemyKinds.Role.COLONY_CORE
const ROLE_HEAVY_GRAZER := EnemyKinds.Role.HEAVY_GRAZER
const ROLE_RUSHER := EnemyKinds.Role.RUSHER
const ROLE_SIEGE_CORRUPTOR := EnemyKinds.Role.SIEGE_CORRUPTOR
const ROLE_HIVE_QUEEN := EnemyKinds.Role.HIVE_QUEEN

## The same, for the rule changes an elite can carry.
const MODIFIER_NONE := EnemyKinds.EliteModifier.NONE
const MODIFIER_UNSTOPPABLE := EnemyKinds.EliteModifier.UNSTOPPABLE
const MODIFIER_BLIGHTED := EnemyKinds.EliteModifier.BLIGHTED
const MODIFIER_RAVENOUS := EnemyKinds.EliteModifier.RAVENOUS
const MODIFIER_REGENERATIVE := EnemyKinds.EliteModifier.REGENERATIVE
const MODIFIER_DISRUPTIVE := EnemyKinds.EliteModifier.DISRUPTIVE
const MODIFIER_VOLATILE := EnemyKinds.EliteModifier.VOLATILE

## Wave-20 end multipliers. Wave 20 is the top of each smooth curve and applies no
## extra final-wave spike: the last wave is brutal because everything has matured
## together, not because a hidden multiplier lands on it.
##
## The endpoints are the twenty-five-wave Campaign's, reached across twenty waves
## instead. That is deliberate: the same total escalation over a shorter run is what
## makes the last quarter the hardest part of it rather than its longest plateau.
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
## lines. Resistance holds at nothing until Wave 8 -- Bramble and Fruit deserve most
## of the first two acts where their control is worth exactly what it says -- and
## then climbs unevenly. Modifier chance opens slowly, steps up at the Wave 10 Boss,
## and steps again entering Act IV, so the last third is fought against behaviour
## rather than against larger numbers.
##
## Plain Arrays rather than Packed ones because only a plain Array literal is a
## constant expression in GDScript; a Packed constructor is a call, and a call
## cannot initialise a const.
const CC_RESISTANCE_BY_WAVE := [
	0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00,
	0.02, 0.03, 0.05,
	0.06, 0.08, 0.09, 0.11, 0.12,
	0.14, 0.16, 0.18, 0.20, 0.20,
]
const MODIFIER_CHANCE_BY_WAVE := [
	0.00, 0.00, 0.00, 0.05, 0.07,
	0.10, 0.13, 0.16, 0.19, 0.22,
	0.26, 0.30, 0.34, 0.38, 0.42,
	0.48, 0.54, 0.60, 0.66, 0.75,
]

## Waves whose completion opens eight of the Campaign's eleven relic opportunities.
## The Elite, the Burrower and the Hive Queen are the other three. Deliberately not
## the milestone waves themselves: a relic arriving in the same breath as a boss's
## own reward reads as one reward rather than two.
const RELIC_WAVES := [2, 4, 7, 9, 12, 14, 17, 19]

## Waves that open an Evolution reward, if the run has an eligible Path relationship.
##
## Three opportunities for a target of roughly two Evolutions per run: one late in
## Act II when the first pairing can plausibly be developed, one in the middle of Act
## III, and one in Act IV for a run whose second relationship matured late. A run
## that qualifies for none of them simply does not evolve, which is what makes
## meeting the requirement worth building toward.
const EVOLUTION_REWARD_WAVES := [8, 14, 18]

## Waves that hand the player a new Adaptation draft.
##
## Path acquisition is authored rather than drawn. The measured pacing showed early
## upgrade ordering deciding whether a build functioned at all, and randomness is
## supposed to influence how a build develops rather than whether the player is
## allowed to have one. Wave 1 is the opening choice, Wave 3 is roughly two minutes
## in, Wave 5 closes Act I with the roster complete.
const PATH_GRANT_WAVES := [1, 3, 5]

## Waves that carry a Trial: one rule the player may follow for one wave, for a relic.
##
## One per act after Germination, and deliberately on waves that owe nothing else.
## Act I is left alone because a Trial is a constraint on how a build is played and
## the player does not have a build yet.
const TRIAL_WAVES := [6, 11, 16]

const ELITE_WAVE := 5
const ELITE_SPAWN_SECOND := 30.0
const BOSS_WAVE := 10
## Immediately after the wave's opening cue, which is its authored break.
const BOSS_SPAWN_SECOND := 2.5
## The Hive Queen, five waves after the Burrower and five before the end: the Act III
## checkpoint, fought by a build that should be close to complete.
const HIVE_QUEEN_WAVE := 15
const HIVE_QUEEN_SPAWN_SECOND := 3.0

## Wave at which the objective specialists join the modifier system.
const LATE_MODIFIER_ROLE_WAVE := 11

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

## Mixed into the run seed per wave so two runs shuffle their recipe draws
## differently while one run replays exactly.
const PRIME_WAVE_SEED := 7919

## Wave identity, opening break, threat budget, and the recipes the wave may buy.
## One row per wave, in the order the player meets them.
##
## The budget curve is the pacing dial. It roughly doubles across the run while the
## recipe lists move from two-Hunter probes to elite spearheads, so the same
## proportional increase buys a very different wave at each end -- which is the whole
## structural point: late pressure arrives as composition, not as population.
const AUTHORED_WAVES := [
	{
		"name": &"Garden Under Attack", "break": 0.0, "budget": 620.0,
		"topology": TOPOLOGY_EVEN_RING,
		"recipes": [EncounterRecipes.PROBE, EncounterRecipes.PAIR_PUSH],
	},
	{
		"name": &"Sabotage", "break": 4.0, "budget": 700.0,
		"topology": TOPOLOGY_EVEN_RING,
		"recipes": [
			EncounterRecipes.PROBE, EncounterRecipes.PAIR_PUSH,
			EncounterRecipes.SABOTAGE_RUN,
		],
	},
	{
		"name": &"Grazing", "break": 4.0, "budget": 790.0,
		"topology": TOPOLOGY_CLUSTERED_FRONT,
		"recipes": [
			EncounterRecipes.PAIR_PUSH, EncounterRecipes.GRAZE_LINE,
			EncounterRecipes.SABOTAGE_RUN,
		],
	},
	{
		"name": &"Mixed Opening", "break": 3.5, "budget": 880.0,
		"topology": TOPOLOGY_EVEN_RING,
		"recipes": [
			EncounterRecipes.PROBE, EncounterRecipes.PAIR_PUSH,
			EncounterRecipes.GRAZE_LINE, EncounterRecipes.SABOTAGE_RUN,
		],
	},
	{
		"name": &"Rootbreaker", "break": 3.5, "budget": 980.0,
		"topology": TOPOLOGY_CLUSTERED_FRONT,
		"recipes": [
			EncounterRecipes.PAIR_PUSH, EncounterRecipes.GRAZE_LINE,
			EncounterRecipes.SABOTAGE_RUN,
		],
	},
	{
		"name": &"Corruption", "break": 3.5, "budget": 1080.0,
		"topology": TOPOLOGY_SPECIALIST_OPPOSITE_PACK,
		"recipes": [
			EncounterRecipes.PAIR_PUSH, EncounterRecipes.GRAZE_LINE,
			EncounterRecipes.CORRUPTION_CELL, EncounterRecipes.SABOTAGE_RUN,
		],
	},
	{
		"name": &"Rush", "break": 3.0, "budget": 1180.0,
		"topology": TOPOLOGY_WEAK_SIDE_RUSH,
		"recipes": [
			EncounterRecipes.RUSH_ASSAULT, EncounterRecipes.PAIR_PUSH,
			EncounterRecipes.GRAZE_LINE, EncounterRecipes.SABOTAGE_RUN,
		],
	},
	{
		"name": &"Heavy Ground", "break": 3.0, "budget": 1290.0,
		"topology": TOPOLOGY_CLUSTERED_FRONT,
		"recipes": [
			EncounterRecipes.HEAVY_FRONT, EncounterRecipes.GRAZE_LINE,
			EncounterRecipes.CORRUPTION_CELL, EncounterRecipes.RUSH_ASSAULT,
		],
	},
	{
		"name": &"Colonization", "break": 3.0, "budget": 1400.0,
		"topology": TOPOLOGY_COLONIZER_DISTRACTION,
		"recipes": [
			EncounterRecipes.COLONY_PUSH, EncounterRecipes.CORRUPTION_CELL,
			EncounterRecipes.PAIR_PUSH, EncounterRecipes.CANKER_REINFORCEMENT,
		],
	},
	{
		"name": &"The Burrower", "break": 2.5, "budget": 1520.0,
		"topology": TOPOLOGY_TWO_SIDE_PINCER,
		"recipes": [
			EncounterRecipes.HEAVY_FRONT, EncounterRecipes.RUSH_ASSAULT,
			EncounterRecipes.CORRUPTION_CELL, EncounterRecipes.CANKER_REINFORCEMENT,
		],
	},
	{
		"name": &"Siege", "break": 2.5, "budget": 1650.0,
		"topology": TOPOLOGY_TWO_SIDE_PINCER,
		"recipes": [
			EncounterRecipes.SIEGE_PUSH, EncounterRecipes.HEAVY_FRONT,
			EncounterRecipes.CORRUPTION_CELL, EncounterRecipes.PAIR_PUSH,
		],
	},
	{
		"name": &"Split Front", "break": 2.5, "budget": 1780.0,
		"topology": TOPOLOGY_TWO_SIDE_PINCER,
		"recipes": [
			EncounterRecipes.SPLIT_PRESSURE, EncounterRecipes.RUSH_ASSAULT,
			EncounterRecipes.HEAVY_FRONT, EncounterRecipes.COLONY_PUSH,
		],
	},
	{
		"name": &"Warden Line", "break": 2.5, "budget": 1900.0,
		"topology": TOPOLOGY_SPECIALIST_OPPOSITE_PACK,
		"recipes": [
			EncounterRecipes.WARDEN_GUARD, EncounterRecipes.SIEGE_PUSH,
			EncounterRecipes.GRAZE_LINE, EncounterRecipes.CANKER_REINFORCEMENT,
		],
	},
	{
		"name": &"Infestation", "break": 2.0, "budget": 2030.0,
		"topology": TOPOLOGY_COLONIZER_DISTRACTION,
		"recipes": [
			EncounterRecipes.COLONY_PUSH, EncounterRecipes.SIEGE_PUSH,
			EncounterRecipes.WARDEN_GUARD, EncounterRecipes.SPLIT_PRESSURE,
			EncounterRecipes.CANKER_REINFORCEMENT,
		],
	},
	{
		"name": &"The Hive Queen", "break": 2.0, "budget": 2160.0,
		"topology": TOPOLOGY_THREE_FRONT_PRESSURE,
		"recipes": [
			EncounterRecipes.HEAVY_FRONT, EncounterRecipes.SPLIT_PRESSURE,
			EncounterRecipes.CORRUPTION_CELL, EncounterRecipes.RUSH_ASSAULT,
		],
	},
	{
		"name": &"Combined Arms", "break": 2.0, "budget": 2300.0,
		"topology": TOPOLOGY_THREE_FRONT_PRESSURE,
		"recipes": [
			EncounterRecipes.SIEGE_PUSH, EncounterRecipes.SPLIT_PRESSURE,
			EncounterRecipes.HEAVY_FRONT, EncounterRecipes.WARDEN_GUARD,
			EncounterRecipes.ELITE_SPEARHEAD,
		],
	},
	{
		"name": &"Breach", "break": 2.0, "budget": 2440.0,
		"topology": TOPOLOGY_WEAK_SIDE_RUSH,
		"recipes": [
			EncounterRecipes.ELITE_SPEARHEAD, EncounterRecipes.RUSH_ASSAULT,
			EncounterRecipes.SIEGE_PUSH, EncounterRecipes.SPLIT_PRESSURE,
		],
	},
	{
		"name": &"Colony War", "break": 1.5, "budget": 2580.0,
		"topology": TOPOLOGY_COLONIZER_DISTRACTION,
		"recipes": [
			EncounterRecipes.COLONY_PUSH, EncounterRecipes.WARDEN_GUARD,
			EncounterRecipes.SIEGE_PUSH, EncounterRecipes.CANKER_REINFORCEMENT,
			EncounterRecipes.ELITE_SPEARHEAD,
		],
	},
	{
		"name": &"Collapse", "break": 1.5, "budget": 2720.0,
		"topology": TOPOLOGY_THREE_FRONT_PRESSURE,
		"recipes": [
			EncounterRecipes.ELITE_SPEARHEAD, EncounterRecipes.SPLIT_PRESSURE,
			EncounterRecipes.HEAVY_FRONT, EncounterRecipes.SIEGE_PUSH,
			EncounterRecipes.WARDEN_GUARD,
		],
	},
	{
		"name": &"Final Invasion", "break": 1.25, "budget": 2900.0,
		"topology": TOPOLOGY_FINAL_ROTATION, "sustained": true,
		"recipes": [
			EncounterRecipes.ELITE_SPEARHEAD, EncounterRecipes.SPLIT_PRESSURE,
			EncounterRecipes.SIEGE_PUSH, EncounterRecipes.RUSH_ASSAULT,
			EncounterRecipes.HEAVY_FRONT, EncounterRecipes.CANKER_REINFORCEMENT,
		],
	},
]


static func get_wave_count() -> int:
	return WAVE_COUNT


static func get_act(wave_number: int) -> int:
	## Which quarter of the Campaign a wave belongs to. The recipe gate, the Canker
	## escalation and the enemy pool all read this rather than comparing wave numbers
	## in three places that could disagree.
	var wave := clampi(wave_number, 1, WAVE_COUNT)
	for index in range(ACT_LAST_WAVES.size()):
		if wave <= int(ACT_LAST_WAVES[index]):
			return index + 1
	return Act.BLIGHT


static func get_act_name(act: int) -> String:
	return ACT_NAMES[clampi(act, 1, ACT_NAMES.size()) - 1]


static func build_wave_specs() -> Array[CampaignWaveSpec]:
	## The whole Campaign, built once and handed to the director.
	var specs: Array[CampaignWaveSpec] = []
	for index in range(AUTHORED_WAVES.size()):
		specs.append(_build_wave_spec(index + 1, AUTHORED_WAVES[index]))
	return specs


static func _build_wave_spec(wave_number: int, authored: Dictionary) -> CampaignWaveSpec:
	var spec := CampaignWaveSpec.new()
	spec.wave_index = wave_number
	spec.act = get_act(wave_number)
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
	spec.threat_budget = float(authored["budget"])
	spec.recipe_ids = (authored["recipes"] as Array).duplicate()
	spec.spawn_topology = authored["topology"]
	spec.sustains_final_pressure = bool(authored.get("sustained", false))
	spec.modifier_pool_stage = get_modifier_pool_stage(wave_number)
	spec.elite_spawn_second = ELITE_SPAWN_SECOND if wave_number == ELITE_WAVE else -1.0
	spec.boss_spawn_second = BOSS_SPAWN_SECOND if wave_number == BOSS_WAVE else -1.0
	spec.hive_queen_spawn_second = (
		HIVE_QUEEN_SPAWN_SECOND if wave_number == HIVE_QUEEN_WAVE else -1.0
	)
	spec.grants_wave_relic = RELIC_WAVES.has(wave_number)
	spec.grants_evolution_reward = EVOLUTION_REWARD_WAVES.has(wave_number)
	spec.grants_path_draft = PATH_GRANT_WAVES.has(wave_number)
	spec.grants_trial = TRIAL_WAVES.has(wave_number)
	return spec


static func get_wave_progress(wave_number: int) -> float:
	## Position of a wave along every global curve, from 0 at Wave 1 to 1 at Wave 20.
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
	## Nothing before Wave 8, then a climb to 20% at Wave 19. Never an immunity:
	## every root, shove and slow still lands, shortened.
	return float(CC_RESISTANCE_BY_WAVE[clampi(wave_number, 1, WAVE_COUNT) - 1])


static func get_modifier_chance(wave_number: int) -> float:
	## Rule changes begin at Wave 4 and accelerate entering Act IV, so the last
	## quarter of the Campaign is fought against behaviour rather than only against
	## larger numbers.
	return float(MODIFIER_CHANCE_BY_WAVE[clampi(wave_number, 1, WAVE_COUNT) - 1])


static func get_modifier_pool_stage(wave_number: int) -> int:
	var wave := clampi(wave_number, 1, WAVE_COUNT)
	if wave <= 2:
		return 0
	if wave <= 5:
		return 1
	if wave <= 10:
		return 2
	if wave <= 15:
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


static func build_role_scaling_profiles() -> Dictionary:
	## Role id to EnemyRoleScalingProfile.
	##
	## Movement is the sensitive one. A Rusher that received the whole Wave 20
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
	# The Queen takes the Burrower's resistance and almost none of the movement
	# scaling: she is meant to hold a position and be reached, so a late-wave speed
	# multiplier on her would only make her harder to corner. Her action speed scales
	# like a Colonizer's, because that is the number that decides how fast the brood
	# comes back after it is cleared.
	var hive_queen := _role_profile(ROLE_HIVE_QUEEN, 0.15, 0.75)
	hive_queen.role_cc_resistance = 0.35
	profiles[ROLE_HIVE_QUEEN] = hive_queen
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


static func is_specialist_role(role: int) -> bool:
	## A role whose presence changes what a pack is about rather than how large it
	## is. The perimeter topology reads this to decide where a pack enters from.
	return role in [
		ROLE_SABOTEUR, ROLE_CORRUPTOR, ROLE_SIEGE_CORRUPTOR,
		ROLE_COLONIZER, ROLE_WARDEN,
	]
