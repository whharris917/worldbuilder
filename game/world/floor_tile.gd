class_name FloorTile
extends StaticBody3D
## A square of plank floor SIZE metres across that the player builds
## (Workshop) to give a level place to stand pieces on, on legs down to
## the ground. Tiles lie on a world grid SIZE metres apart, so neighbours
## join into one floor, their tops at whole steps of STEP; each of its four
## boards is one row of places for pieces (Workshop.SLOT).

const SIZE := 2.0
const STEP := 0.25
const THICK := 0.1

var workshop: Workshop
var cell := Vector2i.ZERO
var top := 0.0


## The tile in grid `at`, its top at `top_y`.
func _init(shop: Workshop, at: Vector2i, top_y: float) -> void:
	workshop = shop
	cell = at
	top = top_y
	name = "FloorTile"
	position = centre(at, top_y)
	collision_layer = 1


## The middle of the top of the tile in grid `at`, at height `y`.
static func centre(at: Vector2i, y: float) -> Vector3:
	return Vector3((at.x + 0.5) * SIZE, y, (at.y + 0.5) * SIZE)


## The grid square holding the point `p`.
static func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / SIZE), floori(p.z / SIZE))


func _ready() -> void:
	var half := SIZE * 0.5
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SIZE, THICK, SIZE)
	shape.shape = box
	shape.position.y = -THICK * 0.5
	add_child(shape)
	var boards := int(SIZE / Workshop.SLOT)
	for n in boards:
		var board := BoxMesh.new()
		board.size = Vector3(SIZE - 0.01, 0.035, Workshop.SLOT - 0.014)
		board.material = workshop.wood
		_view(board, Vector3(0, -0.0175, -half + (n + 0.5) * Workshop.SLOT))
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
