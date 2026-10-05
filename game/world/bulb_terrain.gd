class_name BulbTerrain
extends StaticBody3D
## The ground outside the one-bulb room: a height field h(x, z), each
## point's height a sum of octaves of simplex noise (fractal Brownian
## motion: each octave twice the frequency of the last and `roughness`
## times its amplitude), laid on a mesh of rings round the room. The
## rings grow apart geometrically, about 0.4 m near the room and 45 m at
## the horizon, so the detail falls off as the eye's does from the
## room. The ground is level out to a little past the wall and rises
## into the hills over a quarter of `feature`. The collider is built from
## the same mesh, so what is walked on is what is seen. With `closed` the
## middle is filled too, a level disc fanned from the centre, for a world
## with no room standing there.

const RINGS := 160
const SEGMENTS := 384

var height := 30.0                      # m, the highest hills
var feature := 400.0                    # m, the size of the largest hills
var roughness := 0.5                    # each octave's amplitude against the last
var noise_seed := 1
var flat_r := 15.0                      # m, the room's radius: the terrain starts here
var outer_r := 1500.0                   # m, where the ground ends
var closed := false                     # fill the middle inside flat_r

var _view: MeshInstance3D
var _shape: CollisionShape3D
var _noise := FastNoiseLite.new()


func _init(material: Material) -> void:
	name = "Terrain"
	_view = MeshInstance3D.new()
	_view.material_override = material
	add_child(_view)
	_shape = CollisionShape3D.new()
	add_child(_shape)


func height_at(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	var rise := smoothstep(flat_r + 4.0, flat_r + 4.0 + feature * 0.25, d)
	if rise <= 0.0:
		return 0.0
	# The noise sum runs about -0.7 to 0.7; mapped to 0..1 and squared,
	# so valleys are broad and hilltops rounder and fewer.
	var n := clampf(_noise.get_noise_2d(x, z) / 0.7 * 0.5 + 0.5, 0.0, 1.0)
	return height * rise * n * n


func build() -> void:
	_noise.seed = noise_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0 / feature
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 8
	_noise.fractal_lacunarity = 2.0
	_noise.fractal_gain = roughness
	var ring_count := (RINGS + 1) * SEGMENTS
	var count := ring_count + (1 if closed else 0)
	var verts := PackedVector3Array()
	verts.resize(count)
	var uvs := PackedVector2Array()
	uvs.resize(count)
	for i in RINGS + 1:
		var r := flat_r * pow(outer_r / flat_r, float(i) / RINGS)
		for j in SEGMENTS:
			var a := TAU * j / SEGMENTS
			var x := r * sin(a)
			var z := -r * cos(a)
			verts[i * SEGMENTS + j] = Vector3(x, height_at(x, z), z)
			uvs[i * SEGMENTS + j] = Vector2(x, z)
	# Normals across each vertex's neighbours, out and round; tangents
	# along +x laid onto the surface (the texture's u runs with x).
	var normals := PackedVector3Array()
	normals.resize(count)
	var tangents := PackedFloat32Array()
	tangents.resize(count * 4)
	for i in RINGS + 1:
		var i0 := maxi(i - 1, 0) * SEGMENTS
		var i1 := mini(i + 1, RINGS) * SEGMENTS
		for j in SEGMENTS:
			var jp := (j + 1) % SEGMENTS
			var jm := (j + SEGMENTS - 1) % SEGMENTS
			var out := verts[i1 + j] - verts[i0 + j]
			var round := verts[i * SEGMENTS + jp] - verts[i * SEGMENTS + jm]
			var n := round.cross(out).normalized()
			if n.y < 0.0:
				n = -n
			normals[i * SEGMENTS + j] = n
			var t := (Vector3.RIGHT - n * n.x).normalized()
			var k := (i * SEGMENTS + j) * 4
			tangents[k] = t.x
			tangents[k + 1] = t.y
			tangents[k + 2] = t.z
			tangents[k + 3] = 1.0
	if closed:
		verts[ring_count] = Vector3.ZERO
		uvs[ring_count] = Vector2.ZERO
		normals[ring_count] = Vector3.UP
		var k := ring_count * 4
		tangents[k] = 1.0
		tangents[k + 3] = 1.0
	var indices := PackedInt32Array()
	indices.resize(RINGS * SEGMENTS * 6 + (SEGMENTS * 3 if closed else 0))
	var faces := PackedVector3Array()
	var up_first := _up_first()
	var w := 0
	for i in RINGS:
		for j in SEGMENTS:
			var v00 := i * SEGMENTS + j
			var v01 := i * SEGMENTS + (j + 1) % SEGMENTS
			var v10 := v00 + SEGMENTS
			var v11 := v01 + SEGMENTS
			indices[w] = v00
			indices[w + 1] = v01 if up_first else v10
			indices[w + 2] = v10 if up_first else v01
			indices[w + 3] = v01
			indices[w + 4] = v11 if up_first else v10
			indices[w + 5] = v10 if up_first else v11
			w += 6
	if closed:
		for j in SEGMENTS:
			var fan := _fan(j, 1, ring_count, up_first)
			for v in fan:
				indices[w] = v
				w += 1
	# The collider: every other ring and segment, a quarter of the
	# triangles, close enough underfoot and four times quicker to build.
	for i in range(0, RINGS, 2):
		for j in range(0, SEGMENTS, 2):
			for v in _quad(i, j, 2, up_first):
				faces.append(verts[v])
	if closed:
		for j in range(0, SEGMENTS, 2):
			for v in _fan(j, 2, ring_count, up_first):
				faces.append(verts[v])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_view.mesh = mesh
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	_shape.shape = shape


## Godot draws a triangle's front where its corners run clockwise, seen
## from that side: which way round a quad's corners face up.
func _up_first() -> bool:
	var p00 := Vector3(0, 0, -flat_r)
	var p01 := Vector3(flat_r * sin(TAU / SEGMENTS), 0, -flat_r * cos(TAU / SEGMENTS))
	var p10 := p00 * 2.0
	return (p01 - p00).cross(p10 - p00).y < 0.0


## The six indices of the quad from ring i, segment j, spanning `step`.
func _quad(i: int, j: int, step: int, up_first: bool) -> Array[int]:
	var i1 := mini(i + step, RINGS)
	var j1 := (j + step) % SEGMENTS
	var v00 := i * SEGMENTS + j
	var v01 := i * SEGMENTS + j1
	var v10 := i1 * SEGMENTS + j
	var v11 := i1 * SEGMENTS + j1
	if up_first:
		return [v00, v01, v10, v01, v11, v10]
	return [v00, v10, v01, v01, v10, v11]


## The three indices of the triangle from the centre to the first ring's
## segment j, spanning `step`, facing up.
func _fan(j: int, step: int, centre: int, up_first: bool) -> Array[int]:
	var a := j
	var b := (j + step) % SEGMENTS
	# The centre lies inward of the ring, where a quad's next ring lies
	# outward, so the turn runs the other way.
	if up_first:
		return [a, centre, b]
	return [a, b, centre]
