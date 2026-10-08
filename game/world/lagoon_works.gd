class_name LagoonWorks
extends BeachSite
## The lagoon works: a long wharf out over the cozy island's lagoon with
## six tidepools along it, fed with broth and harvested by a little cart,
## powered by windmills far out at sea that beam their energy home; run
## by light-beam logic (LumenPart, LumenBeam).
##
## The wharf. Planks on piles from the beach out about 70 m, with a ramp
## at the shore and railings; along its sides six raised stone basins
## (TidePool), each home to one kind of creature that makes something
## while fed: glimmer, pearls, spine-chalk, sea-silk, star-salt,
## jelly-light. A broth kettle and tank on the beach feed two pipes down
## the wharf, a valve to each pool. A cart on rails down the middle visits
## the ripe pools, dips its crane's scoop into each cup, and brings the
## harvest back to a sorting shed of six great jars; a bell rings as it
## comes home.
##
## Power. Four windmills stand 250 to 650 m out (SeaMill), where the wind
## blows harder; each sends a beam to a collector crystal on a tower at
## the wharf's end. A glowing conduit carries the energy to four Leyden
## jars on the beach, the works' store. The kettle, the pool valves and
## the cart draw on it; with the jars empty they stop.
##
## The circuit, in ladder terms:
##   FEED pool n  = pool n hungry AND broth in the tank AND charge in the jars
##   DISPATCH     = (any pool ripe) AND the cart home AND charge in the jars
##   KETTLE       = NOT the tank full AND charge in the jars
##   BELL         = rising edge of the cart home
## The cart's round, once sent: out to each ripe pool in turn, a dip at
## each, home when the hold is full or none is left, and unloading.

const BEARING := 30.0
const DECK := 1.1                       # the deck's height
const WHARF_V0 := 6.0                   # the deck's landward end (v)
const WHARF_V1 := -70.0                 # its seaward end
const HALF := 3.0                       # half the deck's width
const POOL_V := [-12.0, -20.0, -28.0, -36.0, -44.0, -52.0]
const POOL_OFF := 5.6                   # pools' centres off the wharf's middle
const MILLS := [Vector2(-70, -240), Vector2(95, -350), Vector2(-150, -470), Vector2(175, -590)]
const CART_HOME := 4.0                  # v
const CART_SPEED := 3.0
const JARS := 4.0                       # the store's capacity
const HOLD := 4.0                       # cupfuls the cart carries

var pools: Array[TidePool] = []
var mills: Array[SeaMill] = []

var _energy := 1.2
var _broth := 0.6                       # the tank, 0 to 1
var _kettle := 0.0
var _valves: Array[float] = [0, 0, 0, 0, 0, 0]
var _wind_noise := FastNoiseLite.new()
var _clock := 0.0
var _inflow := 0.0

# the cart
enum Cart { HOME, OUT, DIP, BACK, UNLOAD }
var _cart := Cart.HOME
var _cart_v := CART_HOME
var _cart_timer := 0.0
var _route: Array[int] = []
var _hold := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _jars := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _boom_side := 0.0
var _boom_dip := 0.0
var _last_joint := 0

# parts
var _pool_lanterns: Array = []          # [hungry, ripe] per pool
var _r_valves: Array[LumenPart] = []
var _feeds: Array[LumenPart] = []
var _l := {}
var _r := {}
var _was := {}

# pieces
var _cart_node: Node3D
var _boom: Node3D
var _scoop_mat: StandardMaterial3D
var _hold_heap: MeshInstance3D
var _jar_fills: Array[MeshInstance3D] = []
var _store_glows: Array[StandardMaterial3D] = []
var _crystal_mat: StandardMaterial3D
var _crystal_light: OmniLight3D
var _conduit_mat: StandardMaterial3D
var _broth_fill: MeshInstance3D
var _kettle_fire: GPUParticles3D
var _kettle_light: OmniLight3D
var _kettle_steam: GPUParticles3D
var _valve_wheels: Array[Node3D] = []
var _charge_needle: Node3D

# sounds
var _snd_hum: AudioStreamPlayer3D
var _snd_wind: AudioStreamPlayer3D
var _snd_bubble: AudioStreamPlayer3D
var _snd_clack: AudioStreamPlayer3D
var _snd_bell: AudioStreamPlayer3D
var _snd_crane: AudioStreamPlayer3D
var _snd_clanks: Array[AudioStreamPlayer3D] = []

var _plank: StandardMaterial3D
var _deck: StandardMaterial3D
var _iron: StandardMaterial3D
var _copper: StandardMaterial3D
var _stone: StandardMaterial3D
var _stone_inside: StandardMaterial3D
var _canvas: StandardMaterial3D
var _glass: StandardMaterial3D


func _init(owner_island: CozyIsland) -> void:
	super(owner_island, BEARING)
	name = "LagoonWorks"
	_wind_noise.seed = 57
	_wind_noise.frequency = 1.0


static func centre(owner_island: CozyIsland) -> Vector3:
	return BeachSite.site_point(owner_island, BEARING, 0.0, 9.0)


## The wharf, for the island's walls: [shore point, far point, half width].
static func pier(owner_island: CozyIsland) -> Array:
	return [BeachSite.site_point(owner_island, BEARING, 0.0, WHARF_V0 + 4.0),
			BeachSite.site_point(owner_island, BEARING, 0.0, WHARF_V1), HALF]


func _ready() -> void:
	add_child(_site)
	_materials()
	_build_wharf()
	_build_pools()
	_build_shore()
	_build_cart()
	_build_power()
	_build_circuit()
	_place_beams()
	_build_sounds()


func _materials() -> void:
	_wood = island.surface("weathered_wood", 0.8, Color(0.9, 0.88, 0.86), 0.9, Color(0.66, 0.56, 0.46))
	_plank = island.surface("weathered_wood", 0.8, Color(0.95, 0.93, 0.9), 0.9, Color(0.8, 0.68, 0.54))
	# The deck's boards carry their own picture coordinates (a board's
	# grain runs along it) and each its own tone in its vertex colours.
	_deck = island.surface("weathered_wood", 1.0, Color(1.0, 1.0, 1.0), 0.9, Color(1.0, 0.9, 0.76),
			{"line_colour": Color(0.3, 0.24, 0.2)})
	_deck.uv1_triplanar = false
	_deck.uv1_world_triplanar = false
	_deck.uv1_scale = Vector3.ONE
	_deck.vertex_color_use_as_albedo = true
	_stone = island.surface("rough_rock", 0.5, Color(0.7, 0.68, 0.66), 0.9, Color(0.62, 0.6, 0.66))
	_stone_inside = island.surface("rough_rock", 0.5, Color(0.6, 0.58, 0.56), 0.9, Color(0.55, 0.53, 0.6), {"no_line": true})
	_stone_inside.cull_mode = BaseMaterial3D.CULL_DISABLED
	_iron = island.surface("", 1.0, Color(0.1, 0.1, 0.11), 0.45, Color(0.3, 0.3, 0.38))
	_iron.metallic = 0.6
	_brass = island.surface("", 1.0, Color(0.62, 0.46, 0.2), 0.35, Color(0.9, 0.7, 0.32))
	_brass.metallic = 0.85
	_copper = island.surface("", 1.0, Color(0.62, 0.3, 0.18), 0.35, Color(0.92, 0.5, 0.3))
	_copper.metallic = 0.85
	_canvas = island.surface("", 1.0, Color(0.85, 0.82, 0.74), 0.9, Color(0.98, 0.95, 0.86))
	_canvas.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(0.82, 0.92, 1.0, 0.18)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.roughness = 0.04
	_glass.cull_mode = BaseMaterial3D.CULL_DISABLED


## ---- the wharf -------------------------------------------------------------

func _build_wharf() -> void:
	# The deck in 4 m bays, each a solid to walk on, with piles at the
	# bays' corners down to the lagoon's floor; the boards are drawn over
	# them (_build_boards).
	var v := WHARF_V0
	while v > WHARF_V1 + 0.01:
		var v2 := maxf(v - 4.0, WHARF_V1)
		var mid := (v + v2) * 0.5
		var solid := StaticBody3D.new()
		solid.position = at(0, mid, DECK - 0.06)
		var box := BoxShape3D.new()
		box.size = Vector3(HALF * 2.0, 0.12, v - v2)
		var held := CollisionShape3D.new()
		held.shape = box
		solid.add_child(held)
		_site.add_child(solid)
		for u: float in [-HALF + 0.15, HALF - 0.15]:
			var floor_y := ground(u, v2)
			_rod(at(u, v2, floor_y - 0.4), at(u, v2, DECK - 0.12), 0.13, _wood, 8)
		_box(Vector3(HALF * 2.0 + 0.2, 0.18, 0.18), at(0, v2, DECK - 0.25), _wood)
		v = v2
	# The ramp from the beach.
	var g := ground(0, WHARF_V0 + 4.0)
	var ramp_from := at(0, WHARF_V0, DECK - 0.06)
	var ramp_to := at(0, WHARF_V0 + 4.0, g + 0.02)
	var ramp := Transform3D(Basis(Vector3.RIGHT, -atan2(ramp_to.y - ramp_from.y, ramp_to.z - ramp_from.z)), (ramp_from + ramp_to) * 0.5)
	var body := StaticBody3D.new()
	body.transform = ramp
	var shape := BoxShape3D.new()
	shape.size = Vector3(HALF * 2.0, 0.12, ramp_from.distance_to(ramp_to))
	var c := CollisionShape3D.new()
	c.shape = shape
	body.add_child(c)
	_site.add_child(body)
	# Stringers along under the boards, between the beams.
	for u: float in [-HALF + 0.15, -1.0, 1.0, HALF - 0.15]:
		_box(Vector3(0.14, 0.18, WHARF_V0 - WHARF_V1), at(u, (WHARF_V0 + WHARF_V1) * 0.5, DECK - 0.16), _wood)
	_build_boards(ramp, ramp_from.distance_to(ramp_to))
	# Railings: posts every 2 m and two rails.
	for side: float in [-1.0, 1.0]:
		var u := side * (HALF - 0.08)
		var rv := WHARF_V0
		while rv > WHARF_V1:
			_rod(at(u, rv, DECK), at(u, rv, DECK + 1.0), 0.04, _wood, 6)
			rv -= 2.0
		_rod(at(u, WHARF_V0, DECK + 1.0), at(u, WHARF_V1, DECK + 1.0), 0.035, _wood, 6)
		_rod(at(u, WHARF_V0, DECK + 0.5), at(u, WHARF_V1, DECK + 0.5), 0.025, _wood, 6)
	_rod(at(-HALF, WHARF_V1, DECK + 1.0), at(HALF, WHARF_V1, DECK + 1.0), 0.035, _wood, 6)
	# The rails down the middle.
	for u: float in [-0.55, 0.55]:
		_box(Vector3(0.06, 0.06, WHARF_V0 + 2.0 - (POOL_V[5] - 3.0)), at(u, (WHARF_V0 + 2.0 + POOL_V[5] - 3.0) * 0.5, DECK + 0.03), _iron)
	var rv2 := WHARF_V0 + 2.0
	while rv2 > POOL_V[5] - 3.0:
		_box(Vector3(1.5, 0.05, 0.16), at(0, rv2, DECK + 0.005), _wood)
		rv2 -= 0.8


## The deck's boards: laid across the wharf 20 cm wide with a gap of a
## little over a centimetre, each running the width in two lengths that
## butt over a stringer at a point chosen board by board; each board its
## own weathered tone (silver-grey, driftwood, honey, warm brown, now and
## then a dark one) and its own stretch of the grain picture, set a hair
## higher or lower than its neighbours. The ramp from the beach is boarded
## the same way along its slope. One mesh.
func _build_boards(ramp: Transform3D, ramp_length: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3030
	var tones := [Color(0.82, 0.8, 0.76), Color(0.9, 0.85, 0.76), Color(0.95, 0.86, 0.7),
			Color(0.86, 0.76, 0.64), Color(0.9, 0.82, 0.72)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pitch := 0.212
	var width := 0.2
	var thick := 0.07
	var rows := int((WHARF_V0 - WHARF_V1) / pitch)
	var lay := func(centre: Vector3, basis: Basis, length: float) -> void:
		var tone: Color = tones[rng.randi() % tones.size()]
		if rng.randf() < 0.08:
			tone = tone.darkened(0.2)
		tone = tone.lightened(rng.randf_range(-0.06, 0.06))
		var lift := rng.randf_range(-0.006, 0.006)
		_board(st, centre + basis.y * lift, basis, Vector3(length, thick, width), tone,
				Vector2(rng.randf() * 8.0, rng.randf() * 8.0), rng.randf() < 0.5)
	for row in rows:
		var v := WHARF_V0 - pitch * (row + 0.5)
		var joint: float = [-1.0, 1.0, -HALF + 0.15, HALF - 0.15][rng.randi() % 4]
		for piece: Vector2 in [Vector2(-HALF, joint), Vector2(joint, HALF)]:
			var length := piece.y - piece.x - 0.006
			lay.call(at((piece.x + piece.y) * 0.5, v, DECK - thick * 0.5), Basis.IDENTITY, length)
	var ramp_rows := int(ramp_length / pitch)
	for row in ramp_rows:
		var along := -ramp_length * 0.5 + pitch * (row + 0.5)
		lay.call(ramp * Vector3(0.0, 0.06 - thick * 0.5, along), ramp.basis, HALF * 2.0 - 0.006)
	st.generate_tangents()
	var view := MeshInstance3D.new()
	view.name = "Deck"
	view.mesh = st.commit()
	view.mesh.surface_set_material(0, _deck)
	_site.add_child(view)


## One board as a box: `size` x along it, y up, z across; its grain
## picture runs along it (1.2 m to the picture), shifted by `grain`,
## flipped end for end when `flip`.
func _board(st: SurfaceTool, centre: Vector3, basis: Basis, size: Vector3, tone: Color, grain: Vector2, flip: bool) -> void:
	var h := size * 0.5
	var colour := tone.srgb_to_linear()
	# Each face: its normal, and two axes across it (the first along the
	# grain where the face has one).
	var faces := [[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
			[Vector3.BACK, Vector3.RIGHT, Vector3.DOWN], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP],
			[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP]]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var a: Vector3 = f[1]
		var b: Vector3 = f[2]
		var corners: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for k: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var p := n * h * n.abs() + a * k.x * (h * a.abs()).length() + b * k.y * (h * b.abs()).length()
			corners.append(centre + basis * p)
			var along := p.x if absf(a.x) > 0.5 else p.z
			var across := p.z if absf(b.z) > 0.5 and absf(a.x) > 0.5 else p.y
			uvs.append(Vector2((-along if flip else along) / 1.2, across / 1.2) + grain)
		var normal := (basis * n).normalized()
		# Wound so the face looks out along its normal.
		var order := [0, 1, 2, 0, 2, 3]
		if (corners[1] - corners[0]).cross(corners[2] - corners[0]).dot(normal) > 0.0:
			order = [0, 2, 1, 0, 3, 2]
		for i: int in order:
			st.set_normal(normal)
			st.set_color(colour)
			st.set_uv(uvs[i])
			st.add_vertex(corners[i])


## ---- the pools -------------------------------------------------------------

func _build_pools() -> void:
	for i in 6:
		var side := 1.0 if i % 2 == 0 else -1.0
		var v: float = POOL_V[i]
		var u := side * POOL_OFF
		var floor_y := 0.15
		var pool := TidePool.new(i as TidePool.Species, floor_y, ground(u, v), _stone_inside, _glass, Vector3(-side, 0, 0))
		pool.position = at(u, v, floor_y)
		_site.add_child(pool)
		pools.append(pool)
		_site.add_child(HoverNote.new(at(u, v, floor_y + 0.4), Vector3(4.6, 1.0, 4.6),
				"Tidepool of %s\nFed with broth, they make %s; it gathers in the cup on the rim." % [TidePool.NAMES[i], TidePool.PRODUCTS[i]], 1.4))
		# The branch and valve from the main pipe along this side.
		var main_u := side * (HALF + 0.25)
		var wheel := Node3D.new()
		wheel.set_meta(StaticMerge.MOVES, true)
		wheel.position = at(main_u, v + 1.2, DECK + 0.25)
		_site.add_child(wheel)
		var torus := TorusMesh.new()
		torus.inner_radius = 0.1
		torus.outer_radius = 0.125
		torus.material = _iron
		_put(torus, Vector3.ZERO, false, Vector3.ZERO, wheel)
		_box(Vector3(0.22, 0.015, 0.015), Vector3.ZERO, _iron, false, wheel)
		_valve_wheels.append(wheel)
		_rod(at(main_u, v + 1.2, DECK - 0.25), at(main_u + side * 0.4, v + 1.2, floor_y + TidePool.WATER + 0.3), 0.04, _copper, 6)
	# The two mains, under the deck's edges, from the tank to the last pool.
	for side: float in [-1.0, 1.0]:
		_rod(at(side * (HALF + 0.25), WHARF_V0 + 2.0, DECK - 0.25), at(side * (HALF + 0.25), POOL_V[5] - 1.0, DECK - 0.25), 0.05, _copper, 8)


## ---- the beach: broth, store, shed ----------------------------------------

const TANK := Vector2(6.5, 11.0)
const SHED := Vector2(-8.0, 12.0)
const STORE := Vector2(-4.2, 12.5)


func _build_shore() -> void:
	# The broth kettle on its brazier, and the glass tank it fills.
	var gt := ground(TANK.x, TANK.y)
	_cyl(0.75, 0.8, 0.5, at(TANK.x, TANK.y, gt + 0.1), _stone, 14, true)
	_cyl(0.6, 0.6, 1.6, at(TANK.x, TANK.y, gt + 1.15), _glass, 20)
	_cyl(0.63, 0.63, 0.06, at(TANK.x, TANK.y, gt + 1.97), _brass, 20)
	var broth := StandardMaterial3D.new()
	broth.albedo_color = Color(0.45, 0.6, 0.22, 0.85)
	broth.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	broth.emission_enabled = true
	broth.emission = Color(0.4, 0.7, 0.2)
	broth.emission_energy_multiplier = 0.3
	_broth_fill = _cyl(0.57, 0.57, 1.0, Vector3.ZERO, broth, 20)
	var gk := ground(TANK.x + 1.8, TANK.y + 0.8)
	var kettle_at := at(TANK.x + 1.8, TANK.y + 0.8, gk + 0.9)
	_cyl(0.55, 0.4, 0.7, kettle_at, _copper, 16)
	for k in 3:
		var a := TAU * k / 3.0
		_rod(kettle_at + Vector3(cos(a) * 0.5, -0.35, sin(a) * 0.5), kettle_at + Vector3(cos(a) * 0.7, -0.9, sin(a) * 0.7), 0.03, _iron, 6)
	_rod(kettle_at + Vector3(-0.4, 0.2, 0), at(TANK.x + 0.5, TANK.y, gt + 1.9), 0.04, _copper, 8)
	_rod(at(TANK.x - 0.6, TANK.y, gt + 0.4), at(HALF + 0.25, WHARF_V0 + 2.0, DECK - 0.25), 0.05, _copper, 8)
	_rod(at(TANK.x - 0.6, TANK.y, gt + 0.4), at(-(HALF + 0.25), WHARF_V0 + 2.0, DECK - 0.25), 0.05, _copper, 8)
	_kettle_fire = _flames()
	_kettle_fire.position = kettle_at - Vector3(0, 0.75, 0)
	_site.add_child(_kettle_fire)
	_kettle_light = OmniLight3D.new()
	_kettle_light.light_color = Color(1.0, 0.55, 0.25)
	_kettle_light.omni_range = 4.0
	_kettle_light.position = kettle_at - Vector3(0, 0.6, 0)
	_site.add_child(_kettle_light)
	_kettle_steam = _steam()
	_kettle_steam.position = kettle_at + Vector3(0, 0.4, 0)
	_site.add_child(_kettle_steam)
	_site.add_child(HoverNote.new(kettle_at + Vector3(-0.9, -0.2, 0), Vector3(3.2, 2.0, 1.8),
			"Broth kettle and tank\nKelp, salt and sea water simmered into the pools' broth."))
	# The sorting shed: a roof on posts over a shelf of six great jars.
	var gs := ground(SHED.x, SHED.y)
	for du: float in [-2.2, 2.2]:
		for dv: float in [-1.1, 1.1]:
			_rod(at(SHED.x + du, SHED.y + dv, gs - 0.2), at(SHED.x + du, SHED.y + dv, gs + 2.6), 0.07, _wood)
	_box(Vector3(4.8, 0.1, 2.6), at(SHED.x, SHED.y, gs + 2.65), _plank).rotation.x = 0.1
	_box(Vector3(4.4, 0.08, 0.9), at(SHED.x, SHED.y + 0.5, gs + 0.6), _plank, true)
	for i in 6:
		var u := SHED.x - 1.85 + i * 0.74
		var jar_at := at(u, SHED.y + 0.5, gs + 0.64)
		_cyl(0.28, 0.3, 0.9, jar_at + Vector3(0, 0.45, 0), _glass, 16)
		_cyl(0.18, 0.18, 0.08, jar_at + Vector3(0, 0.94, 0), _brass, 12)
		var mat := StandardMaterial3D.new()
		var colour: Color = TidePool.COLOURS[i]
		mat.albedo_color = colour
		mat.emission_enabled = true
		mat.emission = colour
		mat.emission_energy_multiplier = 0.9
		var fill := _cyl(0.26, 0.28, 1.0, jar_at, mat, 16)
		fill.visible = false
		_jar_fills.append(fill)
	_site.add_child(HoverNote.new(at(SHED.x, SHED.y, gs + 1.2), Vector3(4.6, 2.4, 2.4),
			"Sorting shed\nGlimmer, pearls, spine-chalk, sea-silk, star-salt and jelly-light, each in its jar."))
	# The store: four Leyden jars, glass lined with foil, a knobbed rod in
	# each; they glow as they hold charge. A dial reads the charge.
	var gst := ground(STORE.x, STORE.y)
	_box(Vector3(2.2, 0.5, 0.8), at(STORE.x, STORE.y, gst + 0.2), _stone, true)
	for i in 4:
		var jar_at := at(STORE.x - 0.78 + i * 0.52, STORE.y, gst + 0.45)
		_cyl(0.2, 0.2, 0.7, jar_at + Vector3(0, 0.35, 0), _glass, 14)
		_cyl(0.205, 0.205, 0.35, jar_at + Vector3(0, 0.18, 0), _brass, 14)
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(1.0, 0.8, 0.45)
		_cyl(0.14, 0.14, 0.55, jar_at + Vector3(0, 0.34, 0), glow, 12)
		_store_glows.append(glow)
		_rod(jar_at + Vector3(0, 0.7, 0), jar_at + Vector3(0, 1.05, 0), 0.015, _brass, 6)
		_ball(0.045, jar_at + Vector3(0, 1.07, 0), _brass)
	_charge_needle = Node3D.new()
	_charge_needle.set_meta(StaticMerge.MOVES, true)
	var dial_at := at(STORE.x + 1.25, STORE.y + 0.3, gst + 0.9)
	_cyl(0.18, 0.18, 0.03, dial_at, _brass, 16).rotation.x = PI * 0.5
	var enamel := StandardMaterial3D.new()
	enamel.albedo_color = Color(0.93, 0.9, 0.82)
	_cyl(0.15, 0.15, 0.006, dial_at + Vector3(0, 0, 0.018), enamel, 16).rotation.x = PI * 0.5
	_charge_needle.position = dial_at + Vector3(0, 0, 0.025)
	_site.add_child(_charge_needle)
	_box(Vector3(0.012, 0.13, 0.006), Vector3(0, 0.05, 0), _iron, false, _charge_needle)
	_site.add_child(HoverNote.new(at(STORE.x, STORE.y, gst + 0.8), Vector3(2.4, 1.4, 1.0),
			"Leyden jars\nThe works' store of the windmills' light. The dial reads how full."))


func _flames() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.2, 0.02, 0.2)
	process.direction = Vector3.UP
	process.spread = 10.0
	process.initial_velocity_min = 0.3
	process.initial_velocity_max = 0.6
	process.gravity = Vector3(0, 1.0, 0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	ramp.colors = PackedColorArray([Color(1.4, 0.9, 0.4, 0), Color(1.4, 0.6, 0.15, 0.6), Color(0.6, 0.1, 0.02, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	ramp_tex.use_hdr = true
	process.color_ramp = ramp_tex
	var p := GPUParticles3D.new()
	p.amount = 30
	p.lifetime = 0.5
	p.process_material = process
	p.draw_pass_1 = _soft_quad(0.2, true)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	return p


func _steam() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 15.0
	process.initial_velocity_min = 0.4
	process.initial_velocity_max = 0.8
	process.gravity = Vector3(0.3, 0.4, 0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	process.color_ramp = ramp_tex
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.8))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	process.scale_curve = curve_tex
	var p := GPUParticles3D.new()
	p.amount = 16
	p.lifetime = 2.5
	p.process_material = process
	p.draw_pass_1 = _soft_quad(0.5, false)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	return p


func _soft_quad(size: float, additive: bool) -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if additive else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	var dot := GradientTexture2D.new()
	dot.width = 64
	dot.height = 64
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	dot.gradient = fade
	mat.albedo_texture = dot
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	return quad


## ---- the cart --------------------------------------------------------------

func _build_cart() -> void:
	_cart_node = Node3D.new()
	_cart_node.set_meta(StaticMerge.MOVES, true)
	_site.add_child(_cart_node)
	_box(Vector3(1.4, 0.45, 1.8), Vector3(0, 0.45, 0), _plank, false, _cart_node)
	for du: float in [-0.55, 0.55]:
		for dv: float in [-0.6, 0.6]:
			_cyl(0.18, 0.18, 0.08, Vector3(du, 0.2, dv), _iron, 12, false, _cart_node).rotation.z = PI * 0.5
	var heap_mat := StandardMaterial3D.new()
	heap_mat.albedo_color = Color(0.9, 0.85, 1.0)
	heap_mat.emission_enabled = true
	heap_mat.emission = Color(0.8, 0.7, 1.0)
	heap_mat.emission_energy_multiplier = 0.8
	var heap := SphereMesh.new()
	heap.radius = 0.5
	heap.height = 0.5
	heap.material = heap_mat
	_hold_heap = _put(heap, Vector3(0, 0.68, 0.2), false, Vector3.ZERO, _cart_node)
	_hold_heap.visible = false
	# The crane: a post, a boom that swings to either side and dips.
	_rod(Vector3(0, 0.68, -0.6), Vector3(0, 2.0, -0.6), 0.06, _iron, 8, _cart_node)
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 2.0, -0.6)
	_cart_node.add_child(pivot)
	_boom = Node3D.new()
	pivot.add_child(_boom)
	_box(Vector3(3.6, 0.1, 0.1), Vector3(1.8, 0, 0), _wood, false, _boom)
	_rod(Vector3(3.5, 0, 0), Vector3(3.5, -0.9, 0), 0.012, _iron, 4, _boom)
	_scoop_mat = StandardMaterial3D.new()
	_scoop_mat.albedo_color = Color(0.6, 0.45, 0.2)
	_scoop_mat.metallic = 0.8
	_scoop_mat.roughness = 0.35
	_scoop_mat.emission_enabled = true
	var scoop := SphereMesh.new()
	scoop.radius = 0.16
	scoop.height = 0.16
	scoop.is_hemisphere = true
	scoop.material = _scoop_mat
	_put(scoop, Vector3(3.5, -0.95, 0), false, Vector3.ZERO, _boom).rotation.x = PI
	_cart_node.add_child(HoverNote.new(Vector3(0, 0.8, 0), Vector3(1.5, 1.4, 2.0),
			"Harvest cart\nRuns out to the ripe pools, scoops each cup and brings it home to the shed.", 2.0))
	_place_cart()


func _place_cart() -> void:
	_cart_node.position = at(0, _cart_v, DECK)
	(_boom.get_parent() as Node3D).rotation.y = _boom_side
	_boom.rotation.z = -_boom_dip


## ---- power ------------------------------------------------------------------

const TOWER_V := -66.0


func _build_power() -> void:
	# The collector tower at the wharf's end.
	var top := DECK + 11.0
	for du: float in [-1.4, 1.4]:
		for dv: float in [-1.4, 1.4]:
			_rod(at(du, TOWER_V + dv, DECK), at(du * 0.35, TOWER_V + dv * 0.35, top), 0.09, _wood, 8)
	for y: float in [DECK + 3.0, DECK + 6.0, DECK + 9.0]:
		var w := lerpf(1.4, 0.5, (y - DECK) / 11.0)
		for side in 4:
			var a := Vector3(w, 0, w).rotated(Vector3.UP, PI * 0.5 * side)
			var b := Vector3(w, 0, -w).rotated(Vector3.UP, PI * 0.5 * side)
			_rod(at(a.x, TOWER_V + a.z, y), at(b.x, TOWER_V + b.z, y), 0.05, _wood, 6)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.05
	ring.material = _brass
	_put(ring, at(0, TOWER_V, top + 0.6), false, Vector3.ZERO, null)
	_crystal_mat = StandardMaterial3D.new()
	_crystal_mat.albedo_color = Color(1.0, 0.85, 0.55)
	_crystal_mat.roughness = 0.1
	_crystal_mat.emission_enabled = true
	_crystal_mat.emission = Color(1.0, 0.8, 0.45)
	for up: float in [1.0, -1.0]:
		var half := CylinderMesh.new()
		half.radial_segments = 6
		half.rings = 1
		half.bottom_radius = 0.55
		half.top_radius = 0.0
		half.height = 1.1
		half.material = _crystal_mat
		var view := _put(half, at(0, TOWER_V, top + 0.6 + up * 0.55), false, Vector3.ZERO, null)
		if up < 0.0:
			view.rotation.x = PI
	_crystal_light = OmniLight3D.new()
	_crystal_light.light_color = Color(1.0, 0.8, 0.45)
	_crystal_light.omni_range = 14.0
	_crystal_light.position = at(0, TOWER_V, top + 0.6)
	_site.add_child(_crystal_light)
	# The conduit: a glass pipe glowing with the flow, from the tower's
	# foot along the wharf to the store.
	_conduit_mat = StandardMaterial3D.new()
	_conduit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_conduit_mat.albedo_color = Color(1.0, 0.8, 0.45)
	# Hung under the deck's edge, out of the way of feet.
	var cu := -(HALF + 0.12)
	var cy := DECK - 0.16
	_rod(at(0, TOWER_V, top), at(-1.0, TOWER_V + 0.6, DECK + 0.1), 0.035, _conduit_mat, 8)
	_rod(at(-1.0, TOWER_V + 0.6, DECK + 0.1), at(cu, TOWER_V + 1.5, cy), 0.035, _conduit_mat, 8)
	_rod(at(cu, TOWER_V + 1.5, cy), at(cu, WHARF_V0, cy), 0.035, _conduit_mat, 8)
	_rod(at(cu, WHARF_V0, cy), at(STORE.x + 0.8, STORE.y, ground(STORE.x, STORE.y) + 0.5), 0.035, _conduit_mat, 8)
	_site.add_child(HoverNote.new(at(0, TOWER_V, DECK + 6.0), Vector3(3.0, 12.0, 3.0),
			"Collector tower\nIts crystal takes in the windmills' beams; the glowing pipe carries their light to the jars on the beach."))
	# The windmills out at sea.
	var target := _site.to_global(at(0, TOWER_V, top + 0.6))
	for m: Vector2 in MILLS:
		var p := at(m.x, m.y, 0.0)
		var mill := SeaMill.new(-FLOOR_DEPTH, _wood, _iron, _canvas, _brass)
		mill.distance = Vector2(_origin.x, _origin.z).length() + Vector2(m.x, m.y).length()
		mill.position = p
		var toward := at(0, TOWER_V, 0) - p
		mill.basis = Basis.looking_at(-Vector3(toward.x, 0, toward.z).normalized(), Vector3.UP)
		_site.add_child(mill)
		mill.aim(target)
		mills.append(mill)


const FLOOR_DEPTH := -4.0


## ---- the circuit -----------------------------------------------------------

func _build_circuit() -> void:
	# Each pool's lanterns at the deck's edge by it, its feed AND beside
	# them, its valve's radiometer over the valve.
	var or_ripe_inputs: Array[LumenPart] = []
	for i in 6:
		var side := 1.0 if i % 2 == 0 else -1.0
		var v: float = POOL_V[i]
		var u := side * (HALF - 0.3)
		var name_ := TidePool.NAMES[i] as String
		var col := _lantern_column(u, v - 1.4, ["the %s are hungry" % name_, "the %s' cup is full" % name_], 1.4, 0.38, DECK)
		_pool_lanterns.append(col)
		_feeds.append(_part(LumenPart.Kind.AND, "feed the %s" % name_, u, v + 1.8, DECK + 2.6, 0.0, DECK))
		var rv := _part(LumenPart.Kind.RADIOMETER, "opens the %s' broth valve" % name_, side * (HALF + 0.25), v + 1.2, DECK + 1.6)
		_r_valves.append(rv)
		or_ripe_inputs.append(col[1])
	var col_store := _lantern_column(STORE.x + 1.6, STORE.y + 1.2, ["the jars hold charge"], 2.2)
	_l["charged"] = col_store[0]
	var col_tank := _lantern_column(TANK.x - 1.4, TANK.y + 1.2, ["there is broth in the tank", "the tank is full"], 2.0)
	_l["broth"] = col_tank[0]
	_l["full"] = col_tank[1]
	var col_home := _lantern_column(1.9, CART_HOME + 1.5, ["the cart is home"], 1.8, 0.38, DECK)
	_l["home"] = col_home[0]
	var gy := func(u: float, v: float) -> float: return ground(u, v) + 2.9
	var or_ripe := _part(LumenPart.Kind.OR, "a pool is ripe", -2.2, 15.0, gy.call(-2.2, 15.0))
	var dispatch := _part(LumenPart.Kind.AND, "send the cart", 0.6, 16.2, gy.call(0.6, 16.2))
	var not_full := _part(LumenPart.Kind.NOT, "the tank has room", 4.0, 15.0, gy.call(4.0, 15.0))
	var kettle := _part(LumenPart.Kind.AND, "brew broth", 6.0, 14.5, gy.call(6.0, 14.5))
	var rise_home := _part(LumenPart.Kind.RISE, "the cart comes home", 2.8, 13.0, gy.call(2.8, 13.0))
	_r["dispatch"] = _part(LumenPart.Kind.RADIOMETER, "starts the cart", -1.7, CART_HOME + 2.5, ground(-1.7, CART_HOME + 2.5) + 1.9)
	_r["kettle"] = _part(LumenPart.Kind.RADIOMETER, "lights the kettle's brazier", TANK.x + 2.6, TANK.y - 0.3, ground(TANK.x + 2.6, TANK.y - 0.3) + 1.8)
	_r["bell"] = _part(LumenPart.Kind.RADIOMETER, "rings the shed's bell", SHED.x + 2.6, SHED.y - 1.6, ground(SHED.x + 2.6, SHED.y - 1.6) + 2.3)
	# The wires.
	for i in 6:
		var col: Array = _pool_lanterns[i]
		var feed := _feeds[i]
		_wire(col[0], feed)
		_wire(_l["broth"], feed)
		_wire(_l["charged"], feed)
		_wire(feed, _r_valves[i])
	for lantern in or_ripe_inputs:
		_wire(lantern, or_ripe)
	_wire(or_ripe, dispatch)
	_wire(_l["home"], dispatch)
	_wire(_l["charged"], dispatch)
	_wire(dispatch, _r["dispatch"])
	_wire(_l["full"], not_full)
	_wire(not_full, kettle)
	_wire(_l["charged"], kettle)
	_wire(kettle, _r["kettle"])
	_wire(_l["home"], rise_home)
	_wire(rise_home, _r["bell"])


func _build_sounds() -> void:
	var top := DECK + 11.6
	_snd_hum = _speaker("res://audio/shell_drone_loop.wav", true, at(0, TOWER_V, top), 8.0)
	_snd_wind = _speaker("res://audio/wind_loop.wav", true, at(0, TOWER_V, DECK + 3.0), 14.0)
	_snd_bubble = _speaker("res://audio/bubble_loop.wav", true, at(TANK.x + 1.8, TANK.y + 0.8, ground(TANK.x, TANK.y) + 1.0), 3.0)
	_snd_clack = _speaker("res://audio/clank_2.wav", false, Vector3.ZERO, 4.0)
	_snd_crane = _speaker("res://audio/ratchet.wav", false, Vector3.ZERO, 4.0)
	_snd_bell = _speaker("res://audio/bell_2.wav", false, at(SHED.x, SHED.y, ground(SHED.x, SHED.y) + 2.4), 8.0)
	for i in 6:
		var side := 1.0 if i % 2 == 0 else -1.0
		_snd_clanks.append(_speaker("res://audio/clank_1.wav", false, at(side * (HALF + 0.25), POOL_V[i] + 1.2, DECK), 4.0))


## ---- the simulation --------------------------------------------------------

func _on(p: LumenPart) -> bool:
	return p.spin > 0.5


func _edge(key: String, now: bool) -> bool:
	var was: bool = _was.get(key, false)
	_was[key] = now
	return now and not was


func _physics_process(dt: float) -> void:
	_clock += dt
	# Wind at the shore, and out at each mill; power home along the beams.
	var shore := clampf(0.55 + 0.45 * _wind_noise.get_noise_1d(_clock * 0.02) + 0.15 * _wind_noise.get_noise_1d(_clock * 0.5 + 40.0), 0.0, 1.0)
	_inflow = 0.0
	for mill in mills:
		mill.blow(shore, dt)
		_inflow += mill.power
	_energy = minf(_energy + _inflow * 0.007 * dt, JARS)
	var has_charge := _energy > 0.05
	# The pools: valves follow their radiometers; broth flows while open.
	for i in 6:
		var open := _on(_r_valves[i]) and _broth > 0.0 and has_charge
		var was := _valves[i]
		_valves[i] = move_toward(_valves[i], 1.0 if open else 0.0, dt * 2.5)
		if (was <= 0.0 and _valves[i] > 0.0) or (was >= 1.0 and _valves[i] < 1.0):
			_play(_snd_clanks[i], randf_range(0.9, 1.1))
		var fed := 0.06 * _valves[i]
		_broth = maxf(_broth - fed * 0.12 * dt, 0.0)
		_energy = maxf(_energy - 0.004 * _valves[i] * dt, 0.0)
		pools[i].step(dt, fed)
	# The kettle brews while lit.
	_kettle = move_toward(_kettle, 1.0 if _on(_r["kettle"]) and has_charge else 0.0, dt * 1.5)
	_broth = minf(_broth + 0.01 * _kettle * dt, 1.0)
	_energy = maxf(_energy - 0.003 * _kettle * dt, 0.0)
	# The cart.
	_run_cart(dt, has_charge)
	# Lanterns.
	for i in 6:
		(_pool_lanterns[i][0] as LumenPart).condition = pools[i].hungry
		(_pool_lanterns[i][1] as LumenPart).condition = pools[i].ripe
	_l["charged"].condition = _energy > (0.15 if _l["charged"].condition else 0.3)
	_l["broth"].condition = _broth > (0.02 if _l["broth"].condition else 0.08)
	_l["full"].condition = _broth > (0.9 if _l["full"].condition else 0.97)
	_l["home"].condition = _cart == Cart.HOME
	if _edge("bell", _r["bell"].powered):
		_play(_snd_bell, 1.4)
	_step_circuit(dt)


func _run_cart(dt: float, has_charge: bool) -> void:
	match _cart:
		Cart.HOME:
			if _edge("dispatch", _r["dispatch"].powered):
				_route.clear()
				for i in 6:
					if pools[i].ripe:
						_route.append(i)
				if not _route.is_empty():
					_cart = Cart.OUT
		Cart.OUT, Cart.BACK:
			var target := CART_HOME if _cart == Cart.BACK else float(POOL_V[_route[0]])
			if has_charge:
				_cart_v = move_toward(_cart_v, target, CART_SPEED * dt)
				_energy = maxf(_energy - 0.006 * dt, 0.0)
				# A clack at each rail joint, every 2.4 m.
				var joint := floori(_cart_v / 2.4)
				if joint != _last_joint:
					_last_joint = joint
					_snd_clack.position = at(0, _cart_v, DECK)
					_play(_snd_clack, randf_range(1.6, 1.9))
			if is_equal_approx(_cart_v, target):
				if _cart == Cart.BACK:
					_cart = Cart.UNLOAD
					_cart_timer = 2.5
				else:
					_cart = Cart.DIP
					_cart_timer = 2.4
					_snd_crane.position = at(0, _cart_v, DECK + 2.0)
					_play(_snd_crane)
		Cart.DIP:
			_cart_timer -= dt
			var i := _route[0]
			if _cart_timer <= 1.2 and pools[i].product > 0.0:
				_hold[i] = float(_hold[i]) + pools[i].take()
				_scoop_mat.emission = TidePool.COLOURS[i]
			if _cart_timer <= 0.0:
				_route.remove_at(0)
				var held := 0.0
				for h in _hold:
					held += float(h)
				if _route.is_empty() or held >= HOLD:
					_cart = Cart.BACK
				else:
					_cart = Cart.OUT
		Cart.UNLOAD:
			_cart_timer -= dt
			if _cart_timer <= 0.0:
				for i in 6:
					_jars[i] = float(_jars[i]) + float(_hold[i])
					_hold[i] = 0.0
				_cart = Cart.HOME


func _process(delta: float) -> void:
	# The cart's crane: swung over the pool's side and dipped while at it.
	var dipping := _cart == Cart.DIP
	var swing := 0.0
	if dipping:
		swing = 0.0 if _route[0] % 2 == 0 else PI
	_boom_side = rotate_toward(_boom_side, swing if dipping else PI * 0.5, delta * 2.5)
	var dip_want := 0.0
	if dipping and _cart_timer < 2.0 and _cart_timer > 0.6:
		dip_want = 0.35
	_boom_dip = move_toward(_boom_dip, dip_want, delta * 0.8)
	_place_cart()
	var held := 0.0
	for h in _hold:
		held += float(h)
	_hold_heap.visible = held > 0.05
	_hold_heap.scale = Vector3(1, minf(held / HOLD, 1.0) * 0.8 + 0.1, 1)
	_scoop_mat.emission_energy_multiplier = 1.5 if dipping else 0.0
	# Jars, store, crystal, conduit.
	for i in 6:
		var f := clampf(float(_jars[i]) / 12.0, 0.0, 1.0)
		var fill := _jar_fills[i]
		fill.visible = f > 0.01
		var gs := ground(SHED.x, SHED.y)
		fill.position = at(SHED.x - 1.85 + i * 0.74, SHED.y + 0.5, gs + 0.66 + f * 0.85 * 0.5)
		fill.scale = Vector3(1, maxf(f * 0.85, 0.005), 1)
	for i in 4:
		var share := clampf(_energy - i, 0.0, 1.0)
		var m := _store_glows[i]
		m.albedo_color = Color(1.0, 0.8, 0.45) * (0.05 + share * 1.6)
	_charge_needle.rotation.z = -clampf(_energy / JARS, 0.0, 1.0) * 4.0 + 2.0
	var p := clampf(_inflow / 3.0, 0.0, 1.5)
	_crystal_mat.emission_energy_multiplier = 0.4 + 4.0 * p * (0.85 + 0.15 * sin(_clock * 6.0))
	_crystal_light.light_energy = 0.3 + 2.0 * p
	_conduit_mat.albedo_color = Color(1.0, 0.8, 0.45) * (0.2 + 0.9 * p)
	var night := 1.0 - island.sky.daylight
	for pool in pools:
		pool.night = night
	# Broth, kettle.
	var gt := ground(TANK.x, TANK.y)
	var bh := maxf(1.5 * _broth, 0.01)
	_broth_fill.visible = _broth > 0.005
	_broth_fill.position = at(TANK.x, TANK.y, gt + 0.37 + bh * 0.5)
	_broth_fill.scale = Vector3(1, bh, 1)
	_kettle_fire.emitting = _kettle > 0.1
	_kettle_light.visible = _kettle > 0.05
	_kettle_light.light_energy = _kettle * (1.0 + 0.2 * sin(_clock * 11.0))
	_kettle_steam.emitting = _kettle > 0.5
	for i in 6:
		_valve_wheels[i].rotation.x = _valves[i] * TAU
	_level(_snd_hum, clampf(_inflow / 3.0, 0.0, 1.0), -6.0)
	var wind := 0.0
	for mill in mills:
		wind = maxf(wind, mill.wind)
	_level(_snd_wind, clampf(wind / 1.6, 0.1, 1.0), -4.0)
	_level(_snd_bubble, _kettle, -8.0)
