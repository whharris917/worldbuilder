class_name CozyTest
extends BuildWorld
## Cozy Island (Test): a small flat island in a calm sea, for working on
## the cozy island's models one at a time where nothing else stands
## near them. Grass on a level top, a ring of beach round it, a campsite
## on the south beach (Campsite) and one windmill at the centre
## (Windmill). The sky, sun and moon are the cozy island's own
## (IslandSky); the models are painted in vertex colours, as on the
## island (CozyMesh).
##
## The ground is one disc of rings round the centre, its height a
## profile of the distance out as a share of the coast's radius, that
## radius wavering a little with the bearing: a level top, a gentle
## fall to a flat berm of dry sand (the campsite's), then the beach
## sloping into the sea and the seabed falling away. Invisible walls
## along the waterline keep the player ashore; R returns them to the
## campsite.
##
## The wind is the world's: a speed and the bearing it blows from, set on
## the Wind panel, with gusts (two slow noises, one for the speed, one
## for the direction) when they are on. It is heard everywhere, softly
## (wind_loop.wav), louder and a little higher as it blows harder. The windmill turns to it and is
## driven by it; its gasworks (GasWorks) is the machine on its spindle.
## The mill's and the gasworks' state is kept in MILL_PATH.
##
## Time passes: the hour runs on at a chosen pace (the Time panel) and
## the sun keeps to its real path for LATITUDE on a day when its
## declination is DECLINATION (late spring), worked out from the hour
## (`sun_at`). The direct sunlight it gives, watts a square metre, follows
## from how much air it crosses (`sunlight_at`). Building here is under
## sunlight (BenchLight.sun_rules): the only light is what sun collectors
## gather. The hour is kept with the mill's state.
##
## The player builds here as on the cozy island (Workshop, Tab for its menu),
## what they build kept in BUILD_PATH, apart from the island's.

const STATE_PATH := "user://cozy_test.json"
const MILL_PATH := "user://cozy_test_mill.json"
const BUILD_PATH := "user://cozy_test_build.json"
const R := 44.0                         # the coast's mean radius, at the profile's 1.0
const TOP := 1.2                        # the level top's height over the sea
const SEABED := -3.5
# The profile: share of the radius, height. Smoothed between (Catmull-Rom).
const PROFILE := [Vector2(0.0, TOP), Vector2(0.58, TOP), Vector2(0.68, 0.95), Vector2(0.8, 0.78),
		Vector2(0.92, 0.1), Vector2(1.0, -0.45), Vector2(1.2, -2.2), Vector2(1.45, SEABED), Vector2(3.0, SEABED)]
const GRASS_TO := 0.65                  # the grass's edge, as a share of the radius
const CAMP_BEARING := 90.0              # degrees round from +x toward +z: due south
const CAMP_OUT := 0.74                  # the campsite's centre, a share of the radius out
const GROUND_OUT := 90.0                # how far the ground's disc reaches
const LATITUDE := 44.0                  # degrees north
const DECLINATION := 20.0               # the sun's, degrees: late May or mid July

var sky: IslandSky
var campsite: Campsite
var windmill: Windmill
var workshop: Workshop
var _panel: BenchPanel
var _env: Environment
var _mats: Array[Dictionary] = []       # the model materials and their outlines
var _sea_mat: StandardMaterial3D
var _foam_mat: StandardMaterial3D
var _coast_noise := FastNoiseLite.new()
var _patch_noise := FastNoiseLite.new()
var _clock := 0.0
var _spawn := Vector3.ZERO
var _spawn_facing := 0.0
var _was_soft := 0
## The hour of the day, 0 to 24.
var hour := 10.0
var _hour_saved := -1.0
var _sky_left := 0.0
var _slider_left := 0.0
var _time_note: Label
var _gust := FastNoiseLite.new()
var _wind_sound: AudioStreamPlayer
var _readout: Label
var _readout_left := 0.0
var _save_left := 5.0


func _ready() -> void:
	player = $Player as Player
	_was_soft = int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 2))
	_coast_noise.seed = 31
	_coast_noise.frequency = 0.9
	_patch_noise.seed = 47
	_patch_noise.frequency = 0.12
	_build_environment()
	_build_ground()
	_build_sea()
	_build_foam()
	_build_bounds()
	var a := deg_to_rad(CAMP_BEARING)
	var r := CAMP_OUT * coast_radius(a)
	campsite = Campsite.new(material(), material(false))
	campsite.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
	# The campsite's own frame: x along the shore, z out to sea.
	campsite.rotation.y = -a + PI * 0.5
	add_child(campsite)
	campsite.build(height)
	var glass := StandardMaterial3D.new()
	glass.vertex_color_use_as_albedo = true
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.roughness = 0.05
	glass.metallic_specular = 0.6
	var glow := StandardMaterial3D.new()
	glow.vertex_color_use_as_albedo = true
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.72, 0.38)
	glow.emission_energy_multiplier = 2.0
	windmill = Windmill.new({"out": material(), "out_plain": material(false), "in": material(true, true),
			"in_plain": material(false, true), "glass": glass, "glow": glow})
	windmill.position = Vector3(0.0, TOP, 0.0)
	# The door faces the campsite.
	windmill.rotation.y = -a + PI * 0.5
	add_child(windmill)
	windmill.attach(GasWorks.new())
	_load_mill()
	_gust.seed = 13
	_gust.frequency = 1.0
	# The mill's stairs are steeper than the player's usual limit.
	player.floor_max_angle = deg_to_rad(50.0)
	player.floor_snap_length = 0.35
	workshop = Workshop.new(self, BUILD_PATH, false, true)
	add_child(workshop)
	_build_panels()
	LabGraphics.attach(self, _panel.panel("Graphics"), func(g: GraphicsSettings) -> void:
		RenderingServer.directional_soft_shadow_filter_set_quality(
				maxi(g.filter_quality(), RenderingServer.SHADOW_QUALITY_SOFT_LOW) as RenderingServer.ShadowQuality))
	_panel.restore()
	if _hour_saved >= 0.0:
		hour = _hour_saved
	(_panel.sliders["Time of day"] as HSlider).set_value_no_signal(hour)
	_apply()
	# The player starts at the campsite's landward side, looking up the
	# island to the windmill.
	_spawn = campsite.to_global(Vector3(1.5, 0.0, -4.5))
	_spawn.y = height(_spawn.x, _spawn.z) + 0.1
	_spawn_facing = atan2(_spawn.x, _spawn.z)
	_put_player()
	MouseMode.capture()
	if DisplayServer.get_name() == "headless":
		print("[worldbuilder] cozy test: coast at %.1f m south, campsite at %s, windmill hub %.1f m up"
				% [coast_radius(a) * _shore_share(), campsite.position, windmill.hub_height()])


func _exit_tree() -> void:
	_save_mill()
	RenderingServer.directional_soft_shadow_filter_set_quality(_was_soft as RenderingServer.ShadowQuality)


## ---- the controls ----------------------------------------------------------

func _build_panels() -> void:
	_panel = BenchPanel.new(STATE_PATH)
	add_child(_panel)
	var redraw := func(_v: Variant) -> void: _apply()
	var look := _panel.panel("Look")
	_panel.switch(look, "Toon light", true, redraw)
	_panel.note(look, "Surfaces lit fully or not at all, with a soft step between, as on the cozy island with its toon light on.")
	_panel.switch(look, "Outlines", true, redraw)
	_panel.slider(look, "Outline width (cm)", 0.1, 3.0, 0.1, 0.6, redraw)
	_panel.note(look, "Each model drawn a second time, a little larger and from the inside, in a dark brown, so a line shows round its edges. The width is in centimetres of the world, so near things get thicker lines than far ones.")
	_panel.switch(look, "Soft shadows", false, redraw)
	_panel.note(look, "The sun given a larger size in the sky, so shadows blur farther from what casts them. It costs a good deal of drawing time.")
	_panel.switch(look, "Storybook sky", false, redraw)
	var light := _panel.panel("Sun and moon")
	var time := _panel.panel("Time")
	_panel.slider(time, "Time of day", 0.0, 24.0, 0.05, 10.0, func(v: float) -> void:
		hour = v
		_update_sky())
	_panel.switch(time, "Time passes", true, redraw)
	_panel.slider(time, "Minutes per hour", 1.0, 60.0, 1.0, 10.0, redraw)
	_panel.note(time, "How many minutes of play an hour of the day takes. At ten, a day lasts four hours; the sun moves a degree and a half a minute.")
	_time_note = _panel.note(time, "")
	_panel.slider(light, "Sun brightness", 0.0, 3.0, 0.01, 1.4, redraw)
	_panel.slider(light, "Moon height", -30.0, 85.0, 0.5, 25.0, redraw)
	_panel.slider(light, "Moon direction", 0.0, 360.0, 1.0, 120.0, redraw)
	_panel.note(light, "The sun follows the hour (the Time panel). Brightness is how bright it looks; the light it gives the collectors follows from its height. Moon heights in degrees above the horizon; directions from north toward east. The campsite is on the south beach.")
	var wind := _panel.panel("Wind")
	_panel.slider(wind, "Wind speed (m/s)", 0.0, 20.0, 0.5, 7.0, redraw)
	_panel.slider(wind, "Wind from", 0.0, 360.0, 1.0, 225.0, redraw)
	_panel.note(wind, "The bearing the wind blows from, from north toward east. A light breeze is 3 metres a second, a fresh one 8, a gale 18.")
	_panel.switch(wind, "Gusts", true, redraw)
	_panel.note(wind, "The wind rising and falling by about a fifth and veering a few degrees either way, over tens of seconds.")
	_panel.slider(wind, "Sail cloth (%)", 0.0, 100.0, 5.0, 100.0, redraw)
	_panel.note(wind, "How much of the cloth is spread on the sails. A miller took cloth in as the wind rose, to keep the sails from running too fast.")
	_readout = _panel.note(wind, "")
	var sound := _panel.panel("Sound")
	_panel.slider(sound, "Master volume (dB)", -24.0, 12.0, 0.5, AudioOutput.master_db, func(v: float) -> void: AudioOutput.set_master_db(v))
	_panel.note(sound, "Everything the game plays, in every world.")
	_panel.slider(sound, "Wind (%)", 0.0, 200.0, 5.0, 55.0, redraw)
	_panel.slider(sound, "Sails (%)", 0.0, 200.0, 5.0, 50.0, redraw)
	_panel.note(sound, "The wind heard everywhere, and the sails' swoosh as each sweeps past the tower.")


func _on(title: String) -> bool:
	return (_panel.switches[title] as CheckButton).button_pressed


func _value(title: String) -> float:
	return float((_panel.sliders[title] as HSlider).value)


func _apply() -> void:
	_update_sky()
	var size := 2.5 if _on("Soft shadows") else 0.5
	sky.sun.light_angular_distance = size
	sky.moonlight.light_angular_distance = size
	var toon := _on("Toon light")
	var lines := _on("Outlines")
	var width := _value("Outline width (cm)") * 0.01
	for s: Dictionary in _mats:
		var m: StandardMaterial3D = s["mat"]
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON if toon else BaseMaterial3D.DIFFUSE_BURLEY
		m.roughness = 0.2 if toon else 0.85
		var line: StandardMaterial3D = s.get("line")
		if line != null:
			line.grow_amount = width
			m.next_pass = line if lines else null
	_sea_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON if toon else BaseMaterial3D.DIFFUSE_BURLEY
	_sea_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON if toon else BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_sea_mat.roughness = 0.12 if toon else 0.05
	windmill.set_cloth(_value("Sail cloth (%)") * 0.01)
	windmill.swoosh_level = _value("Sails (%)") * 0.01


## ---- the hour and the sun ---------------------------------------------------

## The sun's height over the horizon and bearing from north toward east,
## degrees, at `h` o'clock (solar time).
static func sun_at(h: float) -> Vector2:
	var lat := deg_to_rad(LATITUDE)
	var dec := deg_to_rad(DECLINATION)
	var angle := deg_to_rad((h - 12.0) * 15.0)
	var east := -cos(dec) * sin(angle)
	var north := sin(dec) * cos(lat) - cos(dec) * cos(angle) * sin(lat)
	var up := sin(dec) * sin(lat) + cos(dec) * cos(angle) * cos(lat)
	return Vector2(rad_to_deg(asin(clampf(up, -1.0, 1.0))), fposmod(rad_to_deg(atan2(east, north)), 360.0))


## Direct sunlight with the sun `height` degrees up, W/m²: the sunlight
## above the air (1361) dimmed by the air it crosses (Meinel's fit), the
## air's depth from the sun's height (Kasten and Young's air mass).
static func sunlight_at(height: float) -> float:
	if height <= 0.0:
		return 0.0
	var air := 1.0 / (sin(deg_to_rad(height)) + 0.50572 * pow(height + 6.07995, -1.6364))
	return 1361.0 * pow(0.7, pow(air, 0.678))


## The sky, the night lights and the collectors' sunlight for the hour.
func _update_sky() -> void:
	var at := sun_at(hour)
	sky.set_state(at.x, at.y, _value("Sun brightness"), _value("Moon height"), _value("Moon direction"),
			_on("Storybook sky"))
	campsite.set_night(1.0 - sky.daylight)
	_env.fog_light_color = sky.haze_colour
	workshop.light.sun = sky.sun.global_basis.z.normalized()
	workshop.light.sunlight = sunlight_at(at.x)
	var where: String = ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"][roundi(at.y / 45.0) % 8]
	_time_note.text = "%02d:%02d. %s" % [floori(hour), floori(fmod(hour, 1.0) * 60.0),
			("The sun is %d degrees up in the %s; its direct light %d watts a square metre." % [roundi(at.x), where, roundi(workshop.light.sunlight)])
			if at.x > 0.0 else "The sun is down."]


## ---- materials -------------------------------------------------------------

## A material taking the vertex colours as its albedo, reached by the
## Look panel's switches; `lined` gives it an outline pass.
##
## `inside` is for surfaces indoors: their share of the light from the
## sky (the ambient light, which the engine gives every surface alike,
## walls or no walls) cut to a third through a plain ambient-occlusion
## map, so a room is lit mostly by its windows, door and lamps.
func material(lined := true, inside := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.metallic_specular = 0.0
	m.roughness = 0.85
	if inside:
		var grey := Image.create(1, 1, false, Image.FORMAT_RGB8)
		grey.fill(Color(0.33, 0.33, 0.33))
		m.ao_enabled = true
		m.ao_texture = ImageTexture.create_from_image(grey)
		m.ao_light_affect = 0.0
	var s := {"mat": m}
	if lined:
		var line := StandardMaterial3D.new()
		line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line.cull_mode = BaseMaterial3D.CULL_FRONT
		line.grow = true
		line.grow_amount = 0.025
		line.disable_receive_shadows = true
		line.albedo_color = Color(0.26, 0.2, 0.16)
		s["line"] = line
	_mats.append(s)
	return m


## A built piece's material: its flat colour, reached by the Look
## panel's switches, outlined unless `extra` says "no_line".
func surface(_dir: String, scale: float, _real: Color, rough: float, flat: Color,
		extra: Dictionary = {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = flat
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	var s := {"mat": m}
	if not extra.get("no_line", false):
		var line := StandardMaterial3D.new()
		line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line.cull_mode = BaseMaterial3D.CULL_FRONT
		line.grow = true
		line.grow_amount = 0.025
		line.disable_receive_shadows = true
		line.albedo_color = flat.darkened(0.55)
		s["line"] = line
	_mats.append(s)
	return m


## ---- the light and the air -------------------------------------------------

## The cozy island's softened look, fixed: shade from the sky, a gentle
## grade, a soft glow, a little haze.
func _build_environment() -> void:
	sky = IslandSky.new()
	add_child(sky)
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky.sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	_env.ssao_enabled = true
	_env.adjustment_enabled = true
	_env.adjustment_brightness = 1.03
	_env.adjustment_contrast = 0.92
	_env.adjustment_saturation = 1.25
	_env.glow_enabled = true
	_env.glow_intensity = 0.5
	_env.glow_bloom = 0.15
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	_env.fog_density = 0.0015
	_env.fog_sun_scatter = 0.1
	_env.fog_sky_affect = 0.0
	_env.fog_aerial_perspective = 0.4
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)


## ---- the ground ------------------------------------------------------------

## The coast's radius at a bearing (radians round from +x toward +z).
func coast_radius(bearing: float) -> float:
	return R * (1.0 + 0.06 * _coast_noise.get_noise_2d(cos(bearing), sin(bearing)))


## The ground's height at a share `s` of the coast's radius.
static func profile(s: float) -> float:
	var n := PROFILE.size()
	var i := 0
	while i < n - 2 and s > (PROFILE[i + 1] as Vector2).x:
		i += 1
	var p1: Vector2 = PROFILE[i]
	var p2: Vector2 = PROFILE[i + 1]
	if s <= p1.x:
		return p1.y
	if s >= p2.x:
		return p2.y
	var p0: Vector2 = PROFILE[maxi(i - 1, 0)]
	var p3: Vector2 = PROFILE[mini(i + 2, n - 1)]
	var w := p2.x - p1.x
	# Slopes at the ends of the span from its neighbours, scaled to it.
	var m1 := (p2.y - p0.y) / maxf(p2.x - p0.x, 1e-4) * w
	var m2 := (p3.y - p1.y) / maxf(p3.x - p1.x, 1e-4) * w
	if i == 0:
		m1 = 0.0
	var t := (s - p1.x) / w
	var t2 := t * t
	var t3 := t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * p1.y + (t3 - 2.0 * t2 + t) * m1 \
			+ (-2.0 * t3 + 3.0 * t2) * p2.y + (t3 - t2) * m2


func height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	return profile(r / coast_radius(atan2(z, x)))


## The share of the coast's radius where the ground meets the sea.
func _shore_share() -> float:
	var lo := 0.8
	var hi := 1.2
	for k in 30:
		var mid := (lo + hi) * 0.5
		if profile(mid) > 0.0:
			lo = mid
		else:
			hi = mid
	return lo


func _ground_colour(x: float, z: float, h: float, s: float) -> Color:
	var grass := Color(0.47, 0.66, 0.31).lerp(Color(0.4, 0.6, 0.3), 0.5 + 0.5 * _patch_noise.get_noise_2d(x, z))
	var sand := Color(0.94, 0.86, 0.67)
	var wet := Color(0.78, 0.68, 0.52)
	var seabed := Color(0.72, 0.68, 0.55)
	var edge := GRASS_TO + 0.025 * _patch_noise.get_noise_2d(x * 2.0, z * 2.0)
	var c := sand.lerp(grass, 1.0 - smoothstep(edge - 0.015, edge + 0.015, s))
	c = c.lerp(wet, 1.0 - smoothstep(0.0, 0.25, h))
	return c.lerp(seabed, 1.0 - smoothstep(-0.6, -0.1, h))


## One disc of rings, close together out to the shore and the shallows,
## wider beyond; collision from the same triangles.
func _build_ground() -> void:
	var radii: Array[float] = [0.0]
	var r := 0.0
	while r < GROUND_OUT:
		r += 2.0 if r < 20.0 else (0.75 if r < 60.0 else 3.0)
		radii.append(minf(r, GROUND_OUT))
	var segments := 240
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := PackedVector3Array()
	for ring in radii.size():
		for k in segments:
			var a := TAU * k / segments
			var rr := radii[ring]
			var p := Vector3(cos(a) * rr, 0.0, sin(a) * rr)
			var s := rr / coast_radius(a)
			p.y = profile(s)
			points.append(p)
			st.set_color(_ground_colour(p.x, p.z, p.y, s).srgb_to_linear())
			st.add_vertex(p)
	for ring in radii.size() - 1:
		for k in segments:
			var a := ring * segments + k
			var b := ring * segments + (k + 1) % segments
			var c := a + segments
			var d := b + segments
			for tri: Array in [[a, b, c], [b, d, c]]:
				st.add_index(tri[0])
				var p0 := points[tri[0]]
				var p1 := points[tri[1]]
				var p2 := points[tri[2]]
				# Facing up: clockwise seen from above.
				if (p2 - p0).cross(p1 - p0).y >= 0.0:
					st.add_index(tri[1])
					st.add_index(tri[2])
				else:
					st.add_index(tri[2])
					st.add_index(tri[1])
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, material(false))
	var view := MeshInstance3D.new()
	view.name = "Ground"
	view.mesh = mesh
	add_child(view)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)


## ---- the sea ---------------------------------------------------------------

## A disc 3 km across at the sea's level, each point coloured by the
## depth of the ground under it (pale where shallow), with drifting
## ripple bumps.
func _build_sea() -> void:
	var radii: Array[float] = [0.0]
	var r := 0.0
	while r < 1500.0:
		r += 2.0 if r < GROUND_OUT else r * 0.15
		radii.append(minf(r, 1500.0))
	var segments := 180
	var deep := Color(0.16, 0.5, 0.78)
	var shallow := Color(0.5, 0.88, 0.82)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := PackedVector3Array()
	for ring in radii.size():
		for k in segments:
			var a := TAU * k / segments
			var p := Vector3(cos(a) * radii[ring], 0.0, sin(a) * radii[ring])
			points.append(p)
			var depth := -height(p.x, p.z) if radii[ring] < GROUND_OUT else -SEABED
			st.set_color(deep.lerp(shallow, 1.0 - smoothstep(0.0, 3.0, depth)))
			st.set_normal(Vector3.UP)
			st.set_tangent(Plane(1.0, 0.0, 0.0, 1.0))
			st.set_uv(Vector2(p.x, p.z) / 9.0)
			st.add_vertex(p)
	for ring in radii.size() - 1:
		for k in segments:
			var a := ring * segments + k
			var b := ring * segments + (k + 1) % segments
			var c := a + segments
			var d := b + segments
			for tri: Array in [[a, b, c], [b, d, c]]:
				var p0 := points[tri[0]]
				var p1 := points[tri[1]]
				var p2 := points[tri[2]]
				if p0 == p1 or p1 == p2 or p0 == p2:
					continue
				st.add_index(tri[0])
				if (p2 - p0).cross(p1 - p0).y >= 0.0:
					st.add_index(tri[1])
					st.add_index(tri[2])
				else:
					st.add_index(tri[2])
					st.add_index(tri[1])
	var bumps := FastNoiseLite.new()
	bumps.seed = 5
	bumps.frequency = 0.02
	bumps.fractal_octaves = 4
	var ripple := NoiseTexture2D.new()
	ripple.width = 512
	ripple.height = 512
	ripple.seamless = true
	ripple.as_normal_map = true
	ripple.bump_strength = 4.0
	ripple.noise = bumps
	_sea_mat = StandardMaterial3D.new()
	_sea_mat.vertex_color_use_as_albedo = true
	_sea_mat.vertex_color_is_srgb = true
	_sea_mat.normal_enabled = true
	_sea_mat.normal_texture = ripple
	_sea_mat.normal_scale = 0.35
	_sea_mat.metallic_specular = 0.5
	var mesh := st.commit()
	mesh.surface_set_material(0, _sea_mat)
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = mesh
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)


## A band of foam along the waterline, from half a metre up the sand to
## two and a half out, crisp-edged; it swells and sinks with a slow
## swell (`_process`).
func _build_foam() -> void:
	var shore := _shore_share()
	var segments := 240
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in segments + 1:
		var a := TAU * k / segments
		var r := coast_radius(a) * shore
		var dir := Vector3(cos(a), 0.0, sin(a))
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(dir * (r - 0.5) + Vector3.UP * 0.03)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(dir * (r + 2.5) + Vector3.UP * 0.03)
	for k in segments:
		var i := k * 2
		# Inner and outer points of this step and the next, wound to face up.
		st.add_index(i)
		st.add_index(i + 1)
		st.add_index(i + 2)
		st.add_index(i + 1)
		st.add_index(i + 3)
		st.add_index(i + 2)
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.17, 0.3, 0.37, 0.43])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.95), Color(1, 1, 1, 0),
			Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	var band := GradientTexture1D.new()
	band.gradient = g
	band.width = 256
	_foam_mat = StandardMaterial3D.new()
	_foam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_foam_mat.roughness = 1.0
	_foam_mat.metallic_specular = 0.0
	_foam_mat.texture_repeat = false
	_foam_mat.albedo_texture = band
	var foam := MeshInstance3D.new()
	foam.name = "Foam"
	foam.mesh = st.commit()
	foam.material_override = _foam_mat
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(foam)


## Invisible walls round the island where the ground is 30 cm under the
## sea, so the player can wade to the knees and no further.
func _build_bounds() -> void:
	var lo := 0.9
	var hi := 1.3
	for k in 30:
		var mid := (lo + hi) * 0.5
		if profile(mid) > -0.3:
			lo = mid
		else:
			hi = mid
	var faces := PackedVector3Array()
	var segments := 120
	for k in segments:
		var a0 := TAU * k / segments
		var a1 := TAU * (k + 1) / segments
		var p0 := Vector3(cos(a0), 0.0, sin(a0)) * coast_radius(a0) * lo
		var p1 := Vector3(cos(a1), 0.0, sin(a1)) * coast_radius(a1) * lo
		var quad := [p0 + Vector3.DOWN * 6.0, p1 + Vector3.DOWN * 6.0, p1 + Vector3.UP * 6.0, p0 + Vector3.UP * 6.0]
		for i: int in [0, 1, 2, 0, 2, 3]:
			faces.append(quad[i])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var c := CollisionShape3D.new()
	c.shape = shape
	var body := StaticBody3D.new()
	body.add_child(c)
	add_child(body)


## ---- each frame --------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	_sea_mat.uv1_offset = Vector3(_clock * 0.012, _clock * 0.007, 0.0)
	var swell := sin(_clock * TAU / 10.0)
	_foam_mat.uv1_offset = Vector3(0.06 * swell, 0.0, 0.0)
	_foam_mat.albedo_color.a = 0.85 + 0.15 * swell
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		sky.follow(camera.global_position)
	_blow(delta)
	if _on("Time passes"):
		hour = fposmod(hour + delta / (_value("Minutes per hour") * 60.0), 24.0)
	_sky_left -= delta
	if _sky_left <= 0.0:
		_sky_left = 0.1
		_update_sky()
	_slider_left -= delta
	if _slider_left <= 0.0:
		_slider_left = 0.5
		(_panel.sliders["Time of day"] as HSlider).set_value_no_signal(hour)
	_save_left -= delta
	if _save_left <= 0.0:
		_save_left = 5.0
		_save_mill()
	if MouseMode.probe or player == null:
		return
	if player.position.y < -1.5 or (Input.is_physical_key_pressed(KEY_R) and not player.input_locked and player.look_held_by == null):
		_put_player()


func _put_player() -> void:
	player.global_position = _spawn
	player.rotation.y = _spawn_facing
	player.velocity = Vector3.ZERO


## ---- the wind and the mill -------------------------------------------------

## The wind given to the mill, gusting if asked; the readout four times a
## second.
func _blow(delta: float) -> void:
	if _wind_sound == null:
		_wind_sound = AudioStreamPlayer.new()
		_wind_sound.volume_db = -80.0
		if DisplayServer.get_name() != "headless":
			var loop := load("res://audio/wind_loop.wav") as AudioStreamWAV
			loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop.loop_begin = 0
			loop.loop_end = int(loop.get_length() * loop.mix_rate)
			_wind_sound.stream = loop
			_wind_sound.autoplay = true
		add_child(_wind_sound)
	var speed := _value("Wind speed (m/s)")
	var from := _value("Wind from")
	if _on("Gusts"):
		speed *= 1.0 + 0.2 * _gust.get_noise_1d(_clock * 0.08)
		from += 8.0 * _gust.get_noise_1d(_clock * 0.02 + 300.0)
	windmill.wind_speed = maxf(speed, 0.0)
	windmill.wind_from = wrapf(from, 0.0, 360.0)
	var strength := windmill.wind_speed / 10.0
	_wind_sound.volume_db = linear_to_db(clampf(strength * _value("Wind (%)") * 0.01, 0.0001, 1.6)) - 30.0
	_wind_sound.pitch_scale = 0.85 + 0.03 * windmill.wind_speed
	_readout_left -= delta
	if _readout_left > 0.0:
		return
	_readout_left = 0.25
	var off := absf(windmill.off_wind())
	var turning := "The sails are still." if absf(windmill.rpm()) < 0.1 else "The sails turn %.1f times a minute." % windmill.rpm()
	var facing := "They face the wind." if off < 3.0 else "They stand %d degrees off the wind; the fantail is turning the cap." % roundi(off)
	if windmill.rpm() > 30.0:
		turning += " That is dangerously fast: take in cloth."
	if windmill.brake_on:
		turning += " The brake is on."
	if not windmill.in_gear:
		turning += " The spindle is out of gear."
	_readout.text = "Wind %.1f m/s from %d.
%s
%s
Power to the spindle: %.1f kW.
%s" % [windmill.wind_speed,
			roundi(windmill.wind_from), turning, facing, windmill.power * 0.001, windmill.load.report()]


func _save_mill() -> void:
	# Not for the probes, which set the mill as they need it.
	if windmill == null or MouseMode.probe:
		return
	var file := FileAccess.open(MILL_PATH, FileAccess.WRITE)
	if file != null:
		var state := windmill.state()
		state["hour"] = hour
		file.store_string(JSON.stringify(state))


func _load_mill() -> void:
	var saved := {}
	if FileAccess.file_exists(MILL_PATH):
		var file := FileAccess.open(MILL_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				saved = parsed
	windmill.restore(saved)
	if saved.has("hour"):
		_hour_saved = fposmod(float(saved["hour"]), 24.0)
