## The Clover machine: territory is the stake and the payout is a Path event.
##
## That is the whole feature and the reason it is checked this hard - what is risked
## comes off the organism and what is won lands on the battlefield, so they are not
## one axis wearing two names. Most of these checks are about honesty rather than
## odds: a face that reads as a jackpot has to be one, the four chances have to sum,
## and a lost wager has to take the ground it named and no other.
##
## The constructed-result checks sample thousands of built displays rather than
## spinning, because a reel that lies once in a thousand spins is still a reel that
## lies.
class_name SmokeCloverMachine
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	var adaptations := prototype.adaptation_director

	# The Clover machine. Territory is the stake and the payout is a Path event, which is
	# the point of the whole feature: what is risked comes off the organism and what is
	# won lands on the battlefield, so they are not one axis wearing two names.
	var machine := prototype.slot_machine
	var clover_odds := prototype.clover_odds
	var selector := prototype.wager_selector
	var jackpots := prototype.clover_jackpots
	var grace := prototype.all_in_grace
	machine.reset_machine()
	clover_odds.reset_odds()
	jackpots.reset_jackpots()
	grace.reset_grace()
	prototype.progression.reset_progression()

	# The winning grammar. A Clover stands in for a missing Path symbol and for nothing
	# else: it never completes a Bust, and it never picks between two different Paths.
	var wild_completes := CloverSlot.resolve_outcome(PackedInt32Array([
		CloverSlot.Symbol.BLOOM,
		CloverSlot.Symbol.CLOVER,
		CloverSlot.Symbol.BLOOM,
	]))
	var clover_bust := CloverSlot.resolve_outcome(PackedInt32Array([
		CloverSlot.Symbol.BUST,
		CloverSlot.Symbol.BUST,
		CloverSlot.Symbol.CLOVER,
	]))
	var mixed_paths := CloverSlot.resolve_outcome(PackedInt32Array([
		CloverSlot.Symbol.BLOOM,
		CloverSlot.Symbol.ROOT,
		CloverSlot.Symbol.CLOVER,
	]))
	report.check(
		wild_completes == CloverSlot.Outcome.PATH_JACKPOT
		and CloverSlot.resolve_path(PackedInt32Array([
			CloverSlot.Symbol.BLOOM,
			CloverSlot.Symbol.CLOVER,
			CloverSlot.Symbol.BLOOM,
		])) == CloverSlot.Symbol.BLOOM
		and clover_bust == CloverSlot.Outcome.WHIFF
		and mixed_paths == CloverSlot.Outcome.WHIFF
		and CloverSlot.resolve_outcome(PackedInt32Array([
			CloverSlot.Symbol.CLOVER,
			CloverSlot.Symbol.CLOVER,
			CloverSlot.Symbol.CLOVER,
		])) == CloverSlot.Outcome.TRIPLE_CLOVER,
		"a Clover completes a Path pair, never a Bust, and never chooses between two Paths"
	)
	var all_slot_paths_present := CloverSlot.PATH_SYMBOLS.size() == Progression.PathId.size()
	var mapped_slot_paths := {}
	for path_symbol in CloverSlot.PATH_SYMBOLS:
		var mapped_path := prototype._path_id_for_symbol(path_symbol)
		all_slot_paths_present = (
			all_slot_paths_present
			and CloverSlot.is_path_symbol(path_symbol)
			and mapped_path >= 0
			and prototype.slot_panel.symbol_texture(path_symbol) != null
		)
		mapped_slot_paths[mapped_path] = true
	report.check(
		all_slot_paths_present
		and mapped_slot_paths.size() == Progression.PathId.size()
		and CloverSlot.PATH_SYMBOLS.has(CloverSlot.Symbol.THISTLE)
		and CloverSlot.PATH_SYMBOLS.has(CloverSlot.Symbol.VINE)
		and CloverSlot.PATH_SYMBOLS.has(CloverSlot.Symbol.FRUIT)
		and CloverSlot.resolve_outcome(PackedInt32Array([
			CloverSlot.Symbol.FRUIT,
			CloverSlot.Symbol.CLOVER,
			CloverSlot.Symbol.FRUIT,
		])) == CloverSlot.Outcome.PATH_JACKPOT,
		"all eight Paths have unique reel mappings and icons, including the three Adaptations"
	)

	# The reels are built to represent a result that was already decided, so a face the
	# machine draws must never resolve to a different outcome than the one it was asked
	# for. A whiff that accidentally reads as a jackpot is the one bug in a slot machine
	# that cannot be argued with.
	var display_mismatches := 0
	var whiff_teases := 0
	for _display_index in range(4000):
		for outcome in [
			CloverSlot.Outcome.WHIFF,
			CloverSlot.Outcome.PATH_JACKPOT,
			CloverSlot.Outcome.TRIPLE_CLOVER,
			CloverSlot.Outcome.TRIPLE_BUST,
		]:
			var wanted_path := clover_odds.pick_path()
			var faces := clover_odds.build_display(outcome, wanted_path)
			if CloverSlot.resolve_outcome(faces) != outcome:
				display_mismatches += 1
			if outcome == CloverSlot.Outcome.PATH_JACKPOT \
				and CloverSlot.resolve_path(faces) != wanted_path:
				display_mismatches += 1
			if outcome == CloverSlot.Outcome.WHIFF and faces[0] == faces[1]:
				whiff_teases += 1
	report.check(
		display_mismatches == 0 and whiff_teases > 0,
		"every constructed line shows exactly the result it was built for, teases included (%d teases, %d mismatches)"
			% [whiff_teases, display_mismatches]
	)

	# Truthful odds. Whatever protection is running underneath, the four outcome chances
	# have to be a probability distribution, because they are also the numbers printed
	# on the readout.
	var odds_sum_error := 0.0
	for stake in range(CloverSlot.Stake.size()):
		var stake_odds := clover_odds.get_effective_odds(stake)
		odds_sum_error = maxf(odds_sum_error, absf(
			float(stake_odds["path_jackpot"])
			+ float(stake_odds["triple_clover"])
			+ float(stake_odds["triple_bust"])
			+ float(stake_odds["whiff"])
			- 1.0
		))
	report.check(odds_sum_error < 0.0001, "the printed odds are a complete distribution")

	# Drought protection begins only after a real drought, takes its extra chance out of
	# Whiff alone, and is counted per stake so cheap Low spins cannot charge up pity and
	# have it cashed out on an All In.
	clover_odds.reset_odds()
	var dry_base := clover_odds.get_effective_odds(CloverSlot.Stake.MEDIUM)
	for _dry_spin in range(clover_odds.drought_grace_spins):
		clover_odds.note_outcome(CloverSlot.Stake.MEDIUM, CloverSlot.Outcome.WHIFF)
	var dry_at_grace := clover_odds.get_effective_odds(CloverSlot.Stake.MEDIUM)
	clover_odds.note_outcome(CloverSlot.Stake.MEDIUM, CloverSlot.Outcome.WHIFF)
	var dry_past_grace := clover_odds.get_effective_odds(CloverSlot.Stake.MEDIUM)
	var untouched_stake := clover_odds.get_effective_odds(CloverSlot.Stake.ALL_IN)
	report.check(
		is_equal_approx(float(dry_at_grace["path_jackpot"]), float(dry_base["path_jackpot"]))
		and float(dry_past_grace["path_jackpot"]) > float(dry_base["path_jackpot"])
		and is_equal_approx(
			float(dry_past_grace["triple_clover"]), float(dry_base["triple_clover"])
		)
		and is_equal_approx(
			float(dry_past_grace["triple_bust"]), float(dry_base["triple_bust"])
		)
		and float(dry_past_grace["whiff"]) < float(dry_base["whiff"])
		and clover_odds.get_drought(CloverSlot.Stake.ALL_IN) == 0
		and is_equal_approx(
			float(untouched_stake["path_jackpot"]),
			clover_odds.path_jackpot_chances[CloverSlot.Stake.ALL_IN]
		),
		"pity starts after a drought, comes only out of Whiff, and does not cross stakes"
	)

	# A positive result clears the drought for that stake, and no drought can push the
	# positive chance past the cap: without one, a long Low drought would eventually pay
	# better than All In and there would be no reason to take a real risk.
	for _long_dry in range(40):
		clover_odds.note_outcome(CloverSlot.Stake.LOW, CloverSlot.Outcome.WHIFF)
	var capped := clover_odds.get_effective_odds(CloverSlot.Stake.LOW)
	clover_odds.note_outcome(CloverSlot.Stake.LOW, CloverSlot.Outcome.PATH_JACKPOT)
	var after_win := clover_odds.get_effective_odds(CloverSlot.Stake.LOW)
	report.check(
		float(capped["positive"]) <= clover_odds.positive_caps[CloverSlot.Stake.LOW] + 0.0001
		and float(capped["positive"]) > float(after_win["positive"])
		and clover_odds.get_drought(CloverSlot.Stake.LOW) == 0,
		"a drought is capped and a win clears it (%.3f capped, %.3f after)"
			% [float(capped["positive"]), float(after_win["positive"])]
	)

	# Triple Bust cannot happen twice in a row, and the probability taken off it becomes
	# Whiff rather than Jackpot: a catastrophe must not make the next spin generous.
	clover_odds.reset_odds()
	var bust_normal := clover_odds.get_effective_odds(CloverSlot.Stake.HIGH)
	clover_odds.note_outcome(CloverSlot.Stake.HIGH, CloverSlot.Outcome.TRIPLE_BUST)
	var bust_next := clover_odds.get_effective_odds(CloverSlot.Stake.HIGH)
	clover_odds.note_outcome(CloverSlot.Stake.HIGH, CloverSlot.Outcome.WHIFF)
	var bust_second := clover_odds.get_effective_odds(CloverSlot.Stake.HIGH)
	report.check(
		is_equal_approx(float(bust_next["triple_bust"]), 0.0)
		and is_equal_approx(
			float(bust_second["triple_bust"]), float(bust_normal["triple_bust"]) * 0.5
		)
		and float(bust_next["whiff"]) > float(bust_normal["whiff"])
		and is_equal_approx(
			float(bust_next["path_jackpot"]), float(bust_normal["path_jackpot"])
		),
		"a Bust cannot immediately repeat, and the removed chance becomes Whiff"
	)
	clover_odds.reset_odds()

	# The wager is a physical region of the organism, sized exactly by the notch and
	# made only of ground the run actually holds.
	var owned_cells := prototype.territory_field.collect_owned_cells()
	report.check(owned_cells.size() > 0, "the starting island gives the machine something to wager")
	# Seeded in the middle of the island rather than at its first cell in index order,
	# which is a corner of it: a flood that starts on the rim has nowhere inward to go
	# and would say nothing about how the selection prefers integrated tissue. The
	# centroid of a horseshoe need not be Green, which is exactly the case the selector
	# is meant to handle by seeding at the nearest owned cell instead.
	var seat := Vector2.ZERO
	for cell in owned_cells:
		seat += prototype.territory_field.get_cell_local_position(cell)
	seat /= float(owned_cells.size())
	var wrong_stake_sizes := 0
	var unowned_in_wager := 0
	for stake in range(CloverSlot.Stake.size()):
		var region := selector.select(stake, seat)
		if region.size() != selector.get_target_cell_count(stake, owned_cells.size()):
			wrong_stake_sizes += 1
		for cell in region:
			if not prototype.territory_field.is_owned_cell(cell):
				unowned_in_wager += 1
	var all_in_region := selector.select(CloverSlot.Stake.ALL_IN, seat)
	var repeat_region := selector.select(CloverSlot.Stake.MEDIUM, seat)
	report.check(
		wrong_stake_sizes == 0
		and unowned_in_wager == 0
		and all_in_region.size() == owned_cells.size()
		and repeat_region == selector.select(CloverSlot.Stake.MEDIUM, seat),
		"every notch stakes exactly its share of owned Green, All In takes all of it, and the same board picks the same cells"
	)

	# The flood starts under the player. It is the one thing about the wager the player
	# can aim, and it is easy to break from the outside without breaking the selector:
	# the field sits at an offset inside the scene, so handing it the player's global
	# position instead of its arena position seeds the region a dozen cells away, misses
	# Green entirely, and quietly falls back to the nearest owned cell. Both the selector
	# and the path the interface actually drives are checked, because only the second of
	# those two ever went wrong.
	var player_seat := prototype.player.get_arena_position()
	var player_cell := prototype.territory_field.local_to_cell_index(player_seat)
	var stands_on_green := prototype.territory_field.is_owned_cell(player_cell)
	var player_region := selector.select(CloverSlot.Stake.MEDIUM, player_seat)
	prototype.slot_panel._on_hover_changed(true)
	var previewed := machine.get_preview_cells().duplicate()
	prototype.slot_panel._on_hover_changed(false)
	report.check(
		stands_on_green
		and player_region.has(player_cell)
		and previewed.has(player_cell),
		"the wager is seeded on the cell the player is standing on, through the interface as well as directly"
	)

	# The selection prefers integrated tissue over the exposed rim, so a lost bet costs
	# the organism something it will feel rather than a fringe it was about to lose.
	var wager_exposure := 0.0
	for cell in repeat_region:
		wager_exposure += prototype.territory_field.get_cell_boundary_exposure(cell)
	var board_exposure := 0.0
	for cell in owned_cells:
		board_exposure += prototype.territory_field.get_cell_boundary_exposure(cell)
	report.check(
		wager_exposure / float(maxi(1, repeat_region.size()))
			<= board_exposure / float(maxi(1, owned_cells.size())) + 0.0001,
		"the wager reaches inward rather than skimming the boundary"
	)

	# The region is drawn from a mask at the field's own resolution rather than as one
	# rectangle per cell, so the highlight reconstructs into the same kind of soft
	# border as the ground it sits on. What the layer is holding has to stay the region
	# it was handed, and an empty region has to leave nothing on the arena.
	var layer := prototype.wager_layer
	layer.set_wager_cells(repeat_region, false)
	var drawn := layer.get_wager_cell_count() == repeat_region.size() and layer.visible
	layer.set_wager_cells(repeat_region, true)
	var committed_static := layer.is_committed()
	layer.clear_wager()
	report.check(
		drawn and committed_static and not layer.visible and layer.get_wager_cell_count() == 0,
		"the wager layer draws exactly the region it is given and clears completely"
	)

	# The buy-in is enforced on every stake including All In, so a run with almost
	# nothing left cannot use the machine as a free lottery ticket.
	machine.minimum_buyin_established_fraction = 1.0
	var blocked := not machine.can_spin() and not machine.try_spin(seat)
	machine.minimum_buyin_established_fraction = 0.0
	report.check(blocked and machine.can_spin(), "the lever will not move below the minimum buy-in")

	# The result is decided when the lever goes down and applied when the reels stop. The
	# reveal is drama, not a second roll.
	clover_odds.path_jackpot_chances = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	clover_odds.triple_clover_chances = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	clover_odds.triple_bust_chances = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	machine.reset_machine()
	machine.minimum_buyin_established_fraction = 0.0
	machine.set_stake(CloverSlot.Stake.MEDIUM)
	var resolutions: Array = []
	var on_resolved := func(outcome: int, _path: int, _stake: int) -> void:
		resolutions.append(outcome)
	machine.spin_resolved.connect(on_resolved)
	var green_before := prototype.territory_field.get_player_cell_count()
	var pulled := machine.try_spin(seat)
	var committed := machine.get_committed_cells().duplicate()
	var faces_at_pull := machine.get_last_symbols().duplicate()
	machine.advance(machine.get_reel_stop_seconds(2) * 0.5)
	var applied_mid_spin := not resolutions.is_empty()
	var still_turning := machine.is_revealing() and machine.is_reel_spinning(2)
	var locked_out := not machine.can_spin() and not machine.try_spin(seat)
	machine.advance(machine.get_reveal_duration())
	report.check(
		pulled
		and committed.size() > 0
		and not applied_mid_spin
		and still_turning
		and locked_out
		and not machine.is_revealing()
		and machine.get_last_symbols() == faces_at_pull
		and resolutions.size() == 1
		and resolutions[0] == CloverSlot.Outcome.WHIFF,
		"the wager is frozen at the pull, nothing is applied mid-spin, and the reels land on what was rolled"
	)

	# A lost wager takes the ground it named, and only that ground.
	var still_green := 0
	for cell in committed:
		if prototype.territory_field.is_owned_cell(cell):
			still_green += 1
	report.check(
		still_green == 0
		and prototype.territory_field.get_player_cell_count() < green_before,
		"a whiff drains the committed region to neutral"
	)

	# Left to right, and a matching first pair slows the third reel. The visible reels
	# are authoritative: the slowdown follows what reels one and two show, whether that
	# is heading for a jackpot or for a catastrophe.
	report.check(
		machine.get_reel_stop_seconds(0) < machine.get_reel_stop_seconds(1)
		and machine.get_reel_stop_seconds(1) < machine.get_reel_stop_seconds(2),
		"the reels come to rest one after another rather than all at once"
	)

	# Bust turns the region hostile rather than merely emptying it, which is the whole
	# difference between an expensive spin and a catastrophe.
	clover_odds.triple_bust_chances = PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
	clover_odds.reset_odds()
	machine.reset_machine()
	machine.minimum_buyin_established_fraction = 0.0
	machine.set_stake(CloverSlot.Stake.LOW)
	prototype.territory_field.reset_field()
	var bust_seat := prototype.territory_field.get_cell_local_position(
		prototype.territory_field.collect_owned_cells()[0]
	)
	machine.try_spin(bust_seat)
	var bust_region := machine.get_committed_cells().duplicate()
	var tease_stop := machine.get_reel_stop_seconds(2)
	machine.advance(machine.get_reveal_duration() + 0.01)
	var left_green := 0
	var left_neutral := 0
	for cell in bust_region:
		if prototype.territory_field.is_owned_cell(cell):
			left_green += 1
		elif prototype.territory_field.get_control_at_local(
			prototype.territory_field.get_cell_local_position(cell)
		) >= 0.0:
			left_neutral += 1
	report.check(
		bust_region.size() > 0
		and left_green == 0
		and left_neutral == 0
		and tease_stop > machine.reel_stop_seconds[2],
		"Triple Bust turns the wagered ground hostile, and its matching pair slows the third reel"
	)

	# A jackpot lends the Path its ceiling and takes it back. Nothing is added to the
	# build: the loan must not fill a growth-line slot or unlock an Evolution.
	prototype.progression.reset_progression()
	jackpots.reset_jackpots()
	var owned_before := prototype.progression.get_owned_upgrade_level(
		Progression.UpgradeId.ROOT_MATURATION
	)
	var slots_before := prototype.progression.get_slotted_upgrades().size()
	jackpots.light(Progression.PathId.ROOT)
	var lent := prototype.progression.get_upgrade_level(
		Progression.UpgradeId.ROOT_MATURATION
	)
	var lent_other_path := prototype.progression.get_upgrade_level(
		Progression.UpgradeId.BLOOM_FORCE
	)
	var owns_path := prototype.progression.has_path(Progression.PathId.ROOT)
	var stacked := jackpots.light(Progression.PathId.ROOT)
	jackpots.advance(jackpots.root_seconds + 0.01)
	var still_lit := jackpots.is_active(Progression.PathId.ROOT)
	jackpots.advance(jackpots.root_seconds + 0.01)
	report.check(
		lent == prototype.progression.casino_upgrade_level
		and lent_other_path == 0
		and not owns_path
		and prototype.progression.get_owned_upgrade_level(
			Progression.UpgradeId.ROOT_MATURATION
		) == owned_before
		and prototype.progression.get_slotted_upgrades().size() == slots_before
		and is_equal_approx(stacked, jackpots.root_seconds * 2.0)
		and still_lit
		and not jackpots.is_active(Progression.PathId.ROOT)
		and prototype.progression.get_upgrade_level(
			Progression.UpgradeId.ROOT_MATURATION
		) == owned_before,
		"a jackpot runs the Path at its ceiling for a stacking duration, grants no ownership, and gives it all back"
	)

	# The three new faces must pay real, immediately readable Path events, not merely
	# light a timer whose mechanic remains dormant until some later cadence.
	prototype.progression.reset_progression()
	jackpots.reset_jackpots()
	prototype.territory_field.reset_field()
	prototype.player.reset_player()
	prototype.combat.reset_combat()
	adaptations.reset_adaptations()
	prototype._apply_progression_modifiers()
	var adaptation_jackpot_origin := prototype.player.get_arena_position()
	prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		adaptation_jackpot_origin + Vector2(96.0, 0.0)
	)
	prototype._on_path_jackpot(CloverSlot.Symbol.THISTLE, 1.0)
	var jackpot_thorns := 0
	for thorn in adaptations._thorns:
		if thorn.active:
			jackpot_thorns += 1
	# The jackpot lends Thistle its firing numbers, not extra turrets. The network is
	# one Thistle, so a loan that expires in ten seconds cannot leave a second
	# permanent turret standing behind it.
	var thistle_jackpot_fired := (
		jackpots.is_active(Progression.PathId.THISTLE)
		and adaptations.get_active_thistle_count() == 1
		and jackpot_thorns > 0
	)

	jackpots.reset_jackpots()
	prototype.progression.reset_progression()
	prototype.combat.reset_combat()
	adaptations.reset_adaptations()
	prototype._apply_progression_modifiers()
	var vine_jackpot_enemy := prototype.combat.spawn_enemy(
		EnemyKinds.Role.HUNTER,
		adaptation_jackpot_origin + Vector2(96.0, 0.0)
	)
	var vine_jackpot_health := prototype.combat.get_enemy_health(vine_jackpot_enemy)
	prototype._on_path_jackpot(CloverSlot.Symbol.VINE, 1.0)
	for _vine_jackpot_frame in range(24):
		prototype.combat.simulate_step(1.0 / 60.0)
	var vine_jackpot_fired := (
		jackpots.is_active(Progression.PathId.VINE)
		and prototype.combat.get_enemy_health(vine_jackpot_enemy) < vine_jackpot_health
		and prototype.combat._cane_auto_targets
	)

	jackpots.reset_jackpots()
	prototype.progression.reset_progression()
	prototype.combat.reset_combat()
	adaptations.reset_adaptations()
	prototype._apply_progression_modifiers()
	prototype._on_path_jackpot(CloverSlot.Symbol.FRUIT, 1.0)
	var jackpot_fruit_at_start_speed := true
	for fruit in adaptations._fruits:
		if fruit.active and not fruit.dropped_seed:
			jackpot_fruit_at_start_speed = (
				jackpot_fruit_at_start_speed
				and is_equal_approx(fruit.speed, adaptations.fruit_speed_pixels_per_second)
			)
	# Four Fruit, which is Fruit Set's rank-3 maximum: the jackpot runs the
	# Adaptation at its real ceiling, and that ceiling is three ranks now.
	var fruit_jackpot_fired := (
		jackpots.is_active(Progression.PathId.FRUIT)
		and adaptations.get_active_fruit_count() == 4
		and jackpot_fruit_at_start_speed
	)
	report.check(
		thistle_jackpot_fired and vine_jackpot_fired and fruit_jackpot_fired,
		"Thistle, Vine, and Fruit reel faces fire their real max-rank battlefield events"
	)
	jackpots.reset_jackpots()
	prototype.progression.reset_progression()
	adaptations.reset_adaptations()
	prototype.combat.reset_combat()
	prototype._apply_progression_modifiers()

	# A timed jackpot has to reach the ground. Bramble, Root and Pruning all gate their
	# mechanics on owning the path, and Bramble and Root push their numbers into the field
	# and the combat loop once when the build changes rather than reading them every
	# frame. A jackpot that only raised upgrade levels therefore produced nothing at all:
	# levels nobody was reading, on a mechanic nobody had switched on.
	prototype.progression.reset_progression()
	jackpots.reset_jackpots()
	prototype._apply_progression_modifiers()
	var unowned_slow := prototype.bramble_director.get_slow_fraction()
	var unowned_thorns := prototype.territory_field.is_bramble_enabled()
	var unowned_maturation := prototype.root_director.get_maturation_multiplier()
	# Through the signal, so what is checked is the path the machine actually takes.
	jackpots.light(Progression.PathId.BRAMBLE)
	jackpots.light(Progression.PathId.ROOT)
	var lit_slow := prototype.bramble_director.get_slow_fraction()
	var lit_thorns := prototype.territory_field.is_bramble_enabled()
	var lit_maturation := prototype.root_director.get_maturation_multiplier()
	var lit_pruning := prototype.progression.has_path_active(
		Progression.PathId.PRUNING
	)
	jackpots.light(Progression.PathId.PRUNING)
	var lit_pruning_after := prototype.progression.has_path_active(
		Progression.PathId.PRUNING
	)
	report.check(
		unowned_slow == 0.0
		and not unowned_thorns
		and lit_slow > 0.0
		and lit_thorns
		and lit_maturation > unowned_maturation
		and not lit_pruning
		and lit_pruning_after,
		"a timed jackpot switches the path on and pushes its numbers into the field (slow %.2f, maturation %.2fx)"
			% [lit_slow, lit_maturation]
	)

	# It is a loan and it has to be handed back. A jackpot that never re-pushed the
	# ordinary values on the way out would leave the run permanently maxed on whatever
	# it last won, which is a far worse bug than the one it came from.
	jackpots.advance(
		maxf(jackpots.root_seconds, maxf(jackpots.bramble_seconds, jackpots.pruning_seconds))
		+ 0.01
	)
	report.check(
		prototype.bramble_director.get_slow_fraction() == 0.0
		and not prototype.territory_field.is_bramble_enabled()
		and is_equal_approx(
			prototype.root_director.get_maturation_multiplier(), unowned_maturation
		)
		and not prototype.progression.has_path_active(Progression.PathId.PRUNING),
		"the loan is handed back when the timer runs out"
	)

	# The jackpot stacks on top of what the run already owns rather than raising it to a
	# floor. A player who has already maxed a line bought that ceiling, and handing it
	# back what it owned would be no reward for the path the run is built around.
	prototype.progression.reset_progression()
	jackpots.reset_jackpots()
	prototype.progression.debug_select_paths(
		Progression.PathId.ROOT,
		Progression.PathId.BRAMBLE
	)
	prototype.progression._upgrade_levels[
		Progression.UpgradeId.ROOT_MATURATION
	] = prototype.progression.maximum_upgrade_level
	var owned_rank := prototype.progression.get_owned_upgrade_level(
		Progression.UpgradeId.ROOT_MATURATION
	)
	jackpots.light(Progression.PathId.ROOT)
	var maxed_with_jackpot := prototype.progression.get_upgrade_level(
		Progression.UpgradeId.ROOT_MATURATION
	)
	var unowned_with_jackpot := prototype.progression.get_upgrade_level(
		Progression.UpgradeId.ROOT_LATERAL_ROOTS
	)
	# Ownership is still ownership: a relic that requires the player to have selected a
	# path must keep requiring it, whatever the reels paid.
	var borrowed_ownership := prototype.progression.has_path(
		Progression.PathId.PRUNING
	)
	jackpots.light(Progression.PathId.PRUNING)
	report.check(
		owned_rank == prototype.progression.maximum_upgrade_level
		and maxed_with_jackpot == owned_rank + prototype.progression.casino_upgrade_level
		and unowned_with_jackpot == prototype.progression.casino_upgrade_level
		and not borrowed_ownership
		and not prototype.progression.has_path(Progression.PathId.PRUNING)
		and prototype.progression.get_owned_upgrade_level(
			Progression.UpgradeId.ROOT_MATURATION
		) == owned_rank,
		"a jackpot adds its ceiling to the owned rank (%d becomes %d) and never grants the path"
			% [owned_rank, maxed_with_jackpot]
	)
	jackpots.reset_jackpots()
	prototype.progression.reset_progression()
	prototype._apply_progression_modifiers()

	# A colony core planted inside a wall cannot be damaged from any direction, because
	# every radial source tests the line from its centre to the target and no line reaches
	# into solid rock. The run then cannot be won, since clearing the field is a victory
	# condition. So the placement steps clear of the wall, or does not happen.
	prototype.combat.reset_combat()
	var wall_position := Vector2.ZERO
	var field_for_walls := prototype.territory_field
	for cell in range(field_for_walls.get_cell_count()):
		if field_for_walls.is_claimable_cell(cell):
			continue
		var candidate := field_for_walls.get_cell_local_position(cell)
		if field_for_walls.contains_local_point(candidate):
			wall_position = candidate
			break
	var site := prototype.combat._find_colony_core_site(wall_position)
	var placed_clear := site == Vector2.INF or field_for_walls.is_diamond_claimable_at_local(
		site,
		prototype.combat.colony_core_profile.body_radius_pixels
	)
	# And an ordinary position is left exactly where the Colonizer stood.
	var open_position := field_for_walls.get_cell_local_position(
		field_for_walls.collect_owned_cells()[0]
	)
	var open_site := prototype.combat._find_colony_core_site(open_position)
	report.check(
		wall_position != Vector2.ZERO
		and not field_for_walls.is_diamond_claimable_at_local(
			wall_position,
			prototype.combat.colony_core_profile.body_radius_pixels
		)
		and placed_clear
		and open_site == open_position,
		"a colony core is never planted inside a wall, and an unobstructed one does not move"
	)
	prototype.combat.reset_combat()

	# The relic row carries rarity on the slot itself, so a collection reads at a glance
	# rather than only under the pointer. Colour is never the only signal: the tooltip
	# still names the rarity in words.
	prototype.progression.reset_progression()
	prototype.progression._owned_relics[RelicCatalog.Id.HARD_HUSK] = 1
	prototype.progression._owned_relics[RelicCatalog.Id.DOMINO_GERMINATION] = 1
	prototype.relic_tray.refresh()
	var common_edge := prototype.relic_tray.slots.get_slot_border_color(0)
	var legendary_edge := prototype.relic_tray.slots.get_slot_border_color(1)
	var empty_edge := prototype.relic_tray.slots.get_slot_border_color(2)
	var slot_names_rarity := prototype.relic_tray.slots.get_slot_tooltip(1).contains("LEGENDARY")
	# Hue only: the row keeps its own border alpha so a rarity cannot quietly change how
	# solid a slot looks, only what colour it is.
	var same_hue := func(edge: Color, rarity: int) -> bool:
		var wanted := RelicCatalog.get_rarity_color(rarity)
		return (
			is_equal_approx(edge.r, wanted.r)
			and is_equal_approx(edge.g, wanted.g)
			and is_equal_approx(edge.b, wanted.b)
		)
	report.check(
		same_hue.call(common_edge, RelicCatalog.Rarity.COMMON)
		and same_hue.call(legendary_edge, RelicCatalog.Rarity.LEGENDARY)
		and not common_edge.is_equal_approx(legendary_edge)
		and not legendary_edge.is_equal_approx(empty_edge)
		and slot_names_rarity,
		"a relic slot is coloured by its rarity and still names it in words"
	)
	prototype.progression.reset_progression()
	prototype.relic_tray.refresh()

	# All In whiff: everything goes, the ordinary extinction countdown is held off, and
	# the run gets exactly three seconds to put something back.
	prototype.territory_field.reset_field()
	grace.reset_grace()
	# Measured against the board that actually exists rather than against the shipped
	# five percent, so the check is about the rule and not about how big the starting
	# island happens to be this build.
	var authored_threshold := grace.recovery_threshold
	grace.recovery_threshold = grace.get_recovered_fraction() * 0.5
	grace.begin()
	var suppressing := grace.is_suppressing_defeat()
	var started_at := grace.get_remaining_seconds()
	var failures: Array = []
	var recoveries: Array = []
	var on_failed := func() -> void:
		failures.append(true)
	var on_recovered := func(_left: float) -> void:
		recoveries.append(true)
	grace.grace_failed.connect(on_failed)
	grace.grace_recovered.connect(on_recovered)
	# Recovery first: the board still holds its starting island, which is above the
	# threshold, so the very first tick has to read as a rescue.
	grace.advance(0.1)
	var rescued := recoveries.size() == 1 and not grace.is_active()
	prototype.territory_field.neutralize_all_owned()
	grace.recovery_threshold = authored_threshold
	grace.begin()
	grace.advance(grace.grace_duration + 0.01)
	grace.grace_failed.disconnect(on_failed)
	grace.grace_recovered.disconnect(on_recovered)
	report.check(
		suppressing
		and is_equal_approx(started_at, grace.grace_duration)
		and rescued
		and failures.size() == 1
		and not grace.is_suppressing_defeat(),
		"the All In grace period suspends defeat, ends the moment the board is rebuilt, and ends the run when it is not"
	)

	machine.spin_resolved.disconnect(on_resolved)
	clover_odds.path_jackpot_chances = PackedFloat32Array([0.095, 0.21, 0.38, 0.55])
	clover_odds.triple_clover_chances = PackedFloat32Array([0.005, 0.01, 0.02, 0.05])
	clover_odds.triple_bust_chances = PackedFloat32Array([0.005, 0.02, 0.07, 0.15])
	clover_odds.reset_odds()
	jackpots.reset_jackpots()
	grace.reset_grace()
	machine.reset_machine()
	prototype.territory_field.reset_field()
	prototype.progression.reset_progression()
