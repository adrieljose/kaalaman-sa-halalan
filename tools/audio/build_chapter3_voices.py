"""Build AI-generated local-review speech with Edge TTS, not voice cloning.

All characters use Filipino Angelo with fixed character-specific prosody/EQ.
These are processed identities, not nine independently trained actors.
No paid API, game runtime network call, or deployment is involved.
"""
import asyncio, hashlib, html, json, shutil, subprocess
from pathlib import Path
import edge_tts

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/speech/chapter3'
DEST = ROOT / 'assets/audio/sfx/voices/chapter3'
# id, name, pitch Hz, rate %, EQ frequency/gain, exact supplied lines.
PROFILES = [
 ('bokal_bulsa','Bokal Bulsa',-7,15,500,2,["Aray! Grabe naman!","Agh! Sapul!","Naku! Ang sakit!","Teka lang naman!","Naubos... ang suporta ko..."]),
 ('assessor_altapresyo','Assessor Altapresyo',9,18,1600,3,["Aray! Mali ang tantya ko!","Agh! Sobra naman 'yan!","Teka—aray!","Hindi kasama 'yan sa assessment!","Mali... ang assessment..."]),
 ('treasurer_tago','Treasurer Tago',-18,24,700,3,["Aray!","Agh! Napuruhan!","Naku, naku!","Teka! Ingat!","Isara... ang vault..."]),
 ('auditor_alibi','Auditor Alibi',2,11,1000,2,["Aray! Ire-report ko 'yan!","Agh! May finding ako diyan!","Sapul!","Teka, teka!","Ito... ay may finding..."]),
 ('planner_palusot','Planner Palusot',19,32,2100,2,["Aray! Hindi 'yan nasa plano!","Agh! Revised plan!","Naku! Sablay!","Teka lang!","Kailangan... ng bagong plano..."]),
 ('engineer_eskandalo','Engineer Eskandalo',-30,8,190,4,["Argh! Matibay ah!","Aray! Sapul!","Agh! Napuruhan!","Naku! Safety first!","Project... down..."]),
 ('contractor_kutsaba','Contractor Kutsaba',-3,23,350,2,["Aray! Dagdag trabaho 'to!","Agh! Change order!","Sapul!","Teka lang naman!","Cancel... ang kontrata..."]),
 ('project_padrino','Project Padrino',-38,0,150,3,["Ugh... lucky hit.","Hmph... hindi masama.","Argh!","Tsk... sapul mo 'ko.","Hmph... hindi pa ito ang huli..."]),
 ('cong_meow','Cong Meow',26,20,2700,2,["ME-OWCH!","Aray! Claws out!","Agh! Sapul!","Hisss... hindi pa tapos!","Meow...jority... lost..."]),
]

async def main(profiles=PROFILES, chapter=3, voices=None):
    voices = voices or {}
    OUT = ROOT / f'output/speech/chapter{chapter}'
    DEST = ROOT / f'assets/audio/sfx/voices/chapter{chapter}'
    OUT.mkdir(parents=True,exist_ok=True)
    ffmpeg=shutil.which('ffmpeg')
    assert ffmpeg, 'ffmpeg is required'
    manifest=[]
    for key,name,pitch,rate,freq,gain,lines in profiles:
        voice=voices.get(key,'fil-PH-AngeloNeural')
        for i,line in enumerate(lines):
            kind='defeat' if i==4 else f'heavy_{i-4:02}' if i>4 else f'hurt_{i+1:02}'
            used_rate=rate+12 if i>4 else rate
            raw=OUT/key/(kind+'.mp3'); raw.parent.mkdir(parents=True,exist_ok=True)
            target=DEST/key/(kind+'.ogg'); target.parent.mkdir(parents=True,exist_ok=True)
            if not raw.exists():
                await edge_tts.Communicate(line,voice,pitch=f'{pitch:+}Hz',rate=f'{used_rate:+}%').save(str(raw))
            # Trim start/end dead air, not internal punctuation pauses. Final
            # loudness match preserves identity while keeping peaks below 0 dBFS.
            filters=f'silenceremove=start_periods=1:start_duration=0.015:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_duration=0.03:start_threshold=-45dB,areverse,highpass=f=85,equalizer=f={freq}:t=q:w=1:g={gain},loudnorm=I=-18:TP=-2:LRA=7'
            subprocess.run([ffmpeg,'-v','error','-y','-i',str(raw),'-af',filters,'-ar','44100','-ac','1','-c:a','libvorbis','-q:a','5',str(target)],check=True)
            probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(target)]))
            manifest.append(dict(enemy=key,name=name,kind=kind,text=line,voice=voice,pitch_hz=pitch,rate_percent=used_rate,eq_hz=freq,eq_db=gain,path=str(target.relative_to(ROOT)).replace('\\','/'),seconds=float(probe['format']['duration']),sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
            print(key,kind,manifest[-1]['seconds'],flush=True)
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    cards=[]
    for key,name,*_ in profiles:
        rows=[]
        for row in [r for r in manifest if r['enemy']==key]:
            src='../../../'+row['path']
            rows.append(f'<p>{row["kind"]}: {html.escape(row["text"])} ({row["seconds"]:.2f}s)<br><audio controls preload="none" src="{src}"></audio></p>')
        cards.append('<section><h2>'+name+'</h2>'+''.join(rows)+'</section>')
    (OUT/'preview.html').write_text('<!doctype html><meta charset="utf-8"><title>Chapter 3 — AI-generated voices</title><style>body{background:#17222b;color:#f0e8d6;font:16px system-ui;margin:32px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(330px,1fr));gap:20px}section{background:#263642;padding:20px;border-radius:8px}audio{width:100%}</style><h1>Chapter 3 — AI-generated hurt and defeat voices</h1><p>Local review only. Edge Filipino TTS with nine fixed pitch, pacing and EQ profiles. One base synthetic voice; not nine actors or real-person imitations. Acting and emotional range are limited.</p><main>'+''.join(cards)+'</main>',encoding='utf-8')
    preview=OUT/'preview.html'
    preview.write_text(preview.read_text(encoding='utf-8').replace('Chapter 3',f'Chapter {chapter}'),encoding='utf-8')
    if chapter==1:
        preview.write_text(preview.read_text(encoding='utf-8').replace('nine fixed','five fixed').replace('One base synthetic voice; not nine actors','Male Angelo and female Blessica base voices; not five actors'),encoding='utf-8')
    print(f'DONE: {len(manifest)} clips',flush=True)

if __name__=='__main__': asyncio.run(main())
