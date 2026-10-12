class_name AlchemistHouse
extends Node3D
## The alchemist's house: a stone cottage of the 1600s, left empty and in
## slight disrepair, of two rooms under one steep slate roof: the living
## room at the west end round a great hearth, and the workshop at the east
## end, with a furnace against its gable, a long bench of glassware, a
## writing desk, and in the middle of it a table of loose spinstones
## (CrystalTable) under a burning glass set in the roof (BurningGlass),
## its curtains drawn shut.
##
## Built in its own frame: the ground at the house's middle at the origin,
## x along the ridge (east), z toward the front (south). Rubble-stone
## walls 0.6 m thick, limewashed inside, stone gables, a roof pitched at
## PITCH, its underside meeting the walls' outer faces at EAVE. The
## burning glass is in the north slope over the workshop at the foot of a
## barrel pointing up and north (AXIS_UP) at the heliostat's mirror on its
## mast north of the house (Heliostat), which the player sets by hand to
## throw the sun down the barrel; the table is where the lens's light
## then lands, down the barrel's axis.
##
## Disrepair: a patch of slates gone from the north slope, its battens
## bare, moss along the north eaves, a few slates slipped on the south
## slope and one fallen by the door, a pane broken in the living room's
## front window, one chimney pot broken, a chair overturned, a flask
## broken on the bench.

const LEN := 13.0                       # m: outside, along the ridge
const DEP := 6.6                        # m: outside, front to back
const T := 0.6                          # m: the walls
const FLOOR := 0.03                     # m: the flagstones' top over the ground
const EAVE := 2.8                       # m: the roof's underside on the walls' outer faces
const PITCH := 50.0                     # degrees
const ROOF_T := 0.22                    # m: rafters, boards and slates
const OVER := 0.35                      # m: the eaves past the walls
const PART_X := -1.4                    # m: the wall between the two rooms
const PART_T := 0.5
const GLASS_X := 2.4                    # m: the burning glass's middle, along the ridge
const GLASS_Z := -2.0                   # m: and toward the front (in the north slope)
const AXIS_UP := 55.0                   # degrees: its barrel's axis over level, toward the north
const DOOR_X := -2.6                    # m: the front door's middle
const DOOR_H := 2.05
const STONE := Color(0.5, 0.47, 0.42)
const MORTAR := Color(0.66, 0.63, 0.56)
const LIME := Color(0.86, 0.83, 0.74)
const OAK := Color(0.4, 0.29, 0.19)
const SLATE := Color(0.29, 0.31, 0.35)

var glass: BurningGlass
var table: CrystalTable
var heliostat: Heliostat

var _world: Node
var _rng := RandomNumberGenerator.new()
var _out := CozyMesh.new()             # outside: stone, slates
var _in := CozyMesh.new()              # inside: limewash, timber, furniture
var _panes := CozyMesh.new()           # window glass
var _body := StaticBody3D.new()
var _sin := sin(deg_to_rad(PITCH))
var _cos := cos(deg_to_rad(PITCH))
var _ridge_under := EAVE + DEP * 0.5 * tan(deg_to_rad(PITCH))


## `world` gives the house its materials (`material`).
func _init(world: Node) -> void:
	name = "AlchemistHouse"
	_world = world
	_rng.seed = 1661


func _ready() -> void:
	add_child(_body)
	var outside: StandardMaterial3D = _world.call("material", true, false)
	var inside: StandardMaterial3D = _world.call("material", true, true)
	var pane_mat := StandardMaterial3D.new()
	pane_mat.vertex_color_use_as_albedo = true
	pane_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pane_mat.roughness = 0.08
	pane_mat.metallic_specular = 0.7
	_walls()
	_gables()
	_chimneys()
	_roof()
	_floor()
	_living_room()
	_workshop()
	for part: Array in [[_out, outside, true], [_in, inside, true], [_panes, pane_mat, false]]:
		var view := MeshInstance3D.new()
		view.mesh = (part[0] as CozyMesh).commit(part[1])
		if not part[2]:
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(view)
	# The front door, hung at its west jamb, opening inward; the door
	# between the rooms stood open.
	var door := MillDoor.new(0.98, DOOR_H - 0.03, Color(0.38, 0.27, 0.18), outside,
			"Door\nThe house's front door. A click opens and shuts it.")
	door.position = Vector3(DOOR_X - 0.49, FLOOR, DEP * 0.5 - T * 0.5)
	add_child(door)
	var inner := MillDoor.new(0.88, DOOR_H - 0.03, Color(0.42, 0.3, 0.2), inside,
			"Door\nBetween the living room and the workshop. A click opens and shuts it.")
	inner.position = Vector3(PART_X, FLOOR, 0.75)
	inner.rotation.y = -PI * 0.5
	add_child(inner)
	inner.set_open(true)
	_burning_glass(inside)


## Sets the sun on the burning glass and the table.
func set_sun(to_sun: Vector3, sunlight: float) -> void:
	heliostat.set_sun(to_sun, sunlight)
	table.to_sun = to_sun


## Lines for the panel: the mirror and the crystals.
func report() -> String:
	var lines := "The mirror faces %d degrees from north, tilted %d; its light comes down %d degrees off the barrel's axis." % [
			roundi(heliostat.bearing), roundi(heliostat.tilt), roundi(heliostat.off_axis())]
	if glass.light <= 0.0:
		lines = "The mirror faces %d degrees from north, tilted %d; no sun on it." % [roundi(heliostat.bearing), roundi(heliostat.tilt)]
	return lines + "
" + table.report()


## ---- helpers ------------------------------------------------------------------

## A card for what the player looks at: on its own layer, met by the
## crosshair, not walked into, and out of the burning glass's way.
func _note(at: Vector3, size: Vector3, text: String) -> void:
	var note := HoverNote.new(at, size, text)
	note.collision_layer = 4
	add_child(note)


func _solid(extent: Vector3, at: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = extent
	var c := CollisionShape3D.new()
	c.shape = shape
	c.position = at
	_body.add_child(c)


## A point on the roof's underside: `side` 1 the south slope, -1 the
## north; `t` metres down the slope from the ridge.
func _under(side: float, x: float, t: float) -> Vector3:
	return Vector3(x, _ridge_under - t * _sin, side * t * _cos)


## The frame of a slope: x along it, y out of the roof, z down the slope.
func _slope_basis(side: float) -> Basis:
	return Basis(Vector3(side, 0, 0), Vector3(0, _cos, side * _sin), Vector3(0, -_sin, side * _cos))


## A box on a slope over [x0, x1] across and [t0, t1] down it, `lift` out
## of the underside to its middle, `thick` through.
func _on_slope(m: CozyMesh, side: float, x0: float, x1: float, t0: float, t1: float, lift: float, thick: float, colour: Color, tilt := 0.0) -> void:
	var b := _slope_basis(side)
	var at := _under(side, (x0 + x1) * 0.5, (t0 + t1) * 0.5) + b.y * lift
	m.box(Vector3(absf(x1 - x0), thick, t1 - t0), CozyMesh.at(at, b * Basis(Vector3.RIGHT, tilt)), colour)


## A wall's face of rubble: stones in rough courses, a little proud of the
## mortar, over the rectangle of the face from `a` (lower left) along
## `across` for `width` and up for `high`; the openings' rectangles (across from a, up from a: Rect2) left bare.
## `top` limits the height at a point across (for a gable's slopes).
func _rubble(a: Vector3, across: Vector3, width: float, high: float, holes: Array[Rect2], top := Callable()) -> void:
	var y := 0.0
	var dir := across.normalized()
	var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
	while y < high - 0.05:
		var course := _rng.randf_range(0.18, 0.32)
		var u := -_rng.randf_range(0.0, 0.3)
		while u < width:
			var long := _rng.randf_range(0.28, 0.62)
			var u0 := maxf(u + 0.025, 0.0)
			var u1 := minf(u + long - 0.025, width)
			var y0 := y + 0.02
			var y1 := minf(y + course - 0.02, high)
			var mid := Vector2((u0 + u1) * 0.5, (y0 + y1) * 0.5)
			var ok := u1 - u0 > 0.08 and y1 - y0 > 0.06
			if ok and top.is_valid():
				ok = y1 < float(top.call(u0)) - 0.04 and y1 < float(top.call(u1)) - 0.04
			for hole in holes:
				if ok and hole.grow(0.04).intersects(Rect2(u0, y0, u1 - u0, y1 - y0)):
					ok = false
			if ok:
				var proud := _rng.randf_range(0.012, 0.03)
				var tint := _rng.randf_range(-0.07, 0.07)
				var colour := Color(STONE.r + tint, STONE.g + tint, STONE.b + tint * 0.8)
				if _rng.randf() < 0.12:
					colour = colour.lerp(Color(0.56, 0.5, 0.36), 0.5)
				_out.box(Vector3(u1 - u0, y1 - y0, proud * 2.0), CozyMesh.at(a + dir * mid.x + Vector3.UP * mid.y, basis), colour)
			u += long
		y += course


## A wall running along x at `z` (its middle), from x0 to x1, its inside
## toward `inward` (z), with openings [middle x, width, sill, head].
func _wall_x(z: float, x0: float, x1: float, inward: float, openings: Array) -> void:
	var cuts: Array = openings.duplicate()
	cuts.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	var x := x0
	for o: Array in cuts:
		var l: float = o[0] - o[1] * 0.5
		var r: float = o[0] + o[1] * 0.5
		_wall_piece(Vector3(x, 0, z), Vector3(l - x, EAVE, T), inward)
		if o[2] > 0.0:
			_wall_piece(Vector3(l, 0, z), Vector3(o[1], o[2], T), inward)
		_wall_piece(Vector3(l, o[3], z), Vector3(o[1], EAVE - o[3], T), inward)
		_window_or_door(Vector3(o[0], 0, z), Vector3.RIGHT, o[1], o[2], o[3], Vector3(0, 0, -inward))
		x = r
	_wall_piece(Vector3(x, 0, z), Vector3(x1 - x, EAVE, T), inward)
	# The outer face's stones.
	var holes: Array[Rect2] = []
	for o: Array in cuts:
		holes.append(Rect2(o[0] - o[1] * 0.5 - x0, o[2], o[1], o[3] - o[2]))
	var face := z - inward * T * 0.5
	if inward > 0.0:
		_rubble(Vector3(x1, 0, face), Vector3.LEFT, x1 - x0, EAVE, _flip(holes, x1 - x0))
	else:
		_rubble(Vector3(x0, 0, face), Vector3.RIGHT, x1 - x0, EAVE, holes)


## The rectangles mirrored across a face `width` wide (for a face read
## from its other end).
func _flip(holes: Array[Rect2], width: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for h in holes:
		out.append(Rect2(width - h.position.x - h.size.x, h.position.y, h.size.x, h.size.y))
	return out


## A wall running along z at `x` (its middle), from z0 to z1, its inside
## toward `inward` (x), with openings [middle z, width, sill, head].
func _wall_z(x: float, z0: float, z1: float, inward: float, openings: Array, thick := T, stones := true) -> void:
	var z := z0
	var cuts: Array = openings.duplicate()
	cuts.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	for o: Array in cuts:
		var l: float = o[0] - o[1] * 0.5
		_wall_piece_z(Vector3(x, 0, z), Vector3(thick, EAVE, l - z), inward)
		if o[2] > 0.0:
			_wall_piece_z(Vector3(x, 0, l), Vector3(thick, o[2], o[1]), inward)
		_wall_piece_z(Vector3(x, o[3], l), Vector3(thick, EAVE - o[3], o[1]), inward)
		if stones:
			_window_or_door(Vector3(x, 0, o[0]), Vector3.BACK, o[1], o[2], o[3], Vector3(-inward, 0, 0))
		z = o[0] + o[1] * 0.5
	_wall_piece_z(Vector3(x, 0, z), Vector3(thick, EAVE, z1 - z), inward)
	if stones:
		var holes: Array[Rect2] = []
		for o: Array in cuts:
			holes.append(Rect2(o[0] - o[1] * 0.5 - z0, o[2], o[1], o[3] - o[2]))
		var face := x - inward * thick * 0.5
		if inward > 0.0:
			_rubble(Vector3(face, 0, z0), Vector3.BACK, z1 - z0, EAVE, holes)
		else:
			_rubble(Vector3(face, 0, z1), Vector3.FORWARD, z1 - z0, EAVE, _flip(holes, z1 - z0))


## A piece of a wall along x: from `corner` (its low x end, the ground,
## the wall's middle), `size` long, high and thick; mortar outside,
## limewash on its inner face within the rooms.
func _wall_piece(corner: Vector3, size: Vector3, inward: float) -> void:
	if size.x <= 0.001 or size.y <= 0.001:
		return
	var at := corner + Vector3(size.x * 0.5, size.y * 0.5, 0)
	_out.box(size, CozyMesh.at(at), MORTAR)
	_solid(size, at)
	var x0 := maxf(corner.x, -LEN * 0.5 + T)
	var x1 := minf(corner.x + size.x, LEN * 0.5 - T)
	if x1 > x0:
		var y0 := maxf(corner.y, FLOOR)
		_in.box(Vector3(x1 - x0, corner.y + size.y - y0, 0.01), CozyMesh.at(Vector3((x0 + x1) * 0.5, (y0 + corner.y + size.y) * 0.5, corner.z + inward * (size.z * 0.5 + 0.005))), LIME)


## The same for a wall along z, `size` thick, high, long.
func _wall_piece_z(corner: Vector3, size: Vector3, inward: float) -> void:
	if size.z <= 0.001 or size.y <= 0.001:
		return
	var at := corner + Vector3(0, size.y * 0.5, size.z * 0.5)
	_out.box(size, CozyMesh.at(at), MORTAR)
	_solid(size, at)
	var z0 := maxf(corner.z, -DEP * 0.5 + T)
	var z1 := minf(corner.z + size.z, DEP * 0.5 - T)
	if z1 > z0:
		var y0 := maxf(corner.y, FLOOR)
		for side: float in ([inward] if absf(corner.x) > LEN * 0.5 - T else [1.0, -1.0]):
			_in.box(Vector3(0.01, corner.y + size.y - y0, z1 - z0), CozyMesh.at(Vector3(corner.x + side * (size.x * 0.5 + 0.005), (y0 + corner.y + size.y) * 0.5, (z0 + z1) * 0.5)), LIME)


## An opening's dressed stone surround outside, its oak frame, and for a
## window its leaded casement: `at` the opening's middle at the ground in
## the wall's middle, `along` the wall's way, `out` its outward normal.
func _window_or_door(at: Vector3, along: Vector3, width: float, sill: float, head: float, out: Vector3) -> void:
	var face := at + out * (T * 0.5)
	var dressed := Color(0.62, 0.58, 0.5)
	var b := Basis(along, Vector3.UP, along.cross(Vector3.UP))
	# The lintel over it, the jambs' quoins, and a sill under a window.
	_out.box(Vector3(width + 0.36, 0.26, 0.06), CozyMesh.at(face + Vector3.UP * (head + 0.13), b), dressed)
	var y := sill
	var k := 0
	while y < head - 0.05:
		var high := minf(0.32, head - y)
		var wide := 0.2 if k % 2 == 0 else 0.3
		for s: float in [-1.0, 1.0]:
			_out.box(Vector3(wide, high - 0.03, 0.05), CozyMesh.at(face + along * s * (width * 0.5 + wide * 0.5) + Vector3.UP * (y + high * 0.5), b), dressed.darkened(_rng.randf() * 0.08))
		y += high
		k += 1
	if sill > 0.0:
		_out.box(Vector3(width + 0.16, 0.08, 0.14), CozyMesh.at(face + out * 0.04 + Vector3.UP * (sill - 0.04), b), dressed)
		# The casement, set back in the opening: an oak frame, a mullion, the
		# glass in diamond quarries of lead.
		var set := at + out * 0.12
		var high := head - sill
		for s: float in [-1.0, 1.0]:
			_in.box(Vector3(0.06, high, 0.08), CozyMesh.at(set + along * s * (width * 0.5 - 0.03) + Vector3.UP * (sill + high * 0.5), b), OAK)
			_in.box(Vector3(width, 0.06, 0.08), CozyMesh.at(set + Vector3.UP * (sill + 0.03 if s < 0.0 else head - 0.03), b), OAK)
		_in.box(Vector3(0.05, high, 0.07), CozyMesh.at(set + Vector3.UP * (sill + high * 0.5), b), OAK)
		var pane_w := width * 0.5 - 0.085
		var pane_h := high - 0.12
		for s: float in [-1.0, 1.0]:
			var middle := set + along * s * (pane_w * 0.5 + 0.025) + Vector3.UP * (sill + 0.06 + pane_h * 0.5)
			var broken := s < 0.0 and absf(at.x - (-4.6)) < 0.01 and out.z > 0.0
			_pane(middle, along, pane_w, pane_h, broken)


## One pane of leaded glass at `middle`, `along` its width.
func _pane(middle: Vector3, along: Vector3, w: float, h: float, broken: bool) -> void:
	var normal := along.cross(Vector3.UP)
	var b := Basis(along, Vector3.UP, normal)
	var glass := Color(0.78, 0.86, 0.8, 0.32)
	if broken:
		# A quarry and a half gone at the lower outer corner.
		var hole := Rect2(-w * 0.5, -h * 0.5, w * 0.45, h * 0.28)
		for piece in [Rect2(-w * 0.5, hole.end.y, w, h * 0.5 - hole.end.y), Rect2(hole.end.x, -h * 0.5, w * 0.5 - hole.end.x, hole.size.y)]:
			var r: Rect2 = piece
			_panes.box(Vector3(r.size.x, r.size.y, 0.004), CozyMesh.at(middle + along * r.get_center().x + Vector3.UP * r.get_center().y, b), glass)
	else:
		_panes.box(Vector3(w, h, 0.004), CozyMesh.at(middle, b), glass)
	# The leads, two ways on the diagonal.
	var lead := Color(0.25, 0.25, 0.26)
	var step := 0.16
	for way: float in [1.0, -1.0]:
		var c := -(w + h)
		while c < w + h:
			var ends := _clip(Vector2(c, 0), Vector2(1, way).normalized(), w, h)
			if ends.size() == 2:
				var p: Vector2 = ends[0]
				var q: Vector2 = ends[1]
				if p.distance_to(q) > 0.02:
					_in.rod(middle + along * p.x + Vector3.UP * p.y, middle + along * q.x + Vector3.UP * q.y, 0.004, 4, lead)
			c += step


## Where the line through `p` along `dir` crosses the rectangle w by h
## round the origin: its two ends, or none.
func _clip(p: Vector2, dir: Vector2, w: float, h: float) -> Array:
	var t0 := -1e9
	var t1 := 1e9
	for axis in 2:
		var lo := -(w if axis == 0 else h) * 0.5
		var hi := -lo
		var o := p[axis]
		var d := dir[axis]
		if absf(d) < 1e-6:
			if o < lo or o > hi:
				return []
			continue
		var a := (lo - o) / d
		var c := (hi - o) / d
		t0 = maxf(t0, minf(a, c))
		t1 = minf(t1, maxf(a, c))
	if t1 <= t0:
		return []
	return [p + dir * t0, p + dir * t1]


## ---- the shell ----------------------------------------------------------------

func _walls() -> void:
	var z_mid := DEP * 0.5 - T * 0.5
	# Front (south) and back (north), between the gables' outer faces.
	_wall_x(z_mid, -LEN * 0.5, LEN * 0.5, -1.0, [[DOOR_X, 1.0, 0.0, DOOR_H], [-4.6, 0.8, 0.85, 1.85],
			[0.6, 0.8, 0.85, 1.85], [4.6, 0.8, 0.85, 1.85]])
	_wall_x(-z_mid, -LEN * 0.5, LEN * 0.5, 1.0, [[-4.8, 0.7, 1.0, 1.85], [3.2, 0.8, 1.15, 1.95]])
	# The gables' walls to the eaves, between the front and back walls.
	_wall_z(-LEN * 0.5 + T * 0.5, -DEP * 0.5 + T, DEP * 0.5 - T, 1.0, [])
	_wall_z(LEN * 0.5 - T * 0.5, -DEP * 0.5 + T, DEP * 0.5 - T, -1.0, [[1.3, 0.7, 1.0, 1.85]])
	# The rubble on the gables' ends of the long walls' corners: quoins.
	var quoin := Color(0.6, 0.56, 0.48)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var y := 0.0
			var k := 0
			while y < EAVE - 0.1:
				var high := minf(0.3, EAVE - y)
				var long := 0.55 if k % 2 == 0 else 0.32
				var short := 0.32 if k % 2 == 0 else 0.55
				var corner := Vector3(sx * (LEN * 0.5 + 0.02), y + high * 0.5, sz * (DEP * 0.5 + 0.02))
				_out.box(Vector3(long, high - 0.03, 0.05), CozyMesh.at(corner + Vector3(-sx * long * 0.5, 0, 0)), quoin.darkened(_rng.randf() * 0.08))
				_out.box(Vector3(0.05, high - 0.03, short), CozyMesh.at(corner + Vector3(0, 0, -sz * short * 0.5)), quoin.darkened(_rng.randf() * 0.08))
				y += high
				k += 1
	# The wall heads: the walls' tops along the eaves, sloped to the roof.
	# A right triangle across, its upright side on the inner face (the
	# prism's apex at its local -x, which points in).
	var head_rise := T * tan(deg_to_rad(PITCH))
	var head := PrismMesh.new()
	head.size = Vector3(T, head_rise, LEN)
	head.left_to_right = 0.0
	for side: float in [-1.0, 1.0]:
		var prism := Basis(Vector3(0, 0, side), Vector3.UP, Vector3(-side, 0, 0))
		_out.add(head, CozyMesh.at(Vector3(0, EAVE + head_rise * 0.5, side * (DEP * 0.5 - T * 0.5)), prism), MORTAR)
		_in.box(Vector3(LEN - T * 2.0, head_rise, 0.01), CozyMesh.at(Vector3(0, EAVE + head_rise * 0.5, side * (DEP * 0.5 - T - 0.005))), LIME)
	# The wall between the rooms, its doorway near the front.
	_wall_z(PART_X, -DEP * 0.5 + T, DEP * 0.5 - T, 1.0, [[1.2, 0.9, 0.0, DOOR_H]], PART_T, false)
	_in.box(Vector3(0.12, 0.2, 1.14), CozyMesh.at(Vector3(PART_X, DOOR_H + 0.1, 1.2)), OAK)
	var rise := (DEP * 0.5) * tan(deg_to_rad(PITCH))
	var gable := Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0))
	_in.prism(Vector3(DEP, rise, PART_T), CozyMesh.at(Vector3(PART_X, EAVE + rise * 0.5, 0), gable), LIME)


func _gables() -> void:
	var rise := (DEP * 0.5) * tan(deg_to_rad(PITCH))
	var gable := Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0))
	for sx: float in [-1.0, 1.0]:
		var x := sx * (LEN * 0.5 - T * 0.5)
		_out.prism(Vector3(DEP, rise, T), CozyMesh.at(Vector3(x, EAVE + rise * 0.5, 0), gable), MORTAR)
		_in.prism(Vector3(DEP - T * 2.0 - 0.02, rise - T * tan(deg_to_rad(PITCH)), 0.01),
				CozyMesh.at(Vector3(x - sx * (T * 0.5 + 0.005), EAVE + T * tan(deg_to_rad(PITCH)) + (rise - T * tan(deg_to_rad(PITCH))) * 0.5, 0), gable), LIME)
		# Its rubble, to the slopes.
		var face := x + sx * T * 0.5
		var top := func(u: float) -> float: return rise - absf(u - DEP * 0.5) * tan(deg_to_rad(PITCH))
		if sx < 0.0:
			_rubble(Vector3(face, EAVE, -DEP * 0.5), Vector3.BACK, DEP, rise, [], top)
		else:
			_rubble(Vector3(face, EAVE, DEP * 0.5), Vector3.FORWARD, DEP, rise, [], top)
		# The coping stones along its top, over the slates.
		for side: float in [-1.0, 1.0]:
			_on_slope(_out, side, x - 0.38, x + 0.38, 0.0, (DEP * 0.5) / _cos + 0.05, ROOF_T + 0.08, 0.16, Color(0.58, 0.54, 0.47))


func _chimneys() -> void:
	var top := _ridge_under + ROOF_T / _cos
	# The great stack on the west gable, over the hearth, two pots, one
	# broken.
	var west := Vector3(-LEN * 0.5 + 0.1, 0, 0)
	var high := top + 1.1
	_out.box(Vector3(0.9, high, 1.4), CozyMesh.at(west + Vector3(0, high * 0.5, 0)), MORTAR)
	_solid(Vector3(0.9, high, 1.4), west + Vector3(0, high * 0.5, 0))
	_rubble(Vector3(west.x - 0.45, 0, 0.7), Vector3.FORWARD, 1.4, high, [])
	_out.box(Vector3(1.0, 0.12, 1.5), CozyMesh.at(west + Vector3(0, high - 0.15, 0)), Color(0.58, 0.54, 0.47))
	var pot := Color(0.62, 0.38, 0.28)
	_out.cyl(0.13, 0.16, 0.5, 10, CozyMesh.at(west + Vector3(0, high + 0.25, -0.3)), pot)
	_out.cyl(0.15, 0.16, 0.22, 10, CozyMesh.at(west + Vector3(0, high + 0.11, 0.3)), pot)
	_out.box(Vector3(0.08, 0.14, 0.06), CozyMesh.at(west + Vector3(0.1, high + 0.27, 0.36), Basis(Vector3.BACK, 0.4)), pot)
	# The furnace's flue on the east gable, behind the ridge.
	var east := Vector3(LEN * 0.5 - 0.25, 0, -1.2)
	var east_high := top + 0.5
	_out.box(Vector3(0.75, east_high, 0.75), CozyMesh.at(east + Vector3(0, east_high * 0.5, 0)), MORTAR)
	_solid(Vector3(0.75, east_high, 0.75), east + Vector3(0, east_high * 0.5, 0))
	_rubble(Vector3(east.x + 0.375, 0, -1.575), Vector3.BACK, 0.75, east_high, [])
	_out.box(Vector3(0.85, 0.1, 0.85), CozyMesh.at(east + Vector3(0, east_high - 0.12, 0)), Color(0.58, 0.54, 0.47))
	_out.cyl(0.11, 0.13, 0.4, 10, CozyMesh.at(east + Vector3(0, east_high + 0.2, 0)), pot)


func _roof() -> void:
	var end := (DEP * 0.5 + OVER) / _cos
	var half := LEN * 0.5 + 0.12
	# The burning glass's opening in the north slope, round its tilted
	# lens.
	var t_glass := absf(GLASS_Z) / _cos
	var open := 0.75
	var open_t := 0.95
	var board := Color(0.3, 0.22, 0.15)
	for side: float in [-1.0, 1.0]:
		var pieces: Array = [[-half, half, 0.0, end]]
		if side < 0.0:
			pieces = [[-half, half, 0.0, t_glass - open_t], [-half, half, t_glass + open_t, end],
					[-half, GLASS_X - open, t_glass - open_t, t_glass + open_t], [GLASS_X + open, half, t_glass - open_t, t_glass + open_t]]
		# The boarding on the rafters, seen from inside.
		for p: Array in pieces:
			_on_slope(_in, side, p[0], p[1], p[2], p[3], 0.06, 0.12, board)
		# Rafters under it, a purlin each side, and the ridge beam.
		var x := -LEN * 0.5 + T + 0.3
		while x < LEN * 0.5 - T:
			if side > 0.0 or absf(x - GLASS_X) > open + 0.05:
				_on_slope(_in, side, x - 0.05, x + 0.05, 0.0, (DEP * 0.5 - T) / _cos, -0.07, 0.14, OAK)
			x += 0.75
		_on_slope(_in, side, -LEN * 0.5 + T, LEN * 0.5 - T, 1.55, 1.75, -0.18, 0.2, OAK)
		# The slates in courses, each course a little steeper than the
		# roof so each laps over the one below; the patch gone from the
		# north slope, its battens bare, moss along the north eaves.
		var t := 0.04
		var row := 0
		while t < end:
			var x0 := -half
			while x0 < half:
				var x1 := minf(x0 + _rng.randf_range(1.2, 3.2), half)
				var cut: Array = [[x0, x1]]
				if side < 0.0 and t + 0.3 > t_glass - open_t - 0.05 and t < t_glass + open_t + 0.05:
					cut = [[x0, minf(x1, GLASS_X - open - 0.06)], [maxf(x0, GLASS_X + open + 0.06), x1]]
				if side < 0.0 and t > 1.4 and t < 2.3:
					var gone := -3.3 + 0.25 * sin(row * 1.7)
					cut = [[x0, minf(x1, gone)], [maxf(x0, gone + 0.9 + 0.2 * cos(row * 2.3)), x1]]
				for c: Array in cut:
					if c[1] - c[0] > 0.05:
						var tint := _rng.randf_range(-0.03, 0.03)
						_on_slope(_out, side, c[0], c[1], t, t + 0.3, ROOF_T - 0.02, 0.025, Color(SLATE.r + tint, SLATE.g + tint, SLATE.b + tint), 0.05)
				x0 = x1
			t += 0.24
			row += 1
		if side < 0.0:
			for k in 6:
				var bt := 1.45 + k * 0.16
				_on_slope(_out, side, -3.35, -2.3, bt, bt + 0.04, ROOF_T - 0.07, 0.025, Color(0.48, 0.36, 0.24))
			for k in 14:
				var mx := _rng.randf_range(-LEN * 0.5, LEN * 0.5)
				var mt := end - _rng.randf_range(0.2, 1.4)
				var w := _rng.randf_range(0.25, 0.7)
				if mx + w > GLASS_X - open - 0.1 and mx < GLASS_X + open + 0.1 and mt < t_glass + open_t + 0.1:
					continue
				_on_slope(_out, side, mx, mx + w, mt, mt + w * 0.6, ROOF_T + 0.005, 0.02, Color(0.36, 0.44, 0.24).darkened(_rng.randf() * 0.2))
	# Slates slipped on the south slope.
	for k in 3:
		var sx := _rng.randf_range(-5.0, 0.5)
		var st := _rng.randf_range(2.6, 4.6)
		var b := _slope_basis(1.0) * Basis(Vector3.UP, _rng.randf_range(-0.5, 0.5))
		_out.box(Vector3(0.3, 0.025, 0.4), CozyMesh.at(_under(1.0, sx, st) + b.y * (ROOF_T + 0.01), b), SLATE.lightened(0.05))
	# One fallen by the door.
	_out.box(Vector3(0.3, 0.02, 0.42), CozyMesh.at(Vector3(DOOR_X + 1.2, 0.03, DEP * 0.5 + 0.9), Basis(Vector3.UP, 0.7) * Basis(Vector3.RIGHT, 0.08)), SLATE)
	_out.box(Vector3(0.16, 0.02, 0.2), CozyMesh.at(Vector3(DOOR_X + 1.45, 0.025, DEP * 0.5 + 1.1), Basis(Vector3.UP, -0.4)), SLATE)
	# The ridge's half-round tiles.
	var ridge_top := _ridge_under + ROOF_T / _cos - 0.03
	_out.cyl(0.12, 0.12, LEN + 0.1, 12, CozyMesh.at(Vector3(0, ridge_top, 0), Basis(Vector3.BACK, PI * 0.5)), SLATE.darkened(0.15))
	_in.box(Vector3(LEN - T * 2.0, 0.24, 0.16), CozyMesh.at(Vector3(0, _ridge_under - 0.2, 0)), OAK)
	# Tie beams across the rooms at the eaves, clear of the glass's light.
	for bx: float in [-4.0, 0.2, 4.9]:
		_in.box(Vector3(0.22, 0.26, DEP - T * 2.0), CozyMesh.at(Vector3(bx, EAVE + 0.35, 0)), OAK)
	# The lead apron round the opening outside.
	var b2 := _slope_basis(-1.0)
	var middle := _under(-1.0, GLASS_X, t_glass)
	_out.box(Vector3(open * 2.0 + 0.3, 0.012, open_t * 2.0 + 0.3), CozyMesh.at(middle + b2.y * (ROOF_T + 0.01), b2), Color(0.5, 0.52, 0.54))


func _floor() -> void:
	var x_in := LEN * 0.5 - T
	var z_in := DEP * 0.5 - T
	_solid(Vector3(LEN, FLOOR * 2.0, DEP), Vector3(0, 0, 0))
	# The bedding the flags are laid in, showing between them.
	_in.box(Vector3(x_in * 2.0, 0.01, z_in * 2.0), CozyMesh.at(Vector3(0, 0.006, 0)), Color(0.36, 0.34, 0.3))
	var x := -x_in
	while x < x_in - 0.01:
		var w := minf(_rng.randf_range(0.45, 0.75), x_in - x)
		var z := -z_in
		while z < z_in - 0.01:
			var d := minf(_rng.randf_range(0.4, 0.7), z_in - z)
			var tint := _rng.randf_range(-0.05, 0.05)
			_in.box(Vector3(w - 0.02, FLOOR, d - 0.02), CozyMesh.at(Vector3(x + w * 0.5, FLOOR * 0.5, z + d * 0.5)), Color(0.5 + tint, 0.48 + tint, 0.44 + tint))
			z += d
		x += w
	# The threshold under the front door.
	_out.box(Vector3(1.1, FLOOR + 0.02, T + 0.2), CozyMesh.at(Vector3(DOOR_X, (FLOOR + 0.02) * 0.5, DEP * 0.5 - T * 0.5 + 0.1)), Color(0.6, 0.57, 0.5))
	# Weeds along the walls' feet.
	for k in 40:
		var along := _rng.randf_range(-LEN * 0.5, LEN * 0.5)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var at := Vector3(along, 0.04, side * (DEP * 0.5 + 0.08))
		if absf(along - DOOR_X) < 0.8:
			continue
		_out.ball(_rng.randf_range(0.06, 0.13), 6, CozyMesh.at(at), Color(0.34, 0.48, 0.22).darkened(_rng.randf() * 0.25), true)


## ---- the rooms ----------------------------------------------------------------

func _living_room() -> void:
	var x_wall := -LEN * 0.5 + T
	# The hearth: a breast of stone out from the gable, its fireplace open
	# under an oak lintel, the hearthstone before it, a pot on a crane.
	var breast := 0.55
	var dressed := Color(0.6, 0.56, 0.48)
	var soot := Color(0.12, 0.11, 0.1)
	var bx := x_wall + breast * 0.5
	for z: float in [-0.85, 0.85]:
		_in.box(Vector3(breast, 1.3, 0.3), CozyMesh.at(Vector3(bx, FLOOR + 0.65, z)), dressed)
		_solid(Vector3(breast, 1.3, 0.3), Vector3(bx, FLOOR + 0.65, z))
	var up := EAVE + 2.6 - (FLOOR + 1.3)
	_in.box(Vector3(breast, up, 2.0), CozyMesh.at(Vector3(bx, FLOOR + 1.3 + up * 0.5, 0)), LIME.darkened(0.04))
	_in.box(Vector3(breast + 0.04, 0.24, 1.6), CozyMesh.at(Vector3(bx + 0.02, FLOOR + 1.3 - 0.12, 0)), OAK)
	_in.box(Vector3(0.02, 1.3, 1.4), CozyMesh.at(Vector3(x_wall + 0.01, FLOOR + 0.65, 0)), soot)
	_in.box(Vector3(breast, 0.02, 1.4), CozyMesh.at(Vector3(bx, FLOOR + 0.005, 0)), soot.lightened(0.1))
	_in.box(Vector3(0.6, 0.04, 1.8), CozyMesh.at(Vector3(x_wall + breast + 0.3, FLOOR + 0.02, 0)), dressed.darkened(0.05))
	var iron := Color(0.16, 0.15, 0.15)
	_in.rod(Vector3(x_wall + 0.05, FLOOR + 0.2, -0.6), Vector3(x_wall + 0.05, FLOOR + 1.15, -0.6), 0.02, 6, iron)
	_in.rod(Vector3(x_wall + 0.05, FLOOR + 1.05, -0.6), Vector3(x_wall + 0.4, FLOOR + 1.05, -0.1), 0.015, 6, iron)
	_in.rod(Vector3(x_wall + 0.35, FLOOR + 1.05, -0.15), Vector3(x_wall + 0.35, FLOOR + 0.62, -0.15), 0.006, 4, iron)
	_in.ball(0.17, 10, CozyMesh.at(Vector3(x_wall + 0.35, FLOOR + 0.5, -0.15)), iron, false, 0.26)
	for k in 4:
		_in.cyl(0.04, 0.04, 0.45, 6, CozyMesh.at(Vector3(x_wall + 0.2 + k * 0.05, FLOOR + 0.06, 0.25 + k * 0.07), Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.RIGHT, k * 0.4)), Color(0.12, 0.1, 0.08))
	# A table and a bench, a chair overturned.
	var wood := Color(0.46, 0.33, 0.22)
	_table_at(Vector3(-3.6, FLOOR, 0.2), Vector2(1.6, 0.8), 0.74, wood)
	_in.box(Vector3(1.4, 0.06, 0.3), CozyMesh.at(Vector3(-3.6, FLOOR + 0.44, 0.9)), wood)
	for s: float in [-0.6, 0.6]:
		_in.box(Vector3(0.06, 0.41, 0.26), CozyMesh.at(Vector3(-3.6 + s, FLOOR + 0.205, 0.9)), wood.darkened(0.15))
	_solid(Vector3(1.4, 0.47, 0.3), Vector3(-3.6, FLOOR + 0.235, 0.9))
	var chair := Transform3D(Basis(Vector3.UP, 0.6) * Basis(Vector3.BACK, PI * 0.5), Vector3(-3.0, FLOOR + 0.22, -0.65))
	_in.box(Vector3(0.42, 0.05, 0.42), chair * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), wood)
	_in.box(Vector3(0.42, 0.5, 0.05), chair * Transform3D(Basis.IDENTITY, Vector3(0, 0.25, -0.19)), wood)
	for lx: float in [-0.18, 0.18]:
		for lz: float in [-0.18, 0.18]:
			_in.box(Vector3(0.04, 0.42, 0.04), chair * Transform3D(Basis.IDENTITY, Vector3(lx, -0.21, lz)), wood.darkened(0.15))
	# A box bed in the north-east corner, its curtain rail empty, a chest
	# at its foot; pewter on a shelf on the dividing wall.
	var bed := Vector3(-2.55, FLOOR, -2.2)
	_in.box(Vector3(1.75, 0.45, 1.0), CozyMesh.at(bed + Vector3(0, 0.225, 0)), wood.darkened(0.1))
	_in.box(Vector3(1.65, 0.12, 0.9), CozyMesh.at(bed + Vector3(0, 0.5, 0)), Color(0.66, 0.6, 0.48))
	_in.box(Vector3(0.5, 0.1, 0.35), CozyMesh.at(bed + Vector3(-0.5, 0.6, 0)), Color(0.72, 0.68, 0.58))
	for end: float in [-1.0, 1.0]:
		_in.box(Vector3(0.06, 0.95 if end < 0.0 else 0.7, 1.0), CozyMesh.at(bed + Vector3(end * 0.9, 0.475 if end < 0.0 else 0.35, 0)), wood.darkened(0.15))
	_solid(Vector3(1.75, 0.6, 1.0), bed + Vector3(0, 0.3, 0))
	_in.box(Vector3(0.9, 0.5, 0.5), CozyMesh.at(Vector3(-4.5, FLOOR + 0.25, -2.35)), wood.darkened(0.2))
	_solid(Vector3(0.9, 0.5, 0.5), Vector3(-4.5, FLOOR + 0.25, -2.35))
	_in.box(Vector3(0.22, 0.04, 1.4), CozyMesh.at(Vector3(PART_X - PART_T * 0.5 - 0.11, 1.75, -1.2)), wood)
	for k in 4:
		_in.cyl(0.13, 0.13, 0.015, 14, CozyMesh.at(Vector3(PART_X - PART_T * 0.5 - 0.05, 1.9, -1.7 + k * 0.32), Basis(Vector3.BACK, PI * 0.5 - 0.15)), Color(0.62, 0.62, 0.6))


## A plain table: top `size` at `high`, four legs.
func _table_at(at: Vector3, size: Vector2, high: float, colour: Color) -> void:
	_in.box(Vector3(size.x, 0.05, size.y), CozyMesh.at(at + Vector3(0, high - 0.025, 0)), colour)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_in.box(Vector3(0.06, high - 0.05, 0.06), CozyMesh.at(at + Vector3(sx * (size.x * 0.5 - 0.06), (high - 0.05) * 0.5, sz * (size.y * 0.5 - 0.06))), colour.darkened(0.15))
	_solid(Vector3(size.x, high, size.y), at + Vector3(0, high * 0.5, 0))


func _workshop() -> void:
	var x_wall := LEN * 0.5 - T
	var z_back := -DEP * 0.5 + T
	var wood := Color(0.46, 0.33, 0.22)
	var brick := Color(0.56, 0.3, 0.22)
	var glassware := Color(0.74, 0.84, 0.78)
	var brass := Color(0.78, 0.6, 0.3)
	# The furnace against the east gable: a round tower of brick on a
	# square base, a domed top with a sand bath, its fire door, the flue
	# into the gable's stack.
	var furnace := Vector3(x_wall - 0.55, FLOOR, -1.2)
	_in.box(Vector3(1.0, 0.3, 1.0), CozyMesh.at(furnace + Vector3(0, 0.15, 0)), brick.darkened(0.1))
	_in.cyl(0.42, 0.45, 1.25, 16, CozyMesh.at(furnace + Vector3(0, 0.3 + 0.625, 0)), brick)
	_in.ball(0.42, 16, CozyMesh.at(furnace + Vector3(0, 1.55, 0)), brick, true)
	_in.cyl(0.24, 0.2, 0.1, 14, CozyMesh.at(furnace + Vector3(0, 1.97, 0)), Color(0.3, 0.3, 0.3))
	_in.box(Vector3(0.05, 0.36, 0.3), CozyMesh.at(furnace + Vector3(-0.43, 0.62, 0)), Color(0.14, 0.13, 0.12))
	_in.box(Vector3(0.05, 0.22, 0.26), CozyMesh.at(furnace + Vector3(-0.42, 1.2, 0)), Color(0.18, 0.16, 0.14))
	_in.rod(furnace + Vector3(0.25, 1.75, 0), Vector3(x_wall, FLOOR + 2.0, -1.2), 0.09, 10, Color(0.2, 0.19, 0.18))
	_solid(Vector3(1.0, 1.9, 1.0), furnace + Vector3(0, 0.95, 0))
	# A retort on the sand bath, its neck reaching down to a receiver.
	_in.ball(0.11, 12, CozyMesh.at(furnace + Vector3(0, 2.1, 0)), glassware.darkened(0.15))
	_in.rod(furnace + Vector3(-0.05, 2.15, 0), furnace + Vector3(-0.65, 1.55, 0.25), 0.02, 6, glassware.darkened(0.15))
	_note(furnace + Vector3(0, 1.0, 0), Vector3(1.0, 2.1, 1.0),
			"Furnace\nThe alchemist's furnace, cold for many years, a retort still on its sand bath.")
	# The long bench under the back window, shelves of jars either side.
	var bench := Vector3(2.75, FLOOR, z_back + 0.33)
	_in.box(Vector3(5.2, 0.08, 0.66), CozyMesh.at(bench + Vector3(0, 0.88, 0)), wood)
	for lx: float in [-2.5, -0.8, 0.8, 2.5]:
		_in.box(Vector3(0.08, 0.84, 0.6), CozyMesh.at(bench + Vector3(lx, 0.42, 0)), wood.darkened(0.15))
	_in.box(Vector3(5.1, 0.04, 0.5), CozyMesh.at(bench + Vector3(0, 0.18, 0)), wood.darkened(0.1))
	_solid(Vector3(5.2, 0.92, 0.66), bench + Vector3(0, 0.46, 0))
	for span: Vector2 in [Vector2(0.2, 2.5), Vector2(3.9, 5.5)]:
		for y: float in [1.45, 1.9]:
			_in.box(Vector3(span.y - span.x, 0.04, 0.26), CozyMesh.at(Vector3((span.x + span.y) * 0.5, y, z_back + 0.13)), wood)
			var x := span.x + 0.12
			while x < span.y - 0.1:
				var r := _rng.randf_range(0.04, 0.08)
				var h := _rng.randf_range(0.1, 0.24)
				var c := [Color(0.42, 0.5, 0.36), Color(0.55, 0.42, 0.3), Color(0.3, 0.36, 0.5), Color(0.66, 0.6, 0.48), glassware][_rng.randi() % 5] as Color
				_in.cyl(r, r, h, 8, CozyMesh.at(Vector3(x, y + 0.02 + h * 0.5, z_back + 0.13 + _rng.randf_range(-0.04, 0.04))), c)
				_in.cyl(r * 0.5, r * 0.5, 0.03, 6, CozyMesh.at(Vector3(x, y + 0.035 + h, z_back + 0.13)), c.darkened(0.3))
				x += r * 2.0 + _rng.randf_range(0.03, 0.12)
	var top := bench + Vector3(0, 0.92, 0)
	# A still: the gourd on its ring, the head, its beak to a flask.
	_in.torus(0.08, 0.12, 12, 6, CozyMesh.at(top + Vector3(-1.9, 0.02, 0)), Color(0.3, 0.29, 0.28))
	_in.ball(0.15, 14, CozyMesh.at(top + Vector3(-1.9, 0.16, 0)), glassware)
	_in.cyl(0.05, 0.06, 0.14, 10, CozyMesh.at(top + Vector3(-1.9, 0.34, 0)), glassware)
	_in.ball(0.1, 12, CozyMesh.at(top + Vector3(-1.9, 0.46, 0)), glassware, false, 0.14)
	_in.rod(top + Vector3(-1.82, 0.46, 0.0), top + Vector3(-1.35, 0.22, 0.08), 0.015, 6, glassware)
	_in.ball(0.1, 12, CozyMesh.at(top + Vector3(-1.3, 0.1, 0.08)), glassware)
	_in.cyl(0.025, 0.03, 0.12, 8, CozyMesh.at(top + Vector3(-1.3, 0.24, 0.08)), glassware)
	# A pair of scales: a post, a beam, two pans.
	var scales := top + Vector3(-0.4, 0, 0)
	_in.cyl(0.08, 0.1, 0.03, 12, CozyMesh.at(scales + Vector3(0, 0.015, 0)), brass)
	_in.cyl(0.012, 0.012, 0.42, 6, CozyMesh.at(scales + Vector3(0, 0.22, 0)), brass)
	_in.box(Vector3(0.5, 0.015, 0.015), CozyMesh.at(scales + Vector3(0, 0.43, 0), Basis(Vector3.BACK, 0.06)), brass)
	for s: float in [-1.0, 1.0]:
		var hang := scales + Vector3(s * 0.24, 0.43 - s * 0.015, 0)
		_in.rod(hang, hang + Vector3(0, -0.25, 0), 0.003, 4, brass)
		_in.cyl(0.08, 0.06, 0.02, 12, CozyMesh.at(hang + Vector3(0, -0.26, 0)), brass)
	# A mortar and pestle, books, and a flask fallen and broken.
	_in.cyl(0.08, 0.06, 0.1, 10, CozyMesh.at(top + Vector3(0.3, 0.05, 0.1)), Color(0.55, 0.53, 0.5))
	_in.rod(top + Vector3(0.3, 0.06, 0.1), top + Vector3(0.38, 0.22, 0.04), 0.015, 6, Color(0.55, 0.53, 0.5))
	for k in 3:
		_in.box(Vector3(0.3, 0.05, 0.22), CozyMesh.at(top + Vector3(1.0, 0.025 + k * 0.05, 0.05), Basis(Vector3.UP, k * 0.2)), [Color(0.4, 0.2, 0.15), Color(0.3, 0.26, 0.2), Color(0.25, 0.3, 0.22)][k])
	_in.ball(0.08, 10, CozyMesh.at(top + Vector3(1.7, 0.07, 0.15), Basis(Vector3.BACK, 1.3)), glassware, true)
	for k in 6:
		_in.box(Vector3(0.04, 0.004, 0.03), CozyMesh.at(top + Vector3(1.85 + _rng.randf_range(-0.12, 0.12), 0.003, 0.15 + _rng.randf_range(-0.1, 0.1)), Basis(Vector3.UP, _rng.randf() * TAU)), glassware)
	_note(bench + Vector3(0, 0.6, 0), Vector3(5.2, 1.2, 0.66),
			"Bench\nGlassware, a still, a pair of scales, dust over all of it.")
	# A mirror of polished metal on a stand at the bench's east end,
	# tarnished, a crack across it.
	var mirror := top + Vector3(2.25, 0, 0.05)
	_in.cyl(0.07, 0.09, 0.03, 10, CozyMesh.at(mirror + Vector3(0, 0.015, 0)), brass.darkened(0.3))
	_in.rod(mirror, mirror + Vector3(0, 0.3, 0), 0.012, 6, brass.darkened(0.3))
	var face := Basis(Vector3.RIGHT, PI * 0.5 - 0.35)
	_in.cyl(0.17, 0.17, 0.025, 20, CozyMesh.at(mirror + Vector3(0, 0.42, 0), face), Color(0.66, 0.58, 0.42))
	_in.cyl(0.155, 0.155, 0.004, 20, CozyMesh.at(mirror + Vector3(0, 0.42, 0) + face.y * 0.013, face), Color(0.8, 0.76, 0.66))
	_in.box(Vector3(0.3, 0.003, 0.006), CozyMesh.at(mirror + Vector3(0, 0.42, 0) + face.y * 0.016, face * Basis(Vector3.UP, 0.6)), Color(0.2, 0.18, 0.15))
	_note(mirror + Vector3(0, 0.3, 0), Vector3(0.4, 0.6, 0.3),
			"Metal mirror\nA disc of polished bronze, tarnished, cracked across.")
	# The writing desk under the front window by the east wall, a stool,
	# pages on it and fallen from it.
	var desk := Vector3(4.6, FLOOR, DEP * 0.5 - T - 0.35)
	_table_at(desk, Vector2(1.2, 0.6), 0.76, wood)
	_in.cyl(0.18, 0.18, 0.04, 10, CozyMesh.at(desk + Vector3(-0.1, 0.46, -0.6)), wood)
	for k in 3:
		var a := TAU * k / 3.0
		_in.rod(desk + Vector3(-0.1 + cos(a) * 0.14, 0.0, -0.6 + sin(a) * 0.14), desk + Vector3(-0.1 + cos(a) * 0.1, 0.45, -0.6 + sin(a) * 0.1), 0.02, 5, wood.darkened(0.15))
	var paper := Color(0.86, 0.8, 0.64)
	var page_at: Array[Vector3] = [desk + Vector3(-0.3, 0.765, 0.0), desk + Vector3(0.05, 0.766, 0.08), desk + Vector3(0.3, 0.767, -0.05),
			desk + Vector3(-0.5, 0.032, -0.55), desk + Vector3(0.2, 0.033, -0.8), desk + Vector3(-0.9, 0.032, -0.25)]
	for p in page_at:
		_in.box(Vector3(0.2, 0.002, 0.28), CozyMesh.at(p, Basis(Vector3.UP, _rng.randf_range(-0.6, 0.6))), paper.darkened(_rng.randf() * 0.15))
	_in.box(Vector3(0.24, 0.05, 0.32), CozyMesh.at(desk + Vector3(0.38, 0.785, 0.12), Basis(Vector3.UP, 0.2)), Color(0.36, 0.22, 0.16))
	_in.cyl(0.03, 0.035, 0.05, 8, CozyMesh.at(desk + Vector3(-0.45, 0.785, 0.18)), Color(0.15, 0.15, 0.17))
	_in.rod(desk + Vector3(-0.45, 0.8, 0.18), desk + Vector3(-0.35, 0.98, 0.1), 0.006, 4, Color(0.9, 0.88, 0.82))
	_note(desk + Vector3(-0.2, 0.45, -0.3), Vector3(1.6, 0.9, 1.2),
			"Loose pages\nPages in a cramped, hurried hand, stained and out of order.")
	# A barrel by the east wall.
	_in.cyl(0.28, 0.25, 0.75, 14, CozyMesh.at(Vector3(x_wall - 0.35, FLOOR + 0.375, 0.35)), wood.darkened(0.05))
	for y: float in [0.12, 0.62]:
		_in.torus(0.25, 0.29, 14, 4, CozyMesh.at(Vector3(x_wall - 0.35, FLOOR + y, 0.35)), Color(0.2, 0.2, 0.2))
	_solid(Vector3(0.56, 0.75, 0.56), Vector3(x_wall - 0.35, FLOOR + 0.375, 0.35))


## The lens's frame: its axis AXIS_UP over level toward the north.
func _lens_basis() -> Basis:
	var a := deg_to_rad(AXIS_UP)
	var axis := Vector3(0, sin(a), -cos(a))
	return Basis(Vector3.RIGHT, axis, Vector3.RIGHT.cross(axis))


## The burning glass in the north slope in its barrel, the heliostat on
## its mast up the barrel's axis, and the table where the lens's light
## lands.
func _burning_glass(inside: Material) -> void:
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.42, 0.16, 0.12)
	cloth.roughness = 0.95
	var dim := Image.create(1, 1, false, Image.FORMAT_RGB8)
	dim.fill(Color(0.33, 0.33, 0.33))
	cloth.ao_enabled = true
	cloth.ao_texture = ImageTexture.create_from_image(dim)
	cloth.ao_light_affect = 0.0
	glass = BurningGlass.new({"wood": inside, "cloth": cloth}, FLOOR)
	var b := _lens_basis()
	var lens_at := _under(-1.0, GLASS_X, absf(GLASS_Z) / _cos) + Vector3(0, ROOF_T / _cos * 0.8, 0)
	glass.transform = Transform3D(b, lens_at)
	add_child(glass)
	# The barrel: oak staves bound with iron hoops, from inside the roof up
	# its axis to its mouth, dark inside; drawn on its own, the house's
	# meshes being made before this.
	var axis := b.y
	var staves := CozyMesh.new()
	var bore := CozyMesh.new()
	var barrel := CylinderMesh.new()
	barrel.top_radius = Heliostat.BARREL_R + 0.06
	barrel.bottom_radius = Heliostat.BARREL_R + 0.06
	barrel.height = Heliostat.BARREL + 0.35
	barrel.radial_segments = 24
	barrel.cap_top = false
	barrel.cap_bottom = false
	var along := Transform3D(b, lens_at + axis * (Heliostat.BARREL - 0.35) * 0.5)
	staves.add(barrel, along, OAK.darkened(0.15))
	var lining := barrel.duplicate() as CylinderMesh
	lining.top_radius = Heliostat.BARREL_R
	lining.bottom_radius = Heliostat.BARREL_R
	bore.add_inside(lining, along, Color(0.16, 0.13, 0.1))
	staves.torus(Heliostat.BARREL_R, Heliostat.BARREL_R + 0.07, 24, 4, Transform3D(b, lens_at + axis * Heliostat.BARREL), OAK.darkened(0.3))
	for k in 3:
		staves.torus(Heliostat.BARREL_R + 0.05, Heliostat.BARREL_R + 0.08, 24, 4, Transform3D(b, lens_at + axis * (0.1 + k * 0.38)), Color(0.24, 0.23, 0.22))
	var out_mat: StandardMaterial3D = _world.call("material", true, false)
	for part: Array in [[staves, out_mat], [bore, inside]]:
		var view := MeshInstance3D.new()
		view.mesh = (part[0] as CozyMesh).commit(part[1])
		add_child(view)
	# The heliostat's mirror up the axis, at its mast's height.
	heliostat = Heliostat.new(glass, out_mat, out_mat)
	var mirror_at := lens_at + axis * ((Heliostat.MAST_H - lens_at.y) / axis.y)
	heliostat.position = Vector3(mirror_at.x, 0, mirror_at.z)
	add_child(heliostat)
	# The table where the lens's light lands, down the axis.
	var drop := lens_at.y - (FLOOR + CrystalTable.TABLE_TOP)
	var spot := lens_at - axis * (drop / axis.y)
	table = CrystalTable.new(inside, glass)
	table.position = Vector3(spot.x, FLOOR, spot.z)
	add_child(table)
