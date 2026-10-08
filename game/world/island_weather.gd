class_name IslandWeather
extends Node3D
## The cozy island's weather: separate clouds and showers carried across
## the sky on the wind, so one part of the sky can be raining while
## another is clear. Four kinds of cell:
## - Fair: a white heap of cumulus 260-360 m up, no rain; it dims the
##   sun as it crosses it.
## - Shower: a taller grey heap with a soft shaft of rain under it,
##   leaning downwind, blowing through quickly. Spawned upwind and
##   carried across; some cross the island, others pass by at sea. Under
##   it the rain falls round the player and patters, a gust runs ahead
##   of it, and the sun is dimmed.
## - Squall: a long dark line of storm cloud two to three kilometres out
##   with heavy rain under it, travelling round the horizon; lightning
##   flickers in it and its thunder arrives after the distance takes.
## - Mist: a low pale bank of sea fog on the horizon, drifting slowly.
## Rainbows: where a shower lies opposite the sun and the sun is shining
## on it, the bow stands at 42 degrees round the point opposite the sun,
## red outside, with a faint second bow at 51 degrees, colours reversed.
##
## Built from the engine's own parts: clouds are camera-facing puffs (one
## MultiMesh a cell), rain shafts see-through sheets with streaks slid
## down them, the rain round the player GPU particles, the bows a mesh
## drawn additively. Nothing here is a custom shader. Clouds ignore the
## environment's depth fog and fade toward the sky's haze colour by their
## own distance instead, so they can be seen kilometres out.

enum Kind { FAIR, SHOWER, SQUALL, MIST }

const SOUND := 343.0
const DOME := 3400.0                     # nothing beyond: inside the star dome

var island: CozyIsland
## Where the wind blows toward, and its speed (m/s).
var wind_dir := Vector2(-0.8, 0.6).normalized()
var wind_speed := 7.0
var fair := true
var showers := 0.5                       # 0 none to 1 often
var far_weather := true
var rainbows := true
## How much of the sun's light reaches the player past the clouds (1 all).
var sun_through := 1.0
## How hard it is raining where the player stands (0 to 1).
var rain_here := 0.0

var _cells: Array[Cell] = []
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _plan_left := 0.0
var _next_shower := 30.0
var _streaks: ImageTexture
var _puff: ImageTexture
var _rain: GPUParticles3D
var _rain_process: ParticleProcessMaterial
var _bow: MeshInstance3D
var _bow_mat: StandardMaterial3D
var _bow_left := 0.0
var _bolt: MeshInstance3D
var _bolt_mat: StandardMaterial3D
var _bolt_left := 0.0
var _thunders: Array = []                # [time, file, position, volume]
var _snd_rain: AudioStreamPlayer
var _snd_gust: AudioStreamPlayer
var _gust := 0.0


class Cell:
	var kind: int
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var axis := Vector2.RIGHT            # its long way
	var radius := 100.0
	var stretch := 1.0                   # along its axis
	var base := 250.0
	var top := 350.0
	var lean := Vector2.ZERO             # the rain's foot, downwind of the cloud
	var rain := 0.0                      # 0 none to 1 heavy
	var shade := 0.6                     # how much sun it stops at its middle
	var grey := 1.0
	var age := 0.0
	var span := 600.0                    # its life, s
	var fade := 0.0
	var leaving := false
	var retired := false                 # sent away: fades out where it is
	var node: Node3D
	var mat: StandardMaterial3D
	var curtain_mat: StandardMaterial3D
	var scroll := 0.0
	var next_flash := 5.0
	var flash := 0.0

	## Distance from a point to the cell's footprint, scaled so its edge
	## is 1 (its long way stretched).
	func reach(p: Vector2, foot: Vector2) -> float:
		var d := p - (pos + foot)
		var along := d.dot(axis) / stretch
		var across := d.dot(Vector2(-axis.y, axis.x))
		return sqrt(along * along + across * across) / radius


func _init(owner_island: CozyIsland) -> void:
	name = "Weather"
	island = owner_island
	_rng.seed = 4242


func _ready() -> void:
	_streaks = _streak_picture()
	_puff = BeachSite.cloud_puff()
	_build_rain()
	_build_bow()
	_build_bolt()
	_build_sound()
	# The sky starts with its fair clouds already about.
	for i in 9:
		_spawn(Kind.FAIR, true)


## ---- cells -------------------------------------------------------------------

## A new cell of `kind`: upwind and carried across, or (squalls, mist)
## far out and travelling round the horizon. `anywhere` scatters it over
## the sky (at the start).
func _spawn(kind: int, anywhere := false, at := Vector2.INF) -> Cell:
	var c := Cell.new()
	c.kind = kind
	var side := Vector2(-wind_dir.y, wind_dir.x)
	match kind:
		Kind.FAIR:
			c.radius = _rng.randf_range(100.0, 190.0)
			c.base = _rng.randf_range(380.0, 480.0)
			c.top = c.base + _rng.randf_range(80.0, 160.0)
			c.shade = 0.55
			c.grey = 1.08
			c.vel = wind_dir * wind_speed
			c.pos = -wind_dir * 1400.0 + side * _rng.randf_range(-1400.0, 1400.0)
			if anywhere:
				c.pos = Vector2(_rng.randf_range(-1400.0, 1400.0), _rng.randf_range(-1400.0, 1400.0))
		Kind.SHOWER:
			c.radius = _rng.randf_range(80.0, 140.0)
			c.base = _rng.randf_range(220.0, 270.0)
			c.top = c.base + _rng.randf_range(90.0, 150.0)
			c.rain = _rng.randf_range(0.45, 0.8)
			c.shade = 0.75
			c.grey = 0.8
			c.vel = wind_dir * wind_speed * 1.1
			# Half cross the island, the rest pass by out at sea.
			var off := _rng.randf_range(-180.0, 180.0) if _rng.randf() < 0.5 else _rng.randf_range(250.0, 900.0) * signf(_rng.randf() - 0.5)
			c.pos = -wind_dir * 1300.0 + side * off
		Kind.SQUALL:
			var b := _rng.randf() * TAU
			var dir := Vector2(cos(b), sin(b))
			c.pos = dir * _rng.randf_range(1800.0, 2400.0)
			c.vel = Vector2(-dir.y, dir.x) * _rng.randf_range(4.0, 6.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
			c.radius = _rng.randf_range(300.0, 420.0)
			c.stretch = 2.6
			c.base = 300.0
			c.top = c.base + _rng.randf_range(450.0, 750.0)
			c.rain = 1.0
			c.shade = 0.9
			c.grey = 0.42
			c.span = _rng.randf_range(360.0, 600.0)
		Kind.MIST:
			var b := _rng.randf() * TAU
			var dir := Vector2(cos(b), sin(b))
			c.pos = dir * _rng.randf_range(1300.0, 2100.0)
			c.vel = Vector2(-dir.y, dir.x) * _rng.randf_range(1.5, 2.5) * (1.0 if _rng.randf() < 0.5 else -1.0)
			c.radius = _rng.randf_range(260.0, 420.0)
			c.stretch = 2.5
			c.base = 0.0
			c.top = 70.0
			c.shade = 0.0
			c.grey = 0.96
			c.span = _rng.randf_range(420.0, 720.0)
	if at != Vector2.INF:
		c.pos = at
	c.axis = c.vel.normalized() if c.vel.length() > 0.01 else Vector2.RIGHT
	if c.rain > 0.0:
		# Rain falls at 6-9 m/s from the base and drifts with the wind on
		# the way down: its foot leans downwind.
		c.lean = wind_dir * c.base * (0.35 if kind == Kind.SHOWER else 0.2)
	c.age = 0.0
	if anywhere:
		c.fade = 1.0
	_build_cell(c)
	_cells.append(c)
	return c


func _build_cell(c: Cell) -> void:
	c.node = Node3D.new()
	c.node.top_level = true
	add_child(c.node)
	c.node.global_transform = Transform3D(Basis(Vector3.UP, atan2(-c.axis.y, c.axis.x)), Vector3(c.pos.x, 0.0, c.pos.y))
	c.mat = StandardMaterial3D.new()
	c.mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	c.mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	c.mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	c.mat.billboard_keep_scale = true
	c.mat.albedo_texture = _puff
	c.mat.disable_fog = true
	var quad := QuadMesh.new()
	quad.material = c.mat
	var count := 45
	var lo := 60.0
	var hi := 110.0
	var flat := 0.7
	match c.kind:
		Kind.SHOWER:
			count = 90
			lo = 50.0
			hi = 90.0
		Kind.SQUALL:
			count = 130
			lo = 150.0
			hi = 260.0
		Kind.MIST:
			count = 80
			lo = 120.0
			hi = 220.0
			flat = 0.3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = count
	for i in count:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf())
		var p := Vector3(cos(a) * r * c.radius * c.stretch, 0.0, sin(a) * r * c.radius)
		# Heaped: higher toward the middle, a flat base.
		p.y = c.base + (1.0 - r) * (c.top - c.base) * _rng.randf_range(0.4, 1.0) + _rng.randf() * 10.0
		var s := _rng.randf_range(lo, hi)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s * flat, s)), p))
	var heap := MultiMeshInstance3D.new()
	heap.multimesh = mm
	heap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var w := c.radius * c.stretch + hi
	heap.custom_aabb = AABB(Vector3(-w, c.base - hi, -c.radius - hi), Vector3(w * 2.0, c.top - c.base + hi * 2.0, (c.radius + hi) * 2.0))
	c.node.add_child(heap)
	if c.rain > 0.0:
		c.curtain_mat = StandardMaterial3D.new()
		c.curtain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		c.curtain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		c.curtain_mat.vertex_color_use_as_albedo = true
		c.curtain_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		c.curtain_mat.albedo_texture = _streaks
		c.curtain_mat.disable_fog = true
		c.curtain_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		var curtain := MeshInstance3D.new()
		curtain.mesh = _curtain(c)
		curtain.material_override = c.curtain_mat
		curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.node.add_child(curtain)


## The rain shaft: three nested sheets round the cloud's middle from its
## base down to the sea, their foot shifted downwind, see-through at the
## top and densest low down.
func _curtain(c: Cell) -> ArrayMesh:
	var foot := c.node.global_transform.basis.inverse() * Vector3(c.lean.x, 0.0, c.lean.y)
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colours := PackedColorArray()
	var index := PackedInt32Array()
	var segments := 40
	var rows := 6
	for sheet in 3:
		var share := 0.45 + 0.2 * sheet
		var strength := 1.0 - 0.3 * sheet
		var first := points.size()
		for row in rows + 1:
			var t := float(row) / rows        # 0 at the cloud, 1 at the sea
			var y := lerpf(c.base + 5.0, -2.0, t)
			var shift := foot * t
			var alpha := smoothstep(0.0, 0.3, t) * lerpf(1.0, 0.75, smoothstep(0.85, 1.0, t)) * strength
			for s in segments + 1:
				var a := TAU * s / segments
				var p := Vector3(cos(a) * c.radius * c.stretch * share, y, sin(a) * c.radius * share) + shift
				points.append(p)
				uvs.append(Vector2(float(s) / segments * c.radius * share * TAU / 30.0, (c.base - y) / 45.0))
				colours.append(Color(1, 1, 1, alpha))
		for row in rows:
			for s in segments:
				var i := first + row * (segments + 1) + s
				index.append_array([i, i + 1, i + segments + 1, i + 1, i + segments + 2, i + segments + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Vertical streaks over a thin veil, tiling: the rain seen from afar.
func _streak_picture() -> ImageTexture:
	var w := 64
	var h := 256
	var img := Image.create(w, h, true, Image.FORMAT_RGBA8)
	var veil := FastNoiseLite.new()
	veil.seed = 9
	veil.frequency = 0.08
	for y in h:
		for x in w:
			var v := 0.22 + 0.12 * veil.get_noise_2d(x * 3.0, y * 0.25)
			img.set_pixel(x, y, Color(1, 1, 1, v))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 70:
		var x := rng.randi() % w
		var y0 := rng.randi() % h
		var length := rng.randi_range(20, 90)
		var strength := rng.randf_range(0.25, 0.6)
		for j in length:
			var y := (y0 + j) % h
			var taper := sin(PI * j / length)
			var c := img.get_pixel(x, y)
			c.a = minf(c.a + strength * taper, 1.0)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## ---- rain round the player, the bow, the bolt ---------------------------------

func _build_rain() -> void:
	_rain_process = ParticleProcessMaterial.new()
	_rain_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_rain_process.emission_box_extents = Vector3(16, 1, 16)
	_rain_process.direction = Vector3.DOWN
	_rain_process.spread = 2.0
	_rain_process.initial_velocity_min = 5.5
	_rain_process.initial_velocity_max = 7.0
	_rain_process.gravity = Vector3.ZERO
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.85, 0.9, 1.0, 0.32)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	var streak := QuadMesh.new()
	streak.size = Vector2(0.018, 0.45)
	streak.material = mat
	_rain = GPUParticles3D.new()
	_rain.amount = 2400
	_rain.lifetime = 2.6
	_rain.process_material = _rain_process
	_rain.draw_pass_1 = streak
	_rain.top_level = true
	_rain.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 24, 40))
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.amount_ratio = 0.0
	add_child(_rain)


func _build_bow() -> void:
	_bow_mat = StandardMaterial3D.new()
	_bow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_bow_mat.vertex_color_use_as_albedo = true
	_bow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bow_mat.disable_fog = true
	_bow_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_bow = MeshInstance3D.new()
	_bow.top_level = true
	_bow.material_override = _bow_mat
	_bow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bow.visible = false
	add_child(_bow)


func _build_bolt() -> void:
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


func _build_sound() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_snd_rain = _loop("res://audio/rain_loop.wav")
	_snd_gust = _loop("res://audio/wind_loop.wav")


func _loop(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var stream := load(path) as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	p.stream = stream
	p.volume_db = -60.0
	p.autoplay = true
	add_child(p)
	return p


## ---- each frame --------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam != null else Vector3(0, 2, 0)
	var eye2 := Vector2(eye.x, eye.z)
	_plan_left -= delta
	if _plan_left <= 0.0:
		_plan_left = 1.0
		_plan(eye2)
	var sky := island.sky
	# The light shines along its -z: toward the sun is its +z.
	var to_sun := sky.sun.global_transform.basis.z
	var light := Color(1, 1, 1).lerp(sky.sun.light_color, 0.25) * lerpf(0.18, 1.0, sky.daylight)
	var through := 1.0
	var wet := 0.0
	var gust := 0.0
	var gone: Array[Cell] = []
	for c: Cell in _cells:
		c.age += delta
		c.pos += c.vel * delta
		c.node.global_position = Vector3(c.pos.x, 0.0, c.pos.y)
		# Fading in where it starts, out as it leaves or its life ends.
		var far := c.pos.length()
		if c.kind == Kind.FAIR or c.kind == Kind.SHOWER:
			c.leaving = c.retired or c.pos.dot(wind_dir) > 1300.0
		else:
			c.leaving = c.retired or c.age > c.span
		c.fade = clampf(c.fade + delta / 30.0 * (-1.0 if c.leaving else 1.0), 0.0, 1.0)
		if (c.leaving and c.fade <= 0.0) or far > DOME:
			gone.append(c)
			continue
		# Its colour: lit by the sun, greyer for rain, toward the sky's haze
		# with distance, a flash of lightning on top.
		var d := eye2.distance_to(c.pos)
		var haze := 1.0 - exp(-maxf(d - c.radius, 0.0) / 2600.0)
		var col := Color(c.grey, c.grey, c.grey * 1.03) * light
		col = col.lerp(sky.haze_colour * lerpf(0.25, 1.0, sky.daylight), haze * 0.7)
		col = col.lerp(Color(1.4, 1.4, 1.7), c.flash)
		col.a = (0.92 if c.kind != Kind.MIST else 0.75) * c.fade
		c.mat.albedo_color = col
		if c.curtain_mat != null:
			var rcol := Color(c.grey * 0.95, c.grey, c.grey * 1.08) * light
			rcol = rcol.lerp(sky.haze_colour * lerpf(0.25, 1.0, sky.daylight), haze * 0.6)
			rcol.a = (0.55 + 0.4 * c.rain) * c.fade
			c.curtain_mat.albedo_color = rcol
			c.scroll -= delta * (6.0 + 3.0 * c.rain) / 45.0
			c.curtain_mat.uv1_offset = Vector3(0.0, c.scroll, 0.0)
			# Rain where the player stands, and the gust running ahead.
			var at := c.reach(eye2, c.lean)
			wet = maxf(wet, c.rain * c.fade * smoothstep(0.7, 0.4, at))
			gust = maxf(gust, c.fade * smoothstep(1.8, 0.9, c.reach(eye2, c.lean - wind_dir * c.radius * 0.6)))
		# The sun hidden behind it: where the line to the sun crosses the
		# cloud's middle height.
		if c.shade > 0.0 and to_sun.y > 0.02:
			var h := lerpf(c.base, c.top, 0.35) - eye.y
			var p := eye2 + Vector2(to_sun.x, to_sun.z) / to_sun.y * h
			through *= 1.0 - c.shade * c.fade * smoothstep(1.0, 0.55, c.reach(p, Vector2.ZERO))
		# Lightning in a squall.
		if c.kind == Kind.SQUALL:
			c.flash = maxf(c.flash - delta * 6.0, 0.0)
			c.next_flash -= delta
			if c.next_flash <= 0.0 and c.fade > 0.5:
				c.next_flash = _rng.randf_range(2.0, 12.0)
				_flash(c, eye)
	for c: Cell in gone:
		_cells.erase(c)
		c.node.queue_free()
	sun_through = lerpf(sun_through, through, 1.0 - exp(-1.5 * delta))
	island.sky.shade_sun(sun_through)
	rain_here = lerpf(rain_here, wet, 1.0 - exp(-1.0 * delta))
	_gust = lerpf(_gust, gust, 1.0 - exp(-1.2 * delta))
	# The rain round the player, falling slanted with the wind.
	_rain.global_position = eye + Vector3(wind_dir.x, 0.0, wind_dir.y) * -2.0 + Vector3(0, 14, 0)
	_rain.amount_ratio = clampf(rain_here * 1.3, 0.0, 1.0)
	_rain.emitting = rain_here > 0.01
	_rain_process.gravity = Vector3(wind_dir.x, 0.0, wind_dir.y) * wind_speed * 0.35
	if _snd_rain != null:
		_snd_rain.volume_db = linear_to_db(clampf(rain_here, 0.0001, 1.0)) - 6.0
		_snd_gust.volume_db = linear_to_db(clampf(0.15 + 0.7 * _gust, 0.0001, 1.0)) - 14.0
	_update_bow(eye, to_sun)
	_step_bolt(delta)
	_step_thunder(eye)


## Keeps the sky stocked: fair clouds always about, a shower now and
## then, a squall or a mist bank somewhere out at sea.
func _plan(eye2: Vector2) -> void:
	# The wind wanders slowly round the compass.
	var a := atan2(wind_dir.y, wind_dir.x) + _rng.randfn(0.0, 0.01)
	wind_dir = Vector2(cos(a), sin(a))
	var counts := [0, 0, 0, 0]
	for c: Cell in _cells:
		if not c.leaving:
			counts[c.kind] += 1
	if fair and counts[Kind.FAIR] < 9:
		_spawn(Kind.FAIR)
	if not fair:
		_retire(Kind.FAIR)
	_next_shower -= 1.0
	if showers > 0.0 and _next_shower <= 0.0:
		_next_shower = lerpf(240.0, 50.0, showers) * _rng.randf_range(0.6, 1.4)
		_spawn(Kind.SHOWER)
	if far_weather:
		if counts[Kind.SQUALL] < 1 or (counts[Kind.SQUALL] < 2 and _rng.randf() < 0.004):
			_spawn(Kind.SQUALL)
		if counts[Kind.MIST] < 1 and _rng.randf() < 0.01:
			_spawn(Kind.MIST)
	else:
		_retire(Kind.SQUALL)
		_retire(Kind.MIST)


func _retire(kind: int) -> void:
	for c: Cell in _cells:
		if c.kind == kind:
			c.retired = true


## A shower sent toward the player, arriving in about a minute.
func send_shower() -> void:
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam != null else Vector3.ZERO
	var c := _spawn(Kind.SHOWER, false, Vector2(eye.x, eye.z) - wind_dir * wind_speed * 1.1 * 60.0)
	c.pos -= c.lean
	c.fade = 0.0
	c.node.global_position = Vector3(c.pos.x, 0.0, c.pos.y)


## A cell of `kind` put at once with its middle, or its rain's foot, at
## a point (for the probe).
func place(kind: int, at: Vector2) -> void:
	var c := _spawn(kind, true, at)
	c.pos -= c.lean
	c.node.global_position = Vector3(c.pos.x, 0.0, c.pos.y)


## ---- lightning far out --------------------------------------------------------

func _flash(c: Cell, eye: Vector3) -> void:
	c.flash = 1.0
	var a := _rng.randf() * TAU
	var r := _rng.randf() * c.radius * 0.8
	var p := c.pos + Vector2(cos(a) * r * c.stretch, sin(a) * r).rotated(atan2(c.axis.y, c.axis.x))
	# One in three comes down to the sea where it can be seen.
	if _rng.randf() < 0.35:
		_bolt.mesh = _bolt_mesh(Vector3(p.x, c.base, p.y), Vector3(p.x + _rng.randf_range(-60, 60), 0.0, p.y + _rng.randf_range(-60, 60)), eye)
		_bolt.visible = true
		_bolt_left = 0.4
	var at := Vector3(p.x, 150.0, p.y)
	var dist := eye.distance_to(at)
	_thunders.append([_clock + dist / SOUND, "res://audio/thunder_%d.wav" % (1 + _rng.randi() % 3), at,
			-8.0 - 20.0 * log(dist / 1000.0) / log(10.0)])


func _step_bolt(delta: float) -> void:
	if _bolt_left <= 0.0:
		return
	_bolt_left -= delta
	var pulse := maxf(sin(_bolt_left * 45.0), 0.0) * (_bolt_left / 0.4)
	_bolt_mat.albedo_color = Color(0.9, 0.9, 1.0) * (1.0 + 4.0 * pulse)
	if _bolt_left <= 0.0:
		_bolt.visible = false


func _step_thunder(eye: Vector3) -> void:
	var due: Array = []
	for th: Array in _thunders:
		if _clock >= float(th[0]):
			due.append(th)
	for th: Array in due:
		_thunders.erase(th)
		if DisplayServer.get_name() == "headless":
			continue
		var p := AudioStreamPlayer3D.new()
		p.stream = load(str(th[1]))
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		p.volume_db = float(th[3])
		p.pitch_scale = _rng.randf_range(0.8, 0.95)
		p.top_level = true
		add_child(p)
		# Placed a little way off in the strike's direction, so it is heard
		# from there.
		p.global_position = eye + (th[2] as Vector3 - eye).normalized() * 30.0
		p.play()
		p.finished.connect(p.queue_free)


func _bolt_mesh(top: Vector3, bottom: Vector3, eye: Vector3) -> ArrayMesh:
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
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var side := (b - a).cross(eye - a).normalized() * 4.0
		for v: Vector3 in [a - side, a + side, b + side, a - side, b + side, b - side]:
			st.add_vertex(v)
	return st.commit()


## ---- the rainbow ---------------------------------------------------------------

## The bow drawn on a sphere 700 m round the eye, its points lit where a
## shower's rain lies in their direction, the sun shines on the player,
## and the point is above the horizon. Rebuilt eight times a second
## round the eye and carried with it between.
func _update_bow(eye: Vector3, to_sun: Vector3) -> void:
	_bow.global_position = eye
	_bow_left -= get_process_delta_time()
	if _bow_left > 0.0:
		return
	_bow_left = 0.12
	var strength := 0.0
	if rainbows and to_sun.y > 0.0 and island.sky.daylight > 0.5:
		strength = smoothstep(0.35, 0.8, sun_through)
	var showers_on: Array[Cell] = []
	for c: Cell in _cells:
		if c.kind == Kind.SHOWER and c.fade > 0.1:
			showers_on.append(c)
	if strength <= 0.0 or showers_on.is_empty():
		_bow.visible = false
		return
	var anti := -to_sun
	var right := anti.cross(Vector3.UP).normalized()
	var up := right.cross(anti).normalized()
	var dist := 700.0
	var segments := 96
	# Rings from the inside out: the main bow's six colours at 40.5-42.3
	# degrees, violet inside; the second bow's at 50-53, red inside.
	var spectrum := [Color(0.45, 0.2, 0.75), Color(0.2, 0.35, 1.0), Color(0.2, 0.85, 0.35),
			Color(1.0, 0.9, 0.2), Color(1.0, 0.5, 0.1), Color(0.95, 0.15, 0.1)]
	var bows := [[40.5, 0.3, false, 0.9], [50.0, 0.5, true, 0.3]]   # inner edge, band width, reversed, strength
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for bow: Array in bows:
		# Each ring's points and how much rain lies behind them, worked out
		# once and shared by the bands either side.
		var dirs: Array = []
		var lit: Array = []
		for ring in 7:
			var r := deg_to_rad(float(bow[0]) + float(bow[1]) * ring)
			var ring_dirs := PackedVector3Array()
			var ring_lit := PackedFloat32Array()
			for s in segments + 1:
				var a := TAU * s / segments
				var dir := (anti * cos(r) + (right * cos(a) + up * sin(a)) * sin(r)).normalized()
				ring_dirs.append(dir * dist)
				ring_lit.append(_rain_toward(eye, dir, showers_on) * smoothstep(0.0, 0.03, dir.y) if dir.y > 0.0 else 0.0)
			dirs.append(ring_dirs)
			lit.append(ring_lit)
		for band in 6:
			var colour: Color = spectrum[5 - band if bow[2] else band]
			var k := float(bow[3]) * strength
			var inner: PackedVector3Array = dirs[band]
			var outer: PackedVector3Array = dirs[band + 1]
			var inner_lit: PackedFloat32Array = lit[band]
			var outer_lit: PackedFloat32Array = lit[band + 1]
			for s in segments:
				if inner_lit[s] + inner_lit[s + 1] + outer_lit[s] + outer_lit[s + 1] <= 0.0:
					continue
				any = true
				var quad := [inner[s], inner[s + 1], outer[s + 1], outer[s]]
				var alphas := [inner_lit[s], inner_lit[s + 1], outer_lit[s + 1], outer_lit[s]]
				for q: int in [0, 1, 2, 0, 2, 3]:
					st.set_color(Color(colour.r, colour.g, colour.b) * float(alphas[q]) * k)
					st.add_vertex(quad[q])
	_bow.visible = any
	if any:
		_bow.mesh = st.commit()


## How much shower rain a line of sight from the eye passes through.
func _rain_toward(eye: Vector3, dir: Vector3, cells: Array[Cell]) -> float:
	var flat := Vector2(dir.x, dir.z)
	var run := flat.length()
	if run < 0.01:
		return 0.0
	flat /= run
	var best := 0.0
	var eye2 := Vector2(eye.x, eye.z)
	for c: Cell in cells:
		var centre := c.pos + c.lean * 0.5
		var t := (centre - eye2).dot(flat)
		if t <= 0.0:
			continue
		var miss := (eye2 + flat * t).distance_to(centre)
		var height := eye.y + dir.y / run * t
		var inside := smoothstep(c.radius * 0.75, c.radius * 0.35, miss) * smoothstep(c.base, c.base * 0.6, height)
		best = maxf(best, inside * c.rain * c.fade)
	return clampf(best * 1.6, 0.0, 1.0)
