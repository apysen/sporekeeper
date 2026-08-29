shader_type canvas_item;

// Applied to custom-drawn botanical paintings. Primitive lines and circles use
// Godot's 1x1 white texture and are deliberately bypassed, so gameplay telegraphs
// retain their exact colour and alpha while raster art gains pigment granulation.
uniform sampler2D granulation_texture : repeat_enable, filter_linear_mipmap;
uniform float granulation_strength : hint_range(0.0, 0.75) = 0.44;
uniform float granulation_scale : hint_range(0.25, 8.0) = 1.45;
uniform float paper_lift : hint_range(0.0, 0.3) = 0.10;

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float raster_art = step(TEXTURE_PIXEL_SIZE.x, 0.25)
		* step(TEXTURE_PIXEL_SIZE.y, 0.25);
	vec2 grain_uv = UV * granulation_scale + vec2(0.173, 0.419);
	float broad = texture(granulation_texture, grain_uv).r;
	float fine = texture(granulation_texture, grain_uv * 2.13 + vec2(0.31, 0.11)).g;
	float grain = clamp((broad * 0.70 + fine * 0.30 - 0.42) * 1.85, 0.0, 1.0);
	float pigment_density = 1.0 - grain;
	float pigment = mix(
		1.0 + paper_lift,
		1.0 - granulation_strength,
		pigment_density
	);
	float painted = raster_art * smoothstep(0.015, 0.32, source.a);
	source.rgb *= mix(1.0, pigment, painted);
	// Pale paper breaks through the wash while dark fibres collect pigment. This
	// broad contrast is intentional: at gameplay scale it must read as watercolor,
	// not as a nearly invisible photographic-noise overlay.
	source.rgb += vec3((1.0 - pigment_density) * paper_lift * 0.45 * painted);
	float translucent_edge = 1.0 - smoothstep(0.24, 0.82, source.a);
	float alpha_grain = mix(0.76, 1.0, grain);
	source.a *= mix(
		1.0,
		alpha_grain,
		painted * granulation_strength * mix(0.55, 1.0, translucent_edge)
	);
	COLOR = clamp(source, vec4(0.0), vec4(1.0));
}
