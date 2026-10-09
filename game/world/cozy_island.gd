class_name CozyIsland
extends Node3D
## An island about 300 m across in a calm sea under an afternoon sun: a
## beach all round, meadows above it with hills, woods, rocky outcrops
## and wild flowers, dunes to the north, a cabin, a dock. A
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
## - Storybook sky: the engine's procedural sky in soft colours, in
##   place of its physical sky; a larger moon with a
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
const PLACE_PATH := "user://cozy_island_place.json"   # where the player stood on leaving
const R := 146.0                       # the coast's mean radius
const HILL := Vector2(-32.0, -25.0)     # the highest hill, the sky works on its top
# Lower hills: x, z, height, radius.
const HILLS := [Vector4(-32.0, -25.0, 14.0, 42.0), Vector4(62.0, -58.0, 7.0, 32.0),
		Vector4(-78.0, 52.0, 6.0, 34.0), Vector4(48.0, 52.0, 4.0, 26.0), Vector4(-20.0, -105.0, 5.0, 28.0)]
const EXTENT := 300.0                  # half the ground's square: out past the spits and the lagoon's sandbar
const GRID := 1.5
const FLOOR := -4.0                    # the seabed's depth far out
const CABIN_INLAND := 25.0             # the cabin's distance up from the south shore
const CABIN_SIZE := Vector3(4.0, 2.4, 5.0)
const DOCK_X := 4.0
const DOCK_W := 1.6
const DOCK_Y := 0.6
const NIGHT_SHADE := Color(0.22, 0.28, 0.6)
const LAGOON_BEARING := 30.0           # degrees round from +x toward +z
const LAGOON_HALF := 11.0               # degrees either side, fading over 5 more
const LAGOON_FLOOR := -1.1
const LAGOON_OUT := 76.0                # the sandbar's crest beyond the shore
# The north: a lobe of sand dunes reaching 30% further out than the
# shore elsewhere, two sand spits running on out to sea, and a sheltered
# round bay in the dunes opening to the sea by one narrow inlet.
const NORTH_BEARING := -90.0
const NORTH_HALF := 20.0                # degrees either side, fading over 14 more
const NORTH_OUT := 0.3
const BAY := Vector2(27.0, -152.6)
const BAY_R := 13.0
const INLET_DIR := Vector2(0.6, -0.8)
const INLET_FROM := 10.0                # m from the bay's centre
const INLET_TO := 47.0
const INLET_HALF := 2.2
const SPITS := [Vector3(-112.0, 183.0, 70.0), Vector3(-98.0, 194.0, 80.0)]   # bearing, start radius, length
# The west beach between the balloon works and the colour works runs
# wide: a flat of sand WIDE_BEACH metres deep before the land rises, for
# the exposition (CrystalExpo).
const WIDE_BEARING := 203.0
const WIDE_HALF := 17.0                 # degrees either side, fading over 8 more
const WIDE_BEACH := 62.0
const FIRE_BEARING := 105.0            # degrees round from +x toward +z
const LANTERNS := 5
const STEPS := ["Flat colours", "Toon light", "Coloured shade", "Soft shadows", "Outlines",
		"Gentle grade", "Glow", "Haze", "Soft focus", "Storybook sky", "Foam line"]

var player: Player
var sky: IslandSky
var clouds: IslandClouds
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
var _dune_noise := FastNoiseLite.new()
var _roll_noise := FastNoiseLite.new()
var _sandbar := 0.0                    # the lagoon's bar, m from the centre
## The cabin, its floor's height worked out when built.
var cabin := Vector3.ZERO
var _grass_grid := PackedFloat32Array() # grassiness on the ground's grid
var _normal_grid := PackedVector3Array()
var _grid := PackedFloat32Array()       # the ground's heights on its grid, kept for the shorelines
var _grid_n := 0
var _works: Array[Node3D] = []
var _works_gap: Array[CollisionShape3D] = []    # closes the shore where a works' pier was
var _works_pier: Array[CollisionShape3D] = []   # a works' pier's side walls
var _ground := [PackedVector3Array(), PackedVector3Array(), PackedVector3Array(), PackedVector3Array()]
## Walkways out over the water, as [shore point, far point, half width]:
## the invisible walls keeping the player on land open for each and run
## along its sides.
var piers: Array = []
var _dock_z0 := 0.0
var _dock_z1 := 0.0
var _clock := 0.0
var _was_debanding := false
var _was_soft := 0
var _place_left := 3.0
var _labels := true                     # floating labels on what the player looks at
var _good: Array[Vector4] = []          # recent places stood freely on the ground: x, y, z, facing
var _good_left := 0.0
var _wedged := 0.0                      # seconds found inside something
var _probe_capsule := CapsuleShape3D.new()


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
	_dune_noise.seed = 61
	_dune_noise.frequency = 0.03
	_roll_noise.seed = 19
	_roll_noise.frequency = 0.012
	_sandbar = shore_radius(deg_to_rad(LAGOON_BEARING)) + LAGOON_OUT
	_build_environment()
	_build_ground()
	_build_sea()
	_build_foam()
	cabin = Vector3(DOCK_X, 0.0, coast(PI * 0.5, 0.0) - CABIN_INLAND)
	_build_cabin()
	_build_dock()
	_build_trees()
	_build_rocks()
	_build_outcrops()
	_build_flowers()
	_build_campfire()
	_build_lanterns()
	_works.append_array([SaltWorks.new(self), ColourWorks.new(self), BalloonWorks.new(self),
			LagoonWorks.new(self), SkyWorks.new(self), CrystalExpo.new(self), TideWorks.new(self)])
	for works in _works:
		add_child(works)
	var wharf := LagoonWorks.pier(self)
	wharf.append(true)
	piers.append(wharf)
	_build_dune_grass()
	add_child(InnerBay.new(self))
	_build_bounds()
	_lighten()
	clouds = IslandClouds.new(self)
	add_child(clouds)
	_build_panels()
	# Soft shadows need the engine's shadow softening at least at Low,
	# whatever the graphics preset says.
	LabGraphics.attach(self, _panel.panel("Graphics"), func(g: GraphicsSettings) -> void:
		var preset := g.filter_quality()
		RenderingServer.directional_soft_shadow_filter_set_quality(
				maxi(preset, RenderingServer.SHADOW_QUALITY_SOFT_LOW) as RenderingServer.ShadowQuality))
	_panel.restore()
	_apply()
	# The player starts where they stood when they last left, or the
	# first time at the dock's end, looking back at the island.
	player.global_position = Vector3(DOCK_X, DOCK_Y + 0.05, _dock_z1 - 1.0)
	player.rotation.y = 0.0
	if not MouseMode.probe:
		_load_place()
	MouseMode.capture()
	if DisplayServer.get_name() == "headless":
		print("[worldbuilder] cozy island: %d surfaces, coast at %.1f m, dock %.1f to %.1f m"
				% [_surfaces.size(), coast(PI * 0.5, 0.0), _dock_z0, _dock_z1])


func _exit_tree() -> void:
	_save_place()
	get_viewport().use_debanding = _was_debanding
	RenderingServer.directional_soft_shadow_filter_set_quality(_was_soft as RenderingServer.ShadowQuality)


## Everything built made cheap to draw (StaticMerge): round shapes given
## only the sides their size needs, every piece that never moves joined
## into one mesh per material per works, small separate details faded
## out at a distance.
func _lighten() -> void:
	var shared: Array = []
	for s: Dictionary in _surfaces:
		shared.append(s["mat"])
	var simplified := StaticMerge.simplify(self)
	var merged := StaticMerge.merge(self, shared)
	StaticMerge.fade_details(self)
	if DisplayServer.get_name() == "headless":
		print("[worldbuilder] cozy island: %d shapes simplified, %d pieces joined into %d meshes" % [simplified, merged.x, merged.y])


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
	_panel.slider(steps, "Sharp up to (m)", 5.0, 250.0, 1.0, 80.0, redraw)
	_panel.note(steps, "The camera's depth of field: what is farther than this blurs gradually, which also makes the island read as small, like a model.")

	_panel.heading(steps, "Setting")
	_panel.switch(steps, "Storybook sky", false, redraw)
	_panel.note(steps, "Off, the engine's physical sky: the colour of air lit by the sun. On, its simpler sky drawn from a few chosen colours that change through sunset and dusk to night; the moon larger with a crisp edge, and only the brightest stars, as sparkles.")
	_panel.switch(steps, "Foam line", false, redraw)
	_panel.note(steps, "Where the sea meets the beach, a crisp white band in place of a soft one. Both rise and fall with the swell.")

	var isle := _panel.panel("Island")
	_panel.switch(isle, "Works and machines", true, func(v: bool) -> void: _set_works(v))
	_panel.switch(isle, "Floating labels", true, func(v: bool) -> void: _labels = v)
	_panel.note(isle, "All the works and the exposition, their machines, beams and sounds. Off, the island is left to itself: the beaches, the dunes and the bay, the cabin, the campfire and the lanterns.")

	var wx := _panel.panel("Weather")
	_panel.slider(wx, "Clouds", 0.0, 1.0, 0.05, 0.4, func(v: float) -> void: clouds.amount = v)
	_panel.note(wx, "Fair-weather clouds: from a clear sky to one well filled. New clouds form and old ones melt away to match, over a minute or so.")

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
			line.albedo_color = s.get("line_colour", (s["flat"] as Color).darkened(0.55))
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

## Height of the ground at (x, z): rising from the shore (its distance
## from the middle wavering with the bearing) at a beach's slope and
## levelling off inland at about five metres, falling the same way under
## the sea to a flat seabed; inland, hills, rolling meadows and hummocks.
func height(x: float, z: float) -> float:
	var bearing := atan2(z, x)
	var north := north_weight(bearing)
	var shore := shore_radius(bearing)
	var r := sqrt(x * x + z * z)
	var s := shore - r                  # metres inland of the shore
	var h := 5.5 * tanh(s / 55.0)
	# The wide beach: a gentle rise of 4 cm a metre across the flat, then
	# the land's usual rise behind it.
	var wide := wide_weight(bearing)
	if wide > 0.0 and s > 0.0:
		var flat := 0.04 * minf(s, WIDE_BEACH) + 4.4 * tanh(maxf(s - WIDE_BEACH, 0.0) / 55.0)
		h = lerpf(h, flat, wide)
	var inland := smoothstep(WIDE_BEACH * wide, 40.0 + WIDE_BEACH * wide, s)
	# The hills stand back from the wide beach's flat, rising behind it.
	var hills := 1.0 - wide * smoothstep(WIDE_BEACH + 12.0, WIDE_BEACH - 4.0, s)
	for hill: Vector4 in HILLS:
		h += hills * hill.z * exp(-((x - hill.x) ** 2 + (z - hill.y) ** 2) / (hill.w * hill.w))
	h += inland * (2.2 * _roll_noise.get_noise_2d(x, z) + 0.7 * _hump_noise.get_noise_2d(x, z))
	# The lagoon: in its sector the seabed holds at a shallow sand floor
	# out to a sandbar whose crest just breaks the surface.
	var off := absf(angle_difference(bearing, deg_to_rad(LAGOON_BEARING)))
	var inside := smoothstep(deg_to_rad(LAGOON_HALF + 8.0), deg_to_rad(LAGOON_HALF), off)
	if inside > 0.0:
		var lagoon := h
		if r < _sandbar:
			lagoon = maxf(h, LAGOON_FLOOR + 0.15 * _hump_noise.get_noise_2d(x * 2.0, z * 2.0))
		var bar := 0.3 - pow((r - _sandbar) / 7.0, 2.0) * 1.4
		lagoon = maxf(lagoon, bar)
		h = lerpf(h, lagoon, inside)
	if north > 0.0:
		# Dunes: long ridges across the wind, in a band up from the shore.
		var ridge := 1.0 - absf(_dune_noise.get_noise_2d(x * 0.9, z * 2.2))
		h += north * 3.5 * pow(ridge, 3.0) * smoothstep(3.0, 12.0, s) * smoothstep(70.0, 45.0, s)
	# The spits: low ridges of sand running out to sea, their crests just
	# above the water, sinking toward their tips.
	for spit: Vector3 in SPITS:
		var d := Vector2(cos(deg_to_rad(spit.x)), sin(deg_to_rad(spit.x)))
		var p := Vector2(x, z) - d * spit.y
		var t := p.dot(d) / spit.z
		if t > -0.3 and t < 1.15:
			var side := absf(p.dot(Vector2(-d.y, d.x)) - 6.0 * sin(clampf(t, 0.0, 1.0) * PI))
			var crest := 0.5 - 0.8 * clampf(t, 0.0, 1.0) ** 2
			h = maxf(h, crest - pow(side / 5.0, 2.0) * 1.3)
	# The bay and its inlet, carved down through the dunes.
	var db := Vector2(x, z).distance_to(BAY)
	if db < BAY_R + 6.0:
		var bed := -1.15 + 0.5 * (db / BAY_R) ** 2 + 0.08 * _hump_noise.get_noise_2d(x * 3.0, z * 3.0)
		h = minf(h, lerpf(bed, h, smoothstep(BAY_R - 1.5, BAY_R + 4.0, db)))
	var inlet := _inlet_distance(Vector2(x, z))
	if inlet < INLET_HALF + 4.0:
		h = minf(h, lerpf(-0.9, h, smoothstep(INLET_HALF, INLET_HALF + 3.5, inlet)))
	return maxf(h, FLOOR)


## The shore's distance from the middle along a bearing, before the
## lagoon, spits and bay are shaped into it.
func shore_radius(bearing: float) -> float:
	return R * (1.0 + 0.12 * _coast_noise.get_noise_2d(cos(bearing) * 1.3, sin(bearing) * 1.3)) * (1.0 + NORTH_OUT * north_weight(bearing))


## How far into the wide west beach a bearing lies, 0 outside to 1 inside.
static func wide_weight(bearing: float) -> float:
	var off := absf(angle_difference(bearing, deg_to_rad(WIDE_BEARING)))
	return smoothstep(deg_to_rad(WIDE_HALF + 8.0), deg_to_rad(WIDE_HALF), off)


## How far into the north lobe a bearing lies, 0 outside to 1 inside.
static func north_weight(bearing: float) -> float:
	var off := absf(angle_difference(bearing, deg_to_rad(NORTH_BEARING)))
	return smoothstep(deg_to_rad(NORTH_HALF + 14.0), deg_to_rad(NORTH_HALF), off)


## Distance from a point to the inlet's middle line.
static func _inlet_distance(p: Vector2) -> float:
	var a := BAY + INLET_DIR.normalized() * INLET_FROM
	var b := BAY + INLET_DIR.normalized() * INLET_TO
	var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return p.distance_to(a.lerp(b, t))


## Whether a point lies in the bay or its inlet (calm water: no surf).
static func in_bay(p: Vector2, margin: float) -> bool:
	return p.distance_to(BAY) < BAY_R + margin or _inlet_distance(p) < INLET_HALF + margin


func _normal(x: float, z: float) -> Vector3:
	var e := 0.25
	return Vector3(height(x - e, z) - height(x + e, z), 2.0 * e, height(x, z - e) - height(x, z + e)).normalized()


## Above zero, grass; below, sand. The line wanders about a metre above
## the sea.
func _grassiness(x: float, z: float, h: float) -> float:
	# The north's dunes are bare sand, the grass giving out behind them.
	var bearing := atan2(z, x)
	var s := shore_radius(bearing) - sqrt(x * x + z * z)
	var sandy := north_weight(bearing) * smoothstep(78.0, 64.0, s) * 6.0
	# The wide beach is sand all across its flat.
	sandy += wide_weight(bearing) * smoothstep(WIDE_BEACH + 4.0, WIDE_BEACH - 3.0, s) * 3.0
	return h - 0.9 - 0.35 * _edge_noise.get_noise_2d(x, z) - sandy


## Where along a bearing the ground falls through `level`.
func coast(bearing: float, level: float) -> float:
	# Out from the middle to the first fall below `level`: the island's
	# own shore, not the lagoon's sandbar beyond it.
	var d := Vector2(cos(bearing), sin(bearing))
	var r := 0.6 * R
	while r < EXTENT and height(d.x * r, d.y * r) >= level:
		r += 1.0
	var lo := r - 1.0
	var hi := r
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
	_grid = heights
	_grid_n = n
	# Each grid point's slope and grassiness, worked out once.
	_normal_grid.resize(n * n)
	_grass_grid.resize(n * n)
	for j in n:
		for i in n:
			var hl := heights[j * n + maxi(i - 1, 0)]
			var hr := heights[j * n + mini(i + 1, n - 1)]
			var hd := heights[maxi(j - 1, 0) * n + i]
			var hu := heights[mini(j + 1, n - 1) * n + i]
			_normal_grid[j * n + i] = Vector3(hl - hr, 4.0 * GRID, hd - hu).normalized()
			var h := heights[j * n + i]
			_grass_grid[j * n + i] = _grassiness(-EXTENT + i * GRID, -EXTENT + j * GRID, h) if h > -0.5 else -1.0
	var faces := PackedVector3Array()
	for j in n - 1:
		for i in n - 1:
			var p := [Vector3(), Vector3(), Vector3(), Vector3()]
			var g := [0.0, 0.0, 0.0, 0.0]
			var nm := [Vector3(), Vector3(), Vector3(), Vector3()]
			var k := 0
			for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var at := (j + c.y) * n + i + c.x
				p[k] = Vector3(-EXTENT + (i + c.x) * GRID, heights[at], -EXTENT + (j + c.y) * GRID)
				g[k] = _grass_grid[at]
				nm[k] = _normal_grid[at]
				k += 1
			for tri: Array in [[0, 1, 2], [1, 3, 2]]:
				var a: Vector3 = p[tri[0]]
				var b: Vector3 = p[tri[1]]
				var c3: Vector3 = p[tri[2]]
				if a.y <= FLOOR + 0.01 and b.y <= FLOOR + 0.01 and c3.y <= FLOOR + 0.01:
					continue
				# Only ground the player can reach collides.
				if maxf(a.y, maxf(b.y, c3.y)) > -1.5:
					faces.append_array(_upward(a, b, c3))
				_split([a, b, c3], [g[tri[0]], g[tri[1]], g[tri[2]]], [nm[tri[0]], nm[tri[1]], nm[tri[2]]])
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
func _split(tri: Array, g: Array, nm: Array) -> void:
	var lo: Array[Vector3] = []
	var hi: Array[Vector3] = []
	var lo_n: Array[Vector3] = []
	var hi_n: Array[Vector3] = []
	for i in 3:
		var j := (i + 1) % 3
		var vi: Vector3 = tri[i]
		var vj: Vector3 = tri[j]
		var gi: float = g[i]
		var gj: float = g[j]
		var ni: Vector3 = nm[i]
		var nj: Vector3 = nm[j]
		if gi < 0.0:
			lo.append(vi)
			lo_n.append(ni)
		else:
			hi.append(vi)
			hi_n.append(ni)
		if (gi < 0.0) != (gj < 0.0):
			var t := gi / (gi - gj)
			var cut := vi.lerp(vj, t)
			var cn := ni.lerp(nj, t).normalized()
			lo.append(cut)
			hi.append(cut)
			lo_n.append(cn)
			hi_n.append(cn)
	# Held as plain locals and written back: a packed array taken out of
	# an Array is a copy.
	for side in 2:
		var poly: Array[Vector3] = lo if side == 0 else hi
		var pn: Array[Vector3] = lo_n if side == 0 else hi_n
		var points: PackedVector3Array = _ground[side * 2]
		var normals: PackedVector3Array = _ground[side * 2 + 1]
		for k in range(1, poly.size() - 1):
			var flip := (poly[k + 1] - poly[0]).cross(poly[k] - poly[0]).y < 0.0
			for m: int in ([0, k + 1, k] if flip else [0, k, k + 1]):
				points.append(poly[m])
				normals.append(pn[m])
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
		r += 2.5 if r < EXTENT else r * 0.12
		radii.append(minf(r, 1500.0))
	var segments := 360
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
			# The bay has its own calm, clear water; no sea under it.
			var mid := (points[a] + points[d]) * 0.5
			if Vector2(mid.x, mid.z).distance_to(BAY) < BAY_R + 1.5:
				continue
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
	# A short band across every stretch of the waterline (the height
	# field's 0 contour), from half a metre up the sand to two and a half
	# out, turned toward the water by the slope; none in the calm bay.
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	for seg: Array in contour(0.0):
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var mid := (a + b) * 0.5
		if in_bay(mid, 2.0):
			continue
		var e := 0.5
		var down := Vector2(height(mid.x - e, mid.y) - height(mid.x + e, mid.y), height(mid.x, mid.y - e) - height(mid.x, mid.y + e)).normalized()
		var quad := [Vector3(a.x - down.x * 0.5, 0.03, a.y - down.y * 0.5), Vector3(b.x - down.x * 0.5, 0.03, b.y - down.y * 0.5),
				Vector3(b.x + down.x * 2.5, 0.03, b.y + down.y * 2.5), Vector3(a.x + down.x * 2.5, 0.03, a.y + down.y * 2.5)]
		var quv := [0.0, 0.0, 1.0, 1.0]
		for tri: Array in [[0, 1, 2], [0, 2, 3]]:
			var p0: Vector3 = quad[tri[0]]
			var p1: Vector3 = quad[tri[1]]
			var p2: Vector3 = quad[tri[2]]
			var order: Array = tri if (p2 - p0).cross(p1 - p0).y >= 0.0 else [tri[0], tri[2], tri[1]]
			for k: int in order:
				points.append(quad[k])
				uvs.append(Vector2(quv[k], 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var normals := PackedVector3Array()
	normals.resize(points.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
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
	# Where the player stands, written every few seconds as well as on
	# leaving, so a closed window or a crash keeps it too.
	_place_left -= delta
	if _place_left <= 0.0:
		_place_left = 3.0
		_save_place()
	_keep_free(delta)
	# Ripples drift with the breeze; the foam swells over ten seconds.
	_sea_mat.uv1_offset = Vector3(_clock * 0.012, _clock * 0.007, 0.0)
	var swell := sin(_clock * TAU / 10.0)
	# The swash: the band's picture slid up and down the beach.
	_foam_mat.uv1_offset = Vector3(0.06 * swell, 0.0, 0.0)
	_foam_mat.albedo_color.a = 0.85 + 0.15 * swell
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		sky.follow(camera.global_position)
	# What the player looks at tells what it is (the salt works' parts),
	# unless the floating labels are switched off.
	var view: Node = player.look_view() if _labels else null
	if view != _hovered:
		if _hovered != null and is_instance_valid(_hovered) and _hovered.has_method("show_label"):
			_hovered.call("show_label", false)
		_hovered = view
		if view != null and view.has_method("show_label"):
			view.call("show_label", true)


## ---- where the player stands -------------------------------------------

## Keeps the player from being trapped. Twice a second, a place where
## they stand on the ground and inside nothing is remembered (the last
## eight). A player found inside something (a body slightly smaller than
## theirs overlapping a solid) for half a second is put back where they
## stood freely a few seconds before, as is one who has fallen into the
## sea. R takes them back to the dock.
func _keep_free(delta: float) -> void:
	if MouseMode.probe or player == null:
		return
	var inside := _player_inside()
	_good_left -= delta
	if _good_left <= 0.0:
		_good_left = 0.5
		if player.is_on_floor() and not inside:
			_good.append(Vector4(player.position.x, player.position.y, player.position.z, player.rotation.y))
			if _good.size() > 8:
				_good.remove_at(0)
	_wedged = _wedged + delta if inside else 0.0
	# Fallen into the sea, or found inside something: back where they
	# stood freely.
	if player.position.y < -1.5:
		_wedged = 1.0
	if _wedged > 0.5:
		_wedged = 0.0
		var back := _good[0] if not _good.is_empty() else Vector4(DOCK_X, DOCK_Y + 0.05, _dock_z1 - 1.0, 0.0)
		_put_player(Vector3(back.x, back.y + 0.2, back.z), back.w)
	if Input.is_physical_key_pressed(KEY_R) and player.look_held_by == null and not player.input_locked:
		_put_player(Vector3(DOCK_X, DOCK_Y + 0.25, _dock_z1 - 1.0), 0.0)


## Whether the player's body, made 6 cm thinner, overlaps any solid.
func _player_inside() -> bool:
	_probe_capsule.radius = 0.29
	_probe_capsule.height = 1.6
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _probe_capsule
	q.transform = Transform3D(Basis.IDENTITY, player.global_position + Vector3(0, 0.95, 0))
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _put_player(at: Vector3, facing: float) -> void:
	player.global_position = at
	player.rotation.y = facing
	player.velocity = Vector3.ZERO
	_good.clear()
	_save_place()


func _save_place() -> void:
	# Not for the probes, which park the player out of sight. The place
	# written is the last one where they stood freely, so a player wedged
	# somewhere is never brought back to it.
	if MouseMode.probe or player == null:
		return
	var at := Vector4(player.position.x, player.position.y, player.position.z, player.rotation.y)
	if not _good.is_empty():
		at = _good[-1]
	elif player.position.y < -3.0:
		return
	var file := FileAccess.open(PLACE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"player": [at.x, at.y, at.z, at.w]}))


func _load_place() -> void:
	if not FileAccess.file_exists(PLACE_PATH):
		return
	var file := FileAccess.open(PLACE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not (parsed as Dictionary).get("player") is Array:
		return
	var at: Array = parsed["player"]
	if at.size() < 4:
		return
	# A little above where they stood, to settle onto the ground.
	player.global_position = Vector3(float(at[0]), float(at[1]) + 0.2, float(at[2]))
	player.rotation.y = float(at[3])


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
		top = maxf(top, height(cabin.x + c.x, cabin.z + c.y))
	var floor_y := top + 0.3
	var walls := surface("wood_floor", 0.6, Color(0.78, 0.72, 0.64), 0.8, Color(0.95, 0.87, 0.72))
	var base := surface("rough_rock", 0.5, Color(0.75, 0.75, 0.75), 0.9, Color(0.66, 0.64, 0.66))
	var roof := surface("", 1.0, Color(0.3, 0.12, 0.09), 0.75, Color(0.86, 0.42, 0.33),
			{"bumps": _noise_bumps(17, 0.05, 3.0)})
	var door := surface("wood_floor", 0.6, Color(0.35, 0.27, 0.22), 0.7, Color(0.38, 0.6, 0.78))
	var glass := surface("", 1.0, Color(0.04, 0.05, 0.06), 0.08, Color(1.0, 0.86, 0.5),
			{"glow": Color(1.0, 0.8, 0.45), "no_line": true})
	var stone := surface("old_stone_bricks", 1.0 / 1.8, Color(0.85, 0.85, 0.85), 0.9, Color(0.72, 0.66, 0.62))
	cabin.y = floor_y
	var c := cabin
	var depth := floor_y - minf(height(cabin.x - hx, cabin.z + hz), height(cabin.x + hx, cabin.z + hz)) + 0.6
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
	piers.append([Vector3(DOCK_X, 0, coast(PI * 0.5, -0.5) - 2.0), Vector3(DOCK_X, 0, _dock_z1), DOCK_W * 0.5])
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
	var keep_clear: Array[Vector3] = [   # x, z, radius
		_flat(SaltWorks.centre(self), 26.0), _flat(ColourWorks.centre(self), 22.0),
		_flat(BalloonWorks.centre(self), 20.0), _flat(LagoonWorks.centre(self), 18.0),
		Vector3(HILL.x, HILL.y, 20.0), Vector3(cabin.x, cabin.z, 7.0), Vector3(BAY.x, BAY.y, BAY_R + 8.0)]
	var placed: Array[Vector2] = []
	var try_tree := func(p: Vector2, spacing: float, round_share: float) -> bool:
		var h := height(p.x, p.y)
		if _grassiness(p.x, p.y, h) < 0.4:
			return false
		if absf(p.x - DOCK_X) < 4.0 and p.y > cabin.z:
			return false
		for c: Vector3 in keep_clear:
			if p.distance_to(Vector2(c.x, c.y)) < c.z:
				return false
		for q: Vector2 in placed:
			if p.distance_to(q) < spacing:
				return false
		placed.append(p)
		var size := rng.randf_range(0.8, 1.3)
		var base := Vector3(p.x, h - 0.2, p.y)
		if rng.randf() < round_share:
			_round_tree(base, size, bark, leaves, rng)
		else:
			_pine(base, size, bark, needles)
		return true
	# Broad-leaved trees round the cabin, behind and beside it, for the
	# lanterns.
	var ring := 0
	var ring_tries := 0
	while ring < 7 and ring_tries < 200:
		ring_tries += 1
		var a := rng.randf_range(-PI, 0.15) if ring % 2 == 0 else rng.randf_range(PI - 0.15, TAU)
		if try_tree.call(Vector2(cabin.x, cabin.z) + Vector2(cos(a), sin(a)) * rng.randf_range(9.0, 15.0), 5.0, 1.0):
			ring += 1
	# Woods: groves of a dozen or two, each mostly one kind.
	var groves := 0
	var tries := 0
	while groves < 11 and tries < 400:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.2, 0.75) * shore_radius(a)
		var centre := Vector2(cos(a), sin(a)) * r
		if _grassiness(centre.x, centre.y, height(centre.x, centre.y)) < 1.0:
			continue
		groves += 1
		var round_share := 0.85 if rng.randf() < 0.5 else 0.2
		var reach := rng.randf_range(12.0, 24.0)
		for k in rng.randi_range(10, 22):
			var off := Vector2(rng.randfn(0.0, reach * 0.5), rng.randfn(0.0, reach * 0.5))
			try_tree.call(centre + off, 4.5, round_share)
	# And a few standing alone in the meadows.
	var singles := 0
	tries = 0
	while singles < 28 and tries < 800:
		tries += 1
		var a := rng.randf() * TAU
		var p := Vector2(cos(a), sin(a)) * rng.randf_range(0.1, 0.85) * shore_radius(a)
		if try_tree.call(p, 12.0, 0.6):
			singles += 1


static func _flat(p: Vector3, radius: float) -> Vector3:
	return Vector3(p.x, p.z, radius)


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
	for s: Vector3 in [Vector3(-15, 15, 1.6), Vector3(10, -17, 1.1), Vector3(-22, -10, 0.9)]:
		_boulder(Vector3(HILL.x + s.x, 0.0, HILL.y + s.y), s.z, 8 + int(s.x), rock, lumps)


## Rocky outcrops in the meadows: knots of boulders half sunk in the
## grass, a big one and smaller ones leaning on it.
func _build_outcrops() -> void:
	var rock := surface("rough_rock", 0.4, Color(0.8, 0.78, 0.76), 0.9, Color(0.68, 0.68, 0.74))
	var lumps := FastNoiseLite.new()
	lumps.seed = 43
	lumps.frequency = 0.9
	var rng := RandomNumberGenerator.new()
	rng.seed = 3131
	var made := 0
	var tries := 0
	while made < 8 and tries < 300:
		tries += 1
		var a := rng.randf() * TAU
		var c := Vector2(cos(a), sin(a)) * rng.randf_range(0.25, 0.8) * shore_radius(a)
		var h := height(c.x, c.y)
		if _grassiness(c.x, c.y, h) < 1.0 or c.distance_to(Vector2(cabin.x, cabin.z)) < 25.0 or c.distance_to(BAY) < 30.0:
			continue
		var clear := true
		for p: Vector3 in [SaltWorks.centre(self), ColourWorks.centre(self), BalloonWorks.centre(self), LagoonWorks.centre(self)]:
			clear = clear and c.distance_to(Vector2(p.x, p.z)) > 30.0
		if not clear or c.distance_to(HILL) < 22.0:
			continue
		made += 1
		var big := rng.randf_range(2.2, 3.4)
		_boulder(Vector3(c.x, 0.0, c.y), big, 100 + made * 10, rock, lumps, -0.25)
		for k in rng.randi_range(3, 6):
			var b := rng.randf() * TAU
			var at := c + Vector2(cos(b), sin(b)) * big * rng.randf_range(1.1, 2.0)
			_boulder(Vector3(at.x, 0.0, at.y), big * rng.randf_range(0.25, 0.55), 101 + made * 10 + k, rock, lumps, -0.1)


## Wild flowers in drifts across the meadows: a stem and a little head
## each, built cozy-native, one mesh per patch of ground, the far ones
## left out.
func _build_flowers() -> void:
	var colours := [Color(0.98, 0.95, 0.85), Color(0.98, 0.82, 0.25), Color(0.85, 0.55, 0.9),
			Color(0.95, 0.45, 0.45), Color(0.55, 0.7, 0.98)]
	var stem := Color(0.42, 0.62, 0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2626
	var tiles := {}
	for d in 90:
		var a := rng.randf() * TAU
		var c := Vector2(cos(a), sin(a)) * rng.randf_range(0.05, 0.85) * shore_radius(a)
		var colour: Color = colours[rng.randi() % colours.size()]
		var reach := rng.randf_range(2.5, 5.5)
		for k in rng.randi_range(70, 140):
			var p := c + Vector2(rng.randfn(0.0, reach), rng.randfn(0.0, reach))
			var h := height(p.x, p.y)
			if _grassiness(p.x, p.y, h) < 0.5 or p.distance_to(Vector2(cabin.x, cabin.z)) < 4.0:
				continue
			var key := Vector2i(floori(p.x / 50.0), floori(p.y / 50.0))
			if not tiles.has(key):
				tiles[key] = CozyMesh.new()
			var m: CozyMesh = tiles[key]
			var tall := rng.randf_range(0.22, 0.42)
			m.box(Vector3(0.02, tall, 0.02), CozyMesh.at(Vector3(p.x, h + tall * 0.5, p.y)), stem)
			m.box(Vector3(0.13, 0.05, 0.13), CozyMesh.at(Vector3(p.x, h + tall, p.y), Basis(Vector3.UP, rng.randf() * TAU)), colour)
	var mat := cozy_material(false)
	for key: Vector2i in tiles:
		var view := MeshInstance3D.new()
		view.name = "Flowers"
		view.mesh = (tiles[key] as CozyMesh).commit(mat)
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		view.visibility_range_end = 70.0
		view.visibility_range_end_margin = 10.0
		add_child(view)


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
		return Vector2(p.x, p.z).distance_to(Vector2(cabin.x, cabin.z)) < Vector2(q.x, q.z).distance_to(Vector2(cabin.x, cabin.z)))
	for k in mini(LANTERNS, near.size()):
		var c: Vector4 = near[k]
		var toward := Vector3(cabin.x - c.x, 0.0, cabin.z - c.z).normalized()
		# Where a line 1.5 sizes out from the trunk meets the main ball's
		# underside (its radius 1.7 sizes).
		var anchor := Vector3(c.x, c.y, c.z) + toward * 1.5 * c.w + Vector3.DOWN * 0.8 * c.w
		var lantern := HangingLantern.new(frame, cord, k * 1.9)
		lantern.position = anchor
		add_child(lantern)
		_lanterns.append(lantern)


func _boulder(at: Vector3, size: float, seed_value: int, mat: Material, lumps: FastNoiseLite,
		sink := 0.25) -> void:
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
	view.position = Vector3(at.x, ground + size * sink, at.z)
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
## The walls that keep the player on land: a fence along the line where
## the sea is half a metre deep (the height field's -0.5 contour, cell by
## cell, so it follows spits and inlets exactly), open where a pier,
## dock or bridge leaves the land, whose sides it runs along instead. A
## pier is [shore point, far point, half width, belongs to a works,
## open at the far end].
func _build_bounds() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var faces := PackedVector3Array()
	var gap_faces := PackedVector3Array()
	for seg: Array in contour(-0.5):
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var mid := (a + b) * 0.5
		var crossed := -1
		for i in piers.size():
			if _on_pier(piers[i], mid):
				crossed = i
		var quad := [Vector3(a.x, -6.0, a.y), Vector3(b.x, -6.0, b.y), Vector3(b.x, 6.0, b.y), Vector3(a.x, 6.0, a.y)]
		var into := faces
		if crossed >= 0:
			if not _pier_flag(piers[crossed], 3):
				continue
			into = gap_faces
		for k: int in [0, 1, 2, 0, 2, 3]:
			into.append(quad[k])
	for list: Array in [[faces, false], [gap_faces, true]]:
		var f: PackedVector3Array = list[0]
		if f.is_empty():
			continue
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(f)
		var c := CollisionShape3D.new()
		c.shape = shape
		body.add_child(c)
		if list[1]:
			c.disabled = true
			_works_gap.append(c)
	# Each pier's sides, and its far end unless open.
	for pier: Array in piers:
		var from: Vector3 = pier[0]
		var to: Vector3 = pier[1]
		var half: float = pier[2]
		var along := (to - from).normalized()
		var side := Vector3(along.z, 0.0, -along.x)
		var start := from - along * 2.0
		var before := body.get_child_count()
		for s in [-1.0, 1.0]:
			_wall(body, start + side * s * half, to + side * s * half)
		if not _pier_flag(pier, 4):
			_wall(body, to - side * half, to + side * half)
		if _pier_flag(pier, 3):
			for k in range(before, body.get_child_count()):
				_works_pier.append(body.get_child(k) as CollisionShape3D)


static func _pier_flag(pier: Array, i: int) -> bool:
	return pier.size() > i and bool(pier[i])


## Whether a point of the shore lies across a pier's walkway.
static func _on_pier(pier: Array, p: Vector2) -> bool:
	var from: Vector3 = pier[0]
	var to: Vector3 = pier[1]
	var half: float = pier[2]
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var along := (b - a).normalized()
	var u := (p - a).dot(along)
	return absf((p - a).dot(Vector2(-along.y, along.x))) < half + 0.4 and u > -2.5 and u < a.distance_to(b) + 1.0


## The line where the ground crosses `level`, as segments [a, b] (x, z),
## found cell by cell over the ground's grid (marching squares).
func contour(level: float) -> Array:
	var out: Array = []
	var n := _grid_n
	for j in n - 1:
		for i in n - 1:
			var v := [_grid[j * n + i], _grid[j * n + i + 1], _grid[(j + 1) * n + i + 1], _grid[(j + 1) * n + i]]
			var case := 0
			for k in 4:
				if float(v[k]) >= level:
					case |= 1 << k
			if case == 0 or case == 15:
				continue
			var x0 := -EXTENT + i * GRID
			var z0 := -EXTENT + j * GRID
			var corners := [Vector2(x0, z0), Vector2(x0 + GRID, z0), Vector2(x0 + GRID, z0 + GRID), Vector2(x0, z0 + GRID)]
			var cut := func(e: int) -> Vector2:
				var p0: Vector2 = corners[e]
				var p1: Vector2 = corners[(e + 1) % 4]
				var h0: float = v[e]
				var h1: float = v[(e + 1) % 4]
				return p0.lerp(p1, clampf((level - h0) / (h1 - h0), 0.0, 1.0))
			var pairs: Array = []
			match case:
				1, 14: pairs = [[3, 0]]
				2, 13: pairs = [[0, 1]]
				3, 12: pairs = [[3, 1]]
				4, 11: pairs = [[1, 2]]
				6, 9: pairs = [[0, 2]]
				7, 8: pairs = [[3, 2]]
				5, 10:
					var centre := (float(v[0]) + float(v[1]) + float(v[2]) + float(v[3])) * 0.25
					if (centre >= level) == (case == 5):
						pairs = [[3, 2], [0, 1]]
					else:
						pairs = [[3, 0], [1, 2]]
			for pr: Array in pairs:
				out.append([cut.call(pr[0]), cut.call(pr[1])])
	return out


## Works shown and running, or gone: hidden, paused, silent; the shore
## closed where the wharf was.
func _set_works(on: bool) -> void:
	for works in _works:
		works.visible = on
		works.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		for n in works.find_children("*", "", true, false):
			if n is AudioStreamPlayer3D:
				(n as AudioStreamPlayer3D).stream_paused = not on
			elif n is AudioStreamPlayer:
				(n as AudioStreamPlayer).stream_paused = not on
	for c in _works_gap:
		c.disabled = on
	for c in _works_pier:
		c.disabled = not on


## Tufts of marram grass on the dunes, and a little driftwood: built
## cozy-native, one mesh in flat colours.
func _build_dune_grass() -> void:
	var m := CozyMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7070
	var greens := [Color(0.62, 0.7, 0.36), Color(0.72, 0.74, 0.42), Color(0.55, 0.64, 0.33)]
	var placed := 0
	var tries := 0
	while placed < 420 and tries < 9000:
		tries += 1
		var a := deg_to_rad(NORTH_BEARING) + rng.randf_range(-0.6, 0.6)
		var r := shore_radius(a) - rng.randf_range(2.0, 72.0)
		var x := cos(a) * r
		var z := sin(a) * r
		var h := height(x, z)
		if h < 0.6 or north_weight(atan2(z, x)) < 0.5 or in_bay(Vector2(x, z), 2.5):
			continue
		placed += 1
		var colour: Color = greens[rng.randi() % 3]
		for k in 7:
			var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.1, 0.45))
			var tall := rng.randf_range(0.4, 0.8)
			m.cyl(0.0, 0.025, tall, 3, CozyMesh.at(Vector3(x + rng.randf_range(-0.2, 0.2), h + tall * 0.45, z + rng.randf_range(-0.2, 0.2)), lean), colour)
	for k in 9:
		var a := deg_to_rad(NORTH_BEARING) + rng.randf_range(-0.45, 0.45)
		var r := shore_radius(a) - rng.randf_range(2.0, 8.0)
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		p.y = maxf(height(p.x, p.z), 0.0) + 0.1
		var length_ := rng.randf_range(1.5, 3.2)
		m.cyl(0.09, 0.12, length_, 7, CozyMesh.at(p, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5)), Color(0.66, 0.6, 0.52))
	var view := MeshInstance3D.new()
	view.name = "DuneGrass"
	view.mesh = m.commit(cozy_material())
	add_child(view)


var _cozy_mat: StandardMaterial3D
var _cozy_plain: StandardMaterial3D


## The island's own flat-painted material: white, taking vertex colours,
## registered so the light and outline switches reach it; `lined` false
## gives one without outlines, for small things.
func cozy_material(lined := true) -> StandardMaterial3D:
	if lined and _cozy_mat == null:
		_cozy_mat = surface("", 1.0, Color.WHITE, 0.85, Color.WHITE, {"line_colour": Color(0.26, 0.2, 0.16)})
		_cozy_mat.vertex_color_use_as_albedo = true
	if not lined and _cozy_plain == null:
		_cozy_plain = surface("", 1.0, Color.WHITE, 0.85, Color.WHITE, {"no_line": true})
		_cozy_plain.vertex_color_use_as_albedo = true
	return _cozy_mat if lined else _cozy_plain


func _wall(body: StaticBody3D, a: Vector3, b: Vector3) -> void:
	var along := b - a
	var shape := BoxShape3D.new()
	shape.size = Vector3(along.length() + 0.4, 6.0, 0.2)
	var c := CollisionShape3D.new()
	c.shape = shape
	c.position = (a + b) * 0.5 + Vector3.UP * 1.5
	c.rotation.y = -atan2(along.z, along.x)
	body.add_child(c)
