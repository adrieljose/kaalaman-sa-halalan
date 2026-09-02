# -*- coding: utf-8 -*-
"""Builds the browser-tab / app icon from the PixelLab ballot-box sprite.

The web export had been shipping Godot's default blue robot, because
`config/icon` still pointed at the stock `icon.svg` and `html/export_icon=true`
derives `index.icon.png` and `index.apple-touch-icon.png` from it.

`ballot_64.png` beside this file is the PixelLab source (one generation,
64x64, generated against a forced palette sampled from the game's own UI art --
see PALETTE_SOURCES below, which is what makes the icon the same gold and wood
as the title screen rather than a second look). Everything this script adds is
about one thing: surviving a 16px browser tab.

Three decisions, all of them measured against a 16px downscale rather than
guessed at:

  DARK PLATE     The sprite is cream and gold on transparency. On a light tab
                 strip it washed out entirely. A near-black rounded tile gives
                 it a constant ground in either browser theme.

  TONE SPLIT     At tab size the box only has to read as a solid base, so it is
                 pushed down toward the plate, while the ballot -- the part that
                 carries the meaning -- is lifted toward white. That widens the
                 gap between them from ~60 levels of luminance to ~130. Without
                 it the whole thing greys into one brown blob.

  ONE PIXEL RIM  Anything thicker matched the box's own gold banding and the two
                 merged; nothing at all left the dark tile with no edge against
                 a dark tab strip.

Scaling is NEAREST at an integer factor only, so the 64px pixel grid is never
resampled onto half-pixels. 256 is the output because Godot shrinks it to both
128 (favicon) and 180 (apple-touch): both are then downscales, which stay sharp,
rather than upscales, which invent detail.

    python tools/icon/make_app_icon.py

Writes assets/images/ui/app_icon.png. Re-run after replacing ballot_64.png; the
export picks it up on the next --export-release.
"""
import os

from PIL import Image, ImageDraw

SRC = "tools/icon/ballot_64.png"
OUT = "assets/images/ui/app_icon.png"
PREVIEW = "tools/icon/_preview.png"

## Where the forced palette handed to PixelLab came from. Kept as a record of
## how the source was generated, not read at runtime.
PALETTE_SOURCES = ["assets/images/ui/title_logo.png",
                   "assets/images/ui/panel_ornate.png",
                   "assets/images/ui/button_banner.png"]

S = 64
RADIUS = 12
PLATE = (26, 18, 10, 255)
RIM = (150, 114, 44, 255)
## Luminance below which a pixel counts as "the box" rather than "the ballot".
TONE_CUT = 170
BOX_GAIN = 0.50
BALLOT_GAIN = 1.22
## The sprite sits a shade low in its own 64px frame; this centres it optically.
ART_OFFSET = (0, -2)


def split_tones(art):
    out = art.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            k = BOX_GAIN if lum < TONE_CUT else BALLOT_GAIN
            px[x, y] = (min(255, int(r * k)), min(255, int(g * k)),
                        min(255, int(b * k)), a)
    return out


def main():
    art = split_tones(Image.open(SRC).convert("RGBA"))

    icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(icon)
    draw.rounded_rectangle([0, 0, S - 1, S - 1], RADIUS, fill=RIM)
    draw.rounded_rectangle([1, 1, S - 2, S - 2], RADIUS - 1, fill=PLATE)
    icon.alpha_composite(art, ART_OFFSET)

    # The sprite overhangs the rounded corners slightly; clip it back so the
    # tile has clean edges instead of four stray pixels.
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], RADIUS, fill=255)
    icon.putalpha(Image.composite(icon.getchannel("A"),
                                  Image.new("L", (S, S), 0), mask))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    icon.resize((256, 256), Image.NEAREST).save(OUT)

    # What it looks like where it actually has to work: 16px and 32px, blown
    # back up so the result is inspectable.
    strip = Image.new("RGBA", (96 * 2 + 16, 96), (245, 245, 247, 255))
    for i, size in enumerate((16, 32)):
        small = icon.resize((size, size), Image.LANCZOS)
        strip.alpha_composite(small.resize((96, 96), Image.NEAREST), (i * 112, 0))
    strip.save(PREVIEW)
    print("wrote %s (256x256) and %s" % (OUT, PREVIEW))


main()
