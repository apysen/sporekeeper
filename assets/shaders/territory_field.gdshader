shader_type canvas_item;
render_mode unshaded;

uniform float ownership_threshold : hint_range(0.01, 0.49) = 0.18;
uniform int debug_view = 0;
uniform bool bramble_enabled = false;

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

	vec3 neutral_color = vec3(0.045, 0.062, 0.086) + detail * 0.010;
	vec3 plant_color = mix(
		vec3(0.035, 0.34, 0.14),
		vec3(0.22, 0.80, 0.31),
		clamp(maturity * 0.72 + max(control, 0.0) * 0.28, 0.0, 1.0)
	);
	plant_color += detail * mix(0.018, 0.055, maturity);
	vec3 hostile_color = mix(
		vec3(0.43, 0.035, 0.095),
		vec3(0.82, 0.055, 0.14),
		clamp(maturity * 0.36 + max(-control, 0.0) * 0.64, 0.0, 1.0)
	);
	hostile_color += detail * vec3(0.040, 0.010, 0.014);

	vec3 field_color = neutral_color;
	field_color = mix(field_color, plant_color, player_weight);
	field_color = mix(field_color, hostile_color, hostile_weight);

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
	}

	float contour_aa = max(fwidth(control), 0.0001);
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
	vec3 player_line = vec3(0.42, 1.0, 0.69);
	vec3 hostile_line = vec3(1.0, 0.27, 0.38);
	field_color = mix(field_color, player_line, player_contour * 0.78);
	field_color = mix(field_color, hostile_line, hostile_contour * 0.74);
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

	if (debug_view == 0) {
		field_color += vec3(0.05, 0.16, 0.22) * pressure;
	}

	float mask_aa = max(fwidth(mask) * 1.4, 0.006);
	float claimable = smoothstep(0.5 - mask_aa, 0.5 + mask_aa, mask);
	float basalt_strata = sin(UV.y * 215.0 + sin(UV.x * 47.0) * 2.2);
	float basalt_grain = sin((UV.x - UV.y) * 310.0) * 0.5;
	vec3 rock_color = vec3(0.095, 0.100, 0.105);
	rock_color += basalt_strata * 0.014 + basalt_grain * 0.006;
	vec3 final_color = mix(rock_color, field_color, claimable);
	float rock_contour = 1.0 - smoothstep(
		mask_aa * 0.28,
		mask_aa * 1.35,
		abs(mask - 0.5)
	);
	final_color = mix(final_color, vec3(0.42, 0.43, 0.44), rock_contour * 0.82);

	COLOR = vec4(max(final_color, vec3(0.0)), 1.0);
}
