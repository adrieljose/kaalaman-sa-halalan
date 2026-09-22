"""Prepare only the approved loading HTML and unchanged production game files."""
import base64
import hashlib
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'output/loading_screen/site'
BASE = ROOT / 'output/chapter3_patch_notes/site'
DEST = ROOT / 'output/loading_screen/release_2026_09_12'

html = (SOURCE / 'index.html').read_text(encoding='utf-8')
assert 'LOCAL DESIGN PREVIEW' not in html
assert 'KAALAMAN ANG UNANG HAKBANG' not in html
assert '<footer' not in html
assert '@@' not in html and '$GODOT_' not in html
assert 'class Engine {' not in html
assert 'Press Start 2P' in html and 'ANG BAWAT BOTO, MAY HALAGA' in html
assert '<script src="index.js"' in html
assert 'await engine.startGame(' in html
logo = re.search(r'<img class="logo" src="data:image/png;base64,([^"]+)"', html)[1]
assert base64.b64decode(logo) == (ROOT / 'assets/images/ui/title_logo.png').read_bytes()
config = json.loads(re.search(r'const GODOT_CONFIG = (.*?);', html)[1])
assert config == json.loads(re.search(r'const GODOT_CONFIG = (.*?);', (BASE / 'index.html').read_text(encoding='utf-8'))[1])
assert not DEST.exists(), 'Release folder already exists; do not overwrite it.'
DEST.mkdir(parents=True)
files = {}
for original in BASE.iterdir():
    if not original.is_file():
        continue
    candidate = SOURCE / original.name
    if original.name != 'index.html':
        assert candidate.read_bytes() == original.read_bytes(), original.name
    shutil.copy2(candidate, DEST / original.name)
    files[original.name] = hashlib.sha256(candidate.read_bytes()).hexdigest()
assert len(files) == 10
assert not (DEST / 'preview.html').exists()
(DEST / '.vercel').mkdir()
shutil.copy2(BASE / '.vercel/project.json', DEST / '.vercel/project.json')
report = {'source_deployment':'dpl_HWrbbwSCf7MbfnQxsuV6rEX7E8DW',
          'changed_files':['index.html'], 'unchanged_game_files':9,
          'unchanged_logo':True, 'preview_excluded':True, 'files_sha256':files}
(DEST.parent / 'release_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
