## Ecosystem Metabolism: the one system the run never clicks on.
##
## Nothing here is bought. The three axes develop out of the Biomass the run has
## earned across its whole life, along the same cost curve the old shop charged, so
## the checks are about the ladder rather than about a transaction - spending must
## never take development back, and the build the run is playing must lean it.
class_name SmokeEconomy
extends RefCounted


static func run(report: SmokeReport, prototype: RunRoot) -> void:
	var adaptations := prototype.adaptation_director

	# Ecosystem Metabolism. Nothing here is bought and nothing here is clicked: the
	# three axes develop out of the Biomass the run has earned across its whole life,
	# along the same cost curve the old shop charged.
	var metabolism := prototype.metabolism
	metabolism.reset_metabolism()
	prototype.progression.reset_progression()
	var mass_level_before := metabolism.get_level(Metabolism.SystemId.PHOTOSYNTHESIS)
	for _idle_step in range(300):
		metabolism.advance(1.0 / 30.0)
	report.check(
		metabolism.get_level(Metabolism.SystemId.PHOTOSYNTHESIS) == mass_level_before,
		"the run clock alone never moves a physical axis"
	)

	# Earning is what develops it, and the rank arrives where the cost curve says it
	# should rather than at some second opinion about the price.
	metabolism.reset_metabolism()
	prototype.progression.reset_progression()
	var mass_id := Metabolism.SystemId.PHOTOSYNTHESIS
	var second_rank_cost := metabolism.get_cumulative_rank_cost(2)
	var mass_share := metabolism.get_axis_share(mass_id)
	prototype.progression.add_biomass(second_rank_cost / mass_share * 0.96)
	var short_of_the_rank := metabolism.get_level(mass_id)
	prototype.progression.add_biomass(second_rank_cost / mass_share * 0.08)
	report.check(
		short_of_the_rank == 1 and metabolism.get_level(mass_id) == 2,
		"an axis reaches its next rank when lifetime earnings pay the curve price"
	)

	# Spending must never take development back. This is the whole reason lifetime
	# earnings are tracked apart from the balance: a Clover spin or an Overgrow can
	# empty the run pocket, and the organism it has already become stays.
	var rank_before_spending := metabolism.get_level(mass_id)
	prototype.progression.spend_biomass(1000000.0)
	report.check(
		is_equal_approx(prototype.progression.biomass, 0.0)
		and metabolism.get_level(mass_id) == rank_before_spending,
		"spending the reserve to nothing never costs the run a rank it has developed"
	)

	# The build leans the ladder. A run down Bramble develops Hold out of the same
	# earnings a run down Bloom spends on Push, without either being asked to allocate.
	metabolism.reset_metabolism()
	prototype.progression.reset_progression()
	for _unlock_step in range(int(metabolism.cohesion_unlock_seconds * 30.0) + 60):
		metabolism.advance(1.0 / 30.0)
	var even_hold_share := metabolism.get_axis_share(Metabolism.SystemId.CAMBIUM)
	prototype.progression.debug_select_paths(
		Progression.PathId.BRAMBLE,
		Progression.PathId.SPORE
	)
	var leaned_hold_share := metabolism.get_axis_share(Metabolism.SystemId.CAMBIUM)
	report.check(
		leaned_hold_share > even_hold_share,
		"the Paths a run is built from lean the ladder toward the axis they feed "
			+ "(%.2f against %.2f)" % [leaned_hold_share, even_hold_share]
	)

	# The economy unfolds on the run clock: Mass from the first second, the other two
	# while the run is being played, so it opens simple and gains capabilities.
	metabolism.reset_metabolism()
	prototype.progression.reset_progression()
	var push_locked_at_the_start := not metabolism.is_system_unlocked(
		Metabolism.SystemId.MERISTEM
	)
	for _push_step in range(int(metabolism.pressure_unlock_seconds * 30.0) + 30):
		metabolism.advance(1.0 / 30.0)
	report.check(
		metabolism.is_system_unlocked(Metabolism.SystemId.PHOTOSYNTHESIS)
		and push_locked_at_the_start
		and metabolism.is_system_unlocked(Metabolism.SystemId.MERISTEM),
		"Mass is available from the start and Push arrives on the run clock"
	)
	metabolism.reset_metabolism()
	prototype.progression.reset_progression()
