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
## click outside the menu go back to the view. A small button at each
## card's top right, or I with the pointer on the card, opens the
## piece's details: what it is and how it works (DETAILS).
##
## The quick-select bar along the bottom: ten slots, keys 1 to 9 and 0,
## empty to begin. A number pressed with the pointer resting on a card
## in the menu puts that piece in that slot; pressed in the view it takes
## the slot's piece in hand, or puts it away if it is in hand already.
## The slots are kept with what is built.
##
## The mouse: a click uses a thing (left click is the "interact" action,
## with E), a right click changes it (aims a piece, turns a gate's ring).
## Nothing carries a floating label and the screen carries almost no help
## text: whatever can be used or read (a `view` the player's ray meets,
## or a built piece within REACH) turns the crosshair into a brass ring
## while it is on it, and I shows its card, what it is and what it does,
## until the crosshair leaves it (its `inspect_text`). The line under the
## view speaks only when something cannot be done, or which side of a
## latch a beam will strike.
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
## With empty hands: a click on a lantern opens or closes it; E on any
## other piece but a radiometer looks through it to aim it (BenchScope);
## a right click on a piece's brass rod takes the piece up to move it, as
## G does (the rod has a solid of its own, fatter than it, naming its
## piece); a right click on one takes it up to aim, its beam following the
## crosshair (settling on any piece it is on) until a click fixes it or a
## right click or Esc leaves it as it was.
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
## radiometer whirs softly as its vanes spin. Everything built is
## kept in the world's own save (SAVE_PATH on the cozy island).
##
## It stands in any BuildWorld: the world gives it the player, the
## ground's height and the pieces' materials in its look.
##
## Under sunlight (`sun_rules`, the test island's; BenchLight) light has
## to come from somewhere: the menu offers the sun collector in place of
## the lantern, the push and pull lamps and the track, the crystals read
## light without sending any, and the pieces' texts say so (SUN_TEXTS).
## A collector is a parabolic dish on a fork mount above a lantern-bodied
## turning head (SunDish), the dish turned each frame to face the sun as
## it stood when the collector was last aimed or set down (meta
## "sun_set"); the light comes down the mount to the head, which aims the
## beam.

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
const ROD_LAYER := 8                    # the rods' solids: met by the crosshair, not by beams

## What can be built, in the tray's order: key, name. The first ten have
## the number keys 1 to 9 and 0.
const ITEMS := [["floor", "Floor"], ["lantern", "Lantern"], ["gate", "Opening gate"],
		["closing_gate", "Closing gate"], ["and", "AND"], ["or", "OR"], ["not", "NOT"], ["latch", "Latch"],
		["on_delay", "Hourglass"], ["off_delay", "Afterglow"], ["rise", "Rising spark"], ["fall", "Falling spark"],
		["radiometer", "Radiometer"], ["mirror", "Mirror"], ["splitter", "Splitter"], ["lens", "Lens"],
		["push_lamp", "Push lamp"], ["pull_lamp", "Pull lamp"], ["track", "Track and cart"],
		["collector", "Sun collector"]]
## Free light: kept out of the menu under sunlight.
const FREE_LIGHT := ["lantern", "push_lamp", "pull_lamp", "track"]
const BEAMS := {"push_lamp": "push", "pull_lamp": "pull"}   # lamps sending force beams, by kind
const TRACK_COLOUR := Color(0.6, 0.45, 0.32)
const GATES := {"gate": false, "closing_gate": true}   # key -> closing
const GATE_COLOUR := Color(0.92, 0.72, 0.34)
const KINDS := {"lantern": LumenPart.Kind.LANTERN, "and": LumenPart.Kind.AND, "or": LumenPart.Kind.OR,
		"not": LumenPart.Kind.NOT, "latch": LumenPart.Kind.LATCH, "on_delay": LumenPart.Kind.TON,
		"off_delay": LumenPart.Kind.TOF, "rise": LumenPart.Kind.RISE, "fall": LumenPart.Kind.FALL,
		"radiometer": LumenPart.Kind.RADIOMETER, "push_lamp": LumenPart.Kind.LANTERN,
		"pull_lamp": LumenPart.Kind.LANTERN, "collector": LumenPart.Kind.LANTERN}
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
	"collector": {"lamp": "drum", "metal": "brass"},
}
const FLOOR_COLOUR := Color(0.85, 0.7, 0.5)
const GLASS_COLOUR := Color(0.85, 0.9, 1.0)
const DELAYS := [1.0, 2.0, 3.0, 5.0, 8.0, 13.0]

## What a piece tells the player looking at it. Drafts.
const NOTES := {
	"lantern": "Lantern\nA click opens or closes its shutter; a right click aims it.",
	"and": "AND crystal\nShines while every beam striking it is lit.",
	"or": "OR crystal\nShines while any beam striking it is lit.",
	"not": "NOT crystal\nShines while no lit beam strikes it.",
	"latch": "Latch crystal\nA lit beam striking its left side lights it, one striking its right side puts it out; between, it remembers.",
	"on_delay": "Hourglass, %s s\nShines once a beam striking it has stayed lit that long. T: change the time.",
	"off_delay": "Afterglow crystal, %s s\nShines while a beam striking it is lit, and that long after. T: change the time.",
	"rise": "Rising spark\nOne flash when a beam striking it lights.",
	"fall": "Falling spark\nOne flash when a beam striking it goes dark.",
	"radiometer": "Radiometer\nIts vanes spin in the light, whirring softly.",
	"gate": "Opening gate\nLets a beam through its ring while a lit beam strikes the bulb above it.",
	"closing_gate": "Closing gate\nStops a beam at its ring while a lit beam strikes the bulb above it.",
	"push_lamp": "Push lamp\nIts red beam on a cart's copper ball pushes the cart along its track, away from the lamp.\nA click opens or closes it; a right click aims it.",
	"pull_lamp": "Pull lamp\nIts green beam on a cart's copper ball pulls the cart along its track, toward the lamp.\nA click opens or closes it; a right click aims it.",
	"track": "Track and cart\nPush and pull beams on the copper ball drive the cart along the track.",
	"mirror": "Mirror\nTurns a beam off its silvered face; a little of its reach is lost.",
	"splitter": "Splitter\nSends a beam on through and aside as well, each with half its reach.",
	"lens": "Lens\nA beam passing through it reaches twice as far again.",
}
## The menu's groups, in order, and what each piece does, one line
## each. Drafts.
const GROUPS := [[["Floors", ["floor"]], ["Lamps", ["collector", "lantern", "push_lamp", "pull_lamp"]]],
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
	"radiometer": "its vanes spin in the light, whirring softly.",
	"track": "a cart on rails, driven by push and pull beams on its copper ball.",
}
## Each piece's details, opened from its card. Drafts.
const DETAILS := {
	"floor": "A square of boards two metres across on legs, set level whatever the ground does underneath. Placed within a metre of the place beside another floor it settles flush against it, so floors join into a deck. Pieces stand on it, and moving a floor carries them with it.",
	"lantern": "A lamp with a shutter. While the shutter is open it sends a gold beam straight ahead; a click opens and shuts it. A gold beam is the signal every crystal and gate reads: lit or dark. A right click aims it at what you look at.",
	"push_lamp": "A lantern with red glass. Its red beam is no signal: striking the copper ball on a cart's pole it pushes the cart along its track, away from the lamp. A click opens and shuts it.",
	"pull_lamp": "A lantern with green glass. Its green beam is no signal: striking the copper ball on a cart's pole it pulls the cart along its track, toward the lamp. A click opens and shuts it.",
	"and": "A crystal that shines, sending a gold beam of its own onward, while every beam striking it is lit. Two lanterns aimed at it make it shine only while both are open.",
	"or": "A crystal that shines, sending a gold beam of its own onward, while any beam striking it is lit.",
	"not": "A crystal that shines while no lit beam strikes it; a lit beam puts it out. It turns a signal round.",
	"latch": "A crystal that remembers. A lit beam striking its left side lights it, one striking its right side puts it out, and with neither lit it stays as it was. While aiming a beam at it, the line under the view says which side the beam will strike.",
	"on_delay": "An hourglass. It shines once a beam striking it has stayed lit for its time, and goes dark the moment the beam does. T changes the time, from 1 to 13 seconds. It keeps a flicker from starting anything.",
	"off_delay": "A crystal that lights the moment a beam striking it lights, and stays lit for its time after the beam goes dark. T changes the time, from 1 to 13 seconds. It keeps a short gap from stopping anything.",
	"rise": "One short flash the moment a beam striking it lights, then dark however long the beam stays lit: for counting, or for starting something once.",
	"fall": "One short flash the moment a beam striking it goes dark.",
	"gate": "A brass ring with a glass bulb above it. A beam through the ring passes only while a lit beam strikes the bulb. Gates in a row along one beam make an AND. A right click turns its ring toward what you look at.",
	"closing_gate": "A ring like the opening gate's, but it stops the beam through it while its bulb is lit and lets it pass while the bulb is dark. A right click turns its ring toward what you look at.",
	"mirror": "A silvered glass that turns a beam off its face as a mirror turns light, losing a little of the beam's reach. A right click aims the beam it sends on.",
	"splitter": "Half-silvered glass. A beam striking it goes on straight through and is turned aside as well, each with half the reach.",
	"lens": "A beam passing through it reaches twice as far again, for carrying a signal across a distance.",
	"radiometer": "Four vanes on a needle in a glass bulb, dark on one face and bright on the other. A lit beam striking the bulb spins them, faster the more light, with a soft whir.",
	"track": "Sixteen metres of track with a cart on it, carrying a copper ball on a pole. Red beams on the ball push the cart away from their lamp and green ones pull it toward theirs, up to eight metres a second; gold beams do nothing to it.",
}
## What the pieces are under sunlight, where it differs: their card
## ("note"), the menu's line ("menu") and their details ("details").
## Drafts.
const SUN_TEXTS := {
	"collector": {
		"note": "Sun collector\nA dish gathers the sun and sends it down its mount and out of the head as a beam, while the shutter is open (a click). A right click aims the beam and turns the dish to the sun where it stands now; as the sun moves on, the beam fades.",
		"menu": "a mirrored dish that gathers the sun into a beam.",
		"details": "The first light that can be made. A dish two metres across, its face a paraboloid of polished metal, gathers the sun to a point eighty centimetres in front of it; a small curved mirror held on three struts just short of that point sends the light back through a hole in the dish's middle, along the axle, down the fork and the column to the head, which sends it out as a beam wherever it is aimed. At noon in clear air it carries over two kilowatts; less as the sun sinks, nothing in shadow or at night. A click opens and shuts its shutter. A right click aims the beam, and turns the dish to the sun where it is now; the sun moves fifteen degrees an hour, and three degrees off it the dish's light misses the hole, so turn it again from time to time. The beam runs straight and narrow, and fades as it goes, losing half its light about every five and a half metres: at noon it lights a crystal some fifty metres off, less as the sun sinks. A lens along the way makes it fade half as fast from there.",
	},
	"and": {"note": "AND crystal\nGlows while every beam striking it is lit. It sends no light of its own.",
		"menu": "glows while every beam striking it is lit; it sends no light.",
		"details": "A crystal that glows while every beam striking it carries enough light, three watts or more. It reads light and sends none: to let one beam govern another, use a gate."},
	"or": {"note": "OR crystal\nGlows while any beam striking it is lit. It sends no light of its own.",
		"menu": "glows while any beam striking it is lit; it sends no light.",
		"details": "A crystal that glows while any beam striking it carries enough light. It reads light and sends none."},
	"not": {"note": "NOT crystal\nGlows while no lit beam strikes it. It sends no light of its own.",
		"menu": "glows while no lit beam strikes it; it sends no light.",
		"details": "A crystal that glows while nothing lit strikes it. It sends no light; a closing gate is the NOT that governs a beam."},
	"latch": {"note": "Latch crystal\nLit by a beam on its left, put out by one on its right; it remembers between. It sends no light of its own.",
		"menu": "lit from its left, put out from its right; remembers; sends no light.",
		"details": "A crystal that remembers: a lit beam on its left lights it, one on its right puts it out, and with neither it stays as it was. It shows a state and sends no light."},
	"on_delay": {"menu": "glows once a beam striking it has stayed lit a while; sends no light.",
		"details": "An hourglass that glows once a beam striking it has stayed lit for its time, from 1 to 13 seconds (T changes it). It sends no light."},
	"off_delay": {"menu": "glows while a beam is lit and a while after; sends no light.",
		"details": "A crystal that glows the moment a beam striking it lights and stays lit for its time after it goes dark (T changes it). It sends no light."},
	"rise": {"menu": "one flash when a beam striking it lights; sends no light."},
	"fall": {"menu": "one flash when a beam striking it goes dark; sends no light."},
	"gate": {"details": "The piece that lets one beam govern another. A brass ring with a glass bulb above it: a beam through the ring passes only while a lit beam strikes the bulb (three watts or more). Gates in a row along one beam make an AND; two beams brought to the same place make an OR. A right click turns its ring toward what you look at."},
	"closing_gate": {"details": "Like the opening gate, but it stops the beam through its ring while its bulb is lit, and lets it pass while the bulb is dark: the NOT. A right click turns its ring toward what you look at."},
	"mirror": {"details": "A silvered glass that turns a beam off its face without losing any of it. A right click aims the beam it sends on."},
	"splitter": {"details": "Half-silvered glass: a beam striking it goes on straight through and is turned aside as well, half its light each way."},
	"lens": {"menu": "a beam passing through it fades half as fast from there.",
		"details": "A beam passing through a lens loses a twentieth of its light there, and from there fades half as fast, so it carries a signal twice as far again."},
	"radiometer": {"details": "Four vanes on a needle in a glass bulb, dark on one face and bright on the other, that spin while a beam striking it carries enough light, with a soft whir."},
}
const MENU_HELP := ""
const AIM_NOTE := "\nA right click aims it at what you look at; E looks through it."

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
var _polish: StandardMaterial3D         # a collector's dish
var _iron: StandardMaterial3D           # its back and mount
var building := false
var item := 0
var lift := 0.0

var _whirs := {}                        # radiometer -> its whir's speaker
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
var _carry_building := false            # whether something was in hand when the carrying began
var _carry_item := 0                    # and what
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
var _cross := TextureRect.new()
var _plus: ImageTexture                 # the crosshair
var _ring: ImageTexture                 # the crosshair over something to use or read
var _on_piece: Node3D = null            # the piece the crosshair is on, within reach
var _on_thing: Node = null              # what the crosshair is on that can be used or read
## The quick-select slots: a piece's key, or "" for none.
var slots: Array[String] = ["", "", "", "", "", "", "", "", "", ""]
var _slot_cells: Array[PanelContainer] = []
var _slot_pictures: Array[TextureRect] = []
var _bar: HBoxContainer
var _hover_item := -1                   # the card the pointer rests on, or -1
var _textures := {}                     # item index -> its picture
var _details: PanelContainer
var _details_picture: TextureRect
var _details_name: Label
var _details_text: Label
var _card: PanelContainer               # the inspected thing's card
var _card_title: Label
var _card_text: Label
var _inspected: Node = null
var _inspect_grace := 0.0
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
## `sun` puts the light under sunlight (BenchLight.sun_rules).
func _init(owner_island: BuildWorld, save_path := SAVE_PATH, demo := true, sun := false) -> void:
	island = owner_island
	_save_path = save_path
	_demo = demo
	light.sun_rules = sun
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
	_polish = island.surface("", 1.0, Color(0.9, 0.92, 0.95), 0.08, Color(0.92, 0.94, 0.98))
	_polish.metallic = 0.95
	_iron = island.surface("", 1.0, Color(0.3, 0.32, 0.33), 0.55, Color(0.4, 0.43, 0.45))
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
	if key == "collector":
		piece.set_meta("sun_set", light.sun)
	add_child(piece)
	piece.call("aim", yaw, pitch)
	pieces.append(piece)
	light.add(piece)
	relabel(piece)
	if piece is LumenPart and (piece as LumenPart).kind == LumenPart.Kind.RADIOMETER:
		var whir := AudioStreamPlayer3D.new()
		if DisplayServer.get_name() != "headless":
			var loop := load("res://audio/radiometer_whir_loop.wav") as AudioStreamWAV
			loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop.loop_begin = 0
			loop.loop_end = int(loop.get_length() * loop.mix_rate)
			whir.stream = loop
			whir.autoplay = true
		whir.volume_db = -80.0
		whir.unit_size = 1.5
		piece.add_child(whir)
		_whirs[piece] = whir
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
	if key == "collector":
		part.set_meta("collector", true)
		var dish := SunDish.new(_polish, _iron, brass)
		part.add_child(dish)
		part.set_meta("dish", dish)
	return part


## Under sunlight, whether the menu offers `key`.
func offered(key: String) -> bool:
	return not FREE_LIGHT.has(key) if light.sun_rules else key != "collector"


## A piece's text from `table`, the sunlight's own where it has one.
func _text(table: Dictionary, which: String, key: String) -> String:
	if light.sun_rules and SUN_TEXTS.has(key) and (SUN_TEXTS[key] as Dictionary).has(which):
		return SUN_TEXTS[key][which]
	return table.get(key, "")


## A collector's dish turned to the sun as it stood when the collector
## was last aimed or set down.
func _turn_dish(part: LumenPart) -> void:
	var dish: SunDish = part.get_meta("dish")
	dish.point_at(part.get_meta("sun_set", light.sun))
	part.set_meta("mirror_at", dish.centre())


## A piece (a gate's sensor too) on collision layer `layer`.
func _set_layer(n: Node3D, layer: int) -> void:
	if n.has_meta("rod_body"):
		(n.get_meta("rod_body") as CollisionObject3D).collision_layer = ROD_LAYER if layer != 0 else 0
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
	_whirs.erase(piece)
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
	var text: String = _text(NOTES, "note", key)
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
		if piece.has_meta("rod_body"):
			q.exclude.append((piece.get_meta("rod_body") as CollisionObject3D).get_rid())
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
		# The rod is something to take hold of: a right click on it moves
		# its piece. Its solid is fatter than the rod, to be easy to point at.
		var body: StaticBody3D = piece.get_meta("rod_body") if piece.has_meta("rod_body") else null
		if body == null:
			body = StaticBody3D.new()
			body.collision_layer = ROD_LAYER if piece.visible else 0
			body.collision_mask = 0
			body.set_meta("rod_of", piece)
			var c := CollisionShape3D.new()
			c.shape = CylinderShape3D.new()
			body.add_child(c)
			piece.add_child(body)
			piece.set_meta("rod_body", body)
		var shape := (body.get_child(0) as CollisionShape3D).shape as CylinderShape3D
		shape.radius = 0.07
		shape.height = maxf(top - bottom, 0.02)
		body.global_position = rod.global_position
		body.global_rotation = Vector3.ZERO


## ---- where the thing in hand goes -----------------------------------------

## What the crosshair is on, within reach: the ray's hit (empty if none).
func _look_hit(exclude: Array[RID] = []) -> Dictionary:
	var cam := island.player.camera
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (REACH + island.player.zoom_offset()), 1 | 4 | ROD_LAYER)
	var skip: Array[RID] = [island.player.get_rid()]
	skip.append_array(exclude)
	q.exclude = skip
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and (hit["collider"] as Node).has_meta("part_of"):
		hit["collider"] = (hit["collider"] as Node).get_meta("part_of")
		hit["sensor"] = true
	elif not hit.is_empty() and (hit["collider"] as Node).has_meta("rod_of"):
		hit["collider"] = (hit["collider"] as Node).get_meta("rod_of")
		hit["rod"] = true
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
	_carry_building = building
	_carry_item = item
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
	q.collision_mask = 0xFFFFFFFF & ~ROD_LAYER
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
			if r.has_meta("collector"):
				r.set_meta("sun_set", light.sun)
		for target: Dictionary in _targets.values() + links.values():
			if target.get("tile") == old:
				target["tile"] = tile
	else:
		_carried.global_position = _at
		_hide(_carried, false)
		if _carried.has_meta("collector"):
			_carried.set_meta("sun_set", light.sun)
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
	_end_carry()


## The carried thing back where it stood.
func _put_back() -> void:
	if _carried == null:
		return
	for m: Node3D in [_carried] + _riders:
		_hide(m, false)
	_carried = null
	_riders.clear()
	_targets.clear()
	_end_carry()


## After carrying, the hands as they were: empty, or holding what they held.
func _end_carry() -> void:
	if _carry_building:
		_pick(_carry_item)
	else:
		_set_building(false)


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
		# I with the pointer on a card opens its details.
		if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_I and _hover_item >= 0:
			_show_details(_hover_item)
			get_viewport().set_input_as_handled()
			return
		# A number with the pointer on a card fills that slot.
		var n := _slot_of(key)
		if n >= 0 and _hover_item >= 0:
			slots[n] = str(ITEMS[_hover_item][0])
			_refresh_bar()
			changed()
			get_viewport().set_input_as_handled()
			return
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
			# Aiming a collector sets its mirror for the sun where it is now.
			if _aiming.has_meta("collector"):
				_aiming.set_meta("sun_set", light.sun)
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
		# With empty hands, a right click changes a piece: on its rod it
		# takes the piece up to move it; on the piece it aims it, or turns a
		# gate's ring (one that turns no beam is taken up instead).
		var hit := _look_hit()
		if hit.is_empty() or not is_piece(hit["collider"]):
			return
		if hit.get("rod", false) or not turns(hit["collider"]):
			_take_up(hit["collider"] as Node3D)
		else:
			_start_aim(hit["collider"])
	elif key != null and key.pressed and not key.echo and key.physical_keycode == KEY_I:
		# I reads what the crosshair is on, or puts its card away.
		_inspect(null if _inspected != null else _on_thing)
	elif _slot_of(key) >= 0:
		_use_slot(_slot_of(key))
	elif event.is_action_pressed("interact") and not (building and click != null):
		# Using a piece: a click or E opens or closes a lantern; E looks
		# through any other (a click on one does nothing). Anything else is
		# left to the player, who uses what it is looking at.
		var hit := _look_hit()
		if hit.is_empty() or not is_piece(hit["collider"]):
			return
		var v := hit["collider"] as Node3D
		if v is LumenPart and (v as LumenPart).kind == LumenPart.Kind.LANTERN:
			toggle(v as LumenPart)
		elif sends(v) and key != null:
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
	for r: LumenPart in _whirs:
		# The vanes' whir, as loud and high as they spin: a soft sound,
		# heard close by.
		var whir := _whirs[r] as AudioStreamPlayer3D
		whir.volume_db = linear_to_db(clampf(r.spin, 0.0001, 1.0)) - 28.0
		whir.pitch_scale = 0.6 + 0.6 * r.spin


func _process(delta: float) -> void:
	var player := island.player
	var free := scope.held == null and not player.input_locked and player.look_held_by == null
	if _aiming != null and free:
		_follow_aim()
	for piece in pieces:
		if piece.has_meta("collector") and piece.visible:
			_turn_dish(piece as LumenPart)
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
	_on_thing = null
	if looking and _aiming == null and not building and _carried == null:
		_on_thing = _on_piece if _on_piece != null else player.look_view()
		if _on_thing != null and not (_on_thing.has_method("inspect_text") or _on_thing.has_method("use")):
			_on_thing = null
	_cross.visible = looking
	_cross.texture = _ring if _on_thing != null else _plus
	# The card stays while the crosshair stays on what it tells of.
	if _inspected != null:
		if not is_instance_valid(_inspected) or not looking:
			_inspect(null)
		elif _on_thing == _inspected:
			_inspect_grace = 0.4
		else:
			_inspect_grace -= delta
			if _inspect_grace <= 0.0:
				_inspect(null)
	_bar.visible = free and not (_aiming != null)
	for k in slots.size():
		var held := building and slots[k] != "" and str(ITEMS[item][0]) == slots[k]
		_slot_cells[k].add_theme_stylebox_override("panel", _picked if held else _plain)
	# The menu closes if the view was taken back some other way.
	if _menu_open and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not free):
		_close_menu(false)
	_hint.visible = looking and (building or _aiming != null or _on_piece != null or _on_thing != null)
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
		var text := ""
		var hit := _look_hit([(_aiming as CollisionObject3D).get_rid()])
		if not hit.is_empty() and hit["collider"] is LumenPart and is_piece(hit["collider"]):
			var latch := hit["collider"] as LumenPart
			if latch.kind == LumenPart.Kind.LATCH:
				var right := latch.global_transform.basis * (Basis.from_euler(Vector3(latch.pitch, latch.yaw, 0.0)) * Vector3.RIGHT)
				var dir := (latch.global_position - _aiming.global_position).normalized()
				text = ("It strikes the latch from its left: it will light it." if dir.dot(right) > 0.0
						else "It strikes the latch from its right: it will put it out.")
		return text
	if _carried != null or building:
		return _why if not _ok else ""
	return ""


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
	_plus = _crosshair(false)
	_ring = _crosshair(true)
	_cross.texture = _plus
	_cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_cross.offset_left = -16.0
	_cross.offset_right = 16.0
	_cross.offset_top = -16.0
	_cross.offset_bottom = 16.0
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.visible = false
	root.add_child(_cross)
	_build_bar(root)
	_build_card(root)
	_build_menu(root)
	_build_details(root)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.97, 0.93, 0.82))
	_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.offset_bottom = -96.0
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
				if not offered(key):
					continue
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
				card.mouse_entered.connect(func() -> void:
					_hover_item = i
					_about.text = "%s: %s" % [ITEMS[i][1], _text(MENU_NOTES, "menu", key)])
				card.mouse_exited.connect(func() -> void:
					if _hover_item == i:
						_hover_item = -1
					_about.text = MENU_HELP)
				var more := Button.new()
				more.text = "i"
				more.focus_mode = Control.FOCUS_NONE
				more.add_theme_font_size_override("font_size", 11)
				more.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
				more.offset_left = -20.0
				more.offset_right = -3.0
				more.offset_top = 3.0
				more.offset_bottom = 20.0
				more.pressed.connect(func() -> void: _show_details(i))
				card.add_child(more)
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
	return -1


## Opening the menu puts away what was in hand.
func _open_menu() -> void:
	_set_building(false)
	_inspect(null)
	_hover_item = -1
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
	_details.visible = false
	_hover_item = -1
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
		if not offered(key):
			continue
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
		if thing.has_meta("collector"):
			thing.set_meta("sun_set", Vector3(-0.4, 0.8, 0.45).normalized())
			_turn_dish(thing as LumenPart)
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
			_textures[pair[0]] = ImageTexture.create_from_image(picture)
			(_pictures[pair[0]] as TextureRect).texture = _textures[pair[0]]
		studio.queue_free()
	_refresh_bar()


## ---- the quick-select bar, details, inspecting ---------------------------------

## The slot a key is for: 1 to 9 the first nine, 0 the tenth; -1 for any
## other key.
static func _slot_of(key: InputEventKey) -> int:
	if key == null or not key.pressed or key.echo:
		return -1
	if key.physical_keycode >= KEY_1 and key.physical_keycode <= KEY_9:
		return key.physical_keycode - KEY_1
	if key.physical_keycode == KEY_0:
		return 9
	return -1


## A slot's piece taken in hand, or put away if it is in hand already.
func _use_slot(n: int) -> void:
	if slots[n] == "" or _carried != null or _aiming != null:
		return
	var i := _index_of(slots[n])
	if i < 0:
		return
	if building and item == i:
		_set_building(false)
		return
	_inspect(null)
	_pick(i)
	_set_building(true)


func _build_bar(root: Control) -> void:
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 4)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bar.offset_bottom = -12.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bar)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.09, 0.07, 0.05, 0.6)
	back.set_corner_radius_all(6)
	for k in 10:
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(58, 60)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var frame := Control.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(frame)
		var picture := TextureRect.new()
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(picture)
		var number := Label.new()
		number.text = str((k + 1) % 10)
		number.position = Vector2(2, -2)
		number.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
		number.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06))
		number.add_theme_constant_override("outline_size", 4)
		frame.add_child(number)
		_bar.add_child(cell)
		_slot_cells.append(cell)
		_slot_pictures.append(picture)
	_refresh_bar()


func _refresh_bar() -> void:
	for k in _slot_pictures.size():
		_slot_pictures[k].texture = _textures.get(_index_of(slots[k])) if slots[k] != "" else null


## A piece's details over the menu: its picture, its name, what it does
## and how it works; Back closes it.
func _build_details(root: Control) -> void:
	_details = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.09, 0.06, 0.97)
	style.border_color = Color(0.85, 0.66, 0.36)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	_details.add_theme_stylebox_override("panel", style)
	_details.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_details.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_details.grow_vertical = Control.GROW_DIRECTION_BOTH
	_details.custom_minimum_size = Vector2(520, 0)
	_details.visible = false
	root.add_child(_details)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_details.add_child(row)
	_details_picture = TextureRect.new()
	_details_picture.custom_minimum_size = Vector2(150, 142)
	_details_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_details_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_details_picture)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	row.add_child(column)
	_details_name = Label.new()
	_details_name.add_theme_font_size_override("font_size", 18)
	_details_name.add_theme_color_override("font_color", Color(0.98, 0.86, 0.58))
	column.add_child(_details_name)
	_details_text = Label.new()
	_details_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_text.custom_minimum_size = Vector2(330, 0)
	_details_text.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84))
	column.add_child(_details_text)
	var back := Button.new()
	back.text = "Back"
	back.focus_mode = Control.FOCUS_NONE
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.pressed.connect(func() -> void: _details.visible = false)
	column.add_child(back)


func _show_details(i: int) -> void:
	var key := str(ITEMS[i][0])
	_details_name.text = str(ITEMS[i][1])
	_details_text.text = _text(DETAILS, "details", key)
	_details_picture.texture = _textures.get(i)
	_details.visible = true
	_details.reset_size()


## The inspected thing's card, at the right of the view.
func _build_card(root: Control) -> void:
	_card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.07, 0.05, 0.86)
	style.border_color = Color(0.72, 0.56, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_card.add_theme_stylebox_override("panel", style)
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.offset_right = -40.0
	_card.custom_minimum_size = Vector2(320, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	root.add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_card.add_child(column)
	_card_title = Label.new()
	_card_title.add_theme_font_size_override("font_size", 16)
	_card_title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.58))
	_card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_card_title)
	_card_text = Label.new()
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.custom_minimum_size = Vector2(296, 0)
	_card_text.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84))
	column.add_child(_card_text)


## Shows `thing`'s card (its first line the title, the rest the text), or
## hides the card for null or a thing with nothing to read.
func _inspect(thing: Node) -> void:
	var text := ""
	if thing != null and is_instance_valid(thing) and thing.has_method("inspect_text"):
		text = str(thing.call("inspect_text"))
	_inspected = thing if text != "" else null
	_card.visible = text != ""
	if text == "":
		return
	var lines := text.split("\n", true, 1)
	_card_title.text = lines[0]
	_card_text.text = lines[1] if lines.size() > 1 else ""
	_card_text.visible = lines.size() > 1
	_inspect_grace = 0.4
	_card.reset_size()


## The crosshair: a plus, or a brass ring over something to use or read.
static func _crosshair(ring: bool) -> ImageTexture:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5) - c
			var on := 0.0
			var rim := 0.0
			if ring:
				var d := absf(p.length() - 9.0)
				on = clampf(1.6 - d, 0.0, 1.0)
				rim = clampf(2.8 - d, 0.0, 1.0)
				var dot := clampf(2.2 - p.length(), 0.0, 1.0)
				on = maxf(on, dot)
				rim = maxf(rim, clampf(3.4 - p.length(), 0.0, 1.0))
			else:
				var arm := minf(absf(p.x), absf(p.y))
				var reach := maxf(absf(p.x), absf(p.y))
				on = clampf(1.5 - arm, 0.0, 1.0) * clampf(8.5 - reach, 0.0, 1.0)
				rim = clampf(2.6 - arm, 0.0, 1.0) * clampf(9.6 - reach, 0.0, 1.0)
			var fill := Color(1.0, 0.84, 0.45) if ring else Color(1, 1, 1)
			var col := Color(0, 0, 0, 0.55 * rim).blend(Color(fill, on * 0.92))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


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
			if part.has_meta("collector"):
				var set_for: Vector3 = part.get_meta("sun_set", light.sun)
				entry["sun_set"] = [set_for.x, set_for.y, set_for.z]
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
		file.store_string(JSON.stringify({"floor": floor_list, "pieces": list, "demo": DEMO_VERSION if _demo_built else 0,
				"slots": slots}))


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
	if data.get("slots") is Array:
		var saved: Array = data["slots"]
		for k in mini(saved.size(), slots.size()):
			slots[k] = str(saved[k]) if _index_of(str(saved[k])) >= 0 and str(saved[k]) != "" else ""
		_refresh_bar()
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
			var sun_set: Variant = d.get("sun_set")
			if piece.has_meta("collector") and sun_set is Array and (sun_set as Array).size() >= 3:
				piece.set_meta("sun_set", Vector3(float(sun_set[0]), float(sun_set[1]), float(sun_set[2])).normalized())
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
