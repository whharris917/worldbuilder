class_name HeliostatCrank
extends StaticBody3D
## A crank at the foot of the heliostat's mast (Heliostat): held with a
## click or E it turns the mirror round (bearing) or tilts it (tilt),
## Shift held turning it the other way; a wheel with a handle on the end
## of its shaft, turning while held. Its card reads where the mirror
## faces (the body's `view` meta names this node, as the player's
## interact ray expects).

var _heliostat: Heliostat
var _which := "bearing"
var _way := 0.0
var _wheel := Node3D.new()


func _init(heliostat: Heliostat, which: String, mat: Material, _shaft: Node3D) -> void:
	name = "HeliostatCrank"
	_heliostat = heliostat
	_which = which
	set_meta("view", self)
	# Met by the crosshair, not walked into, out of the light's way.
	collision_layer = 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.5, 0.5)
	shape.shape = box
	add_child(shape)
	# A short arm out from the mast carrying the wheel's spindle, the
	# wheel turning across it, a handle on its rim.
	var m := CozyMesh.new()
	m.box(Vector3(0.3, 0.05, 0.05), CozyMesh.at(Vector3(-0.15, 0, 0)), Color(0.22, 0.21, 0.2))
	var view := MeshInstance3D.new()
	view.mesh = m.commit(mat)
	add_child(view)
	add_child(_wheel)
	var w := CozyMesh.new()
	w.torus(0.17, 0.2, 18, 5, CozyMesh.at(Vector3.ZERO, Basis(Vector3.BACK, PI * 0.5)), Color(0.24, 0.23, 0.22))
	for k in 4:
		var a := TAU * k / 4.0
		w.rod(Vector3.ZERO, Vector3(0, cos(a), sin(a)) * 0.18, 0.012, 5, Color(0.24, 0.23, 0.22))
	w.rod(Vector3(0, 0.18, 0), Vector3(0.12, 0.18, 0), 0.02, 6, Color(0.46, 0.33, 0.22))
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
	_wheel.rotate_x(_way * delta * 3.0)


## What a right click on it reads (a draft).
func inspect_text() -> String:
	if _which == "bearing":
		return "Mirror's bearing\nHeld, turns the mirror round; with Shift, the other way. It faces %d degrees from north." % roundi(_heliostat.bearing)
	return "Mirror's tilt\nHeld, tilts the mirror up; with Shift, down. Its face is %d degrees over level." % roundi(_heliostat.tilt)
