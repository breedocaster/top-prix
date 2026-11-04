#!/usr/bin/env python3
"""Measure the rendered soundtrack without listening: decode each .ogg and print duration, sample peak, true
peak and integrated loudness (ffmpeg's EBU R128 meter), RMS, clipped samples, how each file starts and ends,
spectral balance per octave band, and write spectrogram PNGs.

Usage: python3 tools/audio/music_check.py [music_dir] [--spec DIR]
"""
import argparse, glob, os, re, subprocess
import numpy as np

BANDS = [(20, 60), (60, 250), (250, 1000), (1000, 4000), (4000, 8000), (8000, 16000), (16000, 22050)]


def decode(path):
    """ffmpeg -> float32 stereo at the file's own rate. Returns (x (2, n), sr)."""
    sr = int(subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=sample_rate",
                             "-of", "csv=p=0", path], capture_output=True, text=True, check=True).stdout.strip())
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, "<f4").reshape(-1, 2).T.astype(np.float64), sr


def ebur128(path):
    """ffmpeg's R128 meter: -af ebur128=peak=true prints integrated loudness (I), loudness range (LRA) and
    true peak (4x oversampled) in its summary."""
    err = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    summ = err[err.rfind("Summary:"):]
    I = float(re.search(r"I:\s+(-?[\d.]+) LUFS", summ).group(1))
    lra = float(re.search(r"LRA:\s+(-?[\d.]+) LU", summ).group(1))
    tp = float(re.search(r"True peak:\s+Peak:\s+(-?[\d.inf]+) dBFS", summ).group(1))
    return I, lra, tp


def bands(x, sr):
    m = x.mean(0)
    seg = 8192
    n = len(m) // seg * seg
    S = (np.abs(np.fft.rfft(m[:n].reshape(-1, seg) * np.hanning(seg), axis=1)) ** 2).mean(0)
    f = np.fft.rfftfreq(seg, 1 / sr)
    tot = S.sum()
    out = []
    for lo, hi in BANDS:
        e = S[(f >= lo) & (f < hi)].sum()
        out.append(10 * np.log10(e / tot + 1e-12) if e > 0 else -99)
    mag = np.sqrt(S)
    c = (mag * f).sum() / mag.sum()                 # centroid of the magnitude spectrum
    cum = np.cumsum(S) / tot
    roll = f[np.searchsorted(cum, 0.95)]
    # long-term average spectrum slope (power per Hz) 100 Hz - 4 kHz, in 1/6-octave bins, dB per octave.
    # Reference: Pestana et al. 2013 found ~5 dB/octave decay over 100-4000 Hz in commercial recordings.
    edges = 100 * 2 ** (np.arange(0, 5.33 * 6 + 1) / 6)
    lv = [10 * np.log10(S[(f >= a) & (f < b)].mean()) for a, b in zip(edges[:-1], edges[1:])]
    slope = np.polyfit(np.log2(np.sqrt(edges[:-1] * edges[1:])), lv, 1)[0]
    return out, c, roll, slope


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser()
    ap.add_argument("dir", nargs="?", default=os.path.join(here, "../../godot/audio/music"))
    ap.add_argument("--spec", default="/tmp/music_spec", help="where spectrogram PNGs go")
    a = ap.parse_args()
    os.makedirs(a.spec, exist_ok=True)
    files = sorted(glob.glob(os.path.join(a.dir, "*.ogg")))
    tot = 0
    print(f"{'file':18s} {'rate':>5s} {'dur s':>6s} {'peak':>6s} {'TP':>6s} {'LUFS':>6s} {'LRA':>5s} {'RMS':>6s} "
          f"{'clip':>4s} {'head ms':>7s} {'end':>8s} {'mono':>5s} {'kB':>5s}")
    rows = []
    for p in files:
        name = os.path.basename(p)[:-4]
        x, sr = decode(p)
        I, lra, tp = ebur128(p)
        pk = 20 * np.log10(np.abs(x).max())
        rms = 10 * np.log10(np.mean(x ** 2))
        clip = int((np.abs(x) >= 0.9999).sum())
        env = np.abs(x).max(0)
        head = np.argmax(env > 10 ** (-50 / 20)) / sr * 1000          # time to first sound above -50 dBFS
        tail = 20 * np.log10(np.sqrt(np.mean(x[:, -int(0.05 * sr):] ** 2)) + 1e-12)   # last 50 ms RMS
        kb = os.path.getsize(p) / 1024; tot += kb
        # mono fold-down loss (phone speakers): loudness of (L+R)/2 on both channels vs the stereo file
        mono = float(np.mean(x ** 2)) and 10 * np.log10(np.mean(((x[0] + x[1]) / 2) ** 2) / np.mean(x ** 2))
        print(f"{name:18s} {sr // 1000:>4d}k {x.shape[1] / sr:6.1f} {pk:6.1f} {tp:6.1f} {I:6.1f} {lra:5.1f} {rms:6.1f} "
              f"{clip:4d} {head:7.0f} {tail:6.0f}dB {mono:5.1f} {kb:5.0f}")
        rows.append((name, sr, x))
        # spectrogram: log frequency axis so melodic contours are readable, 100 dB range
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", p, "-lavfi",
                        "showspectrumpic=s=1600x600:mode=combined:fscale=log:scale=log:drange=100:legend=1",
                        os.path.join(a.spec, name + ".png")], check=True)
    print(f"total {tot / 1024:.2f} MB")
    print("\nspectral balance: share of energy per band (dB re total), magnitude centroid, 95% energy roll-off,")
    print("LTAS slope 100 Hz-4 kHz (Pestana et al. 2013: commercial recordings ~ -5 dB/oct)")
    print(f"{'file':18s} " + " ".join(f"{f'{lo}-{hi}':>10s}" for lo, hi in BANDS) + f" {'centroid':>9s} {'rolloff':>8s} {'slope':>9s}")
    for name, sr, x in rows:
        b, c, r, sl = bands(x, sr)
        print(f"{name:18s} " + " ".join(f"{v:10.1f}" for v in b) + f" {c:8.0f}Hz {r:7.0f}Hz {sl:5.1f}dB/oct")


if __name__ == "__main__":
    main()
