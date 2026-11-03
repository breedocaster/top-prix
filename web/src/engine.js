// ===================== ENGINE =====================
let G = null;
const E = {};
E.H = {toast(){},popup(){},float(){},sfx(){},roundDue(){},yearEnd(){},gameEnd(){},refresh(){}};

// ---------- helpers ----------
E.ws = ()=>D.WORKSHOPS[G.ws];
E.drivers = ()=>G.staff.filter(s=>s.role==='drv');
E.mechs = ()=>G.staff.filter(s=>s.role==='mec');
E.staff = id=>G.staff.find(s=>s.id===id);
E.veh = id=>G.vehicles.find(v=>v.id===id);
E.nid = ()=>G.nid++;
E.year = (d=G.day)=>Math.floor(d/D.DAYS_YEAR)+1;
E.dateStr = (d=G.day)=>{const y=E.year(d),m=Math.floor((d%D.DAYS_YEAR)/D.DAYS_MONTH),w=Math.floor((d%D.DAYS_MONTH)/7)+1;return `Y${y} ${D.MONTHS[m]} W${w}`;};
E.facV = fx=>{for(const f of G.fac){if(!f)continue;const F=D.FAC[f.id];if(F.fx===fx)return F.v[f.lv-1];}return 0;};
E.facLv = id=>{const f=G.fac.find(f=>f&&f.id===id);return f?f.lv:0;};
E.teamTech = ()=>U.sum(E.mechs(),s=>s.tech)+0.5*U.sum(E.drivers(),s=>s.tech);
E.fanRank = (f=G.fans)=>{let r=0;D.FAN_RANKS.forEach((x,i)=>{if(f>=x[0])r=i;});return r;};
E.fanRankName = ()=>D.FAN_RANKS[E.fanRank()][1];
E.log = (t)=>{G.log.unshift({d:G.day,t});if(G.log.length>40)G.log.length=40;};
E.say = (t)=>{E.log(t);E.H.toast(t);};
E.bays = ()=>E.ws().teams+1;
E.titlesIn = (tier,disc)=>G.st.titles.filter(t=>D.SER[t]&&(tier==null||D.SER[t].tier===tier)&&(disc==null||D.SER[t].disc===disc)).length;
E.wkey = (k)=>{G.st.wc[k]=(G.st.wc[k]||0)+1;};

// ---------- staff generation ----------
E.genStaff = (role,q)=>{
  const base=8+q*13; const r=(m=1)=>Math.max(1,Math.round(base*m*U.rand(0.6,1.4)));
  const s={id:E.nid(),role,name:U.pick(D.FIRST)+' '+U.pick(D.LAST),hair:U.pick(D.HAIR),skin:U.pick(D.SKIN),
    appeal:r(0.8),tech:r(role==='mec'?1.35:0.7),analysis:r(role==='mec'?1.0:0.7),lv:1,joined:G?G.day:0};
  if(role==='drv'){
    s.pedal=r(1.15);s.shift=r(1.15);s.steer=r(1.15);s.energy=100;s.maxE=100;
    const c=U.rand(0.86,1.16);s.aff={car:+c.toFixed(2),bike:+U.clamp(2.02-c+U.rand(-0.08,0.08),0.84,1.18).toFixed(2)};
    s.trait=U.chance(0.45)?U.pick(Object.keys(D.TRAITS)):null;
  }
  const avg=role==='drv'?(s.pedal+s.shift+s.steer+s.appeal+s.tech+s.analysis)/6:(s.appeal+s.tech+s.analysis)/3;
  s.salary=Math.round(avg*0.22+2+(role==='drv'?2:0))*1000;
  return s;
};
E.refreshCandidates = ()=>{
  const q=E.fanRank()+E.facV('scout')+G.ws*0.5;
  G.cand=[];
  for(let i=0;i<5;i++){const role=i<2?'drv':(i<4?'mec':U.pick(['drv','mec']));G.cand.push(E.genStaff(role,U.clamp(q+U.rand(-1,1.2),0,12)));}
};

// ---------- new game ----------
E.newGame = (name,color,mode)=>{
  G={v:1,team:{name:name||'Team Hoosier',color:color||D.TEAM_COLORS[0]},day:0,money:420000,rp:40,fans:0,ws:1,
    staff:[],vehicles:[],jobs:[],
    res:{body:{},layout:{},part:{}},unl:{body:{},layout:{},part:{},train:{},fac:{}},
    partLv:{},races:{},series:{},spons:[],sponDone:{},fac:[],sparks:{b:1,s:0,g:0},
    st:{races:0,wins:0,podiums:0,dnf:0,titles:[],earn:0,wc:{}},
    cand:[],settings:{speed:1,autoRetire:true,sound:true},log:[],nid:1,yearWins:{},
    lazy:{},ended:false,tut:0,lastSave:0,wxRain:false,year:{wins:0,podiums:0,earn:0,titles:0},tech:{carbbasic:1},ach:{}};
  G.settings.mode=mode||'standard';G.st.tests=0;G.st.streak=0;G.st.cells=0;
  D.BODIES.forEach(b=>{if(b.un==='S')G.res.body[b.id]=1;});
  D.LAYOUTS.forEach(l=>{if(l.un==='S')G.res.layout[l.id]=1;});
  const d=E.genStaff('drv',1.2);d.pedal+=4;d.shift+=4;d.steer+=4;G.staff.push(d);
  G.staff.push(E.genStaff('mec',1.4));G.staff.push(E.genStaff('mec',1.0));
  E.refreshCandidates();
  E.log('Welcome to the paddock! Build your first vehicle.');
  return G;
};

// ---------- availability / research ----------
E.bodyAvail = id=>{const b=D.BODY[id];if(G.res.body[id])return{ok:true,done:true};
  if(b.un==='sp')return G.unl.body[id]?{ok:true}:{ok:false,why:'Sponsor reward'};
  const w=D.RANK_WS[b.rank];return G.ws>=w?{ok:true}:{ok:false,why:`Needs ${D.WORKSHOPS[w].n}`};};
E.layoutAvail = id=>{const l=D.LAYOUT[id];if(G.res.layout[id])return{ok:true,done:true};
  if(l.un==='sp')return G.unl.layout[id]?{ok:true}:{ok:false,why:'Sponsor reward'};return{ok:true};};
E.partAvail = id=>{const p=D.PART[id];if(G.res.part[id])return{ok:true,done:true};
  if(p.un==='sp')return G.unl.part[id]?{ok:true}:{ok:false,why:'Sponsor reward'};
  const w=D.PART_TIER_WS[p.tier];return G.ws>=w?{ok:true}:{ok:false,why:`Needs ${D.WORKSHOPS[w].n}`};};
E.research = (kind,id)=>{
  const src={body:D.BODY,layout:D.LAYOUT,part:D.PART}[kind][id];
  const av=(kind==='body'?E.bodyAvail:kind==='layout'?E.layoutAvail:E.partAvail)(id);
  if(!av.ok||av.done)return false; if(G.rp<src.rp){E.H.toast('Not enough research data');return false;}
  G.rp-=src.rp;G.res[kind][id]=1;E.say(`Researched ${src.n}!`);E.H.sfx('good');return true;
};

// ---------- vehicles ----------
E.partClsOk = (p,cls)=>p.cls==='A'||(p.cls==='C'&&cls==='car')||(p.cls==='B'&&cls==='bike');
E.partLv = pid=>(G.partLv[pid]||{lv:1}).lv;
E.vs = v=>{
  const b=D.BODY[v.body]; const s={spd:v.base.spd+v.upAdd.spd,acc:v.base.acc+v.upAdd.acc,hnd:v.base.hnd+v.upAdd.hnd,dur:v.base.dur+v.upAdd.dur};
  const t={...v.terr}; let adv=b.adv; const fx={rp:0,mis:1,wear:1,fan:0};
  for(const pid of v.parts){const P=D.PART[pid];const lm=1+0.1*(E.partLv(pid)-1);
    for(const k in P.st){if(k in s)s[k]+=P.st[k]*lm;else if(k in t)t[k]+=P.st[k];else if(k==='adv')adv+=P.st[k];}
    if(P.fx.rp)fx.rp+=P.fx.rp;if(P.fx.mis)fx.mis*=P.fx.mis;if(P.fx.wear)fx.wear*=P.fx.wear;if(P.fx.fan)fx.fan+=P.fx.fan;}
  const lm=1+0.03*(v.lv-1); for(const k in s)s[k]=Math.max(5,Math.round(s[k]*lm));
  for(const k in t)t[k]=Math.round(U.clamp(t[k],5,220));
  return {...s,...t,adv,fx};
};
E.sysCost = (bid,lid,sys)=>{if(!sys||D.LAYOUT_CYL[lid]===0)return 0;const b=D.BODY[bid];if(sys.type==='efi')return T.efiCost(b);const def=T.defaultCarb(b.cls,lid);return sys.carb&&sys.carb!==def?T.carbSwapCost(b,sys.carb):0;};
E.vehCost = (bid,lid)=>Math.round(D.BODY[bid].cost*(1+D.LAYOUT[lid].cm)/1000)*1000;
E.buildQ = (bid)=>U.clamp(E.teamTech()/D.RANK_REQ[D.BODY[bid].rank],0.45,1.6);
E.qMult = q=>0.72+0.28*q;
E.activeJobs = ()=>G.jobs.length;
E.canStartJob = ()=>{if(G.jobs.length>=E.bays()){E.H.toast('All work bays busy!');return false;}return true;};
E.startBuild = (bid,lid,spark,sys)=>{
  const b=D.BODY[bid],L=D.LAYOUT[lid];if(!G.res.body[bid]||!G.res.layout[lid]||L.cls!==b.cls)return false;
  if(G.vehicles.length>=E.ws().veh){E.H.toast('Garage is full! Sell or scrap a vehicle.');return false;}
  if(!E.canStartJob())return false;
  const cost=E.vehCost(bid,lid)+E.sysCost(bid,lid,sys); if(G.money<cost){E.H.toast('Not enough money');return false;}
  if(sys&&sys.type==='efi'&&!T.has('efi'))return false;if(sys&&sys.carb&&!T.carbAvail(sys.carb))return false;
  if(spark&&!E.useSpark(spark))return false;
  G.money-=cost;
  const sb=spark?{b:0.1,s:0.2,g:0.3}[spark]:0;
  const n=G.vehicles.filter(v=>v.body===bid).length+1;
  const v={id:E.nid(),body:bid,layout:lid,name:`${b.n} #${n}`,q:E.buildQ(bid)+sb,phase:{spd:0,acc:0,hnd:0,dur:0},
    base:{spd:0,acc:0,hnd:0,dur:0},terr:{...b.t},upAdd:{spd:0,acc:0,hnd:0,dur:0},up:{spd:0,acc:0,hnd:0,dur:0},
    parts:[],lv:1,xp:0,hp:1,status:'build',races:0,wins:0,cost};
  T.initEng(v,sys);v.setup=T.defaultSetup(v);
  G.vehicles.push(v);
  G.jobs.push({id:E.nid(),type:'build',vid:v.id,left:b.days,total:b.days,req:D.RANK_REQ[b.rank],ph:0});
  E.say(`Started building ${v.name} (${L.n})`);E.H.sfx('click');return v;
};
E.finishBuild = v=>{
  const b=D.BODY[v.body],L=D.LAYOUT[v.layout];const qm=E.qMult(v.q);
  const fb={spd:E.facV('bSpd'),acc:E.facV('bAcc'),hnd:E.facV('bHnd'),dur:E.facV('bDur')};
  for(const k of['spd','acc','hnd','dur'])v.base[k]=Math.round(b.s[k]*qm*(1+(L.m[k]||0)/100)*(1+v.phase[k])*(1+fb[k]/100));
  const ft={on:E.facV('tOn'),off:E.facV('tOff'),wet:E.facV('tWet'),ice:E.facV('tIce')};
  for(const k of['on','off','wet','ice'])v.terr[k]=b.t[k]+(L.t[k]||0)+ft[k];
  v.status='ready';v.hp=1;
  E.ach('build1');if(v.eng&&v.eng.fuel==='efi'){T.initEFI(v);E.ach('efi1');}
  E.say(`${v.name} is complete!`);E.H.sfx('fanfare');E.H.float('Complete!',v.id,'#ffe066');
};
E.buildPhase = (v,job)=>{
  const r=Math.random()+(v.q-1)*0.35; const ks=['spd','acc','hnd','dur'];const k=U.pick(ks);
  let txt,amt,col;
  if(r>0.86){txt='Eureka!';amt=0.08;col='#ffe066';}
  else if(r>0.55){txt=U.pick(['Smooth!','Nice fit!','Clean welds!']);amt=0.04;col='#9ff';}
  else if(r>0.2){txt=U.pick(['Steady...','Hmm, okay.','Tightening up']);amt=0.01;col='#ddd';}
  else {txt=U.pick(['Oops!','Stripped a bolt!','Wrong part!']);amt=-0.03;col='#f88';}
  v.phase[k]+=amt;E.H.float(txt,v.id,col);
};
E.upCost = (v,k)=>Math.round(D.BODY[v.body].cost*0.12*Math.pow(v.up[k]+1,1.35)/1000)*1000;
E.startUpgrade = (vid,k,spark)=>{
  const v=E.veh(vid);if(!v||v.status!=='ready')return false;if(v.up[k]>=5)return false;if(!E.canStartJob())return false;
  const c=E.upCost(v,k);if(G.money<c){E.H.toast('Not enough money');return false;}
  if(spark&&!E.useSpark(spark))return false;
  G.money-=c;v.status='upgrade';
  const days=4+2*v.up[k];G.jobs.push({id:E.nid(),type:'up',vid,k,left:days,total:days,req:D.RANK_REQ[D.BODY[v.body].rank],spark:spark||null});
  E.say(`Upgrading ${v.name}: ${k.toUpperCase()}`);E.H.sfx('click');return true;
};
E.finishUpgrade = (v,job)=>{
  const b=D.BODY[v.body];const k=job.k;const q=U.clamp(E.teamTech()/job.req,0.45,1.6);
  const fb={spd:E.facV('bSpd'),acc:E.facV('bAcc'),hnd:E.facV('bHnd'),dur:E.facV('bDur')}[k];
  const sm=job.spark?{b:1.5,s:2,g:3}[job.spark]:1;
  const gain=Math.max(1,Math.round((b.s[k]*0.085+3)*(0.8+0.25*q)*(1+fb/100)*sm*U.rand(0.9,1.15)));
  v.upAdd[k]+=gain;v.up[k]++;v.status='ready';
  E.say(`${v.name}: ${k.toUpperCase()} +${gain}`);E.H.float(`${k.toUpperCase()} +${gain}`,v.id,'#7f7');E.H.sfx('good');
};
E.partCost = pid=>Math.round(D.PART[pid].cost*(1-E.facV('partdisc')/100)/1000)*1000;
E.installPart = (vid,pid)=>{
  const v=E.veh(vid),P=D.PART[pid],b=D.BODY[v.body];if(!v||!G.res.part[pid]||!E.partClsOk(P,b.cls))return false;
  if(v.status==='build'){E.H.toast('Still being built');return false;}
  if(v.parts.includes(pid))return false;
  const same=v.parts.find(x=>D.PART[x].cat===P.cat);
  if(!same&&v.parts.length>=b.slots){E.H.toast('No free part slots');return false;}
  const c=E.partCost(pid);if(G.money<c){E.H.toast('Not enough money');return false;}
  G.money-=c;if(same)v.parts=v.parts.filter(x=>x!==same);v.parts.push(pid);
  E.say(`Installed ${P.n} on ${v.name}`);E.H.float(P.n,v.id,'#9cf');E.H.sfx('good');return true;
};
E.removePart = (vid,pid)=>{const v=E.veh(vid);if(!v)return;v.parts=v.parts.filter(x=>x!==pid);};
E.rushCost = v=>Math.round((1-v.hp)*D.BODY[v.body].cost*0.3/1000+1)*1000;
E.rushRepair = vid=>{const v=E.veh(vid);if(!v||v.status!=='repair')return false;const c=E.rushCost(v);
  if(G.money<c){E.H.toast('Not enough money');return false;}G.money-=c;G.jobs=G.jobs.filter(j=>j.vid!==vid);v.hp=1;v.status='ready';
  E.say(`${v.name} rush-repaired`);E.H.sfx('good');return true;};
E.sellValue = v=>Math.round((v.cost*0.4+U.sum(v.parts,p=>D.PART[p].cost*0.25))/1000)*1000;
E.scrapRP = v=>Math.round(D.BODY[v.body].rp*0.3+v.races*2+5);
E.removeVehicle = vid=>{G.vehicles=G.vehicles.filter(v=>v.id!==vid);G.jobs=G.jobs.filter(j=>j.vid!==vid);};
E.sell = vid=>{const v=E.veh(vid);if(!v||v.status==='build')return false;const m=E.sellValue(v);G.money+=m;E.removeVehicle(vid);E.say(`Sold ${v.name} for ${U.money(m)}`);return true;};
E.scrap = vid=>{const v=E.veh(vid);if(!v||v.status==='build')return false;const r=E.scrapRP(v);G.rp+=r;E.removeVehicle(vid);E.say(`Scrapped ${v.name}: +${r} RP`);return true;};

// ---------- sparks ----------
E.useSpark = t=>{if(!G.sparks[t]){E.H.toast('No spark of that kind');return false;}G.sparks[t]--;return true;};
E.giveSpark = (t,why)=>{G.sparks[t]++;const n={b:'Bronze',s:'Silver',g:'Gold'}[t];E.say(`Got a ${n} Spark! ${why||''}`);};

// ---------- staff actions ----------
E.hire = cid=>{
  const c=G.cand.find(x=>x.id===cid);if(!c)return false;
  const W=E.ws(); if(c.role==='drv'&&E.drivers().length>=W.teams+1){E.H.toast(`Driver limit (${W.teams+1}) — upgrade workshop`);return false;}
  if(c.role==='mec'&&E.mechs().length>=W.mech){E.H.toast(`Mechanic limit (${W.mech}) — upgrade workshop`);return false;}
  const fee=c.salary*3;if(G.money<fee){E.H.toast('Not enough money');return false;}
  G.money-=fee;c.joined=G.day;G.staff.push(c);G.cand=G.cand.filter(x=>x!==c);
  E.say(`${c.name} joined the team!`);E.H.sfx('fanfare');return true;
};
E.fire = sid=>{const s=E.staff(sid);if(!s)return false;if(s.role==='drv'&&E.drivers().length<=1){E.H.toast('You need at least one driver');return false;}
  G.staff=G.staff.filter(x=>x!==s);E.say(`${s.name} left the team.`);return true;};
E.mechLvCost = s=>Math.round(12*Math.pow(s.lv,1.9));
E.levelMech = sid=>{const s=E.staff(sid);if(!s||s.role!=='mec'||s.lv>=10)return false;const c=E.mechLvCost(s);
  if(G.rp<c){E.H.toast('Not enough research data');return false;}G.rp-=c;s.lv++;
  const t=U.ri(3,6)+s.lv,a=U.ri(1,3),an=U.ri(1,4);s.tech+=t;s.appeal+=a;s.analysis+=an;s.salary=Math.round(s.salary*1.08/1000)*1000;
  E.say(`${s.name} reached Lv${s.lv}! Tech +${t}`);E.H.sfx('good');return true;};
E.trainCost = (s,t)=>t.cost<0?Math.round(t.cost*(1+E.fanRank()*0.3)/1000)*1000:Math.round(t.cost*(1+(s.pedal+s.shift+s.steer)/450)/1000)*1000;
E.trainAvail = id=>{const t=D.TRAIN[id];return t.un==='S'||!!G.unl.train[id];};
E.train = (sid,tid,spark)=>{
  const s=E.staff(sid),t=D.TRAIN[tid];if(!s||s.role!=='drv'||!E.trainAvail(tid))return null;
  const en=Math.round(t.en*(s.trait==='iron'?0.6:1));if(s.energy<en){E.H.toast(`${s.name} is too tired`);return null;}
  const tc=E.trainCost(s,t);if(tc>0&&G.money<tc){E.H.toast('Not enough money');return null;}
  if(spark&&!E.useSpark(spark))return null;
  G.money-=tc;s.energy-=en;const out={};
  const sm=spark?{b:1.5,s:2,g:3}[spark]:1;const gm=(1+E.facV('train')/100)*(s.trait==='bloomer'?1.4:1)*sm;
  for(const k in t.g){
    if(k==='car'||k==='bike'){s.aff[k]=+Math.min(1.45,s.aff[k]+t.g[k]*sm).toFixed(2);out[k]='+';continue;}
    if(k==='maxE'){s.maxE=Math.min(160,s.maxE+t.g[k]);out.maxE=t.g[k];continue;}
    const dim=120/(120+s[k]*0.35);const g=Math.max(1,Math.round(t.g[k]*gm*U.rand(0.8,1.3)*dim));s[k]+=g;out[k]=g;
  }
  if(tid==='oddjobs'){out.money=-tc;}
  return out;
};

// ---------- sponsors ----------
E.sponsorOffers = ()=>D.SPONSORS.filter(s=>G.fans>=s.fans&&!G.spons.find(x=>x.id===s.id)).sort((a,b)=>b.fans-a.fans).slice(0,5);
E.sponsorPay = sp=>Math.round(D.SPON[sp.id].mo*1000*(1+0.3*(sp.ad-1))*(1+E.facV('spon')/100));
E.signSponsor = id=>{
  if(G.spons.length>=E.ws().spon){E.H.toast('Sponsor slots full');return false;}
  const S=D.SPON[id];const done=!!G.sponDone[id];
  G.money+=done?Math.round(S.sign*500):S.sign*1000;
  G.spons.push({id,ad:1,adx:0,day:G.day,base:{st:JSON.parse(JSON.stringify(G.st)),fans:G.fans},done});
  E.say(`Signed with ${S.n}!`);E.H.sfx('fanfare');return true;
};
E.cancelSponsor = id=>{G.spons=G.spons.filter(s=>s.id!==id);E.say(`Contract with ${D.SPON[id].n} ended.`);};
E.goalKey = g=>g.disc?'disc:'+g.disc:g.surf?'terr:'+g.surf:g.cls?'cls:'+g.cls:g.tier?'tier:'+g.tier:null;
E.goalProgress = sp=>{
  const g=D.SPON[sp.id].goal,b=sp.base.st;
  switch(g.t){
    case 'enter':return[G.st.races-b.races,g.n];
    case 'races':return[G.st.races-b.races,g.n];
    case 'podium':return[G.st.podiums-b.podiums,g.n];
    case 'win':{const k=E.goalKey(g);if(!k)return[G.st.wins-b.wins,g.n];return[(G.st.wc['w:'+k]||0)-(b.wc['w:'+k]||0),g.n];}
    case 'series':{const cnt=G.st.titles.filter(t=>{const S=D.SER[t];return(!g.tier||S.tier===g.tier)&&(!g.disc||S.disc===g.disc);}).length;
      const bc=b.titles.filter(t=>{const S=D.SER[t];return(!g.tier||S.tier===g.tier)&&(!g.disc||S.disc===g.disc);}).length;return[cnt-bc,g.n];}
    case 'fans':return[G.fans,g.n];
    case 'money':return[G.money,g.n];
  }return[0,1];
};
E.goalText = g=>{
  const f=[g.disc?D.DISC[g.disc].n:'',g.surf?D.TERR_N[g.surf]:'',g.cls==='bike'?'bike':g.cls==='car'?'car':'',g.tier?D.TIER_N[g.tier]:''].filter(Boolean).join(' ');
  switch(g.t){case 'enter':return`Enter ${g.n} races`;case 'races':return`Run ${g.n} races`;case 'podium':return`Finish on the podium ${g.n}×`;
    case 'win':return`Win ${g.n>1?g.n+' ':'a '}${f?f+' ':''}race${g.n>1?'s':''}`;case 'series':return`Win ${g.n>1?g.n+' ':'a '}${f?f+' ':''}series title${g.n>1?'s':''}`;
    case 'fans':return`Reach ${U.num(g.n)} fans`;case 'money':return`Hold ${U.money(g.n)}`;}return'';
};
E.rewardText = rw=>{const a=[];
  (rw.train||[]).forEach(t=>a.push('Training: '+D.TRAIN[t].n));(rw.layout||[]).forEach(t=>a.push('Layout: '+D.LAYOUT[t].n));
  (rw.part||[]).forEach(t=>a.push('Part: '+D.PART[t].n));(rw.body||[]).forEach(t=>a.push('Vehicle: '+D.BODY[t].n));
  (rw.fac||[]).forEach(t=>a.push('Facility: '+D.FAC[t].n));if(rw.cash)a.push('Bonus '+U.money(rw.cash*1000));return a.join(', ');};
E.checkSponsors = ()=>{
  for(const sp of G.spons){if(sp.done)continue;const[c,n]=E.goalProgress(sp);if(c>=n){
    sp.done=true;G.sponDone[sp.id]=1;const S=D.SPON[sp.id],rw=S.rw;
    (rw.train||[]).forEach(t=>G.unl.train[t]=1);(rw.layout||[]).forEach(t=>G.unl.layout[t]=1);(rw.part||[]).forEach(t=>G.unl.part[t]=1);
    (rw.body||[]).forEach(t=>G.unl.body[t]=1);(rw.fac||[]).forEach(t=>G.unl.fac[t]=1);if(rw.cash)G.money+=rw.cash*1000;
    E.log(`${S.n} goal complete!`);E.H.popup({title:'Sponsor Goal Achieved!',html:`<b>${U.esc(S.n)}</b> is thrilled!<br><br>Unlocked: ${U.esc(E.rewardText(rw))}`});E.H.sfx('fanfare');
  }}
};

// ---------- facilities ----------
E.facAvail = id=>D.FAC[id].un==='S'||!!G.unl.fac[id];
E.buildFac = (id)=>{
  const W=E.ws();const used=G.fac.filter(Boolean).length;if(used>=W.fac){E.H.toast('No free facility slots');return false;}
  if(G.fac.find(f=>f&&f.id===id))return false;const c=D.FAC[id].cost[0]*1000;if(G.money<c){E.H.toast('Not enough money');return false;}
  G.money-=c;G.fac.push({id,lv:1});E.say(`Built ${D.FAC[id].n}!`);E.H.sfx('fanfare');return true;};
E.upgradeFac = id=>{const f=G.fac.find(f=>f&&f.id===id);if(!f||f.lv>=3)return false;const c=D.FAC[id].cost[f.lv]*1000;
  if(G.money<c){E.H.toast('Not enough money');return false;}G.money-=c;f.lv++;E.say(`${D.FAC[id].n} upgraded to Lv${f.lv}`);E.H.sfx('good');return true;};
E.demolishFac = id=>{G.fac=G.fac.filter(f=>f&&f.id!==id);E.say(`Removed ${D.FAC[id].n}`);};

// ---------- workshop ----------
E.wsNeed = ()=>G.ws<4?{titles:1,tier:G.ws,cost:D.WORKSHOPS[G.ws+1].cost}:null;
E.canUpgradeWS = ()=>{const n=E.wsNeed();if(!n)return false;return E.titlesIn(n.tier)>=n.titles;};
E.upgradeWS = ()=>{if(!E.canUpgradeWS())return false;const n=E.wsNeed();if(G.money<n.cost){E.H.toast('Not enough money');return false;}
  G.money-=n.cost;G.ws++;E.say(`Moved into the ${E.ws().n}!`);E.H.sfx('fanfare');
  E.H.popup({title:`Welcome to the ${E.ws().n}!`,html:`More room for staff, vehicles, facilities and sponsors.<br><br>New ${D.TIER_N[G.ws]} races and research are now available!`});return true;};
E.legendOpen = ()=>G.ws>=4&&E.titlesIn(4)>=2;

// ---------- races ----------
E.best = id=>(G.races[id]&&G.races[id].best)||99;
E.raceState = id=>{
  const r=D.RACE[id];if(r.excl)return{ok:false,why:'Series only',series:true};
  if(r.tier===5){if(!E.legendOpen())return{ok:false,why:'Win 2 World series'};}
  else if(G.ws<r.tier)return{ok:false,why:`Needs ${D.WORKSHOPS[r.tier].n}`};
  if(r.letter==='a'){if(r.disc==='OP'&&r.tier===1&&G.st.wins<2)return{ok:false,why:'Win 2 races first'};return{ok:true};}
  const prev=r.id.slice(0,-1)+(r.letter==='b'?'a':'b');
  if(E.best(prev)>3)return{ok:false,why:`Top 3 at ${D.RACE[prev].n}`};return{ok:true};
};
E.seriesState = id=>{
  const S=D.SER[id];const st=G.series[id]||{};
  if(st.act)return{ok:false,active:true,why:'In progress'};
  if(S.tier===5&&!E.legendOpen())return{ok:false,why:'Win 2 World series'};
  if(S.tier<5&&G.ws<S.tier)return{ok:false,why:`Needs ${D.WORKSHOPS[S.tier].n}`};
  const normals=D.RACES.filter(r=>r.tier===S.tier&&r.disc===S.disc&&!r.excl);
  const need=S.disc==='OP'&&S.tier<5?1:2;const w=normals.filter(r=>E.best(r.id)===1).length;
  if(w<need)return{ok:false,why:`Win ${need} ${D.DISC[S.disc].n} ${D.TIER_N[S.tier]} race${need>1?'s':''} (${w}/${need})`};
  if(st.lastStart!=null&&G.day-st.lastStart<D.DAYS_YEAR)return{ok:false,why:`Next season in ${D.DAYS_YEAR-(G.day-st.lastStart)}d`};
  if(Object.values(G.series).filter(x=>x.act).length>=E.ws().teams)return{ok:false,why:'Too many active series'};
  return{ok:true};
};
E.availRaceIds = ()=>D.RACES.filter(r=>E.raceState(r.id).ok).map(r=>r.id).concat(D.SERIES.filter(s=>E.seriesState(s.id).ok).map(s=>s.id));
E.clsOk = (race,v)=>race.cls==='any'||D.BODY[v.body].cls===race.cls;
E.eligibleVehicles = race=>G.vehicles.filter(v=>v.status==='ready'&&E.clsOk(race,v)&&E.engReady(v));
E.raceEnergy = s=>s.trait==='iron'?20:30;
E.eligibleDrivers = ()=>E.drivers().filter(s=>s.energy>=E.raceEnergy(s));

// effective race profile of driver+vehicle
E.profile = (v,s)=>{
  const st=E.vs(v),cls=D.BODY[v.body].cls,aff=s.aff[cls];
  const dm=x=>1+x/(x+250);let S=st.spd*dm(s.pedal)*aff,A=st.acc*dm(s.shift)*aff,H=st.hnd*dm(s.steer)*aff;
  if(s.trait==='drift'&&cls==='car')H*=1.1;if(s.trait==='wheelie'&&cls==='bike')A*=1.1;
  const t={on:st.on,off:st.off,wet:st.wet,ice:st.ice};
  if(s.trait==='dirt')t.off+=15;if(s.trait==='rain')t.wet+=20;if(s.trait==='ice')t.ice+=20;if(s.trait==='tar')t.on+=10;
  let pm=1;if(s.trait==='hothead')pm*=1.04;if(s.energy<40)pm*=0.95;
  let mis=st.fx.mis;if(s.trait==='steady')mis*=0.6;if(s.trait==='hothead')mis*=1.6;
  return {S,A,H,t,pm,mis,wear:st.fx.wear*(s.trait==='iron'?0.9:1)*(cls==='bike'?0.85:1),dur:st.dur,cls};
};
// expected pace ratio vs race rating
E.oddsRatio = (race,v,s)=>{
  const p=E.profile(v,s);const tr=Race.track(race,false);const rt=Race.rivalTerr(race);let tot=0,rv=0;
  const cond=T.forecast(race);const rsx=T.raceSecs(v,race,tr,cond,T.mode()==='easy');
  tr.secs.forEach((sc,i)=>{const w=D.SEC[sc.type].w;const tk=D.SURF[sc.surf].k;const k=rsx.secs[i];tot+=((w[0]*p.S*k.s+w[1]*p.A*k.a)*k.ef+w[2]*p.H*k.h)*(U.clamp(p.t[tk]*k.t,5,220)/100)*p.pm*sc.len;rv+=race.R*Race.rivalMul()*(rt[tk]+1)/100*sc.len;});
  return tot/rv;
};
E.oddsLabel = r=>r<0.8?['Hopeless','#f55']:r<0.95?['Tough','#f95']:r<1.07?['Even','#fd5']:r<1.2?['Favored','#9e5']:['Dominant','#5ef'];

// ---------- series ----------
E.enterSeries = id=>{
  const S=D.SER[id];const st=E.seriesState(id);if(!st.ok){E.H.toast(st.why);return false;}
  if(G.money<S.fee){E.H.toast('Not enough money for entry fee');return false;}
  G.money-=S.fee;const rv=U.shuffle(D.RIVALS).slice(0,S.rivals);
  const rivals=rv.map((r,i)=>({team:r[0],col:r[1],drv:U.pick(D.FIRST)+' '+U.pick(D.LAST),f:+(1.13-0.3*i/(S.rivals-1)+U.rand(-0.03,0.03)).toFixed(3)}));
  G.series[id]=G.series[id]||{titles:0,best:99};G.series[id].lastStart=G.day;
  G.series[id].act={round:0,next:G.day+7,pts:{you:0},rivals,res:[],pending:false};
  rivals.forEach(r=>G.series[id].act.pts[r.team]=0);
  E.say(`Entered the ${S.n}! Round 1 in 7 days.`);E.H.sfx('fanfare');return true;
};
E.standings = id=>{const a=G.series[id].act;return Object.entries(a.pts).sort((x,y)=>y[1]-x[1]);};
E.seriesRoundDone = (id,rs)=>{
  const a=G.series[id].act,S=D.SER[id];
  // points
  rs.order.forEach((e,i)=>{if(e.dnf)return;const p=D.POINTS[i]||0;const key=e.isPlayer?'you':e.team;a.pts[key]=(a.pts[key]||0)+p;});
  const me=rs.order.findIndex(e=>e.isPlayer);a.res.push(rs.player.dnf?'DNF':me+1);
  a.round++;a.pending=false;
  if(a.round>=S.rounds.length)E.endSeries(id);else{a.next=G.day+21;E.log(`${S.n}: round ${a.round+1} in 3 weeks`);}
};
E.seriesRoundSkip = id=>{const a=G.series[id].act;a.res.push('—');a.round++;a.pending=false;
  // rivals still score
  const order=a.rivals.slice().sort((x,y)=>y.f*U.rand(0.9,1.1)-x.f*U.rand(0.9,1.1));order.forEach((r,i)=>a.pts[r.team]+=D.POINTS[i]||0);
  if(a.round>=D.SER[id].rounds.length)E.endSeries(id);else a.next=G.day+21;};
E.endSeries = id=>{
  const S=D.SER[id],st=G.series[id],a=st.act;const tb=E.standings(id);const pos=tb.findIndex(x=>x[0]==='you')+1;
  st.lastEnd=G.day;st.best=Math.min(st.best||99,pos);delete st.act;
  let html=`<div class="stand">`+tb.slice(0,6).map((x,i)=>`<div class="${x[0]==='you'?'me':''}">${i+1}. ${U.esc(x[0]==='you'?G.team.name:x[0])} <b>${x[1]}</b></div>`).join('')+`</div>`;
  if(pos===1){
    const first=!G.st.titles.includes(id);G.st.titles.push(id);st.titles++;G.year.titles++;
    const prize=first?S.prize:Math.round(S.prize*0.5);G.money+=prize;G.st.earn+=prize;G.year.earn+=prize;
    const fans=Math.round(S.prize/1500*(1+E.facV('fans')/100));G.fans+=fans;E.giveSpark('g','Series champion!');
    html=`<div class="big">🏆 CHAMPIONS! 🏆</div>${html}<br>Prize ${U.money(prize)} · Fans +${U.num(fans)}`;
    if(E.canUpgradeWS())html+=`<br><br><b class="hl">A bigger workshop is available! (Team menu)</b>`;
    E.H.sfx('fanfare');
  }else{
    const prize=pos<=3?Math.round(S.prize*(pos===2?0.4:0.2)):0;G.money+=prize;G.st.earn+=prize;G.fans+=Math.round(S.prize/6000);
    html=`<div class="big">${U.ord(pos)} in the championship</div>${html}`+(prize?`<br>Prize ${U.money(prize)}`:'');
  }
  E.log(`${S.n} finished: ${U.ord(pos)}`);E.H.popup({title:S.n+' — Final',html});E.checkSponsors();
};

// ---------- race results ----------
E.finishRace = (rs)=>{
  const def=rs.def,P=rs.player,v=E.veh(P.vid),s=E.staff(P.sid);
  const pos=rs.forcePos||rs.order.indexOf(P)+1;const dnf=P.dnf;const mul=(rs.fmt&&rs.fmt.mul)||{prize:1,rp:1,fans:1,wear:1};const ff=dnf?0.1:[1,.75,.6,.45,.38,.32,.28,.24,.2,.18,.16,.15][pos-1]||0.12;
  const out={pos,dnf,prize:0,rp:0,fans:0,unl:[],spark:null,destroyed:P.destroyed};
  const before=new Set(E.availRaceIds());const rk0=E.fanRank();
  // money
  const rep=!rs.series&&G.yearWins[def.id]?0.4:1;if(!dnf&&pos<=12){out.prize=Math.round(def.prize*D.PRIZE_SPLIT[pos-1]*rep*mul.prize/100)*100;}out.rep=rep<1;
  G.money+=out.prize;G.st.earn+=out.prize;G.year.earn+=out.prize;
  // RP
  const mAn=E.mechs().length?U.sum(E.mechs(),m=>m.analysis)/E.mechs().length:0;
  const vst=v?E.vs(v):{fx:{rp:0,fan:0},adv:0};
  out.rp=Math.round(def.rp*ff*(1+(s.analysis+mAn)/250)*(1+E.facV('rp')/100)*(1+vst.fx.rp)*(rs.series?1.3:1)*(rep<1?0.6:1)*mul.rp*(T.has('telem')?1.1:1));G.rp+=out.rp;
  // fans
  out.fans=Math.round(def.R*0.6*ff*(rep<1?0.5:1)*mul.fans*(1+s.appeal/250)*(1+E.facV('fans')/100)*(s.trait==='show'?1.3:1)*(1+vst.fx.fan)*(rs.series?1.4:1));G.fans+=out.fans;
  // stats
  G.st.races++;if(!dnf&&pos===1){G.st.wins++;G.year.wins++;G.yearWins[def.id]=1;}if(!dnf&&pos<=3){G.st.podiums++;G.year.podiums++;}if(dnf)G.st.dnf++;
  if(!dnf&&pos===1){E.wkey('w:disc:'+def.disc);E.wkey('w:cls:'+(v?D.BODY[v.body].cls:def.cls));E.wkey('w:tier:'+def.tier);
    const tk={};for(const k in def.surf){const t=D.SURF[k].k;tk[t]=(tk[t]||0)+def.surf[k];}if(rs.rain&&tk.on){tk.wet=(tk.wet||0)+tk.on;}
    for(const k in tk)if(tk[k]>=40)E.wkey('w:terr:'+k);}
  // best & sparks
  const rr=G.races[def.id]=G.races[def.id]||{best:99,n:0,w:0};rr.n++;if(!dnf&&pos===1)rr.w++;
  if(!dnf&&pos<rr.best){if(pos<=3){const t=pos===1?'g':pos===2?'s':'b';E.giveSpark(t,'First '+(pos===1?'win':'podium')+' here!');out.spark=t;}rr.best=pos;}
  if(!dnf&&s.trait==='lucky'&&U.chance(0.15)){E.giveSpark('b','Lucky!');}
  // vehicle
  if(v){
    v.races++;if(!dnf&&pos===1)v.wins++;
    if(P.destroyed){E.removeVehicle(v.id);E.log(`${v.name} was destroyed!`);}
    else{
      v.hp=U.clamp(P.hp,0,1);v.xp+=Math.round(def.tier*12*(ff+0.3));
      while(v.lv<10&&v.xp>=E.vehXpNeed(v)){v.xp-=E.vehXpNeed(v);v.lv++;out.vlv=v.lv;}
      for(const pid of v.parts){const pl=G.partLv[pid]=G.partLv[pid]||{lv:1,xp:0};if(pl.lv<5){pl.xp+=def.tier*8+4;while(pl.lv<5&&pl.xp>=40*pl.lv){pl.xp-=40*pl.lv;pl.lv++;}}}
      E.engAfter(v,rs,P,mul);
      if(v.hp<0.999){const days=Math.max(1,Math.ceil((1-v.hp)*14));v.status='repair';G.jobs.push({id:E.nid(),type:'rep',vid:v.id,left:days,total:days,req:D.RANK_REQ[D.BODY[v.body].rank],nob:true});}
      else v.status='ready';
    }
  }
  // driver
  s.energy=Math.max(0,s.energy-E.raceEnergy(s));
  const gains=[];if(U.chance(0.6)){const k=U.pick(['pedal','shift','steer']);s[k]+=1;gains.push(k);}
  // sponsors ad
  for(const sp of G.spons){if(sp.ad>=5)continue;sp.adx+=(s.appeal+vst.adv)/8*(ff+0.3);while(sp.ad<5&&sp.adx>=60*sp.ad){sp.adx-=60*sp.ad;sp.ad++;E.log(`${D.SPON[sp.id].n} ad effect Lv${sp.ad}!`);}}
  // streaks & achievements
  if(!dnf&&pos===1){G.st.streak=(G.st.streak||0)+1;if(G.st.streak>=3)E.ach('hat');}else G.st.streak=0;
  if(!dnf&&pos===1){const c=rs.cond||{alt:0,temp:20};if(v&&v.eng&&v.eng.fuel==='carb'&&Math.max(c.alt,c.alt2||0)>=2500)E.ach('thinair');if(c.temp<=-10)E.ach('frozen');
    if(def.disc==='HC'||def.style==='hill'){E.ach('hill1');if((c.alt2||0)>=4000)E.ach('clouds');}if(rs.fmt&&rs.fmt.id==='endur')E.ach('endur');
    if(rs.gridSlot!=null&&rs.gridSlot>=Math.floor(rs.ents.length/2))E.ach('comeback');if(rs.heatWin)E.ach('heatmain');if(rs.drag)E.ach('drag1');}
  if(!dnf&&rs.fmt&&rs.fmt.id==='endur')E.ach('endur');
  if(P.holed)E.ach('holed');if(P.seized)E.ach('seize');
  if(rs.fuelCost){G.money-=rs.fuelCost;}
  E.checkSponsors();E.checkAch();
  const after=E.availRaceIds();out.unl=after.filter(x=>!before.has(x));
  E.log(`${def.n}: ${dnf?'DNF':U.ord(pos)} (+${U.money(out.prize)})`);
  const rk1=E.fanRank();if(rk1>rk0){E.H.popup({title:'📣 Team Rank Up!',html:`Your team is now <b class="hl">${D.FAN_RANKS[rk1][1]}</b>!<br><br>Bigger sponsors are calling, and better staff want to join.`});E.refreshCandidates();}
  return out;
};
E.engAfter = (v,rs,P,mul)=>{
  const e=v.eng;if(!e)return;
  if(e.fuel!=='none'){
    const wear=0.014*mul.wear*(T.has('oilcool')?0.7:1)*(rs.tactic==='push'?1.3:rs.tactic==='safe'?0.8:1);
    e.cond=U.clamp((P.cond!=null?P.cond:e.cond)-wear,0,1);
    const n=e.sync.length,bi=T.syncBase(n);e.sync=e.sync.map((x,i)=>i===bi?0:+U.clamp(x+U.rand(-0.45,0.45)*(1+def_t(rs)*0.1),-6,6).toFixed(1));
    if(T.has('datalog')&&rs.cond)e.log=T.makeLog(v,rs.cond,'Race: '+rs.def.n);
    if(e.cond<=0)E.H.popup({title:'💥 Engine Failure',html:`${U.esc(v.name)}'s engine is finished. Open <b>Garage → Engine</b> to rebuild it before racing again.`});
  }
};
const def_t = rs=>rs.def.tier||1;
E.engReady = v=>!v.eng||v.eng.fuel==='none'||v.eng.cond>0.02;
E.startRebuild = vid=>{const v=E.veh(vid);if(!v||v.status!=='ready')return false;if(!E.canStartJob())return false;const c=T.rebuildCost(v);if(G.money<c){E.H.toast('Not enough money');return false;}
  G.money-=c;v.status='upgrade';const days=Math.ceil(3+(1-v.eng.cond)*10);G.jobs.push({id:E.nid(),type:'reb',vid,left:days,total:days,req:D.RANK_REQ[D.BODY[v.body].rank]});E.say(`Rebuilding ${v.name}'s engine`);return true;};
E.startSwap = (vid,sys)=>{const v=E.veh(vid);if(!v||v.status!=='ready')return false;if(!E.canStartJob())return false;const b=D.BODY[v.body];
  const c=sys.type==='efi'?T.efiCost(b):T.carbSwapCost(b,sys.carb);if(G.money<c){E.H.toast('Not enough money');return false;}
  G.money-=c;v.status='upgrade';G.jobs.push({id:E.nid(),type:'swap',vid,sys,left:4,total:4,req:D.RANK_REQ[b.rank]});E.say(`Fitting ${sys.type==='efi'?'EFI':D.CARBS[sys.carb].n} to ${v.name}`);return true;};
E.researchTech = id=>{const t=D.TECHM[id];if(!t||T.has(id))return false;if(!E.techAvail(id).ok)return false;if(G.rp<t.rp){E.H.toast('Not enough research data');return false;}
  G.rp-=t.rp;G.tech[id]=1;E.say(`Tech unlocked: ${t.n}!`);E.H.sfx('fanfare');E.checkAch();return true;};
E.techAvail = id=>{const t=D.TECHM[id];if(T.has(id))return{ok:true,done:true};if(G.ws<t.ws)return{ok:false,why:`Needs ${D.WORKSHOPS[t.ws].n}`};
  const miss=t.req.filter(r=>!T.has(r));if(miss.length)return{ok:false,why:'Needs '+miss.map(r=>D.TECHM[r].n).join(', ')};return{ok:true};};
E.ach = id=>{if(!G.ach)G.ach={};if(G.ach[id])return false;const a=D.ACHM[id];if(!a)return false;G.ach[id]=G.day+1;
  const rw=a.rw||{};if(rw.cash)G.money+=rw.cash*1000;if(rw.rp)G.rp+=rw.rp;if(rw.spark)G.sparks[rw.spark]++;
  const r=[rw.cash?U.money(rw.cash*1000):'',rw.rp?rw.rp+' RP':'',rw.spark?({b:'Bronze',s:'Silver',g:'Gold'}[rw.spark])+' Spark':''].filter(Boolean).join(' + ');
  E.log(`Achievement: ${a.n}`);E.H.popup({title:`${a.ic} Achievement!`,html:`<div class="big">${U.esc(a.n)}</div><div style="text-align:center">${U.esc(a.d)}</div>${r?`<div style="text-align:center" class="hl">Reward: ${r}</div>`:''}`});E.H.sfx('fanfare');return true;};
E.checkAch = ()=>{for(const a of D.ACH)if(a.chk&&!(G.ach&&G.ach[a.id])){try{if(a.chk(G))E.ach(a.id);}catch(e){}}};
E.vehXpNeed = v=>Math.round(40*Math.pow(v.lv,1.3));

// ---------- test day ----------
E.testCost = laps=>laps*3000*G.ws;
E.finishTest = rs=>{
  const v=E.veh(rs.player.vid),s=E.staff(rs.player.sid);const laps=rs.tr.laps;const out={gains:[]};
  G.money-=E.testCost(laps);s.energy=Math.max(0,s.energy-(8+2*laps));G.st.tests=(G.st.tests||0)+1;
  const n=Math.max(1,Math.floor(laps/3));for(let i=0;i<n;i++){const k=U.pick(['pedal','shift','steer']);s[k]+=1;out.gains.push(k);}
  const cls=D.BODY[v.body].cls;s.aff[cls]=+Math.min(1.45,s.aff[cls]+0.004*laps).toFixed(3);
  v.xp+=laps*2;while(v.lv<10&&v.xp>=E.vehXpNeed(v)){v.xp-=E.vehXpNeed(v);v.lv++;}
  if(v.eng&&v.eng.fuel!=='none'){v.eng.cond=U.clamp((rs.player.cond!=null?rs.player.cond:v.eng.cond)-0.002*laps,0,1);v.eng.log=T.makeLog(v,rs.cond,'Test: '+rs.def.n);}
  v.hp=U.clamp(rs.player.hp,0,1);if(v.hp<0.999){const days=Math.max(1,Math.ceil((1-v.hp)*14));v.status='repair';G.jobs.push({id:E.nid(),type:'rep',vid:v.id,left:days,total:days,req:D.RANK_REQ[D.BODY[v.body].rank],nob:true});}
  E.checkAch();E.log(`Test day: ${laps} laps with ${v.name}`);return out;
};

// ---------- time ----------
E.jobRate = job=>{
  const n=G.jobs.filter(j=>!j.nob).length;const share=job.nob?1:1+0.35*Math.max(0,n-1);
  const lazy=G.lazyUntil&&G.lazyUntil>G.day?0.6:1;
  return U.clamp(0.5+0.7*E.teamTech()/job.req,0.5,2.6)*(1+E.facV('speed')/100)/share*lazy;
};
E.tick = ()=>{
  G.day++;
  // jobs
  for(const j of G.jobs.slice()){
    const v=E.veh(j.vid);if(!v){G.jobs=G.jobs.filter(x=>x!==j);continue;}
    j.left-=E.jobRate(j);
    if(j.type==='build'){const prog=1-j.left/j.total;const ph=[0.3,0.6,0.9];while(j.ph<3&&prog>=ph[j.ph]){E.buildPhase(v,j);j.ph++;}}
    if(j.type==='rep')v.hp=Math.min(1,v.hp+(1/14)*E.jobRate(j));
    if(j.left<=0){G.jobs=G.jobs.filter(x=>x!==j);
      if(j.type==='build')E.finishBuild(v);else if(j.type==='up')E.finishUpgrade(v,j);else if(j.type==='rep'){v.hp=1;v.status='ready';E.log(`${v.name} repaired`);}
      else if(j.type==='reb'){v.eng.cond=1;v.status='ready';E.say(`${v.name}: fresh engine!`);E.H.float('Rebuilt!',v.id,'#8ef58e');}
      else if(j.type==='swap'){const keep=v.eng.fuelT;T.initEng(v,j.sys);v.eng.fuelT=keep;v.status='ready';E.say(`${v.name}: ${j.sys.type==='efi'?'EFI installed — base map loaded, go tune it!':D.CARBS[j.sys.carb].n+' fitted'}`);if(j.sys.type==='efi')E.ach('efi1');}}
  }
  // energy
  for(const s of E.drivers())s.energy=Math.min(s.maxE,s.energy+1.6+E.facV('regen'));
  // series rounds due
  for(const id in G.series){const a=G.series[id].act;if(a&&!a.pending&&G.day>=a.next){a.pending=true;E.H.roundDue(id);}}
  // random events
  if(U.chance(0.018))E.randomEvent();
  if(G.day%D.DAYS_MONTH===0)E.monthly();
  if(G.day%D.DAYS_YEAR===0)E.yearly();
};
E.monthly = ()=>{
  const sal=U.sum(G.staff,s=>s.salary);const sp=U.sum(G.spons,s=>E.sponsorPay(s));const merch=Math.round(G.fans*E.facV('merch'));
  G.money+=sp+merch-sal;G.lastMonth={sal,sp,merch};
  E.log(`Month end: sponsors +${U.money(sp)}${merch?`, merch +${U.money(merch)}`:''}, salaries -${U.money(sal)}`);
  if(G.money<0)E.H.toast('⚠ In the red! Race, sign sponsors or do Odd Jobs.');
  E.refreshCandidates();E.checkSponsors();E.checkAch();G.wxRain=U.chance(0.2);
};
E.yearly = ()=>{
  const y=E.year()-1;const rank=E.fanRank();const bonus=rank*rank*40000;G.money+=bonus;
  const yr=G.year;G.year={wins:0,podiums:0,earn:0,titles:0};G.yearWins={};
  E.H.yearEnd({y,yr,bonus,rank});
  if(y>=D.YEARS&&!G.ended){G.ended=true;E.H.gameEnd(E.score());}
};
E.score = ()=>{
  const t=G.st.titles.reduce((s,id)=>s+[0,100,300,800,2000,5000][D.SER[id].tier],0);
  return Math.round(t+G.st.wins*20+G.st.podiums*5+G.fans/50+Math.max(0,G.money)/50000+G.ws*200);
};

// ---------- random events ----------
E.EVENTS = [
  {w:3,f(){const m=U.ri(5,20)*1000*(1+E.fanRank());G.money+=m;return `A fan sent a care package! +${U.money(m)}`;}},
  {w:3,f(){const s=U.pick(E.mechs());if(!s)return null;const r=U.ri(3,8)+G.ws*3;G.rp+=r;E.H.float('Idea!',null,'#ffe066');return `${s.name} had a brainstorm! +${r} RP`;}},
  {w:2,f(){const f=Math.round(30+G.fans*0.04);G.fans+=f;return `A racing magazine featured the team! +${f} fans`;}},
  {w:2,f(){const s=U.pick(E.mechs());if(!s)return null;G.lazyUntil=G.day+5;return `${s.name} is slacking off... work slows for a few days.`;}},
  {w:1,f(){E.giveSpark('b','');return `Found an old trophy in the parts bin. It sparkles!`;}},
  {w:2,f(){const s=U.pick(E.drivers());s.appeal+=2;return `${s.name} signed autographs for local kids. Appeal +2`;}},
  {w:2,f(){const s=U.pick(E.staff?G.staff:[]);if(!s)return null;s.tech+=2;return `${s.name} learned a new trick from a video. Tech +2`;}},
  {w:1,f(){if(E.fanRank()<2)return null;const m=50000*E.fanRank();G.money+=m;return `An investor was impressed! +${U.money(m)}`;}},
  {w:2,f(){const d=U.pick(E.drivers());d.energy=Math.min(d.maxE,d.energy+30);return `${d.name} had a great night's sleep. Energy +30`;}},
  {w:1,f(){G.wxRain=true;return `Weather service: rain likely at the next tarmac race.`;}},
  {w:1,f(){const m=U.ri(10,30)*1000;G.money+=m;return `The team bake sale was a hit! +${U.money(m)}`;}},
];
E.randomEvent = ()=>{const tot=U.sum(E.EVENTS,e=>e.w);let r=Math.random()*tot;for(const e of E.EVENTS){r-=e.w;if(r<=0){const t=e.f();if(t)E.say(t);return;}}};

// ---------- save ----------
E.serialize = ()=>JSON.stringify(G);
E.load = (str)=>{const o=typeof str==='string'?JSON.parse(str):str;if(!o||o.v!==1||!o.team)throw new Error('bad save');G=o;
  G.settings=Object.assign({speed:1,autoRetire:true,sound:true,mode:'standard'},G.settings||{});G.st.wc=G.st.wc||{};G.year=G.year||{wins:0,podiums:0,earn:0,titles:0};
  G.tech=G.tech||{carbbasic:1};G.ach=G.ach||{};G.st.tests=G.st.tests||0;G.st.streak=G.st.streak||0;G.st.cells=G.st.cells||0;
  for(const v of G.vehicles){if(!v.eng)T.initEng(v,null);if(!v.setup)v.setup=T.defaultSetup(v);}return G;};
