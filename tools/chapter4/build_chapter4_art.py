# -*- coding: utf-8 -*-
"""Turns each reposed Chapter 4 sprite into the frame sets the game plays.

    python tools/chapter4/build_chapter4_art.py

For every character this writes six clips into
assets/images/characters/chapter4/<slug>_<clip>/frame_N.png --

    idle 8, attack 12, attack2 12, guard 10, hit 8, walk 10

and a 96x96 portrait into assets/images/portraits/enemy_<slug>.png.

WHY WARP RATHER THAN GENERATE
    The brief asks for arms, hands, legs, feet, torso, head and props to move,
    and forbids sliding a rigid sprite. Generating 60 hand-drawn frames per
    character is far beyond the generation budget, so the same technique
    Chapter 3 used is applied: a thin-plate-spline deformation driven by a
    thirteen-point skeleton. Each joint gets its own target per frame, the
    soles are pinned during grounded strikes, and the canvas corners are
    anchored so the deformation cannot drag the margins inward. The result is
    a body that bends at the shoulder, elbow, hip and knee -- not a picture
    being pushed across the screen.

WHERE THE SKELETON COMES FROM
    Chapter 3 hand-authored thirteen landmarks per villain. That does not scale
    and it is easy to get quietly wrong, so here the skeleton is measured from
    the sprite itself: the alpha silhouette gives the head top, the sole line
    and the body's mid-line, and the limb joints are placed at human
    proportions of that measured height, pushed out to the silhouette's own
    left and right extremes at each band. It is approximate by construction --
    which is why the build also writes a landmark overlay per character, so a
    skeleton that has landed in the wrong place is visible rather than
    something to be discovered later in an animation.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy.interpolate import RBFInterpolator

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "chapter4"))
import spec  # noqa: E402

ROT = os.path.join(ROOT, "output", "chapter4_villains", "rot")
ART = os.path.join(ROOT, "assets", "images", "characters", "chapter4")
PORTRAITS = os.path.join(ROOT, "assets", "images", "portraits")
CHECK = os.path.join(ROOT, "output", "chapter4_villains", "rig")

# The canvas Chapter 3's rivals live on, so Chapter 4 stages identically and
# AnimatedCharacter.body_rect keeps behaving the same way.
SIZE = (256, 320)
BODY_H = 270            # drawn height inside that canvas
SOLE_Y = 310            # where the feet sit, leaving a little air below
CLIPS = [("idle", 8), ("attack", 12), ("attack2", 12),
         ("guard", 10), ("hit", 8), ("walk", 10)]

# Joint order, matching Chapter 3's rig so articulated() is unchanged:
# head, chest, hips, near shoulder/elbow/hand, far shoulder/elbow/hand,
# near knee/foot, far knee/foot.
HEAD, CHEST, HIPS = 0, 1, 2
NEAR_SH, NEAR_EL, NEAR_HAND = 3, 4, 5
FAR_SH, FAR_EL, FAR_HAND = 6, 7, 8
NEAR_KNEE, NEAR_FOOT, FAR_KNEE, FAR_FOOT = 9, 10, 11, 12

# Fractions of the drawn body height, measured from the top of the head.
BANDS = {HEAD: 0.09, CHEST: 0.33, HIPS: 0.53,
         NEAR_SH: 0.24, NEAR_EL: 0.38, NEAR_HAND: 0.50,
         FAR_SH: 0.24, FAR_EL: 0.38, FAR_HAND: 0.50,
         NEAR_KNEE: 0.72, NEAR_FOOT: 0.97,
         FAR_KNEE: 0.72, FAR_FOOT: 0.97}


def place(image):
    """Scales the sprite onto the shared canvas and stands it on SOLE_Y."""
    box = image.getbbox()
    crop = image.crop(box)
    scale = min((SIZE[0] - 40) / crop.width, BODY_H / crop.height)
    width, height = max(1, round(crop.width * scale)), max(1, round(crop.height * scale))
    canvas = Image.new("RGBA", SIZE)
    origin = ((SIZE[0] - width) // 2, SOLE_Y - height)
    canvas.alpha_composite(crop.resize((width, height), Image.Resampling.NEAREST), origin)
    return canvas


def skeleton(canvas):
    """Measures a thirteen-point rig off the sprite's own silhouette."""
    alpha = np.asarray(canvas.getchannel("A")) > 127
    rows = np.where(alpha.any(1))[0]
    top, bottom = rows[0], rows[-1]
    height = max(1, bottom - top)

    def extents(fraction, span=0.05):
        """Left, right and centre of the silhouette in a horizontal band."""
        lo = int(top + max(0.0, fraction - span) * height)
        hi = int(top + min(1.0, fraction + span) * height)
        band = alpha[lo:hi + 1]
        columns = np.where(band.any(0))[0]
        if columns.size == 0:
            columns = np.where(alpha.any(0))[0]
        return columns[0], columns[-1], (columns[0] + columns[-1]) / 2.0

    points = np.zeros((13, 2), float)
    for joint, fraction in BANDS.items():
        left, right, centre = extents(fraction)
        y = top + fraction * height
        if joint in (HEAD, CHEST, HIPS):
            x = centre
        elif joint in (NEAR_SH, NEAR_EL, NEAR_HAND, NEAR_KNEE, NEAR_FOOT):
            # "Near" is the screen-left side: these rivals face screen-left, so
            # that is the arm and leg the player sees lead.
            x = left + (centre - left) * (0.25 if joint in (NEAR_SH, NEAR_KNEE) else 0.05)
        else:
            x = right - (right - centre) * (0.25 if joint in (FAR_SH, FAR_KNEE) else 0.05)
        points[joint] = (x, y)

    # The held prop rides with whichever hand is nearer the silhouette edge.
    left, right, _ = extents(BANDS[NEAR_HAND])
    prop = np.array([left + 4.0, top + BANDS[NEAR_HAND] * height])
    return points, prop


def articulated(frame, points, prop, kind, phase):
    """Chapter 3's deformation, unchanged in shape: one target per joint."""
    p = points.copy()
    dst = p.copy()
    pulse = math.sin(math.pi * phase)
    if kind in ("attack", "attack2"):
        drive = float(np.interp(phase, [0, .24, .48, .62, .80, 1], [0, -.45, 1, .9, .25, 0]))
        power = 1.0 if kind == "attack" else 1.2
        active = NEAR_HAND if kind == "attack" else FAR_HAND
        shoulder = NEAR_SH if kind == "attack" else FAR_SH
        elbow = NEAR_EL if kind == "attack" else FAR_EL
        angle = drive * power * (-.19 if kind == "attack" else .24)
        c, s = math.cos(angle), math.sin(angle)
        rot = np.array([[c, -s], [s, c]])
        shift = np.array([-9 * drive * power, 3 * pulse])
        dst[:9] += shift
        dst[CHEST] = p[CHEST] + [-3 * drive, 3 * pulse]
        for joint in (elbow, active):
            dst[joint] = p[shoulder] + rot @ (p[joint] - p[shoulder]) + shift + [-7 * drive, -3 * drive]
        dst[HEAD] += [-2 * drive, -2 * pulse]
        dst[NEAR_KNEE] += [-4 * drive, 2 * pulse]
        dst[FAR_KNEE] += [2 * drive, 2 * pulse]
    elif kind == "guard":
        dst[:9] += [3 * pulse, 5 * pulse]
        dst[CHEST] += [0, 3 * pulse]
        dst[NEAR_HAND] += [7 * pulse, -8 * pulse]
        dst[FAR_HAND] += [-6 * pulse, -9 * pulse]
        dst[NEAR_KNEE] += [-3 * pulse, 2 * pulse]
        dst[FAR_KNEE] += [3 * pulse, 2 * pulse]
    elif kind == "hit":
        dst[:9] += [7 * pulse, 3 * pulse]
        dst[HEAD] += [3 * pulse, -3 * pulse]
        dst[NEAR_HAND] += [-2 * pulse, -3 * pulse]
        dst[FAR_HAND] += [4 * pulse, -2 * pulse]
        dst[CHEST] += [2 * pulse, 2 * pulse]
    elif kind == "walk":
        a = math.sin(phase * 2 * math.pi)
        b = abs(a)
        dst[:9] += [0, -2 * b]
        dst[NEAR_HAND] += [-4 * a, 0]
        dst[FAR_HAND] += [4 * a, 0]
        dst[NEAR_KNEE] += [-5 * a, -3 * b]
        dst[FAR_KNEE] += [5 * a, -3 * b]
        dst[NEAR_FOOT] += [-6 * a, -max(0, a) * 4]
        dst[FAR_FOOT] += [6 * a, -max(0, -a) * 4]
    else:
        a = math.sin(phase * 2 * math.pi)
        dst[:9] += [0, -1.5 * a]
        dst[HEAD] += [0, -.5 * a]
        dst[NEAR_HAND] += [.6 * a, 0]
        dst[FAR_HAND] += [-.6 * a, 0]

    hand = NEAR_HAND if np.linalg.norm(prop - p[NEAR_HAND]) < np.linalg.norm(prop - p[FAR_HAND]) else FAR_HAND
    prop_dst = prop + (dst[hand] - p[hand])
    edges = np.array([(0, 0), (128, 0), (255, 0), (0, 160), (255, 160),
                      (0, 319), (128, 319), (255, 319)], float)
    src = np.vstack((p, prop, edges))
    target = np.vstack((dst, prop_dst, edges))
    inverse = RBFInterpolator(target, src - target, kernel="thin_plate_spline", smoothing=1.0)
    yy, xx = np.mgrid[:SIZE[1], :SIZE[0]]
    grid = np.column_stack((xx.ravel(), yy.ravel())).astype(float)
    mapped = np.rint(grid + inverse(grid)).astype(int)
    mapped[:, 0] = mapped[:, 0].clip(0, SIZE[0] - 1)
    mapped[:, 1] = mapped[:, 1].clip(0, SIZE[1] - 1)
    pixels = np.asarray(frame)[mapped[:, 1], mapped[:, 0]].reshape((SIZE[1], SIZE[0], 4))
    return Image.fromarray(pixels)


def overlay(canvas, points, prop):
    """A picture of where the measured rig landed, for eyeballing."""
    sheet = Image.new("RGBA", SIZE, (22, 26, 34, 255))
    sheet.alpha_composite(canvas)
    draw = ImageDraw.Draw(sheet)
    bones = [(HEAD, CHEST), (CHEST, HIPS), (CHEST, NEAR_SH), (CHEST, FAR_SH),
             (NEAR_SH, NEAR_EL), (NEAR_EL, NEAR_HAND), (FAR_SH, FAR_EL),
             (FAR_EL, FAR_HAND), (HIPS, NEAR_KNEE), (NEAR_KNEE, NEAR_FOOT),
             (HIPS, FAR_KNEE), (FAR_KNEE, FAR_FOOT)]
    for a, b in bones:
        draw.line([tuple(points[a]), tuple(points[b])], fill=(90, 220, 255, 220), width=1)
    for x, y in points:
        draw.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(255, 210, 90, 255))
    draw.ellipse([prop[0] - 3, prop[1] - 3, prop[0] + 3, prop[1] + 3],
                 outline=(255, 90, 140, 255))
    return sheet


def main():
    os.makedirs(CHECK, exist_ok=True)
    os.makedirs(PORTRAITS, exist_ok=True)
    for entry in spec.all_entries():
        slug = entry["slug"]
        source = os.path.join(ROT, slug, "south-west.png")
        canvas = place(Image.open(source).convert("RGBA"))
        points, prop = skeleton(canvas)
        overlay(canvas, points, prop).convert("RGB").save(
            os.path.join(CHECK, slug + "_rig.png"))

        # Portrait: the head band, squared off and scaled to the HUD size.
        hx, hy = points[HEAD]
        half = 46
        head = canvas.crop((int(hx - half), int(hy - half),
                            int(hx + half), int(hy + half)))
        head.resize((96, 96), Image.Resampling.NEAREST).save(
            os.path.join(PORTRAITS, "enemy_%s.png" % slug))

        made = 0
        for kind, count in CLIPS:
            folder = os.path.join(ART, "%s_%s" % (slug, kind))
            os.makedirs(folder, exist_ok=True)
            frames = []
            for index in range(count):
                phase = index / (count if kind in ("idle", "walk") else count - 1)
                image = articulated(canvas, points, prop, kind, phase)
                image.save(os.path.join(folder, "frame_%d.png" % index))
                frames.append(image)
                made += 1
            # A clip whose frames are nearly all identical is a still image
            # wearing an animation's name, which is the exact failure the
            # brief calls out. Motion clips must actually differ.
            if kind in ("attack", "attack2", "guard", "walk"):
                distinct = len({f.tobytes() for f in frames})
                assert distinct >= max(3, count // 2), \
                    "%s/%s is static (%d distinct of %d)" % (slug, kind, distinct, count)
        print("%-18s %2d frames, rig overlay written" % (slug, made))


if __name__ == "__main__":
    main()
