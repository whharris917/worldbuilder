class_name CurtainCord
extends StaticBody3D
## A curtain's cord drum on the stand by the burning glass's table
## (BurningGlass): a small wooden drum on an axle across, the curtain's
## cord coming down onto it from its pulley at the lens; a click (or E)
## winds the cord in or lets it out and draws the curtain across its strip
## of the lens or back (the body's `view` meta names this node, as the
## player's interact ray expects). The drum turns as the curtain moves, a
## handle on its cheek showing it.
##
## Its origin is the drum's axle, the axle along x.

const DRUM_R := 0.045                   # m: the drum, the cord wound on it

var _glass: BurningGlass
var _index := 0
var _drum := Node3D.new()


func _init(glass: BurningGlass, index: int, wood: Material) -> void:
	name = "CurtainCord"
	_glass = glass
	_index = index
	set_meta("view", self)
	# Met by the player's crosshair, not walked into, out of the light's way.
	collision_layer = 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 0.2, 0.2)
	shape.shape = box
	add_child(shape)
	add_child(_drum)
	var m := CozyMesh.new()
	var oak := Color(0.5, 0.36, 0.22)
	var turn := Basis(Vector3.BACK, PI * 0.5)
	m.cyl(DRUM_R, DRUM_R, 0.1, 12, CozyMesh.at(Vector3.ZERO, turn), oak)
	m.cyl(DRUM_R * 0.7, DRUM_R * 0.7, 0.1, 12, CozyMesh.at(Vector3.ZERO, turn), Color(0.72, 0.62, 0.44))
	for side: float in [-1.0, 1.0]:
		m.cyl(0.075, 0.075, 0.015, 14, CozyMesh.at(Vector3(side * 0.055, 0, 0), turn), oak.darkened(0.2))
	m.rod(Vector3(0.065, 0.055, 0), Vector3(0.13, 0.055, 0), 0.012, 6, Color(0.36, 0.25, 0.16))
	var view := MeshInstance3D.new()
	view.mesh = m.commit(wood)
	_drum.add_child(view)


func use() -> void:
	_glass.pull(_index)


## The drum turned as the curtain is drawn `share` of the way across:
## the curtain's travel wound on or off it.
func set_drawn(share: float) -> void:
	_drum.rotation.x = share * BurningGlass.OPENING / DRUM_R


## What a right click on it reads (a draft).
func inspect_text() -> String:
	return "Curtain cord\nA click winds its curtain across the burning glass, or lets it back."
