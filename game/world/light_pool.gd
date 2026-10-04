class_name LightPool
extends Node3D
## A closed room ten metres every way. Most of its floor is an opening
## 7.5 m square onto a dark chamber under the whole room, lit by one bare
## lamp on a stand. The lamp is the only light, so the room is lit from
## below through the opening: the ceiling brightest, the walls fading
## downward, the deck around the opening in the room's own reflected
## light. A stair along the south wall goes down into the chamber;
## stepping off the deck into the opening drops the player into it.
##
## Everything is drawn by the engine's own lighting: an omni light with
## shadows, standard materials, and a VoxelGI box around the room and the
## chamber for the bounce light, baked on arrival and traced at half the
## screen's resolution and low quality (both engine-wide, put back when
## the scene closes).

const ROOM := 10.0                     # inside, every way
const OPENING_HALF := 3.75             # the opening is 7.5 m square
const OPENING_CENTRE := Vector2(0.0, -0.5) # x, z: north of centre, leaving the south walk for the stair
const SLAB_BOTTOM := -0.55             # the deck's underside, the chamber's ceiling
const TILE := 0.04                     # the stone facing on the deck
const CHAMBER_FLOOR := -3.2
const LAMP := Vector3(0.0, -2.4, -0.5) # under the opening's middle, 0.8 m over the chamber floor
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
const HOLE_WEST := -0.3                # the deck's stair opening ends here: 2 m headroom past it

@onready var player: Player = $Player

var _atlas_was: Array = []              # the shadow atlas's size and first quadrant, as found


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
	_build_room()
	_build_deck()
	_build_lamp()
	RenderingServer.gi_set_use_half_resolution(true)
	RenderingServer.voxel_gi_set_quality(RenderingServer.VOXEL_GI_QUALITY_LOW)
	var gi := VoxelGI.new()
	gi.subdiv = VoxelGI.SUBDIV_64
	gi.size = Vector3(ROOM + 1.0, ROOM - CHAMBER_FLOOR + 1.0, ROOM + 1.0)
	gi.position.y = (ROOM + CHAMBER_FLOOR) * 0.5
	add_child(gi)
	gi.bake()
	MouseMode.capture()


func _exit_tree() -> void:
	var vp := get_viewport()
	vp.positional_shadow_atlas_size = _atlas_was[0]
	vp.set_positional_shadow_atlas_quadrant_subdiv(0, _atlas_was[1])
	RenderingServer.gi_set_use_half_resolution(ProjectSettings.get_setting("rendering/global_illumination/gi/use_half_resolution", false))
	RenderingServer.voxel_gi_set_quality(ProjectSettings.get_setting("rendering/global_illumination/voxel_gi/quality", 0))


## ---- the room --------------------------------------------------------------

## The ceiling and four walls in matte plaster, and the chamber under the
## whole room, its walls continuing the room's down to its floor, painted
## dark.
func _build_room() -> void:
	var h := ROOM * 0.5
	var plaster := StandardMaterial3D.new()
	plaster.albedo_color = Color(0.80, 0.78, 0.74)
	plaster.roughness = 0.9
	_slab_between(Vector3(-h - WALL, ROOM, -h - WALL), Vector3(h + WALL, ROOM + WALL, h + WALL), plaster)
	_slab_between(Vector3(h, 0.0, -h), Vector3(h + WALL, ROOM, h), plaster)
	_slab_between(Vector3(-h - WALL, 0.0, -h), Vector3(-h, ROOM, h), plaster)
	_slab_between(Vector3(-h - WALL, 0.0, h), Vector3(h + WALL, ROOM, h + WALL), plaster)
	_slab_between(Vector3(-h - WALL, 0.0, -h - WALL), Vector3(h + WALL, ROOM, -h), plaster)

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(CHAMBER_ALBEDO, CHAMBER_ALBEDO, CHAMBER_ALBEDO)
	dark.roughness = 0.9
	_slab_between(Vector3(-h - WALL, CHAMBER_FLOOR - WALL, -h - WALL), Vector3(h + WALL, CHAMBER_FLOOR, h + WALL), dark)
	_slab_between(Vector3(h, CHAMBER_FLOOR, -h - WALL), Vector3(h + WALL, 0.0, h + WALL), dark)
	_slab_between(Vector3(-h - WALL, CHAMBER_FLOOR, -h - WALL), Vector3(-h, 0.0, h + WALL), dark)
	_slab_between(Vector3(-h, CHAMBER_FLOOR, h), Vector3(h, 0.0, h + WALL), dark)
	_slab_between(Vector3(-h, CHAMBER_FLOOR, -h - WALL), Vector3(h, 0.0, -h), dark)


## ---- the deck --------------------------------------------------------------

## The deck is a concrete slab faced with stone tiles, round the opening
## and open also over the stair along the south wall.
func _build_deck() -> void:
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.30, 0.30, 0.29)
	concrete.roughness = 0.9
	_deck_layer(-TILE, 0.0, _stone())
	_deck_layer(SLAB_BOTTOM, -TILE, concrete)
	_build_stair(concrete)


## One layer of the deck, from y0 to y1.
func _deck_layer(y0: float, y1: float, mat: Material) -> void:
	var h := ROOM * 0.5
	var x0 := OPENING_CENTRE.x - OPENING_HALF
	var x1 := OPENING_CENTRE.x + OPENING_HALF
	var z0 := OPENING_CENTRE.y - OPENING_HALF
	var z1 := OPENING_CENTRE.y + OPENING_HALF
	_slab_between(Vector3(-h, y0, -h), Vector3(x0, y1, z1), mat)
	_slab_between(Vector3(x1, y0, -h), Vector3(h, y1, z1), mat)
	_slab_between(Vector3(x0, y0, -h), Vector3(x1, y1, z0), mat)
	_slab_between(Vector3(-h, y0, z1), Vector3(h, y1, STAIR_Z), mat)
	_slab_between(Vector3(-h, y0, STAIR_Z), Vector3(HOLE_WEST, y1, h), mat)
	_slab_between(Vector3(STAIR_TOP, y0, STAIR_Z), Vector3(h, y1, h), mat)


## The stair down to the chamber: solid concrete steps against the south
## wall, a railing up their open side, and a railing round the opening
## above. The steps are drawn; what the player walks on is a ramp through
## their front edges, since a body that slides cannot climb a step.
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


## ---- boxes -----------------------------------------------------------------

## A box drawn and solid.
func _slab(centre: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := _shape(centre, size, mat)
	_solid(centre, size, Basis.IDENTITY)
	return mi


## A slab between two corners.
func _slab_between(lo: Vector3, hi: Vector3, mat: Material) -> void:
	_slab((lo + hi) * 0.5, hi - lo, mat)


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
