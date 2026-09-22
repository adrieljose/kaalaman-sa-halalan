"""Chapter 1 profiles; uses the shared speech builder, no new voice engine."""
import asyncio, hashlib, json
from build_chapter3_voices import ROOT, main

PROFILES = [
 ('lord_trapo','Lord Trapo',22,14,1400,2,["Aray! Alam mo ba kung sino ako?","Agh! Teka lang!","Naku! Sapul!","Hoy! Bawal 'yan!","Pero... pangalan namin..."]),
 ('vote_vandal','Vote Vandal',-2,35,2600,4,["Aray! Grabe!","Agh! Sapul!","Hoy! Easy lang!","Naku! Tinamaan!","Wala na... ang gulo..."]),
 ('senator_sabaw','Senador Sabaw',-17,-10,650,2,["Ha? Aray!","Agh... ano 'yon?","Naku... nasaan ako?","Teka... may session ba?","Adjourned... na ba?"]),
 ('kapitan_komisyon','Kapitan Komisyon',-28,7,220,3,["Aray! May porsyento 'yan!","Agh! Sapul!","Naku! Bawas ang kita!","Teka! Sampung porsyento muna!","Wala na... ang porsyento..."]),
 ('ate_ayuda','Ate Ayuda',-18,5,500,2,["Aray! Walang utang na loob!","Agh! Teka lang!","Naku! Ako pa talaga?","Hmph! Matapang ka.","Wala na... ang ayuda..."]),
]

if __name__=='__main__':
    out=ROOT/'output/speech/chapter1'; out.mkdir(parents=True,exist_ok=True)
    snapshot=out/'preserved_assets.json'
    if not snapshot.exists():
        files=list((ROOT/'data').rglob('*.tres'))+list((ROOT/'assets/audio/sfx/voices').rglob('*.ogg'))
        snapshot.write_text(json.dumps({str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2),encoding='utf-8')
    asyncio.run(main(PROFILES,1,{'ate_ayuda':'fil-PH-BlessicaNeural'}))
