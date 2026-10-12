class_name CurtainCord
extends StaticBody3D
## The toggle on a burning glass's curtain cord (BurningGlass): a wooden
## toggle on the cord hanging from the curtain's pulley, a click (or E)
## pulls it and draws the curtain across its strip of the lens or back
## (the body's `view` meta names this node, as the player's interact
## ray expects). It rides up the cord as the curtain is drawn back and
## down as it is drawn across.
##
## Its origin is the pulley; `down` is straight down in its parent's
## frame.

var _glass: BurningGlass
var _index := 0
var _down := Vector3.DOWN
var _hang := 3.0                        # m: the cord's length from the pulley to its loop
var _toggle: Node3D
var _solid: CollisionShape3D
var _wood: Material


func _init(glass: BurningGlass, index: int, down: Vector3, wood: Material) -> void:
	name = "CurtainCord"
	_glass = glass
	_index = index
	_down = down.normalized()
	_wood = wood
	set_meta("view", self)


## The cord `length` long below the pulley.
func hang(length: float) -> void:
	_hang = length
	_toggle = Node3D.new()
	add_child(_toggle)
	var m := CozyMesh.new()
	m.cyl(0.018, 0.018, 0.13, 8, CozyMesh.at(Vector3.ZERO, CozyMesh.aligned(_down)), Color(0.5, 0.34, 0.2))
	var view := MeshInstance3D.new()
	view.mesh = m.commit(_wood)
	_toggle.add_child(view)
	# The solid a direct child of the body, as the engine needs, moved
	# with the toggle.
	_solid = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.16, 0.3, 0.16)
	_solid.shape = box
	add_child(_solid)
	set_drawn(_glass.drawn[_index])


## The toggle's place for the curtain drawn `share` of the way across.
func set_drawn(share: float) -> void:
	if _toggle == null:
		return
	_toggle.position = _down * (_hang - 0.15 - BurningGlass.OPENING * (1.0 - share))
	_solid.position = _toggle.position


func use() -> void:
	_glass.pull(_index)


## What a right click on it reads (a draft).
func inspect_text() -> String:
	return "Curtain cord\nPulled, it draws its curtain across the burning glass, or back."
