# -*- coding: utf-8 -*-
"""Re-skins Don Eraptado: barong, black hair, black trousers, heavier build.

The PixelLab trial is spent, so this edits the generated sprite rather than
asking for a new one. Every rule is expressed as a fraction of the FRAME'S OWN
bounding box rather than an absolute y, because the attack clip uses the west
rotation and the hit clip is offset -- a rule pinned to absolute rows would
recolour the wrong band on half the frames.

Three bands do the work:

    0.00 - 0.28   head      near-white here is hair and moustache -> black
    0.28 - 0.62   torso     maroon here is the jacket -> barong cream
    0.62 - 1.00   legs      maroon here is trousers -> black

The shirt collar and cuffs are also near-white, which is why the hair rule is
banded rather than a flat palette swap: below the chin, near-white is cloth and
must stay.
"""
import glob
import os
import re

from PIL import Image

ROOT = r"D:\klhgamefinal\assets\images\characters"
PORTRAITS = r"D:\klhgamefinal\assets\images\portraits"
SLUG = "don_eraptado"
CLIPS = ("idle", "attack", "hit")

HEAD_END = 0.28      # bottom of the head, as a fraction of bbox height
HEM = 0.62           # where the barong stops and the trousers start
WIDEN = 1.16         # how much heavier he gets

# Barong tagalog: pina cloth is warm off-white, and it is sheer, so the
# shading is gentler than a suit's. Three tiers keyed off the jacket's own.
BARONG = [(236, 230, 212), (206, 197, 172), (170, 160, 136)]
TROUSERS = [(38, 36, 42), (24, 23, 28), (14, 13, 16)]
HAIR = [(38, 33, 38), (22, 19, 22)]
EMBROIDERY = (150, 139, 108)   # tonal thread: visible on cream, never a stripe


def is_maroon(p):
    r, g, b, a = p
    return a > 100 and 25 <= r <= 95 and g < 50 and r > g and r >= b - 6


def is_pale(p):
    r, g, b, a = p
    return a > 100 and min(r, g, b) > 178 and (max(r, g, b) - min(r, g, b)) < 46


def is_gold(p):
    r, g, b, a = p
    return a > 100 and r > 150 and g > 110 and b < 130 and r - b > 60


def is_dark(p):
    r, g, b, a = p
    return a > 100 and max(r, g, b) < 70


def tier(p, tiers):
    """Pick a replacement shade by how dark the source pixel was, so the
    original shading survives the swap instead of flattening to one colour."""
    lum = 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]
    if lum > 55:
        return tiers[0]
    if lum > 34:
        return tiers[1]
    return tiers[-1]


def reskin(im):
    bb = im.getbbox()
    if bb is None:
        return im
    top, height = bb[1], bb[3] - bb[1]
    cx = (bb[0] + bb[2]) // 2
    head_end = top + height * HEAD_END
    hem = top + height * HEM

    px = im.load()
    out = im.copy()
    op = out.load()
    for y in range(im.height):
        for x in range(im.width):
            p = px[x, y]
            if p[3] < 40:
                continue
            if y < head_end:
                if is_pale(p):                       # hair and moustache
                    # Keep the highlight/shadow split the white hair already
                    # had, just inverted into black: the brightest silver
                    # becomes the lighter black, not a flat fill.
                    lum = 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]
                    op[x, y] = (HAIR[0] if lum > 215 else HAIR[1]) + (p[3],)
            elif is_maroon(p):
                shades = BARONG if y < hem else TROUSERS
                op[x, y] = tier(p, shades) + (p[3],)
            elif y < hem and is_gold(p):
                # The waistcoat. A barong is a single untucked shirt, so the
                # chest has to become one continuous panel of cloth before the
                # embroidery can read as embroidery rather than as trim.
                op[x, y] = tier(p, BARONG) + (p[3],)
            elif y < hem and abs(x - cx) <= 4 and is_dark(p):
                op[x, y] = BARONG[1] + (p[3],)      # the necktie

    # Dissolve the lapels. What still reads as a suit is the hard black V of
    # the jacket opening; a barong has no opening at all. Only the CHEST
    # columns are softened -- widening this to the whole torso would also eat
    # the lines separating the arms from the body.
    chest = int((bb[2] - bb[0]) * 0.26)
    for y in range(int(head_end), int(hem)):
        for x in range(cx - chest, cx + chest + 1):
            if 0 <= x < im.width and is_dark(px[x, y]):
                op[x, y] = BARONG[2] + (px[x, y][3],)
    return out


def add_placket(im):
    """The embroidered panel down a barong's chest. Drawn from the collar to
    the hem on the two columns either side of centre, which is where the
    original sprite carried its waistcoat -- so it lands on cloth, not on a
    hand or a lapel."""
    bb = im.getbbox()
    top, height = bb[1], bb[3] - bb[1]
    cx = (bb[0] + bb[2]) // 2
    px = im.load()
    for y in range(int(top + height * 0.33), int(top + height * 0.60)):
        for dx in (-4, -3, 3, 4):
            x = cx + dx
            if not (0 <= x < im.width) or px[x, y][3] < 100:
                continue
            if px[x, y][0] < 130:            # off the cloth (hand, shadow)
                continue
            # Two vertical guide lines with a stitch every third row, which is
            # what makes it read as needlework rather than as a painted stripe.
            solid = abs(dx) == 4 or (y - top) % 3 == 0
            px[x, y] = (EMBROIDERY if solid else BARONG[1]) + (px[x, y][3],)
    return im


def widen(im):
    """Heavier build. A horizontal-only NEAREST scale duplicates columns rather
    than blending them, so the result stays hard-edged pixel art; the frame is
    then re-centred on the original figure so the feet do not drift."""
    bb = im.getbbox()
    cx = (bb[0] + bb[2]) / 2.0
    wide = im.resize((int(im.width * WIDEN), im.height), Image.NEAREST)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(wide, (int(round(cx - cx * WIDEN)), 0), wide)
    return out


if __name__ == "__main__":
    total = 0
    for clip in CLIPS:
        folder = os.path.join(ROOT, "%s_gen_%s" % (SLUG, clip))
        files = sorted(glob.glob(os.path.join(folder, "frame_*.png")),
                       key=lambda p: int(re.search(r"(\d+)\.png$", p).group(1)))
        for path in files:
            im = Image.open(path).convert("RGBA")
            im = widen(add_placket(reskin(im)))
            im.save(path)
            total += 1
        print("%-8s %d frames" % (clip, len(files)))

    idle0 = Image.open(os.path.join(ROOT, "%s_gen_idle" % SLUG, "frame_0.png"))
    bb = idle0.getbbox()
    side = max(int((bb[3] - bb[1]) * 0.55), 48)
    cx = (bb[0] + bb[2]) // 2
    idle0.crop((cx - side // 2, bb[1] - 4, cx - side // 2 + side,
                bb[1] - 4 + side)).resize((128, 128), Image.NEAREST).save(
        os.path.join(PORTRAITS, "enemy_%s.png" % SLUG))
    print("reskinned %d frames + portrait" % total)
