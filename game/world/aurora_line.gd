class_name AuroraLine
extends Node3D
## The aurora line: water carried across the cozy island on a ropeway of
## aurora cable, the cable spun from the northern lights caught on the
## north dunes.
##
## The way it goes round:
## - The aurora comb (a mast 24 m tall on the north dunes with a broad
##   brass comb at its top) catches the aurora (Aurora) on dark nights:
##   threads of light come down onto its tines and gather as fleece in
##   two baskets at its foot, green from the curtains' lower edge and red
##   from their tops, twice as much green as red (CATCH).
## - Two great spinning frames beside it, one for each colour, twist the
##   fleece, wetted with water from the cistern, into cable and wind it
##   on spools: SPOOL_TIME to a spool, FLEECE_PER_SPOOL and WATER_PER_SPOOL
##   spent on each. Full spools go to the spool store, RACK of each colour
##   at most.
## - The ropeway runs from the spring at A, on the south-west shore past
##   the campfire, to the cistern at B by the spinners, about 280 m, bent
##   at an angle tower east of the central hill, so neither end can see
##   the other. Its carrying cable is red cable, push cable, which holds
##   itself straight between the towers without sagging; a carriage runs
##   on it with a copper bucket hanging below.
## - At the spring the bucket fills (FILL_TIME). Its weight, felt down the
##   haul cable, tells the drive house at B to bring it home: the green
##   drum winds in pull cable and hauls the carriage to B. There the
##   bucket tips into the cistern (EMPTY_TIME, WATER_PER_LOAD), and the
##   red drum pays out push cable and sends the empty carriage back. Every
##   metre hauled spends cable (a spool's worth for SPOOL_METRES), drawn
##   from the store onto the drums a spool at a time; with no spool of the
##   colour wanted, the line waits.
##
## So the aurora makes the cable that carries the water that spins the
## aurora into cable. The store starts with spools in it, so the line
## runs by day; the aurora and the catch come only at night. The state is
## kept in SAVE_PATH.
##
## Engine features only: the still parts are one mesh built cozy-native
## (CozyMesh, flat colours), the moving parts engine primitives, the
## glowing threads one mesh of camera-facing ribbons rebuilt each frame.
## The notes floating over the parts are drafts.

const A_AT := Vector3(-54.3, 0.0, 116.4)     # the spring
const B_AT := Vector3(-46.2, 0.0, -142.1)    # the cistern
const M_AT := Vector3(0.0, 0.0, -30.0)       # the angle tower
const CLEAR_H := 13.0                   # the cable's height over the ground at a tower
const SPACING := 38.0                   # towers at most this far apart
const STATION_H := 4.6                  # the cable's height over the ground at a station
const HANG := 2.5                       # the bucket's middle below the cable
const SPEED := 6.0                      # m/s, the carriage's top speed
const ACCEL := 1.0
const FILL_TIME := 5.0
const EMPTY_TIME := 4.0
const SPOOL_METRES := 900.0             # metres hauled on a spool's worth of cable
const SPOOL_TIME := 30.0                # seconds to spin a spool
const FLEECE_PER_SPOOL := 2.0
const WATER_PER_SPOOL := 0.1
const WATER_PER_LOAD := 0.4
const BASKET := 10.0                    # fleece a basket holds
const RACK := 8                         # spools of a colour the store holds
const CATCH := {"green": 0.1, "red": 0.05}   # fleece a second at full aurora
const START_SPOOLS := 4
const COLOURS := {"green": Color(0.3, 1.0, 0.5), "red": Color(1.0, 0.28, 0.3)}
const SAVE_PATH := "user://cozy_island_aurora.json"

enum Stage { FILLING, TO_B, EMPTYING, TO_A }

var island: CozyIsland
var fleece := {"green": 0.0, "red": 0.0}
var spools := {"green": START_SPOOLS, "red": START_SPOOLS}
var drum := {"green": 0.0, "red": 0.0}         # metres of cable on each drum
var progress := {"green": 0.0, "red": 0.0}     # the spool being spun
var spinning := {"green": false, "red": false}
var water := 0.5                                # the cistern, 0 to 1
var stage := Stage.FILLING
var along := 0.0                                # the carriage, m from A along the cable
var speed := 0.0
var load := 0.0                                 # the bucket, 0 to 1

var _rope: Array[Vector3] = []
var _length := 0.0
var _d_a := Vector3.ZERO                        # flat, away from A along the line
var _d_b := Vector3.ZERO                        # flat, toward B along the line
var _side_b := Vector3.ZERO
var _a_ground := Vector3.ZERO
var _b_ground := Vector3.ZERO
var _comb := Vector3.ZERO
var _tines: Array[Vector3] = []
var _baskets := {}                              # colour -> foot point
var _frames := {}                               # colour -> {wheel, bobbin, at}
var _carriage := Node3D.new()
var _pivot := Node3D.new()
var _bucket_water: MeshInstance3D
var _sheaves: Array[Node3D] = []
var _bull_wheel := Node3D.new()
var _drums := {}                                # colour -> Node3D
var _drum_turn := 0.0
var _rack := {}                                 # colour -> Array of spool nodes
var _puffs := {}                                # colour -> MeshInstance3D
var _cistern_water: MeshInstance3D
var _pour_a: MeshInstance3D
var _pour_b: MeshInstance3D
var _track_mat := StandardMaterial3D.new()
var _haul_mat := StandardMaterial3D.new()
var _water_mat := StandardMaterial3D.new()
var _glow := ImmediateMesh.new()
var _glow_mat := StandardMaterial3D.new()
var _notes := {}                                # name -> HoverNote
var _sounds := {}                               # name -> AudioStreamPlayer3D
var _clock := 0.0
var _note_left := 0.0
var _save_left := 5.0
var _tip := 0.0                                 # the bucket's tip, 0 upright to 1 poured


func _init(owner_island: CozyIsland) -> void:
	island = owner_island
	name = "AuroraLine"


func _ready() -> void:
	_route()
	_materials()
	var still := CozyMesh.new()
	_build_towers(still)
	_build_spring(still)
	_build_cistern(still)
	_build_catcher(still)
	_build_frames(still)
	_build_store(still)
	_build_ropes()
	_build_carriage()
	var view := MeshInstance3D.new()
	view.name = "Still"
	view.mesh = still.commit(island.cozy_material(true))
	add_child(view)
	var glow_view := MeshInstance3D.new()
	glow_view.name = "Threads"
	glow_view.mesh = _glow
	glow_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow_view.extra_cull_margin = 16384.0
	add_child(glow_view)
	_build_sounds()
	if not MouseMode.probe:
		_load()
	_place_carriage()


func _exit_tree() -> void:
	_save()


## ---- the route ----------------------------------------------------------------

func _g(p: Vector3) -> float:
	return island.height(p.x, p.z)


## The cable's points: the spring's station, towers on the way to the
## angle tower, the angle tower, towers on to the cistern, its station.
func _route() -> void:
	_a_ground = Vector3(A_AT.x, _g(A_AT), A_AT.z)
	_b_ground = Vector3(B_AT.x, _g(B_AT), B_AT.z)
	var m := Vector3(M_AT.x, _g(M_AT) + CLEAR_H, M_AT.z)
	_rope.append(_a_ground + Vector3(0, STATION_H, 0))
	_rope.append_array(_tops(_a_ground, m))
	_rope.append(m)
	_rope.append_array(_tops(m, _b_ground))
	_rope.append(_b_ground + Vector3(0, STATION_H, 0))
	for k in _rope.size() - 1:
		_length += _rope[k].distance_to(_rope[k + 1])
	_d_a = _flat(_rope[1] - _rope[0])
	_d_b = _flat(_rope[-1] - _rope[-2])
	_side_b = _d_b.cross(Vector3.UP).normalized()


func _tops(a: Vector3, b: Vector3) -> Array[Vector3]:
	var n := ceili(Vector2(b.x - a.x, b.z - a.z).length() / SPACING)
	var out: Array[Vector3] = []
	for k in range(1, n):
		var p := a.lerp(b, float(k) / n)
		p.y = _g(p) + CLEAR_H
		out.append(p)
	return out


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()


## The point `s` metres along the cable from A, and the way it runs there.
func _rope_at(s: float) -> Array:
	var left := clampf(s, 0.0, _length)
	for k in _rope.size() - 1:
		var seg := _rope[k].distance_to(_rope[k + 1])
		if left <= seg or k == _rope.size() - 2:
			var t := clampf(left / maxf(seg, 0.001), 0.0, 1.0)
			return [_rope[k].lerp(_rope[k + 1], t), (_rope[k + 1] - _rope[k]).normalized()]
		left -= seg
	return [_rope[-1], _d_b]


## ---- building ------------------------------------------------------------------

const TIMBER := Color(0.45, 0.33, 0.22)
const STONE := Color(0.64, 0.61, 0.56)
const BRASS := Color(0.86, 0.66, 0.3)
const WICKER := Color(0.62, 0.46, 0.26)
const ROOF := Color(0.6, 0.28, 0.22)


func _materials() -> void:
	_track_mat.albedo_color = Color(0.5, 0.12, 0.12)
	_track_mat.emission_enabled = true
	_track_mat.emission = COLOURS["red"]
	_track_mat.emission_energy_multiplier = 0.8
	_haul_mat.albedo_color = Color(0.25, 0.25, 0.25)
	_haul_mat.emission_enabled = true
	_haul_mat.emission = COLOURS["green"]
	_haul_mat.emission_energy_multiplier = 0.2
	_water_mat.albedo_color = Color(0.35, 0.6, 0.85, 0.85)
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_mat.roughness = 0.08
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.vertex_color_use_as_albedo = true
	_glow_mat.vertex_color_is_srgb = true
	_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glow_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_glow_mat.disable_fog = true


## An A-frame trestle under each tower top, its legs spread across the
## line, a crossarm and a sheave the cable runs over; the angle tower a
## pair of them. Each leg's foot is solid.
func _build_towers(m: CozyMesh) -> void:
	var solid := StaticBody3D.new()
	solid.name = "TowerFeet"
	add_child(solid)
	for k in range(1, _rope.size() - 1):
		var top := _rope[k]
		var across := _flat(_rope[k + 1] - _rope[k - 1]).cross(Vector3.UP).normalized()
		for side: float in [-1.0, 1.0]:
			var foot := top + across * side * (1.4 + top.y * 0.02)
			foot.y = _g(foot) - 0.3
			m.rod(foot, top + across * side * 0.35 + Vector3(0, 0.3, 0), 0.13, 6, TIMBER)
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(0.45, 2.6, 0.45)
			shape.shape = box
			shape.position = foot + Vector3(0, 1.3, 0)
			solid.add_child(shape)
			# Braces between the legs at a third and two thirds.
		for f: float in [0.35, 0.7]:
			var y := lerpf(_g(top) - 0.3, top.y, f)
			var spread := lerpf(1.4 + top.y * 0.02, 0.35, f)
			m.rod(Vector3(top.x, y, top.z) - across * spread, Vector3(top.x, y, top.z) + across * spread, 0.07, 6, TIMBER)
		m.rod(top + Vector3(0, 0.45, 0) - across * 0.7, top + Vector3(0, 0.45, 0) + across * 0.7, 0.09, 6, TIMBER)
		var sheave := Node3D.new()
		sheave.position = top + Vector3(0, 0.1, 0)
		sheave.basis = Basis.looking_at(across, Vector3.UP)
		sheave.set_meta(StaticMerge.MOVES, true)
		add_child(sheave)
		var wheel := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.16
		tm.outer_radius = 0.26
		tm.rings = 16
		tm.ring_segments = 6
		tm.material = island.cozy_material(true)
		wheel.mesh = _coloured(tm, BRASS)
		wheel.rotation.x = PI * 0.5
		sheave.add_child(wheel)
		_sheaves.append(sheave)


## A primitive painted one flat colour, for a moving part drawn as the
## still ones are.
func _coloured(prim: PrimitiveMesh, colour: Color) -> Mesh:
	var cm := CozyMesh.new()
	cm.add(prim, Transform3D.IDENTITY, colour)
	return cm.commit(island.cozy_material(true))


## A station's frame: two posts either side of the cable's end and a beam
## over it.
func _station_frame(m: CozyMesh, ground: Vector3, along_dir: Vector3) -> void:
	var across := along_dir.cross(Vector3.UP).normalized()
	for side: float in [-1.0, 1.0]:
		var foot := ground + across * side * 1.2
		foot.y = _g(foot) - 0.2
		m.rod(foot, Vector3(foot.x, ground.y + STATION_H + 0.5, foot.z), 0.12, 6, TIMBER)
	m.rod(ground + Vector3(0, STATION_H + 0.45, 0) - across * 1.35, ground + Vector3(0, STATION_H + 0.45, 0) + across * 1.35, 0.1, 6, TIMBER)


## The spring at A: a round stone well-head brimming, a pipe up from it
## and over the bucket's place to a spout; the station's frame; the bull
## wheel the haul cable turns round, behind the station.
func _build_spring(m: CozyMesh) -> void:
	var g := _a_ground
	_station_frame(m, g, _d_a)
	var across := _d_a.cross(Vector3.UP).normalized()
	var well := g + across * 2.2
	well.y = _g(well)
	m.cyl(1.0, 1.1, 0.8, 16, CozyMesh.at(well + Vector3(0, 0.3, 0)), STONE)
	m.cyl(0.85, 0.85, 0.04, 16, CozyMesh.at(well + Vector3(0, 0.66, 0)), Color(0.35, 0.58, 0.82))
	var bucket_top := g + Vector3(0, STATION_H - HANG + 0.4, 0)
	m.rod(well + Vector3(0, 0.6, 0), Vector3(well.x, bucket_top.y + 0.7, well.z), 0.06, 8, BRASS)
	m.rod(Vector3(well.x, bucket_top.y + 0.7, well.z), bucket_top + Vector3(0, 0.7, 0), 0.06, 8, BRASS)
	m.rod(bucket_top + Vector3(0, 0.7, 0), bucket_top + Vector3(0, 0.45, 0), 0.07, 8, BRASS)
	_pour_a = _stream(bucket_top + Vector3(0, 0.45, 0), bucket_top)
	_bull_wheel.position = g - _d_a * 0.9 + Vector3(0, STATION_H - 0.35, 0)
	_bull_wheel.set_meta(StaticMerge.MOVES, true)
	add_child(_bull_wheel)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.7
	tm.rings = 24
	tm.ring_segments = 6
	rim.mesh = _coloured(tm, BRASS)
	_bull_wheel.add_child(rim)
	for k in 3:
		var spoke := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.2, 0.06, 0.08)
		spoke.mesh = _coloured(bm, TIMBER)
		spoke.rotation.y = TAU * k / 6.0
		_bull_wheel.add_child(spoke)
	m.rod(Vector3(_bull_wheel.position.x, _g(_bull_wheel.position) - 0.2, _bull_wheel.position.z),
			_bull_wheel.position - Vector3(0, 0.05, 0), 0.12, 6, TIMBER)
	_notes["spring"] = _note(well + Vector3(0, 0.6, 0), Vector3(2.2, 1.2, 2.2), 2.8)


## The cistern at B under the bucket's place, the station's frame, and
## the drive house beyond with its two drums.
func _build_cistern(m: CozyMesh) -> void:
	var g := _b_ground
	_station_frame(m, g, _d_b)
	m.cyl(1.7, 1.8, 1.1, 20, CozyMesh.at(g + Vector3(0, 0.45, 0)), STONE)
	_cistern_water = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.5
	disc.bottom_radius = 1.5
	disc.height = 0.04
	disc.radial_segments = 20
	disc.rings = 1
	disc.material = _water_mat
	_cistern_water.mesh = disc
	_cistern_water.set_meta(StaticMerge.MOVES, true)
	add_child(_cistern_water)
	_pour_b = _stream(g + Vector3(0, 1.8, 0), g + Vector3(0, 0.9, 0))
	# The drive house: posts, a pitched roof, and the drums on an axle.
	var house := g + _d_b * 3.6
	house.y = _g(house)
	var across := _side_b
	for u: float in [-1.4, 1.4]:
		for v: float in [-1.0, 1.0]:
			var foot := house + across * u + _d_b * v
			m.rod(Vector3(foot.x, _g(foot) - 0.2, foot.z), Vector3(foot.x, house.y + 2.6, foot.z), 0.1, 6, TIMBER)
	var roof_basis := Basis(across, Vector3.UP, across.cross(Vector3.UP).normalized())
	for side: float in [-1.0, 1.0]:
		var slope := roof_basis * Basis(Vector3.RIGHT, side * 0.45)
		m.box(Vector3(3.2, 0.08, 1.4), Transform3D(slope, house + Vector3(0, 2.95, 0) + _d_b * side * 0.6), ROOF)
	m.rod(house + Vector3(0, 1.3, 0) - across * 1.4, house + Vector3(0, 1.3, 0) + across * 1.4, 0.05, 8, TIMBER)
	for k in 2:
		var colour: String = ["green", "red"][k]
		var d := Node3D.new()
		d.position = house + Vector3(0, 1.3, 0) + across * (k * 1.2 - 0.6)
		d.basis = Basis(_d_b, Vector3.UP, across).orthonormalized()
		d.set_meta(StaticMerge.MOVES, true)
		add_child(d)
		var core := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.5
		cyl.height = 0.6
		cyl.radial_segments = 16
		cyl.rings = 1
		var mat := StandardMaterial3D.new()
		mat.albedo_color = (COLOURS[colour] as Color).darkened(0.6)
		mat.emission_enabled = true
		mat.emission = COLOURS[colour]
		mat.emission_energy_multiplier = 0.6
		cyl.material = mat
		core.mesh = cyl
		core.rotation.x = PI * 0.5
		d.add_child(core)
		for f: float in [-0.32, 0.32]:
			var flange := MeshInstance3D.new()
			var fm := CylinderMesh.new()
			fm.top_radius = 0.75
			fm.bottom_radius = 0.75
			fm.height = 0.05
			fm.radial_segments = 16
			fm.rings = 1
			flange.mesh = _coloured(fm, TIMBER)
			flange.rotation.x = PI * 0.5
			flange.position.z = f
			d.add_child(flange)
		_drums[colour] = d
	_notes["cistern"] = _note(g + Vector3(0, 0.55, 0), Vector3(3.6, 1.1, 3.6), 3.0)
	_notes["drive"] = _note(house + Vector3(0, 1.4, 0), Vector3(3.0, 2.8, 2.2), 3.3)


## A stream of water from `a` down to `b`, shown while it runs.
func _stream(a: Vector3, b: Vector3) -> MeshInstance3D:
	var s := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.07
	cyl.height = 1.0
	cyl.radial_segments = 8
	cyl.rings = 1
	cyl.material = _water_mat
	s.mesh = cyl
	s.set_meta(StaticMerge.MOVES, true)
	_aim_stream(s, a, b)
	s.visible = false
	add_child(s)
	return s


func _aim_stream(s: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var len := maxf(a.distance_to(b), 0.05)
	s.basis = CozyMesh.aligned(b - a) * Basis.from_scale(Vector3(1.0, len, 1.0))
	s.position = (a + b) * 0.5


## The aurora comb: a mast with a broad brass comb on top facing north,
## stayed by four guys, and two baskets of fleece at its foot.
func _build_catcher(m: CozyMesh) -> void:
	var foot := _b_ground + _side_b * 15.0 - _d_b * 2.0
	foot.y = _g(foot)
	_comb = foot + Vector3(0, 24.0, 0)
	m.cyl(0.14, 0.26, 24.4, 8, CozyMesh.at(foot + Vector3(0, 12.0, 0)), TIMBER)
	m.rod(_comb - Vector3(4.2, 0, 0), _comb + Vector3(4.2, 0, 0), 0.1, 6, BRASS)
	for k in 15:
		var x := -4.0 + 8.0 * k / 14.0
		var base := _comb + Vector3(x, 0, 0)
		var tip := base + Vector3(0, 1.7, -0.6)
		m.rod(base, tip, 0.03, 5, BRASS)
		_tines.append(tip)
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		var stake := foot + Vector3(cos(a), 0, sin(a)) * 10.0
		stake.y = _g(stake)
		m.rod(stake, _comb - Vector3(0, 2.0, 0), 0.02, 4, Color(0.3, 0.3, 0.32))
		m.cyl(0.08, 0.1, 0.5, 6, CozyMesh.at(stake + Vector3(0, 0.2, 0)), TIMBER)
	for k in 2:
		var colour: String = ["green", "red"][k]
		var at := foot + _d_b * (k * 2.4 - 1.2) + _side_b * 1.4
		at.y = _g(at)
		_baskets[colour] = at
		m.cyl(0.62, 0.5, 0.7, 12, CozyMesh.at(at + Vector3(0, 0.35, 0)), WICKER)
		var puff := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.55
		ball.height = 0.8
		ball.radial_segments = 12
		ball.rings = 6
		var mat := StandardMaterial3D.new()
		mat.albedo_color = (COLOURS[colour] as Color).lightened(0.3)
		mat.emission_enabled = true
		mat.emission = COLOURS[colour]
		mat.emission_energy_multiplier = 1.2
		ball.material = mat
		puff.mesh = ball
		puff.position = at + Vector3(0, 0.7, 0)
		puff.set_meta(StaticMerge.MOVES, true)
		add_child(puff)
		_puffs[colour] = puff
	_notes["comb"] = _note(foot + Vector3(0, 1.5, 0), Vector3(1.2, 3.0, 1.2), 3.6)


## The two spinning frames: each a long bench, a great wheel 4 m across
## standing on it, and a spool turning at its end.
func _build_frames(m: CozyMesh) -> void:
	for k in 2:
		var colour: String = ["green", "red"][k]
		var at := _b_ground + _side_b * 8.0 + _d_b * (k * 5.0 - 1.5)
		at.y = _g(at)
		var basis := Basis(_side_b, Vector3.UP, _side_b.cross(Vector3.UP).normalized())
		m.box(Vector3(3.2, 0.35, 0.9), Transform3D(basis, at + Vector3(0, 0.55, 0)), TIMBER)
		for leg: float in [-1.4, 1.4]:
			m.box(Vector3(0.2, 0.4, 0.8), Transform3D(basis, at + _side_b * leg + Vector3(0, 0.2, 0)), TIMBER)
		var hub := at + _side_b * -0.6 + Vector3(0, 2.75, 0)
		for side: float in [-1.0, 1.0]:
			m.rod(at + _side_b * -0.6 + _d_b * side * 0.3 + Vector3(0, 0.7, 0), hub + _d_b * side * 0.3, 0.08, 6, TIMBER)
		var wheel := Node3D.new()
		wheel.position = hub
		wheel.basis = Basis(_side_b, Vector3.UP, _d_b).orthonormalized()
		wheel.set_meta(StaticMerge.MOVES, true)
		add_child(wheel)
		var rim := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.9
		tm.outer_radius = 2.05
		tm.rings = 40
		tm.ring_segments = 6
		rim.mesh = _coloured(tm, TIMBER)
		rim.rotation.z = PI * 0.5
		wheel.add_child(rim)
		for s in 6:
			var spoke := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.06, 3.9, 0.06)
			spoke.mesh = _coloured(bm, TIMBER)
			spoke.rotation.x = TAU * s / 12.0
			wheel.add_child(spoke)
		var bobbin := Node3D.new()
		bobbin.position = at + _side_b * 1.2 + Vector3(0, 1.1, 0)
		bobbin.basis = Basis(_side_b, Vector3.UP, _d_b).orthonormalized()
		bobbin.set_meta(StaticMerge.MOVES, true)
		add_child(bobbin)
		var core := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.0
		cyl.bottom_radius = 1.0
		cyl.height = 0.4
		cyl.radial_segments = 14
		cyl.rings = 1
		var mat := StandardMaterial3D.new()
		mat.albedo_color = (COLOURS[colour] as Color).darkened(0.5)
		mat.emission_enabled = true
		mat.emission = COLOURS[colour]
		mat.emission_energy_multiplier = 0.9
		cyl.material = mat
		core.mesh = cyl
		core.rotation.z = PI * 0.5
		bobbin.add_child(core)
		_frames[colour] = {"wheel": wheel, "bobbin": bobbin, "core": core, "at": at, "hub": hub}
		_notes["frame_" + colour] = _note(at + Vector3(0, 1.0, 0), Vector3(3.4, 2.0, 1.2), 4.4)


## The spool store: a long rack with two shelves, green spools above and
## red below.
func _build_store(m: CozyMesh) -> void:
	var at := _b_ground + _side_b * 8.0 - _d_b * 7.5
	at.y = _g(at)
	var basis := Basis(_side_b, Vector3.UP, _side_b.cross(Vector3.UP).normalized())
	for u: float in [-2.2, 2.2]:
		m.box(Vector3(0.15, 2.0, 0.6), Transform3D(basis, at + _side_b * u + Vector3(0, 1.0, 0)), TIMBER)
	for y: float in [0.5, 1.3]:
		m.box(Vector3(4.6, 0.08, 0.6), Transform3D(basis, at + Vector3(0, y, 0)), TIMBER)
	m.box(Vector3(4.8, 0.1, 0.8), Transform3D(basis, at + Vector3(0, 2.05, 0)), ROOF)
	for k in 2:
		var colour: String = ["green", "red"][k]
		var row: Array[Node3D] = []
		for i in RACK:
			var spool := Node3D.new()
			spool.position = at + _side_b * (-1.85 + i * 0.53) + Vector3(0, 1.58 - k * 0.8, 0)
			spool.basis = Basis(_side_b, Vector3.UP, _d_b).orthonormalized()
			spool.set_meta(StaticMerge.MOVES, true)
			add_child(spool)
			var core := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.18
			cyl.bottom_radius = 0.18
			cyl.height = 0.3
			cyl.radial_segments = 12
			cyl.rings = 1
			var mat := StandardMaterial3D.new()
			mat.albedo_color = (COLOURS[colour] as Color).darkened(0.5)
			mat.emission_enabled = true
			mat.emission = COLOURS[colour]
			mat.emission_energy_multiplier = 0.7
			cyl.material = mat
			core.mesh = cyl
			core.rotation.z = PI * 0.5
			spool.add_child(core)
			for f: float in [-0.17, 0.17]:
				var flange := MeshInstance3D.new()
				var fm := CylinderMesh.new()
				fm.top_radius = 0.24
				fm.bottom_radius = 0.24
				fm.height = 0.03
				fm.radial_segments = 12
				fm.rings = 1
				flange.mesh = _coloured(fm, TIMBER)
				flange.rotation.z = PI * 0.5
				flange.position.x = f
				spool.add_child(flange)
			row.append(spool)
		_rack[colour] = row
	_notes["store"] = _note(at + Vector3(0, 1.0, 0), Vector3(4.8, 2.0, 0.8), 2.6)


## The carrying cable (red, glowing) between the towers' tops, and the
## haul cable a little below it, glowing in the colour of the drum at
## work.
func _build_ropes() -> void:
	for k in _rope.size() - 1:
		for haul in [false, true]:
			var a := _rope[k] - Vector3(0, 0.35 if haul else 0.0, 0)
			var b := _rope[k + 1] - Vector3(0, 0.35 if haul else 0.0, 0)
			var seg := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.025 if haul else 0.04
			cyl.bottom_radius = cyl.top_radius
			cyl.height = 1.0
			cyl.radial_segments = 6
			cyl.rings = 1
			cyl.material = _haul_mat if haul else _track_mat
			seg.mesh = cyl
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			seg.basis = CozyMesh.aligned(b - a) * Basis.from_scale(Vector3(1.0, a.distance_to(b), 1.0))
			seg.position = (a + b) * 0.5
			add_child(seg)


## The carriage: two grooved wheels on the cable, a hanger down to a
## copper bucket on a pivot, its water inside.
func _build_carriage() -> void:
	_carriage.top_level = true
	_carriage.set_meta(StaticMerge.MOVES, true)
	add_child(_carriage)
	var copper := StandardMaterial3D.new()
	copper.albedo_color = Color(0.72, 0.4, 0.25)
	copper.metallic = 0.7
	copper.roughness = 0.35
	copper.cull_mode = BaseMaterial3D.CULL_DISABLED
	for u: float in [-0.3, 0.3]:
		var wheel := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.07
		tm.outer_radius = 0.13
		tm.rings = 14
		tm.ring_segments = 6
		wheel.mesh = _coloured(tm, BRASS)
		wheel.position = Vector3(u, 0.08, 0)
		wheel.rotation.x = PI * 0.5
		_carriage.add_child(wheel)
	var frame := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 0.12, 0.1)
	frame.mesh = _coloured(bm, TIMBER)
	frame.position = Vector3(0, -0.05, 0.12)
	_carriage.add_child(frame)
	var hanger := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.025
	rod.bottom_radius = 0.025
	rod.height = HANG - 0.45
	rod.radial_segments = 6
	rod.rings = 1
	hanger.mesh = _coloured(rod, TIMBER)
	hanger.position = Vector3(0, -0.05 - rod.height * 0.5, 0.12)
	_carriage.add_child(hanger)
	_pivot.position = Vector3(0, -HANG + 0.4, 0.12)
	_carriage.add_child(_pivot)
	var bucket := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.34
	bc.bottom_radius = 0.27
	bc.height = 0.6
	bc.radial_segments = 16
	bc.rings = 1
	bc.cap_top = false
	bc.material = copper
	bucket.mesh = bc
	bucket.position = Vector3(0, -0.35, 0)
	_pivot.add_child(bucket)
	var bail := MeshInstance3D.new()
	var tm2 := TorusMesh.new()
	tm2.inner_radius = 0.34
	tm2.outer_radius = 0.37
	tm2.rings = 20
	tm2.ring_segments = 4
	bail.mesh = _coloured(tm2, BRASS)
	bail.position = Vector3(0, -0.05, 0)
	_pivot.add_child(bail)
	_bucket_water = MeshInstance3D.new()
	var wc := CylinderMesh.new()
	wc.top_radius = 0.31
	wc.bottom_radius = 0.31
	wc.height = 0.02
	wc.radial_segments = 16
	wc.rings = 1
	wc.material = _water_mat
	_bucket_water.mesh = wc
	_pivot.add_child(_bucket_water)


func _note(at: Vector3, size: Vector3, lift: float) -> HoverNote:
	var n := HoverNote.new(at, size, "", lift)
	add_child(n)
	return n


## ---- sound ------------------------------------------------------------------------

func _sound(key: String, path: String, loop: bool, at: Vector3, parent: Node3D, unit := 5.0) -> void:
	var p := AudioStreamPlayer3D.new()
	if DisplayServer.get_name() != "headless":
		var stream := load(path) as AudioStreamWAV
		if loop:
			stream = stream.duplicate() as AudioStreamWAV
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
			p.autoplay = true
			p.volume_db = -80.0
		p.stream = stream
	p.unit_size = unit
	p.position = at
	parent.add_child(p)
	_sounds[key] = p


func _build_sounds() -> void:
	_sound("roll", "res://audio/cart_roll_loop.wav", true, Vector3(0, 0.1, 0), _carriage, 5.0)
	_sound("drums", "res://audio/cart_roll_loop.wav", true, (_drums["green"] as Node3D).position, self, 5.0)
	_sound("pour_a", "res://audio/river_loop.wav", true, _a_ground + Vector3(0, 2.0, 0), self, 4.0)
	_sound("pour_b", "res://audio/river_loop.wav", true, _b_ground + Vector3(0, 1.5, 0), self, 4.0)
	for colour: String in ["green", "red"]:
		_sound("spin_" + colour, "res://audio/radiometer_whir_loop.wav", true, (_frames[colour] as Dictionary)["hub"], self, 6.0)
	_sound("chime", "res://audio/chime.wav", false, _b_ground + _side_b * 8.0 - _d_b * 7.5 + Vector3(0, 1.0, 0), self, 6.0)
	_sound("clank", "res://audio/clank_1.wav", false, Vector3(0, -0.5, 0), _carriage, 6.0)


static func _loud(p: AudioStreamPlayer3D, level: float, top_db := 0.0) -> void:
	p.volume_db = linear_to_db(clampf(level, 0.0001, 1.0)) + top_db


static func _play(p: AudioStreamPlayer3D, pitch := 1.0) -> void:
	if p.stream != null:
		p.pitch_scale = pitch
		p.play()


## ---- each step ----------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	var aurora := island.aurora.strength if island.aurora != null else 0.0
	# The comb's catch.
	for colour: String in ["green", "red"]:
		fleece[colour] = minf(BASKET, float(fleece[colour]) + float(CATCH[colour]) * aurora * dt)
	# The spinners.
	for colour: String in ["green", "red"]:
		var can := int(spools[colour]) < RACK and float(fleece[colour]) > 0.01 and water > 0.001
		spinning[colour] = can
		if not can:
			continue
		var rate := dt / SPOOL_TIME
		progress[colour] = float(progress[colour]) + rate
		fleece[colour] = maxf(0.0, float(fleece[colour]) - FLEECE_PER_SPOOL * rate)
		water = maxf(0.0, water - WATER_PER_SPOOL * rate)
		if float(progress[colour]) >= 1.0:
			progress[colour] = 0.0
			spools[colour] = int(spools[colour]) + 1
			_play(_sounds["chime"], 0.8 if colour == "red" else 1.0)
	# The line.
	match stage:
		Stage.FILLING:
			load = minf(1.0, load + dt / FILL_TIME)
			if load >= 1.0:
				stage = Stage.TO_B
		Stage.TO_B:
			if _haul(_length, "green", dt):
				stage = Stage.EMPTYING
				_play(_sounds["clank"])
		Stage.EMPTYING:
			_tip = minf(1.0, _tip + dt / 0.8)
			if _tip >= 1.0:
				var poured := minf(load, dt / EMPTY_TIME)
				load -= poured
				water = minf(1.0, water + WATER_PER_LOAD * poured)
				if load <= 0.0:
					load = 0.0
					stage = Stage.TO_A
		Stage.TO_A:
			_tip = maxf(0.0, _tip - dt / 0.8)
			if _tip <= 0.0 and _haul(0.0, "red", dt):
				stage = Stage.FILLING
				_play(_sounds["clank"])
	if stage != Stage.EMPTYING and stage != Stage.TO_A:
		_tip = maxf(0.0, _tip - dt / 0.8)
	_save_left -= dt
	if _save_left <= 0.0:
		_save_left = 5.0
		_save()


## The carriage hauled toward `to` by the drum of `colour`, slowing to
## arrive; cable spent from the drum, the drum loaded from the store when
## it runs out; nothing moves without cable. Whether it has arrived.
func _haul(to: float, colour: String, dt: float) -> bool:
	var left := to - along
	if float(drum[colour]) <= 0.0 and int(spools[colour]) > 0:
		spools[colour] = int(spools[colour]) - 1
		drum[colour] = SPOOL_METRES
	var wanted := signf(left) * minf(SPEED, sqrt(2.0 * ACCEL * absf(left)) + 0.2)
	if float(drum[colour]) <= 0.0:
		wanted = 0.0
	speed = move_toward(speed, wanted, ACCEL * dt * 1.5)
	var step := speed * dt
	if absf(step) >= absf(left):
		step = left
	along += step
	_drum_turn += step
	drum[colour] = maxf(0.0, float(drum[colour]) - absf(step))
	if absf(to - along) < 0.01:
		along = to
		speed = 0.0
		return true
	return false


func _process(delta: float) -> void:
	_clock += delta
	_place_carriage()
	# Water at the spring and into the cistern.
	var filling := stage == Stage.FILLING and load < 1.0
	_pour_a.visible = filling
	var pouring := stage == Stage.EMPTYING and _tip >= 1.0 and load > 0.0
	_pour_b.visible = pouring
	if pouring:
		var lip := _pivot.to_global(Vector3(0, -0.05, 0.34))
		_aim_stream(_pour_b, lip, _b_ground + Vector3(lip.x - _b_ground.x, 0.25 + 0.6 * water, lip.z - _b_ground.z))
	_cistern_water.position = _b_ground + Vector3(0, 0.05 + 0.85 * water, 0)
	_cistern_water.visible = water > 0.01
	# The drums turn with the cable, the bull wheel too; the haul cable
	# glows in the colour at work.
	for colour: String in ["green", "red"]:
		var d := _drums[colour] as Node3D
		var hauling := (stage == Stage.TO_B and colour == "green") or (stage == Stage.TO_A and colour == "red")
		if hauling:
			d.rotate_object_local(Vector3.FORWARD, speed * delta / 0.5)
		var full := clampf(float(drum[colour]) / SPOOL_METRES, 0.0, 1.0)
		d.scale = Vector3(0.6 + 0.4 * full, 0.6 + 0.4 * full, 1.0)
	_bull_wheel.rotate_y(speed * delta / 0.62)
	for s in _sheaves:
		s.rotate_object_local(Vector3.FORWARD, speed * delta / 0.2)
	var work := 0.0
	if stage == Stage.TO_B:
		_haul_mat.emission = COLOURS["green"]
		work = absf(speed) / SPEED
	elif stage == Stage.TO_A:
		_haul_mat.emission = COLOURS["red"]
		work = absf(speed) / SPEED
	_haul_mat.emission_energy_multiplier = 0.15 + 1.2 * work
	_track_mat.emission_energy_multiplier = 0.7 + 0.15 * sin(_clock * 1.3)
	# The fleece in the baskets, the spools spinning and in the store.
	for colour: String in ["green", "red"]:
		var puff := _puffs[colour] as MeshInstance3D
		var f := clampf(float(fleece[colour]) / BASKET, 0.0, 1.0)
		puff.visible = f > 0.01
		puff.scale = Vector3.ONE * (0.3 + 0.7 * f)
		var frame: Dictionary = _frames[colour]
		var spin: bool = spinning[colour]
		if spin:
			(frame["wheel"] as Node3D).rotate_object_local(Vector3.RIGHT, delta * 1.6)
			(frame["bobbin"] as Node3D).rotate_object_local(Vector3.RIGHT, delta * 9.0)
		var r := 0.08 + 0.18 * float(progress[colour])
		(frame["core"] as MeshInstance3D).scale = Vector3(1.0, 1.0, 1.0) * 1.0
		(frame["bobbin"] as Node3D).scale = Vector3(1.0, r, r)
		var row: Array = _rack[colour]
		for i in row.size():
			(row[i] as Node3D).visible = i < int(spools[colour])
	_sounds_now()
	_draw_threads()
	_note_left -= delta
	if _note_left <= 0.0:
		_note_left = 0.5
		_write_notes()


## The carriage at its place on the cable, turned along it; the bucket
## tipped as far as it is, its water as high as it is full.
func _place_carriage() -> void:
	var here: Array = _rope_at(along)
	var dir := _flat(here[1] as Vector3)
	if dir == Vector3.ZERO:
		dir = _d_b
	_carriage.global_transform = Transform3D(Basis(dir, Vector3.UP, dir.cross(Vector3.UP).normalized()), here[0])
	_pivot.rotation.x = -smoothstep(0.0, 1.0, _tip) * 1.9
	_bucket_water.visible = load > 0.02
	_bucket_water.position = Vector3(0, -0.62 + 0.5 * load, 0)


func _sounds_now() -> void:
	if not _sounds.has("roll"):
		return
	var pace := absf(speed) / SPEED
	var roll := _sounds["roll"] as AudioStreamPlayer3D
	_loud(roll, pace, -2.0)
	roll.pitch_scale = 0.7 + 0.7 * pace
	var drums := _sounds["drums"] as AudioStreamPlayer3D
	_loud(drums, pace, -4.0)
	drums.pitch_scale = 0.45 + 0.35 * pace
	_loud(_sounds["pour_a"], 1.0 if _pour_a.visible else 0.0, -6.0)
	_loud(_sounds["pour_b"], 1.0 if _pour_b.visible else 0.0, -4.0)
	for colour: String in ["green", "red"]:
		var p := _sounds["spin_" + colour] as AudioStreamPlayer3D
		_loud(p, 1.0 if spinning[colour] else 0.0, -8.0)
		p.pitch_scale = 0.4


## The glowing threads: the aurora's down to the comb's tines while it
## catches, down the mast to each basket, and the yarn from each basket
## over its frame's wheel to the spool.
func _draw_threads() -> void:
	_glow.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := cam.global_position
	var points := PackedVector3Array()
	var colours := PackedColorArray()
	var aurora := island.aurora.strength if island.aurora != null else 0.0
	if aurora > 0.01 and not island.aurora.low_points.is_empty():
		var lows: Array[Vector3] = island.aurora.low_points
		for k in 6:
			var sky := lows[(k * 3) % lows.size()]
			var red := k % 3 == 2
			if red:
				sky += Vector3(0, 320.0, 0)
			var tine := _tines[(k * 5 + 2) % _tines.size()]
			var colour: Color = COLOURS["red" if red else "green"]
			var path: Array[Vector3] = []
			for i in 25:
				var t := i / 24.0
				var bend := sky.lerp(tine, t)
				bend.y += sin(t * PI) * 40.0
				path.append(bend)
			var widths: Array[float] = []
			var shades: Array[Color] = []
			for i in 25:
				var t := i / 24.0
				widths.append(lerpf(3.0, 0.08, pow(t, 0.4)))
				var pulse := pow(fposmod(t * 5.0 - _clock * 0.4 + k * 0.17, 1.0), 6.0)
				shades.append(colour * aurora * (0.18 + 0.8 * pulse) * (1.0 - 0.5 * (1.0 - t)))
			_ribbon(points, colours, path, widths, shades, eye)
		for colour: String in ["green", "red"]:
			var foot: Vector3 = _baskets[colour]
			var c: Color = COLOURS[colour]
			_ribbon(points, colours, [_comb, foot + Vector3(0, 0.8, 0)] as Array[Vector3], [0.05, 0.05] as Array[float],
					[c * aurora * 0.5, c * aurora * 0.5] as Array[Color], eye)
	for colour: String in ["green", "red"]:
		if not spinning[colour]:
			continue
		var frame: Dictionary = _frames[colour]
		var c: Color = COLOURS[colour]
		var hub: Vector3 = frame["hub"]
		var path: Array[Vector3] = [(_baskets[colour] as Vector3) + Vector3(0, 0.9, 0), hub + Vector3(0, 2.0, 0),
				(frame["bobbin"] as Node3D).global_position]
		_ribbon(points, colours, path, [0.025, 0.025, 0.025] as Array[float], [c * 0.6, c * 0.6, c * 0.6] as Array[Color], eye)
	if points.is_empty():
		return
	_glow.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _glow_mat)
	for i in points.size():
		_glow.surface_set_color(colours[i])
		_glow.surface_add_vertex(points[i])
	_glow.surface_end()


## A ribbon along `path`, turned to the eye, `widths` and `shades` at each
## point.
static func _ribbon(points: PackedVector3Array, colours: PackedColorArray, path: Array[Vector3],
		widths: Array[float], shades: Array[Color], eye: Vector3) -> void:
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var cross := (b - a).cross(eye - a)
		if cross.length_squared() < 1e-8:
			continue
		var side_a := cross.normalized() * widths[i] * 0.5
		var side_b := cross.normalized() * widths[i + 1] * 0.5
		points.append_array([a - side_a, a + side_a, b + side_b, a - side_a, b + side_b, b - side_b])
		colours.append_array([shades[i], shades[i], shades[i + 1], shades[i], shades[i + 1], shades[i + 1]])


## What the notes over the parts say now. Drafts.
func _write_notes() -> void:
	var stage_text: String = ["filling at the spring", "full, on its way north to the cistern",
			"emptying into the cistern", "empty, on its way back south to the spring"][stage]
	(_notes["spring"] as HoverNote).set_text("The spring\nFills the ropeway's copper bucket. Its water crosses the island north, to the spinners.\nThe bucket is %s." % stage_text)
	(_notes["cistern"] as HoverNote).set_text("The cistern\nWater carried from the spring in the south, %d%% full. The spinners wet the aurora's fleece with it." % roundi(water * 100.0))
	var waiting := ""
	if (stage == Stage.TO_B and float(drum["green"]) <= 0.0) or (stage == Stage.TO_A and float(drum["red"]) <= 0.0):
		waiting = "\nWaiting for cable: the store has no spool of the colour wanted."
	(_notes["drive"] as HoverNote).set_text("The drive house\nGreen aurora cable pulls the bucket home here when it comes full; red cable pushes it back out empty. On the drums: green %d m, red %d m.%s" % [roundi(float(drum["green"])), roundi(float(drum["red"])), waiting])
	var night := "Catching now." if island.aurora != null and island.aurora.strength > 0.05 else "It catches only on dark nights, when the aurora shows in the north."
	(_notes["comb"] as HoverNote).set_text("The aurora comb\nCatches the northern lights as fleece: green from the curtains' lower edge, red from their tops. %s\nIn the baskets: green %.1f, red %.1f." % [night, float(fleece["green"]), float(fleece["red"])])
	for colour: String in ["green", "red"]:
		var doing := "Spinning." if spinning[colour] else ("Idle: no fleece." if float(fleece[colour]) <= 0.01 else ("Idle: the store is full." if int(spools[colour]) >= RACK else "Idle: no water."))
		(_notes["frame_" + colour] as HoverNote).set_text("Spinning frame, %s\nTwists %s fleece, wetted from the cistern, into %s cable and winds it on a spool. %s This spool: %d%%." % [colour, colour, "pull" if colour == "green" else "push", doing, roundi(float(progress[colour]) * 100.0)])
	(_notes["store"] as HoverNote).set_text("The spool store\nGreen pull cable: %d spools. Red push cable: %d spools." % [int(spools["green"]), int(spools["red"])])


## ---- keeping it ---------------------------------------------------------------------

func _save() -> void:
	if MouseMode.probe:
		return
	var data := {"fleece": fleece, "spools": spools, "drum": drum, "progress": progress, "water": water,
			"stage": stage, "along": along, "load": load}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var d := parsed as Dictionary
	for key: String in ["fleece", "spools", "drum", "progress"]:
		var v: Variant = d.get(key)
		if v is Dictionary:
			var target: Dictionary = get(key)
			for colour: String in ["green", "red"]:
				if (v as Dictionary).has(colour):
					target[colour] = (v as Dictionary)[colour]
	spools["green"] = int(spools["green"])
	spools["red"] = int(spools["red"])
	water = clampf(float(d.get("water", water)), 0.0, 1.0)
	stage = [Stage.FILLING, Stage.TO_B, Stage.EMPTYING, Stage.TO_A][clampi(int(d.get("stage", 0)), 0, 3)]
	along = clampf(float(d.get("along", along)), 0.0, _length)
	load = clampf(float(d.get("load", load)), 0.0, 1.0)
	if stage == Stage.EMPTYING:
		_tip = 1.0
