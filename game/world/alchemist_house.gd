class_name AlchemistHouse
extends Node3D
## The alchemist's house: a stone cottage of the 1600s, left empty and in
## slight disrepair, one long room open to a steep slate roof: living
## at the west end round a great hearth, the workshop at the east end,
## with a furnace against its gable, a long bench of glassware, a
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
## slope and one fallen by the door, a pane broken in the living end's
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
const GLASS_X := 2.4                    # m: the burning glass's middle, along the ridge
const GLASS_Z := -2.0                   # m: and toward the front (in the north slope)
const AXIS_UP := 55.0                   # degrees: its barrel's axis over level, toward the north
const STAND_GAP := 0.14                 # m: the stand of controls north of the table's edge
const STAND_H := 1.3                    # m: its drums' blocks' tops over the floor
const DOOR_X := -2.6                    # m: the front door's middle
const DOOR_H := 2.05
const STONE := Color(0.5, 0.47, 0.42)
const MORTAR := Color(0.66, 0.63, 0.56)
const LIME := Color(0.86, 0.83, 0.74)
const OAK := Color(0.4, 0.29, 0.19)
const SLATE := Color(0.29, 0.31, 0.35)
# The hole rotted through the north slope over the living end, [x0, x1,
# t0, t1] (t down the slope from the ridge); its battens stay.
const HOLE := [-3.25, -2.45, 1.5, 2.2]
# The openings, [middle along the wall, width, sill, head]: the front's,
# the back's, the east gable's (along z).
const SOUTH_OPEN := [[DOOR_X, 1.0, 0.0, DOOR_H], [-4.6, 0.8, 0.85, 1.85], [0.6, 0.8, 0.85, 1.85], [4.6, 0.8, 0.85, 1.85]]
const NORTH_OPEN := [[-4.8, 0.7, 1.0, 1.85], [3.2, 0.8, 1.15, 1.95]]
const EAST_OPEN := [[1.3, 0.7, 1.0, 1.85]]

var glass: BurningGlass
var table: CrystalTable
var heliostat: Heliostat

var _world: Node
var _rng := RandomNumberGenerator.new()
var _wear := RandomNumberGenerator.new()  # the two centuries' weathering, apart from the building's own draws
var _out := CozyMesh.new()             # outside: stone, slates
var _in := CozyMesh.new()              # inside: limewash, timber, furniture
var _panes := CozyMesh.new()           # window glass
var _stains := CozyMesh.new()          # see-through weathering laid over the stone: streaks, lichen
var _body := StaticBody3D.new()
var _sin := sin(deg_to_rad(PITCH))
var _cos := cos(deg_to_rad(PITCH))
var _ridge_under := EAVE + DEP * 0.5 * tan(deg_to_rad(PITCH))


## `world` gives the house its materials (`material`).
func _init(world: Node) -> void:
	name = "AlchemistHouse"
	_world = world
	_rng.seed = 1661
	_wear.seed = 1805


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
	_decay()
	_furnishings()
	_weathering()
	_overgrowth()
	_yard()
	var stain_mat := StandardMaterial3D.new()
	stain_mat.vertex_color_use_as_albedo = true
	stain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stain_mat.roughness = 0.95
	stain_mat.metallic_specular = 0.0
	for part: Array in [[_out, outside, true], [_in, inside, true], [_panes, pane_mat, false], [_stains, stain_mat, false]]:
		var view := MeshInstance3D.new()
		view.mesh = (part[0] as CozyMesh).commit(part[1])
		if not part[2]:
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(view)
	# The front door, hung at its west jamb, opening inward.
	var door := MillDoor.new(0.98, DOOR_H - 0.03, Color(0.42, 0.37, 0.3), outside,
			"Door\nThe house's front door. A click opens and shuts it.")
	door.position = Vector3(DOOR_X - 0.49, FLOOR, DEP * 0.5 - T * 0.5)
	add_child(door)
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


## The rectangle [x0, x1, t0, t1] less the `holes` (each the same), as
## rectangles: in bands between the holes' edges down the slope, each band
## the stretches across it no hole covers.
func _cut(whole: Array, holes: Array) -> Array:
	var cuts: Array[float] = [whole[2], whole[3]]
	for h: Array in holes:
		for t: float in [h[2], h[3]]:
			if t > whole[2] and t < whole[3]:
				cuts.append(t)
	cuts.sort()
	var out: Array = []
	for i in cuts.size() - 1:
		var ta: float = cuts[i]
		var tb: float = cuts[i + 1]
		if tb - ta < 0.001:
			continue
		var mid := (ta + tb) * 0.5
		var spans: Array = [[whole[0], whole[1]]]
		for h: Array in holes:
			if mid <= h[2] or mid >= h[3]:
				continue
			var kept: Array = []
			for sp: Array in spans:
				if h[1] <= sp[0] or h[0] >= sp[1]:
					kept.append(sp)
					continue
				if h[0] > sp[0]:
					kept.append([sp[0], h[0]])
				if h[1] < sp[1]:
					kept.append([h[1], sp[1]])
			spans = kept
		for sp: Array in spans:
			out.append([sp[0], sp[1], ta, tb])
	return out


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
				var at := a + dir * mid.x + Vector3.UP * mid.y
				var size := Vector3(u1 - u0, y1 - y0, proud * 2.0)
				var weathered: Variant = _weather_stone(colour, at.y, -basis.z.z)
				if weathered == null:
					# Fallen out: the hollow it left, dark, its mortar bed
					# showing at its back.
					_out.box(Vector3(size.x - 0.02, size.y - 0.02, 0.012), CozyMesh.at(at, basis), Color(0.2, 0.19, 0.17))
				else:
					_out.box(size, CozyMesh.at(at, basis), weathered as Color)
			u += long
		y += course


## Two centuries on a stone of `colour`, `high` over the ground, on a face
## turned `north` (1 due north, -1 due south): lichen, more on the shaded
## north; damp rising in the lowest courses, green on the north; now and
## then a stone fallen out of the face (null).
func _weather_stone(colour: Color, high: float, north: float) -> Variant:
	var shade := clampf(north, 0.0, 1.0)
	if high < 2.3 and _wear.randf() < 0.025:
		return null
	var c := colour
	if high < 0.7:
		var damp := (0.7 - high) / 0.7
		c = c.darkened(0.25 * damp)
		c = c.lerp(Color(0.3, 0.38, 0.24), 0.35 * damp * (0.3 + shade))
	if _wear.randf() < 0.05 + 0.12 * shade:
		var lichen := Color(0.68, 0.68, 0.46) if _wear.randf() < 0.6 else Color(0.74, 0.74, 0.68)
		c = c.lerp(lichen, _wear.randf_range(0.4, 0.75))
	elif _wear.randf() < 0.3:
		c = c.darkened(_wear.randf_range(0.05, 0.15))
	return c


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
## limewash on its inner face within the house.
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
			var broken := (s < 0.0 and absf(at.x - (-4.6)) < 0.01 and out.z > 0.0) or _wear.randf() < 0.3
			_pane(middle, along, pane_w, pane_h, broken)


## One pane of leaded glass at `middle`, `along` its width.
func _pane(middle: Vector3, along: Vector3, w: float, h: float, broken: bool) -> void:
	var normal := along.cross(Vector3.UP)
	var b := Basis(along, Vector3.UP, normal)
	var glass := Color(0.78, 0.86, 0.8, 0.32)
	if broken:
		# Quarries gone at one corner: the glass left round the hole.
		var hw := w * _wear.randf_range(0.3, 0.6)
		var hh := h * _wear.randf_range(0.2, 0.45)
		var hx := -w * 0.5 if _wear.randf() < 0.5 else w * 0.5 - hw
		var hy := -h * 0.5 if _wear.randf() < 0.6 else h * 0.5 - hh
		var hole := Rect2(hx, hy, hw, hh)
		var pieces: Array[Rect2] = [Rect2(-w * 0.5, -h * 0.5, w, hole.position.y + h * 0.5), Rect2(-w * 0.5, hole.end.y, w, h * 0.5 - hole.end.y),
				Rect2(-w * 0.5, hole.position.y, hole.position.x + w * 0.5, hh), Rect2(hole.end.x, hole.position.y, w * 0.5 - hole.end.x, hh)]
		for r in pieces:
			if r.size.x > 0.005 and r.size.y > 0.005:
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
	_wall_x(z_mid, -LEN * 0.5, LEN * 0.5, -1.0, SOUTH_OPEN)
	_wall_x(-z_mid, -LEN * 0.5, LEN * 0.5, 1.0, NORTH_OPEN)
	# The gables' walls to the eaves, between the front and back walls.
	_wall_z(-LEN * 0.5 + T * 0.5, -DEP * 0.5 + T, DEP * 0.5 - T, 1.0, [])
	_wall_z(LEN * 0.5 - T * 0.5, -DEP * 0.5 + T, DEP * 0.5 - T, -1.0, EAST_OPEN)
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
		# On the north slope the glass's opening and the hole where the
		# slates went and the boards under them rotted through.
		var holes: Array = []
		if side < 0.0:
			holes = [[GLASS_X - open, GLASS_X + open, t_glass - open_t, t_glass + open_t], HOLE]
		var pieces := _cut([-half, half, 0.0, end], holes)
		# The boarding on the rafters, seen from inside; the roof a solid,
		# so light and the player stop at it.
		for p: Array in pieces:
			_on_slope(_in, side, p[0], p[1], p[2], p[3], 0.06, 0.12, board)
			var b := _slope_basis(side)
			var size := Vector3(absf(p[1] - p[0]), ROOF_T, p[3] - p[2])
			var shape := BoxShape3D.new()
			shape.size = size
			var c := CollisionShape3D.new()
			c.shape = shape
			c.transform = Transform3D(b, _under(side, (p[0] + p[1]) * 0.5, (p[2] + p[3]) * 0.5) + b.y * (ROOF_T * 0.5))
			_body.add_child(c)
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
	# Tie beams across the room at the eaves, clear of the glass's light.
	for bx: float in [-4.0, 0.2, 4.9]:
		_in.box(Vector3(0.22, 0.26, DEP - T * 2.0), CozyMesh.at(Vector3(bx, EAVE + 0.35, 0)), OAK)
	# The opening closed round the barrel where it passes through the
	# roof: boarding under, lead over, from the opening's edges to the
	# barrel's outline in the roof (an ellipse, the barrel crossing the
	# roof a little aslant).
	var b2 := _slope_basis(-1.0)
	var middle := _under(-1.0, GLASS_X, t_glass)
	var axis := _lens_basis().y
	var lens_at := _lens_at()
	var plane := middle + b2.y * (ROOF_T * 0.5)
	var crossing := lens_at + axis * ((plane - lens_at).dot(b2.y) / axis.dot(b2.y))
	var shift := (crossing - middle).dot(b2.z)
	var r := Heliostat.BARREL_R + 0.06
	var ry := r / absf(axis.dot(b2.y))
	var sides := 32
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var pts: Array[Vector3] = []
		for a: float in [a0, a1]:
			var dir := Vector2(cos(a), sin(a))
			var reach := minf(open / maxf(absf(dir.x), 1e-4), (open_t - shift * signf(dir.y)) / maxf(absf(dir.y), 1e-4))
			pts.append(Vector3(dir.x * r, 0, dir.y * ry))
			pts.append(Vector3(dir.x * reach, 0, dir.y * reach))
		for face: Array in [[_in, 0.0, Color(0.3, 0.22, 0.15), -1.0], [_out, ROOF_T, Color(0.5, 0.52, 0.54), 1.0]]:
			var at := middle + b2.z * shift + b2.y * (face[1] as float)
			var q: Array[Vector3] = []
			for p in pts:
				q.append(at + b2 * p)
			(face[0] as CozyMesh).quad(q[0], q[2], q[3], q[1], b2.y * (face[3] as float), face[2])


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


## ---- two centuries ------------------------------------------------------------

## A point on a wall face, a little proud of its stones: `face` is [the
## point on it at the ground at its start, its way along, its outward
## normal, its width, its openings, how shaded it is]; `u` along, `y` up.
func _face_point(face: Array, u: float, y: float) -> Vector3:
	return (face[0] as Vector3) + (face[1] as Vector3) * u + Vector3.UP * y + (face[2] as Vector3) * 0.035


## Where an opening's middle lies along a face, from the face's start.
func _opening_u(face: Array, middle: float) -> float:
	var start: Vector3 = face[0]
	var along: Vector3 = face[1]
	if absf(along.x) > 0.5:
		return (middle - start.x) * along.x
	return (middle - start.z) * along.z


## A flat stain on a face, a disc `r` across, squashed `squash` up; drawn
## see-through over the stone.
func _blot(face: Array, u: float, y: float, r: float, colour: Color, squash := 1.0) -> void:
	var along: Vector3 = face[1]
	var out: Vector3 = face[2]
	var b := Basis(along, out, along.cross(out)).orthonormalized()
	_stains.ball(r, 10, CozyMesh.at(_face_point(face, u, y), b * Basis.from_scale(Vector3(1.0, 1.0, squash))), colour, false, 0.004)


## A streak running down a face from (u, y) for `length`, `wide`: the
## water's track, darkest at its head.
func _streak(face: Array, u: float, y: float, wide: float, length: float, alpha: float) -> void:
	var out: Vector3 = face[2]
	var along: Vector3 = face[1]
	var b := Basis(along, Vector3.UP, along.cross(Vector3.UP))
	for k in 3:
		var f := k / 3.0
		var l := length * (1.0 - f * 0.45)
		_stains.box(Vector3(wide * (1.0 - f * 0.4), l, 0.002), CozyMesh.at(_face_point(face, u, y - l * 0.5) + out * 0.002 * k, b), Color(0.16, 0.15, 0.13, alpha * 0.5))


## The weather's marks on the shell: water streaks under every sill and
## down from the eaves, a darkened band under them, soot at the stacks'
## tops, green damp along the shaded walls' feet, lichen in blotches on
## the walls (thicker to the north and west) and orange lichen on the
## south slope's slates, a gable's coping stone slipped, slate fragments
## along the eaves, the north window boarded up from outside.
func _weathering() -> void:
	var half := LEN * 0.5
	var faces: Array = [
		[Vector3(-half, 0, DEP * 0.5), Vector3.RIGHT, Vector3.BACK, LEN, SOUTH_OPEN, 0.0, false],
		[Vector3(half, 0, -DEP * 0.5), Vector3.LEFT, Vector3.FORWARD, LEN, NORTH_OPEN, 1.0, false],
		[Vector3(-half, 0, -DEP * 0.5), Vector3.BACK, Vector3.LEFT, DEP, [], 0.6, true],
		[Vector3(half, 0, DEP * 0.5), Vector3.FORWARD, Vector3.RIGHT, DEP, EAST_OPEN, 0.3, true],
	]
	for face: Array in faces:
		var width: float = face[3]
		var shade: float = face[5]
		var gable: bool = face[6]
		var along: Vector3 = face[1]
		var flat := Basis(along, Vector3.UP, along.cross(Vector3.UP))
		for o: Array in face[4]:
			if o[2] > 0.0:
				_streak(face, _opening_u(face, o[0]), o[2] - 0.06, o[1] * 0.8, _wear.randf_range(0.5, 0.85), 0.5)
		if not gable:
			_stains.box(Vector3(width, 0.45, 0.002), CozyMesh.at(_face_point(face, width * 0.5, EAVE - 0.22), flat), Color(0.14, 0.13, 0.12, 0.28))
			for k in 14:
				_streak(face, _wear.randf_range(0.3, width - 0.3), EAVE - 0.3, _wear.randf_range(0.06, 0.2), _wear.randf_range(0.4, 1.6), 0.3)
		if shade > 0.5:
			_stains.box(Vector3(width, 0.5, 0.002), CozyMesh.at(_face_point(face, width * 0.5, 0.25), flat), Color(0.24, 0.36, 0.18, 0.32))
		var count := roundi(18 + 40 * shade)
		for k in count:
			var u := _wear.randf_range(0.2, width - 0.2)
			var top := EAVE
			if gable:
				top = EAVE + (DEP * 0.5 - absf(u - DEP * 0.5)) * tan(deg_to_rad(PITCH)) - 0.2
			var y := _wear.randf_range(0.3, top - 0.1)
			var blocked := false
			for o: Array in face[4]:
				if absf(u - _opening_u(face, o[0])) < o[1] * 0.5 + 0.25 and y > o[2] - 0.2 and y < o[3] + 0.3:
					blocked = true
			if blocked:
				continue
			# A colony: small crusts of one kind clustered, ragged at the edge;
			# orange more on the sunny faces.
			var kinds: Array[Color] = [Color(0.7, 0.7, 0.44, 0.5), Color(0.56, 0.6, 0.46, 0.5), Color(0.82, 0.58, 0.24, 0.5)]
			var colour := kinds[2] if _wear.randf() < 0.25 * (1.0 - shade) else kinds[_wear.randi() % 2]
			for j in _wear.randi_range(3, 8):
				_blot(face, u + _wear.randf_range(-0.12, 0.12), y + _wear.randf_range(-0.09, 0.09), _wear.randf_range(0.025, 0.07), colour.darkened(_wear.randf() * 0.1), _wear.randf_range(0.6, 1.0))
	# Soot at the stacks' tops.
	var roof_top := _ridge_under + ROOF_T / _cos
	for stack: Array in [[Vector3(-LEN * 0.5 + 0.1, roof_top + 1.1, 0), Vector3(0.9, 0.6, 1.4)], [Vector3(LEN * 0.5 - 0.25, roof_top + 0.5, -1.2), Vector3(0.75, 0.45, 0.75)]]:
		var c: Vector3 = stack[0]
		var size: Vector3 = stack[1]
		_stains.box(size + Vector3(0.08, 0, 0.08), CozyMesh.at(c - Vector3(0, size.y * 0.5 + 0.12, 0)), Color(0.08, 0.07, 0.07, 0.45))
	# Orange lichen on the south slope's slates, moss on the north's.
	for side: float in [1.0, -1.0]:
		var b := _slope_basis(side)
		for k in (45 if side > 0.0 else 25):
			var x := _wear.randf_range(-half, half)
			var t := _wear.randf_range(0.3, (DEP * 0.5 + OVER) / _cos - 0.2)
			if side < 0.0 and absf(x - GLASS_X) < 1.0:
				continue
			var colour := Color(0.86, 0.58, 0.2, 0.7) if side > 0.0 else Color(0.4, 0.48, 0.3, 0.5)
			_stains.ball(_wear.randf_range(0.04, 0.13), 8, CozyMesh.at(_under(side, x, t) + b.y * (ROOF_T + 0.012), b), colour, false, 0.004)
	# A coping stone on the east gable slipped down its slope.
	var slipped := _slope_basis(1.0) * Basis(Vector3.UP, 0.12)
	_out.box(Vector3(0.7, 0.16, 0.5), CozyMesh.at(_under(1.0, half - 0.3, 2.9) + _slope_basis(1.0).y * (ROOF_T + 0.17), slipped), Color(0.56, 0.52, 0.45))
	# Slate fragments fallen along the eaves.
	for k in 18:
		var side := 1.0 if k % 2 == 0 else -1.0
		var at := Vector3(_wear.randf_range(-half + 0.3, half - 0.3), 0.025, side * (DEP * 0.5 + _wear.randf_range(0.2, 0.9)))
		if side > 0.0 and absf(at.x - DOOR_X) < 0.8:
			continue
		_out.box(Vector3(0.2, 0.015, 0.28) * _wear.randf_range(0.4, 1.0), CozyMesh.at(at, Basis(Vector3.UP, _wear.randf() * TAU) * Basis(Vector3.RIGHT, _wear.randf_range(-0.15, 0.15))), SLATE.lightened(_wear.randf() * 0.1))
	# The north window boarded up from outside, its planks greyed, one
	# fallen.
	var o: Array = NORTH_OPEN[0]
	var plank := Color(0.48, 0.45, 0.4)
	for k in 3:
		var y: float = o[2] + 0.15 + k * 0.28
		_out.box(Vector3(o[1] + 0.36, 0.2, 0.03), CozyMesh.at(Vector3(o[0], y, -DEP * 0.5 - 0.05), Basis(Vector3.BACK, _wear.randf_range(-0.05, 0.05))), plank.darkened(_wear.randf() * 0.15))
		for side: float in [-1.0, 1.0]:
			_out.ball(0.012, 5, CozyMesh.at(Vector3(o[0] + side * (o[1] * 0.5 + 0.1), y, -DEP * 0.5 - 0.07)), Color(0.3, 0.2, 0.15))
	_out.box(Vector3(o[1] + 0.36, 0.2, 0.03), CozyMesh.at(Vector3(o[0] + 0.3, 0.06, -DEP * 0.5 - 0.5), Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, PI * 0.5 - 0.1)), plank.darkened(0.1))


## What has grown up round the house: ivy up the front's east end, the
## west chimney and the back's west end, a young ash at the north-west
## corner, brambles at the north-east, nettles and long grass along the
## walls' feet.
func _overgrowth() -> void:
	var half := LEN * 0.5
	_ivy(Vector3(half - 0.5, 0.0, DEP * 0.5), Vector3.RIGHT, Vector3.BACK, EAVE - 0.1, 0.9)
	_ivy(Vector3(-half - 0.45, 0.0, 0.75), Vector3.FORWARD, Vector3.LEFT, _ridge_under + 0.6, 0.6)
	_ivy(Vector3(-half + 1.2, 0.0, -DEP * 0.5), Vector3.LEFT, Vector3.FORWARD, EAVE - 0.3, 0.8)
	# The young ash: a slim grey trunk, a few boughs, clumps of leaves.
	var ash := Vector3(-half - 1.6, 0.0, -DEP * 0.5 - 1.4)
	var bark := Color(0.5, 0.48, 0.42)
	_out.rod(ash, ash + Vector3(0.2, 3.6, -0.1), 0.07, 7, bark)
	for k in 5:
		var from := ash + Vector3(0.2, 3.6, -0.1) * _wear.randf_range(0.45, 0.95)
		var to := from + Vector3(_wear.randf_range(-1.1, 1.1), _wear.randf_range(0.5, 1.2), _wear.randf_range(-1.1, 1.1))
		_out.rod(from, to, 0.035, 5, bark)
		for j in 4:
			_out.ball(_wear.randf_range(0.35, 0.6), 8, CozyMesh.at(to + Vector3(_wear.randf_range(-0.35, 0.35), _wear.randf_range(-0.1, 0.35), _wear.randf_range(-0.35, 0.35))), Color(0.34, 0.5, 0.24).darkened(_wear.randf() * 0.2))
	_solid(Vector3(0.16, 3.6, 0.16), ash + Vector3(0.1, 1.8, -0.05))
	# Brambles in a mound at the north-east corner.
	var bramble := Vector3(half + 0.6, 0.0, -DEP * 0.5 - 0.4)
	for k in 14:
		_out.ball(_wear.randf_range(0.2, 0.42), 7, CozyMesh.at(bramble + Vector3(_wear.randf_range(-0.9, 0.9), _wear.randf_range(0.1, 0.45), _wear.randf_range(-0.6, 0.6)), Basis.from_scale(Vector3(1.0, 0.7, 1.0))), Color(0.26, 0.38, 0.2).darkened(_wear.randf() * 0.2))
	# Long grass and nettles along the walls' feet, kept down by the door.
	for k in 140:
		var side := _wear.randi() % 4
		var at := Vector3.ZERO
		if side == 0:
			at = Vector3(_wear.randf_range(-half, half), 0, DEP * 0.5 + _wear.randf_range(0.05, 0.5))
			if absf(at.x - DOOR_X) < 1.0:
				continue
		elif side == 1:
			at = Vector3(_wear.randf_range(-half, half), 0, -DEP * 0.5 - _wear.randf_range(0.05, 0.6))
		elif side == 2:
			at = Vector3(-half - _wear.randf_range(0.05, 0.6), 0, _wear.randf_range(-DEP * 0.5, DEP * 0.5))
		else:
			at = Vector3(half + _wear.randf_range(0.05, 0.6), 0, _wear.randf_range(-DEP * 0.5, DEP * 0.5))
		if _wear.randf() < 0.25:
			# A nettle: a stem, pairs of leaves up it.
			var tall := _wear.randf_range(0.4, 0.8)
			_out.rod(at, at + Vector3(0, tall, 0), 0.008, 4, Color(0.3, 0.42, 0.2))
			for j in 4:
				var y := tall * (0.3 + j * 0.2)
				var turn := Basis(Vector3.UP, j * PI * 0.5)
				for s2: float in [-1.0, 1.0]:
					_out.ball(0.045, 5, CozyMesh.at(at + Vector3(0, y, 0) + turn * Vector3(s2 * 0.05, 0, 0), turn * Basis.from_scale(Vector3(1.0, 0.25, 0.6))), Color(0.24, 0.4, 0.18))
		else:
			for j in 5:
				var lean := Vector3(_wear.randf_range(-0.12, 0.12), _wear.randf_range(0.25, 0.55), _wear.randf_range(-0.12, 0.12))
				var foot := at + Vector3(_wear.randf_range(-0.05, 0.05), 0, _wear.randf_range(-0.05, 0.05))
				_out.prism(Vector3(0.025, lean.length(), 0.006), CozyMesh.at(foot + lean * 0.5, CozyMesh.aligned(lean)), Color(0.42, 0.56, 0.26).lerp(Color(0.66, 0.62, 0.36), _wear.randf() * 0.5))


## The yard's leavings: path stones to the door sunk in the turf, a
## stone trough cracked through, a water butt at the front's east corner
## rotted to its last staves and hoops; up top, a fern and grass rooted in
## the great chimney's head, moss along the gables' copings and the
## ridge; swallows' nests under the front eaves.
func _yard() -> void:
	var half := LEN * 0.5
	var flag := Color(0.58, 0.56, 0.5)
	for k in 5:
		var at := Vector3(DOOR_X + _wear.randf_range(-0.12, 0.12), 0.005, DEP * 0.5 + 0.75 + k * 0.62)
		_out.box(Vector3(_wear.randf_range(0.45, 0.6), 0.04, _wear.randf_range(0.4, 0.5)), CozyMesh.at(at, Basis(Vector3.UP, _wear.randf_range(-0.25, 0.25))), flag.darkened(_wear.randf() * 0.12))
		for j in 4:
			var blade := at + Vector3(_wear.randf_range(-0.35, 0.35), 0, _wear.randf_range(-0.3, 0.3))
			_out.prism(Vector3(0.02, 0.18, 0.005), CozyMesh.at(blade + Vector3(0, 0.09, 0)), Color(0.42, 0.56, 0.26))
	# The trough, west of the door, split across one end.
	var trough := Vector3(DOOR_X - 1.6, 0.0, DEP * 0.5 + 0.9)
	var stone := Color(0.56, 0.54, 0.48)
	_out.box(Vector3(1.0, 0.08, 0.5), CozyMesh.at(trough + Vector3(0, 0.04, 0)), stone)
	for side: float in [-1.0, 1.0]:
		_out.box(Vector3(1.0, 0.36, 0.08), CozyMesh.at(trough + Vector3(0, 0.22, side * 0.21)), stone.darkened(0.05))
	_out.box(Vector3(0.08, 0.36, 0.34), CozyMesh.at(trough + Vector3(-0.46, 0.22, 0)), stone.darkened(0.05))
	_out.box(Vector3(0.08, 0.3, 0.34), CozyMesh.at(trough + Vector3(0.52, 0.12, 0.02), Basis(Vector3.BACK, -0.5)), stone.darkened(0.1))
	_out.box(Vector3(0.84, 0.03, 0.34), CozyMesh.at(trough + Vector3(-0.04, 0.1, 0)), Color(0.3, 0.38, 0.22))
	_solid(Vector3(1.0, 0.4, 0.5), trough + Vector3(0, 0.2, 0))
	# The water butt, its staves fallen outward, hoops rusted on the turf.
	var butt := Vector3(half + 0.5, 0.0, DEP * 0.5 + 0.5)
	var stave := Color(0.4, 0.36, 0.3)
	for k in 14:
		var a := TAU * k / 14.0
		if k % 5 == 2:
			var lie := butt + Vector3(cos(a), 0, sin(a)) * 0.75
			_out.box(Vector3(0.09, 0.025, 0.8), CozyMesh.at(lie + Vector3(0, 0.015, 0), Basis(Vector3.UP, -a)), stave.darkened(0.1))
			continue
		var tall := _wear.randf_range(0.35, 0.8)
		var lean := Basis(Vector3(-sin(a), 0, cos(a)), _wear.randf_range(0.0, 0.18))
		_out.box(Vector3(0.1, tall, 0.025), CozyMesh.at(butt + Vector3(cos(a), 0, sin(a)) * 0.3 + Vector3(0, tall * 0.5, 0), lean * Basis(Vector3.UP, -a + PI * 0.5)), stave.darkened(_wear.randf() * 0.15))
	_out.torus(0.29, 0.32, 18, 4, CozyMesh.at(butt + Vector3(0, 0.2, 0)), Color(0.4, 0.24, 0.16))
	_out.torus(0.3, 0.33, 18, 4, CozyMesh.at(butt + Vector3(0.25, 0.02, 0.45), Basis(Vector3.RIGHT, 0.05)), Color(0.4, 0.24, 0.16))
	# The great chimney's head: a fern and grass rooted in its mortar.
	var head := Vector3(-half + 0.1, _ridge_under + ROOF_T / _cos + 1.1, 0)
	for k in 6:
		var a := TAU * k / 6.0
		var frond := Vector3(cos(a) * 0.3, 0.25, sin(a) * 0.3)
		_out.prism(Vector3(0.1, frond.length(), 0.01), CozyMesh.at(head + Vector3(0.25, 0.0, 0.45) + frond * 0.5, CozyMesh.aligned(frond)), Color(0.3, 0.5, 0.22))
	for k in 5:
		_out.prism(Vector3(0.02, 0.2, 0.005), CozyMesh.at(head + Vector3(-0.3 + k * 0.05, 0.1, -0.5), Basis(Vector3.BACK, _wear.randf_range(-0.3, 0.3))), Color(0.5, 0.58, 0.3))
	# Moss along the gables' copings and the ridge.
	for side: float in [-1.0, 1.0]:
		for gx: float in [-half + 0.3, half - 0.3]:
			for k in 6:
				var t := _wear.randf_range(0.3, DEP * 0.5 / _cos)
				var b := _slope_basis(side)
				_out.ball(_wear.randf_range(0.06, 0.12), 6, CozyMesh.at(_under(side, gx + _wear.randf_range(-0.25, 0.25), t) + b.y * (ROOF_T + 0.17), b * Basis.from_scale(Vector3(1.0, 0.35, 1.0))), Color(0.34, 0.46, 0.22).darkened(_wear.randf() * 0.2))
	var ridge_top := _ridge_under + ROOF_T / _cos + 0.08
	for k in 10:
		_out.ball(_wear.randf_range(0.05, 0.1), 6, CozyMesh.at(Vector3(_wear.randf_range(-half, half), ridge_top, _wear.randf_range(-0.05, 0.05)), Basis.from_scale(Vector3(1.0, 0.4, 1.0))), Color(0.36, 0.48, 0.24).darkened(_wear.randf() * 0.2))
	# Swallows' nests of mud under the front eaves.
	for x: float in [1.9, 3.4]:
		var nest := Vector3(x, EAVE - 0.12, DEP * 0.5 + 0.07)
		_out.ball(0.09, 8, CozyMesh.at(nest, Basis.from_scale(Vector3(1.0, 0.8, 0.7))), Color(0.5, 0.42, 0.32), true)
		_out.ball(0.09, 8, CozyMesh.at(nest, Basis(Vector3.RIGHT, PI) * Basis.from_scale(Vector3(1.0, 0.8, 0.7))), Color(0.46, 0.38, 0.28), true)


## Ivy from `foot` up a face (`along` its way, `out` from it) to `top`:
## three stems climbing and wandering sideways, leaves in clusters along
## them, the plant `spread` across.
func _ivy(foot: Vector3, along: Vector3, out: Vector3, top: float, spread: float) -> void:
	var stem := Color(0.3, 0.24, 0.18)
	var flat := Basis(along, out, along.cross(out)).orthonormalized()
	for k in 3:
		var p := foot + along * _wear.randf_range(-spread * 0.3, spread * 0.3) + out * 0.05
		while p.y < top:
			var next := p + Vector3.UP * _wear.randf_range(0.12, 0.2) + along * _wear.randf_range(-0.09, 0.09)
			_out.rod(p, next, 0.012, 4, stem)
			for j in 3:
				var leaf := next + along * _wear.randf_range(-0.13, 0.13) + Vector3.UP * _wear.randf_range(-0.08, 0.08) + out * _wear.randf_range(0.02, 0.08)
				var colour := [Color(0.2, 0.34, 0.16), Color(0.26, 0.4, 0.2), Color(0.18, 0.3, 0.15)][_wear.randi() % 3] as Color
				_out.ball(_wear.randf_range(0.04, 0.065), 6, CozyMesh.at(leaf, Basis(out, _wear.randf() * TAU) * flat), colour, false, 0.02)
			p = next


## Inside, two centuries empty: the limewash flaked off in patches to the
## stone, a damp tide-mark along the walls' feet, water's tracks down the
## back wall under the roof's hole, cracks, cobwebs in the corners and
## the window reveals, flakes of limewash fallen along the walls, leaves
## blown in at the door.
func _decay() -> void:
	var x_in := LEN * 0.5 - T
	var z_in := DEP * 0.5 - T
	# The inner faces: [a point at the floor at its start, along, inward].
	var faces: Array = [
		[Vector3(-x_in, 0, z_in), Vector3.RIGHT, Vector3.FORWARD, x_in * 2.0, SOUTH_OPEN],
		[Vector3(x_in, 0, -z_in), Vector3.LEFT, Vector3.BACK, x_in * 2.0, NORTH_OPEN],
		[Vector3(-x_in, 0, -z_in), Vector3.BACK, Vector3.RIGHT, z_in * 2.0, []],
		[Vector3(x_in, 0, z_in), Vector3.FORWARD, Vector3.LEFT, z_in * 2.0, EAST_OPEN],
	]
	var damp := LIME.darkened(0.1).lerp(Color(0.62, 0.62, 0.5), 0.3)
	for face: Array in faces:
		var start: Vector3 = face[0]
		var along: Vector3 = face[1]
		var inward: Vector3 = face[2]
		var width: float = face[3]
		var flat := Basis(along, Vector3.UP, along.cross(Vector3.UP))
		var at := func(u: float, y: float, proud: float) -> Vector3:
			return start + along * u + Vector3.UP * y + inward * proud
		# The tide-mark: damp risen up the wall's foot, its top ragged.
		var u := 0.0
		while u < width:
			var w := minf(_wear.randf_range(0.25, 0.6), width - u)
			var h := _wear.randf_range(0.36, 0.5)
			_in.box(Vector3(w, h, 0.004), CozyMesh.at(at.call(u + w * 0.5, FLOOR + h * 0.5, 0.012), flat), damp.darkened(_wear.randf() * 0.04))
			u += w
		# Limewash fallen away in patches, the stone and mortar behind.
		for k in 9:
			var pu := _wear.randf_range(0.3, width - 0.3)
			var py := _wear.randf_range(0.7, EAVE - 0.3)
			var clear := true
			for o: Array in face[4]:
				var ou := (float(o[0]) - start.x) * along.x if absf(along.x) > 0.5 else (float(o[0]) - start.z) * along.z
				if absf(pu - ou) < float(o[1]) * 0.5 + 0.35 and py > float(o[2]) - 0.3 and py < float(o[3]) + 0.3:
					clear = false
			if not clear:
				continue
			var turn := Basis(along, inward, along.cross(inward)).orthonormalized()
			for j in _wear.randi_range(2, 5):
				var r := _wear.randf_range(0.06, 0.18)
				var spot: Vector3 = at.call(pu + _wear.randf_range(-0.15, 0.15), py + _wear.randf_range(-0.12, 0.12), 0.014)
				_in.ball(r, 16, CozyMesh.at(spot, turn * Basis.from_scale(Vector3(1.0, 1.0, _wear.randf_range(0.5, 0.9)))), LIME.lerp(Color(0.66, 0.6, 0.5), _wear.randf_range(0.45, 0.8)), false, 0.004)
			# Its flakes fallen below.
			for j in 6:
				var chip: Vector3 = at.call(pu + _wear.randf_range(-0.3, 0.3), FLOOR + 0.005, _wear.randf_range(0.04, 0.35))
				_in.box(Vector3(0.04, 0.004, 0.03) * _wear.randf_range(0.6, 1.6), CozyMesh.at(chip, Basis(Vector3.UP, _wear.randf() * TAU)), LIME.darkened(_wear.randf() * 0.1))
		# A crack or two, wandering down from the wall's head.
		for k in 2:
			var cu := _wear.randf_range(0.5, width - 0.5)
			var cy := EAVE + _wear.randf_range(-0.2, 0.3)
			for j in _wear.randi_range(5, 9):
				var nu := cu + _wear.randf_range(-0.12, 0.12)
				var ny := cy - _wear.randf_range(0.1, 0.22)
				_in.rod(at.call(cu, cy, 0.016), at.call(nu, ny, 0.016), 0.004, 3, Color(0.3, 0.28, 0.25))
				cu = nu
				cy = ny
	# The water's tracks down the back wall under the hole in the roof.
	var hole_x := (float(HOLE[0]) + float(HOLE[1])) * 0.5
	for k in 4:
		var x := hole_x + _wear.randf_range(-0.6, 0.6)
		var l := _wear.randf_range(1.2, 2.6)
		var w := _wear.randf_range(0.08, 0.2)
		for j in 3:
			var f := j / 3.0
			var lj := l * (1.0 - f * 0.4)
			_in.box(Vector3(w * (1.0 - f * 0.5), lj, 0.004), CozyMesh.at(Vector3(x, EAVE + 0.4 - lj * 0.5, -z_in + 0.017 + j * 0.002)), LIME.lerp(Color(0.6, 0.5, 0.36), 0.25 + f * 0.2))
	# Cobwebs: grey sheets slung across the corners under the roof and
	# in the windows' reveals.
	for corner: Vector3 in [Vector3(-x_in, EAVE + 0.6, -z_in), Vector3(-x_in, EAVE + 0.6, z_in), Vector3(x_in, EAVE + 0.6, -z_in), Vector3(x_in, EAVE + 0.6, z_in)]:
		_web(corner + Vector3(-signf(corner.x), 0, -signf(corner.z)) * 0.02, Vector3(-signf(corner.x), 0, 0), Vector3(0, 0, -signf(corner.z)), Vector3.DOWN, 0.55)
	for bx: float in [-4.0, 4.9]:
		_web(Vector3(bx + 0.11, EAVE + 0.22, _wear.randf_range(-1.5, 1.5)), Vector3.RIGHT, Vector3.BACK, Vector3.DOWN, 0.35)
	for face: Array in [[SOUTH_OPEN, z_in, -1.0], [NORTH_OPEN, -z_in, 1.0]]:
		for o: Array in face[0]:
			if float(o[2]) <= 0.0:
				continue
			var top := Vector3(float(o[0]) - float(o[1]) * 0.5 + 0.01, float(o[3]) - 0.01, float(face[1]) + float(face[2]) * 0.03)
			_web(top, Vector3.RIGHT, Vector3.DOWN, Vector3(0, 0, float(face[2])), 0.22)
	# Leaves blown in under the door and drifted into the corner by it.
	_leaves(Vector3(DOOR_X, FLOOR, z_in - 0.4), 0.6, 40)
	_leaves(Vector3(-x_in + 0.4, FLOOR, z_in - 0.4), 0.4, 25)


## A cobweb in a corner at `at`: threads out along `u` and `v` and the
## way between them, crossed by sagging rings of thread, `size` out;
## `_normal` the side it faces.
func _web(at: Vector3, u: Vector3, v: Vector3, _normal: Vector3, size: float) -> void:
	var thread := Color(0.82, 0.82, 0.8)
	var spokes: Array[Vector3] = []
	for k in 5:
		var f := k / 4.0
		spokes.append((u * (1.0 - f) + v * f).normalized() * size * _wear.randf_range(0.8, 1.0))
	for sp in spokes:
		_in.rod(at, at + sp, 0.0015, 3, thread)
	for ring in 4:
		var r := (ring + 1) / 5.0
		for k in 4:
			var a := at + spokes[k] * r
			var b := at + spokes[k + 1] * r
			var sag := (a + b) * 0.5 - (a + b - at * 2.0).normalized() * 0.015 * r
			_in.rod(a, sag, 0.0012, 3, thread)
			_in.rod(sag, b, 0.0012, 3, thread)


## The alchemist's belongings, left as they were: a dresser of crockery,
## some of it fallen and broken; herbs hung to dry from the living end's
## tie beam, long since dust; a woodpile gone soft by the hearth; a cloak
## mouldering on its peg by the door; a candlestick on the table; at the
## workshop end, bellows and tongs by the furnace, a bin of charcoal, an
## armillary sphere of brass rings on a stand, a chart of the sun's and
## moon's circles pinned to the front wall, a candle-end on the desk; a
## bird's nest on the middle tie beam.
func _furnishings() -> void:
	var x_in := LEN * 0.5 - T
	var z_in := DEP * 0.5 - T
	var wood := Color(0.46, 0.33, 0.22)
	var brass := Color(0.62, 0.5, 0.28)
	var crock := Color(0.82, 0.78, 0.68)
	# The dresser against the back wall in the middle of the room.
	var d := Vector3(-0.85, FLOOR, -z_in + 0.25)
	_in.box(Vector3(1.3, 0.85, 0.5), CozyMesh.at(d + Vector3(0, 0.425, 0)), wood.darkened(0.1))
	_in.box(Vector3(1.36, 0.05, 0.55), CozyMesh.at(d + Vector3(0, 0.875, 0.02)), wood)
	_in.box(Vector3(1.3, 1.0, 0.04), CozyMesh.at(d + Vector3(0, 1.4, -0.23)), wood.darkened(0.15))
	for y: float in [1.2, 1.55, 1.88]:
		_in.box(Vector3(1.3, 0.03, 0.2), CozyMesh.at(d + Vector3(0, y, -0.13)), wood)
	for side: float in [-1.0, 1.0]:
		_in.box(Vector3(0.04, 1.0, 0.24), CozyMesh.at(d + Vector3(side * 0.63, 1.4, -0.12)), wood)
	# One cupboard door hanging open on a broken hinge.
	_in.box(Vector3(0.6, 0.7, 0.03), CozyMesh.at(d + Vector3(-0.85, 0.38, 0.32), Basis(Vector3.UP, -1.1) * Basis(Vector3.BACK, 0.08)), wood.darkened(0.05))
	_solid(Vector3(1.3, 0.9, 0.5), d + Vector3(0, 0.45, 0))
	for k in 5:
		if k == 2:
			continue
		_in.cyl(0.11, 0.11, 0.012, 14, CozyMesh.at(d + Vector3(-0.5 + k * 0.25, 1.33, -0.17), Basis(Vector3.RIGHT, PI * 0.5 - 0.2)), crock.darkened(_wear.randf() * 0.1))
	for k in 3:
		_in.cyl(0.05, 0.06, 0.16, 10, CozyMesh.at(d + Vector3(-0.4 + k * 0.4, 1.65, -0.12)), crock.darkened(0.1 + _wear.randf() * 0.1))
	# A plate and a jug fallen and broken on the floor before it.
	for k in 7:
		_in.box(Vector3(0.06, 0.008, 0.05) * _wear.randf_range(0.6, 1.5), CozyMesh.at(d + Vector3(_wear.randf_range(-0.5, 0.4), 0.006, 0.45 + _wear.randf_range(0.0, 0.35)), Basis(Vector3.UP, _wear.randf() * TAU)), crock)
	_in.cyl(0.05, 0.06, 0.12, 10, CozyMesh.at(d + Vector3(0.3, 0.06, 0.6), Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.UP, 0.7)), crock.darkened(0.15))
	# Herbs hung to dry from the living end's tie beam.
	for k in 6:
		var at := Vector3(-4.0, EAVE + 0.22, -1.6 + k * 0.55 + _wear.randf_range(-0.1, 0.1))
		var drop := _wear.randf_range(0.3, 0.55)
		_in.rod(at, at - Vector3(0, drop, 0), 0.004, 3, Color(0.5, 0.42, 0.3))
		var hang := at - Vector3(0, drop, 0)
		var dried := Color(0.72, 0.68, 0.5).lerp(Color(0.6, 0.56, 0.36), _wear.randf())
		_in.cyl(0.012, 0.012, 0.04, 5, CozyMesh.at(hang - Vector3(0, 0.02, 0)), Color(0.5, 0.42, 0.3))
		for j in 7:
			var a := TAU * j / 7.0 + _wear.randf_range(-0.3, 0.3)
			var tip := hang + Vector3(cos(a) * 0.07, -_wear.randf_range(0.22, 0.32), sin(a) * 0.07)
			_in.rod(hang - Vector3(0, 0.03, 0), tip, 0.006, 3, dried.darkened(0.2))
			_in.ball(0.03, 5, CozyMesh.at(tip + Vector3(0, 0.04, 0), Basis.from_scale(Vector3(0.7, 1.4, 0.7))), dried)
	# The woodpile by the hearth, its logs gone soft and grey.
	for k in 9:
		var row := k / 4
		var at := Vector3(-x_in + 0.25, FLOOR + 0.07 + row * 0.12, 1.25 + (k % 4) * 0.13 + row * 0.06)
		_in.cyl(0.06, 0.06, 0.45, 7, CozyMesh.at(at, Basis(Vector3.BACK, PI * 0.5)), Color(0.42, 0.38, 0.32).darkened(_wear.randf() * 0.2))
	# A cloak mouldering on its peg west of the door.
	var peg := Vector3(DOOR_X - 0.95, 1.75, z_in - 0.06)
	_in.rod(peg + Vector3(0, 0, 0.06), peg, 0.015, 5, wood.darkened(0.2))
	var wool := Color(0.5, 0.44, 0.34)
	_in.cyl(0.08, 0.24, 1.15, 12, CozyMesh.at(peg + Vector3(0, -0.6, -0.08), Basis.from_scale(Vector3(1.0, 1.0, 0.45))), wool)
	for j in 4:
		_in.cyl(0.015, 0.03, 1.0, 5, CozyMesh.at(peg + Vector3(-0.15 + j * 0.1, -0.65, -0.14)), wool.darkened(0.15))
	_in.ball(0.1, 8, CozyMesh.at(peg + Vector3(0, -0.02, -0.08), Basis.from_scale(Vector3(1.0, 0.6, 0.6))), wool.darkened(0.08))
	# A candlestick on the table, its candle burned down.
	var stick := Vector3(-3.3, FLOOR + 0.74, 0.3)
	_in.cyl(0.05, 0.06, 0.02, 10, CozyMesh.at(stick + Vector3(0, 0.01, 0)), brass)
	_in.cyl(0.012, 0.015, 0.12, 6, CozyMesh.at(stick + Vector3(0, 0.08, 0)), brass)
	_in.cyl(0.018, 0.018, 0.04, 6, CozyMesh.at(stick + Vector3(0, 0.16, 0)), Color(0.86, 0.82, 0.66))
	# At the furnace: bellows on the floor, tongs leaned on it, a bin of
	# charcoal.
	var furnace := Vector3(x_in - 0.55, FLOOR, -1.2)
	var bellows := furnace + Vector3(-0.85, 0.05, 0.55)
	var lean := Basis(Vector3.UP, 0.6)
	_in.box(Vector3(0.35, 0.05, 0.25), CozyMesh.at(bellows, lean), wood)
	_in.box(Vector3(0.3, 0.06, 0.22), CozyMesh.at(bellows + Vector3(0, 0.06, 0), lean), Color(0.36, 0.26, 0.18))
	_in.rod(bellows + lean * Vector3(0.17, 0.03, 0), bellows + lean * Vector3(0.38, 0.03, 0), 0.015, 5, brass.darkened(0.3))
	for side: float in [-1.0, 1.0]:
		_in.rod(furnace + Vector3(-0.45, 0.02, 0.55 + side * 0.02), furnace + Vector3(-0.42, 0.85, 0.38), 0.01, 4, Color(0.18, 0.17, 0.16))
	var bin := furnace + Vector3(0.0, 0.0, 0.85)
	_in.box(Vector3(0.45, 0.4, 0.4), CozyMesh.at(bin + Vector3(0, 0.2, 0)), wood.darkened(0.25))
	for k in 12:
		_in.ball(_wear.randf_range(0.03, 0.06), 5, CozyMesh.at(bin + Vector3(_wear.randf_range(-0.17, 0.17), 0.4 + _wear.randf_range(0.0, 0.05), _wear.randf_range(-0.15, 0.15))), Color(0.12, 0.11, 0.11))
	_solid(Vector3(0.45, 0.4, 0.4), bin + Vector3(0, 0.2, 0))
	# The armillary sphere: brass rings round a small ball, on a turned
	# stand, near the front wall.
	var arm := Vector3(-0.15, FLOOR, z_in - 0.45)
	_in.cyl(0.18, 0.22, 0.05, 12, CozyMesh.at(arm + Vector3(0, 0.025, 0)), wood.darkened(0.1))
	_in.cyl(0.03, 0.04, 0.9, 8, CozyMesh.at(arm + Vector3(0, 0.47, 0)), wood)
	var c := arm + Vector3(0, 1.15, 0)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(44.0))
	_in.torus(0.2, 0.215, 24, 4, CozyMesh.at(c, Basis(Vector3.BACK, PI * 0.5)), brass)
	_in.torus(0.2, 0.215, 24, 4, CozyMesh.at(c, tilt * Basis(Vector3.RIGHT, PI * 0.5)), brass)
	_in.torus(0.2, 0.215, 24, 4, CozyMesh.at(c, tilt), brass.lightened(0.1))
	_in.torus(0.19, 0.205, 24, 4, CozyMesh.at(c, tilt * Basis(Vector3.BACK, 0.41)), brass.darkened(0.1))
	_in.rod(c - tilt.y * 0.26, c + tilt.y * 0.26, 0.006, 4, brass.darkened(0.2))
	_in.ball(0.045, 10, CozyMesh.at(c), Color(0.4, 0.46, 0.5))
	_in.box(Vector3(0.05, 0.25, 0.04), CozyMesh.at(arm + Vector3(0, 0.98, 0)), wood)
	_solid(Vector3(0.36, 1.4, 0.36), arm + Vector3(0, 0.7, 0))
	# The chart on the front wall between the workshop's windows: a sheet
	# gone brown at its edges, the sun's circle and the moon's drawn on it,
	# one corner come away.
	var chart := Vector3(2.6, 1.55, z_in - 0.02)
	_in.box(Vector3(0.7, 0.55, 0.005), CozyMesh.at(chart), Color(0.78, 0.72, 0.56))
	_in.box(Vector3(0.74, 0.59, 0.003), CozyMesh.at(chart + Vector3(0, 0, 0.003)), Color(0.58, 0.5, 0.36))
	var ink := Color(0.25, 0.2, 0.16)
	var face_on := Basis(Vector3.RIGHT, PI * 0.5)
	_in.torus(0.2, 0.208, 32, 3, CozyMesh.at(chart + Vector3(0, 0, -0.004), face_on), ink)
	_in.torus(0.12, 0.127, 24, 3, CozyMesh.at(chart + Vector3(0.07, 0.02, -0.004), face_on * Basis(Vector3.UP, 0.4)), ink)
	_in.ball(0.025, 8, CozyMesh.at(chart + Vector3(0, 0, -0.004)), Color(0.7, 0.5, 0.2))
	_in.ball(0.016, 6, CozyMesh.at(chart + Vector3(0.19, 0.02, -0.004)), Color(0.4, 0.4, 0.42))
	_in.box(Vector3(0.16, 0.13, 0.004), CozyMesh.at(chart + Vector3(0.29, -0.23, -0.03), Basis(Vector3.RIGHT, -0.5)), Color(0.74, 0.68, 0.52))
	for corner: Vector2 in [Vector2(-0.33, 0.25), Vector2(0.33, 0.25), Vector2(-0.33, -0.25)]:
		_in.ball(0.01, 5, CozyMesh.at(chart + Vector3(corner.x, corner.y, -0.006)), Color(0.3, 0.3, 0.3))
	# A candle-end on the desk.
	var desk := Vector3(4.6, FLOOR, z_in - 0.35)
	_in.cyl(0.035, 0.04, 0.015, 8, CozyMesh.at(desk + Vector3(0.48, 0.77, -0.15)), brass)
	_in.cyl(0.016, 0.016, 0.03, 6, CozyMesh.at(desk + Vector3(0.48, 0.79, -0.15)), Color(0.86, 0.82, 0.66))
	# A bird's nest on the middle tie beam, droppings under it.
	var nest := Vector3(0.2, EAVE + 0.5, 1.6)
	_in.torus(0.06, 0.13, 12, 6, CozyMesh.at(nest, Basis.from_scale(Vector3(1.0, 0.6, 1.0))), Color(0.45, 0.36, 0.24))
	for k in 10:
		_in.ball(0.008, 4, CozyMesh.at(Vector3(0.2 + _wear.randf_range(-0.25, 0.25), FLOOR + 0.003, 1.6 + _wear.randf_range(-0.25, 0.25))), Color(0.88, 0.88, 0.84))


## ---- the room ------------------------------------------------------------------

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
	# at its foot; pewter on a shelf on the front wall.
	var bed := Vector3(-2.55, FLOOR, -2.2)
	_in.box(Vector3(1.75, 0.45, 1.0), CozyMesh.at(bed + Vector3(0, 0.225, 0)), wood.darkened(0.1))
	# The bedding mouldered under two centuries of the roof's drips.
	_in.box(Vector3(1.65, 0.12, 0.9), CozyMesh.at(bed + Vector3(0, 0.5, 0)), Color(0.46, 0.44, 0.34))
	_in.box(Vector3(0.5, 0.1, 0.35), CozyMesh.at(bed + Vector3(-0.5, 0.6, 0)), Color(0.5, 0.48, 0.38))
	for k in 5:
		_in.box(Vector3(_wear.randf_range(0.15, 0.35), 0.005, _wear.randf_range(0.1, 0.3)), CozyMesh.at(bed + Vector3(_wear.randf_range(-0.6, 0.6), 0.563, _wear.randf_range(-0.3, 0.3))), Color(0.3, 0.34, 0.24))
	_under_hole()
	for end: float in [-1.0, 1.0]:
		_in.box(Vector3(0.06, 0.95 if end < 0.0 else 0.7, 1.0), CozyMesh.at(bed + Vector3(end * 0.9, 0.475 if end < 0.0 else 0.35, 0)), wood.darkened(0.15))
	_solid(Vector3(1.75, 0.6, 1.0), bed + Vector3(0, 0.3, 0))
	_in.box(Vector3(0.9, 0.5, 0.5), CozyMesh.at(Vector3(-4.5, FLOOR + 0.25, -2.35)), wood.darkened(0.2))
	_solid(Vector3(0.9, 0.5, 0.5), Vector3(-4.5, FLOOR + 0.25, -2.35))
	var front := DEP * 0.5 - T
	_in.box(Vector3(1.4, 0.04, 0.22), CozyMesh.at(Vector3(-1.05, 1.75, front - 0.11)), wood)
	for k in 4:
		_in.cyl(0.13, 0.13, 0.015, 14, CozyMesh.at(Vector3(-1.53 + k * 0.32, 1.9, front - 0.05), Basis(Vector3.RIGHT, -(PI * 0.5 - 0.15))), Color(0.62, 0.62, 0.6))


## Under the hole in the roof: two centuries of rain and leaves come in.
## A dark wet stain on the flags and a green skin of moss in its middle,
## slates and a rotted board fallen through, leaf litter drifted.
func _under_hole() -> void:
	var mid_t := (HOLE[2] + HOLE[3]) * 0.5
	var over := _under(-1.0, (HOLE[0] + HOLE[1]) * 0.5, mid_t)
	var at := Vector3(over.x, FLOOR, over.z)
	_in.cyl(0.75, 0.8, 0.004, 14, CozyMesh.at(at + Vector3(0, 0.002, 0), Basis.from_scale(Vector3(1.0, 1.0, 0.7))), Color(0.26, 0.25, 0.22))
	for k in 9:
		var off := Vector3(_wear.randf_range(-0.45, 0.45), 0.006, _wear.randf_range(-0.3, 0.3))
		_in.ball(_wear.randf_range(0.08, 0.18), 7, CozyMesh.at(at + off, Basis.from_scale(Vector3(1.0, 0.18, 1.0))), Color(0.3, 0.42, 0.2).darkened(_wear.randf() * 0.2), true)
	for k in 4:
		var b := Basis(Vector3.UP, _wear.randf() * TAU) * Basis(Vector3.RIGHT, _wear.randf_range(-0.2, 0.2))
		_in.box(Vector3(0.28, 0.02, 0.4) * _wear.randf_range(0.5, 1.0), CozyMesh.at(at + Vector3(_wear.randf_range(-0.6, 0.6), 0.03, _wear.randf_range(-0.4, 0.4)), b), SLATE.lightened(0.05))
	_in.box(Vector3(0.9, 0.025, 0.14), CozyMesh.at(at + Vector3(0.3, 0.05, 0.35), Basis(Vector3.UP, 0.5) * Basis(Vector3.BACK, 0.06)), Color(0.32, 0.25, 0.18))
	_leaves(at, 0.9, 50)


## Dead leaves drifted round `at`, `count` of them within `reach`.
func _leaves(at: Vector3, reach: float, count: int) -> void:
	for k in count:
		var r := sqrt(_wear.randf()) * reach
		var a := _wear.randf() * TAU
		var colour := [Color(0.55, 0.36, 0.18), Color(0.45, 0.3, 0.16), Color(0.62, 0.5, 0.26), Color(0.35, 0.26, 0.16)][_wear.randi() % 4] as Color
		_in.box(Vector3(0.05, 0.004, 0.08), CozyMesh.at(at + Vector3(cos(a) * r, 0.008 + _wear.randf() * 0.01, sin(a) * r), Basis(Vector3.UP, _wear.randf() * TAU) * Basis(Vector3.RIGHT, _wear.randf_range(-0.3, 0.3))), colour)


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
	for k in 9:
		_in.torus(0.445, 0.462, 18, 3, CozyMesh.at(furnace + Vector3(0, 0.36 + k * 0.13, 0)), brick.darkened(0.3))
	_in.box(Vector3(0.03, 0.38, 0.33), CozyMesh.at(furnace + Vector3(-0.47, 0.62, 0)), Color(0.2, 0.18, 0.17))
	_in.rod(furnace + Vector3(-0.5, 0.62, 0.08), furnace + Vector3(-0.56, 0.62, 0.08), 0.012, 4, Color(0.2, 0.18, 0.17))
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
	for span: Vector2 in [Vector2(0.2, 1.85), Vector2(3.9, 5.5)]:
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
	var scales := top + Vector3(0.65, 0, 0)
	_in.cyl(0.08, 0.1, 0.03, 12, CozyMesh.at(scales + Vector3(0, 0.015, 0)), brass)
	_in.cyl(0.012, 0.012, 0.42, 6, CozyMesh.at(scales + Vector3(0, 0.22, 0)), brass)
	_in.box(Vector3(0.5, 0.015, 0.015), CozyMesh.at(scales + Vector3(0, 0.43, 0), Basis(Vector3.BACK, 0.06)), brass)
	for s: float in [-1.0, 1.0]:
		var hang := scales + Vector3(s * 0.24, 0.43 - s * 0.015, 0)
		_in.rod(hang, hang + Vector3(0, -0.25, 0), 0.003, 4, brass)
		_in.cyl(0.08, 0.06, 0.02, 12, CozyMesh.at(hang + Vector3(0, -0.26, 0)), brass)
	# A mortar and pestle, books, and a flask fallen and broken.
	_in.cyl(0.08, 0.06, 0.1, 10, CozyMesh.at(top + Vector3(-0.9, 0.05, 0.1)), Color(0.55, 0.53, 0.5))
	_in.rod(top + Vector3(-0.9, 0.06, 0.1), top + Vector3(-0.82, 0.22, 0.04), 0.015, 6, Color(0.55, 0.53, 0.5))
	for k in 3:
		_in.box(Vector3(0.3, 0.05, 0.22), CozyMesh.at(top + Vector3(1.0, 0.025 + k * 0.05, 0.05), Basis(Vector3.UP, k * 0.2)), [Color(0.4, 0.2, 0.15), Color(0.3, 0.26, 0.2), Color(0.25, 0.3, 0.22)][k])
	_in.ball(0.08, 10, CozyMesh.at(top + Vector3(1.7, 0.07, 0.15), Basis(Vector3.BACK, 1.3)), glassware, true)
	for k in 6:
		_in.box(Vector3(0.04, 0.004, 0.03), CozyMesh.at(top + Vector3(1.85 + _rng.randf_range(-0.12, 0.12), 0.003, 0.15 + _rng.randf_range(-0.1, 0.1)), Basis(Vector3.UP, _rng.randf() * TAU)), glassware)
	_note(bench + Vector3(0, 0.5, 0), Vector3(5.2, 1.0, 0.66),
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


## The stand of controls' line along z: the table's north edge less
## STAND_GAP.
func _stand_z() -> float:
	var b := _lens_basis()
	var spot := _lens_at() - b.y * ((_lens_at().y - (FLOOR + CrystalTable.TABLE_TOP)) / b.y.y)
	return spot.z - CrystalTable.TABLE.y * 0.5 - STAND_GAP


## The lens's middle, in the north slope near the roof's outer face.
func _lens_at() -> Vector3:
	return _under(-1.0, GLASS_X, absf(GLASS_Z) / _cos) + Vector3(0, ROOF_T / _cos * 0.8, 0)


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
	# Where the lens's light lands, down the axis: the table; north of it
	# the stand of controls, the curtains' cord drums at its ends.
	var b := _lens_basis()
	var spot := _lens_at() - b.y * ((_lens_at().y - (FLOOR + CrystalTable.TABLE_TOP)) / b.y.y)
	var stand_z := _stand_z()
	var ends: Array[Vector3] = []
	for x: float in [-0.8, -0.6, 0.6, 0.8]:
		ends.append(Vector3(GLASS_X + x, FLOOR + STAND_H + 0.1, stand_z))
	glass = BurningGlass.new({"wood": inside, "cloth": cloth}, ends)
	var lens_at := _lens_at()
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
	heliostat.wall_in = (-DEP * 0.5 + T) - mirror_at.z
	heliostat.wall_out = -DEP * 0.5 - mirror_at.z
	heliostat.crank_out = (_stand_z() + 0.04) - (-DEP * 0.5 + T)
	add_child(heliostat)
	table = CrystalTable.new(inside, glass)
	table.position = Vector3(spot.x, FLOOR, spot.z)
	add_child(table)
	_stand(inside, stand_z)


## The stand of controls at the table's north edge, in reach of a player
## at the table: a beam on two posts carrying the heliostat's two cranks
## (their shafts run back to the wall over the bench) and, on blocks at
## its ends, the four curtains' cord drums.
func _stand(inside: Material, z: float) -> void:
	var m := CozyMesh.new()
	var y := FLOOR + Heliostat.CRANK_Y
	for x: float in [-1.0, 1.0]:
		m.box(Vector3(0.1, y + 0.06, 0.1), CozyMesh.at(Vector3(GLASS_X + x, (y + 0.06) * 0.5, z)), OAK)
		m.box(Vector3(0.3, 0.06, 0.4), CozyMesh.at(Vector3(GLASS_X + x, FLOOR + 0.03, z)), OAK.darkened(0.15))
		_solid(Vector3(0.1, y, 0.1), Vector3(GLASS_X + x, y * 0.5, z))
		# The drums' blocks and their axles' brackets.
		m.box(Vector3(0.5, STAND_H - Heliostat.CRANK_Y, 0.12), CozyMesh.at(Vector3(GLASS_X + x * 0.7, FLOOR + (STAND_H + Heliostat.CRANK_Y) * 0.5, z)), OAK)
		for dx: float in [-0.27, -0.07, 0.07, 0.27]:
			m.box(Vector3(0.02, 0.12, 0.05), CozyMesh.at(Vector3(GLASS_X + x * 0.7 + dx * (1.0 if x > 0 else -1.0), FLOOR + STAND_H + 0.06, z)), OAK.darkened(0.2))
	m.box(Vector3(2.1, 0.12, 0.08), CozyMesh.at(Vector3(GLASS_X, y, z)), OAK)
	var view := MeshInstance3D.new()
	view.mesh = m.commit(inside)
	add_child(view)
