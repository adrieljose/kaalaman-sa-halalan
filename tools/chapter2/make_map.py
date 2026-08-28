# -*- coding: utf-8 -*-
"""Rebuilds the chapter-select map so each island reads as its chapter.

The shipped map was a generic fantasy scene -- palm islands, purple mountains
and one pink temple -- which told the player nothing about where a chapter was
set. This drops a real landmark onto each island instead, so the progression
from a barangay hall to the Congress is legible at a glance.

The five landmarks come from ONE generated image (tools/chapter2/landmarks_raw
.png): the buildings were generated in a row with gaps, then cut apart on the
alpha channel's column runs rather than on fixed cells, so uneven spacing in
the generation cannot mis-slice them.

They arrive near-monochrome, which is useful: recolouring by luminance onto a
per-chapter ramp gives each place its own palette while keeping one drawing
style across all five, and lets the ramp carry the progression -- humble warm
timber at the barangay, cold civic stone in the middle, ivory and gold at the
palace and the Congress.
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))
MAP = r"D:\klhgamefinal\assets\images\backgrounds\chapter_map.png"
RAW = os.path.join(ROOT, "landmarks_raw.png")
# Always rebuilt from the untouched original, so re-running never stacks
# landmarks on top of the ones a previous run already drew.
ORIGINAL = os.path.join(ROOT, "chapter_map_original.png")

# Column runs of the five buildings in landmarks_raw.png, found by scanning the
# alpha channel. Recomputed at run time so a regenerated sheet still slices.
MIN_RUN = 6

# Where each chapter's pin sits on the 640x480 map, from main_menu.tscn.
PINS = [(100, 314), (234, 232), (352, 114), (470, 280), (566, 146)]

# Dark outline, shadow, midtone, highlight -- darkest first.
RAMPS = [
    [(58, 34, 22), (122, 74, 44), (196, 150, 96), (246, 226, 186)],   # barangay
    [(38, 44, 62), (92, 104, 128), (170, 182, 200), (242, 246, 252)],  # city hall
    [(34, 52, 48), (78, 116, 106), (150, 190, 176), (238, 250, 244)],  # capitol
    [(66, 34, 30), (140, 78, 52), (214, 158, 96), (252, 238, 208)],   # palace
    [(30, 34, 58), (78, 88, 132), (158, 168, 208), (244, 246, 255)],  # congress
]

# Per-island scale: the small outlying islands cannot carry a full-size
# building without spilling into the sea.
SCALES = [1.05, 1.35, 1.15, 1.10, 1.00]

# Nudges off the pin, in pixels. The pins were placed against the old artwork,
# and a couple of them land on a mountain rather than on open ground.
NUDGES = [(6, 10), (0, 6), (0, 6), (-14, 6), (-10, 4)]

# The pink temple the old map put on the central island competes with the new
# City Hall, so it is painted out first. A flat fill left an obvious rectangle
# against the island's dappled grass, so the patch is tiled from the least
# varied grass found elsewhere on the SAME island instead.
TEMPLE_BOX = (214, 148, 294, 212)
ISLAND_BOX = (150, 130, 390, 340)


def grass_patch(world, w, h):
    """Find the flattest w x h block of the central island and return it.
    Lowest colour variance means no trees, no path and no shoreline -- the
    parts that would betray a tiled patch."""
    best, best_var = None, None
    x0, y0, x1, y1 = ISLAND_BOX
    for y in range(y0, y1 - h, 6):
        for x in range(x0, x1 - w, 6):
            block = world.crop((x, y, x + w, y + h)).convert("RGB")
            px = list(block.getdata())[::7]
            n = len(px)
            mean = [sum(c[i] for c in px) / n for i in range(3)]
            var = sum(sum((c[i] - mean[i]) ** 2 for i in range(3)) for c in px) / n
            # Grass only: skip anything that is mostly sand, sea or path.
            if not (60 < mean[1] < 165 and mean[1] > mean[2] + 12):
                continue
            if best_var is None or var < best_var:
                best, best_var = (x, y), var
    if best is None:
        return None
    return world.crop((best[0], best[1], best[0] + w, best[1] + h))


def is_sea(p):
    r, g, b = p[:3]
    return b > 120 and b >= g - 10 and r < 140


def snap_to_land(world, pin, size, nudge, reach=46):
    """Slide a landmark off its pin until it is standing on ground.

    The pins were placed against the old artwork and several sit a little off
    their island, so a building anchored straight to one hangs over the sea.
    Rather than hand-tuning five offsets by eye, search a window around the pin
    for the spot whose FOOTPRINT -- the bottom few rows, where the building
    meets the ground -- is most solidly land, breaking ties by staying close to
    the pin so a landmark never wanders to a different island.
    """
    w, h = size
    px, py = pin[0] + nudge[0], pin[1] + nudge[1]
    best, best_score = None, None
    for dy in range(-reach, reach + 1, 2):
        for dx in range(-reach, reach + 1, 2):
            x = px - w // 2 + dx
            y = py - h - 2 + dy
            foot = world.crop((x, y + h - 6, x + w, y + h)).convert("RGB")
            pixels = list(foot.getdata())
            if not pixels:
                continue
            land = sum(0 if is_sea(p) else 1 for p in pixels) / len(pixels)
            # Land fraction dominates; distance from the pin only breaks ties.
            score = land * 1000.0 - (abs(dx) + abs(dy)) * 0.5
            if best_score is None or score > best_score:
                best, best_score = (x, y), score
    return best


def column_runs(im):
    a = im.split()[3]
    cols = [max(a.getpixel((x, y)) for y in range(im.height))
            for x in range(im.width)]
    runs, start = [], None
    for x, v in enumerate(cols + [0]):
        if v > 40 and start is None:
            start = x
        elif v <= 40 and start is not None:
            if x - start > MIN_RUN:
                runs.append((start, x))
            start = None
    return runs


def recolour(sprite, ramp):
    """Map luminance onto the chapter's ramp, keeping the original shading."""
    out = sprite.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a < 40:
                px[x, y] = (0, 0, 0, 0)
                continue
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            if lum < 70:
                c = ramp[0]
            elif lum < 140:
                c = ramp[1]
            elif lum < 205:
                c = ramp[2]
            else:
                c = ramp[3]
            px[x, y] = c + (255,)
    return out


def outline(sprite, colour=(24, 18, 14, 220)):
    """A one-pixel skirt so a pale building still reads against pale sand."""
    w, h = sprite.size
    pad = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    a = sprite.split()[3]
    ring = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    solid = Image.new("RGBA", (w, h), colour)
    for dx, dy in ((0, 1), (2, 1), (1, 0), (1, 2), (0, 0), (2, 0), (0, 2), (2, 2)):
        ring.paste(solid, (dx, dy), a)
    pad.paste(ring, (0, 0), ring)
    pad.paste(sprite, (1, 1), sprite)
    return pad


def build():
    raw = Image.open(RAW).convert("RGBA")
    runs = column_runs(raw)
    if len(runs) != 5:
        raise SystemExit("expected 5 buildings, found %d: %s" % (len(runs), runs))

    world = Image.open(ORIGINAL if os.path.exists(ORIGINAL) else MAP).convert("RGBA")

    # Clear the old temple so the City Hall is the only landmark on that island.
    tw = TEMPLE_BOX[2] - TEMPLE_BOX[0]
    th = TEMPLE_BOX[3] - TEMPLE_BOX[1]
    patch = grass_patch(world, tw, th)
    if patch is not None:
        world.paste(patch, TEMPLE_BOX[:2])

    placed = []
    for i, (x0, x1) in enumerate(runs):
        strip = raw.crop((x0, 0, x1, raw.height))
        bb = strip.getbbox()
        sprite = strip.crop(bb)
        sprite = recolour(sprite, RAMPS[i])
        sprite = outline(sprite)

        s = SCALES[i]
        sprite = sprite.resize((max(1, int(sprite.width * s)),
                                max(1, int(sprite.height * s))), Image.NEAREST)

        # The pin marks the doorway, so the building sits ON it: centred
        # horizontally and standing with its base just above the pin's middle.
        pos = snap_to_land(world, PINS[i], sprite.size, NUDGES[i])
        world.alpha_composite(sprite, pos)
        placed.append((i + 1, sprite.size, pos))

    world.save(MAP)
    return placed


if __name__ == "__main__":
    for n, size, pos in build():
        print("chapter %d  %dx%d at %s" % (n, size[0], size[1], pos))
