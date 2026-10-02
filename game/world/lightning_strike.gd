class_name LightningStrike
extends Node3D
## One stroke of lightning, an event the world starts: a jagged channel
## from a kilometre up to the ground somewhere between 0.9 and 2.5 km off
## in the direction the viewer faces, flickering through two to four
## return strokes; the flash lights the land (a light from the stroke's
## direction), the sky toward it and the air; and the thunder sets out
## at the speed of sound, so it arrives three seconds a kilometre later
## and rolls: the near crack (thunder_near) for a close stroke, a long
## roll for a far one.

const SOUND := 343.0           # metres a second
const BASE := 1000.0           # the cloud's base, where the channel starts

var _world: WorldBase
var _t := -1.0
var _pulses: Array[Vector2] = []          # (start time, strength)
var _thunder_at := 0.0
var _thunder_file := ""
var _thunder_db := 0.0
var _dir := Vector3.FORWARD
var _reach := 0.3
var _ends := 0.0
var _added_ambient := 0.0
var _light: DirectionalLight3D
var _bolt: MeshInstance3D
var _bolt_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func setup(world: WorldBase) -> void:
	_world = world
	_light = DirectionalLight3D.new()
	_light.light_color = Color(0.82, 0.86, 1.0)
	_light.light_energy = 0.0
	_light.shadow_enabled = true
	_light.visible = false
	add_child(_light)
	_bolt_mat = StandardMaterial3D.new()
	_bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bolt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bolt_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_bolt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bolt_mat.disable_fog = true
	_bolt_mat.render_priority = 2
	_bolt = MeshInstance3D.new()
	_bolt.material_override = _bolt_mat
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.visible = false
	add_child(_bolt)


func running() -> bool:
	return _t >= 0.0


## Strike, as seen from `eye` facing `forward`; `ground` gives the
## height of the land where it hits.
func play(eye: Vector3, forward: Vector3, ground: Callable) -> void:
	_rng.randomize()
	var flat := Vector3(forward.x, 0.0, forward.z)
	if flat.length() < 0.01:
		flat = Vector3.FORWARD
	var az := atan2(flat.z, flat.x) + _rng.randf_range(-0.6, 0.6)
	var dist := exp(_rng.randf_range(log(900.0), log(2500.0)))
	var at := eye + Vector3(cos(az), 0.0, sin(az)) * dist
	at.y = float(ground.call(at.x, at.z))
	_dir = (at + Vector3(0.0, 350.0, 0.0) - eye).normalized()
	_reach = clampf(1400.0 / dist, 0.35, 1.0)
	_light.basis = Basis.looking_at(-_dir)
	_t = 0.0
	_pulses.clear()
	var start := 0.15
	for i in 2 + _rng.randi() % 3:
		_pulses.append(Vector2(start, _rng.randf_range(0.6, 1.0) * (1.0 if i == 0 else 0.75)))
		start += _rng.randf_range(0.05, 0.14)
	_bolt.mesh = _bolt_mesh(at, eye)
	_thunder_at = dist / SOUND
	_thunder_file = "res://audio/thunder_near.wav" if dist < 1300.0 else "res://audio/thunder_1.wav"
	_thunder_db = -1.0 - 10.0 * log(dist / 900.0) / log(10.0)
	_ends = _thunder_at + 12.0


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	var before := _t
	_t += delta
	# The return strokes: each a sharp rise and a fast fade.
	var flash := 0.0
	for p in _pulses:
		var age := _t - p.x
		if age >= 0.0:
			flash += p.y * exp(-age / 0.05)
	var lit := flash > 0.01
	_light.visible = lit
	_light.light_energy = flash * 3.0 * _reach
	_bolt.visible = lit
	_bolt_mat.albedo_color = Color(0.85, 0.88, 1.0) * clampf(flash * 3.0, 0.0, 6.0)
	var sky := _world.sky_mat as ShaderMaterial
	if sky != null:
		sky.set_shader_parameter("flash", flash * 0.6 if lit else 0.0)
		sky.set_shader_parameter("flash_dir", _dir)
	# The air lit by the flash: the ambient raised by the flash and put
	# back as it fades, whatever the clock set meanwhile.
	var add := (flash * 0.8 * _reach) if lit else 0.0
	if _world.sky_env != null:
		_world.sky_env.ambient_light_energy += add - _added_ambient
	_added_ambient = add
	if before < _thunder_at and _t >= _thunder_at:
		_play_thunder()
	if _t > _ends:
		_t = -1.0


func _play_thunder() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = load(_thunder_file)
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	p.volume_db = _thunder_db
	p.pitch_scale = _rng.randf_range(0.9, 1.05)
	p.bus = "Outdoor"
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam != null else Vector3.ZERO
	p.position = eye + Vector3(_dir.x, 0.0, _dir.z).normalized() * 40.0
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()


## The channel: from the cloud's base down to the ground in jagged
## steps, a branch or two, each segment a pair of crossed ribbons.
func _bolt_mesh(at: Vector3, eye: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := at + Vector3(_rng.randf_range(-150.0, 150.0), BASE, _rng.randf_range(-150.0, 150.0))
	var width := clampf(eye.distance_to(at) / 450.0, 1.0, 6.0)
	var pts := _jag(top, at, 7, 90.0)
	_ribbons(st, pts, width)
	for _b in 2:
		var from: Vector3 = pts[2 + _rng.randi() % 5]
		var end := from + Vector3(_rng.randf_range(-200.0, 200.0), -_rng.randf_range(120.0, 300.0), _rng.randf_range(-200.0, 200.0))
		_ribbons(st, _jag(from, end, 4, 40.0), width * 0.6)
	return st.commit()


func _jag(a: Vector3, b: Vector3, depth: int, spread: float) -> Array[Vector3]:
	var pts: Array[Vector3] = [a, b]
	var s := spread
	for _d in depth:
		var next: Array[Vector3] = [pts[0]]
		for i in pts.size() - 1:
			var mid := (pts[i] + pts[i + 1]) / 2.0 + Vector3(_rng.randf_range(-s, s), _rng.randf_range(-s, s) * 0.3, _rng.randf_range(-s, s))
			next.append(mid)
			next.append(pts[i + 1])
		pts = next
		s *= 0.55
	return pts


func _ribbons(st: SurfaceTool, pts: Array[Vector3], width: float) -> void:
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		for across: Vector3 in [Vector3(width, 0, 0), Vector3(0, 0, width)]:
			for p: Vector3 in [a - across, a + across, b + across, a - across, b + across, b - across]:
				st.add_vertex(p)
