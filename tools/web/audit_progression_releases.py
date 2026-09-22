"""Read-only verification of the two progression release packs."""
from pathlib import Path
import hashlib
import struct

ROOT = Path(__file__).resolve().parents[2]
for folder, testing in [('web', False), ('web-testing', True)]:
    pack = ROOT / 'build' / folder / 'index.pck'
    blob = pack.read_bytes()
    assert blob[:4] == b'GDPC'
    base, directory = struct.unpack_from('<QQ', blob, 24)
    count = struct.unpack_from('<I', blob, directory)[0]
    cursor = directory + 4
    entries = {}
    for _ in range(count):
        length = struct.unpack_from('<I', blob, cursor)[0]
        cursor += 4
        name = blob[cursor:cursor+length].rstrip(b'\0').decode().removeprefix('res://')
        cursor += length
        start, size = struct.unpack_from('<QQ', blob, cursor)
        entries[name] = blob[base+start:base+start+size]
        cursor += 36
    assert (b'testing_chapters' in entries['project.binary']) == testing, folder
    assert not any(n.startswith(('output/', 'tools/', 'archive/', 'build/')) or 'claudetocodex' in n for n in entries)
    for chapter in range(1, 6):
        assert any(f'chapter_{chapter:02d}.tres' in n for n in entries), chapter
    for stem in ('cityhall_bidding_floor_v2', 'cityhall_session_hall_floor_v2', 'enemy_limb_motion'):
        assert any(stem in n for n in entries), stem
    for script in ('game_state', 'main_menu', 'ui/animated_character'):
        assert 'scripts/'+script+'.gdc' in entries
    html = (pack.parent/'index.html').read_text(encoding='utf-8')
    assert 'ANG BAWAT BOTO, MAY HALAGA' in html
    assert 'LOCAL DESIGN PREVIEW' not in html
    print(folder, 'PASS', 'testing_chapters='+str(testing), 'entries='+str(count),
          'sha256='+hashlib.sha256(blob).hexdigest())
