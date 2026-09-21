## The run clock's milestones and what each one owes: the wave cadence that pays a
## relic, the elite and Burrower arrivals, the final invasion, and the Evolution
## pairing the draft has to offer once a run has earned it.
##
## The relic fixtures above spend the pool, so the blocks that expect a relic reward
## restock it first - an exhausted pool pays a Compost Cache and never opens the
## panel this is about.
class_name SmokeMilestones
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	# Relic rewards are on a wave schedule as well as on the elite and the boss.
	# A crossing owes the run a relic only on the authored cycle, and the debt is
	# paid out by the run loop once no other choice holds the panel.
	var relic_cycle := prototype.relic_reward_wave_cycle
	prototype._owed_wave_relics = 0
	# A panel held open, so the debt is observed rather than immediately settled:
	# what is being checked is which crossings owe a relic, not how fast the run
	# loop pays one out.
	var held_choice_kind := prototype._choice_kind
	prototype._choice_kind = RunRoot.ChoiceKind.RELIC
	prototype._on_wave_began(relic_cycle + 1)
	var off_cycle_owed := prototype._owed_wave_relics
	prototype._on_wave_began(relic_cycle * 2)
	var on_cycle_owed := prototype._owed_wave_relics
	prototype._choice_kind = held_choice_kind
	prototype._owed_wave_relics = 0
	report.check(
		relic_cycle > 0 and off_cycle_owed == 0 and on_cycle_owed == 1,
		"every %dth wave owes the run a relic reward and the waves between owe none"
		% relic_cycle
	)
	report.check(
		prototype.wave_director.announced_wave_number
		== prototype.wave_director.get_current_wave_number(),
		"the wave director has announced every wave the run clock has crossed"
	)

	prototype.progression.debug_complete_evolution_requirements()
	report.check(
		prototype.progression.evolution_status == Progression.EvolutionStatus.READY,
		"investing five ranks in each of Spore and Bloom marks an Evolution eligible"
	)
	# An Evolution is a reward of its own now, not a card inside a level-up. An
	# ordinary draft must never contain one, however ready the run is.
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	var ordinary_draft := prototype.progression.get_pending_upgrade_options()
	var draft_carries_evolution := false
	for option_id in ordinary_draft:
		if prototype.progression.is_evolution_upgrade(option_id):
			draft_carries_evolution = true
	report.check(
		ordinary_draft.size() == 3 and not draft_carries_evolution,
		"a level-up offers three upgrade lines and never the Evolution itself"
	)
	prototype._choose_displayed_option(0)
	var evolution_opened := prototype.progression.request_evolution_choice()
	var evolution_options := prototype.progression.get_pending_evolution_options()
	var evolution_button_text := ""
	if not evolution_options.is_empty():
		evolution_button_text = prototype.choice_panel.buttons[0].text
	report.check(
		evolution_opened
		and evolution_options.has(Progression.EvolutionId.SUPER_BLOOM)
		and prototype.choice_panel.header.text == "EVOLUTION"
		and evolution_button_text.contains("SUPER BLOOM"),
		"an Evolution reward offers the relationships the build has actually developed"
	)
	prototype._choose_displayed_option(
		evolution_options.find(Progression.EvolutionId.SUPER_BLOOM)
	)
	report.check(
		prototype.progression.evolution_status == Progression.EvolutionStatus.EVOLVED
		and prototype.progression.active_evolution
		== Progression.EvolutionId.SUPER_BLOOM
		and prototype.progression.get_evolution_rank(
			Progression.EvolutionId.SUPER_BLOOM
		) == 1,
		"choosing the pairing grants Super Bloom and its rank-1 line immediately"
	)

	# An Evolution line's hover has to grow with the line. Every rank does something
	# different, so a single "now" line threw away most of what the run had bought:
	# the hover is the only place the finished build can be read back.
	var evolution_upgrade_id := Evolutions.get_evolution_upgrade_id(
		Progression.EvolutionId.SUPER_BLOOM
	)
	prototype._update_hud()
	var hover_rank_one_tooltip := prototype.adaptation_tree.evolution_slot.get_slot_tooltip(0)
	prototype.progression._upgrade_levels[evolution_upgrade_id] = 3
	prototype._apply_progression_modifiers()
	prototype._update_hud()
	var hover_rank_three_tooltip := prototype.adaptation_tree.evolution_slot.get_slot_tooltip(0)
	var hover_rank_one_text := prototype.evolutions.get_evolution_upgrade_rank_description(
		evolution_upgrade_id,
		1
	)
	var hover_rank_three_text := prototype.evolutions.get_evolution_upgrade_rank_description(
		evolution_upgrade_id,
		3
	)
	report.check(
		not hover_rank_one_text.is_empty()
		and not hover_rank_three_text.is_empty()
		and hover_rank_one_tooltip.contains(hover_rank_one_text)
		and not hover_rank_one_tooltip.contains(hover_rank_three_text)
		and hover_rank_three_tooltip.contains(hover_rank_one_text)
		and hover_rank_three_tooltip.contains(hover_rank_three_text)
		and hover_rank_three_tooltip.split("
").size()
		> hover_rank_one_tooltip.split("
").size(),
		"an Evolution hover lists every rank the run owns, not only the newest"
	)
	prototype.progression._upgrade_levels[evolution_upgrade_id] = 1
	prototype._apply_progression_modifiers()
	prototype._update_hud()
	prototype.progression.add_xp(prototype.progression.get_required_xp())
	report.check(
		not prototype.progression.get_eligible_evolutions().has(
			Progression.EvolutionId.SUPER_BLOOM
		),
		"a claimed Evolution stops being eligible for a second Evolution reward"
	)
	prototype._choose_displayed_option(0)

	prototype.combat.reset_combat()
	# The relic fixtures above have been handing this run relics all along, and an
	# exhausted pool pays a Compost Cache instead of opening a panel. The reward
	# under test is the relic, so the pool is restocked first.
	prototype.progression._owned_relics.fill(0)
	var boss_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.BOSS,
		Vector2(760.0, 330.0)
	)
	prototype.combat.debug_damage_enemy(boss_id, 100000.0)
	# The Boss opens the last Branch position, so its Adaptation offer comes first
	# and the relic follows once that choice is made -- by which time the new
	# Adaptation's relic pool is already eligible.
	if prototype.progression.is_pending_adaptation_draft():
		prototype._choose_displayed_option(0)
	report.check(
		prototype.choice_panel.visible
		and prototype.choice_panel.header.text == "ELITE RELIC",
		"defeating the boss pays out a relic once its Adaptation offer is answered"
	)
	prototype._choose_displayed_option(0)

	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	var chain_center := Vector2(735.0, 350.0)
	for index in range(prototype.evolutions.secondary_kills_per_seed):
		prototype.combat.spawn_enemy(
			EnemyKinds.Role.HUNTER,
			chain_center + Vector2(float(index) * 2.0, 0.0)
		)
	var explosion_count_before_bloom := prototype.combat.get_plant_explosion_sfx_play_count()
	prototype.bloom_director.on_bloom_detonated(chain_center, 1)
	report.check(
		prototype.combat.get_plant_explosion_sfx_play_count()
		== explosion_count_before_bloom + 1,
		"Bloom and Super Bloom detonations play the authored explosion SFX"
	)
	report.check(
		prototype.overlay.get_active_seed_count() == 1,
		"Super Bloom kills propagate one safeguarded secondary Seed"
	)

	prototype.combat.reset_combat()
	prototype.overlay.clear_effects()
	var wall_source := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.475,
		prototype.territory_field.tuning.arena_size.y * 0.20
	)
	var wall_open_side := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.415,
		prototype.territory_field.tuning.arena_size.y * 0.20
	)
	var wall_shadow := Vector2(
		prototype.territory_field.tuning.arena_size.x * 0.56,
		prototype.territory_field.tuning.arena_size.y * 0.20
	)
	report.check(
		prototype.territory_field.is_growth_path_clear(wall_source, wall_open_side)
		and not prototype.territory_field.is_growth_path_clear(wall_source, wall_shadow),
		"combat occlusion fixture has an open target and a target behind basalt"
	)
	var open_enemy_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		wall_open_side
	)
	var shadow_enemy_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		wall_shadow
	)
	prototype.combat.damage_enemies_in_radius(
		wall_source,
		150.0,
		10000.0,
		CombatDirector.DeathSource.BLOOM
	)
	report.check(
		not prototype.combat.is_enemy_active(open_enemy_id)
		and prototype.combat.is_enemy_active(shadow_enemy_id),
		"Bloom and germination damage cannot hit enemies through basalt walls"
	)

	prototype.reset_run()
	prototype.set_process(false)
	prototype.player.input_enabled = false
	prototype.debug_advance_time(prototype.wave_director.elite_time_seconds)
	report.check(
		prototype.combat.get_active_enemy_count_by_role(
			EnemyKinds.Role.ELITE
		) == 1,
		"the shortened timeline introduces its elite milestone"
	)
	prototype.debug_advance_time(
		prototype.wave_director.boss_time_seconds
		- prototype.wave_director.elite_time_seconds
	)
	report.check(
		not prototype.combat.has_active_boss()
		and prototype.is_wave_grace_period_active(),
		"the Burrower waits through the grace period at its wave milestone"
	)
	prototype.debug_advance_time(prototype.wave_director.wave_grace_period_seconds)
	report.check(
		prototype.combat.has_active_boss(),
		"the Burrower arrives immediately after its milestone grace ends"
	)
	prototype.debug_advance_time(
		prototype.wave_director.final_invasion_time_seconds - prototype.get_elapsed_seconds()
	)
	report.check(
		prototype.wave_director.final_invasion_started,
		"the final invasion phase begins on the timeline"
	)
	var specialist_schedule_is_authored := true
	var specialist_schedule: Array[Array] = [
		[
			prototype.wave_director.saboteur_intro_seconds,
			prototype.wave_director.saboteur_pack_cycle,
			EnemyKinds.Role.SABOTEUR,
		],
		[
			prototype.wave_director.corruptor_intro_seconds,
			prototype.wave_director.corruptor_pack_cycle,
			EnemyKinds.Role.CORRUPTOR,
		],
		[
			prototype.wave_director.colonizer_intro_seconds,
			prototype.wave_director.colonizer_pack_cycle,
			EnemyKinds.Role.COLONIZER,
		],
		[
			prototype.wave_director.warden_intro_seconds,
			prototype.wave_director.warden_pack_cycle,
			EnemyKinds.Role.WARDEN,
		],
	]
	for specialist_entry in specialist_schedule:
		prototype.wave_director.elapsed_seconds = specialist_entry[0]
		prototype.wave_director._spawn_pack_sequence = specialist_entry[1] - 1
		specialist_schedule_is_authored = (
			specialist_schedule_is_authored
			and prototype.wave_director._select_regular_role(
				EnemyKinds.Role.HUNTER
			) == specialist_entry[2]
		)
	report.check(
		specialist_schedule_is_authored,
		"the wave schedule introduces all four specialist roles at authored cadences"
	)
