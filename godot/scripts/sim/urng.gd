class_name URng
extends RefCounted
## Bit-exact ports of the web build's U.hash (FNV-1a) and U.seeded (mulberry32),
## so generated tracks match the web version and every LAN peer.

const M32 := 0xFFFFFFFF
var s: int = 0

func _init(seed: int = 0) -> void:
	s = seed & M32

## Math.imul for 32-bit operands, avoiding 64-bit overflow.
static func imul(a: int, b: int) -> int:
	a &= M32
	b &= M32
	var lo := (a & 0xFFFF) * b
	var hi := (((a >> 16) * b) & 0xFFFF) << 16
	return (lo + hi) & M32

static func fnv(text: String) -> int:
	var h := 2166136261
	for i in text.length():
		h ^= text.unicode_at(i)
		h = imul(h, 16777619)
	return h & M32

## Next float in [0,1) — identical sequence to U.seeded(seed)().
func next() -> float:
	s = (s + 0x6D2B79F5) & M32
	var t := s
	t = imul(t ^ (t >> 15), t | 1)
	t ^= (t + imul(t ^ (t >> 7), t | 61)) & M32
	t &= M32
	return float((t ^ (t >> 14)) & M32) / 4294967296.0

func range_f(a: float, b: float) -> float: return a + next() * (b - a)
func range_i(a: int, b: int) -> int: return a + int(floor(next() * (b - a + 1)))
func pick(arr: Array): return arr[int(floor(next() * arr.size()))]
func chance(p: float) -> bool: return next() < p
func shuffle(arr: Array) -> Array:
	var a := arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := int(floor(next() * (i + 1)))
		var tmp = a[i]; a[i] = a[j]; a[j] = tmp
	return a
