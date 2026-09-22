"""Animation-only additions. Existing enemy data, original art and poses untouched.
Uses supplied generated action sheets and local nearest-sampled joint motion.
"""
from pathlib import Path
import json, math, shutil, wave, hashlib
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.interpolate import RBFInterpolator

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/chapter3_combat'; OUT.mkdir(parents=True,exist_ok=True)
ART=ROOT/'assets/images/characters/chapter3/combat'
GEN=Path('C:/Users/Asus/.codex/generated_images/01a07070-f10d-7780-98c9-982a92835651')
SPEC=json.loads((Path(__file__).with_name('regular_combat_spec.json')).read_text())
SIZE=(256,320)

def snapshot():
    paths=list((ROOT/'data/enemies').glob('ch3_*.tres'))+[ROOT/'data/chapters/chapter_03.tres']
    paths+=list((ROOT/'assets/images/characters/chapter3').glob('*/*.png'))
    paths+=list((ROOT/'assets/images/backgrounds').glob('capitol_*.png'))
    paths+=list((ROOT/'assets/images/portraits').glob('enemy_*.png'))
    return {str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}

def sheets(im):
    a=np.array(im.convert('RGBA'))
    if a[:,:,3].min()==a[:,:,3].max():
        rgb=a[:,:,:3].astype(int)
        bg=(rgb[:,:,0]>170)&(rgb[:,:,2]>170)&(rgb[:,:,1]<100)
        # Fallback for actual checkerboard background: only neutral light areas.
        if bg.mean()<.1:
            neutral=(rgb.min(2)>185)&((rgb.max(2)-rgb.min(2))<22)
            seeds=np.zeros(neutral.shape,bool); seeds[0,:]=seeds[-1,:]=True; seeds[:,0]=seeds[:,-1]=True
            bg=ndimage.binary_propagation(seeds&neutral,mask=neutral)
        a[:,:,3]=np.where(bg,0,255)
    else: a[:,:,3]=np.where(a[:,:,3]>127,255,0)
    a[a[:,:,3]==0,:3]=0
    # Connected silhouettes, not rigid cell crops: outstretched feet/hands can
    # legitimately cross a nominal cell boundary. Ignore detached projectiles.
    labels,n=ndimage.label(a[:,:,3]>0)
    areas=np.bincount(labels.ravel()); ids=np.argsort(areas[1:])[-6:]+1
    poses=[]
    for ident in ids:
        mask=labels==ident; yy,xx=np.where(mask)
        box=(xx.min(),yy.min(),xx.max()+1,yy.max()+1)
        piece=a.copy(); piece[~mask]=0
        poses.append((box,Image.fromarray(piece).crop(box)))
    poses.sort(key=lambda pair: (round(pair[0][3]/im.height*2),pair[0][0]))
    # Top and bottom triplets sorted independently avoids a tall hand changing rows.
    poses.sort(key=lambda pair: pair[0][3])
    poses=sorted(poses[:3],key=lambda pair:pair[0][0])+sorted(poses[3:],key=lambda pair:pair[0][0])
    return [p[1] for p in poses]

def normalize(im, height):
    ratio=min(height/im.height,234/im.width)
    w,h=round(im.width*ratio),round(im.height*ratio)
    canvas=Image.new('RGBA',SIZE); canvas.alpha_composite(im.resize((w,h),Image.Resampling.NEAREST),((256-w)//2,310-h))
    return canvas

def motion(im, phase, kind):
    x,y,r,b=im.getbbox(); w=r-x; h=b-y
    f=[(.50,.12),(.51,.33),(.51,.55),(.35,.25),(.26,.38),(.15,.33),(.66,.25),(.75,.36),(.80,.32),(.33,.74),(.23,.97),(.75,.75),(.86,.98)]
    p=np.array([(x+a*w,y+c*h) for a,c in f]); dst=p.copy()
    a=math.sin(phase*math.pi); drive=math.sin(phase*2*math.pi)
    if kind=='walk':
        dst[:9]+=[0,-2*abs(drive)]; dst[5]+=[-6*drive,0]; dst[8]+=[6*drive,0]
        dst[9]+=[-9*drive,-4*abs(drive)]; dst[11]+=[9*drive,-4*abs(drive)]
        dst[10]+=[-10*drive,-max(0,drive)*7]; dst[12]+=[10*drive,-max(0,-drive)*7]
    elif kind=='impact':
        dst[:9]+=[-4*a,2*a]; dst[0]+=[-2*a,1*a]; dst[2]+=[-2*a,2*a]
        dst[5]+=[-7*a,-4*a]; dst[8]+=[-3*a,4*a]; dst[9]+=[-3*a,2*a]
    elif kind=='react':
        dst[:9]+=[6*a,2*a]; dst[0]+=[3*a,-3*a]; dst[5]+=[4*a,-4*a]; dst[8]+=[3*a,3*a]
        dst[9]+=[-2*a,2*a]; dst[10]+=[2*a,0]
    else:
        dst[:9]+=[2*a,3*a]; dst[0]+=[-1*a,1*a]; dst[5]+=[4*a,-5*a]; dst[8]+=[-4*a,-3*a]
        dst[2]+=[0,2*a]; dst[9]+=[-3*a,1*a]; dst[11]+=[3*a,1*a]
    edges=np.array([(0,0),(128,0),(255,0),(0,160),(255,160),(0,319),(128,319),(255,319)],float)
    src=np.vstack((p,edges)); target=np.vstack((dst,edges))
    inverse=RBFInterpolator(target,src-target,kernel='thin_plate_spline',smoothing=1)
    yy,xx=np.mgrid[:320,:256]; grid=np.column_stack((xx.ravel(),yy.ravel())).astype(float)
    mapped=np.rint(grid+inverse(grid)).astype(int)
    return Image.fromarray(np.asarray(im)[mapped[:,1].clip(0,319),mapped[:,0].clip(0,255)].reshape(320,256,4))

def sfx(index, slot, phase):
    # Per-enemy materials and attack/defense envelopes; distinct local synthesis.
    sr=22050; duration=.24 if phase=='cast' else .31
    t=np.arange(int(sr*duration))/sr; p=t/duration
    rng=np.random.default_rng(306+index*11+slot)
    frequencies=[780,410,170,1250,630,105,240,90]
    hz=frequencies[index]*(1.4 if slot==1 else 1)*(1-.45*p)
    angle=2*math.pi*np.cumsum(hz)/sr
    noise=rng.normal(0,1,len(t))
    tone=np.sin(angle)+.3*np.sin(angle*2.73)+.18*np.sin(angle*4.11)
    mix=.28 if index in (0,2,7) else .60
    signal=(tone*(1-mix)+noise*mix)*np.sin(math.pi*p)**.4*np.exp(-3*p)*.35
    path=ROOT/'assets/audio/sfx/moves'/f'c3combat_{SPEC[index]["ids"][slot]}_{phase}.wav'
    with wave.open(str(path),'wb') as out:
        out.setnchannels(1); out.setsampwidth(2); out.setframerate(sr); out.writeframes((signal.clip(-1,1)*32767).astype('<i2').tobytes())

def main():
    before=OUT/'preserved_assets.json'
    if not before.exists(): before.write_text(json.dumps(snapshot(),indent=2))
    (OUT/'sources').mkdir(exist_ok=True)
    report=[]
    for i,v in enumerate(SPEC):
        if v['source']=='PENDING': continue
        slug=v['slug']; shutil.copy2(GEN/v['source'],OUT/'sources'/f'{slug}.png')
        original=Image.open(ROOT/f'assets/images/characters/chapter3/{slug}_idle/frame_0.png').convert('RGBA')
        height=original.getbbox()[3]-original.getbbox()[1]
        poses=[normalize(p,height) for p in sheets(Image.open(OUT/'sources'/f'{slug}.png'))]
        clips={name:(poses[j],kind,8) for j,(name,kind) in enumerate([('windup','prep'),('strike','impact'),('prepare','prep'),('release','impact'),('brace','prep'),('block_hit','react')])}
        clips['walk']=(original,'walk',12)
        for name,(source,kind,count) in clips.items():
            folder=ART/slug/name; folder.mkdir(parents=True,exist_ok=True)
            frames=[]
            for n in range(count):
                frame=motion(source,n/(count-1),kind); frame.save(folder/f'frame_{n}.png'); frames.append(frame)
            # Strictly opaque/transparent edges and separate pose review tiles.
            source.save(OUT/f'{slug}_{name}.png')
            bgframes=[]
            for frame in frames:
                bg=Image.new('RGBA',SIZE,'#202533'); bg.alpha_composite(frame); bgframes.append(bg.convert('RGB'))
            bgframes[0].save(OUT/f'{slug}_{name}.gif',save_all=True,append_images=bgframes[1:],duration=70,loop=0)
        for slot in range(3):
            for phase in ('cast','impact'): sfx(i,slot,phase)
        report.append({'slug':slug,'frames':60,'poses':6,'original_height':height})
        print(slug,'60 animation-only frames',flush=True)
    (OUT/'asset_report.json').write_text(json.dumps(report,indent=2))
    original=json.loads(before.read_text()); current=snapshot()
    changed=[p for p,digest in original.items() if current.get(p)!=digest]
    assert not changed,('Existing assets changed',changed)
    print('Preservation PASS:',len(original),'existing files unchanged')

if __name__=='__main__': main()
