# -*- coding: utf-8 -*-
"""Points the Chapter 2 rivals at their side-facing clips.

The `_gen_*` folders are left on disk untouched. They are the front-facing set
the chapter shipped with, and keeping them means this is one line of data away
from being reversible if the profile pose turns out to read worse in play than
it does in a contact sheet.
"""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from spec import ROSTER

ENEMIES = r"D:\klhgamefinal\data\enemies"
CHARS = r"D:\klhgamefinal\assets\images\characters"
SUFFIX = "west"

def frames(folder):
    p = os.path.join(CHARS, folder)
    if not os.path.isdir(p):
        return 0
    return len([f for f in os.listdir(p) if re.fullmatch(r"frame_\d+\.png", f)])

def set_field(text, key, value):
    pat = re.compile(r"^%s = .*$" % re.escape(key), re.MULTILINE)
    line = "%s = %s" % (key, value)
    return pat.sub(line, text) if pat.search(text) else text.rstrip("\n") + "\n" + line + "\n"

done = []
for i, e in enumerate(ROSTER):
    slug = e["slug"]
    path = os.path.join(ENEMIES, "enemy_%02d_%s.tres" % (i + 1, slug))
    if not os.path.exists(path):
        print("  ! missing", path); continue
    text = open(path, encoding="utf-8").read()
    ok = True
    for clip in ("idle", "attack", "hit"):
        folder = "%s_%s_%s" % (slug, SUFFIX, clip)
        n = frames(folder)
        if n == 0:
            print("  ! %s has no frames" % folder); ok = False; continue
        text = set_field(text, "%s_dir" % clip,
                         '"res://assets/images/characters/%s"' % folder)
        text = set_field(text, "%s_count" % clip, str(n))
    if ok:
        open(path, "w", encoding="utf-8").write(text)
        done.append(slug)
print("rivals repointed to side-facing clips: %d" % len(done))
