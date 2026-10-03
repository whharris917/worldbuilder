class_name PickupTruck
extends VehicleBody3D
## A red half-ton pickup of the early 1940s that the player can drive.
## Built to its real size from simple shapes: a long hood between
## pontoon fenders, a tall upright grille, round headlamps on the
## fenders, a closed cab with a split windshield, a steel bed behind,
## running boards and chrome bumpers. Its own frame: front +z, its left
## (the driver's side) +x, the ground at y 0.
##
## The physics is Godot's vehicle: a 1.4 t body on four sprung wheels,
## the rear two driven, the front two steering. Walked up to and used
## (E), the player takes the driver's seat: W and S throttle and brake
## (S held at a standstill backs it up), A and D steer (less at speed),
## Space the handbrake, the mouse looks round the cab, the wheel moves
## the view between the seat and behind the truck, E gets out once it
## has nearly stopped. Parked, the handbrake is on. The engine's sound
## (engine_loop.wav) runs while it is driven, its pitch through three
## gears with the road speed, louder with the throttle; the headlamps
## light while it is driven.
##
## It keeps its feet: the weight rides low, the tyres slide before they
## grip hard enough to roll it, and an anti-roll bar (a torque against
## the body's lean, damped) holds it level through turns. Turned over
## all the same and come to rest, it is set back on its wheels after
## RIGHTING seconds.

const RED := Color(0.52, 0.07, 0.05)
const WHEEL_R := 0.38
const ENGINE := 3600.0               # N at the rear wheels, from a standstill
const TOP_SPEED := 24.0              # m/s, about 55 mph
const REVERSE := 1600.0
const BRAKE := 25.0
const PARK_BRAKE := 40.0
const STEER_LOW := 0.55              # rad at a crawl
const STEER_HIGH := 0.14             # rad at top speed
const GEARS: Array[float] = [7.0, 15.0, 24.0]   # m/s at the top of each gear
const DRIVER_EYE := Vector3(0.36, 1.66, -0.08)
const CHASE := Vector3(0.0, 3.2, -8.5)
const ROLL_STIFF := 14000.0          # N m a radian of lean
const ROLL_DAMP := 3500.0            # N m a radian a second
const RIGHTING := 2.0                # s on its side or back, still, before it is righted

var world: WorldBase
var driving := false
var _steer := 0.0
var _yaw := 0.0
var _pitch := -0.08
var _chase := false
var _cab_cam: Camera3D
var _chase_cam: Camera3D
var _engine: AudioStreamPlayer3D
var _lamps: Array[SpotLight3D] = []
var _player_layers := Vector2i.ZERO
var _over := 0.0


func _init() -> void:
	mass = 1400.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, 0.3, 0.2)
	brake = PARK_BRAKE
	set_meta("view", self)


func _ready() -> void:
	_build_body()
	_build_wheels()
	_build_collision()
	_cab_cam = Camera3D.new()
	_cab_cam.position = DRIVER_EYE
	_cab_cam.fov = 62.0
	_cab_cam.near = 0.05
	_cab_cam.far = 4500.0
	add_child(_cab_cam)
	_chase_cam = Camera3D.new()
	_chase_cam.top_level = true
	_chase_cam.fov = 60.0
	_chase_cam.far = 4500.0
	add_child(_chase_cam)
	for x: float in [-0.62, 0.62]:
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(x, 1.05, 2.05)
		lamp.rotation.y = PI
		lamp.rotation.x = -0.06
		lamp.light_color = Color(1.0, 0.88, 0.68)
		lamp.light_energy = 4.0
		lamp.spot_range = 45.0
		lamp.spot_angle = 24.0
		lamp.visible = false
		add_child(lamp)
		_lamps.append(lamp)
	if DisplayServer.get_name() != "headless":
		var stream := load("res://audio/engine_loop.wav") as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_engine = AudioStreamPlayer3D.new()
		_engine.stream = stream
		_engine.position = Vector3(0.0, 0.9, 1.6)
		_engine.unit_size = 6.0
		_engine.max_distance = 300.0
		_engine.bus = "Outdoor"
		add_child(_engine)


## ---- getting in and out ----------------------------------------------------

## Used from outside: the player takes the driver's seat.
func use() -> void:
	if driving or world == null:
		return
	driving = true
	var p := world.player
	_player_layers = Vector2i(p.collision_layer, p.collision_mask)
	p.collision_layer = 0
	p.collision_mask = 0
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.visible = false
	_yaw = 0.0
	_pitch = -0.08
	_chase = false
	_cab_cam.current = true
	brake = 0.0
	for lamp in _lamps:
		lamp.visible = true
	if _engine != null:
		_engine.play()
	world.hud.toast("W/S drive and brake · A/D steer · Space handbrake · wheel: view · E get out")


## Out on the driver's side, facing the way the truck faces.
func get_out() -> void:
	if not driving:
		return
	if linear_velocity.length() > 2.0:
		world.hud.toast("Slow down to get out")
		return
	driving = false
	engine_force = 0.0
	brake = PARK_BRAKE
	for lamp in _lamps:
		lamp.visible = false
	if _engine != null:
		_engine.stop()
	var p := world.player
	p.global_position = to_global(Vector3(1.4, 0.3, 0.1))
	p.rotation = Vector3(0.0, global_rotation.y + PI, 0.0)
	p.camera.rotation.x = 0.0
	p.collision_layer = _player_layers.x
	p.collision_mask = _player_layers.y
	p.visible = true
	p.process_mode = Node.PROCESS_MODE_INHERIT
	p.camera.current = true


## ---- driving ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not driving or world.settings.visible:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		_yaw = clampf(_yaw - m.relative.x * Player.MOUSE_SENS, -2.0, 2.0)
		_pitch = clampf(_pitch - m.relative.y * Player.MOUSE_SENS, -1.2, 1.0)
	elif event.is_action_pressed("zoom_out"):
		_chase = true
		_chase_cam.current = true
	elif event.is_action_pressed("zoom_in"):
		_chase = false
		_cab_cam.current = true
	elif event.is_action_pressed("interact"):
		get_out()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		MouseMode.capture()


func _physics_process(delta: float) -> void:
	_keep_upright(delta)
	if not driving:
		engine_force = 0.0
		steering = move_toward(steering, 0.0, delta)
		return
	var active := not world.settings.visible
	var ahead := Input.get_axis("move_back", "move_forward") if active else 0.0
	var turn := Input.get_axis("move_right", "move_left") if active else 0.0
	var forward := global_basis.z
	var speed := linear_velocity.dot(forward)
	engine_force = 0.0
	brake = 0.0
	if ahead > 0.0:
		if speed < -0.5:
			brake = BRAKE
		else:
			engine_force = ENGINE * ahead * clampf(1.0 - speed / TOP_SPEED, 0.0, 1.0)
	elif ahead < 0.0:
		if speed > 0.5:
			brake = BRAKE * -ahead
		else:
			engine_force = -REVERSE * -ahead * clampf(1.0 + speed / 6.0, 0.0, 1.0)
	if active and Input.is_action_pressed("jump"):
		brake = PARK_BRAKE
	var most := lerpf(STEER_LOW, STEER_HIGH, clampf(absf(speed) / TOP_SPEED, 0.0, 1.0))
	_steer = move_toward(_steer, turn * most, 1.6 * delta)
	steering = _steer
	# The player rides along, so what follows the player follows the truck.
	world.player.global_position = to_global(Vector3(DRIVER_EYE.x, 0.9, DRIVER_EYE.z))
	_sound(absf(speed), absf(ahead))


func _process(delta: float) -> void:
	if not driving:
		return
	_cab_cam.rotation = Vector3(_pitch, PI + _yaw, 0.0)
	# Behind the truck, following it smoothly, looking past it.
	var want := global_transform * CHASE
	var t := 1.0 - exp(-6.0 * delta)
	_chase_cam.global_position = _chase_cam.global_position.lerp(want, t) if _chase else want
	_chase_cam.look_at(global_transform * Vector3(0.0, 1.2, 6.0), Vector3.UP)


## The anti-roll bar, and righting the truck if it is over anyway.
func _keep_upright(delta: float) -> void:
	var fwd := global_basis.z
	var up := global_basis.y
	# The lean about the truck's own length, from the level.
	var side := global_basis.x
	var lean := asin(clampf(side.y, -1.0, 1.0))
	var spin := angular_velocity.dot(fwd)
	if up.y > 0.3:
		# Left side up is a positive turn about the length: push it back.
		apply_torque(-fwd * (lean * ROLL_STIFF + spin * ROLL_DAMP))
		_over = 0.0
		return
	if linear_velocity.length() < 1.0 and angular_velocity.length() < 1.0:
		_over += delta
		if _over > RIGHTING:
			_over = 0.0
			var yaw := atan2(fwd.x, fwd.z)
			global_transform = Transform3D(Basis(Vector3.UP, yaw), global_position + Vector3.UP * 1.2)
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
	else:
		_over = 0.0


## The engine through three gears: its pitch climbs through each gear
## and drops at the change; louder under throttle.
func _sound(speed: float, throttle: float) -> void:
	if _engine == null:
		return
	var low := 0.0
	var revs := 0.0
	for top in GEARS:
		if speed <= top or top == GEARS[GEARS.size() - 1]:
			revs = clampf((speed - low) / (top - low), 0.0, 1.0)
			break
		low = top
	_engine.pitch_scale = 0.85 + 1.5 * revs + 0.15 * throttle
	_engine.volume_db = -8.0 + 7.0 * throttle


## ---- the body ------------------------------------------------------------------

func _build_body() -> void:
	var paint := _mat(RED, 0.35, 0.15)
	var dark := _mat(Color(0.05, 0.05, 0.05), 0.7, 0.0)
	var chrome := _mat(Color(0.75, 0.75, 0.72), 0.18, 1.0)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.25, 0.3, 0.32, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var seat := _mat(Color(0.30, 0.20, 0.13), 0.8, 0.0)
	var inside := _mat(RED.darkened(0.35), 0.5, 0.0)
	inside.cull_mode = BaseMaterial3D.CULL_DISABLED
	var lens := _mat(Color(0.95, 0.93, 0.85), 0.1, 0.0)
	lens.emission_enabled = true
	lens.emission = Color(1.0, 0.9, 0.7)
	lens.emission_energy_multiplier = 0.3
	# The frame and the floor under it.
	_box(Vector3(0.95, 0.18, 4.3), Vector3(0.0, 0.52, -0.05), dark)
	# The hood: a box with a rounded top, to the grille.
	_box(Vector3(0.92, 0.42, 1.42), Vector3(0.0, 1.06, 1.45), paint)
	_cyl(0.46, 1.42, Vector3(0.0, 1.27, 1.45), Vector3(PI / 2.0, 0.0, 0.0), paint, Vector3(1.0, 1.0, 0.32))
	# The grille: tall, with chrome bars, and the bumper under it.
	_box(Vector3(0.78, 0.62, 0.08), Vector3(0.0, 1.0, 2.17), dark)
	for i in 9:
		_box(Vector3(0.025, 0.58, 0.03), Vector3(-0.32 + 0.08 * i, 1.0, 2.22), chrome)
	_box(Vector3(1.78, 0.12, 0.1), Vector3(0.0, 0.58, 2.36), chrome)
	_box(Vector3(1.72, 0.12, 0.1), Vector3(0.0, 0.58, -2.36), chrome)
	# Pontoon fenders over the wheels, front and back.
	for x: float in [-0.75, 0.75]:
		_capsule(0.3, 1.55, Vector3(x, 0.8, 1.42), paint, Vector3(0.72, 1.0, 1.0))
		_capsule(0.3, 1.25, Vector3(x * 1.02, 0.78, -1.45), paint, Vector3(0.6, 1.0, 1.0))
		# A headlamp on each front fender, chrome ringed.
		_sphere(0.115, Vector3(x * 0.83, 1.05, 1.98), chrome)
		_sphere(0.095, Vector3(x * 0.83, 1.05, 2.04), lens)
		# Running boards between the fenders.
		_box(Vector3(0.24, 0.04, 1.75), Vector3(x * 1.08, 0.6, -0.05), dark)
	# The cab: lower body to the beltline, pillars, roof, back wall; its
	# inside painted, the floor, a bench seat, the dash and the wheel.
	var belt := 1.33
	_box(Vector3(1.52, belt - 0.85, 1.3), Vector3(0.0, (belt + 0.85) / 2.0, 0.1), paint)
	_box(Vector3(1.48, belt - 0.88, 1.26), Vector3(0.0, (belt + 0.88) / 2.0 + 0.02, 0.1), inside)
	_box(Vector3(1.52, 0.08, 1.24), Vector3(0.0, 2.0, 0.08), paint)
	for x: float in [-0.73, 0.0, 0.73]:
		_box(Vector3(0.06 if x != 0.0 else 0.04, 2.0 - belt, 0.06), Vector3(x, (2.0 + belt) / 2.0, 0.72), paint)
	for x: float in [-0.73, 0.73]:
		_box(Vector3(0.06, 2.0 - belt, 0.08), Vector3(x, (2.0 + belt) / 2.0, -0.51), paint)
	_box(Vector3(1.52, 2.0 - belt, 0.05), Vector3(0.0, (2.0 + belt) / 2.0, -0.53), inside)
	_box(Vector3(0.7, 0.26, 0.02), Vector3(0.0, 1.7, -0.558), glass)
	_box(Vector3(1.4, 0.6, 0.02), Vector3(0.0, (2.0 + belt) / 2.0, 0.73), glass)
	for x: float in [-0.755, 0.755]:
		_box(Vector3(0.02, 0.6, 1.16), Vector3(x, (2.0 + belt) / 2.0, 0.1), glass)
	_box(Vector3(1.4, 0.1, 0.5), Vector3(0.0, 1.12, -0.24), seat)
	_box(Vector3(1.4, 0.5, 0.1), Vector3(0.0, 1.4, -0.46), seat)
	_box(Vector3(1.44, 0.18, 0.22), Vector3(0.0, 1.38, 0.6), inside)
	var wheel := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.17
	torus.outer_radius = 0.2
	wheel.mesh = torus
	wheel.material_override = dark
	wheel.position = Vector3(0.36, 1.42, 0.38)
	wheel.rotation = Vector3(-1.1, 0.0, 0.0)
	add_child(wheel)
	# The bed: floor, sides, the front wall and the tailgate.
	_box(Vector3(1.32, 0.05, 1.68), Vector3(0.0, 0.86, -1.42), dark)
	for x: float in [-0.66, 0.66]:
		_box(Vector3(0.05, 0.45, 1.68), Vector3(x, 1.1, -1.42), paint)
	_box(Vector3(1.32, 0.45, 0.05), Vector3(0.0, 1.1, -0.6), paint)
	_box(Vector3(1.32, 0.45, 0.05), Vector3(0.0, 1.1, -2.25), paint)
	for x: float in [-0.5, 0.5]:
		_box(Vector3(0.1, 0.08, 0.04), Vector3(x, 0.9, -2.29), _mat(Color(0.6, 0.05, 0.03), 0.3, 0.0))


func _build_wheels() -> void:
	var tyre := _mat(Color(0.04, 0.04, 0.04), 0.9, 0.0)
	var rim := _mat(RED.darkened(0.1), 0.4, 0.1)
	var cap := _mat(Color(0.75, 0.75, 0.72), 0.18, 1.0)
	for z: float in [1.45, -1.45]:
		for x: float in [-0.76, 0.76]:
			var w := VehicleWheel3D.new()
			w.position = Vector3(x, WHEEL_R + 0.18, z)
			w.wheel_radius = WHEEL_R
			w.wheel_rest_length = 0.18
			w.suspension_travel = 0.22
			w.suspension_stiffness = 42.0
			w.damping_compression = 2.2
			w.damping_relaxation = 3.0
			w.wheel_friction_slip = 2.2
			w.suspension_max_force = 12000.0
			w.use_as_traction = z < 0.0
			w.use_as_steering = z > 0.0
			add_child(w)
			var t := MeshInstance3D.new()
			var tm := CylinderMesh.new()
			tm.top_radius = WHEEL_R
			tm.bottom_radius = WHEEL_R
			tm.height = 0.2
			t.mesh = tm
			t.material_override = tyre
			t.rotation.z = PI / 2.0
			w.add_child(t)
			var r := MeshInstance3D.new()
			var rm := CylinderMesh.new()
			rm.top_radius = 0.22
			rm.bottom_radius = 0.22
			rm.height = 0.21
			r.mesh = rm
			r.material_override = rim
			r.rotation.z = PI / 2.0
			w.add_child(r)
			var c := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.09
			cm.bottom_radius = 0.11
			cm.height = 0.24
			c.mesh = cm
			c.material_override = cap
			c.rotation.z = PI / 2.0
			w.add_child(c)


func _build_collision() -> void:
	for part: Array in [
		[Vector3(1.7, 0.7, 4.6), Vector3(0.0, 0.95, 0.0)],
		[Vector3(1.5, 0.65, 1.3), Vector3(0.0, 1.65, 0.1)],
	]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = part[0]
		shape.shape = box
		shape.position = part[1]
		add_child(shape)


func _mat(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _box(size: Vector3, at: Vector3, mat: Material) -> void:
	var m := BoxMesh.new()
	m.size = size
	_part(m, at, Vector3.ZERO, mat, Vector3.ONE)


func _cyl(r: float, h: float, at: Vector3, rot: Vector3, mat: Material, scale_by: Vector3) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	_part(m, at, rot, mat, scale_by)


func _capsule(r: float, length: float, at: Vector3, mat: Material, scale_by: Vector3) -> void:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = length
	_part(m, at, Vector3(PI / 2.0, 0.0, 0.0), mat, scale_by)


func _sphere(r: float, at: Vector3, mat: Material) -> void:
	var m := SphereMesh.new()
	m.radius = r
	m.height = 2.0 * r
	_part(m, at, Vector3.ZERO, mat, Vector3.ONE)


func _part(mesh: Mesh, at: Vector3, rot: Vector3, mat: Material, scale_by: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	mi.scale = scale_by
	add_child(mi)
