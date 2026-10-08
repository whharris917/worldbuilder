class_name ColourWorks
extends BeachSite
## An alchemist's colour works on the cozy island's north-west beach,
## run by the same light-beam logic as the salt works (LumenPart,
## LumenBeam), stepped through its recipe by a sequencer drum.
##
## The process. Three tall glass tanks hold red, blue and yellow
## tinctures, topped up slowly from the springs. A glass reactor is
## charged with red, then blue (purple), heated by a burner and stirred
## by a small steam engine; at heat the brew reacts to a glowing magenta,
## giving off gas that builds pressure: a pipe lets it into a gasholder
## whose iron bell rises, a relief valve hisses vapour when the pressure
## climbs too high, and when the gasholder is full a flare stack burns it
## off in coloured flame. Yellow added flashes the brew to a glowing green
## in a burst of sparkles. It is distilled over into a glass condenser
## cooled by a copper coil, drips into a receiving flask, and a carousel
## fills bottles from it one by one; a counter keeps the tally.
##
## The sequencer drum (the recipe). A brass drum with pegs turns one
## notch per step; over it a row of lanterns open where a peg stands
## under their follower: one lantern per step (which step it is) and one
## per output (which valves and burners that step works). While the drum
## turns, a bar shuts all its lanterns; the run lever holds the bar shut.
##   step  does                         advances when
##   0     wait                         stock in all three tanks AND room in the receiver
##   1     charge red                   reactor a third full
##   2     charge blue, stir            two thirds full
##   3     heat, stir                   hot (80 degrees)
##   4     heat, stir (react)           8 s on (an hourglass)
##   5     add yellow, stir             full
##   6     heat, distil                 the reactor nearly empty
##   7     (cool)                       cool (40 degrees); the whistle blows
## Each step's lantern and its condition meet in an AND crystal; all eight
## feed one OR crystal, whose rising spark drives the drum's ratchet.
## Beside the drum: relief valve = pressure high; flare = latch set by the
## gasholder high, reset by it low; spout = product in the receiver AND an
## empty bottle under it; the carousel turns on the rising edge of a full
## bottle under the spout.
##
## Sounds come from the moments they belong to: a valve's clank when its
## radiometer throws it, the ratchet at each step, the chime with the
## flash, an engine chuff each half turn of the flywheel, a drop's sound
## as each drop falls, bubbling while it boils, a hiss while the relief
## valve is open, the flare's roar while it burns, the whistle at the end.
##
## Engine materials, particles and lights throughout; the chemistry and
## the logic are script.

const BEARING := 235.0
const STEPS := 8
# Which steps each output track has a peg on.
const PEGS := {
	"red": [1], "blue": [2], "yellow": [5], "heat": [3, 4, 6], "stir": [2, 3, 4, 5], "distil": [6],
}
const OUTPUTS := ["red", "blue", "yellow", "heat", "stir", "distil"]
const RED := Color(0.85, 0.05, 0.08)
const BLUE := Color(0.05, 0.22, 0.95)
const YELLOW := Color(0.95, 0.78, 0.08)
const MAGENTA := Color(1.0, 0.15, 0.85)
const GREEN := Color(0.25, 1.0, 0.35)
const DOSE := 0.05                      # reactor volumes a second
const DISTIL_RATE := 0.05
const SPOUT_RATE := 0.08
const BOTTLE := 0.1                     # reactor volumes a bottle holds
const RECEIVER := 1.6
const DROP := 0.02                      # reactor volumes a drop (scaled up, for the ear)

# the chemistry and the machines
var _stock := {"red": 0.8, "blue": 0.8, "yellow": 0.8}
var _vol := {"red": 0.0, "blue": 0.0, "yellow": 0.0}
var _aether := 0.0                      # how far red and blue have reacted
var _elixir := 0.0                      # how far yellow has turned it
var _temp := 20.0
var _pressure := 1.0                    # bar
var _gas := 0.1                         # the gasholder, 0 to 1
var _burner := 0.0
var _vent := 0.0
var _flare := 0.0
var _engine := 0.0
var _engine_angle := 0.0
var _stir_angle := 0.0
var _received := 0.0
var _drop := 0.0
var _flashed := false
var _bottles: Array[float] = [0, 0, 0, 0, 0, 0, 0, 0]
var _carousel := 0                      # the slot under the spout
var _carousel_angle := 0.0
var _made := 0
var _step := 0
var _drum_angle := 0.0
var _clock := 0.0
var _was := {}                          # radiometers' last powered state, for edges
var _tank_valves := {}                  # output -> valve opening 0..1
var _cool_valve := 0.0
var _spout := 0.0

# parts
var _drum_lanterns: Array[LumenPart] = []     # S0..S7 then the outputs
var _l: Dictionary = {}                       # condition lanterns by name
var _r: Dictionary = {}                       # radiometers by name
var _lever: WorksHandle

# pieces that move or change
var _tank_liquid := {}
var _liquid_mat: StandardMaterial3D
var _reactor_liquid: MeshInstance3D
var _reactor_light: OmniLight3D
var _stirrer: Node3D
var _bubbles: GPUParticles3D
var _bubble_mat: StandardMaterial3D
var _sparkle_burst: GPUParticles3D
var _vapour: GPUParticles3D
var _burner_flame: GPUParticles3D
var _burner_light: OmniLight3D
var _gauge_needle: Node3D
var _thermo_needle: Node3D
var _bell: Node3D
var _flare_flame: GPUParticles3D
var _flare_sparks: GPUParticles3D
var _flare_light: OmniLight3D
var _column_vapour: GPUParticles3D
var _drips: GPUParticles3D
var _receiver_liquid: MeshInstance3D
var _receiver_light: OmniLight3D
var _receiver_sparkles: GPUParticles3D
var _carousel_node: Node3D
var _bottle_liquid: Array[MeshInstance3D] = []
var _product_mat: StandardMaterial3D
var _flywheel: Node3D
var _piston: Node3D
var _puff: GPUParticles3D
var _drum: Node3D
var _digits: Array[Label3D] = []
var _valve_wheels := {}
var _jacket_water: MeshInstance3D

# sounds
var _snd_bubble: AudioStreamPlayer3D
var _snd_hiss: AudioStreamPlayer3D
var _snd_flare: AudioStreamPlayer3D
var _snd_chime: AudioStreamPlayer3D
var _snd_chuff: AudioStreamPlayer3D
var _snd_ratchet: AudioStreamPlayer3D
var _snd_whistle: AudioStreamPlayer3D
var _snd_drip: AudioStreamPlayer3D
var _drip_streams: Array[AudioStream] = []
var _clanks := {}                       # radiometer name -> speaker

# materials
var _iron: StandardMaterial3D
var _copper: StandardMaterial3D
var _stone: StandardMaterial3D
var _plank: StandardMaterial3D
var _glass: StandardMaterial3D
var _water: StandardMaterial3D

# where things stand (u, v)
const TANK_U := [-8.5, -7.0, -5.5]
const TANK_V := 9.5
const REACTOR := Vector2(-2.0, 5.0)
const COLUMN := Vector2(1.6, 5.4)
const CAROUSEL := Vector2(2.9, 4.2)
const GASHOLDER := Vector2(-6.0, 2.8)
const FLARE := Vector2(-9.5, 1.8)
const ENGINE := Vector2(-0.6, 9.6)
const DRUM := Vector2(6.0, 10.0)


func _init(owner_island: CozyIsland) -> void:
	super(owner_island, BEARING)
	name = "ColourWorks"


static func centre(owner_island: CozyIsland) -> Vector3:
	return BeachSite.site_point(owner_island, BEARING, -1.0, 7.0)


func _ready() -> void:
	add_child(_site)
	_materials()
	_build_tanks()
	_build_reactor()
	_build_column()
	_build_carousel()
	_build_gasholder()
	_build_flare()
	_build_engine()
	_build_drum()
	_build_circuit()
	_place_beams()
	_build_sounds()


func _materials() -> void:
	_wood = island.surface("wood_floor", 0.6, Color(0.55, 0.45, 0.36), 0.85, Color(0.72, 0.54, 0.38))
	_plank = island.surface("wood_floor", 0.8, Color(0.45, 0.37, 0.3), 0.85, Color(0.66, 0.48, 0.34))
	_stone = island.surface("old_stone_bricks", 1.0 / 1.8, Color(0.85, 0.85, 0.85), 0.9, Color(0.7, 0.66, 0.64))
	_iron = island.surface("", 1.0, Color(0.1, 0.1, 0.11), 0.45, Color(0.3, 0.3, 0.38))
	_iron.metallic = 0.6
	_brass = island.surface("", 1.0, Color(0.62, 0.46, 0.2), 0.35, Color(0.9, 0.7, 0.32))
	_brass.metallic = 0.85
	_copper = island.surface("", 1.0, Color(0.62, 0.3, 0.18), 0.35, Color(0.92, 0.5, 0.3))
	_copper.metallic = 0.85
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(0.82, 0.92, 1.0, 0.16)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.roughness = 0.04
	_glass.metallic_specular = 0.8
	_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_water = StandardMaterial3D.new()
	_water.albedo_color = Color(0.3, 0.55, 0.75, 0.45)
	_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water.roughness = 0.1
	_liquid_mat = _liquid(Color.BLACK, 0.0)
	_product_mat = _liquid(GREEN, 2.0)


## A glowing liquid's material: `colour`, glowing by `glow`.
func _liquid(colour: Color, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(colour, 0.88)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = glow
	return m


## ---- the raw tanks ---------------------------------------------------------

func _build_tanks() -> void:
	var colours := {"red": RED, "blue": BLUE, "yellow": YELLOW}
	var names := ["red", "blue", "yellow"]
	var header_y := 0.0
	for i in 3:
		var u: float = TANK_U[i]
		var key: String = names[i]
		var g := ground(u, TANK_V)
		header_y = maxf(header_y, g + 0.5)
		_cyl(0.6, 0.65, 0.9, at(u, TANK_V, g + 0.15), _stone, 10, true)
		_cyl(0.45, 0.45, 2.0, at(u, TANK_V, g + 0.6 + 1.0), _glass, 20)
		_cyl(0.48, 0.48, 0.08, at(u, TANK_V, g + 2.64), _brass, 20)
		_cyl(0.48, 0.48, 0.08, at(u, TANK_V, g + 0.62), _brass, 20)
		var liquid := _cyl(0.43, 0.43, 1.0, Vector3.ZERO, _liquid(colours[key], 0.15 if key != "blue" else 0.5), 20)
		_tank_liquid[key] = [liquid, g + 0.66, 1.94]
		# The pipe from the springs, and the pipe down to the valve.
		_rod(at(u, TANK_V, g + 2.68), at(u, TANK_V, g + 3.2), 0.04, _copper, 8)
		_rod(at(u, TANK_V, g + 3.2), at(u, TANK_V + 3.5, ground(u, TANK_V + 3.5) + 0.2), 0.04, _copper, 8)
		_rod(at(u, TANK_V - 0.45, g + 0.45), at(u, 8.0, g + 0.45), 0.045, _copper, 8)
		var wheel := Node3D.new()
		wheel.set_meta(StaticMerge.MOVES, true)
		wheel.position = at(u, 8.6, g + 0.75)
		_site.add_child(wheel)
		var torus := TorusMesh.new()
		torus.inner_radius = 0.1
		torus.outer_radius = 0.125
		torus.material = _iron
		_put(torus, Vector3.ZERO, false, Vector3.ZERO, wheel)
		_box(Vector3(0.22, 0.015, 0.015), Vector3.ZERO, _iron, false, wheel)
		_cyl(0.015, 0.015, 0.3, at(u, 8.6, g + 0.6), _iron, 6)
		_valve_wheels[key] = wheel
		_site.add_child(HoverNote.new(at(u, TANK_V, g + 1.4), Vector3(1.0, 2.6, 1.0),
				"Tank of %s tincture\nTopped up slowly from the springs." % key))
	# The header carrying the tinctures to the reactor.
	var hy := header_y
	_rod(at(TANK_U[0], 8.0, hy), at(REACTOR.x, 8.0, hy), 0.05, _copper, 8)
	for i in 3:
		_rod(at(TANK_U[i], 8.0, ground(TANK_U[i], TANK_V) + 0.45), at(TANK_U[i], 8.0, hy), 0.045, _copper, 8)
	var rg := ground(REACTOR.x, REACTOR.y)
	_rod(at(REACTOR.x, 8.0, hy), at(REACTOR.x, REACTOR.y + 0.9, hy), 0.05, _copper, 8)
	_rod(at(REACTOR.x, REACTOR.y + 0.9, hy), at(REACTOR.x, REACTOR.y + 0.9, rg + 2.75), 0.05, _copper, 8)
	_rod(at(REACTOR.x, REACTOR.y + 0.9, rg + 2.75), at(REACTOR.x, REACTOR.y + 0.3, rg + 2.75), 0.05, _copper, 8)


## ---- the reactor -----------------------------------------------------------

const R_RADIUS := 0.7
const R_BASE := 1.0                     # above the ground
const R_HEIGHT := 1.6


func _build_reactor() -> void:
	var g := ground(REACTOR.x, REACTOR.y)
	var base := g + R_BASE
	for k in 3:
		var a := TAU * k / 3.0
		_rod(at(REACTOR.x + cos(a) * 0.9, REACTOR.y + sin(a) * 0.9, g - 0.1),
				at(REACTOR.x + cos(a) * 0.62, REACTOR.y + sin(a) * 0.62, base + 0.1), 0.04, _brass, 8)
	_cyl(R_RADIUS + 0.06, R_RADIUS + 0.06, 0.06, at(REACTOR.x, REACTOR.y, base), _brass, 24)
	_cyl(R_RADIUS, R_RADIUS, R_HEIGHT, at(REACTOR.x, REACTOR.y, base + R_HEIGHT * 0.5), _glass, 28)
	var dome := SphereMesh.new()
	dome.radius = R_RADIUS + 0.04
	dome.height = (R_RADIUS + 0.04) * 2.0
	dome.is_hemisphere = true
	dome.material = _copper
	_put(dome, at(REACTOR.x, REACTOR.y, base + R_HEIGHT), false, Vector3.ZERO, null)
	_reactor_liquid = _cyl(R_RADIUS - 0.03, R_RADIUS - 0.03, 1.0, Vector3.ZERO, _liquid_mat, 28)
	_reactor_light = OmniLight3D.new()
	_reactor_light.position = at(REACTOR.x, REACTOR.y, base + 0.6)
	_reactor_light.omni_range = 6.0
	_reactor_light.visible = false
	_site.add_child(_reactor_light)
	# The stirrer, turned by a belt from the engine.
	_stirrer = Node3D.new()
	_stirrer.set_meta(StaticMerge.MOVES, true)
	_stirrer.position = at(REACTOR.x, REACTOR.y, base)
	_site.add_child(_stirrer)
	_cyl(0.025, 0.025, R_HEIGHT + 1.0, Vector3(0, R_HEIGHT * 0.5 + 0.4, 0), _iron, 6, false, _stirrer)
	_box(Vector3(0.9, 0.18, 0.03), Vector3(0, 0.3, 0), _iron, false, _stirrer)
	_cyl(0.2, 0.2, 0.06, Vector3(0, R_HEIGHT + 0.85, 0), _brass, 16, false, _stirrer)
	var top := at(REACTOR.x, REACTOR.y, base + R_HEIGHT + 0.85)
	var fly := at(ENGINE.x + 0.6, ENGINE.y, ground(ENGINE.x, ENGINE.y) + 0.9)
	for d: float in [-0.05, 0.05]:
		_rod(top + Vector3(d, 0, 0), fly + Vector3(d, 0.6, 0), 0.012, _plank, 4)
	# Bubbles, rising through the brew while it boils.
	_bubble_mat = StandardMaterial3D.new()
	_bubble_mat.albedo_color = Color(1, 1, 1, 0.6)
	_bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bubble_mat.emission_enabled = true
	var bubble := SphereMesh.new()
	bubble.radius = 0.025
	bubble.height = 0.05
	bubble.radial_segments = 8
	bubble.rings = 4
	bubble.material = _bubble_mat
	_bubbles = _particles(bubble, 60, 1.6, Vector3(R_RADIUS * 0.7, 0.05, R_RADIUS * 0.7),
			Vector2(0.3, 0.6), Vector3(0, 0.3, 0), [Color(1, 1, 1, 1), Color(1, 1, 1, 1)])
	_bubbles.position = at(REACTOR.x, REACTOR.y, base + 0.1)
	_bubbles.emitting = false
	_site.add_child(_bubbles)
	# The flash of sparkles when the yellow turns it.
	_sparkle_burst = _particles(_dot_quad(0.06, true), 140, 1.6, Vector3(0.4, 0.1, 0.4), Vector2(1.5, 3.5),
			Vector3(0, -1.5, 0), [Color(3.0, 3.0, 1.5, 1), Color(1.0, 3.0, 1.2, 1), Color(0.5, 2.0, 0.6, 0)])
	_sparkle_burst.one_shot = true
	_sparkle_burst.explosiveness = 0.9
	_sparkle_burst.emitting = false
	(_sparkle_burst.process_material as ParticleProcessMaterial).spread = 60.0
	_sparkle_burst.position = at(REACTOR.x, REACTOR.y, base + R_HEIGHT + 0.6)
	_site.add_child(_sparkle_burst)
	# The burner underneath.
	_cyl(0.12, 0.16, 0.3, at(REACTOR.x, REACTOR.y, g + 0.45), _brass, 12)
	_rod(at(REACTOR.x, REACTOR.y, g + 0.45), at(GASHOLDER.x, GASHOLDER.y, ground(GASHOLDER.x, GASHOLDER.y) + 0.3), 0.025, _iron, 6)
	_burner_flame = _particles(_dot_quad(0.16, true), 40, 0.5, Vector3(0.06, 0.01, 0.06), Vector2(0.4, 0.8),
			Vector3(0, 0.6, 0), [Color(0.3, 0.5, 2.5, 0), Color(0.3, 0.6, 2.5, 0.7), Color(0.6, 0.4, 1.5, 0)])
	_burner_flame.position = at(REACTOR.x, REACTOR.y, g + 0.62)
	_site.add_child(_burner_flame)
	_burner_light = OmniLight3D.new()
	_burner_light.light_color = Color(0.45, 0.6, 1.0)
	_burner_light.omni_range = 3.0
	_burner_light.position = at(REACTOR.x, REACTOR.y, g + 0.75)
	_site.add_child(_burner_light)
	# Gauges on the dome: pressure and heat.
	_gauge_needle = _dial(at(REACTOR.x + 0.25, REACTOR.y + 0.62, base + R_HEIGHT + 0.25), PI * 0.5)
	_thermo_needle = _dial(at(REACTOR.x - 0.25, REACTOR.y + 0.62, base + R_HEIGHT + 0.25), PI * 0.5)
	# The relief valve and its vapour; the gas pipe to the gasholder.
	var vent_at := at(REACTOR.x - 0.35, REACTOR.y - 0.3, base + R_HEIGHT + 0.5)
	_rod(at(REACTOR.x - 0.35, REACTOR.y - 0.3, base + R_HEIGHT + 0.3), vent_at, 0.04, _brass, 8)
	_box(Vector3(0.12, 0.12, 0.12), vent_at, _brass)
	_vapour = _steam(Color(1.0, 0.75, 1.0), 50)
	_vapour.position = vent_at + Vector3(0, 0.1, 0)
	_site.add_child(_vapour)
	var gas_from := at(REACTOR.x + 0.2, REACTOR.y - 0.35, base + R_HEIGHT + 0.35)
	var gas_mid := at(REACTOR.x + 0.2, REACTOR.y - 0.35, base + R_HEIGHT + 0.7)
	var gh := ground(GASHOLDER.x, GASHOLDER.y)
	var gas_to := at(GASHOLDER.x, GASHOLDER.y, gh + 3.2)
	_rod(gas_from, gas_mid, 0.035, _iron, 6)
	_rod(gas_mid, Vector3(gas_to.x, gas_mid.y, gas_to.z), 0.035, _iron, 6)
	_site.add_child(HoverNote.new(at(REACTOR.x, REACTOR.y, base + R_HEIGHT * 0.5), Vector3(1.5, R_HEIGHT + 0.8, 1.5),
			"Reactor\nRed and blue, heated and stirred, react to a glowing magenta and give off gas; yellow turns it green."))


## A round brass dial facing +v at `pos`; its needle, to turn.
func _dial(pos: Vector3, face_turn: float) -> Node3D:
	var face := _cyl(0.1, 0.1, 0.02, pos, _brass, 16)
	face.rotation.x = face_turn
	var enamel := StandardMaterial3D.new()
	enamel.albedo_color = Color(0.93, 0.9, 0.82)
	_cyl(0.085, 0.085, 0.005, pos + Vector3(0, 0, 0.012), enamel, 16).rotation.x = face_turn
	var needle := Node3D.new()
	needle.set_meta(StaticMerge.MOVES, true)
	needle.position = pos + Vector3(0, 0, 0.018)
	_site.add_child(needle)
	_box(Vector3(0.008, 0.075, 0.004), Vector3(0, 0.03, 0), _iron, false, needle)
	return needle


## ---- the condenser, receiver and carousel ---------------------------------

func _build_column() -> void:
	var g := ground(COLUMN.x, COLUMN.y)
	var bottom := g + 1.95
	var top := g + 4.4
	# Frame.
	for du: float in [-0.35, 0.35]:
		_rod(at(COLUMN.x + du, COLUMN.y + 0.35, g - 0.1), at(COLUMN.x + du, COLUMN.y + 0.35, top), 0.035, _wood)
	_box(Vector3(0.8, 0.06, 0.12), at(COLUMN.x, COLUMN.y + 0.35, top), _wood)
	_box(Vector3(0.8, 0.06, 0.12), at(COLUMN.x, COLUMN.y + 0.35, bottom), _wood)
	# Inner tube, water jacket, copper coil.
	_cyl(0.07, 0.07, top - bottom, at(COLUMN.x, COLUMN.y, (top + bottom) * 0.5), _glass, 12)
	_cyl(0.22, 0.22, top - bottom - 0.4, at(COLUMN.x, COLUMN.y, (top + bottom) * 0.5), _glass, 20)
	_jacket_water = _cyl(0.2, 0.2, top - bottom - 0.45, at(COLUMN.x, COLUMN.y, (top + bottom) * 0.5), _water, 20)
	var coil := TorusMesh.new()
	coil.inner_radius = 0.12
	coil.outer_radius = 0.145
	coil.material = _copper
	var y := bottom + 0.3
	while y < top - 0.3:
		_put(coil, at(COLUMN.x, COLUMN.y, y), false, Vector3.ZERO, null)
		y += 0.12
	# The gooseneck from the reactor's dome over to the column's head.
	var rg := ground(REACTOR.x, REACTOR.y)
	var dome := at(REACTOR.x + 0.3, REACTOR.y + 0.2, rg + R_BASE + R_HEIGHT + 0.5)
	var up := at(REACTOR.x + 0.3, REACTOR.y + 0.2, top + 0.15)
	_rod(dome, up, 0.05, _copper, 10)
	_rod(up, at(COLUMN.x, COLUMN.y, top + 0.15), 0.05, _copper, 10)
	_rod(at(COLUMN.x, COLUMN.y, top + 0.15), at(COLUMN.x, COLUMN.y, top - 0.1), 0.05, _copper, 10)
	_column_vapour = _particles(_dot_quad(0.06, false), 30, 2.0, Vector3(0.03, 0.05, 0.03), Vector2(0.1, 0.2),
			Vector3(0, -0.6, 0), [Color(0.6, 1.0, 0.7, 0), Color(0.6, 1.0, 0.7, 0.5), Color(0.6, 1.0, 0.7, 0)])
	_column_vapour.position = at(COLUMN.x, COLUMN.y, top - 0.2)
	_site.add_child(_column_vapour)
	_drips = _particles(_dot_quad(0.03, true), 12, 0.25, Vector3(0.005, 0.005, 0.005), Vector2(0.0, 0.1),
			Vector3(0, -9.8, 0), [Color(0.6, 2.5, 0.8, 1), Color(0.6, 2.5, 0.8, 1)])
	_drips.position = at(COLUMN.x, COLUMN.y, bottom - 0.08)
	_site.add_child(_drips)
	# The receiving flask below it.
	var rc := at(COLUMN.x, COLUMN.y, g + 1.35)
	_cyl(0.18, 0.25, 0.85, at(COLUMN.x, COLUMN.y, g + 0.45), _wood, 10)
	var flask := SphereMesh.new()
	flask.radius = 0.42
	flask.height = 0.84
	flask.material = _glass
	_put(flask, rc, false, Vector3.ZERO, null)
	_cyl(0.06, 0.06, 0.3, rc + Vector3(0, 0.5, 0), _glass, 10)
	_receiver_liquid = _cyl(0.38, 0.38, 1.0, Vector3.ZERO, _product_mat, 20)
	_receiver_light = OmniLight3D.new()
	_receiver_light.light_color = GREEN
	_receiver_light.omni_range = 4.0
	_receiver_light.position = rc
	_site.add_child(_receiver_light)
	_receiver_sparkles = _particles(_dot_quad(0.03, true), 20, 1.8, Vector3(0.25, 0.05, 0.25), Vector2(0.1, 0.25),
			Vector3(0, 0.05, 0), [Color(1.0, 3.0, 1.2, 0), Color(1.5, 3.0, 1.0, 1), Color(1.0, 2.0, 0.6, 0)])
	_receiver_sparkles.position = rc + Vector3(0, 0.35, 0)
	_site.add_child(_receiver_sparkles)
	# The tap and spout over the carousel.
	var spout_end := at(CAROUSEL.x + _slot_offset(0).x, CAROUSEL.y + _slot_offset(0).y, ground(CAROUSEL.x, CAROUSEL.y) + 0.9)
	_rod(rc - Vector3(0, 0.42, 0), rc - Vector3(0, 0.55, 0), 0.025, _brass, 8)
	_rod(rc - Vector3(0, 0.55, 0), spout_end, 0.025, _brass, 8)
	_site.add_child(HoverNote.new(at(COLUMN.x, COLUMN.y, (top + bottom) * 0.5), Vector3(0.6, top - bottom, 0.6),
			"Condenser\nThe green vapour cools in the copper coil and drips into the flask below."))


## Where a carousel slot stands relative to its centre: slot 0 faces the
## receiver.
func _slot_offset(slot: int) -> Vector2:
	var toward := (COLUMN - CAROUSEL).normalized()
	var a := atan2(toward.y, toward.x) + TAU * slot / 8.0
	return Vector2(cos(a), sin(a)) * 0.62


func _build_carousel() -> void:
	var g := ground(CAROUSEL.x, CAROUSEL.y)
	_cyl(0.12, 0.2, 0.45, at(CAROUSEL.x, CAROUSEL.y, g + 0.2), _iron, 10)
	_carousel_node = Node3D.new()
	_carousel_node.set_meta(StaticMerge.MOVES, true)
	_carousel_node.position = at(CAROUSEL.x, CAROUSEL.y, g + 0.45)
	_site.add_child(_carousel_node)
	_cyl(0.82, 0.82, 0.05, Vector3.ZERO, _plank, 24, false, _carousel_node)
	var toward := (COLUMN - CAROUSEL).normalized()
	var a0 := atan2(toward.y, toward.x)
	for k in 8:
		var a := a0 + TAU * k / 8.0
		var p := Vector3(cos(a) * 0.62, 0.0, sin(a) * 0.62)
		_cyl(0.07, 0.07, 0.24, p + Vector3(0, 0.15, 0), _glass, 12, false, _carousel_node)
		_cyl(0.025, 0.035, 0.08, p + Vector3(0, 0.31, 0), _glass, 8, false, _carousel_node)
		var liquid := _cyl(0.06, 0.06, 1.0, p, _product_mat, 12, false, _carousel_node)
		liquid.visible = false
		_bottle_liquid.append(liquid)
	# The tally of bottles made, on brass wheels.
	var case_at := at(CAROUSEL.x + 0.95, CAROUSEL.y, g + 0.45)
	_box(Vector3(0.06, 0.18, 0.42), case_at, _brass)
	for k in 3:
		var digit := Label3D.new()
		digit.text = "0"
		digit.font_size = 64
		digit.pixel_size = 0.0018
		digit.modulate = Color(0.1, 0.08, 0.06)
		digit.outline_size = 0
		digit.position = case_at + Vector3(0.035, 0, 0.12 - 0.12 * k)
		digit.rotation.y = PI * 0.5
		_site.add_child(digit)
		_digits.append(digit)
	_site.add_child(HoverNote.new(at(CAROUSEL.x, CAROUSEL.y, g + 0.6), Vector3(1.7, 0.5, 1.7),
			"Bottling carousel\nFills a bottle under the spout, then turns one place on."))


## ---- the gasholder and the flare -----------------------------------------

func _build_gasholder() -> void:
	var g := ground(GASHOLDER.x, GASHOLDER.y)
	var tank := CylinderMesh.new()
	tank.top_radius = 1.25
	tank.bottom_radius = 1.25
	tank.height = 1.0
	tank.cap_top = false
	tank.radial_segments = 24
	var iron2 := _iron.duplicate() as StandardMaterial3D
	iron2.cull_mode = BaseMaterial3D.CULL_DISABLED
	tank.material = iron2
	_put(tank, at(GASHOLDER.x, GASHOLDER.y, g + 0.4), true, Vector3(2.3, 1.0, 2.3), null)
	_cyl(1.2, 1.2, 0.02, at(GASHOLDER.x, GASHOLDER.y, g + 0.85), _water, 24)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		_rod(at(GASHOLDER.x + cos(a) * 1.35, GASHOLDER.y + sin(a) * 1.35, g - 0.1),
				at(GASHOLDER.x + cos(a) * 1.35, GASHOLDER.y + sin(a) * 1.35, g + 3.2), 0.05, _iron, 8)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.3
	ring.outer_radius = 1.4
	ring.material = _iron
	_put(ring, at(GASHOLDER.x, GASHOLDER.y, g + 3.2), false, Vector3.ZERO, null)
	_bell = Node3D.new()
	_bell.set_meta(StaticMerge.MOVES, true)
	_site.add_child(_bell)
	_cyl(1.12, 1.12, 1.4, Vector3(0, 0.7, 0), _iron, 24, false, _bell)
	var cap := SphereMesh.new()
	cap.radius = 1.12
	cap.height = 0.5
	cap.is_hemisphere = true
	cap.material = _iron
	_put(cap, Vector3(0, 1.4, 0), false, Vector3.ZERO, _bell)
	_site.add_child(HoverNote.new(at(GASHOLDER.x, GASHOLDER.y, g + 1.4), Vector3(2.6, 2.8, 2.6),
			"Gasholder\nIts bell rises in the water as the reactor's gas fills it."))


func _build_flare() -> void:
	var g := ground(FLARE.x, FLARE.y)
	var tip := at(FLARE.x, FLARE.y, g + 5.0)
	_rod(at(FLARE.x, FLARE.y, g - 0.2), tip, 0.09, _iron, 10)
	_cyl(0.16, 0.1, 0.25, tip + Vector3(0, 0.1, 0), _copper, 12)
	for k in 3:
		var a := TAU * k / 3.0
		_rod(at(FLARE.x + cos(a) * 1.6, FLARE.y + sin(a) * 1.6, g), tip - Vector3(0, 1.5, 0), 0.012, _iron, 4)
	var gh := ground(GASHOLDER.x, GASHOLDER.y)
	_rod(at(GASHOLDER.x - 1.25, GASHOLDER.y, gh + 0.3), at(FLARE.x, FLARE.y, gh + 0.3), 0.04, _iron, 6)
	_flare_flame = _particles(_dot_quad(0.5, true), 60, 0.9, Vector3(0.08, 0.05, 0.08), Vector2(1.2, 2.2),
			Vector3(0.3, 1.5, 0), [Color(0.3, 2.5, 1.2, 0), Color(0.3, 1.6, 2.6, 0.7), Color(1.6, 0.5, 2.4, 0.5), Color(0.8, 0.2, 1.0, 0)])
	_flare_flame.position = tip + Vector3(0, 0.25, 0)
	_flare_flame.emitting = false
	_site.add_child(_flare_flame)
	_flare_sparks = _particles(_dot_quad(0.04, true), 30, 1.4, Vector3(0.1, 0.1, 0.1), Vector2(1.5, 3.0),
			Vector3(0.4, -2.0, 0), [Color(3.0, 2.5, 1.0, 1), Color(2.0, 1.2, 3.0, 0)])
	(_flare_sparks.process_material as ParticleProcessMaterial).spread = 45.0
	_flare_sparks.position = tip + Vector3(0, 0.3, 0)
	_flare_sparks.emitting = false
	_site.add_child(_flare_sparks)
	_flare_light = OmniLight3D.new()
	_flare_light.omni_range = 14.0
	_flare_light.position = tip + Vector3(0, 0.8, 0)
	_flare_light.visible = false
	_site.add_child(_flare_light)
	_site.add_child(HoverNote.new(tip - Vector3(0, 2.5, 0), Vector3(0.6, 5.0, 0.6),
			"Flare stack\nBurns off the gas when the gasholder is full; the copper in it colours the flame."))


## ---- the steam engine ------------------------------------------------------

func _build_engine() -> void:
	var g := ground(ENGINE.x, ENGINE.y)
	# The boiler on its firebox, its chimney and whistle.
	_box(Vector3(1.6, 0.5, 0.9), at(ENGINE.x - 1.2, ENGINE.y, g + 0.15), _stone, true)
	var boiler := _cyl(0.42, 0.42, 1.5, at(ENGINE.x - 1.2, ENGINE.y, g + 0.85), _copper, 16, false)
	boiler.rotation.z = PI * 0.5
	_rod(at(ENGINE.x - 1.85, ENGINE.y, g + 1.1), at(ENGINE.x - 1.85, ENGINE.y, g + 2.6), 0.08, _iron, 10)
	_cyl(0.05, 0.03, 0.25, at(ENGINE.x - 0.7, ENGINE.y, g + 1.4), _brass, 10)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.5, 0.2)
	glow.light_energy = 0.6
	glow.omni_range = 2.0
	glow.position = at(ENGINE.x - 1.2, ENGINE.y + 0.5, g + 0.2)
	_site.add_child(glow)
	# The cylinder, piston and flywheel.
	_cyl(0.12, 0.12, 0.45, at(ENGINE.x, ENGINE.y, g + 1.15), _iron, 12)
	_rod(at(ENGINE.x - 0.4, ENGINE.y, g + 1.1), at(ENGINE.x, ENGINE.y, g + 1.1), 0.03, _brass, 6)
	_piston = Node3D.new()
	_piston.set_meta(StaticMerge.MOVES, true)
	_site.add_child(_piston)
	_cyl(0.02, 0.02, 0.6, Vector3(0, 0.3, 0), _brass, 6, false, _piston)
	_flywheel = Node3D.new()
	_flywheel.set_meta(StaticMerge.MOVES, true)
	_flywheel.position = at(ENGINE.x + 0.6, ENGINE.y, g + 0.9)
	_site.add_child(_flywheel)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.52
	rim.outer_radius = 0.6
	rim.rings = 32
	rim.material = _iron
	var rim_view := _put(rim, Vector3.ZERO, false, Vector3.ZERO, _flywheel)
	rim_view.rotation.z = PI * 0.5
	for k in 6:
		var spoke := _box(Vector3(0.03, 1.05, 0.04), Vector3.ZERO, _iron, false, _flywheel)
		spoke.rotation.x = PI * k / 6.0
	_cyl(0.06, 0.06, 0.2, Vector3.ZERO, _brass, 10, false, _flywheel).rotation.z = PI * 0.5
	for dv: float in [-0.25, 0.25]:
		_box(Vector3(0.08, 0.9, 0.08), at(ENGINE.x + 0.6, ENGINE.y + dv, g + 0.45), _wood)
	_puff = _steam(Color(1, 1, 1), 12)
	_puff.one_shot = true
	_puff.explosiveness = 0.8
	_puff.position = at(ENGINE.x - 1.85, ENGINE.y, g + 2.65)
	_site.add_child(_puff)
	_site.add_child(HoverNote.new(at(ENGINE.x - 0.6, ENGINE.y, g + 0.8), Vector3(2.6, 1.6, 1.2),
			"Steam engine\nTurns the stirrer by its belt while the recipe calls for stirring or dosing; its whistle ends each batch."))


## ---- the sequencer drum ----------------------------------------------------

const DRUM_LEN := 3.5
const DRUM_R := 0.32
const TRACKS := 14
const TRACK_W := 0.24


func _track_u(t: int) -> float:
	return DRUM.x - (TRACKS - 1) * TRACK_W * 0.5 + t * TRACK_W


func _build_drum() -> void:
	var g := ground(DRUM.x, DRUM.y)
	var axle_y := g + 1.1
	for du: float in [-DRUM_LEN * 0.5 - 0.15, DRUM_LEN * 0.5 + 0.15]:
		_box(Vector3(0.12, axle_y - g + 0.25, 0.5), at(DRUM.x + du, DRUM.y, (axle_y + g) * 0.5), _wood, true)
	_box(Vector3(DRUM_LEN + 0.5, 0.08, 0.12), at(DRUM.x, DRUM.y, axle_y + 0.55), _wood)
	_drum = Node3D.new()
	_drum.set_meta(StaticMerge.MOVES, true)
	_drum.position = at(DRUM.x, DRUM.y, axle_y)
	_site.add_child(_drum)
	_cyl(DRUM_R, DRUM_R, DRUM_LEN, Vector3.ZERO, _brass, 24, false, _drum).rotation.z = PI * 0.5
	_cyl(0.03, 0.03, DRUM_LEN + 0.4, Vector3.ZERO, _iron, 8, false, _drum).rotation.z = PI * 0.5
	# Pegs: a track's peg for step s stands at the angle that brings it
	# to the top when the drum is on step s.
	for t in TRACKS:
		for s in STEPS:
			if not _peg(t, s):
				continue
			var a := TAU * s / STEPS
			var peg := _cyl(0.025, 0.025, 0.08, Vector3(_track_u(t) - DRUM.x, cos(a) * (DRUM_R + 0.03), sin(a) * (DRUM_R + 0.03)), _iron, 6, false, _drum)
			peg.basis = _aligned(Vector3(0, cos(a), sin(a)))
	_site.add_child(HoverNote.new(at(DRUM.x, DRUM.y, axle_y), Vector3(DRUM_LEN, 0.8, 0.8),
			"Sequencer drum: the recipe, one notch a step\n0 wait for stock and room   1 charge red   2 charge blue, stir   3 heat   4 react 8 s   5 add yellow   6 distil   7 cool"))


## Whether track t has a peg for step s: the first eight tracks mark one
## step each, the rest are the outputs.
func _peg(t: int, s: int) -> bool:
	if t < STEPS:
		return t == s
	return s in PEGS[OUTPUTS[t - STEPS]]


## ---- the circuit -----------------------------------------------------------

## A column of lanterns on one post at (u, v), from `y0` up by `dy`.
func _mast(u: float, v: float, titles: Array, keys: Array, y0: float, dy := 0.38) -> void:
	var column := _lantern_column(u, v, titles, y0, dy)
	for i in keys.size():
		_l[keys[i]] = column[i]


func _build_circuit() -> void:
	var gd := ground(DRUM.x, DRUM.y)
	# The drum's lanterns, on short posts on its top bar.
	var drum_titles := ["step 0: waiting", "step 1: charging red", "step 2: charging blue", "step 3: heating",
			"step 4: reacting", "step 5: adding yellow", "step 6: distilling", "step 7: cooling",
			"the recipe calls for red", "the recipe calls for blue", "the recipe calls for yellow",
			"the recipe calls for heat", "the recipe calls for stirring", "the recipe calls for distilling"]
	for t in TRACKS:
		var p := LumenPart.new(LumenPart.Kind.LANTERN, drum_titles[t], at(_track_u(t), DRUM.y, gd + 2.0), gd + 1.68, _wood, _brass)
		_site.add_child(p)
		parts.append(p)
		_drum_lanterns.append(p)
	# The machines' lanterns.
	_mast(REACTOR.x + 1.3, REACTOR.y + 1.7,
			["the reactor is a third full", "the reactor is two thirds full", "the reactor is full",
			"the reactor is nearly empty", "the brew is hot", "the brew has cooled"],
			["lvl1", "lvl2", "full", "low", "hot", "cool"], 1.6)
	_mast(REACTOR.x - 1.1, REACTOR.y - 0.6, ["the pressure is high"], ["press"], 3.4)
	_mast(GASHOLDER.x - 1.7, GASHOLDER.y + 0.9, ["the gasholder is nearly empty", "the gasholder is full"], ["gas_lo", "gas_hi"], 2.6)
	_mast(-4.0, 11.2, ["there is red in stock", "there is blue in stock", "there is yellow in stock"], ["red_ok", "blue_ok", "yel_ok"], 2.0)
	_mast(COLUMN.x + 0.9, COLUMN.y + 1.0, ["the flask holds product", "the flask has room"], ["recv", "room"], 2.0)
	_mast(CAROUSEL.x + 1.3, CAROUSEL.y - 0.9, ["an empty bottle is under the spout", "a full bottle is under the spout"], ["b_empty", "b_full"], 1.6)
	# The recipe's transitions: a step's lantern AND its condition.
	var ga := func(u: float, v: float) -> float: return ground(u, v) + 2.6
	var and_stock := _part(LumenPart.Kind.AND, "all three tinctures in stock", -4.0, 12.8, ga.call(-4.0, 12.8))
	var trans: Array[LumenPart] = []
	var trans_titles := ["step 0 done: ready to start", "step 1 done: red charged", "step 2 done: blue charged",
			"step 3 done: hot", "step 4 done: reacted", "step 5 done: yellow charged", "step 6 done: distilled",
			"step 7 done: cooled"]
	for k in STEPS:
		var u := -1.0 + 1.05 * k
		var v := 13.4
		if k == 4:
			trans.append(_part(LumenPart.Kind.TON, trans_titles[k], u, v, ga.call(u, v), 8.0))
		else:
			trans.append(_part(LumenPart.Kind.AND, trans_titles[k], u, v, ga.call(u, v)))
	var or_step := _part(LumenPart.Kind.OR, "a step is done", 3.0, 15.6, ga.call(3.0, 15.6) + 0.3)
	var rise_step := _part(LumenPart.Kind.RISE, "step on", 7.8, 14.2, ga.call(7.8, 14.2))
	var rise_end := _part(LumenPart.Kind.RISE, "a batch is finished", 8.6, 12.6, ga.call(8.6, 12.6))
	var latch_flare := _part(LumenPart.Kind.LATCH, "burning off gas", GASHOLDER.x - 2.6, GASHOLDER.y + 2.2, 3.0 + ground(GASHOLDER.x - 2.6, GASHOLDER.y + 2.2))
	var and_spout := _part(LumenPart.Kind.AND, "fill a bottle", COLUMN.x + 2.2, COLUMN.y + 1.6, ground(COLUMN.x + 2.2, COLUMN.y + 1.6) + 2.6)
	var rise_full := _part(LumenPart.Kind.RISE, "a bottle is full", CAROUSEL.x + 2.4, CAROUSEL.y + 0.6, ground(CAROUSEL.x + 2.4, CAROUSEL.y + 0.6) + 2.4)
	# The radiometers at the machines.
	var R := func(key: String, title: String, u: float, v: float, h: float) -> LumenPart:
		var p := _part(LumenPart.Kind.RADIOMETER, title, u, v, ground(u, v) + h)
		_r[key] = p
		return p
	R.call("advance", "turns the drum one notch", DRUM.x + DRUM_LEN * 0.5 + 0.5, DRUM.y + 0.5, 1.7)
	R.call("red", "opens the red tank's valve", TANK_U[0], 8.0, 2.4)
	R.call("blue", "opens the blue tank's valve", TANK_U[1], 8.0, 2.4)
	R.call("yellow", "opens the yellow tank's valve", TANK_U[2], 8.0, 2.4)
	R.call("heat", "lights the burner", REACTOR.x - 1.0, REACTOR.y + 0.9, 1.4)
	R.call("stir", "engages the stirrer's belt", ENGINE.x + 1.2, ENGINE.y - 0.6, 1.8)
	R.call("distil", "opens the condenser's water and vapour", COLUMN.x - 0.6, COLUMN.y + 0.8, 2.6)
	R.call("vent", "opens the relief valve", REACTOR.x - 0.9, REACTOR.y - 1.3, 3.1)
	R.call("flare", "opens the flare's gas and strikes it", FLARE.x + 0.8, FLARE.y + 0.6, 1.8)
	R.call("spout", "opens the spout", COLUMN.x + 0.8, COLUMN.y - 1.1, 1.7)
	R.call("carousel", "turns the carousel one place", CAROUSEL.x + 0.2, CAROUSEL.y - 1.2, 1.4)
	R.call("whistle", "blows the steam whistle", ENGINE.x - 0.7, ENGINE.y - 0.7, 2.0)

	# The wires.
	_wire(_l["red_ok"], and_stock)
	_wire(_l["blue_ok"], and_stock)
	_wire(_l["yel_ok"], and_stock)
	var conditions: Array = [null, _l["lvl1"], _l["lvl2"], _l["hot"], null, _l["full"], _l["low"], _l["cool"]]
	for k in STEPS:
		_wire(_drum_lanterns[k], trans[k])
		if k == 0:
			_wire(and_stock, trans[0])
			_wire(_l["room"], trans[0])
		elif conditions[k] != null:
			_wire(conditions[k], trans[k])
		_wire(trans[k], or_step)
	_wire(or_step, rise_step)
	_wire(rise_step, _r["advance"])
	_wire(trans[7], rise_end)
	_wire(rise_end, _r["whistle"])
	for i in OUTPUTS.size():
		_wire(_drum_lanterns[STEPS + i], _r[OUTPUTS[i]])
	_wire(_l["press"], _r["vent"])
	_wire(_l["gas_hi"], latch_flare)
	_wire(_l["gas_lo"], latch_flare)
	_wire(latch_flare, _r["flare"])
	_wire(_l["recv"], and_spout)
	_wire(_l["b_empty"], and_spout)
	_wire(and_spout, _r["spout"])
	_wire(_l["b_full"], rise_full)
	_wire(rise_full, _r["carousel"])

	var lg := ground(DRUM.x - 2.4, DRUM.y + 1.2)
	_lever = WorksHandle.new(WorksHandle.Kind.LEVER, at(DRUM.x - 2.4, DRUM.y + 1.2, lg + 0.55), _wood, _iron,
			"Run lever\nE: hold or release the recipe drum. Safety valves and bottling carry on.")
	_site.add_child(_lever)


## ---- particles and sounds --------------------------------------------------

func _dot_quad(size: float, additive: bool) -> QuadMesh:
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
	fade.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	dot.gradient = fade
	mat.albedo_texture = dot
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	return quad


## Particles of `mesh`: `amount` alive, living `life` s, born in a box of
## `extents`, leaving upward at `speed` (least, most), accelerated by
## `accel`, coloured over life by `colours` spread evenly.
func _particles(mesh: Mesh, amount: int, life: float, extents: Vector3, speed: Vector2,
		accel: Vector3, colours: Array) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.direction = Vector3.UP
	process.spread = 12.0
	process.initial_velocity_min = speed.x
	process.initial_velocity_max = speed.y
	process.gravity = accel
	var ramp := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colours.size():
		offsets.append(float(i) / maxf(colours.size() - 1, 1))
	ramp.offsets = offsets
	ramp.colors = PackedColorArray(colours)
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	ramp_tex.use_hdr = true
	process.color_ramp = ramp_tex
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.process_material = process
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 10, 8))
	return p


## Steam or vapour puffs of `colour`, swelling as they rise.
func _steam(colour: Color, amount: int) -> GPUParticles3D:
	var p := _particles(_dot_quad(0.5, false), amount, 2.2, Vector3(0.05, 0.05, 0.05), Vector2(0.8, 1.4),
			Vector3(0.3, 0.6, 0), [Color(colour, 0.0), Color(colour, 0.45), Color(colour, 0.0)])
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(1.0, 2.0))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	(p.process_material as ParticleProcessMaterial).scale_curve = curve_tex
	p.emitting = false
	return p


func _build_sounds() -> void:
	var rg := ground(REACTOR.x, REACTOR.y)
	var rpos := at(REACTOR.x, REACTOR.y, rg + R_BASE + 0.8)
	_snd_bubble = _speaker("res://audio/bubble_loop.wav", true, rpos)
	_snd_hiss = _speaker("res://audio/hiss_loop.wav", true, rpos + Vector3(0, 1.2, 0))
	var fg := ground(FLARE.x, FLARE.y)
	_snd_flare = _speaker("res://audio/flare_loop.wav", true, at(FLARE.x, FLARE.y, fg + 5.0), 10.0)
	_snd_chime = _speaker("res://audio/chime.wav", false, rpos, 8.0)
	var eg := ground(ENGINE.x, ENGINE.y)
	_snd_chuff = _speaker("res://audio/chuff.wav", false, at(ENGINE.x - 1.85, ENGINE.y, eg + 2.6), 4.0)
	_snd_whistle = _speaker("res://audio/whistle.wav", false, at(ENGINE.x - 0.7, ENGINE.y, eg + 1.4), 12.0)
	_snd_ratchet = _speaker("res://audio/ratchet.wav", false, at(DRUM.x, DRUM.y, ground(DRUM.x, DRUM.y) + 1.1), 4.0)
	var cg := ground(COLUMN.x, COLUMN.y)
	_snd_drip = _speaker("res://audio/drip_one_c1.wav", false, at(COLUMN.x, COLUMN.y, cg + 1.7), 3.0)
	if DisplayServer.get_name() != "headless":
		for k in 5:
			_drip_streams.append(load("res://audio/drip_one_c%d.wav" % (k + 1)))
	var valves := {"red": at(TANK_U[0], 8.6, 1.0), "blue": at(TANK_U[1], 8.6, 1.0), "yellow": at(TANK_U[2], 8.6, 1.0),
			"distil": at(COLUMN.x, COLUMN.y, cg + 2.0), "vent": rpos + Vector3(0, 1.2, 0),
			"flare": at(FLARE.x, FLARE.y, fg + 0.6), "spout": at(COLUMN.x, COLUMN.y, cg + 0.8), "heat": at(REACTOR.x, REACTOR.y, rg + 0.5)}
	var k := 0
	for key: String in valves:
		_clanks[key] = _speaker("res://audio/clank_%d.wav" % (1 + k % 2), false, valves[key], 4.0)
		k += 1


## ---- the simulation --------------------------------------------------------

func _volume() -> float:
	return float(_vol["red"]) + float(_vol["blue"]) + float(_vol["yellow"])


## The brew's colour and glow: the tinctures mixed by volume, turned
## toward magenta as red and blue react and toward green as yellow turns
## it.
func _brew() -> Array:
	var total := maxf(_volume(), 0.0001)
	var mix: Color = RED * (float(_vol["red"]) / total) + BLUE * (float(_vol["blue"]) / total) + YELLOW * (float(_vol["yellow"]) / total)
	mix = mix.lerp(MAGENTA, _aether * (float(_vol["red"]) + float(_vol["blue"])) / total)
	mix = mix.lerp(GREEN, _elixir)
	var glow := _aether * 0.8 + _elixir * 2.0
	return [mix, glow]


func _edge(key: String) -> bool:
	var now: bool = (_r[key] as LumenPart).powered
	var was: bool = _was.get(key, false)
	_was[key] = now
	return now and not was


func _on(key: String) -> bool:
	return (_r[key] as LumenPart).spin > 0.5


func _physics_process(dt: float) -> void:
	_clock += dt
	# The drum: a notch per ratchet stroke; its lanterns shut while it
	# turns or while the run lever holds it.
	if _edge("advance"):
		_step = (_step + 1) % STEPS
		_play(_snd_ratchet)
	var target := TAU * _step / STEPS
	var turn := absf(angle_difference(_drum_angle, target)) > 0.02
	_drum_angle = rotate_toward(_drum_angle, target, dt * 2.0)
	for t in TRACKS:
		_drum_lanterns[t].condition = _lever.on and not turn and _peg(t, _step)
	# Valves follow their radiometers, clanking as they go over.
	for key: String in ["red", "blue", "yellow"]:
		var open := _on(key) and float(_stock[key]) > 0.01 and _volume() < 1.0
		var was: float = _tank_valves.get(key, 0.0)
		_tank_valves[key] = move_toward(was, 1.0 if open else 0.0, dt * 3.0)
		if (was <= 0.0 and float(_tank_valves[key]) > 0.0) or (was >= 1.0 and float(_tank_valves[key]) < 1.0):
			_play(_clanks[key], randf_range(0.9, 1.1))
		var flow := DOSE * float(_tank_valves[key]) * dt
		flow = minf(flow, float(_stock[key]) * 1.5)
		_stock[key] = float(_stock[key]) - flow / 1.5
		_vol[key] = float(_vol[key]) + flow
		# The springs top the tanks up.
		_stock[key] = minf(float(_stock[key]) + 0.006 * dt, 1.0)
	for key: String in ["distil", "vent", "flare", "spout", "heat"]:
		var now := _on(key)
		if now != bool(_was.get("v_" + key, false)):
			_play(_clanks[key], randf_range(0.85, 1.15))
		_was["v_" + key] = now
	# Heat and stirring; the engine runs while anything needs it.
	_burner = move_toward(_burner, 1.0 if _on("heat") else 0.0, dt * 2.0)
	var stirring := _on("stir")
	var dosing := float(_tank_valves.get("red", 0.0)) + float(_tank_valves.get("blue", 0.0)) + float(_tank_valves.get("yellow", 0.0)) > 0.0
	_engine = move_toward(_engine, 1.0 if stirring or dosing else 0.0, dt * 0.8)
	var before := _engine_angle
	_engine_angle += _engine * 7.0 * dt
	if floori(_engine_angle / PI) != floori(before / PI):
		_play(_snd_chuff, randf_range(0.92, 1.08))
		_puff.restart()
	if stirring:
		_stir_angle += _engine * 6.0 * dt
	var vol := _volume()
	var cooling := 0.09 + (0.06 if _on("distil") else 0.0)
	_temp += (_burner * 14.0 * (1.0 if vol > 0.02 else 0.4) - (_temp - 20.0) * cooling) * dt
	if vol > 0.02 and _temp > 100.0:
		_temp = 100.0
	# The first reaction: red and blue at heat, faster stirred, giving gas.
	var rb := float(_vol["red"]) + float(_vol["blue"])
	if _temp > 60.0 and rb > 0.05 and _aether < 1.0:
		var rate := 0.11 * (1.0 if stirring else 0.3) * dt
		_aether = minf(_aether + rate, 1.0)
		_pressure += rate * 6.0
	# The second: yellow turns the aether to elixir, flashing over.
	if float(_vol["yellow"]) > 0.02 and _aether > 0.5:
		_elixir = minf(_elixir + 0.5 * float(_vol["yellow"]) * dt * (1.0 if stirring else 0.4), 1.0)
		_pressure += 0.6 * dt
		if not _flashed and _elixir > 0.25:
			_flashed = true
			_sparkle_burst.restart()
			_play(_snd_chime)
	# Gas: into the gasholder above 1 bar; out of the relief valve when
	# it opens; burnt at the flare.
	var to_holder := maxf(_pressure - 1.0, 0.0) * 0.4 * dt
	if _gas < 1.0:
		_pressure -= to_holder
		_gas = minf(_gas + to_holder * 0.25, 1.0)
	_vent = move_toward(_vent, 1.0 if _on("vent") else 0.0, dt * 4.0)
	_pressure = maxf(_pressure - _vent * 0.8 * dt, 1.0)
	_flare = move_toward(_flare, 1.0 if _on("flare") and _gas > 0.02 else 0.0, dt * 2.0)
	_gas = maxf(_gas - _flare * 0.06 * dt, 0.0)
	# Distilling: the brew boils over into the condenser and drips, drop
	# by drop, into the flask.
	if _on("distil") and _temp >= 99.0 and vol > 0.0:
		var over := minf(DISTIL_RATE * _burner * dt, vol)
		var share := over / vol
		for key: String in _vol:
			_vol[key] = float(_vol[key]) * (1.0 - share)
		_drop += over
		if _drop >= DROP:
			_drop -= DROP
			_received = minf(_received + DROP, RECEIVER)
			if not _drip_streams.is_empty():
				_snd_drip.stream = _drip_streams[randi() % _drip_streams.size()]
				_play(_snd_drip, randf_range(0.9, 1.15))
	# A batch's end: the reactor emptied, the brew forgotten.
	if _step == 0 and vol < 0.02:
		for key: String in _vol:
			_vol[key] = 0.0
		_aether = 0.0
		_elixir = 0.0
		_flashed = false
	# Bottling.
	_spout = move_toward(_spout, 1.0 if _on("spout") else 0.0, dt * 3.0)
	var pour := minf(SPOUT_RATE * _spout * dt, _received)
	pour = minf(pour, BOTTLE - _bottles[_carousel])
	_bottles[_carousel] += pour
	_received -= pour
	if _edge("carousel"):
		_carousel = (_carousel + 1) % 8
		# The bottle coming round to the far side is taken away full.
		var far := (_carousel + 4) % 8
		if _bottles[far] > BOTTLE * 0.9:
			_made = (_made + 1) % 1000
			for k in 3:
				_digits[k].text = str(_made / int(pow(10, 2 - k)) % 10)
		_bottles[far] = 0.0
	if _edge("whistle"):
		_play(_snd_whistle)
	# The lanterns' conditions.
	var lvl := _volume()
	# Each mark sits a little under its share: the valve takes a few
	# seconds to hear the drum and close, and pours on meanwhile.
	_l["lvl1"].condition = lvl > 0.25
	_l["lvl2"].condition = lvl > 0.55
	_l["full"].condition = lvl > 0.9
	_l["low"].condition = lvl < 0.04
	_l["hot"].condition = _temp > 80.0
	_l["cool"].condition = _temp < 40.0
	_l["press"].condition = _pressure > (1.3 if _l["press"].condition else 1.8)
	_l["gas_hi"].condition = _gas > 0.85
	_l["gas_lo"].condition = _gas < 0.15
	_l["red_ok"].condition = float(_stock["red"]) > 0.25
	_l["blue_ok"].condition = float(_stock["blue"]) > 0.25
	_l["yel_ok"].condition = float(_stock["yellow"]) > 0.25
	_l["recv"].condition = _received > 0.01
	_l["room"].condition = _received < RECEIVER - 1.1
	_l["b_empty"].condition = _bottles[_carousel] < BOTTLE * 0.98
	_l["b_full"].condition = _bottles[_carousel] >= BOTTLE * 0.98
	_step_circuit(dt)


func _process(delta: float) -> void:
	_drum.rotation.x = -_drum_angle
	# The tanks.
	for i in 3:
		var key: String = ["red", "blue", "yellow"][i]
		var entry: Array = _tank_liquid[key]
		var tank_h := maxf(float(entry[2]) * float(_stock[key]), 0.01)
		var mesh := entry[0] as MeshInstance3D
		mesh.position = at(TANK_U[i], TANK_V, float(entry[1]) + tank_h * 0.5)
		mesh.scale = Vector3(1, tank_h, 1)
		(_valve_wheels[key] as Node3D).rotation.y = float(_tank_valves.get(key, 0.0)) * TAU
	# The brew.
	var rg := ground(REACTOR.x, REACTOR.y)
	var base := rg + R_BASE + 0.03
	var vol := _volume()
	var h := maxf(R_HEIGHT * 0.95 * vol, 0.01)
	_reactor_liquid.visible = vol > 0.005
	_reactor_liquid.position = at(REACTOR.x, REACTOR.y, base + h * 0.5)
	_reactor_liquid.scale = Vector3(1, h, 1)
	var brew := _brew()
	var colour: Color = brew[0]
	var glow: float = brew[1] * (1.0 + 0.15 * sin(_clock * 3.1) * _elixir)
	_liquid_mat.albedo_color = Color(colour, 0.88)
	_liquid_mat.emission = colour
	_liquid_mat.emission_energy_multiplier = glow
	_reactor_light.visible = vol > 0.02 and glow > 0.05
	_reactor_light.light_color = colour
	_reactor_light.light_energy = glow * 1.2
	_bubble_mat.albedo_color = Color(colour.lightened(0.5), 0.6)
	_bubble_mat.emission = colour
	_bubbles.emitting = vol > 0.05 and _temp > 70.0
	# A new lifetime restarts every bubble, so it changes only in steps.
	var life := snappedf(maxf(h / 0.45, 0.4), 0.5)
	if not is_equal_approx(_bubbles.lifetime, life):
		_bubbles.lifetime = life
	_stirrer.rotation.y = _stir_angle
	_burner_flame.emitting = _burner > 0.1
	_burner_flame.amount_ratio = maxf(_burner, 0.05)
	_burner_light.visible = _burner > 0.05
	_burner_light.light_energy = _burner * 1.2
	_gauge_needle.rotation.z = -clampf((_pressure - 1.0) / 1.5, 0.0, 1.0) * 4.0 + 2.0
	_thermo_needle.rotation.z = -clampf(_temp / 120.0, 0.0, 1.0) * 4.0 + 2.0
	_vapour.emitting = _vent > 0.3
	# Gas.
	var gh := ground(GASHOLDER.x, GASHOLDER.y)
	_bell.position = at(GASHOLDER.x, GASHOLDER.y, gh + 0.2 + _gas * 1.3)
	_flare_flame.emitting = _flare > 0.1
	_flare_sparks.emitting = _flare > 0.5
	_flare_light.visible = _flare > 0.05
	var hue := fposmod(_clock * 0.08, 1.0)
	_flare_light.light_color = Color.from_hsv(0.35 + 0.4 * (0.5 + 0.5 * sin(hue * TAU)), 0.7, 1.0)
	_flare_light.light_energy = _flare * (2.0 + 0.5 * sin(_clock * 17.0) * sin(_clock * 5.3))
	# Distilling and the flask.
	var distilling := _on("distil") and _temp >= 99.0 and vol > 0.0
	_column_vapour.emitting = distilling
	_drips.emitting = distilling
	var cg := ground(COLUMN.x, COLUMN.y)
	var rc_y := cg + 1.35
	var fill := _received / RECEIVER
	var rh := maxf(0.72 * fill, 0.01)
	_receiver_liquid.visible = _received > 0.005
	_receiver_liquid.position = at(COLUMN.x, COLUMN.y, rc_y - 0.36 + rh * 0.5)
	_receiver_liquid.scale = Vector3(1, rh, 1)
	_receiver_light.visible = _received > 0.02
	_receiver_light.light_energy = 0.6 + fill * 1.2
	_receiver_sparkles.emitting = _received > 0.05
	_product_mat.emission_energy_multiplier = 2.0 + 0.4 * sin(_clock * 2.3)
	# The carousel turns to put the current slot under the spout.
	var target := TAU * _carousel / 8.0
	_carousel_angle = rotate_toward(_carousel_angle, target, delta * 1.5)
	_carousel_node.rotation.y = _carousel_angle
	for k in 8:
		var f := _bottles[k] / BOTTLE
		var liquid := _bottle_liquid[k]
		liquid.visible = f > 0.02
		var bh := 0.22 * f
		liquid.position.y = 0.04 + bh * 0.5
		liquid.scale = Vector3(1, maxf(bh, 0.005), 1)
	# The engine.
	_flywheel.rotation.x = _engine_angle
	var eg := ground(ENGINE.x, ENGINE.y)
	_piston.position = at(ENGINE.x, ENGINE.y, eg + 1.15) + Vector3(0, 0.12 + 0.18 * sin(_engine_angle), 0)
	# Sounds that follow levels.
	var boiling := vol > 0.05 and _temp > 90.0
	_level(_snd_bubble, (0.5 + 0.5 * _elixir) if boiling else 0.0, -4.0)
	_level(_snd_hiss, _vent, -2.0)
	_level(_snd_flare, _flare, 0.0)
