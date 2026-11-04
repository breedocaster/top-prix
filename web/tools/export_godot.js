// Export the web build's game data to the Godot project so both share one source of truth.
// Usage: node web/tools/export_godot.js
// Writes godot/data/game_data.json and godot/tests/fixtures/parity.json (JS reference values for the GDScript port).
const fs = require('fs'), vm = require('vm'), path = require('path');
const SRC = path.join(__dirname, '../src');
const OUT = path.join(__dirname, '../../godot');
const ctx = {console, Math, JSON, Object, Array, Set, Map, String, Number, Date};
vm.createContext(ctx);
const files = ['data.js', 'data2.js', 'util.js', 'tune.js', 'engine.js', 'build.js', 'race.js'];
const code = files.map(f => fs.readFileSync(path.join(SRC, f), 'utf8')).join('\n');
vm.runInContext(code + '\n;globalThis.D=D;globalThis.U=U;globalThis.E=E;globalThis.Race=Race;globalThis.T=T;globalThis.getG=()=>G;globalThis.setG=g=>{G=g;};', ctx);
const {D, U, E, Race, T} = ctx;

// ---- game data ----
const data = JSON.parse(JSON.stringify(D)); // drops functions
data.FORMATS = {}; data.CONDS = {};
for (const r of D.RACES) { data.FORMATS[r.id] = D.formats(r); data.CONDS[r.id] = D.condOf(r); }
data.SECZ = T.SECZ;
data.TRACK_LEN = Race.LEN;
data.TAC = Race.TAC;
data.KINDS = Race.KINDS;
data._meta = {source: 'web/src via web/tools/export_godot.js', exported: new Date().toISOString().slice(0, 10)};
fs.mkdirSync(path.join(OUT, 'data'), {recursive: true});
fs.writeFileSync(path.join(OUT, 'data/game_data.json'), JSON.stringify(data));

// ---- parity fixtures ----
// 1) seeded RNG + hash
const rng = U.seeded(U.hash('c1a'));
const rngSeq = [U.hash('c1a'), U.hash('h4x2'), rng(), rng(), rng()];
// 2) generated tracks
const tracks = {};
for (const id of ['c1a', 'c2c', 'o1b', 'o1c', 'd1b', 'h1a', 'r1a', 'l5c'].filter(i => D.RACE[i])) {
  const t = Race.track(D.RACE[id], false);
  tracks[id] = {lapLen: t.lapLen, laps: t.laps, secs: t.secs.map(s => [s.type, s.len, s.at, s.surf])};
}
// 3) vehicle profiles from a fresh game with a couple of builds
E.newGame('Parity', '#e04040', 'standard');
const G = ctx.getG();
G.money = 1e9;
const prof = {};
const mk = (bid, lid) => {
  const b = D.BODY[bid]; if (!b) return null;
  G.res.body[bid] = 1; G.res.layout[lid] = 1;
  const v = E.startBuild(bid, lid); if (!v) return null;
  G.jobs = G.jobs.filter(j => j.vid !== v.id); E.finishBuild(v); return v;
};
const s0 = G.staff.find(s => s.role === 'driver') || G.staff[0];
for (const [bid, lid] of [['kei', 'fr'], [D.BODIES.find(b => b.cls === 'bike').id, D.LAYOUTS.find(l => l.cls === 'bike').id]]) {
  const v = mk(bid, lid); if (!v) continue;
  const p = E.profile(v, s0);
  const tr = Race.track(D.RACE.c1a, false);
  const rsx = T.raceSecs(v, D.RACE.c1a, tr, T.SHOP(), true);
  prof[v.id] = {veh: JSON.parse(JSON.stringify(v)), staff: JSON.parse(JSON.stringify(s0)), profile: p, secs0: rsx.secs[0], vs: E.vs(v)};
}
fs.mkdirSync(path.join(OUT, 'tests/fixtures'), {recursive: true});
fs.writeFileSync(path.join(OUT, 'tests/fixtures/parity.json'), JSON.stringify({rngSeq, tracks, prof, partLv: G.partLv, tech: G.tech}, null, 1));
console.log('exported', Object.keys(data).length, 'tables;', D.RACES.length, 'races;', D.BODIES.length, 'bodies; fixtures:', Object.keys(tracks).length, 'tracks,', Object.keys(prof).length, 'profiles');
