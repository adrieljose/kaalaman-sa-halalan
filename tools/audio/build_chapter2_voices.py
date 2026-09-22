"""Chapter 2 speech profiles using the established Edge TTS build pipeline."""
import asyncio, hashlib, json
from build_chapter3_voices import ROOT, main

PROFILES = [
 ('fixer_fredo','Fixer Fredo',17,28,1900,2,["Aray! Sandali!","Agh! Sapul!","Naku, boss!","Teka! May paraan pa!","Wala na... akong shortcut..."]),
 ('clerk_kurakot','Clerk Kurakot',-20,5,550,3,["Aray! Ano ba!","Agh! Sandali!","Naku! Ang sakit!","Teka! May pila!","Sarado na... ang counter..."]),
 ('permit_peke','Permit Peke',29,34,2400,3,["Aray! Hindi ako 'yon!","Agh! Teka!","Naku! Nahuli—este, sapul!","Wala akong alam!","Rejected... ako..."]),
 ('notaryo_naku','Notaryo Naku',5,8,850,3,["ARAY! Naku naman!","Agh! Ang aking pirma!","Sapul! Nasaan ang seal ko?","Naku! Protesta!","Naku... wala nang seal..."]),
 ('cashier_kaltas','Cashier Kaltas',10,22,1800,4,["Aray! May kaltas 'yan!","Agh! Sapul!","Naku! Kulang!","Teka! Bilangin muna!","Naubos... ang sukli..."]),
 ('budget_bandido','Budget Bandido',-32,10,180,4,["ARGH! Sapul!","Aray! Pondo ko!","Agh! Matindi 'yon!","Naku! Hawakan ang bag!","Wala na... ang pondo..."]),
 ('bidding_bandit','Bidding Bandit',-5,17,420,2,["Aray! Outbid ako!","Agh! Sapul!","Teka! Final offer!","Naku! Hindi kasama 'yan sa bid!","Natalo... ang bid..."]),
 ('ordinance_ogre','Ordinance Ogre',-45,-8,140,4,["ARGH!","Aray... malakas!","Hmph! Sapul!","Ugh... labag sa ordinansa!","Session... adjourned..."]),
 ('don_eraptado','Don Eraptado',-25,3,240,3,["Hmph...","Tsk!","Ugh... sapul.","Aray... matapang ka.","Hmph... hindi... pa ito...","ARGH!","Aray! Sobra na 'yan!","Agh... hindi pa tapos!","Hmph... magaling."]),
]

if __name__=='__main__':
    out=ROOT/'output/speech/chapter2'
    out.mkdir(parents=True,exist_ok=True)
    snapshot=out/'preserved_assets.json'
    if not snapshot.exists():
        files=list((ROOT/'data').rglob('*.tres'))+list((ROOT/'assets/audio/sfx/voices/chapter3').rglob('*.ogg'))+list((ROOT/'assets/audio/sfx/voices').glob('*.ogg'))
        snapshot.write_text(json.dumps({str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2),encoding='utf-8')
    asyncio.run(main(PROFILES,2))
