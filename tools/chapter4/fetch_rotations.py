# -*- coding: utf-8 -*-
"""Downloads the reposed Chapter 4 sprites and picks the battle-facing view.

    python tools/chapter4/fetch_rotations.py

Each character was rotated once by create_character(mode="v3"), which returns
all eight directions from that single job. This pulls them and keeps the one
the battle screen needs.

WHICH DIRECTION
    Rivals stand on the RIGHT of the stage and face the player on the left, so
    the wanted view is the three-quarter turn toward screen-left: `south-west`.
    `west` is kept beside it as the fallback, because the model does not turn
    every character equally hard -- on some sprites `south-west` comes back
    barely off frontal and `west` is the real three-quarter. Both arrive in the
    same job, so choosing between them costs nothing.

    Downloading is authenticated by the URL alone, but Backblaze rejects
    urllib's default User-Agent with a 403, so a browser one is sent. A 423
    means the rotation job has not finished yet.
"""
import io
import os
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "output", "chapter4_villains", "rot")
WANTED = ("south-west", "west", "south")

# character_id per slug, from the v3 repose jobs.
CHARACTERS = {
    "secretary_sipsip": "72874ad4-2174-4ebe-a971-207272975d1b",
    "protocol_porma": "e1887b06-fcc5-4262-99e6-55c1c520b153",
    "spox_spin": "5a8504ce-ae59-4fa0-b50a-b0786f239aba",
    "chief_utos": "8315f84f-0d66-4b3f-9904-11b6a3303fd4",
    "cabinet_konek": "22a37e00-9200-45b1-bdce-3f5d4d6b4725",
    "director_dikta": "e75359f1-f45c-4549-97b9-0e9e24a48496",
    "adviser_areglo": "a04d28a4-66a0-4e55-9783-74c857b9dfb6",
    "eo_ego": "0473360c-4488-4501-a1dc-405c15413ab1",
    "lolo_enrilegend": "16370331-dddd-48a4-9887-96b83cbb59fa",
}

# The per-rotation Backblaze links carry a signed ?t= token and a project id
# that is not derivable from the character id, so the zip endpoint is used
# instead: one authenticated request per character, every direction inside.
API = "https://api.pixellab.ai/mcp/characters/%s/download"
AGENT = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
         "(KHTML, like Gecko) Chrome/125.0 Safari/537.36")


def get(url):
    request = urllib.request.Request(url, headers={"User-Agent": AGENT})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


def main():
    pending = []
    for slug, character_id in CHARACTERS.items():
        try:
            blob = get(API % character_id)
        except Exception as error:                      # noqa: BLE001
            # 423 is the documented "still rendering" answer, not a failure.
            pending.append("%s: %s" % (slug, error))
            continue
        archive = zipfile.ZipFile(io.BytesIO(blob))
        inside = {os.path.basename(n): n for n in archive.namelist()
                  if n.endswith(".png")}
        folder = os.path.join(OUT, slug)
        os.makedirs(folder, exist_ok=True)
        saved = []
        for direction in WANTED:
            name = inside.get(direction + ".png")
            if name is None:
                continue
            open(os.path.join(folder, direction + ".png"), "wb").write(
                archive.read(name))
            saved.append(direction)
        print("%-18s %s" % (slug, ", ".join(saved) or "nothing"))
        if not saved:
            pending.append("%s: the archive held no wanted direction" % slug)

    if pending:
        print("\nnot ready:")
        for row in pending:
            print("   %s" % row)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
