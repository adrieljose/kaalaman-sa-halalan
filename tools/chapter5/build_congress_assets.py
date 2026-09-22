"""Package built-in generation originals into low-memory runtime scenery."""
from pathlib import Path
import json
import re
import shutil
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/chapter5_environments"
ART = ROOT / "assets/images/backgrounds/chapter5"

def main():
    manifest = json.loads((OUT / "generation_manifest.json").read_text(encoding="utf-8"))
    if len(manifest) != 9:
        raise SystemExit("All nine generated stages are required")
    ART.mkdir(parents=True, exist_ok=True)
    (OUT / "sources").mkdir(exist_ok=True)
    sheet = Image.new("RGB", (1152, 846), "#20252a")
    for i, item in enumerate(manifest):
        source = Path(re.search(r"as (C:\\.*?\.png) by default", item["output_hint"]).group(1))
        shutil.copy2(source, OUT / "sources" / (item["id"] + ".png"))
        im = Image.open(source).convert("RGB").resize((768,512), Image.Resampling.NEAREST)
        im.save(ART / (item["id"] + ".png"), optimize=True)
        card = Image.new("RGB", (384,282), "#20252a")
        card.paste(im.resize((384,256), Image.Resampling.NEAREST))
        ImageDraw.Draw(card).text((8,264), item["id"], fill="#eed397")
        sheet.paste(card, ((i%3)*384,(i//3)*282))
    sheet.save(OUT / "roster.png")
    print("Packaged 9 Congress backgrounds, 768x512 each; originals retained.")

if __name__ == "__main__":
    main()
