// ===================== GRID & GRAVEL — CONTENT DATA =====================
const D = {};

D.RANKS = ['E','D','C','B','A','S'];
D.RANK_WS = {E:1,D:1,C:2,B:3,A:4,S:4};
D.RANK_REQ = {E:30,D:70,C:150,B:260,A:420,S:640}; // team tech needed for full-quality build

// Surfaces -> which terrain stat they test
D.SURF = {
  tar:{n:'Tarmac',k:'on',col:'#7d7f87',dmg:0.8,risk:0.8},
  wet:{n:'Wet',k:'wet',col:'#4f6f8f',dmg:1.0,risk:1.35},
  dirt:{n:'Dirt',k:'off',col:'#a2683a',dmg:1.15,risk:1.1},
  sand:{n:'Sand',k:'off',col:'#d9b45c',dmg:1.25,risk:1.15},
  mud:{n:'Mud',k:'off',col:'#6b4a2b',dmg:1.45,risk:1.35},
  snow:{n:'Snow',k:'ice',col:'#e3ecf5',dmg:1.0,risk:1.3},
  ice:{n:'Ice',k:'ice',col:'#a9dcf0',dmg:1.05,risk:1.55},
};
D.TERR_N = {on:'On-Rd',off:'Off-Rd',wet:'Wet',ice:'Icy'};

// Section types: weights [spd,acc,hnd], damage, base mistake risk
D.SEC = {
  str:{n:'Straight',w:[0.75,0.2,0.05],dmg:0.35,risk:0.004},
  crv:{n:'Sweeper',w:[0.4,0.15,0.45],dmg:0.55,risk:0.012},
  hp:{n:'Hairpin',w:[0.05,0.45,0.5],dmg:0.6,risk:0.022},
  chi:{n:'Chicane',w:[0.1,0.4,0.5],dmg:0.65,risk:0.02},
  jmp:{n:'Jump',w:[0.3,0.3,0.4],dmg:1.6,risk:0.03},
  rgh:{n:'Rough',w:[0.2,0.3,0.5],dmg:1.5,risk:0.026},
  hill:{n:'Climb',w:[0.3,0.6,0.1],dmg:0.6,risk:0.008},
};
D.STYLES = {
  oval:{pat:['str','crv','str','crv'],n:8},
  circuit:{p:{str:35,crv:35,hp:15,chi:15},n:11},
  tech:{p:{str:20,crv:35,hp:25,chi:20},n:12},
  speed:{p:{str:55,crv:35,chi:10},n:10},
  street:{p:{str:25,crv:20,hp:30,chi:25},n:12},
  mx:{p:{str:15,crv:25,jmp:30,rgh:20,hp:10},n:12},
  enduro:{p:{rgh:35,hill:25,crv:20,hp:10,jmp:10},n:14,p2p:true},
  rally:{p:{str:25,crv:40,hp:15,jmp:10,rgh:10},n:16,p2p:true},
  desert:{p:{str:45,rgh:25,jmp:15,crv:15},n:16,p2p:true},
  hill:{p:{hill:50,hp:30,crv:20},n:12,p2p:true},
  mixed:{p:{str:25,crv:25,hp:12,jmp:13,rgh:13,chi:12},n:13},
};

// ---------- BODIES ----------
// [id,name,cls,kind,rank,costK,rp,days,spd,acc,hnd,dur,on,off,wet,ice,slots,adv,unlock]
D.BODIES = [
 // Road cars
 ['kei','Kei Hatch','car','hatch','E',60,0,8,28,30,30,46,100,55,85,55,2,10,'S'],
 ['sedan','City Sedan','car','sedan','E',90,30,10,34,30,28,60,105,50,90,50,3,14,''],
 ['kart','Shifter Kart','car','kart','D',110,45,8,50,62,70,40,118,30,70,30,2,12,''],
 ['roadster','Pocket Roadster','car','roadster','D',160,60,12,64,58,66,60,112,40,85,40,3,22,''],
 ['coupe','Touring Coupe','car','coupe','C',300,110,16,112,100,108,124,115,45,92,45,4,26,''],
 ['hothatch','Hot Hatch R','car','hatch','C',260,100,14,100,115,112,108,110,60,98,60,4,24,''],
 ['gt','GT Sport','car','gt','B',600,200,20,196,170,172,196,120,35,92,40,5,36,''],
 ['fjr','Formula Junior','car','formula','B',560,190,18,190,186,200,140,128,20,80,25,4,32,''],
 ['proto','GT Prototype','car','proto','A',1200,340,26,310,280,290,306,128,25,95,30,6,48,''],
 ['formula','Formula Grand','car','formula','A',1300,360,26,318,300,320,230,134,15,85,20,5,50,''],
 ['hyper','Hyper LMP','car','proto','S',2600,600,34,470,430,440,470,135,20,100,25,7,70,'sp'],
 ['arrow','Arrow X1','car','formula','S',2800,640,34,486,462,486,340,140,10,90,15,6,72,'sp'],
 // Off-road cars
 ['pickup','Farm Pickup','car','pickup','E',70,20,9,26,28,24,72,82,96,86,86,3,8,''],
 ['buggy','Dune Buggy','car','buggy','D',140,55,10,56,66,58,72,72,118,85,80,3,18,''],
 ['rallyhatch','Rally Hatch','car','rally','D',170,65,12,60,62,64,80,95,110,100,100,3,20,''],
 ['sprintcar','Dirt Sprint Car','car','sprint','C',280,105,14,122,120,96,98,80,126,80,60,3,28,''],
 ['rallycoupe','Rally Coupe','car','rally','C',320,115,16,106,110,112,134,100,118,105,112,4,26,''],
 ['raidtruck','Raid Truck','car','truck','B',560,190,20,176,160,150,268,85,128,95,110,5,30,''],
 ['rallyevo','Rally 4x4 Evo','car','rally','B',640,210,20,182,190,186,204,105,125,112,125,5,38,''],
 ['trophy','Desert Trophy Truck','car','truck','A',1250,350,26,300,280,252,410,90,138,100,105,6,46,''],
 ['rallyhyper','Rally Hyper','car','rally','A',1350,370,26,296,312,306,306,108,132,118,130,6,50,''],
 ['monster','Rallycross Monster','car','rally','S',2700,620,34,452,482,452,470,115,140,120,135,7,70,'sp'],
 ['dakar','Raid King T1+','car','truck','S',2600,600,34,462,432,404,570,95,146,105,116,7,66,'sp'],
 // Road bikes
 ['scooter','Scooter 50','bike','scooter','E',40,15,6,22,32,34,28,96,55,76,40,2,16,''],
 ['commuter','Commuter 125','bike','commuter','E',55,0,7,28,33,33,34,100,66,80,45,2,10,'S'],
 ['naked4','Naked 400','bike','naked','D',130,50,10,58,66,64,48,108,50,82,40,3,20,''],
 ['sport3','Sport 300','bike','sport','D',145,55,10,62,62,68,46,114,40,80,35,3,22,''],
 ['cafe','Cafe Racer','bike','cafe','C',240,95,12,100,108,114,84,112,45,85,40,3,34,''],
 ['ss600','Supersport 600','bike','sport','C',290,110,14,118,118,122,88,120,30,82,32,4,28,''],
 ['sidecar','Sidecar Racer','bike','sidecar','B',500,180,18,178,170,198,176,118,40,96,40,4,42,'sp'],
 ['sbk','Superbike 1000','bike','super','B',580,200,18,206,196,184,146,124,25,82,30,5,40,''],
 ['hypernaked','Hyper Naked','bike','naked','B',540,190,18,186,208,190,156,118,40,88,40,4,44,''],
 ['gp250','GP 250 Two-Stroke','bike','gp','A',1100,330,22,292,322,332,196,130,15,80,20,5,46,''],
 ['motogp','GP Prototype','bike','gp','A',1350,370,26,322,322,318,236,134,15,85,20,6,56,''],
 ['comet','Comet RR','bike','gp','S',2700,620,34,482,492,472,340,140,10,92,15,7,76,'sp'],
 // Off-road bikes
 ['trail','Trail 125','bike','trail','E',60,15,7,24,31,31,38,82,100,80,76,2,10,''],
 ['dirt250','Dirt 250','bike','mx','D',135,50,10,52,66,66,54,70,118,82,80,3,18,''],
 ['enduro3','Enduro 300','bike','enduro','D',150,55,11,56,60,62,68,88,112,90,90,3,16,''],
 ['flattrack','Flat Tracker','bike','flat','C',250,95,12,116,110,98,88,85,124,85,70,3,30,''],
 ['supermoto','Supermoto 450','bike','smoto','C',270,100,13,104,116,120,92,110,106,90,72,4,30,''],
 ['mx250f','MX 250F','bike','mx','C',280,105,13,100,124,120,90,72,128,88,86,4,28,''],
 ['raid450','Rally Raid 450','bike','raid','B',560,195,18,182,176,170,196,88,130,95,96,5,34,''],
 ['mx450','MX 450','bike','mx','B',600,205,18,190,214,200,154,72,134,90,90,5,40,''],
 ['hardenduro','Hard Enduro','bike','enduro','A',1150,340,22,270,300,312,306,80,138,100,116,6,44,''],
 ['factorymx','Factory MX','bike','mx','A',1300,360,24,300,332,322,246,75,142,95,96,6,54,''],
 ['mudhawk','Mudhawk X','bike','mx','S',2650,610,32,452,502,492,388,85,150,110,126,7,72,'sp'],
].map(a=>({id:a[0],n:a[1],cls:a[2],kind:a[3],rank:a[4],cost:a[5]*1000,rp:a[6],days:a[7],
  s:{spd:a[8],acc:a[9],hnd:a[10],dur:a[11]},t:{on:a[12],off:a[13],wet:a[14],ice:a[15]},slots:a[16],adv:a[17],un:a[18]}));
D.BODY = Object.fromEntries(D.BODIES.map(b=>[b.id,b]));

// ---------- LAYOUTS (drive types / engine configs) ----------
D.LAYOUTS = [
 {id:'ff',n:'FF',cls:'car',cm:0,rp:0,m:{dur:10},t:{},un:'S',d:'Front engine, front drive. Cheap and durable.'},
 {id:'fr',n:'FR',cls:'car',cm:0.4,rp:0,m:{spd:10,acc:8},t:{off:-10,ice:-15},un:'S',d:'Front engine, rear drive. Quick on tarmac, poor on bad roads.'},
 {id:'mr',n:'MR',cls:'car',cm:0.65,rp:60,m:{spd:12,hnd:12},t:{off:-15,ice:-15,wet:-5},un:'',d:'Mid engine. Fast and nimble, hates loose surfaces.'},
 {id:'rr',n:'RR',cls:'car',cm:0.55,rp:80,m:{acc:15,hnd:5,dur:-5},t:{wet:-10},un:'sp',d:'Rear engine. Big traction off the line, twitchy in rain.'},
 {id:'awd',n:'4WD',cls:'car',cm:0.9,rp:120,m:{acc:10,dur:10,spd:-5},t:{off:20,ice:20,wet:10},un:'sp',d:'All-wheel drive. King of dirt, snow and rain.'},
 {id:'hyb',n:'Hybrid',cls:'car',cm:1.2,rp:300,m:{spd:8,acc:20},t:{wet:5},un:'sp',d:'Electric boost. Brutal acceleration.'},
 {id:'single',n:'Single',cls:'bike',cm:0,rp:0,m:{hnd:10,acc:5,spd:-5},t:{off:10},un:'S',d:'Thumper single. Light and torquey off-road.'},
 {id:'twin',n:'P-Twin',cls:'bike',cm:0.3,rp:0,m:{dur:8,acc:5},t:{},un:'S',d:'Parallel twin. Reliable all-rounder.'},
 {id:'stroke2',n:'2-Stroke',cls:'bike',cm:0.4,rp:70,m:{acc:20,dur:-15},t:{off:10},un:'sp',d:'Ring-ding! Explosive but fragile.'},
 {id:'vtwin',n:'V-Twin',cls:'bike',cm:0.5,rp:100,m:{acc:15,dur:10,hnd:-5},t:{wet:5},un:'sp',d:'Torque monster with a great sound.'},
 {id:'triple',n:'Triple',cls:'bike',cm:0.6,rp:160,m:{spd:8,acc:10},t:{},un:'sp',d:'Three cylinders, best of both worlds.'},
 {id:'inline4',n:'Inline-4',cls:'bike',cm:0.8,rp:140,m:{spd:18,acc:5},t:{off:-15},un:'sp',d:'Screaming top end. Tarmac only, please.'},
 {id:'elec',n:'Electric',cls:'bike',cm:1.1,rp:320,m:{acc:25,spd:5,dur:-5},t:{wet:5},un:'sp',d:'Silent, instant torque.'},
];
D.LAYOUT = Object.fromEntries(D.LAYOUTS.map(l=>[l.id,l]));

// ---------- PARTS ----------
D.PART_CATS = {eng:'Engine',exh:'Exhaust',ful:'Fuel',gbx:'Gearbox',tir:'Tires',sus:'Suspension',brk:'Brakes',aer:'Aero',chs:'Chassis',ele:'Electronics',spc:'Special'};
D.PART_TIER_COST = [15,40,100,220,480,900];
D.PART_TIER_RP = [8,20,45,90,160,260];
D.PART_TIER_WS = [1,1,2,3,4,4];
// [id,name,cat,cls(C/B/A),tier,stats,fx,unlock]
D.PARTS = [
 ['tuneup','Tune-Up Kit','eng','A',0,{spd:6,acc:4}],
 ['turbo','Turbo Kit','eng','C',1,{spd:16,acc:10,dur:-4}],
 ['bigbore','Big Bore Kit','eng','B',1,{spd:12,acc:14}],
 ['twinturbo','Twin Turbo','eng','C',2,{spd:34,acc:20}],
 ['racecams','Race Cams','eng','B',2,{spd:28,acc:28}],
 ['builtmotor','Built Motor','eng','A',3,{spd:60,acc:40,dur:10}],
 ['worksengine','Works Engine','eng','A',4,{spd:100,acc:80}],
 ['rocketheart','Rocket Heart','eng','A',5,{spd:165,acc:135},null,'sp'],
 ['straightpipe','Straight Pipe','exh','A',0,{acc:6,spd:2,adv:2}],
 ['sportexh','Sport Exhaust','exh','A',1,{acc:12,spd:8}],
 ['expchamber','Expansion Chamber','exh','B',2,{acc:34,spd:6}],
 ['tiheaders','Titanium Headers','exh','C',2,{acc:26,spd:12}],
 ['raceexh','Race Exhaust','exh','A',3,{acc:50,spd:30}],
 ['tiworks','Ti Works Exhaust','exh','A',4,{acc:90,spd:52}],
 ['airfilter','Air Filter','ful','A',0,{spd:3,acc:3}],
 ['fuelinj','Fuel Injection','ful','A',1,{spd:10,acc:10,dur:4}],
 ['nitrous','Nitrous Bottle','ful','C',2,{spd:22,acc:40,dur:-10}],
 ['racefuel','Race Fuel System','ful','A',3,{spd:42,acc:42}],
 ['methanol','Methanol Mapping','ful','A',4,{spd:72,acc:72}],
 ['shortshift','Short Shifter','gbx','A',0,{acc:6}],
 ['closeratio','Close-Ratio Box','gbx','A',1,{acc:16,spd:4}],
 ['quickshift','Quickshifter','gbx','A',2,{acc:30,hnd:6}],
 ['seqbox','Sequential Box','gbx','C',3,{acc:56,spd:14}],
 ['slipper','Slipper Clutch','gbx','B',3,{acc:44,hnd:22}],
 ['seamless','Seamless Gearbox','gbx','A',4,{acc:96,spd:26}],
 ['streettire','Street Tires','tir','A',0,{on:5,wet:5}],
 ['knobby','Knobby Tires','tir','A',0,{off:20,on:-10,ice:5}],
 ['sporttire','Sport Tires','tir','A',1,{on:12,hnd:8,wet:-5}],
 ['raintire','Rain Tires','tir','A',1,{wet:26,on:-3}],
 ['studs','Studded Tires','tir','A',1,{ice:36,on:-10}],
 ['slicks','Racing Slicks','tir','A',2,{on:22,hnd:20,wet:-20,off:-20}],
 ['mudtire','Mud Terrain','tir','A',2,{off:28,dur:10,on:-12}],
 ['alltire','All-Terrain Tires','tir','A',2,{off:14,ice:14,wet:10,on:-2}],
 ['softcomp','Soft Compound','tir','A',3,{on:28,hnd:40,dur:-10}],
 ['deserttire','Desert Tires','tir','A',3,{off:34,dur:22}],
 ['icespike','Ice Spikes Pro','tir','A',4,{ice:60,wet:10,off:10}],
 ['omnigrip','Omni-Grip','tir','A',5,{on:20,off:20,wet:20,ice:20,hnd:40},null,'sp'],
 ['lowering','Lowering Springs','sus','A',0,{hnd:6,off:-5}],
 ['coilover','Coilovers','sus','A',1,{hnd:16,on:3}],
 ['longtravel','Long-Travel Kit','sus','A',1,{off:14,dur:10,hnd:4}],
 ['adjdamp','Adjustable Dampers','sus','A',2,{hnd:30,dur:6}],
 ['rallystrut','Rally Struts','sus','A',3,{off:20,hnd:30,dur:30}],
 ['racesus','Race Suspension','sus','A',3,{hnd:56,on:6}],
 ['activesus','Active Suspension','sus','A',4,{hnd:92,off:10,wet:8}],
 ['braided','Braided Lines','brk','A',0,{hnd:5}],
 ['bigbrake','Big Brake Kit','brk','A',1,{hnd:12,acc:4}],
 ['carbonpad','Carbon Pads','brk','A',2,{hnd:24,dur:4}],
 ['ceramic','Carbon-Ceramic','brk','A',3,{hnd:46,dur:10}],
 ['racecaliper','Racing Calipers','brk','A',4,{hnd:82}],
 ['splitter','Front Splitter','aer','C',1,{hnd:10,on:4,spd:4}],
 ['fairing','Race Fairing','aer','B',1,{spd:14}],
 ['gtwing','GT Wing','aer','C',2,{hnd:26,on:6,spd:-4}],
 ['winglets','Winglets','aer','B',2,{hnd:20,spd:10}],
 ['diffuser','Diffuser','aer','C',3,{hnd:40,spd:20}],
 ['groundfx','Ground Effect Kit','aer','A',4,{hnd:72,spd:42}],
 ['rollcage','Roll Cage','chs','C',0,{dur:14}],
 ['crashbars','Crash Bars','chs','B',0,{dur:10,off:3}],
 ['bracing','Frame Bracing','chs','A',1,{dur:12,hnd:8}],
 ['lightpanel','Lightweight Panels','chs','A',2,{acc:18,hnd:12,dur:-6}],
 ['skidplate','Skid Plates','chs','A',2,{dur:30,off:8}],
 ['carbonchs','Carbon Chassis','chs','A',3,{acc:30,hnd:30,spd:10}],
 ['monocoque','Monocoque','chs','A',4,{dur:84,hnd:40,acc:30}],
 ['datalog','Data Logger','ele','A',1,{},{rp:0.15}],
 ['tc','Traction Control','ele','A',2,{wet:12,hnd:14,off:5}],
 ['launch','Launch Control','ele','A',3,{acc:50}],
 ['icemap','Ice Mapping ECU','ele','A',3,{ice:22,wet:10}],
 ['aipit','AI Pit Wall','ele','A',5,{spd:34,acc:34,hnd:34},{mis:0.7},'sp'],
 ['livery','Sponsor Livery','spc','A',1,{adv:20},{fan:0.15}],
 ['lucky','Lucky Charm','spc','A',2,{},{mis:0.65}],
 ['repairkit','Field Repair Kit','spc','A',3,{},{wear:0.78}],
 ['nitroboost','Nitro Boost System','spc','A',4,{acc:44,spd:44}],
 ['goldwrench','Golden Wrench','spc','A',5,{spd:45,acc:45,hnd:45,dur:45},{wear:0.85},'sp'],
].map(a=>({id:a[0],n:a[1],cat:a[2],cls:a[3],tier:a[4],st:a[5],fx:a[6]||{},un:a[7]||'',
  cost:D.PART_TIER_COST[a[4]]*1000,rp:D.PART_TIER_RP[a[4]]}));
D.PART = Object.fromEntries(D.PARTS.map(p=>[p.id,p]));

// ---------- RACES ----------
D.DISC = {
  CR:{n:'Road Car',cls:'car',ic:'🏎️'}, CO:{n:'Off-Road Car',cls:'car',ic:'🚙'},
  BR:{n:'Road Bike',cls:'bike',ic:'🏍️'}, BO:{n:'Dirt Bike',cls:'bike',ic:'🛵'},
  OP:{n:'Open (any)',cls:'any',ic:'🏁'},
};
D.TIER_N = ['','Rookie','National','Continental','World','Legend'];
// [id,name,tier,disc,surf,style,laps,R,prizeK,rp]
D.RACES = [
 // ---- Tier 1 ----
 ['c1a','Parking Lot Sprint',1,'CR','tar','street',2,28,30,10],
 ['c1b','Main Street Classic',1,'CR','tar','street',2,38,45,13],
 ['c1c','Fairgrounds Road Course',1,'CR','tar','circuit',2,50,60,16],
 ['o1a','County Fair Dirt Dash',1,'CO','dirt','oval',3,28,30,10],
 ['o1b','Gravel Pit Rally',1,'CO','dirt70 mud30','rally',1,38,45,13],
 ['o1c','Frostbite Hillclimb',1,'CO','snow','hill',1,50,60,16],
 ['b1a','Moped Madness',1,'BR','tar','street',2,26,30,10],
 ['b1b','River Road Rumble',1,'BR','tar60 wet40','circuit',2,36,45,13],
 ['b1c','Old Airfield Sprint',1,'BR','tar','speed',2,48,60,16],
 ['d1a','Cornfield Scramble',1,'BO','dirt60 mud40','mx',2,26,30,10],
 ['d1b','Creekbed Hare Scramble',1,'BO','mud50 dirt50','enduro',1,36,45,13],
 ['d1c','Sandpit Showdown',1,'BO','sand','mx',2,48,60,16],
 ['p1a','Barnyard Free-for-All',1,'OP','dirt50 tar50','mixed',2,44,55,15],
 ['p1b','Rainy Day Derby',1,'OP','wet60 mud40','mixed',2,56,70,18],
 ['c1x1','Lakeside Loop',1,'CR','tar','circuit',2,58,60,16],
 ['c1x2','Harvest Grand Prix',1,'CR','tar','tech',3,68,80,20],
 ['o1x1','Quarry Run',1,'CO','dirt','rally',1,58,60,16],
 ['o1x2','Pumpkin Patch Rally',1,'CO','dirt60 mud40','rally',1,68,80,20],
 ['b1x1','Downtown Dash',1,'BR','tar','street',3,58,60,16],
 ['b1x2','Bridge Bash',1,'BR','tar50 wet50','circuit',2,68,80,20],
 ['d1x1','Hay Bale Supercross',1,'BO','dirt','mx',3,58,60,16],
 ['d1x2','Muddy Monday',1,'BO','mud','mx',2,68,80,20],
 // ---- Tier 2 ----
 ['c2a','Twin Rivers Raceway',2,'CR','tar','circuit',3,70,130,30],
 ['c2b','Harbor Street Circuit',2,'CR','tar','street',3,107,170,38],
 ['c2c','Thunder Valley Speedway',2,'CR','tar','oval',4,151,210,46],
 ['o2a','Pine Forest Stages',2,'CO','dirt','rally',1,74,130,30],
 ['o2b','Red Canyon Rally',2,'CO','dirt60 sand40','rally',1,114,170,38],
 ['o2c','Snowbound Sprint',2,'CO','snow60 ice40','rally',1,158,210,46],
 ['b2a','Coastal Sweepers',2,'BR','tar','speed',3,71,130,30],
 ['b2b','Tunnel Twisties',2,'BR','tar','tech',3,110,170,38],
 ['b2c','Monsoon Mile',2,'BR','wet','circuit',3,154,210,46],
 ['d2a','Ridge MX Park',2,'BO','dirt','mx',3,73,130,30],
 ['d2b','Black Swamp Enduro',2,'BO','mud','enduro',1,111,170,38],
 ['d2c','Hoosier Half-Mile',2,'BO','dirt','oval',4,157,210,46],
 ['p2a','Supermoto Showdown',2,'OP','tar50 dirt50','mixed',3,122,200,42],
 ['p2b','Mountain Madness',2,'OP','tar30 dirt40 snow30','mixed',2,181,260,52],
 ['c2x1','Capital Loop',2,'CR','tar','circuit',3,181,240,50],
 ['c2x2','National Finale Raceway',2,'CR','tar','speed',4,210,300,58],
 ['o2x1','Lakeland Gravel',2,'CO','dirt','rally',1,181,240,50],
 ['o2x2','Blizzard Pass',2,'CO','snow50 ice50','rally',1,210,300,58],
 ['b2x1','Hilltop Circuit',2,'BR','tar','tech',3,181,240,50],
 ['b2x2','Rainmaker GP',2,'BR','wet70 tar30','circuit',3,210,300,58],
 ['d2x1','Thunder Hill MX',2,'BO','dirt','mx',3,181,240,50],
 ['d2x2','Sand Dune Nationals',2,'BO','sand','mx',3,210,300,58],
 ['p2x1','Badlands Brawl',2,'OP','dirt50 sand50','mixed',2,151,220,46],
 ['p2x2','Fogbank Frenzy',2,'OP','wet50 mud50','mixed',2,195,280,54],
 ['p2x3','Grand Gauntlet',2,'OP','tar40 dirt30 snow30','mixed',2,225,320,60],
 // ---- Tier 3 ----
 ['c3a','Sunset Coast Circuit',3,'CR','tar','speed',3,230,400,70],
 ['c3b','Castle Hill Ring',3,'CR','tar','tech',3,320,520,85],
 ['c3c','Neon Night Street Race',3,'CR','tar','street',3,410,640,100],
 ['o3a','Highland Forest Rally',3,'CO','dirt60 wet40','rally',1,238,400,70],
 ['o3b','Great Desert Stage',3,'CO','sand','desert',1,328,520,85],
 ['o3c','Arctic Circle Rally',3,'CO','ice50 snow50','rally',1,418,640,100],
 ['b3a','Ocean Cliff Circuit',3,'BR','tar','speed',3,233,400,70],
 ['b3b','Old Town Street Race',3,'BR','tar','street',3,323,520,85],
 ['b3c','Typhoon Ring',3,'BR','wet','circuit',3,413,640,100],
 ['d3a','Volcano MX',3,'BO','dirt60 sand40','mx',3,236,400,70],
 ['d3b','Iron Mountain Enduro',3,'BO','mud50 dirt50','enduro',1,326,520,85],
 ['d3c','Stadium Supercross',3,'BO','dirt','mx',4,416,640,100],
 ['p3a','Mixed Surface Mayhem',3,'OP','tar40 dirt30 wet30','mixed',3,350,600,95],
 ['p3b','Cloud Summit Climb',3,'OP','tar40 dirt30 snow30','hill',1,470,750,115],
 ['c3x1','Eagle Ridge Endurance',3,'CR','tar','circuit',5,485,700,110],
 ['c3x2','Continental Crown',3,'CR','tar','speed',4,545,820,125],
 ['o3x1','Salt Flat Dash',3,'CO','sand','desert',1,485,700,110],
 ['o3x2','Glacier Stage',3,'CO','ice','rally',1,545,820,125],
 ['b3x1','Mountain Rose Ring',3,'BR','tar','tech',3,485,700,110],
 ['b3x2','Grand Coast Finale',3,'BR','tar','speed',4,545,820,125],
 ['d3x1','Rocky Gorge Extreme',3,'BO','dirt50 mud50','enduro',1,485,700,110],
 ['d3x2','Six Days Trial',3,'BO','dirt40 mud30 wet30','enduro',2,545,820,125],
 ['p3x1','Jungle Jamboree',3,'OP','mud50 wet50','mixed',2,410,680,105],
 ['p3x2','Tundra Two-Step',3,'OP','snow50 tar50','mixed',2,500,760,118],
 ['p3x3','Masters Finale',3,'OP','tar30 dirt30 sand20 wet20','mixed',3,560,850,128],
 // ---- Tier 4 ----
 ['c4a','Grand Harbor Prix',4,'CR','tar','street',3,600,1000,150],
 ['c4b','Temple Ring',4,'CR','tar','tech',3,760,1300,180],
 ['c4c','Autobahn Speedway',4,'CR','tar','speed',4,921,1600,210],
 ['o4a','Monte Mountain Rally',4,'CO','tar50 snow50','rally',1,611,1000,150],
 ['o4b','Great Sand Sea Raid',4,'CO','sand','desert',1,772,1300,180],
 ['o4c','Midnight Sun Rally',4,'CO','ice50 snow50','rally',1,932,1600,210],
 ['b4a','Island TT',4,'BR','tar','speed',1,606,1000,150],
 ['b4b','Lightning Ring',4,'BR','tar','circuit',3,766,1300,180],
 ['b4c','Grand Monsoon GP',4,'BR','wet','circuit',3,927,1600,210],
 ['d4a','World MX Opener',4,'BO','dirt','mx',3,609,1000,150],
 ['d4b','Iron Peak Hare Scramble',4,'BO','dirt50 mud50','enduro',1,770,1300,180],
 ['d4c','Supercross Spectacular',4,'BO','dirt','mx',4,930,1600,210],
 ['p4a','World Terrain Trophy',4,'OP','tar30 dirt30 sand20 snow20','mixed',3,864,1700,215],
 ['p4b','Rainbow Bridge Run',4,'OP','tar40 wet30 snow30','mixed',2,1035,2000,240],
 ['c4x1','Royal Park Grand Prix',4,'CR','tar','tech',4,1012,1800,230],
 ['c4x2','World Finale GP',4,'CR','tar','speed',5,1104,2200,260],
 ['o4x1','Forest Kingdom Rally',4,'CO','dirt','rally',1,1012,1800,230],
 ['o4x2','Ice Kingdom Rally',4,'CO','ice','rally',1,1104,2200,260],
 ['b4x1','Sakura Ring',4,'BR','tar','tech',4,1012,1800,230],
 ['b4x2','Moto World Finale',4,'BR','tar','speed',5,1104,2200,260],
 ['d4x1','Desert Night SX',4,'BO','sand50 dirt50','mx',4,1012,1800,230],
 ['d4x2','World SX Final',4,'BO','dirt','mx',5,1104,2200,260],
 ['p4x1','Festival of Speed',4,'OP','tar','hill',1,944,1800,225],
 ['p4x2','Continental Crossing',4,'OP','tar25 dirt25 sand25 snow25','mixed',3,1058,2100,250],
 ['p4x3','Festival Grand Finale',4,'OP','tar30 dirt20 wet20 snow15 mud15','mixed',4,1150,2400,280],
 // ---- Legend ----
 ['l5a','Volcano Island GP',5,'OP','tar50 dirt50','mixed',3,1250,3000,320],
 ['l5b','Sky Highway',5,'OP','tar','speed',4,1531,4000,380],
 ['l5c','Glacier Planet Rally',5,'OP','ice50 snow50','mixed',2,1812,5000,440],
 ['l5x1','Thunderdome Mixed',5,'OP','tar25 dirt25 mud25 wet25','mixed',3,1719,4500,420],
 ['l5x2','Ultimate Crown',5,'OP','tar20 dirt20 sand20 wet20 ice20','mixed',5,2000,6000,500],
].map(a=>{
  const surf={}; a[4].split(' ').forEach(tok=>{const m=tok.match(/^([a-z]+)(\d*)$/); surf[m[1]]=m[2]?+m[2]:100;});
  return {id:a[0],n:a[1],tier:a[2],disc:a[3],cls:D.DISC[a[3]].cls,surf,style:a[5],laps:a[6],R:a[7],prize:a[8]*1000,rp:a[9],
    excl:/x\d$/.test(a[0]), letter:(a[0].match(/([abc])$/)||[])[1]||null};
});
D.RACE = Object.fromEntries(D.RACES.map(r=>[r.id,r]));

// ---------- SERIES ----------
// [id,name,tier,disc,rounds,prizeK,feeK,rivals]
D.SERIES = [
 ['s1c','Sunday Sedan Cup',1,'CR',['c1a','c1b','c1c','c1x1','c1x2'],300,20,7],
 ['s1o','Gravel Grinder Cup',1,'CO',['o1a','o1b','o1c','o1x1','o1x2'],300,20,7],
 ['s1b','Two-Stroke Town Cup',1,'BR',['b1a','b1b','b1c','b1x1','b1x2'],300,20,7],
 ['s1d','Cornfield MX Cup',1,'BO',['d1a','d1b','d1c','d1x1','d1x2'],300,20,7],
 ['s2c','Touring Car Nationals',2,'CR',['c2a','c2b','c2c','c2x1','c2x2'],900,80,9],
 ['s2o','National Rally Series',2,'CO',['o2a','o2b','o2c','o2x1','o2x2'],900,80,9],
 ['s2b','Supersport Nationals',2,'BR',['b2a','b2b','b2c','b2x1','b2x2'],900,80,9],
 ['s2d','Motocross Nationals',2,'BO',['d2a','d2b','d2c','d2x1','d2x2'],900,80,9],
 ['s2p','All-Terrain Open',2,'OP',['p2a','p2x1','p2b','p2x2','p2x3'],1000,90,9],
 ['s3c','GT Continental',3,'CR',['c3a','c3b','c3c','c3x1','c3x2'],2500,250,11],
 ['s3o','Continental Rally Raid',3,'CO',['o3a','o3b','o3c','o3x1','o3x2'],2500,250,11],
 ['s3b','Superbike Continental',3,'BR',['b3a','b3b','b3c','b3x1','b3x2'],2500,250,11],
 ['s3d','Enduro Continental',3,'BO',['d3a','d3b','d3c','d3x1','d3x2'],2500,250,11],
 ['s3p','Mixed Masters',3,'OP',['p3a','p3x1','p3b','p3x2','p3x3'],2800,280,11],
 ['s4c','Formula Grand Prix',4,'CR',['c4a','c4b','c4c','c4x1','c4x2'],6000,600,11],
 ['s4o','World Rally Cup',4,'CO',['o4a','o4b','o4c','o4x1','o4x2'],6000,600,11],
 ['s4b','Moto Grand Prix',4,'BR',['b4a','b4b','b4c','b4x1','b4x2'],6000,600,11],
 ['s4d','Supercross World Cup',4,'BO',['d4a','d4b','d4c','d4x1','d4x2'],6000,600,11],
 ['s4p','World Motorsport Festival',4,'OP',['p4a','p4x1','p4b','p4x2','p4x3'],7000,700,11],
 ['s5l','King of All Terrain',5,'OP',['l5a','l5b','l5x1','l5c','l5x2'],15000,1500,11],
].map(a=>({id:a[0],n:a[1],tier:a[2],disc:a[3],cls:D.DISC[a[3]].cls,rounds:a[4],prize:a[5]*1000,fee:a[6]*1000,rivals:a[7]}));
D.SER = Object.fromEntries(D.SERIES.map(s=>[s.id,s]));
D.POINTS = [15,12,10,8,6,5,4,3,2,1];
D.PRIZE_SPLIT = [1,0.5,0.3,0.2,0.15,0.12,0.1,0.08,0.06,0.05,0.04,0.03];

// ---------- WORKSHOPS ----------
D.WORKSHOPS = [null,
 {n:'Backyard Shed',teams:1,mech:2,veh:2,fac:2,spon:2,cost:0},
 {n:'Town Garage',teams:2,mech:5,veh:4,fac:4,spon:3,cost:400000},
 {n:'Race Workshop',teams:3,mech:8,veh:6,fac:6,spon:4,cost:2000000},
 {n:'Factory HQ',teams:4,mech:12,veh:10,fac:9,spon:5,cost:8000000},
];

// ---------- TRAINING ----------
// [id,name,costK,energy,gains,unlock]
D.TRAINING = [
 ['jog','Jog',20,15,{pedal:3,shift:2},'S'],
 ['kartlaps','Kart Laps',30,15,{shift:2,steer:3},'S'],
 ['study','Study Manuals',20,10,{tech:3,analysis:2},'S'],
 ['fanmeet','Fan Meet',15,10,{appeal:4},'S'],
 ['oddjobs','Odd Jobs',-12,15,{},'S'],
 ['drag','Drag Strip',45,20,{pedal:7},'sp'],
 ['skid','Skid Pad',45,20,{steer:7},'sp'],
 ['geardrill','Gear Drills',45,20,{shift:7},'sp'],
 ['mxcamp','Motocross Camp',60,25,{steer:4,shift:4,bike:0.02},'sp'],
 ['rallyschool','Rally School',60,25,{steer:5,pedal:3,car:0.02},'sp'],
 ['icedrive','Ice Driving',55,20,{steer:4,analysis:4},'sp'],
 ['rainschool','Rain School',50,20,{steer:4,shift:3},'sp'],
 ['dataseminar','Data Seminar',60,15,{analysis:8},'sp'],
 ['talkshow','Talk Show',50,10,{appeal:10},'sp'],
 ['enduroclinic','Enduro Clinic',55,25,{shift:5,steer:3,tech:2},'sp'],
 ['gymbig','Strength Camp',80,30,{maxE:5},'sp'],
 ['simulator','Pro Simulator',160,30,{pedal:6,shift:6,steer:6},'sp'],
 ['zen','Zen Retreat',200,20,{pedal:4,shift:4,steer:4,appeal:4,tech:4,analysis:4},'sp'],
 ['astro','Astronaut Program',600,40,{pedal:10,shift:10,steer:10,appeal:10,tech:10,analysis:10},'sp'],
].map(a=>({id:a[0],n:a[1],cost:a[2]*1000,en:a[3],g:a[4],un:a[5]}));
D.TRAIN = Object.fromEntries(D.TRAINING.map(t=>[t.id,t]));

// ---------- FACILITIES ----------
// effect value per level [l1,l2,l3]
D.FACILITIES = [
 {id:'dyno',n:'Dyno Room',ic:'⚙',col:'#c0392b',d:'Builds & upgrades: +Speed',fx:'bSpd',v:[6,12,18],cost:[80,250,700],un:'S'},
 {id:'tunnel',n:'Wind Tunnel',ic:'≋',col:'#2980b9',d:'Builds & upgrades: +Handling',fx:'bHnd',v:[6,12,18],cost:[80,250,700],un:'S'},
 {id:'gearbench',n:'Gearbox Bench',ic:'⚒',col:'#8e44ad',d:'Builds & upgrades: +Accel',fx:'bAcc',v:[6,12,18],cost:[80,250,700],un:'S'},
 {id:'stress',n:'Stress Rig',ic:'▣',col:'#7f8c8d',d:'Builds & upgrades: +Durability',fx:'bDur',v:[8,16,24],cost:[80,250,700],un:'sp'},
 {id:'tarstrip',n:'Tarmac Test Strip',ic:'═',col:'#555',d:'New builds: +On-Road',fx:'tOn',v:[5,10,15],cost:[100,300,800],un:'S'},
 {id:'dirtyard',n:'Dirt Test Yard',ic:'⛰',col:'#a0522d',d:'New builds: +Off-Road',fx:'tOff',v:[5,10,15],cost:[100,300,800],un:'sp'},
 {id:'skidpad',n:'Wet Skid Pad',ic:'☂',col:'#34698f',d:'New builds: +Wet',fx:'tWet',v:[5,10,15],cost:[100,300,800],un:'sp'},
 {id:'cold',n:'Cold Chamber',ic:'❄',col:'#7fc7e0',d:'New builds: +Icy',fx:'tIce',v:[5,10,15],cost:[100,300,800],un:'sp'},
 {id:'telemetry',n:'Telemetry Room',ic:'▤',col:'#16a085',d:'+Research data from races',fx:'rp',v:[15,30,45],cost:[120,350,900],un:'sp'},
 {id:'gym',n:'Gym',ic:'♥',col:'#e67e22',d:'+Training gains',fx:'train',v:[20,40,60],cost:[90,260,700],un:'S'},
 {id:'lounge',n:'Driver Lounge',ic:'☕',col:'#d35400',d:'+Energy regen per day',fx:'regen',v:[1,1.5,2],cost:[70,200,550],un:'S'},
 {id:'media',n:'Media Room',ic:'✉',col:'#f1c40f',d:'+Fans from races',fx:'fans',v:[15,30,45],cost:[120,350,900],un:'sp'},
 {id:'merch',n:'Merch Stand',ic:'$',col:'#27ae60',d:'Monthly income from fans',fx:'merch',v:[0.5,1,1.5],cost:[100,300,800],un:'S'},
 {id:'fab',n:'Fab Shop',ic:'✂',col:'#95a5a6',d:'+Build/repair speed',fx:'speed',v:[15,30,45],cost:[110,320,850],un:'sp'},
 {id:'scout',n:'Scout Office',ic:'⌕',col:'#9b59b6',d:'Better hiring candidates',fx:'scout',v:[1,2,3],cost:[100,300,800],un:'S'},
 {id:'depot',n:'Parts Depot',ic:'▦',col:'#2c3e50',d:'Parts cost less',fx:'partdisc',v:[10,20,30],cost:[120,350,900],un:'S'},
 {id:'sponlounge',n:'Sponsor Lounge',ic:'★',col:'#e84393',d:'+Sponsor monthly pay',fx:'spon',v:[10,20,30],cost:[150,400,1000],un:'sp'},
];
D.FAC = Object.fromEntries(D.FACILITIES.map(f=>[f.id,f]));

// ---------- SPONSORS ----------
// goal types: enter(n) win(n,disc?,tier?,surf?) podium(n) series(n,tier?,disc?) fans(n) money(n) races(n)
D.SPONSORS = [
 {id:'cornoil',n:'Corn Belt Oil',fans:0,sign:30,mo:8,goal:{t:'enter',n:3},rw:{train:['drag']},bl:'Keeping engines slick since forever.'},
 {id:'momtires',n:'Mom & Pop Tires',fans:0,sign:20,mo:6,goal:{t:'win',n:1},rw:{train:['skid'],fac:['stress']},bl:'Family owned, mostly round.'},
 {id:'hotdog',n:'Hot Dog Hut',fans:150,sign:40,mo:10,goal:{t:'podium',n:3},rw:{train:['geardrill'],layout:['stroke2']},bl:'Snappy dogs, snappy laps.'},
 {id:'gearhead',n:'Gearhead Monthly',fans:300,sign:50,mo:12,goal:{t:'win',n:1,cls:'bike'},rw:{train:['mxcamp'],fac:['dirtyard']},bl:'The magazine your mechanic hides.'},
 {id:'rallytea',n:'Rally Tea',fans:300,sign:50,mo:12,goal:{t:'win',n:1,disc:'CO'},rw:{train:['rallyschool'],layout:['awd']},bl:'Steeped in gravel.'},
 {id:'bolt',n:'Bolt Hardware',fans:600,sign:70,mo:15,goal:{t:'series',n:1},rw:{layout:['rr'],fac:['fab']},bl:'Nuts about racing.'},
 {id:'frosty',n:'Frosty Pops',fans:800,sign:60,mo:14,goal:{t:'win',n:1,surf:'ice'},rw:{train:['icedrive'],fac:['cold']},bl:'Brain freeze, any season.'},
 {id:'drizzle',n:'Drizzle Coats',fans:1000,sign:60,mo:15,goal:{t:'win',n:1,surf:'wet'},rw:{train:['rainschool'],fac:['skidpad']},bl:'Wet? Never heard of it.'},
 {id:'pixelnet',n:'PixelNet ISP',fans:1500,sign:90,mo:20,goal:{t:'fans',n:3000},rw:{train:['dataseminar'],fac:['telemetry']},bl:'Low ping, high speed.'},
 {id:'vroomcola',n:'Vroom Cola',fans:2500,sign:120,mo:26,goal:{t:'podium',n:12},rw:{train:['talkshow'],layout:['vtwin'],fac:['media']},bl:'Zero calories, all throttle.'},
 {id:'mudpuppy',n:'Mud Puppy Boots',fans:3500,sign:140,mo:30,goal:{t:'win',n:3,surf:'off'},rw:{train:['enduroclinic'],body:['sidecar']},bl:'Boots that love a bog.'},
 {id:'turbojoe',n:"Turbo Joe's Diner",fans:5000,sign:180,mo:36,goal:{t:'series',n:1,tier:2},rw:{train:['gymbig'],layout:['inline4']},bl:'Bottomless coffee, boosted.'},
 {id:'ironhorse',n:'Iron Horse Insurance',fans:7000,sign:220,mo:42,goal:{t:'races',n:40},rw:{fac:['sponlounge'],cash:500}, bl:'We cover crashes. Mostly.'},
 {id:'skyline',n:'Skyline Airways',fans:10000,sign:300,mo:55,goal:{t:'win',n:1,tier:3},rw:{layout:['triple']},bl:'Fly like you drive.'},
 {id:'quantum',n:'Quantum Chips',fans:15000,sign:400,mo:70,goal:{t:'series',n:1,tier:3},rw:{layout:['hyb'],train:['simulator']},bl:'Computing at the speed of sound.'},
 {id:'maplebank',n:'Maple Bank',fans:20000,sign:500,mo:85,goal:{t:'money',n:10000000},rw:{cash:2000},bl:'Your money, on pole position.'},
 {id:'kaboom',n:'Kaboom Fireworks',fans:30000,sign:600,mo:100,goal:{t:'win',n:60},rw:{train:['zen']},bl:'Every win deserves a boom.'},
 {id:'glacier',n:'Glacier Water',fans:40000,sign:700,mo:120,goal:{t:'win',n:1,tier:4},rw:{layout:['elec']},bl:'Cool under pressure.'},
 {id:'apex',n:'Apex Motors',fans:60000,sign:900,mo:150,goal:{t:'series',n:1,tier:4,disc:'CR'},rw:{body:['arrow','hyper']},bl:'Engineering the impossible.'},
 {id:'dunecorp',n:'Dune Corp',fans:60000,sign:900,mo:150,goal:{t:'series',n:1,tier:4,disc:'CO'},rw:{body:['monster','dakar']},bl:'Sand is just slow road.'},
 {id:'thunder',n:'Thunder Energy',fans:60000,sign:900,mo:150,goal:{t:'series',n:1,tier:4,disc:'BR'},rw:{body:['comet']},bl:'Lightning in a can.'},
 {id:'mudking',n:'Mud King Gear',fans:60000,sign:900,mo:150,goal:{t:'series',n:1,tier:4,disc:'BO'},rw:{body:['mudhawk']},bl:'Long live the king of dirt.'},
 {id:'goldwrench',n:'Golden Wrench Co.',fans:100000,sign:1500,mo:220,goal:{t:'series',n:2,tier:4},rw:{part:['goldwrench','rocketheart','omnigrip','aipit']},bl:'For legends only.'},
 {id:'cosmos',n:'Cosmos Space Agency',fans:150000,sign:2500,mo:300,goal:{t:'series',n:1,tier:5},rw:{train:['astro'],cash:10000},bl:'Next stop: orbit.'},
];
D.SPON = Object.fromEntries(D.SPONSORS.map(s=>[s.id,s]));

// ---------- FANS RANKS ----------
D.FAN_RANKS = [[0,'Unknown'],[300,'Local'],[1500,'Regional'],[6000,'National'],[20000,'Continental'],[60000,'World'],[200000,'Legendary']];

// ---------- TRAITS ----------
D.TRAITS = {
  dirt:{n:'Dirt Devil',d:'+15 Off-Rd grip'},
  rain:{n:'Rain Master',d:'+20 Wet grip'},
  ice:{n:'Ice Cool',d:'+20 Icy grip'},
  tar:{n:'Tarmac Ace',d:'+10 On-Rd grip'},
  wheelie:{n:'Wheelie King',d:'+10% Accel on bikes'},
  drift:{n:'Drift King',d:'+10% Handling in cars'},
  iron:{n:'Iron Body',d:'Uses less energy'},
  show:{n:'Showboat',d:'+30% fans'},
  steady:{n:'Steady Hands',d:'-40% mistakes'},
  hothead:{n:'Hothead',d:'+4% pace, more mistakes'},
  bloomer:{n:'Late Bloomer',d:'+40% training gains'},
  lucky:{n:'Lucky Star',d:'Finds Sparks more often'},
};

// ---------- NAMES ----------
D.FIRST = ['Ace','Bea','Cal','Dot','Eli','Fern','Gus','Hana','Ike','Jo','Kip','Lou','Max','Nell','Ozzie','Pip','Quinn','Rae','Sid','Tess','Ugo','Vi','Wade','Xia','Yuki','Zed','Bo','Cass','Dex','Edie','Finn','Gil','Hux','Ivy','Jett','Kit','Lark','Moe','Nico','Opal','Remy','Sunny','Tex','Vera','Wren','Ziggy','Dusty','Rusty','Penny','Skip'];
D.LAST = ['Gasket','Throttle','Ramirez','Okafor','Nakamura','Lindqvist','Rossi-ish','McAllister','Pistone','Brakewell','Clutchley','Torres','Kowalski','Haddad','Fenwick','Boltz','Sprocket','Dunlap','Varga','Ishikawa','Moreau','Bauer','Quickley','Hollis','Petrov','Castell','Dempsey','Tanaka','Silva','Grimes','Faraday','Revson','Mudd','Gravelle','Tarmack','Hayes','Okoro','Sandoval','Winslow','Kerr'];
D.HAIR = ['#2b1a12','#5a3214','#c08a3e','#e8d07a','#8a2be2','#c0392b','#222','#ddd','#f39c12','#1e90ff'];
D.SKIN = ['#f5d0a9','#e0ac69','#c68642','#8d5524','#ffdbac'];

D.RIVALS = [
 ['Velocity Rabbits','#e74c3c'],['Iron Mule Racing','#7f8c8d'],['Team Thunderbean','#8e5a2b'],['Crimson Comet','#c0392b'],
 ['Bluegrass Bandits','#2e86de'],['Rustbucket Racing','#b9770e'],['Polar Pistons','#85c1e9'],['Desert Fox GP','#e67e22'],
 ['Sakura Speed','#ff9ff3'],['Nordic Throttle','#1abc9c'],['Pampas Panthers','#6c5ce7'],['Outback Outlaws','#d35400'],
 ['Zephyr Works','#00cec9'],['Kraken Moto','#2d3436'],['Gecko Grip','#55efc4'],['Maple Lightning','#fdcb6e'],
 ['Atlas Torque','#636e72'],['Viper Verde','#27ae60'],['Golden Gearheads','#f1c40f'],['Mudlark MX','#795548'],
 ['Cobalt Rockets','#0652dd'],['Flamingo Flyers','#fd79a8'],
];

D.TEAM_COLORS = ['#e8432f','#2f7de8','#2fb34a','#f2b01e','#9b4de8','#ff7f2a','#1fc6c6','#e84393'];

D.MONTHS = ['Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar'];
D.DAYS_MONTH = 28; D.DAYS_YEAR = 336; D.YEARS = 15;
