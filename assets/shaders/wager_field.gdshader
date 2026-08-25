shader_type canvas_item;
render_mode unshaded;

// The wager region as a continuous field rather than a set of lit cells.
//
// The selection is decided per cell, because that is what a wager is counted in, but a
// grid of hard squares reads as a debug view of the simulation rather than as part of
// the organism. This samples the selection mask with the same B-spline reconstruction
// the territory field uses for its own border, so the highlight has the same kind of
// edge as the ground underneath it and the two look like one picture.

uniform vec4 wager_color : source_color = vec4(1.0, 0.86, 0.35, 1.0);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.22;
// Zero while the wager is committed. A preview breathes because it is still a question;
// once the lever is down there is nothing left to decide and the region holds still.
uniform float pulse_amplitude : hint_range(0.0, 0.5) = 0.08;
uniform float pulse_hz : hint_range(0.0, 6.0) = 1.6;
// Where the reconstructed mask is treated as the edge of the region, and how wide that
// transition is. Widening it softens the contour; the midpoint keeps the region the
// size the selection actually chose.
uniform float edge_midpoint : hint_range(0.0, 1.0) = 0.5;
uniform float edge_softness : hint_range(0.001, 0.5) = 0.09;
// Extra alpha in a band just inside the contour, so the region reads as one shape with
// a rim rather than as a flat wash someone dropped over the arena.
uniform float boundary_boost : hint_range(0.0, 1.0) = 0.30;
uniform float boundary_width : hint_range(0.001, 0.6) = 0.22;

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
	// Four bilinear taps weighted into a cubic reconstruction. Sixteen point samples
	// would give the same result and cost four times as much; this is the same trick
	// the territory shader uses, and the two must stay the same or the highlight will
	// visibly disagree with the border it is sitting on.
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
	float upper_left = texture(TEXTURE, sample_offset.xz).r;
	float upper_right = texture(TEXTURE, sample_offset.yz).r;
	float lower_left = texture(TEXTURE, sample_offset.xw).r;
	float lower_right = texture(TEXTURE, sample_offset.yw).r;
	float horizontal_mix = weight_sums.x / (weight_sums.x + weight_sums.y);
	float vertical_mix = weight_sums.z / (weight_sums.z + weight_sums.w);
	float coverage = mix(
		mix(lower_right, lower_left, horizontal_mix),
		mix(upper_right, upper_left, horizontal_mix),
		vertical_mix
	);

	float half_edge = edge_softness * 0.5;
	float inside = smoothstep(edge_midpoint - half_edge, edge_midpoint + half_edge, coverage);
	if (inside <= 0.0) {
		discard;
	}
	// The rim is the part of the region that has already crossed the contour but has
	// not yet reached the interior, measured on the same reconstructed field, so it
	// follows the smooth outline rather than the cell grid.
	float interior = smoothstep(
		edge_midpoint + half_edge,
		edge_midpoint + half_edge + boundary_width,
		coverage
	);
	float rim = inside * (1.0 - interior);

	float breathing = sin(TIME * TAU * pulse_hz) * pulse_amplitude;
	float alpha = clamp(base_alpha + breathing, 0.0, 1.0) * inside + boundary_boost * rim;
	COLOR = vec4(wager_color.rgb, clamp(alpha, 0.0, 1.0) * wager_color.a);
}
