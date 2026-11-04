// ===================== UI v3: staged build decisions =====================
D.BPH_HINT = {
  design:'What kind of machine is this going to be? This sets its character.',
  frame:'The backbone. Stiffer and lighter is faster, heavier is tougher.',
  engine:'How the motor goes together decides power, torque and how long it lives.',
  drive:'Gearing and how the power gets to the ground.',
  susp:'Spring, damper and brake package. Pick for the surfaces you race on.',
  body:'Panels, aero and paint. Sponsors care about the paint.',
  elec:'Wiring loom and fuel system hookup.',
  shake:'Last checks before it rolls out the door.',
};
UI.buildTag = v=>{const j=E.bJob(v.id);if(!j||!j.pd)return 'Building…';return `Building — ${D.BPHN[D.BPH[j.pi]]} (${j.pi+1}/8)${j.wait?' <b class="hl">❓ decision</b>':''}`;};
UI.buildAsk = j=>{
  const v=E.veh(j.vid);const w=j.wait;if(!v||!w)return;j.asked=true;
  if(UI.popQ.some(o=>o._bvid===v.id)||(UI.popOpen&&UI.curPop&&UI.curPop._bvid===v.id))return;
  let o;
  if(w.k==='ph'){const opts=E.bOpts(v,w.ph);
    o={_bvid:v.id,title:`🔧 ${U.esc(v.name)} — ${D.BPHN[w.ph]} <span class="sub">(${j.pi+1}/8)</span>`,html:`<div class="sub">${D.BPH_HINT[w.ph]}</div>${UI.buildSoFar(v)}`,
      buttons:opts.map((op,i)=>{const r=E.bReq(op,v);return {t:`<b>${U.esc(op.n)}${op.crew?' <span class="rec">crew pick</span>':''}</b><span class="od">${U.esc(op.d)}</span><span class="ofx">${E.bFx(op,v)||'No change'}</span>${r.ok?'':`<span class="bd">🔒 ${r.why}</span>`}`,cls:'opt',dis:!r.ok,fn:()=>{if(!E.bChoose(v.id,i))return false;SFX.play('good');}};})
        .concat([{t:'👷 Let the crew decide',cls:'gray',fn:()=>{E.bChoose(v.id,'crew');}}])};}
  else{const e=D.BEVM[w.ev];
    o={_bvid:v.id,title:`⚠️ ${U.esc(e.n)}`,html:`<div>${U.esc(w.txt)}</div><div class="sub" style="margin-top:4px">${U.esc(v.name)} · ${D.BPHN[w.next]} coming up</div>`,
      buttons:e.o.map((op,i)=>{const c=E.bCost(op,v);const ok=!(c>0&&G.money<c);return {t:`<b>${U.esc(op.n)}</b><span class="ofx">${E.bFx(op,v)||'—'}</span>`,cls:'opt',dis:!ok,fn:()=>{if(!E.bChoose(v.id,i))return false;}};})};}
  UI.popup(o);SFX.play('bump');
};
UI.buildSoFar = v=>{const l=v.blog||[];if(!l.length)return '';return `<div class="bsofar">${l.slice(-4).map(x=>`✓ ${U.esc(x)}`).join('<br>')}</div>`;};
UI.buildSheet = v=>{
  const j=E.bJob(v.id);if(!j||!j.pd)return `<div class="note">Still being built…</div>`;
  const pr=U.clamp(1-j.left/j.total,0,1);let h=`<div class="card"><b>🏗️ Build sheet</b><div class="ebar" style="margin:4px 0"><i style="width:${pr*100}%"></i></div><div class="sub">≈${Math.ceil(j.left)} work-days left (crew speed decides real days)</div>`;
  for(let i=0;i<8;i++){const ph=D.BPH[i];const ch=j.ch&&j.ch[ph];const op=ch&&E.bOpts(v,ph).find(x=>x.id===ch);
    h+=`<div class="bph ${i<j.pi?'done':i===j.pi?'cur':''}"><span>${i<j.pi||op?'✓':i===j.pi?'▶':'·'} ${D.BPHN[ph]}</span><span class="sub">${op?U.esc(op.n):i===j.pi&&j.wait?'<b class="hl">waiting on you</b>':''}</span></div>`;}
  h+=`</div>`;
  const ev=(v.blog||[]).filter(x=>!D.BPH.some(p=>x.startsWith(D.BPHN[p])));if(ev.length)h+=`<div class="card"><b>Shop log</b><div class="sub">${ev.map(x=>'• '+U.esc(x)).join('<br>')}</div></div>`;
  const bm=v.bm||{};const fx=['spd','acc','hnd','dur'].filter(k=>bm[k]).map(k=>`${k.toUpperCase()} ${bm[k]>0?'+':''}${Math.round(bm[k])}%`).concat(['on','off','wet','ice'].filter(k=>bm[k]).map(k=>`${D.TERR_N[k]} ${bm[k]>0?'+':''}${bm[k]}`));
  if(fx.length)h+=`<div class="note">Build so far: ${fx.join(' · ')}${v.slotB?` · +${v.slotB} slot`:''}</div>`;
  if(j.wait)h+=`<button class="btn big grn" data-a="bDecide">❓ Make the ${j.wait.k==='ph'?D.BPHN[j.wait.ph].toLowerCase():'shop'} call</button>`;
  return h;};
UI.A.bDecide = ()=>{const j=E.bJob(UI.sel.vid);if(j&&j.wait){j.asked=false;UI.buildAsk(j);}};
UI.A.doBuild = ()=>{const v=E.startBuild(UI.sel.body,UI.sel.layout,UI.sel.spark||null,UI.sel.sys||null);if(v){UI.close();const j=E.bJob(v.id);if(j&&j.wait)UI.buildAsk(j);}};
// activity rows: show phase
const _hud=UI.hud;
UI.hud = ()=>{_hud();if(!G)return;const rows=$('activity').querySelectorAll('.row .lbl');
  rows.forEach(el=>{const t=el.textContent;if(!t.startsWith('Build · '))return;const nm=t.slice(8);const v=G.vehicles.find(x=>x.name===nm);const j=v&&E.bJob(v.id);
    if(j&&j.pd)el.innerHTML=`${D.BPHS[D.BPH[j.pi]]} ${j.pi+1}/8${j.wait?' ❓':''} · ${U.esc(nm)}`;});};
