// ===================== GRAPHICS (procedural pixel art) =====================
const GX = {FONT:'"DotGothic16", monospace'};
GX.P = (c,x,y,w,h,col)=>{c.fillStyle=col;c.fillRect(Math.round(x),Math.round(y),w,h);};
GX.shade = (hex,a)=>{let h=hex.replace('#','');if(h.length===3)h=h.split('').map(x=>x+x).join('');
  let r=parseInt(h.slice(0,2),16),g=parseInt(h.slice(2,4),16),b=parseInt(h.slice(4,6),16);
  const t=a<0?0:255,p=Math.abs(a);r=Math.round(r+(t-r)*p);g=Math.round(g+(t-g)*p);b=Math.round(b+(t-b)*p);
  return '#'+[r,g,b].map(v=>v.toString(16).padStart(2,'0')).join('');};
GX.CARS = new Set(['hatch','sedan','kart','roadster','coupe','gt','formula','proto','pickup','buggy','rally','sprint','truck']);
GX.W = {hatch:22,sedan:24,kart:15,roadster:21,coupe:24,gt:26,formula:28,proto:28,pickup:24,buggy:20,rally:22,sprint:20,truck:28,
  scooter:17,commuter:21,naked:22,sport:22,super:22,gp:22,cafe:22,trail:24,mx:24,enduro:24,smoto:23,raid:24,flat:22,sidecar:23};
GX.vehW = k=>GX.W[k]||22;
const GL='#9fd8f5',TI='#1a1a1a',LT='#fff6a8',TL='#ff3b3b',KK='#222',SV='#aab2bd';

GX.wheel = (c,cx,cy,r,f)=>{const P=GX.P;
  if(r<=2){P(c,cx-1,cy-2,3,5,TI);P(c,cx-2,cy-1,5,3,TI);P(c,cx,cy,1,1,'#999');P(c,f?cx-1:cx+1,f?cy-1:cy+1,1,1,'#666');return;}
  if(r===3){P(c,cx-1,cy-3,3,7,TI);P(c,cx-3,cy-1,7,3,TI);P(c,cx-2,cy-2,5,5,TI);P(c,cx-1,cy-1,3,3,'#9aa0a6');P(c,cx,cy,1,1,'#555');P(c,f?cx-1:cx+1,cy-1,1,1,'#666');return;}
  P(c,cx-2,cy-4,5,9,TI);P(c,cx-4,cy-2,9,5,TI);P(c,cx-3,cy-3,7,7,TI);P(c,cx-2,cy-2,5,5,'#8d939a');P(c,cx-1,cy-1,3,3,'#6b7077');P(c,cx,cy,1,1,'#ccc');
  P(c,f?cx-2:cx+2,f?cy-2:cy+1,1,1,'#555');};

GX.drawCar = (c,k,x,gy,col,acc,f)=>{
  const p=(dx,dy,w,h,cl)=>GX.P(c,x+dx,gy+dy,w,h,cl);const dk=GX.shade(col,-0.35);const W=(a,b,r)=>{GX.wheel(c,x+a,gy-r,r,f);GX.wheel(c,x+b,gy-r,r,f);};
  switch(k){
  case 'hatch':p(1,-9,20,5,col);p(0,-8,1,3,col);p(21,-8,1,3,col);p(4,-13,12,4,col);p(5,-14,10,1,col);p(16,-12,2,3,col);
    p(6,-13,4,3,GL);p(11,-13,4,3,GL);p(16,-12,1,2,GL);p(1,-6,20,1,acc);p(21,-8,1,1,LT);p(0,-8,1,1,TL);p(2,-5,18,1,dk);W(5,17,3);break;
  case 'sedan':p(0,-8,24,4,col);p(1,-9,22,1,col);p(6,-12,11,3,col);p(7,-13,9,1,col);p(7,-12,4,2,GL);p(12,-12,4,2,GL);
    p(1,-6,22,1,acc);p(23,-7,1,1,LT);p(0,-7,1,1,TL);p(1,-4,22,1,dk);W(5,19,3);break;
  case 'kart':p(1,-4,13,2,KK);p(11,-5,4,2,acc);p(0,-7,3,3,SV);p(5,-8,4,4,col);p(5,-12,4,4,acc);p(8,-11,1,2,GL);p(9,-7,3,1,col);
    GX.wheel(c,x+3,gy-3,3,f);GX.wheel(c,x+13,gy-2,2,f);break;
  case 'roadster':p(0,-8,21,4,col);p(1,-9,8,1,col);p(14,-9,6,1,col);p(12,-11,1,3,GL);p(8,-12,3,3,acc);p(10,-11,1,1,GL);
    p(1,-6,19,1,acc);p(20,-7,1,1,LT);p(0,-7,1,1,TL);p(1,-4,19,1,dk);W(4,17,3);break;
  case 'coupe':p(0,-8,24,4,col);p(1,-9,22,1,col);p(7,-12,9,3,col);p(5,-10,2,1,col);p(16,-11,3,2,col);p(8,-12,3,2,GL);p(12,-12,4,2,GL);
    p(1,-6,22,1,acc);p(23,-7,1,1,LT);p(0,-7,1,1,TL);p(1,-4,22,1,dk);W(5,19,3);break;
  case 'gt':p(0,-7,26,4,col);p(2,-8,22,1,col);p(9,-10,9,2,col);p(8,-9,12,1,col);p(10,-10,3,1,GL);p(14,-10,4,1,GL);
    p(0,-11,5,1,acc);p(2,-10,1,2,KK);p(1,-5,24,1,acc);p(25,-6,1,1,LT);p(0,-6,1,1,TL);p(1,-3,24,1,dk);W(5,21,3);break;
  case 'formula':p(18,-6,8,2,col);p(26,-5,2,1,col);p(6,-8,13,4,col);p(6,-11,6,3,col);p(12,-11,3,3,acc);p(14,-10,1,1,GL);
    p(0,-12,5,2,acc);p(2,-10,1,4,KK);p(23,-3,5,1,acc);p(7,-6,11,1,acc);W(4,22,3);break;
  case 'proto':p(0,-7,28,4,col);p(2,-8,24,1,col);p(26,-6,2,2,col);p(11,-11,8,3,col);p(12,-11,6,2,GL);p(3,-12,2,5,col);
    p(0,-12,6,1,acc);p(1,-5,26,1,acc);p(27,-6,1,1,LT);p(0,-6,1,1,TL);p(1,-3,26,1,dk);W(5,22,3);break;
  case 'pickup':p(0,-12,24,5,col);p(0,-13,10,1,dk);p(0,-14,1,2,col);p(11,-17,8,5,col);p(13,-16,5,2,GL);p(19,-15,1,3,GL);
    p(23,-11,1,1,LT);p(0,-11,1,1,TL);p(1,-8,22,1,dk);p(1,-10,22,1,acc);W(5,19,4);break;
  case 'buggy':p(2,-9,16,3,col);p(15,-8,4,2,col);p(5,-15,1,6,KK);p(12,-15,1,6,KK);p(5,-15,8,1,KK);p(8,-13,3,3,acc);p(10,-12,1,1,GL);
    p(0,-11,3,4,SV);p(3,-7,13,1,acc);W(4,16,4);break;
  case 'rally':p(1,-11,20,5,col);p(0,-10,1,3,col);p(21,-10,1,3,col);p(4,-15,12,4,col);p(5,-16,10,1,col);p(9,-17,3,1,KK);
    p(6,-15,4,3,GL);p(11,-15,4,3,GL);p(16,-14,1,2,GL);p(1,-8,20,1,acc);p(7,-10,3,2,'#fff');p(21,-11,1,2,LT);p(0,-10,1,1,TL);
    p(2,-6,1,3,KK);p(13,-6,1,3,KK);p(2,-7,18,1,dk);p(4,-7,1,2,SV);p(16,-7,1,2,SV);W(5,17,3);break;
  case 'sprint':p(3,-8,14,3,col);p(16,-7,3,2,col);p(8,-11,3,3,acc);p(6,-12,1,4,KK);p(12,-12,1,4,KK);
    p(2,-17,12,1,acc);p(2,-17,1,4,acc);p(13,-17,1,4,acc);p(7,-16,1,4,KK);p(11,-16,1,4,KK);
    GX.wheel(c,x+4,gy-4,4,f);GX.wheel(c,x+16,gy-3,3,f);break;
  case 'truck':p(0,-13,28,5,col);p(1,-14,10,1,col);p(11,-18,9,5,col);p(13,-17,5,2,GL);p(20,-16,1,2,GL);p(12,-19,7,1,LT);
    p(2,-17,4,3,KK);p(1,-10,26,1,acc);p(27,-12,1,1,LT);p(0,-12,1,1,TL);p(4,-9,1,3,SV);p(21,-9,1,3,SV);W(5,22,4);break;
  default:p(0,-8,22,4,col);W(5,17,3);
  }
};
GX.drawBike = (c,k,x,gy,col,acc,f)=>{
  const p=(dx,dy,w,h,cl)=>GX.P(c,x+dx,gy+dy,w,h,cl);const suit=GX.shade(col,-0.5);
  const W=(a,b,r)=>{GX.wheel(c,x+a,gy-r,r,f);GX.wheel(c,x+b,gy-r,r,f);};
  switch(k){
  case 'scooter':W(3,14,2);p(1,-7,7,4,col);p(7,-4,5,1,col);p(12,-10,2,7,col);p(14,-8,1,1,LT);p(2,-8,5,1,KK);
    p(4,-14,3,6,suit);p(7,-13,5,1,suit);p(4,-17,4,3,acc);p(7,-16,1,1,GL);p(6,-8,3,2,suit);p(9,-7,1,3,KK);break;
  case 'commuter':W(4,17,3);p(4,-6,13,1,SV);p(8,-6,4,2,'#666');p(9,-9,5,2,col);p(4,-9,5,1,KK);p(2,-8,3,1,col);p(16,-10,1,7,SV);
    p(14,-11,3,1,KK);p(17,-9,1,1,LT);p(6,-15,3,6,suit);p(9,-14,5,1,suit);p(6,-18,4,3,acc);p(9,-17,1,1,GL);p(8,-10,3,2,suit);p(10,-9,1,3,KK);break;
  case 'naked':W(4,18,3);p(5,-7,12,1,SV);p(8,-7,5,3,'#666');p(9,-11,6,3,col);p(3,-10,6,1,col);p(5,-11,4,1,KK);p(17,-11,1,8,SV);
    p(18,-10,1,2,LT);p(2,-5,6,1,SV);p(7,-16,4,5,suit);p(10,-15,2,2,suit);p(11,-14,5,1,suit);p(8,-19,4,3,acc);p(11,-18,1,1,GL);p(9,-11,3,2,suit);p(11,-10,1,3,KK);break;
  case 'sport':case 'super':case 'gp':W(4,18,3);p(9,-11,9,5,col);p(17,-10,2,3,col);p(10,-9,6,1,acc);p(15,-13,2,2,GL);p(2,-11,7,2,col);
    p(5,-12,4,1,KK);p(8,-6,7,2,'#555');p(17,-9,1,6,SV);p(6,-15,7,3,suit);p(12,-16,3,3,acc);p(14,-15,1,1,GL);p(13,-12,3,1,suit);
    p(7,-12,3,2,suit);p(9,-10,2,2,KK);if(k==='gp')p(3,-11,2,2,'#fff');if(k==='super')p(1,-12,2,1,acc);break;
  case 'cafe':W(4,18,3);p(5,-7,12,1,SV);p(8,-7,5,3,'#777');p(9,-11,6,3,col);p(10,-12,4,1,col);p(3,-11,4,2,col);p(6,-11,3,1,KK);
    p(17,-11,1,8,SV);p(18,-11,2,2,LT);p(15,-11,2,1,KK);p(6,-15,6,4,suit);p(11,-17,3,3,acc);p(13,-16,1,1,GL);p(12,-13,4,1,suit);p(7,-11,3,2,suit);break;
  case 'trail':case 'mx':case 'enduro':case 'smoto':case 'raid':{
    const r=k==='smoto'?3:4;W(4,19,r);p(6,-9,11,1,SV);p(8,-8,4,3,'#666');p(4,-13,6,1,KK);p(0,-13,5,1,col);
    if(k==='raid'){p(8,-14,8,4,col);p(17,-18,3,6,col);p(19,-20,1,2,GL);}else p(9,-13,6,3,col);
    if(k==='smoto')p(17,-8,4,1,col);else p(17,-13,5,1,col);
    p(18,-13,1,9,SV);p(16,-15,3,1,KK);if(k==='mx'||k==='smoto')p(17,-16,2,3,'#fff');if(k==='trail'||k==='enduro')p(19,-13,2,2,LT);
    if(k==='trail'){p(6,-17,3,5,suit);p(6,-21,4,4,suit);p(10,-19,5,1,suit);p(6,-24,4,3,acc);p(9,-23,1,1,GL);p(8,-13,3,2,suit);}
    else{p(8,-17,2,5,suit);p(8,-22,4,5,suit);p(12,-21,4,1,suit);p(9,-25,4,3,acc);p(13,-24,2,1,acc);p(12,-24,1,1,GL);p(9,-13,2,1,KK);}
    break;}
  case 'flat':W(4,18,3);p(5,-7,12,1,SV);p(8,-7,5,3,'#777');p(9,-10,6,2,col);p(2,-12,5,3,'#fff');p(3,-11,2,1,KK);p(6,-11,4,1,KK);
    p(17,-11,1,8,SV);p(15,-12,3,1,KK);p(7,-16,5,4,suit);p(11,-18,3,3,acc);p(13,-17,1,1,GL);p(12,-14,4,1,suit);p(8,-12,3,2,suit);break;
  case 'sidecar':GX.wheel(c,x+3,gy-2,2,f);GX.wheel(c,x+13,gy-2,2,f);GX.wheel(c,x+20,gy-2,2,f);p(0,-6,22,2,col);p(14,-9,7,3,col);
    p(1,-8,8,2,col);p(15,-8,4,1,acc);p(10,-12,5,3,suit);p(14,-14,3,3,acc);p(2,-11,4,3,suit);p(1,-14,3,3,GL);break;
  default:W(4,18,3);p(5,-9,12,3,col);
  }
};
GX.drawVeh = (c,k,x,gy,col,acc,f)=>GX.CARS.has(k)?GX.drawCar(c,k,x,gy,col,acc,f):GX.drawBike(c,k,x,gy,col,acc,f);

GX.drawPerson = (c,x,gy,o)=>{
  const m=o.dir<0;const p=(dx,dy,w,h,cl)=>GX.P(c,x+(m?5-dx-w:dx),gy+dy,w,h,cl);const sit=o.pose==='sit';const dy=sit?2:0;
  if(sit){p(1,-3,4,1,KK);p(4,-2,1,2,KK);}
  else if(o.pose==='walk'&&o.f){p(1,-3,1,3,KK);p(3,-2,1,2,KK);p(3,-3,1,1,o.suit);}
  else{p(1,-3,1,3,KK);p(3,-3,1,3,KK);}
  p(0,-7+dy,5,4,o.suit);p(0,-4+dy,5,1,GX.shade(o.suit,-0.3));
  if(o.pose==='work'){p(4,-6+dy,2,1,o.skin);p(6,-8+dy+(o.f?1:0),1,3,'#c8ccd0');}
  else if(o.pose==='cheer'){p(-1,-10+dy,1,4,o.skin);p(5,-10+dy,1,4,o.skin);}
  else{p(4,-6+dy,1,3,o.suit);}
  p(0,-12+dy,5,5,o.skin);p(0,-12+dy,5,2,o.hair);p(0,-11+dy,1,2,o.hair);p(3,-10+dy,1,1,'#222');
  if(o.cap){p(0,-13+dy,5,1,o.cap);p(4,-12+dy,2,1,o.cap);}
};

// ---------- thumbnails (cached data URLs) ----------
GX._th={};
GX.thumb = (kind,col,acc='#fff')=>{const key=kind+col+acc;if(GX._th[key])return GX._th[key];
  const cv=document.createElement('canvas');cv.width=34*3;cv.height=28*3;const c=cv.getContext('2d');c.imageSmoothingEnabled=false;c.scale(3,3);
  const w=GX.vehW(kind);GX.drawVeh(c,kind,Math.floor((34-w)/2),26,col,acc,0);return GX._th[key]=cv.toDataURL();};
GX.face = (s)=>{const key='f'+s.id+s.hair+s.role;if(GX._th[key])return GX._th[key];
  const cv=document.createElement('canvas');cv.width=9*4;cv.height=15*4;const c=cv.getContext('2d');c.scale(4,4);
  GX.drawPerson(c,2,14,{hair:s.hair,skin:s.skin,suit:s.role==='drv'?G.team.color:'#3b5ba5',dir:1,pose:'stand',cap:s.role==='mec'?'#e2b53a':null});
  return GX._th[key]=cv.toDataURL();};

// ---------- GARAGE SCENE ----------
GX.S = {W:160,H:120,actors:{},floats:[],parts:[],t:0};
GX.bays = ()=>{const cap=E.ws().veh;const rows=cap<=5?1:2;const per=Math.ceil(cap/rows);const out=[];const bw=156/per;
  for(let i=0;i<cap;i++){const row=rows===1?0:(i<per?1:0);const col=rows===1?i:(i%per);
    out.push({x:2+col*bw,w:bw,gy:rows===1?110:(row===1?114:90)});}return out;};
GX.vehBay = vid=>{const i=G.vehicles.findIndex(v=>v.id===vid);if(i<0)return null;return GX.bays()[i]||null;};
GX.addFloat = (text,x,y,col)=>{for(const f of GX.S.floats)if(f.t<0.6&&Math.abs(f.x-x)<30&&Math.abs(f.y-f.t*8-y)<7)y-=8;GX.S.floats.push({text,x,y,col:col||'#fff',t:0});if(GX.S.floats.length>12)GX.S.floats.shift();};
GX.floatAtVeh = (text,vid,col)=>{const b=vid!=null?GX.vehBay(vid):null;
  if(b)GX.addFloat(text,b.x+b.w/2,b.gy-22,col);else{const a=Object.values(GX.S.actors);const r=a.length?U.pick(a):{x:100,gy:100};GX.addFloat(text,r.x+3,r.gy-16,col);}};

GX.wall = (c)=>{const P=GX.P,W=160;const ws=G.ws;
  if(ws===1){P(c,0,10,W,54,'#8a5a35');for(let x=0;x<W;x+=9)P(c,x,10,1,54,'#6e4527');for(let i=0;i<14;i++)P(c,(i*37)%W+3,18+(i*13)%40,2,1,'#5d3a20');}
  else if(ws===2){P(c,0,10,W,54,'#a3503f');for(let y=10;y<64;y+=5){P(c,0,y,W,1,'#c9a99a');for(let x=((y/5)%2)*6;x<W;x+=12)P(c,x,y,1,5,'#c9a99a');}}
  else if(ws===3){P(c,0,10,W,54,'#7d8a96');for(let x=0;x<W;x+=25)P(c,x,10,1,54,'#6a7682');P(c,0,36,W,1,'#6a7682');P(c,0,58,W,2,'#5a6570');P(c,0,13,W,1,'#9aa6b1');}
  else{P(c,0,10,W,54,'#27324a');for(let x=0;x<W;x+=40)P(c,x,10,2,54,'#33405c');P(c,0,32,W,1,'#7fd3ff');P(c,0,60,W,1,'#7fd3ff');
    c.globalAlpha=0.3;P(c,8,36,40,18,G.team.color);c.globalAlpha=1;}
  // windows
  const mo=Math.floor((G.day%D.DAYS_YEAR)/D.DAYS_MONTH);const winter=mo>=8&&mo<=10;const autumn=mo>=5&&mo<=7;const tt=GX.S.t;
  const win=(x,y,w,h)=>{P(c,x-1,y-1,w+2,h+2,'#3a2c20');P(c,x,y,w,h,winter?'#b8cbe0':'#9ad7f5');
    c.save();c.beginPath();c.rect(x,y,w,h);c.clip();for(let k=0;k<2;k++){const cx=x+((k*23+tt*2)%(w+16))-8;P(c,cx,y+3+k*4,8,2,'#fff');P(c,cx+2,y+2+k*4,4,1,'#fff');}
    if(winter)for(let k=0;k<6;k++)P(c,x+((k*7+tt*3)%w),y+((k*5+tt*8)%h),1,1,'#fff');c.restore();
    P(c,x,y+h-4,w,4,winter?'#f2f6fb':autumn?'#c98a3a':'#7cc36b');P(c,x+w/2,y,1,h,'#3a2c20');P(c,x,y+Math.floor(h/2),w,1,'#3a2c20');P(c,x+2,y+2,3,1,'#fff');};
  if(ws===1)win(122,36,22,16);else if(ws===2){win(100,36,20,16);win(130,36,20,16);}else if(ws===3){win(92,36,30,18);win(126,36,28,18);}
  else{P(c,98,36,58,20,'#5cc0f0');P(c,98,52,58,4,'#6ab86a');for(let x=98;x<156;x+=14)P(c,x,36,1,20,'#1b2234');}
  // pegboard & tools
  if(ws<=2){P(c,6,36,36,16,'#c9a26a');for(let i=0;i<4;i++){P(c,10+i*8,39,1,6,'#555');P(c,9+i*8,45,3,2,'#888');}P(c,46,44,8,12,'#c0392b');P(c,46,44,8,2,'#7f1d12');}
  else if(ws===3){P(c,6,36,30,16,'#2c3e50');P(c,8,38,26,12,'#16a085');for(let i=0;i<4;i++)P(c,10+i*6,42+(i%2)*3,4,1,'#9ff');P(c,40,40,14,14,'#e67e22');}
  // trophy shelf
  const tro=Math.min(5,G.st.titles.length);if(tro){P(c,58,54,4+tro*7,2,'#5a4632');const ts=G.st.titles.slice().sort((a,b)=>D.SER[b].tier-D.SER[a].tier);for(let i=0;i<tro;i++){const tc=['#cd7f32','#c0c0c0','#ffd700','#ffd700','#7ff'][Math.min(4,D.SER[ts[i]].tier-1)];P(c,61+i*7,49,4,3,tc);P(c,62+i*7,52,2,2,tc);}}
};
GX.facRow = (c)=>{const P=GX.P;const n=E.ws().fac;const list=G.fac.filter(Boolean);
  for(let i=0;i<n;i++){const x=3+i*17,y=13;const f=list[i];
    if(!f){c.globalAlpha=0.5;P(c,x,y,15,16,'#000');c.globalAlpha=1;P(c,x+6,y+7,3,1,'#888');P(c,x+7,y+6,1,3,'#888');continue;}
    const F=D.FAC[f.id];P(c,x,y,15,16,'#1d1d28');P(c,x+1,y+1,13,12,F.col);P(c,x+1,y+1,13,2,GX.shade(F.col,0.25));
    c.fillStyle='#fff';c.font='8px '+GX.FONT;c.textAlign='center';c.textBaseline='middle';c.fillText(F.ic,x+7.5,y+7.5);
    for(let l=0;l<f.lv;l++)P(c,x+2+l*4,y+13,3,2,'#ffd84a');}
};
GX.floor = (c)=>{const P=GX.P;const col=['','#6b6257','#7d7d7d','#8d9399','#bfc5ce'][G.ws];P(c,0,64,160,56,col);
  P(c,0,64,160,2,GX.shade(col,-0.25));
  for(const b of GX.bays()){P(c,b.x+1,b.gy+1,1,4,'#e2b53a');P(c,b.x+b.w-2,b.gy+1,1,4,'#e2b53a');P(c,b.x+1,b.gy+4,b.w-2,1,'#e2b53a');}
  if(G.ws>=4){c.globalAlpha=0.12;for(let x=0;x<160;x+=30)P(c,x,66,12,54,'#fff');c.globalAlpha=1;}
};
GX.drawScene = (c,dt)=>{
  const S=GX.S;S.t+=dt;const P=GX.P;c.imageSmoothingEnabled=false;
  P(c,0,0,160,120,'#000');GX.wall(c);GX.facRow(c);GX.floor(c);
  // banner
  P(c,0,0,160,10,'#141821');P(c,0,9,160,1,G.team.color);
  c.font='7px '+GX.FONT;c.textBaseline='middle';c.textAlign='left';c.fillStyle='#ffd84a';c.fillText(G.team.name,3,5);
  c.textAlign='right';c.fillStyle='#9fb3d1';c.fillText(E.ws().n,157,5);
  // collect drawables
  const items=[];const bays=GX.bays();const busy={};G.jobs.forEach(j=>busy[j.vid]=j);
  G.vehicles.forEach((v,i)=>{const b=bays[i];if(!b)return;items.push({y:b.gy,draw:()=>GX.drawBayVeh(c,v,b,busy[v.id])});});
  // actors
  const mechs=E.mechs(),jobs=G.jobs;
  for(const s of G.staff){let a=S.actors[s.id];if(!a)a=S.actors[s.id]={x:U.rand(10,140),gy:U.rand(80,116),tx:null,tgy:null,dir:1,f:0,ft:0,mode:'idle',timer:U.rand(0.5,2)};
    const mi=mechs.indexOf(s);let target=null;
    if(s.role==='mec'&&jobs.length){const j=jobs[mi%jobs.length];const vi=G.vehicles.findIndex(v=>v.id===j.vid);const b=bays[vi];
      if(b){const side=(mi%2)?-1:1;target={x:b.x+b.w/2+side*(GX.vehW(D.BODY[G.vehicles[vi].body].kind)/2+2)-2,gy:b.gy+(mi%3===2?-3:1)};}}
    if(target){a.tx=target.x;a.tgy=target.gy;}
    else if(a.timer<=0||a.mode==='work'){a.timer=U.rand(2,6);
      if(s.role==='drv'&&s.energy<35){a.tx=134+U.rand(-5,5);a.tgy=78;a.mode='tired';}
      else{a.tx=U.rand(6,148);a.tgy=U.rand(74,118);a.mode='walk';}}
    a.timer-=dt;
    if(a.tx!=null){const dx=a.tx-a.x,dy=a.tgy-a.gy,d=Math.hypot(dx,dy);
      if(d>1){const sp=16*dt;a.x+=dx/d*Math.min(sp,d);a.gy+=dy/d*Math.min(sp,d);a.dir=dx>=0?1:-1;a.ft+=dt;if(a.ft>0.18){a.ft=0;a.f^=1;}a.pose='walk';}
      else{a.pose=target?'work':(a.mode==='tired'?'sit':'stand');if(target){a.dir=(G.vehicles.length&&a.x<a.tx+3)?1:-1;a.ft+=dt;if(a.ft>0.25){a.ft=0;a.f^=1;if(U.chance(0.5))S.parts.push({x:a.x+(a.dir>0?7:-2),y:a.gy-6,vx:U.rand(-15,15),vy:U.rand(-25,-8),t:0});}}}}
    items.push({y:a.gy,draw:()=>{GX.drawPerson(c,a.x,a.gy,{hair:s.hair,skin:s.skin,suit:s.role==='drv'?G.team.color:'#3b5ba5',dir:a.dir,f:a.f,pose:a.pose,cap:s.role==='mec'?'#e2b53a':null});
      if(a.pose==='sit'&&Math.floor(S.t*2)%2){c.font='6px '+GX.FONT;c.fillStyle='#fff';c.textAlign='left';c.fillText('z',a.x+5,a.gy-13);}}});
  }
  for(const id in S.actors)if(!G.staff.find(s=>s.id==id))delete S.actors[id];
  // bench
  items.push({y:79,draw:()=>{P(c,126,74,22,2,'#6b4a2b');P(c,127,76,1,3,'#4a3220');P(c,146,76,1,3,'#4a3220');}});
  items.sort((a,b)=>a.y-b.y).forEach(it=>it.draw());
  // particles
  S.parts=S.parts.filter(p=>(p.t+=dt)<0.5);for(const p of S.parts){p.x+=p.vx*dt;p.y+=p.vy*dt;p.vy+=60*dt;P(c,p.x,p.y,1,1,p.t<0.25?'#fff7a0':'#ffb43a');}
  // floats
  c.font='7px '+GX.FONT;c.textAlign='center';c.textBaseline='middle';
  S.floats=S.floats.filter(f=>(f.t+=dt)<1.8);
  for(const f of S.floats){const y=f.y-f.t*8;c.globalAlpha=f.t>1.3?(1.8-f.t)*2:1;c.fillStyle='#000';c.fillText(f.text,f.x+0.6,y+0.6);c.fillStyle=f.col;c.fillText(f.text,f.x,y);c.globalAlpha=1;}
};
GX.drawBayVeh = (c,v,b,job)=>{
  const P=GX.P;const B=D.BODY[v.body];const w=GX.vehW(B.kind);const x=Math.round(b.x+(b.w-w)/2);let gy=b.gy;
  const f=Math.floor(GX.S.t*4)%2;
  if(v.status==='build'&&job){
    const pi=job.pd?job.pi:Math.min(7,Math.floor(U.clamp(1-job.left/job.total,0,0.999)*8));const bare='#8d959d';
    if(pi===0){c.globalAlpha=0.55;GX.drawVeh(c,B.kind,x,gy,'#5b8cff','#9fc0ff',0);c.globalAlpha=1;for(let k=0;k<5;k++)P(c,x-2+k*((w+4)/4),gy-26,1,26,'#2b4a8f');P(c,x-2,gy-13,w+4,1,'#2b4a8f');}
    else if(pi<5){c.globalAlpha=0.45+0.11*pi;GX.drawVeh(c,B.kind,x,gy,bare,'#c3cbd3',0);c.globalAlpha=1;}
    else if(pi===5){const pl=job.plen||job.total/8;const pp=job.pd?U.clamp(1-Math.max(0,job.pd[5])/pl,0,1):0.5;GX.drawVeh(c,B.kind,x,gy,bare,'#c3cbd3',0);
      c.save();c.beginPath();c.rect(x-2,gy-30,Math.max(1,(w+4)*pp),32);c.clip();GX.drawVeh(c,B.kind,x,gy,G.team.color,'#ffd84a',0);c.restore();
      if(Math.floor(GX.S.t*8)%2)P(c,x-3+(w+4)*pp,gy-14+Math.sin(GX.S.t*9)*4,2,2,'#dfe6ee');}
    else GX.drawVeh(c,B.kind,x,gy,G.team.color,'#ffd84a',0);
    if(pi>=1&&pi<=3){P(c,x+2,gy-3,3,3,'#5a4a2a');P(c,x+w-5,gy-3,3,3,'#5a4a2a');}
    if(pi===2&&Math.floor(GX.S.t*6)%3===0)P(c,x+w/2,gy-12,2,2,'#fff7a0');
    P(c,x-2,gy-24,1,24,'#8a6d3b');P(c,x+w+1,gy-24,1,24,'#8a6d3b');P(c,x-2,gy-24,w+4,1,'#8a6d3b');
    if(job.wait&&Math.floor(GX.S.t*3)%2){c.font='9px '+GX.FONT;c.fillStyle='#ffd84a';c.textAlign='center';c.textBaseline='middle';c.fillText('?',x+w/2,gy-17);}
  }else{
    if(job){P(c,x+2,gy-1,w-4,1,'#444');gy-=3;P(c,x+3,gy+1,1,2,SV);P(c,x+w-4,gy+1,1,2,SV);}
    GX.drawVeh(c,B.kind,x,gy,G.team.color,'#ffd84a',job?f:0);
    if(v.hp<0.6&&!job){c.font='7px '+GX.FONT;c.fillStyle='#f66';c.textAlign='center';c.fillText('!',x+w/2,gy-20);}
  }
  if(job){const prog=U.clamp(1-job.left/job.total,0,1);P(c,x,b.gy-30,w,3,'#111');P(c,x+1,b.gy-29,Math.round((w-2)*prog),1,job.type==='rep'?'#f66':job.type==='up'?'#6cf':'#7f7');
    c.font='6px '+GX.FONT;c.fillStyle='#fff';c.textAlign='center';c.fillText(job.type==='rep'?'REPAIR':job.type==='up'?'TUNE '+job.k.toUpperCase():job.type==='reb'?'REBUILD':job.type==='swap'?'FUEL SYS':(job.pd?D.BPHS[D.BPH[job.pi]]+' '+(job.pi+1)+'/8':'BUILD'),x+w/2,b.gy-34);}
};

// ---------- TRACK SHAPE ----------
GX._shape={};
GX.trackShape = (def,tr,box)=>{
  const key=def.id+box.join(',');if(GX._shape[key])return GX._shape[key];
  const rng=U.seeded(U.hash(def.id)+99);const[cx,cy,rx,ry]=box;const pts=[];
  if(tr.p2p){const N=48,a1=rng()*6,a2=rng()*6;for(let i=0;i<=N;i++){const t=i/N;pts.push([cx-rx+t*2*rx,cy+ry*0.7*(Math.sin(t*5+a1)*0.6+Math.sin(t*11+a2)*0.3)]);}}
  else if(tr.oval){const N=64;for(let i=0;i<=N;i++){const a=i/N*Math.PI*2;pts.push([cx+rx*0.9*Math.cos(a),cy+ry*0.85*Math.sin(a)]);}}
  else{const N=72,p1=rng()*6,p2=rng()*6,p3=rng()*6,a1=0.1+rng()*0.12,a2=0.06+rng()*0.1,a3=0.03+rng()*0.06;
    for(let i=0;i<=N;i++){const a=i/N*Math.PI*2;const r=1+a1*Math.sin(2*a+p1)+a2*Math.sin(3*a+p2)+a3*Math.sin(5*a+p3);pts.push([cx+rx*0.82*r*Math.cos(a),cy+ry*0.8*r*Math.sin(a)]);}}
  const cum=[0];for(let i=1;i<pts.length;i++)cum.push(cum[i-1]+Math.hypot(pts[i][0]-pts[i-1][0],pts[i][1]-pts[i-1][1]));
  return GX._shape[key]={pts,cum,len:cum[cum.length-1]};
};
GX.shapeAt = (sh,frac)=>{const d=U.clamp(frac,0,1)*sh.len;let i=1;while(i<sh.cum.length-1&&sh.cum[i]<d)i++;const a=sh.pts[i-1],b=sh.pts[i];const seg=sh.cum[i]-sh.cum[i-1]||1;const t=(d-sh.cum[i-1])/seg;return[a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t];};
GX.drawTrack = (c,def,tr,box,lw=3)=>{
  const sh=GX.trackShape(def,tr,box);
  const seg=(f0,f1,col,w)=>{c.strokeStyle=col;c.lineWidth=w;c.lineCap='round';c.lineJoin='round';c.beginPath();const n=Math.max(2,Math.ceil((f1-f0)*60));for(let i=0;i<=n;i++){const p=GX.shapeAt(sh,f0+(f1-f0)*i/n);i?c.lineTo(p[0],p[1]):c.moveTo(p[0],p[1]);}c.stroke();};
  seg(0,1,'#111',lw+2);
  for(const s of tr.secs){seg(s.at/tr.lapLen,(s.at+s.len)/tr.lapLen,D.SURF[s.surf].col,lw);
    if(s.type==='jmp'){const p=GX.shapeAt(sh,(s.at+0.5)/tr.lapLen);GX.P(c,p[0]-1,p[1]-1,2,2,'#ff4');}}
  const s0=GX.shapeAt(sh,0);GX.P(c,s0[0]-2,s0[1]-2,4,4,'#fff');GX.P(c,s0[0]-2,s0[1]-2,2,2,'#000');GX.P(c,s0[0],s0[1],2,2,'#000');
  if(tr.p2p){const s1=GX.shapeAt(sh,1);GX.P(c,s1[0]-2,s1[1]-2,4,4,'#fff');GX.P(c,s1[0]-2,s1[1]-2,2,2,'#000');GX.P(c,s1[0],s1[1],2,2,'#000');}
  return sh;
};

// ---------- RACE VIEW ----------
GX.ENV = {tar:'stadium',wet:'stadium',dirt:'country',mud:'swamp',sand:'desert',snow:'snow',ice:'snow'};
GX.SKY = {mountain:['#3d8fd8','#bfe2f7'],stadium:['#4aa8ee','#b6e2fa'],country:['#58b2e6','#cdebf8'],swamp:['#7c968a','#c2d2bf'],desert:['#f09a4c','#fde0a6'],snow:['#a9c4da','#eef5fa'],rain:['#5b6b7a','#9aa6b0']};
GX.drawRace = (c,rs,dt)=>{
  const P=GX.P;const W=160,PPU=34,CX=52;c.imageSmoothingEnabled=false;const t=rs.t;
  const me=(rs.player.dnf&&!rs.player.fin)?rs.order[0]:rs.player;rs.cam=rs.cam==null?me.prog:rs.cam+(me.prog-rs.cam)*Math.min(1,dt*8);const cam=rs.cam;
  let env=GX.ENV[Race.mainSurf(rs.tr)];if(rs.tr.hill&&env!=='snow')env='mountain';const tod=(rs.cond&&rs.cond.tod)||'day';const night=tod==='night';
  const sky=night?['#0b1030','#26305a']:rs.rain?GX.SKY.rain:GX.SKY[env];
  for(let i=0;i<8;i++){P(c,0,i*7,W,7,GX.mixc(sky[0],sky[1],i/7));}
  const hf=rs.tr.hill?U.clamp(cam/rs.tr.total,0,1):0;const sink=Math.round(hf*14);
  if(night){for(let i=0;i<26;i++){const x=(i*61)%W,y=(i*37)%40;if((Math.floor(t*2+i)%7)!==0)P(c,x,y,1,1,'#fff');}P(c,128,8,7,7,'#f4f1d0');P(c,130,8,5,5,'#26305a');}
  else if(!rs.rain){P(c,130,7,8,8,env==='desert'?'#fff3c4':'#fff8d8');P(c,129,9,10,4,env==='desert'?'#fff3c4':'#fff8d8');}
  // clouds
  if(!night){c.globalAlpha=rs.rain?0.9:0.85;for(let i=0;i<5;i++){const x=((i*53-cam*PPU*0.03-t*3)%200+200)%200-30;const y=6+((i*17)%18)+sink*0.3;const cc=rs.rain?'#8a96a3':'#fff';
    P(c,x,y,22,4,cc);P(c,x+4,y-3,12,3,cc);P(c,x+12,y-2,8,2,cc);}c.globalAlpha=1;}
  c.save();c.translate(0,-6+sink);
  // far mountains
  const off=cam*PPU*0.08;const hc=night?'#1b2445':{mountain:'#7b8ea6',stadium:'#6c8fae',country:'#7d9fb0',swamp:'#55705f',desert:'#c98a52',snow:'#c8d6e2'}[env];
  for(let x=0;x<W;x+=2){const h=14+8*Math.sin((x+off)*0.025)+5*Math.sin((x+off)*0.061);P(c,x,50-h,2,h+12,hc);if(env==='snow'||env==='mountain'){P(c,x,50-h,2,2,'#fff');if(h>19)P(c,x,52-h,2,3,'#fff');}}
  // mid hills
  const off2=cam*PPU*0.18;const hc2=night?'#141b38':{mountain:'#4d6b57',stadium:'#58789a',country:'#4f8a55',swamp:'#3f5d47',desert:'#b8743f',snow:'#a9bccb'}[env];
  for(let x=0;x<W;x+=2){const h=7+5*Math.sin((x+off2)*0.045+1)+3*Math.sin((x+off2)*0.11);P(c,x,56-h,2,h+8,hc2);}
  if(hf>0.45){c.globalAlpha=Math.min(0.8,(hf-0.45)*2);P(c,0,52,W,8,'#f2f6fb');for(let x=0;x<W;x+=9)P(c,(x-t*4)%W,50,7,3,'#ffffff');c.globalAlpha=1;}
  // mid scenery
  const mo=cam*PPU*0.45;const step=44;const first=Math.floor(mo/step)-1;
  for(let i=first;i<first+6;i++){const sx=i*step-mo;const r=U.seeded(i*7919+3)();GX.scenery(c,env,sx,i,r,t,night,rs.drag);}
  c.restore();
  // near trackside (posts/cones)
  const no=cam*PPU*0.85;for(let i=Math.floor(no/24)-1;i<Math.floor(no/24)+8;i++){const x=i*24-no;const k=(i*7)%5;
    if(rs.drag){P(c,x,51,24,5,'#bfc4c9');P(c,x,51,24,1,'#e8ecef');continue;}
    if(env==='mountain'){P(c,x+6,49,1,7,'#e8e8e8');P(c,x+6,49,1,2,'#d33');}
    else if(env==='stadium'){P(c,x,50,12,5,['#e74c3c','#3498db','#f1c40f','#2ecc71','#ecf0f1'][k]);P(c,x+1,51,10,1,'#fff');}
    else if(env==='snow'){P(c,x+4,50,6,5,'#fff');}else{P(c,x+6,48,1,8,'#6b4a2b');if(k<2)P(c,x+2,52,3,4,'#ff8c1a');}}
  // ground
  P(c,0,56,W,28,'#555');
  for(let x=0;x<W;x+=2){const d=cam+(x-CX)/PPU;if(d<0||d>rs.tr.total){P(c,x,56,2,28,rs.drag?'#6e7277':'#555');continue;}const sec=rs.tr.secs[Race.secAt(rs.tr,d)];
    const col=D.SURF[sec.surf].col;const yo=sec.type==='hill'?Math.round((x-CX)*-0.06):0;P(c,x,56+yo,2,28-yo,col);if(yo<0)P(c,x,56+yo,2,1,GX.shade(col,0.2));
    const wx=Math.floor(d*PPU);
    if(rs.drag){if(Math.floor(wx/12)%2===0)P(c,x,75,2,1,'#f2f2f2');P(c,x,57,2,1,'#fff');P(c,x,83,2,1,'#fff');if(wx%40<3)P(c,x,60+(wx%18),2,1,'#3c3c3c');continue;}
    if(sec.surf==='tar'||sec.surf==='wet'){if(Math.floor(wx/2)%2===0)P(c,x,56+yo,2,2,(Math.floor(wx/6)%2)?'#e33':'#fff');if(Math.floor(wx/12)%2===0)P(c,x,71,2,1,'#ddd');if(sec.surf==='wet'&&(wx%17)<2)P(c,x,62+(wx%13),2,1,'#8fb3d6');}
    else if(sec.surf==='dirt'){if(wx%7===0)P(c,x,58+(wx*13)%24,1,1,'#7a4a24');if(wx%29<2)P(c,x,64+(wx%9),2,1,'#8e5a2f');}
    else if(sec.surf==='sand'){if(wx%9<2)P(c,x,58+(wx*7)%24,2,1,'#c49a45');}
    else if(sec.surf==='mud'){if(wx%23<5)P(c,x,62+(wx*5)%16,2,2,'#4b3219');if(wx%23<3)P(c,x,62+(wx*5)%16,1,1,'#8a6a45');}
    else if(sec.surf==='snow'){if(wx%11===0)P(c,x,59+(wx*3)%22,1,1,'#bcd');}
    else if(sec.surf==='ice'){if(wx%15<2)P(c,x,59+(wx*3)%22,2,1,'#e8fbff');}
    if(sec.type==='jmp'){const fr=(((d%rs.tr.lapLen)+rs.tr.lapLen)%rs.tr.lapLen-sec.at)/sec.len;if(fr<0.5){const h=Math.round(fr*2*7);P(c,x,56-h,2,h,GX.shade(col,-0.2));}}
    if(sec.type==='rgh'&&wx%10<3)P(c,x,55,2,1,GX.shade(col,-0.3));
  }
  // start/finish & lap lines
  for(let L=0;L<=rs.tr.laps;L++){if(rs.tr.p2p&&L>0&&L<rs.tr.laps&&!rs.tt)continue;const d=L*rs.tr.lapLen;const sx=CX+(d-cam)*PPU;if(sx<-4||sx>W)continue;for(let y=56;y<84;y+=2){P(c,sx,y,2,2,(y/2)%2?'#fff':'#000');P(c,sx+2,y,2,2,(y/2)%2?'#000':'#fff');}
    if(L===0||L===rs.tr.laps){P(c,sx-1,30,2,26,'#444');P(c,sx+3,30,2,26,'#444');P(c,sx-1,28,8,4,L===0?'#1a1a1a':'#c0392b');}}
  // drag christmas tree
  if(rs.drag){const sx=CX+(0-cam)*PPU-8;if(sx>-10&&sx<W){P(c,sx,36,3,20,'#333');P(c,sx-3,34,9,4,'#222');
    const ph=rs.t/rs.tree;for(let k=0;k<3;k++){const on=ph>=0.3+k*0.22&&ph<1;P(c,sx-2,38+k*4,7,3,on?'#ffb000':'#4a3a10');}
    const green=rs.t>=rs.tree;P(c,sx-2,50,7,3,rs.player.redlight&&green?'#ff2020':green?'#20ff40':'#103a18');}
    const fx=CX+(rs.tr.total-cam)*PPU+6;if(fx<W+40){P(c,fx,26,34,14,'#111');c.font='6px '+GX.FONT;c.fillStyle='#ffb000';c.textAlign='left';c.textBaseline='top';
      c.fillText(rs.et?rs.et.et.toFixed(2):'--.--',fx+2,27);c.fillText(rs.et?rs.et.mph+'mph':'',fx+2,33);}}
  // entrants
  const lanes=rs.drag?[68,75,82]:[68,75,82];const ents=rs.ents.slice().sort((a,b)=>a.lane-b.lane);
  const ghost=rs.tt?rs.order.find(e=>!e.isPlayer&&!e.dnf):null;
  for(const e of ents){if(rs.tt&&!e.isPlayer&&e!==ghost)continue;const sx=CX+(e.prog-cam)*PPU;const w=GX.vehW(e.kind);if(sx<-w||sx>W+w)continue;
    let gy=lanes[e.lane];let yo=0;if(e.air>0)yo=-Math.sin(e.air*Math.PI)*10;
    const si=Race.secAt(rs.tr,Math.max(0,e.prog));const sec=rs.tr.secs[si];if(sec&&sec.type==='rgh'&&!e.fin)yo-=(Math.floor(t*12+e.lane)%2);
    if(sec&&sec.type==='hill')yo+=Math.round((sx-CX)*-0.06);
    let xo=0;if(e.slow>0)xo=Math.sin(t*40)*1.5;
    if((e.dnf&&!e.fin)||e===ghost)c.globalAlpha=e===ghost?0.38:0.5;
    const launch=rs.drag&&rs.t<rs.tree+0.6&&rs.t>0.3;
    GX.drawVeh(c,e.kind,sx-w/2+xo,gy+yo,e.col,e.isPlayer?'#ffd84a':'#fff',(e.fin||e.dnf)?0:Math.floor(t*(launch?30:12))%2);c.globalAlpha=1;
    if(e===ghost){c.font='5px '+GX.FONT;c.fillStyle='#cfe';c.textAlign='center';c.fillText('BEST',sx,gy+yo-(GX.CARS.has(e.kind)?20:28));}
    if(e.isPlayer){const my=gy+yo-(GX.CARS.has(e.kind)?22:30);P(c,sx-2,my,5,1,'#ffd84a');P(c,sx-1,my+1,3,1,'#ffd84a');P(c,sx,my+2,1,1,'#ffd84a');}
    if(e.boost>0){for(let i=0;i<4;i++)P(c,sx-w/2-6-i*5,gy-4-i*2,4,1,'#9ff');}
    if(e.isPlayer&&night){c.globalAlpha=0.25;P(c,sx+w/2,gy-8,26,6,'#fff6a8');c.globalAlpha=1;}
    // fx emitters
    const moving=!e.fin&&!e.dnf&&e.v>0.1;
    if(moving&&sec&&U.chance(dt*16)){const s2=D.SURF[sec.surf];if(sec.surf!=='tar'||rs.drag&&launch)rs.fx.push({x:e.prog-w/2/PPU,y:gy-2,vy:U.rand(-8,-2),t:0,col:rs.drag?'#dfe3e6':sec.surf==='wet'?'#d6ecff':GX.shade(s2.col,-0.1),sz:rs.drag?3:2});}
    if(e.isPlayer&&moving&&e.sk&&sec){const k=e.sk[si];
      if(k.smoke==='rich'&&U.chance(dt*10))rs.fx.push({x:e.prog-w/2/PPU,y:gy-5,vy:U.rand(-10,-4),t:0,col:'#2a2a2a',sz:3});
      if(k.smoke==='pop'&&U.chance(dt*6)){rs.fx.push({x:e.prog-w/2/PPU,y:gy-4,vy:0,t:0,col:'#ff9a1f',sz:3,life:0.15});rs.fx.push({x:e.prog-w/2/PPU-0.05,y:gy-4,vy:0,t:0,col:'#ffe066',sz:2,life:0.12});}}
    if(e.air>0.95&&U.chance(0.5))for(let i=0;i<3;i++)rs.fx.push({x:e.prog,y:gy-1,vy:U.rand(-14,-6),t:0,col:'#ffe9a0',sz:1,life:0.3});
  }
  rs.fx=rs.fx.filter(p=>(p.t+=dt)<(p.life||0.7));for(const p of rs.fx){const sx=CX+(p.x-cam)*PPU-p.t*10;const s=(p.sz||2)+(p.life?0:Math.floor(p.t*3));c.globalAlpha=p.life?1:Math.max(0,1-p.t/0.7);P(c,sx,p.y+p.vy*p.t,s,s,p.col);c.globalAlpha=1;}
  // foreground tufts / barrier
  const fo=cam*PPU*1.3;for(let i=Math.floor(fo/14)-1;i<Math.floor(fo/14)+13;i++){const x=i*14-fo;
    if(rs.drag)P(c,x,82,14,2,'#9aa0a6');else if(env==='snow')P(c,x+3,82,6,2,'#fff');else if(env==='desert')P(c,x+4,82,3,2,'#b9893e');else{P(c,x+4,81,1,3,'#2f6a2a');P(c,x+6,82,1,2,'#3f8a37');}}
  // weather
  if(rs.rain||Race.mainSurf(rs.tr)==='wet'){c.globalAlpha=0.6;for(let i=0;i<40;i++){const x=(i*53+t*160)%W,y=(i*29+t*240)%84;P(c,x,y,1,3,'#cfe3f5');}c.globalAlpha=1;}
  if(env==='snow'){for(let i=0;i<30;i++){const x=(i*47+t*20+Math.sin(t+i)*6)%W,y=(i*31+t*30)%84;P(c,x,y,1,1,'#fff');}}
  if(env==='desert'&&!night){c.globalAlpha=0.12;for(let y=58;y<66;y+=2)P(c,(Math.sin(t*6+y)*3),y,W,1,'#fff');c.globalAlpha=1;}
  if(night){c.globalAlpha=0.18;P(c,0,0,W,84,'#000');c.globalAlpha=1;}
  // map panel
  P(c,0,84,W,66,'#13182a');P(c,0,84,W,1,'#3b4b7a');
  if(rs.drag){P(c,8,108,144,6,'#7d7f87');P(c,8,117,144,6,'#7d7f87');for(const e of rs.ents){const x=8+U.clamp(e.prog/rs.tr.total,0,1)*140;P(c,x,e.lane===0?108:117,4,6,e.col);}
    c.font='7px '+GX.FONT;c.fillStyle='#cfe0ff';c.textAlign='left';c.textBaseline='top';const opp=rs.ents.find(e=>!e.isPlayer);c.fillText('YOU',8,98);if(opp)c.fillText(opp.team.slice(0,22),8,127);
    if(rs.et){c.fillStyle='#ffd84a';c.fillText(`RT ${rs.et.rt.toFixed(3)}  ET ${rs.et.et.toFixed(3)}  ${rs.et.mph} mph`,8,138);}return;}
  GX.drawTrack(c,rs.def,rs.tr,[80,117,74,28],3);const sh=GX.trackShape(rs.def,rs.tr,[80,117,74,28]);
  for(const e of rs.order.slice().reverse()){if(e.dnf&&!e.fin)continue;if(rs.tt&&!e.isPlayer&&e!==ghost)continue;const fr=rs.tr.p2p?((Math.max(0,e.prog)%rs.tr.lapLen)/rs.tr.lapLen):((Math.max(0,e.prog)%rs.tr.lapLen)/rs.tr.lapLen);const p=GX.shapeAt(sh,e.fin&&rs.tr.p2p?1:fr);
    if(e.isPlayer){const bl=Math.floor(t*4)%2;P(c,p[0]-2,p[1]-2,5,5,bl?'#fff':'#000');P(c,p[0]-1,p[1]-1,3,3,e.col);}else{P(c,p[0]-1,p[1]-1,3,3,'#000');P(c,p[0]-1,p[1]-1,2,2,e.col);}}
  if(rs.tr.hill&&rs.cond){const alt=Math.round(rs.cond.alt+(rs.cond.alt2-rs.cond.alt)*U.clamp(me.prog/rs.tr.total,0,1));c.font='7px '+GX.FONT;c.fillStyle='#cfe0ff';c.textAlign='left';c.textBaseline='top';c.fillText(`ALT ${alt} m`,4,87);}
  if(rs.telem&&rs.player.sk&&!rs.player.fin){const k=rs.player.sk[Race.secAt(rs.tr,Math.max(0,rs.player.prog))];c.font='7px '+GX.FONT;c.textAlign='right';c.textBaseline='top';
    c.fillStyle=k.kd>0.3?'#ff6060':'#8ef58e';c.fillText(`AFR ${(k.lam*14.7).toFixed(1)}${k.kd>0.3?' KNOCK':''}`,156,87);}
};
GX.mixc = (a,b,t)=>{const pa=GX.hex(a),pb=GX.hex(b);return 'rgb('+pa.map((v,i)=>Math.round(v+(pb[i]-v)*t)).join(',')+')';};
GX.hex = h=>{h=h.replace('#','');return[parseInt(h.slice(0,2),16),parseInt(h.slice(2,4),16),parseInt(h.slice(4,6),16)];};
GX.scenery = (c,env,x,i,r,t=0,night=false,drag=false)=>{const P=GX.P;
  if(env==='stadium'||drag){if(i%3!==2){P(c,x,40,40,20,'#3d4659');P(c,x,38,40,2,'#c0392b');for(let yy=42;yy<58;yy+=3)for(let xx=1;xx<40;xx+=2){const k=(xx*7+yy*3+i*11)%6;const bob=((xx+Math.floor(t*6))%5===0)?-1:0;P(c,x+xx,yy+bob,1,1,['#f5d0a9','#e74c3c','#3498db','#f1c40f','#fff','#2ecc71'][k]);}
    if(night){P(c,x+4,24,8,3,'#fffbd0');P(c,x+28,24,8,3,'#fffbd0');P(c,x+7,27,2,11,'#555');P(c,x+31,27,2,11,'#555');}P(c,x,58,40,4,'#2b3240');}
    else{P(c,x+18,22,2,40,'#555');P(c,x+14,20,10,4,night?'#fffbd0':'#ddd');P(c,x+2,46,30,10,'#fff');P(c,x+4,48,26,6,['#e74c3c','#3498db','#27ae60','#f39c12'][i%4]);const fl=Math.floor(t*5+i)%2;P(c,x+36,30,1,16,'#777');P(c,x+37,30+fl,6,4,['#e74c3c','#ffd84a','#2ecc71'][i%3]);}}
  else if(env==='country'){P(c,x,56,44,1,'#8b5a2b');for(let k=0;k<44;k+=8)P(c,x+k,52,1,8,'#8b5a2b');if(r<0.7){P(c,x+14,38,3,22,'#5d3a1a');P(c,x+6,26,19,14,'#2f7d32');P(c,x+9,22,13,6,'#3d9a40');}else{P(c,x+10,52,10,8,'#e8c35a');P(c,x+10,52,10,1,'#c9a43f');}}
  else if(env==='swamp'){P(c,x,58,44,4,'#3f5a3a');for(let k=0;k<44;k+=5)P(c,x+k,50+(k%3),1,10,'#6d8b47');if(r<0.5){P(c,x+20,30,3,30,'#4b3b2b');P(c,x+14,34,8,2,'#4b3b2b');P(c,x+22,38,7,2,'#4b3b2b');}}
  else if(env==='desert'){P(c,x-6,52,56,10,'#e7b765');P(c,x+4,48,30,4,'#e7b765');if(r<0.6){P(c,x+20,38,4,22,'#3f8f4a');P(c,x+15,44,5,3,'#3f8f4a');P(c,x+15,40,2,5,'#3f8f4a');P(c,x+24,42,5,3,'#3f8f4a');P(c,x+27,38,2,6,'#3f8f4a');}}
  else if(env==='mountain'){P(c,x,56,44,6,'#6b7d5c');const tr=(tx,h)=>{for(let k=0;k<h;k+=3){const w=Math.max(2,Math.round((k/h)*12));P(c,tx-w/2,34+(20-h)+k,w,3,'#2d5f4a');}P(c,tx-1,52,2,6,'#4a3220');};tr(x+10,18);if(r<0.5){P(c,x+24,46,12,10,'#8a8f96');P(c,x+26,44,8,3,'#a3a8ae');}else tr(x+30,14);P(c,x,54,44,1,'#c9cdd2');for(let k=0;k<44;k+=11)P(c,x+k,54,1,4,'#9aa0a6');}
  else if(env==='snow'){P(c,x,56,44,6,'#f4f8fb');const tr=(tx,h)=>{for(let k=0;k<h;k+=3){const w=Math.max(2,Math.round((k/h)*14));P(c,tx-w/2,32+(20-h)+k,w,3,'#2d5f4a');P(c,tx-w/2,32+(20-h)+k,w,1,'#fff');}P(c,tx-1,52,2,6,'#4a3220');};tr(x+12,20);if(r<0.6)tr(x+30,16);}
};
