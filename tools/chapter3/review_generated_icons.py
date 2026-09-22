from pathlib import Path
from PIL import Image,ImageDraw
root=Path('C:/Users/Asus/.codex/generated_images/01a07070-f10d-7780-98c9-982a92835651')
files=sorted(root.glob('*.png'),key=lambda p:p.stat().st_mtime)
start=next(i for i,p in enumerate(files) if p.name=='exec-c10addf7-1aa5-45a4-b5ac-411dbb29bd58.png')
files=files[start:]
out=Path('output/chapter3_skill_icons'); out.mkdir(parents=True,exist_ok=True)
board=Image.new('RGB',(900,((len(files)+5)//6)*170),'#302820'); d=ImageDraw.Draw(board)
for i,p in enumerate(files):
    im=Image.open(p).convert('RGBA'); im.thumbnail((140,140))
    x=(i%6)*150;y=(i//6)*170
    board.paste(im,(x,y),im);d.text((x,y+142),str(i)+' '+p.stem[5:13],fill='white')
    print(i,p.name)
board.save(out/'source_review.png')
