# -*- coding: utf-8 -*-
"""Pulls each rival's 3/4-facing idle / attack / hit clips and installs them.

One zip per character rather than per-frame URLs: the API only hands out frame
URLs through get_character, whose reply is a wall of text meant for a reader,
and the download endpoint gives the same frames in one request. It returns
HTTP 423 while any of that character's jobs is still rendering, which is a
useful gate -- a character is only ever installed complete.

ALIGNMENT is the whole job. Three separate things have to agree or the fight
falls apart:

  * The clips arrive on the rotation's own tight canvas (44x152 for the
    Bandit), not the battle canvas (69x180). Pasting at 0,0 would sink every
    rival through the floor.
  * Within one clip the frames must not drift, or the character shivers.
  * Between clips the FEET must land on the same line, or the rival hops when
    it stops attacking.

So one offset is computed per character from its idle clip's first frame and
applied to every frame of every clip: horizontally centred on the source
sprite's centre, vertically anchored so the lowest opaque row sits on the
source's floor line. The relative motion the animator drew is preserved
because the same offset is used throughout.
"""
import io
import json
import os
import urllib.request
import zipfile

from PIL import Image

OUT = "assets/images/characters"
REFS = "tools/chapter2/attack_refs"
UA = {"User-Agent": "Mozilla/5.0"}
FACING = "south-west"
DL = "https://api.pixellab.ai/mcp/characters/%s/download"

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
# Which clip a zip folder belongs to, by the name given at generation time.
KINDS = ("idle", "attack", "hit")


def fetch_zip(char_id):
    req = urllib.request.Request(DL % char_id, headers=UA)
    with urllib.request.urlopen(req, timeout=180) as r:
        return zipfile.ZipFile(io.BytesIO(r.read()))


def frames_of(z, kind):
    """Every south-west frame of the clip whose folder name ends in `kind`."""
    hits = [n for n in z.namelist()
            if n.lower().endswith(".png")
            and FACING in n.replace("\\", "/")
            and ("_%s" % kind) in n.lower()
            and "rotation" not in n.lower()]

    def order(name):
        stem = os.path.splitext(os.path.basename(name))[0]
        return int(stem) if stem.isdigit() else 0

    return [z.read(n) for n in sorted(hits, key=order)]


def main():
    manifest = json.load(open(f"{REFS}/manifest.json"))
    report = []
    for slug, char_id in CHARS.items():
        meta = manifest[slug]
        canvas, box = tuple(meta["canvas"]), tuple(meta["box"])
        try:
            z = fetch_zip(char_id)
        except Exception as exc:
            print(f"  {slug:16} SKIPPED -- {exc}")
            continue

        clips = {k: frames_of(z, k) for k in KINDS}
        missing = [k for k, v in clips.items() if not v]
        if missing:
            print(f"  {slug:16} SKIPPED -- no frames for {missing}")
            continue

        # One offset for the character, taken from the idle's first frame.
        first = Image.open(io.BytesIO(clips["idle"][0])).convert("RGBA")
        bb = first.getchannel("A").getbbox()
        cx = (box[0] + box[2]) // 2
        dx = cx - (bb[0] + bb[2]) // 2
        dy = box[3] - bb[3]

        counts = {}
        for kind, blobs in clips.items():
            folder = f"{OUT}/{slug}_battle_{kind}_34"
            os.makedirs(folder, exist_ok=True)
            for i, blob in enumerate(blobs):
                src = Image.open(io.BytesIO(blob)).convert("RGBA")
                out = Image.new("RGBA", canvas, (0, 0, 0, 0))
                out.paste(src, (dx, dy))
                out.save(f"{folder}/frame_{i}.png")
            counts[kind] = len(blobs)
        report.append((slug, counts, (dx, dy)))
        print(f"  {slug:16} idle={counts['idle']} attack={counts['attack']} "
              f"hit={counts['hit']}  offset={dx},{dy}")

    print(f"\n{len(report)}/{len(CHARS)} rivals installed")
    return report


main()
