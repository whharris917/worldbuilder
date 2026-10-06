extends Node
## Debug harness for the shifting room: boots it and photographs it from free
## cameras, printing the frame rate with each. Run windowed:
##   godot --path game res://world/shifting_probe.tscn
## WORLDBUILDER_SHIFT_SHOTS=name,name limits it to those views;
## WORLDBUILDER_SHIFT_VIEWS=name:fov:x,y,z:tx,ty,tz;... takes its own;
## WORLDBUILDER_SHIFT_SET=Title=value;... sets panel switches (0/1),
## sliders and choices (Title=Option) by title;
## WORLDBUILDER_SHIFT_CLOCK=s sets the eye's clock (it is out and open
## from 11 s).

## name, fov, camera, target.
const VIEWS := [
	["platform", 75.0, Vector3(0.0, 13.6, 1.4), Vector3(0.0, 11.0, -12.0)],
	["down", 80.0, Vector3(1.4, 13.6, 1.4), Vector3(-6.0, 0.0, -6.0)],
	["up", 80.0, Vector3(0.0, 13.6, 1.4), Vector3(-4.0, 24.0, -10.0)],
	["floor", 75.0, Vector3(10.0, 1.6, 10.0), Vector3(0.0, 11.0, 0.0)],
]

var _world: ShiftingRoom


func _ready() -> void:
	MouseMode.probe = true
	_world = (load("res://world/shifting_room.tscn") as PackedScene).instantiate()
	add_child(_world)
	_run()


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	_world.player.visible = false
	_world.player.process_mode = Node.PROCESS_MODE_DISABLED
	_world.player.global_position = Vector3(0, -20, 0)
	var panel := _world.find_children("*", "BenchPanel", true, false)[0] as BenchPanel
	var sets := OS.get_environment("WORLDBUILDER_SHIFT_SET")
	if sets != "":
		for pair: String in sets.split(";"):
			var kv := pair.split("=")
			if panel.switches.has(kv[0]):
				(panel.switches[kv[0]] as CheckButton).button_pressed = kv[1] == "1"
			elif panel.sliders.has(kv[0]):
				(panel.sliders[kv[0]] as HSlider).value = float(kv[1])
			elif panel.choices.has(kv[0]):
				panel.pick(kv[0], kv[1])
	if OS.get_environment("WORLDBUILDER_SHIFT_CLOCK") != "":
		_world.eye_clock = float(OS.get_environment("WORLDBUILDER_SHIFT_CLOCK"))
	await get_tree().create_timer(1.0).timeout
	for layer: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var views: Array = VIEWS
	var custom := OS.get_environment("WORLDBUILDER_SHIFT_VIEWS")
	if custom != "":
		views = []
		for v: String in custom.split(";"):
			var parts := v.split(":")
			var p := parts[2].split_floats(",")
			var t := parts[3].split_floats(",")
			views.append([parts[0], float(parts[1]), Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2])])
	var only := OS.get_environment("WORLDBUILDER_SHIFT_SHOTS")
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
		img.save_png("user://shift_%s.png" % v[0])
		print("[shift_probe] %s  %.1f fps" % [v[0], fps])
	get_tree().quit()
