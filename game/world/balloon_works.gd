class_name BalloonWorks
extends BeachSite
## A balloon works on the cozy island's west beach: a tethered balloon
## that harvests water from the air, run by light-beam logic
## (LumenPart, LumenBeam).
##
## The physics it starts from, scaled for the island: air cools about
## 6.5 degrees a kilometre of height; here a metre of tether stands for
## ten metres of sky, so the balloon at 260 m is in air as cold as 2.6 km
## up. Its fog net gathers water as fog nets in Chile and Morocco do,
## richly inside cloud; the island has no clouds yet, so it gathers only
## the little in clear air. Where the air is below freezing the water
## gathers as frost and icicles instead. The
## harvest is richest at dawn, good at night, poorest at noon. Wind blows
## in gusts and now and then a gale, stronger aloft.
##
## The machines. A steam winch pays the tether out (the balloon's lift
## pulls it up, the pawl clicking on the ratchet) and reels it in (the
## engine chuffing). Back in its landing cradle, a brazier under a copper
## trough thaws the ice and the meltwater runs into a cistern; a bell
## rings at each landing. An anemometer and a vane stand on a mast; dials
## on the winch house read the balloon's height and the cold up there.
## The cloud water glows faintly pale blue (a whimsy, not physics).
##
## The circuit, in ladder terms:
##   gale about = TOF 12 s ( TON 2 s ( gale ) )
##   HARVEST    = latch: set by basket empty AND cistern has room AND run
##                lever AND NOT gale about; reset by basket heavy OR gale about
##   UP         = HARVEST AND NOT at the top
##   DOWN       = NOT HARVEST AND NOT docked
##   THAW       = docked AND ice in the basket
##   DRAIN      = docked AND NOT basket empty AND cistern has room
##   BELL       = rising edge of docked
##   WHISTLE    = rising edge of gale about

const BEARING := 170.0
const TOP := 260.0                      # tether length at the top, m
const RISE_SPEED := 10.0                # m/s paying out
const REEL_SPEED := 8.0                 # m/s reeling in
const HARVEST_RATE := 0.035             # basket loads a second at full
const CISTERN := 6.0                    # basket loads
const CRADLE := Vector2(0.0, 4.0)
const WINCH := Vector2(0.0, 8.5)
const TROUGH := Vector2(3.0, 4.0)
const TANK := Vector2(5.6, 6.0)
const MAST := Vector2(-4.5, 7.5)
const ENVELOPE_R := 7.0                 # a giant: 14 m across, to be seen at the top of the tether
const HANG := 10.5                      # basket floor to envelope centre

var _tether := 0.0                      # paid out, m
var _water := 0.0                       # in the basket, loads
var _ice := 0.0
var _cistern := 1.0
var _wind := 0.0                        # 0 calm to 1 gale, at the ground
var _wind_noise := FastNoiseLite.new()
var _gust_noise := FastNoiseLite.new()
var _clock := 0.0
var _drum_angle := 0.0
var _engine_angle := 0.0
var _cups := 0.0
var _thaw := 0.0
var _drain := 0.0
var _drift := Vector3.ZERO
var _was := {}

var _l := {}
var _r := {}
var _lever: WorksHandle

var _balloon: Node3D
var _envelope_frost: StandardMaterial3D
var _icicles: Array[MeshInstance3D] = []
var _jar_water: MeshInstance3D
var _cloud_water: StandardMaterial3D
var _net_sparkle: GPUParticles3D
var _lanterns: Array[HangingLantern] = []
var _rope: MeshInstance3D
var _rope_from := Vector3.ZERO
var _drum: Node3D
var _flywheel: Node3D
var _puff: GPUParticles3D
var _cup_head: Node3D
var _vane: Node3D
var _alt_needle: Node3D
var _cold_needle: Node3D
var _brazier: GPUParticles3D
var _brazier_light: OmniLight3D
var _trough_water: MeshInstance3D
var _tank_water: MeshInstance3D
var _tank_light: OmniLight3D
var _pour: MeshInstance3D
var _digits: Array[Label3D] = []
var _gathered := 0.0

var _snd_chuff: AudioStreamPlayer3D
var _snd_ratchet: AudioStreamPlayer3D
var _snd_bell: AudioStreamPlayer3D
var _snd_whistle: AudioStreamPlayer3D
var _snd_pour: AudioStreamPlayer3D
var _snd_fire: AudioStreamPlayer3D
var _snd_wind: AudioStreamPlayer3D

var _plank: StandardMaterial3D
var _iron: StandardMaterial3D
var _copper: StandardMaterial3D
var _stone: StandardMaterial3D
var _canvas_a: StandardMaterial3D
var _canvas_b: StandardMaterial3D
var _glass: StandardMaterial3D
var _rope_mat: StandardMaterial3D


func _init(owner_island: CozyIsland) -> void:
	super(owner_island, BEARING)
	name = "BalloonWorks"
	_wind_noise.seed = 91
	_wind_noise.frequency = 1.0
	_gust_noise.seed = 92
	_gust_noise.frequency = 1.0


static func centre(owner_island: CozyIsland) -> Vector3:
	return BeachSite.site_point(owner_island, BEARING, 0.5, 6.5)


func _ready() -> void:
	add_child(_site)
	_materials()
	_build_cradle()
	_build_winch()
	_build_balloon()
	_build_trough_and_tank()
	_build_mast()
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
	_canvas_a = island.surface("", 1.0, Color(0.75, 0.2, 0.15), 0.85, Color(0.95, 0.45, 0.35))
	_canvas_b = island.surface("", 1.0, Color(0.85, 0.8, 0.68), 0.85, Color(0.98, 0.94, 0.82))
	_rope_mat = island.surface("", 1.0, Color(0.45, 0.38, 0.28), 0.9, Color(0.66, 0.54, 0.4), {"no_line": true})
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(0.82, 0.92, 1.0, 0.18)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.roughness = 0.04
	_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cloud_water = StandardMaterial3D.new()
	_cloud_water.albedo_color = Color(0.62, 0.82, 1.0, 0.8)
	_cloud_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cloud_water.roughness = 0.08
	_cloud_water.emission_enabled = true
	_cloud_water.emission = Color(0.45, 0.75, 1.0)
	_envelope_frost = StandardMaterial3D.new()
	_envelope_frost.albedo_color = Color(0.95, 0.98, 1.0, 0.0)
	_envelope_frost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_envelope_frost.roughness = 0.6


## ---- the cradle and the winch ---------------------------------------------

func _build_cradle() -> void:
	var g := ground(CRADLE.x, CRADLE.y)
	var deck := g + 1.0
	for k in 8:
		var a := TAU * k / 8.0
		_rod(at(CRADLE.x + cos(a) * 2.0, CRADLE.y + sin(a) * 2.0, g - 0.2),
				at(CRADLE.x + cos(a) * 2.0, CRADLE.y + sin(a) * 2.0, deck), 0.07, _wood)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.25
	ring.outer_radius = 2.15
	ring.rings = 32
	ring.material = _plank
	var ring_view := _put(ring, at(CRADLE.x, CRADLE.y, deck), false, Vector3.ZERO, null)
	ring_view.scale = Vector3(1, 0.12, 1)
	var body := StaticBody3D.new()
	body.position = at(CRADLE.x, CRADLE.y, deck)
	var shape := CylinderShape3D.new()
	shape.radius = 2.15
	shape.height = 0.2
	var c := CollisionShape3D.new()
	c.shape = shape
	body.add_child(c)
	_site.add_child(body)
	# The snatch block the tether runs through, and the rope back to the
	# winch.
	_cyl(0.2, 0.2, 0.12, at(CRADLE.x, CRADLE.y, g + 0.4), _iron, 12).rotation.z = PI * 0.5
	_rope_from = at(CRADLE.x, CRADLE.y, g + 0.5)
	_rod(_rope_from, at(WINCH.x, WINCH.y - 0.5, ground(WINCH.x, WINCH.y) + 1.25), 0.025, _rope_mat, 6)
	_site.add_child(HoverNote.new(at(CRADLE.x, CRADLE.y, deck + 0.2), Vector3(4.4, 0.6, 4.4),
			"Landing cradle\nThe basket settles here to be emptied; the tether runs through the block beneath.", 1.2))


func _build_winch() -> void:
	var g := ground(WINCH.x, WINCH.y)
	# The shed: a roof on four posts.
	for du: float in [-1.8, 1.8]:
		for dv: float in [-1.2, 1.2]:
			_rod(at(WINCH.x + du, WINCH.y + dv, g - 0.2), at(WINCH.x + du, WINCH.y + dv, g + 2.6), 0.07, _wood)
	var roof := _box(Vector3(4.2, 0.1, 3.0), at(WINCH.x, WINCH.y, g + 2.65), _plank)
	roof.rotation.x = -0.12
	# The rope drum.
	for du: float in [-0.9, 0.9]:
		_box(Vector3(0.12, 1.3, 0.8), at(WINCH.x + du, WINCH.y, g + 0.45), _wood, true)
	_drum = Node3D.new()
	_drum.set_meta(StaticMerge.MOVES, true)
	_drum.position = at(WINCH.x, WINCH.y, g + 1.0)
	_site.add_child(_drum)
	_cyl(0.42, 0.42, 1.6, Vector3.ZERO, _wood, 16, false, _drum).rotation.z = PI * 0.5
	for du: float in [-0.75, 0.75]:
		_cyl(0.6, 0.6, 0.06, Vector3(du, 0, 0), _iron, 20, false, _drum).rotation.z = PI * 0.5
	var coil := _cyl(0.46, 0.46, 1.3, Vector3.ZERO, _rope_mat, 16, false, _drum)
	coil.rotation.z = PI * 0.5
	for k in 8:
		_box(Vector3(1.5, 0.04, 0.04), Vector3(0, cos(TAU * k / 8.0) * 0.47, sin(TAU * k / 8.0) * 0.47), _iron, false, _drum)
	# The little engine beside it: boiler, chimney, flywheel.
	var boiler := _cyl(0.38, 0.38, 1.2, at(WINCH.x - 2.6, WINCH.y, g + 0.75), _copper, 16)
	boiler.rotation.z = PI * 0.5
	_box(Vector3(1.3, 0.4, 0.8), at(WINCH.x - 2.6, WINCH.y, g + 0.15), _stone, true)
	_rod(at(WINCH.x - 3.1, WINCH.y, g + 1.0), at(WINCH.x - 3.1, WINCH.y, g + 2.9), 0.07, _iron, 10)
	_flywheel = Node3D.new()
	_flywheel.set_meta(StaticMerge.MOVES, true)
	_flywheel.position = at(WINCH.x - 1.5, WINCH.y, g + 0.85)
	_site.add_child(_flywheel)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.45
	rim.outer_radius = 0.52
	rim.material = _iron
	_put(rim, Vector3.ZERO, false, Vector3.ZERO, _flywheel).rotation.z = PI * 0.5
	for k in 5:
		_box(Vector3(0.03, 0.92, 0.04), Vector3.ZERO, _iron, false, _flywheel).rotation.x = PI * k / 5.0
	_puff = _steam_puff()
	_puff.position = at(WINCH.x - 3.1, WINCH.y, g + 2.95)
	_site.add_child(_puff)
	# The dials: the balloon's height and the cold up there.
	_alt_needle = _dial(at(WINCH.x + 0.6, WINCH.y + 1.25, g + 1.7))
	_cold_needle = _dial(at(WINCH.x - 0.6, WINCH.y + 1.25, g + 1.7))
	_site.add_child(HoverNote.new(at(WINCH.x - 0.6, WINCH.y, g + 1.0), Vector3(5.0, 2.0, 2.2),
			"Steam winch\nPays the tether out as the balloon rises and reels it back in. Left dial: how cold it is up at the balloon; right dial: its height."))


func _dial(pos: Vector3) -> Node3D:
	var face := _cyl(0.2, 0.2, 0.03, pos, _brass, 20)
	face.rotation.x = PI * 0.5
	var enamel := StandardMaterial3D.new()
	enamel.albedo_color = Color(0.93, 0.9, 0.82)
	_cyl(0.17, 0.17, 0.006, pos + Vector3(0, 0, 0.018), enamel, 20).rotation.x = PI * 0.5
	var needle := Node3D.new()
	needle.set_meta(StaticMerge.MOVES, true)
	needle.position = pos + Vector3(0, 0, 0.026)
	_site.add_child(needle)
	_box(Vector3(0.012, 0.15, 0.006), Vector3(0, 0.06, 0), _iron, false, needle)
	return needle


func _steam_puff() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 15.0
	process.initial_velocity_min = 0.8
	process.initial_velocity_max = 1.4
	process.gravity = Vector3(0.3, 0.5, 0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	process.color_ramp = ramp_tex
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 2.0))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	process.scale_curve = curve_tex
	var p := GPUParticles3D.new()
	p.amount = 10
	p.lifetime = 2.0
	p.one_shot = true
	p.explosiveness = 0.8
	p.emitting = false
	p.process_material = process
	p.draw_pass_1 = _soft_quad(0.5, false)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _soft_quad(size: float, additive: bool) -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if additive else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_dot()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	return quad


func _soft_dot() -> GradientTexture2D:
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
	return dot


## ---- the balloon -----------------------------------------------------------

func _build_balloon() -> void:
	_balloon = Node3D.new()
	_balloon.set_meta(StaticMerge.MOVES, true)
	_site.add_child(_balloon)
	# The envelope in eight gores of two colours, with a frost skin over it.
	var gore_mesh := SphereMesh.new()
	gore_mesh.radius = ENVELOPE_R
	gore_mesh.height = ENVELOPE_R * 2.3
	gore_mesh.radial_segments = 48
	gore_mesh.rings = 24
	var env := _put(gore_mesh, Vector3(0, HANG, 0), false, Vector3.ZERO, _balloon)
	env.material_override = _canvas_b
	# Coloured bands over the seams: rings standing upright round the
	# envelope, each over two opposite seams, stretched to its shape.
	for k in 4:
		var band := TorusMesh.new()
		band.inner_radius = 0.97
		band.outer_radius = 1.03
		band.rings = 48
		band.ring_segments = 6
		band.material = _canvas_a
		var holder := Node3D.new()
		holder.position = Vector3(0, HANG, 0)
		holder.rotation.y = PI * k / 4.0
		_balloon.add_child(holder)
		var view := _put(band, Vector3.ZERO, false, Vector3.ZERO, holder)
		view.basis = Basis.from_scale(Vector3(ENVELOPE_R * 1.005, ENVELOPE_R * 1.155, ENVELOPE_R * 1.005)) * Basis(Vector3.RIGHT, PI * 0.5)
	var crown := SphereMesh.new()
	crown.radius = ENVELOPE_R * 0.3
	crown.height = ENVELOPE_R * 0.2
	crown.is_hemisphere = true
	crown.material = _canvas_a
	_put(crown, Vector3(0, HANG + ENVELOPE_R * 1.15 - ENVELOPE_R * 0.09, 0), false, Vector3.ZERO, _balloon)
	var frost := SphereMesh.new()
	frost.radius = ENVELOPE_R * 1.02
	frost.height = ENVELOPE_R * 2.3 * 1.02
	frost.material = _envelope_frost
	_put(frost, Vector3(0, HANG, 0), false, Vector3.ZERO, _balloon)
	# Rigging down to the basket's ring.
	for k in 8:
		var a := TAU * k / 8.0
		_rod(Vector3(cos(a) * ENVELOPE_R * 0.75, HANG - ENVELOPE_R * 0.9, sin(a) * ENVELOPE_R * 0.75),
				Vector3(cos(a) * 0.7, 1.4, sin(a) * 0.7), 0.012, _rope_mat, 4, _balloon)
	# The basket, a fog net of strings under a frame, the glass jar.
	_cyl(0.75, 0.65, 0.9, Vector3(0, 0.45, 0), _plank, 16, false, _balloon)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.66
	ring.outer_radius = 0.74
	ring.material = _brass
	_put(ring, Vector3(0, 1.4, 0), false, Vector3.ZERO, _balloon)
	for k in 14:
		var a := TAU * k / 14.0
		_rod(Vector3(cos(a) * 0.68, 1.4, sin(a) * 0.68), Vector3(cos(a) * 0.68, 0.95, sin(a) * 0.68), 0.004, _glass, 3, _balloon)
	_cyl(0.18, 0.18, 0.5, Vector3(0, 1.15, 0), _glass, 12, false, _balloon)
	_jar_water = _cyl(0.16, 0.16, 1.0, Vector3.ZERO, _cloud_water, 12, false, _balloon)
	for k in 10:
		var a := TAU * k / 10.0
		var ice := CylinderMesh.new()
		ice.top_radius = 0.035
		ice.bottom_radius = 0.0
		ice.height = 0.4
		ice.material = _envelope_frost
		var icicle := _put(ice, Vector3(cos(a) * 0.7, -0.1, sin(a) * 0.7), false, Vector3.ZERO, _balloon)
		_icicles.append(icicle)
	# Glints of water caught on the net.
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_radius = 0.7
	process.emission_ring_inner_radius = 0.6
	process.emission_ring_height = 0.4
	process.emission_ring_axis = Vector3.UP
	process.gravity = Vector3(0, -0.4, 0)
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1.5, 2.0, 2.5, 1), Color(1.0, 1.5, 2.5, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	ramp_tex.use_hdr = true
	process.color_ramp = ramp_tex
	_net_sparkle = GPUParticles3D.new()
	_net_sparkle.amount = 24
	_net_sparkle.lifetime = 1.2
	_net_sparkle.process_material = process
	_net_sparkle.draw_pass_1 = _soft_quad(0.06, true)
	_net_sparkle.position = Vector3(0, 1.15, 0)
	_net_sparkle.emitting = false
	_net_sparkle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_balloon.add_child(_net_sparkle)
	# Two lanterns on the basket, lit at night so it can be found in the sky.
	for k in 2:
		var lantern := HangingLantern.new(_iron, _rope_mat, k * 1.3)
		lantern.position = Vector3(0.75 if k == 0 else -0.75, 1.4, 0)
		_balloon.add_child(lantern)
		_lanterns.append(lantern)
	_rope = _rod(Vector3.ZERO, Vector3.UP, 0.02, _rope_mat, 6)
	_rope.set_meta(StaticMerge.MOVES, true)
	_balloon.add_child(HoverNote.new(Vector3(0, 0.7, 0), Vector3(1.6, 1.6, 1.6),
			"Balloon\nIts net gathers water from the air, as frost and icicles above the freezing height.", 2.0))


## ---- the thawing trough and the cistern ------------------------------------

func _build_trough_and_tank() -> void:
	var g := ground(TROUGH.x, TROUGH.y)
	_box(Vector3(1.2, 0.5, 0.9), at(TROUGH.x, TROUGH.y, g + 0.15), _stone, true)
	var trough_y := g + 0.75
	_box(Vector3(1.3, 0.05, 0.6), at(TROUGH.x, TROUGH.y, trough_y - 0.15), _copper)
	for dv: float in [-0.3, 0.3]:
		_box(Vector3(1.3, 0.3, 0.04), at(TROUGH.x, TROUGH.y + dv, trough_y), _copper)
	for du: float in [-0.65, 0.65]:
		_box(Vector3(0.04, 0.3, 0.6), at(TROUGH.x + du, TROUGH.y, trough_y), _copper)
	_trough_water = _box(Vector3(1.22, 1.0, 0.52), Vector3.ZERO, _cloud_water)
	# The spout from the cradle to the trough.
	var gc := ground(CRADLE.x, CRADLE.y)
	_rod(at(CRADLE.x + 1.3, CRADLE.y, gc + 1.1), at(TROUGH.x - 0.6, TROUGH.y, trough_y + 0.2), 0.04, _copper, 8)
	# The brazier under it.
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.4, 0.02, 0.25)
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
	_brazier = GPUParticles3D.new()
	_brazier.amount = 40
	_brazier.lifetime = 0.5
	_brazier.process_material = process
	_brazier.draw_pass_1 = _soft_quad(0.22, true)
	_brazier.position = at(TROUGH.x, TROUGH.y + 0.46, g + 0.2)
	_brazier.emitting = false
	_brazier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_site.add_child(_brazier)
	_brazier_light = OmniLight3D.new()
	_brazier_light.light_color = Color(1.0, 0.55, 0.25)
	_brazier_light.omni_range = 4.0
	_brazier_light.position = at(TROUGH.x, TROUGH.y + 0.6, g + 0.4)
	_brazier_light.visible = false
	_site.add_child(_brazier_light)
	# The pipe on to the cistern, and the cistern.
	var gt := ground(TANK.x, TANK.y)
	_rod(at(TROUGH.x + 0.65, TROUGH.y, trough_y - 0.1), at(TANK.x, TANK.y, gt + 2.3), 0.04, _copper, 8)
	_cyl(0.85, 0.9, 0.5, at(TANK.x, TANK.y, gt + 0.1), _stone, 14, true)
	_cyl(0.75, 0.75, 1.8, at(TANK.x, TANK.y, gt + 1.25), _glass, 20)
	_cyl(0.78, 0.78, 0.06, at(TANK.x, TANK.y, gt + 2.17), _brass, 20)
	_cyl(0.78, 0.78, 0.06, at(TANK.x, TANK.y, gt + 0.37), _brass, 20)
	_tank_water = _cyl(0.72, 0.72, 1.0, Vector3.ZERO, _cloud_water, 20)
	_tank_light = OmniLight3D.new()
	_tank_light.light_color = Color(0.5, 0.75, 1.0)
	_tank_light.omni_range = 4.0
	_tank_light.position = at(TANK.x, TANK.y, gt + 1.2)
	_site.add_child(_tank_light)
	_pour = _cyl(0.03, 0.03, 1.0, Vector3.ZERO, _cloud_water, 8)
	# The garden pipe that draws the cistern down slowly.
	_rod(at(TANK.x + 0.75, TANK.y, gt + 0.5), at(TANK.x + 3.0, TANK.y + 2.0, ground(TANK.x + 3.0, TANK.y + 2.0) - 0.1), 0.035, _copper, 8)
	# The tally: barrels of cloud water gathered.
	var case_at := at(TANK.x, TANK.y + 0.92, gt + 0.55)
	_box(Vector3(0.42, 0.18, 0.06), case_at, _brass)
	for k in 3:
		var digit := Label3D.new()
		digit.text = "0"
		digit.font_size = 64
		digit.pixel_size = 0.0018
		digit.modulate = Color(0.1, 0.08, 0.06)
		digit.outline_size = 0
		digit.position = case_at + Vector3(-0.12 + 0.12 * k, 0, 0.035)
		_site.add_child(digit)
		_digits.append(digit)
	_site.add_child(HoverNote.new(at(TROUGH.x, TROUGH.y, g + 0.6), Vector3(1.4, 1.2, 1.0),
			"Thawing trough\nA brazier melts the balloon's ice; the water runs on to the cistern."))
	_site.add_child(HoverNote.new(at(TANK.x, TANK.y, gt + 1.2), Vector3(1.7, 2.4, 1.7),
			"Cistern of cloud water\nIt glows faintly at night. The counter tallies basketfuls gathered."))


## ---- the weather mast ------------------------------------------------------

func _build_mast() -> void:
	var g := ground(MAST.x, MAST.y)
	_rod(at(MAST.x, MAST.y, g - 0.2), at(MAST.x, MAST.y, g + 6.0), 0.06, _wood)
	_cup_head = Node3D.new()
	_cup_head.set_meta(StaticMerge.MOVES, true)
	_cup_head.position = at(MAST.x, MAST.y, g + 6.1)
	_site.add_child(_cup_head)
	for k in 4:
		var arm := Node3D.new()
		arm.rotation.y = TAU * k / 4.0
		_cup_head.add_child(arm)
		_box(Vector3(0.5, 0.02, 0.02), Vector3(0.25, 0, 0), _brass, false, arm)
		var cup := SphereMesh.new()
		cup.radius = 0.07
		cup.height = 0.14
		cup.is_hemisphere = true
		cup.material = _brass
		_put(cup, Vector3(0.5, 0, 0), false, Vector3.ZERO, arm).rotation.z = PI * 0.5
	_vane = Node3D.new()
	_vane.set_meta(StaticMerge.MOVES, true)
	_vane.position = at(MAST.x, MAST.y, g + 5.6)
	_site.add_child(_vane)
	_box(Vector3(0.9, 0.02, 0.02), Vector3.ZERO, _iron, false, _vane)
	_box(Vector3(0.02, 0.25, 0.3), Vector3(-0.45, 0, 0), _iron, false, _vane).rotation.y = PI * 0.5
	_site.add_child(HoverNote.new(at(MAST.x, MAST.y, g + 3.0), Vector3(0.6, 6.0, 0.6),
			"Weather mast\nThe cups spin with the wind; the vane points into it."))


## ---- the circuit -----------------------------------------------------------

func _mast_lanterns(u: float, v: float, titles: Array, keys: Array, y0: float, dy := 0.38) -> void:
	var column := _lantern_column(u, v, titles, y0, dy)
	for i in keys.size():
		_l[keys[i]] = column[i]


func _build_circuit() -> void:
	_mast_lanterns(CRADLE.x - 2.6, CRADLE.y + 1.6,
			["the basket is docked", "the basket is empty", "the basket is heavy", "there is ice in the basket"],
			["docked", "empty", "heavy", "ice"], 1.8)
	_mast_lanterns(WINCH.x + 2.3, WINCH.y - 0.8, ["the balloon is at the top"], ["top"], 2.4)
	_mast_lanterns(MAST.x + 0.5, MAST.y + 0.6, ["a gale is blowing"], ["gale"], 2.4)
	_mast_lanterns(TANK.x - 1.2, TANK.y + 1.2, ["the cistern has room"], ["room"], 2.2)
	var gy := func(u: float, v: float) -> float: return ground(u, v) + 2.8
	var ton_gale := _part(LumenPart.Kind.TON, "a steady gale", -4.0, 10.5, gy.call(-4.0, 10.5), 2.0)
	var tof_gale := _part(LumenPart.Kind.TOF, "a gale about", -2.5, 12.0, gy.call(-2.5, 12.0), 12.0)
	var not_gale := _part(LumenPart.Kind.NOT, "no gale about", -0.5, 12.5, gy.call(-0.5, 12.5))
	var and_set := _part(LumenPart.Kind.AND, "send the balloon up", 1.5, 11.5, gy.call(1.5, 11.5))
	var or_reset := _part(LumenPart.Kind.OR, "bring the balloon down", 0.0, 10.4, gy.call(0.0, 10.4))
	var latch := _part(LumenPart.Kind.LATCH, "harvesting", 2.5, 10.0, gy.call(2.5, 10.0))
	var not_top := _part(LumenPart.Kind.NOT, "not yet at the top", 4.0, 11.0, gy.call(4.0, 11.0))
	var not_harvest := _part(LumenPart.Kind.NOT, "not harvesting", 3.5, 8.8, gy.call(3.5, 8.8))
	var not_docked := _part(LumenPart.Kind.NOT, "not docked", -2.5, 6.0, gy.call(-2.5, 6.0))
	var not_empty := _part(LumenPart.Kind.NOT, "water in the basket", -1.5, 2.2, gy.call(-1.5, 2.2))
	var and_up := _part(LumenPart.Kind.AND, "let it rise", 4.5, 9.4, gy.call(4.5, 9.4))
	var and_down := _part(LumenPart.Kind.AND, "reel it in", 2.0, 7.3, gy.call(2.0, 7.3))
	var and_thaw := _part(LumenPart.Kind.AND, "thaw the ice", 1.6, 2.0, gy.call(1.6, 2.0))
	var and_drain := _part(LumenPart.Kind.AND, "drain the basket", 4.2, 2.6, gy.call(4.2, 2.6))
	var rise_dock := _part(LumenPart.Kind.RISE, "a landing", -3.6, 3.0, gy.call(-3.6, 3.0))
	var rise_gale := _part(LumenPart.Kind.RISE, "a gale begins", -5.8, 11.0, gy.call(-5.8, 11.0))
	var R := func(key: String, title: String, u: float, v: float, h: float) -> void:
		_r[key] = _part(LumenPart.Kind.RADIOMETER, title, u, v, ground(u, v) + h)
	R.call("up", "lifts the winch's brake", WINCH.x + 1.2, WINCH.y + 1.6, 2.0)
	R.call("down", "engages the winch's engine", WINCH.x - 1.2, WINCH.y + 1.6, 2.0)
	R.call("thaw", "lights the brazier", TROUGH.x - 0.4, TROUGH.y + 1.1, 1.5)
	R.call("drain", "opens the basket's tap", CRADLE.x + 2.4, CRADLE.y - 1.0, 1.8)
	R.call("bell", "rings the landing bell", -4.6, 2.2, 2.4)
	R.call("whistle", "blows the gale whistle", WINCH.x - 3.6, WINCH.y + 1.0, 2.4)

	_wire(_l["gale"], ton_gale)
	_wire(ton_gale, tof_gale)
	_wire(tof_gale, not_gale)
	_wire(_l["empty"], and_set)
	_wire(_l["room"], and_set)
	_wire(not_gale, and_set)
	_wire(_l["heavy"], or_reset)
	_wire(tof_gale, or_reset)
	_wire(and_set, latch)                 # set
	_wire(or_reset, latch)                # reset
	_wire(_l["top"], not_top)
	_wire(latch, and_up)
	_wire(not_top, and_up)
	_wire(and_up, _r["up"])
	_wire(latch, not_harvest)
	_wire(_l["docked"], not_docked)
	_wire(not_harvest, and_down)
	_wire(not_docked, and_down)
	_wire(and_down, _r["down"])
	_wire(_l["docked"], and_thaw)
	_wire(_l["ice"], and_thaw)
	_wire(and_thaw, _r["thaw"])
	_wire(_l["empty"], not_empty)
	_wire(_l["docked"], and_drain)
	_wire(not_empty, and_drain)
	_wire(_l["room"], and_drain)
	_wire(and_drain, _r["drain"])
	_wire(_l["docked"], rise_dock)
	_wire(rise_dock, _r["bell"])
	_wire(tof_gale, rise_gale)
	_wire(rise_gale, _r["whistle"])

	var lg := ground(WINCH.x + 2.6, WINCH.y + 1.6)
	_lever = WorksHandle.new(WorksHandle.Kind.LEVER, at(WINCH.x + 2.6, WINCH.y + 1.6, lg + 0.55), _wood, _iron,
			"Run lever\nE: let the balloon go up, or keep it home. It still comes down in a gale.")
	_site.add_child(_lever)
	_wire_run()


## The run lever as a lantern into the launch AND.
func _wire_run() -> void:
	_mast_lanterns(WINCH.x + 3.2, WINCH.y + 2.2, ["the run lever is on"], ["run"], 2.0)
	for p in parts:
		if p.title == "send the balloon up":
			_wire(_l["run"], p)


func _build_sounds() -> void:
	var gw := ground(WINCH.x, WINCH.y)
	_snd_chuff = _speaker("res://audio/chuff.wav", false, at(WINCH.x - 3.1, WINCH.y, gw + 2.9), 5.0)
	_snd_ratchet = _speaker("res://audio/ratchet.wav", false, at(WINCH.x, WINCH.y, gw + 1.0), 4.0)
	_snd_bell = _speaker("res://audio/bell_1.wav", false, at(-4.6, 2.2, ground(-4.6, 2.2) + 2.4), 8.0)
	_snd_whistle = _speaker("res://audio/whistle.wav", false, at(WINCH.x - 3.1, WINCH.y, gw + 2.5), 14.0)
	_snd_pour = _speaker("res://audio/river_loop.wav", true, at(TROUGH.x, TROUGH.y, ground(TROUGH.x, TROUGH.y) + 0.8), 3.0)
	_snd_fire = _speaker("res://audio/flare_loop.wav", true, at(TROUGH.x, TROUGH.y, ground(TROUGH.x, TROUGH.y) + 0.3), 2.0)
	_snd_wind = _speaker("res://audio/wind_loop.wav", true, at(MAST.x, MAST.y, ground(MAST.x, MAST.y) + 5.0), 10.0)


## ---- the simulation --------------------------------------------------------

func _on(key: String) -> bool:
	return (_r[key] as LumenPart).spin > 0.5


func _edge(key: String) -> bool:
	var now: bool = (_r[key] as LumenPart).powered
	var was: bool = _was.get(key, false)
	_was[key] = now
	return now and not was


## The air's temperature at a height on the tether: the ground's (warmer
## by day), less 6.5 degrees per scaled kilometre.
func _air_temp(height: float) -> float:
	var ground_t := lerpf(6.0, 14.0, island.sky.daylight)
	return ground_t - 0.065 * height


## How much water the air offers at a height: clear air holds little,
## a little more higher up; most at dawn, more by night than at noon.
func _humidity(height: float) -> float:
	var h := lerpf(0.05, 0.12, clampf(height / TOP, 0.0, 1.0))
	var sun := island.sky.sun_height
	var dawn := 1.0 - clampf(absf(sun - 2.0) / 10.0, 0.0, 1.0)
	var time := lerpf(1.2, 0.7, clampf(sun / 40.0, 0.0, 1.0)) + 0.6 * dawn
	return h * time


func _physics_process(dt: float) -> void:
	_clock += dt
	# Wind: slow weather with gusts on top; a gale now and then.
	var weather := 0.5 + 0.6 * _wind_noise.get_noise_1d(_clock * 0.012)
	var gust := 0.25 * _gust_noise.get_noise_1d(_clock * 0.4)
	_wind = clampf(weather + gust, 0.0, 1.0)
	# The winch.
	var before := _tether
	if _on("up"):
		_tether = minf(_tether + RISE_SPEED * dt, TOP)
	elif _on("down"):
		_tether = maxf(_tether - REEL_SPEED * dt, 0.0)
	var drum_before := _drum_angle
	_drum_angle += (_tether - before) / 0.46
	# Paying out, the pawl clicks over each of the ratchet's four teeth.
	if _tether > before and floori(_drum_angle / (PI * 0.5)) != floori(drum_before / (PI * 0.5)):
		_play(_snd_ratchet, randf_range(0.95, 1.05))
	var reeling := _on("down") and _tether > 0.0
	var e_before := _engine_angle
	_engine_angle += (6.0 if reeling else 0.0) * dt
	if floori(_engine_angle / PI) != floori(e_before / PI):
		_play(_snd_chuff, randf_range(0.92, 1.08))
		_puff.restart()
	# Harvest: water in the cloud, frost where it freezes.
	var height := _tether
	var carried := _water + _ice
	if height > 20.0 and carried < 1.0:
		var gather := HARVEST_RATE * _humidity(height) * dt
		if _air_temp(height) <= 0.0:
			_ice += gather
		else:
			_water += gather
	# At the cradle: the brazier thaws, the tap drains.
	var docked := _tether < 0.5
	_thaw = move_toward(_thaw, 1.0 if _on("thaw") and docked else 0.0, dt * 2.0)
	var melt := minf(_ice, 0.06 * _thaw * dt)
	_ice -= melt
	_water += melt
	_drain = move_toward(_drain, 1.0 if _on("drain") and docked else 0.0, dt * 3.0)
	var flow := minf(_water, 0.07 * _drain * dt)
	flow = minf(flow, CISTERN - _cistern)
	_water -= flow
	_cistern += flow
	var before_g := floori(_gathered)
	_gathered += flow
	if floori(_gathered) != before_g:
		var n := floori(_gathered) % 1000
		for k in 3:
			_digits[k].text = str(n / int(pow(10, 2 - k)) % 10)
	# The garden draws the cistern down slowly.
	_cistern = maxf(_cistern - 0.006 * dt, 0.0)
	if _edge("bell"):
		_play(_snd_bell, 1.25)
	if _edge("whistle"):
		_play(_snd_whistle, 0.85)
	# The lanterns' conditions.
	carried = _water + _ice
	_l["docked"].condition = docked
	_l["empty"].condition = carried < (0.05 if _l["empty"].condition else 0.03)
	_l["heavy"].condition = carried > 0.85
	_l["ice"].condition = _ice > 0.01
	_l["top"].condition = _tether >= TOP - 0.5
	_l["gale"].condition = _wind > (0.65 if _l["gale"].condition else 0.72)
	_l["room"].condition = _cistern < CISTERN * 0.85
	_l["run"].condition = _lever.on
	_step_circuit(dt)


func _process(delta: float) -> void:
	# The balloon drifts downwind with height; the tether follows it.
	var gc := ground(CRADLE.x, CRADLE.y)
	var aloft := clampf(_wind * (0.6 + _tether / TOP), 0.0, 1.5)
	var want := Vector3(-1.0, 0.0, 0.4).normalized() * aloft * _tether * 0.12
	_drift = _drift.lerp(want, 1.0 - exp(-0.5 * delta))
	var basket := at(CRADLE.x, CRADLE.y, gc + 1.05 + _tether) + _drift
	_balloon.position = basket
	_balloon.rotation.z = -_drift.x * 0.002 + sin(_clock * 0.7) * 0.02 * _wind
	_balloon.rotation.x = sin(_clock * 0.53) * 0.02 * _wind
	var low := _rope_from
	var span := basket - low
	_rope.visible = span.length() > 0.3
	if _rope.visible:
		_rope.position = (low + basket) * 0.5
		_rope.basis = _aligned(span) * Basis.from_scale(Vector3(1, span.length(), 1))
	# Frost, icicles, the jar, the glints.
	var frost := clampf(_ice / 0.6, 0.0, 1.0)
	_envelope_frost.albedo_color.a = frost * 0.75
	for i in _icicles.size():
		_icicles[i].scale = Vector3.ONE * maxf(frost * (0.6 + 0.4 * sin(i * 2.3)), 0.001)
	var jar := clampf(_water, 0.0, 1.0)
	_jar_water.visible = jar > 0.01
	_jar_water.position = Vector3(0, 0.92 + jar * 0.22, 0)
	_jar_water.scale = Vector3(1, maxf(jar * 0.44, 0.005), 1)
	_net_sparkle.emitting = _tether > 20.0 and _humidity(_tether) > 0.5 and _water + _ice < 1.0
	var night := 1.0 - island.sky.daylight
	for lantern in _lanterns:
		lantern.set_lit(night)
	_cloud_water.emission_energy_multiplier = 0.2 + 1.6 * night
	# Winch, engine, weather mast, dials.
	_drum.rotation.x = -_drum_angle
	_flywheel.rotation.x = _engine_angle
	_cups += (0.5 + 9.0 * _wind) * delta
	_cup_head.rotation.y = _cups
	_vane.rotation.y = lerp_angle(_vane.rotation.y, atan2(0.4, -1.0) + 0.2 * sin(_clock * 0.3), 1.0 - exp(-delta))
	_alt_needle.rotation.z = -clampf(_tether / TOP, 0.0, 1.0) * 4.2 + 2.1
	_cold_needle.rotation.z = -clampf((_air_temp(_tether) + 20.0) / 40.0, 0.0, 1.0) * 4.2 + 2.1
	# Trough, brazier, cistern.
	_brazier.emitting = _thaw > 0.1
	_brazier_light.visible = _thaw > 0.05
	_brazier_light.light_energy = _thaw * (1.2 + 0.2 * sin(_clock * 13.0))
	var gt := ground(TROUGH.x, TROUGH.y)
	var trough_level := clampf(_drain * 0.6 + _thaw * 0.3, 0.0, 1.0)
	_trough_water.visible = trough_level > 0.05
	_trough_water.position = at(TROUGH.x, TROUGH.y, gt + 0.62 + trough_level * 0.08)
	_trough_water.scale = Vector3(1, maxf(trough_level * 0.16, 0.01), 1)
	var gk := ground(TANK.x, TANK.y)
	var level := _cistern / CISTERN
	var th := maxf(1.72 * level, 0.01)
	_tank_water.visible = level > 0.005
	_tank_water.position = at(TANK.x, TANK.y, gk + 0.4 + th * 0.5)
	_tank_water.scale = Vector3(1, th, 1)
	_tank_light.visible = night > 0.2 and level > 0.05
	_tank_light.light_energy = night * level * 1.5
	_pour.visible = _drain > 0.1 and _water > 0.001
	if _pour.visible:
		var top := gk + 2.3
		var surface := gk + 0.4 + th
		_pour.position = at(TANK.x, TANK.y, (top + surface) * 0.5)
		_pour.scale = Vector3(1, maxf(top - surface, 0.05), 1)
	_level(_snd_pour, _drain if _water > 0.001 else 0.0, -6.0)
	_level(_snd_fire, _thaw * 0.5, -8.0)
	_level(_snd_wind, 0.2 + 0.8 * _wind, -6.0)
