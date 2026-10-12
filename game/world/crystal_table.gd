class_name CrystalTable
extends Node3D
## A table with one or two spinstone crystals lying loose in a shallow
## brass dish on it (TableCrystal, each with its own kind, size and
## shape), to see what light does to a crystal of a given size that
## nothing holds, and to two together. The table gives them their light
## (`light_at`, from a BurningGlass over it), the sun's direction and the
## sound settings. The dish, a spherical bowl DISH across and DEEP deep,
## keeps a crystal that heaves or skates in the light rolling back to its
## middle, where the glass's spot falls at noon.
##
## A crystal's size runs from a twentieth of a whole stone's volume (a
## whole stone is the gimbal stones' crystal) to five times a whole
## stone's length. Larger, the light's twist grows as its surface and its
## weight's hold as its volume times its size, so a small crystal stands
## up and spins where a large one only rocks or lies still.
##
## Built in its own frame: the floor under the table's middle at the
## origin, the table's length along x.

const SMALLEST := 0.368                 # the smallest's length, as a share of a whole stone's: a twentieth of its volume
const LARGEST := 5.0
const TABLE_TOP := 0.8
const TABLE := Vector2(2.4, 1.2)
const DISH := 0.4                       # m: the dish across, inside
const DEEP := 0.05                      # m

## Toward the sun, set by the world.
var to_sun := Vector3.UP
## Where the light comes from.
var glass: BurningGlass
## The crystals' knocks and scrapes heard, each; how much lower a larger
## stone sounds (TableCrystal._pitch).
var knocks_heard := true
var scrape_heard := true
var pitch_drop := 0.7
## The crystals: the first, and the second, on the table when chosen.
var crystals: Array[TableCrystal] = []

var _mat: Material


## `mat`: the table's material (vertex coloured).
func _init(mat: Material, lens: BurningGlass) -> void:
	name = "CrystalTable"
	_mat = mat
	glass = lens


func _ready() -> void:
	_build()
	# Both in the dish, a little apart.
	for k in 2:
		var c := TableCrystal.new(self, 7 + k * 31, Vector3(-0.06 if k == 0 else 0.06, 0, 0))
		c.visible = k == 0
		# The second an earthstone to begin, as its panel row says.
		c.kind = "sun" if k == 0 else "earth"
		crystals.append(c)
		add_child(c)


## The light, W/m², at `at` (global).
func light_at(at: Vector3) -> float:
	return glass.irradiance(at) if glass != null else 0.0


## Lines for the panel, one for each crystal on the table.
func report() -> String:
	var lines: Array[String] = []
	for k in crystals.size():
		if crystals[k].visible:
			lines.append("%s: %s" % ["First" if k == 0 else "Second", crystals[k].report()])
	return "\n".join(lines)


func _build() -> void:
	var m := CozyMesh.new()
	var body := StaticBody3D.new()
	add_child(body)
	var solid := func(extent: Vector3, at: Vector3) -> void:
		var shape := BoxShape3D.new()
		shape.size = extent
		var c := CollisionShape3D.new()
		c.shape = shape
		c.position = at
		body.add_child(c)
	var top_wood := Color(0.55, 0.42, 0.3)
	var dark := Color(0.36, 0.27, 0.2)
	# The top, a lip round it to keep the crystals on it, and turned legs
	# with stretchers low between them.
	var top := Vector3(0, TABLE_TOP - 0.03, 0)
	m.box(Vector3(TABLE.x, 0.06, TABLE.y), CozyMesh.at(top), top_wood)
	solid.call(Vector3(TABLE.x, 0.06, TABLE.y), top)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var leg := Vector3(sx * (TABLE.x * 0.5 - 0.1), 0, sz * (TABLE.y * 0.5 - 0.1))
			m.cyl(0.04, 0.045, TABLE_TOP - 0.06, 8, CozyMesh.at(leg + Vector3(0, (TABLE_TOP - 0.06) * 0.5, 0)), dark)
			m.ball(0.055, 8, CozyMesh.at(leg + Vector3(0, TABLE_TOP * 0.45, 0)), dark)
		m.box(Vector3(TABLE.x - 0.2, 0.05, 0.05), CozyMesh.at(Vector3(0, 0.15, sx * (TABLE.y * 0.5 - 0.1))), dark)
		var lip := Vector3(sx * (TABLE.x * 0.5 - 0.02), TABLE_TOP + 0.06, 0)
		m.box(Vector3(0.04, 0.12, TABLE.y), CozyMesh.at(lip), dark)
		solid.call(Vector3(0.04, 0.12, TABLE.y), lip)
		var lip_z := Vector3(0, TABLE_TOP + 0.06, sx * (TABLE.y * 0.5 - 0.02))
		m.box(Vector3(TABLE.x, 0.12, 0.04), CozyMesh.at(lip_z), dark)
		solid.call(Vector3(TABLE.x, 0.12, 0.04), lip_z)
	_dish(m)
	var view := MeshInstance3D.new()
	view.mesh = m.commit(_mat)
	add_child(view)
	# Its card on its own layer, met by the crosshair, out of the light's way.
	var note := HoverNote.new(Vector3(0, TABLE_TOP * 0.5, 0), Vector3(TABLE.x, TABLE_TOP, TABLE.y),
			"Table under the burning glass\nSpinstones lying loose where the glass's spot crosses the table toward noon.")
	note.collision_layer = 4
	add_child(note)


## The dish: a spherical bowl of beaten brass standing on the top, a
## rolled rim round it.
func _dish(m: CozyMesh) -> void:
	var r := DISH * 0.5
	var sphere := (r * r + DEEP * DEEP) / (2.0 * DEEP)
	var floor_y := TABLE_TOP + 0.006
	var centre := Vector3(0, floor_y + sphere, 0)
	var brass := Color(0.74, 0.56, 0.3)
	var rings := 8
	var sides := 28
	var point := func(i: int, j: int) -> Vector3:
		var a := asin(r / sphere) * i / rings
		var b := TAU * j / sides
		return centre + Vector3(sin(a) * cos(b), -cos(a), sin(a) * sin(b)) * sphere
	for i in rings:
		for j in sides:
			var p00: Vector3 = point.call(i, j)
			var p01: Vector3 = point.call(i, j + 1)
			var p10: Vector3 = point.call(i + 1, j)
			var p11: Vector3 = point.call(i + 1, j + 1)
			var n := ((p00 + p11) * 0.5 - centre).normalized()
			m.quad(p00, p10, p11, p01, -n, brass)
	m.torus(r - 0.006, r + 0.012, sides, 6, CozyMesh.at(Vector3(0, TABLE_TOP + DEEP + 0.004, 0)), brass.darkened(0.1))
	m.cyl(r * 0.5, r * 0.55, 0.008, 20, CozyMesh.at(Vector3(0, TABLE_TOP + 0.004, 0)), brass.darkened(0.2))
	# Its solid: a flat round floor and a ring of sloped plates to the
	# rim, shapes the engine settles a crystal on steadily (on the bowl's
	# own triangles it never came to rest).
	var body := StaticBody3D.new()
	var floor_r := r * 0.35
	var base := CylinderShape3D.new()
	base.radius = floor_r
	base.height = 0.02
	var c := CollisionShape3D.new()
	c.shape = base
	c.position = Vector3(0, floor_y - 0.01, 0)
	body.add_child(c)
	var rise := TABLE_TOP + DEEP - floor_y
	var run := r - floor_r
	var tilt := atan2(rise, run)
	var slant := sqrt(rise * rise + run * run)
	for j in 16:
		var b := TAU * j / 16.0
		var out := Vector3(cos(b), 0, sin(b))
		var plate := BoxShape3D.new()
		plate.size = Vector3(slant + 0.02, 0.01, TAU * r / 16.0 + 0.02)
		var pc := CollisionShape3D.new()
		pc.shape = plate
		var frame := Basis(Vector3.UP, -b) * Basis(Vector3.BACK, tilt)
		pc.transform = Transform3D(frame, Vector3(0, floor_y + rise * 0.5, 0) + out * (floor_r + run * 0.5) - frame.y * 0.005)
		body.add_child(pc)
	add_child(body)
