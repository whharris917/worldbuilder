extends Node3D
## A gray floor in a black void lit by one bare bulb, drawn with Godot's
## default shading: no sky, no ambient light, no post-processing. A
## player who walks off the edge is put back at the start.

const START := Vector3(0, 0, 3)

@onready var player: Player = $Player


func _ready() -> void:
	player.global_position = START
	if DisplayServer.get_name() == "headless":
		print("[worldbuilder] bulb void: floor, one bulb")


func _physics_process(_delta: float) -> void:
	if player.global_position.y < -30.0:
		player.global_position = START
		player.velocity = Vector3.ZERO
