// ===================== STAGED BUILD PROCESS =====================
D.BPH = ['design','frame','engine','drive','susp','body','elec','shake'];
D.BPHN = {design:'Design & concept',frame:'Frame / chassis',engine:'Engine assembly',drive:'Drivetrain',susp:'Suspension & brakes',body:'Bodywork & aero',elec:'Electrics & fuel',shake:'Shakedown'};
D.BPHS = {design:'DESIGN',frame:'FRAME',engine:'ENGINE',drive:'DRIVE',susp:'SUSP',body:'BODY',elec:'WIRING',shake:'SHAKEDOWN'};
D.BUILD_MULT = 3.5;
// option: {id,n,d,cost(frac of body cost),days,m:{%},t:{terr},adv,slot,flag,req:{ws,tech,fac,q},crew}
D.BOPT = {
 design:[
  {id:'bal',n:'Balanced concept',d:'A little of everything.',m:{spd:2,acc:2,hnd:2},crew:1},
  {id:'speed',n:'Top-speed concept',d:'Slippery and long-legged.',m:{spd:6,hnd:-2}},
  {id:'accel',n:'Punchy concept',d:'Light and eager off the line.',m:{acc:6,spd:-2}},
  {id:'handle',n:'Corner-carver concept',d:'Tight wheelbase, quick steering.',m:{hnd:6,spd:-2}},
  {id:'tough',n:'Built-to-last concept',d:'Overbuilt everywhere.',m:{dur:10,acc:-2}},
 ],
 frame:{
  car:[{id:'mild',n:'Mild-steel tube frame',d:'Cheap and tough, a bit heavy.',cost:-0.04,m:{dur:8,acc:-3}},
       {id:'cromo',n:'Chromoly cage frame',d:'Stiff, strong, fair weight.',cost:0.08,m:{dur:4,hnd:3},crew:1},
       {id:'alu',n:'Aluminum chassis',d:'Light and nimble, less forgiving.',cost:0.15,days:1,m:{acc:5,hnd:4,dur:-5}},
       {id:'carbon',n:'Carbon tub',d:'Race-car stiffness and weight.',cost:0.35,days:3,m:{acc:8,hnd:6,dur:2},req:{ws:3}}],
  bike:[{id:'cradle',n:'Steel double cradle',d:'Old-school and bulletproof.',cost:-0.04,m:{dur:8,hnd:-2}},
       {id:'trellis',n:'Steel trellis',d:'Flexes just right. Great feel.',cost:0.06,m:{hnd:4,dur:3},crew:1},
       {id:'perim',n:'Aluminum perimeter',d:'Stiff and light, harsh on rough ground.',cost:0.15,days:1,m:{hnd:6,acc:3,dur:-4},t:{off:-4}},
       {id:'carbon',n:'Carbon monocoque',d:'Factory-team exotic.',cost:0.35,days:3,m:{hnd:8,acc:6},req:{ws:3}}],
 },
 engine:{
  ice:[{id:'stock',n:'Factory tolerances',d:'Bolt it together and move on.',days:-2,m:{}},
       {id:'blue',n:'Blueprinted & balanced',d:'Every clearance measured. Needs a skilled crew.',cost:0.06,days:3,m:{spd:3,acc:3,dur:3},req:{q:0.9},crew:1},
       {id:'rev',n:'High-rev build',d:'Lighter internals, screams up top. Wants a bigger main jet.',cost:0.08,days:1,m:{spd:6,acc:-1,dur:-6},flag:'rev'},
       {id:'torque',n:'Torque build',d:'Fat midrange for exits and hills.',cost:0.05,m:{acc:6,spd:-2},flag:'torque'},
       {id:'endur',n:'Endurance build',d:'Conservative and long-lived. Engine wears 30% slower.',cost:0.04,m:{dur:8,spd:-2},flag:'endur'}],
  elec:[{id:'std',n:'Standard battery pack',d:'Proven cells.',m:{},crew:1},
       {id:'hd',n:'High-discharge pack',d:'Brutal launches, runs hot.',cost:0.08,m:{acc:7,dur:-5}},
       {id:'lr',n:'Long-life cells',d:'Cool and steady.',cost:0.04,m:{dur:8,acc:-2}}],
 },
 drive:{
  car:[{id:'close',n:'Close-ratio gearbox',d:'Stays on the boil.',m:{acc:5,spd:-2},crew:1},
       {id:'wide',n:'Tall overdrive box',d:'For long straights.',m:{spd:5,acc:-2}},
       {id:'hd',n:'Heavy-duty diff & axles',d:'Shrugs off abuse.',cost:0.04,m:{dur:8}},
       {id:'lsd',n:'Limited-slip diff',d:'Puts power down on loose and wet surfaces.',cost:0.07,days:1,m:{hnd:3},t:{off:6,wet:6}}],
  bike:[{id:'o520',n:'520 O-ring chain',d:'Strong and sealed.',m:{dur:6},crew:1},
       {id:'l428',n:'Lightweight 428 chain & sprockets',d:'Less rotating mass, wears faster.',m:{acc:4,dur:-4}},
       {id:'shaft',n:'Shaft drive',d:'Zero maintenance, heavy.',cost:0.08,days:1,m:{dur:12,acc:-3}},
       {id:'close',n:'Close-ratio gearbox',d:'Tight gear spacing.',cost:0.04,m:{acc:5,spd:-2}}],
 },
 susp:[
  {id:'all',n:'All-rounder setup',d:'Works everywhere, excels nowhere.',t:{on:3,off:3,wet:3},crew:1},
  {id:'tar',n:'Tarmac spec',d:'Stiff springs, big brakes.',m:{hnd:5},t:{on:8,off:-8}},
  {id:'dirt',n:'Long-travel dirt spec',d:'Soaks up whoops and landings.',m:{hnd:2,dur:4},t:{off:10,on:-6}},
  {id:'rain',n:'Rain & ice package',d:'Soft compliance, ABS-style brakes.',m:{hnd:1},t:{wet:8,ice:8}},
  {id:'race',n:'Fully adjustable race kit',d:'Pro-level dampers.',cost:0.1,days:2,m:{hnd:7},req:{tech:'adjsus'}},
 ],
 body:{
  car:[{id:'kit',n:'Aero body kit',d:'Splitter, skirts, wing mounts.',cost:0.07,days:1,m:{spd:4,hnd:3},t:{off:-4},crew:1},
       {id:'bare',n:'Stripped & light',d:'Gutted interior, thin panels.',m:{acc:4,dur:-4},adv:-5},
       {id:'armor',n:'Rally armor & skid plates',d:'Built for rocks.',cost:0.05,m:{dur:10},t:{off:5}},
       {id:'show',n:'Show-quality paint',d:'Sponsors love it.',cost:0.05,days:2,adv:15}],
  bike:[{id:'fairing',n:'Full race fairing',d:'Tuck in and fly.',cost:0.07,days:1,m:{spd:5},crew:1},
       {id:'naked',n:'Naked & stripped',d:'Nothing extra.',m:{acc:4}},
       {id:'plastics',n:'MX plastics & guards',d:'Crash-friendly.',cost:0.03,m:{dur:6},t:{off:5}},
       {id:'show',n:'Show-quality paint',d:'Chrome and candy paint.',cost:0.05,days:2,adv:15}],
 },
 elec:[
  {id:'basic',n:'Simple harness',d:'Fewer things to break... in theory.',days:-1,crew:1},
  {id:'race',n:'Race loom, sealed connectors',d:'Engine wear -15%.',cost:0.04,m:{dur:4},flag:'loom'},
  {id:'data',n:'Data-logging loom',d:'Logs a datalog every race. +10% research data.',cost:0.06,days:1,flag:'data'},
  {id:'slot',n:'Expandable harness',d:'+1 part slot.',cost:0.05,days:1,slot:1},
 ],
 shake:[
  {id:'quick',n:'Quick shakedown',d:'Roll it out and call it done.',days:-2},
  {id:'full',n:'Full test day',d:'Finds and fixes the worst flaw.',cost:0.02,days:3,flag:'full',crew:1},
  {id:'dyno',n:'Dyno-tune before delivery',d:'Crew jets/maps the engine on the shop dyno.',cost:0.03,days:2,flag:'dyno',req:{fac:'dyno'}},
 ],
};
// random shop events
D.BEV = [
 {id:'crack',n:'Cracked weld!',d:'{m} spots a hairline crack in a frame weld.',o:[{n:'Re-weld it properly',days:3},{n:'Gusset it and move on',m:{dur:-4}}]},
 {id:'bolts',n:'Lightweight hardware',d:'A supplier offers titanium bolts at a discount.',o:[{n:'Buy them',cost:0.03,m:{acc:2,hnd:1}},{n:'No thanks'}]},
 {id:'idea',n:'Bright idea',d:'{m} wants to try a trick port shape on the intake.',o:[{n:'Try it (gamble)',gamble:{p:0.6,win:{spd:4,acc:2},lose:{spd:-2}}},{n:'Stick to the plan'}],ice:1},
 {id:'backorder',n:'Parts on backorder',d:'The next batch of parts is stuck at the warehouse.',o:[{n:'Wait it out',days:4},{n:'Pay to expedite',cost:0.04,min:5000}]},
 {id:'fitting',n:'Seat fitting',d:'{d} asks to sit in for a custom fitting.',o:[{n:'Sure, come in',m:{hnd:3},drv:1},{n:'Not right now'}]},
 {id:'wrong',n:'Wrong part delivered',d:'The box has the wrong part number on it.',o:[{n:'Send it back',days:2},{n:'Make it fit',gamble:{p:0.35,win:{hnd:3},lose:{dur:-3}}}]},
 {id:'press',n:'Press visit',d:'A racing magazine wants to photograph the build.',o:[{n:'Smile for the camera',days:1,fans:1},{n:'Not now'}]},
 {id:'bin',n:'Treasure in the parts bin',d:'{m} finds a race-spec bit in the parts bin.',o:[{n:'Fit it',m:{rand:3}},{n:'Sell it',money:0.03}]},
 {id:'weekend',n:'Weekend overtime',d:'The crew offers to work through the weekend.',o:[{n:'Pay overtime',cost:0.03,min:3000,days:-3},{n:'Let them rest'}]},
 {id:'logo',n:'Sponsor request',d:'{s} wants their logo bigger on this one.',o:[{n:'Make it huge',adv:8,money:0.02},{n:'Keep it classy'}],spon:1},
 {id:'leak',n:'Weeping gasket',d:'{m} finds a weeping gasket on the test fire.',o:[{n:'Pull it apart and replace it',days:2},{n:'Sealant and pray',gamble:{p:0.5,win:{},lose:{dur:-5}}}],ice:1},
];
D.BEVM = Object.fromEntries(D.BEV.map(e=>[e.id,e]));

// ---------- logic ----------
E.bOpts = (v,ph)=>{const b=D.BODY[v.body];const o=D.BOPT[ph];if(Array.isArray(o))return o;if(ph==='engine')return D.LAYOUT_CYL[v.layout]===0?o.elec:o.ice;return o[b.cls];};
E.bCost = (o,v)=>{if(!o.cost)return 0;const c=Math.round(o.cost*D.BODY[v.body].cost/1000)*1000;return o.min?Math.sign(c)*Math.max(Math.abs(c),o.min):c;};
E.bReq = (o,v)=>{const r=o.req||{};if(r.ws&&G.ws<r.ws)return{ok:false,why:`Needs ${D.WORKSHOPS[r.ws].n}`};if(r.tech&&!T.has(r.tech))return{ok:false,why:`Tech: ${D.TECHM[r.tech].n}`};
  if(r.fac&&!E.facLv(r.fac))return{ok:false,why:`Needs ${D.FAC[r.fac].n}`};if(r.q&&E.buildQ(v.body)<r.q)return{ok:false,why:`Team skill ${Math.round(E.buildQ(v.body)*100)}% (need ${Math.round(r.q*100)}%)`};
  const c=E.bCost(o,v);if(c>0&&G.money<c)return{ok:false,why:'Not enough money'};return{ok:true};};
E.bFx = (o,v)=>{const a=[];const m=o.m||{};for(const k in m){if(k==='rand'){a.push(`random stat +${m[k]}%`);continue;}a.push(`${k.toUpperCase()} ${m[k]>0?'+':''}${m[k]}%`);}
  for(const k in(o.t||{}))a.push(`${D.TERR_N[k]} ${o.t[k]>0?'+':''}${o.t[k]}`);if(o.adv)a.push(`Ad appeal ${o.adv>0?'+':''}${o.adv}`);if(o.slot)a.push('+1 part slot');
  if(o.gamble){const w=Object.entries(o.gamble.win).map(([k,x])=>`${k.toUpperCase()} +${x}%`).join(' ');a.push(`${Math.round(o.gamble.p*100)}%: ${w||'fine'}`);}
  const c=E.bCost(o,v);if(c)a.push(c>0?U.money(c):`saves ${U.money(-c)}`);if(o.money)a.push('+'+U.money(Math.round(o.money*D.BODY[v.body].cost/1000)*1000));
  if(o.days)a.push(`${o.days>0?'+':''}${o.days} days`);if(o.fans)a.push('+fans');return a.join(' · ');};
E.bJob = vid=>G.jobs.find(j=>j.vid===vid&&j.type==='build');
E.bMerge = (v,o,scale=1)=>{const bm=v.bm=v.bm||{spd:0,acc:0,hnd:0,dur:0,on:0,off:0,wet:0,ice:0,adv:0};
  for(const k in(o.m||{})){if(k==='rand'){const kk=U.pick(['spd','acc','hnd','dur']);bm[kk]+=o.m.rand;continue;}bm[k]+=o.m[k]*scale;}
  for(const k in(o.t||{}))bm[k]+=o.t[k];if(o.adv)bm.adv+=o.adv;if(o.slot)v.slotB=(v.slotB||0)+o.slot;if(o.flag){v.bflags=v.bflags||[];v.bflags.push(o.flag);}};
E.bWaitNext = (j,v)=>{
  const ph=D.BPH[j.pi];
  if(j.pi>=1&&(j.evN||0)<3&&U.chance(0.3)){let pool=D.BEV.filter(e=>!(j.evs||[]).includes(e.id)&&(!e.ice||D.LAYOUT_CYL[v.layout]!==0)&&(!e.spon||G.spons.length));
    if(pool.length){const e=U.pick(pool);j.evs=(j.evs||[]).concat(e.id);j.evN=(j.evN||0)+1;
      const mech=U.pick(E.mechs())||{name:'The crew'},drv=U.pick(E.drivers())||{name:'Your driver'},sp=G.spons.length?D.SPON[U.pick(G.spons).id].n:'';
      j.wait={k:'ev',ev:e.id,txt:e.d.replace('{m}',mech.name).replace('{d}',drv.name).replace('{s}',sp),drv:drv.id,next:ph};j.asked=false;return;}}
  j.wait={k:'ph',ph};j.asked=false;};
E.bChoose = (vid,idx)=>{
  const j=E.bJob(vid),v=E.veh(vid);if(!j||!j.wait)return false;const w=j.wait;let o;
  if(w.k==='ph'){const opts=E.bOpts(v,w.ph);if(idx==='crew'){o=opts.find(x=>x.crew&&E.bReq(x,v).ok)||opts.find(x=>E.bReq(x,v).ok&&!E.bCost(x,v))||opts.find(x=>E.bReq(x,v).ok);}else o=opts[idx];
    if(!o||!E.bReq(o,v).ok)return false;}
  else{const e=D.BEVM[w.ev];o=idx==='crew'?e.o[e.o.length-1]:e.o[idx];if(!o)return false;const c=E.bCost(o,v);if(c>0&&G.money<c)return false;}
  const c=E.bCost(o,v);G.money-=c;if(o.money)G.money+=Math.round(o.money*D.BODY[v.body].cost/1000)*1000;
  if(o.days){j.pd[j.pi]=Math.max(0.2,j.pd[j.pi]+o.days);j.total=Math.max(1,j.total+o.days);}
  let note='';
  if(o.gamble){if(U.chance(o.gamble.p)){E.bMerge(v,{m:o.gamble.win});note=' — it worked!';E.H.float('Nice!',v.id,'#8ef58e');}else{E.bMerge(v,{m:o.gamble.lose});note=' — no luck.';E.H.float('Oops',v.id,'#ff9a9a');}}
  else E.bMerge(v,o);
  if(o.fans)G.fans+=Math.round(40+G.fans*0.02);
  if(o.drv){const s=E.staff(w.drv);if(s){s.energy=Math.max(0,s.energy-10);const cls=D.BODY[v.body].cls;s.aff[cls]=+Math.min(1.45,s.aff[cls]+0.02).toFixed(2);}}
  v.blog=(v.blog||[]).concat(w.k==='ph'?`${D.BPHN[w.ph]}: ${o.n}`:`${D.BEVM[w.ev].n}: ${o.n}${note}`);
  if(w.k==='ph'){j.ch=j.ch||{};j.ch[w.ph]=o.id;j.wait=null;}else{j.wait={k:'ph',ph:w.next};j.asked=false;}
  j.left=U.sum(j.pd.slice(j.pi));
  if(w.k==='ph')E.say(`${v.name}: ${o.n}`);
  return true;
};
// override start/finish/tick for staged builds
const _startBuild=E.startBuild;
E.startBuild = (bid,lid,spark,sys)=>{const v=_startBuild(bid,lid,spark,sys);if(!v)return v;
  const j=E.bJob(v.id);const days=Math.round(D.BODY[bid].days*D.BUILD_MULT);const per=days/8;
  Object.assign(j,{pd:Array(8).fill(per),pi:0,total:days,left:days,evN:0,evs:[],plen:per});v.bm={spd:0,acc:0,hnd:0,dur:0,on:0,off:0,wet:0,ice:0,adv:0};v.blog=[];v.bflags=[];
  E.bWaitNext(j,v);return v;};
const _finishBuild=E.finishBuild;
E.finishBuild = v=>{
  const fl=v.bflags||[];
  if(fl.includes('full')){const ks=['spd','acc','hnd','dur'];const worst=ks.slice().sort((a,b)=>(v.phase[a]+(v.bm?v.bm[a]:0)/100)-(v.phase[b]+(v.bm?v.bm[b]:0)/100))[0];
    if(v.phase[worst]<0)v.phase[worst]=0;else if(v.bm)v.bm[worst]+=3;}
  _finishBuild(v);
  const bm=v.bm;if(bm){for(const k of['spd','acc','hnd','dur'])v.base[k]=Math.round(v.base[k]*(1+bm[k]/100));for(const k of['on','off','wet','ice'])v.terr[k]+=bm[k];v.advB=bm.adv;}
  if(fl.includes('dyno')&&v.eng&&v.eng.fuel!=='none'){if(v.eng.fuel==='efi')T.initEFI(v);T.crewTune(v,T.SHOP(),0.98);}
};
E.slots = v=>D.BODY[v.body].slots+(v.slotB||0);
E.tickBuild = (j,v)=>{
  if(!j.pd){j.left-=E.jobRate(j);const prog=1-j.left/j.total;const ph=[0.3,0.6,0.9];while(j.ph<3&&prog>=ph[j.ph]){E.buildPhase(v,j);j.ph++;}return j.left<=0;}
  if(j.wait){if(!j.asked){j.asked=true;E.H.buildAsk(j);}return false;}
  j.pd[j.pi]-=E.jobRate(j);
  while(j.pd[j.pi]<=0&&j.pi<7){const carry=j.pd[j.pi];j.pi++;j.pd[j.pi]+=carry;E.bWaitNext(j,v);break;}
  j.left=Math.max(0,U.sum(j.pd.slice(j.pi)));
  const prog=1-j.left/j.total;const ph=[0.3,0.6,0.9];while(j.ph<3&&prog>=ph[j.ph]){E.buildPhase(v,j);j.ph++;}
  if(j.wait&&!j.asked){j.asked=true;E.H.buildAsk(j);}
  return j.pi===7&&j.pd[7]<=0&&!j.wait;
};
E.H.buildAsk = j=>{const v=E.veh(j.vid);if(v)E.bChoose(v.id,'crew');};
