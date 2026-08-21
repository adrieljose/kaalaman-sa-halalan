# -*- coding: utf-8 -*-
"""Builds the ornate 9-slice panel and progress-bar textures.

Drawn procedurally rather than generated, for two reasons: the PixelLab
create_ui_asset endpoint costs 20-40 generations per call and the trial account
has 3 left, and a 9-sliced panel's centre has to TILE seamlessly at any panel
size - which a one-off generated image would not do. The grain here is built
from integer-frequency sine terms, so it wraps exactly in both axes.

Palette is lifted from the styleboxes already in word_battle.tscn.
"""
import numpy as np
from PIL import Image, ImageDraw
import os, sys

OUT = r"D:\klhgamefinal\assets\images\ui"

# --- palette (matches existing StyleBoxFlat values) -------------------------
OUTLINE      = (13, 9, 6)        # near-black rim
GOLD_LIGHT   = (217, 191, 128)   # 0.85,0.75,0.50 - existing light trim
GOLD_MID     = (184, 143, 56)    # 0.72,0.56,0.22 - existing border colour
GOLD_DARK    = (122, 92, 34)     # shaded side of the bevel
INNER_SHADOW = (36, 24, 13)
WOOD_BASE    = (44, 30, 18)      # a shade above the old flat 0.09,0.06,0.04 fill
WOOD_HI      = (78, 55, 32)      # lit grain - has to be visibly lighter than base
WOOD_LO      = (18, 11, 6)       # deep grain lines

PANEL = 96
# The 9-slice margin is exactly the frame's thickness. It has to be: the four
# edge strips are tiled along their length, so every row of them must be
# uniform in that direction. Push the margin any deeper and it starts including
# wood grain, which then tiles at a different rate than the centre and shows a
# seam where the two meet. Ornaments therefore sit ON the frame, not inset into
# the wood behind it.
MARGIN = 10


def seamless_wood(w, h):
    """Dark vertical wood grain that tiles exactly in both axes."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    u = 2.0 * np.pi * x / w
    v = 2.0 * np.pi * y / h
    # Vertical streaks that wobble slightly down their length.
    g = 0.55 * np.sin(7.0 * u + 0.7 * np.sin(2.0 * v))
    g += 0.28 * np.sin(13.0 * u + 1.1 * np.sin(3.0 * v))
    g += 0.14 * np.sin(23.0 * u + 0.5 * np.sin(5.0 * v))
    # Faint cross-grain so it does not read as pure stripes.
    g += 0.10 * np.sin(3.0 * v + 0.4 * np.sin(2.0 * u))
    g = (g - g.min()) / (g.max() - g.min())          # -> 0..1
    # Enough contrast to actually read as wood at 1:1 on a 640x480 screen. An
    # earlier pass was so subtle it was indistinguishable from the flat fill it
    # replaced - "subtle" still has to be visible.
    g = np.clip((g - 0.5) * 1.05 + 0.5, 0.0, 1.0)

    lo = np.array(WOOD_LO, dtype=np.float64)
    base = np.array(WOOD_BASE, dtype=np.float64)
    hi = np.array(WOOD_HI, dtype=np.float64)
    img = np.where(g[..., None] < 0.5,
                   lo + (base - lo) * (g[..., None] / 0.5),
                   base + (hi - base) * ((g[..., None] - 0.5) / 0.5))
    # Quantise so it stays pixel-art rather than a smooth gradient.
    img = np.round(img / 6.0) * 6.0
    return np.clip(img, 0, 255).astype(np.uint8)


def corner_rivet(d, cx, cy):
    """A gold rivet set into the frame at a corner.

    Must stay inside the MARGIN box — anything crossing it lands in a tiled
    edge strip and prints a repeating row of dashes down every side. The
    build asserts this afterwards rather than trusting the arithmetic.
    """
    d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=GOLD_DARK, outline=OUTLINE)
    d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=GOLD_MID)
    d.point((cx - 1, cy - 1), fill=GOLD_LIGHT)


def build_panel():
    wood = Image.fromarray(seamless_wood(PANEL, PANEL), "RGB").convert("RGBA")
    img = wood.copy()
    d = ImageDraw.Draw(img)

    # Frame, drawn outside-in, exactly MARGIN rings deep. Top/left catch the
    # light and bottom/right fall away, which is what gives it real relief
    # rather than a flat outline.
    rings = [
        (OUTLINE, OUTLINE),           # 0  hard rim
        (GOLD_LIGHT, GOLD_MID),       # 1  lit bevel
        (GOLD_MID, GOLD_DARK),        # 2  body
        (GOLD_MID, GOLD_DARK),        # 3  body
        (GOLD_DARK, OUTLINE),         # 4  shaded bevel
        (INNER_SHADOW, INNER_SHADOW), # 5  recess
        ((30, 20, 12), (30, 20, 12)), # 6  recess falloff
        ((34, 23, 14), (34, 23, 14)), # 7  recess falloff
        ((38, 26, 15), (38, 26, 15)), # 8  recess falloff
        ((42, 29, 17), (42, 29, 17)), # 9  meets the wood
    ]
    assert len(rings) == MARGIN, "frame depth must equal the 9-slice margin"
    for i, (lit, shade) in enumerate(rings):
        a, b = i, PANEL - 1 - i
        d.line([(a, a), (b, a)], fill=lit)      # top
        d.line([(a, a), (a, b)], fill=lit)      # left
        d.line([(a, b), (b, b)], fill=shade)    # bottom
        d.line([(b, a), (b, b)], fill=shade)    # right

    inset = 5
    for cx in (inset, PANEL - 1 - inset):
        for cy in (inset, PANEL - 1 - inset):
            corner_rivet(d, cx, cy)

    # Guard the rule the ornaments have to obey: the four edge strips are what
    # get tiled along each side, so nothing decorative may appear in them.
    a = np.asarray(img.convert("RGB")).astype(int)
    gold = np.array(GOLD_LIGHT)
    strips = {
        "top": a[0:MARGIN, MARGIN:PANEL - MARGIN],
        "bottom": a[PANEL - MARGIN:PANEL, MARGIN:PANEL - MARGIN],
        "left": a[MARGIN:PANEL - MARGIN, 0:MARGIN],
        "right": a[MARGIN:PANEL - MARGIN, PANEL - MARGIN:PANEL],
    }
    for name, s in strips.items():
        # Each row (or column) of an edge strip should be uniform along the
        # tiling direction; an ornament pixel breaks that.
        axis = 1 if name in ("top", "bottom") else 0
        var = s.std(axis=axis).max()
        if var > 1.0:
            print("  WARNING: %s edge strip is not uniform (std %.1f) - "
                  "an ornament is bleeding into the tiled region" % (name, var))

    img.save(os.path.join(OUT, "panel_ornate.png"))
    return img.size


def build_bar():
    """Sunken track + beveled, ticked fill.

    The fill is kept greyscale so the controller can tint it green/amber/red
    through the stylebox's modulate_color without fighting the bevel.
    """
    w, h = 64, 14

    # --- track: inset, so the fill sits down inside it ---
    bg = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(bg)
    d.rectangle([0, 0, w - 1, h - 1], fill=(26, 17, 10, 255), outline=OUTLINE)
    d.line([(1, 1), (w - 2, 1)], fill=(12, 8, 5))          # top inner shadow
    d.line([(1, 1), (1, h - 2)], fill=(12, 8, 5))
    d.line([(1, h - 2), (w - 2, h - 2)], fill=(62, 47, 26))  # bottom lip catches light
    bg.save(os.path.join(OUT, "bar_track.png"))

    # --- fill: rounded bevel top to bottom, with tick segments ---
    fill = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(fill)
    for y in range(1, h - 1):
        t = (y - 1) / float(h - 3)
        # bright near the top, dropping off toward the bottom
        v = int(255 - 90 * t)
        if y == 1:
            v = 255
        elif y == h - 2:
            v = 120
        d.line([(1, y), (w - 2, y)], fill=(v, v, v, 255))
    for x in range(0, w, 6):  # tick segments
        d.line([(x, 1), (x, h - 2)], fill=(170, 170, 170, 255))
    d.rectangle([0, 0, w - 1, h - 1], outline=(90, 90, 90, 255))
    fill.save(os.path.join(OUT, "bar_fill.png"))
    return (w, h)


def main():
    if not os.path.isdir(OUT):
        print("missing:", OUT)
        return 1
    p = build_panel()
    b = build_bar()
    print("panel_ornate.png %s  (9-slice margin %d)" % (p, MARGIN))
    print("bar_track.png / bar_fill.png %s" % (b,))
    # Sanity: the tiling centre must wrap without a seam.
    a = np.asarray(Image.open(os.path.join(OUT, "panel_ornate.png")).convert("RGB"))
    c = a[MARGIN:PANEL - MARGIN, MARGIN:PANEL - MARGIN]
    seam_x = np.abs(c[:, 0].astype(int) - c[:, -1].astype(int)).mean()
    seam_y = np.abs(c[0, :].astype(int) - c[-1, :].astype(int)).mean()
    print("centre wrap delta: x=%.1f y=%.1f (lower is a cleaner tile)" % (seam_x, seam_y))
    return 0


if __name__ == "__main__":
    sys.exit(main())
