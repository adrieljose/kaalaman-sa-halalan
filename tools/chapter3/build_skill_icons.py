"""Package generated icon masters and prepare icon-only resource patches."""
import hashlib, html, json, re, shutil
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/chapter3_skill_icons'
DEST=ROOT/'assets/images/ui/skill_icons/chapter3'

def slug(name):
    return name.lower().replace("'",'').replace(' ','_')

def main():
    sources={r['id']:r for r in json.loads((OUT/'generated_sources.json').read_text(encoding='utf-8'))}
    for entry in (OUT/'source_entries').glob('*.json'):
        r=json.loads(entry.read_text(encoding='utf-8')); sources[r['id']]=r
    rows=[]; patch=['*** Begin Patch']; originals={}
    for enemy_file in sorted((ROOT/'data/enemies').glob('ch3_*.tres')):
        enemy_text=enemy_file.read_text(encoding='utf-8')
        enemy_name=re.search(r'^enemy_name = "([^"]+)"',enemy_text,re.M)[1]
        enemy_id=re.sub(r'^ch3_\d+_','',enemy_file.stem)
        for rel in re.findall(r'path="res://(data/moves/[^\"]+)"',enemy_text):
            path=ROOT/rel; original=path.read_text(encoding='utf-8')
            name=re.search(r'^move_name = "([^"]+)"',original,re.M)[1]
            key=slug(name); source=sources[key]
            matches=re.findall(r'[A-Z]:\\[^:\r\n]+?\.png',source['hint'])
            raw=Path(matches[-1]); assert raw.exists(),raw
            archive=OUT/'masters'/f'{key}.png'; archive.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(raw,archive)
            img=Image.open(raw).convert('RGBA')
            alpha=img.getchannel('A'); assert alpha.getextrema()==(0,255),f'Not transparent: {key}'
            box=alpha.getbbox(); crop=img.crop(box)
            # Packaging only: preserve generated art/alpha, fit within 64px,
            # integer nearest-neighbour sampling. No repainting or AI cleanup.
            crop.thumbnail((60,60),Image.Resampling.NEAREST)
            icon=Image.new('RGBA',(64,64)); icon.alpha_composite(crop,((64-crop.width)//2,(64-crop.height)//2))
            target=DEST/enemy_id/f'{key}.png'; target.parent.mkdir(parents=True,exist_ok=True)
            icon.save(target)
            resource_path='res://'+target.relative_to(ROOT).as_posix()
            modified=original
            match=re.search(r'^icon = ExtResource\("([^\"]+)"\)',original,re.M)
            if match:
                rid=match[1]
                modified=re.sub(r'(\[ext_resource type="Texture2D" path=")[^\"]+(" id="'+re.escape(rid)+r'"\])',lambda m:m[1]+resource_path+m[2],modified)
            else:
                modified=re.sub(r'load_steps=(\d+)',lambda m:f'load_steps={int(m[1])+1}',modified,count=1)
                modified=modified.replace('[resource]',f'[ext_resource type="Texture2D" path="{resource_path}" id="skill_icon"]\n\n[resource]')
                modified=modified.replace('script = ExtResource("1")','script = ExtResource("1")\nicon = ExtResource("skill_icon")',1)
            if modified!=original:
                patch.extend(['*** Update File: '+str(path).replace('\\','/'),'@@']+['-'+l for l in original.splitlines()]+['+'+l for l in modified.splitlines()])
            originals[rel]=original
            rows.append(dict(enemy=enemy_name,skill=name,key=key,resource=rel,icon=target.relative_to(ROOT).as_posix(),size=[64,64],sha256=hashlib.sha256(target.read_bytes()).hexdigest(),prompt=source['prompt']))
    assert len(rows)==27 and len({r['sha256'] for r in rows})==27
    baseline=OUT/'original_resources.json'
    if not baseline.exists(): baseline.write_text(json.dumps(originals,indent=2),encoding='utf-8')
    patch.append('*** End Patch')
    (OUT/'resource_icons.patch').write_text('\n'.join(patch)+'\n',encoding='utf-8')
    (OUT/'manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',14)
    board=Image.new('RGB',(990,9*130),(32,25,22)); draw=ImageDraw.Draw(board)
    cards=[]
    for i,row in enumerate(rows):
        x=(i%3)*330; y=(i//3)*130
        img=Image.open(ROOT/row['icon'])
        board.paste(img,(x+12,y+22),img)
        tiny=img.resize((16,16),Image.Resampling.NEAREST); board.paste(tiny,(x+90,y+35),tiny)
        draw.text((x+12,y+92),row['skill'],font=font,fill='#f5d98f')
        cards.append(f'<article><h3>{html.escape(row["skill"])}</h3><p>{html.escape(row["enemy"])}</p><img width="64" height="64" src="../../{row["icon"]}"> <img width="16" height="16" src="../../{row["icon"]}"></article>')
    board.save(OUT/'roster.png')
    (OUT/'preview.html').write_text('<!doctype html><meta charset="utf-8"><title>Chapter 3 skill icons</title><style>body{background:#201916;color:#f5d98f;font:15px system-ui;padding:24px}main{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}article{padding:16px;background:#33261d;border:1px solid #785633}img{image-rendering:pixelated}p{color:#c8bda7}</style><h1>Chapter 3 — 27 skill icons</h1><p>64×64 masters and actual 16×16 slot size. Local review only.</p><main>'+''.join(cards)+'</main>',encoding='utf-8')
    print('Packaged',len(rows),'unique transparent icons. Apply resource_icons.patch next.')

if __name__=='__main__': main()
