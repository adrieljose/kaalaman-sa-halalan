# -*- coding: utf-8 -*-
"""Paints the bidding room's projector screen, which shipped as a flat fill.

The room has a ceiling projector and a framed screen on the back wall, and the
screen's interior was left as 6,240 pixels of one exact colour (#0B743C) with
no shading, no falloff and no texture -- the third most common colour in the
whole image. Everything around it is properly rendered pixel art, so it reads
as a chroma-key placeholder rather than as a screen.

This does not invent content for it. It keeps the artist's hue and makes the
surface behave like a lit screen:

  HOTSPOT    a projector throws from above and in front, so the brightest
             point sits above centre and the light falls off from there.
  VIGNETTE   corners are dimmest, which is what stops it reading as a decal.
  SCANLINES  faint horizontal banding -- the cheapest, most legible shorthand
             for "this is a display" at this resolution.
  INNER      the frame casts a shadow along its top and left edges.
  SHADOW

Then the whole patch is quantised back to a handful of tones. Smooth gradients
would be the giveaway here: every other surface in this room is a few flat
steps, so a continuous ramp would look wrong in the opposite direction.

The untouched original is kept in rooms_raw/ so this is reversible and the edit
can be re-derived if the tuning changes.
"""
import math
import os
import shutil

from PIL import Image

SRC = "assets/images/backgrounds/cityhall_bidding.png"
RAW = "tools/chapter2/rooms_raw/cityhall_bidding.png"
BOX = (140, 63, 244, 123)          # x0, y0, x1, y1 -- the flat run, exclusive
FLAT = (11, 116, 60)
STEPS = 5                          # tones the finished screen is allowed


def main():
    os.makedirs(os.path.dirname(RAW), exist_ok=True)
    if not os.path.exists(RAW):
        shutil.copy(SRC, RAW)
        print(f"  kept the original at {RAW}")

    im = Image.open(RAW).convert("RGBA")
    px = im.load()
    x0, y0, x1, y1 = BOX
    w, h = x1 - x0, y1 - y0

    # The projector sits above and forward, so the hotspot is high and central.
    hx, hy = 0.5, 0.34
    for y in range(y0, y1):
        for x in range(x0, x1):
            if px[x, y][:3] != FLAT:
                continue                     # never touch the frame
            u = (x - x0) / (w - 1)
            v = (y - y0) / (h - 1)

            d = math.hypot((u - hx) * 1.25, (v - hy))
            light = 1.18 - 0.72 * min(d / 0.72, 1.0) ** 1.25

            # Corners darkest.
            light *= 1.0 - 0.30 * (abs(u - 0.5) * 2.0) ** 2 \
                         - 0.22 * (abs(v - 0.5) * 2.0) ** 2

            # Frame shadow: a couple of rows/columns in from the top and left.
            edge = min(x - x0, y - y0)
            if edge < 3:
                light *= 0.62 + 0.13 * edge

            # Display banding.
            if (y - y0) % 3 == 0:
                light *= 0.93

            r = FLAT[0] + 150 * (light - 0.55)
            g = FLAT[1] * (0.42 + 0.72 * light)
            b = FLAT[2] * (0.55 + 0.62 * light) + 26 * max(light - 0.9, 0.0)
            px[x, y] = (max(0, min(255, int(r))),
                        max(0, min(255, int(g))),
                        max(0, min(255, int(b))), 255)

    # Quantise the patch alone, so the rest of the room's palette is untouched.
    patch = im.crop(BOX).convert("RGB")
    patch = patch.quantize(colors=STEPS, method=Image.MEDIANCUT,
                           dither=Image.Dither.NONE).convert("RGB")
    im.paste(patch, (x0, y0))
    im.save(SRC)

    # Report what actually changed.
    out = Image.open(SRC).convert("RGB").load()
    tones = {out[x, y] for y in range(y0, y1) for x in range(x0, x1)}
    flat_left = sum(1 for y in range(y0, y1) for x in range(x0, x1)
                    if out[x, y] == FLAT)
    print(f"  screen repainted: {len(tones)} tones over {w}x{h}, "
          f"{flat_left} pixels still the old flat colour")


main()
