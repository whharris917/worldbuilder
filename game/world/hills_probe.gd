extends Node
## Debug harness for the grass hills: boots the world and photographs
## it from free cameras at chosen hours, printing the frame rate with
## each. Run windowed:
##   godot --path game res://world/hills_probe.tscn
## WORLDBUILDER_HILLS_SHOTS=name,name limits it to those views;
## WORLDBUILDER_HILLS_VIEWS=name:hour:fov:x,y,z:tx,ty,tz;... takes its
## own (heights over the ground); WORLDBUILDER_HILLS_PRESET picks the
## graphics preset (Medium by default); WORLDBUILDER_HILLS_GRASS the
## grass's model; WORLDBUILDER_HILLS_DRIVE=1 drives the truck. Two views follow the world: "start", where the
## player arrives, and "edge", at the pond's edge looking across it;
## "house" the farmhouse from its yard, "parlor" the parlour through the front door,
## "inside" in it at eye height, "kitchen" the kitchen; "lane" down
## the driveway, "road" along the road a way off.

## name, hour, fov, camera (x, height over ground, z), target (x, height over ground, z).
const VIEWS := [
	["upwind", 15.0, 60.0, Vector3(0.0, 1.6, 0.0), Vector3(-80.0, 0.0, -60.0)],
	["across", 15.0, 60.0, Vector3(0.0, 1.6, 0.0), Vector3(-60.0, 0.0, 80.0)],
	["high", 15.0, 60.0, Vector3(0.0, 6.0, 0.0), Vector3(-80.0, 0.0, -60.0)],
	["evening", 19.0, 60.0, Vector3(0.0, 1.6, 0.0), Vector3(-80.0, 0.0, -60.0)],
	["pond", 15.0, 60.0, Vector3(0.0, 1.6, 0.0), Vector3(-31.0, 0.0, -45.0)],
	["pond_above", 15.0, 60.0, Vector3(-5.0, 10.0, -20.0), Vector3(-31.0, 0.0, -45.0)],
	["pond_shore", 15.0, 60.0, Vector3(-14.0, 1.6, -30.0), Vector3(-34.0, 0.0, -48.0)],
	["start", 15.0, 60.0, Vector3.ZERO, Vector3.ZERO],
	["edge", 15.0, 60.0, Vector3.ZERO, Vector3.ZERO],
	["house", 15.0, 60.0, Vector3.ZERO, Vector3.ZERO],
	["parlor", 15.0, 60.0, Vector3.ZERO, Vector3.ZERO],
	["kitchen", 15.0, 60.0, Vector3.ZERO, Vector3.ZERO],
	["inside", 15.0, 60.0, Vector3.ZERO, Vector3.ZERO],
	["lane", 15.0, 60.0, Vector3.ZERO, Vector3.ZERO],
	["truck", 15.0, 60.0, Vector3.ZERO, Vector3.ZERO],
	["road", 15.0, 60.0, Vector3.ZERO, Vector3.ZERO],
]


func _ready() -> void:
	MouseMode.probe = true
	# WORLDBUILDER_HILLS_STYLE=anime photographs the painted hills.
	var scene := "res://world/grass_hills_painted.tscn" if OS.get_environment("WORLDBUILDER_HILLS_STYLE") == "anime" else "res://world/grass_hills.tscn"
	var world: GrassHills = (load(scene) as PackedScene).instantiate()
	add_child(world)
	_run(world)


func _run(world: GrassHills) -> void:
	await get_tree().create_timer(5.0).timeout
	var preset := OS.get_environment("WORLDBUILDER_HILLS_PRESET")
	world.graphics.set_preset(preset if preset != "" else "Medium")
	world.graphics.apply(world)
	# WORLDBUILDER_HILLS_SKY=n: the air, as in the options' Sky row.
	if OS.get_environment("WORLDBUILDER_HILLS_SKY") != "":
		world._apply_sky(int(OS.get_environment("WORLDBUILDER_HILLS_SKY")))
	if OS.get_environment("WORLDBUILDER_HILLS_GRASS") != "":
		world.grass.set_model(OS.get_environment("WORLDBUILDER_HILLS_GRASS"))
	for layer: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	world.player.visible = false
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var views: Array = VIEWS
	var custom := OS.get_environment("WORLDBUILDER_HILLS_VIEWS")
	if custom != "":
		views = []
		for v: String in custom.split(";"):
			var parts := v.split(":")
			var p := parts[3].split_floats(",")
			var t := parts[4].split_floats(",")
			views.append([parts[0], float(parts[1]), float(parts[2]), Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2])])
	# WORLDBUILDER_HILLS_DRIVE=1: get into the truck, drive it down the
	# lane with the throttle open, steering a little, and photograph from
	# the seat and from behind, printing its speed.
	if OS.get_environment("WORLDBUILDER_HILLS_DRIVE") == "1":
		world.set_time_of_day(15.0)
		cam.current = false
		world.truck.use()
		Input.action_press("move_forward")
		for i in 7:
			await get_tree().create_timer(1.0).timeout
			print("[probe] driving %d s: %.1f m/s at %s" % [i + 1, world.truck.linear_velocity.length(), str(world.truck.global_position)])
		await _shot("probe_hills_drive_seat")
		world.truck._chase = true
		world.truck._chase_cam.current = true
		await _shot("probe_hills_drive_behind")
		Input.action_release("move_forward")
		get_tree().quit()
		return
	var only := OS.get_environment("WORLDBUILDER_HILLS_SHOTS")
	for v: Array in views:
		if only != "" and not (str(v[0]) in only.split(",")):
			continue
		world.set_time_of_day(float(v[1]))
		cam.fov = float(v[2])
		var at: Vector3 = v[3]
		var to: Vector3 = v[4]
		at.y += world.land.height_at(at.x, at.z)
		to.y += world.land.height_at(to.x, to.z)
		if v[0] == "start":
			at = world.player.global_position + Vector3.UP * 1.2
			to = at - world.player.global_basis.z * 40.0 + Vector3.DOWN * 6.0
		elif v[0] in ["house", "parlor", "kitchen", "inside"]:
			# The farmhouse from the yard, and its rooms from inside, in its
			# own frame (metres, +x its front).
			var b: Node3D = world.house
			var rooms := {
				"house": [Vector3(16.0, 1.6, 9.0), Vector3(0.0, 3.0, -2.5)],
				"parlor": [Vector3(4.6, 2.2, -0.2), Vector3(-2.5, 1.6, 3.5)],
				"kitchen": [Vector3(0.0, 2.2, -4.9), Vector3(0.0, 1.5, -9.0)],
				"inside": [Vector3(2.4, 2.2, 0.5), Vector3(-1.0, 1.4, 3.9)],
			}
			var pair: Array = rooms[v[0]]
			at = b.to_global(pair[0])
			to = b.to_global(pair[1])
		elif v[0] == "truck":
			# The pickup from in front and to its left.
			var tr: Node3D = world.truck
			at = tr.to_global(Vector3(3.5, 1.6, 6.0))
			to = tr.to_global(Vector3(0.0, 1.0, 0.0))
		elif v[0] == "lane" or v[0] == "road":
			# "lane": from the back of the yard along the driveway to the
			# road; "road": on the road a way off, looking along it.
			var land: HillsLand = world.land
			if v[0] == "lane":
				var a2: Vector2 = land.drive_pts[0]
				var b2: Vector2 = land.drive_pts[land.drive_pts.size() - 1]
				at = Vector3(a2.x, land.height_at(a2.x, a2.y) + 1.6, a2.y)
				to = Vector3(b2.x, land.height_at(b2.x, b2.y) + 1.0, b2.y)
			else:
				var k := mini(land.road_pts.size() - 1, land.road_pts.size() / 2 + 60)
				var a2: Vector2 = land.road_pts[k]
				var b2: Vector2 = land.road_pts[mini(land.road_pts.size() - 1, k + 40)]
				at = Vector3(a2.x, land.height_at(a2.x, a2.y) + 1.6, a2.y)
				to = Vector3(b2.x, land.height_at(b2.x, b2.y) + 1.0, b2.y)
		elif v[0] == "edge":
			var pond: Vector2 = world.land.lake_centre
			var from := Vector2(world.player.global_position.x, world.player.global_position.z)
			var q := from
			while world.land.height_at(q.x, q.y) > world.land.lake_level + 0.4 and q.distance_to(pond) > 2.0:
				q = q.move_toward(pond, 0.5)
			at = Vector3(q.x, world.land.height_at(q.x, q.y) + 1.6, q.y)
			to = Vector3(pond.x, world.land.lake_level - 1.5, pond.y)
		cam.look_at_from_position(at, to, Vector3.UP)
		await _shot("probe_hills_%s" % v[0])
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
