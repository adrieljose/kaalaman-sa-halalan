# -*- coding: utf-8 -*-
"""Synthesises a hurt-voice set for every Chapter 2 rival.

Why synthesised rather than recorded: the game had ONE shared enemy_hurt set of
three takes, played for all nine rivals, so an ogre and a cashier yelped in the
same voice. Nine distinct casts is not something a placeholder library can
supply, and there is no voice talent in this project -- but a hurt grunt is a
short vowel, and a short vowel is exactly what formant synthesis is good at.

The model is the standard source-filter one:

  SOURCE   a glottal pulse train at F0, with a per-character pitch CONTOUR --
           this is most of what separates a startled yelp (pitch shoots up)
           from an annoyed grumble (pitch sags) even at the same vowel.
  FILTER   three resonators at the formant frequencies of a chosen vowel.
           F1/F2 place the vowel; the character's vocal-tract LENGTH is applied
           as a scale over all three, which is what makes the ogre read as a
           big body and the cashier as a small one rather than as the same
           person pitch-shifted.
  NOISE    breath through the same filter, mixed under the voiced part.
  GROWL    an octave-down subharmonic, for the rivals who need weight.

Every take is rendered from the character's parameters with a little jitter, so
the three variants are siblings rather than copies.

Output: assets/audio/sfx/voices/<voice>_hurt_<n>.ogg, encoded with ffmpeg.
"""
import math
import os
import shutil
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np
from scipy.signal import lfilter

SR = 44100
OUT = Path("assets/audio/sfx/voices")
FFMPEG = shutil.which("ffmpeg")

# Vowel formants (F1, F2, F3) for a neutral adult tract, in Hz.
VOWELS = {
    "uh": (620, 1150, 2400),   # grumble
    "ah": (730, 1300, 2500),   # open shout
    "eh": (530, 1800, 2550),   # sharp, forward
    "ih": (390, 2000, 2650),   # tight, panicked
    "oh": (450, 850, 2400),    # dark, heavy
}

# Contours are pitch multipliers sampled across the take. They carry the
# ACTING: where the pitch goes is what makes a sound read as startled,
# irritated or composed.
CONTOURS = {
    "startled":  [1.00, 1.28, 1.34, 1.18, 0.96],   # shoots up, then drops
    "annoyed":   [1.06, 1.00, 0.93, 0.86, 0.80],   # sags throughout
    "panicked":  [1.10, 1.36, 1.30, 1.40, 1.12],   # high and unsteady
    "theatrical":[0.94, 1.22, 1.05, 1.25, 0.82],   # swoops, milks it
    "offended":  [1.14, 1.06, 1.10, 0.98, 0.90],   # clipped, indignant
    "heavy":     [1.00, 0.95, 0.90, 0.84, 0.74],   # drops like a weight
    "composed":  [1.02, 1.00, 0.99, 0.97, 0.94],   # barely moves
    "monstrous": [0.96, 1.02, 0.98, 0.90, 0.78],   # slow, deep roll
    "imperious": [1.08, 1.02, 1.04, 0.95, 0.86],   # authority, then irritation
    "furious":   [1.16, 1.30, 1.22, 1.26, 0.94],   # control lost
}

# voice id -> parameters.
#   f0      base pitch in Hz -- the single biggest identity cue
#   tract   formant scale. >1 = shorter tract (smaller body), <1 = longer
#   vowel   which vowel the grunt sits on
#   dur     seconds
#   contour which pitch shape above
#   growl   0..1 subharmonic mix, for weight
#   breath  0..1 noise mix
#   rasp    0..1 pulse-timing jitter, reads as a rough/aged voice
VOICES = {
    # Sneaky and cocky, so being hit is a SURPRISE more than a pain.
    "fixer_fredo":    dict(f0=152, tract=1.04, vowel="eh", dur=0.30,
                           contour="startled", growl=0.00, breath=0.16, rasp=0.10),
    # Older office worker: lower, raspier, and permanently put upon.
    "clerk_kurakot":  dict(f0=112, tract=0.94, vowel="uh", dur=0.40,
                           contour="annoyed", growl=0.10, breath=0.14, rasp=0.30),
    # Nervous forger who never expected to be caught.
    "permit_peke":    dict(f0=196, tract=1.10, vowel="ih", dur=0.26,
                           contour="panicked", growl=0.00, breath=0.24, rasp=0.06),
    # Plays every injury to the back row.
    "notaryo_naku":   dict(f0=138, tract=1.00, vowel="ah", dur=0.58,
                           contour="theatrical", growl=0.04, breath=0.12, rasp=0.14),
    # Sharp and strict; a woman who is offended rather than hurt.
    "cashier_kaltas": dict(f0=238, tract=1.16, vowel="eh", dur=0.28,
                           contour="offended", growl=0.00, breath=0.13, rasp=0.05),
    # Rough and greedy: a big chest and no composure at all.
    "budget_bandido": dict(f0=96,  tract=0.90, vowel="ah", dur=0.44,
                           contour="heavy", growl=0.30, breath=0.10, rasp=0.24),
    # Keeps his face straight even while taking it.
    "bidding_bandit": dict(f0=126, tract=0.99, vowel="uh", dur=0.24,
                           contour="composed", growl=0.05, breath=0.10, rasp=0.04),
    # Far heavier than anyone else on the roster, by design.
    "ordinance_ogre": dict(f0=61,  tract=0.78, vowel="oh", dur=0.66,
                           contour="monstrous", growl=0.62, breath=0.08, rasp=0.34),
    # The boss, holding his authority together.
    "don_eraptado":   dict(f0=104, tract=0.92, vowel="ah", dur=0.46,
                           contour="imperious", growl=0.18, breath=0.11, rasp=0.26),
}

# The boss alone gets a second, angrier register for heavy damage and phase 2 --
# the brief says he must not sound the same when the composure goes.
HEAVY = {
    "don_eraptado": dict(f0=118, tract=0.94, vowel="ah", dur=0.60,
                         contour="furious", growl=0.34, breath=0.16, rasp=0.38),
}

TAKES = 3


def contour_curve(name, n):
    pts = np.array(CONTOURS[name], dtype=float)
    return np.interp(np.linspace(0, len(pts) - 1, n), np.arange(len(pts)), pts)


def glottal(n, f0_track, rasp, rng):
    """A pulse train whose period follows the pitch track.

    Built by accumulating phase rather than by placing pulses on a fixed grid,
    so the pitch contour bends the source continuously instead of stepping.
    Each pulse is a short raised-cosine burst -- crude next to a real glottal
    model, but it puts energy across the whole spectrum, which is what the
    formant filters need to work with.
    """
    out = np.zeros(n)
    phase = 0.0
    i = 0
    while i < n:
        period = SR / max(f0_track[min(i, n - 1)], 20.0)
        # Rasp is period jitter: an uneven glottis is what an aged or rough
        # voice actually is.
        period *= 1.0 + rng.uniform(-rasp, rasp) * 0.45
        w = max(int(period * 0.32), 2)
        burst = 0.5 - 0.5 * np.cos(np.linspace(0, 2 * math.pi, w))
        end = min(i + w, n)
        out[i:end] += burst[:end - i]
        i += max(int(period), 2)
        phase += 1.0
    return out


def resonate(x, freq, bw):
    """One two-pole formant resonator."""
    r = math.exp(-math.pi * bw / SR)
    theta = 2 * math.pi * freq / SR
    a = [1.0, -2.0 * r * math.cos(theta), r * r]
    # Normalised so the peak does not blow up as bandwidth narrows.
    b = [(1.0 - r) * math.sqrt(1.0 - 2.0 * r * math.cos(2 * theta) + r * r)]
    return lfilter(b, a, x)


def render(p, seed):
    rng = np.random.default_rng(seed)
    dur = p["dur"] * rng.uniform(0.92, 1.08)
    n = int(SR * dur)
    t = np.linspace(0, dur, n, endpoint=False)

    f0 = p["f0"] * rng.uniform(0.97, 1.03)
    track = f0 * contour_curve(p["contour"], n)
    # A slow wobble keeps it off a synthetic straight line.
    track *= 1.0 + 0.02 * np.sin(2 * math.pi * rng.uniform(4.5, 7.5) * t)

    src = glottal(n, track, p["rasp"], rng)
    if p["growl"] > 0.0:
        # An octave-down train under the main one: the standard cheap way to
        # add body without simply lowering the pitch.
        src += p["growl"] * glottal(n, track * 0.5, p["rasp"] * 1.3, rng)
    src += p["breath"] * rng.normal(0, 0.35, n)

    f1, f2, f3 = (f * p["tract"] for f in VOWELS[p["vowel"]])
    voiced = (1.00 * resonate(src, f1, 90)
              + 0.62 * resonate(src, f2, 120)
              + 0.28 * resonate(src, f3, 170))

    # Envelope: near-instant attack (a grunt has no fade-in), then a decay
    # shaped so the tail is longer on the heavy voices.
    atk = max(int(SR * 0.012), 1)
    env = np.ones(n)
    env[:atk] = np.linspace(0, 1, atk)
    tail = np.exp(-np.linspace(0, 1, n) * (2.6 if p["dur"] > 0.45 else 3.6))
    env *= tail
    # And a hard-ish stop, so nothing rings past the flinch animation.
    rel = max(int(SR * 0.03), 1)
    env[-rel:] *= np.linspace(1, 0, rel)

    y = voiced * env
    peak = np.max(np.abs(y))
    if peak > 0:
        y = y / peak * 0.86
    return y


def write(path, y):
    pcm = (np.clip(y, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main():
    if FFMPEG is None:
        sys.exit("ffmpeg not found -- needed to encode .ogg")
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = [(v, p, "hurt") for v, p in VOICES.items()]
    # The boss's angrier register is just another VOICE, named
    # "<id>_rage", so play_voice needs no second concept for it.
    jobs += [(v + "_rage", p, "hurt") for v, p in HEAVY.items()]

    made = 0
    for voice, params, kind in jobs:
        for i in range(1, TAKES + 1):
            y = render(params, seed=abs(hash((voice, kind, i))) % (2 ** 31))
            wav = OUT / f"{voice}_{kind}_{i}.wav"
            ogg = OUT / f"{voice}_{kind}_{i}.ogg"
            write(wav, y)
            subprocess.run(
                [FFMPEG, "-y", "-loglevel", "error", "-i", str(wav),
                 "-c:a", "libvorbis", "-q:a", "4", str(ogg)], check=True)
            wav.unlink()
            made += 1
            print(f"  {ogg.name}  {len(y)/SR:.2f}s  f0~{params['f0']}Hz "
                  f"{params['vowel']}/{params['contour']}")
    print(f"\n{made} takes across {len(jobs)} voices -> {OUT}")


main()
