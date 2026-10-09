class_name Workshop
extends Node3D
## The player's own light-beam circuits on the cozy island, built in
## first person from the pieces the works and the exposition use: floor
## tiles (FloorTile) to make level ground, and the parts and glass that
## stand on it.
##
## B starts and stops building. While building, a tray along the bottom
## shows what is in hand (ITEMS: the number keys, or the wheel, choose)
## and a pale copy of it stands where it would go, at what the crosshair
## is on within REACH metres; a left click puts it there. A floor tile
## goes in the grid square under the crosshair, its top a step above the
## highest ground under it, or level with the highest floor beside it
## where that clears the ground; looking at the edge or side of a tile
## puts the next one beside it at the same height. A piece stands HEAD metres
## over what the crosshair is on (a tile, at the middle of the nearest
## place on it, SLOT metres apart; the ground, where it is), or half a
## metre over a piece looked at, on a brass rod down to what is under
## it. The pale copy shows red where it cannot go. Shift and the wheel
## raise and lower it in steps; X takes away what the crosshair is on; T
## changes an hourglass's or afterglow's delay.
##
## At any time: E on a lantern opens or closes it; E on any other piece
## but a radiometer looks through it to aim it (BenchScope); a right click
## on one takes it up to aim, its beam following the crosshair (settling
## on any piece it is on) until a left click fixes it or a right click or
## Esc leaves it as it was.
##
## The light is one for every piece (BenchLight), travelling slowly. A
## radiometer rings its bell when its vanes start. Everything built is
## kept in SAVE_PATH.

const SAVE_PATH := "user://cozy_island_build.json"
const REACH := 8.0
const HEAD := 1.0                       # a piece's height over what it stands on, to begin
const SLOT := 0.5
const LIFT_STEP := 0.25
const MAX_TILE_RISE := 6.0              # a tile's top over the highest ground under it, at most
const CLEAR := 0.4                      # pieces' middles kept this far apart

## What can be built, in the tray's order: key, name. The first ten have
## the number keys 1 to 9 and 0.
const ITEMS := [["floor", "Floor"], ["lantern", "Lantern"], ["and", "AND"], ["or", "OR"], ["not", "NOT"],
		["latch", "Latch"], ["on_delay", "Hourglass"], ["off_delay", "Afterglow"], ["rise", "Rising spark"],
		["fall", "Falling spark"], ["radiometer", "Radiometer"], ["mirror", "Mirror"], ["splitter", "Splitter"],
		["lens", "Lens"]]
const KINDS := {"lantern": LumenPart.Kind.LANTERN, "and": LumenPart.Kind.AND, "or": LumenPart.Kind.OR,
		"not": LumenPart.Kind.NOT, "latch": LumenPart.Kind.LATCH, "on_delay": LumenPart.Kind.TON,
		"off_delay": LumenPart.Kind.TOF, "rise": LumenPart.Kind.RISE, "fall": LumenPart.Kind.FALL,
		"radiometer": LumenPart.Kind.RADIOMETER}
const GLASS := {"mirror": OpticElement.Kind.MIRROR, "splitter": OpticElement.Kind.SPLITTER,
		"lens": OpticElement.Kind.LENS}
## Each kind's cut and setting (LumenPart's `look`); a metal by name.
const LOOKS := {
	"lantern": {"lamp": "drum", "metal": "brass"},
	"and": {"design": "gem", "setting": "prongs"},
	"or": {"design": "orb", "setting": "cage", "metal": "silver"},
	"not": {"design": "obelisk", "setting": "collar", "metal": "copper"},
	"off_delay": {"design": "cluster", "setting": "cup", "metal": "copper"},
}
const FLOOR_COLOUR := Color(0.85, 0.7, 0.5)
const GLASS_COLOUR := Color(0.85, 0.9, 1.0)
const DELAYS := [1.0, 2.0, 3.0, 5.0, 8.0, 13.0]

## What a piece tells the player looking at it. Drafts.
const NOTES := {
	"lantern": "Lantern\nE: open or close its shutter.",
	"and": "AND crystal\nShines while every beam striking it is lit.",
	"or": "OR crystal\nShines while any beam striking it is lit.",
	"not": "NOT crystal\nShines while no lit beam strikes it.",
	"latch": "Latch crystal\nA lit beam striking its left side lights it, one striking its right side puts it out; between, it remembers.",
	"on_delay": "Hourglass, %s s\nShines once a beam striking it has stayed lit that long. T: change the time.",
	"off_delay": "Afterglow crystal, %s s\nShines while a beam striking it is lit, and that long after. T: change the time.",
	"rise": "Rising spark\nOne flash when a beam striking it lights.",
	"fall": "Falling spark\nOne flash when a beam striking it goes dark.",
	"radiometer": "Radiometer\nIts vanes spin in the light; a bell rings as they start.",
	"mirror": "Mirror\nTurns a beam off its silvered face; a little of its reach is lost.",
	"splitter": "Splitter\nSends a beam on through and aside as well, each with half its reach.",
	"lens": "Lens\nA beam passing through it reaches twice as far again.",
}
const AIM_NOTE := "\nE: look through it.  Right click: aim it at what you look at."

var island: CozyIsland
var light := BenchLight.new()
var scope: BenchScope
var tiles := {}                         # Vector2i -> FloorTile
var pieces: Array[Node3D] = []
var wood: StandardMaterial3D            # floor boards
var timber: StandardMaterial3D          # bearers and legs
var brass: StandardMaterial3D
var copper: StandardMaterial3D
var silver: StandardMaterial3D
var glass: StandardMaterial3D
var building := false
var item := 0
var lift := 0.0

var _bells := {}                        # radiometer -> [was spinning, speaker]
var _aiming: Node3D = null
var _aim_before := Vector2.ZERO
var _rods_due := false
var _save_in := -1.0
# Where the thing in hand would go, worked out each frame.
var _ok := false
var _why := ""
var _at := Vector3.ZERO                 # a piece's middle, or a tile's top middle
var _tile_cell := Vector2i.ZERO
var _ghost_tile := MeshInstance3D.new()
var _ghost_piece := MeshInstance3D.new()
var _ghost_mat := StandardMaterial3D.new()
var _ui := CanvasLayer.new()
var _cross := Label.new()
var _hint := Label.new()
var _tray := HBoxContainer.new()
var _tray_cells: Array[PanelContainer] = []
var _picked := StyleBoxFlat.new()
var _plain := StyleBoxFlat.new()


func _init(owner_island: CozyIsland) -> void:
	island = owner_island
	name = "Workshop"


func _ready() -> void:
	wood = island.surface("wood_floor", 0.6, Color(0.62, 0.5, 0.38), 0.85, Color(0.8, 0.62, 0.44))
	timber = island.surface("wood_floor", 0.6, Color(0.36, 0.27, 0.2), 0.85, Color(0.55, 0.4, 0.3))
	brass = island.surface("", 1.0, Color(0.62, 0.46, 0.2), 0.3, Color(0.92, 0.72, 0.34))
	brass.metallic = 0.85
	copper = island.surface("", 1.0, Color(0.62, 0.32, 0.2), 0.32, Color(0.9, 0.52, 0.34))
	copper.metallic = 0.9
	silver = island.surface("", 1.0, Color(0.78, 0.78, 0.8), 0.22, Color(0.88, 0.9, 0.95))
	silver.metallic = 0.9
	glass = StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.95, 1.0, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.8
	add_child(light)
	scope = BenchScope.new(self)
	add_child(scope)
	_build_ghosts()
	_build_ui()
	if not MouseMode.probe:
		_load()


func _exit_tree() -> void:
	if _save_in >= 0.0:
		_save()


## ---- building ----------------------------------------------------------------

## A floor tile in grid `cell` with its top at `top`.
func add_tile(cell: Vector2i, top: float) -> FloorTile:
	var t := FloorTile.new(self, cell, top)
	add_child(t)
	tiles[cell] = t
	_clear_ground()
	_rods_due = true
	return t


func remove_tile(t: FloorTile) -> void:
	tiles.erase(t.cell)
	t.queue_free()
	_clear_ground()
	_rods_due = true


## A piece of `key` with its middle at `at`, its head turned to `yaw`
## and `pitch`.
func add_piece(key: String, at: Vector3, yaw: float, pitch: float, delay := 2.0) -> Node3D:
	var piece: Node3D
	if GLASS.has(key):
		var e := OpticElement.new(GLASS[key], at, 0.0, timber, brass, silver, glass, false)
		e.collision_layer = 4
		piece = e
	else:
		var kind: LumenPart.Kind = KINDS[key]
		var look := {"post": false, "aimed": true, "catch": 0.22}
		look.merge(LOOKS.get(key, {}))
		if look.has("metal"):
			look["metal"] = get(look["metal"])
		var p := LumenPart.new(kind, "", at, at.y, timber, brass,
				delay if kind == LumenPart.Kind.TON or kind == LumenPart.Kind.TOF else 0.0, look)
		p.collision_layer = 4
		piece = p
	piece.set_meta("piece", key)
	add_child(piece)
	piece.call("aim", yaw, pitch)
	pieces.append(piece)
	light.add(piece)
	relabel(piece)
	if piece is LumenPart and (piece as LumenPart).kind == LumenPart.Kind.RADIOMETER:
		var bell := AudioStreamPlayer3D.new()
		bell.stream = load("res://audio/chime.wav") if DisplayServer.get_name() != "headless" else null
		bell.unit_size = 6.0
		piece.add_child(bell)
		_bells[piece] = [false, bell]
	_rods_due = true
	return piece


func remove_piece(piece: Node3D) -> void:
	if _aiming == piece:
		_end_aim()
	if scope.held == piece:
		scope.leave()
	pieces.erase(piece)
	light.remove(piece)
	_bells.erase(piece)
	piece.queue_free()
	_rods_due = true


func relabel(piece: Node3D) -> void:
	var key: String = piece.get_meta("piece", "")
	var text: String = NOTES.get(key, "")
	if piece is LumenPart:
		var p := piece as LumenPart
		if p.kind == LumenPart.Kind.TON or p.kind == LumenPart.Kind.TOF:
			text = text % ("%d" % roundi(p.delay))
		if p.kind == LumenPart.Kind.LANTERN:
			text += "  Right click: aim it."
		elif sends(p):
			text += AIM_NOTE
		p.relabel(text)
	elif piece is OpticElement:
		(piece as OpticElement).relabel(text + AIM_NOTE)


func is_piece(n: Object) -> bool:
	return n is Node3D and (n as Node3D).has_meta("piece") and pieces.has(n)


func all_pieces() -> Array[Node3D]:
	return pieces


## Whether a piece sends a beam of its own or turns one (all but the
## radiometer).
static func sends(piece: Node3D) -> bool:
	return not (piece is LumenPart and (piece as LumenPart).kind == LumenPart.Kind.RADIOMETER)


## `piece` turned so its beam goes to `point`: a part's lens toward it; a
## mirror's or splitter's face so the beam reaching it is sent there (or
## facing it when no beam reaches it); a lens's axis toward it.
func aim_at(piece: Node3D, point: Vector3) -> void:
	if piece is LumenPart:
		var p := piece as LumenPart
		# The lens swings with the head: aimed again from where it now is.
		for k in 4:
			p.aim_along(point - p.lens_point())
		return
	var e := piece as OpticElement
	if e.kind != OpticElement.Kind.LENS and light.arrivals.has(e):
		var arrival: Array = light.arrivals[e]
		var out := (point - (arrival[0] as Vector3)).normalized()
		e.aim_along((out - (arrival[1] as Vector3)).normalized())
	elif e.global_position.distance_to(point) > 0.01:
		e.aim_along(point - e.global_position)


func toggle(lantern: LumenPart) -> void:
	lantern.condition = not lantern.condition
	changed()


## No flowers growing up through a floor laid near the ground.
func _clear_ground() -> void:
	var areas: Array = []
	for t: FloorTile in tiles.values():
		var low := INF
		for u: float in [-1.0, 1.0]:
			for v: float in [-1.0, 1.0]:
				var c := t.position + Vector3(u, 0.0, v) * FloorTile.SIZE * 0.5
				low = minf(low, t.top - island.height(c.x, c.z))
		if low < 0.6:
			areas.append([Transform3D(Basis.IDENTITY, t.position), FloorTile.SIZE * 0.5 + 0.05])
	island.clear_ground(areas)


## Each piece's brass rod, down to whatever is under it: a piece, a
## floor, the ground.
func _place_rods() -> void:
	var space := get_world_3d().direct_space_state
	for piece in pieces:
		var glass_piece := piece is OpticElement
		var from := piece.global_position - Vector3(0, 0.24 if glass_piece else 0.16, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 12.0, 0), 1 | 4)
		q.exclude = [(piece as CollisionObject3D).get_rid(), island.player.get_rid()]
		var hit := space.intersect_ray(q)
		var bottom: float = (hit["position"] as Vector3).y if not hit.is_empty() else from.y - 12.0
		var top := piece.global_position.y - (0.2 if glass_piece else 0.13)
		var rod: MeshInstance3D = piece.get_meta("rod") if piece.has_meta("rod") else null
		if rod == null:
			rod = MeshInstance3D.new()
			piece.add_child(rod)
			piece.set_meta("rod", rod)
			if not glass_piece:
				var cradle := CylinderMesh.new()
				cradle.top_radius = 0.075
				cradle.bottom_radius = 0.04
				cradle.height = 0.04
				cradle.radial_segments = 12
				cradle.rings = 1
				cradle.material = brass
				var cv := MeshInstance3D.new()
				cv.mesh = cradle
				cv.position.y = -0.13
				piece.add_child(cv)
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.016
		mesh.bottom_radius = 0.022
		mesh.height = maxf(top - bottom, 0.02)
		mesh.radial_segments = 8
		mesh.rings = 1
		mesh.material = brass
		rod.mesh = mesh
		rod.global_position = Vector3(piece.global_position.x, (top + bottom) * 0.5, piece.global_position.z)
		rod.global_rotation = Vector3.ZERO


## ---- where the thing in hand goes -----------------------------------------

## What the crosshair is on, within reach: the ray's hit (empty if none).
func _look_hit(exclude: Array[RID] = []) -> Dictionary:
	var cam := island.player.camera
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (REACH + island.player.zoom_offset()), 1 | 4)
	var skip: Array[RID] = [island.player.get_rid()]
	skip.append_array(exclude)
	q.exclude = skip
	return get_world_3d().direct_space_state.intersect_ray(q)


func _held_key() -> String:
	return str(ITEMS[item][0])


## Where the thing in hand would go and whether it can; the pale copy
## put there.
func _find_place() -> void:
	var hit := _look_hit()
	_ok = false
	_why = ""
	_ghost_tile.visible = false
	_ghost_piece.visible = false
	if hit.is_empty():
		return
	var p: Vector3 = hit["position"]
	var n: Vector3 = hit["normal"]
	var c: Object = hit["collider"]
	if _held_key() == "floor":
		_find_tile(p, n, c)
	else:
		_find_spot(p, n, c)
	_ghost_mat.albedo_color = Color(_ghost_mat.albedo_color, 0.4) if _ok else Color(1.0, 0.25, 0.2, 0.4)


func _find_tile(p: Vector3, n: Vector3, c: Object) -> void:
	var cell := FloorTile.cell_of(p)
	var top := 0.0
	var base := false
	if c is FloorTile:
		# Beside the tile looked at: off the side it is looked at by, or
		# off its nearest edge when looked at from above, at its height.
		var t := c as FloorTile
		var d := Vector2(n.x, n.z)
		if n.y > 0.7:
			var off := Vector2(p.x - t.position.x, p.z - t.position.z)
			d = Vector2(signf(off.x), 0.0) if absf(off.x) > absf(off.y) else Vector2(0.0, signf(off.y))
		elif absf(d.x) > absf(d.y):
			d = Vector2(signf(d.x), 0.0)
		else:
			d = Vector2(0.0, signf(d.y))
		cell = t.cell + Vector2i(roundi(d.x), roundi(d.y))
		top = t.top
	else:
		base = true
	var lo := INF
	var hi := -INF
	var centre := FloorTile.centre(cell, 0.0)
	for a in 3:
		for b in 3:
			var q := centre + Vector3(a - 1.0, 0.0, b - 1.0) * FloorTile.SIZE * 0.5
			var h := island.height(q.x, q.z)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	if base:
		# A step over the ground, or level with the highest floor beside
		# it when that clears the ground too.
		top = ceilf((hi + 0.05) / FloorTile.STEP) * FloorTile.STEP
		var beside := -INF
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if tiles.has(cell + d):
				beside = maxf(beside, (tiles[cell + d] as FloorTile).top)
		if beside >= top:
			top = beside
	top += lift
	_tile_cell = cell
	_at = FloorTile.centre(cell, top)
	_ghost_tile.global_position = _at + Vector3(0, -FloorTile.THICK * 0.5, 0)
	_ghost_tile.visible = true
	_ghost_mat.albedo_color = FLOOR_COLOUR
	# Drafts.
	if tiles.has(cell):
		_why = "There is a floor there already."
	elif lo < 0.12:
		_why = "Not over the water."
	elif top < hi + 0.04:
		_why = "The ground stands higher than that; raise it with Shift and the wheel."
	elif top > hi + MAX_TILE_RISE:
		_why = "Too high above the ground."
	elif _blocked(_at + Vector3(0, 0.95, 0), Vector3(FloorTile.SIZE - 0.05, 1.8, FloorTile.SIZE - 0.05)):
		_why = "Something stands in the way."
	elif _under_player(_at):
		_why = "You are standing there."
	_ok = _why == ""


func _find_spot(p: Vector3, n: Vector3, c: Object) -> void:
	var support := p
	if is_piece(c):
		support = (c as Node3D).global_position
		_at = support + Vector3(0, 0.5 + lift, 0)
	elif n.y > 0.7:
		if c is FloorTile:
			support.x = (floorf(p.x / SLOT) + 0.5) * SLOT
			support.z = (floorf(p.z / SLOT) + 0.5) * SLOT
		_at = support + Vector3(0, HEAD + lift, 0)
	else:
		return
	var key := _held_key()
	_ghost_mat.albedo_color = LumenPart.COLOURS[KINDS[key]] if KINDS.has(key) else GLASS_COLOUR
	_ghost_piece.global_position = _at
	_ghost_piece.visible = true
	if _at.y < support.y + 0.3:
		_why = "Too low."
	elif _at.y > support.y + 4.0:
		_why = "Too high."
	else:
		for other in pieces:
			if other.global_position.distance_to(_at) < CLEAR:
				_why = "Too close to another piece."
				break
	if _why == "" and _blocked(_at, Vector3(0.3, 0.36, 0.3)):
		_why = "Something stands in the way."
	_ok = _why == ""


## Whether a box of `size` at `at` meets anything solid but the player.
func _blocked(at: Vector3, size: Vector3) -> bool:
	var box := BoxShape3D.new()
	box.size = size
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = Transform3D(Basis.IDENTITY, at)
	q.collision_mask = 1 | 4
	q.exclude = [island.player.get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Whether the player stands on the square a tile at `at` would cover,
## below its top and within their height of it.
func _under_player(at: Vector3) -> bool:
	var pp := island.player.global_position
	var half := FloorTile.SIZE * 0.5 + 0.35
	return absf(pp.x - at.x) < half and absf(pp.z - at.z) < half and pp.y < at.y and pp.y > at.y - 2.0


func _place() -> void:
	if not _ok:
		return
	if _held_key() == "floor":
		add_tile(_tile_cell, _at.y)
	else:
		# Set down facing the way the player looks, level.
		var f := -island.player.camera.global_basis.z
		add_piece(_held_key(), _at, atan2(-f.x, -f.z), 0.0)
	changed()


## ---- aiming by pointing ------------------------------------------------------

func _start_aim(piece: Node3D) -> void:
	_aiming = piece
	_aim_before = Vector2(float(piece.get("yaw")), float(piece.get("pitch")))
	light.held = piece


func _end_aim() -> void:
	_aiming = null
	light.held = null
	light.spot = Vector3.INF


## The piece in hand turned toward what the crosshair is on: the middle
## of a piece, or the point struck.
func _follow_aim() -> void:
	if not is_instance_valid(_aiming):
		_end_aim()
		return
	var hit := _look_hit([(_aiming as CollisionObject3D).get_rid()])
	var cam := island.player.camera
	var point := cam.global_position - cam.global_basis.z * 20.0
	if not hit.is_empty():
		point = hit["position"]
		if is_piece(hit["collider"]):
			point = (hit["collider"] as Node3D).global_position
	aim_at(_aiming, point)
	light.spot = point
	light.spot_size = 0.012 * cam.global_position.distance_to(point) + 0.02


## ---- input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var player := island.player
	if scope.held != null or player.input_locked or player.look_held_by != null:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not MouseMode.probe:
		return
	var key := event as InputEventKey
	var click := event as InputEventMouseButton
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_B:
		_set_building(not building)
	elif _aiming != null:
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_end_aim()
			changed()
		elif (click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT) \
				or event.is_action_pressed("ui_cancel"):
			_aiming.call("aim", _aim_before.x, _aim_before.y)
			_end_aim()
		else:
			return
	elif click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
		var hit := _look_hit()
		if hit.is_empty() or not is_piece(hit["collider"]) or not sends(hit["collider"]):
			return
		_start_aim(hit["collider"])
	elif event.is_action_pressed("interact"):
		var v := player.look_view()
		if not is_piece(v):
			return
		if v is LumenPart and (v as LumenPart).kind == LumenPart.Kind.LANTERN:
			toggle(v as LumenPart)
		elif sends(v):
			scope.enter(v, player.camera)
		else:
			return
	elif building:
		if not _build_input(event):
			return
	else:
		return
	get_viewport().set_input_as_handled()


## Input while building: whether it was taken.
func _build_input(event: InputEvent) -> bool:
	var click := event as InputEventMouseButton
	if click != null:
		if not click.pressed:
			return false
		match click.button_index:
			MOUSE_BUTTON_LEFT:
				_place()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				var up := click.button_index == MOUSE_BUTTON_WHEEL_UP
				if click.shift_pressed:
					lift = clampf(lift + (LIFT_STEP if up else -LIFT_STEP), -0.5, MAX_TILE_RISE)
				else:
					_pick((item + (-1 if up else 1) + ITEMS.size()) % ITEMS.size())
			_:
				return false
		return true
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	match key.physical_keycode:
		KEY_X:
			var hit := _look_hit()
			if hit.is_empty():
				return true
			var c: Object = hit["collider"]
			if is_piece(c):
				remove_piece(c as Node3D)
				changed()
			elif c is FloorTile:
				remove_tile(c as FloorTile)
				changed()
		KEY_T:
			var hit := _look_hit()
			if not hit.is_empty() and hit["collider"] is LumenPart and is_piece(hit["collider"]):
				var p := hit["collider"] as LumenPart
				if p.kind == LumenPart.Kind.TON or p.kind == LumenPart.Kind.TOF:
					var i := DELAYS.find(p.delay)
					p.delay = DELAYS[(i + 1) % DELAYS.size()]
					relabel(p)
					changed()
		_:
			if key.physical_keycode >= KEY_0 and key.physical_keycode <= KEY_9:
				_pick(9 if key.physical_keycode == KEY_0 else key.physical_keycode - KEY_1)
			else:
				return false
	return true


func _pick(i: int) -> void:
	if (str(ITEMS[i][0]) == "floor") != (_held_key() == "floor"):
		lift = 0.0
	item = i
	for k in _tray_cells.size():
		_tray_cells[k].add_theme_stylebox_override("panel", _picked if k == item else _plain)


func _set_building(on: bool) -> void:
	building = on
	_ghost_tile.visible = false
	_ghost_piece.visible = false


## ---- each step --------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if _rods_due:
		_rods_due = false
		_place_rods()
	light.step(dt)
	for r: LumenPart in _bells:
		var b: Array = _bells[r]
		if r.powered and not bool(b[0]):
			BeachSite._play(b[1] as AudioStreamPlayer3D, 1.0)
		b[0] = r.powered


func _process(delta: float) -> void:
	var player := island.player
	var free := scope.held == null and not player.input_locked and player.look_held_by == null
	if _aiming != null and free:
		_follow_aim()
	if building and free and _aiming == null:
		_find_place()
	else:
		_ghost_tile.visible = false
		_ghost_piece.visible = false
	_cross.visible = free and (building or _aiming != null)
	_tray.get_parent().visible = building and free
	_hint.visible = _cross.visible
	if _hint.visible:
		_hint.text = _hint_text()
	if _save_in >= 0.0:
		_save_in -= delta
		if _save_in < 0.0:
			_save()


## What the line over the tray says. Drafts.
func _hint_text() -> String:
	if _aiming != null:
		var text := "Look where its beam should go and click     Right click: leave it as it was"
		var hit := _look_hit([(_aiming as CollisionObject3D).get_rid()])
		if not hit.is_empty() and hit["collider"] is LumenPart and is_piece(hit["collider"]):
			var latch := hit["collider"] as LumenPart
			if latch.kind == LumenPart.Kind.LATCH:
				var right := latch.global_transform.basis * (Basis.from_euler(Vector3(latch.pitch, latch.yaw, 0.0)) * Vector3.RIGHT)
				var dir := (latch.global_position - _aiming.global_position).normalized()
				text = ("It strikes the latch from its left: it will light it.\n" if dir.dot(right) > 0.0
						else "It strikes the latch from its right: it will put it out.\n") + text
		return text
	var place := ("Click: place the %s" % str(ITEMS[item][1]).to_lower()) if _ok else _why
	if place == "":
		place = "Look at the ground, a floor or a piece"
	var height := ""
	if not is_zero_approx(lift):
		height = "     %+.2f m" % lift
	return "%s%s\nWheel: choose     Shift and wheel: higher, lower     X: take away     Right click a piece: aim it     B: stop building" % [place, height]


## ---- the pale copies and the screen --------------------------------------

func _build_ghosts() -> void:
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var slab := BoxMesh.new()
	slab.size = Vector3(FloorTile.SIZE, FloorTile.THICK, FloorTile.SIZE)
	slab.material = _ghost_mat
	_ghost_tile.mesh = slab
	var head := BoxMesh.new()
	head.size = Vector3(0.28, 0.34, 0.28)
	head.material = _ghost_mat
	_ghost_piece.mesh = head
	for g: MeshInstance3D in [_ghost_tile, _ghost_piece]:
		g.top_level = true
		g.visible = false
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(g)


func _build_ui() -> void:
	_ui.layer = 5
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 13
	root.theme = theme
	_ui.add_child(root)
	_cross.text = "+"
	_cross.add_theme_font_size_override("font_size", 22)
	_cross.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_cross.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_cross.add_theme_constant_override("outline_size", 4)
	_cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_cross.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cross.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.visible = false
	root.add_child(_cross)
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.6)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(5)
	frame.add_theme_stylebox_override("panel", style)
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	frame.grow_vertical = Control.GROW_DIRECTION_BEGIN
	frame.offset_bottom = -10.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	root.add_child(frame)
	_tray.add_theme_constant_override("separation", 3)
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_tray)
	_plain.bg_color = Color(1, 1, 1, 0.05)
	_plain.set_corner_radius_all(4)
	_plain.set_content_margin_all(4)
	_picked.bg_color = Color(1.0, 0.9, 0.6, 0.3)
	_picked.border_color = Color(1.0, 0.9, 0.6, 0.9)
	_picked.set_border_width_all(2)
	_picked.set_corner_radius_all(4)
	_picked.set_content_margin_all(4)
	for i in ITEMS.size():
		var key: String = ITEMS[i][0]
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(70, 46)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(col)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(28, 5)
		swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.color = FLOOR_COLOUR if key == "floor" else (LumenPart.COLOURS[KINDS[key]] if KINDS.has(key) else GLASS_COLOUR)
		col.add_child(swatch)
		var name_label := Label.new()
		name_label.text = str(ITEMS[i][1])
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name_label)
		var number := Label.new()
		number.text = str((i + 1) % 10) if i < 10 else " "
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		col.add_child(number)
		_tray.add_child(cell)
		_tray_cells.append(cell)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.97, 0.93, 0.82))
	_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.offset_bottom = -92.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	root.add_child(_hint)
	_pick(0)


## ---- keeping what is built -------------------------------------------------

## Something changed: written half a second after the last change.
func changed() -> void:
	if not MouseMode.probe:
		_save_in = 0.5


func _save() -> void:
	_save_in = -1.0
	if MouseMode.probe:
		return
	var floor_list: Array = []
	for t: FloorTile in tiles.values():
		floor_list.append([t.cell.x, t.cell.y, t.top])
	var list: Array = []
	for piece in pieces:
		var p := piece.global_position
		var entry := {"kind": piece.get_meta("piece"), "at": [p.x, p.y, p.z],
				"aim": [float(piece.get("yaw")), float(piece.get("pitch"))]}
		if piece is LumenPart:
			var part := piece as LumenPart
			if part.kind == LumenPart.Kind.TON or part.kind == LumenPart.Kind.TOF:
				entry["delay"] = part.delay
			if part.kind == LumenPart.Kind.LANTERN:
				entry["on"] = part.condition
		list.append(entry)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"floor": floor_list, "pieces": list}))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var data := parsed as Dictionary
	if data.get("floor") is Array:
		for f: Variant in data["floor"]:
			if f is Array and (f as Array).size() >= 3:
				var cell := Vector2i(int(f[0]), int(f[1]))
				if not tiles.has(cell):
					add_tile(cell, float(f[2]))
	if data.get("pieces") is Array:
		for entry: Variant in data["pieces"]:
			if not entry is Dictionary:
				continue
			var d := entry as Dictionary
			var key := str(d.get("kind", ""))
			var at: Variant = d.get("at")
			if not (KINDS.has(key) or GLASS.has(key)) or not at is Array or (at as Array).size() < 3:
				continue
			var aim := [0.0, 0.0]
			var a: Variant = d.get("aim")
			if a is Array and (a as Array).size() >= 2:
				aim = [float(a[0]), float(a[1])]
			var piece := add_piece(key, Vector3(float(at[0]), float(at[1]), float(at[2])), aim[0], aim[1],
					float(d.get("delay", 2.0)))
			if piece is LumenPart and bool(d.get("on", false)):
				(piece as LumenPart).condition = true
