"""Build an offline review page from the actual Godot test recordings."""
from pathlib import Path
import json, html, hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/player_ranged'
NAMES={'male':['Ballot Bolt',"People's Volley","People's Kick",'Ballot Breaker','Bayanihan Strike'],
'female':['Civic Spark','Ballot Barrage','Ballot Flurry',"Voter's Vault","People's Voice"]}
cards=[]
for key,names in NAMES.items():
    rows=[]
    for slot,name in enumerate(names):
        sources=sorted((OUT/'recordings'/f'{key}_{slot}').glob('frame_*.png'))
        frames=[]
        for source in sources:
            with Image.open(source) as image: frames.append(image.resize((768,432),Image.Resampling.NEAREST).convert('RGB'))
        if frames: frames[0].save(OUT/f'{key}_{slot}.gif',save_all=True,append_images=frames[1:],duration=140,loop=0)
        rows.append(f'<figure><img loading="lazy" src="{key}_{slot}.gif" alt="{html.escape(name)} actual battle"><figcaption>{html.escape(name)}</figcaption></figure>')
    cards.append('<section><h2>'+('Juan' if key=='male' else 'Maria')+'</h2><div>'+''.join(rows)+'</div></section>')
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Juan & Maria — Player attacks</title><style>body{background:#19222a;color:#f6e9c7;font:16px system-ui;margin:0;padding:24px}main{max-width:1500px;margin:auto}h1,h2{color:#f3c971}p{max-width:960px;line-height:1.6}section>div{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px}figure{margin:0;background:#2c3741;border:1px solid #50626b;border-radius:8px;overflow:hidden}img{width:100%;image-rendering:pixelated}figcaption{padding:12px}a{color:#91dfdd}section{margin-top:32px}@media(max-width:800px){section>div{grid-template-columns:1fr}}</style><main><h1>Juan & Maria — Five attacks each</h1><p>Actual local Godot recordings against Bokal Bulsa's shield. Every animation receives the same 30 damage input; his existing 35% defense reduces it to 20 after rounding. Multi-hit sequences apply that total once, on the final contact. The test suite also covers other Chapters 1–3 enemies and bosses.</p><p><a href="IMPLEMENTATION.md">Implementation and limitations</a> · <a href="runtime_report.json">Runtime tests</a> · <a href="asset_report.json">Assets and preservation</a> · <a href="generation_prompts.json">Generation prompts</a></p>'''+''.join(cards)+'</main></html>'
page=page.replace('Five attacks each','Five attacks each — 2 ranged + 3 close')
page=page.replace('<a href="generation_prompts.json">Generation prompts</a>','<a href="ranged_report.json">All-defense ranged tests</a>')
(OUT/'preview.html').write_text(page,encoding='utf-8')
baseline=json.loads((OUT/'preserved_assets.json').read_text())
changed=[p for p,h in baseline.items() if hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h]
player_paths=[p for p in baseline if p.startswith('assets/images/characters/player_variations/')]
player_changed=[p for p in changed if p in player_paths]
(OUT/'preservation_report.json').write_text(json.dumps({'checked':len(baseline),'player_art_checked':len(player_paths),'player_art_changed':player_changed,'other_workspace_changes': [p for p in changed if p not in player_paths],'player_art_passed':not player_changed},indent=2))
assert not player_changed,player_changed
print('Player review ready; player art preservation PASS',len(player_paths))
