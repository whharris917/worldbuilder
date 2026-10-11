class_name SunTrolley
extends Node3D
## A short track on the lawn and on it a wheelset: two spoked brass
## wheels on an axle that runs through a pure sunstone along its length
## (the stone drilled from end to end), its seeking end to the south.
## The track runs east and west; the axle lies square across it, north
## and south.
##
## The rails hold the axle level and square, so the stone's pull toward
## the sun only presses on them; its spin about its length (Photogyrite,
## by its purity, as much as its seeking end faces the sun) turns the
## axle, the wheels roll, and the wheelset runs along the track. Worked
## as one turning: the axle's spin against the whole wheelset's mass at
## the wheels' rim and its own inertia, less the wheels' rolling
## resistance (ROLLING) and the bearings' slight drag; the stone turns
## with the wheels. A buffer at each end stops it with a knock
## (cart_buffer.wav, the cozy island's cart's); it rolls with the cart's
## rumble (cart_roll_loop.wav), louder as it runs faster. A lever by the
## track sets it back at the east end, still. Inert at night and in an
## eclipse's shadow.

const LENGTH := 8.0                     # m: the track, buffer to buffer
const GAUGE := 0.6                      # m: between the rails
const WHEEL_R := 0.18                   # m
const STONE_SIZE := 0.6                 # the stone's length, as a share of a whole stone's
const WHEEL_MASS := 1.6                 # kg each
const ROLLING := 0.003                  # the wheels' rolling resistance, a share of the weight
const BEARING := 0.002                  # N m s: the axle's bearings
const BUFFER_GIVE := 0.3                # the share of its speed it keeps, rebounding

## Toward the sun and its direct light, W/m², set by the world.
var to_sun := Vector3.UP
var sunlight := 0.0
var purity := 1.0

var _set: Node3D                        # the wheelset, moving along the track
var _turning: Node3D                    # its wheels, axle and stone, turning
var _at := 0.0                          # m: the wheelset along the track, +x east
var _spin := 0.0                        # rad/s: the axle, about +z (south)
var _angle := 0.0
var _area := 0.0
var _mass := 0.0
var _axle_inertia := 0.0
var _roll: AudioStreamPlayer3D
var _knock: AudioStreamPlayer3D


func _init(world: Node) -> void:
	name = "SunTrolley"
	_build(world)


func _ready() -> void:
	_back_to_start()


func _back_to_start() -> void:
	_at = LENGTH * 0.5 - 0.5
	_spin = 0.0


func _physics_process(delta: float) -> void:
	var watts := sunlight * _area if to_sun.y > 0.0 else 0.0
	var axis := Vector3.BACK                # the stone's seeking end, south
	var drive := Photogyrite.spin(watts, maxf(axis.dot(to_sun), 0.0), _spin, purity)
	# Rolling on its wheels: positive spin about the south axis rolls it
	# west (-x).
	var held := ROLLING * _mass * 9.8 * WHEEL_R + BEARING * absf(_spin)
	var twist := drive - signf(_spin) * held
	if absf(_spin) < 0.02 and absf(drive) <= ROLLING * _mass * 9.8 * WHEEL_R:
		twist = 0.0
		_spin = 0.0
	_spin += twist / (_axle_inertia + _mass * WHEEL_R * WHEEL_R) * delta
	_at -= _spin * WHEEL_R * delta
	var end := LENGTH * 0.5 - 0.45
	if absf(_at) > end:
		var speed := absf(_spin) * WHEEL_R
		_at = signf(_at) * end
		_spin = -_spin * BUFFER_GIVE
		if speed > 0.05 and _knock.stream != null:
			_knock.global_position = _set.global_position
			_knock.volume_db = linear_to_db(clampf(speed / 1.5, 0.05, 1.0)) - 4.0
			_knock.play()
	_angle = fposmod(_angle + _spin * delta, TAU)
	_set.position.x = _at
	_turning.rotation.z = _angle
	_roll.volume_db = linear_to_db(maxf(clampf(absf(_spin) * WHEEL_R / 1.5, 0.0, 1.0) * 0.7, 0.0001)) - 8.0
	_roll.pitch_scale = clampf(0.7 + absf(_spin) * WHEEL_R * 0.4, 0.7, 1.5)


## ---- building ----------------------------------------------------------------

func _build(world: Node) -> void:
	var wood_mat: StandardMaterial3D = world.call("material", true, false)
	var ground := CozyMesh.new()
	var rail_y := 0.12
	# Sleepers and rails, buffers at the ends.
	var n := int(LENGTH / 0.5)
	for k in n + 1:
		var x := -LENGTH * 0.5 + LENGTH * k / n
		ground.box(Vector3(0.14, 0.06, GAUGE + 0.4), CozyMesh.at(Vector3(x, 0.03, 0)), Color(0.42, 0.3, 0.2))
	for side: float in [-1.0, 1.0]:
		ground.box(Vector3(LENGTH, 0.06, 0.04), CozyMesh.at(Vector3(0, 0.09, side * GAUGE * 0.5)), Color(0.32, 0.32, 0.34))
	for end: float in [-1.0, 1.0]:
		ground.box(Vector3(0.12, 0.3, GAUGE + 0.3), CozyMesh.at(Vector3(end * (LENGTH * 0.5 - 0.1), 0.15, 0)), Color(0.5, 0.36, 0.24))
		ground.box(Vector3(0.06, 0.12, GAUGE * 0.6), CozyMesh.at(Vector3(end * (LENGTH * 0.5 - 0.19), rail_y + WHEEL_R, 0)), Color(0.25, 0.25, 0.27))
	var ground_view := MeshInstance3D.new()
	ground_view.mesh = ground.commit(wood_mat)
	add_child(ground_view)
	# The wheelset: its middle at the axle, over the rails.
	_set = Node3D.new()
	_set.position = Vector3(0, rail_y + WHEEL_R, 0)
	add_child(_set)
	_turning = Node3D.new()
	_set.add_child(_turning)
	var brass := Color(0.82, 0.62, 0.3)
	var metal := CozyMesh.new()
	metal.rod(Vector3(0, 0, -GAUGE * 0.5 - 0.06), Vector3(0, 0, GAUGE * 0.5 + 0.06), 0.012, 10, brass)
	for side: float in [-1.0, 1.0]:
		var z := side * GAUGE * 0.5
		metal.torus(WHEEL_R - 0.025, WHEEL_R, 32, 8, CozyMesh.at(Vector3(0, 0, z), Basis(Vector3.RIGHT, PI * 0.5)), brass)
		metal.cyl(0.035, 0.035, 0.05, 12, CozyMesh.at(Vector3(0, 0, z), Basis(Vector3.RIGHT, PI * 0.5)), brass)
		for k in 6:
			var a := TAU * k / 6.0
			metal.rod(Vector3(0, 0, z), Vector3(cos(a), sin(a), 0) * (WHEEL_R - 0.02) + Vector3(0, 0, z), 0.007, 6, brass)
		# The flange inside the rail.
		metal.torus(WHEEL_R - 0.01, WHEEL_R + 0.018, 32, 6, CozyMesh.at(Vector3(0, 0, z - side * 0.03), Basis(Vector3.RIGHT, PI * 0.5)), brass.darkened(0.15))
	var metal_mat := StandardMaterial3D.new()
	metal_mat.vertex_color_use_as_albedo = true
	metal_mat.metallic = 0.8
	metal_mat.roughness = 0.3
	var metal_view := MeshInstance3D.new()
	metal_view.mesh = metal.commit(metal_mat)
	_turning.add_child(metal_view)
	# The stone, its length along the axle, seeking end south (+z).
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.8, 0.45, 0.6)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.roughness = 0.08
	glow.metallic_specular = 0.9
	glow.emission_enabled = true
	glow.emission = Color(0.85, 0.5, 0.15)
	glow.emission_energy_multiplier = 0.6
	var grow := RandomNumberGenerator.new()
	grow.seed = 2718
	var cm := CozyMesh.new()
	LumenPart.grow_spinstone(cm, grow)
	var arrays := cm.commit(glow).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var scale_by := ShedCrystal.WHOLE * STONE_SIZE
	for k in verts.size():
		verts[k] *= scale_by
	var volume := 0.0
	var middle := Vector3.ZERO
	var surface := 0.0
	for k in range(0, index.size(), 3):
		var a := verts[index[k]]
		var b := verts[index[k + 1]]
		var c := verts[index[k + 2]]
		var v := a.dot(b.cross(c)) / 6.0
		volume += v
		middle += (a + b + c) * 0.25 * v
		surface += (b - a).cross(c - a).length() * 0.5
	middle /= volume
	volume = absf(volume)
	for k in verts.size():
		verts[k] -= middle
	_area = surface * 0.25
	var stone_mass := volume * ShedCrystal.DENSITY
	_mass = stone_mass + WHEEL_MASS * 2.0
	# About the axle: the wheels as rims, the stone as the box round it.
	var box := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		box = box.expand(v)
	_axle_inertia = WHEEL_MASS * 2.0 * WHEEL_R * WHEEL_R + stone_mass * (box.size.x * box.size.x + box.size.z * box.size.z) / 12.0
	var stone_arrays := arrays.duplicate()
	stone_arrays[Mesh.ARRAY_VERTEX] = verts
	var stone_mesh := ArrayMesh.new()
	stone_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, stone_arrays)
	stone_mesh.surface_set_material(0, glow)
	var stone := MeshInstance3D.new()
	stone.mesh = stone_mesh
	stone.basis = Basis(Vector3.RIGHT, PI * 0.5)
	_turning.add_child(stone)
	# Its sounds.
	_roll = AudioStreamPlayer3D.new()
	_roll.unit_size = 4.0
	_roll.volume_db = -80.0
	_set.add_child(_roll)
	_knock = AudioStreamPlayer3D.new()
	_knock.unit_size = 5.0
	add_child(_knock)
	if DisplayServer.get_name() != "headless":
		var loop := (load("res://audio/cart_roll_loop.wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = int(loop.get_length() * loop.mix_rate)
		_roll.stream = loop
		_roll.autoplay = true
		_knock.stream = load("res://audio/cart_buffer.wav")
	# A lever by the east end; what a player inspecting reads (drafts).
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.4, 0.27)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.22, 0.22, 0.22)
	var lever := WorksHandle.new(WorksHandle.Kind.LEVER, Vector3(LENGTH * 0.5 + 0.6, 0.55, 0.9), wood, dark,
			"Back to the start\nA click sets the wheelset at the east end of the track, still.")
	lever.thrown.connect(func(_on: bool) -> void: _back_to_start())
	add_child(lever)
	var stand := CozyMesh.new()
	stand.box(Vector3(0.4, 0.08, 0.4), CozyMesh.at(Vector3(LENGTH * 0.5 + 0.6, 0.04, 0.9)), Color(0.5, 0.36, 0.24))
	var stand_view := MeshInstance3D.new()
	stand_view.mesh = stand.commit(wood_mat)
	add_child(stand_view)
	add_child(HoverNote.new(Vector3(0, 0.15, 0), Vector3(LENGTH, 0.3, GAUGE + 0.4),
			"A sunstone on wheels\nA pure sunstone drilled from end to end on the axle of two wheels, set on a short track, its seeking end to the south. The sun spins the stone, the stone turns the wheels."))
