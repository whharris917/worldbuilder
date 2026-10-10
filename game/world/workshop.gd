class_name Workshop
extends Node3D
## The player's own light-beam circuits on the cozy island, built in
## first person from the pieces the works and the exposition use: floor
## tiles (FloorTile) to make level ground, and the parts and glass that
## stand on it.
##
## Tab opens the building menu: the view stops turning and the game's
## own pointer (a brass arrow) appears, the world going on round it; it
## is the game's, not the engine's release of the mouse that Esc gives.
## The menu shows every piece as a picture of the piece itself, taken by
## a camera in the game when the world opens, grouped by kind (GROUPS),
## its name under it and what it does along the bottom as the pointer
## rests on it. A click picks one and goes back to the view with it in
## hand. Opening the menu, or a right click while something is in hand,
## puts it away. Empty hands stops building; Tab, Esc, a right click or a
## click outside the menu go back to the view. The number keys still
## pick the first ten pieces while building.
##
## While building, a see-through copy of what is in hand, whole, stands where it would go, at
## what the crosshair is on within REACH metres, turned square to the
## view; a left click puts it there. Nothing keeps to a grid. A floor
## tile is centred where the crosshair meets the ground, its top just
## clear of the highest ground under it; brought within SETTLE metres of
## the place beside a tile already down (or looked at on that tile's
## edge or side) it settles there, flush and level with it, so floors
## join. A piece stands HEAD metres over the point the crosshair is on
## (on a floor or the ground), or half a metre over a piece looked at,
## on a brass rod down to what is under it. The copy shows red where it
## cannot go. Shift and the wheel raise and lower it.
##
## Building or not: X takes away the piece or tile the crosshair is on;
## T changes an hourglass's or afterglow's delay.
##
## G on a piece or a tile, building or not, takes it up to move it: it
## leaves its place (a tile taking the pieces standing on it), its copy
## follows the crosshair as a new one would, and a left click sets it
## down there with its delay and shutter as they were, still aimed at
## its target, as are the pieces carried on a tile; and pieces aimed at
## what moved turn to follow it.
##
## A piece's target is what it was last aimed at (`links`): the piece,
## gate's bulb or point the crosshair settled on when it was aimed by a
## right click, or the piece its beam settled on in the lens view. So a
## lantern aimed across at a crystal with gates set in its path later
## keeps to the crystal when either moves. A piece never aimed that way
## (or turned freely in the lens view) is taken to be aimed at what its
## beam strikes first. Esc, B or
## choosing something else puts it back where it stood.
##
## A crosshair shows whenever the player looks about, gold when it is on
## a piece within REACH; the line above it then says what can be done.
## At any time: E on a lantern opens or closes it; E on any other piece
## but a radiometer looks through it to aim it (BenchScope); a right click
## on one takes it up to aim, its beam following the crosshair (settling
## on any piece it is on) until a left click fixes it or a right click or
## Esc leaves it as it was.
##
## Light gates (LightGate): an opening gate lets a beam through its ring
## while a lit beam strikes the bulb above it, a closing gate stops one
## while lit; a right click on one turns its ring to face what the
## crosshair is on. From these an AND is gates in a row along one beam,
## a NOT a closing gate.
##
## Push and pull lamps are lanterns whose beams are red and green; a
## track and cart (BeamCart) is placed as a piece, along the view, and
## its cart is driven by those beams striking the copper ball on its
## pole (see BenchLight).
##
## The shuttle (`build_demo`), built of these pieces in the meadow by
## the cabin the first time the island is visited (and again from the
## Island panel): a cart running to and fro on its track by itself. A
## gold beam crosses the track near each end; the cart's ball arriving
## blocks it and a NOT crystal behind it lights, setting or resetting a
## latch; the latch works an opening gate and a closing gate, through a
## splitter, on a push lamp's beam and a pull lamp's beam, which a second
## splitter at the track's end brings onto the track's line, so only one
## reaches the ball at a time; a lens past it gives back the reach the
## splitter takes, so the beams reach the track's far end. Once built it
## is the player's like any other build. A save with an older shuttle
## (DEMO_VERSION) has it built afresh.
##
## The light is one for every piece (BenchLight), travelling slowly. A
## radiometer rings its bell when its vanes start, and whirs as they spin. Everything built is
## kept in the world's own save (SAVE_PATH on the cozy island).
##
## It stands in any BuildWorld: the world gives it the player, the
## ground's height and the pieces' materials in its look.

const SAVE_PATH := "user://cozy_island_build.json"
const DEMO_AT := Vector3(21.3, 0.0, 108.9)   # the shuttle's track middle, in the meadow by the cabin
const DEMO_VERSION := 2                 # the shuttle for the 16 m track
const OLD_DEMO_AT := Vector3(16.7, 0.0, 106.1)   # where the first, short shuttle stood
const REACH := 8.0
const HEAD := 1.0                       # a piece's height over what it stands on, to begin
const LIFT_STEP := 0.1
const SETTLE := 1.0                     # m from the place beside a tile within which a tile settles there
const MAX_TILE_RISE := 6.0              # a tile's top over the highest ground under it, at most
const CLEAR := 0.4                      # pieces' middles kept this far apart

## What can be built, in the tray's order: key, name. The first ten have
## the number keys 1 to 9 and 0.
const ITEMS := [["floor", "Floor"], ["lantern", "Lantern"], ["gate", "Opening gate"],
		["closing_gate", "Closing gate"], ["and", "AND"], ["or", "OR"], ["not", "NOT"], ["latch", "Latch"],
		["on_delay", "Hourglass"], ["off_delay", "Afterglow"], ["rise", "Rising spark"], ["fall", "Falling spark"],
		["radiometer", "Radiometer"], ["mirror", "Mirror"], ["splitter", "Splitter"], ["lens", "Lens"],
		["push_lamp", "Push lamp"], ["pull_lamp", "Pull lamp"], ["track", "Track and cart"]]
const BEAMS := {"push_lamp": "push", "pull_lamp": "pull"}   # lamps sending force beams, by kind
const TRACK_COLOUR := Color(0.6, 0.45, 0.32)
const GATES := {"gate": false, "closing_gate": true}   # key -> closing
const GATE_COLOUR := Color(0.92, 0.72, 0.34)
const KINDS := {"lantern": LumenPart.Kind.LANTERN, "and": LumenPart.Kind.AND, "or": LumenPart.Kind.OR,
		"not": LumenPart.Kind.NOT, "latch": LumenPart.Kind.LATCH, "on_delay": LumenPart.Kind.TON,
		"off_delay": LumenPart.Kind.TOF, "rise": LumenPart.Kind.RISE, "fall": LumenPart.Kind.FALL,
		"radiometer": LumenPart.Kind.RADIOMETER, "push_lamp": LumenPart.Kind.LANTERN,
		"pull_lamp": LumenPart.Kind.LANTERN}
const GLASS := {"mirror": OpticElement.Kind.MIRROR, "splitter": OpticElement.Kind.SPLITTER,
		"lens": OpticElement.Kind.LENS}
## Each kind's cut and setting (LumenPart's `look`); a metal by name.
const LOOKS := {
	"lantern": {"lamp": "drum", "metal": "brass"},
	"and": {"design": "gem", "setting": "prongs"},
	"or": {"design": "orb", "setting": "cage", "metal": "silver"},
	"not": {"design": "obelisk", "setting": "collar", "metal": "copper"},
	"off_delay": {"design": "cluster", "setting": "cup", "metal": "copper"},
	"push_lamp": {"lamp": "drum", "metal": "copper", "colour": Color(1.0, 0.3, 0.22)},
	"pull_lamp": {"lamp": "drum", "metal": "silver", "colour": Color(0.35, 1.0, 0.45)},
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
	"gate": "Opening gate\nLets a beam through its ring while a lit beam strikes the bulb above it.",
	"closing_gate": "Closing gate\nStops a beam at its ring while a lit beam strikes the bulb above it.",
	"push_lamp": "Push lamp\nIts red beam on a cart's copper ball pushes the cart along its track, away from the lamp.\nE: open or close it.",
	"pull_lamp": "Pull lamp\nIts green beam on a cart's copper ball pulls the cart along its track, toward the lamp.\nE: open or close it.",
	"track": "Track and cart\nPush and pull beams on the copper ball drive the cart along the track.",
	"mirror": "Mirror\nTurns a beam off its silvered face; a little of its reach is lost.",
	"splitter": "Splitter\nSends a beam on through and aside as well, each with half its reach.",
	"lens": "Lens\nA beam passing through it reaches twice as far again.",
}
## The menu's groups, in order, and what each piece does, one line
## each. Drafts.
const GROUPS := [[["Floors", ["floor"]], ["Lamps", ["lantern", "push_lamp", "pull_lamp"]]],
		[["Crystals", ["and", "or", "not", "latch", "on_delay", "off_delay", "rise", "fall"]]],
		[["Gates", ["gate", "closing_gate"]], ["Glass", ["mirror", "splitter", "lens"]]],
		[["Machines", ["radiometer", "track"]]]]
const MENU_NOTES := {
	"floor": "boards two metres square, to build on.",
	"lantern": "sends a gold beam while its shutter is open.",
	"push_lamp": "its red beam pushes a cart's copper ball away from it.",
	"pull_lamp": "its green beam pulls a cart's copper ball toward it.",
	"and": "shines while every beam striking it is lit.",
	"or": "shines while any beam striking it is lit.",
	"not": "shines while no lit beam strikes it.",
	"latch": "lit by a beam on its left, put out by one on its right; remembers between.",
	"on_delay": "shines once a beam striking it has stayed lit a while.",
	"off_delay": "shines while a beam striking it is lit, and a while after.",
	"rise": "one flash when a beam striking it lights.",
	"fall": "one flash when a beam striking it goes dark.",
	"gate": "lets a beam through its ring while its bulb is lit.",
	"closing_gate": "stops a beam at its ring while its bulb is lit.",
	"mirror": "turns a beam off its silvered face.",
	"splitter": "sends a beam on through and aside, each with half its reach.",
	"lens": "a beam through it reaches twice as far again.",
	"radiometer": "its vanes spin in the light; a bell rings as they start.",
	"track": "a cart on rails, driven by push and pull beams on its copper ball.",
}
const MENU_HELP := "Click a piece to take it in hand.     Tab or right click: back to the view."
const AIM_NOTE := "\nE: look through it.  Right click: aim it at what you look at."

var island: BuildWorld
var _save_path := SAVE_PATH
var _demo := true
var light := BenchLight.new()
var scope: BenchScope
var tiles: Array[FloorTile] = []
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
var _yaw := 0.0                         # how it is turned
var _support := 0.0                     # the height a piece's rod goes down to
# The see-through copy of what is in hand.
var _ghost: Node3D = null
var _ghost_key := ""
var _ghost_rod: MeshInstance3D = null
var _ghost_red := false
# Something picked up to move, gone from where it stood until set down.
var _carried: Node3D = null
var _riders: Array[Node3D] = []         # pieces standing on a carried tile
var _targets := {}                      # piece -> its target, for the pieces aimed again after a move
## What each piece was aimed at: piece -> {piece, sensor} for a piece or a
## gate's bulb, {tile, local} for a point on a floor tile, and always
## {point}, where it was.
var links := {}
var _aim_target := {}                   # what the piece being aimed points at now
var _demo_built := false
var _reaim: Array = []                  # [piece, target, steps left]: aimed again as the light settles
var _red := StandardMaterial3D.new()
var _ui := CanvasLayer.new()
var _cross := Label.new()
var _on_piece: Node3D = null            # the piece the crosshair is on, within reach
var _hint := Label.new()
var _menu: PanelContainer
var _menu_open := false
var _cards := {}                        # item index -> its button in the menu
var _pictures := {}                     # item index -> its picture
var _about: Label                       # the line saying what a piece does
var _pointer: ImageTexture
var _picked := StyleBoxFlat.new()
var _plain := StyleBoxFlat.new()


## `save_path` is where what is built is kept; `demo` builds the shuttle
## on a first visit (the cozy island's).
func _init(owner_island: BuildWorld, save_path := SAVE_PATH, demo := true) -> void:
	island = owner_island
	_save_path = save_path
	_demo = demo
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
	_red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_red.albedo_color = Color(1.0, 0.2, 0.15, 0.55)
	_build_ui()
	if not MouseMode.probe:
		_load()
		if _demo and not _demo_built:
			build_demo()
	if DisplayServer.get_name() != "headless":
		_take_pictures.call_deferred()


func _exit_tree() -> void:
	if _menu_open:
		Input.set_custom_mouse_cursor(null)
	if _save_in >= 0.0:
		_save()


## ---- building ----------------------------------------------------------------

## A floor tile with the middle of its top at `at`, turned `yaw`.
func add_tile(at: Vector3, yaw: float) -> FloorTile:
	var t := FloorTile.new(self, at, yaw)
	add_child(t)
	tiles.append(t)
	_clear_ground()
	_rods_due = true
	return t


func remove_tile(t: FloorTile) -> void:
	for target: Dictionary in links.values():
		if target.get("tile") == t:
			target["point"] = _target_point(target)
			target.erase("tile")
			target.erase("local")
	tiles.erase(t)
	t.queue_free()
	_clear_ground()
	_rods_due = true


## A piece of `key` with its middle at `at`, its head turned to `yaw`
## and `pitch`.
func add_piece(key: String, at: Vector3, yaw: float, pitch: float, delay := 2.0) -> Node3D:
	var piece := _make(key, at, delay)
	_set_layer(piece, 4)
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
		var whir := AudioStreamPlayer3D.new()
		if DisplayServer.get_name() != "headless":
			var loop := load("res://audio/radiometer_whir_loop.wav") as AudioStreamWAV
			loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop.loop_begin = 0
			loop.loop_end = int(loop.get_length() * loop.mix_rate)
			whir.stream = loop
			whir.autoplay = true
		whir.volume_db = -80.0
		whir.unit_size = 3.0
		piece.add_child(whir)
		_bells[piece] = [false, bell, whir]
	_rods_due = true
	if piece is BeamCart:
		_clear_ground()
	return piece


## A piece of `key` at `at`, not yet placed.
func _make(key: String, at: Vector3, delay := 2.0) -> Node3D:
	if key == "track":
		return BeamCart.new(at, wood, timber, brass, copper)
	if GATES.has(key):
		return LightGate.new(at, brass, copper if GATES[key] else brass, glass, GATES[key])
	if GLASS.has(key):
		return OpticElement.new(GLASS[key], at, 0.0, timber, brass, silver, glass, false)
	var kind: LumenPart.Kind = KINDS[key]
	var look := {"post": false, "aimed": true, "catch": 0.22}
	look.merge(LOOKS.get(key, {}))
	if look.has("metal"):
		look["metal"] = get(look["metal"])
	var part := LumenPart.new(kind, "", at, at.y, timber, brass,
			delay if kind == LumenPart.Kind.TON or kind == LumenPart.Kind.TOF else 0.0, look)
	if BEAMS.has(key):
		part.set_meta("beam", BEAMS[key])
	return part


## A piece (a gate's sensor too) on collision layer `layer`.
func _set_layer(n: Node3D, layer: int) -> void:
	if n is LightGate:
		(n as LightGate).set_layer(layer)
	elif n is BeamCart:
		(n as BeamCart).set_layer(layer)
	else:
		(n as CollisionObject3D).collision_layer = layer


func remove_piece(piece: Node3D) -> void:
	if _aiming == piece:
		_end_aim()
	if scope.held == piece:
		scope.leave()
	pieces.erase(piece)
	light.remove(piece)
	_bells.erase(piece)
	links.erase(piece)
	for target: Dictionary in links.values():
		if target.get("piece") == piece:
			target["point"] = _target_point(target)
			target.erase("piece")
			target.erase("sensor")
	piece.queue_free()
	_rods_due = true
	if piece is BeamCart:
		_clear_ground()


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
	elif piece is LightGate:
		(piece as LightGate).relabel(text + "\nRight click: turn its ring to face what you look at.")
	elif piece is BeamCart:
		(piece as BeamCart).relabel(text)


func is_piece(n: Object) -> bool:
	return n is Node3D and (n as Node3D).has_meta("piece") and pieces.has(n)


func all_pieces() -> Array[Node3D]:
	return pieces


## Whether a piece sends a beam of its own or turns one (all but the
## radiometer).
static func sends(piece: Node3D) -> bool:
	return piece is OpticElement or (piece is LumenPart and (piece as LumenPart).kind != LumenPart.Kind.RADIOMETER)


## Whether a right click turns it: all that send a beam, and gates.
static func turns(piece: Node3D) -> bool:
	return sends(piece) or piece is LightGate


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
	if piece is LightGate:
		if piece.global_position.distance_to(point) > 0.01:
			(piece as LightGate).aim_along(point - piece.global_position)
		return
	var e := piece as OpticElement
	if e.kind != OpticElement.Kind.LENS and light.arrivals.has(e):
		var arrival: Array = light.arrivals[e]
		var out := (point - (arrival[0] as Vector3)).normalized()
		e.aim_along((out - (arrival[1] as Vector3)).normalized())
	elif e.global_position.distance_to(point) > 0.01:
		e.aim_along(point - e.global_position)


## The lens view left `piece`: aimed at `target` if its beam settled on a
## piece there, or, turned freely, at whatever its beam strikes first.
func aimed_by_scope(piece: Node3D, target: Node3D, turned: bool) -> void:
	if target != null and pieces.has(target):
		links[piece] = {"piece": target, "point": target.global_position}
	elif turned:
		links.erase(piece)


## ---- the shuttle ---------------------------------------------------------------

## The shuttle built at DEMO_AT, in place of any pieces standing there:
## the track along x, the lamps at its east end, the gold beams' lanterns
## on the south side, the crystals and the latch to the north.
func build_demo() -> void:
	# Whatever stands in its place goes first, and the first, short
	# shuttle where it stood.
	var half := BeamCart.LENGTH * 0.5
	for piece: Node3D in pieces.duplicate():
		var off := piece.global_position - DEMO_AT
		var old := piece.global_position - OLD_DEMO_AT
		if (off.x > -half - 0.6 and off.x < half + 2.1 and off.z > -4.6 and off.z < 1.7) \
				or (old.x > -3.6 and old.x < 4.1 and old.z > -4.6 and old.z < 1.7):
			remove_piece(piece)
	var base := -INF
	for k in 9:
		base = maxf(base, island.height(DEMO_AT.x - half + k * half / 4.0, DEMO_AT.z))
	var at := func(u: float, v: float, h: float) -> Vector3:
		return Vector3(DEMO_AT.x + u, base + h, DEMO_AT.z + v)
	var h := BeamCart.HANDLE
	var cart := add_piece("track", Vector3(DEMO_AT.x, base, DEMO_AT.z), 0.0, 0.0) as BeamCart
	# The east end: the push lamp's beam straight along the track through
	# its gate and the splitter; the pull lamp's from the south, through
	# its gate, turned onto the track's line by the splitter.
	var join := add_piece("splitter", at.call(half + 0.7, 0.0, h), 0.0, 0.0) as OpticElement
	join.aim_along(Vector3(-1.0, 0.0, 1.0))
	var push := add_piece("push_lamp", at.call(half + 1.6, 0.0, h), 0.0, 0.0) as LumenPart
	var pull := add_piece("pull_lamp", at.call(half + 0.7, 1.0, h), 0.0, 0.0) as LumenPart
	_demo_aim(push, join)
	_demo_aim(pull, join)
	var lens := add_piece("lens", at.call(half + 0.3, 0.0, h), 0.0, 0.0) as OpticElement
	lens.aim_along(Vector3(1.0, 0.0, 0.0))
	# The latch, and which of its sides each end's crystal strikes.
	# The latch stands west of the crystals' line, so the line of its own
	# beam passes between them and they strike it from opposite sides.
	var latch_at: Vector3 = at.call(-3.0, -4.0, 1.7)
	var push_gate_at: Vector3 = at.call(half + 1.15, 0.0, h)
	var pull_gate_at: Vector3 = at.call(half + 0.7, 0.5, h)
	var push_bulb := push_gate_at + Vector3(0, 0.27, 0)
	var pull_bulb := pull_gate_at + Vector3(0, 0.27, 0)
	var fork_at := latch_at.lerp(push_bulb, 0.85)
	var east_crystal_at: Vector3 = at.call(half - 0.4, -1.3, h)
	var right := (fork_at - latch_at).normalized().cross(Vector3.UP)
	var east_sets := (latch_at - east_crystal_at).normalized().dot(right) > 0.0
	# Lit, the latch means the cart is to go west: the push gate open and
	# the pull gate shut. Whether lit means that depends on the side the
	# east crystal strikes it from.
	var push_gate := add_piece("gate" if east_sets else "closing_gate", push_gate_at, 0.0, 0.0) as LightGate
	var pull_gate := add_piece("closing_gate" if east_sets else "gate", pull_gate_at, 0.0, 0.0) as LightGate
	push_gate.aim_along(Vector3(1.0, 0.0, 0.0))
	pull_gate.aim_along(Vector3(0.0, 0.0, 1.0))
	var latch := add_piece("latch", latch_at, 0.0, 0.0) as LumenPart
	var fork := add_piece("splitter", fork_at, 0.0, 0.0) as OpticElement
	_demo_aim(latch, fork)
	var incoming := (fork_at - latch_at).normalized()
	fork.aim_along(((pull_bulb - fork_at).normalized() - incoming).normalized())
	links[fork] = {"piece": pull_gate, "sensor": true, "point": pull_bulb}
	# The beams across the track near its ends, and the NOT crystals that
	# light when the cart's ball blocks them.
	for u: float in [-half + 0.4, half - 0.4]:
		var lamp := add_piece("lantern", at.call(u, 1.3, h), 0.0, 0.0) as LumenPart
		var crystal := add_piece("not", at.call(u, -1.3, h), 0.0, 0.0) as LumenPart
		lamp.condition = true
		_demo_aim(lamp, crystal)
		_demo_aim(crystal, latch)
	push.condition = true
	pull.condition = true
	cart.place_cart(0.0)
	_demo_built = true
	changed()


## `from` aimed at `to`, and the link kept.
func _demo_aim(from: Node3D, to: Node3D) -> void:
	aim_at(from, to.global_position)
	links[from] = {"piece": to, "point": to.global_position}


func toggle(lantern: LumenPart) -> void:
	lantern.condition = not lantern.condition
	changed()


## No flowers growing up through a floor laid near the ground, or a
## track.
func _clear_ground() -> void:
	var areas: Array = []
	for piece in pieces:
		if piece is BeamCart:
			areas.append([piece.global_transform, BeamCart.LENGTH * 0.5 + 0.1, 0.3])
	for t in tiles:
		var low := INF
		for u: float in [-1.0, 1.0]:
			for v: float in [-1.0, 1.0]:
				var c := t.global_transform * (Vector3(u, 0.0, v) * FloorTile.SIZE * 0.5)
				low = minf(low, t.top - island.height(c.x, c.z))
		if low < 0.6:
			areas.append([t.global_transform, FloorTile.SIZE * 0.5 + 0.05])
	island.clear_ground(areas)


## Each piece's brass rod, down to whatever is under it: a piece, a
## floor, the ground.
func _place_rods() -> void:
	var space := get_world_3d().direct_space_state
	for piece in pieces:
		if piece is BeamCart:
			continue
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
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and (hit["collider"] as Node).has_meta("part_of"):
		hit["collider"] = (hit["collider"] as Node).get_meta("part_of")
		hit["sensor"] = true
	return hit


func _held_key() -> String:
	return str(ITEMS[item][0])


## Where the thing in hand would go and whether it can; its copy put
## there, red where it cannot go.
func _find_place() -> void:
	var hit := _look_hit()
	_ok = false
	_why = ""
	var f := -island.player.camera.global_basis.z
	_yaw = atan2(-f.x, -f.z)
	var shown := false
	if not hit.is_empty():
		var p: Vector3 = hit["position"]
		var n: Vector3 = hit["normal"]
		var c: Object = hit["collider"]
		if _held_key() == "floor":
			shown = _find_tile(p, n, c)
		elif _held_key() == "track":
			shown = _find_track(p, n, c)
		else:
			shown = _find_spot(p, n, c)
	if not shown:
		if _ghost != null:
			_ghost.visible = false
		return
	_show_ghost()


## A tile: where the crosshair meets the ground, or settled beside a tile
## near it. Whether there is anything to show.
func _find_tile(p: Vector3, n: Vector3, c: Object) -> bool:
	var at := p
	var yaw := _yaw
	var level := -INF
	if c is FloorTile:
		# Beside the tile looked at: off the side it is looked at by, or
		# off its nearest edge when looked at from above.
		var t := c as FloorTile
		var local := t.to_local(p)
		var ln := t.global_basis.inverse() * n
		var d := Vector3(ln.x, 0.0, ln.z) if n.y < 0.7 else Vector3(local.x, 0.0, local.z)
		d = Vector3(signf(d.x), 0.0, 0.0) if absf(d.x) > absf(d.z) else Vector3(0.0, 0.0, signf(d.z))
		at = t.global_transform * (d * FloorTile.SIZE)
		yaw = t.rotation.y
		level = t.top
	else:
		var best := SETTLE
		for t in tiles:
			if t == _carried:
				continue
			for b in t.beside():
				var gap := Vector2(b.x - p.x, b.z - p.z).length()
				if gap < best:
					best = gap
					at = b
					yaw = t.rotation.y
					level = t.top
	var turn := Basis(Vector3.UP, yaw)
	var lo := INF
	var hi := -INF
	for a in 3:
		for b in 3:
			var q := Vector3(at.x, 0.0, at.z) + turn * (Vector3(a - 1.0, 0.0, b - 1.0) * FloorTile.SIZE * 0.5)
			var h := island.height(q.x, q.z)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	var top := (level if level > -INF else hi + 0.05) + lift
	_at = Vector3(at.x, top, at.z)
	_yaw = yaw
	var xf := Transform3D(turn, _at)
	# Drafts.
	if lo < 0.12:
		_why = "Not over the water."
	elif top < hi + 0.04:
		_why = "The ground stands higher than that; raise it with Shift and the wheel."
	elif top > hi + MAX_TILE_RISE:
		_why = "Too high above the ground."
	elif _meets_tile(xf):
		_why = "Another floor is there."
	elif _blocked(xf * Vector3(0, 0.95, 0), Vector3(FloorTile.SIZE - 0.05, 1.8, FloorTile.SIZE - 0.05), turn):
		_why = "Something stands in the way."
	elif _under_player(xf):
		_why = "You are standing there."
	_ok = _why == ""
	return true


## A track: on the floor or ground where the crosshair is, running away
## from the view, level at the highest ground along it. Whether there is
## anything to show.
func _find_track(p: Vector3, n: Vector3, c: Object) -> bool:
	if n.y < 0.7 or is_piece(c):
		return false
	_yaw += PI * 0.5
	var along := Basis(Vector3.UP, _yaw) * Vector3.RIGHT
	var lo := INF
	var hi := -INF
	for k in 9:
		var q := p + along * BeamCart.LENGTH * (k / 8.0 - 0.5)
		var h := island.height(q.x, q.z)
		lo = minf(lo, h)
		hi = maxf(hi, h)
	_at = Vector3(p.x, p.y if c is FloorTile else maxf(hi, p.y), p.z)
	_support = _at.y
	# Drafts.
	if lo < 0.12:
		_why = "Not over the water."
	elif not c is FloorTile and hi - lo > 0.8:
		_why = "The ground is too steep for a track here."
	elif _blocked(_at + Vector3(0, 0.75, 0), Vector3(BeamCart.LENGTH, 1.2, 0.5), Basis(Vector3.UP, _yaw)):
		_why = "Something stands in the way."
	_ok = _why == ""
	return true


## A piece: over the point the crosshair is on, or over the piece looked
## at. Whether there is anything to show.
func _find_spot(p: Vector3, n: Vector3, c: Object) -> bool:
	if is_piece(c) and not c is BeamCart:
		var under := c as Node3D
		var over := 0.33 if under is LightGate else 0.2
		_support = under.global_position.y + over
		_at = under.global_position + Vector3(0, over + 0.3 + lift, 0)
	elif n.y > 0.7:
		_support = p.y
		_at = p + Vector3(0, HEAD + lift, 0)
	else:
		return false
	# Drafts.
	if _at.y < _support + 0.25:
		_why = "Too low."
	elif _at.y > _support + 4.0:
		_why = "Too high."
	else:
		for other in pieces:
			if other != _carried and other.global_position.distance_to(_at) < CLEAR:
				_why = "Too close to another piece."
				break
	if _why == "" and _blocked(_at, Vector3(0.3, 0.36, 0.3)):
		_why = "Something stands in the way."
	_ok = _why == ""
	return true


## Whether a box of `size` at `at`, turned by `turn`, meets anything
## solid but the player.
func _blocked(at: Vector3, size: Vector3, turn := Basis.IDENTITY) -> bool:
	var box := BoxShape3D.new()
	box.size = size
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = Transform3D(turn, at)
	q.collision_mask = 1 | 4
	q.exclude = [island.player.get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Whether a tile placed at `xf` would overlap another (touching edge to
## edge is allowed).
func _meets_tile(xf: Transform3D) -> bool:
	var box := BoxShape3D.new()
	box.size = Vector3(FloorTile.SIZE - 0.1, FloorTile.THICK - 0.02, FloorTile.SIZE - 0.1)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = Transform3D(xf.basis, xf * Vector3(0, -FloorTile.THICK * 0.5, 0))
	q.collision_mask = 1
	for found: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, 16):
		if found["collider"] is FloorTile:
			return true
	return false


## Whether the player stands within the square of a tile placed at
## `xf`, below its top and within their height of it.
func _under_player(xf: Transform3D) -> bool:
	var local := xf.affine_inverse() * island.player.global_position
	var half := FloorTile.SIZE * 0.5 + 0.35
	return absf(local.x) < half and absf(local.z) < half and local.y < 0.0 and local.y > -2.0


func _place() -> void:
	if not _ok:
		return
	if _carried != null:
		_put_down()
	elif _held_key() == "floor":
		add_tile(_at, _yaw)
	else:
		add_piece(_held_key(), _at, _yaw, 0.0)
	changed()


## ---- moving what is built ----------------------------------------------------

## `n` (a piece or a tile) taken up to move: out of sight, out of the
## light and out of the way of rays until set down or put back.
func _take_up(n: Node3D) -> void:
	_riders.clear()
	if n is FloorTile:
		var tile := n as FloorTile
		if _under_player(tile.global_transform):
			return
		for piece in pieces:
			var local := tile.to_local(piece.global_position)
			if absf(local.x) < FloorTile.SIZE * 0.5 and absf(local.z) < FloorTile.SIZE * 0.5 \
					and local.y > 0.0 and local.y < 5.0:
				_riders.append(piece)
	if not building:
		_set_building(true)
	for i in ITEMS.size():
		if ITEMS[i][0] == ("floor" if n is FloorTile else n.get_meta("piece")):
			_pick(i)
	lift = 0.0
	_carried = n
	_targets.clear()
	var moving: Array = [n] + _riders
	for m: Node3D in moving:
		if sends(m):
			_targets[m] = _target_for(m)
	# Pieces left standing that are aimed at what moves follow it.
	for other in pieces:
		if moving.has(other) or not sends(other):
			continue
		var target := _target_for(other)
		if moving.has(target.get("piece")) or (n is FloorTile and target.get("tile") == n):
			_targets[other] = target
	for m: Node3D in [n] + _riders:
		_hide(m, true)


## A piece's target: what it was aimed at, or else what its beam
## strikes first.
func _target_for(piece: Node3D) -> Dictionary:
	if links.has(piece):
		return links[piece]
	return _target_of(piece)


## What a piece's beam strikes first: a piece (or a gate's bulb), a point
## on a floor tile (kept in its frame), the point struck, or a point
## 20 m on.
func _target_of(piece: Node3D) -> Dictionary:
	var origin := piece.global_position
	var dir := Vector3.FORWARD
	if piece is LumenPart:
		origin = (piece as LumenPart).lens_point()
		dir = (piece as LumenPart).forward()
	else:
		var e := piece as OpticElement
		dir = e.normal()
		if e.kind != OpticElement.Kind.LENS and light.arrivals.has(e):
			var arrival: Array = light.arrivals[e]
			var incoming: Vector3 = arrival[1]
			origin = arrival[0]
			dir = (incoming - 2.0 * incoming.dot(dir) * dir).normalized()
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * BenchLight.REACH)
	q.exclude = [(piece as CollisionObject3D).get_rid(), island.player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {"point": origin + dir * 20.0}
	var c: Object = hit["collider"]
	if (c as Node).has_meta("part_of"):
		return {"piece": (c as Node).get_meta("part_of"), "sensor": true, "point": hit["position"]}
	if is_piece(c):
		return {"piece": c, "point": hit["position"]}
	return _point_target(c, hit["position"])


## A point struck on `c` as a target: kept in a floor tile's frame.
func _point_target(c: Object, at: Vector3) -> Dictionary:
	if c is FloorTile:
		return {"tile": c, "local": (c as FloorTile).to_local(at), "point": at}
	return {"point": at}


## Where a kept target now is.
func _target_point(target: Dictionary) -> Vector3:
	var piece: Variant = target.get("piece")
	if piece != null and is_instance_valid(piece) and pieces.has(piece):
		if target.get("sensor", false):
			return (piece as Node3D).call("sensor_point")
		return (piece as Node3D).global_position
	var tile: Variant = target.get("tile")
	if tile != null and is_instance_valid(tile) and tiles.has(tile):
		return (tile as FloorTile).global_transform * (target["local"] as Vector3)
	return target["point"]


func _hide(n: Node3D, away: bool) -> void:
	n.visible = not away
	var body := n as CollisionObject3D
	if n is FloorTile:
		body.collision_layer = 0 if away else 1
	else:
		_set_layer(n, 0 if away else 4)
		if away:
			light.remove(n)
		else:
			light.add(n)


## The carried thing set down where its copy stands: a piece moved there
## as it was aimed; a tile made again there (for its legs), the pieces on
## it carried with it.
func _put_down() -> void:
	if _carried is FloorTile:
		var old := _carried as FloorTile
		var before := old.global_transform
		tiles.erase(old)
		old.queue_free()
		var tile := add_tile(_at, _yaw)
		var move := tile.global_transform * before.affine_inverse()
		var turn := _yaw - before.basis.get_euler().y
		for r in _riders:
			r.global_position = move * r.global_position
			r.call("aim", float(r.get("yaw")) + turn, float(r.get("pitch")))
			_hide(r, false)
		for target: Dictionary in _targets.values() + links.values():
			if target.get("tile") == old:
				target["tile"] = tile
	else:
		_carried.global_position = _at
		_hide(_carried, false)
	for piece: Node3D in _targets:
		links[piece] = _targets[piece]
		aim_at(piece, _target_point(_targets[piece]))
		_reaim.append([piece, _targets[piece], 6])
	_targets.clear()
	_carried = null
	_riders.clear()
	_rods_due = true
	_clear_ground()
	changed()


## The carried thing back where it stood.
func _put_back() -> void:
	if _carried == null:
		return
	for m: Node3D in [_carried] + _riders:
		_hide(m, false)
	_carried = null
	_riders.clear()
	_targets.clear()


## ---- the see-through copy -----------------------------------------------------

## The copy of what is in hand, made whole and see-through, moved to
## where it would go; a tile's made again when it moves, for its legs.
func _show_ghost() -> void:
	var key := _held_key()
	var tile := key == "floor"
	var moved := _ghost != null and tile and (_ghost.global_position.distance_to(_at) > 0.005
			or absf(_ghost.rotation.y - _yaw) > 0.001)
	if _ghost == null or _ghost_key != key or moved:
		_drop_ghost()
		_ghost_key = key
		if tile:
			_ghost = FloorTile.new(self, _at, _yaw)
		else:
			_ghost = _make(key, _at)
			if key != "track":
				_ghost_rod = MeshInstance3D.new()
				_ghost.add_child(_ghost_rod)
		if tile:
			(_ghost as CollisionObject3D).collision_layer = 0
		else:
			_set_layer(_ghost, 0)
		add_child(_ghost)
		for m: Node in _ghost.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			mi.transparency = 0.45
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ghost_red = false
	_ghost.visible = true
	if not tile:
		_ghost.global_position = _at
		if _carried != null:
			_ghost.call("aim", float(_carried.get("yaw")), float(_carried.get("pitch")))
		else:
			_ghost.call("aim", _yaw, 0.0)
	if not tile and _ghost_rod != null:
		var top := _at.y - (0.2 if _ghost is OpticElement else 0.13)
		var rod := CylinderMesh.new()
		rod.top_radius = 0.016
		rod.bottom_radius = 0.022
		rod.height = maxf(top - _support, 0.02)
		rod.radial_segments = 8
		rod.rings = 1
		rod.material = brass
		_ghost_rod.mesh = rod
		_ghost_rod.global_position = Vector3(_at.x, (top + _support) * 0.5, _at.z)
		_ghost_rod.global_rotation = Vector3.ZERO
	if _ghost_red != not _ok:
		_ghost_red = not _ok
		for m: Node in _ghost.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_overlay = _red if _ghost_red else null


func _drop_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
	_ghost = null
	_ghost_rod = null
	_ghost_key = ""


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
	_aim_target = {"point": point}
	if not hit.is_empty():
		point = hit["position"]
		var c: Object = hit["collider"]
		_aim_target = _point_target(c, point)
		if hit.get("sensor", false):
			point = (c as Node3D).call("sensor_point")
			_aim_target = {"piece": c, "sensor": true, "point": point}
		elif is_piece(c):
			point = (c as Node3D).global_position
			_aim_target = {"piece": c, "point": point}
	aim_at(_aiming, point)
	light.spot = point
	light.spot_size = 0.012 * cam.global_position.distance_to(point) + 0.02


## ---- input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var player := island.player
	var key := event as InputEventKey
	var click := event as InputEventMouseButton
	if _menu_open:
		# Back to the view: Tab, Esc, a right click, or a click outside
		# the menu (a click on it is the menu's own).
		if (key != null and key.pressed and not key.echo and key.physical_keycode == KEY_TAB) \
				or event.is_action_pressed("ui_cancel") or (click != null and click.pressed \
				and click.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]):
			_close_menu()
			get_viewport().set_input_as_handled()
		return
	if scope.held != null or player.input_locked or player.look_held_by != null:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not MouseMode.probe:
		return
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_TAB:
		if _carried == null and _aiming == null:
			_open_menu()
	elif _carried != null and event.is_action_pressed("ui_cancel"):
		_put_back()
	elif key != null and key.pressed and not key.echo and key.physical_keycode == KEY_G and _aiming == null:
		if _carried != null:
			return
		var hit := _look_hit()
		if hit.is_empty() or not (is_piece(hit["collider"]) or hit["collider"] is FloorTile):
			return
		_take_up(hit["collider"] as Node3D)
	elif _carried != null and click != null and click.button_index == MOUSE_BUTTON_RIGHT:
		pass
	elif key != null and key.pressed and not key.echo and key.physical_keycode in [KEY_X, KEY_T] \
			and _carried == null and _aiming == null:
		_change(key.physical_keycode)
	elif _aiming != null:
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			if not _aim_target.is_empty():
				links[_aiming] = _aim_target
			_aim_target = {}
			_end_aim()
			changed()
		elif (click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT) \
				or event.is_action_pressed("ui_cancel"):
			_aiming.call("aim", _aim_before.x, _aim_before.y)
			_end_aim()
		else:
			return
	elif building and click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
		# A right click with something in hand puts it away.
		_set_building(false)
	elif click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
		var hit := _look_hit()
		if hit.is_empty() or not is_piece(hit["collider"]) or not turns(hit["collider"]):
			return
		_start_aim(hit["collider"])
	elif event.is_action_pressed("interact"):
		var hit := _look_hit()
		if hit.is_empty() or not is_piece(hit["collider"]):
			return
		var v := hit["collider"] as Node3D
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
				# The wheel alone zooms the view, as always; with Shift it
				# raises and lowers what is in hand.
				if not click.shift_pressed:
					return false
				var up := click.button_index == MOUSE_BUTTON_WHEEL_UP
				lift = clampf(lift + (LIFT_STEP if up else -LIFT_STEP), -0.5, MAX_TILE_RISE)
			_:
				return false
		return true
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	match key.physical_keycode:
		_:
			if key.physical_keycode >= KEY_0 and key.physical_keycode <= KEY_9:
				_pick(9 if key.physical_keycode == KEY_0 else key.physical_keycode - KEY_1)
			else:
				return false
	return true


## X: the piece or tile the crosshair is on taken away. T: an
## hourglass's or afterglow's delay stepped on.
func _change(code: Key) -> void:
	var hit := _look_hit()
	if hit.is_empty():
		return
	var c: Object = hit["collider"]
	if code == KEY_X:
		if is_piece(c):
			remove_piece(c as Node3D)
			changed()
		elif c is FloorTile:
			remove_tile(c as FloorTile)
			changed()
	elif c is LumenPart and is_piece(c):
		var p := c as LumenPart
		if p.kind == LumenPart.Kind.TON or p.kind == LumenPart.Kind.TOF:
			var i := DELAYS.find(p.delay)
			p.delay = DELAYS[(i + 1) % DELAYS.size()]
			relabel(p)
			changed()


func _pick(i: int) -> void:
	_put_back()
	if (str(ITEMS[i][0]) == "floor") != (_held_key() == "floor"):
		lift = 0.0
	item = i
	if _ghost != null and _ghost_key != _held_key():
		_drop_ghost()
	for k: int in _cards:
		(_cards[k] as Button).add_theme_stylebox_override("normal", _picked if k == item else _plain)


func _set_building(on: bool) -> void:
	building = on
	for k: int in _cards:
		(_cards[k] as Button).add_theme_stylebox_override("normal", _picked if on and k == item else _plain)
	if not on:
		_put_back()
		_drop_ghost()


## ---- each step --------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if _rods_due:
		_rods_due = false
		_place_rods()
	light.step(dt)
	# Moved pieces aimed again for a few steps, as the beams reaching
	# moved mirrors settle.
	for i in range(_reaim.size() - 1, -1, -1):
		var r: Array = _reaim[i]
		if is_instance_valid(r[0]) and pieces.has(r[0]):
			aim_at(r[0], _target_point(r[1]))
		r[2] = int(r[2]) - 1
		if int(r[2]) <= 0:
			_reaim.remove_at(i)
			changed()
	for r: LumenPart in _bells:
		var b: Array = _bells[r]
		if r.powered and not bool(b[0]):
			BeachSite._play(b[1] as AudioStreamPlayer3D, 1.0)
		b[0] = r.powered
		# The vanes' whir, as loud and high as they spin.
		var whir := b[2] as AudioStreamPlayer3D
		whir.volume_db = linear_to_db(clampf(r.spin, 0.0001, 1.0)) - 6.0
		whir.pitch_scale = 0.6 + 0.6 * r.spin


func _process(delta: float) -> void:
	var player := island.player
	var free := scope.held == null and not player.input_locked and player.look_held_by == null
	if _aiming != null and free:
		_follow_aim()
	if building and free and _aiming == null and not _menu_open:
		_find_place()
	elif _ghost != null:
		_ghost.visible = false
	# The crosshair shows whenever the player looks about, gold over a
	# piece within reach.
	var looking := free and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or MouseMode.probe)
	_on_piece = null
	if looking and _aiming == null:
		var hit := _look_hit()
		if not hit.is_empty() and is_piece(hit["collider"]):
			_on_piece = hit["collider"] as Node3D
	_cross.visible = looking
	_cross.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35, 1.0) if _on_piece != null else Color(1, 1, 1, 0.7))
	# The menu closes if the view was taken back some other way.
	if _menu_open and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not free):
		_close_menu(false)
	_hint.visible = looking and (building or _aiming != null or _on_piece != null)
	if _hint.visible:
		_hint.text = _hint_text()
		_hint.visible = _hint.text != ""
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
	if not building:
		var p := _on_piece as LumenPart
		if p != null and p.kind == LumenPart.Kind.LANTERN:
			return "Right click: aim it     E: open or close it     G: move it     X: take it away"
		if p != null and p.kind == LumenPart.Kind.RADIOMETER:
			return "G: move it     X: take it away"
		if p != null and (p.kind == LumenPart.Kind.TON or p.kind == LumenPart.Kind.TOF):
			return "Right click: aim it     E: look through it     T: change the time     G: move it     X: take it away"
		if _on_piece is BeamCart:
			return "G: move it     X: take it away"
		if _on_piece is LightGate:
			return "Right click: turn it     G: move it     X: take it away"
		return "Right click: aim it     E: look through it     G: move it     X: take it away"
	if _carried != null:
		var put := "Click: set it down here" if _ok else _why
		if put == "":
			put = "Look at the ground, a floor or a piece"
		return "%s\nShift and wheel: higher, lower     Esc: put it back where it was" % put
	var place := ("Click: place the %s" % str(ITEMS[item][1]).to_lower()) if _ok else _why
	if place == "":
		place = "Look at the ground, a floor or a piece"
	var height := ""
	if not is_zero_approx(lift):
		height = "     %+.2f m" % lift
	return "%s%s\nRight click: put it away     Tab: the menu     Shift and wheel: higher, lower     G: move     X: take away" % [place, height]


## ---- the screen ------------------------------------------------------------------

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
	_build_menu(root)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.97, 0.93, 0.82))
	_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.offset_bottom = -40.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	root.add_child(_hint)
	_pick(0)


## ---- the building menu --------------------------------------------------------

## The menu, closed: a row for each group of pieces, a card for each
## piece (its picture once taken, its name), Empty hands, and the line
## saying what the piece under the pointer does.
func _build_menu(root: Control) -> void:
	_plain.bg_color = Color(1, 1, 1, 0.04)
	_plain.set_corner_radius_all(6)
	_plain.set_content_margin_all(4)
	_picked.bg_color = Color(1.0, 0.9, 0.6, 0.22)
	_picked.border_color = Color(1.0, 0.85, 0.5, 0.95)
	_picked.set_border_width_all(2)
	_picked.set_corner_radius_all(6)
	_picked.set_content_margin_all(4)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.14)
	hover.set_corner_radius_all(6)
	hover.set_content_margin_all(4)
	_menu = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.07, 0.05, 0.86)
	style.border_color = Color(0.72, 0.56, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	_menu.add_theme_stylebox_override("panel", style)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu.visible = false
	root.add_child(_menu)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_menu.add_child(column)
	for line: Array in GROUPS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		column.add_child(row)
		for group: Array in line:
			var heading := Label.new()
			heading.text = str(group[0])
			heading.custom_minimum_size = Vector2(76, 0)
			heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			heading.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
			heading.add_theme_font_size_override("font_size", 15)
			row.add_child(heading)
			for key: String in group[1]:
				var i := _index_of(key)
				var card := Button.new()
				card.custom_minimum_size = Vector2(90, 98)
				card.focus_mode = Control.FOCUS_NONE
				card.add_theme_stylebox_override("normal", _plain)
				card.add_theme_stylebox_override("hover", hover)
				card.add_theme_stylebox_override("pressed", _picked)
				var inner := VBoxContainer.new()
				inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
				inner.add_theme_constant_override("separation", 2)
				card.add_child(inner)
				var picture := TextureRect.new()
				picture.custom_minimum_size = Vector2(80, 76)
				picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
				inner.add_child(picture)
				_pictures[i] = picture
				var label := Label.new()
				label.text = str(ITEMS[i][1])
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				label.clip_text = true
				inner.add_child(label)
				card.pressed.connect(func() -> void:
					_pick(i)
					building = true
					_close_menu())
				card.mouse_entered.connect(func() -> void: _about.text = "%s: %s" % [ITEMS[i][1], MENU_NOTES.get(key, "")])
				card.mouse_exited.connect(func() -> void: _about.text = MENU_HELP)
				row.add_child(card)
				_cards[i] = card
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	column.add_child(foot)
	var empty := Button.new()
	empty.text = "Empty hands"
	empty.focus_mode = Control.FOCUS_NONE
	empty.pressed.connect(func() -> void:
		_set_building(false)
		_close_menu())
	foot.add_child(empty)
	_about = Label.new()
	_about.text = MENU_HELP
	_about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_about.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_about.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84))
	foot.add_child(_about)
	_pointer = _brass_pointer()


func _index_of(key: String) -> int:
	for i in ITEMS.size():
		if str(ITEMS[i][0]) == key:
			return i
	return 0


## Opening the menu puts away what was in hand.
func _open_menu() -> void:
	_set_building(false)
	_menu_open = true
	_menu.visible = true
	_about.text = MENU_HELP
	if _ghost != null:
		_ghost.visible = false
	MouseMode.release()
	Input.set_custom_mouse_cursor(_pointer, Input.CURSOR_ARROW, Vector2(1, 1))
	Input.warp_mouse(get_viewport().get_visible_rect().size * 0.5)


## Back to the view; `capture` takes the mouse back for looking about.
func _close_menu(capture := true) -> void:
	_menu_open = false
	_menu.visible = false
	Input.set_custom_mouse_cursor(null)
	if capture:
		MouseMode.capture()


## The game's own pointer: a brass arrow with a dark rim.
static func _brass_pointer() -> ImageTexture:
	var arrow := PackedVector2Array([Vector2(1, 1), Vector2(1, 21), Vector2(6.5, 16), Vector2(10, 24),
			Vector2(13.5, 22.5), Vector2(10, 15), Vector2(17, 15)])
	var img := Image.create(26, 26, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var inside := func(x: int, y: int) -> bool:
		return Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), arrow)
	for y in 26:
		for x in 26:
			if not inside.call(x, y):
				continue
			var rim := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not inside.call(x + d.x, y + d.y):
					rim = true
			var shine := clampf(1.0 - float(x + y) / 40.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.18, 0.12, 0.06) if rim else Color(0.82, 0.62, 0.28).lerp(Color(1.0, 0.9, 0.6), shine))
	return ImageTexture.create_from_image(img)


## Each piece's picture for the menu: the piece itself built in a small
## world of its own with a sun and a camera framing it, drawn once, kept
## as a picture, and the small world put away.
func _take_pictures() -> void:
	var studios: Array = []
	for i in ITEMS.size():
		var key := str(ITEMS[i][0])
		var studio := SubViewport.new()
		studio.size = Vector2i(160, 152)
		studio.own_world_3d = true
		studio.transparent_bg = true
		studio.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(studio)
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.62, 0.64, 0.7)
		env.ambient_light_energy = 0.7
		env.tonemap_mode = Environment.TONE_MAPPER_AGX
		var world_env := WorldEnvironment.new()
		world_env.environment = env
		studio.add_child(world_env)
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(35.0), 0.0)
		sun.light_energy = 1.3
		studio.add_child(sun)
		var thing: Node3D
		if key == "floor":
			thing = FloorTile.new(self, Vector3(0.0, island.height(0.0, 0.0) + 0.45, 0.0), 0.35)
		else:
			thing = _make(key, Vector3.ZERO)
		studio.add_child(thing)
		if thing.has_method("aim"):
			# Lamps turned to show their glass to the camera.
			thing.call("aim", 0.6 + (PI if KINDS.get(key, -1) == LumenPart.Kind.LANTERN else 0.0), -0.12)
		var box := AABB()
		var first := true
		for v: Node in thing.find_children("*", "MeshInstance3D", true, false):
			if not (v as MeshInstance3D).is_visible_in_tree():
				continue
			var b := (v as MeshInstance3D).global_transform * (v as MeshInstance3D).get_aabb()
			# The track's rails run 16 m: framed on its cart instead.
			if b.get_longest_axis_size() > 3.0:
				continue
			box = b if first else box.merge(b)
			first = false
		var cam := Camera3D.new()
		cam.fov = 30.0
		studio.add_child(cam)
		var r := maxf(box.size.length() * 0.5, 0.05)
		if key == "track":
			# Close on the cart, the track running away behind it.
			r = 0.9
			box = AABB(Vector3(0.0, 0.3, 0.0), Vector3.ZERO)
		cam.position = box.get_center() + Vector3(0.55, 0.42, 1.0).normalized() * r / sin(deg_to_rad(15.0)) * 1.05
		cam.look_at(box.get_center())
		studios.append([i, studio])
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for pair: Array in studios:
		var studio := pair[1] as SubViewport
		var picture := studio.get_texture().get_image()
		if picture != null and _pictures.has(pair[0]):
			(_pictures[pair[0]] as TextureRect).texture = ImageTexture.create_from_image(picture)
		studio.queue_free()


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
	for t in tiles:
		floor_list.append([t.position.x, t.top, t.position.z, t.rotation.y])
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
		if piece is BeamCart:
			entry["along"] = (piece as BeamCart).along
		if links.has(piece):
			var l: Dictionary = links[piece]
			var at: Vector3 = _target_point(l)
			var link := {"point": [at.x, at.y, at.z]}
			if l.get("piece") != null and pieces.has(l["piece"]):
				link["to"] = pieces.find(l["piece"])
				link["sensor"] = l.get("sensor", false)
			elif l.get("tile") != null and tiles.has(l["tile"]):
				var local: Vector3 = l["local"]
				link["tile"] = tiles.find(l["tile"])
				link["local"] = [local.x, local.y, local.z]
			entry["link"] = link
		list.append(entry)
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"floor": floor_list, "pieces": list, "demo": DEMO_VERSION if _demo_built else 0}))


func _load() -> void:
	if not FileAccess.file_exists(_save_path):
		return
	var file := FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var data := parsed as Dictionary
	_demo_built = int(data.get("demo", 0)) >= DEMO_VERSION
	if data.get("floor") is Array:
		for f: Variant in data["floor"]:
			if f is Array and (f as Array).size() >= 4:
				add_tile(Vector3(float(f[0]), float(f[1]), float(f[2])), float(f[3]))
			elif f is Array and (f as Array).size() == 3:
				# Kept when tiles stood on a grid 2 m square: grid x, grid z, top.
				add_tile(Vector3((float(f[0]) + 0.5) * 2.0, float(f[2]), (float(f[1]) + 0.5) * 2.0), 0.0)
	if data.get("pieces") is Array:
		var saved_links := {}
		for entry: Variant in data["pieces"]:
			if not entry is Dictionary:
				continue
			var d := entry as Dictionary
			var key := str(d.get("kind", ""))
			var at: Variant = d.get("at")
			if not (KINDS.has(key) or GLASS.has(key) or GATES.has(key) or key == "track") or not at is Array \
					or (at as Array).size() < 3:
				continue
			var aim := [0.0, 0.0]
			var a: Variant = d.get("aim")
			if a is Array and (a as Array).size() >= 2:
				aim = [float(a[0]), float(a[1])]
			var piece := add_piece(key, Vector3(float(at[0]), float(at[1]), float(at[2])), aim[0], aim[1],
					float(d.get("delay", 2.0)))
			if piece is LumenPart and bool(d.get("on", false)):
				(piece as LumenPart).condition = true
			if piece is BeamCart:
				(piece as BeamCart).place_cart(float(d.get("along", 0.0)))
			if d.get("link") is Dictionary:
				saved_links[piece] = d["link"]
		# Links name pieces and tiles by their place in the lists.
		for piece: Node3D in saved_links:
			var l: Dictionary = saved_links[piece]
			var pt: Variant = l.get("point")
			if not pt is Array or (pt as Array).size() < 3:
				continue
			var target := {"point": Vector3(float(pt[0]), float(pt[1]), float(pt[2]))}
			var to := int(l.get("to", -1))
			var tile_at := int(l.get("tile", -1))
			var local: Variant = l.get("local")
			if to >= 0 and to < pieces.size():
				target["piece"] = pieces[to]
				target["sensor"] = bool(l.get("sensor", false)) and (pieces[to] is LightGate or pieces[to] is BeamCart)
			elif tile_at >= 0 and tile_at < tiles.size() and local is Array and (local as Array).size() >= 3:
				target["tile"] = tiles[tile_at]
				target["local"] = Vector3(float(local[0]), float(local[1]), float(local[2]))
			links[piece] = target
