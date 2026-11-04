// Engineering & formats test: carb/EFI benches, sync, setup, drag/hill/heats flows, test day.
const {chromium}=require('playwright');const path=require('path');require('fs').mkdirSync(path.resolve(__dirname,'shots'),{recursive:true});
(async()=>{
  const b=await chromium.launch();const p=await b.newPage({viewport:{width:390,height:844},deviceScaleFactor:2});
  const errs=[];p.on('console',m=>{if(m.type()==='error'&&!m.text().includes('ERR_FAILED'))errs.push(m.text());});p.on('pageerror',e=>errs.push('PAGEERR '+e.message+' '+(e.stack||'').split('\n')[1]));
  await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
  await p.goto('file://'+path.resolve(__dirname,'../dist/index.html'));await p.waitForTimeout(400);
  const shot=async n=>{await p.screenshot({path:path.resolve(__dirname,'shots',n+'.png')});};
  const closePops=async()=>{let g=0;while(await p.$('#pop:not(.hidden)')&&g++<30){await p.click('#pop .pf button:last-child');await p.waitForTimeout(60);}};
  await p.click('#tStart');await p.waitForTimeout(150);await closePops();
  await p.evaluate(()=>{G.money=5e7;G.rp=9000;G.ws=4;for(const t of D.TECH)G.tech[t.id]=1;delete G.tech.wideband;delete G.tech.syncgauge;
    for(const id in D.BODY)G.res.body[id]=1;for(const id in D.LAYOUT)G.res.layout[id]=1;
    for(let i=0;i<6;i++)G.staff.push(E.genStaff('mec',6));G.staff.push(E.genStaff('drv',6));G.staff.push(E.genStaff('drv',6));
    const mk=(bid,lid,sys)=>{const v=E.startBuild(bid,lid,null,sys);UI.popQ=[];G.jobs=G.jobs.filter(j=>j.vid!==v.id);E.finishBuild(v);return v;};
    window.V={tri:mk('ss600','triple',{type:'carb',carb:'cv'}),i4:mk('sbk','inline4',{type:'carb',carb:'cv'}),pe:mk('dirt250','single',{type:'carb',carb:'pe'}),
      q4:mk('coupe','fr',{type:'carb',carb:'q4'}),dc:mk('rallycoupe','awd',{type:'carb',carb:'dcoe'}),efi:mk('mx450','single',{type:'efi'}),fcr:mk('mx250f','stroke2',{type:'carb',carb:'fcr'})};
    E.buildFac('dyno');});
  await closePops();
  const openV=async(key,tab,n)=>{await p.evaluate(([k,t])=>{UI.open('garage',t,{vid:V[k].id});},[key,tab]);await p.waitForTimeout(700);await shot(n);};
  await openV('pe','fuel','50_carb_pe_nowb');
  await p.click('[data-a="sweep"]');await p.waitForTimeout(1200);await shot('51_carb_sweep');
  await p.evaluate(()=>{G.tech.wideband=1;G.tech.syncgauge=1;});await openV('i4','fuel','52_carb_cv_i4');
  await p.evaluate(()=>{document.getElementById('syncCv').scrollIntoView();});await p.waitForTimeout(500);await shot('53_sync');
  await p.click('[data-a="syncAdj"][data-i="0"][data-dir="1"]');await p.waitForTimeout(200);
  await openV('q4','fuel','54_carb_4bbl');await p.click('[data-a="snap"]');await p.waitForTimeout(300);await shot('55_4bbl_snap');
  await openV('dc','fuel','56_dcoe');
  await openV('fcr','fuel','57_fcr');
  await openV('efi','fuel','58_efi_ve');
  await p.click('.vegrid .cell[data-j="5"][data-i="5"]');await p.click('[data-a="selRow"]');await p.click('[data-a="cadj"][data-v="5%"]');await p.waitForTimeout(200);await shot('59_efi_edit');
  await p.click('[data-a="etab"][data-v="dyno"]');await p.waitForTimeout(200);await p.click('[data-a="dynoRun"]');await p.waitForTimeout(2500);await shot('60_dyno');await p.waitForTimeout(2500);
  await p.click('[data-a="etab"][data-v="ve"]');await p.waitForTimeout(300);await shot('61_efi_log');
  await p.click('[data-a="veal"]');await p.waitForTimeout(300);await closePops();await shot('62_veal');
  await p.click('[data-a="etab"][data-v="ign"]');await p.waitForTimeout(200);await shot('63_spark');
  await openV('tri','setup','64_setup');await openV('tri','engine','65_engine');
  await p.evaluate(()=>UI.close());await closePops();
  await p.evaluate(()=>UI.open('research','tech'));await p.waitForTimeout(300);await shot('66_tech');await p.evaluate(()=>UI.close());
  await p.evaluate(()=>UI.open('team','awards'));await p.waitForTimeout(300);await shot('67_awards');await p.evaluate(()=>UI.close());
  // hillclimb prerace & run
  await p.evaluate(()=>{V.tri.upAdd={spd:700,acc:700,hnd:700,dur:1200};V.i4.upAdd={spd:700,acc:700,hnd:700,dur:1200};V.efi.upAdd={spd:700,acc:700,hnd:700,dur:1200};G.races.h1a={best:1,n:1,w:1};G.races.h1b={best:1,n:1,w:1};UI.open('prerace',null,{rid:'h4b',vid:V.tri.id});});await p.waitForTimeout(400);await shot('68_prerace_hill');
  await p.click('[data-a="go"]');await p.waitForTimeout(3000);await shot('69_hill_run');await p.click('[data-r="skip"]');await p.waitForTimeout(1500);await shot('70_hill_r1');
  await p.click('[data-rb="1"]');await p.waitForTimeout(500);await shot('71_retune');
  await p.click('[data-a="resume"]');await p.waitForTimeout(1200);await p.click('[data-r="skip"]');await p.waitForTimeout(1500);await shot('72_hill_r2');
  await p.click('[data-rb="0"]');await p.waitForTimeout(500);await shot('73_hill_final');await p.click('[data-r2="done"]');await p.waitForTimeout(300);await closePops();
  // drag
  await p.evaluate(()=>{UI.open('prerace',null,{rid:'r4b',vid:V.i4.id});});await p.waitForTimeout(300);await p.click('[data-a="go"]');await p.waitForTimeout(1200);await shot('74_drag_tree');await p.waitForTimeout(3500);await shot('75_drag_run');
  for(let k=0;k<4;k++){const sk=await p.$('[data-r="skip"]');if(sk&&await sk.isVisible())await sk.click().catch(()=>{});await p.waitForTimeout(1600);const rb=await p.$('[data-rb="0"]');if(rb&&await rb.isVisible()){await shot('76_drag_panel_'+k);await rb.click();await p.waitForTimeout(600);}const d=await p.$('[data-r2="done"]');if(d&&await d.isVisible()){await shot('77_drag_result');await d.click();break;}}
  await closePops();
  // heats + main
  await p.evaluate(()=>{UI.open('prerace',null,{rid:'d4a',vid:V.efi.id,fmt:'heats'});});await p.waitForTimeout(300);await shot('78_prerace_heats');await p.click('[data-a="go"]');await p.waitForTimeout(1500);await p.click('[data-r="skip"]');await p.waitForTimeout(1500);await shot('79_heat_panel');
  await p.click('[data-rb="0"]');await p.waitForTimeout(2000);await shot('80_main');await p.click('[data-r="skip"]');await p.waitForTimeout(1500);await shot('81_main_result');await p.click('[data-r2="done"]');await closePops();
  // night race
  await p.evaluate(()=>{const v=G.vehicles.find(x=>x.status==='ready'&&D.BODY[x.body].cls==='car');UI.startRace(D.RACE.c3c,v,E.drivers()[0],'normal',null,'sprint');});await p.waitForTimeout(2500);await shot('82_night');
  await p.evaluate(()=>Race.runInstant(UI.race));await p.waitForTimeout(1200);await p.click('[data-r2="done"]');await closePops();
  // test day
  await p.evaluate(()=>{UI.open('test');UI.sel.tvid=V.pe.id;});await p.waitForTimeout(300);await shot('83_testday');await p.click('[data-a="tGo"]');await p.waitForTimeout(2500);await shot('84_test_run');
  await p.click('[data-r="skip"]');await p.waitForTimeout(1500);await shot('85_test_result');
  // lean engine damage check: lean the pe out badly and race
  const dmg=await p.evaluate(()=>{const v=V.fcr;v.status='ready';v.eng.jets.main=150;v.eng.timing=6;const r=D.RACE.d4c;const rs=Race.create(r,{vid:v.id,sid:E.drivers()[0].id,tactic:'push'},{});Race.runInstant(rs);return {cond:rs.player.cond,holed:!!rs.player.holed,seized:!!rs.player.seized,msgs:rs.msgs.map(m=>m.text).slice(-6)};});
  console.log('lean test',JSON.stringify(dmg));
  console.log('ERRORS:',errs.length?[...new Set(errs)].join('\n'):'none');await b.close();})();
