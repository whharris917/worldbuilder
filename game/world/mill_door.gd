class_name MillDoor
extends StaticBody3D
## A boarded door on a hinge, opened and shut with E while looking at it
## (the body's `view` meta names this node, as the player's interact ray
## expects). The hinge is this node's origin; the leaf runs along +x and
## swings toward -z, taking a second over it.

const OPEN := 1.75                      # radians, swung open

var open := false
var _angle := 0.0
var _label: Label3D


## A leaf `width` by `height`, its boards in `colour`, drawn in `mat`.
func _init(width: float, height: float, colour: Color, mat: Material, text: String) -> void:
	name = "Door"
	set_meta("view", self)
	var m := CozyMesh.new()
	m.box(Vector3(width, height, 0.06), CozyMesh.at(Vector3(width * 0.5, height * 0.5, 0)), colour)
	# Ledges across the back and the boards' joints down the front.
	for y: float in [0.25, height * 0.5, height - 0.25]:
		m.box(Vector3(width - 0.1, 0.14, 0.04), CozyMesh.at(Vector3(width * 0.5, y, -0.05)), colour.darkened(0.15))
	for k in range(1, 5):
		m.box(Vector3(0.015, height - 0.02, 0.01), CozyMesh.at(Vector3(width * k / 5.0, height * 0.5, 0.033)), colour.darkened(0.3))
	m.ball(0.035, 8, CozyMesh.at(Vector3(width - 0.12, height * 0.5, 0.06)), Color(0.75, 0.62, 0.3))
	for y: float in [0.25, height - 0.25]:
		m.box(Vector3(width * 0.5, 0.04, 0.01), CozyMesh.at(Vector3(width * 0.25, y, 0.035)), Color(0.2, 0.2, 0.2))
	var view := MeshInstance3D.new()
	view.mesh = m.commit(mat)
	add_child(view)
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.08)
	var c := CollisionShape3D.new()
	c.shape = shape
	c.position = Vector3(width * 0.5, height * 0.5, 0)
	add_child(c)
	_label = Label3D.new()
	_label.text = text
	_label.font_size = 26
	_label.pixel_size = 0.0022
	_label.outline_size = 8
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = Vector3(width * 0.5, height * 0.6, 0.2)
	_label.visible = false
	add_child(_label)


## What a right click on it reads: its name, then what it does.
func inspect_text() -> String:
	return _label.text


func use() -> void:
	open = not open


## Set at once, without swinging.
func set_open(on: bool) -> void:
	open = on
	_angle = OPEN if on else 0.0
	rotation.y = _angle


func _physics_process(delta: float) -> void:
	_angle = move_toward(_angle, OPEN if open else 0.0, delta * 1.8)
	rotation.y = _angle
