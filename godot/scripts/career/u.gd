class_name U
extends RefCounted
## Static helpers mirroring web/src/util.js (the web `U` object).
## `Math.random()` maps to `U.rng` (seed it with `U.seed(n)` for repeatable careers and tests).
## `U.seeded()` / `U.hash()` are the bit-exact `URng` ports, so seeded tracks, forecasts and
## engine maps match the web build.

static var rng := RandomNumberGenerator.new()

static func seed(s: int) -> void: rng.seed = s
static func random() -> float: return rng.randf()

static func clamp(v: float, a: float, b: float) -> float: return maxf(a, minf(b, v))
static func rand(a: float, b: float) -> float: return a + rng.randf() * (b - a)
static func ri(a: int, b: int) -> int: return int(floor(a + rng.randf() * (b - a + 1)))
static func pick(arr: Array):
	if arr.is_empty(): return null
	return arr[int(floor(rng.randf() * arr.size()))]
static func chance(p: float) -> bool: return rng.randf() < p
static func shuffle(a: Array) -> Array:
	a = a.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := int(floor(rng.randf() * (i + 1)))
		var t = a[i]; a[i] = a[j]; a[j] = t
	return a
static func seeded(s: int) -> URng: return URng.new(s)
static func hash(text: String) -> int: return URng.fnv(text)

## JS Math.round: halves round toward +infinity (Math.round(-2.5) == -2).
static func round(x: float) -> float: return floor(x + 0.5)
## JS Math.round as an int.
static func iround(x: float) -> int: return int(floor(x + 0.5))

## JS Number.prototype.toFixed (exact binary ties round away from zero, like V8).
static func to_fixed(x: float, n: int) -> String:
	var p := pow(10.0, n)
	var t := absf(x) * p
	var fl := floorf(t)
	if t - fl == 0.5 and (fl + 0.5) / p == absf(x):
		var k: float = fl + 1.0
		var s := ("%." + str(n) + "f") % (k / p)
		return ("-" + s) if x < 0 else s
	return ("%." + str(n) + "f") % x

## `+x.toFixed(n)`: the number JS gets back from its fixed-point string.
static func fixed(x: float, n: int) -> float: return to_fixed(x, n).to_float()

static func money(v: float) -> String:
	var a := absf(v)
	var s := "-" if v < 0 else ""
	if a >= 1e6: return s + "$" + to_fixed(a / 1e6, 0 if a >= 1e8 else 1 if a >= 1e7 else 2) + "M"
	if a >= 1e3: return s + "$" + str(iround(a / 1e3)) + "K"
	return s + "$" + str(iround(a))

static func num(v: float) -> String:
	if v >= 1e6: return to_fixed(v / 1e6, 1) + "M"
	if v >= 1e4: return to_fixed(v / 1e3, 1) + "K"
	return str(iround(v))

static func esc(s) -> String:
	return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;")

static func ord(n: int) -> String:
	var s := ["th", "st", "nd", "rd"]
	var v := n % 100
	var i := (v - 20) % 10
	if i >= 1 and i <= 3: return str(n) + s[i]
	if v >= 1 and v <= 3: return str(n) + s[v]
	return str(n) + "th"

## U.sum(arr) or U.sum(arr, func(x): return x.k)
static func sum(a: Array, f = null) -> float:
	var s := 0.0
	if f == null:
		for x in a: s += float(x)
	else:
		for x in a: s += float(f.call(x))
	return s

static func stars(n: int, mx: int = 5) -> String:
	var s := ""
	for i in mx: s += "★" if i < n else "☆"
	return s

## Stable sort (JS Array.prototype.sort is stable): ascending by key(x), ties keep input order.
static func sort_by(a: Array, key: Callable, desc := false) -> Array:
	var dec := []
	for i in a.size(): dec.append([key.call(a[i]), i, a[i]])
	if desc: dec.sort_custom(_cmp_desc)
	else: dec.sort_custom(_cmp_asc)
	var out := []
	for d in dec: out.append(d[2])
	return out

static func _cmp_asc(x: Array, y: Array) -> bool:
	if x[0] != y[0]: return x[0] < y[0]
	return x[1] < y[1]

static func _cmp_desc(x: Array, y: Array) -> bool:
	if x[0] != y[0]: return x[0] > y[0]
	return x[1] < y[1]

## Deep copy (JSON.parse(JSON.stringify(x)) for plain data).
static func clone(x):
	if x is Dictionary or x is Array: return x.duplicate(true)
	return x
