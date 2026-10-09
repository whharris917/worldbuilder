class_name Workshop
extends Node3D
## The player's own light-beam circuits on the cozy island: workbenches
## (Workbench) they set down anywhere on open ground and build on with
## the same pieces the works and the exposition use, aimed as at the beam
## range.
##
## Walking about: B brings out a workbench, standing on the ground ahead
## of the player and turning with them; a left click sets it down where
## it shows pale (red where the ground is too steep, under water, or
## something stands in the way), a right click, Esc or B puts it away.
## E on a bench works at it (BenchEditor: the view flies out over it and
## the mouse is freed to build with); E on a lantern opens or closes its
## shutter; E on any other piece but a radiometer looks through it to aim
## it (BenchScope).
##
## The light on every bench is one (BenchLight): a beam may cross from
## one bench to another. A radiometer rings its bell when its vanes start.
## The benches and their pieces are kept in SAVE_PATH.

const SAVE_PATH := "user://cozy_island_benches.json"
const AHEAD := 1.2                      # m from the player to the near edge of a bench being set down
const STEEP := 0.7                      # m the ground may fall across a bench's footprint

## The pieces, in the tray's order: key, name.
const PIECES := [["lantern", "Lantern"], ["and", "AND"], ["or", "OR"], ["not", "NOT"], ["latch", "Latch"],
		["on_delay", "Hourglass"], ["off_delay", "Afterglow"], ["rise", "Rising spark"], ["fall", "Falling spark"],
		["radiometer", "Radiometer"], ["mirror", "Mirror"], ["splitter", "Splitter"], ["lens", "Lens"]]
const KEYS := ["lantern", "and", "or", "not", "latch", "on_delay", "off_delay", "rise", "fall", "radiometer",
		"mirror", "splitter", "lens"]
const KINDS := {"lantern": LumenPart.Kind.LANTERN, "and": LumenPart.Kind.AND, "or": LumenPart.Kind.OR,
		"not": LumenPart.Kind.NOT, "latch": LumenPart.Kind.LATCH, "on_delay": LumenPart.Kind.TON,
		"off_delay": LumenPart.Kind.TOF, "rise": LumenPart.Kind.RISE, "fall": LumenPart.Kind.FALL,
		"radiometer": LumenPart.Kind.RADIOMETER}
## Each kind's cut and setting (LumenPart's `look`); a metal by name.
const LOOKS := {
	"lantern": {"lamp": "drum", "metal": "brass"},
	"and": {"design": "gem", "setting": "prongs"},
	"or": {"design": "orb", "setting": "cage", "metal": "silver"},
	"not": {"design": "obelisk", "setting": "collar", "metal": "copper"},
	"off_delay": {"design": "cluster", "setting": "cup", "metal": "copper"},
}
const GLASS_COLOUR := Color(0.85, 0.9, 1.0)
const DELAYS := [1.0, 2.0, 3.0, 5.0, 8.0, 13.0]

## What a piece and a bench tell the player looking at them. Drafts.
const BENCH_NOTE := "Workbench\nE: work at it."
const NOTES := {
	"lantern": "Lantern\nE: open or close its shutter.",
	"and": "AND crystal\nShines while every beam striking it is lit.",
	"or": "OR crystal\nShines while any beam striking it is lit.",
	"not": "NOT crystal\nShines while no lit beam strikes it.",
	"latch": "Latch crystal\nA lit beam striking its left side lights it, one striking its right side puts it out; between, it remembers.",
	"on_delay": "Hourglass, %s s\nShines once a beam striking it has stayed lit that long.",
	"off_delay": "Afterglow crystal, %s s\nShines while a beam striking it is lit, and that long after.",
	"rise": "Rising spark\nOne flash when a beam striking it lights.",
	"fall": "Falling spark\nOne flash when a beam striking it goes dark.",
	"radiometer": "Radiometer\nIts vanes spin in the light; a bell rings as they start.",
	"mirror": "Mirror\nTurns a beam off its silvered face; a little of its reach is lost.",
	"splitter": "Splitter\nSends a beam on through and aside as well, each with half its reach.",
	"lens": "Lens\nA beam passing through it reaches twice as far again.",
}
const AIM_NOTE := "\nE: look through it to aim it."

var island: CozyIsland
var benches: Array[Workbench] = []
var light := BenchLight.new()
var editor: BenchEditor
var scope: BenchScope
var wood: StandardMaterial3D              # the deck's boards
var timber: StandardMaterial3D            # the bench's frame
var brass: StandardMaterial3D
var copper: StandardMaterial3D
var silver: StandardMaterial3D
var glass: StandardMaterial3D

var _bells := {}                        # radiometer -> [was spinning, speaker]
var _carrying := false
var _ghost := Node3D.new()
var _ghost_mat := StandardMaterial3D.new()
var _ghost_ok := false
var _ghost_top := 0.0
var _ui := CanvasLayer.new()
var _hint := Label.new()
var _save_in := -1.0


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
	editor = BenchEditor.new(self)
	add_child(editor)
	scope = BenchScope.new(self)
	add_child(scope)
	_build_ghost()
	_ui.layer = 5
	add_child(_ui)
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.97, 0.93, 0.82))
	_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position.y -= 60.0
	_hint.visible = false
	_ui.add_child(_hint)
	if not MouseMode.probe:
		_load()


func _exit_tree() -> void:
	if _save_in >= 0.0:
		_save()


## ---- benches -------------------------------------------------------------------

## A bench with its deck's top at `at`, turned `yaw`.
func add_bench(at: Vector3, yaw: float) -> Workbench:
	var b := Workbench.new(self, at, yaw)
	add_child(b)
	benches.append(b)
	_clear_ground()
	return b


func remove_bench(b: Workbench) -> void:
	for piece: Node3D in b.cells.keys():
		removed(piece)
	benches.erase(b)
	b.queue_free()
	_clear_ground()
	changed()


## No flowers growing up through a bench.
func _clear_ground() -> void:
	var areas: Array = []
	for b in benches:
		areas.append([b.global_transform, Workbench.SIZE * 0.5 + 0.3])
	island.clear_ground(areas)


## Called by a bench for each piece it gains: lit by the light, labelled,
## a radiometer given its bell.
func added(piece: Node3D) -> void:
	light.add(piece)
	relabel(piece)
	if piece is LumenPart and (piece as LumenPart).kind == LumenPart.Kind.RADIOMETER:
		var bell := AudioStreamPlayer3D.new()
		bell.stream = load("res://audio/chime.wav") if DisplayServer.get_name() != "headless" else null
		bell.unit_size = 6.0
		piece.add_child(bell)
		_bells[piece] = [false, bell]


func removed(piece: Node3D) -> void:
	light.remove(piece)
	_bells.erase(piece)
	if scope.held == piece:
		scope.leave()


func relabel(piece: Node3D) -> void:
	var key: String = piece.get_meta("piece", "")
	var text: String = NOTES.get(key, "")
	if piece is LumenPart:
		var p := piece as LumenPart
		if p.kind == LumenPart.Kind.TON or p.kind == LumenPart.Kind.TOF:
			text = text % ("%d" % roundi(p.delay) if is_equal_approx(p.delay, roundf(p.delay)) else "%.1f" % p.delay)
		if p.kind != LumenPart.Kind.LANTERN and p.kind != LumenPart.Kind.RADIOMETER:
			text += AIM_NOTE
		p.relabel(text)
	elif piece is OpticElement:
		(piece as OpticElement).relabel(text + AIM_NOTE)


func is_piece(n: Object) -> bool:
	return n is Node3D and (n as Node3D).has_meta("piece") and (n as Node).get_parent() is Workbench


func all_pieces() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for b in benches:
		for piece: Node3D in b.cells:
			out.append(piece)
	return out


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


## A lantern's shutter opened or closed.
func toggle(lantern: LumenPart) -> void:
	lantern.condition = not lantern.condition
	changed()


## ---- walking about -----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var player := island.player
	if editor.mode != BenchEditor.Mode.OFF or scope.held != null:
		return
	if player.look_held_by != null or player.input_locked:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_B:
		_carry(not _carrying)
		get_viewport().set_input_as_handled()
		return
	if _carrying:
		var click := event as InputEventMouseButton
		if click != null and click.pressed:
			if click.button_index == MOUSE_BUTTON_LEFT and _ghost_ok:
				add_bench(_ghost.global_position, _ghost.rotation.y)
				changed()
				_carry(false)
			elif click.button_index == MOUSE_BUTTON_RIGHT:
				_carry(false)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_cancel"):
			_carry(false)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		var v := player.look_view()
		if v is Workbench:
			editor.begin(v as Workbench)
		elif is_piece(v):
			if v is LumenPart and (v as LumenPart).kind == LumenPart.Kind.LANTERN:
				toggle(v as LumenPart)
			elif sends(v):
				scope.enter(v, player.camera)
			else:
				return
		else:
			return
		get_viewport().set_input_as_handled()


func _carry(on: bool) -> void:
	_carrying = on
	_ghost.visible = on
	_hint.visible = on


func _build_ghost() -> void:
	_ghost.top_level = true
	_ghost.visible = false
	add_child(_ghost)
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost_mat.no_depth_test = false
	var half := Workbench.SIZE * 0.5
	var deck := BoxMesh.new()
	deck.size = Vector3(Workbench.SIZE + 0.3, Workbench.DECK, Workbench.SIZE + 0.3)
	deck.material = _ghost_mat
	var dv := MeshInstance3D.new()
	dv.mesh = deck
	dv.position.y = -Workbench.DECK * 0.5
	_ghost.add_child(dv)
	for u: float in [-half, half]:
		for v: float in [-half, half]:
			var post := BoxMesh.new()
			post.size = Vector3(0.1, Workbench.FRAME_H, 0.1)
			post.material = _ghost_mat
			var pv := MeshInstance3D.new()
			pv.mesh = post
			pv.position = Vector3(u, Workbench.FRAME_H * 0.5, v)
			_ghost.add_child(pv)


## The bench being set down kept ahead of the player, and whether it can
## stand there.
func _place_ghost() -> void:
	var player := island.player
	var yaw := player.global_rotation.y
	var ahead := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var centre := player.global_position + ahead * (AHEAD + Workbench.SIZE * 0.5 + 0.15)
	var basis := Basis(Vector3.UP, yaw)
	var lo := INF
	var hi := -INF
	var half := Workbench.SIZE * 0.5
	for a in 5:
		for b in 5:
			var p := centre + basis * Vector3(-half + half * 0.5 * a, 0.0, -half + half * 0.5 * b)
			var h := island.height(p.x, p.z)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	_ghost_top = hi + 0.06
	_ghost.global_transform = Transform3D(basis, Vector3(centre.x, _ghost_top, centre.z))
	var reason := ""
	if lo < 0.12:
		reason = "Not in the water."
	elif hi - lo > STEEP:
		reason = "The ground is too steep here."
	else:
		var box := BoxShape3D.new()
		box.size = Vector3(Workbench.SIZE + 0.3, Workbench.FRAME_H - 0.2, Workbench.SIZE + 0.3)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = box
		q.transform = Transform3D(basis, Vector3(centre.x, _ghost_top + 0.15 + box.size.y * 0.5, centre.z))
		q.collision_mask = 1
		q.exclude = [player.get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
			reason = "Something stands in the way."
	_ghost_ok = reason == ""
	_ghost_mat.albedo_color = Color(0.75, 1.0, 0.8, 0.35) if _ghost_ok else Color(1.0, 0.35, 0.3, 0.35)
	# Drafts.
	_hint.text = ("Left click: set the workbench down here     Right click or B: put it away" if _ghost_ok
			else reason + "     Right click or B: put it away")


## ---- each step --------------------------------------------------------------

func _physics_process(dt: float) -> void:
	light.step(dt)
	for r: LumenPart in _bells:
		var b: Array = _bells[r]
		if r.powered and not bool(b[0]):
			BeachSite._play(b[1] as AudioStreamPlayer3D, 1.0)
		b[0] = r.powered


func _process(delta: float) -> void:
	if _carrying:
		if island.player.look_held_by != null or island.player.input_locked:
			_carry(false)
		else:
			_place_ghost()
	if _save_in >= 0.0:
		_save_in -= delta
		if _save_in < 0.0:
			_save()


## ---- keeping the benches ---------------------------------------------------

## Something changed: written half a second after the last change.
func changed() -> void:
	if not MouseMode.probe:
		_save_in = 0.5


func _save() -> void:
	_save_in = -1.0
	if MouseMode.probe:
		return
	var list: Array = []
	for b in benches:
		list.append(b.to_data())
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"benches": list}))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not (parsed as Dictionary).get("benches") is Array:
		return
	for entry: Variant in (parsed as Dictionary)["benches"]:
		if not entry is Dictionary:
			continue
		var d := entry as Dictionary
		var at: Variant = d.get("at")
		if not at is Array or (at as Array).size() < 3:
			continue
		var b := add_bench(Vector3(float(at[0]), float(at[1]), float(at[2])), float(d.get("yaw", 0.0)))
		b.load_pieces(d)
