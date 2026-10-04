extends Node
## Debug harness for the light pool room: boots it and photographs it
## from free cameras, printing the frame rate with each. Run windowed:
##   godot --path game res://world/pool_probe.tscn
## WORLDBUILDER_POOL_SHOTS=name,name limits it to those views;
## WORLDBUILDER_POOL_VIEWS=name:fov:x,y,z:tx,ty,tz;... takes its own;
## WORLDBUILDER_POOL_OFF=gi,shadow,glow switches those parts off, to see
## what each costs.

## name, fov, camera, target.
const VIEWS := [
	["deck", 60.0, Vector3(-2.5, 1.6, 4.4), Vector3(0.0, 1.5, -5.0)],
	["ceiling", 70.0, Vector3(3.5, 1.6, 4.2), Vector3(-1.0, 10.0, -2.0)],
	["opening", 60.0, Vector3(4.4, 1.6, 4.4), Vector3(0.0, -2.5, -0.5)],
	["corner", 75.0, Vector3(4.6, 8.5, 4.6), Vector3(-3.0, 0.0, -3.0)],
	["stair", 70.0, Vector3(4.6, 1.6, 3.6), Vector3(0.0, -2.2, 4.5)],
	["chamber", 75.0, Vector3(-1.5, -1.6, 4.5), Vector3(2.0, -2.0, -3.0)],
	["under", 75.0, Vector3(-4.0, -1.6, -4.0), Vector3(1.0, -0.8, 1.0)],
]

var _world: LightPool


func _ready() -> void:
	MouseMode.probe = true
	_world = (load("res://world/light_pool.tscn") as PackedScene).instantiate()
	add_child(_world)
	_run()


func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	_world.player.visible = false
	var off := OS.get_environment("WORLDBUILDER_POOL_OFF").split(",")
	for n: Node in _world.find_children("*", "", true, false):
		if "gi" in off and n is VoxelGI:
			(n as VoxelGI).visible = false
		if "shadow" in off and n is OmniLight3D:
			(n as OmniLight3D).shadow_enabled = false
	if "glow" in off:
		(_world.get_node("WorldEnvironment") as WorldEnvironment).environment.glow_enabled = false
	for layer: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var views: Array = VIEWS
	var custom := OS.get_environment("WORLDBUILDER_POOL_VIEWS")
	if custom != "":
		views = []
		for v: String in custom.split(";"):
			var parts := v.split(":")
			var p := parts[2].split_floats(",")
			var t := parts[3].split_floats(",")
			views.append([parts[0], float(parts[1]), Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2])])
	var only := OS.get_environment("WORLDBUILDER_POOL_SHOTS")
	for v: Array in views:
		if only != "" and not (str(v[0]) in only.split(",")):
			continue
		cam.fov = float(v[1])
		cam.global_position = v[2]
		cam.look_at(v[3])
		await get_tree().create_timer(1.0).timeout
		var frames := Engine.get_frames_drawn()
		var t0 := Time.get_ticks_usec()
		await get_tree().create_timer(3.0).timeout
		var fps := float(Engine.get_frames_drawn() - frames) / ((Time.get_ticks_usec() - t0) * 1e-6)
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://pool_%s.png" % v[0])
		print("[pool_probe] %s  %.1f fps" % [v[0], fps])
	get_tree().quit()
