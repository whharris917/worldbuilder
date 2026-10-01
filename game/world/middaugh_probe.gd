extends Node
## Debug harness for the Middaugh house: boots the world and photographs
## the house from free cameras, round it from the corners and square on
## to each face as the survey's elevations draw it (a long lens from far
## off), printing the frame rate with each.
## Run windowed:
##   godot --path game res://world/middaugh_probe.tscn
## VERIBUILDER_MD_SHOTS=corners or faces limits it.

## name, camera position, target (metres; +x east, +z south, where the front faces).
const CORNERS := [
	["sw", Vector3(-22.0, 1.7, 26.0), Vector3(0.0, 6.0, 0.0)],
	["se", Vector3(24.0, 1.7, 24.0), Vector3(0.0, 6.0, 0.0)],
	["ne", Vector3(24.0, 1.7, -26.0), Vector3(0.0, 6.0, 0.0)],
	["nw", Vector3(-24.0, 1.7, -24.0), Vector3(0.0, 6.0, 0.0)],
]
const FACES := [
	["south", Vector3(0.0, 6.0, 120.0)],
	["north", Vector3(0.0, 6.0, -120.0)],
	["east", Vector3(120.0, 6.0, 0.0)],
	["west", Vector3(-120.0, 6.0, 0.0)],
]

var _world: MiddaughMap


func _ready() -> void:
	MouseMode.probe = true
	var world: MiddaughMap = (load("res://world/middaugh.tscn") as PackedScene).instantiate()
	add_child(world)
	_world = world
	_run(world)


func _run(world: MiddaughMap) -> void:
	await get_tree().create_timer(5.0).timeout
	world.graphics.set_preset("Medium")
	world.graphics.apply(world)
	world.set_time_of_day(10.0)
	for layer: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	world.player.visible = false
	var which := OS.get_environment("VERIBUILDER_MD_SHOTS")
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	if which == "" or which == "corners":
		cam.fov = 60.0
		for c: Array in CORNERS:
			cam.look_at_from_position(c[1], c[2], Vector3.UP)
			await _shot("probe_md_%s" % c[0])
	if which == "" or which == "faces":
		for f: Node in get_tree().root.find_children("*", "", true, false):
			if f is Forest:
				(f as Node3D).visible = false
		cam.fov = 11.0
		for c: Array in FACES:
			var at: Vector3 = c[1]
			cam.look_at_from_position(at, Vector3(0.0, 6.0, 0.0), Vector3.UP)
			await _shot("probe_md_%s" % c[0])
	get_tree().quit()


func _shot(name: String) -> void:
	for i in 30:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://%s.png" % name)
	print("[probe] %s written, %d fps" % [name, Engine.get_frames_per_second()])
