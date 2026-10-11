class_name SunTrolley
extends Node3D
## A ring of track on the lawn and on it a wheelset: two spoked brass
## wheels on an axle that runs through a pure sunstone along its length
## (the stone drilled from end to end), the axle pointing out from the
## ring's middle, the stone's seeking end outward.
##
## The rails hold the axle level and pointing out, so the stone's pull
## toward the sun only presses on them; its spin about its length
## (Photogyrite, by its purity, as much as its seeking end faces the
## sun) turns the axle, the wheels roll, and the wheelset runs round.
## Since its seeking end turns with it round the ring, the stone drives
## while it faces the sun's side and none on the far side, where it
## coasts: it surges and slows once round. Worked as one turning: the
## axle's spin against the whole wheelset's mass at the wheels' rim and
## its own inertia, less the wheels' rolling resistance (ROLLING) and the
## bearings' slight drag; the stone turns with the wheels; the wheels
## run at the ring's middle radius (a real wheelset's coned treads take
## up the inner and outer rails' difference). It rolls with a scrape of
## metal (metal_scrape_loop.wav: the shed's scrape recording with a
## steel rail's faint ring, made by tools/cut_scrape.py), louder and
## quicker as it runs faster. A lever by the ring sets it still. Inert
## at night and in an eclipse's shadow.

const RADIUS := 3.0                     # m: the ring, to the middle between the rails
const GAUGE := 0.6                      # m: between the rails
const WHEEL_R := 0.18                   # m
const STONE_SIZE := 0.6                 # the stone's length, as a share of a whole stone's
const WHEEL_MASS := 1.6                 # kg each
const ROLLING := 0.003                  # the wheels' rolling resistance, a share of the weight
const BEARING := 0.002                  # N m s: the axle's bearings

## Toward the sun and its direct light, W/m², set by the world.
var to_sun := Vector3.UP
var sunlight := 0.0
var purity := 1.0

var _set: Node3D                        # the wheelset, going round the ring
var _turning: Node3D                    # its wheels, axle and stone, turning
var _round := PI * 0.5                  # rad: where it is round the ring (from east toward south); it begins on the south side, facing the noon sun
var _spin := 0.0                        # rad/s: the axle, about its outward length
var _angle := 0.0
var _area := 0.0
var _mass := 0.0
var _axle_inertia := 0.0
var _scrape: AudioStreamPlayer3D


func _init(world: Node) -> void:
	name = "SunTrolley"
	_build(world)


func _ready() -> void:
	_place()


## Still where it is.
func set_still() -> void:
	_spin = 0.0


func _physics_process(delta: float) -> void:
	var watts := sunlight * _area if to_sun.y > 0.0 else 0.0
	var outward := Vector3(cos(_round), 0.0, sin(_round))
	var drive := Photogyrite.spin(watts, maxf(outward.dot(to_sun), 0.0), _spin, purity)
	var held := ROLLING * _mass * 9.8 * WHEEL_R + BEARING * absf(_spin)
	var twist := drive - signf(_spin) * held
	if absf(_spin) < 0.02 and absf(drive) <= ROLLING * _mass * 9.8 * WHEEL_R:
		twist = 0.0
		_spin = 0.0
	_spin += twist / (_axle_inertia + _mass * WHEEL_R * WHEEL_R) * delta
	# Spin about its outward length rolls it round toward greater angle.
	_round = fposmod(_round + _spin * WHEEL_R / RADIUS * delta, TAU)
	_angle = fposmod(_angle + _spin * delta, TAU)
	_place()
	var speed := absf(_spin) * WHEEL_R
	_scrape.volume_db = linear_to_db(maxf(clampf(speed / 1.2, 0.0, 1.0) * 0.8, 0.0001)) - 12.0
	_scrape.pitch_scale = clampf(0.8 + speed * 0.35, 0.8, 1.4)


## The wheelset where it is round the ring: its axle (+z of its frame)
## pointing out from the middle.
func _place() -> void:
	_set.position = Vector3(cos(_round) * RADIUS, _set.position.y, sin(_round) * RADIUS)
	_set.rotation.y = PI * 0.5 - _round
	_turning.rotation.z = _angle


## ---- building ----------------------------------------------------------------

func _build(world: Node) -> void:
	var wood_mat: StandardMaterial3D = world.call("material", true, false)
	var ground := CozyMesh.new()
	var rail_y := 0.12
	# Sleepers across the ring, two rails round it, a hub at the middle.
	var n := 40
	for k in n:
		var a := TAU * k / n
		var out_dir := Vector3(cos(a), 0, sin(a))
		ground.box(Vector3(0.14, 0.06, GAUGE + 0.4), CozyMesh.at(out_dir * RADIUS + Vector3(0, 0.03, 0), Basis(Vector3.UP, PI * 0.5 - a)), Color(0.42, 0.3, 0.2))
	for side: float in [-1.0, 1.0]:
		var r := RADIUS + side * GAUGE * 0.5
		ground.torus(r - 0.02, r + 0.02, 96, 6, CozyMesh.at(Vector3(0, 0.1, 0)), Color(0.32, 0.32, 0.34))
	ground.cyl(0.25, 0.3, 0.3, 16, CozyMesh.at(Vector3(0, 0.15, 0)), Color(0.5, 0.36, 0.24))
	var ground_view := MeshInstance3D.new()
	ground_view.mesh = ground.commit(wood_mat)
	add_child(ground_view)
	# The wheelset: its middle at the axle, over the rails.
	_set = Node3D.new()
	_set.position = Vector3(RADIUS, rail_y + WHEEL_R, 0)
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
	# Its sound: the metallic scrape, by its speed.
	_scrape = AudioStreamPlayer3D.new()
	_scrape.unit_size = 4.0
	_scrape.volume_db = -80.0
	_set.add_child(_scrape)
	if DisplayServer.get_name() != "headless":
		var loop := load("res://audio/metal_scrape_loop.wav") as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = int(loop.get_length() * loop.mix_rate)
		_scrape.stream = loop
		_scrape.autoplay = true
	# A lever beside the ring; what a player inspecting reads (drafts).
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.4, 0.27)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.22, 0.22, 0.22)
	var lever_at := Vector3(RADIUS + GAUGE + 0.7, 0.55, -1.0)
	var lever := WorksHandle.new(WorksHandle.Kind.LEVER, lever_at, wood, dark,
			"Set it still\nA click stops the wheelset where it is.")
	lever.thrown.connect(func(_on: bool) -> void: set_still())
	add_child(lever)
	var stand := CozyMesh.new()
	stand.box(Vector3(0.4, 0.08, 0.4), CozyMesh.at(Vector3(lever_at.x, 0.04, lever_at.z)), Color(0.5, 0.36, 0.24))
	var stand_view := MeshInstance3D.new()
	stand_view.mesh = stand.commit(wood_mat)
	add_child(stand_view)
	add_child(HoverNote.new(Vector3(0, 0.15, 0), Vector3(0.6, 0.3, 0.6),
			"A sunstone on wheels\nA pure sunstone drilled from end to end on the axle of two wheels, on a ring of track, its seeking end outward. Where it faces the sun the stone spins and drives the wheels; round the far side it coasts."))
