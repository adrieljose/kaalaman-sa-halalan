# -*- coding: utf-8 -*-
"""Grades the phase 2 boss arena into 'the mask comes off'.

The generated variant supplies what generation is good at -- the same room
with documents tumbling through it -- but came back brighter than phase 1
rather than darker, which is the wrong way round for a transformation that is
supposed to read as the lights going out.

So the mood is applied here instead of asked for again: the room is dimmed,
pushed toward red-orange, given a warm bloom on the vault side and a vignette.
Doing it as a grade rather than a re-roll also guarantees phase 2 lines up with
phase 1 pixel for pixel, which is the whole point of an arena that changes
under the player rather than a different room.
"""
import os

from PIL import Image, ImageEnhance, ImageFilter

BG = r"D:\klhgamefinal\assets\images\backgrounds"
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "phase2_raw.png")
DST = os.path.join(BG, "cityhall_mayor_office_phase2.png")

DIM = 0.52          # how far the lights go down
TINT = (255, 96, 40)  # the red-orange the room falls back to
TINT_MIX = 0.30
BLOOM = (255, 170, 70)  # vault-side glow


def grade(im):
    w, h = im.size
    im = ImageEnhance.Brightness(im).enhance(DIM)
    im = ImageEnhance.Contrast(im).enhance(1.18)

    # Pull the whole room toward one hot colour, which is what makes it read as
    # a single dramatic light source rather than as a darker version of the
    # same daylight.
    tint = Image.new("RGB", (w, h), TINT)
    im = Image.blend(im, tint, TINT_MIX)

    # Bloom from the vault on the right, falling off across the room. Added
    # rather than blended, so it lifts the light side without washing out the
    # dark one -- a blend would lighten the whole frame and undo the dimming.
    glow = Image.new("RGB", (w, h), (0, 0, 0))
    gp = glow.load()
    for x in range(w):
        f = max(0.0, (x - w * 0.55) / (w * 0.45)) ** 1.6
        for y in range(h):
            v = f * max(0.0, 1.0 - abs(y - h * 0.55) / (h * 0.75))
            gp[x, y] = tuple(int(c * v) for c in BLOOM)
    glow = glow.filter(ImageFilter.GaussianBlur(6))

    px, gpx = im.load(), glow.load()
    for x in range(w):
        for y in range(h):
            r, g, b = px[x, y]
            gr, gg, gb = gpx[x, y]
            px[x, y] = (min(255, r + gr), min(255, g + gg), min(255, b + gb))

    # Vignette: darkens the corners so the eye goes to the desk and the vault.
    cx, cy = w * 0.5, h * 0.52
    maxd = (cx ** 2 + cy ** 2) ** 0.5
    for x in range(w):
        for y in range(h):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / maxd
            k = 1.0 - 0.55 * max(0.0, d - 0.35) / 0.65
            r, g, b = px[x, y]
            px[x, y] = (int(r * k), int(g * k), int(b * k))
    return im


if __name__ == "__main__":
    out = grade(Image.open(SRC).convert("RGB"))
    out.save(DST)
    print("phase 2 arena graded ->", DST)
