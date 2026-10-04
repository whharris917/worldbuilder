class_name LightPool
extends Node3D
## A closed room ten metres every way, most of its floor a shallow pool
## whose bottom is glass, lit by one bare lamp in a dark chamber under
## the glass. Its only light comes up through the water, so the room is
## lit from below: the ceiling brightest, the walls fading downward, the
## deck around the pool in the room's own reflected light.
##
## The water is a grid of heights stepped by the wave equation each
## frame on the GPU (pool_ripples.gdshader, two SubViewports taking
## turns, each reading what the other wrote). The player's legs push
## it aside where they wade and a jump into it splashes; the ripples run
## out, come back off the pool's sides and die away. The water is drawn
## from the grid (pool_water.gdshader), and the same grid bends the
## lamp's light: for each face of the room above the deck one
## SubViewport draws where that light lands, a tile for each face
## (pool_caustics.gdshader), and the face multiplies the lamp's light by
## its tile (pool_room.gdshader).
## Still water lights the room evenly; moving water throws a net of
## bright lines across it.
##
## Bounce light is a VoxelGI box around the room and the chamber, baked
## on arrival, traced at half the screen's resolution and low quality
## (both engine-wide, put back when the scene closes); the water and
## the lamp's glass take no part in it.

const ROOM := 10.0                     # inside, every way
const POOL_HALF := 4.0                 # the pool is 8 m square
const WATER_Y := -0.05                 # the deck is at 0
const GLASS_TOP := -0.35               # 30 cm of water
const GLASS_BOTTOM := -0.40
const BEAM_DEPTH := 0.30               # the steel under the glass
const SLAB_BOTTOM := -0.80
const CHAMBER_FLOOR := -3.2
const LAMP := Vector3(0.0, -2.4, 0.0)  # 2 m under the glass
const WALL := 0.3
const START := Vector3(0.0, 0.0, 4.5)
const SIM_SIZE := 256                  # ripple texels across the pool
const CAUSTIC_SIZE := 512              # texels across each face
const WAVE_SPEED := 0.6                # m/s, the ripples' speed
const LEG_RADIUS := 0.12               # m, the push of one leg
const LEG_APART := 0.11                # m, each leg from the body's centre

@onready var player: Player = $Player

var _sims: Array[SubViewport] = []
var _sim_mats: Array[ShaderMaterial] = []
var _sim_turn := 0
var _caustic_mats: Array[ShaderMaterial] = []
var _water_mat: ShaderMaterial
var _atlas_was: Array = []              # the shadow atlas's size and first quadrant, as found
var _last_feet := Vector3.ZERO
var _wading := false                    # the player's feet in the water; their steps splash
var _fall := 0.0                        # m/s, the fastest fall since last on the floor


func _ready() -> void:
	player.global_position = START
	for node in player.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	# The lamp's shadow map gets a quarter of an 8192 atlas to itself: its
	# shadows are thrown 10 m and would show their texels as steps.
	var vp := get_viewport()
	_atlas_was = [vp.positional_shadow_atlas_size, vp.get_positional_shadow_atlas_quadrant_subdiv(0)]
	vp.positional_shadow_atlas_size = 8192
	vp.set_positional_shadow_atlas_quadrant_subdiv(0, Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1)
	_build_ripples()
	_build_room()
	_build_pool()
	_build_lamp()
	RenderingServer.gi_set_use_half_resolution(true)
	RenderingServer.voxel_gi_set_quality(RenderingServer.VOXEL_GI_QUALITY_LOW)
	var gi := VoxelGI.new()
	gi.subdiv = VoxelGI.SUBDIV_64
	gi.size = Vector3(ROOM + 1.0, ROOM - CHAMBER_FLOOR + 1.0, ROOM + 1.0)
	gi.position.y = (ROOM + CHAMBER_FLOOR) * 0.5
	add_child(gi)
	gi.bake()
	var probe := ReflectionProbe.new()
	probe.size = Vector3(ROOM, ROOM, ROOM)
	probe.position.y = ROOM * 0.5
	probe.origin_offset = Vector3(0.0, 1.5 - ROOM * 0.5, 0.0)
	probe.box_projection = true
	probe.interior = true
	add_child(probe)
	MouseMode.capture()


## ---- the ripples -----------------------------------------------------------

func _build_ripples() -> void:
	for i in 2:
		var vp := SubViewport.new()
		vp.size = Vector2i(SIM_SIZE, SIM_SIZE)
		vp.use_hdr_2d = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.transparent_bg = true
		var rect := ColorRect.new()
		rect.size = Vector2(SIM_SIZE, SIM_SIZE)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://world/pool_ripples.gdshader")
		rect.material = mat
		vp.add_child(rect)
		add_child(vp)
		_sims.append(vp)
		_sim_mats.append(mat)
	_sim_mats[0].set_shader_parameter("prev", _sims[1].get_texture())
	_sim_mats[1].set_shader_parameter("prev", _sims[0].get_texture())


## One step of the water each frame: the two grids take turns, each
## reading the other. The step is as long as the frame, held to a
## stable size.
func _step_ripples(delta: float) -> void:
	_sim_turn = 1 - _sim_turn
	var vp := _sims[_sim_turn]
	var mat := _sim_mats[_sim_turn]
	var dx := 2.0 * POOL_HALF / SIM_SIZE
	var c := WAVE_SPEED * minf(delta, 1.0 / 30.0) / dx
	mat.set_shader_parameter("courant", minf(c * c, 0.45))
	var pushes := _pushes(delta)
	mat.set_shader_parameter("push_a", pushes[0])
	mat.set_shader_parameter("push_b", pushes[1])
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var tex := vp.get_texture()
	_water_mat.set_shader_parameter("ripples", tex)
	for m in _caustic_mats:
		m.set_shader_parameter("ripples", tex)


## The player's legs, where they stand in the water: each pushes the
## surface as far as the player moves this frame, so wading leaves a
## wake and standing still leaves the water to settle; the footsteps
## splash while the feet are in it. Landing in the
## water from a jump pushes once, as hard as the fall.
func _pushes(delta: float) -> Array[Vector4]:
	var out: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO]
	var grounded := player.is_on_floor()
	var landing := _fall if grounded else 0.0
	_fall = 0.0 if grounded else maxf(-player.velocity.y, _fall)
	var feet := player.global_position
	var wading := absf(feet.x) < POOL_HALF and absf(feet.z) < POOL_HALF and feet.y < WATER_Y
	if wading != _wading:
		_wading = wading
		player.use_steps("wade" if wading else "")
	if not wading:
		_last_feet = feet
		return out
	var moved := Vector2(feet.x - _last_feet.x, feet.z - _last_feet.z).length()
	_last_feet = feet
	var depth := -0.012 * minf(moved, 5.0 * delta)
	var radius := LEG_RADIUS / (2.0 * POOL_HALF)
	if landing > 1.0:
		depth -= 0.004 * landing
		radius *= 2.5
	if depth == 0.0:
		return out
	var side := player.global_transform.basis.x * LEG_APART
	for i in 2:
		var leg := feet + side * (1.0 if i == 0 else -1.0)
		var uv := Vector2(leg.x, leg.z) / (2.0 * POOL_HALF) + Vector2(0.5, 0.5)
		out[i] = Vector4(uv.x, uv.y, radius, depth)
	return out


func _process(delta: float) -> void:
	_step_ripples(delta)


func _exit_tree() -> void:
	var vp := get_viewport()
	vp.positional_shadow_atlas_size = _atlas_was[0]
	vp.set_positional_shadow_atlas_quadrant_subdiv(0, _atlas_was[1])
	RenderingServer.gi_set_use_half_resolution(ProjectSettings.get_setting("rendering/global_illumination/gi/use_half_resolution", false))
	RenderingServer.voxel_gi_set_quality(ProjectSettings.get_setting("rendering/global_illumination/voxel_gi/quality", 0))


## ---- the room --------------------------------------------------------------

## The ceiling and four walls, each a slab with its own tile of the
## caustic texture: one SubViewport, three tiles by two, drawn in one
## pass. A face's tile covers it from the deck to the ceiling and wall
## to wall, a little over.
func _build_room() -> void:
	var h := ROOM * 0.5
	var over := h + 0.05
	var plaster := Color(0.80, 0.78, 0.74)
	# normal axis, sign, u axis, v axis, centre, slab centre, slab size
	var faces := [
		[Vector3.UP, 1.0, Vector3.RIGHT, Vector3.BACK, Vector2(0.0, 0.0),
			Vector3(0.0, ROOM + WALL * 0.5, 0.0), Vector3(ROOM + 2.0 * WALL, WALL, ROOM + 2.0 * WALL)],
		[Vector3.RIGHT, 1.0, Vector3.BACK, Vector3.UP, Vector2(0.0, h),
			Vector3(h + WALL * 0.5, h, 0.0), Vector3(WALL, ROOM, ROOM)],
		[Vector3.RIGHT, -1.0, Vector3.BACK, Vector3.UP, Vector2(0.0, h),
			Vector3(-h - WALL * 0.5, h, 0.0), Vector3(WALL, ROOM, ROOM)],
		[Vector3.BACK, 1.0, Vector3.RIGHT, Vector3.UP, Vector2(0.0, h),
			Vector3(0.0, h, h + WALL * 0.5), Vector3(ROOM + 2.0 * WALL, ROOM, WALL)],
		[Vector3.BACK, -1.0, Vector3.RIGHT, Vector3.UP, Vector2(0.0, h),
			Vector3(0.0, h, -h - WALL * 0.5), Vector3(ROOM + 2.0 * WALL, ROOM, WALL)],
	]
	var grid := PlaneMesh.new()
	grid.size = Vector2(2.0 * POOL_HALF, 2.0 * POOL_HALF)
	grid.subdivide_width = SIM_SIZE - 1
	grid.subdivide_depth = SIM_SIZE - 1
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var vp := SubViewport.new()
	vp.size = Vector2i(3 * CAUSTIC_SIZE, 2 * CAUSTIC_SIZE)
	vp.use_hdr_2d = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 100.0
	vp.add_child(cam)
	cam.current = true
	add_child(vp)
	var tile_scale := Vector2(1.0 / 3.0, 0.5)
	for i in faces.size():
		var f: Array = faces[i]
		var n: Vector3 = f[0]
		var sgn: float = f[1]
		var u: Vector3 = f[2]
		var v: Vector3 = f[3]
		var centre: Vector2 = f[4]
		var plane: float = ROOM if n == Vector3.UP else h * sgn
		var tile := Vector2i(i % 3, i / 3)
		var mesh := MeshInstance3D.new()
		mesh.mesh = grid
		mesh.position = Vector3(0.0, 0.0, -20.0)
		mesh.custom_aabb = AABB(Vector3(-40, -40, -10), Vector3(80, 80, 20))
		var mat := ShaderMaterial.new()
		mat.shader = load("res://world/pool_caustics.gdshader")
		mat.set_shader_parameter("lamp", LAMP)
		mat.set_shader_parameter("glass_y", GLASS_BOTTOM)
		mat.set_shader_parameter("water_y", WATER_Y)
		mat.set_shader_parameter("pool_half", POOL_HALF)
		mat.set_shader_parameter("n_mask", n)
		mat.set_shader_parameter("u_mask", u)
		mat.set_shader_parameter("v_mask", v)
		mat.set_shader_parameter("plane", plane)
		mat.set_shader_parameter("sgn", sgn)
		mat.set_shader_parameter("centre", centre)
		mat.set_shader_parameter("half_size", Vector2(over, over))
		mat.set_shader_parameter("tile", tile)
		mat.set_shader_parameter("tile_px", CAUSTIC_SIZE)
		mesh.material_override = mat
		vp.add_child(mesh)
		_caustic_mats.append(mat)

		var face_mat := ShaderMaterial.new()
		face_mat.shader = load("res://world/pool_room.gdshader")
		face_mat.set_shader_parameter("albedo", plaster)
		face_mat.set_shader_parameter("caustics", vp.get_texture())
		face_mat.set_shader_parameter("u_mask", u)
		face_mat.set_shader_parameter("v_mask", v)
		face_mat.set_shader_parameter("centre", centre)
		face_mat.set_shader_parameter("half_size", Vector2(over, over))
		face_mat.set_shader_parameter("tile_origin", Vector2(tile) * tile_scale)
		face_mat.set_shader_parameter("tile_scale", tile_scale)
		_slab(f[5], f[6], face_mat)


## A box drawn and solid.
func _slab(centre: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	mi.position = centre
	add_child(mi)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	body.position = centre
	add_child(body)
	return mi


## ---- the pool --------------------------------------------------------------

## The deck is four slabs round the pool, their inner faces its sides;
## the glass sits on a 2 m grid of steel that spans the chamber below.
func _build_pool() -> void:
	var stone := _stone()
	var h := ROOM * 0.5
	var ring := h - POOL_HALF
	var depth := -SLAB_BOTTOM
	var y := SLAB_BOTTOM * 0.5
	_slab(Vector3(0.0, y, POOL_HALF + ring * 0.5), Vector3(ROOM, depth, ring), stone)
	_slab(Vector3(0.0, y, -POOL_HALF - ring * 0.5), Vector3(ROOM, depth, ring), stone)
	_slab(Vector3(POOL_HALF + ring * 0.5, y, 0.0), Vector3(ring, depth, 2.0 * POOL_HALF), stone)
	_slab(Vector3(-POOL_HALF - ring * 0.5, y, 0.0), Vector3(ring, depth, 2.0 * POOL_HALF), stone)

	# The glass: solid to walk on, drawn by the water above it.
	var glass := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.0 * POOL_HALF, GLASS_TOP - GLASS_BOTTOM, 2.0 * POOL_HALF)
	shape.shape = bs
	glass.add_child(shape)
	glass.position.y = (GLASS_TOP + GLASS_BOTTOM) * 0.5
	add_child(glass)

	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.16, 0.16, 0.17)
	steel.metallic = 0.6
	steel.roughness = 0.45
	var by := GLASS_BOTTOM - BEAM_DEPTH * 0.5
	for k in [-2.0, 0.0, 2.0]:
		var at: float = k
		_slab(Vector3(at, by, 0.0), Vector3(0.08, BEAM_DEPTH, 2.0 * POOL_HALF), steel)
		_slab(Vector3(0.0, by, at), Vector3(2.0 * POOL_HALF, BEAM_DEPTH, 0.08), steel)

	# The chamber under the glass, painted dark.
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.06, 0.06)
	dark.roughness = 0.9
	var ch := SLAB_BOTTOM - CHAMBER_FLOOR
	var cy := (SLAB_BOTTOM + CHAMBER_FLOOR) * 0.5
	var span := 2.0 * POOL_HALF
	_slab(Vector3(0.0, CHAMBER_FLOOR - 0.15, 0.0), Vector3(span + 0.6, 0.3, span + 0.6), dark)
	_slab(Vector3(POOL_HALF + 0.15, cy, 0.0), Vector3(0.3, ch, span), dark)
	_slab(Vector3(-POOL_HALF - 0.15, cy, 0.0), Vector3(0.3, ch, span), dark)
	_slab(Vector3(0.0, cy, POOL_HALF + 0.15), Vector3(span + 0.6, ch, 0.3), dark)
	_slab(Vector3(0.0, cy, -POOL_HALF - 0.15), Vector3(span + 0.6, ch, 0.3), dark)

	var water := PlaneMesh.new()
	water.size = Vector2(span, span)
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://world/pool_water.gdshader")
	_water_mat.set_shader_parameter("pool_half", POOL_HALF)
	var wi := MeshInstance3D.new()
	wi.mesh = water
	wi.material_override = _water_mat
	wi.position.y = WATER_Y
	wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(wi)


## Limestone tiles, laid in world space so the slabs' tiles line up.
func _stone() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/ambientcg_tiles142/albedo.png")
	m.normal_enabled = true
	m.normal_texture = load("res://textures/ambientcg_tiles142/normal.png")
	m.roughness_texture = load("res://textures/ambientcg_tiles142/roughness.png")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 2.0
	return m


## ---- the lamp --------------------------------------------------------------

func _build_lamp() -> void:
	var light := OmniLight3D.new()
	light.position = LAMP
	light.light_color = Color(1.0, 0.96, 0.9)
	light.light_energy = 60.0
	light.omni_range = 40.0
	light.omni_attenuation = 2.0
	light.shadow_enabled = true
	add_child(light)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1, 1, 1)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.96, 0.9)
	glow.emission_energy_multiplier = 40.0
	var bulb := SphereMesh.new()
	bulb.radius = 0.06
	bulb.height = 0.12
	bulb.material = glow
	var mi := MeshInstance3D.new()
	mi.mesh = bulb
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	light.add_child(mi)
