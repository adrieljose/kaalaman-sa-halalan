# -*- coding: utf-8 -*-
"""Writes the Chapter 2 Godot resources from spec.py.

Generated rather than hand-written because 28 moves + 9 enemies + 1 chapter is
38 files that must agree with each other on ids, paths and frame counts; a
generator makes a rename a one-line edit in spec.py instead of a search across
38 files.
"""
import io, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from spec import ROSTER, BACKGROUNDS, CHAPTER

DATA = r"D:\klhgamefinal\data"
IDLE_N, HIT_N, ATK_N = 4, 4, 6


def w(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    io.open(path, "w", encoding="utf-8", newline="\n").write(text)


def col(t):
    return "Color(%s)" % ", ".join(str(round(v, 3)) for v in t)


def esc(s):
    return s.replace('"', '\\"')


# ------------------------------------------------------------------- moves
for e in ROSTER:
    for m in e["moves"]:
        clip = "res://assets/images/characters/%s_%s" % (e["slug"], m["id"])
        lines = [
            '[gd_resource type="Resource" script_class="EnemyMove" load_steps=3 format=3]',
            '',
            '[ext_resource type="Script" path="res://scripts/enemy_move.gd" id="1"]',
            '[ext_resource type="Texture2D" path="res://assets/images/moves/%s.png" id="2"]' % m["id"],
            '',
            '[resource]',
            'script = ExtResource("1")',
            'move_id = "%s"' % m["id"],
            'move_name = "%s"' % esc(m["name"]),
            'description = "%s"' % esc(m["desc"]),
            'icon = ExtResource("2")',
            'direct_damage = %d' % m["dmg"],
            'animation_style = "%s"' % m["style"],
            'effect_color = %s' % col(m["tint"]),
        ]
        if m.get("phase2"):
            lines.append('min_phase = 2')
        lines += [
            'attack_dir = "%s"' % clip,
            'attack_count = %d' % ATK_N,
            '',
        ]
        w(os.path.join(DATA, "moves", "%s.tres" % m["id"]), "\n".join(lines))

# ----------------------------------------------------------------- enemies
for e in ROSTER:
    steps = 3 + len(e["moves"]) + (2 if e["boss"] else 0)
    ext = [
        '[ext_resource type="Script" path="res://scripts/enemy_data.gd" id="1"]',
        '[ext_resource type="Texture2D" path="res://assets/images/portraits/enemy_%s.png" id="2"]' % e["slug"],
        '[ext_resource type="Texture2D" path="res://assets/images/backgrounds/%s.png" id="3"]' % e["bg"],
    ]
    mids = []
    for i, m in enumerate(e["moves"]):
        rid = str(10 + i)
        ext.append('[ext_resource type="Resource" path="res://data/moves/%s.tres" id="%s"]' % (m["id"], rid))
        mids.append(rid)
    if e["boss"]:
        ext.append('[ext_resource type="Texture2D" path="res://assets/images/backgrounds/%s_phase2.png" id="90"]' % e["bg"])

    lines = [
        '[gd_resource type="Resource" script_class="EnemyData" load_steps=%d format=3]' % (len(ext) + 1),
        '',
    ] + ext + [
        '',
        '[resource]',
        'script = ExtResource("1")',
        'enemy_name = "%s"' % esc(e["name"]),
        'title = "%s"' % esc(e["title"]),
        'max_hp = %d' % e["hp"],
        'portrait = ExtResource("2")',
        'background = ExtResource("3")',
        'lore = "%s"' % esc(e["lore"]),
        'is_boss = %s' % ("true" if e["boss"] else "false"),
        'moves = [%s]' % ", ".join('ExtResource("%s")' % r for r in mids),
    ]
    if e["boss"]:
        lines += [
            'phase_thresholds = Array[float]([0.5])',
            'phase_backgrounds = Array[Texture2D]([ExtResource("90")])',
            'phase_banners = PackedStringArray("THE MASK COMES OFF")',
        ]
    lines += [
        'idle_dir = "res://assets/images/characters/%s_idle"' % e["slug"],
        'idle_count = %d' % IDLE_N,
        # Default attack clip = the first skill's clip. Every skill overrides it
        # with its own, so this only ever shows if a move somehow has none.
        'attack_dir = "res://assets/images/characters/%s_%s"' % (e["slug"], e["moves"][0]["id"]),
        'attack_count = %d' % ATK_N,
        'hit_dir = "res://assets/images/characters/%s_hit"' % e["slug"],
        'hit_count = %d' % HIT_N,
        '',
    ]
    w(os.path.join(DATA, "enemies", "enemy_%02d_%s.tres" % (ROSTER.index(e) + 1, e["slug"])), "\n".join(lines))

# ----------------------------------------------------------------- chapter
ext = ['[ext_resource type="Script" path="res://scripts/chapter_data.gd" id="1"]']
ids = []
for i, e in enumerate(ROSTER):
    rid = str(i + 2)
    ext.append('[ext_resource type="Resource" path="res://data/enemies/enemy_%02d_%s.tres" id="%s"]'
               % (i + 1, e["slug"], rid))
    ids.append(rid)
chapter = [
    '[gd_resource type="Resource" script_class="ChapterData" load_steps=%d format=3]' % (len(ext) + 1),
    '',
] + ext + [
    '',
    '[resource]',
    'script = ExtResource("1")',
    'chapter_number = %d' % CHAPTER["number"],
    'chapter_name = "%s"' % CHAPTER["name"],
    'encounters = [%s]' % ", ".join('ExtResource("%s")' % r for r in ids),
    '',
]
w(os.path.join(DATA, "chapters", "chapter_%02d.tres" % CHAPTER["number"]), "\n".join(chapter))

print("moves:     %d" % sum(len(e["moves"]) for e in ROSTER))
print("enemies:   %d" % len(ROSTER))
print("chapter:   chapter_%02d.tres (%d encounters)" % (CHAPTER["number"], len(ROSTER)))
