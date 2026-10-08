class_name LaserLab
extends Node3D
## A dark room 16 m by 10 m and 3.2 m high with a laser on a post and six
## round mirrors on posts, all at 1.2 m, the beam crossing the room from
## mirror to mirror to the east wall. The player turns a mirror with E
## held while looking at it (Shift and E the other way), and the beam
## follows. A study of what Godot's own lighting does with a laser:
## nothing here is a custom shader.
##
## The beam's path: each frame a physics ray from the laser finds what
## it meets first. On a mirror's glass, from the front, it goes on in
## the mirror direction (the incoming direction with its part along the
## glass's facing reversed), its power times the mirror's reflectance;
## on anything else (wall, post, holder, the player) it stops. At most
## MAX_BOUNCES mirrors.
##
## Each stretch of the path is shown two ways, each on its own switch:
## - a thin glowing tube (an engine cylinder with an emissive material),
##   standing for the light the air scatters toward the eye;
## - a spot light at its start pointing along it, the cone as wide at the
##   far end as the beam, with shadows so it stops where the beam does:
##   the engine's light makes the lit dot where the beam lands, and in
##   haze (Godot's volumetric fog) the light in the air. Its brightness
##   does not fall with distance (attenuation 0), as a laser's does not;
##   its range is twice the stretch so the engine's fade at the range's
##   end barely reaches the dot, and its energy is raised by what that
##   fade takes.
##
## The mirrors (LaserMirror) are the engine's standard material, fully
## metallic and almost smooth; what they show comes from a reflection
## probe the size of the room (photographed once, and again after the
## room light changes; it leaves out the tubes) and from screen-space
## reflections. A ceiling lamp, on to begin, switched at a wall switch
## by the start or on the Room panel.
##
## Controls in two panels (BenchPanel; Esc frees the mouse), kept in
## user://laser_lab.json. Laser: on, colour, power, beam width, the
## tube and its glow, mirror reflectance, aim the mirrors as at the
## start. Room: the ceiling lamp and its brightness, haze and its
## thickness, the reflection probe, screen-space reflections, glow.

const ROOM := Vector3(16.0, 3.2, 10.0)
const WALL := 0.3
const BEAM_Y := 1.2
const START := Vector3(-3.0, 0.0, 4.3)
const MAX_BOUNCES := 24
# A spot light's cone narrower than this is drawn wrongly: the engine's
# test of whether a point is inside the cone runs out of precision, and
# the light floods whole blocks of the screen.
const MIN_SPOT_ANGLE := 0.5
const BEAM := 2                        # render layer of the tubes: left out of the probe
const STATE_PATH := "user://laser_lab.json"
const COLOURS := {
	"Red": Color(1.0, 0.04, 0.02),      # 638 nm
	"Green": Color(0.3, 1.0, 0.0),      # 532 nm
	"Blue": Color(0.22, 0.0, 1.0),      # 450 nm
}

# The beam as first set: the laser, then each mirror, then where it
# lands on the east wall (x, z at the beam's height). The mirrors are
# aimed from this.
const LASER := Vector2(-7.17, -3.5)
const PATH: Array[Vector2] = [
	Vector2(6.5, -3.5), Vector2(-5.0, -0.5), Vector2(6.5, 1.5),
	Vector2(1.0, 4.0), Vector2(-6.5, 3.0), Vector2(-2.0, -2.0),
]
const LANDING := Vector2(8.0, -1.0)

var player: Player
var _panel: BenchPanel
var _env: Environment
var _mirrors: Array[LaserMirror] = []
var _tubes: Array[MeshInstance3D] = []
var _tube_mats: Array[StandardMaterial3D] = []
var _spots: Array[SpotLight3D] = []
var _lamp: OmniLight3D
var _lamp_mat: StandardMaterial3D
var _switch: WallSwitch
var _probe: ReflectionProbe
var _probe_frames := 0
var _segments: Array[Array] = []        # [from, to, power] for each stretch
var _was_debanding := false


func _ready() -> void:
	player = $Player as Player
	player.global_position = START
	var vp := get_viewport()
	_was_debanding = vp.use_debanding
	vp.use_debanding = true
	_build_environment()
	_build_room()
	_build_laser()
	_build_mirrors()
	_build_lamp()
	_build_beam()
	_build_probe()
	_build_panels()
	LabGraphics.attach(self, _panel.panel("Graphics"))
	_panel.restore()
	_set_lamp()
	MouseMode.capture()


func _exit_tree() -> void:
	get_viewport().use_debanding = _was_debanding


## ---- the controls ----------------------------------------------------------

func _build_panels() -> void:
	_panel = BenchPanel.new(STATE_PATH)
	add_child(_panel)
	var laser := _panel.panel("Laser")
	_panel.switch(laser, "Laser on", true, func(_v: bool) -> void: pass)
	_panel.choice(laser, "Colour", COLOURS.keys(), "Green", func(_o: String) -> void: pass)
	_panel.slider(laser, "Power", 0.0, 200.0, 1.0, 40.0, func(_v: float) -> void: pass)
	_panel.note(laser, "How brightly the beam lights the spot where it lands.")
	_panel.slider(laser, "Beam width (mm)", 1.0, 100.0, 1.0, 10.0, func(_v: float) -> void: pass)
	_panel.note(laser, "A pointer's beam is 1 to 3 mm. The engine lights a surface once a pixel, so a spot that narrow is one pixel or none from across the room. The spot's light is a spot light, which cannot be narrower than half a degree, so for a thin beam it starts a short way before the landing.")
	_panel.slider(laser, "Mirror reflectance", 0.5, 1.0, 0.01, 0.95, func(_v: float) -> void: pass)
	_panel.note(laser, "The share of the light each mirror sends on. A good silvered mirror keeps about 95 in 100.")
	_panel.switch(laser, "Draw the beam", true, func(_v: bool) -> void: pass)
	_panel.slider(laser, "Beam glow", 0.0, 20.0, 0.1, 3.0, func(_v: float) -> void: pass)
	_panel.note(laser, "In clean air a laser beam cannot be seen from the side; dust and haze make it show. The drawn beam is a thin glowing tube along the path, standing for that. Off, only the engine's light remains: the spots, and the beam in the haze.")
	_panel.button(laser, "Aim the mirrors as at the start", _aim_mirrors)
	_panel.note(laser, "E held while looking at a mirror turns it; Shift and E turns it the other way.")

	var room := _panel.panel("Room")
	_panel.switch(room, "Ceiling lamp", true, func(_v: bool) -> void: _set_lamp())
	_panel.slider(room, "Lamp brightness", 0.0, 4.0, 0.01, 0.6, func(_v: float) -> void: _set_lamp())
	_panel.switch(room, "Haze", false, func(v: bool) -> void: _env.volumetric_fog_enabled = v)
	_panel.slider(room, "Haze thickness", 0.0, 0.2, 0.001, 0.03, func(v: float) -> void:
		_env.volumetric_fog_density = v)
	_panel.note(room, "Godot's volumetric fog: the air is divided into boxes, each lit by the lights that reach it. The boxes are several centimetres across near you and wider farther off, so a beam a few millimetres wide shows faintly or not at all; a wide one shows as a soft shaft.")
	_panel.switch(room, "Reflection probe", true, func(v: bool) -> void: _probe.visible = v)
	_panel.note(room, "A photograph of the room from its middle, which the mirrors reflect, bent to fit the room's box. Near the walls it is close to right; things standing in the room come out in the wrong places.")
	_panel.switch(room, "Screen-space reflections", true, func(v: bool) -> void: _env.ssr_enabled = v)
	_panel.note(room, "Reflections found in the picture already on the screen. Correct where they work, but anything off the screen or hidden behind something is missing, so the mirrors' edges go blank.")
	_panel.switch(room, "Glow", true, func(v: bool) -> void: _env.glow_enabled = v)
	_panel.note(room, "The haze of light round anything very bright, as the eye and a camera see it.")
	_switch.toggled.connect(func(on: bool) -> void:
		(_panel.switches["Ceiling lamp"] as CheckButton).button_pressed = on)


func _value(title: String) -> float:
	return float((_panel.sliders[title] as HSlider).value)


func _on(title: String) -> bool:
	return (_panel.switches[title] as CheckButton).button_pressed


func _colour() -> Color:
	for option: String in COLOURS:
		if ((_panel.choices["Colour"] as Dictionary)[option] as CheckBox).button_pressed:
			return COLOURS[option]
	return COLOURS["Green"]


## ---- the room --------------------------------------------------------------

## Black outside the room; a little ambient light so the room is not
## pitch dark with the lamp off; glow for the beam and its spots.
func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0, 0, 0)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(1, 1, 1)
	_env.ambient_light_energy = 0.02
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	_env.ssr_enabled = true
	_env.glow_enabled = true
	_env.glow_intensity = 0.8
	_env.glow_bloom = 0.0
	# A laser's spot is a few pixels hundreds of times brighter than the
	# lit room; the engine's default cap (12) on what feeds the glow would
	# leave it almost none.
	_env.glow_hdr_luminance_cap = 256.0
	_env.volumetric_fog_density = 0.03
	_env.volumetric_fog_albedo = Color(1, 1, 1)
	_env.volumetric_fog_ambient_inject = 0.0
	_env.volumetric_fog_length = 24.0
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)


## Wooden floor; walls and ceiling of matte grey paint.
func _build_room() -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.42, 0.42, 0.41)
	paint.roughness = 0.9
	var ceiling := StandardMaterial3D.new()
	ceiling.albedo_color = Color(0.3, 0.3, 0.3)
	ceiling.roughness = 0.95
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = load("res://textures/wood_floor/albedo.jpg") as Texture2D
	floor_mat.albedo_color = Color(0.7, 0.7, 0.7)
	floor_mat.normal_enabled = true
	floor_mat.normal_texture = load("res://textures/wood_floor/normal.jpg") as Texture2D
	floor_mat.roughness_texture = load("res://textures/wood_floor/roughness.jpg") as Texture2D
	floor_mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	floor_mat.uv1_triplanar = true
	floor_mat.uv1_world_triplanar = true
	floor_mat.uv1_scale = Vector3.ONE * 0.5
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var hx := ROOM.x * 0.5
	var hz := ROOM.z * 0.5
	_slab_between(Vector3(-hx - WALL, -WALL, -hz - WALL), Vector3(hx + WALL, 0.0, hz + WALL), floor_mat)
	_slab_between(Vector3(-hx - WALL, ROOM.y, -hz - WALL), Vector3(hx + WALL, ROOM.y + WALL, hz + WALL), ceiling)
	_slab_between(Vector3(hx, 0.0, -hz), Vector3(hx + WALL, ROOM.y, hz), paint)
	_slab_between(Vector3(-hx - WALL, 0.0, -hz), Vector3(-hx, ROOM.y, hz), paint)
	_slab_between(Vector3(-hx - WALL, 0.0, hz), Vector3(hx + WALL, ROOM.y, hz + WALL), paint)
	_slab_between(Vector3(-hx - WALL, 0.0, -hz - WALL), Vector3(hx + WALL, ROOM.y, -hz), paint)


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


func _dark_metal() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.04, 0.04, 0.045)
	m.metallic = 0.6
	m.roughness = 0.45
	return m


## The laser: a black body 25 cm long on a post like the mirrors',
## pointing east, its aperture at LASER.
func _build_laser() -> void:
	var metal := _dark_metal()
	var body := StaticBody3D.new()
	body.position = Vector3(LASER.x - 0.125, BEAM_Y, LASER.y)
	add_child(body)
	var box := BoxMesh.new()
	box.size = Vector3(0.25, 0.06, 0.06)
	box.material = metal
	var view := MeshInstance3D.new()
	view.mesh = box
	body.add_child(view)
	var shape := BoxShape3D.new()
	shape.size = box.size
	var collide := CollisionShape3D.new()
	collide.shape = shape
	body.add_child(collide)
	var rod := CylinderMesh.new()
	rod.top_radius = 0.012
	rod.bottom_radius = 0.012
	rod.height = BEAM_Y - 0.03
	rod.material = metal
	var rod_view := MeshInstance3D.new()
	rod_view.mesh = rod
	rod_view.position.y = -BEAM_Y * 0.5 - 0.015
	body.add_child(rod_view)
	var foot := CylinderMesh.new()
	foot.top_radius = 0.11
	foot.bottom_radius = 0.12
	foot.height = 0.03
	foot.material = metal
	var foot_view := MeshInstance3D.new()
	foot_view.mesh = foot
	foot_view.position.y = -BEAM_Y + 0.015
	body.add_child(foot_view)


func _build_mirrors() -> void:
	var holder := _dark_metal()
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.97, 0.97, 0.97)
	glass.metallic = 1.0
	glass.roughness = 0.02
	var post := _dark_metal()
	for p: Vector2 in PATH:
		var m := LaserMirror.new(BEAM_Y, holder, glass, post)
		m.position = Vector3(p.x, 0.0, p.y)
		add_child(m)
		_mirrors.append(m)
	_aim_mirrors()


## Each mirror turned to send the beam on to the next point of PATH:
## its glass facing halfway between the way back to where the beam
## comes from and the way on.
func _aim_mirrors() -> void:
	var points: Array[Vector2] = [LASER]
	points.append_array(PATH)
	points.append(LANDING)
	for i in _mirrors.size():
		var back := (points[i] - points[i + 1]).normalized()
		var on := (points[i + 2] - points[i + 1]).normalized()
		var n := (back + on).normalized()
		_mirrors[i].aim(Vector3(n.x, 0.0, n.y))


## The ceiling lamp: a round fitting in the middle of the ceiling, its
## face glowing when lit, and a point light just under it with shadows.
## The wall switch on the south wall by the start.
func _build_lamp() -> void:
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color(0.9, 0.9, 0.88)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1.0, 0.93, 0.82)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.25
	disc.bottom_radius = 0.25
	disc.height = 0.04
	disc.material = _lamp_mat
	var fitting := MeshInstance3D.new()
	fitting.mesh = disc
	fitting.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fitting.position = Vector3(0.0, ROOM.y - 0.02, 0.0)
	add_child(fitting)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0.0, ROOM.y - 0.1, 0.0)
	_lamp.light_color = Color(1.0, 0.93, 0.82)
	_lamp.omni_range = 14.0
	_lamp.shadow_enabled = true
	add_child(_lamp)
	_switch = WallSwitch.new()
	_switch.position = Vector3(START.x + 1.2, 1.3, ROOM.z * 0.5 - 0.005)
	_switch.rotation_degrees.y = 180.0
	add_child(_switch)


func _set_lamp() -> void:
	var on := _on("Ceiling lamp")
	var level := _value("Lamp brightness")
	if _switch.on != on:
		_switch.set_on(on)
	_lamp.visible = on and level > 0.0
	_lamp.light_energy = level
	_lamp_mat.emission_energy_multiplier = level * 3.0 if on else 0.0
	_rephotograph()


func _build_probe() -> void:
	_probe = ReflectionProbe.new()
	_probe.size = ROOM + Vector3(0.4, 0.4, 0.4)
	_probe.position = Vector3(0.0, ROOM.y * 0.5, 0.0)
	_probe.origin_offset = Vector3(0.0, BEAM_Y - ROOM.y * 0.5, 0.0)
	_probe.box_projection = true
	_probe.interior = true
	_probe.blend_distance = 0.0
	_probe.cull_mask = 0xFFFFF & ~BEAM
	_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(_probe)


## The probe photographs the room again a few frames on, once the change
## has reached the lighting: set to Always for those frames, then Once.
func _rephotograph() -> void:
	if _probe == null:
		return
	_probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	_probe_frames = 4


## ---- the beam --------------------------------------------------------------

## A tube and a spot light for each stretch the beam can have, hidden
## until used.
func _build_beam() -> void:
	var tube := CylinderMesh.new()
	tube.top_radius = 0.5
	tube.bottom_radius = 0.5
	tube.height = 1.0
	tube.radial_segments = 8
	tube.rings = 1
	for i in MAX_BOUNCES + 1:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0, 0, 0)
		mat.emission_enabled = true
		mat.disable_receive_shadows = true
		var mi := MeshInstance3D.new()
		mi.mesh = tube
		mi.material_override = mat
		mi.layers = BEAM
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_tubes.append(mi)
		_tube_mats.append(mat)
		var spot := SpotLight3D.new()
		spot.spot_attenuation = 0.0
		spot.spot_angle_attenuation = 1.0
		spot.shadow_enabled = true
		spot.shadow_bias = 0.02
		spot.light_cull_mask = 0xFFFFF & ~BEAM
		spot.light_specular = 0.5
		spot.visible = false
		add_child(spot)
		_spots.append(spot)


## The beam's path through the room as it stands, from the laser.
func _trace() -> void:
	_segments.clear()
	if not _on("Laser on"):
		return
	var space := get_world_3d().direct_space_state
	var from := Vector3(LASER.x + 0.001, BEAM_Y, LASER.y)
	var dir := Vector3.RIGHT
	var power := 1.0
	var reflectance := _value("Mirror reflectance")
	var exclude: Array[RID] = []
	for i in MAX_BOUNCES + 1:
		var query := PhysicsRayQueryParameters3D.create(from, from + dir * 40.0)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			_segments.append([from, from + dir * 40.0, power])
			return
		var at: Vector3 = hit["position"]
		_segments.append([from, at, power])
		var body := hit["collider"] as Node
		if body == null or not body.has_meta("mirror"):
			return
		var mirror := body.get_meta("mirror") as LaserMirror
		var n := mirror.face()
		var off := at - mirror.centre()
		off -= n * off.dot(n)
		if dir.dot(n) >= 0.0 or off.length() > LaserMirror.GLASS_R:
			return
		dir = (dir - 2.0 * dir.dot(n) * n).normalized()
		power *= reflectance
		from = at
		exclude = [(body as CollisionObject3D).get_rid()]


## Tubes and spot lights placed on the path.
func _show_beam() -> void:
	var colour := _colour()
	var radius := _value("Beam width (mm)") * 0.0005
	var glow := _value("Beam glow")
	var tubes := _on("Draw the beam")
	var energy := _value("Power")
	for i in _tubes.size():
		var used := i < _segments.size()
		_tubes[i].visible = used and tubes
		_spots[i].visible = used
		if not used:
			continue
		var a: Vector3 = _segments[i][0]
		var b: Vector3 = _segments[i][1]
		var power: float = _segments[i][2]
		var along := b - a
		var length := along.length()
		if length < 0.001:
			_tubes[i].visible = false
			_spots[i].visible = false
			continue
		var dir := along / length
		var side := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
		var up := side.cross(dir)
		var width := radius * 2.0
		_tubes[i].transform = Transform3D(Basis(side * width, along, up * width), (a + b) * 0.5)
		_tube_mats[i].emission = colour
		_tube_mats[i].emission_energy_multiplier = glow * power
		# The spot's cone is never narrower than MIN_SPOT_ANGLE, so for a
		# thin beam it starts only so far short of the landing as gives the
		# beam's width there; otherwise 2 cm along the stretch, clear of the
		# mirror it leaves. It reaches twice as far as the landing.
		var reach := minf(length - 0.02, radius / tan(deg_to_rad(MIN_SPOT_ANGLE)))
		var start := b - dir * reach
		var spot := _spots[i]
		spot.transform = Transform3D(Basis.looking_at(dir, side.cross(dir)), start)
		spot.spot_range = reach * 2.0 + 0.05
		spot.spot_angle = rad_to_deg(atan(radius / maxf(reach, 0.01)))
		var t := reach / spot.spot_range
		var fade := pow(1.0 - t * t * t * t, 2.0)
		spot.light_color = colour
		spot.light_energy = energy * power / fade


func _process(_delta: float) -> void:
	if _probe_frames > 0:
		_probe_frames -= 1
		if _probe_frames == 0:
			_probe.update_mode = ReflectionProbe.UPDATE_ONCE


func _physics_process(_delta: float) -> void:
	_trace()
	_show_beam()
	if DisplayServer.get_name() == "headless" and Engine.get_physics_frames() == 10:
		var last: Vector3 = _segments[-1][1] if not _segments.is_empty() else Vector3.ZERO
		print("[worldbuilder] laser lab: %d mirrors, beam in %d stretches, ends at (%.2f, %.2f, %.2f)"
			% [_mirrors.size(), _segments.size(), last.x, last.y, last.z])
