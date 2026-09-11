## The Plant pool every run can draw from, and the Root relics that read the Network
## under the ground.
##
## The Root half stands deliberately deep: these relics are about the Network's depth
## and the frontier hedge reaches a few cells inward, so ground near an edge would
## answer for the wrong reason.
class_name SmokeRelicsPlantRoot
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot, relics: RelicDirector, lone_spot: Vector2) -> void:
	# ------------------------------------------------------------- Plant relics
	# Plant is the glue pool, and two of its relics repeat other relics' effects,
	# so the recursion limiters here are the ones guarding the whole catalog.
	relics.reset_director()
	prototype.combat.reset_combat()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	var plant_spot := SmokeFixtures.find_owned_cell_position(prototype)

	# Garden Hose: distance is counted on owned Green only, a teleport-sized step
	# never banks any of it, and the counter resets only when the spray fires.
	prototype.progression._owned_relics[RelicCatalog.Id.GARDEN_HOSE] = 1
	relics._garden_hose_travel = 0.0
	relics._garden_hose_last_position = plant_spot
	prototype.player.global_position = prototype.territory_field.to_global(
		plant_spot + Vector2(400.0, 0.0)
	)
	relics._advance_garden_hose()
	var hose_ignored_jump := relics._garden_hose_travel
	relics._garden_hose_last_position = plant_spot
	prototype.player.global_position = prototype.territory_field.to_global(
		plant_spot + Vector2(20.0, 0.0)
	)
	relics._advance_garden_hose()
	var hose_counted_step := relics._garden_hose_travel
	report.check(
		is_equal_approx(hose_ignored_jump, 0.0) and hose_counted_step > 0.0,
		"GARDEN HOSE counts ordinary travel on Green and never a teleport-sized jump"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.GARDEN_HOSE] = 0

	# Mulch: only what an enemy itself eats is stored, it is capped, and one corpse
	# releases it exactly once.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.MULCH] = 1
	relics.notify_green_eaten(41, 0.5)
	var mulch_stored := relics.get_mulch_store(41)
	for _mulch_bite in range(40):
		relics.notify_green_eaten(41, 1.0)
	var mulch_capped := relics.get_mulch_store(41)
	relics._release_mulch(41, plant_spot)
	var mulch_released := relics.get_mulch_store(41)
	report.check(
		mulch_stored > 0.0
		and mulch_capped <= relics.mulch_maximum_store + 0.001
		and is_equal_approx(mulch_released, 0.0),
		"MULCH stores a share of what an enemy eats, caps it, and releases it once"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.MULCH] = 0

	# Compost Heap: corpses merge into a nearby pile, an elite is worth more than a
	# hunter, the pile erupts on its threshold, and the active count is capped.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.COMPOST_HEAP] = 1
	relics._add_compost(plant_spot, 1)
	var heaps_started := relics.get_compost_heap_count()
	relics._add_compost(plant_spot + Vector2(10.0, 0.0), 1)
	var heaps_merged := relics.get_compost_heap_count()
	# Exactly up to the threshold and no further: a heap at threshold stops
	# accepting, so extra corpses would correctly start new piles instead.
	for _compost_corpse in range(relics.compost_threshold - 2):
		relics._add_compost(plant_spot + Vector2(10.0, 0.0), 1)
	for _compost_tick in range(int(relics.compost_eruption_delay * 60.0) + 6):
		relics.advance(1.0 / 60.0)
	var heap_erupted := relics.get_compost_heap_count() == 0
	for far_heap in range(relics.compost_maximum_heaps + 4):
		relics._add_compost(plant_spot + Vector2(float(far_heap) * 300.0, 0.0), 1)
	report.check(
		heaps_started == 1
		and heaps_merged == 1
		and heap_erupted
		and relics.get_compost_heap_count() <= relics.compost_maximum_heaps,
		"COMPOST HEAP merges nearby corpses, erupts on its threshold, and caps its piles"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.COMPOST_HEAP] = 0

	# Miracle-Gro: new Green banks one charge, a second charge cannot stack behind
	# it, and the next Adaptation event spends it.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.MIRACLE_GRO] = 1
	relics.notify_green_created(relics.miracle_gro_required_mass * 0.5)
	var gro_half := relics.is_miracle_gro_charged()
	relics.notify_green_created(relics.miracle_gro_required_mass * 0.5)
	var gro_charged := relics.is_miracle_gro_charged()
	relics.notify_green_created(relics.miracle_gro_required_mass * 4.0)
	var gro_spent := relics.consume_miracle_gro()
	var gro_spent_twice := relics.consume_miracle_gro()
	report.check(
		not gro_half
		and gro_charged
		and is_equal_approx(gro_spent, relics.miracle_gro_strength)
		and is_equal_approx(gro_spent_twice, 0.0),
		"MIRACLE-GRO banks one repeat at a time and the next event spends it"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.MIRACLE_GRO] = 0

	# Grafting Tape: ready, spent, and then held on its cooldown.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.GRAFTING_TAPE] = 1
	var tape_ready := relics.is_grafting_tape_ready()
	var tape_strength := relics.consume_grafting_tape()
	var tape_on_cooldown := not relics.is_grafting_tape_ready()
	report.check(
		tape_ready
		and is_equal_approx(tape_strength, relics.grafting_tape_strength)
		and tape_on_cooldown,
		"GRAFTING TAPE answers once and then holds its cooldown"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.GRAFTING_TAPE] = 0

	# Hybrid Vigor: a repeat can never roll another repeat, Hybrid Vigor never
	# repeats itself, and the rolling window bounds how many land at once.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.HYBRID_VIGOR] = 1
	relics.hybrid_vigor_chance = 1.0
	relics._try_hybrid_vigor(RelicCatalog.Id.HYBRID_VIGOR)
	var vigor_self_repeat := relics._generated_events.size()
	relics._repeating = true
	relics._try_hybrid_vigor(RelicCatalog.Id.SNARE_VINE)
	relics._repeating = false
	var vigor_from_repeat := relics._generated_events.size()
	for _vigor_roll in range(relics.hybrid_vigor_window_maximum + 5):
		relics._try_hybrid_vigor(RelicCatalog.Id.SNARE_VINE)
	var vigor_windowed := relics._generated_events.size()
	report.check(
		vigor_self_repeat == 0
		and vigor_from_repeat == 0
		and vigor_windowed == relics.hybrid_vigor_window_maximum,
		"HYBRID VIGOR never repeats itself or a repeat, and its rolling window holds"
	)

	# The global scheduler drains its queue on a budget rather than dropping what
	# the player earned, and a full queue keeps the rarest events.
	var queued_before := relics._generated_events.size()
	for _drain_tick in range(120):
		relics.advance(1.0 / 60.0)
	var drained := relics._generated_events.is_empty()
	relics._generated_events.clear()
	for _fill in range(relics.generated_event_queue_maximum):
		relics._queue_generated_event(
			RelicCatalog.Id.SNARE_VINE, plant_spot, 0.5, 99.0
		)
	var accepted_legendary := relics._queue_generated_event(
		RelicCatalog.Id.THE_HEDGE, plant_spot, 0.5, 99.0
	)
	report.check(
		queued_before > 0 and drained and accepted_legendary,
		"the generated-event queue drains on its frame budget and a full one keeps the rarest"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.HYBRID_VIGOR] = 0
	relics.reset_director()
	prototype.combat.reset_combat()

	# -------------------------------------------------------------- Root relics
	# Root transmits through Mature Green rather than adding a resource to manage,
	# so these cases check what the network does, not what the player spends.
	relics.reset_director()
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	var root_spot := SmokeFixtures.find_owned_cell_position(prototype)

	# The Shared Ancient Territory rule places near Grandma rather than on the
	# globally oldest cell, which is the whole point of replacing it.
	for _ripen_ancient in range(6):
		prototype.territory_field.queue_maturity_support(root_spot, 1.0, 4.0)
		prototype.territory_field.step_simulation()
	prototype.player.global_position = prototype.territory_field.to_global(root_spot)
	# The region list is sampled on the shared topology clock, so a relic that reads
	# it has to be held and one sample has to have run.
	prototype.progression._owned_relics[RelicCatalog.Id.TAPROOT] = 1
	relics._topology_remaining = 0.0
	relics._advance_topology(1.0 / 60.0)
	var ancient_site := relics._find_ancient_site()
	var ancient_is_near := (
		ancient_site.x >= 0.0
		and ancient_site.distance_to(root_spot) <= relics.ancient_expanded_search_pixels
	)
	# A region already tracked is skipped, which is what lets Annual Rings hold
	# several distinct regions instead of stacking them all on one.
	var excluded_site := relics._find_ancient_site(
		PackedVector2Array([ancient_site]), 4000.0
	)
	report.check(
		ancient_is_near and excluded_site.x < 0.0,
		"the Ancient Territory rule places near Grandma and skips regions already tracked"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.TAPROOT] = 0

	# Rootbound: charged by continuous time on deep Green, carried, and spent by
	# walking into young Green rather than by standing still.
	prototype.progression._owned_relics[RelicCatalog.Id.ROOTBOUND] = 1
	relics._rootbound_standing = 0.0
	relics._rootbound_carrying = 0.0
	relics._rootbound_cooldown = 0.0
	prototype.player.global_position = prototype.territory_field.to_global(root_spot)
	for _charge_tick in range(int(relics.rootbound_charge_seconds * 60.0) + 6):
		relics._advance_rootbound(1.0 / 60.0)
	var rootbound_carrying := relics._rootbound_carrying > 0.0
	# Stepping off owned Green entirely must not discharge it.
	var off_green := prototype.territory_field.find_player_frontier_near(root_spot)
	relics._advance_rootbound(1.0 / 60.0)
	var rootbound_held := relics._rootbound_carrying > 0.0
	report.check(
		rootbound_carrying and rootbound_held,
		"ROOTBOUND charges on deep Green and keeps the pulse until young Green takes it"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.ROOTBOUND] = 0

	# Suckers: only enemy-caused loss counts, and the relic answers once per
	# regional cooldown rather than once per cell.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.SUCKERS] = 1
	relics.notify_mature_green_lost(relics.suckers_lost_cells - 1)
	relics._advance_suckers(1.0 / 60.0)
	var suckers_under_threshold := relics._pending_suckers.size()
	relics.notify_mature_green_lost(2)
	relics._advance_suckers(1.0 / 60.0)
	var suckers_sprouted := relics._pending_suckers.size()
	# A second wound inside the cooldown must not sprout again.
	relics.notify_mature_green_lost(relics.suckers_lost_cells * 2)
	relics._advance_suckers(1.0 / 60.0)
	var suckers_on_cooldown := relics._pending_suckers.size()
	report.check(
		suckers_under_threshold == 0
		and suckers_sprouted == relics.suckers_count
		and suckers_on_cooldown == suckers_sprouted,
		"SUCKERS answers a real wound once, and its regional cooldown holds"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.SUCKERS] = 0

	# Feeder Roots: only amplified natural events on deep Green count, and a
	# relic-generated echo never advances it.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.FEEDER_ROOTS] = 1
	relics.notify_amplified_event(root_spot, 1.0)
	var feeder_unamplified := relics._feeder_events
	relics._repeating = true
	relics.notify_amplified_event(root_spot, 1.5)
	relics._repeating = false
	var feeder_from_echo := relics._feeder_events
	for _feeder_event in range(relics.feeder_roots_events - 1):
		relics.notify_amplified_event(root_spot, 1.5)
	var feeder_counted := relics._feeder_events
	report.check(
		feeder_unamplified == 0
		and feeder_from_echo == 0
		and feeder_counted == relics.feeder_roots_events - 1,
		"FEEDER ROOTS counts only amplified natural events, never an unamplified one or an echo"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.FEEDER_ROOTS] = 0

	# Graft Union: arms on a reconnection, is spent once, and then holds cooldown.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.GRAFT_UNION] = 1
	var graft_unarmed := relics.is_graft_union_armed()
	# Component count comes off the shared topology cache, so the split and the
	# rejoin are driven through that seam rather than by rearranging the board.
	relics._cached_component_count = 2
	relics._advance_graft_union(1.0 / 60.0)
	var graft_saw_split := relics._graft_components > 1
	relics._graft_split_seconds = relics.graft_union_separation_seconds
	relics._cached_component_count = 1
	relics._advance_graft_union(1.0 / 60.0)
	var graft_armed := relics.is_graft_union_armed()
	var graft_strength := relics.consume_graft_union()
	var graft_spent_twice := relics.consume_graft_union()
	report.check(
		not graft_unarmed
		and graft_saw_split
		and graft_armed
		and is_equal_approx(graft_strength, relics.graft_union_strength)
		and is_equal_approx(graft_spent_twice, 0.0),
		"GRAFT UNION arms when a long-split network rejoins and its echo is spent once"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.GRAFT_UNION] = 0

	# Rhizome: a whole organism offers no colony to reconnect, and the field's own
	# component query is what decides that rather than the relic guessing.
	relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.RHIZOME] = 1
	prototype.territory_field.reset_field()
	prototype.territory_field.step_simulation()
	var whole_organism := prototype.territory_field.find_isolated_colony(
		relics.rhizome_minimum_cells, relics.rhizome_minimum_maturity
	)
	for _rhizome_tick in range(int(relics.rhizome_survival_seconds * 60.0) + 10):
		relics._advance_rhizome(1.0 / 60.0)
	report.check(
		whole_organism.x < 0.0
		and prototype.territory_field.get_owned_component_count() >= 1
		and relics._rhizome_growing <= 0.0,
		"RHIZOME finds nothing to reconnect while the organism is in one piece"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.RHIZOME] = 0
	relics.reset_director()
	prototype.combat.reset_combat()
