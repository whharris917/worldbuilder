class_name InnerBay
extends Node3D
## The sheltered bay in the cozy island's northern dunes: a round pool of
## calm, clear water open to the sea by one narrow inlet, with a wooden
## footbridge across the inlet. Small things live here: schools of
## minnows that dart off when someone comes near, crabs that walk
## sideways along the shore and run from feet, bury themselves if caught
## up to; eelgrass and shells on the sandy floor.
##
## The water is its own surface (the island's sea has a hole under it):
## see-through, its ripples slow and small, no surf. The creatures,
## grass, shells and bridge are built cozy-native (CozyMesh, flat vertex
## colours); the minnows are one MultiMesh whose fish the script places
## each frame, the crabs a body and two sets of legs each.
##
## Minnows: each school's centre wanders the bay on slow noise; its fish
## keep loose places about it, each flicking its tail; a player within
## 5 m sends the school darting away. Crabs: each walks the shore's edge
## at its own pace, pausing; within 3 m a player sends it scuttling off
## sideways, within 1.5 m it digs in and waits.

const SCHOOLS := 3
const PER_SCHOOL := 14
const CRABS := 9

var island: CozyIsland
var _clock := 0.0
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _water_mat: StandardMaterial3D
var _sheen_mat: StandardMaterial3D
var _fish: MultiMeshInstance3D
var _schools: Array = []                 # [position, velocity, phase]
var _fish_place: Array = []              # per fish: [school, radius, angle, depth, flick]
var _crabs: Array = []                   # [node, legs_left, legs_right, angle, radius, speed, pause, buried]


func _init(owner_island: CozyIsland) -> void:
	name = "InnerBay"
	island = owner_island
	_rng.seed = 5150
	_noise.seed = 77
	_noise.frequency = 1.0


func _ready() -> void:
	_build_water()
	_build_floor()
	_build_bridge()
	_build_minnows()
	_build_crabs()
	_build_sounds()


func _bay3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


## ---- the water and the floor -----------------------------------------------

func _build_water() -> void:
	# Clear water over sand: it absorbs the red end of the light more the
	# deeper it is, so the bed is seen through it tinted toward turquoise.
	# Drawn as a multiply over what lies beneath (a teal laid over sand by
	# ordinary blending would cancel to grey), white at the edge, deepening
	# with the depth under each point.
	_water_mat = StandardMaterial3D.new()
	_water_mat.vertex_color_use_as_albedo = true
	_water_mat.vertex_color_is_srgb = true
	_water_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_water_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var shallow := Color(1.0, 1.0, 1.0)
	var deep := Color(0.3, 0.74, 0.82)
	var size := CozyIsland.BAY_R + 4.0
	var n := 34
	var step := size * 2.0 / n
	var points := PackedVector3Array()
	var colours := PackedColorArray()
	for j in n + 1:
		for i in n + 1:
			var p := CozyIsland.BAY + Vector2(-size + i * step, -size + j * step)
			points.append(_bay3(p, 0.0))
			var depth := -island.height(p.x, p.y)
			colours.append(shallow.lerp(deep, smoothstep(0.0, 1.1, depth)))
	var index := PackedInt32Array()
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			var mid := CozyIsland.BAY + Vector2(-size + (i + 0.5) * step, -size + (j + 0.5) * step)
			if mid.distance_to(CozyIsland.BAY) > size:
				continue
			index.append_array([a, a + 1, a + n + 1, a + 1, a + n + 2, a + n + 1])
	var normals := PackedVector3Array()
	normals.resize(points.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _water_mat)
	# Over it, the surface itself: nearly clear, its slow ripples catching
	# the light and the sky.
	_sheen_mat = StandardMaterial3D.new()
	_sheen_mat.albedo_color = Color(0.8, 0.95, 0.95, 0.08)
	_sheen_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sheen_mat.roughness = 0.12
	_sheen_mat.metallic_specular = 0.5
	_sheen_mat.normal_enabled = true
	_sheen_mat.normal_texture = island.sea_ripples()
	_sheen_mat.normal_scale = 0.3
	_sheen_mat.uv1_triplanar = true
	_sheen_mat.uv1_world_triplanar = true
	_sheen_mat.uv1_scale = Vector3.ONE * 0.25
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_overlay = _sheen_mat
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)


## Eelgrass in patches and shells scattered on the sandy bed.
func _build_floor() -> void:
	var m := CozyMesh.new()
	var greens := [Color(0.3, 0.55, 0.32), Color(0.38, 0.62, 0.35), Color(0.26, 0.48, 0.3)]
	for patch in 9:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * (CozyIsland.BAY_R - 3.0)
		var c := CozyIsland.BAY + Vector2(cos(a), sin(a)) * r
		for k in 26:
			var p := c + Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.2, 1.2))
			var floor_y := island.height(p.x, p.y)
			if floor_y > -0.3:
				continue
			var tall := minf(_rng.randf_range(0.3, 0.7), -floor_y - 0.1)
			var lean := Basis(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized(), _rng.randf_range(0.05, 0.3))
			m.box(Vector3(0.03, tall, 0.005), CozyMesh.at(_bay3(p, floor_y + tall * 0.5), lean), greens[k % 3])
	var shell_colours := [Color(0.95, 0.88, 0.8), Color(0.98, 0.72, 0.62), Color(0.85, 0.8, 0.95)]
	for k in 40:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * (CozyIsland.BAY_R + 2.0)
		var p := CozyIsland.BAY + Vector2(cos(a), sin(a)) * r
		var y := island.height(p.x, p.y)
		m.ball(_rng.randf_range(0.04, 0.08), 8, CozyMesh.at(_bay3(p, y + 0.01), Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3(1.0, 0.35, 0.8))), shell_colours[k % 3], true)
	# A few starfish on the shallows.
	for k in 5:
		var a := _rng.randf() * TAU
		var p := CozyIsland.BAY + Vector2(cos(a), sin(a)) * _rng.randf_range(CozyIsland.BAY_R - 3.0, CozyIsland.BAY_R - 0.5)
		var y := island.height(p.x, p.y)
		for arm in 5:
			var b := TAU * arm / 5.0 + a
			m.cyl(0.012, 0.04, 0.2, 5, CozyMesh.at(_bay3(p, y + 0.02) + Vector3(cos(b), 0, sin(b)) * 0.09, Basis(Vector3(-sin(b), 0, cos(b)), PI * 0.5)), Color(0.95, 0.5, 0.3))
	var view := MeshInstance3D.new()
	view.name = "BayFloor"
	view.mesh = m.commit(island.cozy_material())
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)


## ---- the footbridge --------------------------------------------------------

func _build_bridge() -> void:
	var d := CozyIsland.INLET_DIR.normalized()
	var mid := CozyIsland.BAY + d * ((CozyIsland.INLET_FROM + CozyIsland.INLET_TO) * 0.5)
	var across := Vector2(-d.y, d.x)
	var a := mid - across * 5.5
	var b := mid + across * 5.5
	var ha := island.height(a.x, a.y)
	var hb := island.height(b.x, b.y)
	var deck := maxf(maxf(ha, hb), 0.4) + 0.35
	var m := CozyMesh.new()
	var wood := Color(0.74, 0.55, 0.38)
	var dark := Color(0.52, 0.37, 0.27)
	var span := a.distance_to(b)
	# Planks across the deck, a gentle arch in the middle.
	var steps := int(span / 0.3)
	for k in steps + 1:
		var t := float(k) / steps
		var p := a.lerp(b, t)
		var y := deck + 0.25 * sin(t * PI) - 0.03
		m.box(Vector3(0.26, 0.06, 1.6), CozyMesh.at(_bay3(p, y), Basis(Vector3.UP, atan2(-across.y, across.x))), wood if k % 2 == 0 else dark)
	for s: float in [-0.8, 0.8]:
		for k in 5:
			var t := float(k) / 4.0
			var p := a.lerp(b, t) + d * s
			var y := deck + 0.25 * sin(t * PI)
			m.rod(_bay3(p, y), _bay3(p, y + 0.85), 0.04, 8, dark)
			m.rod(_bay3(p, island.height(p.x, p.y) - 0.3), _bay3(p, y), 0.06, 8, dark)
		for k in 8:
			var t0 := float(k) / 8.0
			var t1 := float(k + 1) / 8.0
			var p0 := a.lerp(b, t0) + d * s
			var p1 := a.lerp(b, t1) + d * s
			m.rod(_bay3(p0, deck + 0.25 * sin(t0 * PI) + 0.85), _bay3(p1, deck + 0.25 * sin(t1 * PI) + 0.85), 0.035, 6, wood)
	var view := MeshInstance3D.new()
	view.name = "Footbridge"
	view.mesh = m.commit(island.cozy_material())
	add_child(view)
	# What the player walks on: two slopes up to the middle of the arch.
	var body := StaticBody3D.new()
	add_child(body)
	var top := _bay3(mid, deck + 0.25)
	for end: Vector2 in [a, b]:
		var low := _bay3(end, island.height(end.x, end.y) + 0.02)
		var run := top - low
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.6, 0.1, run.length())
		var c := CollisionShape3D.new()
		c.shape = shape
		var fwd := run.normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		c.transform = Transform3D(Basis(right, fwd.cross(right), -fwd).orthonormalized(), (low + top) * 0.5)
		body.add_child(c)
	# The shore's walls open here, running along its sides instead.
	island.piers.append([_bay3(a - across * 1.5, 0.0), _bay3(b + across * 1.5, 0.0), 0.8, false, true])
	add_child(HoverNote.new(top + Vector3(0, 0.6, 0), Vector3(1.6, 1.2, 3.0),
			"Footbridge\nOver the bay's one way to the sea."))


## ---- minnows ----------------------------------------------------------------

func _build_minnows() -> void:
	var m := CozyMesh.new()
	m.ball(0.05, 8, CozyMesh.at(Vector3.ZERO, Basis.from_scale(Vector3(0.45, 0.6, 1.6))), Color(0.72, 0.78, 0.8))
	m.box(Vector3(0.01, 0.06, 0.05), CozyMesh.at(Vector3(0, 0, 0.1)), Color(0.55, 0.62, 0.68))
	m.box(Vector3(0.02, 0.01, 0.07), CozyMesh.at(Vector3(0, 0.025, 0)), Color(0.4, 0.48, 0.52))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m.commit(island.cozy_material())
	mm.instance_count = SCHOOLS * PER_SCHOOL
	_fish = MultiMeshInstance3D.new()
	_fish.multimesh = mm
	_fish.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fish)
	for s in SCHOOLS:
		var a := TAU * s / SCHOOLS
		_schools.append([CozyIsland.BAY + Vector2(cos(a), sin(a)) * 5.0, Vector2.ZERO, s * 13.0])
		for k in PER_SCHOOL:
			_fish_place.append([s, _rng.randf_range(0.2, 0.9), _rng.randf() * TAU, _rng.randf_range(0.25, 0.55), _rng.randf() * TAU])


## ---- crabs -------------------------------------------------------------------

func _build_crabs() -> void:
	var shell := [Color(0.88, 0.38, 0.22), Color(0.8, 0.45, 0.25), Color(0.92, 0.55, 0.3)]
	for i in CRABS:
		var crab := Node3D.new()
		add_child(crab)
		var colour: Color = shell[i % 3]
		var body := CozyMesh.new()
		body.ball(0.09, 10, CozyMesh.at(Vector3(0, 0.07, 0), Basis.from_scale(Vector3(1.3, 0.55, 1.0))), colour)
		for s: float in [-1.0, 1.0]:
			body.ball(0.035, 8, CozyMesh.at(Vector3(s * 0.05, 0.11, -0.07)), Color(0.15, 0.12, 0.1))
			body.ball(0.045, 8, CozyMesh.at(Vector3(s * 0.15, 0.07, -0.1), Basis.from_scale(Vector3(1.0, 0.7, 1.3))), colour.darkened(0.1))
		_piece(body, crab)
		var legs: Array[Node3D] = []
		for s: float in [-1.0, 1.0]:
			var lm := CozyMesh.new()
			for k in 3:
				lm.rod(Vector3(s * 0.08, 0.06, -0.04 + k * 0.05), Vector3(s * 0.2, 0.0, -0.06 + k * 0.07), 0.012, 4, colour.darkened(0.25))
			var node := Node3D.new()
			crab.add_child(node)
			_piece(lm, node)
			legs.append(node)
		var angle := TAU * i / CRABS + _rng.randf_range(-0.2, 0.2)
		_crabs.append([crab, legs[0], legs[1], angle, CozyIsland.BAY_R + _rng.randf_range(-0.5, 1.8),
				_rng.randf_range(0.04, 0.09) * (1.0 if i % 2 == 0 else -1.0), _rng.randf_range(0.0, 3.0), 0.0])


func _piece(m: CozyMesh, parent: Node3D) -> void:
	var view := MeshInstance3D.new()
	view.mesh = m.commit(island.cozy_material())
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)


func _build_sounds() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var lap := AudioStreamPlayer3D.new()
	var stream := load("res://audio/river_loop.wav") as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	lap.stream = stream
	lap.volume_db = -16.0
	lap.unit_size = 3.0
	var d := CozyIsland.INLET_DIR.normalized()
	lap.position = _bay3(CozyIsland.BAY + d * (CozyIsland.INLET_FROM + 4.0), 0.1)
	lap.autoplay = true
	add_child(lap)


## ---- life ------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	_sheen_mat.uv1_offset = Vector3(_clock * 0.004, _clock * 0.003, 0.0)
	var cam := get_viewport().get_camera_3d()
	var who := Vector2(cam.global_position.x, cam.global_position.z) if cam != null else Vector2(9999, 9999)
	# The schools: each wanders, and darts off from a visitor.
	for s in SCHOOLS:
		var school: Array = _schools[s]
		var pos: Vector2 = school[0]
		var vel: Vector2 = school[1]
		var ph: float = school[2]
		var wander := Vector2(_noise.get_noise_2d(_clock * 0.08, ph), _noise.get_noise_2d(ph, _clock * 0.08)) * 1.2
		var home := (CozyIsland.BAY - pos) * 0.03
		var want := wander + home
		var away := pos - who
		if away.length() < 5.0:
			want += away.normalized() * 3.5
		vel = vel.lerp(want, 1.0 - exp(-2.0 * delta))
		pos += vel * delta
		if pos.distance_to(CozyIsland.BAY) > CozyIsland.BAY_R - 2.5:
			pos = CozyIsland.BAY + (pos - CozyIsland.BAY).normalized() * (CozyIsland.BAY_R - 2.5)
		school[0] = pos
		school[1] = vel
	var mm := _fish.multimesh
	for i in _fish_place.size():
		var f: Array = _fish_place[i]
		var school: Array = _schools[f[0]]
		var pos: Vector2 = school[0]
		var vel: Vector2 = school[1]
		var a := float(f[2]) + _clock * 0.4
		var p := pos + Vector2(cos(a), sin(a)) * float(f[1])
		var floor_y := island.height(p.x, p.y)
		var y := maxf(-float(f[3]), floor_y + 0.08)
		var heading := vel if vel.length() > 0.05 else Vector2(-sin(a), cos(a))
		var yaw := atan2(heading.x, heading.y) + 0.25 * sin(_clock * (8.0 + vel.length() * 10.0) + float(f[4]))
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw + PI), Vector3(p.x, y, p.y)))
	# The crabs: along the shore, off from feet, into the sand when close.
	for c: Array in _crabs:
		var crab := c[0] as Node3D
		var angle: float = c[3]
		var radius: float = c[4]
		var speed: float = c[5]
		var pause: float = c[6]
		var buried: float = c[7]
		var here := CozyIsland.BAY + Vector2(cos(angle), sin(angle)) * radius
		var near := here.distance_to(who)
		var moving := 0.0
		if near < 1.5:
			buried = 3.0
		elif buried > 0.0:
			buried -= delta
		elif near < 3.0:
			# Run along the shore, away from the visitor.
			var tangent := Vector2(-sin(angle), cos(angle))
			var dir := signf(tangent.dot(here - who))
			angle += dir * 0.35 * delta
			moving = 1.0
		else:
			pause -= delta
			if pause <= 0.0:
				angle += speed * delta
				moving = 0.4
				if pause < -_rng.randf_range(2.0, 5.0):
					pause = _rng.randf_range(1.0, 4.0)
		var floor_y := island.height(here.x, here.y)
		var sink := clampf(buried, 0.0, 1.0) * 0.12
		crab.position = Vector3(here.x, floor_y - sink, here.y)
		# Sideways: the crab faces the bay's middle and walks along the shore.
		crab.rotation.y = atan2(CozyIsland.BAY.x - here.x, CozyIsland.BAY.y - here.y) + PI
		var step := sin(_clock * 22.0 + angle * 10.0) * 0.35 * moving
		(c[1] as Node3D).rotation.x = step
		(c[2] as Node3D).rotation.x = -step
		c[3] = angle
		c[6] = pause
		c[7] = buried
