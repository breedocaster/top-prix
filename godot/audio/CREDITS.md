# Audio credits

## Music (`music/`)

All compositions are original, written for Top Prix: songs `tinplate_boogie`, `shed_sessions`, `long_road_home`, `full_throttle`, `redline_shuffle`, `gravel_surf`, `crownwell_motors` and the jingles `jingle_win`, `jingle_podium`, `jingle_lose`. There are no covers and no samples of existing recordings. The notes, riffs and arrangements are written as code in `tools/audio/music.py`.

The recordings are rendered with FluidSynth, using instrument samples from two soundfonts released under the MIT license:

- **MuseScore_General** (MuseScore_General_HQ, the `MuseScore_General_Full.sf2` build) by S. Christian Collins. It renders the menu music: `tinplate_boogie`, `shed_sessions`, `long_road_home`. License: MIT, with parts in the public domain or CC0.
- **Fluid (R3) GM** by Frank Wen. It renders the race music and jingles, run through an SNES-style S-DSP emulation. License: MIT.

How to regenerate: `tools/audio/README.md`.

## Engine sounds and sound effects (`engine/`, `sfx/`)

Synthesized from code (`tools/audio/engines.py`, `tools/audio/sfx.py`). No third-party samples.

---

## License notices

### MuseScore_General_HQ SoundFont (MIT, parts PD or CC0)

From the Debian package `musescore-general-soundfont-lossless`, `/usr/share/doc/musescore-general-soundfont-lossless/copyright`:

```
MuseScore Drumline (MDL) samples (CC0) by S. Christian Collins & Amir Oosman
Splendid Grand piano from AKAI S5000 (verified Public Domain)

Marching Cymbals: open crash samples from Versilian Community Sample Library
https://github.com/sgossner/VCSL (CC0) by Sam Gossner

Ensemble strings from Versilian Studios Chamber Orchestra (VSCO) 2.1.1
Community Edition (CC0) by Sam Gossner, Simon Dalzell, Elan Hickler/Soundemote

Adaptation for MuseScore_General Copyright © 2018-2021 S. Christian Collins

Fluid (R3) Mono GM soundfont (MIT):

Mono version Copyright © 2014-2017 Michael Cowgill
Temple Blocks instrument Copyright © 2002 Ethan Winer
Drumline Cymbals Copyright © 2016 Michael Schorsch

(Original Stereo version) Fluid (R3) GM SoundFont (MIT):

Copyright © 2000-2002, 2008 Frank Wen <getfrank@gmail.com>
```

### Fluid (R3) GM SoundFont (MIT)

From the Debian package `fluid-soundfont-gm`, `/usr/share/doc/fluid-soundfont-gm/copyright`:

```
Copyright © 2000-2002, 2008 Frank Wen

"Fluid was constructed in part from samples found in the public domain that I
edited/cleaned/remixed/programmed and largely from recordings of my own and
in conjunction with the people below who helped along the way:
Suren M. Seron, Scott Hanan, Steve Aupperle, Chris Gillman, Alex Taubr,
Chris Prola, Andrew Klenk, Winfried Hubbe, Dylan, Tim, Gort, Uros Katic,
Ethan Winer (http://www.ethanwiner.com)"
```

### MIT license text (applies to both soundfonts)

```
Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
```
