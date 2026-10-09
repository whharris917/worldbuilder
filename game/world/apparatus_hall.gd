class_name ApparatusHall
extends Node3D
## The exposition's second row: a hall of apparatus along a boardwalk
## behind the crystal booths, six booths built as theirs are
## (CrystalExpo._booth), each a working demonstration in brass, copper,
## glass and iron, moved each frame (`_movers`):
## - The Vessel Hall: tiered shelves of glassware in many shapes, round,
##   conical and long-necked flasks, a retort, a pelican, ampoules, square
##   bottles, a carboy, a crucible, holding softly glowing liquids.
## - The Alembic: a still. A copper pot over a glowing brazier, its onion
##   head and swan-neck arm into a cooling coil in a tub, drops falling
##   into a receiving flask that fills and is emptied again.
## - The Pipework: a copper manifold with handwheel valves turning to and
##   fro, gauges whose needles swing, a glass sight tube with slugs of
##   liquid rising through it, a hand pump rocking.
## - The Cauldron: a copper cauldron over a fire, a paddle stirring,
##   bubbles swelling and bursting on its surface.
## - The Clockwork: a train of gears meshing at true ratios on a panel, a
##   pendulum, and a governor whose balls swing out as it spins faster.
## - The Bellows: a forge whose bellows breathe, the coals and the
##   crucible brightening with each breath.
## The booth names and notes are drafts.

const NAMES := ["THE VESSEL HALL", "THE ALEMBIC", "THE PIPEWORK", "THE CAULDRON", "THE CLOCKWORK", "THE BELLOWS"]
const NOTES := [
	"The Vessel Hall\nGlassware for every working: round and conical flasks, a retort, a pelican, ampoules, a carboy and a crucible.",
	"The Alembic\nA still: the pot is heated, the vapour rises into the head, runs down the arm, cools in the coil and drips into the flask.",
	"The Pipework\nCopper pipe, handwheel valves and gauges: a liquid sent where it is wanted, watched through a sight glass.",
	"The Cauldron\nA great copper cauldron over a fire, stirred without rest.",
	"The Clockwork\nGears turning one another at true ratios, a pendulum keeping time, a governor holding the speed steady.",
	"The Bellows\nA forge's bellows: each breath brightens the coals and the crucible on them.",
]

var expo: CrystalExpo
var booths: Array[Node3D] = []
var _movers: Array[Callable] = []
var _t := 0.0
var _stone: StandardMaterial3D
var _ceramic: StandardMaterial3D


func _init(owner_expo: CrystalExpo) -> void:
	name = "ApparatusHall"
	expo = owner_expo


func _ready() -> void:
	_stone = expo.island.surface("rough_rock", 0.6, Color(0.7, 0.68, 0.66), 0.9, Color(0.62, 0.6, 0.62))
	_ceramic = expo.island.surface("", 1.0, Color(0.88, 0.86, 0.82), 0.6, Color(0.96, 0.94, 0.9))
	expo._build_promenade(CrystalExpo.WALK2_IN, CrystalExpo.HALL_SPREAD + 5.0)
	var builders: Array[Callable] = [_vessels, _alembic, _pipework, _cauldron, _clockwork, _bellows]
	for i in builders.size():
		var b := deg_to_rad(CrystalExpo.BEARING - CrystalExpo.HALL_SPREAD + 2.0 * CrystalExpo.HALL_SPREAD * i / (builders.size() - 1))
		var booth := expo._booth(b, 11 + i, CrystalExpo.HALL_IN, NAMES[i], NOTES[i])
		booths.append(booth)
		var show := Node3D.new()
		show.position = Vector3(0, 0, -0.6)
		booth.add_child(show)
		builders[i].call(show)
	expo._build_bunting(booths)


func _process(delta: float) -> void:
	_t += delta
	for m in _movers:
		m.call(_t)


## ---- helpers ----------------------------------------------------------------

## A node that moves, kept out of the island's joining of still pieces.
func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.set_meta(StaticMerge.MOVES, true)
	parent.add_child(n)
	return n


## A liquid of `colour`, glowing softly.
static func _liquid(colour: Color, glow := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour.darkened(0.2)
	m.roughness = 0.12
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = glow
	return m


## A fire's glow, orange.
static func _embers(glow := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.18, 0.05)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.45, 0.12)
	m.emission_energy_multiplier = glow
	return m


func _mesh(mesh: PrimitiveMesh, at: Vector3, mat: Material, parent: Node3D, basis := Basis.IDENTITY) -> MeshInstance3D:
	mesh.material = mat
	var view := expo._put(mesh, at, false, Vector3.ZERO, parent)
	view.basis = basis
	return view


func _sphere(r: float, at: Vector3, mat: Material, parent: Node3D, squash := Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 20
	s.rings = 10
	return _mesh(s, at, mat, parent, Basis.from_scale(squash))


func _cylinder(top: float, bottom: float, h: float, at: Vector3, mat: Material, parent: Node3D, basis := Basis.IDENTITY) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 16
	c.rings = 1
	return _mesh(c, at, mat, parent, basis)


## ---- the vessels --------------------------------------------------------------

func _vessels(show: Node3D) -> void:
	var glass: Material = expo.get("_glass")
	var wood: Material = expo.get("_wood")
	var brass: Material = expo.get("_brass")
	var z := 1.6
	# The shelves: four boards on four posts, velvet behind.
	for x: float in [-1.35, 1.35]:
		for zz: float in [z - 0.2, z + 0.2]:
			expo._box(Vector3(0.06, 2.2, 0.06), Vector3(x, 1.1, zz), wood, false, show)
	expo._box(Vector3(2.7, 2.1, 0.03), Vector3(0, 1.15, z + 0.22), expo.get("_velvet"), false, show)
	for y: float in [0.45, 1.0, 1.55, 2.1]:
		expo._box(Vector3(2.8, 0.04, 0.46), Vector3(0, y, z), wood, true, show)
	var colours := [Color(0.3, 0.9, 0.55), Color(0.95, 0.4, 0.55), Color(0.4, 0.6, 1.0), Color(1.0, 0.78, 0.3),
			Color(0.7, 0.45, 1.0), Color(0.35, 0.95, 0.95), Color(1.0, 0.55, 0.3)]
	var shelf := [
		[0.47, [["round", -1.0], ["cone", -0.55], ["tall", -0.2], ["retort", 0.25], ["bottle", 0.75], ["cone", 1.1]]],
		[1.02, [["ampoules", -0.95], ["pelican", -0.35], ["round", 0.2], ["bottle", 0.6], ["tall", 1.05]]],
		[1.57, [["cone", -1.05], ["round", -0.6], ["crucible", -0.15], ["retort", 0.35], ["tall", 0.8], ["round", 1.1]]],
	]
	var k := 0
	for row: Array in shelf:
		var y: float = row[0]
		for item: Array in row[1]:
			var mat := _liquid(colours[k % colours.size()])
			_vessel(String(item[0]), Vector3(float(item[1]), y + 0.02, z), mat, glass, brass, show)
			var phase := k * 1.7
			_movers.append(func(t: float) -> void: mat.emission_energy_multiplier = 0.45 + 0.25 * sin(t * 0.9 + phase))
			k += 1
	# A carboy in its wicker on the stage floor, and another on the top.
	_vessel("carboy", Vector3(-2.2, 0.0, 0.9), _liquid(Color(0.4, 0.95, 0.6), 0.8), glass, brass, show)
	_vessel("carboy", Vector3(2.2, 0.0, 0.7), _liquid(Color(0.95, 0.6, 0.9), 0.8), glass, brass, show)


## One vessel of `kind` standing at `at`.
func _vessel(kind: String, at: Vector3, liquid: Material, glass: Material, brass: Material, parent: Node3D) -> void:
	var cork := expo.get("_wood") as Material
	match kind:
		"round":
			_sphere(0.11, at + Vector3(0, 0.11, 0), glass, parent)
			_sphere(0.095, at + Vector3(0, 0.08, 0), liquid, parent, Vector3(1, 0.6, 1))
			_cylinder(0.025, 0.03, 0.14, at + Vector3(0, 0.27, 0), glass, parent)
			_cylinder(0.03, 0.025, 0.04, at + Vector3(0, 0.35, 0), cork, parent)
		"cone":
			_cylinder(0.035, 0.11, 0.2, at + Vector3(0, 0.1, 0), glass, parent)
			_cylinder(0.07, 0.105, 0.09, at + Vector3(0, 0.05, 0), liquid, parent)
			_cylinder(0.03, 0.035, 0.08, at + Vector3(0, 0.24, 0), glass, parent)
		"tall":
			_cylinder(0.045, 0.045, 0.34, at + Vector3(0, 0.17, 0), glass, parent)
			_cylinder(0.04, 0.04, 0.2, at + Vector3(0, 0.1, 0), liquid, parent)
			_cylinder(0.07, 0.07, 0.015, at + Vector3(0, 0.008, 0), glass, parent)
		"retort":
			_sphere(0.1, at + Vector3(0, 0.1, 0), glass, parent)
			_sphere(0.085, at + Vector3(0, 0.075, 0), liquid, parent, Vector3(1, 0.6, 1))
			expo._rod(at + Vector3(0, 0.18, 0), at + Vector3(0.28, 0.08, 0), 0.02, glass, 8, parent)
		"pelican":
			_sphere(0.1, at + Vector3(0, 0.1, 0), glass, parent)
			_sphere(0.085, at + Vector3(0, 0.08, 0), liquid, parent, Vector3(1, 0.6, 1))
			_cylinder(0.025, 0.03, 0.2, at + Vector3(0, 0.3, 0), glass, parent)
			for side: float in [-1.0, 1.0]:
				expo._rod(at + Vector3(0, 0.36, 0), at + Vector3(side * 0.16, 0.3, 0), 0.015, glass, 6, parent)
				expo._rod(at + Vector3(side * 0.16, 0.3, 0), at + Vector3(side * 0.09, 0.12, 0), 0.015, glass, 6, parent)
		"ampoules":
			for i in 5:
				var p := at + Vector3(-0.16 + i * 0.08, 0.0, 0)
				_cylinder(0.022, 0.022, 0.12, p + Vector3(0, 0.07, 0), glass, parent)
				_cylinder(0.018, 0.018, 0.07, p + Vector3(0, 0.045, 0), liquid, parent)
				_cylinder(0.004, 0.012, 0.04, p + Vector3(0, 0.15, 0), glass, parent)
			expo._box(Vector3(0.42, 0.03, 0.08), at + Vector3(0, 0.015, 0), brass, false, parent)
		"bottle":
			expo._box(Vector3(0.14, 0.2, 0.14), at + Vector3(0, 0.1, 0), glass, false, parent)
			expo._box(Vector3(0.12, 0.12, 0.12), at + Vector3(0, 0.065, 0), liquid, false, parent)
			_cylinder(0.03, 0.035, 0.05, at + Vector3(0, 0.22, 0), glass, parent)
			_cylinder(0.035, 0.035, 0.03, at + Vector3(0, 0.255, 0), brass, parent)
		"crucible":
			_cylinder(0.09, 0.06, 0.12, at + Vector3(0, 0.06, 0), _ceramic, parent)
			_cylinder(0.075, 0.075, 0.01, at + Vector3(0, 0.11, 0), _embers(1.5), parent)
		"carboy":
			_sphere(0.24, at + Vector3(0, 0.3, 0), glass, parent)
			_sphere(0.21, at + Vector3(0, 0.24, 0), liquid, parent, Vector3(1, 0.7, 1))
			_cylinder(0.05, 0.06, 0.14, at + Vector3(0, 0.58, 0), glass, parent)
			_cylinder(0.25, 0.22, 0.26, at + Vector3(0, 0.13, 0), cork, parent)


## ---- the alembic ----------------------------------------------------------------

func _alembic(show: Node3D) -> void:
	var copper: Material = expo.get("_copper")
	var iron: Material = expo.get("_iron")
	var glass: Material = expo.get("_glass")
	var wood: Material = expo.get("_wood")
	var c := Vector3(-0.9, 0, 0.8)
	# The brazier: an iron bowl on three legs, coals glowing in it.
	_cylinder(0.36, 0.24, 0.2, c + Vector3(0, 0.42, 0), iron, show)
	for k in 3:
		var a := TAU * k / 3.0
		expo._rod(c + Vector3(cos(a) * 0.3, 0.35, sin(a) * 0.3), c + Vector3(cos(a) * 0.36, 0.0, sin(a) * 0.36), 0.025, iron, 6, show)
	var coals := _embers(2.0)
	for k in 7:
		var a := TAU * k / 7.0
		_sphere(0.07, c + Vector3(cos(a) * 0.17, 0.5, sin(a) * 0.17), coals, show)
	_movers.append(func(t: float) -> void: coals.emission_energy_multiplier = 1.8 + 0.5 * sin(t * 7.0) * sin(t * 2.3) + 0.3 * sin(t * 13.0))
	# The pot, its onion head, the swan-neck arm.
	_sphere(0.33, c + Vector3(0, 0.86, 0), copper, show)
	_cylinder(0.1, 0.14, 0.2, c + Vector3(0, 1.2, 0), copper, show)
	_sphere(0.2, c + Vector3(0, 1.4, 0), copper, show, Vector3(1, 0.85, 1))
	_sphere(0.04, c + Vector3(0, 1.6, 0), copper, show)
	var arm_end := Vector3(0.45, 1.05, 0.8)
	expo._rod(c + Vector3(0.15, 1.42, 0), arm_end, 0.03, copper, 8, show)
	# The tub with the coil in it.
	var tub := Vector3(0.6, 0, 0.8)
	_cylinder(0.34, 0.3, 0.8, tub + Vector3(0, 0.4, 0), wood, show)
	_cylinder(0.31, 0.31, 0.01, tub + Vector3(0, 0.77, 0), _liquid(Color(0.4, 0.7, 0.9), 0.2), show)
	for k in 3:
		expo._ring(0.2, 0.225, tub + Vector3(0, 0.84 + k * 0.08, 0), copper, show)
	expo._rod(arm_end, tub + Vector3(-0.2, 0.84 + 0.16, 0), 0.025, copper, 6, show)
	# Out at the foot, over the receiver on its stool.
	var spout := tub + Vector3(0.36, 0.25, 0)
	expo._rod(tub + Vector3(0.3, 0.25, 0), spout + Vector3(0.2, 0, 0), 0.015, copper, 6, show)
	var drip := spout + Vector3(0.2, -0.02, 0)
	var flask := drip + Vector3(0, -0.47, 0)
	expo._box(Vector3(0.3, 0.06, 0.3), Vector3(flask.x, flask.y - 0.15, flask.z), wood, false, show)
	expo._box(Vector3(0.05, flask.y - 0.18, 0.05), Vector3(flask.x, (flask.y - 0.18) * 0.5, flask.z), wood, false, show)
	_sphere(0.12, flask, glass, show)
	_cylinder(0.03, 0.035, 0.12, flask + Vector3(0, 0.16, 0), glass, show)
	var spirit := _liquid(Color(1.0, 0.75, 0.3), 1.0)
	var fill := _pivot(show, flask + Vector3(0, -0.1, 0))
	_sphere(0.1, Vector3(0, 0.08, 0), spirit, fill)
	var drop := _pivot(show, drip)
	_sphere(0.014, Vector3.ZERO, spirit, drop)
	_movers.append(func(t: float) -> void:
		# A drop every 0.9 s, falling under gravity to the flask's neck.
		var f := fmod(t, 0.9)
		var fall := 0.5 * 9.8 * f * f
		drop.visible = fall < 0.3
		drop.position = drip + Vector3(0, -minf(fall, 0.3), 0)
		# Filling over 40 s, then emptied.
		var level := fmod(t, 44.0) / 40.0
		var s := clampf(level, 0.02, 1.0) if level <= 1.0 else maxf(0.02, 1.0 - (level - 1.0) * 10.0)
		fill.scale = Vector3(1.0, s, 1.0))


## ---- the pipework ---------------------------------------------------------------

func _pipework(show: Node3D) -> void:
	var copper: Material = expo.get("_copper")
	var iron: Material = expo.get("_iron")
	var brass: Material = expo.get("_brass")
	var glass: Material = expo.get("_glass")
	var z := 1.5
	for x: float in [-1.6, 1.6]:
		expo._box(Vector3(0.08, 2.4, 0.08), Vector3(x, 1.2, z), iron, true, show)
	var rows := [0.55, 1.2, 1.85]
	for y: float in rows:
		expo._rod(Vector3(-1.6, y, z - 0.1), Vector3(1.6, y, z - 0.1), 0.045, copper, 10, show)
	for x: float in [-1.1, 0.0, 1.1]:
		expo._rod(Vector3(x, 0.55, z - 0.1), Vector3(x, 1.85, z - 0.1), 0.04, copper, 10, show)
		for y: float in rows:
			_sphere(0.065, Vector3(x, y, z - 0.1), copper, show)
	# The tank feeding it.
	var tank := Vector3(-2.35, 0, 1.0)
	_cylinder(0.38, 0.38, 1.4, tank + Vector3(0, 0.7, 0), copper, show)
	_sphere(0.38, tank + Vector3(0, 1.4, 0), copper, show, Vector3(1, 0.45, 1))
	expo._rod(tank + Vector3(0.3, 1.2, 0.2), Vector3(-1.6, 1.2, z - 0.1), 0.045, copper, 10, show)
	# Valves: handwheels turning to and fro.
	var spots := [Vector3(-0.55, 0.55, z - 0.1), Vector3(0.55, 1.2, z - 0.1), Vector3(-0.55, 1.85, z - 0.1)]
	for k in spots.size():
		var at: Vector3 = spots[k]
		_cylinder(0.07, 0.07, 0.16, at, brass, show, Basis(Vector3.RIGHT, PI * 0.5))
		var wheel := _pivot(show, at + Vector3(0, 0, -0.18))
		expo._ring(0.11, 0.13, Vector3.ZERO, iron, wheel, Basis(Vector3.RIGHT, PI * 0.5))
		for s in 3:
			var a := TAU * s / 3.0
			expo._rod(Vector3.ZERO, Vector3(cos(a), sin(a), 0) * 0.12, 0.01, iron, 4, wheel)
		var phase := k * 2.1
		_movers.append(func(t: float) -> void: wheel.rotation.z = 2.5 * sin(t * 0.35 + phase))
	# Gauges on the top pipe.
	for k in 2:
		var at := Vector3(-0.2 + k * 0.6, 2.12, z - 0.1)
		expo._rod(Vector3(at.x, 1.85, at.z), at, 0.015, brass, 6, show)
		var face := at + Vector3(0, 0.13, 0)
		_cylinder(0.12, 0.12, 0.04, face, _ceramic, show, Basis(Vector3.RIGHT, PI * 0.5))
		expo._ring(0.115, 0.135, face + Vector3(0, 0, -0.02), brass, show, Basis(Vector3.RIGHT, PI * 0.5))
		var needle := _pivot(show, face + Vector3(0, 0, -0.03))
		expo._box(Vector3(0.012, 0.1, 0.005), Vector3(0, 0.045, 0), iron, false, needle)
		var rate := 0.6 + k * 0.45
		_movers.append(func(t: float) -> void: needle.rotation.z = -1.2 * sin(t * rate) - 0.4 * sin(t * rate * 2.7))
	# The sight glass between the lower pipes, slugs of liquid rising in it.
	var sight := Vector3(1.1, 0.875, z - 0.1)
	_cylinder(0.055, 0.055, 0.5, Vector3(1.1, 0.875, z - 0.25), glass, show)
	expo._rod(Vector3(1.1, 0.55, z - 0.1), Vector3(1.1, 0.6, z - 0.25), 0.03, copper, 6, show)
	expo._rod(Vector3(1.1, 1.2, z - 0.1), Vector3(1.1, 1.15, z - 0.25), 0.03, copper, 6, show)
	var flow := _liquid(Color(0.3, 0.95, 0.85), 1.2)
	var slugs: Array[Node3D] = []
	for k in 3:
		var slug := _pivot(show, sight)
		_sphere(0.04, Vector3.ZERO, flow, slug, Vector3(1, 1.6, 1))
		slugs.append(slug)
	_movers.append(func(t: float) -> void:
		for k in slugs.size():
			var f := fmod(t * 0.35 + k / 3.0, 1.0)
			slugs[k].position = Vector3(1.1, 0.66 + 0.43 * f, z - 0.25))
	# The hand pump: a column and a rocking lever.
	var pump := Vector3(2.3, 0, 0.6)
	_cylinder(0.09, 0.12, 1.0, pump + Vector3(0, 0.5, 0), iron, show)
	_cylinder(0.05, 0.05, 0.25, pump + Vector3(0.12, 0.85, 0), iron, show, Basis(Vector3.FORWARD, PI * 0.5))
	var lever := _pivot(show, pump + Vector3(0, 1.08, 0))
	expo._rod(Vector3(-0.15, 0, 0), Vector3(0.65, 0, 0), 0.025, iron, 6, lever)
	_sphere(0.04, Vector3(0.66, 0, 0), brass, lever)
	_movers.append(func(t: float) -> void: lever.rotation.z = 0.35 * sin(t * 1.6))


## ---- the cauldron ----------------------------------------------------------------

func _cauldron(show: Node3D) -> void:
	var copper: Material = expo.get("_copper")
	var iron: Material = expo.get("_iron")
	var wood: Material = expo.get("_wood")
	var c := Vector3(0, 0, 0.7)
	var rim := 1.15
	# The fire under it.
	var fire := _embers(2.5)
	for k in 6:
		var a := TAU * k / 6.0
		_cylinder(0.0, 0.08, 0.3, c + Vector3(cos(a) * 0.18, 0.15, sin(a) * 0.18), fire, show)
	_movers.append(func(t: float) -> void: fire.emission_energy_multiplier = 2.2 + 0.8 * sin(t * 9.0) * sin(t * 3.1))
	for k in 3:
		var a := TAU * k / 3.0 + 0.3
		expo._rod(c + Vector3(cos(a) * 0.55, rim - 0.2, sin(a) * 0.55), c + Vector3(cos(a) * 0.75, 0.0, sin(a) * 0.75), 0.04, iron, 6, show)
	# The bowl, its rim, the brew.
	var bowl := SphereMesh.new()
	bowl.radius = 0.62
	bowl.height = 0.62
	bowl.is_hemisphere = true
	bowl.radial_segments = 24
	bowl.rings = 8
	_mesh(bowl, c + Vector3(0, rim, 0), copper, show, Basis(Vector3.RIGHT, PI))
	expo._ring(0.6, 0.66, c + Vector3(0, rim, 0), copper, show)
	expo._cyl(0.62, 0.62, 0.5, c + Vector3(0, rim - 0.3, 0), copper, 24, true, show).visible = false
	var brew := _liquid(Color(0.45, 0.95, 0.4), 0.9)
	_cylinder(0.58, 0.58, 0.02, c + Vector3(0, rim - 0.08, 0), brew, show)
	# The paddle, stirring round.
	var stir := _pivot(show, c + Vector3(0, rim - 0.08, 0))
	expo._rod(Vector3(0.25, -0.3, 0), Vector3(0.55, 1.1, 0.0), 0.03, wood, 8, stir)
	expo._box(Vector3(0.05, 0.3, 0.16), Vector3(0.24, -0.3, 0), wood, false, stir)
	_movers.append(func(t: float) -> void: stir.rotation.y = t * 0.9)
	# Bubbles swelling and bursting.
	for k in 6:
		var bubble := _pivot(show, c + Vector3(cos(k * 2.3) * 0.35, rim - 0.07, sin(k * 2.3) * 0.35))
		_sphere(0.05, Vector3.ZERO, brew, bubble)
		var phase := k * 0.73
		_movers.append(func(t: float) -> void:
			var f := fmod(t * 0.6 + phase, 1.0)
			bubble.scale = Vector3.ONE * maxf(f, 0.01)
			bubble.visible = f < 0.95)
	# A rack of ingredient jars beside it.
	var glass: Material = expo.get("_glass")
	var brass: Material = expo.get("_brass")
	expo._box(Vector3(1.0, 0.05, 0.35), Vector3(1.9, 0.75, 0.9), wood, false, show)
	for x: float in [1.55, 2.25]:
		expo._box(Vector3(0.05, 0.75, 0.3), Vector3(x, 0.375, 0.9), wood, false, show)
	var hues := [Color(0.95, 0.5, 0.3), Color(0.5, 0.5, 1.0), Color(0.9, 0.9, 0.4)]
	for k in 3:
		_vessel("bottle", Vector3(1.6 + k * 0.3, 0.78, 0.9), _liquid(hues[k]), glass, brass, show)


## ---- the clockwork ---------------------------------------------------------------

func _clockwork(show: Node3D) -> void:
	var wood: Material = expo.get("_wood")
	var brass: Material = expo.get("_brass")
	var copper: Material = expo.get("_copper")
	var iron: Material = expo.get("_iron")
	var z := 1.7
	expo._box(Vector3(3.0, 2.3, 0.08), Vector3(0, 1.3, z), wood, true, show)
	# The train: each gear meshes with the last, turning the other way at
	# the inverse ratio of their teeth.
	var m := 0.035                       # tooth size (module), metres
	var train := [[24, -0.25], [12, 0.6], [30, -0.9], [16, 0.3], [20, 1.2]]   # teeth, heading to the next
	var at := Vector2(-1.0, 1.3)
	var theta := 0.0
	var speed := 0.5                     # radians a second, the first gear
	var prev_n := 0
	var prev_r := 0.0
	var prev_heading := 0.0
	for k in train.size():
		var n: int = train[k][0]
		var r := n * m * 0.5
		if k > 0:
			at += Vector2(cos(prev_heading), sin(prev_heading)) * (prev_r + r)
			# Its gap faces the last gear's tooth across the line between them.
			var to_this := prev_heading
			var delta := fposmod(to_this - theta, TAU / prev_n)
			theta = to_this + PI - delta * prev_n / n - PI / n
			speed = -speed * prev_n / n
		var gear := _pivot(show, Vector3(at.x, at.y, z - 0.08))
		gear.add_child(_gear_view(n, m, brass if k % 2 == 0 else copper))
		_cylinder(0.025, 0.025, 0.16, Vector3(at.x, at.y, z - 0.06), iron, show, Basis(Vector3.RIGHT, PI * 0.5))
		var start := theta
		var w := speed
		_movers.append(func(t: float) -> void: gear.rotation.z = start + w * t)
		prev_n = n
		prev_r = r
		prev_heading = float(train[k][1])
	# The pendulum.
	var hang := _pivot(show, Vector3(-1.2, 2.25, z - 0.12))
	expo._rod(Vector3.ZERO, Vector3(0, -1.2, 0), 0.012, brass, 6, hang)
	_cylinder(0.11, 0.11, 0.03, Vector3(0, -1.25, 0), brass, hang, Basis(Vector3.RIGHT, PI * 0.5))
	_movers.append(func(t: float) -> void: hang.rotation.z = 0.28 * sin(t * TAU / 2.2))
	# The governor: a spindle spinning, its balls flung out as it speeds up.
	var gov := Vector3(2.2, 0, 0.7)
	_cylinder(0.18, 0.22, 0.1, gov + Vector3(0, 0.05, 0), iron, show)
	var spin := _pivot(show, gov + Vector3(0, 0, 0))
	_cylinder(0.02, 0.02, 1.5, Vector3(0, 0.8, 0), brass, spin)
	var arms: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		var arm := _pivot(spin, Vector3(0, 1.5, 0))
		expo._rod(Vector3.ZERO, Vector3(0, -0.45, 0), 0.012, brass, 4, arm)
		_sphere(0.07, Vector3(0, -0.47, 0), brass, arm)
		arm.set_meta("side", side)
		arms.append(arm)
	var turned := [0.0]
	_movers.append(func(t: float) -> void:
		# Its speed rises and falls; the balls swing out with it.
		var rate := 3.0 + 2.5 * sin(t * 0.25)
		turned[0] = float(turned[0]) + rate * get_process_delta_time()
		spin.rotation.y = float(turned[0])
		for arm in arms:
			arm.rotation.z = float(arm.get_meta("side")) * (0.2 + 0.12 * rate))


## A gear of `n` teeth: a disc with a hub, teeth round its edge, facing
## along z.
func _gear_view(n: int, m: float, mat: Material) -> MeshInstance3D:
	var g := CozyMesh.new()
	var r := n * m * 0.5
	var face := Basis(Vector3.RIGHT, PI * 0.5)
	g.cyl(r - 0.4 * m, r - 0.4 * m, 0.03, maxi(n, 12), CozyMesh.at(Vector3.ZERO, face), Color.WHITE)
	g.cyl(0.05, 0.05, 0.06, 10, CozyMesh.at(Vector3.ZERO, face), Color.WHITE)
	for k in n:
		var a := TAU * k / n
		g.box(Vector3(m * 1.1, m * 0.9, 0.03), CozyMesh.at(Vector3(cos(a), sin(a), 0) * r, Basis(Vector3.BACK, a)), Color.WHITE)
	var view := MeshInstance3D.new()
	view.mesh = g.commit(mat)
	return view


## ---- the bellows -----------------------------------------------------------------

func _bellows(show: Node3D) -> void:
	var wood: Material = expo.get("_wood")
	var iron: Material = expo.get("_iron")
	var copper: Material = expo.get("_copper")
	# The hearth, its coals and crucible, a hood and chimney over it.
	var h := Vector3(-0.6, 0, 1.0)
	expo._box(Vector3(1.3, 0.8, 1.0), h + Vector3(0, 0.4, 0), _stone, true, show)
	var coals := _embers(1.5)
	for k in 9:
		_sphere(0.08, h + Vector3(-0.35 + (k % 3) * 0.35, 0.83, -0.25 + (k / 3) * 0.25), coals, show)
	var crucible := _embers(1.5)
	_cylinder(0.14, 0.1, 0.2, h + Vector3(0, 0.98, 0), _ceramic, show)
	_cylinder(0.12, 0.12, 0.01, h + Vector3(0, 1.08, 0), crucible, show)
	var hood := PrismMesh.new()
	hood.size = Vector3(1.3, 0.6, 1.0)
	_mesh(hood, h + Vector3(0, 2.1, 0), _stone, show)
	expo._box(Vector3(0.35, 1.0, 0.35), h + Vector3(0, 2.9, 0), _stone, false, show)
	for x: float in [-0.6, 0.6]:
		expo._box(Vector3(0.08, 1.0, 0.08), h + Vector3(x, 1.3, -0.45), _stone, false, show)
	# The bellows: a fixed lower board, an upper board hinged at the back,
	# the leather between, a nozzle into the hearth, a handle.
	var b := Vector3(0.75, 0.55, 0.7)
	expo._box(Vector3(0.05, 0.55, 0.05), b + Vector3(0.0, -0.275, 0.25), wood, false, show)
	expo._box(Vector3(0.05, 0.55, 0.05), b + Vector3(0.0, -0.275, -0.25), wood, false, show)
	expo._box(Vector3(0.9, 0.04, 0.55), b, wood, false, show)
	expo._cyl(0.02, 0.06, 0.4, b + Vector3(-0.62, 0.05, 0), iron, 8, false, show).basis = Basis(Vector3.BACK, PI * 0.5)
	var top := _pivot(show, b + Vector3(0.45, 0.02, 0))
	expo._box(Vector3(0.9, 0.04, 0.55), Vector3(-0.45, 0.0, 0), wood, false, top)
	expo._rod(Vector3(0.0, 0.0, 0), Vector3(0.35, 0.2, 0), 0.02, wood, 6, top)
	var leather := _pivot(show, b + Vector3(0.0, 0.02, 0))
	var hide := StandardMaterial3D.new()
	hide.albedo_color = Color(0.42, 0.26, 0.16)
	hide.roughness = 0.85
	expo._box(Vector3(0.86, 1.0, 0.5), Vector3(0, 0.5, 0), hide, false, leather)
	_movers.append(func(t: float) -> void:
		# A breath every 2.4 s: the upper board lifts, then presses down.
		var lift := 0.5 + 0.5 * sin(t * TAU / 2.4)
		var angle := 0.04 + 0.26 * lift
		top.rotation.z = -angle
		leather.scale = Vector3(1.0 - 0.2 * lift, maxf(sin(angle) * 0.9, 0.01), 1.0)
		leather.position.x = b.x - 0.1 * (1.0 - lift)
		# Pressing down blows: the coals and the crucible brighten.
		var blow := maxf(-cos(t * TAU / 2.4), 0.0)
		coals.emission_energy_multiplier = 1.2 + 2.2 * blow
		crucible.emission_energy_multiplier = 1.4 + 1.6 * blow)
