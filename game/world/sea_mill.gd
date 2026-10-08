class_name SeaMill
extends Node3D
## A windmill far out at sea on a platform on piles, sending its power to
## the lagoon wharf's collector as a beam of light.
##
## Wind over open water blows harder the farther from land (less
## friction from the ground, a longer reach of open water to build over),
## so a mill farther out turns faster; the power a wind can give rises with
## the cube of its speed, so a mill twice as far out, in wind half again
## as strong, gives over three times the power. `power` is that, from
## 0 up to about 2.
##
## The beam is a glowing tube from the lamp in the mill's head to the
## collector, brighter with more power, with packets of light running
## along it, more and faster the more power; all engine meshes and
## materials, placed by this script.

const PACKETS := 10
const PACKET_SPEED := 70.0              # m/s at full power

var wind := 0.0                         # 0 calm to about 1.6, here
var power := 0.0
var distance := 0.0                     # from the island's middle, m

var _rotor: Node3D
var _angle := 0.0
var _lamp_mat: StandardMaterial3D
var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _packets: MultiMeshInstance3D
var _lamp_at := Vector3.ZERO            # global
var _target := Vector3.ZERO             # global
var _travel := 0.0


## A mill standing in sea `depth` deep. `wood`, `iron`, `canvas` and
## `brass` are its materials.
func _init(depth: float, wood: Material, iron: Material, canvas: Material, brass: Material) -> void:
	name = "SeaMill"
	# Piles and platform.
	for du: float in [-3.5, 3.5]:
		for dv: float in [-3.5, 3.5]:
			_cyl(0.25, 0.3, depth + 2.2, Vector3(du, (2.2 - depth) * 0.5, dv), iron, 8)
	_box(Vector3(9.0, 0.3, 9.0), Vector3(0, 2.3, 0), wood)
	# A lattice tower: four legs leaning in, with cross ties.
	var top := 20.0
	for du: float in [-1.0, 1.0]:
		for dv: float in [-1.0, 1.0]:
			_rod(Vector3(du * 3.0, 2.4, dv * 3.0), Vector3(du * 0.8, top, dv * 0.8), 0.12, wood)
	for y: float in [6.0, 10.0, 14.0, 18.0]:
		var w := lerpf(3.0, 0.8, (y - 2.4) / (top - 2.4))
		for side in 4:
			var a := Vector3(w, y, w).rotated(Vector3.UP, PI * 0.5 * side)
			var b := Vector3(w, y, -w).rotated(Vector3.UP, PI * 0.5 * side)
			_rod(a, b, 0.06, wood)
	_box(Vector3(2.6, 2.0, 3.4), Vector3(0, top + 1.0, 0), wood)
	var cap := PrismMesh.new()
	cap.size = Vector3(2.9, 1.1, 3.6)
	cap.material = brass
	_put(cap, Vector3(0, top + 2.55, 0))
	# The rotor, facing the open sea (-z, local), four canvas sails.
	_rotor = Node3D.new()
	_rotor.position = Vector3(0, top + 1.0, -2.0)
	add_child(_rotor)
	_cyl(0.4, 0.4, 0.6, Vector3.ZERO, iron, 12, _rotor).rotation.x = PI * 0.5
	for k in 4:
		var arm := Node3D.new()
		arm.rotation.z = TAU * k / 4.0
		_rotor.add_child(arm)
		_box(Vector3(0.25, 10.0, 0.2), Vector3(0, 5.0, 0), wood, arm)
		_box(Vector3(2.2, 7.5, 0.05), Vector3(1.15, 5.8, 0.06), canvas, arm)
	# The lamp in the head, facing the island (+z, local).
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color(1.0, 0.85, 0.5)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1.0, 0.8, 0.4)
	var lens := CylinderMesh.new()
	lens.top_radius = 0.5
	lens.bottom_radius = 0.5
	lens.height = 0.1
	lens.material = _lamp_mat
	_put(lens, Vector3(0, top + 1.0, 1.75)).rotation.x = PI * 0.5
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.albedo_color = Color(1.0, 0.8, 0.45)
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.disable_fog = true
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.height = 1.0
	tube.radial_segments = 8
	tube.material = _beam_mat
	_beam = MeshInstance3D.new()
	_beam.mesh = tube
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.top_level = true
	add_child(_beam)
	var packet := SphereMesh.new()
	packet.radius = 0.45
	packet.height = 0.9
	packet.radial_segments = 8
	packet.rings = 4
	var packet_mat := StandardMaterial3D.new()
	packet_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	packet_mat.albedo_color = Color(2.5, 2.0, 1.0)
	packet_mat.disable_fog = true
	packet.material = packet_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = packet
	mm.instance_count = PACKETS
	_packets = MultiMeshInstance3D.new()
	_packets.multimesh = mm
	_packets.top_level = true
	_packets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_packets)


## The beam's far end, once both stand in the world.
func aim(target: Vector3) -> void:
	_target = target
	_lamp_at = to_global(Vector3(0, 21.0, 1.8))
	var span := _target - _lamp_at
	_beam.global_transform = Transform3D(_aligned(span).scaled(Vector3(1, 1, 1)), (_lamp_at + _target) * 0.5)
	_packets.global_transform = Transform3D.IDENTITY
	_packets.custom_aabb = AABB(_lamp_at.min(_target) - Vector3.ONE * 5, (_target - _lamp_at).abs() + Vector3.ONE * 10)


## The wind here from the wind at the shore: stronger the farther out.
func blow(shore_wind: float, dt: float) -> void:
	var want := clampf(shore_wind * (0.55 + distance / 550.0), 0.0, 1.6)
	wind = move_toward(wind, want, dt * 0.2)
	power = minf(pow(wind, 3.0), 2.0)
	_angle += wind * 1.4 * dt
	_travel += (0.3 + 0.7 * minf(power, 1.0)) * PACKET_SPEED * dt


func _process(_delta: float) -> void:
	_rotor.rotation.z = _angle
	var p := minf(power, 1.5)
	_lamp_mat.emission_energy_multiplier = 1.0 + 4.0 * p
	var span := _target - _lamp_at
	var length := span.length()
	if length < 1.0:
		return
	var r := 0.08 + 0.14 * minf(p, 1.0)
	_beam.global_transform = Transform3D(_aligned(span) * Basis.from_scale(Vector3(r, length, r)), (_lamp_at + _target) * 0.5)
	_beam_mat.albedo_color = Color(1.0 * (0.25 + 0.6 * p), 0.8 * (0.25 + 0.6 * p), 0.45 * (0.25 + 0.6 * p), 1.0)
	# Packets, as many lit as the power can send.
	var lit := int(round(PACKETS * clampf(p, 0.0, 1.0)))
	var mm := _packets.multimesh
	var dir := span / length
	for i in PACKETS:
		var s := fposmod(_travel + i * length / PACKETS, length)
		var size := 1.0 if i < lit else 0.0001
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), _lamp_at + dir * s))


static func _aligned(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


func _put(mesh: Mesh, at: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	(parent if parent != null else self).add_child(view)
	return view


func _box(size: Vector3, at: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	return _put(mesh, at, parent)


func _cyl(top: float, bottom: float, height: float, at: Vector3, mat: Material, segments := 10, parent: Node3D = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	mesh.material = mat
	return _put(mesh, at, parent)


func _rod(a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var view := _cyl(radius, radius, a.distance_to(b), (a + b) * 0.5, mat, 6)
	view.basis = _aligned(b - a)
	return view
