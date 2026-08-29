# -*- coding: utf-8 -*-
"""Builds side-facing battle clips for the Chapter 2 rivals.

Every rival was standing front-on in battle, looking at the camera rather than
at the player. They were animated from their `south` rotation because that is
the one the importer happened to take -- but create_character produced FOUR
directions for each of them, and `west` is the same character, drawn by the
same model, in profile facing left. The player stands on the left of the
stage, so west is exactly the way a rival should be looking.

That matters more than it sounds: west is a genuine redraw, not the south
sprite mirrored. A mirrored front pose is still a front pose, and would have
left nine characters staring at the camera while appearing to fight.

Motion is layered on top rather than generated, because the game already
supplies most of it:

  * the skill choreography (_body_play) does the travel, the wind-up and the
    follow-through in tweens;
  * IdlePersonality gives each rival its own breathing, sway and lean at
    runtime.

So what these clips have to add is POSE -- a body that leans into a strike and
recoils from a hit. That is done by shearing the sprite in horizontal bands
about the hips, which is the same cut-out trick AnimatedCharacter.rig_enable
uses in-engine, applied offline. Every offset is a whole number of pixels, so
nothing is resampled and the pixel art stays exactly as crisp as it arrived.
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))
WEST = os.path.join(ROOT, "west")
CHARS = r"D:\klhgamefinal\assets\images\characters"

SLUGS = ["fixer_fredo", "clerk_kurakot", "permit_peke", "notaryo_naku",
         "cashier_kaltas", "budget_bandido", "bidding_bandit",
         "ordinance_ogre", "don_eraptado"]

# The player is to the LEFT, so "forward" for a rival is negative x.
FORWARD = -1
PAD = 26          # room for the lean and the knockback to move into


def lean(im, amount, pivot=0.62):
    """Tilt the body about the hips by shifting rows, top of the head most.

    A whole-body translation reads as the sprite sliding; shifting the upper
    rows progressively further reads as a figure leaning its weight in. Rows
    below the pivot barely move, which keeps the feet planted -- and planted
    feet are what make the lean look like a body rather than a slide.
    """
    if amount == 0:
        return im
    w, h = im.size
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    hip = int(h * pivot)
    for y in range(h):
        row = im.crop((0, y, w, y + 1))
        if y >= hip:
            t = 0.0
        else:
            t = (hip - y) / float(hip)     # 0 at the hips, 1 at the crown
        out.paste(row, (int(round(amount * t)), y), row)
    return out


def shifted(im, dx, dy=0):
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im, (dx, dy), im)
    return out


def flashed(im, amount):
    """Lift toward white for an impact frame, preserving alpha."""
    if amount <= 0:
        return im
    r, g, b, a = im.split()
    white = Image.new("L", im.size, 255)
    mix = lambda ch: Image.blend(ch, white, amount)
    return Image.merge("RGBA", (mix(r), mix(g), mix(b), a))


def padded(im):
    """Widen the canvas so a lean or a knockback cannot clip at the edge."""
    out = Image.new("RGBA", (im.width + PAD * 2, im.height), (0, 0, 0, 0))
    out.paste(im, (PAD, 0), im)
    return out


def idle_frames(base):
    """A shallow breath. Deliberately small: IdlePersonality adds each rival's
    own breathing, sway and lean on top of these at runtime, and doubling the
    motion made the bigger rivals look like they were bobbing at sea."""
    return [base,
            shifted(lean(base, FORWARD * 1), 0, -1),
            base,
            shifted(lean(base, -FORWARD * 1), 0, 1)]


def attack_frames(base):
    """Coil away, drive in, hold the blow, settle back to the stance.

    The frame the skill lands on is the deepest lean, so the sprite is at full
    commitment exactly when _fx_impact fires.
    """
    return [
        base,                                             # stance
        shifted(lean(base, -FORWARD * 4), 2, 1),          # anticipation
        shifted(lean(base, FORWARD * 7), FORWARD * 4, 0),  # drive
        shifted(lean(base, FORWARD * 11), FORWARD * 8, 1),  # impact
        shifted(lean(base, FORWARD * 6), FORWARD * 3, 0),  # follow-through
        base,                                             # recovery
    ]


def hit_frames(base):
    """Driven back and away from the player, flashing on the first frames."""
    back = -FORWARD
    return [
        flashed(shifted(lean(base, back * 6), back * 3), 0.30),
        flashed(shifted(lean(base, back * 9), back * 6, -1), 0.16),
        shifted(lean(base, back * 7), back * 6, 1),
        shifted(lean(base, back * 4), back * 3),
        shifted(lean(base, back * 2), back * 1),
        base,
    ]


def write(slug, name, frames, box):
    out_dir = os.path.join(CHARS, "%s_west_%s" % (slug, name))
    os.makedirs(out_dir, exist_ok=True)
    for old in os.listdir(out_dir):
        if old.endswith(".png") or old.endswith(".png.import"):
            os.remove(os.path.join(out_dir, old))
    for i, im in enumerate(frames):
        im.crop(box).save(os.path.join(out_dir, "frame_%d.png" % i))
    return len(frames)


def build(slug):
    src = Image.open(os.path.join(WEST, slug + ".png")).convert("RGBA")
    base = padded(src)

    clips = {"idle": idle_frames(base),
             "attack": attack_frames(base),
             "hit": hit_frames(base)}

    # ONE crop box across all three clips. Cropping per clip would make the
    # rival jump the moment the battle switched between them -- the same rule
    # the front-facing importer follows.
    boxes = [im.getbbox() for fs in clips.values() for im in fs
             if im.getbbox() is not None]
    x0 = max(0, min(b[0] for b in boxes) - 2)
    x1 = min(base.width, max(b[2] for b in boxes) + 2)
    box = (x0, 0, x1, base.height)

    return {name: write(slug, name, fs, box) for name, fs in clips.items()}, (x1 - x0)


if __name__ == "__main__":
    for slug in SLUGS:
        counts, width = build(slug)
        print("%-16s %3dx180  %s" % (slug, width,
              "  ".join("%s=%d" % kv for kv in sorted(counts.items()))))
