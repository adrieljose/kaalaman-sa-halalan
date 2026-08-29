# -*- coding: utf-8 -*-
"""Points the rotated Chapter 1 rivals, and the players, at their 3/4 clips.

The old front-facing folders are left on disk. They are what the chapter
shipped with, and keeping them means this is one line of data away from being
reversible if the pose reads worse in play than it does in a contact sheet.

Three things get repointed, and missing any one of them puts a character back
on the camera mid-fight:

  * the rivals' idle / attack / hit;
  * Lord Trapo's two MOVE resources, which each override the attack clip -- he
    is the only character in the game that does this;
  * both players' walk, and the two rivals that have one. A walk left pointing
    at the old art snaps the character front-facing for the whole approach.
"""
import os, re

ROOT = r"D:\klhgamefinal"
ENEMIES = os.path.join(ROOT, "data", "enemies")
MOVES = os.path.join(ROOT, "data", "moves")
CHARS = os.path.join(ROOT, "assets", "images", "characters")

# enemy resource -> slug of the rotated clips
RIVALS = {
    "enemy_01_lord_trapo.tres":       "lord_trapo",
    "enemy_02_vote_vandal.tres":      "vote_vandal",
    "enemy_04_kapitan_komisyon.tres": "kapitan_komisyon",
    "enemy_05_ate_ayuda.tres":        "ate_ayuda",
}
# move resource -> the clip folder that move should use
MOVES_MAP = {
    "lord_trapo_dynasty_power.tres":  "lord_trapo_battle_dynasty",
    "lord_trapo_smear_campaign.tres": "lord_trapo_battle_smear",
}


def frames(folder):
    p = os.path.join(CHARS, folder)
    if not os.path.isdir(p):
        return 0
    return len([f for f in os.listdir(p) if re.fullmatch(r"frame_\d+\.png", f)])


def set_field(text, key, value):
    pat = re.compile(r"^%s = .*$" % re.escape(key), re.MULTILINE)
    line = "%s = %s" % (key, value)
    return pat.sub(line, text) if pat.search(text) else text.rstrip("\n") + "\n" + line + "\n"


def point(text, clip, folder):
    n = frames(folder)
    if n == 0:
        raise SystemExit("%s has no frames" % folder)
    text = set_field(text, "%s_dir" % clip,
                     '"res://assets/images/characters/%s"' % folder)
    return set_field(text, "%s_count" % clip, str(n))


changed = []
for name, slug in RIVALS.items():
    path = os.path.join(ENEMIES, name)
    text = open(path, encoding="utf-8").read()
    for clip in ("idle", "attack", "hit"):
        text = point(text, clip, "%s_battle_%s" % (slug, clip))
    walk = "%s_battle_walk" % slug
    if frames(walk):
        text = point(text, "walk", walk)
    elif "walk_dir" in text:
        # Clear rather than leave it: AnimatedCharacter keeps the PREVIOUS
        # rival's walk when a key is absent, so a stale path would leak across
        # encounters.
        text = set_field(text, "walk_dir", '""')
        text = set_field(text, "walk_count", "0")
    open(path, "w", encoding="utf-8").write(text)
    changed.append(name)

for name, folder in MOVES_MAP.items():
    path = os.path.join(MOVES, name)
    text = open(path, encoding="utf-8").read()
    text = point(text, "attack", folder)
    open(path, "w", encoding="utf-8").write(text)
    changed.append(name)

# The players' walk lives in code, not a resource.
gs = os.path.join(ROOT, "scripts", "game_state.gd")
text = open(gs, encoding="utf-8").read()
for old, new, count in (
        ("player_walk", "player_battle_walk", frames("player_battle_walk")),
        ("player_female_walk", "player_female_battle_walk",
         frames("player_female_battle_walk"))):
    before = text
    text = re.sub(r'"walk_dir": "res://assets/images/characters/%s", "walk_count": \d+' % old,
                  '"walk_dir": "res://assets/images/characters/%s", "walk_count": %d' % (new, count),
                  text)
    if text != before:
        changed.append(new)
open(gs, "w", encoding="utf-8").write(text)

print("repointed:")
for c in changed:
    print("  " + c)
