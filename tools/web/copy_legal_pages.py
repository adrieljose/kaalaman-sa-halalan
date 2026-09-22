"""Copy static legal pages into one or more completed Godot web exports."""
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
FILES = ("privacy.html", "terms.html", "legal.css")

if len(sys.argv) < 2:
    raise SystemExit("Usage: copy_legal_pages.py BUILD_DIR [BUILD_DIR ...]")

for raw in sys.argv[1:]:
    destination = Path(raw).resolve()
    if not (destination / "index.html").is_file():
        raise SystemExit(f"Not a completed web export: {destination}")
    for name in FILES:
        shutil.copy2(ROOT / "web" / name, destination / name)
    print(f"Copied legal pages to {destination}")
