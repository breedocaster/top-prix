// ===================== CONTENT DATA v2: engineering, formats, tech, awards =====================
// Rename intake parts so "fuel injection" only means the EFI system
(()=>{const ren={airfilter:['Pod Filter','ful'],fuelinj:['Velocity Stacks','ful'],racefuel:['Ram-Air Intake','ful'],methanol:['Tuned Intake Runners','ful']};
  for(const k in ren){D.PART[k].n=ren[k][0];}D.PART_CATS.ful='Intake';})();

// ---------- Launch section + drag style ----------
D.SEC.lau = {n:'Launch',w:[0.1,0.75,0.15],dmg:0.5,risk:0.03};
D.STYLES.drag = {pat:['lau','str','str','str'],n:4,p2p:true};
D.STYLES.hill.p2p = true;

// ---------- Fuels ----------
D.FUELS = {
  pump:{n:'Pump 91',need:1,kn:0,pw:1,cost:0},
  race:{n:'Race 110',need:1,kn:5,pw:1.01,cost:4000,tech:'racefuel'},
  e85:{n:'E85',need:1.32,kn:9,pw:1.035,cost:2500,tech:'e85'},
};
D.LAM = {idle:0.93,low:0.9,mid:0.88,wot:0.87}; // racing lambda targets per throttle zone
D.ZONES = ['idle','low','mid','wot'];
D.ZONE_N = {idle:'Idle',low:'1/8–1/4',mid:'1/4–3/4',wot:'3/4–Full'};

// ---------- Carburetors ----------
// type: jet -> richness *= (v/stock)^(2w); lin/clip -> *= 1 + w*(v-stock); pv -> mid; airc -> wot leaner with bigger; pump -> transient
D.CARBS = {
  pe:{n:'Round-Slide 30 (PE-style)',cls:'bike',kind:'slide',trans:0.92,pw:1,un:'S',
    p:[{k:'main',n:'Main jet',min:100,max:170,step:2.5,stock:130,t:'jet',w:{idle:0,low:0.08,mid:0.3,wot:1}},
       {k:'pilot',n:'Pilot jet',min:25,max:50,step:2.5,stock:40,t:'jet',w:{idle:1,low:0.7,mid:0.2,wot:0.08}},
       {k:'clip',n:'Needle clip',min:1,max:5,step:1,stock:3,t:'clip',w:{idle:0,low:0.035,mid:0.07,wot:0.02},d:'Lower groove (higher #) raises the needle = richer midrange'},
       {k:'screw',n:'Air screw',min:0.5,max:3.5,step:0.25,stock:1.5,t:'lin',w:{idle:-0.07,low:-0.025,mid:0,wot:0},u:' turns',d:'Air screw: turning OUT leans the pilot circuit'},
       {k:'float',n:'Fuel level',min:-3,max:3,step:0.5,stock:0,t:'lin',w:{idle:0.035,low:0.03,mid:0.02,wot:0.015},u:' mm',d:'Higher fuel level = richer everywhere. Too low starves on jumps; too high floods on rough ground'}]},
  cv:{n:'CV 32 (BS-style)',cls:'bike',kind:'cv',trans:0.97,pw:0.99,un:'S',
    p:[{k:'main',n:'Main jet',min:95,max:160,step:2.5,stock:122.5,t:'jet',w:{idle:0,low:0.06,mid:0.28,wot:1}},
       {k:'pilot',n:'Pilot jet',min:30,max:47.5,step:2.5,stock:40,t:'jet',w:{idle:1,low:0.7,mid:0.2,wot:0.08}},
       {k:'clip',n:'Needle shim/clip',min:1,max:5,step:1,stock:3,t:'clip',w:{idle:0,low:0.03,mid:0.065,wot:0.02},d:'Raising the needle (higher #) richens 1/4–3/4'},
       {k:'screw',n:'Pilot fuel screw',min:0.5,max:4,step:0.25,stock:2,t:'lin',w:{idle:0.07,low:0.025,mid:0,wot:0},u:' turns',d:'Fuel screw: turning OUT richens the pilot circuit'},
       {k:'float',n:'Fuel level',min:-3,max:3,step:0.5,stock:0,t:'lin',w:{idle:0.035,low:0.03,mid:0.02,wot:0.015},u:' mm'}]},
  pwk:{n:'PWK-style 28 (round slide)',cls:'bike',kind:'slide',trans:0.93,pw:1.02,un:'pwk',
    p:[{k:'main',n:'Main jet',min:100,max:160,step:2.5,stock:125,t:'jet',w:{idle:0,low:0.08,mid:0.3,wot:1}},
       {k:'pilot',n:'Pilot jet',min:30,max:50,step:2.5,stock:40,t:'jet',w:{idle:1,low:0.7,mid:0.2,wot:0.08}},
       {k:'clip',n:'Needle clip',min:1,max:5,step:1,stock:3,t:'clip',w:{idle:0,low:0.035,mid:0.07,wot:0.02}},
       {k:'screw',n:'Air screw',min:0.5,max:3.5,step:0.25,stock:1.5,t:'lin',w:{idle:-0.07,low:-0.025,mid:0,wot:0},u:' turns',d:'Air screw: OUT = leaner'},
       {k:'float',n:'Fuel level',min:-3,max:3,step:0.5,stock:0,t:'lin',w:{idle:0.035,low:0.03,mid:0.02,wot:0.015},u:' mm'}]},
  fcr:{n:'Flat-Slide Pumper 39 (FCR-style)',cls:'bike',kind:'flat',trans:1,pw:1.045,un:'fcr',
    p:[{k:'main',n:'Main jet',min:145,max:200,step:2.5,stock:172,t:'jet',w:{idle:0,low:0.06,mid:0.28,wot:1}},
       {k:'pilot',n:'Slow jet',min:35,max:50,step:2.5,stock:42,t:'jet',w:{idle:1,low:0.7,mid:0.2,wot:0.08}},
       {k:'clip',n:'Needle clip',min:1,max:5,step:1,stock:3,t:'clip',w:{idle:0,low:0.035,mid:0.07,wot:0.02}},
       {k:'screw',n:'Fuel screw',min:0.5,max:3.5,step:0.25,stock:1.75,t:'lin',w:{idle:0.07,low:0.025,mid:0,wot:0},u:' turns',d:'Fuel screw: OUT = richer'},
       {k:'float',n:'Fuel level',min:-3,max:3,step:0.5,stock:0,t:'lin',w:{idle:0.035,low:0.03,mid:0.02,wot:0.015},u:' mm'},
       {k:'pump',n:'Accel pump shot',min:50,max:160,step:10,stock:100,t:'pump',u:'%',d:'Squirt on a throttle snap — cures the lean bog off hairpins'}]},
  d2:{n:'Downdraft 2-Barrel 350',cls:'car',kind:'down',barrels:2,trans:0.95,pw:1,un:'S',
    p:[{k:'main',n:'Main jets',min:56,max:80,step:1,stock:66,t:'jet',w:{idle:0,low:0.15,mid:0.8,wot:1}},
       {k:'pv',n:'Power valve',min:2.5,max:10.5,step:1,stock:6.5,t:'pv',u:' inHg',d:'Higher rating opens sooner = richer under part-throttle load'},
       {k:'screw',n:'Idle mixture screws',min:0.5,max:3,step:0.25,stock:1.5,t:'lin',w:{idle:0.07,low:0.03,mid:0,wot:0},u:' turns',d:'OUT = richer idle'},
       {k:'float',n:'Fuel level',min:-3,max:3,step:0.5,stock:0,t:'lin',w:{idle:0.03,low:0.025,mid:0.02,wot:0.015},u:' mm'},
       {k:'pump',n:'Pump squirter',min:22,max:40,step:3,stock:31,t:'pump',u:'',d:'Bigger squirter = more fuel on throttle snap'}]},
  q4:{n:'Downdraft 4-Barrel 600',cls:'car',kind:'down',barrels:4,trans:0.96,pw:1.05,un:'carb4',
    p:[{k:'main',n:'Primary jets',min:56,max:80,step:1,stock:65,t:'jet',w:{idle:0,low:0.15,mid:0.85,wot:0.5}},
       {k:'sec',n:'Secondary jets',min:60,max:90,step:1,stock:74,t:'jet',w:{idle:0,low:0,mid:0.05,wot:0.5}},
       {k:'pv',n:'Power valve',min:2.5,max:10.5,step:1,stock:6.5,t:'pv',u:' inHg'},
       {k:'screw',n:'Idle mixture screws',min:0.5,max:3,step:0.25,stock:1.5,t:'lin',w:{idle:0.07,low:0.03,mid:0,wot:0},u:' turns'},
       {k:'float',n:'Fuel level',min:-3,max:3,step:0.5,stock:0,t:'lin',w:{idle:0.03,low:0.025,mid:0.02,wot:0.015},u:' mm'},
       {k:'pump',n:'Pump squirter',min:22,max:40,step:3,stock:31,t:'pump',u:''}]},
  dcoe:{n:'Twin Sidedraft 40 (DCOE-style)',cls:'car',kind:'side',carbs:2,trans:0.97,pw:1.08,un:'dcoe',
    p:[{k:'main',n:'Main jet',min:110,max:170,step:5,stock:135,t:'jet',w:{idle:0,low:0.1,mid:0.45,wot:1}},
       {k:'airc',n:'Air corrector',min:150,max:230,step:5,stock:185,t:'airc',d:'Bigger air corrector = leaner at high rpm'},
       {k:'pilot',n:'Idle jet',min:40,max:65,step:5,stock:50,t:'jet',w:{idle:1,low:0.7,mid:0.2,wot:0.05}},
       {k:'screw',n:'Mixture screws',min:0.5,max:3,step:0.25,stock:1.5,t:'lin',w:{idle:0.07,low:0.03,mid:0,wot:0},u:' turns'},
       {k:'float',n:'Fuel level',min:-3,max:3,step:0.5,stock:0,t:'lin',w:{idle:0.03,low:0.025,mid:0.02,wot:0.015},u:' mm'},
       {k:'pump',n:'Pump jet',min:30,max:55,step:5,stock:40,t:'pump',u:''}]},
};
D.LAYOUT_CYL = {single:1,stroke2:1,twin:2,vtwin:2,triple:3,inline4:4,elec:0,ff:4,fr:4,mr:4,rr:4,awd:4,hyb:4};
D.CYL_N = {1:'Single',2:'Twin',3:'Triple',4:'Inline-4'};

// ---------- EFI bins ----------
D.RPM_B = {bike:[2000,3500,5000,6500,8000,9500,11000,12500],car:[1000,2000,3000,4000,5000,6000,7000,8000]};
D.LOAD_B = [30,45,60,75,90,100];
D.AFR_DEF = [13.8,13.4,13.1,12.9,12.8,12.7];

// ---------- Setup sheet ----------
D.SETUP = {
  gear:{n:'Gearing',tech:'gearing'},susp:{n:'Suspension',tech:'adjsus'},tire:{n:'Tire pressure',tech:'tirepress'},wing:{n:'Wing angle',tech:'aero',car:true},
};

// ---------- Race conditions ----------
D.COND = {
  o1c:[1100,1450,-4],p3b:[2860,4300,10],p4x1:[60,110,20],o4a:[1200,1700,2],o2b:[1600,0,26],o3b:[350,0,40],o3x1:[1300,0,30],o4b:[250,0,42],
  o3c:[100,0,-20],o4c:[300,0,-12],d2c:[250,0,24],d3a:[900,0,30],d4b:[1000,1300,14],b4a:[50,0,15],l5c:[400,0,-25],l5b:[3500,0,5],l5a:[600,0,32],
  p2b:[1900,0,6],o2c:[1200,0,-8],o2x2:[2100,2400,-10],o3a:[700,0,10],d1c:[200,0,28],c3c:[100,0,22,'night'],d4x1:[600,0,24,'night'],
  c2c:[220,0,26],c4c:[300,0,18],b3c:[20,0,28],b4c:[30,0,30],o3x2:[1800,0,-6],o4x2:[900,0,-16],p3x2:[1400,0,-5],d1x2:[200,0,10],b2c:[30,0,24],
};
D.NIGHT = {};
D.condOf = (r)=>{
  const o=D.COND[r.id];let alt,alt2,temp,tod='day';
  if(o){alt=o[0];alt2=o[1]||o[0];temp=o[2];tod=o[3]||'day';}
  else{alt=200;temp=18;const s=r.surf;if(s.sand)temp=34,alt=300;if(s.snow)temp=-6,alt=900;if(s.ice)temp=-14,alt=600;if(s.mud||s.wet)temp=12;
    if(r.style==='hill'){alt=300+500*r.tier;}alt2=alt+(r.style==='hill'?250+250*r.tier:0);}
  if(r.alt!=null){alt=r.alt;alt2=r.alt2;temp=r.temp;tod=r.tod||tod;}
  return {alt,alt2,temp,tod};
};
D.SEASON = [0,4,8,10,9,5,0,-5,-9,-11,-9,-4];

// ---------- New disciplines: Drag (straight) & Hillclimb ----------
D.DISC.DR = {n:'Drag Strip',cls:'any',ic:'🚦'};
D.DISC.HC = {n:'Hillclimb',cls:'any',ic:'⛰️'};
(()=>{
  const add=[
   // id,name,tier,disc,surf,style,laps,R,prizeK,rp,alt,alt2,temp,tod
   ['r1a','Friday Night Drags',1,'DR','tar','drag',1,30,30,10,180,180,20,'night'],
   ['r1b','County Line Quarter',1,'DR','tar','drag',1,40,45,13,240,240,24],
   ['r1c','Test & Tune Shootout',1,'DR','tar','drag',1,52,60,16,200,200,16],
   ['r1x1','Hometown Nationals',1,'DR','tar','drag',1,60,60,16,220,220,26],
   ['r1x2','Grain Elevator Grudge Match',1,'DR','tar','drag',1,68,80,20,250,250,30],
   ['h1a','Old Mill Hill',1,'HC','tar','hill',1,30,30,10,250,330,18],
   ['h1b','Orchard Ridge Climb',1,'HC','tar70 dirt30','hill',1,40,45,13,420,560,16],
   ['h1c','Fire Tower Run',1,'HC','tar','hill',1,52,60,16,600,780,12],
   ['h1x1','Quarry Road Climb',1,'HC','dirt60 tar40','hill',1,60,60,16,500,700,20],
   ['h1x2','Rookie King of the Hill',1,'HC','tar','hill',1,68,80,20,700,950,10],
   ['r2a','Heartland Dragway',2,'DR','tar','drag',1,80,130,30,250,250,24],
   ['r2b','Thunder Alley Eighth',2,'DR','tar','drag',1,115,170,38,300,300,30,'night'],
   ['r2c','Midwest Nitro Nationals',2,'DR','tar','drag',1,150,210,46,230,230,28],
   ['r2x1','Pro Street Shootout',2,'DR','tar','drag',1,180,240,50,280,280,22],
   ['r2x2','National Quarter Finals',2,'DR','tar','drag',1,210,300,58,260,260,26],
   ['h2a','Twin Peaks Climb',2,'HC','tar','hill',1,80,130,30,900,1250,14],
   ['h2b','Switchback Sprint',2,'HC','tar80 dirt20','hill',1,115,170,38,1200,1600,10],
   ['h2c','Eagle Pass Climb',2,'HC','tar70 snow30','hill',1,150,210,46,1500,2000,2],
   ['h2x1','National Hillclimb Cup',2,'HC','tar','hill',1,180,240,50,1700,2300,8],
   ['h2x2','Thunderhead Climb',2,'HC','tar60 dirt40','hill',1,210,300,58,2000,2600,6],
   ['r3a','Desert Mile Drags',3,'DR','tar','drag',1,240,400,70,1300,1300,36],
   ['r3b','Harbor Lights Drags',3,'DR','tar','drag',1,330,520,85,10,10,22,'night'],
   ['r3c','Continental Top Speed',3,'DR','tar','drag',1,420,640,100,400,400,20],
   ['r3x1','Night of Fire',3,'DR','tar','drag',1,480,700,110,300,300,18,'night'],
   ['r3x2','Continental Drag Finals',3,'DR','tar','drag',1,545,820,125,350,350,24],
   ['h3a','Granite Spire Climb',3,'HC','tar','hill',1,240,400,70,1800,2500,6],
   ['h3b','Cloud Gate Climb',3,'HC','tar70 dirt30','hill',1,330,520,85,2200,3000,4],
   ['h3c','Glacier Road',3,'HC','tar60 snow40','hill',1,420,640,100,2400,3200,-4],
   ['h3x1','Continental Climb',3,'HC','tar','hill',1,480,700,110,2000,2900,8],
   ['h3x2','Sky Ladder',3,'HC','tar70 dirt30','hill',1,545,820,125,2800,3900,0],
   ['r4a','World Drag Opener',4,'DR','tar','drag',1,620,1000,150,200,200,26],
   ['r4b','Mile-High Thin Air Drags',4,'DR','tar','drag',1,800,1300,180,1610,1610,30],
   ['r4c','Nitro World Series',4,'DR','tar','drag',1,950,1600,210,250,250,28,'night'],
   ['r4x1','Pro Mod World Cup',4,'DR','tar','drag',1,1060,1800,230,300,300,24],
   ['r4x2','World Finals Quarter',4,'DR','tar','drag',1,1130,2200,260,220,220,22,'night'],
   ['h4a','Thunder Mountain Climb',4,'HC','tar','hill',1,620,1000,150,2000,3000,10],
   ['h4b','Summit of Clouds',4,'HC','tar','hill',1,800,1300,180,2860,4300,8],
   ['h4c','Dragon Spine Climb',4,'HC','tar70 dirt30','hill',1,950,1600,210,1500,2600,14],
   ['h4x1','World Hillclimb Masters',4,'HC','tar','hill',1,1060,1800,230,3000,4100,2],
   ['h4x2','Top of the World',4,'HC','tar80 snow20','hill',1,1130,2200,260,3500,4800,-6],
  ];
  for(const a of add){const surf={};a[4].split(' ').forEach(tok=>{const m=tok.match(/^([a-z]+)(\d*)$/);surf[m[1]]=m[2]?+m[2]:100;});
    const r={id:a[0],n:a[1],tier:a[2],disc:a[3],cls:'any',surf,style:a[5],laps:a[6],R:a[7],prize:a[8]*1000,rp:a[9],excl:/x\d$/.test(a[0]),letter:(a[0].match(/([abc])$/)||[])[1]||null,alt:a[10],alt2:a[11],temp:a[12],tod:a[13]||'day'};
    D.RACES.push(r);D.RACE[r.id]=r;}
  const ser=[['s1r','Rookie Drag Series',1,'DR',['r1a','r1b','r1c','r1x1','r1x2'],300,20,7],['s1h','Rookie Hillclimb Cup',1,'HC',['h1a','h1b','h1c','h1x1','h1x2'],300,20,7],
    ['s2r','National Drag Racing Series',2,'DR',['r2a','r2b','r2c','r2x1','r2x2'],900,80,9],['s2h','National Mountain Cup',2,'HC',['h2a','h2b','h2c','h2x1','h2x2'],900,80,9],
    ['s3r','Continental Drag Championship',3,'DR',['r3a','r3b','r3c','r3x1','r3x2'],2500,250,11],['s3h','Continental Hillclimb Series',3,'HC',['h3a','h3b','h3c','h3x1','h3x2'],2500,250,11],
    ['s4r','World Drag Championship',4,'DR',['r4a','r4b','r4c','r4x1','r4x2'],6000,600,11],['s4h','World Hillclimb Championship',4,'HC',['h4a','h4b','h4c','h4x1','h4x2'],6000,600,11]];
  for(const a of ser){const s={id:a[0],n:a[1],tier:a[2],disc:a[3],cls:'any',rounds:a[4],prize:a[5]*1000,fee:a[6]*1000,rivals:a[7]};D.SERIES.push(s);D.SER[s.id]=s;}
  for(const id of['c3c','d4x1'])D.RACE[id].tod='night';
  D.RACE.o1c.disc='CO';
})();

// ---------- Formats ----------
// returns list of {id,n,laps,mul:{prize,rp,fans,wear},kind}
D.formats = (r)=>{
  const L=r.laps;const st=r.style;
  if(st==='drag')return[{id:'elim',n:'Eliminations (8-car ladder)',kind:'drag',laps:1,mul:{prize:1,rp:1,fans:1,wear:1}}];
  if(st==='hill')return[{id:'best2',n:'2 runs — best time counts',kind:'tt',runs:2,laps:1,mul:{prize:1.15,rp:1.2,fans:1.1,wear:1.6}},{id:'one',n:'Single run',kind:'tt',runs:1,laps:1,mul:{prize:1,rp:1,fans:1,wear:1}}];
  if(st==='rally'||st==='desert')return[{id:'stage',n:'Single stage',kind:'tt',laps:1,mul:{prize:1,rp:1,fans:1,wear:1}},{id:'rally3',n:'3-stage rally',kind:'tt',laps:3,mul:{prize:2.2,rp:2,fans:1.8,wear:2.6}}];
  if(st==='enduro')return[{id:'one',n:`Hare scramble (${L} lap${L>1?'s':''})`,kind:'mass',laps:L,mul:{prize:1,rp:1,fans:1,wear:1}},{id:'long',n:`Long scramble (${L*2} laps)`,kind:'mass',laps:L*2,mul:{prize:1.7,rp:1.6,fans:1.5,wear:2}}];
  const out=[{id:'sprint',n:`Sprint — ${L} lap${L>1?'s':''}`,kind:'mass',laps:L,mul:{prize:1,rp:1,fans:1,wear:1}},
    {id:'feature',n:`Feature — ${L*2} laps`,kind:'mass',laps:L*2,mul:{prize:1.6,rp:1.5,fans:1.5,wear:1.8}}];
  if(st==='mx'||st==='oval'||st==='mixed')out.push({id:'heats',n:`Heats + Main (${Math.max(1,Math.ceil(L/2))}-lap heats, ${L+1}-lap main)`,kind:'heats',laps:L+1,heatLaps:Math.max(1,Math.ceil(L/2)),mul:{prize:1.35,rp:1.5,fans:1.6,wear:1.6}});
  if(r.tier>=2&&(st==='circuit'||st==='speed'||st==='oval'||st==='tech'||st==='street'))out.push({id:'endur',n:`Endurance — ${L*4} laps`,kind:'mass',laps:L*4,mul:{prize:2.6,rp:2.3,fans:2.2,wear:3.4}});
  return out;
};
D.seriesFormat = r=>{const f=D.formats(r);return f.find(x=>x.id==='heats')||f.find(x=>x.id==='best2')||f[0];};

// ---------- Test day tracks ----------
D.TESTS = [
  {id:'t_tar',n:'Shop Lot Loop',surf:{tar:100},style:'circuit',lap:true},
  {id:'t_dirt',n:'Back-Forty Dirt Loop',surf:{dirt:100},style:'mx',lap:true},
  {id:'t_drag',n:'Rented Drag Strip',surf:{tar:100},style:'drag'},
  {id:'t_hill',n:'Fire Road Hill',surf:{tar:60,dirt:40},style:'hill',alt:300,alt2:700},
];

// ---------- TECH TREE ----------
D.TECH = [
 // Fuel
 {id:'carbbasic',n:'Carburetor Basics',cat:'Fuel',rp:0,ws:1,req:[],d:'Round-slide & CV bike carbs, 2-barrel car carbs, plug chops.',own:true},
 {id:'wideband',n:'Wideband O2 Sensor',cat:'Fuel',rp:30,ws:1,req:['carbbasic'],d:'See real air/fuel ratios on the bench and in logs instead of reading plugs.'},
 {id:'syncgauge',n:'Vacuum Sync Gauges',cat:'Fuel',rp:20,ws:1,req:['carbbasic'],d:'Carbtune-style gauge columns. Without them you sync multi-carb engines by ear.'},
 {id:'pwk',n:'PWK-Style Racing Carbs',cat:'Fuel',rp:35,ws:1,req:['carbbasic'],d:'Round-slide racing carb for bikes. A little more power.'},
 {id:'carb4',n:'4-Barrel Carburetion',cat:'Fuel',rp:35,ws:1,req:['carbbasic'],d:'Downdraft 4-barrel with vacuum secondaries for cars.'},
 {id:'racefuel',n:'Race Fuel (110)',cat:'Fuel',rp:40,ws:2,req:['carbbasic'],d:'More knock margin. Costs extra each race.'},
 {id:'baffle',n:'Float Bowl Baffles',cat:'Fuel',rp:50,ws:2,req:['carbbasic'],d:'Stops fuel starvation and flooding on jumps and rough ground.'},
 {id:'fcr',n:'Flat-Slide Pumper Carbs',cat:'Fuel',rp:80,ws:2,req:['pwk'],d:'FCR-style flat slide with accelerator pump. Best carb power for bikes.'},
 {id:'dcoe',n:'Twin Sidedraft Carbs',cat:'Fuel',rp:80,ws:2,req:['carb4','syncgauge'],d:'DCOE-style pair for cars. Needs syncing.'},
 {id:'efi',n:'Throttle-Body EFI (Alpha-N)',cat:'Fuel',rp:120,ws:2,req:['wideband'],d:'Programmable injection with VE/spark/AFR tables on a laptop. TPS load: does not correct for altitude by itself.'},
 {id:'mapsens',n:'MAP Sensor + Baro',cat:'Fuel',rp:90,ws:3,req:['efi'],d:'Speed-density load with barometric correction: EFI stays on target at any altitude.'},
 {id:'iat',n:'Intake Air Temp Sensor',cat:'Fuel',rp:60,ws:3,req:['efi'],d:'EFI corrects for hot and cold air.'},
 {id:'veal',n:'VE Analyze (Auto-tune)',cat:'Fuel',rp:140,ws:3,req:['mapsens'],d:'Applies New VE = VE × measured AFR ÷ target AFR to logged cells.'},
 {id:'knock',n:'Knock Sensor + Retard',cat:'Fuel',rp:120,ws:3,req:['efi'],d:'EFI pulls timing when it hears detonation. Logs knock per cell.'},
 {id:'e85',n:'Flex Fuel / E85',cat:'Fuel',rp:160,ws:4,req:['efi'],d:'Huge knock margin and a little more power, but needs ~32% more fuel — rejet or retune!'},
 {id:'launch',n:'Launch Control / 2-Step',cat:'Fuel',rp:100,ws:3,req:['efi'],d:'EFI launches hard off the drag-strip line. Bigger edge on Launch sections.'},
 {id:'tcmap',n:'Traction Control Maps',cat:'Fuel',rp:120,ws:3,req:['efi'],d:'EFI vehicles make fewer mistakes on wet, dirt and ice.'},
 // Engine
 {id:'porting',n:'Port & Polish',cat:'Engine',rp:60,ws:2,req:[],d:'+3% engine power. Engine will need more fuel.'},
 {id:'highcomp',n:'High-Compression Pistons',cat:'Engine',rp:90,ws:2,req:['porting'],d:'+4% power, but 3° less knock margin.'},
 {id:'forged',n:'Forged Internals',cat:'Engine',rp:120,ws:3,req:['highcomp'],d:'Detonation and lean damage cut in half.'},
 {id:'oilcool',n:'Oil Cooler / Dry Sump',cat:'Engine',rp:80,ws:2,req:[],d:'Engine wear per race -30%.'},
 {id:'bigvalve',n:'Big-Valve Head',cat:'Engine',rp:150,ws:4,req:['porting'],d:'+5% power up top. Needs a lot more fuel at WOT.'},
 // Chassis
 {id:'gearing',n:'Sprocket & Gear Kit',cat:'Chassis',rp:15,ws:1,req:[],d:'Change sprockets (bikes) or final drive (cars).'},
 {id:'tirepress',n:'Tire Pressure Program',cat:'Chassis',rp:15,ws:1,req:[],d:'Air down for dirt, pump up for tarmac.'},
 {id:'adjsus',n:'Adjustable Suspension',cat:'Chassis',rp:30,ws:1,req:[],d:'Click stiffer for tarmac, softer for rough ground.'},
 {id:'aero',n:'Adjustable Aero',cat:'Chassis',rp:60,ws:2,req:['adjsus'],d:'Wing angle on cars: downforce vs. top speed.'},
 {id:'quickchange',n:'Quick-Change Kit',cat:'Chassis',rp:70,ws:2,req:['gearing'],d:'Crew retunes between hillclimb runs and heats for free.'},
 // Data & crew
 {id:'crewchief',n:'Crew Chief Program',cat:'Crew',rp:25,ws:1,req:[],d:'"Crew tune" button: the crew jets/maps for the conditions (Standard mode).'},
 {id:'datalog',n:'Datalogging',cat:'Crew',rp:30,ws:1,req:[],d:'Races record a fuel datalog you can review on the bench.'},
 {id:'telem',n:'Live Telemetry',cat:'Crew',rp:100,ws:3,req:['datalog','wideband'],d:'AFR & knock in the race HUD. +10% research data from races.'},
];
D.TECHM = Object.fromEntries(D.TECH.map(t=>[t.id,t]));

// ---------- ACHIEVEMENTS ----------
// ev: event-only (unlocked by E.ach); chk: (G)=>bool checked periodically
D.ACH = [
 {id:'build1',n:'Shed-Built',d:'Finish your first vehicle',ic:'🔧',rw:{rp:10}},
 {id:'race1',n:'Green Flag',d:'Enter your first race',ic:'🏁',chk:G=>G.st.races>=1,rw:{cash:10}},
 {id:'win1',n:'First Blood',d:'Win a race',ic:'🥇',chk:G=>G.st.wins>=1,rw:{cash:20}},
 {id:'pod10',n:'Podium Regular',d:'10 podium finishes',ic:'🥉',chk:G=>G.st.podiums>=10,rw:{rp:30}},
 {id:'win10',n:'Winning Habit',d:'Win 10 races',ic:'🏆',chk:G=>G.st.wins>=10,rw:{cash:100}},
 {id:'win50',n:'Fifty Up',d:'Win 50 races',ic:'🏆',chk:G=>G.st.wins>=50,rw:{cash:500,spark:'s'}},
 {id:'win150',n:'Dynasty',d:'Win 150 races',ic:'👑',chk:G=>G.st.wins>=150,rw:{cash:2000,spark:'g'}},
 {id:'hat',n:'Hat Trick',d:'Win 3 races in a row',ic:'🎩',rw:{rp:40}},
 {id:'title1',n:'Champions!',d:'Win a series title',ic:'🏆',chk:G=>G.st.titles.length>=1,rw:{cash:100,spark:'s'}},
 {id:'title5',n:'Trophy Cabinet',d:'Win 5 series titles',ic:'🏆',chk:G=>G.st.titles.length>=5,rw:{cash:500}},
 {id:'world',n:'World Champions',d:'Win a World-tier series',ic:'🌍',chk:G=>G.st.titles.some(t=>D.SER[t].tier===4),rw:{cash:3000,spark:'g'}},
 {id:'legend',n:'Legend',d:'Win the King of All Terrain',ic:'⭐',chk:G=>G.st.titles.includes('s5l'),rw:{cash:10000,spark:'g'}},
 {id:'bothways',n:'Two Wheels & Four',d:'Win with a car and with a bike',ic:'🏍️',chk:G=>(G.st.wc['w:cls:car']||0)>0&&(G.st.wc['w:cls:bike']||0)>0,rw:{rp:50}},
 {id:'alldisc',n:'Jack of All Trades',d:'Win in all 7 disciplines',ic:'🃏',chk:G=>Object.keys(D.DISC).every(k=>(G.st.wc['w:disc:'+k]||0)>0),rw:{cash:1000,spark:'g'}},
 {id:'jet1',n:'Jet Setter',d:'Change a carb jet for the first time',ic:'🔩',rw:{rp:5}},
 {id:'spoton',n:'Spot On',d:'Every throttle zone within 0.3 AFR of target',ic:'🎯',rw:{rp:40}},
 {id:'sync4',n:'In Sync',d:'Balance a 4-carb rack within 0.3 cmHg',ic:'⚖️',rw:{rp:30}},
 {id:'efi1',n:'Fuel Injected',d:'Run an EFI vehicle',ic:'💻',rw:{rp:30}},
 {id:'cells',n:'Cell Shaded',d:'Edit 50 table cells on the laptop',ic:'📊',rw:{rp:40}},
 {id:'veal1',n:'Let the Laptop Drive',d:'Apply VE Analyze corrections',ic:'🤖',rw:{rp:20}},
 {id:'holed',n:'Ventilated',d:'Hole a piston',ic:'💥',rw:{rp:15}},
 {id:'seize',n:'Ring-Ding Seize',d:'Lean-seize a two-stroke',ic:'🧊',rw:{rp:15}},
 {id:'thinair',n:'Thin Air',d:'Win above 2,500 m on carbs',ic:'🏔️',rw:{cash:200,rp:50}},
 {id:'frozen',n:'Brain Freeze',d:'Win a race below -10°C',ic:'❄️',rw:{rp:40}},
 {id:'drag1',n:'Quarter-Mile Hero',d:'Win a drag eliminations',ic:'🚦',rw:{cash:50}},
 {id:'ten',n:'Ten-Second Machine',d:'Run a 9.99 or quicker',ic:'⏱️',rw:{rp:40}},
 {id:'eights',n:'Into the Eights',d:'Run an 8.99 or quicker',ic:'⚡',rw:{rp:80,spark:'s'}},
 {id:'hill1',n:'King of the Hill',d:'Win a hillclimb',ic:'⛰️',rw:{cash:50}},
 {id:'clouds',n:'Above the Clouds',d:'Win a climb finishing above 4,000 m',ic:'☁️',rw:{cash:500,spark:'s'}},
 {id:'endur',n:'Iron Man',d:'Finish an Endurance race',ic:'🕰️',rw:{rp:40}},
 {id:'heatmain',n:'Heat Seeker',d:'Win your heat and the main',ic:'🔥',rw:{rp:40}},
 {id:'comeback',n:'Comeback Kid',d:'Win from the back half of the grid',ic:'🚀',rw:{rp:40}},
 {id:'rain',n:'Singin\' in the Rain',d:'Win a wet race',ic:'☔',chk:G=>(G.st.wc['w:terr:wet']||0)>0,rw:{rp:30}},
 {id:'mud',n:'Mud Bath',d:'Win an off-road race',ic:'🟫',chk:G=>(G.st.wc['w:terr:off']||0)>0,rw:{rp:30}},
 {id:'ice',n:'Ice Ice Baby',d:'Win on snow or ice',ic:'🧊',chk:G=>(G.st.wc['w:terr:ice']||0)>0,rw:{rp:30}},
 {id:'factory',n:'Factory Team',d:'Move into the Factory HQ',ic:'🏭',chk:G=>G.ws>=4,rw:{cash:1000}},
 {id:'fullgar',n:'Car Collector',d:'Fill every garage bay',ic:'🅿️',chk:G=>G.vehicles.length>=D.WORKSHOPS[G.ws].veh&&G.ws>=2,rw:{rp:40}},
 {id:'mil',n:'Millionaire',d:'Hold $1M',ic:'💰',chk:G=>G.money>=1e6,rw:{rp:30}},
 {id:'mil10',n:'Deep Pockets',d:'Hold $10M',ic:'💎',chk:G=>G.money>=1e7,rw:{rp:100}},
 {id:'fans10k',n:'Fan Club',d:'10,000 fans',ic:'♥',chk:G=>G.fans>=10000,rw:{cash:200}},
 {id:'fans100k',n:'Superstars',d:'100,000 fans',ic:'💖',chk:G=>G.fans>=100000,rw:{cash:2000}},
 {id:'spon5',n:'Brand Ambassador',d:'Complete 5 sponsor goals',ic:'💼',chk:G=>Object.keys(G.sponDone).length>=5,rw:{cash:300}},
 {id:'tech10',n:'Engineer',d:'Research 10 technologies',ic:'🧪',chk:G=>Object.keys(G.tech||{}).length>=10,rw:{rp:60}},
 {id:'techall',n:'Chief Engineer',d:'Research every technology',ic:'🧠',chk:G=>D.TECH.every(t=>G.tech&&G.tech[t.id]),rw:{cash:3000,spark:'g'}},
 {id:'mech10',n:'Master Mechanic',d:'Train a mechanic to Lv10',ic:'🛠️',chk:G=>G.staff.some(s=>s.role==='mec'&&s.lv>=10),rw:{rp:80}},
 {id:'test10',n:'Test Pilot',d:'Run 10 test days',ic:'🧪',chk:G=>(G.st.tests||0)>=10,rw:{rp:40}},
];
D.ACHM = Object.fromEntries(D.ACH.map(a=>[a.id,a]));

D.MODES = {
  easy:{n:'Easy',d:'Crew tunes the engine for every race. Bad tunes never damage engines. Rivals a bit slower.'},
  standard:{n:'Standard',d:'You tune. Crew warns you about lean/knock risk and can tune for a fee.'},
  sim:{n:'Sim',d:'No warnings, no crew tunes. Plug chops until you buy a wideband. Race-day weather swings more.'},
};
