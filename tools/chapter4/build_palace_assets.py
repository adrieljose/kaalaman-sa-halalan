"""Package generated artwork without repainting; synthesize quiet local ambience.
Run after the ten generation provenance JSONs exist. No network or deployment.
"""
from pathlib import Path
import json, re, shutil, wave, subprocess
import numpy as np
from PIL import Image, ImageDraw
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/chapter4_environments'
ART = ROOT / 'assets/images/backgrounds/chapter4'
AUDIO = ROOT / 'assets/audio/ambience/palace'
ART.mkdir(parents=True, exist_ok=True)
AUDIO.mkdir(parents=True, exist_ok=True)
cards = []
manifest = []
for spec_path in sorted(OUT.glob('*_generation.json')):
	
    if spec_path.name == 'npcs_generation.json' and (OUT/'npcs_alpha_generation.json').exists():
        continue
    data = json.loads(spec_path.read_text(encoding='utf-8'))
    source = Path(re.search(r'as (C:\\.*?\.png) by default', data['output_hint']).group(1))
    im = Image.open(source).convert('RGBA')
    if spec_path.name.startswith('npcs_'):
        # Six equal cells requested at generation. Trim transparent margins only.
        for i in range(6):
            cell = im.crop((i*im.width//6, 0, (i+1)*im.width//6, im.height))
            # Alpha-weighted trim ignores nearly invisible generator padding.
            box = cell.getchannel('A').point(lambda a: 255 if a > 192 else 0).getbbox()
            if box is None: raise ValueError('Missing NPC cell '+str(i))
            cell = cell.crop(box)
            cell.thumbnail((48,72), Image.Resampling.NEAREST)
            cell.save(ART / f'npc_{i}.png')
        shutil.copy2(source, OUT/'npc_master.png')
        continue
    slug = data['slug']
    # Standardized low-memory texture; closest-neighbour retains crisp pixel edges.
    packed = im.resize((768,512), Image.Resampling.NEAREST).convert('RGB')
    packed.save(ART / (slug+'.png'), optimize=True)
    card = Image.new('RGB',(384,282),'#18212a')
    card.paste(packed.resize((384,256),Image.Resampling.NEAREST),(0,0))
    ImageDraw.Draw(card).text((8,264),slug,fill='#f1dcab')
    cards.append(card)
    manifest.append({'id':slug,'path':str(ART/(slug+'.png')),'source':str(source),'dimensions':[768,512]})
sheet = Image.new('RGB',(384*3,282*3),'#18212a')
for i,card in enumerate(cards): sheet.paste(card,((i%3)*384,(i//3)*282))
sheet.save(OUT/'roster.png')
(OUT/'assets_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')

# Synthesized non-verbal room beds. No voice service, recordings, or paid API.
sr, duration = 22050, 40
t = np.arange(sr*duration)/sr
for i,name in enumerate(['courtyard','garden','press','operations','office','hall']):
    rng = np.random.default_rng(480+i)
    noise = rng.normal(0,1,len(t))
    low = sosfilt(butter(2,450,fs=sr,output='sos'),noise)
    signal = low*(.06+.018*np.sin(2*np.pi*t/17))
    if name in ['garden','hall']:
        water = sosfilt(butter(2,[800,3200],btype='bandpass',fs=sr,output='sos'),noise)
        signal += water*.019*(1+.15*np.sin(t*.9))
    if name in ['courtyard','garden']:
        for start in [8.7,21.3,32.1]:
            u=t-start; mask=(u>0)&(u<.24)
            signal[mask] += .025*np.sin(2*np.pi*(1700*u[mask]+1300*u[mask]**2))*np.sin(np.pi*u[mask]/.24)**2
    if name in ['office','press','hall']:
        signal += .008*np.sin(2*np.pi*90*t)+.003*np.sin(2*np.pi*180*t)
    if name=='press':
        for start in [11.2,28.6]:
            u=t-start; mask=(u>=0)&(u<.05)
            signal[mask] += noise[mask]*.025*np.exp(-u[mask]*70)
    if name=='operations':
        signal += .013*np.sin(2*np.pi*65*t)*np.exp(-((t-22)/4)**2)
    if name=='office':
        for start in range(1,40,3):
            u=t-start; mask=(u>=0)&(u<.025)
            signal[mask] += .01*np.sin(2*np.pi*1700*u[mask])*np.exp(-u[mask]*130)
    fade=np.minimum(np.minimum(t/.5,(duration-t)/.5),1)
    signal = np.clip(signal*fade,-.8,.8)
    path=OUT/(name+'_ambience_master.wav')
    with wave.open(str(path),'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(sr)
        f.writeframes((signal*32767).astype('<i2').tobytes())
    subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(path),'-c:a','libvorbis','-q:a','2',str(AUDIO/(name+'.ogg'))],check=True)
print('Packaged',len(cards),'environments, 6 NPCs, 6 ambient beds')
