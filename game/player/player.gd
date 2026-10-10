class_name Player
extends CharacterBody3D
## First-person controller: WASD + mouse look, click to capture the
## mouse, Esc to release, E to use what you're looking at. The mouse
## wheel slides the camera along a hockey-stick track — blade tip at
## eye level in front of the face (zoomed in), knee at the eyes, and a
## handle rising up and slightly behind that extends indefinitely, so
## zooming out keeps climbing toward a bird's-eye view still centered
## on the player. Ctrl+wheel is optical zoom: it narrows the field of
## view from wherever the camera sits, with look sensitivity scaled to
## match. Yaw turns the body, pitch free-looks from the vantage point.
## Space jumps; in the air the player keeps the speed they left the
## ground with and can steer it a little.
##
## The pace: a walk at WALK_SPEED (twice a person's), Shift to run, picking
## up and slowing over a fraction of a second rather than at once; and
## the view about ninety degrees across, as a room looks to the eye, so
## a room is crossed in the steps it takes and looks its size.

const WALK_SPEED := 4.0        # m/s
const RUN_SPEED := 8.0         # m/s, Shift held
const ACCEL := 6.0             # m/s² picking up
const DECEL := 9.0             # m/s² slowing to a stop or a walk
const MOUSE_SENS := 0.0022
const GRAVITY := 9.8
const JUMP_SPEED := 3.43       # a 0.6 m rise
const AIR_STEER := 4.0         # m/s² of steering while airborne
const JUMP_GRACE := 0.12       # s: a jump pressed just before landing, or
                               # just after walking off an edge, still counts

const EYE := Vector3(0, 1.6, 0)
# The zoom track, eye-local: a quadratic through tip -> knee -> top,
# then an unbounded straight handle continuing past the top in the
# same direction, exponentially faster per notch (C1 at the joint).
const ZOOM_TIP := Vector3(0, 0, -0.55)
const ZOOM_KNEE := Vector3(0, 0.15, 0.25)
const ZOOM_TOP := Vector3(0, 5.4, 0.9)   # nearly overhead, just trailing the player
const ZOOM_STEP := 0.07
const ZOOM_T_MAX := 4.0        # ~870 m up the handle — effectively unbounded
const ZOOM_EXT_RATE := 1.6     # exponential growth rate past the top
const FOV_DEFAULT := 60.0       # vertical: about 90 degrees across at 16:9
const BASE_REACH := 3.0

@onready var camera: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/InteractRay

var zoom_t: float = 0.0        # 0 = blade tip (first person), 1 = top of the curve
var _zoom_now: float = 0.0     # smoothed follower
var _fov_target: float = FOV_DEFAULT
var _shaft_dir: Vector3 = (ZOOM_TOP - ZOOM_KNEE).normalized()
var _shaft_speed: float = 2.0 * (ZOOM_TOP - ZOOM_KNEE).length()
## The player's size against the world's: 1 a full-grown adult. A world
## that wants to feel bigger sets it smaller (set_body_scale); the body,
## the eye, the reach, the zoom track, the stride and the jump follow.
var body_scale := 1.0
var eye := EYE

var figure: PlayerFigure

var _step_streams: Array[AudioStream] = []
var _land_stream: AudioStream
var _step_surface := ""

## A footstep is about to sound (a world's acoustics may set its echoes).
signal footstep
var _steps: AudioStreamPlayer
var _was_on_floor: bool = true
var _fall_speed: float = 0.0
var _off_floor: float = 0.0     # seconds since last on the floor
var _jump_wanted: float = 0.0   # seconds a jump press stays pending
var _silent := DisplayServer.get_name() == "headless"


## Resize the player: the capsule, the eye, the figure. Everything else
## reads body_scale as it goes.
func set_body_scale(s: float) -> void:
	body_scale = s
	eye = EYE * s
	var col := $Collision as CollisionShape3D
	var cap := (col.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	cap.radius = 0.35 * s
	cap.height = 1.8 * s
	col.shape = cap
	col.position = Vector3(0, 0.9 * s, 0)
	camera.position = eye
	if figure != null:
		figure.scale = Vector3(s, s, s)


func _ready() -> void:
	ray.add_exception(self)
	# The ground and structures (1).
	collision_mask = 1
	# World (1) + interact volumes (4).
	ray.collision_mask = 1 | 4
	MouseMode.capture()
	figure = PlayerFigure.new()
	add_child(figure)
	use_steps("")
	_land_stream = load("res://audio/land.wav")
	_steps = AudioStreamPlayer.new()
	_steps.bus = "Room"
	_steps.volume_db = -17.0
	add_child(_steps)


## Set while a full-screen panel owns the screen. The movement code
## polls Input directly rather than going through the event queue, so a
## panel cannot stop the player walking just by marking events handled.
var input_locked: bool = false
## Set while something in the world takes the mouse (a part being aimed
## through its scope): mouse movement goes to its `turn_by` and the wheel
## to its `zoom_by` instead of the view, and the player stands still.
var look_held_by: Object = null


## Space is taken before the interface sees it, so a button left
## focused by a click is not pressed by a jump.
func _input(event: InputEvent) -> void:
	if input_locked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("jump"):
		_jump_wanted = JUMP_GRACE
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		if look_held_by != null:
			look_held_by.call("turn_by", motion.relative)
			return
		var sens := MOUSE_SENS * camera.fov / FOV_DEFAULT
		rotate_y(-motion.relative.x * sens)
		camera.rotation.x = clampf(camera.rotation.x - motion.relative.y * sens,
			-PI / 2.0 + 0.05, PI / 2.0 - 0.05)
	elif look_held_by != null and (event.is_action_pressed("zoom_in") or event.is_action_pressed("zoom_out")):
		look_held_by.call("zoom_by", 1 if event.is_action_pressed("zoom_in") else -1)
	elif event.is_action_pressed("zoom_in"):
		if Input.is_key_pressed(KEY_CTRL):
			_fov_target = clampf(_fov_target * 0.90, 8.0, 85.0)
		else:
			zoom_t = clampf(zoom_t - ZOOM_STEP, 0.0, ZOOM_T_MAX)
	elif event.is_action_pressed("zoom_out"):
		if Input.is_key_pressed(KEY_CTRL):
			_fov_target = clampf(_fov_target / 0.90, 8.0, 85.0)
		else:
			zoom_t = clampf(zoom_t + ZOOM_STEP, 0.0, ZOOM_T_MAX)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		MouseMode.capture()
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("interact") and look_held_by == null:
		var view := look_view()
		if view != null and view.has_method("use"):
			view.call("use")


func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	_off_floor = 0.0 if grounded else _off_floor + delta
	_jump_wanted = maxf(_jump_wanted - delta, 0.0)
	if not grounded:
		velocity.y -= GRAVITY * delta
		_fall_speed = -velocity.y
	var input := Vector2.ZERO if input_locked or look_held_by != null else Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var pace := RUN_SPEED if Input.is_action_pressed("run") and not input_locked else WALK_SPEED
	var wanted := Vector2(direction.x, direction.z) * pace * sqrt(body_scale)
	var ground := Vector2(velocity.x, velocity.z)
	if grounded:
		var rate := ACCEL if wanted.length() > ground.length() else DECEL
		ground = ground.move_toward(wanted, rate * sqrt(body_scale) * delta)
	elif input != Vector2.ZERO:
		ground = ground.move_toward(wanted, AIR_STEER * delta)
	velocity.x = ground.x
	velocity.z = ground.y
	if _jump_wanted > 0.0 and _off_floor < JUMP_GRACE and look_held_by == null:
		velocity.y = JUMP_SPEED * sqrt(body_scale)
		_jump_wanted = 0.0
		_off_floor = JUMP_GRACE
		_play(_step_streams[randi() % _step_streams.size()], randf_range(0.78, 0.86))
	move_and_slide()
	_update_landing()


## The camera follows every rendered frame, not every physics step:
## at a frame rate off the physics rate the step count per frame
## alternates, and a camera moved in steps looks jumpy.
func _process(delta: float) -> void:
	_update_camera(delta)
	figure.show_head(camera.position.distance_to(eye) > 0.3 * body_scale)
	var moving := global_basis.inverse() * velocity
	if figure.pose(delta, moving, is_on_floor(), camera.rotation.x):
		_play(_step_streams[randi() % _step_streams.size()], randf_range(0.88, 1.12))


## Slide the camera along the zoom track, pulling it in when a wall,
## floor, or ceiling sits between the head and the desired spot.
func _update_camera(delta: float) -> void:
	_zoom_now = lerpf(_zoom_now, zoom_t, 1.0 - exp(-10.0 * delta))
	var head := to_global(eye)
	var target := to_global(_zoom_point(_zoom_now))
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(head, target, 1)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		target = (hit["position"] as Vector3) + (head - target).normalized() * 0.18
	camera.position = to_local(target)
	camera.fov = lerpf(camera.fov, _fov_target, 1.0 - exp(-12.0 * delta))
	ray.target_position = Vector3(0, 0, -(BASE_REACH * body_scale + zoom_offset()))


## What the crosshair is on.
func aimed_collider() -> Node:
	if ray.is_colliding():
		return ray.get_collider() as Node
	return null


func _zoom_point(t: float) -> Vector3:
	if t <= 1.0:
		var a := ZOOM_TIP.lerp(ZOOM_KNEE, t)
		var b := ZOOM_KNEE.lerp(ZOOM_TOP, t)
		return eye + a.lerp(b, t) * body_scale
	# The handle: straight on in the shaft direction, exponentially
	# faster per notch so the sky is a few clicks away, not a hundred.
	var dist := (exp(ZOOM_EXT_RATE * (t - 1.0)) - 1.0) * _shaft_speed / ZOOM_EXT_RATE
	return eye + ZOOM_TOP * body_scale + _shaft_dir * dist


## How far the camera currently sits from the head. Reach-based systems
## (the interact ray) add this so the crosshair keeps working
## from a zoomed-out vantage.
func zoom_offset() -> float:
	return camera.position.distance_to(eye)


## A landing from a fall or a jump: the thud, and the knees take it.
func _update_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and _fall_speed > 1.0:
		figure.land(_fall_speed)
		if _fall_speed > 2.5:
			_play(_land_stream, randf_range(0.92, 1.02))
		else:
			_play(_step_streams[randi() % _step_streams.size()], randf_range(0.88, 1.12))
	_was_on_floor = on_floor


## The footsteps for the ground underfoot: "" for the ordinary ones
## (step_1..4.wav), or a surface's own set, step_<surface>_1..4.wav
## (pebbles). A world calls it when the ground under the player changes.
func use_steps(surface: String) -> void:
	if surface == _step_surface and not _step_streams.is_empty():
		return
	_step_surface = surface
	_step_streams.clear()
	var stem := "res://audio/step_%d.wav" if surface == "" else "res://audio/step_" + surface + "_%d.wav"
	for i in range(1, 5):
		_step_streams.append(load(stem % i))


## A headless run mixes no audio, so a sound started there is never
## finished and outlives its stream at exit; it plays none.
func _play(stream: AudioStream, pitch: float) -> void:
	if _silent:
		return
	footstep.emit()
	_steps.stream = stream
	_steps.pitch_scale = pitch
	_steps.volume_db = -17.0 + randf_range(-2.0, 0.0)
	_steps.play()


## The player that sounds the footsteps and landings, for a world that
## echoes them.
func step_player() -> AudioStreamPlayer:
	return _steps


## The view under the crosshair, or null.
func look_view() -> Node3D:
	if not ray.is_colliding():
		return null
	var collider := ray.get_collider()
	if collider is Node and (collider as Node).has_meta("view"):
		return (collider as Node).get_meta("view") as Node3D
	return null
