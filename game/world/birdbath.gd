class_name Birdbath
extends Node3D
## For the teaser: an old stone birdbath, dry, and a small earthstone
## loose in its bowl that stands up and spins in the sun and falls over
## in shadow.
##
## The stone is a rigid body of the engine's physics, its solid its own
## faceted shape, its mass from its volume (as TableCrystal): its weight,
## its tipping, its rolling and sliding on the bowl are the engine's. On
## it, each physics step, the laws of a combination stone: lit, its
## seeking end is drawn toward its body, the upright (Photogyrite.pull,
## PULL times the game's law), and it is spun about its length as much as
## it points there (Photogyrite.spin, FORCE times the game's law: the
## teaser's licence); the air drags on its spin. So in the sun it rises
## onto its point, spins and wanders about the bowl as a top does; when a
## sail's shadow takes its light nothing holds it up, it topples, and its
## spin is spent rubbing on the stone. Its light is the share of the
## sun's disc it sees (five points of the disc, its middle and four on its
## edge, so a shadow's edge passes over it by degrees, as the drawn
## shadows' soft edges do), each seen while nothing stands between: the
## house and the mill's tower by a ray, the turning sails by their own
## reckoning (Windmill.sail_shades). It glows the brighter the more it is
## lit and the faster it turns, brighter than the game's stones (also the
## teaser's licence), with a small violet light of its own; the glow
## follows over about a fifth of a second, as a glowing crystal's would
## not flick on and off.
##
## Built at the bath's foot on the ground.

const FORCE := 16.0                     # times the spin law's strength
const PULL := 70.0                      # times the pull law's strength
const AREA := 0.0016                    # m²: the light it catches, a quarter of its surface
const DENSITY := 2650.0                 # kg/m³
const AIR := 4.4e-4                     # N m s: the air's drag on its spin
const STONE_LONG := 0.1                 # m
const RIM_Y := 0.92                     # m: the bowl's rim over the ground
const BOWL_R := 0.32                    # m: the bowl across its rim, half
const DEEP := 0.07                      # m: the bowl's depth
const EASE := 5.0                       # 1/s: how quickly its glow follows

## Toward the sun and its direct light, W/m², set by the teaser.
var to_sun := Vector3.UP
var sunlight := 0.0
var mill: Windmill
## Turns a second now, how far it leans from upright (rad), and the
## share of the sun's disc it sees.
var rate := 0.0
var lean := PI * 0.5
var lit := 0.0

var _stone: RigidBody3D
var _glow: StandardMaterial3D
var _light: OmniLight3D
var _mat: Material
var _half := 0.0                        # m: half its length
var _shine := 0.0                       # its glow, 0 to 1, eased


func _init(world_mat: Material, windmill: Windmill) -> void:
	name = "Birdbath"
	_mat = world_mat
	mill = windmill


func _ready() -> void:
	_build()
	_make_stone()


func _physics_process(delta: float) -> void:
	var axis := _stone.global_basis.y.normalized()
	var middle := _stone.global_position
	lit = _seen(middle)
	var watts := sunlight * AREA * lit
	var w := _stone.angular_velocity
	var omega := w.dot(axis)
	var twist := axis.cross(Vector3.UP) * PULL * Photogyrite.pull(watts, 0.0) \
			+ axis * (FORCE * Photogyrite.spin(watts, maxf(axis.y, 0.0), omega, 0.0) - AIR * omega)
	_stone.apply_torque(twist)
	rate = omega / TAU
	lean = acos(clampf(axis.y, -1.0, 1.0))
	var bright := clampf(absf(omega) / 12.0, 0.0, 1.0) * 0.7 + 0.3 * lit
	_shine = lerpf(_shine, bright, 1.0 - exp(-EASE * delta))
	_glow.emission_energy_multiplier = 0.05 + 6.0 * _shine
	_light.light_energy = 2.0 * _shine
	_light.global_position = middle + Vector3(0, 0.08, 0)


## The share of the sun's disc seen from `at`: its middle and four points
## round its edge.
func _seen(at: Vector3) -> float:
	if sunlight <= 0.0 or to_sun.y <= 0.0:
		return 0.0
	var side := to_sun.cross(Vector3.UP).normalized()
	var up := side.cross(to_sun).normalized()
	var r := deg_to_rad(IslandSky.SUN_ACROSS * 0.5)
	var space := get_world_3d().direct_space_state
	var seen := 0
	for d: Vector3 in [to_sun, to_sun + side * r, to_sun - side * r, to_sun + up * r, to_sun - up * r]:
		var dir := d.normalized()
		var ray := PhysicsRayQueryParameters3D.create(at, at + dir * 80.0, 1)
		ray.exclude = [_stone.get_rid()]
		if space.intersect_ray(ray).is_empty() and (mill == null or not mill.sail_shades(at, dir)):
			seen += 1
	return seen / 5.0


func _build() -> void:
	var m := CozyMesh.new()
	var stone := Color(0.62, 0.6, 0.54)
	# A square foot, a turned column, the bowl on it, its lip chipped.
	m.box(Vector3(0.42, 0.1, 0.42), CozyMesh.at(Vector3(0, 0.05, 0)), stone.darkened(0.1))
	m.cyl(0.11, 0.14, 0.62, 12, CozyMesh.at(Vector3(0, 0.41, 0)), stone)
	m.cyl(0.16, 0.12, 0.06, 12, CozyMesh.at(Vector3(0, 0.75, 0)), stone.darkened(0.05))
	m.cyl(0.36, 0.2, 0.16, 20, CozyMesh.at(Vector3(0, 0.84, 0)), stone, false)
	m.cyl(0.2, 0.2, 0.004, 20, CozyMesh.at(Vector3(0, 0.762, 0)), stone.darkened(0.1))
	m.torus(BOWL_R, 0.37, 20, 5, CozyMesh.at(Vector3(0, RIM_Y, 0)), stone.lightened(0.05))
	m.box(Vector3(0.1, 0.06, 0.08), CozyMesh.at(Vector3(0.34, 0.93, 0.08), Basis(Vector3.UP, 0.4)), stone.darkened(0.2))
	_hollow(m, stone)
	# Lichen and moss on it, a crust of green at the foot.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1809
	for k in 14:
		var a := rng.randf() * TAU
		var y := rng.randf_range(0.15, 0.85)
		var r := 0.12 + (0.2 if y > 0.78 else 0.0)
		var spot := Vector3(cos(a) * r, y, sin(a) * r)
		m.ball(rng.randf_range(0.02, 0.05), 6, CozyMesh.at(spot, CozyMesh.aligned(Vector3(cos(a), 0, sin(a))) * Basis.from_scale(Vector3(1.0, 0.25, 1.0))), [Color(0.7, 0.7, 0.44), Color(0.82, 0.58, 0.24), Color(0.4, 0.5, 0.28)][rng.randi() % 3])
	for k in 8:
		var a := rng.randf() * TAU
		m.ball(rng.randf_range(0.04, 0.08), 6, CozyMesh.at(Vector3(cos(a) * 0.22, 0.1, sin(a) * 0.22), Basis.from_scale(Vector3(1.0, 0.4, 1.0))), Color(0.32, 0.44, 0.22))
	var view := MeshInstance3D.new()
	view.mesh = m.commit(_mat)
	add_child(view)


## The bowl's hollow, a shallow spherical dish, dry, a stain where the
## water stood and a few leaves; and its solid: the column, then a flat
## round floor and a ring of sloped plates to the rim, shapes the engine
## settles a stone on steadily (as CrystalTable's dish).
func _hollow(m: CozyMesh, stone: Color) -> void:
	var sphere := (BOWL_R * BOWL_R + DEEP * DEEP) / (2.0 * DEEP)
	var floor_y := RIM_Y - DEEP
	var centre := Vector3(0, floor_y + sphere, 0)
	var rings := 8
	var sides := 28
	var point := func(i: int, j: int) -> Vector3:
		var a := asin(BOWL_R / sphere) * i / rings
		var b := TAU * j / sides
		return centre + Vector3(sin(a) * cos(b), -cos(a), sin(a) * sin(b)) * sphere
	for i in rings:
		# Darker toward the bottom, where the water stood longest.
		var shade := stone.darkened(0.28 - 0.025 * i)
		for j in sides:
			var p00: Vector3 = point.call(i, j)
			var p01: Vector3 = point.call(i, j + 1)
			var p10: Vector3 = point.call(i + 1, j)
			var p11: Vector3 = point.call(i + 1, j + 1)
			var n := ((p00 + p11) * 0.5 - centre).normalized()
			m.quad(p00, p10, p11, p01, -n, shade)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1811
	for k in 4:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.17, 0.26)
		var y := centre.y - sqrt(sphere * sphere - r * r) + 0.003
		m.box(Vector3(0.045, 0.002, 0.025), CozyMesh.at(Vector3(cos(a) * r, y, sin(a) * r), Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, 0.2)), Color(0.48, 0.36, 0.2).darkened(rng.randf() * 0.2))
	var body := StaticBody3D.new()
	var column := CylinderShape3D.new()
	column.radius = 0.3
	column.height = floor_y - 0.03
	var cc := CollisionShape3D.new()
	cc.shape = column
	cc.position = Vector3(0, column.height * 0.5, 0)
	body.add_child(cc)
	var floor_r := BOWL_R * 0.35
	var base := CylinderShape3D.new()
	base.radius = floor_r
	base.height = 0.02
	var c := CollisionShape3D.new()
	c.shape = base
	c.position = Vector3(0, floor_y - 0.01, 0)
	body.add_child(c)
	var rise := DEEP
	var run := BOWL_R - floor_r
	var tilt := atan2(rise, run)
	var slant := sqrt(rise * rise + run * run)
	for j in 16:
		var b := TAU * j / 16.0
		var out := Vector3(cos(b), 0, sin(b))
		var plate := BoxShape3D.new()
		plate.size = Vector3(slant + 0.02, 0.01, TAU * BOWL_R / 16.0 + 0.02)
		var pc := CollisionShape3D.new()
		pc.shape = plate
		var frame := Basis(Vector3.UP, -b) * Basis(Vector3.BACK, tilt)
		pc.transform = Transform3D(frame, Vector3(0, floor_y + rise * 0.5, 0) + out * (floor_r + run * 0.5) - frame.y * 0.005)
		body.add_child(pc)
	add_child(body)


## The earthstone, grown, scaled to STONE_LONG, lying in the bowl.
func _make_stone() -> void:
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = Color(0.74, 0.62, 0.95, 0.92)
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.roughness = 0.08
	_glow.metallic_specular = 0.9
	_glow.emission_enabled = true
	_glow.emission = Color(0.55, 0.38, 0.95)
	var grown := CozyMesh.new()
	var grow := RandomNumberGenerator.new()
	grow.seed = 61
	LumenPart.grow_spinstone(grown, grow)
	var arrays := grown.commit(_glow).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var box := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		box = box.expand(v)
	var scale_by := STONE_LONG / box.size.y
	for k in verts.size():
		verts[k] *= scale_by
	# Its volume and middle (of mass), from its faces.
	var volume := 0.0
	var middle := Vector3.ZERO
	for k in range(0, index.size(), 3):
		var a := verts[index[k]]
		var b := verts[index[k + 1]]
		var cc := verts[index[k + 2]]
		var v := a.dot(b.cross(cc)) / 6.0
		volume += v
		middle += (a + b + cc) * 0.25 * v
	middle /= volume
	volume = absf(volume)
	for k in verts.size():
		verts[k] -= middle
	box = AABB(verts[0], Vector3.ZERO)
	for v in verts:
		box = box.expand(v)
	_half = box.size.y * 0.5
	_stone = RigidBody3D.new()
	_stone.name = "Earthstone"
	_stone.mass = DENSITY * volume
	var s := box.size
	_stone.inertia = Vector3(s.y * s.y + s.z * s.z, s.x * s.x + s.z * s.z, s.x * s.x + s.y * s.y) * _stone.mass / 12.0
	_stone.can_sleep = false
	_stone.continuous_cd = true
	var friction := PhysicsMaterial.new()
	friction.friction = 0.6
	friction.bounce = 0.05
	_stone.physics_material_override = friction
	var shape := ConvexPolygonShape3D.new()
	shape.points = verts
	var c := CollisionShape3D.new()
	c.shape = shape
	_stone.add_child(c)
	var view_arrays := arrays.duplicate()
	view_arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, view_arrays)
	mesh.surface_set_material(0, _glow)
	var view := MeshInstance3D.new()
	view.mesh = mesh
	_stone.add_child(view)
	_stone.transform = Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.BACK, PI * 0.5), Vector3(0, RIM_Y - DEEP + s.x * 0.5 + 0.01, 0))
	add_child(_stone)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.62, 0.45, 1.0)
	_light.omni_range = 1.4
	_light.position = Vector3(0, RIM_Y, 0)
	add_child(_light)
