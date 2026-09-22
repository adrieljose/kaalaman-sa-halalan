"""User-approved local alpha cleanup of built-in-generated Chapter 5 sprites.

Originals are copied into the project, never modified. Pass additional sources
as slug=absolute_path. Outputs are the existing animation builder's inputs.
"""
from pathlib import Path
import argparse
import json
import shutil
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/chapter5_villains"
GENERATED = Path("C:/Users/Asus/.codex/generated_images/01a07070-f10d-7780-98c9-982a92835651")
SOURCES = {
    "cong_kodigo": "exec-501c0298-8605-4478-9b88-f86fe172239d.png",
    "senador_sawsaw": "exec-3b63d83c-d645-40e1-99a4-ccfc0c622249.png",
    "chairman_chika": "exec-3bfa22b3-e411-449e-9979-fd1c181a0353.png",
    "quorum_kuno": "exec-f6fd4098-48f8-491d-86c9-50a27a7f2997.png",
    "spiker_supremo": "exec-b34e62c6-0e3d-488d-8827-91bbd620c4b9.png",
    "whip_walanghiya": "exec-5dd215ba-0afe-4343-81e4-4424cf5cdf02.png",
    "amendment_atras": "exec-f8b1b4aa-3b2c-473f-b4df-13da099f731b.png",
    "bicam_berto": "exec-aa94650c-205b-46bf-a6db-23035c8d9ea7.png",
    "budget_bomba": "exec-47bde4eb-905e-4f90-9afc-c13b94e93848.png",
}


def clean(source):
    image = Image.open(source)
    pixels = np.array(image.convert("RGBA"))
    if image.mode == "RGBA" and pixels[:, :, 3].min() == 0:
        # Remove near-transparent generator halos, without color-keying dark
        # outlines or cream clothing. Crisp alpha for nearest-neighbor sprites.
        mask = pixels[:, :, 3] >= 200
    else:
        rgb = pixels[:, :, :3].astype(int)
        grey = (rgb.max(2) - rgb.min(2) < 22) & (rgb.min(2) > 155)
        border = np.zeros(grey.shape, bool)
        border[0] = grey[0]
        border[-1] = grey[-1]
        border[:, 0] = grey[:, 0]
        border[:, -1] = grey[:, -1]
        background = ndimage.binary_propagation(border, mask=grey)
        mask = ~background
    labels, count = ndimage.label(mask)
    areas = np.bincount(labels.ravel())
    areas[0] = 0
    # Discard isolated background specks; props are connected to the hands.
    mask = labels == areas.argmax()
    pixels[:, :, 3] = np.where(mask, 255, 0)
    pixels[~mask, :3] = 0
    cleaned = Image.fromarray(pixels)
    assert cleaned.getbbox() is not None
    return cleaned.crop(cleaned.getbbox())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("sources", nargs="*")
    args = parser.parse_args()
    paths = {slug: GENERATED / name for slug, name in SOURCES.items()}
    paths.update(dict(value.split("=", 1) for value in args.sources))
    (OUT / "sources").mkdir(parents=True, exist_ok=True)
    manifest_path = OUT / "sources/manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    for slug, source in paths.items():
        original = OUT / "sources" / (slug + ".png")
        shutil.copy2(source, original)
        image = clean(original)
        target = OUT / "rot" / slug / "south-west.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        image.save(target)
        manifest[slug] = {"generator": "Codex built-in image_gen", "original": str(original.relative_to(ROOT)),
                          "cleaned": str(target.relative_to(ROOT)), "alpha": "binary RGBA, user-approved local cleanup"}
        print(slug, image.size, image.getchannel("A").getextrema())
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    files = list((OUT / "rot").glob("*/south-west.png"))
    preview = Image.new("RGB", (256 * 3, 350 * ((len(files) + 2) // 3)), "#353344")
    draw = ImageDraw.Draw(preview)
    for i, file in enumerate(files):
        image = Image.open(file)
        image.thumbnail((230, 310), Image.Resampling.NEAREST)
        x, y = (i % 3) * 256, (i // 3) * 350
        preview.paste(image, (x + (256 - image.width) // 2, y + 310 - image.height), image)
        draw.text((x + 8, y + 325), file.parent.name, fill="white")
    preview.save(OUT / "roster_preview.png")


if __name__ == "__main__":
    main()
