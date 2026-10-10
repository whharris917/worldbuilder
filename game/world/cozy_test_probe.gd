extends Node
## Debug harness for Cozy Island (Test): boots it and photographs it from
## free cameras, printing the frame rate with each. Run windowed:
##   godot --path game res://world/cozy_test_probe.tscn
## WORLDBUILDER_CTEST_SHOTS=name,name limits it to those views;
## WORLDBUILDER_CTEST_VIEWS=name:fov:x,y,z:tx,ty,tz;... takes its own;
## WORLDBUILDER_CTEST_SET=Title=value;... sets panel switches (0/1) and
## sliders by title. "camp" views are in the campsite's frame (x along
## the shore, z out to sea), the rest in the world's.

## name, fov, camera, target, frame.
const VIEWS := [
	["island", 55.0, Vector3(70.0, 45.0, 90.0), Vector3(0.0, 2.0, 5.0), ""],
	["arrive", 62.0, Vector3(1.5, 1.7, -4.5), Vector3(1.5, 6.0, -32.0), "camp"],
	["camp", 60.0, Vector3(5.0, 2.4, 4.5), Vector3(-1.2, 0.5, -0.8), "camp"],
	["tent", 55.0, Vector3(0.3, 1.5, 1.6), Vector3(-2.7, 0.6, -1.5), "camp"],
	["fire", 55.0, Vector3(2.0, 1.3, 2.6), Vector3(0.0, 0.3, 0.8), "camp"],
	["mill", 58.0, Vector3(-15.0, 2.9, 15.0), Vector3(0.0, 9.0, 0.0), ""],
	["mill_door", 60.0, Vector3(0.0, 2.9, 9.0), Vector3(0.0, 3.0, 0.0), ""],
	["mill_side", 58.0, Vector3(-20.0, 3.0, -8.0), Vector3(0.0, 8.0, 0.0), ""],
	["mill_back", 58.0, Vector3(14.0, 3.0, -14.0), Vector3(0.0, 10.0, 0.0), ""],
	["sails", 50.0, Vector3(-9.0, 9.0, 9.0), Vector3(0.0, 11.5, 0.0), ""],
	["ground_floor", 70.0, Vector3(-0.4, 3.3, 1.9), Vector3(1.0, 2.2, -1.2), ""],
	["ground_up", 70.0, Vector3(0.4, 2.6, 1.7), Vector3(0.0, 4.4, -0.2), ""],
	["bench", 60.0, Vector3(0.3, 3.1, -0.5), Vector3(0.0, 2.4, -1.9), ""],
	["stairs", 70.0, Vector3(0.6, 3.0, 2.0), Vector3(-1.3, 3.6, -0.6), ""],
	["bin_floor", 70.0, Vector3(0.9, 5.8, 1.0), Vector3(-1.0, 4.7, -1.0), ""],
	["stone_floor", 70.0, Vector3(-0.9, 8.1, -0.9), Vector3(0.9, 7.2, 1.0), ""],
	["dust_floor", 70.0, Vector3(1.0, 10.2, -0.9), Vector3(-0.4, 11.0, 0.5), ""],
	["gasworks", 60.0, Vector3(2.0, 3.5, 10.0), Vector3(8.0, 2.0, 0.5), ""],
	["holders", 60.0, Vector3(15.0, 3.2, -7.0), Vector3(8.0, 2.5, 1.0), ""],
]

var _world: CozyTest


func _ready() -> void:
	MouseMode.probe = true
	_world = (load("res://world/cozy_test.tscn") as PackedScene).instantiate()
	add_child(_world)
	_run()


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	_world.player.visible = false
	_world.player.process_mode = Node.PROCESS_MODE_DISABLED
	_world.player.global_position = Vector3(0, -20, 0)
	var panel := _world.find_children("*", "BenchPanel", true, false)[0] as BenchPanel
	var sets := OS.get_environment("WORLDBUILDER_CTEST_SET")
	if sets != "":
		for pair: String in sets.split(";"):
			var kv := pair.split("=")
			if panel.switches.has(kv[0]):
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
	var custom := OS.get_environment("WORLDBUILDER_CTEST_VIEWS")
	if custom != "":
		views = []
		for v: String in custom.split(";"):
			var parts := v.split(":")
			var p := parts[2].split_floats(",")
			var t := parts[3].split_floats(",")
			views.append([parts[0], float(parts[1]), Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2]),
					parts[4] if parts.size() > 4 else ""])
	var only := OS.get_environment("WORLDBUILDER_CTEST_SHOTS")
	for v: Array in views:
		if only != "" and not (str(v[0]) in only.split(",")):
			continue
		cam.fov = float(v[1])
		var eye: Vector3 = v[2]
		var target: Vector3 = v[3]
		if str(v[4]) == "camp":
			# Heights over the ground at the campsite.
			eye = _world.campsite.to_global(eye)
			target = _world.campsite.to_global(target)
			eye.y += _world.height(eye.x, eye.z)
			target.y += _world.height(target.x, target.z)
		cam.global_position = eye
		cam.look_at(target)
		await get_tree().create_timer(1.0).timeout
		var frames := Engine.get_frames_drawn()
		var t0 := Time.get_ticks_usec()
		await get_tree().create_timer(2.0).timeout
		var fps := float(Engine.get_frames_drawn() - frames) / ((Time.get_ticks_usec() - t0) * 1e-6)
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://ctest_%s.png" % v[0])
		print("[ctest_probe] %s  %.1f fps" % [v[0], fps])
	get_tree().quit()
