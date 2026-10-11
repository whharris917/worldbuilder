class_name OrbPool
extends Node3D
## A round stone pool on the grass with the glass ball (GlassOrb) at its
## middle, held by a smooth wooden ring at the water's surface on four
## spokes from the rim: the ring touches the ball below its middle, so
## the ball sits in it as in a cup and turns freely on the water.

const RADIUS := 1.6                     # m: the pool, inside the rim
const WALL := 0.5                       # m: the rim's height over the ground
const WATER := 0.45                     # m: the water's surface over the ground
const RING_DROP := 0.25                 # m: the ring under the ball's middle

var orb: GlassOrb


## `world` gives the pool its material (`material`).
func _init(world: Node) -> void:
	name = "OrbPool"
	var stone_mat: StandardMaterial3D = world.call("material", true, false)
	var rim := CozyMesh.new()
	var stone := Color(0.62, 0.6, 0.56)
	rim.cyl(RADIUS + 0.25, RADIUS + 0.3, WALL, 48, CozyMesh.at(Vector3(0, WALL * 0.5, 0)), stone)
	var rim_view := MeshInstance3D.new()
	rim_view.mesh = rim.commit(stone_mat)
	add_child(rim_view)
	# The rim's solid, so the player walks round it; the water's surface
	# drawn just under the rim's top.
	# (A ring of blocks round the water, clear of the ball.)
	var body := StaticBody3D.new()
	for k in 16:
		var a := TAU * k / 16.0
		var block := BoxShape3D.new()
		block.size = Vector3(0.3, WALL, 2.0 * PI * (RADIUS + 0.15) / 16.0 + 0.05)
		var c := CollisionShape3D.new()
		c.shape = block
		c.transform = Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0, sin(a)) * (RADIUS + 0.15) + Vector3(0, WALL * 0.5, 0))
		body.add_child(c)
	add_child(body)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.16, 0.36, 0.42, 0.85)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	water.metallic_specular = 0.8
	water.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The surface a flat ring: from the rim in to where it meets the
	# globe's glass, the water kept out of the globe.
	var ring_y := WATER + 0.07
	var water_y := WATER + 0.06
	var above := ring_y + RING_DROP - water_y
	var inner := sqrt(maxf(GlassOrb.RADIUS * GlassOrb.RADIUS - above * above, 0.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 64:
		var a0 := TAU * k / 64.0
		var a1 := TAU * (k + 1) / 64.0
		var corners := [Vector3(cos(a0) * inner, 0, sin(a0) * inner), Vector3(cos(a0) * RADIUS, 0, sin(a0) * RADIUS),
				Vector3(cos(a1) * RADIUS, 0, sin(a1) * RADIUS), Vector3(cos(a1) * inner, 0, sin(a1) * inner)]
		for i: int in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.add_vertex(corners[i])
	var surface := st.commit()
	surface.surface_set_material(0, water)
	var water_view := MeshInstance3D.new()
	water_view.mesh = surface
	water_view.position = Vector3(0, water_y, 0)
	water_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water_view)
	# The ring and its spokes, smooth oiled wood.
	var wood := CozyMesh.new()
	var oak := Color(0.48, 0.32, 0.2)
	var touch := sqrt(GlassOrb.RADIUS * GlassOrb.RADIUS - RING_DROP * RING_DROP)
	wood.torus(touch, touch + 0.12, 40, 10, CozyMesh.at(Vector3(0, ring_y, 0)), oak)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var d := Vector3(cos(a), 0, sin(a))
		wood.rod(d * (touch + 0.1) + Vector3(0, ring_y, 0), d * (RADIUS + 0.1) + Vector3(0, WALL - 0.02, 0), 0.035, 8, oak)
	var wood_mat := StandardMaterial3D.new()
	wood_mat.vertex_color_use_as_albedo = true
	wood_mat.roughness = 0.35
	var wood_view := MeshInstance3D.new()
	wood_view.mesh = wood.commit(wood_mat)
	add_child(wood_view)
	# The ball, sitting in the ring.
	orb = GlassOrb.new()
	orb.position = Vector3(0, ring_y + RING_DROP, 0)
	add_child(orb)
