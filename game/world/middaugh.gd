extends OutdoorWorld
class_name MiddaughMap
## Clarendon Hills, Illinois: the Henry C. Middaugh house (1888-1892),
## generated from its data file (game/data/buildings/middaugh.json) and
## checked by tools/building/build.py, on open ground. Its own save.

var built: BuildingMesh


func _init() -> void:
	super()
	save_path = "user://save_middaugh.json"
	settings_prefix = "middaugh_"
	time_of_day = 10.0


func _build_ground() -> void:
	super()
	# A plain lawn to the woods: the house's foundation stands into it.
	var lawn := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(440.0, 440.0)
	lawn.mesh = plane
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.26, 0.31, 0.18)
	grass.roughness = 1.0
	lawn.material_override = grass
	add_child(lawn)
	built = BuildingMesh.open("res://data/buildings/middaugh.bld")
	# The data's plans run x south and z west; turned half round, the
	# house's front faces south in the world.
	built.rotation.y = PI
	add_child(built)


func _after_build() -> void:
	if not FileAccess.file_exists(save_path):
		# Out on the lawn to the south-east, looking at the front door,
		# the porch and the tower.
		player.global_position = Vector3(13.4, 0.3, 17.1)
		player.rotation.y = 0.665
	hud.toast("Clarendon Hills, Illinois: the Middaugh house, from its survey drawings. O options · F5/F9 save/load")
	print("[worldbuilder] middaugh house from its data: %d faces, %d triangles, loaded in %d ms%s"
		% [int(built.stats.get("faces", 0)), int(built.stats.get("triangles", 0)), int(built.stats.get("ms", 0)),
		" (BROKEN: it fails its checks)" if built.broken else ""])
	if DisplayServer.get_name() == "headless":
		_report_in = 20
