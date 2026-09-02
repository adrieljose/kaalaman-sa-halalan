# -*- coding: utf-8 -*-
"""Downloads the generated attack animations and puts them back on the sprite
canvas the battle scene expects.

The generation was run on a CROP of each rival -- the opaque bounds, so no
budget went on empty canvas -- which means every returned frame has to be
pasted back at exactly the offset it was cut from. That offset is the whole
job: paste it a few pixels out and the rival's feet leave the floor line the
shadows and the melee reach are both measured against.

Frame 0 of a result is the INPUT frame returned unchanged, so it is the idle
stance the swing grows out of. It is kept as the first frame of the clip: an
attack that starts from the pose the rival is already standing in has no jump
at the front of it.

Downloads need a browser User-Agent. The storage behind the API rejects
Python-urllib's default outright, which reads as a dead link rather than as a
refusal.
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
FRAMES = 9          # index 0 (the input) plus the 8 generated

# slug -> job id, in encounter order.
#
# Four of these are SECOND runs. The first pass encoded their references at
# 4-8 colours to fit the inline-base64 budget, and the model faithfully
# animated the flattened palette -- the Ogre came back 36 RGB levels off his
# own coat, which is a redesign, not an animation. Re-encoded at 16-32
# colours and regenerated; the brief is explicit that colours are preserved.
JOBS = {
    "fixer_fredo":    "91265167-a999-41f8-b522-0905914d6cdf",
    "clerk_kurakot":  "0ca0d31f-5205-41e0-a8c0-28bdba52cddd",
    "permit_peke":     "f64ad8e9-78d2-4475-87f5-4f92b436c72f",
    "notaryo_naku":   "96204efe-11a4-42fc-a818-643239c457f8",
    "cashier_kaltas":  "df2227cf-336c-4a63-9077-adc697ba6ada",
    "budget_bandido":  "43b333b3-1c85-41b7-b98b-a2d8c9f4a5bf",
    "bidding_bandit": "945a558b-913d-491b-a3b0-ba33a4f989ec",
    "ordinance_ogre":  "607ac6f2-7040-4e7c-a9a2-bdf8c951219a",
    "don_eraptado":   "4323c458-24c9-47e4-87be-48979dc7e643",
}
URL = "https://api.pixellab.ai/mcp/images/%s/download?index=%d"


def grab(job, index, tries=4):
    for attempt in range(tries):
        try:
            req = urllib.request.Request(URL % (job, index), headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                return Image.open(BytesIO(r.read())).convert("RGBA")
        except Exception as exc:
            # 423 means the job is still rendering; anything else is worth a
            # retry too, since one dropped frame ruins the whole clip.
            if attempt == tries - 1:
                raise
            time.sleep(6 * (attempt + 1))
    return None


def main():
    manifest = json.load(open(f"{REFS}/manifest.json"))
    report = []
    for slug, job in JOBS.items():
        meta = manifest[slug]
        canvas = tuple(meta["canvas"])
        box = tuple(meta["box"])
        folder = f"{OUT}/{slug}_battle_attack_v2"
        os.makedirs(folder, exist_ok=True)

        kept = 0
        prev = None
        moved = []
        for i in range(FRAMES):
            frame = grab(job, i)
            if frame.size != (box[2] - box[0], box[3] - box[1]):
                # The model is expected to hold the canvas; if it ever does not,
                # fitting it back by force would silently rescale the character.
                raise SystemExit(
                    f"{slug} frame {i}: got {frame.size}, expected "
                    f"{(box[2]-box[0], box[3]-box[1])}")
            full = Image.new("RGBA", canvas, (0, 0, 0, 0))
            full.paste(frame, (box[0], box[1]))
            full.save(f"{folder}/frame_{i}.png")
            kept += 1
            if prev is not None:
                diff = sum(1 for a, b in zip(prev.tobytes(), full.tobytes()) if a != b)
                moved.append(diff)
            prev = full

        report.append((slug, kept, sum(moved) // max(len(moved), 1)))
        print(f"  {slug:16} {kept} frames -> {folder}")

    print("\nper-frame change (bytes differing, higher = more motion):")
    for slug, n, m in report:
        print(f"  {slug:16} {m:8}")


main()
