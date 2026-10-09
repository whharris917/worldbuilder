class_name Workbench
extends StaticBody3D
## A workbench for light-beam circuits, set down by the player on the
## cozy island (Workshop): a square wooden deck SIZE metres across, a
## wooden frame standing at its corners as tall as the space it gives,
## legs down to the ground where the ground falls away under it, and a
## ramp up to the middle of each side that stands higher than a step. Its
## space is a grid of cells PITCH apart, CELLS a side and LEVELS high; a
## piece (an aimed lumen part or optic element) stands in a cell on a
## brass rod down to the deck or to the piece below it.
##
## Its frame: the origin at the middle of the deck's top, y up; cell
## (i, j, k) at x = (i - (CELLS - 1) / 2) * PITCH, z likewise from j,
## and y = k * PITCH, k from 1 to LEVELS.

const SIZE := 6.0
const PITCH := 0.5
const CELLS := 12
const LEVELS := 6
const DECK := 0.1
const FRAME_H := 3.4
const NO_CELL := Vector3i(-1, -1, -1)
const RAMP_FROM := 0.12                 # m the deck stands over the ground beside it before a ramp is wanted
const RAMP_ANGLE := 28.0

var workshop: Workshop
var pieces := {}                        # Vector3i -> Node3D (LumenPart or OpticElement)
var cells := {}                         # Node3D -> Vector3i
var editing := false

var _stands := Node3D.new()
var _label: Label3D


## A bench whose deck top is at `at`, turned `yaw` about the upright.
func _init(shop: Workshop, at: Vector3, yaw: float) -> void:
	workshop = shop
	name = "Workbench"
	position = at
	rotation.y = yaw
	collision_layer = 1
	set_meta("view", self)
	add_child(_stands)


func _ready() -> void:
	_build()


## The deck, its legs, the frame, and the label.
func _build() -> void:
	var wood := workshop.wood
	var island := workshop.island
	var deck := BoxMesh.new()
	deck.size = Vector3(SIZE + 0.3, DECK - 0.03, SIZE + 0.3)
	deck.material = workshop.timber
	_solid(deck, Vector3(0, -DECK * 0.5 - 0.015, 0), Vector3(SIZE + 0.3, DECK, SIZE + 0.3))
	# The boards, one to each row of cells, so the grid shows in them.
	for n in CELLS:
		var board := BoxMesh.new()
		board.size = Vector3(SIZE + 0.3, 0.03, PITCH - 0.018)
		board.material = wood
		_view(board, Vector3(0, -0.015, (n - (CELLS - 1) * 0.5) * PITCH))
	# Battens round the deck's edge, a little proud of it.
	for side in 4:
		var along := side < 2
		var batten := BoxMesh.new()
		batten.size = Vector3(SIZE + 0.4, 0.05, 0.08) if along else Vector3(0.08, 0.05, SIZE + 0.4)
		batten.material = workshop.timber
		var s := (SIZE * 0.5 + 0.17) * (1.0 if side % 2 == 0 else -1.0)
		_view(batten, Vector3(0, 0.0, s) if along else Vector3(s, 0.0, 0))
	# Legs wherever the ground lies below the deck.
	var half := SIZE * 0.5
	for u: float in [-half, 0.0, half]:
		for v: float in [-half, 0.0, half]:
			var foot := to_global(Vector3(u, 0, v))
			var drop := global_position.y - DECK - island.height(foot.x, foot.z)
			if drop < 0.03:
				continue
			var leg := BoxMesh.new()
			leg.size = Vector3(0.14, drop + 0.1, 0.14)
			leg.material = workshop.timber
			_view(leg, Vector3(u, -DECK - drop * 0.5 + 0.05, v))
	# A ramp up to the deck at the middle of each side standing higher
	# than a step.
	for side in 4:
		var out := Vector3([0.0, 0.0, 1.0, -1.0][side], 0.0, [1.0, -1.0, 0.0, 0.0][side])
		var edge := out * (half + 0.2)
		var foot := to_global(edge + out * 0.5)
		var rise := global_position.y - island.height(foot.x, foot.z)
		if rise < RAMP_FROM:
			continue
		var run := rise / tan(deg_to_rad(RAMP_ANGLE))
		var length := sqrt(run * run + rise * rise)
		var ramp := BoxMesh.new()
		ramp.size = Vector3(1.4, 0.06, length + 0.1)
		ramp.material = wood
		var tilt := atan2(rise, run)
		var turn := Basis(Vector3.UP, atan2(out.x, out.z)) * Basis(Vector3.RIGHT, tilt)
		var mid := edge + out * run * 0.5 + Vector3(0, -rise * 0.5 - 0.03, 0)
		var m := _view(ramp, mid)
		m.basis = turn
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = ramp.size
		shape.shape = box
		shape.transform = Transform3D(turn, mid)
		add_child(shape)
	# The frame: a post at each corner and rails along the top.
	for u: float in [-half, half]:
		for v: float in [-half, half]:
			var post := BoxMesh.new()
			post.size = Vector3(0.1, FRAME_H, 0.1)
			post.material = workshop.timber
			_solid(post, Vector3(u, FRAME_H * 0.5, v), post.size)
			var cap := SphereMesh.new()
			cap.radius = 0.07
			cap.height = 0.14
			cap.material = workshop.brass
			_view(cap, Vector3(u, FRAME_H + 0.04, v))
	for side in 4:
		var along := side < 2
		var rail := BoxMesh.new()
		rail.size = Vector3(SIZE, 0.08, 0.08) if along else Vector3(0.08, 0.08, SIZE)
		rail.material = workshop.timber
		var s := half * (1.0 if side % 2 == 0 else -1.0)
		_view(rail, Vector3(0, FRAME_H - 0.04, s) if along else Vector3(s, FRAME_H - 0.04, 0))
	_label = Label3D.new()
	_label.text = Workshop.BENCH_NOTE
	_label.font_size = 26
	_label.pixel_size = 0.0022
	_label.outline_size = 8
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = Vector3(0, 1.0, 0)
	_label.width = 520.0
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.visible = false
	add_child(_label)


func _view(mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	add_child(m)
	return m


func _solid(mesh: Mesh, at: Vector3, size: Vector3) -> void:
	_view(mesh, at)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	add_child(shape)


func show_label(on: bool) -> void:
	if _label != null:
		_label.visible = on and not editing


## ---- the grid ----------------------------------------------------------------

## The middle of `cell`, in the bench's frame.
static func cell_point(cell: Vector3i) -> Vector3:
	var mid := (CELLS - 1) * 0.5
	return Vector3((cell.x - mid) * PITCH, cell.y * PITCH, (cell.z - mid) * PITCH)


## The cell at level `level` nearest the point `local` (in the bench's
## frame), or NO_CELL off the bench.
static func cell_near(local: Vector3, level: int) -> Vector3i:
	var mid := (CELLS - 1) * 0.5
	var i := roundi(local.x / PITCH + mid)
	var j := roundi(local.z / PITCH + mid)
	if i < 0 or j < 0 or i >= CELLS or j >= CELLS or level < 1 or level > LEVELS:
		return NO_CELL
	return Vector3i(i, level, j)


## Whether `cell` is free, or held by `but` itself.
func is_free(cell: Vector3i, but: Node3D = null) -> bool:
	return cell != NO_CELL and (not pieces.has(cell) or pieces[cell] == but)


## ---- pieces ---------------------------------------------------------------------

## A piece of the catalogue's `key` (Workshop.PIECES) standing in `cell`,
## its head turned to `yaw` and `pitch` (in the bench's frame).
func add_piece(key: String, cell: Vector3i, yaw: float, pitch: float, delay := 2.0) -> Node3D:
	var at := cell_point(cell)
	var piece: Node3D
	match key:
		"mirror", "splitter", "lens":
			var ek: OpticElement.Kind = {"mirror": OpticElement.Kind.MIRROR, "splitter": OpticElement.Kind.SPLITTER,
					"lens": OpticElement.Kind.LENS}[key]
			var e := OpticElement.new(ek, at, 0.0, workshop.wood, workshop.brass, workshop.silver, workshop.glass, false)
			e.collision_layer = 4
			piece = e
		_:
			var kind: LumenPart.Kind = Workshop.KINDS[key]
			var look := {"post": false, "aimed": true, "catch": 0.22}
			look.merge(Workshop.LOOKS.get(key, {}))
			if look.has("metal"):
				look["metal"] = workshop.get(look["metal"])
			var p := LumenPart.new(kind, "", at, at.y, workshop.wood, workshop.brass,
					delay if kind == LumenPart.Kind.TON or kind == LumenPart.Kind.TOF else 0.0, look)
			p.collision_layer = 4
			piece = p
	piece.set_meta("piece", key)
	add_child(piece)
	piece.call("aim", yaw, pitch)
	pieces[cell] = piece
	cells[piece] = cell
	rebuild_stands()
	workshop.added(piece)
	return piece


func remove_piece(piece: Node3D) -> void:
	if not cells.has(piece):
		return
	pieces.erase(cells[piece])
	cells.erase(piece)
	workshop.removed(piece)
	piece.queue_free()
	rebuild_stands()


## `piece` moved to `cell`, which must be free.
func move_piece(piece: Node3D, cell: Vector3i) -> void:
	pieces.erase(cells[piece])
	pieces[cell] = piece
	cells[piece] = cell
	piece.position = cell_point(cell)
	rebuild_stands()


## Each piece's rod, from the deck or the top of the piece below it up to
## its head, with a little brass cradle under the head and a foot on the
## deck.
func rebuild_stands() -> void:
	for c in _stands.get_children():
		c.queue_free()
	for cell: Vector3i in pieces:
		var piece: Node3D = pieces[cell]
		var glass := piece is OpticElement
		var top := cell_point(cell).y - (0.2 if glass else 0.13)
		var bottom := 0.0
		for k in range(cell.y - 1, 0, -1):
			if pieces.has(Vector3i(cell.x, k, cell.z)):
				bottom = cell_point(Vector3i(cell.x, k, cell.z)).y + 0.2
				break
		var base := cell_point(Vector3i(cell.x, 0, cell.z))
		if top - bottom > 0.01:
			var rod := CylinderMesh.new()
			rod.top_radius = 0.016
			rod.bottom_radius = 0.02
			rod.height = top - bottom
			rod.radial_segments = 8
			rod.rings = 1
			rod.material = workshop.brass
			_stand(rod, base + Vector3(0, (top + bottom) * 0.5, 0))
		if not glass:
			var cradle := CylinderMesh.new()
			cradle.top_radius = 0.075
			cradle.bottom_radius = 0.04
			cradle.height = 0.04
			cradle.radial_segments = 12
			cradle.rings = 1
			cradle.material = workshop.brass
			_stand(cradle, base + Vector3(0, top, 0))
		if bottom == 0.0:
			var foot := CylinderMesh.new()
			foot.top_radius = 0.05
			foot.bottom_radius = 0.08
			foot.height = 0.03
			foot.radial_segments = 12
			foot.rings = 1
			foot.material = workshop.brass
			_stand(foot, base + Vector3(0, 0.015, 0))


func _stand(mesh: Mesh, at: Vector3) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	_stands.add_child(m)


## ---- keeping it --------------------------------------------------------------

func to_data() -> Dictionary:
	var list: Array = []
	for cell: Vector3i in pieces:
		var piece: Node3D = pieces[cell]
		var entry := {"kind": piece.get_meta("piece"), "cell": [cell.x, cell.y, cell.z],
				"aim": [float(piece.get("yaw")), float(piece.get("pitch"))]}
		if piece is LumenPart:
			var p := piece as LumenPart
			if p.kind == LumenPart.Kind.TON or p.kind == LumenPart.Kind.TOF:
				entry["delay"] = p.delay
			if p.kind == LumenPart.Kind.LANTERN:
				entry["on"] = p.condition
		list.append(entry)
	return {"at": [position.x, position.y, position.z], "yaw": rotation.y, "pieces": list}


## The pieces of `data` (as `to_data` writes it) set up on the bench.
func load_pieces(data: Dictionary) -> void:
	var list: Variant = data.get("pieces")
	if not list is Array:
		return
	for entry: Variant in list:
		if not entry is Dictionary:
			continue
		var d := entry as Dictionary
		var key := str(d.get("kind", ""))
		var c: Variant = d.get("cell")
		var a: Variant = d.get("aim")
		if not Workshop.KEYS.has(key) or not c is Array or (c as Array).size() < 3:
			continue
		var cell := Vector3i(int(c[0]), int(c[1]), int(c[2]))
		if not is_free(cell) or cell_near(cell_point(cell), cell.y) != cell:
			continue
		var aim := [0.0, 0.0]
		if a is Array and (a as Array).size() >= 2:
			aim = [float(a[0]), float(a[1])]
		var piece := add_piece(key, cell, aim[0], aim[1], float(d.get("delay", 2.0)))
		if piece is LumenPart and bool(d.get("on", false)):
			(piece as LumenPart).condition = true
