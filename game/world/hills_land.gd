class_name HillsLand
extends Landscape
## Open rolling hills of long grass: no trees, no stones, one pond.
## Long low swells with smaller rolls on them, the land rising gently
## toward the horizon all round so the edge of the world is always a
## far hillside. The ground is hills_ground.gdshader.
##
## The pond fills a hollow near the start as rain would: of the hollows
## the land closes round within LAKE_SEARCH of the centre, the nearest
## that holds a pond worth the name, filled to just under the lowest gap
## in its rim (find_lake). The meadow runs on under it: the hollow is a
## flooded field, its grass standing in the clear water.

## How far from the centre a hollow may lie, the grid it is searched on,
## and how much water makes a pond: its area and its depth.
const LAKE_SEARCH := 180.0
const LAKE_STEP := 2.0
const LAKE_MIN_AREA := 1200.0
const LAKE_MIN_DEPTH := 1.5
## How far under its rim's lowest gap the water stands.
const LAKE_FREEBOARD := 0.3

var _n: FastNoiseLite
## The pond: its level, its cells (LAKE_STEP squares, keyed by index)
## and its deepest point; empty when the land holds none.
var lake_level := -INF
var lake_cells: Dictionary = {}
var lake_centre := Vector2.ZERO
var lake_depth := 0.0
var lake_mat: ShaderMaterial          # lake.gdshader; the world keeps its wind current


func _init() -> void:
	centre = Vector3.ZERO
	sea_level = -500.0
	tide_range = 0.0
	seed = 20261010
	cell = 1.0
	grid_n = 600
	mesh_reach = 1800.0
	ground_shader = "res://world/hills_ground.gdshader"
	_n = FastNoiseLite.new()
	_n.seed = seed
	_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n.frequency = 1.0


func height_at(x: float, z: float) -> float:
	var h := 16.0 * _n.get_noise_2d(x * 0.0035, z * 0.0035) \
		+ 6.0 * _n.get_noise_2d(x * 0.011 + 40.0, z * 0.011) \
		+ 1.2 * _n.get_noise_2d(x * 0.035 + 90.0, z * 0.035)
	var r := Vector2(x, z).length()
	return h + 0.00003 * pow(maxf(r - 250.0, 0.0), 2.0)


## Grass everywhere, under the pond too.
func grass_at(_x: float, _z: float) -> float:
	return 1.0


## Find the pond. On a grid round the centre, fill every hollow as rain
## would (_fill_all: the height water stands at over each cell before
## it runs off the grid's edge). Then take each low point (the lowest
## in the 5 by 5 cells round it), nearest the centre first: its water
## stands at its filled height less LAKE_FREEBOARD, over the cells
## joined to it that lie under that. The first whose water covers
## LAKE_MIN_AREA to LAKE_MIN_DEPTH is the pond.
func find_lake() -> void:
	var n := int(2.0 * LAKE_SEARCH / LAKE_STEP)
	var lo := -n / 2
	var h := PackedFloat32Array()
	h.resize(n * n)
	for j in n:
		for i in n:
			h[j * n + i] = height_at((lo + i + 0.5) * LAKE_STEP, (lo + j + 0.5) * LAKE_STEP)
	var minima: Array[Vector2i] = []
	for j in range(2, n - 2):
		for i in range(2, n - 2):
			var v := h[j * n + i]
			var lowest := true
			for dj in range(-2, 3):
				for di in range(-2, 3):
					if (di != 0 or dj != 0) and h[(j + dj) * n + i + di] <= v:
						lowest = false
			if lowest:
				minima.append(Vector2i(i, j))
	var filled := _fill_all(h, n)
	var half := n / 2
	minima.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - Vector2i(half, half)).length_squared() < (b - Vector2i(half, half)).length_squared())
	for m in minima:
		var level := filled[m.y * n + m.x] - LAKE_FREEBOARD
		if level <= h[m.y * n + m.x]:
			continue
		# The water: the cells under the level joined to the low point.
		var wet: Dictionary = {}
		var deepest := 0.0
		var todo: Array[Vector2i] = [m]
		var seen := {m: true}
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			var d := level - h[c.y * n + c.x]
			if d <= 0.0:
				continue
			wet[Vector2i(lo + c.x, lo + c.y)] = true
			deepest = maxf(deepest, d)
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb: Vector2i = c + o
				if nb.x >= 0 and nb.y >= 0 and nb.x < n and nb.y < n and not seen.has(nb):
					seen[nb] = true
					todo.append(nb)
		if wet.size() * LAKE_STEP * LAKE_STEP < LAKE_MIN_AREA or deepest < LAKE_MIN_DEPTH:
			continue
		lake_level = level
		lake_cells = wet
		lake_centre = Vector2((lo + m.x + 0.5) * LAKE_STEP, (lo + m.y + 0.5) * LAKE_STEP)
		lake_depth = deepest
		stats["lake_m2"] = wet.size() * LAKE_STEP * LAKE_STEP
		return


## The height water stands at over each cell of the grid, filled from
## its edges inward (priority flood): the edge cells drain off the
## grid; from them, always the lowest cell yet reached is taken next,
## and each of its neighbours holds water to the higher of its own
## ground and the water at the cell it was reached from.
func _fill_all(h: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var filled := PackedFloat32Array()
	filled.resize(n * n)
	var seen := PackedByteArray()
	seen.resize(n * n)
	# A binary heap of [water height, index].
	var heap: Array = []
	var push := func(v: float, k: int) -> void:
		heap.append([v, k])
		var c := heap.size() - 1
		while c > 0:
			var p := (c - 1) / 2
			if heap[p][0] <= heap[c][0]:
				break
			var t: Array = heap[p]
			heap[p] = heap[c]
			heap[c] = t
			c = p
	var pop := func() -> Array:
		var top: Array = heap[0]
		var last: Array = heap.pop_back()
		if not heap.is_empty():
			heap[0] = last
			var c := 0
			while true:
				var l := 2 * c + 1
				var r := l + 1
				var sm := c
				if l < heap.size() and heap[l][0] < heap[sm][0]:
					sm = l
				if r < heap.size() and heap[r][0] < heap[sm][0]:
					sm = r
				if sm == c:
					break
				var t: Array = heap[sm]
				heap[sm] = heap[c]
				heap[c] = t
				c = sm
		return top
	for i in n:
		for k: int in [i, (n - 1) * n + i, i * n, i * n + n - 1]:
			if seen[k] == 0:
				seen[k] = 1
				filled[k] = h[k]
				push.call(h[k], k)
	while not heap.is_empty():
		var top: Array = pop.call()
		var v: float = top[0]
		var k: int = top[1]
		var x := k % n
		var y := k / n
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := x + d.x
			var ny := y + d.y
			if nx < 0 or ny < 0 or nx >= n or ny >= n:
				continue
			var nk := ny * n + nx
			if seen[nk] == 0:
				seen[nk] = 1
				filled[nk] = maxf(h[nk], v)
				push.call(filled[nk], nk)
	return filled


func coast_distance(_x: float, _z: float) -> float:
	return 1000.0


func _build_sea() -> void:
	pass


## The pond is found before the terrain is drawn, so the world can ask
## for it as it builds.
func build() -> void:
	find_lake()
	super()


func _build_rocks() -> void:
	pass


## The pond's surface: one flat square at the water level over each of
## its cells and the cells round them, so its edge runs under the bank.
func _build_landmarks() -> void:
	if lake_cells.is_empty():
		return
	var cover: Dictionary = {}
	for c: Vector2i in lake_cells:
		for dj in range(-1, 2):
			for di in range(-1, 2):
				cover[c + Vector2i(di, dj)] = true
	var verts := PackedVector3Array()
	var index := PackedInt32Array()
	for c: Vector2i in cover:
		var x0 := c.x * LAKE_STEP
		var z0 := c.y * LAKE_STEP
		var k := verts.size()
		verts.append_array([Vector3(x0, lake_level, z0), Vector3(x0 + LAKE_STEP, lake_level, z0),
			Vector3(x0, lake_level, z0 + LAKE_STEP), Vector3(x0 + LAKE_STEP, lake_level, z0 + LAKE_STEP)])
		index.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	lake_mat = ShaderMaterial.new()
	lake_mat.shader = load("res://world/lake.gdshader")
	var water := MeshInstance3D.new()
	water.name = "Pond"
	water.mesh = mesh
	water.material_override = lake_mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _build_forest() -> void:
	stats["trees"] = 0


## The sounds are the world's (GrassHills).
func _build_sound() -> void:
	pass
