"""Package actual locally captured battle frames into small review GIFs."""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/cong_meow'
for folder in (OUT/'recordings').iterdir():
    if not folder.is_dir(): continue
    frames=[Image.open(p).convert('RGB').resize((768,576),Image.Resampling.NEAREST) for p in sorted(folder.glob('frame_*.png'))]
    if frames:
        frames[0].save(OUT/f'battle_{folder.name}.gif',save_all=True,append_images=frames[1:],duration=125,loop=0)
        print(folder.name,len(frames),'captured game frames')
