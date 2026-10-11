class_name SunstoneJack
extends RigidBody3D
## A pure sunstone pierced through its middle by five brass rods, each
## standing out both sides, so ten legs: a jack lying loose on the grass,
## one rigid body of the engine's physics (its weight on its leg tips,
## the ground's grip on them, its tipping and tumbling the engine's).
##
## The rods' directions lie round the stone's length at even turns,
## tilted alternately toward one end and the other, so whichever way it
## lies it rests on some of its legs. On it, each physics step, the
## spinstone laws of a combination stone by its purity (Photogyrite), by
## the sunlight on a quarter of the stone's surface: its seeking end
## drawn toward the sun, and spun about its length while that end faces
## the sun, the twist scaled by `force_scale` (the panel's); the air's
## slight drag on its turning. Inert at night and in an eclipse's shadow;
## shade is not counted.

const SIZE := 1.0                       # the stone's length, as a share of a whole stone's
const RODS := 5
const LEG := 0.36                       # m: each leg, from the stone's middle to its tip
const ROD_R := 0.008                    # m: the rods' radius
const BRASS_DENSITY := 8500.0           # kg/m³
const TILT := 0.45                      # radians: the rods' lean from square to the stone's length
const AIR := 5.0e-4                     # N m s²: the air's drag on its turning
const AIR_HOLD := 0.02                  # its own slight damping, in place of the engine's default

## Toward the sun and its direct light, W/m², set by the world.
var to_sun := Vector3.UP
var sunlight := 0.0
var purity := 1.0
## A multiplier on the light's pull and spin (a trial knob, the panel's).
var force_scale := 1.0

var _area := 0.0
var _watts := 0.0
var _glow: StandardMaterial3D


func _init() -> void:
	name = "SunstoneJack"
	set_meta("view", self)


func _ready() -> void:
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = Color(1.0, 0.8, 0.45, 0.6)
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.roughness = 0.08
	_glow.metallic_specular = 0.9
	_glow.emission_enabled = true
	_glow.emission = Color(0.85, 0.5, 0.15)
	var grow := RandomNumberGenerator.new()
	grow.seed = 5150
	var cm := CozyMesh.new()
	LumenPart.grow_spinstone(cm, grow)
	var arrays := cm.commit(_glow).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var scale_by := ShedCrystal.WHOLE * SIZE
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
	var box := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		box = box.expand(v)
	# The rods' directions: even turns round the length (+y), tilted
	# toward one end and the other in turn.
	var rods: Array[Vector3] = []
	for k in RODS:
		var a := TAU * k / RODS
		var lean := TILT if k % 2 == 0 else -TILT
		rods.append(Vector3(cos(a) * cos(lean), sin(lean), sin(a) * cos(lean)))
	# Mass and inertia: the stone as the box round it, each rod a thin
	# rod about its middle (its share m L²/12 about every axis square to
	# it); kept to the body's own axes.
	var stone_mass := volume * ShedCrystal.DENSITY
	var rod_mass := BRASS_DENSITY * PI * ROD_R * ROD_R * LEG * 2.0
	var s := box.size
	var inertia_sum := Vector3(s.y * s.y + s.z * s.z, s.x * s.x + s.z * s.z, s.x * s.x + s.y * s.y) * stone_mass / 12.0
	for d in rods:
		var each := rod_mass * pow(LEG * 2.0, 2.0) / 12.0
		inertia_sum += Vector3(1.0 - d.x * d.x, 1.0 - d.y * d.y, 1.0 - d.z * d.z) * each
	mass = stone_mass + rod_mass * RODS
	inertia = inertia_sum
	can_sleep = false
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = AIR_HOLD
	var grip := PhysicsMaterial.new()
	grip.friction = 0.7
	grip.bounce = 0.1
	physics_material_override = grip
	# Its solids: the crystal, and each rod as a capsule.
	var hull := ConvexPolygonShape3D.new()
	hull.points = verts
	var hull_shape := CollisionShape3D.new()
	hull_shape.shape = hull
	add_child(hull_shape)
	for d in rods:
		var capsule := CapsuleShape3D.new()
		capsule.radius = ROD_R * 1.5
		capsule.height = LEG * 2.0
		var c := CollisionShape3D.new()
		c.shape = capsule
		c.basis = CozyMesh.aligned(d)
		add_child(c)
	# Its look: the stone, and the rods with a small knob at each leg's tip.
	var stone_arrays := arrays.duplicate()
	stone_arrays[Mesh.ARRAY_VERTEX] = verts
	var stone_mesh := ArrayMesh.new()
	stone_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, stone_arrays)
	stone_mesh.surface_set_material(0, _glow)
	var stone := MeshInstance3D.new()
	stone.mesh = stone_mesh
	add_child(stone)
	var brass := Color(0.82, 0.62, 0.3)
	var metal_mesh := CozyMesh.new()
	for d in rods:
		metal_mesh.rod(-d * LEG, d * LEG, ROD_R, 8, brass)
		for side: float in [-1.0, 1.0]:
			metal_mesh.ball(ROD_R * 1.8, 8, CozyMesh.at(d * LEG * side), brass)
	var metal := StandardMaterial3D.new()
	metal.vertex_color_use_as_albedo = true
	metal.metallic = 0.8
	metal.roughness = 0.3
	var metal_view := MeshInstance3D.new()
	metal_view.mesh = metal_mesh.commit(metal)
	add_child(metal_view)


func inspect_text() -> String:
	var axis := global_basis.y.normalized()
	var turning := angular_velocity.dot(axis)
	return "A sunstone on ten legs\nA pure sunstone pierced through by five brass rods, lying loose on the grass on their ends. Its seeking end %d degrees off the sun; turning %.2f times a second; %d W of light on it." % [
			roundi(rad_to_deg(axis.angle_to(to_sun))), absf(turning) / TAU, roundi(_watts)]


func _physics_process(_delta: float) -> void:
	_watts = sunlight * _area if to_sun.y > 0.0 else 0.0
	var axis := global_basis.y.normalized()
	var w := angular_velocity
	var turning := w.dot(axis)
	var drive := Photogyrite.spin(_watts, maxf(axis.dot(to_sun), 0.0), turning, purity) * force_scale
	apply_torque(axis.cross(to_sun) * Photogyrite.pull(_watts, purity) * force_scale + axis * drive - w * w.length() * AIR)
	_glow.emission_energy_multiplier = 0.3 + 0.8 * clampf(absf(turning) / 6.0, 0.0, 1.0)
