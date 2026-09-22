"""Local, reproducible alpha cleanup and articulated pixel animation export.

Run from the project root. User-authorized local processing; no network calls.
Preserves generated sources. Motion uses torso, head, elbow, hand/prop, knee
and foot landmarks, rather than shifting a flat character image.
"""
from pathlib import Path
import json
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage
from scipy.interpolate import RBFInterpolator

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/chapter3_villain_concepts'
ART = ROOT / 'assets/images/characters/chapter3'
MANIFEST = json.loads((OUT / 'generation_manifest.json').read_text(encoding='utf-8'))
SIZE = (256, 320)
# Landmarks are in original source-image coordinates: head, chest, hips,
# screen-left shoulder/elbow/hand, screen-right shoulder/elbow/hand,
# left knee/foot, right knee/foot. Props follow the hand that holds them.
LANDMARKS = [
 [(0.52,.19),(.53,.40),(.52,.60),(.38,.31),(.28,.35),(.17,.31),(.70,.32),(.75,.39),(.65,.40),(.38,.73),(.35,.86),(.72,.75),(.80,.88)],
 [(.44,.13),(.47,.34),(.52,.51),(.37,.23),(.32,.36),(.23,.23),(.60,.26),(.66,.40),(.54,.45),(.40,.69),(.39,.92),(.65,.70),(.74,.93)],
 [(.49,.13),(.51,.37),(.51,.57),(.39,.22),(.28,.29),(.34,.26),(.65,.23),(.68,.39),(.50,.40),(.34,.69),(.29,.88),(.72,.74),(.77,.91)],
 [(.45,.14),(.48,.37),(.49,.56),(.35,.30),(.30,.43),(.41,.40),(.60,.28),(.69,.36),(.71,.22),(.35,.73),(.31,.92),(.64,.71),(.66,.86)],
 [(.53,.14),(.54,.35),(.53,.53),(.44,.27),(.33,.35),(.28,.36),(.65,.28),(.70,.40),(.74,.44),(.43,.73),(.39,.92),(.64,.73),(.71,.92)],
 [(.42,.16),(.48,.36),(.50,.55),(.30,.27),(.28,.38),(.32,.34),(.60,.25),(.65,.32),(.58,.20),(.33,.71),(.29,.87),(.67,.73),(.73,.91)],
 [(.37,.16),(.45,.38),(.45,.56),(.26,.29),(.21,.41),(.21,.47),(.60,.26),(.72,.36),(.76,.44),(.32,.72),(.28,.89),(.60,.73),(.65,.90)],
 [(.52,.14),(.52,.35),(.53,.54),(.40,.26),(.33,.34),(.23,.29),(.65,.28),(.70,.40),(.74,.51),(.45,.74),(.43,.91),(.59,.75),(.61,.93)],
]
PROPS = [(.12,.27),(.23,.28),(.36,.40),(.72,.09),(.17,.30),(.72,.13),(.82,.56),(.77,.82)]

def clean(source, index):
    rgb = np.asarray(Image.open(source).convert('RGB'))
    lo, hi = rgb.min(2), rgb.max(2)
    candidate = (lo >= 210) & ((hi.astype(int)-lo.astype(int)) <= 25)
    seeds = np.zeros(candidate.shape, bool)
    seeds[0,:] = seeds[-1,:] = True
    seeds[:,0] = seeds[:,-1] = True
    # Enclosed negative space in the drafting compass, never white clothing.
    if index == 4:
        for x,y in [(.158,.259),(.190,.307)]:
            seeds[int(y*rgb.shape[0]),int(x*rgb.shape[1])] = True
    if index == 3:
        # Small enclosed triangle below the raised roller arm.
        seeds[523,744] = True
    outside = ndimage.binary_propagation(seeds & candidate, mask=candidate)
    # Remove antialias fringe on the background side only; dark outlines remain.
    expanded = ndimage.binary_dilation(outside, iterations=1)
    outside |= expanded & (lo>165) & ((hi.astype(int)-lo.astype(int))<27)
    alpha = (~outside).astype(np.uint8)*255
    rgba = np.dstack((rgb,alpha))
    rgba[alpha==0,:3] = 0
    return Image.fromarray(rgba)

def normalize(im, index):
    box=im.getbbox()
    crop=im.crop(box)
    ratio=min(210/crop.width,270/crop.height)
    w,h=round(crop.width*ratio),round(crop.height*ratio)
    origin=np.array([(SIZE[0]-w)//2,310-h], dtype=float)
    canvas=Image.new('RGBA',SIZE)
    canvas.alpha_composite(crop.resize((w,h),Image.Resampling.NEAREST),tuple(origin.astype(int)))
    def coord(p):
        return (np.array(p)*im.width-np.array(box[:2]))*ratio+origin
    pts=np.array([coord(p) for p in LANDMARKS[index]])
    prop=coord(PROPS[index])
    return canvas,pts,prop

def articulated(frame, points, prop, kind, phase, index):
    p=points.copy(); dst=p.copy()
    # Each joint has an independent target, while the soles stay pinned during
    # grounded strikes. Curves return exactly to neutral at either end.
    pulse=math.sin(math.pi*phase)
    if kind in ('attack','attack2'):
        # Pull back -> accelerate into strike -> follow through -> recover.
        drive=float(np.interp(phase,[0,.24,.48,.62,.80,1],[0,-.45,1,.9,.25,0]))
        power=1.0 if kind=='attack' else 1.2
        active=5 if kind=='attack' else 8
        shoulder=3 if active==5 else 6
        elbow=4 if active==5 else 7
        angle=drive*power*(-.19 if kind=='attack' else .24)
        c,s=math.cos(angle),math.sin(angle)
        rot=np.array([[c,-s],[s,c]])
        shift=np.array([-9*drive*power,3*pulse])
        dst[:9] += shift
        dst[2] = p[2]+[-3*drive,3*pulse]
        for joint in (elbow,active):
            dst[joint]=p[shoulder]+rot@(p[joint]-p[shoulder])+shift+[-7*drive, -3*drive]
        dst[0] += [-2*drive,-2*pulse]
        dst[9] += [-4*drive,2*pulse]; dst[11] += [2*drive,2*pulse]
    elif kind=='guard':
        dst[:9] += [3*pulse,5*pulse]
        dst[2] += [0,3*pulse]
        dst[5] += [7*pulse,-8*pulse]; dst[8] += [-6*pulse,-9*pulse]
        dst[9] += [-3*pulse,2*pulse]; dst[11] += [3*pulse,2*pulse]
    elif kind=='hit':
        dst[:9] += [7*pulse,3*pulse]
        dst[0] += [3*pulse,-3*pulse]
        dst[5] += [-2*pulse,-3*pulse]; dst[8] += [4*pulse,-2*pulse]
        dst[2] += [2*pulse,2*pulse]
    elif kind=='walk':
        a=math.sin(phase*2*math.pi); b=abs(a)
        dst[:9] += [0,-2*b]
        dst[5] += [-4*a,0]; dst[8] += [4*a,0]
        dst[9] += [-5*a,-3*b]; dst[11] += [5*a,-3*b]
        dst[10] += [-6*a,-max(0,a)*4]; dst[12] += [6*a,-max(0,-a)*4]
    else:
        a=math.sin(phase*2*math.pi)
        dst[:9] += [0,-1.5*a]
        dst[0] += [0,-.5*a]
        dst[5] += [.6*a,0]; dst[8] += [-.6*a,0]
    # Carry the held object with its nearest hand; cane tip is grounded.
    hand=5 if np.linalg.norm(prop-p[5])<np.linalg.norm(prop-p[8]) else 8
    prop_dst=prop+(dst[hand]-p[hand])
    if index==7: prop_dst=prop.copy()
    # Fixed canvas edge anchors protect margins from drifting into the image.
    edges=np.array([(0,0),(128,0),(255,0),(0,160),(255,160),(0,319),(128,319),(255,319)],float)
    src=np.vstack((p,prop,edges)); target=np.vstack((dst,prop_dst,edges))
    # Thin-plate deformation keeps the character connected across elbows,
    # shoulders, hips and knees; nearest sampling preserves the pixel edges.
    inverse=RBFInterpolator(target,src-target,kernel='thin_plate_spline',smoothing=1.0)
    yy,xx=np.mgrid[:SIZE[1],:SIZE[0]]
    grid=np.column_stack((xx.ravel(),yy.ravel())).astype(float)
    mapped=np.rint(grid+inverse(grid)).astype(int)
    mapped[:,0]=mapped[:,0].clip(0,SIZE[0]-1)
    mapped[:,1]=mapped[:,1].clip(0,SIZE[1]-1)
    pixels=np.asarray(frame)[mapped[:,1],mapped[:,0]].reshape((SIZE[1],SIZE[0],4))
    return Image.fromarray(pixels)

def font(size):
    return ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',size)

def main():
    report=[]; previews=[]
    for i,v in enumerate(MANIFEST):
        slug=v['slug']; im=clean(OUT/'sources'/f'{slug}.png',i)
        im.save(OUT/f'{slug}.png')
        base,pts,prop=normalize(im,i)
        portrait=im.crop((int(LANDMARKS[i][0][0]*1254)-140, int(LANDMARKS[i][0][1]*1254)-130,
                          int(LANDMARKS[i][0][0]*1254)+140, int(LANDMARKS[i][0][1]*1254)+160))
        portrait.resize((96,96),Image.Resampling.NEAREST).save(OUT/f'{slug}_portrait.png')
        for kind,count in [('idle',8),('attack',12),('attack2',12),('guard',10),('hit',8),('walk',10)]:
            dest=ART/f'{slug}_{kind}'; dest.mkdir(parents=True,exist_ok=True)
            frames=[]
            for f in range(count):
                phase=f/(count if kind in ('idle','walk') else count-1)
                img=articulated(base,pts,prop,kind,phase,i)
                img.save(dest/f'frame_{f}.png'); frames.append(img)
                assert img.getbbox()[0]>0 and img.getbbox()[2]<SIZE[0], (slug,kind,'clipped')
            if kind in ('attack','attack2','guard'):
                assert len({f.tobytes() for f in frames})>=count//2,(slug,kind,'static clip')
                gif=[]
                for f in frames:
                    bg=Image.new('RGBA',SIZE,(28,38,49,255)); bg.alpha_composite(f)
                    gif.append(bg.convert('RGB'))
                gif[0].save(OUT/f'{slug}_{kind}.gif',save_all=True,append_images=gif[1:],duration=80,loop=0)
        report.append({'name':v['name'],'alpha_extrema':im.getchannel('A').getextrema(),
                       'source_bounds':im.getbbox(),'frame_size':SIZE,'frames':60})
        previews.append(im)
        print(slug,'alpha and 60 articulated frames exported',flush=True)
    sheet=Image.new('RGB',(1600,1300),(17,25,34)); d=ImageDraw.Draw(sheet)
    d.text((40,24),'CHAPTER 3 / PROVINCIAL CIRCUIT',font=font(30),fill='#f2d188')
    d.text((40,68),'Eight villains  |  2 attacks + 1 defense each  |  Boss pending',font=font(18),fill='#bac7d4')
    for i,(v,im) in enumerate(zip(MANIFEST,previews)):
        x=30+(i%4)*395; y=115+(i//4)*570
        d.rounded_rectangle((x,y,x+380,y+550),12,fill='#202e3c')
        crop=im.crop(im.getbbox()); crop.thumbnail((335,380),Image.Resampling.NEAREST)
        sheet.paste(crop,(x+(380-crop.width)//2,y+400-crop.height),crop)
        d.text((x+18,y+413),v['name'],font=font(22),fill='#fff1ce')
        d.text((x+18,y+444),v['title'],font=font(16),fill='#d8b768')
        for j,m in enumerate(v['moves']):
            d.text((x+18,y+473+j*23),('DEF  ' if j==2 else 'ATK  ')+m[0],font=font(16),fill=('#95d2b1' if j==2 else '#cfdae4'))
    sheet.save(OUT/'roster_preview.png')
    (OUT/'alpha_animation_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')

if __name__=='__main__': main()
