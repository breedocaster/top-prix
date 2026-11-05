// ===================== ENGINE & FUEL MODEL =====================
const T = {};
T.has = id=>!!(G.tech&&G.tech[id]);
T.mode = ()=>(G&&G.settings&&G.settings.mode)||'standard';
T.T0 = 288.15;
T.press = alt=>Math.pow(1-2.25577e-5*alt,5.25588);
T.dens = (alt,temp)=>T.press(alt)*(T.T0/(273.15+temp));
T.forecast = (r,day=G.day)=>{
  const c=D.condOf(r);const m=Math.floor((day%D.DAYS_YEAR)/D.DAYS_MONTH);const rng=U.seeded(U.hash(r.id)+Math.floor(day/7)*31);
  const sw=T.mode()==='sim'?7:3;const temp=Math.round(c.temp+D.SEASON[m]*(c.temp<0?0.5:1)+(rng()*2-1)*sw);
  return {alt:c.alt,alt2:c.alt2,temp,tod:c.tod,rho:T.dens(c.alt,temp),rho2:T.dens(c.alt2,temp-(c.alt2-c.alt)*0.0065),name:r.n};
};
T.SHOP = ()=>({alt:200,alt2:200,temp:20,tod:'day',rho:T.dens(200,20),rho2:T.dens(200,20),name:'Shop (200 m, 20°C)'});
T.cyl = v=>D.LAYOUT_CYL[v.layout]==null?4:D.LAYOUT_CYL[v.layout];
T.isBike = v=>D.BODY[v.body].cls==='bike';
T.dirtKind = k=>['trail','mx','enduro','raid','smoto','flat'].includes(k);
T.nCarbs = v=>{if(!v.eng||v.eng.fuel==='none')return 0;if(v.eng.fuel==='efi')return T.isBike(v)?T.cyl(v):1;const C=D.CARBS[v.eng.carb];return C.cls==='car'?(C.carbs||1):T.cyl(v);};
T.syncBase = n=>n>=3?1:0;
T.carbsFor = v=>Object.entries(D.CARBS).filter(([k,c])=>c.cls===D.BODY[v.body].cls).map(([k])=>k);
T.carbAvail = id=>{const c=D.CARBS[id];return c.un==='S'||T.has(c.un);};
T.defaultCarb = (cls,lid)=>cls==='car'?'d2':'pe';
T.efiCost = b=>Math.max(20000,Math.round(b.cost*0.25/1000)*1000);
T.carbSwapCost = (b,id)=>Math.max(8000,Math.round(b.cost*({pe:0.05,cv:0.06,pwk:0.08,fcr:0.14,d2:0.05,q4:0.09,dcoe:0.15}[id]||0.08)/1000)*1000);

// ---------- init / migrate ----------
T.initEng = (v,sys)=>{
  const cyl=T.cyl(v);
  if(cyl===0){v.eng={fuel:'none',cond:1,fuelT:'pump',timing:0,sync:[]};return v.eng;}
  const e=v.eng={fuel:sys&&sys.type==='efi'?'efi':'carb',carb:(sys&&sys.carb)||T.defaultCarb(D.BODY[v.body].cls,v.layout),jets:{},timing:0,fuelT:'pump',cond:1,log:null,sync:[]};
  T.stockJets(v);
  const n=T.nCarbs(v);const rng=U.seeded(v.id*131+7);e.sync=Array.from({length:n},(_,i)=>i===T.syncBase(n)?0:+((rng()*2-1)*0.8).toFixed(1));
  if(e.fuel==='efi')T.initEFI(v);
  return e;
};
T.stockJets = v=>{const C=D.CARBS[v.eng.carb];v.eng.jets={};for(const p of C.p)v.eng.jets[p.k]=p.stock;};
// saves from before a carb gained a part (idle feed restrictors, cutaway...) get the stock part
T.fillJets = v=>{const e=v.eng;if(!e||e.fuel!=='carb'||!D.CARBS[e.carb])return;e.jets=e.jets||{};for(const p of D.CARBS[e.carb].p)if(e.jets[p.k]==null)e.jets[p.k]=p.stock;};
T.initEFI = v=>{
  const tv=T.trueVE(v);const rng=U.seeded(v.id*977+3);
  v.eng.efi={ve:tv.map(r=>r.map(x=>Math.round(x*(1+(rng()*2-1)*0.11)))),ign:[],afr:D.LOAD_B.map((l,j)=>D.RPM_B.car.map(()=>D.AFR_DEF[j])),ae:100,edits:0};
  for(let j=0;j<6;j++){v.eng.efi.ign.push([]);for(let i=0;i<8;i++)v.eng.efi.ign[j].push(Math.round(T.mbt(i,j)-4));}
  const n=T.nCarbs(v);v.eng.sync=Array.from({length:n},(_,i)=>i===T.syncBase(n)?0:+((rng()*2-1)*0.6).toFixed(1));
};

// ---------- hidden engine requirement ----------
T.need = v=>{
  const rng=U.seeded(v.id*9973+U.hash(v.body));const b=z=>1+(rng()-0.5)*0.08;
  const n={idle:b(),low:b(),mid:b(),wot:b(),trans:1+(rng()-0.5)*0.12};
  for(const pid of v.parts){const P=D.PART[pid];if(!['exh','ful','eng'].includes(P.cat))continue;const t=P.tier+1;
    n.wot+=0.014*t;n.mid+=0.008*t;n.low+=0.003*t;n.trans+=0.006*t;if(pid==='nitrous')n.wot+=0.05;if(pid.includes('turbo'))n.wot+=0.03,n.mid+=0.02;}
  if(T.has('porting')){n.wot+=0.03;n.mid+=0.02;}
  const fl=v.bflags||[];if(fl.includes('rev'))n.wot+=0.04;if(fl.includes('torque'))n.mid+=0.03,n.low+=0.01;
  if(T.has('bigvalve')){n.wot+=0.06;n.mid+=0.02;}
  return n;
};
T.aeNeed = v=>Math.round(100*T.need(v).trans);
T.trueVE = v=>{
  const nd=T.need(v);const rng=U.seeded(v.id*31337+5);const pk=4.2+rng()*1.6+(v.parts.some(p=>D.PART[p].cat==='eng')?0.6:0);
  const out=[];for(let j=0;j<6;j++){out.push([]);const L=D.LOAD_B[j];const zn=j>=4?nd.wot:j>=2?nd.mid:nd.low;
    for(let i=0;i<8;i++){const bell=Math.exp(-Math.pow((i-pk)/2.6,2));out[j].push((48+44*bell)*(0.78+0.22*L/100)*zn*(1+(rng()-0.5)*0.05));}}
  return out;
};
T.mbt = (i,j)=>14+2.4*i+(100-D.LOAD_B[j])*0.17;
T.kl = (v,i,j,lam,cond)=>{
  const L=D.LOAD_B[j];let m=6+(100-L)*0.15+i*0.6-(L>=90&&i<=2?4:0);
  m+=D.FUELS[v.eng.fuelT||'pump'].kn-(T.has('highcomp')?3:0)+cond.alt/1000*1.5-(cond.temp-20)*0.12;
  if(lam>0.9)m-=(lam-0.9)*50;if(lam<0.85)m+=(0.85-lam)*20;
  return T.mbt(i,j)+m;
};
// cell weights per zone
T.ZC = {
  idle:[[0,0,1]],
  low:[[0,1,1],[0,2,1],[0,3,0.6],[1,1,1],[1,2,1],[1,3,0.8]],
  mid:[[2,2,1],[2,3,1],[2,4,1],[2,5,0.7],[3,2,1],[3,3,1],[3,4,1],[3,5,0.8],[3,6,0.5]],
  wot:[[4,2,0.6],[4,3,0.9],[4,4,1],[4,5,1.1],[4,6,1.1],[4,7,1],[5,2,0.6],[5,3,0.9],[5,4,1],[5,5,1.2],[5,6,1.2],[5,7,1.1]],
};

// ---------- carb richness ----------
T.carbRich = v=>{
  const C=D.CARBS[v.eng.carb];const j=v.eng.jets;const R={idle:1,low:1,mid:1,wot:1,trans:1};
  for(const p of C.p){const val=j[p.k];if(val==null)continue;
    if(p.t==='jet'){for(const z of D.ZONES)R[z]*=Math.pow(val/p.stock,2*p.w[z]);R.trans*=Math.pow(val/p.stock,2*p.w.low);}
    else if(p.t==='lin'||p.t==='clip'){for(const z of D.ZONES)R[z]*=1+p.w[z]*(val-p.stock);R.trans*=1+p.w.low*(val-p.stock);}
    else if(p.t==='pv'){R.mid*=1+0.03*(val-p.stock);R.trans*=1+0.01*(val-p.stock);}
    else if(p.t==='airc'){R.wot*=Math.pow(p.stock/val,0.8);R.mid*=Math.pow(p.stock/val,0.2);}
    else if(p.t==='pump'){R.trans*=Math.pow(val/p.stock,0.8);}
  }
  R.trans*=C.trans;return R;
};

// ---------- full evaluation for one condition (rho/temp/alt) ----------
T.pf = (lam,z)=>{const t=D.LAM[z]||0.88;const w={idle:0.3,low:0.5,mid:0.9,wot:1,trans:0.6}[z];
  let loss=lam<t?4.5*Math.pow(t-lam,2):5*Math.pow(lam-t,2);if(lam>1.12)loss+=(lam-1.12)*1.5;if(lam<0.72)loss+=(0.72-lam)*1.2;return Math.max(0.4,1-loss*w);};
T.tf = (adv,mbt)=>{const r=mbt-adv;return r>0?1-0.0005*r*r:1-0.0008*r*r;};
T.eval = (v,cond,rhoOverride)=>{
  const e=v.eng;const out={lam:{},pf:{},tf:{},kd:{},lh:{},ef:{},cells:null,notes:[]};
  if(!e||e.fuel==='none'){for(const z of[...D.ZONES,'trans']){out.lam[z]=D.LAM[z]||0.9;out.ef[z]=1;out.kd[z]=0;out.lh[z]=0;}return out;}
  const rho=rhoOverride!=null?rhoOverride:cond.rho;const tK=273.15+cond.temp;const press=rho*tK/T.T0;
  const nd=T.need(v);const n=T.nCarbs(v);
  // sync
  const bi=T.syncBase(n);const offs=e.sync.filter((x,i)=>i!==bi);const imb=offs.length?U.sum(offs,x=>Math.abs(x))/offs.length:0;out.imb=imb;
  const sF={idle:1-0.04*imb,low:1-0.025*imb,mid:1-0.008*imb,wot:1-0.003*imb,trans:1-0.025*imb};
  let pw=D.FUELS[e.fuelT||'pump'].pw*(T.has('porting')?1.03:1)*(T.has('highcomp')?1.04:1)*(0.86+0.14*U.clamp(e.cond,0,1));
  const ve=e.fuel==='efi'?e.efi.ve:null;
  if(e.fuel==='carb'){const C=D.CARBS[e.carb];pw*=C.pw;const R=T.carbRich(v);const fn=D.FUELS[e.fuelT||'pump'].need;
    for(const z of D.ZONES)out.lam[z]=D.LAM[z]*nd[z]*fn/R[z]*Math.sqrt(rho);
    out.lam.trans=D.LAM.low*nd.trans*fn/R.trans*Math.sqrt(rho);
  }else{pw*=1.05;const tv=T.trueVE(v);const comp=(T.has('mapsens')?1:press)*(T.has('iat')?1:T.T0/tK);
    out.cells=[];for(let j=0;j<6;j++){out.cells.push([]);for(let i=0;i<8;i++){out.cells[j].push(e.efi.afr[j][i]/14.7*tv[j][i]/Math.max(5,ve[j][i])*comp);}}
    for(const z of D.ZONES){let s=0,w=0;for(const[j,i,ww]of T.ZC[z]){s+=out.cells[j][i]*ww;w+=ww;}out.lam[z]=s/w;}
    out.lam.trans=out.lam.low*Math.pow(T.aeNeed(v)/Math.max(10,e.efi.ae),0.6);}
  // power, timing & knock per zone
  for(const z of D.ZONES){let pf=0,tf=0,kd=0,kmax=0,w=0;
    for(const[j,i,ww]of T.ZC[z]){const lam=out.cells?out.cells[j][i]:out.lam[z];const mbt=T.mbt(i,j);
      const adv=e.fuel==='efi'?e.efi.ign[j][i]:mbt-3+(e.timing||0);const k=Math.max(0,adv-T.kl(v,i,j,lam,cond));
      pf+=T.pf(lam,z)*ww;tf+=T.tf(adv,mbt)*ww;kd+=k*ww;kmax=Math.max(kmax,k);w+=ww;}
    out.pf[z]=pf/w;out.tf[z]=tf/w;out.kd[z]=(z==='mid'||z==='wot')?kd/w*0.5+kmax*0.5:0;
    out.lh[z]=(z==='mid'||z==='wot')?Math.max(0,out.lam[z]-0.97)*40:0;
    if(e.fuel==='efi'&&T.has('knock')&&out.kd[z]>0){out.tf[z]*=1-0.01*out.kd[z];out.kd[z]*=0.15;}
    out.ef[z]=out.pf[z]*out.tf[z]*sF[z]*pw;}
  out.pf.trans=T.pf(out.lam.trans,'trans');out.ef.trans=out.pf.trans*sF.trans*pw;out.kd.trans=0;out.lh.trans=0;
  // float effects
  const fl=e.fuel==='carb'?(e.jets.float||0):0;out.starve=fl<=-1.5&&!T.has('baffle');out.flood=fl>=1.5&&!T.has('baffle');
  out.foul=out.lam.idle<0.78||out.lam.low<0.76;out.seize=v.layout==='stroke2'&&out.lam.wot>0.93;
  return out;
};
T.afr = lam=>lam*14.7;
T.zoneLabel = (lam,z)=>{const t=D.LAM[z]||0.88;const d=lam-t;return Math.abs(d)<0.02?['On target','#8ef58e']:d<0?(d<-0.06?['Very rich','#ff9a5c']:['Rich','#ffd84a']):(d>0.06?['Very lean','#ff5c5c']:['Lean','#ffd84a']);};
T.plug = lam=>lam<0.8?['Sooty black','#1c1c1c','Rich']:lam<0.845?['Dark brown','#5a3b1c','Slightly rich']:lam<0.905?['Light tan','#c79a5a','Good']:lam<0.96?['Grey-white','#c9c9c0','Slightly lean']:['Chalk white, blistered','#f4f4f4','LEAN!'];
T.symptoms = (ev,efi)=>{const s=[];const L=ev.lam,t=D.LAM;
  if(L.idle>t.idle+0.07)s.push(efi?'Hangs at idle and pops on decel (lean low-load cells)':'Hangs at idle and pops on decel (lean pilot circuit)');else if(L.idle<t.idle-0.1)s.push(efi?'Sooty idle (rich low-load cells)':'Blubbery, sooty idle (rich pilot circuit)');
  if(L.trans>t.low+0.05)s.push(efi?'Bogs on throttle snaps — more accel enrichment':'Bogs when you snap the throttle (lean transition)');
  if(L.mid>t.mid+0.06)s.push(efi?'Surges at part throttle (lean mid cells)':'Surges at part throttle (lean needle)');else if(L.mid<t.mid-0.07)s.push(efi?'Dull midrange (rich mid cells)':'Dull midrange, black smoke (rich needle)');
  if(L.wot>t.wot+0.06)s.push(efi?'Pulls then flattens — lean WOT cells':'Pulls hard then flattens; pinging under load (lean main)');else if(L.wot<t.wot-0.06)s.push(efi?'Soggy top end (rich WOT cells)':'Black smoke and soggy top end (rich main)');
  if(ev.kd.wot>0.5||ev.kd.mid>0.5)s.push('Audible pinging — detonation!');
  if(ev.imb>1.2)s.push('Rough, lumpy idle — carbs out of sync');
  if(!s.length)s.push('Crisp and clean everywhere');return s;};

// ---------- race section factors ----------
T.SECZ = {str:{wot:1},hill:{wot:0.6,mid:0.4},crv:{mid:0.8,wot:0.2},jmp:{mid:0.5,wot:0.5},hp:{low:0.6,trans:0.4},chi:{low:0.5,trans:0.5},rgh:{low:0.5,mid:0.5},lau:{trans:0.5,low:0.2,wot:0.3}};
T.setupMul = (v,sec)=>{
  const st=v.setup||{};const b=D.BODY[v.body];const bike=b.cls==='bike';const off=D.SURF[sec.surf].k==='off'||sec.type==='rgh'||sec.type==='jmp';
  let g=1;if(T.has('gearing')){if(bike&&st.f)g=(st.r/st.f)/T.stockRatio(v);else if(!bike&&st.fd)g=st.fd/3.7;}
  let S=Math.pow(g,-0.5),A=Math.pow(g,0.6),H=1,tm=1;
  if(T.has('adjsus')&&st.susp!=null){const c=st.susp-5;H*=off?1-0.015*c:1+0.012*c;}
  if(T.has('tirepress')&&st.psi!=null){const sp=T.stockPsi(v);const d=(st.psi-sp)/sp;tm*=off?1-0.35*d-0.6*d*d:1+0.25*d-0.9*d*d;}
  if(!bike&&T.has('aero')&&st.wing!=null){const w=st.wing-5;if(sec.type==='str')S*=1-0.004*w;else if(sec.type!=='lau')H*=1+0.006*w;}
  return {S,A,H,tm};
};
T.stockRatio = v=>T.dirtKind(D.BODY[v.body].kind)?47/13:45/16;
T.stockPsi = v=>{const b=D.BODY[v.body];return b.cls==='car'?32:T.dirtKind(b.kind)?14:34;};
T.defaultSetup = v=>{const b=D.BODY[v.body];return b.cls==='bike'?(T.dirtKind(b.kind)?{f:13,r:47,susp:5,psi:14}:{f:16,r:45,susp:5,psi:34}):{fd:3.7,susp:5,psi:32,wing:5};};
T.evalIdeal = v=>{const e=v.eng;const out={lam:{...D.LAM,trans:D.LAM.low},ef:{},kd:{},lh:{},imb:0};let pw=1;if(e&&e.fuel!=='none'){pw=D.FUELS[e.fuelT||'pump'].pw*(T.has('porting')?1.03:1)*(T.has('highcomp')?1.04:1)*(0.86+0.14*U.clamp(e.cond,0,1))*(e.fuel==='efi'?1.05:D.CARBS[e.carb].pw);}
  for(const z of[...D.ZONES,'trans']){out.ef[z]=pw*0.995;out.kd[z]=0;out.lh[z]=0;}return out;};
T.raceSecs = (v,def,tr,cond,ideal)=>{
  const out=[];const hill=cond.alt2!==cond.alt;const cache={};
  const evAt=frac=>{if(ideal)return cache.i||(cache.i=T.evalIdeal(v));const key=hill?Math.round(frac*4):0;if(cache[key])return cache[key];const alt=cond.alt+(cond.alt2-cond.alt)*(key/4);
    const temp=cond.temp-(alt-cond.alt)*0.0065;return cache[key]=T.eval(v,{...cond,alt,temp},T.dens(alt,temp));};
  const easy=T.mode()==='easy';const efi=v.eng&&v.eng.fuel==='efi';
  for(const sec of tr.secs){const ev=evAt((sec.at+sec.len/2)/tr.lapLen);const zw=T.SECZ[sec.type]||{wot:1};let ef=0,kd=0,lh=0,lam=0;
    for(const z in zw){ef+=zw[z]*ev.ef[z];kd+=zw[z]*(ev.kd[z]||0);lh+=zw[z]*(ev.lh[z]||0);lam+=zw[z]*ev.lam[z];}
    if(sec.type==='lau'&&efi&&T.has('launch'))ef*=1.08;
    const sm=T.setupMul(v,sec);
    out.push({ef,s:sm.S,a:sm.A,h:sm.H,t:sm.tm,kd:easy?0:kd,lh:easy?0:lh,lam,starve:!easy&&ev.starve&&(sec.type==='jmp'||sec.type==='rgh'),flood:!easy&&ev.flood&&sec.type==='rgh',
      smoke:lam<0.8?'rich':(ev.lam.idle>1.0||ev.lam.low>0.97)&&(sec.type==='hp'||sec.type==='chi')?'pop':null});}
  const ev0=evAt(0);return {secs:out,ev:ev0,foul:!easy&&ev0.foul,seize:!easy&&ev0.seize};
};

// ---------- crew tune (optimizer) ----------
T.err = (v,cond)=>{let s=0;const hill=cond.alt2!==cond.alt;const pts=hill?[0,0.5,1]:[0];
  for(const f of pts){const alt=cond.alt+(cond.alt2-cond.alt)*f;const temp=cond.temp-(alt-cond.alt)*0.0065;const ev=T.eval(v,{...cond,alt,temp},T.dens(alt,temp));
    for(const z of D.ZONES)s+=({idle:0.4,low:0.8,mid:1.2,wot:1.6}[z])*Math.pow(ev.lam[z]-D.LAM[z],2)+(ev.lam[z]>D.LAM[z]?0.5*Math.pow(ev.lam[z]-D.LAM[z],2):0);
    s+=0.6*Math.pow(ev.lam.trans-D.LAM.low,2)+0.02*(ev.kd.wot+ev.kd.mid);}
  return s;};
T.crewTune = (v,cond,q=0.97)=>{
  const e=v.eng;if(!e||e.fuel==='none')return;
  if(e.fuel==='carb'){const C=D.CARBS[e.carb];T.fillJets(v);e.jets.float=0;
    for(let it=0;it<4;it++)for(const p of C.p){if(p.k==='float')continue;let best=e.jets[p.k],bs=T.err(v,cond);
      for(let x=p.min;x<=p.max+1e-9;x+=p.step){e.jets[p.k]=+x.toFixed(2);const s=T.err(v,cond);if(s<bs-1e-9){bs=s;best=e.jets[p.k];}}e.jets[p.k]=best;}
    // timing: as far as safe
    let bt=-6;for(let t=-6;t<=8;t++){e.timing=t;const ev=T.eval(v,cond);if(ev.kd.wot<=0&&ev.kd.mid<=0)bt=t;}e.timing=Math.max(-6,bt-1);
    if(U.chance((1-q)*8)){const p=C.p[0];e.jets[p.k]=+U.clamp(e.jets[p.k]+(U.chance(0.5)?1:-1)*p.step,p.min,p.max).toFixed(2);}
  }else{const tv=T.trueVE(v);const tK=273.15+cond.temp;const rho=cond.alt2!==cond.alt?T.dens((cond.alt+cond.alt2)/2,cond.temp):cond.rho;const press=rho*tK/T.T0;
    const comp=(T.has('mapsens')?1:press)*(T.has('iat')?1:T.T0/tK);
    for(let j=0;j<6;j++)for(let i=0;i<8;i++){e.efi.afr[j][i]=D.AFR_DEF[j];
      e.efi.ve[j][i]=Math.round(tv[j][i]*comp*(1+(U.rand(-1,1))*(1-q)*0.6));
      const lam=e.efi.afr[j][i]/14.7;e.efi.ign[j][i]=Math.round(Math.min(T.mbt(i,j),T.kl(v,i,j,lam,cond)-1.5));}
    e.efi.ae=T.aeNeed(v);}
  const n=e.sync.length,bi=T.syncBase(n);e.sync=e.sync.map((x,i)=>i===bi?0:+(U.rand(-1,1)*(1-q)*3).toFixed(1));
  e.tunedFor=cond.name;
};
T.crewCost = ()=>Math.round((6000+G.ws*G.ws*6000)/1000)*1000;
T.rebuildCost = v=>Math.round(D.BODY[v.body].cost*0.12*(1-v.eng.cond+0.2)/1000)*1000;

// ---------- logging ----------
T.makeLog = (v,cond,src)=>{const ev=T.eval(v,cond);return {d:G.day,src,cond:cond.name,lam:{...ev.lam},kd:{...ev.kd},imb:ev.imb||0,cells:ev.cells?ev.cells.map(r=>r.slice()):null,wb:T.has('wideband')};};
