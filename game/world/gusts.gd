class_name Gusts
extends RefCounted
## The wind's gusts over grass on the CPU: the same bands as
## gust.gdshaderinc, with its defaults, so a sound can swell as the
## band the eye sees reaches the listener.

const GUST_SPEED := 1.2
const BAND_LENGTH := 30.0
const BAND_WIDTH := 6.0
const MASK := 0xFFFFFFFF


static func _hash(cx: int, cy: int) -> float:
	var v := ((cx & MASK) * 1597334677) & MASK
	v ^= ((cy & MASK) * 3812015801) & MASK
	v = (v * 747796405 + 2891336453) & MASK
	v = (((v >> ((v >> 28) + 4)) ^ v) * 277803737) & MASK
	v = (v >> 22) ^ v
	return float(v) / 4294967295.0


static func _noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var cx := int(i.x)
	var cy := int(i.y)
	return lerpf(lerpf(_hash(cx, cy), _hash(cx + 1, cy), u.x),
		lerpf(_hash(cx, cy + 1), _hash(cx + 1, cy + 1), u.x), u.y)


## The gust at ground point p: 0 between bands to 0.45-1 at a crest.
static func at(p: Vector2, travel: float, wind: float, wind_dir: Vector2) -> float:
	var wd := wind_dir.normalized()
	var across := Vector2(-wd.y, wd.x)
	var run := travel * GUST_SPEED
	var u := (p.dot(wd) - run) / BAND_WIDTH
	var v := (p.dot(across) + run * 0.25) / BAND_LENGTH
	var bands := _noise(Vector2(u, v)) * 0.75 + _noise(Vector2(u * 2.3, v * 1.7) + Vector2(11.0, 11.0)) * 0.25
	return smoothstep(0.38, 0.62, bands) * (0.45 + 0.55 * wind)
