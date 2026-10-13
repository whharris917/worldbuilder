extends Node
## The teaser: one held shot of the alchemist's house's west side, the
## side facing the windmill, in the late afternoon sun, an earthstone in
## a birdbath in front of the great chimney spinning in the sun and
## falling still as each sail's shadow sweeps over it (Birdbath).
##
## Filmed with the engine's movie maker:
##   godot --path game res://world/teaser.tscn --write-movie <file>.avi --fixed-fps 30
## It runs for LENGTH seconds of film, then quits. The camera is the one
## kept on the test island with F8 (CozyTest.CAMERA_PATH) if there is
## one, else a close framing of the bath, low over its bowl, the gable's
## ivy and stones behind.

const LENGTH := 30.0                    # s of film
const SETTLE := 3.0                     # s run before filming starts, the sails got going
const HOUR := 16.25                     # the sun 32 degrees up in the west, the sails' shadows on the bath
const WIND := 1.6                       # m/s: the wind heard
const SAILS := 2.0                      # turns a minute, held: a sail's shadow every 7.5 s, about 2 s of it dark
const SHADE := 0.3                      # the sky's light on the shade, of the game's
const CONTRAST := 1.12
const BATH := Vector3(-8.1, 0.0, 0.3)   # in the house's frame: west of the gable, before the chimney

var _world: CozyTest
var _bath: Birdbath
var _cam := Camera3D.new()
var _time := 0.0


func _ready() -> void:
	MouseMode.probe = true
	_world = (load("res://world/cozy_test.tscn") as PackedScene).instantiate()
	add_child(_world)
	add_child(_cam)
	_run()


func _run() -> void:
	await get_tree().process_frame
	_world.player.visible = false
	_world.player.process_mode = Node.PROCESS_MODE_DISABLED
	_world.player.global_position = Vector3(0, -20, 0)
	var panel := _world.find_children("*", "BenchPanel", true, false)[0] as BenchPanel
	(panel.switches["Time passes"] as CheckButton).button_pressed = false
	(panel.switches["Gusts"] as CheckButton).button_pressed = false
	(panel.sliders["Time of day"] as HSlider).value = HOUR
	var sun := CozyTest.sun_at(HOUR)
	(panel.sliders["Wind from"] as HSlider).value = sun.y
	(panel.sliders["Wind speed (m/s)"] as HSlider).value = WIND
	(panel.sliders["Sail cloth (%)"] as HSlider).value = 100.0
	var mill := _world.windmill
	mill.cap_facing = sun.y
	mill.brake_on = false
	mill.omega = SAILS * TAU / 60.0
	# The shade deepened: less of the sky's light, more contrast.
	_world._env.ambient_light_energy = SHADE
	_world._env.ssao_intensity = 3.0
	_world._env.adjustment_contrast = CONTRAST
	for layer: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	_bath = Birdbath.new(_world.material(true, false), mill)
	var foot := _world.house.to_global(BATH)
	foot.y = _world.height(foot.x, foot.z)
	_bath.position = foot
	_world.add_child(_bath)
	_frame(foot)
	_cam.make_current()


## The camera kept with F8, or the framing of the bath against the gable.
func _frame(foot: Vector3) -> void:
	_cam.fov = 50.0
	if FileAccess.file_exists(CozyTest.CAMERA_PATH):
		var kept: Variant = JSON.parse_string(FileAccess.get_file_as_string(CozyTest.CAMERA_PATH))
		if kept is Dictionary:
			var o: Array = kept["origin"]
			var f: Array = kept["forward"]
			_cam.fov = float(kept.get("fov", 60.0))
			_cam.global_position = Vector3(o[0], o[1], o[2])
			_cam.look_at(_cam.global_position + Vector3(f[0], f[1], f[2]))
			return
	_cam.fov = 42.0
	_cam.global_position = foot + Vector3(-1.15, 1.3, 0.95)
	_cam.look_at(foot + Vector3(0.2, 0.97, -0.2))


func _physics_process(delta: float) -> void:
	if _bath == null:
		return
	_bath.to_sun = _world.workshop.light.sun
	_bath.sunlight = _world.workshop.light.sunlight
	# The sails held at their pace, whatever the wind would make of them.
	_world.windmill.omega = SAILS * TAU / 60.0
	_time += delta
	if _time > SETTLE + LENGTH:
		get_tree().quit()
