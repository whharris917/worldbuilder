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
## the model's full_r, then falling as the distance to the power 1.5, gone
## by its far),
## and a chunk takes the sparsest band that still carries that rate at
## its nearest point, so the bands meet without a seam. Chunks with no
## grass in them are hidden.
##
## The field is drawn in one of MODELS (`set_model`), changeable while
## the world runs: "full", the dense blades; "light", fewer and broader
## blades of fewer segments, an eighth of the near field's triangles;
## "fluffy", clumps of a few crossed cards cut into blades and lit as
## one mass (grass_fluffy.gdshader); "shells", the ground drawn again in
## thin layers that keep only the strands' cross-sections
## (grass_shell.gdshader); "off", none.

const CHUNK := 8.0
const TEXEL := 0.5
## Each model of blades or clumps: its bands (density in tufts a square
## metre, blades a tuft or cards a clump, segments a blade), full
## density out to full_r, gone by far, blades widen times the usual
## width. Shells: how many layers, strands gone by reach.
const MODELS: Dictionary = {
	"full": {"bands": [[14.0, 10, 4], [7.0, 8, 3], [3.5, 6, 2], [1.4, 5, 1]],
		"full_r": 7.0, "far": 64.0, "widen": 1.0},
	"light": {"bands": [[6.0, 6, 2], [4.0, 5, 1], [2.5, 4, 1], [1.2, 3, 1]],
		"full_r": 7.0, "far": 64.0, "widen": 1.8},
	"fluffy": {"kind": "clumps", "bands": [[2.4, 2, 0], [1.2, 2, 0], [0.6, 2, 0], [0.3, 2, 0]],
		"full_r": 7.0, "far": 56.0, "widen": 1.0},
	"shells": {"kind": "shells", "layers": 16, "reach": 32.0},
}
const MODEL_NAMES: Array[String] = ["full", "light", "fluffy", "shells", "off"]
## A clump's cards: how wide, in metres at full size.
const CARD_W := 0.7
## The shell mesh's grid, in metres.
const SHELL_CELL := 1.0

var origin := Vector2(-128.0, -128.0)
var size := 256.0
var ground_tex: ImageTexture
var model := "full"
var materials: Array[ShaderMaterial] = []
var stats: Dictionary = {}

var _style := "real"
var _bands: Array = []
var _full_r := 7.0
var _far := 64.0
var _shell: MeshInstance3D

var _meshes: Array[MultiMesh] = []
var _slots: Array[MultiMeshInstance3D] = []
var _offsets: Array[Vector2i] = []
var _grass_in: Dictionary = {}       # chunk index -> [min height, max height], for chunks with grass
var _band_out: Array[float] = []     # the distance out to which each band is wanted
var _placed_at := Vector2(1.0e9, 0.0)


## Bake the ground over a square of side `side` round `centre` from the
## landscape's height and the callables' grass and flowers, then make
## the tiles and the slots. `style` picks the look: "real", or the
## drawn styles: "cartoon" and "anime" in grass_toon.gdshader in their
## own greens, "diorama" in grass_lowpoly.gdshader, short blades of one
## flat triangle each. `with_model` is the model to draw.
func build(land: Landscape, centre: Vector2, side: float, grass: Callable, flowers: Callable,
		style := "real", with_model := "full") -> void:
	var t0 := Time.get_ticks_msec()
	_style = style
	size = side
	origin = centre - Vector2(side, side) * 0.5
	var n := int(side / TEXEL)
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBAF)
	for j in n:
		var z := origin.y + (j + 0.5) * TEXEL
		for i in n:
			var x := origin.x + (i + 0.5) * TEXEL
			var g: float = grass.call(x, z)
			var h := land.surface_height(x, z)
			var f: float = flowers.call(x, z) if g > 0.0 else 0.0
			img.set_pixel(i, j, Color(h, g, f, 1.0))
			if g > 0.02:
				var key := Vector2i(floori(x / CHUNK), floori(z / CHUNK))
				if _grass_in.has(key):
					var span: Vector2 = _grass_in[key]
					_grass_in[key] = Vector2(minf(span.x, h), maxf(span.y, h))
				else:
					_grass_in[key] = Vector2(h, h)
	ground_tex = ImageTexture.create_from_image(img)
	set_model(with_model)
	stats["ms"] = Time.get_ticks_msec() - t0
	stats["chunks_with_grass"] = _grass_in.size()


## Draw the field in model `which` (one of MODEL_NAMES), replacing the
## tiles and slots of the last.
func set_model(which: String) -> void:
	model = which if which in MODEL_NAMES else "full"
	for slot in _slots:
		slot.queue_free()
	_slots.clear()
	if _shell != null:
		_shell.queue_free()
		_shell = null
	_offsets.clear()
	_meshes.clear()
	materials.clear()
	_band_out.clear()
	_placed_at = Vector2(1.0e9, 0.0)
	stats["slots"] = 0
	if model == "off":
		return
	var spec: Dictionary = MODELS[model]
	var kind := str(spec.get("kind", "blades"))
	if kind == "shells":
		_make_shells(int(spec["layers"]), float(spec["reach"]))
		return
	_bands = spec["bands"]
	_full_r = float(spec["full_r"])
	_far = float(spec["far"])
	var widen := float(spec["widen"])
	var shader_path := "res://world/grass.gdshader"
	if _style == "cartoon" or _style == "anime":
		shader_path = "res://world/grass_toon.gdshader"
	elif _style == "diorama":
		shader_path = "res://world/grass_lowpoly.gdshader"
	if kind == "clumps":
		shader_path = "res://world/grass_fluffy.gdshader"
	var shader := load(shader_path) as Shader
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261002
	var full_density := float(_bands[0][0])
	for band: Array in _bands:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("ground", ground_tex)
		mat.set_shader_parameter("ground_origin", origin)
		mat.set_shader_parameter("ground_size", size)
		mat.set_shader_parameter("band_density", float(band[0]))
		mat.set_shader_parameter("full_density", full_density)
		mat.set_shader_parameter("full_r", _full_r)
		mat.set_shader_parameter("grass_far", _far)
		_style_colours(mat)
		materials.append(mat)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		# A model's grass: single wide triangles standing nearly upright.
		var flat := _style == "diorama"
		var segs := 1 if flat else int(band[2])
		if kind == "clumps":
			mm.mesh = _clump(int(band[1]))
		else:
			mm.mesh = _tuft(int(band[1]), segs, band == _bands[0] or band == _bands[1], rng,
				(3.0 if flat else 1.0) * widen, 0.25 if flat else 1.0)
		var count := int(float(band[0]) * CHUNK * CHUNK)
		mm.instance_count = count
		for k in count:
			mm.set_instance_transform(k, Transform3D(Basis.IDENTITY,
				Vector3(rng.randf_range(0.0, CHUNK), 0.0, rng.randf_range(0.0, CHUNK))))
		_meshes.append(mm)
	_lay_slots(full_density)


## The look's colours for the grass, the same names in every grass shader.
func _style_colours(mat: ShaderMaterial) -> void:
	match _style:
		"cartoon":
			mat.set_shader_parameter("green", Color(0.27, 0.52, 0.16))
			mat.set_shader_parameter("yellow_green", Color(0.44, 0.64, 0.20))
			mat.set_shader_parameter("seed_tan", Color(0.80, 0.72, 0.40))
		"anime":
			mat.set_shader_parameter("green", Color(0.16, 0.46, 0.20))
			mat.set_shader_parameter("yellow_green", Color(0.46, 0.72, 0.22))
			mat.set_shader_parameter("seed_tan", Color(0.84, 0.80, 0.44))
			mat.set_shader_parameter("toon_step", 0.3)
			mat.set_shader_parameter("height_scale", 1.15)
		"diorama":
			mat.set_shader_parameter("green", Color(0.46, 0.68, 0.32))
			mat.set_shader_parameter("yellow_green", Color(0.62, 0.80, 0.38))
			mat.set_shader_parameter("seed_tan", Color(0.86, 0.80, 0.56))
			mat.set_shader_parameter("height_scale", 0.4)


## The chunk slots round the camera for the bands just made.
func _lay_slots(full_density: float) -> void:
	# A band is wanted out to where the thinning falls to the next band's
	# density; the last to the model's reach.
	for b in _bands.size():
		if b + 1 < _bands.size():
			_band_out.append(_full_r * pow(full_density / float(_bands[b + 1][0]), 1.0 / 1.5))
		else:
			_band_out.append(_far)
	var reach := int(ceil(_far / CHUNK)) + 1
	for j in range(-reach, reach + 1):
		for i in range(-reach, reach + 1):
			if _gap(Vector2i(i, j)) <= _far:
				_offsets.append(Vector2i(i, j))
				var slot := MultiMeshInstance3D.new()
				slot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				slot.visible = false
				add_child(slot)
				_slots.append(slot)
	stats["slots"] = _slots.size()


## The shell mesh: `layers` layers of a grid round the camera, the top
## first so the layers below are hidden behind it where they can be;
## each layer a disc, the higher ones smaller, as the strands that
## reach them thin out with distance. UV2.x is the layer's height.
func _make_shells(layers: int, reach: float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://world/grass_shell.gdshader") as Shader
	mat.set_shader_parameter("ground", ground_tex)
	mat.set_shader_parameter("ground_origin", origin)
	mat.set_shader_parameter("ground_size", size)
	mat.set_shader_parameter("reach", reach)
	_style_colours(mat)
	materials.append(mat)
	var verts := PackedVector3Array()
	var uv2 := PackedVector2Array()
	var index := PackedInt32Array()
	for i in range(layers, 0, -1):
		var t := float(i) / layers
		var r := reach * (1.0 - 0.55 * t)
		# Past the middle distance every other layer is left out: the
		# layers there are too close on screen to tell apart.
		if i % 2 == 1:
			r = minf(r, reach * 0.4)
		var n := int(ceil(r / SHELL_CELL))
		var first := verts.size()
		for j in range(-n, n + 1):
			for k in range(-n, n + 1):
				verts.append(Vector3(k * SHELL_CELL, 0.0, j * SHELL_CELL))
				uv2.append(Vector2(t, 0.0))
		var row := 2 * n + 1
		for j in 2 * n:
			for k in 2 * n:
				var centre := Vector2(k - n + 0.5, j - n + 0.5) * SHELL_CELL
				if centre.length() > r:
					continue
				var a := first + j * row + k
				index.append_array([a, a + row, a + 1, a + 1, a + row, a + row + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_shell = MeshInstance3D.new()
	_shell.name = "Shells"
	_shell.mesh = mesh
	_shell.material_override = mat
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shell.custom_aabb = AABB(Vector3(-reach - 2.0, -500.0, -reach - 2.0), Vector3(2.0 * reach + 4.0, 1000.0, 2.0 * reach + 4.0))
	add_child(_shell)
	stats["shell_quads"] = index.size() / 6


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
	if _shell != null:
		# On whole cells, so the grid's corners stay on the same ground.
		_shell.position = Vector3(snappedf(camera_pos.x, SHELL_CELL), 0.0, snappedf(camera_pos.z, SHELL_CELL))
		return
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
		if gap > _far:
			slot.visible = false
			continue
		var band := _bands.size() - 1
		for b in _bands.size():
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
## metre tall at full size (the shader sizes it), `widen` times the
## usual width and leaning `lean_by` times the usual lean; one blade of
## the near tufts is a flower's stem with a head. COLOR: red the blade's own
## random, green a flower's stem, blue its head; UV.y runs root to tip.
func _tuft(blades: int, segs: int, with_flower: bool, rng: RandomNumberGenerator,
		widen := 1.0, lean_by := 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := 0.014 * sqrt(10.0 / blades) * widen
	for b in blades:
		var flower_stem := with_flower and b == 0
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(0.0, 0.09)
		var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var face := rng.randf_range(0.0, TAU)
		var side := Vector3(cos(face), 0.0, sin(face))
		var normal := Vector3(-side.z, 0.0, side.x)
		var lean_dir := Vector3(cos(a), 0.0, sin(a)) if r > 0.01 else side
		var lean := rng.randf_range(0.12, 0.5) * lean_by
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


## A clump of `cards` upright cards CARD_W wide and a metre tall,
## crossed through the centre at even angles; UV.x runs across a card,
## UV.y root to top; normals up (the shader lights the clump as one).
func _clump(cards: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in cards:
		var a := PI * c / cards
		var side := Vector3(cos(a), 0.0, sin(a)) * CARD_W * 0.5
		_quad(st, -side, side, side + Vector3.UP, -side + Vector3.UP, 0.0, 1.0,
			Vector3.UP, Color(0.0, 0.0, 0.0, 1.0))
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
