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
## Then, used with the mouse freed by Esc, the ball's material and
## shape: a colour picker for its hue, sliders for albedo, roughness,
## metallic, specular and the sphere mesh's segment count (rings half
## of it), and a button that puts every control back as the scene
## opened.
##
## The ball's colour is held as a linear tint, its brightest channel 1,
## times the albedo slider, so the slider reads as the reflectance of
## the brightest channel; for a gray that is the reflectance itself.
## The material stores colour in sRGB and the shader converts it.

const START := Vector3(0, 0, 3)
const ATLAS_SIZES: Array[int] = [4096, 8192, 16384]

@onready var player: Player = $Player
@onready var _ball_mesh: SphereMesh = ($Ball/Mesh as MeshInstance3D).mesh as SphereMesh
@onready var _ball_mat: StandardMaterial3D = _ball_mesh.material as StandardMaterial3D

var _dither: CheckButton
var _atlas: Button
var _picker: ColorPickerButton
var _sliders: Dictionary = {}          # title -> HSlider
var _debanding_was := false
var _atlas_was := 4096
var _tint := Color(1, 1, 1)            # linear, brightest channel 1
var _albedo := 0.0                     # linear reflectance of the brightest channel
var _defaults: Dictionary = {}         # what reset puts back


func _ready() -> void:
	player.global_position = START
	var vp := get_viewport()
	_debanding_was = vp.use_debanding
	_atlas_was = vp.positional_shadow_atlas_size
	_set_colour(_ball_mat.albedo_color)
	_defaults = {
		"colour": _ball_mat.albedo_color,
		"Albedo": _albedo,
		"Roughness": _ball_mat.roughness,
		"Metallic": _ball_mat.metallic,
		"Specular": _ball_mat.metallic_specular,
		"Segments": float(_ball_mesh.radial_segments),
	}

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

	var colour_row := HBoxContainer.new()
	var colour_label := Label.new()
	colour_label.text = "Colour"
	colour_row.add_child(colour_label)
	_picker = ColorPickerButton.new()
	_picker.focus_mode = Control.FOCUS_NONE
	_picker.edit_alpha = false
	_picker.custom_minimum_size = Vector2(60, 24)
	_picker.color = _ball_mat.albedo_color
	_picker.color_changed.connect(func(c: Color) -> void:
		_set_colour(c)
		_apply_colour()
		(_sliders["Albedo"] as HSlider).set_value_no_signal(_albedo)
		_show_slider("Albedo", _albedo))
	colour_row.add_child(_picker)
	column.add_child(colour_row)

	_slider(column, "Albedo", 0.0, 1.0, 0.01, _albedo, func(v: float) -> void:
		_albedo = v
		_apply_colour()
		_picker.color = _ball_mat.albedo_color)
	_slider(column, "Roughness", 0.0, 1.0, 0.01, _ball_mat.roughness, func(v: float) -> void:
		_ball_mat.roughness = v)
	_slider(column, "Metallic", 0.0, 1.0, 0.01, _ball_mat.metallic, func(v: float) -> void:
		_ball_mat.metallic = v)
	_slider(column, "Specular", 0.0, 1.0, 0.01, _ball_mat.metallic_specular, func(v: float) -> void:
		_ball_mat.metallic_specular = v)
	_slider(column, "Segments", 8.0, 128.0, 2.0, float(_ball_mesh.radial_segments), func(v: float) -> void:
		_ball_mesh.radial_segments = int(v)
		_ball_mesh.rings = int(v) / 2)

	var reset := Button.new()
	reset.text = "Reset all"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(_reset)
	column.add_child(reset)
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


## Split an sRGB colour into a linear tint (brightest channel 1) and
## the brightest channel's reflectance.
func _set_colour(srgb: Color) -> void:
	var lin := srgb.srgb_to_linear()
	_albedo = maxf(lin.r, maxf(lin.g, lin.b))
	_tint = Color(1, 1, 1) if _albedo <= 0.0 else Color(lin.r / _albedo, lin.g / _albedo, lin.b / _albedo)


func _apply_colour() -> void:
	_ball_mat.albedo_color = Color(_tint.r * _albedo, _tint.g * _albedo, _tint.b * _albedo).linear_to_srgb()


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
	slider.set_meta("label", label)
	slider.set_meta("step", step)
	_sliders[title] = slider
	slider.value_changed.connect(func(v: float) -> void:
		_show_slider(title, v)
		on_change.call(v))
	_show_slider(title, value)
	column.add_child(slider)


func _show_slider(title: String, v: float) -> void:
	var slider := _sliders[title] as HSlider
	var label := slider.get_meta("label") as Label
	var whole: bool = float(slider.get_meta("step")) >= 1.0
	label.text = "%s: %s" % [title, str(int(v)) if whole else "%.2f" % v]


## Every control back as the scene opened.
func _reset() -> void:
	_dither.button_pressed = _debanding_was
	get_viewport().positional_shadow_atlas_size = _atlas_was
	_show_atlas()
	_set_colour(_defaults["colour"] as Color)
	_apply_colour()
	_picker.color = _ball_mat.albedo_color
	for title: String in ["Albedo", "Roughness", "Metallic", "Specular", "Segments"]:
		(_sliders[title] as HSlider).value = float(_defaults[title])


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
