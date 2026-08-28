# -*- coding: utf-8 -*-
"""Single source of truth for Chapter 2 — City Hall.

Both the placeholder-art generator and the Godot .tres generator read this, so
a name, colour or damage value is edited in exactly one place. Enemy order in
ROSTER *is* the encounter order (ChapterData.encounters is ordered).
"""

# Palette note: `body` and `accent` drive the placeholder sprite; `tint` is the
# move's effect_color in-game and also tints that skill's placeholder prop, so
# each skill's clip is visually distinct from its siblings even as a stand-in.

ROSTER = [
    dict(
        slug="fixer_fredo", name="Fixer Fredo", title="The Shortcut Dealer",
        hp=170, boss=False,
        body=(96, 78, 58), accent=(210, 176, 96), build="slim", hat="cap",
        bg="cityhall_plaza",
        lore="He is already at the gate before you reach it, holding a clipboard "
             "nobody gave him. For a fee, he says, the line simply stops applying to you.",
        moves=[
            dict(id="backdoor_dash", name="Backdoor Dash", dmg=14, style="lunge",
                 tint=(0.62, 0.55, 0.42, 0.95),
                 desc="Out one door, in behind you."),
            dict(id="envelope_express", name="Envelope Express", dmg=12, style="volley",
                 tint=(0.88, 0.82, 0.62, 0.95),
                 desc="Envelopes flicked like cards. They burst."),
            dict(id="queue_skip_kick", name="Queue Skip Kick", dmg=16, style="lunge",
                 tint=(0.74, 0.66, 0.44, 0.95),
                 desc="He steps over the barrier, then kicks."),
        ]),
    dict(
        slug="clerk_kurakot", name="Clerk Kurakot", title="The Counter Crook",
        hp=185, boss=False,
        body=(74, 88, 104), accent=(196, 66, 58), build="wide", hat="none",
        bg="cityhall_lobby",
        lore="Every form you bring him is the wrong form. He has been reaching for "
             "the same stamp since morning and has not stamped anything yet.",
        moves=[
            dict(id="stamp_slam", name="Stamp Slam", dmg=17, style="slam",
                 tint=(0.86, 0.24, 0.20, 0.95),
                 desc="An oversized stamp, driven down. DENIED."),
            dict(id="paper_cut_volley", name="Paper Cut Volley", dmg=13, style="volley",
                 tint=(0.94, 0.92, 0.86, 0.95),
                 desc="Documents that straighten into blades."),
            dict(id="counter_charge", name="Counter Charge", dmg=15, style="lunge",
                 tint=(0.66, 0.74, 0.86, 0.95),
                 desc="He vaults his own service counter."),
        ]),
    dict(
        slug="permit_peke", name="Permit Peke", title="The Forged Approver",
        hp=200, boss=False,
        body=(88, 96, 72), accent=(226, 92, 70), build="normal", hat="visor",
        bg="cityhall_permits",
        lore="The signature is real. The seal is real. The office it came from "
             "closed four years ago.",
        moves=[
            dict(id="permit_board_bash", name="Permit Board Bash", dmg=18, style="slam",
                 tint=(0.90, 0.58, 0.30, 0.95),
                 desc="A signboard swung flat. APPROVED, then PEKE."),
            dict(id="fake_seal_shot", name="Fake Seal Shot", dmg=15, style="spray",
                 tint=(0.92, 0.30, 0.28, 0.95),
                 desc="Seals peel off the page and curve in."),
            dict(id="carbon_copy_barrage", name="Carbon Copy Barrage", dmg=16, style="volley",
                 tint=(0.86, 0.88, 0.94, 0.95),
                 desc="The photocopier will not stop."),
        ]),
    dict(
        slug="notaryo_naku", name="Notaryo Naku", title="The Seal Schemer",
        hp=215, boss=False,
        body=(64, 62, 88), accent=(232, 214, 128), build="slim", hat="none",
        bg="cityhall_archive",
        lore="He notarises with the flourish of a man signing a treaty. What he "
             "is signing is a photocopy of a photocopy.",
        moves=[
            dict(id="notary_stampede", name="Notary Stampede", dmg=19, style="lunge",
                 tint=(0.88, 0.26, 0.24, 0.95),
                 desc="A stamp on each fist. Left, right, both."),
            dict(id="signature_slash", name="Signature Slash", dmg=16, style="lunge",
                 tint=(0.30, 0.34, 0.62, 0.95),
                 desc="He signs the air. It keeps travelling."),
            dict(id="seal_of_approval", name="Seal of Approval", dmg=20, style="curse",
                 tint=(0.94, 0.78, 0.34, 0.95),
                 desc="A seal glows under your feet. Move."),
        ]),
    dict(
        slug="cashier_kaltas", name="Cashier Kaltas", title="The Deduction Collector",
        hp=230, boss=False,
        body=(104, 72, 88), accent=(240, 206, 110), build="normal", hat="none",
        bg="cityhall_treasury",
        lore="The amount was correct until she looked at it. Now there is a "
             "service charge, a processing fee, and something she has not named yet.",
        moves=[
            dict(id="cash_drawer_bash", name="Cash Drawer Bash", dmg=20, style="slam",
                 tint=(0.94, 0.80, 0.36, 0.95),
                 desc="The whole drawer, swung like a hammer."),
            dict(id="coin_flick", name="Coin Flick", dmg=17, style="volley",
                 tint=(0.98, 0.86, 0.42, 0.95),
                 desc="Ping. Ping. PING. The third one hurts."),
            dict(id="receipt_whip", name="Receipt Whip", dmg=19, style="lunge",
                 tint=(0.90, 0.90, 0.84, 0.95),
                 desc="It prints to the floor. Then she picks it up."),
        ]),
    dict(
        slug="budget_bandido", name="Budget Bandido", title="The Fund Raider",
        hp=245, boss=False,
        body=(58, 66, 62), accent=(238, 194, 76), build="wide", hat="mask",
        bg="cityhall_budget",
        lore="A masked man carrying a sack marked CITY FUNDS, in daylight, past "
             "three guards, none of whom felt it was their department.",
        moves=[
            dict(id="budget_bag_bash", name="Budget Bag Bash", dmg=21, style="slam",
                 tint=(0.92, 0.76, 0.30, 0.95),
                 desc="One spin. The sack does the rest."),
            dict(id="coin_burst", name="Coin Burst", dmg=18, style="spray",
                 tint=(0.98, 0.84, 0.34, 0.95),
                 desc="One coin in, far more coins out."),
            dict(id="deficit_drop", name="Deficit Drop", dmg=23, style="slam",
                 tint=(0.86, 0.28, 0.26, 0.95),
                 desc="A red figure, then the sack it belongs to."),
        ]),
    dict(
        slug="bidding_bandit", name="Bidding Bandit", title="The Auction Schemer",
        hp=260, boss=False,
        body=(70, 74, 92), accent=(150, 200, 176), build="normal", hat="none",
        bg="cityhall_bidding",
        lore="Three companies bid. All three envelopes are in his handwriting.",
        moves=[
            dict(id="briefcase_beatdown", name="Briefcase Beatdown", dmg=22, style="lunge",
                 tint=(0.62, 0.68, 0.86, 0.95),
                 desc="Jab, spin, overhead. Then it bursts open."),
            dict(id="bid_folder_fan", name="Bid Folder Fan", dmg=19, style="volley",
                 tint=(0.56, 0.82, 0.72, 0.95),
                 desc="Folders fanned. The last one wins."),
            dict(id="contract_snare", name="Contract Snare", dmg=24, style="curse",
                 tint=(0.88, 0.72, 0.44, 0.95),
                 desc="It finds your ankles and asks you to sign."),
        ]),
    dict(
        slug="ordinance_ogre", name="Ordinance Ogre", title="The Rule Twister",
        hp=280, boss=False,
        body=(86, 108, 76), accent=(198, 156, 88), build="huge", hat="none",
        bg="cityhall_session_hall",
        lore="He has read every ordinance in the city and remembers only the "
             "clauses that suit him. The book is heavier than you are.",
        moves=[
            dict(id="codex_crusher", name="Codex Crusher", dmg=24, style="slam",
                 tint=(0.72, 0.58, 0.34, 0.95),
                 desc="He shuts the book, then swings it."),
            dict(id="citation_cannon", name="Citation Cannon", dmg=20, style="lunge",
                 tint=(0.94, 0.86, 0.52, 0.95),
                 desc="He points. The clause leaves the page."),
            dict(id="session_smash", name="Session Smash", dmg=26, style="slam",
                 tint=(0.82, 0.62, 0.28, 0.95),
                 desc="The gavel grows. The floor regrets it."),
        ]),
    dict(
        slug="don_eraptado", name="Don Eraptado", title="The Plunder Supremo",
        hp=480, boss=True,
        body=(46, 44, 60), accent=(226, 182, 68), build="boss", hat="none",
        bg="cityhall_mayor_office",
        lore="He does not rise when you enter. The vault behind him is open, and "
             "he has decided that this, too, is a formality he can approve.",
        moves=[
            # Names follow the project brief's roster; animations follow the design
            # document's descriptions. See CH2_NOTES.md.
            dict(id="kaban_ng_bayan", name="Kaban ng Bayan", dmg=26, style="slam",
                 tint=(0.94, 0.78, 0.30, 0.95),
                 desc="He swings the treasury itself."),
            dict(id="plunder_supremo", name="Plunder Supremo", dmg=22, style="volley",
                 tint=(0.96, 0.84, 0.40, 0.95),
                 desc="He never stands. The sacks fire."),
            dict(id="jueteng_jackpot", name="Jueteng Jackpot", dmg=24, style="spray",
                 tint=(0.90, 0.42, 0.62, 0.95),
                 desc="A number nobody chose. He collects."),
            dict(id="executive_privilege", name="Executive Privilege", dmg=34, style="slam",
                 tint=(0.98, 0.88, 0.52, 0.95),
                 phase2=True,
                 desc="Lights out. He is entitled to it."),
        ]),
]

# Backgrounds, in progression order. `key` is the file stem under
# assets/images/backgrounds/. `palette` drives the placeholder art.
BACKGROUNDS = [
    dict(key="cityhall_plaza", label="City Hall Plaza", kind="plaza",
         sky=(126, 176, 214), wall=(214, 200, 176), floor=(168, 160, 148)),
    dict(key="cityhall_lobby", label="Citizen Service Lobby", kind="lobby",
         sky=(196, 204, 206), wall=(198, 202, 196), floor=(154, 152, 148)),
    dict(key="cityhall_permits", label="Business Permit & Licensing", kind="permits",
         sky=(206, 206, 194), wall=(206, 206, 190), floor=(150, 148, 140)),
    dict(key="cityhall_archive", label="Records & Notarial Archive", kind="archive",
         sky=(126, 116, 100), wall=(132, 120, 102), floor=(104, 94, 80)),
    dict(key="cityhall_treasury", label="Treasury & Cashier Office", kind="treasury",
         sky=(150, 158, 168), wall=(160, 166, 172), floor=(120, 124, 130)),
    dict(key="cityhall_budget", label="City Budget Office", kind="budget",
         sky=(158, 154, 172), wall=(164, 160, 176), floor=(122, 118, 132)),
    dict(key="cityhall_bidding", label="Procurement & Bidding Room", kind="bidding",
         sky=(120, 128, 140), wall=(128, 134, 146), floor=(96, 100, 110)),
    dict(key="cityhall_session_hall", label="Sangguniang Panlungsod", kind="session",
         sky=(112, 92, 76), wall=(120, 96, 74), floor=(88, 68, 52)),
    dict(key="cityhall_mayor_office", label="Mayor's Executive Office", kind="mayor",
         sky=(74, 62, 62), wall=(84, 68, 62), floor=(62, 50, 46)),
]

CHAPTER = dict(number=2, name="City Hall Shadows")


def all_moves():
    for e in ROSTER:
        for m in e["moves"]:
            yield e, m
