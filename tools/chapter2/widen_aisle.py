# -*- coding: utf-8 -*-
"""Widens the aisle in Chapter 1's session hall so the fighters stand on it.

Same fault as the Chapter 2 hall: the room was generated without regard for
where the fighters stand, so the tiled aisle runs up the middle and the sides
are auditorium seating. Juan was standing astride a seat's armrest and Senator
Sabaw on the row beside him.

It needs far less than the other hall did, though. The aisle already reaches art
x 95..292 at the ground line and the fighters' feet land at 75 and 310 — about
twenty pixels short on each side. So rather than deleting seat rows, the seating
is PUSHED OUTWARD and the strip it vacates is filled with floor. Every seat
survives, and the widening ramps in from nothing so there is no seam where it
starts.

The ramp is not only there to hide the join: an aisle SHOULD widen as it comes
toward the camera, so growing the shift with depth is the perspective the room
already has, applied a little harder.
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, "rooms_raw", "battle_session_hall.png")
DST = r"D:\klhgamefinal\assets\images\backgrounds\battle_session_hall.png"

# Where the widening starts, and how far the seating has moved by the bottom
# edge. 44 puts the aisle at roughly art 67..320 on the line the fighters stand
# on, which clears both of them by about eight pixels.
RAMP_FROM = 196
MAX_SHIFT = 44


def is_floor(c):
    """The tiled aisle: the only bright, warm, low-contrast thing down here.

    The seats are near-black navy and the panelling is a dark red-brown, so a
    plain brightness test would be enough — but keeping the warm/neutral clause
    means a lit seat back cannot pass for floor.
    """
    r, g, b = c
    return (r + g + b) / 3.0 > 105 and r >= b and r - b < 90


def _tone(px, x0, y, w, span=7):
    """The typical floor colour in a short horizontal window."""
    xs = [min(max(x0 + i, 0), w - 1) for i in range(span)]
    samples = sorted((px[x, y] for x in xs), key=lambda c: c[0] + c[1] + c[2])
    return samples[len(samples) // 2]


def aisle(px, y, w):
    best, run = None, None
    for x in range(w):
        if is_floor(px[x, y]):
            run = x if run is None else run
        elif run is not None:
            if best is None or x - run > best[1] - best[0]:
                best = (run, x)
            run = None
    if run is not None and (best is None or w - run > best[1] - best[0]):
        best = (run, w)
    return best


def build():
    im = Image.open(SRC).convert("RGB")
    w, h = im.size
    px = im.load()
    out = im.copy()
    op = out.load()

    widest = 0
    for y in range(RAMP_FROM, h):
        run = aisle(px, y, w)
        if run is None:
            continue
        a, b = run
        k = int(round(MAX_SHIFT * (y - RAMP_FROM) / float(h - 1 - RAMP_FROM)))
        if k <= 0:
            continue
        # A MEDIAN of several pixels just inside the aisle's own edge, so the
        # fill carries this row's tone and the shading the floor already has
        # where it meets the seating.
        #
        # Median, not a single pixel: this floor's tile joints run diagonally,
        # so one sample per row lands on a joint on some rows and not others,
        # and the strip comes out in horizontal stripes that no floor has.
        # Taking the middle of a short window steps over a joint crossing it.
        left_tone = _tone(px, a + 1, y, w)
        right_tone = _tone(px, b - 8, y, w)
        for x in range(w):
            if a <= x < b:
                continue
            if x < a:
                op[x, y] = left_tone if x >= a - k else px[x + k, y]
            else:
                op[x, y] = right_tone if x < b + k else px[x - k, y]
        widest = max(widest, (b + k) - (a - k))

    out.save(DST)
    return widest


if __name__ == "__main__":
    print("widest aisle after widening: %d px of 384 -> %s"
          % (build(), os.path.basename(DST)))
