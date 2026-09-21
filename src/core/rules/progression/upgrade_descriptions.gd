class_name UpgradeDescriptions
extends RefCounted

## Every line of text the interface prints about an upgrade: its two-letter slot
## abbreviation, its hover, the finished numbers a rank resolves to right now, and
## what the Root Network makes of them.
##
## This is scene-independent by design but not pure: the whole point of "resolved"
## is that the numbers are read from the same getters the systems themselves use,
## so a hover can never drift from what the run is actually doing. What it must
## never do is *change* any of them - every method here is a read.
##
## It lives outside the node tree so that both the run root and the Adaptation tree
## can hold one without either reaching through the other. Construct it once, after
## the components exist, and hand it to whatever needs to describe an upgrade.

var _progression: Progression
var _evolutions: Evolutions
var _combat: CombatDirector
var _spore_director: SporeDirector
var _bloom_director: BloomDirector
var _bramble_director: BrambleDirector
var _root_director: RootDirector
var _pruning_director: PruningDirector
var _adaptation_director: AdaptationDirector
var _territory_field: TerritoryField
## The authored wording for the Root Network row. It stays an Inspector export on
## the run root - the scene is the design surface - and is handed over from there,
## so this module formats it but never owns it.
var _root_potency_note_template: String


func _init(
	progression: Progression,
	evolutions: Evolutions,
	combat: CombatDirector,
	spore_director: SporeDirector,
	bloom_director: BloomDirector,
	bramble_director: BrambleDirector,
	root_director: RootDirector,
	pruning_director: PruningDirector,
	adaptation_director: AdaptationDirector,
	territory_field: TerritoryField,
	root_potency_note_template: String,
) -> void:
	_progression = progression
	_evolutions = evolutions
	_combat = combat
	_spore_director = spore_director
	_bloom_director = bloom_director
	_bramble_director = bramble_director
	_root_director = root_director
	_pruning_director = pruning_director
	_adaptation_director = adaptation_director
	_territory_field = territory_field
	_root_potency_note_template = root_potency_note_template


static func initials(source: String) -> String:
	# Two letters taken from an authored name, so a slot reads at a glance and
	# never needs a second name kept in sync with it.
	var words := source.split(" ", false)
	if words.size() >= 2:
		return (words[0].substr(0, 1) + words[1].substr(0, 1)).to_upper()
	if words.size() == 1:
		return words[0].substr(0, 2).to_upper()
	return "--"


func abbreviation(upgrade_id: int) -> String:
	return initials(Progression.get_upgrade_name(upgrade_id))


func tooltip(upgrade_id: int) -> String:
	# What the line is, what one more rank buys, and what the run's numbers
	# actually resolve to right now.
	var level := _progression.get_owned_upgrade_level(upgrade_id)
	var maximum := _progression.get_upgrade_maximum_level(upgrade_id)
	var lines := PackedStringArray()
	lines.append("%s   %d/%d" % [
		Progression.get_upgrade_name(upgrade_id),
		level,
		maximum,
	])
	# An Evolution line's ranks each do something different, so the hover carries
	# every rank the run has bought rather than one averaged line. This is the only
	# place the player can read the finished build back, and it is empty for the
	# ordinary lines, whose ranks are all the same thing again.
	var owned := _evolution_owned_ranks(upgrade_id)
	for owned_rank in owned:
		lines.append(owned_rank)
	var per_rank := _progression.get_upgrade_description(upgrade_id)
	if not per_rank.is_empty():
		var rank_label := "Next rank" if level < maximum else "Maxed"
		lines.append("%s: %s" % [rank_label, per_rank])
	if owned.is_empty():
		# For an Evolution line the last owned rank above already says this, and the
		# hover should not print it twice.
		var resolved := resolved_effect(upgrade_id)
		if not resolved.is_empty():
			lines.append("Now: %s" % resolved)
	# The Root Network row sits under the base number rather than replacing it, so
	# the hover shows what the line is worth on its own and what Mature ground turns
	# that into, in that order.
	var rooted := root_potency_note(upgrade_id)
	if not rooted.is_empty():
		lines.append(rooted)
	return "\n".join(lines)


func _evolution_owned_ranks(upgrade_id: int) -> PackedStringArray:
	# Every Evolution rank the run has actually bought, in the order it bought them.
	# Owned rather than effective level: a Clover jackpot lends a Path its ceiling for
	# a few seconds, and the hover must not claim the run holds ranks it never took.
	var owned := PackedStringArray()
	if Evolutions.get_upgrade_evolution(upgrade_id) == Progression.EvolutionId.NONE:
		return owned
	var level := _progression.get_owned_upgrade_level(upgrade_id)
	for rank in range(1, level + 1):
		var description := _evolutions.get_evolution_upgrade_rank_description(upgrade_id, rank)
		if description.is_empty():
			continue
		owned.append("%d. %s" % [rank, description])
	return owned


func resolved_effect(upgrade_id: int) -> String:
	# The finished numbers, read from the same values the systems use, so the hover
	# text can never drift from what the run is actually doing.
	match upgrade_id:
		Progression.UpgradeId.SEED_PRODUCTION:
			return "%d kills per Seed" % _spore_director.get_seed_kill_threshold()
		Progression.UpgradeId.GROWTH_MASS:
			return "%d%% Seed growth mass" % roundi(
				_spore_director.get_seed_mass_multiplier() * 100.0
			)
		Progression.UpgradeId.SPORULATION:
			var spore_rate := (
				_combat.sporulation_per_second
				* _spore_director.get_sporulation_rate_multiplier()
			)
			return "%.2f%% Spore per second, Overgrown after %.0fs on Green" % [
				spore_rate * 100.0,
				1.0 / maxf(0.0001, spore_rate),
			]
		Progression.UpgradeId.FRUITING_BODIES:
			return "%d%% of germinations inside your Green raise a colony" % roundi(
				_spore_director.get_fruiting_body_chance() * 100.0
			)
		Progression.UpgradeId.BLOOM_FORCE:
			return "%d%% Bloom force, %.0f Bloom damage" % [
				roundi(_bloom_director.get_bloom_force_multiplier() * 100.0),
				_bloom_director.bloom_damage * _bloom_director.get_bloom_force_multiplier(),
			]
		Progression.UpgradeId.BLOOM_FREQUENCY:
			return "a Bloom every %.1fs" % (
				_bloom_director.bloom_interval_seconds
				* _bloom_director.get_bloom_interval_multiplier()
			)
		Progression.UpgradeId.AFTERGROWTH:
			return "%d temporary control on Bloomed Green for %.0fs" % [
				roundi(_bloom_director.get_aftergrowth_shield()),
				_bloom_director.bloom_tempo_window_seconds,
			]
		Progression.UpgradeId.SUPPRESSION:
			return "%d%% less Territory damage for %.0fs after a Bloom" % [
				roundi(_bloom_director.get_suppression_share() * 100.0),
				_bloom_director.bloom_tempo_window_seconds,
			]
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT:
			return "up to %d%% slow when fully Entangled" % roundi(
				_bramble_director.get_slow_fraction() * 100.0
			)
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT_RATE:
			var rate := (
				_combat.bramble_entanglement_per_second
				* _bramble_director.get_entanglement_rate_multiplier()
			)
			return "fully Entangled after %.1fs on Green" % (1.0 / maxf(0.01, rate))
		Progression.UpgradeId.BRAMBLE_GRASPING_THORNS:
			return "%.2fs Ensnare, then %.0fs immune" % [
				_bramble_director.get_ensnare_seconds(),
				_bramble_director.get_ensnare_immunity_seconds(),
			]
		Progression.UpgradeId.BRAMBLE_REPULSION:
			return "%.0f px knockback on territory attackers" % (
				_bramble_director.get_repulsion_pixels()
			)
		Progression.UpgradeId.ROOT_MATURATION:
			return "%d%% maturation rate" % roundi(
				_root_director.get_maturation_multiplier() * 100.0
			)
		Progression.UpgradeId.ROOT_LATERAL_ROOTS:
			return "+%d px projected Root reach" % roundi(
				_root_director.get_lateral_reach()
			)
		Progression.UpgradeId.ROOT_MATURE_STRENGTH:
			return "%.2fx Mature resistance, +%.3f control per second" % [
				_root_director.get_mature_resistance_multiplier(),
				_root_director.get_regeneration_per_second(),
			]
		Progression.UpgradeId.ROOT_POTENCY:
			return "+%d%% from fully Mature ground" % roundi(
				_root_director.get_network_bonus() * 100.0
			)
		Progression.UpgradeId.PRUNING_HARVEST_RATE:
			return "%.1f cells per second held, %.1f at full Charge" % [
				_pruning_director.upkeep_cells_per_second
				* _pruning_director.get_pruning_harvest_rate_multiplier(),
				_pruning_director.upkeep_cells_per_second_at_charge
				* _pruning_director.get_pruning_harvest_rate_multiplier(),
			]
		Progression.UpgradeId.PRUNING_CUTTING_YIELD:
			return "%.2f Cuttings per cell harvested" % (
				_pruning_director.cuttings_per_cell
				* _pruning_director.get_pruning_cutting_yield_multiplier()
			)
		Progression.UpgradeId.PRUNING_CUTTING_DAMAGE:
			# The thicket's own bite is printed beside the line but not multiplied by
			# it: this line buys launched Cuttings, and the ring is deliberately
			# outside it. Showing both keeps the card honest about which half moves.
			return "%.0f per launched Cutting; the thicket bites for %.0f" % [
				_pruning_director.cutting_damage
				* _pruning_director.get_pruning_cutting_damage_multiplier(),
				_pruning_director.orbit_contact_damage,
			]
		Progression.UpgradeId.PRUNING_CHARGE:
			# Read from the exports rather than through get_charge_seconds, which now
			# folds in the Root Network where Grandma is standing. This is the plain
			# row; the Network's contribution is reported on its own row beneath it.
			return "full Charge in %.1fs, +%d%% launch damage" % [
				_pruning_director.charge_seconds / maxf(
					0.05, _pruning_director.get_pruning_charge_multiplier()
				),
				roundi(
					_pruning_director.launch_charge_damage_bonus
					* _pruning_director.get_pruning_charge_multiplier()
					* 100.0
				),
			]
		Progression.UpgradeId.THISTLE_CLUSTERING:
			return "%d thorns per normal turret firing event" % (
				1 + _progression.get_upgrade_level(upgrade_id)
			)
		Progression.UpgradeId.THISTLE_DEHISCENCE:
			var thistle_speed := 1.0 + 0.15 * float(_progression.get_upgrade_level(upgrade_id))
			return "one turret firing event every %.3fs" % (
				_adaptation_director.thistle_attack_interval / thistle_speed
			)
		Progression.UpgradeId.THISTLE_BURR:
			return "%d full-damage ricochets per thorn" % (
				_progression.get_upgrade_level(upgrade_id)
			)
		Progression.UpgradeId.THISTLE_NEEDLEPOINT:
			return "%d%% critical chance per impact at %sx damage" % [
				roundi(100.0 * _adaptation_director.thistle_base_critical_chance),
				_format_multiplier(
					_adaptation_director.thistle_critical_multiplier
					+ _adaptation_director.thistle_needlepoint_critical_damage_per_rank
					* float(_progression.get_upgrade_level(upgrade_id))
				),
			]
		Progression.UpgradeId.VINE_ELONGATION:
			# From the export rather than through get_cane_reach, which already folds
			# in the Root Network where Grandma is standing. This is the plain row;
			# the Network's contribution is reported on its own row beneath it.
			return "%.0f px Vine reach" % (
				_combat.cane_reach_pixels
				* (1.0 + 0.20 * float(_progression.get_upgrade_level(upgrade_id)))
			)
		Progression.UpgradeId.VINE_LIGNIFICATION:
			return "%.1f damage before Apical, Root, and relic modifiers" % (
				_combat.cane_damage
				* (1.0 + 0.25 * float(_progression.get_upgrade_level(upgrade_id)))
			)
		Progression.UpgradeId.VINE_TURGOR:
			var vine_speed := 1.0 + 0.15 * float(_progression.get_upgrade_level(upgrade_id))
			return "one automatic sweep every %.3fs before relic timing" % (
				_combat.cane_cooldown_seconds / vine_speed
			)
		Progression.UpgradeId.VINE_APICAL_DOMINANCE:
			return "%.2fx damage in the outer 25%% of reach" % (
				1.0 + 0.25 * float(_progression.get_upgrade_level(upgrade_id))
			)
		Progression.UpgradeId.FRUIT_SET:
			return "%d Fruit per normal release" % (
				1 + _progression.get_upgrade_level(upgrade_id)
			)
		Progression.UpgradeId.FRUIT_RIPENING:
			var ripening := 1.0 + 0.25 * float(_progression.get_upgrade_level(upgrade_id))
			return "%.1f collision damage, up to %.1f terminal damage" % [
				_adaptation_director.fruit_collision_damage * ripening,
				_adaptation_director.fruit_terminal_explosion_damage * ripening,
			]
		Progression.UpgradeId.FRUIT_MOMENTUM:
			return "%.0f px unobstructed stopping distance" % (
				_adaptation_director.fruit_roll_distance_pixels
				* (1.0 + 0.20 * float(_progression.get_upgrade_level(upgrade_id)))
			)
		Progression.UpgradeId.FRUIT_GERMINATION:
			return "%d%% Fruit-created Green area" % roundi(
				(1.0 + 0.20 * float(_progression.get_upgrade_level(upgrade_id))) * 100.0
			)
	if Evolutions.get_upgrade_evolution(upgrade_id) != Progression.EvolutionId.NONE:
		# An Evolution line's ranks each do something different, so what it is doing
		# now is the description of the rank the run has actually reached.
		var evolution_level := _progression.get_upgrade_level(upgrade_id)
		if evolution_level <= 0:
			return ""
		return _evolutions.get_evolution_upgrade_rank_description(
			upgrade_id,
			evolution_level
		)
	return ""


func root_potency_note(upgrade_id: int) -> String:
	# The finished Root Network row for a line, or nothing at all. A run without Root
	# and every line the Network does not touch return empty, so the row appears only
	# where it is true rather than as a permanent piece of furniture.
	var effect := _root_potency_effect(upgrade_id)
	if effect.is_empty():
		return ""
	return AuthoredText.render(_root_potency_note_template, {
		"multiplier": "%.2f" % (1.0 + _root_director.get_network_bonus()),
		"effect": effect,
	})


func _rooted_line_bonus(upgrade_id: int, per_rank: float, multiplier: float) -> float:
	# One line's own per-rank bonus out of fully Mature ground. Thistle, Vine, and
	# Fruit take Root Potency on the bonus they bought rather than on the authored
	# base, so this is the same expression the Adaptation applies and the ROOTED row
	# stays honest as the line ranks up.
	return per_rank * float(_progression.get_upgrade_level(upgrade_id)) * multiplier


func _has_started_line(upgrade_id: int) -> bool:
	# Root deepens a line the build has started. An unbought line has no Network row,
	# and a Clover jackpot lending a Path its ceiling does not create one either.
	return _progression.get_owned_upgrade_level(upgrade_id) > 0


func _root_potency_effect(upgrade_id: int) -> String:
	# What this line resolves to on fully Mature ground, read through the same
	# amplification the systems apply. Full maturity is the honest headline: it is
	# the ceiling the Network reaches, and every consumer scales down from it with
	# the age of the ground the effect actually happens on. Every row names the
	# line's own number -- its reach, its cadence, its count, its hold -- rather than
	# reporting a damage figure the line was never about.
	if _root_director == null:
		return ""
	var bonus := _root_director.get_network_bonus()
	if bonus <= 0.0:
		return ""
	var multiplier := 1.0 + bonus
	match upgrade_id:
		Progression.UpgradeId.SEED_PRODUCTION:
			return "Seeds germinate in %.2fs instead of %.2fs" % [
				_territory_field.tuning.seed_charge_seconds / multiplier,
				_territory_field.tuning.seed_charge_seconds,
			]
		Progression.UpgradeId.GROWTH_MASS:
			return "%d%% Seed growth mass" % roundi(
				_spore_director.get_seed_mass_multiplier() * multiplier * 100.0
			)
		Progression.UpgradeId.SPORULATION:
			var rooted_spore := (
				_combat.sporulation_per_second
				* _spore_director.get_sporulation_rate_multiplier()
				* multiplier
			)
			return "%.2f%% Spore per second, Overgrown after %.0fs" % [
				rooted_spore * 100.0,
				1.0 / maxf(0.0001, rooted_spore),
			]
		Progression.UpgradeId.FRUITING_BODIES:
			return "colonies apply %d%% Spore per cloud, %d%% on rupture" % [
				roundi(_combat.fruiting_body_cloud_spore * multiplier * 100.0),
				roundi(_combat.fruiting_body_rupture_spore * multiplier * 100.0),
			]
		Progression.UpgradeId.BLOOM_FORCE:
			return "%d%% Bloom force, %.0f Bloom damage" % [
				roundi(_bloom_director.get_bloom_force_multiplier() * multiplier * 100.0),
				_bloom_director.bloom_damage
				* _bloom_director.get_bloom_force_multiplier()
				* multiplier,
			]
		Progression.UpgradeId.BLOOM_FREQUENCY:
			return "a Bloom every %.1fs" % (
				_bloom_director.bloom_interval_seconds
				* _bloom_director.get_bloom_interval_multiplier()
				/ multiplier
			)
		Progression.UpgradeId.AFTERGROWTH:
			return "%d temporary control on Bloomed Green for %.0fs" % [
				roundi(_bloom_director.get_aftergrowth_shield() * multiplier),
				_bloom_director.bloom_tempo_window_seconds,
			]
		Progression.UpgradeId.SUPPRESSION:
			return "%d%% less Territory damage for %.0fs after a Bloom" % [
				roundi(
					clampf(_bloom_director.get_suppression_share() * multiplier, 0.0, 0.95)
					* 100.0
				),
				_bloom_director.bloom_tempo_window_seconds,
			]
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT:
			return "up to %d%% slow when fully Entangled" % roundi(
				clampf(_bramble_director.get_slow_fraction() * multiplier, 0.0, 0.85)
				* 100.0
			)
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT_RATE:
			var rate := (
				_combat.bramble_entanglement_per_second
				* _bramble_director.get_entanglement_rate_multiplier()
				* multiplier
			)
			return "fully Entangled after %.1fs on Green" % (1.0 / maxf(0.01, rate))
		Progression.UpgradeId.BRAMBLE_GRASPING_THORNS:
			return "%.2fs Ensnare, then %.0fs immune" % [
				_bramble_director.get_ensnare_seconds() * multiplier,
				_bramble_director.get_ensnare_immunity_seconds(),
			]
		Progression.UpgradeId.BRAMBLE_REPULSION:
			return "%.0f px knockback on territory attackers" % (
				_bramble_director.get_repulsion_pixels() * multiplier
			)
		Progression.UpgradeId.PRUNING_CUTTING_DAMAGE:
			return "%.0f per launched Cutting" % (
				_pruning_director.cutting_damage
					* _pruning_director.get_pruning_cutting_damage_multiplier()
					* multiplier
			)
		Progression.UpgradeId.PRUNING_HARVEST_RATE:
			return "%.1f cells per second held, and the spikes to match" % (
				_pruning_director.upkeep_cells_per_second
				* _pruning_director.get_pruning_harvest_rate_multiplier()
				* multiplier
			)
		Progression.UpgradeId.PRUNING_CUTTING_YIELD:
			return "%.2f Cuttings per cell harvested" % (
				_pruning_director.cuttings_per_cell
				* _pruning_director.get_pruning_cutting_yield_multiplier()
				* multiplier
			)
		Progression.UpgradeId.PRUNING_CHARGE:
			return "full Charge in %.1fs, +%d%% launch damage" % [
				_pruning_director.charge_seconds / maxf(
					0.05,
					_pruning_director.get_pruning_charge_multiplier() * multiplier
				),
				roundi(
					_pruning_director.launch_charge_damage_bonus
					* _pruning_director.get_pruning_charge_multiplier()
					* multiplier
					* 100.0
				),
			]
		Progression.UpgradeId.ROOT_POTENCY:
			return (
				"Spore, Bloom, Bramble, Cuttings, thorns, Vine, and Fruit "
				+ "out of Mature ground"
			)
	# Everything below is a Thistle, Vine, or Fruit line. Those paths take Potency one
	# line at a time, on the bonus that line bought, and only once the build has
	# actually started the line.
	if not _has_started_line(upgrade_id):
		return ""
	match upgrade_id:
		Progression.UpgradeId.THISTLE_CLUSTERING:
			return "%d thorns per firing event out of Mature ground" % (
				2 + _progression.get_upgrade_level(upgrade_id)
			)
		Progression.UpgradeId.THISTLE_DEHISCENCE:
			return "one firing event every %.3fs" % (
				_adaptation_director.thistle_attack_interval / maxf(
					0.05,
					1.0 + _rooted_line_bonus(upgrade_id, 0.15, multiplier)
				)
			)
		Progression.UpgradeId.THISTLE_BURR:
			return "%d full-damage ricochets per thorn out of Mature ground" % (
				1 + _progression.get_upgrade_level(upgrade_id)
			)
		Progression.UpgradeId.THISTLE_NEEDLEPOINT:
			return "%d%% critical chance per impact at %sx damage" % [
				roundi(100.0 * _adaptation_director.thistle_base_critical_chance),
				_format_multiplier(
					_adaptation_director.thistle_critical_multiplier
					+ _rooted_line_bonus(
						upgrade_id,
						_adaptation_director.thistle_needlepoint_critical_damage_per_rank,
						multiplier
					)
				),
			]
		Progression.UpgradeId.VINE_ELONGATION:
			return "%.0f px Vine reach" % (
				_combat.cane_reach_pixels
				* (1.0 + _rooted_line_bonus(upgrade_id, 0.20, multiplier))
			)
		Progression.UpgradeId.VINE_LIGNIFICATION:
			return "%.1f Vine damage before Apical and relic modifiers" % (
				_combat.cane_damage
				* (1.0 + _rooted_line_bonus(upgrade_id, 0.25, multiplier))
			)
		Progression.UpgradeId.VINE_TURGOR:
			return "one automatic sweep every %.3fs before relic timing" % (
				_combat.cane_cooldown_seconds
				/ maxf(0.05, 1.0 + _rooted_line_bonus(upgrade_id, 0.15, multiplier))
			)
		Progression.UpgradeId.VINE_APICAL_DOMINANCE:
			return "%.2fx damage in the outer 25%% of reach" % (
				1.0 + _rooted_line_bonus(upgrade_id, 0.25, multiplier)
			)
		Progression.UpgradeId.FRUIT_SET:
			return "%d Fruit per release out of Mature ground" % (
				2 + _progression.get_upgrade_level(upgrade_id)
			)
		Progression.UpgradeId.FRUIT_RIPENING:
			var rooted_ripening := 1.0 + _rooted_line_bonus(upgrade_id, 0.25, multiplier)
			return "%.1f collision damage, up to %.1f terminal damage" % [
				_adaptation_director.fruit_collision_damage * rooted_ripening,
				_adaptation_director.fruit_terminal_explosion_damage * rooted_ripening,
			]
		Progression.UpgradeId.FRUIT_MOMENTUM:
			return "%.0f px unobstructed stopping distance" % (
				_adaptation_director.fruit_roll_distance_pixels
				* (1.0 + _rooted_line_bonus(upgrade_id, 0.20, multiplier))
			)
		Progression.UpgradeId.FRUIT_GERMINATION:
			return "%d%% Fruit-created Green area" % roundi(
				(1.0 + _rooted_line_bonus(upgrade_id, 0.20, multiplier)) * 100.0
			)
	return ""


static func _format_multiplier(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return "%d" % int(round(value))
	return "%.2f" % value

## The player-facing name of one upgrade line.
static func get_upgrade_name(upgrade_id: int) -> String:
	match upgrade_id:
		Progression.UpgradeId.SEED_PRODUCTION:
			return "Seed Production"
		Progression.UpgradeId.GROWTH_MASS:
			return "Growth Mass"
		Progression.UpgradeId.SPORULATION:
			return "Sporulation"
		Progression.UpgradeId.FRUITING_BODIES:
			return "Fruiting Bodies"
		Progression.UpgradeId.BLOOM_FORCE:
			return "Bloom Force"
		Progression.UpgradeId.BLOOM_FREQUENCY:
			return "Bloom Frequency"
		Progression.UpgradeId.AFTERGROWTH:
			return "Aftergrowth"
		Progression.UpgradeId.SUPPRESSION:
			return "Suppression"
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT:
			return "Entanglement"
		Progression.UpgradeId.BRAMBLE_ENTANGLEMENT_RATE:
			return "Entanglement Rate"
		Progression.UpgradeId.BRAMBLE_GRASPING_THORNS:
			return "Grasping Thorns"
		Progression.UpgradeId.BRAMBLE_REPULSION:
			return "Repulsion"
		Progression.UpgradeId.ROOT_MATURATION:
			return "Maturation Speed"
		Progression.UpgradeId.ROOT_LATERAL_ROOTS:
			return "Lateral Roots"
		Progression.UpgradeId.ROOT_MATURE_STRENGTH:
			return "Mature Strength"
		Progression.UpgradeId.ROOT_POTENCY:
			return "Root Potency"
		Progression.UpgradeId.PRUNING_HARVEST_RATE:
			return "Harvest Rate"
		Progression.UpgradeId.PRUNING_CUTTING_YIELD:
			return "Cutting Yield"
		Progression.UpgradeId.PRUNING_CUTTING_DAMAGE:
			return "Cutting Edge"
		Progression.UpgradeId.PRUNING_CHARGE:
			return "Charge"
		Progression.UpgradeId.THISTLE_CLUSTERING:
			return "Clustering"
		Progression.UpgradeId.THISTLE_DEHISCENCE:
			return "Dehiscence"
		Progression.UpgradeId.THISTLE_BURR:
			return "Burr"
		Progression.UpgradeId.THISTLE_NEEDLEPOINT:
			return "Needlepoint"
		Progression.UpgradeId.VINE_ELONGATION:
			return "Elongation"
		Progression.UpgradeId.VINE_LIGNIFICATION:
			return "Lignification"
		Progression.UpgradeId.VINE_TURGOR:
			return "Turgor"
		Progression.UpgradeId.VINE_APICAL_DOMINANCE:
			return "Apical Dominance"
		Progression.UpgradeId.FRUIT_SET:
			return "Fruit Set"
		Progression.UpgradeId.FRUIT_RIPENING:
			return "Ripening"
		Progression.UpgradeId.FRUIT_MOMENTUM:
			return "Momentum"
		Progression.UpgradeId.FRUIT_GERMINATION:
			return "Germination"
		Progression.UpgradeId.EVOLUTION_FLORAL_CASCADE:
			return "Floral Cascade"
		Progression.UpgradeId.EVOLUTION_TANGLEBURST:
			return "Tangleburst"
		Progression.UpgradeId.EVOLUTION_SEED_RESERVE:
			return "Seed Reserve"
		Progression.UpgradeId.EVOLUTION_BRIAR_PAYLOAD:
			return "Briar Payload"
		Progression.UpgradeId.EVOLUTION_SEASONAL_SURGE:
			return "Seasonal Surge"
		Progression.UpgradeId.EVOLUTION_ANCIENT_FURY:
			return "Ancient Fury"
		Progression.UpgradeId.EVOLUTION_SECOND_FLUSH:
			return "Second Flush"
		Progression.UpgradeId.EVOLUTION_COMPRESSION:
			return "Compression"
		Progression.UpgradeId.EVOLUTION_SPLINTERSTORM:
			return "Splinterstorm"
		Progression.UpgradeId.EVOLUTION_STOOL_REGROWTH:
			return "Stool Regrowth"
		Progression.UpgradeId.EVOLUTION_INOCULATOR:
			return "Inoculator"
		Progression.UpgradeId.EVOLUTION_BURSTBLOOM:
			return "Burstbloom"
		Progression.UpgradeId.EVOLUTION_HEDGE_BATTERY:
			return "Hedge Battery"
		Progression.UpgradeId.EVOLUTION_ROOTSTOCK:
			return "Rootstock"
		Progression.UpgradeId.EVOLUTION_DEADHEADING:
			return "Deadheading"
		Progression.UpgradeId.EVOLUTION_THORNWHIP:
			return "Thornwhip"
		Progression.UpgradeId.EVOLUTION_BURDOCK:
			return "Burdock"
		Progression.UpgradeId.EVOLUTION_MYCELIAL_VINE:
			return "Mycelial Vine"
		Progression.UpgradeId.EVOLUTION_WISTERIA:
			return "Wisteria"
		Progression.UpgradeId.EVOLUTION_BRIAR_CANE:
			return "Briar Cane"
		Progression.UpgradeId.EVOLUTION_HEARTWOOD:
			return "Heartwood"
		Progression.UpgradeId.EVOLUTION_ESPALIER:
			return "Espalier"
		Progression.UpgradeId.EVOLUTION_GOURDVINE:
			return "Gourdvine"
		Progression.UpgradeId.EVOLUTION_ROT:
			return "Rot"
		Progression.UpgradeId.EVOLUTION_OVERRIPE:
			return "Overripe"
		Progression.UpgradeId.EVOLUTION_DURIAN:
			return "Durian"
		Progression.UpgradeId.EVOLUTION_ORCHARD:
			return "Orchard"
		Progression.UpgradeId.EVOLUTION_GRAFT:
			return "Graft"
	return "Unknown Upgrade"


## The player-facing name of one Path.
static func get_path_name(path_id: int) -> String:
	match path_id:
		Progression.PathId.SPORE:
			return "Spore"
		Progression.PathId.BLOOM:
			return "Bloom"
		Progression.PathId.BRAMBLE:
			return "Bramble"
		Progression.PathId.ROOT:
			return "Root"
		Progression.PathId.PRUNING:
			return "Pruning"
		Progression.PathId.THISTLE:
			return "Thistle"
		Progression.PathId.VINE:
			return "Vine"
		Progression.PathId.FRUIT:
			return "Fruit"
	return "Unchosen"
