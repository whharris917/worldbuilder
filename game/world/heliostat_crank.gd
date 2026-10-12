class_name HeliostatCrank
extends StaticBody3D
## A crank on the inside of the workshop's wall for the heliostat
## (Heliostat): held with a click or E it turns the mirror round (bearing)
## or tilts it (tilt), Shift held turning it the other way; a wheel on the
## end of its shaft, which runs out through the wall, a handle on its rim,
## turning while held. Its card reads where the mirror faces (the body's
## `view` meta names this node, as the player's interact ray expects).
##
## Its origin on the wall's inner face, the wheel out from it along +z.

var _heliostat: Heliostat
var _which := "bearing"
var _way := 0.0
var _wheel := Node3D.new()


func _init(heliostat: Heliostat, which: String, mat: Material) -> void:
	name = "HeliostatCrank"
	_heliostat = heliostat
	_which = which
	set_meta("view", self)
	# Met by the crosshair, not walked into, out of the light's way.
	collision_layer = 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.45, 0.45, 0.2)
	shape.shape = box
	shape.position = Vector3(0, 0, 0.1)
	add_child(shape)
	# The shaft's end from the wall in an iron bearing plate, the wheel on
	# it turning across it, a handle on its rim.
	var m := CozyMesh.new()
	m.box(Vector3(0.14, 0.14, 0.02), CozyMesh.at(Vector3(0, 0, 0.01)), Color(0.22, 0.21, 0.2))
	m.cyl(0.02, 0.02, 0.1, 6, CozyMesh.at(Vector3(0, 0, 0.05), Basis(Vector3.RIGHT, PI * 0.5)), Color(0.22, 0.21, 0.2))
	var view := MeshInstance3D.new()
	view.mesh = m.commit(mat)
	add_child(view)
	_wheel.position = Vector3(0, 0, 0.1)
	add_child(_wheel)
	var w := CozyMesh.new()
	w.torus(0.15, 0.18, 18, 5, CozyMesh.at(Vector3.ZERO, Basis(Vector3.RIGHT, PI * 0.5)), Color(0.24, 0.23, 0.22))
	for k in 4:
		var a := TAU * k / 4.0
		w.rod(Vector3.ZERO, Vector3(cos(a), sin(a), 0) * 0.16, 0.012, 5, Color(0.24, 0.23, 0.22))
	w.rod(Vector3(0, 0.165, 0), Vector3(0, 0.165, 0.11), 0.02, 6, Color(0.46, 0.33, 0.22))
	var wheel_view := MeshInstance3D.new()
	wheel_view.mesh = w.commit(mat)
	_wheel.add_child(wheel_view)


func use() -> void:
	_way = -1.0 if Input.is_action_pressed("run") else 1.0


func _process(delta: float) -> void:
	if _way == 0.0:
		return
	if not Input.is_action_pressed("interact"):
		_way = 0.0
		return
	_heliostat.crank(_which, _way, delta)
	_wheel.rotate_z(_way * delta * 3.0)


## What a right click on it reads (a draft).
func inspect_text() -> String:
	if _which == "bearing":
		return "Mirror's bearing\nHeld, turns the mirror round; with Shift, the other way. It faces %d degrees from north." % roundi(_heliostat.bearing)
	return "Mirror's tilt\nHeld, tilts the mirror up; with Shift, down. Its face is %d degrees over level." % roundi(_heliostat.tilt)
