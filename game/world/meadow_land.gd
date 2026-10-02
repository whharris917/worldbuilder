class_name MeadowLand
extends Landscape
## A meadow in a summer wood: an oval of tall grass in the floor of a
## shallow valley, a brook winding down the valley through it from
## north to south, and a mixed wood of maple, oak, birch, white pine
## and spruce closing round it and climbing the valley's sides. No sea.
##
## The brook is a centreline with a meander, a width that swells into
## pools, a depth and a water level falling gently to the south, all
## functions of z; the ground is a valley rising from the brook, cut
## with its channel. The meadow is an ellipse with a ragged edge. Its
## ground shader (meadow_ground.gdshader) is told the brook's bed, the
## forest floor and the meadow as vertex colours red, green and blue;
## the grass itself is a GrassField over the same ground.

const MEADOW := Vector2(0.0, 0.0)
const MEADOW_RX := 52.0
const MEADOW_RZ := 80.0
const BROOK_GRADE := 0.008       # the water falls this much a metre southward
const BROOK_REACH := 300.0       # the water drawn and heard this far north and south
## The lone tree standing out in the meadow, west of the brook.
const LONE_TREE := Vector3(-24.0, 0.0, -18.0)
const EDGE_R := 1.18             # meadow_r out to which a tree is always drawn with leaves
const CELL := 40.0               # the wood's cells, for drawing near and far
const CELL_NEAR := 60.0          # a cell is drawn with leaves within this of the camera

var _n: FastNoiseLite
var _edge: FastNoiseLite
var brook_mat: ShaderMaterial
## Drawn as a cartoon (set before build): its ground, wood, stones and
## water in the cartoon shaders, the trees rounded crowns and cones with
## ink outlines.
var cartoon := false
## The cartoon materials, whose wind the world keeps current.
var toon_mats: Array[ShaderMaterial] = []
var _stone_count := 0


func _init() -> void:
	centre = Vector3.ZERO
	sea_level = -200.0
	tide_range = 0.0
	seed = 20261001
	cell = 0.75
	grid_n = 480
	mesh_reach = 800.0
	ground_shader = "res://world/meadow_ground.gdshader"
	detailed_trees = true
	_n = FastNoiseLite.new()
	_n.seed = seed
	_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n.frequency = 1.0
	_edge = FastNoiseLite.new()
	_edge.seed = seed + 5
	_edge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_edge.frequency = 1.0


## ---- the brook --------------------------------------------------------------

## The brook's centreline: x where it runs at z.
func brook_x(z: float) -> float:
	return 12.0 * sin(z * 0.021 + 0.4) + 5.0 * sin(z * 0.053 + 2.0) + 2.0 * sin(z * 0.13 + 1.0)


func brook_slope(z: float) -> float:
	return 12.0 * 0.021 * cos(z * 0.021 + 0.4) + 5.0 * 0.053 * cos(z * 0.053 + 2.0) + 2.0 * 0.13 * cos(z * 0.13 + 1.0)


## Half the brook's width: a metre and a bit over the riffles, wider in
## the pools.
func brook_half(z: float) -> float:
	return 1.3 + 0.45 * sin(z * 0.047 + 1.3) + 0.25 * sin(z * 0.11)


## How deep the brook runs at its middle: deeper where it pools.
func brook_depth(z: float) -> float:
	return 0.35 + 0.3 * maxf(0.0, sin(z * 0.047 + 1.3))


func water_y(z: float) -> float:
	return -BROOK_GRADE * z


## The distance from (x, z) to the brook's centreline, across it.
func brook_distance(x: float, z: float) -> float:
	return absf(x - brook_x(z)) / sqrt(1.0 + pow(brook_slope(z), 2.0))


## ---- the meadow -------------------------------------------------------------

## 1 on the meadow's edge, less inside it, more out in the wood; the
## edge wanders.
func meadow_r(x: float, z: float) -> float:
	var d := Vector2((x - MEADOW.x) / MEADOW_RX, (z - MEADOW.y) / MEADOW_RZ).length()
	return d + 0.12 * _edge.get_noise_2d(x * 0.035, z * 0.035) + 0.05 * _edge.get_noise_2d(x * 0.11 + 30.0, z * 0.11)


## How tall the grass stands at (x, z), 0 none to 1 the meadow's
## height: the meadow, thinning into the wood's edge, none in the water.
func grass_at(x: float, z: float) -> float:
	var g := 1.0 - smoothstep(0.92, 1.06, meadow_r(x, z))
	var s := brook_distance(x, z)
	var half := brook_half(z)
	g *= smoothstep(half - 0.1, half + 0.5, s)
	# Under the lone tree's crown the grass is shaded thin.
	var lone := Vector2(x - LONE_TREE.x, z - LONE_TREE.z).length()
	g *= 0.35 + 0.65 * smoothstep(2.0, 7.0, lone)
	return g


## ---- what the landscape asks ------------------------------------------------

func height_at(x: float, z: float) -> float:
	var s := brook_distance(x, z)
	var w := water_y(z)
	var half := brook_half(z)
	# The valley: its floor half a metre over the water, its sides rising
	# gently through the meadow, then more steeply into wooded hills.
	var h := w + 0.5 + 0.035 * s + 0.00055 * pow(minf(s, 220.0), 2.0) + 0.12 * maxf(s - 220.0, 0.0)
	var wood := smoothstep(0.8, 1.4, meadow_r(x, z))
	var rolls := lerpf(0.45, 2.4, wood) * _n.get_noise_2d(x * 0.03, z * 0.03) \
		+ lerpf(0.18, 0.6, wood) * _n.get_noise_2d(x * 0.11 + 5.0, z * 0.11)
	h += rolls * smoothstep(half + 1.0, half + 9.0, s)
	# The channel: the bed dished under the water, the banks falling to it.
	var ch := 1.0 - smoothstep(half - 0.3, half + 0.9, s)
	if ch > 0.0:
		var across := clampf(s / half, 0.0, 1.0)
		var bed := w - brook_depth(z) * (1.0 - across * across)
		h = lerpf(h, minf(h, bed), ch)
	return h


func coast_distance(_x: float, _z: float) -> float:
	return 1000.0


## Trees stand in the wood, not in the meadow or the brook; at the
## meadow's edge they thin out raggedly.
func tree_ground(x: float, z: float) -> float:
	if brook_distance(x, z) < brook_half(z) + 1.5:
		return -INF
	var m := meadow_r(x, z)
	if m < 1.0:
		return -INF
	if m < 1.14 and _hash(x, z) > (m - 1.0) / 0.14:
		return -INF
	return height_at(x, z)


func rock_blocked(x: float, z: float) -> bool:
	return brook_distance(x, z) < brook_half(z) + 3.0


## The ground shader's vertex colour: the brook's bed in red, the
## forest floor in green, the meadow in blue.
func ground_tint(x: float, z: float) -> Color:
	var s := brook_distance(x, z)
	var bed := 1.0 - smoothstep(brook_half(z) - 0.2, brook_half(z) + 0.4, s)
	var meadow := grass_at(x, z)
	var wood := smoothstep(0.98, 1.12, meadow_r(x, z))
	return Color(bed, wood, meadow, 1.0)


static func _hash(x: float, z: float) -> float:
	return fposmod(sin(x * 12.9898 + z * 78.233) * 43758.5453, 1.0)


## ---- building -----------------------------------------------------------------

## No sea.
func _build_sea() -> void:
	pass


## The wood, mixed as a New England wood is, in summer leaf. Trees with
## leaves (TreeKit) stand along the meadow's edge, where they are seen
## close from anywhere in the meadow; deeper in, the wood is laid in
## square cells, each drawn with leaves within CELL_NEAR of the camera
## and as plain cone-and-ball trees beyond it. Past DETAIL_R a plain
## wood, then silhouettes on the hills. A fringe of shrubs and saplings
## where the meadow meets the trees, and one big oak alone in the meadow.
func _build_forest() -> void:
	if cartoon:
		_build_cartoon_forest()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 77
	var edge := Forest.new()
	edge.name = "Wood"
	var cells: Dictionary = {}        # cell index -> [[at, h, kind, leaf], ...]
	var planted := 0
	var spacing := 4.6
	var count := int(4.0 * DETAIL_R * DETAIL_R / (spacing * spacing))
	# kind, share, leaf colour, height
	var mix: Array = [
		["maple", 0.40, Color(0.27, 0.38, 0.13), 17.0],
		["oak", 0.12, Color(0.24, 0.33, 0.12), 18.0],
		["birch", 0.16, Color(0.34, 0.44, 0.15), 14.0],
		["spruce", 0.32, Color(0.07, 0.15, 0.07), 16.0],
	]
	for _i in count:
		var x := rng.randf_range(-DETAIL_R, DETAIL_R)
		var z := rng.randf_range(-DETAIL_R, DETAIL_R)
		var pick := rng.randf()
		var hpick := rng.randf_range(0.7, 1.3)
		var tone := rng.randf_range(-0.04, 0.05)
		if Vector2(x, z).length() > DETAIL_R:
			continue
		var y := tree_ground(x, z)
		if y == -INF:
			continue
		var acc := 0.0
		for kind: Array in mix:
			acc += float(kind[1])
			if pick <= acc or kind == mix.back():
				var tree := [Vector3(x, y, z), float(kind[3]) * hpick, str(kind[0]), (kind[2] as Color).lightened(tone)]
				if meadow_r(x, z) < EDGE_R:
					edge.plant_species(tree[0], tree[1], tree[2], tree[3], rng)
				else:
					var key := Vector2i(floori(x / CELL), floori(z / CELL))
					if not cells.has(key):
						cells[key] = []
					(cells[key] as Array).append(tree)
				break
		planted += 1
	# The fringe: shrubs and saplings where the meadow gives way.
	var fringe := 0
	for _i in 450:
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(0.97, 1.1)
		var x := MEADOW.x + cos(a) * MEADOW_RX * r
		var z := MEADOW.y + sin(a) * MEADOW_RZ * r
		var m := meadow_r(x, z)
		if m < 0.97 or m > 1.12 or brook_distance(x, z) < brook_half(z) + 2.0:
			continue
		var y := height_at(x, z)
		if rng.randf() < 0.75:
			edge.plant_species(Vector3(x, y, z), rng.randf_range(1.2, 2.6), "shrub",
				Color(0.24, 0.34, 0.12).lightened(rng.randf_range(-0.05, 0.05)), rng)
		else:
			var kind := "birch" if rng.randf() < 0.5 else "maple"
			edge.plant_species(Vector3(x, y, z), rng.randf_range(4.0, 8.0), kind,
				Color(0.32, 0.43, 0.15).lightened(rng.randf_range(-0.04, 0.04)), rng)
		fringe += 1
	var lone := Vector3(LONE_TREE.x, height_at(LONE_TREE.x, LONE_TREE.z), LONE_TREE.z)
	edge.plant_species(lone, 19.0, "oak", Color(0.25, 0.35, 0.12), rng, 0.6)
	edge.finish(true, false, true)
	add_child(edge)
	# The cells: leaves near, plain beyond, the two meeting at CELL_NEAR
	# from the cell's middle.
	for key: Vector2i in cells:
		var leafy := Forest.new()
		leafy.name = "WoodNear"
		var plain := Forest.new()
		plain.name = "WoodFar"
		for tree: Array in cells[key]:
			leafy.plant_species(tree[0], tree[1], tree[2], tree[3], rng)
			if tree[2] == "spruce":
				plain.plant_conifer(tree[0], tree[1], rng)
			else:
				# The plain material shows a tint as it is; the leaf
				# pictures darken theirs, so the plain tree takes the
				# wood's own darker green.
				plain.plant_broadleaf(tree[0], tree[1], Forest.BROADLEAF_COLOR.lightened(rng.randf_range(-0.02, 0.05)), rng)
		leafy.finish(true, false, true)
		plain.finish(true, true)
		add_child(leafy)
		add_child(plain)
		for node in leafy.get_children():
			(node as GeometryInstance3D).visibility_range_end = CELL_NEAR
		for node in plain.get_children():
			(node as GeometryInstance3D).visibility_range_begin = CELL_NEAR
	stats["wood_cells"] = cells.size()
	# The plain wood from DETAIL_R to 300 m, then silhouettes to the edge.
	var r_near := 300.0
	var ring_sampler := func(x: float, z: float) -> float:
		var d := Vector2(x, z).length()
		if d <= DETAIL_R or d > r_near:
			return -INF
		return tree_ground(x, z)
	var ring := Forest.new()
	ring.name = "Ring"
	planted += ring.plant_scatter(Vector2(-r_near, -r_near), Vector2(r_near, r_near), 6.5, 18.0, 0.7, rng, ring_sampler)
	ring.finish(false, true)
	add_child(ring)
	var r_far := 760.0
	var far_sampler := func(x: float, z: float) -> float:
		if Vector2(x, z).length() <= r_near:
			return -INF
		return tree_ground(x, z)
	var far := Forest.new()
	far.name = "FarWood"
	planted += far.plant_scatter(Vector2(-r_far, -r_far), Vector2(r_far, r_far), 17.0, 22.0, 0.7, rng, far_sampler)
	far.finish(false, true)
	add_child(far)
	stats["trees"] = planted + fringe + 1


## The wood as a cartoon: the same mix of broadleaves and conifers, but
## as rounded crowns on trunks and stacked cones, in bright greens,
## flat-lit and outlined in ink; a few saplings at the meadow's edge
## and the lone oak. The plain wood and silhouettes beyond as before,
## brightened to match.
func _build_cartoon_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 77
	var leaves: Array[Color] = [Color(0.30, 0.58, 0.16), Color(0.40, 0.66, 0.18), Color(0.24, 0.50, 0.20), Color(0.50, 0.70, 0.20)]
	var needles: Array[Color] = [Color(0.10, 0.40, 0.26), Color(0.14, 0.46, 0.24)]
	var wood := Forest.new()
	wood.name = "Wood"
	var ring := Forest.new()
	ring.name = "Ring"
	var planted := 0
	var r_near := 300.0
	# Fewer trees than the realistic wood: a cartoon wood reads by its
	# crowns, and each is drawn twice, once as its outline.
	var spacing := 6.0
	var count := int(4.0 * r_near * r_near / (spacing * spacing))
	for _i in count:
		var x := rng.randf_range(-r_near, r_near)
		var z := rng.randf_range(-r_near, r_near)
		var d := Vector2(x, z).length()
		var pick := rng.randf()
		var hpick := rng.randf_range(0.7, 1.3)
		if d > r_near or (d > DETAIL_R and rng.randf() < 0.6):
			continue
		var y := tree_ground(x, z)
		if y == -INF:
			continue
		var into := wood if d <= DETAIL_R else ring
		if pick < 0.35:
			into.plant_conifer(Vector3(x, y, z), 16.0 * hpick, rng, needles[rng.randi() % needles.size()])
		else:
			into.plant_broadleaf(Vector3(x, y, z), 15.0 * hpick, leaves[rng.randi() % leaves.size()], rng)
		planted += 1
	for _i in 160:
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(0.98, 1.08)
		var x := MEADOW.x + cos(a) * MEADOW_RX * r
		var z := MEADOW.y + sin(a) * MEADOW_RZ * r
		if meadow_r(x, z) < 0.97 or brook_distance(x, z) < brook_half(z) + 2.0:
			continue
		wood.plant_broadleaf(Vector3(x, height_at(x, z), z), rng.randf_range(3.0, 6.0), leaves[rng.randi() % leaves.size()], rng)
		planted += 1
	var lone := Vector3(LONE_TREE.x, height_at(LONE_TREE.x, LONE_TREE.z), LONE_TREE.z)
	wood.plant_broadleaf(lone, 17.0, Color(0.36, 0.62, 0.18), rng)
	wood.finish(true, true)
	add_child(wood)
	ring.finish(false, true)
	add_child(ring)
	_toonify(wood, true, Vector3.ONE)
	_toonify(ring, false, Vector3.ONE)
	var r_far := 760.0
	var far_sampler := func(x: float, z: float) -> float:
		if Vector2(x, z).length() <= r_near:
			return -INF
		return tree_ground(x, z)
	var far := Forest.new()
	far.name = "FarWood"
	planted += far.plant_scatter(Vector2(-r_far, -r_far), Vector2(r_far, r_far), 17.0, 22.0, 0.6, rng, far_sampler)
	far.finish(false, true)
	add_child(far)
	# The wood's own dark greens, lifted to the cartoon's.
	_toonify(far, false, Vector3(4.0, 3.2, 3.6))
	stats["trees"] = planted + 1


## Give a plain Forest's parts cartoon materials: crowns and cones sway,
## trunks stand; with an outline, each part drawn again as its ink hull.
func _toonify(forest: Forest, outline: bool, tint: Vector3) -> void:
	var made: Dictionary = {}
	for node in forest.get_children():
		var mmi := node as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null:
			continue
		var mesh := mmi.multimesh.mesh
		var sway := 0.0
		if mesh is SphereMesh:
			sway = 0.5
		elif mesh is CylinderMesh and (mesh as CylinderMesh).top_radius == 0.0:
			sway = 0.35
		if not made.has(sway):
			made[sway] = _toon_material(ShaderMaterial.new(), sway, outline, tint, true)
		mmi.material_override = made[sway]


## Make mat a cartoon surface (toon_solid.gdshader) of the given sway
## and tint, with its outline as the next pass if wanted.
func _toon_material(mat: ShaderMaterial, sway: float, outline: bool, tint: Vector3, srgb: bool) -> ShaderMaterial:
	mat.shader = load("res://world/toon_solid.gdshader")
	mat.set_shader_parameter("sway", sway)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("srgb_colors", srgb)
	toon_mats.append(mat)
	if outline:
		var hull := ShaderMaterial.new()
		hull.shader = load("res://world/outline_hull.gdshader")
		hull.set_shader_parameter("sway", sway)
		mat.next_pass = hull
		toon_mats.append(hull)
	return mat


## The brook: a water ribbon down its line, wider than the water so its
## edges bury in the banks, and stones in its bed, the bigger ones
## breaking the surface.
func _build_landmarks() -> void:
	if cartoon:
		_toon_material(rock_mat, 0.0, true, Vector3(0.62, 0.60, 0.56), false)
	var samples: Array[Dictionary] = []
	var z := -BROOK_REACH
	while z <= BROOK_REACH + 0.01:
		var tangent := Vector2(brook_slope(z), 1.0).normalized()
		var across := Vector2(tangent.y, -tangent.x)
		# Along runs upstream (north), as the river shader flows.
		samples.append({"c": Vector3(brook_x(z), water_y(z), z), "n": across, "w": brook_half(z) + 0.9, "s": -z})
		z += 1.5
	brook_mat = ShaderMaterial.new()
	brook_mat.shader = load("res://world/toon_water.gdshader" if cartoon else "res://world/river.gdshader")
	brook_mat.set_shader_parameter("flow", 0.7)
	brook_mat.set_shader_parameter("foam_depth", 0.06)
	brook_mat.set_shader_parameter("foam_amount", 0.15)
	brook_mat.set_shader_parameter("shallow_color", Color(0.20, 0.17, 0.09))
	brook_mat.set_shader_parameter("deep_color", Color(0.035, 0.035, 0.018))
	var ribbon := _water_ribbon(samples, brook_mat)
	ribbon.name = "Brook"
	_build_stones()
	stats["brook_m"] = int(2.0 * BROOK_REACH)


func _build_stones() -> void:
	var xforms: Array[Array] = [[], [], []]
	var colors: Array[Array] = [[], [], []]
	var z := -BROOK_REACH
	while z <= BROOK_REACH:
		for _k in 2:
			if _rng.randf() > 0.55:
				continue
			var half := brook_half(z)
			var off := _rng.randf_range(-half - 0.6, half + 0.6)
			var tangent := Vector2(brook_slope(z), 1.0).normalized()
			var across := Vector2(tangent.y, -tangent.x)
			var x := brook_x(z) + across.x * off
			var zz := z + across.y * off
			var size := _rng.randf_range(0.12, 0.38)
			if _rng.randf() < 0.12:
				size = _rng.randf_range(0.45, 0.8)
			var y := height_at(x, zz)
			var sy := size * _rng.randf_range(0.5, 0.8)
			var basis := Basis.from_euler(Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(0.0, TAU),
				_rng.randf_range(-0.3, 0.3))).scaled(Vector3(size, sy, size * _rng.randf_range(0.7, 1.3)))
			var v := _rng.randi() % 3
			xforms[v].append(Transform3D(basis, Vector3(x, y + sy * 0.15, zz)))
			# Wet granite in the shade of the banks: darker than the
			# boulders out in the sun.
			colors[v].append(Color.WHITE.darkened(_rng.randf_range(0.35, 0.55)))
			_stone_count += 1
		z += 1.0
	for v in 3:
		if xforms[v].is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _rock_meshes[v]
		mm.instance_count = xforms[v].size()
		for i in xforms[v].size():
			mm.set_instance_transform(i, xforms[v][i])
			mm.set_instance_color(i, colors[v][i])
		var inst := MultiMeshInstance3D.new()
		inst.name = "Stones"
		inst.multimesh = mm
		inst.material_override = rock_mat
		add_child(inst)
	stats["stones"] = _stone_count


## The sounds are the world's (MeadowSound).
func _build_sound() -> void:
	pass
