"""Read-only art audit plus a generated preview of completed image outputs."""
import json,re
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/chapter4_skill_icons'
rows=[]
for entry in sorted((OUT/'source_entries').glob('*.json')):
    row=json.loads(entry.read_text())
    raw=Path(re.findall(r'[A-Z]:\\[^:\r\n]+?\.png',row['hint'])[-1])
    im=Image.open(raw).convert('RGBA')
    alpha=im.getchannel('A')
    box=alpha.getbbox()
    crop=im.crop(box); crop.thumbnail((60,60),Image.Resampling.NEAREST)
    rows.append((row['id'],crop,alpha.getextrema()))
board=Image.new('RGB',(900,max(1,(len(rows)+3)//4)*120),'#241c16')
draw=ImageDraw.Draw(board); font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',12)
for i,(name,im,extrema) in enumerate(rows):
    x=i%4*225; y=i//4*120
    board.paste(im,(x+10,y+10),im)
    icon=Image.new('RGBA',(64,64)); icon.alpha_composite(im,((64-im.width)//2,(64-im.height)//2))
    tiny=icon.resize((16,16),Image.Resampling.NEAREST); board.paste(tiny,(x+94,y+28),tiny)
    draw.text((x+10,y+82),name,font=font,fill='#f5d98f')
    draw.text((x+10,y+99),str(extrema),font=font,fill='#aaa799')
board.save(OUT/'source_review.png')
print(json.dumps({'completed':len(rows),'alpha':[{'id':r[0],'range':r[2]} for r in rows]}))
