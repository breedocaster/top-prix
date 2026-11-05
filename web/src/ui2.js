// ===================== UI v2: engineering, formats, tech, awards =====================
UI.resume = null;
UI.cond = ()=>UI.sel.cond||T.SHOP();
UI.condLine = c=>`🌡 ${c.temp}°C · ⛰ ${c.alt}${c.alt2!==c.alt?'→'+c.alt2:''} m · air density ${Math.round(c.rho*100)}%${c.alt2!==c.alt?'→'+Math.round(c.rho2*100)+'%':''}${c.tod==='night'?' · 🌙 night':''}`;
UI.stepper = (a,label,val,extra='',dis=false,data='')=>`<div class="stp"><span class="sp1">${label}${extra?`<div class="sub">${extra}</div>`:''}</span><button class="btn sm blue" data-a="${a}" data-dir="-1" ${data} ${dis?'disabled':''}>−</button><b class="sv">${val}</b><button class="btn sm blue" data-a="${a}" data-dir="1" ${data} ${dis?'disabled':''}>+</button></div>`;
UI.zoneTable = (v,ev,showNum)=>{
  let h=`<div class="ztab">`;for(const z of[...D.ZONES,'trans']){const lam=ev.lam[z];const tz=z==='trans'?'low':z;const[l,col]=T.zoneLabel(lam,tz);
    h+=`<div><span class="zn">${z==='trans'?'Snap':D.ZONE_N[z]}</span><b style="color:${col}">${showNum?(lam*14.7).toFixed(1):l}</b>${showNum?`<span class="sub">→${(D.LAM[tz]*14.7).toFixed(1)}</span>`:''}${ev.kd[z]>0.3?'<span class="bd"> knock</span>':''}</div>`;}
  return h+`</div>`;};

// ---------- vehicle view with engineering tabs ----------
UI.V.vehicle = (v,tab)=>{
  const b=D.BODY[v.body],st=E.vs(v);tab=tab||'info';let h='';
  if(UI.resume)h+=`<div class="note resume"><b class="hl">${UI.resume.label}</b><button class="btn grn" data-a="resume">${UI.resume.btn||'Go'}</button></div>`;
  h+=`<div class="card"><div class="row"><img class="vth" src="${GX.thumb(b.kind,G.team.color,'#ffd84a')}"><div class="sp1"><b>${U.esc(v.name)}</b><span class="rk rk${b.rank}">${b.rank}</span>
    <div class="sub">${b.cls==='car'?'Car':'Bike'} · ${D.LAYOUT[v.layout].n}${v.eng&&v.eng.fuel!=='none'?' · '+(v.eng.fuel==='efi'?'EFI':D.CARBS[v.eng.carb].n.split(' (')[0]):''} · Lv${v.lv}</div>
    <div class="sub">Status: ${v.status} · HP ${Math.round(v.hp*100)}%${v.eng&&v.eng.fuel!=='none'?` · Engine ${Math.round(v.eng.cond*100)}%`:''} · ${v.wins}W/${v.races}R</div></div></div></div>`;
  const tabs=[['info','Info'],['tune','Upgrade'],['parts','Parts'],['setup','Setup'],['fuel',v.eng&&v.eng.fuel==='efi'?'EFI':'Carbs'],['engine','Engine']];
  if(v.status==='build')return {title:'🚗 '+U.esc(v.name),html:h+UI.buildSheet(v),back:'gBack',key:'b'+v.id};
  if(tab==='info'){
    h+=`<div class="card">${UI.vehStats(st)}${UI.terrChips(st)}<div class="sub" style="margin-top:4px">Ad appeal ${st.adv}${st.fx.rp?` · RP +${Math.round(st.fx.rp*100)}%`:''}${st.fx.mis<1?` · mistakes -${Math.round((1-st.fx.mis)*100)}%`:''}${st.fx.wear<1?` · wear -${Math.round((1-st.fx.wear)*100)}%`:''}</div></div>`;
    if(v.status==='repair')h+=`<button class="btn big" data-a="rush">⚡ Rush repair ${U.money(E.rushCost(v))}</button>`;
    h+=`<div class="grid2" style="margin-top:8px"><button class="btn" data-a="testOpen">🧪 Test Day</button><button class="btn blue" data-a="sell">Sell ${U.money(E.sellValue(v))}</button><button class="btn red" data-a="scrap">Scrap +${E.scrapRP(v)} RP</button></div>`;
  }else if(tab==='tune'){
    h+=`<div class="note">Each stat can be upgraded 5 times. Mechanics' Tech and facilities boost the gain.</div>`;
    for(const k of['spd','acc','hnd','dur']){const lv=v.up[k];const c=E.upCost(v,k);
      h+=`<div class="card"><div class="row"><div class="sp1"><b>${{spd:'Speed',acc:'Acceleration',hnd:'Handling',dur:'Durability'}[k]}</b> <span class="hl">${'■'.repeat(lv)}${'□'.repeat(5-lv)}</span><div class="sub">Current ${st[k]} (+${v.upAdd[k]} from upgrades)</div></div>
        ${lv<5?`<button class="btn" data-a="tune" data-k="${k}" ${v.status!=='ready'||G.money<c?'disabled':''}>${U.money(c)}</button>`:'<span class="gd">MAX</span>'}</div></div>`;}
    h+=UI.sparkChips();if(v.status!=='ready')h+=`<div class="note">Vehicle must be Ready to upgrade.</div>`;
  }else if(tab==='parts'){
    h+=`<div class="note">Slots ${v.parts.length}/${E.slots(v)}. One part per category. ⚠ Engine, exhaust and intake parts make the engine want more fuel — re-jet or retune after fitting!</div><div class="sec-h">Installed</div>`;
    if(!v.parts.length)h+=`<div class="sub">None</div>`;
    for(const pid of v.parts){const P=D.PART[pid];h+=`<div class="card"><div class="row"><div class="sp1"><b>${P.n}</b> <span class="sub">${D.PART_CATS[P.cat]} · Lv${E.partLv(pid)}</span><div class="sub hl">${UI.partFx(P)}</div></div><button class="btn sm red" data-a="rmPart" data-p="${pid}">Remove</button></div></div>`;}
    h+=`<div class="sec-h">Available</div>`;
    const avail=D.PARTS.filter(P=>G.res.part[P.id]&&E.partClsOk(P,b.cls)&&!v.parts.includes(P.id));
    if(!avail.length)h+=`<div class="sub">Research parts in 🔬 Research.</div>`;
    for(const P of avail){const c=E.partCost(P.id);const rep=v.parts.find(x=>D.PART[x].cat===P.cat);
      h+=`<div class="card"><div class="row"><div class="sp1"><b>${P.n}</b> <span class="sub">${D.PART_CATS[P.cat]} · T${P.tier}${rep?` · replaces ${D.PART[rep].n}`:''}</span><div class="sub hl">${UI.partFx(P)}</div></div><button class="btn sm" data-a="instPart" data-p="${P.id}" ${G.money<c?'disabled':''}>${U.money(c)}</button></div></div>`;}
  }else if(tab==='setup')h+=UI.setupHTML(v);
  else if(tab==='fuel')h+=v.eng.fuel==='efi'?UI.efiHTML(v):v.eng.fuel==='carb'?UI.carbHTML(v):`<div class="note">Electric drive — no fuel to tune. Check the Setup tab.</div>`;
  else if(tab==='engine')h+=UI.engineHTML(v);
  return {title:'🚗 '+U.esc(v.name),tabs,html:h,back:'gBack',key:v.id+tab};
};
UI.A.gBack = ()=>{if(UI.sel.ret){const r=UI.sel.ret;UI.view=r.view;UI.tab=r.tab;UI.sel=r.sel;return;}UI.sel={};UI.tab=null;};
UI.A.resume = ()=>{const r=UI.resume;UI.resume=null;UI.view=null;$('ov').classList.add('hidden');r.fn();};
const _close=UI.close;UI.close=()=>{if(UI.resume){const r=UI.resume;UI.confirm('Skip it?',r.cancelText||'Leave without running?',()=>{UI.resume=null;UI.view=null;$('ov').classList.add('hidden');r.cancel&&r.cancel();});return;}_close();};

// ---------- conditions selector ----------
UI.condChips = ()=>{const cur=UI.sel.cond;return `<div class="note"><b>Tuning for:</b> <span class="chips" style="display:inline-flex"><button class="chip ${!cur?'on':''}" data-a="condShop">🏠 Shop</button>${UI.sel.condRace?`<button class="chip ${cur?'on':''}" data-a="condRace">🏁 ${U.esc(D.RACE[UI.sel.condRace]?D.RACE[UI.sel.condRace].n:'Race')}</button>`:''}<button class="chip" data-a="condPick">+ pick race</button></span><div class="sub">${UI.condLine(UI.cond())}</div></div>`;};
UI.A.condShop = ()=>{UI.sel.cond=null;};
UI.A.condRace = ()=>{UI.sel.cond=T.forecast(D.RACE[UI.sel.condRace]);};
UI.A.condPick = ()=>{const ids=E.availRaceIds().filter(id=>D.RACE[id]).slice(0,30);
  UI.popup({title:'Tune for which event?',html:`<div class="chips">${ids.map(id=>`<button class="chip" data-pick="${id}" style="padding:5px 8px">${U.esc(D.RACE[id].n)}</button>`).join('')}</div>`,buttons:[{t:'Cancel',cls:'gray'}],
    after:pop=>pop.querySelectorAll('[data-pick]').forEach(b=>b.onclick=()=>{UI.sel.condRace=b.dataset.pick;UI.sel.cond=T.forecast(D.RACE[b.dataset.pick]);UI.nextPop();UI.render();})});};

// ---------- carb bench ----------
UI.carbHTML = v=>{
  const e=v.eng,C=D.CARBS[e.carb],ev=T.eval(v,UI.cond());const wb=T.has('wideband');const n=T.nCarbs(v);let h=UI.condChips();
  h+=`<canvas class="benchcv" id="benchCv" width="480" height="300"></canvas>
    <div class="row" style="margin:4px 0"><span class="sub">Throttle</span><input type="range" min="2" max="100" value="${Math.round(Bench.s.thr*100)}" id="thrSl" class="sp1"><button class="btn sm ${Bench.s.sweep?'grn':''}" data-a="sweep">Sweep</button><button class="btn sm" data-a="snap">Snap</button></div>
    <canvas class="chartcv" id="chartCv" width="480" height="150"></canvas>`;
  h+=`<div class="card">${UI.zoneTable(v,ev,wb)}<div class="sub" style="margin-top:4px">${wb?'Target ≈ 12.8 WOT / 12.9 mid / 13.2 low':'No wideband — reading plugs & symptoms. (Tech: Wideband O2)'}</div>
    ${!wb?`<div class="row" style="margin-top:4px"><span class="plug" style="background:${T.plug(ev.lam.wot)[1]}"></span><span class="sub">Plug chop (WOT): <b>${T.plug(ev.lam.wot)[0]}</b></span></div>`:''}
    <div class="sub">${T.symptoms(ev,v.eng.fuel==='efi').map(x=>'• '+x).join('<br>')}</div></div>`;
  h+=`<div class="sec-h">${U.esc(C.n)} ${n>1?`×${n}`:''}</div>`;
  for(const p of C.p){const val=e.jets[p.k]!=null?e.jets[p.k]:p.stock;h+=UI.stepper('jet',p.n,(p.k==='clip'?'#':'')+val+(p.u||''),p.d||'',v.status!=='ready',`data-k="${p.k}"`);}
  h+=UI.stepper('timing','Ignition advance',(e.timing>0?'+':'')+e.timing+'°',T.mode()==='sim'?'Base timing vs. stock':'More advance = more power until it knocks. Hot days & pump gas knock sooner.',v.status!=='ready');
  h+=`<div class="grid2" style="margin-top:6px">${T.mode()==='standard'&&T.has('crewchief')?`<button class="btn" data-a="crewTune">👷 Crew tune ${U.money(T.crewCost())}</button>`:''}<button class="btn gray" data-a="stockJets">Reset to stock</button></div>`;
  if(n>1)h+=UI.syncHTML(v);
  h+=UI.dynoHTML(v);
  if(e.log)h+=UI.logHTML(e.log);
  return h;};
UI.syncHTML = v=>{const n=v.eng.sync.length,bi=T.syncBase(n);const g=T.has('syncgauge');let h=`<div class="sec-h">⚖️ ${v.eng.fuel==='efi'?'Throttle-body':'Carb'} sync (${n})</div><canvas class="synccv" id="syncCv" width="480" height="210"></canvas>`;
  h+=`<div class="sub">${g?'Match every column to the base carb. Sync drifts as you race.':'Without gauges you adjust by ear — coarse steps and no readout. (Tech: Vacuum Sync Gauges)'}</div>`;
  for(let i=0;i<n;i++){if(i===bi)continue;h+=UI.stepper('syncAdj',`#${i+1} sync screw`,g?(v.eng.sync[i]>0?'+':'')+v.eng.sync[i].toFixed(1):'?','',v.status!=='ready',`data-i="${i}"`);}
  return h;};
UI.dynoHTML = v=>{const has=E.facLv('dyno')>0;const d=Bench.s.dyno;
  return `<div class="sec-h">🏋️ Dyno</div>${has?`<canvas class="dynocv" id="dynoCv" width="480" height="270"></canvas><button class="btn big blue" data-a="dynoRun" ${d&&d.running?'disabled':''}>${d&&d.running?'Pulling…':'Run a WOT pull'}</button>`:`<div class="note">Build a <b>Dyno Room</b> (🏗️ Facility) to do dyno pulls. Meanwhile a 🧪 Test Day logs the same data.</div>`}`;};
UI.logHTML = log=>{let h=`<div class="sec-h">📋 Last datalog</div><div class="card"><div class="sub">${U.esc(log.src)} · ${E.dateStr(log.d)} · ${U.esc(log.cond)}</div><div class="ztab">`;
  for(const z of[...D.ZONES,'trans']){const lam=log.lam[z];const tz=z==='trans'?'low':z;const[l,col]=T.zoneLabel(lam,tz);h+=`<div><span class="zn">${z==='trans'?'Snap':D.ZONE_N[z]}</span><b style="color:${col}">${log.wb?(lam*14.7).toFixed(1):l}</b>${(log.kd[z]||0)>0.3?'<span class="bd"> knock</span>':''}</div>`;}
  return h+`</div></div>`;};
UI.A.jet = d=>{const v=E.veh(UI.sel.vid);const C=D.CARBS[v.eng.carb];const p=C.p.find(x=>x.k===d.k);v.eng.jets[p.k]=+U.clamp((v.eng.jets[p.k]!=null?v.eng.jets[p.k]:p.stock)+(+d.dir)*p.step,p.min,p.max).toFixed(2);E.ach('jet1');UI.checkSpot(v);};
UI.A.timing = d=>{const v=E.veh(UI.sel.vid);v.eng.timing=U.clamp(v.eng.timing+(+d.dir),-6,8);};
UI.A.stockJets = ()=>{const v=E.veh(UI.sel.vid);T.stockJets(v);v.eng.timing=0;};
UI.A.crewTune = ()=>{const v=E.veh(UI.sel.vid);const c=T.crewCost();if(G.money<c){UI.toast('Not enough money');return;}G.money-=c;T.crewTune(v,UI.cond(),0.96);UI.toast('Crew tuned it for '+UI.cond().name);};
UI.A.sweep = ()=>{Bench.s.sweep=!Bench.s.sweep;};
UI.A.snap = ()=>{Bench.s.sweep=false;Bench.s.thr=0.95;Bench.s.snapT=0.5;setTimeout(()=>{Bench.s.thr=0.2;},900);};
UI.A.syncAdj = d=>{const v=E.veh(UI.sel.vid);const g=T.has('syncgauge');const i=+d.i;v.eng.sync[i]=+U.clamp(v.eng.sync[i]+(+d.dir)*(g?0.2:0.6)+(g?0:U.rand(-0.25,0.25)),-6,6).toFixed(1);
  const bi=T.syncBase(v.eng.sync.length);const o=v.eng.sync.filter((x,k)=>k!==bi);if(v.eng.sync.length===4&&o.every(x=>Math.abs(x)<=0.3))E.ach('sync4');};
UI.checkSpot = v=>{if(!T.has('wideband'))return;const ev=T.eval(v,UI.cond());if(D.ZONES.every(z=>Math.abs(ev.lam[z]-D.LAM[z])<=0.02))E.ach('spoton');};
UI.A.dynoRun = ()=>{const v=E.veh(UI.sel.vid);if(v.status!=='ready'){UI.toast('Vehicle must be ready');return;}Bench.s.dyno={running:true,tt:0,rpm:0,trace:[],ev:T.eval(v,UI.cond()),vid:v.id,cond:UI.cond()};SFX.play('start');};
Bench.dynoDone = (v)=>{const d=Bench.s.dyno;v.eng.log=T.makeLog(v,d.cond,'Dyno pull');UI.toast('Pull done — datalog saved');if(UI.view)UI.render();};

// ---------- EFI laptop ----------
UI.efiHTML = v=>{
  const e=v.eng,f=e.efi;const ev=T.eval(v,UI.cond());const et=UI.sel.etab||'ve';const sel=UI.sel.cells||(UI.sel.cells={});const bins=D.RPM_B[D.BODY[v.body].cls];
  let h=UI.condChips();
  h+=`<div class="laptop"><div class="lscreen"><div class="ltop">TunerStudio-ish · ${U.esc(v.name)} · ${T.has('mapsens')?'Speed Density (MAP)':'Alpha-N (TPS)'}${T.has('iat')?' + IAT':''}${T.has('knock')?' + knock':''}</div>
    <div class="ltabs">${[['ve','Fuel VE'],['ign','Spark'],['afr','AFR Target'],['dyno','Dyno/Log'],['set','Settings']].map(([k,n])=>`<button data-a="etab" data-v="${k}" class="${et===k?'on':''}">${n}</button>`).join('')}</div>`;
  if(et==='ve'||et==='ign'||et==='afr'){const tb=et==='ve'?f.ve:et==='ign'?f.ign:f.afr;const rng=et==='ve'?[30,120]:et==='ign'?[5,45]:[11,15.5];
    const log=e.log&&e.log.cells?e.log:null;
    h+=`<div class="vegrid">`;
    for(let j=5;j>=0;j--){h+=`<div class="ax">${D.LOAD_B[j]}</div>`;for(let i=0;i<8;i++){const val=tb[j][i];const nrm=U.clamp((val-rng[0])/(rng[1]-rng[0]),0,1);const k=j+','+i;
      let mark='';if(log&&et==='ve'&&log.wb){const err=log.cells[j][i]/(f.afr[j][i]/14.7)-1;if(Math.abs(err)>0.02)mark=`<i class="lg ${err>0?'ln':'rc'}"></i>`;}
      if(et==='ign'&&log&&T.has('knock')&&ev.cells){const kk=f.ign[j][i]-T.kl(v,i,j,ev.cells[j][i],UI.cond());if(kk>0)mark=`<i class="lg kn"></i>`;}
      h+=`<div class="cell ${sel[k]?'sel':''}" data-a="cell" data-j="${j}" data-i="${i}" style="background:hsl(${Math.round(230-230*nrm)},70%,${et==='afr'?62:58}%)">${et==='afr'?val.toFixed(1):Math.round(val)}${mark}</div>`;}}
    h+=`<div class="ax">kPa</div>${bins.map(r=>`<div class="ax">${r>=10000?(r/1000).toFixed(1)+'k':r>=1000?(r/1000).toFixed(r%1000?1:0)+'k':r}</div>`).join('')}</div>`;
    const ks=Object.keys(sel);
    h+=`<div class="lbar"><button data-a="selRow">Row</button><button data-a="selCol">Col</button><button data-a="selAll">All</button><button data-a="selNone">None</button><span class="sp1"></span>
      <button data-a="cadj" data-v="-5%">−5%</button><button data-a="cadj" data-v="-1">−1</button><button data-a="cadj" data-v="1">+1</button><button data-a="cadj" data-v="5%">+5%</button>${et!=='afr'?'<button data-a="csmooth">Smooth</button>':''}</div>`;
    if(ks.length===1){const[j,i]=ks[0].split(',').map(Number);h+=`<div class="lhint">Cell ${bins[i]} rpm / ${D.LOAD_B[j]} kPa`;
      if(et==='ve'&&log&&log.wb){const m=log.cells[j][i]*14.7,tg=f.afr[j][i];h+=` · log AFR <b>${m.toFixed(1)}</b> vs target ${tg.toFixed(1)} → suggest VE <b>${Math.round(f.ve[j][i]*m/tg)}</b>`;}
      else if(et==='ve'&&!log)h+=' · no datalog yet — dyno pull or test day';
      if(et==='ign')h+=` · ${T.mode()==='sim'?'':`MBT ≈ ${Math.round(T.mbt(i,j))}°`}`;h+=`</div>`;}
    if(et==='ve'&&T.has('veal'))h+=`<button class="btn sm grn" data-a="veal" ${log&&log.wb?'':'disabled'} style="margin-top:4px">🤖 VE Analyze: apply log corrections</button>`;
  }else if(et==='dyno'){h+=UI.dynoHTML(v).replace('class="sec-h"','class="lhint"');if(e.log)h+=UI.logHTML(e.log);}
  else{h+=UI.stepper('ae','Accel enrichment (TPSdot)',f.ae+'%','Extra fuel on throttle snaps — fixes the bog off hairpins');
    h+=`<div class="lhint">Load: ${T.has('mapsens')?'MAP (baro corrected)':'TPS — will go rich at altitude'} · IAT: ${T.has('iat')?'on':'not fitted'} · Knock control: ${T.has('knock')?'on':'not fitted'} · Launch: ${T.has('launch')?'2-step armed':'—'}</div>`;}
  h+=`</div><div class="lbase"></div></div>`;
  h+=`<div class="card">${UI.zoneTable(v,ev,true)}<div class="sub">${T.symptoms(ev,v.eng.fuel==='efi').map(x=>'• '+x).join('<br>')}</div></div>`;
  h+=`<div class="grid2">${T.mode()==='standard'&&T.has('crewchief')?`<button class="btn" data-a="crewTune">👷 Crew tune ${U.money(T.crewCost())}</button>`:''}<button class="btn gray" data-a="efiBase">Reload base map</button></div>`;
  if(T.nCarbs(v)>1)h+=UI.syncHTML(v);
  return h;};
UI.A.etab = d=>{UI.sel.etab=d.v;UI.sel.cells={};};
UI.A.cell = d=>{const k=d.j+','+d.i;const s=UI.sel.cells;if(s[k])delete s[k];else s[k]=1;};
UI.A.selRow = ()=>{const s=UI.sel.cells;const ks=Object.keys(s);const j=ks.length?ks[0].split(',')[0]:5;UI.sel.cells={};for(let i=0;i<8;i++)UI.sel.cells[j+','+i]=1;};
UI.A.selCol = ()=>{const s=UI.sel.cells;const ks=Object.keys(s);const i=ks.length?ks[0].split(',')[1]:5;UI.sel.cells={};for(let j=0;j<6;j++)UI.sel.cells[j+','+i]=1;};
UI.A.selAll = ()=>{UI.sel.cells={};for(let j=0;j<6;j++)for(let i=0;i<8;i++)UI.sel.cells[j+','+i]=1;};
UI.A.selNone = ()=>{UI.sel.cells={};};
UI.efiTable = v=>{const et=UI.sel.etab||'ve';return et==='ve'?v.eng.efi.ve:et==='ign'?v.eng.efi.ign:et==='afr'?v.eng.efi.afr:null;};
UI.A.cadj = d=>{const v=E.veh(UI.sel.vid);const tb=UI.efiTable(v);if(!tb)return;const et=UI.sel.etab||'ve';const ks=Object.keys(UI.sel.cells);if(!ks.length){UI.toast('Tap cells to select them');return;}
  for(const k of ks){const[j,i]=k.split(',').map(Number);let x=tb[j][i];
    if(d.v.endsWith('%'))x*=1+parseFloat(d.v)/100;else x+=et==='afr'?(+d.v)*0.1:+d.v;
    tb[j][i]=et==='afr'?+U.clamp(x,9.5,16.5).toFixed(1):Math.round(U.clamp(x,et==='ign'?-5:5,et==='ign'?55:180));}
  G.st.cells=(G.st.cells||0)+ks.length;if(G.st.cells>=50)E.ach('cells');UI.checkSpot(v);};
UI.A.csmooth = ()=>{const v=E.veh(UI.sel.vid);const tb=UI.efiTable(v);const ks=Object.keys(UI.sel.cells);if(ks.length<2)return;const cp=tb.map(r=>r.slice());
  for(const k of ks){const[j,i]=k.split(',').map(Number);let s=0,n=0;for(const[a,b]of[[0,0],[1,0],[-1,0],[0,1],[0,-1]]){const jj=j+a,ii=i+b;if(jj>=0&&jj<6&&ii>=0&&ii<8){s+=cp[jj][ii];n++;}}tb[j][i]=Math.round(s/n);}};
UI.A.veal = ()=>{const v=E.veh(UI.sel.vid);const f=v.eng.efi,log=v.eng.log;if(!log||!log.cells)return;let n=0;const vis=new Set();for(const z in T.ZC)for(const[j,i]of T.ZC[z])vis.add(j+','+i);for(let i=0;i<8;i++){vis.add('4,'+i);vis.add('5,'+i);}
  for(const k of vis){const[j,i]=k.split(',').map(Number);const m=log.cells[j][i],tg=f.afr[j][i]/14.7;const nv=Math.round(f.ve[j][i]*m/tg);if(nv!==f.ve[j][i]){f.ve[j][i]=U.clamp(nv,5,180);n++;}}
  v.eng.log=null;E.ach('veal1');UI.toast(`VE Analyze corrected ${n} cells. Log again to verify.`);};
UI.A.efiBase = ()=>{const v=E.veh(UI.sel.vid);UI.confirm('Reload base map?','Your VE, spark and AFR tables go back to the rough base tune.',()=>T.initEFI(v),'Reload','red');};
UI.A.ae = d=>{const v=E.veh(UI.sel.vid);v.eng.efi.ae=U.clamp(v.eng.efi.ae+(+d.dir)*5,0,250);};

// ---------- setup sheet ----------
UI.setupHTML = v=>{
  const b=D.BODY[v.body],st=v.setup;const bike=b.cls==='bike';let h=`<div class="note">Setup changes how speed, acceleration and grip show up on each track. Locked rows need 🔬 Tech.</div>`;
  const lock=t=>T.has(t)?'':`🔒 ${D.TECHM[t].n}`;
  if(bike){const ratio=(st.r/st.f).toFixed(2);const rel=(st.r/st.f)/T.stockRatio(v);
    h+=UI.stepper('sFront','Front sprocket',st.f+'T',lock('gearing'),!T.has('gearing'))+UI.stepper('sRear','Rear sprocket',st.r+'T',lock('gearing')||`Ratio ${ratio} · ${rel>1.02?'shorter: more accel, less top speed':rel<0.98?'taller: more top speed, softer launch':'stock-ish'}`,!T.has('gearing'));}
  else h+=UI.stepper('sFd','Final drive',st.fd.toFixed(2)+':1',lock('gearing')||(st.fd>3.75?'Short: launches & hills':st.fd<3.65?'Tall: fast tracks':'Stock'),!T.has('gearing'));
  h+=UI.stepper('sSusp','Suspension stiffness',st.susp+' clicks',lock('adjsus')||'Stiffer = sharper on tarmac, worse over rough ground',!T.has('adjsus'));
  h+=UI.stepper('sPsi','Tire pressure',st.psi+' psi',lock('tirepress')||`Stock ${T.stockPsi(v)} — air down for dirt, up a touch for tarmac`,!T.has('tirepress'));
  if(!bike)h+=UI.stepper('sWing','Wing angle',st.wing+'°',lock('aero')||'More wing = more cornering grip, less top speed',!T.has('aero'));
  h+=UI.condChips().replace('Tuning for:','Setting up for:');
  h+=`<div class="grid2"><button class="btn" data-a="crewSetup" ${UI.sel.condRace?'':'disabled'}>👷 Crew setup for ${UI.sel.condRace?U.esc(D.RACE[UI.sel.condRace].n):'(pick race)'}</button><button class="btn gray" data-a="stockSetup">Stock setup</button></div>`;
  return h;};
UI.A.sFront = d=>{const v=E.veh(UI.sel.vid);v.setup.f=U.clamp(v.setup.f+(+d.dir),11,19);};
UI.A.sRear = d=>{const v=E.veh(UI.sel.vid);v.setup.r=U.clamp(v.setup.r+(+d.dir),34,60);};
UI.A.sFd = d=>{const v=E.veh(UI.sel.vid);v.setup.fd=+U.clamp(v.setup.fd+(+d.dir)*0.05,2.8,4.8).toFixed(2);};
UI.A.sSusp = d=>{const v=E.veh(UI.sel.vid);v.setup.susp=U.clamp(v.setup.susp+(+d.dir),1,10);};
UI.A.sPsi = d=>{const v=E.veh(UI.sel.vid);v.setup.psi=U.clamp(v.setup.psi+(+d.dir),8,44);};
UI.A.sWing = d=>{const v=E.veh(UI.sel.vid);v.setup.wing=U.clamp(v.setup.wing+(+d.dir),0,15);};
UI.A.stockSetup = ()=>{const v=E.veh(UI.sel.vid);v.setup=T.defaultSetup(v);};
UI.A.crewSetup = ()=>{const v=E.veh(UI.sel.vid);const r=D.RACE[UI.sel.condRace];const s=E.drivers()[0];if(!r||!s)return;E.bestSetup(v,r,s);UI.toast('Crew set it up for '+r.n);};
E.bestSetup = (v,r,s)=>{const bike=D.BODY[v.body].cls==='bike';const keys=bike?['r','susp','psi']:['fd','susp','psi','wing'];
  const rng={r:[34,60,1],fd:[2.8,4.8,0.1],susp:[1,10,1],psi:bike?[8,40,2]:[18,40,2],wing:[0,15,1]};
  for(let pass=0;pass<2;pass++)for(const k of keys){const[a,b,st]=rng[k];let best=v.setup[k],bs=E.oddsRatio(r,v,s);
    for(let x=a;x<=b+1e-9;x+=st){v.setup[k]=+x.toFixed(2);const o=E.oddsRatio(r,v,s);if(o>bs+1e-6){bs=o;best=v.setup[k];}}v.setup[k]=best;}};

// ---------- engine tab ----------
UI.engineHTML = v=>{
  const e=v.eng,b=D.BODY[v.body];if(e.fuel==='none')return `<div class="note">Electric motor — nothing to rebuild or jet. Lucky you.</div>`;
  const cyl=T.cyl(v);let h=`<div class="card"><b>${cyl}-cylinder · ${D.LAYOUT[v.layout].n}</b> · ${e.fuel==='efi'?'EFI':`${D.CARBS[e.carb].n} ×${T.nCarbs(v)}`}
    <div class="sub">Engine condition ${Math.round(e.cond*100)}%</div><div class="ebar"><i style="width:${e.cond*100}%;background:${e.cond>0.6?'#8ef58e':e.cond>0.3?'#ffd84a':'#ff6060'}"></i></div>
    ${e.cond<0.999?`<button class="btn big" style="margin-top:6px" data-a="rebuild" ${v.status!=='ready'?'disabled':''}>🔧 Rebuild engine ${U.money(T.rebuildCost(v))}</button>`:''}
    ${e.cond<=0.02?'<div class="bd">Engine is dead — rebuild before racing.</div>':''}</div>`;
  h+=`<div class="sec-h">⛽ Fuel</div><div class="chips">${Object.entries(D.FUELS).map(([k,f])=>{const ok=!f.tech||T.has(f.tech);return `<button class="chip ${e.fuelT===k?'on':''}" style="padding:5px 9px" ${ok?`data-a="fuelT" data-v="${k}"`:'disabled'}>${f.n}${f.cost?' '+U.money(f.cost)+'/race':''}${ok?'':' 🔒'}</button>`;}).join('')}</div>
    <div class="sub">${e.fuelT==='e85'?(e.fuel==='carb'?'⚠ E85 needs ~32% more fuel. Jet up a lot!':T.has('e85')?'Flex sensor adjusts the EFI automatically.':''):'Race gas & E85 add knock margin.'}</div>`;
  h+=`<div class="sec-h">🔁 Fuel system</div>`;
  const opts=T.carbsFor(v).filter(k=>k!==e.carb||e.fuel==='efi');
  for(const k of opts){const C=D.CARBS[k];const ok=T.carbAvail(k);h+=`<div class="card ${ok?'':'lock'}"><div class="row"><div class="sp1"><b>${C.n}</b><div class="sub">${C.pw>1?`+${Math.round((C.pw-1)*100)}% power`:'Basic'}${C.p.find(p=>p.k==='pump')?' · accel pump':''}${C.kind==='cv'?' · smooth CV slide':''}${C.carbs>1||(C.cls==='bike'&&cyl>1)?' · needs sync':''}</div></div>
    ${ok?`<button class="btn sm" data-a="swap" data-v="${k}" ${v.status!=='ready'?'disabled':''}>${U.money(T.carbSwapCost(b,k))}</button>`:`<span class="sub">🔒 ${D.TECHM[C.un]?D.TECHM[C.un].n:''}</span>`}</div></div>`;}
  if(e.fuel!=='efi')h+=`<div class="card ${T.has('efi')?'':'lock'}"><div class="row"><div class="sp1"><b>💻 Convert to EFI</b><div class="sub">Laptop tuning: VE, spark & AFR tables. +5% power when mapped.</div></div>${T.has('efi')?`<button class="btn sm" data-a="swap" data-v="efi" ${v.status!=='ready'?'disabled':''}>${U.money(T.efiCost(b))}</button>`:'<span class="sub">🔒 Throttle-Body EFI</span>'}</div></div>`;
  if(e.log)h+=UI.logHTML(e.log);
  return h;};
UI.A.rebuild = ()=>{E.startRebuild(UI.sel.vid);};
UI.A.fuelT = d=>{const v=E.veh(UI.sel.vid);v.eng.fuelT=d.v;};
UI.A.swap = d=>{const v=E.veh(UI.sel.vid);UI.confirm('Change fuel system?',`Fit ${d.v==='efi'?'EFI (base map — needs tuning!)':D.CARBS[d.v].n} to ${U.esc(v.name)}? Takes a few days.`,()=>E.startSwap(v.id,d.v==='efi'?{type:'efi'}:{type:'carb',carb:d.v}),'Fit it','grn');};

// ---------- build: fuel system choice ----------
const _buildV=UI.V.build;
UI.V.build = tab=>{
  if(UI.sel.body&&UI.sel.layout&&!UI.sel.sysPicked&&D.LAYOUT_CYL[UI.sel.layout]!==0){const b=D.BODY[UI.sel.body];const cyl=D.LAYOUT_CYL[UI.sel.layout];
    let h=`<div class="sec-h">Fuel system for ${U.esc(b.n)} (${D.LAYOUT[UI.sel.layout].n}${b.cls==='bike'?` · ${cyl} cyl → ${cyl} carb${cyl>1?'s':''}`:''})</div>`;
    for(const k of T.carbsFor({body:b.id})){const C=D.CARBS[k];const ok=T.carbAvail(k);const add=E.sysCost(b.id,UI.sel.layout,{type:'carb',carb:k});
      h+=`<div class="card ${ok?'':'lock'}" ${ok?`data-a="pickSys" data-v="${k}"`:''}><div class="row"><div class="sp1"><b>${C.n}</b><div class="sub">${C.pw>1?`+${Math.round((C.pw-1)*100)}% power`:'Basic'}${C.p.find(p=>p.k==='pump')?' · accel pump':''}</div></div><span class="hl">${ok?(add?'+'+U.money(add):'Included'):'🔒'}</span></div></div>`;}
    const okE=T.has('efi');h+=`<div class="card ${okE?'':'lock'}" ${okE?`data-a="pickSys" data-v="efi"`:''}><div class="row"><div class="sp1"><b>💻 EFI</b><div class="sub">Laptop-tuned injection</div></div><span class="hl">${okE?'+'+U.money(T.efiCost(b)):'🔒'}</span></div></div>`;
    return {title:'🔧 Build',html:h,back:'bBackL',key:'sys'};}
  return _buildV(tab);};
UI.A.pickSys = d=>{UI.sel.sysPicked=true;UI.sel.sys=d.v==='efi'?{type:'efi'}:{type:'carb',carb:d.v};};
const _selL=UI.A.selL;UI.A.selL = d=>{_selL(d);UI.sel.sysPicked=false;UI.sel.sys=null;};
UI.A.bBackL = ()=>{if(UI.sel.sysPicked){UI.sel.sysPicked=false;return;}UI.sel.layout=null;};
UI.A.doBuild = ()=>{const v=E.startBuild(UI.sel.body,UI.sel.layout,UI.sel.spark||null,UI.sel.sys||null);if(v){UI.close();}};
const _vcost=E.vehCost;

// ---------- research: tech tab ----------
const _resV=UI.V.research;
UI.V.research = tab=>{
  tab=tab||'tech';if(tab!=='tech'){const r=_resV(tab);r.tabs=[['tech','Tech'],...r.tabs];return r;}
  let h=`<div class="note">Research Data: <b class="bl">${G.rp} RP</b>. Technologies unlock carbs, EFI features, setup options and engine upgrades.</div>`;
  for(const cat of['Fuel','Engine','Chassis','Crew']){h+=`<div class="sec-h">${cat}</div>`;
    for(const t of D.TECH.filter(x=>x.cat===cat)){const av=E.techAvail(t.id);
      h+=`<div class="card ${av.done?'done':av.ok?'':'lock'}"><div class="row"><div class="sp1"><b>${t.n}</b><div class="sub">${U.esc(t.d)}</div>${!av.ok?`<div class="sub hl">🔒 ${av.why}</div>`:''}</div>
        ${av.done?'<span class="gd">✓</span>':av.ok?`<button class="btn sm blue" data-a="resTech" data-v="${t.id}" ${G.rp<t.rp?'disabled':''}>${t.rp} RP</button>`:''}</div></div>`;}}
  return {title:'🔬 Research',tabs:[['tech','Tech'],['car','Cars'],['bike','Bikes'],['layout','Layouts'],['part','Parts']],html:h};};
UI.A.resTech = d=>{E.researchTech(d.v);};

// ---------- team: awards + mode ----------
const _teamV=UI.V.team;
UI.V.team = tab=>{
  tab=tab||'team';
  if(tab==='awards'){const got=Object.keys(G.ach||{}).length;let h=`<div class="note">${got}/${D.ACH.length} achievements unlocked</div>`;
    for(const a of D.ACH){const ok=G.ach&&G.ach[a.id];const rw=a.rw||{};h+=`<div class="card ${ok?'done':'lock'}"><div class="row"><span style="font-size:22px">${a.ic}</span><div class="sp1"><b>${U.esc(a.n)}</b><div class="sub">${U.esc(a.d)}</div></div><span class="sub">${ok?'✓ '+E.dateStr(ok-1):[rw.cash?U.money(rw.cash*1000):'',rw.rp?rw.rp+'RP':'',rw.spark?'✨':''].filter(Boolean).join(' ')}</span></div></div>`;}
    return {title:'📋 Team',tabs:UI.teamTabs,html:h};}
  const r=_teamV(tab);r.tabs=UI.teamTabs;
  if(tab==='settings'){const m=T.mode();r.html=`<div class="card"><b>🎚️ Difficulty</b> <span class="sub">(change any time)</span><div class="chips" style="margin:6px 0">${Object.entries(D.MODES).map(([k,x])=>`<button class="chip ${m===k?'on':''}" style="padding:6px 12px;font-size:13px" data-a="setMode" data-v="${k}">${x.n}</button>`).join('')}</div><div class="sub">${D.MODES[m].d}</div></div>`+r.html;}
  return r;};
UI.teamTabs = [['team','Team'],['titles','Titles'],['awards','Awards'],['news','News'],['settings','Settings']];
UI.A.setMode = d=>{G.settings.mode=d.v;UI.toast('Difficulty: '+D.MODES[d.v].n);};

// ---------- garage list: test day button ----------
const _garV=UI.V.garage;
UI.V.garage = tab=>{const r=_garV(tab);if(!UI.sel.vid)r.html=`<button class="btn big" style="margin-bottom:8px" data-a="testOpen">🧪 Test Day — log data & train drivers</button>`+r.html;return r;};

// ---------- TEST DAY ----------
UI.A.testOpen = ()=>{const vid=UI.sel.vid;UI.view='test';UI.tab=null;UI.sel={tvid:vid||null,laps:5,track:'t_tar'};};
UI.V.test = ()=>{
  UI.sel.track=UI.sel.track||'t_tar';UI.sel.laps=UI.sel.laps||5;
  const vs=G.vehicles.filter(v=>v.status==='ready'&&E.engReady(v));if(UI.sel.tvid&&!vs.find(v=>v.id===UI.sel.tvid))UI.sel.tvid=null;if(!UI.sel.tvid&&vs[0])UI.sel.tvid=vs[0].id;
  const ds=E.drivers().filter(s=>s.energy>=10);if(!UI.sel.tsid2||!ds.find(s=>s.id===UI.sel.tsid2))UI.sel.tsid2=ds[0]&&ds[0].id;
  let h=`<div class="note">Run laps alone at a private track. You get a full fuel datalog (AFR per throttle zone, knock, sync), lap times, and a little driver experience. Costs money and some energy.</div>`;
  h+=`<div class="sec-h">Track</div><div class="chips">${D.TESTS.map(t=>`<button class="chip ${UI.sel.track===t.id?'on':''}" style="padding:5px 9px" data-a="tTrack" data-v="${t.id}">${t.n}</button>`).join('')}</div>`;
  const tt=D.TESTS.find(t=>t.id===UI.sel.track);
  if(tt.style!=='drag'&&tt.style!=='hill')h+=`<div class="sec-h">Laps</div><div class="chips">${[3,5,10].map(n=>`<button class="chip ${UI.sel.laps===n?'on':''}" style="padding:5px 12px" data-a="tLaps" data-v="${n}">${n} laps</button>`).join('')}</div>`;
  h+=`<div class="sec-h">Vehicle</div>`;if(!vs.length)h+=`<div class="note">No ready vehicle.</div>`;
  for(const v of vs){const b=D.BODY[v.body];h+=`<div class="card ${UI.sel.tvid===v.id?'sel':''}" data-a="tVeh" data-v="${v.id}"><div class="row"><img class="vth" style="width:52px;height:43px" src="${GX.thumb(b.kind,G.team.color,'#ffd84a')}"><div class="sp1"><b>${U.esc(v.name)}</b><div class="sub">${v.eng.fuel==='efi'?'EFI':v.eng.fuel==='carb'?D.CARBS[v.eng.carb].n:'Electric'} · engine ${Math.round(v.eng.cond*100)}%</div></div></div></div>`;}
  h+=`<div class="sec-h">Driver</div><div class="chips">${ds.map(s=>`<button class="chip ${UI.sel.tsid2===s.id?'on':''}" style="padding:5px 9px" data-a="tDrv" data-v="${s.id}">${U.esc(s.name)} ⚡${Math.round(s.energy)}</button>`).join('')||'<span class="sub">Everyone is too tired.</span>'}</div>`;
  const laps=tt.style==='drag'||tt.style==='hill'?3:UI.sel.laps;const c=E.testCost(laps);
  h+=`<button class="btn big grn" style="margin-top:10px" data-a="tGo" ${!UI.sel.tvid||!UI.sel.tsid2||G.money<c?'disabled':''}>🧪 Start test (${U.money(c)})</button>`;
  return {title:'🧪 Test Day',html:h};};
UI.A.tTrack = d=>{UI.sel.track=d.v;};UI.A.tLaps = d=>{UI.sel.laps=+d.v;};UI.A.tVeh = d=>{UI.sel.tvid=+d.v;};UI.A.tDrv = d=>{UI.sel.tsid2=+d.v;};
UI.A.tGo = ()=>{const tt=D.TESTS.find(t=>t.id===UI.sel.track);const v=E.veh(UI.sel.tvid),s=E.staff(UI.sel.tsid2);if(!v||!s)return;
  const p=E.profile(v,s);const laps=tt.style==='drag'||tt.style==='hill'?3:UI.sel.laps;
  const def={id:tt.id,n:tt.n,tier:Math.max(1,G.ws),disc:'OP',cls:'any',surf:tt.surf,style:tt.style,laps,R:Math.max(10,(p.S+p.A+p.H)/3/1.25),prize:0,rp:0,alt:tt.alt||200,alt2:tt.alt2||tt.alt||200,temp:20};
  const cond=T.forecast(def);UI.view=null;$('ov').classList.add('hidden');
  const rs=Race.create(def,{vid:v.id,sid:s.id,tactic:'normal'},{test:true,rivals:[],fmt:{id:'test',kind:'tt',laps,mul:{prize:0,rp:0,fans:0,wear:0.4}},cond});
  UI.launch(rs,rs=>UI.testResult(rs),`🧪 ${tt.n}`);};
UI.testResult = rs=>{
  const out=E.finishTest(rs);const v=E.veh(rs.player.vid);const P=rs.player;const lg=v&&v.eng.log;
  let h=`<div class="big">🧪 Test complete</div><div class="sub" style="text-align:center">${U.esc(rs.def.n)} · ${UI.condLine(rs.cond)}</div>`;
  if(P.lapT&&P.lapT.length)h+=`<div class="card"><b>Lap times</b><div class="sub">${P.lapT.map((t,i)=>`L${i+1} ${t.toFixed(2)}s`).join(' · ')}</div></div>`;
  if(P.dnf)h+=`<div class="note bd">${P.holed?'💥 Holed a piston during the test!':P.seized?'🧊 Seized!':'Session cut short.'}</div>`;
  if(lg&&v.eng.fuel!=='none'){const ev=T.eval(v,rs.cond);h+=`<div class="card"><b>Datalog</b>${UI.zoneTable(v,ev,lg.wb)}${!lg.wb?`<div class="sub">Plug chop: <b>${T.plug(ev.lam.wot)[0]}</b></div>`:''}<div class="sub">${T.symptoms(ev,v.eng.fuel==='efi').map(x=>'• '+x).join('<br>')}</div></div>`;}
  h+=`<div class="sub">Driver: ${out.gains.map(k=>k+' +1').join(', ')} · Cost ${U.money(E.testCost(rs.tr.laps))}</div>`;
  UI.racePanel(h,[{t:'⛽ Tune it',cls:'blue',fn:()=>{UI.raceClose();UI.open('garage','fuel',{vid:v.id,cond:rs.cond.rho!==T.SHOP().rho?rs.cond:null});}},{t:'Done',cls:'grn',fn:()=>UI.raceClose()}]);};

// ---------- PRE-RACE (rewritten) ----------
UI.V.prerace = ()=>{
  const r=D.RACE[UI.sel.rid];const tr=Race.track(r,false);const sid=UI.sel.sid;
  const fmts=sid?[D.seriesFormat(r)]:D.formats(r);if(!UI.sel.fmt||!fmts.find(f=>f.id===UI.sel.fmt))UI.sel.fmt=fmts[0].id;const fmt=fmts.find(f=>f.id===UI.sel.fmt);
  const vs=E.eligibleVehicles(r);const ds=E.drivers();const cond=T.forecast(r);
  if(UI.sel.vid&&!vs.find(v=>v.id===UI.sel.vid))UI.sel.vid=null;
  if(!UI.sel.vid&&vs.length){UI.sel.vid=vs.map(v=>({v,o:ds[0]?E.oddsRatio(r,v,ds[0]):0})).sort((a,b)=>b.o-a.o)[0].v.id;}
  const okD=E.eligibleDrivers();if(UI.sel.sid2&&!okD.find(s=>s.id===UI.sel.sid2))UI.sel.sid2=null;
  if(!UI.sel.sid2&&okD.length)UI.sel.sid2=okD.slice().sort((a,b)=>b.energy-a.energy)[0].id;
  UI.sel.tactic=UI.sel.tactic||'normal';
  const cnt={};tr.secs.forEach(s=>cnt[s.type]=(cnt[s.type]||0)+1);
  let h='';
  if(sid){const S=D.SER[sid],a=G.series[sid].act;h+=`<div class="note"><b class="hl">${U.esc(S.n)}</b> — Round ${a.round+1}/${S.rounds.length}. ${a.round>0?'You have '+(a.pts.you||0)+' pts.':''}</div>`;}
  h+=`<canvas class="trkcv" data-track="${r.id}"></canvas>${UI.surfBar(r)}${UI.surfChips(r)}
    <div class="chips">${Object.entries(cnt).map(([k,n])=>`<span class="chip">${D.SEC[k].n} ×${n}</span>`).join('')}<span class="chip">${D.DISC[r.disc].ic} ${r.cls==='any'?'Cars & Bikes':r.cls==='car'?'Cars only':'Bikes only'}</span></div>
    <div class="note" style="margin-top:6px">${UI.condLine(cond)}</div>`;
  h+=`<div class="sec-h">Format</div><div class="chips">${fmts.map(f=>`<button class="chip ${f.id===fmt.id?'on':''}" style="padding:5px 9px" ${fmts.length>1?`data-a="selF" data-v="${f.id}"`:''}>${f.n}${f.mul.prize!==1?` · ${f.mul.prize}× prize`:''}</button>`).join('')}</div>`;
  h+=`<div class="sec-h">Vehicle</div>`;
  if(!vs.length)h+=`<div class="note">No ready ${r.cls==='any'?'':r.cls} vehicle! ${G.vehicles.some(v=>E.clsOk(r,v))?'Your eligible vehicles are busy or need an engine rebuild.':'Build one first.'}</div>`;
  for(const v of vs){const st=E.vs(v);const b=D.BODY[v.body];
    h+=`<div class="card ${UI.sel.vid===v.id?'sel':''}" data-a="selV" data-v="${v.id}"><div class="row"><img class="vth" src="${GX.thumb(b.kind,G.team.color,'#ffd84a')}"><div class="sp1"><b>${U.esc(v.name)}</b> <span class="sub">Lv${v.lv} · HP ${Math.round(v.hp*100)}%${v.eng.fuel!=='none'?` · Eng ${Math.round(v.eng.cond*100)}%`:''}</span>
      <div class="sub">SPD ${st.spd} · ACC ${st.acc} · HND ${st.hnd} · DUR ${st.dur}</div>${UI.terrChips(st)}</div></div></div>`;}
  const v=E.veh(UI.sel.vid);
  if(v&&v.eng.fuel!=='none'){const m=T.mode();h+=`<div class="card"><b>🔧 Engine outlook</b> <span class="sub">${v.eng.fuel==='efi'?'EFI':D.CARBS[v.eng.carb].n} · ${D.FUELS[v.eng.fuelT].n}</span>`;
    if(m==='easy')h+=`<div class="sub gd">Crew will jet/map for these conditions before the start ✓</div>`;
    else if(m==='sim')h+=`<div class="sub">Sim mode — no crew forecast. Trust your datalogs.</div>`;
    else{const rsx=T.raceSecs(v,r,tr,cond);const ev=rsx.ev;h+=UI.zoneTable(v,ev,T.has('wideband'));const w=[];
      if(cond.alt2!==cond.alt){const top=T.eval(v,{...cond,alt:cond.alt2,temp:cond.temp-(cond.alt2-cond.alt)*0.0065},cond.rho2);w.push(`At the summit WOT goes to ${T.has('wideband')?(top.lam.wot*14.7).toFixed(1):T.zoneLabel(top.lam.wot,'wot')[0].toLowerCase()}`);}
      if(ev.kd.wot>0.3||ev.kd.mid>0.3)w.push('<span class="bd">⚠ Knock risk under load — pull timing, richen, or run better fuel</span>');
      if(ev.lh.wot>0.3||ev.lh.mid>0.3)w.push('<span class="bd">⚠ Lean under load — engine damage likely</span>');
      if(ev.seize)w.push('<span class="bd">⚠ Two-stroke too lean — seizure risk!</span>');
      if(ev.starve&&(cnt.jmp||cnt.rgh))w.push('<span class="hl">Low fuel level + jumps = starvation</span>');
      if(ev.flood&&cnt.rgh)w.push('<span class="hl">High fuel level + rough sections = flooding</span>');
      if(ev.foul)w.push('<span class="hl">Very rich idle — may foul a plug</span>');
      if(ev.imb>1.2)w.push('<span class="hl">Carbs out of sync</span>');
      if(v.eng.cond<0.4)w.push('<span class="bd">Engine is tired — rebuild soon</span>');
      if(w.length)h+=`<div class="sub">${w.join('<br>')}</div>`;}
    h+=`<div class="grid2" style="margin-top:6px"><button class="btn sm blue" data-a="preTune">⛽ ${v.eng.fuel==='efi'?'Laptop':'Carbs'}</button><button class="btn sm blue" data-a="preSetup">⚙ Setup</button>${m==='standard'&&T.has('crewchief')?`<button class="btn sm" data-a="preCrew">👷 Crew tune ${U.money(T.crewCost())}</button>`:''}</div></div>`;}
  h+=`<div class="sec-h">Driver</div>`;
  for(const s of ds){const ok=s.energy>=E.raceEnergy(s);
    h+=`<div class="card ${UI.sel.sid2===s.id?'sel':''} ${ok?'':'lock'}" ${ok?`data-a="selD" data-v="${s.id}"`:''}><div class="row"><img class="face" src="${GX.face(s)}"><div class="sp1"><b>${U.esc(s.name)}</b> ${s.trait?`<span class="chip">${D.TRAITS[s.trait].n}</span>`:''}
      <div class="sub">Pedal ${s.pedal} · Shift ${s.shift} · Steer ${s.steer} · Car ${s.aff.car}× · Bike ${s.aff.bike}×</div><div class="ebar"><i style="width:${s.energy/s.maxE*100}%"></i></div>${ok?'':'<div class="sub bd">Too tired to race</div>'}</div></div></div>`;}
  h+=`<div class="sec-h">Tactic</div><div class="chips">${Object.entries(Race.TAC).map(([k,t])=>`<button class="chip ${UI.sel.tactic===k?'on':''}" style="padding:5px 10px;font-size:13px" data-a="selT" data-v="${k}">${t.n}</button>`).join('')}</div>
    <div class="sub" style="margin-top:3px">Safe: fewer mistakes, less wear, cooler engine. Push: faster, riskier, hotter.${r.style==='drag'?' Push also risks a red light.':''}</div>`;
  const s=E.staff(UI.sel.sid2);
  if(v&&s){const o=E.oddsRatio(r,v,s);const[l,c]=E.oddsLabel(o);h+=`<div class="note" style="margin-top:8px;text-align:center;font-size:15px">Outlook: <b style="color:${c}">${l}</b> <span class="sub">(${Math.round(o*100)}% of field pace)</span></div>
    <button class="btn big grn" data-a="go">🏁 START${fmt.kind==='drag'?' ELIMINATIONS':fmt.kind==='heats'?' HEAT':fmt.runs===2?' RUN 1':' RACE'}</button>`;}
  if(sid)h+=`<div style="margin-top:8px"><button class="btn gray big" data-a="skipRound">Skip this round</button></div>`;
  return {title:`${D.DISC[r.disc].ic} ${U.esc(r.n)}`,html:h,back:sid?null:'backRace',key:r.id};
};
UI.A.selF = d=>{UI.sel.fmt=d.v;};
UI.A.preTune = ()=>{const ret={view:'prerace',tab:null,sel:{...UI.sel}};const r=D.RACE[UI.sel.rid];UI.view='garage';UI.tab='fuel';UI.sel={vid:UI.sel.vid,cond:T.forecast(r),condRace:r.id,ret};};
UI.A.preSetup = ()=>{const ret={view:'prerace',tab:null,sel:{...UI.sel}};const r=D.RACE[UI.sel.rid];UI.view='garage';UI.tab='setup';UI.sel={vid:UI.sel.vid,cond:T.forecast(r),condRace:r.id,ret};};
UI.A.preCrew = ()=>{const v=E.veh(UI.sel.vid);const c=T.crewCost();if(G.money<c){UI.toast('Not enough money');return;}G.money-=c;T.crewTune(v,T.forecast(D.RACE[UI.sel.rid]),0.96);UI.toast('Crew tuned for race-day conditions');};
UI.A.go = ()=>{const r=D.RACE[UI.sel.rid];const v=E.veh(UI.sel.vid),s=E.staff(UI.sel.sid2);if(!v||!s)return;
  if(s.energy<E.raceEnergy(s)){UI.toast('Driver too tired');return;}
  UI.view=null;$('ov').classList.add('hidden');UI.startRace(r,v,s,UI.sel.tactic,UI.sel.sid,UI.sel.fmt);};

// ---------- race flow ----------
UI.launch = (rs,onDone,title)=>{UI.race=rs;UI.raceDone=onDone;UI.raceSpeed=G.settings.raceSpeed||1;
  $('race').classList.remove('hidden');$('rResult').classList.add('hidden');
  $('rTitle').textContent=title||((rs.series?D.SER[rs.series].n+' · ':'')+rs.def.n+(rs.rain?' ☔':''));UI.raceCtl();SFX.play('start');};
UI.raceClose = ()=>{UI.race=null;$('race').classList.add('hidden');$('rResult').classList.add('hidden');Save.save();UI.hud();const d=UI.deferPop;UI.deferPop=[];d.forEach(o=>UI.popup(o));};
UI.racePanel = (html,btns)=>{$('rResult').innerHTML=`<div class="pw">${html}<div class="grid2" style="margin-top:10px">${btns.map((b,i)=>`<button class="btn ${b.cls||''}" data-rb="${i}">${b.t}</button>`).join('')}</div></div>`;
  $('rResult').classList.remove('hidden');$('rResult').querySelectorAll('[data-rb]').forEach(el=>el.onclick=()=>{SFX.play('click');btns[+el.dataset.rb].fn();});};
UI.carry = (v,P)=>{v.hp=U.clamp(P.hp,0,1);if(v.eng)v.eng.cond=U.clamp(P.cond!=null?P.cond:v.eng.cond,0,1);};
UI.startRace = (def,v,s,tactic,sid,fmtId)=>{
  const fmt=sid?D.seriesFormat(def):(D.formats(def).find(f=>f.id===fmtId)||D.formats(def)[0]);
  const rivals=sid?G.series[sid].act.rivals:null;const pl={vid:v.id,sid:s.id,tactic};
  if(fmt.kind==='drag')return UI.dragStart(def,pl,sid,fmt,rivals);
  if(fmt.kind==='heats')return UI.heatsStart(def,pl,sid,fmt,rivals);
  if(fmt.kind==='tt'&&fmt.runs===2)return UI.hillStart(def,pl,sid,fmt,rivals);
  const rs=Race.create(def,pl,{fmt,series:sid,rivals});UI.launch(rs,rs=>UI.raceResult(rs));
};
// heats + main
UI.heatsStart = (def,pl,sid,fmt,rivals)=>{
  rivals=rivals||Race.mkRivals(def,[0,5,7,9,11,11][def.tier]);const sh=U.shuffle(rivals);const half=Math.floor(sh.length/2);const mine=sh.slice(0,half),other=sh.slice(half);
  const hf={id:'heat',kind:'mass',laps:fmt.heatLaps,mul:{prize:0,rp:0,fans:0,wear:0.5}};
  const rs=Race.create(def,pl,{fmt:hf,rivals:mine,series:sid});
  UI.launch(rs,rs=>{const v=E.veh(pl.vid);const P=rs.player;UI.carry(v,P);
    const myOrd=rs.order.map(e=>e.isPlayer?'P':e.ref);const oth=other.map(r=>({r,t:Race.quickTime(def,r,hf)})).sort((a,b)=>a.t-b.t).map(x=>x.r);
    const grid=[];for(let i=0;i<Math.max(myOrd.length,oth.length);i++){if(myOrd[i])grid.push(myOrd[i]);if(oth[i])grid.push(oth[i]);}
    const slot=grid.indexOf('P');const hp=myOrd.indexOf('P')+1;const dead=P.holed||P.destroyed||P.seized||P.hp<0.15||(P.cond!=null&&P.cond<=0.1);
    let h=`<div class="big">Heat ${P.dnf?'DNF':U.ord(hp)}</div><div class="sub" style="text-align:center">${U.esc(def.n)} — heat race</div><div class="stand">${rs.order.map((e,i)=>`<div class="${e.isPlayer?'me':''}">${i+1}. ${U.esc(e.isPlayer?G.team.name:e.team)}</div>`).join('')}</div>`;
    h+=dead?`<div class="note bd">Your machine can't make the main.</div>`:`<div class="note">Main event grid: you start <b class="hl">P${slot+1}</b> of ${grid.length}.</div>`;
    const startMain=()=>{const rs2=Race.create(def,pl,{fmt,series:sid,rivals,gridRivals:grid.filter(x=>x!=='P'),playerSlot:slot});rs2.heatWin=hp===1&&!P.dnf;UI.launch(rs2,r2=>UI.raceResult(r2));};
    const btns=dead?[{t:'See results',cls:'grn',fn:()=>{rs.fmt=fmt;P.dnf=true;UI.raceResult(rs);}}]:[{t:'🏁 Start Main',cls:'grn',fn:startMain}];
    if(!dead&&(T.has('quickchange')||T.mode()!=='sim'))btns.push({t:'⛽ Retune first',cls:'blue',fn:()=>UI.retune(pl.vid,rs.cond,'🏁 Main event is waiting','Start Main',startMain,()=>{rs.fmt=fmt;P.dnf=true;UI.raceResult(rs);})});
    UI.racePanel(h,btns);});
};
UI.retune = (vid,cond,label,btn,fn,cancel)=>{UI.race=null;$('race').classList.add('hidden');$('rResult').classList.add('hidden');
  UI.resume={label,btn,fn,cancel,cancelText:'Leave without running? You will take the result as it stands.'};UI.open('garage','fuel',{vid,cond,condRace:null});};
// drag eliminations
UI.dragStart = (def,pl,sid,fmt,rivals)=>{
  rivals=(rivals||Race.mkRivals(def,7)).slice(0,7);const field=U.shuffle([...rivals,'P']);
  UI.drag={def,pl,sid,fmt,alive:field,out:[],best:null,lastRs:null};UI.dragRound();};
UI.dragRound = ()=>{
  const d=UI.drag;const n=d.alive.length;const rn=n===8?'Quarterfinal':n===4?'Semifinal':'Final';const pairs=[];for(let i=0;i<n;i+=2)pairs.push([d.alive[i],d.alive[i+1]]);
  const mine=pairs.find(p=>p.includes('P'));const opp=mine[0]==='P'?mine[1]:mine[0];
  const rs=Race.create(d.def,d.pl,{fmt:d.fmt,rivals:[opp],series:d.sid});
  UI.launch(rs,rs=>{const v=E.veh(d.pl.vid);const P=rs.player;UI.carry(v,P);d.lastRs=rs;
    const O=rs.ents.find(e=>!e.isPlayer);const pt=P.fin?P.finT:Infinity,ot=O.fin?O.finT:Infinity;const win=!P.redlight&&pt<ot;
    if(rs.et){d.best=d.best?Math.min(d.best,rs.et.et):rs.et.et;if(rs.et.et<10)E.ach('ten');if(rs.et.et<9)E.ach('eights');}
    const oet=O.fin?Race.et(rs,O):null;
    const next=[];for(const p of pairs){if(p===mine){next.push(win?'P':opp);d.out.push({e:win?opp:'P',r:n});}else{const w=Race.quickTime(d.def,p[0],d.fmt)<Race.quickTime(d.def,p[1],d.fmt)?0:1;next.push(p[w]);d.out.push({e:p[1-w],r:n});}}
    d.alive=next;const dead=P.holed||P.destroyed||P.seized||P.hp<0.15||(P.cond!=null&&P.cond<=0.1);
    let h=`<div class="big">${rn}: ${win?'WIN!':'LOSS'}</div><div class="card"><div class="row"><span class="sp1">You${P.redlight?' — 🔴 RED LIGHT':''}</span><b>${rs.et?rs.et.et.toFixed(3)+'s @ '+rs.et.mph:'—'}</b></div>
      <div class="row"><span class="sp1">${U.esc(opp.team)}</span><b>${oet?oet.et.toFixed(3)+'s @ '+oet.mph:'—'}</b></div>${rs.et?`<div class="sub">Reaction ${rs.et.rt.toFixed(3)}s</div>`:''}</div>`;
    if(win&&d.alive.length>1&&!dead){h+=`<div class="note">${d.alive.length===2?'On to the FINAL!':'On to the semis!'}</div>`;
      const btns=[{t:'🚦 Next round',cls:'grn',fn:UI.dragRound}];if(T.mode()!=='sim'||T.has('quickchange'))btns.push({t:'⛽ Retune first',cls:'blue',fn:()=>UI.retune(d.pl.vid,rs.cond,'🚦 Next drag round is staging','Stage it',UI.dragRound,UI.dragFinish)});
      UI.racePanel(h,btns);}
    else{h+=`<div class="note">${win?'🏆 You won the eliminations!':'Out of the eliminations.'}</div>`;UI.racePanel(h,[{t:'Results',cls:'grn',fn:UI.dragFinish}]);}
  },`🚦 ${rn}${d.sid?' · '+D.SER[d.sid].n:''}`);};
UI.dragFinish = ()=>{
  const d=UI.drag;const rs=d.lastRs;const P=rs.player;
  // resolve remaining bracket if player out
  while(d.alive.length>1){const n=d.alive.length;const nx=[];for(let i=0;i<n;i+=2){const a=d.alive[i],b=d.alive[i+1];const w=a==='P'?0:b==='P'?1:(Race.quickTime(d.def,a,d.fmt)<Race.quickTime(d.def,b,d.fmt)?0:1);nx.push(w?b:a);d.out.push({e:w?a:b,r:n});}d.alive=nx;}
  const order=[d.alive[0]];[2,4,8].forEach(r=>d.out.filter(o=>o.r===r).forEach(o=>order.push(o.e)));
  const ents=order.map(x=>x==='P'?P:{team:x.team,col:x.col,isPlayer:false,dnf:false,fin:true});
  const pos=order.indexOf('P')+1;if(!P.holed&&!P.destroyed&&!P.seized)P.dnf=false;
  const pseudo=Object.assign({},rs,{order:ents,forcePos:pos,fmt:d.fmt,drag:true});
  UI.raceResult(pseudo,d.best?`Best ET ${d.best.toFixed(3)}s`:'');};
// hillclimb best of 2
UI.hillStart = (def,pl,sid,fmt,rivals)=>{rivals=rivals||Race.mkRivals(def,[0,5,7,9,11,11][def.tier]);UI.hill={def,pl,sid,fmt,rivals,run:1,best:new Map(),pBest:Infinity,lastRs:null};UI.hillRun();};
UI.hillRun = ()=>{
  const h0=UI.hill;const rs=Race.create(h0.def,h0.pl,{fmt:{...h0.fmt,kind:'tt'},rivals:h0.rivals,series:h0.sid});
  UI.launch(rs,rs=>{const v=E.veh(h0.pl.vid);const P=rs.player;UI.carry(v,P);h0.lastRs=rs;
    for(const e of rs.ents){const t=e.fin?e.finT:Infinity;if(e.isPlayer)h0.pBest=Math.min(h0.pBest,t);else h0.best.set(e.ref,Math.min(h0.best.get(e.ref)||Infinity,t));}
    const tab=[...h0.rivals.map(r=>({n:r.team,t:h0.best.get(r)})),{n:G.team.name,t:h0.pBest,me:true}].sort((a,b)=>a.t-b.t);
    const dead=P.holed||P.destroyed||P.seized||P.hp<0.15||(P.cond!=null&&P.cond<=0.1);
    let h=`<div class="big">Run ${h0.run}: ${P.fin?P.finT.toFixed(2)+'s':'DNF'}</div><div class="stand">${tab.slice(0,8).map((x,i)=>`<div class="${x.me?'me':''}">${i+1}. ${U.esc(x.n)} — ${isFinite(x.t)?x.t.toFixed(2)+'s':'DNF'}</div>`).join('')}</div>`;
    if(h0.run===1&&!dead){const go=()=>{h0.run=2;UI.hillRun();};
      UI.racePanel(h+`<div class="note">Best of two runs counts. The air gets thin up there — retune for the summit?</div>`,[{t:'⛰️ Run 2',cls:'grn',fn:go},{t:'⛽ Retune first',cls:'blue',fn:()=>UI.retune(h0.pl.vid,rs.cond,'⛰️ Run 2 is waiting at the start line','Start Run 2',go,UI.hillFinish)},{t:'Keep run 1',cls:'gray',fn:UI.hillFinish}]);}
    else UI.racePanel(h,[{t:'Results',cls:'grn',fn:UI.hillFinish}]);
  },`⛰️ Run ${h0.run} · ${h0.def.n}`);};
UI.hillFinish = ()=>{const h0=UI.hill;const rs=h0.lastRs;const P=rs.player;
  const list=[...h0.rivals.map(r=>({r,t:h0.best.get(r)})),{r:'P',t:h0.pBest}].sort((a,b)=>a.t-b.t);
  const ents=list.map(x=>x.r==='P'?P:{team:x.r.team,col:x.r.col,isPlayer:false,dnf:!isFinite(x.t),fin:isFinite(x.t)});const pos=list.findIndex(x=>x.r==='P')+1;
  if(isFinite(h0.pBest))P.dnf=false;const pseudo=Object.assign({},rs,{order:ents,forcePos:pos,fmt:h0.fmt});UI.raceResult(pseudo,isFinite(h0.pBest)?`Best run ${h0.pBest.toFixed(2)}s`:'');};

// ---------- race frame & result overrides ----------
UI.raceFrame = (dt)=>{
  const rs=UI.race;if(!rs)return;
  if(!rs.done&&!UI.popOpen){let t=dt*UI.raceSpeed;while(t>0){const s=Math.min(0.05,t);Race.step(rs,s);t-=s;if(rs.done)break;}}
  // lap timing for tests
  const P=rs.player;
  const cv=$('rcv');const c=cv.getContext('2d');c.setTransform(3,0,0,3,0,0);GX.drawRace(c,rs,dt*UI.raceSpeed);
  const pos=rs.order.indexOf(P)+1;const lap=Math.min(rs.tr.laps,Math.floor(Math.max(0,(rs.tt?P:rs.order[0]).prog)/rs.tr.lapLen)+1);
  const lapTxt=rs.drag?`${rs.t<rs.tree?'Staging':'Pass'}`:rs.tr.p2p?(rs.tr.laps>1?`Stage ${lap}/${rs.tr.laps}`:'Stage'):`Lap ${lap}/${rs.tr.laps}`;
  $('rInfo').innerHTML=`${lapTxt} · ${rs.test?`<b class="hl">${rs.t.toFixed(1)}s</b>`:`<b class="hl">${P.dnf&&!P.fin?'DNF':'P'+pos}</b>/${rs.ents.length}`}<br>HP <span style="color:${P.hp>0.5?'#8ef58e':P.hp>0.25?'#ffd84a':'#ff7070'}">${'█'.repeat(Math.max(0,Math.ceil(P.hp*10)))}${'░'.repeat(10-Math.max(0,Math.ceil(P.hp*10)))}</span>${P.cond!=null&&E.veh(P.vid)&&E.veh(P.vid).eng.fuel!=='none'?` · Eng <span style="color:${P.cond>0.5?'#8ef58e':P.cond>0.25?'#ffd84a':'#ff7070'}">${Math.max(0,Math.round(P.cond*100))}%</span>`:''}`;
  const m=rs.msgs[rs.msgs.length-1];$('rComm').textContent=m?m.text:'';
  if(rs.test){$('rBoard').innerHTML=`<div class="lr me"><span class="n">${U.esc(P.name)} — test session</span><span>${(P.lapT||[]).map(t=>t.toFixed(1)).join(' / ')}</span></div>`;}
  else{const L=rs.order[0];const vv=Math.max(0.1,L.v||1);const rows=rs.order.slice(0,8);if(!rows.includes(P))rows[7]=P;
    $('rBoard').innerHTML=rows.map(e=>{const p=rs.order.indexOf(e)+1;
      const gap=rs.tt||rs.drag?(e.fin?e.finT.toFixed(2)+'s':e.dnf?'DNF':'…'):e===L?(e.fin?'FIN':'Leader'):e.dnf&&!e.fin?'DNF':e.fin?'+'+(e.finT-L.finT).toFixed(1)+'s':'+'+Math.max(0,(L.prog-e.prog)/vv).toFixed(1)+'s';
      return `<div class="lr ${e.isPlayer?'me':''}"><span class="p">${p}.</span><span class="sw" style="background:${e.col}"></span><span class="n">${U.esc(e.isPlayer?G.team.name+' ('+e.name+')':e.team)}</span><span>${gap}</span></div>`;}).join('');}
  if(rs.done&&!rs.resolved){rs.resolved=true;setTimeout(()=>(UI.raceDone||UI.raceResult)(rs),700);}
};
const _raceResult=UI.raceResult;
UI.raceResult = (rs,extra)=>{
  _raceResult(rs);
  const pw=$('rResult').querySelector('.pw');
  if(extra&&pw){const d=document.createElement('div');d.className='sub';d.style.textAlign='center';d.textContent=extra;pw.insertBefore(d,pw.children[2]);}
  const P=rs.player;const v=E.veh(P.vid);
  if(pw&&v&&v.eng&&v.eng.fuel!=='none'){const d=document.createElement('div');d.className='sub';d.innerHTML=`Engine ${Math.round(v.eng.cond*100)}%${P.holed?' — <b class="bd">holed a piston!</b>':P.seized?' — <b class="bd">seized!</b>':''}${rs.fuelCost?` · fuel ${U.money(rs.fuelCost)}`:''}`;pw.insertBefore(d,pw.querySelector('.sec-h'));}
  const btn=$('rResult').querySelector('[data-r2]');if(btn)btn.onclick=()=>{SFX.play('click');UI.raceClose();};
};

// ---------- bench animation hook ----------
UI.benchFrame = dt=>{
  if(UI.view!=='garage'||!UI.sel.vid)return;const v=E.veh(UI.sel.vid);if(!v||!v.eng||v.eng.fuel==='none')return;Bench.tick(dt);const cond=UI.cond();let ev=null;
  const g=(id)=>{const cv=$(id);if(!cv)return null;const c=cv.getContext('2d');c.setTransform(3,0,0,3,0,0);c.imageSmoothingEnabled=false;return c;};
  let c=g('benchCv');if(c&&v.eng.fuel==='carb'){ev=T.eval(v,cond);Bench.drawCarb(c,v,ev,dt);}
  c=g('chartCv');if(c){ev=ev||T.eval(v,cond);Bench.drawChart(c,ev);}
  c=g('syncCv');if(c)Bench.drawSync(c,v,dt);
  c=g('dynoCv');if(c){const d=Bench.s.dyno;if(d&&d.vid===v.id){Bench.dynoStep(v,dt);if(d.done&&!d.logged){d.logged=true;Bench.dynoDone(v);}}Bench.drawDyno(c,v,dt);}
};
