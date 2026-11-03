const {chromium}=require('playwright');const path=require('path');
(async()=>{
  const b=await chromium.launch();const p=await b.newPage({viewport:{width:390,height:844}});
  const errs=[];p.on('pageerror',e=>errs.push('PAGEERR '+e.message+'\n'+e.stack));p.on('console',m=>{if(m.type()==='error'&&!m.text().includes('ERR_FAILED'))errs.push(m.text());});
  await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
  await p.goto('file://'+path.resolve(__dirname,'../dist/index.html'));await p.waitForTimeout(400);
  await p.click('#tStart');await p.waitForTimeout(100);
  await p.evaluate(()=>{G.money=5e7;G.rp=5000;G.fans=30000;G.ws=3;G.sparks={b:5,s:5,g:5};for(const k in G.unl)for(const id of Object.keys(D[{body:'BODY',layout:'LAYOUT',part:'PART',train:'TRAIN',fac:'FAC'}[k]]))G.unl[k][id]=1;
    for(let i=0;i<4;i++)G.staff.push(E.genStaff('mec',5));G.staff.push(E.genStaff('drv',5));});
  const menus=['race','build','garage','research','staff','sponsors','facility','team'];
  let clicks=0;
  for(let it=0;it<500;it++){
    try{
      if(await p.$('#race:not(.hidden)')){const rr=await p.$('[data-r2="done"]');if(rr&&await rr.isVisible()){await rr.click();}else{const bs=await p.$$('#rCtl button');const bb=bs[Math.floor(Math.random()*bs.length)];if(bb&&Math.random()<0.5)await bb.click({timeout:500}).catch(()=>{});else await p.waitForTimeout(150);}continue;}
      if(await p.$('#pop:not(.hidden)')){const bs=await p.$$('#pop .pf button');await bs[Math.floor(Math.random()*bs.length)].click({timeout:500}).catch(()=>{});continue;}
      if(await p.$('#ov:not(.hidden)')){
        const r=Math.random();
        if(r<0.08){await p.click('#wclose',{timeout:500}).catch(()=>{});continue;}
        if(r<0.2){const tabs=await p.$$('#wtabs button');if(tabs.length){await tabs[Math.floor(Math.random()*tabs.length)].click({timeout:500}).catch(()=>{});continue;}}
        const els=await p.$$('#wbody [data-a]:not([disabled]), #wback:not(.hidden)');if(els.length){await els[Math.floor(Math.random()*els.length)].click({timeout:500}).catch(()=>{});clicks++;}
        continue;}
      const m=menus[Math.floor(Math.random()*menus.length)];await p.click(`[data-m="${m}"]`,{timeout:500}).catch(()=>{});
      if(Math.random()<0.3)await p.evaluate(()=>{for(let i=0;i<10;i++){if(UI.paused())break;E.tick();}});
    }catch(e){errs.push('TESTERR '+e.message);}
  }
  console.log('clicks',clicks,'day',await p.evaluate(()=>G.day),'races',await p.evaluate(()=>G.st.races));
  console.log('ERRORS:',errs.length?[...new Set(errs)].slice(0,10).join('\n---\n'):'none');await b.close();})();
