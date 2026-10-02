class_name HillsLand
extends Landscape
## Open rolling hills of long grass: no trees, no water, no stones.
## Long low swells with smaller rolls on them, the land rising gently
## toward the horizon all round so the edge of the world is always a
## far hillside. The ground is hills_ground.gdshader.

var _n: FastNoiseLite


func _init() -> void:
	centre = Vector3.ZERO
	sea_level = -500.0
	tide_range = 0.0
	seed = 20261010
	cell = 1.0
	grid_n = 600
	mesh_reach = 1800.0
	ground_shader = "res://world/hills_ground.gdshader"
	_n = FastNoiseLite.new()
	_n.seed = seed
	_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n.frequency = 1.0


func height_at(x: float, z: float) -> float:
	var h := 16.0 * _n.get_noise_2d(x * 0.0035, z * 0.0035) \
		+ 6.0 * _n.get_noise_2d(x * 0.011 + 40.0, z * 0.011) \
		+ 1.2 * _n.get_noise_2d(x * 0.035 + 90.0, z * 0.035)
	var r := Vector2(x, z).length()
	return h + 0.00003 * pow(maxf(r - 250.0, 0.0), 2.0)


## Grass everywhere.
func grass_at(_x: float, _z: float) -> float:
	return 1.0


func coast_distance(_x: float, _z: float) -> float:
	return 1000.0


func _build_sea() -> void:
	pass


func _build_rocks() -> void:
	pass


func _build_forest() -> void:
	stats["trees"] = 0


## The sounds are the world's (GrassHills).
func _build_sound() -> void:
	pass
