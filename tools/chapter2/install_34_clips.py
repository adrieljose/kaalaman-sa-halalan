# -*- coding: utf-8 -*-
"""Installs animate_image results onto the 3/4 battle canvas.

Every job in JOBS was generated from a rival's own `_battle_idle_34/frame_0`,
cropped to its opaque bounds. So the frames come back on that crop and go
straight back at the crop's origin -- which is what keeps the new clip on the
same floor line (176) and at the same horizontal centre as the idle, attack and
hit clips already installed. No re-alignment is needed or wanted: any offset
applied here would be a drift relative to the clips it has to sit beside.

`dest` is either a rival clip folder ("<slug>_battle_attack_34") or a per-skill
folder ("<slug>_move_<move_id>_34"); the caller decides which, and repointing
is a separate step so a bad clip can be inspected before anything uses it.
"""
import json
import os
import time
import urllib.request
from io import BytesIO

from PIL import Image

OUT = "assets/images/characters"
REFS = "tools/chapter2/refs34"
UA = {"User-Agent": "Mozilla/5.0"}
URL = "https://api.pixellab.ai/mcp/images/%s/download?index=%d"
FRAMES = 9          # index 0 is the input pose, then the 8 generated

# (slug, destination folder, job id)
JOBS = [
    ("cashier_kaltas", "cashier_kaltas_battle_attack_34",           "cc9671df-b606-461a-b070-8236aa534b56"),
    ("don_eraptado",   "don_eraptado_move_plunder_supremo_34",      "fafa3c4c-0c55-47c0-ac3d-214a6639543c"),
    ("don_eraptado",   "don_eraptado_move_jueteng_jackpot_34",      "6e9e1ee2-d6df-4038-a50e-39ee3a877c25"),
    ("don_eraptado",   "don_eraptado_move_executive_privilege_34",  "326a9a6b-1057-4531-9fc0-33499eab197a"),
    ("ordinance_ogre", "ordinance_ogre_move_citation_cannon_34",    "afe0c265-6653-4e1e-b4aa-23f507fd86a7"),
    ("ordinance_ogre", "ordinance_ogre_move_session_smash_34",      "e0fb0047-f8de-40ca-a3c7-7787570be6c8"),
    ("bidding_bandit", "bidding_bandit_move_bid_folder_fan_34",     "e65ea434-0ac8-4c5a-bdda-ff23779d87dc"),
    ("bidding_bandit", "bidding_bandit_move_contract_snare_34",     "4c707231-cf4b-411a-9c7e-4826a811c61a"),
    ("budget_bandido", "budget_bandido_move_coin_burst_34",         "06e78184-4b53-47f5-802d-a07632ecdaf3"),
    ("budget_bandido", "budget_bandido_move_deficit_drop_34",       "b54e6857-d688-4c1b-9c9f-9018c9b04cb4"),
    ("cashier_kaltas", "cashier_kaltas_move_coin_flick_34",         "3cd1fd5a-7719-4e43-b1ea-e7dd4c27a262"),
    ("cashier_kaltas", "cashier_kaltas_move_receipt_whip_34",       "ef3f3c30-a3c9-48fe-a1ad-e9849cd9d40a"),
    ("notaryo_naku",   "notaryo_naku_move_signature_slash_34",      "11321a29-330e-46fe-bb51-8614e45ce4c7"),
    ("notaryo_naku",   "notaryo_naku_move_seal_of_approval_34",     "67a11069-6c18-4c69-a857-882101878fe3"),
    ("permit_peke",    "permit_peke_move_fake_seal_shot_34",        "7503e9f5-a8d2-4a24-814e-773d9285635c"),
    ("permit_peke",    "permit_peke_move_carbon_copy_barrage_34",   "c23c56f5-14d4-4ac3-8bda-d00c4bb4afee"),
    ("fixer_fredo",    "fixer_fredo_move_envelope_express_34",      "1102f046-7f51-4520-811d-7e9569cf6d1a"),
    ("clerk_kurakot",  "clerk_kurakot_move_paper_cut_volley_34",    "198e2550-740b-41c6-bab3-30dd5677355a"),
    ("clerk_kurakot",  "clerk_kurakot_move_counter_charge_34",      "f482a2bd-fd54-4eb8-b087-efd577f953de"),
]


def grab(job, index, tries=5):
    for attempt in range(tries):
        try:
            req = urllib.request.Request(URL % (job, index), headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                return Image.open(BytesIO(r.read())).convert("RGBA")
        except Exception:
            if attempt == tries - 1:
                raise
            time.sleep(8 * (attempt + 1))


def install(slug, dest, job, manifest):
    meta = manifest[slug]
    canvas, box = tuple(meta["canvas"]), tuple(meta["box"])
    folder = f"{OUT}/{dest}"
    os.makedirs(folder, exist_ok=True)
    feet = set()
    for i in range(FRAMES):
        frame = grab(job, i)
        full = Image.new("RGBA", canvas, (0, 0, 0, 0))
        full.paste(frame, (box[0], box[1]))
        full.save(f"{folder}/frame_{i}.png")
        bb = full.getchannel("A").getbbox()
        feet.add(bb[3])
    return folder, sorted(feet)


def main():
    manifest = json.load(open(f"{REFS}/manifest.json"))
    for slug, dest, job in JOBS:
        try:
            folder, feet = install(slug, dest, job, manifest)
        except Exception as exc:
            print(f"  {dest:44} FAILED -- {exc}")
            continue
        # The floor line is the contract every other clip and the shadow share.
        flag = "" if feet == [176] else f"  <-- foot rows {feet}, expected [176]"
        print(f"  {dest:44} {FRAMES}f{flag}")


main()
