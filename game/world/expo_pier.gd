class_name ExpoPier
extends Node3D
## The exposition's second half, out on the water: a pier from the
## exposition beach with a promenade down its middle, lamp posts and
## bunting along it, an arch at its landward end, a bandstand at its far
## end, and eighteen booths, nine down each side, built as the beach's are
## (CrystalExpo.booth_at) and facing the promenade, in three themes:
## - Sensing: a float valve keeping a cistern topped up; a governor
##   working a throttle; a bimetal thermostat working a flame; a balance
##   that tips and empties; a barometer; a weathervane and anemometer.
## - Light: a prism fanning a beam into colours; a turning lighthouse
##   lens; a heliograph signalling to a receiver; a glass light pipe; a
##   ring of mirrors bouncing a beam; a lantern clock.
## - Power: an overshot water wheel; a beam engine; a clockwork motor; a
##   windmill; a Stirling engine; a Pelton wheel.
## Each is moved every frame by its own small simulation (`_movers`). The
## pier's name, the booth names and notes are drafts.

const BEARING := 212.0
const DECK_Y := 0.9
const HALF_W := 8.1                      # half the pier's width
const WALK := 2.5                        # half the promenade's width
const START := 6.0                       # the first booths, along the pier from its landward end
const PITCH := 7.6                       # booth to booth along it
const LENGTH := 84.0

const NAMES := [
	"THE FLOAT VALVE", "THE PRISM", "THE WATER WHEEL",
	"THE GOVERNOR", "THE LIGHTHOUSE LENS", "THE BEAM ENGINE",
	"THE THERMOSTAT", "THE HELIOGRAPH", "THE CLOCKWORK MOTOR",
	"THE BALANCE", "THE LIGHT PIPE", "THE WINDMILL",
	"THE BAROMETER", "THE MIRROR RING", "THE STIRLING ENGINE",
	"THE WEATHERVANE", "THE LANTERN CLOCK", "THE PELTON WHEEL",
]
const NOTES := [
	"The Float Valve\nAs the cistern drains, its float drops and opens the inlet; as it fills, the float rises and shuts it again.",
	"The Prism\nWhite light bent by glass, each colour by its own amount, fanned out across the card.",
	"The Water Wheel\nWater poured into its buckets at the top weighs it round.",
	"The Governor\nAs the engine speeds up, the balls fly out and close the throttle; as it slows, they fall and open it.",
	"The Lighthouse Lens\nRings of glass gather the lamp's light into beams that sweep round as the lens turns.",
	"The Beam Engine\nThe piston rocks the great beam, and the beam turns the flywheel through the crank.",
	"The Thermostat\nTwo metals bonded together bend as they warm, and turn the flame down; cooling, they straighten and turn it up.",
	"The Heliograph\nA mirror and a shutter send flashes of light to the receiver across the way.",
	"The Clockwork Motor\nThe mainspring unwinds through the gears; the escapement lets it go one tooth at a time.",
	"The Balance\nSand pours into the pan; when it outweighs the weight, the beam tips and the pan empties.",
	"The Light Pipe\nLight carried along a coil of glass, kept inside by reflection, out to the crystal at its end.",
	"The Windmill\nThe sails turn in the wind; the cap turns them to face it.",
	"The Barometer\nThe weight of the air holds the column up; it falls before a storm.",
	"The Mirror Ring\nThree mirrors turning together throw a beam from one to another.",
	"The Stirling Engine\nAir heated in one cylinder and cooled in the other drives the two pistons round.",
	"The Weathervane\nThe vane points into the wind; the cups spin with its speed and the dial counts it.",
	"The Lantern Clock\nA turning drum of pegs opens the lanterns in turn, round and round.",
	"The Pelton Wheel\nA jet of water strikes the cups and spins the wheel fast.",
]

var expo: CrystalExpo
var booths: Array[Node3D] = []
var _movers: Array[Callable] = []
var _t := 0.0
var _beam_mat: StandardMaterial3D
var _frame: Node3D
var _lamp_globes: StandardMaterial3D


func _init(owner_expo: CrystalExpo) -> void:
	name = "ExpoPier"
	expo = owner_expo
	var island := owner_expo.island
	var a := deg_to_rad(BEARING)
	var d := Vector3(cos(a), 0.0, sin(a))
	# The shore's walls open along the pier and close its far end.
	var shore := d * (island.coast(a, -0.5) - 2.0)
	var end := d * (island.coast(a, 0.0) + LENGTH)
	island.piers.append([shore, end, HALF_W, true, false])


func _ready() -> void:
	var island := expo.island
	var a := deg_to_rad(BEARING)
	var d := Vector3(cos(a), 0.0, sin(a))
	var along := Vector3(-d.z, 0.0, d.x)
	var o := d * island.coast(a, 0.0)
	_frame = Node3D.new()
	add_child(_frame)
	_frame.global_transform = Transform3D(Basis(-along, Vector3.UP, d), Vector3(o.x, DECK_Y, o.z))
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.vertex_color_use_as_albedo = true
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_build_pier()
	var builders: Array[Callable] = [_float_valve, _prism, _water_wheel, _governor, _lighthouse, _beam_engine,
			_thermostat, _heliograph, _clockwork, _balance, _light_pipe, _windmill,
			_barometer, _mirror_ring, _stirling, _weathervane, _lantern_clock, _pelton]
	for i in builders.size():
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := START + PITCH * (i / 2) + 3.2
		var centre := Vector3(side * (WALK + 2.5 + 0.1), 0.08, z)
		# Each booth faces the promenade: its back to the pier's edge.
		var back := Vector3(side, 0, 0)
		var x_axis := Vector3.UP.cross(back)
		var local := Transform3D(Basis(x_axis, Vector3.UP, back), centre)
		var booth := expo.booth_at(_frame.global_transform * local, 30 + i, NAMES[i], NOTES[i], 0.08, _frame)
		booths.append(booth)
		var show := Node3D.new()
		show.position = Vector3(0, 0, -0.9)
		show.scale = Vector3.ONE * CrystalExpo.EXHIBIT_SCALE
		booth.add_child(show)
		builders[i].call(show)


func _process(delta: float) -> void:
	_t += delta
	for m in _movers:
		m.call(_t, delta)


## ---- the pier itself -----------------------------------------------------------

func _build_pier() -> void:
	var island := expo.island
	var m := CozyMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9393
	var tones := [Color(0.84, 0.74, 0.6), Color(0.78, 0.68, 0.56), Color(0.88, 0.8, 0.66), Color(0.74, 0.64, 0.52)]
	for k in int(LENGTH / 0.22):
		var z := 0.11 + k * 0.22
		m.box(Vector3(HALF_W * 2.0, 0.06, 0.2), CozyMesh.at(Vector3(0, -0.03, z)), (tones[rng.randi() % tones.size()] as Color).lightened(rng.randf_range(-0.05, 0.05)))
	for x: float in [-HALF_W, HALF_W]:
		m.box(Vector3(0.25, 0.35, LENGTH), CozyMesh.at(Vector3(x, -0.24, LENGTH * 0.5)), Color(0.5, 0.38, 0.28))
	# Piles down to the sea floor, in rows across.
	var rows := int(LENGTH / 6.0)
	for k in rows + 1:
		var z := k * LENGTH / rows
		for x: float in [-HALF_W + 0.3, -2.7, 2.7, HALF_W - 0.3]:
			m.cyl(0.16, 0.18, DECK_Y + 4.2, 10, CozyMesh.at(Vector3(x, -(DECK_Y + 4.2) * 0.5, z)), Color(0.42, 0.32, 0.24))
		m.box(Vector3(HALF_W * 2.0, 0.2, 0.25), CozyMesh.at(Vector3(0, -0.5, z)), Color(0.45, 0.34, 0.25))
	# The arch over the landward end.
	for x: float in [-2.8, 2.8]:
		m.box(Vector3(0.22, 3.6, 0.22), CozyMesh.at(Vector3(x, 1.8, 0.4)), Color(0.55, 0.42, 0.3))
		m.ball(0.17, 10, CozyMesh.at(Vector3(x, 3.7, 0.4)), Color(0.92, 0.72, 0.34))
	m.box(Vector3(6.2, 0.7, 0.14), CozyMesh.at(Vector3(0, 3.25, 0.4)), Color(0.5, 0.36, 0.26))
	m.box(Vector3(6.0, 0.56, 0.16), CozyMesh.at(Vector3(0, 3.25, 0.4)), CrystalExpo.CREAM)
	# The bandstand at the far end: an octagon of posts under a striped roof.
	var bs := Vector3(0, 0, LENGTH - 5.0)
	m.cyl(3.6, 3.6, 0.2, 8, CozyMesh.at(bs + Vector3(0, 0.1, 0)), Color(0.8, 0.7, 0.56))
	for k in 8:
		var ang := TAU * k / 8.0
		m.cyl(0.08, 0.08, 3.0, 8, CozyMesh.at(bs + Vector3(cos(ang) * 3.3, 1.6, sin(ang) * 3.3)), Color(0.92, 0.72, 0.34))
	for k in 8:
		var ang := TAU * k / 8.0
		m.prism(Vector3(2.7, 1.3, 0.05), CozyMesh.at(bs + Vector3(cos(ang + PI / 8.0) * 2.0, 3.55, sin(ang + PI / 8.0) * 2.0),
				Basis(Vector3.UP, -ang - PI / 8.0 + PI * 0.5) * Basis(Vector3.RIGHT, -0.55)), CrystalExpo.STRIPES[k % 4] if k % 2 == 0 else CrystalExpo.CREAM)
	m.ball(0.25, 10, CozyMesh.at(bs + Vector3(0, 4.25, 0)), Color(0.92, 0.72, 0.34))
	var view := MeshInstance3D.new()
	view.name = "Pier"
	view.mesh = m.commit(island.cozy_material())
	_frame.add_child(view)
	for face: float in [1.0, -1.0]:
		var sign := Label3D.new()
		sign.text = "THE EXPOSITION PIER"
		sign.font_size = 72
		sign.pixel_size = 0.0045
		sign.modulate = Color(0.32, 0.2, 0.14)
		sign.double_sided = false
		sign.position = Vector3(0, 3.25, 0.4 - 0.085 * face)
		sign.rotation.y = PI if face > 0.0 else 0.0
		_frame.add_child(sign)
	# What is walked on: the deck; a ramp up from the sand.
	var body := StaticBody3D.new()
	_frame.add_child(body)
	var deck := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HALF_W * 2.0, 0.3, LENGTH)
	deck.shape = box
	deck.position = Vector3(0, -0.15, LENGTH * 0.5)
	body.add_child(deck)
	var a := deg_to_rad(BEARING)
	var dd := Vector3(cos(a), 0.0, sin(a))
	var sand := dd * (island.coast(a, 0.0) - 3.5)
	var sand_y := island.height(sand.x, sand.z) + 0.03
	var ramp_from := _frame.to_local(Vector3(sand.x, sand_y, sand.z))
	var ramp_to := Vector3(0, 0, 0.0)
	var run := ramp_to - ramp_from
	var rm := CozyMesh.new()
	for k in int(run.length() / 0.2):
		rm.box(Vector3(5.0, 0.05, 0.18), CozyMesh.at(Vector3(0, -0.025, -run.length() * 0.5 + 0.1 + k * 0.2)), Color(0.8, 0.7, 0.56))
	var fwd := run.normalized()
	var x0 := Vector3.UP.cross(fwd).normalized()
	var rbasis := Basis(x0, fwd.cross(x0).normalized(), fwd)
	var rview := MeshInstance3D.new()
	rview.mesh = rm.commit(island.cozy_material())
	rview.transform = Transform3D(rbasis, (ramp_from + ramp_to) * 0.5)
	_frame.add_child(rview)
	var rshape := CollisionShape3D.new()
	var rbox := BoxShape3D.new()
	rbox.size = Vector3(5.0, 0.1, run.length())
	rshape.shape = rbox
	rshape.transform = Transform3D(rbasis, (ramp_from + ramp_to) * 0.5 + rbasis.y * -0.05)
	body.add_child(rshape)
	# Rails round the edge, a wall within them, open at the landward end.
	var brass: Material = expo.get("_brass")
	for e: Array in [[Vector3(-HALF_W, 0, 0.3), Vector3(-HALF_W, 0, LENGTH)], [Vector3(-HALF_W, 0, LENGTH), Vector3(HALF_W, 0, LENGTH)],
			[Vector3(HALF_W, 0, LENGTH), Vector3(HALF_W, 0, 0.3)], [Vector3(-HALF_W, 0, 0.3), Vector3(-2.6, 0, 0.3)], [Vector3(2.6, 0, 0.3), Vector3(HALF_W, 0, 0.3)]]:
		var p: Vector3 = e[0]
		var q: Vector3 = e[1]
		var posts := maxi(int(p.distance_to(q) / 2.4), 1)
		for k in posts + 1:
			expo._cyl(0.035, 0.045, 1.05, p.lerp(q, float(k) / posts) + Vector3(0, 0.525, 0), brass, 8, false, _frame)
		expo._rod(p + Vector3(0, 1.0, 0), q + Vector3(0, 1.0, 0), 0.02, brass, 6, _frame)
		expo._rod(p + Vector3(0, 0.55, 0), q + Vector3(0, 0.55, 0), 0.015, brass, 6, _frame)
		var wall := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = Vector3(p.distance_to(q), 1.4, 0.1)
		wall.shape = wb
		wall.transform = Transform3D(Basis(Vector3.UP, atan2(-(q - p).z, (q - p).x)), (p + q) * 0.5 + Vector3(0, 0.7, 0))
		body.add_child(wall)
	# Lamp posts down the promenade, bunting between them.
	_lamp_globes = ApparatusHall._liquid(Color(1.0, 0.86, 0.6), 0.6)
	var bunting := CozyMesh.new()
	var flags := [Color(0.93, 0.5, 0.42), Color(0.93, 0.74, 0.3), Color(0.3, 0.66, 0.66), CrystalExpo.CREAM, Color(0.68, 0.56, 0.84)]
	var lamps: Array[Vector3] = []
	for k in 10:
		var z := 3.0 + k * (LENGTH - 12.0) / 9.0
		for x: float in [-WALK + 0.2, WALK - 0.2]:
			var at := Vector3(x, 0, z)
			expo._cyl(0.05, 0.07, 3.2, at + Vector3(0, 1.6, 0), brass, 8, false, _frame)
			expo._ball(0.18, at + Vector3(0, 3.3, 0), _lamp_globes, _frame)
			lamps.append(at + Vector3(0, 3.0, 0))
	for k in lamps.size() - 2:
		var a2 := lamps[k]
		var b2 := lamps[k + 2]
		var count := int(a2.distance_to(b2) / 0.4)
		for n in range(1, count):
			var t := float(n) / count
			var p := a2.lerp(b2, t) + Vector3.DOWN * 0.5 * 4.0 * t * (1.0 - t)
			bunting.prism(Vector3(0.22, 0.26, 0.01), CozyMesh.at(p + Vector3.DOWN * 0.13, Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.FORWARD, PI)), flags[n % flags.size()])
	var bview := MeshInstance3D.new()
	bview.mesh = bunting.commit(island.cozy_material(false))
	bview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_frame.add_child(bview)
	_movers.append(func(_t2: float, _dt: float) -> void:
		_lamp_globes.emission_energy_multiplier = 0.4 + 3.0 * (1.0 - island.sky.daylight))


## ---- helpers ----------------------------------------------------------------

func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.set_meta(StaticMerge.MOVES, true)
	parent.add_child(n)
	return n


## Silvered glass, pale in both looks (wholly metallic, the cartoon look
## draws it dark).
func _mirror() -> Material:
	var m: StandardMaterial3D = expo.island.surface("", 1.0, Color(0.86, 0.9, 0.96), 0.08, Color(0.88, 0.94, 1.0), {"no_line": true})
	m.metallic = 0.5
	m.emission_enabled = true
	m.emission = Color(0.85, 0.92, 1.0)
	m.emission_energy_multiplier = 0.25
	return m


func _mat(name_: String) -> Material:
	return expo.get(name_)


func _sphere(r: float, at: Vector3, mat: Material, parent: Node3D, squash := Vector3.ONE) -> MeshInstance3D:
	var v := expo._ball(r, at, mat, parent)
	v.basis = Basis.from_scale(squash)
	return v


func _link(parent: Node3D, radius: float, mat: Material) -> MeshInstance3D:
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
	parent.add_child(view)
	return view


## A mesh of beams, redrawn each frame in `parent`'s frame.
func _beams(parent: Node3D) -> ImmediateMesh:
	var im := ImmediateMesh.new()
	var view := MeshInstance3D.new()
	view.mesh = im
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.extra_cull_margin = 64.0
	parent.add_child(view)
	return im


## Draws `beams` ([from, to, colour, width]) as ribbons turned to the eye.
func _draw(im: ImmediateMesh, parent: Node3D, beams: Array) -> void:
	im.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null or beams.is_empty():
		return
	var eye := parent.to_local(cam.global_position)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _beam_mat)
	for b: Array in beams:
		var a: Vector3 = b[0]
		var c: Vector3 = b[1]
		var cross := (c - a).cross(eye - a)
		if cross.length_squared() < 1e-8:
			continue
		var side := cross.normalized() * float(b[3])
		var col: Color = b[2]
		for v: Vector3 in [a - side, a + side, c + side, a - side, c + side, c - side]:
			im.surface_set_color(col)
			im.surface_add_vertex(v)
	im.surface_end()


func _stand(show: Node3D, at: Vector3, h: float) -> void:
	expo._cyl(0.22, 0.28, 0.08, at + Vector3(0, 0.04, 0), _mat("_brass"), 16, false, show)
	expo._cyl(0.05, 0.07, h, at + Vector3(0, h * 0.5, 0), _mat("_brass"), 10, false, show)


## ---- sensing --------------------------------------------------------------------

func _float_valve(show: Node3D) -> void:
	var glass: Material = _mat("_glass")
	var c := Vector3(0, 0, 0.6)
	expo._box(Vector3(1.2, 0.5, 1.2), c + Vector3(0, 0.25, 0), _mat("_wood"), true, show)
	expo._cyl(0.48, 0.48, 1.0, c + Vector3(0, 1.0, 0), glass, 24, false, show)
	expo._ring(0.47, 0.53, c + Vector3(0, 1.5, 0), _mat("_brass"), show)
	var water := ApparatusHall._liquid(Color(0.35, 0.7, 0.85), 0.3)
	var level_node := _pivot(show, c + Vector3(0, 0.51, 0))
	expo._cyl(0.45, 0.45, 1.0, Vector3(0, 0.5, 0), water, 24, false, level_node)
	# The inlet pipe and its valve over the rim; the float on its arm.
	var copper: Material = _mat("_copper")
	expo._rod(c + Vector3(-1.2, 2.1, 0), c + Vector3(-0.3, 2.1, 0), 0.04, copper, 8, show)
	expo._rod(c + Vector3(-1.2, 2.1, 0), c + Vector3(-1.2, 0.5, 0), 0.04, copper, 8, show)
	expo._rod(c + Vector3(-0.3, 2.1, 0), c + Vector3(-0.3, 1.75, 0), 0.04, copper, 8, show)
	expo._cyl(0.07, 0.07, 0.12, c + Vector3(-0.3, 1.72, 0), _mat("_brass"), 10, false, show)
	var arm := _pivot(show, c + Vector3(-0.3, 1.66, 0))
	expo._rod(Vector3.ZERO, Vector3(0.55, 0, 0), 0.012, _mat("_brass"), 6, arm)
	_sphere(0.1, Vector3(0.6, 0, 0), copper, arm)
	var stream := _link(show, 0.03, water)
	var drain := _link(show, 0.025, water)
	var st := [0.6]
	_movers.append(func(_t2: float, dt: float) -> void:
		var level: float = st[0]
		var open := clampf((0.75 - level) * 5.0, 0.0, 1.0)
		level = clampf(level + (0.12 * open - 0.05) * dt, 0.05, 1.0)
		st[0] = level
		level_node.scale = Vector3(1, maxf(level * 0.95, 0.01), 1)
		var surface := 0.51 + 0.95 * level
		arm.rotation.z = clampf(atan2(surface - 1.66, 0.6), -0.5, 0.3)
		stream.visible = open > 0.05
		TideWorks._place(stream, c + Vector3(-0.3, 1.66, 0), c + Vector3(-0.3, surface, 0))
		drain.visible = true
		TideWorks._place(drain, c + Vector3(0.48, 0.6, 0), c + Vector3(0.75, 0.0, 0)))


func _governor(show: Node3D) -> void:
	var brass: Material = _mat("_brass")
	var iron: Material = _mat("_iron")
	var c := Vector3(0, 0, 0.6)
	expo._box(Vector3(1.6, 0.4, 0.8), c + Vector3(0, 0.2, 0), iron, true, show)
	var fly := _pivot(show, c + Vector3(-0.5, 0.95, 0))
	expo._ring(0.48, 0.55, Vector3.ZERO, iron, fly, Basis(Vector3.RIGHT, PI * 0.5))
	for k in 6:
		var a := TAU * k / 6.0
		expo._rod(Vector3.ZERO, Vector3(cos(a), sin(a), 0) * 0.5, 0.025, iron, 6, fly)
	var spin := _pivot(show, c + Vector3(0.4, 0.4, 0))
	expo._cyl(0.025, 0.025, 1.6, Vector3(0, 0.8, 0), brass, 8, false, spin)
	var arms: Array[Node3D] = []
	for s in [-1.0, 1.0]:
		var arm := _pivot(spin, Vector3(0, 1.6, 0))
		expo._rod(Vector3.ZERO, Vector3(0, -0.5, 0), 0.015, brass, 4, arm)
		_sphere(0.1, Vector3(0, -0.53, 0), brass, arm)
		arm.set_meta("s", s)
		arms.append(arm)
	var sleeve := _pivot(spin, Vector3(0, 1.0, 0))
	expo._ring(0.035, 0.07, Vector3.ZERO, brass, sleeve)
	# The throttle: a butterfly in a pipe, worked by a lever from the sleeve.
	var pipe := c + Vector3(1.1, 1.2, 0)
	expo._cyl(0.09, 0.09, 0.8, pipe, _mat("_copper"), 12, false, show)
	var butterfly := _pivot(show, pipe)
	expo._cyl(0.085, 0.085, 0.01, Vector3.ZERO, brass, 12, false, butterfly)
	var lever := _link(show, 0.015, brass)
	var st := [0.5, 0.0]                  # speed, the flywheel's angle
	_movers.append(func(t: float, dt: float) -> void:
		var speed: float = st[0]
		var lift := clampf((speed - 0.3) * 1.2, 0.0, 0.6)
		var throttle := 1.0 - lift / 0.6
		var demand := 0.5 + 0.3 * sin(t * 0.3)
		speed = maxf(speed + (1.2 * throttle - demand * speed * 1.4) * dt, 0.0)
		st[0] = speed
		st[1] = float(st[1]) + speed * 4.0 * dt
		fly.rotation.z = st[1]
		spin.rotation.y += speed * 6.0 * dt
		for arm in arms:
			arm.rotation.z = float(arm.get_meta("s")) * (0.25 + lift * 1.3)
		sleeve.position.y = 1.0 + lift * 0.4
		butterfly.rotation.z = throttle * PI * 0.5
		TideWorks._place(lever, c + Vector3(0.45, 1.4 + lift * 0.4, 0), pipe + Vector3(0, 0.12, 0)))


func _thermostat(show: Node3D) -> void:
	var c := Vector3(0, 0, 0.6)
	var iron: Material = _mat("_iron")
	expo._cyl(0.35, 0.25, 0.25, c + Vector3(0, 0.5, 0), iron, 16, false, show)
	for k in 3:
		var a := TAU * k / 3.0
		expo._rod(c + Vector3(cos(a) * 0.3, 0.4, sin(a) * 0.3), c + Vector3(cos(a) * 0.38, 0.0, sin(a) * 0.38), 0.02, iron, 4, show)
	var flame := ApparatusHall._embers(2.0)
	var flames: Array[Node3D] = []
	for k in 5:
		var f := _pivot(show, c + Vector3(cos(k * 1.3) * 0.15, 0.68, sin(k * 1.3) * 0.15))
		expo._cyl(0.0, 0.07, 0.3, Vector3(0, 0.15, 0), flame, 8, false, f)
		flames.append(f)
	# The strip of two metals over the flame, bending as it heats.
	var strip_parts: Array[Node3D] = []
	var root := _pivot(show, c + Vector3(-0.5, 1.4, 0))
	expo._box(Vector3(0.12, 0.2, 0.12), Vector3(0, 0.05, 0), iron, false, root)
	var prev := root
	for k in 8:
		var seg := _pivot(prev, Vector3(0.12, 0, 0) if k > 0 else Vector3(0.06, 0, 0))
		expo._box(Vector3(0.12, 0.02, 0.06), Vector3(0.06, 0.01, 0), _mat("_copper"), false, seg)
		expo._box(Vector3(0.12, 0.02, 0.06), Vector3(0.06, -0.01, 0), _mat("_silver"), false, seg)
		strip_parts.append(seg)
		prev = seg
	expo._box(Vector3(0.05, 1.4, 0.05), c + Vector3(-0.5, 0.7, 0), iron, false, show)
	var st := [0.3]
	_movers.append(func(t: float, dt: float) -> void:
		var temp: float = st[0]
		var bend := temp * 0.09
		var flame_size := 1.0 if temp < 0.6 else 0.3
		temp = clampf(temp + (0.12 * flame_size - 0.06) * dt, 0.0, 1.0)
		st[0] = temp
		for seg in strip_parts:
			seg.rotation.z = -bend
		flame.emission_energy_multiplier = 0.5 + 2.5 * flame_size
		for f in flames:
			f.scale = Vector3(1, (0.4 + 0.6 * flame_size) * (0.9 + 0.1 * sin(t * 12.0 + f.position.x * 30.0)), 1))


func _balance(show: Node3D) -> void:
	var brass: Material = _mat("_brass")
	var c := Vector3(0, 0, 0.6)
	_stand(show, c, 1.5)
	var beam := _pivot(show, c + Vector3(0, 1.55, 0))
	expo._box(Vector3(1.6, 0.05, 0.06), Vector3.ZERO, brass, false, beam)
	expo._cyl(0.03, 0.06, 0.15, Vector3(0, 0.08, 0), brass, 8, false, beam)
	var pans: Array[Node3D] = []
	for s in [-1.0, 1.0]:
		var pan := _pivot(show, c + Vector3(s * 0.8, 1.1, 0))
		expo._cyl(0.22, 0.16, 0.06, Vector3.ZERO, brass, 16, false, pan)
		for k in 3:
			var a := TAU * k / 3.0
			expo._rod(Vector3(cos(a) * 0.2, 0.03, sin(a) * 0.2), Vector3(0, 0.45, 0), 0.005, brass, 4, pan)
		pans.append(pan)
	expo._box(Vector3(0.14, 0.14, 0.14), Vector3(0, 0.1, 0), _mat("_iron"), false, pans[0])
	var sand: Material = expo.island.surface("sand", 0.5, Color(1.0, 0.97, 0.92), 0.9, Color(0.98, 0.87, 0.64))
	var heap := _pivot(pans[1], Vector3(0, 0.04, 0))
	_sphere(0.16, Vector3.ZERO, sand, heap, Vector3(1, 0.4, 1))
	var hopper := c + Vector3(0.8, 2.1, 0)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.2
	cone.bottom_radius = 0.04
	cone.height = 0.3
	cone.material = _mat("_copper")
	expo._put(cone, hopper, false, Vector3.ZERO, show)
	expo._rod(hopper + Vector3(0, 0.15, 0), c + Vector3(0.8, 2.6, 0.0) + Vector3(0, 0, 0.3), 0.02, brass, 4, show)
	var stream := _link(show, 0.015, sand)
	var st := [0.0, 0.0]                  # sand in the pan, tipped time
	_movers.append(func(_t2: float, dt: float) -> void:
		var pile: float = st[0]
		var tipped: float = st[1]
		if tipped > 0.0:
			tipped -= dt
			pile = maxf(pile - 0.8 * dt, 0.0)
		else:
			pile += 0.08 * dt
			if pile >= 1.0:
				tipped = 1.5
		st[0] = pile
		st[1] = tipped
		var tilt := clampf((pile - 0.85) * 2.0, -0.25, 0.25)
		beam.rotation.z = -tilt
		pans[0].position.y = 1.1 + tilt * 0.8
		pans[1].position.y = 1.1 - tilt * 0.8
		pans[1].rotation.z = 0.8 if tipped > 0.0 else 0.0
		heap.scale = Vector3.ONE * maxf(pile, 0.05)
		stream.visible = tipped <= 0.0
		TideWorks._place(stream, hopper - Vector3(0, 0.15, 0), pans[1].position + Vector3(0, 0.05, 0)))


func _barometer(show: Node3D) -> void:
	var c := Vector3(0, 0, 1.2)
	var wood: Material = _mat("_wood")
	expo._box(Vector3(0.5, 2.2, 0.06), c + Vector3(-0.4, 1.4, 0.05), wood, true, show)
	for k in 11:
		expo._box(Vector3(0.12, 0.01, 0.01), c + Vector3(-0.32, 1.2 + k * 0.08, -0.01), _mat("_brass"), false, show)
	expo._cyl(0.025, 0.025, 1.6, c + Vector3(-0.45, 1.4, -0.04), _mat("_glass"), 8, false, show)
	expo._cyl(0.1, 0.12, 0.12, c + Vector3(-0.45, 0.6, -0.04), _mat("_glass"), 12, false, show)
	var mercury := StandardMaterial3D.new()
	mercury.albedo_color = Color(0.8, 0.82, 0.86)
	mercury.metallic = 0.9
	mercury.roughness = 0.15
	var column := _pivot(show, c + Vector3(-0.45, 0.62, -0.04))
	expo._cyl(0.018, 0.018, 1.0, Vector3(0, 0.5, 0), mercury, 6, false, column)
	# An aneroid dial beside it, its needle following.
	var dial := c + Vector3(0.45, 1.5, -0.02)
	expo._cyl(0.3, 0.3, 0.05, dial, expo.island.surface("", 1.0, Color(0.9, 0.88, 0.82), 0.6, Color(0.96, 0.94, 0.9)), 24, false, show).basis = Basis(Vector3.RIGHT, PI * 0.5)
	expo._ring(0.29, 0.34, dial, _mat("_brass"), show, Basis(Vector3.RIGHT, PI * 0.5))
	var needle := _pivot(show, dial + Vector3(0, 0, -0.04))
	expo._box(Vector3(0.015, 0.25, 0.005), Vector3(0, 0.11, 0), _mat("_iron"), false, needle)
	expo._box(Vector3(0.4, 1.2, 0.3), c + Vector3(0.45, 0.6, 0.1), wood, false, show)
	_movers.append(func(t: float, _dt: float) -> void:
		var p := 0.5 + 0.35 * sin(t * 0.13) + 0.1 * sin(t * 0.41)
		column.scale = Vector3(1, 0.7 + 0.5 * p, 1)
		needle.rotation.z = 1.4 - 2.8 * p)


func _weathervane(show: Node3D) -> void:
	var brass: Material = _mat("_brass")
	var c := Vector3(0, 0, 0.6)
	_stand(show, c, 2.4)
	var vane := _pivot(show, c + Vector3(0, 2.5, 0))
	expo._rod(Vector3(0, 0, -0.5), Vector3(0, 0, 0.6), 0.015, brass, 6, vane)
	expo._box(Vector3(0.02, 0.3, 0.35), Vector3(0, 0.05, 0.5), _mat("_copper"), false, vane)
	var arrow := CylinderMesh.new()
	arrow.top_radius = 0.0
	arrow.bottom_radius = 0.06
	arrow.height = 0.16
	arrow.material = _mat("_copper")
	expo._put(arrow, Vector3(0, 0, -0.55), false, Vector3.ZERO, vane).basis = Basis(Vector3.RIGHT, -PI * 0.5)
	var cups := _pivot(show, c + Vector3(0, 2.15, 0))
	for k in 3:
		var a := TAU * k / 3.0
		expo._rod(Vector3.ZERO, Vector3(cos(a), 0, sin(a)) * 0.35, 0.01, brass, 4, cups)
		var cup := SphereMesh.new()
		cup.radius = 0.07
		cup.height = 0.07
		cup.is_hemisphere = true
		cup.material = _mat("_copper")
		expo._put(cup, Vector3(cos(a), 0, sin(a)) * 0.38, false, Vector3.ZERO, cups).basis = Basis(Vector3.UP, -a) * Basis(Vector3.FORWARD, PI * 0.5)
	# The counting dial at the foot.
	var dial := c + Vector3(0.4, 1.0, -0.15)
	expo._box(Vector3(0.36, 0.36, 0.05), dial, _mat("_wood"), false, show)
	var hand := _pivot(show, dial + Vector3(0, 0, -0.04))
	expo._box(Vector3(0.015, 0.15, 0.005), Vector3(0, 0.07, 0), brass, false, hand)
	var noise := FastNoiseLite.new()
	noise.seed = 77
	var st := [0.0]
	_movers.append(func(t: float, dt: float) -> void:
		var wind := 0.6 + 0.4 * noise.get_noise_1d(t * 8.0)
		vane.rotation.y = lerp_angle(vane.rotation.y, 1.5 * noise.get_noise_1d(t * 0.6 + 100.0), 1.0 - exp(-1.5 * dt))
		cups.rotation.y += wind * 8.0 * dt
		st[0] = float(st[0]) + wind * dt
		hand.rotation.z = -float(st[0]) * 0.4)


## ---- light ----------------------------------------------------------------------

func _prism(show: Node3D) -> void:
	var c := Vector3(0, 0, 0.6)
	_stand(show, c + Vector3(-1.2, 0, 0), 1.1)
	expo._box(Vector3(0.3, 0.25, 0.25), c + Vector3(-1.2, 1.25, 0), _mat("_brass"), false, show)
	_stand(show, c, 1.1)
	# The prism lies on its side so the colours fan out up the card.
	var prism := _pivot(show, c + Vector3(0, 1.3, 0))
	var glass := CylinderMesh.new()
	glass.top_radius = 0.18
	glass.bottom_radius = 0.18
	glass.height = 0.4
	glass.radial_segments = 3
	glass.rings = 1
	glass.material = _mat("_glass")
	expo._put(glass, Vector3.ZERO, false, Vector3.ZERO, prism).basis = Basis(Vector3.RIGHT, PI * 0.5)
	# The card the colours fall on.
	var card := c + Vector3(1.3, 1.3, 0)
	expo._box(Vector3(0.04, 1.0, 1.2), card, expo.island.surface("", 1.0, Color(0.92, 0.9, 0.86), 0.9, Color(0.98, 0.96, 0.92)), false, show)
	expo._box(Vector3(0.06, 1.3, 0.06), card + Vector3(0, -0.65, 0), _mat("_wood"), false, show)
	var im := _beams(show)
	var colours := [Color(0.9, 0.15, 0.1), Color(1.0, 0.5, 0.1), Color(1.0, 0.9, 0.2), Color(0.2, 0.85, 0.3), Color(0.2, 0.4, 1.0), Color(0.55, 0.2, 0.85)]
	_movers.append(func(t: float, _dt: float) -> void:
		var turn := 0.15 * sin(t * 0.4)
		prism.rotation.z = turn
		var beams := [[c + Vector3(-1.05, 1.28, 0), c + Vector3(-0.08, 1.3, 0), Color(1, 1, 1) * 0.8, 0.035]]
		for k in 6:
			var spread := (k - 2.5) * (0.08 + 0.02 * sin(t * 0.4)) + turn
			beams.append([c + Vector3(0.08, 1.3, 0), card + Vector3(-0.03, spread * 1.3, 0), colours[k] * 1.2, 0.035])
		_draw(im, show, beams))


func _lighthouse(show: Node3D) -> void:
	var c := Vector3(0, 0, 0.8)
	expo._cyl(0.5, 0.6, 1.0, c + Vector3(0, 0.5, 0), _mat("_iron"), 16, true, show)
	var lamp := ApparatusHall._liquid(Color(1.0, 0.92, 0.7), 4.0)
	expo._ball(0.12, c + Vector3(0, 1.55, 0), lamp, show)
	var drum := _pivot(show, c + Vector3(0, 1.55, 0))
	for k in 7:
		var y := -0.35 + k * 0.12
		var r := 0.42 - absf(k - 3) * 0.03
		expo._ring(r - 0.02, r + 0.02, Vector3(0, y, 0), _mat("_glass"), drum)
	for k in 4:
		var a := TAU * k / 4.0
		expo._rod(Vector3(cos(a), -0.45, sin(a)) * 0.44 + Vector3(0, -0.45, 0) * 0.0, Vector3(cos(a) * 0.44, 0.45, sin(a) * 0.44), 0.015, _mat("_brass"), 4, drum)
	var dome := SphereMesh.new()
	dome.radius = 0.5
	dome.height = 0.5
	dome.is_hemisphere = true
	dome.material = _mat("_copper")
	expo._put(dome, c + Vector3(0, 2.05, 0), false, Vector3.ZERO, show)
	var im := _beams(show)
	_movers.append(func(t: float, _dt: float) -> void:
		var a := t * 0.7
		drum.rotation.y = a
		var beams := []
		for k in 2:
			var d := Vector3(cos(a + PI * k), 0, sin(a + PI * k))
			beams.append([c + Vector3(0, 1.55, 0) + d * 0.4, c + Vector3(0, 1.55, 0) + d * 3.0, Color(1.0, 0.92, 0.7) * 0.35, 0.12])
		_draw(im, show, beams))


func _heliograph(show: Node3D) -> void:
	var c := Vector3(-1.2, 0, 0.4)
	for k in 3:
		var a := TAU * k / 3.0
		expo._rod(c + Vector3(cos(a) * 0.4, 0, sin(a) * 0.4), c + Vector3(0, 1.3, 0), 0.02, _mat("_wood"), 6, show)
	expo._box(Vector3(0.36, 0.36, 0.02), c + Vector3(0, 1.45, 0), _mirror(), false, show).basis = Basis(Vector3.UP, 0.3)
	var shutter: Array[Node3D] = []
	for k in 4:
		var louvre := _pivot(show, c + Vector3(0.35, 1.32 + k * 0.08, 0))
		expo._box(Vector3(0.02, 0.07, 0.36), Vector3.ZERO, _mat("_brass"), false, louvre)
		shutter.append(louvre)
	var rx := Vector3(1.3, 1.4, 1.0)
	_stand(show, rx - Vector3(0, 1.4, 0), 1.25)
	expo._ring(0.12, 0.16, rx, _mat("_brass"), show, Basis(Vector3.BACK, PI * 0.5))
	var lens := ApparatusHall._liquid(Color(1.0, 0.95, 0.75), 0.4)
	expo._cyl(0.12, 0.12, 0.02, rx, lens, 16, false, show).basis = Basis(Vector3.BACK, PI * 0.5)
	var im := _beams(show)
	var pattern := [1, 0, 1, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0]
	_movers.append(func(t: float, _dt: float) -> void:
		var open: bool = pattern[int(t * 3.0) % pattern.size()] == 1
		for l in shutter:
			l.rotation.z = 0.0 if open else PI * 0.5
		lens.emission_energy_multiplier = 3.0 if open else 0.3
		_draw(im, show, [[c + Vector3(0.0, 1.45, 0), rx, Color(1.0, 0.95, 0.75) * 0.5, 0.05]] if open else []))


func _light_pipe(show: Node3D) -> void:
	var c := Vector3(0, 0, 0.8)
	_stand(show, c, 0.6)
	var lamp := ApparatusHall._liquid(Color(1.0, 0.9, 0.6), 2.0)
	expo._ball(0.1, c + Vector3(-0.9, 0.9, 0), lamp, show)
	expo._box(Vector3(0.12, 0.9, 0.12), c + Vector3(-0.9, 0.45, 0), _mat("_brass"), false, show)
	# The coil: a spiral of glass up and round.
	var path: Array[Vector3] = []
	path.append(c + Vector3(-0.8, 0.9, 0))
	for k in 81:
		var f := float(k) / 80.0
		var a := f * TAU * 3.0
		path.append(c + Vector3(cos(a) * 0.45 - 0.0, 0.7 + f * 1.3, sin(a) * 0.45))
	path.append(c + Vector3(0.9, 2.1, 0))
	for k in path.size() - 1:
		expo._rod(path[k], path[k + 1], 0.02, _mat("_glass"), 5, show)
	var crystal_mat := ApparatusHall._liquid(Color(1.0, 0.85, 0.4), 0.3)
	var gem := SphereMesh.new()
	gem.radius = 0.12
	gem.height = 0.24
	gem.radial_segments = 6
	gem.rings = 3
	gem.material = crystal_mat
	expo._put(gem, c + Vector3(1.0, 2.1, 0), false, Vector3.ZERO, show)
	expo._ring(0.1, 0.13, c + Vector3(1.0, 2.0, 0), _mat("_brass"), show)
	expo._box(Vector3(0.05, 2.0, 0.05), c + Vector3(1.0, 1.0, 0), _mat("_brass"), false, show)
	var pulse_mat := ApparatusHall._liquid(Color(1.0, 0.95, 0.7), 4.0)
	var pulses: Array[Node3D] = []
	for k in 3:
		var p := _pivot(show, path[0])
		expo._ball(0.035, Vector3.ZERO, pulse_mat, p)
		pulses.append(p)
	_movers.append(func(t: float, _dt: float) -> void:
		var lit := false
		for k in pulses.size():
			var f := fposmod(t * 0.25 + k / 3.0, 1.0)
			var idx := f * (path.size() - 1)
			var i := int(idx)
			pulses[k].position = path[i].lerp(path[mini(i + 1, path.size() - 1)], idx - i)
			lit = lit or f > 0.9
		crystal_mat.emission_energy_multiplier = 4.0 if lit else 0.3)


func _mirror_ring(show: Node3D) -> void:
	var c := Vector3(0, 0, 0.7)
	expo._cyl(0.9, 0.95, 0.9, c + Vector3(0, 0.45, 0), _mat("_wood"), 24, true, show)
	var table := _pivot(show, c + Vector3(0, 0.92, 0))
	expo._cyl(0.85, 0.85, 0.04, Vector3.ZERO, _mat("_brass"), 32, false, table)
	var corners: Array[Vector2] = []
	for k in 3:
		var a := TAU * k / 3.0 + PI * 0.5
		corners.append(Vector2(cos(a), sin(a)) * 0.7)
	for k in 3:
		var p: Vector2 = corners[k]
		var q: Vector2 = corners[(k + 1) % 3]
		var mid := (p + q) * 0.5
		var mirror := expo._box(Vector3(p.distance_to(q) * 0.9, 0.3, 0.02), Vector3(mid.x, 0.18, mid.y), _mirror(), false, table)
		mirror.basis = Basis(Vector3.UP, -atan2(q.y - p.y, q.x - p.x))
	var lamp := ApparatusHall._liquid(Color(0.6, 0.9, 1.0), 2.0)
	expo._ball(0.06, c + Vector3(-1.4, 1.1, 0), lamp, show)
	_stand(show, c + Vector3(-1.4, 0, 0), 1.0)
	var im := _beams(show)
	_movers.append(func(t: float, _dt: float) -> void:
		var spin := t * 0.3
		table.rotation.y = spin
		# The beam enters through a gap at one corner and bounces round
		# the triangle of mirrors (2D, in the table's plane).
		var segs: Array[Array] = []
		for k in 3:
			var p: Vector2 = corners[k].rotated(-spin)
			var q: Vector2 = corners[(k + 1) % 3].rotated(-spin)
			segs.append([p.lerp(q, 0.05), p.lerp(q, 0.95)])
		var o := Vector2(-1.4, 0.0)
		var d := Vector2(1.0, 0.12 * sin(t * 0.5)).normalized()
		var beams := []
		var y := 1.1
		for bounce in 9:
			var best := INF
			var hit := Vector2.ZERO
			var n := Vector2.ZERO
			for sg: Array in segs:
				var a: Vector2 = sg[0]
				var b: Vector2 = sg[1]
				var e := b - a
				var den := d.cross(e)
				if absf(den) < 1e-5:
					continue
				var tt := (a - o).cross(e) / den
				var u := (a - o).cross(d) / den
				if tt > 0.01 and u >= 0.0 and u <= 1.0 and tt < best:
					best = tt
					hit = o + d * tt
					n = Vector2(-e.y, e.x).normalized()
			if best == INF:
				beams.append([c + Vector3(o.x, y, o.y), c + Vector3(o.x + d.x * 2.0, y, o.y + d.y * 2.0), Color(0.6, 0.9, 1.0) * 0.9, 0.03])
				break
			beams.append([c + Vector3(o.x, y, o.y), c + Vector3(hit.x, y, hit.y), Color(0.6, 0.9, 1.0) * 1.0, 0.03])
			o = hit
			d = d - 2.0 * d.dot(n) * n
		_draw(im, show, beams))


func _lantern_clock(show: Node3D) -> void:
	var c := Vector3(0, 0, 0.8)
	_stand(show, c, 0.9)
	# The pegged drum turning in a frame.
	var drum := _pivot(show, c + Vector3(0, 1.05, 0))
	expo._cyl(0.18, 0.18, 0.6, Vector3.ZERO, _mat("_copper"), 16, false, drum).basis = Basis(Vector3.BACK, PI * 0.5)
	var pegs := [[0, 0.0], [1, 0.4], [2, 0.8], [3, 1.2], [4, 1.6], [5, 2.0], [6, 2.4], [7, 2.8], [0, 3.6], [4, 4.4]]
	for pg: Array in pegs:
		var x := -0.26 + float(pg[0]) * 0.075
		var a := float(pg[1])
		expo._cyl(0.012, 0.012, 0.06, Vector3(x, cos(a) * 0.2, sin(a) * 0.2), _mat("_brass"), 6, false, drum).basis = Basis(Vector3.RIGHT, a)
	# A ring of lanterns round it, each opened by its pegs.
	var lanterns: Array[LumenPart] = []
	for k in 8:
		var a := TAU * k / 8.0
		var at := c + Vector3(cos(a) * 1.1, 1.5 + 0.3 * sin(a), sin(a) * 0.9)
		expo._rod(c + Vector3(0, 1.0, 0), at - Vector3(0, 0.15, 0), 0.012, _mat("_brass"), 4, show)
		var lamp := LumenPart.new(LumenPart.Kind.LANTERN, "a lantern of the clock", at, 0.0, _mat("_wood"), _mat("_brass"), 0.0,
				{"post": false, "lamp": "drum", "metal": _mat("_brass")})
		show.add_child(lamp)
		lanterns.append(lamp)
	_movers.append(func(t: float, dt: float) -> void:
		var turn := t * 0.6
		drum.rotation.x = turn
		var a := fposmod(turn, TAU)
		for k in lanterns.size():
			var on := false
			for pg: Array in pegs:
				if int(pg[0]) == k and absf(angle_difference(a, float(pg[1]))) < 0.25:
					on = true
			lanterns[k].condition = on
			lanterns[k].evaluate(dt))


## ---- power ------------------------------------------------------------------------

func _water_wheel(show: Node3D) -> void:
	var c := Vector3(0, 0, 0.8)
	var water := ApparatusHall._liquid(Color(0.35, 0.7, 0.85), 0.3)
	expo._box(Vector3(2.0, 0.3, 1.0), c + Vector3(0, 0.15, 0), _mat("_iron"), true, show)
	expo._box(Vector3(1.8, 0.04, 0.8), c + Vector3(0, 0.3, 0), water, false, show)
	var wheel := _pivot(show, c + Vector3(0, 1.3, 0))
	var face := Basis(Vector3.RIGHT, PI * 0.5)
	for z in [-0.18, 0.18]:
		expo._ring(0.82, 0.88, Vector3(0, 0, z), _mat("_wood"), wheel, face)
	for k in 12:
		var a := TAU * k / 12.0
		expo._rod(Vector3.ZERO, Vector3(cos(a), sin(a), 0) * 0.85, 0.025, _mat("_wood"), 4, wheel)
		var bucket := expo._box(Vector3(0.16, 0.12, 0.36), Vector3(cos(a), sin(a), 0) * 0.92, _mat("_copper"), false, wheel)
		bucket.basis = Basis(Vector3.BACK, a)
	for side in [-1.0, 1.0]:
		expo._box(Vector3(0.1, 1.4, 0.1), c + Vector3(0, 0.7, side * 0.35), _mat("_wood"), false, show)
	# The flume over the top and the water falling into the buckets.
	expo._box(Vector3(1.3, 0.12, 0.3), c + Vector3(-0.8, 2.3, 0), _mat("_wood"), false, show)
	expo._box(Vector3(0.1, 2.3, 0.1), c + Vector3(-1.4, 1.15, 0), _mat("_wood"), false, show)
	var stream := _link(show, 0.06, water)
	TideWorks._place(stream, c + Vector3(-0.15, 2.28, 0), c + Vector3(0.15, 2.05, 0))
	_movers.append(func(t: float, _dt: float) -> void: wheel.rotation.z = -t * 0.8)


func _beam_engine(show: Node3D) -> void:
	var brass: Material = _mat("_brass")
	var iron: Material = _mat("_iron")
	var c := Vector3(0, 0, 0.8)
	expo._box(Vector3(2.4, 0.3, 0.9), c + Vector3(0, 0.15, 0), iron, true, show)
	# The cylinder at the left, the column and beam, the flywheel at right.
	var cyl := c + Vector3(-0.9, 0.85, 0)
	expo._cyl(0.18, 0.18, 0.9, cyl, _mat("_copper"), 16, false, show)
	expo._box(Vector3(0.2, 1.9, 0.2), c + Vector3(0, 1.1, 0), brass, false, show)
	var pivot := c + Vector3(0, 2.05, 0)
	var beam := _pivot(show, pivot)
	expo._box(Vector3(1.9, 0.08, 0.08), Vector3.ZERO, iron, false, beam)
	var fly_c := c + Vector3(0.9, 0.9, 0.2)
	var fly := _pivot(show, fly_c)
	expo._ring(0.5, 0.58, Vector3.ZERO, iron, fly, Basis(Vector3.RIGHT, PI * 0.5))
	for k in 6:
		var a := TAU * k / 6.0
		expo._rod(Vector3.ZERO, Vector3(cos(a), sin(a), 0) * 0.52, 0.025, iron, 4, fly)
	var rod := _link(show, 0.022, iron)
	var piston_rod := _link(show, 0.02, brass)
	var crank_r := 0.25
	var rod_len := 1.1
	_movers.append(func(t: float, _dt: float) -> void:
		var a := t * 1.4
		fly.rotation.z = a
		var pin := Vector2(fly_c.x, fly_c.y) + Vector2(cos(a), sin(a)) * crank_r
		var end2 := LinkageHall._meet(Vector2(pivot.x, pivot.y), 0.9, pin, rod_len, false)
		var ang := atan2(end2.y - pivot.y, end2.x - pivot.x)
		beam.rotation.z = ang
		TideWorks._place(rod, Vector3(end2.x, end2.y, fly_c.z), Vector3(pin.x, pin.y, fly_c.z))
		var left := Vector3(pivot.x - 0.9 * cos(ang), pivot.y - 0.9 * sin(ang), 0.0 + c.z)
		TideWorks._place(piston_rod, left, Vector3(cyl.x, cyl.y + 0.3, c.z)))


func _clockwork(show: Node3D) -> void:
	var c := Vector3(0, 0, 1.2)
	expo._box(Vector3(2.0, 1.8, 0.06), c + Vector3(0, 1.4, 0.05), _mat("_wood"), true, show)
	# The mainspring: a spiral in its barrel, unwinding.
	var barrel := c + Vector3(-0.55, 1.4, -0.05)
	expo._ring(0.32, 0.36, barrel, _mat("_brass"), show, Basis(Vector3.RIGHT, PI * 0.5))
	var spring := _pivot(show, barrel)
	var m := CozyMesh.new()
	for k in 120:
		var a := k * 0.18
		var r := 0.05 + k * 0.0022
		m.box(Vector3(0.012, 0.03, 0.01), CozyMesh.at(Vector3(cos(a) * r, sin(a) * r, 0), Basis(Vector3.BACK, a)), Color(0.75, 0.75, 0.8))
	var sv := MeshInstance3D.new()
	sv.mesh = m.commit(_mat("_silver"))
	spring.add_child(sv)
	# The escape wheel and the balance wheel.
	var esc := _pivot(show, c + Vector3(0.25, 1.6, -0.05))
	var esc_mesh := MeshInstance3D.new()
	esc_mesh.mesh = LinkageHall._plate(func(a: float) -> float: return 0.14 + 0.03 * fposmod(a * 15.0 / TAU, 1.0), 0.02, 150)
	esc_mesh.material_override = _mat("_brass")
	esc.add_child(esc_mesh)
	var balance := _pivot(show, c + Vector3(0.6, 1.05, -0.06))
	expo._ring(0.2, 0.23, Vector3.ZERO, _mat("_copper"), balance, Basis(Vector3.RIGHT, PI * 0.5))
	expo._box(Vector3(0.42, 0.02, 0.01), Vector3.ZERO, _mat("_copper"), false, balance)
	var anchor := _pivot(show, c + Vector3(0.25, 1.85, -0.07))
	expo._box(Vector3(0.3, 0.03, 0.01), Vector3(0, -0.05, 0), _mat("_iron"), false, anchor)
	_movers.append(func(t: float, _dt: float) -> void:
		var tick := floorf(t * 4.0)
		esc.rotation.z = -tick * TAU / 15.0 * 0.5
		balance.rotation.z = 1.4 * sin(t * PI * 2.0)
		anchor.rotation.z = 0.2 * signf(sin(t * PI * 2.0))
		spring.rotation.z = -t * 0.05)


func _windmill(show: Node3D) -> void:
	var c := Vector3(0, 0, 0.8)
	expo._cyl(0.2, 0.3, 1.2, c + Vector3(0, 0.6, 0), _mat("_wood"), 8, true, show)
	var cap := _pivot(show, c + Vector3(0, 1.2, 0))
	expo._box(Vector3(0.7, 0.7, 0.9), Vector3(0, 0.35, 0), expo.island.surface("", 1.0, Color(0.9, 0.86, 0.8), 0.9, Color(0.95, 0.9, 0.82)), false, cap)
	var roof := PrismMesh.new()
	roof.size = Vector3(0.8, 0.35, 1.0)
	roof.material = _mat("_copper")
	expo._put(roof, Vector3(0, 0.88, 0), false, Vector3.ZERO, cap)
	expo._rod(Vector3(0, 0.3, 0.45), Vector3(0, -0.5, 1.4), 0.03, _mat("_wood"), 4, cap)
	var cloth: Material = expo.island.surface("", 1.0, CrystalExpo.CREAM, 0.9, CrystalExpo.CREAM)
	var sails := _pivot(cap, Vector3(0, 0.5, -0.5))
	for k in 4:
		var a := TAU * k / 4.0
		var arm := _pivot(sails, Vector3.ZERO)
		arm.rotation.z = a
		expo._box(Vector3(0.04, 1.3, 0.04), Vector3(0, 0.7, 0), _mat("_wood"), false, arm)
		expo._box(Vector3(0.28, 1.1, 0.01), Vector3(0.14, 0.75, 0), cloth, false, arm)
	var noise := FastNoiseLite.new()
	noise.seed = 31
	_movers.append(func(t: float, dt: float) -> void:
		var wind := 0.7 + 0.3 * noise.get_noise_1d(t * 5.0)
		sails.rotation.z += wind * 1.5 * dt
		cap.rotation.y = lerp_angle(cap.rotation.y, 0.6 * noise.get_noise_1d(t * 0.3 + 50.0), 1.0 - exp(-0.5 * dt)))


func _stirling(show: Node3D) -> void:
	var c := Vector3(0, 0, 0.8)
	var brass: Material = _mat("_brass")
	expo._box(Vector3(1.8, 0.3, 0.8), c + Vector3(0, 0.15, 0), _mat("_wood"), true, show)
	var flame := ApparatusHall._embers(2.0)
	expo._cyl(0.0, 0.08, 0.2, c + Vector3(-0.5, 0.45, 0), flame, 8, false, show)
	var hot := ApparatusHall._embers(0.6)
	hot.albedo_color = Color(0.5, 0.25, 0.15)
	expo._cyl(0.12, 0.12, 0.5, c + Vector3(-0.5, 0.85, 0), hot, 16, false, show)
	expo._cyl(0.12, 0.12, 0.5, c + Vector3(0.0, 0.85, 0), _mat("_silver"), 16, false, show).basis = Basis(Vector3.BACK, PI * 0.5)
	for k in 5:
		expo._cyl(0.18, 0.18, 0.02, c + Vector3(0.0 - 0.2 + k * 0.1, 0.85, 0), _mat("_silver"), 16, false, show).basis = Basis(Vector3.BACK, PI * 0.5)
	expo._rod(c + Vector3(-0.5, 1.1, 0), c + Vector3(-0.25, 0.85, 0), 0.03, _mat("_copper"), 6, show)
	var fly_c := c + Vector3(0.5, 1.35, 0.2)
	var fly := _pivot(show, fly_c)
	expo._ring(0.3, 0.36, Vector3.ZERO, brass, fly, Basis(Vector3.RIGHT, PI * 0.5))
	expo._box(Vector3(0.6, 0.03, 0.02), Vector3.ZERO, brass, false, fly)
	var rods: Array[MeshInstance3D] = [_link(show, 0.015, brass), _link(show, 0.015, brass)]
	var pistons: Array[Node3D] = []
	for k in 2:
		var p := _pivot(show, Vector3.ZERO)
		expo._cyl(0.1, 0.1, 0.08, Vector3.ZERO, brass, 12, false, p)
		pistons.append(p)
	_movers.append(func(t: float, _dt: float) -> void:
		var a := t * 2.2
		fly.rotation.z = a
		hot.emission_energy_multiplier = 0.6 + 0.2 * sin(t * 7.0)
		for k in 2:
			var phase := a + k * PI * 0.5
			var pin := fly_c + Vector3(cos(phase), sin(phase), 0) * 0.12
			var px := -0.5 if k == 0 else 0.25
			var piston := c + Vector3(px, 1.12 + 0.06 * sin(phase), 0) if k == 0 else c + Vector3(0.25 + 0.06 * cos(phase), 0.85, 0)
			pistons[k].position = piston
			TideWorks._place(rods[k], piston, pin))


func _pelton(show: Node3D) -> void:
	var c := Vector3(0, 0, 0.8)
	expo._box(Vector3(1.2, 0.4, 0.8), c + Vector3(0, 0.2, 0), _mat("_iron"), true, show)
	expo._cyl(0.75, 0.75, 0.5, c + Vector3(0, 1.2, 0), _mat("_glass"), 24, false, show).basis = Basis(Vector3.RIGHT, PI * 0.5)
	var wheel := _pivot(show, c + Vector3(0, 1.2, 0))
	expo._cyl(0.35, 0.35, 0.06, Vector3.ZERO, _mat("_brass"), 24, false, wheel).basis = Basis(Vector3.RIGHT, PI * 0.5)
	for k in 16:
		var a := TAU * k / 16.0
		var cup := SphereMesh.new()
		cup.radius = 0.07
		cup.height = 0.07
		cup.is_hemisphere = true
		cup.material = _mat("_copper")
		expo._put(cup, Vector3(cos(a), sin(a), 0) * 0.45, false, Vector3.ZERO, wheel).basis = Basis(Vector3.BACK, a) * Basis(Vector3.RIGHT, PI * 0.5)
	var water := ApparatusHall._liquid(Color(0.4, 0.75, 0.9), 0.5)
	expo._rod(c + Vector3(-1.4, 1.65, 0), c + Vector3(-0.75, 1.65, 0), 0.06, _mat("_copper"), 8, show)
	expo._cyl(0.03, 0.06, 0.15, c + Vector3(-0.68, 1.65, 0), _mat("_brass"), 8, false, show).basis = Basis(Vector3.BACK, PI * 0.5)
	expo._box(Vector3(0.1, 1.65, 0.1), c + Vector3(-1.4, 0.82, 0), _mat("_iron"), false, show)
	var jet := _link(show, 0.025, water)
	TideWorks._place(jet, c + Vector3(-0.6, 1.65, 0), c + Vector3(0.05, 1.65, 0))
	var spray: Array[Node3D] = []
	for k in 6:
		var s := _pivot(show, c + Vector3(0, 1.65, 0))
		expo._ball(0.025, Vector3.ZERO, water, s)
		spray.append(s)
	_movers.append(func(t: float, _dt: float) -> void:
		wheel.rotation.z = -t * 6.0
		for k in spray.size():
			var f := fposmod(t * 2.0 + k / 6.0, 1.0)
			spray[k].position = c + Vector3(0.05 + f * 0.25, 1.65 - f * f * 0.9, (k - 2.5) * 0.04 * f))
