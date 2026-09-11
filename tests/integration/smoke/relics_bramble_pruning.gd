## The relics of the two paths that act on ground rather than on bodies: Bramble's
## shove and Entanglement, and Pruning's wound.
##
## Both read the territory back rather than a health bar, so these blocks thorn their
## own Green and stand the player where the harvest will reach.
class_name SmokeRelicsBramblePruning
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot, relics: RelicDirector, lone_spot: Vector2) -> void:
	# ----------------------------------------------------------- Bramble relics
	# The pool's engine is Entanglement feeding itself, so each case asserts both
	# that the rule fires and that the limiter which stops it looping holds.
	var bramble := prototype.bramble_director
	var bramble_spot := SmokeFixtures.find_owned_cell_position(prototype)

	# Hookthorn: a shoved enemy that collides with another tangles both, once per
	# shove, and then both sit on a cooldown.
	bramble.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.HOOKTHORN] = 1
	var shoved_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER, bramble_spot
	)
	var struck_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		bramble_spot + Vector2(bramble.hookthorn_collision_pixels * 0.5, 0.0)
	)
	prototype.combat.enemy_repelled.emit(shoved_id, bramble_spot, Vector2.RIGHT)
	bramble.advance_relics(1.0 / 60.0)
	var hook_shoved := prototype.combat.get_enemy_entanglement(shoved_id)
	var hook_struck := prototype.combat.get_enemy_entanglement(struck_id)
	# The window closed on the collision, so a second tick must add nothing.
	bramble.advance_relics(1.0 / 60.0)
	var hook_no_repeat := is_equal_approx(
		prototype.combat.get_enemy_entanglement(struck_id), hook_struck
	)
	report.check(
		hook_shoved > 0.0 and hook_struck > hook_shoved and hook_no_repeat,
		"HOOKTHORN tangles both bodies once per shove and cannot retrigger from it"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.HOOKTHORN] = 0

	# Thornback: a shove makes the Green shoot a thorn at the least tangled enemy
	# other than the one that was shoved.
	bramble.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.THORNBACK] = 1
	var thorn_source := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER, bramble_spot
	)
	var thorn_target := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER, bramble_spot + Vector2(90.0, 0.0)
	)
	var thorn_health_before := prototype.combat.get_enemy_health(thorn_target)
	prototype.combat.enemy_repelled.emit(thorn_source, bramble_spot, Vector2.RIGHT)
	var thorn_hit := prototype.combat.get_enemy_health(thorn_target) < thorn_health_before
	var thorn_tangled := prototype.combat.get_enemy_entanglement(thorn_target) > 0.0
	# The per-source cooldown has to stop a grazing cadence firing a stream of them.
	var health_after_first := prototype.combat.get_enemy_health(thorn_target)
	prototype.combat.enemy_repelled.emit(thorn_source, bramble_spot, Vector2.RIGHT)
	var thorn_on_cooldown := is_equal_approx(
		prototype.combat.get_enemy_health(thorn_target), health_after_first
	)
	report.check(
		thorn_hit and thorn_tangled and thorn_on_cooldown,
		"THORNBACK shoots one thorn per shove and its source cooldown holds"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.THORNBACK] = 0

	# Cocklebur: only an enemy that leaves Green heavily Entangled carries burrs,
	# and leaving again does not refresh the timer.
	bramble.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.COCKLEBUR] = 1
	var carrier_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER, bramble_spot
	)
	prototype.combat.enemy_left_green.emit(
		carrier_id, bramble_spot, bramble.cocklebur_minimum_entanglement - 0.1
	)
	var burr_under_threshold := bramble.get_burr_carrier_count()
	prototype.combat.enemy_left_green.emit(
		carrier_id, bramble_spot, bramble.cocklebur_minimum_entanglement
	)
	var burr_carried := bramble.get_burr_carrier_count()
	# A carrier spreads Entanglement by touch, and only to bodies it has not
	# already burred.
	var burr_target := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		bramble_spot + Vector2(bramble.cocklebur_contact_pixels * 0.5, 0.0)
	)
	bramble.advance_relics(1.0 / 60.0)
	var burr_spread := prototype.combat.get_enemy_entanglement(burr_target)
	bramble.advance_relics(1.0 / 60.0)
	var burr_capped := is_equal_approx(
		prototype.combat.get_enemy_entanglement(burr_target), burr_spread
	)
	report.check(
		burr_under_threshold == 0 and burr_carried == 1 and burr_spread > 0.0 and burr_capped,
		"COCKLEBUR burrs only a heavily Entangled leaver and respects its touch cooldown"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.COCKLEBUR] = 0

	# Briar Knot: a heavily Entangled corpse leaves a one-use trap, and the active
	# cap replaces the oldest rather than refusing the newest.
	bramble.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.BRIAR_KNOT] = 1
	prototype.combat.enemy_died_entangled.emit(
		bramble_spot,
		bramble.briar_knot_required_entanglement - 0.1,
		EnemyKinds.Role.HUNTER
	)
	var knot_under_threshold := bramble.get_knot_count()
	for knot_index in range(bramble.briar_knot_maximum + 3):
		prototype.combat.enemy_died_entangled.emit(
			bramble_spot + Vector2(float(knot_index) * 400.0, 0.0),
			1.0,
			EnemyKinds.Role.HUNTER
		)
	var knots_capped := bramble.get_knot_count()
	# One use: an enemy walking into a Knot springs it and the Knot is gone.
	bramble.reset_director()
	prototype.combat.enemy_died_entangled.emit(
		bramble_spot, 1.0, EnemyKinds.Role.HUNTER
	)
	var caught_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER, bramble_spot
	)
	for _knot_tick in range(30):
		bramble.advance_relics(1.0 / 60.0)
	report.check(
		knot_under_threshold == 0
		and knots_capped == bramble.briar_knot_maximum
		and bramble.get_knot_count() == 0
		and prototype.combat.get_enemy_entanglement(caught_id) > 0.0,
		"BRIAR KNOT arms on a tangled corpse, caps its count, and springs exactly once"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.BRIAR_KNOT] = 0

	# Briarball: four heavily Entangled deaths roll into one ball, and the active
	# cap preserves a completed charge rather than spending it into nothing.
	bramble.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.BRIARBALL] = 1
	for _ball_death in range(bramble.briarball_deaths_required - 1):
		prototype.combat.enemy_died_entangled.emit(
			bramble_spot, 1.0, EnemyKinds.Role.HUNTER
		)
	var ball_under_charge := bramble.get_briarball_count()
	prototype.combat.enemy_died_entangled.emit(
		bramble_spot, 1.0, EnemyKinds.Role.HUNTER
	)
	var ball_rolled := bramble.get_briarball_count()
	# A ball damages and tangles what it rolls over.
	var rolled_id := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		bramble_spot + Vector2(bramble.briarball_contact_pixels * 0.5, 0.0)
	)
	var rolled_health := prototype.combat.get_enemy_health(rolled_id)
	bramble.advance_relics(1.0 / 60.0)
	report.check(
		ball_under_charge == 0
		and ball_rolled == 1
		and prototype.combat.get_enemy_health(rolled_id) < rolled_health
		and prototype.combat.get_enemy_entanglement(rolled_id) > 0.0,
		"BRIARBALL rolls on its fourth tangled corpse and crashes through the crowd"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.BRIARBALL] = 0
	bramble.reset_director()
	prototype.combat.reset_combat()

	# ----------------------------------------------------------- Pruning relics
	# Pruning's pool turns one release into a cycle, so every case here asserts the
	# limiter as well as the payout: an unbounded Pruning build is the failure mode.
	prototype.progression.reset_progression()
	prototype.progression.debug_select_paths(
		Progression.PathId.PRUNING,
		Progression.PathId.SPORE
	)
	prototype._apply_progression_modifiers()
	var pruning_relics := prototype.pruning_director
	var prune_spot := SmokeFixtures.find_owned_cell_position(prototype)
	prototype.player.global_position = prototype.territory_field.to_global(prune_spot)

	# Brush Pile: only Green cut past half Charge is stored, the bundle count is
	# capped, and a release empties the store whether or not it was full.
	pruning_relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.BRUSH_PILE] = 1
	pruning_relics._charge = pruning_relics.brush_pile_charge_threshold - 0.1
	pruning_relics._note_brush_harvest(pruning_relics.brush_pile_cells_per_bundle * 2)
	var brush_below_threshold := pruning_relics.get_brush_bundles()
	pruning_relics._charge = pruning_relics.brush_pile_charge_threshold
	pruning_relics._note_brush_harvest(
		pruning_relics.brush_pile_cells_per_bundle * (pruning_relics.brush_pile_maximum_bundles + 3)
	)
	var brush_capped := pruning_relics.get_brush_bundles()
	report.check(
		brush_below_threshold == 0
		and brush_capped == pruning_relics.brush_pile_maximum_bundles,
		"BRUSH PILE stores only what is cut past half Charge and stops at its cap"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.BRUSH_PILE] = 0

	# Callus: standing in the wound when the ring fires is not returning to it. The
	# player has to leave and come back before the pulse is owed.
	pruning_relics.reset_director()
	prototype.progression._owned_relics[RelicCatalog.Id.CALLUS] = 1
	pruning_relics._callus_position = prune_spot
	pruning_relics._callus_remaining = pruning_relics.callus_window_seconds
	pruning_relics._callus_used = false
	pruning_relics._callus_left_wound = false
	prototype.player.global_position = prototype.territory_field.to_global(prune_spot)
	pruning_relics._advance_callus(1.0 / 60.0)
	var callus_standing_still := pruning_relics._callus_used
	# Leave the wound, then come back.
	prototype.player.global_position = prototype.territory_field.to_global(
		prune_spot + Vector2(pruning_relics.callus_radius_pixels * 2.0, 0.0)
	)
	pruning_relics._advance_callus(1.0 / 60.0)
	prototype.player.global_position = prototype.territory_field.to_global(prune_spot)
	pruning_relics._advance_callus(1.0 / 60.0)
	var callus_paid := pruning_relics._callus_used
	# One pulse per release: a second return is worth nothing.
	pruning_relics._advance_callus(1.0 / 60.0)
	report.check(
		not callus_standing_still and callus_paid and not pruning_relics.is_callus_armed(),
		"CALLUS pays once, and only after the player has actually left the wound"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.CALLUS] = 0

	# Stubble: the wound stays sharp, each enemy is on its own tick cooldown, and
	# only two wounds are ever hazardous at once.
	pruning_relics.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.STUBBLE] = 1
	for stubble_wound_index in range(pruning_relics.stubble_maximum_wounds + 2):
		pruning_relics._stubble_wounds.append([
			prune_spot + Vector2(float(stubble_wound_index) * 500.0, 0.0),
			pruning_relics.stubble_seconds,
			{},
		])
		if pruning_relics._stubble_wounds.size() > pruning_relics.stubble_maximum_wounds:
			pruning_relics._stubble_wounds.remove_at(0)
	var stubble_capped := pruning_relics.get_stubble_wound_count()
	# A wound expires rather than lingering.
	for _stubble_tick in range(int(pruning_relics.stubble_seconds * 60.0) + 10):
		pruning_relics._advance_stubble(1.0 / 60.0)
	report.check(
		stubble_capped == pruning_relics.stubble_maximum_wounds
		and pruning_relics.get_stubble_wound_count() == 0,
		"STUBBLE keeps at most two sharp wounds and each one expires on its own clock"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.STUBBLE] = 0

	# Skimming Cut: a natural spike glances off terrain toward a new target once,
	# and a spike that has already glanced is spent by its next collision.
	pruning_relics.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.SKIMMING_CUT] = 1
	prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER, prune_spot + Vector2(60.0, 0.0)
	)
	var skimmer := pruning_relics._get_inactive_cutting()
	skimmer.position = prune_spot
	skimmer.damage = 40.0
	skimmer.velocity = Vector2(200.0, 0.0)
	skimmer.natural_release = true
	skimmer.has_ricocheted = false
	var skimmed := pruning_relics._try_skimming_cut(skimmer)
	var skim_damage_cut := skimmer.damage < 40.0
	var skim_again := pruning_relics._try_skimming_cut(skimmer)
	# A relic-thrown spike is not a natural release and never glances.
	var relic_spike := pruning_relics._get_inactive_cutting()
	relic_spike.position = prune_spot
	relic_spike.damage = 40.0
	relic_spike.velocity = Vector2(200.0, 0.0)
	relic_spike.natural_release = false
	var relic_skimmed := pruning_relics._try_skimming_cut(relic_spike)
	report.check(
		skimmed and skim_damage_cut and not skim_again and not relic_skimmed,
		"SKIMMING CUT redirects a natural spike once and never a relic-thrown one"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.SKIMMING_CUT] = 0

	# Watersprouts: a natural killing spike sprouts children, those children may
	# branch once more, and generation two is the end of it.
	pruning_relics.reset_director()
	prototype.combat.reset_combat()
	prototype.progression._owned_relics[RelicCatalog.Id.WATERSPROUTS] = 1
	for sprout_index in range(8):
		prototype.combat.spawn_enemy(
			EnemyKinds.Role.HUNTER,
			prune_spot + Vector2(40.0 + float(sprout_index) * 12.0, 0.0)
		)
	var parent := pruning_relics._get_inactive_cutting()
	parent.position = prune_spot
	parent.damage = 40.0
	parent.natural_release = true
	parent.sprout_generation = 0
	pruning_relics._sprout_watersprouts(parent, prune_spot)
	var generation_one := pruning_relics._watersprouts_this_release
	# A generation-2 spike must not reproduce at all.
	var final_child := pruning_relics._get_inactive_cutting()
	final_child.position = prune_spot
	final_child.damage = 20.0
	final_child.natural_release = false
	final_child.sprout_generation = 2
	pruning_relics._sprout_watersprouts(final_child, prune_spot)
	var after_final := pruning_relics._watersprouts_this_release
	# The per-release cap is absolute across both generations.
	pruning_relics._watersprouts_this_release = pruning_relics.watersprout_release_maximum
	pruning_relics._sprout_watersprouts(parent, prune_spot)
	var at_cap := pruning_relics._watersprouts_this_release
	report.check(
		generation_one == pruning_relics.watersprout_children
		and after_final == generation_one
		and at_cap == pruning_relics.watersprout_release_maximum,
		"WATERSPROUTS branches twice, stops at generation two, and honours its release cap"
	)
	prototype.progression._owned_relics[RelicCatalog.Id.WATERSPROUTS] = 0
	pruning_relics.reset_director()
	prototype.combat.reset_combat()
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()
