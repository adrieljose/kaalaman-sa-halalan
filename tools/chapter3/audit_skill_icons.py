"""Verify every move change is icon-only, and all delivered PNGs are distinct."""
import hashlib,json,re
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'output/chapter3_skill_icons'
def gameplay(text):
    text=re.sub(r'load_steps=\d+','load_steps=ICON_COUNT_IGNORED',text)
    text=re.sub(r'^\[ext_resource type="Texture2D".*\]\n?','',text,flags=re.M)
    text=re.sub(r'^icon = .*\n?','',text,flags=re.M)
    return '\n'.join(line.strip() for line in text.splitlines() if line.strip())
baseline=json.loads((OUT/'original_resources.json').read_text())
changed=[p for p,old in baseline.items() if gameplay(old)!=gameplay((ROOT/p).read_text())]
manifest=json.loads((OUT/'manifest.json').read_text()); faults=[]; hashes=[]
for row in manifest:
    path=ROOT/row['icon']; img=Image.open(path).convert('RGBA')
    lo,hi=img.getchannel('A').getextrema()
    if img.size!=(64,64) or lo!=0 or hi<250: faults.append(row['key'])
    hashes.append(hashlib.sha256(path.read_bytes()).hexdigest())
    assert ('path="res://'+row['icon']+'"') in (ROOT/row['resource']).read_text()
report=dict(passed=not changed and not faults and len(set(hashes))==27,icon_count=len(manifest),non_icon_resource_changes=changed,invalid_icons=faults,unique_hashes=len(set(hashes)))
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2))
print(report)
assert report['passed']
