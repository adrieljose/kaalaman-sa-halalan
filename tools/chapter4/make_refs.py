# -*- coding: utf-8 -*-
"""Turn the Chapter 4 concept generations into v3-rotation references.

WHY THIS STEP EXISTS
    The concept pass comes back FRONT-FACING on a flat opaque backdrop however
    firmly the prompt asks for a three-quarter screen-left pose on transparent
    RGBA -- pixflux's `direction` argument simply does not reach the pose. So
    the concept pass is left to do the one thing it does well (identity,
    wardrobe and props) and each result is repaired here and then REPOSED by
    create_character(mode="v3"), which rotates a sprite you already have into
    eight real directions. The reference defines identity, so the barong, the
    folder, the cane and the sash all survive the turn -- it is a repose, not a
    redesign, and it is what satisfies "the whole body should reflect the
    facing direction" rather than a horizontal flip.

TWO THINGS HAVE TO BE TRUE OF A REFERENCE

    IT MUST HAVE A REAL SILHOUETTE. The generations are fully opaque, so the
    backdrop is flood-filled away from the border. Filling from the EDGE and
    not by colour alone is what protects a pale barong: cream cloth enclosed by
    the character's own outline is never reachable from outside it.

    IT MUST SURVIVE THE WIRE. MCP clients cut inline base64 around ~3.9k chars
    and a truncated reference is silently corrupt -- the job then faithfully
    rotates garbage and the generations are gone. The lever is the ENCODING: an
    N-colour palette PNG is one byte per pixel where RGBA is four. The
    transparent index is built by hand and saved with optimize=False, because
    PNG optimize renumbers the palette and takes the reserved hole with it,
    turning the reference into an opaque rectangle. check() asserts the encoded
    silhouette still matches the source pixel for pixel, every build.

SIZE IS A BUDGET DECISION
    v3 costs 2-9 generations, scaling with the reference size. Chapter 1 and 2
    rivals reposed for 2 each at roughly 90x175, which is also about the size
    the game actually draws a rival at, so that is the target here.
"""
import base64
import io
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "chapter4"))
import spec  # noqa: E402

SRC = os.path.join(ROOT, "output", "chapter4_villains", "sources_v2")
CUT = os.path.join(ROOT, "output", "chapter4_villains", "cutout")
OUT = os.path.join(ROOT, "output", "chapter4_villains", "refs")
BUDGET = 3600          # comfortably under the ~3.9k truncation seen before
# Height is traded for PALETTE, not the other way round. At 175 the base64
# budget only left room for 6-8 colours and the first rotation came back
# flattened to cream and brown -- a green barong or a red tie would not have
# survived at all. At 136 the same budget buys 16-48 colours on every
# character, and 136 is already close to the 130x180 node the game draws a
# rival into, so almost nothing is lost by it.
TARGET_H = 136


def cutout(path):
    """Flood the flat studio backdrop away from the border, leaving alpha."""
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(int)
    # The backdrop is one flat near-neutral tone. Sample the four corners
    # rather than assuming white: these came back pale blue, pale grey and
    # off-white depending on the character.
    h, w, _ = rgb.shape
    corners = np.array([rgb[1, 1], rgb[1, w - 2], rgb[h - 2, 1], rgb[h - 2, w - 2]])
    base = corners.mean(0)
    # Nearness to the SAMPLED corner colour is the whole test. An earlier
    # version also demanded the pixel be nearly colourless, which quietly did
    # nothing on seven characters and then failed completely on the two whose
    # backdrop came back warm cream -- the cut-out removed nothing and handed
    # on a solid rectangle. Saturation is not needed as a guard anyway: cream
    # clothing is enclosed by the character's own outline, so the flood coming
    # in from the frame can never reach it.
    distance = np.abs(rgb - base).max(2)
    candidate = distance <= 26

    seeds = np.zeros(candidate.shape, bool)
    seeds[0, :] = seeds[-1, :] = True
    seeds[:, 0] = seeds[:, -1] = True
    outside = ndimage.binary_propagation(seeds & candidate, mask=candidate)
    # One dilation step removes the antialias fringe on the backdrop side only;
    # the character's own dark outline is far from the backdrop tone and stays.
    fringe = ndimage.binary_dilation(outside, iterations=1)
    outside |= fringe & (distance <= 42)

    # Some generations paint a soft cast-shadow ellipse under the feet despite
    # being told not to. It is a genuine part of the picture, so the flood
    # above stops at its soft edge and leaves a grey smear that would then be
    # rotated, animated and drawn UNDER the game's own contact shadow. It is
    # removed with a second, looser flood confined to the bottom band.
    #
    # The threshold is not a guess. Measured across the three affected
    # characters, the bottom band is strongly bimodal: backdrop at distance
    # 0-10, then an EMPTY gap from 10 to 60, then the shadow packed into 60-90,
    # then the character from 140 up. SHADOW_TONE sits in the gap above the
    # shadow and far below shoe leather, so it takes the whole ellipse and
    # cannot reach a shoe. A first attempt at 62 landed just under the shadow
    # cluster and removed nothing at all.
    SHADOW_TONE = 95
    floor_band = np.zeros(candidate.shape, bool)
    floor_band[int(h * 0.80):, :] = True
    soft = floor_band & (distance <= SHADOW_TONE)
    shadow_seeds = np.zeros(candidate.shape, bool)
    shadow_seeds[-1, :] = True
    shadow_seeds[:, 0] = shadow_seeds[:, -1] = True
    shadow_seeds &= floor_band
    outside |= ndimage.binary_propagation(shadow_seeds & soft, mask=soft)

    # NOT DONE HERE: filling the backdrop trapped INSIDE the silhouette -- the
    # sliver between two legs, or behind a trailing foot. Selecting those by
    # tone and size was tried and is a trap: at any threshold loose enough to
    # catch them it also selects a cream barong, a white statement page and an
    # unrolled document, and the "cleanup" deleted the very props this roster
    # was regenerated to obtain. A faint pale sliver between the ankles is a
    # far smaller defect than a spokesman with no press release, so the
    # slivers stay and only frame-reachable backdrop is removed.

    alpha = (~outside).astype(np.uint8) * 255
    rgba = np.dstack((rgb.astype(np.uint8), alpha))
    rgba[alpha == 0, :3] = 0
    return Image.fromarray(rgba, "RGBA")


def encode(im, colors):
    """Quantize to `colors` entries plus one reserved transparent index."""
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
    pal.save(buf, "PNG", optimize=False, transparency=clear)
    return buf.getvalue()


def check(raw, src):
    """The encoded reference must have the same silhouette as the source."""
    back = Image.open(io.BytesIO(raw)).convert("RGBA")
    a = lambda im: [v > 127 for v in im.getchannel("A").getdata()]
    return sum(1 for x, y in zip(a(back), a(src)) if x != y)


def main():
    os.makedirs(CUT, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    rows = []
    for entry in spec.all_entries():
        slug = entry["slug"]
        src = os.path.join(SRC, slug + ".png")
        im = cutout(src)
        box = im.getbbox()
        assert box is not None, "%s: the cut-out removed the whole character" % slug
        im = im.crop(box)
        # A character that still touches the frame was clipped by the
        # generator, and rotating a clipped sprite rotates the clip with it.
        opaque = np.asarray(im.getchannel("A")) > 127
        coverage = opaque.mean()
        im.save(os.path.join(CUT, slug + ".png"))

        # Colours come off first because they cost identity least; only if the
        # palette floor is still too big does the sprite lose height. The
        # earlier version stopped at the colour floor and used whatever it had,
        # which let two references through ABOVE the truncation budget --
        # exactly the silent corruption this whole file exists to prevent.
        small, raw, colors = None, None, 0
        for height in (TARGET_H, 124, 112):
            scale = height / im.height
            small = im.resize((max(1, round(im.width * scale)), height),
                              Image.Resampling.NEAREST)
            for colors in (48, 40, 32, 24, 16, 12, 10, 8, 6):
                raw = encode(small, colors)
                b64 = base64.b64encode(raw).decode()
                if len(b64) <= BUDGET:
                    break
            if len(b64) <= BUDGET:
                break
        assert len(b64) <= BUDGET, (
            "%s: reference is %d base64 chars, over the %d truncation budget"
            % (slug, len(b64), BUDGET))
        bad = check(raw, small)
        assert bad == 0, "%s: %d pixels differ from the source silhouette" % (slug, bad)
        open(os.path.join(OUT, slug + ".png"), "wb").write(raw)
        open(os.path.join(OUT, slug + ".b64"), "w").write(b64)
        rows.append({"slug": slug, "cut": list(im.size), "ref": list(small.size),
                     "colors": colors, "b64": len(b64), "coverage": round(coverage, 3)})
        print("%-18s cut %3dx%-3d -> ref %3dx%-3d  %2d colours  %5d b64  fill %.2f"
              % (slug, im.width, im.height, small.width, small.height,
                 colors, len(b64), coverage))
    with open(os.path.join(OUT, "index.json"), "w", encoding="utf-8") as f:
        json.dump(rows, f, indent=2)


if __name__ == "__main__":
    main()
