shader_type canvas_item;
render_mode unshaded;

// The Aftergrowth shield, drawn as part of the Green rather than as a sheet lying on
// top of it.
//
// Two rules make that true, and both matter:
//
// 1. The shield is torn by the same edge noise, at the same tile and the same
//    displacement, as the territory field's own border. A shield with a smooth
//    contour sitting on ragged Green reads as a decal however well it is coloured.
//
// 2. It is multiplied by the Green's own paint coverage, derived here exactly as the
//    territory shader derives it, so the shield cannot paint a pixel the Green does
//    not. The mask is stamped per cell and reconstructed smoothly, and without this
//    the reconstruction alone would bleed it a cell or so past the frontier and out
//    over open board.
//
// Both fields are sampled with the same four-tap B-spline reconstruction the
// territory field and the wager highlight use, off the same lattice, so nothing here
// can disagree with the border it is sitting on.

// The shield mask. Each cell carries how much shield is left, normalised against the
// strongest on the board, so the reconstructed value is both outline and strength.
// TEXTURE is that mask; the field state arrives beside it.
uniform sampler2D field_tex : filter_linear, repeat_disable;
uniform vec2 field_size_px = vec2(960.0, 540.0);

uniform vec4 aftergrowth_color : source_color = vec4(0.72, 1.0, 0.86, 1.0);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.30;
// A slow shimmer, so a fresh shield reads as living growth rather than as a decal.
uniform float pulse_amplitude : hint_range(0.0, 0.5) = 0.05;
uniform float pulse_hz : hint_range(0.0, 6.0) = 0.9;
// Where the reconstructed shield counts as the edge of the sheet, and how wide that
// transition is. Low, because a nearly spent cell should still show something: the
// shield fading out is the whole readout.
uniform float edge_midpoint : hint_range(0.0, 1.0) = 0.12;
uniform float edge_softness : hint_range(0.001, 0.5) = 0.16;
// Extra alpha in a band just inside the contour, so the sheet reads as one skin with
// a rim rather than as a flat wash dropped over the arena.
uniform float boundary_boost : hint_range(0.0, 1.0) = 0.34;
uniform float boundary_width : hint_range(0.001, 0.6) = 0.26;
// How strongly the fill follows what is left of the shield, against how much of it is
// simply present.
uniform float strength_weight : hint_range(0.0, 1.0) = 0.70;

// Mirrored from the territory field's material by the layer that owns this, never
// authored twice. If the ground's border moves, the shield's border moves with it.
uniform sampler2D edge_noise_tex : filter_linear, repeat_enable;
uniform float edge_noise_tile_px : hint_range(32.0, 1200.0) = 280.0;
uniform float edge_distortion_px : hint_range(0.0, 40.0) = 7.0;
uniform float edge_softness_px : hint_range(0.0, 20.0) = 2.5;
uniform float ownership_threshold : hint_range(0.01, 0.49) = 0.18;
uniform float paint_threshold_scale : hint_range(0.0, 1.0) = 0.35;
uniform float front_paint_bias : hint_range(0.0, 40.0) = 6.0;

vec4 cubic_weights(float offset) {
	vec4 distances = vec4(1.0, 2.0, 3.0, 4.0) - offset;
	vec4 cubes = distances * distances * distances;
	float first = cubes.x;
	float second = cubes.y - 4.0 * cubes.x;
	float third = cubes.z - 4.0 * cubes.y + 6.0 * cubes.x;
	float fourth = 6.0 - first - second - third;
	return vec4(first, second, third, fourth) / 6.0;
}

// Four bilinear taps weighted into a cubic reconstruction. Sixteen point samples give
// the same result and cost four times as much. Both the shield mask and the field
// state are on the field's own lattice, so one set of offsets serves both.
vec4 sample_offsets(vec2 uv, vec2 texel_size, out float horizontal_mix, out float vertical_mix) {
	vec2 texture_size = 1.0 / texel_size;
	vec2 texel_position = uv * texture_size - 0.5;
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
	vec4 offsets = sample_position
		+ vec4(x_weights.y, x_weights.w, y_weights.y, y_weights.w) / weight_sums;
	offsets *= texel_size.xxyy;
	horizontal_mix = weight_sums.x / (weight_sums.x + weight_sums.y);
	vertical_mix = weight_sums.z / (weight_sums.z + weight_sums.w);
	return offsets;
}

void fragment() {
	float horizontal_mix;
	float vertical_mix;
	vec4 offsets = sample_offsets(UV, TEXTURE_PIXEL_SIZE, horizontal_mix, vertical_mix);

	float shield = mix(
		mix(texture(TEXTURE, offsets.yw).r, texture(TEXTURE, offsets.xw).r, horizontal_mix),
		mix(texture(TEXTURE, offsets.yz).r, texture(TEXTURE, offsets.xz).r, horizontal_mix),
		vertical_mix
	);
	float control = mix(
		mix(texture(field_tex, offsets.yw).r, texture(field_tex, offsets.xw).r, horizontal_mix),
		mix(texture(field_tex, offsets.yz).r, texture(field_tex, offsets.xz).r, horizontal_mix),
		vertical_mix
	) * 2.0 - 1.0;

	vec2 local_px = UV * field_size_px;
	// One tear, read once and applied to both fields, so the shield's contour and the
	// Green's contour wander together. Tearing them independently opens gaps between
	// them at exactly the frontier where they are supposed to be the same edge.
	float edge_noise = texture(edge_noise_tex, local_px / edge_noise_tile_px).r;
	float edge_centered = (edge_noise - 0.5) * 2.0;

	// Displacement is scaled by how fast each field changes across a pixel, which is
	// what makes the tear wander the same distance everywhere instead of tens of
	// pixels across softly held ground. Flat interiors have no edge to move.
	float control_step = max(fwidth(control), 0.00001);
	float shield_step = max(fwidth(shield), 0.00001);
	float torn_control = control + edge_centered * edge_distortion_px * control_step;
	float torn_shield = shield + edge_centered * edge_distortion_px * shield_step;

	// The Green's own paint coverage, derived exactly as the territory shader derives
	// it. This is the clip: the shield is only ever as wide as the paint underneath.
	float paint_threshold = ownership_threshold * paint_threshold_scale;
	float claim = abs(torn_control) + front_paint_bias * control_step - paint_threshold;
	float claim_smooth = clamp(0.5 + claim, 0.0, 1.0);
	float claim_step = max(fwidth(claim_smooth), 0.00001);
	float claim_bleed = max(edge_softness_px * claim_step, 0.0005);
	float claimed = smoothstep(0.5 - claim_bleed, 0.5 + claim_bleed, claim_smooth);
	// Which of the two materials holds it, off the same torn field. Only the Green's
	// share carries a shield: a Bloom does not armour the ground the enemy owns.
	float share_bleed = max(edge_softness_px * control_step, 0.0005);
	float green_share = smoothstep(-share_bleed, share_bleed, torn_control);
	float green_weight = claimed * green_share;
	if (green_weight <= 0.0) {
		discard;
	}

	float half_edge = edge_softness * 0.5;
	float inside = smoothstep(edge_midpoint - half_edge, edge_midpoint + half_edge, torn_shield);
	if (inside <= 0.0) {
		discard;
	}
	// The rim is the part of the sheet that has crossed the contour but has not yet
	// reached the interior, measured on the same torn field, so it follows the ragged
	// outline rather than the cell grid.
	float interior = smoothstep(
		edge_midpoint + half_edge,
		edge_midpoint + half_edge + boundary_width,
		torn_shield
	);
	float rim = inside * (1.0 - interior);

	// Strength is read from the reconstruction itself rather than from a uniform, so
	// one cell being chewed through dims that patch instead of the whole sheet.
	float strength = mix(1.0, clamp(torn_shield, 0.0, 1.0), strength_weight);
	float breathing = sin(TIME * TAU * pulse_hz) * pulse_amplitude;
	float alpha = clamp(base_alpha * strength + breathing, 0.0, 1.0) * inside
		+ boundary_boost * rim * strength;
	COLOR = vec4(
		aftergrowth_color.rgb,
		clamp(alpha, 0.0, 1.0) * aftergrowth_color.a * green_weight
	);
}
