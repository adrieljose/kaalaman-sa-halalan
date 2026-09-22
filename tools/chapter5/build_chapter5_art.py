# -*- coding: utf-8 -*-
"""Builds Chapter 5 frames from the approved cleaned real sprites.

Current mode: all nine real sources are mandatory. Missing art aborts before
writing any game assets. Authored landmarks replace silhouette inference.
The historical block-in helper below is retained for provenance but is no
longer used by the production build.

    python tools/chapter5/build_chapter5_art.py

For each rival it writes six clips into
assets/images/characters/chapter5/<slug>_<clip>/frame_N.png --

    idle 8, attack 12, attack2 12, guard 10, hit 8, walk 10

and a 96x96 portrait into assets/images/portraits/enemy_<slug>.png.

TWO SOURCES, ONE PIPELINE
    The generation budget ran out during Chapter 4: six generations remained
    against nine characters, and a v3 repose alone costs one to two each. So
    Chapter 5's rivals have no generated art yet.

    Rather than leave the chapter unbuildable and untestable until they do,
    this script takes its sprite from whichever source is available:

      1. output/chapter5_villains/rot/<slug>/south-west.png -- the real
         reposed sprite, once a PixelLab account is connected and
         make_refs.py / fetch_rotations.py have been run, exactly as for
         Chapter 4; or
      2. a BLOCK-IN drawn here, in the rival's own palette and proportions.

    Everything after that point is identical. The block-in is deliberately
    flat and obviously unfinished -- it could never be mistaken for the real
    thing, which is the point -- but it is the correct height, build and
    silhouette for its character, so grounding, body_rect, the articulation
    rig, staging and the safe-zone clamp are all genuinely exercised. When the
    real sprites land, this script is re-run and NOTHING else changes: no
    resource, no id, no test.
"""
import os
import sys
import numpy as np

from PIL import Image, ImageDraw

import importlib.util

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Chapter 4 and Chapter 5 both ship a module called `spec`, so a plain
# sys.path import binds whichever directory happens to be first and the script
# silently builds the WRONG roster -- which is exactly what it did on the
# first run. Each is therefore loaded by path under its own module name.
def _load(name, relative):
    spot = importlib.util.spec_from_file_location(name, os.path.join(ROOT, *relative))
    module = importlib.util.module_from_spec(spot)
    sys.modules[name] = module
    spot.loader.exec_module(module)
    return module


sys.path.insert(0, os.path.join(ROOT, "tools", "chapter4"))
import build_chapter4_art as rig  # noqa: E402  -- the articulation pipeline
spec = _load("chapter5_spec", ("tools", "chapter5", "spec.py"))

ROT = os.path.join(ROOT, "output", "chapter5_villains", "rot")
ART = os.path.join(ROOT, "assets", "images", "characters", "chapter5")
PORTRAITS = os.path.join(ROOT, "assets", "images", "portraits")
CHECK = os.path.join(ROOT, "output", "chapter5_villains", "rig")

# Authored against the cleaned source silhouettes, not inferred from their
# highest pixel (Chairman's raised gavel is well above his actual head).
# head/chest/hips, near arm, far arm, near knee/foot, far knee/foot, prop.
LANDMARKS = {
    "cong_kodigo": [( .44,.10),(.54,.32),(.56,.55),(.33,.27),(.17,.40),(.10,.31),(.70,.29),(.85,.46),(.87,.43),(.30,.73),(.14,.97),(.77,.76),(.90,.94),(.10,.24)],
    "senador_sawsaw": [(.50,.12),(.56,.34),(.60,.57),(.36,.28),(.23,.35),(.10,.24),(.76,.30),(.78,.45),(.62,.36),(.32,.72),(.14,.97),(.77,.80),(.86,.97),(.59,.29)],
    "chairman_chika": [(.48,.18),(.51,.34),(.50,.59),(.33,.31),(.11,.30),(.10,.17),(.70,.32),(.84,.46),(.75,.49),(.26,.77),(.13,.97),(.81,.77),(.87,.93),(.20,.05)],
    "quorum_kuno": [(.43,.12),(.51,.32),(.52,.53),(.31,.27),(.22,.40),(.14,.28),(.71,.27),(.85,.41),(.81,.35),(.31,.70),(.21,.97),(.84,.70),(.87,.85),(.08,.21)],
    "whip_walanghiya": [(.43,.11),(.54,.33),(.56,.55),(.27,.27),(.08,.35),(.28,.37),(.77,.29),(.91,.40),(.68,.40),(.24,.73),(.10,.97),(.83,.74),(.89,.91),(.77,.27)],
    "amendment_atras": [(.56,.12),(.58,.34),(.60,.52),(.41,.30),(.35,.34),(.25,.30),(.71,.30),(.84,.46),(.87,.42),(.44,.72),(.31,.97),(.80,.70),(.91,.89),(.11,.24)],
    "bicam_berto": [(.54,.11),(.55,.32),(.56,.53),(.32,.27),(.25,.43),(.05,.37),(.74,.28),(.86,.47),(.92,.45),(.32,.73),(.17,.97),(.82,.72),(.89,.91),(.13,.34)],
    "budget_bomba": [(.41,.10),(.49,.33),(.50,.59),(.24,.24),(.16,.42),(.53,.48),(.78,.24),(.92,.37),(.88,.45),(.19,.78),(.10,.97),(.80,.77),(.90,.94),(.70,.40)],
    "spiker_supremo": [(.45,.11),(.48,.32),(.52,.52),(.30,.27),(.12,.35),(.10,.26),(.70,.27),(.78,.40),(.68,.41),(.34,.74),(.18,.97),(.74,.74),(.89,.91),(.14,.19)],
}

def authored_skeleton(canvas, slug):
    left, top, right, bottom = canvas.getbbox()
    points = np.array([(left + x * (right-left), top + y * (bottom-top))
                       for x, y in LANDMARKS[slug]])
    return points[:13], points[13]

INK = (24, 20, 18, 255)
SKIN = (196, 146, 106, 255)
DARK = (44, 40, 52, 255)

# build -> (shoulder width, hip width, height in px, head radius). The rivals
# are meant to differ in silhouette before they differ in anything else, so
# the block-in carries each one's build rather than nine identical figures.
BUILD = {
    "cong_kodigo": (26, 22, 168, 11),
    "senador_sawsaw": (32, 27, 170, 12),
    "chairman_chika": (27, 24, 166, 11),
    "quorum_kuno": (25, 21, 164, 11),
    "whip_walanghiya": (34, 28, 172, 12),
    "amendment_atras": (26, 22, 170, 11),
    "bicam_berto": (30, 26, 170, 12),
    "budget_bomba": (44, 40, 178, 14),   # the mini-boss: visibly the widest
    "spiker_supremo": (33, 27, 176, 12),
}


def block_in(entry):
    """A flat, obviously-unfinished stand-in with the right build and colours.

    Drawn facing SCREEN LEFT like every real rival: the head sits forward of
    the body's centre line and the lead foot is the left one, so the sprite
    reads as three-quarter-turned even in block-in form and the rig's
    left/right joint bands land where they will land on the real art.
    """
    shoulder, hip, height, head_r = BUILD[entry["slug"]]
    r, g, b = entry["colour"]
    cloth = (int(r * 255), int(g * 255), int(b * 255), 255)
    trouser = DARK
    width = shoulder + 26
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    cx = width // 2 + 2          # body centre, pushed right of frame centre
    head_y = head_r + 4

    # legs, lead one forward
    leg_top = int(height * 0.56)
    d.rectangle([cx - hip // 2, leg_top, cx - 2, height - 6], fill=trouser, outline=INK)
    d.rectangle([cx + 1, leg_top, cx + hip // 2, height - 10], fill=trouser, outline=INK)
    d.rectangle([cx - hip // 2 - 4, height - 7, cx - 1, height - 1], fill=INK)   # lead shoe
    d.rectangle([cx + 1, height - 11, cx + hip // 2 + 3, height - 5], fill=INK)

    # torso
    d.polygon([(cx - shoulder // 2, int(height * 0.24)),
               (cx + shoulder // 2, int(height * 0.24)),
               (cx + hip // 2, leg_top + 2),
               (cx - hip // 2, leg_top + 2)], fill=cloth, outline=INK)

    # arms: the lead arm forward, ready for a prop
    d.rectangle([cx - shoulder // 2 - 7, int(height * 0.28),
                 cx - shoulder // 2 + 1, int(height * 0.50)], fill=cloth, outline=INK)
    d.rectangle([cx + shoulder // 2 - 1, int(height * 0.28),
                 cx + shoulder // 2 + 6, int(height * 0.52)], fill=cloth, outline=INK)
    d.rectangle([cx - shoulder // 2 - 8, int(height * 0.50),
                 cx - shoulder // 2, int(height * 0.56)], fill=SKIN, outline=INK)

    # the prop block, in the lead hand
    d.rectangle([cx - shoulder // 2 - 16, int(height * 0.44),
                 cx - shoulder // 2 - 5, int(height * 0.57)],
                fill=(238, 232, 214, 255), outline=INK)

    # head and neck, set forward of centre
    d.rectangle([cx - 3, int(height * 0.19), cx + 3, int(height * 0.25)],
                fill=SKIN, outline=INK)
    d.ellipse([cx - head_r - 3, head_y - head_r, cx + head_r - 3, head_y + head_r],
              fill=SKIN, outline=INK)
    d.rectangle([cx - head_r - 3, head_y - head_r, cx + head_r - 3, head_y - head_r // 2],
                fill=INK)                                        # hair
    d.rectangle([cx - head_r, head_y - 1, cx - head_r + 3, head_y + 1], fill=INK)  # eye
    return image


def main():
    # Fail before touching existing assets if a real sprite is missing.
    missing = [e["slug"] for e in spec.all_entries()
               if not os.path.exists(os.path.join(ROT, e["slug"], "south-west.png"))]
    if missing:
        raise SystemExit("Real sprites required; refusing block-ins: " + ", ".join(missing))
    os.makedirs(CHECK, exist_ok=True)
    os.makedirs(PORTRAITS, exist_ok=True)
    real, blocked = 0, 0
    for entry in spec.all_entries():
        slug = entry["slug"]
        source = os.path.join(ROT, slug, "south-west.png")
        if os.path.exists(source):
            sprite = Image.open(source).convert("RGBA")
            real += 1
            origin = "reposed sprite"
        else:
            sprite = block_in(entry)
            blocked += 1
            origin = "BLOCK-IN"

        canvas = rig.place(sprite)
        points, prop = authored_skeleton(canvas, slug)
        rig.overlay(canvas, points, prop).convert("RGB").save(
            os.path.join(CHECK, slug + "_rig.png"))

        hx, hy = points[rig.HEAD]
        half = 46
        head = canvas.crop((int(hx - half), int(hy - half),
                            int(hx + half), int(hy + half)))
        head.resize((96, 96), Image.Resampling.NEAREST).save(
            os.path.join(PORTRAITS, "enemy_%s.png" % slug))

        made = 0
        for kind, count in rig.CLIPS:
            folder_path = os.path.join(ART, "%s_%s" % (slug, kind))
            os.makedirs(folder_path, exist_ok=True)
            frames = []
            for index in range(count):
                phase = index / (count if kind in ("idle", "walk") else count - 1)
                image = rig.articulated(canvas, points, prop, kind, phase)
                image.save(os.path.join(folder_path, "frame_%d.png" % index))
                frames.append(image)
                made += 1
            if kind in ("attack", "attack2", "guard", "walk"):
                distinct = len({f.tobytes() for f in frames})
                assert distinct >= max(3, count // 2), \
                    "%s/%s is static (%d distinct of %d)" % (slug, kind, distinct, count)
        print("%-18s %2d frames  (%s)" % (slug, made, origin))

    print("\n%d from real sprites, %d from block-ins" % (real, blocked))
    if blocked:
        print("Re-run this script after fetch_rotations.py to replace the block-ins;")
        print("no resource, id or test changes when you do.")


if __name__ == "__main__":
    main()
