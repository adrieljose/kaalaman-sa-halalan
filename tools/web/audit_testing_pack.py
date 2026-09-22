"""Read-only check of the Godot testing export directory."""
from pathlib import Path
import struct
root = Path(__file__).resolve().parents[2]
blob = (root / 'build/web-testing/index.pck').read_bytes()
assert blob[:4] == b'GDPC'
base, offset = struct.unpack_from('<QQ', blob, 24)
count = struct.unpack_from('<I', blob, offset)[0]
cursor = offset + 4
names = []
sizes = []
for _ in range(count):
    length = struct.unpack_from('<I', blob, cursor)[0]
    cursor += 4
    names.append(blob[cursor:cursor+length].rstrip(b'\0').decode())
    sizes.append((struct.unpack_from('<Q', blob, cursor+length+8)[0], names[-1]))
    cursor += length + 36
assert not any('claudetocodex' in n or n.startswith(('res://output/', 'res://tools/', 'output/', 'tools/')) for n in names)
for chapter in range(1, 6):
    assert any(f'chapter_{chapter:02d}.tres' in n for n in names), chapter
assert sum('backgrounds/chapter5/' in n and n.endswith('.png.import') for n in names) == 9
assert any('data/wordlists/en.txt' in n for n in names)
assert any('data/wordlists/fil.txt' in n for n in names)
for asset in ('cityhall_bidding_floor_v2.png.import',
              'cityhall_session_hall_floor_v2.png.import',
              'enemy_limb_motion.gdshader'):
    assert any(asset in n for n in names), f'Missing encounter fix: {asset}'
print(f'PASS: {count} packaged entries; all 5 chapters, 9 Congress backgrounds, wordlists; no chat or tools/output files.')
print('\n'.join(f'{size:>10} {name}' for size, name in sorted(sizes, reverse=True)[:20]))
