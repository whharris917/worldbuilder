class_name SkyWorks
extends BeachSite
## The sky works on the cozy island's hilltop: lightning rods that catch
## strikes from passing storms into Leyden jars, and silvered dishes that
## gather moonlight into vials on clear nights; run by light-beam logic.
## The first works built cozy-native: its still parts are one mesh
## painted in flat vertex colours with one shared material (CozyMesh),
## its moving parts a few more; it keeps its flat colours in the
## photographic look and follows the light, outline and shade switches.
##
## Storms. Now and then a storm drifts across the island: a dark heap of
## cloud 130 m up with rain falling under it. While it is within 700 m it
## strikes, more often the nearer; a strike is a jagged bolt with a flash,
## and its thunder sets out at the speed of sound (343 m/s), so it is
## heard three seconds a kilometre after it is seen. A strike within reach
## of a raised rod takes the rod: the rod is the tallest thing about, as a
## real lightning rod is, and the charge runs down its cable into the jars.
##
## Moonlight. Each dish, unparked, turns to face the moon; what it gathers
## is the moon's lit share times how high it stands, in a dark clear sky,
## times how squarely the dish faces it. The vials fill one after another.
##
## The circuit, in ladder terms:
##   RODS     = storm near AND NOT jars full AND run lever
##   storm about = TOF 20 s ( storm near )
##   DISHES   = moon up in a dark sky AND NOT storm about AND NOT vials full AND run lever
##   DISCHARGE = TON 5 s ( jars full )  -> a thunderstone
##   PACK     = TON 5 s ( vials full ) -> a crate of moon vials

const BEARING := 219.0                  # toward the hill from the island's middle
const CLOUD_Y := 130.0
const STORM_SPEED := 14.0
const STRIKE_REACH := 260.0             # a raised rod draws strikes from a storm this near
const SOUND := 343.0
const JARS := 4.0
const VIALS := 8.0

const WOOD := Color(0.74, 0.54, 0.38)
const DARK_WOOD := Color(0.5, 0.35, 0.26)
const STONE := Color(0.72, 0.7, 0.68)
const COPPER := Color(0.86, 0.5, 0.32)
const BRASS := Color(0.92, 0.74, 0.36)
const IRON := Color(0.34, 0.34, 0.4)
const PATINA := Color(0.38, 0.66, 0.64)
const SILVER := Color(0.88, 0.9, 0.95)

const RODS := [Vector2(-6.0, -3.0), Vector2(6.0, -3.0), Vector2(0.0, 6.5)]
const DISHES := [Vector2(-5.5, 4.0), Vector2(5.5, 4.0), Vector2(0.0, -7.5)]
const ROD_LOW := 7.3                    # the mast's top
const ROD_RISE := 4.5                   # how far the top section climbs

var _hu := 0.0                          # the summit in the frame
var _hv := 0.0
var _cozy: StandardMaterial3D
var _clock := 0.0
var _rng := RandomNumberGenerator.new()

# storms
var _storm: Node3D
var _storm_pos := Vector3.ZERO           # world
var _storm_dir := Vector3.ZERO
var _storm_live := false
var _storm_wait := 20.0
var _storm_mat: StandardMaterial3D
var _rain: GPUParticles3D
var _bolt: MeshInstance3D
var _bolt_mat: StandardMaterial3D
var _flash: OmniLight3D
var _bolt_left := 0.0
var _thunders: Array = []                # [when, path, pitch, position]

# the works' state
var _charge := 0.0
var _moon := 0.0                         # vials' worth gathered
var _stones := 0
var _crates := 0
var _rod_up := [0.0, 0.0, 0.0]
var _rod_glow := [0.0, 0.0, 0.0]
var _dish_yaw := [0.0, 0.0, 0.0]
var _dish_pitch := [-1.3, -1.3, -1.3]
var _dish_take := [0.0, 0.0, 0.0]
var _storm_near := 0.0                   # 0 far to 1 overhead
var _was := {}
var _discharge_flash := 0.0

# parts
var _l := {}
var _r := {}
var _lever: WorksHandle

# moving and glowing pieces
var _rod_tops: Array[Node3D] = []
var _rod_tip_mats: Array[StandardMaterial3D] = []
var _dish_yaws: Array[Node3D] = []
var _dish_tilts: Array[Node3D] = []
var _dish_beams: Array[MeshInstance3D] = []
var _beam_mat: StandardMaterial3D
var _focus_mats: Array[StandardMaterial3D] = []
var _jar_mats: Array[StandardMaterial3D] = []
var _vial_fills: Array[MeshInstance3D] = []
var _stone_mat: StandardMaterial3D
var _cable_mat: StandardMaterial3D
var _storm_glass: StandardMaterial3D
var _stone_digits: Array[Label3D] = []
var _crate_digits: Array[Label3D] = []
var _rack_at := Vector3.ZERO             # site frame

var _snd_rain: AudioStreamPlayer
var _snd_crackle: AudioStreamPlayer3D
var _snd_ratchet: AudioStreamPlayer3D
var _snd_chime: AudioStreamPlayer3D
var _snd_pack: AudioStreamPlayer3D
var _snd_thunder: Array[AudioStreamPlayer3D] = []


func _init(owner_island: CozyIsland) -> void:
	super(owner_island, BEARING)
	name = "SkyWorks"
	_rng.seed = 1888
	var p := Vector3(CozyIsland.HILL.x, 0.0, CozyIsland.HILL.y) - Vector3(_origin.x, 0.0, _origin.z)
	_hu = p.dot(_along)
	_hv = p.dot(_in)


## A point by the summit: (du, dv) from it, `up` above the ground there.
func hill(du: float, dv: float, up: float) -> Vector3:
	return at(_hu + du, _hv + dv, ground(_hu + du, _hv + dv) + up)


func _ready() -> void:
	add_child(_site)
	_materials()
	var still := CozyMesh.new()
	_build_hut(still)
	_build_rods(still)
	_build_dishes(still)
	_build_store(still)
	var view := MeshInstance3D.new()
	view.name = "Still"
	view.mesh = still.commit(_cozy)
	_site.add_child(view)
	_build_storm()
	_build_circuit()
	_place_beams()
	_build_sounds()


func _materials() -> void:
	# One material for every flat-painted part: white, taking the vertex
	# colours; registered with the island so the light and outline
	# switches reach it.
	_cozy = island.surface("", 1.0, Color.WHITE, 0.85, Color.WHITE, {"line_colour": Color(0.24, 0.17, 0.15)})
	_cozy.vertex_color_use_as_albedo = true
	_wood = island.surface("", 1.0, WOOD, 0.85, WOOD)
	_brass = island.surface("", 1.0, BRASS, 0.4, BRASS)
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.albedo_color = Color(0.7, 0.8, 1.0)
	_cable_mat = StandardMaterial3D.new()
	_cable_mat.albedo_color = IRON
	_cable_mat.emission_enabled = true
	_cable_mat.emission = Color(0.7, 0.5, 1.0)


func _glow(colour: Color, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = energy
	return m


func _glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.93, 1.0, 0.22)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	return m


## A separate mesh (its own material, or the cozy one) at `xf` in the site.
func _piece(mesh: Mesh, xf: Transform3D, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xf
	(parent if parent != null else _site).add_child(mi)
	return mi


func _solid_box(size: Vector3, centre: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = centre
	var shape := BoxShape3D.new()
	shape.size = size
	var c := CollisionShape3D.new()
	c.shape = shape
	body.add_child(c)
	_site.add_child(body)


## ---- the hut ---------------------------------------------------------------

func _build_hut(m: CozyMesh) -> void:
	var g := ground(_hu, _hv)
	var c := at(_hu, _hv, g)
	m.cyl(2.5, 2.6, 0.7, 12, CozyMesh.at(c + Vector3(0, 0.05, 0)), STONE)
	m.cyl(2.2, 2.2, 2.4, 12, CozyMesh.at(c + Vector3(0, 1.6, 0)), WOOD)
	for y: float in [0.9, 2.7]:
		m.torus(2.18, 2.3, 12, 4, CozyMesh.at(c + Vector3(0, y, 0)), DARK_WOOD)
	m.ball(2.4, 12, CozyMesh.at(c + Vector3(0, 2.8, 0)), PATINA, true, 2.4)
	m.cyl(0.05, 0.08, 1.2, 8, CozyMesh.at(c + Vector3(0, 5.5, 0)), BRASS)
	m.ball(0.14, 8, CozyMesh.at(c + Vector3(0, 6.15, 0)), BRASS)
	# The door, toward the island's middle (-v), and two round windows.
	m.box(Vector3(0.9, 1.8, 0.12), CozyMesh.at(c + Vector3(0, 1.3, -2.18)), DARK_WOOD)
	for du: float in [-1.4, 1.4]:
		m.cyl(0.32, 0.32, 0.1, 10, CozyMesh.at(c + Vector3(du, 1.8, -1.72), Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.FORWARD, 0.0)), BRASS)
	_solid_box(Vector3(4.4, 3.0, 4.4), c + Vector3(0, 1.5, 0))
	_site.add_child(HoverNote.new(c + Vector3(0, 1.5, 0), Vector3(4.6, 3.2, 4.6),
			"Sky hut\nWhere the jars of lightning and the vials of moonlight are kept.", 4.2))


## ---- the lightning rods ----------------------------------------------------

func _build_rods(m: CozyMesh) -> void:
	var jars_at := hill(0.0, -3.4, 0.0)
	for i in 3:
		var p: Vector2 = RODS[i]
		var foot := hill(p.x, p.y, 0.0)
		m.box(Vector3(1.0, 0.7, 1.0), CozyMesh.at(foot + Vector3(0, 0.15, 0)), STONE)
		m.cyl(0.11, 0.15, ROD_LOW, 8, CozyMesh.at(foot + Vector3(0, ROD_LOW * 0.5 + 0.5, 0)), COPPER)
		for y: float in [2.0, 4.5, ROD_LOW + 0.4]:
			m.torus(0.1, 0.18, 10, 4, CozyMesh.at(foot + Vector3(0, y, 0)), BRASS)
		# Guy ropes.
		for k in 3:
			var a := TAU * k / 3.0 + 0.4
			m.rod(foot + Vector3(cos(a) * 3.0, -0.1, sin(a) * 3.0), foot + Vector3(0, 5.0, 0), 0.02, 4, IRON)
		# The top section, which climbs when raised: a thinner rod, a glass
		# ball and a crown of points.
		var top := Node3D.new()
		top.position = foot + Vector3(0, ROD_LOW + 0.5, 0)
		top.set_meta(StaticMerge.MOVES, true)
		_site.add_child(top)
		var tm := CozyMesh.new()
		tm.cyl(0.07, 0.08, 5.0, 8, CozyMesh.at(Vector3(0, -2.0, 0)), COPPER)
		for k in 4:
			var a := TAU * k / 4.0
			tm.cyl(0.0, 0.03, 0.5, 4, CozyMesh.at(Vector3(cos(a) * 0.12, 0.85, sin(a) * 0.12), Basis(Vector3(-sin(a), 0, cos(a)), -0.35)), COPPER)
		_piece(tm.commit(_cozy), Transform3D.IDENTITY, top)
		var tip := _glow(Color(0.8, 0.7, 1.0), 0.0)
		var ball := SphereMesh.new()
		ball.radius = 0.22
		ball.height = 0.44
		ball.radial_segments = 12
		ball.rings = 6
		ball.material = tip
		_piece(ball, Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)), top)
		_rod_tops.append(top)
		_rod_tip_mats.append(tip)
		# Its cable down to the jars.
		var cable := CylinderMesh.new()
		var a2 := foot + Vector3(0, 0.6, 0)
		var b2 := jars_at + Vector3(0, 0.5, 0)
		cable.top_radius = 0.04
		cable.bottom_radius = 0.04
		cable.height = a2.distance_to(b2)
		cable.radial_segments = 6
		cable.material = _cable_mat
		_piece(cable, Transform3D(CozyMesh.aligned(b2 - a2), (a2 + b2) * 0.5))
		_site.add_child(HoverNote.new(foot + Vector3(0, 4.0, 0), Vector3(0.8, 8.0, 0.8),
				"Lightning rod\nRaised when a storm comes near; a strike within reach runs down its cable into the jars."))


## ---- the moon dishes -------------------------------------------------------

func _build_dishes(m: CozyMesh) -> void:
	_rack_at = hill(2.6, 0.0, 1.5) + Vector3(0.0, 0.0, 1.5)
	for i in 3:
		var p: Vector2 = DISHES[i]
		var foot := hill(p.x, p.y, 0.0)
		m.cyl(0.45, 0.6, 1.2, 10, CozyMesh.at(foot + Vector3(0, 0.5, 0)), STONE)
		var yaw := Node3D.new()
		yaw.position = foot + Vector3(0, 1.1, 0)
		yaw.set_meta(StaticMerge.MOVES, true)
		_site.add_child(yaw)
		var ym := CozyMesh.new()
		ym.cyl(0.35, 0.4, 0.2, 10, CozyMesh.at(Vector3.ZERO), BRASS)
		for side: float in [-1.0, 1.0]:
			ym.box(Vector3(0.1, 1.4, 0.18), CozyMesh.at(Vector3(side * 1.05, 0.75, 0)), BRASS)
		_piece(ym.commit(_cozy), Transform3D.IDENTITY, yaw)
		var tilt := Node3D.new()
		tilt.position = Vector3(0, 1.4, 0)
		yaw.add_child(tilt)
		# The bowl opens toward the tilt node's -z (its back bulging to +z);
		# its focus crystal on three struts in front of it.
		var tm := CozyMesh.new()
		tm.ball(1.3, 14, CozyMesh.at(Vector3.ZERO, Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1, 0.45, 1))), SILVER, true, 1.3)
		tm.torus(1.22, 1.34, 16, 4, CozyMesh.at(Vector3.ZERO, Basis(Vector3.RIGHT, PI * 0.5)), BRASS)
		for k in 3:
			var a := TAU * k / 3.0
			tm.rod(Vector3(cos(a) * 1.25, sin(a) * 1.25, 0.0), Vector3(0, 0, -1.55), 0.025, 4, BRASS)
		_piece(tm.commit(_cozy), Transform3D.IDENTITY, tilt)
		var focus := _glow(Color(0.75, 0.82, 1.0), 0.2)
		var crystal := CylinderMesh.new()
		crystal.top_radius = 0.0
		crystal.bottom_radius = 0.12
		crystal.height = 0.3
		crystal.radial_segments = 6
		crystal.material = focus
		_piece(crystal, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -1.6)), tilt)
		_dish_yaws.append(yaw)
		_dish_tilts.append(tilt)
		_focus_mats.append(focus)
		var beam := CylinderMesh.new()
		beam.top_radius = 0.03
		beam.bottom_radius = 0.03
		beam.height = 1.0
		beam.radial_segments = 6
		beam.material = _beam_mat
		var bi := _piece(beam, Transform3D.IDENTITY)
		bi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_dish_beams.append(bi)
		_site.add_child(HoverNote.new(foot + Vector3(0, 1.6, 0), Vector3(2.8, 3.0, 2.8),
				"Moon dish\nSilvered, it follows the moon on clear nights and sends what it gathers to the vials. It parks face down while a storm is about."))


## ---- the jars, vials, stones and crates ------------------------------------

func _build_store(m: CozyMesh) -> void:
	# The bench of Leyden jars on the hut's -v side.
	var bench := hill(0.0, -3.4, 0.0)
	m.box(Vector3(2.6, 0.55, 0.8), CozyMesh.at(bench + Vector3(0, 0.2, 0)), DARK_WOOD)
	var glass := _glass()
	for i in 4:
		var jp := bench + Vector3(-0.9 + i * 0.6, 0.48, 0)
		var shell := CylinderMesh.new()
		shell.top_radius = 0.22
		shell.bottom_radius = 0.22
		shell.height = 0.75
		shell.radial_segments = 12
		shell.material = glass
		_piece(shell, Transform3D(Basis.IDENTITY, jp + Vector3(0, 0.375, 0)))
		m.cyl(0.225, 0.225, 0.36, 12, CozyMesh.at(jp + Vector3(0, 0.18, 0)), BRASS, false)
		m.rod(jp + Vector3(0, 0.75, 0), jp + Vector3(0, 1.1, 0), 0.015, 6, BRASS)
		m.ball(0.05, 8, CozyMesh.at(jp + Vector3(0, 1.12, 0)), BRASS)
		var core := _glow(Color(0.7, 0.5, 1.0), 0.0)
		var inner := CylinderMesh.new()
		inner.top_radius = 0.15
		inner.bottom_radius = 0.15
		inner.height = 0.6
		inner.radial_segments = 10
		inner.material = core
		_piece(inner, Transform3D(Basis.IDENTITY, jp + Vector3(0, 0.36, 0)))
		_jar_mats.append(core)
	_solid_box(Vector3(2.6, 1.3, 0.8), bench + Vector3(0, 0.6, 0))
	_site.add_child(HoverNote.new(bench + Vector3(0, 0.8, 0), Vector3(2.7, 1.4, 0.9),
			"Leyden jars\nThey hold the lightning; full, they are emptied into a thunderstone."))
	# The thunderstone pedestal and its tally.
	var ped := hill(2.4, -3.8, 0.0)
	m.cyl(0.35, 0.45, 0.9, 8, CozyMesh.at(ped + Vector3(0, 0.45, 0)), STONE)
	_stone_mat = _glow(Color(0.65, 0.45, 1.0), 0.6)
	for up: float in [1.0, -1.0]:
		var half := CylinderMesh.new()
		half.radial_segments = 6
		half.top_radius = 0.0
		half.bottom_radius = 0.25
		half.height = 0.35
		half.material = _stone_mat
		var mi := _piece(half, Transform3D(Basis.IDENTITY if up > 0.0 else Basis(Vector3.RIGHT, PI), ped + Vector3(0, 1.25 + up * 0.175, 0)))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stone_digits = _tally(ped + Vector3(0, 0.55, -0.42))
	# The vial rack on the hut's +u side.
	var rack := hill(2.75, 0.0, 0.0)
	m.box(Vector3(0.5, 0.08, 2.2), CozyMesh.at(rack + Vector3(0, 1.0, 0)), DARK_WOOD)
	m.box(Vector3(0.5, 0.08, 2.2), CozyMesh.at(rack + Vector3(0, 0.3, 0)), DARK_WOOD)
	for dv: float in [-1.05, 1.05]:
		m.box(Vector3(0.08, 1.4, 0.08), CozyMesh.at(rack + Vector3(0, 0.7, dv)), DARK_WOOD)
	m.cyl(0.25, 0.06, 0.3, 10, CozyMesh.at(rack + Vector3(0, 1.6, 0)), BRASS)
	_rack_at = rack + Vector3(0, 1.75, 0)
	for i in 8:
		var vp := rack + Vector3(0, 1.04, -0.9 + i * 0.257)
		var vial := CylinderMesh.new()
		vial.top_radius = 0.05
		vial.bottom_radius = 0.06
		vial.height = 0.26
		vial.radial_segments = 8
		vial.material = glass
		_piece(vial, Transform3D(Basis.IDENTITY, vp + Vector3(0, 0.13, 0)))
		var fill := CylinderMesh.new()
		fill.top_radius = 0.045
		fill.bottom_radius = 0.055
		fill.height = 1.0
		fill.radial_segments = 8
		fill.material = _glow(Color(0.82, 0.88, 1.0), 1.4)
		var fi := _piece(fill, Transform3D(Basis.IDENTITY, vp))
		fi.visible = false
		fi.set_meta("base", vp)
		_vial_fills.append(fi)
	var crate := hill(3.3, 2.6, 0.0)
	m.box(Vector3(0.9, 0.6, 0.7), CozyMesh.at(crate + Vector3(0, 0.3, 0)), WOOD)
	m.box(Vector3(0.95, 0.06, 0.75), CozyMesh.at(crate + Vector3(0, 0.62, 0)), DARK_WOOD)
	_crate_digits = _tally(crate + Vector3(0, 0.35, -0.36))
	_site.add_child(HoverNote.new(rack + Vector3(0, 0.8, 0), Vector3(0.7, 1.6, 2.3),
			"Vials of moonlight\nFilled one after another; a full rack is packed into a crate."))
	# The storm glass: a tall glass whose crystals cloud as a storm comes on.
	var sg := hill(-2.8, -3.6, 0.0)
	m.cyl(0.12, 0.16, 1.2, 8, CozyMesh.at(sg + Vector3(0, 0.6, 0)), DARK_WOOD)
	_storm_glass = _glow(Color(0.85, 0.9, 1.0), 0.0)
	_storm_glass.albedo_color = Color(0.85, 0.9, 1.0, 0.25)
	_storm_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tube := CylinderMesh.new()
	tube.top_radius = 0.07
	tube.bottom_radius = 0.07
	tube.height = 0.5
	tube.radial_segments = 8
	tube.material = _storm_glass
	_piece(tube, Transform3D(Basis.IDENTITY, sg + Vector3(0, 1.45, 0)))
	m.cyl(0.09, 0.09, 0.05, 8, CozyMesh.at(sg + Vector3(0, 1.72, 0)), BRASS)
	_site.add_child(HoverNote.new(sg + Vector3(0, 1.0, 0), Vector3(0.5, 1.8, 0.5),
			"Storm glass\nIts crystals cloud over as a storm draws near."))


## Three numbered wheels on a brass plate at `pos`, facing -v.
func _tally(pos: Vector3) -> Array[Label3D]:
	var out: Array[Label3D] = []
	var plate := BoxMesh.new()
	plate.size = Vector3(0.42, 0.18, 0.04)
	plate.material = _brass
	_piece(plate, Transform3D(Basis.IDENTITY, pos))
	for k in 3:
		var d := Label3D.new()
		d.text = "0"
		d.font_size = 64
		d.pixel_size = 0.0018
		d.modulate = Color(0.1, 0.08, 0.06)
		d.outline_size = 0
		d.position = pos + Vector3(-0.12 + 0.12 * k, 0, -0.025)
		d.rotation.y = PI
		_site.add_child(d)
		out.append(d)
	return out


static func _show(digits: Array[Label3D], n: int) -> void:
	for k in 3:
		digits[k].text = str(n / int(pow(10, 2 - k)) % 10)


## ---- storms ----------------------------------------------------------------

func _build_storm() -> void:
	_storm = Node3D.new()
	_storm.top_level = true
	_storm.visible = false
	add_child(_storm)
	_storm_mat = StandardMaterial3D.new()
	_storm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_storm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_storm_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_storm_mat.billboard_keep_scale = true
	_storm_mat.albedo_texture = BeachSite.cloud_puff()
	_storm_mat.disable_fog = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.material = _storm_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = 140
	for i in 140:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * 85.0
		var middle := 1.0 - r / 85.0
		var p := Vector3(cos(a) * r, CLOUD_Y + middle * _rng.randf_range(5.0, 55.0), sin(a) * r)
		var s := _rng.randf_range(35.0, 60.0)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s * 0.7, s)), p))
	var heap := MultiMeshInstance3D.new()
	heap.multimesh = mm
	heap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	heap.custom_aabb = AABB(Vector3(-130, CLOUD_Y - 40, -130), Vector3(260, 130, 260))
	_storm.add_child(heap)
	# Rain: thin streaks falling from under the cloud.
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(65, 2, 65)
	process.direction = Vector3.DOWN
	process.spread = 3.0
	process.initial_velocity_min = 13.0
	process.initial_velocity_max = 15.0
	process.gravity = Vector3(1.5, -2.0, 0)
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(0.75, 0.8, 0.9, 0.35)
	rmat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	rmat.billboard_keep_scale = true
	var streak := QuadMesh.new()
	streak.size = Vector2(0.03, 0.9)
	streak.material = rmat
	_rain = GPUParticles3D.new()
	_rain.amount = 900
	_rain.lifetime = 5.0
	_rain.process_material = process
	_rain.draw_pass_1 = streak
	_rain.position = Vector3(0, 70, 0)
	_rain.visibility_aabb = AABB(Vector3(-80, -80, -80), Vector3(160, 90, 160))
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.emitting = false
	_storm.add_child(_rain)
	# The bolt and its flash.
	_bolt_mat = StandardMaterial3D.new()
	_bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bolt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bolt_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_bolt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bolt_mat.disable_fog = true
	_bolt = MeshInstance3D.new()
	_bolt.top_level = true
	_bolt.material_override = _bolt_mat
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.visible = false
	add_child(_bolt)
	_flash = OmniLight3D.new()
	_flash.top_level = true
	_flash.light_color = Color(0.82, 0.85, 1.0)
	_flash.omni_range = 160.0
	_flash.omni_attenuation = 1.0
	_flash.visible = false
	add_child(_flash)


func _start_storm() -> void:
	var a := _rng.randf() * TAU
	var start := Vector3(cos(a), 0, sin(a)) * 950.0
	var aim := Vector3(_rng.randf_range(-120, 120), 0, _rng.randf_range(-120, 120))
	_storm_pos = start
	_storm_dir = (aim - start).normalized()
	_storm_live = true
	_storm.visible = true
	_rain.emitting = true


func _strike(target: Vector3, rod: int) -> void:
	# From somewhere under the cloud to where it strikes.
	var a := _rng.randf() * TAU
	var r := _rng.randf() * 40.0
	var from := Vector3(_storm_pos.x + cos(a) * r, CLOUD_Y, _storm_pos.z + sin(a) * r)
	_bolt.mesh = _bolt_mesh(from, target)
	_bolt.global_transform = Transform3D.IDENTITY
	_bolt.visible = true
	_bolt_left = 0.5
	_flash.global_position = target + Vector3(0, 25, 0)
	if rod >= 0:
		_rod_glow[rod] = 1.0
		_charge = minf(_charge + 0.35, JARS)
	# The thunder, heard when the sound has crossed the distance.
	var cam := get_viewport().get_camera_3d()
	var dist := cam.global_position.distance_to(target) if cam != null else 500.0
	var file := "res://audio/thunder_near.wav" if dist < 450.0 else "res://audio/thunder_%d.wav" % (1 + _rng.randi() % 3)
	_thunders.append([_clock + dist / SOUND, file, _rng.randf_range(0.9, 1.1), target])
	if rod >= 0:
		_snd_crackle.position = _site.to_local(target)
		_thunders.append([_clock + dist / SOUND, "crackle", 1.0, target])


## A jagged bolt from `top` to `bottom`, as ribbons facing the viewer.
func _bolt_mesh(top: Vector3, bottom: Vector3) -> ArrayMesh:
	var pts: Array[Vector3] = [top, bottom]
	for depth in 5:
		var next: Array[Vector3] = [pts[0]]
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var spread := a.distance_to(b) * 0.25
			next.append((a + b) * 0.5 + Vector3(_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread) * 0.3, _rng.randf_range(-spread, spread)))
			next.append(b)
		pts = next
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam != null else bottom + Vector3(50, 0, 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var side := (b - a).cross(eye - a).normalized() * 1.1
		st.add_vertex(a - side)
		st.add_vertex(a + side)
		st.add_vertex(b + side)
		st.add_vertex(a - side)
		st.add_vertex(b + side)
		st.add_vertex(b - side)
	return st.commit()


## ---- the circuit -----------------------------------------------------------

func _build_circuit() -> void:
	var col := _lantern_column(_hu - 3.6, _hv - 4.6, ["a storm is near"], 1.6)
	_l["storm"] = col[0]
	col = _lantern_column(_hu + 1.0, _hv - 4.6, ["the jars are full"], 1.6)
	_l["jars"] = col[0]
	col = _lantern_column(_hu + 3.8, _hv + 5.6, ["the moon is up in a dark sky"], 1.8)
	_l["moon"] = col[0]
	col = _lantern_column(_hu + 3.8, _hv - 1.4, ["the vials are full"], 1.8)
	_l["vials"] = col[0]
	col = _lantern_column(_hu - 3.8, _hv + 2.0, ["the run lever is on"], 1.6)
	_l["run"] = col[0]
	var gy := func(du: float, dv: float) -> float: return ground(_hu + du, _hv + dv) + 2.8
	var not_jars := _part(LumenPart.Kind.NOT, "the jars have room", _hu - 1.6, _hv - 7.0, gy.call(-1.6, -7.0))
	var and_rods := _part(LumenPart.Kind.AND, "raise the rods", _hu - 4.5, _hv - 7.5, gy.call(-4.5, -7.5))
	var tof_storm := _part(LumenPart.Kind.TOF, "a storm about", _hu - 7.5, _hv + 1.0, gy.call(-7.5, 1.0), 20.0)
	var not_storm := _part(LumenPart.Kind.NOT, "no storm about", _hu - 7.0, _hv + 4.5, gy.call(-7.0, 4.5))
	var not_vials := _part(LumenPart.Kind.NOT, "the rack has room", _hu + 6.5, _hv + 0.5, gy.call(6.5, 0.5))
	var and_dishes := _part(LumenPart.Kind.AND, "turn the dishes to the moon", _hu - 2.5, _hv + 8.5, gy.call(-2.5, 8.5))
	var ton_jars := _part(LumenPart.Kind.TON, "the jars have stood full", _hu + 4.2, _hv - 6.2, gy.call(4.2, -6.2), 5.0)
	var ton_vials := _part(LumenPart.Kind.TON, "the rack has stood full", _hu + 7.0, _hv - 2.6, gy.call(7.0, -2.6), 5.0)
	_r["rods"] = _part(LumenPart.Kind.RADIOMETER, "raises the rods", _hu - 7.6, _hv - 4.6, ground(_hu - 7.6, _hv - 4.6) + 2.0)
	_r["dishes"] = _part(LumenPart.Kind.RADIOMETER, "unparks the dishes", _hu + 2.0, _hv + 7.4, ground(_hu + 2.0, _hv + 7.4) + 2.0)
	_r["discharge"] = _part(LumenPart.Kind.RADIOMETER, "empties the jars into a thunderstone", _hu + 3.4, _hv - 4.8, ground(_hu + 3.4, _hv - 4.8) + 2.0)
	_r["pack"] = _part(LumenPart.Kind.RADIOMETER, "packs the vials into a crate", _hu + 4.6, _hv + 2.4, ground(_hu + 4.6, _hv + 2.4) + 2.0)
	_wire(_l["jars"], not_jars)
	_wire(_l["storm"], and_rods)
	_wire(not_jars, and_rods)
	_wire(_l["run"], and_rods)
	_wire(and_rods, _r["rods"])
	_wire(_l["storm"], tof_storm)
	_wire(tof_storm, not_storm)
	_wire(_l["vials"], not_vials)
	_wire(_l["moon"], and_dishes)
	_wire(not_storm, and_dishes)
	_wire(not_vials, and_dishes)
	_wire(_l["run"], and_dishes)
	_wire(and_dishes, _r["dishes"])
	_wire(_l["jars"], ton_jars)
	_wire(ton_jars, _r["discharge"])
	_wire(_l["vials"], ton_vials)
	_wire(ton_vials, _r["pack"])
	_lever = WorksHandle.new(WorksHandle.Kind.LEVER, hill(-3.2, 2.6, 0.55), _wood, _brass,
			"Run lever\nE: let the rods rise and the dishes turn, or keep them down.")
	_site.add_child(_lever)


func _build_sounds() -> void:
	_snd_rain = AudioStreamPlayer.new()
	_snd_rain.stream = _sound("res://audio/rain_loop.wav", true)
	_snd_rain.volume_db = -80.0
	_snd_rain.autoplay = _snd_rain.stream != null
	add_child(_snd_rain)
	_snd_crackle = _speaker("res://audio/crackle.wav", false, hill(0, 0, 3), 10.0)
	_snd_ratchet = _speaker("res://audio/ratchet.wav", false, hill(0, 0, 2), 5.0)
	_snd_chime = _speaker("res://audio/chime.wav", false, _rack_at, 5.0)
	_snd_pack = _speaker("res://audio/clank_2.wav", false, _rack_at, 5.0)
	for i in 3:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 80.0
		p.max_db = 3.0
		_site.add_child(p)
		_snd_thunder.append(p)


## ---- the simulation --------------------------------------------------------

func _on(key: String) -> bool:
	return (_r[key] as LumenPart).spin > 0.5


func _edge(key: String) -> bool:
	var now: bool = (_r[key] as LumenPart).powered
	var was: bool = _was.get(key, false)
	_was[key] = now
	return now and not was


func _physics_process(dt: float) -> void:
	_clock += dt
	var summit := _site.to_global(hill(0, 0, 0))
	# Storms come, cross and go.
	if _storm_live:
		_storm_pos += _storm_dir * STORM_SPEED * dt
		if _storm_pos.length() > 1000.0 and _storm_pos.dot(_storm_dir) > 0.0:
			_storm_live = false
			_storm.visible = false
			_rain.emitting = false
			_storm_wait = _rng.randf_range(80.0, 180.0)
	else:
		_storm_wait -= dt
		if _storm_wait <= 0.0:
			_start_storm()
	var d := Vector2(_storm_pos.x - summit.x, _storm_pos.z - summit.z).length() if _storm_live else 9999.0
	_storm_near = clampf(1.0 - d / 700.0, 0.0, 1.0)
	# Strikes, at random moments, more often the nearer.
	if _storm_live and d < 700.0 and _rng.randf() < 0.4 * _storm_near * dt:
		var rod := -1
		var best := INF
		if d < STRIKE_REACH:
			for i in 3:
				if float(_rod_up[i]) > 0.8:
					var tip := _rod_tops[i].global_position
					var far := Vector2(tip.x - _storm_pos.x, tip.z - _storm_pos.z).length()
					if far < best:
						best = far
						rod = i
		if rod >= 0 and _charge < JARS:
			_strike(_rod_tops[rod].global_position + Vector3(0, 0.6, 0), rod)
		else:
			var a := _rng.randf() * TAU
			var r := _rng.randf() * 45.0
			var x := _storm_pos.x + cos(a) * r
			var z := _storm_pos.z + sin(a) * r
			_strike(Vector3(x, maxf(island.height(x, z), 0.0), z), -1)
	# Thunder arriving.
	var still: Array = []
	for t: Array in _thunders:
		if _clock >= float(t[0]):
			if t[1] == "crackle":
				_play(_snd_crackle, randf_range(0.9, 1.1))
			else:
				for p in _snd_thunder:
					if not p.playing:
						p.stream = _sound(t[1], false)
						p.position = _site.to_local(t[3])
						_play(p, float(t[2]))
						break
		else:
			still.append(t)
	_thunders = still
	# Rods rise while their radiometer spins, clicking as they climb.
	for i in 3:
		var was: float = _rod_up[i]
		_rod_up[i] = move_toward(was, 1.0 if _on("rods") else 0.0, dt * 0.35)
		if floori(float(_rod_up[i]) * 8.0) != floori(was * 8.0):
			_snd_ratchet.position = _site.to_local(_rod_tops[i].global_position)
			_play(_snd_ratchet, randf_range(0.9, 1.1))
		_rod_glow[i] = maxf(float(_rod_glow[i]) - dt * 1.5, 0.0)
	# The dishes: to the moon while unparked, else face down.
	var moon_dir := island.sky.moon_direction()
	var night := 1.0 - island.sky.daylight
	var moon_up := island.sky.moon_height > 3.0 and night > 0.5
	var gather := 0.0
	for i in 3:
		var yaw_want := float(_dish_yaw[i])
		var pitch_want := -1.3
		if _on("dishes"):
			var local := _site.global_transform.basis.inverse() * moon_dir
			yaw_want = atan2(-local.x, -local.z)
			pitch_want = asin(clampf(local.y, -1.0, 1.0))
		_dish_yaw[i] = rotate_toward(float(_dish_yaw[i]), yaw_want, dt * 0.6)
		_dish_pitch[i] = move_toward(float(_dish_pitch[i]), pitch_want, dt * 0.5)
		var facing := _dish_tilts[i].global_transform.basis.z * -1.0
		var square := pow(clampf(facing.dot(moon_dir), 0.0, 1.0), 8.0)
		var take := island.sky.moon_lit * maxf(moon_dir.y, 0.0) * night * (1.0 - _storm_near) * square if moon_up else 0.0
		_dish_take[i] = take
		gather += take
	var before := floori(_moon)
	_moon = minf(_moon + gather * 0.04 * dt, VIALS)
	if floori(_moon) != before:
		_play(_snd_chime, 1.6)
	# Discharging full jars, packing a full rack.
	if _edge("discharge"):
		_charge = 0.0
		_stones = (_stones + 1) % 1000
		_show(_stone_digits, _stones)
		_discharge_flash = 1.0
		_snd_crackle.position = hill(2.4, -3.8, 1.2)
		_play(_snd_crackle, 0.8)
	if _edge("pack"):
		_moon = 0.0
		_crates = (_crates + 1) % 1000
		_show(_crate_digits, _crates)
		_play(_snd_pack, 1.4)
	# The lanterns.
	_l["storm"].condition = d < (420.0 if _l["storm"].condition else 350.0)
	_l["jars"].condition = _charge >= JARS - 0.05
	_l["moon"].condition = moon_up
	_l["vials"].condition = _moon >= VIALS - 0.05
	_l["run"].condition = _lever.on
	_step_circuit(dt)


func _process(delta: float) -> void:
	# The storm cloud, and how it darkens with the sky.
	if _storm_live:
		_storm.global_position = Vector3(_storm_pos.x, 0, _storm_pos.z)
		var day := island.sky.daylight
		var grey := lerpf(0.12, 0.42, day)
		_storm_mat.albedo_color = Color(grey, grey * 1.02, grey * 1.12, 0.92)
	# The bolt flickers in three pulses, the flash with it.
	if _bolt_left > 0.0:
		_bolt_left -= delta
		var pulse := maxf(sin(_bolt_left * 40.0), 0.0) * (_bolt_left / 0.5)
		_bolt_mat.albedo_color = Color(0.9, 0.9, 1.0) * (1.5 + 6.0 * pulse)
		_flash.visible = true
		_flash.light_energy = 14.0 * pulse
		if _bolt_left <= 0.0:
			_bolt.visible = false
			_flash.visible = false
	_snd_rain.volume_db = linear_to_db(clampf((_storm_near - 0.5) * 2.0, 0.0001, 1.0)) - 4.0
	_storm_glass.emission_energy_multiplier = _storm_near * 1.5
	_storm_glass.albedo_color = Color(0.85, 0.9, 1.0, 0.25 + 0.6 * _storm_near)
	# Rods, their tips, the cables.
	var cable_glow := 0.0
	for i in 3:
		var p: Vector2 = RODS[i]
		_rod_tops[i].position = hill(p.x, p.y, ROD_LOW + 0.5 + ROD_RISE * float(_rod_up[i]))
		_rod_tip_mats[i].emission_energy_multiplier = 0.2 + 6.0 * float(_rod_glow[i]) + 0.6 * _storm_near * float(_rod_up[i])
		cable_glow = maxf(cable_glow, float(_rod_glow[i]))
	_cable_mat.emission_energy_multiplier = 3.0 * cable_glow
	# Jars fill in turn.
	for i in 4:
		var share := clampf(_charge - i, 0.0, 1.0)
		_jar_mats[i].emission_energy_multiplier = share * (1.5 + 0.3 * sin(_clock * 5.0 + i))
	_discharge_flash = maxf(_discharge_flash - delta * 0.8, 0.0)
	_stone_mat.emission_energy_multiplier = 0.6 + 4.0 * _discharge_flash + 0.3 * sin(_clock * 1.5)
	# Dishes, their focus crystals and beams to the rack.
	for i in 3:
		_dish_yaws[i].rotation.y = float(_dish_yaw[i])
		_dish_tilts[i].rotation.x = float(_dish_pitch[i])
		var take: float = _dish_take[i]
		_focus_mats[i].emission_energy_multiplier = 0.2 + 5.0 * take
		var beam := _dish_beams[i]
		beam.visible = take > 0.02
		if beam.visible:
			var a := _site.to_local(_dish_tilts[i].to_global(Vector3(0, 0, -1.6)))
			var span := _rack_at - a
			beam.transform = Transform3D(CozyMesh.aligned(span) * Basis.from_scale(Vector3(1, span.length(), 1)), (a + _rack_at) * 0.5)
	_beam_mat.albedo_color = Color(0.6, 0.7, 1.0) * 0.8
	# Vials.
	for i in 8:
		var f := clampf(_moon - i, 0.0, 1.0)
		var fi := _vial_fills[i]
		fi.visible = f > 0.02
		var base: Vector3 = fi.get_meta("base")
		fi.position = base + Vector3(0, 0.22 * f * 0.5 + 0.02, 0)
		fi.scale = Vector3(1, maxf(0.22 * f, 0.005), 1)
