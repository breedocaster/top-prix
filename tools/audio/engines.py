#!/usr/bin/env python3
"""Engine sound loops for Top Prix, synthesized from how each engine actually fires.

Model (per loop):
  1. Firing events: every cylinder fires once per cycle (720 deg crank for 4-strokes, 360 deg for
     2-strokes) at its crank angle from the firing order. Cycle-to-cycle jitter in timing and strength.
     The rhythm is the character: a 45-deg V-twin's 315/405 "potato", a 270-deg twin's lope,
     a cross-plane V8's uneven per-bank pulses (the burble), an I4's even 180-deg scream.
  2. Each pulse is a short pressure transient pushed through an exhaust impulse response:
     header/pipe resonances (damped modes) + a muffler low-pass. Exhaust variants change the pipe
     and muffler: stock (quiet, dull), sport (brighter), straight (open, raspy, crackly), race (tuned, loud).
  3. Induction roar (band-passed noise gated by the firing pattern) on throttle, valvetrain ticks,
     and on overrun: weak pulses plus exhaust pops/crackle (more with open exhausts).
  4. Everything is built circularly (FFT convolution, wrapped pulses) so loops are seamless.
Output: 22.05 kHz mono 16-bit WAV with a 'smpl' loop chunk; Godot imports them as looping QOA.

Usage: python3 tools/audio/engines.py [out_dir]     (default godot/audio/engine)
"""
import os, sys, struct, json
import numpy as np

SR = 22050
RNG = np.random.default_rng(1977)

# name: cylinders' firing crank angles (deg within one cycle), cycle (720 4-stroke / 360 2-stroke),
#       idle/red rpm, pulse decay (ms), pipe fundamental (Hz), banks (bank index per firing),
#       brightness, level, extra
VOICES = {
    "single4": dict(fire=[0], cyc=720, idle=1350, red=10500, decay=2.6, pipe=95, bright=0.55, thump=1.4),
    "single2": dict(fire=[0], cyc=360, idle=1900, red=11500, decay=1.1, pipe=420, bright=1.3, chamber=True, skip=0.25),
    "twin270": dict(fire=[0, 270], cyc=720, idle=1250, red=10500, decay=2.0, pipe=120, bright=0.75),
    "vtwin45": dict(fire=[0, 315], cyc=720, idle=950, red=7000, decay=3.0, pipe=85, bright=0.5, thump=1.3),
    "triple": dict(fire=[0, 240, 480], cyc=720, idle=1150, red=12000, decay=1.6, pipe=150, bright=0.95),
    "i4bike": dict(fire=[0, 180, 360, 540], cyc=720, idle=1350, red=15000, decay=1.0, pipe=210, bright=1.25),
    "i3car": dict(fire=[0, 240, 480], cyc=720, idle=800, red=7200, decay=1.8, pipe=105, bright=0.7),
    "i4car": dict(fire=[0, 180, 360, 540], cyc=720, idle=850, red=7500, decay=1.6, pipe=115, bright=0.8),
    "v6": dict(fire=[0, 120, 240, 360, 480, 600], cyc=720, idle=750, red=7200, decay=1.7, pipe=100, bright=0.8),
    # cross-plane V8, firing order 1-8-4-3-6-5-7-2, GM numbering (odd = left bank)
    "v8": dict(fire=[0, 90, 180, 270, 360, 450, 540, 630], banks=[0, 1, 1, 0, 1, 0, 0, 1], cyc=720,
               idle=700, red=7000, decay=2.2, pipe=78, bright=0.65, thump=1.25),
    "v10": dict(fire=[i * 72 for i in range(10)], cyc=720, idle=1100, red=16500, decay=0.8, pipe=260, bright=1.4),
    "electric": dict(electric=True, idle=0, red=14000),
}
EXHAUSTS = {
    #           muffler LP Hz, pipe mode gain, raspy noise, level dB, overrun pop rate /s
    "stock":    dict(lp=850, modes=0.55, rasp=0.02, db=-3.0, pops=0.0),
    "sport":    dict(lp=1900, modes=0.8, rasp=0.05, db=0.0, pops=1.5),
    "straight": dict(lp=5200, modes=0.6, rasp=0.16, db=2.5, pops=6.0),
    "race":     dict(lp=3600, modes=1.15, rasp=0.08, db=2.0, pops=4.0),
}
# RPM layers as a fraction of idle..red; load: 1 = on throttle, 0 = overrun
LAYERS = [("idle", 0.0, 0.25), ("r1", 0.30, 1.0), ("r2", 0.55, 1.0), ("r3", 0.78, 1.0), ("r4", 1.0, 1.0),
          ("o2", 0.45, 0.0), ("o4", 0.85, 0.0)]


def lowpass_mask(n, cutoff, order=2.0):
    f = np.fft.rfftfreq(n, 1.0 / SR)
    return 1.0 / np.sqrt(1.0 + (f / cutoff) ** (2 * order))


def bandpass_mask(n, lo, hi):
    f = np.fft.rfftfreq(n, 1.0 / SR)
    return (1.0 / np.sqrt(1.0 + (lo / np.maximum(f, 1.0)) ** 4)) * (1.0 / np.sqrt(1.0 + (f / hi) ** 4))


def cconv(x, h):
    """Circular convolution (keeps the loop seamless)."""
    n = len(x)
    H = np.fft.rfft(h, n)
    return np.fft.irfft(np.fft.rfft(x) * H, n)


def exhaust_ir(v, ex, n, bank_shift=1.0):
    """Header + pipe resonances (damped modes) as an impulse response of length <= n."""
    L = min(n, int(0.12 * SR))
    t = np.arange(L) / SR
    f0 = v["pipe"] * bank_shift
    h = np.zeros(L)
    h[0] = 1.0
    for k in range(1, 7):
        fk = f0 * k * (1 + 0.013 * k * k)            # slightly inharmonic pipe modes
        tau = 0.018 / k ** 0.7
        h += ex["modes"] * (0.9 / k ** 0.8) * np.exp(-t / tau) * np.sin(2 * np.pi * fk * t)
    if v.get("chamber"):                               # 2-stroke expansion chamber: nasal resonance
        for fk, g in ((620, 1.2), (1240, 0.6), (1900, 0.3)):
            h += g * np.exp(-t / 0.03) * np.sin(2 * np.pi * fk * t)
    return h


def pulse_shape(v, ex):
    n = int(0.012 * SR)
    t = np.arange(n) / SR
    dec = v["decay"] / 1000.0
    p = (1 - np.exp(-t / 0.00018)) * np.exp(-t / dec)
    p += 0.35 * v.get("thump", 1.0) * np.exp(-t / (dec * 3)) * np.sin(2 * np.pi * 55 * t)   # body thump
    return p / np.abs(p).max()


def render(vname, ex_name, rpm_frac, load, secs=0.9):
    v, ex = VOICES[vname], EXHAUSTS[ex_name]
    rpm = v["idle"] + (v["red"] - v["idle"]) * rpm_frac
    if v.get("electric"):
        return render_electric(v, max(rpm, 300.0), load, secs)
    cyc_per_s = rpm / 60.0 / (v["cyc"] / 360.0)
    ncyc = max(3, int(round(secs * cyc_per_s)))
    n = int(round(ncyc * SR / cyc_per_s))
    T = n / ncyc                              # samples per cycle (float)
    banks = v.get("banks", [0] * len(v["fire"]))
    nb = max(banks) + 1
    exc = [np.zeros(n) for _ in range(nb)]
    ps = pulse_shape(v, ex)
    idle = rpm_frac < 0.05
    amp_load = (0.35 + 0.65 * load) if load > 0 else 0.22
    for c in range(ncyc):
        for i, ang in enumerate(v["fire"]):
            if idle and v.get("skip") and RNG.random() < v["skip"]:
                continue                       # 2-stroke idle four-stroking
            t0 = (c + ang / v["cyc"]) * T + RNG.normal(0, 0.004 * T)
            a = amp_load * (1 + RNG.normal(0, 0.09 if not idle else 0.16))
            if load == 0 and RNG.random() < 0.25: a *= 0.3   # misfire-ish on overrun
            i0 = int(np.floor(t0)); fr = t0 - i0
            idx = (i0 + np.arange(len(ps))) % n
            e = exc[banks[i]]
            e[idx] += a * (1 - fr) * ps
            e[(idx + 1) % n] += a * fr * ps
    y = np.zeros(n)
    for b in range(nb):
        y += cconv(exc[b], exhaust_ir(v, ex, n, bank_shift=1.0 + 0.11 * b))
    # raspy broadband component riding on each pulse (open pipes)
    env = cconv(sum(exc), np.exp(-np.arange(int(0.004 * SR)) / (0.0012 * SR)))
    rasp = RNG.normal(0, 1, n) * np.abs(env)
    y += ex["rasp"] * 3.0 * rasp * v["bright"]
    # muffler + engine brightness
    Y = np.fft.rfft(y)
    lp = ex["lp"] * (0.75 + 0.5 * v["bright"]) * (0.7 + 0.5 * rpm_frac) * (0.75 if load == 0 else 1.0)
    Y *= lowpass_mask(n, lp, 2.0)
    Y *= 1.0 / np.sqrt(1.0 + (28.0 / np.maximum(np.fft.rfftfreq(n, 1.0 / SR), 1.0)) ** 4)  # DC / rumble HP
    y = np.fft.irfft(Y, n)
    # induction roar on throttle, gated by the firing pattern
    if load > 0:
        noise = np.fft.irfft(np.fft.rfft(RNG.normal(0, 1, n)) * bandpass_mask(n, 350, 2600), n)
        gate = cconv(sum(exc), np.exp(-np.arange(int(0.01 * SR)) / (0.004 * SR)))
        y += 0.10 * load * (0.4 + rpm_frac) * noise * np.abs(gate) / (np.abs(gate).max() + 1e-9)
    # valvetrain tick at cam frequency
    if v["cyc"] == 720:
        ticks = np.zeros(n)
        for c in range(ncyc):
            for i in range(len(v["fire"])):
                ticks[int((c + (v["fire"][i] + 400) / 720.0) * T) % n] += 1
        click = np.fft.irfft(np.fft.rfft(ticks) * bandpass_mask(n, 3500, 8000), n)
        y += 0.03 * click / (np.abs(click).max() + 1e-9) * (1.2 - rpm_frac)
    # overrun pops / crackle
    if load == 0 and ex["pops"] > 0:
        npop = RNG.poisson(ex["pops"] * n / SR * (0.6 + rpm_frac))
        for _ in range(npop):
            at = RNG.integers(0, n)
            ln = int(SR * RNG.uniform(0.004, 0.02))
            burst = RNG.normal(0, 1, ln) * np.exp(-np.arange(ln) / (ln * 0.25)) * RNG.uniform(0.8, 2.2)
            idx = (at + np.arange(ln)) % n
            y[idx] += burst * 0.6
    # level: normalise RMS, louder with load and rpm, then exhaust level; soft clip
    y /= np.sqrt(np.mean(y ** 2)) + 1e-9
    y *= 0.16 * (0.55 + 0.45 * rpm_frac) * (1.0 if load > 0 else 0.6) * 10 ** (ex["db"] / 20.0)
    y = np.tanh(y * 1.4) / 1.4
    return y, rpm


def render_electric(v, rpm, load, secs):
    n = int(secs * SR)
    f = rpm / 60.0 * 3.0                  # 3 pole pairs
    ncy = max(1, int(round(secs * f)))
    n = int(round(ncy * SR / f))
    t = np.arange(n) / SR
    y = 0.5 * np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t) + 0.12 * np.sin(2 * np.pi * 6 * f * t)
    whine = np.sin(2 * np.pi * min(8000.0, 1800 + f * 4) * t) * (0.06 + 0.1 * load)
    hum = np.fft.irfft(np.fft.rfft(RNG.normal(0, 1, n)) * bandpass_mask(n, 200, 1200), n) * 0.05
    y = (y * (0.4 + 0.6 * load) + whine + hum)
    y /= np.sqrt(np.mean(y ** 2)) + 1e-9
    return y * 0.09 * (0.4 + 0.6 * load), rpm


def write_wav(path, y):
    pcm = np.clip(np.round(y * 32767), -32768, 32767).astype("<i2").tobytes()
    n = len(y)
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    # smpl chunk: one forward loop over the whole buffer (Godot "Detect From WAV")
    smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0) + struct.pack("<6I", 0, 0, 0, n - 1, 0, 0)
    data = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"data" + struct.pack("<I", len(pcm)) + pcm \
        + b"smpl" + struct.pack("<I", len(smpl)) + smpl
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", len(data)) + data)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "../../godot/audio/engine")
    os.makedirs(out, exist_ok=True)
    meta = {"sr": SR, "voices": {}, "layers": [[k, f, l] for k, f, l in LAYERS], "exhausts": list(EXHAUSTS)}
    total = 0
    for vname, v in VOICES.items():
        exs = ["stock"] if v.get("electric") else list(EXHAUSTS)
        meta["voices"][vname] = {"idle": v["idle"], "red": v["red"], "exhausts": exs, "rpm": {}}
        for ex in exs:
            for key, frac, load in LAYERS:
                y, rpm = render(vname, ex, frac, load)
                write_wav(os.path.join(out, f"{vname}_{ex}_{key}.wav"), y)
                meta["voices"][vname]["rpm"][key] = round(rpm, 1)
                total += len(y)
    with open(os.path.join(out, "engines.json"), "w") as f:
        json.dump(meta, f, indent=1)
    print(f"{sum(len(m['exhausts']) for m in meta['voices'].values()) * len(LAYERS)} loops, {total / SR:.0f} s audio -> {out}")


if __name__ == "__main__":
    main()
