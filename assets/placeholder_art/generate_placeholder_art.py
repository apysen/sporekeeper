"""Generate the placeholder VFX sprites for the relic cue layer.

Eight soft primitives, not one sprite per relic. Anything with structure -- a
spray fan, a thorny strand, a row of stubble, a root reaching forward -- is drawn
by repeating one of these along a path at draw time, which is cheaper than baking
a bespoke sprite for every relic and keeps the whole pool looking like one family.

They are effect sprites rather than icons: soft alpha falloff instead of a hard
silhouette, directional forms pointing along +X so the overlay's rotation aims
them, radial forms centred so they can be scaled up as a wave. White with a
shaped alpha channel, because colour comes from the tint at draw time -- that is
what lets one streak serve Bramble's purple and Vine's green from one file.

Placeholders on purpose. Regenerate with:

    python assets/placeholder_art/generate_placeholder_art.py
"""
import os

import numpy as np
from PIL import Image

SIZE = 128
OUT = os.path.dirname(os.path.abspath(__file__))

# Pixel-centre grid in -1..1, so every field below is written in shape terms.
_axis = (np.arange(SIZE) + 0.5) / SIZE * 2.0 - 1.0
X, Y = np.meshgrid(_axis, _axis)
RADIUS = np.hypot(X, Y)
ANGLE = np.arctan2(Y, X)


def smoothstep(edge0, edge1, value):
    span = np.maximum(np.asarray(edge1) - np.asarray(edge0), 1e-6)
    t = np.clip((value - edge0) / span, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def falloff(distance, inner, outer):
    """Solid inside `inner`, fading to nothing at `outer`."""
    return 1.0 - smoothstep(inner, outer, distance)


def save(name, alpha):
    alpha = np.clip(alpha, 0.0, 1.0)
    rgba = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
    rgba[..., 0:3] = 255
    rgba[..., 3] = (alpha * 255.0).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, name + ".png"))
    return name


def particle():
    # The workhorse. A soft circular dab: one is a droplet, a line of them is
    # Garden Hose's spray, a scatter of them is a puff, a row along a wound is
    # Stubble. Most of the pool is this sprite used more than once.
    return falloff(RADIUS, 0.05, 0.62) ** 1.4


def glow():
    # The same idea spread much wider and much softer: a charge, a primed relic,
    # a swollen bud. Never a hard edge anywhere in it.
    return falloff(RADIUS, 0.0, 0.95) ** 2.0


def ring():
    # An expanding wave, and the echo shape. Thin and soft on both edges so
    # scaling it up reads as travelling outward.
    return falloff(np.abs(RADIUS - 0.66), 0.02, 0.22)


def shockwave():
    # A ring with a bright leading edge and a faint wake behind it, for the
    # detonations that need to look like they are moving rather than pulsing.
    edge = falloff(np.abs(RADIUS - 0.78), 0.01, 0.12)
    wake = falloff(RADIUS, 0.30, 0.78) * 0.22
    return np.maximum(edge, wake)


def streak():
    # A soft taper, bright at +X. A thrown petal, a lash, a relay ping, a motion
    # trail -- all the same shape at different lengths.
    along = smoothstep(-0.95, 0.6, X)
    width = 0.02 + 0.17 * along
    return falloff(np.abs(Y), width * 0.25, width) * (0.30 + 0.70 * along)


def spark():
    # A small hot point with a faint cross, for a chip off basalt or the head of
    # a fuse. Deliberately tiny: it is an accent, not an explosion.
    core = falloff(RADIUS, 0.0, 0.30) ** 1.5
    cross = np.maximum(
        falloff(np.abs(Y), 0.0, 0.05) * falloff(np.abs(X), 0.10, 0.62),
        falloff(np.abs(X), 0.0, 0.05) * falloff(np.abs(Y), 0.10, 0.62),
    )
    return np.maximum(core, cross * 0.55)


def burst():
    # Radial spokes over a soft core: a detonation, an eruption, a synchronised
    # volley going off at once.
    spokes = (np.cos(ANGLE * 8.0) * 0.5 + 0.5) ** 2.0
    return np.clip(falloff(RADIUS, 0.06, 0.92) * (0.35 + 0.65 * spokes), 0.0, 1.0)


def swirl():
    # A soft spiral, for the two effects whose whole identity is rotation:
    # Phyllotaxis's spiral packet and Briarball rolling.
    arm = np.abs(np.sin((ANGLE - RADIUS * 5.0) * 0.5))
    return falloff(RADIUS, 0.25, 0.92) * (1.0 - smoothstep(0.20, 0.62, arm))


SPRITES = {
    "vfx_particle": particle,
    "vfx_glow": glow,
    "vfx_ring": ring,
    "vfx_shockwave": shockwave,
    "vfx_streak": streak,
    "vfx_spark": spark,
    "vfx_burst": burst,
    "vfx_swirl": swirl,
}


def main():
    for name, builder in sorted(SPRITES.items()):
        print("wrote", save(name, builder()) + ".png")


if __name__ == "__main__":
    main()
