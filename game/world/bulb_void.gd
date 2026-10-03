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
## Then, used with the mouse freed by Esc: a colour picker for the bulb,
## which sets both the light's colour and the glass's emission (the
## light is invisible; the glass is drawn and lights nothing); the ball's material and
## shape: a colour picker for its hue, sliders for albedo, roughness,
## metallic, specular and the sphere mesh's segment count (rings half
## of it), and a button that puts every control back as the scene
## opened.
##
## A second column, top right, for indirect light: ambient light (a
## colour and an energy, 0 as the scene opens), switches for SSAO, SSIL,
## SDFGI and a VoxelGI box around the room (baked each time it is
## switched on, so it sees the ball as it is then), and the bulb's
## indirect energy, its share in the GI methods.
##
## Below them, a sky: a switch that puts Godot's procedural sky (a
## gradient, no sun) behind the scene in place of the black void, and
## makes it the source of the ambient light and of reflections; then
## its four colours and its curves and energies. Ambient energy still
## scales the sky's ambient light; the ambient colour is unused while
## the sky is on.
##
## The bulb's glass takes no part in GI (it encloses the light, and a
## voxel or distance-field method would count it solid and smother the
## light), and the player's body is dynamic, so the methods that bake
## the room do not bake the body where it stood.
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
@onready var _bulb: OmniLight3D = $Bulb
@onready var _env: Environment = ($WorldEnvironment as WorldEnvironment).environment
@onready var _glass_mat: StandardMaterial3D = (($Bulb/Glass as MeshInstance3D).mesh as PrimitiveMesh).material as StandardMaterial3D

var _dither: CheckButton
var _atlas: Button
var _picker: ColorPickerButton
var _bulb_picker: ColorPickerButton
var _sliders: Dictionary = {}          # title -> HSlider
var _switches: Dictionary = {}         # title -> CheckButton
var _ambient_picker: ColorPickerButton
var _voxel_gi: VoxelGI = null
var _sky_mat: ProceduralSkyMaterial
var _sky_pickers: Dictionary = {}      # material property -> ColorPickerButton
var _debanding_was := false
var _atlas_was := 4096
var _tint := Color(1, 1, 1)            # linear, brightest channel 1
var _albedo := 0.0                     # linear reflectance of the brightest channel
var _defaults: Dictionary = {}         # what reset puts back


func _ready() -> void:
	player.global_position = START
	for node in player.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	var vp := get_viewport()
	_debanding_was = vp.use_debanding
	_atlas_was = vp.positional_shadow_atlas_size
	_set_colour(_ball_mat.albedo_color)
	_defaults = {
		"bulb": _bulb.light_color,
		"colour": _ball_mat.albedo_color,
		"Albedo": _albedo,
		"Roughness": _ball_mat.roughness,
		"Metallic": _ball_mat.metallic,
		"Specular": _ball_mat.metallic_specular,
		"Segments": float(_ball_mesh.radial_segments),
		"ambient": Color(1, 1, 1),
		"Ambient energy": 0.0,
		"Indirect energy": _bulb.light_indirect_energy,
	}
	_sky_mat = _env.sky.sky_material as ProceduralSkyMaterial
	for prop: String in ["sky_top_color", "sky_horizon_color", "ground_bottom_color", "ground_horizon_color",
			"sky_curve", "ground_curve", "sky_energy_multiplier", "ground_energy_multiplier"]:
		_defaults[prop] = _sky_mat.get(prop)
	# Ambient light from a colour; at energy 0 it is the same as none.
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = _defaults["ambient"] as Color
	_env.ambient_light_energy = 0.0

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

	_bulb_picker = _colour_row(column, "Bulb colour", _bulb.light_color)
	_bulb_picker.color_changed.connect(_set_bulb)
	_picker = _colour_row(column, "Ball colour", _ball_mat.albedo_color)
	_picker.color_changed.connect(func(c: Color) -> void:
		_set_colour(c)
		_apply_colour()
		(_sliders["Albedo"] as HSlider).set_value_no_signal(_albedo)
		_show_slider("Albedo", _albedo))

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

	var right := VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -276.0
	right.offset_right = -16.0
	right.offset_top = 16.0
	layer.add_child(right)
	var heading := Label.new()
	heading.text = "Indirect light"
	right.add_child(heading)
	_ambient_picker = _colour_row(right, "Ambient colour", _env.ambient_light_color)
	_ambient_picker.color_changed.connect(func(c: Color) -> void: _env.ambient_light_color = c)
	_slider(right, "Ambient energy", 0.0, 2.0, 0.01, 0.0, func(v: float) -> void:
		_env.ambient_light_energy = v)
	_switch(right, "SSAO", func(on: bool) -> void: _env.ssao_enabled = on)
	_switch(right, "SSIL", func(on: bool) -> void: _env.ssil_enabled = on)
	_switch(right, "SDFGI", func(on: bool) -> void: _env.sdfgi_enabled = on)
	_switch(right, "VoxelGI", _set_voxel_gi)
	_slider(right, "Indirect energy", 0.0, 4.0, 0.01, _bulb.light_indirect_energy, func(v: float) -> void:
		_bulb.light_indirect_energy = v)

	var sky_heading := Label.new()
	sky_heading.text = "Sky"
	right.add_child(sky_heading)
	_switch(right, "Sky", _set_sky)
	_sky_colour(right, "Sky top", "sky_top_color")
	_sky_colour(right, "Sky horizon", "sky_horizon_color")
	_sky_colour(right, "Ground horizon", "ground_horizon_color")
	_sky_colour(right, "Ground bottom", "ground_bottom_color")
	_sky_slider(right, "Sky curve", "sky_curve", 0.001, 1.0)
	_sky_slider(right, "Sky energy", "sky_energy_multiplier", 0.0, 4.0)
	_sky_slider(right, "Ground curve", "ground_curve", 0.001, 1.0)
	_sky_slider(right, "Ground energy", "ground_energy_multiplier", 0.0, 4.0)
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


## A label and a colour swatch that opens a picker.
func _colour_row(column: VBoxContainer, title: String, colour: Color) -> ColorPickerButton:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	row.add_child(label)
	var picker := ColorPickerButton.new()
	picker.focus_mode = Control.FOCUS_NONE
	picker.edit_alpha = false
	picker.custom_minimum_size = Vector2(60, 24)
	picker.color = colour
	row.add_child(picker)
	column.add_child(row)
	return picker


## A switch, off as the scene opens.
func _switch(column: VBoxContainer, title: String, on_toggle: Callable) -> void:
	var button := CheckButton.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.toggled.connect(func(on: bool) -> void: on_toggle.call(on))
	_switches[title] = button
	column.add_child(button)


## The sky behind the scene and as the source of ambient light and
## reflections, or the black void with ambient light from a colour and
## no reflections.
func _set_sky(on: bool) -> void:
	if on:
		_env.background_mode = Environment.BG_SKY
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	else:
		_env.background_mode = Environment.BG_COLOR
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED


func _sky_colour(column: VBoxContainer, title: String, prop: String) -> void:
	var picker := _colour_row(column, title, _sky_mat.get(prop) as Color)
	picker.color_changed.connect(func(c: Color) -> void: _sky_mat.set(prop, c))
	_sky_pickers[prop] = picker


func _sky_slider(column: VBoxContainer, title: String, prop: String, lo: float, hi: float) -> void:
	_slider(column, title, lo, hi, 0.001 if hi <= 1.0 else 0.01, float(_sky_mat.get(prop)),
		func(v: float) -> void: _sky_mat.set(prop, v))
	(_sliders[title] as HSlider).set_meta("prop", prop)


## A VoxelGI box just larger than the room, baked from the scene as it
## is now each time it is switched on.
func _set_voxel_gi(on: bool) -> void:
	if not on:
		if _voxel_gi != null:
			_voxel_gi.queue_free()
			_voxel_gi = null
		return
	_voxel_gi = VoxelGI.new()
	_voxel_gi.size = Vector3(32, 6, 32)
	_voxel_gi.position = Vector3(0, 2.8, 0)
	add_child(_voxel_gi)
	_voxel_gi.bake()


## The light and the glass that stands for it, in one colour.
func _set_bulb(c: Color) -> void:
	_bulb.light_color = c
	_glass_mat.emission = c


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
	_bulb_picker.color = _defaults["bulb"] as Color
	_set_bulb(_bulb_picker.color)
	_set_colour(_defaults["colour"] as Color)
	_apply_colour()
	_picker.color = _ball_mat.albedo_color
	for title: String in ["Albedo", "Roughness", "Metallic", "Specular", "Segments",
			"Ambient energy", "Indirect energy"]:
		(_sliders[title] as HSlider).value = float(_defaults[title])
	_ambient_picker.color = _defaults["ambient"] as Color
	_env.ambient_light_color = _ambient_picker.color
	for button: CheckButton in _switches.values():
		button.button_pressed = false
	for prop: String in _sky_pickers:
		var picker := _sky_pickers[prop] as ColorPickerButton
		picker.color = _defaults[prop] as Color
		_sky_mat.set(prop, picker.color)
	for slider: HSlider in _sliders.values():
		if slider.has_meta("prop"):
			slider.value = float(_defaults[str(slider.get_meta("prop"))])


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
