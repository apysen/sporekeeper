"""Generate the placeholder relic-cue motifs.

These stand in for the per-relic visual language docs/relics.md describes, in the
same register as the existing Adaptation icons and slot symbols: a single bold
white silhouette on transparent, readable at a glance and tinted at runtime by
whichever relic is drawing it.

They are placeholders on purpose. The document asks for things a person has to
look at to judge -- a fuse that reads as a fuse, a tumbleweed whose rotation
matches its speed -- and these give that work a shape to replace rather than a
blank. Regenerate with:

    python assets/placeholder_art/generate_placeholder_art.py
"""
import math
import os

from PIL import Image, ImageDraw

SIZE = 128
WHITE = (255, 255, 255, 255)
OUT = os.path.dirname(os.path.abspath(__file__))


def canvas():
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def star(draw, cx, cy, points, outer, inner, rotation=0.0, fill=WHITE):
    shape = []
    for index in range(points * 2):
        radius = outer if index % 2 == 0 else inner
        angle = rotation + math.pi * index / points
        shape.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius))
    draw.polygon(shape, fill=fill)


def spray_stream():
    # Five separated streams, which is the whole point of Garden Hose's cue: the
    # player should see where each one landed, not a fog cone.
    image, draw = canvas()
    for index in range(5):
        angle = math.radians(-46 + index * 23)
        for step in range(7):
            t = step / 6.0
            radius = 7.0 * (1.0 - t) + 2.0
            distance = 22 + t * 40
            draw.ellipse(
                [
                    18 + math.cos(angle) * distance - radius,
                    64 + math.sin(angle) * distance - radius,
                    18 + math.cos(angle) * distance + radius,
                    64 + math.sin(angle) * distance + radius,
                ],
                fill=WHITE,
            )
    return image


def compost_heap():
    # A mound that reads as built out of pieces, so it can visibly grow.
    image, draw = canvas()
    draw.polygon([(16, 104), (64, 34), (112, 104)], fill=WHITE)
    for cx, cy, r in [(46, 84, 11), (78, 88, 13), (64, 62, 9), (92, 70, 7)]:
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0, 0, 0, 0))
    return image


def burr():
    # Cocklebur: a spiked ball an enemy visibly carries off the Green.
    image, draw = canvas()
    star(draw, 64, 64, 12, 52, 30)
    draw.ellipse([44, 44, 84, 84], fill=WHITE)
    return image


def maw():
    # Man-Eater: two closing jaws, not a mouth-shaped cloud.
    image, draw = canvas()
    upper = [(14, 52), (64, 20), (114, 52)]
    lower = [(14, 76), (64, 108), (114, 76)]
    draw.polygon(upper, fill=WHITE)
    draw.polygon(lower, fill=WHITE)
    for index in range(5):
        x = 26 + index * 19
        draw.polygon([(x, 52), (x + 9, 52), (x + 4, 66)], fill=WHITE)
        draw.polygon([(x, 76), (x + 9, 76), (x + 4, 62)], fill=WHITE)
    return image


def petal():
    # A petal rather than a lozenge: wide and round at the tip, tapering to the
    # point it was torn from, with the crease that tells you which way it flew.
    image, draw = canvas()
    draw.polygon(
        [(64, 116), (26, 62), (36, 26), (64, 12), (92, 26), (102, 62)],
        fill=WHITE,
    )
    draw.line([64, 104, 64, 34], fill=(0, 0, 0, 0), width=6)
    return image


def thorn():
    image, draw = canvas()
    draw.polygon([(20, 100), (108, 24), (74, 96)], fill=WHITE)
    return image


def ghost_ring():
    # A broken ring: the same shape as the effect it echoes, visibly incomplete.
    image, draw = canvas()
    for index in range(8):
        start = index * 45 + 8
        draw.arc([18, 18, 110, 110], start, start + 28, fill=WHITE, width=11)
    return image


def band():
    # Girdling: a band around something, drawn tightening.
    image, draw = canvas()
    draw.ellipse([14, 40, 114, 88], outline=WHITE, width=13)
    draw.rectangle([56, 30, 72, 98], fill=WHITE)
    return image


def tumbleweed():
    # Briarball: a rolling knot of thorns whose spokes read as rotation.
    image, draw = canvas()
    for index in range(9):
        angle = math.pi * 2 * index / 9
        draw.line(
            [
                64 + math.cos(angle) * 12,
                64 + math.sin(angle) * 12,
                64 + math.cos(angle + 0.5) * 54,
                64 + math.sin(angle + 0.5) * 54,
            ],
            fill=WHITE,
            width=9,
        )
    draw.ellipse([44, 44, 84, 84], fill=WHITE)
    return image


def seedling():
    # Puffball's children: smaller and lighter than a Seed.
    image, draw = canvas()
    draw.ellipse([48, 62, 80, 108], fill=WHITE)
    draw.polygon([(64, 66), (34, 34), (60, 44)], fill=WHITE)
    draw.polygon([(64, 66), (96, 30), (70, 44)], fill=WHITE)
    return image


def knot():
    # Briar Knot: low and compact until it springs.
    image, draw = canvas()
    draw.ellipse([26, 46, 102, 100], outline=WHITE, width=12)
    draw.line([30, 92, 98, 52], fill=WHITE, width=11)
    draw.line([30, 52, 98, 92], fill=WHITE, width=11)
    return image


def root_pulse():
    # A pulse travelling along a root rather than appearing along all of it.
    image, draw = canvas()
    draw.line([10, 96, 60, 60, 118, 34], fill=WHITE, width=10, joint="curve")
    draw.line([44, 100, 66, 74], fill=WHITE, width=8)
    draw.line([88, 84, 74, 56], fill=WHITE, width=8)
    draw.ellipse([50, 50, 78, 78], fill=WHITE)
    return image


def runner():
    # A lash thrown from a corpse to one neighbour: a line with a struck end.
    image, draw = canvas()
    draw.line([16, 108, 74, 44], fill=WHITE, width=11)
    star(draw, 92, 30, 6, 30, 12)
    return image


def cutting():
    # A Watersprout child: a splitting twig.
    image, draw = canvas()
    draw.line([64, 116, 64, 62], fill=WHITE, width=12)
    draw.line([64, 66, 26, 22], fill=WHITE, width=10)
    draw.line([64, 66, 102, 22], fill=WHITE, width=10)
    return image


def fuse_spark():
    # Domino's cascade: a spark travelling a line, so the fuse reads as moving.
    image, draw = canvas()
    draw.line([8, 82, 120, 82], fill=WHITE, width=7)
    star(draw, 78, 82, 8, 34, 13)
    return image


def falling_body():
    # Newton's Apple: a launched body with a short motion streak behind it.
    image, draw = canvas()
    draw.ellipse([70, 30, 118, 78], fill=WHITE)
    for index in range(3):
        y = 40 + index * 14
        draw.line([12 + index * 6, y, 62, y + 6], fill=WHITE, width=7)
    return image


MOTIFS = {
    "cue_spray_stream": spray_stream,
    "cue_compost_heap": compost_heap,
    "cue_burr": burr,
    "cue_maw": maw,
    "cue_petal": petal,
    "cue_thorn": thorn,
    "cue_ghost_ring": ghost_ring,
    "cue_band": band,
    "cue_tumbleweed": tumbleweed,
    "cue_seedling": seedling,
    "cue_knot": knot,
    "cue_root_pulse": root_pulse,
    "cue_runner": runner,
    "cue_cutting": cutting,
    "cue_fuse_spark": fuse_spark,
    "cue_falling_body": falling_body,
}


def main():
    for name, builder in sorted(MOTIFS.items()):
        path = os.path.join(OUT, name + ".png")
        builder().save(path)
        print("wrote", os.path.basename(path))


if __name__ == "__main__":
    main()
