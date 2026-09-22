"""Package real Godot recordings and report without touching game assets."""
from pathlib import Path
import json, hashlib, html
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/chapter3_combat'
spec=json.loads((Path(__file__).with_name('regular_combat_spec.json')).read_text())
cards=[]
for enemy in spec:
    skills=[]
    for slot,name in enumerate(enemy['names']):
        stem=enemy['slug']+'_'+str(slot)
        sources=sorted((OUT/'recordings'/stem).glob('frame_*.png'))
        if sources:
            frames=[]
            for source in sources:
                with Image.open(source) as im:
                    frames.append(im.resize((768,432),Image.Resampling.NEAREST).convert('RGB'))
            frames[0].save(OUT/(stem+'.gif'),save_all=True,append_images=frames[1:],duration=145,loop=0)
        skills.append(f'<figure><img loading="lazy" src="{stem}.gif" alt="{html.escape(name)} in game"><figcaption>{html.escape(name)}</figcaption></figure>')
    cards.append('<section><h2>'+enemy['slug'].replace('_',' ').title()+'</h2><div>'+''.join(skills)+'</div></section>')
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Chapter 3 — Combat review</title><style>body{margin:0;padding:24px;background:#181b25;color:#f4e8c6;font:16px system-ui}main{max-width:1500px;margin:auto}h1{color:#f3c56c}p{max-width:900px;line-height:1.6}section{padding:16px 0;border-top:1px solid #575045}section>div{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}figure{margin:0;background:#272936;border-radius:8px;overflow:hidden}img{width:100%;image-rendering:pixelated}figcaption{padding:12px;color:#f3c56c}a{color:#99dbe8}@media(max-width:900px){section>div{grid-template-columns:1fr}}</style><main><h1>Chapter 3 — Combat review</h1><p>Actual local Godot battle recordings: two attacks and one defense for each existing regular villain. The clips show Juan; the automated suite also runs every move against Maria. No deployment.</p><p><a href="IMPLEMENTATION.md">Implementation notes</a> · <a href="runtime_report.json">Runtime test results</a> · <a href="preservation_report.json">Original-asset verification</a></p>'''+''.join(cards)+'</main></html>'
(OUT/'preview.html').write_text(page,encoding='utf-8')
baseline=json.loads((OUT/'preserved_assets.json').read_text())
changed=[path for path,digest in baseline.items() if not (ROOT/path).exists() or hashlib.sha256((ROOT/path).read_bytes()).hexdigest()!=digest]
(OUT/'preservation_report.json').write_text(json.dumps({'checked':len(baseline),'changed':changed,'passed':not changed},indent=2))
assert not changed,changed
print('Review ready. Preservation PASS:',len(baseline))
