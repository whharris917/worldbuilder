class_name ShiftingRoom
extends Node3D
## The Shifting Room: a cube 24 m every way, plain matte grey inside, no
## textures, and in its middle a floating platform 3 m square where the
## player stands, its top 12 m up. The one light is a bare bulb 1 m under
## the platform (an omni light, inverse square, with shadows), so the room
## is lit from below the player's feet: the floor and the lower walls
## brightest, and the platform's shadow over the ceiling and the tops of
## the walls. Godot's default shading; no WorldBase.
##
## Off the platform's edge the fall is caught 6 m down: the screen fades to
## black and the player is put back on the platform.
##
## One panel (BenchPanel; Esc frees the mouse), kept in
## user://shifting_room.json: the bulb's energy, and the bounce method:
## None; SDFGI, the default, smallest cell 0.15 m, since the room's faces
## lie on 0.2 m multiples where SDFGI's default gave no bounce in another
## room; or VoxelGI, a box round the room baked when chosen, which gives
## no bounce at all from a light falling off with the square of the
## distance, as this bulb's does.

const ROOM := 24.0
const WALL := 0.5
const PLATFORM := Vector3(3.0, 0.2, 3.0)
const PLATFORM_TOP := 12.0
const BULB := Vector3(0.0, PLATFORM_TOP - 0.2 - 1.0, 0.0)
const START := Vector3(0.0, PLATFORM_TOP, 0.6)
const FALL_LIMIT := 6.0                 # m below the platform's top: put back
const STATE_PATH := "user://shifting_room.json"

var player: Player
var _panel: BenchPanel
var _env: Environment
var _bulb: OmniLight3D
var _bulb_glass: StandardMaterial3D
var _voxel_gi: VoxelGI
var _fade: ColorRect
var _falling := -1.0                    # s since the fade out began; below 0, none
var _built := false


func _ready() -> void:
	player = $Player as Player
	player.global_position = START
	for node in player.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	_build_environment()
	_build_room()
	_build_platform()
	_build_bulb()
	_build_fade()
	_build_panel()
	_panel.restore()
	_built = true
	_set_bounce(_picked("Bounce"))
	MouseMode.capture()
	if DisplayServer.get_name() == "headless":
		print("[worldbuilder] shifting room: a cube %d m, the platform's top %d m up" % [int(ROOM), int(PLATFORM_TOP)])


func _build_panel() -> void:
	_panel = BenchPanel.new(STATE_PATH)
	add_child(_panel)
	var light := _panel.panel("Light")
	_panel.slider(light, "Bulb energy", 0.0, 600.0, 1.0, 150.0, func(v: float) -> void:
		_bulb.light_energy = v
		_bulb_glass.emission_energy_multiplier = 40.0 * v / 150.0)
	_panel.note(light, "The bare bulb under the platform, the room's only light. Its light falls off with the square of the distance.")
	_panel.choice(light, "Bounce", ["None", "SDFGI", "VoxelGI"], "SDFGI", func(o: String) -> void:
		if _built:
			_set_bounce(o))
	_panel.note(light, "Light reflected off the walls, which is all that reaches the top of the platform and the ceiling in its shadow. None: those are black. SDFGI: cells round wherever you stand, made as you move. VoxelGI: a box round the room divided into cells, made once when chosen (the screen pauses); it takes no light from a bulb whose light falls off with the square of the distance, as this one's does, so here it gives none.")


func _picked(title: String) -> String:
	var boxes := _panel.choices[title] as Dictionary
	for option: String in boxes:
		if (boxes[option] as CheckBox).button_pressed:
			return option
	return ""


## A black void outside; no ambient light, so every bit of light in the
## room comes from the bulb, directly or by the bounce.
func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0, 0, 0)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	_env.glow_enabled = true
	_env.glow_intensity = 0.4
	_env.sdfgi_min_cell_size = 0.15
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)


## Six slabs, plain matte grey inside.
func _build_room() -> void:
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.6, 0.6, 0.6)
	grey.roughness = 0.9
	var h := ROOM * 0.5
	_slab_between(Vector3(-h - WALL, -WALL, -h - WALL), Vector3(h + WALL, 0.0, h + WALL), grey)
	_slab_between(Vector3(-h - WALL, ROOM, -h - WALL), Vector3(h + WALL, ROOM + WALL, h + WALL), grey)
	_slab_between(Vector3(h, 0.0, -h), Vector3(h + WALL, ROOM, h), grey)
	_slab_between(Vector3(-h - WALL, 0.0, -h), Vector3(-h, ROOM, h), grey)
	_slab_between(Vector3(-h - WALL, 0.0, h), Vector3(h + WALL, ROOM, h + WALL), grey)
	_slab_between(Vector3(-h - WALL, 0.0, -h - WALL), Vector3(h + WALL, ROOM, -h), grey)


## The platform, plain darker grey, held up by nothing.
func _build_platform() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.3, 0.3, 0.3)
	dark.roughness = 0.8
	var top := Vector3(0.0, PLATFORM_TOP, 0.0)
	_slab_between(top - Vector3(PLATFORM.x * 0.5, PLATFORM.y, PLATFORM.z * 0.5),
		top + Vector3(PLATFORM.x * 0.5, 0.0, PLATFORM.z * 0.5), dark)


func _slab_between(lo: Vector3, hi: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = (lo + hi) * 0.5
	add_child(body)
	var box := BoxMesh.new()
	box.size = hi - lo
	box.material = mat
	var view := MeshInstance3D.new()
	view.mesh = box
	body.add_child(view)
	var shape := BoxShape3D.new()
	shape.size = hi - lo
	var collide := CollisionShape3D.new()
	collide.shape = shape
	body.add_child(collide)


## The bare bulb: an omni light with shadows and a small glowing ball,
## which is drawn but lights nothing and stays out of the bounce.
func _build_bulb() -> void:
	_bulb = OmniLight3D.new()
	_bulb.position = BULB
	_bulb.omni_range = 60.0
	_bulb.omni_attenuation = 2.0
	_bulb.light_energy = 150.0
	_bulb.shadow_enabled = true
	add_child(_bulb)
	_bulb_glass = StandardMaterial3D.new()
	_bulb_glass.albedo_color = Color(1, 1, 1)
	_bulb_glass.emission_enabled = true
	_bulb_glass.emission = Color(1.0, 0.96, 0.9)
	_bulb_glass.emission_energy_multiplier = 40.0
	var ball := SphereMesh.new()
	ball.radius = 0.06
	ball.height = 0.12
	ball.material = _bulb_glass
	var glass := MeshInstance3D.new()
	glass.mesh = ball
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_bulb.add_child(glass)


func _set_bounce(option: String) -> void:
	_env.sdfgi_enabled = option == "SDFGI"
	if _voxel_gi != null:
		_voxel_gi.queue_free()
		_voxel_gi = null
	if option == "VoxelGI":
		_voxel_gi = VoxelGI.new()
		_voxel_gi.size = Vector3.ONE * (ROOM + 1.0)
		_voxel_gi.position.y = ROOM * 0.5
		add_child(_voxel_gi)
		_voxel_gi.bake()


## A black screen to fade through when a fall is caught.
func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


## Off the platform: once FALL_LIMIT below its top, the screen fades to
## black over a second, the player is put back on the platform, and it
## fades in again.
func _physics_process(delta: float) -> void:
	if _falling < 0.0 and player.global_position.y < PLATFORM_TOP - FALL_LIMIT:
		_falling = 0.0
	if _falling >= 0.0:
		_falling += delta
		var down := 1.0
		if _falling < down:
			_fade.color.a = _falling / down
		elif _falling < down + 0.4:
			_fade.color.a = 1.0
			player.global_position = START
			player.velocity = Vector3.ZERO
		elif _falling < down + 2.0:
			_fade.color.a = 1.0 - (_falling - down - 0.4) / 1.6
		else:
			_fade.color.a = 0.0
			_falling = -1.0
