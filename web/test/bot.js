// Headless balance bot: plays the game greedily and reports progression per year.
const fs=require('fs'),vm=require('vm'),path=require('path');
const ctx={console,Math,JSON,Object,Array,Set,Map,String,Number,Date};vm.createContext(ctx);
const code=['data.js','data2.js','util.js','tune.js','engine.js','race.js'].map(f=>fs.readFileSync(path.join(__dirname,'../src',f),'utf8')).join('\n');vm.runInContext(code+'\n;globalThis.D=D;globalThis.U=U;globalThis.E=E;globalThis.Race=Race;globalThis.T=T;globalThis.getG=()=>G;',ctx,{filename:'game.js'});
const {D,U,E,Race,T}=ctx;
const FOCUS=(process.argv[2]||'CR,BO').split(',');
const YEARS=+(process.argv[3]||15);
const pending=[];E.H.roundDue=id=>pending.push(id);
let destroyed=0;
E.newGame('Bot',D.TEAM_COLORS[0]);let G=ctx.getG();
const log=[];
function bestPair(race){let best=null;
  for(const v of E.eligibleVehicles(race))for(const s of E.eligibleDrivers()){const o=E.oddsRatio(race,v,s);if(!best||o>best.o)best={v,s,o};}return best;}
function runRace(rid,v,s,series){const def=D.RACE[rid];const opts={};if(v.eng&&v.eng.fuel!=='none')T.crewTune(v,T.forecast(def),0.97);if(series){opts.series=series;opts.rivals=G.series[series].act.rivals;}
  const rs=Race.create(def,{vid:v.id,sid:s.id,tactic:'normal'},opts);Race.runInstant(rs);const out=E.finishRace(rs);if(rs.player.destroyed)destroyed++;
  if(series)E.seriesRoundDone(series,rs);return out;}
function clsFor(disc){return D.DISC[disc].cls;}
function terrNeed(disc){return {CR:'on',BR:'on',CO:'off',BO:'off',OP:'off'}[disc];}
function decide(){
  G=ctx.getG();const W=E.ws();
  // workshop
  if(E.canUpgradeWS()&&G.money>E.wsNeed().cost*1.3)E.upgradeWS();
  // sponsors
  while(G.spons.length<W.spon){const o=E.sponsorOffers();if(!o.length)break;E.signSponsor(o[0].id);}
  // research bodies for focus
  for(const disc of FOCUS){const cls=clsFor(disc),tk=terrNeed(disc);
    const cands=D.BODIES.filter(b=>b.cls===cls&&E.bodyAvail(b.id).ok&&!G.res.body[b.id]).sort((a,b)=>(b.s.spd+b.s.acc+b.s.hnd)*b.t[tk]-(a.s.spd+a.s.acc+a.s.hnd)*a.t[tk]);
    if(cands[0]&&G.rp>=cands[0].rp)E.research('body',cands[0].id);}
  for(const l of D.LAYOUTS)if(E.layoutAvail(l.id).ok&&!G.res.layout[l.id]&&G.rp>=l.rp+30)E.research('layout',l.id);
  for(const p of D.PARTS.slice().sort((a,b)=>b.tier-a.tier))if(E.partAvail(p.id).ok&&!G.res.part[p.id]&&G.rp>=p.rp+40)E.research('part',p.id);
  // mech levels
  for(const m of E.mechs())if(m.lv<10&&G.rp>=E.mechLvCost(m)+60)E.levelMech(m.id);
  // hire
  const drv=E.drivers(),mec=E.mechs();
  for(const c of G.cand.slice()){if(c.role==='drv'&&drv.length<W.teams+1&&G.money>c.salary*12)E.hire(c.id);
    if(c.role==='mec'&&E.mechs().length<W.mech&&G.money>c.salary*12)E.hire(c.id);}
  // replace weak mech
  const wm=E.mechs().sort((a,b)=>a.tech-b.tech)[0];const bc=G.cand.filter(c=>c.role==='mec').sort((a,b)=>b.tech-a.tech)[0];
  if(wm&&bc&&bc.tech>wm.tech*1.6&&G.money>bc.salary*15){E.fire(wm.id);E.hire(bc.id);}
  // build
  for(const disc of FOCUS){const cls=clsFor(disc),tk=terrNeed(disc);
    const have=G.vehicles.filter(v=>D.BODY[v.body].cls===cls&&D.BODY[v.body].t[tk]>=95);
    const bodies=D.BODIES.filter(b=>b.cls===cls&&G.res.body[b.id]&&b.t[tk]>=95).sort((a,b)=>(b.s.spd+b.s.acc+b.s.hnd)-(a.s.spd+a.s.acc+a.s.hnd));
    const b=bodies[0];if(!b)continue;
    const bestHave=have.map(v=>D.BODY[v.body]).sort((x,y)=>(y.s.spd+y.s.acc+y.s.hnd)-(x.s.spd+x.s.acc+x.s.hnd))[0];
    if(bestHave&&bestHave.id===b.id)continue;
    if(G.vehicles.length>=W.veh){const old=G.vehicles.filter(v=>v.status==='ready'&&D.BODY[v.body].cls===cls).sort((x,y)=>D.BODY[x.body].cost-D.BODY[y.body].cost)[0];if(old&&G.money>E.vehCost(b.id,'ff')*2)E.scrap(old.id);else continue;}
    const ls=D.LAYOUTS.filter(l=>l.cls===cls&&G.res.layout[l.id]).sort((x,y)=>{const sc=l=>(l.m.spd||0)+(l.m.acc||0)+(l.m.hnd||0)+(l.t[tk]||0)*1.2;return sc(y)-sc(x);});
    for(const l of ls){if(G.money>E.vehCost(b.id,l.id)*1.4){E.startBuild(b.id,l.id);break;}}
  }
  // tech & engine care
  for(const tc of D.TECH)if(!T.has(tc.id)&&E.techAvail(tc.id).ok&&G.rp>=tc.rp+30)E.researchTech(tc.id);
  for(const v of G.vehicles)if(v.status==='ready'&&v.eng&&v.eng.fuel!=='none'&&v.eng.cond<0.45&&G.money>T.rebuildCost(v)*2)E.startRebuild(v.id);
  // upgrades & parts
  for(const v of G.vehicles){if(v.status!=='ready')continue;const k=['spd','acc','hnd','dur'].sort((a,b)=>v.up[a]-v.up[b])[0];
    if(v.up[k]<5&&G.money>E.upCost(v,k)*2.5){E.startUpgrade(v.id,k);continue;}
    const cls=D.BODY[v.body].cls;const cats={};for(const p of D.PARTS)if(G.res.part[p.id]&&E.partClsOk(p,cls)){if(!cats[p.cat]||p.tier>cats[p.cat].tier)cats[p.cat]=p;}
    for(const cat in cats){const p=cats[cat];if(v.parts.includes(p.id))continue;const cur=v.parts.find(x=>D.PART[x].cat===cat);if(cur&&D.PART[cur].tier>=p.tier)continue;
      if(p.cat==='tir'){continue;}
      if(G.money>E.partCost(p.id)*3)E.installPart(v.id,p.id);}
  }
  // training
  for(const s of E.drivers()){const ts=D.TRAINING.filter(t=>E.trainAvail(t.id)&&t.cost>0).sort((a,b)=>U.sum(Object.values(b.g))/b.cost-U.sum(Object.values(a.g))/a.cost);
    const best=D.TRAINING.filter(t=>E.trainAvail(t.id)&&t.cost>0&&t.g.pedal).sort((a,b)=>b.cost-a.cost)[0];
    if(s.energy>70&&best&&G.money>best.cost*6)E.train(s.id,best.id);}
  // facilities
  for(const f of ['dyno','gearbench','tunnel','gym','telemetry','lounge','fab','media','merch']){if(!E.facAvail(f))continue;const lv=E.facLv(f);
    if(!lv&&G.fac.filter(Boolean).length<W.fac&&G.money>D.FAC[f].cost[0]*1000*4)E.buildFac(f);else if(lv&&lv<3&&G.money>D.FAC[f].cost[lv]*1000*5)E.upgradeFac(f);}
  // series
  for(const S of D.SERIES){if(!E.seriesState(S.id).ok)continue;const r=D.RACE[S.rounds[0]];const bp=bestPair(r);if(bp&&bp.o>=1.0&&G.money>S.fee*2)E.enterSeries(S.id);}
  // races
  const avail=D.RACES.filter(r=>E.raceState(r.id).ok);let options=[];
  for(const r of avail){const bp=bestPair(r);if(!bp||bp.s.energy<45)continue;options.push({r,bp,score:(bp.o>=1.05?2:bp.o>=0.95?1:0)*1e6+r.prize*Math.min(1.3,bp.o)});}
  options.sort((a,b)=>b.score-a.score);
  if(options[0]&&options[0].bp.o>=0.85)runRace(options[0].r.id,options[0].bp.v,options[0].bp.s);
}
const yr=[];let lastY=1;let lastTitles=0;
const MAXD=YEARS*D.DAYS_YEAR;
while(G.day<MAXD){
  E.tick();G=ctx.getG();
  while(pending.length){const id=pending.shift();const a=G.series[id].act;const rid=D.SER[id].rounds[a.round];const bp=bestPair(D.RACE[rid]);
    if(bp)runRace(rid,bp.v,bp.s,id);else E.seriesRoundSkip(id);}
  if(G.day%4===0)decide();
  if(E.year()!==lastY){lastY=E.year();
    const tiers=[1,2,3,4,5].map(t=>D.RACES.filter(r=>r.tier===t&&!r.excl&&E.best(r.id)===1).length);
    const newT=G.st.titles.slice(lastTitles);lastTitles=G.st.titles.length;yr.push(`Y${lastY-1}: newTitles[${newT.join(',')}] ws${G.ws} $${(G.money/1e6).toFixed(2)}M rp${G.rp} fans${G.fans} wins${G.st.wins}/${G.st.races} tierWins${JSON.stringify(tiers)} veh:${G.vehicles.map(v=>v.body+'L'+v.lv).join(',')} drvPed:${E.drivers().map(d=>d.pedal).join('/')} tech${Math.round(E.teamTech())} destroyed${destroyed}`);}
}
console.log(yr.join('\n'));
console.log('score',E.score(),'saveBytes',E.serialize().length);
