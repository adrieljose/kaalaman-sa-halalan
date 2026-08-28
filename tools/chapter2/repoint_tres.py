# -*- coding: utf-8 -*-
"""Points the Chapter 2 resources at the generated art instead of the placeholders.

Two edits, both driven by what is actually on disk rather than by a table that
could drift:

  1. Each rival's EnemyData gets idle/attack/hit pointed at its `<slug>_gen_*`
     folders, with the frame counts read from the folders themselves.

  2. Each Chapter 2 EnemyMove has its per-skill `attack_dir` cleared. Those 28
     placeholder clips were one-per-skill; the generated art is one attack clip
     per rival, so a skill that kept its own clip would visibly switch art style
     mid-fight. Clearing the field makes EnemyMove fall back to the rival's
     default attack clip (see enemy_move.gd) -- the skills stay distinct through
     movement, projectiles and impact FX, which are code, not frames.

Run after import_pixellab.py, then let the editor generate .import files.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from spec import ROSTER

REPO = r"D:\klhgamefinal"
CHARS = os.path.join(REPO, "assets", "images", "characters")
ENEMIES = os.path.join(REPO, "data", "enemies")
MOVES = os.path.join(REPO, "data", "moves")

SLUGS = [e["slug"] for e in ROSTER]
# Chapter 1 shares the enemy_NN_ prefix, so match on the rival's own slug.
ENEMY_FILES = {e["slug"]: "enemy_%02d_%s.tres" % (i + 1, e["slug"])
               for i, e in enumerate(ROSTER)}


def frame_count(folder):
    if not os.path.isdir(folder):
        return 0
    return len([f for f in os.listdir(folder)
                if re.fullmatch(r"frame_\d+\.png", f)])


def set_field(text, key, value):
    """Replace `key = ...` on its own line, or append it to [resource]."""
    pattern = re.compile(r"^%s = .*$" % re.escape(key), re.MULTILINE)
    line = "%s = %s" % (key, value)
    if pattern.search(text):
        return pattern.sub(line, text)
    return text.rstrip("\n") + "\n" + line + "\n"


def repoint_enemies():
    changed = []
    for slug in SLUGS:
        path = os.path.join(ENEMIES, ENEMY_FILES[slug])
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read()
        for field, clip in (("idle", "idle"), ("attack", "attack"), ("hit", "hit")):
            folder = os.path.join(CHARS, "%s_gen_%s" % (slug, clip))
            n = frame_count(folder)
            if n == 0:
                print("  ! %s: no frames in %s_gen_%s -- left as-is" % (slug, slug, clip))
                continue
            res = "res://assets/images/characters/%s_gen_%s" % (slug, clip)
            text = set_field(text, "%s_dir" % field, '"%s"' % res)
            text = set_field(text, "%s_count" % field, str(n))
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
        changed.append(slug)
    return changed


def clear_move_clips():
    """Drop the per-skill clip override on every Chapter 2 move."""
    cleared = 0
    for e in ROSTER:
        for m in e["moves"]:
            path = os.path.join(MOVES, "%s.tres" % m["id"])
            if not os.path.exists(path):
                continue
            with open(path, "r", encoding="utf-8") as fh:
                text = fh.read()
            if "attack_dir" not in text:
                continue
            text = re.sub(r"^attack_dir = .*\n", "", text, flags=re.MULTILINE)
            text = re.sub(r"^attack_count = .*\n", "", text, flags=re.MULTILINE)
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(text)
            cleared += 1
    return cleared


if __name__ == "__main__":
    done = repoint_enemies()
    print("rivals repointed: %d" % len(done))
    print("per-skill clip overrides cleared: %d" % clear_move_clips())
