class_name GlassOrb
extends RigidBody3D
## A large earthstone set in a solid ball of clear glass, lying loose on
## the grass in the sun: the stone and the glass one rigid body (the
## engine's physics rolls it, its weight and the ground's friction its
## own), a ball the stone turns from within.
##
## The stone is the spinstone of the shed's crystals (ShedCrystal) at
## SIZE times a whole stone's length, its middle at the ball's, its axis
## at random to begin. On the ball, each physics step, the spinstone laws
## as a combination stone, by the sunlight through the glass (GLASS of it
## passes) on a quarter of the stone's surface: its axis drawn toward
## straight up, PULL_PER_WATT for each watt, and spun about its axis TURN
## for each watt while its seeking end is up; the air's drag on the
## ball's turning. A ball on level ground turns without lifting its
## weight, so however weak the pull it rolls, slowly, until the stone
## stands upright, then turns on the spot about the upright. The ground's
## grip on a rolling ball is the engine's; its slight hold on rolling and
## spinning is an angular damping (ROLL_HOLD). Inert at night and in an
## eclipse's shadow; the shade of things on the island is not counted.

const SIZE := 2.0                       # the stone's length, as a share of a whole stone's
const RADIUS := 0.55                    # m: the ball
const GLASS_DENSITY := 2500.0           # kg/m³
const GLASS := 0.9                      # the share of sunlight the glass lets through
const ROLL_HOLD := 0.15                 # the grass's hold on its rolling and spinning

## Toward the sun and its direct light, W/m², set by the world.
var to_sun := Vector3.UP
var sunlight := 0.0

var _axis := Vector3.UP                 # the stone's axis, in the ball's frame
var _area := 0.0
var _scale := 1.0
var _watts := 0.0
var _glow: StandardMaterial3D


func _init() -> void:
	name = "GlassOrb"
	set_meta("view", self)


func _ready() -> void:
	_scale = ShedCrystal.WHOLE * SIZE
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = Color(0.74, 0.62, 0.95, 0.95)
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.roughness = 0.08
	_glow.metallic_specular = 0.9
	_glow.emission_enabled = true
	_glow.emission = Color(0.5, 0.36, 0.85)
	var grow := RandomNumberGenerator.new()
	grow.seed = 4021
	var cm := CozyMesh.new()
	LumenPart.grow_spinstone(cm, grow)
	var arrays := cm.commit(_glow).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for k in verts.size():
		verts[k] *= _scale
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
	# The ball's mass and inertia: glass round a stone of much the same
	# density, as a solid ball.
	var ball := 4.0 / 3.0 * PI * pow(RADIUS, 3.0)
	mass = (ball - volume) * GLASS_DENSITY + volume * ShedCrystal.DENSITY
	inertia = Vector3.ONE * 0.4 * mass * RADIUS * RADIUS
	angular_damp = ROLL_HOLD
	can_sleep = false
	var grip := PhysicsMaterial.new()
	grip.friction = 0.9
	grip.bounce = 0.05
	physics_material_override = grip
	var shape := SphereShape3D.new()
	shape.radius = RADIUS
	var c := CollisionShape3D.new()
	c.shape = shape
	add_child(c)
	# The stone, its axis tipped at random in the ball.
	var tip := Basis(Vector3(1, 0, 0.4).normalized(), 1.1)
	_axis = tip * Vector3.UP
	var stone_arrays := arrays.duplicate()
	stone_arrays[Mesh.ARRAY_VERTEX] = verts
	var stone_mesh := ArrayMesh.new()
	stone_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, stone_arrays)
	stone_mesh.surface_set_material(0, _glow)
	var stone := MeshInstance3D.new()
	stone.mesh = stone_mesh
	stone.basis = tip
	add_child(stone)
	# The glass: clear, glossy, the far side seen through the near.
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.95, 1.0, 0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.03
	glass.metallic_specular = 1.0
	glass.rim_enabled = true
	glass.rim = 0.4
	glass.rim_tint = 0.2
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	sphere.material = glass
	var view := MeshInstance3D.new()
	view.mesh = sphere
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)


func inspect_text() -> String:
	var axis := (global_basis * _axis).normalized()
	return "An earthstone in glass\nA large earthstone set in a solid ball of clear glass. In the sun the stone draws its seeking end up and spins, and the ball rolls with it. Its end now %d degrees off straight up; turning %.2f times a second." % [
			roundi(rad_to_deg(axis.angle_to(Vector3.UP))), absf(angular_velocity.dot(axis)) / TAU]


func _physics_process(_delta: float) -> void:
	_watts = sunlight * GLASS * _area if to_sun.y > 0.0 else 0.0
	var axis := (global_basis * _axis).normalized()
	var w := angular_velocity
	var grown := pow(_scale / ShedCrystal.WHOLE, 5.0)
	apply_torque(axis.cross(Vector3.UP) * SpinstoneGimbals.PULL_PER_WATT * _watts \
			+ axis * SpinstoneGimbals.TURN * _watts * maxf(axis.y, 0.0) \
			- w * w.length() * ShedCrystal.DRAG * grown)
	_glow.emission_energy_multiplier = 0.1 + 0.8 * clampf(absf(w.dot(axis)) / 3.0, 0.0, 1.0)
