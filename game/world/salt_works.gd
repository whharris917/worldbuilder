class_name SaltWorks
extends Node3D
## A seaside salt works on the cozy island's east beach, run by a circuit
## of light beams: a demonstration of ladder logic (the way machine
## controllers are programmed) made of lanterns, crystals, hourglasses
## and radiometers, in old-fashioned materials.
##
## The process. A windmill on the grass turns a long shaft down the beach
## to a bucket chain standing in the sea; the buckets tip seawater into a
## wooden channel on trestles, which runs into a cistern. A pipe with a
## valve lets the cistern into an iron pan on a brick furnace; bellows
## and the chimney damper make the fire roar. The water boils off as
## steam and leaves a crust of salt; a rake pushes it into a bin, a bell
## rings and a counter adds one batch. A hand crank turns the shaft when
## there is no wind; a lever stops and starts the fire.
##
## The circuit (LumenPart, LumenBeam). Inputs are lanterns whose shutters
## open while something holds; outputs are radiometers that drive the
## machines. In ladder terms:
##   turning   = TOF 5 s ( TON 2 s ( windmill fast ) ) OR crank turning
##   PUMP      = turning AND NOT cistern full
##   BOIL      = latch: set by pan full, reset by pan dry
##   FILL      = NOT BOIL AND cistern has water AND NOT salt in pan
##   FIRE      = BOIL AND run lever
##   RAKE      = salt in pan AND TON 4 s ( NOT BOIL )
##   BELL      = rising edge of RAKE
##   COUNT     = falling edge of BOIL
## The on-delay keeps gusts from starting the pump, the off-delay keeps
## lulls from stopping it; the cooling delay lets the pan cool before the
## rake goes in.
##
## The simulation is scaled for watching: a batch takes about a minute,
## the salt is about five times as thick as a real pan's.
##
## Laid out in the site's own frame: u along the shore (toward the dock),
## v inland from the waterline, y absolute height. The site stands at
## BEARING round the island.

const BEARING := -15.0                  # degrees round from +x toward +z
const CISTERN_M3 := 7.2
const PAN_M3 := 0.96
const PUMP_FLOW := 0.07                 # m3/s at full speed
const VALVE_FLOW := 0.12
const BOIL_RATE := 0.03                 # m3/s at full fire
const SALT_PER_M3 := 35.0               # kg of salt in a cubic metre of seawater

var island: CozyIsland
var parts: Array[LumenPart] = []
var beams: Array[LumenBeam] = []

var _site := Node3D.new()
var _dir := Vector3.ZERO
var _in := Vector3.ZERO
var _along := Vector3.ZERO
var _origin := Vector3.ZERO
var _wind_noise := FastNoiseLite.new()
var _clock := 0.0

# machine state
var _sail_speed := 0.0                  # rad/s
var _sail_angle := 0.0
var _crank_speed := 0.0
var _shaft_angle := 0.0
var _noria := 0.0                       # 0 to 1
var _noria_s := 0.0
var _cistern := CISTERN_M3 * 0.35
var _valve := 0.0
var _pan := 0.0
var _fire := 0.12
var _temp := 20.0
var _salt_pan := 0.0                    # kg
var _salt_bin := 0.0
var _rake := 0.0
var _batches := 0
var _bell_swing := 0.0
var _was_bell := false
var _was_count := false
var _pump_flow := 0.0
var _fill_flow := 0.0

# inputs, logic and outputs
var _s_wind: LumenPart
var _s_crank: LumenPart
var _s_cfull: LumenPart
var _s_cwater: LumenPart
var _s_pfull: LumenPart
var _s_pdry: LumenPart
var _s_salt: LumenPart
var _s_run: LumenPart
var _r_pump: LumenPart
var _r_fill: LumenPart
var _r_fire: LumenPart
var _r_rake: LumenPart
var _r_bell: LumenPart
var _r_count: LumenPart

# moving pieces
var _sails: Node3D
var _governor: Node3D
var _gov_arms: Array[Node3D] = []
var _shaft: MeshInstance3D
var _shaft_from := Vector3.ZERO
var _shaft_to := Vector3.ZERO
var _buckets: Array[Node3D] = []
var _bucket_water: Array[MeshInstance3D] = []
var _flume_water: MeshInstance3D
var _flume_fall: MeshInstance3D
var _cistern_water: MeshInstance3D
var _float_rod: Node3D
var _valve_wheel: Node3D
var _spout_fall: MeshInstance3D
var _pan_water: MeshInstance3D
var _salt_layer: MeshInstance3D
var _salt_heap: MeshInstance3D
var _rake_blade: Node3D
var _steam: GPUParticles3D
var _fire_node: Campfire
var _bellows: Node3D
var _damper: Node3D
var _needle: Node3D
var _bell: Node3D
var _hammer: Node3D
var _digits: Array[Label3D] = []
var _clutch: Node3D
var _crank: WorksHandle
var _lever: WorksHandle
var _bell_sound: AudioStreamPlayer3D
var _water_sound: AudioStreamPlayer3D

var _wood: StandardMaterial3D
var _plank: StandardMaterial3D
var _stone: StandardMaterial3D
var _brick: StandardMaterial3D
var _iron: StandardMaterial3D
var _brass: StandardMaterial3D
var _canvas: StandardMaterial3D
var _roof: StandardMaterial3D
var _salt_mat: StandardMaterial3D
var _water_mat: StandardMaterial3D
var _tank_wood: StandardMaterial3D


func _init(owner_island: CozyIsland) -> void:
	name = "SaltWorks"
	island = owner_island
	var a := deg_to_rad(BEARING)
	_dir = Vector3(cos(a), 0.0, sin(a))
	_in = -_dir
	_along = Vector3(-_dir.z, 0.0, _dir.x)
	_origin = _dir * island.coast(a, 0.0)
	_site.basis = Basis(_along, Vector3.UP, _in)
	_site.position = Vector3(_origin.x, 0.0, _origin.z)
	_wind_noise.seed = 77
	_wind_noise.frequency = 1.0


## Where the site's middle is, for keeping trees off it.
static func centre(owner_island: CozyIsland) -> Vector3:
	var a := deg_to_rad(BEARING)
	var d := Vector3(cos(a), 0.0, sin(a))
	var o := d * owner_island.coast(a, 0.0)
	var along := Vector3(-d.z, 0.0, d.x)
	return o + along * -2.0 - d * 6.0


func _ready() -> void:
	add_child(_site)
	_materials()
	_build_windmill()
	_build_shaft()
	_build_noria()
	_build_flume()
	_build_cistern()
	_build_pipe()
	_build_furnace()
	_build_rake_and_bin()
	_build_bell()
	_build_circuit()
	for b in beams:
		b.place()


## ---- the site's frame ------------------------------------------------------

## A point of the site: u along the shore, v inland, y absolute.
func at(u: float, v: float, y: float) -> Vector3:
	return Vector3(u, y, v)


## Ground height at (u, v).
func ground(u: float, v: float) -> float:
	var p := _origin + _along * u + _in * v
	return island.height(p.x, p.z)


func _materials() -> void:
	_wood = island.surface("wood_floor", 0.6, Color(0.6, 0.5, 0.4), 0.85, Color(0.78, 0.6, 0.42))
	_plank = island.surface("wood_floor", 0.8, Color(0.45, 0.37, 0.3), 0.85, Color(0.66, 0.48, 0.34))
	_stone = island.surface("old_stone_bricks", 1.0 / 1.8, Color(0.85, 0.85, 0.85), 0.9, Color(0.72, 0.68, 0.64))
	_brick = island.surface("red_bricks", 0.9, Color(0.85, 0.8, 0.78), 0.9, Color(0.82, 0.46, 0.36))
	_iron = island.surface("", 1.0, Color(0.11, 0.11, 0.12), 0.45, Color(0.3, 0.3, 0.37))
	_iron.metallic = 0.6
	_brass = island.surface("", 1.0, Color(0.62, 0.46, 0.2), 0.35, Color(0.9, 0.7, 0.32))
	_brass.metallic = 0.85
	_canvas = island.surface("", 1.0, Color(0.82, 0.78, 0.7), 0.9, Color(0.98, 0.95, 0.86))
	_canvas.cull_mode = BaseMaterial3D.CULL_DISABLED
	_roof = island.surface("", 1.0, Color(0.32, 0.13, 0.1), 0.75, Color(0.86, 0.42, 0.33))
	_salt_mat = island.surface("", 1.0, Color(0.93, 0.93, 0.9), 0.9, Color(1.0, 1.0, 1.0))
	_tank_wood = island.surface("wood_floor", 0.6, Color(0.55, 0.46, 0.36), 0.85, Color(0.74, 0.56, 0.4))
	_tank_wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	_water_mat = StandardMaterial3D.new()
	_water_mat.albedo_color = Color(0.18, 0.4, 0.42)
	_water_mat.roughness = 0.08
	_water_mat.normal_enabled = true
	_water_mat.normal_texture = island.sea_ripples()
	_water_mat.uv1_triplanar = true
	_water_mat.uv1_world_triplanar = true
	_water_mat.uv1_scale = Vector3.ONE * 0.6


## ---- building helpers ------------------------------------------------------

func _box(size: Vector3, pos: Vector3, mat: Material, collide := false, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	return _put(mesh, pos, collide, size, parent)


func _cyl(top: float, bottom: float, height: float, pos: Vector3, mat: Material,
		segments := 12, collide := false, parent: Node3D = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	mesh.material = mat
	var view := _put(mesh, pos, false, Vector3.ZERO, parent)
	if collide:
		var body := StaticBody3D.new()
		body.position = pos
		var shape := CylinderShape3D.new()
		shape.radius = maxf(top, bottom)
		shape.height = height
		var c := CollisionShape3D.new()
		c.shape = shape
		body.add_child(c)
		(parent if parent != null else _site).add_child(body)
	return view


func _put(mesh: Mesh, pos: Vector3, collide: bool, size: Vector3, parent: Node3D) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = pos
	var into := parent if parent != null else _site
	into.add_child(view)
	if collide:
		var body := StaticBody3D.new()
		body.position = pos
		var shape := BoxShape3D.new()
		shape.size = size
		var c := CollisionShape3D.new()
		c.shape = shape
		body.add_child(c)
		into.add_child(body)
	return view


## A rod or timber of `radius` from a to b (site coordinates).
func _rod(a: Vector3, b: Vector3, radius: float, mat: Material, segments := 8, parent: Node3D = null) -> MeshInstance3D:
	var view := _cyl(radius, radius, a.distance_to(b), (a + b) * 0.5, mat, segments, false, parent)
	view.basis = _aligned(b - a)
	return view


## A basis whose y runs along `dir`.
static func _aligned(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


## ---- the windmill ----------------------------------------------------------

const MILL_U := -9.0
const MILL_V := 15.0
const HUB_Y := 7.0                       # above the mill's ground


func _build_windmill() -> void:
	var g := ground(MILL_U, MILL_V)
	_cyl(1.9, 2.0, 1.2, at(MILL_U, MILL_V, g + 0.3), _stone, 10, true)
	_cyl(1.05, 1.6, 6.4, at(MILL_U, MILL_V, g + 0.9 + 3.2), _plank, 8, true)
	_cyl(0.15, 1.3, 1.5, at(MILL_U, MILL_V, g + 7.3 + 0.75), _roof, 8)
	var door := _box(Vector3(0.9, 1.7, 0.1), at(MILL_U, MILL_V + 1.62, g + 1.75), _iron)
	door.rotation.x = -0.08
	# The sails face the sea, turning about an axle along v.
	var hub := at(MILL_U, MILL_V - 1.45, g + HUB_Y)
	_rod(at(MILL_U, MILL_V, g + HUB_Y), hub, 0.12, _iron)
	_sails = Node3D.new()
	_sails.position = hub
	_site.add_child(_sails)
	_cyl(0.25, 0.25, 0.3, Vector3.ZERO, _iron, 12, false, _sails).rotation.x = PI * 0.5
	for k in 4:
		var arm := Node3D.new()
		arm.rotation.z = TAU * k / 4.0
		_sails.add_child(arm)
		_box(Vector3(0.14, 5.6, 0.12), Vector3(0, 2.8, 0), _wood, false, arm)
		_box(Vector3(1.15, 4.2, 0.03), Vector3(0.62, 3.2, 0.04), _canvas, false, arm)
		for r in 6:
			_box(Vector3(1.3, 0.05, 0.05), Vector3(0.6, 1.2 + r * 0.8, 0.0), _wood, false, arm)
	# The governor: two iron balls on arms swinging out as it spins.
	_governor = Node3D.new()
	_governor.position = at(MILL_U + 1.3, MILL_V - 1.6, g + 0.9)
	_site.add_child(_governor)
	_cyl(0.03, 0.03, 0.9, Vector3(0, 0.45, 0), _iron, 8, false, _governor)
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 0.9, 0)
		pivot.rotation.y = 0.0 if side > 0.0 else PI
		_governor.add_child(pivot)
		var arm := Node3D.new()
		pivot.add_child(arm)
		_cyl(0.015, 0.015, 0.4, Vector3(0, -0.2, 0), _iron, 6, false, arm)
		var ball := SphereMesh.new()
		ball.radius = 0.07
		ball.height = 0.14
		ball.material = _brass
		_put(ball, Vector3(0, -0.42, 0), false, Vector3.ZERO, arm)
		_gov_arms.append(arm)


## ---- the line shaft and the hand crank ------------------------------------

func _shaft_y(v: float) -> float:
	var t := inverse_lerp(MILL_V - 1.6, -3.6, v)
	return lerpf(ground(MILL_U, MILL_V) + 2.6, 2.7, t)


func _build_shaft() -> void:
	_shaft_from = at(MILL_U, MILL_V - 1.6, _shaft_y(MILL_V - 1.6))
	_shaft_to = at(MILL_U, -3.6, _shaft_y(-3.6))
	_shaft = _rod(_shaft_from, _shaft_to, 0.06, _iron, 6)
	# Trestles with bearing blocks.
	for v: float in [10.5, 6.5, 2.5, -1.2]:
		var y := _shaft_y(v)
		var g := ground(MILL_U, v)
		for side: float in [-0.5, 0.5]:
			_rod(at(MILL_U + side, v, g - 0.2), at(MILL_U + side * 0.15, v, y - 0.05), 0.06, _wood)
		_box(Vector3(0.45, 0.12, 0.18), at(MILL_U, v, y - 0.05), _wood)
	_clutch = Node3D.new()
	_clutch.position = at(MILL_U, -3.0, _shaft_y(-3.0))
	_site.add_child(_clutch)
	_cyl(0.11, 0.11, 0.18, Vector3.ZERO, _brass, 12, false, _clutch).basis = _aligned(_shaft_to - _shaft_from)
	# The crank on its post, its chain up to the shaft.
	var cv := 0.8
	var g := ground(MILL_U - 1.2, cv)
	_box(Vector3(0.2, 1.1, 0.2), at(MILL_U - 1.2, cv, g + 0.45), _wood, true)
	_crank = WorksHandle.new(WorksHandle.Kind.CRANK, at(MILL_U - 1.42, cv, g + 1.05), _wood, _iron,
			"Hand crank\nHold E to turn the shaft when the wind is too light.")
	_site.add_child(_crank)
	_rod(at(MILL_U - 1.42, cv, g + 1.05), at(MILL_U, cv, _shaft_y(cv)), 0.015, _iron, 4)


## ---- the bucket chain ------------------------------------------------------

const NORIA_V := -4.5
const NORIA_TOP := 4.4
const NORIA_BOTTOM := -0.25
const NORIA_R := 0.35
const BUCKETS := 16


func _build_noria() -> void:
	var g := ground(MILL_U, NORIA_V)
	_rod(at(MILL_U - 0.45, NORIA_V, g - 0.3), at(MILL_U - 0.45, NORIA_V, NORIA_TOP + 0.4), 0.08, _wood)
	_rod(at(MILL_U + 0.45, NORIA_V, g - 0.3), at(MILL_U + 0.45, NORIA_V, 3.85), 0.08, _wood)
	for y: float in [0.8, 2.2, 3.5]:
		_box(Vector3(0.9, 0.08, 0.08), at(MILL_U, NORIA_V + 0.5, y), _wood)
	_rod(at(MILL_U - 0.55, NORIA_V, NORIA_TOP), at(MILL_U + 0.3, NORIA_V, NORIA_TOP), 0.04, _iron)
	for y: float in [NORIA_TOP, NORIA_BOTTOM]:
		_cyl(NORIA_R, NORIA_R, 0.08, at(MILL_U, NORIA_V, y), _iron, 14).rotation.z = PI * 0.5
	for dv: float in [-NORIA_R, NORIA_R]:
		_rod(at(MILL_U, NORIA_V + dv, NORIA_BOTTOM), at(MILL_U, NORIA_V + dv, NORIA_TOP), 0.012, _iron, 4)
	# The belt from the shaft's end up to the top wheel.
	for du: float in [-0.08, 0.08]:
		_rod(at(MILL_U + du, -3.6, _shaft_y(-3.6) + 0.12), at(MILL_U + du, NORIA_V + 0.3, NORIA_TOP + 0.3), 0.012, _plank, 4)
	var bucket := BoxMesh.new()
	bucket.size = Vector3(0.3, 0.2, 0.18)
	bucket.material = _plank
	var water := BoxMesh.new()
	water.size = Vector3(0.26, 0.04, 0.14)
	water.material = _water_mat
	for i in BUCKETS:
		var b := Node3D.new()
		_site.add_child(b)
		_put(bucket, Vector3(0, 0.1, 0), false, Vector3.ZERO, b)
		var w := _put(water, Vector3(0, 0.18, 0), false, Vector3.ZERO, b)
		_buckets.append(b)
		_bucket_water.append(w)
	_place_buckets()


## The chain's loop: up the seaward side, over the top, down the inland
## side, under the bottom. Each bucket's open top faces the way it moves,
## so it scoops at the bottom, rises full and tips over at the top.
func _place_buckets() -> void:
	var straight := NORIA_TOP - NORIA_BOTTOM
	var arc := PI * NORIA_R
	var loop := 2.0 * straight + 2.0 * arc
	for i in BUCKETS:
		var s := fposmod(_noria_s + loop * i / BUCKETS, loop)
		var p: Vector2                   # (v, y)
		var t: Vector2                   # the way it moves
		if s < straight:
			p = Vector2(NORIA_V - NORIA_R, NORIA_BOTTOM + s)
			t = Vector2(0, 1)
		elif s < straight + arc:
			var a := PI - (s - straight) / NORIA_R
			p = Vector2(NORIA_V + cos(a) * NORIA_R, NORIA_TOP + sin(a) * NORIA_R)
			t = Vector2(sin(a), -cos(a))
		elif s < 2.0 * straight + arc:
			p = Vector2(NORIA_V + NORIA_R, NORIA_TOP - (s - straight - arc))
			t = Vector2(0, -1)
		else:
			var a := -(s - 2.0 * straight - arc) / NORIA_R
			p = Vector2(NORIA_V + cos(a) * NORIA_R, NORIA_BOTTOM + sin(a) * NORIA_R)
			t = Vector2(-sin(a), cos(a))
		var b := _buckets[i]
		b.position = at(MILL_U, p.x, p.y)
		var up := Vector3(0, t.y, t.x)
		b.basis = Basis(Vector3.RIGHT, up, Vector3.RIGHT.cross(up))
		_bucket_water[i].visible = s < straight and _noria > 0.05 and p.y > 0.05


## ---- the channel and the cistern ------------------------------------------

const CIST_U := -4.0
const CIST_V := 3.0
const TANK_BASE := 1.2
const TANK_H := 1.6
const TANK_R := 1.2


func _build_flume() -> void:
	var a := at(MILL_U, NORIA_V, 4.0)
	var b := at(CIST_U - 0.3, CIST_V - 0.3, TANK_BASE + TANK_H + 0.3)
	var flume := Node3D.new()
	var dir := b - a
	var length := dir.length()
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	flume.position = (a + b) * 0.5
	flume.basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	_site.add_child(flume)
	_box(Vector3(0.44, 0.04, length), Vector3(0, -0.12, 0), _plank, false, flume)
	for side: float in [-0.22, 0.22]:
		_box(Vector3(0.04, 0.26, length), Vector3(side, 0, 0), _plank, false, flume)
	_flume_water = _box(Vector3(0.38, 0.06, length), Vector3(0, -0.07, 0), _water_mat, false, flume)
	_box(Vector3(0.6, 0.3, 0.6), a + Vector3(0, 0.02, 0), _plank)
	for t: float in [0.3, 0.65]:
		var p := a.lerp(b, t)
		var g := ground(p.x, p.z)
		var side := flat.cross(Vector3.UP) * 0.5
		_rod(Vector3(p.x, g - 0.2, p.z) + side, p - Vector3(0, 0.14, 0), 0.05, _wood)
		_rod(Vector3(p.x, g - 0.2, p.z) - side, p - Vector3(0, 0.14, 0), 0.05, _wood)
	_flume_fall = _cyl(0.07, 0.07, 1.0, Vector3.ZERO, _water_mat, 8)
	_flume_fall.position = b + Vector3(0, -0.3, 0)
	_water_sound = AudioStreamPlayer3D.new()
	_water_sound.stream = _sound("res://audio/river_loop.wav", true)
	_water_sound.position = (a + b) * 0.5
	_water_sound.unit_size = 4.0
	_water_sound.volume_db = -80.0
	_water_sound.autoplay = true
	_site.add_child(_water_sound)


func _build_cistern() -> void:
	var g := ground(CIST_U, CIST_V)
	_cyl(1.35, 1.4, TANK_BASE - g + 0.3, at(CIST_U, CIST_V, (TANK_BASE + g - 0.3) * 0.5), _stone, 14, true)
	var tank := CylinderMesh.new()
	tank.top_radius = TANK_R
	tank.bottom_radius = TANK_R
	tank.height = TANK_H
	tank.cap_top = false
	tank.radial_segments = 20
	tank.material = _tank_wood
	_put(tank, at(CIST_U, CIST_V, TANK_BASE + TANK_H * 0.5), true, Vector3(TANK_R * 1.8, TANK_H, TANK_R * 1.8), null)
	for y: float in [TANK_BASE + 0.3, TANK_BASE + TANK_H - 0.25]:
		_cyl(TANK_R + 0.02, TANK_R + 0.02, 0.06, at(CIST_U, CIST_V, y), _iron, 20)
	_cistern_water = _cyl(TANK_R - 0.03, TANK_R - 0.03, 1.0, Vector3.ZERO, _water_mat, 20)
	# The float: a ball on the water, its rod up through a guide with a
	# pointer against a board.
	_float_rod = Node3D.new()
	_site.add_child(_float_rod)
	var ball := SphereMesh.new()
	ball.radius = 0.12
	ball.height = 0.24
	ball.material = _brass
	_put(ball, Vector3.ZERO, false, Vector3.ZERO, _float_rod)
	_cyl(0.015, 0.015, 1.8, Vector3(0, 0.9, 0), _iron, 6, false, _float_rod)
	_box(Vector3(0.25, 0.03, 0.03), Vector3(0.12, 1.8, 0), _brass, false, _float_rod)
	_box(Vector3(0.05, 1.7, 0.3), at(CIST_U + 0.62, CIST_V + 0.75, TANK_BASE + TANK_H + 0.9), _plank)


## ---- the pipe and valve, the furnace and pan ------------------------------

const PAN_U := 2.2
const PAN_V := 3.0
const PAN_L := 2.4                      # along u
const PAN_W := 1.6
const PAN_DEPTH := 0.26
const FURNACE_TOP := 1.25


func _build_pipe() -> void:
	var y := 1.72
	_rod(at(CIST_U + TANK_R - 0.05, CIST_V, y), at(PAN_U - PAN_L * 0.5 + 0.15, CIST_V, y), 0.06, _iron)
	_cyl(0.07, 0.07, 0.12, at(PAN_U - PAN_L * 0.5 + 0.15, CIST_V, y - 0.06), _iron, 10)
	_valve_wheel = Node3D.new()
	_valve_wheel.position = at(-1.2, CIST_V, y + 0.28)
	_site.add_child(_valve_wheel)
	var wheel := TorusMesh.new()
	wheel.inner_radius = 0.13
	wheel.outer_radius = 0.16
	wheel.material = _iron
	_put(wheel, Vector3.ZERO, false, Vector3.ZERO, _valve_wheel)
	for k in 3:
		_box(Vector3(0.28, 0.02, 0.02), Vector3.ZERO, _iron, false, _valve_wheel).rotation.y = PI * k / 3.0
	_cyl(0.02, 0.02, 0.28, at(-1.2, CIST_V, y + 0.14), _iron, 6)
	_box(Vector3(0.18, 0.16, 0.16), at(-1.2, CIST_V, y), _brass)
	_spout_fall = _cyl(0.035, 0.035, 1.0, Vector3.ZERO, _water_mat, 8)


func _build_furnace() -> void:
	var g := ground(PAN_U, PAN_V)
	var u0 := PAN_U - PAN_L * 0.5 - 0.2
	var u1 := PAN_U + PAN_L * 0.5 + 0.2
	var v0 := PAN_V - PAN_W * 0.5 - 0.2
	var v1 := PAN_V + PAN_W * 0.5 + 0.2
	var h := FURNACE_TOP - (g - 0.2)
	var mid_y := (FURNACE_TOP + g - 0.2) * 0.5
	_box(Vector3(u1 - u0, h, 0.25), at(PAN_U, v0 + 0.125, mid_y), _brick, true)
	_box(Vector3(0.25, h, v1 - v0), at(u0 + 0.125, PAN_V, mid_y), _brick, true)
	_box(Vector3(0.25, h, v1 - v0), at(u1 - 0.125, PAN_V, mid_y), _brick, true)
	# The front, with the fire's mouth in the middle.
	var mouth := 0.8
	var side_w := (u1 - u0 - mouth) * 0.5
	_box(Vector3(side_w, h, 0.25), at(u0 + side_w * 0.5, v1 - 0.125, mid_y), _brick, true)
	_box(Vector3(side_w, h, 0.25), at(u1 - side_w * 0.5, v1 - 0.125, mid_y), _brick, true)
	_box(Vector3(mouth, 0.4, 0.25), at(PAN_U, v1 - 0.125, FURNACE_TOP - 0.2), _brick)
	# The pan: an iron tray on the walls.
	var bottom := FURNACE_TOP + 0.02
	_box(Vector3(PAN_L + 0.08, 0.04, PAN_W + 0.08), at(PAN_U, PAN_V, bottom), _iron, true)
	for dv: float in [-1.0, 1.0]:
		_box(Vector3(PAN_L + 0.08, PAN_DEPTH + 0.04, 0.04), at(PAN_U, PAN_V + dv * (PAN_W * 0.5 + 0.02), bottom + PAN_DEPTH * 0.5), _iron)
	_box(Vector3(0.04, PAN_DEPTH + 0.04, PAN_W), at(PAN_U - PAN_L * 0.5 - 0.02, PAN_V, bottom + PAN_DEPTH * 0.5), _iron)
	_pan_water = _box(Vector3(PAN_L, 1.0, PAN_W), Vector3.ZERO, _water_mat)
	_salt_layer = _box(Vector3(1.0, 1.0, PAN_W - 0.04), Vector3.ZERO, _salt_mat)
	# The chimney with its damper arm.
	_box(Vector3(0.6, 5.2, 0.6), at(u1 - 0.3, v0 - 0.3, g + 2.4), _brick, true)
	_damper = Node3D.new()
	_damper.position = at(u1 + 0.02, v0 - 0.3, g + 3.2)
	_site.add_child(_damper)
	_box(Vector3(0.04, 0.04, 0.55), Vector3(0, 0, 0.25), _iron, false, _damper)
	# The fire inside, and the bellows at the side.
	_fire_node = Campfire.new()
	_fire_node.position = at(PAN_U, PAN_V + 0.3, g)
	# Inside a furnace the smoke goes up the chimney and the embers stay in.
	(_fire_node.get_node("Smoke") as Node3D).visible = false
	(_fire_node.get_node("Embers") as Node3D).visible = false
	_site.add_child(_fire_node)
	_bellows = Node3D.new()
	_bellows.position = at(u0 - 0.35, PAN_V - 0.4, g + 0.45)
	_site.add_child(_bellows)
	_box(Vector3(0.5, 0.04, 0.35), Vector3(0, 0.15, 0), _wood, false, _bellows)
	_box(Vector3(0.5, 0.04, 0.35), Vector3(0, -0.15, 0), _wood, false, _bellows)
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.3, 0.18, 0.1)
	_box(Vector3(0.44, 0.3, 0.3), Vector3.ZERO, leather, false, _bellows)
	_rod(at(u0 - 0.1, PAN_V - 0.4, g + 0.45), at(u0 + 0.02, PAN_V - 0.4, g + 0.45), 0.03, _iron)
	_box(Vector3(0.3, 0.8, 0.3), at(u0 - 0.35, PAN_V - 0.4, g - 0.1), _wood)
	# The thermometer: a dial on the front, its needle by the pan's heat.
	var dial_at := at(u1 - 0.55, v1 + 0.02, g + 0.75)
	var face := _cyl(0.2, 0.2, 0.03, dial_at, _brass, 20)
	face.rotation.x = PI * 0.5
	var enamel := StandardMaterial3D.new()
	enamel.albedo_color = Color(0.93, 0.9, 0.82)
	_cyl(0.17, 0.17, 0.01, dial_at + Vector3(0, 0, 0.02), enamel, 20).rotation.x = PI * 0.5
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.7, 0.08, 0.05)
	# 100 degrees is straight up; the dial reads 0 to 200.
	_box(Vector3(0.012, 0.04, 0.005), dial_at + Vector3(0, 0.14, 0.03), red)
	_needle = Node3D.new()
	_needle.position = dial_at + Vector3(0, 0, 0.035)
	_site.add_child(_needle)
	_box(Vector3(0.012, 0.15, 0.006), Vector3(0, 0.06, 0), _iron, false, _needle)
	# Steam off the pan.
	_steam = _steam_particles()
	_steam.position = at(PAN_U, PAN_V, bottom + PAN_DEPTH)
	_site.add_child(_steam)


func _steam_particles() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(PAN_L * 0.45, 0.02, PAN_W * 0.45)
	process.direction = Vector3.UP
	process.spread = 15.0
	process.initial_velocity_min = 0.4
	process.initial_velocity_max = 0.8
	process.gravity = Vector3(0.3, 0.4, 0.0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.5
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	process.color_ramp = ramp_tex
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(1.0, 1.8))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	process.scale_curve = curve_tex
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	var dot := GradientTexture2D.new()
	dot.width = 64
	dot.height = 64
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	dot.gradient = fade
	mat.albedo_texture = dot
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	quad.material = mat
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 3.0
	p.process_material = process
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 6, 6))
	p.emitting = false
	return p


## ---- the rake, the bin, the counter and the bell --------------------------

const BIN_U := 4.25


func _build_rake_and_bin() -> void:
	var g := ground(BIN_U, PAN_V)
	var rail_y := FURNACE_TOP + PAN_DEPTH + 0.1
	for dv: float in [-1.0, 1.0]:
		_rod(at(PAN_U - PAN_L * 0.5, PAN_V + dv * (PAN_W * 0.5 + 0.08), rail_y),
				at(BIN_U + 0.5, PAN_V + dv * (PAN_W * 0.5 + 0.08), rail_y), 0.02, _iron, 6)
	_rake_blade = Node3D.new()
	_site.add_child(_rake_blade)
	_box(Vector3(0.06, 0.06, PAN_W + 0.3), Vector3(0, 0.0, 0), _wood, false, _rake_blade)
	_box(Vector3(0.03, PAN_DEPTH, PAN_W - 0.06), Vector3(0, -PAN_DEPTH * 0.5, 0), _wood, false, _rake_blade)
	# The bin past the pan's open end, the salt heaping in it.
	var bin_top := FURNACE_TOP - 0.15
	var wall_h := bin_top - (g - 0.1)
	var mid := (bin_top + g - 0.1) * 0.5
	_box(Vector3(1.0, 0.05, PAN_W), at(BIN_U, PAN_V, g + 0.05), _plank)
	for dv: float in [-1.0, 1.0]:
		_box(Vector3(1.0, wall_h, 0.05), at(BIN_U, PAN_V + dv * PAN_W * 0.5, mid), _plank, true)
	_box(Vector3(0.05, wall_h, PAN_W), at(BIN_U + 0.5, PAN_V, mid), _plank, true)
	var heap := SphereMesh.new()
	heap.radius = 1.0
	heap.height = 2.0
	heap.material = _salt_mat
	_salt_heap = _put(heap, at(BIN_U, PAN_V, g + 0.08), false, Vector3.ZERO, null)
	_salt_heap.scale = Vector3.ONE * 0.001
	# The batch counter: three numbered wheels in a brass case on the
	# bin's front.
	var case_at := at(BIN_U, PAN_V + PAN_W * 0.5 + 0.06, g + 0.6)
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
		var drum := StandardMaterial3D.new()
		drum.albedo_color = Color(0.93, 0.9, 0.8)
		_box(Vector3(0.1, 0.13, 0.01), digit.position - Vector3(0, 0, 0.006), drum)
		_digits.append(digit)


func _build_bell() -> void:
	var u := BIN_U + 1.4
	var v := PAN_V - 0.8
	var g := ground(u, v)
	for du: float in [-0.4, 0.4]:
		_box(Vector3(0.1, 2.2, 0.1), at(u + du, v, g + 1.0), _wood)
	_box(Vector3(1.0, 0.1, 0.12), at(u, v, g + 2.1), _wood)
	_bell = Node3D.new()
	_bell.position = at(u, v, g + 2.05)
	_site.add_child(_bell)
	_cyl(0.06, 0.18, 0.3, Vector3(0, -0.2, 0), _brass, 16, false, _bell)
	_hammer = Node3D.new()
	_hammer.position = at(u + 0.35, v, g + 1.7)
	_site.add_child(_hammer)
	_box(Vector3(0.02, 0.02, 0.3), Vector3(-0.15, 0, 0), _iron, false, _hammer).rotation.y = PI * 0.5
	_box(Vector3(0.08, 0.06, 0.06), Vector3(-0.3, 0, 0), _iron, false, _hammer)
	_bell_sound = AudioStreamPlayer3D.new()
	_bell_sound.stream = _sound("res://audio/bell_2.wav", false)
	_bell_sound.pitch_scale = 1.8
	_bell_sound.unit_size = 6.0
	_bell_sound.position = _bell.position
	_site.add_child(_bell_sound)


## A sound, looped if asked; none when headless (nothing would hear it,
## and a loop left playing holds its file at exit).
func _sound(path: String, loop: bool) -> AudioStreamWAV:
	if DisplayServer.get_name() == "headless":
		return null
	var stream := load(path) as AudioStreamWAV
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream


## ---- the circuit -----------------------------------------------------------

func _part(kind: LumenPart.Kind, title: String, u: float, v: float, y: float, delay := 0.0) -> LumenPart:
	var p := LumenPart.new(kind, title, at(u, v, y), ground(u, v), _wood, _brass, delay)
	_site.add_child(p)
	parts.append(p)
	return p


func _wire(from: LumenPart, to: LumenPart) -> void:
	var b := LumenBeam.new(from, to, from.colour())
	add_child(b)
	to.inputs.append(b)
	beams.append(b)


func _build_circuit() -> void:
	var gm := ground(MILL_U, MILL_V)
	# Inputs.
	_s_wind = _part(LumenPart.Kind.LANTERN, "the windmill turns fast", MILL_U + 1.6, MILL_V - 2.2, gm + 2.3)
	_s_crank = _part(LumenPart.Kind.LANTERN, "the crank is turning", MILL_U - 1.8, 1.7, ground(MILL_U - 1.8, 1.7) + 2.1)
	_s_cfull = _part(LumenPart.Kind.LANTERN, "the cistern is full", CIST_U - 1.5, CIST_V + 1.3, 3.5)
	_s_cwater = _part(LumenPart.Kind.LANTERN, "the cistern has water", CIST_U - 1.5, CIST_V + 1.3, 3.05)
	_s_pfull = _part(LumenPart.Kind.LANTERN, "the pan is full", -0.2, 4.6, 2.75)
	_s_pdry = _part(LumenPart.Kind.LANTERN, "the pan is dry", -0.2, 4.6, 2.3)
	_s_salt = _part(LumenPart.Kind.LANTERN, "there is salt in the pan", 3.2, 4.6, 2.6)
	_s_run = _part(LumenPart.Kind.LANTERN, "the run lever is on", -0.4, 7.8, ground(-0.4, 7.8) + 2.2)
	# Logic.
	var ton_wind := _part(LumenPart.Kind.TON, "steady wind", MILL_U + 1.5, 10.5, 3.6, 2.0)
	var tof_wind := _part(LumenPart.Kind.TOF, "wind, lulls bridged", MILL_U + 1.5, 8.0, 3.4, 5.0)
	var or_turn := _part(LumenPart.Kind.OR, "the shaft is turning", MILL_U - 1.6, 4.5, 3.1)
	var not_cfull := _part(LumenPart.Kind.NOT, "the cistern has room", -6.0, 6.5, 3.4)
	var and_pump := _part(LumenPart.Kind.AND, "pump", MILL_U - 1.0, 2.6, 3.3)
	var latch := _part(LumenPart.Kind.LATCH, "boiling", 0.5, 9.5, 3.2)
	var not_boil := _part(LumenPart.Kind.NOT, "not boiling", -1.5, 9.0, 3.2)
	var not_salt := _part(LumenPart.Kind.NOT, "the pan is clean", 3.0, 7.2, 3.1)
	var and_fill := _part(LumenPart.Kind.AND, "fill the pan", -1.6, 5.8, 3.0)
	var and_fire := _part(LumenPart.Kind.AND, "stoke the fire", 1.8, 6.6, 3.0)
	var ton_cool := _part(LumenPart.Kind.TON, "the pan has cooled", 2.8, 10.0, 3.2, 4.0)
	var and_rake := _part(LumenPart.Kind.AND, "rake the salt", 4.6, 6.8, 3.0)
	var rise_rake := _part(LumenPart.Kind.RISE, "raking begins", 6.2, 6.2, 3.0)
	var fall_boil := _part(LumenPart.Kind.FALL, "a batch is boiled", 4.6, 9.8, 3.2)
	# Outputs.
	_r_pump = _part(LumenPart.Kind.RADIOMETER, "engages the bucket chain's clutch", MILL_U + 1.1, -3.0, 3.0)
	_r_fill = _part(LumenPart.Kind.RADIOMETER, "opens the valve to the pan", -1.2, 3.75, 2.55)
	_r_fire = _part(LumenPart.Kind.RADIOMETER, "works the bellows and opens the damper", 0.0, 2.2, 2.0)
	_r_rake = _part(LumenPart.Kind.RADIOMETER, "drives the rake", 4.6, 4.3, 2.4)
	_r_bell = _part(LumenPart.Kind.RADIOMETER, "strikes the bell", BIN_U + 1.4, 1.4, 2.6)
	_r_count = _part(LumenPart.Kind.RADIOMETER, "advances the batch counter", 5.3, 4.8, 2.0)

	_wire(_s_wind, ton_wind)
	_wire(ton_wind, tof_wind)
	_wire(tof_wind, or_turn)
	_wire(_s_crank, or_turn)
	_wire(or_turn, and_pump)
	_wire(_s_cfull, not_cfull)
	_wire(not_cfull, and_pump)
	_wire(and_pump, _r_pump)
	_wire(_s_pfull, latch)                # set
	_wire(_s_pdry, latch)                 # reset
	_wire(latch, not_boil)
	_wire(not_boil, and_fill)
	_wire(_s_cwater, and_fill)
	_wire(_s_salt, not_salt)
	_wire(not_salt, and_fill)
	_wire(and_fill, _r_fill)
	_wire(latch, and_fire)
	_wire(_s_run, and_fire)
	_wire(and_fire, _r_fire)
	_wire(not_boil, ton_cool)
	_wire(_s_salt, and_rake)
	_wire(ton_cool, and_rake)
	_wire(and_rake, _r_rake)
	_wire(and_rake, rise_rake)
	_wire(rise_rake, _r_bell)
	_wire(latch, fall_boil)
	_wire(fall_boil, _r_count)
	# Lanterns face where their beams go.
	for b in beams:
		if b.source.kind == LumenPart.Kind.LANTERN:
			b.source.face(b.target.global_position)

	var gl := ground(-0.4, 7.0)
	_lever = WorksHandle.new(WorksHandle.Kind.LEVER, at(-0.4, 7.0, gl + 0.55), _wood, _iron,
			"Run lever\nE: start or stop the fire. The works fill and rake either way.")
	_site.add_child(_lever)


## ---- the simulation --------------------------------------------------------

func _physics_process(dt: float) -> void:
	_clock += dt
	# Wind: slow swells and calms; the sails follow with inertia.
	var wind := clampf(0.55 + 0.7 * _wind_noise.get_noise_1d(_clock * 0.025), 0.0, 1.0)
	var want := 2.2 * maxf(0.0, (wind - 0.25) / 0.75)
	_sail_speed = move_toward(_sail_speed, want, 0.35 * dt)
	_sail_angle += _sail_speed * dt
	var gov := _sail_speed / 2.2
	_s_wind.condition = gov > (0.3 if _s_wind.condition else 0.4)
	# The crank: turned while E is held on it.
	var holding := Input.is_action_pressed("interact") and island.player.look_view() == _crank
	_crank_speed = move_toward(_crank_speed, 1.0 if holding else 0.0, 2.0 * dt)
	_crank.turn(_crank_speed * 5.0 * dt)
	_s_crank.condition = _crank_speed > 0.5
	# The shaft takes the faster of the two (ratchets), the chain turns
	# with it while the clutch is in.
	var shaft := maxf(gov, _crank_speed)
	_shaft_angle += shaft * 6.0 * dt
	var clutch := _r_pump.spin > 0.5
	_noria = move_toward(_noria, shaft if clutch else 0.0, 1.5 * dt)
	_noria_s += _noria * 0.9 * dt
	_pump_flow = PUMP_FLOW * _noria
	_cistern = minf(_cistern + _pump_flow * dt, CISTERN_M3)
	var c_level := _cistern / CISTERN_M3
	_s_cfull.condition = c_level > (0.82 if _s_cfull.condition else 0.92)
	_s_cwater.condition = c_level > (0.06 if _s_cwater.condition else 0.12)
	# The valve, and the pan filling.
	_valve = move_toward(_valve, 1.0 if _r_fill.spin > 0.5 else 0.0, 0.8 * dt)
	_fill_flow = minf(VALVE_FLOW * _valve, _cistern / dt) if _pan < PAN_M3 else 0.0
	_cistern -= _fill_flow * dt
	_pan = minf(_pan + _fill_flow * dt, PAN_M3)
	# The fire: roaring with the bellows and damper, else smouldering.
	_fire = move_toward(_fire, 1.0 if _r_fire.spin > 0.5 else 0.12, 0.5 * dt)
	if _pan > 0.004:
		if _temp < 100.0:
			_temp += (_fire * 14.0 - (_temp - 20.0) * 0.02) * dt
		else:
			_temp = 100.0
			var boil := minf(_fire * BOIL_RATE * dt, _pan)
			_pan -= boil
			_salt_pan += boil * SALT_PER_M3
			if _fire < 0.2:
				_temp -= 0.5 * dt
	else:
		_temp += (_fire * 14.0 - (_temp - 20.0) * 0.05) * dt
	_temp = clampf(_temp, 15.0, 300.0)
	var p_level := _pan / PAN_M3
	_s_pfull.condition = p_level > (0.85 if _s_pfull.condition else 0.95)
	_s_pdry.condition = _pan < (0.02 if _s_pdry.condition else 0.004)
	_s_salt.condition = _salt_pan > (0.1 if _s_salt.condition else 0.5)
	# The rake pushes the salt off the pan's end into the bin.
	if _r_rake.spin > 0.5 and _rake < 1.0:
		_rake = minf(_rake + 0.35 * dt, 1.0)
		if _rake >= 1.0:
			_salt_bin += _salt_pan
			_salt_pan = 0.0
	elif _r_rake.spin <= 0.5:
		_rake = maxf(_rake - 0.5 * dt, 0.0)
	_s_run.condition = _lever.on
	# The bell and the counter, on the moment their light arrives.
	if _r_bell.powered and not _was_bell:
		_bell_swing = 1.0
		if _bell_sound.stream != null:
			_bell_sound.play()
	_was_bell = _r_bell.powered
	if _r_count.powered and not _was_count:
		_batches = (_batches + 1) % 1000
		for k in 3:
			_digits[k].text = str(_batches / int(pow(10, 2 - k)) % 10)
	_was_count = _r_count.powered
	# The circuit: every part reads the beams as they stand, then every
	# beam carries the new outputs on.
	for p in parts:
		p.evaluate(dt)
	for b in beams:
		b.step(dt)


func _process(delta: float) -> void:
	_sails.rotation.z = _sail_angle
	var gov := _sail_speed / 2.2
	_governor.rotation.y += gov * 8.0 * delta
	for arm in _gov_arms:
		arm.rotation.x = -(0.35 + 0.9 * gov)
	_shaft.basis = _aligned(_shaft_to - _shaft_from) * Basis(Vector3.UP, _shaft_angle)
	_clutch.position = at(MILL_U, -3.0 - (0.15 if _r_pump.spin > 0.5 else 0.0), _shaft_y(-3.0))
	_place_buckets()
	var flowing := _pump_flow > 0.002
	_flume_water.visible = flowing
	_flume_fall.visible = flowing
	if flowing:
		var top := TANK_BASE + TANK_H + 0.15
		var surface := TANK_BASE + TANK_H * _cistern / CISTERN_M3
		_flume_fall.position.y = (top + surface) * 0.5
		_flume_fall.scale = Vector3(1.0, maxf(top - surface, 0.05), 1.0)
	_water_sound.volume_db = linear_to_db(clampf(_pump_flow / PUMP_FLOW + _fill_flow / VALVE_FLOW * 0.6, 0.0001, 1.0)) - 6.0
	# The cistern's water and its float.
	var c_h := maxf(TANK_H * _cistern / CISTERN_M3, 0.01)
	_cistern_water.position = at(CIST_U, CIST_V, TANK_BASE + c_h * 0.5)
	_cistern_water.scale = Vector3(1.0, c_h, 1.0)
	_float_rod.position = at(CIST_U + 0.5, CIST_V + 0.5, TANK_BASE + c_h)
	_valve_wheel.rotation.y = _valve * TAU * 1.5
	# The pan: its water, the stream into it, its salt.
	var bottom := FURNACE_TOP + 0.04
	var w_h := maxf(PAN_DEPTH * _pan / PAN_M3, 0.002)
	_pan_water.visible = _pan > 0.004
	_pan_water.position = at(PAN_U, PAN_V, bottom + w_h * 0.5)
	_pan_water.scale = Vector3(1.0, w_h, 1.0)
	_spout_fall.visible = _fill_flow > 0.002
	if _spout_fall.visible:
		var su := PAN_U - PAN_L * 0.5 + 0.15
		var from := 1.66
		var to := bottom + w_h
		_spout_fall.position = at(su, CIST_V, (from + to) * 0.5)
		_spout_fall.scale = Vector3(1.0, from - to, 1.0)
	var u0 := PAN_U - PAN_L * 0.5 + 0.05 + _rake * (PAN_L - 0.1)
	var u1 := PAN_U + PAN_L * 0.5
	var salt_t := clampf(_salt_pan / (PAN_M3 * SALT_PER_M3) * 0.025, 0.0, 0.04) / maxf(1.0 - _rake, 0.25)
	_salt_layer.visible = _salt_pan > 0.05 and u1 - u0 > 0.02
	_salt_layer.position = at((u0 + u1) * 0.5, PAN_V, bottom + salt_t * 0.5)
	_salt_layer.scale = Vector3(maxf(u1 - u0, 0.01), maxf(salt_t, 0.002), 1.0)
	_rake_blade.position = at(u0 - 0.03, PAN_V, bottom + PAN_DEPTH + 0.06)
	var heap := pow(_salt_bin / 400.0, 1.0 / 3.0)
	_salt_heap.scale = Vector3(minf(heap * 0.9, 0.46), minf(heap * 0.5, 0.5), minf(heap * 0.9, 0.75)) + Vector3.ONE * 0.001
	# Fire, steam, bellows, damper, thermometer.
	_fire_node.set_level(_fire)
	_steam.emitting = _temp >= 99.0 and _pan > 0.004 and _fire > 0.3
	_steam.amount_ratio = clampf(_fire, 0.2, 1.0)
	var puff := 0.5 + 0.5 * sin(_clock * 5.0) if _fire > 0.5 else 0.6
	_bellows.scale = Vector3(1.0, lerpf(0.5, 1.0, puff), 1.0)
	_damper.rotation.y = lerpf(0.0, -1.2, (_fire - 0.12) / 0.88)
	_needle.rotation.z = -deg_to_rad((_temp - 100.0) * 1.2)
	# The bell swings and the hammer falls back.
	_bell_swing = maxf(_bell_swing - delta * 0.7, 0.0)
	_bell.rotation.z = sin(_clock * 9.0) * 0.25 * _bell_swing
	_hammer.rotation.z = 0.5 * _bell_swing * _bell_swing
