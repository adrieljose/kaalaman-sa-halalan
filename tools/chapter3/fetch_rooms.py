# -*- coding: utf-8 -*-
"""Downloads a generated room and audits the line the fighters stand on.

    python tools/chapter3/fetch_rooms.py <key> <job_id>
    python tools/chapter3/fetch_rooms.py --audit <key>

The audit is the point. A room can be beautiful and still be unusable, because
the battle scene stands both fighters at 91.25% of the image height and Chapter
2 lost three rooms to exactly that: the session hall, the bidding room and the
service lobby all had furniture where the feet land, and every one had to be
repainted afterwards.

So this measures the strip the feet actually occupy rather than trusting a
glance at a 384px picture. It reports, for the left foot, the centre and the
right foot:

  the colour under the foot, how far it is from the floor colour sampled at
  centre-bottom, and whether that patch is DARK relative to the floor -- which
  is what a chair back, a truck, a planter or a hedge looks like from here.

A flag is not a verdict. It says "look at this patch", and the picture decides.
"""
import os
import sys
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BG_DIR = os.path.join(ROOT, "assets", "images", "backgrounds")

GROUND_FRACTION = 0.9125
# Where the fighters' feet land in a 384-wide room, measured off Chapter 2's
# own staging (see tools/chapter2/widen_aisle.py, which quotes 75 and 310).
FOOT_X = {"left foot": 75, "right foot": 310}
PATCH = 22          # half-width of the patch a foot occupies
BAND = 10           # how many rows up from the ground line to average


def download(key, job_id):
    url = "https://api.pixellab.ai/mcp/images/%s/download" % job_id
    dst = os.path.join(BG_DIR, "%s.png" % key)
    with urllib.request.urlopen(url) as r:
        data = r.read()
    with open(dst, "wb") as f:
        f.write(data)
    img = Image.open(dst)
    print("saved %s  %dx%d  %s" % (dst, img.width, img.height, img.mode))
    return dst


def patch_mean(img, cx, cy):
    px = img.convert("RGB").load()
    xs = range(max(0, cx - PATCH), min(img.width, cx + PATCH))
    ys = range(max(0, cy - BAND), min(img.height, cy + BAND))
    n = 0
    acc = [0, 0, 0]
    for x in xs:
        for y in ys:
            r, g, b = px[x, y]
            acc[0] += r
            acc[1] += g
            acc[2] += b
            n += 1
    return tuple(v // max(n, 1) for v in acc)


def luma(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def audit(key):
    path = os.path.join(BG_DIR, "%s.png" % key)
    img = Image.open(path)
    ground = int(img.height * GROUND_FRACTION)
    print("%s  %dx%d  ground line y=%d" % (key, img.width, img.height, ground))

    # The reference is the floor at dead centre-bottom, BELOW the ground line:
    # that strip is nearest the camera and is floor in every composition.
    floor = patch_mean(img, img.width // 2, min(img.height - 4, ground + 12))
    print("  floor reference %s  luma %.0f" % (floor, luma(floor)))

    flagged = []
    for label, x in FOOT_X.items():
        c = patch_mean(img, x, ground)
        d = max(abs(c[i] - floor[i]) for i in range(3))
        rel = luma(c) - luma(floor)
        note = ""
        # Darker than the floor by a clear margin is the signature of something
        # standing where the fighter should be.
        if rel < -28:
            note = "  <-- DARK, something is probably there"
            flagged.append(label)
        elif d > 70:
            note = "  <-- differs sharply from the floor"
            flagged.append(label)
        print("  %-11s x=%-4d %s  dist %-3d  luma %+.0f%s" % (label, x, c, d, rel, note))

    if flagged:
        print("  CHECK: %s" % ", ".join(flagged))
    else:
        print("  ground line reads as clear floor at both feet")
    return not flagged


if __name__ == "__main__":
    args = sys.argv[1:]
    if args and args[0] == "--audit":
        audit(args[1])
    else:
        key, job_id = args[0], args[1]
        download(key, job_id)
        audit(key)
