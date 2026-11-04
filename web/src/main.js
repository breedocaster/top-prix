// ===================== SOUND =====================
const SFX = {ctx:null};
SFX.init = ()=>{if(SFX.ctx)return;try{SFX.ctx=new (window.AudioContext||window.webkitAudioContext)();}catch(e){SFX.ctx=null;}};
SFX.tone = (f,d,type='square',vol=0.05,delay=0)=>{const c=SFX.ctx;if(!c)return;try{const o=c.createOscillator(),g=c.createGain();o.type=type;o.frequency.value=f;
  const t=c.currentTime+delay;g.gain.setValueAtTime(vol,t);g.gain.exponentialRampToValueAtTime(0.0001,t+d);o.connect(g);g.connect(c.destination);o.start(t);o.stop(t+d+0.02);}catch(e){}};
SFX.play = n=>{if(!G||!G.settings.sound||!SFX.ctx)return;
  switch(n){case 'click':SFX.tone(880,0.04,'square',0.03);break;
    case 'good':SFX.tone(660,0.08);SFX.tone(990,0.12,'square',0.05,0.08);break;
    case 'fanfare':[523,659,784,1047].forEach((f,i)=>SFX.tone(f,0.14,'square',0.05,i*0.1));break;
    case 'crash':SFX.tone(120,0.3,'sawtooth',0.07);SFX.tone(80,0.4,'square',0.05,0.05);break;
    case 'bump':SFX.tone(160,0.08,'square',0.04);break;
    case 'spark':[880,1175,1568].forEach((f,i)=>SFX.tone(f,0.1,'triangle',0.06,i*0.06));break;
    case 'start':[440,440,440,880].forEach((f,i)=>SFX.tone(f,i<3?0.12:0.3,'square',0.05,i*0.35));break;}};

// ===================== SAVE =====================
const Save = {KEY:'gridgravel_v1',ref:null,busy:false,pending:null,last:0,cloud:'connecting'};
Save.local = ()=>{try{const s=localStorage.getItem(Save.KEY);return s?JSON.parse(s):null;}catch(e){return null;}};
Save.save = (force)=>{if(!G)return;G.savedAt=Date.now();const s=E.serialize();try{localStorage.setItem(Save.KEY,s);}catch(e){}Save.toCloud(s,force);};
Save.toCloud = async (s,force)=>{if(!Save.ref)return;if(Save.busy||(!force&&Date.now()-Save.last<45000)){Save.pending=s;return;}
  Save.busy=true;Save.pending=null;try{await Save.ref.set({json:s,savedAt:G.savedAt,team:G.team.name,date:E.dateStr()});Save.last=Date.now();Save.cloud='ok';}
  catch(e){if(e&&e.code==='quota_exceeded')Save.cloud='full';else if(e&&(e.code==='invalid_argument'||e.code==='revoked'||e.code==='not_granted'))Save.ref=null,Save.cloud='off';else Save.cloud='err';}
  Save.busy=false;};
Save.flush = ()=>{if(Save.pending&&Save.ref&&!Save.busy&&Date.now()-Save.last>=45000)Save.toCloud(Save.pending,true);};
Save.status = ()=>{const c={ok:'☁ Synced to your account',connecting:'☁ Connecting to cloud save…',off:'Cloud save unavailable here — saved on this device only',err:'☁ Cloud save hiccup — will retry',full:'☁ Cloud storage full'}[Save.cloud];
  return `Autosaves monthly on this device. ${c}${Save.last?` (last ${new Date(Save.last).toLocaleTimeString()})`:''}`;};
Save.b64e = s=>btoa(unescape(encodeURIComponent(s)));Save.b64d = s=>decodeURIComponent(escape(atob(s)));
Save.exportCode = ()=>{G.savedAt=Date.now();return 'GG1:'+Save.b64e(E.serialize());};
Save.importCode = code=>{const s=Save.b64d(code.replace(/^GG1:/,'').replace(/\s+/g,''));E.load(s);GX.S.actors={};Main.started();Save.save(true);};
Save.initCloud = async ()=>{
  try{if(!window.claude||!window.claude.use){Save.cloud='off';return;}
    const [user,db]=await Promise.all([window.claude.use('user'),window.claude.use('db')]);
    if(!user||!db){Save.cloud='off';return;}const id=await user.id();if(!id){Save.cloud='off';return;}
    Save.ref=db.doc('data/users/'+id+'/save');
    const snap=await Promise.race([Save.ref.get(),new Promise((_,rj)=>setTimeout(()=>rj({code:'timeout'}),10000))]);
    Save.cloud='ok';
    if(snap&&snap.exists){const d=snap.data();const loc=Save.local();
      if(d&&d.json&&(!loc||(d.savedAt||0)>(loc.savedAt||0)+5000)){
        if(Main.onTitle){E.load(d.json);try{localStorage.setItem(Save.KEY,d.json);}catch(e){}Main.title(false);UI.toast('Cloud save found!');}
        else UI.popup({title:'Cloud save found',html:`A newer save for <b>${U.esc(d.team||'your team')}</b> (${U.esc(d.date||'')}) is in your account. Load it?`,
          buttons:[{t:'Keep current',cls:'gray',fn:()=>Save.save(true)},{t:'Load cloud',cls:'blue',fn:()=>{E.load(d.json);GX.S.actors={};Main.started();Save.save();}}]});}}
    else if(G&&!Main.onTitle)Save.save(true);
  }catch(e){Save.cloud=e&&e.code==='timeout'?'err':'off';}
};

// ===================== MAIN =====================
const Main = {last:0,acc:0,DAY_MS:1000,onTitle:true,hudT:0,flushT:0,newColor:D.TEAM_COLORS[0],newMode:'standard'};
Main.started = ()=>{Main.onTitle=false;$('title').classList.add('hidden');UI.hud();if(G&&!G.seenV2&&G.st.races>0){G.seenV2=1;UI.popup({title:'🔧 New in the garage!',html:'<b>Engineering update:</b><br>• Carbs (jets, needle clip, screws, float level, pumps) & multi-carb sync<br>• EFI laptop tuning: VE / spark / AFR tables, dyno pulls, VE Analyze<br>• Altitude & temperature change your mixture — hillclimbs climb into thin air<br>• Drag strips & hillclimbs, heats + main, feature & endurance lengths, test days<br>• Setup sheet: gearing, suspension, tire pressure, wing<br>• Tech tree, achievements, and difficulty (Team → Settings)<br><br>Your vehicles got stock carbs — check their <b>Carbs</b> tab!'});}else if(G)G.seenV2=1;};
Main.title = (forceNew)=>{
  Main.onTitle=true;$('title').classList.remove('hidden');const loc=forceNew?null:(G||Save.local());
  let h='';
  if(loc&&!forceNew){h=`<button class="btn big grn" id="tCont" style="max-width:320px">▶ Continue — ${U.esc(loc.team.name)}<br><span style="font-size:12px">${E.dateStr(loc.day)} · ${U.num(loc.fans)} fans</span></button>
    <button class="btn blue" id="tNew">New team</button>`;}
  else{h=`<input id="tName" maxlength="22" placeholder="Team name" value="${forceNew&&G?U.esc(G.team.name):'Greenlight Racing'}">
    <div class="colors">${D.TEAM_COLORS.map(c=>`<button data-c="${c}" style="background:${c}" class="${c===Main.newColor?'on':''}"></button>`).join('')}</div>
    <div class="modes">${Object.entries(D.MODES).map(([k,m])=>`<button data-mode="${k}" class="${k===Main.newMode?'on':''}">${m.n}</button>`).join('')}</div><div class="tag" id="modeDesc">${D.MODES[Main.newMode].d}</div>
    <button class="btn big grn" id="tStart" style="max-width:320px">🏁 Start your team!</button>${loc||G?'<button class="btn gray" id="tBack">Back</button>':''}`;}
  $('tbox').innerHTML=h;
  if($('tCont'))$('tCont').onclick=()=>{SFX.init();if(!G||G!==loc)E.load(loc);GX.S.actors={};Main.started();Save.save();};
  if($('tNew'))$('tNew').onclick=()=>Main.title(true);
  if($('tBack'))$('tBack').onclick=()=>Main.title(false);
  $('tbox').querySelectorAll('[data-c]').forEach(b=>b.onclick=()=>{Main.newColor=b.dataset.c;$('tbox').querySelectorAll('[data-c]').forEach(x=>x.classList.toggle('on',x===b));});
  $('tbox').querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>{Main.newMode=b.dataset.mode;$('tbox').querySelectorAll('[data-mode]').forEach(x=>x.classList.toggle('on',x===b));$('modeDesc').textContent=D.MODES[Main.newMode].d;});
  if($('tStart'))$('tStart').onclick=()=>{SFX.init();E.newGame($('tName').value.trim()||'Greenlight Racing',Main.newColor,Main.newMode);GX.S.actors={};GX._th={};Main.started();Save.save(true);Main.tutorial();};
};
Main.tutorial = ()=>{
  UI.popup({title:'Welcome, Boss! 🏁',html:`You just opened <b>${U.esc(G.team.name)}</b> in a backyard shed with one driver and two mechanics.<br><br>Your goal: climb from local dirt dashes to <b>world championships</b> — on four wheels <i>and</i> two, on tarmac <i>and</i> dirt.`});
  UI.popup({title:'Step 1: Build 🔧',html:`Tap <b>🔧 Build</b> and pick a <b>Kei Hatch</b> (car) or <b>Commuter 125</b> (bike).<br><br>Your mechanics' <b>Tech</b> decides how well it turns out. Bigger, better vehicles unlock through <b>🔬 Research</b>.`});
  UI.popup({title:'Step 2: Race 🏁',html:`When it's ready, open <b>🏁 Races</b>. Match the vehicle to the surface — a road car on mud is a bad day!<br><br>Win normal races → unlock a <b>Series</b> → win it → move to a bigger <b>workshop</b>.`});
  UI.popup({title:'Under the hood 🔧',html:`Every engine runs <b>carbs</b> (later <b>EFI</b>). Jets, needle clip, screws and float level set the air/fuel mix — and altitude & temperature shift it. Too lean or too much timing and you can <b>hole a piston</b>${G.settings.mode==='easy'?' (not on Easy — your crew tunes for you)':''}.<br><br>Open a vehicle in <b>🚗 Garage</b> → <b>Carbs</b> to tune. Change difficulty any time in Team → Settings.`});
  UI.popup({title:'Step 3: Grow 📈',html:`Races earn money, <b>Research Data (RP)</b> and <b>fans</b>. Fans attract <b>💼 Sponsors</b>, whose goals unlock training, parts and special machines.<br><br>Time only runs when no menu is open. Use ▶▶ to speed up. Good luck!`});
};
Main.hooks = ()=>{
  E.H.toast=t=>UI.toast(t);E.H.popup=o=>{if(UI.race)UI.deferPop.push(o);else UI.popup(o);};E.H.float=(t,vid,col)=>GX.floatAtVeh(t,vid,col);E.H.sfx=n=>SFX.play(n);
  E.H.buildAsk=j=>UI.buildAsk(j);
  E.H.roundDue=sid=>{const S=D.SER[sid],a=G.series[sid].act;const r=D.RACE[S.rounds[a.round]];Save.save();
    UI.popup({title:'🏁 Race Day!',html:`<b>${U.esc(S.n)}</b> — Round ${a.round+1}/${S.rounds.length}<br><span class="hl">${U.esc(r.n)}</span><br><br>Choose who races.`,buttons:[{t:"Let's go!",cls:'grn',fn:()=>{UI.open('prerace',null,{rid:r.id,sid});}}]});};
  E.H.yearEnd=({y,yr,bonus,rank})=>{Save.save(true);UI.popup({title:`📅 Year ${y} Report`,html:`Wins <b>${yr.wins}</b> · Podiums <b>${yr.podiums}</b> · Titles <b>${yr.titles}</b><br>Prize money ${U.money(yr.earn)}<br>Team rank: <b class="hl">${D.FAN_RANKS[rank][1]}</b> (${U.num(G.fans)} fans)<br><br>Fan-club bonus: <b class="gd">+${U.money(bonus)}</b>${y<D.YEARS?`<br><br>${D.YEARS-y} seasons to go!`:''}`});};
  E.H.gameEnd=score=>{UI.popup({title:'🏆 15 Seasons Complete!',html:`<div class="big">Score ${U.num(score)}</div>Titles: ${G.st.titles.length} · Wins: ${G.st.wins} · Fans: ${U.num(G.fans)}<br><br>${G.st.titles.some(t=>D.SER[t].tier===5)?'A true <b>Legend</b> of the sport!':G.st.titles.some(t=>D.SER[t].tier===4)?'World champions! Can you conquer the Legend series?':'A solid career. Keep racing — the season never ends!'}<br><br>You can keep playing as long as you like.`});};
};
Main.frame = (ts)=>{
  const dt=Math.min(0.1,(ts-(Main.last||ts))/1000);Main.last=ts;
  try{
    if(Main.onTitle)Main.drawTitle(dt);
    else if(G){
      if(UI.race)UI.raceFrame(dt);
      else{
        if(!UI.paused()&&G.settings.speed>0){Main.acc+=dt*1000*G.settings.speed;
          while(Main.acc>=Main.DAY_MS){Main.acc-=Main.DAY_MS;E.tick();if(G.day%D.DAYS_MONTH===0)Save.save();if(UI.paused()){Main.acc=0;break;}}}
        else Main.acc=Math.min(Main.acc,Main.DAY_MS*0.9);
        const c=$('scene').getContext('2d');c.setTransform(3,0,0,3,0,0);GX.drawScene(c,dt);UI.benchFrame(dt);
        Main.hudT+=dt;if(Main.hudT>0.25){Main.hudT=0;UI.hud();}
      }
      Main.flushT+=dt;if(Main.flushT>15){Main.flushT=0;Save.flush();}
    }
  }catch(e){console.error(e);}
  requestAnimationFrame(Main.frame);
};
Main.tt=0;
Main.drawTitle = (dt)=>{Main.tt+=dt;const cv=$('tcv');const c=cv.getContext('2d');c.setTransform(3,0,0,3,0,0);c.imageSmoothingEnabled=false;const P=GX.P,t=Main.tt;
  for(let i=0;i<6;i++)P(c,0,i*7,200,7,GX.mixc('#f09a4c','#fde0a6',i/5));
  for(let x=0;x<200;x+=2){const h=8+5*Math.sin((x+t*10)*0.04)+3*Math.sin((x+t*10)*0.09);P(c,x,40-h,2,h+4,'#a35f3a');}
  P(c,0,40,100,20,'#7d7f87');P(c,100,40,100,20,'#a2683a');for(let x=0;x<100;x+=12)P(c,(x-t*60)%100<0?(x-t*60)%100+100:(x-t*60)%100,49,6,1,'#ddd');
  for(let x=100;x<200;x+=7)P(c,100+((x*13-t*60)%100+100)%100,43+(x*7)%15,1,1,'#7a4a24');
  const bob=Math.sin(t*6)*0.6;GX.drawVeh(c,'gt',30+Math.sin(t*0.8)*6,55,Main.newColor||'#e8432f','#ffd84a',Math.floor(t*12)%2);
  const air=Math.max(0,Math.sin(t*1.4))*6;GX.drawVeh(c,'mx',140+Math.sin(t*0.9)*5,55-air+bob,'#2f7de8','#fff',Math.floor(t*12)%2);
  for(let i=0;i<5;i++)P(c,130-i*5-((t*30)%5),52+((i*7)%4),2,2,'#c9a07a');};

Main.boot = ()=>{
  Main.hooks();
  const s=$('scene');s.width=480;s.height=360;const r=$('rcv');r.width=480;r.height=450;const tc=$('tcv');tc.width=600;tc.height=180;
  $('menu').addEventListener('click',e=>{const b=e.target.closest('[data-m]');if(!b||!G)return;SFX.init();const m=b.dataset.m;
    if(m==='race')UI.open('race','races');else if(m==='build')UI.open('build','car');else UI.open(m);});
  $('ov').addEventListener('click',e=>{if(e.target===$('ov'))UI.close();});
  $('wbody').addEventListener('click',UI.click);$('wbody').addEventListener('input',e=>{if(e.target.id==='thrSl'){Bench.s.thr=+e.target.value/100;Bench.s.sweep=false;}});$('wback').addEventListener('click',UI.click);$('wtabs').addEventListener('click',UI.click);
  $('wclose').addEventListener('click',()=>{SFX.play('click');UI.close();});
  $('rCtl').addEventListener('click',UI.raceClick);
  $('nextbar').addEventListener('click',()=>{if(!G)return;const act=Object.values(G.series).some(s=>s.act);UI.open('race',act?'series':'races');});
  document.querySelectorAll('#top .sp button').forEach(b=>b.addEventListener('click',()=>{SFX.init();if(!G)return;const v=b.dataset.s;G.settings.speed=v==='f'?(G.settings.speed===2?4:2):+v;UI.hud();}));
  $('scene').addEventListener('click',e=>{if(!G||UI.view)return;const rc=$('scene').getBoundingClientRect();const x=(e.clientX-rc.left)/rc.width*160,y=(e.clientY-rc.top)/rc.height*120;
    if(y<31&&y>12){UI.open('facility');return;}const bays=GX.bays();for(let i=0;i<G.vehicles.length;i++){const b=bays[i];if(b&&x>=b.x&&x<=b.x+b.w&&y>=b.gy-28&&y<=b.gy+4){UI.open('garage','info',{vid:G.vehicles[i].id});return;}}});
  document.addEventListener('pointerdown',()=>SFX.init(),{once:true});
  document.addEventListener('visibilitychange',()=>{if(document.hidden&&G&&!Main.onTitle)Save.save(true);});
  const loc=Save.local();if(loc){try{E.load(loc);}catch(e){G=null;}}
  Main.title(false);
  requestAnimationFrame(Main.frame);
  Save.initCloud();
  if(document.fonts&&document.fonts.load)document.fonts.load('10px "DotGothic16"').then(()=>{GX._th={};}).catch(()=>{});
};
window.addEventListener('DOMContentLoaded',Main.boot);
