class_name PatternScope
extends Node3D
## A projector built like a telescope, pointing along its -Z: a tube 1 m
## long and 20 cm across on a stand. At its back a small round plate, the
## gate, 6 cm across, shows a moving pattern; a lamp inside the tube
## shines on it; the light it sends back leaves through the lens at the
## front and spreads, so a wall in front shows the gate's pattern
## enlarged.
##
## Drawn by the engine: the gate is a matte plate whose colour is the
## pattern, lit by a spot light in the tube; the light leaving the lens is
## a second spot light carrying the pattern as its projector picture,
## its cone as wide as the gate seen from the lens's focal length, so the
## picture's size on a wall is the gate's times the wall's distance over
## the focal length. Godot draws a projector picture only while its light
## casts shadows, and does not take up a picture changed in place, so the
## pattern goes into one of two pictures in turn and the light is handed
## the new one each frame.
##
## Custom: the pattern, worked out on the graphics card by a compute
## shader (scope_pattern.glsl) on a grid 256 square that wraps at its
## edges, on a rendering device of its own, and read back each frame.
## Four patterns: Caustics (light through rippling water), Reaction
## (Gray-Scott), Interference (waves from drifting sources), Convection
## (Swift-Hohenberg). Out of focus, the picture is blurred as a lens
## spreads each point into a disc.

const SIZE := 256
const RAYS := 1024                      # caustic rays per side: sixteen a pixel
const GATE_R := 0.03
const TUBE_R := 0.1
const TUBE_L := 1.0
const PATTERNS := ["Caustics", "Reaction", "Interference", "Convection"]
# Convection's grid spacing, its rolls 2 pi wide so about 8 points, and a
# time step inside the limit for that spacing, 2 / (8 / h^2 - 1)^2.
const CONVECT_H := 0.8
const CONVECT_DT := 0.0075

var pattern := 0
var speed := 1.0
var setting := 1.0
var focus_blur := 0.0                   # 0 sharp to 1 blurred
var on := true

var body_shape: CollisionShape3D
var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _states: Array[RID] = []
var _tally: RID
var _picture: RID
var _sets: Array[RID] = []              # [0]: state 0 in, 1 out; [1]: the other way
var _current := 0                       # which state holds the present one
var _time := 0.0
var _seed := 0.0
var _textures: Array[ImageTexture] = []
var _shown := 0
var _gate_mat: StandardMaterial3D
var _lens_mat: StandardMaterial3D
var _lamp: SpotLight3D
var _beam: SpotLight3D
var _tube: MeshInstance3D


func _ready() -> void:
	_build_body()
	_build_lights()
	_start_device()


func _exit_tree() -> void:
	if _rd == null:
		return
	for rid: RID in _sets + _states + [_tally, _picture, _pipeline, _shader]:
		if rid.is_valid():
			_rd.free_rid(rid)
	_rd.free()
	_rd = null


## ---- the instrument --------------------------------------------------------

func _build_body() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.06, 0.06, 0.065)
	metal.metallic = 0.6
	metal.roughness = 0.4
	metal.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tube := CylinderMesh.new()
	tube.top_radius = TUBE_R
	tube.bottom_radius = TUBE_R
	tube.height = TUBE_L
	tube.cap_top = false
	tube.cap_bottom = false
	tube.radial_segments = 48
	tube.material = metal
	_tube = MeshInstance3D.new()
	_tube.mesh = tube
	_tube.rotation_degrees.x = 90.0
	_tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	add_child(_tube)
	var back := CylinderMesh.new()
	back.top_radius = TUBE_R
	back.bottom_radius = TUBE_R
	back.height = 0.02
	back.material = metal
	var back_view := MeshInstance3D.new()
	back_view.mesh = back
	back_view.rotation_degrees.x = 90.0
	back_view.position.z = TUBE_L * 0.5
	add_child(back_view)

	# The gate: a matte plate at the back facing forward, its colour the
	# pattern, lit by the lamp.
	_gate_mat = StandardMaterial3D.new()
	_gate_mat.roughness = 1.0
	var gate := CylinderMesh.new()
	gate.top_radius = GATE_R
	gate.bottom_radius = GATE_R
	gate.height = 0.004
	gate.material = _gate_mat
	var gate_view := MeshInstance3D.new()
	gate_view.mesh = gate
	gate_view.rotation_degrees.x = 90.0
	gate_view.position.z = TUBE_L * 0.5 - 0.1
	gate_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gate_view)

	# The lens: a disc of glass at the front, glowing faintly with the
	# pattern as the gate would be seen through it.
	_lens_mat = StandardMaterial3D.new()
	_lens_mat.albedo_color = Color(0.02, 0.02, 0.02)
	_lens_mat.roughness = 0.05
	_lens_mat.emission_enabled = true
	_lens_mat.emission_energy_multiplier = 0.6
	var lens := CylinderMesh.new()
	lens.top_radius = TUBE_R * 0.9
	lens.bottom_radius = TUBE_R * 0.9
	lens.height = 0.01
	lens.material = _lens_mat
	var lens_view := MeshInstance3D.new()
	lens_view.mesh = lens
	lens_view.rotation_degrees.x = 90.0
	lens_view.position.z = -TUBE_L * 0.5 + 0.02
	lens_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lens_view)

	# The stand: a post from the floor to the tube's middle.
	var height := position.y
	var post := CylinderMesh.new()
	post.top_radius = 0.025
	post.bottom_radius = 0.025
	post.height = height - TUBE_R
	post.material = metal
	var post_view := MeshInstance3D.new()
	post_view.mesh = post
	post_view.position.y = -(height + TUBE_R) * 0.5
	add_child(post_view)
	var foot := CylinderMesh.new()
	foot.top_radius = 0.2
	foot.bottom_radius = 0.22
	foot.height = 0.04
	foot.material = metal
	var foot_view := MeshInstance3D.new()
	foot_view.mesh = foot
	foot_view.position.y = -height + 0.02
	add_child(foot_view)

	var solid := StaticBody3D.new()
	add_child(solid)
	var shape := CylinderShape3D.new()
	shape.radius = TUBE_R
	shape.height = TUBE_L
	body_shape = CollisionShape3D.new()
	body_shape.shape = shape
	body_shape.rotation_degrees.x = 90.0
	solid.add_child(body_shape)


## The lamp on the gate, from just inside the tube's wall, and the beam
## leaving the lens.
func _build_lights() -> void:
	_lamp = SpotLight3D.new()
	var gate_at := Vector3(0.0, 0.0, TUBE_L * 0.5 - 0.1)
	var lamp_at := Vector3(0.0, TUBE_R * 0.7, TUBE_L * 0.5 - 0.4)
	add_child(_lamp)
	_lamp.position = lamp_at
	_lamp.look_at(to_global(gate_at), Vector3.UP)
	_lamp.spot_range = 1.0
	_lamp.spot_angle = rad_to_deg(atan((GATE_R + 0.005) / (gate_at - lamp_at).length()))
	_lamp.spot_angle_attenuation = 0.2
	_lamp.light_energy = 6.0
	_beam = SpotLight3D.new()
	_beam.position = Vector3(0.0, 0.0, -TUBE_L * 0.5 - 0.02)
	_beam.spot_range = 20.0
	_beam.spot_attenuation = 2.0
	_beam.spot_angle_attenuation = 0.05
	_beam.shadow_enabled = true
	add_child(_beam)


## The beam's strength and colour, and the lens's focal length in metres:
## the cone's half-angle is the gate's radius seen from that distance.
func set_beam(energy: float, colour: Color, focal: float) -> void:
	_beam.light_energy = energy
	_beam.light_color = colour
	_lamp.light_color = colour
	_beam.spot_angle = rad_to_deg(atan(GATE_R / maxf(focal, 0.01)))


func set_on(value: bool) -> void:
	on = value
	_beam.visible = on
	_lamp.visible = on
	_lens_mat.emission_energy_multiplier = 0.6 if on else 0.0


## The tube drawn or hidden, to see the gate and the lamp.
func set_open(open: bool) -> void:
	_tube.visible = not open


## ---- the pattern -----------------------------------------------------------

func _start_device() -> void:
	_rd = RenderingServer.create_local_rendering_device()
	if _rd == null:
		return
	var file := load("res://world/scope_pattern.glsl") as RDShaderFile
	_shader = _rd.shader_create_from_spirv(file.get_spirv())
	_pipeline = _rd.compute_pipeline_create(_shader)
	var fmt := RDTextureFormat.new()
	fmt.width = SIZE
	fmt.height = SIZE
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	for i in 2:
		_states.append(_rd.texture_create(fmt, RDTextureView.new()))
	var tally_fmt := RDTextureFormat.new()
	tally_fmt.width = SIZE
	tally_fmt.height = SIZE
	tally_fmt.format = RenderingDevice.DATA_FORMAT_R32_UINT
	tally_fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	_tally = _rd.texture_create(tally_fmt, RDTextureView.new())
	var pic_fmt := RDTextureFormat.new()
	pic_fmt.width = SIZE
	pic_fmt.height = SIZE
	pic_fmt.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	pic_fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	_picture = _rd.texture_create(pic_fmt, RDTextureView.new())
	for i in 2:
		var uniforms: Array[RDUniform] = []
		for pair: Array in [[0, _states[i]], [1, _states[1 - i]], [2, _tally], [3, _picture]]:
			var u := RDUniform.new()
			u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
			u.binding = int(pair[0])
			u.add_id(pair[1])
			uniforms.append(u)
		_sets.append(_rd.uniform_set_create(uniforms, _shader, 0))
	var blank := Image.create(SIZE, SIZE, true, Image.FORMAT_RGBA8)
	for i in 2:
		_textures.append(ImageTexture.create_from_image(blank))
	reset()


## Start the reaction and the convection afresh from a new random seed.
func reset() -> void:
	if _rd == null:
		return
	_seed = randf()
	var list := _rd.compute_list_begin()
	for i in 2:
		_dispatch(list, 0, i, SIZE)
	_rd.compute_list_end()
	_rd.submit()
	_rd.sync()


func _dispatch(list: int, stage: int, set_index: int, extent: int) -> void:
	var params := PackedByteArray()
	params.resize(48)
	params.encode_s32(0, stage)
	params.encode_s32(4, pattern)
	params.encode_s32(8, SIZE)
	params.encode_s32(12, RAYS)
	params.encode_float(16, _time)
	params.encode_float(20, setting)
	params.encode_float(24, focus_blur * 10.0)
	params.encode_float(28, _seed)
	params.encode_float(32, CONVECT_DT)
	params.encode_float(36, CONVECT_H)
	params.encode_float(40, 0.03)
	params.encode_float(44, 0.0)
	_rd.compute_list_bind_compute_pipeline(list, _pipeline)
	_rd.compute_list_bind_uniform_set(list, _sets[set_index], 0)
	_rd.compute_list_set_push_constant(list, params, params.size())
	var groups := ceili(extent / 8.0)
	_rd.compute_list_dispatch(list, groups, groups, 1)
	_rd.compute_list_add_barrier(list)


## Time steps for the reaction and the convection this frame: the
## reaction 16 a frame at speed 1; the convection enough steps for half a
## unit of its time.
func _steps() -> int:
	if pattern == 1:
		return roundi(16.0 * speed)
	if pattern == 3:
		return mini(roundi(0.5 * speed / CONVECT_DT), 400)
	return 0


func _process(delta: float) -> void:
	if _rd == null or not on:
		return
	_time += delta * speed
	var list := _rd.compute_list_begin()
	if pattern == 0:
		_dispatch(list, 1, _current, SIZE)
		_dispatch(list, 2, _current, RAYS)
	elif pattern == 1 or pattern == 3:
		for i in _steps():
			_dispatch(list, 3, _current, SIZE)
			_current = 1 - _current
	_dispatch(list, 4, _current, SIZE)
	_rd.compute_list_end()
	_rd.submit()
	_rd.sync()
	var img := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, _rd.texture_get_data(_picture, 0))
	img.generate_mipmaps()
	_shown = 1 - _shown
	var tex := _textures[_shown]
	tex.update(img)
	_beam.light_projector = tex
	_gate_mat.albedo_texture = tex
	_lens_mat.emission_texture = tex
