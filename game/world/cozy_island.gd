class_name CozyIsland
extends Node3D
## A small island in a calm sea under an afternoon sun: a beach all
## round, grass above it, a hill, a cabin, a dock, trees and rocks. A
## study in softening a photographic look into a cosy cartoon one, step
## by step, each step on its own switch. Every step is the engine's own
## rendering: material settings, the light, the environment and the
## camera. Nothing here is a custom shader.
##
## The steps, in the order they are listed:
## - Flat colours: the scanned textures, their bumps and their glossy
##   reflections off; each surface one plain colour, lighter and brighter
##   than the real one. Lit windows in the cabin.
## - Toon light: the materials' diffuse mode Toon, which lights a surface
##   fully or not at all with a soft step between, its width the
##   material's roughness; highlights only on the water, as a hard spot.
## - Coloured shade: the light in shade a fixed blue-lilac instead of
##   the sky's (the environment's ambient light from a colour).
## - Soft shadows: the sun given an apparent size, so shadows blur with
##   distance from what casts them (the engine's PCSS).
## - Outlines: each solid drawn a second time, a little larger and from
##   the inside (a material's next pass with Grow and front faces culled),
##   in a darker shade of its colour.
## - Gentle grade: lower contrast, more colour (environment adjustments).
## - Glow: bright parts bleed light into their neighbours.
## - Haze: depth fog in a pale sky colour, so distance fades.
## - Soft focus: the distance out of focus (camera depth of field).
## - Storybook sky: the engine's procedural sky in soft colours with
##   noise clouds, in place of its physical sky; a larger moon with a
##   crisp edge and fewer, sparkling stars.
## - Foam line: a crisp white band where the sea meets the beach, in
##   place of a soft one.
##
## The ground is one height field, cut along a wavy line into sand below
## and grass above; the sea is one disc whose vertex colours carry the
## water's depth (pale where shallow). Invisible walls keep the player
## on land and on the dock. The sun and moon go anywhere in the sky,
## below the horizon too, and the sky follows through dusk to night
## (IslandSky); at dusk the cabin's windows and porch lamp come on, and
## lanterns hanging in the trees round the cabin (HangingLantern). A
## campfire burns on the beach by the dock (Campfire), day and night.
## Controls (BenchPanel; Esc frees the mouse)
## in two panels, kept in user://cozy_island.json.

const STATE_PATH := "user://cozy_island.json"
const R := 46.0                        # the coast's mean radius
const HILL := Vector2(-10.0, -8.0)
const EXTENT := 100.0                  # half the ground's square
const GRID := 1.0
const FLOOR := -4.0                    # the seabed's depth far out
const CABIN := Vector3(4.0, 0.0, 20.0) # its floor's height worked out
const CABIN_SIZE := Vector3(4.0, 2.4, 5.0)
const DOCK_X := 4.0
const DOCK_W := 1.6
const DOCK_Y := 0.6
const NIGHT_SHADE := Color(0.22, 0.28, 0.6)
const FIRE_BEARING := 105.0            # degrees round from +x toward +z
const LANTERNS := 5
const STEPS := ["Flat colours", "Toon light", "Coloured shade", "Soft shadows", "Outlines",
		"Gentle grade", "Glow", "Haze", "Soft focus", "Storybook sky", "Foam line"]

var player: Player
var sky: IslandSky
var _panel: BenchPanel
var _env: Environment
var _camera_look: CameraAttributesPractical
var _porch: OmniLight3D
var _porch_mat: StandardMaterial3D
var _crowns: Array[Vector4] = []        # broad-leaved trees: crown centre, size
var _lanterns: Array[HangingLantern] = []
var _fire_at := Vector3.ZERO
var _hovered: Node = null
var _surfaces: Array[Dictionary] = []
var _sea: MeshInstance3D
var _sea_mat: StandardMaterial3D
var _sea_depth := PackedFloat32Array()  # 0 deep to 1 shallow, per sea vertex
var _foam: MeshInstance3D
var _foam_mat: StandardMaterial3D
var _foam_soft: GradientTexture1D
var _foam_crisp: GradientTexture1D
var _coast_noise := FastNoiseLite.new()
var _hump_noise := FastNoiseLite.new()
var _edge_noise := FastNoiseLite.new()
var _ground := [PackedVector3Array(), PackedVector3Array(), PackedVector3Array(), PackedVector3Array()]
var _dock_z0 := 0.0
var _dock_z1 := 0.0
var _clock := 0.0
var _was_debanding := false
var _was_soft := 0


func _ready() -> void:
	player = $Player as Player
	var vp := get_viewport()
	_was_debanding = vp.use_debanding
	vp.use_debanding = true
	# Soft shadows need the engine's shadow softening at least at Low; put
	# back on leaving.
	_was_soft = int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 2))
	RenderingServer.directional_soft_shadow_filter_set_quality(
			maxi(_was_soft, RenderingServer.SHADOW_QUALITY_SOFT_LOW) as RenderingServer.ShadowQuality)
	_coast_noise.seed = 7
	_coast_noise.frequency = 1.0
	_hump_noise.seed = 11
	_hump_noise.frequency = 0.04
	_edge_noise.seed = 23
	_edge_noise.frequency = 0.09
	_build_environment()
	_build_ground()
	_build_sea()
	_build_foam()
	_build_cabin()
	_build_dock()
	_build_trees()
	_build_rocks()
	_build_campfire()
	_build_lanterns()
	add_child(SaltWorks.new(self))
	_build_bounds()
	_build_panels()
	# Soft shadows need the engine's shadow softening at least at Low,
	# whatever the graphics preset says.
	LabGraphics.attach(self, _panel.panel("Graphics"), func(g: GraphicsSettings) -> void:
		var preset := g.filter_quality()
		RenderingServer.directional_soft_shadow_filter_set_quality(
				maxi(preset, RenderingServer.SHADOW_QUALITY_SOFT_LOW) as RenderingServer.ShadowQuality))
	_panel.restore()
	_apply()
	# The player starts at the dock's end, looking back at the island.
	player.global_position = Vector3(DOCK_X, DOCK_Y + 0.05, _dock_z1 - 1.0)
	player.rotation.y = 0.0
	MouseMode.capture()
	if DisplayServer.get_name() == "headless":
		print("[worldbuilder] cozy island: %d surfaces, coast at %.1f m, dock %.1f to %.1f m"
				% [_surfaces.size(), coast(PI * 0.5, 0.0), _dock_z0, _dock_z1])


func _exit_tree() -> void:
	get_viewport().use_debanding = _was_debanding
	RenderingServer.directional_soft_shadow_filter_set_quality(_was_soft as RenderingServer.ShadowQuality)


## ---- the controls ----------------------------------------------------------

func _build_panels() -> void:
	_panel = BenchPanel.new(STATE_PATH)
	add_child(_panel)
	var steps := _panel.panel("Softening")
	_panel.note(steps, "Each switch is one step from a photograph's look toward a storybook's, in the order they are usually taken. Every step is a setting of the engine's own.")
	_panel.button(steps, "All off: as photographed", func() -> void: _set_all(false))
	_panel.button(steps, "All on: cosy", func() -> void: _set_all(true))
	var redraw := func(_v: Variant) -> void: _apply()

	_panel.heading(steps, "Surfaces")
	_panel.switch(steps, "Flat colours", false, redraw)
	_panel.note(steps, "The scanned photographs on the sand, grass, rock, bark and wood, their bumps and their glossy reflections are taken away. Each surface keeps one plain colour, chosen lighter and brighter than the real one.")
	_panel.switch(steps, "Toon light", false, redraw)
	_panel.slider(steps, "Edge softness", 0.01, 1.0, 0.01, 0.2, redraw)
	_panel.note(steps, "Normally a surface grows darker smoothly as it turns from the sun. In the material's Toon mode it is either lit or not, with a step between whose width is set here: the engine uses the material's roughness for it. Highlights are kept only on the water, as a hard spot.")

	_panel.heading(steps, "Light")
	_panel.switch(steps, "Coloured shade", false, redraw)
	_panel.colour(steps, "Shade colour", Color(0.55, 0.6, 0.9), redraw)
	_panel.slider(steps, "Shade brightness", 0.0, 1.5, 0.01, 0.6, redraw)
	_panel.note(steps, "What a surface out of the sun receives is the environment's ambient light. Normally it comes from the sky; here it is one fixed colour, so every shadow takes the same cool tint, as painters do.")
	_panel.switch(steps, "Soft shadows", false, redraw)
	_panel.slider(steps, "Sun size", 0.0, 6.0, 0.1, 2.5, redraw)
	_panel.note(steps, "The real sun is half a degree across, which is why shadows blur a little farther from what casts them. Giving the sun a larger size in degrees widens that blur. Off, the sun has its true size.")

	_panel.heading(steps, "Shapes")
	_panel.switch(steps, "Outlines", false, redraw)
	_panel.slider(steps, "Outline width (cm)", 1.0, 15.0, 0.5, 4.0, redraw)
	_panel.note(steps, "Every solid is drawn a second time, swollen outward by this much and showing only its inner side, so a rim of it shows round the edges. The rim is a darker shade of the surface's own colour. Its width is in metres of the world, so far things get thinner lines; sharp corners, like the cabin's, leave small gaps.")

	_panel.heading(steps, "Picture")
	_panel.switch(steps, "Gentle grade", false, redraw)
	_panel.slider(steps, "Contrast", 0.5, 1.2, 0.01, 0.9, redraw)
	_panel.slider(steps, "Saturation", 0.5, 2.0, 0.01, 1.35, redraw)
	_panel.note(steps, "Applied to the finished picture: lower contrast lifts the darks and tames the brights; more saturation strengthens the colours.")
	_panel.switch(steps, "Glow", false, redraw)
	_panel.slider(steps, "Glow strength", 0.0, 2.0, 0.01, 0.6, redraw)
	_panel.note(steps, "Bright parts of the picture bleed a soft light into their surroundings, as through a lens with a little haze on it.")
	_panel.switch(steps, "Haze", false, redraw)
	_panel.slider(steps, "Haze thickness", 0.0, 0.02, 0.0005, 0.003, redraw)
	_panel.note(steps, "Distance fades into a pale sky colour, so the far sea and the far side of the island stay quiet.")
	_panel.switch(steps, "Soft focus", false, redraw)
	_panel.slider(steps, "Sharp up to (m)", 5.0, 100.0, 1.0, 45.0, redraw)
	_panel.note(steps, "The camera's depth of field: what is farther than this blurs gradually, which also makes the island read as small, like a model.")

	_panel.heading(steps, "Setting")
	_panel.switch(steps, "Storybook sky", false, redraw)
	_panel.note(steps, "Off, the engine's physical sky: the colour of air lit by the sun. On, its simpler sky drawn from a few chosen colours that change through sunset and dusk to night, with clouds made from noise; the moon larger with a crisp edge, and only the brightest stars, as sparkles.")
	_panel.switch(steps, "Foam line", false, redraw)
	_panel.note(steps, "Where the sea meets the beach, a crisp white band in place of a soft one. Both rise and fall with the swell.")

	var light := _panel.panel("Sun and moon")
	_panel.slider(light, "Sun height", -30.0, 85.0, 0.5, 38.0, redraw)
	_panel.slider(light, "Sun direction", 0.0, 360.0, 1.0, 215.0, redraw)
	_panel.slider(light, "Sun brightness", 0.0, 3.0, 0.01, 1.4, redraw)
	_panel.note(light, "Height is in degrees above the horizon, below it when negative; direction from north toward east. The cabin's door faces south. As the sun sinks its light crosses more air, which scatters blue away more than red, so it weakens and reddens; once it has set, only the sky's glow is left, until that fades too and the stars come out.")
	_panel.switch(light, "Eyes adjust", true, redraw)
	_panel.note(light, "The camera's automatic exposure: it measures how bright the picture is on average and slowly brightens or darkens it toward a middle grey, as the eye adjusts to dusk, up to a limit so night stays night. Off, the exposure is fixed for daylight, and sunset and night are as dark as the light really is against noon. The storybook sky is painted for each hour already, so with it the exposure stays fixed.")
	_panel.slider(light, "Moon height", -30.0, 85.0, 0.5, 25.0, redraw)
	_panel.slider(light, "Moon direction", 0.0, 360.0, 1.0, 120.0, redraw)
	_panel.note(light, "The moon's phase follows from where it stands against the sun: opposite the sun it is full, beside it new. Its light on the island is as strong as its lit part is large, shown dimmer and bluer than daylight as films show night; the real moon is hundreds of thousands of times fainter than the sun.")


func _set_all(on: bool) -> void:
	for title: String in STEPS:
		(_panel.switches[title] as CheckButton).button_pressed = on


func _value(title: String) -> float:
	return float((_panel.sliders[title] as HSlider).value)


func _on(title: String) -> bool:
	return (_panel.switches[title] as CheckButton).button_pressed


## Every switch and slider applied to the materials, light and
## environment.
func _apply() -> void:
	sky.set_state(_value("Sun height"), _value("Sun direction"), _value("Sun brightness"),
			_value("Moon height"), _value("Moon direction"), _on("Storybook sky"))
	var flat := _on("Flat colours")
	var toon := _on("Toon light")
	var lines := _on("Outlines")
	var edge := _value("Edge softness")
	var width := _value("Outline width (cm)") * 0.01
	for s: Dictionary in _surfaces:
		var m: StandardMaterial3D = s["mat"]
		var water: bool = s.get("water", false)
		var textured := not flat and s.has("albedo")
		m.albedo_texture = s["albedo"] if textured else null
		m.roughness_texture = s.get("rough_tex") if textured else null
		m.normal_enabled = s.has("normal") and (water or not flat)
		m.normal_scale = 0.35 if water and flat else 1.0
		if not water:
			m.albedo_color = s["flat"] if flat else s["real"]
		# The flat look gives no glossy reflections but on the water.
		m.metallic_specular = 0.5 if water or not flat else 0.0
		if s.has("glow"):
			# Lit by day in the flat look; in both, brighter as night falls.
			var lamp := maxf(0.8 if flat else 0.0, 2.5 * (1.0 - sky.daylight))
			m.emission_enabled = lamp > 0.0
			m.emission = s["glow"]
			m.emission_energy_multiplier = lamp
		if toon:
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			m.specular_mode = BaseMaterial3D.SPECULAR_TOON if water else BaseMaterial3D.SPECULAR_DISABLED
			m.roughness = 0.12 if water else edge
		else:
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
			m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
			m.roughness = s["rough"]
		var line: StandardMaterial3D = s.get("line")
		if line != null:
			line.grow_amount = width
			line.albedo_color = (s["flat"] as Color).darkened(0.55)
			m.next_pass = line if lines else null

	_paint_sea(flat)

	# Light and shade.
	var size := _value("Sun size") if _on("Soft shadows") else 0.5
	sky.sun.light_angular_distance = size
	sky.moonlight.light_angular_distance = size
	var night := 1.0 - sky.daylight
	_porch.light_energy = 1.6 * night
	_porch.visible = night > 0.01
	_porch_mat.emission_energy_multiplier = 4.0 * night
	for lantern in _lanterns:
		lantern.set_lit(night)
	if _on("Coloured shade"):
		# The chosen shade by day, a deep blue at night.
		var shade := (_panel.pickers["Shade colour"] as ColorPickerButton).color
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_env.ambient_light_color = shade.lerp(NIGHT_SHADE, night)
		_env.ambient_light_energy = _value("Shade brightness") * lerpf(1.0, 0.35, night)
	else:
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		_env.ambient_light_energy = 1.0

	# The finished picture.
	_env.adjustment_enabled = _on("Gentle grade")
	_env.adjustment_contrast = _value("Contrast")
	_env.adjustment_saturation = _value("Saturation")
	_env.glow_enabled = _on("Glow")
	_env.glow_intensity = _value("Glow strength")
	_env.fog_enabled = _on("Haze")
	_env.fog_density = _value("Haze thickness")
	_env.fog_light_color = sky.haze_colour
	# Soft focus would blur the stars away, so it fades out as night falls.
	_camera_look.dof_blur_far_enabled = _on("Soft focus") and sky.daylight > 0.01
	_camera_look.dof_blur_far_distance = _value("Sharp up to (m)")
	_camera_look.dof_blur_amount = 0.03 * sky.daylight
	_camera_look.auto_exposure_enabled = _on("Eyes adjust") and not _on("Storybook sky")
	_foam_mat.albedo_texture = _foam_crisp if _on("Foam line") else _foam_soft


## ---- the light and the air -------------------------------------------------

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
	_env.adjustment_brightness = 1.03
	_env.glow_bloom = 0.15
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	_env.fog_sun_scatter = 0.1
	_env.fog_sky_affect = 0.0
	_env.fog_aerial_perspective = 0.4
	_camera_look = CameraAttributesPractical.new()
	_camera_look.dof_blur_far_transition = 80.0
	_camera_look.auto_exposure_speed = 1.0
	# The darkest the exposure meter takes the picture to be, which limits
	# how far it brightens a night scene (chosen by eye: the moonlit beach
	# readable, the sky still black).
	_camera_look.auto_exposure_min_sensitivity = 40.0
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	world_env.camera_attributes = _camera_look
	add_child(world_env)


## ---- materials -------------------------------------------------------------

## A surface's material in both looks. `dir` names a scanned set under
## textures/ (or "" for none), `scale` its repeats a metre, `real` the
## tint over the photograph (or the colour where there is none), `flat`
## the flat look's colour. Extra keys pass through (water, glow, normal).
func surface(dir: String, scale: float, real: Color, rough: float, flat: Color,
		extra: Dictionary = {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	var s := {"mat": m, "real": real, "rough": rough, "flat": flat}
	if dir != "":
		var base := "res://textures/%s/" % dir
		s["albedo"] = load(base + "albedo.jpg")
		s["normal"] = true
		m.normal_texture = load(base + "normal.jpg") as Texture2D
		s["rough_tex"] = load(base + "roughness.jpg")
	if extra.has("bumps"):
		s["normal"] = true
		m.normal_texture = extra["bumps"]
	for key: String in extra:
		if key != "bumps":
			s[key] = extra[key]
	if not s.get("water", false) and not s.get("no_line", false):
		var line := StandardMaterial3D.new()
		line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line.cull_mode = BaseMaterial3D.CULL_FRONT
		line.grow = true
		line.disable_receive_shadows = true
		s["line"] = line
	_surfaces.append(s)
	return m


## Bumps made from engine noise, for surfaces with no scan (leaves).
func _noise_bumps(seed_value: int, frequency: float, strength: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = frequency
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = strength
	tex.noise = noise
	return tex


## ---- the ground ------------------------------------------------------------

## Height of the ground at (x, z): a gentle cone that crosses the sea's
## level at the coast (its radius wavering with the bearing), a hill,
## low hummocks inland, and a flat seabed far out.
func height(x: float, z: float) -> float:
	var bearing := atan2(z, x)
	var coast := R * (1.0 + 0.12 * _coast_noise.get_noise_2d(cos(bearing) * 1.3, sin(bearing) * 1.3))
	var q := sqrt(x * x + z * z) / coast
	var h := 4.0 * (1.0 - q)
	h += 6.5 * exp(-((x - HILL.x) ** 2 + (z - HILL.y) ** 2) / (18.0 * 18.0))
	h += 0.8 * smoothstep(1.0, 0.6, q) * _hump_noise.get_noise_2d(x, z)
	return maxf(h, FLOOR)


func _normal(x: float, z: float) -> Vector3:
	var e := 0.25
	return Vector3(height(x - e, z) - height(x + e, z), 2.0 * e, height(x, z - e) - height(x, z + e)).normalized()


## Above zero, grass; below, sand. The line wanders about a metre above
## the sea.
func _grassiness(x: float, z: float, h: float) -> float:
	return h - 0.9 - 0.35 * _edge_noise.get_noise_2d(x, z)


## Where along a bearing the ground falls through `level`.
func coast(bearing: float, level: float) -> float:
	var d := Vector2(cos(bearing), sin(bearing))
	var r := EXTENT
	while r > 0.0 and height(d.x * r, d.y * r) < level:
		r -= 1.0
	var lo := r
	var hi := r + 1.0
	for i in 14:
		var mid := (lo + hi) * 0.5
		if height(d.x * mid, d.y * mid) >= level:
			lo = mid
		else:
			hi = mid
	return lo


## The height field as triangles on a grid, each cut along the grass
## line into its sand part and its grass part, so the line between them
## is smooth rather than stepped.
func _build_ground() -> void:
	var n := int(EXTENT * 2.0 / GRID) + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = height(-EXTENT + i * GRID, -EXTENT + j * GRID)
	var faces := PackedVector3Array()
	for j in n - 1:
		for i in n - 1:
			var p := [Vector3(), Vector3(), Vector3(), Vector3()]
			var k := 0
			for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				p[k] = Vector3(-EXTENT + (i + c.x) * GRID, heights[(j + c.y) * n + i + c.x], -EXTENT + (j + c.y) * GRID)
				k += 1
			for tri: Array in [[p[0], p[1], p[2]], [p[1], p[3], p[2]]]:
				var a: Vector3 = tri[0]
				var b: Vector3 = tri[1]
				var c3: Vector3 = tri[2]
				if a.y <= FLOOR + 0.01 and b.y <= FLOOR + 0.01 and c3.y <= FLOOR + 0.01:
					continue
				faces.append_array(_upward(a, b, c3))
				_split(tri)
	var mesh := ArrayMesh.new()
	var sand_mat := surface("sand", 0.5, Color(1.0, 0.97, 0.92), 0.9, Color(0.98, 0.87, 0.64))
	var grass_mat := surface("grass", 0.7, Color(0.85, 0.92, 0.8), 0.95, Color(0.5, 0.78, 0.36))
	for k in 2:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _ground[k * 2]
		arrays[Mesh.ARRAY_NORMAL] = _ground[k * 2 + 1]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(k, sand_mat if k == 0 else grass_mat)
	_ground.clear()
	var view := MeshInstance3D.new()
	view.mesh = mesh
	add_child(view)
	var body := StaticBody3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collide := CollisionShape3D.new()
	collide.shape = shape
	body.add_child(collide)
	add_child(body)


## The sea's ripple bumps, shared with the salt works' water.
func sea_ripples() -> Texture2D:
	return _sea_mat.normal_texture


## A triangle in the order the engine draws as facing up.
func _upward(a: Vector3, b: Vector3, c: Vector3) -> PackedVector3Array:
	if (c - a).cross(b - a).y < 0.0:
		return PackedVector3Array([a, c, b])
	return PackedVector3Array([a, b, c])


## One triangle cut where the grassiness crosses zero: the part below
## goes to the sand's points and normals (`_ground` 0 and 1), the part
## above to the grass's (2 and 3), each fanned into triangles.
func _split(tri: Array) -> void:
	var g: Array[float] = []
	for v: Vector3 in tri:
		g.append(_grassiness(v.x, v.z, v.y))
	var lo: Array[Vector3] = []
	var hi: Array[Vector3] = []
	for i in 3:
		var j := (i + 1) % 3
		var vi: Vector3 = tri[i]
		var vj: Vector3 = tri[j]
		if g[i] < 0.0:
			lo.append(vi)
		else:
			hi.append(vi)
		if (g[i] < 0.0) != (g[j] < 0.0):
			var cut := vi.lerp(vj, g[i] / (g[i] - g[j]))
			lo.append(cut)
			hi.append(cut)
	# Held as plain locals and written back: a packed array taken out of
	# an Array is a copy.
	for side in 2:
		var poly: Array[Vector3] = lo if side == 0 else hi
		var points: PackedVector3Array = _ground[side * 2]
		var normals: PackedVector3Array = _ground[side * 2 + 1]
		for k in range(1, poly.size() - 1):
			for v: Vector3 in _upward(poly[0], poly[k], poly[k + 1]):
				points.append(v)
				normals.append(_normal(v.x, v.z))
		_ground[side * 2] = points
		_ground[side * 2 + 1] = normals


## ---- the sea ---------------------------------------------------------------

## A disc 1.5 km across at the sea's level, in rings: close together
## over the island's shallows, wider apart far out. Each point's vertex
## colour is set from the depth of the ground under it (`_paint_sea`);
## its picture coordinates are its position, for the ripple bumps.
func _build_sea() -> void:
	var radii: Array[float] = [0.0]
	var r := 0.0
	while r < 1500.0:
		r += 2.0 if r < 110.0 else r * 0.12
		radii.append(minf(r, 1500.0))
	var segments := 160
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	for ring in radii.size():
		for s in segments:
			var a := TAU * s / segments
			var p := Vector3(cos(a) * radii[ring], 0.0, sin(a) * radii[ring])
			points.append(p)
			uvs.append(Vector2(p.x, p.z) / 9.0)
			var depth := -height(p.x, p.z) if radii[ring] < EXTENT else -FLOOR
			_sea_depth.append(1.0 - smoothstep(0.0, 3.5, depth))
	var index := PackedInt32Array()
	for ring in radii.size() - 1:
		for s in segments:
			var a := ring * segments + s
			var b := ring * segments + (s + 1) % segments
			var c := a + segments
			var d := b + segments
			index.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var normals := PackedVector3Array()
	normals.resize(points.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	var tangents := PackedFloat32Array()
	for i in points.size():
		tangents.append_array([1.0, 0.0, 0.0, 1.0])
	arrays[Mesh.ARRAY_TANGENT] = tangents
	var colours := PackedColorArray()
	colours.resize(points.size())
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = index
	# The engine draws a triangle facing up when its points run clockwise
	# seen from above; check one in the second ring (the first ring's
	# points all lie at the centre) and turn them all if not.
	var t0 := segments * 6
	if (points[index[t0 + 2]] - points[index[t0]]).cross(points[index[t0 + 1]] - points[index[t0]]).y < 0.0:
		for t in range(0, index.size(), 3):
			var keep := index[t + 1]
			index[t + 1] = index[t + 2]
			index[t + 2] = keep
		arrays[Mesh.ARRAY_INDEX] = index
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
	_sea_mat = surface("", 1.0, Color.WHITE, 0.05, Color.WHITE, {"water": true, "bumps": ripple})
	_sea_mat.uv1_triplanar = false
	_sea_mat.uv1_world_triplanar = false
	_sea_mat.uv1_scale = Vector3.ONE
	_sea_mat.vertex_color_use_as_albedo = true
	_sea_mat.vertex_color_is_srgb = true
	_sea = MeshInstance3D.new()
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_sea.mesh = mesh
	add_child(_sea)


## The sea's colours: from deep to shallow by the depth under each
## point; dark and greenish as photographed, turquoise in the flat look,
## where it darkens to inky blues at night (as photographed the sea's own
## colour is dark enough, and the light alone dims it).
func _paint_sea(flat: bool) -> void:
	var deep := Color(0.012, 0.05, 0.07)
	var shallow := Color(0.14, 0.26, 0.22)
	if flat:
		deep = Color(0.04, 0.1, 0.22).lerp(Color(0.16, 0.5, 0.78), sky.daylight)
		shallow = Color(0.1, 0.24, 0.32).lerp(Color(0.5, 0.88, 0.82), sky.daylight)
	var mesh := _sea.mesh as ArrayMesh
	var arrays := mesh.surface_get_arrays(0)
	var colours := PackedColorArray()
	colours.resize(_sea_depth.size())
	for i in _sea_depth.size():
		colours[i] = deep.lerp(shallow, _sea_depth[i])
	arrays[Mesh.ARRAY_COLOR] = colours
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _sea_mat)


## A band of foam round the coast, from half a metre up the beach to two
## and a half out to sea, its whiteness across the band from a gradient
## picture: soft, or crisp-edged in the flat look. It swells and sinks
## with a slow swell (`_process`).
func _build_foam() -> void:
	var segments := 256
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	for s in segments + 1:
		var a := TAU * s / segments
		var r := coast(a, 0.0)
		var d := Vector3(cos(a), 0.0, sin(a))
		points.append(d * (r - 0.5) + Vector3.UP * 0.03)
		points.append(d * (r + 2.5) + Vector3.UP * 0.03)
		uvs.append(Vector2(0.0, 0.0))
		uvs.append(Vector2(1.0, 0.0))
	var index := PackedInt32Array()
	for s in segments:
		var a := s * 2
		index.append_array(_upward_index(points, [a, a + 1, a + 2]))
		index.append_array(_upward_index(points, [a + 1, a + 3, a + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var normals := PackedVector3Array()
	normals.resize(points.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_foam_soft = _foam_band(Gradient.GRADIENT_INTERPOLATE_LINEAR,
			[0.0, 0.14, 0.2, 0.45, 1.0], [0.0, 0.5, 0.75, 0.25, 0.0])
	_foam_crisp = _foam_band(Gradient.GRADIENT_INTERPOLATE_CONSTANT,
			[0.0, 0.17, 0.3, 0.37, 0.43], [0.0, 0.95, 0.0, 0.7, 0.0])
	_foam_mat = StandardMaterial3D.new()
	_foam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_foam_mat.roughness = 1.0
	_foam_mat.metallic_specular = 0.0
	_foam_mat.texture_repeat = false
	_foam = MeshInstance3D.new()
	_foam.mesh = mesh
	_foam.material_override = _foam_mat
	_foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_foam)


func _upward_index(points: PackedVector3Array, tri: Array) -> PackedInt32Array:
	var a: Vector3 = points[tri[0]]
	var b: Vector3 = points[tri[1]]
	var c: Vector3 = points[tri[2]]
	if (c - a).cross(b - a).y < 0.0:
		return PackedInt32Array([tri[0], tri[2], tri[1]])
	return PackedInt32Array([tri[0], tri[1], tri[2]])


## White, its opacity across the band given at the offsets.
func _foam_band(mode: Gradient.InterpolationMode, offsets: Array, alphas: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.interpolation_mode = mode
	g.offsets = PackedFloat32Array(offsets)
	var colours := PackedColorArray()
	for a: float in alphas:
		colours.append(Color(1, 1, 1, a))
	g.colors = colours
	var tex := GradientTexture1D.new()
	tex.gradient = g
	tex.width = 256
	return tex


func _process(delta: float) -> void:
	_clock += delta
	# Ripples drift with the breeze; the foam swells over ten seconds.
	_sea_mat.uv1_offset = Vector3(_clock * 0.012, _clock * 0.007, 0.0)
	var swell := sin(_clock * TAU / 10.0)
	_foam.scale = Vector3(1.0 + 0.012 * swell, 1.0, 1.0 + 0.012 * swell)
	_foam_mat.albedo_color.a = 0.85 + 0.15 * swell
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		sky.follow(camera.global_position)
	# What the player looks at tells what it is (the salt works' parts).
	var view: Node = player.look_view()
	if view != _hovered:
		if _hovered != null and is_instance_valid(_hovered) and _hovered.has_method("show_label"):
			_hovered.call("show_label", false)
		_hovered = view
		if view != null and view.has_method("show_label"):
			view.call("show_label", true)


## ---- the cabin and the dock ------------------------------------------------

func _solid(size: Vector3, at: Vector3, mat: Material, mesh: PrimitiveMesh = null,
		collide := true) -> MeshInstance3D:
	if mesh == null:
		var box := BoxMesh.new()
		box.size = size
		mesh = box
	mesh.material = mat
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	if collide:
		var body := StaticBody3D.new()
		body.position = at
		var shape := BoxShape3D.new()
		shape.size = size
		var c := CollisionShape3D.new()
		c.shape = shape
		body.add_child(c)
		add_child(body)
	add_child(view)
	return view


## A one-room cabin with a pitched roof, its door to the south, on a
## stone base reaching down into the slope.
func _build_cabin() -> void:
	var hx := CABIN_SIZE.x * 0.5
	var hz := CABIN_SIZE.z * 0.5
	var top := -INF
	for c: Vector2 in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(-hx, hz), Vector2(hx, hz)]:
		top = maxf(top, height(CABIN.x + c.x, CABIN.z + c.y))
	var floor_y := top + 0.3
	var walls := surface("wood_floor", 0.6, Color(0.78, 0.72, 0.64), 0.8, Color(0.95, 0.87, 0.72))
	var base := surface("rough_rock", 0.5, Color(0.75, 0.75, 0.75), 0.9, Color(0.66, 0.64, 0.66))
	var roof := surface("", 1.0, Color(0.3, 0.12, 0.09), 0.75, Color(0.86, 0.42, 0.33),
			{"bumps": _noise_bumps(17, 0.05, 3.0)})
	var door := surface("wood_floor", 0.6, Color(0.35, 0.27, 0.22), 0.7, Color(0.38, 0.6, 0.78))
	var glass := surface("", 1.0, Color(0.04, 0.05, 0.06), 0.08, Color(1.0, 0.86, 0.5),
			{"glow": Color(1.0, 0.8, 0.45), "no_line": true})
	var stone := surface("old_stone_bricks", 1.0 / 1.8, Color(0.85, 0.85, 0.85), 0.9, Color(0.72, 0.66, 0.62))
	var c := Vector3(CABIN.x, floor_y, CABIN.z)
	var depth := floor_y - minf(height(CABIN.x - hx, CABIN.z + hz), height(CABIN.x + hx, CABIN.z + hz)) + 0.6
	_solid(Vector3(CABIN_SIZE.x + 0.3, depth, CABIN_SIZE.z + 0.3), c + Vector3(0, -depth * 0.5, 0), base)
	_solid(CABIN_SIZE, c + Vector3(0, CABIN_SIZE.y * 0.5, 0), walls)
	var prism := PrismMesh.new()
	var roof_size := Vector3(CABIN_SIZE.x + 0.7, 1.7, CABIN_SIZE.z + 0.7)
	prism.size = roof_size
	_solid(roof_size, c + Vector3(0, CABIN_SIZE.y + roof_size.y * 0.5, 0), roof, prism, false)
	_solid(Vector3(0.9, 1.95, 0.08), c + Vector3(0, 0.975, hz + 0.02), door, null, false)
	for x: float in [-1.0, 1.0]:
		_solid(Vector3(0.05, 0.8, 0.7), c + Vector3(x * (hx + 0.01), 1.4, 0.4), glass, null, false)
	_solid(Vector3(0.6, 0.8, 0.05), c + Vector3(1.2, 1.4, hz + 0.01), glass, null, false)
	_solid(Vector3(0.6, 4.6, 0.6), c + Vector3(-hx + 0.6, 2.3, -hz + 0.9), stone)
	# The porch lamp beside the door, lit from dusk.
	_porch_mat = StandardMaterial3D.new()
	_porch_mat.albedo_color = Color(1.0, 0.9, 0.7)
	_porch_mat.emission_enabled = true
	_porch_mat.emission = Color(1.0, 0.72, 0.4)
	var lamp_at := c + Vector3(-0.75, 2.0, hz + 0.12)
	var lantern := _solid(Vector3(0.14, 0.2, 0.14), lamp_at, _porch_mat, null, false)
	lantern.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_porch = OmniLight3D.new()
	_porch.light_color = Color(1.0, 0.72, 0.4)
	_porch.omni_range = 9.0
	_porch.position = lamp_at + Vector3(0, 0, 0.15)
	add_child(_porch)


## A plank dock from the beach out over the shallows on the south side,
## on posts.
func _build_dock() -> void:
	var coast := coast(PI * 0.5, 0.0)
	_dock_z0 = coast - 3.0
	_dock_z1 = coast + 11.0
	var wood := surface("wood_floor", 0.6, Color(0.55, 0.5, 0.45), 0.85, Color(0.78, 0.6, 0.42))
	var plank := 0.22
	var z := _dock_z0
	while z + plank <= _dock_z1:
		_solid(Vector3(DOCK_W, 0.06, plank), Vector3(DOCK_X, DOCK_Y, z + plank * 0.5), wood, null, false)
		z += plank + 0.03
	var length := _dock_z1 - _dock_z0
	var body := StaticBody3D.new()
	body.position = Vector3(DOCK_X, DOCK_Y, (_dock_z0 + _dock_z1) * 0.5)
	var shape := BoxShape3D.new()
	shape.size = Vector3(DOCK_W, 0.06, length)
	var c := CollisionShape3D.new()
	c.shape = shape
	body.add_child(c)
	add_child(body)
	for pz: float in [_dock_z0 + 0.6, _dock_z0 + length * 0.5, _dock_z1 - 0.2]:
		for side: float in [-1.0, 1.0]:
			var post := CylinderMesh.new()
			post.top_radius = 0.09
			post.bottom_radius = 0.09
			var px := DOCK_X + side * (DOCK_W * 0.5 - 0.05)
			var bottom := height(px, pz) - 0.3
			var top := DOCK_Y + 0.35
			post.height = top - bottom
			_solid(Vector3.ONE * 0.18, Vector3(px, (top + bottom) * 0.5, pz), wood, post, false)


## ---- trees and rocks -------------------------------------------------------

func _build_trees() -> void:
	var bark := surface("bark", 1.0, Color(0.85, 0.85, 0.85), 0.9, Color(0.56, 0.41, 0.3))
	var leaves := surface("", 1.5, Color(0.11, 0.22, 0.06), 0.8, Color(0.42, 0.72, 0.34),
			{"bumps": _noise_bumps(29, 0.04, 6.0)})
	var needles := surface("", 2.0, Color(0.05, 0.13, 0.07), 0.85, Color(0.22, 0.55, 0.42),
			{"bumps": _noise_bumps(31, 0.06, 6.0)})
	var rng := RandomNumberGenerator.new()
	rng.seed = 1874
	var placed: Array[Vector2] = []
	var works := SaltWorks.centre(self)
	var tries := 0
	while placed.size() < 16 and tries < 600:
		tries += 1
		var p := Vector2(rng.randf_range(-R, R), rng.randf_range(-R, R))
		var h := height(p.x, p.y)
		if _grassiness(p.x, p.y, h) < 0.4:
			continue
		if p.distance_to(Vector2(CABIN.x, CABIN.z)) < 7.0 or absf(p.x - DOCK_X) < 4.0 and p.y > 10.0:
			continue
		if p.distance_to(Vector2(works.x, works.z)) < 20.0:
			continue
		var crowded := false
		for q: Vector2 in placed:
			crowded = crowded or p.distance_to(q) < 6.0
		if crowded:
			continue
		placed.append(p)
		var size := rng.randf_range(0.8, 1.25)
		var base := Vector3(p.x, h - 0.2, p.y)
		if rng.randf() < 0.5:
			_round_tree(base, size, bark, leaves, rng)
		else:
			_pine(base, size, bark, needles)


func _trunk(base: Vector3, height: float, radius: float, bark: Material) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = radius * 0.6
	trunk.bottom_radius = radius
	trunk.height = height
	var view := _solid(Vector3.ONE, base + Vector3.UP * height * 0.5, bark, trunk, false)
	var body := StaticBody3D.new()
	body.position = view.position
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var c := CollisionShape3D.new()
	c.shape = shape
	body.add_child(c)
	add_child(body)


## A broad-leaved tree: a trunk and a cluster of four balls of leaves.
func _round_tree(base: Vector3, size: float, bark: Material, leaves: Material,
		rng: RandomNumberGenerator) -> void:
	var height := 3.2 * size
	_trunk(base, height, 0.22 * size, bark)
	var crown := base + Vector3.UP * (height + 0.6 * size)
	_crowns.append(Vector4(crown.x, crown.y, crown.z, size))
	for k in 4:
		var ball := SphereMesh.new()
		var r := size * (1.7 if k == 0 else rng.randf_range(1.0, 1.3))
		ball.radius = r
		ball.height = r * 2.0
		var off := Vector3.ZERO
		if k > 0:
			var a := TAU * k / 3.0 + rng.randf()
			off = Vector3(cos(a) * 1.3 * size, -0.4 * size, sin(a) * 1.3 * size)
		_solid(Vector3.ONE, crown + off, leaves, ball, false)


## A pine: a trunk and three cones of needles.
func _pine(base: Vector3, size: float, bark: Material, needles: Material) -> void:
	var height := 2.0 * size
	_trunk(base, height + 3.0 * size, 0.16 * size, bark)
	for k in 3:
		var cone := CylinderMesh.new()
		var w := (2.0 - 0.5 * k) * size
		cone.top_radius = 0.0
		cone.bottom_radius = w
		cone.height = 2.6 * size
		_solid(Vector3.ONE, base + Vector3.UP * (height + 1.1 * size * k + 1.3 * size), needles, cone, false)


## Boulders: balls with their surfaces pushed in and out by noise, on the
## beach and by the hill.
func _build_rocks() -> void:
	var rock := surface("rough_rock", 0.4, Color(0.8, 0.78, 0.76), 0.9, Color(0.68, 0.68, 0.74))
	var lumps := FastNoiseLite.new()
	lumps.seed = 41
	lumps.frequency = 0.9
	var spots: Array[Vector4] = [   # bearing (degrees), metres past the coast, size, seed
		Vector4(60, -2.0, 1.4, 1), Vector4(66, -0.5, 0.8, 2), Vector4(140, -1.0, 1.8, 3),
		Vector4(200, 0.5, 1.2, 4), Vector4(300, -1.5, 2.2, 5), Vector4(310, 0.8, 1.0, 6),
		Vector4(110, -1.8, 0.7, 7)]
	for s: Vector4 in spots:
		var a := deg_to_rad(s.x)
		var r := coast(a, 0.0) + s.y
		_boulder(Vector3(cos(a) * r, 0.0, sin(a) * r), s.z, int(s.w), rock, lumps)
	for s: Vector3 in [Vector3(-16, -2, 1.6), Vector3(-6, -15, 1.1), Vector3(-19, -12, 0.9)]:
		_boulder(Vector3(s.x, 0.0, s.y), s.z, 8 + int(s.x), rock, lumps)


## ---- the campfire and the lanterns ---------------------------------------

## A ring of stones on the sand six metres up the beach from the water,
## east of the dock, three charred logs crossed in it and the fire on
## them, and two logs to sit on.
func _build_campfire() -> void:
	var a := deg_to_rad(FIRE_BEARING)
	var r := coast(a, 0.0) - 6.0
	_fire_at = Vector3(cos(a) * r, 0.0, sin(a) * r)
	_fire_at.y = height(_fire_at.x, _fire_at.z)
	var stone := surface("rough_rock", 1.2, Color(0.7, 0.68, 0.66), 0.9, Color(0.6, 0.6, 0.66))
	var charred := surface("bark", 1.5, Color(0.22, 0.19, 0.17), 0.9, Color(0.36, 0.26, 0.22))
	var seat := surface("bark", 1.0, Color(0.8, 0.78, 0.74), 0.9, Color(0.62, 0.45, 0.32))
	var lumps := FastNoiseLite.new()
	lumps.seed = 57
	lumps.frequency = 0.9
	for k in 9:
		var t := TAU * k / 9.0
		var at := _fire_at + Vector3(cos(t), 0.0, sin(t)) * 0.62
		_boulder(at, 0.2 + 0.04 * sin(k * 2.7), 60 + k, stone, lumps)
	for k in 3:
		var log := CylinderMesh.new()
		log.top_radius = 0.07
		log.bottom_radius = 0.08
		log.height = 0.7
		log.radial_segments = 10
		# Leaning in a low cone, their upper ends meeting over the middle.
		var out := Vector3(cos(TAU * k / 3.0), 0.0, sin(TAU * k / 3.0))
		var view := _solid(Vector3.ONE, _fire_at + out * 0.2 + Vector3(0, 0.16, 0), charred, log, false)
		view.basis = Basis(out.cross(Vector3.UP).normalized(), 1.1)
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side: float in [-1.0, 1.0]:
		var t := a + side * 1.1 + PI
		var at := _fire_at + Vector3(cos(t), 0.0, sin(t)) * 1.9
		at.y = height(at.x, at.z) + 0.14
		var log := CylinderMesh.new()
		log.top_radius = 0.17
		log.bottom_radius = 0.19
		log.height = 1.6
		var view := _solid(Vector3.ONE, at, seat, log, false)
		# Lying on its side, square to the line to the fire.
		view.basis = Basis(Vector3.UP, -t) * Basis(Vector3.RIGHT, PI * 0.5)
		var body := StaticBody3D.new()
		body.transform = view.transform
		var shape := CylinderShape3D.new()
		shape.radius = 0.18
		shape.height = 1.6
		var c := CollisionShape3D.new()
		c.shape = shape
		body.add_child(c)
		add_child(body)
	var fire := Campfire.new()
	fire.position = _fire_at + Vector3(0, 0.08, 0)
	add_child(fire)


## Lanterns hung from the broad-leaved trees nearest the cabin, each from
## the underside of the crown on the side toward the cabin.
func _build_lanterns() -> void:
	var frame := surface("", 1.0, Color(0.06, 0.06, 0.06), 0.45, Color(0.28, 0.24, 0.32), {"no_line": true})
	var cord := surface("", 1.0, Color(0.25, 0.2, 0.15), 0.9, Color(0.45, 0.34, 0.25), {"no_line": true})
	var near := _crowns.duplicate()
	near.sort_custom(func(p: Vector4, q: Vector4) -> bool:
		return Vector2(p.x, p.z).distance_to(Vector2(CABIN.x, CABIN.z)) < Vector2(q.x, q.z).distance_to(Vector2(CABIN.x, CABIN.z)))
	for k in mini(LANTERNS, near.size()):
		var c: Vector4 = near[k]
		var toward := Vector3(CABIN.x - c.x, 0.0, CABIN.z - c.z).normalized()
		# Where a line 1.5 sizes out from the trunk meets the main ball's
		# underside (its radius 1.7 sizes).
		var anchor := Vector3(c.x, c.y, c.z) + toward * 1.5 * c.w + Vector3.DOWN * 0.8 * c.w
		var lantern := HangingLantern.new(frame, cord, k * 1.9)
		lantern.position = anchor
		add_child(lantern)
		_lanterns.append(lantern)


func _boulder(at: Vector3, size: float, seed_value: int, mat: Material, lumps: FastNoiseLite) -> void:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 24
	sphere.rings = 12
	var arrays := sphere.get_mesh_arrays()
	var src: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var stretch := Vector3(1.0 + 0.2 * sin(seed_value), 0.7, 1.0 + 0.2 * cos(seed_value * 1.7))
	# Points rebuilt from positions alone, so the sphere's seam (points
	# doubled for its picture coordinates) is merged and shades smoothly.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in index:
		var v := src[i]
		var bump := 1.0 + 0.22 * lumps.get_noise_3d(v.x * 2.0 + seed_value * 7.0, v.y * 2.0, v.z * 2.0)
		st.add_vertex(v * 2.0 * size * bump * stretch)
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	var view := MeshInstance3D.new()
	view.mesh = mesh
	var ground := height(at.x, at.z)
	view.position = Vector3(at.x, ground + size * 0.25, at.z)
	view.rotation.y = seed_value * 1.3
	add_child(view)
	var body := StaticBody3D.new()
	body.position = view.position
	var shape := SphereShape3D.new()
	shape.radius = size * 0.8
	var c := CollisionShape3D.new()
	c.shape = shape
	body.add_child(c)
	add_child(body)


## ---- keeping the player on land -------------------------------------------

## Invisible walls where the sea is knee-deep, open where the dock leaves
## the shore, and along the dock's sides and end.
func _build_bounds() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var segments := 96
	var points: Array[Vector3] = []
	for s in segments:
		var a := TAU * s / segments
		var r := coast(a, -0.5)
		points.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	var hw := DOCK_W * 0.5
	var gap: Array[Vector3] = []          # the ring's ends either side of the dock
	for s in segments:
		var a := points[s]
		var b := points[(s + 1) % segments]
		if a.z > 0.0 and maxf(a.x, b.x) > DOCK_X - hw - 0.3 and minf(a.x, b.x) < DOCK_X + hw + 0.3:
			if gap.is_empty():
				gap = [a, b]
			gap[1] = b
			continue
		_wall(body, a, b)
	# The ring's ends joined to the dock's sides, which run out to its end.
	for end: Vector3 in gap:
		var x := DOCK_X - hw if end.x < DOCK_X else DOCK_X + hw
		_wall(body, end, Vector3(x, 0, end.z))
		_wall(body, Vector3(x, 0, end.z), Vector3(x, 0, _dock_z1))
	_wall(body, Vector3(DOCK_X - hw, 0, _dock_z1), Vector3(DOCK_X + hw, 0, _dock_z1))


func _wall(body: StaticBody3D, a: Vector3, b: Vector3) -> void:
	var along := b - a
	var shape := BoxShape3D.new()
	shape.size = Vector3(along.length() + 0.4, 6.0, 0.2)
	var c := CollisionShape3D.new()
	c.shape = shape
	c.position = (a + b) * 0.5 + Vector3.UP * 1.5
	c.rotation.y = -atan2(along.z, along.x)
	body.add_child(c)
