shader_type canvas_item;

// The territory bar's two colours, painted onto the bar's own art.
//
// The shape is not computed here. The bar's authored fill art is what gets drawn,
// nine-sliced exactly as the ProgressBar beneath it slices its track, and this shader
// only decides what colour each surviving pixel is and where each colour stops. Any
// silhouette worked out in code was an approximation of the art and drifted from it at
// the caps; reading the art's alpha makes the match exact by construction.
//
// That applies to the inner ends too, which is the harder half. Where the Green stops
// and where the Rot starts are not the ends of the drawn rectangle, so they get no cap
// from the nine-slice and used to be cut off square. Instead of inventing a rounded
// edge, this reads the art's own end cap -- the first and last few columns of the
// texture, the same pixels the nine-slice uses for the outer ends -- and stamps that
// profile wherever a colour needs to finish. So all four ends of the two bodies are
// the identical shape, and it is the shape the health and XP bars end in.
//
// Nothing here moves. There is no TIME anywhere in this file, on purpose.

// Width of the control in pixels, so position along the bar can be measured in the
// bar's own space. UV cannot do this job: a nine-sliced draw restarts UV.x inside each
// of the three patches, so a boundary expressed in UV would jump at the caps.
uniform float bar_width_px = 220.0;
// The fill art's own width, and how much of each end of it the nine-slice keeps
// unstretched. Together they say where the authored cap lives in the texture. Pushed
// from the StyleBox rather than typed here, so re-authoring the bar art cannot leave
// the inner ends a different shape from the outer ones.
uniform float art_width_px = 258.0;
uniform float cap_width_px = 10.0;

// Everything up to green_edge is held Green and everything from hostile_edge on is Rot.
// The span between them is bare track: ground nobody holds costs no colour, which is
// what keeps this bar to two.
uniform float green_edge : hint_range(0.0, 1.0) = 1.0;
uniform float hostile_edge : hint_range(0.0, 1.0) = 1.0;
// Half-width of the colour cross-fade where the two meet, as a fraction of the bar.
uniform float blend_width : hint_range(0.0, 0.5) = 0.035;

uniform vec4 green_color : source_color = vec4(0.514, 0.631, 0.345, 1.0);
uniform vec4 hostile_color : source_color = vec4(0.430, 0.215, 0.305, 1.0);

// Top-to-bottom shading, reproducing the authored fill art's own gradient. Without it a
// tinted bar reads as a flat strip instead of a rounded body.
uniform float top_shade : hint_range(0.5, 1.5) = 1.06;
uniform float bottom_shade : hint_range(0.5, 1.5) = 0.94;

varying float bar_x;

void vertex() {
	// VERTEX is the control's local space for a canvas draw, so this is position along
	// the bar regardless of how the nine-slice cut up the texture coordinates.
	bar_x = VERTEX.x / max(1.0, bar_width_px);
}

float cap_profile(sampler2D art, float distance_px, float v, float from_right) {
	// The art's own end cap, read at a given distance in from where a colour finishes.
	// Past the cap the art is solid, so anything deeper than one cap width is simply
	// inside the body. The sampler is a parameter rather than the built-in because
	// TEXTURE only exists inside fragment(); a helper that reaches for it will not
	// compile, and the failure surfaces as every uniform vanishing at once.
	if (distance_px <= 0.0) {
		return 0.0;
	}
	if (distance_px >= cap_width_px) {
		return 1.0;
	}
	float u = mix(
		distance_px / art_width_px,
		1.0 - distance_px / art_width_px,
		from_right
	);
	return texture(art, vec2(u, v)).a;
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);

	float x_px = bar_x * bar_width_px;
	float green_end_px = green_edge * bar_width_px;
	float rot_start_px = hostile_edge * bar_width_px;
	// Each body ends in the authored cap: the Green closing rightward, the Rot opening
	// leftward. Their union is where liquid of either colour exists.
	float held = cap_profile(TEXTURE, green_end_px - x_px, UV.y, 1.0);
	float rot = cap_profile(TEXTURE, x_px - rot_start_px, UV.y, 0.0);
	float inner = clamp(held + rot, 0.0, 1.0);

	// As the bare span closes the two caps would meet and pinch the bar in the middle,
	// which is not what two bodies of the same stuff running together looks like. So
	// the carve itself fades out over the last cap-width of gap: by the time they touch
	// there is no cut at all, just one continuous body with the colour changing along
	// it, and the caps only appear once there is room for them.
	float gap_px = max(0.0, rot_start_px - green_end_px);
	float carve = smoothstep(0.0, max(1.0, cap_width_px * 1.2), gap_px);
	float shape = mix(1.0, inner, carve);

	// The two colours meet midway between where one ends and the other begins. When
	// they are touching that midpoint is the seam and they cross-fade; when there is
	// bare track between them the midpoint is inside it and each stays its own colour.
	float colour_edge = (green_edge + hostile_edge) * 0.5;
	float half_blend = min(
		blend_width,
		min(max(colour_edge, 0.0001), max(1.0 - colour_edge, 0.0001))
	);
	vec3 tint = mix(
		green_color.rgb,
		hostile_color.rgb,
		smoothstep(colour_edge - half_blend, colour_edge + half_blend, bar_x)
	);
	tint *= mix(top_shade, bottom_shade, UV.y);

	COLOR = vec4(tint, art.a * shape * COLOR.a);
}
