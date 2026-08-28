# -*- coding: utf-8 -*-
"""Rebuilds the Chapter 2 placeholder backgrounds.

Split out of make_art.py because the floor line had to move: the battle scene
scales a backdrop so that BATTLE_GROUND_FRACTION of its height lands under the
fighters' feet, and anything else leaves them standing in mid-air. Every
fitting below is therefore placed as a fraction of the WALL rather than at an
absolute y, so the room stays composed when that line moves again.
"""
import os, sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from spec import BACKGROUNDS

ROOT = r"D:\klhgamefinal\assets\images\backgrounds"
BG_W, BG_H = 384, 256
GROUND_FRACTION = 0.9125          # must match the battle controller
FLOOR_Y = int(BG_H * GROUND_FRACTION)


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def wy(f):
    """A height as a fraction of the wall, measured down from the ceiling."""
    return int(FLOOR_Y * f)


def build():
    os.makedirs(ROOT, exist_ok=True)
    for b in BACKGROUNDS:
        img = Image.new("RGBA", (BG_W, BG_H), (0, 0, 0, 255))
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, BG_W, FLOOR_Y], fill=b["wall"])
        d.rectangle([0, FLOOR_Y, BG_W, BG_H], fill=b["floor"])
        for x in range(0, BG_W, 24):
            d.line([x, FLOOR_Y, x - 6, BG_H], fill=shade(b["floor"], 0.9))
        d.line([0, FLOOR_Y, BG_W, FLOOR_Y], fill=shade(b["floor"], 0.7), width=2)

        k = b["kind"]
        if k == "plaza":
            d.rectangle([0, 0, BG_W, wy(0.30)], fill=b["sky"])
            d.rectangle([80, wy(0.16), 304, FLOOR_Y], fill=shade(b["wall"], 0.92))
            d.polygon([(70, wy(0.18)), (192, wy(0.02)), (314, wy(0.18))],
                      fill=shade(b["wall"], 0.80))
            for x in range(96, 296, 30):
                d.rectangle([x, wy(0.30), x + 14, FLOOR_Y], fill=shade(b["wall"], 1.08))
            d.rectangle([176, wy(0.58), 208, FLOOR_Y], fill=shade(b["wall"], 0.6))
            for fx, cols in ((36, [(0, 56, 168), (206, 17, 38)]),
                             (330, [(240, 200, 40), (30, 120, 70)])):
                d.line([fx, wy(0.10), fx, FLOOR_Y], fill=(90, 90, 90), width=2)
                d.rectangle([fx, wy(0.12), fx + 26, wy(0.28)], fill=cols[0])
                d.rectangle([fx, wy(0.28), fx + 26, wy(0.36)], fill=cols[1])
        elif k == "lobby":
            d.rectangle([132, wy(0.08), 252, wy(0.26)], fill=(28, 34, 40))
            d.rectangle([142, wy(0.12), 242, wy(0.22)], fill=(90, 220, 140))
            for x in range(16, BG_W - 20, 92):
                d.rectangle([x, wy(0.40), x + 76, wy(0.62)], fill=shade(b["wall"], 0.86))
            for x in range(20, BG_W - 20, 92):
                d.rectangle([x, FLOOR_Y - 46, x + 74, FLOOR_Y], fill=shade(b["wall"], 0.72))
                d.rectangle([x, FLOOR_Y - 54, x + 74, FLOOR_Y - 46], fill=shade(b["wall"], 0.94))
            for x in range(28, BG_W - 30, 36):
                d.rectangle([x, FLOOR_Y - 16, x + 24, FLOOR_Y], fill=(80, 110, 150))
        elif k == "permits":
            d.rectangle([20, wy(0.08), 172, wy(0.20)], fill=(238, 236, 226))
            d.rectangle([204, wy(0.08), 356, wy(0.20)], fill=(238, 236, 226))
            d.rectangle([26, wy(0.30), BG_W - 26, wy(0.56)], fill=shade(b["wall"], 1.07))
            d.rectangle([BG_W - 100, FLOOR_Y - 84, BG_W - 32, FLOOR_Y], fill=(70, 76, 82))
            d.rectangle([BG_W - 92, FLOOR_Y - 76, BG_W - 40, FLOOR_Y - 52], fill=(150, 160, 168))
            d.rectangle([24, FLOOR_Y - 40, 200, FLOOR_Y], fill=shade(b["wall"], 0.74))
        elif k == "archive":
            for x in range(8, BG_W - 44, 52):
                d.rectangle([x, wy(0.14), x + 44, FLOOR_Y], fill=shade(b["wall"], 0.8))
                for dy in range(wy(0.20), FLOOR_Y - 14, 30):
                    d.rectangle([x + 4, dy, x + 40, dy + 24], fill=shade(b["wall"], 0.62))
                    d.rectangle([x + 17, dy + 10, x + 27, dy + 14], fill=shade(b["wall"], 1.1))
            for i, sx in enumerate((72, 214, 302)):
                d.rectangle([sx, FLOOR_Y - 18 - i * 4, sx + 32, FLOOR_Y], fill=(226, 220, 200))
        elif k == "treasury":
            d.rectangle([10, wy(0.16), BG_W - 106, FLOOR_Y], fill=shade(b["wall"], 0.7))
            for x in range(22, BG_W - 124, 64):
                d.rectangle([x, wy(0.24), x + 48, FLOOR_Y - 40], fill=(178, 206, 214))
                d.line([x, FLOOR_Y - 52, x + 48, FLOOR_Y - 52], fill=(90, 96, 104), width=3)
            d.ellipse([BG_W - 96, wy(0.28), BG_W - 12, FLOOR_Y], fill=shade(b["wall"], 0.5))
            d.ellipse([BG_W - 70, wy(0.48), BG_W - 38, wy(0.66)], fill=(200, 190, 150))
        elif k == "budget":
            for i, x in enumerate(range(22, BG_W - 64, 78)):
                d.rectangle([x, wy(0.10), x + 62, wy(0.44)], fill=(242, 240, 232))
                for bx in range(6):
                    h = 6 + ((bx * 13 + i * 7) % 40)
                    d.rectangle([x + 6 + bx * 9, wy(0.42) - h, x + 12 + bx * 9, wy(0.42)],
                                fill=(70 + bx * 22, 110, 170))
            d.rectangle([16, FLOOR_Y - 48, BG_W - 16, FLOOR_Y], fill=shade(b["wall"], 0.72))
            for x in range(26, BG_W - 44, 46):
                d.rectangle([x, FLOOR_Y - 64, x + 32, FLOOR_Y - 48], fill=(200, 176, 120))
        elif k == "bidding":
            d.rectangle([40, wy(0.08), BG_W - 40, wy(0.42)], fill=(24, 30, 38))
            d.rectangle([50, wy(0.12), BG_W - 50, wy(0.38)], fill=(46, 120, 96))
            d.rounded_rectangle([34, FLOOR_Y - 52, BG_W - 34, FLOOR_Y + 8], radius=6,
                                fill=shade(b["wall"], 0.66))
            for x in range(60, BG_W - 68, 56):
                d.rectangle([x, FLOOR_Y - 72, x + 36, FLOOR_Y - 52], fill=(196, 178, 140))
                d.line([x + 18, FLOOR_Y - 72, x + 18, FLOOR_Y - 88], fill=(60, 60, 66), width=2)
        elif k == "session":
            d.ellipse([148, wy(0.06), 236, wy(0.44)], fill=(198, 160, 90))
            d.ellipse([160, wy(0.12), 224, wy(0.38)], fill=shade(b["wall"], 0.8))
            for row, y in enumerate(range(FLOOR_Y - 74, FLOOR_Y + 4, 28)):
                inset = 16 + row * 18
                d.rounded_rectangle([inset, y, BG_W - inset, y + 20], radius=3,
                                    fill=shade(b["wall"], 0.6 + row * 0.09))
                for x in range(inset + 16, BG_W - inset - 12, 44):
                    d.line([x, y, x, y - 10], fill=(50, 46, 44), width=2)
            for fx, c in ((20, (0, 56, 168)), (BG_W - 46, (240, 200, 40))):
                d.rectangle([fx, wy(0.10), fx + 26, wy(0.34)], fill=c)
        elif k == "mayor":
            d.rectangle([14, wy(0.10), 122, wy(0.52)], fill=(120, 150, 180))
            d.rectangle([BG_W - 122, wy(0.10), BG_W - 14, wy(0.52)], fill=(120, 150, 180))
            for wx in range(20, 118, 16):
                d.rectangle([wx, wy(0.30), wx + 9, wy(0.52)], fill=(150, 176, 200))
            d.ellipse([156, wy(0.06), 228, wy(0.38)], fill=(150, 122, 62))
            d.ellipse([168, wy(0.12), 216, wy(0.32)], fill=shade(b["wall"], 0.7))
            d.rounded_rectangle([92, FLOOR_Y - 56, BG_W - 92, FLOOR_Y + 8], radius=5,
                                fill=(78, 56, 44))
            d.rectangle([BG_W - 96, FLOOR_Y - 88, BG_W - 28, FLOOR_Y], fill=(96, 92, 88))
            d.ellipse([BG_W - 78, FLOOR_Y - 66, BG_W - 46, FLOOR_Y - 34], fill=(206, 178, 96))
            for i, sx in enumerate((28, 60)):
                d.ellipse([sx, FLOOR_Y - 28 - i * 4, sx + 28, FLOOR_Y], fill=(198, 176, 110))

        for y in range(0, BG_H, 16):
            d.line([0, y, BG_W, y], fill=(255, 255, 255, 16))
        img.convert("RGB").save(os.path.join(ROOT, "%s.png" % b["key"]))
    return len(BACKGROUNDS)


def build_phase2():
    """The Mayor's Office after the transformation: curtains drawn, red-orange
    light, the vault fully open and the shelves shedding paperwork. Derived
    from the phase 1 file so it reads as the same room, changed."""
    src = Image.open(os.path.join(ROOT, "cityhall_mayor_office.png")).convert("RGB")
    img = src.copy()
    d = ImageDraw.Draw(img, "RGBA")
    for x0 in (14, BG_W - 122):
        d.rectangle([x0, wy(0.10), x0 + 108, wy(0.52)], fill=(96, 34, 30))
        for cx in range(x0, x0 + 108, 10):
            d.line([cx, wy(0.10), cx, wy(0.52)], fill=(72, 24, 22))
    d.rectangle([BG_W - 96, FLOOR_Y - 88, BG_W - 28, FLOOR_Y], fill=(40, 34, 30))
    d.rectangle([BG_W - 90, FLOOR_Y - 82, BG_W - 34, FLOOR_Y - 6], fill=(150, 118, 44))
    for gy in range(FLOOR_Y - 76, FLOOR_Y - 8, 13):
        d.rectangle([BG_W - 86, gy, BG_W - 38, gy + 9], fill=(214, 178, 74))
    for px, py in [(150, wy(0.20)), (196, wy(0.10)), (236, wy(0.30)),
                   (118, wy(0.40)), (262, wy(0.16)), (176, wy(0.50))]:
        d.rectangle([px, py, px + 16, py + 12], fill=(232, 226, 206))
        d.line([px, py + 4, px + 16, py + 4], fill=(180, 174, 158))
    d.rectangle([0, 0, BG_W, BG_H], fill=(180, 60, 20, 62))
    d.rectangle([BG_W - 130, 0, BG_W, BG_H], fill=(255, 170, 60, 28))
    img.save(os.path.join(ROOT, "cityhall_mayor_office_phase2.png"))


if __name__ == "__main__":
    print("backgrounds:", build())
    build_phase2()
    print("phase 2 arena: rebuilt")
