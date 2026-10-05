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
## outside, drawn double-sided for its shadows. It can be made passable,
## to put one's head inside. A model of it stands 3 m to the west: the
## same shell and the same shapes moving in step, without the lights, lit
## inside by a dim lamp of its own, with small glowing markers where the
## lights stand (all on render layer MODEL, which only that lamp lights
## and the real lights leave alone). The room otherwise has
## only a faint ambient light, and a dim ceiling lamp on a slider.
##
## A second projector stands 3 m to the east, built like a telescope
## (PatternScope): a lamp in a tube lights a small plate showing a moving
## pattern, and the lens throws it onto the same wall.
##
## A third setup by the screen's east end tests whether Godot's bounce
## light can carry a pattern: a matte white panel 2 m square lies on the
## floor 1.6 m out from the white wall, and a spot light high above
## throws a dappled engine noise picture onto it, turning slowly. With
## VoxelGI (a box of cells about 11 cm across round the room, baked when
## chosen; it re-lights every frame as lights move) or SDFGI (cells round
## the camera, smallest 0.15 m) the lit panel bounces light onto the wall
## and the ceiling. The bounce is diffuse and coarse, so it can carry the
## pattern's large patches at most. Moving things (the shapes, the
## markers, the player) are left out of the bounce's picture of the room.
##
## Panels (BenchPanel; Esc frees the mouse), kept in
## user://projector_lab.json: Lights (each light's kind, colour, energy
## and size; how far apart they stand), Shapes (kind, count, size, speed),
## Lantern (the hole's width; passable; the model; the room lamp),
## Telescope (on, pattern, speed, setting, start again, brightness,
## colour, focal length, focus, open tube), Bounce (the dappled light on,
## its brightness, its speed, the bounce method, the light's strength in
## the bounce), Viewport (the soft-shadow
## quality and the shadow atlas, engine-wide and put back on leaving).

const ROOM := Vector3(14.0, 5.0, 10.0)
const WALL := 0.3
const CENTRE := Vector3(0.0, 1.6, 2.0)  # the lantern's
const R := 0.5                          # the lantern's outer radius
const SHELL := 0.04
const START := Vector3(2.5, 0.0, 4.0)
const LIGHT_BACK := 0.25                # the lights' plane, behind the centre
const MODEL_OFFSET := Vector3(-3.0, 0.0, 0.0)
const MODEL := 2                        # render layer of the model
const SCOPE_AT := Vector3(3.0, 1.6, 2.0)
const DAPPLE_PANEL := Vector3(5.0, 0.0, -3.4)   # the floor panel's centre
const DAPPLE_LIGHT := Vector3(5.0, 4.6, -1.6)
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
var _solids: Array[CollisionShape3D] = []
var _model: Node3D
var _model_shell: MeshInstance3D
var _model_marks: Array[MeshInstance3D] = []
var _scope: PatternScope
var _env: Environment
var _dapple: SpotLight3D
var _dapple_turn := 0.0
var _voxel_gi: VoxelGI
var _built := false                     # the room is whole: the bounce may be made


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
	_build_dapple()
	_scope = PatternScope.new()
	_scope.position = SCOPE_AT
	add_child(_scope)
	_solids.append(_scope.body_shape)
	_shape_mat = StandardMaterial3D.new()
	_shape_mat.albedo_color = Color(0.25, 0.25, 0.25)
	_shape_mat.roughness = 0.8
	_build_panels()
	_panel.restore()
	_build_shell()
	_rebuild_lights()
	_rebuild_shapes()
	_set_room_lamp()
	_set_scope()
	_set_dapple()
	_built = true
	_set_bounce(_picked("Bounce light"))
	for node in player.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
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
	_panel.switch(lantern, "Passable", false, func(v: bool) -> void:
		for c: CollisionShape3D in _solids:
			c.disabled = v)
	_panel.note(lantern, "Lets you walk into the lanterns and put your head inside.")
	_panel.switch(lantern, "Model beside it", true, func(v: bool) -> void: _model.visible = v)
	_panel.note(lantern, "A copy of the lantern 3 m to the west with its lights off, lit softly inside, the shapes moving in step with the real ones and small markers where the lights stand. Look in through its hole.")
	_panel.slider(lantern, "Room lamp", 0.0, 1.0, 0.01, 0.0, func(_v: float) -> void: _set_room_lamp())

	var scope := _panel.panel("Telescope")
	var rescope := func(_v: Variant) -> void: _set_scope()
	_panel.switch(scope, "Telescope on", true, rescope)
	_panel.choice(scope, "Pattern", PatternScope.PATTERNS, "Caustics", rescope)
	_panel.note(scope, "Caustics: sunlight through rippling water gathered into bright lines, traced ray by ray through the surface. Reaction: two chemicals spreading and reacting, growing spots, mazes or coral. Interference: waves from five drifting sources adding and cancelling. Convection: the cells of a liquid heated from below, seen from above.")
	_panel.slider(scope, "Pattern speed", 0.0, 3.0, 0.01, 1.0, rescope)
	_panel.slider(scope, "Pattern setting", 0.5, 2.0, 0.01, 1.0, rescope)
	_panel.note(scope, "Caustics: how deep the water, so how strongly the ripples gather the light. Reaction: from dividing spots (low) through mazes to coral (high). Interference: the wavelength. Convection: how much the cells are enlarged.")
	_panel.button(scope, "Start the pattern again", func() -> void: _scope.reset())
	_panel.slider(scope, "Brightness", 0.0, 400.0, 1.0, 120.0, rescope)
	_panel.colour(scope, "Telescope colour", Color(1.0, 0.95, 0.85), rescope)
	_panel.slider(scope, "Focal length (cm)", 5.0, 40.0, 0.5, 8.0, rescope)
	_panel.note(scope, "The lens's focal length: the picture on the wall is the 6 cm plate enlarged by the wall's distance over this. Short makes it large and dim, long small and bright.")
	_panel.slider(scope, "Out of focus", 0.0, 1.0, 0.01, 0.0, rescope)
	_panel.switch(scope, "Open the tube", false, rescope)
	_panel.note(scope, "Hides the tube, to show the plate with its pattern at the back and the lamp shining on it.")

	var bounce := _panel.panel("Bounce")
	var redapple := func(_v: Variant) -> void: _set_dapple()
	_panel.switch(bounce, "Dappled light on", true, redapple)
	_panel.slider(bounce, "Dapple brightness", 0.0, 100.0, 0.5, 30.0, redapple)
	_panel.slider(bounce, "Dapple speed", 0.0, 2.0, 0.01, 0.3, func(_v: float) -> void: pass)
	_panel.slider(bounce, "Dapple size", 0.25, 4.0, 0.05, 1.0, redapple)
	_panel.note(bounce, "The size of the bright and dark patches. At the largest only one or two lie on the panel at a time, the most the bounce could follow.")
	_panel.note(bounce, "A spot light high above throws a dappled picture onto the white panel on the floor by the wall, turning slowly. The question is how much of the dapple the bounce light carries onto the wall and the ceiling.")
	_panel.choice(bounce, "Bounce light", ["None", "VoxelGI", "SDFGI"], "VoxelGI", func(o: String) -> void:
		if _built:
			_set_bounce(o))
	_panel.note(bounce, "VoxelGI: a box round the room divided into cells about 11 cm across, made once when chosen (the screen pauses), then lit afresh every frame. SDFGI: cells round wherever you stand, finer near you, made as you move. Both treat a lit surface as glowing evenly in every direction.")
	_panel.slider(bounce, "Bounce strength", 0.0, 8.0, 0.05, 1.0, redapple)
	_panel.note(bounce, "How strongly the dappled light enters the bounce, on top of the true amount (1). Raise it to see the bounce's shape more easily.")

	var view := _panel.panel("Viewport")
	_panel.choice(view, "Soft shadows", QUALITIES.keys(), "Low", func(o: String) -> void:
		RenderingServer.positional_soft_shadow_filter_set_quality(int(QUALITIES[o])))
	_panel.note(view, "How many samples each pixel takes of a light's shadow map to blur the shadow. Low is grainy in wide soft edges; higher is smoother and costs more. Hard turns the softening off.")
	_panel.choice(view, "Shadow atlas", ATLAS_SIZES, str(get_viewport().positional_shadow_atlas_size), func(o: String) -> void:
		get_viewport().positional_shadow_atlas_size = int(o))
	_panel.note(view, "The size of the picture that holds every light's shadow map. A larger one gives sharper shadows: magnified twenty times onto the screen, a shadow map's squares can show.")


## The telescope as the panel has it; a new pattern starts afresh.
func _set_scope() -> void:
	if _scope == null or _panel == null:
		return
	var index := maxi(PatternScope.PATTERNS.find(_picked("Pattern")), 0)
	if index != _scope.pattern:
		_scope.pattern = index
		_scope.reset()
	_scope.speed = _value("Pattern speed")
	_scope.setting = _value("Pattern setting")
	_scope.focus_blur = _value("Out of focus")
	_scope.set_on((_panel.switches["Telescope on"] as CheckButton).button_pressed)
	_scope.set_open((_panel.switches["Open the tube"] as CheckButton).button_pressed)
	_scope.set_beam(_value("Brightness"), (_panel.pickers["Telescope colour"] as ColorPickerButton).color,
		_value("Focal length (cm)") * 0.01)


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
	_env = env
	# Not 0.2 m: every wall, floor and ceiling here lies on 0.2 m
	# multiples, where SDFGI's smallest cells gave no bounce at all.
	env.sdfgi_min_cell_size = 0.15
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
	_shell = _lantern_parts(self, metal, 1)
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	_model = Node3D.new()
	_model.position = MODEL_OFFSET
	add_child(_model)
	_model_shell = _lantern_parts(_model, metal, MODEL)
	_model_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fill := OmniLight3D.new()
	# Just inside the hole, so the shapes are lit on the side one sees.
	fill.position = CENTRE + Vector3(0.0, 0.0, -0.35)
	fill.omni_range = 1.5
	fill.light_energy = 0.25
	fill.light_cull_mask = MODEL
	_model.add_child(fill)


## A lantern's solid ball, stand and empty shell node under `parent`, on
## render layer `layer`; the shell node is returned for its mesh.
func _lantern_parts(parent: Node3D, metal: Material, layer: int) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.position = CENTRE
	parent.add_child(body)
	var ball := SphereShape3D.new()
	ball.radius = R
	var collide := CollisionShape3D.new()
	collide.shape = ball
	body.add_child(collide)
	_solids.append(collide)
	var post := CylinderMesh.new()
	post.top_radius = 0.025
	post.bottom_radius = 0.025
	post.height = CENTRE.y - R
	post.material = metal
	var post_view := MeshInstance3D.new()
	post_view.mesh = post
	post_view.position = Vector3(CENTRE.x, (CENTRE.y - R) * 0.5, CENTRE.z)
	post_view.layers = layer
	parent.add_child(post_view)
	var foot := CylinderMesh.new()
	foot.top_radius = 0.2
	foot.bottom_radius = 0.22
	foot.height = 0.04
	foot.material = metal
	var foot_view := MeshInstance3D.new()
	foot_view.mesh = foot
	foot_view.position = Vector3(CENTRE.x, 0.02, CENTRE.z)
	foot_view.layers = layer
	parent.add_child(foot_view)
	var shell := MeshInstance3D.new()
	shell.position = CENTRE
	shell.layers = layer
	parent.add_child(shell)
	return shell


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
	_model_shell.mesh = mesh
	_rebuild_lights()


## ---- the lights ------------------------------------------------------------

## Each light made afresh as its panel says, at its place on a circle
## round the middle of the lantern's back, facing the hole.
func _rebuild_lights() -> void:
	if _panel == null or _shell == null:
		return
	var spread := _value("Spread (cm)") * 0.01
	var hole_r := _value("Hole (cm)") * 0.005
	for mark: MeshInstance3D in _model_marks:
		mark.queue_free()
	_model_marks.clear()
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
		light.light_cull_mask = 0xFFFFF & ~MODEL
		add_child(light)
		light.global_transform = Transform3D(Basis.looking_at(to_hole.normalized(), Vector3.UP), at)
		_lights[i] = light
		_model_marks.append(_mark(kind, colour, maxf(size, 0.02), at, to_hole))


## A small glowing stand-in for a light in the model: a ball for a point
## or spot light, a thin square for an area light, at the light's size
## (at least 2 cm).
func _mark(kind: String, colour: Color, size: float, at: Vector3, facing: Vector3) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.emission_enabled = true
	mat.emission = colour
	mat.emission_energy_multiplier = 2.0
	var mesh: Mesh
	if kind == "Area":
		var box := BoxMesh.new()
		box.size = Vector3(size, size, 0.003)
		mesh = box
	else:
		var ball := SphereMesh.new()
		ball.radius = size * 0.5
		ball.height = size
		mesh = ball
	mesh.surface_set_material(0, mat)
	var mark := MeshInstance3D.new()
	mark.mesh = mesh
	mark.layers = MODEL
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	_model.add_child(mark)
	mark.transform = Transform3D(Basis.looking_at(facing.normalized(), Vector3.UP), at)
	return mark


## ---- the shapes ------------------------------------------------------------

## The shapes made afresh, each with its own rates and phases drawn from
## a fixed seed, so the same settings give the same dance.
func _rebuild_shapes() -> void:
	if _panel == null:
		return
	for s: Dictionary in _shapes:
		(s["node"] as Node).queue_free()
		(s["copy"] as Node).queue_free()
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
		node.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		add_child(node)
		var copy := MeshInstance3D.new()
		copy.mesh = mesh
		copy.layers = MODEL
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		copy.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		_model.add_child(copy)
		_shapes.append({
			"node": node,
			"copy": copy,
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
		var copy := s["copy"] as Node3D
		copy.transform = node.transform


func _process(delta: float) -> void:
	_phase += _value("Speed") * delta
	_place_shapes()
	_dapple_turn += _value("Dapple speed") * 0.25 * delta
	_dapple.transform = Transform3D(_dapple_aim() * Basis(Vector3.FORWARD, _dapple_turn), DAPPLE_LIGHT)


## ---- the bounce test -------------------------------------------------------

## The white panel on the floor, and the spot light above it carrying a
## dappled picture: engine noise (simplex, three octaves), its contrast
## raised by a colour ramp, mipmapped as projectors need. The cone just
## fits the panel. Godot draws a projector picture only from a light that
## casts shadows.
func _build_dapple() -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.85, 0.85, 0.83)
	white.roughness = 0.95
	_slab_between(DAPPLE_PANEL + Vector3(-1.0, 0.0, -1.0), DAPPLE_PANEL + Vector3(1.0, 0.04, 1.0), white)
	_dapple = SpotLight3D.new()
	_dapple.shadow_enabled = true
	_dapple.spot_range = 8.0
	_dapple.spot_attenuation = 2.0
	_dapple.spot_angle_attenuation = 0.1
	var down := DAPPLE_PANEL + Vector3(0.0, 0.04, 0.0) - DAPPLE_LIGHT
	_dapple.spot_angle = rad_to_deg(atan(0.95 / down.length()))
	add_child(_dapple)
	_dapple.transform = Transform3D(_dapple_aim(), DAPPLE_LIGHT)


func _dapple_picture(frequency: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = frequency
	noise.fractal_octaves = 3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0, 0, 0))
	ramp.set_color(1, Color(1, 1, 1))
	ramp.set_offset(0, 0.4)
	ramp.set_offset(1, 0.6)
	var picture := NoiseTexture2D.new()
	picture.width = 512
	picture.height = 512
	picture.seamless = true
	picture.generate_mipmaps = true
	picture.noise = noise
	picture.color_ramp = ramp
	return picture


func _dapple_aim() -> Basis:
	var down := DAPPLE_PANEL + Vector3(0.0, 0.04, 0.0) - DAPPLE_LIGHT
	return Basis.looking_at(down.normalized(), Vector3.FORWARD)


func _set_dapple() -> void:
	if _dapple == null or _panel == null:
		return
	_dapple.visible = (_panel.switches["Dappled light on"] as CheckButton).button_pressed
	_dapple.light_energy = _value("Dapple brightness")
	_dapple.light_indirect_energy = _value("Bounce strength")
	# A new picture each time: the projector would keep the old one if it
	# were changed in place.
	var frequency := 0.012 / _value("Dapple size")
	var picture := _dapple.light_projector as NoiseTexture2D
	if picture == null or not is_equal_approx(picture.noise.frequency, frequency):
		_dapple.light_projector = _dapple_picture(frequency)


## The bounce method: SDFGI in the environment, or a VoxelGI box round
## the room, baked now.
func _set_bounce(option: String) -> void:
	_env.sdfgi_enabled = option == "SDFGI"
	if _voxel_gi != null:
		_voxel_gi.queue_free()
		_voxel_gi = null
	if option == "VoxelGI":
		_voxel_gi = VoxelGI.new()
		_voxel_gi.size = ROOM + Vector3(0.6, 0.6, 0.6)
		_voxel_gi.position.y = ROOM.y * 0.5
		add_child(_voxel_gi)
		_voxel_gi.bake()
