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

# 19. Use one shared interface between materials

Do **not** generate one Green border and one Rot border independently.

There should be only one visible interface wherever two materials meet.

Examples:

```text
Green touching Paper
→ one Green/Paper edge

Rot touching Paper
→ one Rot/Paper edge

Green touching Rot
→ one Green/Rot edge
```

This avoids doubled borders such as:

```text
Green edge
+
Rot edge
=
two dark lines touching each other
```

The final renderer should instead think in terms of:

```text
three materials
+
three possible pair interfaces
```

The materials are:

```text
Green
Rot
Paper
```

The possible interfaces are:

```text
Green ↔ Paper
Rot ↔ Paper
Green ↔ Rot
```

---

# 20. Derive material weights

After edge distortion, assume:

```glsl
float green_field;
float rot_field;
```

Convert those fields into soft material weights:

```glsl
float green_w = smoothstep(
    0.50 - edge_softness,
    0.50 + edge_softness,
    green_field
);

float rot_w = smoothstep(
    0.50 - edge_softness,
    0.50 + edge_softness,
    rot_field
);
```

Give Rot visual priority over Green:

```glsl
green_w *= (
    1.0 - rot_w
);
```

Then derive Paper:

```glsl
float paper_w = clamp(
    1.0 - max(
        green_w,
        rot_w
    ),
    0.0,
    1.0
);
```

Now:

```text
green_w = visible Green contribution
rot_w   = visible Rot contribution
paper_w = visible Paper contribution
```

These are presentation weights only.

Gameplay ownership remains in `TerritoryField`.

---

# 21. Calculate pair interfaces

Use a helper that peaks where two material weights overlap.

```glsl
float interface_band(
    float a,
    float b
) {
    return 4.0 * a * b;
}
```

Why this works:

```text
a = 1.0, b = 0.0 → 0
a = 0.0, b = 1.0 → 0
a = 0.5, b = 0.5 → 1
```

Calculate the three possible interfaces:

```glsl
float edge_green_paper = interface_band(
    green_w,
    paper_w
);

float edge_rot_paper = interface_band(
    rot_w,
    paper_w
);

float edge_green_rot = interface_band(
    green_w,
    rot_w
);
```

These fields represent:

```text
where Green meets Paper
where Rot meets Paper
where Green meets Rot
```

---

# 22. Combine into one shared edge

Do not add all three interface fields together.

Use:

```glsl
float shared_edge = max(
    edge_green_paper,
    max(
        edge_rot_paper,
        edge_green_rot
    )
);
```

Using `max()` is important.

It means:

```text
there is one interface here
```

instead of:

```text
Green edge
+
Rot edge
+
Paper edge
```

This prevents unnaturally dark doubled borders.

---

# 23. Break up the shared edge with edge noise

Use the already sampled:

```glsl
float edge_noise;
```

to break the interface into a watercolor/ink fringe.

Example:

```glsl
float ragged_breakup = smoothstep(
    0.28,
    0.72,
    edge_noise
);
```

Then:

```glsl
float ragged_edge = (
    shared_edge
    * ragged_breakup
);
```

For a more continuous edge, use a higher minimum contribution:

```glsl
float ragged_breakup = mix(
    0.55,
    1.0,
    smoothstep(
        0.28,
        0.72,
        edge_noise
    )
);
```

Recommended first version:

```glsl
float ragged_breakup = mix(
    0.55,
    1.0,
    smoothstep(
        0.28,
        0.72,
        edge_noise
    )
);

float ragged_edge = (
    shared_edge
    * ragged_breakup
);
```

This gives:

```text
one shared dark interface
+
irregular watercolor breakup
```

rather than two separate territory outlines.

---

# 23A. Pair-aware edge colors

The interface should still be one line, but its color can depend on which two materials are touching.

Recommended starting colors:

## Green ↔ Paper

Deep olive / botanical charcoal:

```glsl
uniform vec3 edge_green_paper_color = vec3(
    0.14,
    0.17,
    0.11
);
```

Approximate visual target:

```text
#242B1C
```

---

## Rot ↔ Paper

Deep aubergine:

```glsl
uniform vec3 edge_rot_paper_color = vec3(
    0.16,
    0.08,
    0.12
);
```

Approximate visual target:

```text
#29141F
```

---

## Green ↔ Rot

Use a neutral botanical dark brown/black that belongs equally to both:

```glsl
uniform vec3 edge_green_rot_color = vec3(
    0.12,
    0.10,
    0.09
);
```

Approximate visual target:

```text
#1F1A17
```

Do not use pure black unless testing proves it is necessary.

---

# 23B. Choose one edge color from the material pair

Calculate the pair contribution:

```glsl
float gp = edge_green_paper;
float rp = edge_rot_paper;
float gr = edge_green_rot;
```

Then:

```glsl
float pair_total = (
    gp + rp + gr
);
```

Blend the three possible colors:

```glsl
vec3 shared_edge_color = (
    edge_green_paper_color * gp
    + edge_rot_paper_color * rp
    + edge_green_rot_color * gr
);
```

Normalize:

```glsl
if (pair_total > 0.0001) {
    shared_edge_color /= pair_total;
}
```

This still renders only **one line**.

The pair fields are used only to decide what color that single line should be.

---

# 23C. Optional pigment buildup on both sides of the shared interface

The dark concept-art border can be treated as:

```text
one central ragged ink/pigment interface
+
slightly darker watercolor immediately beside it
```

Do not independently create a full Green border and full Rot border.

Instead, use the shared edge as the driver for subtle pigment darkening.

Example:

```glsl
float pigment_amount = (
    shared_edge
    * pigment_strength
);
```

Then darken whichever material is locally present:

```glsl
green_color *= mix(
    1.0,
    0.80,
    pigment_amount * green_w
);

rot_color *= mix(
    1.0,
    0.76,
    pigment_amount * rot_w
);
```

Paper can usually remain unchanged.

This creates pigment accumulation adjacent to the shared interface without producing two separate visible outlines.

---

# 23D. Composite the single shared interface last

First composite Paper, Green, and Rot:

```glsl
vec3 final_color = paper_color;

final_color = mix(
    final_color,
    green_color,
    green_w
);

final_color = mix(
    final_color,
    rot_color,
    rot_w
);
```

Then overlay the one ragged interface:

```glsl
uniform float shared_edge_strength = 0.78;

float shared_edge_alpha = clamp(
    ragged_edge
    * shared_edge_strength,
    0.0,
    1.0
);

final_color = mix(
    final_color,
    shared_edge_color,
    shared_edge_alpha
);
```

Finally:

```glsl
COLOR = vec4(
    final_color,
    1.0
);
```

The visual hierarchy becomes:

```text
Paper / Green / Rot materials
↓
subtle pigment accumulation beside the interface
↓
ONE ragged dark shared border
```

---

# 24. Full integration example

The following is a **template** to merge into the shader where Green and Rot wash sampling already exists.

It uses one shared interface between materials.

Replace the placeholder mask reads with the project's existing smooth territory reconstruction.

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

uniform float pigment_strength = 0.20;

uniform float shared_edge_strength = 0.78;

uniform vec3 edge_green_paper_color = vec3(
    0.14,
    0.17,
    0.11
);

uniform vec3 edge_rot_paper_color = vec3(
    0.16,
    0.08,
    0.12
);

uniform vec3 edge_green_rot_color = vec3(
    0.12,
    0.10,
    0.09
);

float interface_band(
    float a,
    float b
) {
    return 4.0 * a * b;
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

    // Keep your already-implemented anti-repeat
    // Green/Rot wash sampling here.
    //
    // These simple reads are placeholders.

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
    // SMOOTH TERRITORY FIELDS
    // ------------------------------------------------

    // Replace these direct reads with the project's
    // existing cubic/B-spline reconstruction.

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
    // MATERIAL WEIGHTS
    // ------------------------------------------------

    float green_w = smoothstep(
        0.50 - edge_softness,
        0.50 + edge_softness,
        green_field
    );

    float rot_w = smoothstep(
        0.50 - edge_softness,
        0.50 + edge_softness,
        rot_field
    );

    // Rot wins visually.
    green_w *= (
        1.0 - rot_w
    );

    float paper_w = clamp(
        1.0 - max(
            green_w,
            rot_w
        ),
        0.0,
        1.0
    );

    // ------------------------------------------------
    // PAIR INTERFACES
    // ------------------------------------------------

    float edge_green_paper = interface_band(
        green_w,
        paper_w
    );

    float edge_rot_paper = interface_band(
        rot_w,
        paper_w
    );

    float edge_green_rot = interface_band(
        green_w,
        rot_w
    );

    float shared_edge = max(
        edge_green_paper,
        max(
            edge_rot_paper,
            edge_green_rot
        )
    );

    // ------------------------------------------------
    // RAGGED SHARED EDGE
    // ------------------------------------------------

    float ragged_breakup = mix(
        0.55,
        1.0,
        smoothstep(
            0.28,
            0.72,
            edge_noise
        )
    );

    float ragged_edge = (
        shared_edge
        * ragged_breakup
    );

    // ------------------------------------------------
    // PAIR-AWARE EDGE COLOR
    // ------------------------------------------------

    float gp = edge_green_paper;
    float rp = edge_rot_paper;
    float gr = edge_green_rot;

    float pair_total = (
        gp + rp + gr
    );

    vec3 shared_edge_color = (
        edge_green_paper_color * gp
        + edge_rot_paper_color * rp
        + edge_green_rot_color * gr
    );

    if (pair_total > 0.0001) {
        shared_edge_color /= pair_total;
    }

    // ------------------------------------------------
    // SUBTLE PIGMENT BUILDUP BESIDE THE INTERFACE
    // ------------------------------------------------

    float pigment_amount = (
        shared_edge
        * pigment_strength
    );

    green_color *= mix(
        1.0,
        0.80,
        pigment_amount * green_w
    );

    rot_color *= mix(
        1.0,
        0.76,
        pigment_amount * rot_w
    );

    // ------------------------------------------------
    // MATERIAL COMPOSITE
    // ------------------------------------------------

    vec3 final_color = paper_color;

    final_color = mix(
        final_color,
        green_color,
        green_w
    );

    final_color = mix(
        final_color,
        rot_color,
        rot_w
    );

    // ------------------------------------------------
    // ONE SHARED RAGGED BORDER
    // ------------------------------------------------

    float shared_edge_alpha = clamp(
        ragged_edge
        * shared_edge_strength,
        0.0,
        1.0
    );

    final_color = mix(
        final_color,
        shared_edge_color,
        shared_edge_alpha
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

The template intentionally leaves that section simple so the shared-edge implementation is easier to read.

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
ONE shared material interface
```

There should never be:

```text
Green border
+
Rot border
```

at the same Green/Rot contact.

There should be one Green/Rot interface.

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

pigment_strength = 0.20
shared_edge_strength = 0.78
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

# 32. Tuning the shared interface

If the shared edge looks like a hard game outline:

Reduce:

```text
shared_edge_strength
```

Example:

```text
0.78 → 0.60
```

Also consider increasing:

```text
edge_softness
```

slightly.

---

If the edge is too faint:

Increase:

```text
shared_edge_strength
```

Example:

```text
0.78 → 0.88
```

Do not immediately make the edge pure black.

---

If Green/Rot contact looks doubled:

Check that the renderer uses:

```glsl
shared_edge = max(
    edge_green_paper,
    max(
        edge_rot_paper,
        edge_green_rot
    )
);
```

Do not render independent Green and Rot edge overlays.

---

If Green/Paper and Rot/Paper edges look good but Green/Rot looks too dark:

Lighten only:

```text
edge_green_rot_color
```

The Green/Rot contact should remain one shared line.

---

If pigment buildup looks like a second border:

Reduce:

```text
pigment_strength
```

Example:

```text
0.20 → 0.12
```

The pigment buildup should darken the watercolor beside the interface.

It should not create another visible line next to the shared edge.

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
6 = Green/Paper interface
7 = Rot/Paper interface
8 = Green/Rot interface
9 = shared edge
10 = watercolor noise
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

For Green/Paper interface:

```glsl
if (debug_view == 6) {
    COLOR = vec4(
        vec3(edge_green_paper),
        1.0
    );
    return;
}
```

For the final shared interface:

```glsl
if (debug_view == 9) {
    COLOR = vec4(
        vec3(shared_edge),
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
one Green/Rot interface appears
```

There should not be:

```text
one Green outline
+
one Rot outline
```

at the same contact.

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
- Green/Paper contact has one shared interface.
- Rot/Paper contact has one shared interface.
- Green/Rot contact has one shared interface, never doubled borders.
- Pigment buildup reads as watercolor accumulation beside the interface rather than a second outline.
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
