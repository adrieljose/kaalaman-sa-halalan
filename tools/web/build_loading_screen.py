"""Build a self-contained Godot HTML shell and an isolated local review build.
Image bytes are embedded unchanged; the game pack/engine are never re-exported.
"""
from pathlib import Path
import base64
import hashlib
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/loading_screen'
BASE = ROOT / 'output/chapter3_patch_notes/site'

def main():
    template = (ROOT / 'web/loading.template.html').read_text(encoding='utf-8')
    assets = {'LOGO': 'assets/images/ui/title_logo.png',
              'BACKGROUND': 'assets/images/backgrounds/menu_updated.png'}
    hashes = {}
    font = (ROOT / 'web/fonts/PressStart2P-Regular.ttf').read_bytes()
    template = template.replace('@@PIXEL_FONT@@', 'data:font/ttf;base64,' + base64.b64encode(font).decode())
    license_text = (ROOT / 'web/fonts/PressStart2P-OFL.txt').read_text(encoding='utf-8')
    template = template.replace('<head>', '<head>\n<!-- Embedded Press Start 2P font license:\n' + license_text.replace('--', '—') + '\n-->')
    for key, path in assets.items():
        data = (ROOT / path).read_bytes()
        uri = 'data:image/png;base64,' + base64.b64encode(data).decode()
        template = template.replace('@@' + key + '@@', uri)
        hashes[path] = hashlib.sha256(data).hexdigest()
    (ROOT / 'web/loading_shell.html').write_text(template, encoding='utf-8')
    assert BASE.is_dir(), 'Expected preserved production patch-notes build'
    original = (BASE / 'index.html').read_text(encoding='utf-8')
    config = re.search(r'const GODOT_CONFIG = (.*?);', original)[1]
    threads = re.search(r'const GODOT_THREADS_ENABLED = (.*?);', original)[1]
    html = template.replace('$GODOT_PROJECT_NAME','Kaalaman sa Halalan')
    html = html.replace('$GODOT_HEAD_INCLUDE','<link rel="icon" href="index.icon.png">')
    html = html.replace('$GODOT_URL','index.js').replace('$GODOT_THREADS_ENABLED',threads).replace('$GODOT_CONFIG',config)
    site = OUT / 'site'
    site.mkdir(parents=True, exist_ok=True)
    for path in BASE.iterdir():
        if path.is_file() and path.name != 'index.html':
            shutil.copy2(path, site / path.name)
    (site / 'index.html').write_text(html, encoding='utf-8')
    # Separate review page: no engine or game downloads, intentionally fixed at 38%.
    preview = re.sub(r'<script src="index.js".*?</script>', '<script>class Engine { static getMissingFeatures() { return []; } startGame(options) { options.onProgress(38,100); return new Promise(() => {}); } }</script>', html)
    (site / 'preview.html').write_text(preview, encoding='utf-8')
    preserved = [p.name for p in BASE.iterdir() if p.is_file() and p.name != 'index.html']
    for name in preserved:
        assert (BASE / name).read_bytes() == (site / name).read_bytes(), name
    report = {'image_sha256':hashes,'unchanged_build_files':preserved,
              'scope':'Local only. No deployment. Original logo/background bytes unchanged.'}
    (OUT / 'build_report.json').write_text(json.dumps(report,indent=2), encoding='utf-8')
    print(json.dumps(report,indent=2))

if __name__ == '__main__':
    main()
