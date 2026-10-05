class_name SpinningShell
extends MeshInstance3D
## A bowl of stone: one cap of a spherical shell, from its pole down to a
## tenth of the radius above its equator, as if a ribbon a fifth of the
## radius wide had been cut round the middle and the far half taken
## away. Its rim is faced. It
## spins at a steady rate, one turn a `period`, about an axis drawn at
## random afresh every `AXIS_EVERY` seconds; the turn carries on from
## where the shell stands, so only the axis changes.

const AXIS_EVERY := 10.0
const LON := 96                         # segments round: 15 cm short of round at 500 m
const LAT := 20                         # rings from the cut edge to the pole

var radius := 100.0                     # m, the outer face
var period := 10.0                      # s, one turn
var axis := Vector3.UP

var _rng: RandomNumberGenerator
var _axis_in := 0.0


func _init(r: float, material: Material, rng: RandomNumberGenerator) -> void:
	radius = r
	_rng = rng
	material_override = material
	mesh = _build_mesh(r, r * 0.98, true)
	# The shadow comes from the outer face alone, drawn both ways round:
	# one layer to draw into the sun's shadow map instead of three.
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var caster := MeshInstance3D.new()
	caster.mesh = _build_mesh(r, r, false)
	caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	var both_ways := StandardMaterial3D.new()
	both_ways.cull_mode = BaseMaterial3D.CULL_DISABLED
	caster.material_override = both_ways
	add_child(caster)
	period = rng.randf_range(5.0, 30.0)
	basis = Basis(_random_axis(), rng.randf_range(0.0, TAU))
	axis = _random_axis()
	_axis_in = AXIS_EVERY


func _process(delta: float) -> void:
	_axis_in -= delta
	if _axis_in <= 0.0:
		_axis_in += AXIS_EVERY
		axis = _random_axis()
	basis = Basis(axis, TAU * delta / period) * basis
	basis = basis.orthonormalized()


## A direction drawn evenly over the sphere.
func _random_axis() -> Vector3:
	var z := _rng.randf_range(-1.0, 1.0)
	var a := _rng.randf_range(0.0, TAU)
	var s := sqrt(1.0 - z * z)
	return Vector3(s * cos(a), z, s * sin(a))


## The cap: an outer face and, if `solid`, an inner face and the face of
## the rim between them.
func _build_mesh(outer: float, inner: float, solid: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge := asin(0.1)               # the rim's latitude: y = r / 10
	for i in LAT:
		var a0 := lerpf(edge, PI / 2.0, float(i) / LAT)
		var a1 := lerpf(edge, PI / 2.0, float(i + 1) / LAT)
		for j in LON:
			var b0 := TAU * j / LON
			var b1 := TAU * (j + 1) / LON
			for face: Array in ([[outer, 1.0], [inner, -1.0]] if solid else [[outer, 1.0]]):
				var r: float = face[0]
				var out: float = face[1]
				var p00 := _on(a0, b0)
				var p01 := _on(a0, b1)
				var p10 := _on(a1, b0)
				var p11 := _on(a1, b1)
				_quad(st, [p00 * r, p01 * r, p11 * r, p10 * r],
					[p00 * out, p01 * out, p11 * out, p10 * out])
	# The rim: a ring between the two faces, facing away from the pole.
	for j in (LON if solid else 0):
		var q0 := _on(edge, TAU * j / LON)
		var q1 := _on(edge, TAU * (j + 1) / LON)
		_quad(st, [q0 * outer, q1 * outer, q1 * inner, q0 * inner], [Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN])
	st.index()
	st.generate_tangents()
	return st.commit()


## The unit vector at latitude a (from the equator) and longitude b.
static func _on(a: float, b: float) -> Vector3:
	return Vector3(cos(a) * cos(b), sin(a), cos(a) * sin(b))


## A quad as two triangles, each wound so its front faces the way its
## normals point (Godot draws a triangle's front where its corners run
## clockwise). UVs are unused (the material is triplanar) but tangents
## are generated from them.
static func _quad(st: SurfaceTool, p: Array, n: Array) -> void:
	for tri: Array in [[0, 1, 2], [0, 2, 3]]:
		var p0: Vector3 = p[tri[0]]
		var p1: Vector3 = p[tri[1]]
		var p2: Vector3 = p[tri[2]]
		var normal: Vector3 = n[tri[0]] + n[tri[1]] + n[tri[2]]
		var order: Array = tri if (p1 - p0).cross(p2 - p0).dot(normal) < 0.0 else [tri[0], tri[2], tri[1]]
		for k: int in order:
			var v: Vector3 = p[k]
			st.set_normal(n[k])
			st.set_uv(Vector2(atan2(v.z, v.x), v.y))
			st.add_vertex(v)
