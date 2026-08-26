"""Build the Rot wash by recolouring the Green wash.

Rot and Green are the same ground in two states, so they are the same painting in two
colours. Deriving one from the other means the two washes cannot drift apart in
brushwork, grain, or seam quality: whatever is true of the Green tile is true of this
one, including the fact that it wraps.

The recolour is three per-channel lookup tables in HSV, which leaves every pixel's
relationship to its neighbours alone:

1. Hue is recentred on the Rot hue, keeping each pixel's own small deviation from the
   Green average, so variegation survives instead of flattening to one flat colour.
2. Saturation and value are scaled to the Rot averages. Scaling rather than replacing
   keeps the brush contrast proportional, which is what stops a dark wash reading as a
   sheet of felt.

Run from the project root:

    python scripts/make_rot_wash_tile.py
"""

from PIL import Image, ImageStat

SOURCE = "assets/textures/green_wash_v3.png"
DESTINATION = "assets/textures/rot_wash_v3.png"

# Measured off the hand-made Rot wash, in PIL's 0-255 HSV. The hue is the plum the art
# pass chose; the other two are how dark and how coloured that wash actually is.
ROT_HUE = 235.3
ROT_SATURATION = 126.3
ROT_VALUE = 80.9


def build_tile() -> Image.Image:
    source = Image.open(SOURCE).convert("RGB").convert("HSV")
    hue, saturation, value = source.split()

    average_hue = ImageStat.Stat(hue).mean[0]
    average_saturation = max(1.0, ImageStat.Stat(saturation).mean[0])
    average_value = max(1.0, ImageStat.Stat(value).mean[0])

    hue_shift = ROT_HUE - average_hue
    saturation_scale = ROT_SATURATION / average_saturation
    value_scale = ROT_VALUE / average_value

    # Hue wraps, so the shift is taken modulo the channel rather than clamped: a pixel
    # on the far side of the wheel has to come round, not pile up at the end.
    hue = hue.point(lambda level: int(round(level + hue_shift)) % 256)
    saturation = saturation.point(
        lambda level: min(255, int(round(level * saturation_scale)))
    )
    value = value.point(lambda level: min(255, int(round(level * value_scale))))

    return Image.merge("HSV", (hue, saturation, value)).convert("RGB")


def report(tile: Image.Image) -> None:
    size = tile.size[0]
    pixels = tile.load()
    sample = range(0, size, 4)

    def column_difference(first: int, second: int) -> float:
        total = sum(
            sum(abs(a - b) for a, b in zip(pixels[first, y], pixels[second, y]))
            for y in sample
        )
        return total / (3 * len(sample))

    def row_difference(first: int, second: int) -> float:
        total = sum(
            sum(abs(a - b) for a, b in zip(pixels[x, first], pixels[x, second]))
            for x in sample
        )
        return total / (3 * len(sample))

    hsv = tile.convert("HSV")
    hue, saturation, value = hsv.split()
    print(
        "hue %.1f, saturation %.1f, value %.1f"
        % (
            ImageStat.Stat(hue).mean[0],
            ImageStat.Stat(saturation).mean[0],
            ImageStat.Stat(value).mean[0],
        )
    )
    # Seamlessness is inherited rather than rebuilt, so it is checked rather than
    # assumed: a per-channel lookup table cannot introduce an edge, but a mistake in
    # one could.
    print(
        "wrap left/right %.2f (control %.2f)"
        % (column_difference(0, size - 1), column_difference(size // 2, size // 2 + 1))
    )
    print(
        "wrap top/bottom %.2f (control %.2f)"
        % (row_difference(0, size - 1), row_difference(size // 2, size // 2 + 1))
    )


if __name__ == "__main__":
    result = build_tile()
    result.save(DESTINATION)
    print("wrote %s at %dx%d" % (DESTINATION, result.size[0], result.size[1]))
    report(result)
