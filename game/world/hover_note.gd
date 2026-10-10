class_name HoverNote
extends StaticBody3D
## An invisible solid over a machine that tells a player looking at it
## what the machine is: a box the player bumps into and the interact ray
## meets (its `view` meta names itself), whose text a right click on it
## reads (`inspect_text`, shown by the Workshop's card).

var _label: Label3D


## A box `size` at `at` (in its parent's frame), with `text` (a draft)
## floating `lift` above its centre.
func _init(at: Vector3, size: Vector3, text: String, lift := 0.0) -> void:
	name = "Note"
	position = at
	set_meta("view", self)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	_label = Label3D.new()
	_label.text = text
	_label.font_size = 26
	_label.pixel_size = 0.0022
	_label.outline_size = 8
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position.y = lift if lift > 0.0 else size.y * 0.5 + 0.3
	_label.width = 560.0
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.visible = false
	add_child(_label)


## What a right click on it reads: its name, then what it does.
func inspect_text() -> String:
	return _label.text


## Its label made to read `text`, for a note that tells a machine's state.
func set_text(text: String) -> void:
	_label.text = text
