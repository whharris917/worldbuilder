class_name StaticMerge
extends RefCounted
## Making a built scene cheap to draw, after it is built, without
## changing how it looks.
##
## `simplify` gives every engine primitive (cylinder, sphere, torus) only
## as many sides as its size needs: Godot's defaults are 64 sides and 32
## rings whatever the size, about 4,000 triangles a sphere; a post a few
## centimetres across needs 8 sides, a tree crown about 20.
##
## `merge` joins every piece that never moves into one mesh per material
## per region, so the graphics chip is handed a few dozen meshes instead
## of thousands of small ones (each costs the processor a fixed amount to
## hand over, however small). It only takes primitives whose material is
## one of `shared` (the island's managed materials, so the look's
## switches still reach them) and that have no node marked as moving
## between them and the root (meta "moves", set by whoever builds the
## moving part). A region is the nearest BeachSite, SeaMill or TidePool
## above a piece, or the root: each keeps its own meshes, so a mesh's
## bounds stay local and what is out of view is skipped.
##
## `fade_details` gives what was left separate and small (creatures,
## crystal heads) a distance beyond which it is not drawn, and no shadow.

const MOVES := "moves"


## Sides for a round shape of radius `r` (metres): 8 for a rod (fewer
## and its outline turns spiky at the corners), about 18 for a metre, 32
## at most. Shapes built with fewer on purpose (six-sided crystals) keep
## theirs.
static func sides(r: float) -> int:
	return clampi(int(8.0 + r * 10.0), 8, 32)


static func simplify(root: Node) -> int:
	var done := {}
	var count := 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var mesh := mi.mesh
		if mesh == null or done.has(mesh):
			continue
		done[mesh] = true
		var s := mi.global_transform.basis.get_scale()
		var grow := maxf(s.x, maxf(s.y, s.z))
		if mesh is CylinderMesh:
			var c := mesh as CylinderMesh
			c.radial_segments = mini(c.radial_segments, sides(maxf(c.top_radius, c.bottom_radius) * grow))
			c.rings = mini(c.rings, 1)
			count += 1
		elif mesh is SphereMesh:
			var sp := mesh as SphereMesh
			var n_sides := sides(sp.radius * grow)
			sp.radial_segments = mini(sp.radial_segments, n_sides)
			sp.rings = mini(sp.rings, maxi(n_sides / 2, 4))
			count += 1
		elif mesh is TorusMesh:
			var t := mesh as TorusMesh
			t.rings = mini(t.rings, clampi(int(8.0 + t.outer_radius * grow * 8.0), 8, 32))
			t.ring_segments = mini(t.ring_segments, clampi(int(4.0 + (t.outer_radius - t.inner_radius) * grow * 40.0), 4, 8))
			count += 1
	return count


static func _moves(node: Node, root: Node) -> bool:
	var n := node
	while n != null and n != root:
		if n.has_meta(MOVES):
			return true
		n = n.get_parent()
	return false


static func _region(node: Node, root: Node) -> Node3D:
	var n := node.get_parent()
	while n != null and n != root:
		if n is BeachSite or n is SeaMill or n is TidePool:
			return n as Node3D
		n = n.get_parent()
	return root as Node3D


static func _material(mi: MeshInstance3D) -> Material:
	if mi.material_override != null:
		return mi.material_override
	var m := mi.get_surface_override_material(0)
	if m != null:
		return m
	return mi.mesh.surface_get_material(0)


## Returns how many pieces were joined, into how many meshes.
static func merge(root: Node3D, shared: Array) -> Vector2i:
	var wanted := {}
	for m in shared:
		wanted[m] = true
	var groups := {}                    # key -> [region, material, shadow, [pieces]]
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.visible or not (mi.mesh is PrimitiveMesh) or mi.mesh.get_surface_count() != 1:
			continue
		var mat := _material(mi)
		if mat == null or not wanted.has(mat) or _moves(mi, root):
			continue
		var region := _region(mi, root)
		var key := "%d/%d/%d/%d" % [region.get_instance_id(), mat.get_instance_id(), mi.cast_shadow, mi.layers]
		if not groups.has(key):
			groups[key] = [region, mat, mi.cast_shadow, mi.layers, []]
		(groups[key][4] as Array).append(mi)
	var pieces := 0
	for key: String in groups:
		var g: Array = groups[key]
		var region: Node3D = g[0]
		var list: Array = g[4]
		if list.size() < 2:
			continue
		var to_region := region.global_transform.affine_inverse()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi: MeshInstance3D in list:
			st.append_from(mi.mesh, 0, to_region * mi.global_transform)
		st.set_material(g[1])
		var merged := MeshInstance3D.new()
		merged.name = "Merged"
		merged.mesh = st.commit()
		merged.cast_shadow = g[2]
		merged.layers = g[3]
		region.add_child(merged)
		for mi: MeshInstance3D in list:
			mi.get_parent().remove_child(mi)
			mi.queue_free()
		pieces += list.size()
	return Vector2i(pieces, groups.size())


static func fade_details(root: Node) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var far := 0.0
		var p := mi.get_parent()
		while p != null and p != root:
			if p is TidePool:
				far = 45.0
				break
			if p is LumenPart:
				far = 90.0
				break
			p = p.get_parent()
		if far > 0.0 and mi.name != "Merged":
			mi.visibility_range_end = far
			mi.visibility_range_end_margin = 8.0
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
