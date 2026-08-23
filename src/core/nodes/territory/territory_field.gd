class_name TerritoryField
extends Node2D

const TERRITORY_SHADER := preload("res://assets/shaders/territory_field.gdshader")

signal metrics_changed(
	player_percent: float,
	hostile_percent: float,
	neutral_percent: float,
	mature_player_percent: float,
	fragment_count: int
)
signal simulation_reset

enum DebugView {
	TERRITORY,
	MATURITY,
	CONTROL,
}

class TerritoryCommand:
	enum Kind {
		BLOOM,
		SEED,
		SPLAT,
		EROSION,
		HOSTILE_GROWTH,
		MATURITY_SUPPRESSION,
	}

	var kind: int
	var cell_position := Vector2.ZERO
	var radius_cells := 0.0
	var mass := 0.0
	var pressure_cells := 0.0
	var hostile_conversion_factor := 1.0
	var erosion := 0.0
	var hostile_mass := 0.0
	var maturity_suppression := 0.0
	## Which way the material was travelling when it landed, in cell space, and how
	## far the impact drags it out along that line. A splat that arrives with speed
	## is not a disc: it lands long, keeps going the way it was thrown, and pushes
	## the ground it claims downrange rather than evenly in every direction.
	var impact_direction := Vector2.ZERO
	var elongation := 1.0
	## Maturity a landing knocks out of established hostile ground before it tries
	## to claim it. Growing into old territory is rightly hard; hitting it is not.
	var impact_break := 0.0
	## Highest Maturity the ground this command claims is allowed to keep. Thrown
	## paint sets this to zero: it wins the cell but leaves nothing rooted there,
	## so the front around it can take it back.
	var maturity_ceiling := -1.0
	## Maturity this command adds to ground the player already holds. Material
	## landing on established growth thickens it rather than resetting it.
	var maturity_reinforcement := 0.0

class BrambleHarvest:
	## Total Bramble power drawn from the ground: every covered cell contributes its
	## territory power, and frontier cells add whatever thorn development they held.
	var amount := 0.0
	## Power-weighted mean maturity of the ground the Bramble covered.
	var average_maturity := 0.0
	## Number of Bramble-covered cells the harvest drew from.
	var cell_count := 0

class PruneHarvest:
	## Cells the cycle actually took.
	var cell_count := 0
	## Total Plant control removed, which is the mass a cycle has to work with.
	var mass := 0.0
	## How much of that came from Mature ground, which Root's pairing pays out on.
	var mature_cell_count := 0
	## Thorn development taken along with it, which Bramble's pairing pays out on.
	var bramble_development := 0.0
	## Sampled positions of the cut ground, for the Cuttings and the visuals.
	var positions := PackedVector2Array()

## Shared resource containing field resolution, fixed-step motion, effect, and metric tuning.
class OvergrowResult:
	## Frontier cells the injection actually reached.
	var cell_count := 0
	## Plant Mass added to the field.
	var mass_applied := 0.0
	## Outward pressure in cells added to the field.
	var pressure_applied := 0.0
	## Control and maturity restored at damaged ground.
	var repair_applied := 0.0


@export var tuning: TerritoryPrototypeTuning

var simulation_paused := false
var debug_view := DebugView.TERRITORY

var _bramble_enabled := false
var _bramble_resistance_multiplier := 1.0
var _mature_resistance_multiplier := 1.0
var _cohesion_multiplier := 1.0
var _regrowth_memory_seconds := 0.0
var _regrowth_memory_per_second := 0.0
var _pruned_regrowth_per_second := 0.0
var _old_growth_enabled := false

var _width := 0
var _height := 0
var _cell_count := 0
var _fixed_delta := 0.0
var _simulation_accumulator := 0.0
var _render_accumulator := 0.0
var _metrics_accumulator := 0.0
var _topology_accumulator := 0.0
var _simulation_turn_when_both_due := true

var _control := PackedFloat32Array()
var _next_control := PackedFloat32Array()
var _maturity := PackedFloat32Array()
var _next_maturity := PackedFloat32Array()
var _pressure_x := PackedFloat32Array()
var _next_pressure_x := PackedFloat32Array()
var _pressure_y := PackedFloat32Array()
var _next_pressure_y := PackedFloat32Array()
var _claimable_mask := PackedByteArray()
var _player_frontier_mask := PackedByteArray()
var _bramble_development := PackedFloat32Array()
var _bramble_alert := PackedFloat32Array()
var _territory_age := PackedFloat32Array()
## Seconds of accelerated reclamation left on ground a Pruning Cycle cut away.
var _pruned_ground := PackedFloat32Array()
var _lost_memory := PackedFloat32Array()
var _topology_labels := PackedInt32Array()
var _topology_queue := PackedInt32Array()
var _pixel_bytes := PackedByteArray()
var _commands: Array[TerritoryCommand] = []

var _field_image: Image
var _field_texture: ImageTexture
var _field_material: ShaderMaterial

var _player_percent := 0.0
var _hostile_percent := 0.0
var _neutral_percent := 100.0
var _mature_player_percent := 0.0
var _fragment_count := 0
var _small_fragment_count := 0

var _average_step_ms := 0.0
var _peak_step_ms := 0.0
var _average_render_ms := 0.0
var _peak_render_ms := 0.0
var _measured_steps := 0
var _measured_renders := 0


func _ready() -> void:
	assert(tuning != null, "TerritoryField requires TerritoryPrototypeTuning")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_configure_material()
	_configure_buffers()
	reset_field()


func _process(delta: float) -> void:
	if not simulation_paused:
		_simulation_accumulator += delta
		var maximum_backlog := _fixed_delta * float(tuning.max_catch_up_steps)
		_simulation_accumulator = minf(_simulation_accumulator, maximum_backlog)

	_render_accumulator += delta
	var render_delta := 1.0 / tuning.render_hz
	var simulation_due := not simulation_paused and _simulation_accumulator >= _fixed_delta
	var render_due := _render_accumulator >= render_delta

	# Simulation and texture upload each fit a 60 fps frame independently. When both
	# are due, alternate them across frames instead of stacking both pieces of work.
	if simulation_due and render_due:
		if _simulation_turn_when_both_due:
			step_simulation()
			_simulation_accumulator -= _fixed_delta
		else:
			refresh_visuals_now()
			_render_accumulator -= render_delta
		_simulation_turn_when_both_due = not _simulation_turn_when_both_due
	elif simulation_due:
		step_simulation()
		_simulation_accumulator -= _fixed_delta
		_simulation_turn_when_both_due = false
	elif render_due:
		refresh_visuals_now()
		_render_accumulator -= render_delta
		_simulation_turn_when_both_due = true


func _draw() -> void:
	if _field_texture == null or tuning == null:
		return
	draw_texture_rect(_field_texture, Rect2(Vector2.ZERO, tuning.arena_size), false)


func reset_field() -> void:
	if _cell_count == 0:
		_configure_buffers()

	_commands.clear()
	_control.fill(0.0)
	_next_control.fill(0.0)
	_maturity.fill(0.0)
	_next_maturity.fill(0.0)
	_pressure_x.fill(0.0)
	_next_pressure_x.fill(0.0)
	_pressure_y.fill(0.0)
	_next_pressure_y.fill(0.0)
	_claimable_mask.fill(1)
	_player_frontier_mask.fill(0)
	_bramble_development.fill(0.0)
	_bramble_alert.fill(0.0)
	_territory_age.fill(0.0)
	_pruned_ground.fill(0.0)
	_lost_memory.fill(0.0)

	for y in range(_height):
		var normalized_y := float(y) / float(_height - 1)
		for x in range(_width):
			var normalized_x := float(x) / float(_width - 1)
			var index := y * _width + x
			var boundary_noise := _boundary_noise(x, y)

			var blocked := _is_border_cell(x, y)
			blocked = blocked or _is_rock_cell(normalized_x, normalized_y)
			if blocked:
				_claimable_mask[index] = 0
				continue

			var plant_offset := Vector2(
				(normalized_x - tuning.starting_plant_center.x)
					/ maxf(0.001, tuning.starting_plant_radius.x),
				(normalized_y - tuning.starting_plant_center.y)
					/ maxf(0.001, tuning.starting_plant_radius.y)
			)
			var hostile_offset := Vector2(
				(normalized_x - tuning.starting_hostile_center.x)
					/ maxf(0.001, tuning.starting_hostile_radius.x),
				(normalized_y - tuning.starting_hostile_center.y)
					/ maxf(0.001, tuning.starting_hostile_radius.y)
			)
			var plant_distance := plant_offset.length()
			var plant_shape := 1.0 - plant_distance + boundary_noise
			var hostile_shape := 1.0 - hostile_offset.length() - boundary_noise * 0.85
			if tuning.starting_hostile_ring > 0.0:
				# Hostile ground wraps the starting island, so the run opens under
				# siege from every side instead of facing one open frontier. The ring
				# is measured in the island's own radii, which keeps it proportional
				# however small the foothold is authored to be.
				var ring_depth := (
					(plant_distance - 1.0) / tuning.starting_hostile_ring
				)
				if ring_depth > 0.0 and ring_depth < 1.0:
					hostile_shape = maxf(
						hostile_shape,
						1.0 - ring_depth - boundary_noise * 0.85
					)
			var control := 0.0

			if plant_shape > 0.0 and plant_shape >= hostile_shape:
				control = clampf(0.20 + plant_shape * 0.95, 0.0, 1.0)
			elif hostile_shape > 0.0:
				control = -clampf(0.20 + hostile_shape * 0.95, 0.0, 1.0)

			# A small Plant island inside hostile territory exercises enclosed growth.
			var pocket_distance := Vector2(
				(normalized_x - 0.775) / 0.060,
				(normalized_y - 0.255) / 0.075
			).length()
			if pocket_distance < 1.0:
				control = maxf(control, 0.30 + (1.0 - pocket_distance) * 0.52)

			# A deliberately weak hostile basin makes conversion behavior easy to compare.
			var weak_distance := Vector2(
				(normalized_x - 0.690) / 0.090,
				(normalized_y - 0.765) / 0.085
			).length()
			if weak_distance < 1.0 and control < 0.0:
				control *= lerpf(0.42, 1.0, weak_distance)

			_control[index] = control
			if absf(control) > tuning.ownership_threshold:
				_maturity[index] = clampf((absf(control) - 0.30) * 0.95, 0.04, 0.78)

	_rebuild_player_frontier_mask()
	_simulation_accumulator = 0.0
	_render_accumulator = 0.0
	_simulation_turn_when_both_due = true
	_metrics_accumulator = 0.0
	_topology_accumulator = 0.0
	analyze_topology_now()
	recalculate_metrics_now()
	refresh_visuals_now()
	simulation_reset.emit()


func step_simulation() -> void:
	var started_at := Time.get_ticks_usec()
	_apply_pending_commands()

	# Bramble development runs inside the hot per-cell loop, so its tuning is read
	# once per step and the whole layer is skipped while the path is unselected.
	var bramble_active := _bramble_enabled
	var bramble_growth_step := 1.0
	if tuning.bramble_development_seconds > 0.0:
		bramble_growth_step = _fixed_delta / tuning.bramble_development_seconds
	var bramble_maturity_bonus := tuning.bramble_maturity_growth_bonus
	var bramble_decay_step := tuning.bramble_decay_per_second * _fixed_delta
	var bramble_attack_multiplier := tuning.bramble_attack_growth_multiplier
	var bramble_mature_start := tuning.bramble_mature_starting_development
	var step_regeneration := tuning.regeneration_per_second * _fixed_delta
	var step_pruned_regrowth := _pruned_regrowth_per_second * _fixed_delta
	var step_mature_threshold := tuning.mature_threshold
	var regrowth_active := _regrowth_memory_seconds > 0.0
	var step_regrowth_memory := _regrowth_memory_per_second * _fixed_delta
	var step_age_reference := maxf(0.001, tuning.age_reference_seconds)


	# The fixed step touches every cell, so its tuning is read once per step
	# rather than through a Resource property lookup inside the inner loop.
	var step_ownership_threshold := tuning.ownership_threshold
	var step_max_pressure_cells := tuning.max_pressure_cells
	var step_sharpening_rate := tuning.sharpening_rate
	var step_pressure_damping := tuning.pressure_damping
	var step_pressure_advection := tuning.pressure_advection
	var step_neutral_maturity_decay_per_second := tuning.neutral_maturity_decay_per_second
	var step_natural_spread_rate := tuning.natural_spread_rate
	var step_maturity_resistance_bonus := tuning.maturity_resistance_bonus
	var step_maturation_per_second := tuning.maturation_per_second
	var step_diffusion_rate := tuning.diffusion_rate
	for y in range(_height):
		for x in range(_width):
			var index := y * _width + x
			if _claimable_mask[index] == 0:
				_player_frontier_mask[index] = 0
				_bramble_development[index] = 0.0
				_bramble_alert[index] = 0.0
				_territory_age[index] = 0.0
				_pruned_ground[index] = 0.0
				_lost_memory[index] = 0.0
				_next_control[index] = 0.0
				_next_maturity[index] = 0.0
				_next_pressure_x[index] = 0.0
				_next_pressure_y[index] = 0.0
				continue

			var control := _control[index]
			var maturity := _maturity[index]
			var resistance := 1.0 + maturity * step_maturity_resistance_bonus

			var pressure_x := _pressure_x[index]
			var pressure_y := _pressure_y[index]
			var pressure_length := minf(
				sqrt(pressure_x * pressure_x + pressure_y * pressure_y),
				step_max_pressure_cells
			)
			var source_x := clampi(int(round(float(x) - pressure_x)), 0, _width - 1)
			var source_y := clampi(int(round(float(y) - pressure_y)), 0, _height - 1)
			var source_index := source_y * _width + source_x
			var source_control := control
			if _claimable_mask[source_index] != 0:
				source_control = _control[source_index]
			var advection_weight := 0.0
			if step_max_pressure_cells > 0.0:
				advection_weight = (
					pressure_length / step_max_pressure_cells
					* step_pressure_advection
					/ resistance
				)
			var transported := lerpf(control, source_control, clampf(advection_weight, 0.0, 0.92))

			var left_index := index - 1 if x > 0 else index
			var right_index := index + 1 if x < _width - 1 else index
			var up_index := index - _width if y > 0 else index
			var down_index := index + _width if y < _height - 1 else index
			var is_player_frontier := false
			if control > step_ownership_threshold:
				is_player_frontier = (
					(_claimable_mask[left_index] != 0 and _control[left_index] <= step_ownership_threshold)
					or (_claimable_mask[right_index] != 0 and _control[right_index] <= step_ownership_threshold)
					or (_claimable_mask[up_index] != 0 and _control[up_index] <= step_ownership_threshold)
					or (_claimable_mask[down_index] != 0 and _control[down_index] <= step_ownership_threshold)
				)
			_player_frontier_mask[index] = int(is_player_frontier)
			if bramble_active:
				var alert := _bramble_alert[index]
				if alert > 0.0:
					alert = maxf(0.0, alert - _fixed_delta)
					_bramble_alert[index] = alert
				var development := _bramble_development[index]
				if is_player_frontier:
					# Development is the frontier hedge alone. It is a bonus layer on
					# top of the hazard every owned cell already carries, so ground
					# behind the border no longer needs to remember anything: burying
					# thorns costs the bonus, never the Bramble itself.
					development = maxf(development, maturity * bramble_mature_start)
					var growth := bramble_growth_step * (
						1.0 + maturity * bramble_maturity_bonus
					)
					if alert > 0.0:
						# A section under attack thickens faster so defence can answer
						# pressure, but still over seconds rather than instantly.
						growth *= bramble_attack_multiplier
					development = minf(1.0, development + growth)
				elif development > 0.0:
					development = maxf(0.0, development - bramble_decay_step)
				_bramble_development[index] = development
			var neighbor_sum := 0.0
			neighbor_sum += _control[left_index] if _claimable_mask[left_index] != 0 else control
			neighbor_sum += _control[right_index] if _claimable_mask[right_index] != 0 else control
			neighbor_sum += _control[up_index] if _claimable_mask[up_index] != 0 else control
			neighbor_sum += _control[down_index] if _claimable_mask[down_index] != 0 else control
			var neighbor_average := neighbor_sum * 0.25

			var diffusion := (
				(neighbor_average - transported)
				* step_diffusion_rate
				* _fixed_delta
				/ resistance
			)
			var sharpening := (
				transported
				* (1.0 - transported * transported)
				* step_sharpening_rate
				* _fixed_delta
			)
			var spread := 0.0
			if absf(transported) < 0.48 and absf(neighbor_average) > step_ownership_threshold:
				var spread_sign := 1.0 if neighbor_average > 0.0 else -1.0
				spread = (
					spread_sign
					* (absf(neighbor_average) - step_ownership_threshold)
					* step_natural_spread_rate
					* _fixed_delta
				)

			var next_control := clampf(transported + diffusion + sharpening + spread, -1.0, 1.0)
			if step_regeneration > 0.0 and next_control > step_ownership_threshold:
				# Root's Regeneration heals ground the player still holds, so damaged
				# interior recovers instead of waiting on diffusion alone.
				next_control = minf(1.0, next_control + step_regeneration)
			if regrowth_active:
				# Regrowth: ground the run has just lost remembers that it was ours
				# and comes back on its own while nothing contests it. Hostile
				# control stops the recovery outright, so this reclaims what
				# slipped away rather than fighting a live invasion for it.
				var memory := _lost_memory[index]
				if control > step_ownership_threshold:
					_lost_memory[index] = _regrowth_memory_seconds
				elif memory > 0.0:
					_lost_memory[index] = maxf(0.0, memory - _fixed_delta)
					if next_control >= 0.0:
						next_control = minf(1.0, next_control + step_regrowth_memory)
			elif _lost_memory[index] > 0.0:
				_lost_memory[index] = 0.0
			if _pruned_ground[index] > 0.0:
				# Pruned Ground remembers that it was ours and grows itself back,
				# rather than only being easier for a neighbour to reach. Without
				# that a cut cell with nothing beside it never returns, and a path
				# built on sacrifice bleeds its own run to death. The enemy can still
				# take it: hostile control stops the recovery outright.
				_pruned_ground[index] = maxf(0.0, _pruned_ground[index] - _fixed_delta)
				if next_control >= 0.0:
					next_control = minf(1.0, next_control + step_pruned_regrowth)
			if absf(next_control) < 0.008:
				next_control = 0.0
			_next_control[index] = next_control

			var old_owner := (
				1 if control > step_ownership_threshold
				else (-1 if control < -step_ownership_threshold else 0)
			)
			var next_owner := (
				1 if next_control > step_ownership_threshold
				else (-1 if next_control < -step_ownership_threshold else 0)
			)
			if next_owner == 0:
				_next_maturity[index] = maxf(
					0.0,
					maturity - step_neutral_maturity_decay_per_second * _fixed_delta
				)
			elif old_owner == next_owner:
				_next_maturity[index] = minf(
					1.0,
					maturity
					+ step_maturation_per_second * absf(next_control) * _fixed_delta
				)
			else:
				_next_maturity[index] = 0.0
			if _next_maturity[index] >= step_mature_threshold and old_owner == next_owner:
				_territory_age[index] = minf(
					step_age_reference,
					_territory_age[index] + _fixed_delta
				)
			elif _territory_age[index] > 0.0:
				_territory_age[index] = 0.0

			_next_pressure_x[index] = pressure_x * step_pressure_damping
			_next_pressure_y[index] = pressure_y * step_pressure_damping

	_swap_simulation_buffers()

	_topology_accumulator += _fixed_delta
	if _topology_accumulator >= tuning.topology_interval_seconds:
		_topology_accumulator = fmod(_topology_accumulator, tuning.topology_interval_seconds)
		analyze_topology_now()

	_metrics_accumulator += _fixed_delta
	if _metrics_accumulator >= tuning.metrics_interval_seconds:
		_metrics_accumulator = fmod(_metrics_accumulator, tuning.metrics_interval_seconds)
		recalculate_metrics_now()

	var elapsed_ms := float(Time.get_ticks_usec() - started_at) / 1000.0
	_measured_steps += 1
	_average_step_ms = elapsed_ms if _measured_steps == 1 else lerpf(_average_step_ms, elapsed_ms, 0.08)
	_peak_step_ms = maxf(_peak_step_ms, elapsed_ms)


func queue_bloom(
	local_position: Vector2,
	mass_multiplier: float = 1.0,
	pressure_multiplier: float = 1.0,
	conversion_multiplier: float = 1.0,
	radius_multiplier: float = 1.0
) -> void:
	if not contains_local_point(local_position):
		return
	var command := TerritoryCommand.new()
	command.kind = TerritoryCommand.Kind.BLOOM
	command.cell_position = local_to_cell(local_position)
	command.radius_cells = tuning.bloom_radius_cells * maxf(0.05, radius_multiplier)
	command.mass = tuning.bloom_mass * maxf(0.0, mass_multiplier)
	command.pressure_cells = tuning.bloom_pressure_cells * maxf(0.0, pressure_multiplier)
	command.hostile_conversion_factor = (
		tuning.bloom_hostile_conversion_factor * maxf(0.0, conversion_multiplier)
	)
	_commands.append(command)


func queue_seed_growth(
	local_position: Vector2,
	mass_multiplier: float = 1.0,
	pressure_multiplier: float = 1.0,
	conversion_multiplier: float = 1.0,
	radius_multiplier: float = 1.0
) -> void:
	if not contains_local_point(local_position):
		return
	var command := TerritoryCommand.new()
	command.kind = TerritoryCommand.Kind.SEED
	command.cell_position = local_to_cell(local_position)
	command.radius_cells = tuning.seed_radius_cells * maxf(0.05, radius_multiplier)
	command.mass = tuning.seed_mass * maxf(0.0, mass_multiplier)
	command.pressure_cells = tuning.seed_pressure_cells * maxf(0.0, pressure_multiplier)
	command.hostile_conversion_factor = (
		tuning.seed_hostile_conversion_factor * maxf(0.0, conversion_multiplier)
	)
	_commands.append(command)


func queue_splat(
	local_position: Vector2,
	mass: float,
	pressure_cells: float,
	radius_cells: float,
	conversion_factor: float = 1.0,
	impact_direction: Vector2 = Vector2.ZERO,
	elongation: float = 1.0,
	impact_break: float = 0.0,
	maturity_ceiling: float = -1.0,
	maturity_reinforcement: float = 0.0
) -> void:
	# A splat is a Bloom's thrown material landing somewhere. Unlike the central
	# surge it does not need Plant beside it, so a glob that clears a wall can
	# establish an island; unlike a Seed its Mass, Force, and radius are authored
	# by the caller rather than scaled off one Seed baseline.
	if not contains_local_point(local_position):
		return
	var command := TerritoryCommand.new()
	command.kind = TerritoryCommand.Kind.SPLAT
	command.cell_position = local_to_cell(local_position)
	command.radius_cells = maxf(0.5, radius_cells)
	command.mass = maxf(0.0, mass)
	command.pressure_cells = maxf(0.0, pressure_cells)
	command.hostile_conversion_factor = maxf(0.0, conversion_factor)
	command.impact_direction = (
		impact_direction.normalized()
		if impact_direction.length_squared() > 0.0001
		else Vector2.ZERO
	)
	command.elongation = maxf(1.0, elongation)
	command.impact_break = maxf(0.0, impact_break)
	command.maturity_ceiling = maturity_ceiling
	command.maturity_reinforcement = maxf(0.0, maturity_reinforcement)
	_commands.append(command)


func set_regrowth_memory(seconds: float, control_per_second: float) -> void:
	# How long lost Green stays remembered, and how fast it reclaims itself while
	# nothing is standing on it. Zero seconds turns the whole layer off, so a run
	# without the relic pays nothing for it in the fixed step.
	_regrowth_memory_seconds = maxf(0.0, seconds)
	_regrowth_memory_per_second = maxf(0.0, control_per_second)
	if _regrowth_memory_seconds <= 0.0:
		_lost_memory.fill(0.0)


func get_regrowth_memory_at_local(local_position: Vector2) -> float:
	var index := _index_at_local(local_position)
	if index < 0:
		return 0.0
	return _lost_memory[index]


func find_oldest_mature_position() -> Vector2:
	# The single oldest patch of Mature Green the run holds. Relics that put a
	# permanent object on old ground ask the field where that ground is rather
	# than scanning it themselves.
	var cell_width := tuning.arena_size.x / float(_width)
	var cell_height := tuning.arena_size.y / float(_height)
	var best_position := Vector2(-1.0, -1.0)
	var best_age := 0.0
	for y in range(_height):
		for x in range(_width):
			var index := y * _width + x
			if _claimable_mask[index] == 0:
				continue
			if _control[index] <= tuning.ownership_threshold:
				continue
			if _maturity[index] < tuning.mature_threshold:
				continue
			if _territory_age[index] <= best_age:
				continue
			best_age = _territory_age[index]
			best_position = Vector2(
				(float(x) + 0.5) * cell_width,
				(float(y) + 0.5) * cell_height
			)
	return best_position


func set_cohesion_multiplier(multiplier: float) -> void:
	# Cambium's structural integrity. Cohesion is a material property of Green, so
	# it lives on the field beside maturity rather than inside an ability.
	_cohesion_multiplier = maxf(0.05, multiplier)


func get_cohesion_multiplier() -> float:
	return _cohesion_multiplier


func get_cohesion_at_local(local_position: Vector2) -> float:
	# How well the material at this point holds together: owned Plant mass, made
	# tougher by maturity and by whatever Cambium the run has invested in.
	var index := _index_at_local(local_position)
	if index < 0:
		return 0.0
	var control := _control[index]
	if control <= tuning.ownership_threshold:
		return 0.0
	return (
		control
		* (1.0 + _maturity[index] * tuning.maturity_resistance_bonus)
		* _cohesion_multiplier
	)


func get_mass_at_local(local_position: Vector2) -> float:
	# Plant Mass alone, with hostile material reported as zero rather than as a
	# negative amount of Green.
	var index := _index_at_local(local_position)
	if index < 0:
		return 0.0
	return maxf(0.0, _control[index])


func overgrow(
	mass_budget: float,
	pressure_budget: float,
	cohesion_budget: float
) -> OvergrowResult:
	# Overgrow spends a reserve into the material and then lets the simulation
	# decide what that means. It adds Mass, outward Pressure, and repair along the
	# whole living frontier; open ground spreads, a corridor funnels the same
	# budget into a jet, and a torn ecosystem spends it sealing itself instead.
	var result := OvergrowResult.new()
	if mass_budget <= 0.0 and pressure_budget <= 0.0 and cohesion_budget <= 0.0:
		return result
	var sampled := sample_overgrow_frontier(mass_budget + pressure_budget)
	if sampled.is_empty():
		return result
	return apply_overgrow(sampled, mass_budget, pressure_budget, cohesion_budget)


func sample_overgrow_frontier(reach_budget: float) -> PackedInt32Array:
	# Which stretch of the living border a release reaches, decided by how much it
	# is carrying. Split out from applying it so a release that is poured in over
	# several frames scans the field once and then keeps feeding the same border,
	# rather than re-deciding its own shape every frame.
	var frontier_cells := PackedInt32Array()
	for index in range(_cell_count):
		if _player_frontier_mask[index] != 0:
			frontier_cells.append(index)
	if frontier_cells.is_empty():
		return frontier_cells
	# How far around the border this release reaches is decided by how much material
	# it is carrying. Spreading a fixed budget across every frontier cell made each
	# cell's share vanish as the border grew, so a late-game injection did less than
	# an early one for the same Biomass.
	var wanted := maxi(16, int(round(maxf(0.0, reach_budget) * tuning.overgrow_cells_per_mass)))
	var limit := mini(maxi(16, tuning.overgrow_frontier_sample_limit), wanted)
	var stride := 1
	if frontier_cells.size() > limit:
		stride = int(ceil(float(frontier_cells.size()) / float(limit)))
	var sampled := PackedInt32Array()
	for offset in range(0, frontier_cells.size(), stride):
		sampled.append(frontier_cells[offset])
	return sampled


func apply_overgrow(
	sampled: PackedInt32Array,
	mass_budget: float,
	pressure_budget: float,
	cohesion_budget: float
) -> OvergrowResult:
	var result := OvergrowResult.new()
	if sampled.is_empty():
		return result
	var share := 1.0 / float(sampled.size())
	var mass_per_cell := mass_budget * share * tuning.overgrow_mass_per_budget
	var pressure_per_cell := pressure_budget * share * tuning.overgrow_pressure_per_budget
	var repair_per_cell := cohesion_budget * share * tuning.overgrow_repair_per_budget
	for index in sampled:
		var x := index % _width
		var y := index / _width
		# The outward normal is the direction with the least Plant behind it, which
		# is what makes a gap funnel and a wall deflect without any special case.
		var outward := Vector2.ZERO
		if x > 0:
			outward.x -= _control[index - 1]
		if x < _width - 1:
			outward.x += _control[index + 1]
		if y > 0:
			outward.y -= _control[index - _width]
		if y < _height - 1:
			outward.y += _control[index + _width]
		if outward.length_squared() > 0.000001:
			outward = -outward.normalized()
		if mass_per_cell > 0.0:
			var before := _control[index]
			_control[index] = clampf(before + mass_per_cell, -1.0, 1.0)
			# What the ground took, not what was offered: a cell already at full
			# control cannot accept more, and the result should say so.
			result.mass_applied += _control[index] - before
		if pressure_per_cell > 0.0 and outward != Vector2.ZERO:
			_pressure_x[index] = clampf(
				_pressure_x[index] + outward.x * pressure_per_cell,
				-tuning.max_pressure_cells,
				tuning.max_pressure_cells
			)
			_pressure_y[index] = clampf(
				_pressure_y[index] + outward.y * pressure_per_cell,
				-tuning.max_pressure_cells,
				tuning.max_pressure_cells
			)
			result.pressure_applied += pressure_per_cell
		if repair_per_cell > 0.0:
			# Cohesion goes where the material is damaged: thin Green thickens and
			# hostile ground beside the frontier is pushed back toward neutral,
			# rather than a full border gaining nothing it can use.
			var repaired := repair_per_cell * (1.0 - clampf(_control[index], 0.0, 1.0))
			_control[index] = clampf(_control[index] + repaired, -1.0, 1.0)
			_maturity[index] = minf(1.0, _maturity[index] + repair_per_cell * 0.25)
			result.repair_applied += repaired
			if x > 0 and _control[index - 1] < 0.0:
				_control[index - 1] = minf(0.0, _control[index - 1] + repaired)
			if x < _width - 1 and _control[index + 1] < 0.0:
				_control[index + 1] = minf(0.0, _control[index + 1] + repaired)
		result.cell_count += 1
	return result


func queue_erosion(
	local_position: Vector2,
	erosion_multiplier: float = 1.0,
	radius_multiplier: float = 1.0
) -> void:
	if not contains_local_point(local_position):
		return
	var command := TerritoryCommand.new()
	command.kind = TerritoryCommand.Kind.EROSION
	command.cell_position = local_to_cell(local_position)
	command.radius_cells = tuning.grazer_radius_cells * maxf(0.05, radius_multiplier)
	command.erosion = tuning.grazer_erosion_per_stamp * maxf(0.0, erosion_multiplier)
	_commands.append(command)


func queue_hostile_growth(
	local_position: Vector2,
	strength: float,
	radius_multiplier: float = 1.0
) -> void:
	if not contains_local_point(local_position):
		return
	var command := TerritoryCommand.new()
	command.kind = TerritoryCommand.Kind.HOSTILE_GROWTH
	command.cell_position = local_to_cell(local_position)
	command.radius_cells = tuning.grazer_radius_cells * maxf(0.05, radius_multiplier)
	command.hostile_mass = maxf(0.0, strength)
	_commands.append(command)


func queue_maturity_suppression(
	local_position: Vector2,
	strength: float,
	radius_multiplier: float = 1.0
) -> void:
	if not contains_local_point(local_position):
		return
	var command := TerritoryCommand.new()
	command.kind = TerritoryCommand.Kind.MATURITY_SUPPRESSION
	command.cell_position = local_to_cell(local_position)
	command.radius_cells = tuning.grazer_radius_cells * maxf(0.05, radius_multiplier)
	# Signed on purpose: the stamp reads a negative suppression as support, which is
	# how a mechanic feeds maturity back into ground it holds. Clamping here made
	# `queue_maturity_support` a silent no-op.
	command.maturity_suppression = strength
	_commands.append(command)


func prune_territory(
	target_cells: int,
	pruned_seconds: float,
	sample_stride: int = 6
) -> PruneHarvest:
	# A Pruning Cycle eats the ecosystem from its youngest edge inward: Fresh ground
	# first, then Established, and Mature only when there is nothing else left. The
	# cost is a fixed number of cells rather than a share of what the run holds, so
	# it stays predictable however well the run is doing.
	var harvest := PruneHarvest.new()
	if target_cells <= 0 or _cell_count == 0:
		return harvest
	var cell_width := tuning.arena_size.x / float(_width)
	var cell_height := tuning.arena_size.y / float(_height)
	var bands := [
		[0.0, tuning.mature_threshold * 0.5],
		[tuning.mature_threshold * 0.5, tuning.mature_threshold],
		[tuning.mature_threshold, 2.0],
	]
	for band in bands:
		if harvest.cell_count >= target_cells:
			break
		var lower: float = band[0]
		var upper: float = band[1]
		for index in range(_cell_count):
			if harvest.cell_count >= target_cells:
				break
			if _claimable_mask[index] == 0:
				continue
			var control := _control[index]
			if control <= tuning.ownership_threshold:
				continue
			var maturity := _maturity[index]
			if maturity < lower or maturity >= upper:
				continue
			harvest.mass += control
			harvest.bramble_development += _bramble_development[index]
			if maturity >= tuning.mature_threshold:
				harvest.mature_cell_count += 1
			if harvest.cell_count % maxi(1, sample_stride) == 0:
				harvest.positions.append(Vector2(
					(float(index % _width) + 0.5) * cell_width,
					(float(index / _width) + 0.5) * cell_height
				))
			harvest.cell_count += 1
			_control[index] = 0.0
			_maturity[index] = 0.0
			_territory_age[index] = 0.0
			_bramble_development[index] = 0.0
			_pruned_ground[index] = pruned_seconds
	if harvest.cell_count > 0:
		refresh_visuals_now()
	return harvest


func prune_territory_in_radius(
	local_position: Vector2,
	radius_pixels: float,
	pruned_seconds: float
) -> PruneHarvest:
	# The same cut, but drawn inward toward one point rather than from the whole
	# ecosystem, which is what a Bloom pulling Green into itself needs.
	var harvest := PruneHarvest.new()
	if not contains_local_point(local_position) or radius_pixels <= 0.0:
		return harvest
	var cell_width := tuning.arena_size.x / float(_width)
	var cell_height := tuning.arena_size.y / float(_height)
	var centre := local_to_cell(local_position)
	var centre_x := clampi(int(round(centre.x)), 0, _width - 1)
	var centre_y := clampi(int(round(centre.y)), 0, _height - 1)
	var radius_x := maxi(1, ceili(radius_pixels / cell_width))
	var radius_y := maxi(1, ceili(radius_pixels / cell_height))
	var radius_squared := radius_pixels * radius_pixels
	for y in range(maxi(0, centre_y - radius_y), mini(_height - 1, centre_y + radius_y) + 1):
		for x in range(maxi(0, centre_x - radius_x), mini(_width - 1, centre_x + radius_x) + 1):
			var index := y * _width + x
			if _claimable_mask[index] == 0 or _control[index] <= tuning.ownership_threshold:
				continue
			var offset_x := (float(x) + 0.5) * cell_width - local_position.x
			var offset_y := (float(y) + 0.5) * cell_height - local_position.y
			if offset_x * offset_x + offset_y * offset_y > radius_squared:
				continue
			harvest.mass += _control[index]
			harvest.bramble_development += _bramble_development[index]
			if _maturity[index] >= tuning.mature_threshold:
				harvest.mature_cell_count += 1
			harvest.cell_count += 1
			_control[index] = 0.0
			_maturity[index] = 0.0
			_territory_age[index] = 0.0
			_bramble_development[index] = 0.0
			_pruned_ground[index] = pruned_seconds
	if harvest.cell_count > 0:
		refresh_visuals_now()
	return harvest


func drain_territory_in_radius(
	local_position: Vector2,
	radius_pixels: float,
	target_cells: int,
	pruned_seconds: float
) -> PruneHarvest:
	# A bounded cut around one point that takes the youngest ground it can find
	# first, which is what an upkeep drain under the player needs: it should eat the
	# fresh growth it is standing on and only bite into ancient ground when there is
	# nothing else left underfoot.
	var harvest := PruneHarvest.new()
	if target_cells <= 0 or not contains_local_point(local_position):
		return harvest
	var cell_width := tuning.arena_size.x / float(_width)
	var cell_height := tuning.arena_size.y / float(_height)
	var centre := local_to_cell(local_position)
	var centre_x := clampi(int(round(centre.x)), 0, _width - 1)
	var centre_y := clampi(int(round(centre.y)), 0, _height - 1)
	var radius_x := maxi(1, ceili(radius_pixels / cell_width))
	var radius_y := maxi(1, ceili(radius_pixels / cell_height))
	var radius_squared := radius_pixels * radius_pixels
	var bands := [
		[0.0, tuning.mature_threshold * 0.5],
		[tuning.mature_threshold * 0.5, tuning.mature_threshold],
		[tuning.mature_threshold, 2.0],
	]
	for band in bands:
		if harvest.cell_count >= target_cells:
			break
		var lower: float = band[0]
		var upper: float = band[1]
		for y in range(maxi(0, centre_y - radius_y), mini(_height - 1, centre_y + radius_y) + 1):
			if harvest.cell_count >= target_cells:
				break
			for x in range(maxi(0, centre_x - radius_x), mini(_width - 1, centre_x + radius_x) + 1):
				if harvest.cell_count >= target_cells:
					break
				var index := y * _width + x
				if _claimable_mask[index] == 0:
					continue
				if _control[index] <= tuning.ownership_threshold:
					continue
				var maturity := _maturity[index]
				if maturity < lower or maturity >= upper:
					continue
				var offset_x := (float(x) + 0.5) * cell_width - local_position.x
				var offset_y := (float(y) + 0.5) * cell_height - local_position.y
				if offset_x * offset_x + offset_y * offset_y > radius_squared:
					continue
				harvest.mass += _control[index]
				harvest.bramble_development += _bramble_development[index]
				if maturity >= tuning.mature_threshold:
					harvest.mature_cell_count += 1
				harvest.positions.append(Vector2(
					(float(x) + 0.5) * cell_width,
					(float(y) + 0.5) * cell_height
				))
				harvest.cell_count += 1
				_control[index] = 0.0
				_maturity[index] = 0.0
				_territory_age[index] = 0.0
				_bramble_development[index] = 0.0
				_pruned_ground[index] = pruned_seconds
	if harvest.cell_count > 0:
		refresh_visuals_now()
	return harvest


func set_pruned_regrowth(control_per_second: float) -> void:
	# How much faster Green retakes ground a cycle cut away. Owned by the field
	# because reclamation is a field rule; Pruning decides how strong it is.
	_pruned_regrowth_per_second = maxf(0.0, control_per_second)


func get_pruned_ground_at_local(local_position: Vector2) -> float:
	if not contains_local_point(local_position):
		return 0.0
	return _pruned_ground[_index_at_local(local_position)]


func get_player_cell_count() -> int:
	# How many cells the run actually holds, which is what a sacrifice has to be
	# proportionate to when the ecosystem is small.
	var count := 0
	for index in range(_cell_count):
		if _claimable_mask[index] != 0 and _control[index] > tuning.ownership_threshold:
			count += 1
	return count


func get_claimable_cell_count() -> int:
	# What a Pruning Cycle measures its fixed cost against.
	var count := 0
	for index in range(_cell_count):
		if _claimable_mask[index] != 0:
			count += 1
	return count


func queue_maturity_support(
	local_position: Vector2,
	strength: float,
	radius_multiplier: float = 1.0
) -> void:
	# The inverse of suppression: a mechanic feeding maturity back into ground it
	# holds, such as the Rhizome Network holding up its colonies.
	queue_maturity_suppression(local_position, -maxf(0.0, strength), radius_multiplier)


func refresh_visuals_now() -> void:
	if _field_image == null or _field_texture == null:
		return
	var started_at := Time.get_ticks_usec()

	for index in range(_cell_count):
		var control_encoded := clampf(_control[index] * 0.5 + 0.5, 0.0, 1.0)
		var pressure_encoded := clampf(
			sqrt(
				_pressure_x[index] * _pressure_x[index]
				+ _pressure_y[index] * _pressure_y[index]
			) / tuning.max_pressure_cells,
			0.0,
			1.0
		)
		var byte_index := index * 4
		_pixel_bytes[byte_index] = clampi(int(control_encoded * 255.0), 0, 255)
		_pixel_bytes[byte_index + 1] = clampi(int(_maturity[index] * 255.0), 0, 255)
		_pixel_bytes[byte_index + 2] = clampi(int(pressure_encoded * 255.0), 0, 255)
		# Unclaimable basalt stays at zero while claimable ground occupies the upper
		# alpha range, so Bramble development rides along without a second texture.
		var mask_encoded := 0.0
		if _claimable_mask[index] != 0:
			mask_encoded = 0.60 + _bramble_development[index] * 0.40
		_pixel_bytes[byte_index + 3] = clampi(int(mask_encoded * 255.0), 0, 255)

	_field_image.set_data(_width, _height, false, Image.FORMAT_RGBA8, _pixel_bytes)
	_field_texture.update(_field_image)
	queue_redraw()

	var elapsed_ms := float(Time.get_ticks_usec() - started_at) / 1000.0
	_measured_renders += 1
	_average_render_ms = elapsed_ms if _measured_renders == 1 else lerpf(_average_render_ms, elapsed_ms, 0.08)
	_peak_render_ms = maxf(_peak_render_ms, elapsed_ms)


func recalculate_metrics_now() -> void:
	var claimable_cells := 0
	var player_cells := 0
	var hostile_cells := 0
	var mature_player_cells := 0
	for index in range(_cell_count):
		if _claimable_mask[index] == 0:
			continue
		claimable_cells += 1
		var owner := _owner_from_control(_control[index])
		if owner > 0:
			player_cells += 1
			if _maturity[index] >= tuning.mature_threshold:
				mature_player_cells += 1
		elif owner < 0:
			hostile_cells += 1

	if claimable_cells == 0:
		_player_percent = 0.0
		_hostile_percent = 0.0
		_neutral_percent = 100.0
	else:
		_player_percent = float(player_cells) / float(claimable_cells) * 100.0
		_hostile_percent = float(hostile_cells) / float(claimable_cells) * 100.0
		_neutral_percent = maxf(0.0, 100.0 - _player_percent - _hostile_percent)
	_mature_player_percent = (
		float(mature_player_cells) / float(player_cells) * 100.0
		if player_cells > 0
		else 0.0
	)
	metrics_changed.emit(
		_player_percent,
		_hostile_percent,
		_neutral_percent,
		_mature_player_percent,
		_fragment_count
	)


func analyze_topology_now() -> void:
	_topology_labels.fill(-1)
	_fragment_count = 0
	_small_fragment_count = 0
	var next_label := 0

	for start_index in range(_cell_count):
		if _topology_labels[start_index] != -1:
			continue
		if _claimable_mask[start_index] == 0 or _control[start_index] <= tuning.ownership_threshold:
			_topology_labels[start_index] = -2
			continue

		var head := 0
		var tail := 0
		_topology_queue[tail] = start_index
		tail += 1
		_topology_labels[start_index] = next_label

		while head < tail:
			var current := _topology_queue[head]
			head += 1
			var current_x := current % _width
			var current_y := current / _width
			if current_x > 0:
				tail = _try_enqueue_topology_neighbor(current - 1, next_label, tail)
			if current_x < _width - 1:
				tail = _try_enqueue_topology_neighbor(current + 1, next_label, tail)
			if current_y > 0:
				tail = _try_enqueue_topology_neighbor(current - _width, next_label, tail)
			if current_y < _height - 1:
				tail = _try_enqueue_topology_neighbor(current + _width, next_label, tail)

		_fragment_count += 1
		if tail < tuning.small_fragment_cell_limit:
			_small_fragment_count += 1
			var decay := tuning.small_fragment_decay_per_second * tuning.topology_interval_seconds
			for queue_index in range(tail):
				var cell_index := _topology_queue[queue_index]
				_control[cell_index] = maxf(0.0, _control[cell_index] - decay)
		next_label += 1


func cycle_debug_view() -> String:
	debug_view = (debug_view + 1) % 3
	if _field_material != null:
		_field_material.set_shader_parameter("debug_view", debug_view)
	queue_redraw()
	return get_debug_view_name()


func get_debug_view_name() -> String:
	match debug_view:
		DebugView.MATURITY:
			return "MATURITY"
		DebugView.CONTROL:
			return "CONTROL FIELD"
		_:
			return "TERRITORY"


func contains_local_point(local_position: Vector2) -> bool:
	return Rect2(Vector2.ZERO, tuning.arena_size).has_point(local_position)


func local_to_cell(local_position: Vector2) -> Vector2:
	# Cell x covers [x, x+1) cell widths, so its centre sits half a cell in. Without
	# that half-cell the inverse of cell_to_local lands on the neighbouring cell,
	# which nudged every position query one cell off its intended sample.
	return Vector2(
		clampf(
			local_position.x / tuning.arena_size.x * float(_width) - 0.5,
			0.0,
			float(_width - 1)
		),
		clampf(
			local_position.y / tuning.arena_size.y * float(_height) - 0.5,
			0.0,
			float(_height - 1)
		)
	)


func describe_frontier_cells(cells: PackedInt32Array) -> Array:
	# Where a set of frontier cells sits in the arena and which way each one faces,
	# so what the ecosystem does to its border can be drawn along that border. The
	# outward direction is the one with the least Plant behind it, which is the same
	# rule the release itself uses to decide where to push.
	var positions := PackedVector2Array()
	var directions := PackedVector2Array()
	for index in cells:
		if index < 0 or index >= _cell_count:
			continue
		var x := index % _width
		var y := index / _width
		var outward := Vector2.ZERO
		if x > 0:
			outward.x -= _control[index - 1]
		if x < _width - 1:
			outward.x += _control[index + 1]
		if y > 0:
			outward.y -= _control[index - _width]
		if y < _height - 1:
			outward.y += _control[index + _width]
		if outward.length_squared() > 0.000001:
			outward = -outward.normalized()
		positions.append(cell_to_local(Vector2(float(x), float(y))))
		directions.append(outward)
	return [positions, directions]


func cell_to_local(cell_position: Vector2) -> Vector2:
	return Vector2(
		(cell_position.x + 0.5) / float(_width) * tuning.arena_size.x,
		(cell_position.y + 0.5) / float(_height) * tuning.arena_size.y
	)


func get_control_at_local(local_position: Vector2) -> float:
	var cell := local_to_cell(local_position)
	var x := clampi(int(round(cell.x)), 0, _width - 1)
	var y := clampi(int(round(cell.y)), 0, _height - 1)
	return _control[y * _width + x]


func get_maturity_at_local(local_position: Vector2) -> float:
	var cell := local_to_cell(local_position)
	var x := clampi(int(round(cell.x)), 0, _width - 1)
	var y := clampi(int(round(cell.y)), 0, _height - 1)
	return _maturity[y * _width + x]


func get_pressure_at_local(local_position: Vector2) -> Vector2:
	var cell := local_to_cell(local_position)
	var x := clampi(int(round(cell.x)), 0, _width - 1)
	var y := clampi(int(round(cell.y)), 0, _height - 1)
	var index := y * _width + x
	return Vector2(_pressure_x[index], _pressure_y[index])


func get_obstacle_normal_at_local(local_position: Vector2, reach: int = 2) -> Vector2:
	# Which way the obstacle at this point faces, so something hitting it can run
	# along the face instead of simply stopping. Basalt and the arena wall are the
	# same thing to this: unclaimable ground.
	#
	# Taken as the gradient of the blocked mask over a small window — every blocked
	# neighbour pushes the normal away from itself, weighted by how near it is — so a
	# flat face gives a square-on normal, an inside corner gives the diagonal, and a
	# lone clipped cell gives a normal that barely deflects anything.
	var cell := local_to_cell(local_position)
	var centre_x := clampi(int(round(cell.x)), 0, _width - 1)
	var centre_y := clampi(int(round(cell.y)), 0, _height - 1)
	var normal := Vector2.ZERO
	for offset_y in range(-reach, reach + 1):
		var y := centre_y + offset_y
		if y < 0 or y >= _height:
			continue
		for offset_x in range(-reach, reach + 1):
			var x := centre_x + offset_x
			if x < 0 or x >= _width:
				continue
			if offset_x == 0 and offset_y == 0:
				continue
			if _claimable_mask[y * _width + x] != 0:
				continue
			var away := Vector2(float(-offset_x), float(-offset_y))
			var distance := away.length()
			if distance <= 0.0:
				continue
			normal += away / (distance * distance)
	# The arena's edge is an obstacle too, and it has no cells to sample.
	var edge := 0.5
	if local_position.x < edge * tuning.arena_size.x / float(_width):
		normal += Vector2.RIGHT
	elif local_position.x > tuning.arena_size.x - edge * tuning.arena_size.x / float(_width):
		normal += Vector2.LEFT
	if local_position.y < edge * tuning.arena_size.y / float(_height):
		normal += Vector2.DOWN
	elif local_position.y > tuning.arena_size.y - edge * tuning.arena_size.y / float(_height):
		normal += Vector2.UP
	if normal.length_squared() < 0.000001:
		return Vector2.ZERO
	return normal.normalized()


func is_claimable_at_local(local_position: Vector2) -> bool:
	var cell := local_to_cell(local_position)
	var x := clampi(int(round(cell.x)), 0, _width - 1)
	var y := clampi(int(round(cell.y)), 0, _height - 1)
	return _claimable_mask[y * _width + x] != 0


func is_diamond_claimable_at_local(local_position: Vector2, radius: float) -> bool:
	var arena_size := tuning.arena_size
	if (
		local_position.x - radius < 0.0
		or local_position.y - radius < 0.0
		or local_position.x + radius >= arena_size.x
		or local_position.y + radius >= arena_size.y
	):
		return false
	var cell_scale_x := float(_width) / arena_size.x
	var cell_scale_y := float(_height) / arena_size.y
	var center_x := clampi(int(round(local_position.x * cell_scale_x)), 0, _width - 1)
	var center_y := clampi(int(round(local_position.y * cell_scale_y)), 0, _height - 1)
	var left_x := clampi(int(round((local_position.x - radius) * cell_scale_x)), 0, _width - 1)
	var right_x := clampi(int(round((local_position.x + radius) * cell_scale_x)), 0, _width - 1)
	var top_y := clampi(int(round((local_position.y - radius) * cell_scale_y)), 0, _height - 1)
	var bottom_y := clampi(int(round((local_position.y + radius) * cell_scale_y)), 0, _height - 1)
	return (
		_claimable_mask[center_y * _width + center_x] != 0
		and _claimable_mask[center_y * _width + left_x] != 0
		and _claimable_mask[center_y * _width + right_x] != 0
		and _claimable_mask[top_y * _width + center_x] != 0
		and _claimable_mask[bottom_y * _width + center_x] != 0
	)


func is_growth_path_clear(local_start: Vector2, local_end: Vector2) -> bool:
	if not contains_local_point(local_start) or not contains_local_point(local_end):
		return false
	var start_cell := local_to_cell(local_start)
	var end_cell := local_to_cell(local_end)
	return _is_claimable_line_clear(
		clampi(int(round(start_cell.x)), 0, _width - 1),
		clampi(int(round(start_cell.y)), 0, _height - 1),
		clampi(int(round(end_cell.x)), 0, _width - 1),
		clampi(int(round(end_cell.y)), 0, _height - 1)
	)


func set_bramble_modifiers(enabled: bool, resistance_multiplier: float) -> void:
	if enabled != _bramble_enabled:
		# Committing to Bramble grows thorns from a bare frontier instead of
		# arming every existing border the instant the path is selected.
		_bramble_development.fill(0.0)
		_bramble_alert.fill(0.0)
	_bramble_enabled = enabled
	_bramble_resistance_multiplier = maxf(1.0, resistance_multiplier)
	if _field_material != null:
		_field_material.set_shader_parameter("bramble_enabled", _bramble_enabled)
	queue_redraw()


func get_region_label_at_local(local_position: Vector2) -> int:
	# Connected-region id from the topology pass, or -1 for ground the player does
	# not hold. Callers use it to tell an isolated Bloom satellite patch from one
	# that has joined the main ecosystem.
	if not contains_local_point(local_position):
		return -1
	var label := _topology_labels[_index_at_local(local_position)]
	return label if label >= 0 else -1


func has_player_territory_within(local_position: Vector2, radius_pixels: float) -> bool:
	# Cheap proximity test used to decide whether ground counts as remote. Scans
	# the cell box covering the radius and stops at the first owned cell.
	if not contains_local_point(local_position):
		return false
	var cell_width := tuning.arena_size.x / float(_width)
	var cell_height := tuning.arena_size.y / float(_height)
	var center := local_to_cell(local_position)
	var center_x := clampi(int(round(center.x)), 0, _width - 1)
	var center_y := clampi(int(round(center.y)), 0, _height - 1)
	var radius_x := maxi(1, ceili(maxf(0.0, radius_pixels) / cell_width))
	var radius_y := maxi(1, ceili(maxf(0.0, radius_pixels) / cell_height))
	var radius_squared := radius_pixels * radius_pixels
	for y in range(maxi(0, center_y - radius_y), mini(_height - 1, center_y + radius_y) + 1):
		for x in range(maxi(0, center_x - radius_x), mini(_width - 1, center_x + radius_x) + 1):
			var index := y * _width + x
			if _claimable_mask[index] == 0 or _control[index] <= tuning.ownership_threshold:
				continue
			var offset_x := (float(x) + 0.5) * cell_width - local_position.x
			var offset_y := (float(y) + 0.5) * cell_height - local_position.y
			if offset_x * offset_x + offset_y * offset_y <= radius_squared:
				return true
	return false


func get_bramble_coverage_at_local(local_position: Vector2) -> float:
	# Bramble covers territory, not a border: every cell of owned Green is thorned
	# ground. Coverage is the hazard's presence, never its strength, so holes,
	# moving frontiers, and rings of any shape all report the same value.
	if not _bramble_enabled or not contains_local_point(local_position):
		return 0.0
	var index := _index_at_local(local_position)
	if _claimable_mask[index] == 0:
		return 0.0
	return 1.0 if _control[index] > tuning.ownership_threshold else 0.0


func get_bramble_strength_at_local(
	local_position: Vector2,
	band_radius_pixels: float = 12.0
) -> float:
	# Frontier thorns only. This is the bonus hedge on top of territory coverage,
	# so it reports the strongest thorns the band touches, never the sum of them:
	# a jagged frontier cannot multiply a single enemy's exposure.
	if not _bramble_enabled or not contains_local_point(local_position):
		return 0.0
	var center := local_to_cell(local_position)
	var cell_width := tuning.arena_size.x / float(_width)
	var cell_height := tuning.arena_size.y / float(_height)
	var radius_x := maxi(1, ceili(maxf(0.0, band_radius_pixels) / cell_width))
	var radius_y := maxi(1, ceili(maxf(0.0, band_radius_pixels) / cell_height))
	var center_x := clampi(int(round(center.x)), 0, _width - 1)
	var center_y := clampi(int(round(center.y)), 0, _height - 1)
	var radius_squared := band_radius_pixels * band_radius_pixels
	var strongest_development := -1.0

	for y in range(maxi(0, center_y - radius_y), mini(_height - 1, center_y + radius_y) + 1):
		for x in range(maxi(0, center_x - radius_x), mini(_width - 1, center_x + radius_x) + 1):
			var index := y * _width + x
			if _player_frontier_mask[index] == 0:
				continue
			var offset_x := (float(x) + 0.5) * cell_width - local_position.x
			var offset_y := (float(y) + 0.5) * cell_height - local_position.y
			if offset_x * offset_x + offset_y * offset_y > radius_squared:
				continue
			strongest_development = maxf(strongest_development, _bramble_development[index])
			if strongest_development >= 1.0:
				return 1.0
	if strongest_development < 0.0:
		return 0.0
	return lerpf(tuning.bramble_minimum_strength, 1.0, strongest_development)


func is_player_frontier_at_local(
	local_position: Vector2,
	band_radius_pixels: float = 12.0
) -> bool:
	return get_bramble_strength_at_local(local_position, band_radius_pixels) > 0.0


func get_age_at_local(local_position: Vector2) -> float:
	if not contains_local_point(local_position):
		return 0.0
	return _territory_age[_index_at_local(local_position)]


func get_age_fraction_at_local(local_position: Vector2) -> float:
	return clampf(
		get_age_at_local(local_position) / maxf(0.001, tuning.age_reference_seconds),
		0.0,
		1.0
	)


func is_mature_player_territory_at_local(local_position: Vector2) -> bool:
	if not contains_local_point(local_position):
		return false
	var index := _index_at_local(local_position)
	return (
		_claimable_mask[index] != 0
		and _control[index] > tuning.ownership_threshold
		and _maturity[index] >= tuning.mature_threshold
	)


func _index_at_local(local_position: Vector2) -> int:
	var cell := local_to_cell(local_position)
	return (
		clampi(int(round(cell.y)), 0, _height - 1) * _width
		+ clampi(int(round(cell.x)), 0, _width - 1)
	)


func set_old_growth_enabled(enabled: bool) -> void:
	# Old Growth reads Age and maturity from the field but resolves its eruptions in
	# combat; the field only records that the run has the evolution.
	_old_growth_enabled = enabled


func is_old_growth_enabled() -> bool:
	return _old_growth_enabled


func set_mature_resistance_multiplier(multiplier: float) -> void:
	_mature_resistance_multiplier = maxf(1.0, multiplier)


func get_mature_resistance_multiplier() -> float:
	return _mature_resistance_multiplier


func find_mature_player_frontier_near(local_position: Vector2) -> Vector2:
	# Root mechanics act from settled ground, so they ask for a frontier cell whose
	# territory has actually matured rather than any border at all.
	var cell_width := tuning.arena_size.x / float(_width)
	var cell_height := tuning.arena_size.y / float(_height)
	var best_position := Vector2(-1.0, -1.0)
	var best_distance := INF
	for y in range(_height):
		for x in range(_width):
			var index := y * _width + x
			if _player_frontier_mask[index] == 0:
				continue
			if _maturity[index] < tuning.mature_threshold:
				continue
			var candidate := Vector2(
				(float(x) + 0.5) * cell_width,
				(float(y) + 0.5) * cell_height
			)
			var candidate_distance := candidate.distance_squared_to(local_position)
			if candidate_distance < best_distance:
				best_distance = candidate_distance
				best_position = candidate
	return best_position


func harvest_bramble_in_radius(
	local_position: Vector2,
	radius_pixels: float
) -> BrambleHarvest:
	# Harvesting draws on the Bramble covering the ground, not on a frontier: every
	# owned cell inside the radius contributes its territory power and any thorn
	# development it carries. Only the inner part of the radius is taken, because
	# the rim is where the new frontier will stand.
	var harvest := BrambleHarvest.new()
	if not _bramble_enabled or not contains_local_point(local_position):
		return harvest
	var center := local_to_cell(local_position)
	var source_x := clampi(int(round(center.x)), 0, _width - 1)
	var source_y := clampi(int(round(center.y)), 0, _height - 1)
	var cell_width := tuning.arena_size.x / float(_width)
	var cell_height := tuning.arena_size.y / float(_height)
	var inner_radius := maxf(0.0, radius_pixels) * tuning.bramble_harvest_inner_fraction
	var radius_x := ceili(inner_radius / cell_width)
	var radius_y := ceili(inner_radius / cell_height)
	var radius_squared := inner_radius * inner_radius
	var maturity_total := 0.0

	for y in range(maxi(0, source_y - radius_y), mini(_height - 1, source_y + radius_y) + 1):
		for x in range(maxi(0, source_x - radius_x), mini(_width - 1, source_x + radius_x) + 1):
			var index := y * _width + x
			if _claimable_mask[index] == 0:
				continue
			if _control[index] <= tuning.ownership_threshold:
				continue
			var stored := tuning.bramble_territory_power + _bramble_development[index]
			var offset_x := (float(x) + 0.5) * cell_width - local_position.x
			var offset_y := (float(y) + 0.5) * cell_height - local_position.y
			if offset_x * offset_x + offset_y * offset_y > radius_squared:
				continue
			if not _is_claimable_line_clear(source_x, source_y, x, y):
				continue
			harvest.amount += stored
			maturity_total += _maturity[index] * stored
			harvest.cell_count += 1
			_bramble_development[index] = 0.0
	if harvest.amount > 0.0:
		harvest.average_maturity = maturity_total / harvest.amount
	return harvest


func get_established_bramble_strength() -> float:
	return lerpf(
		tuning.bramble_minimum_strength,
		1.0,
		tuning.bramble_established_development
	)


func debug_establish_bramble() -> void:
	for index in range(_cell_count):
		_bramble_development[index] = 1.0 if _player_frontier_mask[index] != 0 else 0.0
	refresh_visuals_now()


func is_bramble_enabled() -> bool:
	return _bramble_enabled


func get_player_percent() -> float:
	return _player_percent


func get_hostile_percent() -> float:
	return _hostile_percent


func get_neutral_percent() -> float:
	return _neutral_percent


func get_mature_player_percent() -> float:
	return _mature_player_percent


func get_fragment_count() -> int:
	return _fragment_count


func get_small_fragment_count() -> int:
	return _small_fragment_count


func get_average_step_ms() -> float:
	return _average_step_ms


func get_peak_step_ms() -> float:
	return _peak_step_ms


func get_average_render_ms() -> float:
	return _average_render_ms


func get_peak_render_ms() -> float:
	return _peak_render_ms


func _configure_buffers() -> void:
	_width = tuning.field_size.x
	_height = tuning.field_size.y
	_cell_count = _width * _height
	_fixed_delta = 1.0 / tuning.simulation_hz

	_control.resize(_cell_count)
	_next_control.resize(_cell_count)
	_maturity.resize(_cell_count)
	_next_maturity.resize(_cell_count)
	_pressure_x.resize(_cell_count)
	_next_pressure_x.resize(_cell_count)
	_pressure_y.resize(_cell_count)
	_next_pressure_y.resize(_cell_count)
	_claimable_mask.resize(_cell_count)
	_player_frontier_mask.resize(_cell_count)
	_bramble_development.resize(_cell_count)
	_bramble_alert.resize(_cell_count)
	_territory_age.resize(_cell_count)
	_pruned_ground.resize(_cell_count)
	_lost_memory.resize(_cell_count)
	_topology_labels.resize(_cell_count)
	_topology_queue.resize(_cell_count)
	_pixel_bytes.resize(_cell_count * 4)

	_field_image = Image.create(_width, _height, false, Image.FORMAT_RGBA8)
	_field_texture = ImageTexture.create_from_image(_field_image)


func _configure_material() -> void:
	var configured_material := material as ShaderMaterial
	if configured_material == null:
		_field_material = ShaderMaterial.new()
		_field_material.shader = TERRITORY_SHADER
	else:
		_field_material = configured_material.duplicate() as ShaderMaterial
	material = _field_material
	_field_material.set_shader_parameter("ownership_threshold", tuning.ownership_threshold)
	_field_material.set_shader_parameter("debug_view", debug_view)
	_field_material.set_shader_parameter("bramble_enabled", _bramble_enabled)


func _apply_pending_commands() -> void:
	for command in _commands:
		match command.kind:
			TerritoryCommand.Kind.BLOOM:
				_stamp_bloom_surge(command)
			TerritoryCommand.Kind.SEED:
				_stamp_growth(command)
			TerritoryCommand.Kind.SPLAT:
				_stamp_growth(command)
			TerritoryCommand.Kind.EROSION:
				_stamp_erosion(command)
			TerritoryCommand.Kind.HOSTILE_GROWTH:
				_stamp_hostile_growth(command)
			TerritoryCommand.Kind.MATURITY_SUPPRESSION:
				_stamp_maturity_suppression(command)
	_commands.clear()


func _stamp_growth(command: TerritoryCommand) -> void:
	var source_x := clampi(int(round(command.cell_position.x)), 0, _width - 1)
	var source_y := clampi(int(round(command.cell_position.y)), 0, _height - 1)
	if _claimable_mask[source_y * _width + source_x] == 0:
		return
	# A splat that arrived with speed keeps going: the shape is stretched along the
	# line it was travelling and its centre sits forward of the impact, so the paint
	# reads as having run on rather than as a circle stamped where it stopped.
	var travel := command.impact_direction
	var smear := command.elongation
	var across := travel.orthogonal()
	var centre := command.cell_position
	if travel != Vector2.ZERO and smear > 1.0:
		centre += travel * command.radius_cells * (smear - 1.0) * 0.5
	var extent := command.radius_cells * smear
	var minimum_x := maxi(0, int(floor(centre.x - extent)))
	var maximum_x := mini(_width - 1, int(ceil(centre.x + extent)))
	var minimum_y := maxi(0, int(floor(centre.y - extent)))
	var maximum_y := mini(_height - 1, int(ceil(centre.y + extent)))

	for y in range(minimum_y, maximum_y + 1):
		for x in range(minimum_x, maximum_x + 1):
			var offset := Vector2(float(x), float(y)) - centre
			var distance := offset.length()
			if travel != Vector2.ZERO and smear > 1.0:
				# Measured in the impact's own frame: the same disc, stretched along
				# the direction of travel.
				distance = Vector2(
					offset.dot(travel) / smear,
					offset.dot(across)
				).length()
			if distance > command.radius_cells:
				continue
			var index := y * _width + x
			if _claimable_mask[index] == 0:
				continue
			var transmission := _claimable_line_transmission(
				source_x,
				source_y,
				x,
				y,
				tuning.obstruction_falloff_per_cell
			)
			if transmission <= 0.0:
				continue
			var normalized_falloff := 1.0 - distance / command.radius_cells
			var falloff := (
				normalized_falloff * normalized_falloff * (3.0 - 2.0 * normalized_falloff)
			) * transmission
			var old_control := _control[index]
			var mass_delta := command.mass * falloff
			if old_control < 0.0:
				if command.impact_break > 0.0:
					# Something arriving with momentum does mechanical work on the
					# ground it hits: it breaks the established material up and
					# displaces it, whatever that material had matured into. The dent
					# is dealt first and does not care about resistance; the claim
					# that follows still does. Growing into an old front is hard;
					# hitting one is not the same act.
					# Flatter than the growth profile on purpose: an impact dents its
					# whole contact patch rather than tapering the way material
					# spreading outward from a centre does.
					var kinetic := command.impact_break * sqrt(falloff)
					_maturity[index] = maxf(0.0, _maturity[index] - kinetic)
					old_control = minf(0.0, old_control + kinetic)
					_control[index] = old_control
				var resistance := 1.0 + _maturity[index] * tuning.maturity_resistance_bonus
				mass_delta *= command.hostile_conversion_factor / resistance
			_control[index] = clampf(old_control + mass_delta, -1.0, 1.0)
			if _owner_from_control(old_control) != _owner_from_control(_control[index]):
				# Ground that just changed hands has nothing rooted in it yet.
				_maturity[index] = 0.0
			elif command.maturity_reinforcement > 0.0 and _control[index] > 0.0:
				# Landing on ground the run already holds thickens it. The material
				# settles onto established growth and becomes part of it, so the cell
				# ends up better rooted than it was — the opposite of what happens
				# where the same throw has to take ground first.
				#
				# Only the ceiling on newly taken ground says thrown material has no
				# roots, and that case is the branch above. Applying it here too was
				# a bug: a Bloom landing on its own mature territory stripped it.
				_maturity[index] = minf(
					1.0,
					_maturity[index] + command.maturity_reinforcement * falloff
				)
			if distance > 0.001 and command.pressure_cells > 0.0:
				# Thrown material shoves the ground the way it was going. A splat with
				# no direction still radiates, which is what a drip does.
				var direction := offset / distance
				if travel != Vector2.ZERO:
					direction = (travel * 0.75 + direction * 0.25).normalized()
				_pressure_x[index] = clampf(
					_pressure_x[index] + direction.x * command.pressure_cells * falloff,
					-tuning.max_pressure_cells,
					tuning.max_pressure_cells
				)
				_pressure_y[index] = clampf(
					_pressure_y[index] + direction.y * command.pressure_cells * falloff,
					-tuning.max_pressure_cells,
					tuning.max_pressure_cells
				)


func _stamp_bloom_surge(command: TerritoryCommand) -> void:
	# A Bloom displaces territory that already exists. Its mass only lands where
	# Plant material is already present or immediately beside the cell, so a Bloom
	# surges an existing frontier outward and cannot colonise open ground the way a
	# Seed does. Pressure radiates from the burst and deforms the border it stands on.
	var source_x := clampi(int(round(command.cell_position.x)), 0, _width - 1)
	var source_y := clampi(int(round(command.cell_position.y)), 0, _height - 1)
	if _claimable_mask[source_y * _width + source_x] == 0:
		return
	var minimum_x := maxi(0, int(floor(command.cell_position.x - command.radius_cells)))
	var maximum_x := mini(_width - 1, int(ceil(command.cell_position.x + command.radius_cells)))
	var minimum_y := maxi(0, int(floor(command.cell_position.y - command.radius_cells)))
	var maximum_y := mini(_height - 1, int(ceil(command.cell_position.y + command.radius_cells)))
	var support_reference := maxf(0.05, tuning.bloom_support_reference)
	var support_reach := maxf(0.0, tuning.bloom_support_reach_cells)

	for y in range(minimum_y, maximum_y + 1):
		for x in range(minimum_x, maximum_x + 1):
			var offset := Vector2(float(x), float(y)) - command.cell_position
			var distance := offset.length()
			if distance > command.radius_cells:
				continue
			var index := y * _width + x
			if _claimable_mask[index] == 0:
				continue
			var transmission := _claimable_line_transmission(
				source_x,
				source_y,
				x,
				y,
				tuning.obstruction_falloff_per_cell
			)
			if transmission <= 0.0:
				continue
			# Support is the Plant mass this cell is being pushed away from: the cell
			# looks back toward the burst origin, so a frontier can be driven several
			# cells outward while open ground far from any Plant still receives nothing.
			var support := maxf(0.0, _control[index])
			if distance > 0.001:
				var inward := -offset / distance
				for reach_step in range(1, 3):
					var sample := Vector2(float(x), float(y)) + inward * (
						support_reach * float(reach_step) * 0.5
					)
					var sample_x := clampi(int(round(sample.x)), 0, _width - 1)
					var sample_y := clampi(int(round(sample.y)), 0, _height - 1)
					var sample_index := sample_y * _width + sample_x
					if _claimable_mask[sample_index] != 0:
						support = maxf(support, _control[sample_index])
			if support <= 0.0:
				continue
			var support_scale := clampf(support / support_reference, 0.0, 1.0)
			var normalized_falloff := 1.0 - distance / command.radius_cells
			var falloff := (
				normalized_falloff * normalized_falloff * (3.0 - 2.0 * normalized_falloff)
			) * transmission
			var old_control := _control[index]
			var mass_delta := command.mass * falloff * support_scale
			if old_control < 0.0:
				var resistance := 1.0 + _maturity[index] * tuning.maturity_resistance_bonus
				mass_delta *= command.hostile_conversion_factor / resistance
			_control[index] = clampf(old_control + mass_delta, -1.0, 1.0)
			if _owner_from_control(old_control) != _owner_from_control(_control[index]):
				_maturity[index] = 0.0
			if distance > 0.001 and command.pressure_cells > 0.0:
				var direction := offset / distance
				var impulse := command.pressure_cells * falloff * support_scale
				_pressure_x[index] = clampf(
					_pressure_x[index] + direction.x * impulse,
					-tuning.max_pressure_cells,
					tuning.max_pressure_cells
				)
				_pressure_y[index] = clampf(
					_pressure_y[index] + direction.y * impulse,
					-tuning.max_pressure_cells,
					tuning.max_pressure_cells
				)


func find_player_frontier_near(local_position: Vector2) -> Vector2:
	# Blooms erupt from ground the player already holds, so a caller asks the field
	# where its own border is instead of detonating at an arbitrary point.
	var cell_width := tuning.arena_size.x / float(_width)
	var cell_height := tuning.arena_size.y / float(_height)
	var best_position := Vector2(-1.0, -1.0)
	var best_distance := INF
	for y in range(_height):
		for x in range(_width):
			if _player_frontier_mask[y * _width + x] == 0:
				continue
			var candidate := Vector2(
				(float(x) + 0.5) * cell_width,
				(float(y) + 0.5) * cell_height
			)
			var candidate_distance := candidate.distance_squared_to(local_position)
			if candidate_distance < best_distance:
				best_distance = candidate_distance
				best_position = candidate
	return best_position


func _stamp_erosion(command: TerritoryCommand) -> void:
	var minimum_x := maxi(0, int(floor(command.cell_position.x - command.radius_cells)))
	var maximum_x := mini(_width - 1, int(ceil(command.cell_position.x + command.radius_cells)))
	var minimum_y := maxi(0, int(floor(command.cell_position.y - command.radius_cells)))
	var maximum_y := mini(_height - 1, int(ceil(command.cell_position.y + command.radius_cells)))

	for y in range(minimum_y, maximum_y + 1):
		for x in range(minimum_x, maximum_x + 1):
			var offset := Vector2(float(x), float(y)) - command.cell_position
			var distance := offset.length()
			if distance > command.radius_cells:
				continue
			var index := y * _width + x
			if _claimable_mask[index] == 0 or _control[index] <= 0.0:
				continue
			var normalized_falloff := 1.0 - distance / command.radius_cells
			var falloff := normalized_falloff * normalized_falloff * (3.0 - 2.0 * normalized_falloff)
			var resistance := 1.0 + _maturity[index] * tuning.maturity_resistance_bonus
			if _maturity[index] >= tuning.mature_threshold:
				resistance *= _mature_resistance_multiplier
			if _bramble_enabled and _is_player_frontier_cell(x, y):
				resistance *= lerpf(
					1.0,
					_bramble_resistance_multiplier,
					_bramble_development[index]
				)
				resistance *= (
					1.0
					+ _bramble_development[index]
					* tuning.bramble_development_erosion_resistance
				)
			var erosion := command.erosion * falloff / resistance
			_control[index] = maxf(0.0, _control[index] - erosion)
			_disturb_bramble_development(index, erosion)
			if _control[index] <= tuning.ownership_threshold:
				_maturity[index] = maxf(0.0, _maturity[index] - erosion)


func _stamp_hostile_growth(command: TerritoryCommand) -> void:
	var source_x := clampi(int(round(command.cell_position.x)), 0, _width - 1)
	var source_y := clampi(int(round(command.cell_position.y)), 0, _height - 1)
	if _claimable_mask[source_y * _width + source_x] == 0:
		return
	var minimum_x := maxi(0, int(floor(command.cell_position.x - command.radius_cells)))
	var maximum_x := mini(_width - 1, int(ceil(command.cell_position.x + command.radius_cells)))
	var minimum_y := maxi(0, int(floor(command.cell_position.y - command.radius_cells)))
	var maximum_y := mini(_height - 1, int(ceil(command.cell_position.y + command.radius_cells)))

	for y in range(minimum_y, maximum_y + 1):
		for x in range(minimum_x, maximum_x + 1):
			var offset := Vector2(float(x), float(y)) - command.cell_position
			var distance := offset.length()
			if distance > command.radius_cells:
				continue
			var index := y * _width + x
			if _claimable_mask[index] == 0:
				continue
			if not _is_claimable_line_clear(source_x, source_y, x, y):
				continue
			var normalized_falloff := 1.0 - distance / command.radius_cells
			var falloff := normalized_falloff * normalized_falloff * (3.0 - 2.0 * normalized_falloff)
			var old_control := _control[index]
			var hostile_delta := command.hostile_mass * falloff
			if old_control > 0.0:
				var resistance := 1.0 + _maturity[index] * tuning.maturity_resistance_bonus
				if _maturity[index] >= tuning.mature_threshold:
					resistance *= _mature_resistance_multiplier
				if _bramble_enabled and _is_player_frontier_cell(x, y):
					resistance *= lerpf(
						1.0,
						_bramble_resistance_multiplier,
						_bramble_development[index]
					)
				hostile_delta /= resistance
				_disturb_bramble_development(index, hostile_delta)
			_control[index] = clampf(old_control - hostile_delta, -1.0, 1.0)
			if _owner_from_control(old_control) != _owner_from_control(_control[index]):
				_maturity[index] = 0.0


func _stamp_maturity_suppression(command: TerritoryCommand) -> void:
	var source_x := clampi(int(round(command.cell_position.x)), 0, _width - 1)
	var source_y := clampi(int(round(command.cell_position.y)), 0, _height - 1)
	if _claimable_mask[source_y * _width + source_x] == 0:
		return
	var minimum_x := maxi(0, int(floor(command.cell_position.x - command.radius_cells)))
	var maximum_x := mini(_width - 1, int(ceil(command.cell_position.x + command.radius_cells)))
	var minimum_y := maxi(0, int(floor(command.cell_position.y - command.radius_cells)))
	var maximum_y := mini(_height - 1, int(ceil(command.cell_position.y + command.radius_cells)))

	for y in range(minimum_y, maximum_y + 1):
		for x in range(minimum_x, maximum_x + 1):
			var offset := Vector2(float(x), float(y)) - command.cell_position
			var distance := offset.length()
			if distance > command.radius_cells:
				continue
			var index := y * _width + x
			if _claimable_mask[index] == 0 or _control[index] <= tuning.ownership_threshold:
				continue
			if not _is_claimable_line_clear(source_x, source_y, x, y):
				continue
			var normalized_falloff := 1.0 - distance / command.radius_cells
			var falloff := normalized_falloff * normalized_falloff * (3.0 - 2.0 * normalized_falloff)
			# Clamped both ways: a negative suppression is how a mechanic supports
			# maturity instead of stripping it, and maturity is 0-to-1 everywhere.
			_maturity[index] = clampf(
				_maturity[index] - command.maturity_suppression * falloff,
				0.0,
				1.0
			)



func _claimable_line_transmission(
	start_x: int,
	start_y: int,
	end_x: int,
	end_y: int,
	falloff_per_cell: float
) -> float:
	# How much of a stamp survives the trip from its source to this cell.
	#
	# The straight-line test this replaces answered yes or no, so a single blocked
	# cell removed everything behind it and one corner of a wall cast a hard wedge
	# that widened forever. Material does not stop dead at an edge: it bends around
	# it, weaker for every bit of obstruction it had to get past. Counting the
	# blocked cells the ray crosses and attenuating by them gives that for the price
	# of the walk we were already doing — one clipped corner barely dims, a real wall
	# takes everything.
	var delta_x := end_x - start_x
	var delta_y := end_y - start_y
	var steps_x := absi(delta_x)
	var steps_y := absi(delta_y)
	var direction_x := signi(delta_x)
	var direction_y := signi(delta_y)
	var x := start_x
	var y := start_y
	var progress_x := 0
	var progress_y := 0
	var blocked := 0

	if _claimable_mask[y * _width + x] == 0:
		return 0.0

	while progress_x < steps_x or progress_y < steps_y:
		var decision := (
			(1 + 2 * progress_x) * steps_y
			- (1 + 2 * progress_y) * steps_x
		)
		if decision == 0:
			# A ray threading a blocked corner diagonally is still obstructed by it.
			if (
				_claimable_mask[y * _width + x + direction_x] == 0
				or _claimable_mask[(y + direction_y) * _width + x] == 0
			):
				blocked += 1
			x += direction_x
			y += direction_y
			progress_x += 1
			progress_y += 1
		elif decision < 0:
			x += direction_x
			progress_x += 1
		else:
			y += direction_y
			progress_y += 1
		if _claimable_mask[y * _width + x] == 0:
			blocked += 1
			if blocked >= 3:
				# Past a couple of cells of solid ground nothing gets through, and
				# stopping here keeps the walk as cheap as the old one.
				return 0.0
	if blocked <= 0:
		return 1.0
	return maxf(0.0, 1.0 - falloff_per_cell * float(blocked))


func _is_claimable_line_clear(start_x: int, start_y: int, end_x: int, end_y: int) -> bool:
	var delta_x := end_x - start_x
	var delta_y := end_y - start_y
	var steps_x := absi(delta_x)
	var steps_y := absi(delta_y)
	var direction_x := signi(delta_x)
	var direction_y := signi(delta_y)
	var x := start_x
	var y := start_y
	var progress_x := 0
	var progress_y := 0

	if _claimable_mask[y * _width + x] == 0:
		return false

	while progress_x < steps_x or progress_y < steps_y:
		var decision := (
			(1 + 2 * progress_x) * steps_y
			- (1 + 2 * progress_y) * steps_x
		)
		if decision == 0:
			# A ray touching a blocked corner must not leak diagonally between walls.
			if (
				_claimable_mask[y * _width + x + direction_x] == 0
				or _claimable_mask[(y + direction_y) * _width + x] == 0
			):
				return false
			x += direction_x
			y += direction_y
			progress_x += 1
			progress_y += 1
		elif decision < 0:
			x += direction_x
			progress_x += 1
		else:
			y += direction_y
			progress_y += 1

		if _claimable_mask[y * _width + x] == 0:
			return false

	return true


func _swap_simulation_buffers() -> void:
	var control_swap := _control
	_control = _next_control
	_next_control = control_swap
	var maturity_swap := _maturity
	_maturity = _next_maturity
	_next_maturity = maturity_swap
	var pressure_x_swap := _pressure_x
	_pressure_x = _next_pressure_x
	_next_pressure_x = pressure_x_swap
	var pressure_y_swap := _pressure_y
	_pressure_y = _next_pressure_y
	_next_pressure_y = pressure_y_swap


func _try_enqueue_topology_neighbor(index: int, label: int, tail: int) -> int:
	if _topology_labels[index] != -1:
		return tail
	if _claimable_mask[index] == 0 or _control[index] <= tuning.ownership_threshold:
		_topology_labels[index] = -2
		return tail
	_topology_labels[index] = label
	_topology_queue[tail] = index
	return tail + 1


func _owner_from_control(control: float) -> int:
	if control > tuning.ownership_threshold:
		return 1
	if control < -tuning.ownership_threshold:
		return -1
	return 0


func _disturb_bramble_development(index: int, applied_change: float) -> void:
	if not _bramble_enabled or applied_change <= 0.0:
		return
	# Thorns degrade through bands rather than snapping to zero, so a frontier
	# being chewed keeps part of its defence on the way down.
	var development_loss := minf(
		applied_change * tuning.bramble_disturbance_per_erosion,
		tuning.bramble_disturbance_maximum_step
	)
	_bramble_development[index] = maxf(0.0, _bramble_development[index] - development_loss)
	_bramble_alert[index] = tuning.bramble_attack_growth_seconds


func _is_player_frontier_cell(x: int, y: int) -> bool:
	var index := y * _width + x
	if _claimable_mask[index] == 0 or _control[index] <= tuning.ownership_threshold:
		return false
	if x > 0:
		var left := index - 1
		if _claimable_mask[left] != 0 and _control[left] <= tuning.ownership_threshold:
			return true
	if x < _width - 1:
		var right := index + 1
		if _claimable_mask[right] != 0 and _control[right] <= tuning.ownership_threshold:
			return true
	if y > 0:
		var up := index - _width
		if _claimable_mask[up] != 0 and _control[up] <= tuning.ownership_threshold:
			return true
	if y < _height - 1:
		var down := index + _width
		if _claimable_mask[down] != 0 and _control[down] <= tuning.ownership_threshold:
			return true
	return false


func _rebuild_player_frontier_mask() -> void:
	for y in range(_height):
		for x in range(_width):
			_player_frontier_mask[y * _width + x] = int(_is_player_frontier_cell(x, y))


func _is_border_cell(x: int, y: int) -> bool:
	return x <= 1 or y <= 1 or x >= _width - 2 or y >= _height - 2


func _is_rock_cell(normalized_x: float, normalized_y: float) -> bool:
	# Split basalt ridges make a central pressure choke without turning the arena into tiles.
	var ridge := absf(normalized_x - 0.505) < 0.018
	if ridge and (normalized_y < 0.405 or normalized_y > 0.595):
		return true
	var upper_island := Vector2(
		(normalized_x - 0.350) / 0.050,
		(normalized_y - 0.235) / 0.075
	).length() < 1.0
	var lower_island := Vector2(
		(normalized_x - 0.625) / 0.055,
		(normalized_y - 0.845) / 0.060
	).length() < 1.0
	return upper_island or lower_island


func _boundary_noise(x: int, y: int) -> float:
	# Low-frequency waves keep the fixture organic without creating isolated speckles.
	return (
		sin(float(x) * 0.145 + float(y) * 0.031) * 0.024
		+ sin(float(y) * 0.173 - float(x) * 0.019) * 0.018
	)
