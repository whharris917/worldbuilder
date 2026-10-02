extends OutdoorWorld
class_name MeadowMap
## A meadow in a summer wood with a brook running through it: a place
## built for its mood. Its parts, each answering the clock and the wind
## rather than a timer:
##   the land (MeadowLand): the valley, the brook, the wood;
##   the grass (GrassField): blades and flowers that the wind runs over
##     in gusts and the player parts;
##   the light: the sun by the clock, low and gold through the trees in
##     the late afternoon; mist lying in the valley at dawn and forming
##     again after dark;
##   the air: motes catching the sun by day, fireflies over the grass at
##     dusk;
##   the sound (MeadowSound): the brook loudest at its riffles, the wind
##     in the leaves with the gusts, birds by the hour, crickets at night.
## The wind is a breeze that rises through the day and drops at
## evening, gusting as it goes; the grass, the trees and the leaves'
## sound all follow the one value. Its own save.
##
## The same meadow can be drawn in a style (`style`, set by its scene):
##   "cartoon" (meadow_cartoon.tscn): flat light in two tones, bright
##     colours, rounded trees outlined in ink, cartoon water;
##   "anime" (meadow_anime.tscn): a painted sky of towering clouds, soft
##     light warm in the sun and cool in the shade, painted crowns;
##   "diorama" (meadow_diorama.tscn): a low-poly model on a square board
##     with its edges cut, pastel and faceted, the distance blurred as a
##     close photograph of a model is.
## Each keeps its own save and moonlight and shares the meadow's clock.

const WIND_DIR := Vector2(0.8, 0.6)      # toward the south-east, down the valley

@export var style := "real"

var land: MeadowLand
var grass: GrassField
var sound: MeadowSound
## The events the icons along the bottom start: the lights over the trees.
var events: EventBar
var orbs: Orbs
var wind := 0.3
var _fireflies: MultiMeshInstance3D
var _motes: MultiMeshInstance3D
var _air_mats: Array[ShaderMaterial] = []
var _mist_mat: ShaderMaterial
var _wind_noise := FastNoiseLite.new()
var _clock := 0.0


func _init() -> void:
	super()
	save_path = "user://save_meadow.json"
	settings_prefix = "meadow_"
	time_of_day = 17.0
	_wind_noise.seed = 20261006
	_wind_noise.frequency = 1.0


func _build_environment() -> void:
	super()
	# A summer valley: softer air than the coast's autumn day, and the
	# sun's glow carried in it.
	sky_env.fog_density = 0.0012
	sky_env.fog_sun_scatter = 0.25
	sky_env.fog_aerial_perspective = 0.4
	(sky_mat as ShaderMaterial).set_shader_parameter("haze", 0.55)
	match style:
		"cartoon":
			# Softer contrast between lit and shade, as a painted picture has.
			sun.light_energy = 1.3
			_sun_base_energy = 1.3
			sky_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			sky_env.tonemap_white = 6.0
			sky_env.adjustment_enabled = true
			sky_env.adjustment_saturation = 1.15
		"anime":
			# The painted sky, and a clear summer air with blue distance.
			var painted := ShaderMaterial.new()
			painted.shader = load("res://world/sky_anime.gdshader")
			sky_env.sky.sky_material = painted
			sky_mat = painted
			sun.light_energy = 1.5
			_sun_base_energy = 1.5
			sky_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			sky_env.tonemap_white = 6.0
			sky_env.adjustment_enabled = true
			sky_env.adjustment_saturation = 1.2
			sky_env.fog_aerial_perspective = 0.7
			sky_env.glow_intensity = 0.3
		"diorama":
			# A model on a table: bright even light, clean air, a pale
			# backdrop under the horizon, the far side out of focus.
			(sky_mat as ShaderMaterial).set_shader_parameter("ground_color", Color(0.80, 0.77, 0.72))
			(sky_mat as ShaderMaterial).set_shader_parameter("haze", 0.25)
			sun.light_energy = 1.6
			_sun_base_energy = 1.6
			sky_env.fog_density = 0.0004
			sky_env.adjustment_enabled = true
			sky_env.adjustment_saturation = 1.05
			var lens := CameraAttributesPractical.new()
			lens.dof_blur_far_enabled = true
			lens.dof_blur_far_distance = 55.0
			lens.dof_blur_far_transition = 80.0
			lens.dof_blur_near_enabled = true
			lens.dof_blur_near_distance = 1.2
			lens.dof_blur_near_transition = 1.0
			lens.dof_blur_amount = 0.1
			for node in find_children("*", "WorldEnvironment", true, false):
				(node as WorldEnvironment).camera_attributes = lens


func _build_ground() -> void:
	land = MeadowLand.new()
	if style != "real":
		save_path = "user://save_meadow_%s.json" % style
		moonlight_key = "meadow_%s_moonlight" % style
		land.set_style(style)
	add_child(land)
	land.build()
	if style == "anime":
		# The anime's ground: the cartoon's flat fields, softer lit, in
		# deeper greens.
		land.terrain_mat.set_shader_parameter("toon_step", 0.3)
		land.terrain_mat.set_shader_parameter("meadow", Color(0.26, 0.56, 0.20))
		land.terrain_mat.set_shader_parameter("meadow_light", Color(0.40, 0.66, 0.24))
		land.terrain_mat.set_shader_parameter("wood_floor", Color(0.16, 0.36, 0.20))
	grass = GrassField.new()
	grass.name = "Grass"
	add_child(grass)
	grass.build(land, Vector2(0.0, 0.0), 256.0, land.grass_at, _flowers_at, style)
	_build_air()
	sound = MeadowSound.new()
	sound.name = "Sound"
	add_child(sound)
	sound.build(land)


## The wood is the land's.
func _build_forest() -> void:
	pass


## Flowers bloom in the open meadow, not at its shaded edge or on the
## brook's banks.
func _flowers_at(x: float, z: float) -> float:
	var open := 1.0 - smoothstep(0.75, 0.95, land.meadow_r(x, z))
	return open * smoothstep(land.brook_half(z) + 1.0, land.brook_half(z) + 3.0, land.brook_distance(x, z))


func _build_air() -> void:
	var tex: Texture2D = grass.materials[0].get_shader_parameter("ground")
	_fireflies = _air_layer(tex, false, 260, 60.0)
	_fireflies.name = "Fireflies"
	_motes = _air_layer(tex, true, 500, 14.0)
	_motes.name = "Motes"
	# The mist: one quad over the whole screen (mist.gdshader), drawn
	# after the water and before the fireflies.
	_mist_mat = ShaderMaterial.new()
	_mist_mat.shader = load("res://world/mist.gdshader")
	_mist_mat.set_shader_parameter("floor_y", land.water_y(0.0) + 0.4)
	_mist_mat.set_shader_parameter("floor_slope", -MeadowLand.BROOK_GRADE)
	_mist_mat.render_priority = 10
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var mist := MeshInstance3D.new()
	mist.name = "Mist"
	mist.mesh = quad
	mist.material_override = _mist_mat
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist.extra_cull_margin = 16384.0
	add_child(mist)


func _air_layer(tex: Texture2D, motes: bool, count: int, box: float) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://world/air.gdshader")
	mat.set_shader_parameter("ground", tex)
	mat.set_shader_parameter("ground_origin", grass.origin)
	mat.set_shader_parameter("ground_size", grass.size)
	mat.set_shader_parameter("motes", motes)
	mat.set_shader_parameter("box", box)
	mat.render_priority = 20
	_air_mats.append(mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261007 + count
	for i in count:
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY,
			Vector3(rng.randf_range(0.0, box), rng.randf(), rng.randf_range(0.0, box))))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.custom_aabb = AABB(Vector3(-4000.0, -500.0, -4000.0), Vector3(8000.0, 1000.0, 8000.0))
	add_child(inst)
	return inst


## ---- the clock ----------------------------------------------------------------

func _on_time_of_day(horizon: float, twilight: float) -> void:
	super(horizon, twilight)
	if land == null:
		return
	var h := time_of_day
	# Mist: it gathers in the valley through the night, lies thickest at
	# dawn and burns off by mid-morning; it begins again after sunset.
	var dawn := smoothstep(3.0, 5.5, h) * (1.0 - smoothstep(6.5, 9.0, h))
	var night_mist := smoothstep(19.0, 23.5, h) * 0.6 + (1.0 - smoothstep(0.0, 3.0, h)) * 0.6 * float(h < 3.0)
	var mist := maxf(dawn, night_mist)
	match style:
		"cartoon":
			# The shade lit more by the sky by day, so it reads as a colour,
			# not dark; the night keeps its own darkness.
			sky_env.ambient_light_energy *= lerpf(1.0, 1.6, twilight)
		"anime":
			# Shade painted cool blue by day, against the warm sun.
			sky_env.ambient_light_color = sky_env.ambient_light_color.lerp(Color(0.48, 0.60, 0.95), 0.6 * twilight)
			sky_env.ambient_light_energy *= lerpf(1.0, 1.5, twilight)
		"diorama":
			sky_env.ambient_light_energy *= lerpf(1.0, 1.3, twilight)
	_mist_mat.set_shader_parameter("density", 0.12 * mist)
	_mist_mat.set_shader_parameter("scale_h", 0.9 + 0.6 * dawn)
	# Lit by the sky: pale by day, the dawn's colour softened, dim at night.
	var lit := Color(0.80, 0.82, 0.85).lerp(sky_env.fog_light_color, 0.4) * lerpf(0.06, 1.0, twilight)
	_mist_mat.set_shader_parameter("mist_color", lit)
	if sun != null:
		_mist_mat.set_shader_parameter("sun_dir", sun.global_transform.basis.z)
		var glow := sun.light_color * sun.light_energy * 0.35 * twilight
		_mist_mat.set_shader_parameter("sun_color", Vector3(glow.r, glow.g, glow.b))
	# Fireflies come out as the light goes and are mostly done by
	# midnight; motes show while the sun is up.
	var dark := 1.0 - twilight
	var late := 1.0 - smoothstep(23.0, 24.0, h) * 0.6
	if h < 4.0:
		late = 0.4 * (1.0 - smoothstep(2.0, 4.0, h))
	_air_mats[0].set_shader_parameter("amount", smoothstep(0.3, 0.9, dark) * late)
	_air_mats[1].set_shader_parameter("amount", twilight * (0.3 + 0.7 * horizon))
	if sun != null:
		_air_mats[1].set_shader_parameter("sun_dir", sun.global_transform.basis.z)
	if sound != null:
		sound.set_clock(h, twilight)


## The lights rise over the wood where the viewer is looking.
func start_orbs() -> void:
	var cam := get_viewport().get_camera_3d()
	orbs.play(cam.global_position, -cam.global_basis.z, land.height_at)


## The breeze: calm at dawn and in the night, rising through the
## morning to its strongest in mid-afternoon, falling at evening; gusts
## on top of it.
func _breeze(h: float, t: float) -> float:
	var day := smoothstep(7.0, 14.0, h) * (1.0 - smoothstep(16.5, 20.5, h))
	var base := 0.08 + 0.32 * day
	var gust := 0.5 + 0.5 * _wind_noise.get_noise_1d(t * 0.05) + 0.25 * _wind_noise.get_noise_1d(t * 0.21 + 40.0)
	return clampf(base * (0.5 + 1.1 * maxf(gust, 0.0)), 0.0, 1.0)


func _process(delta: float) -> void:
	super._process(delta)
	if grass == null:
		return
	_clock += delta
	wind = _breeze(time_of_day, _clock)
	var cam := get_viewport().get_camera_3d()
	var cam_pos := cam.global_position if cam != null else player.global_position
	grass.follow(cam_pos, player.global_position, wind, WIND_DIR.normalized())
	for mat in _air_mats:
		mat.set_shader_parameter("wind", wind)
		mat.set_shader_parameter("wind_dir", WIND_DIR)
	_mist_mat.set_shader_parameter("wind_dir", WIND_DIR)
	for mat in land.style_mats:
		mat.set_shader_parameter("wind", wind)
		mat.set_shader_parameter("wind_dir", WIND_DIR.normalized())
	for mat in TreeKit.materials():
		mat.set_shader_parameter("wind", wind * 0.8)
		mat.set_shader_parameter("wind_dir", WIND_DIR.normalized())
	sound.follow(delta, cam_pos, wind)


func _after_build() -> void:
	orbs = Orbs.new()
	orbs.name = "Orbs"
	add_child(orbs)
	events = EventBar.new()
	hud.get_parent().add_child(events)
	events.add_event(EventBar.draw_orbs, "Lights over the trees", start_orbs, orbs.running)
	if not FileAccess.file_exists(save_path):
		# On the meadow east of the brook, looking west across it toward
		# the lone oak and the afternoon sun.
		player.global_position = Vector3(26.0, land.surface_height(26.0, 12.0) + 0.4, 12.0)
		player.rotation.y = PI / 2.0 - 0.25
	match style:
		"cartoon":
			hud.toast("The meadow in the woods, drawn as a cartoon. O options: the time of day. F5/F9 save/load")
		"anime":
			hud.toast("The meadow in the woods, painted. O options: the time of day. F5/F9 save/load")
		"diorama":
			hud.toast("The meadow in the woods, as a model on a board. O options: the time of day. F5/F9 save/load")
		_:
			hud.toast("A meadow in the woods, early summer. O options: the time of day. F5/F9 save/load")
	print("[worldbuilder] meadow: %d trees, %d stones, %d m of brook; terrain %d ms, woods %d ms, grass %d ms over %d chunks"
		% [int(land.stats.get("trees", 0)), int(land.stats.get("stones", 0)), int(land.stats.get("brook_m", 0)),
		int(land.stats.get("ms_terrain", 0)), int(land.stats.get("ms_forest", 0)), int(grass.stats.get("ms", 0)),
		int(grass.stats.get("chunks_with_grass", 0))])
	if DisplayServer.get_name() == "headless":
		_report_in = 20
