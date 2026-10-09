class_name Aurora
extends Node3D
## The northern lights over the cozy island on dark nights: curtains of
## light hanging in the north, folding and drifting, their lower edge a
## sharp bright green and their tops fading to a deep red, as real aurora
## is (oxygen glows green at about 100 to 150 km and red higher up, where
## the air is thin). Here they hang above the clouds, 300 m up and a
## kilometre or so off, near enough for the aurora comb (AuroraLine) to
## catch.
##
## Engine features only: one mesh rebuilt each frame (an ImmediateMesh),
## its triangles coloured in their vertices, drawn unshaded and added to
## the picture, so it glows over the stars and darkens nothing.
## `strength` (0 by day, 1 on a dark night) follows the sky's daylight.

const CURTAINS := 4
const COLUMNS := 90
const GREEN := Color(0.3, 1.0, 0.5)
const RED := Color(1.0, 0.22, 0.32)

var strength := 0.0
## Where the curtains' lower edge hangs, for the comb's threads to reach.
var low_points: Array[Vector3] = []

var island: CozyIsland
var _mesh := ImmediateMesh.new()
var _mat := StandardMaterial3D.new()
var _clock := 0.0
# Each curtain: centre bearing from north (rad), distance, half span (rad),
# lower edge, top, phase, drift.
var _curtains: Array = []


func _init(owner_island: CozyIsland) -> void:
	island = owner_island
	name = "Aurora"


func _ready() -> void:
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mat.disable_fog = true
	var view := MeshInstance3D.new()
	view.name = "Curtains"
	view.mesh = _mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.extra_cull_margin = 16384.0
	add_child(view)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5577
	for k in CURTAINS:
		_curtains.append([deg_to_rad(rng.randf_range(-40.0, 40.0)), rng.randf_range(900.0, 1300.0),
				deg_to_rad(rng.randf_range(16.0, 30.0)), rng.randf_range(300.0, 380.0),
				rng.randf_range(700.0, 900.0), rng.randf() * TAU, rng.randf_range(0.6, 1.4)])


## A point of a curtain at `u` (0 to 1 across it) and height `y`.
func _at(c: Array, u: float, y: float) -> Vector3:
	var t := _clock * float(c[6])
	var phase: float = c[5]
	var bearing: float = c[0] + (u - 0.5) * 2.0 * float(c[2]) + 0.05 * sin(u * 7.0 + t * 0.15 + phase)
	var r: float = c[1] + 70.0 * sin(u * 5.0 + t * 0.1 + phase)
	return Vector3(sin(bearing) * r, y, -cos(bearing) * r)


func _process(delta: float) -> void:
	_clock += delta
	strength = smoothstep(0.35, 0.03, island.sky.daylight)
	_mesh.clear_surfaces()
	low_points.clear()
	if strength < 0.01:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
	for c: Array in _curtains:
		var t := _clock * float(c[6])
		var phase: float = c[5]
		var pulse := 0.75 + 0.25 * sin(t * 0.3 + phase)
		var prev: Array = []
		for i in COLUMNS:
			var u := float(i) / (COLUMNS - 1)
			# Rays: brighter and dimmer columns drifting along the curtain.
			var rays := 0.55 + 0.45 * sin(u * 53.0 + t * 0.9 + phase) * sin(u * 19.0 - t * 0.6)
			var edge := sin(u * PI)
			var b := strength * pulse * rays * edge
			var low: float = c[3] + 14.0 * sin(u * 9.0 + t * 0.2 + phase)
			var top: float = c[4]
			var mid := lerpf(low, top, 0.3)
			var col := [
				[_at(c, u, low), GREEN * (0.9 * b)],
				[_at(c, u, mid), GREEN * (0.35 * b) + RED * (0.1 * b)],
				[_at(c, u, top), RED * (0.0)],
			]
			if i % 15 == 7:
				low_points.append(col[0][0])
			if not prev.is_empty():
				for k in 2:
					var a0: Array = prev[k]
					var a1: Array = prev[k + 1]
					var b0: Array = col[k]
					var b1: Array = col[k + 1]
					for v: Array in [a0, b0, b1, a0, b1, a1]:
						_mesh.surface_set_color(v[1])
						_mesh.surface_add_vertex(v[0])
			prev = col
	_mesh.surface_end()
