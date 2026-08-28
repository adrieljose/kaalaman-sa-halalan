# -*- coding: utf-8 -*-
"""Turns PixelLab animation frames into the frame folders the game loads.

Input is `frames.json`, transcribed from get_character() output. Frame URLs are
fully determined by the character id, the animation group's own uuid, the
signed token and the frame count, so only those four are recorded rather than
six pasted URLs per clip:

    {"fixer_fredo": {"char": "<char-uuid>",
                     "clips": {"idle": ["<anim-uuid>", "<token>", 4], ...}}}

Two things matter for the result to look right in battle, and both are about
*consistency across frames*, not about any single frame:

  * One crop box per rival, not per frame. PixelLab returns a 180x180 canvas
    per frame with the figure roughly centred, so cropping each frame to its
    own content would make the character jitter between frames and jump
    between clips. We take the union of every opaque bounding box across all
    of the rival's clips and apply that one window everywhere.

  * The vertical window is left alone. AnimatedCharacter.body_rect() measures
    opaque pixels to stand a fighter on the floor line, so as long as every
    frame of a rival shares one canvas, the feet land in the same place.
"""
import io
import json
import os
import sys
import urllib.request

from PIL import Image

ROOT = r"D:\klhgamefinal\assets\images\characters"
PORTRAITS = r"D:\klhgamefinal\assets\images\portraits"
PAD = 4          # breathing room around the union box, in pixels
MIN_WIDTH = 96   # keeps a slim rival from ending up on a comically narrow canvas


ACCOUNT = "594552b7-4c6b-481a-9fb1-e15564f87e98"
FRAME_URL = ("https://backblaze.pixellab.ai/file/pixellab-characters/"
             "%(account)s/%(char)s/animations/%(anim)s/south/%(i)d.png?t=%(t)s")
ROT_URL = ("https://backblaze.pixellab.ai/file/pixellab-characters/"
           "%(account)s/%(char)s/rotations/%(dir)s.png?t=%(t)s")


def fetch(url):
    # Backblaze 403s the default "Python-urllib/3.x" agent; curl gets a 200 for
    # the same signed URL. Any ordinary browser agent is accepted.
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return Image.open(io.BytesIO(r.read())).convert("RGBA")


def clip_urls(char, anim, token, count):
    return [FRAME_URL % dict(account=ACCOUNT, char=char, anim=anim, t=token, i=i)
            for i in range(count)]


def rotation(char, token, facing):
    return fetch(ROT_URL % dict(account=ACCOUNT, char=char, t=token, dir=facing))


# --- synthesised clips ----------------------------------------------------
#
# The trial ran out mid-run, so some rivals have an idle but no attack or hit.
# Rather than leave those as flat placeholders next to real art -- which looks
# worse than placeholders throughout -- the missing clips are built from the
# rival's OWN generated frames.
#
# The attack uses the `west` rotation, which create_character returns for free
# and which faces left, toward the player: the rival turns out of its
# front-facing idle into profile, drives forward, and settles back. Every frame
# is real generated art; only the offsets are ours.
#
# Offsets are whole pixels on purpose. Translation is lossless on pixel art,
# where rotation and fractional scaling are not, so a synthesised frame stays
# as crisp as a generated one.

SHIFT = 9          # pixels per step of forward drive
KNOCKBACK = 9      # pixels the rival is driven back by a hit


def shifted(im, dx, dy=0):
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im, (dx, dy), im)
    return out


def flashed(im, amount):
    """Lift the frame toward white to read as an impact, keeping its alpha."""
    if amount <= 0:
        return im
    r, g, b, a = im.split()
    white = Image.new("L", im.size, 255)
    mix = lambda ch: Image.blend(ch, white, amount)
    return Image.merge("RGBA", (mix(r), mix(g), mix(b), a))


def synth_attack(front, profile):
    """Turn to face the player, drive in, settle back. The player is to the
    LEFT of the rival, so forward is negative x."""
    return [front,
            profile,
            shifted(profile, -SHIFT),
            shifted(profile, -SHIFT * 2, 1),
            shifted(profile, -SHIFT),
            front]


def synth_hit(front):
    """Driven back and away from the player, with a flash on the first frames."""
    return [flashed(shifted(front, KNOCKBACK // 2), 0.28),
            flashed(shifted(front, KNOCKBACK, -1), 0.16),
            shifted(front, KNOCKBACK, 1),
            shifted(front, KNOCKBACK // 2),
            shifted(front, 2),
            front]


def synth_idle(front):
    """A two-pixel breath. Enough to stop a rival reading as a static image."""
    return [front, shifted(front, 0, -1), front, shifted(front, 0, 1)]


def union(boxes):
    xs0, ys0, xs1, ys1 = zip(*boxes)
    return (min(xs0), min(ys0), max(xs1), max(ys1))


def import_rival(slug, clips, synth=None, char=None, rot_token=None):
    """clips: {"idle": [url, ...], ...}; synth: names to build rather than fetch.

    Synthesised clips are produced BEFORE the crop so they go through the same
    union box as the generated ones -- that is what keeps a rival's feet in one
    place when the battle scene switches between its clips.
    """
    loaded = {name: [fetch(u) for u in urls] for name, urls in clips.items()}

    for name in (synth or []):
        front = (loaded["idle"][0] if "idle" in loaded
                 else rotation(char, rot_token, "south"))
        if name == "attack":
            loaded[name] = synth_attack(front, rotation(char, rot_token, "west"))
        elif name == "hit":
            loaded[name] = synth_hit(front)
        elif name == "idle":
            loaded[name] = synth_idle(front)

    boxes = [im.getbbox() for frames in loaded.values() for im in frames
             if im.getbbox() is not None]
    if not boxes:
        raise SystemExit("%s: every frame came back fully transparent" % slug)
    x0, y0, x1, y1 = union(boxes)

    canvas_h = loaded[next(iter(loaded))][0].height
    x0 = max(0, x0 - PAD)
    x1 = min(loaded[next(iter(loaded))][0].width, x1 + PAD)
    if x1 - x0 < MIN_WIDTH:                       # widen symmetrically
        grow = (MIN_WIDTH - (x1 - x0)) // 2 + 1
        x0, x1 = max(0, x0 - grow), min(canvas_h, x1 + grow)

    written = {}
    for name, frames in loaded.items():
        out_dir = os.path.join(ROOT, "%s_gen_%s" % (slug, name))
        os.makedirs(out_dir, exist_ok=True)
        for old in os.listdir(out_dir):           # stale frames from a re-run
            if old.endswith(".png") or old.endswith(".png.import"):
                os.remove(os.path.join(out_dir, old))
        for i, im in enumerate(frames):
            im.crop((x0, 0, x1, canvas_h)).save(
                os.path.join(out_dir, "frame_%d.png" % i))
        written[name] = len(frames)

    # HUD portrait: a head-and-shoulders bust off the first idle frame, framed
    # to match Chapter 1's portraits (hair near the top edge, shoulders cut by
    # the bottom) rather than a tight face crop, which reads as a different set.
    idle0 = loaded.get("idle", [None])[0]
    if idle0 is not None:
        bb = idle0.getbbox()
        side = max(int((bb[3] - bb[1]) * 0.55), 48)
        cx = (bb[0] + bb[2]) // 2
        top = bb[1] - 4
        crop = idle0.crop((cx - side // 2, top, cx - side // 2 + side, top + side))
        os.makedirs(PORTRAITS, exist_ok=True)
        crop.resize((128, 128), Image.NEAREST).save(
            os.path.join(PORTRAITS, "enemy_%s.png" % slug))

    return written, (x1 - x0, canvas_h)


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else "frames.json"
    with open(src, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    for slug, entry in data.items():
        clips = {name: clip_urls(entry["char"], anim, token, count)
                 for name, (anim, token, count) in entry["clips"].items()}
        synth = entry.get("synth", [])
        counts, size = import_rival(slug, clips, synth,
                                    entry["char"], entry.get("rot"))
        tags = "  ".join("%s=%d%s" % (k, v, "*" if k in synth else "")
                         for k, v in sorted(counts.items()))
        print("%-16s %dx%d  %s" % (slug, size[0], size[1], tags))
    print("\n* = built from the rival's own frames, not generated")
