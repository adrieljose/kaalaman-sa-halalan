# -*- coding: utf-8 -*-
"""Builds animate_image references from the installed 3/4 idle frames.

The rivals already stand three-quarters on to the player; frame 0 of each
`_battle_idle_34` clip IS that pose, so it is the correct starting frame for
any further animation. Generating from it rather than from a fresh rotation
keeps the new clips in the same facing, at the same scale, on the same floor
line -- and costs nothing, where re-creating the PixelLab characters on this
account would have cost a generation each before any animation at all.

Encoding is the same palette trick used for the earlier references: an N-colour
PNG with a hand-built transparent index, shrunk until the inline base64 is short
enough that the client cannot truncate it mid-string. `check()` asserts the
silhouette survives, because a corrupted reference does not error -- it just
animates the wrong picture and spends the generation doing it.
"""
import base64
import io
import json
import os
from PIL import Image

SRC = "assets/images/characters"
OUT = "tools/chapter2/refs34"
BUDGET = 2400          # tighter than before: two references were mangled at ~3k

SLUGS = ["fixer_fredo", "clerk_kurakot", "permit_peke", "notaryo_naku",
         "cashier_kaltas", "budget_bandido", "bidding_bandit",
         "ordinance_ogre", "don_eraptado"]


def encode(im, colors):
    hole = im.getchannel("A").point(lambda v: 0 if v > 127 else 255)
    pal = im.convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT,
                                     dither=Image.Dither.NONE)
    table = (pal.getpalette() or [])[:colors * 3]
    table += [0] * (colors * 3 - len(table))
    clear = colors
    table += [255, 0, 255]
    pal.paste(clear, (0, 0), hole)
    pal.putpalette(table)
    buf = io.BytesIO()
    pal.save(buf, "PNG", optimize=False, transparency=clear)
    return buf.getvalue()


def check(raw, src):
    back = Image.open(io.BytesIO(raw)).convert("RGBA")
    a = lambda im: [v > 127 for v in im.getchannel("A").get_flattened_data()]
    return sum(1 for x, y in zip(a(back), a(src)) if x != y)


def main():
    os.makedirs(OUT, exist_ok=True)
    manifest = {}
    for slug in SLUGS:
        full = Image.open(f"{SRC}/{slug}_battle_idle_34/frame_0.png").convert("RGBA")
        box = full.getchannel("A").getbbox()
        im = full.crop(box)
        for colors in (32, 24, 16, 12, 10, 8, 6):
            raw = encode(im, colors)
            b64 = base64.b64encode(raw).decode()
            if len(b64) <= BUDGET:
                break
        bad = check(raw, im)
        assert bad == 0, f"{slug}: {bad} pixels differ from the source silhouette"
        open(f"{OUT}/{slug}.b64", "w").write(b64)
        manifest[slug] = {"canvas": list(full.size), "box": list(box),
                          "colors": colors, "chars": len(b64),
                          "cost_8f": round(im.width * im.height * 8 / 32768, 2)}
        print(f"{slug:16} {im.width:3}x{im.height:<3} {colors:2}c "
              f"{len(b64):5} chars  8f~{manifest[slug]['cost_8f']:.1f} gens  exact")
    json.dump(manifest, open(f"{OUT}/manifest.json", "w"), indent=2)


main()
