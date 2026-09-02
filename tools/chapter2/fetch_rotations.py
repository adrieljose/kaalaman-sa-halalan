# -*- coding: utf-8 -*-
"""Pulls the 3/4 facing rotation for every Chapter 2 rival.

The rivals were drawn facing the CAMERA, and the player they are fighting
stands on their left. So every fight has had two characters looking past each
other -- the one thing in the battle that reads as wrong at a glance no matter
how good the animation on top of it is.

south-west is the 3/4 that faces viewer-LEFT, which is where the player stands.
Not `west`: that is near profile, and it loses the face, which is most of each
rival's identity.

Alignment is by FEET, not by canvas. The rotation comes back on its own tight
canvas at a slightly different size from the source (a turned body is a
different width), so pasting at the old crop origin would leave the character
hovering or sunk. The battle scene's whole grounding contract is that the feet
sit on one line, so the feet are what gets matched.
"""
import json
import os
import time
import urllib.request
from io import BytesIO

from PIL import Image

OUT = "assets/images/characters"
REFS = "tools/chapter2/attack_refs"
UA = {"User-Agent": "Mozilla/5.0"}
FACING = "south-west"

CHARS = {
    "fixer_fredo":    "352e4369-beb6-42eb-a2e0-a58da19e8428",
    "clerk_kurakot":  "5289b7d0-efda-4707-be3b-66a2d6527a37",
    "permit_peke":    "3b824598-370b-430b-9846-d5a98dfc4fe6",
    "notaryo_naku":   "b82bb032-43ac-4e09-befe-09d87fa21bc9",
    "cashier_kaltas": "9af51577-0f85-49ab-b5b3-2fb21f690af5",
    "budget_bandido": "4df5895b-2075-4875-8938-6dd2b0391c03",
    "bidding_bandit": "ee023b98-7cc3-4baf-a7c0-464d21049bc8",
    "ordinance_ogre": "9e342407-07d7-4fe7-bc7b-20fb3b427445",
    "don_eraptado":   "1036f798-98b2-4441-bccd-3323e626c3fe",
}
ACCOUNT = "fe45ca41-1d97-42aa-9437-18d24b561824"
URL = ("https://backblaze.pixellab.ai/file/pixellab-characters/"
       "%s/%s/rotations/%s.png")


def grab(char_id, direction, tries=5):
    for attempt in range(tries):
        try:
            req = urllib.request.Request(URL % (ACCOUNT, char_id, direction),
                                         headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                return Image.open(BytesIO(r.read())).convert("RGBA")
        except Exception as exc:
            if attempt == tries - 1:
                raise SystemExit(f"{char_id} {direction}: {exc}")
            time.sleep(8 * (attempt + 1))


def place(rot, canvas, box):
    """Puts the rotated sprite on the original canvas, feet on the old line.

    Horizontally centred on the source's own centre so the character does not
    drift sideways between clips; vertically anchored so the LOWEST opaque row
    lands on the source's lowest opaque row, which is the floor line.
    """
    bb = rot.getchannel("A").getbbox()
    rot = rot.crop(bb)
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    cx = (box[0] + box[2]) // 2
    x = cx - rot.width // 2
    y = box[3] - rot.height
    # Never let a wider turned body push off the canvas.
    x = max(0, min(x, canvas[0] - rot.width))
    out.paste(rot, (x, y))
    return out, (x, y, rot.width, rot.height)


def main():
    manifest = json.load(open(f"{REFS}/manifest.json"))
    placed = {}
    for slug, char_id in CHARS.items():
        meta = manifest[slug]
        canvas, box = tuple(meta["canvas"]), tuple(meta["box"])
        rot = grab(char_id, FACING)
        out, where = place(rot, canvas, box)

        folder = f"{OUT}/{slug}_rot34"
        os.makedirs(folder, exist_ok=True)
        out.save(f"{folder}/{FACING}.png")
        placed[slug] = {"char_id": char_id, "raw": list(rot.size), "at": list(where),
                        "canvas": list(canvas)}
        print(f"  {slug:16} rotation {rot.size[0]}x{rot.size[1]} "
              f"-> canvas {canvas[0]}x{canvas[1]} at {where[0]},{where[1]}")

    json.dump(placed, open(f"{REFS}/rotations.json", "w"), indent=2)
    print(f"\n{len(placed)} rotations saved")


main()
