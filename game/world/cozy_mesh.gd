class_name CozyMesh
extends RefCounted
## A mesh built cozy-native: shapes added one after another straight into
## one set of arrays, each painted a flat colour in its vertices, then
## committed as a single mesh with one material that takes the vertex
## colour as its albedo. A whole works' still parts come out as one
## object to draw, with only as many sides to each round shape as asked.
##
## Shapes come from the engine's primitives (their arrays, read once),
## placed by a transform; normals are carried through the transform's
## inverse transpose, so a stretched shape still shades right.

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colours := PackedColorArray()
var _index := PackedInt32Array()


func add(mesh: PrimitiveMesh, xf: Transform3D, colour: Color) -> void:
	var arrays := mesh.get_mesh_arrays()
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var base := _verts.size()
	var nb := xf.basis.inverse().transposed()
	var c := colour.srgb_to_linear()
	for i in v.size():
		_verts.append(xf * v[i])
		_normals.append((nb * n[i]).normalized())
		_colours.append(c)
	for i in idx:
		_index.append(base + i)


func box(size: Vector3, xf: Transform3D, colour: Color) -> void:
	var m := BoxMesh.new()
	m.size = size
	add(m, xf, colour)


func cyl(top: float, bottom: float, height: float, sides: int, xf: Transform3D, colour: Color, caps := true) -> void:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	m.cap_top = caps
	m.cap_bottom = caps
	add(m, xf, colour)


func ball(radius: float, sides: int, xf: Transform3D, colour: Color, hemisphere := false, height := -1.0) -> void:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0 if height < 0.0 else height
	m.radial_segments = sides
	m.rings = maxi(sides / 2, 3)
	m.is_hemisphere = hemisphere
	add(m, xf, colour)


func torus(inner: float, outer: float, rings: int, segments: int, xf: Transform3D, colour: Color) -> void:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = rings
	m.ring_segments = segments
	add(m, xf, colour)


func prism(size: Vector3, xf: Transform3D, colour: Color) -> void:
	var m := PrismMesh.new()
	m.size = size
	add(m, xf, colour)


## A round rod of `radius` from a to b.
func rod(a: Vector3, b: Vector3, radius: float, sides: int, colour: Color) -> void:
	cyl(radius, radius, a.distance_to(b), sides, Transform3D(aligned(b - a), (a + b) * 0.5), colour)


## A basis whose y runs along `dir`.
static func aligned(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


static func at(p: Vector3, b := Basis.IDENTITY) -> Transform3D:
	return Transform3D(b, p)


## A flat four-sided face a, b, c, d (in order round its edge), facing
## the side `normal` points to.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, colour: Color) -> void:
	quad_normals(a, b, c, d, [normal, normal, normal, normal], colour)


## A four-sided face with a normal at each corner, for a curved surface
## drawn smooth; it faces the side of the corners' mean normal.
func quad_normals(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normals: Array, colour: Color) -> void:
	var base := _verts.size()
	var c_lin := colour.srgb_to_linear()
	var points := [a, b, c, d]
	for k in 4:
		_verts.append(points[k])
		_normals.append((normals[k] as Vector3).normalized())
		_colours.append(c_lin)
	var mean: Vector3 = normals[0] + normals[1] + normals[2] + normals[3]
	# The engine draws a triangle's front where its corners run clockwise
	# seen from that side.
	if (b - a).cross(c - a).dot(mean) <= 0.0:
		_index.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	else:
		_index.append_array([base, base + 2, base + 1, base, base + 3, base + 2])


## A primitive shape seen from inside: its faces turned inward, for the
## inner side of a hollow thing.
func add_inside(mesh: PrimitiveMesh, xf: Transform3D, colour: Color) -> void:
	var start_v := _verts.size()
	var start_i := _index.size()
	add(mesh, xf, colour)
	for i in range(start_v, _verts.size()):
		_normals[i] = -_normals[i]
	for t in range(start_i, _index.size(), 3):
		var keep := _index[t + 1]
		_index[t + 1] = _index[t + 2]
		_index[t + 2] = keep


func is_empty() -> bool:
	return _verts.is_empty()


## The mesh, its one surface wearing `material`.
func commit(material: Material) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colours
	arrays[Mesh.ARRAY_INDEX] = _index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh
