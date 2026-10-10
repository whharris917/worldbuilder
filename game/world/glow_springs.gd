class_name GlowSprings
extends Node3D
## The springs of the south-east plain's hills (CozyIsland.spring_hills):
## in the hollow at each hill's top a pool of glowing liquid, each its own
## colour (SPRING_COLOURS), brimming over a ring of stones, and a rivulet
## of it running down the hill toward the plain by the steepest way. A
## soft light of the pool's colour hangs over each, stronger as the day
## goes. The pools breathe a little in brightness, each at its own pace.
##
## Engine features only: standard materials glowing by their emission,
## omni lights without shadows, the rivulets ribbons laid on the ground.
## The notes over the pools are drafts.

var island: CozyIsland
var _pools: Array[StandardMaterial3D] = []
var _lights: Array[OmniLight3D] = []
var _clock := 0.0


func _init(owner_island: CozyIsland) -> void:
	island = owner_island
	name = "GlowSprings"


func _ready() -> void:
	var stone := island.surface("rough_rock", 0.4, Color(0.8, 0.78, 0.76), 0.9, Color(0.68, 0.68, 0.74))
	var centre := Vector3.ZERO
	for hill: Vector4 in island.spring_hills:
		centre += Vector3(hill.x, 0.0, hill.y)
	centre /= maxf(island.spring_hills.size(), 1)
	for i in island.spring_hills.size():
		var hill := island.spring_hills[i]
		var colour: Color = CozyIsland.SPRING_COLOURS[i % CozyIsland.SPRING_COLOURS.size()]
		var at := Vector3(hill.x, 0.0, hill.y)
		# The pool brims just below the lowest point of the hollow's rim.
		var rim := INF
		for k in 16:
			var a := TAU * k / 16.0
			var q := at + Vector3(cos(a), 0, sin(a)) * CozyIsland.SPRING_BOWL
			rim = minf(rim, island.height(q.x, q.z))
		var level := maxf(rim - 0.12, island.spring_tops[i] - CozyIsland.SPRING_DEPTH + 0.3)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(colour.darkened(0.55), 0.92)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.05
		mat.emission_enabled = true
		mat.emission = colour
		mat.emission_energy_multiplier = 1.6
		_pools.append(mat)
		var pool := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = CozyIsland.SPRING_BOWL - 0.15
		disc.bottom_radius = CozyIsland.SPRING_BOWL - 0.6
		disc.height = 0.5
		disc.radial_segments = 24
		disc.rings = 1
		disc.material = mat
		pool.mesh = disc
		pool.position = Vector3(at.x, level - 0.25, at.z)
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pool)
		# Stones round the rim.
		var rng := RandomNumberGenerator.new()
		rng.seed = 900 + i
		for k in 11:
			var a := TAU * k / 11.0 + rng.randf_range(-0.12, 0.12)
			var q := at + Vector3(cos(a), 0, sin(a)) * (CozyIsland.SPRING_BOWL + rng.randf_range(-0.1, 0.3))
			var rock := MeshInstance3D.new()
			var ball := SphereMesh.new()
			var size := rng.randf_range(0.28, 0.55)
			ball.radius = size
			ball.height = size * 1.3
			ball.radial_segments = 8
			ball.rings = 4
			ball.material = stone
			rock.mesh = ball
			rock.position = Vector3(q.x, island.height(q.x, q.z) + size * 0.25, q.z)
			rock.rotation.y = rng.randf() * TAU
			add_child(rock)
		var light := OmniLight3D.new()
		light.light_color = colour
		light.omni_range = 10.0
		light.omni_attenuation = 1.6
		light.shadow_enabled = false
		light.position = Vector3(at.x, level + 1.2, at.z)
		add_child(light)
		_lights.append(light)
		_rivulet(at, level, centre, colour)
		var note := HoverNote.new(Vector3(at.x, level + 0.4, at.z), Vector3(CozyIsland.SPRING_BOWL * 2.0, 1.0, CozyIsland.SPRING_BOWL * 2.0),
				"A spring of glowing %s water, welling up in the hollow at the hill's top and running down toward the plain." % CozyIsland.SPRING_NAMES[i % CozyIsland.SPRING_NAMES.size()], 1.6)
		add_child(note)


## The rivulet: from the rim on the plain's side, step by step down the
## steepest way until the ground lies flat; a ribbon a hand above the
## ground, narrowing as it goes.
func _rivulet(at: Vector3, level: float, toward: Vector3, colour: Color) -> void:
	var dir := Vector3(toward.x - at.x, 0.0, toward.z - at.z).normalized()
	var p := at + dir * (CozyIsland.SPRING_BOWL + 0.2)
	var path: Array[Vector3] = [Vector3(p.x, level, p.z)]
	var e := 0.4
	for k in 40:
		var grad := Vector3(island.height(p.x + e, p.z) - island.height(p.x - e, p.z), 0.0,
				island.height(p.x, p.z + e) - island.height(p.x, p.z - e))
		if grad.length() < 0.02:
			break
		# Downhill, kept a little toward the plain so it does not wander.
		var down := (-grad.normalized() * 0.8 + dir * 0.2).normalized()
		p += down * 0.9
		path.append(Vector3(p.x, island.height(p.x, p.z) + 0.04, p.z))
	if path.size() < 2:
		return
	var verts := PackedVector3Array()
	var colours := PackedColorArray()
	for k in path.size() - 1:
		var a := path[k]
		var b := path[k + 1]
		var side := (b - a).cross(Vector3.UP).normalized()
		var wa := lerpf(0.14, 0.05, float(k) / path.size())
		var wb := lerpf(0.14, 0.05, float(k + 1) / path.size())
		var ca := Color(colour, 1.0 - 0.6 * float(k) / path.size())
		var cb := Color(colour, 1.0 - 0.6 * float(k + 1) / path.size())
		verts.append_array([a - side * wa, a + side * wa, b + side * wb, a - side * wa, b + side * wb, b - side * wb])
		colours.append_array([ca, ca, cb, ca, cb, cb])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colours
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)


func _process(delta: float) -> void:
	_clock += delta
	var night := 1.0 - island.sky.daylight
	for i in _pools.size():
		var breathe := 0.85 + 0.15 * sin(_clock * (0.6 + 0.13 * i) + i)
		_pools[i].emission_energy_multiplier = (1.3 + 1.0 * night) * breathe
		_lights[i].light_energy = (0.4 + 2.2 * night) * breathe
