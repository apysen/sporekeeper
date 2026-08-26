"""Cut every Fantasy UI surface from the pack's vector sheet instead of its PNGs.

The pack ships both a 48px PNG per sprite and one combined SVG, and the frames this
interface uses were composed from the PNGs. That cost quality twice over.

The first cost is the composite itself. A stylebox tinting the pack's art can have a
light border or a dark interior and never both, because every sprite is white with an
alpha shape - so the two halves are painted separately and combined here. Done against
48px alphas that is a one-bit decision per pixel: a pixel is either border or interior,
and the boundary between the knot and the plate it encloses comes out stepped. Done at
eight times the size and resampled once at the end, the same boundary is a proper
blend of the two colours.

The second is resampling. Anything used at a size the pack does not ship - the wager
knob at eighteen pixels - was being downsampled from the 48px raster, which is two
resamples of art that could have been rendered at the target size directly.

Godot rasterises the sheet (`Image.load_svg_from_string`, which is why there is no SVG
dependency here); this locates each sprite in it by matching the shipped PNG's alpha,
which is exact, and cuts the corresponding region out of the high-resolution render.

    python scripts/cut_fantasy_ui_from_vector.py

Run `scripts/rasterize_fantasy_ui_sheet.gd` first - it writes the two renders this
reads - and re-run this after any colour in the palette below changes.
"""

import io
import os

import numpy as np
from numpy.lib.stride_tricks import sliding_window_view
from PIL import Image

NL = chr(10)
PACK = r"D:/GameDev/GodotUI/kenney/fantasy-ui-borders/PNG/Default"
SUPERSAMPLE = 8
# The wager knob occupies forty-eight canvas units - panel 024 encloses its centre
# square in exactly a third of the sprite, and that square is meant to stand as tall
# as the bar it runs along - and is cut at four times that, so a display twice the
# size of the layout still has two texels for every screen pixel.
KNOB_TEXELS = 192

# The Botanical Field Guide, unchanged: only where the colours come from moves.
HUD_BACKGROUND = (23, 26, 21)
PANEL_FILL = (34, 38, 31)
FRAME = (116, 134, 106)
ORNAMENT = (156, 125, 78)
DISABLED = (86, 96, 82)
BIOMASS_FILL = (44, 58, 41)
HANDLE = (227, 214, 164)
HANDLE_OUTLINE = (122, 98, 51)
HANDLE_HOVER = (240, 228, 184)
HANDLE_PRESSED = (212, 194, 131)

# name -> (pack index, interior, interior alpha, knot, knot alpha, output size)
#
# The frames are 48 because that is the size a nine-patch draws them at: the corner
# ornament is drawn at the margin's size in canvas units from the margin's size in
# texels, so a larger texture with a larger margin gives a larger ornament rather than
# a sharper one.
#
# The knob is not drawn by a nine-patch. It is drawn into a rect this project chooses,
# so it is cut at four times the size it occupies and sampled down at draw time - which
# is what actually raises the detail on screen when the canvas is magnified to a display
# larger than the 1280x720 it is laid out in. See `phase_b_wager_slider.gd`.
SURFACES = {
    "frame_panel": (0, HUD_BACKGROUND, 238, FRAME, 255, 48),
    "frame_tray": (15, HUD_BACKGROUND, 235, FRAME, 220, 48),
    "frame_button": (13, PANEL_FILL, 242, FRAME, 255, 48),
    "frame_button_hover": (12, BIOMASS_FILL, 247, ORNAMENT, 255, 48),
    "frame_button_disabled": (15, PANEL_FILL, 214, DISABLED, 200, 48),
    "frame_slot": (4, PANEL_FILL, 235, DISABLED, 255, 48),
    "frame_button_biomass": (13, BIOMASS_FILL, 245, FRAME, 255, 48),
    # The wager knob, at four times the units it occupies.
    "wager_grabber": (24, HANDLE, 255, HANDLE_OUTLINE, 255, KNOB_TEXELS),
    "wager_grabber_hover": (24, HANDLE_HOVER, 255, HANDLE_OUTLINE, 255, KNOB_TEXELS),
    "wager_grabber_pressed": (24, HANDLE_PRESSED, 255, HANDLE_OUTLINE, 255, KNOB_TEXELS),
}

# The stylebox each frame is worn through, and the 9-slice margin it is worn at. The
# margin is the corner ornament's own reach into the sprite: under it, the ornament is
# stretched along with the edge. Written here so the margin and the art that assumes it
# cannot drift apart.
STYLES = {
    "panel_style.tres": ("frame_panel", 14),
    "tray_style.tres": ("frame_tray", 6),
    "button_style.tres": ("frame_button", 14),
    "button_hover_style.tres": ("frame_button_hover", 14),
    "button_disabled_style.tres": ("frame_button_disabled", 6),
    "slot_style.tres": ("frame_slot", 6),
    "button_biomass_style.tres": ("frame_button_biomass", 14),
}

sheet_small = np.asarray(
    Image.open(".godot/sheet_1x.png").convert("RGBA")
)[:, :, 3].astype(np.int32)
sheet_large = Image.open(".godot/sheet_%dx.png" % SUPERSAMPLE).convert("RGBA")
assert sheet_large.size[0] == sheet_small.shape[1] * SUPERSAMPLE


def locate(reference_path):
    """Where a shipped sprite sits in the sheet, matched on its alpha exactly."""
    target = np.asarray(
        Image.open(reference_path).convert("RGBA")
    )[:, :, 3].astype(np.int32)
    height, width = target.shape
    windows = sliding_window_view(sheet_small, (height, width))
    difference = np.abs(windows - target).sum(axis=(2, 3))
    top, left = np.unravel_index(np.argmin(difference), difference.shape)
    return int(left), int(top), width, height, int(difference[top, left])


def cut(reference_path):
    left, top, width, height, error = locate(reference_path)
    assert error == 0, "%s did not match the sheet exactly (%d)" % (
        reference_path, error
    )
    box = (
        left * SUPERSAMPLE,
        top * SUPERSAMPLE,
        (left + width) * SUPERSAMPLE,
        (top + height) * SUPERSAMPLE,
    )
    return sheet_large.crop(box)


def compose(index, interior, interior_alpha, knot, knot_alpha, size):
    """The plate under the knot, blended rather than decided pixel by pixel.

    `Panel` is the whole silhouette and `Border` is the knot alone, so the plate is
    what the first covers and the second does not. Both are carried as coverage and
    composited, so where the knot meets the plate the result is a mix of the two
    colours - which is the whole reason for working at eight times the size.
    """
    whole = np.asarray(
        cut("%s/Panel/panel-%03d.png" % (PACK, index))
    )[:, :, 3].astype(np.float64) / 255.0
    edge = np.asarray(
        cut("%s/Border/panel-border-%03d.png" % (PACK, index))
    )[:, :, 3].astype(np.float64) / 255.0
    plate = np.clip(whole - edge, 0.0, 1.0) * (interior_alpha / 255.0)
    knot_coverage = edge * (knot_alpha / 255.0)

    height, width = plate.shape
    out = np.zeros((height, width, 4), dtype=np.float64)
    # Knot over plate, premultiplied so the downsample below averages colour and
    # coverage together rather than letting a transparent pixel drag a colour with it.
    for channel in range(3):
        out[:, :, channel] = (
            knot[channel] * knot_coverage
            + interior[channel] * plate * (1.0 - knot_coverage)
        )
    out[:, :, 3] = knot_coverage + plate * (1.0 - knot_coverage)

    supersampled = Image.fromarray(
        np.clip(np.dstack([out[:, :, :3], out[:, :, 3] * 255.0]), 0, 255).astype("uint8"),
        "RGBA",
    )
    # Area average rather than Lanczos. A twenty-to-one reduction of a hard edge rings
    # under a windowed-sinc filter, and the overshoot clips per channel - which turns a
    # brass knot faintly green on one side and blue on the other. Averaging the
    # supersampled coverage is what this is: exactly the right filter for the job.
    reduced = np.asarray(
        supersampled.resize((size, size), Image.BOX)
    ).astype(np.float64)
    # Back out of premultiplied alpha, leaving fully transparent pixels alone.
    alpha = np.clip(reduced[:, :, 3], 0.0, 255.0)
    colour = np.zeros_like(reduced[:, :, :3])
    lit = alpha > 0.5
    for channel in range(3):
        colour[:, :, channel][lit] = np.clip(
            reduced[:, :, channel][lit] * 255.0 / alpha[lit], 0.0, 255.0
        )
    return Image.fromarray(
        np.dstack([colour, alpha]).astype("uint8"), "RGBA"
    )


os.makedirs("assets/ui/kenney", exist_ok=True)
for name, arguments in SURFACES.items():
    compose(*arguments).save("assets/ui/kenney/%s.png" % name)
    print("cut %s from panel %03d at %dpx" % (name, arguments[0], arguments[5]))

# The divider is a single shape, so it needs no compositing - only the frame colour
# and one resample from the high-resolution cut.
divider = cut("%s/Divider/divider-000.png" % PACK)
pixels = np.asarray(divider).astype(np.float64)
tinted = np.dstack([
    np.full(pixels.shape[:2], FRAME[0], dtype=np.float64),
    np.full(pixels.shape[:2], FRAME[1], dtype=np.float64),
    np.full(pixels.shape[:2], FRAME[2], dtype=np.float64),
    pixels[:, :, 3],
]).astype("uint8")
native = Image.open("%s/Divider/divider-000.png" % PACK).size
Image.fromarray(tinted, "RGBA").resize(native, Image.BOX).save(
    "assets/ui/kenney/divider.png"
)
print("cut divider at %dx%d" % native)


for style, (frame, margin) in STYLES.items():
    io.open("assets/ui/" + style, "w", encoding="utf-8", newline="").write(NL.join([
        '[gd_resource type="StyleBoxTexture" load_steps=2 format=3]',
        "",
        '[ext_resource type="Texture2D" path="res://assets/ui/kenney/%s.png" id="1_texture"]'
        % frame,
        "",
        "[resource]",
        'texture = ExtResource("1_texture")',
        "texture_margin_left = %d" % margin,
        "texture_margin_top = %d" % margin,
        "texture_margin_right = %d" % margin,
        "texture_margin_bottom = %d" % margin,
        "",
    ]))
print("restyled %d surfaces" % len(STYLES))
