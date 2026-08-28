# -*- coding: utf-8 -*-
"""Rebuilds the chapter-select map from five whole-island illustrations.

The previous version pasted a building sprite onto each of the old artwork's
generic islands, and it always looked pasted -- the building had its own light,
its own ground shadow and no relationship to the terrain under it. No amount of
positioning fixes that, because the island and the building were drawn by
different passes and never knew about each other.

So each chapter is now ONE generated illustration: shoreline, grounds, paths,
planting and building drawn together as a single scene. They are dropped onto
an empty lagoon rather than onto existing islands, which is why they read as
places instead of as stickers.

The lagoon is the original map with every island erased -- the sea, the
parchment border and the compass are the only things kept.
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))
MAP = r"D:\klhgamefinal\assets\images\backgrounds\chapter_map.png"
ORIGINAL = os.path.join(ROOT, "chapter_map_original.png")
ISLAND_DIR = os.path.join(ROOT, "islands")

# slug, target width on the 640x480 map, centre of the island
ISLANDS = [
    ("barangay",  118, (104, 316)),
    ("cityhall",  186, (238, 236)),
    ("capitol",   132, (352, 120)),
    ("palace",    142, (470, 286)),
    ("congress",  126, (556, 150)),
]

# Where each chapter's marker should sit once its island is placed, as a
# fraction of that island's box: just below centre, clear of the building.
MARKER_AT = (0.50, 0.86)


def is_sea(p):
    r, g, b = p[:3]
    return b > 120 and abs(int(b) - int(g)) < 40 and r < 150


def is_route(p):
    """The old artwork's dashed sailing route.

    It was drawn around the ORIGINAL islands, so once those are gone it wanders
    through open water joining nothing. It is erased with them and a new one is
    drawn between the chapters in order.
    """
    r, g, b = p[:3]
    return r > 200 and g > 200 and b > 200


def empty_lagoon(world):
    """Erase every island, leaving open water inside the shoreline.

    Works a row at a time: anything sitting BETWEEN the leftmost and rightmost
    sea pixel of its row is enclosed by water and is therefore island. The
    parchment border and compass are outside that span on every row, so they
    are never touched and never need special-casing.
    """
    w, h = world.size
    rgb = world.convert("RGB")
    px = rgb.load()

    water = [p for p in rgb.getdata() if is_sea(p)]
    if not water:
        raise SystemExit("no sea found -- is this the right map?")
    # A small tile of real water, so the fill keeps the sea's own texture.
    tile = None
    for y in range(0, h - 24, 4):
        for x in range(0, w - 24, 4):
            block = rgb.crop((x, y, x + 24, y + 24))
            if all(is_sea(p) for p in block.getdata()):
                tile = block
                break
        if tile:
            break
    if tile is None:
        raise SystemExit("no clean 24x24 patch of open water to tile from")

    out = world.copy()
    op = out.load()
    tp = tile.load()
    tw, th = tile.size
    erased = 0
    for y in range(h):
        row = [x for x in range(w) if is_sea(px[x, y])]
        if len(row) < 2:
            continue
        left, right = row[0], row[-1]
        for x in range(left, right + 1):
            p = px[x, y]
            if is_sea(p):
                continue
            op[x, y] = tp[x % tw, y % th] + (255,)
            erased += 1
    return out, erased


def draw_route(world, points):
    """A dashed line from chapter to chapter, so the map reads as a journey.

    Drawn UNDER nothing -- it is laid down before the islands -- and skipped
    wherever it would cross land, so it emerges from one shore and arrives at
    the next instead of running over the top of a palace.
    """
    from PIL import ImageDraw
    layer = Image.new("RGBA", world.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(len(points) - 1):
        x0, y0 = points[i]
        x1, y1 = points[i + 1]
        steps = max(2, int(((x1 - x0) ** 2 + (y1 - y0) ** 2) ** 0.5 / 7))
        for k in range(steps):
            if k % 2:
                continue          # every other segment, to make it dashed
            t0, t1 = k / steps, (k + 0.55) / steps
            d.line([x0 + (x1 - x0) * t0, y0 + (y1 - y0) * t0,
                    x0 + (x1 - x0) * t1, y0 + (y1 - y0) * t1],
                   fill=(236, 244, 246, 150), width=2)
    world.alpha_composite(layer)


def shadow(island):
    """A soft dark pool under the island so it sits IN the water, not on it."""
    a = island.split()[3]
    pool = Image.new("RGBA", island.size, (0, 0, 0, 0))
    pool.paste(Image.new("RGBA", island.size, (18, 46, 62, 90)), (0, 0), a)
    return pool


def build():
    world, erased = empty_lagoon(Image.open(ORIGINAL).convert("RGBA"))

    draw_route(world, [c for _, _, c in ISLANDS])

    placed = []
    for slug, target_w, (cx, cy) in ISLANDS:
        path = os.path.join(ISLAND_DIR, slug + ".png")
        if not os.path.exists(path):
            print("  ! missing %s" % path)
            continue
        art = Image.open(path).convert("RGBA")
        bb = art.getbbox()
        if bb:
            art = art.crop(bb)
        scale = target_w / float(art.width)
        art = art.resize((max(1, int(art.width * scale)),
                          max(1, int(art.height * scale))), Image.NEAREST)

        pos = (cx - art.width // 2, cy - art.height // 2)
        world.alpha_composite(shadow(art), (pos[0] + 2, pos[1] + 5))
        world.alpha_composite(art, pos)
        marker = (int(pos[0] + art.width * MARKER_AT[0]),
                  int(pos[1] + art.height * MARKER_AT[1]))
        placed.append((slug, art.size, pos, marker))

    world.save(MAP)
    print("island pixels erased from the lagoon: %d" % erased)
    return placed


if __name__ == "__main__":
    for slug, size, pos, marker in build():
        print("%-10s %3dx%-3d at %-12s marker %s" % (slug, size[0], size[1], pos, marker))
