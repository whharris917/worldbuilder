class_name Windmill
extends Node3D
## A tower mill: a round whitewashed tower narrowing upward on a stone
## plinth, a door and small windows, a boat-shaped cap that turns on a
## curb at the top, four sails on a windshaft tilted up a little at the
## front, and a fantail behind on its frame. The sails turn
## anticlockwise as seen from the front, as English mills do.
##
## The sails are common sails: a lattice of bars between the stock and
## an outer rail, the cloth spread behind it, a narrow board on the
## leading side. Their plane leans back toward the tower at the top,
## because the shaft rises toward the front, which keeps the lower tips
## clear of the tower's foot.
##
## Built in its own frame: the sails face +z, y up from the plinth's
## foot. Still parts are one mesh, the turning sails another
## (CozyMesh); thin bars and rails go in the material without outlines.

const PLINTH := 0.5                     # the stone plinth's height
const TOWER := 9.0                      # the tower's height above the plinth
const FOOT_R := 2.9                     # the tower's radius at its foot
const TOP_R := 2.05                     # and at its top
const TILT := 8.0                       # the windshaft's rise toward the front, degrees
const HUB := Vector3(0.0, 10.87, 3.1)
const SAIL_R := 8.6                     # from the shaft to a sail's tip
const RPM := 10.0

var turning := true

var _mat: StandardMaterial3D
var _plain: StandardMaterial3D
var _spin: Node3D
var _speed := 1.0                       # 0 still to 1 turning, eased


func _init(mat: StandardMaterial3D, plain: StandardMaterial3D) -> void:
	name = "Windmill"
	_mat = mat
	_plain = plain
	var m := CozyMesh.new()
	var thin := CozyMesh.new()
	_tower(m)
	_cap(m, thin)
	_view(self, "Mill", m.commit(_mat))
	_view(self, "MillThin", thin.commit(_plain))
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = HUB
	rotor.rotation.x = -deg_to_rad(TILT)
	add_child(rotor)
	_spin = Node3D.new()
	_spin.set_meta(StaticMerge.MOVES, true)
	rotor.add_child(_spin)
	var s := CozyMesh.new()
	var s_thin := CozyMesh.new()
	_sails(s, s_thin)
	_view(_spin, "Sails", s.commit(_mat))
	_view(_spin, "SailBars", s_thin.commit(_plain))
	var body := StaticBody3D.new()
	add_child(body)
	for part: Array in [[FOOT_R + 0.45, PLINTH, PLINTH * 0.5], [FOOT_R, TOWER, PLINTH + TOWER * 0.5]]:
		var shape := CylinderShape3D.new()
		shape.radius = part[0]
		shape.height = part[1]
		var c := CollisionShape3D.new()
		c.shape = shape
		c.position.y = part[2]
		body.add_child(c)


## The hub's height over the plinth's foot.
func hub_height() -> float:
	return HUB.y


func _process(delta: float) -> void:
	_speed = move_toward(_speed, 1.0 if turning else 0.0, delta * 0.15)
	_spin.rotation.z = wrapf(_spin.rotation.z + delta * _speed * RPM / 60.0 * TAU, 0.0, TAU)


func _view(parent: Node3D, title: String, mesh: Mesh) -> void:
	var view := MeshInstance3D.new()
	view.name = title
	view.mesh = mesh
	parent.add_child(view)


## The tower's radius at a height over the plinth's foot.
static func radius_at(y: float) -> float:
	return lerpf(FOOT_R, TOP_R, clampf((y - PLINTH) / TOWER, 0.0, 1.0))


## A frame on the tower's face at `bearing` (radians round from +z toward
## +x) and height `y`: z out of the wall, leaning back with the taper.
static func _on_wall(bearing: float, y: float, out := 0.0) -> Transform3D:
	var lean := atan((FOOT_R - TOP_R) / TOWER)
	var b := Basis(Vector3.UP, bearing) * Basis(Vector3.RIGHT, -lean)
	return Transform3D(b, Vector3(sin(bearing), 0.0, cos(bearing)) * (radius_at(y) + out) + Vector3(0, y, 0))


func _tower(m: CozyMesh) -> void:
	var stone := Color(0.66, 0.63, 0.58)
	var lime := Color(0.94, 0.91, 0.84)
	var paint := Color(0.24, 0.43, 0.4)
	m.cyl(FOOT_R + 0.35, FOOT_R + 0.45, PLINTH, 24, CozyMesh.at(Vector3(0, PLINTH * 0.5, 0)), stone)
	m.cyl(TOP_R, FOOT_R, TOWER, 24, CozyMesh.at(Vector3(0, PLINTH + TOWER * 0.5, 0)), lime)
	# A band of render a third of the way up and a cornice under the curb.
	var band := PLINTH + TOWER * 0.42
	m.cyl(radius_at(band + 0.1) + 0.09, radius_at(band - 0.1) + 0.09, 0.2, 24, CozyMesh.at(Vector3(0, band, 0)), lime.darkened(0.1))
	var top := PLINTH + TOWER
	m.cyl(TOP_R + 0.14, TOP_R + 0.04, 0.22, 24, CozyMesh.at(Vector3(0, top - 0.11, 0)), lime.darkened(0.1))
	# The door at the front, in a frame under a stone lintel, up two steps.
	var dy := PLINTH + 1.0
	m.box(Vector3(1.24, 2.14, 0.1), _on_wall(0.0, dy + 0.03, -0.03), lime.darkened(0.18))
	m.box(Vector3(1.0, 1.98, 0.1), _on_wall(0.0, dy, 0.0), paint)
	for x: float in [-0.25, 0.25]:
		m.box(Vector3(0.03, 1.8, 0.03), _on_wall(0.0, dy, 0.05) * CozyMesh.at(Vector3(x, 0, 0)), paint.darkened(0.25))
	m.ball(0.04, 8, _on_wall(0.0, dy, 0.07) * CozyMesh.at(Vector3(0.36, 0.0, 0)), Color(0.75, 0.62, 0.3))
	m.box(Vector3(1.44, 0.22, 0.2), _on_wall(0.0, dy + 1.1, 0.0), stone)
	for k in 2:
		var depth := 0.36 * (2 - k)
		m.box(Vector3(1.5, PLINTH * 0.5, depth), CozyMesh.at(Vector3(0, PLINTH * 0.25 * (2 * k + 1), FOOT_R + 0.4 + depth * 0.5)), stone)
	# Small windows round the tower, each with a sill.
	for w: Vector2 in [Vector2(115.0, 3.3), Vector2(250.0, 3.9), Vector2(35.0, 6.4), Vector2(180.0, 7.0), Vector2(300.0, 8.1)]:
		var at := _on_wall(deg_to_rad(w.x), w.y, 0.0)
		m.box(Vector3(0.68, 0.86, 0.1), at, paint)
		m.box(Vector3(0.52, 0.7, 0.1), at * CozyMesh.at(Vector3(0, 0, 0.01)), Color(0.18, 0.24, 0.3))
		m.box(Vector3(0.05, 0.7, 0.04), at * CozyMesh.at(Vector3(0, 0, 0.06)), paint)
		m.box(Vector3(0.52, 0.05, 0.04), at * CozyMesh.at(Vector3(0, 0, 0.06)), paint)
		m.box(Vector3(0.8, 0.07, 0.16), at * CozyMesh.at(Vector3(0, -0.46, 0.04)), stone)


## The curb, the cap, the windshaft's end, and the fantail on its frame.
func _cap(m: CozyMesh, thin: CozyMesh) -> void:
	var top := PLINTH + TOWER
	var wood := Color(0.36, 0.26, 0.2)
	var cap := Color(0.6, 0.27, 0.2)
	m.cyl(TOP_R + 0.2, TOP_R + 0.2, 0.26, 24, CozyMesh.at(Vector3(0, top + 0.13, 0)), wood)
	# Boat-shaped: half an egg, longer front to back, with a finial.
	var base := top + 0.26
	m.ball(1.0, 20, CozyMesh.at(Vector3(0, base, -0.1), Basis.from_scale(Vector3(TOP_R + 0.3, 1.9, TOP_R + 0.75))), cap, true)
	m.ball(0.16, 10, CozyMesh.at(Vector3(0, base + 1.95, -0.1)), wood)
	m.cyl(0.03, 0.05, 0.3, 6, CozyMesh.at(Vector3(0, base + 1.82, -0.1)), wood)
	# A boarded gable at the front where the shaft comes out.
	m.box(Vector3(1.6, 1.4, 0.5), CozyMesh.at(Vector3(0, base + 0.65, 2.15), Basis(Vector3.RIGHT, -deg_to_rad(TILT))), cap.darkened(0.12))
	var dir := Vector3(0, sin(deg_to_rad(TILT)), cos(deg_to_rad(TILT)))
	m.rod(HUB - dir * 1.0, HUB, 0.2, 12, Color(0.25, 0.25, 0.26))
	# The fantail: a frame of struts out behind the cap, and its wheel of
	# eight vanes turned across the wind.
	var wheel := Vector3(0, base + 1.1, -TOP_R - 2.35)
	var black := Color(0.22, 0.2, 0.19)
	for s: float in [-1.0, 1.0]:
		var hub := wheel + Vector3(s * 0.22, 0, 0)
		thin.rod(Vector3(s * 0.9, base + 0.1, -TOP_R - 0.2), hub, 0.05, 6, black)
		thin.rod(Vector3(s * 0.5, base + 1.2, -TOP_R - 0.3), hub, 0.05, 6, black)
		thin.rod(Vector3(s * 0.9, base + 0.1, -TOP_R - 0.2), Vector3(s * 0.5, base + 1.2, -TOP_R - 0.3), 0.04, 6, black)
	thin.rod(wheel - Vector3(0.3, 0, 0), wheel + Vector3(0.3, 0, 0), 0.05, 8, black)
	for k in 8:
		var t := TAU * k / 8.0
		var out := Vector3(0, cos(t), sin(t))
		# Each vane pitched 30 degrees about its own arm.
		var b := Basis(Vector3.RIGHT, t) * Basis(Vector3.UP, deg_to_rad(30.0))
		m.box(Vector3(0.03, 0.8, 0.5), CozyMesh.at(wheel + out * 0.78, b), Color(0.92, 0.9, 0.84))
		thin.rod(wheel, wheel + out * 1.2, 0.022, 4, black)


## Four common sails on two stocks crossing at the hub, in the rotor's
## frame: the sails in its xy plane, the shaft along z.
func _sails(m: CozyMesh, thin: CozyMesh) -> void:
	var frame := Color(0.4, 0.3, 0.22)
	var cloth := Color(0.95, 0.92, 0.82)
	var iron := Color(0.25, 0.25, 0.26)
	m.cyl(0.34, 0.34, 0.7, 14, CozyMesh.at(Vector3(0, 0, 0.1), Basis(Vector3.RIGHT, PI * 0.5)), iron)
	m.ball(0.2, 10, CozyMesh.at(Vector3(0, 0, 0.48)), iron)
	for k in 4:
		var arm := Basis(Vector3.BACK, TAU * k / 4.0)
		# The stock, from the hub out to the tip.
		m.box(Vector3(0.22, SAIL_R, 0.22), CozyMesh.at(arm * Vector3(0, SAIL_R * 0.5, 0.22), arm), frame)
		var inner := 1.7
		var length := SAIL_R - inner - 0.15
		var mid := inner + length * 0.5
		# The cloth behind the bars on the trailing side (+x), the narrow
		# leading board on the other.
		m.box(Vector3(1.5, length - 0.1, 0.02), CozyMesh.at(arm * Vector3(0.86, mid, 0.12), arm), cloth)
		m.box(Vector3(0.3, length, 0.03), CozyMesh.at(arm * Vector3(-0.27, mid, 0.22), arm), frame.lightened(0.15))
		thin.box(Vector3(0.07, length, 0.09), CozyMesh.at(arm * Vector3(1.62, mid, 0.2), arm), frame)
		thin.box(Vector3(0.05, length, 0.06), CozyMesh.at(arm * Vector3(0.86, mid, 0.2), arm), frame)
		var bars := 14
		for b in bars + 1:
			var y := inner + length * b / bars
			thin.box(Vector3(1.98, 0.05, 0.06), CozyMesh.at(arm * Vector3(0.66, y, 0.21), arm), frame)
