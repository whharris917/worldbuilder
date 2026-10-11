class_name GlassOrb
extends RigidBody3D
## A large earthstone fixed inside a hollow globe of clear glass (a shell
## SHELL thick, blown by hand: faintly green, a little out of round, with
## small bubbles in it), mounted on a brass rod through its middle whose
## ends are set into the glass, or braced by struts (`mounting`), held at the
## middle of a pool (OrbPool) by a smooth wooden ring at the water's
## surface, which keeps it in place and lets it turn freely any way on a
## film of water, as a fountain's floating ball turns: the stone and the
## glass one rigid body, its place fixed (its motion locked), its turning
## free.
##
## The stone is the spinstone of the shed's crystals (ShedCrystal) at
## SIZE times a whole stone's length, its middle at the ball's, its axis
## at random to begin. On the ball, each physics step, the spinstone laws
## as a combination stone, by the sunlight through the glass (GLASS of it
## passes) on a quarter of the stone's surface: its axis drawn toward
## straight up and spun about its axis while its seeking end is up, by
## its purity (`purity`, Photogyrite: an impure stone as found, or a pure
## one a hundred times as strong, its spin's power up to 80% of its
## light); the air's slight drag on the smooth globe's turning (AIR), and
## the water film's (WATER_HOLD, an angular damping). Held in its ring the ball turns without lifting its weight,
## so the pull sways the stone upright and then spins the globe about
## the upright, gathering speed over minutes against the water's hold.
## Inert at night and in an eclipse's shadow; the shade of things on the
## island is not counted.

const SIZE := 2.0                       # the stone's length, as a share of a whole stone's
const RADIUS := 0.55                    # m: the ball
const GLASS_DENSITY := 2500.0           # kg/m³
const SHELL := 0.01                     # m: the glass's thickness
const GLASS := 0.9                      # the share of sunlight the glass lets through
const WATER_HOLD := 0.005               # the water film's hold on its turning
const STRUTS := 5                       # the struts bracing an undrilled stone
const GROUND_HOLD := 0.05               # the grass's hold on a loose globe's rolling and spinning
const AIR := 1.0e-3                     # N m s²: the air's drag on the smooth globe's turning

## The stone's purity (Photogyrite), set before it enters the world.
var purity := 0.0
## How the stone is held in the globe, set before it enters the world:
## "rod" (a brass rod through it, the stone drilled) or "struts" (brass
## rods pressing on its faces from the glass, the stone whole), or "axle"
## (a brass rod through it along its length, its ends at the globe's
## poles, the stone drilled from end to end).
var mounting := "rod"
## Loose on the ground rather than held in a pool's ring: free to roll,
## the ground's slight hold on its rolling and spinning (GROUND_HOLD) in
## place of the water's.
var loose := false
## A multiplier on the light's pull and spin on the stone (a trial knob,
## the panel's), 1 as the laws give.
var force_scale := 1.0
## How thick the pool's liquid is, as many times water's: its film's hold
## on the ball's turning (any way: rocking and spinning alike) grows in
## proportion.
var viscosity := 1.0

## Toward the sun and its direct light, W/m², set by the world.
var to_sun := Vector3.UP
var sunlight := 0.0

var _axis := Vector3.UP                 # the stone's axis, in the ball's frame
var _area := 0.0
var _scale := 1.0
var _watts := 0.0
var _drive := 0.0                       # N m: the light's spin on it now
var _glow: StandardMaterial3D


func _init() -> void:
	name = "GlassOrb"
	set_meta("view", self)


func _ready() -> void:
	_scale = ShedCrystal.WHOLE * SIZE
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = Color(0.82, 0.74, 1.0, 0.55) if purity > 0.5 else Color(0.74, 0.62, 0.95, 0.95)
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
	# The globe's mass and inertia: a thin shell of glass (two thirds of
	# its mass times its radius squared) and the stone (as the box round
	# it, an average over its axes, since it lies tipped in the globe).
	var shell := 4.0 * PI * RADIUS * RADIUS * SHELL * GLASS_DENSITY
	var stone_mass := volume * ShedCrystal.DENSITY
	var box := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		box = box.expand(v)
	var d := box.size
	mass = shell + stone_mass
	inertia = Vector3.ONE * (2.0 / 3.0 * shell * RADIUS * RADIUS + stone_mass * (d.x * d.x + d.y * d.y + d.z * d.z) / 18.0)
	# The water's hold alone, in place of the engine's own default drag.
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = WATER_HOLD
	# Held in its ring: free to turn, not to move.
	axis_lock_linear_x = not loose
	axis_lock_linear_y = not loose
	axis_lock_linear_z = not loose
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
	if mounting == "struts":
		_set_struts(verts, index, tip)
	elif mounting == "axle":
		_set_rod(tip, tip * Vector3.UP)
	else:
		_set_rod(tip, tip * Vector3.RIGHT)
	# The glass, blown by hand: a faint green of old glass, its thickness
	# seen at its edge (its inner face as well as its outer), not quite
	# round, with small bubbles caught in it.
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.82, 0.95, 0.86, 0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.03
	glass.metallic_specular = 1.0
	glass.rim_enabled = true
	glass.rim = 0.45
	glass.rim_tint = 0.3
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var round_off := Vector3(1.0, 0.988, 1.006)
	for radius: float in [RADIUS, RADIUS - SHELL]:
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 2.0
		sphere.radial_segments = 48
		sphere.rings = 24
		sphere.material = glass
		var view := MeshInstance3D.new()
		view.mesh = sphere
		view.scale = round_off
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(view)
	var bubbles := CozyMesh.new()
	var r := RandomNumberGenerator.new()
	r.seed = 1631
	for k in 40:
		var spot := Vector3(r.randf_range(-1, 1), r.randf_range(-1, 1), r.randf_range(-1, 1)).normalized()
		bubbles.ball(r.randf_range(0.0015, 0.005), 6, CozyMesh.at(spot * (RADIUS - SHELL * 0.5) * round_off), Color(1, 1, 1))
	var bubble_mat := StandardMaterial3D.new()
	bubble_mat.vertex_color_use_as_albedo = true
	bubble_mat.albedo_color = Color(1, 1, 1, 0.5)
	bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bubble_mat.roughness = 0.0
	bubble_mat.metallic_specular = 1.0
	var bubble_view := MeshInstance3D.new()
	bubble_view.mesh = bubbles.commit(bubble_mat)
	bubble_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bubble_view)


## Its mounting: a brass rod through the stone's middle along `across`
## (square to its length, the stone drilled across; or along its length,
## drilled from end to end), its ends set into the glass in brass
## collars; the stone hangs on it as on an axle fixed in the globe.
func _set_rod(_tip: Basis, across: Vector3) -> void:
	var brass := Color(0.82, 0.62, 0.3)
	var mount := CozyMesh.new()
	mount.rod(-across * (RADIUS - SHELL), across * (RADIUS - SHELL), 0.012, 10, brass)
	for side: float in [-1.0, 1.0]:
		var end := across * side * (RADIUS - SHELL * 0.5)
		mount.cyl(0.035, 0.035, 0.03, 14, CozyMesh.at(end, CozyMesh.aligned(across)), brass)
	var metal := StandardMaterial3D.new()
	metal.vertex_color_use_as_albedo = true
	metal.metallic = 0.8
	metal.roughness = 0.3
	var mount_view := MeshInstance3D.new()
	mount_view.mesh = mount.commit(metal)
	add_child(mount_view)


## Its mounting without a hole in it: STRUTS brass rods held in
## compression between the stone and the glass, each pressing square on
## one of the stone's faces through a flat foot and on the inside of the
## shell through a collar; the faces chosen to point as far apart as can
## be (each next one the face whose outward direction lies farthest from
## those already chosen), so the rods brace it from every side.
func _set_struts(verts: PackedVector3Array, index: PackedInt32Array, tip: Basis) -> void:
	var faces: Array[Array] = []        # [middle, outward]
	for k in range(0, index.size(), 3):
		var a := verts[index[k]]
		var b := verts[index[k + 1]]
		var c := verts[index[k + 2]]
		var n := (b - a).cross(c - a)
		if n.length() < 1e-6:
			continue
		var middle := (a + b + c) / 3.0
		n = n.normalized()
		if n.dot(middle) < 0.0:
			n = -n
		faces.append([middle, n])
	var chosen: Array[Array] = []
	var first := 0
	for k in faces.size():
		if (faces[k][1] as Vector3).y > (faces[first][1] as Vector3).y:
			first = k
	chosen.append(faces[first])
	while chosen.size() < STRUTS:
		var best := 0
		var best_gap := -INF
		for k in faces.size():
			var gap := INF
			for c: Array in chosen:
				gap = minf(gap, -(faces[k][1] as Vector3).dot(c[1]))
			if gap > best_gap:
				best_gap = gap
				best = k
		chosen.append(faces[best])
	var brass := Color(0.82, 0.62, 0.3)
	var rods := CozyMesh.new()
	var inner := RADIUS - SHELL
	for face: Array in chosen:
		var from: Vector3 = face[0]
		var d: Vector3 = face[1]
		var b := from.dot(d)
		var t := -b + sqrt(maxf(b * b - (from.length_squared() - inner * inner), 0.0))
		var to := from + d * t
		rods.rod(from + d * 0.01, to, 0.011, 10, brass)
		rods.cyl(0.03, 0.03, 0.012, 14, CozyMesh.at(from + d * 0.006, CozyMesh.aligned(d)), brass)
		rods.cyl(0.028, 0.034, 0.025, 14, CozyMesh.at(to - d * 0.012, CozyMesh.aligned(d)), brass)
	var metal := StandardMaterial3D.new()
	metal.vertex_color_use_as_albedo = true
	metal.metallic = 0.8
	metal.roughness = 0.3
	var view := MeshInstance3D.new()
	view.mesh = rods.commit(metal)
	view.basis = tip
	add_child(view)


func inspect_text() -> String:
	var axis := (global_basis * _axis).normalized()
	var turning := angular_velocity.dot(axis)
	return "%s in glass\nA large %s earthstone fixed inside a hollow globe of clear glass, turning freely in a wooden ring on a film of water. In the sun the stone draws its seeking end up and spins, and the ball turns with it. Its end now %d degrees off straight up; turning %.2f times a second; %d W of light on it, %d W in its spin." % [
			"A pure earthstone" if purity > 0.5 else "An earthstone", "pure" if purity > 0.5 else "cloudy",
			roundi(rad_to_deg(axis.angle_to(Vector3.UP))), absf(turning) / TAU, roundi(_watts), roundi(maxf(_drive * turning, 0.0))]


func _physics_process(_delta: float) -> void:
	angular_damp = GROUND_HOLD if loose else WATER_HOLD * viscosity
	_watts = sunlight * GLASS * _area if to_sun.y > 0.0 else 0.0
	var axis := (global_basis * _axis).normalized()
	var w := angular_velocity
	var turning := w.dot(axis)
	_drive = Photogyrite.spin(_watts, maxf(axis.y, 0.0), turning, purity) * force_scale
	apply_torque(axis.cross(Vector3.UP) * Photogyrite.pull(_watts, purity) * force_scale + axis * _drive - w * w.length() * AIR)
	_glow.emission_energy_multiplier = 0.1 + 0.8 * clampf(absf(turning) / 3.0, 0.0, 1.0) + (0.6 if purity > 0.5 else 0.0)
