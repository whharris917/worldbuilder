class_name WorksHandle
extends StaticBody3D
## Something at the salt works a player works by hand, looking at it:
## a LEVER, thrown over with E, or a CRANK, turned while E is held. The
## body's `view` meta names this node, as the player's interact ray
## expects; looking at it shows what it does (a hover label).

enum Kind { LEVER, CRANK }

signal thrown(on: bool)

var kind: Kind
var on := true                          # a lever's
var turning := false                    # a crank's: E held on it this step
var _arm: Node3D
var _label: Label3D
var _angle := 0.0


## `title` and `text` are what a player looking at it reads (drafts).
func _init(handle_kind: Kind, at: Vector3, wood: Material, iron: Material, text: String) -> void:
	kind = handle_kind
	name = "Lever" if kind == Kind.LEVER else "Crank"
	position = at
	set_meta("view", self)
	set_meta(StaticMerge.MOVES, true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.6, 0.6)
	shape.shape = box
	add_child(shape)
	_arm = Node3D.new()
	add_child(_arm)
	if kind == Kind.LEVER:
		var base := BoxMesh.new()
		base.size = Vector3(0.4, 0.25, 0.3)
		base.material = iron
		_mesh(base, Vector3(0, -0.4, 0), self)
		var rod := CylinderMesh.new()
		rod.top_radius = 0.025
		rod.bottom_radius = 0.03
		rod.height = 0.7
		rod.material = iron
		_mesh(rod, Vector3(0, 0.35, 0), _arm)
		var knob := SphereMesh.new()
		knob.radius = 0.06
		knob.height = 0.12
		knob.material = wood
		_mesh(knob, Vector3(0, 0.72, 0), _arm)
		_arm.position.y = -0.3
	else:
		var wheel := CylinderMesh.new()
		wheel.top_radius = 0.28
		wheel.bottom_radius = 0.28
		wheel.height = 0.05
		wheel.radial_segments = 16
		wheel.material = iron
		_mesh(wheel, Vector3.ZERO, _arm).rotation.z = PI * 0.5
		var handle := CylinderMesh.new()
		handle.top_radius = 0.03
		handle.bottom_radius = 0.03
		handle.height = 0.25
		handle.material = wood
		_mesh(handle, Vector3(0.15, 0.22, 0), _arm).rotation.z = PI * 0.5
	_label = Label3D.new()
	_label.text = text
	_label.font_size = 26
	_label.pixel_size = 0.0022
	_label.outline_size = 8
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position.y = 0.7
	_label.width = 520.0
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.visible = false
	add_child(_label)
	_show()


func _mesh(mesh: Mesh, at: Vector3, parent: Node3D) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	parent.add_child(view)
	return view


func show_label(on_screen: bool) -> void:
	_label.visible = on_screen


## E on a lever throws it over.
func use() -> void:
	if kind == Kind.LEVER:
		on = not on
		_show()
		thrown.emit(on)


## A crank's wheel turned by `amount` radians.
func turn(amount: float) -> void:
	_angle += amount
	_arm.rotation.x = _angle


func _show() -> void:
	if kind == Kind.LEVER:
		_arm.rotation.x = -0.6 if on else 0.6
