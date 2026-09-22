# -*- coding: utf-8 -*-
"""Writes every Chapter 5 resource from tools/chapter5/spec.py.

    python tools/chapter5/build_chapter5_data.py [--write]

Produces, all of it derived and none of it hand-typed:

    data/moves/c5_<move>.tres          24 regular skills + 3 boss skills
    data/enemies/ch5_<nn>_<slug>.tres  8 rivals + the boss
    data/chapters/chapter_05.tres      the encounter ladder, in order

WHY IT IS GENERATED
    Chapter 3's equivalent carried its own copy of the roster beside the spec
    and the two drifted, which is how a renamed move silently stopped routing.
    Here the spec is the only source: run this again after editing spec.py and
    every file agrees with it by construction.

WHAT IT REFUSES TO DO
    It will not write a resource that points at a texture or a frame directory
    that is not on disk. Godot fails a .tres with a missing ExtResource by
    silently handing back null, and a null background or a null portrait
    surfaces much later as an empty room or a blank HUD -- so the check happens
    here, loudly, before the file is written.

ICONS
    Unlike Chapter 4, every Chapter 5 move has an icon before its resource is
    written -- tools/chapter5/build_icons.py draws all 27 -- so the icon is a
    hard requirement here rather than an optional field. A move whose icon is
    missing is a FAULT and nothing is written, because an icon silently absent
    is exactly the defect the brief asked not to repeat.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "chapter5"))
import spec  # noqa: E402

MOVES = os.path.join(ROOT, "data", "moves")
ENEMIES = os.path.join(ROOT, "data", "enemies")
CHAPTERS = os.path.join(ROOT, "data", "chapters")
ART = "res://assets/images/characters/chapter5"
ICONS = "res://assets/images/ui/skill_icons/chapter5"
PORTRAITS = "res://assets/images/portraits"
BACKGROUNDS = "res://assets/images/backgrounds"

# The clip a skill drives the body with, per kind. These mirror the frame
# counts build_chapter4_art.py exports.
CLIP_FOR = {spec.MELEE: ("attack", 12), spec.RANGED: ("attack2", 12),
            spec.GUARD: ("guard", 10)}

# Staging, per rival. enemy_battle_offset.y stays 0 everywhere: the controller
# grounds fighters on their VISIBLE soles (AnimatedCharacter.body_rect), so a
# vertical nudge here would be fighting a system that already has it right.
# The x offset and the scale are the only staging knobs Chapter 4 needs, and
# they follow the same shape Chapter 3 settled on.
STAGING = {
    "cong_kodigo": (-25, 1.15),
    "senador_sawsaw": (-27, 1.15),
    "chairman_chika": (-25, 1.16),
    "quorum_kuno": (-25, 1.14),
    "whip_walanghiya": (-29, 1.14),
    "amendment_atras": (-25, 1.15),
    "bicam_berto": (-27, 1.15),
    # The widest rival in the game. He is pushed further from the board rather
    # than scaled down -- the brief is explicit that his size IS the threat, so
    # shrinking him to fit would remove the thing he is for.
    "budget_bomba": (-38, 1.12),
    "spiker_supremo": (-28, 1.20),
}



def res_exists(res_path):
    return os.path.exists(os.path.join(ROOT, res_path.replace("res://", "")))


def move_file(move_key):
    return os.path.join(MOVES, "c5_%s.tres" % move_key)


def write_move(slug, name, kind, value, tagalog, english, colour, faults):
    move_key = spec.move_id(slug, name)[len(spec.PREFIX):]
    clip, count = CLIP_FOR[kind]
    clip_dir = "%s/%s_%s" % (ART, slug, clip)
    if not res_exists(clip_dir):
        faults.append("%s: %s has no frames at %s" % (slug, name, clip_dir))
    icon = "%s/%s/%s.png" % (ICONS, slug, move_key)
    if not res_exists(icon):
        faults.append("%s: %s has no icon at %s" % (slug, name, icon))
    damage = int(value) if kind != spec.GUARD else 0
    guard = float(value) if kind == spec.GUARD else 0.0
    r, g, b = colour
    text = '''[gd_resource type="Resource" script_class="EnemyMove" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/enemy_move.gd" id="1"]
[ext_resource type="Texture2D" path="%s" id="2"]

[resource]
script = ExtResource("1")
icon = ExtResource("2")
move_id = "%s"
move_name = "%s"
description = "%s"
direct_damage = %d
self_heal = 0
guard_reduction = %.2f
animation_style = "%s"
effect_color = Color(%.3f, %.3f, %.3f, 0.95)
attack_dir = "%s"
attack_count = %d
''' % (icon, spec.move_id(slug, name), name, tagalog.replace('"', "'"),
       damage, guard, kind, r, g, b, clip_dir, count)
    return move_file(move_key), text, move_key


def write_enemy(index, entry, move_keys, faults):
    slug = entry["slug"]
    portrait = "%s/enemy_%s.png" % (PORTRAITS, slug)
    room = "%s/%s.png" % (BACKGROUNDS, spec.placeholder_room(slug))
    for path in (portrait, room):
        if not res_exists(path):
            faults.append("%s: missing %s" % (slug, path))
    for kind in ("idle", "attack", "attack2", "guard", "hit", "walk"):
        if not res_exists("%s/%s_%s" % (ART, slug, kind)):
            faults.append("%s: missing %s frames" % (slug, kind))

    boss = entry is spec.BOSS
    dx, scale = STAGING[slug]
    steps = [
        '[ext_resource type="Script" path="res://scripts/enemy_data.gd" id="1"]',
        '[ext_resource type="Texture2D" path="%s" id="2"]' % portrait,
        '[ext_resource type="Texture2D" path="%s" id="3"]' % room,
    ]
    for i, key in enumerate(move_keys):
        steps.append('[ext_resource type="Resource" path="res://data/moves/c5_%s.tres" id="%d"]'
                     % (key, 10 + i))
    head = ('[gd_resource type="Resource" script_class="EnemyData" load_steps=%d format=3]\n\n%s\n'
            % (len(steps) + 1, "\n".join(steps)))

    body = '''
[resource]
script = ExtResource("1")
enemy_name = "%s"
title = "%s"
max_hp = %d
portrait = ExtResource("2")
hud_portrait = ExtResource("2")
background = ExtResource("3")
ground_fraction = 0.9125
player_battle_offset = Vector2(0, 0)
enemy_battle_offset = Vector2(%d, 0)
enemy_battle_scale = %.2f
lore = "%s"
is_boss = %s
moves = [%s]
''' % (entry["name"], entry["title"], entry["hp"], dx, scale,
       entry["lore"].replace('"', "'"), "true" if boss else "false",
       ", ".join('ExtResource("%d")' % (10 + i) for i in range(len(move_keys))))

    if boss:
        body += 'phase_thresholds = [%.2f]\n' % entry["phase_threshold"]
        body += 'phase_banners = ["%s"]\n' % entry["phase_banner"]

    body += '''idle_dir = "%s/%s_idle"
idle_count = 8
attack_dir = "%s/%s_attack"
attack_count = 12
hit_dir = "%s/%s_hit"
hit_count = 8
walk_dir = "%s/%s_walk"
walk_count = 10
flip_h = false
''' % (ART, slug, ART, slug, ART, slug, ART, slug)
    return os.path.join(ENEMIES, "ch5_%02d_%s.tres" % (index, slug)), head + body


def write_chapter(enemy_paths):
    steps = ['[ext_resource type="Script" path="res://scripts/chapter_data.gd" id="1"]']
    for i, path in enumerate(enemy_paths):
        rel = "res://" + os.path.relpath(path, ROOT).replace("\\", "/")
        steps.append('[ext_resource type="Resource" path="%s" id="%d"]' % (rel, i + 2))
    text = ('[gd_resource type="Resource" script_class="ChapterData" load_steps=%d format=3]\n\n%s\n'
            % (len(steps) + 1, "\n".join(steps)))
    text += '''
[resource]
script = ExtResource("1")
chapter_number = 5
chapter_name = "Kongreso"
encounters = [%s]
''' % ", ".join('ExtResource("%d")' % (i + 2) for i in range(len(enemy_paths)))
    return os.path.join(CHAPTERS, "chapter_05.tres"), text


def main():
    write = "--write" in sys.argv
    faults = []
    pending = []

    enemy_paths = []
    for index, entry in enumerate(spec.all_entries(), 1):
        slug = entry["slug"]
        keys = []
        for name, kind, value, tagalog, english in entry["moves"]:
            path, text, key = write_move(slug, name, kind, value, tagalog,
                                         english, entry["colour"], faults)
            pending.append((path, text))
            keys.append(key)
        path, text = write_enemy(index, entry, keys, faults)
        pending.append((path, text))
        enemy_paths.append(path)
        print("  %d %-20s hp %3d  %s" % (index, entry["name"], entry["hp"],
                                         ", ".join(k for k in keys)))

    path, text = write_chapter(enemy_paths)
    pending.append((path, text))

    print("\n%d files, %d moves" % (len(pending), sum(1 for p, _ in pending
                                                      if "/moves/" in p.replace("\\", "/"))))
    if faults:
        print("\nMISSING ASSETS -- nothing written:")
        for f in sorted(set(faults)):
            print("   %s" % f)
        raise SystemExit(1)
    if not write:
        print("\nvalidation only. Re-run with --write to create the resources.")
        return
    for path, text in pending:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    print("\nwrote %d resources" % len(pending))


if __name__ == "__main__":
    main()
