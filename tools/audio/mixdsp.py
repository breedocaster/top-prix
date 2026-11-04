#!/usr/bin/env python3
"""Rendering, mixing and mastering for the Top Prix soundtrack (used by music.py).

Two output paths share one stem mixer:
  hifi : MuseScore_General soundfont at 44.1 kHz with FluidSynth reverb/chorus, then a numpy master
         (low cut, presence, glue compression, true-peak-ish limiter, loudness target).
  snes : FluidR3_GM rendered dry at 32 kHz, then an S-DSP-style chain per stem (BRR-like grit, Gaussian
         interpolation kernel), the S-DSP echo (FIR-filtered feedback delay), narrower stereo and the same
         loudness/limiter stage.

Sources for the S-DSP numbers (see tools/audio/README.md for links):
  - 32 kHz output, echo buffer = EDL * 512 stereo samples (16 ms steps, 240 ms max), EFB/EVOL as signed /128,
    8-tap FIR (signed /128 after the >>6 on 15-bit data) applied to what is read from the echo buffer; the
    FIR output goes to the speakers (* EVOL) and back into the buffer (* EFB): anomie/jwdonal "apudsp" doc,
    sneslab.net "FIR Filter".
  - Gaussian interpolation: 4 taps from a 512-entry table; at a 1:1 pitch ratio (d = 0) the taps are
    g[255], g[511], g[256], g[0] = 0x172, 0x519, 0x176, 0x000 (out of 2048).
  - BRR: 16-sample blocks of signed 4-bit nibbles (-8..7) with a per-block shift and one of four predictors
    (filter 1 = 15/16 * previous sample): snes.nesdev.org "BRR samples".
"""
import os, subprocess, tempfile, warnings
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt, lfilter, resample_poly, fftconvolve

SF2_DIR = "/usr/share/sounds/sf2"
PROFILES = {
    # soundfont, render rate, FluidSynth effects, timing humanize (ms, max), ogg quality, loudness target
    "hifi": dict(sf2=os.path.join(SF2_DIR, "MuseScore_General_Full.sf2"), sr=44100, fx=True, human_ms=8.0, q=5, lufs=-14.0),
    "snes": dict(sf2=os.path.join(SF2_DIR, "FluidR3_GM.sf2"), sr=32000, fx=False, human_ms=3.0, q=4, lufs=-14.0),
}
CEILING_DB = -1.0          # delivered true-peak ceiling (dBTP)
ENCODER_MARGIN_DB = 0.7    # Vorbis overshoots the pre-encode peak by up to ~0.6 dB (measured), so limit 0.7 dB lower
MAX_LIMIT_GR_DB = 4.5      # if hitting the loudness target needs more limiting than this, settle for quieter


# ---------------------------------------------------------------- FluidSynth
def fluidsynth_render(mid_path, wav_path, sf2, sr, fx):
    """Render one MIDI file to a 32-bit float stereo WAV. Every flag is explained inline."""
    cmd = [
        "fluidsynth",
        "-n",                    # --no-midi-in: don't open a MIDI input driver (offline render)
        "-i",                    # --no-shell: don't start the interactive command shell on stdin
        "-q",                    # --quiet: no version banner
        "-r", str(sr),           # --sample-rate: synth + output rate (44100 hi-fi, 32000 = S-DSP rate)
        "-g", "0.5",             # --gain: master gain (default 0.2); output is float so this can't clip
        "-R", "1" if fx else "0",  # --reverb: FluidSynth's reverb (CC91 sends) on for hi-fi, off for SNES
        "-C", "1" if fx else "0",  # --chorus: FluidSynth's chorus (CC93 sends) on for hi-fi, off for SNES
        "-O", "float",           # --audio-file-format: 32-bit float samples (headroom; we master in numpy)
        "-T", "wav",             # --audio-file-type: RIFF WAV
        "-o", "synth.polyphony=512",              # voice limit; ring-outs + double tracking need headroom
        "-o", "synth.dynamic-sample-loading=1",   # load only the samples of presets actually used
        "-o", "synth.reverb.room-size=0.62",      # reverb: medium-large room
        "-o", "synth.reverb.damp=0.45",           # reverb: high-frequency damping (darker tail)
        "-o", "synth.reverb.width=0.9",           # reverb: stereo spread of the tail
        "-o", "synth.reverb.level=0.75",          # reverb: return level
        "-o", "synth.chorus.nr=3",                # chorus: number of delay lines
        "-o", "synth.chorus.level=1.2",           # chorus: return level
        "-o", "synth.chorus.speed=0.35",          # chorus: LFO rate in Hz (slow, Leslie-ish shimmer)
        "-o", "synth.chorus.depth=5",             # chorus: modulation depth in ms
        "-F", wav_path,          # --fast-render: write the MIDI file's audio to this file, faster than real time
        sf2, mid_path,           # soundfont, then the MIDI file to play
    ]
    subprocess.run(cmd, check=True)
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")      # FluidSynth's WAV carries a LIST chunk scipy doesn't parse
        rate, x = wavfile.read(wav_path)
    assert rate == sr, (rate, sr)
    return np.ascontiguousarray(x.T.astype(np.float64))


# ---------------------------------------------------------------- filters
def biquad(kind, f, sr, q=0.7071, gain_db=0.0):
    """RBJ audio-EQ-cookbook biquad -> (b, a)."""
    A = 10 ** (gain_db / 40); w = 2 * np.pi * f / sr; cw, sw = np.cos(w), np.sin(w); al = sw / (2 * q)
    if kind == "peak":
        b = [1 + al * A, -2 * cw, 1 - al * A]; a = [1 + al / A, -2 * cw, 1 - al / A]
    elif kind == "highshelf":
        sA = 2 * np.sqrt(A) * al
        b = [A * ((A + 1) + (A - 1) * cw + sA), -2 * A * ((A - 1) + (A + 1) * cw), A * ((A + 1) + (A - 1) * cw - sA)]
        a = [(A + 1) - (A - 1) * cw + sA, 2 * ((A - 1) - (A + 1) * cw), (A + 1) - (A - 1) * cw - sA]
    elif kind == "lowshelf":
        sA = 2 * np.sqrt(A) * al
        b = [A * ((A + 1) - (A - 1) * cw + sA), 2 * A * ((A - 1) - (A + 1) * cw), A * ((A + 1) - (A - 1) * cw - sA)]
        a = [(A + 1) + (A - 1) * cw + sA, -2 * ((A - 1) + (A + 1) * cw), (A + 1) + (A - 1) * cw - sA]
    elif kind == "highpass":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]; a = [1 + al, -2 * cw, 1 - al]
    elif kind == "lowpass":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]; a = [1 + al, -2 * cw, 1 - al]
    else:
        raise ValueError(kind)
    return np.array(b) / a[0], np.array(a) / a[0]


def eq(x, kind, f, sr, q=0.7071, gain_db=0.0):
    b, a = biquad(kind, f, sr, q, gain_db)
    return lfilter(b, a, x, axis=-1)


def hpf(x, f, sr, order=2):
    return sosfilt(butter(order, f, "highpass", fs=sr, output="sos"), x, axis=-1)


# ---------------------------------------------------------------- loudness (ITU-R BS.1770-4)
def k_weight(x, sr):
    # BS.1770 K-weighting re-derived for any sample rate (B. De Man's formulation, which reproduces the
    # standard's 48 kHz coefficients): stage 1 high shelf (+4 dB), stage 2 RLB high-pass (~38 Hz).
    K = np.tan(np.pi * 1681.9744509555319 / sr); Q = 0.7071752369554193
    Vh = 10 ** (3.99984385397 / 20); Vb = Vh ** 0.499666774155; d = 1 + K / Q + K * K
    b = [(Vh + Vb * K / Q + K * K) / d, 2 * (K * K - Vh) / d, (Vh - Vb * K / Q + K * K) / d]
    a = [1.0, 2 * (K * K - 1) / d, (1 - K / Q + K * K) / d]
    x = lfilter(b, a, x, axis=-1)
    K = np.tan(np.pi * 38.13547087613982 / sr); Q = 0.5003270373253953; d = 1 + K / Q + K * K
    return lfilter([1.0, -2.0, 1.0], [1.0, 2 * (K * K - 1) / d, (1 - K / Q + K * K) / d], x, axis=-1)


def lufs(x, sr):
    """Integrated loudness (gated, 400 ms blocks, 75 % overlap). x: (2, n) or (n,)."""
    x = np.atleast_2d(x)
    y = k_weight(x, sr) ** 2
    blk, hop = int(0.4 * sr), int(0.1 * sr)
    if y.shape[1] < blk:
        y = np.pad(y, ((0, 0), (0, blk - y.shape[1])))
    c = np.cumsum(np.pad(y, ((0, 0), (1, 0))), axis=1)
    starts = np.arange(0, y.shape[1] - blk + 1, hop)
    z = ((c[:, starts + blk] - c[:, starts]) / blk).sum(0)
    l = -0.691 + 10 * np.log10(z + 1e-20)
    z = z[l > -70]
    if len(z) == 0:
        return -70.0
    rel = -0.691 + 10 * np.log10(z.mean()) - 10
    z = z[-0.691 + 10 * np.log10(z) > rel]
    return float(-0.691 + 10 * np.log10(z.mean()))


def true_peak(x, os_=4):
    return float(np.abs(resample_poly(x, os_, 1, axis=-1)).max())


# ---------------------------------------------------------------- dynamics
def _block_env(x, hop):
    n = x.shape[-1] // hop * hop
    return x[..., :n].reshape(*x.shape[:-1], -1, hop)


def _to_samples(g, hop, n):
    """Block gains -> per-sample gains by linear interpolation between block centres."""
    centres = np.arange(len(g)) * hop + hop / 2
    return np.interp(np.arange(n), centres, g)


def glue_compress(x, sr, thresh_db, ratio=2.0, attack=0.025, release=0.25, knee=6.0):
    """Stereo-linked RMS compressor (2 ms detector blocks, or 0.5 ms for fast attacks). Used gently as the
    master 'glue' and fast as a drum-bus compressor. Returns (y, mean gain reduction dB, max GR dB)."""
    hop = max(1, int(sr * (0.0005 if attack < 0.005 else 0.002)))
    e = _block_env((x ** 2).mean(0), hop).mean(-1)
    lvl = 10 * np.log10(e + 1e-12)
    over = lvl - thresh_db
    gr = np.where(over <= -knee / 2, 0.0,
                  np.where(over >= knee / 2, over * (1 - 1 / ratio), (1 - 1 / ratio) * (over + knee / 2) ** 2 / (2 * knee)))
    a = np.exp(-hop / (attack * sr)); r = np.exp(-hop / (release * sr))
    sm = np.empty_like(gr); s = 0.0
    for i, v in enumerate(gr):          # block rate (2 ms) so a Python loop is cheap
        s = a * s + (1 - a) * v if v > s else r * s + (1 - r) * v
        sm[i] = s
    g = 10 ** (-_to_samples(sm, hop, x.shape[1]) / 20)
    return x * g, float(sm.mean()), float(sm.max())


def limiter(x, sr, ceiling_db=CEILING_DB, lookahead=0.0015, release=0.08):
    """Look-ahead peak limiter on a 4x-oversampled (true-peak-ish) detector.
    gain = moving-average(moving-min(needed gain)) so the gain never exceeds what each sample needs,
    then an upward-only release. Returns (y, max gain reduction dB)."""
    ceil = 10 ** (ceiling_db / 20) * 0.985          # small margin for the interpolation between blocks
    hop = max(1, int(sr * 0.0004))
    up = np.abs(resample_poly(x, 4, 1, axis=-1)).max(0)
    pk = _block_env(np.pad(up, (0, (-len(up)) % (hop * 4))), hop * 4).max(-1)
    need = np.minimum(1.0, ceil / np.maximum(pk, 1e-9))
    W = max(1, int(lookahead * sr / hop))
    from scipy.ndimage import minimum_filter1d, uniform_filter1d
    g = uniform_filter1d(minimum_filter1d(need, 2 * W + 1, mode="nearest"), 2 * W + 1, mode="nearest")
    g = np.minimum(g, minimum_filter1d(need, 3, mode="nearest"))
    rel = np.exp(-hop / (release * sr))
    out = np.empty_like(g); s = 1.0
    for i, v in enumerate(g):
        s = v if v < s else rel * s + (1 - rel) * v
        out[i] = s
    gs = _to_samples(out, hop, x.shape[1])
    return x * gs, float(-20 * np.log10(out.min()))


def soft_clip(x, thr, knee=0.6):
    """4x-oversampled soft clipper: linear below knee*thr, then a tanh curve into the ceiling thr."""
    u = resample_poly(x, 4, 1, axis=-1)
    a = knee * thr; ab = np.abs(u); over = ab > a
    u[over] = np.sign(u[over]) * (a + (thr - a) * np.tanh((ab[over] - a) / (thr - a)))
    return resample_poly(u, 1, 4, axis=-1)[..., :x.shape[-1]]


def master_level(x, sr, target_lufs, ceiling_db=CEILING_DB - ENCODER_MARGIN_DB, max_gr=MAX_LIMIT_GR_DB):
    """Gain to the loudness target, limit to the ceiling, re-measure, repeat until within 0.1 LU.
    If the limiter would have to pull more than max_gr dB, lower the target instead (short jingles with a
    long quiet tail otherwise get squashed to reach an integrated target)."""
    g = 10 ** ((target_lufs - lufs(x, sr)) / 20)
    for _ in range(12):
        y, gr = limiter(x * g, sr, ceiling_db)
        if gr > max_gr + 0.05:
            g *= 10 ** (-(gr - max_gr) / 20)
            continue
        err = target_lufs - lufs(y, sr)
        if abs(err) < 0.1 or (err > 0 and gr > max_gr - 0.3):
            break
        g *= 10 ** (err / 20)
    # final safety: true peak must sit at or under the ceiling
    tp = true_peak(y)
    if tp > 10 ** (ceiling_db / 20):
        y *= 10 ** (ceiling_db / 20) / tp
    return y, gr


# ---------------------------------------------------------------- S-DSP emulation
GAUSS_1TO1 = np.array([0x176, 0x519, 0x172]) / 2048.0   # taps on s[n], s[n-1], s[n-2] at pitch ratio 1:1
NSPC_LOWPASS_FIR = [0x0C, 0x21, 0x2B, 0x2B, 0x13, -0x02, -0x0D, -0x07]   # $0C $21 $2B $2B $13 $FE $F3 $F9
FIR_PASSTHRU = [0x7F, 0, 0, 0, 0, 0, 0, 0]


def gaussian_interp(x):
    """The S-DSP's Gaussian interpolation at a 1:1 pitch ratio is a fixed 3-tap low-pass:
    -3.9 dB at 8 kHz, -7 dB at 11 kHz, -11 dB at 16 kHz (32 kHz output)."""
    return lfilter(GAUSS_1TO1, [1.0], x, axis=-1)


def brr_grit(x, amount=0.3, block=16):
    """BRR-like requantisation noise. Each 16-sample block of the filter-1 residual (x[n] - 15/16 x[n-1])
    gets a power-of-two step sized so its peak fits a 4-bit nibble (-8..7); the rounding error of that
    residual is what a closed-loop BRR encoder leaves in the decoded sample. A fraction `amount` of that
    error is added back, so the grit tracks the signal like BRR noise does but stays light."""
    y = x.copy()
    for ch in range(x.shape[0]):
        s = x[ch]
        r = s - np.concatenate(([0.0], s[:-1])) * (15 / 16)
        n = len(r) // block * block
        rb = r[:n].reshape(-1, block)
        peak = np.abs(rb).max(1)
        step = 2.0 ** np.ceil(np.log2(np.maximum(peak, 1e-7) / 7.0))
        step = np.maximum(step, 2.0 ** -15)
        q = np.clip(np.round(rb / step[:, None]), -8, 7) * step[:, None]
        err = (q - rb).ravel()
        y[ch, :n] += amount * err
    return y


def sdsp_echo(x, sr, edl=10, efb=0.38, evol=0.30, fir=NSPC_LOWPASS_FIR):
    """S-DSP echo. Buffer length = EDL * 16 ms (512 samples at 32 kHz). What comes out of the buffer runs
    through the 8-tap FIR; that FIR output is heard (* EVOL) and written back (* EFB) with the new input.
    x: (2, n) echo input (sum of the EON voices). Returns the echo return only (to add to the dry mix)."""
    D = max(1, int(round(edl * 0.016 * sr)))
    c = np.array(fir, dtype=float) / 128.0      # FFC0 multiplies the oldest of the 8 samples
    b = c[::-1]                                  # lfilter's b[0] multiplies the newest
    n = x.shape[1]
    out = np.zeros_like(x)
    for ch in range(x.shape[0]):
        buf_in = x[ch]
        written = np.zeros(n + D)                # what gets written into the ring (input + feedback)
        fir_out = np.zeros(n)
        zi = np.zeros(len(b) - 1)
        for s0 in range(0, n, D):                # FIR output in block k depends only on block k-1's writes
            s1 = min(s0 + D, n)
            read = written[s0 - D:s1 - D] if s0 >= D else np.zeros(s1 - s0)
            f, zi = lfilter(b, [1.0], read, zi=zi)
            fir_out[s0:s1] = f
            written[s0:s1] = np.clip(buf_in[s0:s1] + efb * f, -1.0, 1.0)
        out[ch] = fir_out * evol
    return out


def spring_reverb(x, sr, secs=1.8, seed=7):
    """Spring-tank flavoured reverb: decaying noise IR plus a dispersive chirp (the 'boing')."""
    rr = np.random.default_rng(seed)
    L = int(secs * sr); t = np.arange(L) / sr
    out = []
    for ch in range(2):
        ir = rr.normal(0, 1, L) * np.exp(-t / (secs / 5.0))
        ir = sosfilt(butter(2, [300, 5500], "bandpass", fs=sr, output="sos"), ir)
        ir += 0.5 * np.sin(2 * np.pi * (2400 * t - 1100 * t * t)) * np.exp(-t / 0.3) * rr.normal(1, 0.1, L)
        ir[:int(0.008 * sr)] = 0
        ir /= np.sqrt(np.sum(ir ** 2))
        out.append(fftconvolve(x[ch], ir)[:x.shape[1]])
    return np.stack(out)


def narrow(x, side_gain):
    m = (x[0] + x[1]) / 2; s = (x[0] - x[1]) / 2 * side_gain
    return np.stack([m + s, m - s])


# ---------------------------------------------------------------- stem mixer + masters
DEFAULT_ROLES = {
    # stem: loudness relative to the drum kit (LU), high-pass (Hz), S-DSP echo send (EON level)
    # kit = snare, hats, cymbals (the reference every other stem is set against). Drum hits peak ~20 dB over
    # their loudness; an oversampled soft clipper 15 dB over it shaves the first ms of each hit (about -5 dB
    # peak-to-loudness for -0.7 dB loudness) so the master limiter doesn't pump the mix on every hit.
    # GM snares have a big 200 Hz body: -5 dB there keeps the 120-250 Hz band from piling up with the bass.
    "kit":     dict(lu=0.0,  hp=60, eq=[("peak", 200, 1.0, -5.0)], clip=15.0, echo=0.0),
    # GM kicks are boomy: steep 45 Hz high-pass, less 60-120 Hz, more beater click so it reads on phone speakers
    "kick":    dict(lu=-5.0, hp=45, hp_order=4, eq=[("lowshelf", 110, 0.7, -3.0), ("peak", 3200, 1.0, 3.0)], clip=14.0, echo=0.0),
    "toms":    dict(lu=-3.0, hp=60, eq=[("peak", 200, 1.0, -3.0)], clip=15.0, echo=0.0),
    "bass":    dict(lu=-4.0, hp=38, eq=[("peak", 170, 1.0, -2.0)], echo=0.0),
    "gtr":     dict(lu=-1.0, hp=75,  echo=0.25),
    "mute":    dict(lu=-3.5, hp=75,  echo=0.15),
    "clean":   dict(lu=-3.0, hp=90,  echo=0.5),
    "trem":    dict(lu=0.0,  hp=110, echo=0.6),
    "lead":    dict(lu=0.5,  hp=110, echo=0.7),
    "organ":   dict(lu=-7.0, hp=70,  echo=0.4),
    "farfisa": dict(lu=-5.0, hp=90,  echo=0.5),
}


def mix_stems(stems, sr, profile, mix=None, keep=False):
    """stems: {name: (2, n)} -> (2, n) mix plus a report. mix: per-song overrides
    {stem: {lu, hp, eq: [(kind, f, q, gain)], echo, spring}, '_echo': {edl, efb, evol}, '_grit': amount}."""
    mix = mix or {}
    n = max(v.shape[1] for v in stems.values())
    ref = next((lufs(hpf(stems[k], DEFAULT_ROLES[k]["hp"], sr), sr) for k in ("kit", "kick", "toms") if k in stems), -20.0)
    out = np.zeros((2, n)); echo_in = np.zeros((2, n)); spring_in = np.zeros((2, n))
    report = {}
    for name, x in stems.items():
        role = dict(DEFAULT_ROLES.get(name, dict(lu=-4.0, hp=80, echo=0.3)))
        role.update(mix.get(name, {}))
        x = np.pad(x, ((0, 0), (0, n - x.shape[1])))
        if role.get("hp"):
            x = hpf(x, role["hp"], sr, role.get("hp_order", 2))
        # Fader first, EQ after (like a console): the level is set from the high-passed stem, so an EQ cut
        # really removes energy instead of being undone by the loudness match (a GM snare's 200 Hz body or a
        # kick's sub dominate their stem's loudness, so matching after EQ would just turn them back up).
        l = lufs(x, sr)
        g = 10 ** ((ref + role["lu"] - l) / 20) if l > -69 else 0.0
        x = x * g
        report[name] = dict(lufs_raw=round(l, 1), gain_db=round(20 * np.log10(g + 1e-12), 1))
        for kind, f, q, gdb in role.get("eq", []):
            x = eq(x, kind, f, sr, q, gdb)
        if role.get("comp"):        # (threshold re the stem's own loudness dB, ratio, attack s, release s)
            rel, ratio, att, relt = role["comp"]
            x, _, _ = glue_compress(x, sr, lufs(x, sr) + rel, ratio, att, relt, knee=4.0)
        if role.get("clip"):        # soft-clip ceiling in dB over the stem's own loudness
            x = soft_clip(x, 10 ** ((lufs(x, sr) + role["clip"]) / 20))
        if profile == "snes":
            x = brr_grit(x, mix.get("_grit", 0.3))
            x = gaussian_interp(x)
        if keep:
            report[name]["audio"] = x
        out += x
        if profile == "snes" and role.get("echo"):
            echo_in += x * role["echo"]
        if role.get("spring"):
            spring_in += x * role["spring"]
    if spring_in.any():
        out += spring_reverb(spring_in, sr)
    if profile == "snes" and echo_in.any():
        e = mix.get("_echo", {})
        out += sdsp_echo(echo_in, sr, e.get("edl", 10), e.get("efb", 0.38), e.get("evol", 0.30),
                         e.get("fir", NSPC_LOWPASS_FIR))
    return out, report


def master(x, sr, profile, target_lufs):
    """hifi: 35 Hz low cut, +1.5 dB presence at 3.5 kHz, 2:1 glue comp, limiter at -1 dBTP, loudness target.
    snes: 45 Hz low cut, slightly narrower stereo, then the same loudness/limiter stage (no glue comp: the
    S-DSP had none)."""
    info = {}
    if profile == "hifi":
        x = hpf(x, 35, sr)
        x = eq(x, "peak", 3500, sr, 0.8, 1.5)
        thr = 10 * np.log10(np.mean(x ** 2) + 1e-12) + 4.0
        x, info["glue_gr_mean"], info["glue_gr_max"] = glue_compress(x, sr, thr)
    else:
        x = hpf(x, 45, sr)
        x = narrow(x, 0.75)
    x, info["limit_gr_max"] = master_level(x, sr, target_lufs)
    return x, info


def trim_and_fade(x, sr, head_db=-60.0, tail_db=-60.0, pre=0.01, fade=0.05):
    """Drop leading silence (keep `pre` s), cut the tail where it stays below tail_db, short fades both ends,
    so every file starts and ends on silence (no clicks; Godot's music player chains tracks on 'finished')."""
    env = np.abs(x).max(0)
    thr_h, thr_t = 10 ** (head_db / 20), 10 ** (tail_db / 20)
    above = np.nonzero(env > thr_h)[0]
    i0 = max(0, above[0] - int(pre * sr)) if len(above) else 0
    above = np.nonzero(env > thr_t)[0]
    i1 = min(x.shape[1], above[-1] + int(0.02 * sr)) if len(above) else x.shape[1]
    y = x[:, i0:i1].copy()
    fi = int(0.003 * sr); fo = int(fade * sr)
    y[:, :fi] *= np.linspace(0, 1, fi)
    y[:, -fo:] *= np.linspace(1, 0, fo) ** 2
    return y


def write_ogg(path, x, sr, q):
    """float32 stereo -> Ogg Vorbis via ffmpeg (flags explained inline)."""
    with tempfile.NamedTemporaryFile(suffix=".f32", delete=False) as f:
        f.write(np.ascontiguousarray(x.T, dtype="<f4").tobytes()); raw = f.name
    subprocess.run(["ffmpeg",
                    "-y",                    # overwrite the output file
                    "-loglevel", "error",    # only print errors
                    "-f", "f32le",           # input format: raw little-endian 32-bit float
                    "-ar", str(sr),          # input sample rate
                    "-ac", "2",              # input channels
                    "-i", raw,               # input file
                    "-c:a", "libvorbis",     # encode with libvorbis
                    "-q:a", str(q),          # VBR quality (4 ~ 128 kb/s, 5 ~ 160 kb/s at 44.1 kHz stereo)
                    path], check=True)
    os.unlink(raw)
