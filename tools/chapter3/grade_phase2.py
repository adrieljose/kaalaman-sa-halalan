# -*- coding: utf-8 -*-
"""Grades the governor's office into its phase 2 arena.

Chapter 2 paid a generation for a phase-2 room and got one BRIGHTER than phase
1 -- backwards for a transformation that reads as the lights going out -- so it
was graded anyway. Chapter 3 skips the generation and goes straight to the
grade, which is the better method regardless: a grade lines up with phase 1
pixel for pixel, so the arena changes UNDER the player rather than cutting to a
different room.

    python tools/chapter3/grade_phase2.py

The look: the lights go down, the room falls back toward red-orange, the window
side keeps a warm bloom (the only light left is coming in from outside), and a
vignette closes in the corners. Then everything is quantised back to a small
number of tones, because smooth gradients are the giveaway that a pixel-art
image has been post-processed.
"""
import os

from PIL import Image, ImageEnhance, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BG = os.path.join(ROOT, "assets", "images", "backgrounds")
SRC = os.path.join(BG, "capitol_governor_office.png")
DST = os.path.join(BG, "capitol_governor_office_phase2.png")

DIM = 0.54            # how far the lights go down
TINT = (255, 96, 40)  # the red-orange the room falls back to
TINT_MIX = 0.28
BLOOM = 0.30          # warm light left coming through the windows
VIGNETTE = 0.55       # how dark the corners close in
TONES = 24            # palette size after grading


def main():
    img = Image.open(SRC).convert("RGB")
    w, h = img.size

    img = ImageEnhance.Brightness(img).enhance(DIM)
    img = ImageEnhance.Color(img).enhance(0.72)

    px = img.load()
    tr, tg, tb = TINT
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            r = int(r + (tr - r) * TINT_MIX)
            g = int(g + (tg - g) * TINT_MIX)
            b = int(b + (tb - b) * TINT_MIX)

            # Bloom from the upper centre, where the tall windows are: the only
            # light still in the room is the light from outside it.
            dx = (x - w * 0.5) / (w * 0.5)
            dy = (y - h * 0.34) / (h * 0.6)
            near = max(0.0, 1.0 - (dx * dx + dy * dy))
            k = BLOOM * near
            r = int(r + (255 - r) * k * 0.55)
            g = int(g + (190 - g) * k * 0.45)
            b = int(b + (120 - b) * k * 0.25)

            # Vignette, measured from the centre outward.
            vx = (x - w * 0.5) / (w * 0.5)
            vy = (y - h * 0.5) / (h * 0.5)
            far = min(1.0, (vx * vx + vy * vy) * 0.62)
            v = 1.0 - VIGNETTE * far
            px[x, y] = (
                max(0, min(255, int(r * v))),
                max(0, min(255, int(g * v))),
                max(0, min(255, int(b * v))),
            )

    # Back to flat tones. Every other surface in this room is a handful of flat
    # colours; a smoothly graded one would not sit with them.
    img = img.quantize(colors=TONES, method=Image.MEDIANCUT, dither=Image.NONE)
    img = img.convert("RGBA")
    img.save(DST)
    print("wrote %s" % DST)


if __name__ == "__main__":
    main()
