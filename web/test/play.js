// UI smoke test: mobile viewport, clicks through main flows, screenshots, console errors.
const {chromium}=require('playwright');const path=require('path');require('fs').mkdirSync(path.resolve(__dirname,'shots'),{recursive:true});
(async()=>{
  const b=await chromium.launch();const p=await b.newPage({viewport:{width:390,height:844},deviceScaleFactor:2});
  const errs=[];p.on('console',m=>{if(m.type()==='error')errs.push(m.text());});p.on('pageerror',e=>errs.push('PAGEERR '+e.message));
  await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
  await p.goto('file://'+path.resolve(__dirname,'../dist/index.html'));await p.waitForTimeout(600);
  const closePops=async()=>{let g=0;while(await p.$('#pop:not(.hidden)')&&g++<20){await p.click('#pop .pf button:last-child');await p.waitForTimeout(80);}};
  const shot=async n=>{await p.screenshot({path:path.resolve(__dirname,'shots',n+'.png')});};
  await shot('01_title');
  await p.click('#tStart');await p.waitForTimeout(300);await shot('02_tutorial');
  while(await p.$('#pop:not(.hidden)')){await p.click('#pop .pf button');await p.waitForTimeout(100);}
  await shot('03_main');
  await closePops();await p.click('[data-m="build"]');await p.waitForTimeout(200);await shot('04_build');
  await p.click('[data-a="selB"][data-v="kei"]');await p.waitForTimeout(150);await shot('05_layout');
  await p.click('[data-a="selL"][data-v="fr"]');await p.waitForTimeout(150);await shot('06a_sys');await p.click('[data-a="pickSys"]');await p.waitForTimeout(150);await shot('06_confirm');
  await p.click('[data-a="doBuild"]');await p.waitForTimeout(200);await closePops();
  await p.click('#top .sp button[data-s="f"]');
  await p.waitForTimeout(2500);await shot('07_building');
  // fast forward
  await p.evaluate(()=>{for(let i=0;i<80&&G.vehicles[0].status!=='ready';i++){E.tick();const j=E.bJob(G.vehicles[0].id);if(j&&j.wait)E.bChoose(G.vehicles[0].id,'crew');}});await p.waitForTimeout(300);await shot('08_built');
  await closePops();await p.click('[data-m="race"]');await p.waitForTimeout(200);await shot('09_races');
  await closePops();await p.click('[data-a="pick"][data-rid="c1a"]');await p.waitForTimeout(250);await shot('10_prerace');
  await closePops();await p.click('[data-a="go"]');await p.waitForTimeout(3000);await shot('11_race');
  await p.click('[data-r="spd"][data-v="4"]');await p.waitForTimeout(4000);await shot('12_race2');
  await p.click('[data-r="skip"]');await p.waitForTimeout(1500);await shot('13_result');
  await closePops();await p.click('[data-r2="done"]');await p.waitForTimeout(400);
  while(await p.$('#pop:not(.hidden)')){await p.click('#pop .pf button:last-child');await p.waitForTimeout(100);}
  for(const m of['garage','research','staff','sponsors','facility','team']){await closePops();await p.click(`[data-m="${m}"]`);await p.waitForTimeout(200);await shot('20_'+m);
    const tabs=await p.$$('#wtabs button');for(let i=1;i<tabs.length;i++){await (await p.$$('#wtabs button'))[i].click();await p.waitForTimeout(150);await shot(`21_${m}_${i}`);}
    await p.click('#wclose');await p.waitForTimeout(100);while(await p.$('#pop:not(.hidden)')){await p.click('#pop .pf button:last-child');await p.waitForTimeout(100);}}
  // vehicle detail
  await closePops();await p.click('[data-m="garage"]');await p.waitForTimeout(150);await p.click('[data-a="selVeh"]');await p.waitForTimeout(150);await shot('22_vehicle');
  const tabs=await p.$$('#wtabs button');await tabs[1].click();await p.waitForTimeout(100);await shot('23_tune');await (await p.$$('#wtabs button'))[2].click();await p.waitForTimeout(100);await shot('24_parts');
  await p.click('#wclose');
  // simulate long play with a bigger garage to view later-tier scene
  await p.evaluate(()=>{G.ws=3;G.money=5e6;G.rp=3000;for(const id of['coupe','rallycoupe','mx250f','ss600'])G.res.body[id]=1;
    for(const id of['coupe','rallycoupe','mx250f','ss600']){E.startBuild(id,D.BODY[id].cls==='car'?'fr':'twin');}
    for(let i=0;i<4;i++)G.staff.push(E.genStaff('mec',4));E.buildFac('dyno');E.buildFac('gym');E.buildFac('lounge');for(let i=0;i<6;i++)E.tick();});
  await p.waitForTimeout(1500);await shot('30_ws3');
  await p.evaluate(()=>{G.ws=4;for(let i=0;i<30;i++)E.tick();});await p.waitForTimeout(1200);
  while(await p.$('#pop:not(.hidden)')){await p.click('#pop .pf button:last-child');await p.waitForTimeout(100);}
  await shot('31_ws4');
  // off-road race view
  await p.evaluate(()=>{const v=G.vehicles.find(v=>v.body==='mx250f'&&v.status==='ready')||G.vehicles.find(v=>v.status==='ready');UI.startRace(D.RACE['d2x2'],v,E.drivers()[0],'normal',null);});
  await p.waitForTimeout(2500);await shot('32_race_sand');
  await p.evaluate(()=>{Race.runInstant(UI.race);});await p.waitForTimeout(1200);await closePops();await p.click('[data-r2="done"]');
  await p.evaluate(()=>{const v=G.vehicles.find(v=>v.status==='ready');G.wxRain=true;UI.startRace(D.RACE['o2c'],v,E.drivers()[0],'push',null);});
  await p.waitForTimeout(2500);await shot('33_race_snow');
  console.log('ERRORS:',errs.length?errs.join('\n'):'none');
  await b.close();
})();
