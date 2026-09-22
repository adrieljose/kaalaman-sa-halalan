# -*- coding: utf-8 -*-
"""The single source of truth for Chapter 4 -- MALACANANG PALACE.

Every generator in tools/chapter4 reads this file: the art prompts, the .tres
writers, the icon builder and the probes. Nothing about the roster is typed
twice, so a name or a damage number is changed here and nowhere else.

WHY THIS FILE EXISTS AT ALL
    Chapter 3 was assembled by a script (make_chapter3_data.py) that carried
    its own copy of the roster, and the two drifted. Keeping the data in one
    importable module instead means the .tres files, the choreography table and
    the tests cannot disagree about what a move is called or what it does.

BALANCE
    Chapter 3 runs 300 -> 440 HP in steps of 20, boss 700, with move damage
    18-28. Chapter 4 sits a clear tier above it: 460 -> 620, boss 950, damage
    24-38. EO Ego deliberately breaks the +20 rhythm with a +40 jump, because
    the brief asks for him to read as more dangerous than every regular enemy
    before him rather than as one more rung.

THE BOSS IS A FICTIONAL PARODY
    Lolo Enrilegend is an ORIGINAL satirical character built on the public
    "eternal statesman" joke -- not a portrait of any living person. His art
    prompt asks for a generic elderly Filipino statesman and explicitly forbids
    resembling a specific real individual; his lore and lines describe
    longevity and stubbornness only, never wrongdoing. There is no real-person
    voice, likeness, or claim of misconduct anywhere in this file, and none may
    be added to it.
"""

# Melee, ranged and defensive map onto the three animation_style values the
# battle controller already understands. Chapter 3 established the mapping and
# the Chapter 4 resolver reuses it unchanged.
MELEE, RANGED, GUARD = "slam", "volley", "curse"

# Chapter 4's move ids share one prefix so the controller can route them as a
# set, exactly as "c3combat_" does for Chapter 3.
PREFIX = "c4combat_"

ROSTER = [
    {
        "slug": "secretary_sipsip",
        "name": "Secretary Sipsip",
        "title": "The Cabinet Clinger",
        "hp": 460,
        "colour": (0.94, 0.80, 0.40),
        "lore": "The Cabinet Clinger. He has no policy of his own, only the "
                "policy of whoever is nearest the President -- and he can "
                "change it mid-sentence.",
        "design": "Slim eager middle-aged Filipino man in a crisp cream barong "
                  "tagalog worn slightly too formally, navy slacks, polished "
                  "black shoes, a laminated Palace ID on a blue lanyard. He "
                  "clutches a fat manila Cabinet folder to his chest with one "
                  "arm and holds a rubber approval stamp raised in the other "
                  "hand. Neat oiled side-part, eyebrows raised, wide "
                  "ingratiating smile, shoulders bowed forward in a permanent "
                  "half-bow. Narrow stooping silhouette.",
        "moves": [
            ("Approval Jab", MELEE, 24,
             "Isang mabilis na tatak ng pagsang-ayon, diretso sa harap.",
             "Steps in behind the folder and punches the approval stamp "
             "forward like a short jab."),
            ("Cabinet Folder Toss", RANGED, 22,
             "Naghahagis ng magkakasunod na folder na puno ng papeles.",
             "Three manila folders skim out flat, shedding signed pages."),
            ("Yes-Sir Shield", GUARD, 0.35,
             "Nagtatago sa likod ng sunod-sunod na pagsang-ayon.",
             "Snaps into a deep bow and raises the folder edge-on as cover."),
        ],
    },
    {
        "slug": "protocol_porma",
        "name": "Protocol Porma",
        "title": "The Ceremony Controller",
        "hp": 480,
        "colour": (0.80, 0.22, 0.28),
        "lore": "The Ceremony Controller. Nothing in the Palace begins until "
                "she says the line is straight, and nothing crooked has ever "
                "been her department.",
        "design": "Tall severe Filipina Palace protocol officer in a "
                  "sharply tailored charcoal uniform blazer with gold piping, "
                  "long pencil skirt, white ceremonial gloves and a red sash. "
                  "Hair in a hard bun. One gloved hand holds a brass-cornered "
                  "ceremonial clipboard, the other grips a coiled red velvet "
                  "rope with a gold hook. Chin lifted, mouth a flat line, "
                  "spine rigid, heels together. Tall narrow upright "
                  "silhouette.",
        "moves": [
            ("Red Carpet Sweep", MELEE, 26,
             "Hinahatak ang pulang karpet upang mawalan ng tayo ang kalaban.",
             "Whips the rolled carpet edge low across the floor in a sweeping "
             "leg-level arc."),
            ("Velvet Rope Snare", RANGED, 24,
             "Ipinupukol ang velvet rope na parang lasso.",
             "Hurls the hooked rope; it uncoils across the gap and snaps "
             "taut."),
            ("Formal Formation", GUARD, 0.35,
             "Pinapatayo ang mga hangganan -- walang lumalampas.",
             "Plants the clipboard, snaps to attention and sets a rope line "
             "of floor markers in front of her."),
        ],
    },
    {
        "slug": "spox_spin",
        "name": "Spox Spin",
        "title": "The Narrative Twister",
        "hp": 500,
        "colour": (0.55, 0.83, 0.96),
        "lore": "The Narrative Twister. He never lies outright. He simply "
                "answers a better question than the one he was asked.",
        "design": "Energetic young Filipino press officer in a pale blue "
                  "dress shirt with sleeves rolled to the elbow, loosened navy "
                  "tie, dark slacks, press card clipped to his belt. One hand "
                  "grips a chunky handheld microphone thrust forward, the "
                  "other fans a spread of printed statement pages. Mouth open "
                  "mid-sentence, one eyebrow up, weight on the front foot, "
                  "leaning in. Lean forward-leaning silhouette.",
        "moves": [
            ("Mic Check Bash", MELEE, 25,
             "Ipinapasok ang mikropono na parang batuta.",
             "Drives the microphone forward in a short two-beat check-check "
             "jab."),
            ("Press Release Barrage", RANGED, 28,
             "Sunod-sunod na pahayag na walang sinasagot.",
             "Fans out five statement pages that fly in a spreading arc."),
            ("Narrative Redirect", GUARD, 0.35,
             "Binabaluktot ang usapan palayo sa tanong.",
             "Spins on the ball of one foot behind a curtain of turning "
             "headlines."),
        ],
    },
    {
        "slug": "chief_utos",
        "name": "Chief Utos",
        "title": "The Command Keeper",
        "hp": 520,
        "colour": (0.44, 0.60, 0.80),
        "lore": "The Command Keeper. She holds the schedule, and in this "
                "building the schedule holds everyone else.",
        "design": "Brisk authoritative Filipina chief of staff in a slate "
                  "grey trouser suit over a white blouse, flat black shoes, "
                  "Palace access badge clipped at the hip, short practical "
                  "bob. One hand holds a metal command clipboard thick with "
                  "schedules, the other a mobile phone raised mid-order. "
                  "Frowning, mouth open giving an instruction, front foot "
                  "already stepping forward. Compact purposeful silhouette.",
        "moves": [
            ("Directive Strike", MELEE, 29,
             "Isang utos na hindi tinatanggihan.",
             "Steps through and cracks the clipboard edge down in a short "
             "overhand strike."),
            ("Command Stamp", RANGED, 26,
             "Pinapadala ang tatak ng utos sa buong silid.",
             "Slams a sealed order that launches three stamped seals across "
             "the floor."),
            ("Executive Order Brace", GUARD, 0.35,
             "Nagkakalat ng iskedyul na nagiging pananggalang.",
             "Plants both feet and holds the clipboard flat as a bracing "
             "shield of pinned schedules."),
        ],
    },
    {
        "slug": "cabinet_konek",
        "name": "Cabinet Konek",
        "title": "The Inner Circle Insider",
        "hp": 540,
        "colour": (0.36, 0.86, 0.72),
        "lore": "The Inner Circle Insider. He does not need to win the "
                "argument. He only needs to know who will be in the room "
                "when it is settled.",
        "design": "Smooth well-fed middle-aged Filipino insider in an "
                  "expensive dark green barong with subtle gold thread, black "
                  "slacks, gold ring and watch, executive access badge on a "
                  "gold chain. One hand holds an open leather contact book, "
                  "the other extended forward in a confident handshake offer. "
                  "Relaxed knowing smile, easy wide stance. Broad "
                  "comfortable silhouette.",
        "moves": [
            ("Connection Kick", MELEE, 27,
             "Isang tadyak na dumadaan sa tamang koneksyon.",
             "Pivots and drives a low forward kick, contact book tucked."),
            ("Network Signal", RANGED, 25,
             "Nagpapadala ng senyas sa mga kakilala sa loob.",
             "Flicks the contact book open; linked signal nodes race outward "
             "along glowing connection lines."),
            ("Inner Circle Guard", GUARD, 0.45,
             "Ang bilog ng mga kakilala ang sumasalo ng suntok.",
             "Sweeps the book in a circle, closing a ring of linked contacts "
             "around himself."),
        ],
    },
    {
        "slug": "director_dikta",
        "name": "Director Dikta",
        "title": "The Executive Enforcer",
        "hp": 560,
        "colour": (0.66, 0.26, 0.32),
        "lore": "The Executive Enforcer. He did not write the directive. He "
                "is only here to make absolutely certain it is carried out.",
        "design": "Heavy-set imposing Filipino executive enforcer in a "
                  "severe black suit jacket over a dark shirt, no tie, thick "
                  "shoulders, dark trousers and heavy black shoes. He carries "
                  "a stack of thick bound directive folders braced on one "
                  "forearm and holds a large iron command stamp in the other "
                  "fist. Shaved head, heavy brow, jaw set, feet planted wide. "
                  "Massive blocky silhouette.",
        "moves": [
            ("Memo Slam", MELEE, 33,
             "Ibinabagsak ang buong bigat ng memo.",
             "Hauls the folder stack overhead and slams it straight down."),
            ("Directive Volley", RANGED, 29,
             "Pinakakawalan ang mga direktiba nang sabay-sabay.",
             "Hammers the stamp and sends four heavy directives out low and "
             "fast."),
            ("Command Barrier", GUARD, 0.35,
             "Ang utos mismo ang nagiging pader.",
             "Drives the stamp into the floor and raises a wall of stamped "
             "directives."),
        ],
    },
    {
        "slug": "adviser_areglo",
        "name": "Adviser Areglo",
        "title": "The Backroom Whisperer",
        "hp": 580,
        "colour": (0.58, 0.44, 0.82),
        "lore": "The Backroom Whisperer. He is never in the photograph, and "
                "the arrangement is always already made by the time anyone "
                "thinks to ask.",
        "design": "Lean composed older Filipino adviser in a dark "
                  "slate-grey suit with a high-buttoned jacket, thin steel "
                  "spectacles, hair greying at the temples. He holds a closed "
                  "dark confidential folder low at his side and turns a single "
                  "black chess knight between the fingers of his raised hand. "
                  "Calm half-smile, eyes level and unhurried, weight settled "
                  "back on the rear foot. Slim quiet silhouette.",
        "moves": [
            ("Whisper Jab", MELEE, 28,
             "Isang mahinang bulong na tumatama nang malakas.",
             "Feints high, then steps in with a short close-range palm "
             "strike."),
            ("Backroom Deal", RANGED, 32,
             "Ang kasunduang tapos na bago pa magsimula ang usapan.",
             "Sets three dark folders drifting, then springs them all at "
             "once after a beat."),
            ("Strategic Sidestep", GUARD, 0.40,
             "Wala siya sa kinatatayuan mo noong tumingin ka.",
             "Slides one clean step off the line and settles into a "
             "counter-ready stance."),
        ],
    },
    {
        "slug": "eo_ego",
        "name": "EO Ego",
        "title": "The Order Overlord",
        "hp": 620,
        "colour": (1.00, 0.83, 0.32),
        "lore": "The Order Overlord. He speaks only in issuances, and he has "
                "never once been told that an order can be questioned.",
        "design": "Grand theatrical Filipino official in an ornate "
                  "gold-embroidered cream barong with a heavy gold sash and "
                  "dark formal trousers, rings on both hands. He holds an "
                  "oversized unrolled executive order document in one raised "
                  "arm and a giant golden seal stamp in the other. Chin high, "
                  "chest out, arms wide, cape-like sash flaring. Imposing "
                  "wide-armed silhouette.",
        "moves": [
            ("Executive Smash", MELEE, 36,
             "Ang tatak na pumapawi ng anumang tutol.",
             "Rears back and brings the giant golden seal down in a "
             "two-handed overhead smash."),
            ("EO Barrage", RANGED, 38,
             "Sunod-sunod na kautusan, wala nang paliwanag.",
             "Unrolls the order and launches six heavy sealed documents in "
             "two waves."),
            ("Presidential Seal Guard", GUARD, 0.45,
             "Ang gintong tatak ang huling salita.",
             "Plants the seal in front of him; a gold crest rises and holds."),
        ],
    },
]

BOSS = {
    "slug": "lolo_enrilegend",
    "name": "LOLO ENRILEGEND",
    "title": "The Eternal Statesman",
    "hp": 950,
    "colour": (0.90, 0.74, 0.36),
    "lore": "The Eternal Statesman. A fictional Palace fixture who has "
            "outlasted every administration, every reorganisation and every "
            "colleague who ever wrote him off. He does not shout. He simply "
            "does not leave.",
    # ORIGINAL satirical archetype. The prompt names no real person and asks
    # explicitly for a face that resembles none.
    "design": "Very elderly but upright Filipino statesman, an ORIGINAL "
              "fictional character resembling no real or living person. He "
              "wears a formal long-sleeved cream barong tagalog with fine "
              "embroidery, dark trousers, polished shoes, and thick "
              "old-fashioned spectacles. Deeply lined face, thin white hair "
              "combed back, small dry composed smile. Both hands rest on a "
              "dark polished wooden cane planted firmly on the ground in "
              "front of him; a rolled historical document is tucked under one "
              "arm. Feet apart and completely settled, back straight despite "
              "his age, entirely unhurried. Dignified veteran silhouette.",
    "moves": [
        ("Veteran's Verdict", MELEE, 40,
         "Ang hatol ng taong nakakita na ng lahat.",
         "Plants the cane, raises one finger, takes two deliberate steps, "
         "then jab, sweep and a heavy downward cane strike."),
        ("History Repeats", RANGED, 34,
         "Ang nakaraan ay bumabalik, paulit-ulit.",
         "Aged documents orbit him, launch in two waves, then one great "
         "historical page is loosed on a point of the cane."),
        ("Eternal Resolve", GUARD, 0.50,
         "Nakatayo pa rin.",
         "Steps back, plants both feet, holds the cane upright and raises a "
         "translucent golden statesman's barrier."),
    ],
    # Phase 2 fires at half health. Same character, more determined -- never a
    # redesign, per the brief.
    "phase_threshold": 0.5,
    "phase_banner": "STILL STANDING",
    # The one-time last stand. Never more than once; see chapter4_boss.gd.
    "revive_fraction": 0.22,
    "revive_banner": "NOT YET.",
}


# ROOMS ARE NOT DRAWN YET.
#
# Chapter 4 backgrounds were deliberately deferred -- characters first. Every
# encounter therefore borrows an existing room so the chapter is playable and
# testable end to end, and each borrowed room is paired with the Chapter 4 room
# it is standing in for. When the real art is generated this table is the whole
# brief, and swapping it is a one-line change per encounter.
#
#   slug -> (placeholder background stem, the room actually wanted)
ROOMS = {
    'secretary_sipsip': ('cityhall_lobby',
     'Palace reception hall, marble floor, tall shuttered windows'),
    'protocol_porma': ('cityhall_session_hall',
     'Ceremonial hall, long red carpet, velvet rope stanchions'),
    'spox_spin': ('capitol_committee',
     'Press briefing room, lectern, seated press rows, camera lights'),
    'chief_utos': ('cityhall_mayor_office',
     'Chief of staff anteroom, wall of clocks and schedules'),
    'cabinet_konek': ('capitol_session_hall',
     'Cabinet room, long polished table, national seal behind'),
    'director_dikta': ('cityhall_archive',
     'Executive records floor, steel shelving, stacked directives'),
    'adviser_areglo': ('capitol_governor_office',
     'Dim Palace backroom, drawn curtains, one desk lamp'),
    'eo_ego': ('cityhall_mayor_office',
     'Order-signing hall, gilded desk, flags, heavy seal press'),
    'lolo_enrilegend': ('capitol_governor_office',
     'Palace state room, portraits, tall doors, evening light'),
}


def placeholder_room(slug):
    return ROOMS[slug][0]


def move_id(slug, move_name):
    """The stable id a move is routed and voiced by."""
    key = move_name.lower().replace("'", "").replace("-", " ")
    return PREFIX + "_".join(key.split())


def all_entries():
    """The roster in encounter order, boss last."""
    return ROSTER + [BOSS]
