extends Node3D
## A round gray floor in a black void lit by one bare bulb, drawn with Godot's
## default shading: no sky, no ambient light, no post-processing. A
## wall twice a person's height rings it, open in one doorway; a
## player who walks out and off the edge is put back at the start.
##
## Controls on screen: a switch (1 key) for the viewport's debanding,
## a dither added before the 8-bit output; a button (2 key) that steps
## the shadow atlas, the texture all point and spot lights' shadow maps
## share, through 4096, 8192 and 16384 texels square (the atlas is a
## power of two); both are put back as found when the scene closes.
## Then sliders for the ball's material and shape, used with the mouse
## freed by Esc: albedo as linear reflectance (the material's colour is
## stored in sRGB and converted), roughness, metallic, specular, and the
## sphere mesh's segment count (rings half of it).

const START := Vector3(0, 0, 3)

@onready var player: Player = $Player

const ATLAS_SIZES: Array[int] = [4096, 8192, 16384]

var _dither: CheckButton
@onready var _ball_mesh: SphereMesh = ($Ball/Mesh as MeshInstance3D).mesh as SphereMesh
@onready var _ball_mat: StandardMaterial3D = _ball_mesh.material as StandardMaterial3D
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
	var albedo := _ball_mat.albedo_color.srgb_to_linear().r
	_slider(column, "Albedo", 0.0, 1.0, 0.01, albedo, func(v: float) -> void:
		_ball_mat.albedo_color = Color(v, v, v).linear_to_srgb())
	_slider(column, "Roughness", 0.0, 1.0, 0.01, _ball_mat.roughness, func(v: float) -> void:
		_ball_mat.roughness = v)
	_slider(column, "Metallic", 0.0, 1.0, 0.01, _ball_mat.metallic, func(v: float) -> void:
		_ball_mat.metallic = v)
	_slider(column, "Specular", 0.0, 1.0, 0.01, _ball_mat.metallic_specular, func(v: float) -> void:
		_ball_mat.metallic_specular = v)
	_slider(column, "Segments", 8.0, 128.0, 2.0, float(_ball_mesh.radial_segments), func(v: float) -> void:
		_ball_mesh.radial_segments = int(v)
		_ball_mesh.rings = int(v) / 2)
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


## A labelled slider; the label shows the value as it moves.
func _slider(column: VBoxContainer, title: String, lo: float, hi: float, step: float,
		value: float, on_change: Callable) -> void:
	var label := Label.new()
	column.add_child(label)
	var slider := HSlider.new()
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size = Vector2(240, 0)
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = value
	var show := func(v: float) -> void:
		label.text = "%s: %s" % [title, str(int(v)) if step >= 1.0 else "%.2f" % v]
	slider.value_changed.connect(func(v: float) -> void:
		show.call(v)
		on_change.call(v))
	show.call(value)
	column.add_child(slider)


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
