# Godot port contract

The Godot build mirrors the web build (`web/src`) so its logic can be ported file by file, and so web saves (`GG1:` codes) load as Godot careers.

## Names
| Web | Godot |
|---|---|
| `D.X` (content tables) | `Data.D.X` (`data/game_data.json`, exported by `node web/tools/export_godot.js`). Functions in `D` are exported as tables (`D.formats` → `Data.formats(id)`, `D.condOf` → `Data.cond(id)`); port any other `D` function as a method on `Data` (`scripts/autoload/data.gd`) or add a table to the exporter. |
| `U.*` | `U.*` (`scripts/career/u.gd`, static). `U.seeded` / `U.hash` → `URng` (bit-exact). |
| `E.foo(...)` | `Career.foo(...)`: autoload `scripts/career/career.gd`. **Keep the JS camelCase names** so UI code can mirror `web/src/ui*.js` call for call. |
| `G` (game state) | `Career.G`: a Dictionary with exactly the web save shape (the JSON of `E.serialize()`). `Career.load_json(text)` / `Career.serialize()`. |
| `T.foo(...)` | `Tune.foo(...)`: `scripts/career/tune.gd`, `class_name Tune`, static, reads `Career.G`. |
| `Race.*` | `RaceSim` (`scripts/sim/race_sim.gd`, already ported and multi-human). Career races: `Career.makeRace(def, vid, sid, opts) -> RaceSim` with one human entry (owner 1) whose `sk` comes from `Tune.raceSecs` (full fuel model). `Career.finishRace(rs)` takes that RaceSim (`rs.humans()[0]` is the player). |
| `E.H.*` hooks | signals on `Career`: `toast(text)`, `popup(data)`, `floaty(text, vid, color)`, `sfx(name)`, `round_due(series_id)`, `year_end(summary)`, `game_end()`, `refresh()`, `build_ask(job)` |

Extra signals for the story layer (emitted by `Career`):

- `race_finished(info)`: `info = {race_id, fmt_id, pos, field, dnf, prize, series_id}`
- `title_won(series_id)`
- `workshop_up(level)`
- `research_done(tech_id)`
- `vehicle_built(vid)`
- `staff_hired(sid)`
- `sponsor_signed(id)`
- `day_passed(day)`

Story state persists inside the same save: `Career.G.story` (a Dictionary owned by the `Story` autoload).

## Time
`Career.tick()` advances one game day (web `E.tick`). Screens call it on a timer (web `DAY_MS` 1000 ms at 1×).

## GDScript pitfalls seen in this repo
- `var x := <expr>` fails to compile when `<expr>` is Variant-typed. Dictionary members, `max()`/`min()`, and `==` on Variants all count. Write `var x: float = ...` instead.
- Don't use `trait` as an identifier (reserved).
- Avoid multi-line lambdas inside call arguments. Use named methods plus `.bind()`.
- Constant dictionaries are read-only. Use `static var` for caches.

## Tests
`godot --headless --path godot -- --test=<name>` runs `tests/test_runner.gd`. Unknown names load `tests/<name>.gd` and call `run(r)`; `r.ok(cond, msg)` records failures and `r.shot(name)` saves screenshots (needs a renderer: `xvfb-run -a godot --rendering-driver opengl3 ...`). Check that scripts compile with `godot --headless --path godot --import`, then grep the output for `SCRIPT ERROR`.
