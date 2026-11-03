// ===================== TUNING BENCH GRAPHICS =====================
const Bench = {s:{thr:0.15,sweep:false,dir:1,snapT:0,t:0,drops:[],air:[],dyno:null,lastJet:{}}};
Bench.lamAt = (ev,thr)=>{const pts=[[0.04,ev.lam.idle],[0.18,ev.lam.low],[0.5,ev.lam.mid],[0.9,ev.lam.wot]];
  if(thr<=pts[0][0])return pts[0][1];for(let i=1;i<pts.length;i++)if(thr<=pts[i][0]){const a=pts[i-1],b=pts[i];return a[1]+(b[1]-a[1])*(thr-a[0])/(b[0]-a[0]);}return pts[3][1];};
Bench.tgtAt = thr=>Bench.lamAt({lam:D.LAM},thr);
Bench.tick = dt=>{const s=Bench.s;s.t+=dt;if(s.sweep){s.thr+=s.dir*dt*0.35;if(s.thr>=1){s.thr=1;s.dir=-1;}if(s.thr<=0.02){s.thr=0.02;s.dir=1;}}if(s.snapT>0)s.snapT-=dt;};
const BP=(c,x,y,w,h,col)=>GX.P(c,x,y,w,h,col);
Bench.txt = (c,t,x,y,col='#cfe0ff',al='left',sz=5)=>{c.font=sz+'px '+GX.FONT;c.textAlign=al;c.textBaseline='top';c.fillStyle='#000';c.fillText(t,x+0.5,y+0.5);c.fillStyle=col;c.fillText(t,x,y);};
Bench.fuelCol = lam=>lam<0.8?'#c8641e':lam<0.85?'#e88a2a':lam<0.92?'#f2b33d':lam<0.98?'#f6dd7a':'#cfe9f2';

// ---------- carb cutaway ----------
Bench.drawCarb = (c,v,ev,dt)=>{
  const s=Bench.s,t=s.t;const C=D.CARBS[v.eng.carb];const j=v.eng.jets;const thr=s.thr;const lam=Bench.lamAt(ev,thr);const snap=s.snapT>0;
  BP(c,0,0,160,100,'#1a2140');for(let y=0;y<100;y+=10)BP(c,0,y,160,1,'#1f2850');
  if(C.kind==='down')return Bench.drawDown(c,v,ev,C,j,thr,lam,snap,t,dt);
  const AL='#9aa3ad',ALd='#6f7882',ALl='#c3cbd3';
  // bore & body
  BP(c,4,36,12,24,ALd);BP(c,6,38,10,20,'#0d1020');// bell
  BP(c,14,34,128,4,AL);BP(c,14,58,128,4,AL);BP(c,14,38,128,20,'#0d1020');BP(c,142,36,14,24,'#3d3d3d');BP(c,142,38,14,20,'#120d0a');
  // airflow
  if(U.chance(dt*(8+thr*60)))s.air.push({x:6,y:39+Math.random()*17,t:0});
  s.air=s.air.filter(a=>(a.x+=dt*(30+thr*160))<156);for(const a of s.air)BP(c,a.x,a.y,3,1,'#7fd3ff');
  // mixture tint downstream
  c.globalAlpha=0.25+0.4*thr;BP(c,96,38,46,20,Bench.fuelCol(lam));BP(c,142,38,14,20,Bench.fuelCol(lam));c.globalAlpha=1;
  // slide chamber
  const side=C.kind==='side';
  if(!side){BP(c,62,6,32,30,AL);BP(c,64,8,28,28,ALl);
    if(C.kind==='cv'){BP(c,58,4,40,6,ALd);BP(c,60,9,36,1,'#222');Bench.txt(c,'diaphragm',30,24);}
    const sw=C.kind==='flat'?8:22;const sx=78-sw/2;const sb=56-thr*17;
    BP(c,sx,sb-24,sw,24,C.kind==='flat'?'#d8dde2':'#b7bfc7');BP(c,sx,sb-1,sw,1,'#555');if(C.kind!=='flat')BP(c,sx+sw-3,sb-6,3,6,'#8d959d');
    // needle
    for(let k=0;k<22;k++){const w=k<8?2:1;BP(c,78-(w>1?1:0),sb+k-2,w,1,'#e6e9ec');}
    BP(c,78,sb,1,1,'#ffd84a');
  }else{ // sidedraft butterfly
    const ang=thr*Math.PI*0.45;for(let k=-9;k<=9;k++){const x=118+Math.sin(ang)*k*0.9,y=48+Math.cos(ang)*k;BP(c,x,y,2,1,'#d8dde2');}
    BP(c,117,47,3,3,'#555');Bench.txt(c,'butterfly',106,24);
    // air corrector & emulsion well
    BP(c,74,14,8,20,AL);BP(c,76,12,4,3,'#c8a24a');Bench.txt(c,`air corr ${j.airc}`,84,12,'#ffd84a');BP(c,76,16,4,18,'#0d1020');}
  // needle jet / emulsion tube
  BP(c,76,58,5,22,ALl);BP(c,77,58,3,22,'#2a1a08');
  // float bowl
  const bx=48,by=68,bw=60,bh=28;BP(c,bx,by,bw,bh,AL);BP(c,bx+2,by+2,bw-4,bh-4,'#0d1020');
  const lvl=by+18-(j.float||0)*1.4+Math.sin(t*3)*0.4*(1+thr);c.save();c.beginPath();c.rect(bx+2,by+2,bw-4,bh-4);c.clip();
  BP(c,bx+2,lvl,bw-4,bh,'#e0a12b');BP(c,bx+2,lvl,bw-4,1,'#ffd27a');c.restore();
  // floats & arm
  const fy=lvl-5;BP(c,bx+5,fy,14,5,'#d7c78a');BP(c,bx+bw-19,fy,14,5,'#d7c78a');BP(c,bx+19,fy+2,bw-38,1,'#888');BP(c,bx+bw-8,by+2,3,Math.max(1,fy-by-1),'#777');
  Bench.txt(c,`fuel level ${(j.float||0)>0?'+':''}${j.float||0}mm`,bx,by+bh+1,'#ffd84a');
  // inlet & needle valve
  BP(c,bx+bw,by+4,14,3,'#5b3a1a');const open=lvl>by+18-(j.float||0)*1.4+0.2||thr>0.4;if(open&&U.chance(dt*20))s.drops.push({x:bx+bw-6,y:by+5,vy:12,vx:0,t:0,c:'#ffcf5c'});
  // main jet (orifice width by size)
  const mainP=C.p.find(p=>p.k==='main');const mw=U.clamp(Math.round(2+(j.main/mainP.stock-1)*12),1,6);
  BP(c,74,80,9,5,'#c8a24a');BP(c,78.5-mw/2,80,mw,5,'#1a1206');Bench.txt(c,`main #${j.main}`,86,80,'#ffd84a');
  // pilot jet & screw
  if(j.pilot!=null){BP(c,60,78,4,8,'#c8a24a');BP(c,61,78,2,8,'#1a1206');BP(c,61,62,2,16,'#3a2a10');BP(c,61,60,26,2,'#3a2a10');Bench.txt(c,`pilot #${j.pilot}`,30,86,'#ffd84a');}
  const sp=C.p.find(p=>p.k==='screw');if(sp){const ang=(j.screw||0)*Math.PI*2;BP(c,26,62,10,6,ALd);const cx=31,cy=65;for(let k=-3;k<=3;k++)BP(c,cx+Math.cos(ang)*k,cy+Math.sin(ang)*k,1,1,'#ffd84a');
    Bench.txt(c,`${sp.n.split(' ')[0]==='Air'?'air':'fuel'} scr ${j.screw}t`,8,70,'#ffd84a');}
  // accel pump
  if(j.pump!=null){BP(c,bx+bw-10,by+bh-8,8,6,'#7a6a4a');BP(c,70,37,2,2,'#ffd84a');Bench.txt(c,`pump ${j.pump}`,112,86,'#ffd84a');
    if(snap)for(let k=0;k<4;k++)s.drops.push({x:71,y:39,vx:U.rand(10,40),vy:U.rand(5,20),t:0,c:'#ffb000'});}
  // fuel flow up & spray
  const R=T.carbRich(v);const flow=thr<0.2?0.6:R.mid;const rate=(thr>0.08?thr:0.15)*30*flow/(lam/0.9);
  if(U.chance(dt*rate))s.drops.push({x:77.5,y:80,vx:0,vy:-40-thr*30,t:0,c:'#ffb000',rise:true});
  if(thr<0.3&&j.pilot!=null&&U.chance(dt*12))s.drops.push({x:86,y:57,vx:30,vy:-6,t:0,c:'#ffd27a'});
  s.drops=s.drops.filter(d=>(d.t+=dt)<1.2);
  for(const d of s.drops){if(d.rise&&d.y<56){d.rise=false;d.vx=40+thr*120;d.vy=U.rand(-15,15);}d.x+=d.vx*dt;d.y+=d.vy*dt;if(d.x<156)BP(c,d.x,d.y,1,1,d.c);}
  // needle inset
  if(!side&&C.p.find(p=>p.k==='clip')){BP(c,120,4,36,30,'#0d1020');BP(c,120,4,36,1,'#4b5ea0');Bench.txt(c,'jet needle',122,5);
    for(let g=0;g<5;g++){BP(c,128,10+g*3,8,1,g+1===j.clip?'#ffd84a':'#7d8590');}BP(c,131,9,2,22,'#e6e9ec');BP(c,131,31,1,2,'#e6e9ec');
    BP(c,126,9+(j.clip-1)*3,12,3,'#ffd84a');Bench.txt(c,`clip ${j.clip}`,140,14,'#ffd84a');Bench.txt(c,'1=lean',138,22,'#8fa3d8');Bench.txt(c,'5=rich',138,27,'#8fa3d8');}
  Bench.gauge(c,ev,thr,lam);
};
Bench.drawDown = (c,v,ev,C,j,thr,lam,snap,t,dt)=>{
  const s=Bench.s;const AL='#9aa3ad',ALd='#6f7882';
  BP(c,26,4,86,6,ALd);BP(c,30,10,78,72,AL);
  const barrels=C.barrels===4?[[36,14],[56,14],[74,14],[94,14]]:[[42,20],[78,20]];const bwid=C.barrels===4?14:20;
  const vac=18*Math.pow(1-thr,1.5);const pvOpen=j.pv!=null&&vac<j.pv;
  for(const[bx,bw]of barrels.map(b=>[b[0],bwid])){BP(c,bx,10,bw,74,'#0d1020');
    BP(c,bx+bw/2-3,30,6,3,'#c3cbd3');BP(c,bx+bw/2-1,33,2,2,'#c3cbd3');
    const sec=C.barrels===4&&bx>=74;const op=sec?Math.max(0,(thr-0.6)/0.4):thr;const ang=op*Math.PI*0.45;
    for(let k=-bw/2+1;k<bw/2;k++){BP(c,bx+bw/2+Math.cos(ang)*k*0.95,66+Math.sin(ang)*k,1,1,'#d8dde2');}
    if(op>0.12&&U.chance(dt*op*40))s.drops.push({x:bx+bw/2,y:34,vx:U.rand(-6,6),vy:30+op*60,t:0,c:'#ffb000'});
    if(U.chance(dt*(6+op*40)))s.air.push({x:bx+2+Math.random()*(bw-4),y:10,t:0,down:true});}
  s.air=s.air.filter(a=>(a.y+=dt*(30+thr*140))<84);for(const a of s.air)BP(c,a.x,a.y,1,3,'#7fd3ff');
  c.globalAlpha=0.3+0.4*thr;BP(c,30,74,78,10,Bench.fuelCol(lam));c.globalAlpha=1;
  // bowl
  const bx=112,by=18,bw=34,bh=50;BP(c,bx,by,bw,bh,AL);BP(c,bx+2,by+2,bw-4,bh-4,'#0d1020');
  const lvl=by+30-(j.float||0)*1.6+Math.sin(t*3)*0.4;c.save();c.beginPath();c.rect(bx+2,by+2,bw-4,bh-4);c.clip();BP(c,bx+2,lvl,bw-4,bh,'#e0a12b');BP(c,bx+2,lvl,bw-4,1,'#ffd27a');c.restore();
  BP(c,bx+6,lvl-5,22,5,'#d7c78a');BP(c,bx+bw-6,by-4,3,6,'#777');BP(c,bx+bw,by,10,3,'#5b3a1a');Bench.txt(c,`level ${(j.float||0)>0?'+':''}${j.float||0}mm`,bx,by+bh+1,'#ffd84a');
  // metering block & jets
  BP(c,106,34,6,40,'#8d959d');const mainP=C.p[0];const mw=U.clamp(Math.round(2+(j.main/mainP.stock-1)*12),1,5);BP(c,107,64,4,4,'#c8a24a');BP(c,109-mw/2,64,mw,4,'#1a1206');
  Bench.txt(c,`pri #${j.main}`,112,72,'#ffd84a');if(j.sec!=null)Bench.txt(c,`sec #${j.sec}`,112,78,'#ffd84a');
  if(j.pv!=null){BP(c,107,48,4,6,pvOpen?'#8ef58e':'#b05050');Bench.txt(c,`PV ${j.pv}" ${pvOpen?'OPEN':'shut'}`,112,84,pvOpen?'#8ef58e':'#ff9a9a');}
  // pump
  if(j.pump!=null){BP(c,40,86,30,6,'#7a6a4a');BP(c,44,84,22,2,'#5a4a2a');Bench.txt(c,`squirter #${j.pump}`,4,86,'#ffd84a');
    if(snap)for(const[bx] of barrels.slice(0,2))for(let k=0;k<4;k++)s.drops.push({x:bx+bwid/2,y:14,vx:U.rand(-8,8),vy:U.rand(40,90),t:0,c:'#ffb000'});}
  // idle screws
  const ang=(j.screw||0)*Math.PI*2;for(const sx of[34,100]){for(let k=-2;k<=2;k++)BP(c,sx+Math.cos(ang)*k,78+Math.sin(ang)*k,1,1,'#ffd84a');}Bench.txt(c,`idle ${j.screw}t`,4,76,'#ffd84a');
  s.drops=s.drops.filter(d=>(d.t+=dt)<1);for(const d of s.drops){d.x+=d.vx*dt;d.y+=d.vy*dt;BP(c,d.x,d.y,1,1,d.c);}
  Bench.txt(c,`vacuum ${vac.toFixed(1)} inHg`,4,4,'#8fd8ff');
  Bench.gauge(c,ev,thr,lam);
};
// wideband / plug gauge
Bench.gauge = (c,ev,thr,lam)=>{
  const wb=T.has('wideband');BP(c,2,2,40,14,'#050805');BP(c,3,3,38,12,'#0d1a0d');
  if(wb){const tgt=Bench.tgtAt(thr);const col=Math.abs(lam-tgt)<0.02?'#7dff7d':lam<tgt?'#ffb347':'#ff6060';Bench.txt(c,(lam*14.7).toFixed(1),22,4,col,'center',8);}
  else{const pl=T.plug(lam);BP(c,6,5,6,8,'#eee');BP(c,8,12,2,2,pl[1]);Bench.txt(c,'plug',14,6,'#8fa3d8');}
  Bench.txt(c,`TPS ${Math.round(thr*100)}%`,3,17,'#cfe0ff');
};
// AFR vs throttle chart
Bench.drawChart = (c,ev)=>{
  BP(c,0,0,160,50,'#0d1330');for(let i=0;i<=4;i++)BP(c,10+i*35,4,1,40,'#1d2650');
  const y=l=>44-(U.clamp(l*14.7,10,16)-10)/6*40;
  c.globalAlpha=0.25;for(let x=10;x<150;x++){const th=(x-10)/140;const tg=Bench.tgtAt(th);const y1=y(tg-0.02),y2=y(tg+0.02);BP(c,x,y2,1,Math.max(1,y1-y2),'#7dff7d');}c.globalAlpha=1;
  if(T.has('wideband')){let px=null;for(let x=10;x<150;x++){const th=(x-10)/140;const yy=y(Bench.lamAt(ev,th));BP(c,x,yy,1,1,'#ffd84a');}}
  else Bench.txt(c,'Wideband O2 needed for AFR trace — read the plug & symptoms below',8,20,'#8fa3d8');
  const mx=10+Bench.s.thr*140;BP(c,mx,4,1,40,'#fff');
  Bench.txt(c,'16',1,3);Bench.txt(c,'13',1,23);Bench.txt(c,'10',1,41);Bench.txt(c,'0%',10,45);Bench.txt(c,'¼',45,45);Bench.txt(c,'½',80,45);Bench.txt(c,'¾',115,45);Bench.txt(c,'WOT',140,45);
};
// ---------- sync bench ----------
Bench.drawSync = (c,v,dt)=>{
  const t=Bench.s.t;const n=v.eng.sync.length;const bi=T.syncBase(n);const gauge=T.has('syncgauge');
  BP(c,0,0,160,70,'#1a2140');const imb=(()=>{const o=v.eng.sync.filter((x,i)=>i!==bi);return o.length?U.sum(o,x=>Math.abs(x))/o.length:0;})();
  if(gauge){const w=Math.min(26,140/n);for(let i=0;i<n;i++){const x=14+i*(140/n)+(140/n-w)/2;BP(c,x,6,w,52,'#0d1020');BP(c,x,6,w,1,'#7d8590');
      for(let m=0;m<=10;m++)BP(c,x,8+m*5,3,1,'#4b5ea0');
      const off=v.eng.sync[i];const h=26+off*4+Math.sin(t*(18+i*1.3))*1.3;BP(c,x+w/2-2,58-h,4,h,'#c0392b');BP(c,x+w/2-2,58-h,4,2,'#ff8080');
      Bench.txt(c,i===bi?'BASE':`#${i+1}`,x+w/2,60,i===bi?'#ffd84a':'#cfe0ff','center');}
    BP(c,10,32,144,1,'#8ef58e');}
  else{const rpm=1200+Math.sin(t*(4+imb*3))*imb*90+Math.sin(t*23)*imb*40;Bench.txt(c,'No sync gauges — listening by ear…',80,12,'#cfe0ff','center',6);
    Bench.txt(c,`Idle ${Math.round(rpm)} rpm`,80,28,imb<0.6?'#8ef58e':imb<1.5?'#ffd84a':'#ff7070','center',8);
    Bench.txt(c,imb<0.6?'Smooth & even':imb<1.5?'A little lumpy':'Lumpy, hunting idle',80,44,'#cfe0ff','center',6);}
};
// ---------- dyno ----------
Bench.drawDyno = (c,v,dt)=>{
  const t=Bench.s.t;const d=Bench.s.dyno;const b=D.BODY[v.body];
  BP(c,0,0,160,90,'#1b2036');BP(c,0,62,160,28,'#2a2f45');for(let x=0;x<160;x+=16)BP(c,x,62,1,28,'#232838');
  // roller
  const spin=d&&d.running?t*30:0;BP(c,36,64,40,8,'#555');for(let k=0;k<4;k++)BP(c,36+((k*10+spin)%40),64,2,8,'#888');
  const w=GX.vehW(b.kind);GX.drawVeh(c,b.kind,56-w/2,64,G.team.color,'#ffd84a',d&&d.running?Math.floor(t*20)%2:0);
  BP(c,4,30,8,32,'#3d4766');BP(c,2,28,12,3,'#4f5b80');// fan
  if(d&&d.running){for(let k=0;k<5;k++)BP(c,14+((t*80+k*13)%40),36+k*5,6,1,'#7fd3ff');if(U.chance(0.6))Bench.s.drops.push({x:56-w/2-2,y:60,vx:-20,vy:-6,t:0,c:'#666'});}
  // rpm gauge
  const rpmMax=D.RPM_B[b.cls][7];const rpm=d?d.rpm:0;const ang=Math.PI*0.8+Math.PI*1.4*(rpm/rpmMax);
  BP(c,92,4,64,56,'#0d1020');c.strokeStyle='#4b5ea0';c.lineWidth=1;c.beginPath();c.arc(112,30,16,Math.PI*0.8,Math.PI*2.2);c.stroke();
  c.strokeStyle='#ff6060';c.beginPath();c.moveTo(112,30);c.lineTo(112+Math.cos(ang)*14,30+Math.sin(ang)*14);c.stroke();
  Bench.txt(c,`${Math.round(rpm)} rpm`,112,48,'#cfe0ff','center');
  if(d&&d.cur){const l=d.cur.lam;Bench.txt(c,T.has('wideband')?(l*14.7).toFixed(1):'--',144,8,Math.abs(l-d.cur.tgt)<0.02?'#7dff7d':l<d.cur.tgt?'#ffb347':'#ff6060','center',8);Bench.txt(c,'AFR',144,18,'#8fa3d8','center');
    if(d.cur.kd>0.3)Bench.txt(c,'KNOCK',144,30,Math.floor(t*6)%2?'#ff4040':'#ffd84a','center',6);
    Bench.txt(c,`${Math.round(d.cur.hp)} hp`,144,40,'#ffd84a','center',6);}
  // power trace
  if(d&&d.trace.length){BP(c,4,4,84,24,'#0d1020');const mx=Math.max(...d.trace.map(p=>p.hp),1);
    d.trace.forEach((p,i)=>{BP(c,6+p.r*80,26-p.hp/mx*20,1,1,'#ffd84a');BP(c,6+p.r*80,26-U.clamp((p.lam*14.7-10)/6,0,1)*20,1,1,'#7fd3ff');});
    Bench.txt(c,'power',6,5,'#ffd84a');Bench.txt(c,'afr',30,5,'#7fd3ff');}
  Bench.s.drops=Bench.s.drops.filter(p=>(p.t+=dt)<0.8);for(const p of Bench.s.drops){p.x+=p.vx*dt;p.y+=p.vy*dt;c.globalAlpha=1-p.t;BP(c,p.x,p.y,3,3,p.c);c.globalAlpha=1;}
};
Bench.dynoStep = (v,dt)=>{const d=Bench.s.dyno;if(!d||!d.running)return;d.tt+=dt;const b=D.BODY[v.body];const bins=D.RPM_B[b.cls];
  const f=U.clamp(d.tt/4,0,1);d.rpm=bins[1]+(bins[7]-bins[1])*f;const ic=Math.min(7,Math.max(0,Math.round(f*6)+1));
  const ev=d.ev;const lamC=ev.cells?ev.cells[5][ic]:ev.lam.wot;const tgt=v.eng.fuel==='efi'?v.eng.efi.afr[5][ic]/14.7:D.LAM.wot;
  const st=E.vs(v);const hp=(st.spd*0.6+st.acc*0.4)*0.45*Math.exp(-Math.pow((ic-5)/3,2))*0.6+(st.spd*0.6+st.acc*0.4)*0.45*0.4*(ic/7);const pf=T.pf(lamC,'wot');
  d.cur={lam:lamC*(1+U.rand(-0.008,0.008)),tgt,kd:ev.kd.wot,hp:hp*pf*ev.tf.wot,ic};d.trace.push({r:f,hp:d.cur.hp,lam:d.cur.lam});
  if(f>=1){d.running=false;d.done=true;}};
