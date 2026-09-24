class_name CankerDirector
extends Node2D

## Turns ground the player has abandoned into an interior front.
##
## A Canker is Rot that has been held long enough to become infrastructure. Once one
## forms, a slice of ordinary reinforcements stops walking in from the perimeter and
## arrives beside the Knot instead - the same enemies, entering somewhere the player
## chose not to defend. Section 18 of the consequence rework is emphatic about which
## half that is: a Canker changes spawn *topology*, never spawn *quantity*.
##
## Knots have no health, and damage cannot remove one. The only answer is to take the
## ground back, which is the whole message the structure exists to deliver: this is
## here because the enemy owns this ground.
##
## The ladder itself lives in `CankerRules`. What is here is everything that needs the
## arena: where sites sit, how their Rot is measured, what a Knot looks like, and which
## spawn requests it is allowed to answer.

## A Knot has drawn itself in and is about to open. Carries the arena position so the
## interface can say where rather than merely that.
signal canker_warning_started(local_position: Vector2)
## A Knot has established and is redirecting spawns.
signal canker_formed(local_position: Vector2)
## The player reclaimed the ground under a Knot and it has withered.
signal canker_withered(local_position: Vector2)
## A site that was warning lost its ground before the warning ran out.
signal canker_warning_cancelled(local_position: Vector2)

## The authored variations. Which one a Knot wears, and how far it is turned, are both
## drawn when it forms: the paintings are irregular enough that rotation alone reads as
## a different growth, and a field with four of them should never show the same
## silhouette twice in the same corner.
const CANKER_TEXTURES: Array[Texture2D] = [
	preload("res://assets/art/cankers/canker_1.png"),
	preload("res://assets/art/cankers/canker_2.png"),
	preload("res://assets/art/cankers/canker_3.png"),
	preload("res://assets/art/cankers/canker_4.png"),
]
const INVALID_POSITION := Vector2(-99999.0, -99999.0)
## Blight at which the run is allowed one Knot beyond what its act would give it.
const BLIGHT_EXTRA_KNOT_LEVEL := 3
## The run's own face, rather than `ThemeDB.fallback_font`: this text is painted onto
## the board beside a watercolour structure, and the stock sans is the one thing on the
## field that would read as a debug overlay.
const LABEL_FONT: Font = preload("res://assets/fonts/beholden/Beholden-Medium.ttf")

@export_group("Collaborators")
## Supplies the Rot measurement every decision here is made from.
@export var territory_field: TerritoryField
## Keeps Knots from forming on top of Grandma, and interior spawns away from her.
@export var player: Player
## Says which wave the run is on, which is what gates the first Canker. Optional:
## without it sites arm immediately, which is the behaviour a probe driving this
## component on its own wants.
@export var wave_director: WaveDirector

@export_group("Eligibility")
## Radius the local Rot ratio is measured over. This is the size of the thing being
## judged: a small radius calls one chewed pocket a Canker, a large one waits for most
## of a quadrant to go.
@export_range(40.0, 300.0, 5.0) var sample_radius := 110.0
## Rot share that starts a site climbing, and the lower share that knocks it back down.
## Kept apart on purpose - see `CankerRules.qualifies`.
@export_range(0.0, 1.0, 0.01) var activation_rot_ratio := 0.65
@export_range(0.0, 1.0, 0.01) var cancel_rot_ratio := 0.50
## Seconds of held Rot before a site starts warning, and how long the warning runs.
## Doubled from 10 once Knots started costing Green: rot is almost everywhere, so
## the hold is what sets how soon a freed slot fills again.
@export_range(1.0, 60.0, 0.5) var hold_time := 20.0
## Long enough for the pointer over Grandma to be read and turned toward.
@export_range(0.5, 10.0, 0.1) var warning_time := 4.0
## Knots allowed at once at the Campaign's most permissive. Two is an interior front;
## more is a second perimeter, which is why only a heavily Blighted Act IV reaches it.
## Quick, and any run without a wave director, uses this number flat.
@export_range(1, 6, 1) var maximum_active_knots := 2
## How often the whole site grid is measured. Section 17 asks for 2 to 4 Hz, which is
## far below a frame and still well inside the reaction time of a ten-second hold.
@export_range(1.0, 10.0, 0.5) var evaluation_hz := 3.0
## The first wave on which a site may begin climbing toward a Knot.
##
## The arena opens with a hostile basin already on it, and that basin clears the
## activation ratio on its own, so without a gate the first Canker forms about twelve
## seconds in - on ground the run has not yet had a chance to contest. That reads as a
## timer rather than as the consequence of ignoring something, which is the one thing
## section 14 asks this system not to become.
##
## Gated on the wave rather than on a stopwatch because the wave is the run's own unit
## of escalation and the only one the player can actually read: "Cankers start at wave
## three" is a rule somebody can hold, where forty-five seconds is a number they would
## have to discover. Both modes run sixty-second waves, so this means the same thing in
## each.
## Act I is Canker-free: the arena opens with a hostile basin on it and the run has
## not yet been given the tools to contest it, so a Knot there would be a timer
## rather than a consequence. Wave 6 opens Act II, which is where the Campaign's
## first meaningful Canker risk belongs.
@export_range(1, 25, 1) var first_wave := 6
## Samples every Nth cell on each axis when measuring. Over the hundreds of cells in a
## sample radius this does not move the ratio anywhere near the dead band.
@export_range(1, 4, 1) var sample_cell_stride := 2

@export_group("Placement")
## How far a new Knot must be from Grandma. A Knot that forms under the player is not
## a consequence they can read; it is damage that already happened.
@export_range(0.0, 600.0, 10.0) var minimum_player_distance := 210.0
## How far Knots must be from each other, so two do not share one hostile blob.
@export_range(0.0, 600.0, 10.0) var minimum_knot_spacing := 220.0
## Seconds before ground that lost a Knot may grow another. The player won that fight
## and should get to use the room it bought.
@export_range(0.0, 60.0, 0.5) var reestablish_cooldown := 8.0
## Seconds after any Knot forms or withers before another may start warning, anywhere.
##
## Rot covers most of a late board, so dozens of sites sit climbing toward a Knot at
## once, restarting their hold every time they are refused a slot. The moment the
## player cleared one, the next finished its hold within seconds and formed somewhere
## else about fourteen seconds after the first withered -- the reward for taking one
## back was another. A wave's worth of quiet is what taking one back buys now.
@export_range(0.0, 300.0, 5.0) var formation_cooldown := 60.0

@export_group("Destruction")
## Rot share a Knot's ground must fall below to start withering, and how long it must
## stay there. Nothing else removes one.
@export_range(0.0, 1.0, 0.01) var destroy_rot_ratio := 0.35
@export_range(0.0, 10.0, 0.1) var destroy_hold_time := 1.0

@export_group("Creep")
## A Knot pushes Rot outward along a front that widens the longer it stands. Before
## this a Knot changed only where some enemies entered, formed in ground the player had
## already given up, and could stand from Wave 6 to the end of the run without costing
## anything -- measured, both of a run's Knots did exactly that. Green is the run's
## health, so a structure that eats it is the one that has to be answered.
##
## The push is ordinary hostile growth, so everything that already resists Rot --
## maturity, Bramble's hedge, Root's Mature Strength -- resists a Knot as well.
@export_range(0.1, 5.0, 0.05) var creep_interval_seconds := 0.4
## Stamps laid across the fan each pulse, how wide the fan is, and how hard each one
## pushes.
@export_range(1, 16, 1) var creep_points := 5
@export_range(0.0, 3.0, 0.05) var creep_fan_radians := 0.9
@export_range(0.0, 5.0, 0.05) var creep_strength := 0.5
## Size of each stamp, as a multiple of a Grazer's bite.
@export_range(0.2, 4.0, 0.05) var creep_stamp_radius := 1.3
## The front starts at the Knot's own edge and reaches this far after this long.
@export_range(40.0, 600.0, 5.0) var creep_maximum_radius := 240.0
@export_range(1.0, 600.0, 1.0) var creep_growth_seconds := 90.0

@export_group("Spawn redirection")
## Share of ordinary reinforcements one Knot may pull inside, and the ceiling across
## all of them. The cap is the part that keeps the perimeter the main entrance.
@export_range(0.0, 1.0, 0.01) var redirect_share_per_knot := 0.15
@export_range(0.0, 1.0, 0.01) var maximum_redirect_share := 0.25
## The ring around a Knot an interior spawn may appear in. Off the Knot itself, and
## close enough that it reads as having come out of it.
@export_range(0.0, 200.0, 5.0) var minimum_spawn_offset := 42.0
@export_range(0.0, 400.0, 5.0) var maximum_spawn_offset := 120.0
## How far an interior spawn is kept from Grandma. Larger than the perimeter exclusion:
## an enemy appearing inside the field has less ground to cross before it reaches her.
@export_range(0.0, 600.0, 10.0) var spawn_player_exclusion := 190.0

@export_group("Appearance")
## Painted diameter of an established Knot, in arena pixels.
@export_range(40.0, 400.0, 5.0) var knot_diameter := 150.0
## The dark ring that gathers while a site entrenches, and the colour it draws in.
@export var telegraph_color := Color(0.28, 0.06, 0.20, 1.0)
@export_range(0.0, 1.0, 0.01) var telegraph_maximum_alpha := 0.55
## Pulses per second at the start of entrenchment and during the final warning. The
## rate climbing is most of what makes the warning legible without text.
@export_range(0.1, 6.0, 0.1) var telegraph_slow_hz := 0.7
@export_range(0.1, 12.0, 0.1) var telegraph_warning_hz := 3.4
## Seconds a formed Knot spends swelling to full size, and the flash it throws when it
## sends an enemy through.
@export_range(0.0, 4.0, 0.05) var emergence_seconds := 0.45
@export_range(0.0, 2.0, 0.05) var redirect_flash_seconds := 0.35

@export_group("Warning text")
## What the final seconds before a Knot say, and what the Knot says as it opens.
##
## Painted beside the region rather than announced across the top of the screen, which
## is section 22.3's whole point about this warning: it is a thing happening *there*,
## and a banner would make a local consequence read as a global catastrophe. The ring
## already says something is coming; the words say what.
##
## The second one exists so the structure is somewhere named. A player who never reads
## the word cannot look a Canker up, and an entry nothing on screen leads to is exactly
## the closed loop the glossary was cut back to remove on the 17th.
@export var warning_text := "ROT TAKING ROOT"
@export var formed_text := "CANKER"
## Seconds the name stays up after a Knot opens. Long enough to read once, and gone
## before it becomes part of the furniture.
@export_range(0.0, 8.0, 0.1) var formed_text_seconds := 2.2
## Arena pixels. Small: this is a caption on a region, not a headline.
@export_range(6, 40, 1) var label_font_size := 13
@export var label_color := Color(0.957, 0.925, 0.867, 1.0)
## Painted behind the letters so they survive being read against Rot, Green, paper and
## the Knot itself, none of which can be relied on to be any particular value.
@export var label_outline_color := Color(0.06, 0.02, 0.05, 0.95)
@export_range(0.0, 12.0, 0.5) var label_outline_size := 4.0
## Gap between the bottom of the ring - or of the Knot - and the top of the text.
@export_range(0.0, 60.0, 1.0) var label_gap := 9.0
## Seconds the text takes to arrive. The ring is already pulsing by then, so text that
## appeared instantly would read as a different event rather than as the same one
## getting louder.
@export_range(0.0, 2.0, 0.05) var label_fade_seconds := 0.3
## Above the arena's obstacle layer, which sits at 10. See `LabelLayer`.
@export_range(0, 40, 1) var label_z_index := 11

var _sites: Array[Site] = []
var _settings := CankerRules.Settings.new()
var _random := RandomNumberGenerator.new()
var _evaluation_remaining := 0.0
var _since_evaluation := 0.0
var _active_knots := 0
var _elapsed := 0.0
var _redirects_served := 0
var _formation_cooldown_remaining := 0.0
var _label_layer: LabelLayer


class LabelLayer:
	extends Node2D

	## The warning text, drawn above the arena walls rather than under them.
	##
	## The Canker layer sits at z_index 2 and the arena's obstacle layer at 10, so a
	## warning beside an interior wall came out with the middle of the words behind the
	## stonework - "ROT TA...OOT", which is worse than no warning because it looks like a
	## rendering fault rather than a message. Raising the director itself would take the
	## Knots and telegraph rings up with it, and those are ground: a wall in front of one
	## *should* cover it. So only the words move, the way `CombatDirector` moves only its
	## damage numbers.
	##
	## A child of the director, so it shares the transform and the positions need no
	## adjustment, with an absolute z index that ignores the parent's.
	var director: CankerDirector

	func _process(_delta: float) -> void:
		# Redrawn from here rather than by the director, because the text fades on a clock
		# of its own and anything that changes a site - a restore, a probe reaching in -
		# would otherwise have to know to redraw two nodes instead of one.
		queue_redraw()

	func _draw() -> void:
		if director != null:
			director.draw_labels(self)


class Site:
	extends RefCounted
	## One candidate centre on the coarse grid, carrying whatever stage it has reached.
	##
	## Every site exists for the whole run rather than being created when ground turns:
	## the grid is a few dozen entries, and a site that remembers its own cooldown is
	## what stops a reclaimed patch from immediately growing the same Knot again.
	var position := Vector2.ZERO
	var stage := CankerRules.Stage.INACTIVE
	var hold_timer := 0.0
	var warning_timer := 0.0
	var rot_ratio := 0.0
	var cooldown_remaining := 0.0
	## Drawn once, when the Knot forms, and kept until it withers.
	var texture_index := 0
	var rotation := 0.0
	## Seconds since establishment, which the emergence swell reads.
	var age := 0.0
	## Counts down after this Knot answers a spawn request, for the pulse.
	var flash_remaining := 0.0
	## Counts down to the next push of Rot.
	var creep_remaining := 0.0


func _ready() -> void:
	_label_layer = LabelLayer.new()
	_label_layer.director = self
	_label_layer.z_as_relative = false
	_label_layer.z_index = label_z_index
	add_child(_label_layer)
	_clip_to_arena()
	reset_director()


func _clip_to_arena() -> void:
	## Hard-clips everything this layer draws to the ground inside the outer wall.
	##
	## A Knot is a painting a hundred and fifty pixels across placed at a point, and a
	## site near the edge puts half of it through the wall. Clipping is the right answer
	## rather than insetting the sites: ground beside the wall is exactly the ground a
	## player abandons first, so a Canker has to be able to grow there and simply be cut
	## off by the boundary the way the washes already are.
	##
	## Done through RenderingServer because a CanvasItem has no draw-time clip rect -
	## `clip_children` masks a node's *children*, and every Knot here is an immediate
	## draw call on this node rather than a child node.
	##
	## Re-applied at the end of every `_draw`, not once in `_ready`: the engine recomputes
	## an item's rect from its commands each time it is redrawn, which drops the custom
	## one. Set it only at startup and the first redraw quietly unclips the layer.
	if territory_field == null or territory_field.tuning == null:
		return
	var item := get_canvas_item()
	RenderingServer.canvas_item_set_custom_rect(
		item, true, territory_field.get_playable_bounds_local()
	)
	RenderingServer.canvas_item_set_clip(item, true)


func reset_director() -> void:
	_clip_to_arena()
	_active_knots = 0
	_elapsed = 0.0
	_redirects_served = 0
	_formation_cooldown_remaining = 0.0
	_evaluation_remaining = 0.0
	_since_evaluation = 0.0
	_build_sites()
	queue_redraw()


func set_run_seed(seed_value: int) -> void:
	## Replaying a seed should replay which paintings appeared and how they sat, the
	## same way it already replays the wave decks and the draft.
	_random.seed = seed_value


func advance(delta: float) -> void:
	if territory_field == null or delta <= 0.0:
		return
	_elapsed += delta
	_since_evaluation += delta
	_formation_cooldown_remaining = maxf(0.0, _formation_cooldown_remaining - delta)
	for site in _sites:
		if site.cooldown_remaining > 0.0:
			site.cooldown_remaining = maxf(0.0, site.cooldown_remaining - delta)
		if site.stage == CankerRules.Stage.ACTIVE:
			site.age += delta
			site.flash_remaining = maxf(0.0, site.flash_remaining - delta)
			site.creep_remaining -= delta
			if site.creep_remaining <= 0.0:
				site.creep_remaining = creep_interval_seconds
				_push_creep(site)
	if not is_armed():
		# Measured but not judged. Sites keep their clocks at zero until the gate wave,
		# so the first thing that can happen once it arrives is a site starting to climb
		# rather than several arriving already half-way up.
		return
	_evaluation_remaining -= delta
	if _evaluation_remaining <= 0.0:
		_evaluate_sites(_since_evaluation)
		_since_evaluation = 0.0
		_evaluation_remaining = 1.0 / maxf(0.1, evaluation_hz)
	queue_redraw()


## Whether the run has reached the wave that lets sites begin climbing.
func is_armed() -> bool:
	return wave_director == null or wave_director.get_current_wave_number() >= first_wave


## How many Knots the run may currently hold.
##
## The Campaign's escalation ladder, and the only place the acts reach this system:
## Act II may hold one interior front, Act III two, Act IV three. A Canker is still
## made by losing ground and by nothing else -- the act decides how much of the board
## the player is allowed to have abandoned at once, not whether abandoning it costs
## anything.
##
## A heavily Blighted run gets one more. That is the Director and this system talking
## without merging: Blight does not create a Knot, it widens the room for the ground
## the player is already failing to hold.
func get_maximum_knots_now() -> int:
	if wave_director == null or not wave_director.is_campaign_mode():
		return maximum_active_knots
	var allowed := clampi(wave_director.get_current_act() - 1, 1, maximum_active_knots)
	if wave_director.get_blight_level() >= BLIGHT_EXTRA_KNOT_LEVEL:
		allowed += 1
	return clampi(allowed, 1, maximum_active_knots + 1)


## Whether any Knot is established. Cheap enough for a spawn path to ask every time.
func has_active_knots() -> bool:
	return _active_knots > 0


func get_active_knot_count() -> int:
	return _active_knots


## The share of ordinary reinforcements that should enter through Knots right now.
func get_redirect_share() -> float:
	return CankerRules.redirect_share(
		_active_knots, redirect_share_per_knot, maximum_redirect_share
	)


## How many spawns have actually come through a Knot this run. Reported rather than
## inferred, because the one thing this system must never do is add enemies, and a
## count the tests can read is how that stays true.
func get_redirects_served() -> int:
	return _redirects_served


func get_active_knot_positions() -> PackedVector2Array:
	var positions := PackedVector2Array()
	for site in _sites:
		if site.stage == CankerRules.Stage.ACTIVE:
			positions.append(site.position)
	return positions


## An arena point beside an active Knot for a reinforcement to enter from, or
## `INVALID_POSITION` when this request should stay on the perimeter.
##
## Answers with a *candidate*. Whether the ground there can actually hold the enemy is
## the spawner's question, and it already knows how to ask it; a point refused there
## falls back to the perimeter rather than being retried, because section 19 would
## rather a spawn be ordinary than be late.
func request_interior_spawn(forced: bool = false) -> Vector2:
	if _active_knots <= 0:
		return INVALID_POSITION
	# `forced` is the authored Canker Reinforcement recipe, which the Campaign buys
	# *because* a Knot exists. The share below is the rule for ordinary
	# reinforcements that merely happen past one, and applying it to a pack the wave
	# table deliberately aimed at a Knot would make that recipe silently ordinary
	# five times out of six. The cap on how many enemies exist is untouched either
	# way: this still only answers where one comes in.
	if not forced and _random.randf() >= get_redirect_share():
		return INVALID_POSITION
	var knot := _pick_active_knot()
	if knot == null:
		return INVALID_POSITION
	var player_position := player.get_arena_position() if player != null else INVALID_POSITION
	for _attempt in range(8):
		var angle := _random.randf() * TAU
		var distance := _random.randf_range(
			minimum_spawn_offset, maxf(minimum_spawn_offset, maximum_spawn_offset)
		)
		var candidate := knot.position + Vector2.from_angle(angle) * distance
		if not territory_field.contains_local_point(candidate):
			continue
		if (
			player_position.x > -90000.0
			and candidate.distance_to(player_position) < spawn_player_exclusion
		):
			continue
		return candidate
	return INVALID_POSITION


## Told by the spawner that a point it was handed is actually being used.
##
## Separate from `request_interior_spawn` because the ground under a candidate is the
## spawner's question, and counting a redirect the field then refused would make the
## one number that proves this system adds no enemies quietly wrong.
func notify_spawn_redirected(local_position: Vector2) -> void:
	_redirects_served += 1
	var nearest: Site = null
	var nearest_distance := INF
	for site in _sites:
		if site.stage != CankerRules.Stage.ACTIVE:
			continue
		var distance := site.position.distance_squared_to(local_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = site
	if nearest != null:
		nearest.flash_remaining = redirect_flash_seconds


func _pick_active_knot() -> Site:
	var active: Array[Site] = []
	for site in _sites:
		if site.stage == CankerRules.Stage.ACTIVE:
			active.append(site)
	if active.is_empty():
		return null
	return active[_random.randi_range(0, active.size() - 1)]


func _build_sites() -> void:
	_sites.clear()
	if territory_field == null or territory_field.tuning == null:
		return
	# A lattice one radius apart, so neighbouring discs overlap by half and a hostile
	# region cannot sit in a gap between two sites without either of them noticing it.
	var arena := territory_field.tuning.arena_size
	var spacing := maxf(40.0, sample_radius)
	var columns := maxi(1, int(floor(arena.x / spacing)))
	var rows := maxi(1, int(floor(arena.y / spacing)))
	var step := Vector2(arena.x / float(columns), arena.y / float(rows))
	for row in range(rows):
		for column in range(columns):
			var site := Site.new()
			site.position = Vector2(
				(float(column) + 0.5) * step.x,
				(float(row) + 0.5) * step.y
			)
			_sites.append(site)


func _evaluate_sites(delta: float) -> void:
	_settings.activation_ratio = activation_rot_ratio
	_settings.cancel_ratio = cancel_rot_ratio
	_settings.hold_time = hold_time
	_settings.warning_time = warning_time
	_settings.destroy_ratio = destroy_rot_ratio
	_settings.destroy_hold_time = destroy_hold_time
	# Sites that reached an edge this tick are collected rather than acted on in grid
	# order, then ranked. Ground goes to Rot in sheets, so a dozen sites routinely cross
	# the same threshold on the same tick; taking them in array order would put the Knot
	# in the top-left of the blob instead of the worst part of the board.
	var ready_to_warn: Array[Site] = []
	var ready_to_form: Array[Site] = []
	for site in _sites:
		site.rot_ratio = territory_field.measure_rot_ratio_in_radius(
			site.position, sample_radius, sample_cell_stride
		)
		if site.cooldown_remaining > 0.0 and site.stage != CankerRules.Stage.ACTIVE:
			# Still recovering from a Knot the player destroyed. It keeps measuring so
			# the telegraph can resume the moment the cooldown ends.
			continue
		var was_active := site.stage == CankerRules.Stage.ACTIVE
		var transition := CankerRules.advance_stage(
			site.stage, site.rot_ratio, site.hold_timer, site.warning_timer, delta, _settings
		)
		if transition.entered_warning:
			# Left at the top of ACCUMULATING until the ranking below says whether this
			# is one of the sites that gets to promise a Knot.
			site.hold_timer = transition.hold_timer
			ready_to_warn.append(site)
			continue
		if transition.formed:
			ready_to_form.append(site)
			site.hold_timer = transition.hold_timer
			continue
		site.stage = transition.stage
		site.hold_timer = transition.hold_timer
		site.warning_timer = transition.warning_timer
		if transition.cancelled_warning:
			canker_warning_cancelled.emit(site.position)
		if transition.withered and was_active:
			_wither_knot(site)
	ready_to_warn.sort_custom(_score_descending)
	for site in ready_to_warn:
		if not _can_open_knot(site):
			# No slot, too close to a committed site, or still cooling down. It keeps
			# its Rot and starts the climb again rather than queueing: a site that
			# banked a finished hold would open the instant a slot freed, with no
			# telegraph in front of it.
			site.hold_timer = 0.0
			continue
		site.stage = CankerRules.Stage.WARNING
		site.warning_timer = warning_time
		canker_warning_started.emit(site.position)
	ready_to_form.sort_custom(_score_descending)
	for site in ready_to_form:
		if not _can_open_knot(site):
			site.stage = CankerRules.Stage.ACCUMULATING
			site.hold_timer = 0.0
			site.warning_timer = 0.0
			continue
		_open_knot(site)


func _score_descending(first: Site, second: Site) -> bool:
	return (
		CankerRules.candidate_score(first.rot_ratio, first.hold_timer, hold_time)
		> CankerRules.candidate_score(second.rot_ratio, second.hold_timer, hold_time)
	)


func _can_open_knot(site: Site) -> bool:
	## Whether this site may hold one of the Knot slots.
	##
	## Counted against sites that are *committed* - already a Knot, or warning about
	## one - rather than against established Knots alone. A warning is a promise that
	## something is about to open here, and a board where twenty-eight regions warn and
	## two deliver teaches the player to ignore the telegraph, which costs more than the
	## Knots themselves are worth.
	if site.cooldown_remaining > 0.0:
		return false
	# A site already warning keeps its promise; the cooldown only stops new ones.
	if site.stage != CankerRules.Stage.WARNING and _formation_cooldown_remaining > 0.0:
		return false
	if _committed_count(site) >= get_maximum_knots_now():
		return false
	var player_distance := (
		site.position.distance_to(player.get_arena_position())
		if player != null
		else INF
	)
	return CankerRules.is_site_clear(
		player_distance,
		minimum_player_distance,
		_distance_to_nearest_committed(site),
		minimum_knot_spacing
	)


func _committed_count(exclude: Site) -> int:
	var count := 0
	for site in _sites:
		if site == exclude:
			continue
		if site.stage == CankerRules.Stage.ACTIVE or site.stage == CankerRules.Stage.WARNING:
			count += 1
	return count


func _distance_to_nearest_committed(subject: Site) -> float:
	var nearest := -1.0
	for site in _sites:
		if site == subject:
			continue
		if site.stage != CankerRules.Stage.ACTIVE and site.stage != CankerRules.Stage.WARNING:
			continue
		var distance := subject.position.distance_to(site.position)
		if nearest < 0.0 or distance < nearest:
			nearest = distance
	return nearest


func _open_knot(site: Site) -> void:
	site.stage = CankerRules.Stage.ACTIVE
	site.hold_timer = 0.0
	site.warning_timer = 0.0
	site.age = 0.0
	site.flash_remaining = 0.0
	site.texture_index = _random.randi_range(0, CANKER_TEXTURES.size() - 1)
	site.rotation = _random.randf() * TAU
	_active_knots += 1
	_formation_cooldown_remaining = formation_cooldown
	canker_formed.emit(site.position)


## How far a Knot's front has reached.
func get_creep_radius(site_age: float) -> float:
	var start := knot_diameter * 0.5
	var progress := clampf(site_age / maxf(0.001, creep_growth_seconds), 0.0, 1.0)
	return lerpf(start, maxf(start, creep_maximum_radius), progress)


func _push_creep(site: Site) -> void:
	## One pulse of Rot: on the Knot itself, so the ground it stands on stays its own,
	## and along a fan aimed at the nearest Green within the front's reach.
	##
	## Aimed rather than spread round a ring. An even ring put its stamps on the Rot and
	## bare ground around the Knot almost every time, and measured it cost a patch of
	## Green beside it a handful of cells a minute -- which is the cosmetic Knot again.
	## Reaching for the player's territory is also the thing it should read as doing.
	if creep_strength <= 0.0:
		return
	territory_field.queue_hostile_growth(site.position, creep_strength, creep_stamp_radius)
	var nearest := territory_field.find_nearest_owned_cell(site.position)
	if nearest < 0:
		return
	var target := territory_field.get_cell_local_position(nearest)
	var distance := site.position.distance_to(target)
	var reach := get_creep_radius(site.age)
	if distance > reach:
		# Green beyond the front is safe for now. The front keeps widening.
		return
	var direction := (target - site.position).normalized()
	for index in range(creep_points):
		var spread := (
			(float(index) / float(maxi(1, creep_points - 1)) - 0.5) * creep_fan_radians
		)
		var point := site.position + direction.rotated(spread) * distance
		if territory_field.contains_local_point(point):
			territory_field.queue_hostile_growth(point, creep_strength, creep_stamp_radius)

func _wither_knot(site: Site) -> void:
	site.stage = CankerRules.Stage.INACTIVE
	site.hold_timer = 0.0
	site.warning_timer = 0.0
	site.age = 0.0
	site.flash_remaining = 0.0
	site.cooldown_remaining = reestablish_cooldown
	_active_knots = maxi(0, _active_knots - 1)
	_formation_cooldown_remaining = formation_cooldown
	canker_withered.emit(site.position)


## The Knots, the sites climbing toward one, and the ground still cooling down, in a
## form that survives the game being closed.
##
## Site positions are not stored. The grid is derived from the arena, so what a save
## carries is what each site *is* and this build rebuilds where it sits; the count is
## stored so a save from an arena that has since been re-authored can be noticed. That
## is the same question `TerritoryField.apply_state` asks about the cell grid, answered
## differently: a mismatch drops the Cankers rather than refusing the run, because a run
## resumed onto a clean board is still the run, where one resumed onto the wrong ground
## is not.
##
## The measured Rot ratio is left out deliberately - it is measured again on the first
## evaluation after the restore, off the field the save did bring back, and a stored one
## would be a second opinion about ground that is already on file. `flash_remaining` is
## left out for the reason `RunSnapshot` keeps no enemies: it is a third of a second of
## pulse belonging to a spawn that is not coming back.
func capture_state() -> Dictionary:
	var stages := PackedInt32Array()
	var hold_timers := PackedFloat32Array()
	var warning_timers := PackedFloat32Array()
	var cooldowns := PackedFloat32Array()
	var ages := PackedFloat32Array()
	var texture_indices := PackedInt32Array()
	var rotations := PackedFloat32Array()
	for site in _sites:
		stages.append(int(site.stage))
		hold_timers.append(site.hold_timer)
		warning_timers.append(site.warning_timer)
		cooldowns.append(site.cooldown_remaining)
		ages.append(site.age)
		texture_indices.append(site.texture_index)
		rotations.append(site.rotation)
	return {
		"site_count": _sites.size(),
		"stages": stages,
		"hold_timers": hold_timers,
		"warning_timers": warning_timers,
		"cooldowns": cooldowns,
		"ages": ages,
		"texture_indices": texture_indices,
		"rotations": rotations,
		"redirects_served": _redirects_served,
		"formation_cooldown": _formation_cooldown_remaining,
	}


## Puts the interior front back.
##
## Expects `reset_director` to have run first, the way `RunRoot.restore_snapshot` does
## it: that is what rebuilds the site grid the stages are laid back onto, and what
## re-seeds the generator so the Knots a resumed run grows *after* the save still follow
## the run seed.
##
## Nothing is emitted. `canker_formed` and the rest announce an edge - ground that has
## just been lost or just been won - and a restored Knot is neither; firing them here
## would tell a player continuing a run that a Canker is forming when what happened is
## that they pressed Continue.
func apply_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	var count := _sites.size()
	if int(state.get("site_count", -1)) != count:
		push_warning(
			"CankerDirector: a save with %d sites cannot be read onto this build's %d; "
			% [int(state.get("site_count", -1)), count]
			+ "the run resumes with no Cankers"
		)
		return
	var stages := _saved_ints(state, "stages", count)
	var hold_timers := _saved_floats(state, "hold_timers", count)
	var warning_timers := _saved_floats(state, "warning_timers", count)
	var cooldowns := _saved_floats(state, "cooldowns", count)
	var ages := _saved_floats(state, "ages", count)
	var texture_indices := _saved_ints(state, "texture_indices", count)
	var rotations := _saved_floats(state, "rotations", count)
	if stages.is_empty():
		return
	for index in range(count):
		var site := _sites[index]
		site.stage = clampi(
			stages[index], CankerRules.Stage.INACTIVE, CankerRules.Stage.ACTIVE
		) as CankerRules.Stage
		site.hold_timer = maxf(0.0, hold_timers[index])
		site.warning_timer = maxf(0.0, warning_timers[index])
		site.cooldown_remaining = maxf(0.0, cooldowns[index])
		site.age = maxf(0.0, ages[index])
		site.texture_index = posmod(texture_indices[index], CANKER_TEXTURES.size())
		site.rotation = rotations[index]
		site.rot_ratio = 0.0
		site.flash_remaining = 0.0
	_active_knots = 0
	for site in _sites:
		if site.stage == CankerRules.Stage.ACTIVE:
			_active_knots += 1
	_redirects_served = maxi(0, int(state.get("redirects_served", 0)))
	_formation_cooldown_remaining = maxf(0.0, float(state.get("formation_cooldown", 0.0)))
	queue_redraw()


## One saved column, or an empty array when the save does not hold it at the length the
## site grid needs. A short column is a truncated save rather than an older one, and
## reading half of it would leave the board in a state no run ever produced.
func _saved_floats(state: Dictionary, key: String, count: int) -> PackedFloat32Array:
	var column: Variant = state.get(key)
	if column is PackedFloat32Array and (column as PackedFloat32Array).size() == count:
		return column
	var empty := PackedFloat32Array()
	empty.resize(count)
	return empty


func _saved_ints(state: Dictionary, key: String, count: int) -> PackedInt32Array:
	var column: Variant = state.get(key)
	if column is PackedInt32Array and (column as PackedInt32Array).size() == count:
		return column
	return PackedInt32Array()


func _draw() -> void:
	for site in _sites:
		match site.stage:
			# Only the patch that is actually about to become a Knot is marked. Every
			# accumulating site drew its own ring, and on a board that is mostly Rot that
			# was twenty-odd pulsing circles for the whole back half of a run -- only two of
			# which could ever become anything.
			CankerRules.Stage.WARNING:
				_draw_telegraph(site)
			CankerRules.Stage.ACTIVE:
				_draw_knot(site)
	_clip_to_arena()


## The words beside each region, painted onto `LabelLayer` rather than onto this node.
func draw_labels(canvas: CanvasItem) -> void:
	for site in _sites:
		_draw_label(canvas, site)


func _draw_telegraph(site: Site) -> void:
	## Entrenching ground, drawn as a ring that tightens and quickens rather than as an
	## icon. Section 22 wants the player to read what is coming off the field itself.
	var progress := CankerRules.telegraph_progress(
		site.stage, site.hold_timer, site.warning_timer, _settings
	)
	var warning := site.stage == CankerRules.Stage.WARNING
	var pulse_hz := lerpf(telegraph_slow_hz, telegraph_warning_hz, progress if not warning else 1.0)
	var pulse := 0.5 + 0.5 * sin(_elapsed * TAU * pulse_hz)
	var strength := (0.35 + 0.65 * progress) if not warning else 1.0
	var alpha := telegraph_maximum_alpha * strength * lerpf(0.55, 1.0, pulse)
	# Tendrils drawing inward: the ring starts at the full sample radius and closes on
	# the centre as the hold completes, so the shape itself says where the Knot lands.
	var outer := lerpf(sample_radius, knot_diameter * 0.5, progress)
	var color := Color(telegraph_color.r, telegraph_color.g, telegraph_color.b, alpha)
	draw_arc(site.position, outer, 0.0, TAU, 48, color, 2.0 + 2.0 * progress, true)
	if warning:
		# A second, faster ring during the final seconds, closing on the centre.
		var closing := 1.0 - clampf(site.warning_timer / maxf(0.001, warning_time), 0.0, 1.0)
		draw_arc(
			site.position,
			lerpf(outer, knot_diameter * 0.25, closing),
			0.0,
			TAU,
			40,
			Color(telegraph_color.r, telegraph_color.g, telegraph_color.b, alpha * 0.8),
			3.0,
			true
		)
	var spokes := 6
	for index in range(spokes):
		var angle := float(index) / float(spokes) * TAU + progress * 0.6
		var direction := Vector2.from_angle(angle)
		draw_line(
			site.position + direction * outer,
			site.position + direction * lerpf(outer, 0.0, 0.35 + 0.5 * progress),
			Color(telegraph_color.r, telegraph_color.g, telegraph_color.b, alpha * 0.75),
			1.5 + progress,
			true
		)


func _draw_knot(site: Site) -> void:
	var texture := CANKER_TEXTURES[posmod(site.texture_index, CANKER_TEXTURES.size())]
	if texture == null:
		return
	var emergence := (
		clampf(site.age / maxf(0.001, emergence_seconds), 0.0, 1.0)
		if emergence_seconds > 0.0
		else 1.0
	)
	# Overshoot slightly on the way in, so an opening Knot reads as pushing up through
	# the ground rather than fading into place.
	var swell := sin(emergence * PI * 0.5)
	var diameter := knot_diameter * lerpf(0.35, 1.0, swell) * (1.0 + 0.06 * (1.0 - swell))
	var flash := (
		clampf(site.flash_remaining / maxf(0.001, redirect_flash_seconds), 0.0, 1.0)
		if redirect_flash_seconds > 0.0
		else 0.0
	)
	if flash > 0.0:
		# The pulse it throws when it sends something through, drawn under the painting
		# so the silhouette stays the readable part.
		draw_circle(
			site.position,
			diameter * (0.5 + 0.35 * (1.0 - flash)),
			Color(telegraph_color.r, telegraph_color.g, telegraph_color.b, 0.45 * flash)
		)
	var tint := Color.WHITE
	tint.a = lerpf(0.0, 1.0, clampf(emergence * 1.4, 0.0, 1.0))
	_draw_centered_texture(texture, site.position, diameter, site.rotation, tint)


func _draw_label(canvas: CanvasItem, site: Site) -> void:
	## The words beside a region: the warning while one is coming, and the name of the
	## thing for as long as it takes to read once after it arrives.
	var text := ""
	var alpha := 0.0
	var clearance := 0.0
	match site.stage:
		CankerRules.Stage.WARNING:
			text = warning_text
			# Measured from when the warning began rather than from how much is left, so
			# the text arrives with the second ring instead of with the Knot.
			var elapsed := maxf(0.0, warning_time - site.warning_timer)
			alpha = _fade_in(elapsed)
			clearance = sample_radius * 0.5 + knot_diameter * 0.25
		CankerRules.Stage.ACTIVE:
			if formed_text_seconds <= 0.0 or site.age >= formed_text_seconds:
				return
			text = formed_text
			alpha = minf(_fade_in(site.age), _fade_out(formed_text_seconds - site.age))
			clearance = knot_diameter * 0.5
		_:
			return
	if text.is_empty() or alpha <= 0.0:
		return
	var size := Vector2(
		LABEL_FONT.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_font_size
		).x,
		float(label_font_size)
	)
	# Under the region, and pulled back inside the wall rather than allowed to run past
	# it. The layer is clipped, so a label that overhung would lose its last letters -
	# and ground beside the wall is precisely the ground a player abandons first, which
	# makes the edge the likeliest place for this text to be needed.
	var origin := Vector2(
		site.position.x - size.x * 0.5,
		site.position.y + clearance + label_gap + size.y
	)
	var bounds := (
		territory_field.get_playable_bounds_local()
		if territory_field != null and territory_field.tuning != null
		else Rect2(Vector2.ZERO, size)
	)
	var margin := label_outline_size + 2.0
	origin.x = clampf(
		origin.x, bounds.position.x + margin, maxf(bounds.position.x + margin, bounds.end.x - size.x - margin)
	)
	origin.y = clampf(
		origin.y, bounds.position.y + size.y + margin, maxf(bounds.position.y + size.y + margin, bounds.end.y - margin)
	)
	if label_outline_size > 0.0:
		var outline := label_outline_color
		outline.a *= alpha
		canvas.draw_string_outline(
			LABEL_FONT,
			origin,
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			label_font_size,
			int(label_outline_size),
			outline
		)
	var color := label_color
	color.a *= alpha
	canvas.draw_string(
		LABEL_FONT, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_font_size, color
	)


func _fade_in(elapsed: float) -> float:
	if label_fade_seconds <= 0.0:
		return 1.0
	return clampf(elapsed / label_fade_seconds, 0.0, 1.0)


func _fade_out(remaining: float) -> float:
	if label_fade_seconds <= 0.0:
		return 1.0
	return clampf(remaining / label_fade_seconds, 0.0, 1.0)


func _draw_centered_texture(
	texture: Texture2D,
	position: Vector2,
	diameter: float,
	rotation: float,
	tint: Color
) -> void:
	var texture_size := Vector2(texture.get_width(), texture.get_height())
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or diameter <= 0.0:
		return
	var scale := diameter / maxf(texture_size.x, texture_size.y)
	var rect := Rect2(-texture_size * scale * 0.5, texture_size * scale)
	draw_set_transform(position, rotation, Vector2.ONE)
	draw_texture_rect(texture, rect, false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
