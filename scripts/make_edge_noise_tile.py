"""Make the edge noise wrap.

The supplied noise does not tile: its left and right edges differ about four times as
much as neighbouring interior columns, and top to bottom about eight times. That would
not matter for art laid over the ground, but this noise displaces the territory
boundary itself, so every wrap line becomes a straight discontinuity running through an
otherwise ragged edge - visible in the EDGE NOISE debug view as a grid.

The fix is the wrap half of the Green tiler and nothing else: composite the noise over a
half-shifted copy of itself through a smoothstep band. The shifted copy is continuous
exactly where the original's wrap edges are, and its own discontinuity lands in the
middle, where the original covers it. No flattening pass here - noise has no lighting
ramp to remove, and taking its low frequencies out would cost the large soft shapes
that make an edge look torn rather than merely rough.

Run from the project root:

    python scripts/make_edge_noise_tile.py
"""

from PIL import Image, ImageChops

SOURCE = "assets/textures/edge_noise.png"
DESTINATION = "assets/textures/edge_noise_v2.png"
BLEND_BAND_FRACTION = 0.16


def build_tile() -> Image.Image:
    tile = Image.open(SOURCE).convert("RGB")
    width, height = tile.size
    shifted = ImageChops.offset(tile, width // 2, height // 2)
    return Image.composite(tile, shifted, _mask(width, height))


def _mask(width: int, height: int) -> Image.Image:
    def ramp(index: int, span: int) -> int:
        band = max(1, int(span * BLEND_BAND_FRACTION))
        if index < band:
            position = index / band
        elif index >= span - band:
            position = (span - 1 - index) / band
        else:
            return 255
        return int(round(255 * position * position * (3.0 - 2.0 * position)))

    columns = [ramp(index, width) for index in range(width)]
    rows_weight = [ramp(index, height) for index in range(height)]
    rows = bytearray()
    for row_weight in rows_weight:
        if row_weight == 255:
            rows += bytes(columns)
        else:
            rows += bytes((column * row_weight) // 255 for column in columns)
    return Image.frombytes("L", (width, height), bytes(rows))


def report(tile: Image.Image) -> None:
    width, height = tile.size
    pixels = tile.load()
    columns = range(0, width, 4)
    rows = range(0, height, 4)

    def column_difference(first: int, second: int) -> float:
        total = sum(
            sum(abs(a - b) for a, b in zip(pixels[first, y], pixels[second, y]))
            for y in rows
        )
        return total / (3 * len(rows))

    def row_difference(first: int, second: int) -> float:
        total = sum(
            sum(abs(a - b) for a, b in zip(pixels[x, first], pixels[x, second]))
            for x in columns
        )
        return total / (3 * len(columns))

    print(
        "wrap left/right %.2f (control %.2f)"
        % (
            column_difference(0, width - 1),
            column_difference(width // 2, width // 2 + 1),
        )
    )
    print(
        "wrap top/bottom %.2f (control %.2f)"
        % (row_difference(0, height - 1), row_difference(height // 2, height // 2 + 1))
    )


if __name__ == "__main__":
    result = build_tile()
    result.save(DESTINATION)
    print("wrote %s at %dx%d" % (DESTINATION, result.size[0], result.size[1]))
    report(result)
