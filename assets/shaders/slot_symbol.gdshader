shader_type canvas_item;
render_mode unshaded;

// The reel faces are white silhouettes on a near-white reel strip, which made every
// symbol read as a smudge. The outline is drawn from the silhouette's own alpha rather
// than baked into the art so one set of SVGs can serve every symbol, and the fill
// colour is a uniform rather than `modulate` because modulating the node would tint the
// outline along with the shape and put the reading problem straight back.

uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Measured in source texels so the ring stays the same visual weight whatever size the
// reel window is stretched to.
uniform float outline_texels : hint_range(0.0, 16.0) = 3.0;

void fragment() {
	vec2 step_size = TEXTURE_PIXEL_SIZE * outline_texels;
	float shape = texture(TEXTURE, UV).a;
	// Eight taps around the texel, inline: passing the built-in sampler to a helper is
	// not supported by the compatibility renderer this project targets. Four taps would
	// leave the diagonals of a leaf or a thorn unlined, which is where these shapes are
	// thinnest and hardest to read.
	vec2 diagonal = step_size * 0.7071;
	// A tap that lands off the texture clamps to the edge texel rather than reading
	// nothing, so on art that reaches its own border the ring smears along that border
	// and closes into a square. Taps outside the texture contribute nothing instead.
	float ring = 0.0;
	vec2 taps[8] = {
		vec2(step_size.x, 0.0),
		vec2(-step_size.x, 0.0),
		vec2(0.0, step_size.y),
		vec2(0.0, -step_size.y),
		vec2(diagonal.x, diagonal.y),
		vec2(-diagonal.x, diagonal.y),
		vec2(diagonal.x, -diagonal.y),
		vec2(-diagonal.x, -diagonal.y)
	};
	for (int index = 0; index < 8; index++) {
		vec2 at = UV + taps[index];
		if (at.x < 0.0 || at.x > 1.0 || at.y < 0.0 || at.y > 1.0) {
			continue;
		}
		ring = max(ring, texture(TEXTURE, at).a);
	}
	// The shape sits on top of its own ring, so a thin stem keeps its fill instead of
	// being swallowed by the outline creeping in from both sides.
	vec3 rgb = mix(outline_color.rgb, fill_color.rgb, shape);
	float alpha = max(shape * fill_color.a, ring * outline_color.a);
	// Written outright rather than multiplied into the incoming COLOR. On entry COLOR
	// already holds `texture(TEXTURE, UV) * MODULATE`, so multiplying by it would
	// re-apply the silhouette's own alpha and erase the ring everywhere the ring is
	// meant to exist - which is precisely outside the silhouette. The face's colour is
	// the uniform above for the same reason: node modulate would tint the outline too.
	COLOR = vec4(rgb, alpha);
}
