extends Node
## Debug harness for the cozy island: boots it and photographs it from free
## cameras, printing the frame rate with each. Run windowed:
##   godot --path game res://world/island_probe.tscn
## WORLDBUILDER_ISLAND_SHOTS=name,name limits it to those views;
## WORLDBUILDER_ISLAND_VIEWS=name:fov:x,y,z:tx,ty,tz;... takes its own;
## WORLDBUILDER_ISLAND_SET=Title=value;... sets panel switches (0/1) and
## sliders by title; All=0/1 sets every step of the Softening panel.

## name, fov, camera, target.
const VIEWS := [
	["dock", 60.0, Vector3(4.0, 2.2, 56.0), Vector3(0.0, 3.0, 10.0)],
	["beach", 60.0, Vector3(-28.0, 1.8, 32.0), Vector3(4.0, 2.0, 20.0)],
	["above", 50.0, Vector3(70.0, 35.0, 90.0), Vector3(0.0, 0.0, 5.0)],
	["hill", 60.0, Vector3(-10.0, 12.0, -8.0), Vector3(4.0, 2.0, 30.0)],
]

var _world: CozyIsland


func _ready() -> void:
	MouseMode.probe = true
	_world = (load("res://world/cozy_island.tscn") as PackedScene).instantiate()
	add_child(_world)
	_run()


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	_world.player.visible = false
	_world.player.process_mode = Node.PROCESS_MODE_DISABLED
	_world.player.global_position = Vector3(0, -20, 0)
	var panel := _world.find_children("*", "BenchPanel", true, false)[0] as BenchPanel
	var sets := OS.get_environment("WORLDBUILDER_ISLAND_SET")
	if sets != "":
		for pair: String in sets.split(";"):
			var kv := pair.split("=")
			if kv[0] == "All":
				for title: String in CozyIsland.STEPS:
					(panel.switches[title] as CheckButton).button_pressed = kv[1] == "1"
			elif panel.switches.has(kv[0]):
				(panel.switches[kv[0]] as CheckButton).button_pressed = kv[1] == "1"
			elif panel.sliders.has(kv[0]):
				(panel.sliders[kv[0]] as HSlider).value = float(kv[1])
	await get_tree().create_timer(1.0).timeout
	for layer: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var views: Array = VIEWS
	var custom := OS.get_environment("WORLDBUILDER_ISLAND_VIEWS")
	if custom != "":
		views = []
		for v: String in custom.split(";"):
			var parts := v.split(":")
			var p := parts[2].split_floats(",")
			var t := parts[3].split_floats(",")
			views.append([parts[0], float(parts[1]), Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2])])
	var only := OS.get_environment("WORLDBUILDER_ISLAND_SHOTS")
	for v: Array in views:
		if only != "" and not (str(v[0]) in only.split(",")):
			continue
		cam.fov = float(v[1])
		cam.global_position = v[2]
		cam.look_at(v[3])
		await get_tree().create_timer(1.0).timeout
		var frames := Engine.get_frames_drawn()
		var t0 := Time.get_ticks_usec()
		await get_tree().create_timer(2.0).timeout
		var fps := float(Engine.get_frames_drawn() - frames) / ((Time.get_ticks_usec() - t0) * 1e-6)
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://island_%s.png" % v[0])
		print("[island_probe] %s  %.1f fps" % [v[0], fps])
	get_tree().quit()
