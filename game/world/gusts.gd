class_name Gusts
extends RefCounted
## The wind's gusts over grass on the CPU: the same bands as
## gust.gdshaderinc, with its defaults, carried along the same flow, so a
## sound can swell as the band the eye sees reaches the listener. Holds
## the land's flow map, baked here and handed to the shaders.

const GUST_SPEED := 1.2
const BAND_LENGTH := 30.0
const BAND_WIDTH := 6.0
const EDDY := 0.9
const EDDY_SIZE := 45.0
const WARP := 12.0
const GUST_CYCLE := 24.0
## How hard the slope pulls the gusts downhill: flow per unit of slope.
const DOWNHILL := 5.0
const MASK := 0xFFFFFFFF

var flow: Image                      # RG: the downhill pull, as the shaders' flow_map
var flow_tex: ImageTexture
var flow_origin := Vector2(-1024.0, -1024.0)
var flow_size := 2048.0


## Bake the downhill pull over a square of side `size` round the
## origin, a texel every `texel` metres: the slope's fall, measured over
## a few texels so it follows the hills and not their ripples, times
## DOWNHILL, never more than 1.2 times the wind.
func bake_flow(land: Landscape, size: float, texel: float) -> void:
	flow_size = size
	flow_origin = Vector2(-size, -size) * 0.5
	var n := int(size / texel)
	flow = Image.create_empty(n, n, false, Image.FORMAT_RGF)
	var d := texel * 1.5
	for j in n:
		var z := flow_origin.y + (j + 0.5) * texel
		for i in n:
			var x := flow_origin.x + (i + 0.5) * texel
			var gx := (land.height_at(x + d, z) - land.height_at(x - d, z)) / (2.0 * d)
			var gz := (land.height_at(x, z + d) - land.height_at(x, z - d)) / (2.0 * d)
			var down := -Vector2(gx, gz) * DOWNHILL
			if down.length() > 1.2:
				down = down.normalized() * 1.2
			flow.set_pixel(i, j, Color(down.x, down.y, 0.0, 1.0))
	flow_tex = ImageTexture.create_from_image(flow)


## Hand the flow map to a material that shows gusts.
func apply(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("flow_map", flow_tex)
	mat.set_shader_parameter("flow_origin", flow_origin)
	mat.set_shader_parameter("flow_size", flow_size)
	mat.set_shader_parameter("use_flow", 1.0)


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


## The flow map at p, filtered as the GPU filters it.
func _down(p: Vector2) -> Vector2:
	if flow == null:
		return Vector2.ZERO
	var n := flow.get_width()
	var t := (p - flow_origin) / flow_size * n - Vector2(0.5, 0.5)
	var i0 := clampi(int(floor(t.x)), 0, n - 1)
	var j0 := clampi(int(floor(t.y)), 0, n - 1)
	var i1 := clampi(i0 + 1, 0, n - 1)
	var j1 := clampi(j0 + 1, 0, n - 1)
	var fx := clampf(t.x - floor(t.x), 0.0, 1.0)
	var fy := clampf(t.y - floor(t.y), 0.0, 1.0)
	var a := flow.get_pixel(i0, j0).lerp(flow.get_pixel(i1, j0), fx)
	var b := flow.get_pixel(i0, j1).lerp(flow.get_pixel(i1, j1), fx)
	var c := a.lerp(b, fy)
	return Vector2(c.r, c.g)


func _flow(p: Vector2, travel: float, wd: Vector2) -> Vector2:
	var t := travel * GUST_SPEED
	var e := Vector2(_noise(p / EDDY_SIZE + Vector2(t * 0.022, 3.0)),
		_noise(p / EDDY_SIZE + Vector2(17.0, -t * 0.018))) - Vector2(0.5, 0.5)
	var e2 := Vector2(_noise(p / (EDDY_SIZE * 0.4) + Vector2(-t * 0.05, 41.0)),
		_noise(p / (EDDY_SIZE * 0.4) + Vector2(53.0, t * 0.043))) - Vector2(0.5, 0.5)
	var f := wd + _down(p) + (e * 2.0 + e2) * EDDY
	var mag := f.length()
	return f / maxf(mag, 1e-4) * clampf(mag, 0.15, 2.2)


static func _pattern(q: Vector2, wd: Vector2) -> float:
	var across := Vector2(-wd.y, wd.x)
	q += (Vector2(_noise(q / 35.0 + Vector2(5.0, 5.0)), _noise(q / 35.0 + Vector2(29.0, 29.0))) - Vector2(0.5, 0.5)) * 2.0 * WARP
	var u := q.dot(wd) / BAND_WIDTH
	var v := q.dot(across) / BAND_LENGTH
	return _noise(Vector2(u, v)) * 0.75 + _noise(Vector2(u * 2.3, v * 1.7) + Vector2(11.0, 11.0)) * 0.25


## The gust at ground point p: 0 between bands to 0.45-1 at a crest.
func at(p: Vector2, travel: float, wind: float, wind_dir: Vector2) -> float:
	var wd := wind_dir.normalized()
	var f := _flow(p, travel, wd)
	var c := travel * GUST_SPEED / GUST_CYCLE
	var b := 0.0
	var w2 := 0.0
	for k in 2:
		var ck := c + 0.5 * k
		var cycle := floorf(ck)
		var s := (ck - cycle) * GUST_CYCLE
		var jump := Vector2(_hash(int(cycle), k), _hash(k + 7, int(cycle) + 7)) * 4000.0
		var w := 1.0 - absf(2.0 * (ck - cycle) - 1.0)
		b += (_pattern(p - f * s + jump, wd) - 0.5) * w
		w2 += w * w
	b = 0.5 + b / sqrt(maxf(w2, 1e-4))
	return smoothstep(0.38, 0.62, b) * (0.45 + 0.55 * wind)
