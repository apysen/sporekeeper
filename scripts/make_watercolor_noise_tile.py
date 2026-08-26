"""Wrap and recentre the watercolour interior noise.

Two things are wrong with the supplied noise for the job the shader gives it:

1. It does not tile. Its wrap edges differ about four times as much as neighbouring
   interior columns, which shows as a faint grid across every wash.
2. Its average is far above mid grey. The shader reads this noise as the guide
   describes it - `(noise - 0.5) * 2` , so mid grey means "leave the wash alone",
   darker means darker and lighter means lighter. A noise averaging 0.76 therefore only
   ever brightens, and brightens everything, which is a gamma change wearing the costume
   of variation.

So: recentre on mid grey, keeping every pixel's distance from the average, then wrap it
the same way the Green tile is wrapped. Contrast is left exactly as painted - how strong
the variation reads is `watercolor_variation`'s job, not this script's.

Run from the project root:

    python scripts/make_watercolor_noise_tile.py
"""

from PIL import Image, ImageChops, ImageStat

SOURCE = "assets/textures/watercolor_noise.png"
DESTINATION = "assets/textures/watercolor_noise_v2.png"
BLEND_BAND_FRACTION = 0.16
MID_GREY = 127.5


def build_tile() -> Image.Image:
    tile = Image.open(SOURCE).convert("L")
    shift = MID_GREY - ImageStat.Stat(tile).mean[0]
    tile = tile.point(lambda level: min(255, max(0, int(round(level + shift)))))

    width, height = tile.size
    shifted = ImageChops.offset(tile, width // 2, height // 2)
    wrapped = Image.composite(tile, shifted, _mask(width, height))
    return wrapped.convert("RGB")


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
    rows = bytearray()
    for row_index in range(height):
        row_weight = ramp(row_index, height)
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

    statistics = ImageStat.Stat(tile)
    print(
        "average %.1f, spread %.1f"
        % (statistics.mean[0], sum(statistics.stddev) / 3.0)
    )
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
