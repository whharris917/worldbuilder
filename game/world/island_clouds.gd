class_name IslandClouds
extends Node3D
## Fair-weather clouds over the cozy island: white heaps of cumulus
## 160-420 m long, their bases 300-520 m up, each a cluster of rounded lumps cut flat underneath where
## the air reaches the height at which its moisture condenses, as a real
## cumulus's base is. They are solid objects lit by the island's sun, in
## the island's own white material (CozyIsland.surface), so the look
## switches reach them: toon light, coloured shade, outlines.
##
## Each cloud forms (grows from nothing over a minute or so), drifts on a
## light wind, and after some minutes dissolves (shrinks away), as
## cumulus do; another forms elsewhere. `amount` sets how many there are,
## 0 none to 1 a sky well filled (CLOUDS at most); a change is met by new
## ones forming or old ones dissolving, never by any popping in or out.
## They ignore the depth haze, which would wash them away at their
## distance, and cast no shadows.

const CLOUDS := 60                       # at the most
const REACH := 2500.0                    # how far from the island's middle they lie
const WIND := Vector2(-2.6, 1.4)         # m/s
const FORM := 75.0                       # seconds to form, and to dissolve

## 0 none to 1 a sky well filled.
var amount := 0.4
var island: CozyIsland
var _mat: StandardMaterial3D
var _clouds: Array[Dictionary] = []      # node, age, life, size, leaving
var _rng := RandomNumberGenerator.new()
var _plan_left := 0.0


func _init(owner_island: CozyIsland) -> void:
	name = "Clouds"
	island = owner_island
	_rng.seed = 2024


func _ready() -> void:
	_mat = island.surface("", 1.0, Color.WHITE, 0.9, Color.WHITE,
			{"line_colour": Color(0.72, 0.78, 0.9)})
	_mat.vertex_color_use_as_albedo = true
	_mat.disable_fog = true
	# The sky starts with its clouds already formed, at every stage of
	# their lives.
	for i in roundi(amount * CLOUDS):
		var c := _form(Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * REACH * 0.8)
		c["age"] = _rng.randf_range(FORM, float(c["life"]) - FORM)


## A new cloud starting to form at `at` (x, z).
func _form(at: Vector2) -> Dictionary:
	var view := MeshInstance3D.new()
	view.mesh = _heap(_rng.randf_range(160.0, 420.0))
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.position = Vector3(at.x, _rng.randf_range(300.0, 520.0), at.y)
	view.rotation.y = _rng.randf() * TAU
	view.scale = Vector3.ONE * 0.001
	add_child(view)
	var c := {"node": view, "age": 0.0, "life": _rng.randf_range(420.0, 900.0), "leaving": false}
	_clouds.append(c)
	return c


## ---- a cloud's shape ----------------------------------------------------------

## A heap `length` metres long, its base at y = 0: a row of big lumps
## along it, largest in the middle, a few beside them for depth, then
## smaller ones piled on top; every lump cut off flat at the base.
func _heap(length: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var index := PackedInt32Array()
	var row := _rng.randi_range(3, 6)
	var lumps: Array[Vector4] = []        # centre, radius
	for i in row:
		var t := (float(i) / (row - 1)) * 2.0 - 1.0 if row > 1 else 0.0
		var r := length * _rng.randf_range(0.15, 0.22) * (1.0 - 0.35 * absf(t))
		lumps.append(Vector4(t * length * 0.38, r * 0.2, _rng.randf_range(-0.06, 0.06) * length, r))
	for i in _rng.randi_range(2, 3):
		var r := length * _rng.randf_range(0.13, 0.18)
		var side := 1.0 if i % 2 == 0 else -1.0
		lumps.append(Vector4(_rng.randf_range(-0.25, 0.25) * length, r * 0.15, side * length * 0.14, r))
	for i in _rng.randi_range(2, 4):
		var r := length * _rng.randf_range(0.12, 0.19)
		lumps.append(Vector4(_rng.randf_range(-0.2, 0.2) * length, length * _rng.randf_range(0.14, 0.24), _rng.randf_range(-0.07, 0.07) * length, r))
	if _rng.randf() < 0.6:
		var r := length * _rng.randf_range(0.1, 0.14)
		lumps.append(Vector4(_rng.randf_range(-0.1, 0.1) * length, length * _rng.randf_range(0.3, 0.36), 0.0, r))
	for l: Vector4 in lumps:
		_lump(verts, normals, index, Vector3(l.x, l.y, l.z), l.w)
	var colours := PackedColorArray()
	colours.resize(verts.size())
	colours.fill(Color.WHITE)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _mat)
	return mesh


## One round lump, its points below the base pressed up onto it and
## facing down there.
func _lump(verts: PackedVector3Array, normals: PackedVector3Array, index: PackedInt32Array,
		centre: Vector3, radius: float) -> void:
	var sides := 18
	var rings := 10
	var first := verts.size()
	for ring in rings + 1:
		var theta := PI * ring / rings
		for s in sides + 1:
			var phi := TAU * s / sides
			var n := Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
			var p := centre + n * radius
			if p.y < 0.0:
				p.y = 0.0
				n = Vector3.DOWN
			verts.append(p)
			normals.append(n)
	for ring in rings:
		for s in sides:
			var a := first + ring * (sides + 1) + s
			var b := a + sides + 1
			index.append_array([a, b, a + 1, a + 1, b, b + 1])


## ---- each frame --------------------------------------------------------------

func _process(delta: float) -> void:
	_plan_left -= delta
	if _plan_left <= 0.0:
		_plan_left = 2.0
		_plan()
	var gone: Array[Dictionary] = []
	for c: Dictionary in _clouds:
		var view := c["node"] as MeshInstance3D
		c["age"] = float(c["age"]) + delta
		view.position += Vector3(WIND.x, 0.0, WIND.y) * delta
		var age: float = c["age"]
		var life: float = c["life"]
		# Formed, then dissolving at the end of its life, or sooner when
		# sent away or drifted out over the edge of the sky.
		var flat := Vector2(view.position.x, view.position.z)
		if not c["leaving"] and (age > life - FORM or flat.length() > REACH):
			c["leaving"] = true
			c["life"] = age + FORM
			life = age + FORM
		var grown := smoothstep(0.0, FORM, age) * smoothstep(life, life - FORM, age)
		# Clouds grow up from their base, wider before taller.
		view.scale = Vector3(lerpf(0.3, 1.0, grown), grown, lerpf(0.3, 1.0, grown)) * maxf(grown, 0.001) ** 0.5
		if age >= life:
			gone.append(c)
	for c: Dictionary in gone:
		_clouds.erase(c)
		(c["node"] as Node).queue_free()


## Keeps as many clouds as `amount` asks: new ones forming somewhere in
## the sky, or the oldest dissolving.
func _plan() -> void:
	var want := roundi(amount * CLOUDS)
	var living: Array[Dictionary] = []
	for c: Dictionary in _clouds:
		if not c["leaving"]:
			living.append(c)
	if living.size() < want:
		# Upwind more often, so the sky refills from where the wind comes.
		var p := Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * REACH * 0.85
		if _rng.randf() < 0.5:
			p -= WIND.normalized() * REACH * 0.4
		_form(p.limit_length(REACH * 0.9))
	elif living.size() > want:
		var oldest: Dictionary = living[0]
		for c: Dictionary in living:
			if float(c["age"]) > float(oldest["age"]):
				oldest = c
		oldest["leaving"] = true
		oldest["life"] = maxf(float(oldest["age"]), FORM) + FORM
		if float(oldest["age"]) < FORM:
			# Still forming: it dissolves from where it has grown to.
			oldest["life"] = float(oldest["age"]) * 2.0
