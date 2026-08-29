# -*- coding: utf-8 -*-
"""Builds 3/4 battle clips for the Chapter 1 rivals, and a 3/4 walk cycle.

Chapter 1 shipped before the pose work, so its five rivals still faced the
camera while the player -- converted with Chapter 2 -- faced them. That read as
one fighter confronting an opponent posing for a photograph.

Four of the five are rotated here. Senator Sabaw is deliberately left alone:
his original art is already drawn turned, shoulders angled and bowl extended
toward the player's side, and the trial budget ran out at exactly four.

Two things Chapter 2 never needed:

  * WALK. Chapter 2's rivals have no walk clip at all, so they fall back to the
    idle loop while closing for a melee attack. Lord Trapo, Ate Ayuda and both
    players DO have one, and leaving it alone would have snapped them back to
    the old front-facing art for the length of every approach -- the exact
    revert the pose work exists to prevent.
  * PER-MOVE ATTACKS. Lord Trapo is the only character whose moves override the
    attack clip (`dynasty_power` and `smear_campaign` each name their own
    folder), so those two need reposing as well or he turns to face the camera
    on his two signature moves.

Everything is layered on the one rotated still, at whole-pixel offsets, so
nothing is resampled and the art stays exactly as crisp as it arrived.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "chapter2"))
from make_battle_clips import (CANVAS_H, FOOT_Y, PAD, attack_frames, flashed,
                               hit_frames, idle_frames, lean, shifted)

ROOT = os.path.dirname(os.path.abspath(__file__))
POSES = os.path.join(ROOT, "rot34")
CHARS = r"D:\klhgamefinal\assets\images\characters"

# A rival stands on the RIGHT and attacks leftward, so forward is -1.
RIVALS = ["lord_trapo", "vote_vandal", "kapitan_komisyon", "ate_ayuda"]
FORWARD = -1

# Only these two rivals ever walk; the rest never had a walk clip.
WALKERS = {"lord_trapo", "ate_ayuda"}


def stride(im, amount, pivot=0.62):
    """Swing the legs by shifting rows BELOW the hips, the feet furthest.

    `lean` is the same idea inverted -- it moves the rows above the hips. Using
    both together is what separates a walk from a lean: the torso carries one
    way while the feet carry the other, which is what a stride actually is.
    """
    if amount == 0:
        return im
    w, h = im.size
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    hip = int(h * pivot)
    span = max(1, h - hip)
    for y in range(h):
        row = im.crop((0, y, w, y + 1))
        t = 0.0 if y < hip else (y - hip) / float(span)
        out.paste(row, (int(round(amount * t)), y), row)
    return out


def walk_frames(base, fwd):
    """An eight-frame march: two steps, the body bobbing on each.

    This is a synthesized cycle, not drawn limbs -- there is one still to work
    from, so the legs scissor as a sheared block rather than swinging
    independently. At the size it plays, over the half-second of a melee
    approach, it reads as walking; what it is really buying is that the
    character keeps facing the way it is travelling.
    """
    out = []
    for i in range(8):
        step = (1, 2, 1, 0, -1, -2, -1, 0)[i]        # feet fore and aft
        bob = (0, -1, -2, -1, 0, -1, -2, -1)[i]      # weight rising over each step
        im = stride(base, fwd * step * 3)
        im = lean(im, fwd * (2 - abs(step)))          # torso counters the legs
        out.append(shifted(im, 0, bob))
    return out


def slam_frames(base, fwd):
    """Lord Trapo's Dynasty Power: draw up tall, then bring it down.

    Deliberately unlike the generic attack -- this move's whole idea is
    inherited weight, so the wind-up rises instead of coiling back.
    """
    return [
        base,
        shifted(lean(base, -fwd * 2), 0, -2),
        shifted(lean(base, -fwd * 3), -fwd * 1, -3),
        shifted(lean(base, fwd * 9), fwd * 5, 2),
        shifted(lean(base, fwd * 7), fwd * 4, 1),
        base,
    ]


def spray_frames(base, fwd):
    """Lord Trapo's Smear Campaign: a fast throw, then a long settle.

    Seven frames because the move resource already declares seven; the extra
    two go into the recovery, so the follow-through is visibly slower than the
    flick that starts it.
    """
    return [
        base,
        shifted(lean(base, -fwd * 5), -fwd * 3, 1),
        shifted(lean(base, fwd * 10), fwd * 7, 0),
        shifted(lean(base, fwd * 12), fwd * 9, 1),
        shifted(lean(base, fwd * 8), fwd * 5, 0),
        shifted(lean(base, fwd * 4), fwd * 2, 0),
        base,
    ]


def padded(im):
    out = Image.new("RGBA", (im.width + PAD * 2, im.height), (0, 0, 0, 0))
    out.paste(im, (PAD, 0), im)
    return out


def stand(path):
    """Normalise a rotation onto the shared 180-tall canvas.

    Not cosmetic: the character TextureRects use KEEP_ASPECT_CENTERED, so a
    shorter canvas is scaled UP to fill the node, and a rival that happened to
    crop tighter would render larger than one that did not. Padding to a common
    height keeps each character's true pixel height.
    """
    src = Image.open(path).convert("RGBA")
    bb = src.getbbox()
    if bb:
        src = src.crop(bb)
    if src.height > FOOT_Y:
        raise SystemExit("%s is %dpx tall, taller than FOOT_Y" % (path, src.height))
    out = Image.new("RGBA", (src.width, CANVAS_H), (0, 0, 0, 0))
    out.paste(src, (0, FOOT_Y - src.height), src)
    return padded(out)


def write(folder, frames, box):
    out_dir = os.path.join(CHARS, folder)
    os.makedirs(out_dir, exist_ok=True)
    for old in os.listdir(out_dir):
        if old.endswith(".png") or old.endswith(".png.import"):
            os.remove(os.path.join(out_dir, old))
    for i, im in enumerate(frames):
        im.crop(box).save(os.path.join(out_dir, "frame_%d.png" % i))
    return len(frames)


def build(slug, base, fwd, extra=None):
    clips = {"idle": idle_frames(base, fwd),
             "attack": attack_frames(base, fwd),
             "hit": hit_frames(base, fwd)}
    clips.update(extra or {})

    # ONE crop box across every clip, or the character jumps the moment battle
    # switches between them.
    boxes = [im.getbbox() for fs in clips.values() for im in fs
             if im.getbbox() is not None]
    x0 = max(0, min(b[0] for b in boxes) - 2)
    x1 = min(base.width, max(b[2] for b in boxes) + 2)
    box = (x0, 0, x1, base.height)

    counts = {n: write("%s_battle_%s" % (slug, n), fs, box)
              for n, fs in clips.items()}
    return counts, (x1 - x0)


if __name__ == "__main__":
    for slug in RIVALS:
        base = stand(os.path.join(POSES, slug + ".png"))
        extra = {}
        if slug in WALKERS:
            extra["walk"] = walk_frames(base, FORWARD)
        if slug == "lord_trapo":
            extra["dynasty"] = slam_frames(base, FORWARD)
            extra["smear"] = spray_frames(base, FORWARD)
        counts, w = build(slug, base, FORWARD, extra)
        print("%-18s %3dx%-3d  %s" % (slug, w, CANVAS_H,
              "  ".join("%s=%d" % kv for kv in sorted(counts.items()))))
