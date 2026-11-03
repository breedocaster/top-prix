// ===================== RACE SIM =====================
const Race = {cache:{}};
Race.LEN = {str:[2,4],crv:[2,3],hp:[1,1],chi:[1,2],jmp:[1,1],rgh:[2,3],hill:[2,3],lau:[1,1]};
Race.TAC = {safe:{pace:0.95,mis:0.6,dmg:0.7,n:'Safe'},normal:{pace:1,mis:1,dmg:1,n:'Normal'},push:{pace:1.055,mis:1.5,dmg:1.35,n:'Push'}};
Race.KINDS = {
  CR:['hatch','sedan','roadster','coupe','gt','formula','proto','kart'],
  CO:['pickup','rally','buggy','sprint','truck','rally'],
  BR:['commuter','scooter','naked','sport','cafe','super','gp'],
  BO:['trail','mx','enduro','flat','raid','smoto','mx'],
};
Race.KINDS.DR=['hatch','sport','coupe','naked','gt','super','proto','gp'];
Race.KINDS.HC=['hatch','naked','rally','sport','coupe','smoto','gt','super','proto','gp'];
Race.rivalMul = ()=>T.mode()==='easy'?0.94:1;
Race.track = (def,rain)=>{
  const key=def.id+(rain?'r':'')+(def._laps||'');if(Race.cache[key])return Race.cache[key];
  const rng=U.seeded(U.hash(def.id)),st=D.STYLES[def.style];const secs=[];
  const pickW=p=>{let tot=0;for(const k in p)tot+=p[k];let r=rng()*tot;for(const k in p){r-=p[k];if(r<=0)return k;}return Object.keys(p)[0];};
  for(let i=0;i<st.n;i++){
    let type=st.pat?st.pat[i%st.pat.length]:pickW(st.p);
    if(!st.pat&&i===0)type=st.p.str?'str':type;
    if(!st.pat&&i>0&&type===secs[i-1].type&&(type==='jmp'||type==='hp'||type==='chi'))type=st.p.crv?'crv':'str';
    const[a,b]=Race.LEN[type]||[1,2];secs.push({type,len:def.style==='drag'?(type==='lau'?1:2):a+Math.floor(rng()*(b-a+1))});
  }
  let at=0;secs.forEach(s=>{s.at=at;at+=s.len;});const lapLen=at;
  const ents=Object.entries(def.surf);const order=ents.map(e=>[e,rng()]).sort((a,b)=>a[1]-b[1]).map(x=>x[0]);
  let cum=0;const blocks=order.map(([k,w])=>{const s=cum;cum+=w;return[k,s,cum];});
  secs.forEach(s=>{const mid=(s.at+s.len/2)/lapLen*cum;let k=blocks[blocks.length-1][0];for(const b of blocks)if(mid>=b[1]&&mid<b[2]){k=b[0];break;}s.surf=(rain&&k==='tar')?'wet':k;});
  const laps=def._laps||def.laps;
  const tr={secs,lapLen,laps,total:lapLen*laps,p2p:!!st.p2p,oval:def.style==='oval',drag:def.style==='drag',hill:def.style==='hill'};
  Race.cache[key]=tr;return tr;
};
Race.mainSurf = (tr)=>{const m={};tr.secs.forEach(s=>m[s.surf]=(m[s.surf]||0)+s.len);return Object.entries(m).sort((a,b)=>b[1]-a[1])[0][0];};
Race.rivalTerr = def=>{const b=96+7*def.tier;const t={on:b,off:b,wet:b-6,ice:b-10};
  if(def.disc==='CR'||def.disc==='BR'||def.disc==='DR'){t.on+=28;t.wet+=10;}else if(def.disc==='CO'){t.off+=26;t.ice+=22;t.wet+=8;}else if(def.disc==='BO'){t.off+=28;t.ice+=10;}
  else if(def.disc==='HC'){t.on+=22;t.off+=12;t.wet+=8;t.ice+=10;}else{t.on+=12;t.off+=12;t.wet+=8;t.ice+=8;}
  return t;};
Race.mkRivals = (def,n)=>U.shuffle(D.RIVALS).slice(0,n).map((r,i)=>({team:r[0],col:r[1],drv:U.pick(D.FIRST)+' '+U.pick(D.LAST),f:1.12-0.28*i/Math.max(1,n-1)+U.rand(-0.03,0.03)}));

Race.create = (def,pl,opts={})=>{
  let rain=false;const fmt=opts.fmt||{id:'sprint',kind:'mass',laps:def.laps,mul:{prize:1,rp:1,fans:1,wear:1}};
  if(def.surf.tar&&!opts.test){if(G.wxRain){rain=true;G.wxRain=false;}else if(U.chance(0.08))rain=true;}
  const d2=Object.assign({},def,{_laps:fmt.laps!==def.laps?fmt.laps:null});const tr=Race.track(d2,rain);
  const n=opts.rivals?opts.rivals.length:[0,5,7,9,11,11][def.tier];
  const rivals=opts.rivals||Race.mkRivals(def,n);
  const kinds=(def.disc==='OP')?[...Race.KINDS.CR,...Race.KINDS.CO,...Race.KINDS.BR,...Race.KINDS.BO]:Race.KINDS[def.disc]||Race.KINDS.CR;
  const tierK=()=>kinds.slice(0,Math.min(kinds.length,2+def.tier*2));
  const tb=Race.rivalTerr(def);const rm=Race.rivalMul();const ents=[];
  rivals.forEach(r=>{const str=def.R*r.f*rm;const t={};for(const k of['on','off','wet','ice'])t[k]=tb[k]+U.rand(-6,8);
    if(!r.kind)r.kind=U.pick(tierK());
    ents.push({name:r.drv,team:r.team,col:r.col,kind:r.kind,S:str*U.rand(0.93,1.07),A:str*U.rand(0.93,1.07),H:str*U.rand(0.93,1.07),t,pm:1,mis:1,ref:r,
      dnfAt:U.chance(opts.test?0:0.03)?U.rand(0.2,0.9):null,rt:U.rand(0.04,0.2)});});
  const v=E.veh(pl.vid),s=E.staff(pl.sid),b=D.BODY[v.body];
  const cond=opts.cond||T.forecast(def);
  if(T.mode()==='easy'&&v.eng&&v.eng.fuel!=='none')T.crewTune(v,cond,0.99);
  const p=E.profile(v,s);const rsx=T.raceSecs(v,def,tr,cond);
  const P={isPlayer:true,name:s.name,team:G.team.name,col:G.team.color,kind:b.kind,...p,hp:v.hp,vid:v.id,sid:s.id,hair:s.hair,sk:rsx.secs,
    cond:v.eng?v.eng.cond:1,cyl:T.cyl(v),rt:U.clamp(0.2-(s.shift+s.analysis)/1200,0.02,0.2)};
  if(rsx.foul&&U.chance(0.3))P.fouled=true;if(rsx.seize)P.seizeRisk=true;
  let grid;
  if(opts.gridRivals){grid=opts.gridRivals.map(r=>ents.find(e=>e.ref===r)).filter(Boolean);grid.splice(Math.min(grid.length,opts.playerSlot||0),0,P);}
  else{grid=U.shuffle(ents);const pi=fmt.kind==='tt'?0:Math.floor(grid.length*U.rand(0.35,0.75));grid.splice(pi,0,P);}
  const tt=fmt.kind==='tt'||!!opts.test;const drag=tr.drag;
  grid.forEach((e,i)=>{Object.assign(e,{prog:tt||drag?0:-i*0.18,fin:false,dnf:false,finT:0,slow:0,boost:0,secIdx:-1,noise:1,v:0,lane:drag?(e.isPlayer?0:2):i%3,air:0,crash:0,splits:[]});if(e.dnfAt)e.dnfAt*=tr.total;});
  const T0=drag?9:U.clamp(tr.total*0.8,24,90);
  const rs={def,tr,ents:grid,player:P,t:0,K:tr.total/T0,T:T0,rain,done:false,tactic:pl.tactic||'normal',msgs:[],order:grid.slice(),cond,fmt,tt,drag,
    series:opts.series||null,round:opts.round,lastLeader:null,lastPos:grid.indexOf(P)+1,msgT:{},endT:null,fx:[],critWarned:false,finalLap:false,lapFactor:Math.pow(tr.laps,-0.35),
    gridSlot:grid.indexOf(P),tree:drag?1.8:0,test:!!opts.test,warn:{},telem:T.has('telem'),heat:opts.heat||null};
  if(v.eng&&D.FUELS[v.eng.fuelT||'pump'].cost&&!opts.test)rs.fuelCost=D.FUELS[v.eng.fuelT].cost*(fmt.mul.wear||1);
  if(drag){Race.msg(rs,'Staging… watch the tree!');
    if(U.chance({safe:0.005,normal:0.02,push:0.07}[rs.tactic]))P.redlight=true;}
  else if(tt)Race.msg(rs,opts.test?'Test session — out you go!':'Green light — on the clock!');
  else Race.msg(rs,U.pick(["Lights out — and they're away!","The flag drops! Here we go!","And they're off!"]));
  if(P.fouled)Race.msg(rs,'Fouled a plug on the grid — misfiring!');
  return rs;
};
Race.msg = (rs,t,key,gap)=>{if(key){if(rs.msgT[key]&&rs.t-rs.msgT[key]<(gap||1.5))return;rs.msgT[key]=rs.t;}rs.msgs.push({t:rs.t,text:t});if(rs.msgs.length>30)rs.msgs.shift();};
Race.secAt = (tr,prog)=>{const lp=((prog%tr.lapLen)+tr.lapLen)%tr.lapLen;const s=tr.secs;for(let i=s.length-1;i>=0;i--)if(lp>=s[i].at)return i;return 0;};
Race.pace = (e,sec,idx)=>{const w=D.SEC[sec.type].w;const tk=D.SURF[sec.surf].k;
  if(e.sk){const k=e.sk[idx];let p=((w[0]*e.S*k.s+w[1]*e.A*k.a)*k.ef+w[2]*e.H*k.h)*(U.clamp(e.t[tk]*k.t,5,220)/100)*e.pm;if(e.fouled)p*=1-0.55/Math.max(1,e.cyl);return p;}
  return(w[0]*e.S+w[1]*e.A+w[2]*e.H)*(U.clamp(e.t[tk],5,220)/100)*e.pm;};
Race.label = e=>e.isPlayer?'You':e.team;

Race.step = (rs,dt)=>{
  if(rs.done)return;rs.t+=dt;const tr=rs.tr,R=rs.def.R,tac=Race.TAC[rs.tactic];const P=rs.player;
  if(rs.drag&&!rs.greenSaid&&rs.t>=rs.tree){rs.greenSaid=true;if(P.redlight){P.dnf=true;Race.msg(rs,'🔴 RED LIGHT! Jumped the start!');}else Race.msg(rs,'🟢 GREEN!');}
  for(const e of rs.ents){
    if(e.fin||e.dnf)continue;
    if(rs.drag&&rs.t<rs.tree+e.rt)continue;
    const idx=Race.secAt(tr,Math.max(0,e.prog));const sec=tr.secs[idx];const prevIdx=e.secIdx;
    if(idx!==e.secIdx){
      if(e.isPlayer&&e.sk&&prevIdx>=0){const pk=e.sk[prevIdx];
        if(pk.starve&&tr.secs[prevIdx].type==='jmp'&&!rs.warn.starve){rs.warn.starve=1;e.slow=0.6;e.cond-=0.01;Race.msg(rs,'Fuel starvation on landing! (float level too low)');}}
      e.secIdx=idx;e.noise=U.rand(0.965,1.035);
      if(e.isPlayer&&sec.type==='jmp'&&U.chance(0.3))Race.msg(rs,U.pick(['Huge air!','Sends it over the jump!','Look at that hang time!']),'jmp',4);
      if(e.isPlayer&&e.sk&&e.sk[idx].flood&&!rs.warn.flood){rs.warn.flood=1;e.slow=0.35;Race.msg(rs,'Floods over the whoops — fuel level too high!');}
      if(rs.tt&&!e.isPlayer)null;
    }
    let pace=Race.pace(e,sec,idx)*e.noise;
    if(e.isPlayer)pace*=tac.pace;
    if(e.boost>0){pace*=1.2;e.boost-=dt;}
    if(e.slow>0){pace*=0.35;e.slow-=dt;}
    const v=Math.max(0.05,pace/R*rs.K);e.v=v;const dp=v*dt;e.prog+=dp;
    if(sec.type==='jmp'){e.air=((e.prog%tr.lapLen+tr.lapLen)%tr.lapLen-sec.at)/sec.len;}else e.air=0;
    if(e.isPlayer){const ln=Math.floor(Math.max(0,e.prog)/tr.lapLen);if(ln>(e.lapN||0)){e.lapT=e.lapT||[];e.lapT.push(rs.t-(e.lastLapAt||0));e.lastLapAt=rs.t;e.lapN=ln;}}
    // splits (time trials)
    if(rs.tt){const k=Math.floor(e.prog/tr.total*3);if(k>=1&&k<=2&&!e.splits[k-1]){e.splits[k-1]=rs.t;
      if(e.isPlayer&&!rs.test){const others=rs.ents.filter(x=>!x.isPlayer&&x.splits[k-1]);if(others.length){const best=Math.min(...others.map(x=>x.splits[k-1]));const d=rs.t-best;Race.msg(rs,`Split ${k}: ${d<=0?'🟢 '+d.toFixed(2):'🔴 +'+d.toFixed(2)}s`);}else Race.msg(rs,`Split ${k}: 🟢 fastest so far!`);}}}
    // mistakes
    if(e.slow<=0&&e.boost<=0&&e.prog>0){
      const tk=D.SURF[sec.surf].k;const hr=e.H*(U.clamp(e.t[tk],5,220)/100)/R;
      let pm=D.SEC[sec.type].risk*D.SURF[sec.surf].risk*U.clamp(1.7-hr*0.7,0.35,1.8)*e.mis*(e.isPlayer?tac.mis:1);
      if(e.isPlayer&&T.has('tcmap')&&E.veh(e.vid)&&E.veh(e.vid).eng.fuel==='efi'&&tk!=='on')pm*=0.75;
      if(Math.random()<pm*dt)Race.mistake(rs,e,sec);
    }
    // damage & engine
    if(e.isPlayer){
      const d=R*0.012*D.SEC[sec.type].dmg*D.SURF[sec.surf].dmg*tac.dmg*e.wear*rs.lapFactor;e.hp-=d*dp/e.dur;
      if(!rs.critWarned&&e.hp<0.3){rs.critWarned=true;Race.msg(rs,'⚠ Durability critical!');}
      if(e.sk){const k=e.sk[idx];let kd=k.kd,lh=k.lh;if(rs.tactic==='safe')kd=Math.max(0,kd-1.5);
        if(kd>0||lh>0){const rate=(0.004*Math.pow(kd,1.4)+0.006*Math.pow(lh,1.2))*(T.has('forged')?0.5:1)*(rs.tactic==='push'?1.3:rs.tactic==='safe'?0.6:1);e.cond-=rate*dt;
          if(kd>0.3&&!rs.warn.knock){rs.warn.knock=1;Race.msg(rs,T.mode()==='sim'?'🔔 Ping… ping…':'🔔 Pinging under load! (try Safe)');}
          if(lh>0.5&&!rs.warn.lean){rs.warn.lean=1;Race.msg(rs,T.mode()==='sim'?'🌡 Something smells hot…':'🌡 Running lean and hot!');}
          if(e.cond<0.35&&!rs.warn.hot){rs.warn.hot=1;Race.msg(rs,'⚠ Engine temps critical!');}}
        if(e.seizeRisk&&sec.type==='str'&&Math.random()<0.25*dt){e.dnf=true;e.seized=true;e.cond=0;Race.msg(rs,'🧊 SEIZED! Lean two-stroke locks up!');E.H.sfx('crash');}
        if(!e.dnf&&e.cond<=0.1&&G.settings.autoRetire&&T.mode()!=='sim'){e.dnf=true;e.retired=true;Race.msg(rs,'Crew calls it in — saving the engine.');}
        else if(!e.dnf&&e.cond<=0){e.cond=0;e.dnf=true;e.holed=true;Race.msg(rs,'💥 BANG! Holed a piston!');E.H.sfx('crash');}}
      if(!e.dnf&&e.hp<=0.08&&G.settings.autoRetire){e.dnf=true;e.retired=true;Race.msg(rs,'Your crew calls it in — retired to save the machine.');}
      else if(!e.dnf&&e.hp<=0){e.hp=0;e.dnf=true;e.destroyed=true;Race.msg(rs,'💥 The machine is wrecked!');E.H.sfx('crash');}
    }else if(e.dnfAt&&e.prog>=e.dnfAt){e.dnf=true;if(!rs.tt)Race.msg(rs,`${e.team} pulls off — mechanical failure!`);}
    if(!e.dnf&&e.prog>=tr.total){e.fin=true;e.finT=rs.t-(e.prog-tr.total)/v;
      if(e.isPlayer){const pos=rs.ents.filter(x=>x.fin&&x.finT<=e.finT).length;
        if(rs.drag){rs.et=Race.et(rs,e);Race.msg(rs,`🏁 ${rs.et.et.toFixed(3)}s @ ${rs.et.mph} mph`);}
        else if(rs.test)Race.msg(rs,'🏁 Session complete.');
        else Race.msg(rs,pos===1?'🏁 YOU WIN!!':`🏁 You cross the line ${U.ord(pos)}!`);}
      else if(rs.ents.filter(x=>x.fin).length===1&&!rs.tt)Race.msg(rs,`🏁 ${e.team} takes the checkered flag!`);}
  }
  rs.order=rs.ents.slice().sort((a,b)=>{if(a.dnf!==b.dnf)return a.dnf?1:-1;if(a.fin&&b.fin)return a.finT-b.finT;if(a.fin!==b.fin)return a.fin?-1:1;return b.prog-a.prog;});
  const L=rs.order[0];
  if(!rs.tt&&!rs.drag&&L!==rs.lastLeader&&rs.t>1.5){Race.msg(rs,L.isPlayer?'You take the lead!':`${L.team} takes the lead!`,'lead',2);}
  rs.lastLeader=L;
  const pos=rs.order.indexOf(P)+1;
  if(!rs.tt&&!rs.drag&&!P.fin&&!P.dnf&&rs.t>1.5&&pos!==rs.lastPos){
    if(pos<rs.lastPos)Race.msg(rs,`You pass ${Race.label(rs.order[pos])}! Up to P${pos}`,'pos',1.2);
    else Race.msg(rs,`${Race.label(rs.order[pos-2])} gets by... P${pos}`,'pos',1.2);
    rs.lastPos=pos;}
  if(!rs.finalLap&&tr.laps>1&&L.prog>=tr.lapLen*(tr.laps-1)&&!tr.p2p){rs.finalLap=true;Race.msg(rs,'🔔 Final lap!');}
  if(!rs.finalLap&&tr.laps>1&&tr.p2p&&P.prog>=tr.lapLen*(tr.laps-1)){rs.finalLap=true;Race.msg(rs,'Final stage!');}
  if((P.fin||P.dnf)&&rs.endT==null)rs.endT=rs.t;
  if(!rs.finishing&&rs.endT!=null&&rs.t-rs.endT>1.6)Race.finishAll(rs);
};
Race.et = (rs,e)=>{const ref=[0,14.2,12.0,10.2,8.4,7.0][rs.def.tier]||10;const mph0=[0,96,116,138,165,190][rs.def.tier]||120;
  const tb=Race.rivalTerr(rs.def);const tref=rs.T/(tb.on/100)/Race.rivalMul();const el=e.finT-rs.tree-e.rt;
  return {et:+(ref*el/tref+e.rt*0+0).toFixed(3),rt:+e.rt.toFixed(3),mph:Math.round(mph0*Math.pow(tref/el,0.8))};};
Race.mistake = (rs,e,sec)=>{
  const big=(sec.type==='jmp'||sec.type==='rgh')&&Math.random()<0.18*(e.isPlayer?Race.TAC[rs.tactic].mis:1);
  e.slow=big?U.rand(1.8,2.6):U.rand(0.7,1.4);e.crash=big?1.2:0.6;
  const sn=D.SURF[sec.surf].n.toLowerCase();
  if(sec.type==='lau'){if(e.isPlayer)Race.msg(rs,U.pick(['Big wheelspin off the line!','Wheelie on launch — had to roll out of it!','Bogged the launch!']));e.slow=U.rand(0.3,0.6);return;}
  if(e.isPlayer){e.hp-=big?0.12:0.03;
    Race.msg(rs,big?U.pick(['Hard landing! That hurt!','Big crash — but back on it!','Cartwheel! Somehow still going!']):U.pick([`Slides wide on the ${sn}!`,`Locks up into the ${D.SEC[sec.type].n.toLowerCase()}!`,`Little moment there on the ${sn}`,'Fumbles a shift!']),'pm',1);
    E.H.sfx('bump');}
  else{if(big&&Math.random()<0.12){e.dnf=true;if(!rs.tt)Race.msg(rs,`${e.team} crashes out!`);return;}
    const idx=rs.order.indexOf(e);if(idx<3&&!rs.tt)Race.msg(rs,`${e.team} ${U.pick(['spins','runs wide','gets crossed up','overshoots'])} on the ${sn}!`,'rm',2);}
};
Race.finishAll = rs=>{rs.finishing=true;let guard=0;while(rs.ents.some(e=>!e.fin&&!e.dnf)&&guard++<6000)Race.stepQuiet(rs,0.1);rs.done=true;};
Race.stepQuiet = (rs,dt)=>{const n=rs.msgs.length;Race.step(rs,dt);rs.msgs.length=Math.min(rs.msgs.length,n+3);};
Race.runInstant = rs=>{rs.finishing=true;let g=0;while(rs.ents.some(e=>!e.fin&&!e.dnf)&&g++<20000)Race.step(rs,0.1);rs.done=true;return rs;};
Race.useSpark = (rs,t)=>{if(rs.player.fin||rs.player.dnf||rs.player.boost>0)return false;if(!E.useSpark(t))return false;
  rs.player.boost={b:5,s:8,g:12}[t];rs.player.slow=0;Race.msg(rs,'✨ Spark! Pushing to the limit!');E.H.sfx('spark');return true;};
Race.retire = rs=>{const P=rs.player;if(P.fin||P.dnf)return;P.dnf=true;P.retired=true;Race.msg(rs,'You retire from the race.');};
// quick non-visual time for a rival run (time trial / drag ladders)
Race.quickTime = (def,rival,fmt)=>{const tr=Race.track(Object.assign({},def,{_laps:fmt&&fmt.laps!==def.laps?fmt.laps:null}),false);const tb=Race.rivalTerr(def);const str=def.R*rival.f*Race.rivalMul();
  let t=0;for(const s of tr.secs){const w=D.SEC[s.type].w;const tk=D.SURF[s.surf].k;const p=str*U.rand(0.93,1.07)*(tb[tk]+U.rand(-6,8))/100*(w[0]+w[1]+w[2]);t+=s.len/(p/def.R);}
  t*=tr.laps;if(U.chance(0.12))t*=U.rand(1.03,1.12);const T0=tr.drag?9:U.clamp(tr.total*0.8,24,90);return t*T0/tr.total;};
