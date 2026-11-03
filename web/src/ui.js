// ===================== UI =====================
const UI = {view:null,tab:null,sel:{},popQ:[],popOpen:false,race:null,raceSpeed:1,deferPop:[]};
const $ = id=>document.getElementById(id);
UI.paused = ()=>!!(UI.view||UI.popOpen||UI.race||!G||Object.values(G.series).some(s=>s.act&&s.act.pending));

// ---------- toast / popup ----------
UI.toast = (t)=>{const el=document.createElement('div');el.textContent=t;$('toast').appendChild(el);while($('toast').children.length>3)$('toast').firstChild.remove();setTimeout(()=>el.remove(),2600);};
UI.popup = (o)=>{UI.popQ.push(o);if(!UI.popOpen)UI.nextPop();};
UI.nextPop = ()=>{const o=UI.popQ.shift();if(!o){UI.popOpen=false;$('pop').classList.add('hidden');return;}
  UI.popOpen=true;const btns=o.buttons||[{t:'OK'}];
  $('pop').innerHTML=`<div class="pw"><div class="ph">${o.title||''}</div><div class="pb">${o.html||''}</div><div class="pf">${btns.map((b,i)=>`<button class="btn ${b.cls||''}" data-i="${i}">${b.t}</button>`).join('')}</div></div>`;
  $('pop').classList.remove('hidden');
  $('pop').querySelectorAll('.pf button').forEach(el=>el.onclick=()=>{SFX.play('click');const b=btns[+el.dataset.i];let keep=false;if(b.fn)keep=b.fn($('pop'))===false;if(!keep)UI.nextPop();UI.hud();if(UI.view)UI.render();});
  if(o.after)o.after($('pop'));};
UI.confirm = (title,html,fn,yes='Yes',cls='red')=>UI.popup({title,html,buttons:[{t:'Cancel',cls:'gray'},{t:yes,cls,fn}]});

// ---------- HUD ----------
UI.hud = ()=>{if(!G)return;
  $('tDate').textContent=E.dateStr();$('tMoney').textContent=U.money(G.money);$('tMoney').style.color=G.money<0?'#ff7070':'';
  $('tRP').textContent='RP '+U.num(G.rp);$('tFans').textContent='♥ '+U.num(G.fans);
  const sp=G.settings.speed;document.querySelectorAll('#top .sp button').forEach(b=>b.classList.toggle('on',b.dataset.s==='f'?sp>=2:+b.dataset.s===sp));$('tFast').textContent=sp===4?'4×':'2×';
  const lg=G.log[0];$('ticker').textContent=lg?`${E.dateStr(lg.d)} · ${lg.t}`:'';
  // next bar
  let nb='';const act=Object.entries(G.series).filter(([k,v])=>v.act);
  if(act.length){const[id,s]=act.sort((a,b)=>a[1].act.next-b[1].act.next)[0];const S=D.SER[id];const r=D.RACE[S.rounds[s.act.round]];
    nb=`🏁 ${S.n} R${s.act.round+1}: ${r.n} — ${Math.max(0,s.act.next-G.day)}d`;}
  else{const ready=E.availRaceIds().length;nb=G.vehicles.length?`🏁 ${ready} event${ready===1?'':'s'} open · tap to race`:'🔧 Tap Build to make your first vehicle!';}
  $('nextbar').textContent=nb;
  // activity
  let h='';
  if(G.jobs.length){h+=`<div class="hd">WORKSHOP (${G.jobs.length}/${E.bays()} bays)</div>`;
    for(const j of G.jobs){const v=E.veh(j.vid);if(!v)continue;const pr=U.clamp(1-j.left/j.total,0,1);const nm=j.type==='build'?'Build':j.type==='up'?'Tune '+j.k.toUpperCase():'Repair';
      h+=`<div class="row"><span class="lbl">${nm} · ${U.esc(v.name)}</span><span class="bar"><i style="width:${pr*100}%;background:${j.type==='rep'?'#ff7a7a':j.type==='up'?'#7ac8ff':'#8ef58e'}"></i></span></div>`;}}
  h+=`<div class="hd">DRIVERS</div>`;
  for(const s of E.drivers())h+=`<div class="row"><span class="lbl">${U.esc(s.name)}</span><span class="bar"><i style="width:${s.energy/s.maxE*100}%;background:linear-gradient(90deg,#ffb347,#8ef58e)"></i></span><span style="width:30px;text-align:right">${Math.round(s.energy)}</span></div>`;
  if(G.vehicles.length){h+=`<div class="hd">VEHICLES (${G.vehicles.length}/${E.ws().veh})</div>`;
    for(const v of G.vehicles)h+=`<div class="row"><span class="lbl">${U.esc(v.name)}</span><span class="bar"><i style="width:${v.hp*100}%;background:${v.hp>0.5?'#8ef58e':v.hp>0.25?'#ffd84a':'#ff7a7a'}"></i></span><span style="width:52px;text-align:right;font-size:11px">${{ready:'Ready',build:'Build',upgrade:'Tune',repair:'Repair'}[v.status]}</span></div>`;}
  h+=`<div class="hd">NEWS</div>`+G.log.slice(0,8).map(l=>`<div class="nw">${E.dateStr(l.d)} · ${U.esc(l.t)}</div>`).join('');
  $('activity').innerHTML=h;
  // badges
  const bR=$('mRace').querySelector('.badge');const can=E.canUpgradeWS();$('mTeam').querySelector('.badge').classList.toggle('hidden',!can);
  bR.classList.toggle('hidden',!E.availRaceIds().some(id=>D.SER[id]));
  $('mSpon').querySelector('.badge').classList.toggle('hidden',!(G.spons.length<E.ws().spon&&E.sponsorOffers().length));
};

// ---------- window ----------
UI.open = (view,tab,sel)=>{UI.view=view;UI.tab=tab||null;UI.sel=sel||{};$('ov').classList.remove('hidden');UI.render();SFX.play('click');};
UI.close = ()=>{
  if(UI.view==='prerace'&&UI.sel.sid){UI.confirm('Skip this round?','You will score no points this round.',()=>{E.seriesRoundSkip(UI.sel.sid);UI.view=null;$('ov').classList.add('hidden');UI.hud();});return;}
  UI.view=null;$('ov').classList.add('hidden');UI.hud();};
UI.render = ()=>{
  if(!UI.view)return;const V=UI.V[UI.view](UI.tab);if(!V){UI.close();return;}
  if(V.tabs&&!UI.tab)UI.tab=V.tabs[0][0];
  const body=$('wbody');const st=body.scrollTop;const same=UI._last===UI.view+'|'+UI.tab+'|'+(V.key||'');
  $('wtitle').innerHTML=V.title;$('wback').classList.toggle('hidden',!V.back);$('wback').dataset.a=V.back||'';
  $('wtabs').innerHTML=(V.tabs||[]).map(t=>`<button data-tab="${t[0]}" class="${t[0]===UI.tab?'on':''}">${t[1]}</button>`).join('');$('wtabs').classList.toggle('hidden',!V.tabs);
  body.innerHTML=V.html;body.scrollTop=same?st:0;UI._last=UI.view+'|'+UI.tab+'|'+(V.key||'');
  body.querySelectorAll('canvas[data-track]').forEach(cv=>{const r=D.RACE[cv.dataset.track];cv.width=600;cv.height=252;const c=cv.getContext('2d');c.scale(3,3);c.imageSmoothingEnabled=false;
    GX.P(c,0,0,200,84,'#13182a');GX.drawTrack(c,r,Race.track(r,false),[100,42,92,34],3);});
};
UI.click = (e)=>{
  const tb=e.target.closest('[data-tab]');if(tb&&tb.closest('#wtabs')){UI.tab=tb.dataset.tab;SFX.play('click');UI.render();return;}
  const el=e.target.closest('[data-a]');if(!el||!el.dataset.a)return;const a=el.dataset.a;
  if(el.disabled)return;
  if(UI.A[a]){SFX.play('click');UI.A[a](el.dataset,el);UI.hud();if(UI.view)UI.render();}
};

// ---------- helpers ----------
UI.sbar = (lab,v,max,col)=>`<div class="sbar"><b>${lab}</b><span class="bar"><i style="width:${U.clamp(v/max*100,2,100)}%;background:${col}"></i></span><span>${Math.round(v)}</span></div>`;
UI.terrChips = (t)=>`<div class="chips">${['on','off','wet','ice'].map(k=>`<span class="chip" style="color:${t[k]>=115?'#8ef58e':t[k]<70?'#ff9a9a':'#fff'}">${D.TERR_N[k]} ${Math.round(t[k])}</span>`).join('')}</div>`;
UI.surfBar = (r)=>{const tot=U.sum(Object.values(r.surf));return `<div class="surfbar">${Object.entries(r.surf).map(([k,w])=>`<i style="flex:${w};background:${D.SURF[k].col}" title="${D.SURF[k].n}"></i>`).join('')}</div>`;};
UI.surfChips = (r)=>`<div class="chips">${Object.keys(r.surf).map(k=>`<span class="chip" style="border-color:${D.SURF[k].col}">${D.SURF[k].n}</span>`).join('')}<span class="chip">${r.laps} lap${r.laps>1?'s':''}</span><span class="chip">Rating ${r.R}</span></div>`;
UI.statMax = ()=>[0,140,260,520,900,1200][G.ws]||1200;
UI.vehStats = (st)=>{const m=UI.statMax();return UI.sbar('SPD',st.spd,m,'#ff8a5c')+UI.sbar('ACC',st.acc,m,'#ffd84a')+UI.sbar('HND',st.hnd,m,'#7ac8ff')+UI.sbar('DUR',st.dur,m*1.3,'#8ef58e');};
UI.medal = id=>{const b=E.best(id);return b===1?'🥇':b===2?'🥈':b===3?'🥉':b<99?`<span class="sub">${U.ord(b)}</span>`:'';};
UI.sparkChips = (act)=>{const s=G.sparks;if(!s.b&&!s.s&&!s.g)return'';const cur=UI.sel.spark||'';
  return `<div class="note">✨ Use a Spark? <span class="chips" style="display:inline-flex">${[['','None'],['b',`Bronze ×${s.b}`],['s',`Silver ×${s.s}`],['g',`Gold ×${s.g}`]].filter(x=>!x[0]||s[x[0]]).map(x=>`<button class="chip ${cur===x[0]?'on':''}" data-a="spark" data-v="${x[0]}">${x[1]}</button>`).join('')}</span></div>`;};

// ---------- VIEWS ----------
UI.V = {};
UI.A = {};
UI.A.spark = d=>{UI.sel.spark=d.v||'';};

// RACE LIST
UI.V.race = (tab)=>{
  const maxT=E.legendOpen()?5:G.ws;UI.sel.tier=UI.sel.tier||Math.min(maxT,G.ws);
  let h=`<div class="tier-chips">${[1,2,3,4,5].map(t=>`<button data-a="tier" data-t="${t}" class="${UI.sel.tier===t?'on':''}">${t<=maxT?'':'🔒'}${D.TIER_N[t]}</button>`).join('')}</div>`;
  const T=UI.sel.tier;
  if(tab==='races'){
    for(const disc of Object.keys(D.DISC)){const rs=D.RACES.filter(r=>r.tier===T&&r.disc===disc&&!r.excl);if(!rs.length)continue;
      h+=`<div class="sec-h">${D.DISC[disc].ic} ${D.DISC[disc].n}</div>`;
      for(const r of rs){const st=E.raceState(r.id);const rr=G.races[r.id];
        h+=`<div class="card ${st.ok?'':'lock'}"><div class="row"><div class="sp1"><b>${U.esc(r.n)}</b> ${UI.medal(r.id)}${UI.surfBar(r)}${UI.surfChips(r)}
          <div class="sub">Prize ${U.money(r.prize)}${rr?` · ran ${rr.n}× · won ${rr.w}×`:''}${G.yearWins[r.id]?' · <span class="hl">won this year (reduced prize)</span>':''}</div>${st.ok?'':`<div class="sub hl">🔒 ${st.why}</div>`}</div>
          ${st.ok?`<button class="btn" data-a="pick" data-rid="${r.id}">Enter</button>`:''}</div></div>`;}
    }
  }else{
    for(const S of D.SERIES.filter(s=>s.tier===T)){const st=E.seriesState(S.id);const sv=G.series[S.id]||{};
      h+=`<div class="card ${st.ok||st.active?'':'lock'} ${sv.titles?'done':''}"><div class="row"><div class="sp1"><b>${D.DISC[S.disc].ic} ${U.esc(S.n)}</b> ${sv.titles?`🏆×${sv.titles}`:''}
        <div class="sub">${S.rounds.length} rounds · ${S.rivals+1} teams · Champion ${U.money(S.prize)} · Entry ${U.money(S.fee)}</div>
        <div class="chips">${S.rounds.map((rid,i)=>`<span class="chip ${sv.act&&sv.act.round===i?'on':''}">${i+1}. ${U.esc(D.RACE[rid].n)}${sv.act&&sv.act.res[i]!=null?' → '+sv.act.res[i]:''}</span>`).join('')}</div>
        ${sv.act?`<div class="stand" style="margin-top:4px">${E.standings(S.id).slice(0,5).map((x,i)=>`<div class="${x[0]==='you'?'me':''}">${i+1}. ${U.esc(x[0]==='you'?G.team.name:x[0])} — ${x[1]} pts</div>`).join('')}</div><div class="sub hl">Next round in ${Math.max(0,sv.act.next-G.day)} days</div>`:''}
        ${st.ok||st.active?'':`<div class="sub hl">🔒 ${st.why}</div>`}</div>${st.ok?`<button class="btn" data-a="enterSeries" data-sid="${S.id}">Enter</button>`:''}</div></div>`;}
    h=`<div class="note">Win normal races to unlock a series. Win a series to unlock a bigger workshop. Points: ${D.POINTS.slice(0,5).join('-')}…</div>`+h;
  }
  return {title:'🏁 Races',tabs:[['races','Races'],['series','Series']],html:h};
};
UI.A.tier = d=>{UI.sel.tier=+d.t;};
UI.A.pick = d=>{UI.view='prerace';UI.sel={rid:d.rid,back:'race',tier:UI.sel.tier};UI.tab=null;};
UI.A.enterSeries = d=>{const S=D.SER[d.sid];UI.confirm(`Enter ${S.n}?`,`Entry fee ${U.money(S.fee)}. ${S.rounds.length} rounds, one every 3 weeks. Each round you choose which team runs.`,()=>{E.enterSeries(d.sid);},'Enter','grn');};

// PRE-RACE
UI.V.prerace = ()=>{
  const r=D.RACE[UI.sel.rid];const tr=Race.track(r,false);const sid=UI.sel.sid;
  const vs=E.eligibleVehicles(r);const ds=E.drivers();
  if(UI.sel.vid&&!vs.find(v=>v.id===UI.sel.vid))UI.sel.vid=null;
  if(!UI.sel.vid&&vs.length){UI.sel.vid=vs.map(v=>({v,o:ds[0]?E.oddsRatio(r,v,ds[0]):0})).sort((a,b)=>b.o-a.o)[0].v.id;}
  const okD=E.eligibleDrivers();if(UI.sel.sid2&&!okD.find(s=>s.id===UI.sel.sid2))UI.sel.sid2=null;
  if(!UI.sel.sid2&&okD.length)UI.sel.sid2=okD.slice().sort((a,b)=>b.energy-a.energy)[0].id;
  UI.sel.tactic=UI.sel.tactic||'normal';
  const cnt={};tr.secs.forEach(s=>cnt[s.type]=(cnt[s.type]||0)+1);
  let h='';
  if(sid){const S=D.SER[sid],a=G.series[sid].act;h+=`<div class="note"><b class="hl">${U.esc(S.n)}</b> — Round ${a.round+1}/${S.rounds.length}. ${a.round>0?'You have '+(a.pts.you||0)+' pts.':''}</div>`;}
  h+=`<canvas class="trkcv" data-track="${r.id}"></canvas>${UI.surfBar(r)}${UI.surfChips(r)}
    <div class="chips">${Object.entries(cnt).map(([k,n])=>`<span class="chip">${D.SEC[k].n} ×${n}</span>`).join('')}<span class="chip">${D.DISC[r.disc].ic} ${r.cls==='any'?'Cars & Bikes':r.cls==='car'?'Cars only':'Bikes only'}</span></div>`;
  h+=`<div class="sec-h">Vehicle</div>`;
  if(!vs.length)h+=`<div class="note">No ready ${r.cls==='any'?'':r.cls} vehicle! ${G.vehicles.some(v=>E.clsOk(r,v))?'Your eligible vehicles are busy (building, tuning or repairing).':'Build one first.'}</div>`;
  for(const v of vs){const st=E.vs(v);const b=D.BODY[v.body];
    h+=`<div class="card ${UI.sel.vid===v.id?'sel':''}" data-a="selV" data-v="${v.id}"><div class="row"><img class="vth" src="${GX.thumb(b.kind,G.team.color,'#ffd84a')}"><div class="sp1"><b>${U.esc(v.name)}</b> <span class="sub">Lv${v.lv} · HP ${Math.round(v.hp*100)}%</span>
      <div class="sub">SPD ${st.spd} · ACC ${st.acc} · HND ${st.hnd} · DUR ${st.dur}</div>${UI.terrChips(st)}</div></div></div>`;}
  h+=`<div class="sec-h">Driver</div>`;
  for(const s of ds){const ok=s.energy>=E.raceEnergy(s);
    h+=`<div class="card ${UI.sel.sid2===s.id?'sel':''} ${ok?'':'lock'}" ${ok?`data-a="selD" data-v="${s.id}"`:''}><div class="row"><img class="face" src="${GX.face(s)}"><div class="sp1"><b>${U.esc(s.name)}</b> ${s.trait?`<span class="chip">${D.TRAITS[s.trait].n}</span>`:''}
      <div class="sub">Pedal ${s.pedal} · Shift ${s.shift} · Steer ${s.steer} · Car ${s.aff.car}× · Bike ${s.aff.bike}×</div><div class="ebar"><i style="width:${s.energy/s.maxE*100}%"></i></div>${ok?'':'<div class="sub bd">Too tired to race</div>'}</div></div></div>`;}
  h+=`<div class="sec-h">Tactic</div><div class="chips">${Object.entries(Race.TAC).map(([k,t])=>`<button class="chip ${UI.sel.tactic===k?'on':''}" style="padding:5px 10px;font-size:13px" data-a="selT" data-v="${k}">${t.n}</button>`).join('')}</div>
    <div class="sub" style="margin-top:3px">Safe: fewer mistakes, less wear. Push: faster, riskier, more wear.</div>`;
  const v=E.veh(UI.sel.vid),s=E.staff(UI.sel.sid2);
  if(v&&s){const o=E.oddsRatio(r,v,s);const[l,c]=E.oddsLabel(o);h+=`<div class="note" style="margin-top:8px;text-align:center;font-size:15px">Outlook: <b style="color:${c}">${l}</b> <span class="sub">(${Math.round(o*100)}% of field pace)</span></div>
    <button class="btn big grn" data-a="go">🏁 START RACE</button>`;}
  if(sid)h+=`<div style="margin-top:8px"><button class="btn gray big" data-a="skipRound">Skip this round</button></div>`;
  return {title:`${D.DISC[r.disc].ic} ${U.esc(r.n)}`,html:h,back:sid?null:'backRace',key:r.id};
};
UI.A.backRace = ()=>{UI.view='race';UI.tab='races';};
UI.A.selV = d=>{UI.sel.vid=+d.v;};
UI.A.selD = d=>{UI.sel.sid2=+d.v;};
UI.A.selT = d=>{UI.sel.tactic=d.v;};
UI.A.skipRound = ()=>{const sid=UI.sel.sid;UI.confirm('Skip this round?','You will score no points this round.',()=>{E.seriesRoundSkip(sid);UI.view=null;$('ov').classList.add('hidden');});};
UI.A.go = ()=>{const r=D.RACE[UI.sel.rid];const v=E.veh(UI.sel.vid),s=E.staff(UI.sel.sid2);if(!v||!s)return;
  if(s.energy<E.raceEnergy(s)){UI.toast('Driver too tired');return;}
  UI.view=null;$('ov').classList.add('hidden');UI.startRace(r,v,s,UI.sel.tactic,UI.sel.sid);};

// BUILD
UI.V.build = (tab)=>{
  const cls=tab||'car';let h='';
  h+=`<div class="note">Garage ${G.vehicles.length}/${E.ws().veh} · Bays busy ${G.jobs.length}/${E.bays()} · Team Tech ${Math.round(E.teamTech())}</div>`;
  if(UI.sel.body){const b=D.BODY[UI.sel.body];
    if(UI.sel.layout){const L=D.LAYOUT[UI.sel.layout];const cost=E.vehCost(b.id,L.id)+E.sysCost(b.id,L.id,UI.sel.sys);const q=E.buildQ(b.id)+(UI.sel.spark?{b:0.1,s:0.2,g:0.3}[UI.sel.spark]:0);
      const job={req:D.RANK_REQ[b.rank],nob:false};const days=Math.ceil(b.days/(U.clamp(0.5+0.7*E.teamTech()/job.req,0.5,2.6)*(1+E.facV('speed')/100)));
      h+=`<div class="card"><div class="row"><img class="vth" src="${GX.thumb(b.kind,G.team.color,'#ffd84a')}"><div class="sp1"><b>${U.esc(b.n)}</b> <span class="rk rk${b.rank}">${b.rank}</span> · ${L.n}
        <div class="sub">${L.d}</div><div class="sub hl">${UI.sel.sys?(UI.sel.sys.type==='efi'?'💻 EFI':D.CARBS[UI.sel.sys.carb].n):''}</div></div></div>
        <div class="sec-h">Estimate</div><div class="sub">Team skill vs. this vehicle: <b class="${q>=1?'gd':'bd'}">${Math.round(q*100)}%</b> → stats ≈ ${Math.round(E.qMult(Math.min(1.6,q))*100)}% of spec</div>
        <div class="sub">Build time ≈ ${days} days · Cost <b class="hl">${U.money(cost)}</b></div>
        ${UI.sparkChips()}
        <button class="btn big grn" data-a="doBuild" ${G.money<cost?'disabled':''}>🔧 Build for ${U.money(cost)}</button></div>`;
      return {title:'🔧 Build',html:h,back:'bBackL',key:'c'};}
    h+=`<div class="sec-h">${b.cls==='car'?'Drive layout':'Engine type'} for ${U.esc(b.n)}</div>`;
    for(const L of D.LAYOUTS.filter(l=>l.cls===b.cls)){const ok=G.res.layout[L.id];
      const mods=Object.entries(L.m).map(([k,v])=>`${k.toUpperCase()} ${v>0?'+':''}${v}%`).concat(Object.entries(L.t).map(([k,v])=>`${D.TERR_N[k]} ${v>0?'+':''}${v}`)).join(' · ');
      h+=`<div class="card ${ok?'':'lock'}" ${ok?`data-a="selL" data-v="${L.id}"`:''}><div class="row"><div class="sp1"><b>${L.n}</b> <span class="sub">cost +${Math.round(L.cm*100)}%</span><div class="sub">${L.d}</div><div class="sub hl">${mods||'No modifiers'}</div></div>
        ${ok?`<span class="hl">${U.money(E.vehCost(b.id,L.id))}</span>`:`<span class="sub">🔒 Research</span>`}</div></div>`;}
    return {title:'🔧 Build',html:h,back:'bBackB',key:'l'};
  }
  const bodies=D.BODIES.filter(b=>b.cls===cls&&G.res.body[b.id]);
  if(!bodies.length)h+=`<div class="note">No ${cls}s researched yet. Visit 🔬 Research.</div>`;
  for(const b of bodies){
    h+=`<div class="card" data-a="selB" data-v="${b.id}"><div class="row"><img class="vth" src="${GX.thumb(b.kind,G.team.color,'#ffd84a')}"><div class="sp1"><b>${U.esc(b.n)}</b><span class="rk rk${b.rank}">${b.rank}</span>
      <div class="sub">SPD ${b.s.spd} · ACC ${b.s.acc} · HND ${b.s.hnd} · DUR ${b.s.dur} · ${b.slots} slots</div>${UI.terrChips(b.t)}
      <div class="sub">From ${U.money(b.cost)} · ${b.days} days · Team skill ${Math.round(E.buildQ(b.id)*100)}%</div></div></div></div>`;}
  const locked=D.BODIES.filter(b=>b.cls===cls&&!G.res.body[b.id]).length;if(locked)h+=`<div class="sub" style="text-align:center">${locked} more ${cls}s to discover in 🔬 Research</div>`;
  return {title:'🔧 Build',tabs:[['car','🚗 Cars'],['bike','🏍️ Bikes']],html:h};
};
UI.A.selB = d=>{UI.sel={body:d.v};};
UI.A.selL = d=>{UI.sel.layout=d.v;UI.sel.spark='';};
UI.A.bBackB = ()=>{UI.tab=D.BODY[UI.sel.body].cls;UI.sel={};};
UI.A.bBackL = ()=>{UI.sel.layout=null;};
UI.A.doBuild = ()=>{const v=E.startBuild(UI.sel.body,UI.sel.layout,UI.sel.spark||null);if(v){UI.close();}};

// GARAGE
UI.V.garage = (tab)=>{
  if(UI.sel.vid){const v=E.veh(UI.sel.vid);if(!v){UI.sel={};return UI.V.garage();}return UI.V.vehicle(v,tab);}
  let h=`<div class="note">${G.vehicles.length}/${E.ws().veh} vehicles · Tap one to tune, fit parts, repair or sell.</div>`;
  if(!G.vehicles.length)h+=`<div class="note">Empty garage! Use 🔧 Build.</div>`;
  for(const v of G.vehicles){const b=D.BODY[v.body],st=E.vs(v);
    h+=`<div class="card" data-a="selVeh" data-v="${v.id}"><div class="row"><img class="vth" src="${GX.thumb(b.kind,G.team.color,'#ffd84a')}"><div class="sp1">
      <b>${U.esc(v.name)}</b><span class="rk rk${b.rank}">${b.rank}</span> <span class="sub">${D.LAYOUT[v.layout].n} · Lv${v.lv} · ${v.wins}W/${v.races}R</span>
      <div class="sub">${{ready:'<span class="gd">Ready</span>',build:'Building…',upgrade:'Tuning…',repair:'<span class="bd">Repairing</span>'}[v.status]} · HP ${Math.round(v.hp*100)}% · Parts ${v.parts.length}/${b.slots}</div>
      ${v.status==='build'?'':UI.vehStats(st)+UI.terrChips(st)}</div></div></div>`;}
  return {title:'🚗 Garage',html:h};
};
UI.A.selVeh = d=>{UI.sel={vid:+d.v};UI.tab='info';};
UI.A.gBack = ()=>{UI.sel={};UI.tab=null;};
UI.V.vehicle = (v,tab)=>{
  const b=D.BODY[v.body],st=E.vs(v);tab=tab||'info';let h='';
  h+=`<div class="card"><div class="row"><img class="vth" src="${GX.thumb(b.kind,G.team.color,'#ffd84a')}"><div class="sp1"><b>${U.esc(v.name)}</b><span class="rk rk${b.rank}">${b.rank}</span>
    <div class="sub">${b.cls==='car'?'Car':'Bike'} · ${D.LAYOUT[v.layout].n} · Lv${v.lv} (${v.xp}/${E.vehXpNeed(v)} xp) · build quality ${Math.round(E.qMult(Math.min(1.6,v.q))*100)}%</div>
    <div class="sub">Status: ${v.status} · HP ${Math.round(v.hp*100)}% · ${v.wins} wins / ${v.races} races</div></div></div></div>`;
  if(v.status==='build')return {title:'🚗 '+U.esc(v.name),html:h+`<div class="note">Still being built…</div>`,back:'gBack'};
  if(tab==='info'){
    h+=`<div class="card">${UI.vehStats(st)}${UI.terrChips(st)}<div class="sub" style="margin-top:4px">Ad appeal ${st.adv}${st.fx.rp?` · RP +${Math.round(st.fx.rp*100)}%`:''}${st.fx.mis<1?` · mistakes -${Math.round((1-st.fx.mis)*100)}%`:''}${st.fx.wear<1?` · wear -${Math.round((1-st.fx.wear)*100)}%`:''}</div></div>`;
    if(v.status==='repair')h+=`<button class="btn big" data-a="rush">⚡ Rush repair ${U.money(E.rushCost(v))}</button>`;
    h+=`<div class="grid2" style="margin-top:8px"><button class="btn blue" data-a="sell">Sell ${U.money(E.sellValue(v))}</button><button class="btn red" data-a="scrap">Scrap +${E.scrapRP(v)} RP</button></div>`;
  }else if(tab==='tune'){
    h+=`<div class="note">Each stat can be tuned 5 times. Mechanics' Tech and facilities boost the gain.</div>`;
    for(const k of['spd','acc','hnd','dur']){const lv=v.up[k];const c=E.upCost(v,k);
      h+=`<div class="card"><div class="row"><div class="sp1"><b>${{spd:'Speed',acc:'Acceleration',hnd:'Handling',dur:'Durability'}[k]}</b> <span class="hl">${'■'.repeat(lv)}${'□'.repeat(5-lv)}</span><div class="sub">Current ${st[k]} (+${v.upAdd[k]} from tuning)</div></div>
        ${lv<5?`<button class="btn" data-a="tune" data-k="${k}" ${v.status!=='ready'||G.money<c?'disabled':''}>${U.money(c)}</button>`:'<span class="gd">MAX</span>'}</div></div>`;}
    h+=UI.sparkChips();if(v.status!=='ready')h+=`<div class="note">Vehicle must be Ready to tune.</div>`;
  }else if(tab==='parts'){
    h+=`<div class="note">Slots ${v.parts.length}/${b.slots}. One part per category — installing replaces the old one. Parts level up with racing.</div><div class="sec-h">Installed</div>`;
    if(!v.parts.length)h+=`<div class="sub">None</div>`;
    for(const pid of v.parts){const P=D.PART[pid];h+=`<div class="card"><div class="row"><div class="sp1"><b>${P.n}</b> <span class="sub">${D.PART_CATS[P.cat]} · Lv${E.partLv(pid)}</span><div class="sub hl">${UI.partFx(P)}</div></div><button class="btn sm red" data-a="rmPart" data-p="${pid}">Remove</button></div></div>`;}
    h+=`<div class="sec-h">Available</div>`;
    const avail=D.PARTS.filter(P=>G.res.part[P.id]&&E.partClsOk(P,b.cls)&&!v.parts.includes(P.id));
    if(!avail.length)h+=`<div class="sub">Research parts in 🔬 Research.</div>`;
    for(const P of avail){const c=E.partCost(P.id);const rep=v.parts.find(x=>D.PART[x].cat===P.cat);
      h+=`<div class="card"><div class="row"><div class="sp1"><b>${P.n}</b> <span class="sub">${D.PART_CATS[P.cat]} · T${P.tier}${rep?` · replaces ${D.PART[rep].n}`:''}</span><div class="sub hl">${UI.partFx(P)}</div></div><button class="btn sm" data-a="instPart" data-p="${P.id}" ${G.money<c?'disabled':''}>${U.money(c)}</button></div></div>`;}
  }
  return {title:'🚗 '+U.esc(v.name),tabs:[['info','Info'],['tune','Tune'],['parts','Parts']],html:h,back:'gBack',key:v.id};
};
UI.partFx = P=>{const a=Object.entries(P.st).map(([k,x])=>`${k in D.TERR_N?D.TERR_N[k]:k.toUpperCase()} ${x>0?'+':''}${x}`);
  if(P.fx.rp)a.push(`RP +${P.fx.rp*100}%`);if(P.fx.mis)a.push(`Mistakes -${Math.round((1-P.fx.mis)*100)}%`);if(P.fx.wear)a.push(`Wear -${Math.round((1-P.fx.wear)*100)}%`);if(P.fx.fan)a.push(`Fans +${P.fx.fan*100}%`);return a.join(' · ');};
UI.A.tune = d=>{E.startUpgrade(UI.sel.vid,d.k,UI.sel.spark||null);UI.sel.spark='';};
UI.A.rush = ()=>{E.rushRepair(UI.sel.vid);};
UI.A.sell = ()=>{const v=E.veh(UI.sel.vid);UI.confirm('Sell vehicle?',`Sell ${U.esc(v.name)} for ${U.money(E.sellValue(v))}?`,()=>{E.sell(v.id);UI.sel={};});};
UI.A.scrap = ()=>{const v=E.veh(UI.sel.vid);UI.confirm('Scrap vehicle?',`Scrap ${U.esc(v.name)} for ${E.scrapRP(v)} research data?`,()=>{E.scrap(v.id);UI.sel={};});};
UI.A.instPart = d=>{E.installPart(UI.sel.vid,d.p);};
UI.A.rmPart = d=>{UI.confirm('Remove part?','The part will be discarded.',()=>E.removePart(UI.sel.vid,d.p));};

// RESEARCH
UI.V.research = (tab)=>{
  tab=tab||'car';let h=`<div class="note">Research Data: <b class="bl">${G.rp} RP</b>. Earned from races (driver & mechanic Analysis boost it), scrapping and events.</div>`;
  const item=(kind,o,av,extra)=>`<div class="card ${av.done?'done':av.ok?'':'lock'}"><div class="row">${extra||''}<div class="sp1"><b>${U.esc(o.n)}</b>${o.rank?`<span class="rk rk${o.rank}">${o.rank}</span>`:''}${o.tier!=null?` <span class="sub">T${o.tier}</span>`:''}<div class="sub">${o._d||''}</div></div>
    ${av.done?'<span class="gd">✓</span>':av.ok?`<button class="btn sm blue" data-a="res" data-k="${kind}" data-v="${o.id}" ${G.rp<o.rp?'disabled':''}>${o.rp} RP</button>`:`<span class="sub">🔒 ${av.why}</span>`}</div></div>`;
  if(tab==='car'||tab==='bike'){
    for(const b of D.BODIES.filter(b=>b.cls===tab)){const av=E.bodyAvail(b.id);
      h+=item('body',{...b,_d:`SPD ${b.s.spd} ACC ${b.s.acc} HND ${b.s.hnd} DUR ${b.s.dur} · On ${b.t.on} Off ${b.t.off} Wet ${b.t.wet} Icy ${b.t.ice}`},av,`<img class="vth" style="width:52px;height:43px" src="${GX.thumb(b.kind,av.done||av.ok?G.team.color:'#666','#ffd84a')}">`);}
  }else if(tab==='layout'){
    for(const L of D.LAYOUTS){const av=E.layoutAvail(L.id);h+=item('layout',{...L,n:`${L.n} (${L.cls})`,_d:L.d},av);}
  }else{
    for(const cat of Object.keys(D.PART_CATS)){const ps=D.PARTS.filter(p=>p.cat===cat);h+=`<div class="sec-h">${D.PART_CATS[cat]}</div>`;
      for(const P of ps){const av=E.partAvail(P.id);h+=item('part',{...P,_d:`${P.cls==='A'?'Any':P.cls==='C'?'Cars':'Bikes'} · ${UI.partFx(P)}`},av);}}
  }
  return {title:'🔬 Research',tabs:[['car','Cars'],['bike','Bikes'],['layout','Layouts'],['part','Parts']],html:h};
};
UI.A.res = d=>{E.research(d.k,d.v);};

// STAFF
UI.V.staff = (tab)=>{
  tab=tab||'team';const W=E.ws();let h='';
  if(tab==='team'){
    h+=`<div class="note">Drivers ${E.drivers().length}/${W.teams+1} · Mechanics ${E.mechs().length}/${W.mech} · Monthly salaries ${U.money(U.sum(G.staff,s=>s.salary))}</div><div class="sec-h">Drivers</div>`;
    for(const s of E.drivers())h+=UI.staffCard(s,`<button class="btn sm" data-a="trainSel" data-v="${s.id}">Train</button><button class="btn sm red" data-a="fire" data-v="${s.id}">Release</button>`);
    h+=`<div class="sec-h">Mechanics</div>`;
    for(const s of E.mechs()){const c=E.mechLvCost(s);h+=UI.staffCard(s,`${s.lv<10?`<button class="btn sm blue" data-a="lvup" data-v="${s.id}" ${G.rp<c?'disabled':''}>Lv↑ ${c} RP</button>`:'<span class="gd">MAX</span>'}<button class="btn sm red" data-a="fire" data-v="${s.id}">Release</button>`);}
  }else if(tab==='hire'){
    h+=`<div class="note">New faces arrive every month. Better candidates come with more fans and a Scout Office. Signing fee = 3 months' salary.</div>`;
    for(const c of G.cand)h+=UI.staffCard(c,`<button class="btn sm grn" data-a="hire" data-v="${c.id}" ${G.money<c.salary*3?'disabled':''}>Hire ${U.money(c.salary*3)}</button>`);
    const sc=E.scoutCost();h+=`<button class="btn blue big" data-a="scout" ${G.money<sc?'disabled':''}>🔎 Scout new candidates (${U.money(sc)})</button>`;
  }else{
    const ds=E.drivers();UI.sel.tsid=UI.sel.tsid&&E.staff(UI.sel.tsid)?UI.sel.tsid:ds[0].id;const s=E.staff(UI.sel.tsid);
    h+=`<div class="chips" style="margin-bottom:6px">${ds.map(d=>`<button class="chip ${d.id===s.id?'on':''}" style="padding:5px 9px;font-size:13px" data-a="trainSel" data-v="${d.id}">${U.esc(d.name)}</button>`).join('')}</div>`;
    h+=UI.staffCard(s,'');h+=UI.sparkChips();
    for(const t of D.TRAINING){const ok=E.trainAvail(t.id);const tc=E.trainCost(s,t);const en=Math.round(t.en*(s.trait==='iron'?0.6:1));
      const g=Object.entries(t.g).map(([k,x])=>k==='car'||k==='bike'?`${k} affinity↑`:k==='maxE'?`Max energy +${x}`:`${k} +${x}`).join(', ')||'Earn money';
      h+=`<div class="card ${ok?'':'lock'}"><div class="row"><div class="sp1"><b>${t.n}</b> <span class="sub">⚡${en}</span><div class="sub hl">${g}</div></div>
        ${ok?`<button class="btn sm" data-a="train" data-v="${t.id}" ${(tc>0&&G.money<tc)||s.energy<en?'disabled':''}>${tc<0?'+'+U.money(-tc):U.money(tc)}</button>`:'<span class="sub">🔒 Sponsor</span>'}</div></div>`;}
  }
  return {title:'👥 Staff',tabs:[['team','Team'],['hire','Hire'],['train','Train']],html:h};
};
UI.staffCard = (s,btns)=>{const drv=s.role==='drv';
  return `<div class="card"><div class="row"><img class="face" src="${GX.face(s)}"><div class="sp1"><b>${U.esc(s.name)}</b> <span class="sub">${drv?'Driver':'Mechanic Lv'+s.lv}</span> ${s.trait?`<span class="chip" title="${D.TRAITS[s.trait].d}">${D.TRAITS[s.trait].n}</span>`:''}
    <div class="grid3">${drv?`<span>Pedal <b class="hl">${s.pedal}</b></span><span>Shift <b class="hl">${s.shift}</b></span><span>Steer <b class="hl">${s.steer}</b></span>`:''}<span>Appeal ${s.appeal}</span><span>Tech <b class="${drv?'':'hl'}">${s.tech}</b></span><span>Analysis ${s.analysis}</span></div>
    ${drv?`<div class="sub">Car ${s.aff.car}× · Bike ${s.aff.bike}×${s.trait?` · ${D.TRAITS[s.trait].d}`:''}</div><div class="ebar"><i style="width:${s.energy/s.maxE*100}%"></i></div>`:''}
    <div class="sub">Salary ${U.money(s.salary)}/mo</div><div class="row" style="gap:4px;margin-top:4px;justify-content:flex-end">${btns}</div></div></div></div>`;};
UI.A.trainSel = d=>{UI.tab='train';UI.sel.tsid=+d.v;};
UI.A.train = d=>{const s=E.staff(UI.sel.tsid);const out=E.train(s.id,d.v,UI.sel.spark||null);UI.sel.spark='';
  if(out){const t=Object.entries(out).map(([k,x])=>k==='money'?`+${U.money(x)}`:k==='car'||k==='bike'?`${k} affinity up`:`${k} +${x}`).join(', ');UI.toast(`${s.name}: ${t}`);GX.floatAtVeh(t.split(',')[0],null,'#8ef58e');SFX.play('good');}};
UI.A.lvup = d=>{E.levelMech(+d.v);};
UI.A.hire = d=>{E.hire(+d.v);};
UI.A.fire = d=>{const s=E.staff(+d.v);UI.confirm('Release staff?',`Let ${U.esc(s.name)} go?`,()=>E.fire(s.id));};
UI.A.scout = ()=>{const c=E.scoutCost();if(G.money<c)return;G.money-=c;E.refreshCandidates();UI.toast('New candidates arrived!');};
E.scoutCost = ()=>Math.round(10000*(1+E.fanRank()));

// SPONSORS
UI.V.sponsors = (tab)=>{
  tab=tab||'active';const W=E.ws();let h=`<div class="note">Sponsors ${G.spons.length}/${W.spon}. Racing raises each sponsor's Ad level (driver Appeal + vehicle Ad appeal) which raises their pay. Completing goals unlocks new stuff!</div>`;
  if(tab==='active'){if(!G.spons.length)h+=`<div class="note">No sponsors yet — check Offers!</div>`;
    for(const sp of G.spons){const S=D.SPON[sp.id];const[c,n]=E.goalProgress(sp);
      h+=`<div class="card ${sp.done?'done':''}"><b>${U.esc(S.n)}</b> <span class="hl">${'★'.repeat(sp.ad)}${'☆'.repeat(5-sp.ad)}</span><div class="sub">"${U.esc(S.bl)}"</div>
        <div class="sub">Pays <b class="gd">${U.money(E.sponsorPay(sp))}</b>/month</div>
        ${sp.done?`<div class="sub gd">✓ Goal complete</div>`:`<div class="sub">Goal: ${E.goalText(S.goal)} <b>(${U.num(Math.max(0,Math.min(c,n)))}/${U.num(n)})</b></div><div class="ebar"><i style="width:${U.clamp(c/n,0,1)*100}%"></i></div><div class="sub hl">Reward: ${U.esc(E.rewardText(S.rw))}</div>`}
        <div class="row" style="justify-content:flex-end;margin-top:4px"><button class="btn sm red" data-a="cancelSp" data-v="${sp.id}">End contract</button></div></div>`;}
  }else{const off=E.sponsorOffers();if(!off.length)h+=`<div class="note">No new offers. Get more fans!</div>`;
    for(const S of off){const done=G.sponDone[S.id];
      h+=`<div class="card"><div class="row"><div class="sp1"><b>${U.esc(S.n)}</b><div class="sub">"${U.esc(S.bl)}"</div><div class="sub">Signing ${U.money(done?S.sign*500:S.sign*1000)} · Base pay ${U.money(S.mo*1000)}/mo</div>
        ${done?'<div class="sub gd">Goal already completed</div>':`<div class="sub">Goal: ${E.goalText(S.goal)}</div><div class="sub hl">Reward: ${U.esc(E.rewardText(S.rw))}</div>`}</div>
        <button class="btn sm grn" data-a="signSp" data-v="${S.id}" ${G.spons.length>=W.spon?'disabled':''}>Sign</button></div></div>`;}
    const next=D.SPONSORS.filter(s=>s.fans>G.fans).slice(0,1)[0];if(next)h+=`<div class="sub" style="text-align:center">Next sponsor interest at ${U.num(next.fans)} fans</div>`;
  }
  return {title:'💼 Sponsors',tabs:[['active','Contracts'],['offers','Offers']],html:h};
};
UI.A.signSp = d=>{E.signSponsor(d.v);};
UI.A.cancelSp = d=>{UI.confirm('End contract?',`End the deal with ${U.esc(D.SPON[d.v].n)}? Goal progress is lost.`,()=>E.cancelSponsor(d.v));};

// FACILITIES
UI.V.facility = ()=>{
  const W=E.ws();const built=G.fac.filter(Boolean);let h=`<div class="note">Facility slots ${built.length}/${W.fac}. Bigger workshops have more room.</div><div class="sec-h">Built</div>`;
  if(!built.length)h+=`<div class="sub">Nothing yet.</div>`;
  for(const f of built){const F=D.FAC[f.id];const c=f.lv<3?F.cost[f.lv]*1000:0;
    h+=`<div class="card"><div class="row"><div class="sp1"><b><span style="color:${F.col}">${F.ic}</span> ${F.n}</b> <span class="hl">Lv${f.lv}</span><div class="sub">${F.d} — now ${F.v[f.lv-1]}${F.fx==='regen'?'/day':F.fx==='scout'?' tier':F.fx==='merch'?'$/fan':'%'}</div></div>
      ${f.lv<3?`<button class="btn sm" data-a="upFac" data-v="${f.id}" ${G.money<c?'disabled':''}>Lv↑ ${U.money(c)}</button>`:'<span class="gd">MAX</span>'}<button class="btn sm red" data-a="rmFac" data-v="${f.id}">✕</button></div></div>`;}
  h+=`<div class="sec-h">Build new</div>`;
  for(const F of D.FACILITIES.filter(F=>!built.find(b=>b.id===F.id))){const ok=E.facAvail(F.id);const c=F.cost[0]*1000;
    h+=`<div class="card ${ok?'':'lock'}"><div class="row"><div class="sp1"><b><span style="color:${F.col}">${F.ic}</span> ${F.n}</b><div class="sub">${F.d} (${F.v.join(' / ')})</div></div>
      ${ok?`<button class="btn sm grn" data-a="buildFac" data-v="${F.id}" ${G.money<c||built.length>=W.fac?'disabled':''}>${U.money(c)}</button>`:'<span class="sub">🔒 Sponsor</span>'}</div></div>`;}
  return {title:'🏗️ Facilities',html:h};
};
UI.A.buildFac = d=>{E.buildFac(d.v);};
UI.A.upFac = d=>{E.upgradeFac(d.v);};
UI.A.rmFac = d=>{UI.confirm('Remove facility?',`Tear down ${D.FAC[d.v].n}? No refund.`,()=>E.demolishFac(d.v));};

// TEAM
UI.V.team = (tab)=>{
  tab=tab||'team';let h='';
  if(tab==='team'){const n=E.wsNeed();const lm=G.lastMonth;
    h+=`<div class="card"><div class="row"><div class="sp1"><b style="color:${G.team.color}">■</b> <b>${U.esc(G.team.name)}</b><div class="sub">${E.fanRankName()} team · ${U.num(G.fans)} fans · ${E.dateStr()} (Year ${E.year()}/${D.YEARS})</div></div></div></div>`;
    h+=`<div class="card"><b>🏠 ${E.ws().n}</b><div class="sub">Teams ${E.ws().teams} · Mechanics ${E.ws().mech} · Vehicles ${E.ws().veh} · Facilities ${E.ws().fac} · Sponsors ${E.ws().spon}</div>`;
    if(n){const ok=E.canUpgradeWS();h+=`<div class="sub" style="margin-top:4px">Next: <b>${D.WORKSHOPS[G.ws+1].n}</b> — needs a ${D.TIER_N[n.tier]} series title ${ok?'<span class="gd">✓</span>':''} and ${U.money(n.cost)}</div>
      <button class="btn ${ok?'grn':'gray'} big" style="margin-top:6px" data-a="upWS" ${!ok||G.money<n.cost?'disabled':''}>🏗️ Move to ${D.WORKSHOPS[G.ws+1].n}</button>`;}
    else h+=`<div class="sub gd">Top workshop reached! ${E.legendOpen()?'Legend races are open.':'Win 2 World series to unlock Legend races.'}</div>`;
    h+=`</div>`;
    h+=`<div class="card"><b>📒 Books</b>${lm?`<div class="sub">Last month: sponsors <span class="gd">+${U.money(lm.sp)}</span>${lm.merch?` · merch <span class="gd">+${U.money(lm.merch)}</span>`:''} · salaries <span class="bd">-${U.money(lm.sal)}</span></div>`:'<div class="sub">First month-end coming up.</div>'}
      <div class="sub">Total prize money ${U.money(G.st.earn)}</div></div>`;
    h+=`<div class="card"><b>📊 Record</b><div class="grid3"><span>Races ${G.st.races}</span><span>Wins ${G.st.wins}</span><span>Podiums ${G.st.podiums}</span><span>DNFs ${G.st.dnf}</span><span>Titles ${G.st.titles.length}</span><span>Score ${U.num(E.score())}</span></div>
      <div class="sub">Sparks: ✨Bronze ${G.sparks.b} · Silver ${G.sparks.s} · Gold ${G.sparks.g}</div></div>`;
  }else if(tab==='titles'){
    for(const S of D.SERIES){const sv=G.series[S.id];h+=`<div class="card ${sv&&sv.titles?'done':''}"><b>${D.DISC[S.disc].ic} ${U.esc(S.n)}</b> <span class="sub">${D.TIER_N[S.tier]}</span><div class="sub">${sv?(sv.titles?`🏆 ×${sv.titles}`:`Best ${sv.best<99?U.ord(sv.best):'—'}`):'Not entered'}</div></div>`;}
  }else if(tab==='news'){h+=G.log.map(l=>`<div class="sub" style="padding:3px 0;border-bottom:1px solid #2c3b70">${E.dateStr(l.d)} · ${U.esc(l.t)}</div>`).join('');}
  else{
    h+=`<div class="card"><b>⚙️ Settings</b>
      <div class="row" style="margin-top:6px"><span class="sp1">Auto-retire at 8% durability<div class="sub">Keeps vehicles from being destroyed</div></span><button class="btn sm ${G.settings.autoRetire?'grn':'gray'}" data-a="setAR">${G.settings.autoRetire?'ON':'OFF'}</button></div>
      <div class="row" style="margin-top:6px"><span class="sp1">Sound</span><button class="btn sm ${G.settings.sound?'grn':'gray'}" data-a="setSnd">${G.settings.sound?'ON':'OFF'}</button></div></div>
      <div class="card"><b>💾 Save</b><div class="sub">${Save.status()}</div>
      <div class="grid2" style="margin-top:6px"><button class="btn blue" data-a="saveNow">Save now</button><button class="btn" data-a="export">Export code</button><button class="btn" data-a="import">Import code</button><button class="btn red" data-a="newGame">New game</button></div></div>
      <div class="card"><b>❓ How to play</b><div class="sub" style="line-height:1.5">${UI.HELP}</div></div>`;
  }
  return {title:'📋 Team',tabs:[['team','Team'],['titles','Titles'],['news','News'],['settings','Settings']],html:h};
};
UI.HELP = `• <b>Build</b> cars or bikes from researched bodies. Mechanics' <b>Tech</b> sets build quality and speed.<br>
• <b>Tune</b> Speed/Accel/Handling/Durability up to 5× each, and fit <b>Parts</b> in free slots.<br>
• Match the vehicle to the surface: <b>On-Rd</b> (tarmac), <b>Off-Rd</b> (dirt/sand/mud), <b>Wet</b> and <b>Icy</b> grip all matter.<br>
• Drivers' <b>Pedal</b>→speed, <b>Shift</b>→accel, <b>Steer</b>→handling. Train them with money + energy. Racing also uses energy.<br>
• Win normal races to unlock a <b>Series</b>; win a series to move to a bigger workshop with tougher events.<br>
• Sign <b>Sponsors</b> and finish their goals to unlock training, layouts, parts, facilities and special vehicles.<br>
• <b>Sparks</b> (from first podiums & titles) boost a race, build, tune or training session.`;
UI.A.upWS = ()=>{E.upgradeWS();};
UI.A.setAR = ()=>{G.settings.autoRetire=!G.settings.autoRetire;};
UI.A.setSnd = ()=>{G.settings.sound=!G.settings.sound;};
UI.A.saveNow = ()=>{Save.save(true);UI.toast('Saved!');};
UI.A.export = ()=>{const code=Save.exportCode();UI.popup({title:'Export save',html:`<div class="sub">Copy this code somewhere safe. Import it on any device.</div><textarea readonly id="expTxt">${code}</textarea>`,
  buttons:[{t:'Copy',cls:'blue',fn:()=>{const t=$('expTxt');t.select();try{navigator.clipboard.writeText(t.value).then(()=>UI.toast('Copied!'),()=>UI.toast('Select the text and copy it'));}catch(e){UI.toast('Select the text and copy it');}return false;}},{t:'Close'}]});};
UI.A.import = ()=>{UI.popup({title:'Import save',html:`<div class="sub">Paste a save code. This replaces your current game.</div><textarea id="impTxt"></textarea>`,
  buttons:[{t:'Cancel',cls:'gray'},{t:'Load',cls:'red',fn:()=>{try{Save.importCode($('impTxt').value.trim());UI.toast('Save loaded!');UI.close();}catch(e){UI.toast('That code did not work');return false;}}}]});};
UI.A.newGame = ()=>{UI.confirm('Start over?','This erases your current team.',()=>{UI.close();Main.title(true);});};

// ---------- RACE SCREEN ----------
UI.startRace = (def,v,s,tactic,sid)=>{
  const opts={};if(sid){opts.series=sid;opts.rivals=G.series[sid].act.rivals;}
  const rs=Race.create(def,{vid:v.id,sid:s.id,tactic},opts);UI.race=rs;UI.raceSpeed=G.settings.raceSpeed||1;
  $('race').classList.remove('hidden');$('rResult').classList.add('hidden');
  $('rTitle').textContent=(sid?D.SER[sid].n+' · ':'')+def.n+(rs.rain?' ☔':'');
  UI.raceCtl();SFX.play('start');
};
UI.raceCtl = ()=>{const rs=UI.race;if(!rs)return;const sp=G.sparks;
  $('rCtl').innerHTML=`<div class="r">${Object.entries(Race.TAC).map(([k,t])=>`<button data-r="tac" data-v="${k}" class="${rs.tactic===k?'on':''}">${t.n}</button>`).join('')}</div>
   <div class="r">${[['b','Bronze'],['s','Silver'],['g','Gold']].map(([k,n])=>`<button data-r="spark" data-v="${k}" ${sp[k]?'':'disabled style="opacity:.4"'}>✨${n} ×${sp[k]}</button>`).join('')}</div>
   <div class="r">${[1,2,4].map(x=>`<button data-r="spd" data-v="${x}" class="${UI.raceSpeed===x?'on':''}">${x}×</button>`).join('')}<button class="sk" data-r="skip">Skip ⏭</button><button class="rt" data-r="retire">Retire</button></div>`;};
UI.raceClick = e=>{const b=e.target.closest('[data-r]');if(!b||!UI.race)return;const rs=UI.race;const a=b.dataset.r;SFX.play('click');
  if(a==='tac')rs.tactic=b.dataset.v;else if(a==='spark'){Race.useSpark(rs,b.dataset.v);}
  else if(a==='spd'){UI.raceSpeed=+b.dataset.v;G.settings.raceSpeed=UI.raceSpeed;}
  else if(a==='skip'){Race.runInstant(rs);}
  else if(a==='retire'){if(!rs.player.fin&&!rs.player.dnf)UI.popup({title:'Retire?',html:'Pull out of the race to protect the vehicle?',buttons:[{t:'Keep racing',cls:'gray'},{t:'Retire',cls:'red',fn:()=>Race.retire(rs)}]});}
  UI.raceCtl();};
UI.raceFrame = (dt)=>{
  const rs=UI.race;if(!rs)return;
  if(!rs.done&&!UI.popOpen){let t=dt*UI.raceSpeed;while(t>0){const s=Math.min(0.05,t);Race.step(rs,s);t-=s;if(rs.done)break;}}
  const cv=$('rcv');const c=cv.getContext('2d');c.setTransform(3,0,0,3,0,0);GX.drawRace(c,rs,dt*UI.raceSpeed);
  const P=rs.player;const pos=rs.order.indexOf(P)+1;const lap=Math.min(rs.tr.laps,Math.floor(Math.max(0,rs.order[0].prog)/rs.tr.lapLen)+1);
  $('rInfo').innerHTML=`${rs.tr.p2p?'Stage':`Lap ${lap}/${rs.tr.laps}`} · <b class="hl">${P.dnf&&!P.fin?'DNF':'P'+pos}</b>/${rs.ents.length}<br>HP <span style="color:${P.hp>0.5?'#8ef58e':P.hp>0.25?'#ffd84a':'#ff7070'}">${'█'.repeat(Math.max(0,Math.ceil(P.hp*10)))}${'░'.repeat(10-Math.max(0,Math.ceil(P.hp*10)))}</span> ${Math.max(0,Math.round(P.hp*100))}%`;
  const m=rs.msgs[rs.msgs.length-1];$('rComm').textContent=m?m.text:'';
  const L=rs.order[0];const vv=Math.max(0.1,L.v||1);
  const rows=rs.order.slice(0,8);if(!rows.includes(P))rows[7]=P;
  $('rBoard').innerHTML=rows.map(e=>{const p=rs.order.indexOf(e)+1;const gap=e===L?(e.fin?'FIN':'Leader'):e.dnf&&!e.fin?'DNF':e.fin?'+'+(e.finT-L.finT).toFixed(1)+'s':'+'+Math.max(0,(L.prog-e.prog)/vv).toFixed(1)+'s';
    return `<div class="lr ${e.isPlayer?'me':''}"><span class="p">${p}.</span><span class="sw" style="background:${e.col}"></span><span class="n">${U.esc(e.isPlayer?G.team.name+' ('+e.name+')':e.team)}</span><span>${gap}</span></div>`;}).join('');
  if(rs.done&&!rs.resolved){rs.resolved=true;setTimeout(()=>UI.raceResult(rs),700);}
};
UI.raceResult = (rs)=>{
  const out=E.finishRace(rs);if(rs.series)E.seriesRoundDone(rs.series,rs);
  const pos=out.pos;const big=out.dnf?(out.destroyed?'💥 WRECKED':'DNF'):pos===1?'🏆 VICTORY!':pos<=3?`🎉 ${U.ord(pos)} PLACE`:`${U.ord(pos)} place`;
  SFX.play(out.dnf?'crash':pos===1?'fanfare':pos<=3?'good':'click');
  let h=`<div class="big">${big}</div><div style="text-align:center" class="sub">${U.esc(rs.def.n)}${rs.series?' · '+U.esc(D.SER[rs.series].n):''}</div>
    <div class="card" style="margin-top:8px"><div class="grid2"><span>Prize <b class="gd">${U.money(out.prize)}</b></span><span>Research <b class="bl">+${out.rp} RP</b></span><span>Fans <b style="color:#ff9fcf">+${U.num(out.fans)}</b></span><span>${out.vlv?`Vehicle <b class="hl">Lv${out.vlv}!</b>`:''}</span></div>
    ${out.rep?'<div class="sub">Repeat win this year — reduced rewards.</div>':''}${out.spark?`<div class="hl">✨ Earned a ${{b:'Bronze',s:'Silver',g:'Gold'}[out.spark]} Spark!</div>`:''}${out.destroyed?'<div class="bd">The vehicle was destroyed.</div>':''}</div>`;
  h+=`<div class="sec-h">Results</div><div class="stand">${rs.order.slice(0,8).map((e,i)=>`<div class="${e.isPlayer?'me':''}">${i+1}. ${U.esc(e.isPlayer?G.team.name:e.team)}${e.dnf&&!e.fin?' (DNF)':''}</div>`).join('')}</div>`;
  if(rs.series&&G.series[rs.series].act)h+=`<div class="sec-h">Championship</div><div class="stand">${E.standings(rs.series).slice(0,5).map((x,i)=>`<div class="${x[0]==='you'?'me':''}">${i+1}. ${U.esc(x[0]==='you'?G.team.name:x[0])} — ${x[1]}</div>`).join('')}</div>`;
  if(out.unl.length)h+=`<div class="sec-h">Unlocked!</div>${out.unl.map(id=>`<div class="hl">🔓 ${U.esc(D.RACE[id]?D.RACE[id].n:D.SER[id].n+' (Series)')}</div>`).join('')}`;
  h+=`<button class="btn big grn" style="margin-top:10px" data-r2="done">Continue</button>`;
  $('rResult').innerHTML=`<div class="pw">${h}</div>`;$('rResult').classList.remove('hidden');
  $('rResult').querySelector('[data-r2]').onclick=()=>{SFX.play('click');UI.race=null;$('race').classList.add('hidden');Save.save();UI.hud();const d=UI.deferPop;UI.deferPop=[];d.forEach(o=>UI.popup(o));};
};
