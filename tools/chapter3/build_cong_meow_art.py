"""Reproducible local boss frames + synthesized short SFX. No network/PixelLab.
Original generated poses stay in output/cong_meow/sources. Nearest sampling only.
"""
from pathlib import Path
import json, math, shutil, wave
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
import build_villain_art as rig

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/cong_meow'
ART = ROOT / 'assets/images/characters/chapter3'
GEN = Path('C:/Users/Asus/.codex/generated_images/01a07070-f10d-7780-98c9-982a92835651')
SOURCES = {'idle':'exec-6f876575-ae2d-4f62-a2f4-4b6a339c8395.png',
           'phone':'exec-2956b151-6b09-433f-8e2b-ee94a6169d60.png',
           'claw':'exec-8f05628f-0731-4bbe-8c98-fcac1d23dc05.png',
           'reaction':'exec-3184856a-b93a-4533-9e42-6d4ac8e7815c.png'}

def clean(im):
    a = np.array(im.convert('RGBA'))
    if a[:,:,3].min() < 128:
        a[:,:,3] = np.where(a[:,:,3] > 127,255,0)
    else:
        rgb = a[:,:,:3].astype(int)
        white = (rgb.min(2)>205)&((rgb.max(2)-rgb.min(2))<28)
        seeds=np.zeros(white.shape,bool); seeds[0,:]=seeds[-1,:]=True; seeds[:,0]=seeds[:,-1]=True
        bg=ndimage.binary_propagation(seeds&white,mask=white)
        labels,number=ndimage.label(white & ~bg)
        areas=np.bincount(labels.ravel())
        # Purple/black clothing has no large white patches. Remove enclosed
        # background under the bent elbow, but preserve tiny eyes/teeth.
        for label in range(1,number+1):
            if areas[label]>1200: bg|=labels==label
        a[:,:,3]=np.where(bg,0,255)
    a[a[:,:,3]==0,:3]=0
    return Image.fromarray(a)

def norm(im, scale=None):
    box=im.getbbox(); crop=im.crop(box)
    scale=scale or 270/crop.height
    size=(round(crop.width*scale),round(crop.height*scale))
    pos=((256-size[0])//2,310-size[1])
    result=Image.new('RGBA',(256,320)); result.alpha_composite(crop.resize(size,Image.Resampling.NEAREST),pos)
    return result

def joints(im):
    x,y,r,b=im.getbbox(); w=r-x; h=b-y
    fractions=[(.45,.14),(.5,.34),(.51,.52),(.36,.25),(.24,.34),(.12,.25),(.67,.24),(.79,.34),(.79,.43),(.30,.70),(.22,.96),(.75,.73),(.86,.98)]
    return np.array([(x+a*w,y+c*h) for a,c in fractions])

def main():
    (OUT/'sources').mkdir(parents=True,exist_ok=True)
    for name,source in SOURCES.items(): shutil.copy2(GEN/source,OUT/'sources'/f'{name}.png')
    idle=norm(clean(Image.open(OUT/'sources/idle.png')))
    phone=norm(clean(Image.open(OUT/'sources/phone.png')))
    sheet=clean(Image.open(OUT/'sources/claw.png')); w,h=sheet.size
    poses=[norm(sheet.crop((x*w//2,y*h//2,(x+1)*w//2,(y+1)*h//2)),.39) for y in range(2) for x in range(2)]
    reactions=clean(Image.open(OUT/'sources/reaction.png')); rw,rh=reactions.size
    hurt=norm(reactions.crop((0,0,rw//2,rh)))
    guard=norm(reactions.crop((rw//2,0,rw,rh)))
    clips={'idle':(idle,'idle',8),'walk':(idle,'walk',10),'hit':(hurt,'hit',8),
           'guard':(guard,'guard',12),'phone':(phone,'idle',16),
           'anticipate':(poses[0],'guard',6),'slash1':(poses[1],'attack',6),
           'slash2':(poses[2],'attack2',6),'slash3':(poses[3],'attack',8)}
    manifest={}
    for name,(source,motion,count) in clips.items():
        pts=joints(source)
        if name=='phone':
            pts[5]=[79,112]; pts[8]=[111,111]; pts[4]=[94,145]; pts[7]=[146,137]
        frames=[]; folder=ART/f'cong_meow_{name}'; folder.mkdir(parents=True,exist_ok=True)
        for n in range(count):
            phase=n/(count-1)
            frame=rig.articulated(source,pts,pts[5],motion,phase,0)
            if name=='phone':
                # Independent tapping hand motion, phone stays held in the other hand.
                moving=pts.copy(); moving[8]+=[-4*math.sin(phase*math.pi*6),-1*math.sin(phase*math.pi*6)]
                moving[7]+=[-2*math.sin(phase*math.pi*6),0]
                moving[0]+=[-1*math.sin(phase*math.pi*2),1]
                edges=np.array([(0,0),(255,0),(0,319),(255,319)],float)
                src=np.vstack((pts,edges)); target=np.vstack((moving,edges))
                inverse=rig.RBFInterpolator(target,src-target,kernel='thin_plate_spline',smoothing=1)
                yy,xx=np.mgrid[:320,:256]; grid=np.column_stack((xx.ravel(),yy.ravel())).astype(float)
                mapped=np.rint(grid+inverse(grid)).astype(int)
                frame=Image.fromarray(np.asarray(source)[mapped[:,1].clip(0,319),mapped[:,0].clip(0,255)].reshape(320,256,4))
            frame.save(folder/f'frame_{n}.png'); frames.append(frame)
        frames[0].save(OUT/f'{name}.png')
        # Contact-sheet backgrounds are separate preview imagery, not sprite alpha.
        previews=[]
        for frame in frames:
            bg=Image.new('RGBA',frame.size,'#181c2b'); bg.alpha_composite(frame); previews.append(bg.convert('RGB'))
        previews[0].save(OUT/f'{name}.gif',save_all=True,append_images=previews[1:],duration=85,loop=0)
        manifest[name]={'frames':count,'size':[256,320]}
    portrait=idle.crop((78,34,161,119)).resize((128,128),Image.Resampling.NEAREST)
    portrait.save(ROOT/'assets/images/portraits/enemy_cong_meow.png')
    icons=ROOT/'assets/images/ui/cong_meow'; icons.mkdir(parents=True,exist_ok=True)
    for name in ('claw','phone','shield'):
        icon=Image.new('RGBA',(24,24)); d=ImageDraw.Draw(icon)
        if name=='claw':
            for x in (4,10,16): d.line([(x,3),(x+2,11),(x+6,20)],fill='#ffda80',width=2)
        elif name=='phone':
            d.rectangle((5,1,19,22),fill='#302438',outline='#ffe09c',width=2)
            d.rectangle((8,5,16,15),fill='#83e4ee'); d.rectangle((11,18,13,19),fill='#ffe09c')
        else:
            d.polygon([(3,2),(8,6),(16,6),(21,2),(20,17),(12,23),(4,17)],fill='#ffe09c')
            d.rectangle((7,10,9,12),fill='#493151'); d.rectangle((15,10,17,12),fill='#493151')
        icon.save(icons/f'{name}.png')
    (OUT/'animation_manifest.json').write_text(json.dumps(manifest,indent=2))
    sounds={'dash':(.19,160,60),'swipe':(.16,900,120),'impact':(.18,140,35),
            'tap':(.065,1600,1100),'notification':(.18,700,1350),'digital':(.24,1100,300),
            'meow':(.36,600,210),'activation':(.48,350,1100),'hum':(.65,220,222),
            'shield_hit':(.23,1200,540),'shield_break':(.38,1600,130)}
    audio=ROOT/'assets/audio/sfx/moves'; audio.mkdir(parents=True,exist_ok=True)
    rng=np.random.default_rng(303)
    for name,(duration,f0,f1) in sounds.items():
        sr=22050; t=np.arange(int(sr*duration))/sr; p=t/duration
        hz=f0+(f1-f0)*p
        if name=='meow': hz*=1+.22*np.sin(p*math.pi*2)
        phase=2*math.pi*np.cumsum(hz)/sr
        signal=.65*np.sin(phase)+.2*np.sin(phase*2)+.10*np.sign(np.sin(phase*.5))
        if name in ('dash','swipe','impact','shield_break'): signal+=rng.normal(0,.35,len(t))
        signal*=np.sin(math.pi*p)**.8*np.exp(-2*p)*.34
        with wave.open(str(audio/f'cong_meow_{name}_cast.wav'),'wb') as wav:
            wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(sr); wav.writeframes((signal.clip(-1,1)*32767).astype('<i2').tobytes())
    print('CONG MEOW exported',sum(v['frames'] for v in manifest.values()),'frames;',len(sounds),'SFX')

if __name__=='__main__': main()
