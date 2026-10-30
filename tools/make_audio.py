#!/usr/bin/env python3
"""Sintetiza la banda sonora y los efectos de POCHLAND.

Los archivos finales son OGG mono/estéreo a 22 050 Hz.
"""
from __future__ import annotations

import math
import subprocess
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "experience" / "assets" / "audio"
WAV = ROOT / "tmp-preview" / "wav"
OUT.mkdir(parents=True, exist_ok=True)
WAV.mkdir(parents=True, exist_ok=True)
SR = 22050


def env(n, attack=0.01, decay=0.0, sustain=1.0, release=0.04):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    r = np.clip((n / SR - t) / max(release, 1e-4), 0, 1)
    d = np.exp(-t * decay) if decay else 1.0
    return a * r * d * sustain


def tone(freq, dur, kind="triangle", vol=0.2, attack=0.01, release=0.05, detune=0.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = freq * (1 + detune)
    phase = 2 * np.pi * f * t
    if kind == "sine":
        w = np.sin(phase)
    elif kind == "triangle":
        w = 2 / np.pi * np.arcsin(np.sin(phase))
    elif kind == "square":
        w = np.sign(np.sin(phase)) * 0.6
    elif kind == "saw":
        w = 2 * ((f * t) % 1) - 1
    else:
        w = np.sin(phase)
    return w * vol * env(n, attack, 0.0, 1.0, release)


def noise(dur, vol=0.1, lowpass=0):
    n = int(SR * dur)
    rng = np.random.default_rng(11)
    w = rng.uniform(-1, 1, n) * vol * env(n, 0.002, 0.0, 1.0, 0.05)
    if lowpass:
        # media móvil simple
        w = np.convolve(w, np.ones(lowpass) / lowpass, mode="same")
    return w


def put(buf, sig, start):
    i = int(start * SR)
    end = min(len(buf), i + len(sig))
    if end > i:
        buf[i:end] += sig[: end - i]


def write(name, data, stereo=False):
    data = np.asarray(data, dtype=np.float64)
    peak = max(0.0001, float(np.max(np.abs(data))))
    if peak > 1:
        data = data / peak
    data = np.clip(data, -1, 1)
    path = WAV / (name + ".wav")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2 if stereo else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        if stereo:
            left, right = data
            inter = np.empty(len(left) * 2, dtype=np.int16)
            inter[0::2] = (np.clip(left, -1, 1) * 32767).astype(np.int16)
            inter[1::2] = (np.clip(right, -1, 1) * 32767).astype(np.int16)
            w.writeframes(inter.tobytes())
        else:
            w.writeframes((np.clip(data, -1, 1) * 32767).astype(np.int16).tobytes())
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(path), "-c:a", "libvorbis", "-q:a", "4",
         str(OUT / (name + ".ogg"))],
        check=True,
    )
    print(name, "-", (OUT / (name + ".ogg")).stat().st_size, "bytes")


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


CHORDS = [
    # Cmaj7 - Am7 - Fmaj7 - G7 : cálido y esperanzador
    [48, 52, 55, 59],
    [45, 48, 52, 55],
    [41, 45, 48, 52],
    [43, 47, 50, 53],
]
BPM = 96
BEAT = 60 / BPM
BARS = 8
LOOP = BARS * 4 * BEAT


def make_music():
    n = int(SR * LOOP)
    left = np.zeros(n)
    right = np.zeros(n)
    rng = np.random.default_rng(5)

    # pad cálido (dos voces desafinadas, ligeramente panoramizadas)
    for bar in range(BARS):
        chord = CHORDS[bar % len(CHORDS)]
        t0 = bar * 4 * BEAT
        for idx, note in enumerate(chord[1:]):
            sig = tone(midi(note + 12), 4 * BEAT * 0.98, "triangle", 0.055, 0.12, 0.5)
            put(left, sig * (0.8 + 0.1 * idx), t0)
            put(right, sig * (0.8 - 0.08 * idx), t0)
            sig2 = tone(midi(note + 12), 4 * BEAT * 0.98, "sine", 0.03, 0.2, 0.6, detune=0.004)
            put(left, sig2, t0)
            put(right, sig2, t0)

    # bajo suave en corcheas
    for bar in range(BARS):
        chord = CHORDS[bar % len(CHORDS)]
        root = chord[0] - 12
        for beat in range(4):
            t0 = bar * 4 * BEAT + beat * BEAT
            sig = tone(midi(root), BEAT * 0.7, "sine", 0.16, 0.01, 0.08)
            put(left, sig, t0)
            put(right, sig, t0)
            if beat % 2 == 1:
                sig2 = tone(midi(root + 12), BEAT * 0.35, "triangle", 0.035, 0.005, 0.04)
                put(left, sig2, t0 + BEAT * 0.5)
                put(right, sig2, t0 + BEAT * 0.5)

    # arpegio brillante (guiño chiptune)
    pat = [0, 2, 1, 3, 2, 1, 3, 2]
    for bar in range(BARS):
        chord = CHORDS[bar % len(CHORDS)]
        for step in range(8):
            t0 = bar * 4 * BEAT + step * BEAT * 0.5
            note = chord[pat[step] % len(chord)] + 24
            if bar % 2 == 1 and step % 4 == 3:
                note += 2
            sig = tone(midi(note), BEAT * 0.42, "square", 0.028, 0.004, 0.05)
            pan = 0.5 + 0.35 * math.sin(step)
            put(left, sig * (1.0 - pan * 0.4), t0)
            put(right, sig * (0.6 + pan * 0.4), t0)

    # melodía principal, frase de 4 compases que respira
    melody = [
        (0, 76, 2), (1.5, 79, 1), (2, 84, 2), (3, 79, 2), (4, 81, 3), (6, 79, 2),
        (7, 76, 3), (9, 72, 2), (10, 74, 2), (11, 76, 2), (12, 79, 4), (16, 81, 2),
        (18, 84, 2), (20, 83, 2), (21, 81, 3), (23, 79, 2), (24, 76, 3), (27, 74, 2),
        (28, 72, 4), (32, 76, 2), (34, 79, 2), (36, 84, 2), (38, 86, 2), (40, 84, 3),
        (43, 81, 2), (44, 79, 4), (48, 81, 2), (50, 79, 2), (52, 77, 2), (54, 76, 2),
        (56, 74, 4), (60, 72, 2), (62, 74, 2),
    ]
    for beat, note, length in melody:
        t0 = beat * BEAT
        dur = length * BEAT * 0.9
        sig = tone(midi(note), dur, "square", 0.038, 0.012, 0.22)
        # eco suave
        echo = tone(midi(note), dur, "triangle", 0.02, 0.012, 0.22)
        put(left, sig, t0)
        put(right, sig * 0.92, t0)
        put(left, echo * 0.5, t0 + BEAT * 0.75)
        put(right, echo * 0.65, t0 + BEAT * 0.75)

    # percusión mínima: bombo y hats de ruido
    for bar in range(BARS):
        for beat in range(4):
            t0 = bar * 4 * BEAT + beat * BEAT
            if beat in (0, 2):
                kick = tone(70, 0.16, "sine", 0.18, 0.002, 0.12)
                put(left, kick, t0)
                put(right, kick, t0)
            hat = noise(0.05, 0.02, lowpass=2)
            put(left, hat, t0 + BEAT * 0.5)
            put(right, hat * 0.8, t0 + BEAT * 0.5)

    # aire estéreo: ruido muy tenue filtrado
    air = noise(LOOP, 0.004, lowpass=36)
    left += air
    right += air * 0.8

    # fundidos de 8ms en los extremos para loop limpio
    fade = int(SR * 0.008)
    for ch in (left, right):
        ch[:fade] *= np.linspace(0, 1, fade)
        ch[-fade:] *= np.linspace(1, 0, fade)

    write("music_loop", np.array([left, right]), stereo=True)


def make_sfx():
    # salto
    n = int(SR * 0.14)
    t = np.arange(n) / SR
    f = 300 + 500 * (t / 0.14) ** 0.7
    sig = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.22 * env(n, 0.004, 4.0, 1, 0.02)
    extra = noise(0.03, 0.04, 2)
    sig[: len(extra)] += extra
    write("sfx_jump", sig)

    # aterrizaje
    n = int(SR * 0.12)
    t = np.arange(n) / SR
    f = 120 - 50 * (t / 0.12)
    sig = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.3 * env(n, 0.002, 18, 1, 0.03)
    extra = noise(0.03, 0.06, 5)
    sig[: len(extra)] += extra
    write("sfx_land", sig)

    # paquete
    buf = np.zeros(int(SR * 0.36))
    for i, f in enumerate([880, 1174.7, 1568]):
        sig = tone(f, 0.12, "square", 0.10, 0.002, 0.15)
        put(buf, sig, i * 0.055)
    write("sfx_collect", buf)

    # caja rota
    n = int(SR * 0.24)
    sig = noise(0.24, 0.28, 3)
    sig *= env(n, 0.001, 12, 1, 0.03)[:n]
    thump = tone(90, 0.12, "sine", 0.16, 0.002, 0.12)
    sig[: len(thump)] += thump
    write("sfx_break", sig)

    # glitch / daño
    n = int(SR * 0.3)
    t = np.arange(n) / SR
    f = 520 - 380 * (t / 0.3)
    phase = np.cumsum(f) / SR
    w = np.sign(np.sin(2 * np.pi * phase))
    # sample-and-hold para bitcrush
    hold = 9
    w = np.repeat(w[::hold], hold)[:n]
    sig = w * 0.09 * env(n, 0.002, 4.0, 1, 0.04)
    write("sfx_glitch", sig)

    # sincronía perfecta
    buf = np.zeros(int(SR * 0.9))
    for i, f in enumerate([523.25, 659.25, 783.99, 1046.5, 1318.5, 1568]):
        put(buf, tone(f, 0.5, "triangle", 0.075, 0.004, 0.14), i * 0.065)
        put(buf, tone(f * 2, 0.3, "sine", 0.018, 0.002, 0.1), i * 0.065)
    write("sfx_sync", buf)

    # impulso del jugador
    n = int(SR * 0.3)
    t = np.arange(n) / SR
    f = 220 + 900 * (t / 0.3) ** 1.5
    sig = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.08 * env(n, 0.004, 3, 1, 0.1)
    extra = noise(0.3, 0.04, 8)
    sig[: len(extra)] += extra
    write("sfx_impulse", sig)

    # ui click
    write("sfx_click", tone(660, 0.06, "square", 0.06, 0.001, 0.2) + tone(990, 0.06, "sine", 0.05, 0.001, 0.2))


if __name__ == "__main__":
    make_music()
    make_sfx()
    print("audio listo")
