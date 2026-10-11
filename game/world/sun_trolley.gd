class_name SunTrolley
extends Node3D
## A sunstone running round a ring, as an edge-runner mill's stone runs
## round its post: a post in the middle with a bearing at its top that
## turns freely about the upright; from it an axle runs out level to one
## spoked brass wheel on a ring-shaped rail; on the axle, drilled from end
## to end, a pure sunstone, its seeking end outward. The axle turns in the
## bearing about its own length too, so the stone, the axle and the wheel
## turn together.
##
## The bearing and the rail hold the axle level and pointing out, so the
## stone's pull toward the sun only presses on them; its spin about its
## length (Photogyrite, by its purity, as much as its seeking end faces
## the sun) turns the axle, the wheel rolls along the rail, and the arm
## sweeps round the post. Since its seeking end turns with it, the stone
## drives while it faces the sun's side and none on the far side, where
## it coasts. Worked as one turning: the axle's spin against its own
## inertia and the arm's sweep (the wheel, stone and axle swept round the
## post, at the wheel's rolling as many times slower as the ring is
## larger than the wheel), less the wheel's rolling resistance (ROLLING,
## of the share of the weight the wheel carries; the post carries the
## rest) and the bearings' slight drag. It rolls with a metallic scrape
## (metal_scrape_loop.wav: the shed's scrape recording ringing as a steel
## rail, made by tools/cut_scrape.py), louder and quicker as it runs
## faster. A lever by the ring sets it still. Inert at night and in an
## eclipse's shadow.

const RADIUS := 2.0                     # m: from the post to the wheel's middle, on the rail
const WHEEL_R := 0.25                   # m
const HUB_UP := 0.12 + WHEEL_R          # m: the axle's height over the ground
const STONE_AT := 1.0                   # m: the stone's middle, out from the post
const STONE_SIZE := 0.6                 # the stone's length, as a share of a whole stone's
const WHEEL_MASS := 2.5                 # kg
const AXLE_MASS := 1.5                  # kg
const ROLLING := 0.003                  # the wheel's rolling resistance, a share of the load on it
const BEARING := 0.002                  # N m s: the bearings

## Toward the sun and its direct light, W/m², set by the world.
var to_sun := Vector3.UP
var sunlight := 0.0
var purity := 1.0

var _arm: Node3D                        # sweeping round the post
var _turning: Node3D                    # the axle, stone and wheel, turning about the axle
var _round := PI * 0.5                  # rad: the arm round the post (from east toward south); it begins pointing south, at the noon sun
var _spin := 0.0                        # rad/s: the axle, about its outward length
var _angle := 0.0
var _area := 0.0
var _inertia := 0.0                     # kg m²: as felt at the axle's spin
var _load := 0.0                        # N: the weight on the wheel
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
	var rolling := ROLLING * _load * WHEEL_R
	var twist := drive - signf(_spin) * (rolling + BEARING * absf(_spin))
	if absf(_spin) < 0.02 and absf(drive) <= rolling:
		twist = 0.0
		_spin = 0.0
	_spin += twist / _inertia * delta
	# Spin about its outward length rolls the wheel round toward greater
	# angle.
	_round = fposmod(_round + _spin * WHEEL_R / RADIUS * delta, TAU)
	_angle = fposmod(_angle + _spin * delta, TAU)
	_place()
	var speed := absf(_spin) * WHEEL_R
	_scrape.volume_db = linear_to_db(maxf(clampf(speed / 1.2, 0.0, 1.0) * 0.8, 0.0001)) - 28.0
	_scrape.pitch_scale = clampf(0.85 + speed * 0.3, 0.85, 1.3)


## The arm where it is round the post: the axle (+z of its frame)
## pointing out.
func _place() -> void:
	_arm.rotation.y = PI * 0.5 - _round
	_turning.rotation.z = _angle


## ---- building ----------------------------------------------------------------

func _build(world: Node) -> void:
	var wood_mat: StandardMaterial3D = world.call("material", true, false)
	var ground := CozyMesh.new()
	# Sleepers across the ring and one rail round it; the post.
	var n := 32
	for k in n:
		var a := TAU * k / n
		var out_dir := Vector3(cos(a), 0, sin(a))
		ground.box(Vector3(0.12, 0.06, 0.4), CozyMesh.at(out_dir * RADIUS + Vector3(0, 0.03, 0), Basis(Vector3.UP, PI * 0.5 - a)), Color(0.42, 0.3, 0.2))
	ground.torus(RADIUS - 0.025, RADIUS + 0.025, 96, 6, CozyMesh.at(Vector3(0, 0.095, 0)), Color(0.32, 0.32, 0.34))
	ground.cyl(0.07, 0.09, HUB_UP - 0.05, 12, CozyMesh.at(Vector3(0, (HUB_UP - 0.05) * 0.5, 0)), Color(0.5, 0.36, 0.24))
	ground.cyl(0.2, 0.25, 0.08, 16, CozyMesh.at(Vector3(0, 0.04, 0)), Color(0.45, 0.33, 0.22))
	var ground_view := MeshInstance3D.new()
	ground_view.mesh = ground.commit(wood_mat)
	add_child(ground_view)
	var brass := Color(0.82, 0.62, 0.3)
	var metal_mat := StandardMaterial3D.new()
	metal_mat.vertex_color_use_as_albedo = true
	metal_mat.metallic = 0.8
	metal_mat.roughness = 0.3
	# The arm: the bearing atop the post, sweeping round it.
	_arm = Node3D.new()
	_arm.position = Vector3(0, HUB_UP, 0)
	add_child(_arm)
	var hub := CozyMesh.new()
	hub.cyl(0.09, 0.09, 0.1, 16, CozyMesh.at(Vector3(0, 0, 0)), brass)
	var hub_view := MeshInstance3D.new()
	hub_view.mesh = hub.commit(metal_mat)
	_arm.add_child(hub_view)
	# The axle, stone and wheel, turning about the axle (+z, outward).
	_turning = Node3D.new()
	_arm.add_child(_turning)
	var metal := CozyMesh.new()
	metal.rod(Vector3(0, 0, 0.05), Vector3(0, 0, RADIUS + 0.06), 0.015, 10, brass)
	metal.torus(WHEEL_R - 0.03, WHEEL_R, 40, 8, CozyMesh.at(Vector3(0, 0, RADIUS), Basis(Vector3.RIGHT, PI * 0.5)), brass)
	metal.cyl(0.045, 0.045, 0.06, 14, CozyMesh.at(Vector3(0, 0, RADIUS), Basis(Vector3.RIGHT, PI * 0.5)), brass)
	for k in 8:
		var a := TAU * k / 8.0
		metal.rod(Vector3(0, 0, RADIUS), Vector3(cos(a), sin(a), 0) * (WHEEL_R - 0.025) + Vector3(0, 0, RADIUS), 0.008, 6, brass)
	var metal_view := MeshInstance3D.new()
	metal_view.mesh = metal.commit(metal_mat)
	_turning.add_child(metal_view)
	# The stone on the axle, its length along it, seeking end outward.
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
	var box := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		box = box.expand(v)
	# As felt at the axle's spin: the wheel (a rim), the stone and axle
	# about their length; and their sweep round the post, by the square
	# of the wheel's radius over the ring's.
	var spin_inertia := WHEEL_MASS * WHEEL_R * WHEEL_R + stone_mass * (box.size.x * box.size.x + box.size.z * box.size.z) / 12.0
	var sweep_inertia := WHEEL_MASS * RADIUS * RADIUS + stone_mass * STONE_AT * STONE_AT + AXLE_MASS * RADIUS * RADIUS / 3.0
	_inertia = spin_inertia + sweep_inertia * pow(WHEEL_R / RADIUS, 2.0)
	# The wheel carries the arm's weight by its lever about the post.
	_load = 9.8 * (WHEEL_MASS * RADIUS + stone_mass * STONE_AT + AXLE_MASS * RADIUS * 0.5) / RADIUS
	var stone_arrays := arrays.duplicate()
	stone_arrays[Mesh.ARRAY_VERTEX] = verts
	var stone_mesh := ArrayMesh.new()
	stone_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, stone_arrays)
	stone_mesh.surface_set_material(0, glow)
	var stone := MeshInstance3D.new()
	stone.mesh = stone_mesh
	stone.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, STONE_AT))
	_turning.add_child(stone)
	# Its sound: the metallic scrape, at the wheel, by its speed.
	_scrape = AudioStreamPlayer3D.new()
	_scrape.unit_size = 4.0
	_scrape.volume_db = -80.0
	_scrape.position = Vector3(0, -WHEEL_R, RADIUS)
	_arm.add_child(_scrape)
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
	var lever_at := Vector3(RADIUS + 0.9, 0.55, -1.0)
	var lever := WorksHandle.new(WorksHandle.Kind.LEVER, lever_at, wood, dark,
			"Set it still\nA click stops the wheel where it is.")
	lever.thrown.connect(func(_on: bool) -> void: set_still())
	add_child(lever)
	var stand := CozyMesh.new()
	stand.box(Vector3(0.4, 0.08, 0.4), CozyMesh.at(Vector3(lever_at.x, 0.04, lever_at.z)), Color(0.5, 0.36, 0.24))
	var stand_view := MeshInstance3D.new()
	stand_view.mesh = stand.commit(wood_mat)
	add_child(stand_view)
	add_child(HoverNote.new(Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5),
			"A sunstone running round\nA pure sunstone drilled from end to end on an axle from a turning post out to one wheel on a ring of rail, its seeking end outward. Where it faces the sun the stone spins and rolls the wheel round; on the far side it coasts."))
