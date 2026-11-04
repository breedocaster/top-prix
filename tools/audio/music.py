#!/usr/bin/env python3
"""Original classic-rock soundtrack for Top Prix, composed as code.

Songs are original melodies over standard rock idioms (12-bar blues, boogie, I-bVII-IV, surf i-bVII-bVI-V).
Each song is a set of event lists (Song.tracks). Two renderers:

  default : event lists -> multi-track Standard MIDI File (mido) -> FluidSynth, stem by stem -> mixdsp.
            Menu songs use the hi-fi path (MuseScore_General soundfont, 44.1 kHz, reverb/chorus, mastered to
            -14 LUFS); race songs and jingles use the SNES path (FluidR3_GM at 32 kHz through an S-DSP-style
            chain: BRR-like grit, Gaussian interpolation, FIR echo). Soundfonts are MIT (see godot/audio/CREDITS.md).
  --synth : the original home-made synthesis (Karplus-Strong guitars through an overdrive, saw lead, additive
            organ, synthesized drums) at 32 kHz. No soundfonts involved.

Usage: python3 tools/audio/music.py [song ...] [--out DIR] [--synth] [--profile hifi|snes] [--midi DIR]
       (see tools/audio/README.md)
"""
import os, sys, subprocess, tempfile
import numpy as np
from scipy.signal import fftconvolve, butter, sosfilt

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.dont_write_bytecode = True   # don't leave tools/audio/__pycache__ in the repo
import mido      # noqa: E402  (pip install --break-system-packages mido)
import mixdsp    # noqa: E402

SR = 32000
R = np.random.default_rng(1966)
NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
CHORD = {"5": [0, 7, 12], "": [0, 4, 7, 12], "m": [0, 3, 7, 12], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10], "9": [0, 4, 10, 14], "6": [0, 4, 9]}


def midi(n):
    """'E2' -> 40"""
    name = n[:-1]; octv = int(n[-1])
    return 12 * (octv + 1) + NOTE[name]


def hz(m): return 440.0 * 2 ** ((m - 69) / 12.0)


def chord(sym, octave=2):
    """'A5', 'Dm', 'E7' -> (root midi, intervals)"""
    i = 2 if len(sym) > 1 and sym[1] in "#b" else 1
    root = 12 * (octave + 1) + NOTE[sym[:i]]
    return root, CHORD[sym[i:]]


def sos_filter(x, kind, f, order=2):
    sos = butter(order, f if np.isscalar(f) else list(f), btype=kind, fs=SR, output="sos")
    return sosfilt(sos, x)

# ---------------- instruments ----------------
def pluck(f, dur, decay=2.0, bright=0.6, vel=1.0):
    """Karplus-Strong with fractional delay via the weighted two-tap loop filter (block-vectorized)."""
    L = int(dur * SR)
    D = SR / f
    N = int(D); w = D - N
    N = max(N, 2)
    g = np.exp(-1.0 / (f * decay))
    exc = R.uniform(-1, 1, N)
    if bright < 1.0:
        a = 0.15 + 0.85 * bright
        for i in range(1, N): exc[i] = a * exc[i] + (1 - a) * exc[i - 1]
    x = np.zeros(L); x[:min(N, L)] = exc[:min(N, L)] * vel
    O = N + 1
    Y = np.zeros(L + O)
    for s in range(0, L, N):
        n = np.arange(s, min(s + N, L))
        Y[O + n] = x[n] + g * ((1 - w) * Y[n + 1] + w * Y[n])
    y = Y[O:]
    rel = min(L, int(0.015 * SR))
    if rel > 0: y[-rel:] *= np.linspace(1, 0, rel)
    return y


def saw_lead(notes, total, vib=5.5):
    """notes: [(t0, dur, midi, bend_semitones, vel)] -> band-limited-ish saw+pulse with vibrato after attack."""
    out = np.zeros(total)
    for t0, dur, m, bend, vel in notes:
        i0 = int(t0 * SR); L = int(dur * SR)
        if i0 >= total: continue
        L = min(L, total - i0)
        t = np.arange(L) / SR
        bend_env = bend * np.clip(t / 0.09, 0, 1) if bend else 0.0
        vib_env = np.clip((t - 0.18) / 0.25, 0, 1) * 0.22
        fr = hz(m + bend_env + vib_env * np.sin(2 * np.pi * vib * t))
        ph = np.cumsum(fr) / SR
        y = np.zeros(L)
        for k in range(1, 14):                       # additive saw, harmonics fall off naturally
            y += np.sin(2 * np.pi * k * ph) / k * (fr * k < SR / 2.2)
        y += 0.4 * np.sign(np.sin(2 * np.pi * ph + 0.3))
        env = np.minimum(1, t / 0.008) * np.exp(-t / 2.5)
        rel = min(L, int(0.03 * SR)); env[-rel:] *= np.linspace(1, 0, rel)
        out[i0:i0 + L] += y * env * vel
    return out


def organ(notes, total, bars=(0.8, 1.0, 0.6, 0.0, 0.35, 0.0, 0.2), leslie=6.2, farfisa=False):
    """Drawbar organ: harmonics 1/2,1,2,3,4,6,8 of f (16',8',4',2 2/3',2',1 1/3',1'); Leslie AM/FM."""
    out = np.zeros(total)
    mult = [0.5, 1, 2, 3, 4, 6, 8]
    for t0, dur, ms, vel in notes:
        i0 = int(t0 * SR); L = min(int(dur * SR), total - i0)
        if L <= 0: continue
        t = np.arange(L) / SR
        y = np.zeros(L)
        for m in (ms if isinstance(ms, (list, tuple)) else [ms]):
            f = hz(m)
            for g, k in zip(bars, mult):
                if g and f * k < SR / 2.2:
                    y += g * (np.sign(np.sin(2 * np.pi * f * k * t)) * 0.6 if farfisa and k <= 2 else np.sin(2 * np.pi * f * k * t))
        env = np.minimum(1, t / 0.004)
        rel = min(L, int(0.02 * SR)); env[-rel:] *= np.linspace(1, 0, rel)
        click = np.exp(-t / 0.003) * R.normal(0, 0.3, L)
        out[i0:i0 + L] += (y * env + click) * vel
    tt = np.arange(total) / SR
    lfo = np.sin(2 * np.pi * leslie * tt)
    return out * (0.82 + 0.18 * lfo)


def drum(kind, vel=1.0):
    # kinds added for the MIDI arrangements, mapped onto the closest home-made voice for --synth
    kind = {"r": "h", "rb": "o", "c2": "c", "ss": "s", "hp": "h"}.get(kind, kind)
    if kind == "k":
        L = int(0.35 * SR); t = np.arange(L) / SR
        f = 48 + 95 * np.exp(-t / 0.035)
        y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.16) + 0.4 * R.normal(0, 1, L) * np.exp(-t / 0.002)
    elif kind == "s":
        L = int(0.3 * SR); t = np.arange(L) / SR
        nz = sos_filter(R.normal(0, 1, L), "bandpass", (1200, 7500))
        y = 0.9 * nz * np.exp(-t / 0.11) + 0.6 * np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.06)
    elif kind in ("h", "o"):
        L = int((0.06 if kind == "h" else 0.35) * SR); t = np.arange(L) / SR
        y = sos_filter(R.normal(0, 1, L), "highpass", 7000) * np.exp(-t / (0.022 if kind == "h" else 0.12)) * 0.5
    elif kind == "c":
        L = int(1.8 * SR); t = np.arange(L) / SR
        y = sos_filter(R.normal(0, 1, L), "highpass", 3500) * np.exp(-t / 0.55) * 0.6
        for f in (3150, 4230, 5590, 6920): y += 0.05 * np.sin(2 * np.pi * f * t) * np.exp(-t / 0.4)
    elif kind in ("t1", "t2", "t3"):
        f0 = {"t1": 190, "t2": 140, "t3": 98}[kind]
        L = int(0.45 * SR); t = np.arange(L) / SR
        f = f0 * (1 + 0.5 * np.exp(-t / 0.03))
        y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.2) + 0.15 * R.normal(0, 1, L) * np.exp(-t / 0.01)
    else:
        return np.zeros(1)
    return y * vel


def amp(x, gain=8.0, tone=4200, low=90):
    """Overdrive + 4x12-ish cab: pre-emphasis, tanh clip, cab low-pass, mid bump."""
    x = sos_filter(x, "highpass", low)
    x = np.tanh(gain * x) / np.tanh(gain)
    x = sos_filter(x, "lowpass", tone, 4)
    x = x + 0.35 * sos_filter(x, "bandpass", (700, 1900))
    return x


def reverb(x, secs=1.6, wet=0.22, bright=6000, spring=False, seed=7):
    rr = np.random.default_rng(seed)
    L = int(secs * SR); t = np.arange(L) / SR
    out = []
    for ch in range(2):
        ir = rr.normal(0, 1, L) * np.exp(-t / (secs / 5.5))
        ir = sos_filter(ir, "lowpass", bright)
        if spring:   # dispersive "boing": chirped ringing on top
            ir += 0.6 * np.sin(2 * np.pi * (2200 * t - 900 * t * t)) * np.exp(-t / 0.35) * rr.normal(1, 0.1, L)
        ir[:int(0.012 * SR)] = 0
        ir /= np.sqrt(np.sum(ir ** 2))
        out.append(fftconvolve(x, ir)[:len(x)])
    return np.stack(out) * wet


# ---------------- sequencing ----------------
class Song:
    def __init__(self, name, bpm, bars, swing=0.0, beats=4):
        self.name, self.bpm, self.swing, self.beats = name, bpm, swing, beats
        self.spb = 60.0 / bpm
        self.total = int((bars * beats + 2.0) * self.spb * SR)
        self.tracks = {}

    def t(self, beat):
        """Beat (float) -> seconds, with swing on off-beat 8ths."""
        b = np.floor(beat); f = beat - b
        if self.swing and abs(f - 0.5) < 1e-6: f = 0.5 + self.swing * (2 / 3 - 0.5) * 2
        return (b + f) * self.spb

    def add(self, track, events): self.tracks.setdefault(track, []).extend(events)

    def render(self):
        n = self.total
        mix = np.zeros((2, n))
        def place(buf, y, t0, gain=1.0):
            i0 = int(t0 * SR)
            if i0 >= n: return
            m = min(len(y), n - i0); buf[i0:i0 + m] += y[:m] * gain
        def pan(y, p, g=1.0):
            return np.stack([y * np.cos((p + 1) * np.pi / 4), y * np.sin((p + 1) * np.pi / 4)]) * g
        sends = np.zeros(n)
        merged = {}                       # 'rhythm:mute', 'clean:trem' are MIDI-only splits; the synth mixes by kind
        for name, ev in self.tracks.items():
            merged.setdefault(name.split(":")[0], []).extend(ev)
        for name, ev in merged.items():
            kind = name
            buf = np.zeros(n)
            if kind == "drums":
                for b, k, v in ev: place(buf, drum(k, v), self.t(b))
                mix += pan(buf, 0.0, 0.55)
                sends += buf * 0.15
            elif kind in ("rhythm", "clean", "bass"):
                for b, d, ms, v, dec, br in ev:
                    for m in (ms if isinstance(ms, (list, tuple)) else [ms]):
                        place(buf, pluck(hz(m), d * self.spb + 0.05, dec, br, v), self.t(b) + R.uniform(0, 0.006))
                if kind == "rhythm":
                    y = amp(buf * 2.2, 9.0, 4300)
                    mix += pan(y, -0.55, 0.2) + pan(np.roll(y, int(0.011 * SR)), 0.55, 0.2)   # double-tracked
                    sends += y * 0.12
                elif kind == "clean":
                    y = amp(buf * 0.7, 1.6, 6500, 120)
                    mix += pan(y, 0.35, 0.36); sends += y * 0.5
                else:
                    y = sos_filter(np.tanh(buf * 1.5), "lowpass", 1400) + 0.5 * sos_filter(buf, "lowpass", 160)
                    mix += pan(y, 0.0, 0.42)
            elif kind == "lead":
                notes = [(self.t(b), d * self.spb, m, bend, v) for b, d, m, bend, v in ev]
                y = amp(saw_lead(notes, n) * 0.5, 6.0, 4800, 200)
                dl = np.zeros(n); dl[int(0.36 * SR):] = y[:n - int(0.36 * SR)] * 0.3
                mix += pan(y + dl, 0.15, 0.3); sends += y * 0.3
            elif kind in ("organ", "farfisa"):
                notes = [(self.t(b), d * self.spb, ms, v) for b, d, ms, v in ev]
                y = organ(notes, n, farfisa=(kind == "farfisa"),
                          bars=(0.3, 1.0, 0.8, 0.0, 0.5, 0.0, 0.3) if kind == "farfisa" else (0.8, 1.0, 0.6, 0.0, 0.35, 0.0, 0.2))
                y = sos_filter(y, "lowpass", 5000)
                mix += pan(y, -0.3, 0.12); sends += y * 0.08
        spring = self.name == "gravel_surf"
        mix += reverb(sends, 2.2 if spring else 1.6, 0.35 if spring else 0.2, spring=spring)
        mix = sos_filter(mix, "highpass", 30)
        mix /= np.sqrt(np.mean(mix ** 2)) + 1e-9
        mix *= 0.16
        mix = np.tanh(mix * 1.6) / 1.6          # bus glue
        fade = int(0.8 * SR); mix[:, -fade:] *= np.linspace(1, 0, fade)
        return mix


# ---------------- song building helpers ----------------
def drums_rock(s, bar, fill=False, crash=False, ride8=True, ride=False, ghost=True):
    """Straight rock beat. ride: 8ths on the ride instead of the hats (chorus lift). ghost: quiet snare 16ths
    on the 'a' of 2 and the 'e' of 4. fill: snare pickup on the 'and' of 3, then toms down the kit."""
    b = bar * 4; ev = [(b, "k", 1.0), (b + 2, "k", 0.95), (b + 2.5, "k", 0.6), (b + 1, "s", 0.9), (b + 3, "s", 0.95)]
    cym, cg = ("r", 0.85) if ride else ("h", 1.0)
    ev += [(b + i * 0.5, cym, (0.5 + 0.2 * (i % 2 == 0)) * cg) for i in range(8)] if ride8 else []
    if ghost: ev += [(b + 1.75, "s", 0.2), (b + 3.25, "s", 0.17)]
    if crash: ev.append((b, "c", 0.8))
    if fill: ev = [e for e in ev if e[0] < b + 2.5 or e[1] == "k"] + [(b + 2.5, "s", 0.55), (b + 2.75, "s", 0.65), (b + 3, "t1", 0.85),
                                                                      (b + 3.25, "t1", 0.75), (b + 3.5, "t2", 0.85), (b + 3.75, "t3", 0.95), (b + 3.5, "k", 0.7)]
    s.add("drums", ev)


def drums_shuffle(s, bar, crash=False, soft=1.0, ride=False, ghost=True):
    """Shuffle: hats (or ride) on quarters plus the swung skip note; ghost snares on the skip before 2 and 4."""
    b = bar * 4
    cym = "r" if ride else "h"
    ev = [(b, "k", 1.0 * soft), (b + 2, "k", 0.9 * soft), (b + 1, "s", 0.85 * soft), (b + 3, "s", 0.9 * soft)]
    ev += [(b + i, cym, 0.5 * soft) for i in range(4)] + [(b + i + 0.5, cym, 0.35 * soft) for i in range(4)]
    if ghost: ev += [(b + 0.5, "s", 0.16 * soft), (b + 2.5, "s", 0.16 * soft)]
    if crash: ev.append((b, "c", 0.75))
    s.add("drums", ev)


def drums_surf(s, bar, crash=False):
    """Surf tom beat. The floor tom 8ths are lighter than they were (the mix was bass-heavy) and closed hats
    on the 8ths put some top end back into the groove."""
    b = bar * 4
    ev = [(b + i * 0.5, "t3", 0.34 if i % 2 else 0.5) for i in range(8)] + [(b + 1, "s", 0.9), (b + 3, "s", 0.9), (b, "k", 0.9), (b + 2, "k", 0.8)]
    ev += [(b + i * 0.5, "h", 0.42 if i % 2 else 0.55) for i in range(8)]
    if crash: ev.append((b, "c", 0.7))
    s.add("drums", ev)


def power(s, bar, sym, pattern, octave=2, mute_dec=0.18, dec=2.5, vel=1.0, beats=4):
    """pattern: string of 8ths: 'X' = full power chord, 'x' = palm-muted, '-' = rest/let ring."""
    root, iv = chord(sym if sym[-1] == "5" else sym[:2 if len(sym) > 1 and sym[1] in "#b" else 1] + "5", octave)
    ev, mutes = [], []
    step = beats / len(pattern)
    for i, c in enumerate(pattern):
        if c == "-": continue
        d = step
        j = i + 1
        while j < len(pattern) and pattern[j] == "-": d += step; j += 1
        notes = [root + k for k in iv] if c == "X" else [root, root + 7]
        (ev if c == "X" else mutes).append((bar * beats + i * step, d, notes, vel * (1.0 if c == "X" else 0.75), dec if c == "X" else mute_dec, 0.7 if c == "X" else 0.35))
    s.add("rhythm", ev)
    if mutes: s.add("rhythm:mute", mutes)       # palm-muted hits get their own MIDI channels (GM muted guitar)


def boogie(s, bar, sym, octave=2):
    """Boogie shuffle riff on the low strings: root-5, root-5, root-6, root-6, root-b7, root-b7, root-6, root-6."""
    root, _ = chord(sym, octave)
    seq = [7, 7, 9, 9, 10, 10, 9, 9]
    s.add("rhythm", [(bar * 4 + i * 0.5, 0.5, [root, root + seq[i]], 0.85, 0.25, 0.45) for i in range(8)])


def walk(s, bar, sym, octave=1, style="walk"):
    root, iv = chord(sym, octave)
    if style == "walk":
        seq = [0, 4 if 4 in iv or "7" in sym else 3, 7, 9]
        s.add("bass", [(bar * 4 + i, 1.0, root + seq[i], 0.9, 0.9, 0.35) for i in range(4)])
    elif style == "8ths":
        s.add("bass", [(bar * 4 + i * 0.5, 0.5, root + (12 if i == 6 else 0), 0.85, 0.6, 0.4) for i in range(8)])
    elif style == "root":
        s.add("bass", [(bar * 4, 2.0, root, 0.9, 1.2, 0.35), (bar * 4 + 2, 1.5, root, 0.8, 1.0, 0.35), (bar * 4 + 3.5, 0.5, root + 7, 0.7, 0.6, 0.35)])


def lead(s, start_bar, phrase, octave=4, vel=0.9):
    """phrase: list of (beat_offset, dur_beats, 'E', octave_shift, bend) relative to start bar."""
    ev = []
    for off, d, n, osh, bend in phrase:
        ev.append((start_bar * 4 + off, d, midi(n + str(octave + osh)), bend, vel))
    s.add("lead", ev)


def blues12(key):
    I, IV, V = key, transpose(key, 5), transpose(key, 7)
    return [I, IV, I, I, IV, IV, I, I, V, IV, I, V]


def transpose(sym, semis):
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    i = 2 if len(sym) > 1 and sym[1] in "#b" else 1
    root = (NOTE[sym[:i]] + semis) % 12
    return names[root] + sym[i:]


# ---------------- the songs (all original) ----------------
def tinplate_boogie():
    prog = blues12("E7"); s = Song("tinplate_boogie", 126, 4 + 12 * 3 + 2, swing=0.62)
    for b in range(4): boogie(s, b, "E7"); drums_shuffle(s, b, soft=0.6 if b < 2 else 1.0)
    for rep in range(3):
        for i, sym in enumerate(prog):
            bar = 4 + rep * 12 + i
            boogie(s, bar, sym); walk(s, bar, sym); drums_shuffle(s, bar, crash=(i == 0), ride=(rep == 2))   # ride lifts the last chorus
            if rep != 1 and i % 2 == 1:
                r, iv = chord(sym, 4); s.add("organ", [(bar * 4 + 1.5, 0.4, [r + k for k in iv[:3]], 0.5), (bar * 4 + 3.5, 0.4, [r + k for k in iv[:3]], 0.5)])
    # head melody (chorus 2): call and response in E with the major-3rd twist
    head = [(0, 0.5, "B", 0, 0), (0.5, 0.5, "D", 1, 0), (1, 1.0, "E", 1, 0), (2.5, 0.5, "G", 1, 1), (3, 1, "E", 1, 0),
            (4, 0.5, "B", 0, 0), (4.5, 0.5, "D", 1, 0), (5, 0.5, "E", 1, 0), (5.5, 0.5, "G", 1, 0), (6, 2, "A", 1, 0.0)]
    for k, off in enumerate((16, 20, 24)):
        lead(s, off, head if k < 2 else [(0, 1, "B", 1, 1), (1, 0.5, "A", 1, 0), (1.5, 0.5, "G", 1, 0), (2, 1, "E", 1, 0), (3, 1, "D", 1, 0), (4, 3, "E", 1, 0.5)])
    lead(s, 28, [(0, 0.5, "E", 1, 0), (0.5, 0.5, "G", 1, 1), (1, 0.5, "A", 1, 0), (1.5, 0.5, "B", 1, 0), (2, 1.5, "D", 2, 1), (4, 2, "E", 2, 0.5)])
    end = 4 + 36
    s.add("rhythm", [(end * 4, 4, [midi("E2"), midi("B2"), midi("D3"), midi("G#3"), midi("B3")], 1.0, 3.0, 0.8)])
    s.add("drums", [(end * 4, "c", 1.0), (end * 4, "k", 1.0)])
    return s


def shed_sessions():
    prog = ["A7", "D7", "A7", "A7", "D7", "D7", "A7", "A7", "E7", "D7", "A7", "E7"]
    s = Song("shed_sessions", 88, 2 + 24 + 2, swing=0.58)
    for b in range(2):
        s.add("clean", [(b * 4 + i, 1, [midi("A2") + 7 * (i % 2), midi("A3") + (4 if i % 2 else 3)], 0.6, 1.4, 0.5) for i in range(4)])
    for rep in range(2):
        for i, sym in enumerate(prog):
            bar = 2 + rep * 12 + i
            r, iv = chord(sym, 3)
            s.add("clean", [(bar * 4 + k, 1, [r + iv[k % 3], r + iv[(k + 1) % 3]], 0.55, 1.6, 0.55) for k in range(4)])
            walk(s, bar, sym, 1); drums_shuffle(s, bar, crash=(i == 0 and rep == 1), soft=0.55)
            s.add("organ", [(bar * 4, 4, [r + k for k in iv[:3]], 0.28)])
    lead(s, 14, [(0, 1, "E", 0, 0), (1.5, 0.5, "G", 0, 0), (2, 1.5, "A", 0, 0.5), (4, 0.5, "C", 1, 0), (4.5, 0.5, "A", 0, 0), (5, 2, "E", 0, 0)], 4, 0.6)
    lead(s, 18, [(0, 1, "A", 0, 0), (1, 1, "G", 0, 0), (2, 1, "E", 0, 0), (3, 3, "D", 0, 1), (6, 2, "A", -1, 0)], 4, 0.6)
    s.add("clean", [(26 * 4, 6, [midi("A2"), midi("E3"), midi("G3"), midi("C#4"), midi("E4")], 0.6, 3.5, 0.6)])
    return s


def full_throttle():
    s = Song("full_throttle", 152, 4 + 8 + 8 + 8 + 8 + 8 + 1)
    riff = "xxXxxxX-"
    for b in range(4): power(s, b, "A5", riff); drums_rock(s, b, fill=(b == 3), ride8=b >= 2)
    def verse(b0):
        for i, sym in enumerate(["A5", "G5", "D5", "A5"] * 2):
            power(s, b0 + i, sym, "Xxxxxxxx" if i % 2 == 0 else "Xxx-Xx--"); walk(s, b0 + i, sym, 1, "8ths"); drums_rock(s, b0 + i, fill=(i == 7), crash=(i == 0))
    def chorus(b0, with_lead=True):
        for i, sym in enumerate(["D5", "E5", "A5", "F#5"] * 2):
            power(s, b0 + i, sym, "X---X-X-"); walk(s, b0 + i, sym, 1, "8ths"); drums_rock(s, b0 + i, crash=(i % 4 == 0), fill=(i == 7), ride=True)
            r, iv = chord(sym[:-1], 3); s.add("organ", [(b0 * 4 + i * 4, 4, [r + 12, r + 16 if sym[0] != "F" else r + 15, r + 19], 0.3)])
        if with_lead:
            hook = [(0, 1.5, "F#", 0, 0), (1.5, 0.5, "E", 0, 0), (2, 2, "A", 0, 0.0), (4, 1.5, "G#", 0, 0), (5.5, 0.5, "E", 0, 0), (6, 2, "B", 0, 1),
                    (8, 1, "C#", 1, 0), (9, 1, "B", 0, 0), (10, 2, "A", 0, 0), (12, 1, "C#", 1, 0), (13, 1, "E", 1, 0), (14, 2, "F#", 1, 1)]
            lead(s, b0, hook); lead(s, b0 + 4, hook[:9] + [(12, 4, "A", 0, 0.0)])
    verse(4); chorus(12); verse(20)
    # solo over the verse changes: A minor-pentatonic runs
    solo = [(0, 0.5, "A", 0, 0), (0.5, 0.5, "C", 1, 0), (1, 0.5, "D", 1, 0), (1.5, 0.5, "E", 1, 0), (2, 1.5, "G", 1, 1), (4, 0.5, "A", 1, 0),
            (4.5, 0.5, "G", 1, 0), (5, 0.5, "E", 1, 0), (5.5, 0.5, "D", 1, 0), (6, 2, "E", 1, 0.5), (8, 0.25, "A", 1, 0), (8.25, 0.25, "G", 1, 0),
            (8.5, 0.25, "E", 1, 0), (8.75, 0.25, "G", 1, 0), (9, 0.25, "A", 1, 0), (9.25, 0.25, "G", 1, 0), (9.5, 0.25, "E", 1, 0), (9.75, 0.25, "D", 1, 0),
            (10, 2, "E", 1, 1), (12, 1, "C#", 1, 0), (13, 1, "B", 0, 0), (14, 2, "A", 0, 0)]
    lead(s, 20, solo); lead(s, 24, solo)
    chorus(28); chorus(36, with_lead=False)
    lead(s, 36, [(0, 4, "A", 1, 0), (4, 4, "E", 1, 0), (8, 8, "A", 1, 0.5)])
    power(s, 44, "A5", "X-------"); s.add("drums", [(44 * 4, "c", 1.0), (44 * 4, "k", 1.0)])
    return s


def redline_shuffle():
    prog = blues12("E5"); s = Song("redline_shuffle", 168, 2 + 36 + 1, swing=0.5)
    for b in range(2): power(s, b, "E5", "x-x-x-x-"); drums_rock(s, b, fill=(b == 1))
    for rep in range(3):
        for i, sym in enumerate(prog):
            bar = 2 + rep * 12 + i
            boogie(s, bar, sym[0] + ("7" if True else "")); walk(s, bar, sym[0] + "7", 1)
            b = bar * 4; s.add("drums", [(b, "k", 1), (b + 2, "k", 0.9), (b + 1, "s", 0.9), (b + 3, "s", 0.9)] + [(b + k * 0.5, "s", 0.25) for k in range(8)])
            if i == 0: s.add("drums", [(b, "c", 0.8)])
    lick = [(0, 0.5, "G", 1, 0), (0.5, 0.5, "G#", 1, 0), (1, 0.5, "B", 1, 0), (1.5, 0.5, "B", 1, 0), (2, 0.5, "B", 1, 0), (2.5, 0.5, "G#", 1, 0), (3, 1, "E", 1, 0)]
    for k in range(6): lead(s, 14 + k * 2, lick if k % 2 == 0 else [(0, 0.5, "E", 2, 1), (0.5, 0.5, "D", 2, 0), (1, 0.5, "B", 1, 0), (1.5, 0.5, "A", 1, 0), (2, 2, "E", 1, 0.5)])
    for k in range(4): lead(s, 26 + k * 3, [(0, 0.25, "B", 1, 0), (0.25, 0.25, "D", 2, 0), (0.5, 0.25, "E", 2, 0), (0.75, 0.25, "D", 2, 0)] * 1 + [(1, 0.5, "B", 1, 1), (1.5, 0.5, "A", 1, 0), (2, 1, "G#", 1, 0)])
    power(s, 38, "E5", "X-------"); s.add("drums", [(38 * 4, "c", 1.0)])
    return s


def gravel_surf():
    s = Song("gravel_surf", 170, 4 + 16 + 16 + 8 + 1)
    prog = ["Em", "D", "C", "B7"]
    for b in range(4): drums_surf(s, b, crash=(b == 0)); walk(s, b, "E", 1, "8ths")
    def section(b0, mel=True, farf=False):
        for i in range(16):
            sym = prog[(i // 2) % 4]; bar = b0 + i
            r, iv = chord(sym, 3)
            s.add("clean", [(bar * 4 + k * 0.5, 0.5, [r + iv[0], r + iv[1]], 0.35, 0.4, 0.6) for k in (0, 3, 4, 6)])
            walk(s, bar, sym, 1, "8ths"); drums_surf(s, bar, crash=(i % 8 == 0))
            if farf: s.add("farfisa", [(bar * 4, 4, [r + 12, r + 12 + iv[1], r + 19], 0.35)])
        if mel:   # tremolo-picked melody (16ths), original; one note per bar
            line = ["E", "F#", "G", "B", "A", "G", "F#", "E", "D", "E", "F#", "A", "G", "F#", "E", "D#"]
            ev = []
            for i, n in enumerate(line):
                o = 4 + (1 if n in ("A", "B") and i in (3, 4, 11) else 0)
                for k in range(16):
                    ev.append((b0 * 4 + i * 4 + k * 0.25, 0.25, midi(n + str(o)), 0.55 + 0.1 * (k % 2), 0.35, 0.8))
            s.add("clean:trem", ev)     # own track so the mix can put it on top with spring reverb
    section(4, True); section(20, True, farf=True)
    for i in range(8):
        sym = prog[(i // 2) % 4]; bar = 36 + i
        r, iv = chord(sym, 4)
        s.add("farfisa", [(bar * 4 + k, 0.9, [r, r + iv[1], r + 7], 0.45) for k in range(4)])
        walk(s, bar, sym, 1, "8ths"); drums_surf(s, bar, crash=(i == 0))
    s.add("clean", [(44 * 4, 4, [midi("E3"), midi("B3"), midi("E4"), midi("G4")], 0.8, 3.0, 0.7)]); s.add("drums", [(44 * 4, "c", 1.0)])
    return s


def crownwell_motors():
    s = Song("crownwell_motors", 96, 2 + 16 + 8 + 1)
    prog = ["D5", "A#5", "C5", "A5"]
    for b in range(2): s.add("organ", [(b * 4, 4, [midi("D3"), midi("A3"), midi("F4")], 0.5)]); s.add("drums", [(b * 4 + 3, "t3", 0.8), (b * 4 + 3.5, "t3", 0.9)])
    for i in range(16):
        sym = prog[(i // 2) % 4]; bar = 2 + i
        power(s, bar, sym, "X--x-xX-", octave=2, dec=3.0)
        walk(s, bar, sym, 1, "root"); drums_rock(s, bar, crash=(i % 4 == 0), ride8=False)
        r, _ = chord(sym, 3); s.add("organ", [(bar * 4, 4, [r, r + 3 if sym[0] == "D" else r + 4, r + 7], 0.32)])
    mot = [(0, 1.5, "D", 0, 0), (1.5, 0.5, "F", 0, 0), (2, 1, "E", 0, 0), (3, 1, "C#", 0, 0), (4, 3, "D", 0, 1), (8, 1, "A", 0, 0), (9, 1, "A#", 0, 0),
           (10, 1, "A", 0, 0), (11, 1, "G", 0, 0), (12, 4, "A", 0, 0.5)]
    lead(s, 10, mot, 4, 0.75); lead(s, 14, mot[:6] + [(8, 8, "D", 1, 0.0)], 4, 0.75)
    for i in range(8):
        bar = 18 + i; sym = prog[(i // 2) % 4]
        power(s, bar, sym, "Xxxxxxxx", dec=2.0); walk(s, bar, sym, 1, "8ths"); drums_rock(s, bar, fill=(i == 7), crash=(i == 0))
    power(s, 26, "D5", "X-------", dec=4); s.add("drums", [(26 * 4, "c", 1.0)])
    return s


def long_road_home():
    s = Song("long_road_home", 80, 4 + 8 + 8 + 8 + 8 + 2)
    verse = ["D", "A", "Bm", "G"]; chor = ["D", "C", "G", "D"]
    for b in range(4):
        r, iv = chord(verse[b], 3)
        s.add("clean", [(b * 4 + k * 0.5, 0.5, r + iv[[0, 1, 2, 3, 2, 1, 0, 1][k]], 0.5, 1.8, 0.6) for k in range(8)])
    def part(b0, prog, big, ride=False):
        for i in range(8):
            sym = prog[i % 4]; bar = b0 + i
            r, iv = chord(sym, 3)
            s.add("clean", [(bar * 4 + k * 0.5, 0.5, r + iv[[0, 1, 2, 3, 2, 1, 0, 1][k]], 0.45, 1.8, 0.6) for k in range(8)])
            walk(s, bar, sym, 1, "root" if not big else "8ths")
            if big:
                power(s, bar, sym, "X---X-X-", dec=3.0, vel=0.8); drums_rock(s, bar, crash=(i % 4 == 0), fill=(i == 7), ride=ride)
                s.add("organ", [(bar * 4, 4, [r + k for k in iv[:3]], 0.3)])
            else:   # quiet verse: side-stick instead of a full snare
                s.add("drums", [(bar * 4, "k", 0.7), (bar * 4 + 2, "ss", 0.6)] + [(bar * 4 + k, "h", 0.35) for k in range(4)])
    part(4, verse, False); part(12, chor, True, ride=True); part(20, verse, True); part(28, chor, True, ride=True)
    tune = [(0, 2, "F#", 0, 0), (2, 1, "E", 0, 0), (3, 1, "D", 0, 0), (4, 3, "E", 0, 0.5), (8, 2, "F#", 0, 0), (10, 1, "A", 0, 0), (11, 1, "B", 0, 0),
            (12, 4, "A", 0, 0), (16, 2, "B", 0, 0), (18, 2, "A", 0, 0), (20, 4, "F#", 0, 0), (24, 2, "E", 0, 0), (26, 2, "D", 0, 0), (28, 4, "D", 0, 0.0)]
    lead(s, 12, tune, 4, 0.7); lead(s, 28, tune, 4, 0.8)
    s.add("clean", [(36 * 4, 6, [midi("D3"), midi("A3"), midi("D4"), midi("F#4"), midi("A4")], 0.7, 4.0, 0.7)])
    power(s, 36, "D5", "X-------", dec=4.5); s.add("drums", [(36 * 4, "c", 1.0), (36 * 4, "k", 1.0)])
    return s


def jingle(kind):
    if kind == "win":
        s = Song("jingle_win", 132, 3)
        # (a leftover loop here also struck D5 on beats 1 and 3, so D5 rang against the E5 hits; removed)
        power(s, 0, "D5", "X-X-----"); power(s, 0, "E5", "----X-X-")   # IV ... V
        power(s, 1, "A5", "X-------", dec=4)
        lead(s, 0, [(0, 0.5, "A", 0, 0), (0.5, 0.5, "C#", 1, 0), (1, 0.5, "E", 1, 0), (1.5, 0.5, "A", 1, 0), (2, 0.5, "G#", 1, 0), (2.5, 0.5, "E", 1, 0), (3, 1, "B", 1, 0), (4, 4, "A", 1, 0.0)])
        s.add("drums", [(0, "k", 1), (1, "s", 1), (2, "k", 1), (3, "s", 1), (3.5, "t1", 0.8), (3.75, "t2", 0.8), (4, "c", 1), (4, "k", 1)])
    elif kind == "podium":
        s = Song("jingle_podium", 132, 2)
        power(s, 0, "G5", "X---X-X-"); power(s, 1, "D5", "X-------", dec=3)
        s.add("drums", [(0, "k", 1), (2, "s", 1), (4, "c", 0.9)])
    else:
        s = Song("jingle_lose", 100, 2)
        lead(s, 0, [(0, 1, "E", 0, 0), (1, 1, "D#", 0, 0), (2, 1, "D", 0, 0), (3, 3, "C#", 0, -1.0)], 4, 0.7)
        s.add("drums", [(0, "k", 0.6), (3, "t3", 0.6)])
    return s


SONGS = {"tinplate_boogie": tinplate_boogie, "shed_sessions": shed_sessions, "full_throttle": full_throttle,
         "redline_shuffle": redline_shuffle, "gravel_surf": gravel_surf, "crownwell_motors": crownwell_motors,
         "long_road_home": long_road_home, "jingle_win": lambda: jingle("win"), "jingle_podium": lambda: jingle("podium"),
         "jingle_lose": lambda: jingle("lose")}


def write_ogg(path, mix, q=4):
    with tempfile.NamedTemporaryFile(suffix=".f32", delete=False) as f:
        f.write(np.ascontiguousarray(mix.T, dtype="<f4").tobytes()); raw = f.name
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", raw,
                    "-c:a", "libvorbis", "-q:a", str(q), path], check=True)
    os.unlink(raw)


# ======================================================================================================
# MIDI export + soundfont rendering (default path). The event lists above are the composition; the code
# below is the "performance": GM instruments, double tracking, strums, articulation, bends and vibrato,
# humanised timing/velocity. Each Song becomes a multi-track Standard MIDI File (480 ticks per beat at the
# song tempo; swing is already baked into Song.t()), FluidSynth renders it stem by stem, mixdsp mixes and
# masters the stems.
# ======================================================================================================
TPB = 480
PRE_ROLL = 0.05            # s of silence before beat 0 so early humanised hits aren't clamped (trimmed later)
GM_KEYS = {"k": 36, "s": 38, "ss": 37, "h": 42, "hp": 44, "o": 46, "c": 49, "c2": 57, "r": 51, "rb": 53,
           "t1": 50, "t2": 47, "t3": 43}
TOMS = {"t1", "t2", "t3"}
DRUM_LEN = {"k": .25, "s": .3, "ss": .2, "h": .12, "hp": .12, "o": .45, "c": 3.0, "c2": 3.0, "r": 1.2, "rb": 1.2,
            "t1": .6, "t2": .6, "t3": .7}
# MIDI track -> (channel, stem). Kick and toms share channel 10 with the kit but render as their own stems,
# so the mix can set the kick against snare/hats (GM kicks are boomy and would otherwise rule the low end).
LAYOUT = {"gtrL": (0, "gtr"), "gtrR": (1, "gtr"), "muteL": (2, "mute"), "muteR": (3, "mute"), "clean": (4, "clean"),
          "bass": (5, "bass"), "lead": (6, "lead"), "organ": (7, "organ"), "farfisa": (8, "farfisa"),
          "kick": (9, "kick"), "kit": (9, "kit"), "toms": (9, "toms"), "trem": (10, "trem")}
# GM programs, 0-based as sent in program_change (1-based GM number in the comment)
ORCH = dict(gtr=29,        # 30 Overdriven Guitar (GM's 30 is "Overdriven"; 31 is "Distortion")
            mute=28,       # 29 Electric Guitar (muted)
            clean=27,      # 28 Electric Guitar (clean)
            trem=27,       # 28 Electric Guitar (clean), surf tremolo line
            bass=34,       # 35 Electric Bass (pick)
            lead=29,       # 30 Overdriven Guitar
            organ=18,      # 19 Rock Organ
            farfisa=16,    # 17 Drawbar Organ
            kick=0, kit=0, toms=0)  # Standard kit on channel 10
# pan (CC10), reverb send (CC91), chorus send (CC93); sends only matter on the hi-fi path (SNES renders dry)
TRACK_CC = {"gtrL": (0, 26, 0), "gtrR": (127, 26, 0), "muteL": (0, 18, 0), "muteR": (127, 18, 0),
            "clean": (88, 52, 28), "trem": (56, 40, 0), "bass": (64, 0, 0), "lead": (70, 46, 0),
            "organ": (40, 40, 40), "farfisa": (86, 40, 24), "kick": (64, 12, 0), "kit": (64, 30, 0), "toms": (64, 30, 0)}

MENU = ("tinplate_boogie", "shed_sessions", "long_road_home")
SONG_CFG = {
    # profile: hifi (MuseScore_General, 44.1 kHz) or snes (FluidR3_GM, 32 kHz S-DSP chain)
    # orch: program overrides; mix: per-stem overrides for mixdsp.mix_stems (lu relative to the kit, hp Hz,
    # eq [(kind, Hz, Q, dB)], echo = S-DSP EON send, spring = spring-reverb send); _echo: EDL/EFB/EVOL.
    # trim_db: where the tail is cut. Jingles are cut at -48 dBFS because Audio.jingle() ducks the music for the
    # stream's whole length, so a long faint echo tail would hold the music down for nothing.
    "tinplate_boogie": dict(profile="hifi", mix=dict(organ=dict(lu=-5.0))),
    "shed_sessions": dict(profile="hifi", orch=dict(organ=16),
                          mix=dict(clean=dict(lu=2.5), bass=dict(lu=1.0), lead=dict(lu=3.0), organ=dict(lu=-4.0))),
    "long_road_home": dict(profile="hifi", orch=dict(organ=16), mix=dict(clean=dict(lu=-0.5), lead=dict(lu=1.5))),
    "full_throttle": dict(profile="snes", orch=dict(gtr=30, lead=30), mix=dict(_echo=dict(edl=12, efb=0.35, evol=0.28))),
    "redline_shuffle": dict(profile="snes", mix=dict(_echo=dict(edl=11, efb=0.35, evol=0.28))),
    "gravel_surf": dict(profile="snes", bass_art=0.55,
                        mix=dict(toms=dict(lu=-7.0, hp=110, eq=[("peak", 170, 1.0, -4.0)]),
                                 bass=dict(lu=-6.0, hp=45, eq=[("peak", 90, 1.0, -2.0), ("peak", 170, 1.0, -2.0)]),
                                 kick=dict(lu=-6.0),
                                 trem=dict(lu=1.5, spring=0.45, eq=[("peak", 2800, 0.9, 2.0)]),
                                 clean=dict(lu=-4.5), farfisa=dict(lu=-4.0),
                                 _echo=dict(edl=11, efb=0.40, evol=0.30))),
    "crownwell_motors": dict(profile="snes", orch=dict(gtr=30, lead=30), mix=dict(_echo=dict(edl=10, efb=0.42, evol=0.32))),
    "jingle_win": dict(profile="snes", tail=2.5, trim_db=-48.0, mix=dict(_echo=dict(edl=8, efb=0.30, evol=0.30))),
    "jingle_podium": dict(profile="snes", tail=2.5, trim_db=-48.0, mix=dict(_echo=dict(edl=8, efb=0.30, evol=0.30))),
    "jingle_lose": dict(profile="snes", tail=2.5, trim_db=-48.0, mix=dict(lead=dict(lu=2.0), toms=dict(lu=-2.0), _echo=dict(edl=9, efb=0.32, evol=0.30))),
}


class Performance:
    """Turns a Song's event lists into timed MIDI notes/controllers (seconds), then into a mido.MidiFile."""

    def __init__(self, song, profile, cfg=None):
        import zlib
        self.s, self.profile, self.cfg = song, profile, cfg or {}
        self.hmax = mixdsp.PROFILES[profile]["human_ms"] / 1000.0
        self.rng = np.random.default_rng(zlib.crc32(song.name.encode()))   # same song -> same performance
        self.notes = {k: [] for k in LAYOUT}       # [t_on, t_off, key, vel]
        self.ctl = {k: [] for k in LAYOUT}         # (t, 'cc', num, val) | (t, 'pb', semitones)
        self.orch = dict(ORCH, **self.cfg.get("orch", {}))
        self.build()

    # -- humanisers
    def jit(self, scale=1.0):
        """Timing offset in s: normal with sd = max/2.5 (scaled), clipped to +-max (8 ms hi-fi, 3 ms SNES)."""
        return float(np.clip(self.rng.normal(0, self.hmax / 2.5 * scale), -self.hmax, self.hmax))

    def vel(self, v, sd=4.0):
        return int(np.clip(round(v + self.rng.normal(0, sd)), 1, 127))

    def note(self, trk, t, dur, key, vel):
        self.notes[trk].append([t, t + max(dur, 0.012), int(key), vel])

    # -- instruments
    def guitar(self, ev, left, right):
        """Double-tracked rhythm: L and R are separate 'takes' (own timing), R ~10 ms late and a bit softer."""
        s = self.s
        for b, d, ms, v, dec, br in ev:
            notes = sorted(ms if isinstance(ms, (list, tuple)) else [ms])
            t0, t1 = s.t(b), s.t(b + d)
            if d >= 3: hold, strum = t1 - t0, 0.022           # final / long chords: slow strum, let ring
            elif dec >= 1.0: hold, strum = (t1 - t0) * 0.96, 0.007   # open power chords ring to the next hit
            else: hold, strum = (t1 - t0) * 0.82, 0.004       # chugs, boogie and palm mutes: detached
            base = 18 + 100 * v
            for side, trk in ((0, left), (1, right)):
                tt = t0 + self.jit() + (0.010 if side else 0.0)
                vb = base * (0.92 if side else 1.0)
                for k, m in enumerate(notes):
                    self.note(trk, tt + k * strum, hold - k * strum, m, self.vel(vb - 3 * k))

    def clean(self, ev, trk):
        s = self.s
        for b, d, ms, v, dec, br in ev:
            notes = sorted(ms if isinstance(ms, (list, tuple)) else [ms])
            t0, t1 = s.t(b), s.t(b + d)
            if d >= 3: hold, strum = t1 - t0, 0.03                             # final chord
            elif d <= 0.5 and dec >= 1.4: hold, strum = s.t(b + min(d * 2.5, 2.0)) - t0, 0.0   # arpeggio: let ring
            elif dec < 0.5: hold, strum = (t1 - t0) * (0.6 if d >= 0.5 else 0.9), 0.003  # stabs / tremolo picking
            else: hold, strum = (t1 - t0) * 0.92, 0.008                        # comping
            tt = t0 + self.jit()
            for k, m in enumerate(notes):
                self.note(trk, tt + k * strum, hold - k * strum, m, self.vel(25 + 95 * v - 2 * k))

    def bass(self, ev):
        s, art = self.s, self.cfg.get("bass_art", 0.8)
        for b, d, m, v, dec, br in ev:
            t0, t1 = s.t(b), s.t(b + d)
            self.note("bass", t0 + self.jit(0.7), (t1 - t0) * (art if d <= 0.5 else 0.93), m, self.vel(30 + 90 * v))

    def lead(self, ev):
        """Bends: pitch wheel ramps from the picked note up (or down) by `bend` semitones over ~100 ms, starting
        30 ms after the pick (range set to +-2 by RPN 0). Vibrato: CC1 fades in from 180 ms after the attack."""
        s, c = self.s, self.ctl["lead"]
        depth = 64 if self.profile == "hifi" else 72
        for b, d, m, bend, v in sorted(ev):
            t0 = s.t(b) + self.jit(0.6)
            dur = (s.t(b + d) - s.t(b)) * 0.97
            c.append((t0 - 0.002, "pb", 0.0)); c.append((t0 - 0.002, "cc", 1, 0))
            self.note("lead", t0, dur, m, self.vel(45 + 80 * v))
            if bend:
                for k in range(1, 7):
                    c.append((t0 + 0.03 + 0.1 * k / 6, "pb", bend * k / 6))
            if dur > 0.3:
                for k in range(6):
                    tk = t0 + 0.18 + 0.05 * k
                    if tk < t0 + dur: c.append((tk, "cc", 1, int(depth * (k + 1) / 6)))

    def organ(self, ev, trk):
        s = self.s
        for b, d, ms, v in ev:
            notes = ms if isinstance(ms, (list, tuple)) else [ms]
            t0, t1 = s.t(b), s.t(b + d)
            tt = t0 + self.jit(0.5)
            for m in notes:
                self.note(trk, tt, (t1 - t0) * 0.95, m, self.vel(60 + 60 * v, 2))

    def drums(self, ev):
        s = self.s
        for b, k, v in ev:
            if k not in GM_KEYS: continue
            t = s.t(b) + self.jit(0.6 if k in ("k", "s") else 1.0)
            self.note("toms" if k in TOMS else "kick" if k == "k" else "kit", t, DRUM_LEN[k], GM_KEYS[k], self.vel(8 + 119 * v, 3))

    def build(self):
        for name, ev in self.s.tracks.items():
            if name == "rhythm": self.guitar(ev, "gtrL", "gtrR")
            elif name == "rhythm:mute": self.guitar(ev, "muteL", "muteR")
            elif name == "clean": self.clean(ev, "clean")
            elif name == "clean:trem": self.clean(ev, "trem")
            elif name == "bass": self.bass(ev)
            elif name == "lead": self.lead(ev)
            elif name in ("organ", "farfisa"): self.organ(ev, name)
            elif name == "drums": self.drums(ev)
            else: raise ValueError("no MIDI mapping for track " + name)
        for trk, ns in self.notes.items():
            self.notes[trk] = self._fix_overlaps(ns)

    @staticmethod
    def _fix_overlaps(ns):
        """Same key on one channel: merge near-simultaneous hits (keep the louder), and end a note just before
        the next note-on of that key; otherwise the first note-off would cut the second note."""
        out, by_key = [], {}
        for n in sorted(ns):
            by_key.setdefault(n[2], []).append(n)
        for key, lst in by_key.items():
            keep = []
            for n in lst:
                if keep and n[0] - keep[-1][0] < 0.012:
                    keep[-1][3] = max(keep[-1][3], n[3]); keep[-1][1] = max(keep[-1][1], n[1]); continue
                if keep and keep[-1][1] > n[0] - 0.002:
                    keep[-1][1] = max(keep[-1][0] + 0.01, n[0] - 0.002)
                keep.append(n)
            out += keep
        return sorted(out)

    # -- MIDI
    def end_time(self):
        return max(n[1] for ns in self.notes.values() for n in ns) + self.cfg.get("tail", 4.0)

    def tick(self, t):
        return max(0, int(round((t + PRE_ROLL) / self.s.spb * TPB)))

    def _setup(self, trk):
        ch, stem = LAYOUT[trk]
        pan, rev, cho = TRACK_CC[trk]
        M = mido.Message
        msgs = [M("program_change", channel=ch, program=self.orch[stem]),
                M("control_change", channel=ch, control=7, value=100),     # channel volume (mix gain is in numpy)
                M("control_change", channel=ch, control=11, value=127),    # expression
                M("control_change", channel=ch, control=10, value=pan),    # pan
                M("control_change", channel=ch, control=91, value=rev),    # reverb send
                M("control_change", channel=ch, control=93, value=cho)]    # chorus send
        if trk == "lead":
            msgs += [M("control_change", channel=ch, control=101, value=0), M("control_change", channel=ch, control=100, value=0),
                     M("control_change", channel=ch, control=6, value=2), M("control_change", channel=ch, control=38, value=0),  # RPN 0: bend range +-2 st
                     # SF2.01 NRPN (MSB 120, LSB 24 = freqVibLFO): CC1 vibrato at ~5.5 Hz instead of the 8.2 Hz default.
                     # FluidSynth 2.3 scales this NRPN at 4 cents per step (measured): 1200*log2(5.5/8.176)/4 = -172.
                     M("control_change", channel=ch, control=99, value=120), M("control_change", channel=ch, control=98, value=24),
                     M("control_change", channel=ch, control=38, value=(8192 - 172) & 127),
                     M("control_change", channel=ch, control=6, value=(8192 - 172) >> 7)]
        if trk in ("gtrR", "muteR"):
            msgs.append(M("pitchwheel", channel=ch, pitch=205))         # second take ~5 cents sharp (+-2 st range)
        return msgs

    def midi_track(self, trk):
        ch = LAYOUT[trk][0]
        ev = [(0, 0, m) for m in self._setup(trk)]
        for t0, t1, key, vel in self.notes[trk]:
            ev.append((self.tick(t0), 3, mido.Message("note_on", channel=ch, note=key, velocity=vel)))
            ev.append((max(self.tick(t1), self.tick(t0) + 1), 1, mido.Message("note_off", channel=ch, note=key, velocity=0)))
        for c in self.ctl[trk]:
            if c[1] == "cc":
                ev.append((self.tick(c[0]), 2, mido.Message("control_change", channel=ch, control=c[2], value=c[3])))
            else:
                ev.append((self.tick(c[0]), 2, mido.Message("pitchwheel", channel=ch, pitch=int(np.clip(round(c[2] / 2 * 8191), -8192, 8191)))))
        ev.sort(key=lambda e: (e[0], e[1]))
        tr = mido.MidiTrack([mido.MetaMessage("track_name", name=trk, time=0)])
        last = 0
        for tk, _, m in ev:
            tr.append(m.copy(time=tk - last)); last = tk
        return tr

    def midi(self, tracks=None):
        """Type-1 SMF: a conductor track (tempo, 4/4, end marker after the tail) + one track per instrument."""
        mf = mido.MidiFile(type=1, ticks_per_beat=TPB)
        end = self.tick(self.end_time())
        mf.tracks.append(mido.MidiTrack([
            mido.MetaMessage("track_name", name=self.s.name, time=0),
            mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(self.s.bpm), time=0),
            mido.MetaMessage("time_signature", numerator=self.s.beats, denominator=4, time=0),
            mido.MetaMessage("marker", text="end", time=end)]))   # keeps the player running through the tail
        for trk in (tracks or LAYOUT):
            if self.notes[trk]:
                mf.tracks.append(self.midi_track(trk))
        return mf

    def stems(self):
        out = {}
        for trk, (ch, stem) in LAYOUT.items():
            if self.notes[trk]: out.setdefault(stem, []).append(trk)
        return out


def render_song(name, out_dir, work, profile=None, midi_dir=None, jobs=2):
    from concurrent.futures import ThreadPoolExecutor
    cfg = SONG_CFG[name]
    profile = profile or cfg["profile"]
    P = mixdsp.PROFILES[profile]
    s = SONGS[name]()
    perf = Performance(s, profile, cfg)
    os.makedirs(work, exist_ok=True)
    full = perf.midi()
    full.save(os.path.join(work, name + ".mid"))
    if midi_dir:
        os.makedirs(midi_dir, exist_ok=True); full.save(os.path.join(midi_dir, name + ".mid"))
    stems = perf.stems()

    def one(stem):
        mid = os.path.join(work, f"{name}__{stem}.mid"); wav = os.path.join(work, f"{name}__{stem}.wav")
        perf.midi(stems[stem]).save(mid)
        return stem, mixdsp.fluidsynth_render(mid, wav, P["sf2"], P["sr"], P["fx"])
    with ThreadPoolExecutor(max_workers=jobs) as ex:
        audio = dict(ex.map(one, stems))
    mix, rep = mixdsp.mix_stems(audio, P["sr"], profile, cfg.get("mix"))
    y, info = mixdsp.master(mix, P["sr"], profile, P["lufs"])
    y = mixdsp.trim_and_fade(y, P["sr"], tail_db=cfg.get("trim_db", -60.0), fade=0.25 if "trim_db" in cfg else 0.05)
    path = os.path.join(out_dir, name + ".ogg")
    mixdsp.write_ogg(path, y, P["sr"], P["q"])
    info.update(dur=y.shape[1] / P["sr"], peak=float(np.abs(y).max()), lufs=mixdsp.lufs(y, P["sr"]), stems=rep, profile=profile)
    return info


def main():
    import argparse
    ap = argparse.ArgumentParser(description="Render the Top Prix soundtrack.")
    ap.add_argument("items", nargs="*", help="song names (default: all); a non-song first argument is the output dir")
    ap.add_argument("--out", help="output dir (default godot/audio/music)")
    ap.add_argument("--synth", action="store_true", help="old home-made synth renderer (32 kHz, no soundfonts)")
    ap.add_argument("--profile", choices=["hifi", "snes"], help="force one rendering path for every song")
    ap.add_argument("--work", default=os.path.join(tempfile.gettempdir(), "top-prix-music"), help="scratch dir for stems")
    ap.add_argument("--midi", help="also save each song's multi-track .mid here")
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 2, help="parallel FluidSynth renders")
    a = ap.parse_args()
    names = [x for x in a.items if x in SONGS]
    extra = [x for x in a.items if x not in SONGS]
    out = a.out or (extra[0] if extra else os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../godot/audio/music"))
    names = names or list(SONGS)
    os.makedirs(out, exist_ok=True)
    for name in names:
        if a.synth:
            s = SONGS[name]()
            mix = s.render()
            write_ogg(os.path.join(out, name + ".ogg"), mix)
            print(f"{name:18s} {mix.shape[1] / SR:6.1f} s  peak {np.abs(mix).max():.2f}  rms {np.sqrt(np.mean(mix ** 2)):.3f}")
            continue
        i = render_song(name, out, a.work, a.profile, a.midi, a.jobs)
        gr = f"glue {i['glue_gr_mean']:.1f}/{i['glue_gr_max']:.1f} dB  " if "glue_gr_mean" in i else ""
        print(f"{name:18s} {i['profile']:4s} {i['dur']:6.1f} s  peak {20 * np.log10(i['peak']):5.1f} dBFS  "
              f"{i['lufs']:5.1f} LUFS  {gr}limiter max {i['limit_gr_max']:.1f} dB")
        print("    stems: " + ", ".join(f"{k} {v['gain_db']:+.0f} dB" for k, v in i["stems"].items()))


if __name__ == "__main__":
    main()
