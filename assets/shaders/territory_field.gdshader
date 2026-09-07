shader_type canvas_item;
render_mode unshaded;

uniform float ownership_threshold : hint_range(0.01, 0.49) = 0.18;
uniform int debug_view = 0;
uniform float root_established_threshold : hint_range(0.0, 1.0) = 0.33;
uniform float mature_threshold : hint_range(0.0, 1.0) = 0.66;
uniform float deep_root_threshold : hint_range(0.0, 1.0) = 0.88;
uniform bool bramble_enabled = false;

// The hand-painted layers. A wash is sampled in field space, never in the space of
// the shape it fills, so each behaves like an infinite painted sheet lying under the
// arena that ownership stencils holes in: ground changing hands reveals more of a
// painting that never moves, and losing it hides that painting again. Green and Rot
// are two sheets over the same coordinates, so a front moving back and forth uncovers
// the same pigment it did before rather than repainting the ground each time.
uniform bool green_wash_enabled = false;
uniform sampler2D green_wash_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool rot_wash_enabled = false;
uniform sampler2D rot_wash_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 field_size_px = vec2(960.0, 540.0);
// World pixels covered by one repeat of the wash. Larger means fewer, bigger
// pigment features; this is an apparent-scale control, not the source resolution.
uniform float wash_tile_px : hint_range(256.0, 1600.0) = 640.0;
// Source height over width. A non-square painting would otherwise be stretched to
// a square repeat, which distorts every brush stroke in it.
uniform float wash_aspect : hint_range(0.25, 4.0) = 1.0;
uniform float rot_wash_aspect : hint_range(0.25, 4.0) = 1.0;
// Where on its own sheet the Rot wash is read from. Rot is painted out of the
// same picture Green is, so without this the two would show identical pigment on
// either side of a front and the border would read as one image recoloured down
// the middle. Fixed, so a piece of ground still shows the same Rot every time it
// is lost.
uniform vec2 rot_wash_offset = vec2(0.41, 0.27);

// Repetition is broken by sampling the one painting three times at different
// orientations, scales, and offsets rather than by asking the art to hide its own
// tiling. Each layer stays continuous across the whole field, so unlike per-tile
// random rotation this cannot introduce new seams where previously matching edges
// meet. The primary sample stays dominant: the other two are there to pull
// landmarks out of alignment, not to turn the wash into a kaleidoscope.
uniform float secondary_scale : hint_range(0.5, 2.0) = 0.86;
uniform float tertiary_scale : hint_range(0.5, 2.0) = 1.16;
uniform float secondary_weight : hint_range(0.0, 1.0) = 0.22;
uniform float tertiary_weight : hint_range(0.0, 1.0) = 0.12;
uniform vec2 secondary_offset = vec2(0.37, 0.19);
uniform vec2 tertiary_offset = vec2(0.11, 0.53);

// Paper is what the board is painted on, so it needs no ownership at all: it is
// simply what is there when nothing has claimed the ground. Its own repetition is
// broken far more weakly than a wash's - paper that draws attention to itself is
// paper doing the wrong job.
uniform bool paper_enabled = false;
uniform sampler2D paper_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float paper_tile_px : hint_range(256.0, 2000.0) = 760.0;
uniform float paper_secondary_weight : hint_range(0.0, 0.5) = 0.18;
uniform float paper_secondary_scale : hint_range(0.5, 2.0) = 0.89;
uniform vec2 paper_secondary_offset = vec2(0.31, 0.47);

// Interior variation for the washes. It decides how strong the pigment looks, and
// never whether a pixel is Green or Rot: ownership stays entirely the field's.
// Its repeat is deliberately unrelated to the wash's, so the two periods do not
// line their landmarks up into a grid.
uniform sampler2D watercolor_noise_tex : filter_linear, repeat_enable;
uniform float watercolor_noise_tile_px : hint_range(64.0, 1600.0) = 420.0;
uniform float watercolor_variation : hint_range(0.0, 0.5) = 0.08;

// Edge noise moves the boundary before it is thresholded rather than drawing a
// ragged outline over a smooth one. Because it displaces the field itself, outer
// borders, interior holes, thin bridges, fragments and Clover wounds all come out
// ragged from the same few lines, and none of them needs its own case.
//
// Measured in pixels rather than in field units. The guide's constants assume a
// mask that snaps from nothing to everything inside a cell; this field is control,
// which crosses its threshold gently, so a fixed displacement in field units
// wanders a few pixels at a hard frontier and tens of pixels across ground that is
// only softly held - painting Green over neutral board. Scaling by how fast the
// field changes across one pixel makes the edge wander the same distance
// everywhere, and leaves flat interiors and open neutral ground untouched, because
// where nothing is changing there is no edge to move.
// Obstacle palette. Walls are the arena's own perimeter, rocks are the basalt inside
// it, and they are told apart the same way the field authors them: the outer two
// cells are border. Warm rock against olive-charcoal wall keeps both readable while
// leaving them quieter than the organism and the things fighting it, so the eye runs
// Green and enemies first, obstacles second, board last - rather than being pulled
// straight to a near-black hole in the middle of the picture.
uniform vec3 wall_color : source_color = vec3(0.231, 0.251, 0.208);
uniform vec3 rock_base_color : source_color = vec3(0.318, 0.282, 0.227);
// Where the shading bottoms out. Deliberately well clear of black: the strata are
// meant to give the rock form, not to punch holes in it.
uniform vec3 rock_shadow_color : source_color = vec3(0.161, 0.165, 0.141);
uniform float rock_shadow_depth : hint_range(0.0, 1.0) = 1.0;
uniform float rock_highlight_lift : hint_range(0.0, 0.2) = 0.035;
uniform float wall_border_cells : hint_range(0.0, 16.0) = 2.0;
// The board's outer contour. The arena used to end on a hard rectangle with a blue
// line drawn round it, which reads as a viewport rather than as a place. Tearing it
// with the same noise every other edge uses lets the ground end the way a piece of
// parchment ends, and makes the line unnecessary.
// Kept well under the two-cell wall band: the tear wanders about eight tenths of a
// cell either side, so at this threshold the ground reaches the very edge in places
// and is eaten a cell or so inward in others. Raising it past one starts removing the
// wall itself rather than roughening its outside.
uniform float board_edge_cells : hint_range(0.0, 16.0) = 0.5;
uniform float rock_mottle_tile_px : hint_range(32.0, 1200.0) = 220.0;
uniform float rock_texture_amount : hint_range(0.0, 1.0) = 1.0;

uniform sampler2D edge_noise_tex : filter_linear, repeat_enable;
uniform float edge_noise_tile_px : hint_range(32.0, 1200.0) = 280.0;
uniform float edge_distortion_px : hint_range(0.0, 40.0) = 7.0;
uniform float rot_edge_scale : hint_range(0.5, 1.5) = 0.95;
uniform float edge_softness_px : hint_range(0.0, 20.0) = 2.5;
// Where paint starts, as a fraction of the ownership threshold. Below one the two
// washes reach toward each other and meet at a thin seam of paper instead of being
// held apart by a band of it: the simulation's neutral strip is real, but a run
// reads its front as a place where two materials meet, not as a third material.
// Cosmetic only - ownership itself never moves.
uniform float paint_threshold_scale : hint_range(0.0, 1.0) = 0.35;

// How much pigment freshly claimed Green carries, against what fully established
// Green carries. Age is painted as the strength of the wash rather than as a second
// colour: one material laid thin and laid dense, which is what the medium actually
// does. Ground the run has just taken reads as unfinished, ground it has held reads
// as fully painted, and the difference is legible without reading the HUD.
uniform float fresh_pigment_strength : hint_range(0.0, 1.0) = 0.60;
uniform float mature_pigment_strength : hint_range(0.0, 1.5) = 1.0;
// Interior grain, sparse on fresh ground and denser on established ground.
uniform float fresh_detail_gain : hint_range(0.0, 0.2) = 0.014;
uniform float mature_detail_gain : hint_range(0.0, 0.2) = 0.055;

// How far the paint reaches past ownership at a front, in pixels of control
// gradient. Open board never has a gradient worth speaking of, so this cannot paint
// it; a front has nothing but gradient, so this carries the coat across the hair
// where control changes hands.
uniform float front_paint_bias : hint_range(0.0, 40.0) = 6.0;

vec2 wash_coordinates(vec2 uv, float aspect) {
	return uv * field_size_px / vec2(wash_tile_px, wash_tile_px * aspect);
}

vec3 sample_wash(sampler2D wash, vec2 wash_uv) {
	// A: the painting as it was made. B: the same painting turned a quarter turn.
	// C: the same painting mirrored. Different scales and offsets keep the three
	// from landing their landmarks on top of each other.
	vec2 uv_b = vec2(-wash_uv.y, wash_uv.x) * secondary_scale + secondary_offset;
	vec2 uv_c = vec2(-wash_uv.x, wash_uv.y) * tertiary_scale + tertiary_offset;
	float primary_weight = max(0.0, 1.0 - secondary_weight - tertiary_weight);
	return texture(wash, wash_uv).rgb * primary_weight
		+ texture(wash, uv_b).rgb * secondary_weight
		+ texture(wash, uv_c).rgb * tertiary_weight;
}

vec4 cubic_weights(float offset) {
	vec4 distances = vec4(1.0, 2.0, 3.0, 4.0) - offset;
	vec4 cubes = distances * distances * distances;
	float first = cubes.x;
	float second = cubes.y - 4.0 * cubes.x;
	float third = cubes.z - 4.0 * cubes.y + 6.0 * cubes.x;
	float fourth = 6.0 - first - second - third;
	return vec4(first, second, third, fourth) / 6.0;
}

float organic_pattern(vec2 uv) {
	float broad = sin(uv.x * 61.0 + sin(uv.y * 19.0) * 1.8);
	float cross = sin(uv.y * 53.0 - uv.x * 17.0);
	float fine = sin((uv.x + uv.y) * 127.0) * 0.35;
	return (broad * cross + fine) * 0.5;
}

void fragment() {
	vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 texel_position = UV * texture_size - 0.5;
	vec2 fraction = fract(texel_position);
	texel_position -= fraction;
	vec4 x_weights = cubic_weights(fraction.x);
	vec4 y_weights = cubic_weights(fraction.y);
	vec4 sample_position = texel_position.xxyy + vec2(-0.5, 1.5).xyxy;
	vec4 weight_sums = vec4(
		x_weights.x + x_weights.y,
		x_weights.z + x_weights.w,
		y_weights.x + y_weights.y,
		y_weights.z + y_weights.w
	);
	vec4 sample_offset = sample_position
		+ vec4(x_weights.y, x_weights.w, y_weights.y, y_weights.w) / weight_sums;
	sample_offset *= TEXTURE_PIXEL_SIZE.xxyy;
	vec4 upper_left = texture(TEXTURE, sample_offset.xz);
	vec4 upper_right = texture(TEXTURE, sample_offset.yz);
	vec4 lower_left = texture(TEXTURE, sample_offset.xw);
	vec4 lower_right = texture(TEXTURE, sample_offset.yw);
	float horizontal_mix = weight_sums.x / (weight_sums.x + weight_sums.y);
	float vertical_mix = weight_sums.z / (weight_sums.z + weight_sums.w);
	vec4 state = mix(
		mix(lower_right, lower_left, horizontal_mix),
		mix(upper_right, upper_left, horizontal_mix),
		vertical_mix
	);
	float control = state.r * 2.0 - 1.0;
	float maturity = state.g;
	float pressure = state.b;
	float mask = state.a;
	float bramble_development = clamp((mask - 0.60) / 0.40, 0.0, 1.0);
	float detail = organic_pattern(UV);

	float control_aa = max(fwidth(control) * 1.35, 0.006);
	float player_weight = smoothstep(
		ownership_threshold - control_aa,
		ownership_threshold + control_aa,
		control
	);
	float hostile_weight = smoothstep(
		ownership_threshold - control_aa,
		ownership_threshold + control_aa,
		-control
	);

	vec2 local_px = UV * field_size_px;

	// Paper. What the arena is painted on, and therefore what Neutral ground simply
	// is - no mask, no ownership, nothing to reveal it.
	vec3 paper_color = vec3(0.045, 0.062, 0.086) + detail * 0.010;
	if (paper_enabled) {
		vec2 paper_uv = local_px / paper_tile_px;
		vec2 paper_turned = vec2(-paper_uv.y, paper_uv.x) * paper_secondary_scale
			+ paper_secondary_offset;
		paper_color = mix(
			texture(paper_tex, paper_uv).rgb,
			texture(paper_tex, paper_turned).rgb,
			paper_secondary_weight
		);
	}

	// The two washes, each read off its own sheet at fixed field coordinates.
	vec3 green_color = mix(
		vec3(0.035, 0.34, 0.14),
		vec3(0.22, 0.80, 0.31),
		clamp(maturity * 0.72 + max(control, 0.0) * 0.28, 0.0, 1.0)
	);
	if (green_wash_enabled) {
		green_color = sample_wash(green_wash_tex, wash_coordinates(UV, wash_aspect));
	}
	// Maturity is applied after the wash, not before it. The wash branch replaces the
	// colour outright, so a ramp computed above it was discarded in every build that
	// had the wash switched on - which is every build that ships - and Fresh and
	// Mature Green rendered identically. Thinning the pigment toward the paper it was
	// painted on is the one operation that survives whichever branch supplied it.
	float green_age = clamp(maturity, 0.0, 1.0);
	green_color = mix(
		paper_color,
		green_color,
		mix(fresh_pigment_strength, mature_pigment_strength, green_age)
	);
	green_color += detail * mix(fresh_detail_gain, mature_detail_gain, green_age);
	vec3 rot_color = mix(
		vec3(0.43, 0.035, 0.095),
		vec3(0.82, 0.055, 0.14),
		clamp(maturity * 0.36 + max(-control, 0.0) * 0.64, 0.0, 1.0)
	);
	rot_color += detail * vec3(0.040, 0.010, 0.014);
	if (rot_wash_enabled) {
		rot_color = sample_wash(
			rot_wash_tex,
			wash_coordinates(UV, rot_wash_aspect) + rot_wash_offset
		);
	}

	// Interior variation, applied to both washes together so they stay two states of
	// one medium rather than two materials that happen to be adjacent.
	float watercolor_noise = texture(
		watercolor_noise_tex,
		local_px / watercolor_noise_tile_px
	).r;
	float watercolor_multiplier = 1.0
		+ (watercolor_noise - 0.5) * 2.0 * watercolor_variation;
	green_color *= watercolor_multiplier;
	rot_color *= watercolor_multiplier;

	// Whether this ground is painted at all, and which of the two materials paints it,
	// are different questions and are answered separately. Paper is the ground the
	// board is made of: Green and Rot are laid on top of it, so a piece of ground that
	// either of them holds is covered, and Paper is what is left where neither does.
	//
	// The coverage is one field, torn once. Deriving it from two independently torn
	// fields cannot work however they are combined: at a front the noise pulls both of
	// them inward at the same pixel, and a gap both of them opened is a gap that shows
	// the board through the middle of the organism.
	float paint_threshold = ownership_threshold * paint_threshold_scale;
	float control_step = max(fwidth(control), 0.00001);

	// One tear, applied to control itself, and everything below reads the torn field.
	// Tearing the coverage alone left the handover between Green and Rot running down
	// the untorn line - a clean edge through the middle of a contested front, with the
	// ragged one only where the organism met the board.
	float edge_noise = texture(edge_noise_tex, local_px / edge_noise_tile_px).r;
	float edge_centered = (edge_noise - 0.5) * 2.0;
	float torn_control = control + edge_centered * edge_distortion_px * control_step;

	// A front is ground held by two sides at once, and at the hair where control
	// crosses zero it is held by neither. Locally that pixel is indistinguishable from
	// open board - the same control, the same everything - except that control is
	// changing fast across it, which on open board it never is. So the claim is allowed
	// to lean on that: steep ground is ground between two owners, and it is painted.
	float claim = abs(torn_control) + front_paint_bias * control_step - paint_threshold;
	float claim_smooth = clamp(0.5 + claim, 0.0, 1.0);
	float claim_step = max(fwidth(claim_smooth), 0.00001);
	float claim_bleed = max(edge_softness_px * claim_step, 0.0005);
	float claimed = smoothstep(0.5 - claim_bleed, 0.5 + claim_bleed, claim_smooth);

	// Which material, off the same torn field, handed over across a couple of pixels.
	// Both boundaries therefore wander together and cannot open a gap between them.
	float share_bleed = max(edge_softness_px * control_step, 0.0005);
	float green_share = smoothstep(-share_bleed, share_bleed, torn_control);
	float green_weight = claimed * green_share;
	float rot_weight = claimed * (1.0 - green_share);
	float paper_weight = 1.0 - claimed;
	// Kept for the analytic views, which are read for where a material reaches rather
	// than for what the paint does.
	float green_field = clamp(0.5 + (torn_control - paint_threshold), 0.0, 1.0);
	float rot_field = clamp(0.5 + (-torn_control - paint_threshold), 0.0, 1.0);
	// Nothing is laid along a boundary: no gathered pigment, no darkened rim, no line.
	// Where a material ends is decided by the noise that tore its field and by nothing
	// else, so every edge on the board is the same cut.
	// The two materials hand over to each other first, and the result is laid onto
	// the Paper as one coat.
	vec3 neutral_color = paper_color;
	vec3 plant_color = green_color;
	vec3 hostile_color = rot_color;
	vec3 material_color = mix(rot_color, green_color, green_share);
	vec3 field_color = mix(paper_color, material_color, claimed);

	if (debug_view == 1) {
		vec3 plant_maturity = mix(vec3(0.025, 0.08, 0.04), vec3(0.72, 1.0, 0.22), maturity);
		vec3 hostile_maturity = mix(vec3(0.10, 0.025, 0.04), vec3(1.0, 0.31, 0.40), maturity);
		field_color = neutral_color;
		field_color = mix(field_color, plant_maturity, player_weight);
		field_color = mix(field_color, hostile_maturity, hostile_weight);
	} else if (debug_view == 2) {
		float strength = abs(control);
		vec3 control_color = vec3(0.04, 0.06, 0.12 + (1.0 - strength) * 0.20);
		control_color += control > 0.0
			? vec3(0.02, 0.78, 0.18) * strength
			: vec3(0.82, 0.04, 0.10) * strength;
		field_color = control_color;
	} else if (debug_view == 3) {
		// Root depth read as four discrete stages rather than a smooth ramp. The
		// question this view exists to answer is whether held ground has become
		// established, and a continuous gradient cannot be read that way: banding
		// is what makes the boundary visible at a glance.
		vec3 stage_color = vec3(0.05, 0.07, 0.06);
		if (maturity >= deep_root_threshold) {
			stage_color = vec3(0.86, 1.0, 0.42);
		} else if (maturity >= mature_threshold) {
			stage_color = vec3(0.42, 0.90, 0.34);
		} else if (maturity >= root_established_threshold) {
			stage_color = vec3(0.16, 0.52, 0.28);
		} else {
			stage_color = vec3(0.09, 0.22, 0.16);
		}
		field_color = neutral_color;
		// Hostile ground establishes on the same rule, so it is banded too, in its
		// own hue. Otherwise a contested front reads as if only one side ages.
		vec3 hostile_stage = vec3(0.30, 0.06, 0.09)
			+ vec3(0.62, 0.10, 0.12) * step(root_established_threshold, maturity)
			+ vec3(0.20, 0.14, 0.10) * step(deep_root_threshold, maturity);
		field_color = mix(field_color, stage_color, player_weight);
		field_color = mix(field_color, hostile_stage, hostile_weight);
	}

	float contour_aa = max(fwidth(control), 0.0001);
	// The analytic views are read for where the boundary is, so they keep their
	// hard contour. The painted view does not: pigment gathering at a wet edge is
	// the boundary treatment now, and a bright line over it would only be an
	// outline drawn round a watercolour.
	if (debug_view != 0) {
		float player_contour = 1.0 - smoothstep(
			contour_aa * 0.28,
			contour_aa * 1.35,
			abs(control - ownership_threshold)
		);
		float hostile_contour = 1.0 - smoothstep(
			contour_aa * 0.28,
			contour_aa * 1.35,
			abs(control + ownership_threshold)
		);
		field_color = mix(field_color, vec3(0.42, 1.0, 0.69), player_contour * 0.78);
		field_color = mix(field_color, vec3(1.0, 0.27, 0.38), hostile_contour * 0.74);
	}
	if (bramble_enabled && debug_view == 0) {
		float bramble_band = 1.0 - smoothstep(
			contour_aa * 0.55,
			contour_aa * 2.65,
			abs(control - ownership_threshold)
		);
		float thorn_phase = sin(
			(UV.x * texture_size.x + UV.y * texture_size.y) * 0.47
			+ detail * 6.0
		);
		float thorn_points = smoothstep(0.42, 0.96, thorn_phase) * bramble_band;
		vec3 bramble_stem = vec3(0.055, 0.22, 0.075);
		vec3 bramble_tip = vec3(0.73, 1.0, 0.38);
		// Fresh frontier shows bare stems; thorn tips sharpen as the field's
		// authoritative development rises toward full strength.
		float stem_weight = mix(0.20, 0.72, bramble_development);
		float tip_weight = smoothstep(0.10, 0.95, bramble_development);
		// Bramble covers territory, not a border, so every owned cell carries a
		// sparse thorn texture. It stays far quieter than the frontier hedge, which
		// is drawn over it.
		float interior_thorns = smoothstep(0.72, 0.99, thorn_phase) * player_weight;
		field_color = mix(field_color, bramble_stem, player_weight * 0.16);
		field_color = mix(
			field_color,
			bramble_tip,
			interior_thorns * mix(0.20, 0.42, maturity)
		);
		field_color = mix(field_color, bramble_stem, bramble_band * stem_weight);
		field_color = mix(field_color, bramble_tip, thorn_points * 0.92 * tip_weight);
	}

	// Pressure used to be tinted into the painted view, which put a cyan lift along
	// exactly the ground that was being pushed outward - an outline that appeared
	// wherever territory was expanding and faded once it settled. It reads as an edge
	// treatment, so it is gone from the paint; the CONTROL view still carries it for
	// anyone who needs to see where the field is pushing.

	// Unclaimable ground is torn by the same noise as everything else rather than
	// being cut cleanly and then outlined. It is the one edge on the board that never
	// moves, so it is the one most obviously drawn if it is drawn at all.
	float mask_step = max(fwidth(mask), 0.00001);
	float rock_field = clamp(mask + edge_centered * edge_distortion_px * mask_step, 0.0, 1.0);
	float mask_aa = max(edge_softness_px * mask_step, 0.0005);
	float claimable = smoothstep(0.5 - mask_aa, 0.5 + mask_aa, rock_field);
	// Walls against rocks, from position alone. _is_border_cell marks the outer two
	// cells of the grid, and reproducing that rule here costs nothing and needs no
	// second mask channel - there is no spare one.
	vec2 obstacle_cell = UV * texture_size;
	vec2 obstacle_from_edge = min(obstacle_cell, texture_size - obstacle_cell);
	float obstacle_edge_cells = min(obstacle_from_edge.x, obstacle_from_edge.y);
	float wallness = 1.0 - smoothstep(
		wall_border_cells - 0.5,
		wall_border_cells + 0.5,
		obstacle_edge_cells
	);
	// Cloud mottling off the board's own noise, at two scales. What was here before
	// was a pair of high-frequency sines - 215 bands down the arena crossed by a
	// diagonal hatch at 310 - which at this resolution is a stripe every few pixels:
	// that reads as moire on a screen, not as stone. The noise is the same texture
	// that tears every edge on the board, so the rock is made of the same material as
	// everything else rather than carrying a pattern of its own.
	float rock_mottle_coarse = texture(edge_noise_tex, local_px / rock_mottle_tile_px).r;
	float rock_mottle_fine = texture(
		edge_noise_tex,
		local_px / (rock_mottle_tile_px * 0.41) + vec2(0.37, 0.61)
	).r;
	// Measured from the texture: the combined two-octave value centres near 0.52 and
	// carries most of its mass within about 0.21 either side. Remapping on those
	// numbers is what turns a faint wobble around mid grey into a full shading term,
	// so the dark side still reaches the shadow colour.
	float basalt_shade = clamp(
		((rock_mottle_coarse * 0.66 + rock_mottle_fine * 0.34) - 0.52) / 0.21,
		-1.0,
		1.0
	) * rock_texture_amount;
	vec3 rock_color = mix(
		mix(rock_base_color, wall_color, wallness),
		rock_shadow_color,
		clamp(-basalt_shade, 0.0, 1.0) * rock_shadow_depth
	);
	rock_color += vec3(max(basalt_shade, 0.0) * rock_highlight_lift);
	// Distance from the board's own rectangle, in cells, torn by the same noise that
	// tears every other edge. fwidth here is cells-per-pixel, so the displacement
	// works out to the same few pixels of wander the frontier gets rather than to a
	// different amount because the field happens to be measured in other units.
	float board_edge = obstacle_edge_cells;
	float board_step = max(fwidth(board_edge), 0.00001);
	float torn_board = board_edge + edge_centered * edge_distortion_px * board_step;
	float board_aa = max(edge_softness_px * board_step, 0.0005);
	float on_board = smoothstep(
		board_edge_cells - board_aa,
		board_edge_cells + board_aa,
		torn_board
	);
	vec3 final_color = mix(rock_color, field_color, claimable);

	// The layers on their own. Each answers one question about the stack, so a
	// misbehaving edge can be traced to the field data, the noise, or the paint
	// without having to guess which of the three produced it.
	if (debug_view == 4) {
		final_color = vec3(player_weight);
	} else if (debug_view == 5) {
		final_color = paper_color;
	} else if (debug_view == 6) {
		final_color = vec3(edge_noise);
	} else if (debug_view == 7) {
		final_color = vec3(green_field);
	} else if (debug_view == 8) {
		final_color = vec3(watercolor_noise);
	}

	COLOR = vec4(max(final_color, vec3(0.0)), on_board);
}
