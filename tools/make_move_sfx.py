# -*- coding: utf-8 -*-
"""Synthesises one cast sound and one impact sound for every enemy skill.

Procedural for the same reasons the UI chrome is: there is no budget for 30
licensed clips, and a synthesised set can be tuned until each skill is
*identifiable by ear alone*, which is the actual goal. Everything is built
from oscillators, noise and one-pole filters, then lightly bit-crushed so the
audio sits in the same lo-fi register as the pixel art.

Two files per skill, named <move_id>_cast.wav and <move_id>_hit.wav:
  cast — plays as the rival winds up, before anything crosses the screen
  hit  — plays on the frame the attack lands on the player

Run:  python tools/make_move_sfx.py
"""
import os
import struct
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "audio", "sfx", "moves")

rng = np.random.default_rng(20260820)


# --- building blocks -------------------------------------------------------

def t(dur):
    return np.linspace(0.0, dur, int(SR * dur), endpoint=False)


def silence(dur):
    return np.zeros(int(SR * dur))


def env(dur, attack=0.005, decay=None, curve=2.0):
    """Attack/decay envelope. `curve` >1 decays faster at the end."""
    n = int(SR * dur)
    a = max(1, int(SR * attack))
    a = min(a, n)
    out = np.ones(n)
    out[:a] = np.linspace(0.0, 1.0, a)
    d = n - a
    if d > 0:
        out[a:] = np.linspace(1.0, 0.0, d) ** curve
    return out


def osc(freq, dur, kind="sine", duty=0.5):
    """freq may be a scalar or an array the same length as the output."""
    n = int(SR * dur)
    f = np.full(n, float(freq)) if np.isscalar(freq) else np.asarray(freq)[:n]
    phase = np.cumsum(2.0 * np.pi * f / SR)
    if kind == "sine":
        return np.sin(phase)
    if kind == "square":
        return np.where((phase / (2 * np.pi)) % 1.0 < duty, 1.0, -1.0)
    if kind == "saw":
        return 2.0 * ((phase / (2 * np.pi)) % 1.0) - 1.0
    if kind == "tri":
        return 2.0 * np.abs(2.0 * ((phase / (2 * np.pi)) % 1.0) - 1.0) - 1.0
    raise ValueError(kind)


def noise(dur):
    return rng.uniform(-1.0, 1.0, int(SR * dur))


def glide(f0, f1, dur, curve=1.0):
    return f0 + (f1 - f0) * (np.linspace(0.0, 1.0, int(SR * dur)) ** curve)


def lowpass(x, cutoff):
    """One-pole lowpass. `cutoff` may be an array for a sweeping filter."""
    n = len(x)
    c = np.full(n, float(cutoff)) if np.isscalar(cutoff) else np.asarray(cutoff)[:n]
    alpha = np.clip(1.0 - np.exp(-2.0 * np.pi * c / SR), 1e-4, 1.0)
    out = np.zeros(n)
    acc = 0.0
    for i in range(n):
        acc += alpha[i] * (x[i] - acc)
        out[i] = acc
    return out


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandish(x, centre, width=0.6):
    """Cheap band-pass: lowpass above, highpass below."""
    return highpass(lowpass(x, centre * (1.0 + width)), centre * (1.0 - width * 0.5))


def crush(x, bits=8):
    steps = 2 ** bits
    return np.round(x * steps) / steps


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(delay, x):
    """Places `x` after `delay` seconds."""
    return np.concatenate([silence(delay), x])


def seq(*parts):
    return np.concatenate(parts)


def finish(x, peak=0.72):
    """Soft-clip, normalise and de-click."""
    x = np.tanh(x * 1.15)
    m = np.max(np.abs(x))
    if m > 0:
        x = x / m * peak
    fade = min(180, len(x) // 8)
    if fade > 0:
        x[:fade] *= np.linspace(0.0, 1.0, fade)
        x[-fade:] *= np.linspace(1.0, 0.0, fade)
    return crush(x, 9)


def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    data = np.clip(finish(x), -1.0, 1.0)
    pcm = (data * 32767).astype(np.int16)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(struct.pack("<%dh" % len(pcm), *pcm))
    return len(pcm) / SR


# --- shared gestures -------------------------------------------------------

def thud(dur, f0, f1, cutoff=900, curve=2.4):
    """A body hit: pitch-dropping sine plus a filtered noise transient."""
    body = osc(glide(f0, f1, dur, 0.45), dur) * env(dur, 0.002, curve=curve)
    crack = lowpass(noise(dur), cutoff) * env(dur, 0.001, curve=6.0)
    return body * 0.9 + crack * 0.5


def splat(dur, centre=700):
    wet = bandish(noise(dur), centre) * env(dur, 0.001, curve=5.0)
    body = osc(glide(240, 70, dur, 0.5), dur) * env(dur, 0.002, curve=3.5)
    return wet * 0.85 + body * 0.6


def ping(freq, dur, detune=1.41):
    """Metallic: two inharmonic partials."""
    return (osc(freq, dur) * 0.7 + osc(freq * detune, dur) * 0.4) * env(dur, 0.001, curve=3.0)


# --- per-skill sounds ------------------------------------------------------
# Each entry returns (cast, hit).

def padrino_favor():
    # A telephone ringing somewhere off-screen, then the quiet click of a
    # favour being granted. Nothing violent — this is a call, not a punch.
    def ring(dur):
        two = osc(1000, dur) * 0.5 + osc(1250, dur) * 0.5
        chop = (osc(22, dur, "square") * 0.5 + 0.5)
        return two * chop * env(dur, 0.01, curve=1.2)
    cast = mix(ring(0.20), at(0.30, ring(0.20)))
    click = highpass(noise(0.03), 2600) * env(0.03, 0.0005, curve=8.0)
    hit = mix(click * 0.9, at(0.05, thud(0.34, 190, 62, 620)))
    return cast, hit


def dynasty_power():
    # The heaviest sound in the game: three generations winding up, then a
    # boom with real weight behind it.
    rise = osc(glide(58, 190, 0.55, 2.0), 0.55, "saw") * env(0.55, 0.25, curve=0.7)
    rumble = lowpass(noise(0.55), 260) * env(0.55, 0.3, curve=0.8)
    cast = lowpass(rise * 0.7 + rumble * 0.6, 1400)
    boom = osc(glide(120, 34, 0.85, 0.4), 0.85) * env(0.85, 0.002, curve=1.8)
    body = lowpass(noise(0.85), glide(1800, 180, 0.85)) * env(0.85, 0.001, curve=2.6)
    # A gold-plated overtone so it reads as ceremonial rather than just loud.
    bell = ping(196, 0.7, 2.02) * 0.35
    hit = mix(boom * 1.0, body * 0.55, at(0.02, bell))
    return cast, hit


def smear_campaign():
    # A downward scoop, so it reads as a handful of something being flung
    # rather than as generic noise — its cast measured nearly identical to
    # tarpaulin_wall's and ghost_payroll's until this was added.
    d = 0.2
    scoop = osc(glide(520, 120, d, 0.6), d, "tri") * env(d, 0.01, curve=2.2)
    grit = bandish(noise(d), glide(1900, 600, d)) * env(d, 0.01, curve=2.0)
    cast = (scoop * 0.55 + grit * 0.75) * 0.85
    hit = mix(*[at(i * 0.055, splat(0.26, 560 + i * 190) * (0.9 - i * 0.13))
                for i in range(4)])
    return cast, hit


def ballot_defacer():
    # Pen strokes, then the paper gives up.
    strokes = []
    for i in range(3):
        d = 0.07
        s = highpass(noise(d), 2200) * env(d, 0.002, curve=3.0)
        s *= (osc(70 + i * 22, d, "square") * 0.35 + 0.65)
        strokes.append(at(i * 0.085, s))
    cast = mix(*strokes) * 0.85
    # Kept deliberately dry and thin: this is paper giving up, and it has to
    # not sound like sabaw_splash's wet burst.
    tear = bandish(noise(0.34), glide(2600, 5200, 0.34), 0.45) * env(0.34, 0.004, curve=1.9)
    tear *= (osc(46, 0.34, "square") * 0.45 + 0.55)
    hit = mix(tear, at(0.02, thud(0.16, 210, 120, 900) * 0.3))
    return cast, hit


def poster_paste():
    flap = lowpass(noise(0.3), glide(2600, 500, 0.3)) * env(0.3, 0.02, curve=1.4)
    cast = flap * (osc(11, 0.3, "sine") * 0.4 + 0.6)
    slap = lowpass(noise(0.1), 2400) * env(0.1, 0.0008, curve=7.0)
    paste = lowpass(noise(0.3), 700) * env(0.3, 0.01, curve=2.2)
    hit = mix(slap * 1.0, at(0.01, paste * 0.7), at(0.01, thud(0.3, 170, 60, 420) * 0.6))
    return cast, hit


def spray_and_run():
    hiss = highpass(noise(0.34), 3000) * env(0.34, 0.02, curve=1.1)
    cast = hiss * (osc(9, 0.34) * 0.15 + 0.85) * 0.9
    tag = highpass(noise(0.14), 2400) * env(0.14, 0.004, curve=3.0)
    steps = mix(*[at(0.10 + i * 0.065, lowpass(noise(0.05), 700)
                     * env(0.05, 0.001, curve=6.0) * (0.7 - i * 0.15))
                  for i in range(3)])
    hit = mix(tag * 0.8, steps)
    return cast, hit


def filibuster():
    # Deliberately tiresome: a drone that outstays its welcome, answered by a
    # thud with no payoff, because nothing at all passes.
    d = 0.95
    voice = osc(glide(150, 128, d, 1.0) + osc(5.5, d) * 6.0, d, "saw")
    voice *= (osc(3.2, d) * 0.22 + 0.78)
    cast = lowpass(voice, 1100) * env(d, 0.05, curve=0.6) * 0.8
    hit = lowpass(thud(0.26, 120, 78, 340, curve=3.2), 500) * 0.75
    return cast, hit


def sabaw_splash():
    slosh = lowpass(noise(0.34), glide(500, 1500, 0.34)) * env(0.34, 0.03, curve=1.3)
    gurgle = osc(glide(150, 90, 0.34) + osc(14, 0.34) * 30.0, 0.34) * env(0.34, 0.02, curve=1.5)
    cast = slosh * 0.7 + gurgle * 0.5
    # Weighted low and wet so it reads as hot liquid, not as tearing paper.
    burst = splat(0.34, 520) * 1.1
    body = lowpass(noise(0.34), 900) * env(0.34, 0.003, curve=3.0) * 0.6
    sizzle = bandish(noise(0.45), 3000, 0.5) * env(0.45, 0.03, curve=1.2) * 0.3
    hit = mix(burst, body, at(0.06, sizzle))
    return cast, hit


def word_salad():
    # Several people talking over each other, none of them saying anything.
    blips = []
    for i in range(7):
        d = 0.075
        f = float(rng.uniform(300, 1100))
        b = osc(glide(f, f * rng.uniform(0.6, 1.5), d), d, "square", 0.35)
        blips.append(at(i * 0.045, b * env(d, 0.003, curve=2.5) * 0.42))
    cast = mix(*blips)
    tumble = []
    for i in range(6):
        d = 0.07
        f = 900 * (0.82 ** i)
        tumble.append(at(i * 0.05, osc(f, d, "square", 0.4) * env(d, 0.002, curve=3.0) * 0.5))
    clatter = highpass(noise(0.25), 2000) * env(0.25, 0.005, curve=3.0) * 0.35
    hit = mix(mix(*tumble), clatter)
    return cast, hit


def ghost_payroll():
    # Names on a payroll that do not exist: airy, hollow, nothing solid.
    d = 0.6
    swell = bandish(noise(d), 1200, 0.8) * env(d, 0.35, curve=0.8)
    # A tuned, hollow whisper underneath — the tonal content is what tells it
    # apart from the other airy casts by ear rather than only on a spectrogram.
    whisper = (osc(glide(300, 470, d), d) * osc(83, d)) * env(d, 0.3, curve=1.0)
    cast = (swell * 0.7 + whisper * 0.55) * (osc(6, d) * 0.2 + 0.8) * 0.9
    d = 0.7
    hollow = osc(220, d) * osc(97, d)          # ring modulation
    hollow += osc(330, d) * 0.4
    air = highpass(noise(d), 2400) * env(d, 0.05, curve=1.4) * 0.35
    hit = mix(hollow * env(d, 0.01, curve=1.5) * 0.7, air)
    return cast, hit


def tong_collection():
    coins = mix(*[at(i * 0.07, ping(1800 + i * 260, 0.16, 1.62) * (0.7 - i * 0.12))
                  for i in range(3)])
    cast = coins
    ding = ping(2100, 0.35, 1.48) * 0.8
    drawer = lowpass(noise(0.28), 600) * env(0.28, 0.002, curve=4.0) * 0.7
    hit = mix(ding, at(0.06, drawer), at(0.06, thud(0.3, 140, 55, 400) * 0.6))
    return cast, hit


def under_the_table():
    # Quiet, low and unhurried — the whole point is that nobody hears it.
    slide = lowpass(noise(0.4), glide(1400, 320, 0.4)) * env(0.4, 0.06, curve=1.2)
    cast = slide * 0.55
    hit = lowpass(thud(0.36, 130, 46, 300, curve=2.0), 380) * 0.85
    return cast, hit


def medical_mission():
    # Clean and clinical on the way in; the sting only lands afterwards.
    cast = mix(ping(880, 0.3, 1.5) * 0.55, at(0.09, ping(1320, 0.28, 1.5) * 0.45))
    sting = osc(glide(2600, 900, 0.16, 0.5), 0.16, "square", 0.25) * env(0.16, 0.001, curve=4.0)
    cold = ping(1560, 0.34, 2.7) * 0.5
    hit = mix(sting * 0.7, at(0.02, cold), at(0.02, thud(0.26, 160, 70, 700) * 0.45))
    return cast, hit


def relief_goods_blitz():
    heave = lowpass(noise(0.32), glide(400, 1600, 0.32)) * env(0.32, 0.12, curve=1.0)
    cast = heave * 0.8
    sacks = mix(*[at(i * 0.11, thud(0.34, 190 - i * 25, 52, 520) * (1.0 - i * 0.18))
                  for i in range(3)])
    hit = sacks
    return cast, hit


def tarpaulin_wall():
    d = 0.45
    whoosh = bandish(noise(d), glide(700, 2200, d), 0.9) * env(d, 0.18, curve=1.0)
    # Heavy canvas ruffling: a slow, deep flap the other noise sweeps lack.
    flap_am = (osc(7.5, d, "tri") * 0.45 + 0.55)
    body = lowpass(noise(d), 420) * env(d, 0.12, curve=1.1) * 0.5
    cast = (whoosh * flap_am * 0.9 + body)
    flap = lowpass(noise(0.16), 1800) * env(0.16, 0.002, curve=5.0)
    slam = thud(0.6, 150, 40, 500, curve=1.9)
    hit = mix(flap * 0.8, at(0.03, slam))
    return cast, hit


BUILDERS = {
    "padrino_favor": padrino_favor,
    "dynasty_power": dynasty_power,
    "smear_campaign": smear_campaign,
    "ballot_defacer": ballot_defacer,
    "poster_paste": poster_paste,
    "spray_and_run": spray_and_run,
    "filibuster": filibuster,
    "sabaw_splash": sabaw_splash,
    "word_salad": word_salad,
    "ghost_payroll": ghost_payroll,
    "tong_collection": tong_collection,
    "under_the_table": under_the_table,
    "medical_mission": medical_mission,
    "relief_goods_blitz": relief_goods_blitz,
    "tarpaulin_wall": tarpaulin_wall,
}


if __name__ == "__main__":
    print("%-22s %8s %8s" % ("skill", "cast", "hit"))
    for move_id, build in BUILDERS.items():
        cast, hit = build()
        dc = write(move_id + "_cast", cast)
        dh = write(move_id + "_hit", hit)
        print("%-22s %7.2fs %7.2fs" % (move_id, dc, dh))
    print("\n%d files -> %s" % (len(BUILDERS) * 2, OUT))
