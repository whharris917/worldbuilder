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
	["fire", 60.0, Vector3(-6.5, 1.7, 44.0), Vector3(-10.4, 0.6, 38.0)],
	["flames", 50.0, Vector3(-9.0, 1.3, 40.6), Vector3(-10.4, 0.5, 38.0)],
	["works", 60.0, Vector3(59.6, 9.0, -5.5), Vector3(37.2, 2.0, -12.0)],
	["works_near", 70.0, Vector3(32.9, 3.0, -4.6), Vector3(40.3, 1.8, -11.8)],
	["works_mill", 60.0, Vector3(44.9, 1.7, -14.0), Vector3(26.7, 5.0, -16.4)],
	["colours", 60.0, Vector3(-30.0, 8.0, -49.8), Vector3(-23.8, 2.0, -32.2)],
	["colours_near", 70.0, Vector3(-17.9, 3.8, -29.0), Vector3(-25.2, 2.5, -32.5)],
	["colours_reactor", 70.0, Vector3(-21.5, 3.0, -30.7), Vector3(-25.2, 2.2, -32.5)],
	["balloon", 60.0, Vector3(-58.7, 7.0, 12.4), Vector3(-41.4, 6.0, 7.3)],
	["balloon_ground", 65.0, Vector3(-38.4, 2.2, 12.9), Vector3(-41.4, 14.0, 7.3)],
	["balloon_sky", 70.0, Vector3(-38.4, 2.2, 12.9), Vector3(-60.0, 240.0, 0.0)],
	["works_yard", 70.0, Vector3(32.1, 2.7, -11.65), Vector3(37.2, 3.0, -12.0)],
	["works_pan", 65.0, Vector3(37.8, 2.6, -7.8), Vector3(41.2, 1.3, -8.7)],
	["lanterns", 65.0, Vector3(2.0, 2.2, 33.0), Vector3(4.0, 2.4, 20.0)],
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
