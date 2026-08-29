# -*- coding: utf-8 -*-
"""Prepare Chapter 1 rival sprites as v3-rotation references.

Same recipe that worked for Chapter 2 -- crop to the opaque bounds so no
budget is spent rotating empty canvas, then shrink the FILE (not the picture)
until the inline base64 is small enough that the MCP client cannot truncate it
mid-string, which silently corrupts the reference and wastes a generation.

The lever is the encoding, not the resolution: an N-colour PALETTE png with a
transparent index is one byte per pixel before compression, where the RGBA png
I first reached for is four. Every pixel of the original survives, so the
reference still defines the character exactly.

The transparent index is built by hand rather than left to Pillow. Quantizing
and then pasting a "spare" index only looks right until PNG `optimize` renumbers
the palette, at which point the index that meant "hole" means a colour and the
reference silently becomes an opaque rectangle -- which is exactly what a
rotation job would then faithfully rotate. `check()` below is what catches that,
and it is asserted on every build rather than eyeballed.
"""
import base64, io, os
from PIL import Image

SRC = r"D:\klhgamefinal\assets\images\characters"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "refs")
BUDGET = 3600          # comfortably under the ~3.9k truncation seen before

SLUGS = ["lord_trapo", "vote_vandal", "senator_sabaw",
         "kapitan_komisyon", "ate_ayuda"]


def encode(im, colors):
    """Quantize to `colors` palette entries plus one reserved transparent index.

    Pixel art has no partial transparency, so alpha is hard-thresholded first;
    a palette that spends entries on soft edges is a palette wasted.
    """
    hole = im.getchannel("A").point(lambda v: 0 if v > 127 else 255)
    pal = im.convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT,
                                     dither=Image.Dither.NONE)

    table = (pal.getpalette() or [])[:colors * 3]
    table += [0] * (colors * 3 - len(table))
    clear = colors
    table += [255, 0, 255]                 # the reserved hole, never drawn

    pal.paste(clear, (0, 0), hole)         # stamp it through the alpha mask
    pal.putpalette(table)

    buf = io.BytesIO()
    # optimize would renumber the palette and take the hole with it.
    pal.save(buf, "PNG", optimize=False, transparency=clear)
    return pal, buf.getvalue()


def check(raw, src):
    """The encoded reference must have the same silhouette as the source."""
    back = Image.open(io.BytesIO(raw)).convert("RGBA")
    a = lambda im: [v > 127 for v in im.getchannel("A").get_flattened_data()]
    return sum(1 for x, y in zip(a(back), a(src)) if x != y)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for slug in SLUGS:
        im = Image.open(os.path.join(SRC, "enemy_%s_full.png" % slug)).convert("RGBA")
        im = im.crop(im.getbbox())
        for colors in (32, 24, 16, 12, 10, 8, 6):
            pal, raw = encode(im, colors)
            b64 = base64.b64encode(raw).decode()
            if len(b64) <= BUDGET:
                break
        bad = check(raw, im)
        assert bad == 0, "%s: %d pixels differ from the source silhouette" % (slug, bad)
        open(os.path.join(OUT, slug + ".png"), "wb").write(raw)
        open(os.path.join(OUT, slug + ".b64"), "w").write(b64)
        print("%-18s %3dx%-3d  %2d colours  %5d b64 chars  silhouette exact" % (
            slug, im.width, im.height, colors, len(b64)))
