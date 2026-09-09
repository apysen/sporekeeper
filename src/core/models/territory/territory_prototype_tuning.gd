class_name TerritoryPrototypeTuning
extends Resource

@export_category("Field")
## Authoritative simulation resolution measured in territory cells; changing it reallocates buffers.
@export var field_size := Vector2i(112, 63)
## Playable field dimensions in arena pixels, excluding the surrounding UI.
@export var arena_size := Vector2(960.0, 540.0)
## Target number of deterministic territory simulation steps per second.
@export_range(10.0, 60.0, 1.0) var simulation_hz := 30.0
## Target number of territory texture uploads per second.
@export_range(10.0, 60.0, 1.0) var render_hz := 30.0
## Maximum fixed simulation steps retained when a rendered frame falls behind.
@export_range(1, 8, 1) var max_catch_up_steps := 3
## Absolute control value required to classify a cell as Green or hostile instead of neutral.
@export_range(0.01, 0.49, 0.01) var ownership_threshold := 0.18

@export_category("Starting Layout")
## Normalized arena position of the player's starting Green island.
@export var starting_plant_center := Vector2(0.235, 0.535)
## Normalized half-extents of the starting Green island. Small values start the run
## on a foothold rather than on half the arena.
@export var starting_plant_radius := Vector2(0.085, 0.115)
## Hostile ground wrapped around the starting island, measured in multiples of that
## island's own radius. Zero starts the run with open neutral ground beside it;
## above zero the run opens besieged on every side.
@export_range(0.0, 4.0, 0.05) var starting_hostile_ring := 1.10
## Normalized arena position of the hostile mass the starting island faces.
@export var starting_hostile_center := Vector2(0.765, 0.515)
## Normalized half-extents of that hostile mass.
@export var starting_hostile_radius := Vector2(0.285, 0.405)
## Maturity given to every owned cell of the authored starting island. The opening
## foothold is home rather than ground the run just claimed, so it is established at
## full strength instead of ramping down toward a Fresh rim. This is authored initial
## state and deliberately not a relationship between control magnitude and maturity:
## Green claimed after the run begins still starts Fresh.
@export_range(0.0, 1.0, 0.01) var starting_green_maturity := 1.0
## Maturity given to the authored starting hostile mass. Zero by default so the
## opening Rot does not begin hardened by maturity_resistance_bonus on top of
## whatever resistance hostile ground already carries. Raise it only to entrench the
## opening siege on purpose.
@export_range(0.0, 1.0, 0.01) var starting_rot_maturity := 0.0

@export_category("Territory Motion")
## Per-second strength with which control moves toward the average of neighboring cells.
@export_range(0.0, 5.0, 0.01) var diffusion_rate := 1.45
## Per-second strength that pushes non-neutral control toward fully owned territory.
@export_range(0.0, 5.0, 0.01) var sharpening_rate := 0.85
## Per-second frontier growth supplied by nearby owned territory without an ability.
@export_range(0.0, 2.0, 0.01) var natural_spread_rate := 0.16
## Fraction of stored pressure used to transport territory control during each step.
@export_range(0.0, 1.0, 0.01) var pressure_advection := 0.78
## Pressure retained after each simulation step; lower values make impulses fade faster.
@export_range(0.0, 1.0, 0.01) var pressure_damping := 0.56
## Maximum stored pressure magnitude measured in territory cells.
@export_range(0.1, 8.0, 0.1) var max_pressure_cells := 4.0

@export_category("Maturity")
## Base 0-to-1 maturity gained per second by territory that keeps the same owner.
@export_range(0.0, 1.0, 0.001) var maturation_per_second := 0.028
## Maturity removed per second while a cell is neutral.
@export_range(0.0, 1.0, 0.001) var neutral_maturity_decay_per_second := 0.20
## Maximum extra resistance supplied at full maturity against motion and erosion.
@export_range(0.0, 8.0, 0.1) var maturity_resistance_bonus := 2.4
## Minimum 0-to-1 maturity used to classify Green as Mature for metrics and Biomass.
@export_range(0.1, 1.0, 0.01) var mature_threshold := 0.66
## Minimum 0-to-1 maturity at which established ground counts as deeply rooted. This
## is the top of the four root stages the Root Metabolism doc asks a run to be able
## to read off the battlefield; the three boundaries below it are already implied by
## mature_threshold, so only the last one needs authoring.
@export_range(0.1, 1.0, 0.01) var deep_root_threshold := 0.88
## Seconds of unbroken Mature ownership after which Age-based effects reach full strength.
## Age is explicit field data; it is never inferred from a rendered texture.
@export_range(1.0, 600.0, 1.0) var age_reference_seconds := 45.0
## Control per second recovered by damaged Plant territory that still holds its ground.
## Zero by default; the Root path's Regeneration line raises it.
@export_range(0.0, 2.0, 0.005) var regeneration_per_second := 0.0

@export_category("Bloom")
## Base Bloom territory radius measured in simulation cells before Expansion upgrades.
@export_range(1.0, 40.0, 0.5) var bloom_radius_cells := 13.5
## Base positive control mass stamped by a Bloom at its center before falloff.
@export_range(0.0, 4.0, 0.05) var bloom_mass := 1.90
## Base outward pressure impulse applied by a Bloom, measured in cells.
@export_range(0.0, 8.0, 0.1) var bloom_pressure_cells := 3.4
## Bloom mass multiplier used only while converting negative hostile control.
## Above 1.0 a Bloom drives through a contested border as readily as open ground.
@export_range(0.0, 6.0, 0.05) var bloom_hostile_conversion_factor := 1.80
## Nearby Plant control at which a Bloom's mass reaches full strength. A Bloom
## displaces territory that already exists, so ground with no Plant beside it
## receives nothing and only a Seed can colonise it.
@export_range(0.05, 1.0, 0.05) var bloom_support_reference := 0.45
## How far in cells a Bloom looks back toward its own origin for the Plant mass it
## is displacing. Larger values let one burst drive the frontier further outward.
@export_range(0.0, 12.0, 0.5) var bloom_support_reach_cells := 6.5

@export_category("Seed")
## Default seconds a Seed visibly charges before germinating.
@export_range(0.1, 5.0, 0.05) var seed_charge_seconds := 1.35
## Base Seed territory radius measured in simulation cells before Expansion upgrades.
@export_range(1.0, 30.0, 0.5) var seed_radius_cells := 9.5
## Base positive control mass stamped by a germinating Seed at its center before falloff.
@export_range(0.0, 4.0, 0.05) var seed_mass := 1.12
## Base outward pressure impulse applied by a germinating Seed, measured in cells.
@export_range(0.0, 4.0, 0.05) var seed_pressure_cells := 0.55
## Seed mass multiplier used only while converting negative hostile control.
@export_range(0.0, 6.0, 0.05) var seed_hostile_conversion_factor := 3.2

@export_category("Grazer")
## Phase A debug-Grazer speed in pixels per second; Sporekeeper speed lives on its enemy profile.
@export_range(20.0, 600.0, 5.0) var grazer_speed_pixels_per_second := 205.0
## Base radius in cells for all queued enemy erosion actions in Phase A and Sporekeeper.
@export_range(1.0, 12.0, 0.25) var grazer_radius_cells := 3.75
## Base Green control removed at an erosion stamp's center before falloff and resistance.
@export_range(0.0, 2.0, 0.05) var grazer_erosion_per_stamp := 1.65
## Phase A debug-Grazer stamp cadence; Sporekeeper cadence lives on each enemy profile.
@export_range(0.01, 0.2, 0.01) var grazer_stamp_interval := 0.045

@export_category("Fragments")
## Seconds between connected-region scans of player-owned Green territory.
@export_range(0.1, 2.0, 0.05) var topology_interval_seconds := 0.50
## Regions with fewer cells than this value are classified as small fragments.
@export_range(1, 500, 1) var small_fragment_cell_limit := 28
## Surface energy of a border, in the critical-radius test that decides whether an
## isolated patch of Green survives. This is the doc's gamma: how much it costs to
## be a border rather than an interior, scaled by the ecosystem's own Cohesion. A
## cohesive organism holds its main body harder and throws fewer surviving
## satellites, which is a genuine trade rather than two upgrades that both say
## "better".
@export_range(0.1, 40.0, 0.1) var nucleation_surface_tension := 3.4
## Bulk driving force of being Green at all: the doc's delta-g. Raised by the
## ground's own maturity, by Mass, and by friendly Green sitting right beside the
## patch, and it is what the surface term is weighed against.
@export_range(0.05, 20.0, 0.05) var nucleation_driving_force := 1.9
## How much a patch's own maturity contributes to that driving force. Below one so
## fresh ground still has some claim on surviving rather than none at all.
@export_range(0.0, 1.0, 0.01) var nucleation_maturity_share := 0.65
## What being surrounded by friendly Green is worth. A satellite that lands beside
## the organism survives at a size that would dissolve out on open ground, which is
## the whole behaviour this replaces a flat timer with.
@export_range(0.0, 6.0, 0.05) var nucleation_support_bonus := 1.8
## Green control removed per second from cells belonging to a small fragment.
@export_range(0.0, 1.0, 0.01) var small_fragment_decay_per_second := 0.11

@export_category("Metrics")
## Seconds between published territory-percentage and maturity metric updates.
@export_range(0.05, 1.0, 0.05) var metrics_interval_seconds := 0.20

@export_category("Bramble")
## Seconds of undisturbed frontier contact needed for fresh thorns to reach full strength.
@export_range(0.5, 15.0, 0.1) var bramble_development_seconds := 4.0
## Extra development speed supplied at full maturity; 1.0 lets Mature Green establish twice as fast.
@export_range(0.0, 4.0, 0.05) var bramble_maturity_growth_bonus := 1.00
## Development lost per second by a cell that is no longer a Green frontier cell.
@export_range(0.0, 8.0, 0.05) var bramble_decay_per_second := 1.20
## Development removed per unit of applied erosion or hostile conversion at a frontier cell.
@export_range(0.0, 12.0, 0.05) var bramble_disturbance_per_erosion := 0.90
## Largest development drop a single erosion or conversion stamp may cause, so thorns
## degrade through visible bands instead of snapping to zero.
@export_range(0.01, 1.0, 0.01) var bramble_disturbance_maximum_step := 0.30
## Bramble power stored by each cell of owned Green simply for being thorned ground.
## Bramble covers territory rather than a frontier, so a harvesting mechanic draws
## most of its yield from area and only the remainder from frontier development.
@export_range(0.0, 4.0, 0.01) var bramble_territory_power := 0.30
## Fraction of a harvesting Bloom's radius whose thorns are consumed rather than buried.
@export_range(0.1, 1.0, 0.05) var bramble_harvest_inner_fraction := 0.85
## Development multiplier applied while a section is under active attack.
@export_range(1.0, 6.0, 0.05) var bramble_attack_growth_multiplier := 2.00
## Seconds a disturbed section counts as under attack for accelerated regrowth.
@export_range(0.0, 20.0, 0.1) var bramble_attack_growth_seconds := 3.0
## Development that fully mature Green starts with the moment it becomes frontier.
@export_range(0.0, 1.0, 0.01) var bramble_mature_starting_development := 0.35
## Extra erosion resistance supplied by thorn development alone, before any upgrade.
@export_range(0.0, 8.0, 0.05) var bramble_development_erosion_resistance := 1.50
## Fraction of full thorn strength supplied by freshly exposed, undeveloped frontier.
@export_range(0.0, 0.5, 0.01) var bramble_minimum_strength := 0.10
## Development at which Bramble counts as Established and may deal its crossing hit.
@export_range(0.1, 1.0, 0.01) var bramble_established_development := 0.65

@export_category("Splatter")
## Meaningful field splats produced by one Bloom eruption, excluding the central
## splat. Cosmetic microdroplets are presentation and never reach the field.
@export_range(0, 24, 1) var bloom_glob_count := 5
## Satellite splashes thrown beyond the glob ring, which may land as disconnected Green.
@export_range(0, 16, 1) var bloom_satellite_count := 4
## Directional streaks drawn along the splatter's dominant escape directions.
@export_range(0, 12, 1) var bloom_streak_count := 2
## Glob radius as a fraction of the central splat's radius.
@export_range(0.05, 1.0, 0.01) var bloom_glob_radius_fraction := 0.34
## Satellite radius as a fraction of the central splat's radius.
@export_range(0.02, 1.0, 0.01) var bloom_satellite_radius_fraction := 0.18
## How far Bloom Force throws globs, measured in multiples of the central radius.
@export_range(0.5, 6.0, 0.05) var bloom_glob_throw_multiplier := 1.30
## How far Bloom Force throws satellites, measured in multiples of the central radius.
@export_range(0.5, 10.0, 0.05) var bloom_satellite_throw_multiplier := 2.35
## Fraction of the central splat's Mass carried by each glob.
@export_range(0.0, 1.0, 0.01) var bloom_glob_mass_fraction := 0.55
## Fraction of the central splat's Mass carried by each satellite. Low values make
## isolated patches fragile, so only a high-Mass build keeps them alive.
@export_range(0.0, 1.0, 0.01) var bloom_satellite_mass_fraction := 0.30
## Cosmetic droplets drawn per Bloom. These are particles, not field objects.
@export_range(0, 200, 1) var bloom_microdroplet_count := 56

@export_category("Metabolism")
## How much of a stamp one cell of obstruction takes out of it. Growth reaching
## past the corner of a wall is dimmed rather than deleted, so a ridge on a rock
## costs what the ridge is worth instead of shadowing everything behind it.
@export_range(0.0, 1.0, 0.01) var obstruction_falloff_per_cell := 0.45
@export_range(16, 4096, 16) var overgrow_frontier_sample_limit := 640
## Frontier cells one unit of injected Mass is worth reaching. An injection used to
## divide its budget across every sampled cell, so a large release landed as a film
## too thin to flip any ground: doubling the budget doubled the cells it was spread
## over and changed nothing per cell. Scaling the sample with the budget instead
## keeps each cell's share worth having, and a bigger release reaches further along
## the border rather than pushing the same cells harder.
@export_range(0.05, 40.0, 0.05) var overgrow_cells_per_mass := 1.20
## Plant Mass injected at a frontier cell per unit of Overgrow Mass budget.
@export_range(0.0, 1.0, 0.001) var overgrow_mass_per_budget := 0.055
## Outward pressure in cells injected at a frontier cell per unit of Pressure budget.
@export_range(0.0, 1.0, 0.001) var overgrow_pressure_per_budget := 0.085
## Control and maturity restored at damaged ground per unit of Cohesion budget.
@export_range(0.0, 1.0, 0.001) var overgrow_repair_per_budget := 0.070
