# -*- coding: utf-8 -*-
"""Downloads the per-SKILL attack clips and points the moves at them.

A rival's attack_dir is the swing it uses for everything. That is fine for a
rival with one move and poor for the two that carry a fight: the boss has three
skills and the Ogre has three, and every one of them played the same animation.

The engine already supports this -- _body_swing() prefers the move's own
attack_dir and falls back to the rival's shared clip -- so nothing here needs
new code, only assets and a pointer on each EnemyMove.

Same crop-and-repaste contract as fetch_attacks.py: generation ran on the
rival's opaque bounds, so each frame goes back at exactly the offset it was cut
from or the character leaves its floor line.
"""
import json
import os
import time
import urllib.request
from io import BytesIO

from PIL import Image

OUT = "assets/images/characters"
REFS = "tools/chapter2/attack_refs"
MOVES = "data/moves"
UA = {"User-Agent": "Mozilla/5.0"}
FRAMES = 9
URL = "https://api.pixellab.ai/mcp/images/%s/download?index=%d"

# (move file stem, rival slug whose canvas it was generated on, job id)
JOBS = [
    ("plunder_supremo",  "don_eraptado",   "81154c0d-c70d-45e4-aeb5-4e4c96f03300"),
    ("jueteng_jackpot",  "don_eraptado",   "5efec3f3-1c6a-48a4-9028-cef47000e6af"),
    ("citation_cannon",  "ordinance_ogre", "852a3dcd-2f60-4ee8-8807-cf85665855e5"),
    ("queue_skip_kick",  "fixer_fredo",    "a21841ca-72c1-4410-abc3-ad23fac8a58c"),
]


def grab(job, index, tries=4):
    for attempt in range(tries):
        try:
            req = urllib.request.Request(URL % (job, index), headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                return Image.open(BytesIO(r.read())).convert("RGBA")
        except Exception:
            if attempt == tries - 1:
                raise
            time.sleep(6 * (attempt + 1))


def main():
    manifest = json.load(open(f"{REFS}/manifest.json"))
    for move, slug, job in JOBS:
        meta = manifest[slug]
        canvas, box = tuple(meta["canvas"]), tuple(meta["box"])
        folder = f"{OUT}/{slug}_move_{move}"
        os.makedirs(folder, exist_ok=True)

        for i in range(FRAMES):
            frame = grab(job, i)
            full = Image.new("RGBA", canvas, (0, 0, 0, 0))
            full.paste(frame, (box[0], box[1]))
            full.save(f"{folder}/frame_{i}.png")

        # Point the move at its own clip.
        path = f"{MOVES}/{move}.tres"
        src = open(path, encoding="utf-8").read()
        lines, seen_dir, seen_count = [], False, False
        for line in src.split("\n"):
            if line.startswith("attack_dir = "):
                lines.append(f'attack_dir = "res://{folder}"')
                seen_dir = True
            elif line.startswith("attack_count = "):
                lines.append(f"attack_count = {FRAMES}")
                seen_count = True
            else:
                lines.append(line)
        if not seen_dir:
            # Append into the [resource] block rather than the header.
            for i, l in enumerate(lines):
                if l.startswith("move_id = "):
                    lines.insert(i + 1, f'attack_dir = "res://{folder}"')
                    lines.insert(i + 2, f"attack_count = {FRAMES}")
                    break
        elif not seen_count:
            raise SystemExit(f"{move}: attack_dir without attack_count")
        open(path, "w", encoding="utf-8").write("\n".join(lines))
        print(f"  {move:18} -> {folder}")


main()
