extends Node3D
## A round gray floor in a black void lit by one bare bulb, drawn with Godot's
## default shading: no sky, no ambient light, no post-processing. A
## wall twice a person's height rings it, open in one doorway; a
## player who walks out and off the edge is put back at the start.
##
## Controls on screen, used with the mouse freed by Esc, in two panels
## opened one at a time from two buttons at the top left. First: the
## viewport's debanding (1 key), a dither added before the 8-bit output;
## the shadow atlas (2 key), the texture all point and spot lights'
## shadow maps share, stepped through 4096, 8192 and 16384 texels square
## (it is a power of two), both put back as found when the scene closes;
## the bulb's colour, which sets the light's colour and the glass's
## emission (the light is invisible; the glass is drawn and lights
## nothing); the ball's colour, albedo, roughness, metallic, specular and
## segment count, each with a note on what it does; Reset all.
##
## Second: indirect light, arranged by how Godot combines it. What lies
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
## The ball and the bulb each hang on a rope from a hook 12 m up
## (Pendulum); each hook travels its own triangle across the room,
## waiting at each corner, at a speed and wait set in the Motion panel.
## They bounce off the wall and off each other. A count of frames a
## second sits at the top right.
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
const COLUMN_W := 240.0
const FONT_SIZE := 13
const NOTE_SIZE := 11
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
var _fps: Label
@onready var _ball: AnimatableBody3D = $Ball
var _ball_swing: Pendulum
var _radio: BulbRadio
var _acoustics: BulbAcoustics
var _sound_status: Label
var _sound_clock := 0.0
var _bulb_swing: Pendulum
var _ball_rig: Array = []               # the weight, its hook, its rope
var _bulb_rig: Array = []
var _restitution := 0.9                 # of a knock: 1 loses nothing
var _sun_model := "Off"                # Off, Infinite or Finite
var _sun_far: DirectionalLight3D
var _sun_near: SpotLight3D
var _sun_disc: MeshInstance3D
var _sun_box: VBoxContainer
var _distance_box: VBoxContainer
var _sun_note: Label
var _sky_mat: ProceduralSkyMaterial
var _phys_mat: PhysicalSkyMaterial
var _atmo_mat: ShaderMaterial
var _atmo_box: VBoxContainer
var _sky_model := "Gradient"            # Gradient or Physical
var _grad_box: VBoxContainer
var _phys_box: VBoxContainer
var _sun_sky: DirectionalLight3D        # lights the sky only, at the sun's full strength
var _outside := "Void"                 # Void, Colour or Sky
var _bounce := "None"                  # None, SDFGI or VoxelGI
var _debanding_was := false
var _atlas_was := 4096
var _atlas16_was := true
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
	_atlas16_was = vp.positional_shadow_atlas_16_bits
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
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	root.theme = theme
	layer.add_child(root)
	_build_swing()
	_build_swooshes()
	_build_floor()
	_build_wall()
	_build_ground()
	_build_tabs(root, [_build_left(root), _build_right(root), _build_sun(root), _build_motion(root),
		_build_textures(root), _build_terrain(root), _build_camera(root), _build_sound(root),
		_build_graphics(root)])
	_set_sun("Off")
	_fps = Label.new()
	_fps.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_fps.offset_left = -120.0
	_fps.offset_right = -16.0
	_fps.offset_top = 12.0
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_fps)
	_set_outside("Void")
	_set_bounce("None")
	_apply_textures()
	_load_state()
	_watch_controls()
	if DisplayServer.get_name() == "headless":
		print("[worldbuilder] bulb void: floor, one bulb")


## Two buttons at the top left, each opening its panel below them; one
## panel at most is open, and pressing the open one's button closes it.
func _build_tabs(root: Control, panels: Array) -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(16, 16)
	root.add_child(row)
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for i in panels.size():
		var panel := panels[i] as Control
		panel.position = Vector2(16, 48)
		panel.visible = false
		var tab := Button.new()
		tab.text = ["Bulb and ball", "Indirect light", "Sun", "Motion", "Textures", "Terrain", "Camera", "Sound", "Graphics"][i]
		tab.toggle_mode = true
		tab.button_group = group
		tab.focus_mode = Control.FOCUS_NONE
		tab.toggled.connect(func(on: bool) -> void: panel.visible = on)
		row.add_child(tab)


func _build_left(root: Control) -> Control:
	var column := _column(root)
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
	_bulb_box = _box(column)
	_slider(_bulb_box, "Bulb energy", 0.0, 10.0, 0.01, 1.0, func(_v: float) -> void: _apply_units())
	_defaults["Bulb energy"] = 1.0
	_note(_bulb_box, "The bulb's strength, its light and its glowing glass together. Arbitrary units only; in physical units the Camera panel's lumens set it.")

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
	return _panel_of(column)


func _build_right(root: Control) -> Control:
	var column := _column(root)
	_status = _note(column, "")
	_status.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))

	_choice(column, "Outside", ["Void", "Colour", "Sky"], _set_outside)
	_colour_box = _box(column)
	_ambient_picker = _colour_row(_colour_box, ["Ambient colour"], [_env.ambient_light_color])[0]
	_ambient_picker.color_changed.connect(func(c: Color) -> void: _env.ambient_light_color = c)
	_slider(_colour_box, "Ambient energy", 0.0, 2.0, 0.01, _env.ambient_light_energy, func(v: float) -> void:
		_env.ambient_light_energy = v)
	_sky_box = _box(column)
	_choice(_sky_box, "Sky model", ["Gradient", "Physical", "Atmosphere"], _set_sky_model)
	_grad_box = _box(_sky_box)
	var pickers := _colour_row(_grad_box, ["Sky top", "horizon"],
		[_sky_mat.sky_top_color, _sky_mat.sky_horizon_color])
	pickers.append_array(_colour_row(_grad_box, ["Ground horizon", "bottom"],
		[_sky_mat.ground_horizon_color, _sky_mat.ground_bottom_color]))
	for i in 4:
		var prop := SKY_PROPS[i]
		var picker := pickers[i] as ColorPickerButton
		picker.color_changed.connect(func(c: Color) -> void: _sky_mat.set(prop, c))
		_sky_pickers[prop] = picker
	_sky_slider(_grad_box, "Sky curve", "sky_curve", 0.001, 1.0)
	_sky_slider(_grad_box, "Sky energy", "sky_energy_multiplier", 0.0, 4.0)
	_sky_slider(_grad_box, "Ground curve", "ground_curve", 0.001, 1.0)
	_sky_slider(_grad_box, "Ground energy", "ground_energy_multiplier", 0.0, 4.0)
	_phys_box = _box(_sky_box)
	_phys_mat = PhysicalSkyMaterial.new()
	# The sky materials' own dither, about 0.001, is added before the
	# exposure; a night exposure multiplies it thousands of times into a
	# bright speckle. The viewport's dither, after the exposure, does the job.
	_phys_mat.use_debanding = false
	_sky_mat.use_debanding = false
	for spec: Array in [["Turbidity", "turbidity", 1.0, 20.0, 0.1], ["Rayleigh", "rayleigh_coefficient", 0.0, 8.0, 0.05],
			["Mie", "mie_coefficient", 0.0, 0.05, 0.0005], ["Mie forward", "mie_eccentricity", 0.0, 0.99, 0.01],
			["Sun disc size", "sun_disk_scale", 0.0, 20.0, 0.1], ["Air brightness", "energy_multiplier", 0.0, 4.0, 0.01]]:
		var prop := str(spec[1])
		_slider(_phys_box, str(spec[0]), float(spec[2]), float(spec[3]), float(spec[4]), float(_phys_mat.get(prop)),
			func(v: float) -> void: _phys_mat.set(prop, v))
		_defaults[str(spec[0])] = float(_phys_mat.get(prop))
	_atmo_box = _box(_sky_box)
	_atmo_mat = ShaderMaterial.new()
	_atmo_mat.shader = load("res://world/atmosphere_sky.gdshader") as Shader
	for spec: Array in [["Air density", "rayleigh_scale", 0.0, 3.0, 0.01, 1.0], ["Haze", "mie_scale", 0.0, 20.0, 0.1, 1.0],
			["Ozone", "ozone_scale", 0.0, 3.0, 0.01, 1.0], ["Haze forward", "mie_g", 0.0, 0.95, 0.01, 0.8]]:
		var param := str(spec[1])
		_slider(_atmo_box, str(spec[0]), float(spec[2]), float(spec[3]), float(spec[4]), float(spec[5]),
			func(v: float) -> void: _atmo_mat.set_shader_parameter(param, v))
		_defaults[str(spec[0])] = float(spec[5])
	_note(_atmo_box, "Worked out here, step by step along each line of sight through 100 km of air: sunlight scattered by the air (Rayleigh) and by haze (Mie), and absorbed by ozone, which turns twilight purple. The Earth's shadow gives twilight and night. 1 is the standard atmosphere and a clear day.")
	_note(_phys_box, "Godot's own physical sky: Rayleigh scattering off air molecules (blue overhead, red at sunset), Mie scattering off haze (the white glow round the sun, strongest forward). Turbidity is how hazy the air is. With the sun off, the physical sky is night.")

	_choice(column, "Bounce", ["None", "SDFGI", "VoxelGI"], _set_bounce)
	_bounce_box = _box(column)
	_slider(_bounce_box, "Indirect energy", 0.0, 4.0, 0.01, _bulb.light_indirect_energy, func(v: float) -> void:
		_bulb.light_indirect_energy = v)
	_note(_bounce_box, "How much of the bulb's light enters the bounce.")
	_switch(_bounce_box, "Earth in the bounce", func(on: bool) -> void:
		_earth.gi_mode = GeometryInstance3D.GI_MODE_STATIC if on else GeometryInstance3D.GI_MODE_DISABLED
		# SDFGI reads the scene's shapes when it starts: it is stopped for a
		# few frames and started again so the change shows.
		if _bounce == "SDFGI":
			_env.sdfgi_enabled = false
			_sdfgi_restart_in = 3)
	(_switches["Earth in the bounce"] as CheckButton).button_pressed = true
	_note(_bounce_box, "The unseen ground under the whole map, 20 m deep, which keeps a sun below the horizon from lighting anything. On, SDFGI counts it too, so a set sun's light does not reach the room through the bounce; off, SDFGI sees no ground beneath and a set sun floods the room with bounce light.")

	_heading(column, "On screen, added to any of the above")
	_switch(column, "SSIL", func(on: bool) -> void:
		_env.ssil_enabled = on
		_refresh())
	_note(column, "Light from the surfaces around each pixel on screen, taken from the last frame's image, so bounces build up over a few frames. Only surfaces in view contribute. It also dims the bounce where it finds it blocked.")
	_switch(column, "SSAO", func(on: bool) -> void:
		_env.ssao_enabled = on
		_refresh())
	_note(column, "Darkens ambient and bounce light in corners, SSIL's light included; leaves the bulb's direct light alone.")
	return _panel_of(column)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_1:
				_dither.button_pressed = not _dither.button_pressed
			KEY_2:
				_next_atlas()
			KEY_3:
				var radio := _switches["Radio playing (3)"] as CheckButton
				radio.button_pressed = not radio.button_pressed


## ---- the sun --------------------------------------------------------------

## The sun two ways. Infinitely far: a directional light, every ray
## parallel and the same strength everywhere. Finitely far: a spot light
## at the given distance aimed at the room's centre, its cone just wide
## enough for the room, falling off as the inverse square of distance
## and scaled so that at the room's centre it gives what the far sun
## gives; a glowing ball as wide as the real sun (0.53 degrees) marks
## it. Its angles: polar from straight up, azimuth from the doorway
## toward the ball.
##
## The finite sun's shadows need the shadow atlas at 32 bits a texel
## (at 16 the whole room shadows itself) and a bias that shrinks as the
## light's range grows (Godot scales the bias by the range); even so
## they break up past about 150 m, so the distance stops there.
const SUN_ANGLE := 0.533

func _build_sun(root: Control) -> Control:
	var column := _column(root)
	_choice(column, "Sun", ["Off", "Infinite", "Finite"], _set_sun)
	_sun_note = _note(column, "")
	_sun_note.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_sun_box = _box(column)
	_slider(_sun_box, "Polar angle", 0.0, 180.0, 1.0, 50.0, func(_v: float) -> void: _place_sun())
	_note(_sun_box, "From straight up: 0 overhead, 90 on the horizon.")
	_slider(_sun_box, "Azimuth", 0.0, 360.0, 1.0, 200.0, func(_v: float) -> void: _place_sun())
	_note(_sun_box, "Around the horizon from the doorway: 45 toward the ball, 180 behind the start.")
	_slider(_sun_box, "Sun energy", 0.0, 4.0, 0.01, 1.0, func(_v: float) -> void: _place_sun())
	_note(_sun_box, "Light on a surface facing the sun at the room's centre, above the air.")
	_switch(_sun_box, "Atmosphere dims and reddens the sun", func(_on: bool) -> void: _place_sun())
	_note(_sun_box, "The beam loses light on its way through the atmosphere, blue most: Rayleigh scattering by the air and some by haze, over a path that grows from one air mass overhead to about 38 at the horizon. Overhead the sun keeps about three quarters of its light; low, it turns orange and red and fades.")
	_switch(_sun_box, "No sun below the horizon", func(_on: bool) -> void: _place_sun())
	(_switches["No sun below the horizon"] as CheckButton).set_pressed_no_signal(true)
	_note(_sun_box, "With the atmosphere's dimming off, the sun keeps its full light at any angle, even after it has set. On, its light stops once it is below the horizon, as the Earth would block it. With the dimming on this changes nothing: a set sun already has no light left.")
	_distance_box = _box(column)
	_slider(_distance_box, "Distance (m)", 10.0, 150.0, 1.0, 60.0, func(_v: float) -> void: _place_sun())
	(_sliders["Distance (m)"] as HSlider).exp_edit = true
	_note(_distance_box, "Closer, the rays spread more: shadows grow with distance from what casts them, and the light weakens across the room. Godot's shadows for a light this far away break up past 150 m; by then it looks like the infinite sun anyway.")

	_sun_far = DirectionalLight3D.new()
	_sun_far.shadow_enabled = true
	_sun_far.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_sun_sky = DirectionalLight3D.new()
	_sun_sky.sky_mode = DirectionalLight3D.SKY_MODE_SKY_ONLY
	add_child(_sun_sky)
	_sun_far.directional_shadow_max_distance = 200.0   # the near hills; 800 m cost about 80 ms a frame
	add_child(_sun_far)
	_sun_near = SpotLight3D.new()
	_sun_near.shadow_enabled = true
	_sun_near.spot_attenuation = 2.0          # inverse square
	add_child(_sun_near)
	var disc_mat := StandardMaterial3D.new()
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_mat.albedo_color = Color(1.0, 0.97, 0.9)
	var disc_mesh := SphereMesh.new()
	disc_mesh.material = disc_mat
	_sun_disc = MeshInstance3D.new()
	_sun_disc.mesh = disc_mesh
	_sun_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sun_disc.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_sun_disc)
	_defaults["Polar angle"] = 50.0
	_defaults["Azimuth"] = 200.0
	_defaults["Sun energy"] = 1.0
	_defaults["Distance (m)"] = 60.0
	return _panel_of(column)


func _set_sun(option: String) -> void:
	_sun_model = option
	_sun_far.visible = option == "Infinite"
	_sun_sky.visible = option != "Off"
	_sun_near.visible = option == "Finite"
	_sun_disc.visible = option == "Finite"
	_enable(_sun_box, option != "Off")
	_enable(_distance_box, option == "Finite")
	get_viewport().positional_shadow_atlas_16_bits = _atlas16_was and option != "Finite"
	_place_sun()


## Unit vector from the room's centre toward the sun.
func _sun_dir() -> Vector3:
	var polar := deg_to_rad(float((_sliders["Polar angle"] as HSlider).value))
	var azimuth := deg_to_rad(float((_sliders["Azimuth"] as HSlider).value))
	return Vector3(sin(polar) * sin(azimuth), cos(polar), -sin(polar) * cos(azimuth))


func _place_sun() -> void:
	var dir := _sun_dir()
	var up := Vector3.FORWARD if absf(dir.y) > 0.999 else Vector3.UP
	var aim := Basis.looking_at(-dir, up)
	var energy := float((_sliders["Sun energy"] as HSlider).value) * _sun_scale()
	var d := float((_sliders["Distance (m)"] as HSlider).value)
	_sun_far.basis = aim
	_sun_sky.basis = aim
	_sun_sky.light_energy = energy
	if _atmo_mat != null:
		_atmo_mat.set_shader_parameter("sun_dir", dir)
		_atmo_mat.set_shader_parameter("sun_illuminance", 0.0 if _sun_model == "Off" else energy)
	if _phys_mat != null:
		_phys_mat.energy_multiplier = float((_sliders["Air brightness"] as HSlider).value) * (SKY_CAL if _physical else 1.0)
	# What reaches the ground: the sun's light less what the air scatters
	# out of the beam on the way.
	var through := Color(1, 1, 1)
	if (_switches["Atmosphere dims and reddens the sun"] as CheckButton).button_pressed:
		through = _air_transmittance(float((_sliders["Polar angle"] as HSlider).value))
	elif dir.y < 0.0 and (_switches["No sun below the horizon"] as CheckButton).button_pressed:
		through = Color(0, 0, 0)
	var lum := 0.2126 * through.r + 0.7152 * through.g + 0.0722 * through.b
	var hue := Color(through.r / maxf(through.r, 1e-6), through.g / maxf(through.r, 1e-6), through.b / maxf(through.r, 1e-6))
	var beam := hue.linear_to_srgb() if lum > 0.0 else Color.WHITE
	energy *= lum
	_sun_far.light_color = beam
	_sun_near.light_color = beam
	_sun_far.light_energy = energy
	# The spot's range is twice its distance; its window then lets
	# (1 - (1/2)^4)^2 of the light through at the room, which the energy
	# makes up, with the distance squared.
	var window := pow(1.0 - pow(0.5, 4.0), 2.0)
	_sun_near.transform = Transform3D(aim, dir * d)
	_sun_near.spot_range = 2.0 * d
	_sun_near.light_energy = energy * d * d / window
	_sun_near.spot_angle = rad_to_deg(atan((_room_r + 9.0) / d))
	_sun_near.shadow_bias = 0.9 / d
	_sun_disc.position = dir * d
	var r := d * tan(deg_to_rad(SUN_ANGLE / 2.0))
	(_sun_disc.mesh as SphereMesh).radius = r
	(_sun_disc.mesh as SphereMesh).height = 2.0 * r
	match _sun_model:
		"Off":
			_sun_note.text = "No sun: the bulb and the indirect light settings only."
		"Infinite":
			_sun_note.text = "A directional light: parallel rays, the same strength everywhere, no position. Seen as a disc only in the sky."
		"Finite":
			_sun_note.text = "A spot light %d m away aimed at the room: rays spread from one point. The floor's edge nearest the sun gets %d%% more light than the edge opposite." 				% [int(d), int(round((_edge_ratio(dir * d) - 1.0) * 100.0))]


## The fraction of sunlight that crosses the atmosphere at a zenith
## angle, in red, green and blue (680, 550 and 440 nm): exp(-tau m).
## Tau is Rayleigh's optical depth for dry air, 0.008569 lambda^-4 (1 +
## 0.0113 lambda^-2 + 0.00013 lambda^-4) with lambda in micrometres,
## plus haze by Angstrom's law, 0.1 lambda^-1.3; m is the air mass by
## Kasten and Young (1989), 1 overhead and about 38 at the horizon. Below
## the horizon the sun is set.
static func _air_transmittance(zenith_deg: float) -> Color:
	if zenith_deg >= 91.0:
		return Color(0, 0, 0)
	var z := minf(zenith_deg, 90.0)
	var m := 1.0 / (cos(deg_to_rad(z)) + 0.50572 * pow(96.07995 - z, -1.6364))
	var out: Array[float] = []
	for lam: float in [0.68, 0.55, 0.44]:
		var l2 := 1.0 / (lam * lam)
		var tau_r := 0.008569 * l2 * l2 * (1.0 + 0.0113 * l2 + 0.00013 * l2 * l2)
		var tau_a := 0.1 * pow(lam, -1.3)
		out.append(exp(-(tau_r + tau_a) * m))
	return Color(out[0], out[1], out[2])


## How much more light, by distance alone, the floor's edge nearest a
## light at this point gets than the edge opposite.
func _edge_ratio(at: Vector3) -> float:
	var flat := Vector3(at.x, 0.0, at.z)
	if flat.length() < 0.001:
		return 1.0
	var toward := flat.normalized() * _room_r
	return (at + toward).length_squared() / (at - toward).length_squared()


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


## The gradient sky (four colours chosen by hand) or the physical one
## (worked out from the sun's direction by Rayleigh and Mie scattering).
func _set_sky_model(option: String) -> void:
	_sky_model = option
	_env.sky.sky_material = _phys_mat if option == "Physical" else (_atmo_mat if option == "Atmosphere" else _sky_mat)
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
	_voxel_gi.size = Vector3(2.0 * _room_r + 2.0, maxf(6.0, _wall_h + 2.4), 2.0 * _room_r + 2.0)
	_voxel_gi.position.y = _voxel_gi.size.y * 0.5 - 0.2
	add_child(_voxel_gi)
	_voxel_gi.bake()


## Dim what has no effect now, and say where the light comes from.
func _refresh() -> void:
	_enable(_colour_box, _outside == "Colour" and _bounce != "SDFGI")
	_enable(_sky_box, _outside == "Sky")
	_enable(_grad_box, _outside == "Sky" and _sky_model == "Gradient")
	_enable(_phys_box, _outside == "Sky" and _sky_model == "Physical")
	_enable(_atmo_box, _outside == "Sky" and _sky_model == "Atmosphere")
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
		text += " SSIL adds light from what is in view."
	if _env.ssao_enabled:
		if _outside == "Void" and _bounce == "None":
			text += " SSAO has nothing to darken."
		else:
			text += " SSAO darkens it in corners."
	return text


## ---- widgets -------------------------------------------------------------

## A column of controls on a dark panel, so they read against any sky.
func _column(root: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_scrolls.append(scroll)
	var gutter := MarginContainer.new()
	gutter.add_theme_constant_override("margin_right", 12)      # clear of the scroll bar
	scroll.add_child(gutter)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(COLUMN_W, 0)
	column.add_theme_constant_override("separation", 2)
	gutter.add_child(column)
	return column


## The graphics options shared with the worlds (LabGraphics).
func _build_graphics(root: Control) -> Control:
	var column := _column(root)
	LabGraphics.attach(self, column)
	return _panel_of(column)


## The panel a column stands on.
func _panel_of(column: VBoxContainer) -> Control:
	var node: Node = column
	while not node is PanelContainer:
		node = node.get_parent()
	return node as Control


## The open panel stands as tall as its controls, up to the bottom of the
## window less a margin; beyond that it scrolls (mouse wheel or its bar).
var _scrolls: Array[ScrollContainer] = []


func _fit_panels() -> void:
	var room := get_viewport().get_visible_rect().size.y - 48.0 - 16.0 - 16.0
	for scroll in _scrolls:
		if not scroll.is_visible_in_tree():
			continue
		var want := minf((scroll.get_child(0) as Control).get_combined_minimum_size().y, room)
		if absf(scroll.custom_minimum_size.y - want) > 0.5:
			scroll.custom_minimum_size = Vector2(0.0, want)
			(scroll.get_parent() as Control).reset_size()


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
	label.add_theme_font_size_override("font_size", NOTE_SIZE)
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
		# No intensity slider: it multiplies the colour by 2 to its power,
		# a brightness that belongs to an energy (for the ball's colour, a
		# reflectance over 1, which no material has).
		picker.get_picker().edit_intensity = false
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
	label.custom_minimum_size = Vector2(56, 0)
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
	label.custom_minimum_size = Vector2(120, 0)
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
			"Ambient energy", "Indirect energy", "Bulb energy"]:
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
		if not button.has_meta("per_surface"):
			button.button_pressed = false
	(_choices["Outside"]["Void"] as CheckBox).button_pressed = true
	(_choices["Bounce"]["None"] as CheckBox).button_pressed = true
	for title: String in ["Polar angle", "Azimuth", "Sun energy", "Distance (m)",
			"Ball speed", "Ball wait", "Bulb speed", "Bulb wait", "Restitution"]:
		(_sliders[title] as HSlider).value = float(_defaults[title])
	(_choices["Sun"]["Off"] as CheckBox).button_pressed = true
	(_choices["Sky model"]["Gradient"] as CheckBox).button_pressed = true
	(_choices["Units"]["Arbitrary"] as CheckBox).button_pressed = true
	(_choices["Spreading"]["1/d"] as CheckBox).button_pressed = true
	(_sliders["Volume (dB)"] as HSlider).value = -6.0
	(_choices["Output"]["Speakers"] as CheckBox).button_pressed = true
	(_sliders["Master volume (dB)"] as HSlider).value = 0.0
	(_sliders["Swoosh level (dB)"] as HSlider).value = 0.0
	for title in SOUND_ON:
		(_switches[title] as CheckButton).button_pressed = true
	(_switches["Earth in the bounce"] as CheckButton).button_pressed = true
	(_switches["No sun below the horizon"] as CheckButton).button_pressed = true
	(_choices["Exposure"]["Meter"] as CheckBox).button_pressed = true
	(_sliders["Compensation (EV)"] as HSlider).value = 0.0
	(_choices["Curve"]["Linear"] as CheckBox).button_pressed = true
	for title: String in ["EV100", "Bulb (lm)", "White point"]:
		(_sliders[title] as HSlider).value = float(_defaults[title])
	for title: String in ["Turbidity", "Rayleigh", "Mie", "Mie forward", "Sun disc size", "Air brightness",
			"Air density", "Haze", "Ozone", "Haze forward"]:
		(_sliders[title] as HSlider).value = float(_defaults[title])
	for title: String in ["Room radius (m)", "Wall height (m)", "Ball rope length (m)", "Bulb cord length (m)",
			"Hill height (m)", "Hill size (m)", "Ruggedness", "Seed"]:
		(_sliders[title] as HSlider).value = float(_defaults[title])
	_surf = _surface_defaults()
	(_choices["Edit"]["Floor"] as CheckBox).button_pressed = true
	_show_surface()
	(_choices["Filter"]["Mipmaps"] as CheckBox).button_pressed = true
	(_choices["Ball map"]["UV"] as CheckBox).button_pressed = true
	_apply_textures()
	_refresh()


func _next_atlas() -> void:
	var vp := get_viewport()
	var i := ATLAS_SIZES.find(vp.positional_shadow_atlas_size)
	vp.positional_shadow_atlas_size = ATLAS_SIZES[(i + 1) % ATLAS_SIZES.size()]
	_show_atlas()
	_changed()


func _show_atlas() -> void:
	_atlas.text = "Shadow atlas: %d (2)" % get_viewport().positional_shadow_atlas_size


func _exit_tree() -> void:
	if _save_in >= 0.0:
		_save_state()
	_swooshes.clear()
	var vp := get_viewport()
	vp.use_debanding = _debanding_was
	vp.positional_shadow_atlas_size = _atlas_was
	vp.positional_shadow_atlas_16_bits = _atlas16_was


func _process(delta: float) -> void:
	if _sdfgi_restart_in > 0:
		_sdfgi_restart_in -= 1
		if _sdfgi_restart_in == 0 and _bounce == "SDFGI":
			_env.sdfgi_enabled = true
	var fps := Engine.get_frames_per_second()
	_fps.text = "%d fps  %.1f ms" % [fps, 1000.0 / maxf(fps, 1.0)]
	if _save_in >= 0.0:
		_save_in -= delta
		if _save_in < 0.0:
			_save_state()
	_adapt(delta)
	_hear(delta)
	_fit_panels()
	if _terrain_in >= 0.0:
		_terrain_in -= delta
		if _terrain_in < 0.0:
			_terrain.flat_r = _room_r + WALL_T
			_terrain.build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _save_in >= 0.0:
		_save_state()


## ---- remembering the controls --------------------------------------------

## Every control's setting is kept in user://bulb_void.json: written half
## a second after the last change (so a slider being dragged is written
## once, when it comes to rest) and on leaving, read back on arrival.
## Settings are found by their control's title, so a control added
## later starts at its default and one removed is ignored. Probes and
## headless runs neither read nor write it.
const STATE_PATH := "user://bulb_void.json"

var _save_in := -1.0                    # seconds to the next write; below 0, nothing to write
var _restoring := false


func _remembering() -> bool:
	return not MouseMode.probe and DisplayServer.get_name() != "headless"


func _changed() -> void:
	if not _restoring and _remembering():
		_save_in = 0.5


## Every control reports a change.
func _watch_controls() -> void:
	for slider: HSlider in _sliders.values():
		if not slider.has_meta("per_surface"):
			slider.value_changed.connect(func(_v: float) -> void: _changed())
	for button: CheckButton in _switches.values():
		if not button.has_meta("per_surface"):
			button.toggled.connect(func(_on: bool) -> void: _changed())
	_dither.toggled.connect(func(_on: bool) -> void: _changed())
	for boxes: Dictionary in _choices.values():
		for box: CheckBox in boxes.values():
			box.toggled.connect(func(_on: bool) -> void: _changed())
	for picker: ColorPickerButton in _colour_pickers().values():
		picker.color_changed.connect(func(_c: Color) -> void: _changed())


func _colour_pickers() -> Dictionary:
	var out := {"Bulb colour": _bulb_picker, "Ball colour": _picker, "Ambient colour": _ambient_picker}
	for prop: String in _sky_pickers:
		out[prop] = _sky_pickers[prop]
	return out


func _save_state() -> void:
	_save_in = -1.0
	if not _remembering():
		return
	var state := {"sliders": {}, "switches": {}, "choices": {}, "colours": {}, "surfaces": _surf,
		"dither": _dither.button_pressed, "atlas": get_viewport().positional_shadow_atlas_size}
	for title: String in _sliders:
		if not (_sliders[title] as HSlider).has_meta("per_surface"):
			state["sliders"][title] = (_sliders[title] as HSlider).value
	for title: String in _switches:
		if not (_switches[title] as CheckButton).has_meta("per_surface"):
			state["switches"][title] = (_switches[title] as CheckButton).button_pressed
	for title: String in _choices:
		for option: String in _choices[title]:
			if (_choices[title][option] as CheckBox).button_pressed:
				state["choices"][title] = option
	var pickers := _colour_pickers()
	for title: String in pickers:
		state["colours"][title] = (pickers[title] as ColorPickerButton).color.to_html(false)
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(state, "\t"))


## Each setting put back through its own control, so everything that
## follows from it follows: choices first, then colours (the ball's sets
## its albedo slider), then switches and sliders, then the materials.
func _load_state() -> void:
	if not _remembering() or not FileAccess.file_exists(STATE_PATH):
		return
	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var state: Dictionary = parsed
	_restoring = true
	var choices: Dictionary = state.get("choices", {})
	for title: String in choices:
		if _choices.has(title) and (_choices[title] as Dictionary).has(choices[title]):
			(_choices[title][choices[title]] as CheckBox).button_pressed = true
	var pickers := _colour_pickers()
	var colours: Dictionary = state.get("colours", {})
	for title: String in colours:
		if pickers.has(title):
			var picker := pickers[title] as ColorPickerButton
			picker.color = Color.html(str(colours[title]))
			picker.color_changed.emit(picker.color)
	# Each surface's settings over its defaults, so a setting added later
	# keeps its default.
	var surfaces: Dictionary = state.get("surfaces", {})
	for surface: String in surfaces:
		if _surf.has(surface) and surfaces[surface] is Dictionary:
			for key: String in surfaces[surface]:
				if (_surf[surface] as Dictionary).has(key):
					if key == "maps":
						(_surf[surface]["maps"] as Dictionary).merge(surfaces[surface]["maps"], true)
					else:
						_surf[surface][key] = surfaces[surface][key]
	_show_surface()
	var switches: Dictionary = state.get("switches", {})
	for title: String in switches:
		if _switches.has(title) and not (_switches[title] as CheckButton).has_meta("per_surface"):
			(_switches[title] as CheckButton).button_pressed = bool(switches[title])
	var sliders: Dictionary = state.get("sliders", {})
	for title: String in sliders:
		if _sliders.has(title) and not (_sliders[title] as HSlider).has_meta("per_surface"):
			(_sliders[title] as HSlider).value = float(sliders[title])
	_dither.button_pressed = bool(state.get("dither", _dither.button_pressed))
	var atlas := int(state.get("atlas", _atlas_was))
	if ATLAS_SIZES.has(atlas):
		get_viewport().positional_shadow_atlas_size = atlas
		_show_atlas()
	_apply_textures()
	_refresh()
	_restoring = false


## ---- the swinging ball and bulb ----------------------------------------------

const HOOK_Y := 12.0
var _still := false                     # hooks stopped, weights hanging at rest
const SUBSTEPS := 8


## Each corner, on a circle around the room's centre at an azimuth
## measured from the doorway toward the ball's side.
static func _corners(r: float, azimuths: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for a: float in azimuths:
		out.append(Vector3(r * sin(deg_to_rad(a)), 0, -r * cos(deg_to_rad(a))))
	return out


## The ball's hook runs a triangle nearly as wide as the room; the
## bulb's a smaller one turned 60 degrees from it. Both hooks run 12 m
## up; the ropes start long enough to hang the ball's centre 1.3 m over
## the floor and the bulb 2.2 m, and a shorter rope lifts its weight.
func _build_swing() -> void:
	_ball_swing = Pendulum.new(_corners(0.7 * _room_r, [30.0, 150.0, 270.0]), HOOK_Y, HOOK_Y - 1.3, 1.0, 1.0, 50.0)
	_ball_swing.speed = 1.2
	_ball_swing.wait = 4.0
	_bulb_swing = Pendulum.new(_corners(0.6 * _room_r, [90.0, 210.0, 330.0]), HOOK_Y, HOOK_Y - 2.2, 0.05, 0.05, 0.05)
	_bulb_swing.speed = 1.0
	_bulb_swing.wait = 3.0
	_ball_rig = [_ball, _hook_mesh(), _rope_mesh(0.015)]
	_bulb_rig = [_bulb, _hook_mesh(), _rope_mesh(0.006)]
	_acoustics = BulbAcoustics.new()
	add_child(_acoustics)
	player.footstep.connect(_acoustics.step)
	# The radio sits on the ball 35 degrees from its top, upright to the
	# ball's surface there.
	_radio = BulbRadio.new()
	var n := Vector3(0.0, cos(deg_to_rad(35.0)), -sin(deg_to_rad(35.0)))
	_radio.transform = Transform3D(Basis(Vector3.RIGHT, n, Vector3.RIGHT.cross(n)), n * 1.12)
	_ball.add_child(_radio)
	_acoustics.add_source("radio", _radio, BulbRadio.song())
	_acoustics.set_level("radio", -6.0)
	_acoustics.add_source("knock", null, null, [], 3)
	_draw_swing(_ball_swing, _ball_rig)
	_draw_swing(_bulb_swing, _bulb_rig)


func _hook_mesh() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.3, 0.15, 0.3)
	node.mesh = mesh
	node.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	add_child(node)
	return node


func _rope_mesh(r: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.radial_segments = 8
	mesh.rings = 1
	mesh.height = 1.0
	node.mesh = mesh
	node.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	add_child(node)
	return node


func _step_swing(delta: float) -> void:
	if _still:
		_ball_swing.hang_still()
		_bulb_swing.hang_still()
		_draw_swing(_ball_swing, _ball_rig)
		_draw_swing(_bulb_swing, _bulb_rig)
		return
	var dt := delta / SUBSTEPS
	var hardest := 0.0
	var where := Vector3.ZERO
	for _i in SUBSTEPS:
		_ball_swing.step(dt)
		_bulb_swing.step(dt)
		var hit := _knock_wall(_ball_swing)
		if hit > hardest:
			hardest = hit
			var c := _ball_swing.centre()
			where = c + Vector3(c.x, 0, c.z).normalized() * _ball_swing.radius
		_knock_wall(_bulb_swing)
		_knock_each_other(_ball_swing, _bulb_swing)
	_draw_swing(_ball_swing, _ball_rig)
	_draw_swing(_bulb_swing, _bulb_rig)
	_knock_sound(hardest, where, delta)


## A weight that reaches the wall, below its top, is put back against it and bounces
## off, leaving the restitution's share of its speed toward the wall.
## Returns the speed it struck at, 0 if it did not.
func _knock_wall(w: Pendulum) -> float:
	var c := w.centre()
	var flat := Vector3(c.x, 0, c.z)
	var limit := _room_r - w.radius
	if flat.length() <= limit or c.y - w.radius >= _wall_h:
		return 0.0
	var out := flat.normalized()
	w.place(c - out * (flat.length() - limit))
	var vn := w.velocity().dot(out)
	if vn > 0.0:
		w.push(-out * (1.0 + _restitution) * vn)
		return vn
	return 0.0


## The footsteps follow the surface underfoot: the floor's inside the
## wall, the ground's outside it; wet pebbles have their own.
func _underfoot() -> void:
	var at := Vector2(player.global_position.x, player.global_position.z)
	var surface := "Floor" if at.length() <= _room_r else "Ground"
	var material := str(_surf[surface]["material"])
	player.use_steps("pebbles" if material == "Wet pebbles" else "")


## The ball striking the wall, heard where it struck: a knock whose
## amplitude goes as the speed of impact (6 dB louder for twice as
## fast), 0 dB at 2 m/s and at most +6, its pitch varied a little from
## knock to knock.
## It is a source in the scene's acoustics, heard from where it struck:
## muffled over the wall from outside, with the wall's echoes. A knock
## under 3 cm/s, or within a tenth of a second of the
## last, is the ball settling against the wall, and is not heard.
const KNOCKS: Array[String] = ["res://audio/knock_1.wav", "res://audio/knock_2.wav", "res://audio/knock_3.wav"]
var _knock_gap := 0.0


func _knock_sound(speed: float, at: Vector3, delta: float) -> void:
	_knock_gap -= delta
	if speed < 0.03 or _knock_gap > 0.0 or not (_switches["Knocks"] as CheckButton).button_pressed:
		return
	_knock_gap = 0.1
	_acoustics.play("knock", load(KNOCKS[randi() % KNOCKS.size()]) as AudioStream, at,
		minf(20.0 * log(speed / 2.0) / log(10.0), 6.0), randf_range(0.92, 1.0))


## Two weights that meet are parted and exchange momentum along the
## line between their centres; the light one takes nearly all the change.
func _knock_each_other(a: Pendulum, b: Pendulum) -> void:
	var d := b.centre() - a.centre()
	var gap := a.radius + b.radius - d.length()
	if gap <= 0.0 or d.length() < 0.0001:
		return
	var n := d.normalized()
	var inv_a := 1.0 / a.mass
	var inv_b := 1.0 / b.mass
	a.place(a.centre() - n * gap * inv_a / (inv_a + inv_b))
	b.place(b.centre() + n * gap * inv_b / (inv_a + inv_b))
	var vn := (b.velocity() - a.velocity()).dot(n)
	if vn < 0.0:
		var j := -(1.0 + _restitution) * vn / (inv_a + inv_b)
		a.push(-n * j * inv_a)
		b.push(n * j * inv_b)


## The weight turned to hang along its rope, the hook, and the rope
## from the hook to where it is tied.
func _draw_swing(w: Pendulum, rig: Array) -> void:
	var along := w.swing.normalized()
	var up := -along
	var side := Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD
	var x := side.cross(up).normalized()
	var aim := Basis(x, up, x.cross(up))
	var hook := w.hook()
	(rig[0] as Node3D).global_transform = Transform3D(aim, w.centre())
	(rig[1] as Node3D).position = hook
	var end := w.rope_end()
	(rig[2] as Node3D).global_transform = Transform3D(aim.scaled_local(Vector3(1, (end - hook).length(), 1)), (hook + end) * 0.5)


## ---- the textures panel ----------------------------------------------------

## A library of materials for the floor, the wall and the ball, each
## chosen on its own. One set is generated here (tools/build_textures.py,
## every map from one height field); the rest are scans from ambientCG
## (CC0; each folder's SOURCE.txt names it). Each entry gives its real
## size in metres, width by height of one copy of the image; Scale
## multiplies it. Wet pebbles are a dry scan made wet: darker, its
## roughness cut to a third, as water fills the surface's pores and
## lies on it as a film. Grass takes a constant roughness of 0.9 in place
## of its scan's map: the scan measured single blades (about 0.26, waxy),
## but a flat surface standing for a lawn stands for thousands of blades at
## every angle, which together reflect as a very rough surface; at the
## blades' own value a low sun glares off the field. Its specular is 0.2
## (under 1% head-on, against 4% for most surfaces): toward a low sun the
## blades hide one another, so less light glances off the field. Each map has its own switch. The floor and wall
## are meshes built here whose texture coordinates are metres: the
## floor's its x and z, the wall's the distance round it and down from
## its top. The ball's run once round and pole to pole, or it is mapped
## triplanar in its own space. Height is parallax: the texture shifted
## by the view angle, the surface flat; its depth is in millimetres,
## turned into Godot's heightmap scale (hundredths of a texture repeat).
## Each entry's alpha is its sound absorption coefficient near 1 kHz, the
## share of sound a surface of it absorbs (textbook values, approximate;
## 0.02 where none is given).
## The Moon, the Earth and Mars are global maps (tools/build_planets.py,
## NASA and USGS data): on the ball they wrap it once, by its own
## texture coordinates, whatever the scale or mapping chosen; on floor
## or wall they lie flat as a map 12 m wide.
const LIBRARY: Array[Dictionary] = [
	{"name": "Plain gray", "alpha": 0.02},
	{"name": "Generated tiles", "dir": "generated_tiles", "size": Vector2(2.0, 2.0), "alpha": 0.02},
	{"name": "Limestone tiles", "dir": "ambientcg_tiles142", "size": Vector2(2.0, 2.0), "alpha": 0.02},
	{"name": "Travertine", "dir": "travertine", "size": Vector2(1.2, 1.2), "alpha": 0.03},
	{"name": "Marble", "dir": "marble", "size": Vector2(2.0, 2.0), "alpha": 0.01},
	{"name": "Wood floor", "dir": "wood_floor", "size": Vector2(1.8, 1.8), "alpha": 0.07},
	{"name": "Cobblestone", "dir": "cobblestone", "size": Vector2(1.15, 1.15), "alpha": 0.05},
	{"name": "Paving stones", "dir": "paving_stones", "size": Vector2(3.5, 3.5), "alpha": 0.03},
	{"name": "Red bricks", "dir": "red_bricks", "size": Vector2(2.4, 1.2), "alpha": 0.04},
	{"name": "Old stone bricks", "dir": "old_stone_bricks", "size": Vector2(1.8, 0.9), "alpha": 0.04},
	{"name": "Stone wall", "dir": "stone_wall", "size": Vector2(2.4, 2.4), "alpha": 0.05},
	{"name": "Rough rock", "dir": "rough_rock", "size": Vector2(2.0, 1.0), "alpha": 0.06},
	{"name": "Gravel", "dir": "gravel", "size": Vector2(1.6, 1.6), "alpha": 0.4},
	{"name": "Wet pebbles", "dir": "pebbles", "size": Vector2(1.0, 1.0), "wet": true, "alpha": 0.05},
	{"name": "Grass", "dir": "grass", "size": Vector2(1.4, 1.4), "canopy_rough": 0.9, "canopy_spec": 0.2, "alpha": 0.3},
	{"name": "The Moon", "dir": "planet_moon", "size": Vector2(12.0, 6.0), "globe": true},
	{"name": "The Earth", "dir": "planet_earth", "size": Vector2(12.0, 6.0), "globe": true},
	{"name": "Mars", "dir": "planet_mars", "size": Vector2(12.0, 6.0), "globe": true},
]
const TEX_MAPS: Array[String] = ["Albedo", "Roughness", "Normal", "Height", "AO"]
const TEX_FILES := {"Albedo": "albedo", "Roughness": "roughness", "Normal": "normal", "Height": "height", "AO": "ao"}
const FILTERS := {"Nearest": BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Bilinear": BaseMaterial3D.TEXTURE_FILTER_LINEAR,
	"Mipmaps": BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
	"Anisotropic": BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC}
const WALL_T := 2.0                     # the wall's thickness: thick enough that SDFGI's coarse cells do not carry the sunlit ground outside onto the inside of its foot
# The floor is a solid disc this thick, its top at 0, reaching out under
# the wall to its outer face; the wall stands from the floor's underside,
# so the two overlap and no light finds a crack at the wall's foot.
const FLOOR_T := 0.3
var _wall_h := 3.6                      # the wall's height, 0 to 36 m (Wall height slider)
const DOOR_W := 0.9
# The unseen earth slab's faces in tiles this many a side (40 m): Godot
# squashes shadow casters beyond a cascade's depth range onto its near
# edge corner by corner, which tilts a very large triangle's depth, and
# the slab's shadow as two triangles a face came out wrong.
const EARTH_TILES := 100
const PLAIN := Color(0.5, 0.5, 0.5)

var _floor_mat: StandardMaterial3D
var _wall_mat: StandardMaterial3D
var _wall_view: MeshInstance3D
var _wall_shape: CollisionShape3D
var _room_r := 15.0                     # the floor's radius and the wall's inner face
var _bulb_box: VBoxContainer
var _earth: MeshInstance3D
var _sdfgi_restart_in := 0              # frames until SDFGI starts again; 0, none
var _ground_mat: ShaderMaterial
var _terrain: BulbTerrain
var _terrain_in := -1.0                 # seconds to a terrain rebuild; below 0, none due
const SURFACES: Array[String] = ["Floor", "Walls", "Ball", "Ground"]
var _tex_filter := "Mipmaps"
var _ball_map := "UV"
var _surf: Dictionary = {}              # surface -> its settings (see _surface_defaults)
var _edit := "Floor"                    # the surface the panel shows
var _mat_pick: OptionButton
var _ground_box: VBoxContainer
var _height_box: VBoxContainer


## A disc in place of the floor's cylinder, its texture coordinates its
## x and z in metres, with tangents for normal maps.
func _build_floor() -> void:
	var node := $Floor/Mesh as MeshInstance3D
	node.position = Vector3.ZERO
	_floor_mat = StandardMaterial3D.new()
	_floor_mat.albedo_color = PLAIN
	node.material_override = _floor_mat
	_shape_floor()


func _shape_floor() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 256
	var r := _room_r + WALL_T
	var down := Vector3(0, -FLOOR_T, 0)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var e0 := Vector3(sin(a0), 0, cos(a0))
		var e1 := Vector3(sin(a1), 0, cos(a1))
		var p: Array = [Vector3.ZERO, e0 * r, e1 * r]
		_tri(st, p, [Vector3.UP, Vector3.UP, Vector3.UP],
			[Vector2(p[0].x, p[0].z), Vector2(p[1].x, p[1].z), Vector2(p[2].x, p[2].z)])
		var q: Array = [down, e0 * r + down, e1 * r + down]
		_tri(st, q, [Vector3.DOWN, Vector3.DOWN, Vector3.DOWN],
			[Vector2(q[0].x, q[0].z), Vector2(q[1].x, q[1].z), Vector2(q[2].x, q[2].z)])
		_quad(st, [e0 * r, e1 * r, e1 * r + down, e0 * r + down], [e0, e1, e1, e0],
			[Vector2(r * a0, 0), Vector2(r * a1, 0), Vector2(r * a1, FLOOR_T), Vector2(r * a0, FLOOR_T)])
	st.generate_tangents()
	($Floor/Mesh as MeshInstance3D).mesh = st.commit()
	(($Floor/Collision as CollisionShape3D).shape as CylinderShape3D).radius = _room_r + WALL_T + 0.5


## The ring wall, WALL_T thick and 3.6 m high over the floor, standing
## from the floor's underside (FLOOR_T down), open in a doorway 0.9 m
## wide toward -z: inside and outside faces, its top, and the doorway's
## two sides. Texture coordinates are metres: round the wall and down
## from its top on the faces, x and z on the top.
func _build_wall() -> void:
	var body := StaticBody3D.new()
	body.name = "Wall"
	add_child(body)
	_wall_view = MeshInstance3D.new()
	_wall_mat = StandardMaterial3D.new()
	_wall_mat.albedo_color = PLAIN
	_wall_view.material_override = _wall_mat
	body.add_child(_wall_view)
	_wall_shape = CollisionShape3D.new()
	body.add_child(_wall_shape)
	_shape_wall()


func _shape_wall() -> void:
	var wall_in := _room_r
	var wall_out := _room_r + WALL_T
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := asin(DOOR_W / 2.0 / wall_in)
	var n := 256
	for i in n:
		var a0 := half + (TAU - 2.0 * half) * i / n
		var a1 := half + (TAU - 2.0 * half) * (i + 1) / n
		var in0 := Vector3(-sin(a0), 0, cos(a0))
		var in1 := Vector3(-sin(a1), 0, cos(a1))
		_quad(st, [_round(wall_in, a0, -FLOOR_T), _round(wall_in, a1, -FLOOR_T), _round(wall_in, a1, _wall_h), _round(wall_in, a0, _wall_h)],
			[in0, in1, in1, in0],
			[Vector2(wall_in * a0, _wall_h + FLOOR_T), Vector2(wall_in * a1, _wall_h + FLOOR_T), Vector2(wall_in * a1, 0), Vector2(wall_in * a0, 0)])
		_quad(st, [_round(wall_out, a0, -FLOOR_T), _round(wall_out, a1, -FLOOR_T), _round(wall_out, a1, _wall_h), _round(wall_out, a0, _wall_h)],
			[-in0, -in1, -in1, -in0],
			[Vector2(-wall_out * a0, _wall_h + FLOOR_T), Vector2(-wall_out * a1, _wall_h + FLOOR_T), Vector2(-wall_out * a1, 0), Vector2(-wall_out * a0, 0)])
		var top: Array = [_round(wall_in, a0, _wall_h), _round(wall_in, a1, _wall_h), _round(wall_out, a1, _wall_h), _round(wall_out, a0, _wall_h)]
		_quad(st, top, [Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP],
			[Vector2(top[0].x, top[0].z), Vector2(top[1].x, top[1].z), Vector2(top[2].x, top[2].z), Vector2(top[3].x, top[3].z)])
	for side: float in [-1.0, 1.0]:
		var a := half if side < 0.0 else TAU - half
		var out := Vector3(cos(a), 0, sin(a)) * side
		_quad(st, [_round(wall_in, a, -FLOOR_T), _round(wall_out, a, -FLOOR_T), _round(wall_out, a, _wall_h), _round(wall_in, a, _wall_h)],
			[out, out, out, out],
			[Vector2(0, _wall_h + FLOOR_T), Vector2(wall_out - wall_in, _wall_h + FLOOR_T), Vector2(wall_out - wall_in, 0), Vector2(0, 0)])
	st.generate_tangents()
	var mesh := st.commit()
	_wall_view.mesh = mesh
	_wall_shape.shape = mesh.create_trimesh_shape()
	# At no height there is no wall: nothing drawn, nothing to bump.
	_wall_view.visible = _wall_h > 0.01
	_wall_shape.disabled = _wall_h <= 0.01


## The ground outside the room: procedural terrain (BulbTerrain), level
## by the room and rising into hills, textured by the ground shader. It
## is rebuilt a third of a second after its last change (a room radius
## or terrain slider being dragged rebuilds once, when it comes to rest).
func _build_ground() -> void:
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = load("res://world/ground_tex.gdshader") as Shader
	_terrain = BulbTerrain.new(_ground_mat)
	add_child(_terrain)
	_terrain.flat_r = _room_r + WALL_T
	_terrain.build()
	# The Earth under the map: an unseen slab 20 m thick, its top level with
	# the floor and the flat ground round the room (with a gap below the
	# wall's foot, a sun exactly on the horizon shone in under the wall:
	# the shadow map's squares straddling the foot saw through it), wider than the terrain (1.5 km out),
	# casting shadows only. A light from below the horizon then lights
	# nothing above it, whatever its direction. It must be a solid: a flat
	# sheet casts no shadow for light reaching its back, since Godot's
	# shadow pass, like the camera, skips a one-sided surface's back. It
	# takes part in SDFGI too, which judges what blocks the sun from its
	# own coarse model of the scene's shapes, not the shadow maps: left out,
	# a set sun lit the floor's and ground's undersides there and its light
	# spread into the room. 20 m deep gave the least of that (2 m let more
	# through; 60 m broke the sun's shadows).
	var slab := BoxMesh.new()
	slab.size = Vector3(4000.0, 20.0, 4000.0)
	slab.subdivide_width = EARTH_TILES
	slab.subdivide_depth = EARTH_TILES
	var earth := MeshInstance3D.new()
	_earth = earth
	earth.mesh = slab
	earth.position.y = -10.0
	earth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	earth.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	add_child(earth)


func _shape_ground() -> void:
	_terrain_in = 0.33


## The room at a new radius: floor, wall, the hooks' paths (the ball's
## 0.7 of the radius out, the bulb's 0.6), the ground outside, the player kept clear of the wall, the
## finite sun's aim.
func _set_room(r: float) -> void:
	var was_inside := Vector2(player.global_position.x, player.global_position.z).length() <= _room_r + WALL_T / 2.0
	_room_r = r
	_shape_floor()
	_shape_wall()
	_shape_ground()
	_ball_swing.corners = _corners(0.7 * r, [30.0, 150.0, 270.0])
	_bulb_swing.corners = _corners(0.6 * r, [90.0, 210.0, 330.0])
	# The wall never lands on the player: kept on whichever side they were.
	var at := player.global_position
	var flat := Vector2(at.x, at.z)
	if was_inside and flat.length() > r - 0.6:
		flat = flat.normalized() * (r - 0.6)
	elif not was_inside and flat.length() < r + WALL_T + 0.6:
		flat = flat.normalized() * (r + WALL_T + 0.6)
	player.global_position = Vector3(flat.x, at.y, flat.y)
	_place_sun()


## A point on the wall: radius, azimuth from the doorway toward the
## ball's side, height.
static func _round(r: float, a: float, y: float) -> Vector3:
	return Vector3(r * sin(a), y, -r * cos(a))


## A triangle, wound so its front faces the way its normals point
## (Godot draws a triangle's front where its corners run clockwise).
static func _tri(st: SurfaceTool, p: Array, n: Array, uv: Array) -> void:
	var p0: Vector3 = p[0]
	var p1: Vector3 = p[1]
	var p2: Vector3 = p[2]
	var face := (p1 - p0).cross(p2 - p0)
	var order: Array = [0, 1, 2] if face.dot(n[0] + n[1] + n[2]) < 0.0 else [0, 2, 1]
	for k: int in order:
		st.set_normal(n[k])
		st.set_uv(uv[k])
		st.add_vertex(p[k])


static func _quad(st: SurfaceTool, p: Array, n: Array, uv: Array) -> void:
	_tri(st, [p[0], p[1], p[2]], [n[0], n[1], n[2]], [uv[0], uv[1], uv[2]])
	_tri(st, [p[0], p[2], p[3]], [n[0], n[2], n[3]], [uv[0], uv[2], uv[3]])


## Each surface keeps its own settings: its material, scale, which maps
## are on, normal strength, parallax depth, roughness and brightness
## multipliers, and for the ground variation and tiling. The panel shows
## the surface chosen under Edit; its controls write to that surface only.
static func _surface_defaults() -> Dictionary:
	var out := {}
	for surface in SURFACES:
		out[surface] = {"material": "Grass" if surface == "Ground" else "Plain gray", "scale": 1.0,
			"maps": {"Albedo": true, "Roughness": true, "Normal": true, "Height": true, "AO": true},
			"normal": 1.0, "height": 10.0, "deep": false, "rough": 1.0, "bright": 1.0,
			"variation": 0.6, "tiling": true}
	return out


func _build_textures(root: Control) -> Control:
	_surf = _surface_defaults()
	var column := _column(root)
	_choice(column, "Edit", SURFACES, func(option: String) -> void:
		_edit = option
		_show_surface())
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Material"
	label.custom_minimum_size = Vector2(56, 0)
	row.add_child(label)
	_mat_pick = OptionButton.new()
	_mat_pick.focus_mode = Control.FOCUS_NONE
	_mat_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry: Dictionary in LIBRARY:
		_mat_pick.add_item(str(entry["name"]))
	_mat_pick.item_selected.connect(func(i: int) -> void: _set_surf("material", str(LIBRARY[i]["name"])))
	row.add_child(_mat_pick)
	column.add_child(row)
	_note(column, "Generated tiles are made here, every map from one height field; the rest are scans from ambientCG (CC0); the planets are NASA and USGS maps. Wet pebbles are a dry scan made darker and glossier.")
	_surf_slider(column, "Scale", "scale", 0.25, 4.0, 0.05)
	_note(column, "1 is the material's real size; the planets always wrap the ball once.")
	_heading(column, "Maps")
	for title in TEX_MAPS:
		_switch(column, title, func(on: bool) -> void:
			if not _restoring:
				(_surf[_edit]["maps"] as Dictionary)[title] = on
				_after_surface_change())
		(_switches[title] as CheckButton).set_meta("per_surface", true)
	_note(column, "Height shifts the texture by the view angle to fake depth; outlines and shadows stay flat. AO darkens only ambient and bounce light. Marble and the limestone tiles have no AO map; the planets have no height map.")
	_surf_slider(column, "Normal strength", "normal", 0.0, 2.0, 0.01)
	_surf_slider(column, "Roughness x", "rough", 0.0, 2.0, 0.01)
	_surf_slider(column, "Brightness", "bright", 0.0, 2.0, 0.01)
	_height_box = _box(column)
	_surf_slider(_height_box, "Height depth (mm)", "height", 0.0, 100.0, 1.0)
	_switch(_height_box, "Deep parallax", func(on: bool) -> void: _set_surf("deep", on))
	(_switches["Deep parallax"] as CheckButton).set_meta("per_surface", true)
	_note(_height_box, "Deep parallax steps through the height in layers so raised parts hide what lies behind them; costs more.")
	_ground_box = _box(column)
	_surf_slider(_ground_box, "Variation", "variation", 0.0, 1.0, 0.01)
	_switch(_ground_box, "Break up tiling", func(on: bool) -> void: _set_surf("tiling", on))
	(_switches["Break up tiling"] as CheckButton).set_meta("per_surface", true)
	_note(_ground_box, "The ground only. Variation lays broad patches of drier and lusher colour, 6 to 40 m across. Breaking up the tiling reads the texture again larger and turned, and lets noise choose between the two, so no repeat lines up.")
	_choice(column, "Filter", ["Nearest", "Bilinear", "Mipmaps", "Anisotropic"], func(option: String) -> void:
		_tex_filter = option
		_apply_textures())
	(_choices["Filter"]["Mipmaps"] as CheckBox).set_pressed_no_signal(true)
	(_choices["Filter"]["Nearest"] as CheckBox).set_pressed_no_signal(false)
	_note(column, "For floor, walls and ball (the ground filters anisotropically always). Look across the floor toward the wall: without mipmaps far detail shimmers; mipmaps alone blur it; anisotropic keeps it sharp.")
	_choice(column, "Ball map", ["UV", "Triplanar"], func(option: String) -> void:
		_ball_map = option
		_apply_textures())
	_note(column, "UV wraps the image round the ball and pinches it at the poles. Triplanar projects it from three sides, no seams, blended where they meet; Godot does no height with it.")
	_show_surface()
	return _panel_of(column)


## A slider that writes one of the edited surface's settings.
func _surf_slider(column: VBoxContainer, title: String, key: String, lo: float, hi: float, step: float) -> void:
	_slider(column, title, lo, hi, step, 1.0, func(v: float) -> void: _set_surf(key, v))
	(_sliders[title] as HSlider).set_meta("per_surface", true)


func _set_surf(key: String, value: Variant) -> void:
	if _restoring:
		return
	_surf[_edit][key] = value
	_after_surface_change()


func _after_surface_change() -> void:
	_apply_textures()
	_changed()


## The panel's controls set to the edited surface's settings, quietly.
func _show_surface() -> void:
	var was := _restoring
	_restoring = true
	var st: Dictionary = _surf[_edit]
	_mat_pick.select(_library_index(str(st["material"])))
	for pair: Array in [["Scale", "scale"], ["Normal strength", "normal"], ["Roughness x", "rough"],
			["Brightness", "bright"], ["Height depth (mm)", "height"], ["Variation", "variation"]]:
		var slider := _sliders[pair[0]] as HSlider
		slider.set_value_no_signal(float(st[pair[1]]))
		_show_slider(str(pair[0]), slider.value)
	for title in TEX_MAPS:
		(_switches[title] as CheckButton).set_pressed_no_signal(bool((st["maps"] as Dictionary)[title]))
	(_switches["Deep parallax"] as CheckButton).set_pressed_no_signal(bool(st["deep"]))
	(_switches["Break up tiling"] as CheckButton).set_pressed_no_signal(bool(st["tiling"]))
	_enable(_ground_box, _edit == "Ground")
	_enable(_height_box, _edit != "Ground")
	_restoring = was


func _apply_textures() -> void:
	for surface in SURFACES:
		var st: Dictionary = _surf[surface]
		var entry := LIBRARY[_library_index(str(st["material"]))]
		var size: Vector2 = entry.get("size", Vector2.ONE) * float(st["scale"])
		match surface:
			"Floor":
				_dress(_floor_mat, entry, st, Vector3(1.0 / size.x, 1.0 / size.y, 1.0), false, true)
			"Walls":
				_dress(_wall_mat, entry, st, Vector3(1.0 / size.x, 1.0 / size.y, 1.0), false, true)
			"Ground":
				_dress_ground(entry, st, size)
			"Ball":
				var r := _ball_swing.radius
				if entry.get("globe", false):
					_dress(_ball_mat, entry, st, Vector3.ONE, false, false)
				elif _ball_map == "Triplanar":
					_dress(_ball_mat, entry, st, Vector3(1.0 / size.x, 1.0 / size.y, 1.0 / size.x), true, false)
				else:
					_dress(_ball_mat, entry, st, Vector3(TAU * r / size.x, PI * r / size.y, 1.0), false, false)


static func _library_index(entry_name: String) -> int:
	for i in LIBRARY.size():
		if str(LIBRARY[i]["name"]) == entry_name:
			return i
	return 0


## A library entry's map, if it has one and the surface has it on.
static func _map(entry: Dictionary, st: Dictionary, title: String) -> Texture2D:
	var dir := str(entry.get("dir", ""))
	if dir == "" or not bool((st["maps"] as Dictionary)[title]):
		return null
	if title == "Roughness" and entry.has("canopy_rough"):
		return null
	for ext: String in [".png", ".jpg"]:
		var path := "res://textures/" + dir + "/" + str(TEX_FILES[title]) + ext
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


## One material in one library entry with one surface's settings: each
## map on or off, its strengths, the filter, the coordinates' scale and
## whether they are triplanar. A textured surface takes the texture's
## colour (darkened if wet) times its brightness; a plain one its own:
## gray for floor and wall, the ball's colour and roughness from its
## panel.
func _dress(mat: StandardMaterial3D, entry: Dictionary, st: Dictionary, scale: Vector3, triplanar: bool, own_colour: bool) -> void:
	var maps := {}
	for title in TEX_MAPS:
		maps[title] = _map(entry, st, title)
	var wet: bool = entry.get("wet", false)
	var bright := float(st["bright"]) * (0.65 if wet else 1.0)
	if maps["Albedo"] != null:
		mat.albedo_color = Color(bright, bright, bright)
	elif own_colour:
		mat.albedo_color = Color(PLAIN.r * bright, PLAIN.g * bright, PLAIN.b * bright)
	else:
		_apply_colour()
	var base_rough := 1.0 if own_colour or maps["Albedo"] != null else float((_sliders["Roughness"] as HSlider).value)
	if entry.has("canopy_rough"):
		base_rough = float(entry["canopy_rough"])
	mat.metallic_specular = float(entry.get("canopy_spec", 0.5)) if maps["Albedo"] != null or own_colour 		else float((_sliders["Specular"] as HSlider).value)
	mat.roughness = clampf(base_rough * float(st["rough"]) * (0.3 if wet else 1.0), 0.0, 1.0)
	mat.albedo_texture = maps["Albedo"]
	mat.roughness_texture = maps["Roughness"]
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.normal_enabled = maps["Normal"] != null
	mat.normal_texture = maps["Normal"]
	mat.normal_scale = float(st["normal"])
	mat.heightmap_enabled = maps["Height"] != null and not triplanar
	mat.heightmap_texture = maps["Height"]
	mat.heightmap_scale = float(st["height"]) / 1000.0 * scale.x * 100.0
	mat.heightmap_deep_parallax = bool(st["deep"])
	mat.ao_enabled = maps["AO"] != null
	mat.ao_texture = maps["AO"]
	mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.texture_filter = FILTERS[_tex_filter]
	mat.uv1_triplanar = triplanar
	mat.uv1_world_triplanar = false
	mat.uv1_scale = scale if str(entry.get("dir", "")) != "" else Vector3.ONE


## The ground's shader with one entry and the ground's settings.
func _dress_ground(entry: Dictionary, st: Dictionary, size: Vector2) -> void:
	var wet: bool = entry.get("wet", false)
	var pairs := {"Albedo": ["albedo_tex", "use_albedo"], "Normal": ["normal_tex", "use_normal"],
		"Roughness": ["rough_tex", "use_rough"], "AO": ["ao_tex", "use_ao"]}
	for title: String in pairs:
		var tex := _map(entry, st, title)
		_ground_mat.set_shader_parameter(pairs[title][0], tex)
		_ground_mat.set_shader_parameter(pairs[title][1], tex != null)
	_ground_mat.set_shader_parameter("base_color", PLAIN)
	_ground_mat.set_shader_parameter("tile_m", size)
	_ground_mat.set_shader_parameter("normal_strength", float(st["normal"]))
	_ground_mat.set_shader_parameter("roughness_scale", float(entry.get("canopy_rough", 1.0)) * float(st["rough"]) * (0.3 if wet else 1.0))
	_ground_mat.set_shader_parameter("specular", float(entry.get("canopy_spec", 0.5)))
	_ground_mat.set_shader_parameter("brightness", float(st["bright"]) * (0.65 if wet else 1.0))
	_ground_mat.set_shader_parameter("variation", float(st["variation"]))
	_ground_mat.set_shader_parameter("break_tiling", 1.0 if bool(st["tiling"]) else 0.0)


## ---- the camera: light units and exposure --------------------------------

## Godot's own physical light units are a project setting, read at start
## and shared by every world, so this scene does the same arithmetic
## itself. In Physical units each light is given its real value and
## multiplied by LUX: the sun 127,000 lux above the air (the solar
## constant, 1361 W/m2, at about 93 lm/W) times Sun energy; the bulb its
## lumens over 4 pi steradians as candelas, falling off as the inverse
## square; the bulb's glass its luminance; the physical sky calibrated so
## its blue is about 7,000 nits. The camera then turns luminance into the
## image by saturation-based exposure, image = L / (1.2 2^EV100), which
## with Godot's lights carrying no 1/pi makes the exposure
## 1 / (pi LUX 1.2 2^EV100). In Arbitrary units nothing is converted and
## the exposure is 1.
const LUX := 1e-5                       # Godot's value for one lux
const SUN_LUX := 127000.0
const SKY_CAL := 1.7                    # measured: blue sky overhead about 4,900 nits with the sun 60 degrees up
const EV_PRESETS := {"Noon 15": 15.0, "Shade 12": 12.0, "Dusk 9": 9.0, "Room 5": 5.0, "Bulb 2": 2.0, "Moon -2": -2.0}
const TONEMAPS := {"Linear": Environment.TONE_MAPPER_LINEAR, "Reinhard": Environment.TONE_MAPPER_REINHARDT,
	"Filmic": Environment.TONE_MAPPER_FILMIC, "ACES": Environment.TONE_MAPPER_ACES, "AgX": Environment.TONE_MAPPER_AGX}

var _physical := false
var _metering := true                   # exposure from the light meter, else the EV100 slider
var _ev_now := 15.0                     # the exposure in use, easing toward the meter


func _sun_scale() -> float:
	return SUN_LUX * LUX if _physical else 1.0


func _build_camera(root: Control) -> Control:
	var column := _column(root)
	_choice(column, "Units", ["Arbitrary", "Physical"], func(option: String) -> void:
		_physical = option == "Physical"
		_apply_units())
	_note(column, "Physical: the sun in lux, the bulb in lumens, the sky in nits, as they are; the camera's exposure then decides what is bright. Arbitrary: each light's strength as set, exposure 1.")
	_choice(column, "Exposure", ["Meter", "Manual"], func(option: String) -> void:
		_metering = option == "Meter"
		_apply_units())
	_note(column, "Meter: the exposure follows the light where you stand, as the eye adapts, easing over about a second. Manual: set EV100 yourself, as on a camera; a manual exposure is right only for light of that strength.")
	_slider(column, "Compensation (EV)", -3.0, 3.0, 0.1, 0.0, func(_v: float) -> void: pass)
	_defaults["Compensation (EV)"] = 0.0
	_slider(column, "EV100", -4.0, 17.0, 0.1, 15.0, func(_v: float) -> void:
		if _metering and not _restoring:
			(_choices["Exposure"]["Manual"] as CheckBox).button_pressed = true
		_apply_units())
	_defaults["EV100"] = 15.0
	var row := HBoxContainer.new()
	for label: String in EV_PRESETS:
		var button := Button.new()
		button.text = label
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", NOTE_SIZE)
		button.pressed.connect(func() -> void:
			(_choices["Exposure"]["Manual"] as CheckBox).button_pressed = true
			(_sliders["EV100"] as HSlider).value = float(EV_PRESETS[label]))
		row.add_child(button)
	column.add_child(row)
	_note(column, "Exposure value at ISO 100: each step up halves the light let in. The presets are exposures for light of that kind: noon sun 15, open shade 12, dusk 9, a well-lit room 5, this room's one 60 W bulb 2, moonlight -2. Used in other light they come out too dark or too bright, as a camera's would. Physical units only.")
	_slider(column, "Bulb (lm)", 100.0, 5000.0, 10.0, 800.0, func(_v: float) -> void: _apply_units())
	_defaults["Bulb (lm)"] = 800.0
	_note(column, "Physical units only: a 60 W incandescent bulb gives about 800 lumens, a 100 W about 1,500.")
	_choice(column, "Curve", ["Linear", "Reinhard", "Filmic", "ACES", "AgX"], func(option: String) -> void:
		_env.tonemap_mode = TONEMAPS[option])
	_slider(column, "White point", 1.0, 16.0, 0.1, 1.0, func(v: float) -> void: _env.tonemap_white = v)
	_defaults["White point"] = 1.0
	_note(column, "The tone curve maps light of any strength into what a screen shows. Linear cuts everything above white off flat; the others roll the highlights off gently, as film and the eye do. White point: the light that just reaches white (Linear ignores it).")
	return _panel_of(column)


## Every light's strength and the exposure for the units chosen.
func _apply_units() -> void:
	if not _metering:
		_ev_now = float((_sliders["EV100"] as HSlider).value)
	_expose()
	if _physical:
		var candela := float((_sliders["Bulb (lm)"] as HSlider).value) / (4.0 * PI)
		_bulb.omni_attenuation = 2.0
		_bulb.omni_range = 60.0
		_bulb.light_energy = candela * LUX
		# The glass's luminance: its candelas over its silhouette (an
		# ellipse 8 by 10 cm), as Godot radiance.
		_glass_mat.emission_energy_multiplier = candela / (PI * 0.04 * 0.05) * PI * LUX
	else:
		var level := float((_sliders["Bulb energy"] as HSlider).value)
		_bulb.omni_attenuation = 1.0
		_bulb.omni_range = 20.0
		_bulb.light_energy = level
		_glass_mat.emission_energy_multiplier = level
	if _bulb_box != null:
		_enable(_bulb_box, not _physical)
	_place_sun()


func _expose() -> void:
	_env.tonemap_exposure = 1.0 / (PI * LUX * 1.2 * pow(2.0, _ev_now)) if _physical else 1.0


## An incident light meter at the player's feet: the illuminance on
## level ground from the sun (through the air if that switch is on),
## the sky (a share of the sun's light above the air, 12% with the sun
## high, fading through twilight) and the bulb (its candelas by the
## inverse square and the cosine). The exposure is the standard
## incident-meter calibration, EV100 = log2(E / 2.5): 15 for noon sun,
## about 2 under this room's bulb.
func _meter_ev() -> float:
	var e := 0.0
	var at := player.global_position
	if _sun_model != "Off":
		var polar := float((_sliders["Polar angle"] as HSlider).value)
		var top := SUN_LUX * float((_sliders["Sun energy"] as HSlider).value)
		var through := 1.0
		if (_switches["Atmosphere dims and reddens the sun"] as CheckButton).button_pressed:
			var t := _air_transmittance(polar)
			through = 0.2126 * t.r + 0.7152 * t.g + 0.0722 * t.b
		e += top * through * maxf(cos(deg_to_rad(polar)), 0.0)
		if _outside == "Sky":
			e += top * 0.12 * clampf(sin(deg_to_rad(90.0 - polar)) + 0.1, 0.0003, 1.0)
	var to_bulb := _bulb.global_position - at
	var d2 := maxf(to_bulb.length_squared(), 0.01)
	var candela := float((_sliders["Bulb (lm)"] as HSlider).value) / (4.0 * PI)
	e += candela * maxf(to_bulb.y, 0.0) / sqrt(d2) / d2
	return clampf(log(maxf(e, 0.01) / 2.5) / log(2.0), -4.0, 17.0)


## The meter's reading reached gradually, as the eye adapts: about
## two thirds of the way in 0.8 s.
func _adapt(delta: float) -> void:
	if not (_physical and _metering):
		return
	var target := _meter_ev() + float((_sliders["Compensation (EV)"] as HSlider).value)
	_ev_now += (target - _ev_now) * (1.0 - exp(-delta / 0.8))
	_expose()
	var slider := _sliders["EV100"] as HSlider
	slider.set_value_no_signal(_ev_now)
	_show_slider("EV100", _ev_now)


## ---- the sound panel --------------------------------------------------------

const SOUND_ON: Array[String] = ["Radio playing (3)", "Knocks", "Swooshes", "Air absorption", "Over the wall", "Through the doorway", "Room reverb", "Echoes", "Doppler"]


func _build_sound(root: Control) -> Control:
	var column := _column(root)
	_sound_status = _note(column, "")
	_sound_status.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_choice(column, "Output", ["Speakers", "Headphones"], func(option: String) -> void: AudioOutput.set_mode(option))
	(_choices["Output"][AudioOutput.mode] as CheckBox).set_pressed_no_signal(true)
	if AudioOutput.mode != "Speakers":
		(_choices["Output"]["Speakers"] as CheckBox).set_pressed_no_signal(false)
	_slider(column, "Master volume (dB)", -24.0, 12.0, 0.5, AudioOutput.master_db, func(v: float) -> void: AudioOutput.set_master_db(v))
	_defaults["Master volume (dB)"] = 0.0
	_note(column, "For every world. Speakers: a gentle compressor and a limiter lift the level small speakers need, evening loudness far less than a laptop's own loudness equaliser does. Headphones: the full range of loudness, the stereo narrowed a little so sounds sit less inside your head.")
	_switch(column, "Radio playing (3)", func(on: bool) -> void:
		_radio.playing = on
		_acoustics.set_paused("radio", not on))
	_slider(column, "Volume (dB)", -30.0, 6.0, 0.5, -6.0, func(v: float) -> void: _acoustics.set_level("radio", v))
	_defaults["Volume (dB)"] = -6.0
	_note(column, "The director's recording, Levittown Levity, on a radio sitting on the ball.")
	_switch(column, "Swooshes", func(_on: bool) -> void: pass)
	_slider(column, "Swoosh level (dB)", -24.0, 12.0, 0.5, 0.0, func(_v: float) -> void: pass)
	_defaults["Swoosh level (dB)"] = 0.0
	_note(column, "Air rushing past the ball and the bulb, heard only when they move fast: its power grows as speed to the sixth times the frontal area, so twice as fast is 18 dB louder, and the bulb, being small, is near silent. A broad rush with no pitch, its upper edge rising with speed over size, fluttering as turbulence does.")
	_switch(column, "Knocks", func(_on: bool) -> void: pass)
	_note(column, "The ball striking the wall, loud as the speed it struck at: twice as fast, 6 dB louder. Raise the ball's hook speed under Motion to make it swing into the wall.")
	_heading(column, "How sound travels")
	_note(column, "These belong to the room and apply to every sound alike: the radio, the knocks, the swooshes and your footsteps.")
	_choice(column, "Spreading", ["1/d", "1/d²", "Log", "None"], func(option: String) -> void: _acoustics.spreading = option)
	_note(column, "1/d in amplitude is the physical law, -6 dB each time the distance doubles (Godot calls it inverse distance). Godot's inverse square is 1/d² in amplitude, -12 dB a doubling: too steep.")
	_switch(column, "Air absorption", func(on: bool) -> void: _acoustics.air = on)
	_note(column, "Air takes the treble with distance, about 0.1 dB a metre at 8 kHz: little across the room, a muffled tune from a far hill.")
	_switch(column, "Over the wall", func(on: bool) -> void: _acoustics.over_wall = on)
	_note(column, "With the wall between, sound bends over its top edge: quieter, and the treble most (Maekawa's barrier). Off: only what passes through the masonry, about -45 dB.")
	_switch(column, "Through the doorway", func(on: bool) -> void: _acoustics.doorway = on)
	_note(column, "With the wall between, the music also comes from the doorway, duller the more sharply its path bends there.")
	_switch(column, "Room reverb", func(on: bool) -> void: _acoustics.reverb = on)
	_note(column, "Sabine's reverberation time from the room's size and its floor and wall materials; the open top absorbs most, so it is short, as in a walled courtyard.")
	_switch(column, "Doppler", func(on: bool) -> void:
		_acoustics.doppler = on
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			cam.doppler_tracking = Camera3D.DOPPLER_TRACKING_PHYSICS_STEP if on else Camera3D.DOPPLER_TRACKING_DISABLED)
	_switch(column, "Echoes", func(on: bool) -> void: _acoustics.echoes = on)
	_note(column, "Footsteps and knocks come back off the wall, later the farther it is: about 87 ms from the middle of the room. The curved wall gathers its echo toward the middle like a mirror, so there it is loudest, arriving from all round at once. Outside, the wall's outer face spreads its echo thin.")
	_note(column, "The pitch rises as the radio swings toward you and falls as it swings away; a few hundredths of a semitone at these speeds.")
	for title in SOUND_ON:
		(_switches[title] as CheckButton).set_pressed_no_signal(true)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		cam.doppler_tracking = Camera3D.DOPPLER_TRACKING_PHYSICS_STEP
	return _panel_of(column)


## The room as it stands handed to the acoustics, which works out every
## source's paths for the ear (the camera) each frame.
func _hear(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if _acoustics == null or cam == null:
		return
	_acoustics.room_r = _room_r
	_acoustics.wall_h = _wall_h
	_acoustics.wall_t = WALL_T
	_acoustics.door_w = DOOR_W
	_acoustics.alpha_floor = float(LIBRARY[_library_index(str(_surf["Floor"]["material"]))].get("alpha", 0.02))
	_acoustics.alpha_wall = float(LIBRARY[_library_index(str(_surf["Walls"]["material"]))].get("alpha", 0.02))
	_acoustics.listen(cam.global_transform, player.global_position)
	_swoosh(delta)
	_underfoot()
	_sound_clock -= delta
	if _sound_clock <= 0.0:
		_sound_clock = 0.25
		_sound_status.text = _acoustics.status + " Radio " + _acoustics.source_note("radio") + "."


## ---- swooshes ---------------------------------------------------------------

## The rush of air past the ball and the bulb as they move. The noise is
## the turbulent wake's (dipole flow noise, after Curle): its power
## grows as speed^6 times frontal area, so its amplitude goes as U^3 D:
## level = 60 log10(U / 3 m/s) + 20 log10(D / 1 m) - 42 dB, plus the
## slider, never above -18 dB: the ball's rush about -36 dB at 3 m/s and
## -28 at 4; the bulb's some 28 dB under it. Under about 1.2 m/s it fades
## out. The noise is broadband, with no centre pitch: a gentle low-pass
## whose edge rises as (U / D)^0.45 (the Strouhal relation; the true
## shedding tone for bodies this size lies under 1 Hz), about 300 Hz for
## the ball at full swing, and a high-pass two and a half octaves under
## it. A band-pass in its place, narrow in hertz at these low pitches,
## turned the noise into a hum like a foghorn. The loudness flutters by
## about 3 dB at a few hertz, as turbulence does, so it never settles
## into a tone. Speed is the body's own through the air, the hook's
## motion included, eased over a tenth of a second. Each is a source in
## the scene's acoustics, carried by its body, its two filters its own.
var _swooshes: Array[Dictionary] = []
var _flutter := FastNoiseLite.new()
var _flutter_t := 0.0


func _build_swooshes() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stream := load("res://audio/swoosh_loop.wav") as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_flutter.frequency = 1.0
	var specs := [["swoosh_ball", _ball_swing, 2.0, _ball], ["swoosh_bulb", _bulb_swing, 0.08, _bulb]]
	for spec: Array in specs:
		var high := AudioEffectHighPassFilter.new()
		var low := AudioEffectLowPassFilter.new()
		_acoustics.add_source(str(spec[0]), spec[3] as Node3D, stream, [high, low])
		_acoustics.set_level(str(spec[0]), -80.0)
		_swooshes.append({"id": spec[0], "high": high, "low": low, "swing": spec[1], "size": float(spec[2]),
			"speed": 0.0, "seed": float(_swooshes.size()) * 97.0})


func _swoosh(delta: float) -> void:
	var on := (_switches["Swooshes"] as CheckButton).button_pressed
	var level := float((_sliders["Swoosh level (dB)"] as HSlider).value)
	_flutter_t += delta
	for sw: Dictionary in _swooshes:
		var u := (sw["swing"] as Pendulum).velocity().length() if not _still else 0.0
		var speed := lerpf(float(sw["speed"]), u, 1.0 - exp(-delta / 0.1))
		sw["speed"] = speed
		var size := float(sw["size"])
		var id := str(sw["id"])
		if not on or speed < 0.05:
			_acoustics.set_level(id, -80.0)
			continue
		var db := 60.0 * log(speed / 3.0) / log(10.0) + 20.0 * log(size) / log(10.0) - 42.0 + level
		db += 20.0 * log(maxf(smoothstep(0.8, 1.6, speed), 0.0001)) / log(10.0)
		db += 3.0 * _flutter.get_noise_1d(_flutter_t * 4.0 + float(sw["seed"]))
		_acoustics.set_level(id, clampf(db, -80.0, -18.0 + level))
		var edge := clampf(250.0 * pow(speed / size, 0.45), 120.0, 4000.0)
		(sw["low"] as AudioEffectLowPassFilter).cutoff_hz = edge
		(sw["low"] as AudioEffectLowPassFilter).resonance = 0.3
		(sw["high"] as AudioEffectHighPassFilter).cutoff_hz = edge / 6.0
		(sw["high"] as AudioEffectHighPassFilter).resonance = 0.3


## ---- the terrain panel -----------------------------------------------------

func _build_terrain(root: Control) -> Control:
	var column := _column(root)
	_slider(column, "Hill height (m)", 0.0, 150.0, 1.0, _terrain.height, func(v: float) -> void:
		_terrain.height = v
		_shape_ground())
	_note(column, "The highest hills; 0 is a level plain.")
	_slider(column, "Hill size (m)", 50.0, 1500.0, 10.0, _terrain.feature, func(v: float) -> void:
		_terrain.feature = v
		_shape_ground())
	_note(column, "The width of the largest hills. Each finer layer of noise is half the size of the one before.")
	_slider(column, "Ruggedness", 0.2, 0.8, 0.01, _terrain.roughness, func(v: float) -> void:
		_terrain.roughness = v
		_shape_ground())
	_note(column, "Each finer layer's height against the one before: low gives smooth downland, high rugged ground.")
	_slider(column, "Seed", 1.0, 100.0, 1.0, float(_terrain.noise_seed), func(v: float) -> void:
		_terrain.noise_seed = int(v)
		_shape_ground())
	_note(column, "A different seed, a different landscape from the same rules. The ground rebuilds when a slider comes to rest; it runs 1.5 km out.")
	for title: String in ["Hill height (m)", "Hill size (m)", "Ruggedness", "Seed"]:
		_defaults[title] = (_sliders[title] as HSlider).value
	return _panel_of(column)


## ---- the motion panel ------------------------------------------------------

func _build_motion(root: Control) -> Control:
	var column := _column(root)
	_switch(column, "Hold still", func(on: bool) -> void: _still = on)
	_note(column, "Stops both hooks where they are and lets the ball and bulb hang straight down, at rest.")
	_heading(column, "Room")
	_slider(column, "Room radius (m)", 5.0, 30.0, 0.5, _room_r, func(v: float) -> void: _set_room(v))
	(_sliders["Room radius (m)"] as HSlider).drag_ended.connect(func(_changed: bool) -> void:
		if _bounce == "VoxelGI":
			_set_voxel_gi(true))
	_note(column, "Floor and wall rebuilt as you drag; the hooks' paths scale with it. A VoxelGI box is baked again when you let go.")
	_slider(column, "Wall height (m)", 0.0, 36.0, 0.1, _wall_h, func(v: float) -> void:
		_wall_h = v
		_shape_wall())
	(_sliders["Wall height (m)"] as HSlider).drag_ended.connect(func(_changed: bool) -> void:
		if _bounce == "VoxelGI":
			_set_voxel_gi(true))
	_note(column, "0 is no wall at all; 3.6 m as built, up to ten times that. Above the hooks (12 m) the ropes rise inside it. Light, the knocks and the radio's sound all follow the wall's height.")
	_heading(column, "Ball's hook")
	_slider(column, "Ball rope length (m)", 1.0, HOOK_Y - 1.3, 0.1, _ball_swing.length, func(v: float) -> void: _ball_swing.set_length(v))
	_slider(column, "Ball speed", 0.2, 3.0, 0.05, _ball_swing.speed, func(v: float) -> void: _ball_swing.speed = v)
	_slider(column, "Ball wait", 0.0, 10.0, 0.1, _ball_swing.wait, func(v: float) -> void: _ball_swing.wait = v)
	_heading(column, "Bulb's hook")
	_slider(column, "Bulb cord length (m)", 0.5, HOOK_Y - 0.3, 0.1, _bulb_swing.length, func(v: float) -> void: _bulb_swing.set_length(v))
	_slider(column, "Bulb speed", 0.2, 3.0, 0.05, _bulb_swing.speed, func(v: float) -> void: _bulb_swing.speed = v)
	_slider(column, "Bulb wait", 0.0, 10.0, 0.1, _bulb_swing.wait, func(v: float) -> void: _bulb_swing.wait = v)
	_note(column, "Speed is the hook's average along an edge, in m/s; wait is the pause at each corner, in seconds. The hooks run 12 m up; a shorter rope lifts its weight. A rope's swing takes 2 pi root(L / g): 2.8 s at 2 m, 6.6 s at 10.7 m. A hook whose stops and starts fall in step with that swings its weight higher and higher, until the ball strikes the wall.")
	_heading(column, "Knocks")
	_slider(column, "Restitution", 0.0, 1.0, 0.01, _restitution, func(v: float) -> void: _restitution = v)
	_note(column, "The share of the closing speed kept after a knock, against the wall or between ball and bulb: 1 bounces back as fast as it came, 0 stops dead.")
	for title: String in ["Ball speed", "Ball wait", "Bulb speed", "Bulb wait", "Restitution",
			"Room radius (m)", "Wall height (m)", "Ball rope length (m)", "Bulb cord length (m)"]:
		_defaults[title] = (_sliders[title] as HSlider).value
	return _panel_of(column)


func _physics_process(delta: float) -> void:
	_step_swing(delta)
	if player.global_position.y < -30.0:
		player.global_position = START
		player.velocity = Vector3.ZERO
