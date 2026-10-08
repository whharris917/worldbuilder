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
## cumulus do; another forms elsewhere. `amount` sets how many there are
## and how big, 0 none to 1 a sky well filled (CLOUDS at most, half as
## large again); a change is met within seconds by clouds forming or
## dissolving quickly, never by any popping in or out. Clouds far from
## the island are built with fewer sides to their lumps.
## They ignore the depth haze, which would wash them away at their
## distance, and cast no shadows.

const CLOUDS := 160                      # at the most
const REACH := 2500.0                    # how far from the island's middle they lie
const WIND := Vector2(-2.6, 1.4)         # m/s
const FORM := 75.0                       # seconds to form, and to dissolve, in the sky's own time
const QUICK := 8.0                       # seconds to, when the amount is changed

## 0 none to 1 a sky well filled.
var amount := 0.4:
	set(value):
		amount = value
		_hurry = true
var island: CozyIsland
var _mat: StandardMaterial3D
# Each cloud: node, age, life (when it starts to dissolve of itself),
# form (seconds to form), leave_at (when it began dissolving, INF while
# it has not), leave_for (seconds to dissolve).
var _clouds: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _plan_left := 0.0
var _hurry := false
var _started := false


func _init(owner_island: CozyIsland) -> void:
	name = "Clouds"
	island = owner_island
	_rng.seed = 2024


func _ready() -> void:
	_mat = island.surface("", 1.0, Color.WHITE, 0.9, Color.WHITE,
			{"line_colour": Color(0.72, 0.78, 0.9)})
	_mat.vertex_color_use_as_albedo = true
	_mat.disable_fog = true


## A new cloud starting to form at `at` (x, z), over `form` seconds.
func _form(at: Vector2, form: float) -> Dictionary:
	var view := MeshInstance3D.new()
	var fine := at.length() < 900.0
	view.mesh = _heap(_rng.randf_range(160.0, 420.0) * lerpf(1.0, 1.5, amount), 16 if fine else 11, 9 if fine else 6)
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.position = Vector3(at.x, _rng.randf_range(300.0, 520.0), at.y)
	view.rotation.y = _rng.randf() * TAU
	view.scale = Vector3.ONE * 0.001
	add_child(view)
	var c := {"node": view, "age": 0.0, "life": _rng.randf_range(420.0, 900.0), "form": form,
			"leave_at": INF, "leave_for": FORM}
	_clouds.append(c)
	return c


## ---- a cloud's shape ----------------------------------------------------------

## A heap `length` metres long, its base at y = 0: a row of big lumps
## along it, largest in the middle, a few beside them for depth, then
## smaller ones piled on top; every lump cut off flat at the base.
func _heap(length: float, sides: int, rings: int) -> ArrayMesh:
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
		_lump(verts, normals, index, Vector3(l.x, l.y, l.z), l.w, sides, rings)
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
		centre: Vector3, radius: float, sides: int, rings: int) -> void:
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
	if not _started:
		# The sky starts with its clouds already formed, at every stage of
		# their lives.
		_started = true
		_hurry = false
		for k in roundi(amount * CLOUDS):
			var c := _form(Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * REACH * 0.85, FORM)
			c["age"] = _rng.randf_range(FORM, float(c["life"]))
	_plan_left -= delta
	if _plan_left <= 0.0:
		_plan_left = 0.2
		_plan()
	var gone: Array[Dictionary] = []
	for c: Dictionary in _clouds:
		var view := c["node"] as MeshInstance3D
		var age: float = float(c["age"]) + delta
		c["age"] = age
		view.position += Vector3(WIND.x, 0.0, WIND.y) * delta
		# At the end of its life, or drifted out over the edge of the sky,
		# it dissolves.
		var flat := Vector2(view.position.x, view.position.z)
		if float(c["leave_at"]) == INF and (age > float(c["life"]) or flat.length() > REACH):
			c["leave_at"] = age
			c["leave_for"] = FORM
		var leave_at: float = c["leave_at"]
		var leave_for: float = c["leave_for"]
		var grown := smoothstep(0.0, float(c["form"]), age)
		if leave_at != INF:
			grown *= 1.0 - smoothstep(leave_at, leave_at + leave_for, age)
			if age >= leave_at + leave_for:
				gone.append(c)
		# Clouds grow up from their base, wider before taller.
		var g := maxf(grown, 0.001)
		view.scale = Vector3(lerpf(0.3, 1.0, g), g, lerpf(0.3, 1.0, g)) * sqrt(g)
	for c: Dictionary in gone:
		_clouds.erase(c)
		(c["node"] as Node).queue_free()


## Keeps as many clouds as `amount` asks. After a change of amount,
## clouds form or dissolve quickly, several at a time, until the count is
## met; otherwise one at a time at the sky's own pace (a cloud that has
## dissolved of itself is replaced by one slowly forming).
func _plan() -> void:
	var want := roundi(amount * CLOUDS)
	var living: Array[Dictionary] = []
	for c: Dictionary in _clouds:
		if float(c["leave_at"]) == INF:
			living.append(c)
	var short := want - living.size()
	if short == 0:
		_hurry = false
		return
	var at_once := mini(absi(short), 12) if _hurry else 1
	var pace := QUICK if _hurry else FORM
	if short > 0:
		for k in at_once:
			# Upwind more often, so the sky refills from where the wind comes.
			var p := Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * REACH * 0.85
			if not _hurry and _rng.randf() < 0.5:
				p -= WIND.normalized() * REACH * 0.4
			var c := _form(p.limit_length(REACH * 0.9), _rng.randf_range(pace * 0.7, pace * 1.3))
			if _hurry:
				# Formed at a random point of its life, so they do not all
				# dissolve together later.
				c["life"] = _rng.randf_range(60.0, 900.0)
	else:
		living.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["age"]) > float(b["age"]))
		for k in at_once:
			var c: Dictionary = living[k]
			c["leave_at"] = c["age"]
			c["leave_for"] = _rng.randf_range(pace * 0.7, pace * 1.3)
