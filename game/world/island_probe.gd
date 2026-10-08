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
	["dock", 60.0, Vector3(4.0, 2.2, 56.0), Vector3(0.0, 3.0, 10.0), "dock"],
	["beach", 60.0, Vector3(-28.0, 1.8, 32.0), Vector3(4.0, 2.0, 20.0), "cabin"],
	["clouds", 70.0, Vector3(30.0, 1.7, 60.0), Vector3(-200.0, 260.0, -700.0), "ground"],
	["clouds_sea", 70.0, Vector3(4.0, 1.7, 150.0), Vector3(200.0, 200.0, 1500.0), "ground"],
	["booth0", 62.0, Vector3(0.0, 1.6, -4.6), Vector3(0.0, 1.6, -0.6), "booth0"],
	["booth1", 62.0, Vector3(0.0, 1.6, -4.6), Vector3(0.0, 1.6, -0.6), "booth1"],
	["booth2", 62.0, Vector3(0.0, 1.6, -4.6), Vector3(0.0, 1.6, -0.6), "booth2"],
	["booth3", 62.0, Vector3(0.0, 1.6, -4.6), Vector3(0.0, 1.6, -0.6), "booth3"],
	["booth4", 62.0, Vector3(0.0, 1.6, -4.6), Vector3(0.0, 1.6, -0.6), "booth4"],
	["booth5", 62.0, Vector3(0.0, 1.6, -4.6), Vector3(0.0, 1.6, -0.6), "booth5"],
	["booth6", 62.0, Vector3(0.0, 1.6, -4.6), Vector3(0.0, 1.6, -0.6), "booth6"],
	["booth7", 62.0, Vector3(0.0, 1.6, -4.6), Vector3(0.0, 1.6, -0.6), "booth7"],
	["expo", 60.0, Vector3(-6.0, 7.0, -22.0), Vector3(14.0, 1.0, 0.0), "booth2"],
	["expo_walk", 66.0, Vector3(-4.0, 1.6, -10.5), Vector3(20.0, 1.6, -3.0), "booth3"],
	["island", 55.0, Vector3(60.0, 330.0, 420.0), Vector3(0.0, 0.0, -10.0), ""],
	["meadow", 65.0, Vector3(30.0, 1.7, 60.0), Vector3(-40.0, 1.0, 0.0), "ground"],
	["meadow_west", 65.0, Vector3(-60.0, 1.7, 90.0), Vector3(-90.0, 1.0, 20.0), "ground"],
	["woods", 60.0, Vector3(80.0, 1.7, -10.0), Vector3(20.0, 2.0, -40.0), "ground"],
	["cabin_back", 60.0, Vector3(-20.0, 3.0, 85.0), Vector3(4.0, 2.0, 119.0), "ground"],
	["above", 50.0, Vector3(70.0, 35.0, 90.0), Vector3(0.0, 0.0, 5.0), "scale"],
	["hill", 60.0, Vector3(-32.0, 2.0, 8.0), Vector3(-32.0, 6.0, -25.0), "ground"],
	["fire", 60.0, Vector3(-6.5, 1.7, 44.0), Vector3(-10.4, 0.6, 38.0), "fire"],
	["flames", 50.0, Vector3(-9.0, 1.3, 40.6), Vector3(-10.4, 0.5, 38.0), "fire"],
	["works", 60.0, Vector3(59.6, 9.0, -5.5), Vector3(37.2, 2.0, -12.0), "salt"],
	["works_near", 70.0, Vector3(32.9, 3.0, -4.6), Vector3(40.3, 1.8, -11.8), "salt"],
	["works_mill", 60.0, Vector3(44.9, 1.7, -14.0), Vector3(26.7, 5.0, -16.4), "salt"],
	["colours", 60.0, Vector3(-30.0, 8.0, -49.8), Vector3(-23.8, 2.0, -32.2), "colour"],
	["colours_near", 70.0, Vector3(-17.9, 3.8, -29.0), Vector3(-25.2, 2.5, -32.5), "colour"],
	["colours_reactor", 70.0, Vector3(-21.5, 3.0, -30.7), Vector3(-25.2, 2.2, -32.5), "colour"],
	["balloon", 60.0, Vector3(-58.7, 7.0, 12.4), Vector3(-41.4, 6.0, 7.3), "balloon"],
	["balloon_ground", 65.0, Vector3(-38.4, 2.2, 12.9), Vector3(-41.4, 14.0, 7.3), "balloon"],
	["balloon_sky", 70.0, Vector3(-38.4, 2.2, 12.9), Vector3(-60.0, 240.0, 0.0), "balloon"],
	["lagoon", 60.0, Vector3(29.5, 18.0, 0.9), Vector3(65.8, 0.0, 38.0), "lagoon"],
	["wharf", 70.0, Vector3(46.7, 2.8, 27.0), Vector3(74.4, 1.5, 43.0), "lagoon"],
	["pool", 65.0, Vector3(50.9, 2.6, 31.7), Vector3(47.4, 0.5, 33.85), "lagoon"],
	["mills", 55.0, Vector3(95.0, 6.0, 52.0), Vector3(386.0, 20.0, 223.0), "lagoon"],
	["cart", 60.0, Vector3(41.0, 3.4, 19.0), Vector3(40.0, 1.2, 25.0), "lagoon"],
	["fish", 30.0, Vector3(10.0, 9.0, -68.0), Vector3(10.0, -0.5, -58.0), "bay"],
	["north", 60.0, Vector3(45.0, 48.0, -15.0), Vector3(0.0, 0.0, -80.0), "bay"],
	["bay", 65.0, Vector3(-2.0, 4.0, -50.0), Vector3(10.0, -0.5, -58.0), "bay"],
	["bay_low", 60.0, Vector3(4.0, 1.6, -48.0), Vector3(9.0, -0.6, -55.0), "bay"],
	["spit", 65.0, Vector3(-33.0, 2.1, -81.0), Vector3(-47.0, 0.0, -117.0), "bay"],
	["crabs", 55.0, Vector3(1.0, 3.0, -71.0), Vector3(10.0, -0.4, -58.0), "bay"],
	["works_yard", 70.0, Vector3(32.1, 2.7, -11.65), Vector3(37.2, 3.0, -12.0), "salt"],
	["works_pan", 65.0, Vector3(37.8, 2.6, -7.8), Vector3(41.2, 1.3, -8.7), "salt"],
	["lanterns", 65.0, Vector3(2.0, 2.2, 33.0), Vector3(4.0, 2.4, 20.0), "cabin"],
]

## Where each view's subject stood when the view was set, so a view
## follows its subject when the island changes: [name, fov, eye, target,
## anchor], the eye and target moved by the anchor's shift ("scale"
## stretches them with the island instead).
const ANCHORS_THEN := {"salt": Vector3(38.55, 0, -12.40), "colour": Vector3(-25.03, 0, -34.01),
		"balloon": Vector3(-39.83, 0, 6.51), "lagoon": Vector3(29.85, 0, 17.23), "fire": Vector3(-10.22, 0, 38.15),
		"dock": Vector3(4.0, 0, 56.33), "cabin": Vector3(4.0, 0, 20.0), "sky": Vector3(-10.0, 0, -8.0),
		"bay": Vector3(10.0, 0, -58.0)}

var _world: CozyIsland


func _ready() -> void:
	MouseMode.probe = true
	_world = (load("res://world/cozy_island.tscn") as PackedScene).instantiate()
	add_child(_world)
	_run()


func _anchor(name: String) -> Vector3:
	match name:
		"salt": return SaltWorks.centre(_world)
		"colour": return ColourWorks.centre(_world)
		"balloon": return BalloonWorks.centre(_world)
		"lagoon": return LagoonWorks.centre(_world)
		"fire": return _world.get("_fire_at")
		"dock": return Vector3(CozyIsland.DOCK_X, 0.0, _world.get("_dock_z1"))
		"cabin": return _world.cabin
		"sky": return Vector3(CozyIsland.HILL.x, 0.0, CozyIsland.HILL.y)
		"bay": return Vector3(CozyIsland.BAY.x, 0.0, CozyIsland.BAY.y)
	return Vector3.ZERO


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
		var eye: Vector3 = v[2]
		var target: Vector3 = v[3]
		if v.size() > 4 and v[4] != "":
			if str(v[4]).begins_with("booth"):
				# Given in the exposition booth's own frame (x along the
				# shore, z inland).
				var expo := _world.find_children("*", "CrystalExpo", true, false)[0] as CrystalExpo
				var booth: Node3D = expo.get("_booths")[int(str(v[4]).substr(5))]
				eye = booth.to_global(eye)
				target = booth.to_global(target)
			elif v[4] == "ground":
				# Heights given over the ground under the eye and the target.
				eye.y += maxf(_world.height(eye.x, eye.z), 0.0)
				target.y += maxf(_world.height(target.x, target.z), 0.0)
			elif v[4] == "scale":
				eye *= Vector3(3.17, 3.0, 3.17)
				target *= Vector3(3.17, 3.0, 3.17)
			else:
				var shift: Vector3 = _anchor(str(v[4])) - (ANCHORS_THEN[v[4]] as Vector3)
				shift.y = 0.0
				eye += shift
				target += shift
				# Never below eye height over the ground there now.
				var ground := maxf(_world.height(eye.x, eye.z), 0.0)
				eye.y = maxf(eye.y, ground + 1.6)
		cam.global_position = eye
		cam.look_at(target)
		await get_tree().create_timer(1.0).timeout
		var frames := Engine.get_frames_drawn()
		var t0 := Time.get_ticks_usec()
		await get_tree().create_timer(2.0).timeout
		var fps := float(Engine.get_frames_drawn() - frames) / ((Time.get_ticks_usec() - t0) * 1e-6)
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://island_%s.png" % v[0])
		print("[island_probe] %s  %.1f fps" % [v[0], fps])
	get_tree().quit()
