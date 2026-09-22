# -*- coding: utf-8 -*-
"""The single source of truth for Chapter 5 -- CONGRESS OF THE PHILIPPINES.

The final chapter. Every generator in tools/chapter5 reads this file, so the
.tres resources, the choreography table, the icon builder and the tests cannot
disagree about what a move is called or what it does.

BALANCE -- WHY THESE NUMBERS
    The brief asks for the hardest chapter WITHOUT arbitrary health, so the
    numbers come from the damage the player actually deals.

    A hit is the Scrabble value of the answer, scaled by a length tier
    (1.0 / 1.25 / 1.6 at 5 / 8 / 9+ letters) and a speed bonus (up to 1.3).
    In play that lands between about 30 and 110 a swing.

    The lever Chapter 5 has that no earlier chapter had is its ANSWERS.
    The Congress bank is full of long ones -- TWOHUNDREDFIFTYTHOUSAND,
    TWELVEREPRESENTATIVES, CONGRESSIONALJOURNAL, SIXYEARSIMPRISONMENT -- and
    every answer of nine letters or more lands in the 1.6x tier. So the player
    hits harder here than anywhere else in the game, and health has to rise
    just to keep the number of correct answers per fight roughly level with
    Chapter 4 rather than to make fights longer.

    Chapter 4 ran 460 -> 620, boss 950. Chapter 5 runs 660 -> 900, boss 1250.
    Two rivals break the even rhythm on purpose, exactly as the brief asks:
    Quorum Kuno takes the SMALLEST step up because he is meant to survive by
    evading rather than by soaking, and Budget Bomba takes the largest because
    durability is his whole identity.

THE BOSS IS A FICTIONAL PARODY
    MarTinde RomuRulez uses the user's attached photo as an appearance reference,
    with the approved navy polo and dark pants. No real voice is imitated and
    no misconduct is asserted. Satire concerns legislative procedure only.
    The legacy internal slug remains stable to preserve existing asset routes.
"""

MELEE, RANGED, GUARD = "slam", "volley", "curse"

# Chapter 5's move ids share one prefix, so the controller routes them as a set
# exactly as "c3combat_" and "c4combat_" do for the chapters before it.
PREFIX = "c5combat_"

ROSTER = [
    {
        "slug": "cong_kodigo",
        "name": "Cong Kodigo",
        "title": "The Scripted Solon",
        "hp": 660,
        "colour": (0.92, 0.86, 0.62),
        "lore": "The Scripted Solon. He has an answer for everything, provided "
                "somebody wrote it down for him first. Take the cards away and "
                "the whole speech stops mid-sentence.",
        "room": ("cityhall_archive", "Legislative office and bill drafting room -- "
                 "desks, bill folders, document shelves, drafts, office lamps"),
        "design": "Neat prepared middle-aged Filipino congressman in a pressed "
                  "cream barong tagalog, dark slacks, polished shoes and thin "
                  "spectacles. He holds a fan of index cards in one raised hand "
                  "and a fat legislative folder of scripts under the other arm. "
                  "Tidy side-parted hair, confident practised expression. Neat "
                  "upright silhouette.",
        "moves": [
            ("Scripted Strike", MELEE, 30,
             "Isang talumpating isinaulo, ipinupukol nang tuwid.",
             "Checks the card, nods, steps in and swings the rolled bill flat."),
            ("Bill Barrage", RANGED, 28,
             "Tatlong panukalang batas, sunod-sunod na inihahagis.",
             "Three bills: one straight, one curving, one larger and faster."),
            ("Talking Point Guard", GUARD, 0.35,
             "Nagtatago sa likod ng nakahandang sagot.",
             "Raises layered talking-point cards into a paper panel."),
        ],
    },
    {
        "slug": "senador_sawsaw",
        "name": "Senador Sawsaw",
        "title": "The Floor Interrupter",
        "hp": 690,
        "colour": (0.96, 0.62, 0.30),
        "lore": "The Floor Interrupter. He has never once let a sentence "
                "finish. Whatever the topic, he has a point of order about it.",
        "room": ("cityhall_session_hall", "Senate session floor -- Senate desks, "
                 "microphones, podium, session lights, chamber seating"),
        "design": "Loud animated older Filipino senator in a cream barong with "
                  "a dark undershirt, dark slacks, one index finger raised high "
                  "and a chunky floor microphone gripped in the other hand. "
                  "Mouth open mid-objection, brows down, leaning aggressively "
                  "forward. Broad forward-leaning silhouette.",
        "moves": [
            ("Interpellation Jab", MELEE, 32,
             "Sunod-sunod na tanong na hindi mo masagot-sagot.",
             "Points, feints, then two jabs -- the second one harder."),
            ("Floor Hirit", RANGED, 30,
             "Tatlong alon ng salita mula sa mikropono.",
             "Three speech waves, each wider than the last."),
            ("Point of Order", GUARD, 0.40,
             "Isang daliri, at huminto ang lahat.",
             "One finger up, a chamber flash, and a counter-barrier forms."),
        ],
    },
    {
        "slug": "chairman_chika",
        "name": "Chairman Chika",
        "title": "The Hearing Hype",
        "hp": 720,
        "colour": (0.84, 0.44, 0.86),
        "lore": "The Hearing Hype. She schedules the hearing, packs the room, "
                "and makes very sure the cameras are running before the first "
                "question is asked.",
        "room": ("capitol_committee", "Committee hearing room -- hearing table, "
                 "witness chair, microphones, gavel, nameplates, press"),
        "design": "Theatrical Filipina committee chair in a bold magenta blazer "
                  "over a white blouse, dark skirt, statement earrings. She "
                  "holds a wooden gavel raised high in one hand and a witness "
                  "folder in the other. Wide showman's smile, chin up, one arm "
                  "flung out. Dramatic wide silhouette.",
        "moves": [
            ("Gavel Bang", MELEE, 34,
             "Isang malakas na hampas ng gavel sa sahig.",
             "Raises the gavel overhead, braces, steps in and slams it down."),
            ("Mic Barrage", RANGED, 31,
             "Sunod-sunod na mikroponong lumilipad.",
             "Three microphones: straight, diagonal, then a spinning fast one."),
            ("Committee Shield", GUARD, 0.35,
             "Ang mesa ng pagdinig ang sumasalo.",
             "The hearing table rises with folder stacks around it."),
        ],
    },
    {
        "slug": "quorum_kuno",
        "name": "Quorum Kuno",
        "title": "The Vanishing Vote",
        "hp": 740,
        "colour": (0.62, 0.72, 0.80),
        "lore": "The Vanishing Vote. Present at roll call, absent at the "
                "division, and back in his seat before anybody can ask where "
                "he went.",
        "design": "Slippery evasive Filipino congressman in a slightly rumpled "
                  "cream barong, dark slacks, an attendance clipboard held low "
                  "in one hand and a session bell in the other. Eyes sliding "
                  "sideways, weight already shifting off the back foot, half "
                  "turned away. Slight furtive silhouette.",
        "room": ("capitol_session_hall", "Session hall of empty seats -- rows of "
                 "empty chairs, attendance board, voting screen, session bell, "
                 "subdued light"),
        "moves": [
            ("Attendance Swipe", MELEE, 33,
             "Isang mabilis na hagod ng attendance clipboard.",
             "Checks the sheet, drops low, runs in and swipes the clipboard."),
            ("Empty Seat Shuffle", RANGED, 30,
             "Naglalaho, lumilitaw sa ibang upuan, at humahagis.",
             "Empty chairs bloom, he fades, reappears, throws, returns."),
            ("Quorum Escape", GUARD, 0.45,
             "Biglang wala na siya sa kinatatayuan mo noong tumingin ka.",
             "Telegraphs, bends, sidesteps and fades -- then comes back."),
        ],
    },
    {
        "slug": "whip_walanghiya",
        "name": "Whip Walanghiya",
        "title": "The Vote Wrangler",
        "hp": 780,
        "colour": (0.36, 0.78, 0.52),
        "lore": "The Vote Wrangler. He does not argue and he does not persuade. "
                "He counts, and by the time the bell rings the count is already "
                "whatever he said it would be.",
        "room": ("cityhall_budget", "Majority-minority caucus area -- strategy "
                 "board, vote tally, meeting tables, bloc symbols, arrow lists"),
        "design": "Controlling tactical Filipino party whip in a dark barong "
                  "over black slacks, sleeves pushed back, a tally card fan in "
                  "one hand and the other arm extended pointing straight ahead. "
                  "Hard flat stare, feet set wide and square. Broad commanding "
                  "silhouette.",
        "moves": [
            ("Bloc Breaker", MELEE, 36,
             "Isang balikat na pumuputol ng buong bloke.",
             "Points, gathers the bloc icons, steps in, shoulders through."),
            ("Vote Count Volley", RANGED, 33,
             "Dalawang alon ng boto, tapos ang pinakamalaki.",
             "Two waves of voting tokens at different heights, then one big "
             "vote marker."),
            ("Majority Guard", GUARD, 0.45,
             "Ang mayorya ang nakaharang sa iyo.",
             "Allied silhouettes fall in behind him and link into a bloc wall."),
        ],
    },
    {
        "slug": "amendment_atras",
        "name": "Amendment Atras",
        "title": "The Bill Rewriter",
        "hp": 810,
        "colour": (0.90, 0.30, 0.30),
        "lore": "The Bill Rewriter. Whatever you agreed to this morning is not "
                "what is on the page this afternoon, and he has the revision "
                "history to prove it always said this.",
        "room": ("cityhall_permits", "Legislative drafting and amendment room -- "
                 "bills everywhere, red marks, editing boards, giant document "
                 "projections, revision papers"),
        "design": "Clever restless Filipino legislative drafter in a cream "
                  "barong with the sleeves rolled, dark slacks, holding an "
                  "oversized red marker pen like a blade in one hand and a "
                  "heavily crossed-out bill in the other. Sharp amused "
                  "expression, weight on the back foot mid-turn. Lean angular "
                  "silhouette.",
        "moves": [
            ("Red Pen Slash", MELEE, 38,
             "Dalawang guhit ng pulang panulat, diagonal at pahalang.",
             "Spins the pen, repositions, cuts diagonally then horizontally."),
            ("Revision Rain", RANGED, 35,
             "Bumabagsak na mga binagong pahina.",
             "Amended pages fall in two telegraphed sets, then one REVISED "
             "document lands."),
            ("Motion to Amend", GUARD, 0.40,
             "Binabago ang teksto habang papalapit ang suntok.",
             "Crosses out a glowing bill, rewrites it, and the page hardens."),
        ],
    },
    {
        "slug": "bicam_berto",
        "name": "Bicam Berto",
        "title": "The Conference Closer",
        "hp": 840,
        "colour": (0.46, 0.62, 0.94),
        "lore": "The Conference Closer. Two chambers walk in with two different "
                "bills. One bill walks out, and nobody can quite say which "
                "parts of it either chamber actually voted for.",
        "room": ("cityhall_bidding", "Bicameral conference room -- Senate side, "
                 "House side, long conference table, dual document piles, a "
                 "central merged-bill motif"),
        "design": "Calm strategic Filipino conference negotiator in a "
                  "steel-blue barong and dark slacks, holding a blue Senate "
                  "folder in one hand and a red House folder in the other, one "
                  "in each fist at chest height. Level unhurried gaze, settled "
                  "balanced stance. Squared symmetrical silhouette.",
        "moves": [
            ("Conference Crash", MELEE, 40,
             "Dalawang folder na pinagsasama sa isang hampas.",
             "Strikes with one folder, then the other, then brings both down "
             "together."),
            ("Bicam Merge", RANGED, 37,
             "Dalawang panukala na nagiging iisa -- at mas malakas.",
             "A Senate bill and a House bill converge, fuse into one glowing "
             "measure, and that is what is launched."),
            ("Compromise Shield", GUARD, 0.40,
             "Dalawang panig, isang kasunduan, isang kalasag.",
             "Two paper barriers slide together and merge into one."),
        ],
    },
    {
        "slug": "budget_bomba",
        "name": "Budget Bomba",
        "title": "The Appropriation Bruiser",
        "hp": 900,
        "colour": (0.98, 0.76, 0.24),
        "lore": "The Appropriation Bruiser. The national budget is four "
                "thousand pages and he has read none of them, but he can swing "
                "the whole thing with one arm.",
        "room": ("cityhall_treasury", "Appropriations and budget chamber -- huge "
                 "budget books, appropriation folders, financial screens, peso "
                 "motifs, stacked national budget documents"),
        "design": "Huge heavy-set Filipino appropriations chairman in a "
                  "straining cream barong over dark trousers, thick arms and "
                  "shoulders, hauling an enormous bound national budget book "
                  "against his hip with both hands. Jaw set, feet planted very "
                  "wide, immovable. Massive blocky silhouette.",
        "moves": [
            ("Budget Book Bash", MELEE, 46,
             "Ang buong pambansang badyet, iwinasiwas.",
             "Strains the book up, two heavy steps, a horizontal swing, then a "
             "downward smash that shakes the floor."),
            ("Appropriation Bombardment", RANGED, 41,
             "Maliit na salvo, mabigat na salvo, tapos ang buong folder.",
             "A light volley, a heavier one, then one oversized appropriation "
             "folder."),
            ("Fiscal Fortress", GUARD, 0.50,
             "Ang ledger ang pader, at hindi ito nagagalaw.",
             "Opens a giant ledger, grips both covers, plants wide, and a "
             "golden peso barrier closes."),
        ],
    },
]

BOSS = {
    "slug": "spiker_supremo",
    "name": "MarTinde RomuRulez",
    "title": "The House Supremo",
    "hp": 1250,
    "colour": (0.98, 0.82, 0.42),
    "lore": "The House Supremo. He does not raise his voice, because he has "
            "never needed to. He holds the gavel, the calendar and the "
            "majority, and the chamber moves when he says it moves.",
    "design": "Fictional parody based exclusively on the user's attached "
              "reference photo: mature middle-aged Filipino man, broad oval "
              "face, swept-back dark hair, warm medium skin tone, substantial "
              "average build. Navy-blue short-sleeved collared polo, charcoal "
              "pants and black formal shoes; NOT a barong. Genuine three-quarter "
              "combat stance facing screen left, composed expression, wooden "
              "gavel at chest height and burgundy legislative folder. Preserve "
              "identity and outfit in every animation, phase and defeat pose.",
    "room": ("cityhall_mayor_office", "Grand House chamber -- central rostrum, "
             "voting board, House insignia, rich wood interior, formal "
             "lighting, congressional seating, elevated leadership area, kept "
             "uncluttered directly behind the word board"),
    "moves": [
        ("House Rules", MELEE, 48,
         "Ang tuntunin ng Kapulungan -- at ang martilyo na nagpapatupad nito.",
         "Adjusts the cuff, raises the gavel, points, steps through: gavel "
         "jab, folder sweep, then the overhead slam that carries the hit."),
        ("Majority Motion", RANGED, 43,
         "Ang bilang ay tapos na bago pa man tumayo ang sinuman.",
         "The board lights, vote markers gather, two waves launch, and a "
         "MAJORITY symbol forms and follows them."),
        ("Speaker's Shield", GUARD, 0.50,
         "Ang martilyo ay tumama, at ang silid ay tumahimik.",
         "Strikes the stand, a House emblem lights beneath him and "
         "legislative panels rise with vote icons in orbit."),
    ],
    # HOUSE IN SESSION, at half health. Same character, more determined.
    "phase_threshold": 0.5,
    "phase_banner": "HOUSE IN SESSION!",
    # FINAL READING, once, in the last quarter. Deliberately NOT a heal: the
    # brief asks for a climax, not a second health bar.
    "final_reading_at": 0.22,
    "final_reading_banner": "FINAL READING",
}


def move_id(slug, move_name):
    key = move_name.lower().replace("'", "").replace("-", " ")
    return PREFIX + "_".join(key.split())


def all_entries():
    return ROSTER + [BOSS]


def placeholder_room(slug):
    # Legacy API name, now resolved to the final Congress scenery assets.
    rooms = {
        "cong_kodigo": "chapter5/01_annex_entrance",
        "senador_sawsaw": "chapter5/02_senate_floor",
        "chairman_chika": "chapter5/03_hearing_room",
        "quorum_kuno": "chapter5/04_assembly_walkway",
        "whip_walanghiya": "chapter5/05_caucus_terrace",
        "amendment_atras": "chapter5/06_revision_office",
        "bicam_berto": "chapter5/07_bicam_room",
        "budget_bomba": "chapter5/08_budget_plaza",
        "spiker_supremo": "chapter5/09_grand_house_hall",
    }
    if slug in rooms:
        return rooms[slug]
    for entry in all_entries():
        if entry["slug"] == slug:
            return entry["room"][0]
    raise KeyError(slug)
