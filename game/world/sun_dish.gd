class_name SunDish
extends Node3D
## A sun collector's dish and its mount: a parabolic mirror DISH_D across
## that gathers the sun to a point, built as a reflecting telescope is.
## A small convex secondary mirror held on three struts short of the
## dish's focus sends the gathered light back down the dish's axis,
## through a hole in its middle, into a tube; the tube runs along the
## elevation axis into one arm of the fork, down the arm and the column
## to the output head below (the collector's own turning head). So the
## light comes out at the head whichever way the dish points, and the
## head aims the beam on its own (a coudé path, as great telescopes use).
##
## The mount: a fork on a column turning about the upright (the dish's
## compass bearing), the dish swinging between the fork's arms on a
## horizontal axle (its height). The dish is turned to face a direction
## with `point_at`.
##
## Built in the collector's frame: the output head at the origin, the
## column rising from it, the axle PIVOT above it.

const DISH_D := 2.0                     # the dish, m across
const FOCAL := 0.8                      # its focal length, m: about a third as deep as a soup plate
const HOLE := 0.09                      # the hole in its middle, m across each way
const PIVOT := 2.1                      # the axle's height over the head
const YOKE := 1.0                       # the fork's base over the head
const ARM_X := 1.18                     # the fork's arms either side of the axle's middle
const VERTEX := 0.25                    # the dish's deepest point, ahead of the axle along its axis

var _yoke: Node3D
var _dish: Node3D


## `polish` for the mirrors, `iron` for the dish's back and the mount,
## `brass` for the fittings.
func _init(polish: Material, iron: Material, brass: Material) -> void:
	name = "SunDish"
	set_meta(StaticMerge.MOVES, true)
	var still := CozyMesh.new()
	var grey := Color(0.32, 0.34, 0.35)
	var gold := Color(0.85, 0.66, 0.32)
	# The column from the head's top to the turntable under the fork.
	still.cyl(0.07, 0.09, YOKE - 0.12, 10, CozyMesh.at(Vector3(0, 0.12 + (YOKE - 0.12) * 0.5, 0)), grey)
	_view(self, "Column", still.commit(iron))
	_yoke = Node3D.new()
	_yoke.position.y = YOKE
	add_child(_yoke)
	var fork := CozyMesh.new()
	fork.cyl(0.16, 0.16, 0.06, 16, CozyMesh.at(Vector3(0, 0.0, 0)), grey)
	fork.box(Vector3(ARM_X * 2.0 + 0.1, 0.1, 0.14), CozyMesh.at(Vector3(0, 0.08, 0)), grey)
	for s: float in [-1.0, 1.0]:
		fork.box(Vector3(0.1, PIVOT - YOKE + 0.06, 0.14), CozyMesh.at(Vector3(s * ARM_X, (PIVOT - YOKE) * 0.5 + 0.06, 0)), grey)
		fork.cyl(0.08, 0.08, 0.14, 12, CozyMesh.at(Vector3(s * ARM_X, PIVOT - YOKE, 0), Basis(Vector3.FORWARD, PI * 0.5)), gold)
	# The light's tube down the right arm and across to the column.
	fork.rod(Vector3(ARM_X + 0.09, PIVOT - YOKE, 0), Vector3(ARM_X + 0.09, 0.14, 0), 0.035, 8, gold)
	fork.rod(Vector3(ARM_X + 0.09, 0.14, 0), Vector3(0.12, 0.14, 0), 0.035, 8, gold)
	_view(_yoke, "Fork", fork.commit(iron))
	_dish = Node3D.new()
	_dish.position.y = PIVOT - YOKE
	_yoke.add_child(_dish)
	var face := CozyMesh.new()
	var back := CozyMesh.new()
	var fittings := CozyMesh.new()
	_build_dish(face, back, fittings)
	_view(_dish, "Mirror", face.commit(polish))
	_view(_dish, "Back", back.commit(iron))
	_view(_dish, "Fittings", fittings.commit(brass))
	point_at(Vector3(0.0, 0.7, 0.7).normalized())


func _view(parent: Node3D, title: String, mesh: Mesh) -> void:
	var view := MeshInstance3D.new()
	view.name = title
	view.mesh = mesh
	parent.add_child(view)


## The dish in its own frame: its axis +y, the axle at the origin, the
## dish's deepest point VERTEX up the axis.
func _build_dish(face: CozyMesh, back: CozyMesh, fittings: CozyMesh) -> void:
	var white := Color(0.92, 0.93, 0.95)
	var grey := Color(0.32, 0.34, 0.35)
	var gold := Color(0.85, 0.66, 0.32)
	var rings := 12
	var sides := 40
	var radius := DISH_D * 0.5
	var depth := func(r: float) -> float: return VERTEX + r * r / (4.0 * FOCAL)
	for k in rings:
		var r0 := lerpf(HOLE, radius, float(k) / rings)
		var r1 := lerpf(HOLE, radius, float(k + 1) / rings)
		var z0: float = depth.call(r0)
		var z1: float = depth.call(r1)
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var p := [d0 * r0 + Vector3.UP * z0, d1 * r0 + Vector3.UP * z0, d1 * r1 + Vector3.UP * z1, d0 * r1 + Vector3.UP * z1]
			# The paraboloid's normal, inward and up: (-r / 2f along the radius, 1).
			var n := [(Vector3.UP - d0 * r0 / (2.0 * FOCAL)).normalized(), (Vector3.UP - d1 * r0 / (2.0 * FOCAL)).normalized(),
					(Vector3.UP - d1 * r1 / (2.0 * FOCAL)).normalized(), (Vector3.UP - d0 * r1 / (2.0 * FOCAL)).normalized()]
			face.quad_normals(p[0], p[1], p[2], p[3], n, white)
			var off := Vector3.DOWN * 0.035
			back.quad_normals(p[0] + off, p[1] + off, p[2] + off, p[3] + off, [-n[0], -n[1], -n[2], -n[3]], grey)
	# The rim, the ribs behind, the hub round the hole.
	var rim: float = depth.call(radius)
	Windmill._ring(fittings, radius - 0.01, radius + 0.04, rim - 0.05, rim + 0.01, Transform3D.IDENTITY, gold, sides)
	for i in 6:
		var a := TAU * i / 6.0
		var out := Vector3(cos(a), 0, sin(a))
		back.rod(out * 0.12 + Vector3.UP * (VERTEX - 0.06), out * radius + Vector3.UP * (rim - 0.07), 0.025, 6, grey)
	back.cyl(0.13, 0.15, VERTEX, 12, CozyMesh.at(Vector3(0, VERTEX * 0.5, 0)), grey)
	back.cyl(0.09, 0.09, ARM_X * 2.0 - 0.1, 10, CozyMesh.at(Vector3.ZERO, Basis(Vector3.FORWARD, PI * 0.5)), grey)
	# The secondary mirror on three struts from the rim, short of the focus.
	var second := VERTEX + FOCAL - 0.12
	face.cyl(0.11, 0.11, 0.02, 16, CozyMesh.at(Vector3(0, second, 0)), white)
	fittings.cyl(0.13, 0.12, 0.05, 16, CozyMesh.at(Vector3(0, second + 0.035, 0)), gold)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		var out := Vector3(cos(a), 0, sin(a))
		fittings.rod(out * (radius - 0.02) + Vector3.UP * rim, out * 0.12 + Vector3.UP * (second + 0.03), 0.012, 6, gold)


## The dish turned to face `dir` (in the collector's parent frame's
## terms, world directions when the collector is unturned): the fork
## about the upright to its bearing, the dish about the axle to its
## height.
func point_at(dir: Vector3) -> void:
	var local := (global_basis.inverse() * dir).normalized() if is_inside_tree() else dir.normalized()
	var flat := Vector2(local.x, local.z)
	_yoke.rotation = Vector3(0, atan2(local.x, local.z) if flat.length() > 1e-4 else 0.0, 0)
	var height := asin(clampf(local.y, -1.0, 1.0))
	# The dish's axis is its +y: swung forward (+z) from straight up.
	_dish.rotation = Vector3(PI * 0.5 - height, 0, 0)


## The middle of the dish's mirror, where the sun must reach.
func centre() -> Vector3:
	return _dish.to_global(Vector3(0, VERTEX + 0.2, 0))
