shader_type canvas_item;
render_mode unshaded;

// Basalt, drawn again on top of everything.
//
// The territory shader already paints rock, underneath the whole board. This is the
// same rock painted a second time as the topmost gameplay layer, so that nothing can
// end up drawn over it: not the Aftergrowth sheet, not the wager highlight, not any
// effect that reconstructs a per-cell mask smoothly and therefore bleeds a cell or so
// past the frontier it was stamped against.
//
// It is a countermeasure rather than a fix for any one overlay. Every layer that
// stretches a coarse mask over the arena has the same failure mode at the same edge,
// and clipping each of them individually means solving it again for every layer added
// later. Rock that occludes is one rule that cannot be forgotten.
//
// The mask, the tear and the colour are all taken from the territory shader verbatim,
// because this has to be indistinguishable from the rock already under it. Any
// disagreement would show as a seam exactly where the two copies overlap.

uniform vec2 field_size_px = vec2(960.0, 540.0);
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
uniform float edge_softness_px : hint_range(0.0, 20.0) = 2.5;

vec4 cubic_weights(float offset) {
	vec4 distances = vec4(1.0, 2.0, 3.0, 4.0) - offset;
	vec4 cubes = distances * distances * distances;
	float first = cubes.x;
	float second = cubes.y - 4.0 * cubes.x;
	float third = cubes.z - 4.0 * cubes.y + 6.0 * cubes.x;
	float fourth = 6.0 - first - second - third;
	return vec4(first, second, third, fourth) / 6.0;
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
	float upper_left = texture(TEXTURE, sample_offset.xz).a;
	float upper_right = texture(TEXTURE, sample_offset.yz).a;
	float lower_left = texture(TEXTURE, sample_offset.xw).a;
	float lower_right = texture(TEXTURE, sample_offset.yw).a;
	float horizontal_mix = weight_sums.x / (weight_sums.x + weight_sums.y);
	float vertical_mix = weight_sums.z / (weight_sums.z + weight_sums.w);
	float mask = mix(
		mix(lower_right, lower_left, horizontal_mix),
		mix(upper_right, upper_left, horizontal_mix),
		vertical_mix
	);

	vec2 local_px = UV * field_size_px;
	float edge_noise = texture(edge_noise_tex, local_px / edge_noise_tile_px).r;
	float edge_centered = (edge_noise - 0.5) * 2.0;

	// Verbatim from the territory shader. Unclaimable ground is torn by the same
	// noise as everything else rather than being cut cleanly and then outlined.
	float mask_step = max(fwidth(mask), 0.00001);
	float rock_field = clamp(mask + edge_centered * edge_distortion_px * mask_step, 0.0, 1.0);
	float mask_aa = max(edge_softness_px * mask_step, 0.0005);
	float claimable = smoothstep(0.5 - mask_aa, 0.5 + mask_aa, rock_field);
	if (claimable >= 1.0) {
		discard;
	}
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

	// Opaque wherever the rock is, feathered across the same couple of pixels the
	// board's own rock edge is feathered across, so the two coincide instead of
	// producing a hard second outline over a soft first one.
	COLOR = vec4(rock_color, (1.0 - claimable) * on_board);
}
