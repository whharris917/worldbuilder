class_name WallSwitch
extends StaticBody3D
## A light switch on a wall: a small plate with a toggle that flips up
## for on and down for off. The player uses it with E while looking at
## it (the body's `view` meta names this node, as the player's interact
## ray expects). It reports each flip by `toggled`.

signal toggled(on: bool)

var on := false
var _lever: MeshInstance3D


func _ready() -> void:
	set_meta("view", self)
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.85, 0.83, 0.78)
	plate_mat.roughness = 0.5
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.08, 0.12, 0.01)
	plate.mesh = plate_mesh
	plate.material_override = plate_mat
	add_child(plate)
	var lever_mat := StandardMaterial3D.new()
	lever_mat.albedo_color = Color(0.2, 0.2, 0.2)
	lever_mat.roughness = 0.4
	_lever = MeshInstance3D.new()
	var lever_mesh := BoxMesh.new()
	lever_mesh.size = Vector3(0.012, 0.03, 0.02)
	_lever.mesh = lever_mesh
	_lever.material_override = lever_mat
	add_child(_lever)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.12, 0.16, 0.06)
	shape.shape = box
	add_child(shape)
	_show()


func use() -> void:
	set_on(not on)


## Flips the switch to `value`, reporting it.
func set_on(value: bool) -> void:
	on = value
	_show()
	toggled.emit(on)


func _show() -> void:
	if _lever == null:
		return
	_lever.position = Vector3(0.0, 0.008 if on else -0.008, 0.012)
	_lever.rotation_degrees.x = -25.0 if on else 25.0
