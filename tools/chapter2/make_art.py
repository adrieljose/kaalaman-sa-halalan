# -*- coding: utf-8 -*-
"""Generates PLACEHOLDER art for Chapter 2 at the exact dimensions Chapter 1
uses, so final artwork drops in by overwriting files of the same name.

Nothing here is meant to ship as final art. The point is that every path a
.tres references resolves to a real file: Godot's load() prints an error for a
missing resource, so dangling paths would spam the console on every attack.

Sizes taken from the existing assets:
    character frames  128x180      move icons    28x28
    backgrounds       384x256      portraits     128x128
"""
import os, sys, math
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from spec import ROSTER, BACKGROUNDS

ROOT = r"D:\klhgamefinal\assets\images"
CHAR_W, CHAR_H = 128, 180
BG_W, BG_H = 384, 256
ICON = 28
PORT = 128

WATERMARK = (255, 255, 255, 40)


def out(*parts):
    p = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


# --------------------------------------------------------------- characters
def draw_figure(d, body, accent, build, hat, pose):
    """One placeholder figure. `pose` carries the per-frame variation so the
    clips actually animate rather than showing a static image N times."""
    lean, arm, bob, prop, prop_col = (pose.get(k) for k in
                                      ("lean", "arm", "bob", "prop", "prop_col"))
    lean = lean or 0.0; arm = arm or 0.0; bob = bob or 0.0

    widths = {"slim": 30, "normal": 36, "wide": 44, "huge": 54, "boss": 42}
    w = widths.get(build, 36)
    cx = CHAR_W // 2 + int(lean * 14)
    top = 44 + int(bob * 3) + (0 if build != "huge" else -10)
    bottom = CHAR_H - 8

    # legs
    d.rectangle([cx - w // 3, bottom - 46, cx - 4, bottom], fill=shade(body, 0.72))
    d.rectangle([cx + 4, bottom - 46, cx + w // 3, bottom], fill=shade(body, 0.72))
    # torso
    d.rounded_rectangle([cx - w // 2, top + 26, cx + w // 2, bottom - 42],
                        radius=6, fill=body)
    # accent sash — the per-enemy colour cue
    d.rectangle([cx - w // 2, top + 40, cx + w // 2, top + 50], fill=accent)
    # head
    hr = 13 if build != "huge" else 16
    d.ellipse([cx - hr, top, cx + hr, top + hr * 2], fill=shade(body, 1.35))
    # hat / mask silhouettes keep the roster distinguishable at a glance
    if hat == "cap":
        d.rectangle([cx - hr - 2, top + 2, cx + hr + 2, top + 8], fill=shade(accent, 0.8))
    elif hat == "visor":
        d.rectangle([cx - hr - 3, top + 9, cx + hr + 3, top + 13], fill=shade(accent, 0.9))
    elif hat == "mask":
        d.rectangle([cx - hr, top + 8, cx + hr, top + 15], fill=shade(body, 0.4))
    if build == "boss":
        d.polygon([(cx - w // 2 - 6, top + 30), (cx + w // 2 + 6, top + 30),
                   (cx + w // 2, top + 46), (cx - w // 2, top + 46)], fill=accent)

    # arm — swings with the pose so attack clips read as motion
    ax = cx + int(w * 0.55)
    ay = top + 34
    ex = ax + int(26 * math.cos(math.radians(arm)))
    ey = ay + int(26 * math.sin(math.radians(arm)))
    d.line([ax, ay, ex, ey], fill=shade(body, 1.15), width=8)

    # prop in hand, tinted per skill so sibling clips differ
    if prop:
        pc = prop_col or accent
        if prop == "stamp":
            d.rectangle([ex - 11, ey - 11, ex + 11, ey + 5], fill=pc)
            d.rectangle([ex - 4, ey + 5, ex + 4, ey + 13], fill=shade(pc, 0.7))
        elif prop == "paper":
            for k in range(3):
                d.rectangle([ex - 9 + k * 3, ey - 12 + k * 3, ex + 7 + k * 3, ey + 6 + k * 3],
                            fill=pc, outline=shade(pc, 0.6))
        elif prop == "coin":
            d.ellipse([ex - 9, ey - 9, ex + 9, ey + 9], fill=pc, outline=shade(pc, 0.6))
        elif prop == "book":
            d.rectangle([ex - 16, ey - 14, ex + 16, ey + 12], fill=pc, outline=shade(pc, 0.6))
            d.line([ex, ey - 14, ex, ey + 12], fill=shade(pc, 0.6), width=2)
        elif prop == "case":
            d.rectangle([ex - 15, ey - 10, ex + 15, ey + 10], fill=pc, outline=shade(pc, 0.6))
            d.rectangle([ex - 4, ey - 14, ex + 4, ey - 10], fill=shade(pc, 0.7))
        elif prop == "cane":
            d.line([ex, ey - 18, ex, ey + 22], fill=pc, width=5)
            d.ellipse([ex - 6, ey - 24, ex + 6, ey - 12], fill=shade(pc, 1.2))
        elif prop == "sack":
            d.ellipse([ex - 15, ey - 12, ex + 15, ey + 16], fill=pc)
            d.rectangle([ex - 5, ey - 18, ex + 5, ey - 10], fill=shade(pc, 0.7))


def char_frame(enemy, pose):
    img = Image.new("RGBA", (CHAR_W, CHAR_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_figure(d, enemy["body"], enemy["accent"], enemy["build"], enemy["hat"], pose)
    # faint PLACEHOLDER banding, so a stand-in is never mistaken for final art
    for y in range(0, CHAR_H, 14):
        d.line([0, y, CHAR_W, y], fill=WATERMARK)
    return img


def write_clip(folder, frames):
    for i, im in enumerate(frames):
        im.save(out("characters", folder, "frame_%d.png" % i))


def build_characters():
    n = 0
    for e in ROSTER:
        # idle — a slow breath plus a small sway
        idle = [char_frame(e, dict(bob=math.sin(i / 4 * math.tau) * 1.0,
                                   arm=18 + math.sin(i / 4 * math.tau) * 6))
                for i in range(4)]
        write_clip("%s_idle" % e["slug"], idle); n += len(idle)

        # hit — knocked back, then recovering
        hit = [char_frame(e, dict(lean=-0.55 + i * 0.16, bob=-0.8 + i * 0.2, arm=-24 + i * 10))
               for i in range(4)]
        write_clip("%s_hit" % e["slug"], hit); n += len(hit)

        # one attack clip per SKILL, each with its own prop and tint, so no two
        # skills of the same enemy share an animation
        props = {"stamp_slam": "stamp", "paper_cut_volley": "paper", "counter_charge": "paper",
                 "backdoor_dash": "paper", "envelope_express": "paper", "queue_skip_kick": "paper",
                 "permit_board_bash": "book", "fake_seal_shot": "stamp",
                 "carbon_copy_barrage": "paper",
                 "notary_stampede": "stamp", "signature_slash": "cane",
                 "seal_of_approval": "stamp",
                 "cash_drawer_bash": "case", "coin_flick": "coin", "receipt_whip": "paper",
                 "budget_bag_bash": "sack", "coin_burst": "coin", "deficit_drop": "sack",
                 "briefcase_beatdown": "case", "bid_folder_fan": "paper",
                 "contract_snare": "paper",
                 "codex_crusher": "book", "citation_cannon": "book", "session_smash": "book",
                 "kaban_ng_bayan": "case", "plunder_supremo": "sack",
                 "jueteng_jackpot": "coin", "executive_privilege": "cane"}
        for m in e["moves"]:
            col = tuple(int(c * 255) for c in m["tint"][:3])
            prop = props.get(m["id"], "paper")
            # wind up, hold, strike, follow through, recover
            arcs = [-52, -70, -40, 26, 52, 18]
            leans = [-0.25, -0.4, 0.1, 0.75, 0.95, 0.35]
            frames = [char_frame(e, dict(arm=arcs[i], lean=leans[i],
                                         bob=0.4 if i in (1, 2) else 0.0,
                                         prop=prop, prop_col=col))
                      for i in range(6)]
            write_clip("%s_%s" % (e["slug"], m["id"]), frames); n += len(frames)
    return n


# ---------------------------------------------------------------- portraits
def build_portraits():
    for e in ROSTER:
        img = Image.new("RGBA", (PORT, PORT), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([4, 4, PORT - 4, PORT - 4], radius=8,
                            fill=shade(e["body"], 0.55))
        d.ellipse([34, 24, 94, 84], fill=shade(e["body"], 1.35))
        d.rectangle([28, 88, 100, PORT - 8], fill=e["body"])
        d.rectangle([28, 96, 100, 106], fill=e["accent"])
        if e["hat"] == "mask":
            d.rectangle([34, 44, 94, 58], fill=shade(e["body"], 0.4))
        if e["boss"]:
            d.polygon([(24, 88), (104, 88), (94, 106), (34, 106)], fill=e["accent"])
        img.save(out("portraits", "enemy_%s.png" % e["slug"]))
    return len(ROSTER)


# -------------------------------------------------------------- move icons
def build_icons():
    n = 0
    for e in ROSTER:
        for m in e["moves"]:
            col = tuple(int(c * 255) for c in m["tint"][:3])
            img = Image.new("RGBA", (ICON, ICON), (0, 0, 0, 0))
            d = ImageDraw.Draw(img)
            d.rounded_rectangle([2, 2, ICON - 3, ICON - 3], radius=4,
                                fill=shade(col, 0.45), outline=col)
            d.rectangle([7, 9, ICON - 8, ICON - 9], fill=col)
            d.line([7, 13, ICON - 8, 13], fill=shade(col, 0.5))
            d.line([7, 17, ICON - 8, 17], fill=shade(col, 0.5))
            img.save(out("moves", "%s.png" % m["id"])); n += 1
    return n


# ------------------------------------------------------------- backgrounds
def build_backgrounds():
    # Must match WordBattleController.BATTLE_GROUND_FRACTION. The battle scene
    # scales a backdrop so THIS line lands under the fighters' feet; putting the
    # floor anywhere else leaves them standing in mid-air and crops the room.
    FLOOR_Y = int(BG_H * 0.9125)
    for b in BACKGROUNDS:
        img = Image.new("RGBA", (BG_W, BG_H), (0, 0, 0, 255))
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, BG_W, FLOOR_Y], fill=b["wall"])
        d.rectangle([0, FLOOR_Y, BG_W, BG_H], fill=b["floor"])
        # floor boards, so the ground line reads
        for x in range(0, BG_W, 24):
            d.line([x, FLOOR_Y, x - 14, BG_H], fill=shade(b["floor"], 0.9))
        d.line([0, FLOOR_Y, BG_W, FLOOR_Y], fill=shade(b["floor"], 0.7), width=2)

        k = b["kind"]
        if k == "plaza":
            d.rectangle([0, 0, BG_W, 70], fill=b["sky"])
            d.rectangle([96, 26, 288, FLOOR_Y], fill=shade(b["wall"], 0.92))
            for x in range(112, 280, 28):          # colonnade
                d.rectangle([x, 60, x + 12, FLOOR_Y], fill=shade(b["wall"], 1.08))
            d.polygon([(88, 30), (192, 6), (296, 30)], fill=shade(b["wall"], 0.82))
            for fx, cols in ((60, [(0, 56, 168), (206, 17, 38)]),
                             (316, [(240, 200, 40), (30, 120, 70)])):
                d.line([fx, 26, fx, FLOOR_Y], fill=(90, 90, 90), width=2)
                d.rectangle([fx, 28, fx + 26, 44], fill=cols[0])
                d.rectangle([fx, 44, fx + 26, 52], fill=cols[1])
            for sy in range(0, 5):                  # entrance stairs
                d.rectangle([150, FLOOR_Y + sy * 5, 234, FLOOR_Y + sy * 5 + 5],
                            fill=shade(b["floor"], 1.0 + sy * 0.04))
        elif k == "lobby":
            for x in range(20, BG_W - 20, 92):      # service counters
                d.rectangle([x, FLOOR_Y - 34, x + 74, FLOOR_Y], fill=shade(b["wall"], 0.72))
                d.rectangle([x, FLOOR_Y - 40, x + 74, FLOOR_Y - 34], fill=shade(b["wall"], 0.9))
            d.rectangle([148, 20, 236, 48], fill=(28, 34, 40))
            d.rectangle([156, 28, 228, 40], fill=(90, 220, 140))   # NEXT NUMBER
            for x in range(30, BG_W - 30, 34):      # waiting chairs
                d.rectangle([x, FLOOR_Y + 18, x + 22, FLOOR_Y + 26], fill=(80, 110, 150))
        elif k == "permits":
            d.rectangle([24, 18, 168, 44], fill=(238, 236, 226))
            d.rectangle([200, 18, 344, 44], fill=(238, 236, 226))
            d.rectangle([28, 60, BG_W - 28, FLOOR_Y - 40], fill=shade(b["wall"], 1.06))
            d.rectangle([BG_W - 96, FLOOR_Y - 74, BG_W - 30, FLOOR_Y], fill=(70, 76, 82))
            d.rectangle([BG_W - 88, FLOOR_Y - 66, BG_W - 38, FLOOR_Y - 46], fill=(150, 160, 168))
            d.rectangle([30, FLOOR_Y - 30, 190, FLOOR_Y], fill=shade(b["wall"], 0.74))
        elif k == "archive":
            for x in range(10, BG_W - 40, 52):      # filing cabinets
                d.rectangle([x, 40, x + 42, FLOOR_Y], fill=shade(b["wall"], 0.8))
                for dy in range(48, FLOOR_Y - 10, 26):
                    d.rectangle([x + 4, dy, x + 38, dy + 20], fill=shade(b["wall"], 0.62))
                    d.rectangle([x + 16, dy + 8, x + 26, dy + 12], fill=shade(b["wall"], 1.1))
            for i, sx in enumerate((70, 210, 300)):  # stacked paper
                d.rectangle([sx, FLOOR_Y - 16 - i * 3, sx + 30, FLOOR_Y], fill=(226, 220, 200))
        elif k == "treasury":
            d.rectangle([14, 44, BG_W - 100, FLOOR_Y - 6], fill=shade(b["wall"], 0.7))
            for x in range(26, BG_W - 118, 62):     # cashier windows
                d.rectangle([x, 56, x + 46, FLOOR_Y - 34], fill=(178, 206, 214))
                d.line([x, FLOOR_Y - 46, x + 46, FLOOR_Y - 46], fill=(90, 96, 104), width=3)
            d.ellipse([BG_W - 88, 66, BG_W - 16, FLOOR_Y - 6], fill=shade(b["wall"], 0.5))
            d.ellipse([BG_W - 66, 92, BG_W - 38, 122], fill=(200, 190, 150))  # vault wheel
        elif k == "budget":
            for i, x in enumerate(range(26, BG_W - 60, 76)):   # budget charts
                d.rectangle([x, 34, x + 58, 104], fill=(242, 240, 232))
                for bx in range(6):
                    h = 8 + ((bx * 13 + i * 7) % 46)
                    d.rectangle([x + 5 + bx * 8, 100 - h, x + 10 + bx * 8, 100],
                                fill=(70 + bx * 22, 110, 170))
            d.rectangle([20, FLOOR_Y - 40, BG_W - 20, FLOOR_Y], fill=shade(b["wall"], 0.72))
            for x in range(30, BG_W - 40, 44):      # folder stacks
                d.rectangle([x, FLOOR_Y - 54, x + 30, FLOOR_Y - 40], fill=(200, 176, 120))
        elif k == "bidding":
            d.rectangle([44, 22, BG_W - 44, 96], fill=(24, 30, 38))
            d.rectangle([54, 32, BG_W - 54, 86], fill=(46, 120, 96))     # bidding screen
            d.rounded_rectangle([40, FLOOR_Y - 44, BG_W - 40, FLOOR_Y + 12], radius=6,
                                fill=shade(b["wall"], 0.66))
            for x in range(64, BG_W - 64, 54):      # bid boxes + mics
                d.rectangle([x, FLOOR_Y - 62, x + 34, FLOOR_Y - 44], fill=(196, 178, 140))
                d.line([x + 17, FLOOR_Y - 62, x + 17, FLOOR_Y - 76], fill=(60, 60, 66), width=2)
        elif k == "session":
            d.ellipse([150, 22, 234, 106], fill=shade(b["accent"] if "accent" in b else (198, 160, 90), 1.0))
            d.ellipse([162, 34, 222, 94], fill=shade(b["wall"], 0.8))
            for row, y in enumerate(range(FLOOR_Y - 54, FLOOR_Y + 20, 26)):
                inset = 20 + row * 16
                d.rounded_rectangle([inset, y, BG_W - inset, y + 18], radius=3,
                                    fill=shade(b["wall"], 0.6 + row * 0.08))
                for x in range(inset + 14, BG_W - inset - 10, 40):
                    d.line([x, y, x, y - 9], fill=(50, 46, 44), width=2)
            for fx, c in ((26, (0, 56, 168)), (BG_W - 52, (240, 200, 40))):
                d.rectangle([fx, 26, fx + 26, 58], fill=c)
        elif k == "mayor":
            d.rectangle([18, 26, 128, 104], fill=(120, 150, 180))   # window on the city
            d.rectangle([BG_W - 128, 26, BG_W - 18, 104], fill=(120, 150, 180))
            for wx in range(24, 122, 16):
                d.rectangle([wx, 60, wx + 9, 104], fill=(150, 176, 200))
            d.ellipse([158, 24, 226, 92], fill=(150, 122, 62))      # city seal
            d.ellipse([170, 36, 214, 80], fill=shade(b["wall"], 0.7))
            d.rounded_rectangle([96, FLOOR_Y - 46, BG_W - 96, FLOOR_Y + 16], radius=5,
                                fill=(78, 56, 44))                   # executive desk
            d.rectangle([BG_W - 92, FLOOR_Y - 76, BG_W - 30, FLOOR_Y], fill=(96, 92, 88))
            d.ellipse([BG_W - 74, FLOOR_Y - 54, BG_W - 48, FLOOR_Y - 28], fill=(206, 178, 96))
            for i, sx in enumerate((40, 70)):       # money sacks by the vault
                d.ellipse([sx, FLOOR_Y - 26 - i * 4, sx + 26, FLOOR_Y], fill=(198, 176, 110))

        for y in range(0, BG_H, 16):
            d.line([0, y, BG_W, y], fill=(255, 255, 255, 16))
        img.convert("RGB").save(out("backgrounds", "%s.png" % b["key"]))
    return len(BACKGROUNDS)


if __name__ == "__main__":
    c = build_characters()
    p = build_portraits()
    i = build_icons()
    g = build_backgrounds()
    print("character frames: %d" % c)
    print("portraits:        %d" % p)
    print("move icons:       %d" % i)
    print("backgrounds:      %d" % g)
    print("total files:      %d" % (c + p + i + g))
