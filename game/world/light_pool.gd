class_name LightPool
extends Node3D
## A closed room ten metres every way, most of its floor a shallow pool
## whose bottom is one sheet of glass, lit by one bare lamp on a stand
## in a dark chamber under the room. Its only light comes up through
## the water, so the room is lit from below: the ceiling brightest, the
## walls fading downward, the deck around the pool in the room's own
## reflected light. A stair along the south wall goes down into the
## chamber.
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
const POOL_HALF := 3.75                # the pool is 7.5 m square
const POOL_CENTRE := Vector2(0.0, -0.5) # x, z: north of centre, leaving the south walk for the stair
const WATER_Y := -0.05                 # the deck is at 0
const GLASS_TOP := -0.35               # 30 cm of water
const GLASS_BOTTOM := -0.40
const LEDGE := 0.1                     # the glass rests this far on the slab all round
const SLAB_BOTTOM := -0.55             # the deck's underside, the chamber's ceiling
const CHAMBER_FLOOR := -3.2
const LAMP := Vector3(0.0, -2.4, -0.5) # 2 m under the glass's middle, 0.8 m over the chamber floor
const LAMP_COLOUR := Color(1.0, 0.96, 0.9)
const LAMP_ENERGY := 60.0
const BULB_GLOW := 40.0                # the glass's emission
const CHAMBER_ALBEDO := 0.12           # the chamber's paint, as its colour's channels (sRGB)
const WALL := 0.3
const START := Vector3(-2.5, 0.0, 4.3)
# The stair: 18 risers down the south wall, westward from x = STAIR_TOP.
const STAIR_TOP := 4.0
const STAIR_Z := 4.05                  # its north side; the room's wall is its south
const RISERS := 18
const GOING := 0.28                    # m, each tread front to back
const HOLE_WEST := -0.3                # the deck's opening ends here: 2 m headroom past it
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
	var rel := Vector2(feet.x, feet.z) - POOL_CENTRE
	var wading := absf(rel.x) < POOL_HALF and absf(rel.y) < POOL_HALF and feet.y < WATER_Y and feet.y > GLASS_BOTTOM - 0.2
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
		var uv := (Vector2(leg.x, leg.z) - POOL_CENTRE) / (2.0 * POOL_HALF) + Vector2(0.5, 0.5)
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
		mat.set_shader_parameter("pool_centre", POOL_CENTRE)
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
	var mi := _shape(centre, size, mat)
	_solid(centre, size, Basis.IDENTITY)
	return mi


## A box drawn only.
func _shape(centre: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	mi.position = centre
	add_child(mi)
	return mi


## A box solid only.
func _solid(centre: Vector3, size: Vector3, basis: Basis) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	body.transform = Transform3D(basis, centre)
	add_child(body)


## A slab between two corners.
func _slab_between(lo: Vector3, hi: Vector3, mat: Material) -> void:
	_slab((lo + hi) * 0.5, hi - lo, mat)


## ---- the pool --------------------------------------------------------------

## The deck is a slab round the pool in two layers: stone down to the
## glass, its inner faces the pool's sides, and concrete under it
## reaching LEDGE further in, on which the glass rests. The glass is one
## sheet, unsupported between its edges. The deck is open over the
## stair along the south wall.
func _build_pool() -> void:
	var stone := _stone()
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.30, 0.30, 0.29)
	concrete.roughness = 0.9
	_deck_layer(GLASS_BOTTOM, 0.0, 0.0, stone)
	_deck_layer(SLAB_BOTTOM, GLASS_BOTTOM, LEDGE, concrete)

	# The glass: solid to walk on, drawn by the water above it.
	var span := 2.0 * POOL_HALF
	_solid(Vector3(POOL_CENTRE.x, (GLASS_TOP + GLASS_BOTTOM) * 0.5, POOL_CENTRE.y),
		Vector3(span, GLASS_TOP - GLASS_BOTTOM, span), Basis.IDENTITY)

	# The chamber: the room's whole footprint under the deck, painted dark.
	var h := ROOM * 0.5
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(CHAMBER_ALBEDO, CHAMBER_ALBEDO, CHAMBER_ALBEDO)
	dark.roughness = 0.9
	_slab_between(Vector3(-h - WALL, CHAMBER_FLOOR - WALL, -h - WALL), Vector3(h + WALL, CHAMBER_FLOOR, h + WALL), dark)
	_slab_between(Vector3(h, CHAMBER_FLOOR, -h - WALL), Vector3(h + WALL, 0.0, h + WALL), dark)
	_slab_between(Vector3(-h - WALL, CHAMBER_FLOOR, -h - WALL), Vector3(-h, 0.0, h + WALL), dark)
	_slab_between(Vector3(-h, CHAMBER_FLOOR, h), Vector3(h, 0.0, h + WALL), dark)
	_slab_between(Vector3(-h, CHAMBER_FLOOR, -h - WALL), Vector3(h, 0.0, -h), dark)

	_build_stair(concrete)

	var water := PlaneMesh.new()
	water.size = Vector2(span, span)
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://world/pool_water.gdshader")
	_water_mat.set_shader_parameter("pool_half", POOL_HALF)
	_water_mat.set_shader_parameter("pool_centre", POOL_CENTRE)
	_water_mat.set_shader_parameter("lamp", LAMP)
	_water_mat.set_shader_parameter("lamp_light", _linear(LAMP_COLOUR) * LAMP_ENERGY)
	_water_mat.set_shader_parameter("bulb_glow", _linear(LAMP_COLOUR) * BULB_GLOW)
	_water_mat.set_shader_parameter("chamber_floor", CHAMBER_FLOOR)
	_water_mat.set_shader_parameter("chamber_half", ROOM * 0.5)
	_water_mat.set_shader_parameter("chamber_albedo", Color(CHAMBER_ALBEDO, 0, 0).srgb_to_linear().r)
	var wi := MeshInstance3D.new()
	wi.mesh = water
	wi.material_override = _water_mat
	wi.position = Vector3(POOL_CENTRE.x, WATER_Y, POOL_CENTRE.y)
	wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(wi)


## One layer of the deck from y0 to y1, round the pool shrunk by inset,
## and open over the stair.
func _deck_layer(y0: float, y1: float, inset: float, mat: Material) -> void:
	var h := ROOM * 0.5
	var x0 := POOL_CENTRE.x - POOL_HALF + inset
	var x1 := POOL_CENTRE.x + POOL_HALF - inset
	var z0 := POOL_CENTRE.y - POOL_HALF + inset
	var z1 := POOL_CENTRE.y + POOL_HALF - inset
	_slab_between(Vector3(-h, y0, -h), Vector3(x0, y1, z1), mat)
	_slab_between(Vector3(x1, y0, -h), Vector3(h, y1, z1), mat)
	_slab_between(Vector3(x0, y0, -h), Vector3(x1, y1, z0), mat)
	_slab_between(Vector3(-h, y0, z1), Vector3(h, y1, STAIR_Z), mat)
	_slab_between(Vector3(-h, y0, STAIR_Z), Vector3(HOLE_WEST, y1, h), mat)
	_slab_between(Vector3(STAIR_TOP, y0, STAIR_Z), Vector3(h, y1, h), mat)


## The stair down to the chamber: solid concrete steps against the south
## wall, a railing up their open side, and a railing round the opening
## above. The steps are drawn; what the
## player walks on is a ramp through their front edges, since a body
## that slides cannot climb a step.
func _build_stair(concrete: Material) -> void:
	var h := ROOM * 0.5
	var rise := -CHAMBER_FLOOR / RISERS
	var width := h - STAIR_Z
	for i in range(1, RISERS):
		var x1 := STAIR_TOP - (i - 1) * GOING
		var y1 := -i * rise
		_shape(Vector3(x1 - GOING * 0.5, (CHAMBER_FLOOR + y1) * 0.5, STAIR_Z + width * 0.5),
			Vector3(GOING, y1 - CHAMBER_FLOOR, width), concrete)
	var foot := STAIR_TOP - (RISERS - 1) * GOING
	var run := STAIR_TOP - foot
	var angle := atan2(-CHAMBER_FLOOR, run)
	var dir := Vector3(cos(angle), sin(angle), 0.0)
	var normal := Vector3(-sin(angle), cos(angle), 0.0)
	# From the deck's edge to 0.3 m past the foot, buried in the floor
	# there, so the walk off is smooth.
	var length := Vector2(run, -CHAMBER_FLOOR).length() + 0.3
	var mid := Vector3((STAIR_TOP + foot) * 0.5, CHAMBER_FLOOR * 0.5, STAIR_Z + width * 0.5) - dir * 0.15
	_solid(mid - normal * 0.1, Vector3(length, 0.2, width), Basis(Vector3.BACK, angle))
	var steel := _steel()
	_stair_rail(Vector3(STAIR_TOP, 0.0, STAIR_Z + 0.03), Vector3(foot, CHAMBER_FLOOR, STAIR_Z + 0.03), steel)
	_railing(Vector3(HOLE_WEST, 0.0, STAIR_Z - 0.03), Vector3(STAIR_TOP, 0.0, STAIR_Z - 0.03), steel)
	_railing(Vector3(HOLE_WEST - 0.03, 0.0, STAIR_Z), Vector3(HOLE_WEST - 0.03, 0.0, h), steel)


## A railing a metre high from a to b on the deck: posts no more than
## 1.2 m apart, a top rail and a middle rail, solid to its full height.
func _railing(a: Vector3, b: Vector3, mat: Material) -> void:
	var along := b - a
	var length := along.length()
	var across := along.x == 0.0
	var posts := int(ceil(length / 1.2)) + 1
	for i in posts:
		var p := a + along * (float(i) / (posts - 1))
		_shape(p + Vector3(0.0, 0.5, 0.0), Vector3(0.04, 1.0, 0.04), mat)
	for y: float in [0.5, 1.0]:
		var size := Vector3(0.04, 0.04, length) if across else Vector3(length, 0.04, 0.04)
		_shape((a + b) * 0.5 + Vector3(0.0, y, 0.0), size, mat)
	var wall := Vector3(0.05, 1.0, length) if across else Vector3(length, 1.0, 0.05)
	_solid((a + b) * 0.5 + Vector3(0.0, 0.5, 0.0), wall, Basis.IDENTITY)


## The railing up the stair's open side, from a at the top to b at the
## foot along the line of the steps' front edges: posts no more than
## 1.2 m apart, a handrail 0.9 m over that line, solid a metre up.
func _stair_rail(a: Vector3, b: Vector3, mat: Material) -> void:
	var along := a - b
	var length := along.length()
	var angle := atan2(along.y, along.x)
	var basis := Basis(Vector3.BACK, angle)
	var posts := int(ceil(length / 1.2)) + 1
	for i in posts:
		var p := b + along * (float(i) / (posts - 1))
		_shape(p + Vector3(0.0, 0.45, 0.0), Vector3(0.04, 0.9, 0.04), mat)
	var rail := _shape((a + b) * 0.5 + Vector3(0.0, 0.9, 0.0), Vector3(length, 0.04, 0.04), mat)
	rail.basis = basis
	_solid((a + b) * 0.5 + Vector3(0.0, 0.5, 0.0), Vector3(length, 1.0, 0.05), basis)


## A colour as stored (sRGB) in the linear values a shader works in.
func _linear(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)


func _steel() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.18, 0.18, 0.19)
	m.metallic = 0.7
	m.roughness = 0.4
	return m


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

## The lamp: a bare bulb on a slim steel stand from the chamber floor.
func _build_lamp() -> void:
	var steel := _steel()
	var stem_h := LAMP.y - 0.06 - CHAMBER_FLOOR
	var stem := CylinderMesh.new()
	stem.top_radius = 0.012
	stem.bottom_radius = 0.012
	stem.height = stem_h
	var base := CylinderMesh.new()
	base.top_radius = 0.14
	base.bottom_radius = 0.15
	base.height = 0.02
	for part: Array in [[stem, CHAMBER_FLOOR + stem_h * 0.5], [base, CHAMBER_FLOOR + 0.01]]:
		var mesh: CylinderMesh = part[0]
		mesh.material = steel
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = Vector3(LAMP.x, part[1], LAMP.z)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_solid(Vector3(LAMP.x, CHAMBER_FLOOR + 0.5, LAMP.z), Vector3(0.3, 1.0, 0.3), Basis.IDENTITY)
	var light := OmniLight3D.new()
	light.position = LAMP
	light.light_color = LAMP_COLOUR
	light.light_energy = LAMP_ENERGY
	light.omni_range = 40.0
	light.omni_attenuation = 2.0
	light.shadow_enabled = true
	add_child(light)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1, 1, 1)
	glow.emission_enabled = true
	glow.emission = LAMP_COLOUR
	glow.emission_energy_multiplier = BULB_GLOW
	var bulb := SphereMesh.new()
	bulb.radius = 0.06
	bulb.height = 0.12
	bulb.material = glow
	var mi := MeshInstance3D.new()
	mi.mesh = bulb
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	light.add_child(mi)
