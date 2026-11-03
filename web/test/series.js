const {chromium}=require('playwright');const path=require('path');require('fs').mkdirSync(path.resolve(__dirname,'shots'),{recursive:true});
(async()=>{
  const b=await chromium.launch();const ctx=await b.newContext({viewport:{width:390,height:844},deviceScaleFactor:2});const p=await ctx.newPage();
  const errs=[];p.on('console',m=>{if(m.type()==='error'&&!m.text().includes('ERR_FAILED'))errs.push(m.text());});p.on('pageerror',e=>errs.push('PAGEERR '+e.message));
  await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
  const url='file://'+path.resolve(__dirname,'../dist/index.html');
  await p.goto(url);await p.waitForTimeout(500);
  const shot=async n=>{await p.screenshot({path:path.resolve(__dirname,'shots',n+'.png')});};
  const closePops=async()=>{let g=0;while(await p.$('#pop:not(.hidden)')&&g++<20){await p.click('#pop .pf button:last-child');await p.waitForTimeout(80);}};
  await p.click('#tStart');await p.waitForTimeout(200);await closePops();
  await p.evaluate(()=>{const v=E.startBuild('kei','fr');G.jobs=[];E.finishBuild(v);G.races.c1a={best:1,n:1,w:1};G.races.c1b={best:1,n:1,w:1};G.money=2e6;});
  await closePops();await p.click('[data-m="race"]');await p.waitForTimeout(150);await p.click('#wtabs button[data-tab="series"]');await p.waitForTimeout(150);await shot('40_series');
  await p.click('[data-a="enterSeries"][data-sid="s1c"]');await p.waitForTimeout(150);await p.click('#pop .pf button:last-child');await p.waitForTimeout(150);
  await p.click('#wclose');await p.waitForTimeout(100);
  await p.evaluate(()=>{for(let i=0;i<8;i++)E.tick();});await p.waitForTimeout(300);await shot('41_raceday');
  await p.click('#pop .pf button');await p.waitForTimeout(250);await shot('42_series_prerace');
  await p.click('[data-a="go"]');await p.waitForTimeout(1500);await p.click('[data-r="skip"]');await p.waitForTimeout(1500);await shot('43_series_result');
  await closePops();await p.click('[data-r2="done"]');await p.waitForTimeout(200);await closePops();
  // run remaining rounds automatically
  for(let r=1;r<5;r++){await p.evaluate(()=>{for(let i=0;i<22;i++){E.tick();if(UI.paused())break;}});await p.waitForTimeout(150);
    if(await p.$('#pop:not(.hidden)')){await p.click('#pop .pf button');await p.waitForTimeout(150);}
    if(await p.$('[data-a="go"]')){await p.click('[data-a="go"]');await p.waitForTimeout(400);await p.click('[data-r="skip"]');await p.waitForTimeout(1100);if(r===4)await shot('44_final_round');await closePops();await p.click('[data-r2="done"]');await p.waitForTimeout(200);}
    else if(await p.$('[data-a="skipRound"]')){await p.evaluate(()=>{E.seriesRoundSkip(UI.sel.sid);UI.view=null;document.getElementById('ov').classList.add('hidden');});}
    if(r===4){await p.waitForTimeout(200);await shot('45_champ');}
    await closePops();}
  await closePops();await p.click('[data-m="team"]');await p.waitForTimeout(150);await shot('46_team');await p.click('#wclose');
  // year end
  await p.evaluate(()=>{G.day=D.DAYS_YEAR-1;E.tick();});await p.waitForTimeout(200);await shot('47_yearend');await closePops();
  // reload -> continue
  await p.evaluate(()=>Save.save(true));await p.reload();await p.waitForTimeout(600);await shot('48_reload');
  await p.click('#tCont');await p.waitForTimeout(300);await shot('49_continued');
  console.log('state',await p.evaluate(()=>JSON.stringify({day:G.day,titles:G.st.titles,ws:G.ws,money:G.money})));
  console.log('ERRORS:',errs.length?errs.join('\n'):'none');await b.close();})();
