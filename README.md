# Top Prix

A Kairosoft-style motorsport team manager. It plays like Grand Prix Story 1 and has roughly as much content as Grand Prix Story 2. You run a race team that builds and races **cars and motorcycles, on tarmac and off-road**, and you get very hands-on with the engines.

> Status: the full single-player game is HTML5/JavaScript in `web/`. The Godot 4.7 port in `godot/` is at milestone 1: SNES-style race graphics, quick races and LAN multiplayer. The career and engineering benches come next.

## What's in it

- **Team management, GP1-style.** Build vehicles from a body plus a drive layout. Your mechanics' Tech decides build quality. Upgrade Speed, Accel, Handling and Durability 5× each, and fit parts into slots. Research costs research data (RP). Drivers train using money and energy. Sponsors have goals that unlock things. Facilities live in garage slots. Workshops go Backyard Shed → Town Garage → Race Workshop → Factory HQ.
- **Staged builds.** Every build in every difficulty mode goes through 8 shop phases: design, frame, engine, drivetrain, suspension, bodywork, electrics, shakedown. You pick an option at each phase, such as a chromoly vs. carbon frame, a blueprinted or high-rev engine, close vs. wide gearing, or a gravel vs. tarmac suspension setup. Each pick changes cost, days, stats, terrain bias and part slots. Random shop events (a cracked casting, backordered parts, a press visit) interrupt with their own choices. Can't decide? Hit "Let the crew decide" to auto-pick. The garage bay shows the vehicle moving from blueprint to bare metal to paint.
- **46 vehicles**: 23 cars (hatches, formula cars, prototypes, rally cars, buggies, trophy trucks) and 23 bikes (scooters, sport bikes, GP bikes, MX, enduro, flat track, supermoto, sidecar).
- **Bike engines** are single, twin, V-twin, triple, inline-4, 2-stroke or electric. There's **one carb per cylinder**, and multi-carb engines need **vacuum syncing**.
- **Fuel tuning**
  - **Bike carbs:** round-slide (PE-style), CV (BS-style), PWK-style, flat-slide pumper (FCR-style). Adjustable parts are main jet, pilot jet, needle clip, air or fuel screw, fuel level and accelerator pump.
  - **Car carbs:** 2-barrel and 4-barrel downdrafts with primary and secondary jets, power valve, idle screws and pump squirter. The twin sidedraft has main jet, air corrector, idle jet and pump jet.
  - **Animated carb cutaways:** the slide and needle move, the clip sits in its groove, the fuel level and floats move, jet orifice size is drawn to scale, and fuel droplets atomize in the airflow. A wideband AFR gauge (or a plug chop, before you've researched the wideband) shows the result, along with an AFR-vs-throttle chart.
  - **EFI laptop**, TunerStudio-style: VE, spark and AFR target tables with cell selection, ±1 and ±5% edits, smoothing, dyno pulls with a live trace, and VE Analyze (`New VE = VE × measured AFR / target AFR`). Alpha-N needs a MAP sensor plus baro correction to handle altitude. There are also IAT, knock sensor, launch control, traction maps and flex fuel.
  - **Conditions matter.** Altitude and temperature change air density. Carbs go rich as the air thins (AFR ∝ √density). Hillclimbs climb through thousands of metres.
  - **Real consequences.** Lean mixture or too much timing causes detonation, heat damage, a holed piston or a seized two-stroke. A float level that's too low starves on jumps, and one that's too high floods on rough ground. A rich idle fouls plugs.
- **Setup sheet:** sprockets or final drive, suspension clicks, tire pressure and wing angle.
- **Track types and formats**
  - Looping circuits and ovals, with Sprint, Feature or Endurance lengths.
  - MX, ovals and mixed tracks can run **heats + main**.
  - **Drag strips** run as an 8-car elimination ladder with a christmas tree, reaction time, ET and mph.
  - **Hillclimbs** are timed runs, best of two, and you can retune between runs.
  - Rally stages are time trials. **Test days** collect datalogs.
- **142 races and 28 series** across 7 disciplines: road car, off-road car, road bike, dirt bike, open, drag and hillclimb. There are Rookie, National, Continental, World and Legend tiers.
- **Tech tree** with 30 technologies, **46 achievements**, and **three difficulty modes** you can switch any time:
  - **Easy:** the crew tunes for you, and a bad tune can't damage the engine.
  - **Standard:** you tune, and the crew warns you about risks.
  - **Sim:** no hints, and race-day weather swings more.
- Pixel art drawn procedurally: animated garage, multi-layer parallax race view, night races, smoke and backfire effects.

## Play / build

The built game is a single file: `web/dist/index.html`. Open it in any browser.

```bash
cd web
python3 build.py          # concatenates src/* into dist/index.html
```

Source lives in `web/src/`:

| File | What it holds |
|---|---|
| `data.js`, `data2.js` | All content: vehicles, parts, races, series, sponsors, carbs, tech tree, achievements |
| `engine.js` | Game state, economy, staff, research, building, sponsors, series, saves |
| `tune.js` | Engine and fuel model: carb richness, EFI cells, air density, knock limits, damage, crew tune |
| `race.js` | Race simulation and formats |
| `gfx.js`, `tunegfx.js` | Procedural pixel art: garage, race view, carb benches, sync gauges, dyno |
| `ui.js`, `ui2.js`, `main.js` | Menus, tuning screens, race flow, boot loop, sound, save |

## Godot port (`godot/`)

Open `godot/project.godot` in Godot 4.7 (Compatibility renderer, portrait 256×512 pixel canvas with integer scaling).

**Milestone 1 (this version):**
- **SNES-style race view.** A Mode 7–style perspective floor draws a course painted from the sim's section list. Loops close exactly, rally/hillclimb stages meander, drag strips run straight. The sky and three parallax strips turn with the camera. Trackside props and vehicles are depth-sorted, scaled billboards.
- **Pre-rendered 16-bit sprites.** Voxel models of every body kind are rendered at 16 angles with a fixed light and a 4-shade hue-shifted ramp plus outline. Each team gets a palette swap, and colors are snapped to the SNES 15-bit color space.
- **Shared content.** `node web/tools/export_godot.js` dumps the web build's data to `godot/data/game_data.json` and writes parity fixtures. The race sim, track generator and vehicle/driver profiles are ported to GDScript. The RNG and hash are bit-exact, so the same race id gives the same track in both builds.
- **Quick race** with any preset machine, or with the machines from your web career: in the web game export the save, then paste the `GG1:` code into Garage → Import. Odds against the field are shown per race.
- **LAN multiplayer** for phones on the same Wi-Fi. The host is authoritative: it runs the sim and streams snapshots at 15 Hz, and clients send race calls (Safe/Normal/Push, Spark, Retire) for their own entry. Hosts are found automatically through a UDP broadcast beacon, with manual IP join as a fallback.
  - **Co-op:** everyone races for the host's team against the AI field, and the team's points decide the result.
  - **Versus:** each player races for their own team in a circuit race (AI field optional), a head-to-head drag run, or a hillclimb time trial.
- **Android:** `export_presets.cfg` sets the INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE and CHANGE_WIFI_MULTICAST_STATE permissions. Godot's `PacketPeerUDP` docs note that some Android devices need the multicast permission to receive broadcast packets.

**Not yet in the port:** engines race crew-tuned (ideal fueling), heats and the 8-car drag ladder, the management career, the carb/EFI/sync/dyno benches, and the shared co-op and versus careers. Those are milestones 2 and 3.

Godot tests (run from `godot/`; the rendered ones need a display, e.g. `xvfb-run`):

```bash
godot --headless --path . -- --test=sim       # web parity (RNG, tracks, profiles) + race batches, co-op scoring, drag/hill
godot --path . -- --test=shots                # screenshots of menus and races to tests/shots/
godot --path . -- --test=net_host &           # two-process LAN co-op race over 127.0.0.1 ...
godot --path . -- --test=net_client           # ... (vs_host / vs_client for a versus drag duel)
```

## Tests

```bash
cd web/test
node bot.js CR,BO 15     # headless bot plays 15 seasons and prints progression per year
node play.js             # Playwright UI smoke test (screenshots go to test/shots/)
node series.js           # series, year-end, save/reload
node eng.js              # carb/EFI benches, sync, setup, drag/hill/heats, test day
node monkey.js           # randomized clicking
```

The UI tests need Playwright with Chromium installed.
