# Green Watercolor Wash Implementation

## Scope

Implement the first visual layer of the new territory art system:

- Green territory uses the hand-painted `green_wash.png`.
- The existing TerritoryField remains authoritative for which cells are Green.
- The Green wash is revealed through a runtime territory mask.
- The wash texture remains fixed relative to the arena as territory grows, shrinks, or gets holes cut into it.
- The texture is sampled in fixed field-space rather than stretching to fit the current Green shape.
- To hide repetition, the shader samples the same wash several times at different orientations, scales, and offsets, then blends those samples together.
- Neutral and Hostile presentation are not part of this implementation.
- Watercolor edge treatment is not part of this implementation yet.

The goal of this phase is simply:

> Wherever TerritoryField says a cell is Green, show the Green watercolor texture.

---

## 1. Required asset

Import:

```text
res://art/territory/green_wash.png
```

Recommended source resolution:

```text
2048 × 2048
```

The texture should:

- tile cleanly enough that its borders join without a visible hard seam
- contain no obvious edge discontinuities
- avoid highly recognizable large landmarks where possible
- consist primarily of soft watercolor pigment variation
- have no manually painted territory borders
- have no leaves, flowers, roots, or other gameplay-specific decoration

The source texture does **not** have to hide every trace of repetition by itself. The shader will deliberately reduce visible repetition by blending multiple differently oriented samples of the same source texture.

---

## 2. Godot import settings

Select:

```text
green_wash.png
```

in the FileSystem panel.

In the Import panel, use approximately:

```text
Filter: On
Mipmaps: On
```

Then press:

```text
Reimport
```

Texture repeat will be enabled from the shader sampler itself.

Do not use nearest-neighbor filtering for this texture.

The watercolor texture should remain smooth when scaled.

---

## 3. Architecture

Do not create Green territory as individual sprites.

Do not create one watercolor sprite for every TerritoryField cell.

Do not create a dynamically resized Green texture based on the current Green territory bounds.

Use:

```text
TerritoryField
        ↓
low-resolution Green ownership mask
        ↓
ShaderMaterial
        ↓
green_wash.png revealed through mask
```

The gameplay simulation continues operating exactly as it does now.

The new system is presentation only.

The anti-repetition treatment is also presentation-only. It changes how the watercolor texture is sampled, never where Green territory exists.

---

## 4. Recommended scene structure

The exact node names can be adapted to the existing project.

Conceptually:

```text
Arena
├── TerritoryField
│   └── TerritoryPaintLayer
├── Player
├── Enemies
└── ...
```

`TerritoryPaintLayer` should cover exactly the same world-space rectangle as the claimable TerritoryField.

Possible node types include:

```text
Sprite2D
```

or:

```text
ColorRect
```

or an existing CanvasItem already used by the TerritoryField renderer.

Prefer modifying the existing territory rendering surface if one already exists.

The important requirement is:

```text
UV 0,0
```

must correspond to one corner of TerritoryField, and:

```text
UV 1,1
```

must correspond to the opposite corner.

---

## 5. Runtime Green mask

Create a low-resolution texture representing Green ownership.

Use the same width and height as the TerritoryField simulation grid.

Example:

```text
84 × 84 cells
```

means:

```text
84 × 84 mask texture
```

Each mask pixel represents one simulation cell.

Use:

```text
Image.FORMAT_R8
```

Values:

```text
0   = not Green
255 = Green
```

This keeps the visual mask extremely small.

---

## 6. Green mask controller

Create:

```text
phase_b_green_wash_renderer.gd
```

Example:

```gdscript
class_name PhaseBGreenWashRenderer
extends Node

@export var territory_field: Node
@export var paint_material: ShaderMaterial

var field_width: int
var field_height: int
var cell_count: int

var green_bytes := PackedByteArray()

var green_image: Image
var green_texture: ImageTexture
```

---

## 7. Initialize the Green mask

When TerritoryField dimensions are known:

```gdscript
func initialize_green_mask(width: int, height: int) -> void:
    field_width = width
    field_height = height
    cell_count = width * height

    green_bytes.resize(cell_count)

    green_image = Image.create_empty(
        field_width,
        field_height,
        false,
        Image.FORMAT_R8
    )

    green_image.fill(Color.BLACK)

    green_texture = ImageTexture.create_from_image(
        green_image
    )

    paint_material.set_shader_parameter(
        "green_mask_tex",
        green_texture
    )
```

Do this once.

Do not recreate the `ImageTexture` every frame.

---

## 8. Read Green state from TerritoryField

Prefer reading Green ownership in bulk.

Do not do this:

```gdscript
for cell in every_cell:
    territory_field.is_green(cell)
```

if that requires thousands of GDScript function calls.

The project already encountered severe performance problems from repeated per-cell method calls during Clover wager preview generation.

Instead, expose or reuse a bulk ownership snapshot.

Conceptually:

```gdscript
var snapshot = territory_field.get_visual_snapshot()
```

The exact function name should match the existing TerritoryField architecture.

The snapshot should make it possible to determine whether each cell is Green without crossing the object boundary repeatedly.

---

## 9. Build the mask

Example:

```gdscript
func refresh_green_mask(snapshot) -> void:
    for i in cell_count:
        var is_green: bool = snapshot.is_green[i]

        green_bytes[i] = 255 if is_green else 0

    green_image.set_data(
        field_width,
        field_height,
        false,
        Image.FORMAT_R8,
        green_bytes
    )

    green_texture.update(
        green_image
    )
```

If the existing ownership snapshot represents Green using maturity values and a sentinel value for non-owned territory, the loop can instead use:

```gdscript
func refresh_green_mask(snapshot) -> void:
    for i in cell_count:
        var maturity: float = snapshot.owned_maturity[i]

        green_bytes[i] = 255 if maturity >= 0.0 else 0

    green_image.set_data(
        field_width,
        field_height,
        false,
        Image.FORMAT_R8,
        green_bytes
    )

    green_texture.update(
        green_image
    )
```

Use whichever representation matches the existing TerritoryField data.

---

## 10. Do not upload the mask every rendered frame unnecessarily

The Green renderer only needs refreshing when territory changes.

Recommended starting strategy:

```gdscript
const VISUAL_REFRESH_INTERVAL := 0.05
```

This gives:

```text
20 updates per second
```

which is a reasonable first test.

Example:

```gdscript
var _green_visual_dirty := true
var _green_visual_timer := 0.0
```

```gdscript
func mark_green_visual_dirty() -> void:
    _green_visual_dirty = true
```

```gdscript
func _process(delta: float) -> void:
    if not _green_visual_dirty:
        return

    _green_visual_timer += delta

    if _green_visual_timer < VISUAL_REFRESH_INTERVAL:
        return

    _green_visual_timer = 0.0
    _green_visual_dirty = false

    var snapshot = territory_field.get_visual_snapshot()

    refresh_green_mask(snapshot)
```

Call:

```gdscript
mark_green_visual_dirty()
```

whenever meaningful Green territory changes occur.

Examples:

```text
growth
enemy grazing
Bloom
Pruning
Clover Whiff
Clover Bust
fragment decay
territory restoration
```

If TerritoryField already emits a suitable changed signal, connect to that instead.

---

## 11. Create the Green wash shader

Create:

```text
res://phase_b/visuals/green_watercolor_wash.gdshader
```

Do **not** simply tile one copy of the wash forever if the repeated pattern is visible.

Instead, sample the same `green_wash.png` several times:

```text
Sample A
normal orientation
scale 1.00

Sample B
rotated 90 degrees
scale ~0.86
different offset

Sample C
mirrored horizontally
scale ~1.16
different offset
```

Then blend the three together.

This does **not** require three art files.

All three samples come from the same:

```text
green_wash.png
```

The different orientations and slightly different scales make recognizable landmarks drift out of alignment instead of reinforcing the same square repeat.

Recommended first shader:

```glsl
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D green_mask_tex
    : filter_linear, repeat_disable;

uniform sampler2D green_wash_tex
    : source_color, filter_linear_mipmap, repeat_enable;

uniform vec2 field_size_px = vec2(672.0, 672.0);

uniform float wash_tile_px = 640.0;

uniform float secondary_scale = 0.86;
uniform float tertiary_scale = 1.16;

uniform float secondary_weight = 0.22;
uniform float tertiary_weight = 0.12;

uniform vec2 secondary_offset = vec2(0.37, 0.19);
uniform vec2 tertiary_offset = vec2(0.11, 0.53);

void fragment() {
    float green = texture(
        green_mask_tex,
        UV
    ).r;

    float green_alpha = smoothstep(
        0.45,
        0.55,
        green
    );

    vec2 local_px = UV * field_size_px;

    vec2 wash_uv = (
        local_px / wash_tile_px
    );

    // A: normal orientation.
    vec2 uv_a = wash_uv;

    // B: same texture rotated 90 degrees.
    vec2 uv_b = vec2(
        -wash_uv.y,
        wash_uv.x
    );

    uv_b = (
        uv_b * secondary_scale
        + secondary_offset
    );

    // C: same texture mirrored horizontally.
    vec2 uv_c = vec2(
        -wash_uv.x,
        wash_uv.y
    );

    uv_c = (
        uv_c * tertiary_scale
        + tertiary_offset
    );

    vec3 wash_a = texture(
        green_wash_tex,
        uv_a
    ).rgb;

    vec3 wash_b = texture(
        green_wash_tex,
        uv_b
    ).rgb;

    vec3 wash_c = texture(
        green_wash_tex,
        uv_c
    ).rgb;

    float primary_weight = max(
        0.0,
        1.0
        - secondary_weight
        - tertiary_weight
    );

    vec3 green_color = (
        wash_a * primary_weight
        + wash_b * secondary_weight
        + wash_c * tertiary_weight
    );

    COLOR = vec4(
        green_color,
        green_alpha
    );
}
```

Recommended starting blend:

```text
Primary normal sample:       66%
Secondary rotated sample:    22%
Tertiary mirrored sample:    12%
```

The primary sample should remain dominant.

The secondary and tertiary samples are there to disturb obvious repetition, not to make the texture look kaleidoscopic.

At this stage the shader has three jobs:

1. determine whether the current pixel belongs to Green territory
2. show the watercolor texture there
3. reduce obvious tiling by combining differently oriented samples of the same watercolor art

### Why not randomly rotate every individual tile?

Do **not** begin with true per-tile random rotation such as:

```text
tile 1 = 0 degrees
tile 2 = 90 degrees
tile 3 = 270 degrees
tile 4 = 180 degrees
```

A seamless texture only guarantees that its original left/right and top/bottom edges match.

Arbitrarily rotating neighboring tiles can make previously matching edges meet unrelated edges and create new seams.

The multi-sample method avoids that problem because each sampled layer is itself continuous across the entire field.

---

## 12. Assign the Green wash texture

In the renderer script:

```gdscript
@export var green_wash_texture: Texture2D
```

Then:

```gdscript
func bind_green_wash_texture() -> void:
    paint_material.set_shader_parameter(
        "green_wash_tex",
        green_wash_texture
    )
```

Assign:

```text
green_wash.png
```

through the Inspector.

---

## 13. Set the field size

The shader needs to know the visible dimensions of the TerritoryField.

Example:

```gdscript
paint_material.set_shader_parameter(
    "field_size_px",
    territory_field_size
)
```

If the claimable battlefield is:

```text
672 × 672 world pixels
```

then:

```gdscript
Vector2(672.0, 672.0)
```

should be passed.

Use the actual current TerritoryField dimensions.

Do not hardcode `672` if the project already exposes a field-size property.

---

## 14. Why the wash uses field-space coordinates

This is critical.

Do not sample the texture according to the current Green territory bounding box.

Bad behavior:

```text
Green grows
    ↓
watercolor image stretches
    ↓
existing pigment slides around
```

Instead:

```text
arena exists
    ↓
watercolor pattern is fixed over arena
    ↓
Green mask reveals portions of it
```

Imagine the watercolor texture is an infinite painted sheet underneath the simulation.

The Green mask acts like a stencil.

When Green expands:

```text
more of the existing painting becomes visible
```

When Green is destroyed:

```text
that portion becomes hidden
```

The watercolor itself does not move.

---

## 15. `wash_tile_px`

This controls the visible scale of the primary watercolor pattern.

Start with:

```glsl
uniform float wash_tile_px = 640.0;
```

Meaning roughly:

```text
one primary texture repeat every 640 world pixels
```

This does not correspond directly to the source PNG resolution.

It controls its apparent world-space scale.

Recommended test range:

```text
512 to 900 px
```

Smaller value:

```text
more texture repeats
smaller pigment features
```

Larger value:

```text
fewer repeats
larger pigment features
```

Choose the value based on actual gameplay screenshots.

Because Samples B and C use different scale multipliers, they will repeat at different spatial periods even though they use the same source PNG.

Starting values:

```glsl
secondary_scale = 0.86
tertiary_scale = 1.16
```

These values are intentionally not simple halves or doubles.

That makes the visible landmark alignment drift over distance.

---

## 15A. Anti-repetition orientation blending

The source texture should still be made reasonably seamless in Krita.

However, the final renderer should **not** rely on the source texture alone to hide repetition.

Use three layers of defense:

```text
1. A source texture with no hard seams.

2. Different orientation / scale / offset samples
   of that same texture.

3. Irregular Green territory shapes that reveal
   only portions of the underlying painted field.
```

Recommended first settings:

```text
Sample A:
orientation = normal
scale = 1.00
weight = 0.66

Sample B:
orientation = 90-degree rotation
scale = 0.86
weight = 0.22
offset = (0.37, 0.19)

Sample C:
orientation = horizontal mirror
scale = 1.16
weight = 0.12
offset = (0.11, 0.53)
```

These are art-tuning starting points.

They are not gameplay constants.

### What changing each value does

`secondary_weight`

```text
higher:
more of the rotated texture becomes visible

lower:
closer to the original source texture
```

`tertiary_weight`

```text
higher:
stronger anti-repeat effect
but greater risk of muddying the brush texture
```

`secondary_scale` / `tertiary_scale`

```text
farther from 1.0:
repeat landmarks drift more aggressively

too far from 1.0:
brush sizes from the different samples
may start looking inconsistent
```

Offsets:

```text
move the secondary landmarks away from
the primary landmarks without moving the
actual Green territory
```

### Recommended tuning order

If repetition is still visible:

```text
1. Adjust wash_tile_px.

2. Increase secondary_weight slightly.

3. Change secondary_scale by a few hundredths.

4. Change the secondary_offset.

5. Only then increase tertiary_weight.
```

Do not immediately make all three samples equal.

Avoid:

```text
33% / 33% / 33%
```

That can flatten the visual character of the original watercolor.

The primary painted texture should remain visually dominant.

---

## 16. What the first implementation should look like

At this point:

Neutral:

```text
transparent
```

Green:

```text
green_wash.png
```

There should be no:

```text
watercolor fringe
dark pigment edge
Root
Bramble
flowers
leaves
Rot texture
maturity coloration
```

yet.

The purpose is to prove that the Green texture behaves correctly before adding visual complexity.

---

## 17. Transparent background behavior

The shader currently outputs:

```glsl
COLOR = vec4(
    green_color,
    green_alpha
);
```

Therefore the paint layer should sit above whatever currently renders the battlefield background.

Pixels outside Green remain transparent.

This allows the existing Neutral presentation to remain visible underneath while this phase is tested.

Later, the complete territory material can compose:

```text
Paper
Green
Rot
```

inside one shader.

For the initial Green test, transparency is simpler.

---

## 18. Mask smoothing

The first prototype may visibly reveal the low-resolution field cells.

The temporary shader uses:

```glsl
filter_linear
```

which may be sufficient to verify the architecture.

Do not treat that as the final border behavior.

The existing territory renderer already has smooth reconstruction logic, and the Clover wager renderer was updated to use the same B-spline cubic reconstruction.

Once the basic Green wash works:

```text
replace the direct Green mask sample
```

with:

```text
the existing TerritoryField cubic/B-spline smooth mask sampler
```

Do not create a second unrelated smoothing system.

The watercolor renderer should use the same underlying territory silhouette the rest of the presentation already uses.

---

## 19. Expected behavior during growth

Starting Green:

```text
      ███
    ███████
      ███
```

Shader result:

```text
watercolor visible only inside that shape
```

As Green expands:

```text
     ███████
   ███████████
 ███████████████
   ███████████
```

The mask exposes more Green wash.

The watercolor pigment already visible in the original region should remain stationary.

Nothing should stretch.

Nothing should slide.

---

## 20. Expected behavior when Green is removed

If enemies eat Green:

```text
████████████
████    ████
████    ████
████████████
```

the missing region should immediately become transparent in the Green wash layer.

The underlying background becomes visible.

No special wound texture is necessary.

No special Green-hole code is necessary.

A hole is simply:

```text
Green mask = 0
```

inside an otherwise Green region.

---

## 21. Expected Clover Whiff behavior

The existing Clover system commits a physical collection of Green cells.

On Whiff:

```text
committed Green
    ↓
Neutral
```

The Green renderer automatically responds because those cells are no longer Green.

Example:

Before:

```text
████████████████
████████████████
████████████████
████████████████
```

After:

```text
████████████████
████      ██████
███        █████
████      ██████
████████████████
```

The center simply stops displaying `green_wash.png`.

The later watercolor-edge implementation will automatically add a painted wound border around this interior hole.

That edge work is intentionally outside the scope of this phase.

---

## 22. Coordinate-space rule

The Green mask itself should be generated directly from TerritoryField cells whenever possible.

This avoids world/local conversion entirely.

For anything that does require a position:

```text
use arena-local coordinates
```

Do not use:

```gdscript
player.position
```

for TerritoryField-relative calculations.

Use:

```gdscript
player.get_arena_position()
```

or the equivalent established helper.

The project has already experienced multiple bugs caused by confusing global or parent-local coordinates with TerritoryField-local coordinates.

The Green renderer should not reintroduce that problem.

---

## 23. Recommended file layout

```text
res://art/territory/
    green_wash.png

res://phase_b/visuals/
    green_watercolor_wash.gdshader
    phase_b_green_wash_renderer.gd
```

If a general Territory visual controller already exists, integrate this functionality there instead of creating unnecessary parallel systems.

---

## 24. Debug mode

Add a temporary debug mode that ignores the watercolor texture and displays the Green mask directly.

Shader option:

```glsl
uniform bool debug_green_mask = false;
```

Then:

```glsl
if (debug_green_mask) {
    COLOR = vec4(
        vec3(green),
        1.0
    );
    return;
}
```

This makes it much easier to determine whether a bug comes from:

```text
TerritoryField data
```

or:

```text
watercolor sampling
```

---

## 25. Test checklist

### Test 1: Starting island

Start a new run.

Expected:

```text
Green wash appears exactly where starting Green exists.
```

No offset.

No flipped Y axis.

No missing cells.

### Test 2: Movement

Move the player around.

Expected:

```text
watercolor texture does not move with the player
```

The texture belongs to the field, not the player.

### Test 3: Growth

Grow Green territory.

Expected:

```text
new territory reveals more of the same stationary watercolor pattern
```

Existing watercolor features remain fixed.

### Test 4: Grazing

Allow an enemy to remove Green.

Expected:

```text
destroyed Green becomes transparent immediately
```

No leftover watercolor.

### Test 5: Large connected region

Create a very large Green territory.

Expected:

```text
watercolor repeats are difficult to notice
```

The normal, rotated, and mirrored samples should prevent a single landmark from appearing in a clean square grid.

For debugging, temporarily set:

```text
secondary_weight = 0
tertiary_weight = 0
```

Then compare the single-sample version against the blended version.

The blended version should make repeated landmarks noticeably harder to detect.

If obvious repetition still appears, tune in this order:

```text
1. wash_tile_px
2. secondary_scale
3. secondary_offset
4. secondary_weight
5. tertiary_scale / offset / weight
```

Only return to Krita if the source texture itself contains an overwhelmingly recognizable landmark or a genuine hard seam.

### Test 6: Thin bridge

Create a thin strip of Green connecting two regions.

Expected:

```text
wash still renders correctly at narrow widths
```

### Test 7: Interior hole

Remove Green from the center of a large region.

Expected:

```text
hole becomes transparent
```

The surrounding wash should remain stationary.

### Test 8: Clover Whiff

Commit a large interior wager and Whiff.

Expected:

```text
the committed Green region disappears from the watercolor layer
```

The shape must exactly match the committed wager.

### Test 9: Performance

Cause large amounts of Green to change rapidly.

Expected:

```text
no major frame spike from Green visual updates
```

If spikes occur:

```text
profile bulk mask generation
```

before modifying the shader.

---

## 26. Common problems

### Problem: visible square grid

Cause:

```text
mask interpolation too simple
```

Fix:

```text
integrate existing cubic/B-spline territory reconstruction
```

Do not increase the simulation resolution solely to hide the visual grid.

### Problem: watercolor stretches as Green grows

Cause:

```text
texture coordinates depend on Green bounds
```

Fix:

```text
sample according to fixed field coordinates
```

### Problem: obvious repeating watercolor pattern

Possible causes:

```text
wash_tile_px too small
```

or:

```text
secondary / tertiary samples are too weak
```

or:

```text
all samples accidentally reinforce
the same landmarks
```

or:

```text
source texture contains an unusually
recognizable landmark
```

Try these fixes in order.

#### Fix 1: change the base world scale

Example:

```text
wash_tile_px
640 → 720
```

#### Fix 2: verify anti-repeat blending is enabled

Recommended starting values:

```text
secondary_weight = 0.22
tertiary_weight = 0.12
```

#### Fix 3: slightly change the secondary scale

Example:

```text
secondary_scale
0.86 → 0.82
```

or:

```text
0.86 → 0.90
```

#### Fix 4: move the secondary sample

Example:

```text
secondary_offset
(0.37, 0.19)
→
(0.43, 0.27)
```

#### Fix 5: tune the tertiary sample

Keep it weaker than the secondary sample.

Do not solve repetition by making every sample equally strong.

#### Fix 6: edit the source texture only if necessary

Return to Krita when:

```text
a specific bright or dark shape
is so distinctive that it remains
recognizable even after multi-sampling
```

The shader is intended to alleviate normal repetition.

It cannot completely hide a source image dominated by one unmistakable landmark.

### Problem: Green appears offset

Cause:

```text
TerritoryPaintLayer does not exactly match TerritoryField bounds
```

or:

```text
mask orientation does not match shader UV orientation
```

Use the debug mask before changing anything else.

### Problem: Green is upside down

The Image row orientation and CanvasItem UV orientation may not match the field's indexing convention.

Fix either:

```gdscript
index calculation
```

or shader UV:

```glsl
vec2 mask_uv = vec2(
    UV.x,
    1.0 - UV.y
);
```

Only flip once.

Do not compensate for the same mismatch in multiple systems.

### Problem: texture looks too flat

Do not immediately modify the renderer.

First test the finished game context.

The Green wash is intentionally understated.

Later layers will add:

```text
maturity
watercolor edges
Root
Bramble
leaves
flowers
combat VFX
```

The base wash should not compete with those systems.

---

## 27. Performance rules

The Green wash implementation should obey these rules:

```text
1. One CanvasItem for the territory paint layer.

2. One small R8 Green mask.

3. One reusable ImageTexture.

4. One Green watercolor source texture sampled three times at fixed orientations/scales.

5. One ShaderMaterial.

6. Bulk TerritoryField reads.

7. No Sprite2D per simulation cell.

8. No texture recreation every frame.

9. No CPU-generated watercolor pixels.

10. No procedural decorations during this phase.

11. Keep the anti-repeat blend to a small fixed number of texture reads. Start with three wash samples, not an unbounded stochastic tiling system.
```

---

## 28. Completion criteria

This phase is complete when all of the following are true:

- `green_wash.png` has no unacceptable hard seams in Godot.
- Green territory reveals the watercolor texture.
- Neutral territory does not.
- The Green texture does not move when the player moves.
- The texture does not stretch when Green changes shape.
- New Green reveals more of the same fixed watercolor surface.
- Lost Green cleanly removes the wash.
- Interior holes work.
- Clover Whiff regions work.
- Large regions do not show an obvious square repetition grid.
- The rotated and mirrored secondary samples visibly reduce repetition compared with the primary sample alone.
- No major performance regression occurs.
- The old Green gameplay logic remains completely unchanged.

Once all of these pass, move to the next visual phase:

```text
Watercolor boundary / pigment edge implementation
```

Do not add Root, Bramble, flowers, or other decorative layers until this Green foundation is verified in actual gameplay.
