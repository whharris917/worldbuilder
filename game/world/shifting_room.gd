class_name ShiftingRoom
extends Node3D
## The Shifting Room: a cube 24 m every way, plain matte grey inside but
## for the front wall, which is rough stone made from noise in world space
## (rough_stone.gdshader), never repeating, and in its middle a floating platform 1.2 m square, just room
## to stand, its top 12 m up, with a lip 30 cm high round its edge. The
## player's body is a capsule 35 cm in radius, which rides up over any
## edge low enough to meet its rounded foot at under 45 degrees, about
## 10 cm; the lip stops a walk, and the player must jump (a 60 cm rise) to
## leave. The one light is a bare bulb 1 m under
## the platform (an omni light, inverse square, with shadows), so the room
## is lit from below the player's feet: the floor and the lower walls
## brightest, and the platform's shadow over the ceiling and the tops of
## the walls. Godot's default shading; no WorldBase.
##
## A player who jumps off falls to the floor and may walk about there; R
## puts them back on the platform, through a short fade to black.
##
## The eye: the front wall (north, the one the player faces on arriving)
## has a patch 8 m square, its middle level with the platform's view,
## made of a plane divided 192 times each way whose points the wall's
## shader (eye_wall.gdshader) moves out by a height picture drawn afresh
## each frame (eye_height.gdshader, in a SubViewport 1024 square, half-float
## so heights and slopes keep their precision), the picture's alpha saying
## what the surface is: stone, the same as the rest of the wall, for the
## wall and the eye's lid; white, a streaked blue iris and a black pupil
## for the eye. The wall is open behind the patch and closed by a slab just
## behind it. an eyeball 3.2 m across pushes
## out through the wall over 8 s, 1.5 s after arrival, its lid closed;
## the lid then opens, and it blinks once every 10 s. It looks about the
## room, darting to a new point every 1.2 to 3.5 s (a third of the time,
## the player's head, which it then follows), turning no more than 40
## degrees from straight out.
##
## The rear wall (south, behind the player on arriving) is a single flat
## plane carved to look deep by parallax occlusion mapping
## (ornament_wall.gdshader): the carving drawn once into a picture 2048
## square (ornament_static.gdshader), a frieze strip 2048 by 160 drawn
## every frame (ornament_frieze.gdshader), and gold vines worked out in
## the wall's own shader; stone, marble, wood, silver and gold. The
## manuscript's script is written over 90 s, held 20 s, faded over 5 s,
## and after 5 s blank begins again. A reflection probe the size of the
## room, photographed once, gives the metals something to reflect.
##
## The east wall (to the right on arriving) shows the same ornament
## through the engine's own StandardMaterial3D instead: colour, normal,
## roughness-and-metal, height (its deep parallax) and glow pictures, each
## 2048 square, painted from the same carving, frieze and vines
## (ornament_maps.gdshader): the whole of each once, then only the moving
## parts again (the column strips, the frieze band, the plaque while it is
## written, the forest's stars) every third frame, the pictures keeping
## what was painted before. Switches on the Walls panel turn the eye, the
## custom-shader wall and the engine wall on and off; off, a wall is plain
## grey.
##
## One panel (BenchPanel; Esc frees the mouse), kept in
## user://shifting_room.json: dithering (on to begin; put back as found on
## leaving), the bulb's energy, and the bounce method:
## None; SDFGI, the default, smallest cell 0.15 m, since the room's faces
## lie on 0.2 m multiples where SDFGI's default gave no bounce in another
## room; or VoxelGI, a box round the room baked when chosen, which gives
## no bounce at all from a light falling off with the square of the
## distance, as this bulb's does.

const ROOM := 24.0
const WALL := 0.5
const PLATFORM := Vector3(1.2, 0.2, 1.2)
const LIP := Vector2(0.04, 0.30)        # m wide and high, round the platform's top edge
const PLATFORM_TOP := 12.0
const BULB := Vector3(0.0, PLATFORM_TOP - 0.2 - 1.0, 0.0)
const START := Vector3(0.0, PLATFORM_TOP, 0.0)
const STATE_PATH := "user://shifting_room.json"
const EYE_PATCH := 8.0
const EYE_CENTRE := Vector3(0.0, 13.0, -ROOM * 0.5)
const EYE_GRID := 192                   # points each way: 4 cm apart; at 400, 39 fps from the side on the laptop
const EYE_PICTURE := 1024
const EYE_BALL := 1.6
const EMERGE_START := 1.5
const EMERGE_TIME := 8.0
const OPEN_TIME := 1.5
const BLINK_EVERY := 10.0
const GAZE_LIMIT := 40.0                # degrees from straight out of the wall
const CARVING_PICTURE := 2048
const FRIEZE_PICTURE := Vector2i(2048, 160)
const WRITE_TIME := 90.0
const HOLD_TIME := 20.0
const FADE_TIME := 5.0
const BLANK_TIME := 5.0
const MAP_PICTURE := 2048
const MAP_EVERY := 3                    # frames between paintings of the moving parts
# Parts of the wall (x0, y0, x1, y1 in metres, x across as seen, y up)
# repainted by each map: 0 colour, 1 normal, 2 roughness and metal,
# 3 height, 4 glow.
const MOVING_COLUMNS: Array[Vector4] = [Vector4(0.98, 2.9, 2.22, 19.8), Vector4(4.58, 2.9, 5.82, 19.8),
	Vector4(18.18, 2.9, 19.42, 19.8), Vector4(21.78, 2.9, 23.02, 19.8)]
const MOVING_FRIEZE := Vector4(0.0, 9.7, 24.0, 11.5)
const MOVING_PLAQUE := Vector4(7.0, 11.9, 17.0, 19.5)
const MOVING_FOREST := Vector4(6.4, 3.2, 17.6, 9.4)

var player: Player
var _panel: BenchPanel
var _env: Environment
var _bulb: OmniLight3D
var _bulb_glass: StandardMaterial3D
var _voxel_gi: VoxelGI
var _fade: ColorRect
var _returning := -1.0                  # s since the fade out began; below 0, none
var _built := false
var _debanding_was := false
var _eye_mat: ShaderMaterial
var eye_clock := 0.0                    # s since arrival, for the eye
var _next_blink := 0.0
var _blink_at := -1.0                   # when the current blink began; below 0, none
var _gaze := Vector3.BACK               # where the eye looks, out of the wall (+z)
var _gaze_target := Vector3.ZERO
var _follow_player := false
var _next_glance := 0.0
var _rng := RandomNumberGenerator.new()
var _ornament: ShaderMaterial
var _frieze_mat: ShaderMaterial
var _carving: SubViewport
var _frieze: SubViewport
var _rear_wall: MeshInstance3D
var _east_wall: MeshInstance3D
var _eye_patch: MeshInstance3D
var _front_boxes: Array[BoxMesh] = []
var _front_stone: ShaderMaterial
var _plain: StandardMaterial3D
var _probe: ReflectionProbe
var _probe_frames := 0
var _maps: Array[SubViewport] = []
var _map_mats: Array[ShaderMaterial] = []
var _map_whole: Array[ColorRect] = []    # each map's whole-wall painting, shown once
var _map_frame := 0                     # frames since the room was built, for the maps

var _was_resolution: Array = []

func _ready() -> void:
	# The resolution the graphics preset sets in the worlds, put back on
	# leaving.
	_was_resolution = GraphicsSettings.apply_saved_resolution(get_viewport())
	player = $Player as Player
	player.global_position = START
	_debanding_was = get_viewport().use_debanding
	for node in player.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	_build_environment()
	_build_room()
	_build_platform()
	_build_eye()
	_build_ornament()
	_build_engine_wall()
	_build_bulb()
	_build_fade()
	_build_panel()
	get_viewport().use_debanding = true
	_panel.restore()
	_built = true
	_set_walls()
	_set_bounce(_picked("Bounce"))
	MouseMode.capture()
	if DisplayServer.get_name() == "headless":
		print("[worldbuilder] shifting room: a cube %d m, the platform's top %d m up" % [int(ROOM), int(PLATFORM_TOP)])


func _build_panel() -> void:
	_panel = BenchPanel.new(STATE_PATH)
	add_child(_panel)
	var light := _panel.panel("Light")
	_panel.switch(light, "Dithering", true, func(on: bool) -> void: get_viewport().use_debanding = on)
	_panel.note(light, "Adds a faint noise to each pixel before it is stored at 8 bits a channel, which breaks the bands in the walls' smooth gradients into grain too fine to see.")
	_panel.slider(light, "Bulb energy", 0.0, 600.0, 1.0, 150.0, func(v: float) -> void:
		_bulb.light_energy = v
		_bulb_glass.emission_energy_multiplier = 40.0 * v / 150.0)
	_panel.note(light, "The bare bulb under the platform, the room's only light. Its light falls off with the square of the distance.")
	_panel.choice(light, "Bounce", ["None", "SDFGI", "VoxelGI"], "SDFGI", func(o: String) -> void:
		if _built:
			_set_bounce(o))
	var walls := _panel.panel("Walls")
	var rewall := func(_v: bool) -> void: _set_walls()
	_panel.switch(walls, "Front wall: the eye", true, rewall)
	_panel.switch(walls, "Rear wall: custom shader", true, rewall)
	_panel.switch(walls, "East wall: engine material", true, rewall)
	_panel.note(walls, "The rear and east walls carry the same ornament drawn two ways: the rear by a shader written for it, the east by the engine's own material from five painted pictures. Off, a wall is plain grey; turn one off to see what the other costs in the frame rate at the top right.")
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
	_plain = grey
	var h := ROOM * 0.5
	_slab_between(Vector3(-h - WALL, -WALL, -h - WALL), Vector3(h + WALL, 0.0, h + WALL), grey)
	_slab_between(Vector3(-h - WALL, ROOM, -h - WALL), Vector3(h + WALL, ROOM + WALL, h + WALL), grey)
	# The east wall stands a centimetre back, behind the engine's plane.
	_slab_between(Vector3(h + 0.01, 0.0, -h), Vector3(h + WALL, ROOM, h), grey)
	_slab_between(Vector3(-h - WALL, 0.0, -h), Vector3(-h, ROOM, h), grey)
	# The rear wall stands a centimetre back, behind the ornamented plane.
	_slab_between(Vector3(-h - WALL, 0.0, h + 0.01), Vector3(h + WALL, ROOM, h + WALL), grey)
	# The front wall, stone, open where the eye's patch is and closed behind it.
	var rock := ShaderMaterial.new()
	rock.shader = load("res://world/rough_stone.gdshader") as Shader
	_front_stone = rock
	var e := EYE_PATCH * 0.5
	var ey := EYE_CENTRE.y
	_front_boxes.append(_slab_between(Vector3(-h - WALL, 0.0, -h - WALL), Vector3(-e, ROOM, -h), rock))
	_front_boxes.append(_slab_between(Vector3(e, 0.0, -h - WALL), Vector3(h + WALL, ROOM, -h), rock))
	_front_boxes.append(_slab_between(Vector3(-e, 0.0, -h - WALL), Vector3(e, ey - e, -h), rock))
	_front_boxes.append(_slab_between(Vector3(-e, ey + e, -h - WALL), Vector3(e, ROOM, -h), rock))
	_front_boxes.append(_slab_between(Vector3(-e, ey - e, -h - WALL), Vector3(e, ey + e, -h - 0.01), rock))


## The platform, plain darker grey, held up by nothing, and its lip: four
## strips standing on its top along the edges.
func _build_platform() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.3, 0.3, 0.3)
	dark.roughness = 0.8
	var top := Vector3(0.0, PLATFORM_TOP, 0.0)
	var hx := PLATFORM.x * 0.5
	var hz := PLATFORM.z * 0.5
	_slab_between(top - Vector3(hx, PLATFORM.y, hz), top + Vector3(hx, 0.0, hz), dark)
	var w := LIP.x
	var h := LIP.y
	_slab_between(top + Vector3(-hx, 0.0, -hz), top + Vector3(hx, h, -hz + w), dark)
	_slab_between(top + Vector3(-hx, 0.0, hz - w), top + Vector3(hx, h, hz), dark)
	_slab_between(top + Vector3(-hx, 0.0, -hz + w), top + Vector3(-hx + w, h, hz - w), dark)
	_slab_between(top + Vector3(hx - w, 0.0, -hz + w), top + Vector3(hx, h, hz - w), dark)


func _slab_between(lo: Vector3, hi: Vector3, mat: Material) -> BoxMesh:
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
	return box


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


## ---- the eye -----------------------------------------------------------------

## The height picture's viewport and the patch of wall it moves.
func _build_eye() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(EYE_PICTURE, EYE_PICTURE)
	view.use_hdr_2d = true
	view.disable_3d = true
	# Kept so the picture's alpha, the eye's labels, survives.
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var canvas := ColorRect.new()
	canvas.size = Vector2(EYE_PICTURE, EYE_PICTURE)
	_eye_mat = ShaderMaterial.new()
	_eye_mat.shader = load("res://world/eye_height.gdshader") as Shader
	_eye_mat.set_shader_parameter("patch", EYE_PATCH)
	_eye_mat.set_shader_parameter("ball", EYE_BALL)
	canvas.material = _eye_mat
	view.add_child(canvas)
	var wall := ShaderMaterial.new()
	wall.shader = load("res://world/eye_wall.gdshader") as Shader
	wall.set_shader_parameter("heights", view.get_texture())
	var plane := PlaneMesh.new()
	plane.size = Vector2(EYE_PATCH, EYE_PATCH)
	plane.subdivide_width = EYE_GRID - 1
	plane.subdivide_depth = EYE_GRID - 1
	plane.material = wall
	var patch := MeshInstance3D.new()
	patch.mesh = plane
	patch.position = EYE_CENTRE
	patch.rotation_degrees.x = 90.0
	# The moved surface stands up to about 1.5 m out of the plane.
	patch.extra_cull_margin = 2.0
	add_child(patch)
	_eye_patch = patch
	_rng.randomize()
	_gaze_target = Vector3(0.0, EYE_CENTRE.y, 0.0)


## ---- the rear wall -------------------------------------------------------------

## The two pictures (the carving once, the frieze every frame), the plane
## that shows them, and the reflection probe.
func _build_ornament() -> void:
	var carving := _picture(Vector2i(CARVING_PICTURE, CARVING_PICTURE), "res://world/ornament_static.gdshader",
		SubViewport.UPDATE_ONCE)
	var frieze := _picture(FRIEZE_PICTURE, "res://world/ornament_frieze.gdshader", SubViewport.UPDATE_ALWAYS)
	_carving = carving
	_frieze = frieze
	_frieze_mat = (frieze.get_child(0) as ColorRect).material as ShaderMaterial
	_ornament = ShaderMaterial.new()
	_ornament.shader = load("res://world/ornament_wall.gdshader") as Shader
	_ornament.set_shader_parameter("carving", carving.get_texture())
	_ornament.set_shader_parameter("carving_exact", carving.get_texture())
	_ornament.set_shader_parameter("frieze", frieze.get_texture())
	_ornament.set_shader_parameter("frieze_exact", frieze.get_texture())
	var plane := PlaneMesh.new()
	plane.size = Vector2(ROOM, ROOM)
	plane.material = _ornament
	var wall := MeshInstance3D.new()
	wall.mesh = plane
	wall.position = Vector3(0.0, ROOM * 0.5, ROOM * 0.5)
	wall.rotation_degrees.x = -90.0
	add_child(wall)
	_rear_wall = wall
	var probe := ReflectionProbe.new()
	probe.size = Vector3.ONE * (ROOM + 0.4)
	probe.position = Vector3(0.0, ROOM * 0.5, 0.0)
	probe.origin_offset = Vector3(0.0, PLATFORM_TOP + 1.6 - ROOM * 0.5, 0.0)
	probe.box_projection = true
	probe.interior = true
	probe.blend_distance = 0.0
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)
	_probe = probe


## The east wall: a plane with a StandardMaterial3D drawing the ornament
## from five pictures, each a SubViewport that keeps what it painted
## before (never cleared). Each holds a rectangle painting the whole wall,
## shown for the first painting only (two frames in, after the carving's
## picture has been drawn), and rectangles over the moving parts that map
## needs, painted again every MAP_EVERY frames.
func _build_engine_wall() -> void:
	var moving: Array = [
		MOVING_COLUMNS + [MOVING_FRIEZE, MOVING_PLAQUE],
		MOVING_COLUMNS + [MOVING_FRIEZE],
		MOVING_COLUMNS + [MOVING_FRIEZE, MOVING_PLAQUE],
		MOVING_COLUMNS + [MOVING_FRIEZE],
		MOVING_COLUMNS + [MOVING_FOREST],
	]
	for map in 5:
		var view := SubViewport.new()
		view.size = Vector2i(MAP_PICTURE, MAP_PICTURE)
		view.disable_3d = true
		view.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(view)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://world/ornament_maps.gdshader") as Shader
		mat.set_shader_parameter("map", map)
		mat.set_shader_parameter("carving", _carving.get_texture())
		mat.set_shader_parameter("carving_exact", _carving.get_texture())
		mat.set_shader_parameter("frieze", _frieze.get_texture())
		mat.set_shader_parameter("frieze_exact", _frieze.get_texture())
		var whole := ColorRect.new()
		whole.size = Vector2(MAP_PICTURE, MAP_PICTURE)
		whole.material = mat
		view.add_child(whole)
		for part: Vector4 in moving[map]:
			var rect := ColorRect.new()
			var scale := MAP_PICTURE / ROOM
			rect.position = Vector2(floorf(part.x * scale) - 2.0, floorf((ROOM - part.w) * scale) - 2.0)
			rect.size = Vector2(ceilf((part.z - part.x) * scale) + 4.0, ceilf((part.w - part.y) * scale) + 4.0)
			rect.material = mat
			view.add_child(rect)
		_maps.append(view)
		_map_mats.append(mat)
		_map_whole.append(whole)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _maps[0].get_texture()
	m.normal_enabled = true
	m.normal_texture = _maps[1].get_texture()
	m.roughness = 1.0
	m.roughness_texture = _maps[2].get_texture()
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.metallic = 1.0
	m.metallic_texture = _maps[2].get_texture()
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.heightmap_enabled = true
	m.heightmap_texture = _maps[3].get_texture()
	# The engine's parallax depth is a share of the picture's width, in
	# hundredths: the carving's 0.45 m over the wall's 24 m.
	m.heightmap_scale = 0.45 / ROOM * 100.0
	m.heightmap_deep_parallax = true
	m.heightmap_min_layers = 8
	m.heightmap_max_layers = 32
	m.emission_enabled = true
	m.emission = Color(0, 0, 0)
	m.emission_texture = _maps[4].get_texture()
	m.emission_energy_multiplier = 3.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var plane := PlaneMesh.new()
	plane.size = Vector2(ROOM, ROOM)
	plane.material = m
	_east_wall = MeshInstance3D.new()
	_east_wall.mesh = plane
	# Its picture's across runs along +z (rightward to someone facing the
	# wall), its rows down, and it faces west into the room.
	_east_wall.transform = Transform3D(Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0)),
		Vector3(ROOM * 0.5, ROOM * 0.5, 0.0))
	add_child(_east_wall)


## Each frame: the maps' first whole painting, then the moving parts every
## MAP_EVERY frames, with this moment's time and writing.
func _paint_maps(writing: Vector2) -> void:
	_map_frame += 1
	var whole := _map_frame == 3
	if _map_frame == 5:
		for rect in _map_whole:
			rect.visible = false
	if not whole and (_map_frame < 6 or _map_frame % MAP_EVERY != 0 or not _east_wall.visible):
		return
	for i in _maps.size():
		_map_mats[i].set_shader_parameter("time_s", eye_clock)
		_map_mats[i].set_shader_parameter("write_progress", writing.x)
		_map_mats[i].set_shader_parameter("ink", writing.y)
		_maps[i].render_target_update_mode = SubViewport.UPDATE_ONCE


## The walls' switches. Off, the front wall's stone turns plain grey and
## the eye goes; the rear or east wall's ornamented plane goes, showing
## the grey wall a centimetre behind it. The reflection probe photographs
## the room again.
func _set_walls() -> void:
	if _panel == null:
		return
	var front := (_panel.switches["Front wall: the eye"] as CheckButton).button_pressed
	var rear := (_panel.switches["Rear wall: custom shader"] as CheckButton).button_pressed
	var east := (_panel.switches["East wall: engine material"] as CheckButton).button_pressed
	_eye_patch.visible = front
	for box in _front_boxes:
		box.material = _front_stone if front else _plain
	_rear_wall.visible = rear
	_east_wall.visible = east
	_frieze.render_target_update_mode = SubViewport.UPDATE_ALWAYS if rear or east else SubViewport.UPDATE_DISABLED
	_probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	_probe_frames = 4


## A SubViewport of `size` with a ColorRect drawn by `shader`, half-float,
## its alpha kept.
func _picture(size: Vector2i, shader: String, update: SubViewport.UpdateMode) -> SubViewport:
	var view := SubViewport.new()
	view.size = size
	view.use_hdr_2d = true
	view.disable_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = update
	add_child(view)
	var canvas := ColorRect.new()
	canvas.size = Vector2(size)
	var mat := ShaderMaterial.new()
	mat.shader = load(shader) as Shader
	canvas.material = mat
	view.add_child(canvas)
	return view


## The manuscript's cycle: how much is written (0..1) and how dark the
## ink stands (it fades before the page is begun again).
func _writing(t: float) -> Vector2:
	var cycle := WRITE_TIME + HOLD_TIME + FADE_TIME + BLANK_TIME
	var c := fmod(t, cycle)
	if c < WRITE_TIME:
		return Vector2(c / WRITE_TIME, 1.0)
	if c < WRITE_TIME + HOLD_TIME:
		return Vector2(1.0, 1.0)
	if c < WRITE_TIME + HOLD_TIME + FADE_TIME:
		return Vector2(1.0, 1.0 - (c - WRITE_TIME - HOLD_TIME) / FADE_TIME)
	return Vector2(0.0, 1.0)


## How far the lid is closed at `t` seconds into a blink: shut in 0.1 s,
## held 0.06 s, open again in 0.22 s.
func _blink_shape(t: float) -> float:
	if t < 0.1:
		return smoothstep(0.0, 0.1, t)
	if t < 0.16:
		return 1.0
	return 1.0 - smoothstep(0.16, 0.38, t)


func _process(delta: float) -> void:
	eye_clock += delta
	var emerge := smoothstep(EMERGE_START, EMERGE_START + EMERGE_TIME, eye_clock)
	var opened_at := EMERGE_START + EMERGE_TIME
	var blink := 1.0 - smoothstep(opened_at, opened_at + OPEN_TIME, eye_clock)
	if eye_clock >= opened_at + OPEN_TIME:
		if _next_blink <= 0.0:
			_next_blink = opened_at + OPEN_TIME + BLINK_EVERY
		if eye_clock >= _next_blink:
			_blink_at = eye_clock
			_next_blink += BLINK_EVERY
		if _blink_at >= 0.0:
			var t := eye_clock - _blink_at
			blink = _blink_shape(t)
			if t > 0.38:
				_blink_at = -1.0
	_look(delta, emerge)
	_eye_mat.set_shader_parameter("emerge", emerge)
	_eye_mat.set_shader_parameter("blink", blink)
	_eye_mat.set_shader_parameter("gaze", _gaze)
	_frieze_mat.set_shader_parameter("time_s", eye_clock)
	_ornament.set_shader_parameter("time_s", eye_clock)
	var writing := _writing(eye_clock)
	_ornament.set_shader_parameter("write_progress", writing.x)
	_ornament.set_shader_parameter("ink", writing.y)
	_paint_maps(writing)
	if _probe_frames > 0:
		_probe_frames -= 1
		if _probe_frames == 0:
			_probe.update_mode = ReflectionProbe.UPDATE_ONCE


## Where the eye looks: a new point every 1.2 to 3.5 s, anywhere in the
## room in front of the wall or, a third of the time, the player's head,
## followed until the next glance. The eye turns to it in a quick dart
## (time constant 40 ms), never more than GAZE_LIMIT from straight out.
func _look(delta: float, emerge: float) -> void:
	if eye_clock >= _next_glance:
		_next_glance = eye_clock + _rng.randf_range(1.2, 3.5)
		_follow_player = _rng.randf() < 0.33
		var h := ROOM * 0.5
		_gaze_target = Vector3(_rng.randf_range(-h + 1.0, h - 1.0), _rng.randf_range(0.5, ROOM - 0.5),
			_rng.randf_range(-h + 3.0, h - 0.5))
	var target := _gaze_target
	if _follow_player:
		target = player.camera.global_position
	var centre := EYE_CENTRE + Vector3(0.0, 0.0, emerge * 1.3 - EYE_BALL)
	var want := (target - centre).normalized()
	var limit := deg_to_rad(GAZE_LIMIT)
	if want.angle_to(Vector3.BACK) > limit:
		var side := want - Vector3.BACK * want.dot(Vector3.BACK)
		side = side.normalized() if side.length() > 1e-5 else Vector3.DOWN
		want = Vector3.BACK * cos(limit) + side * sin(limit)
	_gaze = _gaze.lerp(want, 1.0 - exp(-delta / 0.04)).normalized()


func _exit_tree() -> void:
	GraphicsSettings.restore_resolution(get_viewport(), _was_resolution)
	get_viewport().use_debanding = _debanding_was


## A black screen to fade through on the way back to the platform.
func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


## R: back to the platform.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_R and _returning < 0.0:
		_returning = 0.0


## The way back: the screen fades to black over 0.3 s, the player is put
## on the platform, and it fades in again over half a second.
func _physics_process(delta: float) -> void:
	if _returning < 0.0:
		return
	_returning += delta
	var down := 0.3
	if _returning < down:
		_fade.color.a = _returning / down
	elif _returning < down + 0.1:
		_fade.color.a = 1.0
		player.global_position = START
		player.velocity = Vector3.ZERO
	elif _returning < down + 0.6:
		_fade.color.a = 1.0 - (_returning - down - 0.1) / 0.5
	else:
		_fade.color.a = 0.0
		_returning = -1.0
