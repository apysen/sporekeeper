# Territory Texture Rendering — Godot Implementation

## Scope

This implementation assumes the following are **already working**:

- `green_wash.png` is imported.
- `rot_wash.png` is imported.
- Green and Rot territory already reveal their corresponding wash textures.
- Green/Rot wash sampling is fixed to the TerritoryField / arena rather than stretching with the current territory bounds.
- Territory ownership remains controlled entirely by `TerritoryField`.
- The existing Green/Rot implementation already uses, or will continue to use, the project's smooth territory reconstruction.

This document adds the remaining territory presentation layers:

1. `paper_base.png`
2. `watercolor_noise.png`
3. `edge_noise.png`
4. watercolor edge distortion
5. darker pigment buildup around territory boundaries
6. final Paper / Green / Rot compositing
7. interior holes and Clover wounds
8. debug and tuning controls

This is a **presentation-only** change.

Do not move gameplay ownership, maturity, Clover, Root, Bramble, fragmentation, or other simulation logic into the shader.

---

# 1. Final texture stack

Recommended assets:

```text
res://art/territory/
    paper_base.png
    green_wash.png              # already implemented
    rot_wash.png                # already implemented
    watercolor_noise.png
    edge_noise.png
```

The final visible field should conceptually render:

```text
Paper base
    ↓
Green watercolor
    ↓
Rot watercolor
    ↓
watercolor edge deformation
    ↓
pigment buildup at borders
    ↓
later overlays:
Root
Bramble
decorations
units
VFX
```

The watercolor shader should handle only the first five items.

Root, Bramble, leaves, flowers, enemies, and other gameplay visuals should remain separate overlays.

---

# 2. Recommended node arrangement

If Green and Rot already render through one territory presentation node, keep using it.

Conceptually:

```text
Arena
├── TerritoryField
│   ├── TerritoryPaintLayer
│   ├── RootOverlay
│   ├── BrambleVisuals
│   └── TerritoryDecorations
├── Player
├── Enemies
└── ...
```

`TerritoryPaintLayer` should cover exactly the claimable TerritoryField rectangle.

The final watercolor material should preferably compose:

```text
Paper + Green + Rot
```

inside **one ShaderMaterial**.

Avoid creating separate full-field CanvasItems for Paper, Green, Rot, and edge effects unless there is a concrete reason to do so.

---

# 3. Import settings

## Paper base

Select:

```text
paper_base.png
```

Recommended:

```text
Filter: On
Mipmaps: On
```

The shader will use repeating sampling.

---

## Watercolor noise

Select:

```text
watercolor_noise.png
```

Recommended:

```text
Filter: On
Mipmaps: Optional
```

This is utility noise.

It does not need to be visually sharp.

---

## Edge noise

Select:

```text
edge_noise.png
```

Recommended:

```text
Filter: On
Mipmaps: Optional
```

This texture should also repeat.

Your edge noise is deliberately more contrasty and multi-scale because the goal is a **noticeably ragged watercolor border**.

---

# 4. Add the new shader uniforms

Keep your existing Green/Rot uniforms.

Add:

```glsl
uniform sampler2D paper_tex
    : source_color, filter_linear_mipmap, repeat_enable;

uniform sampler2D watercolor_noise_tex
    : filter_linear, repeat_enable;

uniform sampler2D edge_noise_tex
    : filter_linear, repeat_enable;
```

Recommended controls:

```glsl
uniform float paper_tile_px = 760.0;

uniform float watercolor_noise_tile_px = 420.0;
uniform float watercolor_variation = 0.08;

uniform float edge_noise_tile_px = 280.0;
uniform float edge_distortion = 0.06;

uniform float edge_softness = 0.055;

uniform float pigment_band_width = 0.13;
uniform float pigment_strength = 0.20;
```

These are starting values.

They are not gameplay constants.

---

# 5. Bind the new textures from GDScript

Add exported resources to the existing territory visual controller:

```gdscript
@export var paper_texture: Texture2D
@export var watercolor_noise_texture: Texture2D
@export var edge_noise_texture: Texture2D
```

Bind them once when the material initializes:

```gdscript
func bind_territory_art_textures() -> void:
    paint_material.set_shader_parameter(
        "paper_tex",
        paper_texture
    )

    paint_material.set_shader_parameter(
        "watercolor_noise_tex",
        watercolor_noise_texture
    )

    paint_material.set_shader_parameter(
        "edge_noise_tex",
        edge_noise_texture
    )
```

Do not set these every frame.

These textures are static art resources.

---

# 6. Paper base implementation

The Paper should exist across the entire claimable territory rectangle.

Unlike Green and Rot, it does **not** need an ownership mask.

In the shader:

```glsl
vec2 local_px = UV * field_size_px;

vec2 paper_uv = (
    local_px / paper_tile_px
);

vec3 paper_color = texture(
    paper_tex,
    paper_uv
).rgb;
```

Then begin the final output with:

```glsl
vec3 final_color = paper_color;
```

Neutral territory simply remains this Paper.

This means:

```text
Neutral = Paper
```

rather than requiring a special Neutral texture mask.

---

# 7. Paper anti-repetition

If the paper texture repeats visibly, use the same basic strategy as the Green/Rot wash.

Do not randomize individual tile rotation.

Instead, blend a weak secondary sample.

Example:

```glsl
vec2 paper_uv_a = local_px / paper_tile_px;

vec2 paper_uv_b = vec2(
    -paper_uv_a.y,
    paper_uv_a.x
);

paper_uv_b = (
    paper_uv_b * 0.89
    + vec2(0.31, 0.47)
);

vec3 paper_a = texture(
    paper_tex,
    paper_uv_a
).rgb;

vec3 paper_b = texture(
    paper_tex,
    paper_uv_b
).rgb;

vec3 paper_color = mix(
    paper_a,
    paper_b,
    0.18
);
```

Keep Paper blending weaker than Green/Rot.

The Paper should remain quiet.

Recommended:

```text
Primary paper sample:   ~82%
Secondary sample:       ~18%
```

Do not make the paper look kaleidoscopic.

---

# 8. Watercolor noise purpose

`watercolor_noise.png` should **not** determine territory shape.

Its job is to vary the interior appearance of the washes.

It can affect:

```text
brightness
pigment strength
slight saturation/value variation
```

It should not decide whether a pixel is Green or Rot.

Ownership still comes entirely from the runtime territory masks.

---

# 9. Sample watercolor noise in field-space

Use a different repeat scale from the visible wash.

```glsl
vec2 watercolor_noise_uv = (
    local_px / watercolor_noise_tile_px
);

float watercolor_noise = texture(
    watercolor_noise_tex,
    watercolor_noise_uv
).r;
```

Convert it into a centered variation:

```glsl
float wc_centered = (
    watercolor_noise - 0.5
) * 2.0;
```

Now:

```text
-1 = darker variation
 0 = neutral
+1 = lighter variation
```

---

# 10. Apply watercolor noise to Green and Rot

Assume your existing shader has something like:

```glsl
vec3 green_color = ...;
vec3 rot_color = ...;
```

Add:

```glsl
float wc_multiplier = (
    1.0
    + wc_centered
    * watercolor_variation
);

green_color *= wc_multiplier;
rot_color *= wc_multiplier;
```

Recommended starting value:

```glsl
watercolor_variation = 0.08;
```

Meaning roughly:

```text
about ±8% brightness variation
```

Try:

```text
0.04 = very subtle
0.08 = visible
0.12 = strong
```

Do not push this so far that the territory flickers between pale and dark patches.

The visible wash texture should remain the dominant source of visual variation.

---

# 11. Avoid matching noise repetition with wash repetition

Do not use the exact same world scale for:

```text
green_wash
rot_wash
watercolor_noise
edge_noise
```

Example:

```text
wash_tile_px               = 640
watercolor_noise_tile_px   = 420
edge_noise_tile_px         = 280
paper_tile_px              = 760
```

Different repeat periods reduce visible alignment.

Avoid simple relationships such as:

```text
640
320
160
```

because repeated landmarks can line up regularly.

---

# 12. Edge noise purpose

`edge_noise.png` should affect the **territory field before the visible threshold is applied**.

Conceptually:

```text
smooth Green field
+
edge noise
=
irregular Green field

irregular Green field
→ threshold
→ ragged watercolor silhouette
```

This means the shader does not draw a ragged outline sprite.

It changes where the territory becomes visible.

This automatically works for:

```text
outer territory borders
interior holes
thin bridges
fragmented islands
Clover wounds
```

---

# 13. Start from the existing smooth mask

Do not apply edge noise directly to raw square cell ownership if your existing territory renderer already reconstructs a smooth field.

Use the project's existing smooth Green and Rot mask values.

Conceptually:

```glsl
float green_smooth = sample_green_smooth(UV);
float rot_smooth = sample_rot_smooth(UV);
```

The exact function should reuse the current territory B-spline / cubic reconstruction.

Do not create a second unrelated smoothing model just for watercolor.

---

# 14. Sample edge noise

```glsl
vec2 edge_noise_uv = (
    local_px / edge_noise_tile_px
);

float edge_noise = texture(
    edge_noise_tex,
    edge_noise_uv
).r;
```

Center it:

```glsl
float edge_centered = (
    edge_noise - 0.5
) * 2.0;
```

Now:

```text
dark edge noise  → negative
mid gray         → near zero
light edge noise → positive
```

---

# 15. Distort the Green field

Apply the edge noise:

```glsl
float green_field = clamp(
    green_smooth
    + edge_centered
    * edge_distortion,
    0.0,
    1.0
);
```

Recommended first value:

```glsl
edge_distortion = 0.06;
```

Because you want the edge to be **noticeably ragged**, start stronger than a subtle watercolor treatment.

Suggested range:

```text
0.025 = very subtle
0.040 = mild
0.060 = noticeably ragged
0.080 = strong
0.100+ = likely too chewed-up
```

Tune this at actual gameplay zoom.

---

# 16. Distort the Rot field

Use the same noise family so the watercolor language remains cohesive.

Example:

```glsl
float rot_field = clamp(
    rot_smooth
    + edge_centered
    * edge_distortion
    * 0.90,
    0.0,
    1.0
);
```

Rot can use:

```text
90–110%
```

of the Green edge strength.

If Rot should feel more diseased, try:

```glsl
* 1.10
```

If it becomes too noisy, return to:

```glsl
* 0.90
```

Do not use a completely different edge-noise texture initially.

Green and Rot should feel like two states of the same painted medium.

---

# 17. Convert the distorted field to visible alpha

Use a soft threshold:

```glsl
float green_alpha = smoothstep(
    0.50 - edge_softness,
    0.50 + edge_softness,
    green_field
);

float rot_alpha = smoothstep(
    0.50 - edge_softness,
    0.50 + edge_softness,
    rot_field
);
```

Recommended:

```glsl
edge_softness = 0.055;
```

Smaller:

```text
sharper edge
```

Larger:

```text
softer bleed
```

Recommended range:

```text
0.025 to 0.090
```

For the current hand-painted direction, start around:

```text
0.05 to 0.065
```

---

# 18. Prevent Green/Rot overlap

If Rot is authoritative over Green visually:

```glsl
green_alpha *= (
    1.0 - rot_alpha
);
```

This prevents both materials from blending equally in Hostile cells.

Final priority:

```text
Paper
↓
Green
↓
Rot
```

Rot wins when both reconstructed fields overlap slightly due to smoothing.

---

# 19. Pigment buildup around the boundary

A ragged silhouette alone can still look like a noisy game mask.

Watercolor usually has darker pigment collecting near some edges.

Create a boundary band from the distorted field.

Helper:

```glsl
float boundary_band(
    float field_value,
    float width
) {
    float distance_to_edge = abs(
        field_value - 0.5
    );

    return 1.0 - smoothstep(
        0.0,
        width,
        distance_to_edge
    );
}
```

Use:

```glsl
float green_boundary = boundary_band(
    green_field,
    pigment_band_width
);

float rot_boundary = boundary_band(
    rot_field,
    pigment_band_width
);
```

Start with:

```glsl
pigment_band_width = 0.13;
```

---

# 20. Darken Green near the boundary

Example:

```glsl
float green_pigment = (
    green_boundary
    * pigment_strength
);

green_color *= mix(
    1.0,
    0.77,
    green_pigment
);
```

Start:

```glsl
pigment_strength = 0.20;
```

Do not make this look like a dark outline.

It should feel like:

```text
slightly stronger pigment near the wet edge
```

not:

```text
black comic-book border
```

---

# 21. Darken Rot near the boundary

Rot can be slightly stronger:

```glsl
float rot_pigment = (
    rot_boundary
    * pigment_strength
    * 1.10
);

rot_color *= mix(
    1.0,
    0.72,
    rot_pigment
);
```

This helps Rot feel heavier and more corrupted without changing the source wash itself.

---

# 22. Optional irregular pigment-band breakup

If the pigment ring becomes too even, modulate it with the same edge noise.

Example:

```glsl
float pigment_noise = mix(
    0.72,
    1.0,
    edge_noise
);

green_pigment *= pigment_noise;
rot_pigment *= pigment_noise;
```

This prevents a perfect continuous dark ring.

Use this only after the simpler band is working.

---

# 23. Final compositing

Assume you now have:

```glsl
vec3 paper_color;
vec3 green_color;
vec3 rot_color;

float green_alpha;
float rot_alpha;
```

Composite:

```glsl
vec3 final_color = paper_color;

final_color = mix(
    final_color,
    green_color,
    green_alpha
);

final_color = mix(
    final_color,
    rot_color,
    rot_alpha
);

COLOR = vec4(
    final_color,
    1.0
);
```

This gives:

```text
Neutral → Paper
Green   → Green wash
Hostile → Rot wash
```

with watercolor distortion controlling the visible boundaries.

---

# 24. Full integration example

The following is a **template** to merge into the shader where Green and Rot wash sampling already exists.

Replace the placeholder mask calls with the project's existing smooth mask reconstruction.

```glsl
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D green_mask_tex
    : filter_linear, repeat_disable;

uniform sampler2D rot_mask_tex
    : filter_linear, repeat_disable;

uniform sampler2D green_wash_tex
    : source_color, filter_linear_mipmap, repeat_enable;

uniform sampler2D rot_wash_tex
    : source_color, filter_linear_mipmap, repeat_enable;

uniform sampler2D paper_tex
    : source_color, filter_linear_mipmap, repeat_enable;

uniform sampler2D watercolor_noise_tex
    : filter_linear, repeat_enable;

uniform sampler2D edge_noise_tex
    : filter_linear, repeat_enable;

uniform vec2 field_size_px = vec2(
    672.0,
    672.0
);

uniform float paper_tile_px = 760.0;

uniform float wash_tile_px = 640.0;

uniform float watercolor_noise_tile_px = 420.0;
uniform float watercolor_variation = 0.08;

uniform float edge_noise_tile_px = 280.0;
uniform float edge_distortion = 0.06;
uniform float edge_softness = 0.055;

uniform float pigment_band_width = 0.13;
uniform float pigment_strength = 0.20;

float boundary_band(
    float field_value,
    float width
) {
    float d = abs(
        field_value - 0.5
    );

    return 1.0 - smoothstep(
        0.0,
        width,
        d
    );
}

void fragment() {
    vec2 local_px = (
        UV * field_size_px
    );

    // ------------------------------------------------
    // PAPER
    // ------------------------------------------------

    vec2 paper_uv_a = (
        local_px / paper_tile_px
    );

    vec2 paper_uv_b = vec2(
        -paper_uv_a.y,
        paper_uv_a.x
    );

    paper_uv_b = (
        paper_uv_b * 0.89
        + vec2(0.31, 0.47)
    );

    vec3 paper_a = texture(
        paper_tex,
        paper_uv_a
    ).rgb;

    vec3 paper_b = texture(
        paper_tex,
        paper_uv_b
    ).rgb;

    vec3 paper_color = mix(
        paper_a,
        paper_b,
        0.18
    );

    // ------------------------------------------------
    // EXISTING GREEN / ROT WASH SAMPLING
    // ------------------------------------------------

    vec2 wash_uv = (
        local_px / wash_tile_px
    );

    // Replace these with your already-implemented
    // multi-orientation Green/Rot sampling.
    vec3 green_color = texture(
        green_wash_tex,
        wash_uv
    ).rgb;

    vec3 rot_color = texture(
        rot_wash_tex,
        wash_uv
    ).rgb;

    // ------------------------------------------------
    // WATERCOLOR INTERIOR NOISE
    // ------------------------------------------------

    vec2 watercolor_noise_uv = (
        local_px
        / watercolor_noise_tile_px
    );

    float wc = texture(
        watercolor_noise_tex,
        watercolor_noise_uv
    ).r;

    float wc_centered = (
        wc - 0.5
    ) * 2.0;

    float wc_multiplier = (
        1.0
        + wc_centered
        * watercolor_variation
    );

    green_color *= wc_multiplier;
    rot_color *= wc_multiplier;

    // ------------------------------------------------
    // TERRITORY MASKS
    // ------------------------------------------------

    // Replace these direct reads with the
    // existing cubic/B-spline reconstruction
    // used by the current territory renderer.

    float green_smooth = texture(
        green_mask_tex,
        UV
    ).r;

    float rot_smooth = texture(
        rot_mask_tex,
        UV
    ).r;

    // ------------------------------------------------
    // EDGE NOISE
    // ------------------------------------------------

    vec2 edge_noise_uv = (
        local_px
        / edge_noise_tile_px
    );

    float edge_noise = texture(
        edge_noise_tex,
        edge_noise_uv
    ).r;

    float edge_centered = (
        edge_noise - 0.5
    ) * 2.0;

    float green_field = clamp(
        green_smooth
        + edge_centered
        * edge_distortion,
        0.0,
        1.0
    );

    float rot_field = clamp(
        rot_smooth
        + edge_centered
        * edge_distortion
        * 0.95,
        0.0,
        1.0
    );

    // ------------------------------------------------
    // VISIBLE TERRITORY ALPHA
    // ------------------------------------------------

    float green_alpha = smoothstep(
        0.50 - edge_softness,
        0.50 + edge_softness,
        green_field
    );

    float rot_alpha = smoothstep(
        0.50 - edge_softness,
        0.50 + edge_softness,
        rot_field
    );

    green_alpha *= (
        1.0 - rot_alpha
    );

    // ------------------------------------------------
    // PIGMENT BUILDUP
    // ------------------------------------------------

    float green_boundary = boundary_band(
        green_field,
        pigment_band_width
    );

    float rot_boundary = boundary_band(
        rot_field,
        pigment_band_width
    );

    float pigment_noise = mix(
        0.72,
        1.0,
        edge_noise
    );

    float green_pigment = (
        green_boundary
        * pigment_strength
        * pigment_noise
    );

    float rot_pigment = (
        rot_boundary
        * pigment_strength
        * 1.10
        * pigment_noise
    );

    green_color *= mix(
        1.0,
        0.77,
        green_pigment
    );

    rot_color *= mix(
        1.0,
        0.72,
        rot_pigment
    );

    // ------------------------------------------------
    // COMPOSITE
    // ------------------------------------------------

    vec3 final_color = paper_color;

    final_color = mix(
        final_color,
        green_color,
        green_alpha
    );

    final_color = mix(
        final_color,
        rot_color,
        rot_alpha
    );

    COLOR = vec4(
        final_color,
        1.0
    );
}
```

---

# 25. Important note about the existing Green/Rot anti-repeat system

Do not replace your existing multi-orientation wash sampling with the single-sample lines shown in the integration template.

If Green and Rot already use:

```text
normal sample
+
rotated sample
+
mirrored sample
```

keep that.

The template intentionally leaves that section simple so the remaining texture implementation is easier to read.

Final structure should be:

```text
multi-sampled Green wash
+
multi-sampled Rot wash
+
Paper
+
watercolor noise
+
edge noise
+
pigment boundary
```

---

# 26. Interior holes need no special edge code

Suppose a large Green region contains a Neutral hole:

```text
████████████████
████        ████
████        ████
████████████████
```

The smooth Green field falls below the visible threshold around both:

```text
the outer boundary
and
the inner boundary
```

Therefore:

```text
edge distortion
pigment buildup
soft watercolor fringe
```

all appear around the hole automatically.

Do not special-case:

```text
outer edge
versus
inner edge
```

A Green-to-non-Green transition is a boundary in either direction.

---

# 27. Clover Whiff

On Clover Whiff:

```text
committed Green
→
Neutral
```

Gameplay state should update exactly as it already does.

The presentation layer sees:

```text
Green mask goes to 0
```

and automatically reveals:

```text
Paper
```

inside the lost region.

Because that creates a new Green boundary:

```text
edge noise appears there automatically
pigment buildup appears there automatically
```

No special Whiff border asset is required.

---

# 28. Clover Bust

On Bust:

```text
committed region
→
Hostile / Rot
```

The shader now transitions visually from:

```text
Green
```

to:

```text
Rot
```

The Rot wash fills the wound.

The ragged edge remains generated from the live fields.

Later VFX can add:

```text
spores
fungal breakup
leaf debris
root snapping
```

but those are not required for the base territory renderer.

---

# 29. All In behavior

Do not change any existing All In gameplay rules.

The visual system should simply follow the resulting field state.

## All In Whiff

If all Green becomes Neutral:

```text
Green mask → 0 everywhere
```

Result:

```text
Paper visible everywhere
```

The existing 3-second recovery/grace logic remains simulation-side.

## All In Bust

If the whole claimable field becomes Hostile:

```text
Rot mask → 1 across the field
```

Result:

```text
Rot wash covers the claimable area
```

Run-end behavior remains unchanged.

---

# 30. Suggested visual tuning values

Start here:

```text
paper_tile_px = 760

watercolor_noise_tile_px = 420
watercolor_variation = 0.08

edge_noise_tile_px = 280
edge_distortion = 0.06

edge_softness = 0.055

pigment_band_width = 0.13
pigment_strength = 0.20
```

Because you want a noticeably ragged watercolor edge:

```text
edge_distortion = 0.06
```

is the main starting point.

Do not immediately increase it if the edge does not look dramatic enough.

First check:

```text
edge noise scale
edge softness
source noise contrast
```

---

# 31. Tuning order for the ragged edge

If the edge looks too smooth:

```text
1. Increase edge_distortion slightly.

2. Reduce edge_noise_tile_px
   to make the noise features smaller.

3. Reduce edge_softness slightly.

4. Only then edit edge_noise.png.
```

Example:

```text
edge_distortion
0.060 → 0.070
```

---

If the edge looks too hairy or noisy:

```text
1. Increase edge_noise_tile_px.

2. Reduce edge_distortion.

3. Increase edge_softness slightly.
```

Example:

```text
edge_noise_tile_px
280 → 340
```

---

If the edge looks like a wobbly balloon:

```text
the noise features are too large
```

Reduce:

```text
edge_noise_tile_px
```

or strengthen the medium/fine structure of the source edge noise.

---

If the edge looks like a saw blade:

```text
the fine noise is too strong
```

Increase:

```text
edge_noise_tile_px
```

and/or:

```text
edge_softness
```

---

# 32. Tuning the pigment band

If the pigment band looks like a dark outline:

Reduce:

```text
pigment_strength
```

Example:

```text
0.20 → 0.12
```

or widen:

```text
pigment_band_width
```

slightly.

---

If the pigment band is invisible:

Increase:

```text
pigment_strength
```

Example:

```text
0.20 → 0.26
```

Do not immediately make the boundary extremely narrow.

A wider subtle band usually looks more watercolor-like than a thin dark ring.

---

# 33. Debug modes

Add temporary shader debug controls.

Recommended:

```glsl
uniform int debug_view = 0;
```

Suggested meanings:

```text
0 = final composite
1 = Paper only
2 = Green field
3 = Rot field
4 = edge noise
5 = distorted Green field
6 = Green boundary band
7 = Rot boundary band
8 = watercolor noise
```

Example:

```glsl
if (debug_view == 4) {
    COLOR = vec4(
        vec3(edge_noise),
        1.0
    );
    return;
}
```

For distorted Green:

```glsl
if (debug_view == 5) {
    COLOR = vec4(
        vec3(green_field),
        1.0
    );
    return;
}
```

For boundary band:

```glsl
if (debug_view == 6) {
    COLOR = vec4(
        vec3(green_boundary),
        1.0
    );
    return;
}
```

These views make shader tuning much faster.

---

# 34. Test checklist

## Test 1: Neutral field

Expected:

```text
Paper texture visible.
```

No Green/Rot contamination.

---

## Test 2: Starting Green

Expected:

```text
Green wash appears over Paper.
```

Paper should no longer be directly visible inside fully Green areas unless the wash art itself is translucent by design.

---

## Test 3: Rot

Expected:

```text
Rot wash appears over Paper.
```

Rot should visually override Green.

---

## Test 4: Ragged outer boundary

Inspect a large Green island.

Expected:

```text
edge visibly irregular
but still smooth enough to read as watercolor
```

No square cell silhouette.

---

## Test 5: Thin bridge

Expected:

```text
edge distortion does not completely destroy
legitimate narrow Green structures
```

If thin territory disappears visually while gameplay still considers it Green:

```text
edge_distortion is too high
```

This is an important test.

---

## Test 6: Interior hole

Remove Green from the center of a large region.

Expected:

```text
Paper appears in the hole
ragged edge forms around the hole
pigment buildup forms around the hole
```

No special wound code.

---

## Test 7: Clover Whiff

Expected:

```text
lost region becomes Paper
new wound boundary renders correctly
```

---

## Test 8: Clover Bust

Expected:

```text
wager region becomes Rot
Green does not bleed over it
```

---

## Test 9: Fragmented territory

Expected:

```text
each Green island receives independent
ragged watercolor boundaries
```

---

## Test 10: Large Green field

Expected:

```text
Green wash repetition is difficult to notice
Paper repetition is not distracting
edge noise repetition is not obvious
```

---

## Test 11: Movement

Expected:

```text
Paper
Green
Rot
watercolor noise
edge noise
```

remain fixed to the arena.

None of these should move with the player.

---

# 35. Performance notes

The final territory shader will perform more texture reads than the original flat-color renderer.

That is expected.

Still, keep the system bounded.

Recommended:

```text
1 CanvasItem
1 ShaderMaterial

runtime Green mask
runtime Rot mask

1 Paper source texture
1 Green wash source texture
1 Rot wash source texture
1 watercolor noise texture
1 edge noise texture
```

Multi-orientation Green/Rot sampling adds several texture reads, but it remains far preferable to:

```text
Sprite2D per cell
CPU-generated watercolor
multiple full-screen compositing nodes
```

Profile a dense late-run state before adding more layers.

---

# 36. Do not let edge distortion change gameplay

The rendered edge may extend slightly outside or inside the exact simulation threshold.

This is cosmetic.

Collision, enemy grazing, Green ownership, Root logic, Clover eligibility, and every other gameplay rule still use:

```text
TerritoryField
```

not the visible watercolor alpha.

Do not use the shader output as gameplay geometry.

---

# 37. Do not overdo the ragged edge

You specifically want:

```text
noticeably ragged
```

That does **not** mean:

```text
territory shape becomes visually inaccurate
```

The player still needs to understand:

```text
where Green is
where Rot is
where Paper is
```

Recommended goal:

```text
the silhouette is clearly watercolor
while still preserving the major simulation shape
```

If narrow structures vanish or large boundaries visibly shift by many cells:

```text
edge distortion is too strong
```

---

# 38. Recommended completion state

This phase is complete when:

- Paper fills Neutral territory.
- Green wash still behaves exactly as before.
- Rot wash still behaves exactly as before.
- Watercolor noise gives subtle interior variation.
- Edge noise produces clearly ragged boundaries.
- Boundaries remain readable.
- Paper/Green/Rot stay fixed in field-space.
- Inner holes use the same edge treatment automatically.
- Clover Whiff reveals Paper correctly.
- Clover Bust reveals Rot correctly.
- No special hole sprites are required.
- Pigment buildup reads as watercolor rather than a game outline.
- Thin bridges remain visually recognizable.
- No meaningful gameplay behavior changes.
- Performance remains acceptable.

---

# 39. Recommended next visual phase

After this territory renderer is stable, move on to:

```text
Root visual restyle
```

then:

```text
Bramble atlas / presentation
```

then:

```text
maturity-driven leaves
sprouts
flowers
Rot decorations
```

Do not add those until:

```text
Paper + Green + Rot + edges
```

already look convincing on their own.

The territory material should be strong enough that the battlefield reads correctly even with all decorative overlays temporarily disabled.
