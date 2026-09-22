# -*- coding: utf-8 -*-
"""Draws all 27 Chapter 5 skill icons.

    python tools/chapter5/build_icons.py

Writes assets/images/ui/skill_icons/chapter5/<slug>/<move>.png -- 64x64 RGBA
with a transparent background, matching where Chapter 3 keeps its icons and
what EnemyMove.icon expects.

WHY THESE ARE DRAWN RATHER THAN GENERATED
    Chapter 3's icons were one model generation each. That budget is gone -- 6
    generations remained when Chapter 5 started, against a bill of 27 icons,
    9 characters and 9 rooms -- and the brief is explicit that Chapter 5 must
    NOT repeat Chapter 3's period of having no icons at all. So they are drawn
    here instead, and drawing them turns out to suit the job: a skill icon is
    read at about 22 pixels beside a move name, where a bold silhouette of one
    recognisable object beats a detailed illustration every time.

HOW THEY ARE DRAWN
    Everything is composed at 32x32 and scaled 2x with nearest-neighbour, so
    every edge lands on an even pixel boundary and the result is genuinely
    chunky rather than a smooth drawing shrunk down. Each icon is one clear
    subject -- a gavel, a chair, a folder, a ledger -- built from the shared
    motif helpers below, so twenty-seven icons look like one set.

    The palette is deliberately small and shared. Congress is paper and dark
    wood, so cream, wood-brown and near-black carry every icon, and each rival
    contributes one accent from its own spec colour.
"""
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "chapter5"))
import spec  # noqa: E402

DEST = os.path.join(ROOT, "assets", "images", "ui", "skill_icons", "chapter5")
G = 32                      # the grid everything is drawn on
SCALE = 2                   # 32 -> 64

INK = (26, 20, 16, 255)             # the outline, near-black warm
PAPER = (247, 242, 226, 255)        # official cream stock
PAPER_SHADE = (214, 203, 176, 255)
WOOD = (140, 92, 48, 255)
WOOD_DARK = (96, 60, 30, 255)
GOLD = (247, 205, 84, 255)
GOLD_DARK = (196, 148, 44, 255)
STEEL = (108, 122, 140, 255)
RED = (206, 62, 58, 255)
BLUE = (74, 116, 198, 255)
GREEN = (74, 176, 118, 255)
SHADOW = (0, 0, 0, 70)


def accent(entry):
    r, g, b = entry["colour"]
    return (int(r * 255), int(g * 255), int(b * 255), 255)


# --- primitives ----------------------------------------------------------
# All coordinates are inclusive pixel positions on the 32x32 grid.

def box(d, x, y, w, h, fill, ink=INK):
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=fill, outline=ink)


def bar(d, x1, y1, x2, y2, fill, width=3, ink=INK):
    """A thick line with an outline, drawn as an outline pass then a fill."""
    d.line([x1, y1, x2, y2], fill=ink, width=width + 2)
    d.line([x1, y1, x2, y2], fill=fill, width=width)


def disc(d, cx, cy, r, fill, ink=INK):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=ink)


def wedge(d, points, fill, ink=INK):
    d.polygon(points, fill=fill, outline=ink)


# --- shared motifs -------------------------------------------------------

def paper(d, x, y, w=9, h=12, fill=PAPER, lines=True):
    """A sheet of official stock, with a folded corner and ruled lines."""
    box(d, x, y, w, h, fill)
    d.line([x + w - 4, y, x + w - 1, y + 3], fill=INK)
    if lines and w >= 8:
        for i in range(2, h - 2, 3):
            d.line([x + 2, y + i, x + w - 3, y + i], fill=PAPER_SHADE)


def folder(d, x, y, w, h, fill):
    """A document folder: a tab, then the body."""
    box(d, x, y + 2, w, h - 2, fill)
    box(d, x, y, max(4, w // 2), 3, fill)


def gavel(d, cx, cy, angle_down=True, head=GOLD):
    """The chapter's signature object: a mallet head on a wooden handle.

    Drawn with a LIGHT handle and a light head. A first version used dark wood
    for both and the whole icon collapsed into one unreadable dark stick at the
    size these are actually viewed."""
    if angle_down:
        bar(d, cx - 9, cy + 6, cx + 2, cy - 5, PAPER_SHADE, 3)
        d.rectangle([cx - 1, cy - 11, cx + 10, cy - 3], fill=head, outline=INK)
        d.line([cx + 4, cy - 10, cx + 4, cy - 4], fill=GOLD_DARK)
    else:
        bar(d, cx - 6, cy + 8, cx + 3, cy - 2, PAPER_SHADE, 3)
        d.rectangle([cx - 2, cy - 10, cx + 9, cy - 2], fill=head, outline=INK)


def microphone(d, cx, cy, tint=GOLD):
    """A mic reads as a light BALL on a light stem. Drawn dark on dark it
    disappeared entirely in the first pass."""
    disc(d, cx, cy - 5, 5, tint)
    d.line([cx - 3, cy - 7, cx + 1, cy - 7], fill=PAPER)      # highlight
    d.rectangle([cx - 2, cy - 1, cx + 2, cy + 8], fill=PAPER_SHADE, outline=INK)
    d.rectangle([cx - 4, cy + 8, cx + 4, cy + 10], fill=STEEL, outline=INK)


def chair(d, x, y, fill=WOOD, ghost=False):
    """An empty congressional seat, seen from the side."""
    ink = (INK[0], INK[1], INK[2], 110) if ghost else INK
    body = (fill[0], fill[1], fill[2], 110) if ghost else fill
    d.rectangle([x, y, x + 8, y + 9], fill=body, outline=ink)      # back
    d.rectangle([x, y + 9, x + 13, y + 12], fill=body, outline=ink)  # seat
    d.line([x + 1, y + 13, x + 1, y + 18], fill=ink)
    d.line([x + 12, y + 13, x + 12, y + 18], fill=ink)


def plate(d, x, y, w, h, fill):
    """A shield panel -- the shape every defensive icon is built on."""
    d.polygon([(x, y), (x + w, y), (x + w, y + h - 5),
               (x + w // 2, y + h), (x, y + h - 5)], fill=fill, outline=INK)


def token(d, cx, cy, fill, tick=True):
    """A vote token: a disc with a check."""
    disc(d, cx, cy, 4, fill)
    if tick:
        d.line([cx - 2, cy, cx - 1, cy + 2], fill=INK)
        d.line([cx - 1, cy + 2, cx + 2, cy - 2], fill=INK)


def peso(d, cx, cy, fill=GOLD):
    disc(d, cx, cy, 5, fill)
    d.line([cx - 1, cy - 3, cx - 1, cy + 3], fill=INK)
    d.line([cx - 1, cy - 3, cx + 2, cy - 3], fill=INK)
    d.line([cx + 2, cy - 3, cx + 2, cy], fill=INK)
    d.line([cx - 1, cy, cx + 2, cy], fill=INK)
    d.line([cx - 3, cy - 1, cx + 3, cy - 1], fill=INK)
    d.line([cx - 3, cy + 1, cx + 3, cy + 1], fill=INK)


def impact(d, cx, cy, fill=GOLD):
    """A four-point burst, for anything that lands hard."""
    for dx, dy in ((0, -7), (0, 7), (-7, 0), (7, 0)):
        d.line([cx, cy, cx + dx, cy + dy], fill=fill, width=2)
    for dx, dy in ((-5, -5), (5, -5), (-5, 5), (5, 5)):
        d.line([cx, cy, cx + dx, cy + dy], fill=fill)


def motion(d, points, fill=PAPER_SHADE):
    """Speed lines behind a thrown object."""
    for x1, y1, x2, y2 in points:
        d.line([x1, y1, x2, y2], fill=fill)


# --- the twenty-seven ----------------------------------------------------
# Each takes the draw context and the rival's accent colour.

def scripted_strike(d, c):
    motion(d, [(2, 8, 9, 8), (2, 12, 8, 12), (3, 16, 9, 16)])
    bar(d, 8, 24, 26, 6, PAPER, 5)          # the rolled bill, mid-swing
    d.line([9, 23, 25, 7], fill=PAPER_SHADE, width=1)
    impact(d, 25, 7, c)


def bill_barrage(d, c):
    motion(d, [(1, 7, 7, 7), (1, 16, 6, 16), (2, 25, 8, 25)])
    paper(d, 8, 2, 10, 12)
    paper(d, 13, 11, 10, 12)
    paper(d, 19, 20, 11, 11, c)


def talking_point_guard(d, c):
    plate(d, 4, 5, 24, 23, PAPER_SHADE)
    box(d, 8, 9, 9, 12, PAPER)
    box(d, 14, 7, 9, 12, PAPER)
    box(d, 11, 12, 9, 12, c)


def interpellation_jab(d, c):
    # A pointing hand: knuckles, thumb and ONE finger. The first version drew a
    # bare rectangle on a rectangle, which read as a cream cross rather than a
    # hand, so the knuckle line and the thumb are what carry it now.
    # Bigger hand, burst moved off it. When the burst sat on top of the finger
    # the two merged into one bright smear and the hand stopped reading.
    d.rectangle([7, 13, 23, 28], fill=PAPER, outline=INK)       # the fist
    d.rectangle([12, 2, 19, 14], fill=PAPER, outline=INK)       # the finger
    d.rectangle([2, 16, 8, 23], fill=PAPER, outline=INK)        # the thumb
    for y in (17, 21, 25):
        d.line([10, y, 21, y], fill=PAPER_SHADE)                # knuckles
    for dx, dy in ((-4, -3), (0, -5), (4, -3)):
        d.line([15 + dx, 1 + dy, 15 + dx * 2, dy - 1], fill=c, width=2)


def floor_hirit(d, c):
    microphone(d, 8, 13)
    for i, r in enumerate((5, 9, 13)):
        d.arc([17 - r, 15 - r, 17 + r, 15 + r], -62, 62,
              fill=c if i == 2 else PAPER, width=2)


def point_of_order(d, c):
    d.rectangle([17, 15, 29, 27], fill=PAPER, outline=INK)      # the fist
    d.rectangle([21, 4, 26, 16], fill=PAPER, outline=INK)       # the finger
    for y in (19, 22, 25):
        d.line([20, y, 27, y], fill=PAPER_SHADE)
    gavel(d, 9, 16, head=c)                                     # and the gavel
    impact(d, 23, 5, GOLD)


def gavel_bang(d, c):
    gavel(d, 15, 11)
    d.rectangle([3, 24, 29, 29], fill=WOOD, outline=INK)        # the sound block
    d.line([5, 26, 27, 26], fill=WOOD_DARK)
    impact(d, 16, 22, c)


def mic_barrage(d, c):
    motion(d, [(1, 7, 5, 7), (1, 17, 4, 17), (2, 27, 6, 27)])
    microphone(d, 10, 8, PAPER)
    microphone(d, 22, 12, c)
    microphone(d, 13, 22, GOLD)


def committee_shield(d, c):
    # Pale plate, dark furniture. The accent colour filled the whole plate in
    # the first version and swallowed the table it was meant to frame.
    plate(d, 2, 4, 28, 25, PAPER_SHADE)
    d.rectangle([5, 8, 27, 10], fill=c, outline=INK)            # nameplate rail
    d.rectangle([5, 13, 27, 18], fill=WOOD_DARK, outline=INK)   # hearing table
    d.line([7, 15, 25, 15], fill=WOOD)
    folder(d, 7, 19, 8, 8, PAPER)
    folder(d, 18, 19, 8, 8, PAPER)


def attendance_swipe(d, c):
    d.rectangle([9, 4, 24, 27], fill=PAPER, outline=INK)        # clipboard
    d.rectangle([13, 2, 20, 6], fill=STEEL, outline=INK)        # clip
    for y in (11, 16, 21):
        d.line([12, y, 15, y + 2], fill=c)
        d.line([15, y + 2, 21, y - 3], fill=c)
    bar(d, 2, 26, 12, 12, PAPER_SHADE, 2)                       # the swipe


def empty_seat_shuffle(d, c):
    chair(d, 3, 6, WOOD, ghost=True)
    chair(d, 15, 8, c)
    motion(d, [(1, 3, 8, 3), (24, 26, 30, 26)])


def quorum_escape(d, c):
    chair(d, 10, 7, WOOD)
    chair(d, 18, 9, c, ghost=True)
    for x in (6, 8, 10):
        d.line([x, 4, x, 28], fill=(c[0], c[1], c[2], 60))


def bloc_breaker(d, c):
    box(d, 2, 9, 11, 14, BLUE)
    box(d, 19, 9, 11, 14, c)
    impact(d, 16, 16, GOLD)


def vote_count_volley(d, c):
    motion(d, [(1, 8, 6, 8), (1, 17, 5, 17), (2, 26, 7, 26)])
    token(d, 11, 8, PAPER)
    token(d, 18, 16, c)
    token(d, 12, 25, PAPER)


def majority_guard(d, c):
    plate(d, 3, 5, 26, 23, c)
    token(d, 11, 13, PAPER)
    token(d, 21, 13, PAPER)
    token(d, 16, 21, PAPER)
    d.line([11, 13, 21, 13], fill=INK)
    d.line([11, 13, 16, 21], fill=INK)
    d.line([21, 13, 16, 21], fill=INK)


def red_pen_slash(d, c):
    bar(d, 5, 27, 25, 7, RED, 4)                                # the pen body
    wedge(d, [(25, 7), (29, 3), (27, 9)], GOLD)                 # the nib
    d.line([6, 12, 20, 26], fill=RED, width=2)                  # the mark
    d.line([8, 24, 20, 12], fill=RED, width=2)


def revision_rain(d, c):
    motion(d, [(6, 1, 6, 5), (16, 1, 16, 4), (25, 1, 25, 6)])
    paper(d, 3, 5, 9, 11)
    paper(d, 13, 9, 9, 11)
    paper(d, 20, 16, 11, 13, PAPER)
    d.line([21, 19, 29, 27], fill=RED, width=2)
    d.line([21, 27, 29, 19], fill=RED, width=2)


def motion_to_amend(d, c):
    plate(d, 4, 4, 24, 24, PAPER)
    for i in range(9, 22, 4):
        d.line([9, i, 23, i], fill=PAPER_SHADE)
    d.line([8, 9, 24, 23], fill=RED, width=2)
    d.line([8, 23, 24, 9], fill=RED, width=2)


def conference_crash(d, c):
    folder(d, 2, 8, 12, 15, BLUE)
    folder(d, 18, 8, 12, 15, RED)
    impact(d, 16, 16, GOLD)


def bicam_merge(d, c):
    paper(d, 2, 3, 9, 11, BLUE, lines=False)
    paper(d, 21, 3, 9, 11, RED, lines=False)
    d.line([9, 14, 14, 18], fill=INK)
    d.line([23, 14, 18, 18], fill=INK)
    box(d, 9, 17, 14, 13, GOLD)                                 # the merged bill
    d.line([12, 22, 20, 22], fill=GOLD_DARK)
    d.line([12, 26, 20, 26], fill=GOLD_DARK)


def compromise_shield(d, c):
    d.polygon([(3, 5), (16, 5), (16, 31), (3, 23)], fill=BLUE, outline=INK)
    d.polygon([(16, 5), (29, 5), (29, 23), (16, 31)], fill=RED, outline=INK)
    d.line([16, 5, 16, 31], fill=INK)


def budget_book_bash(d, c):
    box(d, 4, 6, 24, 18, WOOD_DARK)                             # the tome
    box(d, 7, 9, 18, 12, PAPER)
    d.line([16, 9, 16, 20], fill=PAPER_SHADE)
    peso(d, 16, 15, c)
    impact(d, 16, 27, GOLD)


def appropriation_bombardment(d, c):
    motion(d, [(5, 1, 5, 4), (15, 1, 15, 3), (25, 1, 25, 5)])
    peso(d, 7, 9, GOLD)
    peso(d, 22, 13, c)
    folder(d, 10, 18, 13, 13, PAPER)


def fiscal_fortress(d, c):
    plate(d, 2, 5, 28, 24, WOOD_DARK)
    box(d, 6, 9, 20, 13, PAPER)
    d.line([16, 9, 16, 21], fill=PAPER_SHADE)
    peso(d, 16, 15, GOLD)


def house_rules(d, c):
    gavel(d, 16, 11)
    d.rectangle([3, 23, 29, 28], fill=WOOD_DARK, outline=INK)
    impact(d, 16, 22, GOLD)
    d.line([2, 4, 6, 8], fill=GOLD)
    d.line([30, 4, 26, 8], fill=GOLD)


def majority_motion(d, c):
    box(d, 2, 4, 28, 20, STEEL)                                 # the vote board
    for i, x in enumerate((6, 13, 20)):
        token(d, x + 2, 11, GREEN if i < 2 else PAPER)
    d.rectangle([6, 16, 26, 21], fill=GOLD, outline=INK)
    d.line([8, 18, 24, 18], fill=GOLD_DARK)
    d.rectangle([12, 25, 20, 29], fill=WOOD, outline=INK)       # the rostrum


def speakers_shield(d, c):
    # A gold plate carrying a dark House roundel. Laying a gold gavel over a
    # pale disc on a gold plate gave three light tones in a stack and the whole
    # emblem read as one blob, so the roundel is dark and the gavel sits below
    # it in silhouette.
    plate(d, 2, 3, 28, 26, GOLD)
    disc(d, 16, 13, 8, WOOD_DARK)
    for a in range(5):                                          # the star
        import math
        ang = -math.pi / 2 + a * 2 * math.pi / 5
        d.line([16, 13, 16 + int(6 * math.cos(ang)), 13 + int(6 * math.sin(ang))],
               fill=GOLD, width=2)
    bar(d, 9, 26, 23, 22, PAPER_SHADE, 3)                       # the gavel
    d.rectangle([20, 19, 27, 25], fill=GOLD_DARK, outline=INK)


ICONS = {
    "scripted_strike": scripted_strike,
    "bill_barrage": bill_barrage,
    "talking_point_guard": talking_point_guard,
    "interpellation_jab": interpellation_jab,
    "floor_hirit": floor_hirit,
    "point_of_order": point_of_order,
    "gavel_bang": gavel_bang,
    "mic_barrage": mic_barrage,
    "committee_shield": committee_shield,
    "attendance_swipe": attendance_swipe,
    "empty_seat_shuffle": empty_seat_shuffle,
    "quorum_escape": quorum_escape,
    "bloc_breaker": bloc_breaker,
    "vote_count_volley": vote_count_volley,
    "majority_guard": majority_guard,
    "red_pen_slash": red_pen_slash,
    "revision_rain": revision_rain,
    "motion_to_amend": motion_to_amend,
    "conference_crash": conference_crash,
    "bicam_merge": bicam_merge,
    "compromise_shield": compromise_shield,
    "budget_book_bash": budget_book_bash,
    "appropriation_bombardment": appropriation_bombardment,
    "fiscal_fortress": fiscal_fortress,
    "house_rules": house_rules,
    "majority_motion": majority_motion,
    "speakers_shield": speakers_shield,
}


def main():
    made = 0
    faults = []
    for entry in spec.all_entries():
        slug = entry["slug"]
        folder_path = os.path.join(DEST, slug)
        os.makedirs(folder_path, exist_ok=True)
        for name, _kind, _value, _tagalog, _english in entry["moves"]:
            key = spec.move_id(slug, name)[len(spec.PREFIX):]
            draw_fn = ICONS.get(key)
            if draw_fn is None:
                faults.append("%s: no icon drawn for %s" % (slug, name))
                continue
            image = Image.new("RGBA", (G, G), (0, 0, 0, 0))
            d = ImageDraw.Draw(image, "RGBA")
            draw_fn(d, accent(entry))
            # A silhouette that touches the frame gets clipped by the UI's own
            # padding, and one that fills nothing is an empty slot with extra
            # steps. Both are caught here rather than seen in the moves panel.
            bounds = image.getchannel("A").getbbox()
            if bounds is None:
                faults.append("%s/%s drew nothing" % (slug, key))
                continue
            coverage = sum(1 for v in image.getchannel("A").getdata() if v > 8) / float(G * G)
            if coverage < 0.10:
                faults.append("%s/%s is nearly empty (%.0f%% covered)"
                              % (slug, key, coverage * 100))
            big = image.resize((G * SCALE, G * SCALE), Image.Resampling.NEAREST)
            big.save(os.path.join(folder_path, key + ".png"))
            made += 1
    print("drew %d icons into %s" % (made, os.path.relpath(DEST, ROOT)))
    if faults:
        print("\nFAULTS:")
        for f in faults:
            print("   %s" % f)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
