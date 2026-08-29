# -*- coding: utf-8 -*-
"""Builds 3/4 battle clips for the rivals AND for Juan and Maria.

Everyone in the battle used to be drawn front-on, looking at the camera. The
first fix pulled the rivals' `west` rotation, which faced the right way but was
a flat profile -- one eye, no shoulder line, props edge-on.

These come from `create_character(mode="v3", reference_image_*)`, which rotates
a sprite you ALREADY HAVE into eight directions rather than inventing a new
character. The reference defines identity, so this is a repose, not a redesign:
the same cap, lanyard, briefcase and law book come back, turned.

Two of the eight directions are the ones that matter:

    south-west   a rival's 3/4 facing LEFT, toward the player
    south-east   the player's 3/4 facing RIGHT, toward the rival

Both keep the face, both eyes, the shoulder line and the props readable, which
is what a flat profile costs you.

Motion is layered on rather than generated, because the game already supplies
most of it: the skill choreography does the travel and follow-through in
tweens, and IdlePersonality supplies each rival's breathing and sway. So the
clips only add POSE -- a body leaning into a strike, recoiling from a hit --
by shearing the sprite in bands about the hips, at whole-pixel offsets so
nothing is resampled.
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))
POSES = os.path.join(ROOT, "rot34", "picked")
CHARS = r"D:\klhgamefinal\assets\images\characters"

# slug -> (output prefix, forward direction in x)
# The player stands LEFT and attacks rightward; a rival stands RIGHT and
# attacks leftward. Everything below is written in terms of "forward", so the
# two only differ by this sign.
TARGETS = {
    "fixer_fredo":    ("fixer_fredo",        -1),
    "clerk_kurakot":  ("clerk_kurakot",      -1),
    "permit_peke":    ("permit_peke",        -1),
    "notaryo_naku":   ("notaryo_naku",       -1),
    "cashier_kaltas": ("cashier_kaltas",     -1),
    "budget_bandido": ("budget_bandido",     -1),
    "bidding_bandit": ("bidding_bandit",     -1),
    "ordinance_ogre": ("ordinance_ogre",     -1),
    "don_eraptado":   ("don_eraptado",       -1),
    "juan":           ("player",             +1),
    "maria":          ("player_female",      +1),
}

PAD = 26
# Every clip lands on a canvas this tall with the feet at FOOT_Y, matching the
# 180-tall convention the rest of the game's sprites already use.
#
# It is not cosmetic. The character TextureRects use KEEP_ASPECT_CENTERED, so a
# shorter canvas is scaled UP to fill the node -- a rival cropped to 132px would
# have rendered noticeably larger than one cropped to 171px, purely because of
# how tightly its source happened to crop. Padding to a common height instead of
# scaling keeps each character's TRUE pixel height, so the Ogre still towers
# over Fredo for the right reason.
CANVAS_H = 180
FOOT_Y = 172


def lean(im, amount, pivot=0.62):
    """Tilt about the hips by shifting rows, the crown moving furthest.

    A flat translation reads as the sprite sliding. Shifting upper rows further
    than lower ones reads as a body putting its weight in, and rows below the
    pivot barely move so the feet stay planted.
    """
    if amount == 0:
        return im
    w, h = im.size
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    hip = int(h * pivot)
    for y in range(h):
        row = im.crop((0, y, w, y + 1))
        t = 0.0 if y >= hip else (hip - y) / float(hip)
        out.paste(row, (int(round(amount * t)), y), row)
    return out


def shifted(im, dx, dy=0):
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im, (dx, dy), im)
    return out


def flashed(im, amount):
    if amount <= 0:
        return im
    r, g, b, a = im.split()
    white = Image.new("L", im.size, 255)
    mix = lambda ch: Image.blend(ch, white, amount)
    return Image.merge("RGBA", (mix(r), mix(g), mix(b), a))


def padded(im):
    out = Image.new("RGBA", (im.width + PAD * 2, im.height), (0, 0, 0, 0))
    out.paste(im, (PAD, 0), im)
    return out


def idle_frames(base, fwd):
    """A shallow breath. Small on purpose -- IdlePersonality adds each
    character's own breathing and sway on top of these at runtime."""
    return [base,
            shifted(lean(base, fwd * 1), 0, -1),
            base,
            shifted(lean(base, -fwd * 1), 0, 1)]


def attack_frames(base, fwd):
    """Coil away, drive in, hold the blow, settle. The deepest lean is the
    frame the skill lands on, so the body is at full commitment exactly when
    the impact fires."""
    return [
        base,
        shifted(lean(base, -fwd * 4), -fwd * 2, 1),
        shifted(lean(base, fwd * 7), fwd * 4, 0),
        shifted(lean(base, fwd * 11), fwd * 8, 1),
        shifted(lean(base, fwd * 6), fwd * 3, 0),
        base,
    ]


def hit_frames(base, fwd):
    """Driven back away from whoever hit them, flashing on the first frames."""
    back = -fwd
    return [
        flashed(shifted(lean(base, back * 6), back * 3), 0.30),
        flashed(shifted(lean(base, back * 9), back * 6, -1), 0.16),
        shifted(lean(base, back * 7), back * 6, 1),
        shifted(lean(base, back * 4), back * 3),
        shifted(lean(base, back * 2), back * 1),
        base,
    ]


def write(prefix, name, frames, box):
    out_dir = os.path.join(CHARS, "%s_battle_%s" % (prefix, name))
    os.makedirs(out_dir, exist_ok=True)
    for old in os.listdir(out_dir):
        if old.endswith(".png") or old.endswith(".png.import"):
            os.remove(os.path.join(out_dir, old))
    for i, im in enumerate(frames):
        im.crop(box).save(os.path.join(out_dir, "frame_%d.png" % i))
    return len(frames)


def build(slug, prefix, fwd):
    src = Image.open(os.path.join(POSES, slug + ".png")).convert("RGBA")
    bb = src.getbbox()
    if bb:
        src = src.crop(bb)
    if src.height > FOOT_Y:
        raise SystemExit("%s is %dpx tall, taller than FOOT_Y" % (slug, src.height))
    stood = Image.new("RGBA", (src.width, CANVAS_H), (0, 0, 0, 0))
    stood.paste(src, (0, FOOT_Y - src.height), src)
    base = padded(stood)

    clips = {"idle": idle_frames(base, fwd),
             "attack": attack_frames(base, fwd),
             "hit": hit_frames(base, fwd)}

    # ONE crop box across all three clips, or the character jumps the moment
    # battle switches between them.
    boxes = [im.getbbox() for fs in clips.values() for im in fs
             if im.getbbox() is not None]
    x0 = max(0, min(b[0] for b in boxes) - 2)
    x1 = min(base.width, max(b[2] for b in boxes) + 2)
    box = (x0, 0, x1, base.height)

    counts = {n: write(prefix, n, fs, box) for n, fs in clips.items()}
    return counts, (x1 - x0, base.height)


if __name__ == "__main__":
    for slug, (prefix, fwd) in TARGETS.items():
        counts, size = build(slug, prefix, fwd)
        print("%-16s -> %-14s %3dx%-3d  %s" % (
            slug, prefix, size[0], size[1],
            "  ".join("%s=%d" % kv for kv in sorted(counts.items()))))
