# -*- coding: utf-8 -*-
"""Opens the floor at the front of the session hall.

The room came back from generation with tiered desks filling the full width and
a narrow aisle up the middle -- so at the line the fighters stand on, the only
carpet is art x 142..241 out of 384. That is dead centre, exactly where the
letter board sits, so no amount of moving the fighters or re-cropping the
backdrop can put them on it: at the sides they were standing on the dark
foreground chair backs, which is what the whole room looked wrong for.

There are no generations left to redraw the room, so the room is edited: the
foreground chair mass across the bottom is replaced with carpet, which turns the
front of the chamber into open floor. That is not a workaround dressed up -- the
well of a session hall IS open floor in front of the desks, and it is where two
people arguing would actually be standing.

Nothing is invented. The replacement carpet is the room's OWN carpet, mirrored
outward row by row, so it keeps the existing dithering and the vertical gradient
that makes the floor recede. A horizontal falloff and a contact shadow under the
new front edge of the tier are the only additions, and both are derived from
what the art already does elsewhere.
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, "rooms_raw", "cityhall_session_hall.png")
DST = r"D:\klhgamefinal\assets\images\backgrounds\cityhall_session_hall.png"

# Where to start looking for the foreground mass. Above this the desk tiers are
# interleaved with aisle and must not be touched.
SCAN_FROM = 206
# A column is foreground once it is dark continuously from here to the bottom.
DARK_LUM = 58
# How far the carpet dims between the aisle and the frame edge. The room already
# shades its floor away from the centre; this continues it rather than pasting a
# flat red slab into the corners.
EDGE_DIM = 0.74
# The tier has to sit ON the new floor, not hover over it.
CONTACT_ROWS = 3
CONTACT_DIM = 0.62


def is_carpet(c):
    r, g, b = c
    return r > 120 and g < 0.42 * r and b < 0.55 * r


def carpet_run(px, y, w):
    """The widest unbroken carpet run in a row — the aisle."""
    best, run = None, None
    for x in range(w):
        if is_carpet(px[x, y]):
            run = x if run is None else run
        elif run is not None:
            if best is None or x - run > best[1] - best[0]:
                best = (run, x)
            run = None
    if run is not None and (best is None or w - run > best[1] - best[0]):
        best = (run, w)
    return best


def cut_row(px, x, h):
    """First row at which this column is dark all the way down, or None.

    Scanning from the BOTTOM up and stopping at the first light pixel is what
    makes this follow the chair backs' own sloping top edge instead of a
    straight line ruled across the picture.
    """
    y = h - 1
    if sum(px[x, y]) / 3.0 >= DARK_LUM:
        return None
    while y > SCAN_FROM and sum(px[x, y - 1]) / 3.0 < DARK_LUM:
        y -= 1
    return y


def build():
    im = Image.open(SRC).convert("RGB")
    w, h = im.size
    px = im.load()
    out = im.copy()
    op = out.load()

    runs = {y: carpet_run(px, y, w) for y in range(SCAN_FROM, h)}
    cuts = {x: cut_row(px, x, h) for x in range(w)}

    filled = 0
    for x in range(w):
        top = cuts[x]
        if top is None:
            continue
        for y in range(top, h):
            run = runs.get(y)
            if run is None:
                continue
            a, b = run
            if a <= x < b:
                continue
            span = max(b - a, 1)
            # Ping-pong the aisle outward, so the fill carries the carpet's own
            # texture rather than one flat colour smeared across the corner.
            if x < a:
                k = (a - x) % (2 * span)
                sx = a + k if k < span else a + (2 * span - k) - 1
                edge = (a - x) / float(max(a, 1))
            else:
                k = (x - b + 1) % (2 * span)
                sx = b - k if k < span else b - (2 * span - k)
                edge = (x - b + 1) / float(max(w - b, 1))
            sx = min(max(sx, a), b - 1)

            dim = 1.0 - (1.0 - EDGE_DIM) * min(edge, 1.0)
            depth = y - top
            if depth < CONTACT_ROWS:
                # The tier's base shadow, strongest right under its edge.
                dim *= CONTACT_DIM + (1.0 - CONTACT_DIM) * (depth / float(CONTACT_ROWS))
            r, g, b2 = px[sx, y]
            op[x, y] = (int(r * dim), int(g * dim), int(b2 * dim))
            filled += 1

    out.save(DST)
    return filled, sum(1 for v in cuts.values() if v is not None)


if __name__ == "__main__":
    n, cols = build()
    print("repainted %d pixels across %d columns -> %s" % (n, cols, os.path.basename(DST)))
