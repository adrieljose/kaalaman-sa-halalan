"""LEGACY. Writes the ORIGINAL Chapter 3 roster, which is no longer the one
that ships.

    python tools/chapter3/make_chapter3_data.py

This script builds Guard Garapal, Assessor Anino, Engineer Epal, Treasurer Tuso,
Auditor Alibi, Kalamidad Kiko, Konsehala Kubli, Board Member Bulok and
Gobernador Ganid. That roster was REPLACED. Chapter 3 now runs Bokal Bulsa,
Assessor Altapresyo, Treasurer Tago, Auditor Alibi, Planner Palusot, Engineer
Eskandalo, Contractor Kutsaba, Project Padrino and CONG MEOW -- hand-authored
resources with their own artwork, six clip folders per rival, and third moves
built on guard_reduction and self_heal.

Running this would overwrite data/chapters/chapter_03.tres and point it back at
nine enemy files this script writes, orphaning the live ones. So it REFUSES,
and the refusal is not a blanket block: it compares the encounter list actually
on disk against the roster below and stops only when they disagree. If the
legacy roster ever really is what is wanted, --force-legacy proceeds, after
printing exactly which files it is about to strand.

Kept rather than deleted because the balance table below is still the record of
where Chapter 3's HP curve and damage bands came from, and the reasoning in
those comments is not written down anywhere else.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ENEMY_DIR = os.path.join(ROOT, "data", "enemies")
MOVE_DIR = os.path.join(ROOT, "data", "moves")
CHAPTER_DIR = os.path.join(ROOT, "data", "chapters")

# --------------------------------------------------------------------------
# Placeholder art. Sprite set, portrait and room, each taken as a matched set
# from one Chapter 2 rival so the staging below is already proven.
# --------------------------------------------------------------------------
PLACEHOLDER = {
    "guard_garapal":     ("fixer_fredo",    "capitol_gate"),
    "assessor_anino":    ("clerk_kurakot",  "capitol_assessor"),
    "engineer_epal":     ("permit_peke",    "capitol_project_yard"),
    "treasurer_tuso":    ("cashier_kaltas", "capitol_treasury"),
    "auditor_alibi":     ("notaryo_naku",   "capitol_arcade"),
    "kalamidad_kiko":    ("budget_bandido", "capitol_relief_yard"),
    "konsehala_kubli":   ("senator_sabaw",  "capitol_committee"),
    "board_member_bulok": ("ordinance_ogre", "capitol_session_hall"),
    "gobernador_ganid":  ("don_eraptado",   "capitol_governor_office"),
}

# frame counts per Chapter 2 clip set, counted off disk
FRAMES = {
    "fixer_fredo":    (8, 7, 6),
    "clerk_kurakot":  (8, 6, 6),
    "permit_peke":    (8, 6, 6),
    "cashier_kaltas": (8, 9, 6),
    "notaryo_naku":   (8, 7, 6),
    "budget_bandido": (8, 7, 6),
    "senator_sabaw":  (8, 6, 6),
    "ordinance_ogre": (8, 7, 6),
    "don_eraptado":   (8, 7, 6),
}

# Per-room staging. Rooms absent here use the authored defaults, which is where
# every Chapter 3 room starts until a render shows it needs otherwise.
STAGING = {
    # Measured per room once the fighters are actually standing in it. Chapter
    # 2's numbers do not carry over -- they were measured against Chapter 2's
    # rooms, and these are different paintings.
}

# --------------------------------------------------------------------------
# The roster.
#
# HP continues Chapter 2's curve (170..280, boss 480) at a steady +20 a rung,
# opening above Chapter 2's strongest ordinary rival.
#
# DAMAGE does NOT keep climbing, and that is the one deliberate departure from
# a straight escalation. The player's health is a flat 100 in every chapter
# (GameState.player_max_hp), and Chapter 2 already reaches 26 on its last mook
# and 34 on its boss -- roughly four hits and three. Pushing Chapter 3 into the
# high thirties would put the player two hits from dead, which is not a harder
# chapter so much as a coin-flip one. So Chapter 3 overlaps Chapter 2's top
# band and grows the FIGHT instead: 300..440 HP is a great deal more board to
# get through, and every extra turn is another chance for the clock to land a
# free hit. The pressure is the timer, not the number.
# --------------------------------------------------------------------------
ROSTER = [
    dict(
        slug="guard_garapal", name="Guard Garapal", title="The Brazen Gatekeeper",
        hp=300, colour=(0.78, 0.72, 0.60),
        lore="The building is public. The lobby is public. He is the part in "
             "between, and he has decided that part is his.",
        moves=[
            ("Gate Bar Swing", "The barrier is not for cars.", 21, "slam"),
            ("ID Check Shove", "He has already decided. The card is a formality.", 18, "lunge"),
            ("Logbook Lash", "Sign here. And here. And come back Thursday.", 20, "volley"),
        ],
    ),
    dict(
        slug="assessor_anino", name="Assessor Anino", title="The Shadow Valuer",
        hp=320, colour=(0.62, 0.70, 0.82),
        lore="Her friend's hectare is worth almost nothing on paper. Yours "
             "went up again. Both figures came from the same desk.",
        moves=[
            ("Zonal Value Slash", "One stroke. Your lot is worth more now.", 19, "lunge"),
            ("Tax Map Trap", "The line moved while you were not looking at it.", 23, "curse"),
            ("Reassessment Rain", "Everyone on the street opens the same envelope.", 21, "spray"),
        ],
    ),
    dict(
        slug="engineer_epal", name="Engineer Epal", title="The Tarpaulin King",
        hp=340, colour=(0.94, 0.78, 0.36),
        lore="His face is on the waiting shed, the water tank and the road. "
             "None of the three were paid for with his money.",
        moves=[
            ("Tarpaulin Unfurl", "Two storeys of him, and a project behind it somewhere.", 22, "slam"),
            ("Ribbon Cut", "The scissors are ceremonial. The swing is not.", 20, "lunge"),
            ("Groundbreaking Pose", "Shovel up. Hold it. Again, for the other photographer.", 24, "volley"),
        ],
    ),
    dict(
        slug="treasurer_tuso", name="Treasurer Tuso", title="The Clever Ledger",
        hp=360, colour=(0.55, 0.80, 0.62),
        lore="She can tell you where every peso is. She has simply never been "
             "asked by anyone who could make her.",
        moves=[
            ("Vault Door Slam", "It closes faster than it opens.", 25, "slam"),
            ("Disbursement Dash", "Out the back before the request is filed.", 21, "lunge"),
            ("Petty Cash Spray", "None of it is petty by the end of the year.", 23, "spray"),
        ],
    ),
    dict(
        slug="auditor_alibi", name="Auditor Alibi", title="The Finding Dodger",
        hp=380, colour=(0.86, 0.56, 0.50),
        lore="Four years of findings, every one of them answered, not one of "
             "them settled.",
        moves=[
            ("Notice of Disallowance", "It follows you. It has your name spelled right.", 26, "curse"),
            ("Findings Flurry", "Volume is its own kind of cover.", 21, "volley"),
            ("Compliance Crush", "The paperwork weighs more than the finding.", 24, "slam"),
        ],
    ),
    dict(
        slug="kalamidad_kiko", name="Kalamidad Kiko", title="The Calamity Profiteer",
        hp=400, colour=(0.52, 0.64, 0.86),
        lore="He is the first to the flooded barangay and the last to file "
             "the receipts. Both facts are on the record.",
        moves=[
            ("Quick Response Rush", "The fund is for speed. So is he.", 22, "lunge"),
            ("Relief Sack Slam", "His name is stencilled on the side of it.", 27, "slam"),
            ("Storm Signal Spray", "Signal number two, and the money is already moving.", 24, "spray"),
        ],
    ),
    dict(
        slug="konsehala_kubli", name="Konsehala Kubli", title="The Hidden Agenda",
        hp=420, colour=(0.78, 0.60, 0.86),
        lore="The measure passed on the floor in nine minutes. It was written "
             "over four months in a room with no gallery.",
        moves=[
            ("Closed Door Session", "The minutes will say the discussion was thorough.", 28, "slam"),
            ("Committee Report Volley", "Forty pages. The change is on page thirty-one.", 23, "volley"),
            ("Insertion Sleight", "One clause, added between the reading and the vote.", 25, "curse"),
        ],
    ),
    dict(
        slug="board_member_bulok", name="Board Member Bulok", title="The Rotten Vote",
        hp=440, colour=(0.70, 0.62, 0.44),
        lore="He has sat on the provincial board for eleven years. Name one "
             "thing he has voted against.",
        moves=[
            ("Gavel Drop", "Carried. He did not look up to count.", 29, "slam"),
            ("Resolution Rush", "Second reading and third in the same breath.", 24, "lunge"),
            ("Roll Call Barrage", "Aye. Aye. Aye. Aye. Aye.", 26, "volley"),
        ],
    ),
    dict(
        slug="gobernador_ganid", name="Gobernador Ganid", title="The Provincial Patron",
        hp=700, colour=(0.98, 0.86, 0.48), boss=True,
        lore="Three terms, then his wife's three, then his son's. He calls it "
             "continuity. The province calls it the family.",
        moves=[
            ("Provincial Patronage", "Everything you have, he would like you to remember he allowed.", 30, "slam"),
            ("Endorsement Chain", "One name, and the whole ballot follows it down.", 26, "curse"),
            ("Pork Barrel Burst", "Scattered wide. Landing where the votes are.", 28, "spray"),
            # Phase-2 exclusive. Held back by min_phase, which the battle
            # controller filters the rotation against -- the same mechanism
            # Don Eraptado's Executive Privilege uses.
            ("Emergency Powers", "He declares the calamity. The calamity is him.", 40, "slam", 2),
        ],
    ),
]


def slug_of(display):
    return display.strip().lower().replace(" ", "_")


def write_move(rival, entry):
    name, description, damage, style = entry[:4]
    min_phase = entry[4] if len(entry) > 4 else 1
    move_slug = slug_of(name)
    r, g, b = rival["colour"]
    # No icon: skill art is stage 4 of the build order. A null icon renders as
    # an empty slot in the moves panel rather than breaking it.
    lines = [
        '[gd_resource type="Resource" script_class="EnemyMove" load_steps=2 format=3]',
        "",
        '[ext_resource type="Script" path="res://scripts/enemy_move.gd" id="1"]',
        "",
        "[resource]",
        'script = ExtResource("1")',
        'move_id = "%s"' % move_slug,
        'move_name = "%s"' % name,
        'description = "%s"' % description,
        "direct_damage = %d" % damage,
        'animation_style = "%s"' % style,
        "effect_color = Color(%.2f, %.2f, %.2f, 0.95)" % (r, g, b),
    ]
    if min_phase > 1:
        lines.append("min_phase = %d" % min_phase)
    lines.append("")
    path = os.path.join(MOVE_DIR, "%s.tres" % move_slug)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    return move_slug


def write_enemy(index, rival, move_slugs):
    sprite, room = PLACEHOLDER[rival["slug"]]
    idle_n, attack_n, hit_n = FRAMES[sprite]
    boss = rival.get("boss", False)
    staging = STAGING.get(room, {})

    ext = [
        '[ext_resource type="Script" path="res://scripts/enemy_data.gd" id="1"]',
        '[ext_resource type="Texture2D" path="res://assets/images/portraits/enemy_%s.png" id="2"]' % sprite,
        '[ext_resource type="Texture2D" path="res://assets/images/backgrounds/%s.png" id="3"]' % room,
    ]
    for i, ms in enumerate(move_slugs):
        ext.append('[ext_resource type="Resource" path="res://data/moves/%s.tres" id="%d"]' % (ms, 10 + i))
    if boss:
        ext.append('[ext_resource type="Texture2D" path="res://assets/images/backgrounds/%s_phase2.png" id="90"]' % room)

    body = [
        "[resource]",
        'script = ExtResource("1")',
        'enemy_name = "%s"' % rival["name"],
        'title = "%s"' % rival["title"],
        "max_hp = %d" % rival["hp"],
        'portrait = ExtResource("2")',
        'background = ExtResource("3")',
    ]
    if "scale" in staging:
        body.append("battle_scale = %s" % staging["scale"])
    if "ground" in staging:
        body.append("ground_fraction = %s" % staging["ground"])
    if "player" in staging:
        body.append("player_battle_offset = Vector2(%d, %d)" % staging["player"])
    if "enemy" in staging:
        body.append("enemy_battle_offset = Vector2(%d, %d)" % staging["enemy"])
    # hurt_voice is left empty on purpose -- Chapter 3 voices are stage 6, and
    # an empty name falls back to the shared three-take set rather than leaving
    # the rival silent.
    body.append('lore = "%s"' % rival["lore"].replace('"', "'"))
    body.append("is_boss = %s" % ("true" if boss else "false"))
    body.append("moves = [%s]" % ", ".join('ExtResource("%d")' % (10 + i) for i in range(len(move_slugs))))
    if boss:
        body.append("phase_thresholds = Array[float]([0.5])")
        body.append('phase_backgrounds = Array[Texture2D]([ExtResource("90")])')
        body.append('phase_banners = PackedStringArray("THE PROVINCE IS MINE")')
    body += [
        'idle_dir = "res://assets/images/characters/%s_battle_idle_34"' % sprite,
        "idle_count = %d" % idle_n,
        'attack_dir = "res://assets/images/characters/%s_battle_attack_34"' % sprite,
        "attack_count = %d" % attack_n,
        'hit_dir = "res://assets/images/characters/%s_battle_hit_34"' % sprite,
        "hit_count = %d" % hit_n,
    ]
    # The borrowed sprite's own mirroring comes with it. Senator Sabaw's frames
    # were drawn facing right, so anything wearing them must be flipped or it
    # fights with its back to the player.
    if sprite == "senator_sabaw":
        body.append("flip_h = true")

    text = "\n".join(
        ['[gd_resource type="Resource" script_class="EnemyData" load_steps=%d format=3]' % (len(ext) + 1), ""]
        + ext + [""] + body + [""]
    )
    filename = "enemy_%02d_%s.tres" % (index, rival["slug"])
    with open(os.path.join(ENEMY_DIR, filename), "w", encoding="utf-8") as f:
        f.write(text)
    return filename


# --------------------------------------------------------------------------
# The refusal.
# --------------------------------------------------------------------------
def live_encounters():
    """The enemy resources chapter_03.tres actually points at right now."""
    path = os.path.join(CHAPTER_DIR, "chapter_03.tres")
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as f:
        text = f.read()
    return re.findall(r'res://data/enemies/([A-Za-z0-9_]+\.tres)', text)


def refuse_if_superseded(force):
    """Stops unless the chapter on disk is the one this script writes.

    Grounded in the file rather than in a hard-coded flag, so this stays honest
    if the legacy roster is ever deliberately restored -- at that point the
    lists match and the script simply runs.
    """
    mine = ["enemy_%02d_%s.tres" % (i, r["slug"]) for i, r in enumerate(ROSTER, start=1)]
    live = live_encounters()
    if live == mine:
        return
    if force:
        print("--force-legacy: overwriting the live Chapter 3 roster.")
        print("These encounter files will be ORPHANED (left on disk, no longer referenced):")
        for name in live:
            print("    data/enemies/%s" % name)
        print("")
        return

    print("REFUSING to run: this is not the roster Chapter 3 is using.")
    print("")
    print("  on disk now                      this script would write")
    print("  " + "-" * 32 + " " + "-" * 32)
    for i in range(max(len(live), len(mine))):
        print("  %-32s %s" % (live[i] if i < len(live) else "",
                              mine[i] if i < len(mine) else ""))
    print("")
    print("The live roster is hand-authored -- its rivals carry their own artwork,")
    print("six clip folders each, and third moves using guard_reduction/self_heal.")
    print("Running this would repoint chapter_03.tres at the files on the RIGHT,")
    print("stranding everything on the left.")
    print("")
    print("If the legacy roster really is wanted:  --force-legacy")
    raise SystemExit(1)


def main():
    enemy_files = []
    move_count = 0
    for i, rival in enumerate(ROSTER, start=1):
        slugs = [write_move(rival, m) for m in rival["moves"]]
        move_count += len(slugs)
        enemy_files.append(write_enemy(i, rival, slugs))

    ext = ['[ext_resource type="Script" path="res://scripts/chapter_data.gd" id="1"]']
    for i, filename in enumerate(enemy_files):
        ext.append('[ext_resource type="Resource" path="res://data/enemies/%s" id="%d"]' % (filename, i + 2))
    chapter = "\n".join(
        ['[gd_resource type="Resource" script_class="ChapterData" load_steps=%d format=3]' % (len(ext) + 1), ""]
        + ext
        + [
            "",
            "[resource]",
            'script = ExtResource("1")',
            "chapter_number = 3",
            # Matches MainMenu.CHAPTER_TITLES[3], which already reads
            # "Provincial Circuit" -- the map caption and the chapter's own
            # name should not disagree.
            'chapter_name = "Provincial Circuit"',
            "encounters = [%s]" % ", ".join('ExtResource("%d")' % (i + 2) for i in range(len(enemy_files))),
            "",
        ]
    )
    with open(os.path.join(CHAPTER_DIR, "chapter_03.tres"), "w", encoding="utf-8") as f:
        f.write(chapter)

    print("wrote %d rivals, %d skills, chapter_03.tres" % (len(enemy_files), move_count))
    for filename in enemy_files:
        print("  %s" % filename)


if __name__ == "__main__":
    refuse_if_superseded("--force-legacy" in sys.argv)
    main()
