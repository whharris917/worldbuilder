class_name TideWorks
extends BeachSite
## A barge moored 50 m off the exposition beach, reached by a walkway of
## pontoons that bob on the swell, carrying one process built from the
## exposition's pieces: sea water made into bottles of glowing essence,
## powered by the waves and run by light-beam logic.
##
## The process, stage by stage:
## - Power: a copper float on a see-saw arm rides the swell; the arm's
##   short end rocks, through a rod, a lever on a countershaft, whose
##   pawl drives a ratchet wheel one way only (a holding pawl clicking
##   over its teeth). A big gear there turns a small one on the line shaft
##   six times as fast; a flywheel carries it through the slack of each
##   swell, and a governor on it swings its balls out with the speed.
## - Pumping: a cam on the line shaft lifts the plunger of a pump in a
##   glass cylinder, drawing sea water up a pipe from below the barge;
##   each stroke sends it up past a sight glass into a copper header tank
##   with a glass level gauge.
## - Filling: from the tank a pipe runs down through a handwheel valve to
##   a copper cauldron on a stone hearth; the valve opens as its
##   radiometer spins.
## - Heating: a second cam works the forge's bellows while their
##   radiometer spins; each breath brightens the fire, and the brew heats.
## - Distilling: once it boils, its vapour rises into a hood and an onion
##   head, runs down a swan-neck arm into a coil in a tub, and drips into
##   the flask under the spout.
## - Collecting: the flasks stand on a carousel turned by a Geneva drive;
##   on the index radiometer's word it steps a quarter turn. The flask on
##   the far side, if full, tips into a glass carboy's funnel.
## - Tinting: the carboy full and the reactor empty, its tap lets the
##   essence along a pipe into the reactor (glass in brass bands under a
##   copper dome, stirred by a geared motor, warmed by a glowing coil).
##   Chebyshev's straight-line linkage carries a brass ladle level from a
##   basin of reagent to the reactor's funnel, tips it in, and lifts back
##   over the top of its path; each dose turns a counting wheel a quarter,
##   and the essence turns from blue to gold. Dosed three times and
##   stirred a while, the reactor's tap fills a crate with gold bottles,
##   the tally goes up and the wheel comes round to the start.
##
## The logic: each lantern stands at what it watches, its shutter worked
## by that machine: the governor's collar lifts with the shaft's speed; a
## float rod rises out of the tank, the carboy and the reactor (the last
## working two lanterns, one low, one high); a float on a lever tips as
## the cauldron's brew drops; a copper coil winds round as the fire heats
## and turns a pointer; a float arm in the flask under the spout rises as
## it fills; a cam on the counting wheel lifts on the third dose. Their
## beams run to crystals on the exposition's mountings:
##   VALVE   = the tank has water AND the cauldron wants filling   (a column by the valve)
##   BELLOWS = the shaft is turning AND NOT the cauldron boils     (hung from the hood's chandelier)
##   INDEX   = TON 1 s ( the flask under the spout is full )       (on a rail on the carousel's mast)
##   DRAIN   = TON 2 s ( the carboy is full ) AND NOT the reactor holds essence   (on a branch by the carboy)
##   DOSE    = the reactor is full AND NOT it is dosed               (on the linkage's beam)
##   BOTTLE  = TON 5 s ( it is dosed )                               (hung from the linkage's beam)
##
## The name board and notes are drafts.

const BEARING := 198.0
const OUT := 55.0                        # the barge's middle beyond the shore, m
const DECK_Y := 0.8                      # its deck over the sea
const HALF := Vector2(12.0, 9.0)         # half its deck, along and out
const PONTOON_Y := 0.4
const SWELL := 6.5                       # seconds a swell
const RATIO := 6.0                       # line shaft turns to the countershaft's
const TEETH := 16
const SHAFT := Vector2(6.0, 1.5)         # the line shaft's z, y
const COUNTER := Vector2(6.0, 0.8)       # the countershaft's z, y
const SEESAW := Vector2(8.6, 1.0)        # the see-saw's pivot z, y
const ARM := 3.8                         # its long arm to the float
const STUB := 1.0                        # its short arm
const LEVER := 0.7
const CAULDRON := Vector3(2.5, 0.0, 1.0)
const TANK := Vector3(-1.5, 0.0, 2.8)
const CAROUSEL := Vector3(6.6, 0.0, -2.4)
const TUB := Vector3(5.6, 0.0, -1.0)
const LS := 0.27                         # the linkage's unit, m: ground 2, crank 1, rocker 2.5, coupler 5
const LINK_Y := 0.81                     # its ground pivots over the deck
const LADLE_DROP := 0.22
const OFFSET := 0.65                     # the linkage plane beside the reactor's line
const GOLD := Color(1.0, 0.72, 0.22)
const BLUE := Color(0.55, 0.9, 1.0)

var _centre := Vector3.ZERO
var _pontoons: Array[AnimatableBody3D] = []
var _pontoon_base: Array[float] = []
var _clock := 0.0

# The machine's state.
var _float_y := 0.0
var _seesaw := 0.0
var _lever := 0.0
var _counter := 0.0                      # the countershaft's angle
var _counter_w := 0.0
var _shaft := 0.0
var _shaft_w := 0.0
var _rod_len := 1.0
var _tank := 0.3
var _brew_level := 0.5                        # the cauldron's
var _wants := false                      # the cauldron wants filling
var _heat := 0.2
var _hot := false
var _flasks := [0.0, 0.0, 0.0, 0.0]      # each carousel place's fill, place 0 under the spout
var _turns := 0                          # quarter turns the carousel has made
var _stepping := -1.0                    # seconds into a step, or < 0
var _pouring := -1.0
var _carboy := 0.0
var _draining := false
var _crates := 0
var _was_follower := 0.0
var _reactor := 0.0                      # its contents, 0 to 1
var _doses := 0
var _wheel := 0.0                        # the counting wheel's quarters turned, eased
var _crank := 0.0                        # the linkage's crank angle
var _bottling := false

var _copper: StandardMaterial3D
var _silver: StandardMaterial3D
var _iron: StandardMaterial3D
var _glass: StandardMaterial3D
var _stone: StandardMaterial3D
var _velvet: StandardMaterial3D
var _essence: StandardMaterial3D
var _sea_water: StandardMaterial3D
var _brew: StandardMaterial3D
var _fire: StandardMaterial3D

# Moving pieces.
var _float_node: Node3D
var _seesaw_node: Node3D
var _rod_link: MeshInstance3D
var _lever_node: Node3D
var _ratchet: Node3D
var _holder: Node3D
var _big_gear: Node3D
var _small_gear: Node3D
var _flywheel: Node3D
var _gov: Node3D
var _gov_arms: Array[Node3D] = []
var _cams: Array[Node3D] = []
var _pump_follower: Node3D
var _plunger: Node3D
var _slugs: Array[Node3D] = []
var _tank_gauge: Node3D
var _valve_wheel: Node3D
var _pour_stream: MeshInstance3D
var _brew_surface: Node3D
var _bubbles: Array[Node3D] = []
var _steam: Array[Node3D] = []
var _bellows_follower: Node3D
var _bellows_top: Node3D
var _bellows_leather: Node3D
var _bellows_rod: MeshInstance3D
var _drop: Node3D
var _turntable: Node3D
var _geneva_driver: Node3D
var _flask_nodes: Array[Node3D] = []
var _flask_fills: Array[Node3D] = []
var _carboy_fill: Node3D
var _funnel_stream: MeshInstance3D
var _tap_stream: MeshInstance3D
var _pendulum: Node3D
var _crate_nodes: Array[Node3D] = []
var _digits: Array[Label3D] = []
var _reactor_at := Vector3.ZERO
var _q := Vector3.ZERO                   # along the linkage's straight line, from the reactor to the basin
var _side := Vector3.ZERO
var _plane := Vector3.ZERO               # the linkage plane's origin: the crank's pivot
var _tint: StandardMaterial3D
var _coil_glow: StandardMaterial3D
var _reactor_fill: Node3D
var _stirrer: Node3D
var _motor_gear: Node3D
var _link_crank: MeshInstance3D
var _link_rocker: MeshInstance3D
var _link_coupler: MeshInstance3D
var _ladle: Node3D
var _ladle_arm: MeshInstance3D
var _count_wheel: Node3D
var _count_cam: Node3D
var _gov_collar: Node3D
var _gov_lever: MeshInstance3D
var _tank_rod: Node3D
var _cauldron_arm: Node3D
var _coil_pointer: Node3D
var _flask_arm: Node3D
var _carboy_rod: Node3D
var _reactor_rod: Node3D
var _snd_dose: AudioStreamPlayer3D

var _l := {}
var _r := {}

var _snd_click: AudioStreamPlayer3D
var _snd_chuff: AudioStreamPlayer3D
var _snd_bubble: AudioStreamPlayer3D
var _snd_clank: AudioStreamPlayer3D
var _snd_chime: AudioStreamPlayer3D


func _init(owner_island: CozyIsland) -> void:
	super(owner_island, BEARING)
	name = "TideWorks"
	var a := deg_to_rad(BEARING)
	var d := Vector3(cos(a), 0.0, sin(a))
	var along := Vector3(-d.z, 0.0, d.x)
	_centre = d * (island.coast(a, 0.0) + OUT)
	_site.transform = Transform3D(Basis(-along, Vector3.UP, d), Vector3(_centre.x, DECK_Y, _centre.z))
	# The shore's walls open for the walkway and run along its sides, up
	# to the barge's entrance, which its own rails close round.
	var shore := d * (island.coast(a, -0.5) - 2.0)
	var entrance := _centre - d * (HALF.y - 0.5)
	island.piers.append([shore, entrance, 1.1, true, true])


func _ready() -> void:
	add_child(_site)
	_materials()
	_build_walkway()
	_build_deck()
	_build_power()
	_build_pump()
	_build_tank()
	_build_cauldron()
	_build_still()
	_build_carousel()
	_build_reactor()
	_build_circuit()
	_place_beams()
	_build_sounds()


func _materials() -> void:
	_wood = island.surface("weathered_wood", 0.8, Color(0.9, 0.88, 0.86), 0.9, Color(0.66, 0.56, 0.46))
	_brass = island.surface("", 1.0, Color(0.62, 0.46, 0.2), 0.3, Color(0.92, 0.72, 0.34))
	_brass.metallic = 0.85
	_copper = island.surface("", 1.0, Color(0.62, 0.32, 0.2), 0.32, Color(0.9, 0.52, 0.34))
	_copper.metallic = 0.9
	_silver = island.surface("", 1.0, Color(0.78, 0.78, 0.8), 0.22, Color(0.88, 0.9, 0.95))
	_silver.metallic = 0.9
	_iron = island.surface("", 1.0, Color(0.12, 0.12, 0.13), 0.5, Color(0.34, 0.34, 0.42))
	_iron.metallic = 0.5
	_stone = island.surface("rough_rock", 0.6, Color(0.7, 0.68, 0.66), 0.9, Color(0.62, 0.6, 0.62))
	_velvet = island.surface("", 1.0, Color(0.08, 0.1, 0.26), 0.95, Color(0.24, 0.28, 0.56))
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(0.85, 0.95, 1.0, 0.18)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.roughness = 0.05
	_glass.metallic_specular = 0.8
	_essence = _glowing(Color(0.55, 0.9, 1.0), 1.2)
	_sea_water = _glowing(Color(0.35, 0.7, 0.75), 0.2)
	_brew = _glowing(Color(0.45, 0.95, 0.6), 0.5)
	_fire = _glowing(Color(1.0, 0.45, 0.12), 1.5)
	_fire.albedo_color = Color(0.5, 0.18, 0.05)


static func _glowing(colour: Color, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour.darkened(0.2)
	m.roughness = 0.12
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = glow
	return m


## ---- small helpers -----------------------------------------------------------

func _pivot(at: Vector3, parent: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.set_meta(StaticMerge.MOVES, true)
	(parent if parent != null else _site).add_child(n)
	return n


func _link(radius: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 1
	mesh.material = mat
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.set_meta(StaticMerge.MOVES, true)
	_site.add_child(view)
	return view


static func _place(link: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var basis := BeachSite._aligned(d) if d.length() > 0.0001 else Basis.IDENTITY
	link.transform = Transform3D(basis * Basis.from_scale(Vector3(1.0, maxf(d.length(), 0.001), 1.0)), (a + b) * 0.5)


## A point in the shaft plane: x along the barge, (z, y) given.
static func _zy(x: float, p: Vector2) -> Vector3:
	return Vector3(x, p.y, p.x)


func _sphere(r: float, at: Vector3, mat: Material, parent: Node3D = null, squash := Vector3.ONE) -> MeshInstance3D:
	var view := _ball(r, at, mat, parent)
	view.basis = Basis.from_scale(squash)
	return view


func _note(at: Vector3, size: Vector3, text: String) -> void:
	_site.add_child(HoverNote.new(at, size, text))


## ---- the walkway and the deck -------------------------------------------------

## Pontoons from the beach to the barge, each bobbing a little on the
## swell as it passes along them; a ramp up from the sand at the shore
## and a gangway up to the deck at the far end.
func _build_walkway() -> void:
	var a := deg_to_rad(BEARING)
	var d := Vector3(cos(a), 0.0, sin(a))
	var along := Vector3(-d.z, 0.0, d.x)
	var shore := d * island.coast(a, 0.0)
	var entrance := _centre - d * HALF.y
	var gang_from := entrance - d * 2.6
	var length := shore.distance_to(gang_from)
	var count := int(length / 3.0)
	var pitch := length / count
	var basis := Basis(-along, Vector3.UP, d)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4848
	var tones := [Color(0.84, 0.74, 0.6), Color(0.78, 0.68, 0.56), Color(0.88, 0.8, 0.66), Color(0.74, 0.64, 0.52)]
	for i in count:
		var mid := shore + d * pitch * (i + 0.5)
		var body := AnimatableBody3D.new()
		body.name = "Pontoon%d" % i
		body.set_meta(StaticMerge.MOVES, true)
		body.transform = Transform3D(basis, Vector3(mid.x, PONTOON_Y, mid.z))
		add_child(body)
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.2, 0.16, pitch - 0.08)
		var c := CollisionShape3D.new()
		c.shape = shape
		c.position.y = -0.08
		body.add_child(c)
		var m := CozyMesh.new()
		var boards := int((pitch - 0.08) / 0.2)
		for k in boards:
			var z := -(pitch - 0.08) * 0.5 + 0.1 + k * 0.2
			m.box(Vector3(2.2, 0.05, 0.18), CozyMesh.at(Vector3(0, -0.025, z)), (tones[rng.randi() % tones.size()] as Color).lightened(rng.randf_range(-0.05, 0.05)))
		for x: float in [-0.75, 0.75]:
			m.cyl(0.24, 0.24, pitch - 0.3, 14, CozyMesh.at(Vector3(x, -0.3, 0), Basis(Vector3.RIGHT, PI * 0.5)), Color(0.72, 0.42, 0.28))
		for x: float in [-1.05, 1.05]:
			for z: float in [-(pitch - 0.2) * 0.5, (pitch - 0.2) * 0.5]:
				m.cyl(0.035, 0.04, 1.0, 8, CozyMesh.at(Vector3(x, 0.5, z)), Color(0.55, 0.42, 0.3))
			m.cyl(0.018, 0.018, pitch - 0.2, 6, CozyMesh.at(Vector3(x, 0.92, 0), Basis(Vector3.RIGHT, PI * 0.5)), Color(0.82, 0.74, 0.58))
		var view := MeshInstance3D.new()
		view.mesh = m.commit(island.cozy_material())
		body.add_child(view)
		_pontoons.append(body)
		_pontoon_base.append(PONTOON_Y)
	# The ramp up from the sand, and the gangway up to the deck.
	var sand := shore - d * 3.0
	_ramp(Vector3(sand.x, island.height(sand.x, sand.z) + 0.03, sand.z), Vector3(shore.x, PONTOON_Y, shore.z))
	_ramp(Vector3(gang_from.x, PONTOON_Y, gang_from.z), Vector3(entrance.x, DECK_Y, entrance.z))


## A boarded ramp 2.2 m wide from `a` up to `b`, with its own solid.
func _ramp(a: Vector3, b: Vector3) -> void:
	var run := b - a
	var fwd := run.normalized()
	var x0 := Vector3.UP.cross(fwd).normalized()
	var basis := Basis(x0, fwd.cross(x0).normalized(), fwd)
	var m := CozyMesh.new()
	var boards := int(run.length() / 0.2)
	for k in boards:
		var z := -run.length() * 0.5 + 0.1 + k * 0.2
		m.box(Vector3(2.2, 0.05, 0.18), CozyMesh.at(Vector3(0, -0.025, z)), Color(0.8, 0.7, 0.56))
	var view := MeshInstance3D.new()
	view.mesh = m.commit(island.cozy_material())
	view.transform = Transform3D(basis, (a + b) * 0.5)
	add_child(view)
	var body := StaticBody3D.new()
	body.transform = view.transform
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 0.1, run.length())
	var c := CollisionShape3D.new()
	c.shape = shape
	c.position.y = -0.05
	body.add_child(c)
	add_child(body)


## The barge: a boarded deck on a dark hull riding on copper drums, rails
## all round but at the entrance, its name over the entrance.
func _build_deck() -> void:
	var m := CozyMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5151
	var tones := [Color(0.84, 0.74, 0.6), Color(0.78, 0.68, 0.56), Color(0.88, 0.8, 0.66), Color(0.74, 0.64, 0.52)]
	var boards := int(HALF.y * 2.0 / 0.22)
	for k in boards:
		var z := -HALF.y + 0.11 + k * 0.22
		m.box(Vector3(HALF.x * 2.0, 0.06, 0.2), CozyMesh.at(Vector3(0, -0.03, z)), (tones[rng.randi() % tones.size()] as Color).lightened(rng.randf_range(-0.05, 0.05)))
	m.box(Vector3(HALF.x * 2.0 + 0.2, 0.9, HALF.y * 2.0 + 0.2), CozyMesh.at(Vector3(0, -0.51, 0)), Color(0.36, 0.28, 0.22))
	for side: float in [-1.0, 1.0]:
		for k in 5:
			var x := -HALF.x + 2.4 + k * (HALF.x * 2.0 - 4.8) / 4.0
			m.cyl(0.55, 0.55, 3.0, 18, CozyMesh.at(Vector3(x, -0.95, side * (HALF.y - 1.5)), Basis(Vector3.RIGHT, PI * 0.5)), Color(0.72, 0.42, 0.28))
		for k in 7:
			m.torus(0.08, 0.18, 12, 6, CozyMesh.at(Vector3(-HALF.x + 2.0 + k * 3.3, -0.35, side * (HALF.y + 0.12)), Basis(Vector3.RIGHT, PI * 0.5)), Color(0.82, 0.74, 0.58))
	# The arch over the entrance.
	for x: float in [-1.4, 1.4]:
		m.box(Vector3(0.18, 3.0, 0.18), CozyMesh.at(Vector3(x, 1.5, -HALF.y + 0.15)), Color(0.55, 0.42, 0.3))
	m.box(Vector3(3.4, 0.6, 0.12), CozyMesh.at(Vector3(0, 2.85, -HALF.y + 0.15)), Color(0.5, 0.36, 0.26))
	m.box(Vector3(3.2, 0.46, 0.14), CozyMesh.at(Vector3(0, 2.85, -HALF.y + 0.15)), CrystalExpo.CREAM)
	var view := MeshInstance3D.new()
	view.name = "Deck"
	view.mesh = m.commit(island.cozy_material())
	_site.add_child(view)
	for face: float in [1.0, -1.0]:
		var sign := Label3D.new()
		sign.text = "THE TIDEWORKS"
		sign.font_size = 72
		sign.pixel_size = 0.004
		sign.modulate = Color(0.32, 0.2, 0.14)
		sign.double_sided = false
		sign.position = Vector3(0, 2.85, -HALF.y + 0.15 - 0.075 * face)
		sign.rotation.y = PI if face > 0.0 else 0.0
		_site.add_child(sign)
	var body := StaticBody3D.new()
	var deck := BoxShape3D.new()
	deck.size = Vector3(HALF.x * 2.0, 0.3, HALF.y * 2.0)
	var c := CollisionShape3D.new()
	c.shape = deck
	c.position.y = -0.15
	body.add_child(c)
	_site.add_child(body)
	# Rails: brass posts and two ropes round the edge, a wall within them
	# so no one walks off; open at the entrance.
	var edge: Array[Array] = [[Vector3(-HALF.x, 0, -HALF.y), Vector3(-1.3, 0, -HALF.y)], [Vector3(1.3, 0, -HALF.y), Vector3(HALF.x, 0, -HALF.y)],
			[Vector3(HALF.x, 0, -HALF.y), Vector3(HALF.x, 0, HALF.y)], [Vector3(HALF.x, 0, HALF.y), Vector3(-HALF.x, 0, HALF.y)],
			[Vector3(-HALF.x, 0, HALF.y), Vector3(-HALF.x, 0, -HALF.y)]]
	for e: Array in edge:
		var p: Vector3 = e[0]
		var q: Vector3 = e[1]
		var posts := maxi(int(p.distance_to(q) / 2.0), 1)
		for k in posts + 1:
			var at := p.lerp(q, float(k) / posts)
			_cyl(0.035, 0.045, 1.05, at + Vector3(0, 0.525, 0), _brass, 8, false)
		_rod(p + Vector3(0, 1.0, 0), q + Vector3(0, 1.0, 0), 0.02, _brass, 6)
		_rod(p + Vector3(0, 0.55, 0), q + Vector3(0, 0.55, 0), 0.015, _brass, 6)
		var wall := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(p.distance_to(q), 1.4, 0.1)
		wall.shape = box
		wall.transform = Transform3D(Basis(Vector3.UP, atan2(-(q - p).z, (q - p).x)), (p + q) * 0.5 + Vector3(0, 0.7, 0))
		body.add_child(wall)
	# Its note on the name board, up out of the way of heads.
	_note(Vector3(0, 2.85, -HALF.y + 0.15), Vector3(3.2, 0.6, 0.3),
			"The Tideworks\nSea water made into bottles of essence, powered by the swell and run by light.")


## ---- power from the swell -----------------------------------------------------

func _build_power() -> void:
	var x := -9.2
	# The see-saw: its pivot on a post at the deck's edge, the float out
	# on the sea at its long end.
	_box(Vector3(0.2, SEESAW.y, 0.2), _zy(x, Vector2(SEESAW.x, SEESAW.y * 0.5)), _iron, false)
	_seesaw_node = _pivot(_zy(x, SEESAW))
	_rod(Vector3(0, 0, -STUB), Vector3(0, 0, ARM), 0.05, _iron, 8, _seesaw_node)
	_float_node = _pivot(Vector3.ZERO)
	_sphere(0.7, Vector3.ZERO, _copper, _float_node, Vector3(1, 0.7, 1))
	_band(_float_node)
	# The countershaft: a ratchet wheel, the lever and its pawl, a big gear.
	_box(Vector3(0.25, COUNTER.y, 0.25), _zy(x + 0.35, Vector2(COUNTER.x, COUNTER.y * 0.5)), _iron, false)
	_ratchet = _pivot(_zy(x, COUNTER))
	var wheel := MeshInstance3D.new()
	wheel.mesh = LinkageHall._plate(func(a: float) -> float: return 0.42 + 0.08 * fposmod(a * TEETH / TAU, 1.0), 0.06, TEETH * 10)
	wheel.material_override = _brass
	wheel.basis = Basis(Vector3.UP, PI * 0.5)
	_ratchet.add_child(wheel)
	_lever_node = _pivot(_zy(x - 0.08, COUNTER))
	_box(Vector3(0.04, 0.05, LEVER), Vector3(0, 0, LEVER * 0.5), _iron, false, _lever_node)
	_box(Vector3(0.03, 0.03, 0.22), Vector3(0, 0.04, 0.38), _copper, false, _lever_node)
	_rod_link = _link(0.03, _iron)
	_holder = _pivot(_zy(x - 0.08, COUNTER + Vector2(-0.35, 0.42)))
	_box(Vector3(0.03, 0.03, 0.26), Vector3(0, -0.02, 0.1), _copper, false, _holder)
	_big_gear = _pivot(_zy(x + 0.18, COUNTER))
	var big := LinkageHall._plate(func(a: float) -> float: return 0.6 + 0.025 * signf(sin(a * 48.0)), 0.05, 48 * 4)
	var big_view := MeshInstance3D.new()
	big_view.mesh = big
	big_view.material_override = _copper
	big_view.basis = Basis(Vector3.UP, PI * 0.5)
	_big_gear.add_child(big_view)
	# The line shaft, on posts, from the gear to the far machines.
	for px: float in [-8.5, -4.0, 1.0, 6.5]:
		_box(Vector3(0.18, SHAFT.y, 0.24), _zy(px, Vector2(SHAFT.x, SHAFT.y * 0.5)), _iron, true)
	var shaft := _pivot(_zy(0.0, SHAFT))
	_cams.append(shaft)
	var bar := _cyl(0.04, 0.04, 16.6, Vector3(-0.9, 0, 0), _iron, 8, false, shaft)
	bar.basis = Basis(Vector3.BACK, PI * 0.5)
	_small_gear = _pivot(_zy(x + 0.18, SHAFT))
	var small := LinkageHall._plate(func(a: float) -> float: return 0.1 + 0.025 * signf(sin(a * 8.0)), 0.05, 64)
	var small_view := MeshInstance3D.new()
	small_view.mesh = small
	small_view.material_override = _brass
	small_view.basis = Basis(Vector3.UP, PI * 0.5)
	_small_gear.add_child(small_view)
	# The flywheel.
	_flywheel = _pivot(_zy(-7.2, SHAFT))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.72
	rim.outer_radius = 0.82
	rim.rings = 40
	rim.ring_segments = 8
	rim.material = _iron
	var rim_view := _put(rim, Vector3.ZERO, false, Vector3.ZERO, _flywheel)
	rim_view.basis = Basis(Vector3.BACK, PI * 0.5)
	for k in 6:
		var a := TAU * k / 6.0
		_rod(Vector3.ZERO, Vector3(0, sin(a), cos(a)) * 0.74, 0.03, _iron, 6, _flywheel)
	_sphere(0.09, Vector3.ZERO, _brass, _flywheel)
	# The governor: a spindle up from a bracket on the shaft.
	var gov_at := _zy(-5.5, SHAFT + Vector2(0, 0.1))
	_box(Vector3(0.2, 0.1, 0.2), gov_at, _brass, false)
	_gov = _pivot(gov_at)
	_cyl(0.02, 0.02, 1.0, Vector3(0, 0.5, 0), _brass, 8, false, _gov)
	for side: float in [-1.0, 1.0]:
		var arm := _pivot(Vector3(0, 1.0, 0), _gov)
		_rod(Vector3.ZERO, Vector3(0, -0.4, 0), 0.012, _brass, 4, arm)
		_ball(0.07, Vector3(0, -0.42, 0), _brass, arm)
		arm.set_meta("side", side)
		_gov_arms.append(arm)
	_note(_zy(x, Vector2(7.2, 1.2)), Vector3(1.6, 2.2, 4.0),
			"The swell engine\nThe float rides the swell; its arm rocks the lever, whose pawl drives the ratchet one way only. The gears turn the line shaft six times as fast; the flywheel carries it between swells.")
	# The see-saw's mid position fixes the rod's length.
	var mid := asin(clampf((-DECK_Y - SEESAW.y) / ARM, -1.0, 1.0))
	var back := SEESAW - Vector2(cos(mid), sin(mid)) * STUB
	var start := COUNTER + Vector2(cos(0.4), sin(0.4)) * LEVER
	_rod_len = back.distance_to(start)


## A brass band round the float, to show it turning with the swell.
func _band(parent: Node3D) -> void:
	var band := TorusMesh.new()
	band.inner_radius = 0.66
	band.outer_radius = 0.74
	band.rings = 32
	band.ring_segments = 6
	band.material = _brass
	_put(band, Vector3.ZERO, false, Vector3.ZERO, parent)


## ---- the pump and the tank ------------------------------------------------------

func _build_pump() -> void:
	var x := -1.5
	var cam_mesh := LinkageHall._plate(func(a: float) -> float: return 0.08 * cos(a) + sqrt(0.15 * 0.15 - pow(0.08 * sin(a), 2.0)), 0.06)
	var cam := MeshInstance3D.new()
	cam.mesh = cam_mesh
	cam.material_override = _copper
	cam.position = Vector3(x, 0, 0)
	cam.basis = Basis(Vector3.UP, PI * 0.5)
	_cams[0].add_child(cam)
	_pump_follower = _pivot(_zy(x, SHAFT))
	_cyl(0.015, 0.015, 0.5, Vector3(0, 0.25, 0), _iron, 6, false, _pump_follower)
	_cyl(0.03, 0.03, 0.03, Vector3(0, 0.01, 0), _brass, 10, false, _pump_follower)
	var cyl_at := _zy(x, SHAFT + Vector2(0, 0.85))
	_cyl(0.1, 0.1, 0.6, cyl_at, _glass, 16, false)
	_cyl(0.12, 0.12, 0.04, cyl_at + Vector3(0, 0.32, 0), _brass, 16, false)
	_cyl(0.12, 0.12, 0.04, cyl_at - Vector3(0, 0.32, 0), _brass, 16, false)
	_plunger = _pivot(cyl_at)
	_cyl(0.09, 0.09, 0.08, Vector3.ZERO, _brass, 16, false, _plunger)
	_box(Vector3(0.05, cyl_at.y - 0.32 - SHAFT.y, 0.05), _zy(x + 0.18, SHAFT + Vector2(0, (cyl_at.y - 0.32 - SHAFT.y) * 0.5 + 0.0)), _iron, false)
	# The intake down into the sea, the riser up past a sight glass to
	# the tank.
	var low := cyl_at - Vector3(0, 0.3, 0)
	_rod(low, Vector3(x, low.y, HALF.y + 0.4), 0.04, _copper, 8)
	_rod(Vector3(x, low.y, HALF.y + 0.4), Vector3(x, -DECK_Y - 0.9, HALF.y + 0.4), 0.04, _copper, 8)
	_sphere(0.12, Vector3(x, -DECK_Y - 0.95, HALF.y + 0.4), _brass)
	var top := cyl_at + Vector3(0, 0.34, 0)
	_cyl(0.05, 0.05, 0.4, top + Vector3(0, 0.2, 0), _glass, 12, false)
	var riser_top := top + Vector3(0, 0.45, 0)
	_rod(riser_top, Vector3(x, riser_top.y, TANK.z), 0.04, _copper, 8)
	_rod(Vector3(x, riser_top.y, TANK.z), TANK + Vector3(0, 2.62, 0), 0.04, _copper, 8)
	for k in 3:
		var slug := _pivot(top)
		_sphere(0.035, Vector3.ZERO, _sea_water, slug, Vector3(1, 1.5, 1))
		_slugs.append(slug)
	_note(cyl_at, Vector3(0.6, 1.6, 0.6), "The pump\nA cam on the line shaft lifts its plunger; each stroke draws sea water up into the tank.")


func _build_tank() -> void:
	for dx: float in [-0.4, 0.4]:
		for dz: float in [-0.4, 0.4]:
			_box(Vector3(0.08, 1.5, 0.08), TANK + Vector3(dx, 0.75, dz), _iron, false)
	_box(Vector3(1.0, 1.5, 1.0), TANK + Vector3(0, 0.75, 0), _iron, true).visible = false
	_cyl(0.55, 0.55, 1.0, TANK + Vector3(0, 2.05, 0), _copper, 20, false)
	_sphere(0.55, TANK + Vector3(0, 2.55, 0), _copper, null, Vector3(1, 0.25, 1))
	# The gauge: a glass tube on its face, the water's level in it.
	var gauge := TANK + Vector3(0, 2.05, -0.6)
	_cyl(0.04, 0.04, 0.95, gauge, _glass, 10, false)
	_rod(gauge + Vector3(0, 0.45, 0), TANK + Vector3(0, 2.5, -0.5), 0.015, _brass, 6)
	_rod(gauge - Vector3(0, 0.45, 0), TANK + Vector3(0, 1.6, -0.5), 0.015, _brass, 6)
	_tank_gauge = _pivot(gauge - Vector3(0, 0.46, 0))
	_cyl(0.032, 0.032, 1.0, Vector3(0, 0.5, 0), _sea_water, 10, false, _tank_gauge)
	# Down to the cauldron through the valve.
	var out := TANK + Vector3(0, 1.55, 0)
	var bend := Vector3(TANK.x, 1.1, TANK.z)
	_rod(out, bend, 0.04, _copper, 8)
	var over := Vector3(CAULDRON.x - 0.3, 1.1, TANK.z)
	_rod(bend, over, 0.04, _copper, 8)
	var spout := CAULDRON + Vector3(-0.3, 1.45, -0.0)
	_rod(over, Vector3(over.x, 1.45, over.z), 0.04, _copper, 8)
	_rod(Vector3(over.x, 1.45, over.z), spout, 0.04, _copper, 8)
	var valve := (bend + over) * 0.5
	_cyl(0.08, 0.08, 0.18, valve, _brass, 12, false).basis = Basis(Vector3.BACK, PI * 0.5)
	_valve_wheel = _pivot(valve + Vector3(0, 0.2, 0))
	_ring(0.12, 0.14, Vector3.ZERO, _iron, _valve_wheel)
	for s in 3:
		var a := TAU * s / 3.0
		_rod(Vector3.ZERO, Vector3(cos(a), 0, sin(a)) * 0.13, 0.01, _iron, 4, _valve_wheel)
	_pour_stream = _link(0.025, _sea_water)
	_place(_pour_stream, spout, spout - Vector3(0, 0.6, 0))
	_pour_stream.visible = false
	_note(TANK + Vector3(0, 2.0, 0), Vector3(1.4, 1.4, 1.4), "The header tank\nThe pump fills it; the gauge shows how full. A valve below lets it down into the cauldron.")


## A ring (torus) lying flat, or turned by `basis`.
func _ring(inner: float, outer: float, at: Vector3, mat: Material, parent: Node3D = null, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 8
	mesh.material = mat
	var view := _put(mesh, at, false, Vector3.ZERO, parent)
	view.basis = basis
	return view


## ---- the cauldron and the bellows -------------------------------------------

func _build_cauldron() -> void:
	var rim := 1.15
	_box(Vector3(1.6, 0.55, 1.6), CAULDRON + Vector3(0, 0.275, 0), _stone, true)
	for k in 5:
		var a := TAU * k / 5.0
		var flame := CylinderMesh.new()
		flame.top_radius = 0.0
		flame.bottom_radius = 0.09
		flame.height = 0.3
		flame.material = _fire
		_put(flame, CAULDRON + Vector3(cos(a) * 0.3, 0.7, sin(a) * 0.3), false, Vector3.ZERO, null)
	var bowl := SphereMesh.new()
	bowl.radius = 0.65
	bowl.height = 0.65
	bowl.is_hemisphere = true
	bowl.radial_segments = 24
	bowl.rings = 8
	bowl.material = _copper
	_put(bowl, CAULDRON + Vector3(0, rim, 0), false, Vector3.ZERO, null).basis = Basis(Vector3.RIGHT, PI)
	_ring(0.63, 0.69, CAULDRON + Vector3(0, rim, 0), _copper)
	_brew_surface = _pivot(CAULDRON + Vector3(0, rim - 0.5, 0))
	_cyl(0.6, 0.6, 0.02, Vector3.ZERO, _brew, 24, false, _brew_surface)
	for k in 6:
		var bubble := _pivot(CAULDRON + Vector3(cos(k * 2.3) * 0.35, rim - 0.1, sin(k * 2.3) * 0.35))
		_sphere(0.05, Vector3.ZERO, _brew, bubble)
		_bubbles.append(bubble)
	# The bellows, worked by the second cam through a long rod.
	var b := CAULDRON + Vector3(1.4, 0.5, 0.0)
	_box(Vector3(0.05, 0.5, 0.05), b + Vector3(0, -0.25, 0.25), _wood, false)
	_box(Vector3(0.05, 0.5, 0.05), b + Vector3(0, -0.25, -0.25), _wood, false)
	_box(Vector3(0.8, 0.04, 0.5), b, _wood, false)
	_cyl(0.02, 0.05, 0.35, b + Vector3(-0.55, 0.04, 0), _iron, 8, false).basis = Basis(Vector3.BACK, PI * 0.5)
	_bellows_top = _pivot(b + Vector3(0.4, 0.02, 0))
	_box(Vector3(0.8, 0.04, 0.5), Vector3(-0.4, 0, 0), _wood, false, _bellows_top)
	_bellows_leather = _pivot(b + Vector3(0, 0.02, 0))
	var hide := StandardMaterial3D.new()
	hide.albedo_color = Color(0.42, 0.26, 0.16)
	hide.roughness = 0.85
	_box(Vector3(0.76, 1.0, 0.46), Vector3(0, 0.5, 0), hide, false, _bellows_leather)
	var cam_mesh := LinkageHall._plate(func(a: float) -> float: return 0.1 + 0.07 * pow(maxf(cos(a), 0.0), 2.0), 0.06)
	var cam := MeshInstance3D.new()
	cam.mesh = cam_mesh
	cam.material_override = _brass
	cam.position = Vector3(3.5, 0, 0)
	cam.basis = Basis(Vector3.UP, PI * 0.5)
	_cams[0].add_child(cam)
	_bellows_follower = _pivot(_zy(3.5, SHAFT))
	_cyl(0.015, 0.015, 0.5, Vector3(0, 0.25, 0), _iron, 6, false, _bellows_follower)
	_cyl(0.03, 0.03, 0.03, Vector3(0, 0.01, 0), _brass, 10, false, _bellows_follower)
	_bellows_rod = _link(0.02, _iron)
	_note(CAULDRON + Vector3(0, 1.0, 0), Vector3(1.8, 2.0, 1.8), "The cauldron\nFilled from the tank, heated by the forge; the bellows blow while it is not yet boiling.")


## ---- the still -----------------------------------------------------------------

func _build_still() -> void:
	# A hood over the cauldron on three rods, the onion head above it.
	var hood := CylinderMesh.new()
	hood.top_radius = 0.12
	hood.bottom_radius = 0.7
	hood.height = 0.4
	hood.material = _copper
	_put(hood, CAULDRON + Vector3(0, 1.85, 0), false, Vector3.ZERO, null)
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		_rod(CAULDRON + Vector3(cos(a) * 0.66, 1.15, sin(a) * 0.66), CAULDRON + Vector3(cos(a) * 0.66, 1.66, sin(a) * 0.66), 0.02, _brass, 6)
	_sphere(0.24, CAULDRON + Vector3(0, 2.3, 0), _copper, null, Vector3(1, 0.85, 1))
	_sphere(0.05, CAULDRON + Vector3(0, 2.53, 0), _copper)
	var arm_end := TUB + Vector3(-0.3, 1.3, 0)
	_rod(CAULDRON + Vector3(0.18, 2.32, -0.1), arm_end, 0.035, _copper, 8)
	# Steam rising into the hood while it boils.
	var steam_mat := StandardMaterial3D.new()
	steam_mat.albedo_color = Color(1, 1, 1, 0.3)
	steam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 5:
		var puff := _pivot(CAULDRON + Vector3(0, 1.2, 0))
		_sphere(0.12, Vector3.ZERO, steam_mat, puff)
		_steam.append(puff)
	# The tub with its coil, the spout over the carousel.
	_cyl(0.46, 0.42, 1.0, TUB + Vector3(0, 0.5, 0), _wood, 20, true)
	_cyl(0.43, 0.43, 0.01, TUB + Vector3(0, 0.97, 0), _sea_water, 20, false)
	for k in 3:
		_ring(0.26, 0.29, TUB + Vector3(0, 1.04 + k * 0.09, 0), _copper)
	_rod(arm_end, TUB + Vector3(-0.25, 1.22, 0), 0.03, _copper, 6)
	var to_carousel := Vector3(CAROUSEL.x - TUB.x, 0, CAROUSEL.z - TUB.z).normalized()
	var spout := CAROUSEL - to_carousel * 0.45 + Vector3(0, 1.45, 0)
	_rod(TUB + Vector3(0, 0.3, 0) + to_carousel * 0.42, TUB + Vector3(0, 0.3, 0) + to_carousel * 0.55, 0.02, _copper, 6)
	_rod(TUB + Vector3(0, 0.3, 0) + to_carousel * 0.55, Vector3(spout.x, 1.45, spout.z), 0.02, _copper, 6)
	_drop = _pivot(spout)
	_sphere(0.016, Vector3.ZERO, _essence, _drop)
	# The chandelier over the hood that the bellows logic hangs from.
	_rod(CAULDRON + Vector3(-0.9, 0, -0.9), CAULDRON + Vector3(-0.9, 2.9, -0.9), 0.04, _brass, 8)
	_rod(CAULDRON + Vector3(-0.9, 2.9, -0.9), CAULDRON + Vector3(0.0, 2.9, -0.9), 0.03, _brass, 8)
	_ring(0.5, 0.55, CAULDRON + Vector3(0.0, 2.75, -0.9), _brass)
	_rod(CAULDRON + Vector3(0.0, 2.9, -0.9), CAULDRON + Vector3(0.0, 2.75, -0.9), 0.012, _brass, 4)
	_note(TUB + Vector3(0, 1.0, 0), Vector3(1.2, 2.0, 1.2), "The still\nThe brew's vapour rises into the hood and head, runs down the arm, cools in the coil, and drips into the flask.")


## ---- the carousel, the carboy, the crates ------------------------------------

func _build_carousel() -> void:
	var c := CAROUSEL
	_cyl(0.3, 0.38, 0.1, c + Vector3(0, 0.05, 0), _iron, 16, true)
	_cyl(0.06, 0.08, 0.75, c + Vector3(0, 0.45, 0), _brass, 12, false)
	# The Geneva drive under the table: a four-slot wheel on its spindle,
	# a driver with its pin beside it, worked by a clockwork with a pendulum.
	var g := c + Vector3(0, 0.55, 0)
	var d := 0.5
	var to_tub := Vector3(TUB.x - c.x, 0, TUB.z - c.z).normalized()
	var side := to_tub.cross(Vector3.UP).normalized()
	_geneva_driver = _pivot(g + side * d)
	_cyl(0.2, 0.2, 0.04, Vector3.ZERO, _copper, 24, false, _geneva_driver)
	_box(Vector3(d / sqrt(2.0), 0.04, 0.05), Vector3(d / sqrt(2.0) * 0.5, 0.03, 0), _copper, false, _geneva_driver)
	_sphere(0.03, Vector3(d / sqrt(2.0), 0.06, 0), _iron, _geneva_driver)
	_cyl(0.03, 0.03, 0.6, g + side * d - Vector3(0, 0.27, 0), _iron, 8, false)
	_turntable = _pivot(c + Vector3(0, 0.85, 0))
	_cyl(0.62, 0.62, 0.05, Vector3.ZERO, _brass, 32, false, _turntable)
	var geneva := _pivot(Vector3(0, -0.3, 0), _turntable)
	_cyl(0.33, 0.33, 0.04, Vector3.ZERO, _brass, 24, false, geneva)
	for k in 4:
		var a := k * PI * 0.5
		var slot := _box(Vector3(0.22, 0.046, 0.05), Vector3(cos(a), 0, sin(a)) * 0.22, _iron, false, geneva)
		slot.basis = Basis(Vector3.UP, -a)
	# Four flasks at the quarters, place 0 toward the tub (under the spout).
	for k in 4:
		var place := _pivot(Vector3.ZERO, _turntable)
		place.rotation.y = atan2(-to_tub.z, to_tub.x) - k * PI * 0.5
		var flask := _pivot(Vector3(0.45, 0.03, 0), place)
		_sphere(0.12, Vector3(0, 0.12, 0), _glass, flask)
		_cyl(0.03, 0.035, 0.14, Vector3(0, 0.29, 0), _glass, 10, false, flask)
		var fill := _pivot(Vector3(0, 0.02, 0), flask)
		_sphere(0.1, Vector3(0, 0.08, 0), _essence, fill)
		_flask_nodes.append(flask)
		_flask_fills.append(fill)
	# The carboy beyond the far place, its funnel, its tap, the crates.
	var carboy := c - to_tub * 1.25
	_cyl(0.45, 0.42, 0.3, carboy + Vector3(0, 0.15, 0), _wood, 20, true)
	_sphere(0.5, carboy + Vector3(0, 0.75, 0), _glass)
	_carboy_fill = _pivot(carboy + Vector3(0, 0.3, 0))
	_sphere(0.46, Vector3(0, 0.42, 0), _essence, _carboy_fill, Vector3(1, 0.9, 1))
	_cyl(0.06, 0.08, 0.2, carboy + Vector3(0, 1.3, 0), _glass, 12, false)
	var funnel := CylinderMesh.new()
	funnel.top_radius = 0.2
	funnel.bottom_radius = 0.04
	funnel.height = 0.2
	funnel.material = _copper
	_put(funnel, carboy + Vector3(0, 1.45, 0) + to_tub * 0.1, false, Vector3.ZERO, null)
	_funnel_stream = _link(0.02, _essence)
	_funnel_stream.visible = false
	# Its tap at the foot, a pipe along to the reactor's foot.
	var tap := carboy + Vector3(0, 0.38, 0) + side * 0.5
	_rod(carboy + Vector3(0, 0.38, 0) + side * 0.42, tap, 0.03, _brass, 8)
	_cyl(0.035, 0.035, 0.1, tap + Vector3(0, 0.06, 0), _brass, 8, false)
	_reactor_at = carboy + side * 1.7
	_rod(tap, _reactor_at + Vector3(0, 0.38, 0) - side * 0.42, 0.035, _copper, 8)
	# The carboy's float rod, rising out of its neck as it fills.
	_carboy_rod = _pivot(carboy + Vector3(0, 1.3, 0) - side * 0.04)
	_cyl(0.01, 0.01, 0.6, Vector3(0, 0.0, 0), _brass, 6, false, _carboy_rod)
	_box(Vector3(0.16, 0.02, 0.02), Vector3(0, 0.3, 0) - side * 0.08, _brass, false, _carboy_rod)
	# The clockwork on the carousel's mast: a pendulum that swings while it
	# steps.
	var mast := c - side * 0.9
	_cyl(0.05, 0.06, 2.6, mast + Vector3(0, 1.3, 0), _brass, 10, true)
	_box(Vector3(0.36, 0.36, 0.12), mast + Vector3(0, 2.1, -0.08), _wood, false)
	_pendulum = _pivot(mast + Vector3(0, 2.0, -0.16))
	_rod(Vector3.ZERO, Vector3(0, -0.6, 0), 0.008, _brass, 4, _pendulum)
	_cyl(0.06, 0.06, 0.02, Vector3(0, -0.63, 0), _brass, 12, false, _pendulum).basis = Basis(Vector3.RIGHT, PI * 0.5)
	_note(c + Vector3(0, 1.1, 0), Vector3(1.5, 1.2, 1.5), "The carousel\nWhen the flask under the spout is full, the Geneva drive steps it on a quarter turn; full flasks are tipped into the carboy.")
	_note(carboy + Vector3(0, 0.8, 0), Vector3(1.1, 1.6, 1.1), "The carboy\nWhen it is full and the reactor empty, its tap lets the essence along to the reactor.")


## ---- the reactor and the straight-line linkage ----------------------------

func _build_reactor() -> void:
	var to_tub := Vector3(TUB.x - CAROUSEL.x, 0, TUB.z - CAROUSEL.z).normalized()
	_side = to_tub.cross(Vector3.UP).normalized()
	_q = _side.cross(Vector3.UP).normalized()
	var r := _reactor_at
	_tint = _glowing(BLUE, 1.0)
	_coil_glow = _glowing(Color(1.0, 0.45, 0.12), 0.2)
	_coil_glow.albedo_color = Color(0.6, 0.32, 0.2)
	# The reactor: glass in brass bands on a brass stand, a copper dome, a
	# funnel, a geared motor turning a stirrer, a glowing coil round its foot.
	_cyl(0.42, 0.48, 0.3, r + Vector3(0, 0.15, 0), _brass, 24, true)
	_cyl(0.4, 0.4, 1.0, r + Vector3(0, 0.8, 0), _glass, 24, false)
	for y: float in [0.32, 0.8, 1.28]:
		_ring(0.39, 0.44, r + Vector3(0, y, 0), _brass)
	_reactor_fill = _pivot(r + Vector3(0, 0.31, 0))
	_cyl(0.37, 0.37, 1.0, Vector3(0, 0.5, 0), _tint, 24, false, _reactor_fill)
	_sphere(0.42, r + Vector3(0, 1.3, 0), _copper, null, Vector3(1, 0.4, 1))
	var funnel := CylinderMesh.new()
	funnel.top_radius = 0.16
	funnel.bottom_radius = 0.04
	funnel.height = 0.2
	funnel.material = _copper
	_put(funnel, r + Vector3(0, 1.55, 0), false, Vector3.ZERO, null)
	for k in 4:
		_ring(0.42 + k * 0.035, 0.45 + k * 0.035, r + Vector3(0, 0.38 + k * 0.05, 0), _coil_glow)
	var motor := r + Vector3(0, 1.5, 0) + _side * 0.22
	_box(Vector3(0.16, 0.16, 0.16), motor, _brass, false)
	_motor_gear = _pivot(motor + Vector3(0, 0.12, 0))
	_cyl(0.07, 0.07, 0.02, Vector3.ZERO, _copper, 12, false, _motor_gear)
	_stirrer = _pivot(r + Vector3(0, 1.4, 0))
	_cyl(0.012, 0.012, 1.1, Vector3(0, -0.45, 0), _iron, 6, false, _stirrer)
	_box(Vector3(0.5, 0.12, 0.02), Vector3(0, -0.9, 0), _brass, false, _stirrer)
	_cyl(0.06, 0.06, 0.02, Vector3(0, 0.06, 0), _copper, 12, false, _stirrer)
	# Its float rod, out of the dome beside the funnel, working two
	# lanterns: one low (it holds essence), one high (it is full).
	_reactor_rod = _pivot(r + Vector3(0, 1.36, 0) - _side * 0.2)
	_cyl(0.01, 0.01, 0.9, Vector3(0, -0.2, 0), _brass, 6, false, _reactor_rod)
	_box(Vector3(0.02, 0.02, 0.16), Vector3(0, 0.25, 0) - _q * 0.06, _brass, false, _reactor_rod)
	# The tap at the foot, toward the crates.
	var tap := r + Vector3(0, 0.38, 0) + _side * 0.5
	_rod(r + Vector3(0, 0.38, 0) + _side * 0.42, tap, 0.03, _brass, 8)
	_tap_stream = _link(0.02, _tint)
	_place(_tap_stream, tap + Vector3(0, -0.04, 0), tap + Vector3(0, -0.3, 0))
	_tap_stream.visible = false
	for k in 6:
		var crate := _pivot(tap + _side * (0.55 + 0.48 * (k % 3)) + Vector3(0, 0.36 * (k / 3), 0) - Vector3(0, 0.38, 0))
		var m := CozyMesh.new()
		m.box(Vector3(0.44, 0.34, 0.44), CozyMesh.at(Vector3(0, 0.17, 0)), Color(0.72, 0.56, 0.38))
		for bx: float in [-0.1, 0.1]:
			for bz: float in [-0.1, 0.1]:
				m.cyl(0.05, 0.05, 0.2, 8, CozyMesh.at(Vector3(bx, 0.42, bz)), Color(1.0, 0.78, 0.3))
				m.cyl(0.02, 0.02, 0.05, 6, CozyMesh.at(Vector3(bx, 0.55, bz)), Color(0.85, 0.6, 0.3))
		var v := MeshInstance3D.new()
		v.mesh = m.commit(island.cozy_material())
		crate.add_child(v)
		crate.visible = false
		_crate_nodes.append(crate)
	var plate_at := tap + _side * 1.0 + Vector3(0, 0.9, 0) - _q * 0.6
	_box(Vector3(0.46, 0.2, 0.04), plate_at, _brass, false)
	for k in 3:
		var dgt := Label3D.new()
		dgt.text = "0"
		dgt.font_size = 64
		dgt.pixel_size = 0.0018
		dgt.modulate = Color(0.1, 0.08, 0.06)
		dgt.position = plate_at + Vector3(-0.12 + 0.12 * k, 0, -0.025)
		dgt.rotation.y = PI
		_site.add_child(dgt)
		_digits.append(dgt)
	# The basin of reagent at the far end of the straight line, on a
	# pedestal, and a rack of reagent jars behind it.
	var basin := r + _q * (4.54 * LS)
	_cyl(0.06, 0.1, 1.45, basin + Vector3(0, 0.725, 0), _brass, 10, true)
	var bowl := SphereMesh.new()
	bowl.radius = 0.24
	bowl.height = 0.24
	bowl.is_hemisphere = true
	bowl.material = _copper
	_put(bowl, basin + Vector3(0, 1.62, 0), false, Vector3.ZERO, null).basis = Basis(Vector3.RIGHT, PI)
	var reagent := _glowing(GOLD, 1.0)
	_cyl(0.22, 0.22, 0.02, basin + Vector3(0, 1.56, 0), reagent, 20, false)
	var rack := basin + _q * 0.6
	_box(Vector3(0.12, 1.3, 0.12), rack + _side * 0.5 + Vector3(0, 0.65, 0), _wood, false)
	_box(Vector3(0.12, 1.3, 0.12), rack - _side * 0.5 + Vector3(0, 0.65, 0), _wood, false)
	for y: float in [0.6, 1.1]:
		var shelf := _box(Vector3(1.1, 0.04, 0.3), rack + Vector3(0, y, 0), _wood, false)
		shelf.basis = Basis(Vector3.UP, atan2(-_side.z, _side.x))
		for k in 4:
			var jar := rack + Vector3(0, y + 0.02, 0) + _side * (-0.36 + 0.24 * k)
			_cyl(0.07, 0.07, 0.2, jar + Vector3(0, 0.1, 0), _glass, 12, false)
			_cyl(0.06, 0.06, 0.12, jar + Vector3(0, 0.06, 0), _glowing(GOLD.lerp(Color(1.0, 0.5, 0.3), k / 3.0), 0.7), 12, false)
			_cyl(0.04, 0.05, 0.04, jar + Vector3(0, 0.22, 0), _brass, 10, false)
	# The linkage: two posts holding the ground pivots in a plane beside
	# the line from basin to reactor, a beam across their tops for its
	# crystals, a clockwork motor at the crank.
	_plane = r - _q * (0.27 * LS) * -1.0 + _q * 0.0 + _side * -OFFSET
	_plane = r + _q * (0.27 * LS) - _side * OFFSET + Vector3(0, LINK_Y, 0)
	var a_pivot := _plane
	var d_pivot := _plane + _q * (2.0 * LS)
	for pv: Vector3 in [a_pivot, d_pivot]:
		_box(Vector3(0.1, pv.y + 1.6, 0.1), Vector3(pv.x, (pv.y + 1.6) * 0.5, pv.z) - _side * 0.12, _wood, true)
		_ball(0.04, pv, _iron)
	var beam := _box(Vector3(0.12, 0.12, 2.0 * LS + 0.6), (a_pivot + d_pivot) * 0.5 + Vector3(0, 1.6, 0) - _side * 0.12, _wood, false)
	beam.basis = Basis(Vector3.UP, atan2(_q.x, _q.z))
	_box(Vector3(0.24, 0.24, 0.2), a_pivot - _side * 0.24, _brass, false)
	_link_crank = _link(0.02, _brass)
	_link_rocker = _link(0.02, _brass)
	_link_coupler = _link(0.018, _copper)
	_ladle_arm = _link(0.014, _brass)
	_ladle = _pivot(Vector3.ZERO)
	_box(Vector3(0.03, 0.03, 0.03), Vector3.ZERO, _brass, false, _ladle)
	var cup := SphereMesh.new()
	cup.radius = 0.08
	cup.height = 0.08
	cup.is_hemisphere = true
	cup.material = _brass
	_put(cup, Vector3(0, -LADLE_DROP, 0), false, Vector3.ZERO, _ladle).basis = Basis(Vector3.RIGHT, PI)
	_rod(Vector3.ZERO, Vector3(0, -LADLE_DROP, 0), 0.01, _brass, 4, _ladle)
	# The counting wheel by the crank: a quarter turn a dose, a cam on it.
	var wheel_at := a_pivot - _side * 0.35 + Vector3(0, -0.35, 0)
	_count_wheel = _pivot(wheel_at)
	var notched := MeshInstance3D.new()
	notched.mesh = LinkageHall._plate(func(ang: float) -> float: return 0.12 + 0.03 * signf(cos(ang * 4.0)), 0.04, 64)
	notched.material_override = _brass
	notched.basis = Basis(Vector3.UP, atan2(_side.x, _side.z))
	_count_wheel.add_child(notched)
	_count_cam = _pivot(Vector3.ZERO, _count_wheel)
	# Set so that three quarter turns bring it upright, under the lantern.
	_count_cam.basis = Basis(_side, PI * 1.5)
	_box(Vector3(0.03, 0.18, 0.03), Vector3(0, 0.12, 0), _copper, false, _count_cam)
	_note(r + Vector3(0, 0.9, 0), Vector3(1.0, 1.8, 1.0), "The reactor\nThe essence is stirred and warmed here while the reagent is dosed in; three doses turn it gold.")
	_note((a_pivot + d_pivot) * 0.5 + Vector3(0, 0.5, 0), Vector3(1.2, 1.2, 0.5) , "The straight-line linkage\nChebyshev's linkage carries the ladle level from the basin to the reactor, so nothing spills, and lifts it back over the top.")


## A point of the linkage's plane: `u` along its straight line (toward
## the basin), `v` up from its ground pivots.
func _in_plane(p: Vector2) -> Vector3:
	return _plane + _q * p.x + Vector3(0, p.y, 0)


## ---- the logic --------------------------------------------------------------------

## A part held by a mounting, at `pos` on the deck.
func _mount(kind: LumenPart.Kind, title: String, pos: Vector3, look: Dictionary, delay := 0.0) -> LumenPart:
	var l := look.duplicate()
	l["post"] = false
	var p := LumenPart.new(kind, title, pos, 0.0, _wood, _brass, delay, l)
	_site.add_child(p)
	parts.append(p)
	return p


func _build_circuit() -> void:
	var lamp := {"lamp": "drum", "metal": _brass}
	var to_tub := Vector3(TUB.x - CAROUSEL.x, 0, TUB.z - CAROUSEL.z).normalized()
	var side := to_tub.cross(Vector3.UP).normalized()
	var carboy := CAROUSEL - to_tub * 1.25
	# The shaft turning: the governor's collar rises with its speed and
	# lifts a lever to the lantern.
	var gov_at := _zy(-5.5, SHAFT + Vector2(0, 0.1))
	_gov_collar = _pivot(Vector3(0, 0.3, 0), _gov)
	_ring(0.03, 0.06, Vector3.ZERO, _brass, _gov_collar)
	_box(Vector3(0.06, 0.06, 0.06), gov_at + Vector3(0, 0.75, -0.5), _brass, false)
	_box(Vector3(0.05, 2.25 - 0.05, 0.05), Vector3(gov_at.x, (2.25 - 0.05) * 0.5, gov_at.z - 0.5), _iron, false)
	_l["swell"] = _mount(LumenPart.Kind.LANTERN, "the line shaft is turning", gov_at + Vector3(0, 0.95, -0.5), lamp)
	_gov_lever = _link(0.012, _brass)
	# The tank has water: a float rod rising out of its lid.
	_tank_rod = _pivot(TANK + Vector3(0.25, 2.5, 0.25))
	_cyl(0.01, 0.01, 0.8, Vector3(0, -0.2, 0), _brass, 6, false, _tank_rod)
	_box(Vector3(0.02, 0.02, 0.2), Vector3(0, 0.2, -0.1), _brass, false, _tank_rod)
	_box(Vector3(0.05, 0.7, 0.05), TANK + Vector3(0.25, 2.95, 0.05), _iron, false)
	_l["tank"] = _mount(LumenPart.Kind.LANTERN, "the header tank has water", TANK + Vector3(0.25, 3.42, 0.05), lamp)
	# The cauldron wants filling: a float on a lever arm over its rim; the
	# arm's outer end rises as the brew drops.
	_cauldron_arm = _pivot(CAULDRON + Vector3(-0.66, 1.3, 0.3))
	_rod(Vector3(-0.4, 0, 0), Vector3(0.36, 0, 0), 0.012, _brass, 6, _cauldron_arm)
	_sphere(0.07, Vector3(0.38, 0, 0), _copper, _cauldron_arm)
	_box(Vector3(0.05, 1.3, 0.05), CAULDRON + Vector3(-0.66, 0.65, 0.3), _iron, false)
	_box(Vector3(0.05, 0.5, 0.05), CAULDRON + Vector3(-1.1, 1.25, 0.3), _iron, false)
	_l["low"] = _mount(LumenPart.Kind.LANTERN, "the cauldron wants filling", CAULDRON + Vector3(-1.1, 1.62, 0.3), lamp)
	# Boiling: a copper coil on the hearth's face winds round as it heats,
	# turning a pointer up toward the lantern.
	var coil_at := CAULDRON + Vector3(0.4, 0.3, -0.82)
	for k in 4:
		_ring(0.03 + k * 0.025, 0.04 + k * 0.025, coil_at, _copper, null, Basis(Vector3.RIGHT, PI * 0.5))
	_coil_pointer = _pivot(coil_at + Vector3(0, 0, -0.03))
	_box(Vector3(0.012, 0.2, 0.01), Vector3(0, 0.1, 0), _brass, false, _coil_pointer)
	_box(Vector3(0.05, 0.4, 0.05), coil_at + Vector3(0.0, 0.4, -0.06), _iron, false)
	_l["hot"] = _mount(LumenPart.Kind.LANTERN, "the cauldron is boiling", coil_at + Vector3(0.0, 0.72, -0.1), lamp)
	# The flask under the spout is full: a little float arm dipping into
	# its neck, rising as it fills.
	var spout := CAROUSEL - to_tub * 0.45 + Vector3(0, 1.45, 0)
	_flask_arm = _pivot(spout + side * 0.18 + Vector3(0, 0.05, 0))
	_rod(Vector3.ZERO, -side * 0.18 + Vector3(0, -0.22, 0), 0.006, _brass, 4, _flask_arm)
	_sphere(0.025, -side * 0.18 + Vector3(0, -0.23, 0), _copper, _flask_arm)
	_rod(Vector3.ZERO, side * 0.16 + Vector3(0, 0.05, 0), 0.006, _brass, 4, _flask_arm)
	_box(Vector3(0.04, spout.y + 0.05, 0.04), Vector3(spout.x, (spout.y + 0.05) * 0.5, spout.z) + side * 0.34, _iron, false)
	_l["full"] = _mount(LumenPart.Kind.LANTERN, "the flask under the spout is full", spout + side * 0.34 + Vector3(0, 0.22, 0), lamp)
	# The carboy is full: its float rod out of the neck.
	_box(Vector3(0.04, 1.75, 0.04), carboy - side * 0.3 + Vector3(0, 0.875, 0), _iron, false)
	_l["carboy"] = _mount(LumenPart.Kind.LANTERN, "the carboy is full", carboy - side * 0.3 + Vector3(0, 1.92, 0), lamp)
	# The reactor holds essence, and is full: its float rod's two lanterns.
	var rr := _reactor_at - _side * 0.2 - _q * 0.25
	_box(Vector3(0.04, 2.2, 0.04), rr + Vector3(0, 1.1, 0), _iron, false)
	_l["holds"] = _mount(LumenPart.Kind.LANTERN, "the reactor holds essence", rr + Vector3(0, 1.72, 0), lamp)
	_l["rfull"] = _mount(LumenPart.Kind.LANTERN, "the reactor is full", rr + Vector3(0, 2.1, 0), lamp)
	# Dosed: the counting wheel's cam.
	var cam_lamp := _count_wheel.position - _side * 0.05 + Vector3(0, 0.36, 0) - _q * 0.25
	_box(Vector3(0.04, cam_lamp.y - 0.12, 0.04), Vector3(cam_lamp.x, (cam_lamp.y - 0.12) * 0.5, cam_lamp.z), _iron, false)
	_l["dosed"] = _mount(LumenPart.Kind.LANTERN, "the essence is dosed", cam_lamp, lamp)

	# VALVE: a column of crystals by the valve.
	var col := TANK + Vector3(1.0, 0.0, -0.9)
	_cyl(0.05, 0.065, 2.3, col + Vector3(0, 1.15, 0), _brass, 10, true)
	_sphere(0.08, col + Vector3(0, 2.32, 0), _brass)
	_ring(0.06, 0.085, col + Vector3(0, 1.45, 0), _brass)
	_rod(col + Vector3(0, 1.45, 0), col + Vector3(0.24, 1.45, 0), 0.015, _brass, 6)
	var valve_and := _mount(LumenPart.Kind.AND, "open the valve", col + Vector3(0.24, 1.6, 0), {"design": "octa", "setting": "collar", "metal": _brass})
	_ring(0.06, 0.085, col + Vector3(0, 1.95, 0), _brass)
	_rod(col + Vector3(0, 1.95, 0), col + Vector3(-0.24, 1.95, 0), 0.015, _brass, 6)
	_r["valve"] = _mount(LumenPart.Kind.RADIOMETER, "turns the valve open", col + Vector3(-0.24, 2.1, 0), {})
	_wire(_l["tank"], valve_and)
	_wire(_l["low"], valve_and)
	_wire(valve_and, _r["valve"])
	# BELLOWS: crystals hung from the chandelier over the hood.
	var ring_at := CAULDRON + Vector3(0.0, 2.75, -0.9)
	var hang := func(a: float) -> Vector3: return ring_at + Vector3(cos(a), 0, sin(a)) * 0.52
	for a: float in [0.0, PI * 0.66, PI * 1.33]:
		_rod(hang.call(a), hang.call(a) - Vector3(0, 0.2, 0), 0.006, _brass, 4)
	var not_hot := _mount(LumenPart.Kind.NOT, "not boiling", hang.call(0.0) - Vector3(0, 0.42, 0), {"design": "cluster", "setting": "hook", "metal": _brass})
	var bellows_and := _mount(LumenPart.Kind.AND, "blow the bellows", hang.call(PI * 0.66) - Vector3(0, 0.42, 0), {"design": "cluster", "setting": "hook", "metal": _brass})
	_r["bellows"] = _mount(LumenPart.Kind.RADIOMETER, "puts the bellows to the cam", CAULDRON + Vector3(1.4, 1.2, 0.5), {})
	_box(Vector3(0.06, 1.0, 0.06), CAULDRON + Vector3(1.4, 0.5, 0.5), _iron, false)
	_wire(_l["hot"], not_hot)
	_wire(_l["swell"], bellows_and)
	_wire(not_hot, bellows_and)
	_wire(bellows_and, _r["bellows"])
	# INDEX: crystals on a silver rail on the carousel's mast.
	var rail := CAROUSEL - side * 0.9 - to_tub * 0.25
	for dx: float in [-0.05, 0.05]:
		_rod(rail + Vector3(dx, 0.4, 0), rail + Vector3(dx, 2.4, 0), 0.014, _silver, 6)
	_box(Vector3(0.18, 0.08, 0.08), rail + Vector3(0, 1.9, 0), _silver, false)
	var index_ton := _mount(LumenPart.Kind.TON, "a full flask, a moment", rail + Vector3(0, 1.7, -0.2), {"design": "orb", "setting": "cage", "metal": _silver}, 1.0)
	_rod(rail + Vector3(0, 1.9, 0), rail + Vector3(0, 1.86, -0.2), 0.008, _silver, 4)
	_box(Vector3(0.18, 0.08, 0.08), rail + Vector3(0, 1.2, 0), _silver, false)
	_r["index"] = _mount(LumenPart.Kind.RADIOMETER, "steps the carousel", rail + Vector3(0, 1.0, -0.2), {})
	_wire(_l["full"], index_ton)
	_wire(index_ton, _r["index"])
	# DRAIN: a branch by the carboy.
	var br := carboy - side * 0.9
	_cyl(0.04, 0.05, 1.8, br + Vector3(0, 0.9, 0), _copper, 10, true)
	_rod(br + Vector3(0, 1.8, -0.6), br + Vector3(0, 1.8, 0.6), 0.025, _copper, 8)
	var drain_ton := _mount(LumenPart.Kind.TON, "a full carboy, a moment", br + Vector3(0, 2.0, -0.45), {"design": "gem", "setting": "cup", "metal": _copper}, 2.0)
	var not_holds := _mount(LumenPart.Kind.NOT, "the reactor is empty", br + Vector3(0, 2.0, -0.05), {"design": "gem", "setting": "cup", "metal": _copper})
	var drain_and := _mount(LumenPart.Kind.AND, "let the carboy down", br + Vector3(0, 2.0, 0.35), {"design": "gem", "setting": "cup", "metal": _copper})
	_r["drain"] = _mount(LumenPart.Kind.RADIOMETER, "opens the carboy's tap", carboy + side * 0.5 + Vector3(0, 0.62, 0), {})
	_wire(_l["carboy"], drain_ton)
	_wire(_l["holds"], not_holds)
	_wire(drain_ton, drain_and)
	_wire(not_holds, drain_and)
	_wire(drain_and, _r["drain"])
	# DOSE and BOTTLE: crystals on the linkage's beam, one hung beneath it.
	var top := (_plane + _q * LS) + Vector3(0, 1.6 - LINK_Y + 0.0, 0) - _side * 0.12
	top.y = LINK_Y + 1.6
	var not_dosed := _mount(LumenPart.Kind.NOT, "not yet dosed", top + Vector3(0, 0.22, 0) - _q * 0.35, {"design": "prism", "setting": "coil", "metal": _copper})
	var dose_and := _mount(LumenPart.Kind.AND, "dose the reactor", top + Vector3(0, 0.22, 0) + _q * 0.05, {"design": "prism", "setting": "coil", "metal": _copper})
	_rod(top + _q * 0.45, top + _q * 0.45 - Vector3(0, 0.2, 0), 0.006, _brass, 4)
	var bottle_ton := _mount(LumenPart.Kind.TON, "dosed, and stirred a while", top + _q * 0.45 - Vector3(0, 0.42, 0), {"design": "obelisk", "setting": "hook", "metal": _brass}, 5.0)
	_r["dose"] = _mount(LumenPart.Kind.RADIOMETER, "runs the linkage", _plane - _side * 0.24 + Vector3(0, 0.3, 0), {})
	_r["bottle"] = _mount(LumenPart.Kind.RADIOMETER, "opens the reactor's tap", _reactor_at + _side * 0.5 + Vector3(0, 0.62, 0), {})
	_wire(_l["dosed"], not_dosed)
	_wire(_l["rfull"], dose_and)
	_wire(not_dosed, dose_and)
	_wire(dose_and, _r["dose"])
	_wire(_l["dosed"], bottle_ton)
	_wire(bottle_ton, _r["bottle"])


## ---- sound ------------------------------------------------------------------------

func _build_sounds() -> void:
	_snd_click = _speaker("res://audio/ratchet.wav", false, _zy(-9.2, COUNTER), 6.0)
	_snd_chuff = _speaker("res://audio/chuff.wav", false, _zy(-1.5, SHAFT + Vector2(0, 0.9)), 6.0)
	_snd_bubble = _speaker("res://audio/bubble_loop.wav", true, CAULDRON + Vector3(0, 1.2, 0), 5.0)
	_snd_clank = _speaker("res://audio/clank_2.wav", false, CAROUSEL + Vector3(0, 0.8, 0), 5.0)
	_snd_chime = _speaker("res://audio/chime.wav", false, _reactor_at + Vector3(0, 1.0, 0), 6.0)
	_snd_dose = _speaker("res://audio/clank_1.wav", false, _reactor_at + Vector3(0, 1.6, 0), 4.0)


## ---- running -----------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	_clock += dt
	var t := _clock
	# The pontoons bob as the swell runs along them.
	for i in _pontoons.size():
		var p := _pontoons[i]
		p.position.y = _pontoon_base[i] + 0.035 * sin(TAU * t / SWELL - i * 0.55)
		p.rotation.z = 0.012 * sin(TAU * t / SWELL - i * 0.55 + 0.8)

	# The swell under the float; the see-saw follows it.
	_float_y = -DECK_Y + 0.5 * sin(TAU * t / SWELL)
	_seesaw = asin(clampf((_float_y - SEESAW.y) / ARM, -1.0, 1.0))
	var back := SEESAW - Vector2(cos(_seesaw), sin(_seesaw)) * STUB
	# The lever's end, where it can meet the rod from the see-saw.
	var end := LinkageHall._meet(COUNTER, LEVER, back, _rod_len, true)
	var lever := atan2(end.y - COUNTER.y, end.x - COUNTER.x)
	var swing := angle_difference(_lever, lever) if _clock > dt * 1.5 else 0.0
	_lever = lever
	# The pawl drives the countershaft while the lever outruns it; the
	# flywheel carries it on, slowing a little, the rest of the time. The
	# load on it holds it to a stately pace.
	var push := minf(swing / maxf(dt, 0.0001), 0.12)
	if push > _counter_w:
		_counter_w = push
	else:
		_counter_w *= exp(-0.12 * dt)
	var before := floorf(_counter * TEETH / TAU)
	_counter += _counter_w * dt
	if floorf(_counter * TEETH / TAU) != before:
		_play(_snd_click, randf_range(0.9, 1.1))
	_shaft_w = _counter_w * RATIO
	_shaft += _shaft_w * dt
	# The pump: the cam lifts the follower; a rising stroke fills the tank.
	var lift := 0.08 * cos(PI * 0.5 - _shaft) + sqrt(0.15 * 0.15 - pow(0.08 * sin(PI * 0.5 - _shaft), 2.0))
	if lift > _was_follower:
		_tank = minf(_tank + (lift - _was_follower) * 1.6, 1.0)
	if lift >= 0.225 and _was_follower < 0.225:
		_play(_snd_chuff, randf_range(0.9, 1.05))
	_was_follower = lift
	# The valve lets the tank down into the cauldron.
	var open := (_r["valve"] as LumenPart).spin
	var flow := 0.0
	if _tank > 0.0 and _brew_level < 1.0:
		flow = minf(0.07 * open * dt, _tank)
	_tank -= flow
	_brew_level = minf(_brew_level + flow * 1.2, 1.0)
	if _brew_level < 0.35:
		_wants = true
	elif _brew_level > 0.9:
		_wants = false
	# The fire: the bellows heat it while they work; it cools slowly.
	var blowing := (_r["bellows"] as LumenPart).spin * clampf(_shaft_w / 0.4, 0.0, 1.0)
	_heat = clampf(_heat + (0.045 * blowing - 0.012) * dt, 0.0, 1.0)
	if _heat > 0.85:
		_hot = true
	elif _heat < 0.72:
		_hot = false
	var boiling := _heat > 0.7 and _brew_level > 0.05
	if boiling:
		_brew_level = maxf(_brew_level - 0.012 * dt, 0.0)
		if _stepping < 0.0:
			_flasks[0] = minf(float(_flasks[0]) + 0.04 * dt, 1.0)
	# The carousel: the index radiometer starts a quarter turn.
	if _stepping < 0.0 and (_r["index"] as LumenPart).spin > 0.5 and float(_flasks[0]) >= 1.0:
		_stepping = 0.0
	if _stepping >= 0.0:
		_stepping += dt
		if _stepping >= 2.0:
			_stepping = -1.0
			_turns += 1
			# What was under the spout moves on a place; the far place's
			# flask comes round empty.
			_flasks = [_flasks[3], _flasks[0], _flasks[1], _flasks[2]]
			_play(_snd_clank, 1.0)
	# The far place pours a full flask into the carboy.
	if _pouring < 0.0 and _stepping < 0.0 and float(_flasks[2]) >= 1.0 and _carboy < 1.0:
		_pouring = 0.0
	if _pouring >= 0.0:
		_pouring += dt
		if _pouring > 1.0 and _pouring < 3.0:
			var poured := minf(dt * 0.5, float(_flasks[2]))
			_flasks[2] = float(_flasks[2]) - poured
			_carboy = minf(_carboy + poured * 0.25, 1.0)
		if _pouring >= 4.0:
			_pouring = -1.0
			_flasks[2] = 0.0
	# The carboy's tap, opened by its radiometer, lets it into the reactor.
	var tap := (_r["drain"] as LumenPart).spin
	if tap > 0.5 and _carboy > 0.0:
		_draining = true
	if _draining:
		var moved := minf(0.25 * dt, _carboy)
		_carboy -= moved
		_reactor = minf(_reactor + moved, 1.0)
		if _carboy <= 0.0:
			_draining = false
	# The linkage runs while its radiometer spins; a dose each time the
	# ladle tips over the funnel.
	var run := (_r["dose"] as LumenPart).spin
	var was := fposmod(rad_to_deg(_crank), 360.0)
	_crank += 1.1 * run * dt
	var now := fposmod(rad_to_deg(_crank), 360.0)
	if run > 0.05 and was < 300.0 and now >= 300.0 and _doses < 3 and _reactor > 0.5:
		_doses += 1
		_play(_snd_dose, randf_range(1.1, 1.3))
	# The reactor's tap, opened by its radiometer, bottles the gold.
	if (_r["bottle"] as LumenPart).spin > 0.5 and _reactor > 0.0 and _doses >= 3:
		_bottling = true
	if _bottling:
		_reactor = maxf(_reactor - 0.2 * dt, 0.0)
		if _reactor <= 0.0:
			_bottling = false
			_doses = 0
			_crates = (_crates + 1) % 1000
			_play(_snd_chime, 1.2)
			for k in 3:
				_digits[k].text = str(_crates / int(pow(10, 2 - k)) % 10)
	# The lanterns.
	(_l["swell"] as LumenPart).condition = _shaft_w > 0.2
	(_l["tank"] as LumenPart).condition = _tank > 0.15
	(_l["low"] as LumenPart).condition = _wants
	(_l["hot"] as LumenPart).condition = _hot
	(_l["full"] as LumenPart).condition = float(_flasks[0]) >= 1.0 and _stepping < 0.0
	(_l["carboy"] as LumenPart).condition = _carboy >= 0.999 and not _draining
	(_l["holds"] as LumenPart).condition = _reactor > 0.02
	(_l["rfull"] as LumenPart).condition = _reactor >= 0.98
	(_l["dosed"] as LumenPart).condition = _wheel >= 2.9 and _doses >= 3
	_step_circuit(dt)


func _process(_delta: float) -> void:
	var t := _clock
	# The swell engine.
	_seesaw_node.rotation.x = -_seesaw
	_float_node.position = _zy(-9.2, SEESAW + Vector2(cos(_seesaw), sin(_seesaw)) * ARM)
	var back := SEESAW - Vector2(cos(_seesaw), sin(_seesaw)) * STUB
	var end := COUNTER + Vector2(cos(_lever), sin(_lever)) * LEVER
	_place(_rod_link, _zy(-9.25, back), _zy(-9.25, end))
	_lever_node.rotation.x = -_lever
	_ratchet.rotation.x = -_counter
	_big_gear.rotation.x = -_counter
	_small_gear.rotation.x = _shaft
	_holder.rotation.x = -0.15 * fposmod(_counter * TEETH / TAU, 1.0)
	_cams[0].rotation.x = _shaft
	_flywheel.rotation.x = _shaft
	_gov.rotation.y += _shaft_w * 3.0 * get_process_delta_time()
	for arm in _gov_arms:
		arm.rotation.z = float(arm.get_meta("side")) * (0.15 + 0.5 * clampf(_shaft_w / 1.2, 0.0, 1.0))
	# The pump.
	var lift := 0.08 * cos(PI * 0.5 - _shaft) + sqrt(0.15 * 0.15 - pow(0.08 * sin(PI * 0.5 - _shaft), 2.0))
	_pump_follower.position = _zy(-1.5, SHAFT + Vector2(0, lift))
	_plunger.position = _zy(-1.5, SHAFT + Vector2(0, 0.85 - 0.25 + lift * 1.2))
	for k in _slugs.size():
		var f := fposmod(_shaft * 0.5 + k / 3.0, 1.0)
		_slugs[k].position = _zy(-1.5, SHAFT + Vector2(0, 0.85 + 0.36 + 0.36 * f))
	_tank_gauge.scale = Vector3(1, maxf(_tank * 0.92, 0.01), 1)
	# The valve and its stream.
	var open := (_r["valve"] as LumenPart).spin
	_valve_wheel.rotation.y = -open * 4.0
	_pour_stream.visible = open > 0.2 and _tank > 0.0 and _brew_level < 1.0
	# The cauldron.
	_brew_surface.position.y = 1.15 - 0.5 + 0.42 * _brew_level
	_brew.emission_energy_multiplier = 0.3 + 1.2 * _heat
	_fire.emission_energy_multiplier = 0.6 + 2.0 * _heat + 0.3 * sin(t * 9.0) * sin(t * 3.1)
	var boiling := _heat > 0.7 and _brew_level > 0.05
	for k in _bubbles.size():
		var f := fmod(t * 0.7 + k * 0.37, 1.0)
		_bubbles[k].visible = boiling and f < 0.95
		_bubbles[k].scale = Vector3.ONE * maxf(f, 0.01)
		_bubbles[k].position.y = _brew_surface.position.y + 0.02
	for k in _steam.size():
		var f := fmod(t * 0.4 + k * 0.2, 1.0)
		_steam[k].visible = boiling
		_steam[k].position = CAULDRON + Vector3(sin(k * 1.7) * 0.2, _brew_surface.position.y + 0.1 + f * 0.9, cos(k * 1.7) * 0.2)
		_steam[k].scale = Vector3.ONE * (0.5 + f)
	if _snd_bubble.stream != null:
		_level(_snd_bubble, 1.0 if boiling else 0.0, -10.0)
	# The bellows, breathing to the cam while put to it.
	var engaged := (_r["bellows"] as LumenPart).spin
	var cam := 0.1 + 0.07 * pow(maxf(cos(PI * 0.5 - _shaft), 0.0), 2.0)
	var breath := (cam - 0.1) / 0.07 * engaged
	_bellows_follower.position = _zy(3.5, SHAFT + Vector2(0, lerpf(0.2, cam, engaged)))
	var angle := 0.05 + 0.25 * (1.0 - breath)
	_bellows_top.rotation.z = -angle
	_bellows_leather.scale = Vector3(1.0 - 0.15 * (1.0 - breath), maxf(sin(angle) * 0.85, 0.01), 1.0)
	_place(_bellows_rod, _zy(3.5, SHAFT + Vector2(0, lerpf(0.2, cam, engaged) + 0.5)), CAULDRON + Vector3(1.75, 0.55 + 0.2 * (1.0 - breath), 0))
	# The drip, every 0.8 s while it boils.
	var f := fmod(t, 0.8)
	var fall := 0.5 * 9.8 * f * f
	var spout_y := 1.45
	_drop.visible = boiling and _stepping < 0.0 and fall < 0.3
	_drop.position.y = spout_y - minf(fall, 0.3)
	# The carousel: a Geneva step takes 2 s, the pendulum swinging the while.
	var part := 0.0
	if _stepping >= 0.0:
		var phi := lerpf(-PI * 0.25, PI * 0.25, _stepping / 2.0)
		var d := 0.5
		var r := d / sqrt(2.0)
		part = (atan2(r * sin(phi), d - r * cos(phi)) + PI * 0.25) / (PI * 0.5)
		_geneva_driver.rotation.y = -(phi + PI * 0.25) - _turns * TAU
		_pendulum.rotation.z = 0.3 * sin(_stepping * PI * 2.0)
	else:
		_pendulum.rotation.z = lerpf(_pendulum.rotation.z, 0.0, 0.1)
	_turntable.rotation.y = -(_turns + part) * PI * 0.5
	for k in 4:
		# The flasks keep their fills as they travel: place k holds the
		# fill listed for it now.
		var slot := posmod(k + _turns, 4)
		var fill: float = _flasks[slot]
		_flask_fills[k].scale = Vector3(1, maxf(fill, 0.02), 1)
		var tipping := slot == 2 and _pouring >= 0.0
		var tip := sin(clampf(_pouring / 4.0, 0.0, 1.0) * PI) * 1.2 if tipping else 0.0
		_flask_nodes[k].rotation.z = -tip
	_funnel_stream.visible = _pouring > 1.0 and _pouring < 3.0
	if _funnel_stream.visible:
		var to_tub := Vector3(TUB.x - CAROUSEL.x, 0, TUB.z - CAROUSEL.z).normalized()
		var carboy := CAROUSEL - to_tub * 1.25
		_place(_funnel_stream, CAROUSEL - to_tub * 0.75 + Vector3(0, 1.25, 0), carboy + Vector3(0, 1.45, 0) + to_tub * 0.1)
	_carboy_fill.scale = Vector3(1, maxf(_carboy, 0.02), 1)
	_carboy_rod.position.y = 1.3 + 0.32 * _carboy
	for k in _crate_nodes.size():
		_crate_nodes[k].visible = k < (_crates % 7)
	# The sensors.
	var speed := clampf(_shaft_w / 1.2, 0.0, 1.0)
	_gov_collar.position.y = 0.25 + 0.45 * speed
	var gov_at := _zy(-5.5, SHAFT + Vector2(0, 0.1))
	_place(_gov_lever, gov_at + Vector3(0, _gov_collar.position.y, -0.05), gov_at + Vector3(0, 0.78 + 0.12 * speed, -0.45))
	_tank_rod.position.y = 2.5 + 0.45 * _tank
	var float_y := 1.15 - 0.5 + 0.42 * _brew_level
	_cauldron_arm.rotation.z = clampf(atan2(float_y - 1.3, 0.38), -0.9, 0.3)
	_coil_pointer.rotation.z = 2.2 - 2.6 * _heat
	var flask_fill: float = _flasks[0] if _stepping < 0.0 else 0.0
	_flask_arm.rotation.x = -0.5 + 0.5 * flask_fill if _stepping < 0.0 else -0.9
	_reactor_rod.position.y = 1.36 + 0.6 * _reactor
	# The reactor: its contents, their colour, the stirrer and its motor,
	# the glowing coil, the tap's stream.
	_reactor_fill.scale = Vector3(1, maxf(_reactor * 0.95, 0.01), 1)
	_wheel = move_toward(_wheel, float(_doses) if _doses > 0 or _wheel < 3.0 else 4.0, get_process_delta_time() * 1.5)
	if _wheel >= 4.0:
		_wheel = 0.0
	var gold := clampf(_wheel / 3.0, 0.0, 1.0)
	var colour := BLUE.lerp(GOLD, gold)
	_tint.albedo_color = colour.darkened(0.2)
	_tint.emission = colour
	var stirring := _reactor > 0.02
	_stirrer.rotation.y += (2.5 if stirring else 0.0) * get_process_delta_time()
	_motor_gear.rotation.y = -_stirrer.rotation.y * 2.0
	_coil_glow.emission_energy_multiplier = 0.2 + (1.8 if stirring else 0.0) * (0.85 + 0.15 * sin(t * 3.0))
	_tap_stream.visible = _bottling
	# The linkage, by Chebyshev's geometry, and the ladle at its end.
	var b2 := Vector2(cos(_crank), sin(_crank)) * LS
	var c2 := LinkageHall._meet(b2, 2.5 * LS, Vector2(2.0 * LS, 0.0), 2.5 * LS, true)
	var p2 := b2 + (c2 - b2) * 2.0
	_place(_link_crank, _in_plane(Vector2.ZERO), _in_plane(b2))
	_place(_link_rocker, _in_plane(Vector2(2.0 * LS, 0.0)), _in_plane(c2))
	_place(_link_coupler, _in_plane(b2), _in_plane(p2))
	var deg := fposmod(rad_to_deg(_crank), 360.0)
	var tip := smoothstep(280.0, 300.0, deg) * (1.0 - smoothstep(318.0, 345.0, deg))
	_ladle.position = _in_plane(p2) + _side * OFFSET
	_place(_ladle_arm, _in_plane(p2), _ladle.position)
	_ladle.basis = Basis(_side, tip * 1.7)
	# The counting wheel, a quarter turn a dose; its cam up on the third.
	_count_wheel.basis = Basis(_side, -_wheel * PI * 0.5)
