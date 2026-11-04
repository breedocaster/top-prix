# tools/audio

Generators for everything in `godot/audio/`:

| Script | Makes |
|---|---|
| `engines.py` | engine loops per engine type and exhaust (`godot/audio/engine/`) |
| `sfx.py` | UI and race sound effects (`godot/audio/sfx/`) |
| `music.py` | the soundtrack: 7 songs and 3 jingles (`godot/audio/music/*.ogg`) |
| `mixdsp.py` | music rendering library: FluidSynth calls, stem mixer, hi-fi master, SNES S-DSP emulation, loudness meter |
| `music_check.py` | measures the rendered music (loudness, peaks, clipping, endings, spectral balance) and draws spectrograms |

## Music

Every song is composed as code in `music.py`: chord progressions, riffs, drum patterns and melodies as event lists. Rendering happens in four steps:

1. **Performance → MIDI.** `Performance` turns the event lists into a type-1 Standard MIDI File with `mido`. It uses 480 ticks per beat at the song tempo, and swing is already baked into `Song.t()`. Musicianship is added at this step:
   - humanised timing: ±8 ms on the hi-fi path, ±3 ms on the SNES path, because SNES sequencers were tight
   - humanised velocity
   - strummed chords
   - per-part articulation
   - double-tracked rhythm guitar
   - pitch-bend bends and delayed CC1 vibrato on the lead
2. **MIDI → stems.** FluidSynth renders each instrument group (stem) on its own.
3. **Stems → mix.** `mixdsp.mix_stems` sets each stem's level by loudness relative to the drum kit, then applies high-pass, EQ, drum soft-clipping and effect sends. Gain comes before EQ, as on a console.
4. **Master → Ogg.** The mix goes through either the hi-fi or the SNES chain, then is cut to clean start and end points and encoded.

| Path | Songs | Soundfont | Rate | Ogg |
|---|---|---|---|---|
| **hi-fi** | `tinplate_boogie` (title), `shed_sessions` (garage), `long_road_home` (credits) | MuseScore_General_Full | 44.1 kHz | `-q:a 5` |
| **snes** | `full_throttle`, `redline_shuffle`, `gravel_surf`, `crownwell_motors`, `jingle_win`, `jingle_podium`, `jingle_lose` | FluidR3_GM | 32 kHz | `-q:a 4` |

File names are fixed: `godot/scripts/audio/audio.gd` plays them by name. The `.ogg.import` files keep `loop=false`, because `Audio` moves to the next track on `finished`. So every track starts within about 10 ms and ends on silence. The tail is cut where it stays below -60 dBFS, or -48 dBFS for jingles, because `Audio.jingle()` ducks the music for the stream's full length.

### Regenerate

```bash
# one-time setup (Debian/Ubuntu)
sudo apt install fluidsynth fluid-soundfont-gm musescore-general-soundfont-lossless ffmpeg
#   fluidsynth                            the soft synth (2.3.x used here)
#   fluid-soundfont-gm                    /usr/share/sounds/sf2/FluidR3_GM.sf2 (MIT)
#   musescore-general-soundfont-lossless  /usr/share/sounds/sf2/MuseScore_General_Full.sf2 (MIT)
#   ffmpeg                                needs libvorbis (Ubuntu's build has it)
pip install --break-system-packages mido numpy scipy
#   --break-system-packages  lets pip install into the system Python on distros that mark it "externally managed"

python3 tools/audio/music.py                      # render all 10 into godot/audio/music/ (~1 min on 2 cores)
python3 tools/audio/music.py gravel_surf jingle_win   # only these
python3 tools/audio/music_check.py                # stats table + spectrograms in /tmp/music_spec/
```

`music.py` arguments:

| Argument | Meaning |
|---|---|
| `song ...` | Song names to render. Default: all of them. |
| `--out DIR` | Output directory. Default: `godot/audio/music`. The old form, a non-song first argument (`music.py DIR`), still works. |
| `--profile hifi\|snes` | Force one rendering path for every song, e.g. to hear a race song in hi-fi. |
| `--midi DIR` | Also save each song's full multi-track `.mid` here, to open in a DAW. |
| `--work DIR` | Scratch directory for per-stem MIDI and WAV files. Default: `/tmp/top-prix-music`. |
| `--jobs N` | Number of FluidSynth renders to run in parallel. Default: CPU count. |
| `--synth` | Use the original home-made synthesis (Karplus-Strong guitars, saw lead, additive organ, synthesized drums) at 32 kHz. No soundfonts. |

`music_check.py [DIR] [--spec DIR]` checks `DIR` (default `godot/audio/music`) and writes PNGs to `--spec` (default `/tmp/music_spec`).

### What the FluidSynth call does

`mixdsp.fluidsynth_render` runs:

```
fluidsynth -n -i -q -r <rate> -g 0.5 -R <0|1> -C <0|1> -O float -T wav
           -o synth.polyphony=512 -o synth.dynamic-sample-loading=1
           -o synth.reverb.room-size=0.62 -o synth.reverb.damp=0.45 -o synth.reverb.width=0.9 -o synth.reverb.level=0.75
           -o synth.chorus.nr=3 -o synth.chorus.level=1.2 -o synth.chorus.speed=0.35 -o synth.chorus.depth=5
           -F <out.wav> <soundfont.sf2> <stem.mid>
```

| Flag | Meaning |
|---|---|
| `-n` (`--no-midi-in`) | Don't open a MIDI input driver. This is an offline render. |
| `-i` (`--no-shell`) | Don't start the interactive shell on stdin. |
| `-q` (`--quiet`) | No banner. |
| `-r` | Sample rate: 44100 for hi-fi, 32000 for SNES (the S-DSP output rate). |
| `-g 0.5` | Master gain. The output is float, so this can't clip. Levels are set in numpy. |
| `-R` / `-C` | FluidSynth reverb and chorus. On for hi-fi, driven by the CC91/CC93 sends per track. Off for SNES, because the S-DSP had only its echo. |
| `-O float -T wav` | 32-bit float WAV. |
| `synth.polyphony` | Voice limit. Ring-outs plus double-tracking need headroom. |
| `synth.dynamic-sample-loading` | Load only the samples of the presets in use, so the 490 MB MuseScore font starts in well under a second. |
| `synth.reverb.*` | Reverb tuning: room size, high damping, stereo width, return level. |
| `synth.chorus.*` | Chorus tuning: voices, level, LFO rate (Hz), depth (ms). Slow, Leslie-ish on the organ. |
| `-F out.wav` | Fast render: write the MIDI file's audio to this file as fast as possible. |

The conductor track ends with a marker 4 s after the last note-off (2.5 s for jingles), so the render includes the release and reverb tails.

### What the ffmpeg call does

```
ffmpeg -y -loglevel error -f f32le -ar <rate> -ac 2 -i <raw> -c:a libvorbis -q:a <4|5> out.ogg
```

| Flag | Meaning |
|---|---|
| `-y` | Overwrite the output. |
| `-loglevel error` | Only print errors. |
| `-f f32le -ar <rate> -ac 2 -i <raw>` | The input is raw little-endian float32 stereo at the given rate. |
| `-c:a libvorbis` | Encode Ogg Vorbis. |
| `-q:a` | VBR quality: 5 is about 160 kb/s at 44.1 kHz, 4 is about 128 kb/s. |

`music_check.py` measures with:

- `ffmpeg -i f.ogg -af ebur128=peak=true -f null -`: EBU R128 integrated loudness, loudness range and 4×-oversampled true peak.
- `-lavfi showspectrumpic=s=1600x600:mode=combined:fscale=log:scale=log:drange=100:legend=1`: the spectrogram. It uses a log frequency axis so melodies read as contours, and a 100 dB range.

### General MIDI mapping

Programs are 1-based GM numbers. `mido` sends them 0-based.

| Part (event track) | MIDI channel | Program |
|---|---|---|
| rhythm guitar (`rhythm`), double-tracked | 1 (hard L) + 2 (hard R, ~10 ms late, ~8 % softer, +5 cents) | 30 Overdriven Guitar. `full_throttle` and `crownwell_motors` use 31 Distortion Guitar. |
| palm-muted hits (`x` in `power()` patterns, track `rhythm:mute`) | 3 (L) + 4 (R) | 29 Electric Guitar (muted) |
| clean guitar (`clean`) | 5 | 28 Electric Guitar (clean) |
| surf tremolo melody (`clean:trem`) | 11 | 28 Electric Guitar (clean) |
| bass | 6 | 35 Electric Bass (pick) |
| lead | 7 | 30 Overdriven Guitar (31 on the two heavy songs) |
| organ | 8 | 19 Rock Organ (17 Drawbar on `shed_sessions` and `long_road_home`) |
| farfisa | 9 | 17 Drawbar Organ |
| drums | 10 | Standard kit. Kick 36, snare 38, side stick 37, closed hat 42, open hat 46, crash 49, ride 51, toms 50/47/43. |

Lead details:

- **Bend range.** RPN 0 sets it to ±2 semitones.
- **Bends.** The pitch wheel ramps to the event's bend amount over ~100 ms, starting 30 ms after the pick.
- **Vibrato.** CC1 fades in from 180 ms after the attack.
- **Vibrato rate.** The SF2 default vibrato LFO is 8.2 Hz, which is too fast for a guitar, so an SF2.01 NRPN (MSB 120, LSB 24 = `freqVibLFO`) sets ~5.5 Hz. FluidSynth 2.3 scales that NRPN at 4 cents per step. That figure was measured by pitch-tracking a render, not taken from documentation.

Kick, snare/hats/cymbals ("kit") and toms share channel 10 but render as separate stems. That lets the mix set the kick against the snare: GM kicks are boomy and otherwise rule the low end.

### Hi-fi master (`mixdsp.master`, profile `hifi`)

1. 35 Hz low cut, then +1.5 dB presence at 3.5 kHz.
2. 2:1 stereo-linked RMS glue compressor. Threshold 4 dB over the mix RMS, 25 ms attack, 250 ms release. It averages under 0.5 dB of reduction.
3. Loudness target -14 LUFS. The meter is ITU-R BS.1770-4 gated loudness with K-weighting re-derived for any sample rate. It reads -3.01 LUFS on the standard 997 Hz full-scale one-channel test tone and matches ffmpeg's `ebur128`.
4. Look-ahead limiter on a 4×-oversampled (true-peak-ish) detector, ceiling -1 dBTP:
   - It limits 0.7 dB lower, because Vorbis encoding overshoots by up to about 0.6 dB.
   - If reaching -14 LUFS would take more than 4.5 dB of limiting, it settles for a quieter result.

### SNES path (`mixdsp`, profile `snes`)

Each stem, then the mix, gets the S-DSP's characteristic processing:

- **32 kHz** render and output (S-DSP output rate).
- **BRR-like grit.** Each 16-sample block of the filter-1 residual (`x[n] - 15/16·x[n-1]`) is requantised to a 4-bit nibble (-8..7) with a power-of-two step. 30 % of that rounding error is added back, which measures about -34 to -39 dB below the signal: light, and it tracks the signal like BRR noise.
- **Gaussian interpolation.** At a 1:1 pitch ratio the S-DSP's 4-tap Gaussian interpolator reduces to a fixed 3-tap kernel: table entries `g[255], g[511], g[256]` = 0x172, 0x519, 0x176 out of 2048. That is -3.9 dB at 8 kHz, -7.2 dB at 11 kHz and -11 dB at 16 kHz. The code applies that kernel itself, not an approximation of it.
- **Echo, per stem (EON).** Lead, guitars, clean/tremolo and organ feed the echo; drums and bass don't.
  - The buffer is EDL × 16 ms long (512 samples per step at 32 kHz, 240 ms maximum).
  - What comes out of the buffer runs through the 8-tap FIR. That FIR output is heard at EVOL and written back at EFB together with new input.
  - The FIR is N-SPC's common low-pass, `$0C $21 $2B $2B $13 $FE $F3 $F9`: +0.6 dB peak, about -3 dB near 5 kHz.
  - Per-song EDL/EFB/EVOL is in `SONG_CFG`, e.g. `full_throttle` uses EDL 12 (192 ms, about an 8th note at 152 bpm), EFB 0.35, EVOL 0.28.
- **Stereo.** Side × 0.75, slightly narrower.
- **Master.** 45 Hz low cut, then the same loudness target and limiter as hi-fi. No glue compression: the S-DSP had none.

`gravel_surf` also sends its tremolo melody to a spring-style reverb (decaying-noise IR plus a dispersive chirp).

### Tuning a song

Each song's entry in `SONG_CFG` (in `music.py`) holds:

- `profile`: hifi or snes
- `orch`: GM program overrides
- `bass_art`: bass note length on 8ths
- `tail`: render tail length
- `trim_db`: where the tail is cut
- `mix`: per-stem overrides of `mixdsp.DEFAULT_ROLES`:
  - `lu`: loudness relative to the snare/hats kit, in LU
  - `hp`, `hp_order`: high-pass
  - `eq`: list of `(kind, Hz, Q, dB)`
  - `clip`: soft-clip ceiling in dB over the stem's loudness
  - `echo`: EON send
  - `spring`: spring-reverb send
  - `_echo`: `{edl, efb, evol, fir}`

After any change, run `music_check.py`. Expect, for each file:

- no `clip`
- `TP` at or below -1.0 dBTP
- `LUFS` about -14
- `end` below -70 dB
- 100 Hz–4 kHz slope within a couple of dB of -5 dB/octave, the average Pestana et al. measured for commercial recordings

## Soundfont licenses

The soundfonts are not in this repo. They come from the Debian/Ubuntu packages above. Both are **MIT**, per their Debian copyright files:

- **MuseScore_General_Full.sf2** (MuseScore_General_HQ by S. Christian Collins).
  - License: MIT, with parts in the public domain or CC0.
  - Copyright file: `/usr/share/doc/musescore-general-soundfont-lossless/copyright`.
  - Builds on Fluid (R3) by Frank Wen (MIT), the Fluid R3 Mono version by Michael Cowgill, Drumline Cymbals by Michael Schorsch, Temple Blocks by Ethan Winer, CC0 VSCO/VCSL samples by Sam Gossner and others, and a public-domain Splendid Grand piano.
- **FluidR3_GM.sf2** (Fluid R3 GM by Frank Wen).
  - License: MIT.
  - Copyright file: `/usr/share/doc/fluid-soundfont-gm/copyright`.

**TimGM6mb.sf2** is installed on the build box too but is **not used**: it has a different license.

`godot/audio/CREDITS.md` carries the notices that ship with the game.

## Sources for the S-DSP and mastering numbers

- S-DSP echo (EDL buffer size, EFB/EVOL format, FIR placement and formula), 32 kHz output, Gaussian table: anomie/jwdonal, "apudsp" document, [RomHacking.net mirror](https://otakon273.duckdns.org/Consoles/RomHacking.net/rhdn_20240801/documents/[191]apudsp_jwdonal.txt)
- FIR position in the echo loop and N-SPC FIR presets: [sneslab.net, "FIR Filter"](https://sneslab.net/wiki/FIR_Mixer)
- BRR block format, nibble range and predictor coefficients: [snes.nesdev.org, "BRR samples"](https://snes.nesdev.org/wiki/BRR_samples)
- Reference spectral slope: Pestana, Ma, Reiss et al., "Spectral characteristics of popular commercial recordings 1950–2010", AES 135th Convention, 2013 ([PDF](https://joshreiss.github.io/documents/2013/Pestana%20Ma%20Reiss%20-%20AES135.pdf))
- Loudness: ITU-R BS.1770-4. The any-rate K-weighting coefficients follow B. De Man's derivation, as used in pyloudnorm.
