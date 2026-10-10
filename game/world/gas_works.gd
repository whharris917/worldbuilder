class_name GasWorks
extends MillLoad
## The windmill's gasworks: the mill's power split water into hydrogen
## and oxygen and stored them, to be burned in a limelight.
##
## On the ground floor a dynamo is belted to the take-off spindle's
## pulley; it turns 4.4 times as fast as the spindle, about a thousand
## turns a minute with the sails at fifteen. Its voltage rises with its
## speed (KE volts for each radian a second). It drives a current through
## ten glass cells in a row on a bench, each holding water made
## conductive (with soda) and two lead plates. Each cell pushes back
## about two volts before any current flows, so nothing happens until
## the dynamo makes twenty, with the sails at about six turns a minute;
## above that the current is the voltage left over divided by the
## circuit's resistance. The dynamo holds the spindle back in proportion
## to that current, so the more gas it makes the harder the sails work.
##
## Faraday's law: each pair of electrons the current carries frees one
## molecule of hydrogen at one plate, half as much oxygen at the other,
## in every cell. The gases bubble up into small glass hoods over the
## plates and run by red (hydrogen) and blue (oxygen) pipes out through
## the wall to two gasholders: iron bells floating upside down in tanks
## of water, rising as gas fills them, so how full each is can be read
## from across the island. The oxygen's bell holds half the hydrogen's,
## as the cells make it.
##
## The limelight: a jet of the two gases burning together on a cylinder
## of quicklime heats it white hot, a bright, steady light used in
## theatres and lighthouses. A valve at its post lets the gas to it.
##
## Gas is made and burned GAS_SCALE times faster than this would really
## run, so a fresh breeze fills the holders in about a quarter of an
## hour and they light the lamp for about half an hour; everything else
## is at its real rate.

const DYNAMO := Vector3(1.4, 0.0, -1.25)        # on the ground floor, its axis upright
const DYNAMO_PULLEY := 0.09
const BELT := Windmill.PULLEY_R / DYNAMO_PULLEY
const KE := 0.477                                # volts per radian a second of the dynamo
const RESISTANCE := 0.19                         # ohms, the dynamo, the wires and the cells
const CELLS := 10
const CELL_VOLTS := 2.0
const FARADAY := 96485.0
const MOLAR_VOLUME := 0.0245                     # m³ a mole at 25 °C
const GAS_SCALE := 120.0
const BURN := 0.25                               # m³ of hydrogen an hour the limelight burns, really
const BENCH_Z := -1.85
const HYDROGEN := Vector3(8.0, 0.0, -1.5)        # the holders, outside to the east
const OXYGEN := Vector3(7.0, 0.0, 3.6)
const LAMP := Vector3(10.5, 0.0, 4.6)
const TANK_H := 2.0
const WATER := 1.8
const RISE := 1.55                               # how far a bell rises from empty to full
const H_BELL := 1.75                             # bell radii: the oxygen's holds half
const O_BELL := 1.24

var current := 0.0                               # amps
var hydrogen := 3.0                              # m³ stored
var oxygen := 1.5
var lamp_open := false
var lit := false

var _dynamo_angle := 0.0
var _armature: Node3D
var _needle: Node3D
var _bubbles: Array[GPUParticles3D] = []
var _bells: Array[Node3D] = []
var _lime_mat: StandardMaterial3D
var _lamp_light: OmniLight3D
var _valve: WorksHandle


func _ready() -> void:
	name = "GasWorks"
	var m := CozyMesh.new()
	var glass := CozyMesh.new()
	var out := CozyMesh.new()
	var out_thin := CozyMesh.new()
	_dynamo(m)
	_belt(m)
	_cells(m, glass)
	_pipes(m, out_thin)
	_holder(out, HYDROGEN, H_BELL, Color(0.27, 0.4, 0.33))
	_holder(out, OXYGEN, O_BELL, Color(0.3, 0.36, 0.48))
	_limelight(out, out_thin)
	_view(self, "GasWorksInside", m.commit(mill.mats["in"]))
	_view(self, "GasWorksGlass", glass.commit(mill.mats["glass"])).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view(self, "GasWorksOutside", out.commit(mill.mats["out"]))
	_view(self, "GasWorksPipes", out_thin.commit(mill.mats["out_plain"]))


func _view(parent: Node3D, title: String, mesh: Mesh) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = title
	view.mesh = mesh
	parent.add_child(view)
	return view


## ---- the physics ------------------------------------------------------------

func _amps(omega: float) -> float:
	return maxf(KE * omega * BELT - CELLS * CELL_VOLTS, 0.0) / RESISTANCE


func torque(omega: float) -> float:
	return KE * _amps(omega) * BELT


func advance(omega: float, delta: float) -> void:
	current = _amps(omega)
	var made := CELLS * current / (2.0 * FARADAY) * MOLAR_VOLUME * GAS_SCALE * delta
	hydrogen = minf(hydrogen + made, _capacity(H_BELL))
	oxygen = minf(oxygen + made * 0.5, _capacity(O_BELL))
	lit = lamp_open and hydrogen > 0.0 and oxygen > 0.0
	if lit:
		var burnt := BURN / 3600.0 * GAS_SCALE * delta
		hydrogen = maxf(hydrogen - burnt, 0.0)
		oxygen = maxf(oxygen - burnt * 0.5, 0.0)
	_dynamo_angle = wrapf(_dynamo_angle + omega * BELT * delta, 0.0, TAU)
	_armature.rotation.y = _dynamo_angle
	_needle.rotation.z = -clampf(current / 300.0, 0.0, 1.0) * 1.6 + 0.8
	var share := clampf(current / 250.0, 0.0, 1.0)
	for b in _bubbles:
		b.emitting = share > 0.01
		b.amount_ratio = maxf(share, 0.1)
	_bells[0].position.y = 0.15 + RISE * hydrogen / _capacity(H_BELL)
	_bells[1].position.y = 0.15 + RISE * oxygen / _capacity(O_BELL)
	_lime_mat.emission_energy_multiplier = 6.0 if lit else 0.0
	_lamp_light.visible = lit


static func _capacity(bell: float) -> float:
	return PI * bell * bell * RISE


func report() -> String:
	var text := "The dynamo sends %d amps through the cells." % roundi(current)
	if current < 1.0:
		text = "The dynamo turns too slowly to drive the cells." if mill.omega > 0.05 else "The dynamo is still."
	return "%s\nHydrogen %d%%, oxygen %d%% full.%s" % [text, roundi(100.0 * hydrogen / _capacity(H_BELL)),
			roundi(100.0 * oxygen / _capacity(O_BELL)), "\nThe limelight is burning." if lit else ""]


func state() -> Dictionary:
	return {"hydrogen": hydrogen, "oxygen": oxygen, "lamp": lamp_open}


func restore(saved: Dictionary) -> void:
	hydrogen = float(saved.get("hydrogen", hydrogen))
	oxygen = float(saved.get("oxygen", oxygen))
	lamp_open = bool(saved.get("lamp", false))
	_valve.on = lamp_open
	_valve.call("_show")


## ---- the ground floor ---------------------------------------------------------

## A dynamo standing upright on an iron bed: two field coils of copper
## either side of the armature, the commutator and its brushes on top,
## its pulley above them level with the spindle's.
func _dynamo(m: CozyMesh) -> void:
	var base := DYNAMO + Vector3(0, Windmill.PLINTH, 0)
	var iron := Color(0.22, 0.24, 0.23)
	var copper := Color(0.75, 0.45, 0.24)
	var turn := Basis(Vector3.UP, 0.6)
	m.box(Vector3(0.62, 0.12, 0.5), CozyMesh.at(base + Vector3(0, 0.06, 0), turn), iron)
	for s: float in [-1.0, 1.0]:
		m.cyl(0.11, 0.11, 0.36, 14, CozyMesh.at(base + turn * Vector3(s * 0.2, 0.32, 0)), copper)
		m.box(Vector3(0.08, 0.42, 0.24), CozyMesh.at(base + turn * Vector3(s * 0.1, 0.33, 0), turn), iron)
	m.box(Vector3(0.6, 0.05, 0.16), CozyMesh.at(base + turn * Vector3(0, 0.56, 0), turn), iron)
	# Brushes on the commutator, and the terminals.
	for s: float in [-1.0, 1.0]:
		m.box(Vector3(0.03, 0.03, 0.08), CozyMesh.at(base + turn * Vector3(0, 0.62, s * 0.07), turn), Color(0.15, 0.15, 0.15))
		m.cyl(0.02, 0.02, 0.05, 6, CozyMesh.at(base + turn * Vector3(s * 0.26, 0.6, 0)), copper)
	_armature = Node3D.new()
	_armature.position = base
	_armature.set_meta(StaticMerge.MOVES, true)
	add_child(_armature)
	var a := CozyMesh.new()
	a.cyl(0.075, 0.075, 0.36, 12, CozyMesh.at(Vector3(0, 0.32, 0)), Color(0.4, 0.38, 0.35))
	for k in 6:
		a.box(Vector3(0.01, 0.34, 0.02), CozyMesh.at(Vector3(0, 0.32, 0), Basis(Vector3.UP, TAU * k / 6.0)) * CozyMesh.at(Vector3(0, 0, 0.077)), copper)
	a.cyl(0.035, 0.035, 0.07, 10, CozyMesh.at(Vector3(0, 0.62, 0)), copper)
	a.cyl(0.015, 0.015, Windmill.PULLEY_Y - Windmill.PLINTH - 0.5, 6, CozyMesh.at(Vector3(0, (Windmill.PULLEY_Y - Windmill.PLINTH + 0.5) * 0.5, 0)), iron)
	a.cyl(DYNAMO_PULLEY, DYNAMO_PULLEY, 0.14, 14, CozyMesh.at(Vector3(0, Windmill.PULLEY_Y - Windmill.PLINTH, 0)), Color(0.5, 0.37, 0.26))
	a.box(Vector3(0.02, 0.15, DYNAMO_PULLEY * 1.6), CozyMesh.at(Vector3(0, Windmill.PULLEY_Y - Windmill.PLINTH, 0)), iron)
	_view(_armature, "Armature", a.commit(mill.mats["in"]))
	# Its wires to the bench.
	var term := base + turn * Vector3(-0.26, 0.62, 0)
	m.rod(term, Vector3(0.95, Windmill.PLINTH + 0.8, BENCH_Z + 0.1), 0.012, 4, copper)
	var term2 := base + turn * Vector3(0.26, 0.62, 0)
	m.rod(term2, term2 + Vector3(0, 0.2, 0), 0.012, 4, copper)
	m.rod(term2 + Vector3(0, 0.2, 0), Vector3(0.95, Windmill.PLINTH + 0.95, BENCH_Z - 0.2), 0.012, 4, copper)


## The flat belt from the spindle's pulley round the dynamo's, along the
## two lines that touch both.
func _belt(m: CozyMesh) -> void:
	var a := Vector2(Windmill.SPINDLE.x, Windmill.SPINDLE.z)
	var b := Vector2(DYNAMO.x, DYNAMO.z)
	var ra := Windmill.PULLEY_R + 0.006
	var rb := DYNAMO_PULLEY + 0.006
	var u := (b - a).normalized()
	var p := Vector2(-u.y, u.x)
	var beta := asin((ra - rb) / a.distance_to(b))
	var n1 := u * sin(beta) + p * cos(beta)
	var n2 := u * sin(beta) - p * cos(beta)
	var points: Array[Vector2] = []
	# Round the spindle's pulley the far way, from n2 to n1 through -u.
	var t1 := atan2(n1.y, n1.x)
	var t2 := atan2(n2.y, n2.x)
	var span := wrapf(t1 - t2, 0.0, TAU)
	for k in 17:
		var t := t2 - (TAU - span) * k / 16.0
		points.append(a + Vector2(cos(t), sin(t)) * ra)
	# Round the dynamo's pulley the near-side way, from n1 to n2 through +u.
	for k in 9:
		var t := t1 - span * k / 8.0
		points.append(b + Vector2(cos(t), sin(t)) * rb)
	var y := Windmill.PULLEY_Y
	var leather := Color(0.36, 0.24, 0.16)
	for k in points.size():
		var q0 := points[k]
		var q1 := points[(k + 1) % points.size()]
		var side := Vector3(q1.y - q0.y, 0, -(q1.x - q0.x)).normalized()
		for s: float in [-1.0, 1.0]:
			m.quad(Vector3(q0.x, y - 0.05, q0.y), Vector3(q1.x, y - 0.05, q1.y), Vector3(q1.x, y + 0.05, q1.y),
					Vector3(q0.x, y + 0.05, q0.y), side * s, leather)


## Ten cells in two rows on a bench against the north wall: a glass jar
## of water, two lead plates, a small glass hood over each plate, copper
## links joining each cell's plate to the next one's; the gas pipes along
## the back; an ammeter on a board.
func _cells(m: CozyMesh, glass: CozyMesh) -> void:
	var top := Windmill.PLINTH + 0.72
	var wood := Color(0.5, 0.37, 0.26)
	m.box(Vector3(1.9, 0.06, 0.6), CozyMesh.at(Vector3(0, top - 0.03, BENCH_Z)), wood)
	for x: float in [-0.88, 0.88]:
		for z: float in [BENCH_Z - 0.26, BENCH_Z + 0.26]:
			m.box(Vector3(0.06, 0.69, 0.06), CozyMesh.at(Vector3(x, Windmill.PLINTH + 0.345, z)), wood.darkened(0.15))
	m.box(Vector3(1.78, 0.04, 0.5), CozyMesh.at(Vector3(0, Windmill.PLINTH + 0.18, BENCH_Z)), wood)
	var lead := Color(0.45, 0.46, 0.5)
	var copper := Color(0.75, 0.45, 0.24)
	var red := Color(0.62, 0.2, 0.16)
	var blue := Color(0.22, 0.32, 0.56)
	var prev := Vector3.ZERO
	for i in CELLS:
		var row := i / 5
		var col := i % 5 if row == 0 else 4 - i % 5
		var at := Vector3(-0.6 + 0.3 * col, top, BENCH_Z + (0.12 if row == 0 else -0.13))
		glass.cyl(0.1, 0.1, 0.34, 16, CozyMesh.at(at + Vector3(0, 0.17, 0)), Color(0.8, 0.9, 0.95, 0.25))
		glass.cyl(0.092, 0.092, 0.27, 16, CozyMesh.at(at + Vector3(0, 0.14, 0)), Color(0.55, 0.78, 0.9, 0.35))
		for s: float in [-1.0, 1.0]:
			var plate := at + Vector3(s * 0.045, 0.0, 0)
			m.box(Vector3(0.012, 0.3, 0.1), CozyMesh.at(plate + Vector3(0, 0.2, 0)), lead)
			glass.cyl(0.02, 0.04, 0.1, 10, CozyMesh.at(plate + Vector3(0, 0.33, 0)), Color(0.8, 0.9, 0.95, 0.35))
			var pipe_y := Windmill.PLINTH + (1.15 if s < 0.0 else 1.05)
			m.rod(plate + Vector3(0, 0.38, 0), Vector3(plate.x, pipe_y, BENCH_Z - 0.24), 0.008, 4, red if s < 0.0 else blue)
		m.cyl(0.012, 0.012, 0.05, 6, CozyMesh.at(at + Vector3(0.045, 0.37, 0.04)), copper)
		m.cyl(0.012, 0.012, 0.05, 6, CozyMesh.at(at + Vector3(-0.045, 0.37, 0.04)), copper)
		if i > 0:
			m.rod(prev, at + Vector3(-0.045, 0.39, 0.04), 0.006, 4, copper)
		prev = at + Vector3(0.045, 0.39, 0.04)
		var bubbles := _bubble_maker()
		bubbles.position = at + Vector3(0, 0.03, 0)
		add_child(bubbles)
		_bubbles.append(bubbles)
	# The manifolds along the back: hydrogen above, oxygen below.
	for pair: Array in [[1.15, red], [1.05, blue]]:
		var y: float = Windmill.PLINTH + float(pair[0])
		m.rod(Vector3(-0.7, y, BENCH_Z - 0.24), Vector3(0.8, y, BENCH_Z - 0.24), 0.025, 8, pair[1])
	# The ammeter on its board, its needle swinging with the current.
	var board := Vector3(-0.72, Windmill.PLINTH + 1.3, BENCH_Z - 0.2)
	m.box(Vector3(0.36, 0.36, 0.03), CozyMesh.at(board), wood.darkened(0.2))
	m.cyl(0.14, 0.14, 0.02, 20, CozyMesh.at(board + Vector3(0, 0, 0.025), Basis(Vector3.RIGHT, PI * 0.5)), Color(0.95, 0.93, 0.86))
	m.torus(0.135, 0.155, 20, 6, CozyMesh.at(board + Vector3(0, 0, 0.03), Basis(Vector3.RIGHT, PI * 0.5)), Color(0.72, 0.58, 0.3))
	for k in 9:
		var t := -0.8 + 1.6 * k / 8.0
		m.box(Vector3(0.006, 0.025, 0.004), CozyMesh.at(board + Vector3(sin(t) * 0.11, cos(t) * 0.11 - 0.03, 0.038), Basis(Vector3.BACK, -t)), Color(0.1, 0.1, 0.1))
	_needle = Node3D.new()
	_needle.position = board + Vector3(0, -0.03, 0.042)
	add_child(_needle)
	var n := CozyMesh.new()
	n.box(Vector3(0.006, 0.12, 0.004), CozyMesh.at(Vector3(0, 0.06, 0)), Color(0.1, 0.1, 0.1))
	n.cyl(0.012, 0.012, 0.008, 8, CozyMesh.at(Vector3.ZERO, Basis(Vector3.RIGHT, PI * 0.5)), Color(0.1, 0.1, 0.1))
	_view(_needle, "Needle", n.commit(mill.mats["in_plain"]))


## Small bubbles rising between a cell's plates.
func _bubble_maker() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.5
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-0.2, -0.1, -0.2), Vector3(0.4, 0.5, 0.4))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.05, 0.02, 0.04)
	process.direction = Vector3.UP
	process.spread = 8.0
	process.initial_velocity_min = 0.25
	process.initial_velocity_max = 0.45
	process.gravity = Vector3(0, 0.3, 0)
	process.scale_min = 0.5
	process.scale_max = 1.2
	p.process_material = process
	var ball := SphereMesh.new()
	ball.radius = 0.005
	ball.height = 0.01
	ball.radial_segments = 6
	ball.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.95, 0.98, 1.0, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball.material = mat
	p.draw_pass_1 = ball
	return p


## The two pipes from the bench out through the wall and along the
## ground on blocks to their holders, and from the holders to the lamp.
func _pipes(m: CozyMesh, out: CozyMesh) -> void:
	var red := Color(0.62, 0.2, 0.16)
	var blue := Color(0.22, 0.32, 0.56)
	var exit := deg_to_rad(145.0)
	for pair: Array in [[1.15, red, HYDROGEN, H_BELL, 0.35, 0.0, 4.5], [1.05, blue, OXYGEN, O_BELL, 0.22, 0.18, 4.2]]:
		var y: float = Windmill.PLINTH + float(pair[0])
		var colour: Color = pair[1]
		var holder: Vector3 = pair[2]
		var low: float = pair[4]
		var shift: float = pair[5]
		var inside := Vector3(sin(exit) * (Windmill.inner_at(y) - 0.05), y, cos(exit) * (Windmill.inner_at(y) - 0.05))
		# Out past the plinth's edge before turning down.
		var outside := Vector3(sin(exit) * (Windmill.radius_at(y) + 0.75), y, cos(exit) * (Windmill.radius_at(y) + 0.75) - shift)
		m.rod(Vector3(0.8, y, BENCH_Z - 0.24), inside, 0.025, 8, colour)
		m.rod(inside, outside, 0.025, 8, colour)
		var down := Vector3(outside.x, low, outside.z)
		var tank: float = float(pair[3]) + 0.35
		var turn: float = pair[6]
		var path: Array[Vector3] = [outside, down, Vector3(turn, low, down.z), Vector3(turn, low, holder.z),
				Vector3(holder.x - tank, low, holder.z)]
		for k in path.size() - 1:
			if path[k].distance_to(path[k + 1]) > 0.01:
				out.rod(path[k], path[k + 1], 0.03, 8, colour)
				out.ball(0.04, 8, CozyMesh.at(path[k + 1]), colour.darkened(0.2))
		for k in range(1, path.size() - 1):
			out.box(Vector3(0.14, low - 0.03, 0.14), CozyMesh.at(Vector3(path[k].x, (low - 0.03) * 0.5, path[k].z)), Color(0.6, 0.58, 0.55))
		# On from the holder's far side to the lamp's post.
		var leave := holder + (Vector3(LAMP.x, 0, LAMP.z) - holder).normalized() * tank
		var post := LAMP + Vector3(-0.18 if colour == red else 0.0, 0, 0.18 if colour == blue else -0.1)
		out.rod(Vector3(leave.x, low, leave.z), Vector3(post.x, low, post.z), 0.025, 8, colour)
		out.rod(Vector3(post.x, low, post.z), Vector3(post.x, 2.9, post.z), 0.022, 8, colour)
		out.ball(0.035, 8, CozyMesh.at(Vector3(leave.x, low, leave.z)), colour.darkened(0.2))


## A gasholder: a round brick tank of water, an iron bell floating upside
## down in it (rising as it fills), four iron guide columns with a ring
## at their tops, rollers on the bell's crown running on them.
func _holder(m: CozyMesh, at: Vector3, bell: float, paint: Color) -> void:
	var brick := Color(0.62, 0.36, 0.28)
	var tank := bell + 0.15
	Windmill._ring(m, tank, tank + 0.2, 0.0, TANK_H, Transform3D(Basis.IDENTITY, at), brick, 36)
	Windmill._ring(m, tank - 0.02, tank + 0.24, TANK_H, TANK_H + 0.08, Transform3D(Basis.IDENTITY, at), brick.lightened(0.2), 36)
	Windmill._ring(m, bell + 0.01, tank, WATER - 0.02, WATER, Transform3D(Basis.IDENTITY, at), Color(0.32, 0.45, 0.5), 36)
	var iron := Color(0.25, 0.27, 0.27)
	var column_h := TANK_H + RISE + 0.8
	for k in 4:
		var a := PI * 0.25 + PI * 0.5 * k
		var foot := at + Vector3(sin(a), 0, cos(a)) * (tank + 0.35)
		m.box(Vector3(0.16, column_h, 0.16), CozyMesh.at(foot + Vector3(0, column_h * 0.5, 0), Basis(Vector3.UP, a)), iron)
		m.box(Vector3(0.3, 0.12, 0.3), CozyMesh.at(foot + Vector3(0, 0.06, 0)), Color(0.6, 0.58, 0.55))
	Windmill._ring(m, tank + 0.27, tank + 0.43, column_h - 0.12, column_h, Transform3D(Basis.IDENTITY, at), iron, 36)
	var body := StaticBody3D.new()
	body.position = at + Vector3(0, TANK_H * 0.5, 0)
	var shape := CylinderShape3D.new()
	shape.radius = tank + 0.2
	shape.height = TANK_H
	var c := CollisionShape3D.new()
	c.shape = shape
	body.add_child(c)
	add_child(body)
	var node := Node3D.new()
	node.position = at
	node.set_meta(StaticMerge.MOVES, true)
	add_child(node)
	_bells.append(node)
	var b := CozyMesh.new()
	var height := 1.95
	Windmill._ring(b, bell - 0.03, bell, 0.0, height, Transform3D.IDENTITY, paint, 36)
	var crown := SphereMesh.new()
	crown.radius = 1.0
	crown.height = 1.0
	crown.radial_segments = 36
	crown.rings = 6
	crown.is_hemisphere = true
	b.add(crown, CozyMesh.at(Vector3(0, height, 0), Basis.from_scale(Vector3(bell, 0.3, bell))), paint)
	# Rivet bands round the side, and the rollers on the guides.
	for y: float in [0.5, 1.0, 1.5]:
		Windmill._ring(b, bell - 0.01, bell + 0.015, y - 0.02, y + 0.02, Transform3D.IDENTITY, paint.darkened(0.25), 36)
	for k in 4:
		var a := PI * 0.25 + PI * 0.5 * k
		var out := Vector3(sin(a), 0, cos(a))
		b.box(Vector3(0.1, 0.1, 0.42), CozyMesh.at(out * (bell + 0.2) + Vector3(0, height, 0), Basis(Vector3.UP, a)), iron)
		b.cyl(0.07, 0.07, 0.05, 10, CozyMesh.at(out * (tank + 0.24) + Vector3(0, height, 0), Basis(Vector3.UP, a) * Basis(Vector3.FORWARD, PI * 0.5)), iron)
	_view(node, "Bell", b.commit(mill.mats["out"]))


## A limelight on a post: a lamp house of iron and glass with a chimney,
## the lime cylinder in the middle where the two pipes' jet meets it, and
## the valve at the post's foot.
func _limelight(m: CozyMesh, thin: CozyMesh) -> void:
	var iron := Color(0.22, 0.24, 0.23)
	m.box(Vector3(0.5, 0.15, 0.5), CozyMesh.at(LAMP + Vector3(0, 0.075, 0)), Color(0.6, 0.58, 0.55))
	m.cyl(0.07, 0.09, 2.8, 10, CozyMesh.at(LAMP + Vector3(0, 1.45, 0)), iron)
	var head := LAMP + Vector3(0, 3.15, 0)
	m.cyl(0.26, 0.26, 0.05, 16, CozyMesh.at(head + Vector3(0, -0.27, 0)), iron)
	m.cyl(0.1, 0.3, 0.18, 16, CozyMesh.at(head + Vector3(0, 0.33, 0)), iron)
	m.cyl(0.06, 0.06, 0.25, 10, CozyMesh.at(head + Vector3(0, 0.52, 0)), iron)
	m.cyl(0.1, 0.06, 0.05, 10, CozyMesh.at(head + Vector3(0, 0.66, 0)), iron)
	for k in 6:
		var a := TAU * k / 6.0
		thin.rod(head + Vector3(sin(a) * 0.24, -0.25, cos(a) * 0.24), head + Vector3(sin(a) * 0.24, 0.24, cos(a) * 0.24), 0.012, 4, iron)
	var glass := CozyMesh.new()
	glass.cyl(0.24, 0.24, 0.48, 18, CozyMesh.at(head), Color(0.85, 0.92, 0.95, 0.2))
	_view(self, "LampGlass", glass.commit(mill.mats["glass"])).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The jet and the lime.
	thin.rod(head + Vector3(-0.2, -0.24, 0), head + Vector3(-0.07, -0.02, 0), 0.012, 6, Color(0.72, 0.58, 0.3))
	_lime_mat = StandardMaterial3D.new()
	_lime_mat.albedo_color = Color(0.95, 0.94, 0.9)
	_lime_mat.emission_enabled = true
	_lime_mat.emission = Color(1.0, 0.97, 0.9)
	var lime := CylinderMesh.new()
	lime.top_radius = 0.04
	lime.bottom_radius = 0.04
	lime.height = 0.09
	lime.material = _lime_mat
	var view := MeshInstance3D.new()
	view.mesh = lime
	view.position = head + Vector3(0.02, 0.0, 0)
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	_lamp_light = OmniLight3D.new()
	_lamp_light.light_color = Color(1.0, 0.96, 0.88)
	_lamp_light.light_energy = 4.0
	_lamp_light.omni_range = 28.0
	_lamp_light.omni_attenuation = 1.2
	_lamp_light.shadow_enabled = true
	_lamp_light.position = head + Vector3(0.1, 0.0, 0)
	_lamp_light.visible = false
	add_child(_lamp_light)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.4, 0.27)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.22, 0.22, 0.22)
	_valve = WorksHandle.new(WorksHandle.Kind.LEVER, LAMP + Vector3(-0.7, 0.55, 0.0), wood, dark,
			"Limelight\nE opens the gas to the lamp, or shuts it.")
	_valve.on = false
	_valve.call("_show")
	_valve.thrown.connect(func(on: bool) -> void: lamp_open = on)
	add_child(_valve)
