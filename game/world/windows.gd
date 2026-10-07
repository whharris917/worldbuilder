class_name WindowsWorld
extends Node3D
## Windows: a gothic cathedral on open grass under One Bulb's Atmosphere
## sky and its sun, for studying how sunlight comes in through windows.
## The windows are plain openings, no glass. Godot's default shading; no
## WorldBase.
##
## The cathedral, at the size of the great French cathedrals (Chartres:
## 130 m long, a nave 16 m wide and 37 m to the vault), facing east: a
## nave 16 m wide inside under a pointed vault 42 m up, with aisles 8 m
## wide either side 14 m high under lean-to roofs, opening onto the nave
## through eight pointed arches a side; a transept crossing it 62 m end
## to end; a choir running on east to a round apse; two towers 62 m high
## with spires to 98 m flanking the west front, set back between them, a
## doorway 12 m high and a rose window above. Windows: a pointed lancet in
## each aisle bay, a tall clerestory lancet above each arcade arch, tall
## lancets down the choir and round the apse, a rose and three lancets in
## each transept end. Built with Godot's CSG (solids joined, the interior
## and every opening cut out), solid to walk in and on, all in one
## limestone: ambientCG's old stone bricks, laid triplanar in world space,
## its blocks about 0.6 m by 0.3 m. Floors of paving stones inside.
##
## Lengths in metres, x east along the axis (the west front at x 0), z
## south, y up. The player starts inside at the nave's west end, facing
## east up the nave.
##
## Panels (BenchPanel; Esc frees the mouse), kept in user://windows.json:
## Sun and Sky as in Movement (One Bulb's: the sun's polar angle and its
## azimuth from north, its energy, whether the atmosphere dims and reddens it, the shadow
## distance; the air's density, haze, ozone and haze forward); Light: the
## bounce (None or SDFGI; SDFGI to begin, which also shades the inside
## from the sky), the haze in the air (Godot's volumetric fog, lit by the
## sun alone, which shows the beams), its thickness, and the exposure.
## The bounce is traced at half the screen's resolution, an engine-wide
## setting put back on leaving.

const START := Vector3(10.0, 0.05, 0.0)
const STATE_PATH := "user://windows.json"
const NAVE_HALF := 8.0                  # inside
const WALL := 1.5
const AISLE_OUT := 19.0                 # the aisles' outer face, from the axis
const NAVE_END := 120.0                 # the apse's centre
const CROSS := Vector2(70.0, 86.0)      # the crossing, x from and to
const TRANSEPT_HALF := 30.0             # inside, from the axis
const SPRING := 28.0                    # where the nave's vault springs
const NAVE_TOP := 44.0                  # the nave's walls' top, under the roof
const AISLE_TOP := 15.0
const BAYS := 8

# The atmosphere as atmosphere_sky.gdshader has it, for the sunlight that
# reaches the ground: per metre for red, green and blue.
const R_EARTH := 6360e3
const R_AIR := 6460e3
const RAYLEIGH := Vector3(5.802e-6, 13.558e-6, 33.1e-6)
const H_RAYLEIGH := 8000.0
const MIE_EXTINCT := 4.40e-6
const H_MIE := 1200.0
const OZONE := Vector3(0.650e-6, 1.881e-6, 0.085e-6)
const SKY_PARAMS := {"Air density": "rayleigh_scale", "Haze": "mie_scale", "Ozone": "ozone_scale",
	"Haze forward": "mie_g"}

var player: Player
var _panel: BenchPanel
var _sun: DirectionalLight3D
var _sky_mat: ShaderMaterial
var _env: Environment
var _stone: StandardMaterial3D
var _csg: CSGCombiner3D
var _debanding_was := false
var _half_was := false


func _ready() -> void:
	player = $Player as Player
	player.global_position = START
	player.rotation.y = -PI / 2.0
	var vp := get_viewport()
	_debanding_was = vp.use_debanding
	vp.use_debanding = true
	_half_was = ProjectSettings.get_setting("rendering/global_illumination/gi/use_half_resolution", false)
	RenderingServer.gi_set_use_half_resolution(true)
	_build_sky()
	_build_sun()
	_build_ground()
	_build_cathedral()
	_build_floors()
	_build_panel()
	_panel.restore()
	_apply_panel()
	_place_sun()
	MouseMode.capture()
	if DisplayServer.get_name() == "headless":
		print("[worldbuilder] windows: a cathedral %d m long, %d CSG pieces" % [int(NAVE_END + 9.5 + 12.0), _csg.get_child_count()])


func _exit_tree() -> void:
	get_viewport().use_debanding = _debanding_was
	RenderingServer.gi_set_use_half_resolution(_half_was)


## ---- sky and sun -------------------------------------------------------------

func _build_sky() -> void:
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://world/atmosphere_sky.gdshader") as Shader
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	# SDFGI's smallest cell off the whole metres the building lies on
	# (faces exactly on cell boundaries gave no bounce in another room),
	# and as coarse as looks the same here: on the laptop 6 cascades of
	# 0.27 m cost about 60 ms a frame, 4 of 0.4 m at half resolution 44.
	_env.sdfgi_min_cell_size = 0.4
	_env.sdfgi_cascades = 4
	_env.volumetric_fog_albedo = Color(0.9, 0.92, 0.95)
	_env.volumetric_fog_anisotropy = 0.6
	_env.volumetric_fog_length = 160.0
	_env.volumetric_fog_ambient_inject = 0.0
	_env.volumetric_fog_sky_affect = 0.0
	_env.glow_enabled = true
	_env.glow_intensity = 0.4
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)


## The sun infinitely far: a directional light, every ray parallel. It
## lights the scene only; the sky draws its own sun from the same direction.
func _build_sun() -> void:
	_sun = DirectionalLight3D.new()
	_sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_sun.shadow_enabled = true
	add_child(_sun)


func _build_panel() -> void:
	_panel = BenchPanel.new(STATE_PATH)
	add_child(_panel)
	var sun := _panel.panel("Sun")
	var place := func(_v: Variant) -> void: _place_sun()
	_panel.slider(sun, "Polar angle", 0.0, 180.0, 1.0, 50.0, place)
	_panel.note(sun, "From straight up: 0 overhead, 90 on the horizon, beyond 90 below it.")
	_panel.slider(sun, "Azimuth", 0.0, 360.0, 1.0, 150.0, place)
	_panel.note(sun, "Round the horizon from north: 90 east, behind the altar; 180 south, the cathedral's right side as you look up the nave; 270 west, behind the doors.")
	_panel.slider(sun, "Sun energy", 0.0, 4.0, 0.01, 1.0, place)
	_panel.note(sun, "Light on a surface facing the sun, above the air.")
	_panel.switch(sun, "Atmosphere dims and reddens the sun", true, place)
	_panel.note(sun, "The beam loses light on its way through the atmosphere, worked out from the Sky panel's air, haze and ozone, as the sky is: overhead the sun keeps most of its light; low, it turns orange and red and fades; set, it gives none.")
	_panel.slider(sun, "Shadow distance (m)", 50.0, 600.0, 10.0, 250.0, func(v: float) -> void:
		_sun.directional_shadow_max_distance = v)
	_panel.note(sun, "Shadows are drawn only this far from you; the cathedral is 140 m long. Farther costs more time a frame and blurs the shadows near you, which share one shadow map.")

	var sky := _panel.panel("Sky")
	for spec: Array in [["Air density", 0.0, 20.0, 0.01, 1.0], ["Haze", 0.0, 100.0, 0.1, 1.0],
			["Ozone", 0.0, 20.0, 0.01, 1.0], ["Haze forward", 0.0, 0.95, 0.01, 0.8]]:
		var param := str(SKY_PARAMS[spec[0]])
		_panel.slider(sky, str(spec[0]), float(spec[1]), float(spec[2]), float(spec[3]), float(spec[4]),
			func(v: float) -> void:
				_sky_mat.set_shader_parameter(param, v)
				_place_sun())
	_panel.note(sky, "Each against Earth's on a clear day, which is 1. Air density: the gas itself, which scatters blue most. Haze: dust and droplets low down, which scatter all colours alike. Ozone: a layer high up that takes out orange and yellow. Haze forward: how much of the haze's light goes on in the sun's direction.")
	_panel.button(sky, "Back to Earth", func() -> void:
		for title: String in ["Air density", "Haze", "Ozone"]:
			(_panel.sliders[title] as HSlider).value = 1.0
		(_panel.sliders["Haze forward"] as HSlider).value = 0.8)

	var light := _panel.panel("Light")
	_panel.choice(light, "Bounce", ["None", "SDFGI"], "SDFGI", func(o: String) -> void:
		_env.sdfgi_enabled = o == "SDFGI")
	_panel.note(light, "None: inside, only the sunlight through the windows and the sky's light, which Godot then lets in everywhere as if the roof were not there. SDFGI: the sky's light only through the openings, and the sunlight bouncing off the floor and walls into the rest of the church.")
	_panel.switch(light, "Haze in the air", true, func(on: bool) -> void: _env.volumetric_fog_enabled = on)
	_panel.slider(light, "Haze thickness", 0.0, 0.05, 0.0005, 0.006, func(v: float) -> void:
		_env.volumetric_fog_density = v)
	_panel.note(light, "Godot's volumetric fog, lit by the sun alone, so the beams through the windows show in the air as they do in dust or incense.")
	_panel.slider(light, "Exposure", 0.1, 8.0, 0.05, 1.0, func(v: float) -> void:
		_env.tonemap_exposure = v)
	_panel.note(light, "How bright the picture is made. Inside, out of the beams, a church is far darker than the day outside; raise this to see into the shade.")


## Every setting the panels hold, applied: a control's own callback runs
## only when it changes, so its starting value is applied here.
func _apply_panel() -> void:
	_env.sdfgi_enabled = (_panel.choices["Bounce"]["SDFGI"] as CheckBox).button_pressed
	_env.volumetric_fog_enabled = (_panel.switches["Haze in the air"] as CheckButton).button_pressed
	_env.volumetric_fog_density = float((_panel.sliders["Haze thickness"] as HSlider).value)
	_env.tonemap_exposure = float((_panel.sliders["Exposure"] as HSlider).value)
	_sun.directional_shadow_max_distance = float((_panel.sliders["Shadow distance (m)"] as HSlider).value)
	for title: String in SKY_PARAMS:
		_sky_mat.set_shader_parameter(str(SKY_PARAMS[title]), float((_panel.sliders[title] as HSlider).value))


## Unit vector toward the sun: azimuth from north (-z) through east (+x).
func _sun_dir() -> Vector3:
	var polar := deg_to_rad(float((_panel.sliders["Polar angle"] as HSlider).value))
	var azimuth := deg_to_rad(float((_panel.sliders["Azimuth"] as HSlider).value))
	return Vector3(sin(polar) * sin(azimuth), cos(polar), -sin(polar) * cos(azimuth))


## The light and the sky from the panel, as Movement places them.
func _place_sun() -> void:
	var dir := _sun_dir()
	var up := Vector3.FORWARD if absf(dir.y) > 0.999 else Vector3.UP
	_sun.basis = Basis.looking_at(-dir, up)
	var energy := float((_panel.sliders["Sun energy"] as HSlider).value)
	_sky_mat.set_shader_parameter("sun_dir", dir)
	_sky_mat.set_shader_parameter("sun_illuminance", energy)
	var through := Color(1, 1, 1)
	if (_panel.switches["Atmosphere dims and reddens the sun"] as CheckButton).button_pressed:
		through = _transmittance(dir)
	var lum := 0.2126 * through.r + 0.7152 * through.g + 0.0722 * through.b
	var top := maxf(maxf(through.r, through.g), maxf(through.b, 1e-6))
	var hue := Color(through.r / top, through.g / top, through.b / top)
	_sun.light_color = hue.linear_to_srgb() if lum > 0.0 else Color.WHITE
	_sun.light_energy = energy * lum


## The share of the sun's light that crosses the air to the ground, by the
## sky's own model, as Movement works it out.
func _transmittance(dir: Vector3) -> Color:
	var from := Vector3(0.0, R_EARTH + 2.0, 0.0)
	var b := from.dot(dir)
	var c := from.length_squared() - R_EARTH * R_EARTH
	if b < 0.0 and b * b - c > 0.0:
		return Color(0, 0, 0)
	var length := -b + sqrt(b * b - (from.length_squared() - R_AIR * R_AIR))
	var air := float((_panel.sliders["Air density"] as HSlider).value)
	var haze := float((_panel.sliders["Haze"] as HSlider).value)
	var ozone := float((_panel.sliders["Ozone"] as HSlider).value)
	var steps := 64
	var dl := length / steps
	var depth := Vector3.ZERO
	for i in steps:
		var h := (from + dir * dl * (i + 0.5)).length() - R_EARTH
		depth += (RAYLEIGH * air * exp(-h / H_RAYLEIGH) + Vector3.ONE * MIE_EXTINCT * haze * exp(-h / H_MIE)
			+ OZONE * ozone * maxf(0.0, 1.0 - absf(h - 25000.0) / 15000.0)) * dl
	return Color(exp(-depth.x), exp(-depth.y), exp(-depth.z))


## ---- the ground ------------------------------------------------------------------

## Flat grass 2 km square, One Bulb's grass laid without its repeat showing.
func _build_ground() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://world/ground_tex.gdshader") as Shader
	for pair: Array in [["albedo_tex", "use_albedo", "albedo"], ["normal_tex", "use_normal", "normal"],
			["ao_tex", "use_ao", "ao"]]:
		mat.set_shader_parameter(str(pair[0]), load("res://textures/grass/%s.jpg" % pair[2]) as Texture2D)
		mat.set_shader_parameter(str(pair[1]), true)
	mat.set_shader_parameter("tile_m", Vector2(5.6, 5.6))
	mat.set_shader_parameter("normal_strength", 2.0)
	mat.set_shader_parameter("roughness_scale", 1.8)
	mat.set_shader_parameter("specular", 0.2)
	var plane := PlaneMesh.new()
	plane.size = Vector2(2000.0, 2000.0)
	plane.material = mat
	var view := MeshInstance3D.new()
	view.mesh = plane
	view.position = Vector3(60.0, 0.0, 0.0)
	add_child(view)
	_slab(Vector3(60.0, -0.5, 0.0), Vector3(2000.0, 1.0, 2000.0), null)


## A texture set laid triplanar in world space, `size` metres to a repeat.
func _textured(dir: String, size: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var base := "res://textures/%s/" % dir
	m.albedo_texture = load(base + "albedo.jpg") as Texture2D
	m.normal_enabled = true
	m.normal_texture = load(base + "normal.jpg") as Texture2D
	m.roughness_texture = load(base + "roughness.jpg") as Texture2D
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.ao_enabled = true
	m.ao_texture = load(base + "ao.jpg") as Texture2D
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / size
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## A box, drawn (when given a material) and solid.
func _slab(centre: Vector3, size: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = centre
	add_child(body)
	if mat != null:
		var box := BoxMesh.new()
		box.size = size
		box.material = mat
		var view := MeshInstance3D.new()
		view.mesh = box
		body.add_child(view)
	var shape := BoxShape3D.new()
	shape.size = size
	var collide := CollisionShape3D.new()
	collide.shape = shape
	body.add_child(collide)


## Paving inside, a hair over the ground, under the walls' feet.
func _build_floors() -> void:
	var paving := _textured("paving_stones", 2.0)
	var t := 0.04
	_slab(Vector3((2.0 + CROSS.x) * 0.5, t * 0.5, 0.0), Vector3(CROSS.x - 2.0, t, 2.0 * (AISLE_OUT - WALL)), paving)
	_slab(Vector3((CROSS.x + CROSS.y) * 0.5, t * 0.5, 0.0), Vector3(CROSS.y - CROSS.x, t, 2.0 * TRANSEPT_HALF), paving)
	_slab(Vector3((CROSS.y + NAVE_END) * 0.5, t * 0.5, 0.0), Vector3(NAVE_END - CROSS.y, t, 2.0 * NAVE_HALF), paving)
	_slab(Vector3(1.0, t * 0.5, 0.0), Vector3(2.0, t, 6.0), paving)
	var apse := CylinderMesh.new()
	apse.top_radius = NAVE_HALF
	apse.bottom_radius = NAVE_HALF
	apse.height = t
	apse.radial_segments = 48
	apse.material = paving
	var view := MeshInstance3D.new()
	view.mesh = apse
	view.position = Vector3(NAVE_END, t * 0.5, 0.0)
	add_child(view)


## ---- the cathedral ---------------------------------------------------------------

## One CSG tree: the solids joined, then the interior and every opening
## cut out of them, in that order (each child acts on what the ones before
## it made).
func _build_cathedral() -> void:
	_stone = _textured("old_stone_bricks", 1.8)
	_csg = CSGCombiner3D.new()
	_csg.use_collision = true
	add_child(_csg)
	var h := NAVE_HALF + WALL

	# Solids.
	_box(Vector3(0.0, 0.0, -h), Vector3(NAVE_END, NAVE_TOP, h), false)
	_box(Vector3(0.0, 0.0, -AISLE_OUT), Vector3(CROSS.x, AISLE_TOP, AISLE_OUT), false)
	_box(Vector3(CROSS.x - 2.0, 0.0, -TRANSEPT_HALF - 2.0), Vector3(CROSS.y + 2.0, NAVE_TOP, TRANSEPT_HALF + 2.0), false)
	_cylinder(Vector3(NAVE_END, NAVE_TOP * 0.5, 0.0), h, NAVE_TOP, false)
	for side: float in [-1.0, 1.0]:
		var z0 := side * (NAVE_HALF - 1.0)
		var z1 := side * AISLE_OUT
		_box(Vector3(-12.0, 0.0, minf(z0, z1)), Vector3(0.0, 62.0, maxf(z0, z1)), false)
		var spire := CSGCylinder3D.new()
		spire.cone = true
		spire.radius = 7.0
		spire.height = 36.0
		spire.sides = 8
		spire.material = _stone
		spire.position = Vector3(-6.0, 62.0 + 18.0, (z0 + z1) * 0.5)
		_csg.add_child(spire)
		# The aisle's lean-to roof, from the nave wall down to the outer wall.
		_prism_x(PackedVector2Array([Vector2(side * h, AISLE_TOP), Vector2(side * (AISLE_OUT + 0.3), AISLE_TOP),
			Vector2(side * h, AISLE_TOP + 4.5)]), 0.0, CROSS.x)
	# Gabled roofs over the nave and choir and the transept, a cone over the apse.
	_prism_x(PackedVector2Array([Vector2(-h - 0.4, NAVE_TOP), Vector2(h + 0.4, NAVE_TOP), Vector2(0.0, NAVE_TOP + 15.0)]),
		0.0, NAVE_END)
	_prism_z(PackedVector2Array([Vector2(CROSS.x - 2.4, NAVE_TOP), Vector2(CROSS.y + 2.4, NAVE_TOP),
		Vector2((CROSS.x + CROSS.y) * 0.5, NAVE_TOP + 15.0)]), -TRANSEPT_HALF - 2.4, TRANSEPT_HALF + 2.4)
	var roof := CSGCylinder3D.new()
	roof.cone = true
	roof.radius = h + 0.4
	roof.height = 15.0
	roof.sides = 32
	roof.material = _stone
	roof.position = Vector3(NAVE_END, NAVE_TOP + 7.5, 0.0)
	_csg.add_child(roof)

	# The inside: the nave and choir and the transept, each a box under a
	# pointed vault; the apse; the aisles, flat-ceiled.
	_vaulted(Vector3(2.0, 0.0, 0.0), NAVE_END - 2.0, true)
	_vaulted(Vector3((CROSS.x + CROSS.y) * 0.5, 0.0, -TRANSEPT_HALF), 2.0 * TRANSEPT_HALF, false)
	_cylinder(Vector3(NAVE_END, SPRING * 0.5, 0.0), NAVE_HALF, SPRING, true)
	var dome := CSGSphere3D.new()
	dome.radius = NAVE_HALF
	dome.radial_segments = 48
	dome.rings = 24
	dome.operation = CSGShape3D.OPERATION_SUBTRACTION
	dome.material = _stone
	dome.position = Vector3(NAVE_END, SPRING, 0.0)
	_csg.add_child(dome)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(2.0, 0.0, minf(side * h, side * (AISLE_OUT - WALL))), Vector3(CROSS.x,
			AISLE_TOP - 1.0, maxf(side * h, side * (AISLE_OUT - WALL))), true)

	# Openings.
	var bay := (CROSS.x - 2.0 - 4.0) / BAYS
	for i in BAYS:
		var x := 2.0 + 2.0 + bay * (i + 0.5)
		for side: float in [-1.0, 1.0]:
			var out := Vector3(0.0, 0.0, side)
			_lancet(Vector3(x, 0.0, side * (NAVE_HALF + WALL * 0.5)), out, 6.0, 14.0)            # arcade
			_lancet(Vector3(x, AISLE_TOP + 6.0, side * (NAVE_HALF + WALL * 0.5)), out, 4.0, 13.0)  # clerestory
			_lancet(Vector3(x, 3.0, side * (AISLE_OUT - WALL * 0.5)), out, 3.0, 9.0)             # aisle
	for x: float in [91.0, 99.0, 107.0, 114.0]:
		for side: float in [-1.0, 1.0]:
			_lancet(Vector3(x, 6.0, side * (NAVE_HALF + WALL * 0.5)), Vector3(0.0, 0.0, side), 3.5, 28.0)
	for k in 5:
		var a := deg_to_rad(-60.0 + 30.0 * k)
		var n := Vector3(cos(a), 0.0, sin(a))
		_lancet(Vector3(NAVE_END, 6.0, 0.0) + n * (NAVE_HALF + WALL * 0.5), n, 2.5, 24.0)
	# The west front: the doorway and the rose.
	_lancet(Vector3(1.0, 0.0, 0.0), Vector3.LEFT, 6.0, 12.0)
	_rose(Vector3(1.0, 27.0, 0.0), Vector3.LEFT)
	# The transept's ends and their west and east walls.
	var mid := (CROSS.x + CROSS.y) * 0.5
	for side: float in [-1.0, 1.0]:
		var end := Vector3(mid, 0.0, side * (TRANSEPT_HALF + 1.0))
		var out := Vector3(0.0, 0.0, side)
		_rose(end + Vector3(0.0, 28.0, 0.0), out)
		for dx: float in [-4.5, 0.0, 4.5]:
			_lancet(end + Vector3(dx, 5.0, 0.0), out, 2.5, 13.0)
		for dz: float in [23.0, 27.0]:
			_lancet(Vector3(CROSS.x - 1.0, 8.0, side * dz), Vector3.LEFT, 2.5, 24.0)
			_lancet(Vector3(CROSS.y + 1.0, 8.0, side * dz), Vector3.RIGHT, 2.5, 24.0)


## A box from corner lo to corner hi, joined or cut out.
func _box(lo: Vector3, hi: Vector3, cut: bool) -> void:
	var box := CSGBox3D.new()
	box.size = hi - lo
	box.position = (lo + hi) * 0.5
	box.material = _stone
	if cut:
		box.operation = CSGShape3D.OPERATION_SUBTRACTION
	_csg.add_child(box)


## An upright cylinder, centred at `centre`, joined or cut out.
func _cylinder(centre: Vector3, radius: float, height: float, cut: bool) -> void:
	var c := CSGCylinder3D.new()
	c.radius = radius
	c.height = height
	c.sides = 48
	c.position = centre
	c.material = _stone
	if cut:
		c.operation = CSGShape3D.OPERATION_SUBTRACTION
	_csg.add_child(c)


## An outline across the axis (across in z, up in y) run along x from x0
## to x1, joined.
func _prism_x(outline: PackedVector2Array, x0: float, x1: float) -> void:
	var p := CSGPolygon3D.new()
	p.polygon = _anticlockwise(outline)
	p.depth = x1 - x0
	p.material = _stone
	# Local x along world z, y up, z along world -x: the extrusion, along
	# local -z, runs east from x0.
	p.transform = Transform3D(Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0)), Vector3(x0, 0.0, 0.0))
	_csg.add_child(p)


## An outline (across in x, up in y) run along z from z1 down to z0, joined.
func _prism_z(outline: PackedVector2Array, z0: float, z1: float) -> void:
	var p := CSGPolygon3D.new()
	p.polygon = _anticlockwise(outline)
	p.depth = z1 - z0
	p.material = _stone
	p.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, z1))
	_csg.add_child(p)


func _anticlockwise(points: PackedVector2Array) -> PackedVector2Array:
	var area := 0.0
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		area += a.x * b.y - b.x * a.y
	if area < 0.0:
		points.reverse()
	return points


## A space 16 m wide under a pointed vault, cut out: a box to the
## springing and, above it, the lens two cylinders make where they
## overlap, each of radius the span and centred on the opposite
## springing (an equilateral pointed arch, its crown 13.9 m over the
## springing). Along x from `start` if `along_x`, else along z.
func _vaulted(start: Vector3, length: float, along_x: bool) -> void:
	var space := CSGCombiner3D.new()
	space.operation = CSGShape3D.OPERATION_SUBTRACTION
	_csg.add_child(space)
	var span := 2.0 * NAVE_HALF
	var box := CSGBox3D.new()
	box.material = _stone
	if along_x:
		box.size = Vector3(length, SPRING, span)
		box.position = start + Vector3(length * 0.5, SPRING * 0.5, 0.0)
	else:
		box.size = Vector3(span, SPRING, length)
		box.position = start + Vector3(0.0, SPRING * 0.5, length * 0.5)
	space.add_child(box)
	var lens := CSGCombiner3D.new()
	space.add_child(lens)
	for k in 2:
		var c := CSGCylinder3D.new()
		c.radius = span
		c.height = length
		c.sides = 96
		c.material = _stone
		var offset := NAVE_HALF * (1.0 if k == 0 else -1.0)
		if along_x:
			c.rotation_degrees.z = 90.0
			c.position = start + Vector3(length * 0.5, SPRING, offset)
		else:
			c.rotation_degrees.x = 90.0
			c.position = start + Vector3(offset, SPRING, length * 0.5)
		if k == 1:
			c.operation = CSGShape3D.OPERATION_INTERSECTION
		lens.add_child(c)


## A pointed lancet opening `w` wide and `h` tall, its sill's middle at
## `at` on the wall's middle plane, cut through a wall whose outward
## facing is `out`.
func _lancet(at: Vector3, out: Vector3, w: float, h: float) -> void:
	var rise := w * sin(PI / 3.0)
	var spring := maxf(h - rise, 0.0)
	var outline := PackedVector2Array([Vector2(-w * 0.5, 0.0), Vector2(w * 0.5, 0.0)])
	var steps := 10
	for i in steps + 1:
		var t := PI / 3.0 * i / steps
		outline.append(Vector2(-w * 0.5 + w * cos(t), spring + w * sin(t)))
	for i in range(1, steps + 1):
		var t := PI / 3.0 * (steps - i) / steps
		outline.append(Vector2(w * 0.5 - w * cos(t), spring + w * sin(t)))
	var p := CSGPolygon3D.new()
	p.polygon = _anticlockwise(outline)
	p.depth = WALL + 2.0
	p.operation = CSGShape3D.OPERATION_SUBTRACTION
	p.material = _stone
	var x := Vector3.UP.cross(out).normalized()
	p.transform = Transform3D(Basis(x, Vector3.UP, out), at + out * (p.depth * 0.5))
	_csg.add_child(p)


## A rose window cut through a wall: a round light 3 m across in the
## middle and twelve 2.8 m across round it, 4.6 m out.
func _rose(centre: Vector3, out: Vector3) -> void:
	var x := Vector3.UP.cross(out).normalized()
	for k in 13:
		var c := CSGCylinder3D.new()
		c.radius = 3.0 if k == 0 else 1.4
		c.height = WALL + 2.0
		c.sides = 32
		c.operation = CSGShape3D.OPERATION_SUBTRACTION
		c.material = _stone
		var at := centre
		if k > 0:
			var a := TAU * (k - 1) / 12.0
			at += (x * cos(a) + Vector3.UP * sin(a)) * 4.6
		c.transform = Transform3D(Basis(x, out, x.cross(out)), at)
		_csg.add_child(c)
