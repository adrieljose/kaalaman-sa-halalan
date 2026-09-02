# -*- coding: utf-8 -*-
"""Points every Chapter 2 rival at its 3/4-facing clips.

Also CLEARS the four per-skill attack clips added earlier in the day. Those
were generated from the front-facing sprites, and a rival that now stands
three-quarters turned would have snapped square to the camera for the duration
of one skill and back again -- a far worse artefact than the shared swing they
fall back to. The move resources keep their entries so the pointers can be
restored if those skills are ever regenerated in the new facing; only the paths
are emptied, and _body_swing already treats an empty attack_dir as "use the
rival's own attack".
"""
import glob
import os
import re

ENEMIES = {
    "enemy_01_fixer_fredo":    "fixer_fredo",
    "enemy_02_clerk_kurakot":  "clerk_kurakot",
    "enemy_03_permit_peke":    "permit_peke",
    "enemy_04_notaryo_naku":   "notaryo_naku",
    "enemy_05_cashier_kaltas": "cashier_kaltas",
    "enemy_06_budget_bandido": "budget_bandido",
    "enemy_07_bidding_bandit": "bidding_bandit",
    "enemy_08_ordinance_ogre": "ordinance_ogre",
    "enemy_09_don_eraptado":   "don_eraptado",
}
# Per-skill clips generated against the OLD facing.
STALE_MOVES = ["plunder_supremo", "jueteng_jackpot",
               "citation_cannon", "queue_skip_kick"]


def count(slug, kind):
    return len(glob.glob(f"assets/images/characters/{slug}_battle_{kind}_34/frame_*.png"))


def main():
    missing = []
    for stem, slug in ENEMIES.items():
        counts = {k: count(slug, k) for k in ("idle", "attack", "hit")}
        if min(counts.values()) == 0:
            missing.append((slug, counts))
            continue
        path = f"data/enemies/{stem}.tres"
        src = open(path, encoding="utf-8").read()
        for kind in ("idle", "attack", "hit"):
            folder = f"res://assets/images/characters/{slug}_battle_{kind}_34"
            src = re.sub(rf'^{kind}_dir = ".*"$', f'{kind}_dir = "{folder}"',
                         src, flags=re.M)
            src = re.sub(rf"^{kind}_count = \d+$", f"{kind}_count = {counts[kind]}",
                         src, flags=re.M)
        open(path, "w", encoding="utf-8").write(src)
        print(f"  {slug:16} idle={counts['idle']} attack={counts['attack']} "
              f"hit={counts['hit']}")

    for move in STALE_MOVES:
        path = f"data/moves/{move}.tres"
        if not os.path.exists(path):
            continue
        src = open(path, encoding="utf-8").read()
        if 'attack_dir = ""' in src:
            continue
        src = re.sub(r'^attack_dir = ".*"$', 'attack_dir = ""', src, flags=re.M)
        src = re.sub(r"^attack_count = \d+$", "attack_count = 0", src, flags=re.M)
        open(path, "w", encoding="utf-8").write(src)
        print(f"  cleared per-skill clip on {move} (was front-facing)")

    if missing:
        print("\nNOT REPOINTED -- clips incomplete:")
        for slug, c in missing:
            print(f"  {slug}: {c}")
        raise SystemExit(1)
    print(f"\n{len(ENEMIES)} rivals repointed to 3/4 facing")


main()
