// Fixtures for the Godot career port (godot/tests/career_test.gd).
// Usage: node web/tools/career_fixtures.js [years=3] [seed=7]
// Writes godot/tests/fixtures/:
//   web_save.json / web_save_gg1.txt  a real web save after a seeded bot plays `years` seasons
//   tune_parity.json                  T.eval / T.raceSecs / T.crewTune / E.oddsRatio ... reference values
const fs = require('fs'), vm = require('vm'), path = require('path');
const YEARS = +(process.argv[2] || 3), SEED = +(process.argv[3] || 7);
const SRC = path.join(__dirname, '../src'), OUT = path.join(__dirname, '../../godot/tests/fixtures');

// seeded Math.random so fixtures are reproducible
const mulberry = s => () => { s = (s + 0x6D2B79F5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
const SM = Object.create(Math); SM.random = mulberry(SEED);
const ctx = {console, Math: SM, JSON, Object, Array, Set, Map, String, Number, Date};
vm.createContext(ctx);
const code = ['data.js', 'data2.js', 'util.js', 'tune.js', 'engine.js', 'build.js', 'race.js'].map(f => fs.readFileSync(path.join(SRC, f), 'utf8')).join('\n');
vm.runInContext(code + '\n;globalThis.D=D;globalThis.U=U;globalThis.E=E;globalThis.Race=Race;globalThis.T=T;globalThis.getG=()=>G;globalThis.setG=g=>{G=g;};', ctx);
const {D, U, E, Race, T} = ctx;
const clone = x => JSON.parse(JSON.stringify(x));

// ---------------- 1) a real save: the balance bot (web/test/bot.js) plays a few seasons ----------------
const pending = []; E.H.roundDue = id => pending.push(id);
E.newGame('Fixture Racing', D.TEAM_COLORS[2], 'standard'); let G = ctx.getG();
const FOCUS = ['CR', 'BO'];
const bestPair = race => { let best = null; for (const v of E.eligibleVehicles(race)) for (const s of E.eligibleDrivers()) { const o = E.oddsRatio(race, v, s); if (!best || o > best.o) best = {v, s, o}; } return best; };
const runRace = (rid, v, s, series) => { const def = D.RACE[rid]; const opts = {}; if (v.eng && v.eng.fuel !== 'none') T.crewTune(v, T.forecast(def), 0.97); if (series) { opts.series = series; opts.rivals = G.series[series].act.rivals; }
  const rs = Race.create(def, {vid: v.id, sid: s.id, tactic: 'normal'}, opts); Race.runInstant(rs); const out = E.finishRace(rs); if (series) E.seriesRoundDone(series, rs); return out; };
const clsFor = disc => D.DISC[disc].cls, terrNeed = disc => ({CR: 'on', BR: 'on', CO: 'off', BO: 'off', OP: 'off'})[disc];
function decide() {
  G = ctx.getG(); const W = E.ws();
  if (E.canUpgradeWS() && G.money > E.wsNeed().cost * 1.3) E.upgradeWS();
  while (G.spons.length < W.spon) { const o = E.sponsorOffers(); if (!o.length) break; E.signSponsor(o[0].id); }
  for (const disc of FOCUS) { const cls = clsFor(disc), tk = terrNeed(disc);
    const c = D.BODIES.filter(b => b.cls === cls && E.bodyAvail(b.id).ok && !G.res.body[b.id]).sort((a, b) => (b.s.spd + b.s.acc + b.s.hnd) * b.t[tk] - (a.s.spd + a.s.acc + a.s.hnd) * a.t[tk]);
    if (c[0] && G.rp >= c[0].rp) E.research('body', c[0].id); }
  for (const l of D.LAYOUTS) if (E.layoutAvail(l.id).ok && !G.res.layout[l.id] && G.rp >= l.rp + 30) E.research('layout', l.id);
  for (const p of D.PARTS.slice().sort((a, b) => b.tier - a.tier)) if (E.partAvail(p.id).ok && !G.res.part[p.id] && G.rp >= p.rp + 40) E.research('part', p.id);
  for (const m of E.mechs()) if (m.lv < 10 && G.rp >= E.mechLvCost(m) + 60) E.levelMech(m.id);
  const drv = E.drivers();
  for (const c of G.cand.slice()) { if (c.role === 'drv' && drv.length < W.teams + 1 && G.money > c.salary * 12) E.hire(c.id); if (c.role === 'mec' && E.mechs().length < W.mech && G.money > c.salary * 12) E.hire(c.id); }
  for (const disc of FOCUS) { const cls = clsFor(disc), tk = terrNeed(disc);
    const have = G.vehicles.filter(v => D.BODY[v.body].cls === cls && D.BODY[v.body].t[tk] >= 95);
    const b = D.BODIES.filter(b => b.cls === cls && G.res.body[b.id] && b.t[tk] >= 95).sort((a, b) => (b.s.spd + b.s.acc + b.s.hnd) - (a.s.spd + a.s.acc + a.s.hnd))[0]; if (!b) continue;
    const bh = have.map(v => D.BODY[v.body]).sort((x, y) => (y.s.spd + y.s.acc + y.s.hnd) - (x.s.spd + x.s.acc + x.s.hnd))[0]; if (bh && bh.id === b.id) continue;
    if (G.vehicles.length >= W.veh) { const old = G.vehicles.filter(v => v.status === 'ready' && D.BODY[v.body].cls === cls).sort((x, y) => D.BODY[x.body].cost - D.BODY[y.body].cost)[0]; if (old && G.money > E.vehCost(b.id, 'ff') * 2) E.scrap(old.id); else continue; }
    const ls = D.LAYOUTS.filter(l => l.cls === cls && G.res.layout[l.id]).sort((x, y) => { const sc = l => (l.m.spd || 0) + (l.m.acc || 0) + (l.m.hnd || 0) + (l.t[tk] || 0) * 1.2; return sc(y) - sc(x); });
    for (const l of ls) if (G.money > E.vehCost(b.id, l.id) * 1.4) { E.startBuild(b.id, l.id); break; } }
  for (const tc of D.TECH) if (!T.has(tc.id) && E.techAvail(tc.id).ok && G.rp >= tc.rp + 30) E.researchTech(tc.id);
  for (const v of G.vehicles) if (v.status === 'ready' && v.eng && v.eng.fuel !== 'none' && v.eng.cond < 0.45 && G.money > T.rebuildCost(v) * 2) E.startRebuild(v.id);
  for (const v of G.vehicles) { if (v.status !== 'ready') continue; const k = ['spd', 'acc', 'hnd', 'dur'].sort((a, b) => v.up[a] - v.up[b])[0];
    if (v.up[k] < 5 && G.money > E.upCost(v, k) * 2.5) { E.startUpgrade(v.id, k); continue; }
    const cls = D.BODY[v.body].cls; const cats = {}; for (const p of D.PARTS) if (G.res.part[p.id] && E.partClsOk(p, cls)) { if (!cats[p.cat] || p.tier > cats[p.cat].tier) cats[p.cat] = p; }
    for (const cat in cats) { const p = cats[cat]; if (v.parts.includes(p.id)) continue; const cur = v.parts.find(x => D.PART[x].cat === cat); if (cur && D.PART[cur].tier >= p.tier) continue; if (p.cat === 'tir') continue; if (G.money > E.partCost(p.id) * 3) E.installPart(v.id, p.id); } }
  for (const s of E.drivers()) { const best = D.TRAINING.filter(t => E.trainAvail(t.id) && t.cost > 0 && t.g.pedal).sort((a, b) => b.cost - a.cost)[0]; if (s.energy > 70 && best && G.money > best.cost * 6) E.train(s.id, best.id); }
  for (const f of ['dyno', 'gearbench', 'tunnel', 'gym', 'telemetry', 'lounge', 'fab', 'media', 'merch']) { if (!E.facAvail(f)) continue; const lv = E.facLv(f);
    if (!lv && G.fac.filter(Boolean).length < W.fac && G.money > D.FAC[f].cost[0] * 1000 * 4) E.buildFac(f); else if (lv && lv < 3 && G.money > D.FAC[f].cost[lv] * 1000 * 5) E.upgradeFac(f); }
  for (const S of D.SERIES) { if (!E.seriesState(S.id).ok) continue; const bp = bestPair(D.RACE[S.rounds[0]]); if (bp && bp.o >= 1.0 && G.money > S.fee * 2) E.enterSeries(S.id); }
  const opts = [];
  for (const r of D.RACES.filter(r => E.raceState(r.id).ok)) { const bp = bestPair(r); if (!bp || bp.s.energy < 45) continue; opts.push({r, bp, score: (bp.o >= 1.05 ? 2 : bp.o >= 0.95 ? 1 : 0) * 1e6 + r.prize * Math.min(1.3, bp.o)}); }
  opts.sort((a, b) => b.score - a.score);
  if (opts[0] && opts[0].bp.o >= 0.85) runRace(opts[0].r.id, opts[0].bp.v, opts[0].bp.s);
}
while (G.day < YEARS * D.DAYS_YEAR + 40) {
  E.tick(); G = ctx.getG();
  while (pending.length) { const id = pending.shift(); const a = G.series[id].act; const rid = D.SER[id].rounds[a.round]; const bp = bestPair(D.RACE[rid]); if (bp) runRace(rid, bp.v, bp.s, id); else E.seriesRoundSkip(id); }
  if (G.day % 4 === 0) decide();
}
// leave a staged build waiting on a decision so the save carries a mid-build job
E.H.buildAsk = () => {};
G.money += 2e6;
const bb = D.BODIES.find(b => b.cls === 'car' && G.res.body[b.id]); const bl = D.LAYOUTS.find(l => l.cls === 'car' && G.res.layout[l.id]);
if (G.vehicles.length >= E.ws().veh) E.sell(G.vehicles.find(v => v.status === 'ready').id);
G.jobs = G.jobs.filter(j => j.type !== 'build' || j.wait);
const bv = E.startBuild(bb.id, bl.id); for (let i = 0; i < 6; i++) E.tick();
fs.mkdirSync(OUT, {recursive: true});
const save = E.serialize();
fs.writeFileSync(path.join(OUT, 'web_save.json'), save);
fs.writeFileSync(path.join(OUT, 'web_save_gg1.txt'), 'GG1:' + Buffer.from(save, 'utf8').toString('base64'));
const summary = {day: G.day, ws: G.ws, money: G.money, rp: G.rp, fans: G.fans, wins: G.st.wins, races: G.st.races, titles: G.st.titles.slice(), vehicles: G.vehicles.map(v => v.body + ':' + v.status),
  score: E.score(), availRaceIds: E.availRaceIds(), standings: Object.fromEntries(Object.keys(G.series).filter(k => G.series[k].act).map(k => [k, E.standings(k)])), buildVid: bv && bv.id};

// ---------------- 2) Tune / odds parity ----------------
const RACES = ['h4b', 'r2a', 'd1c', 'o3c', 'b3c', 'o1c'].filter(id => D.RACE[id]);
const pick = ev => ev && {lam: ev.lam, ef: ev.ef, kd: ev.kd, lh: ev.lh, pf: ev.pf, tf: ev.tf, imb: ev.imb, starve: !!ev.starve, flood: !!ev.flood, foul: !!ev.foul, seize: !!ev.seize, cells: ev.cells};
function vehCase(v) {
  const e = v.eng, c = {vid: v.id, need: T.need(v), ideal: T.evalIdeal(v), evals: [], races: []};
  if (e && e.fuel === 'carb') c.carbRich = T.carbRich(v);
  if (e && e.fuel === 'efi') c.trueVE = T.trueVE(v);
  const shop = T.SHOP(); const ev0 = T.eval(v, shop); c.evals.push({cond: shop, rho: null, ev: pick(ev0)});
  const hc = T.forecast(D.RACE.h4b); c.evals.push({cond: hc, rho: hc.rho2, ev: pick(T.eval(v, hc, hc.rho2))});
  c.symptoms = T.symptoms(ev0, !!(e && e.fuel === 'efi'));
  c.plug = T.plug(ev0.lam.wot); c.zoneLabel = T.zoneLabel(ev0.lam.mid, 'mid');
  for (const rid of RACES) { const def = D.RACE[rid]; const tr = Race.track(def, false); const cond = T.forecast(def);
    const rsx = T.raceSecs(v, def, tr, cond);
    c.races.push({rid, cond, secs: rsx.secs, foul: !!rsx.foul, seize: !!rsx.seize,
      odds: E.drivers().map(s => ({sid: s.id, o: E.oddsRatio(def, v, s)}))}); }
  if (e && e.fuel !== 'none') { const vc = clone(v); const cond = T.forecast(D.RACE.p3b); T.crewTune(vc, cond, 1); c.crew = {cond, eng: vc.eng}; }
  return c;
}
const groups = [];
groups.push({name: 'web save', G: JSON.parse(save), cases: G.vehicles.filter(v => v.status !== 'build').map(vehCase)});

// synthetic garage: every carb type, EFI car/bike, two-stroke, electric, with lean/rich/knock/float extremes
function synth(name, mode, techs) {
  E.newGame('Synth ' + name, D.TEAM_COLORS[1], mode); G = ctx.getG(); G.money = 1e10; G.ws = 4; G.day = 500;
  G.tech = {carbbasic: 1}; for (const t of techs === 'all' ? D.TECH.map(t => t.id) : techs) G.tech[t] = 1;
  for (const b of D.BODIES) G.res.body[b.id] = 1; for (const l of D.LAYOUTS) G.res.layout[l.id] = 1; for (const p of D.PARTS) G.res.part[p.id] = 1;
  const specs = [
    ['kei', 'fr', null, {}], ['rallyevo', 'awd', {type: 'efi'}, {parts: ['turbo', 'sportexh'], fuelT: 'e85'}], ['ss600', 'inline4', {type: 'carb', carb: 'cv'}, {jets: {main: 140, pilot: 35}, sync: true}],
    ['dirt250', 'stroke2', {type: 'carb', carb: 'pwk'}, {jets: {main: 105, float: -2}}], ['cafe', 'triple', {type: 'carb', carb: 'fcr'}, {jets: {float: 2, pump: 60}, timing: 6, flags: ['rev']}],
    ['gt', 'fr', {type: 'carb', carb: 'q4'}, {parts: ['nitrous', 'twinturbo'], fuelT: 'race', timing: 8}], ['coupe', 'fr', {type: 'carb', carb: 'dcoe'}, {jets: {airc: 220, main: 150}, flags: ['torque']}],
    ['sport3', 'elec', null, {}], ['sbk', 'inline4', {type: 'efi'}, {parts: ['bigbore'], efiScale: 1.15, ae: 60}], ['trail', 'single', null, {jets: {pilot: 27.5, screw: 3}, setup: {f: 14, r: 52, susp: 2, psi: 10}}],
    ['formula', 'mr', {type: 'carb', carb: 'd2'}, {setup: {fd: 4.3, susp: 9, psi: 36, wing: 12}, cond: 0.55}],
  ];
  const out = [];
  for (const [bid, lid, sys, o] of specs) {
    if (sys && sys.type === 'efi' && !T.has('efi')) continue; if (sys && sys.carb && !T.carbAvail(sys.carb)) continue;
    const v = E.startBuild(bid, lid, null, sys); if (!v) continue; G.jobs = G.jobs.filter(j => j.vid !== v.id); E.finishBuild(v);
    v.parts = o.parts || []; if (o.flags) v.bflags = v.bflags.concat(o.flags);
    if (o.fuelT) v.eng.fuelT = o.fuelT; if (o.timing) v.eng.timing = o.timing; if (o.cond) v.eng.cond = o.cond;
    if (o.jets) Object.assign(v.eng.jets, o.jets); if (o.setup) Object.assign(v.setup, o.setup);
    if (o.sync) v.eng.sync = v.eng.sync.map((x, i) => i === T.syncBase(v.eng.sync.length) ? 0 : +(x + 0.9 * (i % 2 ? 1 : -1)).toFixed(1));
    if (o.efiScale && v.eng.efi) v.eng.efi.ve = v.eng.efi.ve.map(r => r.map(x => Math.round(x * o.efiScale)));
    if (o.ae && v.eng.efi) v.eng.efi.ae = o.ae;
    out.push(v);
  }
  // fresh engines straight from T.initEng (sync + base maps are seeded by vehicle id)
  const inits = [];
  for (const [id, bid, lid, sys] of [[901, 'ss600', 'inline4', null], [902, 'rallyevo', 'awd', {type: 'efi'}], [903, 'sbk', 'inline4', {type: 'efi'}], [904, 'cafe', 'triple', {type: 'carb', carb: 'fcr'}], [905, 'coupe', 'fr', {type: 'carb', carb: 'dcoe'}]]) {
    const v = {id, body: bid, layout: lid, parts: [], bflags: []}; T.initEng(v, sys); inits.push({v: {id, body: bid, layout: lid, parts: [], bflags: []}, sys, eng: clone(v.eng)}); }
  groups.push({name, G: JSON.parse(E.serialize()), cases: out.map(vehCase), inits,
    forecast: ['c1a', 'h4b', 'o3c', 'r4b', 'l5c'].map(id => [0, 13, 200, 777, 3000].map(day => ({rid: id, day, f: T.forecast(D.RACE[id], day)})))});
}
synth('all tech', 'standard', 'all');
synth('no tech sim', 'sim', ['efi', 'carb4', 'pwk', 'fcr', 'dcoe']);
synth('easy', 'easy', ['efi', 'mapsens', 'gearing', 'adjsus', 'tirepress', 'aero', 'launch', 'porting']);
E.load(save); summary.webReload = E.serialize(); // what the web itself writes after loading the save (resets job.asked)
fs.writeFileSync(path.join(OUT, 'tune_parity.json'), JSON.stringify({groups, saveSummary: summary}));
console.log('web save: day', summary.day, 'ws', summary.ws, 'money', summary.money, 'wins', summary.wins + '/' + summary.races, 'titles', summary.titles.join(','), 'vehicles', summary.vehicles.join(' '));
console.log('parity groups:', groups.map(g => `${g.name}: ${g.cases.length} vehicles`).join('; '), '| save bytes', save.length);
