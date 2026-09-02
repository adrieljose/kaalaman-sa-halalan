# -*- coding: utf-8 -*-
"""Prepare each Chapter 2 rival's idle stance as an animate_image first frame.

Two things are being bought here, and both are about spending the generation
budget on pixels that matter.

CROP  animate_image is priced on total pixels (width x height x frames), and
      these sprites sit on a 180-tall canvas with a lot of empty air. Cropping
      to the opaque bounds cuts an 8-frame job from roughly 4 generations to
      between 1.5 and 3, which is the difference between covering four rivals
      and covering all nine. The crop box is written out alongside so the
      returned frames can be put back on the original canvas exactly.

FILE  The reference travels as inline base64, and MCP clients truncate long
      strings mid-value -- which does not error, it just corrupts the image and
      wastes the generation. Encoding as an N-colour PALETTE png with a
      reserved transparent index is one byte per pixel before compression
      where RGBA is four, and every pixel of the original survives.

      The transparent index is built by hand: quantizing and then pasting a
      spare index only looks right until PNG `optimize` renumbers the palette
      and the hole becomes a colour, at which point the reference is a solid
      rectangle that the model would faithfully animate. check() asserts the
      silhouette matches on every build rather than leaving it to the eye.

The FIRST frame is the idle stance, deliberately: the attack has to flow out of
the pose the rival is actually standing in, and starting anywhere else puts a
jump at the front of every swing.
"""
import base64
import glob
import io
import json
import os
from PIL import Image

SRC = "assets/images/characters"
OUT = "tools/chapter2/attack_refs"
BUDGET = 3600          # comfortably under the ~3.9k truncation seen before

SLUGS = ["fixer_fredo", "clerk_kurakot", "permit_peke", "notaryo_naku",
         "cashier_kaltas", "budget_bandido", "bidding_bandit",
         "ordinance_ogre", "don_eraptado"]


def encode(im, colors):
    """Quantize to `colors` entries plus one reserved transparent index.

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
    pal.paste(clear, (0, 0), hole)
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


def main():
    os.makedirs(OUT, exist_ok=True)
    manifest = {}
    for slug in SLUGS:
        src = sorted(glob.glob(f"{SRC}/{slug}_battle_idle/*.png"))[0]
        full = Image.open(src).convert("RGBA")
        box = full.getchannel("A").getbbox()
        im = full.crop(box)

        for colors in (32, 24, 16, 12, 10, 8, 6):
            pal, raw = encode(im, colors)
            b64 = base64.b64encode(raw).decode()
            if len(b64) <= BUDGET:
                break
        bad = check(raw, im)
        assert bad == 0, f"{slug}: {bad} pixels differ from the source silhouette"

        open(f"{OUT}/{slug}.png", "wb").write(raw)
        open(f"{OUT}/{slug}.b64", "w").write(b64)
        manifest[slug] = {
            "canvas": list(full.size), "box": list(box),
            "colors": colors, "b64_chars": len(b64),
            "cost_8f": round(im.width * im.height * 8 / 32768, 2),
        }
        print(f"{slug:16} {im.width:3}x{im.height:<3} {colors:2}c "
              f"{len(b64):5} chars  8f~{manifest[slug]['cost_8f']:.1f} gens  exact")

    json.dump(manifest, open(f"{OUT}/manifest.json", "w"), indent=2)
    print(f"\ntotal estimated for 9 x 8-frame attacks: "
          f"{sum(m['cost_8f'] for m in manifest.values()):.1f} generations")


main()
