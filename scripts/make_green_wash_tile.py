"""Build the tiling Green wash from the vendor watercolor painting.

The purchased painting is a single canvas, not a tile: its edges do not wrap, and it
is lit light in one corner and dark in the other. Tiled as-is it shows a hard grid of
seams plus a brightness step at every repeat, and the shader's anti-repetition blend
cannot hide either - all three of its samples are the same painting, so each one
carries the same discontinuity.

Two passes fix that:

1. Flatten. Subtract the low frequencies and restore the average, which removes the
   canvas-wide lighting ramp and keeps the brushwork.
2. Wrap. Composite the tile over a half-shifted copy of itself. The shifted copy is
   continuous exactly where the tile's wrap edges are, and its own discontinuity
   lands in the middle, where the unshifted tile covers it.

Run from the project root:

    python scripts/make_green_wash_tile.py
"""

from PIL import Image, ImageChops, ImageFilter, ImageStat

SOURCE = "assets/textures/green_wash_v3.jpg"
DESTINATION = "assets/textures/green_wash_v3.png"
SIZE = 2048
# Wide enough that the hand-off between the two copies has no edge of its own,
# narrow enough that most of the tile is still the painting untouched.
BLEND_BAND = 320
# Large enough to leave brush strokes alone, small enough to take the canvas-wide
# lighting ramp with it.
FLATTEN_RADIUS = 140


def build_tile() -> Image.Image:
    source = Image.open(SOURCE).convert("RGB")
    width, height = source.size
    scale = SIZE / min(width, height)
    source = source.resize((round(width * scale), round(height * scale)), Image.LANCZOS)
    width, height = source.size
    left = (width - SIZE) // 2
    top = (height - SIZE) // 2
    tile = source.crop((left, top, left + SIZE, top + SIZE))

    low_frequencies = tile.filter(ImageFilter.GaussianBlur(radius=FLATTEN_RADIUS))
    average = ImageStat.Stat(low_frequencies).mean
    flat_ground = Image.new("RGB", (SIZE, SIZE), tuple(int(round(v)) for v in average))
    detail = ImageChops.subtract(tile, low_frequencies, 1.0, 128)
    tile = ImageChops.add(detail, flat_ground, 1.0, -128)

    return Image.composite(tile, ImageChops.offset(tile, SIZE // 2, SIZE // 2), _mask())


def _mask() -> Image.Image:
    def ramp(index: int) -> int:
        if index < BLEND_BAND:
            position = index / BLEND_BAND
        elif index >= SIZE - BLEND_BAND:
            position = (SIZE - 1 - index) / BLEND_BAND
        else:
            return 255
        return int(round(255 * position * position * (3.0 - 2.0 * position)))

    axis = [ramp(index) for index in range(SIZE)]
    rows = bytearray()
    for row_weight in axis:
        if row_weight == 255:
            rows += bytes(axis)
        else:
            rows += bytes((column * row_weight) // 255 for column in axis)
    return Image.frombytes("L", (SIZE, SIZE), bytes(rows))


def report(tile: Image.Image) -> None:
    pixels = tile.load()
    sample = range(0, SIZE, 4)

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

    whole = ImageStat.Stat(tile).mean
    spread = 0.0
    for box in (
        (0, 0, SIZE // 2, SIZE // 2),
        (SIZE // 2, 0, SIZE, SIZE // 2),
        (0, SIZE // 2, SIZE // 2, SIZE),
        (SIZE // 2, SIZE // 2, SIZE, SIZE),
    ):
        quadrant = ImageStat.Stat(tile.crop(box)).mean
        spread = max(spread, max(abs(a - b) for a, b in zip(quadrant, whole)))

    # A wrap difference near its neighbouring-column control means the join reads as
    # ordinary variation rather than as an edge.
    print(
        "wrap left/right %.2f (control %.2f)"
        % (column_difference(0, SIZE - 1), column_difference(SIZE // 2, SIZE // 2 + 1))
    )
    print(
        "wrap top/bottom %.2f (control %.2f)"
        % (row_difference(0, SIZE - 1), row_difference(SIZE // 2, SIZE // 2 + 1))
    )
    print("largest quadrant deviation from tile average %.2f" % spread)


if __name__ == "__main__":
    result = build_tile()
    result.save(DESTINATION)
    print("wrote %s at %dx%d" % (DESTINATION, SIZE, SIZE))
    report(result)
