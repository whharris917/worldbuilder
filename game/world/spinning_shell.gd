class_name SpinningShell
extends MeshInstance3D
## A bowl of stone: one cap of a spherical shell, from its pole down to a
## tenth of the radius above its equator, as if a ribbon a fifth of the
## radius wide had been cut round the middle and the far half taken
## away. Its rim is faced. It
## spins at a steady rate, one turn a `period`, about an axis drawn at
## random afresh every `AXIS_EVERY` seconds; the turn carries on from
## where the shell stands, so only the axis changes. `turned` is given
## at each change of axis.
##
## Its outer face and rim take the sky's ambient light; its inner face
## does not, since the bowls around it shut most of the sky out, so
## inside it is lit by the sun through the gaps alone. On the inner face
## run four rings of small lights, 1.5 m long and 10 m apart whatever the
## bowl's size, so the farther bowls show finer rings; they flare when
## the bowl jolts onto a new axis and fade over a few seconds.

signal turned

const AXIS_EVERY := 10.0
const LON := 96                         # segments round: 15 cm short of round at 500 m
const LAT := 20                         # rings from the cut edge to the pole
const LIGHT_RINGS: Array[float] = [0.17, 0.45, 0.8, 1.15]   # latitudes, rad
const LIGHT_GAP := 10.0                 # m between lights along a ring
const LIGHT_GLOW := 1.5                 # the lights' steady brightness

var radius := 100.0                     # m, the outer face
var period := 10.0                      # s, one turn
var axis := Vector3.UP

var _rng: RandomNumberGenerator
var _axis_in := 0.0
var _lamp_mat: StandardMaterial3D
var _flare := 0.0


func _init(r: float, material: Material, rng: RandomNumberGenerator) -> void:
	radius = r
	_rng = rng
	var walls := _build_mesh(r, r * 0.98, true)
	walls.surface_set_material(0, material)
	var inside := material.duplicate() as StandardMaterial3D
	inside.disable_ambient_light = true
	walls.surface_set_material(1, inside)
	mesh = walls
	_build_lights(r * 0.98)
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
		_flare = 6.0
		turned.emit()
	basis = Basis(axis, TAU * delta / period) * basis
	basis = basis.orthonormalized()
	if _flare > 0.01:
		_flare *= exp(-delta / 1.2)
		_lamp_mat.emission_energy_multiplier = LIGHT_GLOW + _flare


## The rings of lights on the inner face, `inner` from the centre, each
## facing the centre; alternate rings offset by half a gap.
func _build_lights(inner: float) -> void:
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp_mat.albedo_color = Color(0.75, 0.88, 1.0)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(0.75, 0.88, 1.0)
	_lamp_mat.emission_energy_multiplier = LIGHT_GLOW
	var lamp := BoxMesh.new()
	lamp.size = Vector3(1.5, 0.35, 0.2)
	lamp.material = _lamp_mat
	var xforms: Array[Transform3D] = []
	for k in LIGHT_RINGS.size():
		var lat := LIGHT_RINGS[k]
		var count := int(TAU * inner * cos(lat) / LIGHT_GAP)
		for j in count:
			var lon := TAU * (j + 0.5 * (k % 2)) / count
			var out := _on(lat, lon)
			var along := Vector3(-sin(lon), 0.0, cos(lon))
			xforms.append(Transform3D(Basis(along, -out.cross(along), -out), out * (inner - 0.05)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = lamp
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var lights := MultiMeshInstance3D.new()
	lights.multimesh = mm
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lights)


## The way the bowl's pole points, from its centre: the middle of the
## stone side.
func pole() -> Vector3:
	return basis.y.normalized()


## A direction drawn evenly over the sphere.
func _random_axis() -> Vector3:
	var z := _rng.randf_range(-1.0, 1.0)
	var a := _rng.randf_range(0.0, TAU)
	var s := sqrt(1.0 - z * z)
	return Vector3(s * cos(a), z, s * sin(a))


## The cap: an outer face and, if `solid`, the face of the rim and, as a
## second surface, the inner face.
func _build_mesh(outer: float, inner: float, solid: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_in := SurfaceTool.new()
	st_in.begin(Mesh.PRIMITIVE_TRIANGLES)
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
				_quad(st if out > 0.0 else st_in, [p00 * r, p01 * r, p11 * r, p10 * r],
					[p00 * out, p01 * out, p11 * out, p10 * out])
	# The rim: a ring between the two faces, facing away from the pole.
	for j in (LON if solid else 0):
		var q0 := _on(edge, TAU * j / LON)
		var q1 := _on(edge, TAU * (j + 1) / LON)
		_quad(st, [q0 * outer, q1 * outer, q1 * inner, q0 * inner], [Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN])
	st.index()
	st.generate_tangents()
	var mesh_out := st.commit()
	if solid:
		st_in.index()
		st_in.generate_tangents()
		st_in.commit(mesh_out)
	return mesh_out


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
