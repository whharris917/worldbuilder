class_name BulbRadio
extends Node3D
## A radio playing the director's recording "Levittown Levity", sitting
## on the one-bulb room's swinging ball. It is a source like any other:
## how its sound reaches the ear is the scene's acoustics (BulbAcoustics).

var _dial: StandardMaterial3D

## Whether it plays: the dial lights while it does.
var playing := true:
	set(on):
		playing = on
		if _dial != null:
			_dial.emission_energy_multiplier = 0.6 if on else 0.0


func _init() -> void:
	name = "Radio"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.17, 0.08)
	wood.roughness = 0.45
	_box(Vector3(0.36, 0.24, 0.17), Vector3.ZERO, wood)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.55, 0.47, 0.33)
	cloth.roughness = 1.0
	_box(Vector3(0.20, 0.15, 0.01), Vector3(-0.06, 0.0, -0.088), cloth)
	_dial = StandardMaterial3D.new()
	_dial.albedo_color = Color(0.9, 0.8, 0.55)
	_dial.emission_enabled = true
	_dial.emission = Color(1.0, 0.7, 0.35)
	_dial.emission_energy_multiplier = 0.6
	_box(Vector3(0.08, 0.05, 0.01), Vector3(0.11, 0.03, -0.088), _dial)


## The recording, looping.
static func song() -> AudioStream:
	var stream := load("res://audio/levittown_levity.mp3") as AudioStreamMP3
	stream.loop = true
	return stream


func _box(size: Vector3, at: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	add_child(node)
