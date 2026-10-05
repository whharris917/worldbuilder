class_name ProjectorLab
extends Node3D
## A dark room with a lantern: a hollow sphere 1 m across on a stand,
## open in a round hole toward the north wall, which is painted white as
## a screen 6.5 m away. Inside, up to three lights near the back and a
## handful of shapes drifting between them and the hole, so the screen
## shows the shapes' shadows, one set for each light, crossing and
## overlapping. A study of soft shadows in Godot's own lighting: nothing
## here is a custom shader.
##
## Each light is one of the engine's: a point light (omni), a spot light
## aimed at the hole, or an area light (a glowing square) facing it. A
## point or spot light given a size casts soft shadows (Godot's
## percentage-closer soft shadows: each pixel's shadow is blurred by how
## far the blocker is from it, in proportion to the light's size); an area
## light's are soft by its own size. A shadow's soft edge on the screen is
## about the light's size times the shape's distance to the screen over
## its distance from the light, so here, with the screen twenty times
## farther than the light, a 5 cm light gives an edge about a metre wide.
## Point and spot lights fall off with the square of distance.
##
## The shapes (Balls, Rings, Rods or Mixed) drift on slow paths made of
## sine waves at unrelated rates, turning as they go, so the pattern never
## quite repeats; their phase is summed each frame so a change of speed
## is smooth.
##
## The lantern's shell is 4 cm thick, matte white inside and dark metal
## outside, drawn double-sided for its shadows. The room otherwise has
## only a faint ambient light, and a dim ceiling lamp on a slider.
##
## Panels (BenchPanel; Esc frees the mouse), kept in
## user://projector_lab.json: Lights (each light's kind, colour, energy
## and size; how far apart they stand), Shapes (kind, count, size, speed),
## Lantern (the hole's width; the room lamp), Viewport (the soft-shadow
## quality and the shadow atlas, engine-wide and put back on leaving).

const ROOM := Vector3(14.0, 5.0, 10.0)
const WALL := 0.3
const CENTRE := Vector3(0.0, 1.6, 2.0)  # the lantern's
const R := 0.5                          # the lantern's outer radius
const SHELL := 0.04
const START := Vector3(2.5, 0.0, 4.0)
const LIGHT_BACK := 0.25                # the lights' plane, behind the centre
const STATE_PATH := "user://projector_lab.json"
const KINDS := ["Off", "Point", "Spot", "Area"]
const LIGHT_COLOURS: Array[Color] = [Color(1.0, 0.25, 0.2), Color(0.3, 1.0, 0.35), Color(0.3, 0.45, 1.0)]
const QUALITIES := {"Hard": 0, "Very low": 1, "Low": 2, "Medium": 3, "High": 4, "Ultra": 5}
const ATLAS_SIZES := ["4096", "8192", "16384"]

var player: Player
var _panel: BenchPanel
var _shell: MeshInstance3D
var _shell_mat_in: StandardMaterial3D
var _shell_mat_out: StandardMaterial3D
var _room_lamp: OmniLight3D
var _lights: Array[Light3D] = [null, null, null]
var _shapes: Array[Dictionary] = []     # {node, freq, phase, spin, spin_phase}
var _shape_mat: StandardMaterial3D
var _phase := 0.0
var _was := {}


func _ready() -> void:
	player = $Player as Player
	player.global_position = START
	var vp := get_viewport()
	_was = {
		"debanding": vp.use_debanding,
		"atlas": vp.positional_shadow_atlas_size,
		"soft": ProjectSettings.get_setting("rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality", 2),
	}
	vp.use_debanding = true
	_build_environment()
	_build_room()
	_build_lantern()
	_shape_mat = StandardMaterial3D.new()
	_shape_mat.albedo_color = Color(0.25, 0.25, 0.25)
	_shape_mat.roughness = 0.8
	_build_panels()
	_panel.restore()
	_build_shell()
	_rebuild_lights()
	_rebuild_shapes()
	_set_room_lamp()
	MouseMode.capture()
	if DisplayServer.get_name() == "headless":
		print("[worldbuilder] projector lab: %d lights, %d shapes" % [
			_lights.filter(func(l: Light3D) -> bool: return l != null).size(), _shapes.size()])


func _exit_tree() -> void:
	var vp := get_viewport()
	vp.use_debanding = _was["debanding"]
	vp.positional_shadow_atlas_size = _was["atlas"]
	RenderingServer.positional_soft_shadow_filter_set_quality(int(_was["soft"]))


## ---- the controls ----------------------------------------------------------

func _build_panels() -> void:
	_panel = BenchPanel.new(STATE_PATH)
	add_child(_panel)
	var lights := _panel.panel("Lights")
	var relight := func(_v: Variant) -> void: _rebuild_lights()
	for i in 3:
		var n := i + 1
		_panel.heading(lights, "Light %d" % n)
		_panel.choice(lights, "Light %d" % n, KINDS, "Point", relight)
		_panel.colour(lights, "Light %d colour" % n, LIGHT_COLOURS[i], relight)
		_panel.slider(lights, "Light %d energy" % n, 0.0, 200.0, 1.0, 40.0, relight)
		_panel.slider(lights, "Light %d size (cm)" % n, 0.0, 30.0, 0.5, 2.0, relight)
	_panel.note(lights, "Point: light from a ball of that size in every direction. Spot: the same, only into a cone just wide enough for the hole. Area: a glowing square of that size facing the hole. The larger the light, the softer its shadows; at size 0 a point or spot light's shadows are sharp.")
	_panel.slider(lights, "Spread (cm)", 0.0, 25.0, 0.5, 12.0, relight)
	_panel.note(lights, "How far apart the lights stand, round the middle of the lantern's back. Farther apart, their shadows of the same shape land farther apart on the screen.")

	var shapes := _panel.panel("Shapes")
	var reshape := func(_v: Variant) -> void: _rebuild_shapes()
	_panel.choice(shapes, "Shapes", ["Balls", "Rings", "Rods", "Mixed"], "Mixed", reshape)
	_panel.slider(shapes, "Count", 1.0, 12.0, 1.0, 7.0, reshape)
	_panel.slider(shapes, "Size", 0.5, 2.0, 0.05, 1.0, reshape)
	_panel.slider(shapes, "Speed", 0.0, 3.0, 0.01, 1.0, func(_v: float) -> void: pass)
	_panel.note(shapes, "The shapes drift inside the lantern between the lights and the hole. A shape near a light throws a large, soft shadow; near the hole, a smaller, sharper one.")

	var lantern := _panel.panel("Lantern")
	_panel.slider(lantern, "Hole (cm)", 5.0, 90.0, 1.0, 60.0, func(_v: float) -> void: _build_shell())
	_panel.note(lantern, "The width of the round hole the light leaves by. A small hole gives the screen a small round patch of light; a wide one lets every light's shadows through.")
	_panel.slider(lantern, "Room lamp", 0.0, 1.0, 0.01, 0.0, func(_v: float) -> void: _set_room_lamp())

	var view := _panel.panel("Viewport")
	_panel.choice(view, "Soft shadows", QUALITIES.keys(), "Low", func(o: String) -> void:
		RenderingServer.positional_soft_shadow_filter_set_quality(int(QUALITIES[o])))
	_panel.note(view, "How many samples each pixel takes of a light's shadow map to blur the shadow. Low is grainy in wide soft edges; higher is smoother and costs more. Hard turns the softening off.")
	_panel.choice(view, "Shadow atlas", ATLAS_SIZES, str(get_viewport().positional_shadow_atlas_size), func(o: String) -> void:
		get_viewport().positional_shadow_atlas_size = int(o))
	_panel.note(view, "The size of the picture that holds every light's shadow map. A larger one gives sharper shadows: magnified twenty times onto the screen, a shadow map's squares can show.")


func _value(title: String) -> float:
	return float((_panel.sliders[title] as HSlider).value)


func _picked(title: String) -> String:
	var boxes := _panel.choices[title] as Dictionary
	for option: String in boxes:
		if (boxes[option] as CheckBox).button_pressed:
			return option
	return ""


## ---- the room --------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.015
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.5
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


## A dark room with its north wall painted matte white as the screen.
func _build_room() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.12, 0.12)
	dark.roughness = 0.95
	var screen := StandardMaterial3D.new()
	screen.albedo_color = Color(0.82, 0.82, 0.8)
	screen.roughness = 0.95
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = load("res://textures/wood_floor/albedo.jpg") as Texture2D
	floor_mat.albedo_color = Color(0.45, 0.45, 0.45)
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
	_slab_between(Vector3(-hx - WALL, ROOM.y, -hz - WALL), Vector3(hx + WALL, ROOM.y + WALL, hz + WALL), dark)
	_slab_between(Vector3(hx, 0.0, -hz), Vector3(hx + WALL, ROOM.y, hz), dark)
	_slab_between(Vector3(-hx - WALL, 0.0, -hz), Vector3(-hx, ROOM.y, hz), dark)
	_slab_between(Vector3(-hx - WALL, 0.0, hz), Vector3(hx + WALL, ROOM.y, hz + WALL), dark)
	_slab_between(Vector3(-hx - WALL, 0.0, -hz - WALL), Vector3(hx + WALL, ROOM.y, -hz), screen)
	_room_lamp = OmniLight3D.new()
	_room_lamp.position = Vector3(0.0, ROOM.y - 0.2, 3.0)
	_room_lamp.omni_range = 16.0
	_room_lamp.light_color = Color(1.0, 0.93, 0.82)
	add_child(_room_lamp)


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


func _set_room_lamp() -> void:
	var level := _value("Room lamp")
	_room_lamp.visible = level > 0.0
	_room_lamp.light_energy = level * 2.0


## ---- the lantern -----------------------------------------------------------

## The stand and the solid the player bumps into; the shell itself is
## built by `_build_shell`, again whenever the hole changes.
func _build_lantern() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.05, 0.05, 0.055)
	metal.metallic = 0.6
	metal.roughness = 0.45
	_shell_mat_out = metal
	_shell_mat_in = StandardMaterial3D.new()
	_shell_mat_in.albedo_color = Color(0.85, 0.85, 0.83)
	_shell_mat_in.roughness = 0.95
	var body := StaticBody3D.new()
	body.position = CENTRE
	add_child(body)
	var ball := SphereShape3D.new()
	ball.radius = R
	var collide := CollisionShape3D.new()
	collide.shape = ball
	body.add_child(collide)
	var post := CylinderMesh.new()
	post.top_radius = 0.025
	post.bottom_radius = 0.025
	post.height = CENTRE.y - R
	post.material = metal
	var post_view := MeshInstance3D.new()
	post_view.mesh = post
	post_view.position = Vector3(CENTRE.x, (CENTRE.y - R) * 0.5, CENTRE.z)
	add_child(post_view)
	var foot := CylinderMesh.new()
	foot.top_radius = 0.2
	foot.bottom_radius = 0.22
	foot.height = 0.04
	foot.material = metal
	var foot_view := MeshInstance3D.new()
	foot_view.mesh = foot
	foot_view.position = Vector3(CENTRE.x, 0.02, CENTRE.z)
	add_child(foot_view)
	_shell = MeshInstance3D.new()
	_shell.position = CENTRE
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	add_child(_shell)


## The shell: a sphere's outer and inner faces from the hole's edge round
## to the back, and the ring of the hole's edge between them. The hole
## faces north (-Z). Polar angle t from the hole's axis, azimuth p.
func _build_shell() -> void:
	if _shell == null or _panel == null:
		return
	var hole := _value("Hole (cm)") * 0.01
	var t0 := asin(clampf(hole * 0.5 / R, 0.0, 0.99))
	var rings := 48
	var segs := 96
	var outer := SurfaceTool.new()
	outer.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := SurfaceTool.new()
	inner.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dir := func(t: float, p: float) -> Vector3:
		return Vector3(sin(t) * cos(p), sin(t) * sin(p), -cos(t))
	for i in rings:
		var ta := t0 + (PI - t0) * float(i) / rings
		var tb := t0 + (PI - t0) * float(i + 1) / rings
		for j in segs:
			var pa := TAU * float(j) / segs
			var pb := TAU * float(j + 1) / segs
			var quad: Array[Vector3] = [dir.call(ta, pa), dir.call(tb, pa), dir.call(tb, pb), dir.call(ta, pb)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				outer.set_normal(quad[k])
				outer.add_vertex(quad[k] * R)
			for k: int in [0, 2, 1, 0, 3, 2]:
				inner.set_normal(-quad[k])
				inner.add_vertex(quad[k] * (R - SHELL))
	# The hole's edge, between the faces, its normal toward the axis.
	for j in segs:
		var pa := TAU * float(j) / segs
		var pb := TAU * float(j + 1) / segs
		var a: Vector3 = dir.call(t0, pa)
		var b: Vector3 = dir.call(t0, pb)
		var quad: Array[Vector3] = [a * R, a * (R - SHELL), b * (R - SHELL), b * R]
		var n := -Vector3(a.x, a.y, 0.0).normalized()
		for k: int in [0, 1, 2, 0, 2, 3]:
			outer.set_normal(n)
			outer.add_vertex(quad[k])
	var mesh := outer.commit()
	inner.commit(mesh)
	_shell_mat_out.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shell_mat_in.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, _shell_mat_out)
	mesh.surface_set_material(1, _shell_mat_in)
	_shell.mesh = mesh
	_rebuild_lights()


## ---- the lights ------------------------------------------------------------

## Each light made afresh as its panel says, at its place on a circle
## round the middle of the lantern's back, facing the hole.
func _rebuild_lights() -> void:
	if _panel == null or _shell == null:
		return
	var spread := _value("Spread (cm)") * 0.01
	var hole_r := _value("Hole (cm)") * 0.005
	for i in 3:
		if _lights[i] != null:
			_lights[i].queue_free()
			_lights[i] = null
		var n := i + 1
		var kind := _picked("Light %d" % n)
		if kind == "Off" or kind == "":
			continue
		var a := deg_to_rad(90.0 + 120.0 * i)
		var at := CENTRE + Vector3(cos(a) * spread, sin(a) * spread, LIGHT_BACK)
		var colour := (_panel.pickers["Light %d colour" % n] as ColorPickerButton).color
		var energy := _value("Light %d energy" % n)
		var size := _value("Light %d size (cm)" % n) * 0.01
		var to_hole := CENTRE + Vector3(0.0, 0.0, -R) - at
		var light: Light3D
		match kind:
			"Point":
				var omni := OmniLight3D.new()
				omni.omni_range = 20.0
				omni.omni_attenuation = 2.0
				omni.light_size = size
				light = omni
			"Spot":
				var spot := SpotLight3D.new()
				spot.spot_range = 20.0
				spot.spot_attenuation = 2.0
				spot.spot_angle = rad_to_deg(atan((hole_r + 0.03) / to_hole.length())) + 3.0
				spot.spot_angle_attenuation = 0.2
				spot.light_size = size
				light = spot
			"Area":
				var area := AreaLight3D.new()
				area.area_size = Vector2(maxf(size, 0.005), maxf(size, 0.005))
				area.area_range = 20.0
				area.area_attenuation = 2.0
				light = area
		light.light_color = colour
		light.light_energy = energy
		light.shadow_enabled = true
		light.shadow_bias = 0.03
		light.shadow_normal_bias = 0.5
		add_child(light)
		light.global_transform = Transform3D(Basis.looking_at(to_hole.normalized(), Vector3.UP), at)
		_lights[i] = light


## ---- the shapes ------------------------------------------------------------

## The shapes made afresh, each with its own rates and phases drawn from
## a fixed seed, so the same settings give the same dance.
func _rebuild_shapes() -> void:
	if _panel == null:
		return
	for s: Dictionary in _shapes:
		(s["node"] as Node).queue_free()
	_shapes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var kind := _picked("Shapes")
	var scale := _value("Size")
	for i in int(_value("Count")):
		var k := kind
		if k == "Mixed":
			k = ["Balls", "Rings", "Rods"][i % 3]
		var mesh: Mesh
		match k:
			"Balls":
				var ball := SphereMesh.new()
				var r := rng.randf_range(0.025, 0.06) * scale
				ball.radius = r
				ball.height = r * 2.0
				mesh = ball
			"Rings":
				var ring := TorusMesh.new()
				var r := rng.randf_range(0.04, 0.08) * scale
				ring.inner_radius = r * 0.75
				ring.outer_radius = r
				mesh = ring
			_:
				var rod := CapsuleMesh.new()
				rod.radius = 0.008 * scale
				rod.height = rng.randf_range(0.1, 0.2) * scale
				mesh = rod
		mesh.surface_set_material(0, _shape_mat)
		var node := MeshInstance3D.new()
		node.mesh = mesh
		add_child(node)
		_shapes.append({
			"node": node,
			"freq": Vector3(rng.randf_range(0.13, 0.31), rng.randf_range(0.11, 0.29), rng.randf_range(0.07, 0.19)),
			"phase": Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU),
			"spin": Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6)),
			"spin_phase": Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU),
		})
	_place_shapes()


## Each shape on its path at the summed phase: across and up by 16 cm
## either way, and from 3 cm behind the centre to 27 cm in front of it.
func _place_shapes() -> void:
	for s: Dictionary in _shapes:
		var f: Vector3 = s["freq"]
		var ph: Vector3 = s["phase"]
		var at := Vector3(0.16 * sin(f.x * _phase + ph.x), 0.16 * sin(f.y * _phase + ph.y),
			-0.12 + 0.15 * sin(f.z * _phase + ph.z))
		var node := s["node"] as Node3D
		node.position = CENTRE + at
		node.rotation = (s["spin"] as Vector3) * _phase + (s["spin_phase"] as Vector3)


func _process(delta: float) -> void:
	_phase += _value("Speed") * delta
	_place_shapes()
