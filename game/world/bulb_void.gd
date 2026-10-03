extends Node3D
## A round gray floor in a black void lit by one bare bulb, drawn with Godot's
## default shading: no sky, no ambient light, no post-processing. A
## wall twice a person's height rings it, open in one doorway; a
## player who walks out and off the edge is put back at the start.
##
## Two controls on screen: a switch (1 key) for the viewport's debanding,
## a dither added before the 8-bit output; and a button (2 key) that
## steps the shadow atlas, the texture all point and spot lights' shadow
## maps share, through 4096, 8192 and 16384 texels square. The atlas is
## a power of two. Both are put back as found when the scene closes.

const START := Vector3(0, 0, 3)

@onready var player: Player = $Player

const ATLAS_SIZES: Array[int] = [4096, 8192, 16384]

var _dither: CheckButton
var _atlas: Button
var _debanding_was := false
var _atlas_was := 4096


func _ready() -> void:
	player.global_position = START
	var vp := get_viewport()
	_debanding_was = vp.use_debanding
	_atlas_was = vp.positional_shadow_atlas_size
	var layer := CanvasLayer.new()
	add_child(layer)
	var column := VBoxContainer.new()
	column.position = Vector2(16, 16)
	layer.add_child(column)
	_dither = CheckButton.new()
	_dither.text = "Dithering (1)"
	_dither.focus_mode = Control.FOCUS_NONE
	_dither.button_pressed = vp.use_debanding
	_dither.toggled.connect(func(on: bool) -> void: get_viewport().use_debanding = on)
	column.add_child(_dither)
	_atlas = Button.new()
	_atlas.focus_mode = Control.FOCUS_NONE
	_atlas.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_atlas.pressed.connect(_next_atlas)
	column.add_child(_atlas)
	_show_atlas()
	if DisplayServer.get_name() == "headless":
		print("[worldbuilder] bulb void: floor, one bulb")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_1:
				_dither.button_pressed = not _dither.button_pressed
			KEY_2:
				_next_atlas()


func _next_atlas() -> void:
	var vp := get_viewport()
	var i := ATLAS_SIZES.find(vp.positional_shadow_atlas_size)
	vp.positional_shadow_atlas_size = ATLAS_SIZES[(i + 1) % ATLAS_SIZES.size()]
	_show_atlas()


func _show_atlas() -> void:
	_atlas.text = "Shadow atlas: %d (2)" % get_viewport().positional_shadow_atlas_size


func _exit_tree() -> void:
	var vp := get_viewport()
	vp.use_debanding = _debanding_was
	vp.positional_shadow_atlas_size = _atlas_was


func _physics_process(_delta: float) -> void:
	if player.global_position.y < -30.0:
		player.global_position = START
		player.velocity = Vector3.ZERO
