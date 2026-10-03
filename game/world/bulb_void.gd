extends Node3D
## A round gray floor in a black void lit by one bare bulb, drawn with Godot's
## default shading: no sky, no ambient light, no post-processing. A
## wall twice a person's height rings it, open in one doorway; a
## player who walks out and off the edge is put back at the start. One switch
## on screen, also on the 1 key, turns the viewport's debanding (a
## dither added before the 8-bit output) on and off.

const START := Vector3(0, 0, 3)

@onready var player: Player = $Player

var _dither: CheckButton


func _ready() -> void:
	player.global_position = START
	var layer := CanvasLayer.new()
	add_child(layer)
	_dither = CheckButton.new()
	_dither.text = "Dithering (1)"
	_dither.focus_mode = Control.FOCUS_NONE
	_dither.position = Vector2(16, 16)
	_dither.button_pressed = get_viewport().use_debanding
	_dither.toggled.connect(func(on: bool) -> void: get_viewport().use_debanding = on)
	layer.add_child(_dither)
	if DisplayServer.get_name() == "headless":
		print("[worldbuilder] bulb void: floor, one bulb")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_1:
		_dither.button_pressed = not _dither.button_pressed


func _physics_process(_delta: float) -> void:
	if player.global_position.y < -30.0:
		player.global_position = START
		player.velocity = Vector3.ZERO
