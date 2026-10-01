extends Node
## Debug harness for the meadow: boots the world and photographs it
## from free cameras at chosen hours, printing the frame rate with each.
## Run windowed:
##   godot --path game res://world/meadow_probe.tscn
## WORLDBUILDER_MEADOW_SHOTS=name,name limits it to those views;
## WORLDBUILDER_MEADOW_VIEWS=name:hour:fov:x,y,z:tx,ty,tz;... takes its
## own (heights over the ground); WORLDBUILDER_MEADOW_PRESET picks the
## graphics preset (Medium by default); WORLDBUILDER_MEADOW_STYLES=0,1,...
## photographs each view in those picture styles (style.gdshader).

## name, hour, fov, camera (x, height over ground, z), target (x, height over ground, z).
const VIEWS := [
	["afternoon", 17.0, 60.0, Vector3(26.0, 1.6, 12.0), Vector3(-24.0, 5.0, -18.0)],
	["noon", 12.0, 60.0, Vector3(26.0, 1.6, 12.0), Vector3(-24.0, 5.0, -18.0)],
	["valley", 15.5, 60.0, Vector3(10.0, 1.6, 60.0), Vector3(-5.0, 2.0, -40.0)],
	["brook", 15.0, 60.0, Vector3(14.0, 1.5, 22.0), Vector3(9.0, -0.6, 30.0)],
	["grass", 16.0, 60.0, Vector3(30.0, 0.9, -10.0), Vector3(20.0, 0.4, -16.0)],
	["dawn", 5.8, 60.0, Vector3(26.0, 1.6, 12.0), Vector3(-24.0, 5.0, -18.0)],
	["dusk", 18.8, 60.0, Vector3(26.0, 1.6, 12.0), Vector3(-24.0, 3.0, -18.0)],
	["night", 22.5, 60.0, Vector3(26.0, 1.6, 12.0), Vector3(-24.0, 5.0, -18.0)],
]

var _world: MeadowMap


func _ready() -> void:
	MouseMode.probe = true
	var world: MeadowMap = (load("res://world/meadow.tscn") as PackedScene).instantiate()
	add_child(world)
	_world = world
	_run(world)


func _run(world: MeadowMap) -> void:
	await get_tree().create_timer(5.0).timeout
	var preset := OS.get_environment("WORLDBUILDER_MEADOW_PRESET")
	world.graphics.set_preset(preset if preset != "" else "Medium")
	world.graphics.apply(world)
	for layer: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	world.player.visible = false
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var views: Array = VIEWS
	var custom := OS.get_environment("WORLDBUILDER_MEADOW_VIEWS")
	if custom != "":
		views = []
		for v: String in custom.split(";"):
			var parts := v.split(":")
			var p := parts[3].split_floats(",")
			var t := parts[4].split_floats(",")
			views.append([parts[0], float(parts[1]), float(parts[2]), Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2])])
	# WORLDBUILDER_MEADOW_HIDE=Grass,Wood,... hides the world's parts by
	# node name, to see what each costs.
	var hide := OS.get_environment("WORLDBUILDER_MEADOW_HIDE")
	if hide != "":
		for part: String in hide.split(","):
			for node in world.find_children(part, "", true, false):
				(node as Node3D).visible = false
	var styles: Array[int] = [-1]
	var style_mat: ShaderMaterial = null
	if OS.get_environment("WORLDBUILDER_MEADOW_STYLES") != "":
		styles.clear()
		for n: String in OS.get_environment("WORLDBUILDER_MEADOW_STYLES").split(","):
			styles.append(int(n))
		var layer := CanvasLayer.new()
		add_child(layer)
		var rect := ColorRect.new()
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		style_mat = ShaderMaterial.new()
		style_mat.shader = load("res://world/style.gdshader")
		rect.material = style_mat
		layer.add_child(rect)
	var only := OS.get_environment("WORLDBUILDER_MEADOW_SHOTS")
	for v: Array in views:
		if only != "" and not (str(v[0]) in only.split(",")):
			continue
		world.set_time_of_day(float(v[1]))
		cam.fov = float(v[2])
		var at: Vector3 = v[3]
		var to: Vector3 = v[4]
		at.y += world.land.height_at(at.x, at.z)
		to.y += world.land.height_at(to.x, to.z)
		cam.look_at_from_position(at, to, Vector3.UP)
		for st in styles:
			if st < 0:
				await _shot("probe_meadow_%s" % v[0])
			else:
				style_mat.set_shader_parameter("style", st)
				await _shot("probe_meadow_%s_style%d" % [v[0], st])
	get_tree().quit()


## Settle, photograph, then time two seconds of frames.
func _shot(name: String) -> void:
	for i in 60:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://%s.png" % name)
	var t0 := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - t0 < 2000000:
		await RenderingServer.frame_post_draw
		frames += 1
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / frames
	print("[probe] %s written, %.1f ms a frame (%.0f fps), %.2f M primitives, %d draws" % [name, ms, 1000.0 / ms,
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1.0e6,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
