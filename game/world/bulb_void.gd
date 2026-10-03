extends Node3D
## A round gray floor in a black void lit by one bare bulb, drawn with Godot's
## default shading: no sky, no ambient light, no post-processing. A
## wall twice a person's height rings it, open in one doorway; a
## player who walks out and off the edge is put back at the start.
##
## Controls on screen, used with the mouse freed by Esc. Left: the
## viewport's debanding (1 key), a dither added before the 8-bit output;
## the shadow atlas (2 key), the texture all point and spot lights'
## shadow maps share, stepped through 4096, 8192 and 16384 texels square
## (it is a power of two), both put back as found when the scene closes;
## the bulb's colour, which sets the light's colour and the glass's
## emission (the light is invisible; the glass is drawn and lights
## nothing); the ball's colour, albedo, roughness, metallic, specular and
## segment count, each with a note on what it does; Reset all.
##
## Right: indirect light, arranged by how Godot combines it. What lies
## outside the room is one of three: the void (no ambient light, no
## reflections), a constant ambient colour, or the procedural sky (a
## gradient, no sun), which is then the background, the ambient light and
## what glossy surfaces reflect. Ambient energy scales the constant
## colour only; the sky's strength is its own two energies. The bounce
## method is one of none, SDFGI or a VoxelGI box around the room (baked
## each time it is chosen, so it sees the ball as it is then). Both
## replace the ambient term: SDFGI takes light from outside only from
## the background, so it ignores the constant colour; VoxelGI blends the
## ambient colour or sky in where its rays leave its box. SSIL and SSAO
## add to any of these. Controls that have no effect in the current
## combination are dimmed, and a line at the top says where the light on
## the surfaces is coming from.
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
const COLUMN_W := 270.0
const SKY_PROPS: Array[String] = ["sky_top_color", "sky_horizon_color", "ground_horizon_color",
	"ground_bottom_color", "sky_curve", "sky_energy_multiplier", "ground_curve", "ground_energy_multiplier"]

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
var _ambient_picker: ColorPickerButton
var _sliders: Dictionary = {}          # title -> HSlider
var _switches: Dictionary = {}         # title -> CheckButton
var _choices: Dictionary = {}          # group title -> {option -> CheckBox}
var _sky_pickers: Dictionary = {}      # material property -> ColorPickerButton
var _specular_note: Label
var _status: Label
var _colour_box: VBoxContainer
var _sky_box: VBoxContainer
var _bounce_box: VBoxContainer
var _specular_box: VBoxContainer
var _voxel_gi: VoxelGI = null
var _sky_mat: ProceduralSkyMaterial
var _outside := "Void"                 # Void, Colour or Sky
var _bounce := "None"                  # None, SDFGI or VoxelGI
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
	_sky_mat = _env.sky.sky_material as ProceduralSkyMaterial
	_set_colour(_ball_mat.albedo_color)
	_env.ambient_light_color = Color(1, 1, 1)
	_env.ambient_light_energy = 0.3
	_defaults = {
		"bulb": _bulb.light_color,
		"colour": _ball_mat.albedo_color,
		"Albedo": _albedo,
		"Roughness": _ball_mat.roughness,
		"Metallic": _ball_mat.metallic,
		"Specular": _ball_mat.metallic_specular,
		"Segments": float(_ball_mesh.radial_segments),
		"ambient": _env.ambient_light_color,
		"Ambient energy": _env.ambient_light_energy,
		"Indirect energy": _bulb.light_indirect_energy,
	}
	for prop in SKY_PROPS:
		_defaults[prop] = _sky_mat.get(prop)

	var layer := CanvasLayer.new()
	add_child(layer)
	_build_left(layer)
	_build_right(layer)
	_set_outside("Void")
	_set_bounce("None")
	if DisplayServer.get_name() == "headless":
		print("[worldbuilder] bulb void: floor, one bulb")


func _build_left(layer: CanvasLayer) -> void:
	var column := _column(layer)
	(column.get_parent() as Control).position = Vector2(16, 16)
	_dither = CheckButton.new()
	_dither.text = "Dithering (1)"
	_dither.focus_mode = Control.FOCUS_NONE
	_dither.button_pressed = get_viewport().use_debanding
	_dither.toggled.connect(func(on: bool) -> void: get_viewport().use_debanding = on)
	column.add_child(_dither)
	_atlas = Button.new()
	_atlas.focus_mode = Control.FOCUS_NONE
	_atlas.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_atlas.pressed.connect(_next_atlas)
	column.add_child(_atlas)
	_show_atlas()

	_heading(column, "Bulb")
	_bulb_picker = _colour_row(column, ["Colour"], [_bulb.light_color])[0]
	_bulb_picker.color_changed.connect(_set_bulb)
	_note(column, "Colours the light and the glowing glass together.")

	_heading(column, "Ball")
	_picker = _colour_row(column, ["Colour"], [_ball_mat.albedo_color])[0]
	_picker.color_changed.connect(func(c: Color) -> void:
		_set_colour(c)
		_apply_colour()
		(_sliders["Albedo"] as HSlider).set_value_no_signal(_albedo)
		_show_slider("Albedo", _albedo))
	_slider(column, "Albedo", 0.0, 1.0, 0.01, _albedo, func(v: float) -> void:
		_albedo = v
		_apply_colour()
		_picker.color = _ball_mat.albedo_color)
	_note(column, "Fraction of light the surface reflects, as physics counts it.")
	_slider(column, "Roughness", 0.0, 1.0, 0.01, _ball_mat.roughness, func(v: float) -> void:
		_ball_mat.roughness = v)
	_note(column, "How widely reflections spread. Near 0 the bulb's reflection shrinks to a dot; it needs the sky or a large bright surface to show.")
	_slider(column, "Metallic", 0.0, 1.0, 0.01, _ball_mat.metallic, func(v: float) -> void:
		_ball_mat.metallic = v
		_refresh())
	_note(column, "Toward 1 the ball loses its diffuse colour and only reflects, tinted by its colour.")
	_specular_box = VBoxContainer.new()
	_specular_box.add_theme_constant_override("separation", 2)
	column.add_child(_specular_box)
	_slider(_specular_box, "Specular", 0.0, 1.0, 0.01, _ball_mat.metallic_specular, func(v: float) -> void:
		_ball_mat.metallic_specular = v)
	_specular_note = _note(_specular_box, "")
	_slider(column, "Segments", 8.0, 128.0, 2.0, float(_ball_mesh.radial_segments), func(v: float) -> void:
		_ball_mesh.radial_segments = int(v)
		_ball_mesh.rings = int(v) / 2)
	_note(column, "Changes the outline only: shading follows smoothed normals.")

	var reset := Button.new()
	reset.text = "Reset all"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(_reset)
	column.add_child(reset)


func _build_right(layer: CanvasLayer) -> void:
	var column := _column(layer)
	var panel := column.get_parent() as Control
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -COLUMN_W - 32.0
	panel.offset_right = -16.0
	panel.offset_top = 16.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_heading(column, "Indirect light")
	_status = _note(column, "")
	_status.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))

	_choice(column, "Outside", ["Void", "Colour", "Sky"], _set_outside)
	_colour_box = _box(column)
	_ambient_picker = _colour_row(_colour_box, ["Ambient colour"], [_env.ambient_light_color])[0]
	_ambient_picker.color_changed.connect(func(c: Color) -> void: _env.ambient_light_color = c)
	_slider(_colour_box, "Ambient energy", 0.0, 2.0, 0.01, _env.ambient_light_energy, func(v: float) -> void:
		_env.ambient_light_energy = v)
	_sky_box = _box(column)
	var pickers := _colour_row(_sky_box, ["Sky top", "horizon"],
		[_sky_mat.sky_top_color, _sky_mat.sky_horizon_color])
	pickers.append_array(_colour_row(_sky_box, ["Ground horizon", "bottom"],
		[_sky_mat.ground_horizon_color, _sky_mat.ground_bottom_color]))
	for i in 4:
		var prop := SKY_PROPS[i]
		var picker := pickers[i] as ColorPickerButton
		picker.color_changed.connect(func(c: Color) -> void: _sky_mat.set(prop, c))
		_sky_pickers[prop] = picker
	_sky_slider(_sky_box, "Sky curve", "sky_curve", 0.001, 1.0)
	_sky_slider(_sky_box, "Sky energy", "sky_energy_multiplier", 0.0, 4.0)
	_sky_slider(_sky_box, "Ground curve", "ground_curve", 0.001, 1.0)
	_sky_slider(_sky_box, "Ground energy", "ground_energy_multiplier", 0.0, 4.0)

	_choice(column, "Bounce", ["None", "SDFGI", "VoxelGI"], _set_bounce)
	_bounce_box = _box(column)
	_slider(_bounce_box, "Indirect energy", 0.0, 4.0, 0.01, _bulb.light_indirect_energy, func(v: float) -> void:
		_bulb.light_indirect_energy = v)
	_note(_bounce_box, "How much of the bulb's light enters the bounce.")

	_heading(column, "On screen, added to any of the above")
	_switch(column, "SSIL", func(on: bool) -> void:
		_env.ssil_enabled = on
		_refresh())
	_note(column, "One bounce, from surfaces in view only.")
	_switch(column, "SSAO", func(on: bool) -> void:
		_env.ssao_enabled = on
		_refresh())
	_note(column, "Darkens ambient and bounce light in corners; leaves the bulb's direct light alone.")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_1:
				_dither.button_pressed = not _dither.button_pressed
			KEY_2:
				_next_atlas()


## ---- what the choices set -----------------------------------------------

## What lies outside the room: the background, the ambient light and
## what glossy surfaces reflect.
func _set_outside(option: String) -> void:
	_outside = option
	match option:
		"Void":
			_env.background_mode = Environment.BG_COLOR
			_env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
			_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		"Colour":
			_env.background_mode = Environment.BG_COLOR
			_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		"Sky":
			_env.background_mode = Environment.BG_SKY
			_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_refresh()


## Two estimates of the same bounce light, so one at a time.
func _set_bounce(option: String) -> void:
	_bounce = option
	_env.sdfgi_enabled = option == "SDFGI"
	_set_voxel_gi(option == "VoxelGI")
	_refresh()


## A VoxelGI box just larger than the room, baked from the scene as it
## is now each time it is switched on.
func _set_voxel_gi(on: bool) -> void:
	if _voxel_gi != null:
		_voxel_gi.queue_free()
		_voxel_gi = null
	if not on:
		return
	_voxel_gi = VoxelGI.new()
	_voxel_gi.size = Vector3(32, 6, 32)
	_voxel_gi.position = Vector3(0, 2.8, 0)
	add_child(_voxel_gi)
	_voxel_gi.bake()


## Dim what has no effect now, and say where the light comes from.
func _refresh() -> void:
	_enable(_colour_box, _outside == "Colour" and _bounce != "SDFGI")
	_enable(_sky_box, _outside == "Sky")
	_enable(_bounce_box, _bounce != "None")
	var metal := _ball_mat.metallic >= 0.999
	_enable(_specular_box, not metal)
	_specular_note.text = "No effect at Metallic 1: a metal's reflection strength is its colour." if metal \
		else "Reflection strength of the non-metal part; 0.5 is about 4%, like paint or plastic."
	_status.text = _describe()


func _describe() -> String:
	var text := ""
	match _bounce:
		"None":
			match _outside:
				"Void":
					text = "Only the bulb lights the room; what it cannot reach is black."
				"Colour":
					text = "The ambient colour adds the same light to every surface, as if nothing blocked it."
				"Sky":
					text = "The sky adds light to each surface by the way it faces, as if nothing blocked it. Glossy surfaces reflect it."
		"SDFGI":
			text = "SDFGI: the bulb's light bounces off floor, wall and ball."
			match _outside:
				"Colour":
					text += " It ignores the ambient colour: it sees only the background, which is black."
				"Sky":
					text += " Sky light enters only through the open top and the doorway."
		"VoxelGI":
			text = "VoxelGI: the bulb's light bounces inside the box around the room."
			match _outside:
				"Colour":
					text += " Where its rays leave the box they pick up the ambient colour."
				"Sky":
					text += " Where its rays leave the box they pick up the sky."
	if _env.ssil_enabled:
		text += " SSIL adds a bounce from what is in view."
	if _env.ssao_enabled:
		if _outside == "Void" and _bounce == "None":
			text += " SSAO has nothing to darken."
		else:
			text += " SSAO darkens it in corners."
	return text


## ---- widgets -------------------------------------------------------------

## A column of controls on a dark panel, so they read against any sky.
func _column(layer: CanvasLayer) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(COLUMN_W, 0)
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	return column


func _box(column: VBoxContainer) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	column.add_child(box)
	return box


func _heading(column: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	column.add_child(label)


func _note(column: VBoxContainer, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(COLUMN_W, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	column.add_child(label)
	return label


## Labels and colour swatches on one row; the swatches, in order.
func _colour_row(column: VBoxContainer, titles: Array, colours: Array) -> Array:
	var row := HBoxContainer.new()
	var pickers := []
	for i in titles.size():
		var label := Label.new()
		label.text = str(titles[i])
		row.add_child(label)
		var picker := ColorPickerButton.new()
		picker.focus_mode = Control.FOCUS_NONE
		picker.edit_alpha = false
		picker.custom_minimum_size = Vector2(48, 22)
		picker.color = colours[i] as Color
		row.add_child(picker)
		pickers.append(picker)
	column.add_child(row)
	return pickers


## A row of options of which exactly one is chosen.
func _choice(column: VBoxContainer, title: String, options: Array, on_pick: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(64, 0)
	row.add_child(label)
	var group := ButtonGroup.new()
	var boxes := {}
	for option: String in options:
		var box := CheckBox.new()
		box.text = option
		box.button_group = group
		box.focus_mode = Control.FOCUS_NONE
		box.button_pressed = option == options[0]
		box.toggled.connect(func(on: bool) -> void:
			if on:
				on_pick.call(option))
		row.add_child(box)
		boxes[option] = box
	_choices[title] = boxes
	column.add_child(row)


## A switch, off as the scene opens.
func _switch(column: VBoxContainer, title: String, on_toggle: Callable) -> void:
	var button := CheckButton.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.toggled.connect(func(on: bool) -> void: on_toggle.call(on))
	_switches[title] = button
	column.add_child(button)


## A label and its slider on one row; the label shows the value.
func _slider(column: VBoxContainer, title: String, lo: float, hi: float, step: float,
		value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	row.add_child(slider)
	column.add_child(row)


func _sky_slider(column: VBoxContainer, title: String, prop: String, lo: float, hi: float) -> void:
	_slider(column, title, lo, hi, 0.001 if hi <= 1.0 else 0.01, float(_sky_mat.get(prop)),
		func(v: float) -> void: _sky_mat.set(prop, v))
	(_sliders[title] as HSlider).set_meta("prop", prop)


func _show_slider(title: String, v: float) -> void:
	var slider := _sliders[title] as HSlider
	var label := slider.get_meta("label") as Label
	var whole: bool = float(slider.get_meta("step")) >= 1.0
	label.text = "%s: %s" % [title, str(int(v)) if whole else "%.2f" % v]


## Dimmed and inert, or live: every control under a box.
func _enable(box: Control, on: bool) -> void:
	box.modulate.a = 1.0 if on else 0.35
	for node in box.find_children("*", "", true, false):
		if node is HSlider:
			(node as HSlider).editable = on
		elif node is BaseButton:
			(node as BaseButton).disabled = not on


## ---- the bulb and the ball's colour ----------------------------------------

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


## ---- reset, the atlas, leaving ------------------------------------------

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
	for prop: String in _sky_pickers:
		var picker := _sky_pickers[prop] as ColorPickerButton
		picker.color = _defaults[prop] as Color
		_sky_mat.set(prop, picker.color)
	for slider: HSlider in _sliders.values():
		if slider.has_meta("prop"):
			slider.value = float(_defaults[str(slider.get_meta("prop"))])
	for button: CheckButton in _switches.values():
		button.button_pressed = false
	(_choices["Outside"]["Void"] as CheckBox).button_pressed = true
	(_choices["Bounce"]["None"] as CheckBox).button_pressed = true
	_refresh()


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
