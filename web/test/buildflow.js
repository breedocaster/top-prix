// Staged build flow: choices, events, garage visuals, build sheet.
const {chromium}=require('playwright');const path=require('path');require('fs').mkdirSync(path.resolve(__dirname,'shots'),{recursive:true});
(async()=>{
  const b=await chromium.launch();const p=await b.newPage({viewport:{width:390,height:844},deviceScaleFactor:2});
  const errs=[];p.on('pageerror',e=>errs.push('PAGEERR '+e.message+' '+(e.stack||'').split('\n')[1]));p.on('console',m=>{if(m.type()==='error'&&!m.text().includes('ERR_FAILED'))errs.push(m.text());});
  await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
  await p.goto('file://'+path.resolve(__dirname,'../dist/index.html'));await p.waitForTimeout(400);
  const shot=async n=>{await p.screenshot({path:path.resolve(__dirname,'shots',n+'.png')});};
  const closePops=async()=>{let g=0;while(await p.$('#pop:not(.hidden)')&&g++<30){await p.click('#pop .pf button:last-child');await p.waitForTimeout(60);}};
  await p.click('#tStart');await p.waitForTimeout(150);await closePops();
  await p.evaluate(()=>{G.money=3e6;E.buildFac('dyno');});await closePops();
  await p.click('[data-m="build"]');await p.click('[data-a="selB"][data-v="kei"]');await p.click('[data-a="selL"][data-v="fr"]');await p.click('[data-a="pickSys"]');await p.waitForTimeout(150);await shot('90_confirm');
  await p.click('[data-a="doBuild"]');await p.waitForTimeout(300);await shot('91_design_choice');
  // pick option 2 (accel concept) then let time run & answer choices with first enabled option
  let n=0;const seen=[];
  await p.click('#pop .pf button[data-i="2"]');await p.waitForTimeout(200);
  await p.evaluate(()=>{G.settings.speed=4;});
  for(let k=0;k<80&&n<14;k++){await p.waitForTimeout(400);
    if(await p.$('#pop:not(.hidden)')){const t=await p.$eval('#pop .ph',e=>e.textContent);seen.push(t);await shot('92_pop_'+n);
      const bs=await p.$$('#pop .pf button:not([disabled])');await bs[Math.min(1,bs.length-1)].click();n++;await p.waitForTimeout(150);}
    if(n===3&&!seen.includes('scene')){seen.push('scene');await shot('93_scene_mid');await p.click('[data-m="garage"]');await p.click('[data-a="selVeh"]');await p.waitForTimeout(250);await shot('94_build_sheet');await p.click('#wclose');}
    const done=await p.evaluate(()=>G.vehicles[0]&&G.vehicles[0].status==='ready');if(done)break;}
  await closePops();await shot('95_done');
  const v=await p.evaluate(()=>{const v=G.vehicles[0];return {status:v.status,base:v.base,bm:v.bm,blog:v.blog,flags:v.bflags,slots:E.slots(v)};});
  console.log('popups:',seen.join(' | '));console.log('vehicle',JSON.stringify(v));
  console.log('ERRORS:',errs.length?[...new Set(errs)].join('\n'):'none');await b.close();})();
