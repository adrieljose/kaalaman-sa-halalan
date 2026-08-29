# -*- coding: utf-8 -*-
"""Pulls the south-west rotation for each Chapter 1 rival.

`south-west` is the 3/4 facing LEFT -- a rival stands on the right of the
stage, so that is the one looking at the player. It keeps both eyes, the
shoulder line and the props readable, which a flat `west` profile does not.

The download endpoint needs no auth but does reject urllib's default
User-Agent outright, hence the browser string.
"""
import io, os, sys, urllib.request, zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "rot34")

ROTATED = {
    "lord_trapo":       "8e2f2071-ffba-4daf-b510-731682be53f6",
    "vote_vandal":      "1afe092c-273a-4d43-89b7-0e13d5ac0bf2",
    "kapitan_komisyon": "347a9d12-b2c6-4aa0-bc0e-b1c8325e554d",
    "ate_ayuda":        "02ebe63d-04d4-4fcd-b00d-ae6451b23d79",
}
WANT = "south-west"


def fetch(cid):
    req = urllib.request.Request(
        "https://api.pixellab.ai/mcp/characters/%s/download" % cid,
        headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for slug, cid in ROTATED.items():
        try:
            z = zipfile.ZipFile(io.BytesIO(fetch(cid)))
        except Exception as exc:
            print("%-18s FAILED %s" % (slug, exc)); continue
        hit = [n for n in z.namelist()
               if n.lower().endswith("/%s.png" % WANT) or n.lower().endswith("%s.png" % WANT)]
        if not hit:
            print("%-18s no %s in %s" % (slug, WANT, z.namelist()[:6])); continue
        data = z.read(hit[0])
        open(os.path.join(OUT, slug + ".png"), "wb").write(data)
        print("%-18s %s  %d bytes" % (slug, hit[0], len(data)))
