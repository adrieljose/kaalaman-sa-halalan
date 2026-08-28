# -*- coding: utf-8 -*-
"""Synthesises PLACEHOLDER cast/impact sounds for the Chapter 2 skills.

Mono 16-bit 22.05 kHz, matching the Chapter 1 move audio, so the existing
loader needs no special case. These are procedural stand-ins chosen to suit
each skill's material — paper, coin, stamp, wood, gavel, vault — not final
sound design; overwrite the file of the same name to replace one.
"""
import math, os, random, struct, sys, wave

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from spec import ROSTER

OUT = r"D:\klhgamefinal\assets\audio\sfx\moves"
RATE = 22050

# Which material each skill is made of. Drives the synthesis below so a paper
# attack does not sound like a coin attack.
MATERIAL = {
    "backdoor_dash": "whoosh", "envelope_express": "paper", "queue_skip_kick": "thud",
    "stamp_slam": "stamp", "paper_cut_volley": "paper", "counter_charge": "thud",
    "permit_board_bash": "wood", "fake_seal_shot": "stamp", "carbon_copy_barrage": "paper",
    "notary_stampede": "stamp", "signature_slash": "whoosh", "seal_of_approval": "chime",
    "cash_drawer_bash": "metal", "coin_flick": "coin", "receipt_whip": "paper",
    "budget_bag_bash": "thud", "coin_burst": "coin", "deficit_drop": "boom",
    "briefcase_beatdown": "thud", "bid_folder_fan": "paper", "contract_snare": "whoosh",
    "codex_crusher": "wood", "citation_cannon": "whoosh", "session_smash": "gavel",
    "kaban_ng_bayan": "boom", "plunder_supremo": "coin", "jueteng_jackpot": "chime",
    "executive_privilege": "gavel",
}

# base frequency, decay rate, noise mix, and a light pitch sweep per material
VOICE = {
    "paper":  (2400, 26.0, 0.85, -0.4),
    "coin":   (3100, 13.0, 0.15, +0.2),
    "stamp":  (420,  20.0, 0.45, -0.6),
    "wood":   (300,  15.0, 0.35, -0.3),
    "thud":   (180,  17.0, 0.40, -0.5),
    "boom":   (95,   8.0,  0.30, -0.4),
    "gavel":  (240,  11.0, 0.30, -0.35),
    "metal":  (1500, 12.0, 0.35, -0.2),
    "whoosh": (900,  10.0, 0.95, +0.5),
    "chime":  (1750, 7.0,  0.05, +0.1),
}


def render(material, phase, seed):
    rnd = random.Random(seed)
    base, decay, noise_mix, sweep = VOICE[material]
    # Cast is lighter and shorter than the impact it announces.
    if phase == "cast":
        base *= 1.25
        decay *= 1.5
        dur = 0.20
        amp = 0.34
    else:
        dur = 0.42
        amp = 0.62

    n = int(RATE * dur)
    out = []
    phase_acc = 0.0
    prev = 0.0
    for i in range(n):
        t = i / RATE
        env = math.exp(-decay * t)
        # a couple of partials keep it from sounding like a pure sine test tone
        f = base * (1.0 + sweep * t)
        phase_acc += 2.0 * math.pi * f / RATE
        tone = (math.sin(phase_acc)
                + 0.42 * math.sin(phase_acc * 2.0)
                + 0.18 * math.sin(phase_acc * 3.01))
        # low-passed noise, which is what gives paper and whoosh their texture
        white = rnd.uniform(-1.0, 1.0)
        prev = prev * 0.62 + white * 0.38
        v = (1.0 - noise_mix) * tone / 1.6 + noise_mix * prev
        # short attack so nothing clicks at the start
        v *= min(1.0, t * 220.0) * env * amp
        out.append(max(-1.0, min(1.0, v)))

    return b"".join(struct.pack("<h", int(s * 32000)) for s in out)


def write(path, data):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    made = 0
    for e in ROSTER:
        for m in e["moves"]:
            mat = MATERIAL.get(m["id"], "thud")
            for phase in ("cast", "hit"):
                path = os.path.join(OUT, "%s_%s.wav" % (m["id"], phase))
                write(path, render(mat, phase, hash(m["id"] + phase) & 0xffff))
                made += 1
    print("placeholder move sounds written: %d" % made)
