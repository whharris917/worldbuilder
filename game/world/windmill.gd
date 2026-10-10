class_name Windmill
extends Node3D
## A tower mill that works: a hollow tower of whitewashed brick on a
## stone plinth, four floors inside reached by steep mill stairs, a cap
## that turns on a curb at the top to face the wind, four sails on a
## windshaft, and the gearing that carries their turning down the tower
## to a take-off spindle on the ground floor, where a machine is belted
## to it (MillLoad).
##
## The sails. Common sails: a lattice of bars between the stock and an
## outer rail, the cloth spread behind it, a narrow board on the leading
## side. Each sail is twisted along its length (its weather): the bars
## stand 22 degrees out of the plane the sails turn in at the inner end
## and 5 at the tip, because the tip moves several times faster than the
## inner end and so meets the wind from a flatter angle. The trailing
## side is set back toward the tower, so the wind pushes each sail
## toward its leading side and the sails turn anticlockwise as seen from
## the front, as English mills do. The windshaft rises 8 degrees toward
## the front, which keeps the lower tips clear of the tower.
##
## How fast they turn. The wind's push is reckoned from the sails'
## torque coefficient, a measured property of a kind of rotor: the
## torque is half the air's density times the swept area times the
## sail's radius times the wind's speed squared, times a coefficient
## that falls in a straight line from CT0 with the sails still to zero
## when the tips run LAMBDA_MAX times as fast as the wind. That puts the
## most power, about a fifth of the wind's, with the tips at a little
## over twice the wind's speed, as old sails measured. Less cloth spread
## gives less push. Against it: the machine on the spindle, the
## bearings' friction, the brake when it is on, the sails' own drag. The
## sails' speed follows from the difference and their weight (INERTIA).
## Only the wind square on the sails counts.
##
## Turning to the wind. The fantail behind the cap stands edge-on to the
## wind while the sails face it. When the wind swings round, it strikes
## the fantail's vanes and spins it; through worm gearing the fantail
## walks the cap round on a toothed ring until the sails face the wind
## again and the fantail stops. Its speed here is YAW_RATE degrees a
## second for each metre a second of wind square across it.
##
## The gearing. On the windshaft in the cap, the brake wheel (72 cogs on
## its back face) turns the wallower (24) at the top of the upright
## shaft, which runs down the middle of the tower on the cap's turning
## axis, so the two stay in mesh however the cap turns. At the foot of
## the upright shaft the great spur wheel (60) turns the pinion (12) on
## the take-off spindle: the spindle turns 15 times as fast as the
## sails. A lever drops the pinion out of mesh (the gear); the brake is a
## band of wooden blocks round the brake wheel, worked by a lever on the
## ground floor through a rope.
##
## Built in its own frame: the door faces +z, y up from the plinth's
## foot. Still parts are joined into a few meshes; the cap, the sails,
## the upright shaft and the spindle are their own (CozyMesh).

const PLINTH := 0.5                     # the stone plinth's height; the ground floor's level
const TOWER := 9.0                      # the tower's height above the plinth
const TOP := PLINTH + TOWER
const FOOT_R := 2.9                     # the tower's outer radius at its foot
const TOP_R := 2.05                     # and at its top
const WALL_FOOT := 0.45                 # the wall's thickness at its foot
const WALL_TOP := 0.3                   # and at its top
const FLOORS := [3.0, 5.3, 7.4]         # the upper floors' levels: bin floor, stone floor, dust floor
const DOOR_W := 1.0
const DOOR_H := 2.0
# Windows: bearing round from the door toward +x, degrees; sill's height.
const WINDOWS := [Vector2(160.0, 1.3), Vector2(200.0, 3.9), Vector2(320.0, 3.9), Vector2(20.0, 6.1), Vector2(140.0, 6.1),
		Vector2(250.0, 8.0)]
const WIN_W := 0.6
const WIN_H := 0.8
const STAIR_RUN := 2.9                  # each stair's length on the floor plan
const STAIR_W := 0.66
const TILT := 8.0                       # the windshaft's rise toward the front, degrees
const HUB := Vector3(0.0, 10.87, 3.1)   # in the cap's frame
const SAIL_R := 8.6                     # from the shaft to a sail's tip
const SAIL_IN := 1.7                    # where the lattice starts
const WEATHER_IN := 22.0                # the sail's twist at its inner end, degrees
const WEATHER_TIP := 5.0                # and at its tip
const BRAKE_AT := 2.55                  # the brake wheel's distance back along the shaft from the hub
const BRAKE_R := 1.25
const BRAKE_COGS := 72
const WALLOWER_Y := 9.3
const WALLOWER_R := 0.45
const WALLOWER_COGS := 24
const SPUR_Y := 2.5
const SPUR_R := 0.8
const SPUR_COGS := 60
const PINION_R := 0.2
const PINION_COGS := 12
## The take-off spindle, on the ground floor, and its belt pulley.
const SPINDLE := Vector3(1.0, 0.0, 0.0)
const PULLEY_Y := 1.1
const PULLEY_R := 0.4
const ROPE := Vector3(0.35, 0.0, 0.95)  # where the brake rope hangs
# The physics.
const AIR := 1.225                      # kg/m³
const CT0 := 0.178                      # torque coefficient with the sails still
const LAMBDA_MAX := 4.5                 # tip speed over wind speed where the push runs out
const INERTIA := 60000.0                # kg m², the sails, stocks, shaft and wheels
const BEARING_TORQUE := 150.0           # N m
const BRAKE_TORQUE := 40000.0           # N m
const GEAR_EFFICIENCY := 0.9
const YAW_RATE := 0.25                  # degrees a second per m/s of wind square across the fantail
const FANTAIL_TURNS := 2.5              # the fantail's turns per degree the cap turns
const RATIO := float(BRAKE_COGS) / WALLOWER_COGS * float(SPUR_COGS) / PINION_COGS

## The wind as it reaches the sails: m/s, and the bearing it blows from
## (degrees round from north toward east).
var wind_speed := 7.0
var wind_from := 225.0
## The share of the cloth spread on the sails, 0 to 1.
var cloth := 1.0
var brake_on := false
var in_gear := true
## The sails' speed, radians a second.
var omega := 0.0
## The bearing the sails face, as the wind's.
var cap_facing := 225.0
## The machine on the spindle.
var load: MillLoad
## Power going to the machine, watts.
var power := 0.0
var mats: Dictionary
var door: MillDoor
var gear_lever: WorksHandle
var brake_lever: WorksHandle

var _cap: Node3D
var _spin: Node3D
var _sail_view: MeshInstance3D
var _fantail: Node3D
var _upright: Node3D
var _spindle: Node3D
var _pinion: Node3D
var _brake_arm: Node3D
var _sail_angle := 0.0
var _fantail_angle := 0.0
var _lift := 0.0                        # the pinion lifted out of mesh, 0 to 1


## `materials`: "out" and "out_plain" for the outside (with and without
## outlines), "in" and "in_plain" for the inside, "glass", "glow".
func _init(materials: Dictionary) -> void:
	name = "Windmill"
	mats = materials
	var outer := CozyMesh.new()
	var inner := CozyMesh.new()
	var inner_thin := CozyMesh.new()
	var glass := CozyMesh.new()
	var glow := CozyMesh.new()
	var wall_out := CozyMesh.new()
	var wall_in := CozyMesh.new()
	_wall(wall_out, wall_in)
	_outside(outer)
	_windows(outer, glass)
	_floors(inner)
	_stairs(inner, inner_thin)
	_lanterns(inner_thin, glow)
	_upper_floors(inner)
	_view(self, "MillWallOut", wall_out.commit(mats["out"]))
	_view(self, "MillWallIn", wall_in.commit(mats["in"]))
	_view(self, "Mill", outer.commit(mats["out"]))
	_view(self, "MillInside", inner.commit(mats["in"]))
	_view(self, "MillInsideThin", inner_thin.commit(mats["in_plain"]))
	_view(self, "MillGlass", glass.commit(mats["glass"])).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view(self, "MillLamps", glow.commit(mats["glow"])).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var walls := StaticBody3D.new()
	walls.name = "Walls"
	add_child(walls)
	for m: CozyMesh in [wall_out, wall_in]:
		var c := CollisionShape3D.new()
		c.shape = m.commit(null).create_trimesh_shape()
		walls.add_child(c)
	_cylinder_body(FOOT_R + 0.45, PLINTH, Vector3(0, PLINTH * 0.5, 0))
	# A slope up the steps to the door, gentle enough to walk.
	var run := 1.1
	var ramp_at := Vector3(0, PLINTH * 0.5, FOOT_R + 0.45 + run * 0.5)
	_box_body(Vector3(1.6, 0.06, sqrt(run * run + PLINTH * PLINTH)), Transform3D(Basis(Vector3.RIGHT, atan(PLINTH / run)), ramp_at))
	_build_door()
	_build_cap()
	_build_drive()


func _ready() -> void:
	gear_lever.thrown.connect(func(on: bool) -> void: in_gear = on)
	brake_lever.thrown.connect(func(on: bool) -> void: brake_on = on)


## The machine on the spindle; it is built as the mill's child.
func attach(machine: MillLoad) -> void:
	load = machine
	machine.mill = self
	add_child(machine)


## The hub's height over the plinth's foot.
func hub_height() -> float:
	return HUB.y


## The sails' speed in turns a minute.
func rpm() -> float:
	return omega * 60.0 / TAU


## How far the sails stand off the wind, degrees.
func off_wind() -> float:
	return wrapf(wind_from - cap_facing, -180.0, 180.0)


func set_cloth(share: float) -> void:
	cloth = clampf(share, 0.0, 1.0)
	if _sail_view != null:
		var m := CozyMesh.new()
		_sails(m)
		_sail_view.mesh = m.commit(mats["out"])


func state() -> Dictionary:
	return {"cap": cap_facing, "omega": omega, "brake": brake_on, "gear": in_gear, "door": door.open,
			"load": load.state() if load != null else {}}


func restore(saved: Dictionary) -> void:
	cap_facing = float(saved.get("cap", wind_from))
	omega = float(saved.get("omega", 0.0))
	brake_on = bool(saved.get("brake", false))
	in_gear = bool(saved.get("gear", true))
	_lift = 0.0 if in_gear else 1.0
	for pair: Array in [[brake_lever, brake_on], [gear_lever, in_gear]]:
		var lever: WorksHandle = pair[0]
		lever.on = pair[1]
		lever.call("_show")
	door.set_open(bool(saved.get("door", false)))
	if load != null:
		load.restore(saved.get("load", {}))


## ---- the physics ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	# The fantail walks the cap round toward the wind.
	var err := off_wind()
	var yaw_rate := YAW_RATE * wind_speed * sin(deg_to_rad(err))
	cap_facing = wrapf(cap_facing + yaw_rate * delta, 0.0, 360.0)
	_fantail_angle = wrapf(_fantail_angle + yaw_rate * delta * FANTAIL_TURNS * TAU, 0.0, TAU)
	# The sails: the wind's push against what holds them.
	var v := wind_speed * maxf(cos(deg_to_rad(err)), 0.0)
	var area := PI * SAIL_R * SAIL_R
	var ct := CT0 * (0.12 + 0.88 * cloth)
	var drive := 0.5 * AIR * area * SAIL_R * ct * (v * v - v * omega * SAIL_R / LAMBDA_MAX) - 40.0 * omega * absf(omega)
	var spindle := omega * RATIO
	var engaged := load != null and in_gear and _lift < 0.01
	power = 0.0
	if engaged:
		var held := load.torque(spindle)
		drive -= held * RATIO / GEAR_EFFICIENCY
		power = held * spindle
	var friction := BEARING_TORQUE + (BRAKE_TORQUE if brake_on else 0.0)
	if absf(omega) < 0.01 and absf(drive) <= friction:
		omega = 0.0
	else:
		var before := omega
		var way := signf(omega) if absf(omega) >= 0.01 else signf(drive)
		omega += (drive - way * friction) / INERTIA * delta
		# Friction stops the sails; it never turns them back.
		if before != 0.0 and signf(omega) != signf(before) and absf(drive) <= friction:
			omega = 0.0
	if load != null:
		load.advance(spindle if engaged else 0.0, delta)
	# The parts turned to match.
	_lift = move_toward(_lift, 0.0 if in_gear else 1.0, delta * 1.5)
	_sail_angle = wrapf(_sail_angle + omega * delta, 0.0, TAU * WALLOWER_COGS * PINION_COGS)
	_spin.rotation.z = fmod(_sail_angle, TAU)
	_upright.rotation.y = -fmod(_sail_angle * BRAKE_COGS / WALLOWER_COGS, TAU)
	if _lift < 0.01:
		_spindle.rotation.y = fmod(_sail_angle * RATIO, TAU)
	_pinion.position.y = SPUR_Y - 0.22 * _lift
	_fantail.rotation.x = _fantail_angle
	_brake_arm.rotation.x = -0.05 if brake_on else 0.03
	var to_wind := Vector3(sin(deg_to_rad(cap_facing)), 0.0, -cos(deg_to_rad(cap_facing)))
	var local := global_basis.inverse() * to_wind
	_cap.rotation.y = atan2(local.x, local.z)


## ---- helpers ----------------------------------------------------------------

func _view(parent: Node3D, title: String, mesh: Mesh) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = title
	view.mesh = mesh
	parent.add_child(view)
	return view


func _box_body(size: Vector3, xf: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.transform = xf
	var shape := BoxShape3D.new()
	shape.size = size
	var c := CollisionShape3D.new()
	c.shape = shape
	body.add_child(c)
	add_child(body)


func _cylinder_body(radius: float, height: float, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var c := CollisionShape3D.new()
	c.shape = shape
	body.add_child(c)
	add_child(body)


## The tower's outer radius at a height over the plinth's foot.
static func radius_at(y: float) -> float:
	return lerpf(FOOT_R, TOP_R, clampf((y - PLINTH) / TOWER, 0.0, 1.0))


static func wall_at(y: float) -> float:
	return lerpf(WALL_FOOT, WALL_TOP, clampf((y - PLINTH) / TOWER, 0.0, 1.0))


## The tower's inner radius at a height.
static func inner_at(y: float) -> float:
	return radius_at(y) - wall_at(y)


## A point on the tower at `bearing` (radians round from +z toward +x),
## radius `r`, height `y`.
static func _at(bearing: float, r: float, y: float) -> Vector3:
	return Vector3(sin(bearing) * r, y, cos(bearing) * r)


## A frame on the tower's outer face at `bearing` and height `y`: z out
## of the wall, leaning back with the taper.
static func _on_wall(bearing: float, y: float, out := 0.0) -> Transform3D:
	var lean := atan((FOOT_R - TOP_R) / TOWER)
	var b := Basis(Vector3.UP, bearing) * Basis(Vector3.RIGHT, -lean)
	return Transform3D(b, _at(bearing, radius_at(y) + out, y))


## A ring round the y axis of `xf`: radii r0 to r1, from y0 to y1; its
## outside, inside, top and bottom.
static func _ring(m: CozyMesh, r0: float, r1: float, y0: float, y1: float, xf: Transform3D, colour: Color, sides := 32) -> void:
	var nb := xf.basis
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var o0 := Vector3(sin(a0), 0, cos(a0))
		var o1 := Vector3(sin(a1), 0, cos(a1))
		var lo := Vector3.UP * y0
		var hi := Vector3.UP * y1
		m.quad_normals(xf * (o0 * r1 + lo), xf * (o1 * r1 + lo), xf * (o1 * r1 + hi), xf * (o0 * r1 + hi),
				[nb * o0, nb * o1, nb * o1, nb * o0], colour)
		m.quad_normals(xf * (o0 * r0 + lo), xf * (o1 * r0 + lo), xf * (o1 * r0 + hi), xf * (o0 * r0 + hi),
				[-(nb * o0), -(nb * o1), -(nb * o1), -(nb * o0)], colour)
		m.quad(xf * (o0 * r0 + hi), xf * (o1 * r0 + hi), xf * (o1 * r1 + hi), xf * (o0 * r1 + hi), nb * Vector3.UP, colour)
		m.quad(xf * (o0 * r0 + lo), xf * (o1 * r0 + lo), xf * (o1 * r1 + lo), xf * (o0 * r1 + lo), nb * Vector3.DOWN, colour)


## Cogs round a wheel: `count` blocks of `size` at radius `r` in the xz
## plane of `xf`, each with its z side pointing out from the middle.
static func _cogs(m: CozyMesh, count: int, r: float, size: Vector3, xf: Transform3D, colour: Color) -> void:
	for k in count:
		var a := TAU * k / count
		m.box(size, xf * Transform3D(Basis(Vector3.UP, a), Vector3(sin(a), 0, cos(a)) * r), colour)


## ---- the tower --------------------------------------------------------------

## The tower's wall: its outer face (into `outer`), its inner face and the
## reveals of its openings (into `inner`), cut by the door and windows.
func _wall(outer: CozyMesh, inner: CozyMesh) -> void:
	var lime := Color(0.94, 0.91, 0.84)
	var plaster := Color(0.86, 0.82, 0.74)
	var start := deg_to_rad(270.0)
	var openings: Array = []
	var hd := asin(DOOR_W * 0.5 / radius_at(PLINTH + DOOR_H * 0.5))
	var d0 := wrapf(-hd, start, start + TAU)
	openings.append([d0, d0 + 2.0 * hd, PLINTH, PLINTH + DOOR_H])
	for w: Vector2 in WINDOWS:
		var h := asin(WIN_W * 0.5 / radius_at(w.y + WIN_H * 0.5))
		var b := wrapf(deg_to_rad(w.x) - h, start, start + TAU)
		openings.append([b, b + 2.0 * h, w.y, w.y + WIN_H])
	var angles: Array[float] = []
	var sides := 48
	for i in sides + 1:
		angles.append(start + TAU * i / sides)
	var ys: Array[float] = [PLINTH, TOP]
	for o: Array in openings:
		angles.append(o[0])
		angles.append(o[1])
		ys.append(o[2])
		ys.append(o[3])
	angles.sort()
	ys.sort()
	var slope_out := (FOOT_R - TOP_R) / TOWER
	var slope_in := (FOOT_R - WALL_FOOT - TOP_R + WALL_TOP) / TOWER
	for i in angles.size() - 1:
		var a0 := angles[i]
		var a1 := angles[i + 1]
		if a1 - a0 < 1e-4:
			continue
		var am := (a0 + a1) * 0.5
		var n0 := Vector3(sin(a0), slope_out, cos(a0))
		var n1 := Vector3(sin(a1), slope_out, cos(a1))
		var m0 := Vector3(-sin(a0), -slope_in, -cos(a0))
		var m1 := Vector3(-sin(a1), -slope_in, -cos(a1))
		for j in ys.size() - 1:
			var y0 := ys[j]
			var y1 := ys[j + 1]
			if y1 - y0 < 1e-4:
				continue
			var ym := (y0 + y1) * 0.5
			var hole := false
			for o: Array in openings:
				if am > o[0] and am < o[1] and ym > o[2] and ym < o[3]:
					hole = true
			if hole:
				continue
			outer.quad_normals(_at(a0, radius_at(y0), y0), _at(a1, radius_at(y0), y0), _at(a1, radius_at(y1), y1),
					_at(a0, radius_at(y1), y1), [n0, n1, n1, n0], lime)
			inner.quad_normals(_at(a0, inner_at(y0), y0), _at(a1, inner_at(y0), y0), _at(a1, inner_at(y1), y1),
					_at(a0, inner_at(y1), y1), [m0, m1, m1, m0], plaster)
		# The wall's top, under the curb.
		inner.quad(_at(a0, inner_at(TOP), TOP), _at(a1, inner_at(TOP), TOP), _at(a1, radius_at(TOP), TOP),
				_at(a0, radius_at(TOP), TOP), Vector3.UP, plaster)
		# Sills and heads.
		for o: Array in openings:
			if am > o[0] and am < o[1]:
				for pair: Array in [[o[2], Vector3.UP], [o[3], Vector3.DOWN]]:
					var y: float = pair[0]
					inner.quad(_at(a0, inner_at(y), y), _at(a1, inner_at(y), y), _at(a1, radius_at(y), y),
							_at(a0, radius_at(y), y), pair[1], plaster)
	# The jambs, the openings' sides through the wall.
	for o: Array in openings:
		for j in ys.size() - 1:
			var y0 := ys[j]
			var y1 := ys[j + 1]
			var ym := (y0 + y1) * 0.5
			if ym < o[2] or ym > o[3]:
				continue
			for side: Array in [[o[0], 1.0], [o[1], -1.0]]:
				var a: float = side[0]
				var n := Vector3(cos(a), 0, -sin(a)) * float(side[1])
				inner.quad(_at(a, inner_at(y0), y0), _at(a, radius_at(y0), y0), _at(a, radius_at(y1), y1),
						_at(a, inner_at(y1), y1), n, plaster)


## The plinth, the bands round the tower, the door's frame and steps.
func _outside(m: CozyMesh) -> void:
	var stone := Color(0.66, 0.63, 0.58)
	var lime := Color(0.94, 0.91, 0.84)
	var paint := Color(0.24, 0.43, 0.4)
	m.cyl(FOOT_R + 0.35, FOOT_R + 0.45, PLINTH, 32, CozyMesh.at(Vector3(0, PLINTH * 0.5, 0)), stone)
	# A band of render at the bin floor's level.
	var band: float = float(FLOORS[0]) - 0.1
	_ring(m, radius_at(band) - 0.02, radius_at(band) + 0.09, band - 0.1, band + 0.1, Transform3D.IDENTITY, lime.darkened(0.1), 48)
	_ring(m, TOP_R - 0.02, TOP_R + 0.14, TOP - 0.22, TOP, Transform3D.IDENTITY, lime.darkened(0.1), 48)
	# The door's frame, a stone lintel, and two steps up to it.
	var dy := PLINTH + DOOR_H * 0.5
	var sag := radius_at(dy) - sqrt(radius_at(dy) ** 2 - 0.56 * 0.56)
	for s: float in [-1.0, 1.0]:
		m.box(Vector3(0.12, DOOR_H + 0.1, 0.08), _on_wall(0.0, dy, 0.02) * CozyMesh.at(Vector3(s * 0.56, 0.05, -sag)), paint.darkened(0.2))
	m.box(Vector3(1.44, 0.24, 0.2), _on_wall(0.0, PLINTH + DOOR_H + 0.12, 0.02), stone)
	for k in 2:
		var depth := 0.36 * (2 - k)
		m.box(Vector3(1.5, PLINTH * 0.5, depth), CozyMesh.at(Vector3(0, PLINTH * 0.25 * (2 * k + 1), FOOT_R + 0.4 + depth * 0.5)), stone)


## Each window: a painted frame on the outer face, a stone sill, glass
## with glazing bars half way through the wall.
func _windows(m: CozyMesh, glass: CozyMesh) -> void:
	var stone := Color(0.66, 0.63, 0.58)
	var paint := Color(0.24, 0.43, 0.4)
	for w: Vector2 in WINDOWS:
		var b := deg_to_rad(w.x)
		var yc := w.y + WIN_H * 0.5
		var r := radius_at(yc)
		var sag := r - sqrt(r * r - (WIN_W * 0.5 + 0.05) ** 2)
		var face := _on_wall(b, yc, 0.02)
		for s: float in [-1.0, 1.0]:
			m.box(Vector3(0.1, WIN_H + 0.2, 0.06), face * CozyMesh.at(Vector3(s * (WIN_W * 0.5 + 0.05), 0, -sag)), paint)
		m.box(Vector3(WIN_W + 0.2, 0.1, 0.06), face * CozyMesh.at(Vector3(0, WIN_H * 0.5 + 0.05, 0)), paint)
		m.box(Vector3(WIN_W + 0.3, 0.08, 0.2), face * CozyMesh.at(Vector3(0, -WIN_H * 0.5 - 0.04, 0.02)), stone)
		var depth := r - wall_at(yc) * 0.5
		var mid := Transform3D(Basis(Vector3.UP, b), _at(b, depth, yc))
		var width := WIN_W * depth / r
		glass.box(Vector3(width, WIN_H, 0.01), mid, Color(0.75, 0.85, 0.9, 0.22))
		m.box(Vector3(0.03, WIN_H, 0.04), mid, paint)
		m.box(Vector3(width, 0.03, 0.04), mid, paint)


## The door, hung at its left jamb seen from outside, half way through
## the wall, opening inward.
func _build_door() -> void:
	var r := radius_at(PLINTH + DOOR_H * 0.5) - wall_at(PLINTH) * 0.5
	var hd := asin(DOOR_W * 0.5 / radius_at(PLINTH + DOOR_H * 0.5))
	var width := 2.0 * r * sin(hd) - 0.04
	door = MillDoor.new(width, DOOR_H - 0.03, Color(0.24, 0.43, 0.4), mats["out"], "Door")
	door.position = Vector3(-width * 0.5, PLINTH + 0.01, r * cos(hd))
	add_child(door)


## ---- the floors and stairs ---------------------------------------------------

## A stair's plan: [bottom level, top level, side (-1 west, +1 east; it
## rises toward z of the same sign), the outer edge's and the inner
## edge's distance from the middle, its middle line's x, its bottom end's
## z, its top end's z]. Stair k rises to upper floor k.
func stair(k: int) -> Array:
	var y0: float = PLINTH if k == 0 else float(FLOORS[k - 1])
	var y1: float = FLOORS[k]
	var side := -1.0 if k % 2 == 0 else 1.0
	var r := inner_at(y1) - 0.06
	var x_out := sqrt(r * r - (STAIR_RUN * 0.5) ** 2)
	var x_in := x_out - STAIR_W
	return [y0, y1, side, x_out, x_in, side * (x_out + x_in) * 0.5, -side * STAIR_RUN * 0.5, side * STAIR_RUN * 0.5]


## How far along a stair the floor above must be open for a head to
## pass under it: where the stair's tread is less than 2.2 m below the
## underside of the floor above.
func _open_from(k: int) -> float:
	var s := stair(k)
	var rise: float = float(s[1]) - float(s[0])
	return maxf((rise - 2.2) * STAIR_RUN / rise, 0.0)


## The holes in upper floor `k`: the upright shaft's, and the stairwell
## of the stair rising to it, as [x0, x1, z0, z1].
func _holes(k: int) -> Array:
	var s := stair(k)
	var side: float = s[2]
	var xa: float = side * float(s[4])
	var xb: float = side * (float(s[3]) + 0.1)
	var za: float = float(s[6]) + side * _open_from(k)
	var zb: float = float(s[7]) + side * 0.05
	return [[-0.17, 0.17, -0.17, 0.17], [minf(xa, xb) - 0.03, maxf(xa, xb) + 0.03, minf(za, zb), maxf(za, zb)]]


## Cuts the spans [a, b] in `runs` where they cross [lo, hi].
static func _cut(runs: Array, lo: float, hi: float) -> Array:
	var out: Array = []
	for run: Array in runs:
		if run[1] <= lo or run[0] >= hi:
			out.append(run)
			continue
		if run[0] < lo:
			out.append([run[0], lo])
		if run[1] > hi:
			out.append([hi, run[1]])
	return out


## Each upper floor: boards running east to west on joists running north
## to south, cut round the holes, a solid for each length of board; and
## the ground floor's flags on the plinth.
func _floors(m: CozyMesh) -> void:
	var body := StaticBody3D.new()
	body.name = "Floors"
	add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var board_w := 0.24
	for k in FLOORS.size():
		var level: float = FLOORS[k]
		var ri := inner_at(level) - 0.02
		var holes := _holes(k)
		var z := -ri
		while z < ri:
			var z0 := z
			var z1 := minf(z + board_w, ri)
			z += board_w
			var far := maxf(absf(z0), absf(z1))
			if far >= ri:
				continue
			var half := sqrt(ri * ri - far * far) - 0.02
			var runs: Array = [[-half, half]]
			for h: Array in holes:
				if z1 > h[2] and z0 < h[3]:
					runs = _cut(runs, h[0], h[1])
			var tone := Color(0.66, 0.5, 0.34).darkened(rng.randf_range(-0.06, 0.12))
			for run: Array in runs:
				var length: float = run[1] - run[0]
				if length < 0.05:
					continue
				var at := Vector3((run[0] + run[1]) * 0.5, level - 0.025, (z0 + z1) * 0.5)
				m.box(Vector3(length, 0.05, z1 - z0 - 0.006), CozyMesh.at(at), tone)
				var shape := BoxShape3D.new()
				shape.size = Vector3(length, 0.05, z1 - z0)
				var c := CollisionShape3D.new()
				c.shape = shape
				c.position = at
				body.add_child(c)
		var rj := inner_at(level - 0.15) - 0.03
		for x: float in [-1.75, -1.05, -0.35, 0.35, 1.05, 1.75]:
			if absf(x) > rj - 0.1:
				continue
			var half := sqrt(rj * rj - x * x)
			var runs: Array = [[-half, half]]
			for h: Array in holes:
				if x + 0.06 > h[0] and x - 0.06 < h[1]:
					runs = _cut(runs, h[2], h[3])
			for run: Array in runs:
				if run[1] - run[0] < 0.1:
					continue
				m.box(Vector3(0.12, 0.18, run[1] - run[0]), CozyMesh.at(Vector3(x, level - 0.14, (run[0] + run[1]) * 0.5)),
						Color(0.5, 0.37, 0.26))
	var flags := FOOT_R - WALL_FOOT
	m.cyl(flags, flags, 0.02, 32, CozyMesh.at(Vector3(0, PLINTH + 0.01, 0)), Color(0.6, 0.57, 0.53))


## The stairs: steep open treads between two strings, a handrail on the
## open side, a slope underneath to walk on; round each stairwell a rail
## on the floor above, open at the top for stepping off.
func _stairs(m: CozyMesh, thin: CozyMesh) -> void:
	var body := StaticBody3D.new()
	body.name = "Stairs"
	add_child(body)
	var wood := Color(0.58, 0.43, 0.29)
	for k in FLOORS.size():
		var s := stair(k)
		var y0: float = s[0]
		var y1: float = s[1]
		var side: float = s[2]
		var xc: float = s[5]
		var zb: float = s[6]
		var zt: float = s[7]
		var rise := y1 - y0
		var length := sqrt(rise * rise + STAIR_RUN * STAIR_RUN)
		var along := Basis(Vector3.RIGHT, -side * atan(rise / STAIR_RUN))
		var mid := Vector3(xc, (y0 + y1) * 0.5, (zb + zt) * 0.5)
		for e: float in [-1.0, 1.0]:
			m.box(Vector3(0.05, 0.24, length), Transform3D(along, mid + Vector3(e * (STAIR_W * 0.5 - 0.025), -0.08, 0)), wood)
		var treads := roundi(rise / 0.25) - 1
		for t in range(1, treads + 1):
			var f := float(t) / (treads + 1)
			m.box(Vector3(STAIR_W - 0.1, 0.04, 0.22), CozyMesh.at(Vector3(xc, y0 + rise * f - 0.02, lerpf(zb, zt, f))), wood.lightened(0.08))
		var normal := along * Vector3.UP
		var shape := BoxShape3D.new()
		shape.size = Vector3(STAIR_W, 0.1, length)
		var c := CollisionShape3D.new()
		c.shape = shape
		c.transform = Transform3D(along, mid - normal * 0.05)
		body.add_child(c)
		var x_rail := xc - side * (STAIR_W * 0.5 - 0.03)
		thin.rod(Vector3(x_rail, y0 + 0.9, zb), Vector3(x_rail, y1 + 0.9, zt), 0.025, 6, wood)
		thin.rod(Vector3(x_rail, y0, zb), Vector3(x_rail, y0 + 0.92, zb), 0.025, 6, wood)
		# The rail round the stairwell on the floor above.
		var hole: Array = _holes(k)[1]
		var x_edge: float = hole[1] if side < 0.0 else hole[0]
		var x_wall: float = hole[0] if side < 0.0 else hole[1]
		var z_low := zb + side * _open_from(k)
		var z_open := zt - side * 0.9
		for run: Array in [[Vector3(x_edge, y1, z_low), Vector3(x_edge, y1, z_open)], [Vector3(x_edge, y1, z_low), Vector3(x_wall, y1, z_low)]]:
			var a: Vector3 = run[0]
			var b: Vector3 = run[1]
			thin.rod(a + Vector3.UP * 0.95, b + Vector3.UP * 0.95, 0.025, 6, wood)
			thin.rod(a + Vector3.UP * 0.5, b + Vector3.UP * 0.5, 0.02, 6, wood)
			for p: Vector3 in [a, b]:
				thin.box(Vector3(0.06, 0.95, 0.06), CozyMesh.at(p + Vector3.UP * 0.475), wood)
			var guard := BoxShape3D.new()
			guard.size = Vector3(0.06, 1.0, a.distance_to(b)) if absf(a.x - b.x) < 0.01 else Vector3(a.distance_to(b), 1.0, 0.06)
			var cg := CollisionShape3D.new()
			cg.shape = guard
			cg.position = (a + b) * 0.5 + Vector3.UP * 0.5
			body.add_child(cg)


## Lanterns hung on each floor, lit day and night.
func _lanterns(thin: CozyMesh, glow: CozyMesh) -> void:
	var iron := Color(0.2, 0.2, 0.19)
	for at: Vector3 in [Vector3(-0.3, 2.3, 1.5), Vector3(-0.2, 4.6, 1.2), Vector3(0.3, 6.75, -1.0), Vector3(-1.2, 9.05, 0.9)]:
		thin.rod(at + Vector3(0, 0.12, 0), at + Vector3(0, 0.5, 0), 0.006, 4, iron)
		thin.cyl(0.03, 0.07, 0.06, 10, CozyMesh.at(at + Vector3(0, 0.12, 0)), iron)
		thin.cyl(0.065, 0.065, 0.03, 10, CozyMesh.at(at + Vector3(0, -0.1, 0)), iron)
		glow.cyl(0.05, 0.055, 0.17, 10, CozyMesh.at(at), Color(1.0, 0.85, 0.6))
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.74, 0.45)
		light.light_energy = 0.8
		light.omni_range = 4.5
		light.omni_attenuation = 1.5
		light.position = at
		add_child(light)


## The bin floor's sacks and the stone floor's spare sail cloth.
func _upper_floors(m: CozyMesh) -> void:
	var sack := Color(0.78, 0.7, 0.55)
	for p: Vector3 in [Vector3(0.4, 0, -1.6), Vector3(0.95, 0, -1.4), Vector3(0.65, 0, -1.1), Vector3(-0.2, 0, -1.75)]:
		var at := p + Vector3(0, float(FLOORS[0]) + 0.32, 0)
		m.ball(1.0, 10, CozyMesh.at(at, Basis(Vector3.UP, p.x * 3.0) * Basis.from_scale(Vector3(0.26, 0.33, 0.2))), sack)
		m.cyl(0.07, 0.1, 0.12, 8, CozyMesh.at(at + Vector3(0, 0.36, 0)), sack.darkened(0.1))
	var level: float = FLOORS[1]
	m.rod(Vector3(-0.3, level + 0.18, -1.45), Vector3(-0.1, level + 0.18, 0.2), 0.18, 12, Color(0.92, 0.88, 0.76))
	m.box(Vector3(0.7, 0.4, 0.4), CozyMesh.at(Vector3(-1.2, level + 0.2, 0.9), Basis(Vector3.UP, 0.6)), Color(0.45, 0.33, 0.24))


## ---- the cap, the sails and the fantail -------------------------------------

func _build_cap() -> void:
	# The curb the cap turns on stays with the tower; the rack of teeth
	# round its inside is what the fantail's worm walks along.
	var still := CozyMesh.new()
	var wood := Color(0.36, 0.26, 0.2)
	_ring(still, TOP_R - WALL_TOP - 0.05, TOP_R + 0.2, TOP, TOP + 0.26, Transform3D.IDENTITY, wood, 48)
	_cogs(still, 120, TOP_R - WALL_TOP - 0.08, Vector3(0.05, 0.08, 0.06), CozyMesh.at(Vector3(0, TOP + 0.2, 0)), wood.darkened(0.2))
	_view(self, "Curb", still.commit(mats["out"]))
	_cap = Node3D.new()
	_cap.name = "Cap"
	add_child(_cap)
	var m := CozyMesh.new()
	var inside := CozyMesh.new()
	var cap := Color(0.6, 0.27, 0.2)
	var base := TOP + 0.26
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 1.0
	dome.radial_segments = 24
	dome.rings = 10
	dome.is_hemisphere = true
	m.add(dome, CozyMesh.at(Vector3(0, base, -0.1), Basis.from_scale(Vector3(TOP_R + 0.3, 1.9, TOP_R + 0.75))), cap)
	inside.add_inside(dome, CozyMesh.at(Vector3(0, base, -0.1), Basis.from_scale(Vector3(TOP_R + 0.22, 1.82, TOP_R + 0.67))),
			Color(0.62, 0.48, 0.36))
	m.ball(0.16, 10, CozyMesh.at(Vector3(0, base + 1.95, -0.1)), wood)
	m.cyl(0.03, 0.05, 0.3, 6, CozyMesh.at(Vector3(0, base + 1.82, -0.1)), wood)
	# A boarded gable at the front where the shaft comes out.
	m.box(Vector3(1.6, 1.4, 0.3), CozyMesh.at(Vector3(0, base + 0.7, 2.45), Basis(Vector3.RIGHT, -deg_to_rad(TILT))), cap.darkened(0.12))
	# The cap's frame: two sheer beams front to back outside the brake
	# wheel, the breast beam carrying the neck bearing, the tail beam
	# carrying the tail bearing.
	var dir := Vector3(0, sin(deg_to_rad(TILT)), cos(deg_to_rad(TILT)))
	var beam := Color(0.5, 0.37, 0.26)
	for s: float in [-1.0, 1.0]:
		inside.box(Vector3(0.22, 0.26, 4.2), CozyMesh.at(Vector3(s * 1.45, base + 0.1, 0.1)), beam)
	for z: float in [1.95, -1.55]:
		var on_shaft := HUB - dir * ((HUB.z - z) / dir.z)
		inside.box(Vector3(3.1, 0.24, 0.26), CozyMesh.at(Vector3(0, base + 0.32, z)), beam)
		inside.box(Vector3(0.5, on_shaft.y - base - 0.62, 0.3), CozyMesh.at(Vector3(0, (on_shaft.y - 0.18 + base + 0.44) * 0.5, z)), beam.darkened(0.1))
		inside.box(Vector3(0.6, 0.12, 0.34), CozyMesh.at(Vector3(0, on_shaft.y - 0.25, z)), Color(0.55, 0.5, 0.35))
	# The brake: a band of blocks round the brake wheel's top, its end on a
	# lever that the rope pulls down.
	var wheel := HUB - dir * BRAKE_AT
	var face := Basis(Vector3.RIGHT, -deg_to_rad(TILT))
	for k in 9:
		var a := deg_to_rad(-100.0 + 200.0 * k / 8.0)
		var out := face * Vector3(sin(a), cos(a), 0)
		inside.box(Vector3(0.34, 0.1, 0.24), CozyMesh.at(wheel + out * (BRAKE_R + 0.06), face * Basis(Vector3.BACK, -a)), Color(0.42, 0.32, 0.22))
	_brake_arm = Node3D.new()
	_brake_arm.position = Vector3(1.45, base + 0.35, -1.3)
	_cap.add_child(_brake_arm)
	var arm := CozyMesh.new()
	arm.box(Vector3(0.16, 0.16, 3.4), CozyMesh.at(Vector3(0, 0, 1.6)), beam)
	_view(_brake_arm, "BrakeLever", arm.commit(mats["in"]))
	_view(_cap, "CapShell", m.commit(mats["out"]))
	_view(_cap, "CapInside", inside.commit(mats["in_plain"]))
	# The fantail: a frame of struts out behind the cap, and its wheel of
	# eight vanes turned across the sails' line, so it catches only wind
	# from the side; its shaft runs down to the worm on the curb's rack.
	var thin := CozyMesh.new()
	var at := Vector3(0, base + 1.1, -TOP_R - 2.35)
	var black := Color(0.22, 0.2, 0.19)
	for s: float in [-1.0, 1.0]:
		var hub := at + Vector3(s * 0.22, 0, 0)
		thin.rod(Vector3(s * 0.9, base + 0.1, -TOP_R - 0.2), hub, 0.05, 6, black)
		thin.rod(Vector3(s * 0.5, base + 1.2, -TOP_R - 0.3), hub, 0.05, 6, black)
		thin.rod(Vector3(s * 0.9, base + 0.1, -TOP_R - 0.2), Vector3(s * 0.5, base + 1.2, -TOP_R - 0.3), 0.04, 6, black)
	thin.rod(at + Vector3(0.22, 0, 0), Vector3(0.25, TOP + 0.3, -TOP_R - 0.05), 0.035, 6, black)
	_view(_cap, "FantailFrame", thin.commit(mats["out_plain"]))
	_fantail = Node3D.new()
	_fantail.position = at
	_fantail.set_meta(StaticMerge.MOVES, true)
	_cap.add_child(_fantail)
	var vanes := CozyMesh.new()
	vanes.rod(Vector3(-0.3, 0, 0), Vector3(0.3, 0, 0), 0.05, 8, black)
	for k in 8:
		var t := TAU * k / 8.0
		var out := Vector3(0, cos(t), sin(t))
		vanes.box(Vector3(0.03, 0.8, 0.5), CozyMesh.at(out * 0.78, Basis(Vector3.RIGHT, t) * Basis(Vector3.UP, deg_to_rad(30.0))), Color(0.92, 0.9, 0.84))
		vanes.rod(Vector3.ZERO, out * 1.2, 0.022, 4, black)
	_view(_fantail, "Fantail", vanes.commit(mats["out"]))
	# The rotor: the hub, the stocks, the sails, the windshaft and the
	# brake wheel, turning together.
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = HUB
	rotor.rotation.x = -deg_to_rad(TILT)
	_cap.add_child(rotor)
	_spin = Node3D.new()
	_spin.set_meta(StaticMerge.MOVES, true)
	rotor.add_child(_spin)
	var shaft := CozyMesh.new()
	var iron := Color(0.25, 0.25, 0.26)
	shaft.cyl(0.34, 0.34, 0.7, 14, CozyMesh.at(Vector3(0, 0, 0.1), Basis(Vector3.RIGHT, PI * 0.5)), iron)
	shaft.ball(0.2, 10, CozyMesh.at(Vector3(0, 0, 0.48)), iron)
	shaft.cyl(0.22, 0.22, 4.9, 12, CozyMesh.at(Vector3(0, 0, -2.4), Basis(Vector3.RIGHT, PI * 0.5)), Color(0.45, 0.34, 0.24))
	var frame := Color(0.4, 0.3, 0.22)
	for k in 2:
		var b := Basis(Vector3.BACK, PI * 0.5 * k)
		shaft.box(Vector3(0.22, SAIL_R * 2.0, 0.22), CozyMesh.at(b * Vector3(0, 0, 0.22), b), frame)
	var brake := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -BRAKE_AT))
	_ring(shaft, BRAKE_R - 0.2, BRAKE_R, -0.12, 0.12, brake, Color(0.55, 0.41, 0.28), 36)
	for s: float in [-1.0, 1.0]:
		for k in 2:
			var b := Basis(Vector3.BACK, PI * 0.5 * k)
			shaft.box(Vector3(BRAKE_R * 2.0 - 0.2, 0.14, 0.14), CozyMesh.at(Vector3(0, 0, -BRAKE_AT) + b * Vector3(0, s * 0.3, 0), b), Color(0.5, 0.37, 0.26))
	# The cogs stand out of the wheel's back face, toward the tail, near
	# its rim, where the wallower's teeth meet them.
	_cogs(shaft, BRAKE_COGS, BRAKE_R - 0.06, Vector3(0.06, 0.18, 0.1), brake * CozyMesh.at(Vector3(0, -0.21, 0)), Color(0.72, 0.58, 0.4))
	_view(_spin, "Shaft", shaft.commit(mats["in"]))
	_sail_view = _view(_spin, "Sails", ArrayMesh.new())
	set_cloth(cloth)


## Four common sails in the rotor's frame (the sails in its xy plane, the
## shaft along z toward the front), each twisted along its length.
func _sails(m: CozyMesh) -> void:
	var frame := Color(0.4, 0.3, 0.22)
	var canvas := Color(0.95, 0.92, 0.82)
	var length := SAIL_R - SAIL_IN - 0.15
	var bars := 14
	var cloth_to := 0.05 + 1.52 * cloth
	for k in 4:
		var arm := Basis(Vector3.BACK, TAU * k / 4.0)
		var prev: Array = []
		for b in bars + 1:
			var f := float(b) / bars
			var stock := arm * Vector3(0, SAIL_IN + length * f, 0.22)
			var twist := arm * Basis(Vector3.UP, deg_to_rad(lerpf(WEATHER_IN, WEATHER_TIP, f)))
			# Points across the sail at x, `forward` in front of the stock.
			var row: Array = []
			for p: Vector2 in [Vector2(0.05, -0.05), Vector2(cloth_to, -0.05), Vector2(-0.33, 0.0), Vector2(-0.03, 0.0),
					Vector2(1.62, 0.0), Vector2(0.86, 0.0)]:
				row.append(stock + twist * Vector3(p.x, 0, p.y))
			m.box(Vector3(1.98, 0.05, 0.06), CozyMesh.at(stock + twist * Vector3(0.66, 0, 0), twist), frame)
			if not prev.is_empty():
				var n: Vector3 = twist * Vector3.BACK
				if cloth > 0.02:
					m.quad(prev[0], prev[1], row[1], row[0], n, canvas)
					m.quad(prev[0], prev[1], row[1], row[0], -n, canvas.darkened(0.08))
				m.quad(prev[2], prev[3], row[3], row[2], n, frame.lightened(0.15))
				m.quad(prev[2], prev[3], row[3], row[2], -n, frame.lightened(0.1))
				m.rod(prev[4], row[4], 0.04, 4, frame)
				m.rod(prev[5], row[5], 0.03, 4, frame)
			prev = row


## ---- the gearing on the ground floor ----------------------------------------

## The upright shaft with the wallower at its top and the great spur
## wheel at its foot; the take-off spindle with its pinion and belt
## pulley; the gear and brake levers.
func _build_drive() -> void:
	_upright = Node3D.new()
	_upright.name = "UprightShaft"
	_upright.set_meta(StaticMerge.MOVES, true)
	add_child(_upright)
	var m := CozyMesh.new()
	var oak := Color(0.55, 0.41, 0.28)
	var cog := Color(0.72, 0.58, 0.4)
	m.cyl(0.13, 0.13, WALLOWER_Y - PLINTH - 0.3, 8, CozyMesh.at(Vector3(0, (WALLOWER_Y + PLINTH + 0.3) * 0.5, 0)), oak)
	m.cyl(WALLOWER_R - 0.08, WALLOWER_R - 0.08, 0.18, 20, CozyMesh.at(Vector3(0, WALLOWER_Y, 0)), oak.darkened(0.1))
	_cogs(m, WALLOWER_COGS, WALLOWER_R - 0.04, Vector3(0.06, 0.16, 0.12), CozyMesh.at(Vector3(0, WALLOWER_Y, 0)), cog)
	_ring(m, SPUR_R - 0.16, SPUR_R - 0.04, -0.09, 0.09, CozyMesh.at(Vector3(0, SPUR_Y, 0)), oak.darkened(0.1), 32)
	for k in 2:
		m.box(Vector3(0.12, 0.14, SPUR_R * 2.0 - 0.1), CozyMesh.at(Vector3(0, SPUR_Y, 0), Basis(Vector3.UP, PI * 0.5 * k)), oak)
	_cogs(m, SPUR_COGS, SPUR_R, Vector3(0.05, 0.14, 0.1), CozyMesh.at(Vector3(0, SPUR_Y, 0)), cog)
	_view(_upright, "Gears", m.commit(mats["in"]))
	# The upright shaft's footstep, its bearing in the dust floor, and the
	# bridge beam under the bin floor carrying the spindle's top.
	var still := CozyMesh.new()
	still.box(Vector3(0.5, 0.3, 0.5), CozyMesh.at(Vector3(0, PLINTH + 0.15, 0)), Color(0.55, 0.53, 0.5))
	still.box(Vector3(0.42, 0.08, 0.42), CozyMesh.at(Vector3(0, float(FLOORS[2]) + 0.04, 0)), Color(0.42, 0.32, 0.24))
	var ri := inner_at(FLOORS[0])
	var reach := sqrt(ri * ri - SPINDLE.x * SPINDLE.x)
	still.box(Vector3(0.14, 0.16, reach * 2.0), CozyMesh.at(Vector3(SPINDLE.x, float(FLOORS[0]) - 0.31, 0)), Color(0.5, 0.37, 0.26))
	still.box(Vector3(0.3, 0.12, 0.3), CozyMesh.at(SPINDLE + Vector3(0, PLINTH + 0.06, 0)), Color(0.55, 0.53, 0.5))
	_view(self, "DriveFrame", still.commit(mats["in"]))
	var rope := CozyMesh.new()
	rope.rod(Vector3(ROPE.x, PLINTH + 0.95, ROPE.z), Vector3(ROPE.x, TOP + 0.35, ROPE.z), 0.015, 4, Color(0.7, 0.62, 0.48))
	rope.cyl(0.07, 0.07, 0.05, 10, CozyMesh.at(Vector3(ROPE.x, TOP + 0.38, ROPE.z), Basis(Vector3.FORWARD, PI * 0.5)), Color(0.3, 0.3, 0.3))
	_view(self, "BrakeRope", rope.commit(mats["in_plain"]))
	_spindle = Node3D.new()
	_spindle.name = "Spindle"
	_spindle.position = SPINDLE
	_spindle.set_meta(StaticMerge.MOVES, true)
	add_child(_spindle)
	var s := CozyMesh.new()
	var iron := Color(0.3, 0.3, 0.31)
	var spindle_top := float(FLOORS[0]) - 0.4
	s.cyl(0.04, 0.04, spindle_top - PLINTH - 0.1, 8, CozyMesh.at(Vector3(0, (spindle_top + PLINTH + 0.1) * 0.5, 0)), iron)
	s.cyl(PULLEY_R, PULLEY_R, 0.14, 24, CozyMesh.at(Vector3(0, PULLEY_Y, 0)), Color(0.5, 0.37, 0.26))
	s.cyl(0.08, 0.08, 0.16, 10, CozyMesh.at(Vector3(0, PULLEY_Y, 0)), iron)
	for k in 4:
		s.box(Vector3(PULLEY_R * 2.0 - 0.02, 0.02, 0.05), CozyMesh.at(Vector3(0, PULLEY_Y + 0.075, 0), Basis(Vector3.UP, PI * 0.25 * k)), iron)
	_view(_spindle, "Pulley", s.commit(mats["in"]))
	_pinion = Node3D.new()
	_pinion.position.y = SPUR_Y
	_spindle.add_child(_pinion)
	var p := CozyMesh.new()
	p.cyl(PINION_R - 0.05, PINION_R - 0.05, 0.14, 14, Transform3D.IDENTITY, iron)
	_cogs(p, PINION_COGS, PINION_R - 0.02, Vector3(0.05, 0.12, 0.08), Transform3D.IDENTITY, iron.lightened(0.2))
	_view(_pinion, "Pinion", p.commit(mats["in"]))
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.55, 0.4, 0.27)
	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.22, 0.22, 0.22)
	gear_lever = WorksHandle.new(WorksHandle.Kind.LEVER, Vector3(1.85, PLINTH + 0.55, 0.35), wood_mat, iron_mat,
			"Gear\nE drops the pinion out of the great spur wheel, or raises it back in.")
	add_child(gear_lever)
	brake_lever = WorksHandle.new(WorksHandle.Kind.LEVER, Vector3(ROPE.x + 0.1, PLINTH + 0.55, ROPE.z + 0.15), wood_mat, iron_mat,
			"Brake\nE draws the brake round the brake wheel, or lets it off.")
	add_child(brake_lever)
	brake_lever.on = false
	brake_lever.call("_show")
