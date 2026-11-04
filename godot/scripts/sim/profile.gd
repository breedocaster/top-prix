class_name Prof
extends RefCounted
## Vehicle + driver race profile. Ports of E.vs, E.profile, T.setupMul, T.evalIdeal
## and T.raceSecs(ideal) from the web build. `team` carries {tech:{}, partLv:{}}.
## M1 races are crew-tuned (ideal fueling); the full T.eval model arrives with the benches.

const DIRT_KINDS := ["trail", "mx", "enduro", "raid", "smoto", "flat"]

static func has_tech(team: Dictionary, id: String) -> bool:
	return bool(team.get("tech", {}).get(id, false))

static func part_lv(team: Dictionary, pid: String) -> int:
	return int(team.get("partLv", {}).get(pid, {}).get("lv", 1))

static func qmult(q: float) -> float: return 0.72 + 0.28 * q

## E.vs — effective stats with parts and level.
static func vs(v: Dictionary, team: Dictionary) -> Dictionary:
	var b: Dictionary = Data.body(v.body)
	var s := {}
	for k in ["spd", "acc", "hnd", "dur"]:
		s[k] = float(v.base[k]) + float(v.get("upAdd", {}).get(k, 0))
	var t: Dictionary = v.terr.duplicate()
	var adv := float(b.adv) + float(v.get("advB", 0))
	var fx := {"rp": 0.0, "mis": 1.0, "wear": 1.0, "fan": 0.0}
	for pid in v.get("parts", []):
		var P: Dictionary = Data.part(pid)
		if P.is_empty(): continue
		var lm := 1.0 + 0.1 * (part_lv(team, pid) - 1)
		for k in P.st:
			if s.has(k): s[k] += P.st[k] * lm
			elif t.has(k): t[k] += P.st[k]
			elif k == "adv": adv += P.st[k]
		var pfx: Dictionary = P.get("fx", {})
		if pfx.has("rp"): fx.rp += pfx.rp
		if pfx.has("mis"): fx.mis *= pfx.mis
		if pfx.has("wear"): fx.wear *= pfx.wear
		if pfx.has("fan"): fx.fan += pfx.fan
	var lvm := 1.0 + 0.03 * (int(v.get("lv", 1)) - 1)
	for k in s: s[k] = max(5.0, round(s[k] * lvm))
	for k in t: t[k] = round(clampf(t[k], 5, 220))
	var out := s.duplicate()
	out.merge(t)
	out.adv = adv
	out.fx = fx
	return out

## E.profile — driver skill applied to vehicle stats.
static func profile(v: Dictionary, s: Dictionary, team: Dictionary) -> Dictionary:
	var st := vs(v, team)
	var cls: String = Data.body(v.body).cls
	var aff := float(s.get("aff", {}).get(cls, 1.0))
	var drv_trait = s.get("trait")
	var S: float = st.spd * dm(s.pedal) * aff
	var A: float = st.acc * dm(s.shift) * aff
	var H: float = st.hnd * dm(s.steer) * aff
	if drv_trait == "drift" and cls == "car": H *= 1.1
	if drv_trait == "wheelie" and cls == "bike": A *= 1.1
	var t := {"on": st.on, "off": st.off, "wet": st.wet, "ice": st.ice}
	match drv_trait:
		"dirt": t.off += 15
		"rain": t.wet += 20
		"ice": t.ice += 20
		"tar": t.on += 10
	var pm := 1.0
	if drv_trait == "hothead": pm *= 1.04
	if float(s.get("energy", 100)) < 40: pm *= 0.95
	var mis: float = st.fx.mis
	if drv_trait == "steady": mis *= 0.6
	if drv_trait == "hothead": mis *= 1.6
	var wear: float = st.fx.wear * (0.9 if drv_trait == "iron" else 1.0) * (0.85 if cls == "bike" else 1.0)
	return {"S": S, "A": A, "H": H, "t": t, "pm": pm, "mis": mis, "wear": wear, "dur": st.dur, "cls": cls}

static func dm(x) -> float:
	x = float(x)
	return 1.0 + x / (x + 250.0)

static func stock_ratio(v: Dictionary) -> float:
	return 47.0 / 13.0 if DIRT_KINDS.has(Data.body(v.body).kind) else 45.0 / 16.0

static func stock_psi(v: Dictionary) -> float:
	var b: Dictionary = Data.body(v.body)
	if b.cls == "car": return 32.0
	return 14.0 if DIRT_KINDS.has(b.kind) else 34.0

static func default_setup(body_id: String) -> Dictionary:
	var b: Dictionary = Data.body(body_id)
	if b.cls == "bike":
		return {"f": 13, "r": 47, "susp": 5, "psi": 14} if DIRT_KINDS.has(b.kind) else {"f": 16, "r": 45, "susp": 5, "psi": 34}
	return {"fd": 3.7, "susp": 5, "psi": 32, "wing": 5}

## T.setupMul
static func setup_mul(v: Dictionary, sec: Dictionary, team: Dictionary) -> Dictionary:
	var st: Dictionary = v.get("setup", {})
	var bike: bool = Data.body(v.body).cls == "bike"
	var off: bool = Data.surf(sec.surf).k == "off" or sec.type == "rgh" or sec.type == "jmp"
	var g := 1.0
	if has_tech(team, "gearing"):
		if bike and st.get("f"): g = (float(st.r) / float(st.f)) / stock_ratio(v)
		elif not bike and st.get("fd"): g = float(st.fd) / 3.7
	var S := pow(g, -0.5)
	var A := pow(g, 0.6)
	var H := 1.0
	var tm := 1.0
	if has_tech(team, "adjsus") and st.get("susp") != null:
		var c := float(st.susp) - 5.0
		H *= (1.0 - 0.015 * c) if off else (1.0 + 0.012 * c)
	if has_tech(team, "tirepress") and st.get("psi") != null:
		var sp := stock_psi(v)
		var d := (float(st.psi) - sp) / sp
		tm *= (1.0 - 0.35 * d - 0.6 * d * d) if off else (1.0 + 0.25 * d - 0.9 * d * d)
	if not bike and has_tech(team, "aero") and st.get("wing") != null:
		var w := float(st.wing) - 5.0
		if sec.type == "str": S *= 1.0 - 0.004 * w
		elif sec.type != "lau": H *= 1.0 + 0.006 * w
	return {"S": S, "A": A, "H": H, "tm": tm}

## T.evalIdeal — crew-tuned engine efficiency per zone.
static func eval_ideal(v: Dictionary, team: Dictionary) -> Dictionary:
	var e: Dictionary = v.get("eng", {})
	var lam: Dictionary = Data.D.LAM.duplicate()
	lam.trans = lam.low
	var pw := 1.0
	if not e.is_empty() and e.get("fuel", "none") != "none":
		pw = float(Data.D.FUELS[e.get("fuelT", "pump")].pw)
		pw *= 1.03 if has_tech(team, "porting") else 1.0
		pw *= 1.04 if has_tech(team, "highcomp") else 1.0
		pw *= 0.86 + 0.14 * clampf(float(e.get("cond", 1.0)), 0, 1)
		pw *= 1.05 if e.fuel == "efi" else float(Data.D.CARBS[e.carb].pw)
	var ef := {}
	for z in Data.D.ZONES + ["trans"]: ef[z] = pw * 0.995
	return {"lam": lam, "ef": ef}

## T.raceSecs(..., ideal=true) — per-section multipliers.
static func race_secs(v: Dictionary, tr: Dictionary, team: Dictionary) -> Array:
	var ev := eval_ideal(v, team)
	var efi: bool = v.get("eng", {}).get("fuel", "") == "efi"
	var out := []
	for sec in tr.secs:
		var zw: Dictionary = Data.D.SECZ.get(sec.type, {"wot": 1})
		var ef := 0.0
		var lam := 0.0
		for z in zw:
			ef += zw[z] * ev.ef[z]
			lam += zw[z] * ev.lam[z]
		if sec.type == "lau" and efi and has_tech(team, "launch"): ef *= 1.08
		var sm := setup_mul(v, sec, team)
		out.append({"ef": ef, "s": sm.S, "a": sm.A, "h": sm.H, "t": sm.tm, "kd": 0.0, "lh": 0.0, "lam": lam,
			"starve": false, "flood": false})
	return out

## A ready-to-race vehicle built the way E.finishBuild does (no facility bonuses).
static func make_vehicle(body_id: String, layout_id: String, lv: int = 1, q: float = 1.0, up: Dictionary = {}) -> Dictionary:
	var b: Dictionary = Data.body(body_id)
	var L: Dictionary = Data.layout(layout_id)
	var base := {}
	for k in ["spd", "acc", "hnd", "dur"]:
		base[k] = round(float(b.s[k]) * qmult(q) * (1.0 + float(L.m.get(k, 0)) / 100.0))
	var terr := {}
	for k in ["on", "off", "wet", "ice"]:
		terr[k] = float(b.t[k]) + float(L.t.get(k, 0))
	var cyl = Data.D.LAYOUT_CYL.get(layout_id, 4)
	var eng := {"fuel": "none"} if cyl == 0 else {"fuel": "carb", "carb": "d2" if b.cls == "car" else "pe", "fuelT": "pump", "cond": 1.0}
	var upAdd := {"spd": 0, "acc": 0, "hnd": 0, "dur": 0}
	upAdd.merge(up, true)
	return {"id": 0, "body": body_id, "layout": layout_id, "name": b.n, "lv": lv, "base": base, "terr": terr,
		"upAdd": upAdd, "parts": [], "advB": 0, "setup": default_setup(body_id), "eng": eng, "hp": 1.0}

static func make_driver(name: String, pedal: int, shift: int, steer: int, drv_trait = null, aff_car := 1.0, aff_bike := 1.0) -> Dictionary:
	return {"id": 0, "name": name, "pedal": pedal, "shift": shift, "steer": steer, "trait": drv_trait,
		"energy": 100, "aff": {"car": aff_car, "bike": aff_bike}, "hair": "#3a2a1a"}
