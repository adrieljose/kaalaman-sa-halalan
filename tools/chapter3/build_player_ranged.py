"""Reuse approved player poses non-destructively; generate new local SFX only."""
from pathlib import Path
import json, hashlib, shutil, wave, math
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/player_ranged'; OUT.mkdir(parents=True,exist_ok=True)
ART=ROOT/'assets/images/characters/player_variations'
MAPPING={'male':{'ballot_bolt':'quick_jab','peoples_volley':'ballot_breaker'},'female':{'civic_spark':'swift_palm','ballot_barrage':'peoples_voice'}}
def main():
    baseline=OUT/'preserved_assets.json'
    if not baseline.exists():
        paths=list(ART.rglob('*.png'))+list((ROOT/'data').rglob('*'))
        baseline.write_text(json.dumps({str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths if p.is_file()},indent=2))
    report=[]
    for character,mapping in MAPPING.items():
        for n,(new,old) in enumerate(mapping.items()):
            folder=ART/character/new; folder.mkdir(parents=True,exist_ok=True)
            for src in (ART/character/old).glob('*.png'): shutil.copy2(src,folder/src.name)
            # Distinct waves/launch timbres through the existing SFX bus.
            count=1 if n==0 else 3 if character=='male' else 5
            for k,phase in enumerate(['cast','impact','light']+[f'launch{i+1}' for i in range(count)]):
                sr=22050; duration=.14+(0.09 if phase=='impact' else .02*k)
                t=np.arange(int(sr*duration))/sr; p=t/duration
                hz=(260+100*n+60*k+(240 if character=='female' else 0))*(1-.25*p)
                tone=np.sin(2*math.pi*np.cumsum(hz)/sr)
                noise=np.random.default_rng(884+n*20+k).normal(0,1,len(t))
                signal=(tone*.4+noise*(.12 if character=='female' else .32))*np.sin(p*math.pi)**.3*np.exp(-3*p)*.35
                target=ROOT/'assets/audio/sfx/moves'/f'player_{new}_{phase}.wav'
                with wave.open(str(target),'wb') as f:
                    f.setnchannels(1); f.setsampwidth(2); f.setframerate(sr); f.writeframes((signal*32767).astype('<i2').tobytes())
            report.append({'character':character,'attack':new,'source_pose':old,'frames':18,'projectiles':count})
    old=json.loads(baseline.read_text()); changed=[p for p,h in old.items() if hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h]
    assert not changed,changed
    (OUT/'asset_report.json').write_text(json.dumps({'attacks':report,'preserved':len(old),'changed':changed},indent=2))
    print('Ranged assets ready: 72 copied pose frames, 22 sounds. Original assets unchanged:',len(old))
if __name__=='__main__': main()
