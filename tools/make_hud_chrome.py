# -*- coding: utf-8 -*-
"""Builds the battle HUD's chrome: the header bar, its brass pillars, the
ribbon nameplates, the recessed heart trays and the portrait frames.

Same reasoning as make_ui_panels.py -- drawn procedurally rather than
generated, because a 9-sliced texture's centre has to tile seamlessly at any
size and a one-off generated image would not. Palette is deliberately the same
one, so the HUD reads as part of the same carved-wood-and-gold set as the
potion, question and side panels rather than as separate art.

The header bar needs a MUCH thinner frame than panel_ornate.png: the HUD only
gets 53px of height before the question panel starts, and a 10px frame top and
bottom would eat 20 of them. Hence a separate 4px-margin bar rather than
reusing the existing panel.
"""
import numpy as np
from PIL import Image, ImageDraw
import os

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "images", "ui")

# --- palette (identical to make_ui_panels.py) ------------------------------
OUTLINE      = (13, 9, 6)
GOLD_LIGHT   = (217, 191, 128)
GOLD_MID     = (184, 143, 56)
GOLD_DARK    = (122, 92, 34)
INNER_SHADOW = (36, 24, 13)
WOOD_BASE    = (44, 30, 18)
WOOD_HI      = (78, 55, 32)
WOOD_LO      = (18, 11, 6)
# Ribbon nameplates: the deep red of the existing "Back" buttons, darkened so
# cream text sits on it comfortably.
RIBBON_BASE  = (104, 34, 30)
RIBBON_HI    = (140, 52, 44)
RIBBON_LO    = (62, 18, 16)
# Recessed tray behind the hearts -- darker than the wood so the hearts read.
SLOT_BASE    = (26, 17, 11)
SLOT_LO      = (14, 9, 6)


def seamless_wood(w, h):
    """Dark vertical wood grain that tiles exactly in both axes."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    u = 2.0 * np.pi * x / w
    v = 2.0 * np.pi * y / h
    g = 0.55 * np.sin(7.0 * u + 0.7 * np.sin(2.0 * v))
    g += 0.28 * np.sin(13.0 * u + 1.1 * np.sin(3.0 * v))
    g += 0.14 * np.sin(23.0 * u + 0.5 * np.sin(5.0 * v))
    g += 0.10 * np.sin(3.0 * v + 0.4 * np.sin(2.0 * u))
    g = (g - g.min()) / (g.max() - g.min())
    g = np.clip((g - 0.5) * 1.05 + 0.5, 0.0, 1.0)
    lo, base, hi = (np.array(c, dtype=np.float64) for c in (WOOD_LO, WOOD_BASE, WOOD_HI))
    img = np.where(g[..., None] < 0.5,
                   lo + (base - lo) * (g[..., None] / 0.5),
                   base + (hi - base) * ((g[..., None] - 0.5) / 0.5))
    return img.astype(np.uint8)


def flat_grain(w, h, base, lo, hi, freq=9.0):
    """A quieter version of the same idea, for ribbons and trays."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    u, v = 2.0 * np.pi * x / w, 2.0 * np.pi * y / h
    g = 0.6 * np.sin(freq * u + 0.5 * np.sin(2.0 * v)) + 0.4 * np.sin(3.0 * v)
    g = (g - g.min()) / (g.max() - g.min())
    g = np.clip((g - 0.5) * 0.55 + 0.5, 0.0, 1.0)
    lo_a, base_a, hi_a = (np.array(c, dtype=np.float64) for c in (lo, base, hi))
    img = np.where(g[..., None] < 0.5,
                   lo_a + (base_a - lo_a) * (g[..., None] / 0.5),
                   base_a + (hi_a - base_a) * ((g[..., None] - 0.5) / 0.5))
    return img.astype(np.uint8)


def bevel_frame(d, size, margin, light, mid, dark, outline=OUTLINE):
    """Draws an outlined frame with a lit top-left and shaded bottom-right."""
    s = size - 1
    d.rectangle([0, 0, s, s], outline=outline, width=1)
    for i in range(1, margin - 1):
        # Top and left catch the light; bottom and right fall away.
        d.line([(i, i), (s - i, i)], fill=light if i == 1 else mid)
        d.line([(i, i), (i, s - i)], fill=light if i == 1 else mid)
        d.line([(i, s - i), (s - i, s - i)], fill=dark if i == 1 else mid)
        d.line([(s - i, i), (s - i, s - i)], fill=dark if i == 1 else mid)
    d.rectangle([margin - 1, margin - 1, s - margin + 1, s - margin + 1],
                outline=INNER_SHADOW, width=1)


def make_bar(path, size=48, margin=4):
    """The header bar itself: thin gold-trimmed frame over tiling wood."""
    img = Image.fromarray(seamless_wood(size, size), "RGB").convert("RGBA")
    d = ImageDraw.Draw(img)
    bevel_frame(d, size, margin, GOLD_LIGHT, GOLD_MID, GOLD_DARK)
    img.save(os.path.join(OUT, path))
    return img.size


def make_ribbon(path, size=20, margin=5):
    # Margin has to stay under half the shortest size this ever gets drawn at:
    # the nameplates are only ~15px tall, so an 8px margin left no centre.
    """Nameplate: red cloth with a gold edge, for YOU / CHAPTER 1 / enemy."""
    img = Image.fromarray(
        flat_grain(size, size, RIBBON_BASE, RIBBON_LO, RIBBON_HI), "RGB").convert("RGBA")
    d = ImageDraw.Draw(img)
    s = size - 1
    d.rectangle([0, 0, s, s], outline=OUTLINE, width=1)
    d.rectangle([1, 1, s - 1, s - 1], outline=GOLD_MID, width=1)
    d.rectangle([2, 2, s - 2, s - 2], outline=(84, 26, 22), width=1)
    # A lit top edge so the plate reads as raised rather than painted on.
    d.line([(3, 3), (s - 3, 3)], fill=RIBBON_HI)
    img.save(os.path.join(OUT, path))
    return img.size


def make_slot(path, size=24, margin=6):
    """Recessed tray the hearts sit in -- the inverse bevel of the bar."""
    img = Image.fromarray(
        flat_grain(size, size, SLOT_BASE, SLOT_LO, (40, 27, 17), freq=5.0),
        "RGB").convert("RGBA")
    d = ImageDraw.Draw(img)
    s = size - 1
    d.rectangle([0, 0, s, s], outline=OUTLINE, width=1)
    # Inverted: dark on top-left, light on bottom-right, so it reads as sunken.
    d.line([(1, 1), (s - 1, 1)], fill=(10, 7, 4))
    d.line([(1, 1), (1, s - 1)], fill=(10, 7, 4))
    d.line([(1, s - 1), (s - 1, s - 1)], fill=GOLD_DARK)
    d.line([(s - 1, 1), (s - 1, s - 1)], fill=GOLD_DARK)
    img.save(os.path.join(OUT, path))
    return img.size


def make_portrait_frame(path, size=24, margin=6):
    """Gold frame around a cropped character head."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = size - 1
    d.rectangle([0, 0, s, s], fill=(20, 13, 8, 255), outline=OUTLINE, width=1)
    d.rectangle([1, 1, s - 1, s - 1], outline=GOLD_MID, width=1)
    d.rectangle([2, 2, s - 2, s - 2], outline=GOLD_LIGHT, width=1)
    d.rectangle([3, 3, s - 3, s - 3], outline=GOLD_DARK, width=1)
    # Hollow centre so the portrait shows through the 9-slice.
    d.rectangle([margin - 1, margin - 1, s - margin + 1, s - margin + 1], fill=(0, 0, 0, 0))
    img.save(os.path.join(OUT, path))
    return img.size


def make_pillar(path, w=12, h=44):
    """The brass column that separates the three HUD sections."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cap = 6
    # Shaft: a lit core with darker flanks, so it reads as round.
    for x in range(w):
        t = abs((x + 0.5) / w - 0.5) * 2.0          # 0 centre .. 1 edge
        c = tuple(int(GOLD_LIGHT[i] * (1.0 - t) + GOLD_DARK[i] * t) for i in range(3))
        d.line([(x, cap), (x, h - cap - 1)], fill=c + (255,))
    # Capital and base blocks, slightly wider than the shaft.
    for y0, y1 in ((0, cap - 1), (h - cap, h - 1)):
        d.rectangle([0, y0, w - 1, y1], fill=GOLD_MID + (255,), outline=OUTLINE + (255,))
        d.line([(1, y0 + 1), (w - 2, y0 + 1)], fill=GOLD_LIGHT + (255,))
    d.line([(0, cap), (0, h - cap - 1)], fill=OUTLINE + (255,))
    d.line([(w - 1, cap), (w - 1, h - cap - 1)], fill=OUTLINE + (255,))
    img.save(os.path.join(OUT, path))
    return img.size


# Parchment for the chapter-name plate. The chapter name is the one piece of
# HUD text that is a heading rather than a stat, so it gets a light ground and
# dark ink -- the inverse of everything around it, which is what makes it read
# as a title instead of another readout.
PARCH_BASE = (196, 174, 128)
PARCH_HI   = (222, 204, 163)
PARCH_LO   = (162, 140, 98)


def make_parchment(path, size=24, margin=6):
    img = Image.fromarray(
        flat_grain(size, size, PARCH_BASE, PARCH_LO, PARCH_HI, freq=4.0),
        "RGB").convert("RGBA")
    d = ImageDraw.Draw(img)
    s = size - 1
    d.rectangle([0, 0, s, s], outline=OUTLINE, width=1)
    d.rectangle([1, 1, s - 1, s - 1], outline=GOLD_DARK, width=1)
    # Sunken: shaded along the top-left, lit along the bottom-right.
    d.line([(2, 2), (s - 2, 2)], fill=PARCH_LO)
    d.line([(2, 2), (2, s - 2)], fill=PARCH_LO)
    d.line([(2, s - 2), (s - 2, s - 2)], fill=PARCH_HI)
    d.line([(s - 2, 2), (s - 2, s - 2)], fill=PARCH_HI)
    img.save(os.path.join(OUT, path))
    return img.size



if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print("hud_bar.png           ", make_bar("hud_bar.png"))
    print("hud_ribbon.png        ", make_ribbon("hud_ribbon.png"))
    print("hud_slot.png          ", make_slot("hud_slot.png"))
    print("hud_portrait_frame.png", make_portrait_frame("hud_portrait_frame.png"))
    print("hud_pillar.png        ", make_pillar("hud_pillar.png"))
    print("hud_parchment.png     ", make_parchment("hud_parchment.png"))
    print("wrote to", OUT)
