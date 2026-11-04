# Top Prix

A Kairosoft-style motorsport team manager. It plays like Grand Prix Story 1 and has roughly as much content as Grand Prix Story 2. You run a race team that builds and races **cars and motorcycles, on tarmac and off-road**, and you get very hands-on with the engines.

> Status: the playable prototype is HTML5/JavaScript in `web/`. A Godot 4 port is planned under `godot/`.

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
