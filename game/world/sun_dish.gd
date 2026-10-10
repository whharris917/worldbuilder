class_name SunDish
extends Node3D
## A sun collector's dish and its mount, in brass, iron and silvered
## glass: a burning mirror. The dish is a paraboloid DISH_D across built
## of flat facets of silvered glass in a brass frame, a riveted copper
## shell behind, so every ray of sun striking it is sent to one point,
## its focus, FOCAL in front of it. There, held out on four brass arms, a
## glass globe in a brass cage catches the gathered light and glows with
## it (`glow`); inside the globe stands the collector's turning head,
## which sends the light out as a beam wherever it is aimed (the head is
## moved to `focus` each frame).
##
## The mount: a cast-iron fork turning on a toothed brass turntable atop
## a fluted column on three legs (the dish's compass bearing), the dish
## swinging between the fork's arms on an axle with a brass quadrant gear
## (its height). The dish is turned to face a direction with `point_at`.
##
## Built in the collector's frame: its origin where the collector stands
## (on its rod, a metre over the ground to begin), the column rising from
## it, the legs reaching down.

const DISH_D := 2.0                     # the dish, m across
const FOCAL := 0.9                      # its focal length, m
const PIVOT := 1.75                     # the axle's height over the collector's middle
const YOKE := 0.6                       # the turntable's height
const ARM_X := 1.18                     # the fork's arms either side of the axle's middle
const VERTEX := 0.2                     # the dish's deepest point, ahead of the axle along its axis
const LEGS := 1.0                       # how far down the legs reach

var _yoke: Node3D
var _dish: Node3D
var _globe_mat: StandardMaterial3D


## `polish` for the silvered facets, `iron` for the mount, `brass` for
## the frame and fittings, `copper` for the dish's back.
func _init(polish: Material, iron: Material, brass: Material, copper: Material) -> void:
	name = "SunDish"
	set_meta(StaticMerge.MOVES, true)
	var still := CozyMesh.new()
	var fittings := CozyMesh.new()
	var grey := Color(0.25, 0.26, 0.27)
	var gold := Color(0.85, 0.66, 0.32)
	# Three legs with ball feet, a brass collar where they meet.
	for k in 3:
		var a := TAU * k / 3.0 + 0.3
		var foot := Vector3(cos(a) * 0.75, -LEGS, sin(a) * 0.75)
		still.rod(Vector3(cos(a) * 0.06, -0.05, sin(a) * 0.06), foot, 0.035, 8, grey)
		fittings.ball(0.06, 10, CozyMesh.at(foot), gold)
	fittings.cyl(0.11, 0.11, 0.08, 14, CozyMesh.at(Vector3(0, -0.05, 0)), gold)
	# The fluted column: a ring of reeds round a core, brass bands.
	still.cyl(0.07, 0.08, YOKE, 12, CozyMesh.at(Vector3(0, YOKE * 0.5, 0)), grey)
	for k in 10:
		var a := TAU * k / 10.0
		still.cyl(0.018, 0.02, YOKE - 0.08, 6, CozyMesh.at(Vector3(cos(a) * 0.075, YOKE * 0.5, sin(a) * 0.075)), grey)
	for y: float in [0.06, YOKE - 0.04]:
		fittings.cyl(0.105, 0.105, 0.04, 14, CozyMesh.at(Vector3(0, y, 0)), gold)
	_view(self, "Mount", still.commit(iron))
	_view(self, "MountBrass", fittings.commit(brass))
	_yoke = Node3D.new()
	_yoke.position.y = YOKE
	add_child(_yoke)
	var fork := CozyMesh.new()
	var fork_brass := CozyMesh.new()
	# The toothed turntable, and the fork rising from it.
	fork_brass.cyl(0.3, 0.3, 0.05, 28, CozyMesh.at(Vector3(0, 0.025, 0)), gold)
	Windmill._cogs(fork_brass, 36, 0.31, Vector3(0.03, 0.045, 0.04), CozyMesh.at(Vector3(0, 0.025, 0)), gold)
	fork.box(Vector3(ARM_X * 2.0 + 0.12, 0.1, 0.16), CozyMesh.at(Vector3(0, 0.1, 0)), grey)
	for s: float in [-1.0, 1.0]:
		var top := Vector3(s * ARM_X, PIVOT - YOKE, 0)
		fork.rod(Vector3(s * ARM_X, 0.1, 0), top, 0.06, 8, grey)
		# A curved brace from the turntable to each arm.
		fork.rod(Vector3(s * 0.25, 0.12, 0), Vector3(s * ARM_X, 0.75, 0), 0.03, 6, grey)
		fork_brass.cyl(0.085, 0.085, 0.16, 14, CozyMesh.at(top, Basis(Vector3.FORWARD, PI * 0.5)), gold)
	# The worm that turns the quadrant, on the right arm.
	fork_brass.cyl(0.05, 0.05, 0.24, 12, CozyMesh.at(Vector3(ARM_X + 0.12, PIVOT - YOKE - 0.38, 0), Basis(Vector3.RIGHT, PI * 0.5)), gold)
	fork_brass.ball(0.05, 10, CozyMesh.at(Vector3(ARM_X + 0.12, PIVOT - YOKE - 0.38, 0.15)), gold)
	_view(_yoke, "Fork", fork.commit(iron))
	_view(_yoke, "ForkBrass", fork_brass.commit(brass))
	_dish = Node3D.new()
	_dish.position.y = PIVOT - YOKE
	_yoke.add_child(_dish)
	var face := CozyMesh.new()
	var back := CozyMesh.new()
	var frame := CozyMesh.new()
	_build_dish(face, back, frame)
	_view(_dish, "Facets", face.commit(polish))
	_view(_dish, "Shell", back.commit(copper))
	_view(_dish, "Frame", frame.commit(brass))
	# The globe at the focus, glowing with what the dish gathers.
	_globe_mat = StandardMaterial3D.new()
	_globe_mat.albedo_color = Color(1.0, 0.95, 0.85, 0.28)
	_globe_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_globe_mat.roughness = 0.05
	_globe_mat.metallic_specular = 0.8
	_globe_mat.emission_enabled = true
	_globe_mat.emission = Color(1.0, 0.8, 0.45)
	_globe_mat.emission_energy_multiplier = 0.0
	var globe := SphereMesh.new()
	globe.radius = 0.17
	globe.height = 0.34
	globe.radial_segments = 20
	globe.rings = 10
	globe.material = _globe_mat
	var g := MeshInstance3D.new()
	g.name = "Globe"
	g.mesh = globe
	g.position = Vector3(0, VERTEX + FOCAL, 0)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dish.add_child(g)
	point_at(Vector3(0.0, 0.7, 0.7).normalized())


func _view(parent: Node3D, title: String, mesh: Mesh) -> void:
	var view := MeshInstance3D.new()
	view.name = title
	view.mesh = mesh
	parent.add_child(view)


## The dish in its own frame: its axis +y, the axle at the origin.
func _build_dish(face: CozyMesh, back: CozyMesh, frame: CozyMesh) -> void:
	var white := Color(0.94, 0.95, 0.97)
	var gold := Color(0.85, 0.66, 0.32)
	var copper := Color(0.7, 0.4, 0.25)
	var radius := DISH_D * 0.5
	var rings := [0.14, 0.36, 0.58, 0.8, 1.0]
	var petals := [8, 12, 16, 20]
	var depth := func(r: float) -> float: return VERTEX + r * r / (4.0 * FOCAL)
	var at := func(r: float, a: float) -> Vector3: return Vector3(cos(a) * r, depth.call(r), sin(a) * r)
	for k in petals.size():
		var r0: float = float(rings[k]) * radius
		var r1: float = float(rings[k + 1]) * radius
		var n: int = petals[k]
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var corners: Array[Vector3] = [at.call(r0, a0), at.call(r0, a1), at.call(r1, a1), at.call(r1, a0)]
			var mid := (corners[0] + corners[1] + corners[2] + corners[3]) * 0.25
			var normal := (corners[2] - corners[0]).cross(corners[1] - corners[3]).normalized()
			if normal.dot(Vector3.UP) < 0.0:
				normal = -normal
			# Each facet a flat pane, set a little in from its frame.
			var inset: Array[Vector3] = []
			for c in corners:
				inset.append(mid + (c - mid) * 0.93 + normal * 0.004)
			face.quad(inset[0], inset[1], inset[2], inset[3], normal, white)
			back.quad(corners[0] - normal * 0.03, corners[1] - normal * 0.03, corners[2] - normal * 0.03,
					corners[3] - normal * 0.03, -normal, copper)
			# The frame: a brass bar along each facet's side and outer edge.
			frame.rod(corners[0], corners[3], 0.012, 4, gold)
			frame.rod(corners[3], corners[2], 0.012, 4, gold)
	# The rim, with rivets; the boss in the middle; ribs behind.
	var rim: float = depth.call(radius)
	Windmill._ring(frame, radius - 0.01, radius + 0.05, rim - 0.06, rim + 0.01, Transform3D.IDENTITY, gold, 40)
	for i in 40:
		var a := TAU * i / 40.0
		frame.ball(0.014, 6, CozyMesh.at(at.call(radius + 0.035, a) + Vector3.UP * 0.012), gold)
	frame.cyl(float(rings[0]) * radius + 0.02, float(rings[0]) * radius, 0.08, 16, CozyMesh.at(Vector3(0, VERTEX + 0.03, 0)), gold)
	frame.ball(0.06, 10, CozyMesh.at(Vector3(0, VERTEX + 0.08, 0)), gold)
	for i in 8:
		var a := TAU * i / 8.0
		back.rod(Vector3(cos(a) * 0.12, VERTEX - 0.08, sin(a) * 0.12), at.call(radius, a) - Vector3.UP * 0.07, 0.02, 6, copper)
	back.cyl(0.16, 0.12, VERTEX + 0.05, 12, CozyMesh.at(Vector3(0, (VERTEX - 0.05) * 0.5, 0)), copper)
	back.cyl(0.07, 0.07, ARM_X * 2.0 - 0.1, 10, CozyMesh.at(Vector3.ZERO, Basis(Vector3.FORWARD, PI * 0.5)), copper)
	# The quadrant gear on the axle's right end, turning with the dish.
	var quad := Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(ARM_X + 0.1, 0, 0))
	frame.cyl(0.36, 0.36, 0.03, 24, quad, gold)
	Windmill._cogs(frame, 40, 0.37, Vector3(0.025, 0.03, 0.035), quad, gold)
	# Four arms from the rim to the cage round the globe at the focus.
	var focus := Vector3(0, VERTEX + FOCAL, 0)
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var out := Vector3(cos(a), 0, sin(a))
		frame.rod(at.call(radius, a), focus + out * 0.2, 0.014, 6, gold)
	for b: Basis in [Basis.IDENTITY, Basis(Vector3.RIGHT, PI * 0.5), Basis(Vector3.BACK, PI * 0.5)]:
		frame.torus(0.18, 0.2, 24, 6, CozyMesh.at(focus, b), gold)


## The dish turned to face `dir` (world): the fork about the upright to
## its bearing, the dish about the axle to its height.
func point_at(dir: Vector3) -> void:
	var local := (global_basis.inverse() * dir).normalized() if is_inside_tree() else dir.normalized()
	var flat := Vector2(local.x, local.z)
	_yoke.rotation = Vector3(0, atan2(local.x, local.z) if flat.length() > 1e-4 else 0.0, 0)
	var height := asin(clampf(local.y, -1.0, 1.0))
	# The dish's axis is its +y: swung forward (+z) from straight up.
	_dish.rotation = Vector3(PI * 0.5 - height, 0, 0)


## The focus, where the gathered light meets and the head stands (world).
func focus() -> Vector3:
	return _dish.to_global(Vector3(0, VERTEX + FOCAL, 0))


## The middle of the dish's mirror, where the sun must reach (world).
func centre() -> Vector3:
	return _dish.to_global(Vector3(0, VERTEX + 0.25, 0))


## The globe's glow, 0 dark to 1 at full sun.
func glow(level: float) -> void:
	_globe_mat.emission_energy_multiplier = 4.0 * clampf(level, 0.0, 1.0)
