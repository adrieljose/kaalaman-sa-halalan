"""Historical/shared base-pose builder, NOT the selectable attack registry.
Run build_player_ranged.py after this to package the current ranged replacements.
Legacy jab/cross/palm assets remain shared by the retained heroic combos.
"""
from pathlib import Path
import json, hashlib, shutil, math, wave
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.spatial import cKDTree
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/player_attacks'; OUT.mkdir(parents=True,exist_ok=True)
GEN=Path('C:/Users/Asus/.codex/generated_images/01a07070-f10d-7780-98c9-982a92835651')
DATA={
'male':('player_battle_idle','exec-90f23650-90e8-44ab-b8d1-a9948e5b98a5.png',['quick_jab','civic_cross','peoples_kick','ballot_breaker','bayanihan_strike']),
'female':('player_female_battle_idle','exec-705a7654-b0d5-4713-8af5-9fb4b16fc472.png',['swift_palm','civic_spin_kick','ballot_flurry','voters_vault','peoples_voice'])}
SIZE=(192,176)

def snapshot():
    paths=[p for p in (ROOT/'assets/images').rglob('*.png') if 'player_variations' not in p.parts]
    paths+=list((ROOT/'data').rglob('*.tres'))+list((ROOT/'data').rglob('*.json'))
    paths += [ROOT/'scripts/game_state.gd',ROOT/'scripts/board_controller.gd']
    return {str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}

def extract(im):
    a=np.array(im.convert('RGBA')); rgb=a[:,:,:3].astype(int)
    if a[:,:,3].min()==a[:,:,3].max():
        bg=(rgb.min(2)>200)&((rgb.max(2)-rgb.min(2))<25)
        a[:,:,3]=np.where(bg,0,255)
    else: a[:,:,3]=np.where(a[:,:,3]>127,255,0)
    poses=[]
    for row in range(5):
        for col in range(3):
            cell=a[round(row*im.height/5):round((row+1)*im.height/5),round(col*im.width/3):round((col+1)*im.width/3)].copy()
            labels,n=ndimage.label(cell[:,:,3]>0)
            areas=np.bincount(labels.ravel()); keep=labels==np.argmax(areas[1:])+1
            cell[~keep]=0
            image=Image.fromarray(cell); poses.append(image.crop(image.getbbox()))
    return poses

def normalize(im, ratio, original, key):
    im=im.resize((max(1,round(im.width*ratio)),max(1,round(im.height*ratio))),Image.Resampling.NEAREST)
    a=np.array(im); rgb=a[:,:,:3].astype(int)
    # Locate the head's dark hair connected region in the upper half.
    mask=(rgb.max(2)<90)&(a[:,:,3]>0)
    # Limit to the hair itself: an outline can connect hair to the shirt/arms.
    rows=mask[:min(60,im.height)].sum(axis=1)
    peak=int(np.argmax(rows))
    top=int(np.flatnonzero(rows>max(3,rows[peak]*.40))[0])
    mask[min(im.height,top+27):]=False
    lab,n=ndimage.label(mask)
    areas=np.bincount(lab.ravel()); hair=lab==np.argmax(areas[1:])+1
    yy,xx=np.where(hair)
    x0,x1,y0,y1=int(xx.min()),int(xx.max()+1),int(yy.min()),int(yy.max()+1)
    # Only head/face zone; raised arms outside this bounding region are retained.
    face_bottom=min(im.height,top+(40 if key=='male' else 47))
    x1=min(im.width,x1+5)
    saved=a.copy()
    a[y0:max(y0,face_bottom-5),x0:x1]=0
    head=original.crop((0,0,original.width,40 if key=='male' else 47))
    head=head.crop(head.getbbox())
    h=np.array(head)
    # The idle's little held pen is not part of the face or hair; attacks use
    # empty hands. Preserve the ponytail tie in the upper half.
    py,px=np.mgrid[:head.height,:head.width]
    pen=(py>head.height*.60)&(h[:,:,2]>h[:,:,0].astype(float)*1.15)&(h[:,:,2]>h[:,:,1].astype(float)*1.3)
    h[pen]=0; head=Image.fromarray(h)
    # Exact original pixels (no generated facial redesign), joined at the neck.
    target=Image.fromarray(a)
    neck_x=round((x0+x1)/2)
    neck_color=(169,77,29,255) if key=='male' else (232,174,133,255)
    ImageDraw.Draw(target).rectangle((neck_x-3,face_bottom-5,neck_x+3,face_bottom+4),fill=neck_color)
    target.alpha_composite(head,(max(0,neck_x-head.width//2),max(0,face_bottom-head.height)))
    # Snap all body colors to this character's existing palette.
    ref=np.array(original); palette=np.unique(ref[ref[:,:,3]>127,:3],axis=0)
    tree=cKDTree(palette.astype(float)); arr=np.array(target)
    opaque=arr[:,:,3]>127
    _,ix=tree.query(arr[opaque,:3]); arr[opaque,:3]=palette[ix]; arr[:,:,3]=opaque*255
    arr[~opaque]=0
    labels,n=ndimage.label(arr[:,:,3]>0)
    areas=np.bincount(labels.ravel())
    for ident in range(1,n+1):
        iy,ix=np.where(labels==ident)
        thin=(ix.max()-ix.min()<2 and iy.max()-iy.min()>12)
        if areas[ident]<5 or thin: arr[labels==ident]=0
    target=Image.fromarray(arr)
    canvas=Image.new('RGBA',SIZE)
    canvas.alpha_composite(target,((SIZE[0]-target.width)//2,175-target.height))
    return canvas

def warp(im,p,mode):
    # Local upper-body/arm/hip motion; sole baseline remains fixed.
    a=np.array(im); yy,xx=np.mgrid[:SIZE[1],:SIZE[0]]
    wave=math.sin(p*math.pi)
    torso=np.exp(-((yy-90)/38)**2)
    arm=np.exp(-((yy-72)/19)**2)*np.clip((xx-52)/45,0,1)
    dx=wave*(2*torso+(6 if mode=='strike' else -3)*arm)
    dy=wave*np.exp(-((yy-110)/38)**2)*1.5
    return Image.fromarray(a[np.clip(np.rint(yy-dy).astype(int),0,175),np.clip(np.rint(xx-dx).astype(int),0,191)])

def sound(key,slot,attack):
    sr=22050
    for phase in ['cast','impact']:
        duration=.17+slot*.025+(0 if phase=='cast' else .06)
        t=np.arange(round(sr*duration))/sr; p=t/duration
        rng=np.random.default_rng(500+slot+(20 if key=='female' else 0))
        hz=(150+slot*85+(80 if key=='female' else 0))*(1-.4*p)
        tone=np.sin(2*math.pi*np.cumsum(hz)/sr)
        signal=(rng.normal(0,1,len(t))*.42+tone*(.22 if phase=='cast' else .5))*np.sin(p*math.pi)**.3*np.exp(-p*4)*.4
        path=ROOT/'assets/audio/sfx/moves'/f'player_{attack}_{phase}.wav'
        with wave.open(str(path),'wb') as f:
            f.setnchannels(1); f.setsampwidth(2); f.setframerate(sr); f.writeframes((signal.clip(-1,1)*32767).astype('<i2').tobytes())

def main():
    baseline=OUT/'preserved_assets.json'
    if not baseline.exists(): baseline.write_text(json.dumps(snapshot(),indent=2))
    (OUT/'sources').mkdir(exist_ok=True)
    report=[]
    for key,(directory,source,ids) in DATA.items():
        shutil.copy2(GEN/source,OUT/'sources'/f'{key}.png')
        original=Image.open(ROOT/f'assets/images/characters/{directory}/frame_0.png').convert('RGBA')
        poses=extract(Image.open(GEN/source))
        # One scale for every pose prevents crouches being stretched upright.
        ratio=min(167/poses[2].height,185/max(p.width for p in poses))
        poses=[normalize(p,ratio,original,key) for p in poses]
        sheet=Image.new('RGBA',(SIZE[0]*4,SIZE[1]*5),'#263039')
        for slot,attack in enumerate(ids):
            folder=ROOT/'assets/images/characters/player_variations'/key/attack
            folder.mkdir(parents=True,exist_ok=True)
            frames=[]
            for n in range(18):
                which=0 if n<6 else 1 if n<=12 else 2
                p=(n%6)/5
                frame=warp(poses[slot*3+which],p,'strike' if which==1 else 'windup')
                frame.save(folder/f'frame_{n:02d}.png'); frames.append(frame)
            for col,im in enumerate([original]+poses[slot*3:slot*3+3]): sheet.alpha_composite(im,(col*SIZE[0],slot*SIZE[1]))
            sound(key,slot,attack)
            report.append({'character':key,'attack':attack,'frames':18,'contact_frame_zero_based':12})
        sheet.save(OUT/f'{key}_pose_review.png')
    current=snapshot(); old=json.loads(baseline.read_text())
    changed=[p for p,h in old.items() if current.get(p)!=h]
    assert not changed,changed
    (OUT/'asset_report.json').write_text(json.dumps({'animations':report,'preserved':len(old),'changed':changed},indent=2))
    print('Built 180 additive frames; preservation PASS',len(old))
if __name__=='__main__': main()
