class_name GrassField
extends Node3D
## Grass that grows where a landscape says, drawn round the camera.
##
## The ground under the field is baked once into a data texture (red:
## height; green: how tall the grass grows; blue: where flowers bloom)
## that grass.gdshader reads to stand each tuft. The tufts come in
## square tiles of CHUNK metres, one tile mesh per density band, each a
## MultiMesh of tufts at random spots; the same tile is laid in every
## chunk slot round the camera, near slots with the dense band and far
## ones with sparser bands of simpler tufts. As the camera moves the
## slots follow it chunk by chunk and take their bands afresh. The
## shader thins the tufts by distance at one rate (full density out to
## FULL_R, then falling as the distance to the power 1.5, gone by FAR),
## and a chunk takes the sparsest band that still carries that rate at
## its nearest point, so the bands meet without a seam. Chunks with no
## grass in them are hidden.

const CHUNK := 8.0
const TEXEL := 0.5
const FULL_R := 7.0
const FAR := 64.0
## density (tufts a square metre), blades a tuft, segments a blade.
const BANDS: Array = [
	[14.0, 10, 4],
	[7.0, 8, 3],
	[3.5, 6, 2],
	[1.4, 5, 1],
]

var origin := Vector2(-128.0, -128.0)
var size := 256.0
var materials: Array[ShaderMaterial] = []
var stats: Dictionary = {}

var _meshes: Array[MultiMesh] = []
var _slots: Array[MultiMeshInstance3D] = []
var _offsets: Array[Vector2i] = []
var _grass_in: Dictionary = {}       # chunk index -> [min height, max height], for chunks with grass
var _band_out: Array[float] = []     # the distance out to which each band is wanted
var _placed_at := Vector2(1.0e9, 0.0)


## Bake the ground over a square of side `side` round `centre` from the
## landscape's height and the callables' grass and flowers, then make
## the tiles and the slots.
func build(land: Landscape, centre: Vector2, side: float, grass: Callable, flowers: Callable) -> void:
	var t0 := Time.get_ticks_msec()
	size = side
	origin = centre - Vector2(side, side) * 0.5
	var n := int(side / TEXEL)
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBAF)
	for j in n:
		var z := origin.y + (j + 0.5) * TEXEL
		for i in n:
			var x := origin.x + (i + 0.5) * TEXEL
			var g: float = grass.call(x, z)
			var h := land.height_at(x, z)
			var f: float = flowers.call(x, z) if g > 0.0 else 0.0
			img.set_pixel(i, j, Color(h, g, f, 1.0))
			if g > 0.02:
				var key := Vector2i(floori(x / CHUNK), floori(z / CHUNK))
				if _grass_in.has(key):
					var span: Vector2 = _grass_in[key]
					_grass_in[key] = Vector2(minf(span.x, h), maxf(span.y, h))
				else:
					_grass_in[key] = Vector2(h, h)
	var tex := ImageTexture.create_from_image(img)
	var shader := load("res://world/grass.gdshader") as Shader
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261002
	var tufts := 0
	for band: Array in BANDS:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("ground", tex)
		mat.set_shader_parameter("ground_origin", origin)
		mat.set_shader_parameter("ground_size", size)
		mat.set_shader_parameter("band_density", float(band[0]))
		mat.set_shader_parameter("full_density", float(BANDS[0][0]))
		mat.set_shader_parameter("full_r", FULL_R)
		mat.set_shader_parameter("grass_far", FAR)
		materials.append(mat)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _tuft(int(band[1]), int(band[2]), band == BANDS[0] or band == BANDS[1], rng)
		var count := int(float(band[0]) * CHUNK * CHUNK)
		mm.instance_count = count
		for k in count:
			mm.set_instance_transform(k, Transform3D(Basis.IDENTITY,
				Vector3(rng.randf_range(0.0, CHUNK), 0.0, rng.randf_range(0.0, CHUNK))))
		_meshes.append(mm)
		tufts += count
	# A band is wanted out to where the thinning falls to the next band's
	# density; the last to FAR.
	for b in BANDS.size():
		if b + 1 < BANDS.size():
			_band_out.append(FULL_R * pow(float(BANDS[0][0]) / float(BANDS[b + 1][0]), 1.0 / 1.5))
		else:
			_band_out.append(FAR)
	var reach := int(ceil(FAR / CHUNK)) + 1
	for j in range(-reach, reach + 1):
		for i in range(-reach, reach + 1):
			if _gap(Vector2i(i, j)) <= FAR:
				_offsets.append(Vector2i(i, j))
				var slot := MultiMeshInstance3D.new()
				slot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				slot.visible = false
				add_child(slot)
				_slots.append(slot)
	stats["ms"] = Time.get_ticks_msec() - t0
	stats["slots"] = _slots.size()
	stats["chunks_with_grass"] = _grass_in.size()


## The nearest distance between the camera's chunk and the chunk at
## offset o from it, wherever in its chunk the camera stands.
func _gap(o: Vector2i) -> float:
	var dx := maxf(absf(o.x) - 1.0, 0.0) * CHUNK
	var dz := maxf(absf(o.y) - 1.0, 0.0) * CHUNK
	return Vector2(dx, dz).length()


## Every metre the camera moves, lay the slots round it again, each
## with the band its nearest point wants; and keep the shaders' wind and
## the player's position current.
func follow(camera_pos: Vector3, player_pos: Vector3, wind: float, wind_dir: Vector2) -> void:
	for mat in materials:
		mat.set_shader_parameter("player_pos", player_pos)
		mat.set_shader_parameter("wind", wind)
		mat.set_shader_parameter("wind_dir", wind_dir)
	var cam := Vector2(camera_pos.x, camera_pos.z)
	if cam.distance_to(_placed_at) < 1.0:
		return
	_placed_at = cam
	var at := Vector2i(floori(cam.x / CHUNK), floori(cam.y / CHUNK))
	var shown := 0
	for k in _slots.size():
		var slot := _slots[k]
		var key := at + _offsets[k]
		if not _grass_in.has(key):
			slot.visible = false
			continue
		# The nearest point of the chunk, less the metre the camera may
		# move before the next laying.
		var lo := Vector2(key) * CHUNK
		var nearest := Vector2(clampf(cam.x, lo.x, lo.x + CHUNK), clampf(cam.y, lo.y, lo.y + CHUNK))
		var gap := maxf(cam.distance_to(nearest) - 1.0, 0.0)
		if gap > FAR:
			slot.visible = false
			continue
		var band := BANDS.size() - 1
		for b in BANDS.size():
			if gap <= _band_out[b]:
				band = b
				break
		slot.multimesh = _meshes[band]
		slot.material_override = materials[band]
		var span: Vector2 = _grass_in[key]
		slot.position = Vector3(key.x * CHUNK, 0.0, key.y * CHUNK)
		slot.custom_aabb = AABB(Vector3(-1.5, span.x - 0.5, -1.5), Vector3(CHUNK + 3.0, span.y - span.x + 2.5, CHUNK + 3.0))
		slot.visible = true
		shown += 1
	stats["shown"] = shown


## A tuft of `blades` blades, each `segs` segments long, standing a
## metre tall at full size (the shader sizes it); one blade of the near
## tufts is a flower's stem with a head. COLOR: red the blade's own
## random, green a flower's stem, blue its head; UV.y runs root to tip.
func _tuft(blades: int, segs: int, with_flower: bool, rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := 0.014 * sqrt(10.0 / blades)
	for b in blades:
		var flower_stem := with_flower and b == 0
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(0.0, 0.09)
		var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var face := rng.randf_range(0.0, TAU)
		var side := Vector3(cos(face), 0.0, sin(face))
		var normal := Vector3(-side.z, 0.0, side.x)
		var lean_dir := Vector3(cos(a), 0.0, sin(a)) if r > 0.01 else side
		var lean := rng.randf_range(0.12, 0.5)
		var h := rng.randf_range(0.4, 1.0)
		var w := width * rng.randf_range(0.7, 1.3)
		var own := rng.randf()
		if flower_stem:
			h = rng.randf_range(0.75, 0.95)
			w = 0.005
			lean = 0.05
		var col := Color(own, 1.0 if flower_stem else 0.0, 0.0, 1.0)
		var rows: Array[Vector3] = []
		for k in segs + 1:
			var t := float(k) / segs
			rows.append(base + Vector3.UP * h * t + lean_dir * lean * h * t * t)
		for k in segs:
			var t0 := float(k) / segs
			var t1 := float(k + 1) / segs
			var w0 := w * pow(1.0 - t0, 0.6)
			var w1 := w * pow(1.0 - t1, 0.6) if k + 1 < segs or flower_stem else 0.0
			var p0a := rows[k] - side * w0
			var p0b := rows[k] + side * w0
			var p1a := rows[k + 1] - side * maxf(w1, 0.0005)
			var p1b := rows[k + 1] + side * maxf(w1, 0.0005)
			_quad(st, p0a, p0b, p1b, p1a, t0, t1, normal, col)
		if flower_stem:
			# The head: a small disc of petals facing up, a little tilted.
			var top := rows[segs]
			var head_r := rng.randf_range(0.014, 0.022)
			var head_col := Color(own, 1.0, 1.0, 1.0)
			var tilt := Vector3(rng.randf_range(-0.3, 0.3), 1.0, rng.randf_range(-0.3, 0.3)).normalized()
			var u := tilt.cross(Vector3.FORWARD).normalized()
			var v := tilt.cross(u)
			for k in 6:
				var a0 := TAU * k / 6.0
				var a1 := TAU * (k + 1) / 6.0
				st.set_color(head_col)
				st.set_normal(tilt)
				st.set_uv(Vector2(0.5, 1.0))
				st.add_vertex(top)
				st.set_uv(Vector2(0.0, 1.0))
				st.add_vertex(top + (u * cos(a0) + v * sin(a0)) * head_r)
				st.set_uv(Vector2(1.0, 1.0))
				st.add_vertex(top + (u * cos(a1) + v * sin(a1)) * head_r)
	st.index()
	return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, t0: float, t1: float,
		normal: Vector3, col: Color) -> void:
	var corners: Array[Vector3] = [a, b, c, a, c, d]
	var vs: Array[float] = [t0, t0, t1, t0, t1, t1]
	var us: Array[float] = [0.0, 1.0, 1.0, 0.0, 1.0, 0.0]
	for k in 6:
		st.set_color(col)
		st.set_normal(normal)
		st.set_uv(Vector2(us[k], vs[k]))
		st.add_vertex(corners[k])
