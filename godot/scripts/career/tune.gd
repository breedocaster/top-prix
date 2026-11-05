class_name Tune
extends RefCounted
## Port of web/src/tune.js (the `T` object): carb / EFI fuel model, knock and lean damage,
## race-section factors, crew tune and datalogs. Static; reads tech and mode from Career.G.
## Expressions keep the JS operation order so results match the web build to the last bits.

const T0 := 288.15
const DIRT := ["trail", "mx", "enduro", "raid", "smoto", "flat"]
const ZONES := ["idle", "low", "mid", "wot"]
const ZONES_T := ["idle", "low", "mid", "wot", "trans"]
const PFW := {"idle": 0.3, "low": 0.5, "mid": 0.9, "wot": 1.0, "trans": 0.6}
const ERRW := {"idle": 0.4, "low": 0.8, "mid": 1.2, "wot": 1.6}
## cell weights per zone [load row j, rpm col i, weight]
const ZC := {
	"idle": [[0, 0, 1.0]],
	"low": [[0, 1, 1.0], [0, 2, 1.0], [0, 3, 0.6], [1, 1, 1.0], [1, 2, 1.0], [1, 3, 0.8]],
	"mid": [[2, 2, 1.0], [2, 3, 1.0], [2, 4, 1.0], [2, 5, 0.7], [3, 2, 1.0], [3, 3, 1.0], [3, 4, 1.0], [3, 5, 0.8], [3, 6, 0.5]],
	"wot": [[4, 2, 0.6], [4, 3, 0.9], [4, 4, 1.0], [4, 5, 1.1], [4, 6, 1.1], [4, 7, 1.0], [5, 2, 0.6], [5, 3, 0.9], [5, 4, 1.0], [5, 5, 1.2], [5, 6, 1.2], [5, 7, 1.1]],
}
const SWAP_K := {"pe": 0.05, "cv": 0.06, "pwk": 0.08, "fcr": 0.14, "d2": 0.05, "q4": 0.09, "dcoe": 0.15}

static func D() -> Dictionary: return Data.D

static func has(id: String) -> bool:
	var t = Career.G.get("tech")
	return t is Dictionary and bool(t.get(id, false))

static func mode() -> String:
	var s = Career.G.get("settings")
	if s is Dictionary and s.get("mode"): return s.mode
	return "standard"

static func press(alt: float) -> float: return pow(1 - 2.25577e-5 * alt, 5.25588)
static func dens(alt: float, temp: float) -> float: return press(alt) * (T0 / (273.15 + temp))

## D.condOf: altitude (start/finish), temperature, time of day for a race or test def.
static func condOf(r: Dictionary) -> Dictionary:
	var o = D().COND.get(r.get("id", ""))
	var alt: float; var alt2: float; var temp: float; var tod := "day"
	if o != null:
		alt = o[0]; alt2 = o[1] if (o.size() > 1 and o[1]) else o[0]; temp = o[2]
		if o.size() > 3 and o[3]: tod = o[3]
	else:
		alt = 200; temp = 18
		var s: Dictionary = r.surf
		if s.get("sand"): temp = 34; alt = 300
		if s.get("snow"): temp = -6; alt = 900
		if s.get("ice"): temp = -14; alt = 600
		if s.get("mud") or s.get("wet"): temp = 12
		if r.style == "hill": alt = 300 + 500 * float(r.tier)
		alt2 = alt + (250 + 250 * float(r.tier) if r.style == "hill" else 0.0)
	if r.get("alt") != null:
		alt = r.alt; alt2 = r.alt2; temp = r.temp
		if r.get("tod"): tod = r.tod
	return {"alt": alt, "alt2": alt2, "temp": temp, "tod": tod}

## T.forecast(r, day): race-day weather (seeded per race and week).
static func forecast(r: Dictionary, day = null) -> Dictionary:
	var d := int(Career.G.day if day == null else day)
	var c := condOf(r)
	var DY := int(D().DAYS_YEAR); var DM := int(D().DAYS_MONTH)
	var m := int(floor(float(d % DY) / DM))
	var rng := URng.new(URng.fnv(r.id) + int(floor(d / 7.0)) * 31)
	var sw := 7.0 if mode() == "sim" else 3.0
	var temp: float = U.round(c.temp + float(D().SEASON[m]) * (0.5 if c.temp < 0 else 1.0) + (rng.next() * 2 - 1) * sw)
	return {"alt": c.alt, "alt2": c.alt2, "temp": temp, "tod": c.tod, "rho": dens(c.alt, temp),
		"rho2": dens(c.alt2, temp - (c.alt2 - c.alt) * 0.0065), "name": r.n}

static func SHOP() -> Dictionary:
	return {"alt": 200.0, "alt2": 200.0, "temp": 20.0, "tod": "day", "rho": dens(200, 20), "rho2": dens(200, 20), "name": "Shop (200 m, 20°C)"}

static func cyl(v: Dictionary) -> int:
	var c = D().LAYOUT_CYL.get(v.layout)
	return 4 if c == null else int(c)
static func isBike(v: Dictionary) -> bool: return D().BODY[v.body].cls == "bike"
static func dirtKind(k: String) -> bool: return DIRT.has(k)
static func nCarbs(v: Dictionary) -> int:
	var e = v.get("eng")
	if e == null or e.fuel == "none": return 0
	if e.fuel == "efi": return cyl(v) if isBike(v) else 1
	var C: Dictionary = D().CARBS[e.carb]
	return int(C.get("carbs", 1)) if C.cls == "car" else cyl(v)
static func syncBase(n: int) -> int: return 1 if n >= 3 else 0
static func carbsFor(v: Dictionary) -> Array:
	var out := []
	var cls: String = D().BODY[v.body].cls
	for k in D().CARBS:
		if D().CARBS[k].cls == cls: out.append(k)
	return out
static func carbAvail(id: String) -> bool:
	var c: Dictionary = D().CARBS[id]
	return c.un == "S" or has(c.un)
static func defaultCarb(cls: String, _lid = null) -> String: return "d2" if cls == "car" else "pe"
static func efiCost(b: Dictionary) -> int: return int(max(20000.0, U.round(float(b.cost) * 0.25 / 1000) * 1000))
static func carbSwapCost(b: Dictionary, id: String) -> int:
	return int(max(8000.0, U.round(float(b.cost) * float(SWAP_K.get(id, 0.08)) / 1000) * 1000))

# ---------------- init / migrate ----------------
static func initEng(v: Dictionary, sys = null) -> Dictionary:
	var c := cyl(v)
	if c == 0:
		v.eng = {"fuel": "none", "cond": 1, "fuelT": "pump", "timing": 0, "sync": []}
		return v.eng
	var efi: bool = sys is Dictionary and sys.get("type") == "efi"
	var carb = sys.get("carb") if sys is Dictionary else null
	if not carb: carb = defaultCarb(D().BODY[v.body].cls, v.layout)
	var e := {"fuel": "efi" if efi else "carb", "carb": carb, "jets": {}, "timing": 0, "fuelT": "pump", "cond": 1, "log": null, "sync": []}
	v.eng = e
	stockJets(v)
	var n := nCarbs(v)
	var rng := URng.new(int(v.id) * 131 + 7)
	var sync := []
	for i in n: sync.append(0 if i == syncBase(n) else U.fixed((rng.next() * 2 - 1) * 0.8, 1))
	e.sync = sync
	if e.fuel == "efi": initEFI(v)
	return e

static func stockJets(v: Dictionary) -> void:
	var C: Dictionary = D().CARBS[v.eng.carb]
	v.eng.jets = {}
	for p in C.p: v.eng.jets[p.k] = p.stock

## T.fillJets: saves from before a carb gained a part (idle feed restrictors, cutaway...) get the stock part.
static func fillJets(v: Dictionary) -> void:
	var e = v.get("eng")
	if not (e is Dictionary) or e.get("fuel") != "carb" or not D().CARBS.has(e.get("carb", "")): return
	if not (e.get("jets") is Dictionary): e.jets = {}
	for p in D().CARBS[e.carb].p:
		if e.jets.get(p.k) == null: e.jets[p.k] = p.stock

static func initEFI(v: Dictionary) -> void:
	var tv := trueVE(v)
	var rng := URng.new(int(v.id) * 977 + 3)
	var ve := []
	for r in tv:
		var row := []
		for x in r: row.append(U.round(x * (1 + (rng.next() * 2 - 1) * 0.11)))
		ve.append(row)
	var afr := []
	for j in D().LOAD_B.size():
		var row2 := []
		for _i in D().RPM_B.car.size(): row2.append(D().AFR_DEF[j])
		afr.append(row2)
	var ign := []
	for j in 6:
		var row3 := []
		for i in 8: row3.append(U.round(mbt(i, j) - 4))
		ign.append(row3)
	v.eng.efi = {"ve": ve, "ign": ign, "afr": afr, "ae": 100, "edits": 0}
	var n := nCarbs(v)
	var sync := []
	for i in n: sync.append(0 if i == syncBase(n) else U.fixed((rng.next() * 2 - 1) * 0.6, 1))
	v.eng.sync = sync

# ---------------- hidden engine requirement ----------------
static func need(v: Dictionary) -> Dictionary:
	var rng := URng.new(int(v.id) * 9973 + URng.fnv(v.body))
	var n := {}
	for z in ZONES: n[z] = 1 + (rng.next() - 0.5) * 0.08
	n.trans = 1 + (rng.next() - 0.5) * 0.12
	for pid in v.parts:
		var P: Dictionary = D().PART[pid]
		if not (P.cat == "exh" or P.cat == "ful" or P.cat == "eng"): continue
		var t: float = float(P.tier) + 1
		n.wot += 0.014 * t; n.mid += 0.008 * t; n.low += 0.003 * t; n.trans += 0.006 * t
		if pid == "nitrous": n.wot += 0.05
		if pid.contains("turbo"): n.wot += 0.03; n.mid += 0.02
	if has("porting"): n.wot += 0.03; n.mid += 0.02
	var fl: Array = v.get("bflags", [])
	if fl.has("rev"): n.wot += 0.04
	if fl.has("torque"): n.mid += 0.03; n.low += 0.01
	if has("bigvalve"): n.wot += 0.06; n.mid += 0.02
	return n

static func aeNeed(v: Dictionary) -> float: return U.round(100 * need(v).trans)

static func trueVE(v: Dictionary) -> Array:
	var nd := need(v)
	var rng := URng.new(int(v.id) * 31337 + 5)
	var any_eng := false
	for p in v.parts:
		if D().PART[p].cat == "eng": any_eng = true; break
	var pk: float = 4.2 + rng.next() * 1.6 + (0.6 if any_eng else 0.0)
	var LB: Array = D().LOAD_B
	var out := []
	for j in 6:
		var row := []
		var L: float = LB[j]
		var zn: float = nd.wot if j >= 4 else (nd.mid if j >= 2 else nd.low)
		for i in 8:
			var bell := exp(-pow((i - pk) / 2.6, 2))
			row.append((48 + 44 * bell) * (0.78 + 0.22 * L / 100) * zn * (1 + (rng.next() - 0.5) * 0.05))
		out.append(row)
	return out

static func mbt(i: int, j: int) -> float: return 14 + 2.4 * i + (100 - float(D().LOAD_B[j])) * 0.17

static func kl(v: Dictionary, i: int, j: int, lam: float, cond: Dictionary) -> float:
	var L: float = D().LOAD_B[j]
	var m: float = 6 + (100 - L) * 0.15 + i * 0.6 - (4.0 if (L >= 90 and i <= 2) else 0.0)
	m += float(D().FUELS[v.eng.get("fuelT", "pump") if v.eng.get("fuelT") else "pump"].kn) - (3.0 if has("highcomp") else 0.0) + float(cond.alt) / 1000 * 1.5 - (float(cond.temp) - 20) * 0.12
	if lam > 0.9: m -= (lam - 0.9) * 50
	if lam < 0.85: m += (0.85 - lam) * 20
	return mbt(i, j) + m

# ---------------- carb richness ----------------
static func carbRich(v: Dictionary) -> Dictionary:
	var C: Dictionary = D().CARBS[v.eng.carb]
	var j: Dictionary = v.eng.jets
	var R := {"idle": 1.0, "low": 1.0, "mid": 1.0, "wot": 1.0, "trans": 1.0}
	for p in C.p:
		var val = j.get(p.k)
		if val == null: continue
		val = float(val)
		var st: float = p.stock
		match p.t:
			"jet":
				for z in ZONES: R[z] *= pow(val / st, 2 * float(p.w[z]))
				R.trans *= pow(val / st, 2 * float(p.w.low))
			"lin", "clip":
				for z in ZONES: R[z] *= 1 + float(p.w[z]) * (val - st)
				R.trans *= 1 + float(p.w.low) * (val - st)
			"pv":
				R.mid *= 1 + 0.03 * (val - st); R.trans *= 1 + 0.01 * (val - st)
			"airc":
				R.wot *= pow(st / val, 0.8); R.mid *= pow(st / val, 0.2)
			"pump":
				R.trans *= pow(val / st, 0.8)
	R.trans *= float(C.trans)
	return R

# ---------------- full evaluation for one condition ----------------
static func pf(lam: float, z: String) -> float:
	var t: float = D().LAM.get(z, 0.88)
	var w: float = PFW[z]
	var loss: float = 4.5 * pow(t - lam, 2) if lam < t else 5 * pow(lam - t, 2)
	if lam > 1.12: loss += (lam - 1.12) * 1.5
	if lam < 0.72: loss += (0.72 - lam) * 1.2
	return maxf(0.4, 1 - loss * w)

static func tf(adv: float, mb: float) -> float:
	var r := mb - adv
	return 1 - 0.0005 * r * r if r > 0 else 1 - 0.0008 * r * r

static func _pw(e: Dictionary) -> float:
	return float(D().FUELS[e.get("fuelT", "pump") if e.get("fuelT") else "pump"].pw) * (1.03 if has("porting") else 1.0) * (1.04 if has("highcomp") else 1.0) * (0.86 + 0.14 * U.clamp(float(e.cond), 0, 1))

## T.eval(v, cond, rhoOverride): lambda / power / timing / knock / lean-heat per throttle zone.
static func eval(v: Dictionary, cond: Dictionary, rho_override = null) -> Dictionary:
	var e = v.get("eng")
	var LAM: Dictionary = D().LAM
	var out := {"lam": {}, "pf": {}, "tf": {}, "kd": {}, "lh": {}, "ef": {}, "cells": null, "notes": []}
	if e == null or e.fuel == "none":
		for z in ZONES_T:
			out.lam[z] = LAM.get(z, 0.9); out.ef[z] = 1.0; out.kd[z] = 0.0; out.lh[z] = 0.0
		return out
	var rho: float = float(rho_override) if rho_override != null else float(cond.rho)
	var tK: float = 273.15 + float(cond.temp)
	var prs: float = rho * tK / T0
	var nd := need(v)
	var n := nCarbs(v)
	var bi := syncBase(n)
	var offs := 0.0; var noff := 0
	for i in e.sync.size():
		if i != bi: offs += absf(float(e.sync[i])); noff += 1
	var imb: float = offs / noff if noff else 0.0
	out.imb = imb
	var sF := {"idle": 1 - 0.04 * imb, "low": 1 - 0.025 * imb, "mid": 1 - 0.008 * imb, "wot": 1 - 0.003 * imb, "trans": 1 - 0.025 * imb}
	var pw := _pw(e)
	var efi: bool = e.fuel == "efi"
	var cells = null
	if not efi:
		var C: Dictionary = D().CARBS[e.carb]
		pw *= float(C.pw)
		var R := carbRich(v)
		var fn: float = D().FUELS[e.get("fuelT", "pump") if e.get("fuelT") else "pump"].need
		var sq := sqrt(rho)
		for z in ZONES: out.lam[z] = float(LAM[z]) * nd[z] * fn / R[z] * sq
		out.lam.trans = float(LAM.low) * nd.trans * fn / R.trans * sq
	else:
		pw *= 1.05
		var tv := trueVE(v)
		var comp: float = (1.0 if has("mapsens") else prs) * (1.0 if has("iat") else T0 / tK)
		var ve: Array = e.efi.ve
		var afr: Array = e.efi.afr
		cells = []
		for j in 6:
			var row := []
			for i in 8: row.append(float(afr[j][i]) / 14.7 * tv[j][i] / maxf(5, float(ve[j][i])) * comp)
			cells.append(row)
		out.cells = cells
		for z in ZONES:
			var s := 0.0; var w := 0.0
			for c in ZC[z]:
				s += cells[c[0]][c[1]] * c[2]; w += c[2]
			out.lam[z] = s / w
		out.lam.trans = out.lam.low * pow(aeNeed(v) / maxf(10, float(e.efi.ae)), 0.6)
	var knock_ctl := efi and has("knock")
	var timing: float = float(e.get("timing", 0)) if e.get("timing") else 0.0
	for z in ZONES:
		var p_ := 0.0; var t_ := 0.0; var kd := 0.0; var kmax := 0.0; var w := 0.0
		for c in ZC[z]:
			var j: int = c[0]; var i: int = c[1]; var ww: float = c[2]
			var lam: float = cells[j][i] if cells != null else out.lam[z]
			var mb := mbt(i, j)
			var adv: float = float(e.efi.ign[j][i]) if efi else mb - 3 + timing
			var k := maxf(0, adv - kl(v, i, j, lam, cond))
			p_ += pf(lam, z) * ww; t_ += tf(adv, mb) * ww; kd += k * ww; kmax = maxf(kmax, k); w += ww
		out.pf[z] = p_ / w; out.tf[z] = t_ / w
		out.kd[z] = kd / w * 0.5 + kmax * 0.5 if (z == "mid" or z == "wot") else 0.0
		out.lh[z] = maxf(0, out.lam[z] - 0.97) * 40 if (z == "mid" or z == "wot") else 0.0
		if knock_ctl and out.kd[z] > 0:
			out.tf[z] *= 1 - 0.01 * out.kd[z]; out.kd[z] *= 0.15
		out.ef[z] = out.pf[z] * out.tf[z] * sF[z] * pw
	out.pf.trans = pf(out.lam.trans, "trans"); out.ef.trans = out.pf.trans * sF.trans * pw; out.kd.trans = 0.0; out.lh.trans = 0.0
	var fl: float = float(e.jets.get("float", 0)) if (not efi and e.jets.get("float")) else 0.0
	out.starve = fl <= -1.5 and not has("baffle")
	out.flood = fl >= 1.5 and not has("baffle")
	out.foul = out.lam.idle < 0.78 or out.lam.low < 0.76
	out.seize = v.layout == "stroke2" and out.lam.wot > 0.93
	return out

static func afr(lam: float) -> float: return lam * 14.7
## [label, color]
static func zoneLabel(lam: float, z: String) -> Array:
	var t: float = D().LAM.get(z, 0.88)
	var d := lam - t
	if absf(d) < 0.02: return ["On target", "#8ef58e"]
	if d < 0: return ["Very rich", "#ff9a5c"] if d < -0.06 else ["Rich", "#ffd84a"]
	return ["Very lean", "#ff5c5c"] if d > 0.06 else ["Lean", "#ffd84a"]
## [plug look, color, verdict]
static func plug(lam: float) -> Array:
	if lam < 0.8: return ["Sooty black", "#1c1c1c", "Rich"]
	if lam < 0.845: return ["Dark brown", "#5a3b1c", "Slightly rich"]
	if lam < 0.905: return ["Light tan", "#c79a5a", "Good"]
	if lam < 0.96: return ["Grey-white", "#c9c9c0", "Slightly lean"]
	return ["Chalk white, blistered", "#f4f4f4", "LEAN!"]

static func symptoms(ev: Dictionary, efi: bool) -> Array:
	var s := []
	var L: Dictionary = ev.lam
	var t: Dictionary = D().LAM
	if L.idle > t.idle + 0.07: s.append("Hangs at idle and pops on decel (lean low-load cells)" if efi else "Hangs at idle and pops on decel (lean pilot circuit)")
	elif L.idle < t.idle - 0.1: s.append("Sooty idle (rich low-load cells)" if efi else "Blubbery, sooty idle (rich pilot circuit)")
	if L.trans > t.low + 0.05: s.append("Bogs on throttle snaps — more accel enrichment" if efi else "Bogs when you snap the throttle (lean transition)")
	if L.mid > t.mid + 0.06: s.append("Surges at part throttle (lean mid cells)" if efi else "Surges at part throttle (lean needle)")
	elif L.mid < t.mid - 0.07: s.append("Dull midrange (rich mid cells)" if efi else "Dull midrange, black smoke (rich needle)")
	if L.wot > t.wot + 0.06: s.append("Pulls then flattens — lean WOT cells" if efi else "Pulls hard then flattens; pinging under load (lean main)")
	elif L.wot < t.wot - 0.06: s.append("Soggy top end (rich WOT cells)" if efi else "Black smoke and soggy top end (rich main)")
	if float(ev.kd.wot) > 0.5 or float(ev.kd.mid) > 0.5: s.append("Audible pinging — detonation!")
	if float(ev.get("imb", 0)) > 1.2: s.append("Rough, lumpy idle — carbs out of sync")
	if s.is_empty(): s.append("Crisp and clean everywhere")
	return s

# ---------------- race section factors ----------------
static func setupMul(v: Dictionary, sec: Dictionary) -> Dictionary:
	var m := Prof.setup_mul(v, sec, Career.G)
	return {"S": m.S, "A": m.A, "H": m.H, "tm": m.tm}
static func stockRatio(v: Dictionary) -> float: return Prof.stock_ratio(v)
static func stockPsi(v: Dictionary) -> float: return Prof.stock_psi(v)
static func defaultSetup(v: Dictionary) -> Dictionary: return Prof.default_setup(v.body)

static func evalIdeal(v: Dictionary) -> Dictionary:
	var e = v.get("eng")
	var lam: Dictionary = D().LAM.duplicate()
	lam.trans = lam.low
	var out := {"lam": lam, "ef": {}, "kd": {}, "lh": {}, "imb": 0}
	var pw := 1.0
	if e != null and e.fuel != "none":
		pw = _pw(e) * (1.05 if e.fuel == "efi" else float(D().CARBS[e.carb].pw))
	for z in ZONES_T:
		out.ef[z] = pw * 0.995; out.kd[z] = 0.0; out.lh[z] = 0.0
	return out

## T.raceSecs(v, def, track, cond, ideal): per-section multipliers for the human race entry.
## -> {secs: [{ef,s,a,h,t,kd,lh,lam,starve,flood,smoke}], ev, foul, seize}
static func raceSecs(v: Dictionary, _def, tr: Dictionary, cond: Dictionary, ideal := false) -> Dictionary:
	var out := []
	var hill: bool = float(cond.alt2) != float(cond.alt)
	var cache := {}
	var easy := mode() == "easy"
	var efi: bool = v.get("eng") != null and v.eng.fuel == "efi"
	var launch := has("launch")
	var secz: Dictionary = D().SECZ
	for sec in tr.secs:
		var ev := _ev_at(v, cond, hill, ideal, cache, (float(sec.at) + float(sec.len) / 2.0) / float(tr.lapLen))
		var zw: Dictionary = secz.get(sec.type, {"wot": 1})
		var ef := 0.0; var kd := 0.0; var lh := 0.0; var lam := 0.0
		for z in zw:
			var w: float = zw[z]
			ef += w * float(ev.ef[z]); kd += w * float(ev.kd.get(z, 0)); lh += w * float(ev.lh.get(z, 0)); lam += w * float(ev.lam[z])
		if sec.type == "lau" and efi and launch: ef *= 1.08
		var sm := Prof.setup_mul(v, sec, Career.G)
		var smoke = null
		if lam < 0.8: smoke = "rich"
		elif (float(ev.lam.idle) > 1.0 or float(ev.lam.low) > 0.97) and (sec.type == "hp" or sec.type == "chi"): smoke = "pop"
		out.append({"ef": ef, "s": sm.S, "a": sm.A, "h": sm.H, "t": sm.tm, "kd": 0.0 if easy else kd, "lh": 0.0 if easy else lh, "lam": lam,
			"starve": not easy and bool(ev.get("starve", false)) and (sec.type == "jmp" or sec.type == "rgh"),
			"flood": not easy and bool(ev.get("flood", false)) and sec.type == "rgh", "smoke": smoke})
	var ev0 := _ev_at(v, cond, hill, ideal, cache, 0.0)
	return {"secs": out, "ev": ev0, "foul": not easy and bool(ev0.get("foul", false)), "seize": not easy and bool(ev0.get("seize", false))}

static func _ev_at(v: Dictionary, cond: Dictionary, hill: bool, ideal: bool, cache: Dictionary, frac: float) -> Dictionary:
	if ideal:
		if not cache.has("i"): cache.i = evalIdeal(v)
		return cache.i
	var key := int(U.round(frac * 4)) if hill else 0
	if cache.has(key): return cache[key]
	var alt: float = float(cond.alt) + (float(cond.alt2) - float(cond.alt)) * (key / 4.0)
	var temp: float = float(cond.temp) - (alt - float(cond.alt)) * 0.0065
	var c2 := cond.duplicate(); c2.alt = alt; c2.temp = temp
	cache[key] = eval(v, c2, dens(alt, temp))
	return cache[key]

# ---------------- crew tune (optimizer) ----------------
## Standard mode's crew limits: "" when the tune is safe to race, else why the crew would step in.
## (Lean heat or knock that would hurt the engine, a tune rich enough to bog/foul, or float problems.)
const STD_KEYS := ["main", "pilot", "clip", "screw", "sec"]
static func danger(v: Dictionary, cond: Dictionary) -> String:
	var e = v.get("eng")
	if e == null or e.fuel == "none": return ""
	var a0: float = cond.alt; var a2: float = cond.alt2
	for f in ([0.0, 1.0] if a2 != a0 else [0.0]):
		var alt: float = a0 + (a2 - a0) * f
		var c2 := cond.duplicate(); c2.alt = alt; c2.temp = float(cond.temp) - (alt - a0) * 0.0065
		var ev := eval(v, c2, dens(alt, float(c2.temp)))
		for z in ZONES:
			if float(ev.lh.get(z, 0.0)) > 0.5: return "running lean and hot at %s" % str(D().ZONE_N.get(z, z)).to_lower()
			if float(ev.kd.get(z, 0.0)) > 0.5: return "knocking at %s" % str(D().ZONE_N.get(z, z)).to_lower()
			if float(ev.lam.get(z, 1.0)) < 0.76: return "so rich it bogs at %s" % str(D().ZONE_N.get(z, z)).to_lower()
		if bool(ev.get("seize", false)): return "lean enough to seize"
		if bool(ev.get("starve", false)) or bool(ev.get("flood", false)): return "fuel level starving or flooding"
	return ""

static func err(v: Dictionary, cond: Dictionary) -> float:
	var s := 0.0
	var a0: float = cond.alt; var a2: float = cond.alt2
	var pts := [0.0, 0.5, 1.0] if a2 != a0 else [0.0]
	var LAM: Dictionary = D().LAM
	for f in pts:
		var alt: float = a0 + (a2 - a0) * f
		var temp: float = float(cond.temp) - (alt - a0) * 0.0065
		var c2 := cond.duplicate(); c2.alt = alt; c2.temp = temp
		var ev := eval(v, c2, dens(alt, temp))
		for z in ZONES:
			var d: float = float(ev.lam[z]) - float(LAM[z])
			s += ERRW[z] * pow(d, 2) + (0.5 * pow(d, 2) if float(ev.lam[z]) > float(LAM[z]) else 0.0)
		s += 0.6 * pow(float(ev.lam.trans) - float(LAM.low), 2) + 0.02 * (float(ev.kd.wot) + float(ev.kd.mid))
	return s

static func crewTune(v: Dictionary, cond: Dictionary, q := 0.97) -> void:
	var e = v.get("eng")
	if e == null or e.fuel == "none": return
	if e.fuel == "carb":
		var C: Dictionary = D().CARBS[e.carb]
		fillJets(v)
		e.jets.float = 0
		for _it in 4:
			for p in C.p:
				if p.k == "float": continue
				var best = e.jets[p.k]
				var bs := err(v, cond)
				var x: float = p.min
				var mx: float = float(p.max) + 1e-9
				var stp: float = p.step
				while x <= mx:
					e.jets[p.k] = U.fixed(x, 2)
					var s := err(v, cond)
					if s < bs - 1e-9: bs = s; best = e.jets[p.k]
					x += stp
				e.jets[p.k] = best
		var bt := -6
		for t in range(-6, 9):
			e.timing = t
			var ev := eval(v, cond)
			if ev.kd.wot <= 0 and ev.kd.mid <= 0: bt = t
		e.timing = maxi(-6, bt - 1)
		if U.chance((1 - q) * 8):
			var p0: Dictionary = C.p[0]
			e.jets[p0.k] = U.fixed(U.clamp(float(e.jets[p0.k]) + (1 if U.chance(0.5) else -1) * float(p0.step), p0.min, p0.max), 2)
	else:
		var tv := trueVE(v)
		var tK: float = 273.15 + float(cond.temp)
		var rho: float = dens((float(cond.alt) + float(cond.alt2)) / 2, cond.temp) if float(cond.alt2) != float(cond.alt) else float(cond.rho)
		var prs: float = rho * tK / T0
		var comp: float = (1.0 if has("mapsens") else prs) * (1.0 if has("iat") else T0 / tK)
		for j in 6:
			for i in 8:
				e.efi.afr[j][i] = D().AFR_DEF[j]
				e.efi.ve[j][i] = U.round(tv[j][i] * comp * (1 + (U.rand(-1, 1)) * (1 - q) * 0.6))
				var lam: float = float(e.efi.afr[j][i]) / 14.7
				e.efi.ign[j][i] = U.round(minf(mbt(i, j), kl(v, i, j, lam, cond) - 1.5))
		e.efi.ae = aeNeed(v)
	var n: int = e.sync.size()
	var bi := syncBase(n)
	var ns := []
	for i in n: ns.append(0 if i == bi else U.fixed(U.rand(-1, 1) * (1 - q) * 3, 1))
	e.sync = ns
	e.tunedFor = cond.name

static func crewCost() -> int:
	var ws := int(Career.G.ws)
	return int(U.round((6000 + ws * ws * 6000) / 1000.0) * 1000)
static func rebuildCost(v: Dictionary) -> int:
	return int(U.round(float(D().BODY[v.body].cost) * 0.12 * (1 - float(v.eng.cond) + 0.2) / 1000) * 1000)

# ---------------- logging ----------------
static func makeLog(v: Dictionary, cond: Dictionary, src: String) -> Dictionary:
	var ev := eval(v, cond)
	var cells = null
	if ev.cells != null:
		cells = []
		for r in ev.cells: cells.append(r.duplicate())
	return {"d": Career.G.day, "src": src, "cond": cond.name, "lam": ev.lam.duplicate(), "kd": ev.kd.duplicate(),
		"imb": ev.get("imb", 0), "cells": cells, "wb": has("wideband")}
