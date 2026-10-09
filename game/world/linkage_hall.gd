class_name LinkageHall
extends Node3D
## The exposition's third row: mechanical linkages, ways of turning one
## motion into another, six booths built as the others are
## (CrystalExpo._booth) behind the hall of apparatus, along a third
## boardwalk. Each mechanism runs continuously, its parts placed every
## frame by its true geometry (`_movers`), most of them on a board facing
## the walk:
## - The Crank & Piston: a flywheel's crank, a connecting rod and a piston
##   in a glass cylinder: turning made into to-and-fro, its stroke slower
##   at the ends.
## - The Straight Line: Chebyshev's lambda linkage. A crank turning round
##   carries a coupler whose far end runs a nearly straight line for half
##   its path; a pen there, and its path drawn on the board.
## - The Scotch Yoke: a pin on a turning disc in the slot of a yoke, which
##   slides to and fro in its guides in a pure sine.
## - The Camshaft: one shaft turning four cams (an eccentric, a heart, a
##   snail and a double lobe), each lifting its follower in its own
##   rhythm: rising evenly, rising slowly and dropping, twice a turn.
## - The Geneva Drive: a steadily turning pin steps a four-slotted wheel
##   on by a quarter turn each time round, holding it still between.
## - The Ratchet: a crank rocks a lever whose pawl pushes a toothed wheel
##   round one way only; a holding pawl clicks over each tooth.
## The booth names and notes are drafts.

const NAMES := ["THE CRANK & PISTON", "THE STRAIGHT LINE", "THE SCOTCH YOKE", "THE CAMSHAFT", "THE GENEVA DRIVE", "THE RATCHET"]
const NOTES := [
	"The Crank & Piston\nA turning crank drives a rod and a piston to and fro, slowest at each end of its stroke.",
	"The Straight Line\nChebyshev's linkage: a crank turning round makes the end of its coupler run a nearly straight line.",
	"The Scotch Yoke\nA pin on a turning disc slides a slotted yoke to and fro, smoothly, as a swing does.",
	"The Camshaft\nOne turning shaft, four cams, four followers, each rising and falling in its own rhythm.",
	"The Geneva Drive\nA steadily turning pin steps the slotted wheel on a quarter turn at a time, and holds it between.",
	"The Ratchet\nA rocking lever pushes the toothed wheel round one way only; the holding pawl stops it slipping back.",
]
const BOARD_Z := 1.3                     # the display boards' face, in the booth's show

var expo: CrystalExpo
var booths: Array[Node3D] = []
var _movers: Array[Callable] = []
var _t := 0.0


func _init(owner_expo: CrystalExpo) -> void:
	name = "LinkageHall"
	expo = owner_expo


func _ready() -> void:
	expo._build_promenade(CrystalExpo.WALK3_IN, CrystalExpo.ROW3_SPREAD + 5.0)
	var builders: Array[Callable] = [_crank, _straight_line, _yoke, _camshaft, _geneva, _ratchet]
	for i in builders.size():
		var b := deg_to_rad(CrystalExpo.BEARING - CrystalExpo.ROW3_SPREAD + 2.0 * CrystalExpo.ROW3_SPREAD * i / (builders.size() - 1))
		var booth := expo._booth(b, 17 + i, CrystalExpo.ROW3_IN, NAMES[i], NOTES[i])
		booths.append(booth)
		var show := Node3D.new()
		show.position = Vector3(0, 0, -0.6)
		booth.add_child(show)
		builders[i].call(show)
	expo._build_bunting(booths)


func _process(delta: float) -> void:
	_t += delta
	for m in _movers:
		m.call(_t, delta)


## ---- helpers ----------------------------------------------------------------

func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.set_meta(StaticMerge.MOVES, true)
	parent.add_child(n)
	return n


## A board facing the walk, `w` by `h`, its face at BOARD_Z, its middle at
## height `y`: a wooden frame round velvet, on two legs.
func _board(show: Node3D, w: float, h: float, y: float) -> void:
	var wood: Material = expo.get("_wood")
	expo._box(Vector3(w, h, 0.05), Vector3(0, y, BOARD_Z + 0.03), expo.get("_velvet"), false, show)
	for side: float in [-1.0, 1.0]:
		expo._box(Vector3(0.07, h + 0.07, 0.08), Vector3(side * (w * 0.5 + 0.035), y, BOARD_Z + 0.04), wood, false, show)
		expo._box(Vector3(0.07, y - h * 0.5, 0.07), Vector3(side * w * 0.4, (y - h * 0.5) * 0.5, BOARD_Z + 0.04), wood, false, show)
		expo._box(Vector3(w + 0.14, 0.07, 0.08), Vector3(0, y + side * (h * 0.5 + 0.035), BOARD_Z + 0.04), wood, false, show)
	expo._box(Vector3(w + 0.2, h + 0.2, 0.3), Vector3(0, y, BOARD_Z + 0.1), wood, true, show).visible = false


## A point on the board's face, `out` metres in front of it.
static func _on(p: Vector2, out := 0.05) -> Vector3:
	return Vector3(p.x, p.y, BOARD_Z - out)


## A disc of `r` facing the walk.
func _disc(r: float, thick: float, at: Vector3, mat: Material, parent: Node3D, sides := 24) -> MeshInstance3D:
	var c := expo._cyl(r, r, thick, at, mat, sides, false, parent)
	c.basis = Basis(Vector3.RIGHT, PI * 0.5)
	return c


## A link (round bar) whose ends are placed each frame by `_place`.
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


static func _place(link: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var basis := BeachSite._aligned(d) if d.length() > 0.0001 else Basis.IDENTITY
	link.transform = Transform3D(basis * Basis.from_scale(Vector3(1.0, maxf(d.length(), 0.001), 1.0)), (a + b) * 0.5)


## The point where circles about `a` (radius ra) and `b` (radius rb)
## meet, on the left of the way from a to b (or on its right).
static func _meet(a: Vector2, ra: float, b: Vector2, rb: float, left := true) -> Vector2:
	var ab := b - a
	var d := maxf(ab.length(), 0.0001)
	var x := (d * d + ra * ra - rb * rb) / (2.0 * d)
	var h := sqrt(maxf(ra * ra - x * x, 0.0))
	var u := ab / d
	var n := Vector2(-u.y, u.x) * (1.0 if left else -1.0)
	return a + u * x + n * h


## A flat plate whose outline is the radial profile `radius(angle)`, in
## the xy plane, `thick` deep along z, centred on the origin.
static func _plate(radius: Callable, thick: float, steps := 72) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array[Vector2] = []
	for k in steps:
		var a := TAU * k / steps
		var r: float = radius.call(a)
		ring.append(Vector2(cos(a), sin(a)) * r)
	var h := thick * 0.5
	for k in steps:
		var p: Vector2 = ring[k]
		var q: Vector2 = ring[(k + 1) % steps]
		# The two faces, fanned from the middle.
		st.set_normal(Vector3.BACK)
		st.add_vertex(Vector3(0, 0, h))
		st.add_vertex(Vector3(q.x, q.y, h))
		st.add_vertex(Vector3(p.x, p.y, h))
		st.set_normal(Vector3.FORWARD)
		st.add_vertex(Vector3(0, 0, -h))
		st.add_vertex(Vector3(p.x, p.y, -h))
		st.add_vertex(Vector3(q.x, q.y, -h))
		# The rim between.
		var out := Vector3(q.y - p.y, p.x - q.x, 0).normalized()
		st.set_normal(out)
		st.add_vertex(Vector3(p.x, p.y, h))
		st.add_vertex(Vector3(q.x, q.y, h))
		st.add_vertex(Vector3(q.x, q.y, -h))
		st.add_vertex(Vector3(p.x, p.y, h))
		st.add_vertex(Vector3(q.x, q.y, -h))
		st.add_vertex(Vector3(p.x, p.y, -h))
	return st.commit()


func _plate_view(radius: Callable, thick: float, mat: Material, parent: Node3D, steps := 72) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = _plate(radius, thick, steps)
	view.material_override = mat
	parent.add_child(view)
	return view


## ---- the booths ---------------------------------------------------------------

func _crank(show: Node3D) -> void:
	var brass: Material = expo.get("_brass")
	var iron: Material = expo.get("_iron")
	var copper: Material = expo.get("_copper")
	var glass: Material = expo.get("_glass")
	_board(show, 2.8, 1.5, 1.35)
	var c := Vector2(-0.8, 1.35)
	var r := 0.22
	var rod_len := 0.78
	expo._cyl(0.03, 0.03, 0.2, _on(c, 0.08), iron, 8, false, show).basis = Basis(Vector3.RIGHT, PI * 0.5)
	var wheel := _pivot(show, _on(c, 0.12))
	_disc(0.34, 0.05, Vector3.ZERO, brass, wheel, 32)
	expo._ring(0.3, 0.36, Vector3.ZERO, copper, wheel, Basis(Vector3.RIGHT, PI * 0.5))
	expo._ball(0.035, Vector3(r, 0, -0.04), iron, wheel)
	# The cylinder: glass along the stroke, a gland at its end.
	var stroke_mid := c.x + rod_len
	var cyl := expo._cyl(0.11, 0.11, 0.8, _on(Vector2(stroke_mid + 0.25, c.y), 0.12), glass, 16, false, show)
	cyl.basis = Basis(Vector3.BACK, PI * 0.5)
	var cap := expo._cyl(0.13, 0.13, 0.04, _on(Vector2(stroke_mid + 0.67, c.y), 0.12), brass, 16, false, show)
	cap.basis = Basis(Vector3.BACK, PI * 0.5)
	var piston := _pivot(show, Vector3.ZERO)
	expo._cyl(0.1, 0.1, 0.14, Vector3.ZERO, brass, 16, false, piston).basis = Basis(Vector3.BACK, PI * 0.5)
	var rod := _link(show, 0.022, iron)
	var tail := _link(show, 0.018, iron)
	_movers.append(func(t: float, _dt: float) -> void:
		var a := t * 1.6
		wheel.rotation.z = a
		var pin := c + Vector2(cos(a), sin(a)) * r
		var x := c.x + r * cos(a) + sqrt(rod_len * rod_len - pow(r * sin(a), 2.0))
		piston.position = _on(Vector2(x, c.y), 0.12)
		_place(rod, _on(pin, 0.16), _on(Vector2(x, c.y), 0.16))
		_place(tail, _on(Vector2(x, c.y), 0.12), _on(Vector2(stroke_mid + 0.95, c.y), 0.12)))


func _straight_line(show: Node3D) -> void:
	var brass: Material = expo.get("_brass")
	var iron: Material = expo.get("_iron")
	var copper: Material = expo.get("_copper")
	_board(show, 2.4, 1.7, 1.4)
	# Chebyshev's lambda: ground pivots 2 apart, crank 1, rocker 2.5,
	# coupler 5 with the rocker joined at its middle; the coupler's far
	# end runs straight along the bottom of its path.
	var s := 0.22
	var o := Vector2(-0.44, 0.62)
	var a := o
	var d := o + Vector2(2.0 * s, 0.0)
	for g: Vector2 in [a, d]:
		expo._ball(0.04, _on(g, 0.06), iron, show)
	expo._box(Vector3(2.0 * s + 0.2, 0.06, 0.04), _on((a + d) * 0.5 + Vector2(0, -0.06), 0.03), iron, false, show)
	# The path drawn on the board: dots round the whole curve.
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color(0.95, 0.9, 0.6)
	ink.emission_enabled = true
	ink.emission = Color(1.0, 0.9, 0.5)
	ink.emission_energy_multiplier = 0.8
	var path := MultiMesh.new()
	path.transform_format = MultiMesh.TRANSFORM_3D
	var dot := SphereMesh.new()
	dot.radius = 0.008
	dot.height = 0.016
	dot.radial_segments = 6
	dot.rings = 3
	dot.material = ink
	path.mesh = dot
	path.instance_count = 180
	var solve := func(angle: float) -> Array:
		var b := a + Vector2(cos(angle), sin(angle)) * s
		var cc := _meet(b, 2.5 * s, d, 2.5 * s, true)
		return [b, cc, b + (cc - b) * 2.0]
	for k in 180:
		var p: Vector2 = (solve.call(TAU * k / 180.0) as Array)[2]
		path.set_instance_transform(k, Transform3D(Basis.IDENTITY, _on(p, 0.01)))
	var trace := MultiMeshInstance3D.new()
	trace.multimesh = path
	show.add_child(trace)
	var crank := _link(show, 0.02, brass)
	var rocker := _link(show, 0.02, brass)
	var coupler := _link(show, 0.018, copper)
	var pen := _pivot(show, Vector3.ZERO)
	expo._ball(0.03, Vector3.ZERO, ink, pen)
	_movers.append(func(t: float, _dt: float) -> void:
		var parts: Array = solve.call(t * 0.9)
		var b: Vector2 = parts[0]
		var cc: Vector2 = parts[1]
		var p: Vector2 = parts[2]
		_place(crank, _on(a, 0.1), _on(b, 0.1))
		_place(rocker, _on(d, 0.14), _on(cc, 0.14))
		_place(coupler, _on(b, 0.12), _on(p, 0.12))
		pen.position = _on(p, 0.03))


func _yoke(show: Node3D) -> void:
	var brass: Material = expo.get("_brass")
	var iron: Material = expo.get("_iron")
	var copper: Material = expo.get("_copper")
	_board(show, 2.8, 1.3, 1.35)
	var c := Vector2(0, 1.35)
	var r := 0.24
	var disc := _pivot(show, _on(c, 0.08))
	_disc(0.3, 0.04, Vector3.ZERO, copper, disc, 32)
	expo._ball(0.035, Vector3(r, 0, -0.05), iron, disc)
	expo._ball(0.04, Vector3(0, 0, -0.03), iron, disc)
	# Fixed guides each side.
	for x: float in [-1.05, 1.05]:
		expo._cyl(0.045, 0.045, 0.22, _on(Vector2(x, c.y), 0.14), iron, 12, false, show).basis = Basis(Vector3.BACK, PI * 0.5)
		expo._box(Vector3(0.06, 0.2, 0.08), _on(Vector2(x, c.y - 0.1), 0.1), iron, false, show)
	# The yoke: a slotted frame with a rod each side.
	var yoke := _pivot(show, _on(c, 0.14))
	for x: float in [-0.04, 0.04]:
		expo._box(Vector3(0.025, 0.62, 0.03), Vector3(x, 0, 0), brass, false, yoke)
	for y: float in [-0.32, 0.32]:
		expo._box(Vector3(0.11, 0.03, 0.03), Vector3(0, y, 0), brass, false, yoke)
	for side: float in [-1.0, 1.0]:
		expo._rod(Vector3(side * 0.06, 0, 0), Vector3(side * 1.2, 0, 0), 0.018, brass, 8, yoke)
		expo._ball(0.04, Vector3(side * 1.22, 0, 0), copper, yoke)
	_movers.append(func(t: float, _dt: float) -> void:
		var a := t * 1.3
		disc.rotation.z = a
		yoke.position = _on(c + Vector2(r * cos(a), 0.0), 0.14))


func _camshaft(show: Node3D) -> void:
	var brass: Material = expo.get("_brass")
	var iron: Material = expo.get("_iron")
	var copper: Material = expo.get("_copper")
	var wood: Material = expo.get("_wood")
	var shaft_y := 0.8
	var z := 0.6
	# A base and two bearing blocks.
	expo._box(Vector3(3.0, 0.08, 0.5), Vector3(0, 0.04, z), wood, true, show)
	for x: float in [-1.35, 1.35]:
		expo._box(Vector3(0.12, shaft_y, 0.18), Vector3(x, shaft_y * 0.5, z), iron, false, show)
	var shaft := _pivot(show, Vector3(0, shaft_y, z))
	expo._cyl(0.025, 0.025, 2.8, Vector3.ZERO, iron, 8, false, shaft).basis = Basis(Vector3.BACK, PI * 0.5)
	expo._ball(0.05, Vector3(1.45, 0, 0), brass, shaft)
	# The cams: radius as a function of angle round the shaft.
	var base := 0.11
	var profiles: Array[Callable] = [
		func(a: float) -> float: return 0.05 * cos(a) + sqrt(0.13 * 0.13 - pow(0.05 * sin(a), 2.0)),
		func(a: float) -> float:
			var f := fposmod(a, TAU) / PI
			return base + 0.1 * (f if f <= 1.0 else 2.0 - f),
		func(a: float) -> float: return base + 0.1 * fposmod(a, TAU) / TAU,
		func(a: float) -> float: return base + 0.06 * pow(cos(a), 2.0),
	]
	var hues := [Color(1.0, 0.75, 0.3), Color(0.95, 0.45, 0.55), Color(0.45, 0.8, 1.0), Color(0.55, 0.95, 0.5)]
	for k in 4:
		var x := -0.9 + 0.6 * k
		var cam := _plate_view(profiles[k], 0.05, copper if k % 2 == 0 else brass, shaft)
		cam.position = Vector3(x, 0, 0)
		cam.basis = Basis(Vector3.UP, PI * 0.5)
		# The follower in its guide above, a glowing knob on top.
		var guide_y := shaft_y + 0.5
		expo._box(Vector3(0.12, 0.05, 0.12), Vector3(x, guide_y, z), iron, false, show)
		expo._box(Vector3(0.04, guide_y - shaft_y + 0.25, 0.04), Vector3(x, (guide_y + shaft_y) * 0.5 - 0.1, z + 0.18), iron, false, show)
		var follower := _pivot(show, Vector3(x, shaft_y, z))
		expo._cyl(0.015, 0.015, 0.6, Vector3(0, 0.3, 0), iron, 8, false, follower)
		expo._cyl(0.03, 0.03, 0.03, Vector3(0, 0.01, 0), brass, 12, false, follower)
		var knob := StandardMaterial3D.new()
		knob.albedo_color = (hues[k] as Color).darkened(0.3)
		knob.emission_enabled = true
		knob.emission = hues[k]
		knob.emission_energy_multiplier = 1.2
		expo._ball(0.05, Vector3(0, 0.63, 0), knob, follower)
		var profile: Callable = profiles[k]
		_movers.append(func(t: float, _dt: float) -> void:
			var a := t * 1.1
			follower.position = Vector3(x, shaft_y + float(profile.call(PI * 0.5 - a)), z))
	_movers.append(func(t: float, _dt: float) -> void: shaft.rotation.x = t * 1.1)


func _geneva(show: Node3D) -> void:
	var brass: Material = expo.get("_brass")
	var iron: Material = expo.get("_iron")
	var copper: Material = expo.get("_copper")
	_board(show, 2.4, 1.5, 1.35)
	# A four-slot Geneva: the driver's pin enters a slot for a quarter of
	# its turn, turning the wheel a quarter turn, and its locking disc
	# holds the wheel the rest of the time.
	var d := 0.6
	var r := d / sqrt(2.0)
	var g1 := Vector2(-0.45, 1.3)
	var g2 := g1 + Vector2(d, 0)
	var driver := _pivot(show, _on(g1, 0.1))
	_disc(0.22, 0.04, Vector3.ZERO, copper, driver, 32)
	expo._box(Vector3(r, 0.05, 0.03), Vector3(r * 0.5, 0, -0.03), copper, false, driver)
	expo._ball(0.03, Vector3(r, 0, -0.06), iron, driver)
	var wheel := _pivot(show, _on(g2, 0.13))
	_disc(r * 0.98, 0.04, Vector3.ZERO, brass, wheel, 32)
	for k in 4:
		var a := PI + k * PI * 0.5
		var slot := expo._box(Vector3(0.24, 0.05, 0.046), Vector3(cos(a), sin(a), 0) * (r - 0.11), iron, false, wheel)
		slot.basis = Basis(Vector3.BACK, a)
	expo._ball(0.04, Vector3(0, 0, -0.03), iron, wheel)
	# A pointer on the wheel and four marks round it.
	expo._box(Vector3(0.05, 0.2, 0.01), Vector3(0, r + 0.12, -0.03), copper, false, wheel)
	for k in 4:
		var a := k * PI * 0.5
		expo._ball(0.025, _on(g2 + Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * (r + 0.32), 0.02), brass, show)
	_movers.append(func(t: float, _dt: float) -> void:
		var phi := t * 1.2
		driver.rotation.z = phi
		var m := floorf((phi + PI * 0.25) / TAU)
		var local := phi - TAU * m
		var steps := m
		var part := 0.0
		if local <= PI * 0.25:
			part = (atan2(r * sin(local), d - r * cos(local)) + PI * 0.25) / (PI * 0.5)
		else:
			steps += 1.0
		wheel.rotation.z = -(steps + part) * PI * 0.5)


func _ratchet(show: Node3D) -> void:
	var brass: Material = expo.get("_brass")
	var iron: Material = expo.get("_iron")
	var copper: Material = expo.get("_copper")
	_board(show, 2.6, 1.5, 1.35)
	var w := Vector2(0.35, 1.3)
	var teeth := 12
	var wheel := _pivot(show, _on(w, 0.1))
	_plate_view(func(a: float) -> float: return 0.24 + 0.07 * fposmod(a * teeth / TAU, 1.0), 0.05, brass, wheel, teeth * 12)
	expo._ball(0.04, Vector3(0, 0, -0.04), iron, wheel)
	# A crank rocking the lever through a rod (a crank and rocker).
	var c := Vector2(-0.85, 0.85)
	var rc := 0.09
	var lever_len := 0.55
	var rod_len := 0.75
	var crank := _pivot(show, _on(c, 0.1))
	_disc(0.12, 0.04, Vector3.ZERO, copper, crank)
	expo._ball(0.025, Vector3(rc, 0, -0.04), iron, crank)
	var lever := _link(show, 0.02, iron)
	var rod := _link(show, 0.016, iron)
	var pawl := _link(show, 0.014, copper)
	var holder := _pivot(show, _on(w + Vector2(0.42, 0.18), 0.1))
	expo._box(Vector3(0.22, 0.03, 0.03), Vector3(-0.1, -0.02, 0), copper, false, holder)
	expo._ball(0.02, _on(w + Vector2(0.42, 0.18), 0.12), iron, show)
	var click := AudioStreamPlayer3D.new()
	click.stream = load("res://audio/ratchet.wav") if DisplayServer.get_name() != "headless" else null
	click.unit_size = 4.0
	click.position = _on(w, 0.1)
	show.add_child(click)
	var turned := [0.0, -INF]          # the wheel's angle, the lever's last angle
	_movers.append(func(t: float, _dt: float) -> void:
		var a := t * 1.4
		crank.rotation.z = a
		var pin := c + Vector2(cos(a), sin(a)) * rc
		var end := _meet(w, lever_len, pin, rod_len, true)
		var swing := atan2(end.y - w.y, end.x - w.x)
		var last: float = turned[1]
		# Moving the wheel's way the pawl carries it; moving back it slips.
		if last != -INF:
			var step := angle_difference(last, swing)
			if step > 0.0:
				var before := floorf(float(turned[0]) * teeth / TAU)
				turned[0] = float(turned[0]) + step
				if floorf(float(turned[0]) * teeth / TAU) != before:
					BeachSite._play(click, randf_range(0.95, 1.1))
		turned[1] = swing
		wheel.rotation.z = turned[0]
		_place(lever, _on(w, 0.15), _on(end, 0.15))
		_place(rod, _on(pin, 0.14), _on(end, 0.14))
		var tip := w + Vector2(cos(swing), sin(swing)) * 0.33
		_place(pawl, _on(end.lerp(w, 0.3), 0.13), _on(tip, 0.13))
		holder.rotation.z = 0.12 * fposmod(float(turned[0]) * teeth / TAU, 1.0))
