"""Validate Chapter 5 RGBA frames/icons and produce local review artifacts."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw
from spec import all_entries

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/chapter5_villains"


def main():
    faults, results, icons = [], [], []
    for entry in all_entries():
        slug = entry["slug"]
        for clip in ["idle", "attack", "attack2", "guard", "hit", "walk"]:
            frames = sorted((ROOT / "assets/images/characters/chapter5" / (slug + "_" + clip)).glob("frame_*.png"), key=lambda p: int(p.stem.split("_")[-1]))
            hashes = set()
            for file in frames:
                image = Image.open(file)
                hashes.add(hashlib.sha256(image.tobytes()).hexdigest())
                if image.mode != "RGBA" or image.size != (256, 320):
                    faults.append(str(file) + ": invalid canvas")
                box = image.getchannel("A").getbbox()
                if box is None or min(box[:2]) <= 0 or box[2] >= 256 or box[3] >= 320:
                    faults.append(str(file) + ": blank or touches canvas edge")
            if len(hashes) < 3:
                faults.append(slug + "/" + clip + ": static")
            results.append({"enemy": slug, "clip": clip, "frames": len(frames), "distinct": len(hashes)})
        icon_files = list((ROOT / "assets/images/ui/skill_icons/chapter5" / slug).glob("*.png"))
        if len(icon_files) != 3:
            faults.append(slug + ": expected three icons")
        for file in icon_files:
            image = Image.open(file)
            if image.mode != "RGBA" or image.size != (64, 64) or image.getchannel("A").getextrema() != (0, 255):
                faults.append(str(file) + ": invalid icon alpha/size")
            icons.append((file, image.copy()))
    unique_icons = len({hashlib.sha256(im.tobytes()).hexdigest() for _, im in icons})
    if unique_icons != 27:
        faults.append("expected 27 unique icons")
    sheet = Image.new("RGB", (640, 9 * 96), "#252330")
    draw = ImageDraw.Draw(sheet)
    for row, entry in enumerate(all_entries()):
        draw.text((8, row * 96 + 6), entry["name"], fill="white")
        for col, (file, im) in enumerate((p, im) for p, im in icons if p.parent.name == entry["slug"]):
            x, y = 190 + col * 145, row * 96
            sheet.paste(im, (x, y), im)
            draw.text((x - 12, y + 68), file.stem.replace("_", " "), fill="#e9ca92")
    sheet.save(OUT / "skill_icons_preview.png")
    report = {"frames": sum(r["frames"] for r in results), "icons": len(icons), "unique_icons": unique_icons, "clips": results, "faults": faults}
    (OUT / "art_audit.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k != "clips"}, indent=2))
    raise SystemExit(1 if faults else 0)


if __name__ == "__main__":
    main()
