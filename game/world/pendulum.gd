class_name Pendulum
extends RefCounted
## A weight on a rope from a hook that travels the corners of a polygon
## in turn: it waits at a corner, then runs the edge to the next,
## easing in and out (a minimum-jerk profile, so its acceleration starts
## and ends at zero). The weight swings as a rigid pendulum would. Its
## motion is integrated in the hook's moving frame: gravity less the
## hook's acceleration, the component across the rope scaled by
## L^2 / (L^2 + 2/5 r^2) for a solid ball's own turning (L from hook to
## the weight's centre), the rope held at its length, a little air drag.
## The rope is taut always and the weight turns with it.
##
## Speed and wait may change at any moment: the hook keeps its place
## along the edge and only its pace changes.

const HOOK_Y := 12.0
const GRAVITY := Vector3(0, -9.8, 0)
const DRAG := 0.03                      # 1/s

var corners: Array[Vector3]             # on the floor; the hook runs HOOK_Y above them
var radius: float                       # of the weight, for collisions
var tie: float                          # from the weight's centre to where the rope is tied
var mass: float
var length: float                       # hook to the weight's centre
var speed := 1.0                        # m/s, the mean along an edge
var wait := 3.0                         # s at each corner
var swing: Vector3                      # hook to the weight's centre
var swing_v := Vector3.ZERO             # its rate of change

var _turning: float
var _leg := 0
var _moving := false
var _waited := 0.0
var _tau := 0.0                         # 0 to 1 along the current edge


func _init(p_corners: Array[Vector3], rest_y: float, p_radius: float, p_tie: float, p_mass: float) -> void:
	corners = p_corners
	radius = p_radius
	tie = p_tie
	mass = p_mass
	length = HOOK_Y - rest_y
	_turning = length * length / (length * length + 0.4 * radius * radius)
	swing = Vector3(0, -length, 0)


func hook() -> Vector3:
	var a := corners[_leg]
	if not _moving:
		return a + Vector3(0, HOOK_Y, 0)
	var b := corners[(_leg + 1) % corners.size()]
	var t := _tau
	return a.lerp(b, t * t * t * (10.0 - 15.0 * t + 6.0 * t * t)) + Vector3(0, HOOK_Y, 0)


func hook_velocity() -> Vector3:
	if not _moving:
		return Vector3.ZERO
	var t := _tau
	return _edge() * (30.0 * t * t * (1.0 - t) * (1.0 - t)) / _move_time()


func hook_acceleration() -> Vector3:
	if not _moving:
		return Vector3.ZERO
	var t := _tau
	var T := _move_time()
	return _edge() * (60.0 * t - 180.0 * t * t + 120.0 * t * t * t) / (T * T)


func centre() -> Vector3:
	return hook() + swing


func velocity() -> Vector3:
	return hook_velocity() + swing_v


## Where the rope meets the weight.
func rope_end() -> Vector3:
	return centre() - swing.normalized() * tie


func step(dt: float) -> void:
	var along := swing.normalized()
	var force := GRAVITY - hook_acceleration()
	var across := force - along * force.dot(along)
	swing_v += (across * _turning - swing_v * DRAG) * dt
	swing = (swing + swing_v * dt).normalized() * length
	along = swing.normalized()
	swing_v -= along * swing_v.dot(along)
	if _moving:
		_tau += dt / _move_time()
		if _tau >= 1.0:
			_tau = 0.0
			_moving = false
			_waited = 0.0
			_leg = (_leg + 1) % corners.size()
	else:
		_waited += dt
		if _waited >= wait:
			_moving = true
			_tau = 0.0


## A change in the weight's velocity, as from a knock; the rope takes
## the part along it.
func push(dv: Vector3) -> void:
	var along := swing.normalized()
	swing_v += dv - along * dv.dot(along)


## Move the weight toward a point, keeping it on its rope.
func place(at: Vector3) -> void:
	swing = (at - hook()).normalized() * length


func _edge() -> Vector3:
	return corners[(_leg + 1) % corners.size()] - corners[_leg]


func _move_time() -> float:
	return _edge().length() / maxf(speed, 0.01)
