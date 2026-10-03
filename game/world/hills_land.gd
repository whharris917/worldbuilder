class_name HillsLand
extends Landscape
## Open rolling hills of long grass: no trees, no stones, one pond, one
## farmhouse, and a country road with the farm's driveway.
## Long ridges and broad valleys on the scale of open downland (swells
## 45 m high across nearly a kilometre), rolls on them, and the small
## undulations of a field underfoot; the land rising gently toward the
## horizon all round, 3.5 km out, so the edge of the world is always a
## far hillside. The ground is hills_ground.gdshader.
##
## The pond fills a hollow near the start as rain would: of the hollows
## the land closes round within LAKE_SEARCH of the centre, the nearest
## that holds a pond worth the name, filled to just under the lowest gap
## in its rim (find_lake). The meadow runs on under it: the hollow is a
## flooded field, its grass standing in the clear water.
##
## The farmhouse (data/buildings/farmhouse.json) stands on the pond's
## shore where the ground is flattest, a few metres above the water,
## facing it (find_site). Its yard is graded level, as a house site is,
## blending back into the hill over YARD_BLEND; no grass grows under the
## house.
##
## The road (find_road) is a gravel country road that passes behind the
## farm ROAD_BACK metres from the house and runs out to the edge of the
## land both ways. It is laid out as a road builder would: from the
## point behind the farm it goes on a step at a time, each step taking,
## of a few headings either side of the last, the one that climbs least,
## turns least and keeps clear of the lake, without doubling back
## toward where it began. Its bed is the ground along it smoothed and held
## to MAX_GRADE, and the land is cut and banked to it (height_at): level
## across the road and its shoulders, blending back into the hill. The
## driveway, a two-track lane, runs from the back of the yard to the
## road the same way. Both are ribbons (road.gdshader) laid on their
## beds; no grass grows on them.

## How far from the centre a hollow may lie, the grid it is searched on,
## and how much water makes a pond: its area and its depth.
const LAKE_SEARCH := 300.0
const LAKE_STEP := 3.0
const LAKE_MIN_AREA := 8000.0
const LAKE_MIN_DEPTH := 3.0
## How far under its rim's lowest gap the water stands.
const LAKE_FREEBOARD := 0.3
## The house in its own frame (metres, +x its front): what it covers,
## with its eaves and porch, as min x, min z, max x, max z.
const HOUSE_RECT := Rect2(-3.4, -9.5, 8.9, 14.1)
## The level yard round it, and the slope back to the hill beyond.
const YARD_MARGIN := 2.5
const YARD_BLEND := 7.0
## The road: half its width, its level shoulders, the least width of
## the cut or bank back to the hill (wider as the cut is deeper, at
## BANK_SLOPE metres across a metre down), its steepest grade, how far
## behind the house it passes, where it ends, and the driveway's half
## width.
const ROAD_HALF := 2.6
const ROAD_SHOULDER := 1.2
const ROAD_BANK := 6.0
const BANK_SLOPE := 3.0
const MAX_GRADE := 0.08
const ROAD_BACK := 90.0
const ROAD_END := 3350.0
const DRIVE_HALF := 1.5
## The road's lookup cells, metres: each holds every segment whose cut
## or bank reaches into it, and the grading worked out once on a grid of
## GRADE_STEP within it.
const ROAD_CELL := 40.0
const GRADE_STEP := 4.0
const GRADE_N := 11                  # ROAD_CELL / GRADE_STEP + 1 samples a side

var _n: FastNoiseLite
## The pond: its level, its cells (LAKE_STEP squares, keyed by index)
## and its deepest point; empty when the land holds none.
var lake_level := -INF
var lake_cells: Dictionary = {}
var lake_centre := Vector2.ZERO
var lake_depth := 0.0
var lake_mat: ShaderMaterial          # lake.gdshader; the world keeps its wind current
## The farmhouse: where it stands, its turn (radians about y, its front
## toward the pond) and its yard's level; site is INF until found.
var site := Vector2(INF, INF)
var site_yaw := 0.0
var site_y := 0.0
## The road and the driveway: centrelines a few metres apart and the
## bed's height at each point.
var road_pts := PackedVector2Array()
var road_y := PackedFloat32Array()
var drive_pts := PackedVector2Array()
var drive_y := PackedFloat32Array()
var road_mat: ShaderMaterial
var drive_mat: ShaderMaterial
var _road_cells: Dictionary = {}      # Vector2i -> Array of [is_drive, segment index]
## What the land is graded to: the centrelines every few points, the bed
## there, and how wide the bank is at each.
var _bed_pts := [PackedVector2Array(), PackedVector2Array()]
var _bed_y := [PackedFloat32Array(), PackedFloat32Array()]
var _bed_bank := [PackedFloat32Array(), PackedFloat32Array()]
## Per road cell: the grading on its grid, as pairs (how much the ground
## takes the bed, 0 to 1; that times the bed's height), so it blends
## evenly between samples.
var _grade: Dictionary = {}


func _init() -> void:
	centre = Vector3.ZERO
	sea_level = -500.0
	tide_range = 0.0
	seed = 20261010
	cell = 1.0
	grid_n = 700
	mesh_reach = 3500.0
	ground_shader = "res://world/hills_ground.gdshader"
	_n = FastNoiseLite.new()
	_n.seed = seed
	_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n.frequency = 1.0


func height_at(x: float, z: float) -> float:
	var h := _natural(x, z)
	if site.x != INF:
		var d := _yard_distance(x, z)
		h = lerpf(site_y, h, smoothstep(YARD_MARGIN, YARD_MARGIN + YARD_BLEND, d))
	if not _grade.is_empty():
		var g := _graded(x, z)
		h = h * (1.0 - g.x) + g.y
	return h


## The road's grading at (x, z) from its cell's grid: x how much the
## ground takes the bed, y that times the bed's height.
func _graded(x: float, z: float) -> Vector2:
	var cx := floori(x / ROAD_CELL)
	var cz := floori(z / ROAD_CELL)
	var grid: Variant = _grade.get(Vector2i(cx, cz))
	if grid == null:
		return Vector2.ZERO
	var g: PackedFloat32Array = grid
	var fx := (x - cx * ROAD_CELL) / GRADE_STEP
	var fz := (z - cz * ROAD_CELL) / GRADE_STEP
	var i := mini(int(fx), GRADE_N - 2)
	var j := mini(int(fz), GRADE_N - 2)
	var u := fx - i
	var v := fz - j
	var k := (j * GRADE_N + i) * 2
	var k2 := k + GRADE_N * 2
	var w := lerpf(lerpf(g[k], g[k + 2], u), lerpf(g[k2], g[k2 + 2], u), v)
	var wy := lerpf(lerpf(g[k + 1], g[k + 3], u), lerpf(g[k2 + 1], g[k2 + 3], u), v)
	return Vector2(w, wy)


## The nearest road or driveway to (x, z) within its bank's reach:
## the distance to its centreline, its bed's height there, its half
## width, its bank's width; x is INF where none reaches.
func road_at(x: float, z: float) -> Vector4:
	var cell := Vector2i(floori(x / ROAD_CELL), floori(z / ROAD_CELL))
	var segs: Array = _road_cells.get(cell, [])
	var best := Vector4(INF, 0.0, 0.0, 0.0)
	if segs.is_empty():
		return best
	var p := Vector2(x, z)
	for seg: Array in segs:
		var k: int = seg[0]
		var i: int = seg[1]
		var pts: PackedVector2Array = _bed_pts[k]
		var a := pts[i]
		var ab := pts[i + 1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		var half := DRIVE_HALF if k == 1 else ROAD_HALF
		# Where a lane meets the road the road's bed wins.
		if best.x == INF or d - half < best.x - best.z:
			var ys: PackedFloat32Array = _bed_y[k]
			var banks: PackedFloat32Array = _bed_bank[k]
			best = Vector4(d, lerpf(ys[i], ys[i + 1], t), half, lerpf(banks[i], banks[i + 1], t))
	return best


## (x, z) in the house's own frame.
func _local(x: float, z: float) -> Vector2:
	var q := Vector2(x, z) - site
	var c := cos(site_yaw)
	var s := sin(site_yaw)
	# The inverse of the house's turn: its +x is (cos, -sin) in the world.
	return Vector2(q.x * c - q.y * s, q.x * s + q.y * c)


## How far (x, z) lies outside the house's cover, 0 within it.
func _yard_distance(x: float, z: float) -> float:
	var p := _local(x, z)
	var dx := maxf(maxf(HOUSE_RECT.position.x - p.x, p.x - HOUSE_RECT.end.x), 0.0)
	var dz := maxf(maxf(HOUSE_RECT.position.y - p.y, p.y - HOUSE_RECT.end.y), 0.0)
	return Vector2(dx, dz).length()


func _natural(x: float, z: float) -> float:
	var h := 45.0 * _n.get_noise_2d(x * 0.0012, z * 0.0012) \
		+ 16.0 * _n.get_noise_2d(x * 0.0037 + 40.0, z * 0.0037) \
		+ 4.0 * _n.get_noise_2d(x * 0.012 + 90.0, z * 0.012) \
		+ 1.0 * _n.get_noise_2d(x * 0.04 + 130.0, z * 0.04)
	var r := Vector2(x, z).length()
	return h + 0.00002 * pow(maxf(r - 900.0, 0.0), 2.0)


## Grass everywhere, under the pond too, but not under the house or on
## the road and the driveway.
func grass_at(x: float, z: float) -> float:
	var g := 1.0
	if site.x != INF:
		g = smoothstep(0.0, 0.4, _yard_distance(x, z))
	if not _grade.is_empty() and _graded(x, z).x > 0.5:
		var r := road_at(x, z)
		if r.x != INF:
			if r.z == DRIVE_HALF:
				# The lane: bare only in its two ruts.
				g = minf(g, smoothstep(0.2, 0.36, absf(r.x - 0.75)))
			else:
				g = minf(g, smoothstep(r.z + 0.1, r.z + 0.7, r.x))
	return g


## Lay out the road and the driveway (see the class's note).
func find_road() -> void:
	if site.x == INF:
		return
	var back := (site - lake_centre).normalized()
	var start := site + back * ROAD_BACK
	var across := Vector2(-back.y, back.x)
	var one := _march(start, across)
	var other := _march(start, -across)
	other.reverse()
	var line := PackedVector2Array(other)
	line.append(start)
	line.append_array(one)
	road_pts = _resample(_smooth(_smooth(line)), 4.0)
	road_y = _bed(road_pts, 5)
	# The driveway: from the back of the yard to the road, bending a
	# little, its bed from the yard's level to the road's.
	var house_back := site + back * (-HOUSE_RECT.position.x + YARD_MARGIN)
	var join := _nearest_on(road_pts, house_back)
	var bend := (house_back + join) * 0.5 + across * 8.0
	var lane := PackedVector2Array([house_back, house_back.lerp(bend, 0.5), bend, bend.lerp(join, 0.5), join])
	drive_pts = _resample(_smooth(_smooth(lane)), 3.0)
	drive_y = _bed(drive_pts, 4)
	drive_y[0] = site_y
	var join_y := road_at_line(join)
	for i in drive_pts.size():
		var t := float(i) / float(drive_pts.size() - 1)
		# Pinned to the yard at one end and the road at the other.
		drive_y[i] = lerpf(drive_y[i], lerpf(site_y, join_y, t), maxf(1.0 - 4.0 * t, 4.0 * t - 3.0) if t < 0.25 or t > 0.75 else 0.0)
	drive_y[0] = site_y
	drive_y[drive_y.size() - 1] = join_y
	_hold_grade(drive_y, 3.0, 0.12)
	drive_y[0] = site_y
	drive_y[drive_y.size() - 1] = join_y
	_index_roads()
	stats["road_km"] = road_pts.size() * 4.0 / 1000.0


## The road's bed height at the point of its centreline nearest p.
func road_at_line(p: Vector2) -> float:
	var best := INF
	var y := 0.0
	for i in road_pts.size():
		var d := road_pts[i].distance_squared_to(p)
		if d < best:
			best = d
			y = road_y[i]
	return y


func _nearest_on(pts: PackedVector2Array, p: Vector2) -> Vector2:
	var best := INF
	var q := p
	for v in pts:
		var d := v.distance_squared_to(p)
		if d < best:
			best = d
			q = v
	return q


## From p, step by step in heading dir until the edge of the land.
func _march(p: Vector2, dir: Vector2) -> PackedVector2Array:
	var from := p
	var out := PackedVector2Array()
	var step := 12.0
	var heading := dir.normalized()
	for _n in 600:
		var best := INF
		var best_h := heading
		for k in range(-4, 5):
			var h := heading.rotated(deg_to_rad(7.0 * k))
			# Winding, but never turned more than 70 degrees from the way
			# it set out.
			if h.dot(dir) < 0.34:
				continue
			var q := p + h * step
			var grade := absf(_natural(q.x, q.y) - _natural(p.x, p.y)) / step
			var cost := grade * 12.0 + absf(k) * 0.08 + maxf(grade - MAX_GRADE, 0.0) * 40.0
			# Clear of the lake and its shore.
			if _natural(q.x, q.y) < lake_level + 3.0 and q.distance_to(lake_centre) < lake_radius() + 120.0:
				cost += 10.0
			# Never back toward where it began, nor far from the way it set out.
			cost += maxf(p.distance_to(from) - q.distance_to(from), 0.0) * 0.4
			cost += (1.0 - h.dot(dir)) * 3.0
			if cost < best:
				best = cost
				best_h = h
		heading = best_h
		p += heading * step
		out.append(p)
		if p.length() > ROAD_END:
			break
	return out


## One pass of corner-cutting (Chaikin), the ends kept.
func _smooth(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	for i in pts.size() - 1:
		out.append(pts[i].lerp(pts[i + 1], 0.25))
		out.append(pts[i].lerp(pts[i + 1], 0.75))
	out.append(pts[pts.size() - 1])
	return out


## Points every `step` metres along a line.
func _resample(pts: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	var carry := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var span := a.distance_to(b)
		var t := step - carry
		while t <= span:
			out.append(a.lerp(b, t / span))
			t += step
		carry = span - (t - step)
	out.append(pts[pts.size() - 1])
	return out


## The bed along a line: the ground smoothed over `window` points either
## side, then held to MAX_GRADE.
func _bed(pts: PackedVector2Array, window: int) -> PackedFloat32Array:
	var raw := PackedFloat32Array()
	for v in pts:
		raw.append(_natural(v.x, v.y))
	var out := PackedFloat32Array()
	out.resize(raw.size())
	for i in raw.size():
		var sum := 0.0
		var n := 0
		for j in range(maxi(0, i - window), mini(raw.size(), i + window + 1)):
			sum += raw[j]
			n += 1
		out[i] = sum / n
	_hold_grade(out, pts[0].distance_to(pts[1]), MAX_GRADE)
	return out


## No rise or fall steeper than grade between neighbours, both ways.
func _hold_grade(ys: PackedFloat32Array, spacing: float, grade: float) -> void:
	var most := spacing * grade
	for i in range(1, ys.size()):
		ys[i] = clampf(ys[i], ys[i - 1] - most, ys[i - 1] + most)
	for i in range(ys.size() - 2, -1, -1):
		ys[i] = clampf(ys[i], ys[i + 1] - most, ys[i + 1] + most)


## What the land is graded to (every third point of the road, every
## point of the lane, with the bank each needs: wider as the cut or fill
## is deeper, the deeper of the two sides counting), and every segment
## of it into the cells its bank reaches.
func _index_roads() -> void:
	_road_cells.clear()
	for k in 2:
		var pts := drive_pts if k == 1 else road_pts
		var ys := drive_y if k == 1 else road_y
		var every := 1 if k == 1 else 3
		var half := DRIVE_HALF if k == 1 else ROAD_HALF
		var bp := PackedVector2Array()
		var by := PackedFloat32Array()
		var bb := PackedFloat32Array()
		var i := 0
		while true:
			var j := mini(i, pts.size() - 1)
			var v := pts[j]
			var t := (pts[mini(j + 1, pts.size() - 1)] - pts[maxi(j - 1, 0)]).normalized()
			var n := Vector2(-t.y, t.x)
			var cut := 0.0
			for side: float in [-1.0, 1.0]:
				for dd: float in [half + ROAD_SHOULDER + 3.0, half + ROAD_SHOULDER + 8.0]:
					var q := v + n * side * dd
					cut = maxf(cut, absf(_natural(q.x, q.y) - ys[j]))
			bp.append(v)
			by.append(ys[j])
			bb.append(maxf(ROAD_BANK, cut * BANK_SLOPE))
			if j == pts.size() - 1:
				break
			i += every
		_bed_pts[k] = bp
		_bed_y[k] = by
		_bed_bank[k] = bb
		for s in bp.size() - 1:
			var reach := half + ROAD_SHOULDER + maxf(bb[s], bb[s + 1]) + 1.0
			var lo := Vector2(minf(bp[s].x, bp[s + 1].x), minf(bp[s].y, bp[s + 1].y)) - Vector2(reach, reach)
			var hi := Vector2(maxf(bp[s].x, bp[s + 1].x), maxf(bp[s].y, bp[s + 1].y)) + Vector2(reach, reach)
			for cx in range(floori(lo.x / ROAD_CELL), floori(hi.x / ROAD_CELL) + 1):
				for cz in range(floori(lo.y / ROAD_CELL), floori(hi.y / ROAD_CELL) + 1):
					var key := Vector2i(cx, cz)
					if not _road_cells.has(key):
						_road_cells[key] = []
					(_road_cells[key] as Array).append([k, s])
	# The grading on each cell's grid.
	_grade.clear()
	for key: Vector2i in _road_cells:
		var grid := PackedFloat32Array()
		grid.resize(GRADE_N * GRADE_N * 2)
		var any := false
		for j in GRADE_N:
			for i in GRADE_N:
				var r := road_at(key.x * ROAD_CELL + i * GRADE_STEP, key.y * ROAD_CELL + j * GRADE_STEP)
				var w := 0.0
				if r.x != INF:
					var flat := r.z + ROAD_SHOULDER
					w = 1.0 - smoothstep(flat, flat + r.w, r.x)
				grid[(j * GRADE_N + i) * 2] = w
				grid[(j * GRADE_N + i) * 2 + 1] = w * r.y
				any = any or w > 0.0
		if any:
			_grade[key] = grid


## The road and the driveway drawn as ribbons on their beds.
func _build_roads() -> void:
	if road_pts.is_empty():
		return
	road_mat = ShaderMaterial.new()
	road_mat.shader = load("res://world/road.gdshader")
	road_mat.set_shader_parameter("half_width", ROAD_HALF)
	drive_mat = ShaderMaterial.new()
	drive_mat.shader = load("res://world/road.gdshader")
	drive_mat.set_shader_parameter("half_width", DRIVE_HALF)
	drive_mat.set_shader_parameter("two_track", 1.0)
	for drive: bool in [false, true]:
		var pts := drive_pts if drive else road_pts
		var ys := drive_y if drive else road_y
		var samples: Array[Dictionary] = []
		var along := 0.0
		for i in pts.size():
			var a := pts[maxi(i - 1, 0)]
			var b := pts[mini(i + 1, pts.size() - 1)]
			var t := (b - a).normalized()
			if i > 0:
				along += pts[i].distance_to(pts[i - 1])
			# Lifted a little more far from the middle, where the ground's
			# triangles are larger than the road is wide.
			var lift := 0.04 + 0.0004 * pts[i].length()
			samples.append({"c": Vector3(pts[i].x, ys[i] + lift, pts[i].y), "n": Vector2(-t.y, t.x),
				"w": (DRIVE_HALF if drive else ROAD_HALF) + 0.3, "s": along})
		var ribbon := _water_ribbon(samples, drive_mat if drive else road_mat)
		ribbon.name = "Driveway" if drive else "Road"


## The pond's rough radius, metres: a circle of its area.
func lake_radius() -> float:
	return sqrt(float(lake_cells.size()) * LAKE_STEP * LAKE_STEP / PI)


## Find the farmhouse's site: round the pond, between 10 and 40 metres
## from the water's edge and 1.5 to 6 metres above it, the spot whose
## natural ground across the house and its yard varies least, a little
## nearer the water counting for it. The house faces the pond's middle.
func find_site() -> void:
	if lake_cells.is_empty():
		return
	var edge: Array[Vector2] = []
	for c: Vector2i in lake_cells:
		if not (lake_cells.has(c + Vector2i(1, 0)) and lake_cells.has(c - Vector2i(1, 0))
				and lake_cells.has(c + Vector2i(0, 1)) and lake_cells.has(c - Vector2i(0, 1))):
			edge.append((Vector2(c) + Vector2(0.5, 0.5)) * LAKE_STEP)
	# Every few cells of the shore are enough to measure from.
	var step := maxi(1, edge.size() / 400)
	var shore_pts: Array[Vector2] = []
	for i in range(0, edge.size(), step):
		shore_pts.append(edge[i])
	var reach := lake_radius() + 80.0
	var best := INF
	var g := -LAKE_SEARCH
	while g <= LAKE_SEARCH:
		var k := -LAKE_SEARCH
		while k <= LAKE_SEARCH:
			var p := Vector2(g, k)
			k += 4.0
			if p.distance_to(lake_centre) > reach:
				continue
			var shore := INF
			for e in shore_pts:
				shore = minf(shore, p.distance_squared_to(e))
			shore = sqrt(shore)
			var h := _natural(p.x, p.y)
			if shore < 10.0 or shore > 40.0 or h < lake_level + 1.5 or h > lake_level + 6.0:
				continue
			var face := lake_centre - p
			var yaw := atan2(-face.y, face.x)
			# The ground's spread over the house and its yard, turned so.
			var lo := INF
			var hi := -INF
			var c := cos(yaw)
			var s := sin(yaw)
			var u := HOUSE_RECT.position.x - YARD_MARGIN
			while u <= HOUSE_RECT.end.x + YARD_MARGIN:
				var w := HOUSE_RECT.position.y - YARD_MARGIN
				while w <= HOUSE_RECT.end.y + YARD_MARGIN:
					var q := p + Vector2(u * c + w * s, -u * s + w * c)
					var v := _natural(q.x, q.y)
					lo = minf(lo, v)
					hi = maxf(hi, v)
					w += 2.0
				u += 2.0
			var score := (hi - lo) + 0.03 * shore
			if score < best:
				best = score
				site = p
				site_yaw = yaw
				site_y = h
		g += 4.0
	stats["site_spread"] = best


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
	find_site()
	find_road()
	super()
	_build_roads()


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
