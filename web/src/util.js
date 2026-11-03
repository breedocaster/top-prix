// ===================== UTIL =====================
const U = {
  clamp:(v,a,b)=>Math.max(a,Math.min(b,v)),
  rand:(a,b)=>a+Math.random()*(b-a),
  ri:(a,b)=>Math.floor(a+Math.random()*(b-a+1)),
  pick:arr=>arr[Math.floor(Math.random()*arr.length)],
  chance:p=>Math.random()<p,
  shuffle(a){a=a.slice();for(let i=a.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]];}return a;},
  seeded(seed){let s=seed>>>0;return()=>{s=(s+0x6D2B79F5)>>>0;let t=s;t=Math.imul(t^(t>>>15),t|1);t^=t+Math.imul(t^(t>>>7),t|61);return((t^(t>>>14))>>>0)/4294967296;};},
  hash(str){let h=2166136261;for(let i=0;i<str.length;i++){h^=str.charCodeAt(i);h=Math.imul(h,16777619);}return h>>>0;},
  money(v){const a=Math.abs(v),s=v<0?'-':'';if(a>=1e6)return s+'$'+(a/1e6).toFixed(a>=1e8?0:a>=1e7?1:2)+'M';if(a>=1e3)return s+'$'+Math.round(a/1e3)+'K';return s+'$'+Math.round(a);},
  num(v){if(v>=1e6)return(v/1e6).toFixed(1)+'M';if(v>=1e4)return(v/1e3).toFixed(1)+'K';return String(Math.round(v));},
  esc(s){return String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));},
  ord(n){const s=['th','st','nd','rd'],v=n%100;return n+(s[(v-20)%10]||s[v]||s[0]);},
  sum:(a,f)=>a.reduce((s,x)=>s+(f?f(x):x),0),
  stars(n,max=5){let s='';for(let i=0;i<max;i++)s+=i<n?'★':'☆';return s;},
};
