"""Decode every delivery clip; verify finite samples, audible signal and headroom."""
import json, subprocess, sys, hashlib
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/('output/speech/chapter1' if '--chapter1' in sys.argv else 'output/speech/chapter2' if '--chapter2' in sys.argv else 'output/speech/chapter3')
rows=[]
for item in json.loads((OUT/'manifest.json').read_text(encoding='utf-8')):
    data=subprocess.check_output(['ffmpeg','-v','error','-i',str(ROOT/item['path']),'-f','f32le','-ac','1','-ar','24000','-'])
    samples=np.frombuffer(data,dtype='<f4')
    peak=float(np.max(np.abs(samples)))
    rms=float(np.sqrt(np.mean(samples*samples)))
    passed=bool(np.isfinite(samples).all() and .05<peak<1 and rms>.003 and len(samples)>2400)
    rows.append(dict(path=item['path'],seconds=len(samples)/24000,peak=peak,rms=rms,passed=passed))
report=dict(passed=all(r['passed'] for r in rows),count=len(rows),clips=rows,note='Signal checks only. Pronunciation, acting and recognizability still require human listening review.')
(OUT/'audio_quality_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('AUDIO QA',report['passed'],len(rows),'decoded clips')
assert report['passed']
if (OUT/'preserved_assets.json').exists():
    baseline=json.loads((OUT/'preserved_assets.json').read_text(encoding='utf-8'))
    changed=[p for p,h in baseline.items() if hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h]
    (OUT/'preservation_report.json').write_text(json.dumps(dict(passed=not changed,checked=len(baseline),changed=changed),indent=2),encoding='utf-8')
    print('PRESERVATION',not changed,len(baseline))
    assert not changed,changed
