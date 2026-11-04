#!/usr/bin/env python3
"""One-shot sound effects for Top Prix (synthesized). Usage: python3 tools/audio/sfx.py [out_dir]"""
import os, sys, struct
import numpy as np
from scipy.signal import butter, sosfilt
SR = 22050
R = np.random.default_rng(42)
def filt(x, kind, f, o=2): return sosfilt(butter(o, f, btype=kind, fs=SR, output="sos"), x)
def env(L, a, d): t = np.arange(L) / SR; return np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / d)
def tone(f, dur, d=0.2, wave="sin"):
    L = int(dur * SR); t = np.arange(L) / SR
    y = np.sin(2 * np.pi * f * t) if wave == "sin" else np.sign(np.sin(2 * np.pi * f * t)) * 0.5
    return y * env(L, 0.003, d)
def S(n): return np.zeros(int(n * SR))
def mix(*parts):
    L = max(len(p[1]) + int(p[0] * SR) for p in parts); y = np.zeros(L)
    for t0, p, g in parts: i = int(t0 * SR); y[i:i + len(p)] += p * g
    return y
SFX = {
    "click": lambda: tone(1800, 0.03, 0.01) * 0.4,
    "beep": lambda: tone(880, 0.25, 0.12, "sq"),
    "go": lambda: tone(1320, 0.5, 0.3, "sq"),
    "coin": lambda: mix((0, tone(1975, 0.4, 0.12), 0.6), (0.06, tone(2637, 0.6, 0.2), 0.7)),          # penny "ting"
    "spark": lambda: mix((0, filt(R.normal(0, 1, int(0.6 * SR)), "bandpass", (900, 5000)) * env(int(0.6 * SR), 0.15, 0.2), 0.5),
                         (0, tone(1975, 0.4, 0.12), 0.4), (0.06, tone(2637, 0.6, 0.2), 0.5)),
    "crash": lambda: mix((0, filt(R.normal(0, 1, int(0.9 * SR)), "lowpass", 2500) * env(int(0.9 * SR), 0.002, 0.18), 1.0),
                         (0.05, sum(np.sin(2 * np.pi * f * np.arange(int(0.6 * SR)) / SR) for f in (1210, 1830, 2650, 3410)) * env(int(0.6 * SR), 0.001, 0.12) * 0.25, 1.0),
                         (0.12, filt(R.normal(0, 1, int(0.4 * SR)), "highpass", 3000) * env(int(0.4 * SR), 0.001, 0.08), 0.5)),
    "bump": lambda: filt(R.normal(0, 1, int(0.25 * SR)), "lowpass", 900) * env(int(0.25 * SR), 0.002, 0.05) * 1.2,
    "screech": lambda: np.sin(2 * np.pi * np.cumsum(2200 + 180 * np.sin(2 * np.pi * 23 * np.arange(int(0.7 * SR)) / SR)) / SR) * env(int(0.7 * SR), 0.03, 0.3) * 0.35
                       + filt(R.normal(0, 1, int(0.7 * SR)), "bandpass", (1500, 4000)) * env(int(0.7 * SR), 0.03, 0.3) * 0.25,
    "crowd": lambda: filt(R.normal(0, 1, int(2.5 * SR)), "bandpass", (300, 3500)) * np.minimum(1, np.arange(int(2.5 * SR)) / (0.4 * SR)) * np.exp(-np.arange(int(2.5 * SR)) / (1.4 * SR)) * 0.7
                     + sum(mix((t, filt(R.normal(0, 1, 600), "bandpass", (1000, 4000)) * env(600, 0.001, 0.01), 0.6)).tolist().__len__() * 0 for t in [0]) ,
    "cash": lambda: mix((0, filt(R.normal(0, 1, int(0.08 * SR)), "highpass", 2000) * env(int(0.08 * SR), 0.001, 0.02), 0.6),
                        (0.08, tone(2093, 0.9, 0.35), 0.5), (0.08, tone(2637, 0.9, 0.3), 0.35)),
    "ratchet": lambda: mix(*[(i * 0.045, filt(R.normal(0, 1, 400), "bandpass", (2000, 6000)) * env(400, 0.0005, 0.004), 0.8) for i in range(8)]),
    "fanfare": lambda: mix(*[(i * 0.12, tone(f, 0.4, 0.25, "sq") * 0.5, 1.0) for i, f in enumerate((523, 659, 784, 1047))]),
    "good": lambda: mix((0, tone(988, 0.2, 0.08, "sq"), 0.4), (0.08, tone(1319, 0.3, 0.12, "sq"), 0.4)),
    "start": lambda: mix((0, tone(880, 0.25, 0.12, "sq"), 0.5), (0.6, tone(880, 0.25, 0.12, "sq"), 0.5), (1.2, tone(880, 0.25, 0.12, "sq"), 0.5), (1.8, tone(1320, 0.5, 0.3, "sq"), 0.6)),
}
def write(path, y):
    y = y / (np.abs(y).max() + 1e-9) * 0.8
    pcm = np.clip(np.round(y * 32767), -32768, 32767).astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    d = b"WAVE" + b"fmt " + struct.pack("<I", 16) + fmt + b"data" + struct.pack("<I", len(pcm)) + pcm
    open(path, "wb").write(b"RIFF" + struct.pack("<I", len(d)) + d)
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "../../godot/audio/sfx")
os.makedirs(out, exist_ok=True)
for k, f in SFX.items(): write(os.path.join(out, k + ".wav"), np.asarray(f(), dtype=float))
print(len(SFX), "sfx ->", out)
