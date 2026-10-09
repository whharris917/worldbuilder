class_name FloorTile
extends StaticBody3D
## A square of plank floor SIZE metres across that the player builds
## (Workshop) to give a level place to stand pieces on, on legs down to
## the ground. It stands wherever it was put, turned about the upright;
## one put close beside another settles flush against its edge, level
## with it, so floors join.

const SIZE := 2.0
const THICK := 0.1

var workshop: Workshop
var top := 0.0


## A tile with the middle of its top at `at`, turned `yaw`.
func _init(shop: Workshop, at: Vector3, yaw: float) -> void:
	workshop = shop
	top = at.y
	name = "FloorTile"
	position = at
	rotation.y = yaw
	collision_layer = 1


func _ready() -> void:
	var half := SIZE * 0.5
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SIZE, THICK, SIZE)
	shape.shape = box
	shape.position.y = -THICK * 0.5
	add_child(shape)
	var boards := 4
	var width := SIZE / boards
	for n in boards:
		var board := BoxMesh.new()
		board.size = Vector3(SIZE - 0.01, 0.035, width - 0.014)
		board.material = workshop.wood
		_view(board, Vector3(0, -0.0175, -half + (n + 0.5) * width))
	for side: float in [-1.0, 1.0]:
		var bearer := BoxMesh.new()
		bearer.size = Vector3(0.1, THICK - 0.035, SIZE - 0.02)
		bearer.material = workshop.timber
		_view(bearer, Vector3(side * (half - 0.12), -0.035 - (THICK - 0.035) * 0.5, 0))
	var island := workshop.island
	for u: float in [-1.0, 1.0]:
		for v: float in [-1.0, 1.0]:
			var at := Vector3(u * (half - 0.12), 0.0, v * (half - 0.12))
			var foot := to_global(at)
			var drop := top - THICK - island.height(foot.x, foot.z)
			if drop < 0.03:
				continue
			var leg := BoxMesh.new()
			leg.size = Vector3(0.1, drop + 0.1, 0.1)
			leg.material = workshop.timber
			_view(leg, at + Vector3(0, -THICK - drop * 0.5 + 0.05, 0))


func _view(mesh: Mesh, at: Vector3) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	add_child(m)


## The middles of the places beside it, where a tile put close settles:
## off each edge, level with it.
func beside() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for d: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		out.append(global_transform * (d * SIZE))
	return out
